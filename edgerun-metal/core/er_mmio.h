#ifndef ER_MMIO_H
#define ER_MMIO_H

/*
 * Purpose: expose read-only MMIO handle primitives for native and Wasm driver code.
 * Intention: validate handles and ranges before any register reads; writes are intentionally absent.
 */

#include "er_types.h"

#define ER_MMIO_MAX_MAPS 8u
#define ER_MMIO_INVALID_HANDLE 0u

typedef struct {
  UINT8 used;
  UINT64 phys;
  UINT64 len;
} ErMmioInfo;

void er_mmio_reset(void);
UINT8 er_mmio_map_request_valid(INT64 phys_i, INT64 len_i);
UINT8 er_mmio_read32_request_valid(INT64 handle_i, INT64 offset_i);
INT64 er_mmio_map(INT64 phys_i, INT64 len_i);
UINT8 er_mmio_get_info(INT64 handle_i, ErMmioInfo* out_info);
INT64 er_mmio_read32(INT64 handle_i, INT64 offset_i);

#endif
