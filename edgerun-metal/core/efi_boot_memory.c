#include "efi_boot_internal.h"

static UINT8 g_ui_boot_arena[ER_UI_BOOT_ARENA_SIZE];
static UINTN g_ui_boot_arena_used;

void* er_ui_boot_alloc(void* user, size_t size, size_t align) {
  UINTN mask;
  UINTN start;
  UINTN end;
  UINT8* arena = (UINT8*)user;

  if (arena == 0 || size == 0u) {
    return 0;
  }
  if (align == 0u) {
    align = 1u;
  }
  mask = (UINTN)align - 1u;
  if (((UINTN)align & mask) != 0u) {
    return 0;
  }

  start = (g_ui_boot_arena_used + mask) & ~mask;
  if ((UINTN)size > ER_UI_BOOT_ARENA_SIZE || start > ER_UI_BOOT_ARENA_SIZE - (UINTN)size) {
    return 0;
  }
  end = start + (UINTN)size;
  g_ui_boot_arena_used = end;
  return arena + start;
}

void er_ui_boot_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)ptr;
  (void)size;
  (void)align;
}

void* er_ui_boot_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  UINT8* next;
  UINTN copy_size;

  if (new_size == 0u) {
    return 0;
  }
  next = (UINT8*)er_ui_boot_alloc(user, new_size, align);
  if (next == 0 || ptr == 0 || old_size == 0u) {
    return next;
  }
  copy_size = (UINTN)(old_size < new_size ? old_size : new_size);
  er_mem_copy(next, (const UINT8*)ptr, copy_size);
  return next;
}

er_ui_allocator_t er_ui_boot_allocator(void) {
  er_ui_allocator_t allocator;
  allocator.user = g_ui_boot_arena;
  allocator.alloc = er_ui_boot_alloc;
  allocator.free = er_ui_boot_free;
  return allocator;
}

void er_fill_nonzero_bytes(UINT8* bytes, UINTN len, UINT8 seed) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0u; i < len; ++i) {
    bytes[i] = (UINT8)(seed + (UINT8)i);
  }
}

vr_font_allocator_t er_ui_boot_font_allocator(void) {
  vr_font_allocator_t allocator;
  allocator.user = g_ui_boot_arena;
  allocator.alloc = er_ui_boot_alloc;
  allocator.realloc = er_ui_boot_realloc;
  allocator.free = er_ui_boot_free;
  return allocator;
}

UINT8 er_ui_boot_create_font(UINT32 height, vr_font_face_t** out_font) {
  vr_font_config_t font_cfg;

  if (out_font == 0) {
    return 0u;
  }
  *out_font = 0;
  g_ui_boot_arena_used = 0u;
  font_cfg.px_size = height <= ER_UI_BOOT_LOW_HEIGHT_MAX ? ER_UI_BOOT_SMALL_FONT_PX : ER_UI_BOOT_LARGE_FONT_PX;
  font_cfg.atlas_width = ER_UI_BOOT_FONT_ATLAS_SIZE;
  font_cfg.atlas_height = ER_UI_BOOT_FONT_ATLAS_SIZE;
  font_cfg.atlas_pad = ER_UI_BOOT_FONT_ATLAS_PAD;
  font_cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  font_cfg.allocator = er_ui_boot_font_allocator();
  font_cfg.gl.user = 0;
  font_cfg.gl.create_texture = 0;
  font_cfg.gl.update_texture = 0;
  font_cfg.gl.destroy_texture = 0;
  return (UINT8)(vr_font_face_create_from_memory(out_font, g_er_font_geist_ttf,
                                                ER_FONT_GEIST_TTF_SIZE, &font_cfg) == VR_OK &&
                 *out_font != 0);
}
