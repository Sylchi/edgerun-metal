#include "test_core_internal.h"

enum {
  TEST_WORK_ROUTE_SIGNATURE_ALGORITHM = 2u
};

static ErIdentity g_test_work_route_signer;

static UINT8 test_work_route_sign(void* ctx, const ErByteSpan* preimage,
                                  ErWorkSignature* out_signature) {
  UINTN i;

  (void)ctx;
  if (er_identity_valid(&g_test_work_route_signer) == 0u ||
      preimage == 0 ||
      preimage->bytes == 0 ||
      preimage->len == 0u ||
      out_signature == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_signature, (UINTN)sizeof(*out_signature));
  out_signature->algorithm = TEST_WORK_ROUTE_SIGNATURE_ALGORITHM;
  out_signature->signature_len = ER_SIGNATURE_LEN;
  out_signature->identity = g_test_work_route_signer;
  for (i = 0u; i < ER_SIGNATURE_LEN; ++i) {
    out_signature->signature[i] =
        (UINT8)(preimage->bytes[i % preimage->len] + (UINT8)i + 7u);
  }
  return 1u;
}

static UINT8 test_work_route_verify(void* ctx, const ErIdentity* identity,
                                    const ErByteSpan* preimage,
                                    const ErWorkSignature* signature) {
  UINTN i;

  (void)ctx;
  if (er_identity_valid(identity) == 0u ||
      preimage == 0 ||
      preimage->bytes == 0 ||
      preimage->len == 0u ||
      signature == 0 ||
      signature->algorithm != TEST_WORK_ROUTE_SIGNATURE_ALGORITHM ||
      signature->signature_len != ER_SIGNATURE_LEN ||
      er_identity_equal(&signature->identity, identity) == 0u) {
    return 0u;
  }
  for (i = 0u; i < ER_SIGNATURE_LEN; ++i) {
    UINT8 expected =
        (UINT8)(preimage->bytes[i % preimage->len] + (UINT8)i + 7u);
    if (signature->signature[i] != expected) {
      return 0u;
    }
  }
  return 1u;
}

