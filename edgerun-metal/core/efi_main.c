#include "er_types.h"
#include "er_print.h"
#include "er_pci.h"
#include "er_mmio.h"
#include "er_acpi.h"
#include "erwire.h"
#include "wasm_vm.h"
#include "wasm_test_module.h"
#include "wasm_pci_scan_module.h"

#ifndef ER_BOOT_PROFILE
#define ER_BOOT_PROFILE 0
#endif

#define ER_BOOT_PROFILE_SMOKE 0
#define ER_BOOT_PROFILE_PCI 1
#define ER_BOOT_PROFILE_QUIET 2
#define ER_BOOT_PROFILE_MMIO 3

#define ER_MMIO_PROBE_WINDOW_LEN 0x1000u
#define ER_CONSOLE_MIN_COLUMNS 80u
#define ER_CONSOLE_MIN_ROWS 25u

static ErWasmHostCalls g_host_calls = {0};
static UINT8 g_wasm_driver_memory[65536];
static UINT8 g_log_u64_stage = 0;
static UINT8 g_log_hex_stage = 0;
static UINT64 g_log_bus = 0;
static UINT64 g_log_dev = 0;
static UINT64 g_log_func = 0;

static void er_reset_log_state(void) {
  g_log_u64_stage = 0;
  g_log_hex_stage = 0;
  g_log_bus = 0;
  g_log_dev = 0;
  g_log_func = 0;
}

static void er_print_u64_field(const char* label, UINT64 value) {
  er_print("    ");
  er_print(label);
  er_print(": ");
  er_print_u64_hex(value);
  er_print("\r\n");
}

