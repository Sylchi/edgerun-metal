#include "er_types.h"
#include "er_print.h"
#include "er_pci.h"
#include "er_mmio.h"
#include "er_mem.h"
#include "er_acpi.h"
#include "er_boot_profile.h"
#include "er_gfx_console.h"
#include "er_ps2_keyboard.h"
#include "er_tpm.h"
#include "er_ui_surface_renderer.h"
#include "er_ui_components.h"
#include "er_ui_ledger_app.h"
#include "er_ui_metal.h"
#include "er_ui_theme.h"
#include "er_ui_wasm_app.h"
#include "er_virtio_gpu.h"
#include "erwire.h"
#include "er_native_boot.h"
#include "font_geist.h"
#include "wasm_vm.h"
#include "wasm_ui_counter_module.h"

#ifndef ER_BOOT_PROFILE
#define ER_BOOT_PROFILE ER_BOOT_PROFILE_UI
#endif

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
#define ER_EFI_MEMORY_MAP_BYTES (128u * 1024u)
#define ER_EFI_EXIT_BOOT_SERVICES_ATTEMPTS 2u
#define ER_WASM_DRIVER_MEMORY_BYTES (64u * 1024u)
#define ER_UI_BOOT_APP_COUNT 2u
#define ER_UI_BOOT_APP_MEMORY_BYTES (64u * 1024u)
#define ER_UI_WASM_RELAY_INBOX_BASE 0u
#define ER_UI_WASM_RELAY_INBOX_BYTES 1024u
#define ER_UI_WASM_RELAY_OUTBOX_BASE 1024u
#define ER_UI_WASM_RELAY_OUTBOX_BYTES 2048u
#define ER_UI_WASM_PRESENTATION_SEQUENCE 1u
#define ER_UI_WASM_PRESENTATION_ID_SEED 0x10u
#define ER_UI_WASM_JURISDICTION_ID_SEED 0x30u
#define ER_UI_WASM_ADMISSION_ID_SEED 0x50u
#define ER_UI_WASM_APP_NODE_ID_SEED 0x70u
#define ER_UI_WASM_RELAY_NODE_ID_SEED 0x90u
#define ER_UI_WASM_ROUTE_HASH_SEED 0xb0u
#define ER_UI_WASM_APP_SEED_STRIDE 0x10u
#define ER_UI_WASM_PS2_INPUT_EPOCH_STRIDE 1u
#define ER_UI_WASM_EXECUTE_EPOCH_STRIDE 2u
#define ER_UI_WASM_COUNTER_PACKET_BYTES (ER_WASM_UI_COMMAND_LIST_HEADER_LEN + \
                                         ER_WASM_UI_RECT_RECORD_LEN + \
                                         ER_WASM_UI_HIT_RECORD_LEN + \
                                         ER_WASM_UI_QUAD_RECORD_LEN)
#define ER_ACPI_SIGNATURE_BYTES 4u
#define ER_BYTE_MASK 0xffu
#define ER_GPU_PROFILE_POLL_LIMIT 1000000u
#define ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX 1280u
#define ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX 720u
#define ER_GPU_PROFILE_FRAMEBUFFER_WIDTH 1280u
#define ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT 720u
#define ER_GPU_PROFILE_RESOURCE_ID 1u
#define ER_GPU_PROFILE_SCANOUT_ID 0u
#define ER_UI_BOOT_GPU_RESOURCE_ID 2u
#define ER_UI_BOOT_GPU_SCANOUT_ID 0u
#define ER_GPU_PROFILE_TOP_COLOR 0x0040d0e0u
#define ER_GPU_PROFILE_BOTTOM_COLOR 0x00202020u
#define ER_TPM_PROFILE_COMMAND_BYTES 128u
#define ER_TPM_PROFILE_RESPONSE_BYTES 512u
#define ER_TPM_PROFILE_RANDOM_REQUEST_BYTES 16u
#define ER_TPM_PROFILE_DIGEST_BYTES 32u
#define ER_TPM_PROFILE_SIGNATURE_BYTES 64u
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
static UINT8 g_ui_boot_app_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MEMORY_BYTES];
static UINT8 g_ui_boot_arena[ER_UI_BOOT_ARENA_SIZE];
static UINT8 g_efi_memory_map[ER_EFI_MEMORY_MAP_BYTES];
static UINT32 g_gpu_profile_framebuffer[ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX *
                                        ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX];
static UINTN g_ui_boot_arena_used;
static UINT8 g_log_u64_stage = ER_LOG_U64_STAGE_IDLE;
static UINT8 g_log_hex_stage = ER_LOG_HEX_STAGE_ID;
static UINT64 g_log_bus = 0;
static UINT64 g_log_dev = 0;
static UINT64 g_log_func = 0;

