#include "er_types.h"
#include "er_print.h"
#include "er_pci.h"
#include "er_mmio.h"
#include "er_mem.h"
#include "er_acpi.h"
#include "er_boot_profile.h"
#include "er_gfx_console.h"
#include "er_tpm.h"
#include "er_ui_gop_renderer.h"
#include "er_ui_components.h"
#include "er_ui_demo_apps.h"
#include "er_ui_metal.h"
#include "er_ui_theme.h"
#include "er_virtio_gpu.h"
#include "erwire.h"
#include "er_native_boot.h"
#include "font_geist.h"
#include "wasm_vm.h"
#include "wasm_test_module.h"
#include "wasm_pci_scan_module.h"

#ifndef ER_BOOT_PROFILE
#define ER_BOOT_PROFILE ER_BOOT_PROFILE_SMOKE
#endif

#define ER_MMIO_PROBE_WINDOW_LEN 0x1000u
#define ER_CONSOLE_MIN_COLUMNS 80u
#define ER_CONSOLE_MIN_ROWS 25u
#define ER_UI_BOOT_ARENA_SIZE (4u * 1024u * 1024u)
#define ER_UI_BOOT_TILE_WIDTH 128u
#define ER_UI_BOOT_TILE_HEIGHT 64u
#define ER_UI_BOOT_MAX_DIRTY_TILES 4096u
#define ER_UI_BOOT_MAX_TILE_MARKS 8192u
#define ER_UI_BOOT_RENDER_OVERDRAW_BUDGET 4u
#define ER_UI_BOOT_BACKING_BUFFERS 1u
#define ER_UI_BOOT_LOW_HEIGHT_MAX 1200u
#define ER_UI_BOOT_SMALL_FONT_PX 16.0f
#define ER_UI_BOOT_LARGE_FONT_PX 28.0f
#define ER_UI_BOOT_FONT_ATLAS_SIZE 1024u
#define ER_UI_BOOT_FONT_ATLAS_PAD 2u
#define ER_UI_BOOT_COMMAND_BYTES (256u * 1024u)
#define ER_UI_BOOT_GLYPH_CACHE_BYTES (1024u * 1024u)
#define ER_UI_BOOT_SURFACE_BYTES 0u
#define ER_UI_BOOT_MEMORY_BUDGET_BYTES (128u * 1024u * 1024u)
#define ER_WASM_DRIVER_MEMORY_BYTES (64u * 1024u)
#define ER_ACPI_SIGNATURE_BYTES 4u
#define ER_BYTE_MASK 0xffu
#define ER_MMIO_PROBE_REG0_OFFSET 0x00u
#define ER_MMIO_PROBE_REG1_OFFSET 0x04u
#define ER_MMIO_PROBE_REG2_OFFSET 0x08u
#define ER_EFI_SCAN_ESC 0x17u
#define ER_EFI_SCAN_LEFT 0x03u
#define ER_EFI_SCAN_RIGHT 0x04u
#define ER_EFI_KEY_TAB 0x09u
#define ER_EFI_KEY_ENTER 0x0du

enum {
  ER_LOG_U64_STAGE_IDLE = 0u,
  ER_LOG_U64_STAGE_PCI_FIELDS = 3u,
  ER_LOG_HEX_STAGE_ID = 0u,
  ER_LOG_HEX_STAGE_COMMAND_STATUS = 1u,
  ER_LOG_HEX_STAGE_CLASS_REVISION = 2u,
  ER_LOG_HEX_STAGE_HEADER_CACHELINE = 3u,
  ER_LOG_HEX_STAGE_BAR0 = 4u,
  ER_LOG_HEX_STAGE_BAR1 = 5u,
  ER_LOG_HEX_STAGE_BAR2 = 6u,
  ER_LOG_HEX_STAGE_BAR3 = 7u,
  ER_LOG_HEX_STAGE_BAR4 = 8u,
  ER_LOG_HEX_STAGE_BAR5 = 9u
};

