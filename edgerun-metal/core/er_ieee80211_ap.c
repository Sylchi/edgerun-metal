#include "er_ieee80211_ap.h"
#include "er_mem.h"

enum {
  ER_IEEE80211_FRAME_CONTROL_OFFSET = 0u,
  ER_IEEE80211_DURATION_OFFSET = 2u,
  ER_IEEE80211_ADDR1_OFFSET = 4u,
  ER_IEEE80211_ADDR2_OFFSET = 10u,
  ER_IEEE80211_ADDR3_OFFSET = 16u,
  ER_IEEE80211_SEQUENCE_CONTROL_OFFSET = 22u,
  ER_IEEE80211_SEQUENCE_NUMBER_SHIFT = 4u,
  ER_IEEE80211_SEQUENCE_NUMBER_MASK = 0x0fffu,
  ER_IEEE80211_FRAME_TYPE_SHIFT = 2u,
  ER_IEEE80211_FRAME_SUBTYPE_SHIFT = 4u,
  ER_IEEE80211_FRAME_TYPE_MASK = 3u,
  ER_IEEE80211_FRAME_SUBTYPE_MASK = 15u,
  ER_IEEE80211_FRAME_TYPE_MANAGEMENT = 0u,
  ER_IEEE80211_SUBTYPE_PROBE_REQUEST = 4u,
  ER_IEEE80211_SUBTYPE_PROBE_RESPONSE = 5u,
  ER_IEEE80211_SUBTYPE_BEACON = 8u,
  ER_IEEE80211_TIMESTAMP_LEN = 8u,
  ER_IEEE80211_CAPABILITY_ESS = 0x0001u,
  ER_IEEE80211_CAPABILITY_SHORT_PREAMBLE = 0x0020u,
  ER_IEEE80211_CAPABILITY_SHORT_SLOT = 0x0400u,
  ER_IEEE80211_IE_HEADER_LEN = 2u,
  ER_IEEE80211_IE_ID_SSID = 0u,
  ER_IEEE80211_IE_ID_SUPPORTED_RATES = 1u,
  ER_IEEE80211_IE_ID_DS_PARAMETER_SET = 3u,
  ER_IEEE80211_DS_PARAMETER_LEN = 1u,
  ER_IEEE80211_MIN_CHANNEL = 1u,
  ER_IEEE80211_MAX_CHANNEL = 14u,
  ER_IEEE80211_BYTE_SHIFT = 8u,
  ER_IEEE80211_BYTE_MASK = 0xffu,
  ER_IEEE80211_BROADCAST_OCTET = 0xffu,
  ER_IEEE80211_RATE_1M_BASIC = 0x82u,
  ER_IEEE80211_RATE_2M_BASIC = 0x84u,
  ER_IEEE80211_RATE_5M5_BASIC = 0x8bu,
  ER_IEEE80211_RATE_11M_BASIC = 0x96u
};

static const UINT8 er_ieee80211_broadcast_mac[ER_NET_MAC_LEN] = {
    ER_IEEE80211_BROADCAST_OCTET,
    ER_IEEE80211_BROADCAST_OCTET,
    ER_IEEE80211_BROADCAST_OCTET,
    ER_IEEE80211_BROADCAST_OCTET,
    ER_IEEE80211_BROADCAST_OCTET,
    ER_IEEE80211_BROADCAST_OCTET};

static const UINT8 er_ieee80211_supported_rates[
    ER_IEEE80211_AP_SUPPORTED_RATE_COUNT] = {
    ER_IEEE80211_RATE_1M_BASIC,
    ER_IEEE80211_RATE_2M_BASIC,
    ER_IEEE80211_RATE_5M5_BASIC,
    ER_IEEE80211_RATE_11M_BASIC};

static UINT8 er_ieee80211_channel_valid(UINT8 channel) {
  return (UINT8)(channel >= ER_IEEE80211_MIN_CHANNEL &&
                 channel <= ER_IEEE80211_MAX_CHANNEL);
}

