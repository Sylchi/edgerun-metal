static void test_ieee80211_fill_probe_request(
    const ErIeee80211OpenApConfig* config,
    const UINT8 station_mac[ER_NET_MAC_LEN],
    UINT8 wildcard,
    UINT8* out_frame,
    UINT32* out_frame_len) {
  enum {
    IEEE80211_TEST_PROBE_REQUEST_FRAME_CONTROL = 0x0040u,
    IEEE80211_TEST_FRAME_CONTROL_OFFSET = 0u,
    IEEE80211_TEST_ADDR1_OFFSET = 4u,
    IEEE80211_TEST_ADDR2_OFFSET = 10u,
    IEEE80211_TEST_ADDR3_OFFSET = 16u,
    IEEE80211_TEST_IE_SSID = 0u,
    IEEE80211_TEST_IE_HEADER_LEN = 2u
  };
  UINT32 offset;

  er_mem_zero(out_frame, ER_IEEE80211_AP_FRAME_MAX);
  out_frame[IEEE80211_TEST_FRAME_CONTROL_OFFSET] =
      (UINT8)(IEEE80211_TEST_PROBE_REQUEST_FRAME_CONTROL & 0xffu);
  out_frame[IEEE80211_TEST_FRAME_CONTROL_OFFSET + 1u] =
      (UINT8)((IEEE80211_TEST_PROBE_REQUEST_FRAME_CONTROL >> 8u) & 0xffu);
  out_frame[IEEE80211_TEST_ADDR1_OFFSET] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR1_OFFSET + 1u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR1_OFFSET + 2u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR1_OFFSET + 3u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR1_OFFSET + 4u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR1_OFFSET + 5u] = 0xffu;
  er_mem_copy(out_frame + IEEE80211_TEST_ADDR2_OFFSET,
              station_mac,
              ER_NET_MAC_LEN);
  out_frame[IEEE80211_TEST_ADDR3_OFFSET] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR3_OFFSET + 1u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR3_OFFSET + 2u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR3_OFFSET + 3u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR3_OFFSET + 4u] = 0xffu;
  out_frame[IEEE80211_TEST_ADDR3_OFFSET + 5u] = 0xffu;

  offset = ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN;
  out_frame[offset] = IEEE80211_TEST_IE_SSID;
  out_frame[offset + 1u] = wildcard == 0u ? config->ssid_len : 0u;
  offset += IEEE80211_TEST_IE_HEADER_LEN;
  if (wildcard == 0u) {
    er_mem_copy(out_frame + offset, config->ssid, config->ssid_len);
    offset += config->ssid_len;
  }
  *out_frame_len = offset;
}

typedef struct {
  const UINT8* ram_bytes;
  const UINT8* nvram_bytes;
  const UINT8* clm_blob_bytes;
  UINTN ram_len;
  UINTN nvram_len;
  UINTN clm_blob_len;
  UINT8 ram_called;
  UINT8 nvram_called;
  UINT8 clm_blob_called;
} Cyw43438TestFirmwareReader;

