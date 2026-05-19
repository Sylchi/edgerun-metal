#include "er_ble_adv.h"
#include "er_mem.h"

enum {
  ER_BLE_ADV_AD_TYPE_MANUFACTURER = 0xffu,
  ER_BLE_ADV_MANUFACTURER_HEADER_LEN = 12u,
  ER_BLE_ADV_COMPANY_ID_LO = 0xffu,
  ER_BLE_ADV_COMPANY_ID_HI = 0xffu,
  ER_BLE_ADV_MAGIC_E = 'E',
  ER_BLE_ADV_MAGIC_R = 'R',
  ER_BLE_ADV_VERSION = 1u,
  ER_BLE_ADV_FIELD_LEN_OFFSET = 0u,
  ER_BLE_ADV_TYPE_OFFSET = 1u,
  ER_BLE_ADV_COMPANY_LO_OFFSET = 2u,
  ER_BLE_ADV_COMPANY_HI_OFFSET = 3u,
  ER_BLE_ADV_MAGIC_E_OFFSET = 4u,
  ER_BLE_ADV_MAGIC_R_OFFSET = 5u,
  ER_BLE_ADV_VERSION_OFFSET = 6u,
  ER_BLE_ADV_CHANNEL_OFFSET = 7u,
  ER_BLE_ADV_SEQUENCE_LO_OFFSET = 8u,
  ER_BLE_ADV_SEQUENCE_HI_OFFSET = 9u,
  ER_BLE_ADV_FRAGMENT_INDEX_OFFSET = 10u,
  ER_BLE_ADV_FRAGMENT_COUNT_OFFSET = 11u,
  ER_BLE_ADV_PAYLOAD_LEN_OFFSET = 12u,
  ER_BLE_ADV_PAYLOAD_OFFSET = 13u,
  ER_BLE_ADV_BYTE_MASK = 0xffu,
  ER_BLE_ADV_BYTE_BITS = 8u,
  ER_BLE_ADV_U32_MASK = 0xffffffffu,
  ER_BLE_ADV_U16_LO_OFFSET = 0u,
  ER_BLE_ADV_U16_HI_OFFSET = 1u,
  ER_BLE_ADV_U32_BYTE0_OFFSET = 0u,
  ER_BLE_ADV_U32_BYTE1_OFFSET = 1u,
  ER_BLE_ADV_U32_BYTE2_OFFSET = 2u,
  ER_BLE_ADV_U32_BYTE3_OFFSET = 3u,
  ER_BLE_ADV_U64_LO_U32_OFFSET = 0u,
  ER_BLE_ADV_U64_HI_U32_OFFSET = 4u,
  ER_BLE_WIFI_ROLE_PAYLOAD_KIND_OFFSET = 0u,
  ER_BLE_WIFI_ROLE_PAYLOAD_VERSION_OFFSET = 1u,
  ER_BLE_WIFI_ROLE_PAYLOAD_CAPABILITIES_OFFSET = 2u,
  ER_BLE_WIFI_ROLE_PAYLOAD_PREFERRED_ROLE_OFFSET = 3u,
  ER_BLE_WIFI_ROLE_PAYLOAD_ELECTION_PRIORITY_OFFSET = 4u,
  ER_BLE_WIFI_ROLE_PAYLOAD_CHANNEL_OFFSET = 5u,
  ER_BLE_WIFI_ROLE_PAYLOAD_GROUP_ID_OFFSET = 6u,
  ER_BLE_WIFI_ROLE_PAYLOAD_NODE_NONCE_OFFSET = 10u,
  ER_BLE_WIFI_ROLE_PAYLOAD_VERSION = 1u,
  ER_BLE_WIFI_ROLE_CAPABILITY_MASK = ER_BLE_WIFI_CAPABILITY_AP |
                                     ER_BLE_WIFI_CAPABILITY_STA,
  ER_BLE_WIFI_CAPABILITY_KNOWN_MASK = ER_BLE_WIFI_CAPABILITY_AP |
                                      ER_BLE_WIFI_CAPABILITY_STA |
                                      ER_BLE_WIFI_CAPABILITY_BURST_TX_PENDING,
  ER_BLE_WIFI_CHANNEL_INVALID = 0u,
  ER_BLE_HCI_COMMAND_OPCODE_LO_OFFSET = 0u,
  ER_BLE_HCI_COMMAND_OPCODE_HI_OFFSET = 1u,
  ER_BLE_HCI_COMMAND_PARAM_LEN_OFFSET = 2u,
  ER_BLE_HCI_COMMAND_HEADER_BYTES = 3u,
  ER_BLE_HCI_LE_SET_ADV_PARAMETERS_BYTES = 15u,
  ER_BLE_HCI_LE_SET_ADV_DATA_BYTES = 32u,
  ER_BLE_HCI_LE_SET_ADV_ENABLE_BYTES = 1u,
  ER_BLE_HCI_LE_SET_SCAN_PARAMETERS_BYTES = 7u,
  ER_BLE_HCI_LE_SET_SCAN_ENABLE_BYTES = 2u,
  ER_BLE_HCI_TIMEOUT = 1000000u,
  ER_BLE_HCI_OPCODE_LE_SET_ADV_PARAMETERS = 0x2006u,
  ER_BLE_HCI_OPCODE_LE_SET_ADV_DATA = 0x2008u,
  ER_BLE_HCI_OPCODE_LE_SET_ADV_ENABLE = 0x200au,
  ER_BLE_HCI_OPCODE_LE_SET_SCAN_PARAMETERS = 0x200bu,
  ER_BLE_HCI_OPCODE_LE_SET_SCAN_ENABLE = 0x200cu,
  ER_BLE_HCI_ADV_INTERVAL_MIN_LO = 0xa0u,
  ER_BLE_HCI_ADV_INTERVAL_MIN_HI = 0x00u,
  ER_BLE_HCI_ADV_INTERVAL_MAX_LO = 0xf0u,
  ER_BLE_HCI_ADV_INTERVAL_MAX_HI = 0x00u,
  ER_BLE_HCI_ADV_TYPE_NONCONNECTABLE = 0x03u,
  ER_BLE_HCI_ADDR_TYPE_PUBLIC = 0x00u,
  ER_BLE_HCI_ADV_CHANNEL_ALL = 0x07u,
  ER_BLE_HCI_ADV_FILTER_ANY = 0x00u,
  ER_BLE_HCI_ADV_PARAM_INTERVAL_MIN_LO_OFFSET = 0u,
  ER_BLE_HCI_ADV_PARAM_INTERVAL_MIN_HI_OFFSET = 1u,
  ER_BLE_HCI_ADV_PARAM_INTERVAL_MAX_LO_OFFSET = 2u,
  ER_BLE_HCI_ADV_PARAM_INTERVAL_MAX_HI_OFFSET = 3u,
  ER_BLE_HCI_ADV_PARAM_TYPE_OFFSET = 4u,
  ER_BLE_HCI_ADV_PARAM_OWN_ADDR_TYPE_OFFSET = 5u,
  ER_BLE_HCI_ADV_PARAM_PEER_ADDR_TYPE_OFFSET = 6u,
  ER_BLE_HCI_ADV_PARAM_CHANNEL_MAP_OFFSET = 13u,
  ER_BLE_HCI_ADV_PARAM_FILTER_POLICY_OFFSET = 14u,
  ER_BLE_HCI_ADV_DATA_LEN_OFFSET = 0u,
  ER_BLE_HCI_ADV_DATA_BYTES_OFFSET = 1u,
  ER_BLE_HCI_ADV_ENABLE_OFFSET = 0u,
  ER_BLE_HCI_ENABLE = 0x01u,
  ER_BLE_HCI_DISABLE_DUP_FILTER = 0x00u,
  ER_BLE_HCI_SCAN_TYPE_PASSIVE = 0x00u,
  ER_BLE_HCI_SCAN_INTERVAL_LO = 0x60u,
  ER_BLE_HCI_SCAN_INTERVAL_HI = 0x00u,
  ER_BLE_HCI_SCAN_WINDOW_LO = 0x30u,
  ER_BLE_HCI_SCAN_WINDOW_HI = 0x00u,
  ER_BLE_HCI_SCAN_OWN_ADDR_PUBLIC = 0x00u,
  ER_BLE_HCI_SCAN_FILTER_ANY = 0x00u,
  ER_BLE_HCI_SCAN_PARAM_TYPE_OFFSET = 0u,
  ER_BLE_HCI_SCAN_PARAM_INTERVAL_LO_OFFSET = 1u,
  ER_BLE_HCI_SCAN_PARAM_INTERVAL_HI_OFFSET = 2u,
  ER_BLE_HCI_SCAN_PARAM_WINDOW_LO_OFFSET = 3u,
  ER_BLE_HCI_SCAN_PARAM_WINDOW_HI_OFFSET = 4u,
  ER_BLE_HCI_SCAN_PARAM_OWN_ADDR_TYPE_OFFSET = 5u,
  ER_BLE_HCI_SCAN_PARAM_FILTER_POLICY_OFFSET = 6u,
  ER_BLE_HCI_SCAN_ENABLE_OFFSET = 0u,
  ER_BLE_HCI_SCAN_DUP_FILTER_OFFSET = 1u,
  ER_BLE_HCI_EVENT_LE_META = 0x3eu,
  ER_BLE_HCI_SUBEVENT_ADV_REPORT = 0x02u,
  ER_BLE_HCI_EVENT_CODE_OFFSET = 0u,
  ER_BLE_HCI_EVENT_LEN_OFFSET = 1u,
  ER_BLE_HCI_EVENT_PAYLOAD_OFFSET = 2u,
  ER_BLE_HCI_LE_REPORT_COUNT_OFFSET = 1u,
  ER_BLE_HCI_LE_REPORT_MIN_BYTES = 12u,
  ER_BLE_HCI_LE_REPORT_DATA_LEN_OFFSET = 10u,
  ER_BLE_HCI_LE_REPORT_DATA_OFFSET = 11u,
  ER_BLE_HCI_LE_REPORT_RSSI_BYTES = 1u,
  ER_BLE_HCI_EVENT_BUFFER_BYTES = 64u
};

