#include "vr_font_internal.h"

#include <limits.h>

static const size_t VR_ATLAS_BUCKET_INITIAL_CAP = 4u;
static const float VR_VERTEX_COLOR_ONE = 1.0f;

static size_t vr_find_atlas_index(const uint32_t* atlas_ids, size_t atlas_count, uint32_t atlas_id);

static bool vr_axis_tag_valid(const char* tag) {
  if (!tag) return false;
  for (size_t i = 0u; i < VR_AXIS_NAME_LEN; ++i) {
    if (tag[i] == '\0') return false;
  }
  return tag[VR_AXIS_NAME_LEN] == '\0';
}

static void* vr_shape_alloc(vr_font_face_t* face, size_t size) {
  return vr_alloc(face, size, 8u);
}

static void* vr_shape_calloc(vr_font_face_t* face, size_t count, size_t size) {
  return vr_calloc(face, count, size, 8u);
}

static void vr_shape_free(vr_font_face_t* face, void* ptr, size_t size) {
  vr_dealloc(face, ptr, size, 8u);
}

static vr_status_t vr_reserve_u32_size_t_pairs(vr_font_face_t* face, uint32_t** ids, size_t** counts, size_t* cap, size_t needed) {
  if (needed <= *cap) {
    return VR_OK;
  }

  size_t new_cap = *cap == 0u ? VR_ATLAS_BUCKET_INITIAL_CAP : *cap;
  while (new_cap < needed) {
    if (new_cap > (SIZE_MAX / 2u)) {
      return VR_ERR_OOM;
    }
    new_cap *= 2u;
  }

  if (new_cap > SIZE_MAX / sizeof(uint32_t) || new_cap > SIZE_MAX / sizeof(size_t)) {
    return VR_ERR_OOM;
  }

  uint32_t* new_ids = (uint32_t*)vr_shape_alloc(face, new_cap * sizeof(uint32_t));
  if (!new_ids) {
    return VR_ERR_OOM;
  }
  size_t* new_counts = (size_t*)vr_shape_alloc(face, new_cap * sizeof(size_t));
  if (!new_counts) {
    vr_shape_free(face, new_ids, new_cap * sizeof(uint32_t));
    return VR_ERR_OOM;
  }
  if (*cap > 0u) {
    vr_copy(new_ids, *ids, *cap * sizeof(uint32_t));
    vr_copy(new_counts, *counts, *cap * sizeof(size_t));
  }
  vr_shape_free(face, *ids, *cap * sizeof(uint32_t));
  vr_shape_free(face, *counts, *cap * sizeof(size_t));

  *ids = new_ids;
  *counts = new_counts;
  *cap = new_cap;
  return VR_OK;
}

static vr_status_t vr_register_atlas_id(
  vr_font_face_t* face,
  uint32_t atlas,
  uint32_t** atlas_ids,
  size_t** atlas_counts,
  size_t* atlas_count,
  size_t* atlas_cap,
  size_t* out_index) {
  size_t idx = vr_find_atlas_index(*atlas_ids, *atlas_count, atlas);
  if (idx != SIZE_MAX) {
    *out_index = idx;
    return VR_OK;
  }

  vr_status_t st = vr_reserve_u32_size_t_pairs(face, atlas_ids, atlas_counts, atlas_cap, *atlas_count + 1u);
  if (st != VR_OK) {
    return st;
  }

  (*atlas_ids)[*atlas_count] = atlas;
  (*atlas_counts)[*atlas_count] = 0u;
  *out_index = *atlas_count;
  ++(*atlas_count);
  return VR_OK;
}

static size_t vr_find_atlas_index(const uint32_t* atlas_ids, size_t atlas_count, uint32_t atlas_id) {
  for (size_t i = 0; i < atlas_count; ++i) {
    if (atlas_ids[i] == atlas_id) {
      return i;
    }
  }
  return SIZE_MAX;
}

static void vr_append_glyph_quad(vr_vertex_t* verts, size_t* cursor, float x0, float y0, float x1, float y1, const vr_baked_glyph_t* baked) {
  float tex_u0 = baked->atlas_u0;
  float tex_v0 = baked->atlas_v0;
  float tex_u1 = baked->atlas_u1;
  float tex_v1 = baked->atlas_v1;

  vr_vertex_t v0 = {x0, y0, tex_u0, tex_v0, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, baked->atlas_id};
  vr_vertex_t v1 = {x1, y0, tex_u1, tex_v0, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, baked->atlas_id};
  vr_vertex_t v2 = {x1, y1, tex_u1, tex_v1, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, baked->atlas_id};
  vr_vertex_t v3 = {x0, y1, tex_u0, tex_v1, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, VR_VERTEX_COLOR_ONE, baked->atlas_id};

  verts[*cursor] = v0;
  verts[*cursor + 1u] = v1;
  verts[*cursor + 2u] = v2;
  verts[*cursor + 3u] = v0;
  verts[*cursor + 4u] = v2;
  verts[*cursor + 5u] = v3;
  *cursor += VR_FONT_VERTICES_PER_GLYPH;
}

