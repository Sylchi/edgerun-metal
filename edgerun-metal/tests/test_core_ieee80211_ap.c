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
    IEEE80211_TEST_STAGE_PROBE = 3u
  };
  ErNodeId node_id;
  ErWifiL2ApPlan ap_plan;
  ErIeee80211OpenApConfig config;
  ErCyw43438ApPath path;
  UINT8 station_mac[ER_NET_MAC_LEN];
  UINT8 frame[ER_IEEE80211_AP_FRAME_MAX];
  UINT8 probe_request[ER_IEEE80211_AP_FRAME_MAX];
  UINT32 frame_len;
  UINT32 probe_request_len;

  test_fill_bytes(node_id.bytes, ER_NODE_ID_LEN, IEEE80211_TEST_NODE_SEED);
  test_fill_bytes(station_mac,
                  (UINTN)sizeof(station_mac),
                  IEEE80211_TEST_STATION_SEED);
  station_mac[0] &= (UINT8)~1u;

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
}
