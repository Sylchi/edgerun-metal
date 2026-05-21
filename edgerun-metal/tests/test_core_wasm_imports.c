#include "test_core_internal.h"

static void test_wasm_log_imports(void) {
  /*
   * Purpose: keep diagnostic log hostcalls covered even though they are not user-admitted.
   * Intention: prove void-result imports do not corrupt the i64 return path.
   */
  static const UINT8 wasm_log_import_test[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x09, 0x02, 0x60,
    0x01, 0x7e, 0x00, 0x60, 0x00, 0x01, 0x7e, 0x02, 0x25, 0x02, 0x0b, 0x65,
    0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x2e, 0x6c, 0x6f, 0x67, 0x03, 0x75,
    0x36, 0x34, 0x00, 0x00, 0x0b, 0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e,
    0x2e, 0x6c, 0x6f, 0x67, 0x03, 0x68, 0x65, 0x78, 0x00, 0x00, 0x03, 0x02,
    0x01, 0x01, 0x07, 0x08, 0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x02,
    0x0a, 0x0e, 0x01, 0x0c, 0x00, 0x42, 0x2a, 0x10, 0x00, 0x42, 0x0f, 0x10,
    0x01, 0x42, 0x07, 0x0b
  };
  ErWasmHostCalls host = {0};
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  g_test_wasm_log_u64_calls = 0u;
  g_test_wasm_log_hex_calls = 0u;
  host.log_u64 = test_vm_log_u64;
  host.log_hex = test_vm_log_hex;

  check_int64("wasm log init",
              er_wasm_init(&module, wasm_log_import_test,
                           (UINT32)sizeof(wasm_log_import_test), &host),
              0);
  check_int64("wasm log reject ui app contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              -1);
  check_int64("wasm log find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm log main index", main_index, 2);
  check_int64("wasm log execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm log result", (UINT64)result, 7u);
  check_uint64("wasm log.u64 call count", g_test_wasm_log_u64_calls, 1u);
  check_uint64("wasm log.hex call count", g_test_wasm_log_hex_calls, 1u);
}

static void test_wasm_pci_imports(void) {
  /*
   * Purpose: keep PCI hostcall stack ordering covered without touching real config space.
   * Intention: internal driver-oriented imports stay explicit and rejected by app contracts.
   */
  static const UINT8 wasm_pci_import_test[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x15, 0x03, 0x60,
    0x04, 0x7e, 0x7e, 0x7e, 0x7e, 0x01, 0x7e, 0x60, 0x05, 0x7e, 0x7e, 0x7e,
    0x7e, 0x7e, 0x00, 0x60, 0x00, 0x01, 0x7e, 0x02, 0x2c, 0x02, 0x0b, 0x65,
    0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x2e, 0x70, 0x63, 0x69, 0x06, 0x72,
    0x65, 0x61, 0x64, 0x33, 0x32, 0x00, 0x00, 0x0b, 0x65, 0x64, 0x67, 0x65,
    0x72, 0x75, 0x6e, 0x2e, 0x70, 0x63, 0x69, 0x07, 0x77, 0x72, 0x69, 0x74,
    0x65, 0x33, 0x32, 0x00, 0x01, 0x03, 0x02, 0x01, 0x02, 0x07, 0x08, 0x01,
    0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x02, 0x0a, 0x1a, 0x01, 0x18, 0x00,
    0x42, 0x01, 0x42, 0x02, 0x42, 0x03, 0x42, 0x04, 0x10, 0x00, 0x42, 0x05,
    0x42, 0x06, 0x42, 0x07, 0x42, 0x08, 0x42, 0x09, 0x10, 0x01, 0x0b
  };
  ErWasmHostCalls host = {0};
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  g_test_wasm_pci_write32_calls = 0u;
  host.pci_read32 = test_vm_pci_read32;
  host.pci_write32 = test_vm_pci_write32;

  check_int64("wasm pci init",
              er_wasm_init(&module, wasm_pci_import_test,
                           (UINT32)sizeof(wasm_pci_import_test), &host),
              0);
  check_int64("wasm pci reject bus driver contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_BUS_DRIVER),
              -1);
  check_int64("wasm pci find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm pci main index", main_index, 2);
  check_int64("wasm pci execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm pci result", (UINT64)result, 0x12345678u);
  check_uint64("wasm pci.write32 call count", g_test_wasm_pci_write32_calls, 1u);
}

static void test_wasm_mmio_imports(void) {
  /*
   * Purpose: keep the edgerun.mmio host ABI covered without booting firmware.
   * Intention: the module calls map(4096, 8), then read32(handle, 4), and returns the read value.
   */
  static const UINT8 wasm_mmio_import_test[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0b, 0x02, 0x60,
    0x02, 0x7e, 0x7e, 0x01, 0x7e, 0x60, 0x00, 0x01, 0x7e, 0x02, 0x2a, 0x02,
    0x0c, 0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x2e, 0x6d, 0x6d, 0x69,
    0x6f, 0x03, 0x6d, 0x61, 0x70, 0x00, 0x00, 0x0c, 0x65, 0x64, 0x67, 0x65,
    0x72, 0x75, 0x6e, 0x2e, 0x6d, 0x6d, 0x69, 0x6f, 0x06, 0x72, 0x65, 0x61,
    0x64, 0x33, 0x32, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x07, 0x08, 0x01,
    0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x02, 0x0a, 0x0f, 0x01, 0x0d, 0x00,
    0x42, 0x80, 0x20, 0x42, 0x08, 0x10, 0x00, 0x42, 0x04, 0x10, 0x01, 0x0b
  };
  ErWasmHostCalls host = {0};
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  host.mmio_map = test_vm_mmio_map;
  host.mmio_read32 = test_vm_mmio_read32;

  check_int64("wasm mmio init", er_wasm_init(&module, wasm_mmio_import_test, (UINT32)sizeof(wasm_mmio_import_test), &host), 0);
  check_int64("wasm mmio reject ui app contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              -1);
  check_int64("wasm mmio find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm mmio main index", main_index, 2);
  check_int64("wasm mmio execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm mmio result", (UINT64)result, 0x55667788u);
}

static void test_wasm_bus_exec_import(void) {
  /*
   * Purpose: prove WASM driver code can send structured bus packets through linear memory.
   * Intention: keep device drivers outside the executor while preserving addressed hardware I/O.
   */
  static UINT8 memory[65536];
  ErWasmHostCalls host = {0};
  ErWasmLinearMemory linear_memory;
  ErDriverAdmissionPolicy policy;
  ErDriverAdmissionPolicy denied_policy;
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  check_int64("wasm linear memory prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  check_uint64("wasm linear memory base", linear_memory.address_base, ER_WASM_LINEAR_MEMORY_BASE);
  check_uint64("wasm linear memory len", linear_memory.address_len, sizeof(memory));
  check_uint64("wasm linear memory inbox", linear_memory.relay_inbox_base, 0u);
  check_uint64("wasm linear memory outbox", linear_memory.relay_outbox_base, 1024u);
  {
    UINT32 region_base = 0u;
    UINT32 region_len = 0u;
    check_int64("wasm public inbox region",
                er_wasm_linear_memory_public_region(&linear_memory,
                                                    ER_WASM_PUBLIC_REGION_RELAY_INBOX,
                                                    &region_base, &region_len),
                0);
    check_uint64("wasm public inbox base", region_base, 0u);
    check_uint64("wasm public inbox len", region_len, 1024u);
    check_int64("wasm public outbox region",
                er_wasm_linear_memory_public_region(&linear_memory,
                                                    ER_WASM_PUBLIC_REGION_RELAY_OUTBOX,
                                                    &region_base, &region_len),
                0);
    check_uint64("wasm public outbox base", region_base, 1024u);
    check_uint64("wasm public outbox len", region_len, 2048u);
    check_int64("wasm reject unknown public region",
                er_wasm_linear_memory_public_region(&linear_memory, 0xffffffffu,
                                                    &region_base, &region_len),
                -1);
  }
  check_int64("wasm linear memory reject outbox overflow",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 65535u, 2u,
                                            &linear_memory),
              -1);
  check_int64("wasm linear memory reject missing inbox",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 0u, 1024u, 2048u,
                                            &linear_memory),
              -1);
  check_int64("wasm linear memory reject overlap",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 2048u, 1024u, 2048u,
                                            &linear_memory),
              -1);
  check_int64("wasm linear memory restore",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  check_int64("wasm bus policy prepare",
              er_driver_policy_prepare_mmio32((UINT32)sizeof(memory), 4096u, 4u,
                                              ER_BUS_ACCESS_READ8, &policy),
              1);
  check_int64("wasm bus denied policy prepare",
              er_driver_policy_prepare_mmio32((UINT32)sizeof(memory), 8192u, 4u,
                                              ER_BUS_ACCESS_READ8, &denied_policy),
              1);

  host.bus_exec = test_vm_bus_exec;
  host.linear_memory = linear_memory;
  host.driver_policy = &policy;

  check_int64("wasm bus init",
              er_wasm_init(&module, g_edgerun_driver_bus_probe_wasm,
                           ER_DRIVER_BUS_PROBE_WASM_SIZE, &host),
              0);
  check_int64("wasm bus driver contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_BUS_DRIVER),
              0);
  check_int64("wasm bus reject ui app contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              -1);
  linear_memory.address_base = 1u;
  host.linear_memory = linear_memory;
  check_int64("wasm bus reject nonzero base",
              er_wasm_init(&module, g_edgerun_driver_bus_probe_wasm,
                           ER_DRIVER_BUS_PROBE_WASM_SIZE, &host),
              -1);
  linear_memory.address_base = ER_WASM_LINEAR_MEMORY_BASE;
  host.linear_memory = linear_memory;
  check_int64("wasm bus restore after reject",
              er_wasm_init(&module, g_edgerun_driver_bus_probe_wasm,
                           ER_DRIVER_BUS_PROBE_WASM_SIZE, &host),
              0);
  check_int64("wasm bus memory min", module.memory_min_pages, 1);
  check_uint64("wasm bus linear len", module.linear_memory.address_len, sizeof(memory));
  check_uint64("wasm bus relay inbox len", module.linear_memory.relay_inbox_len, 1024u);
  check_uint64("wasm bus relay outbox len", module.linear_memory.relay_outbox_len, 2048u);
  check_int64("wasm bus find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm bus main index", main_index, 1);

  check_int64("wasm bus execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm bus result", (UINT64)result, 0x5au);

  host.driver_policy = &denied_policy;
  check_int64("wasm bus denied policy init",
              er_wasm_init(&module, g_edgerun_driver_bus_probe_wasm,
                           ER_DRIVER_BUS_PROBE_WASM_SIZE, &host),
              0);
  check_int64("wasm bus denied policy find main",
              er_wasm_find_main(&module, &main_index),
              0);
  check_int64("wasm bus denied policy execute",
              er_wasm_execute_i64(&module, main_index, &result),
              -1);
}

static void test_wasm_public_region_imports(void) {
  /*
   * Purpose: prove WASM apps discover public memory regions through hostcalls.
   * Intention: keep app memory private except for fixed, bounded regions the VM can meter cheaply.
   */
  static const UINT8 wasm_public_region_import_test[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0a, 0x02, 0x60,
    0x01, 0x7e, 0x01, 0x7e, 0x60, 0x00, 0x01, 0x7e, 0x02, 0x3a, 0x02, 0x0e,
    0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x2e, 0x6d, 0x65, 0x6d, 0x6f,
    0x72, 0x79, 0x0b, 0x72, 0x65, 0x67, 0x69, 0x6f, 0x6e, 0x5f, 0x62, 0x61,
    0x73, 0x65, 0x00, 0x00, 0x0e, 0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e,
    0x2e, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x0a, 0x72, 0x65, 0x67, 0x69,
    0x6f, 0x6e, 0x5f, 0x6c, 0x65, 0x6e, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01,
    0x05, 0x03, 0x01, 0x00, 0x01, 0x07, 0x08, 0x01, 0x04, 0x6d, 0x61, 0x69,
    0x6e, 0x00, 0x02, 0x0a, 0x0d, 0x01, 0x0b, 0x00, 0x42, 0x02, 0x10, 0x00,
    0x42, 0x02, 0x10, 0x01, 0x7c, 0x0b
  };
  static UINT8 memory[65536];
  ErWasmHostCalls host = {0};
  ErWasmLinearMemory linear_memory;
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  er_mem_zero(memory, (UINTN)sizeof(memory));
  check_int64("wasm public region memory prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  host.linear_memory = linear_memory;
  check_int64("wasm public region init",
              er_wasm_init(&module, wasm_public_region_import_test,
                           (UINT32)sizeof(wasm_public_region_import_test), &host),
              0);
  check_int64("wasm public region find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm public region main index", main_index, 2);
  check_int64("wasm public region execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm public region outbox base plus len", (UINT64)result, 3072u);
}

static void test_relay_packets(void) {
  static const UINT8 payload[] = {'p', 'i', 'n', 'g'};
  UINT8 packet[ER_RELAY_PACKET_HEADER_LEN + sizeof(payload)];
  ErNodeId source;
  ErNodeId target;
  ErHash admission;
  ErHash token;
  ErHash route;
  ErHash payload_hash;
  ErRelayPacketHeader decoded_header;
  const UINT8* parsed_payload = 0;
  UINT32 parsed_payload_len = 0u;
  UINT32 packet_len = 0u;

  test_fill_bytes(source.bytes, ER_NODE_ID_LEN, 0x10u);
  test_fill_bytes(target.bytes, ER_NODE_ID_LEN, 0x30u);
  test_fill_bytes(admission.bytes, ER_HASH_LEN, 0x50u);
  test_fill_bytes(token.bytes, ER_HASH_LEN, 0x70u);
  test_fill_bytes(route.bytes, ER_HASH_LEN, 0x90u);
  test_fill_bytes(payload_hash.bytes, ER_HASH_LEN, 0xb0u);

  check_int64("relay packet prepare",
              er_relay_packet_prepare(packet, (UINT32)sizeof(packet), &source, &target,
                                      &admission, &token, &route, 7u, 3u, 12u,
                                      &payload_hash, payload, (UINT32)sizeof(payload),
                                      &packet_len),
              1);
  check_uint64("relay packet len", packet_len, sizeof(packet));
  check_int64("relay packet valid", er_relay_packet_valid(packet, packet_len), 1);
  check_int64("relay packet payload",
              er_relay_packet_payload(packet, packet_len, &parsed_payload, &parsed_payload_len),
              1);
  check_int64("relay packet decode header",
              er_relay_packet_decode_header(packet, packet_len, &decoded_header), 1);
  check_uint64("relay packet decoded abi", decoded_header.abi_version,
               ER_RELAY_PACKET_ABI_VERSION);
  check_uint64("relay packet decoded kind", decoded_header.packet_kind,
               ER_RELAY_PACKET_KIND_BYTES);
  check_node_id_equal("relay packet decoded source",
                      &decoded_header.source_node_id, &source);
  check_node_id_equal("relay packet decoded target",
                      &decoded_header.target_node_id, &target);
  check_hash_equal("relay packet decoded admission",
                   &decoded_header.admission_id, &admission);
  check_hash_equal("relay packet decoded token",
                   &decoded_header.token_id, &token);
  check_hash_equal("relay packet decoded route",
                   &decoded_header.route_hash, &route);
  check_hash_equal("relay packet decoded payload hash",
                   &decoded_header.payload_hash, &payload_hash);
  check_uint64("relay packet decoded sequence", decoded_header.sequence, 7u);
  check_uint64("relay packet decoded cost", decoded_header.cost_per_byte, 3u);
  check_uint64("relay packet decoded max cost", decoded_header.max_total_cost, 12u);
  check_uint64("relay packet decoded payload len", decoded_header.payload_len,
               sizeof(payload));
  check_uint64("relay packet payload len", parsed_payload_len, sizeof(payload));
  check_uint64("relay packet payload byte0", parsed_payload[0], payload[0]);
  check_uint64("relay packet payload byte3", parsed_payload[3], payload[3]);
  packet[0] = 0xffu;
  check_int64("relay packet reject abi", er_relay_packet_valid(packet, packet_len), 0);
  check_int64("relay packet reject decode bad abi",
              er_relay_packet_decode_header(packet, packet_len, &decoded_header), 0);
  packet[0] = 1u;
  check_int64("relay packet reject short len", er_relay_packet_valid(packet, packet_len - 1u), 0);
  er_mem_zero(packet + ER_RELAY_PACKET_HEADER_LEN - ER_HASH_LEN, ER_HASH_LEN);
  check_int64("relay packet reject empty payload hash",
              er_relay_packet_valid(packet, packet_len), 0);
  test_fill_bytes(payload_hash.bytes, ER_HASH_LEN, 0xb0u);
  check_int64("relay packet reject cost overflow",
              er_relay_packet_prepare(packet, (UINT32)sizeof(packet), &source, &target,
                                      &admission, &token, &route, 8u, ~0ull, ~0ull,
                                      &payload_hash, payload, (UINT32)sizeof(payload),
                                      &packet_len),
              0);
}

static void test_wasm_relay_imports(void) {
  /*
   * Purpose: prove a WASM program can only exchange relay bytes through admitted memory windows.
   * Intention: make inbox/outbox jurisdiction a VM-enforced boundary, not a program convention.
   */
  static const UINT8 wasm_relay_import_test[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x0b, 0x02, 0x60,
    0x02, 0x7e, 0x7e, 0x01, 0x7e, 0x60, 0x00, 0x01, 0x7e, 0x02, 0x2b, 0x02,
    0x0d, 0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x2e, 0x72, 0x65, 0x6c,
    0x61, 0x79, 0x04, 0x73, 0x65, 0x6e, 0x64, 0x00, 0x00, 0x0d, 0x65, 0x64,
    0x67, 0x65, 0x72, 0x75, 0x6e, 0x2e, 0x72, 0x65, 0x6c, 0x61, 0x79, 0x04,
    0x72, 0x65, 0x63, 0x76, 0x00, 0x00, 0x03, 0x02, 0x01, 0x01, 0x05, 0x03,
    0x01, 0x00, 0x01, 0x07,
    0x08, 0x01, 0x04, 0x6d, 0x61, 0x69, 0x6e, 0x00, 0x02, 0x0a, 0x13, 0x01,
    0x11, 0x00, 0x42, 0x80, 0x08, 0x42, 0xec, 0x01, 0x10, 0x00, 0x42, 0x00,
    0x42, 0x04, 0x10, 0x01, 0x7c, 0x0b
  };
  static const UINT8 payload[] = {'p', 'i', 'n', 'g'};
  static UINT8 memory[65536];
  UINT8 wasm_render_import_test[sizeof(wasm_relay_import_test)];
  ErWasmHostCalls host = {0};
  ErWasmLinearMemory linear_memory;
  ErWasmModule module;
  ErNodeId source;
  ErNodeId target;
  ErHash admission;
  ErHash token;
  ErHash route;
  ErHash payload_hash;
  ErHash session_id;
  ErHash invocation_id;
  ErHash capability_id;
  ErHash scene_hash;
  ErCapabilityEnvelopeHeader render_header;
  UINT32 main_index = 0;
  UINT32 packet_len = 0u;
  INT64 result = 0;
  UINTN i;
  UINT8 patched_render_len = 0u;

  er_mem_zero(memory, (UINTN)sizeof(memory));
  test_fill_bytes(source.bytes, ER_NODE_ID_LEN, 0x11u);
  test_fill_bytes(target.bytes, ER_NODE_ID_LEN, 0x31u);
  test_fill_bytes(admission.bytes, ER_HASH_LEN, 0x51u);
  test_fill_bytes(token.bytes, ER_HASH_LEN, 0x71u);
  test_fill_bytes(route.bytes, ER_HASH_LEN, 0x91u);
  test_fill_bytes(payload_hash.bytes, ER_HASH_LEN, 0xb1u);
  test_fill_bytes(session_id.bytes, ER_HASH_LEN, 0xc1u);
  test_fill_bytes(invocation_id.bytes, ER_HASH_LEN, 0xd1u);
  test_fill_bytes(capability_id.bytes, ER_HASH_LEN, 0xe1u);
  test_fill_bytes(scene_hash.bytes, ER_HASH_LEN, 0xf1u);
  check_int64("wasm relay linear memory prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  host.relay_send = test_vm_relay_send;
  host.relay_recv = test_vm_relay_recv;
  host.linear_memory = linear_memory;

  check_int64("wasm relay init",
              er_wasm_init(&module, wasm_relay_import_test,
                           (UINT32)sizeof(wasm_relay_import_test), &host),
              0);
  check_int64("wasm relay find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm relay main index", main_index, 2);
  check_int64("wasm relay packet prepare",
              er_relay_packet_prepare(memory + 1024u,
                                      (UINT32)sizeof(memory) - 1024u,
                                      &source, &target, &admission, &token, &route,
                                      9u, 2u, 8u, &payload_hash,
                                      payload, (UINT32)sizeof(payload),
                                      &packet_len),
              1);
  check_uint64("wasm relay packet len", packet_len, ER_RELAY_PACKET_HEADER_LEN + 4u);
  check_int64("wasm relay execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm relay result", (UINT64)result, ER_RELAY_PACKET_HEADER_LEN + 8u);
  check_uint64("wasm relay inbox byte0", memory[0], (UINT8)'p');
  check_uint64("wasm relay inbox byte1", memory[1], (UINT8)'o');
  check_uint64("wasm relay inbox byte2", memory[2], (UINT8)'n');
  check_uint64("wasm relay inbox byte3", memory[3], (UINT8)'g');

  check_uint64("wasm render capability payload size",
               sizeof(ErCapabilityEnvelopeHeader), 232u);
  er_mem_copy(wasm_render_import_test, wasm_relay_import_test,
              (UINTN)sizeof(wasm_render_import_test));
  for (i = 0u; i + 4u < sizeof(wasm_render_import_test); ++i) {
    if (wasm_render_import_test[i] == 0x42u &&
        wasm_render_import_test[i + 1u] == 0xecu &&
        wasm_render_import_test[i + 2u] == 0x01u &&
        wasm_render_import_test[i + 3u] == 0x10u &&
        wasm_render_import_test[i + 4u] == 0x00u) {
      wasm_render_import_test[i + 1u] = 0xd0u;
      wasm_render_import_test[i + 2u] = 0x03u;
      patched_render_len = 1u;
    }
  }
  check_uint64("wasm render import patch", patched_render_len, 1u);
  check_int64("wasm render capability prepare",
              er_work_prepare_capability_envelope_header(ER_CAPABILITY_PACKET_INVOKE,
                                                         ER_WORK_TYPE_CAPABILITY_INVOKE,
                                                         ER_CAPABILITY_CONTENT_RENDER,
                                                         ER_CAPABILITY_RISK_NONE,
                                                         &session_id,
                                                         &invocation_id,
                                                         &capability_id,
                                                         &source,
                                                         &target,
                                                         7u,
                                                         1000u,
                                                         &scene_hash,
                                                         (UINT32)sizeof(payload),
                                                         &render_header),
              1);
  er_mem_zero(memory, (UINTN)sizeof(memory));
  host.relay_send = test_vm_relay_send_render;
  check_int64("wasm render relay init",
              er_wasm_init(&module, wasm_render_import_test,
                           (UINT32)sizeof(wasm_render_import_test), &host),
              0);
  check_int64("wasm render relay find main",
              er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm render relay packet prepare after init",
              er_relay_packet_prepare(memory + 1024u,
                                      (UINT32)sizeof(memory) - 1024u,
                                      &source, &target, &admission, &token, &route,
                                      10u, 1u,
                                      (UINT64)sizeof(ErCapabilityEnvelopeHeader),
                                      &payload_hash,
                                      (const UINT8*)&render_header,
                                      (UINT32)sizeof(render_header),
                                      &packet_len),
              1);
  check_uint64("wasm render relay packet len", packet_len,
               ER_RELAY_PACKET_HEADER_LEN + sizeof(ErCapabilityEnvelopeHeader));
  check_int64("wasm render relay packet valid after init",
              er_relay_packet_valid(memory + 1024u, packet_len), 1);
  check_int64("wasm render relay execute",
              er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm render relay result", (UINT64)result,
               ER_RELAY_PACKET_HEADER_LEN +
               sizeof(ErCapabilityEnvelopeHeader) + 4u);
  check_int64("wasm relay shifted outbox prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 2048u, 2048u,
                                            &linear_memory),
              0);
  host.relay_send = test_vm_relay_send;
  host.linear_memory = linear_memory;
  check_int64("wasm relay shifted outbox init",
              er_wasm_init(&module, wasm_relay_import_test,
                           (UINT32)sizeof(wasm_relay_import_test), &host),
              0);
  check_int64("wasm relay shifted outbox find main",
              er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm relay reject send outside outbox",
              er_wasm_execute_i64(&module, main_index, &result), -1);
}

static void test_wasm_ui_emit_import(void) {
  /*
   * Purpose: prove authored WASM modules can emit UI command lists.
   * Intention: the VM validates public outbox bounds before host UI work.
   */
  static UINT8 memory[65536];
  ErWasmHostCalls host = {0};
  ErWasmLinearMemory linear_memory;
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  er_mem_zero(memory, (UINTN)sizeof(memory));

  check_int64("wasm ui linear memory prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  host.linear_memory = linear_memory;
  host.ui_emit = test_vm_ui_emit;
  check_int64("wasm ui init",
              er_wasm_init(&module, g_edgerun_ui_counter_wasm,
                           ER_UI_COUNTER_WASM_SIZE, &host),
              0);
  check_int64("wasm ui app contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              0);
  check_int64("wasm ui reject bus driver contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_BUS_DRIVER),
              -1);
  check_int64("wasm ui find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm ui main index", main_index, 2);
  check_int64("wasm ui execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm ui result", (UINT64)result,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("wasm ui command count", memory[1028], 3u);
  check_uint64("wasm ui empty input hit id", memory[1124], 0u);

  check_int64("wasm ui shifted outbox prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 2048u, 2048u,
                                            &linear_memory),
              0);
  host.linear_memory = linear_memory;
  check_int64("wasm ui shifted outbox init",
              er_wasm_init(&module, g_edgerun_ui_counter_wasm,
                           ER_UI_COUNTER_WASM_SIZE, &host),
              0);
  check_int64("wasm ui shifted outbox find main",
              er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm ui shifted outbox execute",
              er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm ui shifted outbox command count", memory[2052], 3u);
}

static void test_wasm_c_generated_hostcall_modules(void) {
  static UINT8 memory[65536];
  ErWasmHostCalls host = {0};
  ErWasmLinearMemory linear_memory;
  ErWasmModule module;
  ErDriverAdmissionPolicy driver_policy;
  ErBusIoPacket* request;
  ErBusIoPacket* response;
  UINT32 main_index = 0;
  UINT32 ui_packet_len = ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                         ER_WASM_UI_RECT_RECORD_LEN +
                         ER_WASM_UI_HIT_RECORD_LEN +
                         ER_WASM_UI_QUAD_RECORD_LEN;
  INT64 result = 0;

  er_mem_zero(memory, (UINTN)sizeof(memory));
  check_int64("wasm c hostcall memory prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  check_int64("wasm c bus policy prepare",
              er_driver_policy_prepare_mmio32((UINT32)sizeof(memory), 4096u, 4u,
                                              ER_BUS_ACCESS_READ8, &driver_policy),
              1);

  host.linear_memory = linear_memory;
  host.bus_exec = test_vm_bus_exec;
  host.driver_policy = &driver_policy;
  check_int64("wasm c bus init",
              er_wasm_init(&module, g_edgerun_c_hostcall_bus_exec_wasm,
                           ER_C_HOSTCALL_BUS_EXEC_WASM_SIZE, &host),
              0);
  check_int64("wasm c bus driver contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_BUS_DRIVER),
              0);
  request = (ErBusIoPacket*)memory;
  response = (ErBusIoPacket*)(memory + 128u);
  request->abi_version = ER_BUS_ABI_VERSION;
  request->packet_kind = ER_BUS_PACKET_IO_REQUEST;
  request->packet_id = 1u;
  request->op.abi_version = ER_BUS_ABI_VERSION;
  request->op.bus_kind = ER_BUS_KIND_MMIO32;
  request->op.access = ER_BUS_ACCESS_READ8;
  request->op.width = 1u;
  request->op.address.abi_version = ER_BUS_ABI_VERSION;
  request->op.address.bus_kind = ER_BUS_KIND_MMIO32;
  request->op.address.access_flags = ER_BUS_ACCESS_READ8;
  request->op.address.base = 4096u;
  request->op.address.len = 4u;
  check_int64("wasm c bus find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm c bus main index", main_index, 1);
  check_int64("wasm c bus execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm c bus result", (UINT64)result, 1u);
  check_uint64("wasm c bus response result", response->result, 0x5au);

  host.bus_exec = 0;
  host.driver_policy = 0;
  check_int64("wasm c region base init",
              er_wasm_init(&module, g_edgerun_c_hostcall_region_base_wasm,
                           ER_C_HOSTCALL_REGION_BASE_WASM_SIZE, &host),
              0);
  check_int64("wasm c region base contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              0);
  check_int64("wasm c region base find main",
              er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm c region base main index", main_index, 2);
  check_int64("wasm c region base execute",
              er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm c region base result", (UINT64)result, 1024u);

  check_int64("wasm c region len init",
              er_wasm_init(&module, g_edgerun_c_hostcall_region_len_wasm,
                           ER_C_HOSTCALL_REGION_LEN_WASM_SIZE, &host),
              0);
  check_int64("wasm c region len contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              0);
  check_int64("wasm c region len find main",
              er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm c region len main index", main_index, 2);
  check_int64("wasm c region len execute",
              er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm c region len result", (UINT64)result, 2048u);

  host.ui_emit = test_vm_ui_emit;
  check_int64("wasm c ui emit init",
              er_wasm_init(&module, g_edgerun_c_hostcall_ui_emit_wasm,
                           ER_C_HOSTCALL_UI_EMIT_WASM_SIZE, &host),
              0);
  check_int64("wasm c ui emit contract",
              er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP),
              0);
  test_write_wasm_ui_scene_packet(memory + 1024u, ui_packet_len);
  check_int64("wasm c ui emit find main",
              er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm c ui emit main index", main_index, 1);
  check_int64("wasm c ui emit execute",
              er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm c ui emit result", (UINT64)result, ui_packet_len);
}

static void test_epoch_clock_rollover(void) {
  ErEpochClockLimits limits;
  ErEpochClock clock;
  ErEpochBoundary boundary;
  ErEpochClockModifier modifier;
  ErEpochStamp earlier;
  ErEpochStamp later;

  limits.ticks_per_slot = 2u;
  limits.slots_per_epoch = 2u;
  limits.epochs_per_era = 2u;

  check_int64("epoch rejects null limits", er_epoch_clock_init(0, &clock), 0);
  limits.ticks_per_slot = 0u;
  check_int64("epoch rejects zero tick limit", er_epoch_clock_init(&limits, &clock), 0);
  limits.ticks_per_slot = 2u;
  limits.slots_per_epoch = 3u;
  check_int64("epoch rejects non-power slot limit", er_epoch_clock_init(&limits, &clock), 0);
  limits.slots_per_epoch = 2u;
  check_int64("epoch init", er_epoch_clock_init(&limits, &clock), 1);
  check_uint64("epoch initial tick", clock.now.tick, 0u);
  check_uint64("epoch tick mask", clock.tick_mask, 1u);
  check_uint64("epoch slot mask", clock.slot_mask, 1u);
  check_uint64("epoch epoch mask", clock.epoch_mask, 1u);
  check_uint64("epoch tick shift", clock.tick_shift, 1u);

  check_int64("epoch advance 1", er_epoch_clock_advance(&clock, &boundary), 1);
  check_uint64("epoch tick 1", clock.now.tick, 1u);
  check_uint64("epoch slot boundary clear", boundary.slot_boundary, 0u);

  check_int64("epoch advance slot boundary", er_epoch_clock_advance(&clock, &boundary), 1);
  check_uint64("epoch tick reset", clock.now.tick, 0u);
  check_uint64("epoch slot 1", clock.now.slot, 1u);
  check_uint64("epoch slot boundary set", boundary.slot_boundary, 1u);
  check_uint64("epoch boundary no epoch", boundary.epoch_boundary, 0u);

  check_int64("epoch advance 3", er_epoch_clock_advance(&clock, &boundary), 1);
  check_int64("epoch advance epoch boundary", er_epoch_clock_advance(&clock, &boundary), 1);
  check_uint64("epoch slot reset", clock.now.slot, 0u);
  check_uint64("epoch epoch 1", clock.now.epoch, 1u);
  check_uint64("epoch boundary epoch set", boundary.epoch_boundary, 1u);
  check_uint64("epoch boundary no era", boundary.era_boundary, 0u);

  check_int64("epoch advance 5", er_epoch_clock_advance(&clock, &boundary), 1);
  check_int64("epoch advance 6", er_epoch_clock_advance(&clock, &boundary), 1);
  check_int64("epoch advance 7", er_epoch_clock_advance(&clock, &boundary), 1);
  check_int64("epoch advance era boundary", er_epoch_clock_advance(&clock, &boundary), 1);
  check_uint64("epoch era 1", clock.now.era, 1u);
  check_uint64("epoch epoch reset", clock.now.epoch, 0u);
  check_uint64("epoch era boundary set", boundary.era_boundary, 1u);

  earlier = clock.now;
  later = clock.now;
  later.tick = 1u;
  check_int64("epoch compare less", er_epoch_stamp_compare(earlier, later), -1);
  check_int64("epoch compare equal", er_epoch_stamp_compare(earlier, earlier), 0);
  check_int64("epoch compare greater", er_epoch_stamp_compare(later, earlier), 1);
  check_int64("epoch reject invalid advance", er_epoch_clock_advance(0, &boundary), 0);

  limits.slots_per_epoch = 4u;
  check_int64("epoch reinit for modifier", er_epoch_clock_init(&limits, &clock), 1);
  modifier = er_epoch_clock_default_modifier();
  check_uint64("epoch default stride", modifier.tick_stride, 1u);
  modifier.tick_stride = 5u;
  check_int64("epoch modifier advance",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 1);
  check_uint64("epoch modifier tick", clock.now.tick, 1u);
  check_uint64("epoch modifier slot", clock.now.slot, 2u);
  check_uint64("epoch modifier slot boundary", boundary.slot_boundary, 1u);
  check_uint64("epoch modifier epoch boundary", boundary.epoch_boundary, 0u);
  modifier.tick_stride = 11u;
  check_int64("epoch modifier crosses epoch and era",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 1);
  check_uint64("epoch modifier final tick", clock.now.tick, 0u);
  check_uint64("epoch modifier final slot", clock.now.slot, 0u);
  check_uint64("epoch modifier final epoch", clock.now.epoch, 0u);
  check_uint64("epoch modifier final era", clock.now.era, 1u);
  check_uint64("epoch modifier epoch boundary", boundary.epoch_boundary, 1u);
  check_uint64("epoch modifier era boundary", boundary.era_boundary, 1u);
  modifier.tick_stride = 0u;
  check_int64("epoch reject zero stride",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 0);
  clock.now.tick = 1u;
  modifier.tick_stride = UINT64_MAX;
  check_int64("epoch reject tick overflow",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 0);
  check_uint64("epoch tick overflow unchanged", clock.now.tick, 1u);
  clock.now.tick = 0u;
  clock.now.slot = UINT64_MAX;
  modifier.tick_stride = 2u;
  check_int64("epoch reject slot overflow",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 0);
  check_uint64("epoch slot overflow unchanged", clock.now.slot, UINT64_MAX);
  clock.now.slot = 3u;
  clock.now.epoch = UINT64_MAX;
  check_int64("epoch reject epoch overflow",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 0);
  check_uint64("epoch epoch overflow unchanged", clock.now.epoch, UINT64_MAX);
  clock.now.epoch = 1u;
  clock.now.era = UINT64_MAX;
  check_int64("epoch reject era overflow",
              er_epoch_clock_advance_with_modifier(&clock, &modifier, &boundary), 0);
  check_uint64("epoch era overflow unchanged", clock.now.era, UINT64_MAX);
}
