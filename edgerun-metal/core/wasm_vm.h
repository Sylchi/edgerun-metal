#ifndef WASM_VM_H
#define WASM_VM_H

#include "er_bus.h"
#include "er_driver_policy.h"
#include "er_types.h"
#include "er_ui_scene.h"
#include "er_wasm_contract.h"

#define ER_WASM_MAX_FUNCTIONS 16u
#define ER_WASM_MAX_TYPE_PARAMS 5u
#define ER_WASM_LINEAR_MEMORY_BASE 0u
#define ER_WASM_PUBLIC_REGION_RELAY_INBOX 1u
#define ER_WASM_PUBLIC_REGION_RELAY_OUTBOX 2u
#define ER_WASM_UI_COMMAND_ABI_VERSION 1u
#define ER_WASM_UI_COMMAND_LIST_HEADER_LEN 36u
#define ER_WASM_UI_RECT_RECORD_LEN 60u
#define ER_WASM_UI_HIT_RECORD_LEN 24u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_LEN 28u
#define ER_WASM_UI_DROP_TARGET_RECORD_LEN 24u
#define ER_WASM_UI_TRANSITION_RECORD_LEN 28u
#define ER_WASM_UI_QUAD_RECORD_LEN 52u

/*
 * Purpose: define the bounded WASM interpreter ABI used by metal apps and drivers.
 * Intention: expose memory and hostcalls explicitly, without depending on host libc or OS handles.
 */

typedef void (*er_wasm_log_u64)(INT64 value);
typedef void (*er_wasm_log_hex)(UINT64 value);
typedef INT64 (*er_wasm_pci_read32)(INT64 bus, INT64 device, INT64 func, INT64 offset);
typedef void (*er_wasm_pci_write32)(INT64 bus, INT64 device, INT64 func, INT64 offset, INT64 value);
typedef INT64 (*er_wasm_mmio_map)(INT64 phys, INT64 len);
typedef INT64 (*er_wasm_mmio_read32)(INT64 handle, INT64 offset);
typedef INT64 (*er_wasm_bus_exec)(const ErBusIoPacket* request, ErBusIoPacket* response);
typedef INT64 (*er_wasm_relay_send)(const UINT8* bytes, UINT32 len);
typedef INT64 (*er_wasm_relay_recv)(UINT8* bytes, UINT32 capacity);
typedef INT64 (*er_wasm_ui_emit)(void* user, const UINT8* bytes, UINT32 len,
                                 const er_ui_scene_stats_t* stats);

typedef struct {
  UINT8* bytes;
  UINT32 address_base;
  UINT32 address_len;
  UINT32 relay_inbox_base;
  UINT32 relay_inbox_len;
  UINT32 relay_outbox_base;
  UINT32 relay_outbox_len;
} ErWasmLinearMemory;

typedef struct {
  er_wasm_log_u64 log_u64;
  er_wasm_log_hex log_hex;
  er_wasm_pci_read32 pci_read32;
  er_wasm_pci_write32 pci_write32;
  er_wasm_mmio_map mmio_map;
  er_wasm_mmio_read32 mmio_read32;
  er_wasm_bus_exec bus_exec;
  er_wasm_relay_send relay_send;
  er_wasm_relay_recv relay_recv;
  er_wasm_ui_emit ui_emit;
  void* ui_emit_user;
  UINT8* memory;
  UINT32 memory_size;
  ErWasmLinearMemory linear_memory;
  const ErDriverAdmissionPolicy* driver_policy;
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
  UINT32 memory_min_pages;
  UINT32 memory_size;
  UINT8* memory;
  ErWasmLinearMemory linear_memory;
  UINT8 function_has_main;
  UINT32 main_index;
  UINT32 function_type_indices[ER_WASM_MAX_FUNCTIONS];
  UINT8  function_is_import[ER_WASM_MAX_FUNCTIONS];
  UINT8  function_import_kind[ER_WASM_MAX_FUNCTIONS];
  UINT8  type_params_0[ER_WASM_MAX_FUNCTIONS];
  UINT8  type_param_types[ER_WASM_MAX_FUNCTIONS][ER_WASM_MAX_TYPE_PARAMS];
  UINT8  type_result_count[ER_WASM_MAX_FUNCTIONS];
  UINT8  type_result_type[ER_WASM_MAX_FUNCTIONS];
  ErWasmCode code[ER_WASM_MAX_FUNCTIONS];
  ErWasmHostCalls host;
} ErWasmModule;

int er_wasm_prepare_linear_memory(UINT8* bytes, UINT32 address_len,
                                  UINT32 relay_inbox_base, UINT32 relay_inbox_len,
                                  UINT32 relay_outbox_base, UINT32 relay_outbox_len,
                                  ErWasmLinearMemory* out_memory);
int er_wasm_linear_memory_public_region(const ErWasmLinearMemory* memory, UINT32 region_id,
                                        UINT32* out_base, UINT32* out_len);
int er_wasm_ui_command_stats(const UINT8* bytes, UINT32 len, er_ui_scene_stats_t* out_stats);
int er_wasm_ui_command_decode(const UINT8* bytes, UINT32 len, er_ui_scene_t* scene,
                              er_ui_scene_stats_t* out_stats);
int er_wasm_init(ErWasmModule* module, const UINT8* data, UINT32 size, const ErWasmHostCalls* host);
int er_wasm_find_main(ErWasmModule* module, UINT32* main_index);
int er_wasm_validate_contract(const ErWasmModule* module, ErWasmModuleContract contract);
int er_wasm_execute_i64(ErWasmModule* module, UINT32 function_index, INT64* result);

#endif
