#include "er_mem.h"

/*
 * Purpose: implement the metal byte helpers used by freestanding modules.
 * Intention: keep simple memory operations explicit and auditable without pulling in host libc.
 */

void er_mem_zero(UINT8* bytes, UINTN len) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0; i < len; ++i) {
    bytes[i] = 0;
  }
}

void er_mem_copy(UINT8* dst, const UINT8* src, UINTN len) {
  UINTN i;

  if (dst == 0 || src == 0) {
    return;
  }
  for (i = 0; i < len; ++i) {
    dst[i] = src[i];
  }
}

UINT8 er_mem_equal(const UINT8* a, const UINT8* b, UINTN len) {
  UINTN i;

  if (a == 0 || b == 0) {
    return 0;
  }
  for (i = 0; i < len; ++i) {
    if (a[i] != b[i]) {
      return 0;
    }
  }
  return 1;
}