//@optimizer-ignore-constant UEFI Bluetooth host-controller protocol GUID is ABI-defined by firmware
static EFI_GUID g_er_bluetooth_hc_protocol_guid = {
  0xb3930571u,
  0xbeba,
  0x4fc5u,
  {0x92u, 0x03u, 0x94u, 0x27u, 0x24u, 0x2eu, 0x6au, 0x43u}
};

static void er_ble_adv_write_u16(UINT8* dst, UINT16 value) {
  dst[ER_BLE_ADV_U16_LO_OFFSET] = (UINT8)(value & ER_BLE_ADV_BYTE_MASK);
  dst[ER_BLE_ADV_U16_HI_OFFSET] = (UINT8)((value >> ER_BLE_ADV_BYTE_BITS) & ER_BLE_ADV_BYTE_MASK);
}

static UINT32 er_ble_adv_read_u32(const UINT8* src) {
  return (UINT32)src[ER_BLE_ADV_U32_BYTE0_OFFSET] |
         ((UINT32)src[ER_BLE_ADV_U32_BYTE1_OFFSET] << ER_BLE_ADV_BYTE_BITS) |
         ((UINT32)src[ER_BLE_ADV_U32_BYTE2_OFFSET] <<
          (ER_BLE_ADV_BYTE_BITS * ER_BLE_ADV_U32_BYTE2_OFFSET)) |
         ((UINT32)src[ER_BLE_ADV_U32_BYTE3_OFFSET] <<
          (ER_BLE_ADV_BYTE_BITS * ER_BLE_ADV_U32_BYTE3_OFFSET));
}

