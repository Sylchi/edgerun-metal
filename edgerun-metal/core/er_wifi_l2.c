#include "er_wifi_l2.h"
#include "er_mem.h"

/*
 * Purpose: derive deterministic L2 radio identifiers from node identity.
 * Intention: AP naming and Ethernet framing stay explicit and address-free.
 */

enum {
  ER_WIFI_L2_SSID_PREFIX_E_OFFSET = 0u,
  ER_WIFI_L2_SSID_PREFIX_R_OFFSET = 1u,
  ER_WIFI_L2_SSID_PREFIX_DASH_OFFSET = 2u,
  ER_WIFI_L2_SSID_HEX_OFFSET = 3u,
  ER_WIFI_L2_SSID_NODE_BYTES = 8u,
  ER_WIFI_L2_HEX_DIGITS_PER_BYTE = 2u,
  ER_WIFI_L2_HEX_HIGH_NIBBLE_SHIFT = 4u,
  ER_WIFI_L2_HEX_NIBBLE_MASK = 0x0fu,
  ER_WIFI_L2_MAC_LOCAL_UNICAST = 0x02u,
  ER_WIFI_L2_MAC_NODE_BYTE_COUNT = 5u,
  ER_WIFI_L2_MAC_NODE_OFFSET = 1u,
  ER_WIFI_L2_MAC_BYTE_MASK = 0xffu,
  ER_WIFI_L2_MIN_CHANNEL = 1u,
  ER_WIFI_L2_MAX_CHANNEL = 14u
};

static UINT8 er_wifi_l2_hex_digit(UINT8 value) {
  UINT8 digit = (UINT8)(value & ER_WIFI_L2_HEX_NIBBLE_MASK);

  if (digit < 10u) {
    return (UINT8)('0' + digit);
  }
  return (UINT8)('a' + (digit - 10u));
}

static UINT8 er_wifi_l2_channel_valid(UINT8 channel) {
  return (UINT8)(channel >= ER_WIFI_L2_MIN_CHANNEL &&
                 channel <= ER_WIFI_L2_MAX_CHANNEL);
}

UINT8 er_wifi_l2_node_mac(const ErNodeId* node_id,
                          UINT8 out_mac[ER_NET_MAC_LEN]) {
  UINT8 i;

  if (er_node_id_nonzero(node_id) == 0u || out_mac == 0) {
    return 0u;
  }
  out_mac[0] = ER_WIFI_L2_MAC_LOCAL_UNICAST;
  for (i = 0u; i < ER_WIFI_L2_MAC_NODE_BYTE_COUNT; ++i) {
    out_mac[ER_WIFI_L2_MAC_NODE_OFFSET + i] =
        (UINT8)(node_id->bytes[i] ^
                node_id->bytes[i + ER_WIFI_L2_MAC_NODE_BYTE_COUNT] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT * 2u)] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT * 3u)] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT * 4u)] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT * 5u)] ^
                node_id->bytes[ER_NODE_ID_LEN - 1u - i]);
  }
  out_mac[0] &= (UINT8)~1u;
  out_mac[0] |= ER_WIFI_L2_MAC_LOCAL_UNICAST;
  return 1u;
}

UINT8 er_wifi_l2_node_ssid(const ErNodeId* node_id,
                           UINT8* out_ssid,
                           UINT8 out_capacity,
                           UINT8* out_ssid_len) {
  UINT8 i;
  UINT8 ssid_index;
  UINT8 node_byte;

  if (er_node_id_nonzero(node_id) == 0u ||
      out_ssid == 0 ||
      out_ssid_len == 0 ||
      out_capacity < ER_WIFI_L2_NODE_SSID_LEN) {
    return 0u;
  }
  out_ssid[ER_WIFI_L2_SSID_PREFIX_E_OFFSET] = (UINT8)'e';
  out_ssid[ER_WIFI_L2_SSID_PREFIX_R_OFFSET] = (UINT8)'r';
  out_ssid[ER_WIFI_L2_SSID_PREFIX_DASH_OFFSET] = (UINT8)'-';
  for (i = 0u; i < ER_WIFI_L2_SSID_NODE_BYTES; ++i) {
    node_byte = node_id->bytes[i];
    ssid_index = (UINT8)(ER_WIFI_L2_SSID_HEX_OFFSET +
                         (i * ER_WIFI_L2_HEX_DIGITS_PER_BYTE));
    out_ssid[ssid_index] =
        er_wifi_l2_hex_digit((UINT8)(node_byte >> ER_WIFI_L2_HEX_HIGH_NIBBLE_SHIFT));
    out_ssid[ssid_index + 1u] = er_wifi_l2_hex_digit(node_byte);
  }
  *out_ssid_len = ER_WIFI_L2_NODE_SSID_LEN;
  return 1u;
}

UINT8 er_wifi_l2_ap_plan_prepare(const ErNodeId* node_id,
                                 UINT8 channel,
                                 ErWifiL2ApPlan* out_plan) {
  UINT8 ssid_len;

  if (out_plan == 0 ||
      er_wifi_l2_channel_valid(channel) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
  if (er_wifi_l2_node_mac(node_id, out_plan->mac) == 0u ||
      er_wifi_l2_node_ssid(node_id,
                           out_plan->ssid,
                           ER_WIFI_L2_NODE_SSID_CAP,
                           &ssid_len) == 0u) {
    er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
    return 0u;
  }
  out_plan->abi_version = ER_WIFI_L2_ABI_VERSION;
  out_plan->channel = channel;
  out_plan->ssid_len = ssid_len;
  out_plan->eth_type = ER_NET_ETH_TYPE_EDGERUN;
  return 1u;
}

UINT8 er_wifi_l2_ap_plan_valid(const ErWifiL2ApPlan* plan) {
  if (plan == 0 ||
      plan->abi_version != ER_WIFI_L2_ABI_VERSION ||
      er_wifi_l2_channel_valid(plan->channel) == 0u ||
      plan->ssid_len != ER_WIFI_L2_NODE_SSID_LEN ||
      plan->eth_type != ER_NET_ETH_TYPE_EDGERUN ||
      plan->reserved[0] != 0u ||
      plan->reserved[1] != 0u ||
      (plan->mac[0] & 1u) != 0u ||
      (plan->mac[0] & ER_WIFI_L2_MAC_LOCAL_UNICAST) == 0u) {
    return 0u;
  }
  return (UINT8)(plan->ssid[ER_WIFI_L2_SSID_PREFIX_E_OFFSET] == (UINT8)'e' &&
                 plan->ssid[ER_WIFI_L2_SSID_PREFIX_R_OFFSET] == (UINT8)'r' &&
                 plan->ssid[ER_WIFI_L2_SSID_PREFIX_DASH_OFFSET] == (UINT8)'-');
}
