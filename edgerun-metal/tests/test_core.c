#include "er_mmio.h"
#include "er_mem.h"
#include "er_pci.h"
#include "er_acpi.h"
#include "er_app.h"
#include "er_blake3.h"
#include "er_boot_profile.h"
#include "er_bus.h"
#include "er_crypto_blake3.h"
#include "er_device_identity.h"
#include "er_epoch_clock.h"
#include "er_identity.h"
#include "er_hw_relay.h"
#include "er_native_eth.h"
#include "er_native_boot.h"
#include "er_net_frame.h"
#include "er_netlog.h"
#include "er_ps2_keyboard.h"
#include "er_relay_packet.h"
#include "er_tpm.h"
#include "er_work_route.h"
#include "er_gfx_console.h"
#include "er_ui_surface_renderer.h"
#include "er_ui_tabler_icon_atlas.h"
#include "er_ui_ledger_app.h"
#include "er_ui_wasm_app.h"
#include "er_ui_text.h"
#include "er_virtio.h"
#include "er_virtio_gpu.h"
#include "er_virtio_net.h"
#include "er_vfs.h"
#include "erwire.h"
#include "font_geist.h"
#include "wasm_vm.h"
#include "wasm_driver_bus_probe_module.h"
#include "wasm_ui_counter_module.h"

