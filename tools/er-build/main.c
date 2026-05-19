#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include "package_identity.h"

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
  ERB_MANIFEST_CAP = 512
};

static const char ERB_DEFAULT_CC[] = "clang";
static const char ERB_BUILD_DIR[] = ".build";
static const char ERB_INTERNAL_BUILD_DIR[] = ".build/er-build-out";
static const char ERB_CRYPTO_BUILD_DIR[] = ".build/er-build-out/crypto";
static const char ERB_VARFONT_BUILD_DIR[] = ".build/er-build-out/varfont";
static const char ERB_REPO_CHECK_BIN[] = ".build/repo-check";
static const char ERB_REPO_INSPECT_BIN[] = ".build/repo-inspect";
static const char ERB_ERWIRE_DECODE_BIN[] = ".build/erwire-decode";
static const char ERB_WASM_COMPILE_BIN[] = ".build/wasm-compile";
static const char ERB_APP_RUN_BIN[] = ".build/app-run";
static const char ERB_CRYPTO_TEST_BIN[] = ".build/er-build-out/crypto/test_blake3";
static const char ERB_VARFONT_TEST_BIN[] = ".build/er-build-out/varfont/vrfont_tests";
static const char ERB_APP_SOURCE_NAME[] = "app.c";
static const char ERB_APP_MANIFEST_NAME[] = "app.manifest";
static const char ERB_APP_BUILD_DIR_NAME[] = ".build";
static const char ERB_APP_WASM_NAME[] = "app.wasm";
static const char ERB_APP_PACKAGE_IDENTITY_NAME[] = "package.identity";
static const char ERB_APP_MANIFEST_EXPECTED[] =
    "contract=ui-app\n"
    "memory_pages=1\n"
    "imports=edgerun.ui/emit\n"
    "source=app.c\n"
    "output=.build/app.wasm\n";

typedef struct {
  const char* items[ERB_MAX_ARGC];
  size_t count;
} ErbArgs;

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

static int erb_validate_app_manifest(const char* path) {
  char text[ERB_MANIFEST_CAP];

  if (erb_read_text_file(path, text, sizeof(text)) != 0) {
    return 1;
  }
  if (strcmp(text, ERB_APP_MANIFEST_EXPECTED) != 0) {
    fprintf(stderr, "er-build: invalid app manifest %s\n", path);
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
  return erb_mkdir_one(ERB_VARFONT_BUILD_DIR);
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

static int erb_build_repo_inspect(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_REPO_INSPECT_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "-pthread") != 0 ||
      erb_args_push(&args, "tools/repo-inspect/repo_inspect_main.c") != 0) {
    return 1;
  }
  return erb_run_args(&args, print_plan);
}