static void er_log_acpi(EFI_SYSTEM_TABLE* SystemTable) {
  ErAcpiRsdpInfo rsdp;
  ErAcpiTableList tables;
  UINT32 i;

  if (er_acpi_find_rsdp(SystemTable, &rsdp) == 0u) {
    er_println("ACPI: RSDP unavailable");
    return;
  }

  er_print("ACPI: RSDP ");
  er_print_u64_hex(rsdp.rsdp_address);
  er_print(" revision=");
  er_print_u64_dec((UINT64)rsdp.revision);
  er_print(" checksum=");
  er_print_u64_dec((UINT64)rsdp.checksum_valid);
  er_print("\r\n");

  if (er_acpi_enumerate_tables(&rsdp, &tables) == 0u) {
    er_println("ACPI: table enumeration unavailable");
    return;
  }

  er_print("ACPI: tables=");
  er_print_u64_dec((UINT64)tables.table_count);
  er_print(" root=");
  er_print(tables.table_kind == ER_ACPI_TABLE_KIND_XSDT ? "XSDT" : "RSDT");
  er_print("\r\n");

  for (i = 0; i < tables.table_count; ++i) {
    UINT32 sig = tables.tables[i].signature;
    char name[5];

    name[0] = (char)(sig & 0xffu);
    name[1] = (char)((sig >> 8) & 0xffu);
    name[2] = (char)((sig >> 16) & 0xffu);
    name[3] = (char)((sig >> 24) & 0xffu);
    name[4] = 0;
    er_print("  ");
    er_print(name);
    er_print(" ");
    er_print_u64_hex(tables.tables[i].address);
    er_print(" len=");
    er_print_u64_dec((UINT64)tables.tables[i].length);
    er_print(" checksum=");
    er_print_u64_dec((UINT64)tables.tables[i].checksum_valid);
    er_print("\r\n");
  }

  {
    ErAcpiTableInfo fadt_table;
    ErAcpiFadtInfo fadt;

    if (er_acpi_find_table(&tables, er_acpi_signature("FACP"), &fadt_table) != 0u &&
        er_acpi_parse_fadt(fadt_table.address, &fadt) != 0u && fadt.found != 0u) {
      er_print("ACPI: FADT sci=");
      er_print_u64_dec((UINT64)fadt.sci_interrupt);
      er_print(" pm_timer=");
      er_print_u64_hex((UINT64)fadt.pm_timer_block);
      er_print(" reset=");
      er_print_u64_hex(fadt.reset_register.address);
      er_print(" checksum=");
      er_print_u64_dec((UINT64)fadt.checksum_valid);
      er_print("\r\n");
    }
  }

  {
    ErAcpiTableInfo madt_table;
    ErAcpiMadtInfo madt;

    if (er_acpi_find_table(&tables, er_acpi_signature("APIC"), &madt_table) != 0u &&
        er_acpi_parse_madt(madt_table.address, &madt) != 0u && madt.found != 0u) {
      er_print("ACPI: MADT lapic=");
      er_print_u64_hex((UINT64)madt.lapic_address);
      er_print(" cpus=");
      er_print_u64_dec((UINT64)madt.lapic_count);
      er_print(" ioapics=");
      er_print_u64_dec((UINT64)madt.ioapic_count);
      er_print(" iso=");
      er_print_u64_dec((UINT64)madt.interrupt_source_override_count);
      er_print(" checksum=");
      er_print_u64_dec((UINT64)madt.checksum_valid);
      er_print("\r\n");
    }
  }

  {
    ErAcpiTableInfo mcfg_table;
    ErAcpiMcfgInfo mcfg;

    if (er_acpi_find_table(&tables, er_acpi_signature("MCFG"), &mcfg_table) != 0u &&
        er_acpi_parse_mcfg(mcfg_table.address, &mcfg) != 0u && mcfg.found != 0u) {
      er_print("ACPI: MCFG allocations=");
      er_print_u64_dec((UINT64)mcfg.allocation_count);
      er_print(" checksum=");
      er_print_u64_dec((UINT64)mcfg.checksum_valid);
      if (mcfg.allocation_count > 0u) {
        er_print(" base=");
        er_print_u64_hex(mcfg.allocations[0].base_address);
        er_print(" bus=");
        er_print_u64_dec((UINT64)mcfg.allocations[0].start_bus);
        er_print("-");
        er_print_u64_dec((UINT64)mcfg.allocations[0].end_bus);
      }
      er_print("\r\n");
    }
  }

  {
    ErAcpiTableInfo hpet_table;
    ErAcpiHpetInfo hpet;

    if (er_acpi_find_table(&tables, er_acpi_signature("HPET"), &hpet_table) != 0u &&
        er_acpi_parse_hpet(hpet_table.address, &hpet) != 0u && hpet.found != 0u) {
      er_print("ACPI: HPET addr=");
      er_print_u64_hex(hpet.address);
      er_print(" timers=");
      er_print_u64_dec((UINT64)hpet.comparator_count);
      er_print(" bits64=");
      er_print_u64_dec((UINT64)hpet.counter_size_64);
      er_print(" min_tick=");
      er_print_u64_dec((UINT64)hpet.minimum_tick);
      er_print(" checksum=");
      er_print_u64_dec((UINT64)hpet.checksum_valid);
      er_print("\r\n");
    }
  }
}

