static void test_node_control_relay_assignment(void) {
  enum {
    NODE_CONTROL_TEST_RELAY_KEY = 0x31u,
    NODE_CONTROL_TEST_ADMISSION_KEY = 0x41u,
    NODE_CONTROL_TEST_WORKER_KEY = 0x51u,
    NODE_CONTROL_TEST_HASH = 0x61u,
    NODE_CONTROL_TEST_SIGNATURE = 0x71u,
    NODE_CONTROL_TEST_CHANNEL = 6u,
    NODE_CONTROL_TEST_SEQUENCE = 1u,
    NODE_CONTROL_TEST_NOW_MS = 1000u,
    NODE_CONTROL_TEST_VALID_UNTIL_MS = 60000u
  };
  UINT8 relay_key[ER_PUBLIC_KEY_LEN];
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];
  UINT8 worker_key[ER_PUBLIC_KEY_LEN];
  ErNodeIdentity relay_node;
  ErNodeIdentity admission_node;
  ErNodeIdentity worker_node;
  ErWifiL2ApPlan ap_plan;
  ErChannelEndpoint wifi_endpoint;
  ErRelayEndpoint relay_endpoint;
  ErNodeAvailable relay_available;
  ErNodeAvailable worker_available;
  ErNodeHeartbeat heartbeat;
  ErRelayAssignment assignment;
  ErHash channel_id;
  ErHash log_head;
  ErHash connection_hash;
  ErHash zero_hash;
  ErWorkSignature signature;
  static const char node_control_wifi_label[] = "pi-wifi-l2";

  test_fill_bytes(relay_key, (UINTN)sizeof(relay_key),
                  NODE_CONTROL_TEST_RELAY_KEY);
  test_fill_bytes(admission_key, (UINTN)sizeof(admission_key),
                  NODE_CONTROL_TEST_ADMISSION_KEY);
  test_fill_bytes(worker_key, (UINTN)sizeof(worker_key),
                  NODE_CONTROL_TEST_WORKER_KEY);
  test_fill_bytes(log_head.bytes, ER_HASH_LEN, NODE_CONTROL_TEST_HASH);
  test_fill_bytes(channel_id.bytes, ER_HASH_LEN,
                  (UINT8)(NODE_CONTROL_TEST_HASH + 2u));
  test_fill_bytes(connection_hash.bytes, ER_HASH_LEN,
                  (UINT8)(NODE_CONTROL_TEST_HASH + 1u));
  er_mem_zero((UINT8*)&zero_hash, (UINTN)sizeof(zero_hash));
  er_mem_zero((UINT8*)&signature, (UINTN)sizeof(signature));
  signature.algorithm = 1u;
  signature.signature_len = ER_SIGNATURE_LEN;
  test_fill_bytes(signature.signature, ER_SIGNATURE_LEN,
                  NODE_CONTROL_TEST_SIGNATURE);

  er_mem_zero((UINT8*)&relay_node, (UINTN)sizeof(relay_node));
  relay_node.abi_version = ER_WORK_ABI_VERSION;
  relay_node.role = ER_NODE_ROLE_RELAY;
  check_int64("node control relay identity",
              er_credential_prepare(ER_CREDENTIAL_KIND_PUBLIC_KEY,
                                  ER_CREDENTIAL_BACKING_ED25519,
                                  relay_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &relay_node.identity),
              1);
  er_mem_copy(relay_node.node_id.bytes, relay_key, ER_NODE_ID_LEN);

  er_mem_zero((UINT8*)&admission_node, (UINTN)sizeof(admission_node));
  admission_node.abi_version = ER_WORK_ABI_VERSION;
  admission_node.role = ER_NODE_ROLE_ADMISSION;
  check_int64("node control admission identity",
              er_credential_prepare(ER_CREDENTIAL_KIND_PUBLIC_KEY,
                                  ER_CREDENTIAL_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_node.identity),
              1);
  er_mem_copy(admission_node.node_id.bytes, admission_key, ER_NODE_ID_LEN);

  er_mem_zero((UINT8*)&worker_node, (UINTN)sizeof(worker_node));
  worker_node.abi_version = ER_WORK_ABI_VERSION;
  worker_node.role = ER_NODE_ROLE_STORAGE;
  check_int64("node control worker identity",
              er_credential_prepare(ER_CREDENTIAL_KIND_PUBLIC_KEY,
                                  ER_CREDENTIAL_BACKING_ED25519,
                                  worker_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &worker_node.identity),
              1);
  er_mem_copy(worker_node.node_id.bytes, worker_key, ER_NODE_ID_LEN);

  check_int64("node control ap plan",
              er_wifi_l2_ap_plan_prepare(&relay_node.node_id,
                                         NODE_CONTROL_TEST_CHANNEL,
                                         &ap_plan),
              1);
  check_int64("node control wifi endpoint",
              er_wifi_l2_prepare_channel_endpoint(&channel_id,
                                                  &ap_plan,
                                                  node_control_wifi_label,
                                                  (UINTN)(sizeof(node_control_wifi_label) - 1u),
                                                  &wifi_endpoint),
              1);
  check_int64("node control wifi endpoint valid",
              er_wifi_l2_channel_endpoint_valid(&wifi_endpoint),
              1);
  check_uint64("node control wifi endpoint kind",
               wifi_endpoint.kind,
               ER_CHANNEL_KIND_WIFI_OPEN_L2);
  check_uint64("node control wifi endpoint channel",
               wifi_endpoint.address[ER_WIFI_L2_ENDPOINT_ADDR_CHANNEL_OFFSET],
               NODE_CONTROL_TEST_CHANNEL);
  check_uint64("node control wifi endpoint ssid prefix",
               wifi_endpoint.address[ER_WIFI_L2_ENDPOINT_ADDR_SSID_OFFSET],
               (UINT8)'e');

  check_int64("node control relay endpoint",
              er_relay_endpoint_prepare(&relay_node.node_id,
                                        &wifi_endpoint,
                                        &relay_endpoint),
              1);
  check_int64("node control relay endpoint valid",
              er_relay_endpoint_valid(&relay_endpoint),
              1);

  check_int64("node control relay availability",
              er_node_available_prepare(&relay_node,
                                        &relay_endpoint,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        ER_NODE_CONTROL_DEFAULT_HEARTBEAT_SECS,
                                        &log_head,
                                        &signature,
                                        &relay_available),
              1);
  check_int64("node control relay availability valid",
              er_node_available_shape_valid(&relay_available),
              1);
  check_int64("node control relay availability requires endpoint",
              er_node_available_prepare(&relay_node,
                                        0,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        ER_NODE_CONTROL_DEFAULT_HEARTBEAT_SECS,
                                        &log_head,
                                        &signature,
                                        &relay_available),
              0);
  check_int64("node control worker availability",
              er_node_available_prepare(&worker_node,
                                        0,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        ER_NODE_CONTROL_DEFAULT_HEARTBEAT_SECS,
                                        &log_head,
                                        &signature,
                                        &worker_available),
              1);
  check_int64("node control worker availability valid",
              er_node_available_shape_valid(&worker_available),
              1);
  check_int64("node control worker rejects endpoint",
              er_node_available_prepare(&worker_node,
                                        &relay_endpoint,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        ER_NODE_CONTROL_DEFAULT_HEARTBEAT_SECS,
                                        &log_head,
                                        &signature,
                                        &worker_available),
              0);

  check_int64("node control relay assignment",
              er_relay_assignment_prepare(&worker_node.node_id,
                                          &relay_endpoint,
                                          &admission_node,
                                          NODE_CONTROL_TEST_SEQUENCE,
                                          NODE_CONTROL_TEST_VALID_UNTIL_MS,
                                          &signature,
                                          &assignment),
              1);
  check_int64("node control relay assignment valid",
              er_relay_assignment_shape_valid(&assignment),
              1);
  check_node_id_equal("node control assignment relay",
                      &assignment.relay.relay_node_id,
                      &relay_node.node_id);
  check_int64("node control assignment rejects relay authority",
              er_relay_assignment_prepare(&worker_node.node_id,
                                          &relay_endpoint,
                                          &relay_node,
                                          NODE_CONTROL_TEST_SEQUENCE,
                                          NODE_CONTROL_TEST_VALID_UNTIL_MS,
                                          &signature,
                                          &assignment),
              0);

  check_int64("node control heartbeat",
              er_node_heartbeat_prepare(&worker_node,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        &connection_hash,
                                        &log_head,
                                        &signature,
                                        &heartbeat),
              1);
  check_int64("node control heartbeat valid",
              er_node_heartbeat_shape_valid(&heartbeat),
              1);
  check_int64("node control heartbeat rejects zero connection",
              er_node_heartbeat_prepare(&worker_node,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        &zero_hash,
                                        &log_head,
                                        &signature,
                                        &heartbeat),
              0);
  check_int64("node control heartbeat restores",
              er_node_heartbeat_prepare(&worker_node,
                                        NODE_CONTROL_TEST_SEQUENCE,
                                        NODE_CONTROL_TEST_NOW_MS,
                                        &connection_hash,
                                        &log_head,
                                        &signature,
                                        &heartbeat),
              1);
  heartbeat.connection_hash.bytes[0] = 0u;
  heartbeat.connection_hash.bytes[1] = 0u;
  heartbeat.connection_hash.bytes[2] = 0u;
  check_int64("node control heartbeat still valid with nonzero tail",
              er_node_heartbeat_shape_valid(&heartbeat),
              1);
}
