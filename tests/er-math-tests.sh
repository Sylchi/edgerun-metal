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
  if (er_math_clamp_size(9u, 2u, 5u) != 5u) return 5;
  if (er_math_align_up_u64(17u, 8u) != 24u) return 6;
  if (er_math_align_down_u64(17u, 8u) != 16u) return 7;
  if (er_math_next_power_of_two_u64(33u) != 64u) return 8;
  if (!nearf(er_math_lerpf(10.0f, 20.0f, 0.25f), 12.5f, 0.001f)) return 9;
  if (!nearf(er_math_lerp_clampedf(10.0f, 20.0f, 2.0f), 20.0f, 0.001f)) return 10;
  if (!nearf(er_math_smoothstepf(0.0f, 1.0f, 0.5f), 0.5f, 0.001f)) return 11;
  if (er_math_u8_from_unitf(0.5f) != 128u) return 12;
  if (!nearf(er_math_distance_sq2f(1.0f, 2.0f, 4.0f, 6.0f), 25.0f, 0.001f)) return 13;
  if (er_math_floor_i64(-1.25f) != -2) return 14;
  if (er_math_ceil_i64(1.25f) != 2) return 15;
  if (!nearf(er_math_sqrtf(144.0f), 12.0f, 0.02f)) return 16;
  if (!nearf(er_math_rsqrtf(4.0f), 0.5f, 0.002f)) return 17;
  if (!nearf(er_math_atan2f(1.0f, 0.0f), ER_MATH_HALF_PI, 0.001f)) return 18;
  if (!er_math_isfinitef(1.0f)) return 19;
  if (er_math_isfinitef(1.0f / 0.0f)) return 20;
  return 0;
}
C

"${CC:-clang}" -std=c11 -Wall -Wextra -Werror -ffreestanding -fno-builtin -I"${ROOT_DIR}" -o "${TMP_DIR}/er_math_test" "${TMP_DIR}/er_math_test.c"
"${TMP_DIR}/er_math_test"
printf 'er_math tests passed\n'