static void er_select_large_console(EFI_SYSTEM_TABLE* SystemTable) {
  /*
   * Purpose: choose a low text resolution before printing diagnostics.
   * Intention: firmware consoles on 4K panels often default to tiny high-column modes.
   */
  EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* con;
  UINTN best_mode = 0;
  UINTN best_columns = 0;
  UINTN best_rows = 0;
  UINT8 have_best = 0;
  UINT8 have_usable = 0;
  INT32 max_mode;
  INT32 mode;

  if (SystemTable == 0 || SystemTable->ConOut == 0 || SystemTable->ConOut->QueryMode == 0 ||
      SystemTable->ConOut->SetMode == 0 || SystemTable->ConOut->Mode == 0) {
    return;
  }

  con = SystemTable->ConOut;
  max_mode = con->Mode->MaxMode;
  if (max_mode <= 0) {
    return;
  }

  for (mode = 0; mode < max_mode; ++mode) {
    UINTN columns = 0;
    UINTN rows = 0;

    if (con->QueryMode(con, (UINTN)mode, &columns, &rows) != EFI_SUCCESS) {
      continue;
    }

    if (columns == 0u || rows == 0u) {
      continue;
    }

    if (columns >= ER_CONSOLE_MIN_COLUMNS && rows >= ER_CONSOLE_MIN_ROWS) {
      if (have_usable == 0 || columns < best_columns || (columns == best_columns && rows < best_rows)) {
        best_mode = (UINTN)mode;
        best_columns = columns;
        best_rows = rows;
        have_usable = 1;
        have_best = 1;
      }
      continue;
    }

    if (have_usable == 0 &&
        (have_best == 0 || columns < best_columns || (columns == best_columns && rows < best_rows))) {
      best_mode = (UINTN)mode;
      best_columns = columns;
      best_rows = rows;
      have_best = 1;
    }
  }

  if (have_best == 0) {
    return;
  }

  if (con->SetMode(con, best_mode) == EFI_SUCCESS && con->ClearScreen != 0) {
    con->ClearScreen(con);
  }
}

static void er_log_u64(INT64 value) {
  if (g_log_u64_stage == 0) {
    g_log_bus = (UINT64)value;
    g_log_u64_stage = 1;
    return;
  }

  if (g_log_u64_stage == 1) {
    g_log_dev = (UINT64)value;
    g_log_u64_stage = 2;
    return;
  }

  if (g_log_u64_stage == 2) {
    g_log_func = (UINT64)value;
    er_println("  pci device:");
    er_print("    bus: ");
    er_print_u64_hex(g_log_bus);
    er_print("\r\n");
    er_print("    dev: ");
    er_print_u64_hex(g_log_dev);
    er_print("\r\n");
    er_print("    func: ");
    er_print_u64_hex(g_log_func);
    er_print("\r\n");
    g_log_u64_stage = 3;
    g_log_hex_stage = 0;
    return;
  }

  g_log_u64_stage = 3;
}

static void er_log_hex(UINT64 value) {
  if (g_log_u64_stage != 3) {
    return;
  }

  switch (g_log_hex_stage) {
    case 0:
      er_print_u64_field("id", value);
      g_log_hex_stage = 1;
      break;
    case 1:
      er_print_u64_field("command/status", value);
      g_log_hex_stage = 2;
      break;
    case 2:
      er_print_u64_field("class/revision", value);
      g_log_hex_stage = 3;
      break;
    case 3:
      er_print_u64_field("header/cacheline", value);
      g_log_hex_stage = 4;
      break;
    case 4:
      er_print_u64_field("BAR0", value);
      g_log_hex_stage = 5;
      break;
    case 5:
      er_print_u64_field("BAR1", value);
      g_log_hex_stage = 6;
      break;
    case 6:
      er_print_u64_field("BAR2", value);
      g_log_hex_stage = 7;
      break;
    case 7:
      er_print_u64_field("BAR3", value);
      g_log_hex_stage = 8;
      break;
    case 8:
      er_print_u64_field("BAR4", value);
      g_log_hex_stage = 9;
      break;
    case 9:
      er_print_u64_field("BAR5", value);
      g_log_hex_stage = 0;
      g_log_u64_stage = 0;
      break;
    default:
      er_print_u64_field("value", value);
      g_log_hex_stage = 0;
      g_log_u64_stage = 0;
      break;
  }
}

static void er_halt_once(void) {
  __asm__ __volatile__("hlt");
}

static void er_halt_forever(void) {
  for (;;) {
    er_halt_once();
  }
}

static void er_wait_for_key_then_halt(EFI_SYSTEM_TABLE* SystemTable) {
  EFI_INPUT_KEY key;
  EFIAPI_KEY_FN read_key = 0;

  if (SystemTable != 0 && SystemTable->ConIn != 0) {
    read_key = SystemTable->ConIn->ReadKeyStroke;
  }

  if (read_key != 0) {
    for (;;) {
      if (read_key(SystemTable->ConIn, &key) == EFI_SUCCESS) {
        return;
      }
      er_halt_once();
    }
  } else {
    er_halt_forever();
  }
}

