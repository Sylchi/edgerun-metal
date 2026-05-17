#include "er_hw_relay.h"
#include "er_mem.h"
#include "er_netlog.h"

/*
 * Purpose: implement the first hardware relay endpoint through UEFI UDP4.
 * Intention: packet forwarding is concrete hardware movement, not policy or app execution.
 */

static const char g_default_udp_label[] = "uefi-udp4";
#define ER_HW_RELAY_UDP_WAIT_POLLS 100000u

enum {
  ER_HW_RELAY_ADDR_IPV4_A_INDEX = 0u,
  ER_HW_RELAY_ADDR_IPV4_B_INDEX = 1u,
  ER_HW_RELAY_ADDR_IPV4_C_INDEX = 2u,
  ER_HW_RELAY_ADDR_IPV4_D_INDEX = 3u,
  ER_HW_RELAY_ADDR_PORT_HIGH_INDEX = 4u,
  ER_HW_RELAY_ADDR_PORT_LOW_INDEX = 5u,
  ER_HW_RELAY_PORT_HIGH_SHIFT = 8u,
  ER_HW_RELAY_PORT_BYTE_MASK = 0xffu,
  ER_HW_RELAY_DEFAULT_IP_A = 10u,
  ER_HW_RELAY_DEFAULT_IP_B = 42u,
  ER_HW_RELAY_DEFAULT_IP_C = 0u,
  ER_HW_RELAY_DEFAULT_IP_D = 1u
};

UINT8 er_hw_relay_prepare_firmware_udp_endpoint(UINT8 a, UINT8 b, UINT8 c, UINT8 d, UINT16 port,
                                                const char* label, UINTN label_len,
                                                ErChannelEndpoint* out_endpoint) {
  if (out_endpoint == 0 || label == 0 || label_len == 0u || label_len > ER_CHANNEL_LABEL_MAX) {
    return 0;
  }

  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_FIRMWARE_UDP;
  out_endpoint->address_len = ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN;
  out_endpoint->label_len = (UINT16)label_len;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_A_INDEX] = a;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_B_INDEX] = b;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_C_INDEX] = c;
  out_endpoint->address[ER_HW_RELAY_ADDR_IPV4_D_INDEX] = d;
  out_endpoint->address[ER_HW_RELAY_ADDR_PORT_HIGH_INDEX] =
    (UINT8)((port >> ER_HW_RELAY_PORT_HIGH_SHIFT) & ER_HW_RELAY_PORT_BYTE_MASK);
  out_endpoint->address[ER_HW_RELAY_ADDR_PORT_LOW_INDEX] = (UINT8)(port & ER_HW_RELAY_PORT_BYTE_MASK);
  er_mem_copy((UINT8*)out_endpoint->label, (const UINT8*)label, label_len);
  return 1;
}

UINT8 er_hw_relay_default_firmware_udp_endpoint(ErChannelEndpoint* out_endpoint) {
  return er_hw_relay_prepare_firmware_udp_endpoint(ER_HW_RELAY_DEFAULT_IP_A, ER_HW_RELAY_DEFAULT_IP_B,
                                                  ER_HW_RELAY_DEFAULT_IP_C, ER_HW_RELAY_DEFAULT_IP_D,
                                                  ER_HW_RELAY_FIRMWARE_UDP_PORT,
                                                  g_default_udp_label,
                                                  (UINTN)(sizeof(g_default_udp_label) - 1u),
                                                  out_endpoint);
}

UINT8 er_hw_relay_endpoint_is_firmware_udp(const ErChannelEndpoint* endpoint) {
  if (endpoint == 0 || endpoint->abi_version != ER_WORK_ABI_VERSION ||
      endpoint->kind != ER_CHANNEL_KIND_FIRMWARE_UDP ||
      endpoint->address_len != ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN) {
    return 0;
  }
  return 1;
}

UINT8 er_hw_relay_forward_to_firmware_udp(const ErRelayForwardIntent* intent, const UINT8* packet, UINTN packet_len) {
  if (intent == 0 || packet == 0 || packet_len == 0u) {
    return 0;
  }
  if (intent->abi_version != ER_WORK_ABI_VERSION ||
      er_hw_relay_endpoint_is_firmware_udp(&intent->to) == 0u) {
    return 0;
  }
  if (er_netlog_ready() == 0u) {
    return 0;
  }
  er_netlog_flush_text();
  return er_netlog_write_bytes_wait(packet, packet_len, ER_HW_RELAY_UDP_WAIT_POLLS);
}
