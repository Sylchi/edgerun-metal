#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

cat > "${TMP_DIR}/er_math_test.c" <<'C'
#include "include/er_math.h"

static int nearf(float a, float b, float tolerance) {
  float delta = er_math_absf(a - b);
  return delta <= tolerance;
}

int main(void) {
  if (er_math_clamp01f(-2.0f) != 0.0f) return 1;
  if (er_math_clamp01f(2.0f) != 1.0f) return 2;
  if (er_math_minf(3.0f, -4.0f) != -4.0f) return 3;
  if (er_math_maxf(3.0f, -4.0f) != 3.0f) return 4;
  if (er_math_floor_i64(-1.25f) != -2) return 5;
  if (er_math_ceil_i64(1.25f) != 2) return 6;
  if (!nearf(er_math_sqrtf(144.0f), 12.0f, 0.02f)) return 7;
  if (!nearf(er_math_rsqrtf(4.0f), 0.5f, 0.002f)) return 8;
  if (!nearf(er_math_atan2f(1.0f, 0.0f), ER_MATH_HALF_PI, 0.001f)) return 9;
  if (!er_math_isfinitef(1.0f)) return 10;
  if (er_math_isfinitef(1.0f / 0.0f)) return 11;
  return 0;
}
C

"${CC:-clang}" -std=c11 -Wall -Wextra -Werror -ffreestanding -fno-builtin -I"${ROOT_DIR}" -o "${TMP_DIR}/er_math_test" "${TMP_DIR}/er_math_test.c"
"${TMP_DIR}/er_math_test"
printf 'er_math tests passed\n'