static void test_device_relay_identity(void) {
  ErCryptoProvider crypto;
  UINT8 hardware_key[ER_P256_PUBLIC_KEY_LEN];
  UINT8 ephemeral_key[ER_PUBLIC_KEY_LEN];
  UINT8 hash_material[ER_HASH_LEN];
  ErIdentity hardware_identity;
  ErIdentity ephemeral_identity;
  ErIdentity hash_identity;
  ErHash program_hash;
  ErHash other_program_hash;
  ErDeviceIdentity hardware_device;
  ErDeviceIdentity ephemeral_device;
  ErDeviceRelayIdentity hardware_relay;
  ErDeviceRelayIdentity hardware_relay_again;
  ErDeviceRelayIdentity ephemeral_relay;
  ErDeviceRelayIdentity other_program_relay;

  crypto.ctx = (void*)(UINTN)7u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  test_fill_bytes(hardware_key, ER_P256_PUBLIC_KEY_LEN, 0x21u);
  test_fill_bytes(ephemeral_key, ER_PUBLIC_KEY_LEN, 0x41u);
  test_fill_bytes(hash_material, ER_HASH_LEN, 0x51u);
  test_fill_bytes(program_hash.bytes, ER_HASH_LEN, 0x61u);
  test_fill_bytes(other_program_hash.bytes, ER_HASH_LEN, 0x62u);

  check_int64("identity prepare tpm p256",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_TPM_P256,
                                  hardware_key, ER_P256_PUBLIC_KEY_LEN,
                                  &hardware_identity),
              1);
  check_int64("identity prepare ed25519",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  ephemeral_key, ER_PUBLIC_KEY_LEN,
                                  &ephemeral_identity),
              1);
  check_int64("identity prepare hash",
              er_identity_prepare(ER_IDENTITY_TYPE_HASH,
                                  ER_IDENTITY_BACKING_HASH,
                                  hash_material, ER_HASH_LEN,
                                  &hash_identity),
              1);
  check_int64("identity reject p256 short",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_TPM_P256,
                                  hardware_key, ER_PUBLIC_KEY_LEN,
                                  &hardware_identity),
              0);
  check_int64("identity reject hash as ed25519",
              er_identity_prepare(ER_IDENTITY_TYPE_HASH,
                                  ER_IDENTITY_BACKING_ED25519,
                                  hash_material, ER_HASH_LEN,
                                  &hash_identity),
              0);

  check_int64("device identity hardware prepare",
              er_device_identity_prepare(ER_DEVICE_IDENTITY_KIND_HARDWARE,
                                         &hardware_identity, &hardware_device),
              1);
  check_int64("device identity ephemeral prepare",
              er_device_identity_prepare(ER_DEVICE_IDENTITY_KIND_EPHEMERAL,
                                         &ephemeral_identity, &ephemeral_device),
              1);
  check_int64("device identity reject kind",
              er_device_identity_prepare(99u, &hardware_identity, &hardware_device), 0);
  er_mem_zero(hardware_identity.material, ER_IDENTITY_MATERIAL_MAX);
  check_int64("device identity reject zero key",
              er_device_identity_prepare(ER_DEVICE_IDENTITY_KIND_HARDWARE,
                                         &hardware_identity, &hardware_device),
              0);
  test_fill_bytes(hardware_key, ER_P256_PUBLIC_KEY_LEN, 0x21u);
  (void)er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                            ER_IDENTITY_BACKING_TPM_P256,
                            hardware_key, ER_P256_PUBLIC_KEY_LEN,
                            &hardware_identity);
  check_int64("device identity hardware restore",
              er_device_identity_prepare(ER_DEVICE_IDENTITY_KIND_HARDWARE,
                                         &hardware_identity, &hardware_device),
              1);

  check_int64("device relay hardware derive",
              er_device_relay_identity_derive(&crypto, &hardware_device,
                                              &program_hash, &hardware_relay),
              1);
  check_int64("device relay abi", hardware_relay.abi_version, ER_WORK_ABI_VERSION);
  check_int64("device relay trust kind", hardware_relay.trust_kind,
              ER_DEVICE_IDENTITY_KIND_HARDWARE);
  check_int64("device relay role", hardware_relay.relay_node.role, ER_NODE_ROLE_RELAY);
  check_int64("device relay identity backing",
              hardware_relay.relay_node.identity.backing_type,
              ER_IDENTITY_BACKING_TPM_P256);
  check_uint64("device relay identity byte0",
               hardware_relay.relay_node.identity.material[0], 0x21u);
  check_int64("device relay deterministic derive",
              er_device_relay_identity_derive(&crypto, &hardware_device,
                                              &program_hash, &hardware_relay_again),
              1);
  check_node_id_equal("device relay deterministic node",
                      &hardware_relay_again.relay_node.node_id,
                      &hardware_relay.relay_node.node_id);

  check_int64("device relay ephemeral derive",
              er_device_relay_identity_derive(&crypto, &ephemeral_device,
                                              &program_hash, &ephemeral_relay),
              1);
  check_node_id_not_equal("device relay hardware differs from ephemeral",
                          &hardware_relay.relay_node.node_id,
                          &ephemeral_relay.relay_node.node_id);
  check_int64("device relay other program derive",
              er_device_relay_identity_derive(&crypto, &hardware_device,
                                              &other_program_hash, &other_program_relay),
              1);
  check_node_id_not_equal("device relay program hash changes node",
                          &hardware_relay.relay_node.node_id,
                          &other_program_relay.relay_node.node_id);

  er_mem_zero(program_hash.bytes, ER_HASH_LEN);
  check_int64("device relay reject zero program hash",
              er_device_relay_identity_derive(&crypto, &hardware_device,
                                              &program_hash, &hardware_relay),
              0);
}

