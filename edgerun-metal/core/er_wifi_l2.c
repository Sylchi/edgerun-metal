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
  ER_WIFI_L2_HEX_DECIMAL_DIGITS = 10u,
  ER_WIFI_L2_HEX_HIGH_NIBBLE_SHIFT = 4u,
  ER_WIFI_L2_HEX_NIBBLE_MASK = 0x0fu,
  ER_WIFI_L2_MAC_LOCAL_UNICAST = 0x02u,
  ER_WIFI_L2_MAC_NODE_BYTE_COUNT = 5u,
  ER_WIFI_L2_MAC_NODE_GROUP_2 = 2u,
  ER_WIFI_L2_MAC_NODE_GROUP_3 = 3u,
  ER_WIFI_L2_MAC_NODE_GROUP_4 = 4u,
  ER_WIFI_L2_MAC_NODE_GROUP_5 = 5u,
  ER_WIFI_L2_MAC_NODE_OFFSET = 1u,
  ER_WIFI_L2_MAC_BYTE_MASK = 0xffu,
  ER_WIFI_L2_ETH_TYPE_HIGH_SHIFT = 8u,
  ER_WIFI_L2_MIN_CHANNEL = 1u,
  ER_WIFI_L2_MAX_CHANNEL = 14u
};

static const UINT8 g_er_wifi_l2_control_ssid[ER_WIFI_L2_CONTROL_SSID_LEN] = {
  (UINT8)'E', (UINT8)'d', (UINT8)'g', (UINT8)'e',
  (UINT8)'N', (UINT8)'e', (UINT8)'t'
};

static UINT8 er_wifi_l2_hex_digit(UINT8 value) {
  UINT8 digit = (UINT8)(value & ER_WIFI_L2_HEX_NIBBLE_MASK);

  if (digit < ER_WIFI_L2_HEX_DECIMAL_DIGITS) {
    return (UINT8)('0' + digit);
  }
  return (UINT8)('a' + (digit - ER_WIFI_L2_HEX_DECIMAL_DIGITS));
}

static UINT8 er_wifi_l2_channel_valid(UINT8 channel) {
  return (UINT8)(channel >= ER_WIFI_L2_MIN_CHANNEL &&
                 channel <= ER_WIFI_L2_MAX_CHANNEL);
}

static UINT8 er_wifi_l2_ssid_valid(const UINT8* ssid, UINT8 ssid_len) {
  if (ssid == 0 || ssid_len == 0u || ssid_len > ER_WIFI_L2_NODE_SSID_CAP) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_wifi_l2_node_ssid_valid(const UINT8* ssid, UINT8 ssid_len) {
  return (UINT8)(er_wifi_l2_ssid_valid(ssid, ssid_len) != 0u &&
                 ssid_len == ER_WIFI_L2_NODE_SSID_LEN &&
                 ssid[ER_WIFI_L2_SSID_PREFIX_E_OFFSET] == (UINT8)'e' &&
                 ssid[ER_WIFI_L2_SSID_PREFIX_R_OFFSET] == (UINT8)'r' &&
                 ssid[ER_WIFI_L2_SSID_PREFIX_DASH_OFFSET] == (UINT8)'-');
}

static UINT8 er_wifi_l2_control_ssid_valid(const UINT8* ssid, UINT8 ssid_len) {
  return (UINT8)(er_wifi_l2_ssid_valid(ssid, ssid_len) != 0u &&
                 ssid_len == ER_WIFI_L2_CONTROL_SSID_LEN &&
                 er_mem_equal(ssid,
                              g_er_wifi_l2_control_ssid,
                              ER_WIFI_L2_CONTROL_SSID_LEN) != 0u);
}

static UINT8 er_wifi_l2_plan_ssid_valid(const UINT8* ssid, UINT8 ssid_len) {
  return (UINT8)(er_wifi_l2_node_ssid_valid(ssid, ssid_len) != 0u ||
                 er_wifi_l2_control_ssid_valid(ssid, ssid_len) != 0u);
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
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT *
                                    ER_WIFI_L2_MAC_NODE_GROUP_2)] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT *
                                    ER_WIFI_L2_MAC_NODE_GROUP_3)] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT *
                                    ER_WIFI_L2_MAC_NODE_GROUP_4)] ^
                node_id->bytes[i + (ER_WIFI_L2_MAC_NODE_BYTE_COUNT *
                                    ER_WIFI_L2_MAC_NODE_GROUP_5)] ^
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

