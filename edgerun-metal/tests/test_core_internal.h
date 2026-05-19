#ifndef ER_TEST_CORE_INTERNAL_H
#define ER_TEST_CORE_INTERNAL_H

#include "er_mmio.h"
#include "er_mem.h"
#include "er_pci.h"
#include "er_acpi.h"
#include "er_app.h"
#include "er_blake3.h"
#include "er_boot_config.h"
#include "er_boot_admission_record.h"
#include "er_boot_efi_vars.h"
#include "er_boot_profile.h"
#include "er_boot_services.h"
#include "er_ble_adv.h"
#include "er_bus.h"
#include "er_crypto_blake3.h"
#include "er_device_identity.h"
#include "er_epoch_clock.h"
#include "er_firmware_loader.h"
#include "er_identity.h"
#include "er_hw_relay.h"
#include "er_native_eth.h"
#include "er_native_boot.h"
#include "er_net_frame.h"
#include "er_netlog.h"
#include "er_ps2_keyboard.h"
#include "er_relay_packet.h"
#include "er_render_endpoint.h"
#include "er_rtw89.h"
#include "er_seal.h"
#include "er_storage_endpoint.h"
#include "er_tpm.h"
#include "er_work_route.h"
#include "er_gfx_console.h"
#include "er_ui_surface_renderer.h"
#include "er_ui_tabler_icon_atlas.h"
#include "er_ui_ledger_app.h"
#include "er_ui_wasm_app.h"
#include "er_ui_text.h"
#include "er_virtio.h"
#include "er_virtio_blk.h"
#include "er_virtio_gpu.h"
#include "er_virtio_net.h"
#include "er_vfs.h"
#include "er_wifi_burst.h"
#include "erwire.h"
#include "efi_boot_internal.h"
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

#endif
