#ifndef WASM_VM_H
#define WASM_VM_H

#include "er_types.h"

typedef void (*er_wasm_log_u64)(INT64 value);
typedef void (*er_wasm_log_hex)(UINT64 value);
typedef INT64 (*er_wasm_pci_read32)(INT64 bus, INT64 device, INT64 func, INT64 offset);
typedef void (*er_wasm_pci_write32)(INT64 bus, INT64 device, INT64 func, INT64 offset, INT64 value);

typedef struct {
  er_wasm_log_u64 log_u64;
  er_wasm_log_hex log_hex;
  er_wasm_pci_read32 pci_read32;
  er_wasm_pci_write32 pci_write32;
} ErWasmHostCalls;

typedef struct {
  const UINT8* body;
  UINT32 size;
  UINT8 local_count;
} ErWasmCode;

typedef struct {
  UINT32 num_types;
  UINT32 num_imports;
  UINT32 num_funcs;
  UINT32 num_exports;
  UINT8 function_has_main;
  UINT32 main_index;
  UINT32 function_type_indices[16];
  UINT8  function_is_import[16];
  UINT8  function_import_kind[16];
  UINT8  type_params_0[16];
  UINT8  type_result_count[16];
  UINT8  type_result_type[16];
  ErWasmCode code[16];
  ErWasmHostCalls host;
} ErWasmModule;

int er_wasm_init(ErWasmModule* module, const UINT8* data, UINT32 size, const ErWasmHostCalls* host);
int er_wasm_find_main(ErWasmModule* module, UINT32* main_index);
int er_wasm_execute_i64(ErWasmModule* module, UINT32 function_index, INT64* result);

#endif
