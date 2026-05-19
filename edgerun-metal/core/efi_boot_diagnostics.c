#include "efi_boot_internal.h"

ErWasmHostCalls g_host_calls = {0};
static UINT8 g_wasm_driver_memory[ER_WASM_DRIVER_MEMORY_BYTES];
static UINT8 g_efi_memory_map[ER_EFI_MEMORY_MAP_BYTES];
static UINT8 g_log_u64_stage = ER_LOG_U64_STAGE_IDLE;
static UINT8 g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
static UINT64 g_log_bus = 0;
static UINT64 g_log_dev = 0;
static UINT64 g_log_func = 0;

void er_print_u64_field(const char* label, UINT64 value) {
  er_print("    ");
  er_print(label);
  er_print(": ");
  er_print_u64_hex(value);
  er_print("\r\n");
}

void er_acpi_signature_name(UINT32 signature, char out_name[ER_ACPI_SIGNATURE_BYTES + 1u]) {
  UINTN i;

  for (i = 0u; i < ER_ACPI_SIGNATURE_BYTES; ++i) {
    out_name[i] = (char)((signature >> (i * 8u)) & ER_BYTE_MASK);
  }
  out_name[ER_ACPI_SIGNATURE_BYTES] = 0;
}

void er_log_acpi(EFI_SYSTEM_TABLE* SystemTable) {
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
    char name[ER_ACPI_SIGNATURE_BYTES + 1u];

    er_acpi_signature_name(sig, name);
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

void er_select_large_console(EFI_SYSTEM_TABLE* SystemTable) {
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

void er_log_u64(INT64 value) {
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
    g_log_u64_stage = ER_LOG_U64_STAGE_PCI_FIELDS;
    g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
    return;
  }

  g_log_u64_stage = ER_LOG_U64_STAGE_PCI_FIELDS;
}

void er_log_hex(UINT64 value) {
  if (g_log_u64_stage != ER_LOG_U64_STAGE_PCI_FIELDS) {
    return;
  }

  switch (g_log_hex_stage) {
    case ER_LOG_HEX_STAGE_ID:
      er_print_u64_field("id", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_COMMAND_STATUS;
      break;
    case ER_LOG_HEX_STAGE_COMMAND_STATUS:
      er_print_u64_field("command/status", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_CLASS_REVISION;
      break;
    case ER_LOG_HEX_STAGE_CLASS_REVISION:
      er_print_u64_field("class/revision", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_HEADER_CACHELINE;
      break;
    case ER_LOG_HEX_STAGE_HEADER_CACHELINE:
      er_print_u64_field("header/cacheline", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_BAR0;
      break;
    case ER_LOG_HEX_STAGE_BAR0:
      er_print_u64_field("BAR0", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_BAR1;
      break;
    case ER_LOG_HEX_STAGE_BAR1:
      er_print_u64_field("BAR1", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_BAR2;
      break;
    case ER_LOG_HEX_STAGE_BAR2:
      er_print_u64_field("BAR2", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_BAR3;
      break;
    case ER_LOG_HEX_STAGE_BAR3:
      er_print_u64_field("BAR3", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_BAR4;
      break;
    case ER_LOG_HEX_STAGE_BAR4:
      er_print_u64_field("BAR4", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_BAR5;
      break;
    case ER_LOG_HEX_STAGE_BAR5:
      er_print_u64_field("BAR5", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
      g_log_u64_stage = ER_LOG_U64_STAGE_IDLE;
      break;
    default:
      er_print_u64_field("value", value);
      g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
      g_log_u64_stage = ER_LOG_U64_STAGE_IDLE;
      break;
  }
}

void er_cpu_idle_once(void) {
#if defined(ER_TARGET_X86_64)
  __asm__ __volatile__("hlt");
#elif defined(ER_TARGET_AARCH64)
  __asm__ __volatile__("wfi");
#else
#error unsupported metal architecture
#endif
}

void er_pause_once(void) {
#if defined(ER_TARGET_X86_64)
  __asm__ __volatile__("pause");
#elif defined(ER_TARGET_AARCH64)
  __asm__ __volatile__("yield");
#else
#error unsupported metal architecture
#endif
}

void er_idle_forever(void) {
  for (;;) {
    er_cpu_idle_once();
  }
}

UINT8 er_exit_boot_services(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  UINTN attempt;

  if (SystemTable == 0 || SystemTable->BootServices == 0 ||
      SystemTable->BootServices->GetMemoryMap == 0 ||
      SystemTable->BootServices->ExitBootServices == 0) {
    er_println("boot services: unavailable");
    return 0u;
  }

  for (attempt = 0u; attempt < ER_EFI_EXIT_BOOT_SERVICES_ATTEMPTS; ++attempt) {
    UINTN map_size = sizeof(g_efi_memory_map);
    UINTN map_key = 0u;
    UINTN descriptor_size = 0u;
    UINT32 descriptor_version = 0u;
    EFI_STATUS status = SystemTable->BootServices->GetMemoryMap(
      &map_size,
      g_efi_memory_map,
      &map_key,
      &descriptor_size,
      &descriptor_version);

    if (status == EFI_BUFFER_TOO_SMALL) {
      er_println("boot services: memory map buffer too small");
      return 0u;
    }
    if (status != EFI_SUCCESS) {
      er_print("boot services: GetMemoryMap failed ");
      er_print_u64_hex(status);
      er_println("");
      return 0u;
    }

    status = SystemTable->BootServices->ExitBootServices(ImageHandle, map_key);
    if (status == EFI_SUCCESS) {
      return 1u;
    }
    if (status != EFI_INVALID_PARAMETER || attempt + 1u == ER_EFI_EXIT_BOOT_SERVICES_ATTEMPTS) {
      er_print("boot services: ExitBootServices failed ");
      er_print_u64_hex(status);
      er_println("");
      return 0u;
    }
  }

  return 0u;
}

INT64 er_wasm_bus_exec_host(const ErBusIoPacket* request, ErBusIoPacket* response) {
  return (INT64)er_bus_execute_io_packet(request, response);
}

void er_install_hostcalls(void) {
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
