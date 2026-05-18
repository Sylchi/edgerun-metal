#include "test_core_internal.h"

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
  check_int64("pci device", er_pci_device_id(0x892210ecu), 0x8922);
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
  check_int64("pci classify rtl8922ae", er_pci_classify_target(0x892210ecu, 0x02800000u), ER_PCI_TARGET_KIND_WIFI);
  check_int64("pci classify rtl8922ae vs", er_pci_classify_target(0x892b10ecu, 0x02800000u), ER_PCI_TARGET_KIND_WIFI);
  check_int64("pci classify generic wifi", er_pci_classify_target(0x12348086u, 0x02800000u), ER_PCI_TARGET_KIND_WIFI);
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
