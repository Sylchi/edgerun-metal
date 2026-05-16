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

#define SERVER_IP "10.42.0.1"
#define CLIENT_IP_DEFAULT "10.42.0.2"
#define MGMT_IP_DEFAULT "10.42.0.10"
#define SUBNET_MASK "255.255.255.0"
#define ROUTER_IP SERVER_IP
#define DNS_IP SERVER_IP
#define BOOT_FILE "BOOTX64.EFI"
#define HTTP_PORT_DEFAULT 8081u
#define HTTP_PORT_FALLBACK 8080u
#define HTTP_BOOT_PATH "/" BOOT_FILE

#define DHCP_MAGIC 0x63825363u
#define DHCP_CLIENT_PORT 68u
#define DHCP_SERVER_PORT 67u
#define TFTP_PORT 69u

#define TFTP_BLOCK_SIZE 512u
#define TFTP_TIMEOUT_MS 700u
#define TFTP_MAX_RETRIES 8u

enum {
    DHCP_MESSAGE_DISCOVER = 1u,
    DHCP_MESSAGE_OFFER = 2u,
    DHCP_MESSAGE_REQUEST = 3u,
    DHCP_MESSAGE_ACK = 5u,
};

enum {
    DHCP_OPT_SUBNET_MASK = 1u,
    DHCP_OPT_ROUTER = 3u,
    DHCP_OPT_DNS = 6u,
    DHCP_OPT_REQUESTED_IP = 50u,
    DHCP_OPT_LEASE_TIME = 51u,
    DHCP_OPT_DHCP_MSG_TYPE = 53u,
    DHCP_OPT_SERVER_ID = 54u,
    DHCP_OPT_PARAM_REQUEST_LIST = 55u,
    DHCP_OPT_TFTP_SERVER = 66u,
    DHCP_OPT_BOOTFILE_NAME = 67u,
    DHCP_OPT_VENDOR_CLASS = 60u,
    DHCP_OPT_CLIENT_ARCH = 93u,
    DHCP_OPT_CLIENT_MACHINE = 97u,
    DHCP_OPT_END = 255u,
};

enum {
    TFTP_OP_RRQ = 1u,
    TFTP_OP_DATA = 3u,
    TFTP_OP_ACK = 4u,
    TFTP_OP_ERR = 5u,
};

enum {
    MODE_AUTO = 0u,
    MODE_TFTP = 1u,
    MODE_HTTP = 2u,
    MODE_IGNORE = 3u,
    MODE_MANAGEMENT = 4u,
};

enum {
    CLIENT_OTHER = 0u,
    CLIENT_HTTP_BOOT = 1u,
    CLIENT_PXE_BOOT = 2u,
};

typedef struct __attribute__((packed)) {
    uint8_t op;
    uint8_t htype;
    uint8_t hlen;
    uint8_t hops;
    uint32_t xid;
    uint16_t secs;
    uint16_t flags;
    uint32_t ciaddr;
    uint32_t yiaddr;
    uint32_t siaddr;
    uint32_t giaddr;
    uint8_t chaddr[16];
    uint8_t sname[64];
    uint8_t file[128];
    uint32_t magic;
    uint8_t options[312];
} dhcp_packet_t;

static void log_line(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vprintf(fmt, args);
    printf("\n");
    va_end(args);
    fflush(stdout);
}

static void usage(const char *prog) {
    log_line("Usage:");
    log_line("  %s --iface <name> --efi <path-to-BOOTX64.EFI> [--setup-iface] [--http] [--tftp] [--auto] [--mode <auto|http|tftp>]", prog);
    log_line("  [--http-port <port>] [--allow-mac <aa:bb:cc:dd:ee:ff>] [--client-ip <10.42.0.2>] [--force-http-for-pxe]");
    log_line("  [--mgmt-dhcp] [--mgmt-mac <aa:bb:cc:dd:ee:ff>] [--mgmt-ip <10.42.0.10>]");
    log_line("  --help");
}

