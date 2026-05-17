#include "er_hw_relay.h"
#include "er_netlog.h"

/*
 * Purpose: implement the first hardware relay endpoint through UEFI UDP4.
 * Intention: packet forwarding is concrete hardware movement, not policy or app execution.
 */

static const char g_default_udp_label[] = "uefi-udp4";
#define ER_HW_RELAY_UDP_WAIT_POLLS 100000u

static void er_hw_relay_zero(UINT8* bytes, UINTN len) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0; i < len; ++i) {
    bytes[i] = 0;
  }
}

static void er_hw_relay_copy(UINT8* dst, const UINT8* src, UINTN len) {
  UINTN i;

  for (i = 0; i < len; ++i) {
    dst[i] = src[i];
  }
}

UINT8 er_hw_relay_prepare_firmware_udp_endpoint(UINT8 a, UINT8 b, UINT8 c, UINT8 d, UINT16 port,
                                                const char* label, UINTN label_len,
                                                ErChannelEndpoint* out_endpoint) {
  if (out_endpoint == 0 || label == 0 || label_len == 0u || label_len > ER_CHANNEL_LABEL_MAX) {
    return 0;
  }

  er_hw_relay_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_FIRMWARE_UDP;
  out_endpoint->address_len = ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN;
  out_endpoint->label_len = (UINT16)label_len;
  out_endpoint->address[0] = a;
  out_endpoint->address[1] = b;
  out_endpoint->address[2] = c;
  out_endpoint->address[3] = d;
  out_endpoint->address[4] = (UINT8)((port >> 8) & 0xffu);
  out_endpoint->address[5] = (UINT8)(port & 0xffu);
  er_hw_relay_copy((UINT8*)out_endpoint->label, (const UINT8*)label, label_len);
  return 1;
}

UINT8 er_hw_relay_default_firmware_udp_endpoint(ErChannelEndpoint* out_endpoint) {
  return er_hw_relay_prepare_firmware_udp_endpoint(10u, 42u, 0u, 1u, ER_HW_RELAY_FIRMWARE_UDP_PORT,
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