typedef struct {
  ErAppUiPresentation presentation;
  ErUiWasmAppRuntime runtime;
  er_ui_scene_t scene;
  UINT8 ready;
} ErUiBootAppContext;

typedef struct {
  vr_font_face_t* font;
  ErUiSurfaceMode mode;
  ErUiSurface* surface;
  ErVirtioGpu* gpu;
  const ErVirtioGpuFramebuffer* framebuffer;
  const ErUiSurfaceTilePlan* tile_plan;
  ErUiSurfaceMemoryPlan memory_plan;
  er_ui_scene_budget_t scene_budget;
  ErUiSurfaceFrameBudget frame_budget;
  er_ui_resolved_theme_t theme;
  ErUiBootAppContext* apps;
  UINT32 app_count;
  UINT32 active_app;
} ErUiBootRenderContext;

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

static void er_fill_nonzero_bytes(UINT8* bytes, UINTN len, UINT8 seed) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0u; i < len; ++i) {
    bytes[i] = (UINT8)(seed + (UINT8)i);
  }
}

static vr_font_allocator_t er_ui_boot_font_allocator(void) {
  vr_font_allocator_t allocator;
  allocator.user = g_ui_boot_arena;
  allocator.alloc = er_ui_boot_alloc;
  allocator.realloc = er_ui_boot_realloc;
  allocator.free = er_ui_boot_free;
  return allocator;
}