static bool make_absolute_path(const char *input, char *output, size_t output_size) {
    char cwd[1024];
    if (input == NULL || output == NULL || output_size == 0u) {
        return false;
    }
    if (input[0] == '/') {
        (void)snprintf(output, output_size, "%s", input);
        return true;
    }
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        return false;
    }
    (void)snprintf(output, output_size, "%s/%s", cwd, input);
    return true;
}

static bool run_cmd(const char *fmt, const char *iface) {
    char cmd[256];
    int rc;

    (void)snprintf(cmd, sizeof(cmd), fmt, iface);
    rc = system(cmd);
    if (rc != 0) {
        log_line("command failed: %s", cmd);
        return false;
    }
    return true;
}

static bool setup_iface(const char *iface) {
    if (!run_cmd("ip link set %s down", iface)) {
        return false;
    }
    if (!run_cmd("ip addr flush dev %s", iface)) {
        return false;
    }
    if (!run_cmd("ip addr add 10.42.0.1/24 dev %s", iface)) {
        return false;
    }
    if (!run_cmd("ip link set %s up", iface)) {
        return false;
    }
    return true;
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
    p[0] = code;
    p[1] = 1;
    p[2] = v;
    return 3;
}

static size_t dhcp_append_u32(uint8_t *p, uint8_t code, uint32_t v_host) {
    uint32_t v = htonl(v_host);
    p[0] = code;
    p[1] = 4;
    memcpy(p + 2, &v, 4);
    return 6;
}

static size_t dhcp_append_ipv4(uint8_t *p, uint8_t code, const char *ip) {
    struct in_addr addr;
    if (inet_pton(AF_INET, ip, &addr) != 1) {
        addr.s_addr = 0u;
    }
    p[0] = code;
    p[1] = 4;
    memcpy(p + 2, &addr.s_addr, 4);
    return 6;
}


static size_t dhcp_append_bytes(uint8_t *p, uint8_t code, const uint8_t *v, uint8_t len) {
    p[0] = code;
    p[1] = len;
    memcpy(p + 2, v, len);
    return (size_t)(2 + len);
}

static size_t build_dhcp_reply(dhcp_packet_t *out, const dhcp_packet_t *in, uint8_t dhcp_msg,
                              const char *boot_file, const char *client_ip, uint8_t mode,
                              bool is_pxe_client, bool has_arch, uint16_t arch,
                              const uint8_t *machine_id, uint8_t machine_id_len) {
    uint8_t *p;
    size_t boot_len;
    size_t max_len;

    memset(out, 0, sizeof(*out));
    out->op = 2;
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
    (void)snprintf((char *)out->sname, sizeof(out->sname), "%s", "edgerun");
    out->magic = htonl(DHCP_MAGIC);

    p = out->options;
    p += dhcp_append_u8(p, DHCP_OPT_DHCP_MSG_TYPE, dhcp_msg);
    p += dhcp_append_ipv4(p, DHCP_OPT_SERVER_ID, SERVER_IP);
    p += dhcp_append_u32(p, DHCP_OPT_LEASE_TIME, 3600u);
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
    char out[256];
    size_t i;
    size_t out_len = 0u;

    out_len = 0u;
    for (i = 0; i < (size_t)len && out_len < (sizeof(out) - 1u); i++) {
        if (isprint((int)data[i]) && data[i] < 127u) {
            out[out_len++] = (char)data[i];
        } else {
            out[out_len++] = '.';
        }
    }
    out[out_len] = '\0';
    log_line("%s: %s", label, out_len ? out : "<empty>");
}

