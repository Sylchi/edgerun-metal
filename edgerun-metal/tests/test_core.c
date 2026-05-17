#include "er_mmio.h"
#include "er_pci.h"
#include "er_acpi.h"
#include "er_app.h"
#include "er_bus.h"
#include "er_hw_relay.h"
#include "er_vfs.h"
#include "wasm_vm.h"

/*
 * Purpose: test pure EdgeRun Metal core helpers outside firmware.
 * Intention: catch BAR decode and MMIO handle regressions before real hardware boots.
 */

#include <stdint.h>
#include <stdio.h>

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
  check_int64("mmio read request reject bad handle", er_mmio_read32_request_valid(2, 0), 0);
  check_int64("mmio read request reject unaligned", er_mmio_read32_request_valid(handle, 2), 0);
  check_int64("mmio read request reject out of range", er_mmio_read32_request_valid(handle, 8), 0);
  check_uint64("mmio read0", (UINT64)er_mmio_read32(handle, 0), 0x11223344u);
  check_uint64("mmio read4", (UINT64)er_mmio_read32(handle, 4), 0xaabbccddu);
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
  ErBusAddress ioport;
  ErBusOp32 op;
  ErBusPacket32 request;
  ErBusPacket32 response;
  UINT32 value = 0;

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
                                            ER_BUS_ACCESS_READ32 | ER_BUS_ACCESS_WRITE32, &mmio),
              1);
  check_int64("bus mmio kind", mmio.bus_kind, ER_BUS_KIND_MMIO32);
  check_int64("bus mmio supports read", er_bus_address_supports(&mmio, ER_BUS_ACCESS_READ32), 1);
  check_int64("bus mmio supports write", er_bus_address_supports(&mmio, ER_BUS_ACCESS_WRITE32), 1);
  check_int64("bus mmio reject short",
              er_bus_prepare_mmio32_address((UINT64)(UINTN)regs, 3u, 0u, ER_BUS_ACCESS_READ32, &mmio),
              0);

  check_int64("bus io port address",
              er_bus_prepare_io_port_address(0x0cf8u, ER_BUS_ACCESS_READ32 | ER_BUS_ACCESS_WRITE32, &ioport),
              1);
  check_int64("bus io port kind", ioport.bus_kind, ER_BUS_KIND_IO_PORT);
  check_uint64("bus io port number", ioport.port, 0x0cf8u);
  check_int64("bus io port reject unaligned",
              er_bus_prepare_io_port_address(0x0cf9u, ER_BUS_ACCESS_READ32, &ioport),
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
  check_int64("bus mmio write", er_bus_write32(&mmio, 4u, 0x55667788u), 1);
  check_uint64("bus mmio write value", regs[1], 0x55667788u);

  mmio.access_flags = ER_BUS_ACCESS_READ32;
  check_int64("bus mmio write denied", er_bus_write32(&mmio, 4u, 0x99u), 0);

  check_int64("bus packet read prepare",
              er_bus_prepare_op32_packet(7u, &mmio, ER_BUS_ACCESS_READ32, 0u, 0u, &request),
              1);
  check_int64("bus packet kind", request.packet_kind, ER_BUS_PACKET_OP32_REQUEST);
  check_uint64("bus packet id", request.packet_id, 7u);
  check_int64("bus packet execute read", er_bus_execute_op32_packet(&request, &response), 1);
  check_int64("bus packet response kind", response.packet_kind, ER_BUS_PACKET_OP32_RESPONSE);
  check_int64("bus packet response ok", response.status, ER_BUS_STATUS_OK);
  check_uint64("bus packet response value", response.result, 0x11223344u);

  mmio.access_flags = ER_BUS_ACCESS_READ32 | ER_BUS_ACCESS_WRITE32;
  check_int64("bus packet write prepare",
              er_bus_prepare_op32_packet(8u, &mmio, ER_BUS_ACCESS_WRITE32, 4u, 0x01010101u, &request),
              1);
  check_int64("bus packet execute write", er_bus_execute_op32_packet(&request, &response), 1);
  check_uint64("bus packet write value", regs[1], 0x01010101u);

  check_int64("bus packet reject invalid",
              er_bus_prepare_op32_packet(9u, &mmio, ER_BUS_ACCESS_READ32, 2u, 0u, &request),
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

int main(void) {
  test_bar_decode();
  test_pci_config_addressing();
  test_acpi_tables();
  test_pci_device_classification();
  test_mmio_handles();
  test_bus_addresses();
  test_wasm_mmio_imports();
  test_vfs_object_packets();
  test_app_identity_routes();
  test_hw_relay_endpoints();

  if (g_failed != 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_failed, g_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_total);
  return 0;
}
