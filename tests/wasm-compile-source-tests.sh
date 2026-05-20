#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Test the in-memory ERC/WAT compiler core without the path-based CLI wrapper.
# Intention:
#   Keep the EdgeRun compiler boundary source-bytes to Wasm-bytes.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly TMP_DIR="$(mktemp -d)"
readonly TEST_BIN="${TMP_DIR}/wasm_compile_source_test"
readonly TEST_SRC="${TMP_DIR}/wasm_compile_source_test.c"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

cat > "${TEST_SRC}" <<'CTEST'
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "tools/wasm-compile/wasm_compile.h"

enum {
  TEST_WASM_MAGIC_0 = 0x00u,
  TEST_WASM_MAGIC_1 = 0x61u,
  TEST_WASM_MAGIC_2 = 0x73u,
  TEST_WASM_MAGIC_3 = 0x6du,
  TEST_WASM_VERSION_0 = 0x01u,
  TEST_WASM_VERSION_1 = 0x00u,
  TEST_WASM_VERSION_2 = 0x00u,
  TEST_WASM_VERSION_3 = 0x00u,
  TEST_WASM_HEADER_BYTES = 8
};

static int test_fail(const char* message) {
  fprintf(stderr, "wasm-compile-source-test: %s\n", message);
  return 1;
}

static ErWcSource test_source(const char* text) {
  ErWcSource source;

  memset(&source, 0, sizeof(source));
  source.path = "memory";
  source.bytes = (uint8_t*)text;
  source.len = strlen(text);
  return source;
}

static int test_wasm_header(const ErWcBuffer* out) {
  static const uint8_t expected[TEST_WASM_HEADER_BYTES] = {
    TEST_WASM_MAGIC_0,
    TEST_WASM_MAGIC_1,
    TEST_WASM_MAGIC_2,
    TEST_WASM_MAGIC_3,
    TEST_WASM_VERSION_0,
    TEST_WASM_VERSION_1,
    TEST_WASM_VERSION_2,
    TEST_WASM_VERSION_3
  };

  if (out == NULL || out->len < TEST_WASM_HEADER_BYTES ||
      memcmp(out->bytes, expected, sizeof(expected)) != 0) {
    return test_fail("bad wasm header");
  }
  return 0;
}

static int test_compile_ok(const char* label,
                           const char* text,
                           ErWcSourceKind source_kind) {
  ErWcSource source = test_source(text);
  ErWcBuffer out;
  ErWcCompileStatus status;

  status = erwc_compile_source(&source, source_kind, &out);
  if (status != ERWC_COMPILE_STATUS_OK) {
    fprintf(stderr, "wasm-compile-source-test: %s status %d\n", label, status);
    return 1;
  }
  return test_wasm_header(&out);
}

static int test_compile_status(const char* label,
                               const char* text,
                               ErWcSourceKind source_kind,
                               ErWcCompileStatus expected,
                               const char* expected_code) {
  ErWcSource source = test_source(text);
  ErWcBuffer out;
  ErWcCompileStatus status;

  status = erwc_compile_source(&source, source_kind, &out);
  if (status != expected) {
    fprintf(stderr,
            "wasm-compile-source-test: %s status %d expected %d\n",
            label,
            status,
            expected);
    return 1;
  }
  if (strcmp(erwc_compile_status_code(status), expected_code) != 0) {
    fprintf(stderr,
            "wasm-compile-source-test: %s code %s expected %s\n",
            label,
            erwc_compile_status_code(status),
            expected_code);
    return 1;
  }
  if (erwc_compile_status_message(status)[0] == 0) {
    return test_fail("empty diagnostic message");
  }
  return 0;
}

int main(void) {
  ErWcBuffer out;

  if (erwc_compile_source(NULL, ERWC_SOURCE_KIND_ERC, &out) !=
      ERWC_COMPILE_STATUS_BAD_ARGS) {
    return test_fail("null source accepted");
  }
  if (test_compile_ok("erc ok",
                      "extern i64 ui_emit(i64, i64) "
                      "__import(\"edgerun.ui\", \"emit\");\n"
                      "memory(1);\n"
                      "export i64 main(void) { return ui_emit(0, 0); }\n",
                      ERWC_SOURCE_KIND_ERC) != 0) {
    return 1;
  }
  if (test_compile_ok("wat ok",
                      "(module\n"
                      "  (type $ui_emit_t "
                      "(func (param i64 i64) (result i64)))\n"
                      "  (type $main_t (func (result i64)))\n"
                      "  (import \"edgerun.ui\" \"emit\" "
                      "(func $ui_emit (type $ui_emit_t)))\n"
                      "  (memory 1)\n"
                      "  (func (export \"main\") "
                      "(type $main_t) (result i64)\n"
                      "    (i64.const 0))\n"
                      ")\n",
                      ERWC_SOURCE_KIND_WAT) != 0) {
    return 1;
  }
  if (test_compile_status("host include",
                          "#include <stdio.h>\n"
                          "extern i64 ui_emit(i64, i64) "
                          "__import(\"edgerun.ui\", \"emit\");\n"
                          "memory(1);\n"
                          "export i64 main(void) { return ui_emit(0, 0); }\n",
                          ERWC_SOURCE_KIND_ERC,
                          ERWC_COMPILE_STATUS_UNSUPPORTED_ERC,
                          "ERWC0100") != 0) {
    return 1;
  }
  if (test_compile_status("missing contract import",
                          "memory(1);\n"
                          "export i64 main(void) { return 1; }\n",
                          ERWC_SOURCE_KIND_ERC,
                          ERWC_COMPILE_STATUS_CONTRACT_REJECTED,
                          "ERWC0300") != 0) {
    return 1;
  }
  if (test_compile_status("bad wat",
                          "(module (memory 1) (func (export \"main\") "
                          "(result i64) (i32.add)))\n",
                          ERWC_SOURCE_KIND_WAT,
                          ERWC_COMPILE_STATUS_UNSUPPORTED_WAT,
                          "ERWC0201") != 0) {
    return 1;
  }
  printf("wasm-compile source tests passed\n");
  return 0;
}
CTEST

"${ROOT_DIR}/toolchain/bin/clang" \
  -std=c11 \
  -Wall \
  -Wextra \
  -Werror \
  -O2 \
  -I"${ROOT_DIR}" \
  -o "${TEST_BIN}" \
  "${TEST_SRC}" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_c.c" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_common.c" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_contract.c" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_emit.c" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_module.c" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_parse.c" \
  "${ROOT_DIR}/tools/wasm-compile/wasm_compile_source.c"

"${TEST_BIN}"
