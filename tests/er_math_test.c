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
  if (er_math_min_size(9u, 2u) != 2u) return 5;
  if (er_math_max_size(9u, 2u) != 9u) return 6;
  if (er_math_clamp_size(1u, 2u, 5u) != 2u) return 7;
  if (er_math_clamp_size(9u, 2u, 5u) != 5u) return 8;
  if (er_math_min_u64(9u, 2u) != 2u) return 9;
  if (er_math_max_u64(9u, 2u) != 9u) return 10;
  if (er_math_clamp_u64(1u, 2u, 5u) != 2u) return 11;
  if (er_math_clamp_u64(9u, 2u, 5u) != 5u) return 12;
  if (er_math_clamp_u64(3u, 2u, 5u) != 3u) return 13;
  if (er_math_align_up_u64(17u, 8u) != 24u) return 14;
  if (er_math_align_up_u64(UINT64_MAX - 1u, 8u) != (UINT64_MAX & ~7ull)) return 15;
  if (er_math_align_down_u64(17u, 8u) != 16u) return 16;
  if (er_math_align_down_u64(17u, 7u) != 17u) return 17;
  if (er_math_next_power_of_two_u64(33u) != 64u) return 18;
  if (er_math_next_power_of_two_u64(UINT64_MAX) != UINT64_MAX) return 19;
  if (!nearf(er_math_lerpf(10.0f, 20.0f, 0.25f), 12.5f, 0.001f)) return 20;
  if (!nearf(er_math_lerp_clampedf(10.0f, 20.0f, 2.0f), 20.0f, 0.001f)) return 21;
  if (!nearf(er_math_smoothstepf(0.0f, 1.0f, 0.5f), 0.5f, 0.001f)) return 22;
  if (!nearf(er_math_smoothstepf(1.0f, 1.0f, 0.5f), 0.0f, 0.001f)) return 23;
  if (!nearf(er_math_smootherstepf(0.0f, 1.0f, 0.5f), 0.5f, 0.001f)) return 24;
  if (!nearf(er_math_smootherstepf(1.0f, 1.0f, 2.0f), 1.0f, 0.001f)) return 25;
  if (er_math_u8_from_unitf(0.5f) != 128u) return 26;
  if (!nearf(er_math_distance_sq2f(1.0f, 2.0f, 4.0f, 6.0f), 25.0f, 0.001f)) return 27;
  if (!nearf(er_math_length2f(3.0f, 4.0f), 5.0f, 0.02f)) return 28;
  if (!nearf(er_math_distance2f(1.0f, 2.0f, 4.0f, 6.0f), 5.0f, 0.02f)) return 29;
  if (er_math_floor_i64(-1.25f) != -2) return 30;
  if (er_math_ceil_i64(1.25f) != 2) return 31;
  if (!nearf(er_math_sqrtf(144.0f), 12.0f, 0.02f)) return 32;
  if (!nearf(er_math_rsqrtf(4.0f), 0.5f, 0.002f)) return 33;
  if (!nearf(er_math_atan2f(1.0f, 0.0f), ER_MATH_HALF_PI, 0.001f)) return 34;
  if (!er_math_isfinitef(1.0f)) return 35;
  if (er_math_isfinitef(1.0f / 0.0f)) return 36;
  return 0;
}
