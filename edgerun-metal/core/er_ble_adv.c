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
  ER_BLE_ADV_U16_LO_OFFSET = 0u,
  ER_BLE_ADV_U16_HI_OFFSET = 1u,
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
