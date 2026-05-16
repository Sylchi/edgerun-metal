#include "vr_font_internal.h"

#include <limits.h>
#include <string.h>

static const size_t VR_ATLAS_INITIAL_CAPACITY = 4u;
static const size_t VR_GLYPH_CACHE_INITIAL_CAPACITY = 64u;
static const uint32_t VR_FNV_OFFSET_BASIS = 2166136261u;
static const uint32_t VR_FNV_PRIME = 0x9e3779b9u;
static const size_t VR_ATLAS_ALPHA_BYTES_PER_PIXEL = 1u;
static const size_t VR_ATLAS_MSDF_BYTES_PER_PIXEL = 3u;

static size_t vr_atlas_pixel_stride(vr_font_atlas_format_t atlas_format) {
  switch (atlas_format) {
    case VR_FONT_ATLAS_FORMAT_ALPHA8:
      return VR_ATLAS_ALPHA_BYTES_PER_PIXEL;
    case VR_FONT_ATLAS_FORMAT_MSDF_RGB:
      return VR_ATLAS_MSDF_BYTES_PER_PIXEL;
    case VR_FONT_ATLAS_FORMAT_UNSPECIFIED:
    default:
      return 0u;
  }
}

static vr_status_t vr_atlas_pixel_count(size_t w, size_t h, size_t bpp, size_t* out_pixel_count) {
  if (!out_pixel_count) return VR_ERR_INVALID_FONT;
  if (w == 0u || h == 0u || bpp == 0u) return VR_ERR_INVALID_FONT;
  if (w > (SIZE_MAX / h) || (w * h) > (SIZE_MAX / bpp)) {
    return VR_ERR_OOM;
  }
  *out_pixel_count = w * h * bpp;
  return VR_OK;
}

static size_t vr_next_capacity(size_t current, size_t minimum, size_t initial_capacity) {
  size_t capacity = (current == 0u) ? initial_capacity : current;
  while (capacity < minimum) {
    if (capacity > (SIZE_MAX / 2u)) {
      return minimum;
    }
    capacity *= 2u;
  }
  return capacity;
}

static vr_status_t vr_reserve_array(
  void** out_ptr,
  size_t* out_cap,
  size_t needed,
  size_t elem_size,
  size_t initial_cap,
  int clear_tail) {
  if (needed <= *out_cap) {
    return VR_OK;
  }

  size_t new_cap = vr_next_capacity(*out_cap, needed, initial_cap);
  void* resized = realloc(*out_ptr, new_cap * elem_size);
  if (!resized) {
    return VR_ERR_OOM;
  }

  if (*out_ptr == NULL) {
    memset(resized, 0, new_cap * elem_size);
  } else if (clear_tail && new_cap > *out_cap) {
    memset((uint8_t*)resized + (*out_cap * elem_size), 0, (new_cap - *out_cap) * elem_size);
  }

  *out_ptr = resized;
  *out_cap = new_cap;
  return VR_OK;
}

static uint32_t vr_hash_axes(const vr_font_face_t* face) {
  uint32_t h = VR_FNV_OFFSET_BASIS;
  for (uint16_t i = 0; i < face->fvar.axis_count && i < VR_MAX_AXES; ++i) {
    union {
      float f;
      uint32_t u;
    } c;
    c.f = face->axis_values[i];
    h ^= (c.u + VR_FNV_PRIME + (h << 6) + (h >> 2));
  }
  union {
    float f;
    uint32_t u;
  } ps;
  ps.f = face->cfg.px_size;
  h ^= (ps.u + VR_FNV_PRIME + (h << 6) + (h >> 2));
  return h;
}

static vr_status_t vr_atlas_create(vr_font_face_t* face, vr_atlas_page_t* page) {
  int w = (int)face->cfg.atlas_width;
  int h = (int)face->cfg.atlas_height;
  if (w <= 0 || h <= 0) {
    w = (int)VR_FONT_DEFAULT_ATLAS_DIMENSION;
    h = (int)VR_FONT_DEFAULT_ATLAS_DIMENSION;
  }

  size_t bpp = vr_atlas_pixel_stride(face->cfg.atlas_format);
  if (bpp == 0u) return VR_ERR_INVALID_FONT;
  size_t pixel_count = 0u;
  if (vr_atlas_pixel_count((size_t)w, (size_t)h, bpp, &pixel_count) != VR_OK) {
    return VR_ERR_OOM;
  }

  page->pixels = (uint8_t*)calloc(pixel_count, 1);
  if (!page->pixels) return VR_ERR_OOM;

  page->width = w;
  page->height = h;
  page->bytes_per_pixel = bpp;
  page->x = 0;
  page->y = 0;
  page->h = 0;
  page->row_h = 0;
  page->texture_id = 0;
  page->id = face->next_glyph_cache_id++;

  if (face->cfg.gl.create_texture) {
    face->cfg.gl.create_texture(face->cfg.gl.user, &page->texture_id, w, h, page->pixels);
  }

  vr_status_t st = vr_reserve_array(
    (void**)&face->atlases,
    &face->atlas_cap,
    face->atlas_count + 1u,
    sizeof(vr_atlas_page_t),
    VR_ATLAS_INITIAL_CAPACITY,
    1);
  if (st != VR_OK) {
    free(page->pixels);
    return st;
  }

  face->atlases[face->atlas_count++] = *page;
  return VR_OK;
}

