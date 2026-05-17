#include <stddef.h>

void* memcpy(void* restrict dst, const void* restrict src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  for (size_t i = 0u; i < size; ++i) out[i] = in[i];
  return dst;
}

void* memset(void* dst, int value, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  unsigned char byte = (unsigned char)value;
  for (size_t i = 0u; i < size; ++i) out[i] = byte;
  return dst;
}

void* memmove(void* dst, const void* src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  if (out == in || size == 0u) return dst;
  if (out < in) {
    for (size_t i = 0u; i < size; ++i) out[i] = in[i];
  } else {
    for (size_t i = size; i > 0u; --i) out[i - 1u] = in[i - 1u];
  }
  return dst;
}

int memcmp(const void* left, const void* right, size_t size) {
  const unsigned char* a = (const unsigned char*)left;
  const unsigned char* b = (const unsigned char*)right;
  for (size_t i = 0u; i < size; ++i) {
    if (a[i] != b[i]) return a[i] < b[i] ? -1 : 1;
  }
  return 0;
}
