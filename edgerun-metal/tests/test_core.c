#include "er_mmio.h"
#include "er_pci.h"
#include "er_acpi.h"
#include "er_app.h"
#include "er_bus.h"
#include "er_hw_relay.h"
#include "er_ui_gop_renderer.h"
#include "er_ui_text.h"
#include "er_vfs.h"
#include "font_geist.h"
#include "wasm_vm.h"
#include "wasm_driver_bus_probe_module.h"

/*
 * Purpose: test pure EdgeRun Metal core helpers outside firmware.
 * Intention: catch BAR decode and MMIO handle regressions before real hardware boots.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static int g_failed = 0;
static int g_total = 0;

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
  for (i = 0; i < ER_MMIO_MAX_MAPS; ++i) {
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
  check_uint64("bus io packet read8 result", io_response.result, 0x55u);
  check_int64("bus io packet reject width access mismatch",
              er_bus_prepare_io_packet(11u, &mmio, ER_BUS_ACCESS_READ16, 1u, 1u, 0u, &io_request),
              0);
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
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 result = 0;

  host.bus_exec = test_vm_bus_exec;
  host.memory = memory;
  host.memory_size = (UINT32)sizeof(memory);

  check_int64("wasm bus init",
              er_wasm_init(&module, g_edgerun_driver_bus_probe_wasm,
                           ER_DRIVER_BUS_PROBE_WASM_SIZE, &host),
              0);
  check_int64("wasm bus memory min", module.memory_min_pages, 1);
  check_int64("wasm bus find main", er_wasm_find_main(&module, &main_index), 0);
  check_int64("wasm bus main index", main_index, 1);

  check_int64("wasm bus execute", er_wasm_execute_i64(&module, main_index, &result), 0);
  check_uint64("wasm bus result", (UINT64)result, 0x5au);
}

static void test_vfs_object_packets(void) {
  static const UINT8 object_bytes[] = {'a', 'b', 'c', 'd', 'e', 'f'};
  ErCryptoProvider crypto;
  ErVfsObjectPacket packet;
  ErVfsFileRef ref;
  ErVfsObjectTransformRef transform;

  crypto.ctx = (void*)(UINTN)5u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  check_int64("vfs path valid", er_vfs_path_label_valid("app/data.bin", 12), 1);
  check_int64("vfs path reject empty", er_vfs_path_label_valid("", 0), 0);
  check_int64("vfs path reject absolute", er_vfs_path_label_valid("/app/data.bin", 13), 0);
  check_int64("vfs path reject parent", er_vfs_path_label_valid("app/../data.bin", 15), 0);
  check_int64("vfs path reject backslash", er_vfs_path_label_valid("app\\data.bin", 12), 0);

  check_int64("vfs object packet", er_vfs_prepare_object_packet(&crypto, object_bytes, sizeof(object_bytes), 2, 1, 3, &packet), 1);
  check_int64("vfs packet abi", packet.header.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs packet index", packet.header.packet_index, 1);
  check_int64("vfs packet count", packet.header.packet_count, 3);
  check_uint64("vfs packet object len", packet.header.object_len, sizeof(object_bytes));
  check_uint64("vfs packet offset", packet.header.offset, 2);
  check_uint64("vfs packet bytes len", packet.header.bytes_len, 4);
  check_int64("vfs packet byte0", packet.bytes[0], 'c');
  check_int64("vfs packet byte3", packet.bytes[3], 'f');

  check_int64("vfs file ref", er_vfs_prepare_file_ref(&crypto, "app/data.bin", 12, object_bytes, sizeof(object_bytes), &ref), 1);
  check_int64("vfs file ref abi", ref.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs file ref path len", ref.path_len, 12);
  check_uint64("vfs file ref object len", ref.object_len, sizeof(object_bytes));

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
  ErHash app_object_id;
  ErHash manifest_hash;
  ErHash admission_id;
  ErHash capability_id;
  ErHash route_hash;
  ErNodeId target_node_id;
  ErAppIdentity identity;
  ErAppIpcRouteBinding binding;
  ErAppBudget budget;
  ErAppUsage usage;
  ErAppScheduleSlot slot;
  ErAppLaunchAllocation allocation;
  UINT8 nonce[ER_APP_INSTANCE_NONCE_LEN];
  UINTN i;

  crypto.ctx = (void*)(UINTN)9u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  for (i = 0; i < ER_HASH_LEN; ++i) {
    app_object_id.bytes[i] = (UINT8)(0x10u + i);
    manifest_hash.bytes[i] = (UINT8)(0x30u + i);
    admission_id.bytes[i] = (UINT8)(0x50u + i);
    capability_id.bytes[i] = (UINT8)(0x70u + i);
    route_hash.bytes[i] = (UINT8)(0x90u + i);
    target_node_id.bytes[i] = (UINT8)(0xb0u + i);
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
}

static void test_hw_relay_endpoints(void) {
  ErChannelEndpoint endpoint;
  ErRelayForwardIntent intent;
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
}

static void test_ui_gop_renderer_surface(void) {
  UINT32 pixels[24] = {0};
  ErUiGopSurface surface;
  ErUiGopRenderStats stats;
  ErUiGopFrameBudget frame_budget;
  ErUiGopFrameBudgetViolation frame_violation;
  ErUiGopMode mode;
  ErUiGopBandwidthPlan bandwidth_plan;
  ErUiGopTilePlan tile_plan;
  ErUiGopMemoryPlan memory_plan;
  ErUiGopMemoryBudget memory_budget;
  ErUiGopMemoryBudgetViolation memory_violation;
  ErUiGopDirtyTileList dirty_tiles;
  UINT8 tile_marks[4] = {9u, 9u, 9u, 9u};
  UINT32 tile_ids[4] = {0};
  er_ui_rect_t rects[3];
  er_ui_rect_t next_rects[1];
  er_ui_scene_t scene;
  er_ui_scene_t next_scene;
  ErUiGopPixelRect tile_rect;
  ErUiGopFrameState frame_state;
  UINT32 rgb_red = er_ui_gop_pack_rgb(ER_UI_GOP_PIXEL_RGBX, 255u, 0u, 0u);
  UINT32 bgr_red = er_ui_gop_pack_rgb(ER_UI_GOP_PIXEL_BGRX, 255u, 0u, 0u);
  UINTN i;

  check_pixel("ui gop pack rgb red", rgb_red, 0x00ff0000u);
  check_pixel("ui gop pack bgr red", bgr_red, 0x000000ffu);

  surface.pixels = pixels;
  surface.width = 3u;
  surface.height = 2u;
  surface.stride = 4u;
  surface.pixel_format = ER_UI_GOP_PIXEL_RGBX;
  check_int64("ui gop surface valid", er_ui_gop_surface_valid(&surface), 1);
  check_int64("ui gop surface clear", er_ui_gop_surface_clear(&surface, er_ui_color_rgb_u8(1u, 2u, 3u)), 1);
  check_pixel("ui gop clear first", pixels[0], 0x00010203u);
  check_pixel("ui gop clear row end", pixels[2], 0x00010203u);
  check_pixel("ui gop clear stride untouched", pixels[3], 0u);
  check_pixel("ui gop clear second row", pixels[4], 0x00010203u);
  mode.width = 3u;
  mode.height = 2u;
  mode.stride = 4u;
  mode.refresh_hz = 120u;
  mode.pixel_format = ER_UI_GOP_PIXEL_RGBX;
  check_int64("ui gop mode valid", er_ui_gop_mode_valid(&mode), 1);
  check_int64("ui gop mode tile plan", er_ui_gop_tile_plan_from_mode(&mode, 2u, 1u, 4u, &tile_plan), 1);
  check_uint64("ui gop mode tile scanout bytes", tile_plan.scanout_bytes, 32u);
  check_int64("ui gop bandwidth plan", er_ui_gop_bandwidth_plan_from_mode(&mode, 4u, &bandwidth_plan), 1);
  check_uint64("ui gop bandwidth scanout", bandwidth_plan.scanout_bytes_per_second, 3840u);
  check_uint64("ui gop bandwidth full frame", bandwidth_plan.full_frame_bytes_per_second, 2880u);
  check_uint64("ui gop bandwidth budget", bandwidth_plan.budget_bytes_per_second, 11520u);
  check_int64("ui gop bandwidth reject zero overdraw", er_ui_gop_bandwidth_plan_from_mode(&mode, 0u, &bandwidth_plan), 0);
  check_uint64("ui gop bandwidth reject zeroes output", bandwidth_plan.budget_bytes_per_second, 0u);
  mode.refresh_hz = 0u;
  check_int64("ui gop reject zero refresh mode", er_ui_gop_mode_valid(&mode), 0);
  check_int64("ui gop reject invalid mode plan", er_ui_gop_tile_plan_from_mode(&mode, 2u, 1u, 4u, &tile_plan), 0);
  check_int64("ui gop tile plan", er_ui_gop_tile_plan(&surface, 2u, 1u, 4u, &tile_plan), 1);
  check_uint64("ui gop tile columns", tile_plan.columns, 2u);
  check_uint64("ui gop tile rows", tile_plan.rows, 2u);
  check_uint64("ui gop tile count", tile_plan.tile_count, 4u);
  check_uint64("ui gop tile scanout bytes", tile_plan.scanout_bytes, 32u);
  check_uint64("ui gop tile frame bytes", tile_plan.full_frame_bytes, 24u);
  check_uint64("ui gop tile max bytes", tile_plan.max_tile_bytes, 8u);
  check_uint64("ui gop tile state bytes", tile_plan.tile_state_bytes, 4u);
  check_uint64("ui gop tile dirty queue bytes", tile_plan.dirty_queue_bytes, 16u);
  check_int64("ui gop memory plan",
              er_ui_gop_memory_plan_from_tile_plan(&tile_plan, 1u, 64u, 128u, 256u, &memory_plan),
              1);
  check_uint64("ui gop memory scanout", memory_plan.scanout_bytes, 32u);
  check_uint64("ui gop memory backing", memory_plan.backing_bytes, 32u);
  check_uint64("ui gop memory tile state", memory_plan.tile_state_bytes, 4u);
  check_uint64("ui gop memory dirty queue", memory_plan.dirty_queue_bytes, 16u);
  check_uint64("ui gop memory commands", memory_plan.command_bytes, 64u);
  check_uint64("ui gop memory glyph cache", memory_plan.glyph_cache_bytes, 128u);
  check_uint64("ui gop memory surfaces", memory_plan.surface_bytes, 256u);
  check_uint64("ui gop memory total", memory_plan.total_bytes, 532u);
  memory_budget.scanout_bytes = 32u;
  memory_budget.backing_bytes = 32u;
  memory_budget.tile_state_bytes = 4u;
  memory_budget.dirty_queue_bytes = 16u;
  memory_budget.command_bytes = 64u;
  memory_budget.glyph_cache_bytes = 128u;
  memory_budget.surface_bytes = 256u;
  memory_budget.total_bytes = 532u;
  check_int64("ui gop memory fits exact budget", er_ui_gop_memory_plan_fits_budget(memory_plan, memory_budget), 1);
  memory_budget.glyph_cache_bytes = 127u;
  check_int64("ui gop memory first budget violation",
              er_ui_gop_memory_plan_first_budget_violation(memory_plan, memory_budget, &memory_violation),
              1);
  check_cstr("ui gop memory budget violation name", memory_violation.name, "glyph_cache_bytes");
  check_uint64("ui gop memory budget violation actual", memory_violation.actual, 128u);
  check_uint64("ui gop memory budget violation limit", memory_violation.limit, 127u);
  check_int64("ui gop memory rejects over budget", er_ui_gop_memory_plan_fits_budget(memory_plan, memory_budget), 0);
  check_int64("ui gop memory reject overflow",
              er_ui_gop_memory_plan_from_tile_plan(&tile_plan, 1u, 0xffffffffffffffffull, 0u, 0u, &memory_plan),
              0);
  check_uint64("ui gop memory overflow zeroes output", memory_plan.total_bytes, 0u);
  frame_budget = er_ui_gop_frame_budget_from_plan(&tile_plan, er_ui_scene_budget_native_interactive_frame(), 4u);
  check_uint64("ui gop derived budget pixels", frame_budget.pixels_written, 24u);
  check_uint64("ui gop derived budget bytes", frame_budget.bytes_written, 96u);
  check_uint64("ui gop derived budget rects", frame_budget.rects, 2000u);
  check_uint64("ui gop derived budget text", frame_budget.text_quads, 8000u);
  check_uint64("ui gop derived budget tiles", frame_budget.tiles_rendered, 4u);
  check_uint64("ui gop derived budget dirty", frame_budget.dirty_tiles_requested, 4u);
  check_uint64("ui gop derived budget clipped", frame_budget.clipped_primitives, 40000u);
  frame_budget = er_ui_gop_frame_budget_from_plan(&tile_plan, er_ui_scene_budget_native_interactive_frame(), 0u);
  check_uint64("ui gop reject zero overdraw budget", frame_budget.bytes_written, 0u);
  check_int64("ui gop tile rect", er_ui_gop_tile_rect(&tile_plan, 3u, &tile_rect), 1);
  check_uint64("ui gop tile rect x0", tile_rect.x0, 2u);
  check_uint64("ui gop tile rect y0", tile_rect.y0, 1u);
  check_uint64("ui gop tile rect x1", tile_rect.x1, 3u);
  check_uint64("ui gop tile rect y1", tile_rect.y1, 2u);
  dirty_tiles.tile_ids = tile_ids;
  dirty_tiles.capacity = 4u;
  dirty_tiles.count = 99u;
  dirty_tiles.overflowed = 1u;
  check_int64("ui gop dirty reset", er_ui_gop_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_uint64("ui gop dirty reset count", dirty_tiles.count, 0u);
  check_uint64("ui gop dirty reset mark", tile_marks[0], 0u);
  check_int64("ui gop dirty mark clipped rect",
              er_ui_gop_dirty_tiles_mark_rect(&tile_plan, -1.0f, 0.0f, 3.0f, 2.0f, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop dirty count", dirty_tiles.count, 2u);
  check_uint64("ui gop dirty first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui gop dirty second", dirty_tiles.tile_ids[1], 2u);
  check_uint64("ui gop dirty duplicate count before", dirty_tiles.count, 2u);
  check_int64("ui gop dirty mark duplicate",
              er_ui_gop_dirty_tiles_mark_rect(&tile_plan, 0.0f, 0.0f, 1.0f, 1.0f, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop dirty duplicate count after", dirty_tiles.count, 2u);

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
  check_int64("ui gop render clipped fill", er_ui_gop_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui gop clipped fill x0", pixels[0], 0x000a141eu);
  check_pixel("ui gop clipped fill x1", pixels[1], 0x000a141eu);
  check_pixel("ui gop clipped fill x2 clear", pixels[2], 0u);
  check_int64("ui gop render stats", er_ui_gop_surface_render_scene_with_font_stats(&surface, &scene, 0, &stats), 1);
  check_uint64("ui gop stats clear count", stats.clears, 1u);
  check_uint64("ui gop stats rect count", stats.rects, 1u);
  check_uint64("ui gop stats solid count", stats.solid_rects, 1u);
  check_uint64("ui gop stats pixels", stats.pixels_written, 10u);
  check_uint64("ui gop stats bytes", stats.bytes_written, 40u);
  frame_budget.pixels_written = 10u;
  frame_budget.bytes_written = 40u;
  frame_budget.blend_pixels = 0u;
  frame_budget.text_pixels = 0u;
  frame_budget.rects = 1u;
  frame_budget.text_quads = 0u;
  frame_budget.tiles_rendered = 0u;
  frame_budget.dirty_tiles_requested = 0u;
  frame_budget.clipped_primitives = 0u;
  frame_budget.rejected_primitives = 0u;
  check_int64("ui gop stats fit exact budget", er_ui_gop_render_stats_fits_budget(stats, frame_budget), 1);
  frame_budget.bytes_written = 39u;
  check_int64("ui gop stats first budget violation",
              er_ui_gop_render_stats_first_budget_violation(stats, frame_budget, &frame_violation),
              1);
  check_cstr("ui gop stats budget violation name", frame_violation.name, "bytes_written");
  check_uint64("ui gop stats budget violation actual", frame_violation.actual, 40u);
  check_uint64("ui gop stats budget violation limit", frame_violation.limit, 39u);
  check_int64("ui gop stats reject over budget", er_ui_gop_render_stats_fits_budget(stats, frame_budget), 0);
  check_int64("ui gop dirty reset for scene", er_ui_gop_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui gop dirty mark scene",
              er_ui_gop_dirty_tiles_mark_scene(&tile_plan, &scene, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop dirty scene count", dirty_tiles.count, 2u);
  check_uint64("ui gop dirty scene first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui gop dirty scene second", dirty_tiles.tile_ids[1], 2u);
  er_ui_gop_frame_state_reset(&frame_state);
  check_int64("ui gop frame first dirty",
              er_ui_gop_frame_dirty_tiles(&frame_state, &tile_plan, 0, &scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop frame first count", dirty_tiles.count, 4u);
  er_ui_gop_frame_state_commit(&frame_state);
  next_rects[0] = er_ui_rect_fill(2.0f, 1.0f, 1.0f, 1.0f, 0.0f, er_ui_color_rgb_u8(40u, 50u, 60u));
  next_scene = scene;
  next_scene.rects = next_rects;
  check_int64("ui gop dirty reset for diff", er_ui_gop_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui gop dirty mark scene diff",
              er_ui_gop_dirty_tiles_mark_scene_diff(&tile_plan, &scene, &next_scene,
                                                    tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop dirty diff count", dirty_tiles.count, 3u);
  check_uint64("ui gop dirty diff old first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui gop dirty diff old second", dirty_tiles.tile_ids[1], 2u);
  check_uint64("ui gop dirty diff new", dirty_tiles.tile_ids[2], 3u);
  check_int64("ui gop frame next dirty",
              er_ui_gop_frame_dirty_tiles(&frame_state, &tile_plan, &scene, &next_scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop frame next count", dirty_tiles.count, 3u);
  check_int64("ui gop frame same dirty",
              er_ui_gop_frame_dirty_tiles(&frame_state, &tile_plan, &scene, &scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop frame same count", dirty_tiles.count, 0u);
  check_int64("ui gop render empty dirty tile list",
              er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              1);
  check_uint64("ui gop empty dirty requested", stats.dirty_tiles_requested, 0u);
  check_uint64("ui gop empty dirty rendered", stats.tiles_rendered, 0u);
  check_uint64("ui gop empty dirty bytes", stats.bytes_written, 0u);
  next_scene.clear = er_ui_color_rgb_u8(1u, 1u, 1u);
  check_int64("ui gop dirty reset for clear diff", er_ui_gop_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui gop dirty mark clear diff",
              er_ui_gop_dirty_tiles_mark_scene_diff(&tile_plan, &scene, &next_scene,
                                                    tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui gop dirty clear diff count", dirty_tiles.count, 4u);

  rects[0] = er_ui_rect_fill(0.0f, 0.0f, 1.0f, 1.0f, 0.0f, er_ui_color_rgba_u8(255u, 0u, 0u, 128u));
  check_int64("ui gop render alpha fill", er_ui_gop_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui gop alpha over clear", pixels[0], 0x00800000u);

  surface.width = 4u;
  surface.height = 4u;
  surface.stride = 4u;
  rects[0] = er_ui_rect_border(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, er_ui_color_rgb_u8(0u, 255u, 0u));
  check_int64("ui gop render border", er_ui_gop_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui gop border top", pixels[1], 0x0000ff00u);
  check_pixel("ui gop border left", pixels[4], 0x0000ff00u);
  check_pixel("ui gop border center clear", pixels[5], 0u);
  check_pixel("ui gop border right", pixels[7], 0x0000ff00u);
  check_pixel("ui gop border bottom", pixels[14], 0x0000ff00u);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui gop tile plan 4x4", er_ui_gop_tile_plan(&surface, 2u, 2u, 4u, &tile_plan), 1);
  rects[0] = er_ui_rect_fill(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, er_ui_color_rgb_u8(255u, 0u, 0u));
  check_int64("ui gop render one tile",
              er_ui_gop_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 3u, &stats),
              1);
  check_pixel("ui gop tile outside top left", pixels[0], 0x00abcdefu);
  check_pixel("ui gop tile outside top right", pixels[3], 0x00abcdefu);
  check_pixel("ui gop tile inside bottom right a", pixels[10], 0x00ff0000u);
  check_pixel("ui gop tile inside bottom right b", pixels[15], 0x00ff0000u);
  check_uint64("ui gop tile render clears", stats.clears, 1u);
  check_uint64("ui gop tile render pixels", stats.pixels_written, 8u);
  check_uint64("ui gop tile render count", stats.tiles_rendered, 1u);
  check_uint64("ui gop tile render clipped", stats.clipped_primitives, 1u);
  check_uint64("ui gop tile render rejected", stats.rejected_primitives, 0u);
  tile_ids[0] = 0u;
  tile_ids[1] = 3u;
  dirty_tiles.tile_ids = tile_ids;
  dirty_tiles.capacity = 4u;
  dirty_tiles.count = 2u;
  dirty_tiles.overflowed = 0u;
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui gop render dirty tile list",
              er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              1);
  check_pixel("ui gop dirty list top left", pixels[0], 0x00ff0000u);
  check_pixel("ui gop dirty list top right untouched", pixels[3], 0x00abcdefu);
  check_pixel("ui gop dirty list bottom left untouched", pixels[8], 0x00abcdefu);
  check_pixel("ui gop dirty list bottom right", pixels[15], 0x00ff0000u);
  check_uint64("ui gop dirty list clears", stats.clears, 2u);
  check_uint64("ui gop dirty list pixels", stats.pixels_written, 16u);
  check_uint64("ui gop dirty list tiles", stats.tiles_rendered, 2u);
  check_uint64("ui gop dirty list requested", stats.dirty_tiles_requested, 2u);
  check_uint64("ui gop dirty list clipped", stats.clipped_primitives, 2u);
  dirty_tiles.overflowed = 1u;
  check_int64("ui gop reject overflowed dirty list",
              er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              0);
  check_uint64("ui gop reject overflowed dirty stats", stats.pixels_written, 0u);
  dirty_tiles.overflowed = 0u;
  tile_plan.width = 3u;
  check_int64("ui gop reject mismatched tile plan",
              er_ui_gop_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 3u, &stats),
              0);
  check_uint64("ui gop reject tile stats zero", stats.pixels_written, 0u);

  surface.width = 3u;
  surface.height = 1u;
  surface.stride = 3u;
  rects[0] = er_ui_rect_linear_gradient(0.0f, 0.0f, 3.0f, 1.0f, 0.0f,
                                        er_ui_color_rgb_u8(255u, 0u, 0u),
                                        er_ui_color_rgb_u8(0u, 0u, 255u));
  check_int64("ui gop render gradient", er_ui_gop_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui gop gradient left", pixels[0], 0x00ff0000u);
  check_pixel("ui gop gradient middle", pixels[1], 0x00800080u);
  check_pixel("ui gop gradient right", pixels[2], 0x000000ffu);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui gop tile plan 3x1", er_ui_gop_tile_plan(&surface, 1u, 1u, 3u, &tile_plan), 1);
  check_int64("ui gop render gradient tile",
              er_ui_gop_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 1u, &stats),
              1);
  check_pixel("ui gop gradient tile outside left", pixels[0], 0x00abcdefu);
  check_pixel("ui gop gradient tile middle", pixels[1], 0x00800080u);
  check_pixel("ui gop gradient tile outside right", pixels[2], 0x00abcdefu);
  check_uint64("ui gop gradient tile clipped", stats.clipped_primitives, 1u);

  {
    UINT8 atlas_bytes[3] = {80u, 128u, 180u};
    ErUiGopAlphaAtlas atlas;
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
    check_int64("ui gop render alpha atlas", er_ui_gop_surface_render_scene_with_atlas(&surface, &scene, &atlas), 1);
    check_pixel("ui gop alpha low", pixels[0], 0x00505050u);
    check_pixel("ui gop alpha middle", pixels[1], 0x00808080u);
    check_pixel("ui gop alpha high", pixels[2], 0x00b4b4b4u);
    scene.text_quads = 0;
    scene.text_quad_count = 0u;
    scene.text_quad_capacity = 0u;
  }

  surface.pixels = 0;
  check_int64("ui gop invalid surface", er_ui_gop_surface_valid(&surface), 0);
  check_int64("ui gop reject invalid surface", er_ui_gop_surface_render_scene(&surface, &scene), 0);
  check_int64("ui gop reject invalid tile plan", er_ui_gop_tile_plan(&surface, 128u, 64u, 256u, &tile_plan), 0);
}

static void test_ui_gop_renderer_4k_tile_plan(void) {
  UINT32 pixel = 0u;
  ErUiGopSurface surface;
  ErUiGopMode mode;
  ErUiGopTilePlan plan;
  ErUiGopBandwidthPlan bandwidth;
  ErUiGopMemoryPlan memory;
  ErUiGopFrameBudget budget;

  surface.pixels = &pixel;
  surface.width = 3840u;
  surface.height = 2160u;
  surface.stride = 3840u;
  surface.pixel_format = ER_UI_GOP_PIXEL_RGBX;
  mode.width = 3840u;
  mode.height = 2160u;
  mode.stride = 3840u;
  mode.refresh_hz = 120u;
  mode.pixel_format = ER_UI_GOP_PIXEL_RGBX;
  check_int64("ui gop 4k mode tile plan", er_ui_gop_tile_plan_from_mode(&mode, 128u, 64u, 256u, &plan), 1);
  check_uint64("ui gop 4k mode frame bytes", plan.full_frame_bytes, 33177600u);
  check_int64("ui gop 4k bandwidth plan", er_ui_gop_bandwidth_plan_from_mode(&mode, 4u, &bandwidth), 1);
  check_uint64("ui gop 4k bandwidth scanout", bandwidth.scanout_bytes_per_second, 3981312000u);
  check_uint64("ui gop 4k bandwidth full frame", bandwidth.full_frame_bytes_per_second, 3981312000u);
  check_uint64("ui gop 4k bandwidth budget", bandwidth.budget_bytes_per_second, 15925248000u);
  check_int64("ui gop 4k tile plan", er_ui_gop_tile_plan(&surface, 128u, 64u, 256u, &plan), 1);
  check_uint64("ui gop 4k tile columns", plan.columns, 30u);
  check_uint64("ui gop 4k tile rows", plan.rows, 34u);
  check_uint64("ui gop 4k tile count", plan.tile_count, 1020u);
  check_uint64("ui gop 4k frame bytes", plan.full_frame_bytes, 33177600u);
  check_uint64("ui gop 4k scanout bytes", plan.scanout_bytes, 33177600u);
  check_uint64("ui gop 4k max tile bytes", plan.max_tile_bytes, 32768u);
  check_uint64("ui gop 4k tile state bytes", plan.tile_state_bytes, 1020u);
  check_uint64("ui gop 4k dirty queue bytes", plan.dirty_queue_bytes, 1024u);
  check_int64("ui gop 4k memory plan",
              er_ui_gop_memory_plan_from_tile_plan(&plan, 1u, 262144u, 1048576u, 0u, &memory),
              1);
  check_uint64("ui gop 4k memory scanout", memory.scanout_bytes, 33177600u);
  check_uint64("ui gop 4k memory backing", memory.backing_bytes, 33177600u);
  check_uint64("ui gop 4k memory tile state", memory.tile_state_bytes, 1020u);
  check_uint64("ui gop 4k memory dirty queue", memory.dirty_queue_bytes, 1024u);
  check_uint64("ui gop 4k memory total", memory.total_bytes, 67667964u);
  budget = er_ui_gop_frame_budget_from_plan(&plan, er_ui_scene_budget_native_interactive_frame(), 4u);
  check_uint64("ui gop 4k budget pixels", budget.pixels_written, 33177600u);
  check_uint64("ui gop 4k budget bytes", budget.bytes_written, 132710400u);
  check_uint64("ui gop 4k budget text pixels", budget.text_pixels, 8294400u);
  check_uint64("ui gop 4k budget tiles", budget.tiles_rendered, 1020u);
  check_uint64("ui gop 4k budget dirty", budget.dirty_tiles_requested, 256u);
  check_uint64("ui gop 4k budget clipped", budget.clipped_primitives, 10200000u);
  check_int64("ui gop reject zero tile width", er_ui_gop_tile_plan(&surface, 0u, 64u, 256u, &plan), 0);
  check_int64("ui gop reject zero dirty budget", er_ui_gop_tile_plan(&surface, 128u, 64u, 0u, &plan), 0);
}

static void test_ui_gop_renderer_varfont_text(void) {
  vr_font_config_t cfg;
  vr_font_face_t* font = 0;
  vr_font_atlas_view_t atlas;
  er_ui_scene_t scene;
  UINT32 codepoints[5] = {'H', 'e', 'l', 'l', 'o'};
  UINT32 pixels[512u * 160u] = {0};
  ErUiGopSurface surface;
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
  surface.pixel_format = ER_UI_GOP_PIXEL_RGBX;
  check_int64("ui text render", er_ui_gop_surface_render_scene_with_font(&surface, &scene, font), 1);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    if (pixels[i] != 0u) {
      ++lit_pixels;
    }
  }
  check_int64("ui text render lit pixels", lit_pixels > 0u, 1);

  er_ui_scene_destroy(&scene);
  vr_font_face_destroy(font);
}

int main(void) {
  test_bar_decode();
  test_pci_config_addressing();
  test_acpi_tables();
  test_pci_device_classification();
  test_mmio_handles();
  test_bus_addresses();
  test_wasm_mmio_imports();
  test_wasm_bus_exec_import();
  test_vfs_object_packets();
  test_app_identity_routes();
  test_hw_relay_endpoints();
  test_ui_gop_renderer_surface();
  test_ui_gop_renderer_4k_tile_plan();
  test_ui_gop_renderer_varfont_text();

  if (g_failed != 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_failed, g_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_total);
  return 0;
}