static void er_ieee80211_put_le16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value & ER_IEEE80211_BYTE_MASK);
  dst[1] = (UINT8)((value >> ER_IEEE80211_BYTE_SHIFT) &
                   ER_IEEE80211_BYTE_MASK);
}

static UINT16 er_ieee80211_get_le16(const UINT8* src) {
  return (UINT16)((UINT16)src[0] |
                  ((UINT16)src[1] << ER_IEEE80211_BYTE_SHIFT));
}

static UINT16 er_ieee80211_frame_control(UINT8 type, UINT8 subtype) {
  return (UINT16)(((UINT16)type << ER_IEEE80211_FRAME_TYPE_SHIFT) |
                  ((UINT16)subtype << ER_IEEE80211_FRAME_SUBTYPE_SHIFT));
}

static UINT8 er_ieee80211_config_valid(
    const ErIeee80211OpenApConfig* config) {
  if (config == 0 ||
      config->abi_version != ER_IEEE80211_AP_ABI_VERSION ||
      config->beacon_interval_tu != ER_IEEE80211_AP_BEACON_INTERVAL_TU ||
      er_ieee80211_channel_valid(config->channel) == 0u ||
      config->ssid_len != ER_WIFI_L2_NODE_SSID_LEN ||
      config->reserved[0] != 0u ||
      config->reserved[1] != 0u ||
      er_mem_any_nonzero(config->bssid, ER_NET_MAC_LEN) == 0u ||
      (config->bssid[0] & 1u) != 0u) {
    return 0u;
  }
  return 1u;
}

static UINT32 er_ieee80211_open_ap_frame_len(UINT8 ssid_len) {
  return (UINT32)(ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN +
                  ER_IEEE80211_AP_BEACON_FIXED_LEN +
                  ER_IEEE80211_IE_HEADER_LEN + ssid_len +
                  ER_IEEE80211_IE_HEADER_LEN +
                  ER_IEEE80211_AP_SUPPORTED_RATE_COUNT +
                  ER_IEEE80211_IE_HEADER_LEN +
                  ER_IEEE80211_DS_PARAMETER_LEN);
}

static UINT8 er_ieee80211_write_management_header(
    UINT8 subtype,
    const UINT8 receiver[ER_NET_MAC_LEN],
    const UINT8 transmitter[ER_NET_MAC_LEN],
    const UINT8 bssid[ER_NET_MAC_LEN],
    UINT16 sequence,
    UINT8* out_frame,
    UINT32 out_capacity) {
  UINT16 sequence_control;

  if (receiver == 0 ||
      transmitter == 0 ||
      bssid == 0 ||
      out_frame == 0 ||
      out_capacity < ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN) {
    return 0u;
  }
  er_mem_zero(out_frame, ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN);
  er_ieee80211_put_le16(out_frame + ER_IEEE80211_FRAME_CONTROL_OFFSET,
                        er_ieee80211_frame_control(
                            ER_IEEE80211_FRAME_TYPE_MANAGEMENT,
                            subtype));
  er_ieee80211_put_le16(out_frame + ER_IEEE80211_DURATION_OFFSET, 0u);
  er_mem_copy(out_frame + ER_IEEE80211_ADDR1_OFFSET,
              receiver,
              ER_NET_MAC_LEN);
  er_mem_copy(out_frame + ER_IEEE80211_ADDR2_OFFSET,
              transmitter,
              ER_NET_MAC_LEN);
  er_mem_copy(out_frame + ER_IEEE80211_ADDR3_OFFSET, bssid, ER_NET_MAC_LEN);
  sequence_control = (UINT16)((sequence & ER_IEEE80211_SEQUENCE_NUMBER_MASK) <<
                              ER_IEEE80211_SEQUENCE_NUMBER_SHIFT);
  er_ieee80211_put_le16(out_frame + ER_IEEE80211_SEQUENCE_CONTROL_OFFSET,
                        sequence_control);
  return 1u;
}