static UINT8 cyw43438_test_firmware_read(void* ctx,
                                         const char* path,
                                         UINT16 path_len,
                                         UINT8* out_bytes,
                                         UINTN out_capacity,
                                         UINTN* out_len) {
  Cyw43438TestFirmwareReader* reader;
  static const char ram_path[] = "/EFI/firmware/02d0.a9a6.0";
  static const char nvram_path[] = "/EFI/firmware/02d0.a9a6.1";
  static const char clm_blob_path[] = "/EFI/firmware/02d0.a9a6.2";

  reader = (Cyw43438TestFirmwareReader*)ctx;
  if (reader == 0 ||
      path == 0 ||
      out_bytes == 0 ||
      out_len == 0) {
    return 0u;
  }
  if (path_len == (UINT16)(sizeof(ram_path) - 1u) &&
      er_mem_equal((const UINT8*)path,
                   (const UINT8*)ram_path,
                   (UINTN)(sizeof(ram_path) - 1u)) != 0u) {
    if (reader->ram_len > out_capacity) {
      return 0u;
    }
    er_mem_copy(out_bytes, reader->ram_bytes, reader->ram_len);
    *out_len = reader->ram_len;
    reader->ram_called = 1u;
    return 1u;
  }
  if (path_len == (UINT16)(sizeof(nvram_path) - 1u) &&
      er_mem_equal((const UINT8*)path,
                   (const UINT8*)nvram_path,
                   (UINTN)(sizeof(nvram_path) - 1u)) != 0u) {
    if (reader->nvram_len > out_capacity) {
      return 0u;
    }
    er_mem_copy(out_bytes, reader->nvram_bytes, reader->nvram_len);
    *out_len = reader->nvram_len;
    reader->nvram_called = 1u;
    return 1u;
  }
  if (path_len == (UINT16)(sizeof(clm_blob_path) - 1u) &&
      er_mem_equal((const UINT8*)path,
                   (const UINT8*)clm_blob_path,
                   (UINTN)(sizeof(clm_blob_path) - 1u)) != 0u) {
    if (reader->clm_blob_len > out_capacity) {
      return 0u;
    }
    er_mem_copy(out_bytes, reader->clm_blob_bytes, reader->clm_blob_len);
    *out_len = reader->clm_blob_len;
    reader->clm_blob_called = 1u;
    return 1u;
  }
  return 0u;
}

