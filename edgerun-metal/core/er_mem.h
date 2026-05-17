#ifndef ER_MEM_H
#define ER_MEM_H

/*
 * Purpose: provide small explicit byte helpers for freestanding metal modules.
 * Intention: avoid drifting local memset/memcpy clones while not depending on host libc.
 */

#include "er_types.h"

void er_mem_zero(UINT8* bytes, UINTN len);
void er_mem_copy(UINT8* dst, const UINT8* src, UINTN len);
UINT8 er_mem_equal(const UINT8* a, const UINT8* b, UINTN len);
UINT8 er_mem_any_nonzero(const UINT8* bytes, UINTN len);

#endif
