#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "app_scaffold.h"
#include "package_identity.h"
#include "../repo-inspect/repo_inspect.h"

/*
 * Purpose:
 *   Provide a repository-owned build runner for deterministic local build,
 *   test, and policy targets.
 * Intention:
 *   Move project management out of Make/CMake/shell orchestration while the
 *   repository still uses the host C compiler as the bootstrap compiler.
 */

enum {
  ERB_MAX_ARGC = 96,
  ERB_EXEC_FAILURE_STATUS = 127,
  ERB_OUTPUT_DIR_MODE = 0777,
  ERB_PATH_CAP = 4096,
  ERB_MANIFEST_CAP = 512,
  ERB_MANIFEST_LINE_CAP = 128,
  ERB_PROGRESS_TITLE_CAP = 256,
  ERB_SWARM_DEFAULT_LIMIT = 50,
  ERB_SWARM_MAX_LIMIT = 50,
  ERB_SWARM_CONTEXT_BEFORE = 10,
  ERB_SWARM_CONTEXT_AFTER = 20,
  ERB_SWARM_LINE_CAP = 2048,
  ERB_SWARM_PROMPT_CAP = 32768,
  ERB_SWARM_PATH_CAP = 512,
  ERB_SWARM_FILE_TASK_MAX = 512,
  ERB_SWARM_MAX_ISSUES_PER_FILE = 8,
  ERB_SWARM_AGENT_ARGC = 12,
  ERB_DECIMAL_RADIX = 10,
  ERB_ARGC_TARGET_ONLY = 1,
  ERB_ARGC_ONE_VALUE = 2,
  ERB_ARGC_TWO_VALUES = 3,
  ERB_TEXT_INITIAL_CAP = 8192,
  ERB_PIPE_READ_CHUNK = 4096,
  ERB_SWARM_STREAM_CHUNK = 4096,
  ERB_SELECT_TIMEOUT_USEC = 200000,
  ERB_PACKAGE_CONTRACT_UI_APP = 1,
  ERB_PACKAGE_CONTRACT_BUS_DRIVER = 2,
  ERB_MANIFEST_UI_LINE_COUNT = 5,
  ERB_MANIFEST_BUS_LINE_COUNT = 7,
  ERB_ZERRORS_PREFIX_LEN = 8,
  ERB_ZSYSCALL_PREFIX_LEN = 9,
  ERB_ZSYSNUM_PREFIX_LEN = 8,
  ERB_ZTYPES_PREFIX_LEN = 7
};

typedef enum {
  ERB_SWARM_FIX_SKIP = 0,
  ERB_SWARM_FIX_CONSTANT,
  ERB_SWARM_FIX_DUPLICATE,
  ERB_SWARM_FIX_BOUNDS,
  ERB_SWARM_FIX_LOCAL_REFACTOR
} ErbSwarmFixKind;

static const char ERB_DEFAULT_CC[] = "toolchain/bin/clang";
static const char ERB_BUILD_DIR[] = ".build";
static const char ERB_INTERNAL_BUILD_DIR[] = ".build/er-build-out";
static const char ERB_CRYPTO_BUILD_DIR[] = ".build/er-build-out/crypto";
static const char ERB_OBJECT_BUILD_DIR[] = ".build/er-build-out/object";
static const char ERB_STORAGE_BUILD_DIR[] = ".build/er-build-out/storage";
static const char ERB_VARFONT_BUILD_DIR[] = ".build/er-build-out/varfont";
static const char ERB_UI_CORE_BUILD_DIR[] = ".build/er-build-out/ui-core";
static const char ERB_CODEX_BIN[] = ".build/codex";
static const char ERB_REPO_CHECK_BIN[] = ".build/repo-check";
static const char ERB_ERWIRE_DECODE_BIN[] = ".build/erwire-decode";
static const char ERB_WASM_COMPILE_BIN[] = ".build/wasm-compile";
static const char ERB_APP_RUN_BIN[] = ".build/app-run";
static const char ERB_PI_SERIAL_VERIFY_BIN[] = ".build/pi-serial-verify";
static const char ERB_PI_NODE_UPDATE_BIN[] = ".build/pi-node-update";
static const char ERB_SDCARD_PROBE_BIN[] = ".build/sdcard-probe";
static const char ERB_DISK_ANALYZER_BIN[] = ".build/disk-analyzer";
static const char ERB_PI_USB_BOOT_BIN[] = ".build/pi-usb-boot";
static const char ERB_CRYPTO_BLAKE3_TEST_BIN[] = ".build/er-build-out/crypto/test_blake3";
static const char ERB_CRYPTO_BLAKE3_BENCH_BIN[] = ".build/er-build-out/crypto/bench_blake3";
static const char ERB_OBJECT_TEST_BIN[] = ".build/er-build-out/object/test_object";
static const char ERB_STORAGE_STORE_TEST_BIN[] = ".build/er-build-out/storage/test_store";
static const char ERB_STORAGE_STORE_BENCH_BIN[] = ".build/er-build-out/storage/bench_store";
static const char ERB_VARFONT_TEST_BIN[] = ".build/er-build-out/varfont/vrfont_tests";
static const char ERB_UI_CORE_TEST_BIN[] = ".build/er-build-out/ui-core/er_ui_core_tests";
static const char ERB_APP_ERC_SOURCE_NAME[] = "app.erc";
static const char ERB_APP_MANIFEST_NAME[] = "app.manifest";
static const char ERB_APP_BUILD_DIR_NAME[] = ".build";
static const char ERB_APP_WASM_NAME[] = "app.wasm";
static const char ERB_APP_PACKAGE_IDENTITY_NAME[] = "package.identity";
static const char ERB_MANIFEST_CONTRACT_UI_APP[] = "contract=ui-app";
static const char ERB_MANIFEST_CONTRACT_BUS_DRIVER[] = "contract=bus-driver";
static const char ERB_MANIFEST_UI_MEMORY[] = "memory_pages=1";
static const char ERB_MANIFEST_UI_IMPORTS[] = "imports=edgerun.ui/emit";
static const char ERB_MANIFEST_BUS_IMPORTS[] = "imports=edgerun.bus/exec";
static const char ERB_MANIFEST_DRIVER_MEMORY[] = "driver_memory_bytes=65536";
static const char ERB_MANIFEST_DRIVER_BUS[] = "driver_bus=mmio32:4096:4:read8";
static const char ERB_MANIFEST_OUTPUT_WASM[] = "output=.build/app.wasm";
static const char ERB_MANIFEST_SOURCE_PREFIX[] = "source=";

typedef struct {
  const char* items[ERB_MAX_ARGC];
  size_t count;
} ErbArgs;

typedef struct {
  char app_source[ERB_PATH_CAP];
  char manifest_source[ERB_PATH_CAP];
  char package_build_dir[ERB_PATH_CAP];
  char output_wasm[ERB_PATH_CAP];
  char output_identity[ERB_PATH_CAP];
} ErbAppPackagePaths;

typedef struct {
  char path[ERB_SWARM_PATH_CAP];
  int line;
  char text[ERB_SWARM_LINE_CAP];
  char kind[64];
  ErbSwarmFixKind fix_kind;
} ErbSwarmIssue;

typedef struct {
  char* data;
  size_t len;
  size_t cap;
} ErbTextBuffer;

typedef struct {
  char path[ERB_SWARM_PATH_CAP];
  ErbTextBuffer issues;
  ErbSwarmFixKind fix_kind;
  size_t issue_count;
} ErbSwarmFileTask;

typedef struct {
  pid_t pid;
  int fd;
  size_t index;
  uint8_t active;
  uint8_t line_start;
} ErbSwarmWorker;

static int erb_usage(void);

static int erb_fail(const char* message) {
  fprintf(stderr, "er-build: %s\n", message);
  return 1;
}

static const char* erb_host_cc(void) {
  return ERB_DEFAULT_CC;
}

static void erb_args_init(ErbArgs* args) {
  args->count = 0u;
}

static int erb_args_push(ErbArgs* args, const char* item) {
  if (args->count + 1u >= ERB_MAX_ARGC) {
    return erb_fail("too many command arguments");
  }
  args->items[args->count] = item;
  ++args->count;
  args->items[args->count] = NULL;
  return 0;
}

static void erb_print_command(const ErbArgs* args) {
  size_t i;

  printf("+");
  for (i = 0u; i < args->count; ++i) {
    printf(" %s", args->items[i]);
  }
  printf("\n");
}

static int erb_run_args(const ErbArgs* args, int print_plan) {
  pid_t pid;
  int status;

  if (args->count == 0u) {
    return erb_fail("empty command");
  }
  if (print_plan != 0) {
    erb_print_command(args);
    return 0;
  }
  pid = fork();
  if (pid < 0) {
    return erb_fail("fork failed");
  }
  if (pid == 0) {
    execvp(args->items[0], (char* const*)args->items);
    fprintf(stderr, "er-build: exec failed for %s: %s\n", args->items[0], strerror(errno));
    _exit(ERB_EXEC_FAILURE_STATUS);
  }
  if (waitpid(pid, &status, 0) < 0) {
    return erb_fail("waitpid failed");
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    fprintf(stderr, "er-build: command failed:");
    erb_print_command(args);
    return 1;
  }
  return 0;
}

static int erb_mkdir_one(const char* path) {
  if (mkdir(path, ERB_OUTPUT_DIR_MODE) == 0 || errno == EEXIST) {
    return 0;
  }
  fprintf(stderr, "er-build: mkdir failed for %s: %s\n", path, strerror(errno));
  return 1;
}