static int er_run_module(const UINT8* module_data, UINT32 module_size, const char* module_name) {
  ErWasmModule module;
  UINT32 main_index = 0;
  INT64 main_result = 0;

  if (er_wasm_init(&module, module_data, module_size, &g_host_calls) != 0) {
    er_println("Wasm module load failed");
    return -1;
  }

  er_println(module_name);
  er_println("Wasm module loaded");

  if (er_wasm_find_main(&module, &main_index) != 0) {
    er_println("Wasm export missing: main");
    return -1;
  }

  er_println("Wasm export found: main");

  if (er_wasm_execute_i64(&module, main_index, &main_result) != 0) {
    er_println("Wasm VM execution failed");
    return -1;
  }

  er_println("Wasm VM OK");
  er_print("wasm main() returned: ");
  if (main_result < 0) {
    er_print("-");
    er_print_u64_dec((UINT64)(-main_result));
  } else {
    er_print_u64_dec((UINT64)main_result);
  }
  er_println("");

  return 0;
}

static void er_print_pci_value(const char* label, UINT32 value) {
  er_print("    ");
  er_print(label);
  er_print(": ");
  er_print_u64_hex((UINT64)value);
  er_print("\r\n");
}

static void er_print_bar_kind(UINT8 kind) {
  switch (kind) {
    case ER_PCI_BAR_KIND_IO:
      er_print("io");
      break;
    case ER_PCI_BAR_KIND_MMIO32:
      er_print("mmio32");
      break;
    case ER_PCI_BAR_KIND_MMIO64:
      er_print("mmio64");
      break;
    default:
      er_print("none");
      break;
  }
}

static const char* er_pci_target_label(UINT8 target_kind) {
  switch (target_kind) {
    case ER_PCI_TARGET_KIND_NVIDIA:
      return "nvidia";
    case ER_PCI_TARGET_KIND_NVME:
      return "nvme";
    case ER_PCI_TARGET_KIND_ETHERNET:
      return "ethernet";
    case ER_PCI_TARGET_KIND_DISPLAY:
      return "display";
    default:
      return "unknown";
  }
}

static void er_print_mmio_read32(INT64 handle, UINT32 offset) {
  INT64 value = er_mmio_read32(handle, (INT64)offset);

  er_print("    mmio[");
  er_print_u64_hex((UINT64)offset);
  er_print("]: ");
  if (value < 0) {
    er_println("read failed");
    return;
  }

  er_print_u64_hex((UINT64)value);
  er_println("");
}

static void er_probe_mmio_readonly(const char* label, const ErPciDeviceSnapshot* snapshot) {
  ErPciBarSelection selection;
  INT64 handle;

  if (snapshot == 0 || snapshot->present == 0u) {
    return;
  }

  selection = er_pci_select_first_mmio_bar(snapshot->bars);

  er_print("  mmio target: ");
  er_print(label);
  er_print(" bus=");
  er_print_u64_hex((UINT64)snapshot->bus);
  er_print(" dev=");
  er_print_u64_hex((UINT64)snapshot->dev);
  er_print(" func=");
  er_print_u64_hex((UINT64)snapshot->func);
  er_print("\r\n");
  er_print_u64_field("command/status", (UINT64)snapshot->command_status);

  if (er_pci_command_memory_enabled(snapshot->command_status) == 0u) {
    er_println("    BAR skipped: memory decoding disabled");
    return;
  }

  if (selection.found == 0u) {
    er_println("    BAR skipped: no usable MMIO BAR");
    return;
  }

  er_print("    BAR index: ");
  er_print_u64_dec((UINT64)selection.index);
  er_print("\r\n");
  er_print("    BAR kind: ");
  er_print_bar_kind(selection.info.kind);
  er_print("\r\n");
  er_print_u64_field("BAR base", selection.info.base);
  er_print_u64_field("BAR window", (UINT64)ER_MMIO_PROBE_WINDOW_LEN);

  handle = er_mmio_map((INT64)selection.info.base, (INT64)ER_MMIO_PROBE_WINDOW_LEN);
  if (handle < 0) {
    er_println("    BAR map failed");
    return;
  }

  er_print("    BAR handle: ");
  er_print_u64_dec((UINT64)handle);
  er_print("\r\n");
  er_print_mmio_read32(handle, 0x00u);
  er_print_mmio_read32(handle, 0x04u);
  er_print_mmio_read32(handle, 0x08u);
}

