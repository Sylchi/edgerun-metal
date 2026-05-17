#ifndef ER_MATH_H
#define ER_MATH_H

#include <stdint.h>

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
