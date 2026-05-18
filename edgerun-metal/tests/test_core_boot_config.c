static void test_boot_config_and_seal_strategy(void) {
  ErBootConfig config;
  ErIdentity admission_identity;
  const ErBootFirmwareSourceConfig* firmware_source;
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];

  er_boot_config_init(&config);
  test_fill_bytes(admission_key, (UINTN)sizeof(admission_key), 0x42u);
  check_int64("boot config prepare admission identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_identity),
              1);
  check_int64("boot config set admission",
              er_boot_config_set_admission_identity(&config, &admission_identity), 1);
  check_int64("boot config add edgerun channel",
              er_boot_config_add_channel(&config, ER_CHANNEL_KIND_NATIVE_ETH,
                                         "edgerun0", 8u), 1);
  check_int64("boot config add tcp channel",
              er_boot_config_add_channel(&config, ER_CHANNEL_KIND_TCP_IP,
                                         "tcpip0", 6u), 1);
  check_int64("boot config add open wifi channel",
              er_boot_config_add_open_wifi_channel(&config,
                                                  ER_BOOT_CONFIG_WIFI_ROLE_AUTO,
                                                  "wifi0", 5u),
              1);
  check_int64("boot config reject absolute firmware path",
              er_boot_config_add_efi_firmware_source(&config, 0x10ecu, 0x8922u,
                                                     "/EFI/edgerun/rtw8922.bin", 24u),
              0);
  check_int64("boot config reject missing firmware target",
              er_boot_config_add_efi_firmware_source(&config, 0u, 0x8922u,
                                                     "EFI/edgerun/rtw8922.bin", 23u),
              0);
  check_int64("boot config add efi firmware source",
              er_boot_config_add_efi_firmware_source(&config, 0x10ecu, 0x8922u,
                                                     "EFI/edgerun/rtw8922.bin", 23u),
              1);
  check_int64("boot config invalid generation rejected",
              er_boot_config_valid(&config), 0);
  config.generation = 1u;
  check_int64("boot config valid",
              er_boot_config_valid(&config), 1);
  check_uint64("boot config channel count", config.channel_count, 3u);
  check_uint64("boot config firmware source count", config.firmware_source_count, 1u);
  check_uint64("boot config tcp channel kind",
               config.channels[1].channel_kind, ER_CHANNEL_KIND_TCP_IP);
  check_uint64("boot config wifi channel kind",
               config.channels[2].channel_kind, ER_CHANNEL_KIND_WIFI_OPEN_L2);
  check_uint64("boot config wifi role",
               config.channels[2].wifi_role, ER_BOOT_CONFIG_WIFI_ROLE_AUTO);
  check_uint64("boot config wifi security",
               config.channels[2].wifi_security, ER_BOOT_CONFIG_WIFI_SECURITY_OPEN);
  check_uint64("boot config wifi ssid len",
               config.channels[2].ssid_len, ER_BOOT_CONFIG_WIFI_FIXED_SSID_LEN);
  check_int64("boot config reject fixed ssid drift",
              (config.channels[2].ssid[0] = 'x', er_boot_config_valid(&config)), 0);
  config.channels[2].ssid[0] = 'e';
  check_int64("boot config restored fixed ssid",
              er_boot_config_valid(&config), 1);
  check_uint64("boot config firmware source kind",
               config.firmware_sources[0].source_kind,
               ER_BOOT_CONFIG_FIRMWARE_SOURCE_EFI_PARTITION);
  check_uint64("boot config firmware vendor",
               config.firmware_sources[0].pci_vendor_id, 0x10ecu);
  check_uint64("boot config firmware device",
               config.firmware_sources[0].pci_device_id, 0x8922u);
  check_uint64("boot config firmware path len",
               config.firmware_sources[0].path_len, 23u);
  check_int64("boot config reject firmware path drift",
              (config.firmware_sources[0].path[3] = ' ', er_boot_config_valid(&config)), 0);
  config.firmware_sources[0].path[3] = '/';
  check_int64("boot config restored firmware path",
              er_boot_config_valid(&config), 1);
  firmware_source = er_boot_config_find_efi_firmware_source(&config, 0x10ecu, 0x8922u);
  check_int64("boot config find firmware source", firmware_source != 0, 1);
  if (firmware_source != 0) {
    check_uint64("boot config find firmware path len", firmware_source->path_len, 23u);
  }
  check_int64("boot config find rejects wrong device",
              er_boot_config_find_efi_firmware_source(&config, 0x10ecu, 0x892bu) == 0, 1);

  check_int64("seal zero recipient invalid",
              er_seal_select_strategy(0u, 1u, 1u), ER_SEAL_STRATEGY_INVALID);
  check_int64("seal small direct recipient",
              er_seal_select_strategy(1u, 128u, 1u),
              ER_SEAL_STRATEGY_DIRECT_RECIPIENT);
  check_int64("seal large content key",
              er_seal_select_strategy(1u, ER_SEAL_CONTENT_KEY_THRESHOLD_BYTES, 1u),
              ER_SEAL_STRATEGY_CONTENT_KEY_WRAP);
  check_int64("seal multi recipient content key",
              er_seal_select_strategy(2u, 128u, 1u),
              ER_SEAL_STRATEGY_CONTENT_KEY_WRAP);
  check_int64("seal reuse content key",
              er_seal_select_strategy(1u, 128u, ER_SEAL_CONTENT_KEY_REUSE_MIN),
              ER_SEAL_STRATEGY_CONTENT_KEY_WRAP);
  check_cstr("seal content key label",
             er_seal_strategy_label(ER_SEAL_STRATEGY_CONTENT_KEY_WRAP),
             "content-key-wrap");
}
