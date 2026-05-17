#ifndef ER_MATH_H
#define ER_MATH_H

#include <stdint.h>
#include <stddef.h>

#define ER_MATH_FLOAT_MAX 3.4028234663852886e38f
#define ER_MATH_PI 3.14159265358979323846f
#define ER_MATH_HALF_PI (ER_MATH_PI * 0.5f)
#define ER_MATH_QUARTER_PI (ER_MATH_PI * 0.25f)
#define ER_MATH_THREE_QUARTER_PI (ER_MATH_PI * 0.75f)
#define ER_MATH_ATAN2_EPSILON 1.0e-10f
#define ER_MATH_ATAN2_CUBIC 0.1963f
#define ER_MATH_ATAN2_LINEAR -0.9817f
#define ER_MATH_INV_SQRT_MAGIC 0x5f3759dfu

static inline float er_math_absf(float value) {
  return value < 0.0f ? -value : value;
}

static inline float er_math_minf(float a, float b) {
  return a < b ? a : b;
}

static inline float er_math_maxf(float a, float b) {
  return a > b ? a : b;
}

static inline float er_math_clampf(float value, float min_value, float max_value) {
  if (value < min_value) return min_value;
  if (value > max_value) return max_value;
  return value;
}

static inline float er_math_clamp01f(float value) {
  return er_math_clampf(value, 0.0f, 1.0f);
}

static inline size_t er_math_min_size(size_t a, size_t b) {
  return a < b ? a : b;
}

static inline size_t er_math_max_size(size_t a, size_t b) {
  return a > b ? a : b;
}

static inline size_t er_math_clamp_size(size_t value, size_t min_value, size_t max_value) {
  if (value < min_value) return min_value;
  if (value > max_value) return max_value;
  return value;
}

static inline uint64_t er_math_min_u64(uint64_t a, uint64_t b) {
  return a < b ? a : b;
}

static inline uint64_t er_math_max_u64(uint64_t a, uint64_t b) {
  return a > b ? a : b;
}

static inline uint64_t er_math_clamp_u64(uint64_t value, uint64_t min_value, uint64_t max_value) {
  if (value < min_value) return min_value;
  if (value > max_value) return max_value;
  return value;
}

static inline int er_math_is_power_of_two_u64(uint64_t value) {
  return value != 0u && (value & (value - 1u)) == 0u;
}

static inline uint64_t er_math_align_down_u64(uint64_t value, uint64_t alignment) {
  if (!er_math_is_power_of_two_u64(alignment)) return value;
  return value & ~(alignment - 1u);
}

static inline uint64_t er_math_align_up_u64(uint64_t value, uint64_t alignment) {
  uint64_t mask;

  if (!er_math_is_power_of_two_u64(alignment)) return value;
  mask = alignment - 1u;
  if (value > UINT64_MAX - mask) return UINT64_MAX & ~mask;
  return (value + mask) & ~mask;
}

static inline uint64_t er_math_next_power_of_two_u64(uint64_t value) {
  if (value <= 1u) return 1u;
  --value;
  value |= value >> 1u;
  value |= value >> 2u;
  value |= value >> 4u;
  value |= value >> 8u;
  value |= value >> 16u;
  value |= value >> 32u;
  if (value == UINT64_MAX) return UINT64_MAX;
  return value + 1u;
}

static inline float er_math_lerpf(float a, float b, float t) {
  return a + (b - a) * t;
}

static inline float er_math_lerp_clampedf(float a, float b, float t) {
  return er_math_lerpf(a, b, er_math_clamp01f(t));
}

static inline float er_math_smoothstepf(float edge0, float edge1, float value) {
  float t;

  if (edge0 == edge1) return value < edge0 ? 0.0f : 1.0f;
  t = er_math_clamp01f((value - edge0) / (edge1 - edge0));
  return t * t * (3.0f - 2.0f * t);
}