static vr_status_t vr_pack_into_page(vr_font_face_t* face, vr_atlas_page_t* page, int required_w, int required_h, int* out_x, int* out_y) {
  int pad = (int)face->cfg.atlas_pad;
  required_w += pad;
  required_h += pad;

  if (required_w > page->width || required_h > page->height) {
    return VR_ERR_NO_SPACE;
  }

  if (page->x + required_w > page->width) {
    page->x = 0;
    page->y += page->row_h;
    page->row_h = 0;
  }
  if (page->y + required_h > page->height) {
    return VR_ERR_NO_SPACE;
  }

  if (required_h > page->row_h) {
    page->row_h = required_h;
  }

  *out_x = page->x;
  *out_y = page->y;
  page->x += required_w;
  return VR_OK;
}

vr_status_t vr_upload_bitmap_to_atlas(vr_font_face_t* face, uint32_t atlas_id, int x, int y, int w, int h, const uint8_t* bitmap) {
  size_t pid = (size_t)atlas_id;
  if (pid >= face->atlas_count) return VR_ERR_INVALID_FONT;
  vr_atlas_page_t* page = &face->atlases[pid];

  for (int row = 0; row < h; ++row) {
    size_t dst = ((size_t)(y + row) * (size_t)page->width + (size_t)x) * page->bytes_per_pixel;
    size_t src = (size_t)row * (size_t)w * page->bytes_per_pixel;
    memcpy(
      page->pixels + dst,
      bitmap + src,
      (size_t)w * page->bytes_per_pixel);
  }

  if (face->cfg.gl.update_texture) {
    face->cfg.gl.update_texture(face->cfg.gl.user, page->texture_id, x, y, w, h, bitmap);
  }

  return VR_OK;
}

vr_status_t vr_ensure_atlas(vr_font_face_t* face, int required_w, int required_h, uint32_t* out_atlas_id, int* out_x, int* out_y) {
  if (!out_atlas_id || !out_x || !out_y) return VR_ERR_INVALID_FONT;

  for (size_t i = 0; i < face->atlas_count; ++i) {
    int x, y;
    vr_status_t st = vr_pack_into_page(face, &face->atlases[i], required_w, required_h, &x, &y);
    if (st == VR_OK) {
      *out_atlas_id = (uint32_t)i;
      *out_x = x;
      *out_y = y;
      return VR_OK;
    }
  }

  if (face->atlas_count >= face->atlas_cap) {
    vr_status_t st = vr_reserve_array(
      (void**)&face->atlases,
      &face->atlas_cap,
      face->atlas_count + 1u,
      sizeof(vr_atlas_page_t),
      VR_ATLAS_INITIAL_CAPACITY,
      1);
    if (st != VR_OK) return st;
  }

  vr_atlas_page_t page;
  vr_status_t st = vr_atlas_create(face, &page);
  if (st != VR_OK) return st;
  int x = 0;
  int y = 0;
  st = vr_pack_into_page(face, &face->atlases[face->atlas_count - 1], required_w, required_h, &x, &y);
  if (st != VR_OK) return st;
  *out_atlas_id = (uint32_t)(face->atlas_count - 1);
  *out_x = x;
  *out_y = y;
  return VR_OK;
}

static vr_status_t vr_store_cache(vr_font_face_t* face, uint16_t glyph_id, vr_baked_glyph_t* out) {
  vr_status_t st = vr_reserve_array(
    (void**)&face->glyph_cache,
    &face->glyph_cache_cap,
    face->glyph_cache_count + 1u,
    sizeof(vr_glyph_cache_entry_t),
    VR_GLYPH_CACHE_INITIAL_CAPACITY,
    0);
  if (st != VR_OK) {
    return st;
  }

  vr_glyph_cache_entry_t* ce = &face->glyph_cache[face->glyph_cache_count++];
  ce->glyph_id = glyph_id;
  ce->atlas_id = out->atlas_id;
  ce->width = out->width;
  ce->height = out->height;
  ce->left = out->left;
  ce->top = out->top;
  ce->advance = out->advance;
  ce->u0 = out->atlas_u0;
  ce->v0 = out->atlas_v0;
  ce->u1 = out->atlas_u1;
  ce->v1 = out->atlas_v1;
  ce->cache_key_axis_mask = vr_hash_axes(face);
  ce->bitmap = NULL;
  return VR_OK;
}

