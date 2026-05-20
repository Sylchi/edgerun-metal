/*
 * Purpose: provide compiler ABI helpers required by freestanding C code.
 * Intention: keep metal builds independent from host libc while allowing compiler-generated copies and clears.
 */

#include "er_types.h"

int _fltused = 0;

void __chkstk(void) {
}

void* memcpy(void* dst, const void* src, UINTN size) {
  UINT8* out = (UINT8*)dst;
  const UINT8* in = (const UINT8*)src;
  UINTN i;

  for (i = 0; i < size; ++i) {
    out[i] = in[i];
  }
  return dst;
}

void* memset(void* dst, int value, UINTN size) {
  UINT8* out = (UINT8*)dst;
  UINT8 byte = (UINT8)value;
  UINTN i;

  for (i = 0; i < size; ++i) {
    out[i] = byte;
  }
  return dst;
}

void* memmove(void* dst, const void* src, UINTN size) {
  UINT8* out = (UINT8*)dst;
  const UINT8* in = (const UINT8*)src;
  UINTN i;

  if (out == in || size == 0u) {
    return dst;
  }
  if (out < in) {
    for (i = 0; i < size; ++i) {
      out[i] = in[i];
    }
  } else {
    for (i = size; i > 0u; --i) {
      out[i - 1u] = in[i - 1u];
    }
  }
  return dst;
}

void __aeabi_memcpy(void* dst, const void* src, UINTN size) {
  (void)memcpy(dst, src, size);
}

void __aeabi_memcpy4(void* dst, const void* src, UINTN size) {
  (void)memcpy(dst, src, size);
}

void __aeabi_memcpy8(void* dst, const void* src, UINTN size) {
  (void)memcpy(dst, src, size);
}

void __aeabi_memclr(void* dst, UINTN size) {
  (void)memset(dst, 0, size);
}

void __aeabi_memclr4(void* dst, UINTN size) {
  (void)memset(dst, 0, size);
}

void __aeabi_memclr8(void* dst, UINTN size) {
  (void)memset(dst, 0, size);
}

int memcmp(const void* left, const void* right, UINTN size) {
  const UINT8* a = (const UINT8*)left;
  const UINT8* b = (const UINT8*)right;
  UINTN i;

  for (i = 0; i < size; ++i) {
    if (a[i] != b[i]) {
      return a[i] < b[i] ? -1 : 1;
    }
  }
  return 0;
}