static void vr_free_batch_intermediate(
  vr_font_face_t* face,
  uint32_t* atlas_ids,
  size_t* atlas_counts,
  size_t atlas_cap,
  size_t* atlas_starts,
  size_t* atlas_positions,
  size_t atlas_count,
  vr_vertex_t* sorted_vertices,
  vr_vertex_t* source_vertices,
  size_t vertex_count,
  vr_vertex_atlas_range_t* ranges) {
  vr_shape_free(face, atlas_ids, atlas_cap * sizeof(*atlas_ids));
  vr_shape_free(face, atlas_counts, atlas_cap * sizeof(*atlas_counts));
  vr_shape_free(face, atlas_starts, atlas_count * sizeof(*atlas_starts));
  vr_shape_free(face, atlas_positions, atlas_count * sizeof(*atlas_positions));
  vr_shape_free(face, sorted_vertices, vertex_count * sizeof(*sorted_vertices));
  vr_shape_free(face, source_vertices, 0u);
  vr_shape_free(face, ranges, atlas_count * sizeof(*ranges));
}

vr_status_t vr_font_set_size(vr_font_face_t* face, float px_size) {
  if (!face || px_size <= 0.0f) return VR_ERR_INVALID_FONT;
  if (face->cfg.px_size != px_size) {
    vr_cache_remove(face);
  }
  face->cfg.px_size = px_size;
  return VR_OK;
}

vr_status_t vr_font_set_axis(vr_font_face_t* face, const char* tag, float user_value) {
  if (!face || !vr_axis_tag_valid(tag)) return VR_ERR_INVALID_FONT;
  for (uint16_t i = 0; i < face->fvar.axis_count && i < VR_MAX_AXES; ++i) {
    if (vr_tag_compare(face->fvar.descriptors[i].tag, tag) == 0) {
      float norm = 0.0f;
      float clamped = vr_map_axis_value(face, tag, user_value, &norm);
      face->axes[i].value = clamped;
      face->axis_values[i] = vr_apply_avar_mapping(face, i, norm);
      vr_cache_remove(face);
      return VR_OK;
    }
  }
  return VR_ERR_NOT_FOUND;
}

int vr_font_axis_count(const vr_font_face_t* face) {
  if (!face) return 0;
  return (int)face->fvar.axis_count;
}

const vr_font_axis_t* vr_font_axes(const vr_font_face_t* face) {
  if (!face) return NULL;
  return face->axes;
}

vr_status_t vr_font_shape_text(
  vr_font_face_t* face,
  const uint32_t* codepoints,
  size_t codepoint_count,
  vr_shaped_glyph_t** out_glyphs,
  size_t* out_count) {
  if (!face || !codepoints || !out_glyphs || !out_count) return VR_ERR_INVALID_FONT;
  if (codepoint_count == 0) {
    *out_glyphs = NULL;
    *out_count = 0;
    return VR_OK;
  }

  vr_shaped_glyph_t* g = (vr_shaped_glyph_t*)vr_shape_calloc(face, codepoint_count, sizeof(vr_shaped_glyph_t));
  if (!g) return VR_ERR_OOM;

  uint16_t prev_gid = 0;
  float scale = (face->units_per_em != 0) ? (face->cfg.px_size / (float)face->units_per_em) : 1.0f;
  for (size_t i = 0; i < codepoint_count; ++i) {
    uint16_t gid = vr_find_glyph_id(face, codepoints[i]);
    g[i].glyph = gid;
    g[i].codepoint = codepoints[i];
    g[i].cluster = (uint32_t)i;
    g[i].x_offset = 0.0f;
    g[i].y_offset = 0.0f;
    g[i].x_advance = vr_get_glyph_advance(face, gid);
    if (i > 0 && prev_gid != 0) {
      float kern = vr_find_kern_adjust(face, prev_gid, gid) * scale;
      g[i].x_offset += kern;
      g[i].x_advance += kern;
    }
    prev_gid = gid;
  }

  *out_glyphs = g;
  *out_count = codepoint_count;
  return VR_OK;
}

vr_status_t vr_font_free_shaped(vr_font_face_t* face, vr_shaped_glyph_t* glyphs, size_t glyph_count) {
  if (!glyphs) return VR_OK;
  if (!face) return VR_ERR_INVALID_FONT;
  if (glyph_count > SIZE_MAX / sizeof(*glyphs)) return VR_ERR_INVALID_FONT;
  vr_shape_free(face, glyphs, glyph_count * sizeof(*glyphs));
  return VR_OK;
}

