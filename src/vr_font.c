#include "vr_font_internal.h"

#include <string.h>

vr_status_t vr_font_face_create(vr_font_face_t** out, const char* path, const vr_font_config_t* cfg) {
  if (!out || !path || !cfg) return VR_ERR_INVALID_FONT;
  *out = NULL;

  vr_font_face_t* face = (vr_font_face_t*)calloc(1, sizeof(vr_font_face_t));
  if (!face) return VR_ERR_OOM;

  face->cfg = *cfg;
  if (face->cfg.atlas_width == 0) face->cfg.atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  if (face->cfg.atlas_height == 0) face->cfg.atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  if (face->cfg.atlas_pad == 0) face->cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  if (face->cfg.atlas_format == VR_FONT_ATLAS_FORMAT_UNSPECIFIED) {
    face->cfg.atlas_format = VR_FONT_DEFAULT_ATLAS_FORMAT;
  }

  vr_status_t st = vr_read_file(path, &face->file_data, &face->file_size);
  if (st != VR_OK) {
    free(face);
    return st;
  }

  st = vr_parse_font(face);
  if (st != VR_OK) {
    vr_font_face_destroy(face);
    return st;
  }

  face->next_glyph_cache_id = 1;
  *out = face;
  return VR_OK;
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
      free(face->glyph_cache[i].bitmap);
    }
    free(face->glyph_cache);
  }

  if (face->atlases) {
    for (size_t i = 0; i < face->atlas_count; ++i) {
      if (face->cfg.gl.destroy_texture && face->atlases[i].texture_id) {
        face->cfg.gl.destroy_texture(face->cfg.gl.user, face->atlases[i].texture_id);
      }
      free(face->atlases[i].pixels);
    }
    free(face->atlases);
  }

  if (face->cmap.format == 4) {
    free(face->cmap.u.format4.end_code);
    free(face->cmap.u.format4.start_code);
    free(face->cmap.u.format4.id_delta);
    free(face->cmap.u.format4.id_range_offset);
    free(face->cmap.u.format4.glyph_id_array);
  }
  if (face->cmap.format == 12) {
    free(face->cmap.u.format12.start_char_code);
    free(face->cmap.u.format12.end_char_code);
    free(face->cmap.u.format12.start_glyph_id);
  }
  free(face->kern.pairs);
  free(face->gvar.shared_tuples);
  free(face->gvar.glyph_variation_offsets);
  free(face->avar.segment_count);
  free(face->avar.segment_offset);
  free(face->avar.map_from);
  free(face->avar.map_to);

  free(face->cmap_offsets);
  free(face->tables);
  free(face->loca_offsets);
  free(face->file_data);
  free(face);
}