/*
 * Purpose: test pure EdgeRun Metal core helpers outside firmware.
 * Intention: catch BAR decode and MMIO handle regressions before real hardware boots.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int g_failed = 0;
static int g_total = 0;

//@optimizer-ignore-function fake test hash must visit each supplied byte span deterministically
static UINT8 test_hash(void* ctx, const UINT8* domain, UINTN domain_len,
                       const ErByteSpan* spans, UINTN span_count, ErHash* out_hash) {
  UINTN i;
  UINTN j;
  UINT8 acc = (UINT8)(UINTN)ctx;

  if (domain == 0 || out_hash == 0) {
    return 0;
  }
  for (i = 0; i < domain_len; ++i) {
    acc = (UINT8)(acc + domain[i] + 1u);
  }
  for (i = 0; i < span_count; ++i) {
    if (spans[i].len > 0u && spans[i].bytes == 0) {
      return 0;
    }
    for (j = 0; j < spans[i].len; ++j) {
      acc = (UINT8)(acc + spans[i].bytes[j] + (UINT8)i + 3u);
    }
  }
  for (i = 0; i < ER_HASH_LEN; ++i) {
    out_hash->bytes[i] = (UINT8)(acc + (UINT8)i);
  }
  return 1;
}

static void check_int64(const char* name, INT64 actual, INT64 expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got %lld expected %lld\n", name, (long long)actual, (long long)expected);
    ++g_failed;
  }
}

static void check_uint64(const char* name, UINT64 actual, UINT64 expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got 0x%llx expected 0x%llx\n", name,
            (unsigned long long)actual, (unsigned long long)expected);
    ++g_failed;
  }
}

static void check_hash_equal(const char* name, const ErHash* actual, const ErHash* expected) {
  UINTN i;

  ++g_total;
  for (i = 0; i < ER_HASH_LEN; ++i) {
    if (actual->bytes[i] != expected->bytes[i]) {
      fprintf(stderr, "FAIL %s: hash differs at byte %llu\n", name, (unsigned long long)i);
      ++g_failed;
      return;
    }
  }
}

static void check_hash_not_equal(const char* name, const ErHash* actual, const ErHash* expected) {
  UINTN i;

  ++g_total;
  for (i = 0; i < ER_HASH_LEN; ++i) {
    if (actual->bytes[i] != expected->bytes[i]) {
      return;
    }
  }
  fprintf(stderr, "FAIL %s: hashes match\n", name);
  ++g_failed;
}

static void check_node_id_equal(const char* name, const ErNodeId* actual, const ErNodeId* expected) {
  UINTN i;

  ++g_total;
  for (i = 0; i < ER_NODE_ID_LEN; ++i) {
    if (actual->bytes[i] != expected->bytes[i]) {
      fprintf(stderr, "FAIL %s: node id differs at byte %llu\n", name, (unsigned long long)i);
      ++g_failed;
      return;
    }
  }
}

static void check_node_id_not_equal(const char* name, const ErNodeId* actual, const ErNodeId* expected) {
  UINTN i;

  ++g_total;
  for (i = 0; i < ER_NODE_ID_LEN; ++i) {
    if (actual->bytes[i] != expected->bytes[i]) {
      return;
    }
  }
  fprintf(stderr, "FAIL %s: node ids match\n", name);
  ++g_failed;
}

static void check_cstr(const char* name, const char* actual, const char* expected) {
  UINTN i = 0u;
  UINT8 matches = 1u;

  ++g_total;
  if (actual == 0 || expected == 0) {
    matches = (actual == expected);
  } else {
    while (actual[i] != 0 || expected[i] != 0) {
      if (actual[i] != expected[i]) {
        matches = 0u;
        break;
      }
      ++i;
    }
  }
  if (matches == 0u) {
    fprintf(stderr, "FAIL %s: got %s expected %s\n", name, actual == 0 ? "(null)" : actual, expected == 0 ? "(null)" : expected);
    ++g_failed;
  }
}

static void check_pixel(const char* name, UINT32 actual, UINT32 expected) {
  check_uint64(name, (UINT64)actual, (UINT64)expected);
}

static UINT8 test_hex_nibble(char c) {
  if (c >= '0' && c <= '9') {
    return (UINT8)(c - '0');
  }
  if (c >= 'a' && c <= 'f') {
    return (UINT8)(c - 'a' + 10);
  }
  if (c >= 'A' && c <= 'F') {
    return (UINT8)(c - 'A' + 10);
  }
  return 0xffu;
}

static void check_hash_hex(const char* name, const UINT8 actual[ER_HASH_LEN], const char* expected_hex) {
  UINTN i;
  UINT8 high;
  UINT8 low;
  UINT8 expected;

  ++g_total;
  for (i = 0u; i < ER_HASH_LEN; ++i) {
    high = test_hex_nibble(expected_hex[i * 2u]);
    low = test_hex_nibble(expected_hex[(i * 2u) + 1u]);
    expected = (UINT8)((high << 4u) | low);
    if (high > 0x0fu || low > 0x0fu || actual[i] != expected) {
      fprintf(stderr, "FAIL %s: byte %llu got 0x%02x expected 0x%02x\n",
              name, (unsigned long long)i, actual[i], expected);
      ++g_failed;
      return;
    }
  }
}

static void test_mem_helpers(void) {
  UINT8 dst[4] = {1u, 2u, 3u, 4u};
  const UINT8 src[4] = {9u, 8u, 7u, 6u};

  er_mem_zero(dst, 4u);
  check_uint64("mem zero byte 0", dst[0], 0u);
  check_uint64("mem zero byte 3", dst[3], 0u);
  er_mem_copy(dst, src, 4u);
  check_uint64("mem copy byte 0", dst[0], 9u);
  check_uint64("mem copy byte 3", dst[3], 6u);
  check_int64("mem equal match", er_mem_equal(dst, src, 4u), 1);
  dst[2] = 0u;
  check_int64("mem equal mismatch", er_mem_equal(dst, src, 4u), 0);
  check_int64("mem equal null left", er_mem_equal(0, src, 4u), 0);
  check_int64("mem equal null right", er_mem_equal(dst, 0, 4u), 0);
  check_int64("mem any nonzero match", er_mem_any_nonzero(dst, 4u), 1);
  er_mem_zero(dst, 4u);
  check_int64("mem any nonzero zeroed", er_mem_any_nonzero(dst, 4u), 0);
  check_int64("mem any nonzero null", er_mem_any_nonzero(0, 4u), 0);
  check_int64("mem any nonzero empty", er_mem_any_nonzero(src, 0u), 0);
  er_mem_zero(0, 4u);
  er_mem_copy(0, src, 4u);
  er_mem_copy(dst, 0, 4u);
}

static void test_blake3(void) {
  static const UINT8 abc[] = {'a', 'b', 'c'};
  static const UINT8 domain[] = {'e', 'r', ':', 't', 'e', 's', 't'};
  static const UINT8 span_a[] = {'a', 'b'};
  static const UINT8 span_b[] = {'c', 'd', 'e', 'f'};
  UINT8 large[1255];
  UINT8 digest[ER_BLAKE3_OUT_LEN];
  ErHash provider_hash;
  ErBlake3Hasher hasher;
  ErCryptoProvider provider;
  ErByteSpan spans[2];
  UINTN i;

  check_int64("blake3 empty",
              er_blake3_hash_bytes(0, 0u, digest),
              1);
  check_hash_hex("blake3 empty digest", digest,
                 "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262");

  check_int64("blake3 abc",
              er_blake3_hash_bytes(abc, sizeof(abc), digest),
              1);
  check_hash_hex("blake3 abc digest", digest,
                 "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85");

  //@optimizer-ignore deterministic test fixture pattern intentionally wraps at a prime byte value
  for (i = 0u; i < sizeof(large); ++i) {
    //@optimizer-ignore deterministic test fixture pattern intentionally wraps at a prime byte value
    large[i] = (UINT8)(i % 251u);
  }
  check_int64("blake3 large",
              er_blake3_hash_bytes(large, sizeof(large), digest),
              1);
  check_hash_hex("blake3 large digest", digest,
                 "8b929b2d329f8795b15060a2e5d087ea507aeba8dcf19fb00eb92ceb890d179e");

  er_blake3_init(&hasher);
  check_int64("blake3 update a", er_blake3_update(&hasher, large, 17u), 1);
  check_int64("blake3 update b", er_blake3_update(&hasher, &large[17], sizeof(large) - 17u), 1);
  check_int64("blake3 final", er_blake3_final(&hasher, digest), 1);
  check_hash_hex("blake3 incremental digest", digest,
                 "8b929b2d329f8795b15060a2e5d087ea507aeba8dcf19fb00eb92ceb890d179e");

  er_crypto_blake3_provider(&provider);
  spans[0].bytes = span_a;
  spans[0].len = sizeof(span_a);
  spans[1].bytes = span_b;
  spans[1].len = sizeof(span_b);
  check_int64("blake3 provider hash",
              er_crypto_hash(&provider, domain, sizeof(domain), spans, 2u, &provider_hash),
              1);
  check_hash_hex("blake3 provider digest", provider_hash.bytes,
                 "0c3b6b724833127c5e557fc48b82a6783858aff79a0a048a32e2029b2f04c650");
}

static void* test_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return size == 0u ? 0 : malloc(size);
}

static void* test_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void test_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static er_ui_allocator_t test_ui_allocator(void) {
  er_ui_allocator_t allocator;
  allocator.user = 0;
  allocator.alloc = test_alloc;
  allocator.free = test_free;
  return allocator;
}

static vr_font_allocator_t test_vr_allocator(void) {
  vr_font_allocator_t allocator;
  allocator.user = 0;
  allocator.alloc = test_alloc;
  allocator.realloc = test_realloc;
  allocator.free = test_free;
  return allocator;
}

static void test_put_le32(UINT8* dst, UINT32 value) {
  dst[0] = (UINT8)(value & 0xffu);
  dst[1] = (UINT8)((value >> 8) & 0xffu);
  dst[2] = (UINT8)((value >> 16) & 0xffu);
  dst[3] = (UINT8)((value >> 24) & 0xffu);
}

static void test_put_le64(UINT8* dst, UINT64 value) {
  test_put_le32(dst, (UINT32)(value & 0xffffffffu));
  test_put_le32(dst + 4, (UINT32)(value >> 32));
}

static void test_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> 8) & 0xffu);
  dst[1] = (UINT8)(value & 0xffu);
}

static void test_put_be32(UINT8* dst, UINT32 value) {
  dst[0] = (UINT8)((value >> 24) & 0xffu);
  dst[1] = (UINT8)((value >> 16) & 0xffu);
  dst[2] = (UINT8)((value >> 8) & 0xffu);
  dst[3] = (UINT8)(value & 0xffu);
}

static void test_fill_bytes(UINT8* dst, UINTN len, UINT8 seed) {
  UINTN i;

  for (i = 0u; i < len; ++i) {
    dst[i] = (UINT8)(seed + (UINT8)i);
  }
}

static void test_acpi_set_checksum(UINT8* bytes, UINTN len, UINTN checksum_offset) {
  UINTN i;
  UINT8 sum = 0;

  bytes[checksum_offset] = 0;
  for (i = 0; i < len; ++i) {
    sum = (UINT8)(sum + bytes[i]);
  }
  bytes[checksum_offset] = (UINT8)(0u - sum);
}

static INT64 test_vm_mmio_map(INT64 phys, INT64 len) {
  check_int64("wasm mmio.map phys", phys, 4096);
  check_int64("wasm mmio.map len", len, 8);
  return 7;
}

static INT64 test_vm_mmio_read32(INT64 handle, INT64 offset) {
  check_int64("wasm mmio.read32 handle", handle, 7);
  check_int64("wasm mmio.read32 offset", offset, 4);
  return 0x55667788;
}

static INT64 test_vm_bus_exec(const ErBusIoPacket* request, ErBusIoPacket* response) {
  if (request == 0 || response == 0) {
    return 0;
  }
  check_int64("wasm bus exec request abi", request->abi_version, ER_BUS_ABI_VERSION);
  check_int64("wasm bus exec request kind", request->packet_kind, ER_BUS_PACKET_IO_REQUEST);
  check_uint64("wasm bus exec packet id", request->packet_id, 1u);
  check_int64("wasm bus exec width", request->op.width, 1);
  check_uint64("wasm bus exec base", request->op.address.base, 4096u);
  check_uint64("wasm bus exec len", request->op.address.len, 4u);
  response->abi_version = ER_BUS_ABI_VERSION;
  response->packet_kind = ER_BUS_PACKET_IO_RESPONSE;
  response->status = ER_BUS_STATUS_OK;
  response->packet_id = request->packet_id;
  response->op = request->op;
  response->result = 0x5au;
  return 1;
}

static INT64 test_vm_relay_send(const UINT8* bytes, UINT32 len) {
  const UINT8* payload = 0;
  UINT32 payload_len = 0u;

  if (bytes == 0) {
    return 0;
  }
  check_uint64("wasm relay send len", len, ER_RELAY_PACKET_HEADER_LEN + 4u);
  check_int64("wasm relay send packet valid", er_relay_packet_valid(bytes, len), 1);
  check_int64("wasm relay send payload view",
              er_relay_packet_payload(bytes, len, &payload, &payload_len), 1);
  check_uint64("wasm relay send payload len", payload_len, 4u);
  check_uint64("wasm relay send byte0", payload[0], (UINT8)'p');
  check_uint64("wasm relay send byte1", payload[1], (UINT8)'i');
  check_uint64("wasm relay send byte2", payload[2], (UINT8)'n');
  check_uint64("wasm relay send byte3", payload[3], (UINT8)'g');
  return (INT64)len;
}

static INT64 test_vm_relay_send_render(const UINT8* bytes, UINT32 len) {
  const UINT8* payload = 0;
  const ErCapabilityEnvelopeHeader* header = 0;
  UINT32 payload_len = 0u;

  if (bytes == 0) {
    return 0;
  }
  check_uint64("wasm render relay send len", len,
               ER_RELAY_PACKET_HEADER_LEN + sizeof(ErCapabilityEnvelopeHeader));
  check_int64("wasm render relay packet valid",
              er_relay_packet_valid(bytes, len), 1);
  check_int64("wasm render relay payload view",
              er_relay_packet_payload(bytes, len, &payload, &payload_len), 1);
  check_uint64("wasm render relay payload len", payload_len,
               sizeof(ErCapabilityEnvelopeHeader));
  header = (const ErCapabilityEnvelopeHeader*)payload;
  check_int64("wasm render capability valid",
              er_work_capability_envelope_header_valid(header), 1);
  check_uint64("wasm render capability kind", header->kind,
               ER_CAPABILITY_PACKET_INVOKE);
  check_uint64("wasm render capability operation", header->operation,
               ER_WORK_TYPE_CAPABILITY_INVOKE);
  check_uint64("wasm render capability content", header->content_type,
               ER_CAPABILITY_CONTENT_RENDER);
  check_uint64("wasm render capability risk", header->risk_flags,
               ER_CAPABILITY_RISK_NONE);
  return (INT64)len;
}

static INT64 test_vm_relay_recv(UINT8* bytes, UINT32 capacity) {
  if (bytes == 0) {
    return 0;
  }
  check_uint64("wasm relay recv capacity", capacity, 4u);
  bytes[0] = (UINT8)'p';
  bytes[1] = (UINT8)'o';
  bytes[2] = (UINT8)'n';
  bytes[3] = (UINT8)'g';
  return 4;
}

static INT64 test_vm_ui_emit(void* user, const UINT8* bytes, UINT32 len,
                             const er_ui_scene_stats_t* stats) {
  (void)user;

  if (bytes == 0 || stats == 0) {
    return 0;
  }
  check_uint64("wasm ui emit len", len,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("wasm ui emit abi lo", bytes[0], ER_WASM_UI_COMMAND_ABI_VERSION);
  check_uint64("wasm ui emit rects", stats->rects, 1u);
  check_uint64("wasm ui emit hits", stats->hits, 1u);
  check_uint64("wasm ui emit text", stats->text_quads, 1u);
  check_uint64("wasm ui emit rect mode",
               bytes[ER_WASM_UI_COMMAND_LIST_HEADER_LEN + 52u], 0u);
  check_uint64("wasm ui emit hit kind",
               bytes[ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                     ER_WASM_UI_RECT_RECORD_LEN],
               3u);
  return (INT64)len;
}

static void test_write_wasm_ui_header(UINT8* bytes, UINT32 command_count,
                                      UINT32 rect_count, UINT32 hit_count,
                                      UINT32 text_quad_count) {
  test_put_le32(bytes + 0u, ER_WASM_UI_COMMAND_ABI_VERSION);
  test_put_le32(bytes + 4u, command_count);
  test_put_le32(bytes + 8u, rect_count);
  test_put_le32(bytes + 12u, hit_count);
  test_put_le32(bytes + 16u, 0u);
  test_put_le32(bytes + 20u, 0u);
  test_put_le32(bytes + 24u, 0u);
  test_put_le32(bytes + 28u, 0u);
  test_put_le32(bytes + 32u, text_quad_count);
}

static void test_write_wasm_ui_scene_packet(UINT8* bytes, UINT32 len) {
  UINT32 rect_offset = ER_WASM_UI_COMMAND_LIST_HEADER_LEN;
  UINT32 hit_offset = rect_offset + ER_WASM_UI_RECT_RECORD_LEN;
  UINT32 quad_offset = hit_offset + ER_WASM_UI_HIT_RECORD_LEN;

  er_mem_zero(bytes, (UINTN)len);
  test_write_wasm_ui_header(bytes, 3u, 1u, 1u, 1u);

  test_put_le32(bytes + rect_offset + 0u, 0x41200000u);
  test_put_le32(bytes + rect_offset + 4u, 0x41a00000u);
  test_put_le32(bytes + rect_offset + 8u, 0x42f00000u);
  test_put_le32(bytes + rect_offset + 12u, 0x42480000u);
  test_put_le32(bytes + rect_offset + 16u, 0x41000000u);
  test_put_le32(bytes + rect_offset + 20u, 0x3e800000u);
  test_put_le32(bytes + rect_offset + 24u, 0x3f000000u);
  test_put_le32(bytes + rect_offset + 28u, 0x3f400000u);
  test_put_le32(bytes + rect_offset + 32u, 0x3f800000u);
  test_put_le32(bytes + rect_offset + 36u, 0x3e800000u);
  test_put_le32(bytes + rect_offset + 40u, 0x3f000000u);
  test_put_le32(bytes + rect_offset + 44u, 0x3f400000u);
  test_put_le32(bytes + rect_offset + 48u, 0x3f800000u);
  test_put_le32(bytes + rect_offset + 52u, 0u);
  test_put_le32(bytes + rect_offset + 56u, 0u);

  test_put_le32(bytes + hit_offset + 0u, 3u);
  test_put_le32(bytes + hit_offset + 4u, 7u);
  test_put_le32(bytes + hit_offset + 8u, 0x41200000u);
  test_put_le32(bytes + hit_offset + 12u, 0x41a00000u);
  test_put_le32(bytes + hit_offset + 16u, 0x42f00000u);
  test_put_le32(bytes + hit_offset + 20u, 0x42480000u);

  test_put_le32(bytes + quad_offset + 0u, 0x41300000u);
  test_put_le32(bytes + quad_offset + 4u, 0x41b00000u);
  test_put_le32(bytes + quad_offset + 8u, 0x41800000u);
  test_put_le32(bytes + quad_offset + 12u, 0x41800000u);
  test_put_le32(bytes + quad_offset + 16u, 0u);
  test_put_le32(bytes + quad_offset + 20u, 0u);
  test_put_le32(bytes + quad_offset + 24u, 0x3f800000u);
  test_put_le32(bytes + quad_offset + 28u, 0x3f800000u);
  test_put_le32(bytes + quad_offset + 32u, 2u);
  test_put_le32(bytes + quad_offset + 36u, 0x3f800000u);
  test_put_le32(bytes + quad_offset + 40u, 0x3f800000u);
  test_put_le32(bytes + quad_offset + 44u, 0x3f800000u);
  test_put_le32(bytes + quad_offset + 48u, 0x3f800000u);
}

static void test_prepare_wasm_ui_presentation(ErAppUiPresentation* presentation) {
  er_mem_zero((UINT8*)presentation, (UINTN)sizeof(*presentation));
  presentation->abi_version = ER_APP_ABI_VERSION;
  test_fill_bytes(presentation->presentation_id.bytes, ER_HASH_LEN, 0x10u);
  test_fill_bytes(presentation->jurisdiction_id.bytes, ER_HASH_LEN, 0x30u);
  test_fill_bytes(presentation->admission_id.bytes, ER_HASH_LEN, 0x50u);
  test_fill_bytes(presentation->app_node_id.bytes, ER_NODE_ID_LEN, 0x70u);
  test_fill_bytes(presentation->ui_relay_node_id.bytes, ER_NODE_ID_LEN, 0x90u);
  test_fill_bytes(presentation->route_hash.bytes, ER_HASH_LEN, 0xb0u);
  presentation->sequence = 1u;
  presentation->max_rects = 1u;
  presentation->max_hits = 1u;
  presentation->max_text_quads = 1u;
}

static void test_wasm_ui_command_stats_records(void) {
  UINT8 bytes[ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
              ER_WASM_UI_RECT_RECORD_LEN +
              ER_WASM_UI_HIT_RECORD_LEN +
              ER_WASM_UI_QUAD_RECORD_LEN];
  er_ui_scene_t scene;
  er_ui_scene_stats_t stats;
  UINT32 rect_offset = ER_WASM_UI_COMMAND_LIST_HEADER_LEN;
  UINT32 hit_offset = rect_offset + ER_WASM_UI_RECT_RECORD_LEN;
  UINT32 quad_offset = hit_offset + ER_WASM_UI_HIT_RECORD_LEN;

  test_write_wasm_ui_scene_packet(bytes, (UINT32)sizeof(bytes));
  check_int64("wasm ui scene packet validates",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), 0);
  check_uint64("wasm ui scene packet rect stats", stats.rects, 1u);
  check_uint64("wasm ui scene packet hit stats", stats.hits, 1u);
  check_uint64("wasm ui scene packet text stats", stats.text_quads, 1u);
  check_int64("wasm ui decode scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("wasm ui scene packet decodes",
              er_wasm_ui_command_decode(bytes, (UINT32)sizeof(bytes), &scene, &stats), 0);
  check_uint64("wasm ui decoded rect count", scene.rect_count, 1u);
  check_uint64("wasm ui decoded hit count", scene.hit_count, 1u);
  check_uint64("wasm ui decoded text count", scene.text_quad_count, 1u);
  check_int64("wasm ui decoded rect mode", scene.rects[0].mode, ER_UI_RECT_FILL);
  check_int64("wasm ui decoded hit kind", scene.hits[0].kind, ER_UI_HIT_BUTTON);
  check_uint64("wasm ui decoded hit id", scene.hits[0].id, 7u);
  check_uint64("wasm ui decoded text atlas", scene.text_quads[0].atlas_id, 2u);
  er_ui_scene_destroy(&scene);

  check_int64("wasm ui scene rejects short packet",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes) - 1u, &stats), -1);

  test_put_le32(bytes + rect_offset + 52u, 4u);
  check_int64("wasm ui scene rejects rect mode",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), -1);
  test_put_le32(bytes + rect_offset + 52u, 0u);

  test_put_le32(bytes + hit_offset, 25u);
  check_int64("wasm ui scene rejects hit kind",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), -1);
  test_put_le32(bytes + hit_offset, 3u);

  test_put_le32(bytes + quad_offset, 0x7f800000u);
  check_int64("wasm ui scene rejects infinite float",
              er_wasm_ui_command_stats(bytes, (UINT32)sizeof(bytes), &stats), -1);
}

static void test_bar_decode(void) {
  ErPciBarInfo none = er_pci_decode_bar(0u, 0u);
  ErPciBarInfo io = er_pci_decode_bar(0x0000c001u, 0u);
  ErPciBarInfo mmio32 = er_pci_decode_bar(0xfebc0008u, 0u);
  ErPciBarInfo mmio64 = er_pci_decode_bar(0x0000000cu, 0x00000002u);
  ErPciBarInfo reserved = er_pci_decode_bar(0x00000002u, 0u);
  UINT32 bars_io_then_mmio[ER_PCI_BAR_COUNT] = {0x0000c001u, 0xfebc0000u, 0u, 0u, 0u, 0u};
  UINT32 bars_mmio64[ER_PCI_BAR_COUNT] = {0x0000000cu, 0x00000002u, 0xfebc0000u, 0u, 0u, 0u};
  UINT32 bars_none[ER_PCI_BAR_COUNT] = {0u, 0u, 0u, 0u, 0u, 0u};
  ErPciBarInfo at_invalid = er_pci_decode_bar_at(bars_io_then_mmio, ER_PCI_BAR_COUNT);
  ErPciBarInfo at_mmio = er_pci_decode_bar_at(bars_io_then_mmio, 1u);
  ErPciBarSelection select_none = er_pci_select_first_mmio_bar(bars_none);
  ErPciBarSelection select_null = er_pci_select_first_mmio_bar(0);
  ErPciBarSelection select_mmio32 = er_pci_select_first_mmio_bar(bars_io_then_mmio);
  ErPciBarSelection select_mmio64 = er_pci_select_first_mmio_bar(bars_mmio64);

  check_int64("bar none kind", none.kind, ER_PCI_BAR_KIND_NONE);
  check_uint64("bar none base", none.base, 0u);

  check_int64("bar io kind", io.kind, ER_PCI_BAR_KIND_IO);
  check_uint64("bar io base", io.base, 0x0000c000u);

  check_int64("bar mmio32 kind", mmio32.kind, ER_PCI_BAR_KIND_MMIO32);
  check_uint64("bar mmio32 base", mmio32.base, 0xfebc0000u);
  check_int64("bar mmio32 prefetch", mmio32.prefetchable, 1);

  check_int64("bar mmio64 kind", mmio64.kind, ER_PCI_BAR_KIND_MMIO64);
  check_uint64("bar mmio64 base", mmio64.base, 0x0000000200000000ull);
  check_int64("bar mmio64 prefetch", mmio64.prefetchable, 1);

  check_int64("bar reserved kind", reserved.kind, ER_PCI_BAR_KIND_NONE);

  check_int64("bar at invalid kind", at_invalid.kind, ER_PCI_BAR_KIND_NONE);
  check_int64("bar at mmio kind", at_mmio.kind, ER_PCI_BAR_KIND_MMIO32);
  check_uint64("bar at mmio base", at_mmio.base, 0xfebc0000u);

  check_int64("bar select none found", select_none.found, 0);
  check_int64("bar select none index", select_none.index, ER_PCI_BAR_INVALID_INDEX);
  check_int64("bar select null found", select_null.found, 0);
  check_int64("bar select mmio32 found", select_mmio32.found, 1);
  check_int64("bar select mmio32 index", select_mmio32.index, 1);
  check_int64("bar select mmio32 kind", select_mmio32.info.kind, ER_PCI_BAR_KIND_MMIO32);
  check_uint64("bar select mmio32 base", select_mmio32.info.base, 0xfebc0000u);
  check_int64("bar select mmio64 found", select_mmio64.found, 1);
  check_int64("bar select mmio64 index", select_mmio64.index, 0);
  check_int64("bar select mmio64 kind", select_mmio64.info.kind, ER_PCI_BAR_KIND_MMIO64);
  check_uint64("bar select mmio64 base", select_mmio64.info.base, 0x0000000200000000ull);
}

static void test_pci_config_addressing(void) {
  check_int64("pci access valid base", er_pci_config_access_valid(0, 0, 0, 0), 1);
  check_int64("pci access valid max", er_pci_config_access_valid(255, 31, 7, 252), 1);
  check_int64("pci access reject negative bus", er_pci_config_access_valid(-1, 0, 0, 0), 0);
  check_int64("pci access reject high bus", er_pci_config_access_valid(256, 0, 0, 0), 0);
  check_int64("pci access reject high dev", er_pci_config_access_valid(0, 32, 0, 0), 0);
  check_int64("pci access reject high func", er_pci_config_access_valid(0, 0, 8, 0), 0);
  check_int64("pci access reject high offset", er_pci_config_access_valid(0, 0, 0, 256), 0);
  check_int64("pci access reject unaligned", er_pci_config_access_valid(0, 0, 0, 2), 0);

  check_uint64("pci address base", (UINT64)er_pci_config_address(0, 0, 0, 0), 0x80000000u);
  check_uint64("pci address encoded", (UINT64)er_pci_config_address(2, 3, 4, 0x10), 0x80021c10u);
  check_int64("pci address reject invalid", er_pci_config_address(0, 0, 0, 2), -1);
}

static void test_pci_device_classification(void) {
  ErPciBarInfo none = er_pci_decode_bar(0u, 0u);
  ErPciBarInfo io = er_pci_decode_bar(0x0000c001u, 0u);
  ErPciBarInfo zero_mmio = er_pci_decode_bar(0x00000008u, 0u);
  ErPciBarInfo mmio32 = er_pci_decode_bar(0xfebc0000u, 0u);
  ErPciDeviceSnapshot snapshot;
  UINT32 i;

  snapshot.present = 99;
  snapshot.bus = 99;
  snapshot.dev = 99;
  snapshot.func = 99;
  snapshot.id = 99;
  snapshot.command_status = 99;
  snapshot.class_revision = 99;
  snapshot.header_cacheline = 99;
  for (i = 0; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot.bars[i] = 99;
  }

  check_int64("pci absent ffffffff", er_pci_device_present(0xffffffffu), 0);
  check_int64("pci absent vendor", er_pci_device_present(0x1234ffffu), 0);
  check_int64("pci present", er_pci_device_present(0x1db610deu), 1);
  check_int64("pci vendor", er_pci_vendor_id(0x1db610deu), 0x10de);
  check_int64("pci class", er_pci_class_code(0x030000a1u), 0x03);
  check_int64("pci subclass", er_pci_subclass(0x01080200u), 0x08);
  check_int64("pci header single", er_pci_header_multifunction(0x00000000u), 0);
  check_int64("pci header multi", er_pci_header_multifunction(0x00800000u), 1);
  check_int64("pci bus count", ER_PCI_BUS_COUNT, 256);
  check_int64("pci device count", ER_PCI_DEVICE_COUNT, 32);
  check_int64("pci function count", ER_PCI_FUNCTION_COUNT, 8);
  check_int64("pci single function count", ER_PCI_SINGLE_FUNCTION_COUNT, 1);
  check_int64("pci bar0 offset", ER_PCI_BAR0_OFFSET, 0x10);
  check_int64("pci bar stride", ER_PCI_BAR_STRIDE, 4);
  check_int64("pci function count single", er_pci_function_count(0x00000000u), ER_PCI_SINGLE_FUNCTION_COUNT);
  check_int64("pci function count multi", er_pci_function_count(0x00800000u), ER_PCI_FUNCTION_COUNT);
  check_int64("pci command io disabled", er_pci_command_io_enabled(0u), 0);
  check_int64("pci command io enabled", er_pci_command_io_enabled(ER_PCI_COMMAND_IO_SPACE), 1);
  check_int64("pci command memory disabled", er_pci_command_memory_enabled(0u), 0);
  check_int64("pci command memory enabled", er_pci_command_memory_enabled(ER_PCI_COMMAND_MEMORY_SPACE), 1);
  check_int64("pci command bus master disabled", er_pci_command_bus_master_enabled(0u), 0);
  check_int64("pci command bus master enabled", er_pci_command_bus_master_enabled(ER_PCI_COMMAND_BUS_MASTER), 1);

  check_int64("pci classify none absent", er_pci_classify_target(0xffffffffu, 0x03000000u), ER_PCI_TARGET_KIND_NONE);
  check_int64("pci classify nvidia", er_pci_classify_target(0x1db610deu, 0x03000000u), ER_PCI_TARGET_KIND_NVIDIA);
  check_int64("pci classify nvme", er_pci_classify_target(0x12348086u, 0x01080200u), ER_PCI_TARGET_KIND_NVME);
  check_int64("pci classify ethernet", er_pci_classify_target(0x12348086u, 0x02000000u), ER_PCI_TARGET_KIND_ETHERNET);
  check_int64("pci classify display", er_pci_classify_target(0x12348086u, 0x03000000u), ER_PCI_TARGET_KIND_DISPLAY);
  check_int64("pci classify other", er_pci_classify_target(0x12348086u, 0x0c033000u), ER_PCI_TARGET_KIND_NONE);

  check_int64("pci bar null not mmio", er_pci_bar_is_mmio(0), 0);
  check_int64("pci bar none not mmio", er_pci_bar_is_mmio(&none), 0);
  check_int64("pci bar io not mmio", er_pci_bar_is_mmio(&io), 0);
  check_int64("pci bar zero not mmio", er_pci_bar_is_mmio(&zero_mmio), 0);
  check_int64("pci bar mmio usable", er_pci_bar_is_mmio(&mmio32), 1);

  er_pci_clear_snapshot(0);
  er_pci_clear_snapshot(&snapshot);
  check_int64("pci snapshot clear present", snapshot.present, 0);
  check_uint64("pci snapshot clear bus", snapshot.bus, 0);
  check_uint64("pci snapshot clear dev", snapshot.dev, 0);
  check_uint64("pci snapshot clear func", snapshot.func, 0);
  check_uint64("pci snapshot clear id", snapshot.id, 0xffffffffu);
  check_uint64("pci snapshot clear command", snapshot.command_status, 0xffffffffu);
  check_uint64("pci snapshot clear class", snapshot.class_revision, 0xffffffffu);
  check_uint64("pci snapshot clear header", snapshot.header_cacheline, 0xffffffffu);
  for (i = 0; i < ER_PCI_BAR_COUNT; ++i) {
    check_uint64("pci snapshot clear bar", snapshot.bars[i], 0);
  }
}

static void test_mmio_handles(void) {
  uint32_t regs[2] = {0x11223344u, 0xaabbccddu};
  INT64 handle;
  INT64 handles[ER_MMIO_MAX_MAPS];
  ErMmioInfo info;
  UINT32 i;

  er_mmio_reset();

  info.used = 99;
  info.phys = 99;
  info.len = 99;

  check_int64("mmio map request valid", er_mmio_map_request_valid((INT64)(UINTN)regs, (INT64)sizeof(regs)), 1);
  check_int64("mmio map request reject zero phys", er_mmio_map_request_valid(0, 8), 0);
  check_int64("mmio map request reject zero len", er_mmio_map_request_valid((INT64)(UINTN)regs, 0), 0);
  check_int64("mmio map request reject negative", er_mmio_map_request_valid(-1, 8), 0);
  check_int64("mmio map request reject overflow", er_mmio_map_request_valid(0x7ffffffffffffff0ll, 0x20), 0);
  check_int64("mmio read request reject unmapped", er_mmio_read32_request_valid(1, 0), 0);
  check_int64("mmio info reject null", er_mmio_get_info(1, 0), 0);
  check_int64("mmio info reject unmapped", er_mmio_get_info(1, &info), 0);
  check_int64("mmio info reject clears used", info.used, 0);
  check_uint64("mmio info reject clears phys", info.phys, 0);
  check_uint64("mmio info reject clears len", info.len, 0);

  check_int64("mmio reject zero phys", er_mmio_map(0, 8), -1);
  check_int64("mmio reject zero len", er_mmio_map((INT64)(UINTN)regs, 0), -1);
  check_int64("mmio reject negative phys", er_mmio_map(-16, 0x20), -1);

  handle = er_mmio_map((INT64)(UINTN)regs, (INT64)sizeof(regs));
  check_int64("mmio first handle", handle, 1);
  check_int64("mmio duplicate handle", er_mmio_map((INT64)(UINTN)regs, (INT64)sizeof(regs)), 1);
  check_int64("mmio info mapped", er_mmio_get_info(handle, &info), 1);
  check_int64("mmio info used", info.used, 1);
  check_uint64("mmio info phys", info.phys, (UINT64)(UINTN)regs);
  check_uint64("mmio info len", info.len, (UINT64)sizeof(regs));
  check_int64("mmio read request valid0", er_mmio_read32_request_valid(handle, 0), 1);
  check_int64("mmio read request valid4", er_mmio_read32_request_valid(handle, 4), 1);
  check_int64("mmio read8 request valid1", er_mmio_read8_request_valid(handle, 1), 1);
  check_int64("mmio read16 request valid2", er_mmio_read16_request_valid(handle, 2), 1);
  check_int64("mmio read request reject bad handle", er_mmio_read32_request_valid(2, 0), 0);
  check_int64("mmio read request reject unaligned", er_mmio_read32_request_valid(handle, 2), 0);
  check_int64("mmio read16 request reject unaligned", er_mmio_read16_request_valid(handle, 1), 0);
  check_int64("mmio read request reject out of range", er_mmio_read32_request_valid(handle, 8), 0);
  check_uint64("mmio read8", (UINT64)er_mmio_read8(handle, 1), 0x33u);
  check_uint64("mmio read16", (UINT64)er_mmio_read16(handle, 2), 0x1122u);
  check_uint64("mmio read0", (UINT64)er_mmio_read32(handle, 0), 0x11223344u);
  check_uint64("mmio read4", (UINT64)er_mmio_read32(handle, 4), 0xaabbccddu);
  check_int64("mmio write8", er_mmio_write8(handle, 1, 0x55u), 1);
  check_uint64("mmio write8 value", regs[0], 0x11225544u);
  check_int64("mmio write16", er_mmio_write16(handle, 2, 0x6677u), 1);
  check_uint64("mmio write16 value", regs[0], 0x66775544u);
  check_int64("mmio write4", er_mmio_write32(handle, 4, 0x01020304u), 1);
  check_uint64("mmio write4 value", regs[1], 0x01020304u);
  check_int64("mmio reject bad handle", er_mmio_read32(2, 0), -1);
  check_int64("mmio reject unaligned", er_mmio_read32(handle, 2), -1);
  check_int64("mmio reject out of range", er_mmio_read32(handle, 8), -1);

  er_mmio_reset();
  check_int64("mmio info after reset", er_mmio_get_info(handle, &info), 0);
  //@optimizer-ignore mmio table saturation test must map every slot
  for (i = 0; i < ER_MMIO_MAX_MAPS; ++i) {
    //@optimizer-ignore mmio table saturation test must map every slot
    handles[i] = er_mmio_map((INT64)(UINTN)&regs[0] + (INT64)(i * sizeof(regs)), (INT64)sizeof(regs));
    check_int64("mmio table handle", handles[i], (INT64)(i + 1u));
  }
  check_int64("mmio table full", er_mmio_map((INT64)(UINTN)&regs[0] + 4096, (INT64)sizeof(regs)), -1);
}

static void test_bus_addresses(void) {
  uint32_t regs[2] = {0x11223344u, 0xaabbccddu};
  ErBusAddress pci;
  ErBusAddress mmio;
  ErBusAddress mmio_short;
  ErBusAddress ioport;
  ErBusOp32 op;
  ErBusPacket32 request;
  ErBusPacket32 response;
  ErBusIoPacket io_request;
  ErBusIoPacket io_response;
  UINT32 value = 0;
  UINT8 value8 = 0;
  UINT16 value16 = 0;

  er_mmio_reset();

  check_int64("bus pci address",
              er_bus_prepare_pci_config_address(2u, 3u, 4u, ER_BUS_ACCESS_READ32, &pci),
              1);
  check_int64("bus pci kind", pci.bus_kind, ER_BUS_KIND_PCI_CONFIG);
  check_int64("bus pci supports read", er_bus_address_supports(&pci, ER_BUS_ACCESS_READ32), 1);
  check_int64("bus pci rejects write", er_bus_address_supports(&pci, ER_BUS_ACCESS_WRITE32), 0);
  check_int64("bus pci reject bad dev",
              er_bus_prepare_pci_config_address(0u, 32u, 0u, ER_BUS_ACCESS_READ32, &pci),
              0);

  check_int64("bus mmio address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)regs, (UINT64)sizeof(regs), 0u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL, &mmio),
              1);
  check_int64("bus mmio kind", mmio.bus_kind, ER_BUS_KIND_MMIO32);
  check_int64("bus mmio supports read", er_bus_address_supports(&mmio, ER_BUS_ACCESS_READ32), 1);
  check_int64("bus mmio supports write", er_bus_address_supports(&mmio, ER_BUS_ACCESS_WRITE32), 1);
  check_int64("bus mmio supports read8", er_bus_address_supports(&mmio, ER_BUS_ACCESS_READ8), 1);
  check_int64("bus mmio reject short",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)regs, 1u, 0u, ER_BUS_ACCESS_READ8, &mmio_short),
              1);

  check_int64("bus io port address",
              er_bus_prepare_io_port_address(0x0cf8u, ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL, &ioport),
              1);
  check_int64("bus io port kind", ioport.bus_kind, ER_BUS_KIND_IO_PORT);
  check_uint64("bus io port number", ioport.port, 0x0cf8u);
  check_int64("bus io port byte address",
              er_bus_prepare_io_port_address(0x0cf9u, ER_BUS_ACCESS_READ8, &ioport),
              1);
  check_int64("bus io port high byte address",
              er_bus_prepare_io_port_address(0xffffu, ER_BUS_ACCESS_READ8, &ioport),
              1);
  check_int64("bus io port reject high",
              er_bus_prepare_io_port_address(0x10000u, ER_BUS_ACCESS_READ8, &ioport),
              0);

  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = ER_BUS_KIND_MMIO32;
  op.access = ER_BUS_ACCESS_READ32;
  op.address = mmio;
  op.offset = 4u;
  op.value = 0;
  check_int64("bus op valid", er_bus_op32_valid(&op), 1);
  op.offset = 2u;
  check_int64("bus op reject unaligned", er_bus_op32_valid(&op), 0);
  op.offset = 8u;
  check_int64("bus op reject out of range", er_bus_op32_valid(&op), 0);

  check_int64("bus mmio read", er_bus_read32(&mmio, 0u, &value), 1);
  check_uint64("bus mmio read value", value, 0x11223344u);
  check_int64("bus mmio read8", er_bus_read8(&mmio, 1u, &value8), 1);
  check_uint64("bus mmio read8 value", value8, 0x33u);
  check_int64("bus mmio read16", er_bus_read16(&mmio, 2u, &value16), 1);
  check_uint64("bus mmio read16 value", value16, 0x1122u);
  check_int64("bus mmio write8", er_bus_write8(&mmio, 1u, 0x55u), 1);
  check_uint64("bus mmio write8 value", regs[0], 0x11225544u);
  check_int64("bus mmio write16", er_bus_write16(&mmio, 2u, 0x6677u), 1);
  check_uint64("bus mmio write16 value", regs[0], 0x66775544u);
  check_int64("bus mmio write", er_bus_write32(&mmio, 4u, 0x55667788u), 1);
  check_uint64("bus mmio write value", regs[1], 0x55667788u);

  mmio.access_flags = ER_BUS_ACCESS_READ_ALL;
  check_int64("bus mmio write denied", er_bus_write32(&mmio, 4u, 0x99u), 0);

  check_int64("bus packet read prepare",
              er_bus_prepare_op32_packet(7u, &mmio, ER_BUS_ACCESS_READ32, 0u, 0u, &request),
              1);
  check_int64("bus packet kind", request.packet_kind, ER_BUS_PACKET_OP32_REQUEST);
  check_uint64("bus packet id", request.packet_id, 7u);
  check_int64("bus packet execute read", er_bus_execute_op32_packet(&request, &response), 1);
  check_int64("bus packet response kind", response.packet_kind, ER_BUS_PACKET_OP32_RESPONSE);
  check_int64("bus packet response ok", response.status, ER_BUS_STATUS_OK);
  check_uint64("bus packet response copies packet id", response.packet_id, 7u);
  check_uint64("bus packet response copies address base", response.op.address.base, mmio.base);
  check_uint64("bus packet response copies address len", response.op.address.len, mmio.len);
  check_uint64("bus packet response copies offset", response.op.offset, 0u);
  check_uint64("bus packet response value", response.result, 0x66775544u);

  mmio.access_flags = ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL;
  check_int64("bus packet write prepare",
              er_bus_prepare_op32_packet(8u, &mmio, ER_BUS_ACCESS_WRITE32, 4u, 0x01010101u, &request),
              1);
  check_int64("bus packet execute write", er_bus_execute_op32_packet(&request, &response), 1);
  check_uint64("bus packet write value", regs[1], 0x01010101u);

  check_int64("bus packet reject invalid",
              er_bus_prepare_op32_packet(9u, &mmio, ER_BUS_ACCESS_READ32, 2u, 0u, &request),
              0);
  check_int64("bus io packet read8 prepare",
              er_bus_prepare_io_packet(10u, &mmio, ER_BUS_ACCESS_READ8, 1u, 1u, 0u, &io_request),
              1);
  check_int64("bus io packet read8 valid", er_bus_io_op_valid(&io_request.op), 1);
  check_int64("bus io packet read8 execute", er_bus_execute_io_packet(&io_request, &io_response), 1);
  check_int64("bus io packet response kind", io_response.packet_kind, ER_BUS_PACKET_IO_RESPONSE);
  check_uint64("bus io packet response copies packet id", io_response.packet_id, 10u);
  check_uint64("bus io packet response copies width", io_response.op.width, 1u);
  check_uint64("bus io packet response copies address base", io_response.op.address.base, mmio.base);
  check_uint64("bus io packet response copies offset", io_response.op.offset, 1u);
  check_uint64("bus io packet read8 result", io_response.result, 0x55u);
  check_int64("bus io packet reject width access mismatch",
              er_bus_prepare_io_packet(11u, &mmio, ER_BUS_ACCESS_READ16, 1u, 1u, 0u, &io_request),
              0);
}

static void test_virtio_mmio_transport(void) {
  enum {
    VIRTIO_TEST_MMIO_DWORDS = 128u,
    VIRTIO_TEST_QUEUE_INDEX = 3u,
    VIRTIO_TEST_QUEUE_MAX = 8u,
    VIRTIO_TEST_DESC_ADDR = 0x1122334455667788ull,
    VIRTIO_TEST_DRIVER_ADDR = 0x2233445566778899ull,
    VIRTIO_TEST_DEVICE_ADDR = 0x33445566778899aau,
    VIRTIO_TEST_INTERRUPT_STATUS = 3u
  };
  UINT32 regs[VIRTIO_TEST_MMIO_DWORDS] = {0};
  ErVirtioMmioTransport transport;
  ErVirtioMmioTransport rejected_transport;
  ErVirtioFeatureSet features;
  UINT16 queue_size = 0;
  UINT8 interrupt_status = 0;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_TEST_QUEUE_MAX;
  regs[ER_VIRTIO_MMIO_INTERRUPT_STATUS_OFFSET / sizeof(UINT32)] = VIRTIO_TEST_INTERRUPT_STATUS;

  check_int64("virtio mmio init",
              er_virtio_mmio_transport_init((UINT64)(UINTN)regs, (UINT64)sizeof(regs),
                                            ER_VIRTIO_DEVICE_TYPE_NET, &transport),
              1);
  check_uint64("virtio mmio device type", transport.device_type, ER_VIRTIO_DEVICE_TYPE_NET);
  check_int64("virtio mmio reject wrong type",
              er_virtio_mmio_transport_init((UINT64)(UINTN)regs, (UINT64)sizeof(regs),
                                            ER_VIRTIO_DEVICE_TYPE_BLK, &rejected_transport),
              0);
  check_int64("virtio mmio negotiate",
              er_virtio_mmio_negotiate_features(&transport, ER_VIRTIO_F_VERSION_1 | 1u, &features),
              1);
  check_uint64("virtio mmio host features", features.host, ER_VIRTIO_F_VERSION_1 | 1u);
  check_uint64("virtio mmio driver features", features.driver, ER_VIRTIO_F_VERSION_1 | 1u);
  check_uint64("virtio mmio status features ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER | ER_VIRTIO_STATUS_FEATURES_OK);
  check_uint64("virtio mmio driver feature selector",
               regs[ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET / sizeof(UINT32)],
               1u);
  check_uint64("virtio mmio driver feature high",
               regs[ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET / sizeof(UINT32)],
               1u);

  check_int64("virtio mmio configure queue",
              er_virtio_mmio_configure_split_queue(&transport, VIRTIO_TEST_QUEUE_INDEX,
                                                   ER_VIRTIO_QUEUE_SIZE, 1u,
                                                   VIRTIO_TEST_DESC_ADDR, VIRTIO_TEST_DRIVER_ADDR,
                                                   VIRTIO_TEST_DEVICE_ADDR, &queue_size),
              1);
  check_uint64("virtio mmio queue size", queue_size, VIRTIO_TEST_QUEUE_MAX);
  check_uint64("virtio mmio queue select",
               regs[ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET / sizeof(UINT32)], VIRTIO_TEST_QUEUE_INDEX);
  check_uint64("virtio mmio queue desc low",
               regs[ER_VIRTIO_MMIO_QUEUE_DESC_LOW_OFFSET / sizeof(UINT32)],
               (UINT32)VIRTIO_TEST_DESC_ADDR);
  check_uint64("virtio mmio queue desc high",
               regs[ER_VIRTIO_MMIO_QUEUE_DESC_HIGH_OFFSET / sizeof(UINT32)],
               (UINT32)(VIRTIO_TEST_DESC_ADDR >> 32));
  check_uint64("virtio mmio queue driver low",
               regs[ER_VIRTIO_MMIO_QUEUE_DRIVER_LOW_OFFSET / sizeof(UINT32)],
               (UINT32)VIRTIO_TEST_DRIVER_ADDR);
  check_uint64("virtio mmio queue device high",
               regs[ER_VIRTIO_MMIO_QUEUE_DEVICE_HIGH_OFFSET / sizeof(UINT32)],
               (UINT32)(VIRTIO_TEST_DEVICE_ADDR >> 32));
  check_uint64("virtio mmio queue ready",
               regs[ER_VIRTIO_MMIO_QUEUE_READY_OFFSET / sizeof(UINT32)], 1u);
  check_int64("virtio mmio notify", er_virtio_mmio_notify_queue(&transport, VIRTIO_TEST_QUEUE_INDEX), 1);
  check_uint64("virtio mmio notify value",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], VIRTIO_TEST_QUEUE_INDEX);
  check_int64("virtio mmio interrupt",
              er_virtio_mmio_take_interrupt_status(&transport, &interrupt_status), 1);
  check_uint64("virtio mmio interrupt value", interrupt_status, VIRTIO_TEST_INTERRUPT_STATUS);
  check_uint64("virtio mmio interrupt ack",
               regs[ER_VIRTIO_MMIO_INTERRUPT_ACK_OFFSET / sizeof(UINT32)], VIRTIO_TEST_INTERRUPT_STATUS);
}

static void test_virtio_modern_pci_transport_registers(void) {
  enum {
    VIRTIO_PCI_TEST_QUEUE_INDEX = 2u,
    VIRTIO_PCI_TEST_QUEUE_MAX = 8u,
    VIRTIO_PCI_TEST_QUEUE_NOTIFY_OFF = 3u,
    VIRTIO_PCI_TEST_NOTIFY_MULT = 4u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_SELECT_OFFSET = 22u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_SIZE_OFFSET = 24u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_ENABLE_OFFSET = 28u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_NOTIFY_OFF_OFFSET = 30u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_DESC_OFFSET = 32u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_DRIVER_OFFSET = 40u,
    VIRTIO_PCI_TEST_COMMON_QUEUE_DEVICE_OFFSET = 48u,
    VIRTIO_PCI_TEST_NOTIFY_OFFSET = VIRTIO_PCI_TEST_QUEUE_NOTIFY_OFF * VIRTIO_PCI_TEST_NOTIFY_MULT,
    VIRTIO_PCI_TEST_DESC_ADDR = 0x1122334455667788ull,
    VIRTIO_PCI_TEST_DRIVER_ADDR = 0x2233445566778899ull,
    VIRTIO_PCI_TEST_DEVICE_ADDR = 0x33445566778899aau
  };
  UINT32 common[32] = {0};
  UINT32 notify[8] = {0};
  UINT32 device[8] = {0};
  UINT32 isr[1] = {0};
  ErVirtioMmioTransport transport;
  UINT16 queue_size = 0;

  er_mem_zero((UINT8*)&transport, (UINTN)sizeof(transport));
  transport.transport_kind = ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI;
  transport.device_type = ER_VIRTIO_DEVICE_TYPE_NET;
  transport.vendor_id = ER_VIRTIO_VENDOR_ID;
  transport.common.present = 1u;
  transport.notify.present = 1u;
  transport.device.present = 1u;
  transport.isr.present = 1u;
  transport.notify.notify_off_multiplier = VIRTIO_PCI_TEST_NOTIFY_MULT;
  check_int64("virtio pci common address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)common, (UINT64)sizeof(common), 0u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.common.address),
              1);
  check_int64("virtio pci notify address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)notify, (UINT64)sizeof(notify), 1u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.notify.address),
              1);
  check_int64("virtio pci device address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)device, (UINT64)sizeof(device), 2u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.device.address),
              1);
  check_int64("virtio pci isr address",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)isr, (UINT64)sizeof(isr), 3u,
                                            ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                            &transport.isr.address),
              1);
  *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_SIZE_OFFSET) = VIRTIO_PCI_TEST_QUEUE_MAX;
  *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_NOTIFY_OFF_OFFSET) = VIRTIO_PCI_TEST_QUEUE_NOTIFY_OFF;

  check_int64("virtio pci configure queue",
              er_virtio_mmio_configure_split_queue(&transport, VIRTIO_PCI_TEST_QUEUE_INDEX,
                                                   ER_VIRTIO_QUEUE_SIZE, 1u,
                                                   VIRTIO_PCI_TEST_DESC_ADDR,
                                                   VIRTIO_PCI_TEST_DRIVER_ADDR,
                                                   VIRTIO_PCI_TEST_DEVICE_ADDR,
                                                   &queue_size),
              1);
  check_uint64("virtio pci queue size", queue_size, VIRTIO_PCI_TEST_QUEUE_MAX);
  check_uint64("virtio pci queue select",
               *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_SELECT_OFFSET),
               VIRTIO_PCI_TEST_QUEUE_INDEX);
  check_uint64("virtio pci queue desc low",
               *(UINT32*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_DESC_OFFSET),
               (UINT32)VIRTIO_PCI_TEST_DESC_ADDR);
  check_uint64("virtio pci queue driver high",
               *(UINT32*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_DRIVER_OFFSET + sizeof(UINT32)),
               (UINT32)(VIRTIO_PCI_TEST_DRIVER_ADDR >> 32));
  check_uint64("virtio pci queue device high",
               *(UINT32*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_DEVICE_OFFSET + sizeof(UINT32)),
               (UINT32)(VIRTIO_PCI_TEST_DEVICE_ADDR >> 32));
  check_uint64("virtio pci queue enabled",
               *(UINT16*)((UINT8*)common + VIRTIO_PCI_TEST_COMMON_QUEUE_ENABLE_OFFSET), 1u);

  check_int64("virtio pci notify", er_virtio_mmio_notify_queue(&transport, VIRTIO_PCI_TEST_QUEUE_INDEX), 1);
  check_uint64("virtio pci notify value",
               *(UINT16*)((UINT8*)notify + VIRTIO_PCI_TEST_NOTIFY_OFFSET), VIRTIO_PCI_TEST_QUEUE_INDEX);
}

static void test_virtio_split_queue(void) {
  ErVirtioQueueDesc desc[ER_VIRTIO_QUEUE_SIZE];
  ErVirtioQueueAvail avail;
  ErVirtioQueueUsed used;
  ErVirtioQueueUsedElem elem;
  UINT16 last_used_idx = 0;

  er_virtio_queue_clear(desc, &avail, &used);
  check_uint64("virtio queue desc clear", desc[0].addr, 0u);
  check_uint64("virtio queue avail clear", avail.idx, 0u);
  check_uint64("virtio queue used clear", used.idx, 0u);
  check_int64("virtio queue post first", er_virtio_queue_post_descriptor(&avail, 4u, 2u), 1);
  check_uint64("virtio queue avail idx first", avail.idx, 1u);
  check_uint64("virtio queue avail ring first", avail.ring[0], 2u);
  check_int64("virtio queue post second", er_virtio_queue_post_descriptor(&avail, 4u, 3u), 1);
  check_uint64("virtio queue avail idx second", avail.idx, 2u);
  check_uint64("virtio queue avail ring second", avail.ring[1], 3u);
  check_int64("virtio queue reject high desc", er_virtio_queue_post_descriptor(&avail, 4u, 4u), 0);

  used.idx = 2u;
  used.ring[0].id = 2u;
  used.ring[0].len = 64u;
  used.ring[1].id = 3u;
  used.ring[1].len = 128u;
  check_int64("virtio queue take first",
              er_virtio_queue_take_next_used(&used, 4u, &last_used_idx, &elem), 1);
  check_uint64("virtio queue used first id", elem.id, 2u);
  check_uint64("virtio queue used first len", elem.len, 64u);
  check_uint64("virtio queue last first", last_used_idx, 1u);
  check_int64("virtio queue take second",
              er_virtio_queue_take_next_used(&used, 4u, &last_used_idx, &elem), 1);
  check_uint64("virtio queue used second id", elem.id, 3u);
  check_uint64("virtio queue used second len", elem.len, 128u);
  check_uint64("virtio queue last second", last_used_idx, 2u);
  check_int64("virtio queue take empty",
              er_virtio_queue_take_next_used(&used, 4u, &last_used_idx, &elem), 0);
}

static void test_virtio_net_mmio(void) {
  enum {
    VIRTIO_NET_TEST_MMIO_DWORDS = 128u,
    VIRTIO_NET_TEST_QUEUE_MAX = ER_VIRTIO_QUEUE_SIZE,
    VIRTIO_NET_TEST_FRAME_LEN = 4u,
    VIRTIO_NET_TEST_RX_DESC = 2u
  };
  UINT32 regs[VIRTIO_NET_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErVirtioNetStats stats;
  ErVirtioQueueDesc* rx_desc;
  ErVirtioQueueAvail* rx_avail;
  ErVirtioQueueUsed* rx_used;
  UINT8* rx_buffer;
  ErVirtioQueueDesc* tx_desc;
  ErVirtioQueueAvail* tx_avail;
  ErVirtioQueueUsed* tx_used;
  UINT8* tx_buffer;
  UINT8 frame[VIRTIO_NET_TEST_FRAME_LEN] = {0xdeu, 0xadu, 0xbeu, 0xefu};
  UINT8 recv_frame[8] = {0};
  UINT32 recv_len = 0;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_NET_TEST_QUEUE_MAX;

  check_int64("virtio net init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  check_int64("virtio net initialized", net.initialized, 1);
  check_int64("virtio net link up default", net.link_up, 1);
  check_uint64("virtio net queue size", net.queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio net features", net.features, ER_VIRTIO_F_VERSION_1);
  check_uint64("virtio net status driver ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER |
               ER_VIRTIO_STATUS_FEATURES_OK | ER_VIRTIO_STATUS_DRIVER_OK);
  check_uint64("virtio net initial notify rx",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], 0u);

  rx_desc = er_virtio_net_test_rx_desc();
  rx_avail = er_virtio_net_test_rx_avail();
  rx_used = er_virtio_net_test_rx_used();
  tx_desc = er_virtio_net_test_tx_desc();
  tx_avail = er_virtio_net_test_tx_avail();
  tx_used = er_virtio_net_test_tx_used();
  check_uint64("virtio net rx avail filled", rx_avail->idx, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio net rx desc write", rx_desc[0].flags, ER_VIRTIO_DESC_F_WRITE);
  check_uint64("virtio net tx avail empty", tx_avail->idx, 0u);

  check_int64("virtio net send", er_virtio_net_send(&net, frame, VIRTIO_NET_TEST_FRAME_LEN), 1);
  tx_buffer = er_virtio_net_test_tx_buffer(0u);
  check_uint64("virtio net tx avail idx", tx_avail->idx, 1u);
  check_uint64("virtio net tx avail desc", tx_avail->ring[0], 0u);
  check_uint64("virtio net tx desc len", tx_desc[0].len, 12u + VIRTIO_NET_TEST_FRAME_LEN);
  check_uint64("virtio net tx desc flags", tx_desc[0].flags, 0u);
  check_uint64("virtio net tx hdr zero", tx_buffer[0], 0u);
  check_uint64("virtio net tx payload0", tx_buffer[12], frame[0]);
  check_uint64("virtio net tx payload3", tx_buffer[15], frame[3]);
  check_uint64("virtio net tx notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], 1u);
  stats = er_virtio_net_stats(&net);
  check_uint64("virtio net tx submitted", stats.tx_submitted, 1u);
  check_uint64("virtio net tx completed before used", stats.tx_completed, 0u);

  tx_used->ring[0].id = 0u;
  tx_used->ring[0].len = 12u + VIRTIO_NET_TEST_FRAME_LEN;
  tx_used->idx = 1u;
  stats = er_virtio_net_stats(&net);
  check_uint64("virtio net tx completed after used", stats.tx_completed, 1u);

  rx_buffer = er_virtio_net_test_rx_buffer(VIRTIO_NET_TEST_RX_DESC);
  rx_buffer[12] = 0x11u;
  rx_buffer[13] = 0x22u;
  rx_buffer[14] = 0x33u;
  rx_used->ring[0].id = VIRTIO_NET_TEST_RX_DESC;
  rx_used->ring[0].len = 15u;
  rx_used->idx = 1u;
  check_int64("virtio net recv",
              er_virtio_net_recv(&net, recv_frame, (UINT32)sizeof(recv_frame), &recv_len),
              1);
  check_uint64("virtio net recv len", recv_len, 3u);
  check_uint64("virtio net recv byte0", recv_frame[0], 0x11u);
  check_uint64("virtio net recv byte2", recv_frame[2], 0x33u);
  check_uint64("virtio net rx repost", rx_avail->idx, ER_VIRTIO_QUEUE_SIZE + 1u);
  check_uint64("virtio net rx notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)], 0u);
  stats = er_virtio_net_stats(&net);
  check_uint64("virtio net rx received", stats.rx_received, 1u);
  check_uint64("virtio net rx invalid", stats.rx_invalid, 0u);
}

static void test_virtio_gpu_mmio(void) {
  enum {
    VIRTIO_GPU_TEST_MMIO_DWORDS = 128u,
    VIRTIO_GPU_TEST_QUEUE_MAX = ER_VIRTIO_QUEUE_SIZE,
    VIRTIO_GPU_TEST_EVENTS_READ = 1u,
    VIRTIO_GPU_TEST_SCANOUTS = 2u,
    VIRTIO_GPU_TEST_CAPSETS = 3u,
    VIRTIO_GPU_TEST_CONTROL_RESPONSE_SIZE = 512u,
    VIRTIO_GPU_TEST_FB_RESOURCE_ID = 9u,
    VIRTIO_GPU_TEST_FB_SCANOUT_ID = 0u,
    VIRTIO_GPU_TEST_FB_WIDTH = 3u,
    VIRTIO_GPU_TEST_FB_HEIGHT = 2u,
    VIRTIO_GPU_TEST_FB_STRIDE = 4u,
    VIRTIO_GPU_TEST_FB_PIXELS = VIRTIO_GPU_TEST_FB_STRIDE * VIRTIO_GPU_TEST_FB_HEIGHT,
    VIRTIO_GPU_TEST_FB_BYTES =
        VIRTIO_GPU_TEST_FB_PIXELS * ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL,
    VIRTIO_GPU_TEST_FB_CLEAR_COLOR = 0x00112233u,
    VIRTIO_GPU_TEST_FB_TOP_COLOR = 0x00445566u,
    VIRTIO_GPU_TEST_FB_BOTTOM_COLOR = 0x00778899u,
    VIRTIO_GPU_TEST_CONFIG_EVENTS_READ_DWORD =
        (ER_VIRTIO_MMIO_CONFIG_OFFSET + 0u) / sizeof(UINT32),
    VIRTIO_GPU_TEST_CONFIG_SCANOUTS_DWORD =
        (ER_VIRTIO_MMIO_CONFIG_OFFSET + 8u) / sizeof(UINT32),
    VIRTIO_GPU_TEST_CONFIG_CAPSETS_DWORD =
        (ER_VIRTIO_MMIO_CONFIG_OFFSET + 12u) / sizeof(UINT32)
  };
  UINT32 regs[VIRTIO_GPU_TEST_MMIO_DWORDS] = {0};
  ErVirtioGpu gpu;
  ErVirtioQueueDesc* control_desc;
  ErVirtioQueueAvail* control_avail;
  ErVirtioQueueUsed* control_used;
  ErVirtioQueueDesc* cursor_desc;
  ErVirtioQueueAvail* cursor_avail;
  ErVirtioQueueUsed* cursor_used;
  UINT8* control_request;
  UINT8* control_response;
  ErVirtioGpuDisplayInfo display_info;
  ErVirtioGpuControlHeader control_header;
  ErVirtioGpuStats gpu_stats;
  ErVirtioGpuFramebuffer framebuffer;
  UINT32 framebuffer_pixels[VIRTIO_GPU_TEST_FB_PIXELS] = {0};
  ErUiSurface ui_surface;
  ErUiSurfaceRenderStats ui_render_stats;
  er_ui_rect_t ui_rects[1];
  er_ui_scene_t ui_scene;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_GPU;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = VIRTIO_GPU_TEST_QUEUE_MAX;
  regs[VIRTIO_GPU_TEST_CONFIG_EVENTS_READ_DWORD] = VIRTIO_GPU_TEST_EVENTS_READ;
  regs[VIRTIO_GPU_TEST_CONFIG_SCANOUTS_DWORD] = VIRTIO_GPU_TEST_SCANOUTS;
  regs[VIRTIO_GPU_TEST_CONFIG_CAPSETS_DWORD] = VIRTIO_GPU_TEST_CAPSETS;

  check_int64("virtio gpu init",
              er_virtio_gpu_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &gpu),
              1);
  check_int64("virtio gpu initialized", gpu.initialized, 1);
  check_uint64("virtio gpu features", gpu.features, ER_VIRTIO_F_VERSION_1);
  check_uint64("virtio gpu control queue size", gpu.control_queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio gpu cursor queue size", gpu.cursor_queue_size, ER_VIRTIO_QUEUE_SIZE);
  check_uint64("virtio gpu events read", gpu.config.events_read, VIRTIO_GPU_TEST_EVENTS_READ);
  check_uint64("virtio gpu scanouts", gpu.config.num_scanouts, VIRTIO_GPU_TEST_SCANOUTS);
  check_uint64("virtio gpu capsets", gpu.config.num_capsets, VIRTIO_GPU_TEST_CAPSETS);
  check_uint64("virtio gpu status driver ok",
               regs[ER_VIRTIO_MMIO_STATUS_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER |
               ER_VIRTIO_STATUS_FEATURES_OK | ER_VIRTIO_STATUS_DRIVER_OK);
  check_uint64("virtio gpu final queue select",
               regs[ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_GPU_CURSOR_QUEUE);
  check_uint64("virtio gpu queue ready",
               regs[ER_VIRTIO_MMIO_QUEUE_READY_OFFSET / sizeof(UINT32)], 1u);

  control_desc = er_virtio_gpu_test_control_desc();
  control_avail = er_virtio_gpu_test_control_avail();
  control_used = er_virtio_gpu_test_control_used();
  cursor_desc = er_virtio_gpu_test_cursor_desc();
  cursor_avail = er_virtio_gpu_test_cursor_avail();
  cursor_used = er_virtio_gpu_test_cursor_used();
  control_request = er_virtio_gpu_test_control_request();
  check_uint64("virtio gpu control desc clear", control_desc[0].addr, 0u);
  check_uint64("virtio gpu control avail clear", control_avail->idx, 0u);
  check_uint64("virtio gpu control used clear", control_used->idx, 0u);
  check_uint64("virtio gpu cursor desc clear", cursor_desc[0].addr, 0u);
  check_uint64("virtio gpu cursor avail clear", cursor_avail->idx, 0u);
  check_uint64("virtio gpu cursor used clear", cursor_used->idx, 0u);

  check_int64("virtio gpu display submit", er_virtio_gpu_submit_get_display_info(&gpu), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu display request type", control_header.type,
               ER_VIRTIO_GPU_CMD_GET_DISPLAY_INFO);
  check_uint64("virtio gpu control avail idx", control_avail->idx, 1u);
  check_uint64("virtio gpu control avail desc", control_avail->ring[0], 0u);
  check_uint64("virtio gpu control request len", control_desc[0].len,
               (UINT32)sizeof(ErVirtioGpuControlHeader));
  check_uint64("virtio gpu control request flags", control_desc[0].flags, ER_VIRTIO_DESC_F_NEXT);
  check_uint64("virtio gpu control request next", control_desc[0].next, 1u);
  check_uint64("virtio gpu control response len", control_desc[1].len,
               VIRTIO_GPU_TEST_CONTROL_RESPONSE_SIZE);
  check_uint64("virtio gpu control response flags", control_desc[1].flags, ER_VIRTIO_DESC_F_WRITE);
  check_uint64("virtio gpu control notify",
               regs[ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET / sizeof(UINT32)],
               ER_VIRTIO_GPU_CONTROL_QUEUE);
  check_int64("virtio gpu display busy rejected", er_virtio_gpu_submit_get_display_info(&gpu), 0);
  gpu_stats = er_virtio_gpu_stats(&gpu);
  check_uint64("virtio gpu submitted", gpu_stats.control_submitted, 1u);
  check_uint64("virtio gpu busy", gpu_stats.control_busy, 1u);

  control_response = er_virtio_gpu_test_control_response();
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  display_info.header.type = ER_VIRTIO_GPU_RESP_OK_DISPLAY_INFO;
  display_info.scanouts[0].rect.width = 800u;
  display_info.scanouts[0].rect.height = 600u;
  display_info.scanouts[0].enabled = 1u;
  er_mem_copy(control_response, (const UINT8*)&display_info, (UINTN)sizeof(display_info));
  control_used->ring[0].id = 0u;
  control_used->ring[0].len = (UINT32)sizeof(display_info);
  control_used->idx = 1u;
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  check_int64("virtio gpu display poll", er_virtio_gpu_poll_display_info(&gpu, &display_info), 1);
  check_uint64("virtio gpu display response type", display_info.header.type,
               ER_VIRTIO_GPU_RESP_OK_DISPLAY_INFO);
  check_uint64("virtio gpu display width", display_info.scanouts[0].rect.width, 800u);
  check_uint64("virtio gpu display height", display_info.scanouts[0].rect.height, 600u);
  check_uint64("virtio gpu display enabled", display_info.scanouts[0].enabled, 1u);
  gpu_stats = er_virtio_gpu_stats(&gpu);
  check_uint64("virtio gpu completed", gpu_stats.control_completed, 1u);

  check_int64("virtio gpu create resource",
              er_virtio_gpu_submit_resource_create_2d(&gpu, 7u,
                                                      ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                                      800u, 600u),
              1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu create request type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_CREATE_2D);
  check_int64("virtio gpu reject create zero resource",
              er_virtio_gpu_submit_resource_create_2d(&gpu, 0u,
                                                      ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                                      800u, 600u),
              0);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[1].id = 0u;
  control_used->ring[1].len = (UINT32)sizeof(control_header);
  control_used->idx = 2u;
  check_int64("virtio gpu create ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu attach backing",
              er_virtio_gpu_submit_resource_attach_backing(&gpu, 7u, 0x1000u, 800u * 600u * 4u),
              1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu attach request type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[2].id = 0u;
  control_used->ring[2].len = (UINT32)sizeof(control_header);
  control_used->idx = 3u;
  check_int64("virtio gpu attach ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu set scanout", er_virtio_gpu_submit_set_scanout(&gpu, 0u, 7u, 800u, 600u), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu scanout request type", control_header.type,
               ER_VIRTIO_GPU_CMD_SET_SCANOUT);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[3].id = 0u;
  control_used->ring[3].len = (UINT32)sizeof(control_header);
  control_used->idx = 4u;
  check_int64("virtio gpu scanout ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu transfer",
              er_virtio_gpu_submit_transfer_to_host_2d(&gpu, 7u, 800u, 600u), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu transfer request type", control_header.type,
               ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[4].id = 0u;
  control_used->ring[4].len = (UINT32)sizeof(control_header);
  control_used->idx = 5u;
  check_int64("virtio gpu transfer ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu flush", er_virtio_gpu_submit_resource_flush(&gpu, 7u, 800u, 600u), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu flush request type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[5].id = 0u;
  control_used->ring[5].len = (UINT32)sizeof(control_header);
  control_used->idx = 6u;
  check_int64("virtio gpu flush ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);

  check_int64("virtio gpu framebuffer init",
              er_virtio_gpu_framebuffer_init(&framebuffer, VIRTIO_GPU_TEST_FB_RESOURCE_ID,
                                             VIRTIO_GPU_TEST_FB_SCANOUT_ID,
                                             ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                             VIRTIO_GPU_TEST_FB_HEIGHT,
                                             VIRTIO_GPU_TEST_FB_STRIDE,
                                             framebuffer_pixels,
                                             VIRTIO_GPU_TEST_FB_PIXELS),
              1);
  check_uint64("virtio gpu framebuffer bytes", framebuffer.byte_len, VIRTIO_GPU_TEST_FB_BYTES);
  check_int64("virtio gpu framebuffer reject stride",
              er_virtio_gpu_framebuffer_init(&framebuffer, VIRTIO_GPU_TEST_FB_RESOURCE_ID,
                                             VIRTIO_GPU_TEST_FB_SCANOUT_ID,
                                             ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                             VIRTIO_GPU_TEST_FB_HEIGHT,
                                             VIRTIO_GPU_TEST_FB_WIDTH - 1u,
                                             framebuffer_pixels,
                                             VIRTIO_GPU_TEST_FB_PIXELS),
              0);
  check_int64("virtio gpu framebuffer reinit",
              er_virtio_gpu_framebuffer_init(&framebuffer, VIRTIO_GPU_TEST_FB_RESOURCE_ID,
                                             VIRTIO_GPU_TEST_FB_SCANOUT_ID,
                                             ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                             VIRTIO_GPU_TEST_FB_WIDTH,
                                             VIRTIO_GPU_TEST_FB_HEIGHT,
                                             VIRTIO_GPU_TEST_FB_STRIDE,
                                             framebuffer_pixels,
                                             VIRTIO_GPU_TEST_FB_PIXELS),
              1);
  er_virtio_gpu_framebuffer_clear(&framebuffer, VIRTIO_GPU_TEST_FB_CLEAR_COLOR);
  check_uint64("virtio gpu framebuffer clear first", framebuffer_pixels[0],
               VIRTIO_GPU_TEST_FB_CLEAR_COLOR);
  check_uint64("virtio gpu framebuffer clear stride gap", framebuffer_pixels[3], 0u);
  check_uint64("virtio gpu framebuffer clear second row", framebuffer_pixels[4],
               VIRTIO_GPU_TEST_FB_CLEAR_COLOR);
  er_virtio_gpu_framebuffer_fill_halves(&framebuffer, VIRTIO_GPU_TEST_FB_TOP_COLOR,
                                        VIRTIO_GPU_TEST_FB_BOTTOM_COLOR);
  check_uint64("virtio gpu framebuffer top", framebuffer_pixels[0],
               VIRTIO_GPU_TEST_FB_TOP_COLOR);
  check_uint64("virtio gpu framebuffer bottom", framebuffer_pixels[4],
               VIRTIO_GPU_TEST_FB_BOTTOM_COLOR);
  er_mem_zero((UINT8*)&ui_scene, (UINTN)sizeof(ui_scene));
  ui_rects[0] = er_ui_rect_fill(0.0f, 0.0f, 2.0f, 1.0f, 0.0f,
                                er_ui_color_rgb_u8(255u, 0u, 0u));
  ui_scene.clear = er_ui_color_rgb_u8(0u, 0u, 0u);
  ui_scene.rects = ui_rects;
  ui_scene.rect_count = 1u;
  ui_scene.rect_capacity = 1u;
  ui_surface.pixels = framebuffer.pixels;
  ui_surface.width = framebuffer.width;
  ui_surface.height = framebuffer.height;
  ui_surface.stride = framebuffer.stride_pixels;
  ui_surface.pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  check_int64("virtio gpu framebuffer surface scene",
              er_ui_surface_render_scene_with_font_stats(&ui_surface, &ui_scene, 0, &ui_render_stats),
              1);
  check_uint64("virtio gpu framebuffer surface bytes", ui_render_stats.bytes_written, 32u);
  check_uint64("virtio gpu framebuffer surface rects", ui_render_stats.rects, 1u);
  check_uint64("virtio gpu framebuffer surface bgrx red", framebuffer_pixels[0], 0x000000ffu);
  check_uint64("virtio gpu framebuffer surface clear", framebuffer_pixels[4], 0u);
  check_int64("virtio gpu framebuffer create",
              er_virtio_gpu_submit_framebuffer_create(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer create type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_CREATE_2D);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[6].id = 0u;
  control_used->ring[6].len = (UINT32)sizeof(control_header);
  control_used->idx = 7u;
  check_int64("virtio gpu framebuffer create ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer attach",
              er_virtio_gpu_submit_framebuffer_attach(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer attach type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[7].id = 0u;
  control_used->ring[7].len = (UINT32)sizeof(control_header);
  control_used->idx = 8u;
  check_int64("virtio gpu framebuffer attach ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer scanout",
              er_virtio_gpu_submit_framebuffer_set_scanout(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer scanout type", control_header.type,
               ER_VIRTIO_GPU_CMD_SET_SCANOUT);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[8].id = 0u;
  control_used->ring[8].len = (UINT32)sizeof(control_header);
  control_used->idx = 9u;
  check_int64("virtio gpu framebuffer scanout ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer transfer",
              er_virtio_gpu_submit_framebuffer_transfer(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer transfer type", control_header.type,
               ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D);
  control_header.type = ER_VIRTIO_GPU_RESP_OK_NODATA;
  er_mem_copy(control_response, (const UINT8*)&control_header, (UINTN)sizeof(control_header));
  control_used->ring[9].id = 0u;
  control_used->ring[9].len = (UINT32)sizeof(control_header);
  control_used->idx = 10u;
  check_int64("virtio gpu framebuffer transfer ok", er_virtio_gpu_poll_ok_nodata(&gpu), 1);
  check_int64("virtio gpu framebuffer flush",
              er_virtio_gpu_submit_framebuffer_flush(&gpu, &framebuffer), 1);
  er_mem_zero((UINT8*)&control_header, (UINTN)sizeof(control_header));
  er_mem_copy((UINT8*)&control_header, control_request, (UINTN)sizeof(control_header));
  check_uint64("virtio gpu framebuffer flush type", control_header.type,
               ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH);
}

static void test_net_frame_builders(void) {
  enum {
    NET_TEST_UDP_PAYLOAD_LEN = 3u,
    NET_TEST_SRC_PORT = 1234u,
    NET_TEST_DST_PORT = 9000u
  };
  UINT8 src_mac[ER_NET_MAC_LEN] = {0x02u, 0x00u, 0x00u, 0x00u, 0x00u, 0x02u};
  UINT8 dst_mac[ER_NET_MAC_LEN] = {0x02u, 0x00u, 0x00u, 0x00u, 0x00u, 0x01u};
  UINT8 src_ip[ER_NET_IPV4_LEN] = {10u, 42u, 0u, 2u};
  UINT8 dst_ip[ER_NET_IPV4_LEN] = {10u, 42u, 0u, 1u};
  UINT8 payload[NET_TEST_UDP_PAYLOAD_LEN] = {'E', 'R', 'W'};
  UINT8 frame[ER_NET_FRAME_MAX] = {0};
  UINT8 eth_payload[NET_TEST_UDP_PAYLOAD_LEN] = {'L', '2', '!'};
  UINT8 parsed_payload[NET_TEST_UDP_PAYLOAD_LEN] = {0};
  UINT8 parsed_src_mac[ER_NET_MAC_LEN] = {0};
  UINT32 frame_len = 0;
  UINT32 parsed_payload_len = 0;
  UINT8 arp[ER_NET_ARP_FRAME_LEN] = {0};
  UINT8 parsed_mac[ER_NET_MAC_LEN] = {0};
  UINT32 arp_len = 0;

  check_int64("net frame udp build",
              er_net_build_ipv4_udp_frame(src_mac, dst_mac, src_ip, dst_ip,
                                          NET_TEST_SRC_PORT, NET_TEST_DST_PORT,
                                          payload, NET_TEST_UDP_PAYLOAD_LEN,
                                          frame, (UINT32)sizeof(frame), &frame_len),
              1);
  check_uint64("net frame udp len", frame_len,
               ER_NET_IPV4_UDP_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame dst mac0", frame[0], dst_mac[0]);
  check_uint64("net frame src mac5", frame[11], src_mac[5]);
  check_uint64("net frame eth ipv4 hi", frame[12], 0x08u);
  check_uint64("net frame eth ipv4 lo", frame[13], 0x00u);
  check_uint64("net frame ipv4 version", frame[14], 0x45u);
  check_uint64("net frame ipv4 total hi", frame[16], 0x00u);
  check_uint64("net frame ipv4 total lo", frame[17],
               ER_NET_IPV4_HEADER_LEN + ER_NET_UDP_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame ipv4 ttl", frame[22], 64u);
  check_uint64("net frame ipv4 proto udp", frame[23], ER_NET_IP_PROTO_UDP);
  check_uint64("net frame ipv4 checksum valid",
               er_net_checksum16(&frame[ER_NET_ETH_HEADER_LEN], ER_NET_IPV4_HEADER_LEN), 0u);
  check_uint64("net frame udp src hi", frame[34], 0x04u);
  check_uint64("net frame udp src lo", frame[35], 0xd2u);
  check_uint64("net frame udp dst hi", frame[36], 0x23u);
  check_uint64("net frame udp dst lo", frame[37], 0x28u);
  check_uint64("net frame udp len lo", frame[39], ER_NET_UDP_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame udp checksum zero", frame[40] | frame[41], 0u);
  check_uint64("net frame payload0", frame[ER_NET_IPV4_UDP_HEADER_LEN], payload[0]);
  check_uint64("net frame payload2", frame[ER_NET_IPV4_UDP_HEADER_LEN + 2u], payload[2]);

  check_int64("net frame eth build",
              er_net_build_eth_frame(src_mac, dst_mac, ER_NET_ETH_TYPE_EDGERUN,
                                     eth_payload, NET_TEST_UDP_PAYLOAD_LEN,
                                     frame, (UINT32)sizeof(frame), &frame_len),
              1);
  check_uint64("net frame eth len", frame_len,
               ER_NET_ETH_HEADER_LEN + NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame edgerun type hi", frame[12], 0x88u);
  check_uint64("net frame edgerun type lo", frame[13], 0xb5u);
  check_int64("net frame eth parse",
              er_net_parse_eth_frame(frame, frame_len, dst_mac,
                                     ER_NET_ETH_TYPE_EDGERUN, parsed_src_mac,
                                     parsed_payload, (UINT32)sizeof(parsed_payload),
                                     &parsed_payload_len),
              1);
  check_uint64("net frame eth parse len", parsed_payload_len, NET_TEST_UDP_PAYLOAD_LEN);
  check_uint64("net frame eth parse src5", parsed_src_mac[5], src_mac[5]);
  check_uint64("net frame eth parse payload2", parsed_payload[2], eth_payload[2]);

  check_int64("net frame arp request",
              er_net_build_arp_request(src_mac, src_ip, dst_ip, arp, (UINT32)sizeof(arp), &arp_len),
              1);
  check_uint64("net frame arp len", arp_len, ER_NET_ARP_FRAME_LEN);
  check_uint64("net frame arp broadcast", arp[0], 0xffu);
  check_uint64("net frame arp eth type hi", arp[12], 0x08u);
  check_uint64("net frame arp eth type lo", arp[13], 0x06u);
  check_uint64("net frame arp op request", arp[21], 0x01u);
  check_uint64("net frame arp source mac5", arp[ER_NET_ETH_HEADER_LEN + 13u], src_mac[5]);
  check_uint64("net frame arp target ip0", arp[ER_NET_ETH_HEADER_LEN + 24u], dst_ip[0]);

  er_mem_copy(arp, dst_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + 6u, src_mac, ER_NET_MAC_LEN);
  arp[21] = 0x02u;
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 8u, dst_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 14u, dst_ip, ER_NET_IPV4_LEN);
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 18u, src_mac, ER_NET_MAC_LEN);
  er_mem_copy(arp + ER_NET_ETH_HEADER_LEN + 24u, src_ip, ER_NET_IPV4_LEN);
  check_int64("net frame arp parse",
              er_net_parse_arp_ipv4_reply(arp, arp_len, dst_ip, src_ip, parsed_mac),
              1);
  check_uint64("net frame arp parsed mac0", parsed_mac[0], dst_mac[0]);
  check_uint64("net frame arp parsed mac5", parsed_mac[5], dst_mac[5]);
}

static void test_native_eth_endpoint(void) {
  enum {
    NATIVE_ETH_TEST_MMIO_DWORDS = 128u,
    NATIVE_ETH_TEST_PAYLOAD_LEN = 4u,
    NATIVE_ETH_TEST_VIRTIO_HDR_LEN = 12u,
    NATIVE_ETH_TEST_TX_DESC = 0u,
    NATIVE_ETH_TEST_RX_DESC = 2u,
    NATIVE_ETH_TEST_RX_REJECT_DESC = 3u
  };
  UINT32 regs[NATIVE_ETH_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth endpoint;
  ErNativeEthStats stats;
  ErVirtioQueueUsed* rx_used;
  UINT8* rx_buffer;
  ErVirtioQueueAvail* tx_avail;
  UINT8* tx_frame;
  UINT8 payload[NATIVE_ETH_TEST_PAYLOAD_LEN] = {'w', 'o', 'r', 'k'};
  UINT8 received[NATIVE_ETH_TEST_PAYLOAD_LEN] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x00u, 0x00u, 0x00u, 0x00u, 0x01u};
  UINT8 reply_payload[NATIVE_ETH_TEST_PAYLOAD_LEN] = {'o', 'k', 'a', 'y'};
  UINT32 received_len = 0u;
  UINT32 frame_len = 0u;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("native eth virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("native eth init",
              er_native_eth_init(&endpoint, &net, peer_mac),
              1);
  check_int64("native eth reject empty send",
              er_native_eth_send(&endpoint, payload, 0u), 0);
  check_int64("native eth send",
              er_native_eth_send(&endpoint, payload, NATIVE_ETH_TEST_PAYLOAD_LEN), 1);
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(NATIVE_ETH_TEST_TX_DESC);
  check_uint64("native eth tx avail", tx_avail->ring[0], NATIVE_ETH_TEST_TX_DESC);
  check_uint64("native eth tx dst mac0",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("native eth tx src mac5",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + 11u], net.mac[ER_NET_MAC_LEN - 1u]);
  check_uint64("native eth tx type hi",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + 12u], 0x88u);
  check_uint64("native eth tx type lo",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + 13u], 0xb5u);
  check_uint64("native eth tx payload0",
               tx_frame[NATIVE_ETH_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN], payload[0]);
  stats = er_native_eth_stats(&endpoint);
  check_uint64("native eth tx stats", stats.tx_frames_sent, 1u);

  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_ETH_TEST_RX_DESC);
  check_int64("native eth build reply",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_EDGERUN,
                                     reply_payload, NATIVE_ETH_TEST_PAYLOAD_LEN,
                                     rx_buffer + NATIVE_ETH_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = NATIVE_ETH_TEST_RX_DESC;
  rx_used->ring[0].len = NATIVE_ETH_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;
  check_int64("native eth recv",
              er_native_eth_recv(&endpoint, received, (UINT32)sizeof(received),
                                 &received_len),
              1);
  check_uint64("native eth recv len", received_len, NATIVE_ETH_TEST_PAYLOAD_LEN);
  check_uint64("native eth recv payload0", received[0], reply_payload[0]);
  check_uint64("native eth recv payload3", received[3], reply_payload[3]);
  stats = er_native_eth_stats(&endpoint);
  check_uint64("native eth rx polled stats", stats.rx_frames_polled, 1u);
  check_uint64("native eth rx accepted stats", stats.rx_frames_accepted, 1u);
  check_uint64("native eth rx rejected stats", stats.rx_frames_rejected, 0u);

  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_ETH_TEST_RX_REJECT_DESC);
  check_int64("native eth build rejected frame",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_IPV4,
                                     reply_payload, NATIVE_ETH_TEST_PAYLOAD_LEN,
                                     rx_buffer + NATIVE_ETH_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[1].id = NATIVE_ETH_TEST_RX_REJECT_DESC;
  rx_used->ring[1].len = NATIVE_ETH_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 2u;
  check_int64("native eth reject non edgerun",
              er_native_eth_recv(&endpoint, received, (UINT32)sizeof(received),
                                 &received_len),
              0);
  stats = er_native_eth_stats(&endpoint);
  check_uint64("native eth rejected stats", stats.rx_frames_rejected, 1u);
}

static void test_acpi_tables(void) {
  static UINT8 rsdp[36];
  static UINT8 xsdt[68];
  static UINT8 fadt[132];
  static UINT8 madt[74];
  static UINT8 mcfg[60];
  static UINT8 hpet[56];
  EFI_CONFIGURATION_TABLE config[1];
  EFI_SYSTEM_TABLE st;
  ErAcpiRsdpInfo rsdp_info;
  ErAcpiTableList table_list;
  ErAcpiTableInfo found_table;
  ErAcpiFadtInfo fadt_info;
  ErAcpiMadtInfo madt_info;
  ErAcpiMcfgInfo mcfg_info;
  ErAcpiHpetInfo hpet_info;
  UINT64 ecam_address = 0;
  EFI_GUID acpi20 = {
    0x8868e871u, 0xe4f1u, 0x11d3u, {0xbcu, 0x22u, 0x00u, 0x80u, 0xc7u, 0x3cu, 0x88u, 0x81u}
  };

  test_put_le64(&rsdp[0], 0x2052545020445352ull);
  rsdp[9] = 'E';
  rsdp[10] = 'D';
  rsdp[11] = 'G';
  rsdp[12] = 'E';
  rsdp[13] = 'R';
  rsdp[14] = 'N';
  rsdp[15] = 2;
  test_put_le32(&rsdp[16], 0u);
  test_put_le32(&rsdp[20], (UINT32)sizeof(rsdp));
  test_put_le64(&rsdp[24], (UINT64)(UINTN)xsdt);
  test_acpi_set_checksum(rsdp, 20u, 8u);
  test_acpi_set_checksum(rsdp, (UINTN)sizeof(rsdp), 32u);

  test_put_le32(&xsdt[0], er_acpi_signature("XSDT"));
  test_put_le32(&xsdt[4], (UINT32)sizeof(xsdt));
  xsdt[8] = 1;
  test_put_le64(&xsdt[36], (UINT64)(UINTN)fadt);
  test_put_le64(&xsdt[44], (UINT64)(UINTN)madt);
  test_put_le64(&xsdt[52], (UINT64)(UINTN)mcfg);
  test_put_le64(&xsdt[60], (UINT64)(UINTN)hpet);
  test_acpi_set_checksum(xsdt, (UINTN)sizeof(xsdt), 9u);

  test_put_le32(&fadt[0], er_acpi_signature("FACP"));
  test_put_le32(&fadt[4], (UINT32)sizeof(fadt));
  fadt[8] = 6;
  fadt[46] = 9;
  fadt[47] = 0;
  test_put_le32(&fadt[48], 0x000000b2u);
  fadt[52] = 0xa0u;
  fadt[53] = 0xa1u;
  test_put_le32(&fadt[56], 0x00000400u);
  test_put_le32(&fadt[60], 0x00000500u);
  test_put_le32(&fadt[64], 0x00000404u);
  test_put_le32(&fadt[68], 0x00000504u);
  test_put_le32(&fadt[76], 0x00000408u);
  fadt[88] = 4;
  fadt[89] = 2;
  fadt[91] = 4;
  fadt[109] = 0x03u;
  fadt[110] = 0x00u;
  test_put_le32(&fadt[112], 0x00000001u);
  fadt[116] = 1;
  fadt[117] = 8;
  fadt[118] = 0;
  fadt[119] = 1;
  test_put_le64(&fadt[120], 0x0000000000000cf9ull);
  fadt[128] = 0x06u;
  test_acpi_set_checksum(fadt, (UINTN)sizeof(fadt), 9u);

  test_put_le32(&madt[0], er_acpi_signature("APIC"));
  test_put_le32(&madt[4], (UINT32)sizeof(madt));
  madt[8] = 5;
  test_put_le32(&madt[36], 0xfee00000u);
  test_put_le32(&madt[40], 1u);
  madt[44] = ER_ACPI_MADT_ENTRY_LAPIC;
  madt[45] = 8;
  madt[46] = 2;
  madt[47] = 3;
  test_put_le32(&madt[48], ER_ACPI_MADT_LAPIC_ENABLED);
  madt[52] = ER_ACPI_MADT_ENTRY_IOAPIC;
  madt[53] = 12;
  madt[54] = 4;
  test_put_le32(&madt[56], 0xfec00000u);
  test_put_le32(&madt[60], 0u);
  madt[64] = ER_ACPI_MADT_ENTRY_INTERRUPT_SOURCE_OVERRIDE;
  madt[65] = 10;
  madt[66] = 0;
  madt[67] = 1;
  test_put_le32(&madt[68], 9u);
  madt[72] = 0x0du;
  madt[73] = 0;
  test_acpi_set_checksum(madt, (UINTN)sizeof(madt), 9u);

  test_put_le32(&mcfg[0], er_acpi_signature("MCFG"));
  test_put_le32(&mcfg[4], (UINT32)sizeof(mcfg));
  mcfg[8] = 1;
  test_put_le64(&mcfg[44], 0xe0000000ull);
  mcfg[52] = 0;
  mcfg[53] = 0;
  mcfg[54] = 0;
  mcfg[55] = 63;
  test_acpi_set_checksum(mcfg, (UINTN)sizeof(mcfg), 9u);

  test_put_le32(&hpet[0], er_acpi_signature("HPET"));
  test_put_le32(&hpet[4], (UINT32)sizeof(hpet));
  hpet[8] = 1;
  test_put_le32(&hpet[36], 0x8086u << 16 | 1u << 13 | 2u << 8 | 0x01u);
  hpet[40] = 0;
  hpet[41] = 64;
  hpet[42] = 0;
  hpet[43] = 3;
  test_put_le64(&hpet[44], 0xfed00000ull);
  hpet[52] = 0;
  hpet[53] = 0x80u;
  hpet[54] = 0x00u;
  hpet[55] = 0;
  test_acpi_set_checksum(hpet, (UINTN)sizeof(hpet), 9u);

  config[0].VendorGuid = acpi20;
  config[0].VendorTable = rsdp;
  st.NumberOfTableEntries = 1;
  st.ConfigurationTable = config;

  check_uint64("acpi sig", er_acpi_signature("XSDT"), 0x54445358u);
  check_int64("acpi checksum ok", er_acpi_checksum_valid(xsdt, (UINTN)sizeof(xsdt)), 1);
  check_int64("acpi find rsdp", er_acpi_find_rsdp(&st, &rsdp_info), 1);
  check_int64("acpi rsdp found", rsdp_info.found, 1);
  check_int64("acpi rsdp revision", rsdp_info.revision, 2);
  check_int64("acpi rsdp checksum", rsdp_info.checksum_valid, 1);
  check_int64("acpi xsdt checksum", rsdp_info.xsdt_checksum_valid, 1);
  check_uint64("acpi xsdt address", rsdp_info.xsdt_address, (UINT64)(UINTN)xsdt);

  check_int64("acpi enumerate", er_acpi_enumerate_tables(&rsdp_info, &table_list), 1);
  check_int64("acpi table list found", table_list.found, 1);
  check_int64("acpi table kind xsdt", table_list.table_kind, ER_ACPI_TABLE_KIND_XSDT);
  check_uint64("acpi table count", table_list.table_count, 4u);
  check_uint64("acpi table sig", table_list.tables[0].signature, er_acpi_signature("FACP"));
  check_uint64("acpi table address", table_list.tables[0].address, (UINT64)(UINTN)fadt);
  check_int64("acpi table checksum", table_list.tables[0].checksum_valid, 1);
  check_int64("acpi find fadt", er_acpi_find_table(&table_list, er_acpi_signature("FACP"), &found_table), 1);
  check_int64("acpi parse fadt", er_acpi_parse_fadt(found_table.address, &fadt_info), 1);
  check_int64("acpi fadt found", fadt_info.found, 1);
  check_int64("acpi fadt checksum", fadt_info.checksum_valid, 1);
  check_uint64("acpi fadt sci", fadt_info.sci_interrupt, 9u);
  check_uint64("acpi fadt smi", fadt_info.smi_command_port, 0xb2u);
  check_uint64("acpi fadt pm timer", fadt_info.pm_timer_block, 0x408u);
  check_uint64("acpi fadt boot arch", fadt_info.boot_architecture_flags, 3u);
  check_uint64("acpi fadt flags", fadt_info.flags, 1u);
  check_uint64("acpi fadt reset space", fadt_info.reset_register.address_space_id, 1u);
  check_uint64("acpi fadt reset addr", fadt_info.reset_register.address, 0xcf9u);
  check_uint64("acpi fadt reset value", fadt_info.reset_value, 0x06u);
  check_int64("acpi find madt", er_acpi_find_table(&table_list, er_acpi_signature("APIC"), &found_table), 1);
  check_uint64("acpi madt address", found_table.address, (UINT64)(UINTN)madt);
  check_int64("acpi parse madt", er_acpi_parse_madt(found_table.address, &madt_info), 1);
  check_int64("acpi madt found", madt_info.found, 1);
  check_int64("acpi madt checksum", madt_info.checksum_valid, 1);
  check_uint64("acpi madt lapic addr", madt_info.lapic_address, 0xfee00000u);
  check_uint64("acpi madt flags", madt_info.flags, 1u);
  check_uint64("acpi madt lapic count", madt_info.lapic_count, 1u);
  check_uint64("acpi madt lapic apic id", madt_info.lapics[0].apic_id, 3u);
  check_uint64("acpi madt ioapic count", madt_info.ioapic_count, 1u);
  check_uint64("acpi madt ioapic addr", madt_info.ioapics[0].address, 0xfec00000u);
  check_uint64("acpi madt iso count", madt_info.interrupt_source_override_count, 1u);
  check_uint64("acpi madt iso gsi", madt_info.interrupt_source_overrides[0].global_system_interrupt, 9u);
  check_uint64("acpi madt iso flags", madt_info.interrupt_source_overrides[0].flags, 0x0du);
  check_int64("acpi find mcfg", er_acpi_find_table(&table_list, er_acpi_signature("MCFG"), &found_table), 1);
  check_uint64("acpi mcfg address", found_table.address, (UINT64)(UINTN)mcfg);
  check_int64("acpi parse mcfg", er_acpi_parse_mcfg(found_table.address, &mcfg_info), 1);
  check_int64("acpi mcfg found", mcfg_info.found, 1);
  check_int64("acpi mcfg checksum", mcfg_info.checksum_valid, 1);
  check_uint64("acpi mcfg count", mcfg_info.allocation_count, 1u);
  check_uint64("acpi mcfg base", mcfg_info.allocations[0].base_address, 0xe0000000ull);
  check_uint64("acpi mcfg end bus", mcfg_info.allocations[0].end_bus, 63u);
  check_int64("acpi mcfg ecam",
              er_acpi_mcfg_config_address(&mcfg_info, 0u, 2u, 3u, 4u, 0x10u, &ecam_address),
              1);
  check_uint64("acpi mcfg ecam address", ecam_address,
               0xe0000000ull + (2ull * 0x100000ull) + (3ull * 0x8000ull) + (4ull * 0x1000ull) + 0x10ull);
  check_int64("acpi mcfg reject bus",
              er_acpi_mcfg_config_address(&mcfg_info, 0u, 64u, 0u, 0u, 0u, &ecam_address),
              0);
  check_int64("acpi find hpet", er_acpi_find_table(&table_list, er_acpi_signature("HPET"), &found_table), 1);
  check_uint64("acpi hpet address", found_table.address, (UINT64)(UINTN)hpet);
  check_int64("acpi parse hpet", er_acpi_parse_hpet(found_table.address, &hpet_info), 1);
  check_int64("acpi hpet found", hpet_info.found, 1);
  check_int64("acpi hpet checksum", hpet_info.checksum_valid, 1);
  check_uint64("acpi hpet rev", hpet_info.hardware_rev_id, 1u);
  check_uint64("acpi hpet timers", hpet_info.comparator_count, 3u);
  check_uint64("acpi hpet bits64", hpet_info.counter_size_64, 1u);
  check_uint64("acpi hpet vendor", hpet_info.pci_vendor_id, 0x8086u);
  check_uint64("acpi hpet mmio", hpet_info.address, 0xfed00000ull);
  check_uint64("acpi hpet min tick", hpet_info.minimum_tick, 0x80u);
  check_int64("acpi find missing", er_acpi_find_table(&table_list, er_acpi_signature("SSDT"), &found_table), 0);

  rsdp_info.checksum_valid = 0;
  check_int64("acpi reject bad rsdp", er_acpi_enumerate_tables(&rsdp_info, &table_list), 0);
}

static void test_tpm_crb_direct_transport(void) {
  static UINT8 tpm2[52];
  static UINT8 crb[4096];
  static UINT8 command_buffer[256];
  static UINT8 response_buffer[256];
  ErTpm2Info info;
  ErTpmCrbTransport transport;
  ErTpmP256Primary primary;
  UINT8 command[128];
  UINT8 response[256];
  UINT8 random[32];
  UINT8 digest[32];
  UINT8 signature[64];
  UINT32 command_len = 0u;
  UINT32 response_len = 0u;
  UINT32 random_len = 0u;
  UINT32 response_body_len;
  UINT32 offset;

  er_mem_zero(tpm2, (UINTN)sizeof(tpm2));
  er_mem_zero(crb, (UINTN)sizeof(crb));
  er_mem_zero(command_buffer, (UINTN)sizeof(command_buffer));
  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  test_fill_bytes(digest, (UINTN)sizeof(digest), 0x31u);

  test_put_le32(&tpm2[0], er_acpi_signature("TPM2"));
  test_put_le32(&tpm2[4], (UINT32)sizeof(tpm2));
  tpm2[8] = 4u;
  test_put_le64(&tpm2[40], (UINT64)(UINTN)crb);
  test_put_le32(&tpm2[48], 6u);
  test_acpi_set_checksum(tpm2, (UINTN)sizeof(tpm2), 9u);

  check_int64("tpm parse tpm2",
              er_tpm_parse_tpm2_table((UINT64)(UINTN)tpm2, &info), 1);
  check_int64("tpm info found", info.found, 1);
  check_int64("tpm info crb", er_tpm2_info_is_crb(&info), 1);
  check_uint64("tpm control area", info.control_area, (UINT64)(UINTN)crb);

  test_put_le32(&crb[0x58], (UINT32)sizeof(command_buffer));
  test_put_le64(&crb[0x5c], (UINT64)(UINTN)command_buffer);
  test_put_le32(&crb[0x64], (UINT32)sizeof(response_buffer));
  test_put_le64(&crb[0x68], (UINT64)(UINTN)response_buffer);
  check_int64("tpm crb from base",
              er_tpm_crb_from_register_base((UINT64)(UINTN)crb, &transport), 1);
  transport.timeout_polls = 0u;
  check_uint64("tpm crb command buffer", transport.command_buffer,
               (UINT64)(UINTN)command_buffer);
  check_uint64("tpm crb response buffer", transport.response_buffer,
               (UINT64)(UINTN)response_buffer);

  check_int64("tpm startup command",
              er_tpm_build_startup_command(ER_TPM_SU_CLEAR, command,
                                           (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm startup command len", command_len, 12u);
  check_uint64("tpm startup tag", command[0], 0x80u);
  check_uint64("tpm startup cc lo", command[9], 0x44u);

  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  response_buffer[2] = 0u;
  response_buffer[3] = 0u;
  response_buffer[4] = 0u;
  response_buffer[5] = 10u;
  response_buffer[6] = 0u;
  response_buffer[7] = 0u;
  response_buffer[8] = 0u;
  response_buffer[9] = 0u;
  check_int64("tpm crb transact",
              er_tpm_crb_transact(&transport, command, command_len,
                                  response, (UINT32)sizeof(response),
                                  &response_len),
              1);
  check_uint64("tpm crb response len", response_len, 10u);
  check_uint64("tpm crb copied command cc", command_buffer[9], 0x44u);
  check_uint64("tpm response code", er_tpm_response_code(response, response_len),
               ER_TPM_RC_SUCCESS);

  check_int64("tpm get random command",
              er_tpm_build_get_random_command(4u, command,
                                              (UINT32)sizeof(command),
                                              &command_len),
              1);
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  response_buffer[2] = 0u;
  response_buffer[3] = 0u;
  response_buffer[4] = 0u;
  response_buffer[5] = 16u;
  response_buffer[6] = 0u;
  response_buffer[7] = 0u;
  response_buffer[8] = 0u;
  response_buffer[9] = 0u;
  response_buffer[10] = 0u;
  response_buffer[11] = 4u;
  response_buffer[12] = 0xaau;
  response_buffer[13] = 0xbbu;
  response_buffer[14] = 0xccu;
  response_buffer[15] = 0xddu;
  check_int64("tpm random transact",
              er_tpm_crb_transact(&transport, command, command_len,
                                  response, (UINT32)sizeof(response),
                                  &response_len),
              1);
  check_int64("tpm parse random",
              er_tpm_parse_get_random_response(response, response_len, random,
                                               (UINT32)sizeof(random), &random_len),
              1);
  check_uint64("tpm random len", random_len, 4u);
  check_uint64("tpm random byte0", random[0], 0xaau);
  check_uint64("tpm random byte3", random[3], 0xddu);

  check_int64("tpm create primary command",
              er_tpm_build_create_primary_p256_signing_command(
                  command, (UINT32)sizeof(command), &command_len),
              1);
  check_uint64("tpm create primary len", command_len, 65u);
  check_uint64("tpm create primary command code", command[9], 0x31u);
  check_uint64("tpm create primary owner", command[13], 0x01u);
  check_uint64("tpm create primary auth bytes", command[17], 9u);
  check_uint64("tpm create primary ecc type", command[35], 0x00u);
  check_uint64("tpm create primary ecc type lo", command[36], 0x23u);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x02u;
  test_put_be32(response_buffer + 2u, 126u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, 0x80000000u);
  test_put_be32(response_buffer + 14u, 90u);
  offset = 18u;
  test_put_be16(response_buffer + offset, 88u);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECC);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_SHA256);
  offset += 2u;
  test_put_be32(response_buffer + offset, 0x00040472u);
  offset += 4u;
  test_put_be16(response_buffer + offset, 0u);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_NULL);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_ECDSA);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_SHA256);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ECC_NIST_P256);
  offset += 2u;
  test_put_be16(response_buffer + offset, ER_TPM_ALG_NULL);
  offset += 2u;
  test_put_be16(response_buffer + offset, 32u);
  offset += 2u;
  test_fill_bytes(response_buffer + offset, 32u, 0x71u);
  offset += 32u;
  test_put_be16(response_buffer + offset, 32u);
  offset += 2u;
  test_fill_bytes(response_buffer + offset, 32u, 0x91u);
  check_int64("tpm parse create primary",
              er_tpm_parse_create_primary_p256_response(response_buffer, 126u,
                                                        &primary),
              1);
  check_uint64("tpm primary handle", primary.handle, 0x80000000u);
  check_uint64("tpm primary public x0", primary.public_key[0], 0x71u);
  check_uint64("tpm primary public y0", primary.public_key[32], 0x91u);

  check_int64("tpm read public command",
              er_tpm_build_read_public_command(0x81000001u, command,
                                               (UINT32)sizeof(command),
                                               &command_len),
              1);
  check_uint64("tpm read public len", command_len, 14u);
  check_uint64("tpm read public handle hi", command[10], 0x81u);

  check_int64("tpm sign command",
              er_tpm_build_sign_p256_sha256_command(0x81000001u, digest,
                                                    command, (UINT32)sizeof(command),
                                                    &command_len),
              1);
  check_uint64("tpm sign command len", command_len, 73u);
  check_uint64("tpm sign tag sessions", command[1], 0x02u);
  check_uint64("tpm sign digest byte0", command[29], digest[0]);

  response_body_len = 4u + 2u + 31u + 2u + 32u;
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x01u;
  response_buffer[2] = 0u;
  response_buffer[3] = 0u;
  response_buffer[4] = 0u;
  response_buffer[5] = (UINT8)(10u + response_body_len);
  response_buffer[6] = 0u;
  response_buffer[7] = 0u;
  response_buffer[8] = 0u;
  response_buffer[9] = 0u;
  response_buffer[10] = 0x00u;
  response_buffer[11] = 0x18u;
  response_buffer[12] = 0x00u;
  response_buffer[13] = 0x0bu;
  response_buffer[14] = 0u;
  response_buffer[15] = 31u;
  test_fill_bytes(response_buffer + 16u, 31u, 0x41u);
  response_buffer[47] = 0u;
  response_buffer[48] = 32u;
  test_fill_bytes(response_buffer + 49u, 32u, 0x61u);
  check_int64("tpm parse signature",
              er_tpm_parse_p256_sha256_signature_response(response_buffer,
                                                          10u + response_body_len,
                                                          signature),
              1);
  check_uint64("tpm signature pads r", signature[0], 0u);
  check_uint64("tpm signature r first", signature[1], 0x41u);
  check_uint64("tpm signature s first", signature[32], 0x61u);

  er_mem_zero(response_buffer, (UINTN)sizeof(response_buffer));
  response_buffer[0] = 0x80u;
  response_buffer[1] = 0x02u;
  test_put_be32(response_buffer + 2u, 10u + 4u + response_body_len + 9u);
  test_put_be32(response_buffer + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response_buffer + 10u, response_body_len);
  response_buffer[14] = 0x00u;
  response_buffer[15] = 0x18u;
  response_buffer[16] = 0x00u;
  response_buffer[17] = 0x0bu;
  response_buffer[18] = 0u;
  response_buffer[19] = 31u;
  test_fill_bytes(response_buffer + 20u, 31u, 0x51u);
  response_buffer[51] = 0u;
  response_buffer[52] = 32u;
  test_fill_bytes(response_buffer + 53u, 32u, 0x71u);
  response_buffer[85] = 0x40u;
  response_buffer[86] = 0x00u;
  response_buffer[87] = 0x00u;
  response_buffer[88] = 0x09u;
  response_buffer[89] = 0u;
  response_buffer[90] = 0u;
  response_buffer[91] = 0u;
  response_buffer[92] = 0u;
  response_buffer[93] = 0u;
  check_int64("tpm parse sessions signature",
              er_tpm_parse_p256_sha256_signature_response(
                  response_buffer, 10u + 4u + response_body_len + 9u, signature),
              1);
  check_uint64("tpm sessions signature pads r", signature[0], 0u);
  check_uint64("tpm sessions signature r first", signature[1], 0x51u);
  check_uint64("tpm sessions signature s first", signature[32], 0x71u);

  check_int64("tpm flush command",
              er_tpm_build_flush_context_command(0x80000000u, command,
                                                 (UINT32)sizeof(command),
                                                 &command_len),
              1);
  check_uint64("tpm flush len", command_len, 14u);
  check_uint64("tpm flush code", command[9], 0x65u);
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

  host.bus_exec = test_vm_bus_exec;
  host.linear_memory = linear_memory;

  check_int64("wasm bus init",
              er_wasm_init(&module, g_edgerun_driver_bus_probe_wasm,
                           ER_DRIVER_BUS_PROBE_WASM_SIZE, &host),
              0);
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
  ErAppBudget budget;
  ErAppUsage usage;
  const UINT8* parsed_payload = 0;
  UINT32 parsed_payload_len = 0u;
  UINT32 packet_len = 0u;

  test_fill_bytes(source.bytes, ER_NODE_ID_LEN, 0x10u);
  test_fill_bytes(target.bytes, ER_NODE_ID_LEN, 0x30u);
  test_fill_bytes(admission.bytes, ER_HASH_LEN, 0x50u);
  test_fill_bytes(token.bytes, ER_HASH_LEN, 0x70u);
  test_fill_bytes(route.bytes, ER_HASH_LEN, 0x90u);
  test_fill_bytes(payload_hash.bytes, ER_HASH_LEN, 0xb0u);
  er_mem_zero((UINT8*)&budget, (UINTN)sizeof(budget));
  er_mem_zero((UINT8*)&usage, (UINTN)sizeof(usage));
  budget.abi_version = ER_APP_ABI_VERSION;
  budget.app_kind = ER_APP_KIND_USER;
  budget.admission_id = admission;
  budget.budget_id = token;
  usage.abi_version = ER_APP_ABI_VERSION;
  usage.budget_id = token;
  usage.app_node_id = source;

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
  check_uint64("relay packet payload len", parsed_payload_len, sizeof(payload));
  check_uint64("relay packet payload byte0", parsed_payload[0], payload[0]);
  check_uint64("relay packet payload byte3", parsed_payload[3], payload[3]);
  check_int64("relay packet authorized",
              er_relay_packet_authorized_for_app(packet, packet_len, &usage, &budget), 1);
  usage.app_node_id.bytes[0] ^= 1u;
  check_int64("relay packet reject source mismatch",
              er_relay_packet_authorized_for_app(packet, packet_len, &usage, &budget), 0);
  usage.app_node_id = source;
  budget.budget_id.bytes[0] ^= 1u;
  check_int64("relay packet reject token mismatch",
              er_relay_packet_authorized_for_app(packet, packet_len, &usage, &budget), 0);
  budget.budget_id = token;

  packet[0] = 0xffu;
  check_int64("relay packet reject abi", er_relay_packet_valid(packet, packet_len), 0);
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
  ErAppBudget budget;
  ErAppUsage usage;
  ErAppUsage charge_probe;
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
  er_mem_zero((UINT8*)&budget, (UINTN)sizeof(budget));
  er_mem_zero((UINT8*)&usage, (UINTN)sizeof(usage));
  budget.abi_version = ER_APP_ABI_VERSION;
  budget.app_kind = ER_APP_KIND_USER;
  budget.admission_id = admission;
  budget.budget_id = token;
  budget.max_packet_bytes = ER_RELAY_PACKET_HEADER_LEN + 4u;
  usage.abi_version = ER_APP_ABI_VERSION;
  usage.budget_id = token;
  usage.app_node_id = source;
  host.app_budget = &budget;
  host.app_usage = &usage;

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
  check_uint64("wasm relay usage charged", usage.packet_bytes, ER_RELAY_PACKET_HEADER_LEN + 4u);

  usage.packet_bytes = 0u;
  budget.max_packet_bytes = ER_RELAY_PACKET_HEADER_LEN + 3u;
  check_int64("wasm relay reject packet over budget",
              er_wasm_execute_i64(&module, main_index, &result), -1);
  check_uint64("wasm relay usage unchanged after over budget", usage.packet_bytes, 0u);
  budget.max_packet_bytes = ER_RELAY_PACKET_HEADER_LEN + 4u;
  usage.app_node_id.bytes[0] ^= 1u;
  check_int64("wasm relay reject packet source mismatch",
              er_wasm_execute_i64(&module, main_index, &result), -1);
  check_uint64("wasm relay usage unchanged after source mismatch", usage.packet_bytes, 0u);
  usage.app_node_id = source;

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
  budget.max_packet_bytes =
      ER_RELAY_PACKET_HEADER_LEN + sizeof(ErCapabilityEnvelopeHeader);
  usage.packet_bytes = 0u;
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
  check_int64("wasm render relay packet authorized",
              er_relay_packet_authorized_for_app(memory + 1024u, packet_len,
                                                 &usage, &budget),
              1);
  charge_probe = usage;
  check_int64("wasm render relay charge probe",
              er_app_usage_charge(&charge_probe, &budget,
                                  ER_APP_BUDGET_PACKET_BYTE, packet_len),
              1);
  check_int64("wasm render relay execute",
              er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm render relay result", (UINT64)result,
               ER_RELAY_PACKET_HEADER_LEN +
               sizeof(ErCapabilityEnvelopeHeader) + 4u);
  check_uint64("wasm render relay usage charged", usage.packet_bytes,
               ER_RELAY_PACKET_HEADER_LEN + sizeof(ErCapabilityEnvelopeHeader));

  check_int64("wasm relay shifted outbox prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 2048u, 2048u,
                                            &linear_memory),
              0);
  host.relay_send = test_vm_relay_send;
  budget.max_packet_bytes = ER_RELAY_PACKET_HEADER_LEN + 4u;
  usage.packet_bytes = 0u;
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
   * Purpose: prove authored WASM apps can emit UI command lists through admission.
   * Intention: the VM validates public outbox bounds and presentation budget before host UI work.
   */
  static UINT8 memory[65536];
  ErWasmHostCalls host = {0};
  ErWasmLinearMemory linear_memory;
  ErWasmModule module;
  ErAppUiPresentation presentation;
  UINT32 main_index = 0;
  INT64 result = 0;

  er_mem_zero(memory, (UINTN)sizeof(memory));
  test_prepare_wasm_ui_presentation(&presentation);

  check_int64("wasm ui linear memory prepare",
              er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                            0u, 1024u, 1024u, 2048u,
                                            &linear_memory),
              0);
  host.linear_memory = linear_memory;
  host.ui_emit = test_vm_ui_emit;
  host.ui_presentation = &presentation;
  check_int64("wasm ui init",
              er_wasm_init(&module, g_edgerun_ui_counter_wasm,
                           ER_UI_COUNTER_WASM_SIZE, &host),
              0);
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

  presentation.max_text_quads = 0u;
  check_int64("wasm ui reject over presentation budget",
              er_wasm_execute_i64(&module, main_index, &result), -1);
  presentation.max_text_quads = 1u;
  host.ui_presentation = 0;
  check_int64("wasm ui reject missing presentation",
              er_wasm_init(&module, g_edgerun_ui_counter_wasm,
                           ER_UI_COUNTER_WASM_SIZE, &host),
              0);
  check_int64("wasm ui execute reject missing presentation",
              er_wasm_execute_i64(&module, main_index, &result), -1);

  host.ui_presentation = &presentation;
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