static UINT64 er_ble_adv_read_u64(const UINT8* src) {
  return (UINT64)er_ble_adv_read_u32(src + ER_BLE_ADV_U64_LO_U32_OFFSET) |
         ((UINT64)er_ble_adv_read_u32(src + ER_BLE_ADV_U64_HI_U32_OFFSET) <<
          (ER_BLE_ADV_BYTE_BITS * ER_BLE_ADV_U64_HI_U32_OFFSET));
}

static void er_ble_adv_write_u32(UINT8* dst, UINT32 value) {
  dst[ER_BLE_ADV_U32_BYTE0_OFFSET] = (UINT8)(value & ER_BLE_ADV_BYTE_MASK);
  dst[ER_BLE_ADV_U32_BYTE1_OFFSET] = (UINT8)((value >> ER_BLE_ADV_BYTE_BITS) & ER_BLE_ADV_BYTE_MASK);
  dst[ER_BLE_ADV_U32_BYTE2_OFFSET] =
      (UINT8)((value >> (ER_BLE_ADV_BYTE_BITS * ER_BLE_ADV_U32_BYTE2_OFFSET)) & ER_BLE_ADV_BYTE_MASK);
  dst[ER_BLE_ADV_U32_BYTE3_OFFSET] =
      (UINT8)((value >> (ER_BLE_ADV_BYTE_BITS * ER_BLE_ADV_U32_BYTE3_OFFSET)) & ER_BLE_ADV_BYTE_MASK);
}

static void er_ble_adv_write_u64(UINT8* dst, UINT64 value) {
  er_ble_adv_write_u32(dst + ER_BLE_ADV_U64_LO_U32_OFFSET,
                       (UINT32)(value & ER_BLE_ADV_U32_MASK));
  er_ble_adv_write_u32(dst + ER_BLE_ADV_U64_HI_U32_OFFSET,
                       (UINT32)(value >> (ER_BLE_ADV_BYTE_BITS * ER_BLE_ADV_U64_HI_U32_OFFSET)));
}

