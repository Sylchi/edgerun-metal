#include "er_ui_wasm_app.h"
#include "er_mem.h"

static ErUiWasmAppRuntime* g_active_runtime;

static INT64 er_ui_wasm_app_emit_host(const UINT8* bytes, UINT32 len,
                                      const er_ui_scene_stats_t* stats) {
  if (bytes == 0 || stats == 0 || g_active_runtime == 0 ||
      g_active_runtime->scene == 0) {
    return -1;
  }
  if (er_wasm_ui_command_decode(bytes, len, g_active_runtime->scene,
                                &g_active_runtime->emitted_stats) != 0) {
    return -1;
  }
  g_active_runtime->emitted = 1u;
  return (INT64)(UINT64)len;
}

int er_ui_wasm_app_run(const UINT8* module_data, UINT32 module_size,
                       const ErWasmHostCalls* host_template,
                       ErUiWasmAppRuntime* runtime, INT64* out_result) {
  ErWasmHostCalls host;
  ErWasmLinearMemory linear_memory;
  ErWasmModule module;
  UINT32 main_index = 0u;
  INT64 result = 0;

  if (module_data == 0 || module_size == 0u || host_template == 0 ||
      runtime == 0 || runtime->memory == 0 || runtime->memory_size == 0u ||
      runtime->presentation == 0 || runtime->scene == 0 || out_result == 0 ||
      g_active_runtime != 0) {
    return -1;
  }
  er_mem_zero(runtime->memory, (UINTN)runtime->memory_size);
  er_mem_zero((UINT8*)&runtime->emitted_stats, (UINTN)sizeof(runtime->emitted_stats));
  runtime->emitted = 0u;
  if (er_wasm_prepare_linear_memory(runtime->memory, runtime->memory_size,
                                    runtime->relay_inbox_base,
                                    runtime->relay_inbox_len,
                                    runtime->relay_outbox_base,
                                    runtime->relay_outbox_len,
                                    &linear_memory) != 0) {
    return -1;
  }

  host = *host_template;
  host.linear_memory = linear_memory;
  host.memory = runtime->memory;
  host.memory_size = runtime->memory_size;
  host.ui_emit = er_ui_wasm_app_emit_host;
  host.ui_presentation = runtime->presentation;

  g_active_runtime = runtime;
  if (er_wasm_init(&module, module_data, module_size, &host) != 0 ||
      er_wasm_find_main(&module, &main_index) != 0 ||
      er_wasm_execute_i64(&module, main_index, &result) != 0 ||
      runtime->emitted == 0u) {
    g_active_runtime = 0;
    return -1;
  }
  g_active_runtime = 0;
  *out_result = result;
  return 0;
}