vr_status_t vr_font_build_vertex_batch(
  vr_font_face_t* face,
  const vr_shaped_glyph_t* shaped,
  size_t shaped_count,
  float x,
  float y,
  vr_vertex_t** out_vertices,
  size_t* out_vertex_count) {
  if (!face || !out_vertices || !out_vertex_count) return VR_ERR_INVALID_FONT;
  if (shaped_count == 0) {
    *out_vertices = NULL;
    *out_vertex_count = 0;
    return VR_OK;
  }
  if (!shaped) return VR_ERR_INVALID_FONT;

  if (shaped_count > SIZE_MAX / VR_FONT_VERTICES_PER_GLYPH) return VR_ERR_OOM;
  size_t vertex_capacity = shaped_count * VR_FONT_VERTICES_PER_GLYPH;
  vr_vertex_t* verts = (vr_vertex_t*)vr_shape_calloc(face, vertex_capacity, sizeof(vr_vertex_t));
  if (!verts) return VR_ERR_OOM;

  float pen_x = x;
  float pen_y = y;
  size_t v = 0;

  for (size_t i = 0; i < shaped_count; ++i) {
    vr_baked_glyph_t baked = {0};
    vr_status_t s = vr_font_bake_glyph(face, shaped[i].glyph, &baked);
    if (s != VR_OK) {
      vr_shape_free(face, verts, vertex_capacity * sizeof(*verts));
      return s;
    }
    if (baked.width <= 0 || baked.height <= 0) {
      pen_x += shaped[i].x_advance;
      continue;
    }

    float ox = pen_x + shaped[i].x_offset + baked.left;
    float oy = pen_y + shaped[i].y_offset - baked.top;

    float x0 = ox;
    float y0 = oy;
    float x1 = ox + baked.width;
    float y1 = oy + baked.height;

    vr_append_glyph_quad(verts, &v, x0, y0, x1, y1, &baked);

    pen_x += shaped[i].x_advance;
  }

  if (v == 0u) {
    vr_shape_free(face, verts, vertex_capacity * sizeof(*verts));
    *out_vertices = NULL;
    *out_vertex_count = 0u;
    return VR_OK;
  }

  if (v < vertex_capacity) {
    vr_vertex_t* trimmed = (vr_vertex_t*)vr_shape_alloc(face, v * sizeof(*trimmed));
    if (!trimmed) {
      vr_shape_free(face, verts, vertex_capacity * sizeof(*verts));
      return VR_ERR_OOM;
    }
    vr_copy(trimmed, verts, v * sizeof(*trimmed));
    vr_shape_free(face, verts, vertex_capacity * sizeof(*verts));
    verts = trimmed;
  }

  *out_vertices = verts;
  *out_vertex_count = v;
  return VR_OK;
}