static void test_ui_wasm_app_runner(void) {
  static UINT8 memory[65536];
  static const UINT8 input_packet[] = {'k', 'e', 'y', '1'};
  ErWasmHostCalls host = {0};
  ErUiWasmAppRuntime runtime;
  ErAppUiPresentation presentation;
  er_ui_scene_t scene;
  er_ui_key_t key;
  er_ui_key_t invalid_key;
  er_ui_key_modifiers_t modifiers;
  INT64 result = 0;

  test_prepare_wasm_ui_presentation(&presentation);

  check_int64("ui wasm app scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  er_mem_zero((UINT8*)&runtime, (UINTN)sizeof(runtime));
  runtime.memory = memory;
  runtime.memory_size = (UINT32)sizeof(memory);
  runtime.relay_inbox_base = 0u;
  runtime.relay_inbox_len = 1024u;
  runtime.relay_outbox_base = 1024u;
  runtime.relay_outbox_len = 2048u;
  runtime.presentation = &presentation;
  runtime.scene = &scene;
  runtime.input_epoch_modifier.tick_stride = 2u;
  runtime.execute_epoch_modifier.tick_stride = 4u;
  runtime.input_len = ER_UI_WASM_INPUT_PACKET_LEN;
  runtime.input_sequence = ER_UI_WASM_INPUT_SEQUENCE_MAX;
  check_int64("ui wasm app prepare",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime),
              0);
  check_uint64("ui wasm app prepared input len", runtime.input_len, 0u);
  check_uint64("ui wasm app prepared input sequence", runtime.input_sequence, 0u);
  check_uint64("ui wasm app prepared clock tick", runtime.settlement_clock.now.tick, 0u);
  check_uint64("ui wasm app input epoch stride", runtime.input_epoch_modifier.tick_stride, 2u);
  check_uint64("ui wasm app execute epoch stride", runtime.execute_epoch_modifier.tick_stride, 4u);
  check_int64("ui wasm app deliver input",
              er_ui_wasm_app_deliver_input(&runtime, input_packet,
                                           (UINT32)sizeof(input_packet)),
              0);
  check_uint64("ui wasm app inbox byte0", memory[0], (UINT8)'k');
  check_uint64("ui wasm app inbox byte3", memory[3], (UINT8)'1');
  check_uint64("ui wasm app inbox zeroed", memory[4], 0u);
  check_uint64("ui wasm app input len", runtime.input_len, sizeof(input_packet));
  check_uint64("ui wasm app input sequence", runtime.input_sequence, 1u);
  check_uint64("ui wasm app input epoch tick", runtime.last_input_epoch.tick, 2u);
  check_int64("ui wasm app reject oversized input",
              er_ui_wasm_app_deliver_input(&runtime, input_packet,
                                           runtime.relay_inbox_len + 1u),
              -1);
  check_uint64("ui wasm app rejected input sequence", runtime.input_sequence, 1u);
  check_uint64("ui wasm app rejected input epoch tick", runtime.last_input_epoch.tick, 2u);
  key.kind = ER_UI_KEY_OTHER;
  key.codepoint = (UINT32)'A';
  modifiers = er_ui_key_modifiers(true, true, false, false);
  check_int64("ui wasm app deliver key input",
              er_ui_wasm_app_deliver_key_input(&runtime, key, modifiers), 0);
  check_uint64("ui wasm app key input abi", memory[ER_UI_WASM_INPUT_ABI_OFFSET],
               ER_UI_WASM_INPUT_ABI_VERSION);
  check_uint64("ui wasm app key input kind", memory[ER_UI_WASM_INPUT_KIND_OFFSET],
               ER_UI_WASM_INPUT_KIND_KEY);
  check_uint64("ui wasm app key input key", memory[ER_UI_WASM_INPUT_KEY_KIND_OFFSET],
               ER_UI_KEY_OTHER);
  check_uint64("ui wasm app key input codepoint", memory[ER_UI_WASM_INPUT_KEY_CODEPOINT_OFFSET],
               (UINT8)'A');
  check_uint64("ui wasm app key input modifiers", memory[ER_UI_WASM_INPUT_MODIFIERS_OFFSET],
               ER_UI_WASM_INPUT_MODIFIER_SHIFT | ER_UI_WASM_INPUT_MODIFIER_CTRL);
  check_uint64("ui wasm app key input len", runtime.input_len, ER_UI_WASM_INPUT_PACKET_LEN);
  check_uint64("ui wasm app key input sequence field",
               memory[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 2u);
  check_uint64("ui wasm app key input sequence", runtime.input_sequence, 2u);
  check_uint64("ui wasm app key input epoch field",
               memory[ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET], 4u);
  check_uint64("ui wasm app key input epoch high byte",
               memory[ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET + 4u], 0u);
  check_uint64("ui wasm app key input slot field",
               memory[ER_UI_WASM_INPUT_EPOCH_SLOT_OFFSET], 0u);
  check_uint64("ui wasm app key input era field",
               memory[ER_UI_WASM_INPUT_EPOCH_ERA_OFFSET], 0u);
  check_uint64("ui wasm app key input epoch tick", runtime.last_input_epoch.tick, 4u);
  invalid_key.kind = (er_ui_key_kind_t)(ER_UI_KEY_OTHER + 1u);
  invalid_key.codepoint = 0u;
  check_int64("ui wasm app reject invalid key input",
              er_ui_wasm_app_deliver_key_input(&runtime, invalid_key, modifiers), -1);
  check_uint64("ui wasm app invalid key sequence", runtime.input_sequence, 2u);
  runtime.input_sequence = ER_UI_WASM_INPUT_SEQUENCE_MAX;
  check_int64("ui wasm app deliver wrapped key input",
              er_ui_wasm_app_deliver_key_input(&runtime, key, modifiers), 0);
  check_uint64("ui wasm app wrapped key input sequence field",
               memory[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 1u);
  check_uint64("ui wasm app wrapped key input sequence", runtime.input_sequence, 1u);
  check_uint64("ui wasm app wrapped key input epoch field",
               memory[ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET], 6u);
  check_uint64("ui wasm app wrapped input epoch tick", runtime.last_input_epoch.tick, 6u);
  check_int64("ui wasm app execute", er_ui_wasm_app_execute(&runtime, &result),
              0);
  check_uint64("ui wasm app result", (UINT64)result,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("ui wasm app emitted", runtime.emitted, 1u);
  check_uint64("ui wasm app execute epoch tick", runtime.last_execute_epoch.tick, 10u);
  check_uint64("ui wasm app rects", scene.rect_count, 1u);
  check_uint64("ui wasm app hits", scene.hit_count, 1u);
  check_uint64("ui wasm app text", scene.text_quad_count, 1u);
  check_int64("ui wasm app hit kind", scene.hits[0].kind, ER_UI_HIT_BUTTON);
  check_uint64("ui wasm app hit id from input sequence", scene.hits[0].id, 1u);
  memory[4096] = 0x5au;
  check_int64("ui wasm app execute again", er_ui_wasm_app_execute(&runtime, &result),
              0);
  check_uint64("ui wasm app persistent memory", memory[4096], 0x5au);
  check_uint64("ui wasm app emitted again", runtime.emitted, 1u);
  check_uint64("ui wasm app execute again epoch tick", runtime.last_execute_epoch.tick, 14u);
  check_uint64("ui wasm app rects after rerun", scene.rect_count, 1u);
  check_uint64("ui wasm app hits after rerun", scene.hit_count, 1u);
  check_uint64("ui wasm app text after rerun", scene.text_quad_count, 1u);
  check_int64("ui wasm app reject second prepare",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime),
              -1);
  er_ui_scene_destroy(&scene);
}

static void test_ui_wasm_app_multiple_runtimes(void) {
  static UINT8 memory_a[65536];
  static UINT8 memory_b[65536];
  ErWasmHostCalls host = {0};
  ErUiWasmAppRuntime runtime_a;
  ErUiWasmAppRuntime runtime_b;
  ErAppUiPresentation presentation_a;
  ErAppUiPresentation presentation_b;
  er_ui_scene_t scene_a;
  er_ui_scene_t scene_b;
  er_ui_key_t key;
  er_ui_key_modifiers_t modifiers;
  INT64 result_a = 0;
  INT64 result_b = 0;

  test_prepare_wasm_ui_presentation(&presentation_a);
  test_prepare_wasm_ui_presentation(&presentation_b);
  check_int64("ui wasm multi scene a init",
              er_ui_scene_init_with_allocator(&scene_a, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui wasm multi scene b init",
              er_ui_scene_init_with_allocator(&scene_b, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);

  er_mem_zero(memory_a, (UINTN)sizeof(memory_a));
  er_mem_zero(memory_b, (UINTN)sizeof(memory_b));
  er_mem_zero((UINT8*)&runtime_a, (UINTN)sizeof(runtime_a));
  er_mem_zero((UINT8*)&runtime_b, (UINTN)sizeof(runtime_b));
  runtime_a.memory = memory_a;
  runtime_a.memory_size = (UINT32)sizeof(memory_a);
  runtime_a.relay_inbox_base = 0u;
  runtime_a.relay_inbox_len = 1024u;
  runtime_a.relay_outbox_base = 1024u;
  runtime_a.relay_outbox_len = 2048u;
  runtime_a.presentation = &presentation_a;
  runtime_a.scene = &scene_a;
  runtime_b.memory = memory_b;
  runtime_b.memory_size = (UINT32)sizeof(memory_b);
  runtime_b.relay_inbox_base = 0u;
  runtime_b.relay_inbox_len = 1024u;
  runtime_b.relay_outbox_base = 1024u;
  runtime_b.relay_outbox_len = 2048u;
  runtime_b.presentation = &presentation_b;
  runtime_b.scene = &scene_b;

  check_int64("ui wasm multi prepare a",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime_a),
              0);
  check_int64("ui wasm multi prepare b",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime_b),
              0);

  key.kind = ER_UI_KEY_OTHER;
  key.codepoint = (UINT32)'Z';
  modifiers = er_ui_key_modifiers(false, false, false, false);
  check_int64("ui wasm multi input a",
              er_ui_wasm_app_deliver_key_input(&runtime_a, key, modifiers), 0);
  check_int64("ui wasm multi input b1",
              er_ui_wasm_app_deliver_key_input(&runtime_b, key, modifiers), 0);
  check_int64("ui wasm multi input b2",
              er_ui_wasm_app_deliver_key_input(&runtime_b, key, modifiers), 0);

  check_int64("ui wasm multi execute a",
              er_ui_wasm_app_execute(&runtime_a, &result_a), 0);
  check_int64("ui wasm multi execute b",
              er_ui_wasm_app_execute(&runtime_b, &result_b), 0);
  check_uint64("ui wasm multi result a", (UINT64)result_a,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("ui wasm multi result b", (UINT64)result_b,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("ui wasm multi scene a rects", scene_a.rect_count, 1u);
  check_uint64("ui wasm multi scene b rects", scene_b.rect_count, 1u);
  check_uint64("ui wasm multi scene a hit id", scene_a.hits[0].id, 1u);
  check_uint64("ui wasm multi scene b hit id", scene_b.hits[0].id, 2u);
  check_uint64("ui wasm multi memory a sequence",
               memory_a[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 1u);
  check_uint64("ui wasm multi memory b sequence",
               memory_b[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 2u);
  check_uint64("ui wasm multi emitted a", runtime_a.emitted, 1u);
  check_uint64("ui wasm multi emitted b", runtime_b.emitted, 1u);

  er_ui_scene_destroy(&scene_b);
  er_ui_scene_destroy(&scene_a);
}

static void test_vfs_object_packets(void) {
  static const UINT8 object_bytes[] = {'a', 'b', 'c', 'd', 'e', 'f'};
  ErCryptoProvider crypto;
  ErVfsObjectPacket packet;
  ErVfsObjectPacket packets[2];
  ErVfsObjectPacket tampered_packets[2];
  ErVfsObjectLabelRef ref;
  ErVfsObjectLabelRef ref_from_object;
  ErVfsObjectTransformRef transform;
  UINT8 large_object[1500];
  UINT8 assembled[1500];
  ErHash assembled_object_id;
  UINTN assembled_len = 0u;
  UINTN i;

  crypto.ctx = (void*)(UINTN)5u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  check_int64("vfs label valid", er_vfs_label_valid("app/data.bin", 12), 1);
  check_int64("vfs label reject empty", er_vfs_label_valid("", 0), 0);
  check_int64("vfs label reject absolute", er_vfs_label_valid("/app/data.bin", 13), 0);
  check_int64("vfs label reject parent", er_vfs_label_valid("app/../data.bin", 15), 0);
  check_int64("vfs label reject backslash", er_vfs_label_valid("app\\data.bin", 12), 0);

  check_int64("vfs object packet", er_vfs_prepare_object_packet(&crypto, object_bytes, sizeof(object_bytes), 2, 1, 3, &packet), 1);
  check_int64("vfs packet abi", packet.header.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs packet index", packet.header.packet_index, 1);
  check_int64("vfs packet count", packet.header.packet_count, 3);
  check_uint64("vfs packet object len", packet.header.object_len, sizeof(object_bytes));
  check_uint64("vfs packet offset", packet.header.offset, 2);
  check_uint64("vfs packet bytes len", packet.header.bytes_len, 4);
  check_int64("vfs packet byte0", packet.bytes[0], 'c');
  check_int64("vfs packet byte3", packet.bytes[3], 'f');

  for (i = 0u; i < sizeof(large_object); ++i) {
    large_object[i] = (UINT8)(i & 0xffu);
  }
  check_int64("vfs object packet 0",
              er_vfs_prepare_object_packet(&crypto, large_object,
                                           sizeof(large_object), 0u, 0u, 2u,
                                           &packets[0]),
              1);
  check_int64("vfs object packet 1",
              er_vfs_prepare_object_packet(&crypto, large_object,
                                           sizeof(large_object),
                                           ER_VFS_OBJECT_PACKET_BYTES, 1u, 2u,
                                           &packets[1]),
              1);
  check_int64("vfs assemble object",
              er_vfs_assemble_object_packets(&crypto, packets, 2u, assembled,
                                             sizeof(assembled), &assembled_len,
                                             &assembled_object_id),
              1);
  check_uint64("vfs assemble len", assembled_len, sizeof(large_object));
  check_hash_equal("vfs assemble object id", &assembled_object_id,
                   &packets[0].header.object_id);
  check_int64("vfs assemble first byte", assembled[0], large_object[0]);
  check_int64("vfs assemble split byte",
              assembled[ER_VFS_OBJECT_PACKET_BYTES],
              large_object[ER_VFS_OBJECT_PACKET_BYTES]);
  check_int64("vfs assemble last byte",
              assembled[sizeof(large_object) - 1u],
              large_object[sizeof(large_object) - 1u]);
  tampered_packets[0] = packets[0];
  tampered_packets[1] = packets[1];
  tampered_packets[1].bytes[0] ^= 1u;
  check_int64("vfs assemble reject payload tamper",
              er_vfs_assemble_object_packets(&crypto, tampered_packets, 2u,
                                             assembled, sizeof(assembled),
                                             &assembled_len,
                                             &assembled_object_id),
              0);
  tampered_packets[0] = packets[1];
  tampered_packets[1] = packets[0];
  check_int64("vfs assemble reject packet order",
              er_vfs_assemble_object_packets(&crypto, tampered_packets, 2u,
                                             assembled, sizeof(assembled),
                                             &assembled_len,
                                             &assembled_object_id),
              0);
  check_int64("vfs assemble reject short buffer",
              er_vfs_assemble_object_packets(&crypto, packets, 2u, assembled,
                                             sizeof(assembled) - 1u,
                                             &assembled_len,
                                             &assembled_object_id),
              0);

  check_int64("vfs label ref", er_vfs_prepare_object_label_ref(&crypto, "app/data.bin", 12, object_bytes, sizeof(object_bytes), &ref), 1);
  check_int64("vfs label ref abi", ref.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs label ref label len", ref.label_len, 12);
  check_uint64("vfs label ref object len", ref.object_len, sizeof(object_bytes));
  check_int64("vfs label ref from object",
              er_vfs_prepare_object_label_ref_from_object(&crypto, "app/alias.bin", 13, &ref.object_id,
                                                          ref.object_len, &ref_from_object),
              1);
  check_int64("vfs label ref from object abi", ref_from_object.abi_version, ER_VFS_ABI_VERSION);
  check_uint64("vfs label ref from object len", ref_from_object.object_len, sizeof(object_bytes));
  check_hash_equal("vfs label ref from object id", &ref_from_object.object_id, &ref.object_id);

  check_int64("vfs transform reject unsealed",
              er_vfs_prepare_transform_ref(&crypto, &ref.object_id, ref.object_len, &packet.header.payload_hash,
                                           packet.header.bytes_len, ER_VFS_COMPRESSION_NONE, ER_VFS_SEAL_NONE,
                                           &transform),
              0);
  check_int64("vfs transform sealed",
              er_vfs_prepare_transform_ref(&crypto, &ref.object_id, ref.object_len, &packet.header.payload_hash,
                                           packet.header.bytes_len, ER_VFS_COMPRESSION_NONE, ER_VFS_SEAL_AES256_GCM,
                                           &transform),
              1);
  check_int64("vfs transform abi", transform.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs transform seal", transform.seal_kind, ER_VFS_SEAL_AES256_GCM);
}

static void test_app_identity_routes(void) {
  ErCryptoProvider crypto;
  static const UINT8 app_bytes[] = {'w', 'a', 's', 'm', '-', 'u', 'i'};
  static const UINT8 manifest_bytes[] = {'m', 'a', 'n', 'i', 'f', 'e', 's', 't'};
  static const UINT8 ui_assets_bytes[] = {'a', 's', 's', 'e', 't', 's'};
  ErVfsObjectLabelRef app_ref;
  ErVfsObjectLabelRef app_alias_ref;
  ErVfsObjectLabelRef app_bad_label_ref;
  ErVfsObjectLabelRef manifest_ref;
  ErVfsObjectLabelRef manifest_alias_ref;
  ErVfsObjectLabelRef ui_assets_ref;
  ErVfsObjectPacket app_packet;
  ErVfsObjectPacket manifest_packet;
  ErVfsObjectPacket ui_assets_packet;
  ErVfsObjectPacket tampered_manifest_packet;
  ErAppPackageObjectLoad app_load;
  ErAppPackageObjectLoad manifest_load;
  ErAppPackageObjectLoad ui_assets_load;
  ErAppPackageManifest package;
  ErAppPackageManifest package_alias;
  ErAppPackageManifest package_without_assets;
  ErAppPackageManifest package_bad_id;
  ErAppLoadedPackage loaded_package;
  ErAppPackageStorageSource storage_source;
  ErAppPackageStorageSource storage_source_again;
  ErAppPackageStorageSource package_without_assets_source;
  ErAppPackageStorageSource bad_storage_source;
  ErAppPackageStorageResponse app_storage_response;
  ErAppPackageStorageResponse manifest_storage_response;
  ErAppPackageStorageResponse ui_assets_storage_response;
  ErAppPackageStorageResponse bad_storage_response;
  ErAppPackageStorageObject app_storage_object;
  ErAppPackageStorageObject manifest_storage_object;
  ErAppPackageStorageObject ui_assets_storage_object;
  ErAppPackageStorageObject bad_storage_object;
  ErAdmittedRoute app_retrieve_route;
  ErAdmittedRoute manifest_retrieve_route;
  ErAdmittedRoute ui_assets_retrieve_route;
  ErAdmittedRoute bad_retrieve_route;
  ErHash app_object_id;
  ErHash manifest_hash;
  ErHash admission_id;
  ErHash capability_id;
  ErHash route_hash;
  ErNodeId target_node_id;
  ErNodeId parent_relay_node_id;
  ErNodeId ui_relay_node_id;
  ErAppIdentity identity;
  ErAppIpcRouteBinding binding;
  ErAppBudget budget;
  ErAppUsage usage;
  ErAppScheduleSlot slot;
  ErAppLaunchAllocation allocation;
  ErAppExecutionJurisdiction jurisdiction;
  ErAppUiPresentation presentation;
  er_ui_scene_budget_t scene_budget;
  er_ui_scene_stats_t scene_stats;
  UINT8 loaded_app_bytes[sizeof(app_bytes)];
  UINT8 loaded_manifest_bytes[sizeof(manifest_bytes)];
  UINT8 loaded_ui_assets_bytes[sizeof(ui_assets_bytes)];
  UINT8 nonce[ER_APP_INSTANCE_NONCE_LEN];
  UINTN i;

  crypto.ctx = (void*)(UINTN)9u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  check_int64("app package app ref",
              er_vfs_prepare_object_label_ref(&crypto, "apps/counter.wasm", 17,
                                              app_bytes, sizeof(app_bytes), &app_ref),
              1);
  check_int64("app package app alias ref",
              er_vfs_prepare_object_label_ref(&crypto, "drafts/main.wasm", 16,
                                              app_bytes, sizeof(app_bytes), &app_alias_ref),
              1);
  check_int64("app package manifest ref",
              er_vfs_prepare_object_label_ref(&crypto, "apps/counter.manifest", 21,
                                              manifest_bytes, sizeof(manifest_bytes), &manifest_ref),
              1);
  check_int64("app package manifest alias ref",
              er_vfs_prepare_object_label_ref(&crypto, "drafts/app.manifest", 19,
                                              manifest_bytes, sizeof(manifest_bytes),
                                              &manifest_alias_ref),
              1);
  check_int64("app package assets ref",
              er_vfs_prepare_object_label_ref(&crypto, "apps/counter.assets", 19,
                                              ui_assets_bytes, sizeof(ui_assets_bytes),
                                              &ui_assets_ref),
              1);
  check_int64("app package prepare",
              er_app_prepare_package_manifest(&crypto, &app_ref, &manifest_ref,
                                              &ui_assets_ref, &package),
              1);
  check_int64("app package abi", package.abi_version, ER_APP_ABI_VERSION);
  check_int64("app package kind", package.app_kind, ER_APP_KIND_USER);
  check_hash_equal("app package app object", &package.app_object_id,
                   &app_ref.object_id);
  check_hash_equal("app package manifest object", &package.manifest_object_id,
                   &manifest_ref.object_id);
  check_uint64("app package app len", package.app_object_len, sizeof(app_bytes));
  check_uint64("app package manifest len", package.manifest_object_len,
               sizeof(manifest_bytes));
  check_uint64("app package assets len", package.ui_assets_object_len,
               sizeof(ui_assets_bytes));
  check_int64("app package alias prepare",
              er_app_prepare_package_manifest(&crypto, &app_alias_ref,
                                              &manifest_alias_ref,
                                              &ui_assets_ref, &package_alias),
              1);
  check_hash_equal("app package labels ignored", &package_alias.package_id,
                   &package.package_id);
  check_int64("app package without assets",
              er_app_prepare_package_manifest(&crypto, &app_ref, &manifest_ref,
                                              0, &package_without_assets),
              1);
  check_hash_not_equal("app package assets affect id",
                       &package_without_assets.package_id, &package.package_id);
  check_int64("app package reject missing manifest",
              er_app_prepare_package_manifest(&crypto, &app_ref, 0,
                                              &ui_assets_ref, &package_alias),
              0);
  app_bad_label_ref = app_ref;
  app_bad_label_ref.label[0] = '/';
  check_int64("app package reject invalid label ref",
              er_app_prepare_package_manifest(&crypto, &app_bad_label_ref,
                                              &manifest_ref, &ui_assets_ref,
                                              &package_alias),
              0);
  check_int64("app package app packet",
              er_vfs_prepare_object_packet(&crypto, app_bytes, sizeof(app_bytes),
                                           0u, 0u, 1u, &app_packet),
              1);
  check_int64("app package manifest packet",
              er_vfs_prepare_object_packet(&crypto, manifest_bytes,
                                           sizeof(manifest_bytes), 0u, 0u, 1u,
                                           &manifest_packet),
              1);
  check_int64("app package assets packet",
              er_vfs_prepare_object_packet(&crypto, ui_assets_bytes,
                                           sizeof(ui_assets_bytes), 0u, 0u, 1u,
                                           &ui_assets_packet),
              1);
  app_load.packets = &app_packet;
  app_load.packet_count = 1u;
  app_load.bytes = loaded_app_bytes;
  app_load.capacity = sizeof(loaded_app_bytes);
  manifest_load.packets = &manifest_packet;
  manifest_load.packet_count = 1u;
  manifest_load.bytes = loaded_manifest_bytes;
  manifest_load.capacity = sizeof(loaded_manifest_bytes);
  ui_assets_load.packets = &ui_assets_packet;
  ui_assets_load.packet_count = 1u;
  ui_assets_load.bytes = loaded_ui_assets_bytes;
  ui_assets_load.capacity = sizeof(loaded_ui_assets_bytes);
  check_int64("app package load",
              er_app_load_package_objects(&crypto, &package, &app_load,
                                          &manifest_load, &ui_assets_load,
                                          &loaded_package),
              1);
  check_int64("app package load abi", loaded_package.abi_version,
              ER_APP_ABI_VERSION);
  check_hash_equal("app package load package id", &loaded_package.package_id,
                   &package.package_id);
  check_uint64("app package load app len", loaded_package.app_len,
               sizeof(app_bytes));
  check_uint64("app package load manifest len", loaded_package.manifest_len,
               sizeof(manifest_bytes));
  check_uint64("app package load assets len", loaded_package.ui_assets_len,
               sizeof(ui_assets_bytes));
  check_int64("app package load app byte", loaded_package.app_bytes[0],
              app_bytes[0]);
  check_int64("app package load manifest byte",
              loaded_package.manifest_bytes[0], manifest_bytes[0]);
  check_int64("app package load assets byte",
              loaded_package.ui_assets_bytes[0], ui_assets_bytes[0]);
  check_int64("app package load without assets",
              er_app_load_package_objects(&crypto, &package_without_assets,
                                          &app_load, &manifest_load, 0,
                                          &loaded_package),
              1);
  check_uint64("app package load no assets len",
               loaded_package.ui_assets_len, 0u);
  check_int64("app package load reject extra assets",
              er_app_load_package_objects(&crypto, &package_without_assets,
                                          &app_load, &manifest_load,
                                          &ui_assets_load, &loaded_package),
              0);
  package_bad_id = package;
  package_bad_id.package_id.bytes[0] ^= 1u;
  check_int64("app package load reject package id",
              er_app_load_package_objects(&crypto, &package_bad_id, &app_load,
                                          &manifest_load, &ui_assets_load,
                                          &loaded_package),
              0);
  tampered_manifest_packet = manifest_packet;
  tampered_manifest_packet.bytes[0] ^= 1u;
  manifest_load.packets = &tampered_manifest_packet;
  check_int64("app package load reject manifest bytes",
              er_app_load_package_objects(&crypto, &package, &app_load,
                                          &manifest_load, &ui_assets_load,
                                          &loaded_package),
              0);
  manifest_load.packets = &manifest_packet;

  er_mem_zero((UINT8*)&app_retrieve_route, (UINTN)sizeof(app_retrieve_route));
  app_retrieve_route.abi_version = ER_WORK_ABI_VERSION;
  app_retrieve_route.role = ER_NODE_ROLE_STORAGE;
  app_retrieve_route.department = ER_DEPARTMENT_STORAGE;
  app_retrieve_route.work_type = ER_WORK_TYPE_OBJECT_RETRIEVE;
  app_retrieve_route.admitted_budget = 32u;
  test_fill_bytes(app_retrieve_route.route_id.bytes, ER_HASH_LEN, 0x11u);
  test_fill_bytes(app_retrieve_route.request_hash.bytes, ER_HASH_LEN, 0x12u);
  test_fill_bytes(app_retrieve_route.admission_hash.bytes, ER_HASH_LEN, 0x13u);
  test_fill_bytes(app_retrieve_route.source_node_id.bytes, ER_NODE_ID_LEN, 0x14u);
  test_fill_bytes(app_retrieve_route.target_node_id.bytes, ER_NODE_ID_LEN, 0x15u);
  test_fill_bytes(app_retrieve_route.relay_node_id.bytes, ER_NODE_ID_LEN, 0x16u);
  manifest_retrieve_route = app_retrieve_route;
  test_fill_bytes(manifest_retrieve_route.route_id.bytes, ER_HASH_LEN, 0x21u);
  test_fill_bytes(manifest_retrieve_route.request_hash.bytes, ER_HASH_LEN, 0x22u);
  ui_assets_retrieve_route = app_retrieve_route;
  test_fill_bytes(ui_assets_retrieve_route.route_id.bytes, ER_HASH_LEN, 0x31u);
  test_fill_bytes(ui_assets_retrieve_route.request_hash.bytes, ER_HASH_LEN, 0x32u);
  check_int64("app package storage source",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source),
              1);
  check_int64("app package storage source abi", storage_source.abi_version,
              ER_APP_ABI_VERSION);
  check_hash_equal("app package storage source package",
                   &storage_source.package_id, &package.package_id);
  check_hash_equal("app package storage app route",
                   &storage_source.app_retrieve_route_id,
                   &app_retrieve_route.route_id);
  check_hash_equal("app package storage manifest route",
                   &storage_source.manifest_retrieve_route_id,
                   &manifest_retrieve_route.route_id);
  check_hash_equal("app package storage assets route",
                   &storage_source.ui_assets_retrieve_route_id,
                   &ui_assets_retrieve_route.route_id);
  check_int64("app package storage source deterministic",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              1);
  check_hash_equal("app package storage source id deterministic",
                   &storage_source_again.source_id, &storage_source.source_id);
  er_mem_zero((UINT8*)&app_storage_response,
              (UINTN)sizeof(app_storage_response));
  app_storage_response.abi_version = ER_APP_ABI_VERSION;
  app_storage_response.retrieve_route_id = storage_source.app_retrieve_route_id;
  app_storage_response.object_id = package.app_object_id;
  app_storage_response.object_len = package.app_object_len;
  app_storage_response.packets = app_load.packets;
  app_storage_response.packet_count = app_load.packet_count;
  app_storage_response.bytes = app_load.bytes;
  app_storage_response.capacity = app_load.capacity;
  er_mem_zero((UINT8*)&manifest_storage_response,
              (UINTN)sizeof(manifest_storage_response));
  manifest_storage_response.abi_version = ER_APP_ABI_VERSION;
  manifest_storage_response.retrieve_route_id =
      storage_source.manifest_retrieve_route_id;
  manifest_storage_response.object_id = package.manifest_object_id;
  manifest_storage_response.object_len = package.manifest_object_len;
  manifest_storage_response.packets = manifest_load.packets;
  manifest_storage_response.packet_count = manifest_load.packet_count;
  manifest_storage_response.bytes = manifest_load.bytes;
  manifest_storage_response.capacity = manifest_load.capacity;
  er_mem_zero((UINT8*)&ui_assets_storage_response,
              (UINTN)sizeof(ui_assets_storage_response));
  ui_assets_storage_response.abi_version = ER_APP_ABI_VERSION;
  ui_assets_storage_response.retrieve_route_id =
      storage_source.ui_assets_retrieve_route_id;
  ui_assets_storage_response.object_id = package.ui_assets_object_id;
  ui_assets_storage_response.object_len = package.ui_assets_object_len;
  ui_assets_storage_response.packets = ui_assets_load.packets;
  ui_assets_storage_response.packet_count = ui_assets_load.packet_count;
  ui_assets_storage_response.bytes = ui_assets_load.bytes;
  ui_assets_storage_response.capacity = ui_assets_load.capacity;
  check_int64("app package storage object app",
              er_app_prepare_package_storage_object(&app_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &app_storage_object),
              1);
  check_hash_equal("app package storage object route",
                   &app_storage_object.retrieve_route_id,
                   &storage_source.app_retrieve_route_id);
  check_int64("app package storage object manifest",
              er_app_prepare_package_storage_object(&manifest_storage_response,
                                                    &storage_source.manifest_retrieve_route_id,
                                                    &package.manifest_object_id,
                                                    package.manifest_object_len,
                                                    &manifest_storage_object),
              1);
  check_int64("app package storage object assets",
              er_app_prepare_package_storage_object(&ui_assets_storage_response,
                                                    &storage_source.ui_assets_retrieve_route_id,
                                                    &package.ui_assets_object_id,
                                                    package.ui_assets_object_len,
                                                    &ui_assets_storage_object),
              1);
  bad_storage_response = app_storage_response;
  bad_storage_response.retrieve_route_id =
      storage_source.manifest_retrieve_route_id;
  check_int64("app package storage object reject route",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  bad_storage_response = app_storage_response;
  bad_storage_response.object_id = package.manifest_object_id;
  check_int64("app package storage object reject id",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  bad_storage_response = app_storage_response;
  --bad_storage_response.object_len;
  check_int64("app package storage object reject len",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  bad_storage_response = app_storage_response;
  bad_storage_response.capacity = bad_storage_response.object_len - 1u;
  check_int64("app package storage object reject capacity",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  check_int64("app package storage load",
              er_app_load_package_from_storage_source(&crypto, &package,
                                                      &storage_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              1);
  check_hash_equal("app package storage load package",
                   &loaded_package.package_id, &package.package_id);
  check_uint64("app package storage load app len", loaded_package.app_len,
               sizeof(app_bytes));
  bad_storage_object = app_storage_object;
  bad_storage_object.retrieve_route_id = manifest_storage_object.retrieve_route_id;
  check_int64("app package storage load reject route mismatch",
              er_app_load_package_from_storage_source(&crypto, &package,
                                                      &storage_source,
                                                      &bad_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              0);
  bad_storage_source = storage_source;
  bad_storage_source.source_id.bytes[0] ^= 1u;
  check_int64("app package storage load reject source id",
              er_app_load_package_from_storage_source(&crypto, &package,
                                                      &bad_storage_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              0);
  check_int64("app package storage source without assets",
              er_app_prepare_package_storage_source(&crypto,
                                                    &package_without_assets,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    0,
                                                    &package_without_assets_source),
              1);
  check_hash_not_equal("app package storage source assets affect id",
                       &package_without_assets_source.source_id,
                       &storage_source.source_id);
  app_storage_response.retrieve_route_id =
      package_without_assets_source.app_retrieve_route_id;
  manifest_storage_response.retrieve_route_id =
      package_without_assets_source.manifest_retrieve_route_id;
  check_int64("app package storage object app without assets",
              er_app_prepare_package_storage_object(&app_storage_response,
                                                    &package_without_assets_source.app_retrieve_route_id,
                                                    &package_without_assets.app_object_id,
                                                    package_without_assets.app_object_len,
                                                    &app_storage_object),
              1);
  check_int64("app package storage object manifest without assets",
              er_app_prepare_package_storage_object(&manifest_storage_response,
                                                    &package_without_assets_source.manifest_retrieve_route_id,
                                                    &package_without_assets.manifest_object_id,
                                                    package_without_assets.manifest_object_len,
                                                    &manifest_storage_object),
              1);
  check_int64("app package storage load without assets",
              er_app_load_package_from_storage_source(&crypto,
                                                      &package_without_assets,
                                                      &package_without_assets_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      0,
                                                      &loaded_package),
              1);
  check_uint64("app package storage load no assets len",
               loaded_package.ui_assets_len, 0u);
  check_int64("app package storage load reject extra assets",
              er_app_load_package_from_storage_source(&crypto,
                                                      &package_without_assets,
                                                      &package_without_assets_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              0);
  check_int64("app package storage reject extra assets route",
              er_app_prepare_package_storage_source(&crypto,
                                                    &package_without_assets,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              0);
  bad_retrieve_route = app_retrieve_route;
  bad_retrieve_route.work_type = ER_WORK_TYPE_OBJECT_STORE;
  check_int64("app package storage reject store route",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &bad_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              0);
  bad_retrieve_route = app_retrieve_route;
  bad_retrieve_route.department = ER_DEPARTMENT_RETRIEVAL;
  check_int64("app package storage reject wrong department",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &bad_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              0);

  for (i = 0; i < ER_HASH_LEN; ++i) {
    app_object_id.bytes[i] = (UINT8)(0x10u + i);
    manifest_hash.bytes[i] = (UINT8)(0x30u + i);
    admission_id.bytes[i] = (UINT8)(0x50u + i);
    capability_id.bytes[i] = (UINT8)(0x70u + i);
    route_hash.bytes[i] = (UINT8)(0x90u + i);
    target_node_id.bytes[i] = (UINT8)(0xb0u + i);
    parent_relay_node_id.bytes[i] = (UINT8)(0xc0u + i);
    ui_relay_node_id.bytes[i] = (UINT8)(0xe0u + i);
    nonce[i] = (UINT8)(0xd0u + i);
  }

  check_int64("app identity reject short nonce",
              er_app_derive_identity(&crypto, &app_object_id, &manifest_hash, &admission_id,
                                     nonce, ER_APP_INSTANCE_NONCE_LEN - 1u, &identity),
              0);
  check_int64("app identity derive",
              er_app_derive_identity(&crypto, &app_object_id, &manifest_hash, &admission_id,
                                     nonce, ER_APP_INSTANCE_NONCE_LEN, &identity),
              1);
  check_int64("app identity abi", identity.abi_version, ER_APP_ABI_VERSION);
  check_int64("app identity nonce", identity.instance_nonce[0], 0xd0);
  check_int64("app identity from package",
              er_app_derive_identity_from_package(&crypto, &package, &admission_id,
                                                  nonce, ER_APP_INSTANCE_NONCE_LEN,
                                                  &identity),
              1);
  check_hash_equal("app identity package object", &identity.app_object_id,
                   &package.app_object_id);
  check_hash_equal("app identity package manifest", &identity.manifest_hash,
                   &package.manifest_object_id);

  check_int64("app ipc route",
              er_app_prepare_ipc_route_binding(&crypto, &identity, &target_node_id, &capability_id,
                                               &route_hash, 42u, ER_CAPABILITY_RISK_NONE, &binding),
              1);
  check_int64("app ipc abi", binding.abi_version, ER_APP_ABI_VERSION);
  check_int64("app ipc sealed", binding.seal_policy, ER_APP_SEAL_POLICY_REQUIRED);
  check_uint64("app ipc sequence", binding.sequence_base, 42u);
  check_uint64("app ipc risk", binding.capability_risk_flags, ER_CAPABILITY_RISK_NONE);

  check_int64("app ipc reject risky cap",
              er_app_prepare_ipc_route_binding(&crypto, &identity, &target_node_id, &capability_id,
                                               &route_hash, 42u, ER_CAPABILITY_RISK_RAW_DEVICE, &binding),
              0);

  identity.abi_version = 0;
  check_int64("app ipc reject abi",
              er_app_prepare_ipc_route_binding(&crypto, &identity, &target_node_id, &capability_id,
                                               &route_hash, 42u, ER_CAPABILITY_RISK_NONE, &binding),
              0);

  identity.abi_version = ER_APP_ABI_VERSION;
  check_int64("app budget reject opaque system",
              er_app_prepare_budget(&crypto, &identity, 99u, 1000u, 4096u, 1024u, 2048u, 4u, 4u, &budget),
              0);
  check_int64("app budget reject zero memory",
              er_app_prepare_budget(&crypto, &identity, ER_APP_KIND_USER, 1000u, 0u, 1024u, 2048u, 4u, 4u, &budget),
              0);
  check_int64("app budget prepare",
              er_app_prepare_budget(&crypto, &identity, ER_APP_KIND_USER, 1000u, 4096u, 1024u, 2048u, 4u, 4u, &budget),
              1);
  check_int64("app budget kind", budget.app_kind, ER_APP_KIND_USER);
  check_uint64("app budget cpu", budget.max_cpu_steps, 1000u);
  check_uint64("app budget memory", budget.max_memory_bytes, 4096u);

  check_int64("app usage init", er_app_usage_init(&identity, &budget, &usage), 1);
  check_int64("app usage cpu charge", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_CPU_STEP, 400u), 1);
  check_uint64("app usage cpu charged", usage.cpu_steps, 400u);
  check_int64("app usage cpu over budget", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_CPU_STEP, 601u), 0);
  check_uint64("app usage cpu unchanged", usage.cpu_steps, 400u);
  check_int64("app usage memory charge", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_MEMORY_BYTE, 4096u), 1);
  check_int64("app usage memory over budget", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_MEMORY_BYTE, 1u), 0);
  check_int64("app usage unknown resource", er_app_usage_charge(&usage, &budget, 0xffffffffu, 1u), 0);

  check_int64("app schedule slot",
              er_app_prepare_schedule_slot(&crypto, &identity, &budget, 7u, 11u, &slot),
              1);
  check_int64("app schedule abi", slot.abi_version, ER_APP_ABI_VERSION);
  check_uint64("app schedule tick", slot.deterministic_tick, 7u);
  check_uint64("app schedule sequence", slot.sequence, 11u);
  check_uint64("app schedule cpu quanta", slot.cpu_step_quanta, 1000u);
  check_uint64("app schedule memory limit", slot.memory_byte_limit, 4096u);

  check_int64("app launch reject short backing",
              er_app_prepare_launch_allocation(&crypto, &identity, &budget, 0x100000u, 4095u, &allocation),
              0);
  check_int64("app launch reject null backing",
              er_app_prepare_launch_allocation(&crypto, &identity, &budget, 0u, 4096u, &allocation),
              0);
  check_int64("app launch allocation",
              er_app_prepare_launch_allocation(&crypto, &identity, &budget, 0x100000u, 4096u, &allocation),
              1);
  check_int64("app launch abi", allocation.abi_version, ER_APP_ABI_VERSION);
  check_uint64("app launch executor base", allocation.executor_memory_base, 0x100000u);
  check_uint64("app launch executor len", allocation.executor_memory_len, 4096u);
  check_uint64("app launch address base", allocation.app_address_base, ER_APP_ADDRESS_BASE);
  check_uint64("app launch address len", allocation.app_address_len, 4096u);

  check_int64("app execution jurisdiction",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 1024u,
                                                    1024u, 1024u, &jurisdiction),
              1);
  check_int64("app execution abi", jurisdiction.abi_version, ER_APP_ABI_VERSION);
  check_node_id_equal("app execution parent relay", &jurisdiction.parent_relay_node_id,
                      &parent_relay_node_id);
  check_node_id_equal("app execution app node", &jurisdiction.app_node_id,
                      &identity.app_node_id);
  check_uint64("app execution address len", jurisdiction.app_address_len, 4096u);
  check_uint64("app execution inbox base", jurisdiction.public_inbox_base, 0u);
  check_uint64("app execution inbox len", jurisdiction.public_inbox_len, 1024u);
  check_uint64("app execution outbox base", jurisdiction.public_outbox_base, 1024u);
  check_uint64("app execution outbox len", jurisdiction.public_outbox_len, 1024u);
  check_int64("app execution reject overlap",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 2048u,
                                                    1024u, 1024u, &jurisdiction),
              0);
  check_int64("app execution reject outbox outside",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 1024u,
                                                    4096u, 1u, &jurisdiction),
              0);

  scene_budget.rects = 2u;
  scene_budget.hits = 1u;
  scene_budget.drag_sources = 0u;
  scene_budget.drop_targets = 0u;
  scene_budget.transitions = 1u;
  scene_budget.icon_quads = 1u;
  scene_budget.text_quads = 3u;
  check_int64("app ui presentation prepare",
              er_app_prepare_ui_presentation(&crypto, &jurisdiction, &ui_relay_node_id,
                                             &route_hash, scene_budget, 12u, &presentation),
              1);
  check_int64("app ui presentation abi", presentation.abi_version, ER_APP_ABI_VERSION);
  check_node_id_equal("app ui presentation app", &presentation.app_node_id,
                      &identity.app_node_id);
  check_node_id_equal("app ui presentation relay", &presentation.ui_relay_node_id,
                      &ui_relay_node_id);
  check_uint64("app ui presentation text budget", presentation.max_text_quads, 3u);
  scene_stats.rects = 2u;
  scene_stats.hits = 1u;
  scene_stats.drag_sources = 0u;
  scene_stats.drop_targets = 0u;
  scene_stats.transitions = 1u;
  scene_stats.clips = 100u;
  scene_stats.icon_quads = 1u;
  scene_stats.text_quads = 3u;
  check_int64("app ui scene fits presentation",
              er_app_ui_scene_fits_presentation(scene_stats, &presentation), 1);
  scene_stats.text_quads = 4u;
  check_int64("app ui scene rejects over text budget",
              er_app_ui_scene_fits_presentation(scene_stats, &presentation), 0);
  scene_stats.text_quads = 3u;
  scene_stats.rects = 3u;
  check_int64("app ui scene rejects over rect budget",
              er_app_ui_scene_fits_presentation(scene_stats, &presentation), 0);
  scene_budget.rects = 0u;
  scene_budget.hits = 0u;
  scene_budget.drag_sources = 0u;
  scene_budget.drop_targets = 0u;
  scene_budget.transitions = 0u;
  scene_budget.icon_quads = 0u;
  scene_budget.text_quads = 0u;
  check_int64("app ui presentation reject zero budget",
              er_app_prepare_ui_presentation(&crypto, &jurisdiction, &ui_relay_node_id,
                                             &route_hash, scene_budget, 12u, &presentation),
              0);

  er_mem_zero(parent_relay_node_id.bytes, ER_NODE_ID_LEN);
  check_int64("app execution reject zero parent",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 1024u,
                                                    1024u, 1024u, &jurisdiction),
              0);
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
  ErRelayForwardIntent intent;
  ErRelayTransitHop hop;
  ErRelayTransitHop hop_again;
  ErRelayTransitHop hop_changed;
  ErRelayAccountingClaim claim;
  ErCapabilityEnvelopeHeader capability_header;
  ErCapabilityEnvelopeHeader bad_capability_header;
  ErHash session_id;
  ErHash invocation_id;
  ErHash capability_id;
  ErHash scene_hash;

  crypto.ctx = (void*)(UINTN)11u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

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
  test_fill_bytes(scene_hash.bytes, ER_HASH_LEN, 0xf1u);
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
  test_fill_bytes(envelope.packet_hash.bytes, ER_HASH_LEN, 0xb1u);
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
  test_fill_bytes(envelope.packet_hash.bytes, ER_HASH_LEN, 0xb1u);
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
                                                         11u,
                                                         120000u,
                                                         &scene_hash,
                                                         64u,
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
}

static void test_boot_profiles(void) {
  check_int64("boot profile ui valid", er_boot_profile_valid(ER_BOOT_PROFILE_UI), 1);
  check_int64("boot profile native valid", er_boot_profile_valid(ER_BOOT_PROFILE_NATIVE), 1);
  check_int64("boot profile tpm valid", er_boot_profile_valid(ER_BOOT_PROFILE_TPM), 1);
  check_int64("boot profile gpu valid", er_boot_profile_valid(ER_BOOT_PROFILE_GPU), 1);
  check_int64("boot profile retired smoke rejected", er_boot_profile_valid(0u), 0);
  check_int64("boot profile retired pci rejected", er_boot_profile_valid(1u), 0);
  check_int64("boot profile retired quiet rejected", er_boot_profile_valid(2u), 0);
  check_int64("boot profile retired mmio rejected", er_boot_profile_valid(3u), 0);
  check_int64("boot profile invalid rejected", er_boot_profile_valid(255u), 0);
  check_cstr("boot profile ui label", er_boot_profile_label(ER_BOOT_PROFILE_UI), "ui");
  check_cstr("boot profile native label", er_boot_profile_label(ER_BOOT_PROFILE_NATIVE), "native");
  check_cstr("boot profile tpm label", er_boot_profile_label(ER_BOOT_PROFILE_TPM), "tpm");
  check_cstr("boot profile gpu label", er_boot_profile_label(ER_BOOT_PROFILE_GPU), "gpu");
  check_cstr("boot profile retired label", er_boot_profile_label(0u), "invalid");
  check_cstr("boot profile invalid label", er_boot_profile_label(255u), "invalid");
}

static void test_hw_relay_endpoints(void) {
  enum {
    RELAY_ETH_TEST_MMIO_DWORDS = 128u,
    RELAY_ETH_TEST_VIRTIO_HDR_LEN = 12u,
    RELAY_ETH_TEST_TX_DESC = 0u,
    RELAY_VIRTIO_TEST_DEVICE_TYPE_OFFSET = 0u,
    RELAY_VIRTIO_TEST_QUEUE_OFFSET = 4u,
    RELAY_VIRTIO_TEST_TRANSPORT_OFFSET = 6u
  };
  UINT32 regs[RELAY_ETH_TEST_MMIO_DWORDS] = {0};
  ErChannelEndpoint endpoint;
  ErChannelEndpoint eth_endpoint;
  ErChannelEndpoint virtio_endpoint;
  ErRelayForwardIntent intent;
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErVirtioQueueAvail* tx_avail;
  UINT8* tx_frame;
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x10u, 0x20u, 0x30u, 0x40u, 0x50u};
  UINT8 other_mac[ER_NET_MAC_LEN] = {0x02u, 0xaau, 0xbbu, 0xccu, 0xddu, 0xeeu};
  UINT8 packet[4] = {1u, 2u, 3u, 4u};

  check_int64("relay udp endpoint",
              er_hw_relay_prepare_firmware_udp_endpoint(10u, 42u, 0u, 1u, 9000u,
                                                        "uefi-udp4", 9u, &endpoint),
              1);
  check_int64("relay udp abi", endpoint.abi_version, ER_WORK_ABI_VERSION);
  check_int64("relay udp kind", endpoint.kind, ER_CHANNEL_KIND_FIRMWARE_UDP);
  check_int64("relay udp address len", endpoint.address_len, ER_HW_RELAY_FIRMWARE_UDP_ADDR_LEN);
  check_int64("relay udp ip0", endpoint.address[0], 10);
  check_int64("relay udp ip1", endpoint.address[1], 42);
  check_int64("relay udp port hi", endpoint.address[4], 0x23);
  check_int64("relay udp port lo", endpoint.address[5], 0x28);
  check_int64("relay udp recognized", er_hw_relay_endpoint_is_firmware_udp(&endpoint), 1);

  check_int64("relay default udp", er_hw_relay_default_firmware_udp_endpoint(&endpoint), 1);
  check_int64("relay default label", endpoint.label_len, 9);

  intent.abi_version = ER_WORK_ABI_VERSION;
  intent.reserved = 0;
  intent.to = endpoint;
  check_int64("relay forward unavailable",
              er_hw_relay_forward_to_firmware_udp(&intent, packet, (UINTN)sizeof(packet)),
              0);

  endpoint.kind = ER_CHANNEL_KIND_MEMORY;
  check_int64("relay udp reject kind", er_hw_relay_endpoint_is_firmware_udp(&endpoint), 0);

  check_int64("relay native eth endpoint",
              er_hw_relay_prepare_native_eth_endpoint(peer_mac, "native-eth", 10u,
                                                      &eth_endpoint),
              1);
  check_int64("relay native eth abi", eth_endpoint.abi_version, ER_WORK_ABI_VERSION);
  check_int64("relay native eth kind", eth_endpoint.kind, ER_CHANNEL_KIND_NATIVE_ETH);
  check_int64("relay native eth address len", eth_endpoint.address_len,
              ER_HW_RELAY_NATIVE_ETH_ADDR_LEN);
  check_uint64("relay native eth mac0", eth_endpoint.address[0], peer_mac[0]);
  check_uint64("relay native eth mac5", eth_endpoint.address[5], peer_mac[5]);
  check_int64("relay native eth recognized",
              er_hw_relay_endpoint_is_native_eth(&eth_endpoint), 1);
  check_int64("relay native eth not virtio",
              er_hw_relay_endpoint_is_virtio(&eth_endpoint), 0);

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;
  check_int64("relay native eth virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("relay native eth init",
              er_native_eth_init(&native_eth, &net, peer_mac), 1);
  intent.to = eth_endpoint;
  check_int64("relay forward native eth",
              er_hw_relay_forward_to_native_eth(&native_eth, &intent, packet,
                                                (UINTN)sizeof(packet)),
              1);
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(RELAY_ETH_TEST_TX_DESC);
  check_uint64("relay native eth tx desc", tx_avail->ring[0], RELAY_ETH_TEST_TX_DESC);
  check_uint64("relay native eth tx mac0",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("relay native eth tx type hi",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN + 12u], 0x88u);
  check_uint64("relay native eth tx type lo",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN + 13u], 0xb5u);
  check_uint64("relay native eth payload3",
               tx_frame[RELAY_ETH_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN + 3u],
               packet[3]);

  check_int64("relay native eth other endpoint",
              er_hw_relay_prepare_native_eth_endpoint(other_mac, "native-eth", 10u,
                                                      &eth_endpoint),
              1);
  intent.to = eth_endpoint;
  check_int64("relay native eth reject mac mismatch",
              er_hw_relay_forward_to_native_eth(&native_eth, &intent, packet,
                                                (UINTN)sizeof(packet)),
              0);

  check_int64("relay virtio endpoint",
              er_hw_relay_prepare_virtio_endpoint(ER_VIRTIO_DEVICE_TYPE_BLK, 0u,
                                                  "virtio-blk", 10u,
                                                  &virtio_endpoint),
              1);
  check_int64("relay virtio abi", virtio_endpoint.abi_version, ER_WORK_ABI_VERSION);
  check_int64("relay virtio kind", virtio_endpoint.kind, ER_CHANNEL_KIND_VIRTIO_QUEUE);
  check_int64("relay virtio address len", virtio_endpoint.address_len,
              ER_HW_RELAY_VIRTIO_ADDR_LEN);
  check_uint64("relay virtio device type byte0",
               virtio_endpoint.address[RELAY_VIRTIO_TEST_DEVICE_TYPE_OFFSET],
               ER_VIRTIO_DEVICE_TYPE_BLK);
  check_uint64("relay virtio queue byte0",
               virtio_endpoint.address[RELAY_VIRTIO_TEST_QUEUE_OFFSET], 0u);
  check_uint64("relay virtio transport any",
               virtio_endpoint.address[RELAY_VIRTIO_TEST_TRANSPORT_OFFSET],
               ER_VIRTIO_TRANSPORT_KIND_NONE);
  check_int64("relay virtio recognized",
              er_hw_relay_endpoint_is_virtio(&virtio_endpoint), 1);
  check_int64("relay virtio not native eth",
              er_hw_relay_endpoint_is_native_eth(&virtio_endpoint), 0);
}

static void test_erwire_native_eth_sink(void) {
  enum {
    ERWIRE_ETH_TEST_MMIO_DWORDS = 128u,
    ERWIRE_ETH_TEST_VIRTIO_HDR_LEN = 12u,
    ERWIRE_ETH_TEST_TX_DESC = 0u,
    ERWIRE_ETH_TEST_STREAM_ID = 7u,
    ERWIRE_ETH_TEST_ETH_TYPE_OFFSET = ERWIRE_ETH_TEST_VIRTIO_HDR_LEN + (ER_NET_MAC_LEN * 2u),
    ERWIRE_ETH_TEST_ETH_TYPE_HI = (ER_NET_ETH_TYPE_EDGERUN >> 8u) & 0xffu,
    ERWIRE_ETH_TEST_ETH_TYPE_LO = ER_NET_ETH_TYPE_EDGERUN & 0xffu,
    ERWIRE_ETH_TEST_PAYLOAD_OFFSET = ERWIRE_ETH_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN,
    ERWIRE_ETH_TEST_KIND_OFFSET =
        ERWIRE_ETH_TEST_PAYLOAD_OFFSET + sizeof(UINT32) + (sizeof(UINT16) * 2u) + (sizeof(UINT32) * 2u),
    ERWIRE_ETH_TEST_LEN_OFFSET = ERWIRE_ETH_TEST_KIND_OFFSET + (sizeof(UINT16) * 2u),
    ERWIRE_ETH_TEST_TEXT_OFFSET = ERWIRE_ETH_TEST_PAYLOAD_OFFSET + ERWIRE_HEADER_SIZE
  };
  UINT32 regs[ERWIRE_ETH_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErVirtioQueueAvail* tx_avail;
  UINT8* tx_frame;
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x21u, 0x22u, 0x23u, 0x24u, 0x25u};

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("erwire eth virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("erwire eth native init", er_native_eth_init(&native_eth, &net, peer_mac), 1);
  erwire_init(ERWIRE_ETH_TEST_STREAM_ID);
  check_int64("erwire eth set sink", erwire_set_native_eth_sink(&native_eth), 1);
  erwire_send_text("ok");
  erwire_clear_native_eth_sink();

  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(ERWIRE_ETH_TEST_TX_DESC);
  check_uint64("erwire eth tx desc", tx_avail->ring[0], ERWIRE_ETH_TEST_TX_DESC);
  check_uint64("erwire eth dst mac0", tx_frame[ERWIRE_ETH_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("erwire eth type hi", tx_frame[ERWIRE_ETH_TEST_ETH_TYPE_OFFSET], ERWIRE_ETH_TEST_ETH_TYPE_HI);
  check_uint64("erwire eth type lo", tx_frame[ERWIRE_ETH_TEST_ETH_TYPE_OFFSET + 1u], ERWIRE_ETH_TEST_ETH_TYPE_LO);
  check_uint64("erwire eth magic0", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET], 'E');
  check_uint64("erwire eth magic1", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET + 1u], 'R');
  check_uint64("erwire eth magic2", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET + 2u], 'W');
  check_uint64("erwire eth magic3", tx_frame[ERWIRE_ETH_TEST_PAYLOAD_OFFSET + 3u], '1');
  check_uint64("erwire eth kind", tx_frame[ERWIRE_ETH_TEST_KIND_OFFSET], ERWIRE_KIND_LOG_TEXT);
  check_uint64("erwire eth payload len", tx_frame[ERWIRE_ETH_TEST_LEN_OFFSET], 2u);
  check_uint64("erwire eth text0", tx_frame[ERWIRE_ETH_TEST_TEXT_OFFSET], 'o');
  check_uint64("erwire eth text1", tx_frame[ERWIRE_ETH_TEST_TEXT_OFFSET + 1u], 'k');
}

static void test_erwire_parse_and_native_poll(void) {
  enum {
    ERWIRE_RX_TEST_MMIO_DWORDS = 128u,
    ERWIRE_RX_TEST_VIRTIO_HDR_LEN = 12u,
    ERWIRE_RX_TEST_TX_DESC = 0u,
    ERWIRE_RX_TEST_RX_DESC = 3u,
    ERWIRE_RX_TEST_STREAM_ID = 11u,
    ERWIRE_RX_TEST_PAYLOAD_LEN = 2u,
    ERWIRE_RX_TEST_PAYLOAD_OFFSET = ERWIRE_RX_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN,
    ERWIRE_RX_TEST_PACKET_LEN = ERWIRE_HEADER_SIZE + ERWIRE_RX_TEST_PAYLOAD_LEN
  };
  UINT32 regs[ERWIRE_RX_TEST_MMIO_DWORDS] = {0};
  ErVirtioNet net;
  ErNativeEth native_eth;
  ErwirePacketHeader header;
  ErVirtioQueueUsed* rx_used;
  UINT8* rx_buffer;
  UINT8* tx_frame;
  UINT8 payload[ERWIRE_MAX_PAYLOAD] = {0};
  UINT8 short_payload[1] = {0};
  UINT8 bad_packet[ERWIRE_RX_TEST_PACKET_LEN] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x31u, 0x32u, 0x33u, 0x34u, 0x35u};
  UINT32 frame_len = 0u;
  UINT32 payload_len = 0u;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("erwire rx virtio init",
              er_virtio_net_init_mmio((UINT64)(UINTN)regs, (UINT64)sizeof(regs), &net),
              1);
  net.mac[0] = 0x02u;
  net.mac[ER_NET_MAC_LEN - 1u] = 0x02u;
  check_int64("erwire rx native init", er_native_eth_init(&native_eth, &net, peer_mac), 1);
  erwire_init(ERWIRE_RX_TEST_STREAM_ID);
  check_int64("erwire rx set sink", erwire_set_native_eth_sink(&native_eth), 1);
  erwire_send_text("rx");

  tx_frame = er_virtio_net_test_tx_buffer(ERWIRE_RX_TEST_TX_DESC);
  check_int64("erwire parse packet",
              erwire_parse_packet(tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
                                  ERWIRE_RX_TEST_PACKET_LEN, &header,
                                  payload, (UINT32)sizeof(payload),
                                  &payload_len),
              1);
  check_uint64("erwire parse stream", header.StreamId, ERWIRE_RX_TEST_STREAM_ID);
  check_uint64("erwire parse seq", header.Seq, 0u);
  check_uint64("erwire parse kind", header.Kind, ERWIRE_KIND_LOG_TEXT);
  check_uint64("erwire parse flags", header.Flags, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST);
  check_uint64("erwire parse len", payload_len, ERWIRE_RX_TEST_PAYLOAD_LEN);
  check_uint64("erwire parse payload0", payload[0], 'r');
  check_uint64("erwire parse payload1", payload[1], 'x');
  check_int64("erwire parse reject capacity",
              erwire_parse_packet(tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
                                  ERWIRE_RX_TEST_PACKET_LEN, &header,
                                  short_payload, (UINT32)sizeof(short_payload),
                                  &payload_len),
              0);
  er_mem_copy(bad_packet, tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
              ERWIRE_RX_TEST_PACKET_LEN);
  bad_packet[0] = 0u;
  check_int64("erwire parse reject magic",
              erwire_parse_packet(bad_packet, ERWIRE_RX_TEST_PACKET_LEN,
                                  &header, payload, (UINT32)sizeof(payload),
                                  &payload_len),
              0);

  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(ERWIRE_RX_TEST_RX_DESC);
  check_int64("erwire rx build frame",
              er_net_build_eth_frame(peer_mac, net.mac, ER_NET_ETH_TYPE_EDGERUN,
                                     tx_frame + ERWIRE_RX_TEST_PAYLOAD_OFFSET,
                                     ERWIRE_RX_TEST_PACKET_LEN,
                                     rx_buffer + ERWIRE_RX_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = ERWIRE_RX_TEST_RX_DESC;
  rx_used->ring[0].len = ERWIRE_RX_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;
  check_int64("erwire poll native eth",
              erwire_poll_native_eth(&header, payload, (UINT32)sizeof(payload),
                                     &payload_len),
              1);
  check_uint64("erwire poll stream", header.StreamId, ERWIRE_RX_TEST_STREAM_ID);
  check_uint64("erwire poll payload len", payload_len, ERWIRE_RX_TEST_PAYLOAD_LEN);
  check_uint64("erwire poll payload0", payload[0], 'r');
  check_uint64("erwire poll payload1", payload[1], 'x');
  erwire_clear_native_eth_sink();
}

static void test_native_boot_erwire_eth_sink(void) {
  enum {
    NATIVE_BOOT_TEST_MMIO_DWORDS = 128u,
    NATIVE_BOOT_TEST_VIRTIO_HDR_LEN = 12u,
    NATIVE_BOOT_TEST_TX_DESC = 0u,
    NATIVE_BOOT_TEST_RX_DESC = 3u,
    NATIVE_BOOT_TEST_BAD_RX_DESC = 4u,
    NATIVE_BOOT_TEST_STREAM_ID = 9u,
    NATIVE_BOOT_TEST_PAYLOAD_LEN = 4u,
    NATIVE_BOOT_TEST_PAYLOAD_OFFSET = NATIVE_BOOT_TEST_VIRTIO_HDR_LEN + ER_NET_ETH_HEADER_LEN
  };
  UINT32 regs[NATIVE_BOOT_TEST_MMIO_DWORDS] = {0};
  ErNativeBootState state;
  ErNativeRelayIngress ingress;
  ErCryptoProvider crypto;
  ErVirtioQueueAvail* tx_avail;
  ErVirtioQueueUsed* rx_used;
  UINT8* tx_frame;
  UINT8* rx_buffer;
  UINT8 payload[NATIVE_BOOT_TEST_PAYLOAD_LEN] = {1u, 2u, 3u, 4u};
  UINT8 bad_packet[ERWIRE_HEADER_SIZE] = {0};
  UINT8 peer_mac[ER_NET_MAC_LEN] = {0x02u, 0x21u, 0x22u, 0x23u, 0x24u, 0x25u};
  UINT32 frame_len = 0u;

  er_mmio_reset();
  regs[ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_MAGIC;
  regs[ER_VIRTIO_MMIO_VERSION_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VERSION_MODERN;
  regs[ER_VIRTIO_MMIO_DEVICE_ID_OFFSET / sizeof(UINT32)] = ER_VIRTIO_DEVICE_TYPE_NET;
  regs[ER_VIRTIO_MMIO_VENDOR_OFFSET / sizeof(UINT32)] = ER_VIRTIO_MMIO_VENDOR_ANY;
  regs[ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET / sizeof(UINT32)] = 1u;
  regs[ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET / sizeof(UINT32)] = ER_VIRTIO_QUEUE_SIZE;

  check_int64("native boot sink configured",
              er_native_boot_configure_erwire_eth_sink((UINT64)(UINTN)regs,
                                                       (UINT64)sizeof(regs),
                                                       peer_mac,
                                                       &state),
              1);
  check_int64("native boot initialized", state.initialized, 1);
  check_int64("native boot erwire ready", state.erwire_sink_ready, 1);
  check_int64("native boot net", state.net != 0, 1);
  check_int64("native boot eth", state.eth != 0, 1);

  erwire_init(NATIVE_BOOT_TEST_STREAM_ID);
  erwire_send(ERWIRE_KIND_VFS_OBJECT_PACKET, ERWIRE_FLAG_FIRST | ERWIRE_FLAG_LAST,
              payload, (UINT32)sizeof(payload));
  tx_avail = er_virtio_net_test_tx_avail();
  tx_frame = er_virtio_net_test_tx_buffer(NATIVE_BOOT_TEST_TX_DESC);
  check_uint64("native boot tx desc", tx_avail->ring[0], NATIVE_BOOT_TEST_TX_DESC);
  check_uint64("native boot dst mac0", tx_frame[NATIVE_BOOT_TEST_VIRTIO_HDR_LEN], peer_mac[0]);
  check_uint64("native boot erwire magic0", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET], 'E');
  check_uint64("native boot erwire magic1", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET + 1u], 'R');
  check_uint64("native boot erwire magic2", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET + 2u], 'W');
  check_uint64("native boot erwire magic3", tx_frame[NATIVE_BOOT_TEST_PAYLOAD_OFFSET + 3u], '1');

  rx_used = er_virtio_net_test_rx_used();
  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_BOOT_TEST_RX_DESC);
  check_int64("native boot relay build frame",
              er_net_build_eth_frame(peer_mac, state.net->mac,
                                     ER_NET_ETH_TYPE_EDGERUN,
                                     tx_frame + NATIVE_BOOT_TEST_PAYLOAD_OFFSET,
                                     ERWIRE_HEADER_SIZE + NATIVE_BOOT_TEST_PAYLOAD_LEN,
                                     rx_buffer + NATIVE_BOOT_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[0].id = NATIVE_BOOT_TEST_RX_DESC;
  rx_used->ring[0].len = NATIVE_BOOT_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 1u;

  er_crypto_blake3_provider(&crypto);
  check_int64("native boot poll relay ingress",
              er_native_boot_poll_relay_ingress(&state, &crypto, &ingress), 1);
  check_int64("native boot relay accepted", ingress.status, ER_NATIVE_RELAY_INGRESS_ACCEPTED);
  check_uint64("native boot relay kind", ingress.header.Kind, ERWIRE_KIND_VFS_OBJECT_PACKET);
  check_uint64("native boot relay seq", ingress.header.Seq, 0u);
  check_uint64("native boot relay payload len", ingress.payload_len, NATIVE_BOOT_TEST_PAYLOAD_LEN);
  check_uint64("native boot relay ingress mac", ingress.ingress.address[0], peer_mac[0]);

  rx_buffer = er_virtio_net_test_rx_buffer(NATIVE_BOOT_TEST_BAD_RX_DESC);
  check_int64("native boot bad relay frame",
              er_net_build_eth_frame(peer_mac, state.net->mac,
                                     ER_NET_ETH_TYPE_EDGERUN,
                                     bad_packet, (UINT32)sizeof(bad_packet),
                                     rx_buffer + NATIVE_BOOT_TEST_VIRTIO_HDR_LEN,
                                     ER_NET_FRAME_MAX, &frame_len),
              1);
  rx_used->ring[1].id = NATIVE_BOOT_TEST_BAD_RX_DESC;
  rx_used->ring[1].len = NATIVE_BOOT_TEST_VIRTIO_HDR_LEN + frame_len;
  rx_used->idx = 2u;
  check_int64("native boot poll malformed relay ingress",
              er_native_boot_poll_relay_ingress(&state, &crypto, &ingress), 1);
  check_int64("native boot relay malformed", ingress.status, ER_NATIVE_RELAY_INGRESS_MALFORMED);
  check_int64("native boot poll no relay ingress",
              er_native_boot_poll_relay_ingress(&state, &crypto, &ingress), 1);
  check_int64("native boot relay none", ingress.status, ER_NATIVE_RELAY_INGRESS_NONE);
  erwire_clear_native_eth_sink();
}

static void test_netlog_disabled_path(void) {
  check_int64("netlog starts disabled", er_netlog_ready(), 0);
  check_int64("netlog null init stays disabled", (er_netlog_init(0), er_netlog_ready()), 0);
  check_int64("netlog disabled write fails", er_netlog_write_bytes_wait((const UINT8*)"x", 1u, 0u), 0);
  check_int64("netlog disabled empty write fails", er_netlog_write_bytes_wait((const UINT8*)"", 0u, 0u), 0);
  er_netlog_write(0);
  er_netlog_write_text("queued\n");
  er_netlog_flush_text();
}

static void test_gfx_console_disabled_path(void) {
  er_gfx_console_set_enabled(0u);
  er_gfx_console_write("disabled path");
  er_gfx_console_write(0);
  er_gfx_console_init(0);
  er_gfx_console_write("still disabled");
  check_int64("gfx console disabled path reached", 1, 1);
}

static void test_ui_surface_renderer_surface(void) {
  UINT32 pixels[24] = {0};
  ErUiSurface surface;
  ErUiSurfaceRenderStats stats;
  ErUiSurfaceFrameBudget frame_budget;
  ErUiSurfaceFrameBudgetViolation frame_violation;
  ErUiSurfaceMode mode;
  ErUiSurfaceBandwidthPlan bandwidth_plan;
  ErUiSurfaceTilePlan tile_plan;
  ErUiSurfaceMemoryPlan memory_plan;
  ErUiSurfaceMemoryBudget memory_budget;
  ErUiSurfaceMemoryBudgetViolation memory_violation;
  ErUiSurfaceDirtyTileList dirty_tiles;
  UINT8 tile_marks[4] = {9u, 9u, 9u, 9u};
  UINT32 tile_ids[4] = {0};
  er_ui_rect_t rects[3];
  er_ui_rect_t next_rects[1];
  er_ui_quad_t icon_quads[1];
  er_ui_scene_t scene;
  er_ui_scene_t next_scene;
  ErUiSurfacePixelRect tile_rect;
  ErUiSurfaceFrameState frame_state;
  UINT32 rgb_red = er_ui_surface_pack_rgb(ER_UI_SURFACE_PIXEL_RGBX, 255u, 0u, 0u);
  UINT32 bgr_red = er_ui_surface_pack_rgb(ER_UI_SURFACE_PIXEL_BGRX, 255u, 0u, 0u);
  UINTN i;

  check_pixel("ui surface pack rgb red", rgb_red, 0x00ff0000u);
  check_pixel("ui surface pack bgr red", bgr_red, 0x000000ffu);

  surface.pixels = pixels;
  surface.width = 3u;
  surface.height = 2u;
  surface.stride = 4u;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui surface valid", er_ui_surface_valid(&surface), 1);
  check_int64("ui surface clear", er_ui_surface_clear(&surface, er_ui_color_rgb_u8(1u, 2u, 3u)), 1);
  check_pixel("ui surface clear first", pixels[0], 0x00010203u);
  check_pixel("ui surface clear row end", pixels[2], 0x00010203u);
  check_pixel("ui surface clear stride untouched", pixels[3], 0u);
  check_pixel("ui surface clear second row", pixels[4], 0x00010203u);
  mode.width = 3u;
  mode.height = 2u;
  mode.stride = 4u;
  mode.refresh_hz = 120u;
  mode.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui surface mode valid", er_ui_surface_mode_valid(&mode), 1);
  check_int64("ui surface mode tile plan", er_ui_surface_tile_plan_from_mode(&mode, 2u, 1u, 4u, &tile_plan), 1);
  check_uint64("ui surface mode tile scanout bytes", tile_plan.scanout_bytes, 32u);
  check_int64("ui surface bandwidth plan", er_ui_surface_bandwidth_plan_from_mode(&mode, 4u, &bandwidth_plan), 1);
  check_uint64("ui surface bandwidth scanout", bandwidth_plan.scanout_bytes_per_second, 3840u);
  check_uint64("ui surface bandwidth full frame", bandwidth_plan.full_frame_bytes_per_second, 2880u);
  check_uint64("ui surface bandwidth budget", bandwidth_plan.budget_bytes_per_second, 11520u);
  check_int64("ui surface bandwidth reject zero overdraw", er_ui_surface_bandwidth_plan_from_mode(&mode, 0u, &bandwidth_plan), 0);
  check_uint64("ui surface bandwidth reject zeroes output", bandwidth_plan.budget_bytes_per_second, 0u);
  mode.refresh_hz = 0u;
  check_int64("ui surface reject zero refresh mode", er_ui_surface_mode_valid(&mode), 0);
  check_int64("ui surface reject invalid mode plan", er_ui_surface_tile_plan_from_mode(&mode, 2u, 1u, 4u, &tile_plan), 0);
  check_int64("ui surface tile plan", er_ui_surface_tile_plan(&surface, 2u, 1u, 4u, &tile_plan), 1);
  check_uint64("ui surface tile columns", tile_plan.columns, 2u);
  check_uint64("ui surface tile rows", tile_plan.rows, 2u);
  check_uint64("ui surface tile count", tile_plan.tile_count, 4u);
  check_uint64("ui surface tile scanout bytes", tile_plan.scanout_bytes, 32u);
  check_uint64("ui surface tile frame bytes", tile_plan.full_frame_bytes, 24u);
  check_uint64("ui surface tile max bytes", tile_plan.max_tile_bytes, 8u);
  check_uint64("ui surface tile state bytes", tile_plan.tile_state_bytes, 4u);
  check_uint64("ui surface tile dirty queue bytes", tile_plan.dirty_queue_bytes, 16u);
  check_int64("ui surface memory plan",
              er_ui_surface_memory_plan_from_tile_plan(&tile_plan, 1u, 64u, 128u, 256u, &memory_plan),
              1);
  check_uint64("ui surface memory scanout", memory_plan.scanout_bytes, 32u);
  check_uint64("ui surface memory backing", memory_plan.backing_bytes, 32u);
  check_uint64("ui surface memory tile state", memory_plan.tile_state_bytes, 4u);
  check_uint64("ui surface memory dirty queue", memory_plan.dirty_queue_bytes, 16u);
  check_uint64("ui surface memory commands", memory_plan.command_bytes, 64u);
  check_uint64("ui surface memory glyph cache", memory_plan.glyph_cache_bytes, 128u);
  check_uint64("ui surface memory surfaces", memory_plan.surface_bytes, 256u);
  check_uint64("ui surface memory total", memory_plan.total_bytes, 532u);
  memory_budget.scanout_bytes = 32u;
  memory_budget.backing_bytes = 32u;
  memory_budget.tile_state_bytes = 4u;
  memory_budget.dirty_queue_bytes = 16u;
  memory_budget.command_bytes = 64u;
  memory_budget.glyph_cache_bytes = 128u;
  memory_budget.surface_bytes = 256u;
  memory_budget.total_bytes = 532u;
  check_int64("ui surface memory fits exact budget", er_ui_surface_memory_plan_fits_budget(memory_plan, memory_budget), 1);
  memory_budget.glyph_cache_bytes = 127u;
  check_int64("ui surface memory first budget violation",
              er_ui_surface_memory_plan_first_budget_violation(memory_plan, memory_budget, &memory_violation),
              1);
  check_cstr("ui surface memory budget violation name", memory_violation.name, "glyph_cache_bytes");
  check_uint64("ui surface memory budget violation actual", memory_violation.actual, 128u);
  check_uint64("ui surface memory budget violation limit", memory_violation.limit, 127u);
  check_int64("ui surface memory rejects over budget", er_ui_surface_memory_plan_fits_budget(memory_plan, memory_budget), 0);
  check_int64("ui surface memory reject overflow",
              er_ui_surface_memory_plan_from_tile_plan(&tile_plan, 1u, 0xffffffffffffffffull, 0u, 0u, &memory_plan),
              0);
  check_uint64("ui surface memory overflow zeroes output", memory_plan.total_bytes, 0u);
  frame_budget = er_ui_surface_frame_budget_from_plan(&tile_plan, er_ui_scene_budget_native_interactive_frame(), 4u);
  check_uint64("ui surface derived budget pixels", frame_budget.pixels_written, 24u);
  check_uint64("ui surface derived budget bytes", frame_budget.bytes_written, 96u);
  check_uint64("ui surface derived budget rects", frame_budget.rects, 2000u);
  check_uint64("ui surface derived budget icons", frame_budget.icon_quads, 1200u);
  check_uint64("ui surface derived budget text", frame_budget.text_quads, 8000u);
  check_uint64("ui surface derived budget tiles", frame_budget.tiles_rendered, 4u);
  check_uint64("ui surface derived budget dirty", frame_budget.dirty_tiles_requested, 4u);
  check_uint64("ui surface derived budget clipped", frame_budget.clipped_primitives, 44800u);
  frame_budget = er_ui_surface_frame_budget_from_plan(&tile_plan, er_ui_scene_budget_native_interactive_frame(), 0u);
  check_uint64("ui surface reject zero overdraw budget", frame_budget.bytes_written, 0u);
  check_int64("ui surface tile rect", er_ui_surface_tile_rect(&tile_plan, 3u, &tile_rect), 1);
  check_uint64("ui surface tile rect x0", tile_rect.x0, 2u);
  check_uint64("ui surface tile rect y0", tile_rect.y0, 1u);
  check_uint64("ui surface tile rect x1", tile_rect.x1, 3u);
  check_uint64("ui surface tile rect y1", tile_rect.y1, 2u);
  dirty_tiles.tile_ids = tile_ids;
  dirty_tiles.capacity = 4u;
  dirty_tiles.count = 99u;
  dirty_tiles.overflowed = 1u;
  check_int64("ui surface dirty reset", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_uint64("ui surface dirty reset count", dirty_tiles.count, 0u);
  check_uint64("ui surface dirty reset mark", tile_marks[0], 0u);
  check_int64("ui surface dirty mark clipped rect",
              er_ui_surface_dirty_tiles_mark_rect(&tile_plan, -1.0f, 0.0f, 3.0f, 2.0f, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty count", dirty_tiles.count, 2u);
  check_uint64("ui surface dirty first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui surface dirty second", dirty_tiles.tile_ids[1], 2u);
  check_uint64("ui surface dirty duplicate count before", dirty_tiles.count, 2u);
  check_int64("ui surface dirty mark duplicate",
              er_ui_surface_dirty_tiles_mark_rect(&tile_plan, 0.0f, 0.0f, 1.0f, 1.0f, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty duplicate count after", dirty_tiles.count, 2u);

  rects[0] = er_ui_rect_fill(-1.0f, 0.0f, 3.0f, 2.0f, 0.0f, er_ui_color_rgb_u8(10u, 20u, 30u));
  scene.clear = er_ui_color_rgb_u8(0u, 0u, 0u);
  scene.rects = rects;
  scene.rect_count = 1u;
  scene.rect_capacity = 1u;
  scene.hits = 0;
  scene.hit_count = 0u;
  scene.hit_capacity = 0u;
  scene.drag_sources = 0;
  scene.drag_source_count = 0u;
  scene.drag_source_capacity = 0u;
  scene.drop_targets = 0;
  scene.drop_target_count = 0u;
  scene.drop_target_capacity = 0u;
  scene.transitions = 0;
  scene.transition_count = 0u;
  scene.transition_capacity = 0u;
  scene.clips = 0;
  scene.clip_count = 0u;
  scene.clip_capacity = 0u;
  scene.icon_quads = 0;
  scene.icon_quad_count = 0u;
  scene.icon_quad_capacity = 0u;
  scene.text_quads = 0;
  scene.text_quad_count = 0u;
  scene.text_quad_capacity = 0u;
  check_int64("ui surface render clipped fill", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface clipped fill x0", pixels[0], 0x000a141eu);
  check_pixel("ui surface clipped fill x1", pixels[1], 0x000a141eu);
  check_pixel("ui surface clipped fill x2 clear", pixels[2], 0u);
  check_int64("ui surface render stats", er_ui_surface_render_scene_with_font_stats(&surface, &scene, 0, &stats), 1);
  check_uint64("ui surface stats clear count", stats.clears, 1u);
  check_uint64("ui surface stats rect count", stats.rects, 1u);
  check_uint64("ui surface stats solid count", stats.solid_rects, 1u);
  check_uint64("ui surface stats pixels", stats.pixels_written, 10u);
  check_uint64("ui surface stats bytes", stats.bytes_written, 40u);
  frame_budget.pixels_written = 10u;
  frame_budget.bytes_written = 40u;
  frame_budget.blend_pixels = 0u;
  frame_budget.text_pixels = 0u;
  frame_budget.rects = 1u;
  frame_budget.icon_quads = 0u;
  frame_budget.text_quads = 0u;
  frame_budget.tiles_rendered = 0u;
  frame_budget.dirty_tiles_requested = 0u;
  frame_budget.clipped_primitives = 0u;
  frame_budget.rejected_primitives = 0u;
  check_int64("ui surface stats fit exact budget", er_ui_surface_render_stats_fits_budget(stats, frame_budget), 1);
  frame_budget.bytes_written = 39u;
  check_int64("ui surface stats first budget violation",
              er_ui_surface_render_stats_first_budget_violation(stats, frame_budget, &frame_violation),
              1);
  check_cstr("ui surface stats budget violation name", frame_violation.name, "bytes_written");
  check_uint64("ui surface stats budget violation actual", frame_violation.actual, 40u);
  check_uint64("ui surface stats budget violation limit", frame_violation.limit, 39u);
  check_int64("ui surface stats reject over budget", er_ui_surface_render_stats_fits_budget(stats, frame_budget), 0);
  icon_quads[0] = er_ui_quad_atlas(0.0f, 0.0f, 2.0f, 2.0f, 0.0f, 0.0f, 1.0f, 1.0f, 2u, er_ui_color_rgb_u8(200u, 200u, 200u));
  scene.icon_quads = icon_quads;
  scene.icon_quad_count = 1u;
  scene.icon_quad_capacity = 1u;
  check_int64("ui surface render icon stats", er_ui_surface_render_scene_with_font_stats(&surface, &scene, 0, &stats), 1);
  check_uint64("ui surface stats icon count", stats.icon_quads, 1u);
  scene.icon_quads = 0;
  scene.icon_quad_count = 0u;
  scene.icon_quad_capacity = 0u;
  {
    UINT32 icon_pixels[576] = {0};
    ErUiSurface icon_surface;
    er_ui_scene_t icon_scene;
    er_ui_quad_t tabler_icon[1];
    ErUiTablerIconRect search_rect;
    UINT64 visible_icon_pixels = 0u;

    icon_surface.pixels = icon_pixels;
    icon_surface.width = 24u;
    icon_surface.height = 24u;
    icon_surface.stride = 24u;
    icon_surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
    icon_scene = (er_ui_scene_t){0};
    icon_scene.clear = er_ui_color_rgb_u8(0u, 0u, 0u);
    tabler_icon[0] = er_ui_quad_atlas(0.0f, 0.0f, 24.0f, 24.0f, 0.0f, 0.0f, 1.0f, 1.0f,
                                      er_ui_icon_atlas_id(ER_UI_ICON_SEARCH), er_ui_color_rgb_u8(255u, 255u, 255u));
    icon_scene.icon_quads = tabler_icon;
    icon_scene.icon_quad_count = 1u;
    icon_scene.icon_quad_capacity = 1u;
    check_int64("ui surface tabler search rect", er_ui_tabler_icon_rect(ER_UI_ICON_SEARCH, &search_rect), 1);
    check_uint64("ui surface tabler search atlas x", search_rect.x, 120u);
    check_int64("ui surface render tabler icon", er_ui_surface_render_scene_with_font_stats(&icon_surface, &icon_scene, 0, &stats), 1);
    check_uint64("ui surface tabler icon stats", stats.icon_quads, 1u);
    for (i = 0u; i < 576u; ++i) {
      if (icon_pixels[i] != 0u) ++visible_icon_pixels;
    }
    check_int64("ui surface tabler icon draws real atlas pixels", visible_icon_pixels > 20u, 1);
    check_int64("ui surface tabler icon keeps transparent interior", visible_icon_pixels < 260u, 1);
  }
  check_int64("ui surface dirty reset for scene", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui surface dirty mark scene",
              er_ui_surface_dirty_tiles_mark_scene(&tile_plan, &scene, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty scene count", dirty_tiles.count, 2u);
  check_uint64("ui surface dirty scene first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui surface dirty scene second", dirty_tiles.tile_ids[1], 2u);
  er_ui_surface_frame_state_reset(&frame_state);
  check_int64("ui surface frame first dirty",
              er_ui_surface_frame_dirty_tiles(&frame_state, &tile_plan, 0, &scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface frame first count", dirty_tiles.count, 4u);
  er_ui_surface_frame_state_commit(&frame_state);
  next_rects[0] = er_ui_rect_fill(2.0f, 1.0f, 1.0f, 1.0f, 0.0f, er_ui_color_rgb_u8(40u, 50u, 60u));
  next_scene = scene;
  next_scene.rects = next_rects;
  check_int64("ui surface dirty reset for diff", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui surface dirty mark scene diff",
              er_ui_surface_dirty_tiles_mark_scene_diff(&tile_plan, &scene, &next_scene,
                                                    tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty diff count", dirty_tiles.count, 3u);
  check_uint64("ui surface dirty diff old first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui surface dirty diff old second", dirty_tiles.tile_ids[1], 2u);
  check_uint64("ui surface dirty diff new", dirty_tiles.tile_ids[2], 3u);
  check_int64("ui surface frame next dirty",
              er_ui_surface_frame_dirty_tiles(&frame_state, &tile_plan, &scene, &next_scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface frame next count", dirty_tiles.count, 3u);
  check_int64("ui surface frame same dirty",
              er_ui_surface_frame_dirty_tiles(&frame_state, &tile_plan, &scene, &scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface frame same count", dirty_tiles.count, 0u);
  check_int64("ui surface render empty dirty tile list",
              er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              1);
  check_uint64("ui surface empty dirty requested", stats.dirty_tiles_requested, 0u);
  check_uint64("ui surface empty dirty rendered", stats.tiles_rendered, 0u);
  check_uint64("ui surface empty dirty bytes", stats.bytes_written, 0u);
  next_scene.clear = er_ui_color_rgb_u8(1u, 1u, 1u);
  check_int64("ui surface dirty reset for clear diff", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui surface dirty mark clear diff",
              er_ui_surface_dirty_tiles_mark_scene_diff(&tile_plan, &scene, &next_scene,
                                                    tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty clear diff count", dirty_tiles.count, 4u);

  rects[0] = er_ui_rect_fill(0.0f, 0.0f, 1.0f, 1.0f, 0.0f, er_ui_color_rgba_u8(255u, 0u, 0u, 128u));
  check_int64("ui surface render alpha fill", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface alpha over clear", pixels[0], 0x00800000u);

  surface.width = 4u;
  surface.height = 4u;
  surface.stride = 4u;
  rects[0] = er_ui_rect_border(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, er_ui_color_rgb_u8(0u, 255u, 0u));
  check_int64("ui surface render border", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface border top", pixels[1], 0x0000ff00u);
  check_pixel("ui surface border left", pixels[4], 0x0000ff00u);
  check_pixel("ui surface border center clear", pixels[5], 0u);
  check_pixel("ui surface border right", pixels[7], 0x0000ff00u);
  check_pixel("ui surface border bottom", pixels[14], 0x0000ff00u);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui surface tile plan 4x4", er_ui_surface_tile_plan(&surface, 2u, 2u, 4u, &tile_plan), 1);
  rects[0] = er_ui_rect_fill(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, er_ui_color_rgb_u8(255u, 0u, 0u));
  check_int64("ui surface render one tile",
              er_ui_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 3u, &stats),
              1);
  check_pixel("ui surface tile outside top left", pixels[0], 0x00abcdefu);
  check_pixel("ui surface tile outside top right", pixels[3], 0x00abcdefu);
  check_pixel("ui surface tile inside bottom right a", pixels[10], 0x00ff0000u);
  check_pixel("ui surface tile inside bottom right b", pixels[15], 0x00ff0000u);
  check_uint64("ui surface tile render clears", stats.clears, 1u);
  check_uint64("ui surface tile render pixels", stats.pixels_written, 8u);
  check_uint64("ui surface tile render count", stats.tiles_rendered, 1u);
  check_uint64("ui surface tile render clipped", stats.clipped_primitives, 1u);
  check_uint64("ui surface tile render rejected", stats.rejected_primitives, 0u);
  tile_ids[0] = 0u;
  tile_ids[1] = 3u;
  dirty_tiles.tile_ids = tile_ids;
  dirty_tiles.capacity = 4u;
  dirty_tiles.count = 2u;
  dirty_tiles.overflowed = 0u;
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui surface render dirty tile list",
              er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              1);
  check_pixel("ui surface dirty list top left", pixels[0], 0x00ff0000u);
  check_pixel("ui surface dirty list top right untouched", pixels[3], 0x00abcdefu);
  check_pixel("ui surface dirty list bottom left untouched", pixels[8], 0x00abcdefu);
  check_pixel("ui surface dirty list bottom right", pixels[15], 0x00ff0000u);
  check_uint64("ui surface dirty list clears", stats.clears, 2u);
  check_uint64("ui surface dirty list pixels", stats.pixels_written, 16u);
  check_uint64("ui surface dirty list tiles", stats.tiles_rendered, 2u);
  check_uint64("ui surface dirty list requested", stats.dirty_tiles_requested, 2u);
  check_uint64("ui surface dirty list clipped", stats.clipped_primitives, 2u);
  dirty_tiles.overflowed = 1u;
  check_int64("ui surface reject overflowed dirty list",
              er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              0);
  check_uint64("ui surface reject overflowed dirty stats", stats.pixels_written, 0u);
  dirty_tiles.overflowed = 0u;
  tile_plan.width = 3u;
  check_int64("ui surface reject mismatched tile plan",
              er_ui_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 3u, &stats),
              0);
  check_uint64("ui surface reject tile stats zero", stats.pixels_written, 0u);

  surface.width = 3u;
  surface.height = 1u;
  surface.stride = 3u;
  rects[0] = er_ui_rect_linear_gradient(0.0f, 0.0f, 3.0f, 1.0f, 0.0f,
                                        er_ui_color_rgb_u8(255u, 0u, 0u),
                                        er_ui_color_rgb_u8(0u, 0u, 255u));
  check_int64("ui surface render gradient", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface gradient left", pixels[0], 0x00ff0000u);
  check_pixel("ui surface gradient middle", pixels[1], 0x00800080u);
  check_pixel("ui surface gradient right", pixels[2], 0x000000ffu);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui surface tile plan 3x1", er_ui_surface_tile_plan(&surface, 1u, 1u, 3u, &tile_plan), 1);
  check_int64("ui surface render gradient tile",
              er_ui_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 1u, &stats),
              1);
  check_pixel("ui surface gradient tile outside left", pixels[0], 0x00abcdefu);
  check_pixel("ui surface gradient tile middle", pixels[1], 0x00800080u);
  check_pixel("ui surface gradient tile outside right", pixels[2], 0x00abcdefu);
  check_uint64("ui surface gradient tile clipped", stats.clipped_primitives, 1u);

  {
    UINT8 atlas_bytes[3] = {80u, 128u, 180u};
    ErUiAlphaAtlas atlas;
    er_ui_quad_t text_quads[1];

    atlas.pixels = atlas_bytes;
    atlas.width = 3u;
    atlas.height = 1u;
    atlas.bytes_per_pixel = 1u;
    text_quads[0] = er_ui_quad_atlas(0.0f, 0.0f, 3.0f, 1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0u,
                                     er_ui_color_rgb_u8(255u, 255u, 255u));
    scene.rect_count = 0u;
    scene.text_quads = text_quads;
    scene.text_quad_count = 1u;
    scene.text_quad_capacity = 1u;
    check_int64("ui surface render alpha atlas", er_ui_surface_render_scene_with_atlas(&surface, &scene, &atlas), 1);
    check_pixel("ui surface alpha low", pixels[0], 0x00505050u);
    check_pixel("ui surface alpha middle", pixels[1], 0x00808080u);
    check_pixel("ui surface alpha high", pixels[2], 0x00b4b4b4u);
    scene.text_quads = 0;
    scene.text_quad_count = 0u;
    scene.text_quad_capacity = 0u;
  }

  surface.pixels = 0;
  check_int64("ui surface invalid surface", er_ui_surface_valid(&surface), 0);
  check_int64("ui surface reject invalid surface", er_ui_surface_render_scene(&surface, &scene), 0);
  check_int64("ui surface reject invalid tile plan", er_ui_surface_tile_plan(&surface, 128u, 64u, 256u, &tile_plan), 0);
}

static void test_ui_surface_renderer_4k_tile_plan(void) {
  UINT32 pixel = 0u;
  ErUiSurface surface;
  ErUiSurfaceMode mode;
  ErUiSurfaceTilePlan plan;
  ErUiSurfaceBandwidthPlan bandwidth;
  ErUiSurfaceMemoryPlan memory;
  ErUiSurfaceFrameBudget budget;

  surface.pixels = &pixel;
  surface.width = 3840u;
  surface.height = 2160u;
  surface.stride = 3840u;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  mode.width = 3840u;
  mode.height = 2160u;
  mode.stride = 3840u;
  mode.refresh_hz = 120u;
  mode.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui surface 4k mode tile plan", er_ui_surface_tile_plan_from_mode(&mode, 128u, 64u, 256u, &plan), 1);
  check_uint64("ui surface 4k mode frame bytes", plan.full_frame_bytes, 33177600u);
  check_int64("ui surface 4k bandwidth plan", er_ui_surface_bandwidth_plan_from_mode(&mode, 4u, &bandwidth), 1);
  check_uint64("ui surface 4k bandwidth scanout", bandwidth.scanout_bytes_per_second, 3981312000u);
  check_uint64("ui surface 4k bandwidth full frame", bandwidth.full_frame_bytes_per_second, 3981312000u);
  check_uint64("ui surface 4k bandwidth budget", bandwidth.budget_bytes_per_second, 15925248000u);
  check_int64("ui surface 4k tile plan", er_ui_surface_tile_plan(&surface, 128u, 64u, 256u, &plan), 1);
  check_uint64("ui surface 4k tile columns", plan.columns, 30u);
  check_uint64("ui surface 4k tile rows", plan.rows, 34u);
  check_uint64("ui surface 4k tile count", plan.tile_count, 1020u);
  check_uint64("ui surface 4k frame bytes", plan.full_frame_bytes, 33177600u);
  check_uint64("ui surface 4k scanout bytes", plan.scanout_bytes, 33177600u);
  check_uint64("ui surface 4k max tile bytes", plan.max_tile_bytes, 32768u);
  check_uint64("ui surface 4k tile state bytes", plan.tile_state_bytes, 1020u);
  check_uint64("ui surface 4k dirty queue bytes", plan.dirty_queue_bytes, 1024u);
  check_int64("ui surface 4k memory plan",
              er_ui_surface_memory_plan_from_tile_plan(&plan, 1u, 262144u, 1048576u, 0u, &memory),
              1);
  check_uint64("ui surface 4k memory scanout", memory.scanout_bytes, 33177600u);
  check_uint64("ui surface 4k memory backing", memory.backing_bytes, 33177600u);
  check_uint64("ui surface 4k memory tile state", memory.tile_state_bytes, 1020u);
  check_uint64("ui surface 4k memory dirty queue", memory.dirty_queue_bytes, 1024u);
  check_uint64("ui surface 4k memory total", memory.total_bytes, 67667964u);
  budget = er_ui_surface_frame_budget_from_plan(&plan, er_ui_scene_budget_native_interactive_frame(), 4u);
  check_uint64("ui surface 4k budget pixels", budget.pixels_written, 33177600u);
  check_uint64("ui surface 4k budget bytes", budget.bytes_written, 132710400u);
  check_uint64("ui surface 4k budget text pixels", budget.text_pixels, 8294400u);
  check_uint64("ui surface 4k budget tiles", budget.tiles_rendered, 1020u);
  check_uint64("ui surface 4k budget dirty", budget.dirty_tiles_requested, 256u);
  check_uint64("ui surface 4k budget clipped", budget.clipped_primitives, 11424000u);
  check_int64("ui surface reject zero tile width", er_ui_surface_tile_plan(&surface, 0u, 64u, 256u, &plan), 0);
  check_int64("ui surface reject zero dirty budget", er_ui_surface_tile_plan(&surface, 128u, 64u, 0u, &plan), 0);
}

static void test_ui_surface_renderer_varfont_text(void) {
  vr_font_config_t cfg;
  vr_font_face_t* font = 0;
  vr_font_atlas_view_t atlas;
  er_ui_scene_t scene;
  UINT32 codepoints[5] = {'H', 'e', 'l', 'l', 'o'};
  UINT32 pixels[512u * 160u] = {0};
  ErUiSurface surface;
  UINTN i;
  UINTN lit_pixels = 0;

  cfg.px_size = 56.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = 2u;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = test_vr_allocator();
  cfg.gl.user = 0;
  cfg.gl.create_texture = 0;
  cfg.gl.update_texture = 0;
  cfg.gl.destroy_texture = 0;

  check_int64("ui text font create",
              vr_font_face_create_from_memory(&font, g_er_font_geist_ttf, ER_FONT_GEIST_TTF_SIZE, &cfg),
              VR_OK);
  if (font == 0) {
    return;
  }

  check_int64("ui text scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u), test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui text push",
              er_ui_scene_push_varfont_text(&scene, font, codepoints, 5u, 20.0f, 90.0f, er_ui_color_rgb_u8(255u, 255u, 255u)),
              ER_UI_OK);
  check_int64("ui text emits quads", scene.text_quad_count > 0u, 1);
  check_int64("ui text atlas exists", vr_font_atlas_count(font) > 0u, 1);
  check_int64("ui text atlas view", vr_font_atlas_view(font, 0u, &atlas), VR_OK);
  check_int64("ui text atlas alpha format", atlas.format, VR_FONT_ATLAS_FORMAT_ALPHA8);
  check_int64("ui text atlas bytes", atlas.bytes_per_pixel, 1);

  surface.pixels = pixels;
  surface.width = 512u;
  surface.height = 160u;
  surface.stride = 512u;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui text render", er_ui_surface_render_scene_with_font(&surface, &scene, font), 1);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    if (pixels[i] != 0u) {
      ++lit_pixels;
    }
  }
  check_int64("ui text render lit pixels", lit_pixels > 0u, 1);

  er_ui_scene_destroy(&scene);
  vr_font_face_destroy(font);
}

static void test_ui_ledger_app_switching(void) {
  er_ui_ledger_app_state_t apps;
  er_ui_runtime_state_t runtime;
  er_ui_scene_t scene;
  er_ui_scene_stats_t stats;
  er_ui_bounds_t focused;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  vr_font_config_t cfg;
  vr_font_face_t* font = 0;
  er_ui_action_t down;
  er_ui_action_t up;
  bool changed = false;

  cfg.px_size = 24.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = 2u;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = test_vr_allocator();
  cfg.gl.user = 0;
  cfg.gl.create_texture = 0;
  cfg.gl.update_texture = 0;
  cfg.gl.destroy_texture = 0;

  check_int64("ui ledger font create",
              vr_font_face_create_from_memory(&font, g_er_font_geist_ttf, ER_FONT_GEIST_TTF_SIZE, &cfg),
              VR_OK);
  if (font == 0) {
    return;
  }

  check_int64("ui ledger state init", er_ui_ledger_app_state_init(&apps, test_ui_allocator()), ER_UI_OK);
  check_uint64("ui ledger app count", er_ui_workspace_surface_count(&apps.shell), 3u);
  check_uint64("ui ledger initial focus", er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_LEDGER_APP_LEDGER_ID);
  check_int64("ui ledger focused bounds",
              er_ui_workspace_focused_surface_bounds(&apps.shell, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), &focused),
              1);
  check_int64("ui ledger focused bounds positive", focused.w > 0.0f && focused.h > 0.0f, 1);

  check_int64("ui ledger runtime init", er_ui_runtime_state_init_with_allocator(&runtime, test_ui_allocator()), ER_UI_OK);
  check_int64("ui ledger scene init",
              er_ui_scene_init_with_allocator(&scene, theme.colors.bg, test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui ledger emit",
              er_ui_ledger_app_emit_scene(&apps, &scene, font, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), theme),
              ER_UI_OK);
  stats = er_ui_scene_stats(&scene);
  check_int64("ui ledger emits rects", stats.rects > 0u, 1);
  check_uint64("ui ledger emits hits", stats.hits, 6u);
  check_int64("ui ledger emits text", stats.text_quads > 0u, 1);

  down = er_ui_runtime_pointer_down(&runtime, &scene, 40.0f, 138.0f);
  check_int64("ui ledger nav down focus", down.kind, ER_UI_ACTION_FOCUSED);
  up = er_ui_runtime_pointer_up(&runtime, &scene, 40.0f, 138.0f);
  check_int64("ui ledger nav up select", up.kind, ER_UI_ACTION_TAB_SELECTED);
  check_int64("ui ledger apply payments nav", er_ui_ledger_app_apply_action(&apps, up, &changed), ER_UI_OK);
  check_int64("ui ledger tab changed", changed, 1);
  check_uint64("ui ledger payments focus", er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_LEDGER_APP_PAYMENTS_ID);

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_ledger_app_state_destroy(&apps);
  vr_font_face_destroy(font);
}

static void test_ps2_keyboard_set1_decoder(void) {
  ErPs2KeyboardState state = {0};
  ErPs2KeyboardAction action;

  check_int64("ps2 decode tab",
              er_ps2_keyboard_decode_set1(&state, 0x0fu, &action), 1);
  check_int64("ps2 tab action", action.kind, ER_PS2_KEYBOARD_ACTION_UI_KEY);
  check_int64("ps2 tab key", action.key.kind, ER_UI_KEY_TAB);
  check_int64("ps2 tab shift clear", action.modifiers.shift, 0);

  check_int64("ps2 decode shift down",
              er_ps2_keyboard_decode_set1(&state, 0x2au, &action), 1);
  check_int64("ps2 shift down no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);
  check_int64("ps2 decode shifted tab",
              er_ps2_keyboard_decode_set1(&state, 0x0fu, &action), 1);
  check_int64("ps2 shifted tab key", action.key.kind, ER_UI_KEY_TAB);
  check_int64("ps2 shifted tab modifier", action.modifiers.shift, 1);
  check_int64("ps2 decode shift up",
              er_ps2_keyboard_decode_set1(&state, 0xaau, &action), 1);
  check_int64("ps2 shift up no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);

  check_int64("ps2 decode surface 1",
              er_ps2_keyboard_decode_set1(&state, 0x02u, &action), 1);
  check_int64("ps2 surface action", action.kind, ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE);
  check_uint64("ps2 ledger surface", action.surface_id, ER_UI_LEDGER_APP_LEDGER_ID);
  check_int64("ps2 decode surface 2",
              er_ps2_keyboard_decode_set1(&state, 0x03u, &action), 1);
  check_uint64("ps2 payments surface", action.surface_id, ER_UI_LEDGER_APP_PAYMENTS_ID);
  check_int64("ps2 decode surface 3",
              er_ps2_keyboard_decode_set1(&state, 0x04u, &action), 1);
  check_uint64("ps2 access surface", action.surface_id, ER_UI_LEDGER_APP_ACCESS_ID);

  check_int64("ps2 extended prefix",
              er_ps2_keyboard_decode_set1(&state, 0xe0u, &action), 1);
  check_int64("ps2 extended prefix no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);
  check_int64("ps2 extended right arrow",
              er_ps2_keyboard_decode_set1(&state, 0x4du, &action), 1);
  check_int64("ps2 right arrow key", action.key.kind, ER_UI_KEY_ARROW_RIGHT);
  check_int64("ps2 release ignored",
              er_ps2_keyboard_decode_set1(&state, 0xcdu, &action), 1);
  check_int64("ps2 release no action", action.kind, ER_PS2_KEYBOARD_ACTION_NONE);

  check_int64("ps2 decode quit",
              er_ps2_keyboard_decode_set1(&state, 0x10u, &action), 1);
  check_int64("ps2 quit action", action.kind, ER_PS2_KEYBOARD_ACTION_QUIT);
  check_int64("ps2 rejects null state",
              er_ps2_keyboard_decode_set1(0, 0x0fu, &action), 0);
  check_int64("ps2 rejects null action",
              er_ps2_keyboard_decode_set1(&state, 0x0fu, 0), 0);
}

int main(void) {
  test_mem_helpers();
  test_blake3();
  test_bar_decode();
  test_pci_config_addressing();
  test_acpi_tables();
  test_tpm_crb_direct_transport();
  test_pci_device_classification();
  test_mmio_handles();
  test_bus_addresses();
  test_virtio_mmio_transport();
  test_virtio_modern_pci_transport_registers();
  test_virtio_split_queue();
  test_virtio_net_mmio();
  test_virtio_gpu_mmio();
  test_net_frame_builders();
  test_native_eth_endpoint();
  test_wasm_mmio_imports();
  test_wasm_bus_exec_import();
  test_wasm_public_region_imports();
  test_relay_packets();
  test_wasm_relay_imports();
  test_wasm_ui_command_stats_records();
  test_wasm_ui_emit_import();
  test_epoch_clock_rollover();
  test_ui_wasm_app_runner();
  test_ui_wasm_app_multiple_runtimes();
  test_vfs_object_packets();
  test_app_identity_routes();
  test_device_relay_identity();
  test_work_admitted_relay_route();
  test_boot_profiles();
  test_hw_relay_endpoints();
  test_erwire_native_eth_sink();
  test_erwire_parse_and_native_poll();
  test_native_boot_erwire_eth_sink();
  test_netlog_disabled_path();
  test_gfx_console_disabled_path();
  test_ui_surface_renderer_surface();
  test_ui_surface_renderer_4k_tile_plan();
  test_ui_surface_renderer_varfont_text();
  test_ui_ledger_app_switching();
  test_ps2_keyboard_set1_decoder();

  if (g_failed != 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_failed, g_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_total);
  return 0;
}
