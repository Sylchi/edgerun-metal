static void test_jurisdiction_policy_and_node_instances(void) {
  ErCryptoProvider crypto;
  UINT8 owner_key[ER_PUBLIC_KEY_LEN];
  UINT8 admission_key[ER_PUBLIC_KEY_LEN];
  ErIdentity owner_identity;
  ErNodeIdentity admission_node;
  ErHash policy_hash;
  ErHash route_scope_hash;
  ErAdmissionPolicyRecord policy;
  ErAdmissionPolicyRecord changed_policy;
  ErNodeInstanceRecord instance;
  ErNodeInstanceRecord changed_instance;
  ErNodeId storage_node_id;

  crypto.ctx = (void*)7u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  test_fill_bytes(owner_key, ER_PUBLIC_KEY_LEN, 0x10u);
  test_fill_bytes(admission_key, ER_PUBLIC_KEY_LEN, 0x40u);
  test_fill_bytes(policy_hash.bytes, ER_HASH_LEN, 0x70u);
  test_fill_bytes(route_scope_hash.bytes, ER_HASH_LEN, 0x90u);
  test_fill_bytes(storage_node_id.bytes, ER_NODE_ID_LEN, 0xb0u);

  check_int64("jurisdiction owner identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  owner_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &owner_identity),
              1);
  er_mem_zero((UINT8*)&admission_node, (UINTN)sizeof(admission_node));
  admission_node.abi_version = ER_WORK_ABI_VERSION;
  admission_node.role = ER_NODE_ROLE_ADMISSION;
  check_int64("jurisdiction admission identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  admission_key,
                                  ER_PUBLIC_KEY_LEN,
                                  &admission_node.identity),
              1);
  er_mem_copy(admission_node.node_id.bytes, admission_key, ER_NODE_ID_LEN);

  check_int64("jurisdiction admission node valid",
              er_jurisdiction_node_identity_authority_valid(&admission_node),
              1);
  admission_node.node_id.bytes[0] ^= 1u;
  check_int64("jurisdiction admission node rejects mismatched key",
              er_jurisdiction_node_identity_authority_valid(&admission_node),
              0);
  admission_node.node_id.bytes[0] ^= 1u;

  check_int64("jurisdiction policy prepare",
              er_admission_policy_prepare(&crypto,
                                          ER_ADMISSION_POLICY_SOURCE_USER,
                                          &owner_identity,
                                          &admission_node,
                                          &policy_hash,
                                          1000u,
                                          10u,
                                          10000u,
                                          &policy),
              1);
  check_int64("jurisdiction policy valid",
              er_admission_policy_valid(&crypto, &policy),
              1);
  check_int64("jurisdiction policy rejects source",
              er_admission_policy_prepare(&crypto,
                                          99u,
                                          &owner_identity,
                                          &admission_node,
                                          &policy_hash,
                                          1000u,
                                          10u,
                                          10000u,
                                          &changed_policy),
              0);
  changed_policy = policy;
  changed_policy.policy_hash.bytes[0] ^= 1u;
  check_int64("jurisdiction policy rejects tamper",
              er_admission_policy_valid(&crypto, &changed_policy),
              0);
  check_int64("jurisdiction policy id changes with budget",
              er_admission_policy_prepare(&crypto,
                                          ER_ADMISSION_POLICY_SOURCE_USER,
                                          &owner_identity,
                                          &admission_node,
                                          &policy_hash,
                                          1001u,
                                          10u,
                                          10000u,
                                          &changed_policy),
              1);
  check_hash_not_equal("jurisdiction policy budget id",
                       &policy.policy_id,
                       &changed_policy.policy_id);

  check_int64("jurisdiction node instance prepare",
              er_node_instance_prepare(&crypto,
                                       &owner_identity,
                                       &storage_node_id,
                                       ER_NODE_ROLE_STORAGE,
                                       ER_RUNTIME_TARGET_FIRMWARE,
                                       &policy.policy_hash,
                                       512u,
                                       &route_scope_hash,
                                       10u,
                                       10000u,
                                       ER_NODE_INSTANCE_STATUS_RUNNING,
                                       &instance),
              1);
  check_int64("jurisdiction node instance valid",
              er_node_instance_valid(&crypto, &instance),
              1);
  changed_instance = instance;
  changed_instance.status = ER_NODE_INSTANCE_STATUS_REVOKED;
  check_int64("jurisdiction node instance rejects tamper",
              er_node_instance_valid(&crypto, &changed_instance),
              0);
  check_int64("jurisdiction node instance rejects zero budget",
              er_node_instance_prepare(&crypto,
                                       &owner_identity,
                                       &storage_node_id,
                                       ER_NODE_ROLE_STORAGE,
                                       ER_RUNTIME_TARGET_FIRMWARE,
                                       &policy.policy_hash,
                                       0u,
                                       &route_scope_hash,
                                       10u,
                                       10000u,
                                       ER_NODE_INSTANCE_STATUS_RUNNING,
                                       &changed_instance),
              0);
}