static int erb_build_erwire_decode(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_ERWIRE_DECODE_BIN) != 0) {
    return 1;
  }
  if (erb_args_push(&args, "tools/erwire-decode.c") != 0) {
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
      erb_args_push(&args, "tools/wasm-compile/wasm_compile_parse.c") != 0) {
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

static int erb_target_app_build(const char* package_dir, int print_plan) {
  ErbArgs args;
  char app_source[ERB_PATH_CAP];
  char manifest_source[ERB_PATH_CAP];
  char package_build_dir[ERB_PATH_CAP];
  char output_wasm[ERB_PATH_CAP];
  char output_identity[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0') {
    return erb_fail("app-build requires a package directory");
  }
  if (erb_path_join(app_source, sizeof(app_source), package_dir,
                    ERB_APP_SOURCE_NAME) != 0 ||
      erb_path_join(manifest_source, sizeof(manifest_source), package_dir,
                    ERB_APP_MANIFEST_NAME) != 0 ||
      erb_path_join(package_build_dir, sizeof(package_build_dir), package_dir,
                    ERB_APP_BUILD_DIR_NAME) != 0 ||
      erb_path_join(output_wasm, sizeof(output_wasm), package_build_dir,
                    ERB_APP_WASM_NAME) != 0 ||
      erb_path_join(output_identity, sizeof(output_identity), package_build_dir,
                    ERB_APP_PACKAGE_IDENTITY_NAME) != 0) {
    return 1;
  }
  if (erb_require_regular_file(app_source) != 0 ||
      erb_require_regular_file(manifest_source) != 0 ||
      erb_validate_app_manifest(manifest_source) != 0 ||
      erb_build_wasm_compile(print_plan) != 0) {
    return 1;
  }
  if (print_plan == 0 && erb_mkdir_one(package_build_dir) != 0) {
    return 1;
  }
  erb_args_init(&args);
  if (erb_args_push(&args, ERB_WASM_COMPILE_BIN) != 0 ||
      erb_args_push(&args, app_source) != 0 ||
      erb_args_push(&args, output_wasm) != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  if (print_plan != 0) {
    return 0;
  }
  return erb_write_app_package_identity(output_identity, app_source, manifest_source,
                                        output_wasm);
}

static int erb_target_app_verify(const char* package_dir) {
  char app_source[ERB_PATH_CAP];
  char manifest_source[ERB_PATH_CAP];
  char package_build_dir[ERB_PATH_CAP];
  char output_wasm[ERB_PATH_CAP];
  char output_identity[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0') {
    return erb_fail("app-verify requires a package directory");
  }
  if (erb_path_join(app_source, sizeof(app_source), package_dir,
                    ERB_APP_SOURCE_NAME) != 0 ||
      erb_path_join(manifest_source, sizeof(manifest_source), package_dir,
                    ERB_APP_MANIFEST_NAME) != 0 ||
      erb_path_join(package_build_dir, sizeof(package_build_dir), package_dir,
                    ERB_APP_BUILD_DIR_NAME) != 0 ||
      erb_path_join(output_wasm, sizeof(output_wasm), package_build_dir,
                    ERB_APP_WASM_NAME) != 0 ||
      erb_path_join(output_identity, sizeof(output_identity), package_build_dir,
                    ERB_APP_PACKAGE_IDENTITY_NAME) != 0) {
    return 1;
  }
  if (erb_require_regular_file(app_source) != 0 ||
      erb_require_regular_file(manifest_source) != 0 ||
      erb_require_regular_file(output_wasm) != 0 ||
      erb_require_regular_file(output_identity) != 0 ||
      erb_validate_app_manifest(manifest_source) != 0) {
    return 1;
  }
  return erb_verify_app_package_identity(output_identity, app_source, manifest_source,
                                         output_wasm);
}

static int erb_target_app_run(const char* package_dir, int print_plan) {
  ErbArgs args;
  char package_build_dir[ERB_PATH_CAP];
  char output_wasm[ERB_PATH_CAP];

  if (package_dir == NULL || package_dir[0] == '\0') {
    return erb_fail("app-run requires a package directory");
  }
  if (erb_path_join(package_build_dir, sizeof(package_build_dir), package_dir,
                    ERB_APP_BUILD_DIR_NAME) != 0 ||
      erb_path_join(output_wasm, sizeof(output_wasm), package_build_dir,
                    ERB_APP_WASM_NAME) != 0) {
    return 1;
  }
  if (erb_target_app_verify(package_dir) != 0 ||
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
  if (strcmp(scope, "edgerun-metal") == 0) {
    return "edgerun-check";
  }
  if (strcmp(scope, "tools/wasm-compile") == 0) {
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
  char title[256];

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

  erb_args_init(&args);
  if (erb_args_push(&args, "make") != 0 ||
      erb_args_push(&args, "repo-inspect") != 0 ||
      erb_run_progress_step("build repo-inspect", &args, print_plan) != 0) {
    return 1;
  }

  snprintf(title, sizeof(title), "repo-inspect: %s", scope);
  erb_args_init(&args);
  if (erb_args_push(&args, ERB_REPO_INSPECT_BIN) != 0 ||
      erb_args_push(&args, scope) != 0 ||
      erb_run_progress_step(title, &args, print_plan) != 0) {
    return 1;
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

static int erb_target_repo_test(int print_plan) {
  if (erb_build_repo_check(print_plan) != 0 ||
      erb_build_repo_inspect(print_plan) != 0 ||
      erb_build_erwire_decode(print_plan) != 0 ||
      erb_build_wasm_compile(print_plan) != 0) {
    return 1;
  }
  if (erb_run_program("./tests/repo-check-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-inspect-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-progress-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/er-build-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/app-package-build-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/wasm-compile-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/metal-arch-build-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/er-math-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/erwire-decode-tests.sh", print_plan) != 0) {
    return 1;
  }
  return 0;
}

static int erb_target_crypto_test(int print_plan) {
  ErbArgs args;

  if (erb_prepare_dirs() != 0 || erb_compile_common(&args, ERB_CRYPTO_TEST_BIN) != 0) {
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
  return erb_run_program(ERB_CRYPTO_TEST_BIN, print_plan);
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
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_freestanding.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_utils.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_axes.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_cmap.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_gvar.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_gvar_apply.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_kern.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_tables.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_shape.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_raster.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_raster_geometry.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_raster_glyph.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_raster_msdf.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_raster_outline.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_raster_storage.c") != 0 ||
      erb_args_push(&args, "edgerun-ui-core/varfont/src/vr_font_atlas.c") != 0 ||
      erb_args_push(&args, "-lm") != 0) {
    return 1;
  }
  if (erb_run_args(&args, print_plan) != 0) {
    return 1;
  }
  return erb_run_program(ERB_VARFONT_TEST_BIN, print_plan);
}

static int erb_usage(void) {
  fprintf(stderr,
          "usage: er-build [--print-plan] <target> [args]\n"
          "targets: app-build <package-dir> app-verify <package-dir> app-run <package-dir>\n"
          "         repo-check-bin repo-inspect erwire-decode erwire-test wasm-compile\n"
          "         repo-check repo-test repo-progress <scope> [test-target]\n"
          "         crypto-test varfont-test\n");
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

    if (target_index + 2 > argc || target_index + 3 < argc) {
      return erb_usage();
    }
    scope = argv[target_index + 1];
    if (target_index + 3 == argc) {
      test_target = argv[target_index + 2];
    }
    return erb_target_repo_progress(scope, test_target, print_plan);
  }
  if (strcmp(target, "app-build") == 0) {
    if (target_index + 2 != argc) {
      return erb_usage();
    }
    return erb_target_app_build(argv[target_index + 1], print_plan);
  }
  if (strcmp(target, "app-verify") == 0) {
    if (print_plan != 0 || target_index + 2 != argc) {
      return erb_usage();
    }
    return erb_target_app_verify(argv[target_index + 1]);
  }
  if (strcmp(target, "app-run") == 0) {
    if (target_index + 2 != argc) {
      return erb_usage();
    }
    return erb_target_app_run(argv[target_index + 1], print_plan);
  }
  if (target_index + 1 != argc) {
    return erb_usage();
  }
  if (strcmp(target, "repo-check-bin") == 0) {
    return erb_build_repo_check(print_plan);
  }
  if (strcmp(target, "repo-inspect") == 0) {
    return erb_build_repo_inspect(print_plan);
  }
  if (strcmp(target, "erwire-decode") == 0) {
    return erb_build_erwire_decode(print_plan);
  }
  if (strcmp(target, "wasm-compile") == 0) {
    return erb_build_wasm_compile(print_plan);
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
  if (strcmp(target, "varfont-test") == 0) {
    return erb_target_varfont_test(print_plan);
  }
  return erb_usage();
}
