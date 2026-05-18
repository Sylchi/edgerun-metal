#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <ctype.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>

#include "host_util.h"
#include "protocol.h"

static void log_line(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    printf("\n");
    va_end(args);
    fflush(stdout);
}

static bool get_option(const uint8_t *opts, size_t opts_len, uint8_t code,
                      const uint8_t **val, uint8_t *len) {
    size_t i = 0;
    while (i < opts_len) {
        uint8_t c = opts[i++];
        if (c == DHCP_OPT_END) {
            return false;
        }
        if (c == 0) {
            continue;
        }
        if (i >= opts_len) {
            return false;
        }
        uint8_t l = opts[i++];
        if (l == 0) {
            continue;
        }
        if (i + l > opts_len) {
            return false;
        }
        if (c == code) {
            *val = &opts[i];
            *len = l;
            return true;
        }
        i += l;
    }
    return false;
}

static bool is_same_peer(const struct sockaddr_in *a, const struct sockaddr_in *b) {
    return a->sin_addr.s_addr == b->sin_addr.s_addr && a->sin_port == b->sin_port;
}

static int open_dgram_socket(uint16_t port, bool allow_bcast) {
    int fd;
    int one = 1;
    struct sockaddr_in addr;

    fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (fd < 0) {
        perror("socket");
        return -1;
    }

    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) < 0) {
        perror("SO_REUSEADDR");
        close(fd);
        return -1;
    }

    if (allow_bcast && setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &one, sizeof(one)) < 0) {
        perror("SO_BROADCAST");
        close(fd);
        return -1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }
    return fd;
}

static size_t dhcp_append_u8(uint8_t *p, uint8_t code, uint8_t v) {
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = DHCP_OPTION_U8_PAYLOAD_LEN;
    p[DHCP_OPTION_VALUE_OFFSET] = v;
    return DHCP_OPTION_U8_TOTAL_LEN;
}

static size_t dhcp_append_u32(uint8_t *p, uint8_t code, uint32_t v_host) {
    uint32_t v = htonl(v_host);
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = DHCP_OPTION_U32_PAYLOAD_LEN;
    memcpy(p + DHCP_OPTION_VALUE_OFFSET, &v, DHCP_OPTION_U32_PAYLOAD_LEN);
    return DHCP_OPTION_U32_TOTAL_LEN;
}

static size_t dhcp_append_ipv4(uint8_t *p, uint8_t code, const char *ip) {
    struct in_addr addr;
    if (inet_pton(AF_INET, ip, &addr) != 1) {
        addr.s_addr = 0u;
    }
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = DHCP_OPTION_U32_PAYLOAD_LEN;
    memcpy(p + DHCP_OPTION_VALUE_OFFSET, &addr.s_addr, DHCP_OPTION_U32_PAYLOAD_LEN);
    return DHCP_OPTION_U32_TOTAL_LEN;
}


static size_t dhcp_append_bytes(uint8_t *p, uint8_t code, const uint8_t *v, uint8_t len) {
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = len;
    memcpy(p + DHCP_OPTION_VALUE_OFFSET, v, len);
    return (size_t)(DHCP_OPTION_VALUE_OFFSET + len);
}

static size_t build_dhcp_reply(dhcp_packet_t *out, const dhcp_packet_t *in, uint8_t dhcp_msg,
                              const char *boot_file, const char *client_ip, uint8_t mode,
                              bool is_pxe_client, bool has_arch, uint16_t arch,
                              const uint8_t *machine_id, uint8_t machine_id_len) {
    uint8_t *p;
    size_t boot_len;
    size_t max_len;

    memset(out, 0, sizeof(*out));
    out->op = DHCP_OP_BOOTREPLY;
    out->htype = in->htype;
    out->hlen = in->hlen;
    out->hops = 0u;
    out->xid = in->xid;
    out->secs = in->secs;
    out->flags = in->flags;
    out->ciaddr = 0u;
    out->yiaddr = inet_addr(client_ip);
    out->siaddr = inet_addr(SERVER_IP);
    out->giaddr = 0u;
    memcpy(out->chaddr, in->chaddr, sizeof(out->chaddr));
    boot_len = (boot_file != NULL) ? strlen(boot_file) : 0u;
    max_len = sizeof(out->file) - 1u;
    if (boot_len > max_len) {
        boot_len = max_len;
    }
    if (boot_len > 0u) {
        memcpy(out->file, boot_file, boot_len);
        out->file[boot_len] = '\0';
    }
    /* sname intentionally left empty; siaddr/options carry boot server. */
    out->magic = htonl(DHCP_MAGIC);

    p = out->options;
    p += dhcp_append_u8(p, DHCP_OPT_DHCP_MSG_TYPE, dhcp_msg);
    p += dhcp_append_ipv4(p, DHCP_OPT_SERVER_ID, SERVER_IP);
    p += dhcp_append_u32(p, DHCP_OPT_LEASE_TIME, DHCP_LEASE_SECONDS);
    p += dhcp_append_ipv4(p, DHCP_OPT_SUBNET_MASK, SUBNET_MASK);
    p += dhcp_append_ipv4(p, DHCP_OPT_ROUTER, ROUTER_IP);
    p += dhcp_append_ipv4(p, DHCP_OPT_DNS, DNS_IP);
    if (mode == MODE_TFTP) {
        p += dhcp_append_bytes(p, DHCP_OPT_TFTP_SERVER, (const uint8_t *)SERVER_IP, (uint8_t)strlen(SERVER_IP));
    }
    if (boot_len > 0u) {
        p += dhcp_append_bytes(p, DHCP_OPT_BOOTFILE_NAME, (const uint8_t *)boot_file, (uint8_t)boot_len);
    }
    (void)is_pxe_client;
    (void)has_arch;
    (void)arch;
    (void)machine_id;
    (void)machine_id_len;
    *p = DHCP_OPT_END;
    p++;

    return (size_t)(p - (uint8_t *)out);
}