vr_status_t vr_cache_lookup(vr_font_face_t* face, uint16_t glyph_id, vr_baked_glyph_t* out) {
  uint32_t axis = vr_hash_axes(face);
  for (size_t i = 0; i < face->glyph_cache_count; ++i) {
    vr_glyph_cache_entry_t* e = &face->glyph_cache[i];
    if (e->glyph_id != glyph_id) continue;
    if (e->cache_key_axis_mask != axis) continue;

    out->glyph = glyph_id;
    out->width = e->width;
    out->height = e->height;
    out->left = e->left;
    out->top = e->top;
    out->advance = e->advance;
    out->atlas_id = e->atlas_id;
    out->atlas_u0 = e->u0;
    out->atlas_v0 = e->v0;
    out->atlas_u1 = e->u1;
    out->atlas_v1 = e->v1;
    return VR_OK;
  }
  return VR_ERR_NOT_FOUND;
}

void vr_cache_remove(vr_font_face_t* face) {
  for (size_t i = 0; i < face->glyph_cache_count; ++i) {
    vr_glyph_cache_entry_t* e = &face->glyph_cache[i];
    if (e->bitmap) {
      free(e->bitmap);
      e->bitmap = NULL;
    }
  }

  free(face->glyph_cache);
  face->glyph_cache = NULL;
  face->glyph_cache_count = 0;
  face->glyph_cache_cap = 0;
}

vr_status_t vr_font_bake_glyph(vr_font_face_t* face, uint32_t glyph_id, vr_baked_glyph_t* out) {
  if (!face || !out) return VR_ERR_INVALID_FONT;

  if (vr_cache_lookup(face, (uint16_t)glyph_id, out) == VR_OK) {
    return VR_OK;
  }

  vr_glyph_outline_t outline;
  vr_status_t st = vr_load_glyph_outline(face, (uint16_t)glyph_id, &outline);
  if (st != VR_OK) {
    return st;
  }

  (void)vr_apply_gvar_variation(face, (uint16_t)glyph_id, &outline);

  uint8_t* bmp = NULL;
  int w = 0, h = 0, left = 0, top = 0;
  st = vr_rasterize_outline_with_mode(
    face,
    &outline,
    face->cfg.atlas_format,
    &bmp,
    &w,
    &h,
    &left,
    &top);
  if (st == VR_ERR_UNSUPPORTED) {
    out->glyph = glyph_id;
    out->width = 0;
    out->height = 0;
    out->left = 0;
    out->top = 0;
    out->advance = vr_get_glyph_advance(face, (uint16_t)glyph_id);
    out->atlas_id = 0u;
    out->atlas_u0 = 0.0f;
    out->atlas_v0 = 0.0f;
    out->atlas_u1 = 0.0f;
    out->atlas_v1 = 0.0f;
    vr_status_t cache_status = vr_store_cache(face, (uint16_t)glyph_id, out);
    if (cache_status != VR_OK) {
      vr_free_outline(&outline);
      return cache_status;
    }
    vr_free_outline(&outline);
    return VR_OK;
  }
  vr_free_outline(&outline);
  if (st != VR_OK) {
    return st;
  }

  uint32_t atlas_id = 0;
  int ux = 0;
  int uy = 0;
  st = vr_ensure_atlas(face, w, h, &atlas_id, &ux, &uy);
  if (st != VR_OK) {
    free(bmp);
    return st;
  }
  vr_atlas_page_t* page = &face->atlases[atlas_id];

  st = vr_upload_bitmap_to_atlas(face, atlas_id, ux, uy, w, h, bmp);
  if (st != VR_OK) {
    free(bmp);
    return st;
  }

  float denom_u = (float)page->width;
  float denom_v = (float)page->height;
  out->glyph = glyph_id;
  out->width = w;
  out->height = h;
  out->left = left;
  out->top = top;
  out->advance = vr_get_glyph_advance(face, (uint16_t)glyph_id);
  out->atlas_id = atlas_id;
  out->atlas_u0 = (float)ux / denom_u;
  out->atlas_v0 = (float)uy / denom_v;
  out->atlas_u1 = (float)(ux + w) / denom_u;
  out->atlas_v1 = (float)(uy + h) / denom_v;

  vr_store_cache(face, (uint16_t)glyph_id, out);
  free(bmp);

  return VR_OK;
}