static ErWasmHostCalls g_host_calls = {0};
static UINT8 g_wasm_driver_memory[ER_WASM_DRIVER_MEMORY_BYTES];
static UINT8 g_ui_boot_arena[ER_UI_BOOT_ARENA_SIZE];
static UINTN g_ui_boot_arena_used;
static UINT8 g_log_u64_stage = ER_LOG_U64_STAGE_IDLE;
static UINT8 g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
static UINT64 g_log_bus = 0;
static UINT64 g_log_dev = 0;
static UINT64 g_log_func = 0;

static void er_reset_log_state(void) {
  g_log_u64_stage = ER_LOG_U64_STAGE_IDLE;
  g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
  g_log_bus = 0;
  g_log_dev = 0;
  g_log_func = 0;
}

static void* er_ui_boot_alloc(void* user, size_t size, size_t align) {
  UINTN mask;
  UINTN start;
  UINTN end;
  UINT8* arena = (UINT8*)user;

  if (arena == 0 || size == 0u) {
    return 0;
  }
  if (align == 0u) {
    align = 1u;
  }
  mask = (UINTN)align - 1u;
  if (((UINTN)align & mask) != 0u) {
    return 0;
  }

  start = (g_ui_boot_arena_used + mask) & ~mask;
  if ((UINTN)size > ER_UI_BOOT_ARENA_SIZE || start > ER_UI_BOOT_ARENA_SIZE - (UINTN)size) {
    return 0;
  }
  end = start + (UINTN)size;
  g_ui_boot_arena_used = end;
  return arena + start;
}

static void er_ui_boot_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)ptr;
  (void)size;
  (void)align;
}

static void* er_ui_boot_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  UINT8* next;
  UINTN copy_size;

  if (new_size == 0u) {
    return 0;
  }
  next = (UINT8*)er_ui_boot_alloc(user, new_size, align);
  if (next == 0 || ptr == 0 || old_size == 0u) {
    return next;
  }
  copy_size = (UINTN)(old_size < new_size ? old_size : new_size);
  er_mem_copy(next, (const UINT8*)ptr, copy_size);
  return next;
}

static er_ui_allocator_t er_ui_boot_allocator(void) {
  er_ui_allocator_t allocator;
  allocator.user = g_ui_boot_arena;
  allocator.alloc = er_ui_boot_alloc;
  allocator.free = er_ui_boot_free;
  return allocator;
}

static vr_font_allocator_t er_ui_boot_font_allocator(void) {
  vr_font_allocator_t allocator;
  allocator.user = g_ui_boot_arena;
  allocator.alloc = er_ui_boot_alloc;
  allocator.realloc = er_ui_boot_realloc;
  allocator.free = er_ui_boot_free;
  return allocator;
}

static void er_print_u64_field(const char* label, UINT64 value) {
  er_print("    ");
  er_print(label);
  er_print(": ");
  er_print_u64_hex(value);
  er_print("\r\n");
}

static void er_acpi_signature_name(UINT32 signature, char out_name[ER_ACPI_SIGNATURE_BYTES + 1u]) {
  UINTN i;

  for (i = 0u; i < ER_ACPI_SIGNATURE_BYTES; ++i) {
    out_name[i] = (char)((signature >> (i * 8u)) & ER_BYTE_MASK);
  }
  out_name[ER_ACPI_SIGNATURE_BYTES] = 0;
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
    g_log_u64_stage = ER_LOG_U64_STAGE_PCI_FIELDS;
    g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
    return;
  }

  g_log_u64_stage = ER_LOG_U64_STAGE_PCI_FIELDS;
}

