#ifndef ER_BYTES_H
#define ER_BYTES_H

#include <stddef.h>
#include <stdint.h>

static inline void er_bytes_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static inline void er_bytes_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

static inline int er_bytes_nonzero(const void* data, size_t len) {
  size_t i;
  const uint8_t* bytes = (const uint8_t*)data;

  for (i = 0u; i < len; ++i) {
    if (bytes[i] != 0u) {
      return 1;
    }
  }
  return 0;
}

static inline int er_bytes_zeroed(const void* data, size_t len) {
  return er_bytes_nonzero(data, len) == 0;
}

static inline int er_bytes_equal(const void* left_data, const void* right_data, size_t len) {
  size_t i;
  const uint8_t* left = (const uint8_t*)left_data;
  const uint8_t* right = (const uint8_t*)right_data;

  for (i = 0u; i < len; ++i) {
    if (left[i] != right[i]) {
      return 0;
    }
  }
  return 1;
}

static inline int er_bytes_compare(const uint8_t* left, const uint8_t* right, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (left[i] < right[i]) {
      return -1;
    }
    if (left[i] > right[i]) {
      return 1;
    }
  }
  return 0;
}

static inline void er_bytes_store16_le(uint8_t* out, uint16_t value) {
  out[0] = (uint8_t)value;
  out[1] = (uint8_t)(value >> 8u);
}

static inline void er_bytes_store32_le(uint8_t* out, uint32_t value) {
  out[0] = (uint8_t)value;
  out[1] = (uint8_t)(value >> 8u);
  out[2] = (uint8_t)(value >> 16u);
  out[3] = (uint8_t)(value >> 24u);
}

static inline void er_bytes_store64_le(uint8_t* out, uint64_t value) {
  er_bytes_store32_le(out, (uint32_t)value);
  er_bytes_store32_le(&out[4], (uint32_t)(value >> 32u));
}

static inline uint16_t er_bytes_load16_le(const uint8_t* in) {
  return (uint16_t)((uint16_t)in[0] | ((uint16_t)in[1] << 8u));
}

static inline uint32_t er_bytes_load32_le(const uint8_t* in) {
  return (uint32_t)in[0] |
         ((uint32_t)in[1] << 8u) |
         ((uint32_t)in[2] << 16u) |
         ((uint32_t)in[3] << 24u);
}

static inline uint64_t er_bytes_load64_le(const uint8_t* in) {
  return (uint64_t)er_bytes_load32_le(in) |
         ((uint64_t)er_bytes_load32_le(&in[4]) << 32u);
}

#endif
