#include "internal/efi_boot_internal.h"

static UINT8 g_ui_boot_arena[ER_UI_BOOT_ARENA_SIZE];
static UINTN g_ui_boot_arena_used;

typedef struct {
  UINTN offset;
  UINTN size;
} ErUiBootArenaFreeBlock;

static ErUiBootArenaFreeBlock g_ui_boot_arena_free_blocks[ER_UI_BOOT_ARENA_FREE_BLOCKS];
static UINTN g_ui_boot_arena_free_block_count;

static UINTN er_ui_boot_align_forward(UINTN value, UINTN align) {
  UINTN mask;

  if (align == 0u) {
    align = 1u;
  }
  mask = align - 1u;
  if ((align & mask) != 0u) {
    return ER_UI_BOOT_ARENA_SIZE + 1u;
  }
  return (value + mask) & ~mask;
}

static void er_ui_boot_arena_remove_free_block(UINTN index) {
  UINTN i;

  if (index >= g_ui_boot_arena_free_block_count) {
    return;
  }
  for (i = index + 1u; i < g_ui_boot_arena_free_block_count; ++i) {
    g_ui_boot_arena_free_blocks[i - 1u] = g_ui_boot_arena_free_blocks[i];
  }
  --g_ui_boot_arena_free_block_count;
}

static UINT8 er_ui_boot_arena_insert_free_block(UINTN offset, UINTN size) {
  UINTN index;
  UINTN i;

  if (size == 0u || offset >= ER_UI_BOOT_ARENA_SIZE ||
      size > ER_UI_BOOT_ARENA_SIZE - offset) {
    return 0u;
  }
  if (g_ui_boot_arena_free_block_count >= ER_UI_BOOT_ARENA_FREE_BLOCKS) {
    return 0u;
  }

  index = 0u;
  while (index < g_ui_boot_arena_free_block_count &&
         g_ui_boot_arena_free_blocks[index].offset < offset) {
    ++index;
  }
  for (i = g_ui_boot_arena_free_block_count; i > index; --i) {
    g_ui_boot_arena_free_blocks[i] = g_ui_boot_arena_free_blocks[i - 1u];
  }
  g_ui_boot_arena_free_blocks[index].offset = offset;
  g_ui_boot_arena_free_blocks[index].size = size;
  ++g_ui_boot_arena_free_block_count;

  if (index > 0u) {
    ErUiBootArenaFreeBlock* prev = &g_ui_boot_arena_free_blocks[index - 1u];
    ErUiBootArenaFreeBlock* current = &g_ui_boot_arena_free_blocks[index];
    if (prev->offset + prev->size == current->offset) {
      prev->size += current->size;
      er_ui_boot_arena_remove_free_block(index);
      --index;
    }
  }
  if (index + 1u < g_ui_boot_arena_free_block_count) {
    ErUiBootArenaFreeBlock* current = &g_ui_boot_arena_free_blocks[index];
    ErUiBootArenaFreeBlock* next = &g_ui_boot_arena_free_blocks[index + 1u];
    if (current->offset + current->size == next->offset) {
      current->size += next->size;
      er_ui_boot_arena_remove_free_block(index + 1u);
    }
  }
  return 1u;
}

static void* er_ui_boot_alloc_from_free_blocks(UINTN size, UINTN align) {
  UINTN i;

  for (i = 0u; i < g_ui_boot_arena_free_block_count; ++i) {
    ErUiBootArenaFreeBlock block = g_ui_boot_arena_free_blocks[i];
    UINTN start = er_ui_boot_align_forward(block.offset, align);
    UINTN block_end;
    UINTN end;
    UINTN prefix_size;
    UINTN suffix_size;

    if (start > ER_UI_BOOT_ARENA_SIZE || size > ER_UI_BOOT_ARENA_SIZE - start) {
      continue;
    }
    end = start + size;
    block_end = block.offset + block.size;
    if (end > block_end) {
      continue;
    }

    prefix_size = start - block.offset;
    suffix_size = block_end - end;
    er_ui_boot_arena_remove_free_block(i);
    if (prefix_size != 0u &&
        er_ui_boot_arena_insert_free_block(block.offset, prefix_size) == 0u) {
      return 0;
    }
    if (suffix_size != 0u &&
        er_ui_boot_arena_insert_free_block(end, suffix_size) == 0u) {
      return 0;
    }
    return g_ui_boot_arena + start;
  }
  return 0;
}

void* er_ui_boot_alloc(void* user, size_t size, size_t align) {
  UINTN start;
  UINTN end;
  UINT8* arena = (UINT8*)user;
  void* free_block;

  if (arena == 0 || size == 0u) {
    return 0;
  }
  if (align == 0u) {
    align = 1u;
  }
  if (arena != g_ui_boot_arena || (UINTN)size > ER_UI_BOOT_ARENA_SIZE) {
    return 0;
  }

  free_block = er_ui_boot_alloc_from_free_blocks((UINTN)size, (UINTN)align);
  if (free_block != 0) {
    return free_block;
  }

  start = er_ui_boot_align_forward(g_ui_boot_arena_used, (UINTN)align);
  if (start > ER_UI_BOOT_ARENA_SIZE) {
    return 0;
  }
  if ((UINTN)size > ER_UI_BOOT_ARENA_SIZE || start > ER_UI_BOOT_ARENA_SIZE - (UINTN)size) {
    return 0;
  }
  end = start + (UINTN)size;
  g_ui_boot_arena_used = end;
  return arena + start;
}

void er_ui_boot_free(void* user, void* ptr, size_t size, size_t align) {
  (void)align;

  if (user != g_ui_boot_arena || ptr == 0 || size == 0u ||
      (UINT8*)ptr < g_ui_boot_arena ||
      (UINT8*)ptr >= g_ui_boot_arena + ER_UI_BOOT_ARENA_SIZE) {
    return;
  }
  (void)er_ui_boot_arena_insert_free_block((UINTN)((UINT8*)ptr - g_ui_boot_arena), (UINTN)size);
}

void* er_ui_boot_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  UINT8* next;
  UINTN copy_size;

  if (ptr == 0) {
    return er_ui_boot_alloc(user, new_size, align);
  }
  if (new_size == 0u) {
    er_ui_boot_free(user, ptr, old_size, align);
    return 0;
  }
  if (new_size <= old_size) {
    return ptr;
  }
  next = (UINT8*)er_ui_boot_alloc(user, new_size, align);
  if (next == 0 || ptr == 0 || old_size == 0u) {
    return next;
  }
  copy_size = (UINTN)(old_size < new_size ? old_size : new_size);
  er_mem_copy(next, (const UINT8*)ptr, copy_size);
  er_ui_boot_free(user, ptr, old_size, align);
  return next;
}

void er_ui_boot_allocator_reset(void) {
  g_ui_boot_arena_used = 0u;
  g_ui_boot_arena_free_block_count = 0u;
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
  er_ui_boot_allocator_reset();
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