vr_status_t vr_font_build_vertex_batches_by_atlas(
  vr_font_face_t* face,
  const vr_shaped_glyph_t* shaped,
  size_t shaped_count,
  float x,
  float y,
  vr_vertex_t** out_vertices,
  size_t* out_vertex_count,
  vr_vertex_atlas_range_t** out_ranges,
  size_t* out_range_count) {
  if (!face || !out_vertices || !out_vertex_count || !out_ranges || !out_range_count) {
    return VR_ERR_INVALID_FONT;
  }
  if (shaped_count == 0) {
    *out_vertices = NULL;
    *out_vertex_count = 0;
    *out_ranges = NULL;
    *out_range_count = 0;
    return VR_OK;
  }
  if (!shaped) {
    return VR_ERR_INVALID_FONT;
  }

  vr_vertex_t* source_vertices = NULL;
  size_t source_vertex_count = 0;
  vr_status_t st = vr_font_build_vertex_batch(face, shaped, shaped_count, x, y, &source_vertices, &source_vertex_count);
  if (st != VR_OK) {
    return st;
  }
  if (source_vertex_count == 0) {
    vr_shape_free(face, source_vertices, 0u);
    *out_vertices = NULL;
    *out_vertex_count = 0;
    *out_ranges = NULL;
    *out_range_count = 0;
    return VR_OK;
  }

  uint32_t* atlas_ids = NULL;
  size_t* atlas_counts = NULL;
  size_t atlas_count = 0;
  size_t atlas_cap = 0;
  size_t* atlas_starts = NULL;
  size_t* atlas_positions = NULL;
  vr_vertex_t* sorted_vertices = NULL;
  vr_vertex_atlas_range_t* ranges = NULL;

  for (size_t i = 0; i < source_vertex_count; ++i) {
    uint32_t atlas = source_vertices[i].atlas_id;
    size_t idx = 0u;
    st = vr_register_atlas_id(face, atlas, &atlas_ids, &atlas_counts, &atlas_count, &atlas_cap, &idx);
    if (st != VR_OK) {
      vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, sorted_vertices, source_vertices, source_vertex_count, ranges);
      return st;
    }
    atlas_counts[idx] += 1u;
  }

  atlas_starts = (size_t*)vr_shape_calloc(face, atlas_count, sizeof(size_t));
  if (!atlas_starts) {
    st = VR_ERR_OOM;
    vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, sorted_vertices, source_vertices, source_vertex_count, ranges);
    return st;
  }

  size_t cursor = 0;
  for (size_t i = 0; i < atlas_count; ++i) {
    atlas_starts[i] = cursor;
    cursor += atlas_counts[i];
  }

  atlas_positions = (size_t*)vr_shape_alloc(face, atlas_count * sizeof(size_t));
  if (!atlas_positions) {
    st = VR_ERR_OOM;
    vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, sorted_vertices, source_vertices, source_vertex_count, ranges);
    return st;
  }

  for (size_t i = 0; i < atlas_count; ++i) {
    atlas_positions[i] = atlas_starts[i];
  }

  sorted_vertices = (vr_vertex_t*)vr_shape_alloc(face, source_vertex_count * sizeof(vr_vertex_t));
  if (!sorted_vertices) {
    st = VR_ERR_OOM;
    vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, sorted_vertices, source_vertices, source_vertex_count, ranges);
    return st;
  }

  for (size_t i = 0; i < source_vertex_count; ++i) {
    uint32_t atlas = source_vertices[i].atlas_id;
    size_t idx = vr_find_atlas_index(atlas_ids, atlas_count, atlas);
    if (idx == SIZE_MAX) {
      st = VR_ERR_INVALID_FONT;
      vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, sorted_vertices, source_vertices, source_vertex_count, ranges);
      return st;
    }
    sorted_vertices[atlas_positions[idx]++] = source_vertices[i];
  }

  ranges = (vr_vertex_atlas_range_t*)vr_shape_calloc(face, atlas_count, sizeof(vr_vertex_atlas_range_t));
  if (!ranges) {
    st = VR_ERR_OOM;
    vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, sorted_vertices, source_vertices, source_vertex_count, ranges);
    return st;
  }

  for (size_t i = 0; i < atlas_count; ++i) {
    ranges[i].atlas_id = atlas_ids[i];
    ranges[i].start_vertex = atlas_starts[i];
    ranges[i].vertex_count = atlas_counts[i];
  }

  vr_free_batch_intermediate(face, atlas_ids, atlas_counts, atlas_cap, atlas_starts, atlas_positions, atlas_count, NULL, source_vertices, source_vertex_count, NULL);

  *out_vertices = sorted_vertices;
  *out_vertex_count = source_vertex_count;
  *out_ranges = ranges;
  *out_range_count = atlas_count;
  return VR_OK;
}

vr_status_t vr_font_free_vertices(vr_font_face_t* face, vr_vertex_t* verts, size_t vertex_count) {
  if (!verts) return VR_OK;
  if (!face) return VR_ERR_INVALID_FONT;
  if (vertex_count > SIZE_MAX / sizeof(*verts)) return VR_ERR_INVALID_FONT;
  vr_shape_free(face, verts, vertex_count * sizeof(*verts));
  return VR_OK;
}

vr_status_t vr_font_free_vertex_atlas_ranges(vr_font_face_t* face, vr_vertex_atlas_range_t* ranges, size_t range_count) {
  if (!ranges) return VR_OK;
  if (!face) return VR_ERR_INVALID_FONT;
  if (range_count > ((size_t)-1) / sizeof(*ranges)) return VR_ERR_INVALID_FONT;
  vr_dealloc(face, ranges, range_count * sizeof(*ranges), 8u);
  return VR_OK;
}

uint32_t vr_font_last_error(const vr_font_face_t* face) {
  return face ? face->last_error : VR_ERR_INVALID_FONT;
}

size_t vr_font_atlas_count(const vr_font_face_t* face) {
  if (!face) return 0;
  return face->atlas_count;
}

vr_status_t vr_font_atlas_texture(const vr_font_face_t* face, uint32_t atlas_id, uint32_t* out_texture) {
  if (!face || !out_texture) return VR_ERR_INVALID_FONT;
  if (atlas_id >= face->atlas_count) return VR_ERR_INVALID_FONT;
  *out_texture = face->atlases[atlas_id].texture_id;
  return VR_OK;
}
