static UINT8 g_test_ble_locate_protocol_called;
static UINT8 g_test_ble_send_count;
static UINT16 g_test_ble_opcodes[8];
static UINT8 g_test_ble_command_params[8][32];
static UINT8 g_test_ble_event[64];
static UINTN g_test_ble_event_len;
static EFI_BLUETOOTH_HC_PROTOCOL g_test_ble_hc;

static EFI_STATUS test_ble_locate_protocol(EFI_GUID* Protocol,
                                           void* Registration,
                                           void** Interface) {
  (void)Protocol;
  (void)Registration;

  g_test_ble_locate_protocol_called = 1u;
  if (Interface == 0) {
    return EFI_INVALID_PARAMETER;
  }
  *Interface = &g_test_ble_hc;
  return EFI_SUCCESS;
}

static EFI_STATUS EFIAPI test_ble_send_command(EFI_BLUETOOTH_HC_PROTOCOL* This,
                                               UINTN* BufferSize,
                                               void* Buffer,
                                               UINTN Timeout) {
  UINT8* bytes = (UINT8*)Buffer;

  (void)This;
  (void)Timeout;

  if (BufferSize == 0 || Buffer == 0 || *BufferSize < 3u || g_test_ble_send_count >= 8u) {
    return EFI_INVALID_PARAMETER;
  }
  g_test_ble_opcodes[g_test_ble_send_count] = (UINT16)((UINT16)bytes[0] | ((UINT16)bytes[1] << 8u));
  er_mem_copy(g_test_ble_command_params[g_test_ble_send_count], bytes + 3u, bytes[2]);
  g_test_ble_send_count += 1u;
  return EFI_SUCCESS;
}

static EFI_STATUS EFIAPI test_ble_receive_event(EFI_BLUETOOTH_HC_PROTOCOL* This,
                                                UINTN* BufferSize,
                                                void* Buffer,
                                                UINTN Timeout) {
  (void)This;
  (void)Timeout;

  if (BufferSize == 0 || Buffer == 0 || *BufferSize < g_test_ble_event_len) {
    return EFI_INVALID_PARAMETER;
  }
  er_mem_copy((UINT8*)Buffer, g_test_ble_event, g_test_ble_event_len);
  *BufferSize = g_test_ble_event_len;
  return EFI_SUCCESS;
}