static UINT8 er_ble_wifi_role_valid(UINT8 role) {
  switch (role) {
    case ER_BLE_WIFI_ROLE_NONE:
    case ER_BLE_WIFI_ROLE_AP:
    case ER_BLE_WIFI_ROLE_STA:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_ble_wifi_role_capability_valid(UINT8 capabilities) {
  if ((capabilities & ER_BLE_WIFI_ROLE_CAPABILITY_MASK) == 0u ||
      (capabilities & (UINT8)~ER_BLE_WIFI_CAPABILITY_KNOWN_MASK) != 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_ble_wifi_role_can_ap(const ErBleWifiRoleAdvert* advert) {
  return (UINT8)(advert != 0 &&
                 (advert->capabilities & ER_BLE_WIFI_CAPABILITY_AP) != 0u);
}

static UINT8 er_ble_wifi_role_can_sta(const ErBleWifiRoleAdvert* advert) {
  return (UINT8)(advert != 0 &&
                 (advert->capabilities & ER_BLE_WIFI_CAPABILITY_STA) != 0u);
}

static UINT8 er_ble_wifi_role_advert_valid(const ErBleWifiRoleAdvert* advert) {
  if (advert == 0 ||
      er_ble_wifi_role_capability_valid(advert->capabilities) == 0u ||
      er_ble_wifi_role_valid(advert->preferred_role) == 0u ||
      advert->wifi_channel == ER_BLE_WIFI_CHANNEL_INVALID ||
      advert->group_id == ER_BLE_WIFI_GROUP_ID_INVALID ||
      advert->node_nonce == 0u) {
    return 0u;
  }
  switch (advert->preferred_role) {
    case ER_BLE_WIFI_ROLE_AP:
      return er_ble_wifi_role_can_ap(advert);
    case ER_BLE_WIFI_ROLE_STA:
      return er_ble_wifi_role_can_sta(advert);
    case ER_BLE_WIFI_ROLE_NONE:
      return 1u;
    default:
      return 0u;
  }
}

UINT8 er_ble_adv_prepare_packet(UINT8 channel_id,
                                UINT16 sequence,
                                UINT8 fragment_index,
                                UINT8 fragment_count,
                                const UINT8* payload,
                                UINT8 payload_len,
                                ErBleAdvPacket* out_packet) {
  if (out_packet == 0 ||
      channel_id == 0u ||
      sequence == ER_BLE_ADV_SEQUENCE_INVALID ||
      fragment_count == 0u ||
      fragment_index >= fragment_count ||
      payload_len > ER_BLE_ADV_PAYLOAD_BYTES ||
      (payload_len > 0u && payload == 0)) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  out_packet->channel_id = channel_id;
  out_packet->sequence = sequence;
  out_packet->fragment_index = fragment_index;
  out_packet->fragment_count = fragment_count;
  out_packet->payload_len = payload_len;
  if (payload_len > 0u) {
    er_mem_copy(out_packet->payload, payload, payload_len);
  }
  return 1u;
}

UINT8 er_ble_adv_encode_data(const ErBleAdvPacket* packet,
                             UINT8 out_data[ER_BLE_ADV_LEGACY_DATA_BYTES],
                             UINT8* out_len) {
  if (packet == 0 || out_data == 0 || out_len == 0 ||
      packet->channel_id == 0u ||
      packet->sequence == ER_BLE_ADV_SEQUENCE_INVALID ||
      packet->fragment_count == 0u ||
      packet->fragment_index >= packet->fragment_count ||
      packet->payload_len > ER_BLE_ADV_PAYLOAD_BYTES) {
    return 0u;
  }
  er_mem_zero(out_data, ER_BLE_ADV_LEGACY_DATA_BYTES);
  out_data[ER_BLE_ADV_FIELD_LEN_OFFSET] =
      (UINT8)(ER_BLE_ADV_MANUFACTURER_HEADER_LEN + packet->payload_len);
  out_data[ER_BLE_ADV_TYPE_OFFSET] = ER_BLE_ADV_AD_TYPE_MANUFACTURER;
  out_data[ER_BLE_ADV_COMPANY_LO_OFFSET] = ER_BLE_ADV_COMPANY_ID_LO;
  out_data[ER_BLE_ADV_COMPANY_HI_OFFSET] = ER_BLE_ADV_COMPANY_ID_HI;
  out_data[ER_BLE_ADV_MAGIC_E_OFFSET] = ER_BLE_ADV_MAGIC_E;
  out_data[ER_BLE_ADV_MAGIC_R_OFFSET] = ER_BLE_ADV_MAGIC_R;
  out_data[ER_BLE_ADV_VERSION_OFFSET] = ER_BLE_ADV_VERSION;
  out_data[ER_BLE_ADV_CHANNEL_OFFSET] = packet->channel_id;
  er_ble_adv_write_u16(out_data + ER_BLE_ADV_SEQUENCE_LO_OFFSET, packet->sequence);
  out_data[ER_BLE_ADV_FRAGMENT_INDEX_OFFSET] = packet->fragment_index;
  out_data[ER_BLE_ADV_FRAGMENT_COUNT_OFFSET] = packet->fragment_count;
  out_data[ER_BLE_ADV_PAYLOAD_LEN_OFFSET] = packet->payload_len;
  if (packet->payload_len > 0u) {
    er_mem_copy(out_data + ER_BLE_ADV_PAYLOAD_OFFSET, packet->payload, packet->payload_len);
  }
  *out_len = (UINT8)(ER_BLE_ADV_PAYLOAD_OFFSET + packet->payload_len);
  return 1u;
}

UINT8 er_ble_adv_decode_data(const UINT8* data,
                             UINT8 data_len,
                             ErBleAdvPacket* out_packet) {
  UINT8 offset = 0u;
  UINT8 field_len;
  UINT8 field_type;
  UINT8 packet_payload_len;

  if (data == 0 || out_packet == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  while (offset < data_len) {
    field_len = data[offset];
    if (field_len == 0u) {
      return 0u;
    }
    if ((UINT16)offset + ER_BLE_HCI_ADV_DATA_BYTES_OFFSET + field_len > data_len) {
      return 0u;
    }
    field_type = data[offset + ER_BLE_ADV_TYPE_OFFSET];
    switch (field_type) {
      case ER_BLE_ADV_AD_TYPE_MANUFACTURER:
        if (field_len < ER_BLE_ADV_MANUFACTURER_HEADER_LEN ||
            data[offset + ER_BLE_ADV_COMPANY_LO_OFFSET] != ER_BLE_ADV_COMPANY_ID_LO ||
            data[offset + ER_BLE_ADV_COMPANY_HI_OFFSET] != ER_BLE_ADV_COMPANY_ID_HI ||
            data[offset + ER_BLE_ADV_MAGIC_E_OFFSET] != ER_BLE_ADV_MAGIC_E ||
            data[offset + ER_BLE_ADV_MAGIC_R_OFFSET] != ER_BLE_ADV_MAGIC_R ||
            data[offset + ER_BLE_ADV_VERSION_OFFSET] != ER_BLE_ADV_VERSION) {
          return 0u;
        }
        packet_payload_len = data[offset + ER_BLE_ADV_PAYLOAD_LEN_OFFSET];
        if (packet_payload_len > ER_BLE_ADV_PAYLOAD_BYTES ||
            field_len != (UINT8)(ER_BLE_ADV_MANUFACTURER_HEADER_LEN + packet_payload_len)) {
          return 0u;
        }
        return er_ble_adv_prepare_packet(data[offset + ER_BLE_ADV_CHANNEL_OFFSET],
                                         (UINT16)((UINT16)data[offset + ER_BLE_ADV_SEQUENCE_LO_OFFSET] |
                                                  ((UINT16)data[offset + ER_BLE_ADV_SEQUENCE_HI_OFFSET] << 8u)),
                                         data[offset + ER_BLE_ADV_FRAGMENT_INDEX_OFFSET],
                                         data[offset + ER_BLE_ADV_FRAGMENT_COUNT_OFFSET],
                                         data + offset + ER_BLE_ADV_PAYLOAD_OFFSET,
                                         packet_payload_len,
                                         out_packet);
      default:
        break;
    }
    offset = (UINT8)(offset + ER_BLE_HCI_ADV_DATA_BYTES_OFFSET + field_len);
  }
  return 0u;
}

UINT8 er_ble_wifi_role_advert_prepare(UINT8 capabilities,
                                      UINT8 preferred_role,
                                      UINT8 election_priority,
                                      UINT8 wifi_channel,
                                      UINT32 group_id,
                                      UINT64 node_nonce,
                                      ErBleWifiRoleAdvert* out_advert) {
  ErBleWifiRoleAdvert advert;

  if (out_advert == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)&advert, (UINTN)sizeof(advert));
  advert.capabilities = capabilities;
  advert.preferred_role = preferred_role;
  advert.election_priority = election_priority;
  advert.wifi_channel = wifi_channel;
  advert.group_id = group_id;
  advert.node_nonce = node_nonce;
  if (er_ble_wifi_role_advert_valid(&advert) == 0u) {
    return 0u;
  }
  *out_advert = advert;
  return 1u;
}

UINT8 er_ble_wifi_role_encode_payload(const ErBleWifiRoleAdvert* advert,
                                      UINT8 out_payload[ER_BLE_ADV_PAYLOAD_BYTES]) {
  if (out_payload == 0 || er_ble_wifi_role_advert_valid(advert) == 0u) {
    return 0u;
  }
  er_mem_zero(out_payload, ER_BLE_ADV_PAYLOAD_BYTES);
  out_payload[ER_BLE_WIFI_ROLE_PAYLOAD_KIND_OFFSET] = ER_BLE_PAYLOAD_KIND_WIFI_ROLE;
  out_payload[ER_BLE_WIFI_ROLE_PAYLOAD_VERSION_OFFSET] = ER_BLE_WIFI_ROLE_PAYLOAD_VERSION;
  out_payload[ER_BLE_WIFI_ROLE_PAYLOAD_CAPABILITIES_OFFSET] = advert->capabilities;
  out_payload[ER_BLE_WIFI_ROLE_PAYLOAD_PREFERRED_ROLE_OFFSET] = advert->preferred_role;
  out_payload[ER_BLE_WIFI_ROLE_PAYLOAD_ELECTION_PRIORITY_OFFSET] = advert->election_priority;
  out_payload[ER_BLE_WIFI_ROLE_PAYLOAD_CHANNEL_OFFSET] = advert->wifi_channel;
  er_ble_adv_write_u32(out_payload + ER_BLE_WIFI_ROLE_PAYLOAD_GROUP_ID_OFFSET,
                       advert->group_id);
  er_ble_adv_write_u64(out_payload + ER_BLE_WIFI_ROLE_PAYLOAD_NODE_NONCE_OFFSET,
                       advert->node_nonce);
  return 1u;
}

UINT8 er_ble_wifi_role_decode_payload(const UINT8 payload[ER_BLE_ADV_PAYLOAD_BYTES],
                                      ErBleWifiRoleAdvert* out_advert) {
  if (payload == 0 || out_advert == 0 ||
      payload[ER_BLE_WIFI_ROLE_PAYLOAD_KIND_OFFSET] != ER_BLE_PAYLOAD_KIND_WIFI_ROLE ||
      payload[ER_BLE_WIFI_ROLE_PAYLOAD_VERSION_OFFSET] != ER_BLE_WIFI_ROLE_PAYLOAD_VERSION) {
    return 0u;
  }
  return er_ble_wifi_role_advert_prepare(payload[ER_BLE_WIFI_ROLE_PAYLOAD_CAPABILITIES_OFFSET],
                                         payload[ER_BLE_WIFI_ROLE_PAYLOAD_PREFERRED_ROLE_OFFSET],
                                         payload[ER_BLE_WIFI_ROLE_PAYLOAD_ELECTION_PRIORITY_OFFSET],
                                         payload[ER_BLE_WIFI_ROLE_PAYLOAD_CHANNEL_OFFSET],
                                         er_ble_adv_read_u32(payload + ER_BLE_WIFI_ROLE_PAYLOAD_GROUP_ID_OFFSET),
                                         er_ble_adv_read_u64(payload + ER_BLE_WIFI_ROLE_PAYLOAD_NODE_NONCE_OFFSET),
                                         out_advert);
}

UINT8 er_ble_wifi_role_advert_is_valid(const ErBleWifiRoleAdvert* advert) {
  return er_ble_wifi_role_advert_valid(advert);
}

ErBleWifiRoleDecision er_ble_wifi_role_decide(const ErBleWifiRoleAdvert* local,
                                              const ErBleWifiRoleAdvert* remote) {
  UINT8 local_can_ap;
  UINT8 local_can_sta;
  UINT8 remote_can_ap;
  UINT8 remote_can_sta;

  if (er_ble_wifi_role_advert_valid(local) == 0u ||
      er_ble_wifi_role_advert_valid(remote) == 0u ||
      local->group_id != remote->group_id ||
      local->wifi_channel != remote->wifi_channel) {
    return ER_BLE_WIFI_ROLE_DECISION_NONE;
  }

  local_can_ap = er_ble_wifi_role_can_ap(local);
  local_can_sta = er_ble_wifi_role_can_sta(local);
  remote_can_ap = er_ble_wifi_role_can_ap(remote);
  remote_can_sta = er_ble_wifi_role_can_sta(remote);

  if (local_can_ap != 0u && remote_can_sta != 0u &&
      local->preferred_role == ER_BLE_WIFI_ROLE_AP &&
      remote->preferred_role == ER_BLE_WIFI_ROLE_STA) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_AP;
  }
  if (local_can_sta != 0u && remote_can_ap != 0u &&
      local->preferred_role == ER_BLE_WIFI_ROLE_STA &&
      remote->preferred_role == ER_BLE_WIFI_ROLE_AP) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_STA;
  }
  if (local_can_ap == 0u && remote_can_ap == 0u) {
    return ER_BLE_WIFI_ROLE_DECISION_CONFLICT;
  }
  if (local_can_sta == 0u && remote_can_sta == 0u) {
    return ER_BLE_WIFI_ROLE_DECISION_CONFLICT;
  }
  if (local_can_ap != 0u && remote_can_sta != 0u &&
      (local_can_sta == 0u || remote_can_ap == 0u)) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_AP;
  }
  if (local_can_sta != 0u && remote_can_ap != 0u &&
      (local_can_ap == 0u || remote_can_sta == 0u)) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_STA;
  }
  if (local->election_priority > remote->election_priority) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_AP;
  }
  if (local->election_priority < remote->election_priority) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_STA;
  }
  if (local->node_nonce > remote->node_nonce) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_AP;
  }
  if (local->node_nonce < remote->node_nonce) {
    return ER_BLE_WIFI_ROLE_DECISION_LOCAL_STA;
  }
  return ER_BLE_WIFI_ROLE_DECISION_CONFLICT;
}

