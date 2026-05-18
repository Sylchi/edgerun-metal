#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

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
  ERB_OUTPUT_DIR_MODE = 0777
};

static const char ERB_DEFAULT_CC[] = "clang";
static const char ERB_BUILD_DIR[] = ".build";
static const char ERB_INTERNAL_BUILD_DIR[] = ".build/er-build-out";
static const char ERB_CRYPTO_BUILD_DIR[] = ".build/er-build-out/crypto";
static const char ERB_REPO_CHECK_BIN[] = ".build/repo-check";
static const char ERB_REPO_INSPECT_BIN[] = ".build/repo-inspect";
static const char ERB_ERWIRE_DECODE_BIN[] = ".build/erwire-decode";
static const char ERB_CRYPTO_TEST_BIN[] = ".build/er-build-out/crypto/test_blake3";

typedef struct {
  const char* items[ERB_MAX_ARGC];
  size_t count;
} ErbArgs;

static int erb_fail(const char* message) {
  fprintf(stderr, "er-build: %s\n", message);
  return 1;
}

static const char* erb_host_cc(void) {
  const char* host_cc = getenv("HOST_CC");

  if (host_cc != NULL && host_cc[0] != '\0') {
    return host_cc;
  }
  host_cc = getenv("CC");
  if (host_cc != NULL && host_cc[0] != '\0') {
    return host_cc;
  }
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

static int erb_prepare_dirs(void) {
  if (erb_mkdir_one(ERB_BUILD_DIR) != 0) {
    return 1;
  }
  if (erb_mkdir_one(ERB_INTERNAL_BUILD_DIR) != 0) {
    return 1;
  }
  return erb_mkdir_one(ERB_CRYPTO_BUILD_DIR);
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
      erb_build_erwire_decode(print_plan) != 0) {
    return 1;
  }
  if (erb_run_program("./tests/repo-check-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-inspect-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/repo-progress-tests.sh", print_plan) != 0 ||
      erb_run_program("./tests/er-build-tests.sh", print_plan) != 0 ||
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

static int erb_usage(void) {
  fprintf(stderr,
          "usage: er-build [--print-plan] <target>\n"
          "targets: repo-check-bin repo-inspect erwire-decode erwire-test repo-check repo-test crypto-test\n");
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
  if (target_index + 1 != argc) {
    return erb_usage();
  }
  target = argv[target_index];
  if (strcmp(target, "repo-check-bin") == 0) {
    return erb_build_repo_check(print_plan);
  }
  if (strcmp(target, "repo-inspect") == 0) {
    return erb_build_repo_inspect(print_plan);
  }
  if (strcmp(target, "erwire-decode") == 0) {
    return erb_build_erwire_decode(print_plan);
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
  return erb_usage();
}
