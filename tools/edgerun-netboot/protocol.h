#ifndef EDGERUN_NETBOOT_PROTOCOL_H
#define EDGERUN_NETBOOT_PROTOCOL_H

/*
 * Purpose: collect the fixed protocol constants used by the netboot helper.
 * Intention: keep DHCP/TFTP/HTTP wire values separate from server control flow.
 */

#include <stdint.h>

#define SERVER_IP "10.42.0.1"
#define CLIENT_IP_DEFAULT "10.42.0.2"
#define MGMT_IP_DEFAULT "10.42.0.10"
#define SUBNET_MASK "255.255.255.0"
#define ROUTER_IP SERVER_IP
#define DNS_IP SERVER_IP
#define BOOT_FILE "BOOTX64.EFI"
#define BOOT_FILE_BASENAME "BOOTX64.EFI"
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
#define TFTP_OP_OACK 6u

#define NETBOOT_PATH_BUFFER_SIZE 1024u
#define NETBOOT_COMMAND_BUFFER_SIZE 256u
#define NETBOOT_TEXT_BUFFER_SIZE 256u
#define NETBOOT_VENDOR_BUFFER_SIZE 128u
#define NETBOOT_HTTP_REQUEST_BUFFER_SIZE 1024u
#define NETBOOT_HTTP_TARGET_BUFFER_SIZE 512u
#define NETBOOT_HTTP_HEADER_BUFFER_SIZE 512u
#define NETBOOT_HTTP_PATH_BUFFER_SIZE 64u
#define NETBOOT_FILE_BUFFER_SIZE 4096u
#define NETBOOT_ABSOLUTE_PATH_BUFFER_SIZE 4096u
#define NETBOOT_BOOT_URL_BUFFER_SIZE 128u
#define NETBOOT_IO_BUFFER_SIZE 2048u
#define NETBOOT_FILE_SIZE_MAX 0x7fffffff
#define NETBOOT_PRINTABLE_ASCII_LIMIT 127u
#define NETBOOT_DECIMAL_BYTE_TEXT_ROOM 4u
#define NETBOOT_IPV4_BYTES 4u
#define NETBOOT_MAC_BYTES 6u
#define NETBOOT_VENDOR_HTTP "HTTPClient"
#define NETBOOT_VENDOR_PXE "PXEClient"
#define NETBOOT_VENDOR_HTTP_LEN 10u
#define NETBOOT_VENDOR_PXE_LEN 9u
#define NETBOOT_HTTP_REQUEST_FIELD_COUNT 3
#define NETBOOT_STRTOL_BASE_DECIMAL 10
#define NETBOOT_TCP_PORT_MAX 65535
#define NETBOOT_OPT_MGMT_DHCP_EQ "--mgmt-dhcp="
#define NETBOOT_OPT_FORCE_HTTP_FOR_PXE_EQ "--force-http-for-pxe="
#define NETBOOT_OPT_CLIENT_IP_EQ "--client-ip="
#define NETBOOT_OPT_MGMT_IP_EQ "--mgmt-ip="
#define NETBOOT_OPT_ALLOW_MAC_EQ "--allow-mac="
#define NETBOOT_OPT_MGMT_MAC_EQ "--mgmt-mac="
#define NETBOOT_OPT_MODE_EQ "--mode="
#define NETBOOT_OPT_IFACE_EQ "--iface="
#define NETBOOT_OPT_EFI_EQ "--efi="
#define NETBOOT_OPT_HTTP_PORT_EQ "--http-port="
#define NETBOOT_LITERAL_LEN(value) (sizeof(value) - 1u)
#define NETBOOT_BYTE0 0u
#define NETBOOT_BYTE1 1u
#define NETBOOT_BYTE2 2u
#define NETBOOT_BYTE3 3u
#define NETBOOT_BYTE4 4u
#define NETBOOT_BYTE5 5u

#define DHCP_OP_BOOTREPLY 2u
#define DHCP_OP_BOOTREQUEST 1u
#define DHCP_OPTION_CODE_OFFSET 0u
#define DHCP_OPTION_LEN_OFFSET 1u
#define DHCP_OPTION_VALUE_OFFSET 2u
#define DHCP_OPTION_U8_PAYLOAD_LEN 1u
#define DHCP_OPTION_U32_PAYLOAD_LEN 4u
#define DHCP_OPTION_ARCH_PAYLOAD_LEN 2u
#define DHCP_OPTION_MSG_TYPE_PAYLOAD_LEN 1u
#define DHCP_OPTION_U8_TOTAL_LEN 3u
#define DHCP_OPTION_U32_TOTAL_LEN 6u
#define DHCP_LEASE_SECONDS 3600u

#define TFTP_ERROR_PACKET_BYTES 516u
#define TFTP_PACKET_BYTES 516u
#define TFTP_FILENAME_BUFFER_SIZE 260u
#define TFTP_OACK_BUFFER_SIZE 256u
#define TFTP_HEADER_BYTES 4u
#define TFTP_MIN_ACK_BYTES 4
#define TFTP_OP_HIGH_OFFSET 0u
#define TFTP_OP_LOW_OFFSET 1u
#define TFTP_BLOCK_HIGH_OFFSET 2u
#define TFTP_BLOCK_LOW_OFFSET 3u
#define TFTP_PAYLOAD_OFFSET 4u
#define TFTP_ERROR_CODE_OFFSET 2u
#define TFTP_ERROR_MSG_OFFSET 4u
#define TFTP_ERROR_OVERHEAD_BYTES 5u
#define HTTP_LISTEN_BACKLOG 4

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

#endif