static void format_ipv4_str(uint32_t in_addr, char *out, size_t out_size) {
    struct in_addr addr;
    if (out == NULL || out_size == 0u) {
        return;
    }
    addr.s_addr = in_addr;
    if (inet_ntop(AF_INET, &addr, out, (socklen_t)out_size) == NULL) {
        (void)snprintf(out, out_size, "0.0.0.0");
    }
}

static void print_vendor_bytes(const char *label, const uint8_t *data, uint8_t len) {
    char out[NETBOOT_TEXT_BUFFER_SIZE];
    size_t i;
    size_t out_len = 0u;

    out_len = 0u;
    for (i = 0; i < (size_t)len && out_len < (sizeof(out) - 1u); i++) {
        if (isprint((int)data[i]) && data[i] < NETBOOT_PRINTABLE_ASCII_LIMIT) {
            out[out_len++] = (char)data[i];
        } else {
            out[out_len++] = '.';
        }
    }
    out[out_len] = '\0';
    log_line("%s: %s", label, out_len ? out : "<empty>");
}

static void print_bytes_list_hex(const char *label, const uint8_t *data, uint8_t len) {
    char out[NETBOOT_TEXT_BUFFER_SIZE];
    size_t off = 0u;
    size_t i;

    if (label == NULL) {
        return;
    }
    if (data == NULL || len == 0u) {
        log_line("%s: <none>", label);
        return;
    }

    for (i = 0u; i < (size_t)len && off < (sizeof(out) - NETBOOT_DECIMAL_BYTE_TEXT_ROOM); i++) {
        off += (size_t)snprintf(&out[off], sizeof(out) - off, "%s%u", i == 0u ? "" : " ", (unsigned)data[i]);
    }
    if (off >= (sizeof(out) - 1u)) {
        out[sizeof(out) - 1u] = '\0';
    } else {
        out[off] = '\0';
    }
    log_line("%s: %s", label, out);
}

static void print_option_ip(const char *label, const uint8_t *data, uint8_t len) {
    if (data == NULL || len != NETBOOT_IPV4_BYTES) {
        print_bytes_list_hex(label, data, len);
        return;
    }
    log_line("%s: %u.%u.%u.%u", label,
             data[NETBOOT_BYTE0], data[NETBOOT_BYTE1], data[NETBOOT_BYTE2], data[NETBOOT_BYTE3]);
}

static void vendor_to_string(const uint8_t *data, uint8_t len, char *out, size_t out_size) {
    size_t i;
    size_t out_len = 0u;
    if (out_size == 0u || out == NULL) {
        return;
    }
    if (data == NULL || len == 0u) {
        (void)snprintf(out, out_size, "<unknown>");
        return;
    }
    for (i = 0; i < (size_t)len && out_len < (out_size - 1u); i++) {
        if (isprint((int)data[i]) && data[i] < NETBOOT_PRINTABLE_ASCII_LIMIT) {
            out[out_len++] = (char)data[i];
        }
    }
    if (out_len == 0u) {
        (void)snprintf(out, out_size, "<empty>");
        return;
    }
    out[out_len] = '\0';
}

static uint8_t classify_client_class(const char *vendor) {
    if (vendor == NULL) {
        return CLIENT_OTHER;
    }
    if (strncmp(vendor, NETBOOT_VENDOR_HTTP, NETBOOT_VENDOR_HTTP_LEN) == 0) {
        return CLIENT_HTTP_BOOT;
    }
    if (strncmp(vendor, NETBOOT_VENDOR_PXE, NETBOOT_VENDOR_PXE_LEN) == 0) {
        return CLIENT_PXE_BOOT;
    }
    return CLIENT_OTHER;
}

static const char *mode_name(uint8_t mode) {
    if (mode == MODE_HTTP) {
        return "http";
    }
    if (mode == MODE_TFTP) {
        return "tftp";
    }
    if (mode == MODE_AUTO) {
        return "auto";
    }
    if (mode == MODE_IGNORE) {
        return "ignored";
    }
    if (mode == MODE_MANAGEMENT) {
        return "management";
    }
    return "unknown";
}

static bool mac_match(const uint8_t *a, const uint8_t *b) {
    return memcmp(a, b, NETBOOT_MAC_BYTES) == 0;
}

static void mac_to_str(const uint8_t *mac, uint8_t len, char *out, size_t out_size) {
    size_t i;
    int off = 0;

    if (out_size == 0u || out == NULL) {
        return;
    }
    if (len == 0u || mac == NULL) {
        (void)snprintf(out, out_size, "<unknown>");
        return;
    }

    for (i = 0; i < (size_t)(len < NETBOOT_MAC_BYTES ? len : NETBOOT_MAC_BYTES); i++) {
        off += snprintf(&out[off], out_size - (size_t)off, "%s%02x", i == 0u ? "" : ":", mac[i]);
        if (off >= (int)out_size) {
            break;
        }
    }
    if (off < (int)out_size) {
        out[off] = '\0';
    }
}

