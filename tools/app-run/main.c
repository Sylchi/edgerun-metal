#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "er_mem.h"
#include "wasm_vm.h"

/*
 * Purpose:
 *   Execute an admitted local app package Wasm module through the real metal VM.
 * Intention:
 *   Keep the first host-side app runner deterministic while package loading is
 *   moved into the shell runtime.
 */

enum {
  ERA_INPUT_ARGC = 2,
  ERA_WASM_ARG = 1,
  ERA_MEMORY_BYTES = 65536,
  ERA_RELAY_INBOX_BASE = 0,
  ERA_RELAY_INBOX_LEN = 1024,
  ERA_RELAY_OUTBOX_BASE = 1024,
  ERA_RELAY_OUTBOX_LEN = 2048
};

typedef struct {
  UINT32 emit_count;
  UINT32 last_len;
  er_ui_scene_stats_t last_stats;
} ErAppRunUiState;

static int era_usage(const char* program) {
  fprintf(stderr, "usage: %s <app.wasm>\n", program);
  return 2;
}

static int era_read_file(const char* path, UINT8** out_bytes, UINT32* out_len) {
  FILE* file;
  long size;
  UINT8* bytes;

  if (path == NULL || out_bytes == NULL || out_len == NULL) {
    return -1;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "app-run: open failed for %s\n", path);
    return -1;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    fprintf(stderr, "app-run: seek failed for %s\n", path);
    return -1;
  }
  size = ftell(file);
  if (size <= 0 || (unsigned long)size > UINT32_MAX) {
    fclose(file);
    fprintf(stderr, "app-run: invalid file size for %s\n", path);
    return -1;
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    fprintf(stderr, "app-run: seek failed for %s\n", path);
    return -1;
  }
  bytes = (UINT8*)malloc((size_t)size);
  if (bytes == NULL) {
    fclose(file);
    fprintf(stderr, "app-run: allocation failed\n");
    return -1;
  }
  if (fread(bytes, 1u, (size_t)size, file) != (size_t)size) {
    free(bytes);
    fclose(file);
    fprintf(stderr, "app-run: read failed for %s\n", path);
    return -1;
  }
  if (fclose(file) != 0) {
    free(bytes);
    fprintf(stderr, "app-run: close failed for %s\n", path);
    return -1;
  }
  *out_bytes = bytes;
  *out_len = (UINT32)size;
  return 0;
}

static INT64 era_ui_emit(void* user, const UINT8* bytes, UINT32 len,
                         const er_ui_scene_stats_t* stats) {
  ErAppRunUiState* state = (ErAppRunUiState*)user;

  if (state == NULL || bytes == NULL || stats == NULL) {
    return 0;
  }
  ++state->emit_count;
  state->last_len = len;
  state->last_stats = *stats;
  return (INT64)len;
}

int main(int argc, char** argv) {
  UINT8 memory[ERA_MEMORY_BYTES];
  UINT8* wasm_bytes = NULL;
  UINT32 wasm_len = 0u;
  ErWasmLinearMemory linear_memory;
  ErWasmHostCalls host = {0};
  ErWasmModule module;
  ErAppRunUiState ui_state = {0};
  UINT32 main_index = 0u;
  INT64 result = 0;
  int status = 1;

  if (argc != ERA_INPUT_ARGC) {
    return era_usage(argv[0]);
  }
  er_mem_zero(memory, (UINTN)sizeof(memory));
  if (era_read_file(argv[ERA_WASM_ARG], &wasm_bytes, &wasm_len) != 0 ||
      er_wasm_prepare_linear_memory(memory, (UINT32)sizeof(memory),
                                    ERA_RELAY_INBOX_BASE, ERA_RELAY_INBOX_LEN,
                                    ERA_RELAY_OUTBOX_BASE, ERA_RELAY_OUTBOX_LEN,
                                    &linear_memory) != 0) {
    free(wasm_bytes);
    return 1;
  }
  host.linear_memory = linear_memory;
  host.ui_emit = era_ui_emit;
  host.ui_emit_user = &ui_state;
  if (er_wasm_init(&module, wasm_bytes, wasm_len, &host) != 0) {
    fprintf(stderr, "app-run: wasm init failed\n");
  } else if (er_wasm_validate_contract(&module, ER_WASM_MODULE_CONTRACT_UI_APP) != 0) {
    fprintf(stderr, "app-run: contract validation failed\n");
  } else if (er_wasm_find_main(&module, &main_index) != 0) {
    fprintf(stderr, "app-run: main lookup failed\n");
  } else {
    if (er_wasm_execute_i64(&module, main_index, &result) != 0) {
      fprintf(stderr, "app-run: main execution failed\n");
    } else {
      printf("app-run result=%lld ui_emit_count=%u ui_emit_bytes=%u rects=%llu hits=%llu text=%llu\n",
             (long long)result,
             (unsigned)ui_state.emit_count,
             (unsigned)ui_state.last_len,
             (unsigned long long)ui_state.last_stats.rects,
             (unsigned long long)ui_state.last_stats.hits,
             (unsigned long long)ui_state.last_stats.text_quads);
      status = 0;
    }
  }
  free(wasm_bytes);
  return status;
}