static void test_ble_adv(void) {
  static const UINT8 payload[ER_BLE_ADV_PAYLOAD_BYTES] = {
    'e', 'd', 'g', 'e', 'r', 'u', 'n', ':', 'b', 'l', 'e', ':', '0', '0', '1', '2', '3', '4'
  };
  ErBleAdvPacket packet;
  ErBleAdvPacket decoded;
  ErBleAdvEfi ble;
  EFI_BOOT_SERVICES boot_services;
  EFI_SYSTEM_TABLE system_table;
  UINT8 data[ER_BLE_ADV_LEGACY_DATA_BYTES];
  UINT8 data_len;
  UINT8 i;

  check_int64("ble adv reject zero channel",
              er_ble_adv_prepare_packet(0u, 1u, 0u, 1u, payload, 1u, &packet), 0);
  check_int64("ble adv reject zero sequence",
              er_ble_adv_prepare_packet(ER_BLE_ADV_CHANNEL_ID, 0u, 0u, 1u,
                                        payload, 1u, &packet), 0);
  check_int64("ble adv reject bad fragment",
              er_ble_adv_prepare_packet(ER_BLE_ADV_CHANNEL_ID, 1u, 1u, 1u,
                                        payload, 1u, &packet), 0);
  check_int64("ble adv prepare full payload",
              er_ble_adv_prepare_packet(ER_BLE_ADV_CHANNEL_ID, 7u, 0u, 1u,
                                        payload, ER_BLE_ADV_PAYLOAD_BYTES, &packet), 1);
  check_int64("ble adv encode",
              er_ble_adv_encode_data(&packet, data, &data_len), 1);
  check_uint64("ble adv encoded length", data_len, ER_BLE_ADV_LEGACY_DATA_BYTES);
  check_int64("ble adv decode",
              er_ble_adv_decode_data(data, data_len, &decoded), 1);
  check_uint64("ble adv decoded channel", decoded.channel_id, ER_BLE_ADV_CHANNEL_ID);
  check_uint64("ble adv decoded sequence", decoded.sequence, 7u);
  check_uint64("ble adv decoded payload len", decoded.payload_len, ER_BLE_ADV_PAYLOAD_BYTES);
  for (i = 0u; i < ER_BLE_ADV_PAYLOAD_BYTES; ++i) {
    check_uint64("ble adv decoded payload byte", decoded.payload[i], payload[i]);
  }

  data[12] = (UINT8)(ER_BLE_ADV_PAYLOAD_BYTES + 1u);
  check_int64("ble adv reject oversized decoded payload",
              er_ble_adv_decode_data(data, data_len, &decoded), 0);
  check_int64("ble adv re-encode after malformed case",
              er_ble_adv_encode_data(&packet, data, &data_len), 1);

  er_mem_zero((UINT8*)&g_test_ble_hc, (UINTN)sizeof(g_test_ble_hc));
  er_mem_zero((UINT8*)&boot_services, (UINTN)sizeof(boot_services));
  er_mem_zero((UINT8*)&system_table, (UINTN)sizeof(system_table));
  er_mem_zero((UINT8*)g_test_ble_opcodes, (UINTN)sizeof(g_test_ble_opcodes));
  er_mem_zero((UINT8*)g_test_ble_command_params, (UINTN)sizeof(g_test_ble_command_params));
  g_test_ble_locate_protocol_called = 0u;
  g_test_ble_send_count = 0u;
  g_test_ble_hc.SendCommand = test_ble_send_command;
  g_test_ble_hc.ReceiveEvent = test_ble_receive_event;
  boot_services.LocateProtocol = test_ble_locate_protocol;
  system_table.BootServices = &boot_services;
  check_int64("ble adv efi init",
              er_ble_adv_efi_init(&system_table, &ble), 1);
  check_uint64("ble adv locate called", g_test_ble_locate_protocol_called, 1u);
  check_int64("ble adv efi start advertising",
              er_ble_adv_efi_start_advertising(&ble, &packet), 1);
  check_uint64("ble adv command count", g_test_ble_send_count, 3u);
  check_uint64("ble adv params opcode", g_test_ble_opcodes[0], 0x2006u);
  check_uint64("ble adv data opcode", g_test_ble_opcodes[1], 0x2008u);
  check_uint64("ble adv enable opcode", g_test_ble_opcodes[2], 0x200au);
  check_uint64("ble adv hci data len", g_test_ble_command_params[1][0], ER_BLE_ADV_LEGACY_DATA_BYTES);
  check_uint64("ble adv hci enable", g_test_ble_command_params[2][0], 1u);

  er_mem_zero(g_test_ble_event, (UINTN)sizeof(g_test_ble_event));
  g_test_ble_event[0] = 0x3eu;
  g_test_ble_event[1] = (UINT8)(12u + data_len);
  g_test_ble_event[2] = 0x02u;
  g_test_ble_event[3] = 1u;
  g_test_ble_event[12] = data_len;
  er_mem_copy(g_test_ble_event + 13u, data, data_len);
  g_test_ble_event[13u + data_len] = 0xc0u;
  g_test_ble_event_len = 14u + data_len;
  check_int64("ble adv efi poll packet",
              er_ble_adv_efi_poll_packet(&ble, &decoded), 1);
  check_uint64("ble adv scan parameters opcode", g_test_ble_opcodes[3], 0x200bu);
  check_uint64("ble adv scan enable opcode", g_test_ble_opcodes[4], 0x200cu);
  check_uint64("ble adv polled sequence", decoded.sequence, 7u);
}