static void handle_dhcp(int sock, const uint8_t *buf, size_t len, const char *boot_file,
                        const char *boot_url, const char *client_ip,
                        uint8_t configured_mode, bool force_http_for_pxe,
                        bool has_allow_mac, const uint8_t *allow_mac,
                        bool mgmt_dhcp, const char *mgmt_ip,
                        bool has_mgmt_mac, const uint8_t *mgmt_mac,
                        bool *has_assigned_client, uint8_t *assigned_mac,
                        bool *has_assigned_mgmt_client, uint8_t *assigned_mgmt_mac) {
    const dhcp_packet_t *req = (const dhcp_packet_t *)buf;
    size_t opts_len;
    const uint8_t *v;
    uint8_t l;
    uint8_t msg_type = 0;
    const uint8_t *vendor_opt = NULL;
    uint8_t vendor_len = 0u;
    char vendor[NETBOOT_VENDOR_BUFFER_SIZE];
    bool has_arch = false;
    uint16_t arch = 0u;
    uint8_t client_type = CLIENT_OTHER;
    uint8_t reply_mode = MODE_IGNORE;
    const char *reply_bootfile = "<none>";
    const char *req_kind = "DHCP";
    char peer_mac[32];
    char ciaddr_text[32];
    char arch_text[16];
    dhcp_packet_t reply;
    size_t reply_len;
    struct sockaddr_in dst;
    uint8_t resp_type;
    bool same_client = false;
    bool same_mgmt_client = false;
    const uint8_t *req_machine_id = NULL;
    uint8_t req_machine_id_len = 0u;
    const uint8_t *requested_ip = NULL;
    uint8_t requested_ip_len = 0u;
    const uint8_t *requested_server_id = NULL;
    uint8_t requested_server_id_len = 0u;
    const uint8_t *request_list = NULL;
    uint8_t request_list_len = 0u;
    bool is_pxe_client = false;

    if (len < offsetof(dhcp_packet_t, options)) {
        return;
    }
    if (req->magic != htonl(DHCP_MAGIC)) {
        return;
    }
    if (req->op != DHCP_OP_BOOTREQUEST) {
        return;
    }

    opts_len = len - offsetof(dhcp_packet_t, options);
    if (!get_option(req->options, opts_len, DHCP_OPT_DHCP_MSG_TYPE, &v, &l) ||
        l != DHCP_OPTION_MSG_TYPE_PAYLOAD_LEN) {
        return;
    }
    msg_type = v[0];
    if (msg_type == DHCP_MESSAGE_DISCOVER) {
        req_kind = "DHCPDISCOVER";
    } else if (msg_type == DHCP_MESSAGE_REQUEST) {
        req_kind = "DHCPREQUEST";
    } else {
        return;
    }
    format_ipv4_str(req->ciaddr, ciaddr_text, sizeof(ciaddr_text));

    mac_to_str(req->chaddr, req->hlen, peer_mac, sizeof(peer_mac));
    if (get_option(req->options, opts_len, DHCP_OPT_VENDOR_CLASS, &vendor_opt, &vendor_len)) {
        vendor_to_string(vendor_opt, vendor_len, vendor, sizeof(vendor));
    } else {
        (void)snprintf(vendor, sizeof(vendor), "<unknown>");
    }
    if (get_option(req->options, opts_len, DHCP_OPT_CLIENT_ARCH, &v, &l) &&
        l == DHCP_OPTION_ARCH_PAYLOAD_LEN) {
        arch = (uint16_t)(((uint16_t)v[0] << 8u) | (uint16_t)v[1]);
        has_arch = true;
    }
    if (get_option(req->options, opts_len, DHCP_OPT_CLIENT_MACHINE, &req_machine_id, &req_machine_id_len)) {
        print_vendor_bytes("option 97 machine-id", req_machine_id, req_machine_id_len);
    }
    get_option(req->options, opts_len, DHCP_OPT_REQUESTED_IP, &requested_ip, &requested_ip_len);
    get_option(req->options, opts_len, DHCP_OPT_SERVER_ID, &requested_server_id, &requested_server_id_len);
    get_option(req->options, opts_len, DHCP_OPT_PARAM_REQUEST_LIST, &request_list, &request_list_len);

    client_type = classify_client_class(vendor);
    is_pxe_client = (client_type == CLIENT_PXE_BOOT);

    if (client_type == CLIENT_OTHER) {
        if (mgmt_dhcp) {
            reply_mode = MODE_MANAGEMENT;
        } else {
            reply_mode = MODE_IGNORE;
        }
    } else if (configured_mode == MODE_HTTP) {
        reply_mode = MODE_HTTP;
    } else if (configured_mode == MODE_TFTP) {
        reply_mode = MODE_TFTP;
    } else if (configured_mode == MODE_AUTO) {
        if (client_type == CLIENT_HTTP_BOOT) {
            reply_mode = MODE_HTTP;
        } else if (client_type == CLIENT_PXE_BOOT) {
            if (force_http_for_pxe) {
                log_line("PXE client forced to HTTP boot URL");
                reply_mode = MODE_HTTP;
            } else {
                reply_mode = MODE_TFTP;
            }
        } else {
            reply_mode = MODE_IGNORE;
        }
    }

    if (reply_mode == MODE_MANAGEMENT) {
        reply_bootfile = "<none>";
    } else if (reply_mode == MODE_HTTP) {
        reply_bootfile = boot_url;
    } else if (reply_mode == MODE_TFTP) {
        reply_bootfile = boot_file;
    }

    if (!has_arch) {
        (void)snprintf(arch_text, sizeof(arch_text), "<not-present>");
    } else {
        (void)snprintf(arch_text, sizeof(arch_text), "0x%04x", arch);
    }

    log_line("%s from %s xid=0x%08x vendor=%s arch=%s selected mode=%s ip=%s bootfile=%s",
             req_kind, peer_mac, ntohl(req->xid), vendor,
             arch_text, mode_name(reply_mode),
             reply_mode == MODE_MANAGEMENT ? mgmt_ip : client_ip, reply_bootfile);
    log_line("%s flags=0x%04x ciaddr=%s", req_kind, ntohs(req->flags), ciaddr_text);
    print_option_ip("requested ip (50)", requested_ip, requested_ip_len);
    print_option_ip("server id in request (54)", requested_server_id, requested_server_id_len);
    print_bytes_list_hex("parameter request list (55)", request_list, request_list_len);

    if (reply_mode == MODE_IGNORE) {
        return;
    }

    if (reply_mode == MODE_MANAGEMENT) {
        if (has_mgmt_mac) {
            same_mgmt_client = mac_match(req->chaddr, mgmt_mac);
        } else if (*has_assigned_mgmt_client) {
            same_mgmt_client = mac_match(req->chaddr, assigned_mgmt_mac);
        } else {
            same_mgmt_client = true;
            *has_assigned_mgmt_client = true;
            memcpy(assigned_mgmt_mac, req->chaddr, NETBOOT_MAC_BYTES);
        }
        if (!same_mgmt_client) {
            log_line("ignoring additional management DHCP client %s vendor=%s", peer_mac, vendor);
            return;
        }
    } else {
        if (has_allow_mac) {
            same_client = mac_match(req->chaddr, allow_mac);
            if (!same_client) {
                log_line("ignoring non-allowed DHCP client %s vendor=%s", peer_mac, vendor);
                return;
            }
        } else {
            if (*has_assigned_client) {
                same_client = mac_match(req->chaddr, assigned_mac);
                if (!same_client) {
                    log_line("ignoring additional DHCP client %s (ip %s already assigned)", peer_mac, client_ip);
                    return;
                }
            } else {
                memcpy(assigned_mac, req->chaddr, NETBOOT_MAC_BYTES);
                *has_assigned_client = true;
            }
        }
    }

    resp_type = (msg_type == DHCP_MESSAGE_DISCOVER) ? DHCP_MESSAGE_OFFER : DHCP_MESSAGE_ACK;
    if (reply_mode == MODE_MANAGEMENT) {
        reply_len = build_dhcp_reply(&reply, req, resp_type, NULL, mgmt_ip,
                                    reply_mode, false, false, 0u, NULL, 0u);
    } else {
        reply_len = build_dhcp_reply(&reply, req, resp_type, reply_bootfile, client_ip,
                                reply_mode, is_pxe_client, has_arch, arch,
                                req_machine_id, req_machine_id_len);
    }

    dst.sin_family = AF_INET;
    dst.sin_port = htons(DHCP_CLIENT_PORT);
    dst.sin_addr.s_addr = INADDR_BROADCAST;
    log_line("sending DHCP reply to 255.255.255.255:%u", (unsigned)DHCP_CLIENT_PORT);
    if (sendto(sock, &reply, reply_len, 0, (struct sockaddr *)&dst, sizeof(dst)) < 0) {
        perror("sendto");
        return;
    }
    if (resp_type == DHCP_MESSAGE_OFFER) {
        if (reply_mode == MODE_MANAGEMENT) {
            log_line("DHCPOFFER management %s", mgmt_ip);
        } else {
            log_line("DHCPOFFER boot %s bootfile=%s", client_ip, reply_bootfile);
        }
    } else {
        if (reply_mode == MODE_MANAGEMENT) {
            log_line("DHCPACK management %s", mgmt_ip);
        } else {
            log_line("DHCPACK boot %s bootfile=%s", client_ip, reply_bootfile);
        }
    }
}