static UINT8 er_ieee80211_write_open_ap_body(
    const ErIeee80211OpenApConfig* config,
    UINT8* out_frame,
    UINT32 out_capacity,
    UINT32* out_frame_len) {
  UINT32 offset;
  UINT16 capabilities;
  UINT32 frame_len;

  if (er_ieee80211_config_valid(config) == 0u ||
      out_frame == 0 ||
      out_frame_len == 0) {
    return 0u;
  }
  frame_len = er_ieee80211_open_ap_frame_len(config->ssid_len);
  if (out_capacity < frame_len) {
    return 0u;
  }
  offset = ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN;
  er_mem_zero(out_frame + offset, ER_IEEE80211_TIMESTAMP_LEN);
  offset += ER_IEEE80211_TIMESTAMP_LEN;
  er_ieee80211_put_le16(out_frame + offset, config->beacon_interval_tu);
  offset += (UINT32)sizeof(UINT16);
  capabilities = (UINT16)(ER_IEEE80211_CAPABILITY_ESS |
                          ER_IEEE80211_CAPABILITY_SHORT_PREAMBLE |
                          ER_IEEE80211_CAPABILITY_SHORT_SLOT);
  er_ieee80211_put_le16(out_frame + offset, capabilities);
  offset += (UINT32)sizeof(UINT16);

  out_frame[offset] = ER_IEEE80211_IE_ID_SSID;
  out_frame[offset + 1u] = config->ssid_len;
  offset += ER_IEEE80211_IE_HEADER_LEN;
  er_mem_copy(out_frame + offset, config->ssid, config->ssid_len);
  offset += config->ssid_len;

  out_frame[offset] = ER_IEEE80211_IE_ID_SUPPORTED_RATES;
  out_frame[offset + 1u] = ER_IEEE80211_AP_SUPPORTED_RATE_COUNT;
  offset += ER_IEEE80211_IE_HEADER_LEN;
  er_mem_copy(out_frame + offset,
              er_ieee80211_supported_rates,
              ER_IEEE80211_AP_SUPPORTED_RATE_COUNT);
  offset += ER_IEEE80211_AP_SUPPORTED_RATE_COUNT;

  out_frame[offset] = ER_IEEE80211_IE_ID_DS_PARAMETER_SET;
  out_frame[offset + 1u] = ER_IEEE80211_DS_PARAMETER_LEN;
  offset += ER_IEEE80211_IE_HEADER_LEN;
  out_frame[offset] = config->channel;
  offset += ER_IEEE80211_DS_PARAMETER_LEN;

  *out_frame_len = offset;
  return (UINT8)(offset == frame_len);
}

UINT8 er_ieee80211_open_ap_config_from_l2_plan(
    const ErWifiL2ApPlan* plan,
    ErIeee80211OpenApConfig* out_config) {
  if (er_wifi_l2_ap_plan_valid(plan) == 0u || out_config == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_config, (UINTN)sizeof(*out_config));
  out_config->abi_version = ER_IEEE80211_AP_ABI_VERSION;
  out_config->beacon_interval_tu = ER_IEEE80211_AP_BEACON_INTERVAL_TU;
  out_config->channel = plan->channel;
  out_config->ssid_len = plan->ssid_len;
  er_mem_copy(out_config->bssid, plan->mac, ER_NET_MAC_LEN);
  er_mem_copy(out_config->ssid, plan->ssid, plan->ssid_len);
  return 1u;
}

static UINT8 er_ieee80211_open_ap_build_management_frame(
    const ErIeee80211OpenApConfig* config,
    UINT8 subtype,
    const UINT8 receiver[ER_NET_MAC_LEN],
    UINT16 sequence,
    UINT8* out_frame,
    UINT32 out_capacity,
    UINT32* out_frame_len) {
  if (er_ieee80211_write_management_header(subtype,
                                           receiver,
                                           config->bssid,
                                           config->bssid,
                                           sequence,
                                           out_frame,
                                           out_capacity) == 0u) {
    return 0u;
  }
  return er_ieee80211_write_open_ap_body(config,
                                         out_frame,
                                         out_capacity,
                                         out_frame_len);
}