static void er_print_pci_target(const char* label, const ErPciDeviceSnapshot* snapshot) {
  if (snapshot == 0 || snapshot->present == 0u) {
    return;
  }

  er_print("  target: ");
  er_print(label);
  er_print(" bus=");
  er_print_u64_hex((UINT64)snapshot->bus);
  er_print(" dev=");
  er_print_u64_hex((UINT64)snapshot->dev);
  er_print(" func=");
  er_print_u64_hex((UINT64)snapshot->func);
  er_print("\r\n");

  er_print_pci_value("id", snapshot->id);
  er_print_pci_value("command/status", snapshot->command_status);
  er_print_pci_value("class/revision", snapshot->class_revision);
  er_print_pci_value("header/cacheline", snapshot->header_cacheline);
  er_print_pci_value("BAR0", snapshot->bars[0]);
  er_print_pci_value("BAR1", snapshot->bars[1]);
  er_print_pci_value("BAR2", snapshot->bars[2]);
  er_print_pci_value("BAR3", snapshot->bars[3]);
  er_print_pci_value("BAR4", snapshot->bars[4]);
  er_print_pci_value("BAR5", snapshot->bars[5]);
}

static void erwire_send_pci_snapshot(UINT8 target_kind, const ErPciDeviceSnapshot* snapshot) {
  if (snapshot == 0 || snapshot->present == 0u) {
    return;
  }
  erwire_send_pci_device(snapshot->bus, snapshot->dev, snapshot->func, (UINT32)target_kind, snapshot->id,
                         snapshot->command_status, snapshot->class_revision, snapshot->header_cacheline,
                         snapshot->bars);
}

static UINT8 er_scan_mmio_probe_function(UINT32 bus, UINT32 dev, UINT32 func) {
  ErPciDeviceSnapshot snapshot;
  UINT8 target_kind;

  if (er_pci_read_snapshot(bus, dev, func, &snapshot) == 0u) {
    return 0;
  }

  target_kind = er_pci_classify_target(snapshot.id, snapshot.class_revision);
  if (target_kind == ER_PCI_TARGET_KIND_NVIDIA) {
    er_probe_mmio_readonly("nvidia", &snapshot);
    return 1;
  }

  return 0;
}

static void er_scan_pci_function(UINT32 bus, UINT32 dev, UINT32 func) {
  ErPciDeviceSnapshot snapshot;
  UINT8 target_kind;

  if (er_pci_read_snapshot(bus, dev, func, &snapshot) == 0u) {
    return;
  }

  target_kind = er_pci_classify_target(snapshot.id, snapshot.class_revision);
  if (target_kind != ER_PCI_TARGET_KIND_NONE) {
    erwire_send_pci_snapshot(target_kind, &snapshot);
    er_print_pci_target(er_pci_target_label(target_kind), &snapshot);
    return;
  }
}