static void test_ephemeral_node_identity(void) {
  enum {
    EPHEMERAL_TEST_WIFI_CHANNEL = 6u
  };
  ErCryptoProvider crypto;
  ErHash admission_id;
  ErHash other_admission_id;
  UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN];
  UINT8 other_boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN];
  ErEphemeralNode node;
  ErEphemeralNode node_again;
  ErEphemeralNode other_nonce_node;
  ErEphemeralNode other_admission_node;
  ErEphemeralNodeWifiL2 wifi_l2;

  crypto.ctx = (void*)(UINTN)17u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  test_fill_bytes(admission_id.bytes, ER_HASH_LEN, 0x20u);
  test_fill_bytes(other_admission_id.bytes, ER_HASH_LEN, 0x21u);
  test_fill_bytes(boot_nonce, ER_EPHEMERAL_NODE_BOOT_NONCE_LEN, 0x30u);
  test_fill_bytes(other_boot_nonce,
                  ER_EPHEMERAL_NODE_BOOT_NONCE_LEN,
                  0x31u);

  check_int64("ephemeral node derive",
              er_ephemeral_node_derive(&crypto,
                                       &admission_id,
                                       boot_nonce,
                                       &node),
              1);
  check_uint64("ephemeral node abi",
               node.abi_version,
               ER_EPHEMERAL_NODE_ABI_VERSION);
  check_hash_equal("ephemeral node admission",
                   &node.admission_id,
                   &admission_id);
  check_uint64("ephemeral node nonce byte",
               node.boot_nonce[0],
               boot_nonce[0]);
  check_int64("ephemeral node id nonzero",
              er_node_id_nonzero(&node.node_id),
              1);
  check_int64("ephemeral node derive repeat",
              er_ephemeral_node_derive(&crypto,
                                       &admission_id,
                                       boot_nonce,
                                       &node_again),
              1);
  check_node_id_equal("ephemeral node deterministic",
                      &node_again.node_id,
                      &node.node_id);
  check_int64("ephemeral node derive other nonce",
              er_ephemeral_node_derive(&crypto,
                                       &admission_id,
                                       other_boot_nonce,
                                       &other_nonce_node),
              1);
  check_node_id_not_equal("ephemeral node nonce changes id",
                          &other_nonce_node.node_id,
                          &node.node_id);
  check_int64("ephemeral node derive other admission",
              er_ephemeral_node_derive(&crypto,
                                       &other_admission_id,
                                       boot_nonce,
                                       &other_admission_node),
              1);
  check_node_id_not_equal("ephemeral node admission changes id",
                          &other_admission_node.node_id,
                          &node.node_id);

  er_mem_zero(admission_id.bytes, ER_HASH_LEN);
  check_int64("ephemeral node reject zero admission",
              er_ephemeral_node_derive(&crypto,
                                       &admission_id,
                                       boot_nonce,
                                       &node),
              0);
  test_fill_bytes(admission_id.bytes, ER_HASH_LEN, 0x20u);
  er_mem_zero(boot_nonce, ER_EPHEMERAL_NODE_BOOT_NONCE_LEN);
  check_int64("ephemeral node reject zero nonce",
              er_ephemeral_node_derive(&crypto,
                                       &admission_id,
                                       boot_nonce,
                                       &node),
              0);
  test_fill_bytes(boot_nonce, ER_EPHEMERAL_NODE_BOOT_NONCE_LEN, 0x30u);

  check_int64("ephemeral node wifi l2 prepare",
              er_ephemeral_node_wifi_l2_prepare(&crypto,
                                                &admission_id,
                                                boot_nonce,
                                                EPHEMERAL_TEST_WIFI_CHANNEL,
                                                &wifi_l2),
              1);
  check_node_id_equal("ephemeral node wifi node id",
                      &wifi_l2.node.node_id,
                      &node_again.node_id);
  check_int64("ephemeral node wifi ap valid",
              er_wifi_l2_ap_plan_valid(&wifi_l2.ap_plan),
              1);
  check_uint64("ephemeral node wifi eth type",
               wifi_l2.ap_plan.eth_type,
               ER_NET_ETH_TYPE_EDGERUN);
}