static UINT8 er_ble_adv_efi_send_command(EFI_BLUETOOTH_HC_PROTOCOL* hc,
                                         UINT16 opcode,
                                         const UINT8* params,
                                         UINT8 params_len) {
  UINT8 command[ER_BLE_HCI_COMMAND_HEADER_BYTES + ER_BLE_HCI_LE_SET_ADV_DATA_BYTES];
  UINTN command_len;

  if (hc == 0 || hc->SendCommand == 0 ||
      params_len > ER_BLE_HCI_LE_SET_ADV_DATA_BYTES ||
      (params_len > 0u && params == 0)) {
    return 0u;
  }
  er_mem_zero(command, (UINTN)sizeof(command));
  command[ER_BLE_HCI_COMMAND_OPCODE_LO_OFFSET] = (UINT8)(opcode & ER_BLE_ADV_BYTE_MASK);
  command[ER_BLE_HCI_COMMAND_OPCODE_HI_OFFSET] =
      (UINT8)((opcode >> ER_BLE_ADV_BYTE_BITS) & ER_BLE_ADV_BYTE_MASK);
  command[ER_BLE_HCI_COMMAND_PARAM_LEN_OFFSET] = params_len;
  if (params_len > 0u) {
    er_mem_copy(command + ER_BLE_HCI_COMMAND_HEADER_BYTES, params, params_len);
  }
  command_len = (UINTN)(ER_BLE_HCI_COMMAND_HEADER_BYTES + params_len);
  return (UINT8)(hc->SendCommand(hc, &command_len, command, ER_BLE_HCI_TIMEOUT) == EFI_SUCCESS);
}

