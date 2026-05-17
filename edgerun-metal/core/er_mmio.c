#include "er_mmio.h"

/*
 * Purpose: manage a small MMIO mapping table in UEFI app mode.
 * Intention: treat physical addresses as identity-readable until Boot Services mapping is required.
 */

#define ER_MMIO_MAX_SIGNED_ADDRESS 0x7fffffffffffffffull

static ErMmioInfo g_mmio_maps[ER_MMIO_MAX_MAPS];

void er_mmio_reset(void) {
  UINT32 i;

  for (i = 0; i < ER_MMIO_MAX_MAPS; ++i) {
    g_mmio_maps[i].used = 0;
    g_mmio_maps[i].phys = 0;
    g_mmio_maps[i].len = 0;
  }
}

UINT8 er_mmio_map_request_valid(INT64 phys_i, INT64 len_i) {
  UINT64 phys = (UINT64)phys_i;
  UINT64 len = (UINT64)len_i;

  if (phys_i <= 0 || len_i <= 0) {
    return 0;
  }

  if (phys + len < phys) {
    return 0;
  }

  if (len > ER_MMIO_MAX_SIGNED_ADDRESS - phys) {
    return 0;
  }

  return 1;
}

static UINT8 er_mmio_access_request_valid(INT64 handle_i, INT64 offset_i, UINT64 width) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  const ErMmioInfo* map;

  if (handle_i <= 0 || offset_i < 0 || width == 0u) {
    return 0;
  }

  handle = (UINT32)handle_i;
  if (handle == ER_MMIO_INVALID_HANDLE || handle > ER_MMIO_MAX_MAPS) {
    return 0;
  }

  map = &g_mmio_maps[handle - 1u];
  if (map->used == 0u) {
    return 0;
  }

  if ((offset & (width - 1u)) != 0u || offset > map->len || map->len - offset < width) {
    return 0;
  }

  return 1;
}

UINT8 er_mmio_read8_request_valid(INT64 handle_i, INT64 offset_i) {
  return er_mmio_access_request_valid(handle_i, offset_i, 1u);
}

UINT8 er_mmio_read16_request_valid(INT64 handle_i, INT64 offset_i) {
  return er_mmio_access_request_valid(handle_i, offset_i, 2u);
}

UINT8 er_mmio_read32_request_valid(INT64 handle_i, INT64 offset_i) {
  return er_mmio_access_request_valid(handle_i, offset_i, 4u);
}

UINT8 er_mmio_write8_request_valid(INT64 handle_i, INT64 offset_i) {
  return er_mmio_read8_request_valid(handle_i, offset_i);
}

UINT8 er_mmio_write16_request_valid(INT64 handle_i, INT64 offset_i) {
  return er_mmio_read16_request_valid(handle_i, offset_i);
}

UINT8 er_mmio_write32_request_valid(INT64 handle_i, INT64 offset_i) {
  return er_mmio_read32_request_valid(handle_i, offset_i);
}

INT64 er_mmio_map(INT64 phys_i, INT64 len_i) {
  UINT64 phys = (UINT64)phys_i;
  UINT64 len = (UINT64)len_i;
  UINT32 i;

  if (er_mmio_map_request_valid(phys_i, len_i) == 0u) {
    return -1;
  }

  for (i = 0; i < ER_MMIO_MAX_MAPS; ++i) {
    if (g_mmio_maps[i].used != 0u && g_mmio_maps[i].phys == phys && g_mmio_maps[i].len == len) {
      return (INT64)(i + 1u);
    }
  }

  for (i = 0; i < ER_MMIO_MAX_MAPS; ++i) {
    if (g_mmio_maps[i].used == 0u) {
      g_mmio_maps[i].used = 1;
      g_mmio_maps[i].phys = phys;
      g_mmio_maps[i].len = len;
      return (INT64)(i + 1u);
    }
  }

  return -1;
}

UINT8 er_mmio_get_info(INT64 handle_i, ErMmioInfo* out_info) {
  UINT32 handle;
  const ErMmioInfo* map;

  if (out_info == 0) {
    return 0;
  }

  out_info->used = 0;
  out_info->phys = 0;
  out_info->len = 0;

  if (handle_i <= 0) {
    return 0;
  }

  handle = (UINT32)handle_i;
  if (handle == ER_MMIO_INVALID_HANDLE || handle > ER_MMIO_MAX_MAPS) {
    return 0;
  }

  map = &g_mmio_maps[handle - 1u];
  if (map->used == 0u) {
    return 0;
  }

  out_info->used = map->used;
  out_info->phys = map->phys;
  out_info->len = map->len;
  return 1;
}

INT64 er_mmio_read8(INT64 handle_i, INT64 offset_i) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  const volatile UINT8* ptr;
  const ErMmioInfo* map;

  if (er_mmio_read8_request_valid(handle_i, offset_i) == 0u) {
    return -1;
  }

  handle = (UINT32)handle_i;
  map = &g_mmio_maps[handle - 1u];
  ptr = (const volatile UINT8*)(UINTN)(map->phys + offset);
  return (INT64)(UINT8)(*ptr);
}

INT64 er_mmio_read16(INT64 handle_i, INT64 offset_i) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  const volatile UINT16* ptr;
  const ErMmioInfo* map;

  if (er_mmio_read16_request_valid(handle_i, offset_i) == 0u) {
    return -1;
  }

  handle = (UINT32)handle_i;
  map = &g_mmio_maps[handle - 1u];
  ptr = (const volatile UINT16*)(UINTN)(map->phys + offset);
  return (INT64)(UINT16)(*ptr);
}

INT64 er_mmio_read32(INT64 handle_i, INT64 offset_i) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  const volatile UINT32* ptr;
  const ErMmioInfo* map;

  if (er_mmio_read32_request_valid(handle_i, offset_i) == 0u) {
    return -1;
  }

  handle = (UINT32)handle_i;
  map = &g_mmio_maps[handle - 1u];
  ptr = (const volatile UINT32*)(UINTN)(map->phys + offset);
  return (INT64)(UINT32)(*ptr);
}

UINT8 er_mmio_write8(INT64 handle_i, INT64 offset_i, UINT8 value) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  volatile UINT8* ptr;
  const ErMmioInfo* map;

  if (er_mmio_write8_request_valid(handle_i, offset_i) == 0u) {
    return 0;
  }

  handle = (UINT32)handle_i;
  map = &g_mmio_maps[handle - 1u];
  ptr = (volatile UINT8*)(UINTN)(map->phys + offset);
  *ptr = value;
  return 1;
}

UINT8 er_mmio_write16(INT64 handle_i, INT64 offset_i, UINT16 value) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  volatile UINT16* ptr;
  const ErMmioInfo* map;

  if (er_mmio_write16_request_valid(handle_i, offset_i) == 0u) {
    return 0;
  }

  handle = (UINT32)handle_i;
  map = &g_mmio_maps[handle - 1u];
  ptr = (volatile UINT16*)(UINTN)(map->phys + offset);
  *ptr = value;
  return 1;
}

UINT8 er_mmio_write32(INT64 handle_i, INT64 offset_i, UINT32 value) {
  UINT64 offset = (UINT64)offset_i;
  UINT32 handle;
  volatile UINT32* ptr;
  const ErMmioInfo* map;

  if (er_mmio_write32_request_valid(handle_i, offset_i) == 0u) {
    return 0;
  }

  handle = (UINT32)handle_i;
  map = &g_mmio_maps[handle - 1u];
  ptr = (volatile UINT32*)(UINTN)(map->phys + offset);
  *ptr = value;
  return 1;
}