static bool send_all(int sock, const uint8_t *buf, size_t len) {
    while (len > 0u) {
        ssize_t sent = send(sock, buf, len, 0);
        if (sent <= 0) {
            return false;
        }
        buf += (size_t)sent;
        len -= (size_t)sent;
    }
    return true;
}

static bool send_dhcp_error(int sock, const struct sockaddr_in *client, uint16_t code, const char *msg) {
    uint8_t pkt[TFTP_ERROR_PACKET_BYTES];
    size_t len = strlen(msg);
    uint16_t code_net = htons(code);
    size_t total;

    if (len > sizeof(pkt) - TFTP_ERROR_OVERHEAD_BYTES) {
        len = sizeof(pkt) - TFTP_ERROR_OVERHEAD_BYTES;
    }
    pkt[NETBOOT_BYTE0] = 0;
    pkt[NETBOOT_BYTE1] = TFTP_OP_ERR;
    memcpy(&pkt[TFTP_ERROR_CODE_OFFSET], &code_net, DHCP_OPTION_ARCH_PAYLOAD_LEN);
    memcpy(&pkt[TFTP_ERROR_MSG_OFFSET], msg, len);
    pkt[TFTP_ERROR_MSG_OFFSET + len] = 0;
    total = TFTP_ERROR_OVERHEAD_BYTES + len;
    return sendto(sock, pkt, total, 0, (const struct sockaddr *)client, (socklen_t)sizeof(*client)) == (ssize_t)total;
}

static int open_http_listener(const char *bind_ip, uint16_t port) {
    int fd;
    int one = 1;
    struct sockaddr_in addr;
    fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (fd < 0) {
        perror("socket");
        return -1;
    }

    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one)) < 0) {
        perror("SO_REUSEADDR");
        close(fd);
        return -1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(bind_ip);
    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        close(fd);
        return -1;
    }

    if (listen(fd, HTTP_LISTEN_BACKLOG) < 0) {
        perror("listen");
        close(fd);
        return -1;
    }

    return fd;
}

static int open_http_listener_with_fallback(uint16_t *port, bool port_explicit) {
    const uint16_t fallback_port = HTTP_PORT_FALLBACK;
    int fd;

    if (port == NULL) {
        return -1;
    }
    if (*port == 0u) {
        *port = HTTP_PORT_DEFAULT;
    }
    fd = open_http_listener(SERVER_IP, *port);
    if (fd >= 0 || port_explicit) {
        return fd;
    }
    if (*port == HTTP_PORT_DEFAULT && fallback_port != 0u) {
        fd = open_http_listener(SERVER_IP, fallback_port);
        if (fd >= 0) {
            *port = fallback_port;
            return fd;
        }
    }
    return -1;
}

