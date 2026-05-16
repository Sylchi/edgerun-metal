#include "er_types.h"
#include "er_print.h"
#include "wasm_vm.h"
#include "wasm_test_module.h"
#include "wasm_pci_scan_module.h"

static ErWasmHostCalls g_host_calls = {0};
static UINT8 g_log_u64_stage = 0;
static UINT8 g_log_hex_stage = 0;
static UINT64 g_log_bus = 0;
static UINT64 g_log_dev = 0;
static UINT64 g_log_func = 0;

static inline UINT32 er_in32(UINT16 port) {
  UINT32 value = 0;
  __asm__ __volatile__("inl %1, %0" : "=a"(value) : "Nd"(port));
  return value;
}

static inline void er_out32(UINT16 port, UINT32 value) {
  __asm__ __volatile__("outl %0, %1" : : "a"(value), "Nd"(port));
}

static void er_reset_log_state(void) {
  g_log_u64_stage = 0;
  g_log_hex_stage = 0;
  g_log_bus = 0;
  g_log_dev = 0;
  g_log_func = 0;
}

static INT64 er_pci_read32(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i) {
  UINT32 bus = (UINT32)bus_i & 0xff;
  UINT32 dev = (UINT32)dev_i & 0x1f;
  UINT32 func = (UINT32)func_i & 0x07;
  UINT32 offset = (UINT32)offset_i & 0xfc;
  UINT32 address = (UINT32)(0x80000000u | (bus << 16) | (dev << 11) | (func << 8) | offset);
  UINT32 value = 0;

  er_out32(0x0cf8, address);
  value = er_in32(0x0cfc);
  return (INT64)(UINT32)value;
}

static void er_pci_write32(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i, INT64 value_i) {
  UINT32 bus = (UINT32)bus_i & 0xff;
  UINT32 dev = (UINT32)dev_i & 0x1f;
  UINT32 func = (UINT32)func_i & 0x07;
  UINT32 offset = (UINT32)offset_i & 0xfc;
  UINT32 address = (UINT32)(0x80000000u | (bus << 16) | (dev << 11) | (func << 8) | offset);

  er_out32(0x0cf8, address);
  er_out32(0x0cfc, (UINT32)value_i);
}

static void er_print_u64_field(const char* label, UINT64 value) {
  er_print("    ");
  er_print(label);
  er_print(": ");
  er_print_u64_hex(value);
  er_print("\r\n");
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

EFI_STATUS EFIAPI efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable) {
  (void)ImageHandle;

  er_print_set_system_table(SystemTable);

  g_host_calls.log_u64 = er_log_u64;
  g_host_calls.log_hex = er_log_hex;
  g_host_calls.pci_read32 = er_pci_read32;
  g_host_calls.pci_write32 = er_pci_write32;

  er_println("EdgeRun Metal Core v0.2");
  er_println("UEFI boot OK");

  er_reset_log_state();
  er_run_module(g_edgerun_test_wasm, ER_TEST_WASM_SIZE, "test_return_123");

  er_println("PCI scan bus 0..255");
  er_reset_log_state();
  er_run_module(g_edgerun_pci_scan_wasm, ER_PCI_SCAN_WASM_SIZE, "pci_scan");

  er_println("Press any key to halt...");
  er_wait_for_key_then_halt(SystemTable);
  return EFI_SUCCESS;
}
