#include "vr_font_internal.h"

static void* vr_config_alloc(vr_font_allocator_t allocator, size_t size, size_t align) {
  if (!vr_allocator_valid(allocator) || size == 0u) return NULL;
  return allocator.alloc(allocator.user, size, align);
}

static void vr_config_free(vr_font_allocator_t allocator, void* ptr, size_t size, size_t align) {
  if (!ptr || !vr_allocator_valid(allocator)) return;
  allocator.free(allocator.user, ptr, size, align);
}

vr_status_t vr_font_face_create_from_memory(vr_font_face_t** out, const void* data, size_t size, const vr_font_config_t* cfg) {
  if (!out || !data || size == 0u || !cfg || !vr_allocator_valid(cfg->allocator)) return VR_ERR_INVALID_FONT;
  *out = NULL;

  vr_font_face_t* face = (vr_font_face_t*)vr_config_alloc(cfg->allocator, sizeof(vr_font_face_t), 8u);
  if (!face) return VR_ERR_OOM;
  vr_zero(face, sizeof(*face));

  face->cfg = *cfg;
  face->allocator = cfg->allocator;
  if (face->cfg.atlas_width == 0) face->cfg.atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  if (face->cfg.atlas_height == 0) face->cfg.atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  if (face->cfg.atlas_pad == 0) face->cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  if (face->cfg.atlas_format == VR_FONT_ATLAS_FORMAT_UNSPECIFIED) {
    face->cfg.atlas_format = VR_FONT_DEFAULT_ATLAS_FORMAT;
  }

  face->file_data = (uint8_t*)vr_alloc(face, size, 1u);
  if (!face->file_data) {
    vr_config_free(cfg->allocator, face, sizeof(*face), 8u);
    return VR_ERR_OOM;
  }
  vr_copy(face->file_data, data, size);
  face->file_size = size;

  vr_status_t st = vr_parse_font(face);
  if (st != VR_OK) {
    vr_font_face_destroy(face);
    return st;
  }

  face->next_glyph_cache_id = 1;
  *out = face;
  return VR_OK;
}

vr_status_t vr_font_face_create(vr_font_face_t** out, const char* path, const vr_font_config_t* cfg) {
  (void)path;
  (void)cfg;
  if (out) *out = NULL;
  return VR_ERR_UNSUPPORTED;
}

vr_status_t vr_font_clear_cache(vr_font_face_t* face) {
  if (!face) return VR_ERR_INVALID_FONT;
  vr_cache_remove(face);
  return VR_OK;
}

void vr_font_face_destroy(vr_font_face_t* face) {
  if (!face) return;

  if (face->glyph_cache) {
    for (size_t i = 0; i < face->glyph_cache_count; ++i) {
      vr_dealloc(face, face->glyph_cache[i].bitmap, (size_t)face->glyph_cache[i].width * (size_t)face->glyph_cache[i].height * face->atlases[face->glyph_cache[i].atlas_id].bytes_per_pixel, 1u);
    }
    vr_dealloc(face, face->glyph_cache, face->glyph_cache_cap * sizeof(*face->glyph_cache), 8u);
  }

  if (face->atlases) {
    for (size_t i = 0; i < face->atlas_count; ++i) {
      if (face->cfg.gl.destroy_texture && face->atlases[i].texture_id) {
        face->cfg.gl.destroy_texture(face->cfg.gl.user, face->atlases[i].texture_id);
      }
      vr_dealloc(face, face->atlases[i].pixels, (size_t)face->atlases[i].width * (size_t)face->atlases[i].height * face->atlases[i].bytes_per_pixel, VR_FONT_ALIGN_U8);
    }
    vr_dealloc(face, face->atlases, face->atlas_cap * sizeof(*face->atlases), VR_FONT_ALIGN_PTR);
  }

  if (face->cmap.format == VR_FONT_CMAP_FORMAT_4) {
    size_t seg_count = (size_t)face->cmap.u.format4.seg_count_x2 / 2u;
    vr_dealloc(face, face->cmap.u.format4.end_code, seg_count * sizeof(*face->cmap.u.format4.end_code), VR_FONT_ALIGN_U16);
    vr_dealloc(face, face->cmap.u.format4.start_code, seg_count * sizeof(*face->cmap.u.format4.start_code), VR_FONT_ALIGN_U16);
    vr_dealloc(face, face->cmap.u.format4.id_delta, seg_count * sizeof(*face->cmap.u.format4.id_delta), VR_FONT_ALIGN_U16);
    vr_dealloc(face, face->cmap.u.format4.id_range_offset, seg_count * sizeof(*face->cmap.u.format4.id_range_offset), VR_FONT_ALIGN_U16);
    vr_dealloc(face, face->cmap.u.format4.glyph_id_array, face->cmap.u.format4.glyph_id_array_count * sizeof(*face->cmap.u.format4.glyph_id_array), VR_FONT_ALIGN_U16);
  }
  if (face->cmap.format == VR_FONT_CMAP_FORMAT_12) {
    size_t groups = face->cmap.u.format12.n_groups;
    vr_dealloc(face, face->cmap.u.format12.start_char_code, groups * sizeof(*face->cmap.u.format12.start_char_code), VR_FONT_ALIGN_U32);
    vr_dealloc(face, face->cmap.u.format12.end_char_code, groups * sizeof(*face->cmap.u.format12.end_char_code), VR_FONT_ALIGN_U32);
    vr_dealloc(face, face->cmap.u.format12.start_glyph_id, groups * sizeof(*face->cmap.u.format12.start_glyph_id), VR_FONT_ALIGN_U32);
  }
  vr_dealloc(face, face->kern.pairs, face->kern.cap * sizeof(*face->kern.pairs), VR_FONT_ALIGN_PTR);
  vr_dealloc(face, face->gvar.shared_tuples, (size_t)face->gvar.shared_tuple_count * (size_t)face->gvar.axis_count * sizeof(*face->gvar.shared_tuples), VR_FONT_ALIGN_PTR);
  vr_dealloc(face, face->gvar.glyph_variation_offsets, ((size_t)face->gvar.glyph_count + 1u) * sizeof(*face->gvar.glyph_variation_offsets), VR_FONT_ALIGN_U32);
  vr_dealloc(face, face->avar.segment_count, (size_t)face->avar.axis_count * sizeof(*face->avar.segment_count), VR_FONT_ALIGN_U16);
  vr_dealloc(face, face->avar.segment_offset, (size_t)face->avar.axis_count * sizeof(*face->avar.segment_offset), VR_FONT_ALIGN_PTR);
  vr_dealloc(face, face->avar.map_from, face->avar.total_segment_count * sizeof(*face->avar.map_from), VR_FONT_ALIGN_PTR);
  vr_dealloc(face, face->avar.map_to, face->avar.total_segment_count * sizeof(*face->avar.map_to), VR_FONT_ALIGN_PTR);

  vr_dealloc(face, face->cmap_offsets, face->cmap_offset_count * sizeof(*face->cmap_offsets), VR_FONT_ALIGN_U32);
  vr_dealloc(face, face->tables, face->table_count * sizeof(*face->tables), VR_FONT_ALIGN_PTR);
  vr_dealloc(face, face->loca_offsets, ((size_t)face->num_glyphs + 1u) * sizeof(*face->loca_offsets), VR_FONT_ALIGN_U32);
  vr_dealloc(face, face->file_data, face->file_size, VR_FONT_ALIGN_U8);
  vr_config_free(face->allocator, face, sizeof(*face), VR_FONT_ALIGN_PTR);
}