static void er_scan_pci_targets(void) {
  UINT32 bus;
  UINT32 dev;

  er_println("PCI target scan: nvidia/nvme/ethernet");

  for (bus = 0; bus < ER_PCI_BUS_COUNT; ++bus) {
    for (dev = 0; dev < ER_PCI_DEVICE_COUNT; ++dev) {
      UINT32 id0 = er_pci_cfg_read32(bus, dev, 0u, 0x00);
      UINT32 header0;
      UINT32 max_func;
      UINT32 func;

      if (er_pci_device_present(id0) == 0u) {
        continue;
      }

      header0 = er_pci_cfg_read32(bus, dev, 0u, 0x0c);
      max_func = er_pci_function_count(header0);

      for (func = 0; func < max_func; ++func) {
        er_scan_pci_function(bus, dev, func);
      }
    }
  }

  er_println("PCI target scan done");
}

static void er_run_mmio_probe(void) {
  UINT32 bus;
  UINT32 dev;

  er_println("MMIO read-only probe: nvidia MMIO BAR");

  for (bus = 0; bus < ER_PCI_BUS_COUNT; ++bus) {
    for (dev = 0; dev < ER_PCI_DEVICE_COUNT; ++dev) {
      UINT32 id0 = er_pci_cfg_read32(bus, dev, 0u, 0x00);
      UINT32 header0;
      UINT32 max_func;
      UINT32 func;

      if (er_pci_device_present(id0) == 0u) {
        continue;
      }

      header0 = er_pci_cfg_read32(bus, dev, 0u, 0x0c);
      max_func = er_pci_function_count(header0);

      for (func = 0; func < max_func; ++func) {
        if (er_scan_mmio_probe_function(bus, dev, func) != 0u) {
          er_println("MMIO read-only probe done");
          return;
        }
      }
    }
  }

  er_println("MMIO read-only probe: no NVIDIA target found");
}

static INT64 er_wasm_bus_exec_host(const ErBusIoPacket* request, ErBusIoPacket* response) {
  return (INT64)er_bus_execute_io_packet(request, response);
}

static void er_install_hostcalls(void) {
  g_host_calls.log_u64 = er_log_u64;
  g_host_calls.log_hex = er_log_hex;
  g_host_calls.pci_read32 = er_pci_read32;
  g_host_calls.pci_write32 = er_pci_write32;
  g_host_calls.mmio_map = er_mmio_map;
  g_host_calls.mmio_read32 = er_mmio_read32;
  g_host_calls.bus_exec = er_wasm_bus_exec_host;
  g_host_calls.memory = g_wasm_driver_memory;
  g_host_calls.memory_size = (UINT32)sizeof(g_wasm_driver_memory);
}

static void er_run_smoke_profile(void) {
  er_println("boot profile: smoke");
  er_reset_log_state();
  er_run_module(g_edgerun_test_wasm, ER_TEST_WASM_SIZE, "test_return_123");
}

static void er_run_pci_profile(void) {
  er_println("boot profile: pci");
  er_scan_pci_targets();
}

static void er_run_quiet_profile(void) {
  er_println("boot profile: quiet");
  er_println("halt ready");
}

static void er_run_mmio_profile(void) {
  er_println("boot profile: mmio");
  er_run_mmio_probe();
}

static void er_run_invalid_profile(void) {
  er_print("invalid boot profile: ");
  er_print_u64_dec((UINT64)ER_BOOT_PROFILE);
  er_println("");
  er_halt_forever();
}

static void er_run_boot_profile(void) {
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_PCI) {
    er_run_pci_profile();
    return;
  }

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_QUIET) {
    er_run_quiet_profile();
    return;
  }

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_MMIO) {
    er_run_mmio_profile();
    return;
  }

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_SMOKE) {
    er_run_smoke_profile();
    return;
  }

  er_run_invalid_profile();
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  (void)ImageHandle;

  er_select_large_console(SystemTable);
  er_print_set_system_table(SystemTable);
  er_mmio_reset();
  er_install_hostcalls();

  er_println("EdgeRun Metal Core v0.2");
  er_println("UEFI boot OK");
  er_log_acpi(SystemTable);

  er_run_boot_profile();

  er_println("Press any key to halt...");
  er_wait_for_key_then_halt(SystemTable);
  return EFI_SUCCESS;
}
