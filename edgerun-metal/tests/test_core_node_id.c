static void test_node_id_sources(void) {
  ErCryptoProvider crypto;
  UINT8 tpm_key[ER_P256_PUBLIC_KEY_LEN];
  UINT8 mac[ER_NET_MAC_LEN];
  UINT8 hash_material[ER_HASH_LEN];
  ErNodeId tpm_node;
  ErNodeId tpm_node_again;
  ErNodeId mac_node;
  ErNodeId hash_node;
  ErNodeId memory_node;
  ErNodeIdSource memory_source;

  crypto.ctx = (void*)(UINTN)23u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  test_fill_bytes(tpm_key, ER_P256_PUBLIC_KEY_LEN, 0x11u);
  test_fill_bytes(mac, ER_NET_MAC_LEN, 0x21u);
  test_fill_bytes(hash_material, ER_HASH_LEN, 0x31u);

  check_int64("node id tpm derive",
              er_node_id_from_material(&crypto,
                                       ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY,
                                       tpm_key,
                                       ER_P256_PUBLIC_KEY_LEN,
                                       &tpm_node),
              1);
  check_int64("node id tpm deterministic",
              er_node_id_from_material(&crypto,
                                       ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY,
                                       tpm_key,
                                       ER_P256_PUBLIC_KEY_LEN,
                                       &tpm_node_again),
              1);
  check_node_id_equal("node id tpm repeat", &tpm_node, &tpm_node_again);
  check_int64("node id mac derive",
              er_node_id_from_material(&crypto,
                                       ER_NODE_ID_SOURCE_MAC,
                                       mac,
                                       ER_NET_MAC_LEN,
                                       &mac_node),
              1);
  check_int64("node id hash derive",
              er_node_id_from_material(&crypto,
                                       ER_NODE_ID_SOURCE_HASH,
                                       hash_material,
                                       ER_HASH_LEN,
                                       &hash_node),
              1);
  check_int64("node id memory source",
              er_node_id_source_prepare_memory_address(0x100000u, &memory_source), 1);
  check_int64("node id memory derive",
              er_node_id_from_source(&crypto, &memory_source, &memory_node), 1);
  check_node_id_not_equal("node id tpm differs from mac", &tpm_node, &mac_node);
  check_node_id_not_equal("node id hash differs from memory", &hash_node, &memory_node);
  check_int64("node id reject short mac",
              er_node_id_from_material(&crypto,
                                       ER_NODE_ID_SOURCE_MAC,
                                       mac,
                                       ER_NET_MAC_LEN - 1u,
                                       &mac_node),
              0);
  check_int64("node id reject zero address",
              er_node_id_source_prepare_memory_address(0u, &memory_source), 0);
  er_mem_zero(tpm_key, ER_P256_PUBLIC_KEY_LEN);
  check_int64("node id reject zero material",
              er_node_id_from_material(&crypto,
                                       ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY,
                                       tpm_key,
                                       ER_P256_PUBLIC_KEY_LEN,
                                       &tpm_node),
              0);
}
