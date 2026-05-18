#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define SERVER_IP "10.42.0.1"
#define BOOT_FILE "BOOTX64.EFI"
#define MAGIC 0x63825363u
#define PORT 4011u
#define DHCP_CLIENT_PORT 68u
#define DHCP_OP_BOOTREQUEST 1u
#define DHCP_OP_BOOTREPLY 2u
#define DHCP_MESSAGE_OFFER 2u
#define DHCP_OPTION_CODE_OFFSET 0u
#define DHCP_OPTION_LEN_OFFSET 1u
#define DHCP_OPTION_VALUE_OFFSET 2u
#define DHCP_OPTION_U8_LEN 1u
#define DHCP_OPTION_IPV4_LEN 4u
#define DHCP_OPTION_U8_TOTAL_LEN 3u
#define DHCP_OPTION_IPV4_TOTAL_LEN 6u
#define DHCP_OPTION_MAX_LEN 255u
#define PXE_VENDOR_CLASS "PXEClient"
#define PXE_RECV_BUFFER_SIZE 1500u
#define PXE_MAC_TEXT_SIZE 32u
#define PXE_MAC_BYTE0 0u
#define PXE_MAC_BYTE1 1u
#define PXE_MAC_BYTE2 2u
#define PXE_MAC_BYTE3 3u
#define PXE_MAC_BYTE4 4u
#define PXE_MAC_BYTE5 5u

#define OPT_MSG 53u
#define OPT_SERVER 54u
#define OPT_VENDOR 60u
#define OPT_TFTP 66u
#define OPT_FILE 67u
#define OPT_END 255u

typedef struct __attribute__((packed)) {
    uint8_t op, htype, hlen, hops;
    uint32_t xid;
    uint16_t secs, flags;
    uint32_t ciaddr, yiaddr, siaddr, giaddr;
    uint8_t chaddr[16];
    uint8_t sname[64];
    uint8_t file[128];
    uint32_t magic;
    uint8_t options[312];
} pkt_t;

static size_t opt_u8(uint8_t *p, uint8_t code, uint8_t val) {
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = DHCP_OPTION_U8_LEN;
    p[DHCP_OPTION_VALUE_OFFSET] = val;
    return DHCP_OPTION_U8_TOTAL_LEN;
}

static size_t opt_ip(uint8_t *p, uint8_t code, const char *ip) {
    struct in_addr a;
    if (inet_pton(AF_INET, ip, &a) != 1) a.s_addr = 0;
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = DHCP_OPTION_IPV4_LEN;
    memcpy(p + DHCP_OPTION_VALUE_OFFSET, &a.s_addr, DHCP_OPTION_IPV4_LEN);
    return DHCP_OPTION_IPV4_TOTAL_LEN;
}

static size_t opt_str(uint8_t *p, uint8_t code, const char *s) {
    size_t n = strlen(s);
    if (n > DHCP_OPTION_MAX_LEN) n = DHCP_OPTION_MAX_LEN;
    p[DHCP_OPTION_CODE_OFFSET] = code;
    p[DHCP_OPTION_LEN_OFFSET] = (uint8_t)n;
    memcpy(p + DHCP_OPTION_VALUE_OFFSET, s, n);
    return n + DHCP_OPTION_VALUE_OFFSET;
}

static size_t build(pkt_t *out, const pkt_t *in) {
    uint8_t *p;
    memset(out, 0, sizeof(*out));
    out->op = DHCP_OP_BOOTREPLY;
    out->htype = in->htype;
    out->hlen = in->hlen;
    out->xid = in->xid;
    out->secs = in->secs;
    out->flags = in->flags;
    out->yiaddr = 0;
    out->siaddr = inet_addr(SERVER_IP);
    memcpy(out->chaddr, in->chaddr, sizeof(out->chaddr));
    snprintf((char *)out->file, sizeof(out->file), "%s", BOOT_FILE);
    out->magic = htonl(MAGIC);

    p = out->options;
    p += opt_u8(p, OPT_MSG, DHCP_MESSAGE_OFFER);
    p += opt_ip(p, OPT_SERVER, SERVER_IP);
    p += opt_str(p, OPT_VENDOR, PXE_VENDOR_CLASS);
    p += opt_str(p, OPT_TFTP, SERVER_IP);
    p += opt_str(p, OPT_FILE, BOOT_FILE);
    *p++ = OPT_END;
    return (size_t)(p - (uint8_t *)out);
}

static void mac(char *out, size_t n, const uint8_t *m) {
    snprintf(out, n, "%02x:%02x:%02x:%02x:%02x:%02x",
             m[PXE_MAC_BYTE0], m[PXE_MAC_BYTE1], m[PXE_MAC_BYTE2],
             m[PXE_MAC_BYTE3], m[PXE_MAC_BYTE4], m[PXE_MAC_BYTE5]);
}

int main(void) {
    int fd;
    int one = 1;
    struct sockaddr_in a;

    fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (fd < 0) { perror("socket"); return 1; }

    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &one, sizeof(one));

    memset(&a, 0, sizeof(a));
    a.sin_family = AF_INET;
    a.sin_port = htons(PORT);
    a.sin_addr.s_addr = INADDR_ANY;

    if (bind(fd, (struct sockaddr *)&a, sizeof(a)) < 0) {
        perror("bind 4011");
        return 1;
    }

    printf("edgerun-pxe4011 listening udp/%u boot=%s server=%s\n", PORT, BOOT_FILE, SERVER_IP);
    fflush(stdout);

    for (;;) {
        uint8_t buf[PXE_RECV_BUFFER_SIZE];
        pkt_t reply;
        struct sockaddr_in src, dst;
        socklen_t sl = sizeof(src);
        ssize_t got = recvfrom(fd, buf, sizeof(buf), 0, (struct sockaddr *)&src, &sl);
        size_t len;
        char m[PXE_MAC_TEXT_SIZE];

        if (got < (ssize_t)(sizeof(pkt_t) - sizeof(((pkt_t *)0)->options))) continue;

        const pkt_t *req = (const pkt_t *)buf;
        if (req->op != DHCP_OP_BOOTREQUEST || req->magic != htonl(MAGIC)) continue;

        len = build(&reply, req);

        memset(&dst, 0, sizeof(dst));
        dst.sin_family = AF_INET;
        dst.sin_port = htons(DHCP_CLIENT_PORT);
        dst.sin_addr.s_addr = INADDR_BROADCAST;

        mac(m, sizeof(m), req->chaddr);
        printf("edgerun-pxe4011 request xid=0x%08x mac=%s -> %s\n", ntohl(req->xid), m, BOOT_FILE);
        fflush(stdout);

        if (sendto(fd, &reply, len, 0, (struct sockaddr *)&dst, sizeof(dst)) < 0) {
            perror("sendto");
        }
    }
}