static bool serve_http_file(int sock, const char *efi_path) {
    FILE *fp = fopen(efi_path, "rb");
    uint8_t buf[NETBOOT_FILE_BUFFER_SIZE];
    size_t nread;
    bool ok;

    if (fp == NULL) {
        return false;
    }

    while ((nread = fread(buf, 1, sizeof(buf), fp)) > 0u) {
        if (!send_all(sock, buf, nread)) {
            fclose(fp);
            return false;
        }
    }
    ok = !ferror(fp);
    fclose(fp);
    return ok;
}

static bool handle_http_client(int sock, const char *req_host, uint16_t port, const char *efi_path, size_t efi_size) {
    char request[NETBOOT_HTTP_REQUEST_BUFFER_SIZE];
    char method[16];
    char target[NETBOOT_HTTP_TARGET_BUFFER_SIZE];
    char version[16];
    char expect_abs[NETBOOT_HTTP_TARGET_BUFFER_SIZE];
    char expect_path[NETBOOT_HTTP_PATH_BUFFER_SIZE];
    const char *body;
    char resp_header[NETBOOT_HTTP_HEADER_BUFFER_SIZE];
    ssize_t n;

    memset(request, 0, sizeof(request));
    n = recv(sock, request, sizeof(request) - 1u, 0);
    if (n <= 0) {
        return false;
    }
    request[sizeof(request) - 1u] = '\0';

    if (sscanf(request, "%15s %511s %15s", method, target, version) != NETBOOT_HTTP_REQUEST_FIELD_COUNT) {
        return false;
    }
    log_line("HTTP request: %s %s %s", method, target, version);
    snprintf(expect_path, sizeof(expect_path), "/%s", BOOT_FILE);
    snprintf(expect_abs, sizeof(expect_abs), "http://%s:%u%s", req_host, (unsigned)port, expect_path);

    char expect_base[NETBOOT_HTTP_PATH_BUFFER_SIZE];
    char expect_base_abs[NETBOOT_HTTP_TARGET_BUFFER_SIZE];
    snprintf(expect_base, sizeof(expect_base), "/%s", BOOT_FILE_BASENAME);
    snprintf(expect_base_abs, sizeof(expect_base_abs), "http://%s:%u%s", req_host, (unsigned)port, expect_base);

    if ((strcasecmp(method, "GET") != 0) || (strcmp(version, "HTTP/1.0") != 0 && strcmp(version, "HTTP/1.1") != 0) ||
        ((strcmp(target, expect_path) != 0) && (strcmp(target, expect_abs) != 0) &&
         (strcmp(target, expect_base) != 0) && (strcmp(target, expect_base_abs) != 0))) {
        const char *not_found =
            "HTTP/1.1 404 Not Found\r\n"
            "Content-Length: 0\r\n"
            "Connection: close\r\n"
            "\r\n";
        (void)send_all(sock, (const uint8_t *)not_found, strlen(not_found));
        return false;
    }

    body = BOOT_FILE;
    snprintf(resp_header, sizeof(resp_header),
             "HTTP/1.1 200 OK\r\n"
             "Content-Type: application/octet-stream\r\n"
             "Content-Length: %zu\r\n"
             "Connection: close\r\n"
             "\r\n",
             efi_size);
    log_line("HTTP 200 %s %zu", body, efi_size);
    if (!send_all(sock, (const uint8_t *)resp_header, strlen(resp_header))) {
        return false;
    }
    if (!serve_http_file(sock, efi_path)) {
        return false;
    }

    return true;
}

static bool wait_for_ack(int sock, const struct sockaddr_in *peer, uint16_t expected_block) {
    while (true) {
        fd_set fds;
        struct timeval tv = {(time_t)(TFTP_TIMEOUT_MS / 1000u), (suseconds_t)((TFTP_TIMEOUT_MS % 1000u) * 1000u)};
        struct sockaddr_in src;
        socklen_t src_len = (socklen_t)sizeof(src);
        uint8_t buf[TFTP_PACKET_BYTES];
        int rc;
        ssize_t n;

        FD_ZERO(&fds);
        FD_SET(sock, &fds);
        rc = select(sock + 1, &fds, NULL, NULL, &tv);
        if (rc <= 0) {
            return false;
        }
        n = recvfrom(sock, buf, sizeof(buf), 0, (struct sockaddr *)&src, &src_len);
        if (n < TFTP_MIN_ACK_BYTES || !is_same_peer(&src, peer)) {
            continue;
        }
        if (buf[TFTP_OP_HIGH_OFFSET] != 0 || buf[TFTP_OP_LOW_OFFSET] != TFTP_OP_ACK) {
            continue;
        }
        if (((uint16_t)buf[TFTP_BLOCK_HIGH_OFFSET] << 8u |
             (uint16_t)buf[TFTP_BLOCK_LOW_OFFSET]) == expected_block) {
            return true;
        }
    }
}