static int erb_path_join(char* out, size_t out_len, const char* left, const char* right) {
  int written;

  if (out == NULL || left == NULL || right == NULL || out_len == 0u ||
      left[0] == '\0' || right[0] == '\0') {
    return erb_fail("invalid path");
  }
  written = snprintf(out, out_len, "%s/%s", left, right);
  if (written < 0 || (size_t)written >= out_len) {
    return erb_fail("path too long");
  }
  return 0;
}

static int erb_require_regular_file(const char* path) {
  struct stat st;

  if (path == NULL || stat(path, &st) != 0) {
    fprintf(stderr, "er-build: missing required file %s\n", path == NULL ? "(null)" : path);
    return 1;
  }
  if (!S_ISREG(st.st_mode) || st.st_size <= 0) {
    fprintf(stderr, "er-build: invalid required file %s\n", path);
    return 1;
  }
  return 0;
}

static int erb_read_text_file(const char* path, char* out, size_t out_len) {
  FILE* file;
  size_t len;

  if (path == NULL || out == NULL || out_len == 0u) {
    return erb_fail("invalid file read");
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "er-build: open failed for %s: %s\n", path, strerror(errno));
    return 1;
  }
  len = fread(out, 1u, out_len - 1u, file);
  if (ferror(file) != 0) {
    fclose(file);
    fprintf(stderr, "er-build: read failed for %s\n", path);
    return 1;
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "er-build: close failed for %s: %s\n", path, strerror(errno));
    return 1;
  }
  out[len] = '\0';
  if (len == out_len - 1u) {
    fprintf(stderr, "er-build: file too large %s\n", path);
    return 1;
  }
  return 0;
}

static int erb_write_text_new_file(const char* dest_path, const char* text) {
  FILE* dest;
  size_t len;

  if (dest_path == NULL || text == NULL) {
    return erb_fail("invalid file write");
  }
  dest = fopen(dest_path, "wbx");
  if (dest == NULL) {
    fprintf(stderr, "er-build: create failed for %s: %s\n", dest_path, strerror(errno));
    return 1;
  }
  len = strlen(text);
  if (fwrite(text, 1u, len, dest) != len) {
    fprintf(stderr, "er-build: write failed for %s\n", dest_path);
    fclose(dest);
    return 1;
  }
  if (fclose(dest) != 0) {
    fprintf(stderr, "er-build: close failed for %s: %s\n", dest_path, strerror(errno));
    return 1;
  }
  return 0;
}

static void erb_text_buffer_free(ErbTextBuffer* buffer) {
  if (buffer != NULL) {
    free(buffer->data);
    buffer->data = NULL;
    buffer->len = 0u;
    buffer->cap = 0u;
  }
}

static int erb_text_buffer_reserve(ErbTextBuffer* buffer, size_t needed) {
  size_t next;
  char* grown;

  if (buffer == NULL) {
    return erb_fail("invalid text buffer");
  }
  if (needed <= buffer->cap) {
    return 0;
  }
  next = buffer->cap == 0u ? ERB_TEXT_INITIAL_CAP : buffer->cap;
  while (next < needed) {
    next *= 2u;
  }
  grown = (char*)realloc(buffer->data, next);
  if (grown == NULL) {
    return erb_fail("text buffer allocation failed");
  }
  buffer->data = grown;
  buffer->cap = next;
  return 0;
}

static int erb_text_buffer_append(ErbTextBuffer* buffer, const char* text, size_t len) {
  if (text == NULL) {
    return erb_fail("invalid text append");
  }
  if (erb_text_buffer_reserve(buffer, buffer->len + len + 1u) != 0) {
    return 1;
  }
  if (len > 0u) {
    memcpy(buffer->data + buffer->len, text, len);
    buffer->len += len;
  }
  buffer->data[buffer->len] = '\0';
  return 0;
}

static int erb_copy_source_name(char* out_source_name,
                                size_t out_source_name_len,
                                const char* source_name) {
  size_t source_name_len;

  if (out_source_name == NULL || source_name == NULL || out_source_name_len == 0u) {
    return erb_fail("invalid app source name output");
  }
  source_name_len = strlen(source_name);
  if (source_name_len + 1u > out_source_name_len) {
    return erb_fail("app source name too long");
  }
  memcpy(out_source_name, source_name, source_name_len + 1u);
  return 0;
}

static int erb_manifest_next_line(const char** cursor,
                                  char* out_line,
                                  size_t out_line_len,
                                  int* out_has_line) {
  const char* start;
  const char* end;
  size_t len;

  if (cursor == NULL || *cursor == NULL || out_line == NULL ||
      out_line_len == 0u || out_has_line == NULL) {
    return erb_fail("invalid manifest cursor");
  }
  *out_has_line = 0;
  if ((*cursor)[0] == '\0') {
    return 0;
  }
  start = *cursor;
  end = start;
  while (*end != '\0' && *end != '\n') {
    if (*end == '\r') {
      return erb_fail("manifest contains carriage return");
    }
    ++end;
  }
  len = (size_t)(end - start);
  if (len == 0u) {
    return erb_fail("manifest contains empty line");
  }
  if (len + 1u > out_line_len) {
    return erb_fail("manifest line too long");
  }
  memcpy(out_line, start, len);
  out_line[len] = '\0';
  *cursor = *end == '\n' ? end + 1 : end;
  *out_has_line = 1;
  return 0;
}

static int erb_manifest_line_equals(const char* line, const char* expected) {
  if (line == NULL || expected == NULL || strcmp(line, expected) != 0) {
    return erb_fail("invalid app manifest field");
  }
  return 0;
}

static int erb_manifest_parse_source(const char* line,
                                     char* out_source_name,
                                     size_t out_source_name_len) {
  const char* source_name;
  size_t prefix_len;

  if (line == NULL) {
    return erb_fail("invalid manifest source field");
  }
  prefix_len = strlen(ERB_MANIFEST_SOURCE_PREFIX);
  if (strncmp(line, ERB_MANIFEST_SOURCE_PREFIX, prefix_len) != 0) {
    return erb_fail("invalid app manifest source field");
  }
  source_name = line + prefix_len;
  if (strcmp(source_name, ERB_APP_ERC_SOURCE_NAME) == 0) {
    return erb_copy_source_name(out_source_name, out_source_name_len, source_name);
  }
  return erb_fail("unsupported app manifest source");
}