static void test_work_admitted_relay_route(void) {
  ErCryptoProvider crypto;
  ErWorkRequest request;
  ErWorkAdmission admission;
  ErChannelEnvelopeHeader envelope;
  ErChannelEndpoint from_endpoint;
  ErChannelEndpoint to_endpoint;
  ErNodeId source_node_id;
  ErNodeId target_node_id;
  ErNodeId relay_node_id;
  ErNodeId second_relay_node_id;
  ErNodeId wrong_relay_node_id;
  ErHash channel_id;
  ErHash input_hash;
  ErHash previous_transit_hash;
  UINT8 user_material[ER_PUBLIC_KEY_LEN];
  UINT8 admission_material[ER_PUBLIC_KEY_LEN];
  ErAdmittedRoute route;
  ErAdmittedRoute route_again;
  ErWorkRouteChallenge route_challenge;
  ErWorkRouteChallenge route_challenge_again;
  ErWorkRouteChallenge changed_route_challenge;
  ErWorkRouteStartProof route_start_proof;
  ErWorkRouteStartProof tampered_route_start_proof;
  ErEpochStamp route_challenge_issued_at;
  ErEpochStamp route_challenge_valid_until;
  ErEpochStamp route_challenge_now;
  ErEpochStamp route_challenge_before;
  ErEpochStamp route_challenge_expired;
  ErRelayForwardIntent intent;
  ErRelayTransitHop hop;
  ErRelayTransitHop hop_again;
  ErRelayTransitHop hop_changed;
  ErRelayAccountingClaim claim;
  ErCapabilityEnvelopeHeader capability_header;
  ErCapabilityEnvelopeHeader bad_capability_header;
  ErRenderEndpointCapture render_capture;
  ErRenderEndpointCapture render_capture_again;
  ErRenderEndpointCapture bad_render_capture;
  ErRenderEndpointScene render_scene;
  ErRenderEndpointScene render_scene_again;
  ErAdmittedRoute bad_render_route;
  ErHash session_id;
  ErHash invocation_id;
  ErHash capability_id;
  ErHash scene_payload_hash;
  UINT8 scene_payload[ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                      ER_WASM_UI_RECT_RECORD_LEN +
                      ER_WASM_UI_HIT_RECORD_LEN +
                      ER_WASM_UI_QUAD_RECORD_LEN];
  er_ui_scene_t endpoint_scene;

  crypto.ctx = (void*)(UINTN)11u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = test_work_route_sign;
  crypto.verify = test_work_route_verify;
  test_write_wasm_ui_scene_packet(scene_payload, (UINT32)sizeof(scene_payload));
  check_int64("render scene payload hash",
              er_render_endpoint_scene_payload_hash(&crypto, scene_payload,
                                                    (UINT32)sizeof(scene_payload),
                                                    &scene_payload_hash),
              1);

  er_mem_zero((UINT8*)&request, (UINTN)sizeof(request));
  er_mem_zero((UINT8*)&admission, (UINTN)sizeof(admission));
  er_mem_zero((UINT8*)&envelope, (UINTN)sizeof(envelope));
  er_mem_zero((UINT8*)&from_endpoint, (UINTN)sizeof(from_endpoint));
  er_mem_zero((UINT8*)&to_endpoint, (UINTN)sizeof(to_endpoint));
  test_fill_bytes(source_node_id.bytes, ER_NODE_ID_LEN, 0x11u);
  test_fill_bytes(target_node_id.bytes, ER_NODE_ID_LEN, 0x22u);
  test_fill_bytes(relay_node_id.bytes, ER_NODE_ID_LEN, 0x33u);
  test_fill_bytes(second_relay_node_id.bytes, ER_NODE_ID_LEN, 0x44u);
  test_fill_bytes(wrong_relay_node_id.bytes, ER_NODE_ID_LEN, 0x55u);
  test_fill_bytes(channel_id.bytes, ER_HASH_LEN, 0x66u);
  test_fill_bytes(input_hash.bytes, ER_HASH_LEN, 0x77u);
  test_fill_bytes(previous_transit_hash.bytes, ER_HASH_LEN, 0x88u);
  test_fill_bytes(session_id.bytes, ER_HASH_LEN, 0xc1u);
  test_fill_bytes(invocation_id.bytes, ER_HASH_LEN, 0xd1u);
  test_fill_bytes(capability_id.bytes, ER_HASH_LEN, 0xe1u);
  test_fill_bytes(user_material, ER_PUBLIC_KEY_LEN, 0x92u);
  test_fill_bytes(admission_material, ER_PUBLIC_KEY_LEN, 0xa2u);

  request.abi_version = ER_WORK_ABI_VERSION;
  request.work_type = ER_WORK_TYPE_CAPABILITY_INVOKE;
  request.department = ER_DEPARTMENT_CAPABILITY;
  test_fill_bytes(request.request_id.bytes, ER_HASH_LEN, 0x91u);
  check_int64("work request user identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  user_material, ER_PUBLIC_KEY_LEN,
                                  &request.user),
              1);
  request.user_sequence = 3u;
  request.recipient = target_node_id;
  test_fill_bytes(request.payload_hash.bytes, ER_HASH_LEN, 0x93u);
  test_fill_bytes(request.input_root.bytes, ER_HASH_LEN, 0x94u);
  request.max_total_cost = 20u;
  request.valid_until_ms = 100000u;
  g_test_work_route_signer = request.user;

  admission.abi_version = ER_WORK_ABI_VERSION;
  admission.relay_count = 2u;
  test_fill_bytes(admission.admission_id.bytes, ER_HASH_LEN, 0xa1u);
  admission.user = request.user;
  admission.admission_node.abi_version = ER_WORK_ABI_VERSION;
  admission.admission_node.role = ER_NODE_ROLE_ADMISSION;
  test_fill_bytes(admission.admission_node.node_id.bytes, ER_NODE_ID_LEN, 0xa2u);
  check_int64("work admission node identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_material, ER_PUBLIC_KEY_LEN,
                                  &admission.admission_node.identity),
              1);
  test_fill_bytes(admission.request_hash.bytes, ER_HASH_LEN, 0xa3u);
  test_fill_bytes(admission.route_commitment.bytes, ER_HASH_LEN, 0xa4u);
  admission.channel.abi_version = ER_WORK_ABI_VERSION;
  admission.channel.kind = ER_CHANNEL_KIND_MEMORY;
  admission.channel.channel_id = channel_id;
  admission.relay_path[0] = relay_node_id;
  admission.relay_path[1] = second_relay_node_id;
  admission.admitted_budget = 20u;
  test_fill_bytes(admission.policy_hash.bytes, ER_HASH_LEN, 0xa5u);
  admission.sequence = 5u;
  admission.valid_until_ms = 90000u;

  from_endpoint.abi_version = ER_WORK_ABI_VERSION;
  from_endpoint.kind = ER_CHANNEL_KIND_MEMORY;
  from_endpoint.channel_id = channel_id;
  to_endpoint.abi_version = ER_WORK_ABI_VERSION;
  to_endpoint.kind = ER_CHANNEL_KIND_MEMORY;
  to_endpoint.channel_id = channel_id;

  envelope.abi_version = ER_WORK_ABI_VERSION;
  envelope.packet_kind = ER_WORK_TYPE_CAPABILITY_INVOKE;
  envelope.channel_id = channel_id;
  envelope.from = source_node_id;
  envelope.to = target_node_id;
  envelope.route_hash = admission.route_commitment;
  envelope.packet_hash = scene_payload_hash;
  envelope.sequence = 1u;
  test_fill_bytes(envelope.previous_message_hash.bytes, ER_HASH_LEN, 0xb2u);

  check_int64("work route admitted",
              er_work_admitted_route_from_admission(&crypto, &request, &admission,
                                                    &source_node_id, &relay_node_id,
                                                    ER_NODE_ROLE_CAPABILITY, &route),
              1);
  check_int64("work route abi", route.abi_version, ER_WORK_ABI_VERSION);
  check_node_id_equal("work route source", &route.source_node_id, &source_node_id);
  check_node_id_equal("work route target", &route.target_node_id, &target_node_id);
  check_node_id_equal("work route relay", &route.relay_node_id, &relay_node_id);
  check_hash_equal("work route channel", &route.channel_id, &channel_id);
  check_hash_equal("work route commitment", &route.target_route_commitment,
                   &admission.route_commitment);
  check_uint64("work route budget", route.admitted_budget, admission.admitted_budget);
  check_int64("work route deterministic",
              er_work_admitted_route_from_admission(&crypto, &request, &admission,
                                                    &source_node_id, &relay_node_id,
                                                    ER_NODE_ROLE_CAPABILITY, &route_again),
              1);
  check_hash_equal("work route deterministic id", &route_again.route_id, &route.route_id);

  route_challenge_issued_at.era = 1u;
  route_challenge_issued_at.epoch = 2u;
  route_challenge_issued_at.slot = 3u;
  route_challenge_issued_at.tick = 4u;
  route_challenge_valid_until.era = 1u;
  route_challenge_valid_until.epoch = 2u;
  route_challenge_valid_until.slot = 4u;
  route_challenge_valid_until.tick = 0u;
  route_challenge_now.era = 1u;
  route_challenge_now.epoch = 2u;
  route_challenge_now.slot = 3u;
  route_challenge_now.tick = 8u;
  route_challenge_before.era = 1u;
  route_challenge_before.epoch = 2u;
  route_challenge_before.slot = 3u;
  route_challenge_before.tick = 3u;
  route_challenge_expired = route_challenge_valid_until;

  check_int64("work route challenge prepare",
              er_work_route_challenge_prepare(&crypto,
                                              &route,
                                              route_challenge_issued_at,
                                              route_challenge_valid_until,
                                              &route_challenge),
              1);
  check_hash_equal("work route challenge route",
                   &route_challenge.route_id,
                   &route.route_id);
  check_hash_equal("work route challenge admission",
                   &route_challenge.admission_hash,
                   &route.admission_hash);
  check_node_id_equal("work route challenge worker",
                      &route_challenge.worker_node_id,
                      &source_node_id);
  check_node_id_equal("work route challenge relay",
                      &route_challenge.relay_node_id,
                      &relay_node_id);
  check_int64("work route challenge valid",
              er_work_route_challenge_valid_at(&route_challenge,
                                               route_challenge_now),
              1);
  check_int64("work route challenge rejects early",
              er_work_route_challenge_valid_at(&route_challenge,
                                               route_challenge_before),
              0);
  check_int64("work route challenge rejects expired",
              er_work_route_challenge_valid_at(&route_challenge,
                                               route_challenge_expired),
              0);
  check_int64("work route challenge deterministic",
              er_work_route_challenge_prepare(&crypto,
                                              &route,
                                              route_challenge_issued_at,
                                              route_challenge_valid_until,
                                              &route_challenge_again),
              1);
  check_hash_equal("work route challenge deterministic id",
                   &route_challenge_again.challenge_id,
                   &route_challenge.challenge_id);
  route_again.relay_node_id = second_relay_node_id;
  route_again.relay_path[0] = second_relay_node_id;
  check_int64("work route challenge changes with relay",
              er_work_route_challenge_prepare(&crypto,
                                              &route_again,
                                              route_challenge_issued_at,
                                              route_challenge_valid_until,
                                              &changed_route_challenge),
              1);
  check_hash_not_equal("work route challenge relay differs",
                       &changed_route_challenge.challenge_id,
                       &route_challenge.challenge_id);
  check_int64("work route start proof sign",
              er_work_route_start_proof_sign(&crypto,
                                             &route_challenge,
                                             &request.user,
                                             route_challenge_now,
                                             &route_start_proof),
              1);
  check_hash_equal("work route start proof challenge",
                   &route_start_proof.challenge_id,
                   &route_challenge.challenge_id);
  check_node_id_equal("work route start proof worker",
                      &route_start_proof.worker_node_id,
                      &source_node_id);
  check_int64("work route start proof verify",
              er_work_route_start_proof_verify(&crypto,
                                               &route_challenge,
                                               &route_start_proof,
                                               route_challenge_now),
              1);
  tampered_route_start_proof = route_start_proof;
  tampered_route_start_proof.relay_node_id.bytes[0] ^= 1u;
  check_int64("work route start proof rejects relay tamper",
              er_work_route_start_proof_verify(&crypto,
                                               &route_challenge,
                                               &tampered_route_start_proof,
                                               route_challenge_now),
              0);
  tampered_route_start_proof = route_start_proof;
  tampered_route_start_proof.signature.signature[0] ^= 1u;
  check_int64("work route start proof rejects signature tamper",
              er_work_route_start_proof_verify(&crypto,
                                               &route_challenge,
                                               &tampered_route_start_proof,
                                               route_challenge_now),
              0);
  check_int64("work route start proof rejects stale clock",
              er_work_route_start_proof_verify(&crypto,
                                               &route_challenge,
                                               &route_start_proof,
                                               route_challenge_expired),
              0);

  check_int64("work envelope for route",
              er_work_verify_channel_envelope_for_route(&envelope, &route), 1);
  envelope.route_hash.bytes[0] ^= 1u;
  check_int64("work envelope reject route",
              er_work_verify_channel_envelope_for_route(&envelope, &route), 0);
  envelope.route_hash = admission.route_commitment;
  envelope.packet_hash.bytes[0] = 0u;
  er_mem_zero(envelope.packet_hash.bytes, ER_HASH_LEN);
  check_int64("work envelope reject packet hash",
              er_work_verify_channel_envelope_for_route(&envelope, &route), 0);
  envelope.packet_hash = scene_payload_hash;
  envelope.packet_kind = ER_WORK_TYPE_CAPABILITY_CLOSE;
  check_int64("work envelope reject packet kind",
              er_work_verify_channel_envelope_for_route(&envelope, &route), 0);
  envelope.packet_kind = ER_WORK_TYPE_CAPABILITY_INVOKE;

  check_int64("work forward intent",
              er_work_prepare_relay_forward_intent(&admission, &envelope,
                                                   &relay_node_id, &from_endpoint,
                                                   &to_endpoint, &intent),
              1);
  check_node_id_equal("work intent relay", &intent.relay_node_id, &relay_node_id);
  check_node_id_equal("work intent source", &intent.source_node_id, &source_node_id);
  check_node_id_equal("work intent target", &intent.target_node_id, &target_node_id);
  check_hash_equal("work intent packet", &intent.packet_hash, &envelope.packet_hash);
  check_int64("work forward reject wrong relay",
              er_work_prepare_relay_forward_intent(&admission, &envelope,
                                                   &wrong_relay_node_id, &from_endpoint,
                                                   &to_endpoint, &intent),
              0);

  check_int64("work ordered input hash",
              er_work_ordered_message_input_hash(&crypto, &envelope, &input_hash), 1);
  check_int64("work transit hop",
              er_work_prepare_relay_transit_hop(&crypto, &intent, &input_hash,
                                                &previous_transit_hash, 0u, &hop),
              1);
  check_node_id_equal("work transit from", &hop.from, &source_node_id);
  check_node_id_equal("work transit to", &hop.to, &target_node_id);
  check_hash_equal("work transit input", &hop.input_hash, &input_hash);
  check_int64("work transit deterministic",
              er_work_prepare_relay_transit_hop(&crypto, &intent, &input_hash,
                                                &previous_transit_hash, 0u, &hop_again),
              1);
  check_hash_equal("work transit deterministic hash", &hop_again.transit_hash,
                   &hop.transit_hash);
  previous_transit_hash.bytes[0] ^= 9u;
  check_int64("work transit changes with chain",
              er_work_prepare_relay_transit_hop(&crypto, &intent, &input_hash,
                                                &previous_transit_hash, 0u, &hop_changed),
              1);
  check_hash_not_equal("work transit chain differs", &hop_changed.transit_hash,
                       &hop.transit_hash);

  check_int64("work relay accounting claim",
              er_work_prepare_relay_accounting_claim(&hop, &route.request_hash,
                                                     &route.admission_hash,
                                                     1500u, 2u, 1u, &claim),
              1);
  check_uint64("work relay accounting units", claim.units_used, 2u);
  check_uint64("work relay accounting total", claim.total_claim, 5u);
  check_hash_equal("work relay accounting transit", &claim.transit_hash,
                   &hop.transit_hash);
  check_int64("work relay accounting reject zero bytes",
              er_work_prepare_relay_accounting_claim(&hop, &route.request_hash,
                                                     &route.admission_hash,
                                                     0u, 2u, 1u, &claim),
              0);

  check_int64("work render capability envelope",
              er_work_prepare_capability_envelope_header(ER_CAPABILITY_PACKET_INVOKE,
                                                         ER_WORK_TYPE_CAPABILITY_INVOKE,
                                                         ER_CAPABILITY_CONTENT_RENDER,
                                                         ER_CAPABILITY_RISK_NONE,
                                                         &session_id,
                                                         &invocation_id,
                                                         &capability_id,
                                                         &source_node_id,
                                                         &target_node_id,
                                                         envelope.sequence,
                                                         120000u,
                                                         &envelope.packet_hash,
                                                         (UINT32)sizeof(scene_payload),
                                                         &capability_header),
              1);
  check_int64("work render capability valid",
              er_work_capability_envelope_header_valid(&capability_header), 1);
  check_uint64("work render capability content",
               capability_header.content_type, ER_CAPABILITY_CONTENT_RENDER);
  bad_capability_header = capability_header;
  bad_capability_header.content_type = 99u;
  check_int64("work capability reject content",
              er_work_capability_envelope_header_valid(&bad_capability_header), 0);
  bad_capability_header = capability_header;
  bad_capability_header.risk_flags = ER_CAPABILITY_RISK_HOST_PRIVILEGE << 1u;
  check_int64("work capability reject unknown risk",
              er_work_capability_envelope_header_valid(&bad_capability_header), 0);
  bad_capability_header = capability_header;
  er_mem_zero(bad_capability_header.payload_hash.bytes, ER_HASH_LEN);
  check_int64("work capability reject zero payload hash",
              er_work_capability_envelope_header_valid(&bad_capability_header), 0);

  check_int64("render endpoint capture",
              er_render_endpoint_capture(&crypto, &route, &envelope,
                                         &capability_header, &render_capture),
              1);
  check_int64("render capture abi", render_capture.abi_version,
              ER_RENDER_ENDPOINT_ABI_VERSION);
  check_hash_equal("render capture route", &render_capture.route_id,
                   &route.route_id);
  check_hash_equal("render capture capability",
                   &render_capture.capability_id, &capability_id);
  check_hash_equal("render capture scene hash", &render_capture.scene_hash,
                   &scene_payload_hash);
  check_node_id_equal("render capture source", &render_capture.source_node_id,
                      &source_node_id);
  check_node_id_equal("render capture target", &render_capture.target_node_id,
                      &target_node_id);
  check_uint64("render capture sequence", render_capture.sequence,
               envelope.sequence);
  check_uint64("render capture scene bytes", render_capture.scene_bytes,
               (UINT64)sizeof(scene_payload));
  check_int64("render endpoint deterministic",
              er_render_endpoint_capture(&crypto, &route, &envelope,
                                         &capability_header,
                                         &render_capture_again),
              1);
  check_hash_equal("render capture deterministic id",
                   &render_capture_again.capture_id,
                   &render_capture.capture_id);
  bad_capability_header = capability_header;
  bad_capability_header.content_type = ER_CAPABILITY_CONTENT_OBJECT;
  check_int64("render endpoint reject object content",
              er_render_endpoint_capture(&crypto, &route, &envelope,
                                         &bad_capability_header,
                                         &render_capture_again),
              0);
  bad_capability_header = capability_header;
  bad_capability_header.target_node_id = wrong_relay_node_id;
  check_int64("render endpoint reject target mismatch",
              er_render_endpoint_capture(&crypto, &route, &envelope,
                                         &bad_capability_header,
                                         &render_capture_again),
              0);
  bad_capability_header = capability_header;
  ++bad_capability_header.sequence;
  check_int64("render endpoint reject sequence mismatch",
              er_render_endpoint_capture(&crypto, &route, &envelope,
                                         &bad_capability_header,
                                         &render_capture_again),
              0);
  bad_render_route = route;
  bad_render_route.department = ER_DEPARTMENT_STORAGE;
  check_int64("render endpoint reject department",
              er_render_endpoint_capture(&crypto, &bad_render_route, &envelope,
                                         &capability_header,
                                         &render_capture_again),
              0);

  check_int64("render endpoint scene init",
              er_ui_scene_init_with_allocator(&endpoint_scene,
                                              er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("render endpoint decode scene payload",
              er_render_endpoint_decode_scene_payload(&crypto, &render_capture,
                                                      scene_payload,
                                                      (UINT32)sizeof(scene_payload),
                                                      &endpoint_scene,
                                                      &render_scene),
              1);
  check_int64("render endpoint scene abi", render_scene.abi_version,
              ER_RENDER_ENDPOINT_ABI_VERSION);
  check_hash_equal("render endpoint scene capture", &render_scene.capture_id,
                   &render_capture.capture_id);
  check_hash_equal("render endpoint scene hash", &render_scene.scene_hash,
                   &scene_payload_hash);
  check_uint64("render endpoint scene rects", render_scene.scene_stats.rects,
               1u);
  check_uint64("render endpoint scene hits", render_scene.scene_stats.hits,
               1u);
  check_uint64("render endpoint scene text", render_scene.scene_stats.text_quads,
               1u);
  check_uint64("render endpoint decoded rect count", endpoint_scene.rect_count,
               1u);
  check_uint64("render endpoint decoded hit count", endpoint_scene.hit_count,
               1u);
  check_int64("render endpoint decode deterministic",
              er_render_endpoint_decode_scene_payload(&crypto, &render_capture,
                                                      scene_payload,
                                                      (UINT32)sizeof(scene_payload),
                                                      &endpoint_scene,
                                                      &render_scene_again),
              1);
  check_hash_equal("render endpoint scene deterministic id",
                   &render_scene_again.scene_id, &render_scene.scene_id);
  scene_payload[0] ^= 1u;
  check_int64("render endpoint reject tampered scene payload",
              er_render_endpoint_decode_scene_payload(&crypto, &render_capture,
                                                      scene_payload,
                                                      (UINT32)sizeof(scene_payload),
                                                      &endpoint_scene,
                                                      &render_scene_again),
              0);
  scene_payload[0] ^= 1u;
  bad_render_capture = render_capture;
  ++bad_render_capture.scene_bytes;
  check_int64("render endpoint reject scene byte mismatch",
              er_render_endpoint_decode_scene_payload(&crypto, &bad_render_capture,
                                                      scene_payload,
                                                      (UINT32)sizeof(scene_payload),
                                                      &endpoint_scene,
                                                      &render_scene_again),
              0);

  er_ui_scene_destroy(&endpoint_scene);
}