UINT8 er_wifi_l2_control_ssid(UINT8* out_ssid,
                              UINT8 out_capacity,
                              UINT8* out_ssid_len) {
  if (out_ssid == 0 ||
      out_ssid_len == 0 ||
      out_capacity < ER_WIFI_L2_CONTROL_SSID_LEN) {
    return 0u;
  }
  er_mem_copy(out_ssid,
              g_er_wifi_l2_control_ssid,
              ER_WIFI_L2_CONTROL_SSID_LEN);
  *out_ssid_len = ER_WIFI_L2_CONTROL_SSID_LEN;
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

UINT8 er_wifi_l2_control_plan_prepare(const ErNodeId* node_id,
                                      ErWifiL2ApPlan* out_plan) {
  UINT8 ssid_len;

  if (out_plan == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
  if (er_wifi_l2_node_mac(node_id, out_plan->mac) == 0u ||
      er_wifi_l2_control_ssid(out_plan->ssid,
                              ER_WIFI_L2_NODE_SSID_CAP,
                              &ssid_len) == 0u) {
    er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
    return 0u;
  }
  out_plan->abi_version = ER_WIFI_L2_ABI_VERSION;
  out_plan->channel = ER_WIFI_L2_CONTROL_CHANNEL;
  out_plan->ssid_len = ssid_len;
  out_plan->eth_type = ER_NET_ETH_TYPE_EDGERUN;
  return 1u;
}

UINT8 er_wifi_l2_ap_plan_valid(const ErWifiL2ApPlan* plan) {
  if (plan == 0 ||
      plan->abi_version != ER_WIFI_L2_ABI_VERSION ||
      er_wifi_l2_channel_valid(plan->channel) == 0u ||
      er_wifi_l2_plan_ssid_valid(plan->ssid, plan->ssid_len) == 0u ||
      plan->eth_type != ER_NET_ETH_TYPE_EDGERUN ||
      plan->reserved[0] != 0u ||
      plan->reserved[1] != 0u ||
      (plan->mac[0] & 1u) != 0u ||
      (plan->mac[0] & ER_WIFI_L2_MAC_LOCAL_UNICAST) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_wifi_l2_prepare_channel_endpoint(const ErHash* channel_id,
                                          const ErWifiL2ApPlan* plan,
                                          const char* label,
                                          UINTN label_len,
                                          ErChannelEndpoint* out_endpoint) {
  UINT8 address_len;

  if (channel_id == 0 ||
      er_hash_nonzero(channel_id) == 0u ||
      er_wifi_l2_ap_plan_valid(plan) == 0u ||
      label == 0 ||
      label_len == 0u ||
      label_len > ER_CHANNEL_LABEL_MAX ||
      out_endpoint == 0) {
    return 0u;
  }

  address_len = (UINT8)(ER_WIFI_L2_ENDPOINT_ADDR_FIXED_LEN + plan->ssid_len);
  er_mem_zero((UINT8*)out_endpoint, (UINTN)sizeof(*out_endpoint));
  out_endpoint->abi_version = ER_WORK_ABI_VERSION;
  out_endpoint->kind = ER_CHANNEL_KIND_WIFI_OPEN_L2;
  out_endpoint->channel_id = *channel_id;
  out_endpoint->address_len = address_len;
  out_endpoint->label_len = (UINT16)label_len;
  er_mem_copy(out_endpoint->address + ER_WIFI_L2_ENDPOINT_ADDR_MAC_OFFSET,
              plan->mac,
              ER_NET_MAC_LEN);
  out_endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_ETH_TYPE_OFFSET] =
      (UINT8)((plan->eth_type >> ER_WIFI_L2_ETH_TYPE_HIGH_SHIFT) &
              ER_WIFI_L2_MAC_BYTE_MASK);
  out_endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_ETH_TYPE_OFFSET + 1u] =
      (UINT8)(plan->eth_type & ER_WIFI_L2_MAC_BYTE_MASK);
  out_endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_CHANNEL_OFFSET] =
      plan->channel;
  out_endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_SSID_LEN_OFFSET] =
      plan->ssid_len;
  er_mem_copy(out_endpoint->address + ER_WIFI_L2_ENDPOINT_ADDR_SSID_OFFSET,
              plan->ssid,
              plan->ssid_len);
  er_mem_copy((UINT8*)out_endpoint->label, (const UINT8*)label, label_len);
  return 1u;
}

UINT8 er_wifi_l2_channel_endpoint_valid(const ErChannelEndpoint* endpoint) {
  UINT8 ssid_len;
  UINT16 eth_type;

  if (endpoint == 0 ||
      endpoint->abi_version != ER_WORK_ABI_VERSION ||
      endpoint->kind != ER_CHANNEL_KIND_WIFI_OPEN_L2 ||
      er_hash_nonzero(&endpoint->channel_id) == 0u ||
      endpoint->label_len == 0u ||
      endpoint->label_len > ER_CHANNEL_LABEL_MAX ||
      endpoint->address_len < ER_WIFI_L2_ENDPOINT_ADDR_FIXED_LEN) {
    return 0u;
  }

  ssid_len = endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_SSID_LEN_OFFSET];
  eth_type = (UINT16)(((UINT16)endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_ETH_TYPE_OFFSET] <<
                       ER_WIFI_L2_ETH_TYPE_HIGH_SHIFT) |
                      (UINT16)endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_ETH_TYPE_OFFSET + 1u]);
  if (endpoint->address_len != (UINT8)(ER_WIFI_L2_ENDPOINT_ADDR_FIXED_LEN + ssid_len) ||
      er_wifi_l2_plan_ssid_valid(endpoint->address + ER_WIFI_L2_ENDPOINT_ADDR_SSID_OFFSET,
                                 ssid_len) == 0u ||
      eth_type != ER_NET_ETH_TYPE_EDGERUN ||
      er_wifi_l2_channel_valid(endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_CHANNEL_OFFSET]) == 0u ||
      (endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_MAC_OFFSET] & 1u) != 0u ||
      (endpoint->address[ER_WIFI_L2_ENDPOINT_ADDR_MAC_OFFSET] &
       ER_WIFI_L2_MAC_LOCAL_UNICAST) == 0u) {
    return 0u;
  }
  return 1u;
}
