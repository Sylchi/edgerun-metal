#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly TMP_DIR="$(mktemp -d)"
readonly TEST_SRC="${SCRIPT_DIR}/er_math_test.c"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

"${CC:-clang}" -std=c11 -Wall -Wextra -Werror -ffreestanding -fno-builtin -I"${ROOT_DIR}" -o "${TMP_DIR}/er_math_test" "${TEST_SRC}"
"${TMP_DIR}/er_math_test"
printf 'er_math tests passed\n'