static void print_bytes_list_hex(const char *label, const uint8_t *data, uint8_t len) {
    char out[256];
    size_t off = 0u;
    size_t i;

    if (label == NULL) {
        return;
    }
    if (data == NULL || len == 0u) {
        log_line("%s: <none>", label);
        return;
    }

    for (i = 0u; i < (size_t)len && off < (sizeof(out) - 4u); i++) {
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
    if (data == NULL || len != 4u) {
        print_bytes_list_hex(label, data, len);
        return;
    }
    log_line("%s: %u.%u.%u.%u", label, data[0], data[1], data[2], data[3]);
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
        if (isprint((int)data[i]) && data[i] < 127u) {
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
    if (strncmp(vendor, "HTTPClient", 10u) == 0) {
        return CLIENT_HTTP_BOOT;
    }
    if (strncmp(vendor, "PXEClient", 9u) == 0) {
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

static bool parse_mac(const char *s, uint8_t *out) {
    unsigned int b0, b1, b2, b3, b4, b5;
    int consumed = -1;

    if (s == NULL || *s == '\0') {
        return false;
    }
    if (sscanf(s, "%2x:%2x:%2x:%2x:%2x:%2x%n", &b0, &b1, &b2, &b3, &b4, &b5, &consumed) != 6) {
        return false;
    }
    if (s[consumed] != '\0') {
        return false;
    }
    out[0] = (uint8_t)b0;
    out[1] = (uint8_t)b1;
    out[2] = (uint8_t)b2;
    out[3] = (uint8_t)b3;
    out[4] = (uint8_t)b4;
    out[5] = (uint8_t)b5;
    return true;
}

static bool mac_match(const uint8_t *a, const uint8_t *b) {
    return memcmp(a, b, 6u) == 0;
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

    for (i = 0; i < (size_t)(len < 6u ? len : 6u); i++) {
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
    char vendor[128];
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
    if (req->op != 1u) {
        return;
    }

    opts_len = len - offsetof(dhcp_packet_t, options);
    if (!get_option(req->options, opts_len, DHCP_OPT_DHCP_MSG_TYPE, &v, &l) || l != 1u) {
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
    if (get_option(req->options, opts_len, DHCP_OPT_CLIENT_ARCH, &v, &l) && l == 2u) {
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
            memcpy(assigned_mgmt_mac, req->chaddr, 6u);
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
                memcpy(assigned_mac, req->chaddr, 6u);
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
    uint8_t pkt[516];
    size_t len = strlen(msg);
    uint16_t code_net = htons(code);
    size_t total;

    if (len > sizeof(pkt) - 5u) {
        len = sizeof(pkt) - 5u;
    }
    pkt[0] = 0;
    pkt[1] = TFTP_OP_ERR;
    memcpy(&pkt[2], &code_net, 2);
    memcpy(&pkt[4], msg, len);
    pkt[4 + len] = 0;
    total = 5u + len;
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

    if (listen(fd, 4) < 0) {
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
    uint8_t buf[4096];
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
    char request[1024];
    char method[16];
    char target[512];
    char version[16];
    char expect_abs[512];
    char expect_path[16];
    const char *body;
    char resp_header[512];
    ssize_t n;

    memset(request, 0, sizeof(request));
    n = recv(sock, request, sizeof(request) - 1u, 0);
    if (n <= 0) {
        return false;
    }
    request[sizeof(request) - 1u] = '\0';

    if (sscanf(request, "%15s %511s %15s", method, target, version) != 3) {
        return false;
    }
    log_line("HTTP request: %s %s %s", method, target, version);
    snprintf(expect_path, sizeof(expect_path), "/%s", BOOT_FILE);
    snprintf(expect_abs, sizeof(expect_abs), "http://%s:%u%s", req_host, (unsigned)port, expect_path);

    if ((strcasecmp(method, "GET") != 0) || (strcmp(version, "HTTP/1.0") != 0 && strcmp(version, "HTTP/1.1") != 0) ||
        ((strcmp(target, expect_path) != 0) && (strcmp(target, expect_abs) != 0))) {
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
        uint8_t buf[516];
        int rc;
        ssize_t n;

        FD_ZERO(&fds);
        FD_SET(sock, &fds);
        rc = select(sock + 1, &fds, NULL, NULL, &tv);
        if (rc <= 0) {
            return false;
        }
        n = recvfrom(sock, buf, sizeof(buf), 0, (struct sockaddr *)&src, &src_len);
        if (n < 4 || !is_same_peer(&src, peer)) {
            continue;
        }
        if (buf[0] != 0 || buf[1] != TFTP_OP_ACK) {
            continue;
        }
        if (((uint16_t)buf[2] << 8u | (uint16_t)buf[3]) == expected_block) {
            return true;
        }
    }
}

static bool send_block_with_retries(int sock, const struct sockaddr_in *peer, const uint8_t *file_data,
                                   size_t file_size, size_t offset, uint16_t block) {
    size_t left;
    size_t chunk;
    uint8_t packet[4 + TFTP_BLOCK_SIZE];

    left = (offset < file_size) ? (file_size - offset) : 0u;
    if (left > TFTP_BLOCK_SIZE) {
        chunk = TFTP_BLOCK_SIZE;
    } else {
        chunk = left;
    }

    packet[0] = 0;
    packet[1] = TFTP_OP_DATA;
    packet[2] = (uint8_t)(block >> 8u);
    packet[3] = (uint8_t)block;
    if (chunk > 0u) {
        memcpy(&packet[4], file_data + offset, chunk);
    }

    for (uint32_t attempt = 0u; attempt < TFTP_MAX_RETRIES; attempt++) {
        ssize_t sent = sendto(sock, packet, 4u + chunk, 0, (const struct sockaddr *)peer, (socklen_t)sizeof(*peer));
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

static bool transfer_boot_file(const char *path, const struct sockaddr_in *peer) {
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
    if (size_long < 0 || size_long > (long)0x7fffffff) {
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

    int tfd = open_dgram_socket(0, false);
    if (tfd < 0) {
        free(file_data);
        return false;
    }

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

    close(tfd);
    free(file_data);
    return ok;
}

static void handle_tftp(int sock, const uint8_t *pkt, size_t len, const struct sockaddr_in *src,
                        const char *efi_path) {
    uint16_t opcode;
    const uint8_t *cursor;
    const uint8_t *end;
    const uint8_t *name_end;
    const uint8_t *mode_end;
    char filename[260];
    char mode[16];
    size_t name_len;
    size_t mode_len;
    if (len < 4u) {
        return;
    }

    opcode = (uint16_t)((uint16_t)pkt[0] << 8u | (uint16_t)pkt[1]);
    if (opcode != TFTP_OP_RRQ) {
        return;
    }

    cursor = &pkt[2];
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
    if (strcmp(filename, BOOT_FILE) != 0) {
        send_dhcp_error(sock, src, 1u, "File not found");
        return;
    }

    log_line("TFTP RRQ %s", filename);
    if (transfer_boot_file(efi_path, src)) {
        log_line("TFTP complete");
    } else {
        log_line("TFTP failed");
    }
}

static bool parse_bool_value(const char *value) {
    if (value == NULL) {
        return true;
    }
    if (strcasecmp(value, "1") == 0) {
        return true;
    }
    if (strcasecmp(value, "true") == 0 || strcasecmp(value, "yes") == 0 || strcasecmp(value, "on") == 0) {
        return true;
    }
    return false;
}

static bool parse_mode_arg(const char *value, uint8_t *mode) {
    if (strcasecmp(value, "auto") == 0) {
        *mode = MODE_AUTO;
        return true;
    }
    if (strcasecmp(value, "http") == 0) {
        *mode = MODE_HTTP;
        return true;
    }
    if (strcasecmp(value, "tftp") == 0) {
        *mode = MODE_TFTP;
        return true;
    }
    return false;
}

int main(int argc, char **argv) {
    const char *iface = NULL;
    const char *efi_path = NULL;
    const char *client_ip = CLIENT_IP_DEFAULT;
    const char *mgmt_ip = MGMT_IP_DEFAULT;
    const char *boot_url_host = SERVER_IP;
    uint16_t http_port = HTTP_PORT_DEFAULT;
    bool explicit_http_port = false;
    uint8_t mode = MODE_AUTO;
    bool setup_interface = false;
    uint8_t allow_mac[6];
    bool has_allow_mac = false;
    uint8_t mgmt_mac[6];
    bool has_mgmt_mac = false;
    bool mgmt_dhcp = false;
    bool force_http_for_pxe = false;
    bool has_assigned_client = false;
    uint8_t assigned_mac[6];
    bool has_assigned_mgmt_client = false;
    uint8_t assigned_mgmt_mac[6];
    struct stat st;
    size_t efi_size = 0u;
    int dhcp_sock = -1;
    int tftp_sock = -1;
    int http_sock = -1;
    char boot_url[128];
    char efi_abs_path[4096];
    bool running = true;
    bool seen_client = false;
    bool parse_done;
    uint8_t buf[2048];
    const char *prog = argv[0];
    int i;

    if (prog == NULL) {
        prog = "edgerun-netboot";
    }

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            usage(prog);
            return 0;
        }
        if (strcmp(argv[i], "--iface") == 0) {
            if (i + 1 >= argc) {
                log_line("--iface requires an argument");
                usage(prog);
                return 1;
            }
            iface = argv[++i];
            continue;
        }
        if (strcmp(argv[i], "--efi") == 0) {
            if (i + 1 >= argc) {
                log_line("--efi requires an argument");
                usage(prog);
                return 1;
            }
            efi_path = argv[++i];
            continue;
        }
        if (strcmp(argv[i], "--http-port") == 0) {
            char *end = NULL;
            long val;
            if (i + 1 >= argc) {
                log_line("--http-port requires an argument");
                usage(prog);
                return 1;
            }
            val = strtol(argv[++i], &end, 10);
            if (end == NULL || *end != '\0' || val <= 0 || val > 65535) {
                log_line("invalid --http-port value");
                usage(prog);
                return 1;
            }
            http_port = (uint16_t)val;
            explicit_http_port = true;
            continue;
        }
        if (strcmp(argv[i], "--setup-iface") == 0) {
            setup_interface = true;
            continue;
        }
        if (strcmp(argv[i], "--mgmt-dhcp") == 0) {
            mgmt_dhcp = true;
            continue;
        }
        if (strncmp(argv[i], "--mgmt-dhcp=", 12) == 0) {
            mgmt_dhcp = parse_bool_value(argv[i] + 12);
            continue;
        }
        if (strcmp(argv[i], "--http") == 0) {
            mode = MODE_HTTP;
            continue;
        }
        if (strcmp(argv[i], "--tftp") == 0) {
            mode = MODE_TFTP;
            continue;
        }
        if (strcmp(argv[i], "--auto") == 0) {
            mode = MODE_AUTO;
            continue;
        }
        if (strcmp(argv[i], "--mode") == 0) {
            uint8_t parsed;
            if (i + 1 >= argc) {
                log_line("--mode requires an argument");
                usage(prog);
                return 1;
            }
            parse_done = parse_mode_arg(argv[++i], &parsed);
            if (!parse_done) {
                log_line("--mode expects auto|http|tftp");
                usage(prog);
                return 1;
            }
            mode = parsed;
            continue;
        }
        if (strcmp(argv[i], "--allow-mac") == 0) {
            if (i + 1 >= argc) {
                log_line("--allow-mac requires an argument");
                usage(prog);
                return 1;
            }
            {
                const char *mac_arg = argv[++i];
                if (*mac_arg == '\0') {
                    has_allow_mac = false;
                    continue;
                }
                if (!parse_mac(mac_arg, allow_mac)) {
                    log_line("invalid --allow-mac value");
                    usage(prog);
                    return 1;
                }
                has_allow_mac = true;
            }
            continue;
        }
        if (strcmp(argv[i], "--mgmt-mac") == 0) {
            if (i + 1 >= argc) {
                log_line("--mgmt-mac requires an argument");
                usage(prog);
                return 1;
            }
            {
                const char *mac_arg = argv[++i];
                if (*mac_arg == '\0') {
                    has_mgmt_mac = false;
                    continue;
                }
                if (!parse_mac(mac_arg, mgmt_mac)) {
                    log_line("invalid --mgmt-mac value");
                    usage(prog);
                    return 1;
                }
                has_mgmt_mac = true;
            }
            continue;
        }
        if (strcmp(argv[i], "--client-ip") == 0) {
            struct in_addr tmp;
            if (i + 1 >= argc) {
                log_line("--client-ip requires an argument");
                usage(prog);
                return 1;
            }
            client_ip = argv[++i];
            if (inet_pton(AF_INET, client_ip, &tmp) != 1) {
                log_line("invalid --client-ip value");
                usage(prog);
                return 1;
            }
            continue;
        }
        if (strcmp(argv[i], "--mgmt-ip") == 0) {
            struct in_addr tmp;
            if (i + 1 >= argc) {
                log_line("--mgmt-ip requires an argument");
                usage(prog);
                return 1;
            }
            mgmt_ip = argv[++i];
            if (inet_pton(AF_INET, mgmt_ip, &tmp) != 1) {
                log_line("invalid --mgmt-ip value");
                usage(prog);
                return 1;
            }
            continue;
        }
        if (strcmp(argv[i], "--force-http-for-pxe") == 0) {
            force_http_for_pxe = true;
            continue;
        }
        if (strncmp(argv[i], "--force-http-for-pxe=", 21) == 0) {
            force_http_for_pxe = parse_bool_value(argv[i] + 21);
            continue;
        }
        if (strncmp(argv[i], "--client-ip=", 11) == 0) {
            struct in_addr tmp;
            client_ip = argv[i] + 11;
            if (inet_pton(AF_INET, client_ip, &tmp) != 1) {
                log_line("invalid --client-ip value");
                usage(prog);
                return 1;
            }
            continue;
        }
        if (strncmp(argv[i], "--mgmt-ip=", 9) == 0) {
            struct in_addr tmp;
            mgmt_ip = argv[i] + 9;
            if (inet_pton(AF_INET, mgmt_ip, &tmp) != 1) {
                log_line("invalid --mgmt-ip value");
                usage(prog);
                return 1;
            }
            continue;
        }
        if (strncmp(argv[i], "--allow-mac=", 12) == 0) {
            const char *mac_arg = argv[i] + 12;
            if (*mac_arg == '\0') {
                has_allow_mac = false;
                continue;
            }
            if (!parse_mac(mac_arg, allow_mac)) {
                log_line("invalid --allow-mac value");
                usage(prog);
                return 1;
            }
            has_allow_mac = true;
            continue;
        }
        if (strncmp(argv[i], "--mgmt-mac=", 10) == 0) {
            const char *mac_arg = argv[i] + 10;
            if (*mac_arg == '\0') {
                has_mgmt_mac = false;
                continue;
            }
            if (!parse_mac(mac_arg, mgmt_mac)) {
                log_line("invalid --mgmt-mac value");
                usage(prog);
                return 1;
            }
            has_mgmt_mac = true;
            continue;
        }
        if (strncmp(argv[i], "--mode=", 7) == 0) {
            uint8_t parsed;
            parse_done = parse_mode_arg(argv[i] + 7, &parsed);
            if (!parse_done) {
                log_line("--mode expects auto|http|tftp");
                usage(prog);
                return 1;
            }
            mode = parsed;
            continue;
        }
        if (strncmp(argv[i], "--iface=", 8) == 0) {
            iface = argv[i] + 8;
            continue;
        }
        if (strncmp(argv[i], "--efi=", 6) == 0) {
            efi_path = argv[i] + 6;
            continue;
        }
        if (strncmp(argv[i], "--http-port=", 12) == 0) {
            char *end = NULL;
            long val = strtol(argv[i] + 12, &end, 10);
            if (end == NULL || *end != '\0' || val <= 0 || val > 65535) {
                log_line("invalid --http-port value");
                usage(prog);
                return 1;
            }
            http_port = (uint16_t)val;
            explicit_http_port = true;
            continue;
        }
        log_line("unknown option: %s", argv[i]);
        usage(prog);
        return 1;
    }

    if (iface == NULL) {
        log_line("missing --iface");
        usage(prog);
        return 1;
    }
    if (efi_path == NULL) {
        log_line("missing --efi");
        usage(prog);
        return 1;
    }

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
        mac_to_str(allow_mac, 6u, allow_buf, sizeof(allow_buf));
        log_line("allow-mac: %s", allow_buf);
    } else {
        log_line("allow-mac: (not set)");
    }
    log_line("mgmt-dhcp: %s", mgmt_dhcp ? "enabled" : "disabled");
    log_line("mgmt-ip: %s", mgmt_ip);
    if (has_mgmt_mac) {
        char mgmt_buf[32];
        mac_to_str(mgmt_mac, 6u, mgmt_buf, sizeof(mgmt_buf));
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
            uint8_t tbuf[516];
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