static int erb_validate_app_manifest(const char* path,
                                     int* out_contract,
                                     char* out_source_name,
                                     size_t out_source_name_len) {
  char text[ERB_MANIFEST_CAP];
  char line[ERB_MANIFEST_LINE_CAP];
  const char* cursor;
  size_t line_index = 0u;
  int has_line = 0;

  if (out_contract == NULL || out_source_name == NULL || out_source_name_len == 0u) {
    return erb_fail("invalid manifest contract output");
  }
  *out_contract = 0;
  out_source_name[0] = '\0';
  if (erb_read_text_file(path, text, sizeof(text)) != 0) {
    return 1;
  }
  cursor = text;
  while (1) {
    if (erb_manifest_next_line(&cursor, line, sizeof(line), &has_line) != 0) {
      fprintf(stderr, "er-build: invalid app manifest %s\n", path);
      return 1;
    }
    if (has_line == 0) {
      break;
    }
    switch (line_index) {
      case 0:
        if (strcmp(line, ERB_MANIFEST_CONTRACT_UI_APP) == 0) {
          *out_contract = ERB_PACKAGE_CONTRACT_UI_APP;
        } else if (strcmp(line, ERB_MANIFEST_CONTRACT_BUS_DRIVER) == 0) {
          *out_contract = ERB_PACKAGE_CONTRACT_BUS_DRIVER;
        } else {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      case 1:
        if (erb_manifest_line_equals(line, ERB_MANIFEST_UI_MEMORY) != 0) {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      case 2:
        if ((*out_contract == ERB_PACKAGE_CONTRACT_UI_APP &&
             erb_manifest_line_equals(line, ERB_MANIFEST_UI_IMPORTS) != 0) ||
            (*out_contract == ERB_PACKAGE_CONTRACT_BUS_DRIVER &&
             erb_manifest_line_equals(line, ERB_MANIFEST_BUS_IMPORTS) != 0)) {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      case 3:
        if (*out_contract == ERB_PACKAGE_CONTRACT_UI_APP) {
          if (erb_manifest_parse_source(line, out_source_name,
                                        out_source_name_len) != 0) {
            fprintf(stderr, "er-build: invalid app manifest %s\n", path);
            return 1;
          }
        } else if (erb_manifest_line_equals(line, ERB_MANIFEST_DRIVER_MEMORY) != 0) {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      case 4:
        if (*out_contract == ERB_PACKAGE_CONTRACT_UI_APP) {
          if (erb_manifest_line_equals(line, ERB_MANIFEST_OUTPUT_WASM) != 0) {
            fprintf(stderr, "er-build: invalid app manifest %s\n", path);
            return 1;
          }
        } else if (erb_manifest_line_equals(line, ERB_MANIFEST_DRIVER_BUS) != 0) {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      case 5:
        if (*out_contract != ERB_PACKAGE_CONTRACT_BUS_DRIVER ||
            erb_manifest_parse_source(line, out_source_name,
                                      out_source_name_len) != 0) {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      case 6:
        if (*out_contract != ERB_PACKAGE_CONTRACT_BUS_DRIVER ||
            erb_manifest_line_equals(line, ERB_MANIFEST_OUTPUT_WASM) != 0) {
          fprintf(stderr, "er-build: invalid app manifest %s\n", path);
          return 1;
        }
        break;
      default:
        fprintf(stderr, "er-build: invalid app manifest %s\n", path);
        return 1;
    }
    ++line_index;
  }
  if ((*out_contract == ERB_PACKAGE_CONTRACT_UI_APP &&
       line_index == ERB_MANIFEST_UI_LINE_COUNT) ||
      (*out_contract == ERB_PACKAGE_CONTRACT_BUS_DRIVER &&
       line_index == ERB_MANIFEST_BUS_LINE_COUNT)) {
    return 0;
  }
  fprintf(stderr, "er-build: invalid app manifest %s\n", path);
  return 1;
}

static int erb_init_app_package_paths(ErbAppPackagePaths* paths,
                                      const char* package_dir) {
  if (paths == NULL || package_dir == NULL || package_dir[0] == '\0') {
    return erb_fail("invalid app package path input");
  }
  memset(paths, 0, sizeof(*paths));
  if (erb_path_join(paths->manifest_source, sizeof(paths->manifest_source), package_dir,
                    ERB_APP_MANIFEST_NAME) != 0 ||
      erb_path_join(paths->package_build_dir, sizeof(paths->package_build_dir), package_dir,
                    ERB_APP_BUILD_DIR_NAME) != 0 ||
      erb_path_join(paths->output_wasm, sizeof(paths->output_wasm), paths->package_build_dir,
                    ERB_APP_WASM_NAME) != 0 ||
      erb_path_join(paths->output_identity, sizeof(paths->output_identity),
                    paths->package_build_dir, ERB_APP_PACKAGE_IDENTITY_NAME) != 0) {
    return 1;
  }
  return 0;
}

static int erb_prepare_dirs(void) {
  if (erb_mkdir_one(ERB_BUILD_DIR) != 0) {
    return 1;
  }
  if (erb_mkdir_one(ERB_INTERNAL_BUILD_DIR) != 0) {
    return 1;
  }
  if (erb_mkdir_one(ERB_CRYPTO_BUILD_DIR) != 0) {
    return 1;
  }
  if (erb_mkdir_one(ERB_STORAGE_BUILD_DIR) != 0) {
    return 1;
  }
  if (erb_mkdir_one(ERB_VARFONT_BUILD_DIR) != 0) {
    return 1;
  }
  return erb_mkdir_one(ERB_UI_CORE_BUILD_DIR);
}

static int erb_compile_common(ErbArgs* args, const char* output) {
  const char* cc = erb_host_cc();

  erb_args_init(args);
  if (erb_args_push(args, cc) != 0 ||
      erb_args_push(args, "-std=c11") != 0 ||
      erb_args_push(args, "-Wall") != 0 ||
      erb_args_push(args, "-Wextra") != 0 ||
      erb_args_push(args, "-Werror") != 0 ||
      erb_args_push(args, "-O2") != 0 ||
      erb_args_push(args, "-o") != 0 ||
      erb_args_push(args, output) != 0) {
    return 1;
  }
  return 0;
}

static int erb_args_push_varfont_sources(ErbArgs* args) {
  if (erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_freestanding.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_utils.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_axes.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_cmap.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_gvar.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_gvar_apply.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_kern.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_tables.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_shape.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_raster.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_raster_geometry.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_raster_glyph.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_raster_msdf.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_raster_outline.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_raster_storage.c") != 0 ||
      erb_args_push(args, "edgerun-ui-core/varfont/src/vr_font_atlas.c") != 0) {
    return 1;
  }
  return 0;
}

static int erb_build_repo_check(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_REPO_CHECK_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "tools/repo-check.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_erwire_decode(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_ERWIRE_DECODE_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "tools/erwire-decode.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_wasm_compile(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_WASM_COMPILE_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "tools/wasm-compile/main.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_c.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_common.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_contract.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_emit.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_io.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_module.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_parse.c") != 0 ||
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_source.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_pi_serial_verify(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 ||
      erb_compile_common(&args, ERB_PI_SERIAL_VERIFY_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "tools/pi-serial-verify/main.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_pi_node_update(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 ||
      erb_compile_common(&args, ERB_PI_NODE_UPDATE_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "-Iedgerun-metal/core") != 0 ||
      erb_args_push(&args, "-Iedgerun-metal/devices/pi_zero_w_v1_1") != 0 ||
      erb_args_push(&args, "-Iedgerun-crypto/include") != 0 ||
      erb_args_push(&args, "tools/pi-node-update/main.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/devices/pi_zero_w_v1_1/er_pi_zero_w_v1_1_ota.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_mem.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_vfs.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_crypto.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_crypto_blake3.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_identity.c") != 0 ||
      erb_args_push(&args, "edgerun-crypto/src/er_blake3.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_sdcard_probe(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 ||
      erb_compile_common(&args, ERB_SDCARD_PROBE_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "tools/sdcard-probe/main.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_disk_analyzer(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 ||
      erb_compile_common(&args, ERB_DISK_ANALYZER_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "-Iedgerun-metal/core") != 0 ||
      erb_args_push(&args, "tools/disk-analyzer/main.c") != 0 ||
      erb_args_push(&args, "tools/disk-analyzer/disk_analyzer.c") != 0 ||
      erb_args_push(&args, "tools/disk-analyzer/duplicates.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_disk_analyzer.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_mem.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_pi_usb_boot(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 ||
      erb_compile_common(&args, ERB_PI_USB_BOOT_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "tools/pi-usb-boot/main.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_app_run(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_APP_RUN_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-ffunction-sections") != 0 ||
      erb_args_push(&args, "-fdata-sections") != 0 ||
      erb_args_push(&args, "-Iedgerun-metal/core") != 0 ||
      erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/include") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/varfont/include") != 0 ||
      erb_args_push(&args, "tools/app-run/main.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_mem.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_pci.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_mmio.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_bus.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_driver_policy.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_node_id.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_app.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/er_relay_packet.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/wasm_vm.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/wasm_vm_reader.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/wasm_vm_memory_ui.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/wasm_vm_contract.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/wasm_vm_hostcall.c") != 0 ||
      erb_args_push(&args, "edgerun-metal/core/wasm_vm_execute.c") != 0 ||
      erb_args_push(&args, "-Wl,--gc-sections") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_load_app_package(const char* package_dir,
                                const char* target_name,
                                ErbAppPackagePaths* paths) {
  int package_contract = 0;
  char source_name[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0') {
    fprintf(stderr, "er-build: %s requires a package directory\n", target_name);
    return 1;
  }
  if (paths == NULL || erb_init_app_package_paths(paths, package_dir) != 0) {
    return 1;
  }
  if (erb_require_regular_file(paths->manifest_source) != 0 ||
      erb_validate_app_manifest(paths->manifest_source, &package_contract,
                                source_name, sizeof(source_name)) != 0 ||
      erb_path_join(paths->app_source, sizeof(paths->app_source), package_dir,
                    source_name) != 0 ||
      erb_require_regular_file(paths->app_source) != 0) {
    return 1;
  }
  (void)package_contract;
  return 0;
}

static int erb_target_app_build(const char* package_dir, int print_plan) {
  ErbArgs args;
  ErbAppPackagePaths paths;

  if (erb_load_app_package(package_dir, "app-build", &paths) != 0 ||
      erb_build_wasm_compile(print_plan) != 0) {
    return 1;
  }
  if (print_plan == 0 && erb_mkdir_one(paths.package_build_dir) != 0) {
    return 1;
  }
  erb_args_init(&args);
  if (erb_args_push(&args, ERB_WASM_COMPILE_BIN) != 0 ||
      erb_args_push(&args, paths.app_source) != 0 ||
      erb_args_push(&args, paths.output_wasm) != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  if (print_plan != 0) {
    return 0;
  }
  return erb_write_app_package_identity(paths.output_identity, paths.app_source,
                                        paths.manifest_source, paths.output_wasm);
}

static int erb_target_app_verify(const char* package_dir) {
  ErbAppPackagePaths paths;

  if (erb_load_app_package(package_dir, "app-verify", &paths) != 0 ||
      erb_require_regular_file(paths.output_wasm) != 0 ||
      erb_require_regular_file(paths.output_identity) != 0) {
    return 1;
  }
  return erb_verify_app_package_identity(paths.output_identity, paths.app_source,
                                         paths.manifest_source, paths.output_wasm);
}

static int erb_target_app_run(const char* package_dir, int print_plan) {
  ErbArgs args;
  char manifest_source[ERB_PATH_CAP];
  char package_build_dir[ERB_PATH_CAP];
  char output_wasm[ERB_PATH_CAP];
  int package_contract = 0;
  char source_name[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0') {
    return erb_fail("app-run requires a package directory");
  }
  if (erb_path_join(manifest_source, sizeof(manifest_source), package_dir,
                    ERB_APP_MANIFEST_NAME) != 0 ||
      erb_path_join(package_build_dir, sizeof(package_build_dir), package_dir,
                    ERB_APP_BUILD_DIR_NAME) != 0 ||
      erb_path_join(output_wasm, sizeof(output_wasm), package_build_dir,
                    ERB_APP_WASM_NAME) != 0) {
    return 1;
  }
  if (erb_validate_app_manifest(manifest_source, &package_contract,
                                source_name, sizeof(source_name)) != 0 ||
      package_contract != ERB_PACKAGE_CONTRACT_UI_APP) {
    return erb_fail("app-run requires a ui-app package");
  }
  if ((print_plan == 0 && erb_target_app_verify(package_dir) != 0) ||
      erb_build_app_run(print_plan) != 0) {
    return 1;
  }
  erb_args_init(&args);
  if (erb_args_push(&args, ERB_APP_RUN_BIN) != 0 ||
      erb_args_push(&args, output_wasm) != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_read_app_contract(const char* package_dir, int* out_contract) {
  char manifest_source[ERB_PATH_CAP];
  char source_name[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0' || out_contract == NULL) {
    return erb_fail("invalid app contract read");
  }
  if (erb_path_join(manifest_source, sizeof(manifest_source), package_dir,
                    ERB_APP_MANIFEST_NAME) != 0 ||
      erb_validate_app_manifest(manifest_source, out_contract,
                                source_name, sizeof(source_name)) != 0) {
    return 1;
  }
  return 0;
}

static int erb_target_app_check(const char* package_dir, int print_plan) {
  int package_contract = 0;

  if (package_dir == NULL || package_dir[0] == '\0') {
    return erb_fail("app-check requires a package directory");
  }
  if (erb_target_app_build(package_dir, print_plan) != 0 ||
      erb_read_app_contract(package_dir, &package_contract) != 0) {
    return 1;
  }
  switch (package_contract) {
    case ERB_PACKAGE_CONTRACT_UI_APP:
      return erb_target_app_run(package_dir, print_plan);
    case ERB_PACKAGE_CONTRACT_BUS_DRIVER:
      if (print_plan != 0) {
        return 0;
      }
      if (erb_target_app_verify(package_dir) != 0) {
        return 1;
      }
      printf("app-check result=verified contract=bus-driver\n");
      return 0;
    default:
      return erb_fail("unsupported app package contract");
  }
}

static int erb_target_app_new(const char* package_dir, const char* contract) {
  const char* scaffold_source;
  const char* scaffold_manifest;
  char output_source[ERB_PATH_CAP];
  char output_manifest[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0' ||
      contract == NULL || contract[0] == '\0') {
    return erb_fail("app-new requires a package directory and contract");
  }
  if (strcmp(contract, "ui-app") == 0) {
    scaffold_source = ERB_UI_APP_SCAFFOLD_SOURCE;
    scaffold_manifest = ERB_UI_APP_SCAFFOLD_MANIFEST;
  } else if (strcmp(contract, "bus-driver") == 0) {
    scaffold_source = ERB_BUS_DRIVER_SCAFFOLD_SOURCE;
    scaffold_manifest = ERB_BUS_DRIVER_SCAFFOLD_MANIFEST;
  } else {
    return erb_fail("app-new contract must be ui-app or bus-driver");
  }
  if (mkdir(package_dir, ERB_OUTPUT_DIR_MODE) != 0) {
    fprintf(stderr, "er-build: mkdir failed for %s: %s\n", package_dir, strerror(errno));
    return 1;
  }
  if (erb_path_join(output_source, sizeof(output_source), package_dir,
                    ERB_APP_ERC_SOURCE_NAME) != 0 ||
      erb_path_join(output_manifest, sizeof(output_manifest), package_dir,
                    ERB_APP_MANIFEST_NAME) != 0 ||
      erb_write_text_new_file(output_source, scaffold_source) != 0 ||
      erb_write_text_new_file(output_manifest, scaffold_manifest) != 0) {
    return 1;
  }
  return 0;
}

static int erb_run_program(const char* program, int print_plan) {
  ErbArgs args;

  erb_args_init(&args);
  if (erb_args_push(&args, program) != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_run_program_arg(const char* program, const char* arg, int print_plan) {
  ErbArgs args;

  erb_args_init(&args);
  if (erb_args_push(&args, program) != 0 || erb_args_push(&args, arg) != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_target_repo_inspect(int argc, char** argv, int print_plan) {
  ErbArgs args;
  char* inspect_argv[ERB_MAX_ARGC];

  if (print_plan != 0) {
    erb_args_init(&args);
    if (erb_args_push(&args, ".build/er-build") != 0 ||
        erb_args_push(&args, "repo-inspect") != 0) {
      return 1;
    }
    for (int i = 0; i < argc; ++i) {
      if (erb_args_push(&args, argv[i]) != 0) {
        return 1;
      }
    }
    return erb_run_args(&args, print_plan);
  }
  if ((size_t)argc + 2u > ERB_MAX_ARGC) {
    return erb_fail("too many repo-inspect arguments");
  }
  inspect_argv[0] = "repo-inspect";
  for (int i = 0; i < argc; ++i) {
    inspect_argv[i + 1] = argv[i];
  }
  inspect_argv[argc + 1] = NULL;
  return eri_main(argc + 1, inspect_argv);
}

static void erb_repo_scope_root_rel(const char* scope, const char** root, const char** rel) {
  const char* cursor = scope;

  while (cursor[0] == '.' && cursor[1] == '/') {
    cursor += 2u;
  }
  if (cursor[0] == 0 || strcmp(cursor, ".") == 0 || cursor[0] == '/') {
    *root = scope;
    *rel = "";
  } else {
    *root = ".";
    *rel = cursor;
  }
}

static int erb_repo_inspect_details_memory(const EriVfs* vfs, ErbTextBuffer* out) {
  int pipe_fds[2];
  pid_t pid;
  int status;
  char chunk[ERB_PIPE_READ_CHUNK];
  EriInspectOptions options;

  if (vfs == NULL || out == NULL) {
    return erb_fail("invalid repo-inspect capture");
  }
  options.thread_count = ERI_DEFAULT_THREAD_COUNT;
  options.details = 1u;
  fflush(stdout);
  if (pipe(pipe_fds) != 0) {
    return erb_fail("pipe failed");
  }
  pid = fork();
  if (pid < 0) {
    close(pipe_fds[0]);
    close(pipe_fds[1]);
    return erb_fail("fork failed");
  }
  if (pid == 0) {
    int rc;

    close(pipe_fds[0]);
    if (dup2(pipe_fds[1], STDOUT_FILENO) < 0) {
      _exit(ERB_EXEC_FAILURE_STATUS);
    }
    close(pipe_fds[1]);
    rc = eri_analyze(vfs, &options) != 0u ? 0 : 1;
    fflush(stdout);
    _exit(rc == 0 ? 0 : 1);
  }
  close(pipe_fds[1]);
  for (;;) {
    ssize_t read_len = read(pipe_fds[0], chunk, sizeof(chunk));

    if (read_len < 0) {
      close(pipe_fds[0]);
      return erb_fail("repo-inspect pipe read failed");
    }
    if (read_len == 0) {
      break;
    }
    if (erb_text_buffer_append(out, chunk, (size_t)read_len) != 0) {
      close(pipe_fds[0]);
      return 1;
    }
  }
  if (close(pipe_fds[0]) != 0) {
    return erb_fail("repo-inspect pipe close failed");
  }
  if (waitpid(pid, &status, 0) < 0) {
    return erb_fail("waitpid failed");
  }
  if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    return erb_fail("repo-inspect failed");
  }
  if (out->data == NULL && erb_text_buffer_append(out, "", 0u) != 0) {
    return 1;
  }
  return 0;
}

static int erb_swarm_issue_parse(const char* line, ErbSwarmIssue* issue) {
  const char* text = line;
  const char* colon;
  const char* after_colon;
  const char* kind_open;
  const char* kind_close;
  char* end = NULL;
  unsigned long parsed_line;
  size_t path_len;
  size_t kind_len;

  if (line == NULL || issue == NULL) {
    return 0;
  }
  while (*text == ' ') {
    ++text;
  }
  colon = strchr(text, ':');
  if (colon == NULL || strstr(text, " [") == NULL) {
    return 0;
  }
  path_len = (size_t)(colon - text);
  if (path_len == 0u || path_len >= sizeof(issue->path)) {
    return 0;
  }
  after_colon = colon + 1;
  errno = 0;
  parsed_line = strtoul(after_colon, &end, ERB_DECIMAL_RADIX);
  if (end == after_colon || errno == ERANGE || parsed_line == 0ul || *end != ' ') {
    return 0;
  }
  memcpy(issue->path, text, path_len);
  issue->path[path_len] = '\0';
  issue->line = (int)parsed_line;
  snprintf(issue->text, sizeof(issue->text), "%s", text);
  kind_open = strchr(text, '[');
  kind_close = kind_open == NULL ? NULL : strchr(kind_open, ']');
  if (kind_open == NULL || kind_close == NULL || kind_close <= kind_open + 1) {
    return 0;
  }
  kind_len = (size_t)(kind_close - kind_open - 1);
  if (kind_len >= sizeof(issue->kind)) {
    kind_len = sizeof(issue->kind) - 1u;
  }
  memcpy(issue->kind, kind_open + 1, kind_len);
  issue->kind[kind_len] = '\0';
  issue->fix_kind = ERB_SWARM_FIX_SKIP;
  return 1;
}

static int erb_swarm_next_issue_line(const char** cursor, char* line, size_t line_len, int* eof) {
  const char* start;
  const char* end;
  size_t len;

  if (cursor == NULL || *cursor == NULL || line == NULL || line_len == 0u || eof == NULL) {
    return 1;
  }
  if (**cursor == '\0') {
    *eof = 1;
    line[0] = '\0';
    return 0;
  }
  start = *cursor;
  end = strchr(start, '\n');
  len = end == NULL ? strlen(start) : (size_t)(end - start);
  if (len >= line_len) {
    len = line_len - 1u;
  }
  memcpy(line, start, len);
  line[len] = '\0';
  *cursor = end == NULL ? start + strlen(start) : end + 1;
  return 0;
}

static const char* erb_swarm_fix_kind_label(ErbSwarmFixKind kind) {
  switch (kind) {
    case ERB_SWARM_FIX_CONSTANT:
      return "name constants";
    case ERB_SWARM_FIX_DUPLICATE:
      return "remove duplication";
    case ERB_SWARM_FIX_BOUNDS:
      return "add bounds guard";
    case ERB_SWARM_FIX_LOCAL_REFACTOR:
      return "small local refactor";
    case ERB_SWARM_FIX_SKIP:
    default:
      return "skip";
  }
}

static int erb_swarm_path_generated_or_catalog(const char* path) {
  const char* base;

  if (path == NULL) {
    return 1;
  }
  base = strrchr(path, '/');
  base = base == NULL ? path : base + 1;
  if (strstr(path, "/generated/") != NULL ||
      strstr(path, "catalog_data") != NULL ||
      strstr(path, "_data.c") != NULL ||
      strstr(path, "_table.c") != NULL ||
      strncmp(base, "zerrors_", ERB_ZERRORS_PREFIX_LEN) == 0 ||
      strncmp(base, "zsyscall_", ERB_ZSYSCALL_PREFIX_LEN) == 0 ||
      strncmp(base, "zsysnum_", ERB_ZSYSNUM_PREFIX_LEN) == 0 ||
      strncmp(base, "ztypes_", ERB_ZTYPES_PREFIX_LEN) == 0) {
    return 1;
  }
  return 0;
}

static ErbSwarmFixKind erb_swarm_issue_fix_kind(const ErbSwarmIssue* issue) {
  if (issue == NULL || erb_swarm_path_generated_or_catalog(issue->path) != 0) {
    return ERB_SWARM_FIX_SKIP;
  }
  if (strcmp(issue->kind, "magic-number") == 0) {
    return ERB_SWARM_FIX_CONSTANT;
  }
  if (strcmp(issue->kind, "duplicate-block") == 0) {
    return ERB_SWARM_FIX_DUPLICATE;
  }
  if (strcmp(issue->kind, "string-indexing") == 0) {
    return ERB_SWARM_FIX_BOUNDS;
  }
  if (strcmp(issue->kind, "cpu-memory-in-loop") == 0 ||
      strcmp(issue->kind, "cpu-alloc-in-loop") == 0) {
    return ERB_SWARM_FIX_LOCAL_REFACTOR;
  }
  return ERB_SWARM_FIX_SKIP;
}

static void erb_swarm_file_tasks_free(ErbSwarmFileTask* tasks, size_t task_count) {
  size_t i;

  for (i = 0u; i < task_count; ++i) {
    erb_text_buffer_free(&tasks[i].issues);
  }
}

static int erb_swarm_file_task_add_issue(ErbSwarmFileTask* tasks,
                                         size_t* task_count,
                                         const ErbSwarmIssue* issue) {
  size_t i;
  ErbSwarmFileTask* task = NULL;
  ErbSwarmFixKind fix_kind;

  if (tasks == NULL || task_count == NULL || issue == NULL) {
    return 1;
  }
  fix_kind = erb_swarm_issue_fix_kind(issue);
  if (fix_kind == ERB_SWARM_FIX_SKIP) {
    return 0;
  }
  for (i = 0u; i < *task_count; ++i) {
    if (strcmp(tasks[i].path, issue->path) == 0) {
      task = &tasks[i];
      break;
    }
  }
  if (task == NULL) {
    if (*task_count >= ERB_SWARM_FILE_TASK_MAX) {
      return erb_fail("too many swarm file tasks");
    }
    task = &tasks[*task_count];
    memset(task, 0, sizeof(*task));
    snprintf(task->path, sizeof(task->path), "%s", issue->path);
    task->fix_kind = fix_kind;
    ++*task_count;
  }
  if (task->issue_count >= ERB_SWARM_MAX_ISSUES_PER_FILE ||
      strstr(task->issues.data == NULL ? "" : task->issues.data, issue->text) != NULL) {
    return 0;
  }
  if (task->fix_kind == ERB_SWARM_FIX_SKIP) {
    task->fix_kind = fix_kind;
  }
  if (erb_text_buffer_append(&task->issues, issue->text, strlen(issue->text)) != 0 ||
      erb_text_buffer_append(&task->issues, "\n", 1u) != 0) {
    return 1;
  }
  ++task->issue_count;
  return 0;
}

static int erb_swarm_file_tasks_from_issues(const ErbTextBuffer* issues,
                                            ErbSwarmFileTask* tasks,
                                            size_t* task_count) {
  const char* cursor;
  char line[ERB_SWARM_LINE_CAP];
  int eof = 0;

  if (issues == NULL || issues->data == NULL || tasks == NULL || task_count == NULL) {
    return 1;
  }
  cursor = issues->data;
  *task_count = 0u;
  while (eof == 0) {
    ErbSwarmIssue issue;

    if (erb_swarm_next_issue_line(&cursor, line, sizeof(line), &eof) != 0) {
      return 1;
    }
    if (eof != 0 || erb_swarm_issue_parse(line, &issue) == 0) {
      continue;
    }
    if (erb_swarm_file_task_add_issue(tasks, task_count, &issue) != 0) {
      return 1;
    }
  }
  return 0;
}

static int erb_swarm_prompt_append(char* prompt, size_t prompt_len, size_t* used,
                                   const char* text) {
  size_t text_len;

  if (prompt == NULL || used == NULL || text == NULL) {
    return 1;
  }
  text_len = strlen(text);
  if (*used + text_len + 1u >= prompt_len) {
    return 1;
  }
  memcpy(prompt + *used, text, text_len);
  *used += text_len;
  prompt[*used] = '\0';
  return 0;
}

static int erb_swarm_prompt_appendf(char* prompt, size_t prompt_len, size_t* used,
                                    const char* format, const char* text) {
  char line[ERB_SWARM_LINE_CAP];
  int written = snprintf(line, sizeof(line), format, text);

  if (written < 0 || (size_t)written >= sizeof(line)) {
    return 1;
  }
  return erb_swarm_prompt_append(prompt, prompt_len, used, line);
}

static int erb_swarm_prompt_for_file_task(const ErbSwarmFileTask* task,
                                          const EriVfs* vfs,
                                          char* prompt,
                                          size_t prompt_len) {
  const EriVfsFile* file;
  size_t used = 0u;

  if (task == NULL || vfs == NULL || prompt == NULL || prompt_len == 0u) {
    return 1;
  }
  prompt[0] = '\0';
  if (erb_swarm_prompt_append(prompt, prompt_len, &used,
      "You are one worker in an automated EdgeRun C repo-agent swarm.\n"
      "Fix repo-inspect issues for exactly one file.\n"
      "Edit only the named file. You may inspect only that file. Do not inspect broad repo state.\n"
      "Do not run git, tests, commits, pushes, branch commands, or repo-inspect.\n"
      "If the file cannot be fixed safely, make no change.\n"
      "Keep the patch local and small; do not add optimizer-ignore annotations unless the issue explicitly asks for one.\n"
      "Output only the file name and proposed unified diff. Do not add explanation outside the diff.\n"
      "Multiple agents share this checkout; do not revert or overwrite unrelated edits.\n\n") != 0 ||
      erb_swarm_prompt_appendf(prompt, prompt_len, &used, "FILE: %s\n\n", task->path) != 0 ||
      erb_swarm_prompt_appendf(prompt, prompt_len, &used, "FIX TYPE: %s\n\n",
                               erb_swarm_fix_kind_label(task->fix_kind)) != 0 ||
      erb_swarm_prompt_append(prompt, prompt_len, &used, "ISSUES:\n") != 0 ||
      erb_swarm_prompt_append(prompt, prompt_len, &used, task->issues.data) != 0 ||
      erb_swarm_prompt_append(prompt, prompt_len, &used, "\n") != 0) {
    return 1;
  }

  file = eri_vfs_find(vfs, task->path);
  if (file == NULL) {
    return erb_swarm_prompt_append(prompt, prompt_len, &used, "Context unavailable: file missing from VFS.\n");
  }
  if (erb_swarm_prompt_append(prompt, prompt_len, &used,
                              "The in-memory workspace contains only FILE. Read that file if needed.\n") != 0) {
    return 1;
  }
  return 0;
}

static void erb_swarm_worker_prefix(const ErbSwarmWorker* worker) {
  printf("[agent-%04u] ", (unsigned)worker->index);
}

static int erb_swarm_stream_worker(ErbSwarmWorker* worker) {
  char chunk[ERB_SWARM_STREAM_CHUNK];
  ssize_t len;
  ssize_t i;

  if (worker == NULL || worker->fd < 0) {
    return 0;
  }
  len = read(worker->fd, chunk, sizeof(chunk));
  if (len < 0) {
    if (errno == EINTR) {
      return 0;
    }
    return erb_fail("worker pipe read failed");
  }
  if (len == 0) {
    close(worker->fd);
    worker->fd = -1;
    return 0;
  }
  for (i = 0; i < len; ++i) {
    if (worker->line_start != 0u) {
      erb_swarm_worker_prefix(worker);
      worker->line_start = 0u;
    }
    putchar(chunk[i]);
    if (chunk[i] == '\n') {
      worker->line_start = 1u;
    }
  }
  fflush(stdout);
  return 0;
}

static ErbSwarmWorker* erb_swarm_find_worker(ErbSwarmWorker* workers, size_t count, pid_t pid) {
  size_t i;

  for (i = 0u; i < count; ++i) {
    if (workers[i].active != 0u && workers[i].pid == pid) {
      return &workers[i];
    }
  }
  return NULL;
}

static int erb_swarm_reap_workers(ErbSwarmWorker* workers,
                                  size_t count,
                                  int* active,
                                  size_t* completed,
                                  size_t* failed) {
  for (;;) {
    int status;
    pid_t done = waitpid(-1, &status, WNOHANG);
    ErbSwarmWorker* worker;

    if (done == 0) {
      return 0;
    }
    if (done < 0) {
      if (errno == ECHILD) {
        return 0;
      }
      return erb_fail("waitpid failed");
    }
    worker = erb_swarm_find_worker(workers, count, done);
    if (worker == NULL) {
      continue;
    }
    while (worker->fd >= 0) {
      if (erb_swarm_stream_worker(worker) != 0) {
        return 1;
      }
    }
    worker->active = 0u;
    --*active;
    ++*completed;
    if (!WIFEXITED(status) || WEXITSTATUS(status) != 0) {
      ++*failed;
      fprintf(stderr, "repo-agent-swarm: worker pid %ld failed\n", (long)done);
    }
  }
}

static int erb_swarm_wait_for_activity(ErbSwarmWorker* workers,
                                       size_t count,
                                       int* active,
                                       size_t* completed,
                                       size_t* failed) {
  fd_set read_fds;
  struct timeval timeout;
  int max_fd = -1;
  int ready;
  size_t i;

  if (erb_swarm_reap_workers(workers, count, active, completed, failed) != 0) {
    return 1;
  }
  if (*active == 0) {
    return 0;
  }
  FD_ZERO(&read_fds);
  for (i = 0u; i < count; ++i) {
    if (workers[i].active != 0u && workers[i].fd >= 0) {
      FD_SET(workers[i].fd, &read_fds);
      if (workers[i].fd > max_fd) {
        max_fd = workers[i].fd;
      }
    }
  }
  if (max_fd < 0) {
    return erb_swarm_reap_workers(workers, count, active, completed, failed);
  }
  timeout.tv_sec = 0;
  timeout.tv_usec = ERB_SELECT_TIMEOUT_USEC;
  ready = select(max_fd + 1, &read_fds, NULL, NULL, &timeout);
  if (ready < 0) {
    if (errno == EINTR) {
      return 0;
    }
    return erb_fail("worker pipe select failed");
  }
  if (ready > 0) {
    for (i = 0u; i < count; ++i) {
      if (workers[i].active != 0u && workers[i].fd >= 0 && FD_ISSET(workers[i].fd, &read_fds)) {
        if (erb_swarm_stream_worker(&workers[i]) != 0) {
          return 1;
        }
      }
    }
  }
  return erb_swarm_reap_workers(workers, count, active, completed, failed);
}

static int erb_swarm_spawn_file_task(const ErbSwarmFileTask* task,
                                 const EriVfs* vfs,
                                 size_t index,
                                 ErbSwarmWorker* worker) {
  char prompt[ERB_SWARM_PROMPT_CAP];
  int pipe_fds[2];
  pid_t pid;

  if (task == NULL || worker == NULL) {
    return 1;
  }
  if (erb_swarm_prompt_for_file_task(task, vfs, prompt, sizeof(prompt)) != 0) {
    return erb_fail("failed to build swarm prompt");
  }
  if (pipe(pipe_fds) != 0) {
    return erb_fail("worker pipe failed");
  }
  pid = fork();
  if (pid < 0) {
    close(pipe_fds[0]);
    close(pipe_fds[1]);
    return erb_fail("fork failed");
  }
  if (pid == 0) {
    char* const args[ERB_SWARM_AGENT_ARGC] = {
      (char*)ERB_CODEX_BIN,
      "--memory-only",
      "--quiet-agent",
      "--minimal-agent",
      "--only-file",
      (char*)task->path,
      "--root",
      ".",
      "--prompt",
      prompt,
      NULL
    };
    close(pipe_fds[0]);
    if (dup2(pipe_fds[1], STDOUT_FILENO) < 0 ||
        dup2(pipe_fds[1], STDERR_FILENO) < 0) {
      _exit(ERB_EXEC_FAILURE_STATUS);
    }
    close(pipe_fds[1]);
    execv(ERB_CODEX_BIN, args);
    fprintf(stderr, "er-build: exec failed for %s: %s\n", ERB_CODEX_BIN, strerror(errno));
    _exit(ERB_EXEC_FAILURE_STATUS);
  }
  close(pipe_fds[1]);
  worker->pid = pid;
  worker->fd = pipe_fds[0];
  worker->index = index;
  worker->active = 1u;
  worker->line_start = 1u;
  printf("repo-agent-swarm: dispatched %04u pid %ld %s\n",
         (unsigned)index, (long)pid, task->path);
  fflush(stdout);
  return 0;
}

static int erb_swarm_parse_bounded(const char* text,
                                   unsigned long max_value,
                                   const char* value_name,
                                   unsigned long* out_value) {
  char* end = NULL;
  unsigned long value;

  if (text == NULL || out_value == NULL) {
    return 0;
  }
  errno = 0;
  value = strtoul(text, &end, ERB_DECIMAL_RADIX);
  if (end == text || *end != '\0' || errno == ERANGE ||
      value == 0ul || value > max_value) {
    fprintf(stderr, "er-build: repo-agent-swarm %s must be 1..%lu\n",
            value_name, max_value);
    return 0;
  }
  *out_value = value;
  return 1;
}

static int erb_swarm_parse_concurrency(const char* text, int* out_value) {
  unsigned long value;

  if (erb_swarm_parse_bounded(text, (unsigned long)ERB_SWARM_MAX_LIMIT,
                              "concurrency", &value) == 0) {
    return 0;
  }
  *out_value = (int)value;
  return 1;
}

static int erb_swarm_parse_limit(const char* text, size_t* out_value) {
  unsigned long value;

  if (erb_swarm_parse_bounded(text, (unsigned long)ERB_SWARM_FILE_TASK_MAX,
                              "limit", &value) == 0) {
    return 0;
  }
  *out_value = (size_t)value;
  return 1;
}

static int erb_target_repo_agent_swarm(int argc, char** argv, int print_plan) {
  const char* scope = ".";
  const char* root;
  const char* rel;
  int concurrency = ERB_SWARM_DEFAULT_LIMIT;
  int argi = 0;
  size_t limit = 0u;
  EriVfs vfs;
  ErbTextBuffer issues;
  ErbSwarmFileTask tasks[ERB_SWARM_FILE_TASK_MAX];
  ErbSwarmWorker workers[ERB_SWARM_MAX_LIMIT];
  int active = 0;
  size_t dispatched = 0u;
  size_t completed = 0u;
  size_t failed = 0u;
  size_t task_count = 0u;
  size_t next_task = 0u;

  while (argi < argc) {
    if (strcmp(argv[argi], "--scope") == 0 && argi + 1 < argc) {
      scope = argv[argi + 1];
      argi += 2;
      continue;
    }
    if (strcmp(argv[argi], "--concurrency") == 0 && argi + 1 < argc) {
      if (erb_swarm_parse_concurrency(argv[argi + 1], &concurrency) == 0) {
        return 2;
      }
      argi += 2;
      continue;
    }
    if (strcmp(argv[argi], "--limit") == 0 && argi + 1 < argc) {
      if (erb_swarm_parse_limit(argv[argi + 1], &limit) == 0) {
        return 2;
      }
      argi += 2;
      continue;
    }
    if (strcmp(argv[argi], "--help") == 0) {
      printf("usage: er-build repo-agent-swarm [--scope PATH] [--concurrency N] [--limit N]\n");
      return 0;
    }
    return erb_usage();
  }

  erb_repo_scope_root_rel(scope, &root, &rel);
  memset(&vfs, 0, sizeof(vfs));
  memset(&issues, 0, sizeof(issues));
  memset(tasks, 0, sizeof(tasks));
  memset(workers, 0, sizeof(workers));
  if (print_plan != 0) {
    printf("+ make codex-build\n");
    printf("+ repo-inspect VFS load %s %s\n", root, rel);
    printf("+ repo-inspect analyze --details <in-memory VFS> | <filtered actionable file task queue>\n");
    if (limit == 0u) {
      printf("+ .build/codex --memory-only --quiet-agent --minimal-agent --only-file FILE --root . --prompt <one focused file, streamed diffs, %d concurrent>\n",
             concurrency);
    } else {
      printf("+ .build/codex --memory-only --quiet-agent --minimal-agent --only-file FILE --root . --prompt <one focused file, streamed diffs, %d concurrent, %u limit>\n",
             concurrency, (unsigned)limit);
    }
    return 0;
  }

  {
    ErbArgs args;
    erb_args_init(&args);
    if (erb_args_push(&args, "make") != 0 ||
        erb_args_push(&args, "codex-build") != 0 ||
        erb_run_args(&args, 0) != 0) {
        return 1;
    }
  }
  if (eri_load_dir(&vfs, root, rel, ERI_DEFAULT_THREAD_COUNT) == 0u) {
    return erb_fail("repo-inspect VFS load failed");
  }
  if (erb_repo_inspect_details_memory(&vfs, &issues) != 0) {
    eri_vfs_free(&vfs);
    erb_text_buffer_free(&issues);
    return 1;
  }
  if (erb_swarm_file_tasks_from_issues(&issues, tasks, &task_count) != 0) {
    eri_vfs_free(&vfs);
    erb_text_buffer_free(&issues);
    erb_swarm_file_tasks_free(tasks, task_count);
    return 1;
  }
  while ((next_task < task_count && (limit == 0u || dispatched < limit)) || active > 0) {
    while (active < concurrency && next_task < task_count && (limit == 0u || dispatched < limit)) {
      ErbSwarmWorker* worker = NULL;
      size_t worker_index;

      for (worker_index = 0u; worker_index < (size_t)concurrency; ++worker_index) {
        if (workers[worker_index].active == 0u) {
          worker = &workers[worker_index];
          break;
        }
      }
      if (worker == NULL) {
        break;
      }
      ++dispatched;
      if (erb_swarm_spawn_file_task(&tasks[next_task], &vfs, dispatched, worker) != 0) {
        eri_vfs_free(&vfs);
        erb_text_buffer_free(&issues);
        erb_swarm_file_tasks_free(tasks, task_count);
        return 1;
      }
      ++next_task;
      ++active;
    }
    if (active > 0) {
      if (erb_swarm_wait_for_activity(workers,
                                      (size_t)concurrency,
                                      &active,
                                      &completed,
                                      &failed) != 0) {
        eri_vfs_free(&vfs);
        erb_text_buffer_free(&issues);
        erb_swarm_file_tasks_free(tasks, task_count);
        return 1;
      }
    }
  }
  eri_vfs_free(&vfs);
  erb_text_buffer_free(&issues);
  erb_swarm_file_tasks_free(tasks, task_count);
  printf("repo-agent-swarm: dispatched %u files completed %u failed %u\n",
         (unsigned)dispatched, (unsigned)completed, (unsigned)failed);
  fflush(stdout);
  return failed == 0u ? 0 : 1;
}

static const char* erb_default_progress_test(const char* scope) {
  if (strcmp(scope, "edgerun-ui-core") == 0) {
    return "ui-core-test";
  }
  if (strcmp(scope, "edgerun-ui-core/varfont") == 0 || strcmp(scope, "varfont") == 0) {
    return "varfont-test";
  }
  if (strcmp(scope, "edgerun-crypto") == 0) {
    return "crypto-test";
  }
  if (strcmp(scope, "edgerun-object") == 0) {
    return "object-test";
  }
  if (strcmp(scope, "storage") == 0) {
    return "storage-test";
  }
  if (strcmp(scope, "edgerun-metal") == 0) {
    return "edgerun-check";
  }
  if (strcmp(scope, "tools/wasm-compile") == 0) {
    return "repo-test";
  }
  if (strcmp(scope, "tools") == 0) {
    return "repo-test";
  }
  if (strcmp(scope, "codex") == 0) {
    return "codex-test";
  }
  return NULL;
}

static int erb_run_progress_step(const char* title, const ErbArgs* args, int print_plan) {
  printf("\n== %s ==\n", title);
  return erb_run_args(args, print_plan);
}

static int erb_target_repo_progress(const char* scope, const char* test_target, int print_plan) {
  ErbArgs args;
  char title[ERB_PROGRESS_TITLE_CAP];

  if (scope == NULL || scope[0] == '\0') {
    fprintf(stderr, "er-build: repo-progress requires a scope\n");
    return 2;
  }
  if (test_target == NULL || test_target[0] == '\0') {
    test_target = erb_default_progress_test(scope);
    if (test_target == NULL) {
      fprintf(stderr, "er-build: no default test target for scope %s\n", scope);
      fprintf(stderr, "er-build: pass an explicit test target\n");
      return 2;
    }
  }

  erb_args_init(&args);
  if (erb_args_push(&args, "git") != 0 ||
      erb_args_push(&args, "status") != 0 ||
      erb_args_push(&args, "--short") != 0 ||
      erb_args_push(&args, "--branch") != 0 ||
      erb_run_progress_step("git status", &args, print_plan) != 0) {
    return 1;
  }

  snprintf(title, sizeof(title), "git diff stat: %s", scope);
  erb_args_init(&args);
  if (erb_args_push(&args, "git") != 0 ||
      erb_args_push(&args, "diff") != 0 ||
      erb_args_push(&args, "--stat") != 0 ||
      erb_args_push(&args, "--") != 0 ||
      erb_args_push(&args, scope) != 0 ||
      erb_run_progress_step(title, &args, print_plan) != 0) {
    return 1;
  }

  snprintf(title, sizeof(title), "git cached diff stat: %s", scope);
  erb_args_init(&args);
  if (erb_args_push(&args, "git") != 0 ||
      erb_args_push(&args, "diff") != 0 ||
      erb_args_push(&args, "--cached") != 0 ||
      erb_args_push(&args, "--stat") != 0 ||
      erb_args_push(&args, "--") != 0 ||
      erb_args_push(&args, scope) != 0 ||
      erb_run_progress_step(title, &args, print_plan) != 0) {
    return 1;
  }

  snprintf(title, sizeof(title), "git diff check: %s", scope);
  erb_args_init(&args);
  if (erb_args_push(&args, "git") != 0 ||
      erb_args_push(&args, "diff") != 0 ||
      erb_args_push(&args, "--check") != 0 ||
      erb_args_push(&args, "--") != 0 ||
      erb_args_push(&args, scope) != 0 ||
      erb_run_progress_step(title, &args, print_plan) != 0) {
    return 1;
  }

  snprintf(title, sizeof(title), "git cached diff check: %s", scope);
  erb_args_init(&args);
  if (erb_args_push(&args, "git") != 0 ||
      erb_args_push(&args, "diff") != 0 ||
      erb_args_push(&args, "--cached") != 0 ||
      erb_args_push(&args, "--check") != 0 ||
      erb_args_push(&args, "--") != 0 ||
      erb_args_push(&args, scope) != 0 ||
      erb_run_progress_step(title, &args, print_plan) != 0) {
    return 1;
  }

  snprintf(title, sizeof(title), "repo-inspect: %s", scope);
  printf("\n== %s ==\n", title);
  {
    char* inspect_argv[] = {(char*)scope};
    if (erb_target_repo_inspect(1, inspect_argv, print_plan) != 0) {
      return 1;
    }
  }

  snprintf(title, sizeof(title), "test target: %s", test_target);
  erb_args_init(&args);
  if (erb_args_push(&args, "make") != 0 ||
      erb_args_push(&args, test_target) != 0 ||
      erb_run_progress_step(title, &args, print_plan) != 0) {
    return 1;
  }
  return 0;
}

static int erb_target_repo_check(int print_plan) {
  if (erb_build_repo_check(print_plan) != 0) {
    return 1;
  }
  return erb_run_program_arg(ERB_REPO_CHECK_BIN, ".", print_plan);
}

static int erb_target_erwire_test(int print_plan) {
  if (erb_build_erwire_decode(print_plan) != 0) {
    return 1;
  }
  return erb_run_program("./tests/erwire-decode-tests.sh", print_plan);
}

static int erb_target_storage_test(int print_plan);
static int erb_target_object_test(int print_plan);

static int erb_target_repo_test(int print_plan) {
  if (erb_build_repo_check(print_plan) != 0 ||
      erb_build_erwire_decode(print_plan) != 0 ||
      erb_build_wasm_compile(print_plan) != 0 ||
      erb_build_pi_serial_verify(print_plan) != 0 ||
      erb_build_pi_node_update(print_plan) != 0 ||
      erb_build_sdcard_probe(print_plan) != 0 ||
      erb_build_disk_analyzer(print_plan) != 0 ||
      erb_build_pi_usb_boot(print_plan) != 0) {
    return 1;
  }
  if (erb_run_program("./tests/repo-check-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-push-check-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-inspect-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-progress-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/er-build-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/app-package-build-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/wasm-compile-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/wasm-compile-source-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/metal-arch-build-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/pi-boot-stage-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/pi-serial-verify-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/pi-zero-w-v1_1-bring-up-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/sdcard-probe-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/disk-analyzer-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/pi-usb-boot-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/er-math-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/erwire-decode-tests.sh", print_plan) != 0 ||
      erb_target_object_test(print_plan) != 0 ||
      erb_target_storage_test(print_plan) != 0) {
    return 1;
  }
  return 0;
}

static int erb_target_crypto_test(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_CRYPTO_BLAKE3_TEST_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Iedgerun-crypto/include") != 0 ||
      erb_args_push(&args, "edgerun-crypto/tests/test_blake3.c") != 0 ||
      erb_args_push(&args, "edgerun-crypto/src/er_blake3.c") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  if (erb_run_program(ERB_CRYPTO_BLAKE3_TEST_BIN, print_plan) != 0) {
    return 1;
  }
  return 0;
}

static int erb_target_crypto_bench(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_CRYPTO_BLAKE3_BENCH_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Iedgerun-crypto/include") != 0 ||
      erb_args_push(&args, "edgerun-crypto/bench/bench_blake3.c") != 0 ||
      erb_args_push(&args, "edgerun-crypto/src/er_blake3.c") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_CRYPTO_BLAKE3_BENCH_BIN, print_plan);
}

static int erb_target_object_test(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 ||
      erb_mkdir_one(ERB_OBJECT_BUILD_DIR) != 0 ||
      erb_compile_common(&args, ERB_OBJECT_TEST_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-ffreestanding") != 0 ||
      erb_args_push(&args, "-fno-builtin") != 0 ||
      erb_args_push(&args, "-fno-stack-protector") != 0 ||
      erb_args_push(&args, "-Iedgerun-object/include") != 0 ||
      erb_args_push(&args, "-Iedgerun-crypto/include") != 0 ||
      erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "edgerun-object/tests/test_object.c") != 0 ||
      erb_args_push(&args, "edgerun-object/src/er_object.c") != 0 ||
      erb_args_push(&args, "edgerun-crypto/src/er_blake3.c") != 0 ||
      erb_args_push(&args, "-DER_BLAKE3_NO_SIMD=1") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_OBJECT_TEST_BIN, print_plan);
}

static int erb_target_storage_test(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_STORAGE_STORE_TEST_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Istorage/include") != 0 ||
      erb_args_push(&args, "-Iedgerun-crypto/include") != 0 ||
      erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "storage/tests/test_store.c") != 0 ||
      erb_args_push(&args, "storage/src/er_store.c") != 0 ||
      erb_args_push(&args, "edgerun-crypto/src/er_blake3.c") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_STORAGE_STORE_TEST_BIN, print_plan);
}

static int erb_target_storage_bench(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_STORAGE_STORE_BENCH_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-Istorage/include") != 0 ||
      erb_args_push(&args, "-Iedgerun-crypto/include") != 0 ||
      erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "storage/bench/bench_store.c") != 0 ||
      erb_args_push(&args, "storage/src/er_store.c") != 0 ||
      erb_args_push(&args, "edgerun-crypto/src/er_blake3.c") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_STORAGE_STORE_BENCH_BIN, print_plan);
}

static int erb_target_varfont_test(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_VARFONT_TEST_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-ffreestanding") != 0 ||
      erb_args_push(&args, "-fno-builtin") != 0 ||
      erb_args_push(&args, "-fno-stack-protector") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/varfont/include") != 0 ||
      erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/varfont/src") != 0 ||
      erb_args_push(&args, "-DVRFONT_PROJECT_ROOT=\"edgerun-ui-core/varfont\"") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_runner.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_common.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_validation.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_axes.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_shape.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_atlas_cache.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_api.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_cmap.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_raster.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/tests/test_vr_font_freestanding.c") != 0 ||
      erb_args_push_varfont_sources(&args) != 0 ||
      erb_args_push(&args, "-lm") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_VARFONT_TEST_BIN, print_plan);
}

static int erb_target_ui_core_test(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_UI_CORE_TEST_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-ffreestanding") != 0 ||
      erb_args_push(&args, "-fno-builtin") != 0 ||
      erb_args_push(&args, "-fno-stack-protector") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/include") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/varfont/include") != 0 ||
      erb_args_push(&args, "-Iedgerun-ui-core/varfont/src") != 0 ||
      erb_args_push(&args, "-Iinclude") != 0 ||
      erb_args_push(&args, "-DER_UI_REPO_ROOT=\".\"") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_assets.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_components.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_ledger_app.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_initial_setup.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_node.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_preset_code.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_record_codec.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_shell.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_runtime.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_scene.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_text.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/tests/test_spacing.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_assets.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_catalog.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_catalog_data.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_contracts.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_emit.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_internal.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_preview.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_components_state.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_ledger_app.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_icon.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_initial_setup.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_metal.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node_accessibility.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node_layout.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node_render.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node_render_controls.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node_render_conversation.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_node_render_panels.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_painter.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_primitives.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_preset_code.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_record_codec.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_runtime_focus.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_runtime_input.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_runtime_internal.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_runtime_state.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_runtime_text.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_scene.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_shell.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_spacing.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_surface_renderer.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_theme.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/src/er_ui_text.c") != 0 ||
      erb_args_push_varfont_sources(&args) != 0 ||
      erb_args_push(&args, "-lm") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_UI_CORE_TEST_BIN, print_plan);
}

static int erb_usage(void) {
  fprintf(stderr,
          "usage: er-build [--print-plan] <target> [args]\n"
          "targets: app-new <package-dir> ui-app|bus-driver\n"
          "         app-build <package-dir> app-verify <package-dir>\n"
          "         app-run <package-dir> app-check <package-dir>\n"
          "         repo-check-bin repo-push-check repo-inspect erwire-decode erwire-test wasm-compile\n"
          "         repo-agent-swarm [--scope PATH] [--concurrency N] [--limit N]\n"
          "         pi-serial-verify pi-node-update sdcard-probe disk-analyzer pi-usb-boot\n"
          "         repo-check repo-test repo-progress <scope> [test-target]\n"
          "         crypto-test crypto-bench object-test storage-test storage-bench varfont-test ui-core-test\n");
  return 2;
}

int main(int argc, char** argv) {
  const char* target;
  int print_plan = 0;
  int target_index = 1;

  if (argc < 2) {
    return erb_usage();
  }
  if (strcmp(argv[target_index], "--print-plan") == 0) {
    print_plan = 1;
    ++target_index;
  }
  target = argv[target_index];
  if (strcmp(target, "repo-progress") == 0) {
    const char* scope;
    const char* test_target = NULL;

    if (target_index + ERB_ARGC_ONE_VALUE > argc ||
        target_index + ERB_ARGC_TWO_VALUES < argc) {
      return erb_usage();
    }
    scope = argv[target_index + 1];
    if (target_index + ERB_ARGC_TWO_VALUES == argc) {
      test_target = argv[target_index + 2];
    }
    return erb_target_repo_progress(scope, test_target, print_plan);
  }
  if (strcmp(target, "app-build") == 0) {
    if (target_index + ERB_ARGC_ONE_VALUE != argc) {
      return erb_usage();
    }
    return erb_target_app_build(argv[target_index + 1], print_plan);
  }
  if (strcmp(target, "app-new") == 0) {
    if (print_plan != 0 || target_index + ERB_ARGC_TWO_VALUES != argc) {
      return erb_usage();
    }
    return erb_target_app_new(argv[target_index + 1], argv[target_index + 2]);
  }
  if (strcmp(target, "app-check") == 0) {
    if (target_index + ERB_ARGC_ONE_VALUE != argc) {
      return erb_usage();
    }
    return erb_target_app_check(argv[target_index + 1], print_plan);
  }
  if (strcmp(target, "app-verify") == 0) {
    if (print_plan != 0 || target_index + ERB_ARGC_ONE_VALUE != argc) {
      return erb_usage();
    }
    return erb_target_app_verify(argv[target_index + 1]);
  }
  if (strcmp(target, "app-run") == 0) {
    if (target_index + ERB_ARGC_ONE_VALUE != argc) {
      return erb_usage();
    }
    return erb_target_app_run(argv[target_index + 1], print_plan);
  }
  if (strcmp(target, "repo-inspect") == 0) {
    return erb_target_repo_inspect(argc - target_index - 1, argv + target_index + 1, print_plan);
  }
  if (strcmp(target, "repo-agent-swarm") == 0) {
    return erb_target_repo_agent_swarm(argc - target_index - 1, argv + target_index + 1, print_plan);
  }
  if (target_index + ERB_ARGC_TARGET_ONLY != argc) {
    return erb_usage();
  }
  if (strcmp(target, "repo-check-bin") == 0) {
    return erb_build_repo_check(print_plan);
  }
  if (strcmp(target, "repo-push-check") == 0) {
    return erb_run_program("./tools/repo-push-check.sh", print_plan);
  }
  if (strcmp(target, "erwire-decode") == 0) {
    return erb_build_erwire_decode(print_plan);
  }
  if (strcmp(target, "wasm-compile") == 0) {
    return erb_build_wasm_compile(print_plan);
  }
  if (strcmp(target, "pi-serial-verify") == 0) {
    return erb_build_pi_serial_verify(print_plan);
  }
  if (strcmp(target, "pi-node-update") == 0) {
    return erb_build_pi_node_update(print_plan);
  }
  if (strcmp(target, "sdcard-probe") == 0) {
    return erb_build_sdcard_probe(print_plan);
  }
  if (strcmp(target, "disk-analyzer") == 0) {
    return erb_build_disk_analyzer(print_plan);
  }
  if (strcmp(target, "pi-usb-boot") == 0) {
    return erb_build_pi_usb_boot(print_plan);
  }
  if (strcmp(target, "erwire-test") == 0) {
    return erb_target_erwire_test(print_plan);
  }
  if (strcmp(target, "repo-check") == 0) {
    return erb_target_repo_check(print_plan);
  }
  if (strcmp(target, "repo-test") == 0) {
    return erb_target_repo_test(print_plan);
  }
  if (strcmp(target, "crypto-test") == 0) {
    return erb_target_crypto_test(print_plan);
  }
  if (strcmp(target, "crypto-bench") == 0) {
    return erb_target_crypto_bench(print_plan);
  }
  if (strcmp(target, "object-test") == 0) {
    return erb_target_object_test(print_plan);
  }
  if (strcmp(target, "storage-test") == 0) {
    return erb_target_storage_test(print_plan);
  }
  if (strcmp(target, "storage-bench") == 0) {
    return erb_target_storage_bench(print_plan);
  }
  if (strcmp(target, "varfont-test") == 0) {
    return erb_target_varfont_test(print_plan);
  }
  if (strcmp(target, "ui-core-test") == 0) {
    return erb_target_ui_core_test(print_plan);
  }
  return erb_usage();
}