static inline float er_math_smootherstepf(float edge0, float edge1, float value) {
  float t;

  if (edge0 == edge1) return value < edge0 ? 0.0f : 1.0f;
  t = er_math_clamp01f((value - edge0) / (edge1 - edge0));
  return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f);
}

static inline uint8_t er_math_u8_from_unitf(float value) {
  float scaled = er_math_clamp01f(value) * 255.0f + 0.5f;

  if (scaled <= 0.0f) return 0u;
  if (scaled >= 255.0f) return 255u;
  return (uint8_t)scaled;
}

static inline float er_math_dot2f(float ax, float ay, float bx, float by) {
  return ax * bx + ay * by;
}

static inline float er_math_length_sq2f(float x, float y) {
  return er_math_dot2f(x, y, x, y);
}

static inline float er_math_distance_sq2f(float ax, float ay, float bx, float by) {
  float dx = ax - bx;
  float dy = ay - by;
  return er_math_length_sq2f(dx, dy);
}

static inline int er_math_isfinitef(float value) {
  return value == value && value <= ER_MATH_FLOAT_MAX && value >= -ER_MATH_FLOAT_MAX;
}

static inline float er_math_floorf(float value) {
  int32_t truncated = (int32_t)value;
  if ((float)truncated > value) --truncated;
  return (float)truncated;
}

static inline float er_math_ceilf(float value) {
  int32_t truncated = (int32_t)value;
  if ((float)truncated < value) ++truncated;
  return (float)truncated;
}

static inline int64_t er_math_floor_i64(float value) {
  int64_t truncated = (int64_t)value;
  if (value < 0.0f && (float)truncated != value) --truncated;
  return truncated;
}

static inline int64_t er_math_ceil_i64(float value) {
  int64_t truncated = (int64_t)value;
  if (value > 0.0f && (float)truncated != value) ++truncated;
  return truncated;
}

static inline long er_math_lrintf(float value) {
  return (long)(value >= 0.0f ? value + 0.5f : value - 0.5f);
}

static inline float er_math_sqrtf(float value) {
  union {
    float f;
    uint32_t u;
  } x;

  if (value <= 0.0f) return 0.0f;
  x.f = value;
  x.u = (x.u >> 1u) + 0x1fc00000u;
  x.f = 0.5f * (x.f + value / x.f);
  x.f = 0.5f * (x.f + value / x.f);
  return x.f;
}

static inline float er_math_length2f(float x, float y) {
  return er_math_sqrtf(er_math_length_sq2f(x, y));
}

static inline float er_math_distance2f(float ax, float ay, float bx, float by) {
  return er_math_sqrtf(er_math_distance_sq2f(ax, ay, bx, by));
}

static inline float er_math_rsqrtf(float value) {
  union {
    float f;
    uint32_t u;
  } x;
  float half;

  if (value <= 0.0f) return 0.0f;
  half = value * 0.5f;
  x.f = value;
  x.u = ER_MATH_INV_SQRT_MAGIC - (x.u >> 1u);
  x.f = x.f * (1.5f - half * x.f * x.f);
  x.f = x.f * (1.5f - half * x.f * x.f);
  return x.f;
}

static inline float er_math_atan2f(float y, float x) {
  float abs_y;
  float angle;
  float ratio;

  if (x == 0.0f) {
    if (y > 0.0f) return ER_MATH_HALF_PI;
    if (y < 0.0f) return -ER_MATH_HALF_PI;
    return 0.0f;
  }

  abs_y = er_math_absf(y) + ER_MATH_ATAN2_EPSILON;
  if (x < 0.0f) {
    ratio = (x + abs_y) / (abs_y - x);
    angle = ER_MATH_THREE_QUARTER_PI;
  } else {
    ratio = (x - abs_y) / (x + abs_y);
    angle = ER_MATH_QUARTER_PI;
  }
  angle += (ER_MATH_ATAN2_CUBIC * ratio * ratio + ER_MATH_ATAN2_LINEAR) * ratio;
  return y < 0.0f ? -angle : angle;
}

#endif