static void test_ieee80211_open_ap_frames(void) {
  enum {
    IEEE80211_TEST_NODE_SEED = 0x31u,
    IEEE80211_TEST_STATION_SEED = 0x71u,
    IEEE80211_TEST_CHANNEL = 6u,
    IEEE80211_TEST_RCA = 0x1234u,
    IEEE80211_TEST_BEACON_LEN = 66u,
    IEEE80211_TEST_FRAME_CONTROL_OFFSET = 0u,
    IEEE80211_TEST_ADDR1_OFFSET = 4u,
    IEEE80211_TEST_ADDR2_OFFSET = 10u,
    IEEE80211_TEST_ADDR3_OFFSET = 16u,
    IEEE80211_TEST_SEQUENCE_OFFSET = 22u,
    IEEE80211_TEST_INTERVAL_OFFSET = 32u,
    IEEE80211_TEST_CAPABILITY_OFFSET = 34u,
    IEEE80211_TEST_IE_OFFSET = 36u,
    IEEE80211_TEST_RATES_OFFSET = 57u,
    IEEE80211_TEST_DS_OFFSET = 63u,
    IEEE80211_TEST_BEACON_FRAME_CONTROL = 0x0080u,
    IEEE80211_TEST_PROBE_RESPONSE_FRAME_CONTROL = 0x0050u,
    IEEE80211_TEST_PROBE_RESPONSE_SEQUENCE = 0x0010u,
    IEEE80211_TEST_BEACON_INTERVAL_LOW = 100u,
    IEEE80211_TEST_CAPABILITY_LOW = 0x21u,
    IEEE80211_TEST_CAPABILITY_HIGH = 0x04u,
    IEEE80211_TEST_IE_SSID = 0u,
    IEEE80211_TEST_IE_SUPPORTED_RATES = 1u,
    IEEE80211_TEST_IE_DS_PARAMETER_SET = 3u,
    IEEE80211_TEST_RATE_1M_BASIC = 0x82u,
    IEEE80211_TEST_RATE_11M_BASIC = 0x96u,
    IEEE80211_TEST_STAGE_IDENTITY = 0u,
    IEEE80211_TEST_STAGE_CLAIM = 1u,
    IEEE80211_TEST_STAGE_BEACON = 2u,
    IEEE80211_TEST_STAGE_PROBE = 3u,
    IEEE80211_TEST_FIRMWARE_RAM_SEED = 0x91u,
    IEEE80211_TEST_FIRMWARE_NVRAM_SEED = 0x92u,
    IEEE80211_TEST_FIRMWARE_CLM_SEED = 0x93u,
    IEEE80211_TEST_FIRMWARE_RAM_LEN = 8u,
    IEEE80211_TEST_FIRMWARE_NVRAM_LEN = 5u,
    IEEE80211_TEST_FIRMWARE_CLM_LEN = 6u
  };
  ErNodeId node_id;
  ErWifiL2ApPlan ap_plan;
  ErIeee80211OpenApConfig config;
  ErBootConfig boot_config;
  ErCryptoProvider crypto;
  ErCyw43438ApPath path;
  ErCyw43438FirmwareSet firmware;
  ErCyw43438OpenApBootDevice boot_device;
  Cyw43438TestFirmwareReader reader;
  UINT8 ram_bytes[IEEE80211_TEST_FIRMWARE_RAM_LEN];
  UINT8 nvram_bytes[IEEE80211_TEST_FIRMWARE_NVRAM_LEN];
  UINT8 clm_blob_bytes[IEEE80211_TEST_FIRMWARE_CLM_LEN];
  UINT8 ram_out[IEEE80211_TEST_FIRMWARE_RAM_LEN];
  UINT8 nvram_out[IEEE80211_TEST_FIRMWARE_NVRAM_LEN];
  UINT8 clm_blob_out[IEEE80211_TEST_FIRMWARE_CLM_LEN];
  UINT8 station_mac[ER_NET_MAC_LEN];
  UINT8 frame[ER_IEEE80211_AP_FRAME_MAX];
  UINT8 probe_request[ER_IEEE80211_AP_FRAME_MAX];
  UINT32 frame_len;
  UINT32 probe_request_len;

  test_fill_bytes(node_id.bytes, ER_NODE_ID_LEN, IEEE80211_TEST_NODE_SEED);
  test_fill_bytes(ram_bytes,
                  (UINTN)sizeof(ram_bytes),
                  IEEE80211_TEST_FIRMWARE_RAM_SEED);
  test_fill_bytes(nvram_bytes,
                  (UINTN)sizeof(nvram_bytes),
                  IEEE80211_TEST_FIRMWARE_NVRAM_SEED);
  test_fill_bytes(clm_blob_bytes,
                  (UINTN)sizeof(clm_blob_bytes),
                  IEEE80211_TEST_FIRMWARE_CLM_SEED);
  test_fill_bytes(station_mac,
                  (UINTN)sizeof(station_mac),
                  IEEE80211_TEST_STATION_SEED);
  station_mac[0] &= (UINT8)~1u;
  crypto.ctx = (void*)0x21u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  check_int64("ieee80211 ap plan",
              er_wifi_l2_ap_plan_prepare(&node_id,
                                         IEEE80211_TEST_CHANNEL,
                                         &ap_plan),
              1);
  check_int64("ieee80211 config from l2",
              er_ieee80211_open_ap_config_from_l2_plan(&ap_plan, &config),
              1);
  check_uint64("ieee80211 config beacon interval",
               config.beacon_interval_tu,
               ER_IEEE80211_AP_BEACON_INTERVAL_TU);
  check_uint64("ieee80211 config channel",
               config.channel,
               IEEE80211_TEST_CHANNEL);
  check_int64("ieee80211 config bssid",
              er_mem_equal(config.bssid, ap_plan.mac, ER_NET_MAC_LEN),
              1);

  check_int64("ieee80211 beacon build",
              er_ieee80211_open_ap_build_beacon(&config,
                                                0u,
                                                frame,
                                                (UINT32)sizeof(frame),
                                                &frame_len),
              1);
  check_uint64("ieee80211 beacon len", frame_len, IEEE80211_TEST_BEACON_LEN);
  check_uint64("ieee80211 beacon fc low",
               frame[IEEE80211_TEST_FRAME_CONTROL_OFFSET],
               IEEE80211_TEST_BEACON_FRAME_CONTROL);
  check_uint64("ieee80211 beacon broadcast",
               frame[IEEE80211_TEST_ADDR1_OFFSET],
               0xffu);
  check_int64("ieee80211 beacon transmitter",
              er_mem_equal(frame + IEEE80211_TEST_ADDR2_OFFSET,
                           ap_plan.mac,
                           ER_NET_MAC_LEN),
              1);
  check_int64("ieee80211 beacon bssid",
              er_mem_equal(frame + IEEE80211_TEST_ADDR3_OFFSET,
                           ap_plan.mac,
                           ER_NET_MAC_LEN),
              1);
  check_uint64("ieee80211 beacon interval low",
               frame[IEEE80211_TEST_INTERVAL_OFFSET],
               IEEE80211_TEST_BEACON_INTERVAL_LOW);
  check_uint64("ieee80211 beacon capability low",
               frame[IEEE80211_TEST_CAPABILITY_OFFSET],
               IEEE80211_TEST_CAPABILITY_LOW);
  check_uint64("ieee80211 beacon capability high",
               frame[IEEE80211_TEST_CAPABILITY_OFFSET + 1u],
               IEEE80211_TEST_CAPABILITY_HIGH);
  check_uint64("ieee80211 beacon ssid ie",
               frame[IEEE80211_TEST_IE_OFFSET],
               IEEE80211_TEST_IE_SSID);
  check_uint64("ieee80211 beacon ssid len",
               frame[IEEE80211_TEST_IE_OFFSET + 1u],
               ER_WIFI_L2_NODE_SSID_LEN);
  check_int64("ieee80211 beacon ssid bytes",
              er_mem_equal(frame + IEEE80211_TEST_IE_OFFSET + 2u,
                           ap_plan.ssid,
                           ap_plan.ssid_len),
              1);
  check_uint64("ieee80211 beacon rates ie",
               frame[IEEE80211_TEST_RATES_OFFSET],
               IEEE80211_TEST_IE_SUPPORTED_RATES);
  check_uint64("ieee80211 beacon first rate",
               frame[IEEE80211_TEST_RATES_OFFSET + 2u],
               IEEE80211_TEST_RATE_1M_BASIC);
  check_uint64("ieee80211 beacon last rate",
               frame[IEEE80211_TEST_RATES_OFFSET + 5u],
               IEEE80211_TEST_RATE_11M_BASIC);
  check_uint64("ieee80211 beacon ds ie",
               frame[IEEE80211_TEST_DS_OFFSET],
               IEEE80211_TEST_IE_DS_PARAMETER_SET);
  check_uint64("ieee80211 beacon ds channel",
               frame[IEEE80211_TEST_DS_OFFSET + 2u],
               IEEE80211_TEST_CHANNEL);

  check_int64("ieee80211 probe response build",
              er_ieee80211_open_ap_build_probe_response(&config,
                                                        station_mac,
                                                        1u,
                                                        frame,
                                                        (UINT32)sizeof(frame),
                                                        &frame_len),
              1);
  check_uint64("ieee80211 probe response fc",
               frame[IEEE80211_TEST_FRAME_CONTROL_OFFSET],
               IEEE80211_TEST_PROBE_RESPONSE_FRAME_CONTROL);
  check_int64("ieee80211 probe response receiver",
              er_mem_equal(frame + IEEE80211_TEST_ADDR1_OFFSET,
                           station_mac,
                           ER_NET_MAC_LEN),
              1);
  check_uint64("ieee80211 probe response sequence",
               frame[IEEE80211_TEST_SEQUENCE_OFFSET],
               IEEE80211_TEST_PROBE_RESPONSE_SEQUENCE);

  test_ieee80211_fill_probe_request(&config,
                                    station_mac,
                                    0u,
                                    probe_request,
                                    &probe_request_len);
  check_int64("ieee80211 probe request match",
              er_ieee80211_open_ap_probe_request_matches(&config,
                                                         probe_request,
                                                         probe_request_len),
              1);
  test_ieee80211_fill_probe_request(&config,
                                    station_mac,
                                    1u,
                                    probe_request,
                                    &probe_request_len);
  check_int64("ieee80211 wildcard probe request match",
              er_ieee80211_open_ap_probe_request_matches(&config,
                                                         probe_request,
                                                         probe_request_len),
              1);
  test_ieee80211_fill_probe_request(&config,
                                    station_mac,
                                    0u,
                                    probe_request,
                                    &probe_request_len);
  probe_request[ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN + 2u] = (UINT8)'x';
  check_int64("ieee80211 wrong probe request rejects",
              er_ieee80211_open_ap_probe_request_matches(&config,
                                                         probe_request,
                                                         probe_request_len),
              0);
  check_int64("ieee80211 beacon rejects short buffer",
              er_ieee80211_open_ap_build_beacon(&config,
                                                0u,
                                                frame,
                                                ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN,
                                                &frame_len),
              0);

  check_int64("cyw43438 open l2 path",
              er_cyw43438_prepare_open_l2_ap_path(&ap_plan,
                                                  IEEE80211_TEST_RCA,
                                                  station_mac,
                                                  &path),
              1);
  check_uint64("cyw43438 path stage count",
               path.stage_count,
               ER_CYW43438_AP_STAGE_COUNT);
  check_uint64("cyw43438 path blocked executor",
               path.blocked_reason,
               ER_CYW43438_AP_BLOCKED_NO_FIRMWARE_REGISTER_EXECUTOR);
  check_uint64("cyw43438 identity stage",
               path.stages[IEEE80211_TEST_STAGE_IDENTITY].kind,
               ER_CYW43438_AP_STAGE_SDIO_IDENTITY);
  check_uint64("cyw43438 claim stage",
               path.stages[IEEE80211_TEST_STAGE_CLAIM].kind,
               ER_CYW43438_AP_STAGE_SDIO_CLAIM);
  check_uint64("cyw43438 beacon stage",
               path.stages[IEEE80211_TEST_STAGE_BEACON].kind,
               ER_CYW43438_AP_STAGE_INSTALL_BEACON_TEMPLATE);
  check_uint64("cyw43438 probe stage",
               path.stages[IEEE80211_TEST_STAGE_PROBE].kind,
               ER_CYW43438_AP_STAGE_INSTALL_PROBE_RESPONSE_TEMPLATE);
  check_uint64("cyw43438 identity commands",
               path.stages[IEEE80211_TEST_STAGE_IDENTITY].sdio_plan.command_count,
               3u);
  check_uint64("cyw43438 claim commands",
               path.stages[IEEE80211_TEST_STAGE_CLAIM].sdio_plan.command_count,
               2u);
  check_uint64("cyw43438 beacon template kind",
               path.stages[IEEE80211_TEST_STAGE_BEACON].ap_template.kind,
               ER_CYW43438_AP_TEMPLATE_BEACON);
  check_uint64("cyw43438 beacon template frame",
               path.stages[IEEE80211_TEST_STAGE_BEACON].ap_template.frame[
                   IEEE80211_TEST_FRAME_CONTROL_OFFSET],
               IEEE80211_TEST_BEACON_FRAME_CONTROL);
  check_uint64("cyw43438 probe template kind",
               path.stages[IEEE80211_TEST_STAGE_PROBE].ap_template.kind,
               ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE);
  check_int64("cyw43438 path blocked without rca",
              er_cyw43438_prepare_open_l2_ap_path(&ap_plan,
                                                  0u,
                                                  station_mac,
                                                  &path),
              1);
  check_uint64("cyw43438 claim blocked reason",
               path.stages[IEEE80211_TEST_STAGE_CLAIM].blocked_reason,
               ER_CYW43438_AP_BLOCKED_NO_RCA);

  er_boot_config_init(&boot_config);
  check_int64("cyw43438 add firmware sources",
              er_cyw43438_add_pi_zero_w_firmware_sources(&boot_config),
              1);
  check_uint64("cyw43438 firmware source count",
               boot_config.firmware_source_count,
               ER_CYW43438_FIRMWARE_SOURCE_COUNT);
  check_cstr("cyw43438 firmware ram path",
             boot_config.firmware_sources[0].path,
             "/EFI/firmware/02d0.a9a6.0");
  check_cstr("cyw43438 firmware nvram path",
             boot_config.firmware_sources[1].path,
             "/EFI/firmware/02d0.a9a6.1");
  check_cstr("cyw43438 firmware clm path",
             boot_config.firmware_sources[2].path,
             "/EFI/firmware/02d0.a9a6.2");

  reader.ram_bytes = ram_bytes;
  reader.nvram_bytes = nvram_bytes;
  reader.clm_blob_bytes = clm_blob_bytes;
  reader.ram_len = (UINTN)sizeof(ram_bytes);
  reader.nvram_len = (UINTN)sizeof(nvram_bytes);
  reader.clm_blob_len = (UINTN)sizeof(clm_blob_bytes);
  reader.ram_called = 0u;
  reader.nvram_called = 0u;
  reader.clm_blob_called = 0u;
  check_int64("cyw43438 load firmware",
              er_cyw43438_load_pi_zero_w_firmware(&crypto,
                                                  &boot_config,
                                                  cyw43438_test_firmware_read,
                                                  &reader,
                                                  ram_out,
                                                  (UINTN)sizeof(ram_out),
                                                  nvram_out,
                                                  (UINTN)sizeof(nvram_out),
                                                  clm_blob_out,
                                                  (UINTN)sizeof(clm_blob_out),
                                                  &firmware),
              1);
  check_int64("cyw43438 ram called", reader.ram_called, 1);
  check_int64("cyw43438 nvram called", reader.nvram_called, 1);
  check_int64("cyw43438 clm called", reader.clm_blob_called, 1);
  check_uint64("cyw43438 ram instance",
               firmware.ram.instance,
               ER_CYW43438_FIRMWARE_INSTANCE_RAM);
  check_uint64("cyw43438 nvram instance",
               firmware.nvram.instance,
               ER_CYW43438_FIRMWARE_INSTANCE_NVRAM);
  check_uint64("cyw43438 clm instance",
               firmware.clm_blob.instance,
               ER_CYW43438_FIRMWARE_INSTANCE_CLM_BLOB);
  check_uint64("cyw43438 ram bytes",
               firmware.ram.bytes_len,
               (UINT64)sizeof(ram_bytes));
  check_uint64("cyw43438 nvram bytes",
               firmware.nvram.bytes_len,
               (UINT64)sizeof(nvram_bytes));
  check_uint64("cyw43438 clm bytes",
               firmware.clm_blob.bytes_len,
               (UINT64)sizeof(clm_blob_bytes));

  reader.ram_called = 0u;
  reader.nvram_called = 0u;
  reader.clm_blob_called = 0u;
  check_int64("cyw43438 boot device",
              er_cyw43438_prepare_open_l2_ap_boot_device(
                  &crypto,
                  &boot_config,
                  cyw43438_test_firmware_read,
                  &reader,
                  ram_out,
                  (UINTN)sizeof(ram_out),
                  nvram_out,
                  (UINTN)sizeof(nvram_out),
                  clm_blob_out,
                  (UINTN)sizeof(clm_blob_out),
                  &ap_plan,
                  IEEE80211_TEST_RCA,
                  station_mac,
                  &boot_device),
              1);
  check_uint64("cyw43438 boot device abi",
               boot_device.abi_version,
               ER_CYW43438_ABI_VERSION);
  check_uint64("cyw43438 boot device stage count",
               boot_device.ap_path.stage_count,
               ER_CYW43438_AP_STAGE_COUNT);
  check_uint64("cyw43438 boot device firmware",
               boot_device.firmware.ram.loaded,
               1u);
}