UINT8 er_ieee80211_open_ap_build_beacon(
    const ErIeee80211OpenApConfig* config,
    UINT16 sequence,
    UINT8* out_frame,
    UINT32 out_capacity,
    UINT32* out_frame_len) {
  if (er_ieee80211_config_valid(config) == 0u ||
      out_frame == 0 ||
      out_frame_len == 0 ||
      out_capacity < er_ieee80211_open_ap_frame_len(config->ssid_len)) {
    return 0u;
  }
  return er_ieee80211_open_ap_build_management_frame(
      config,
      ER_IEEE80211_SUBTYPE_BEACON,
      er_ieee80211_broadcast_mac,
      sequence,
      out_frame,
      out_capacity,
      out_frame_len);
}

UINT8 er_ieee80211_open_ap_build_probe_response(
    const ErIeee80211OpenApConfig* config,
    const UINT8 station_mac[ER_NET_MAC_LEN],
    UINT16 sequence,
    UINT8* out_frame,
    UINT32 out_capacity,
    UINT32* out_frame_len) {
  if (er_ieee80211_config_valid(config) == 0u ||
      station_mac == 0 ||
      er_mem_any_nonzero(station_mac, ER_NET_MAC_LEN) == 0u ||
      (station_mac[0] & 1u) != 0u ||
      out_frame == 0 ||
      out_frame_len == 0 ||
      out_capacity < er_ieee80211_open_ap_frame_len(config->ssid_len)) {
    return 0u;
  }
  return er_ieee80211_open_ap_build_management_frame(
      config,
      ER_IEEE80211_SUBTYPE_PROBE_RESPONSE,
      station_mac,
      sequence,
      out_frame,
      out_capacity,
      out_frame_len);
}

UINT8 er_ieee80211_open_ap_probe_request_matches(
    const ErIeee80211OpenApConfig* config,
    const UINT8* frame,
    UINT32 frame_len) {
  UINT16 frame_control;
  UINT8 type;
  UINT8 subtype;
  UINT32 offset;
  UINT8 element_id;
  UINT8 element_len;

  if (er_ieee80211_config_valid(config) == 0u ||
      frame == 0 ||
      frame_len < ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN) {
    return 0u;
  }
  frame_control = er_ieee80211_get_le16(frame + ER_IEEE80211_FRAME_CONTROL_OFFSET);
  type = (UINT8)((frame_control >> ER_IEEE80211_FRAME_TYPE_SHIFT) &
                 ER_IEEE80211_FRAME_TYPE_MASK);
  subtype = (UINT8)((frame_control >> ER_IEEE80211_FRAME_SUBTYPE_SHIFT) &
                    ER_IEEE80211_FRAME_SUBTYPE_MASK);
  if (type != ER_IEEE80211_FRAME_TYPE_MANAGEMENT ||
      subtype != ER_IEEE80211_SUBTYPE_PROBE_REQUEST) {
    return 0u;
  }
  offset = ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN;
  while ((offset + ER_IEEE80211_IE_HEADER_LEN) <= frame_len) {
    element_id = frame[offset];
    element_len = frame[offset + 1u];
    offset += ER_IEEE80211_IE_HEADER_LEN;
    if ((offset + element_len) > frame_len) {
      return 0u;
    }
    if (element_id == ER_IEEE80211_IE_ID_SSID) {
      if (element_len == 0u) {
        return 1u;
      }
      if (element_len == config->ssid_len &&
          er_mem_equal(frame + offset, config->ssid, config->ssid_len) != 0u) {
        return 1u;
      }
      return 0u;
    }
    offset += element_len;
  }
  return 0u;
}