static void er_log_hex(UINT64 value) {
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

static void er_print_pci_bar_value(UINTN index, UINT32 value) {
  er_print("    BAR");
  er_print_u64_dec((UINT64)index);
  er_print(": ");
  er_print_u64_hex((UINT64)value);
  er_print("\r\n");
}

static void er_print_pci_bars(const ErPciDeviceSnapshot* snapshot) {
  UINTN i;

  for (i = 0u; i < ER_PCI_BAR_COUNT; ++i) {
    er_print_pci_bar_value(i, snapshot->bars[i]);
  }
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

static void er_print_pci_location(const char* prefix, const char* label, const ErPciDeviceSnapshot* snapshot) {
  er_print(prefix);
  er_print(label);
  er_print(" bus=");
  er_print_u64_hex((UINT64)snapshot->bus);
  er_print(" dev=");
  er_print_u64_hex((UINT64)snapshot->dev);
  er_print(" func=");
  er_print_u64_hex((UINT64)snapshot->func);
  er_print("\r\n");
}

static void er_probe_mmio_readonly(const char* label, const ErPciDeviceSnapshot* snapshot) {
  ErPciBarSelection selection;
  INT64 handle;

  if (snapshot == 0 || snapshot->present == 0u) {
    return;
  }

  selection = er_pci_select_first_mmio_bar(snapshot->bars);

  er_print_pci_location("  mmio target: ", label, snapshot);
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
  er_print_mmio_read32(handle, ER_MMIO_PROBE_REG0_OFFSET);
  er_print_mmio_read32(handle, ER_MMIO_PROBE_REG1_OFFSET);
  er_print_mmio_read32(handle, ER_MMIO_PROBE_REG2_OFFSET);
}

static void er_print_pci_target(const char* label, const ErPciDeviceSnapshot* snapshot) {
  if (snapshot == 0 || snapshot->present == 0u) {
    return;
  }

  er_print_pci_location("  target: ", label, snapshot);

  er_print_pci_value("id", snapshot->id);
  er_print_pci_value("command/status", snapshot->command_status);
  er_print_pci_value("class/revision", snapshot->class_revision);
  er_print_pci_value("header/cacheline", snapshot->header_cacheline);
  er_print_pci_bars(snapshot);
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

typedef UINT8 (*ErPciFunctionVisitor)(UINT32 bus, UINT32 dev, UINT32 func);

static UINT8 er_visit_pci_functions(ErPciFunctionVisitor visitor) {
  UINT32 bus;
  UINT32 dev;

  if (visitor == 0) {
    return 0;
  }

  for (bus = 0; bus < ER_PCI_BUS_COUNT; ++bus) {
    for (dev = 0; dev < ER_PCI_DEVICE_COUNT; ++dev) {
      UINT32 id0 = er_pci_cfg_read32(bus, dev, 0u, ER_PCI_ID_OFFSET);
      UINT32 header0;
      UINT32 max_func;
      UINT32 func;

      if (er_pci_device_present(id0) == 0u) {
        continue;
      }

      header0 = er_pci_cfg_read32(bus, dev, 0u, ER_PCI_HEADER_CACHELINE_OFFSET);
      max_func = er_pci_function_count(header0);

      for (func = 0; func < max_func; ++func) {
        if (visitor(bus, dev, func) != 0u) {
          return 1;
        }
      }
    }
  }

  return 0;
}

static UINT8 er_scan_pci_target_visitor(UINT32 bus, UINT32 dev, UINT32 func) {
  er_scan_pci_function(bus, dev, func);
  return 0;
}

static void er_scan_pci_targets(void) {
  er_println("PCI target scan: nvidia/nvme/ethernet");
  (void)er_visit_pci_functions(er_scan_pci_target_visitor);
  er_println("PCI target scan done");
}

static void er_run_mmio_probe(void) {
  er_println("MMIO read-only probe: nvidia MMIO BAR");
  if (er_visit_pci_functions(er_scan_mmio_probe_function) != 0u) {
    er_println("MMIO read-only probe done");
    return;
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

static void er_run_native_profile(void) {
  ErNativeBootState native_state;
  UINT32 mac_index;
  UINT64 transport_base;

  er_println("boot profile: native");
  if (er_native_boot_configure_pci_erwire_eth_sink(&native_state) == 0u &&
      er_native_boot_configure_qemu_microvm_erwire_eth_sink(&native_state) == 0u) {
    er_println("native transport: virtio net unavailable");
    return;
  }
  transport_base = native_state.net->transport.address.base;
  if (transport_base == 0u) {
    transport_base = native_state.net->transport.common.address.base;
  }
  er_print("native transport: virtio net ");
  er_print_u64_hex(transport_base);
  er_print(" mac=");
  for (mac_index = 0u; mac_index < ER_NET_MAC_LEN; ++mac_index) {
    if (mac_index != 0u) {
      er_print(":");
    }
    er_print_u64_hex((UINT64)native_state.net->mac[mac_index]);
  }
  er_println("");
  erwire_send_text("native-erwire-l2-ready");
  er_println("native transport: erwire EdgeRun Ethernet frame submitted");
}

static void er_run_gpu_profile(void) {
  ErVirtioGpu gpu;
  UINT64 transport_base;

  er_println("boot profile: gpu");
  if (er_virtio_gpu_init_first_pci(&gpu) == 0u) {
    er_println("gpu transport: virtio gpu unavailable");
    return;
  }
  transport_base = gpu.transport.address.base;
  if (transport_base == 0u) {
    transport_base = gpu.transport.common.address.base;
  }
  er_print("gpu transport: virtio gpu ");
  er_print_u64_hex(transport_base);
  er_print(" scanouts=");
  er_print_u64_dec((UINT64)gpu.config.num_scanouts);
  er_print(" capsets=");
  er_print_u64_dec((UINT64)gpu.config.num_capsets);
  er_print(" controlq=");
  er_print_u64_dec((UINT64)gpu.control_queue_size);
  er_print(" cursorq=");
  er_print_u64_dec((UINT64)gpu.cursor_queue_size);
  er_println("");
}

static void er_run_tpm_profile(EFI_SYSTEM_TABLE* SystemTable) {
  ErAcpiRsdpInfo rsdp;
  ErAcpiTableList tables;
  ErTpm2Info tpm2;
  ErTpmCrbTransport crb;
  ErTpmP256Primary primary;
  UINT8 command[128];
  UINT8 response[512];
  UINT8 random[32];
  UINT8 digest[32];
  UINT8 signature[64];
  UINT32 command_len = 0u;
  UINT32 response_len = 0u;
  UINT32 random_len = 0u;
  UINT32 code;
  UINT32 i;

  er_println("boot profile: tpm");
  if (er_acpi_find_rsdp(SystemTable, &rsdp) == 0u ||
      er_acpi_enumerate_tables(&rsdp, &tables) == 0u ||
      er_tpm_find_tpm2_table(&tables, &tpm2) == 0u) {
    er_println("tpm: ACPI TPM2 unavailable");
    return;
  }

  er_print("tpm: TPM2 control=");
  er_print_u64_hex(tpm2.control_area);
  er_print(" start_method=");
  er_print_u64_dec((UINT64)tpm2.start_method);
  er_println("");

  if (er_tpm_crb_from_tpm2_info(&tpm2, &crb) == 0u) {
    er_println("tpm: CRB transport unavailable");
    return;
  }

  er_print("tpm: CRB cmd=");
  er_print_u64_hex(crb.command_buffer);
  er_print(" rsp=");
  er_print_u64_hex(crb.response_buffer);
  er_println("");

  if (er_tpm_build_startup_command(ER_TPM_SU_CLEAR, command,
                                   (UINT32)sizeof(command), &command_len) == 0u ||
      er_tpm_crb_transact(&crb, command, command_len, response,
                          (UINT32)sizeof(response), &response_len) == 0u) {
    er_println("tpm: Startup command failed");
    return;
  }
  code = er_tpm_response_code(response, response_len);
  er_print("tpm: Startup rc=");
  er_print_u64_hex((UINT64)code);
  er_println("");
  if (code != ER_TPM_RC_SUCCESS && code != ER_TPM_RC_INITIALIZE) {
    return;
  }

  if (er_tpm_build_get_random_command(16u, command, (UINT32)sizeof(command),
                                      &command_len) == 0u ||
      er_tpm_crb_transact(&crb, command, command_len, response,
                          (UINT32)sizeof(response), &response_len) == 0u ||
      er_tpm_parse_get_random_response(response, response_len, random,
                                       (UINT32)sizeof(random), &random_len) == 0u) {
    er_println("tpm: GetRandom command failed");
    return;
  }

  er_print("tpm: GetRandom bytes=");
  er_print_u64_dec((UINT64)random_len);
  er_print(" first=");
  er_print_u64_hex((UINT64)random[0]);
  er_print(" last=");
  er_print_u64_hex((UINT64)random[random_len - 1u]);
  er_println("");

  if (er_tpm_build_create_primary_p256_signing_command(command,
                                                       (UINT32)sizeof(command),
                                                       &command_len) == 0u ||
      er_tpm_crb_transact(&crb, command, command_len, response,
                          (UINT32)sizeof(response), &response_len) == 0u ||
      er_tpm_parse_create_primary_p256_response(response, response_len, &primary) == 0u) {
    er_println("tpm: CreatePrimary P-256 failed");
    return;
  }
  er_print("tpm: CreatePrimary handle=");
  er_print_u64_hex((UINT64)primary.handle);
  er_print(" pub0=");
  er_print_u64_hex((UINT64)primary.public_key[0]);
  er_print(" pub63=");
  er_print_u64_hex((UINT64)primary.public_key[ER_TPM_P256_PUBLIC_KEY_LEN - 1u]);
  er_println("");

  for (i = 0u; i < (UINT32)sizeof(digest); ++i) {
    digest[i] = (UINT8)i;
  }
  if (er_tpm_build_sign_p256_sha256_command(primary.handle, digest, command,
                                            (UINT32)sizeof(command),
                                            &command_len) == 0u ||
      er_tpm_crb_transact(&crb, command, command_len, response,
                          (UINT32)sizeof(response), &response_len) == 0u) {
    er_println("tpm: Sign P-256 failed");
    return;
  }
  code = er_tpm_response_code(response, response_len);
  if (code != ER_TPM_RC_SUCCESS) {
    er_print("tpm: Sign rc=");
    er_print_u64_hex((UINT64)code);
    er_println("");
    return;
  }
  if (er_tpm_parse_p256_sha256_signature_response(response, response_len,
                                                  signature) == 0u) {
    er_println("tpm: Sign P-256 parse failed");
    return;
  }
  er_print("tpm: Sign bytes=64 first=");
  er_print_u64_hex((UINT64)signature[0]);
  er_print(" last=");
  er_print_u64_hex((UINT64)signature[63]);
  er_println("");

  if (er_tpm_build_flush_context_command(primary.handle, command,
                                         (UINT32)sizeof(command),
                                         &command_len) != 0u) {
    (void)er_tpm_crb_transact(&crb, command, command_len, response,
                              (UINT32)sizeof(response), &response_len);
  }
  er_println("tpm: CRB direct command path ok");
}

static void er_run_mmio_profile(void) {
  er_println("boot profile: mmio");
  er_run_mmio_probe();
}

static er_ui_action_t er_ui_boot_tab_action(UINT32 surface_id) {
  er_ui_action_t action;
  er_mem_zero((UINT8*)&action, (UINTN)sizeof(action));
  action.kind = ER_UI_ACTION_TAB_SELECTED;
  action.id = surface_id;
  return action;
}

static UINT32 er_ui_boot_next_app_id(UINT32 current) {
  switch (current) {
    case ER_UI_DEMO_APP_RESOURCES_ID:
      return ER_UI_DEMO_APP_NETWORK_ID;
    case ER_UI_DEMO_APP_NETWORK_ID:
      return ER_UI_DEMO_APP_PEOPLE_ID;
    case ER_UI_DEMO_APP_PEOPLE_ID:
      return ER_UI_DEMO_APP_RESOURCES_ID;
    default:
      return ER_UI_DEMO_APP_RESOURCES_ID;
  }
}

static UINT32 er_ui_boot_prev_app_id(UINT32 current) {
  switch (current) {
    case ER_UI_DEMO_APP_RESOURCES_ID:
      return ER_UI_DEMO_APP_PEOPLE_ID;
    case ER_UI_DEMO_APP_NETWORK_ID:
      return ER_UI_DEMO_APP_RESOURCES_ID;
    case ER_UI_DEMO_APP_PEOPLE_ID:
      return ER_UI_DEMO_APP_NETWORK_ID;
    default:
      return ER_UI_DEMO_APP_RESOURCES_ID;
  }
}

static UINT8 er_ui_boot_direct_app_id(CHAR16 key, UINT32* out_surface_id) {
  if (out_surface_id == 0) {
    return 0u;
  }
  switch (key) {
    case '1':
      *out_surface_id = ER_UI_DEMO_APP_RESOURCES_ID;
      return 1u;
    case '2':
      *out_surface_id = ER_UI_DEMO_APP_NETWORK_ID;
      return 1u;
    case '3':
      *out_surface_id = ER_UI_DEMO_APP_PEOPLE_ID;
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_ui_boot_action_from_key(const er_ui_demo_apps_state_t* demo_state,
                                        EFI_INPUT_KEY key,
                                        er_ui_action_t* out_action) {
  UINT32 surface_id = 0u;
  UINT32 focused_id;

  if (demo_state == 0 || out_action == 0) {
    return 0u;
  }

  if (er_ui_boot_direct_app_id(key.UnicodeChar, &surface_id) != 0u) {
    *out_action = er_ui_boot_tab_action(surface_id);
    return 1u;
  }

  focused_id = er_ui_workspace_focused_surface_id(&demo_state->shell);
  if (key.UnicodeChar == ER_EFI_KEY_TAB || key.UnicodeChar == ER_EFI_KEY_ENTER ||
      key.ScanCode == ER_EFI_SCAN_RIGHT) {
    *out_action = er_ui_boot_tab_action(er_ui_boot_next_app_id(focused_id));
    return 1u;
  }
  if (key.ScanCode == ER_EFI_SCAN_LEFT) {
    *out_action = er_ui_boot_tab_action(er_ui_boot_prev_app_id(focused_id));
    return 1u;
  }

  return 0u;
}

static UINT8 er_ui_boot_key_exits(EFI_INPUT_KEY key) {
  return key.ScanCode == ER_EFI_SCAN_ESC || key.UnicodeChar == 'q' || key.UnicodeChar == 'Q';
}

static er_ui_status_t er_build_ui_boot_scene(er_ui_scene_t* scene,
                                             er_ui_demo_apps_state_t* demo_state,
                                             vr_font_face_t* font,
                                             UINT32 width,
                                             UINT32 height,
                                             er_ui_resolved_theme_t theme) {
  er_ui_status_t status;

  if (scene == 0 || demo_state == 0 || font == 0) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }

  status = er_ui_scene_init_with_allocator(scene, theme.colors.bg, er_ui_boot_allocator());
  if (status != ER_UI_OK) return status;
  return er_ui_demo_apps_emit_scene(demo_state, scene, font, er_ui_bounds(0.0f, 0.0f, (float)width, (float)height), theme);
}

static UINT8 er_ui_boot_render_scene(er_ui_demo_apps_state_t* demo_state,
                                     vr_font_face_t* font,
                                     ErUiGopMode mode,
                                     const ErUiGopTilePlan* tile_plan,
                                     ErUiGopMemoryPlan memory_plan,
                                     er_ui_scene_budget_t scene_budget,
                                     ErUiGopFrameBudget frame_budget,
                                     er_ui_resolved_theme_t theme) {
  er_ui_scene_t scene = {0};
  er_ui_scene_stats_t scene_stats;
  er_ui_scene_budget_violation_t scene_violation;
  ErUiGopRenderStats render_stats;
  ErUiGopFrameBudgetViolation frame_violation;

  if (demo_state == 0 || font == 0 || tile_plan == 0) {
    return 0u;
  }

  if (er_build_ui_boot_scene(&scene, demo_state, font, mode.width, mode.height, theme) != ER_UI_OK) {
    er_println("ui renderer: scene build failed");
    er_ui_scene_destroy(&scene);
    return 0u;
  }

  scene_stats = er_ui_scene_stats(&scene);
  if (er_ui_scene_first_budget_violation(scene_stats, scene_budget, &scene_violation)) {
    er_print("ui renderer: scene budget exceeded ");
    er_print(scene_violation.name);
    er_print(" actual=");
    er_print_u64_dec((UINT64)scene_violation.actual);
    er_print(" limit=");
    er_print_u64_dec((UINT64)scene_violation.limit);
    er_println("");
    er_ui_scene_destroy(&scene);
    return 0u;
  }

  if (er_ui_gop_renderer_render_scene_with_font_stats(&scene, font, &render_stats) == 0u) {
    er_println("ui renderer: render failed");
    er_ui_scene_destroy(&scene);
    return 0u;
  }

  if (er_ui_gop_render_stats_first_budget_violation(render_stats, frame_budget, &frame_violation) != 0u) {
    er_print("ui renderer: frame budget exceeded ");
    er_print(frame_violation.name);
    er_print(" actual=");
    er_print_u64_dec(frame_violation.actual);
    er_print(" limit=");
    er_print_u64_dec(frame_violation.limit);
    er_println("");
    er_ui_scene_destroy(&scene);
    return 0u;
  }

  er_print("ui renderer: app=");
  er_print_u64_dec((UINT64)er_ui_workspace_focused_surface_id(&demo_state->shell));
  er_print(" bytes=");
  er_print_u64_dec(render_stats.bytes_written);
  er_print(" rects=");
  er_print_u64_dec(render_stats.rects);
  er_print(" text=");
  er_print_u64_dec(render_stats.text_quads);
  er_print(" tile_bytes=");
  er_print_u64_dec(tile_plan->max_tile_bytes);
  er_print(" mem=");
  er_print_u64_dec(memory_plan.total_bytes);
  er_println("");

  er_ui_scene_destroy(&scene);
  return 1u;
}

static void er_run_ui_profile(EFI_SYSTEM_TABLE* SystemTable) {
  er_ui_scene_budget_t scene_budget;
  ErUiGopMode mode;
  ErUiGopFrameBudget frame_budget;
  ErUiGopTilePlan tile_plan;
  ErUiGopMemoryPlan memory_plan;
  ErUiGopMemoryBudget memory_budget;
  ErUiGopMemoryBudgetViolation memory_violation;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  er_ui_demo_apps_state_t demo_state = {0};
  vr_font_config_t font_cfg;
  vr_font_face_t* font = 0;
  EFIAPI_KEY_FN read_key = 0;

  er_println("boot profile: ui");
  if (er_ui_gop_renderer_init(SystemTable) == 0u) {
    er_println("ui renderer: GOP unavailable");
    return;
  }

  g_ui_boot_arena_used = 0u;
  if (er_ui_gop_renderer_mode(&mode) == 0u) {
    er_println("ui renderer: mode unavailable");
    return;
  }
  if (er_ui_gop_renderer_tile_plan(ER_UI_BOOT_TILE_WIDTH, ER_UI_BOOT_TILE_HEIGHT,
                                   ER_UI_BOOT_MAX_DIRTY_TILES, &tile_plan) == 0u ||
      tile_plan.tile_count > ER_UI_BOOT_MAX_TILE_MARKS) {
    er_println("ui renderer: tile plan failed");
    return;
  }
  font_cfg.px_size = mode.height <= ER_UI_BOOT_LOW_HEIGHT_MAX ? ER_UI_BOOT_SMALL_FONT_PX : ER_UI_BOOT_LARGE_FONT_PX;
  font_cfg.atlas_width = ER_UI_BOOT_FONT_ATLAS_SIZE;
  font_cfg.atlas_height = ER_UI_BOOT_FONT_ATLAS_SIZE;
  font_cfg.atlas_pad = ER_UI_BOOT_FONT_ATLAS_PAD;
  font_cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  font_cfg.allocator = er_ui_boot_font_allocator();
  font_cfg.gl.user = 0;
  font_cfg.gl.create_texture = 0;
  font_cfg.gl.update_texture = 0;
  font_cfg.gl.destroy_texture = 0;

  er_println("ui renderer: init font");
  if (vr_font_face_create_from_memory(&font, g_er_font_geist_ttf, ER_FONT_GEIST_TTF_SIZE, &font_cfg) != VR_OK || font == 0) {
    er_println("ui renderer: font failed");
    return;
  }

  scene_budget = er_ui_scene_budget_native_interactive_frame();
  if (er_ui_gop_memory_plan_from_tile_plan(&tile_plan, ER_UI_BOOT_BACKING_BUFFERS,
                                           ER_UI_BOOT_COMMAND_BYTES, ER_UI_BOOT_GLYPH_CACHE_BYTES,
                                           ER_UI_BOOT_SURFACE_BYTES, &memory_plan) == 0u) {
    er_println("ui renderer: memory plan failed");
    vr_font_face_destroy(font);
    return;
  }
  memory_budget.scanout_bytes = memory_plan.scanout_bytes;
  memory_budget.backing_bytes = memory_plan.backing_bytes;
  memory_budget.tile_state_bytes = memory_plan.tile_state_bytes;
  memory_budget.dirty_queue_bytes = memory_plan.dirty_queue_bytes;
  memory_budget.command_bytes = ER_UI_BOOT_COMMAND_BYTES;
  memory_budget.glyph_cache_bytes = ER_UI_BOOT_GLYPH_CACHE_BYTES;
  memory_budget.surface_bytes = ER_UI_BOOT_SURFACE_BYTES;
  memory_budget.total_bytes = ER_UI_BOOT_MEMORY_BUDGET_BYTES;
  if (er_ui_gop_memory_plan_first_budget_violation(memory_plan, memory_budget, &memory_violation) != 0u) {
    er_print("ui renderer: memory budget exceeded ");
    er_print(memory_violation.name);
    er_print(" actual=");
    er_print_u64_dec(memory_violation.actual);
    er_print(" limit=");
    er_print_u64_dec(memory_violation.limit);
    er_println("");
    vr_font_face_destroy(font);
    return;
  }
  frame_budget = er_ui_gop_frame_budget_from_plan(&tile_plan, scene_budget, ER_UI_BOOT_RENDER_OVERDRAW_BUDGET);

  if (er_ui_demo_apps_state_init(&demo_state, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: demo app state failed");
    vr_font_face_destroy(font);
    return;
  }

  er_println("ui renderer: render scene");
  if (er_ui_boot_render_scene(&demo_state, font, mode, &tile_plan, memory_plan, scene_budget,
                              frame_budget, theme) == 0u) {
    er_ui_demo_apps_state_destroy(&demo_state);
    vr_font_face_destroy(font);
    return;
  }

  er_gfx_console_set_enabled(0u);
  er_println("ui renderer: interactive");
  er_println("ui input: 1 resources, 2 network, 3 people, tab/right next, left previous, esc/q exit");

  if (SystemTable != 0 && SystemTable->ConIn != 0) {
    read_key = SystemTable->ConIn->ReadKeyStroke;
  }
  if (read_key == 0) {
    er_println("ui input: unavailable");
    er_ui_demo_apps_state_destroy(&demo_state);
    vr_font_face_destroy(font);
    return;
  }

  for (;;) {
    EFI_INPUT_KEY key;
    if (read_key(SystemTable->ConIn, &key) != EFI_SUCCESS) {
      er_halt_once();
    } else if (er_ui_boot_key_exits(key) != 0u) {
      break;
    } else {
      er_ui_action_t action;
      bool changed = false;
      if (er_ui_boot_action_from_key(&demo_state, key, &action) != 0u &&
          er_ui_demo_apps_apply_action(&demo_state, action, &changed) == ER_UI_OK &&
          changed) {
        if (er_ui_boot_render_scene(&demo_state, font, mode, &tile_plan, memory_plan, scene_budget,
                                    frame_budget, theme) == 0u) {
          break;
        }
      }
    }
  }

  er_ui_demo_apps_state_destroy(&demo_state);
  vr_font_face_destroy(font);
  er_println("ui renderer: exited");
}

static void er_run_invalid_profile(void) {
  er_print("invalid boot profile: ");
  er_print_u64_dec((UINT64)ER_BOOT_PROFILE);
  er_println("");
  er_halt_forever();
}

static void er_run_boot_profile(EFI_SYSTEM_TABLE* SystemTable) {
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_UI) {
    er_run_ui_profile(SystemTable);
    return;
  }

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

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_NATIVE) {
    er_run_native_profile();
    return;
  }

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_TPM) {
    er_run_tpm_profile(SystemTable);
    return;
  }

  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_GPU) {
    er_run_gpu_profile();
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

  er_run_boot_profile(SystemTable);
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_UI) {
    return EFI_SUCCESS;
  }

  er_println("Press any key to halt...");
  er_wait_for_key_then_halt(SystemTable);
  return EFI_SUCCESS;
}