UINT8 er_ble_adv_efi_init(EFI_SYSTEM_TABLE* system_table, ErBleAdvEfi* out_ble) {
  EFI_BLUETOOTH_HC_PROTOCOL* hc = 0;

  if (out_ble == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_ble, (UINTN)sizeof(*out_ble));
  if (system_table == 0 || system_table->BootServices == 0 ||
      system_table->BootServices->LocateProtocol == 0 ||
      system_table->BootServices->LocateProtocol(&g_er_bluetooth_hc_protocol_guid,
                                                 0,
                                                 (void**)&hc) != EFI_SUCCESS ||
      hc == 0) {
    return 0u;
  }
  out_ble->initialized = 1u;
  out_ble->hc = hc;
  return 1u;
}

UINT8 er_ble_adv_efi_start_advertising(ErBleAdvEfi* ble,
                                       const ErBleAdvPacket* packet) {
  UINT8 params[ER_BLE_HCI_LE_SET_ADV_DATA_BYTES];
  UINT8 adv_data[ER_BLE_ADV_LEGACY_DATA_BYTES];
  UINT8 adv_len;

  if (ble == 0 || ble->initialized == 0u || ble->hc == 0 ||
      er_ble_adv_encode_data(packet, adv_data, &adv_len) == 0u) {
    return 0u;
  }
  er_mem_zero(params, (UINTN)sizeof(params));
  params[ER_BLE_HCI_ADV_PARAM_INTERVAL_MIN_LO_OFFSET] = ER_BLE_HCI_ADV_INTERVAL_MIN_LO;
  params[ER_BLE_HCI_ADV_PARAM_INTERVAL_MIN_HI_OFFSET] = ER_BLE_HCI_ADV_INTERVAL_MIN_HI;
  params[ER_BLE_HCI_ADV_PARAM_INTERVAL_MAX_LO_OFFSET] = ER_BLE_HCI_ADV_INTERVAL_MAX_LO;
  params[ER_BLE_HCI_ADV_PARAM_INTERVAL_MAX_HI_OFFSET] = ER_BLE_HCI_ADV_INTERVAL_MAX_HI;
  params[ER_BLE_HCI_ADV_PARAM_TYPE_OFFSET] = ER_BLE_HCI_ADV_TYPE_NONCONNECTABLE;
  params[ER_BLE_HCI_ADV_PARAM_OWN_ADDR_TYPE_OFFSET] = ER_BLE_HCI_ADDR_TYPE_PUBLIC;
  params[ER_BLE_HCI_ADV_PARAM_PEER_ADDR_TYPE_OFFSET] = ER_BLE_HCI_ADDR_TYPE_PUBLIC;
  params[ER_BLE_HCI_ADV_PARAM_CHANNEL_MAP_OFFSET] = ER_BLE_HCI_ADV_CHANNEL_ALL;
  params[ER_BLE_HCI_ADV_PARAM_FILTER_POLICY_OFFSET] = ER_BLE_HCI_ADV_FILTER_ANY;
  if (er_ble_adv_efi_send_command(ble->hc,
                                  ER_BLE_HCI_OPCODE_LE_SET_ADV_PARAMETERS,
                                  params,
                                  ER_BLE_HCI_LE_SET_ADV_PARAMETERS_BYTES) == 0u) {
    return 0u;
  }

  er_mem_zero(params, (UINTN)sizeof(params));
  params[ER_BLE_HCI_ADV_DATA_LEN_OFFSET] = adv_len;
  er_mem_copy(params + ER_BLE_HCI_ADV_DATA_BYTES_OFFSET, adv_data, adv_len);
  if (er_ble_adv_efi_send_command(ble->hc,
                                  ER_BLE_HCI_OPCODE_LE_SET_ADV_DATA,
                                  params,
                                  ER_BLE_HCI_LE_SET_ADV_DATA_BYTES) == 0u) {
    return 0u;
  }

  params[ER_BLE_HCI_ADV_ENABLE_OFFSET] = ER_BLE_HCI_ENABLE;
  return er_ble_adv_efi_send_command(ble->hc,
                                     ER_BLE_HCI_OPCODE_LE_SET_ADV_ENABLE,
                                     params,
                                     ER_BLE_HCI_LE_SET_ADV_ENABLE_BYTES);
}