static bool send_block_with_retries(int sock, const struct sockaddr_in *peer, const uint8_t *file_data,
                                   size_t file_size, size_t offset, uint16_t block) {
    size_t left;
    size_t chunk;
    uint8_t packet[TFTP_HEADER_BYTES + TFTP_BLOCK_SIZE];

    left = (offset < file_size) ? (file_size - offset) : 0u;
    if (left > TFTP_BLOCK_SIZE) {
        chunk = TFTP_BLOCK_SIZE;
    } else {
        chunk = left;
    }

    packet[TFTP_OP_HIGH_OFFSET] = 0;
    packet[TFTP_OP_LOW_OFFSET] = TFTP_OP_DATA;
    packet[TFTP_BLOCK_HIGH_OFFSET] = (uint8_t)(block >> 8u);
    packet[TFTP_BLOCK_LOW_OFFSET] = (uint8_t)block;
    if (chunk > 0u) {
        memcpy(&packet[TFTP_PAYLOAD_OFFSET], file_data + offset, chunk);
    }

    for (uint32_t attempt = 0u; attempt < TFTP_MAX_RETRIES; attempt++) {
        ssize_t sent = sendto(sock, packet, TFTP_HEADER_BYTES + chunk, 0, (const struct sockaddr *)peer, (socklen_t)sizeof(*peer));
        if (sent < 0) {
            return false;
        }
        if (wait_for_ack(sock, peer, block)) {
            log_line("TFTP DATA block %u", block);
            return true;
        }
    }
    return false;
}

static bool transfer_boot_file(const char *path, int tfd, const struct sockaddr_in *peer) {
    FILE *fp = NULL;
    uint8_t *file_data = NULL;
    long size_long;
    size_t file_size = 0u;
    size_t offset = 0u;
    uint16_t block = 1u;
    bool ok = false;
    bool sent_zero = false;
    bool done = false;

    fp = fopen(path, "rb");
    if (fp == NULL) {
        log_line("unable to open %s", path);
        return false;
    }

    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return false;
    }
    size_long = ftell(fp);
    if (size_long < 0 || size_long > (long)NETBOOT_FILE_SIZE_MAX) {
        fclose(fp);
        return false;
    }
    file_size = (size_t)size_long;
    if (fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        return false;
    }

    if (file_size != 0u) {
        file_data = (uint8_t *)malloc(file_size);
        if (file_data == NULL) {
            fclose(fp);
            return false;
        }
        if (fread(file_data, 1, file_size, fp) != file_size) {
            free(file_data);
            fclose(fp);
            return false;
        }
    }
    fclose(fp);

    while (!done) {
        size_t left = (offset < file_size) ? (file_size - offset) : 0u;
        size_t chunk = (left > TFTP_BLOCK_SIZE) ? TFTP_BLOCK_SIZE : left;

        if (offset >= file_size) {
            if (sent_zero || (file_size % TFTP_BLOCK_SIZE) != 0u) {
                ok = true;
                break;
            }
            sent_zero = true;
            if (!send_block_with_retries(tfd, peer, file_data, file_size, offset, block)) {
                ok = false;
                break;
            }
            ok = true;
            block++;
            break;
        }
        if (!send_block_with_retries(tfd, peer, file_data, file_size, offset, block)) {
            ok = false;
            break;
        }
        offset += chunk;
        block++;
    }

    free(file_data);
    return ok;
}


static bool is_boot_filename(const char *filename) {
    if (filename == NULL) {
        return false;
    }
    if (strcmp(filename, BOOT_FILE) == 0) {
        return true;
    }
    if (strcmp(filename, BOOT_FILE_BASENAME) == 0) {
        return true;
    }
    if (strcmp(filename, "/BOOTX64.EFI") == 0) {
        return true;
    }
    if (strcmp(filename, "/EFI/BOOT/BOOTX64.EFI") == 0) {
        return true;
    }
    if (strcmp(filename, "\\EFI\\BOOT\\BOOTX64.EFI") == 0) {
        return true;
    }
    if (strcasecmp(filename, "efi/boot/bootx64.efi") == 0) {
        return true;
    }
    if (strcasecmp(filename, "bootx64.efi") == 0) {
        return true;
    }
    return false;
}


static size_t tftp_make_oack(uint8_t *out, size_t out_cap, bool want_tsize, bool want_blksize, bool want_windowsize, size_t file_size) {
    size_t off = 0;
    uint16_t op = htons(TFTP_OP_OACK);
    if (out_cap < 2) return 0;
    memcpy(out + off, &op, 2);
    off += 2;

#define ADD_OPT(k, v) do { \
    const char *kk = (k); const char *vv = (v); \
    size_t kl = strlen(kk) + 1u; size_t vl = strlen(vv) + 1u; \
    if (off + kl + vl > out_cap) return 0; \
    memcpy(out + off, kk, kl); off += kl; \
    memcpy(out + off, vv, vl); off += vl; \
} while (0)

    if (want_tsize) {
        char n[32];
        snprintf(n, sizeof(n), "%lu", (unsigned long)file_size);
        ADD_OPT("tsize", n);
    }
    if (want_blksize) {
        ADD_OPT("blksize", "512");
    }
    if (want_windowsize) {
        ADD_OPT("windowsize", "1");
    }

#undef ADD_OPT
    return off;
}

static bool tftp_rrq_has_option(const char *opt_start, const uint8_t *end, const char *name) {
    const char *p = opt_start;
    while ((const uint8_t *)p < end && *p != '\0') {
        const char *k = p;
        size_t kl = strlen(k);
        p += kl + 1;
        if ((const uint8_t *)p >= end) break;
        const char *v = p;
        size_t vl = strlen(v);
        (void)v;
        p += vl + 1;
        if (strcasecmp(k, name) == 0) return true;
    }
    return false;
}


