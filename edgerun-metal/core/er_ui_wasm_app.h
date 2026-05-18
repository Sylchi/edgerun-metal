#ifndef ER_UI_WASM_APP_H
#define ER_UI_WASM_APP_H

#include "er_app.h"
#include "er_epoch_clock.h"
#include "er_ui_runtime.h"
#include "wasm_vm.h"

/*
 * Purpose: run admitted freestanding WASM UI apps into EdgeRun UI scenes.
 * Intention: keep boot profiles from owning the ui_emit hostcall bridge and scene decode plumbing.
 */

#define ER_UI_WASM_INPUT_ABI_VERSION 1u
#define ER_UI_WASM_INPUT_PACKET_LEN 24u
#define ER_UI_WASM_INPUT_ABI_OFFSET 0u
#define ER_UI_WASM_INPUT_KIND_OFFSET 4u
#define ER_UI_WASM_INPUT_KEY_KIND_OFFSET 8u
#define ER_UI_WASM_INPUT_KEY_CODEPOINT_OFFSET 12u
#define ER_UI_WASM_INPUT_MODIFIERS_OFFSET 16u
#define ER_UI_WASM_INPUT_SEQUENCE_OFFSET 20u
#define ER_UI_WASM_INPUT_MODIFIER_SHIFT 0x01u
#define ER_UI_WASM_INPUT_MODIFIER_CTRL 0x02u
#define ER_UI_WASM_INPUT_MODIFIER_ALT 0x04u
#define ER_UI_WASM_INPUT_MODIFIER_META 0x08u
#define ER_UI_WASM_INPUT_SEQUENCE_MAX 0xffffffffu

typedef enum {
  ER_UI_WASM_INPUT_KIND_KEY = 1u
} ErUiWasmInputKind;

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
  ErEpochClock settlement_clock;
  ErEpochClockModifier input_epoch_modifier;
  ErEpochClockModifier execute_epoch_modifier;
  ErEpochStamp last_input_epoch;
  ErEpochStamp last_execute_epoch;
  UINT32 input_len;
  UINT32 input_sequence;
  er_ui_scene_stats_t emitted_stats;
  UINT8 emitted;
  UINT8 prepared;
} ErUiWasmAppRuntime;

int er_ui_wasm_app_prepare(const UINT8* module_data, UINT32 module_size,
                           const ErWasmHostCalls* host_template,
                           ErUiWasmAppRuntime* runtime);
int er_ui_wasm_app_deliver_input(ErUiWasmAppRuntime* runtime, const UINT8* bytes,
                                 UINT32 len);
int er_ui_wasm_app_deliver_key_input(ErUiWasmAppRuntime* runtime, er_ui_key_t key,
                                     er_ui_key_modifiers_t modifiers);
int er_ui_wasm_app_execute(ErUiWasmAppRuntime* runtime, INT64* out_result);
int er_ui_wasm_app_run(const UINT8* module_data, UINT32 module_size,
                       const ErWasmHostCalls* host_template,
                       ErUiWasmAppRuntime* runtime, INT64* out_result);

#endif