static UINT8 er_ble_adv_efi_enable_scan(ErBleAdvEfi* ble) {
  UINT8 params[ER_BLE_HCI_LE_SET_SCAN_PARAMETERS_BYTES];

  if (ble == 0 || ble->initialized == 0u || ble->hc == 0) {
    return 0u;
  }
  er_mem_zero(params, (UINTN)sizeof(params));
  params[ER_BLE_HCI_SCAN_PARAM_TYPE_OFFSET] = ER_BLE_HCI_SCAN_TYPE_PASSIVE;
  params[ER_BLE_HCI_SCAN_PARAM_INTERVAL_LO_OFFSET] = ER_BLE_HCI_SCAN_INTERVAL_LO;
  params[ER_BLE_HCI_SCAN_PARAM_INTERVAL_HI_OFFSET] = ER_BLE_HCI_SCAN_INTERVAL_HI;
  params[ER_BLE_HCI_SCAN_PARAM_WINDOW_LO_OFFSET] = ER_BLE_HCI_SCAN_WINDOW_LO;
  params[ER_BLE_HCI_SCAN_PARAM_WINDOW_HI_OFFSET] = ER_BLE_HCI_SCAN_WINDOW_HI;
  params[ER_BLE_HCI_SCAN_PARAM_OWN_ADDR_TYPE_OFFSET] = ER_BLE_HCI_SCAN_OWN_ADDR_PUBLIC;
  params[ER_BLE_HCI_SCAN_PARAM_FILTER_POLICY_OFFSET] = ER_BLE_HCI_SCAN_FILTER_ANY;
  if (er_ble_adv_efi_send_command(ble->hc,
                                  ER_BLE_HCI_OPCODE_LE_SET_SCAN_PARAMETERS,
                                  params,
                                  ER_BLE_HCI_LE_SET_SCAN_PARAMETERS_BYTES) == 0u) {
    return 0u;
  }
  params[ER_BLE_HCI_SCAN_ENABLE_OFFSET] = ER_BLE_HCI_ENABLE;
  params[ER_BLE_HCI_SCAN_DUP_FILTER_OFFSET] = ER_BLE_HCI_DISABLE_DUP_FILTER;
  return er_ble_adv_efi_send_command(ble->hc,
                                     ER_BLE_HCI_OPCODE_LE_SET_SCAN_ENABLE,
                                     params,
                                     ER_BLE_HCI_LE_SET_SCAN_ENABLE_BYTES);
}