static void handle_tftp(int sock, const uint8_t *pkt, size_t len, const struct sockaddr_in *src,
                        const char *efi_path) {
    uint16_t opcode;
    const uint8_t *cursor;
    const uint8_t *end;
    const uint8_t *name_end;
    const uint8_t *mode_end;
    char filename[TFTP_FILENAME_BUFFER_SIZE];
    char mode[16];
    size_t name_len;
    size_t mode_len;
    struct stat st;
    size_t file_size;
    int tfd = -1;
    uint8_t oack[TFTP_OACK_BUFFER_SIZE];
    bool has_options;
    bool want_tsize;
    bool want_blksize;
    bool want_windowsize;
    size_t oack_len;
    const uint8_t *opt_start;
    if (len < TFTP_HEADER_BYTES) {
        return;
    }

    opcode = (uint16_t)((uint16_t)pkt[TFTP_OP_HIGH_OFFSET] << 8u |
                        (uint16_t)pkt[TFTP_OP_LOW_OFFSET]);
    if (opcode != TFTP_OP_RRQ) {
        return;
    }

    cursor = &pkt[TFTP_ERROR_CODE_OFFSET];
    end = pkt + len;
    name_end = memchr(cursor, 0, (size_t)(end - cursor));
    if (name_end == NULL) {
        return;
    }
    name_len = (size_t)(name_end - cursor);
    if (name_len >= sizeof(filename)) {
        return;
    }
    memcpy(filename, cursor, name_len);
    filename[name_len] = '\0';

    cursor = name_end + 1u;
    if (cursor >= end) {
        return;
    }
    mode_end = memchr(cursor, 0, (size_t)(end - cursor));
    if (mode_end == NULL) {
        return;
    }
    mode_len = (size_t)(mode_end - cursor);
    if (mode_len >= sizeof(mode)) {
        return;
    }
    memcpy(mode, cursor, mode_len);
    mode[mode_len] = '\0';

    if (strcasecmp(mode, "octet") != 0) {
        send_dhcp_error(sock, src, 0u, "Unsupported mode");
        return;
    }
    if (!is_boot_filename(filename)) {
        send_dhcp_error(sock, src, 1u, "File not found");
        return;
    }
    if (stat(efi_path, &st) != 0) {
        log_line("unable to stat %s", efi_path);
        return;
    }
    if (st.st_size < 0 || st.st_size > (long)NETBOOT_FILE_SIZE_MAX) {
        log_line("invalid EFI size");
        return;
    }
    file_size = (size_t)st.st_size;

    has_options = (mode_end + 1u) < end;
    want_tsize = false;
    want_blksize = false;
    want_windowsize = false;
    if (has_options) {
        opt_start = mode_end + 1u;
        want_tsize = tftp_rrq_has_option((const char *)opt_start, end, "tsize");
        want_blksize = tftp_rrq_has_option((const char *)opt_start, end, "blksize");
        want_windowsize = tftp_rrq_has_option((const char *)opt_start, end, "windowsize");
    }
    tfd = open_dgram_socket(0u, false);
    if (tfd < 0) {
        log_line("unable to allocate TFTP transfer socket");
        return;
    }
    if (has_options) {
        oack_len = tftp_make_oack(oack, sizeof(oack), want_tsize, want_blksize, want_windowsize, file_size);
        if (oack_len == 0u || sendto(tfd, oack, oack_len, 0, (const struct sockaddr *)src, (socklen_t)sizeof(*src)) != (ssize_t)oack_len) {
            close(tfd);
            return;
        }
        if (!wait_for_ack(tfd, src, 0u)) {
            close(tfd);
            return;
        }
    }

    log_line("TFTP RRQ %s", filename);
    if (transfer_boot_file(efi_path, tfd, src)) {
        log_line("TFTP complete");
    } else {
        log_line("TFTP failed");
    }
    close(tfd);
}

