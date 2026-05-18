#ifndef ER_UI_WASM_APP_H
#define ER_UI_WASM_APP_H

#include "er_app.h"
#include "wasm_vm.h"

/*
 * Purpose: run admitted freestanding WASM UI apps into EdgeRun UI scenes.
 * Intention: keep boot profiles from owning the ui_emit hostcall bridge and scene decode plumbing.
 */

typedef struct {
  UINT8* memory;
  UINT32 memory_size;
  UINT32 relay_inbox_base;
  UINT32 relay_inbox_len;
  UINT32 relay_outbox_base;
  UINT32 relay_outbox_len;
  const ErAppUiPresentation* presentation;
  er_ui_scene_t* scene;
  ErWasmModule module;
  UINT32 main_index;
  er_ui_scene_stats_t emitted_stats;
  UINT8 emitted;
  UINT8 prepared;
} ErUiWasmAppRuntime;

int er_ui_wasm_app_prepare(const UINT8* module_data, UINT32 module_size,
                           const ErWasmHostCalls* host_template,
                           ErUiWasmAppRuntime* runtime);
int er_ui_wasm_app_execute(ErUiWasmAppRuntime* runtime, INT64* out_result);
int er_ui_wasm_app_run(const UINT8* module_data, UINT32 module_size,
                       const ErWasmHostCalls* host_template,
                       ErUiWasmAppRuntime* runtime, INT64* out_result);

#endif