UINT8 er_ble_adv_efi_poll_packet(ErBleAdvEfi* ble, ErBleAdvPacket* out_packet) {
  UINT8 event[ER_BLE_HCI_EVENT_BUFFER_BYTES];
  UINTN event_len = (UINTN)sizeof(event);
  UINT8 payload_len;
  UINT8 report_len;

  if (out_packet == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  if (ble == 0 || ble->initialized == 0u || ble->hc == 0 ||
      ble->hc->ReceiveEvent == 0 ||
      er_ble_adv_efi_enable_scan(ble) == 0u) {
    return 0u;
  }
  if (ble->hc->ReceiveEvent(ble->hc, &event_len, event, ER_BLE_HCI_TIMEOUT) != EFI_SUCCESS ||
      event_len < ER_BLE_HCI_EVENT_PAYLOAD_OFFSET + ER_BLE_HCI_LE_REPORT_MIN_BYTES ||
      event[ER_BLE_HCI_EVENT_CODE_OFFSET] != ER_BLE_HCI_EVENT_LE_META ||
      event[ER_BLE_HCI_EVENT_LEN_OFFSET] + ER_BLE_HCI_EVENT_PAYLOAD_OFFSET > event_len ||
      event[ER_BLE_HCI_EVENT_PAYLOAD_OFFSET] != ER_BLE_HCI_SUBEVENT_ADV_REPORT ||
      event[ER_BLE_HCI_EVENT_PAYLOAD_OFFSET + ER_BLE_HCI_LE_REPORT_COUNT_OFFSET] == 0u) {
    return 0u;
  }
  payload_len = event[ER_BLE_HCI_EVENT_PAYLOAD_OFFSET + ER_BLE_HCI_LE_REPORT_DATA_LEN_OFFSET];
  report_len = (UINT8)(ER_BLE_HCI_LE_REPORT_DATA_OFFSET +
                       payload_len +
                       ER_BLE_HCI_LE_REPORT_RSSI_BYTES);
  if ((UINTN)ER_BLE_HCI_EVENT_PAYLOAD_OFFSET + report_len > event_len) {
    return 0u;
  }
  return er_ble_adv_decode_data(event + ER_BLE_HCI_EVENT_PAYLOAD_OFFSET + ER_BLE_HCI_LE_REPORT_DATA_OFFSET,
                                payload_len,
                                out_packet);
}
