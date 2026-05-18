#include "er_ui_wasm_app.h"
#include "er_mem.h"

static ErUiWasmAppRuntime* g_active_runtime;

static int er_ui_wasm_app_memory_window(const ErUiWasmAppRuntime* runtime, UINT32 base,
                                        UINT32 len, UINT8** out_bytes) {
  UINT64 end;

  if (runtime == 0 || runtime->memory == 0 || out_bytes == 0 || len == 0u) {
    return -1;
  }
  end = (UINT64)base + (UINT64)len;
  if (end > (UINT64)runtime->memory_size) {
    return -1;
  }
  *out_bytes = runtime->memory + base;
  return 0;
}

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

int er_ui_wasm_app_prepare(const UINT8* module_data, UINT32 module_size,
                           const ErWasmHostCalls* host_template,
                           ErUiWasmAppRuntime* runtime) {
  ErWasmHostCalls host;
  ErWasmLinearMemory linear_memory;

  if (module_data == 0 || module_size == 0u || host_template == 0 ||
      runtime == 0 || runtime->memory == 0 || runtime->memory_size == 0u ||
      runtime->presentation == 0 || runtime->scene == 0 ||
      g_active_runtime != 0 || runtime->prepared != 0u) {
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

  if (er_wasm_init(&runtime->module, module_data, module_size, &host) != 0 ||
      er_wasm_find_main(&runtime->module, &runtime->main_index) != 0) {
    return -1;
  }
  runtime->prepared = 1u;
  return 0;
}

int er_ui_wasm_app_deliver_input(ErUiWasmAppRuntime* runtime, const UINT8* bytes,
                                 UINT32 len) {
  UINT8* inbox = 0;

  if (runtime == 0 || bytes == 0 || len == 0u || runtime->prepared == 0u ||
      len > runtime->relay_inbox_len ||
      er_ui_wasm_app_memory_window(runtime, runtime->relay_inbox_base,
                                   runtime->relay_inbox_len, &inbox) != 0) {
    return -1;
  }
  er_mem_zero(inbox, (UINTN)runtime->relay_inbox_len);
  er_mem_copy(inbox, bytes, (UINTN)len);
  return 0;
}

int er_ui_wasm_app_execute(ErUiWasmAppRuntime* runtime, INT64* out_result) {
  INT64 result = 0;

  if (runtime == 0 || out_result == 0 || runtime->prepared == 0u ||
      runtime->scene == 0 || g_active_runtime != 0) {
    return -1;
  }
  er_mem_zero((UINT8*)&runtime->emitted_stats, (UINTN)sizeof(runtime->emitted_stats));
  runtime->emitted = 0u;
  g_active_runtime = runtime;
  if (er_wasm_execute_i64(&runtime->module, runtime->main_index, &result) != 0 ||
      runtime->emitted == 0u) {
    g_active_runtime = 0;
    return -1;
  }
  g_active_runtime = 0;
  *out_result = result;
  return 0;
}

int er_ui_wasm_app_run(const UINT8* module_data, UINT32 module_size,
                       const ErWasmHostCalls* host_template,
                       ErUiWasmAppRuntime* runtime, INT64* out_result) {
  if (er_ui_wasm_app_prepare(module_data, module_size, host_template, runtime) != 0) {
    return -1;
  }
  return er_ui_wasm_app_execute(runtime, out_result);
}