static UINT8 er_ui_boot_create_font(UINT32 height, vr_font_face_t** out_font) {
  vr_font_config_t font_cfg;

  if (out_font == 0) {
    return 0u;
  }
  *out_font = 0;
  g_ui_boot_arena_used = 0u;
  font_cfg.px_size = height <= ER_UI_BOOT_LOW_HEIGHT_MAX ? ER_UI_BOOT_SMALL_FONT_PX : ER_UI_BOOT_LARGE_FONT_PX;
  font_cfg.atlas_width = ER_UI_BOOT_FONT_ATLAS_SIZE;
  font_cfg.atlas_height = ER_UI_BOOT_FONT_ATLAS_SIZE;
  font_cfg.atlas_pad = ER_UI_BOOT_FONT_ATLAS_PAD;
  font_cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  font_cfg.allocator = er_ui_boot_font_allocator();
  font_cfg.gl.user = 0;
  font_cfg.gl.create_texture = 0;
  font_cfg.gl.update_texture = 0;
  font_cfg.gl.destroy_texture = 0;
  return (UINT8)(vr_font_face_create_from_memory(out_font, g_er_font_geist_ttf,
                                                ER_FONT_GEIST_TTF_SIZE, &font_cfg) == VR_OK &&
                 *out_font != 0);
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

static void er_pause_once(void) {
  __asm__ __volatile__("pause");
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

static UINT8 er_exit_boot_services(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
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

static UINT8 er_gpu_profile_wait_ok(ErVirtioGpu* gpu) {
  UINT32 poll_count;

  for (poll_count = 0u; poll_count < ER_GPU_PROFILE_POLL_LIMIT; ++poll_count) {
    if (er_virtio_gpu_poll_ok_nodata(gpu) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_gpu_profile_wait_display_info(ErVirtioGpu* gpu,
                                              ErVirtioGpuDisplayInfo* out_info) {
  UINT32 poll_count;

  if (out_info == 0) {
    return 0u;
  }
  for (poll_count = 0u; poll_count < ER_GPU_PROFILE_POLL_LIMIT; ++poll_count) {
    if (er_virtio_gpu_poll_display_info(gpu, out_info) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_ui_boot_gpu_present(const ErUiBootRenderContext* render) {
  if (render == 0 || render->gpu == 0 || render->framebuffer == 0) {
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_transfer(render->gpu, render->framebuffer) == 0u ||
      er_gpu_profile_wait_ok(render->gpu) == 0u ||
      er_virtio_gpu_submit_framebuffer_flush(render->gpu, render->framebuffer) == 0u ||
      er_gpu_profile_wait_ok(render->gpu) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_ui_boot_gpu_prepare_scanout(ErVirtioGpu* gpu,
                                            ErVirtioGpuFramebuffer* framebuffer,
                                            ErUiSurface* surface,
                                            ErUiSurfaceMode* out_mode) {
  if (gpu == 0 || framebuffer == 0 || surface == 0 || out_mode == 0) {
    return 0u;
  }
  if (er_virtio_gpu_framebuffer_init(framebuffer, ER_UI_BOOT_GPU_RESOURCE_ID,
                                     ER_UI_BOOT_GPU_SCANOUT_ID,
                                     ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH,
                                     ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH,
                                     g_gpu_profile_framebuffer,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX *
                                         ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX) == 0u) {
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_create(gpu, framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u ||
      er_virtio_gpu_submit_framebuffer_attach(gpu, framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u ||
      er_virtio_gpu_submit_framebuffer_set_scanout(gpu, framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u) {
    return 0u;
  }
  surface->pixels = framebuffer->pixels;
  surface->width = framebuffer->width;
  surface->height = framebuffer->height;
  surface->stride = framebuffer->stride_pixels;
  surface->pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  out_mode->width = framebuffer->width;
  out_mode->height = framebuffer->height;
  out_mode->stride = framebuffer->stride_pixels;
  out_mode->refresh_hz = 1u;
  out_mode->pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  return (UINT8)(er_ui_surface_valid(surface) != 0u &&
                 er_ui_surface_mode_valid(out_mode) != 0u);
}

static UINT8 er_gpu_profile_render_component_scene_to_framebuffer(ErVirtioGpuFramebuffer* framebuffer,
                                                                  vr_font_face_t* font,
                                                                  er_ui_resolved_theme_t theme,
                                                                  ErUiSurfaceRenderStats* out_stats) {
  er_ui_scene_t scene = {0};
  ErUiSurface surface;
  er_ui_scene_stats_t scene_stats;
  er_ui_component_gallery_state_t gallery_state;

  if (framebuffer == 0 || framebuffer->initialized == 0u || framebuffer->pixels == 0 || font == 0 ||
      framebuffer->width == 0u || framebuffer->height == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiSurfaceRenderStats){0};
    }
    return 0u;
  }

  er_ui_component_gallery_state_init(&gallery_state);
  if (er_ui_scene_init_with_allocator(&scene, theme.colors.bg, er_ui_boot_allocator()) != ER_UI_OK ||
      er_ui_edgerun_metal_surface_emit(&scene, font,
                                       er_ui_bounds(0.0f, 0.0f, (float)framebuffer->width, (float)framebuffer->height),
                                       theme, &gallery_state) != ER_UI_OK) {
    er_ui_scene_destroy(&scene);
    if (out_stats != 0) {
      *out_stats = (ErUiSurfaceRenderStats){0};
    }
    return 0u;
  }
  scene_stats = er_ui_scene_stats(&scene);
  if (scene_stats.rects == 0u || scene_stats.text_quads == 0u) {
    er_ui_scene_destroy(&scene);
    if (out_stats != 0) {
      *out_stats = (ErUiSurfaceRenderStats){0};
    }
    return 0u;
  }

  surface.pixels = framebuffer->pixels;
  surface.width = framebuffer->width;
  surface.height = framebuffer->height;
  surface.stride = framebuffer->stride_pixels;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  if (er_ui_surface_render_scene_with_font_stats(&surface, &scene, font, out_stats) == 0u) {
    er_ui_scene_destroy(&scene);
    return 0u;
  }
  er_ui_scene_destroy(&scene);
  return 1u;
}

static UINT8 er_gpu_profile_flush_framebuffer(ErVirtioGpu* gpu, UINT32 width, UINT32 height) {
  ErVirtioGpuFramebuffer framebuffer;
  ErUiSurfaceRenderStats render_stats;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  vr_font_face_t* font = 0;

  if (er_virtio_gpu_framebuffer_init(&framebuffer, ER_GPU_PROFILE_RESOURCE_ID,
                                     ER_GPU_PROFILE_SCANOUT_ID,
                                     ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                     width, height, width,
                                     g_gpu_profile_framebuffer,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX *
                                         ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX) == 0u) {
    er_println("gpu framebuffer: unsupported dimensions");
    return 0u;
  }
  if (er_ui_boot_create_font(height, &font) == 0u) {
    er_println("gpu framebuffer: font failed");
    return 0u;
  }
  if (er_gpu_profile_render_component_scene_to_framebuffer(&framebuffer, font, theme, &render_stats) == 0u) {
    er_println("gpu framebuffer: scene render failed");
    vr_font_face_destroy(font);
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_create(gpu, &framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u) {
    er_println("gpu framebuffer: create failed");
    vr_font_face_destroy(font);
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_attach(gpu, &framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u) {
    er_println("gpu framebuffer: attach failed");
    vr_font_face_destroy(font);
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_set_scanout(gpu, &framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u) {
    er_println("gpu framebuffer: scanout failed");
    vr_font_face_destroy(font);
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_transfer(gpu, &framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u) {
    er_println("gpu framebuffer: transfer failed");
    vr_font_face_destroy(font);
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_flush(gpu, &framebuffer) == 0u ||
      er_gpu_profile_wait_ok(gpu) == 0u) {
    er_println("gpu framebuffer: flush failed");
    vr_font_face_destroy(font);
    return 0u;
  }
  er_print("gpu framebuffer: scene bytes=");
  er_print_u64_dec(render_stats.bytes_written);
  er_print(" rects=");
  er_print_u64_dec(render_stats.rects);
  er_print(" text=");
  er_print_u64_dec(render_stats.text_quads);
  er_println("");
  vr_font_face_destroy(font);
  return 1u;
}

static void er_run_gpu_profile(void) {
  ErVirtioGpu gpu;
  ErVirtioGpuDisplayInfo display_info;
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

  if (er_virtio_gpu_submit_get_display_info(&gpu) == 0u) {
    er_println("gpu display: submit failed");
    return;
  }
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  if (er_gpu_profile_wait_display_info(&gpu, &display_info) == 0u) {
    er_println("gpu display: poll timeout");
    return;
  }
  er_print("gpu display: scanout0 enabled=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].enabled);
  er_print(" width=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.width);
  er_print(" height=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.height);
  er_println("");
  er_print("gpu framebuffer: target width=");
  er_print_u64_dec((UINT64)ER_GPU_PROFILE_FRAMEBUFFER_WIDTH);
  er_print(" height=");
  er_print_u64_dec((UINT64)ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT);
  er_println("");
  if (er_gpu_profile_flush_framebuffer(&gpu, ER_GPU_PROFILE_FRAMEBUFFER_WIDTH,
                                       ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT) != 0u) {
    er_println("gpu framebuffer: flushed");
  }
}

static void er_run_tpm_profile(EFI_SYSTEM_TABLE* SystemTable) {
  ErAcpiRsdpInfo rsdp;
  ErAcpiTableList tables;
  ErTpm2Info tpm2;
  ErTpmCrbTransport crb;
  ErTpmP256Primary primary;
  UINT8 command[ER_TPM_PROFILE_COMMAND_BYTES];
  UINT8 response[ER_TPM_PROFILE_RESPONSE_BYTES];
  UINT8 random[ER_TPM_PROFILE_DIGEST_BYTES];
  UINT8 digest[ER_TPM_PROFILE_DIGEST_BYTES];
  UINT8 signature[ER_TPM_PROFILE_SIGNATURE_BYTES];
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

  if (er_tpm_build_get_random_command(ER_TPM_PROFILE_RANDOM_REQUEST_BYTES, command, (UINT32)sizeof(command),
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
  er_print_u64_hex((UINT64)signature[ER_TPM_PROFILE_SIGNATURE_BYTES - 1u]);
  er_println("");

  if (er_tpm_build_flush_context_command(primary.handle, command,
                                         (UINT32)sizeof(command),
                                         &command_len) != 0u) {
    (void)er_tpm_crb_transact(&crb, command, command_len, response,
                              (UINT32)sizeof(response), &response_len);
  }
  er_println("tpm: CRB direct command path ok");
}

static UINT8 er_ui_boot_append_wasm_scene(er_ui_scene_t* scene, const er_ui_scene_t* wasm_scene) {
  size_t i;

  if (scene == 0 || wasm_scene == 0) {
    return 0u;
  }
  for (i = 0u; i < wasm_scene->rect_count; ++i) {
    if (er_ui_scene_push_rect(scene, wasm_scene->rects[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->hit_count; ++i) {
    if (er_ui_scene_push_hit(scene, wasm_scene->hits[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->drag_source_count; ++i) {
    if (er_ui_scene_push_drag_source(scene, wasm_scene->drag_sources[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->drop_target_count; ++i) {
    if (er_ui_scene_push_drop_target(scene, wasm_scene->drop_targets[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->transition_count; ++i) {
    if (er_ui_scene_push_transition(scene, wasm_scene->transitions[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->icon_quad_count; ++i) {
    if (er_ui_scene_push_icon_quad(scene, wasm_scene->icon_quads[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->text_quad_count; ++i) {
    if (er_ui_scene_push_text_quad(scene, wasm_scene->text_quads[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_ui_boot_app_seed(UINT8 seed, UINT32 app_index) {
  return (UINT8)(seed + (UINT8)(app_index * ER_UI_WASM_APP_SEED_STRIDE));
}

static void er_ui_boot_prepare_wasm_presentation(const er_ui_scene_budget_t* scene_budget,
                                                 UINT32 app_index,
                                                 ErAppUiPresentation* out_presentation) {
  if (scene_budget == 0 || out_presentation == 0) {
    return;
  }
  er_mem_zero((UINT8*)out_presentation, (UINTN)sizeof(*out_presentation));
  out_presentation->abi_version = ER_APP_ABI_VERSION;
  er_fill_nonzero_bytes(out_presentation->presentation_id.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_PRESENTATION_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->jurisdiction_id.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_JURISDICTION_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->admission_id.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_ADMISSION_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->app_node_id.bytes, ER_NODE_ID_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_APP_NODE_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->ui_relay_node_id.bytes, ER_NODE_ID_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_RELAY_NODE_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->route_hash.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_ROUTE_HASH_SEED, app_index));
  out_presentation->sequence = ER_UI_WASM_PRESENTATION_SEQUENCE + (UINT64)app_index;
  out_presentation->max_rects = (UINT64)scene_budget->rects;
  out_presentation->max_hits = (UINT64)scene_budget->hits;
  out_presentation->max_drag_sources = (UINT64)scene_budget->drag_sources;
  out_presentation->max_drop_targets = (UINT64)scene_budget->drop_targets;
  out_presentation->max_transitions = (UINT64)scene_budget->transitions;
  out_presentation->max_icon_quads = (UINT64)scene_budget->icon_quads;
  out_presentation->max_text_quads = (UINT64)scene_budget->text_quads;
}

static UINT8 er_ui_boot_execute_wasm_counter(ErUiWasmAppRuntime* runtime) {
  INT64 main_result = 0;

  if (runtime == 0) {
    return 0u;
  }
  if (er_ui_wasm_app_execute(runtime, &main_result) != 0 ||
      main_result != (INT64)(UINT64)ER_UI_WASM_COUNTER_PACKET_BYTES) {
    return 0u;
  }
  er_print("ui renderer: wasm scene rects=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.rects);
  er_print(" hits=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.hits);
  er_print(" text=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.text_quads);
  er_println("");
  return 1u;
}

static UINT8 er_ui_boot_prepare_wasm_counter(ErUiWasmAppRuntime* runtime,
                                             ErAppUiPresentation* presentation,
                                             er_ui_scene_t* wasm_scene,
                                             UINT8* memory,
                                             UINT32 memory_size,
                                             UINT32 app_index,
                                             const er_ui_scene_budget_t* scene_budget) {
  if (runtime == 0 || presentation == 0 || wasm_scene == 0 || memory == 0 ||
      memory_size == 0u || scene_budget == 0) {
    return 0u;
  }
  er_ui_boot_prepare_wasm_presentation(scene_budget, app_index, presentation);
  er_mem_zero((UINT8*)runtime, (UINTN)sizeof(*runtime));
  runtime->memory = memory;
  runtime->memory_size = memory_size;
  runtime->relay_inbox_base = ER_UI_WASM_RELAY_INBOX_BASE;
  runtime->relay_inbox_len = ER_UI_WASM_RELAY_INBOX_BYTES;
  runtime->relay_outbox_base = ER_UI_WASM_RELAY_OUTBOX_BASE;
  runtime->relay_outbox_len = ER_UI_WASM_RELAY_OUTBOX_BYTES;
  runtime->presentation = presentation;
  runtime->scene = wasm_scene;
  runtime->input_epoch_modifier.tick_stride = ER_UI_WASM_PS2_INPUT_EPOCH_STRIDE;
  runtime->execute_epoch_modifier.tick_stride = ER_UI_WASM_EXECUTE_EPOCH_STRIDE;
  if (er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                             &g_host_calls, runtime) != 0) {
    return 0u;
  }
  return er_ui_boot_execute_wasm_counter(runtime);
}

static void er_ui_boot_destroy_app_contexts(ErUiBootAppContext* apps, UINT32 app_count) {
  UINT32 i;

  if (apps == 0) {
    return;
  }
  for (i = 0u; i < app_count; ++i) {
    er_ui_scene_destroy(&apps[i].scene);
    er_mem_zero((UINT8*)&apps[i], (UINTN)sizeof(apps[i]));
  }
}

static UINT8 er_ui_boot_prepare_app_contexts(ErUiBootAppContext* apps,
                                             UINT32 app_count,
                                             const er_ui_scene_budget_t* scene_budget,
                                             er_ui_color4_t clear) {
  UINT32 i;

  if (apps == 0 || app_count == 0u || scene_budget == 0 ||
      app_count > ER_UI_BOOT_APP_COUNT) {
    return 0u;
  }
  for (i = 0u; i < app_count; ++i) {
    er_mem_zero((UINT8*)&apps[i], (UINTN)sizeof(apps[i]));
    if (er_ui_scene_init_with_allocator(&apps[i].scene, clear,
                                        er_ui_boot_allocator()) != ER_UI_OK) {
      er_ui_boot_destroy_app_contexts(apps, i);
      return 0u;
    }
    if (er_ui_boot_prepare_wasm_counter(&apps[i].runtime,
                                        &apps[i].presentation,
                                        &apps[i].scene,
                                        g_ui_boot_app_memory[i],
                                        ER_UI_BOOT_APP_MEMORY_BYTES,
                                        i,
                                        scene_budget) == 0u) {
      er_ui_boot_destroy_app_contexts(apps, i + 1u);
      return 0u;
    }
    apps[i].ready = 1u;
  }
  return 1u;
}

static ErUiBootAppContext* er_ui_boot_active_app(ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

static const ErUiBootAppContext* er_ui_boot_active_app_const(const ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

static UINT8 er_ui_boot_switch_app_for_surface(ErUiBootRenderContext* render, UINT32 surface_id) {
  UINT32 app_index;

  if (render == 0 || render->apps == 0 || render->app_count == 0u) {
    return 0u;
  }
  switch (surface_id) {
    case ER_UI_LEDGER_APP_LEDGER_ID:
      app_index = 0u;
      break;
    case ER_UI_LEDGER_APP_PAYMENTS_ID:
      app_index = render->app_count > 1u ? 1u : 0u;
      break;
    case ER_UI_LEDGER_APP_ACCESS_ID:
      app_index = 0u;
      break;
    default:
      return 1u;
  }
  if (app_index >= render->app_count || render->apps[app_index].ready == 0u) {
    return 0u;
  }
  render->active_app = app_index;
  return 1u;
}

static UINT8 er_ui_boot_render_scene(er_ui_scene_t* scene,
                                     er_ui_ledger_app_state_t* ledger_state,
                                     const ErUiBootRenderContext* render) {
  const ErUiBootAppContext* active_app;
  er_ui_scene_stats_t scene_stats;
  er_ui_scene_budget_violation_t scene_violation;
  ErUiSurfaceRenderStats render_stats;
  ErUiSurfaceFrameBudgetViolation frame_violation;

  if (scene == 0 || ledger_state == 0 || render == 0 || render->font == 0 ||
      render->surface == 0 || render->tile_plan == 0) {
    return 0u;
  }

  er_ui_scene_clear_commands(scene);
  if (er_ui_ledger_app_emit_scene(ledger_state, scene, render->font,
                                 er_ui_bounds(0.0f, 0.0f, (float)render->mode.width, (float)render->mode.height),
                                 render->theme) != ER_UI_OK) {
    er_println("ui renderer: scene build failed");
    return 0u;
  }
  active_app = er_ui_boot_active_app_const(render);
  if (active_app != 0 &&
      er_ui_boot_append_wasm_scene(scene, &active_app->scene) == 0u) {
    er_println("ui renderer: wasm scene append failed");
    return 0u;
  }

  scene_stats = er_ui_scene_stats(scene);
  if (er_ui_scene_first_budget_violation(scene_stats, render->scene_budget, &scene_violation)) {
    er_print("ui renderer: scene budget exceeded ");
    er_print(scene_violation.name);
    er_print(" actual=");
    er_print_u64_dec((UINT64)scene_violation.actual);
    er_print(" limit=");
    er_print_u64_dec((UINT64)scene_violation.limit);
    er_println("");
    return 0u;
  }

  if (er_ui_surface_render_scene_with_font_stats(render->surface, scene, render->font, &render_stats) == 0u) {
    er_println("ui renderer: render failed");
    return 0u;
  }
  if (er_ui_boot_gpu_present(render) == 0u) {
    er_println("ui renderer: virtio gpu present failed");
    return 0u;
  }

  if (er_ui_surface_render_stats_first_budget_violation(render_stats, render->frame_budget, &frame_violation) != 0u) {
    er_print("ui renderer: frame budget exceeded ");
    er_print(frame_violation.name);
    er_print(" actual=");
    er_print_u64_dec(frame_violation.actual);
    er_print(" limit=");
    er_print_u64_dec(frame_violation.limit);
    er_println("");
    return 0u;
  }

  er_print("ui renderer: app=");
  er_print_u64_dec((UINT64)render->active_app);
  er_print(" surface=");
  er_print_u64_dec((UINT64)er_ui_workspace_focused_surface_id(&ledger_state->shell));
  er_print(" bytes=");
  er_print_u64_dec(render_stats.bytes_written);
  er_print(" rects=");
  er_print_u64_dec(render_stats.rects);
  er_print(" text=");
  er_print_u64_dec(render_stats.text_quads);
  er_print(" tile_bytes=");
  er_print_u64_dec(render->tile_plan->max_tile_bytes);
  er_print(" mem=");
  er_print_u64_dec(render->memory_plan.total_bytes);
  er_println("");

  return 1u;
}

static er_ui_action_t er_ui_boot_action_from_ps2(er_ui_runtime_state_t* runtime,
                                                 const er_ui_scene_t* scene,
                                                 ErPs2KeyboardAction input) {
  er_ui_action_t action = {0};

  action.kind = ER_UI_ACTION_NONE;
  if (input.kind == ER_PS2_KEYBOARD_ACTION_UI_KEY) {
    return er_ui_runtime_key_down(runtime, scene, input.key, input.modifiers);
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE) {
    action.kind = ER_UI_ACTION_TAB_SELECTED;
    action.id = input.surface_id;
  }
  return action;
}

static UINT8 er_ui_boot_apply_input(er_ui_ledger_app_state_t* ledger_state,
                                    er_ui_runtime_state_t* runtime,
                                    er_ui_scene_t* scene,
                                    ErUiBootRenderContext* render,
                                    ErPs2KeyboardAction input,
                                    UINT8* out_redraw) {
  ErUiBootAppContext* active_app;
  er_ui_action_t action;
  bool changed = false;

  if (out_redraw == 0) {
    return 0u;
  }
  *out_redraw = 0u;
  if (ledger_state == 0 || runtime == 0 || scene == 0) {
    return 0u;
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_NONE) {
    return 1u;
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE) {
    if (er_ui_boot_switch_app_for_surface(render, input.surface_id) == 0u) {
      return 0u;
    }
    *out_redraw = 1u;
  }
  active_app = er_ui_boot_active_app(render);
  if (input.kind == ER_PS2_KEYBOARD_ACTION_UI_KEY && active_app != 0) {
    if (er_ui_wasm_app_deliver_key_input(&active_app->runtime,
                                         input.key, input.modifiers) != 0 ||
        er_ui_boot_execute_wasm_counter(&active_app->runtime) == 0u) {
      return 0u;
    }
    *out_redraw = 1u;
  }
  action = er_ui_boot_action_from_ps2(runtime, scene, input);
  if (action.kind == ER_UI_ACTION_NONE) {
    return 1u;
  }
  if (er_ui_ledger_app_apply_action(ledger_state, action, &changed) != ER_UI_OK) {
    return 0u;
  }
  *out_redraw = (UINT8)(changed || er_ui_action_needs_redraw(action));
  return 1u;
}

//@optimizer-ignore-function post-ExitBootServices input loop must poll PS/2 I/O and redraw after accepted key events
static void er_ui_boot_input_loop(er_ui_ledger_app_state_t* ledger_state,
                                  er_ui_runtime_state_t* runtime,
                                  er_ui_scene_t* scene,
                                  ErUiBootRenderContext* render) {
  ErPs2KeyboardState keyboard = {0};

  for (;;) {
    ErPs2KeyboardAction input;
    UINT8 redraw = 0u;

    if (er_ps2_keyboard_poll(&keyboard, &input) == 0u) {
      er_halt_forever();
    }
    if (input.kind == ER_PS2_KEYBOARD_ACTION_QUIT) {
      er_halt_forever();
    }
    if (input.kind == ER_PS2_KEYBOARD_ACTION_NONE) {
      er_pause_once();
      continue;
    }
    if (er_ui_boot_apply_input(ledger_state, runtime, scene, render, input, &redraw) == 0u) {
      er_halt_forever();
    }
    if (redraw != 0u &&
        er_ui_boot_render_scene(scene, ledger_state, render) == 0u) {
      er_halt_forever();
    }
  }
}

static void er_run_ui_profile(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  er_ui_scene_budget_t scene_budget;
  ErUiSurfaceMode mode;
  ErUiSurfaceFrameBudget frame_budget;
  ErUiSurfaceTilePlan tile_plan;
  ErUiSurfaceMemoryPlan memory_plan;
  ErUiSurfaceMemoryBudget memory_budget;
  ErUiSurfaceMemoryBudgetViolation memory_violation;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  er_ui_scene_t scene = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_ledger_app_state_t ledger_state = {0};
  ErUiBootAppContext apps[ER_UI_BOOT_APP_COUNT];
  ErVirtioGpu gpu;
  ErVirtioGpuFramebuffer framebuffer;
  ErVirtioGpuDisplayInfo display_info;
  ErUiSurface surface;
  ErUiBootRenderContext render_context = {0};
  vr_font_face_t* font = 0;

  er_mem_zero((UINT8*)apps, (UINTN)sizeof(apps));

  er_println("boot profile: ui");
  if (er_virtio_gpu_init_first_pci(&gpu) == 0u) {
    er_println("ui renderer: virtio gpu unavailable");
    return;
  }
  if (er_virtio_gpu_submit_get_display_info(&gpu) == 0u) {
    er_println("ui renderer: virtio gpu display submit failed");
    return;
  }
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  if (er_gpu_profile_wait_display_info(&gpu, &display_info) == 0u) {
    er_println("ui renderer: virtio gpu display poll failed");
    return;
  }
  er_print("ui renderer: virtio gpu scanout0 width=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.width);
  er_print(" height=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.height);
  er_println("");
  if (er_ui_boot_gpu_prepare_scanout(&gpu, &framebuffer, &surface, &mode) == 0u) {
    er_println("ui renderer: virtio gpu scanout failed");
    return;
  }
  if (er_ui_surface_tile_plan(&surface, ER_UI_BOOT_TILE_WIDTH, ER_UI_BOOT_TILE_HEIGHT,
                              ER_UI_BOOT_MAX_DIRTY_TILES, &tile_plan) == 0u ||
      tile_plan.tile_count > ER_UI_BOOT_MAX_TILE_MARKS) {
    er_println("ui renderer: tile plan failed");
    return;
  }
  er_println("ui renderer: init font");
  if (er_ui_boot_create_font(mode.height, &font) == 0u) {
    er_println("ui renderer: font failed");
    return;
  }

  scene_budget = er_ui_scene_budget_native_interactive_frame();
  if (er_ui_surface_memory_plan_from_tile_plan(&tile_plan, ER_UI_BOOT_BACKING_BUFFERS,
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
  if (er_ui_surface_memory_plan_first_budget_violation(memory_plan, memory_budget, &memory_violation) != 0u) {
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
  frame_budget = er_ui_surface_frame_budget_from_plan(&tile_plan, scene_budget, ER_UI_BOOT_RENDER_OVERDRAW_BUDGET);
  render_context.font = font;
  render_context.mode = mode;
  render_context.surface = &surface;
  render_context.gpu = &gpu;
  render_context.framebuffer = &framebuffer;
  render_context.tile_plan = &tile_plan;
  render_context.memory_plan = memory_plan;
  render_context.scene_budget = scene_budget;
  render_context.frame_budget = frame_budget;
  render_context.theme = theme;
  render_context.apps = apps;
  render_context.app_count = ER_UI_BOOT_APP_COUNT;
  render_context.active_app = 0u;

  if (er_ui_ledger_app_state_init(&ledger_state, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: ledger app state failed");
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_runtime_state_init_with_allocator(&runtime, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: runtime state failed");
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_scene_init_with_allocator(&scene, theme.colors.bg, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: scene state failed");
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_boot_prepare_app_contexts(apps, ER_UI_BOOT_APP_COUNT, &scene_budget,
                                      theme.colors.bg) == 0u) {
    er_println("ui renderer: app contexts failed");
    er_ui_scene_destroy(&scene);
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }

  er_println("ui renderer: first frame deferred until boot services exit");
  er_println("boot services: exiting");
  er_gfx_console_set_enabled(0u);
  er_print_set_firmware_console_enabled(0u);
  if (er_exit_boot_services(ImageHandle, SystemTable) == 0u) {
    er_ui_boot_destroy_app_contexts(apps, ER_UI_BOOT_APP_COUNT);
    er_ui_scene_destroy(&scene);
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    er_halt_forever();
  }
  if (er_ui_boot_render_scene(&scene, &ledger_state, &render_context) == 0u) {
    er_halt_forever();
  }
  er_ui_boot_input_loop(&ledger_state, &runtime, &scene, &render_context);
}

static void er_run_invalid_profile(void) {
  er_print("invalid boot profile: ");
  er_print_u64_dec((UINT64)ER_BOOT_PROFILE);
  er_println("");
  er_halt_forever();
}

static void er_run_boot_profile(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_UI) {
    er_run_ui_profile(ImageHandle, SystemTable);
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

  er_run_boot_profile(ImageHandle, SystemTable);
  if (ER_BOOT_PROFILE == ER_BOOT_PROFILE_UI) {
    return EFI_SUCCESS;
  }

  er_println("Press any key to halt...");
  er_wait_for_key_then_halt(SystemTable);
  return EFI_SUCCESS;
}