int main(int argc, char **argv) {
    NetbootConfig config;
    const char *iface;
    const char *efi_path;
    const char *client_ip;
    const char *mgmt_ip;
    const char *boot_url_host = SERVER_IP;
    uint16_t http_port;
    bool explicit_http_port;
    uint8_t mode;
    bool setup_interface;
    const uint8_t *allow_mac;
    bool has_allow_mac;
    const uint8_t *mgmt_mac;
    bool has_mgmt_mac;
    bool mgmt_dhcp;
    bool force_http_for_pxe;
    bool has_assigned_client = false;
    uint8_t assigned_mac[NETBOOT_MAC_BYTES];
    bool has_assigned_mgmt_client = false;
    uint8_t assigned_mgmt_mac[NETBOOT_MAC_BYTES];
    struct stat st;
    size_t efi_size = 0u;
    int dhcp_sock = -1;
    int tftp_sock = -1;
    int http_sock = -1;
    char boot_url[NETBOOT_BOOT_URL_BUFFER_SIZE];
    char efi_abs_path[NETBOOT_ABSOLUTE_PATH_BUFFER_SIZE];
    bool running = true;
    bool seen_client = false;
    uint8_t buf[NETBOOT_IO_BUFFER_SIZE];
    const char *prog = argv[0];
    int parse_status;

    if (prog == NULL) {
        prog = "edgerun-netboot";
    }

    parse_status = netboot_parse_args(argc, argv, prog, &config);
    if (parse_status == 2) {
        return 0;
    }
    if (parse_status != 0) {
        return 1;
    }
    iface = config.iface;
    efi_path = config.efi_path;
    client_ip = config.client_ip;
    mgmt_ip = config.mgmt_ip;
    http_port = config.http_port;
    explicit_http_port = config.explicit_http_port;
    mode = config.mode;
    setup_interface = config.setup_interface;
    allow_mac = config.allow_mac;
    has_allow_mac = config.has_allow_mac;
    mgmt_mac = config.mgmt_mac;
    has_mgmt_mac = config.has_mgmt_mac;
    mgmt_dhcp = config.mgmt_dhcp;
    force_http_for_pxe = config.force_http_for_pxe;

    if (!make_absolute_path(efi_path, efi_abs_path, sizeof(efi_abs_path))) {
        log_line("unable to resolve EFI path: %s", efi_path);
        return 1;
    }

    if (stat(efi_abs_path, &st) != 0) {
        log_line("unable to stat EFI image: %s", efi_abs_path);
        return 1;
    }
    efi_size = (size_t)st.st_size;

    if (setup_interface && !setup_iface(iface)) {
        return 1;
    }

    dhcp_sock = open_dgram_socket(DHCP_SERVER_PORT, true);
    if (dhcp_sock < 0) {
        return 1;
    }
    if (mode == MODE_AUTO || mode == MODE_TFTP) {
        tftp_sock = open_dgram_socket(TFTP_PORT, false);
        if (tftp_sock < 0) {
            close(dhcp_sock);
            return 1;
        }
    }
    if (mode == MODE_HTTP || mode == MODE_AUTO) {
        http_sock = open_http_listener_with_fallback(&http_port, explicit_http_port);
        if (http_sock < 0) {
            close(dhcp_sock);
            if (tftp_sock >= 0) {
                close(tftp_sock);
            }
            return 1;
        }
    }

    (void)snprintf(boot_url, sizeof(boot_url), "http://%s:%u/%s", boot_url_host, (unsigned)http_port, BOOT_FILE);
    log_line("mode: %s", mode_name(mode));
    log_line("interface: %s", iface);
    log_line("server ip: %s", SERVER_IP);
    log_line("client ip: %s", client_ip);
    log_line("http port: %u", (unsigned)http_port);
    log_line("boot url: %s", boot_url);
    log_line("efi path: %s", efi_abs_path);
    log_line("efi size: %zu", efi_size);
    log_line("force-http-for-pxe: %s", force_http_for_pxe ? "yes" : "no");
    if (has_allow_mac) {
        char allow_buf[32];
        mac_to_str(allow_mac, NETBOOT_MAC_BYTES, allow_buf, sizeof(allow_buf));
        log_line("allow-mac: %s", allow_buf);
    } else {
        log_line("allow-mac: (not set)");
    }
    log_line("mgmt-dhcp: %s", mgmt_dhcp ? "enabled" : "disabled");
    log_line("mgmt-ip: %s", mgmt_ip);
    if (has_mgmt_mac) {
        char mgmt_buf[32];
        mac_to_str(mgmt_mac, NETBOOT_MAC_BYTES, mgmt_buf, sizeof(mgmt_buf));
        log_line("mgmt-mac: %s", mgmt_buf);
    } else {
        log_line("mgmt-mac: (not set)");
    }
    log_line("tftp enabled: %s", (mode == MODE_TFTP || mode == MODE_AUTO) ? "yes" : "no");
    log_line("http enabled: %s", (mode == MODE_HTTP || mode == MODE_AUTO) ? "yes" : "no");

    while (running) {
        fd_set fds;
        int max_fd = dhcp_sock;
        int rc;

        FD_ZERO(&fds);
        FD_SET(dhcp_sock, &fds);
        if (http_sock >= 0) {
            FD_SET(http_sock, &fds);
            if (http_sock > max_fd) {
                max_fd = http_sock;
            }
        }
        if (tftp_sock >= 0) {
            FD_SET(tftp_sock, &fds);
            if (tftp_sock > max_fd) {
                max_fd = tftp_sock;
            }
        }

        rc = select(max_fd + 1, &fds, NULL, NULL, NULL);
        if (rc < 0) {
            if (errno == EINTR) {
                continue;
            }
            perror("select");
            running = false;
            break;
        }

        if (FD_ISSET(dhcp_sock, &fds)) {
            struct sockaddr_in peer;
            socklen_t peer_len = (socklen_t)sizeof(peer);
            ssize_t n = recvfrom(dhcp_sock, buf, sizeof(buf), 0, (struct sockaddr *)&peer, &peer_len);
            if (n > 0) {
                seen_client = true;
                handle_dhcp(dhcp_sock, buf, (size_t)n, BOOT_FILE, boot_url,
                            client_ip, mode, force_http_for_pxe, has_allow_mac, allow_mac,
                            mgmt_dhcp, mgmt_ip, has_mgmt_mac, mgmt_mac,
                            &has_assigned_client, assigned_mac,
                            &has_assigned_mgmt_client, assigned_mgmt_mac);
            }
        }

        if (http_sock >= 0 && FD_ISSET(http_sock, &fds)) {
            struct sockaddr_in peer;
            socklen_t peer_len = (socklen_t)sizeof(peer);
            int conn = accept(http_sock, (struct sockaddr *)&peer, &peer_len);
            if (conn >= 0) {
                char peer_ip[64];
                inet_ntop(AF_INET, &peer.sin_addr, peer_ip, sizeof(peer_ip));
                log_line("HTTP connection from %s", peer_ip);
                if (handle_http_client(conn, boot_url_host, http_port, efi_abs_path, efi_size)) {
                    log_line("HTTP transfer complete");
                }
                close(conn);
            }
        }

        if (tftp_sock >= 0 && FD_ISSET(tftp_sock, &fds)) {
            uint8_t tbuf[TFTP_PACKET_BYTES];
            struct sockaddr_in peer;
            socklen_t peer_len = (socklen_t)sizeof(peer);
            ssize_t n = recvfrom(tftp_sock, tbuf, sizeof(tbuf), 0, (struct sockaddr *)&peer, &peer_len);
            if (n > 0) {
                handle_tftp(tftp_sock, tbuf, (size_t)n, &peer, efi_abs_path);
            }
        }
    }

    if (dhcp_sock >= 0) {
        close(dhcp_sock);
    }
    if (tftp_sock >= 0) {
        close(tftp_sock);
    }
    if (http_sock >= 0) {
        close(http_sock);
    }

    (void)seen_client;
    return 0;
}
