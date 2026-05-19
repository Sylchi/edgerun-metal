#include "vr_font_utils_internal.h"

vr_status_t vr_parse_table_directory(vr_font_face_t* face) {
  const uint8_t* p = face->file_data;
  if (face->file_size < 12) {
    return VR_ERR_INVALID_FONT;
  }

  uint32_t scalar_type = vr_u32(p);
  uint16_t numTables = vr_u16(p + 4);
  if (scalar_type != VR_SFNT_SCALAR_TTF && scalar_type != VR_SFNT_SCALAR_OTTO && scalar_type != VR_SFNT_SCALAR_TTCF) {
    return VR_ERR_INVALID_FONT;
  }

  face->table_count = numTables;
  face->tables = (vr_table_record_t*)vr_face_alloc_array(face, numTables, sizeof(vr_table_record_t), 8u);
  if (!face->tables) {
    return VR_ERR_OOM;
  }

  const uint8_t* rec = p + 12;
  for (size_t i = 0; i < numTables; ++i) {
    if ((size_t)(rec - p) + 16 > face->file_size) {
      return VR_ERR_INVALID_FONT;
    }
    face->tables[i].tag = vr_tag(rec);
    face->tables[i].checksum = vr_u32(rec + 4);
    face->tables[i].offset = vr_u32(rec + 8);
    face->tables[i].length = vr_u32(rec + 12);
    rec += 16;
  }

  (void)face->table_count;
  (void)face->tables;
  return VR_OK;
}

const vr_table_record_t* vr_find_table(const vr_font_face_t* face, uint32_t tag) {
  for (size_t i = 0; i < face->table_count; ++i) {
    if (face->tables[i].tag == tag) {
      return &face->tables[i];
    }
  }
  return NULL;
}

void vr_set_axis_data(vr_font_face_t* face) {
  for (uint16_t i = 0; i < face->fvar.axis_count && i < VR_MAX_AXES; ++i) {
    const char* src = face->fvar.descriptors[i].tag;
    face->axes[i].name[0] = src[0];
    face->axes[i].name[1] = src[1];
    face->axes[i].name[2] = src[2];
    face->axes[i].name[3] = src[3];
    face->axes[i].name[4] = '\0';
    face->axes[i].min_value = face->fvar.descriptors[i].min;
    face->axes[i].default_value = face->fvar.descriptors[i].default_value;
    face->axes[i].max_value = face->fvar.descriptors[i].max;
    face->axes[i].value = face->fvar.descriptors[i].default_value;
  }
}

vr_status_t vr_parse_head(vr_font_face_t* face, const uint8_t* p, size_t len) {
  if (!p || len < 54u) {
    return VR_ERR_INVALID_FONT;
  }
  face->head = (uint8_t*)p;

  uint16_t units = vr_u16(p + 18);
  int16_t xMin = vr_i16(p + 36);
  int16_t yMin = vr_i16(p + 38);
  int16_t xMax = vr_i16(p + 40);
  int16_t yMax = vr_i16(p + 42);
  int16_t index_to_loc_format = (int16_t)vr_i16(p + 50);

  face->units_per_em = units;
  face->yMin = yMin;
  face->yMax = yMax;
  face->index_to_loc_format = index_to_loc_format;
  (void)xMin;
  (void)xMax;
  return VR_OK;
}

vr_status_t vr_parse_maxp(vr_font_face_t* face, const uint8_t* p, size_t len) {
  (void)len;
  if (!p) return VR_ERR_INVALID_FONT;
  face->maxp = (uint8_t*)p;
  face->maxp_num_glyphs = vr_u16(p + 4);
  face->num_glyphs = (uint16_t)face->maxp_num_glyphs;
  return VR_OK;
}

vr_status_t vr_parse_hhea(vr_font_face_t* face, const uint8_t* p, size_t len) {
  if (!p || len < 36u) return VR_ERR_INVALID_FONT;
  face->hhea = (uint8_t*)p;
  face->ascender = vr_i16(p + 4);
  face->descender = vr_i16(p + 6);
  face->line_gap = vr_i16(p + 8);
  face->num_h_metrics = vr_u16(p + 34);
  return VR_OK;
}

vr_status_t vr_parse_loca(vr_font_face_t* face) {
  const vr_table_record_t* loc = vr_find_table(face, VR_TABLE_TAG('l','o','c','a'));
  if (!loc) return VR_ERR_NOT_FOUND;
  if (loc->offset + loc->length > face->file_size) return VR_ERR_INVALID_FONT;

  if (loc->length == 0 || face->num_glyphs == 0) {
    return VR_ERR_INVALID_FONT;
  }

  size_t count = face->num_glyphs + 1;
  face->loca_offsets = (uint32_t*)vr_face_alloc_array(face, count, sizeof(uint32_t), 4u);
  if (!face->loca_offsets) return VR_ERR_OOM;

  const uint8_t* p = face->file_data + loc->offset;
  if (face->index_to_loc_format == 0) {
    for (size_t i = 0; i < count; ++i) {
      uint16_t v = vr_u16(p + i * 2);
      face->loca_offsets[i] = (uint32_t)v * 2u;
    }
  } else {
    for (size_t i = 0; i < count; ++i) {
      face->loca_offsets[i] = vr_u32(p + i * 4);
    }
  }

  return VR_OK;
}

float vr_utils_f2dot14_to_float(uint16_t v) {
  return (float)(int16_t)v / 16384.0f;
}

float vr_fixed_to_float(uint32_t v) {
  return (float)(int32_t)v / 65536.0f;
}

uint16_t vr_get_glyph_h_advance_units(const vr_font_face_t* face, uint16_t glyph_id) {
  if (!face || !face->hmtx || face->num_h_metrics == 0) return 0;
  if (glyph_id < face->num_h_metrics) {
    return vr_u16(face->hmtx + ((size_t)glyph_id * 4u));
  }
  if (glyph_id < face->maxp_num_glyphs) {
    return vr_u16(face->hmtx + ((size_t)(face->num_h_metrics - 1u) * 4u));
  }
  return 0;
}

int16_t vr_get_glyph_h_lsb_units(const vr_font_face_t* face, uint16_t glyph_id) {
  if (!face || !face->hmtx || face->num_h_metrics == 0) return 0;
  if (glyph_id < face->num_h_metrics) {
    return vr_i16(face->hmtx + ((size_t)glyph_id * 4u) + 2u);
  }
  if (glyph_id < face->maxp_num_glyphs) {
    size_t index = (size_t)face->num_h_metrics * 4u + ((size_t)(glyph_id - face->num_h_metrics) * 2u);
    return vr_i16(face->hmtx + index);
  }
  return 0;
}

vr_status_t vr_parse_font(vr_font_face_t* face) {
  vr_status_t st = vr_parse_table_directory(face);
  if (st != VR_OK) return st;

  const vr_table_record_t* head = vr_find_table(face, VR_TABLE_TAG('h','e','a','d'));
  if (!head || head->offset + head->length > face->file_size) return VR_ERR_INVALID_FONT;
  st = vr_parse_head(face, face->file_data + head->offset, head->length);
  if (st != VR_OK) return st;

  const vr_table_record_t* maxp = vr_find_table(face, VR_TABLE_TAG('m','a','x','p'));
  if (!maxp || maxp->offset + maxp->length > face->file_size) return VR_ERR_INVALID_FONT;
  st = vr_parse_maxp(face, face->file_data + maxp->offset, maxp->length);
  if (st != VR_OK) return st;

  const vr_table_record_t* hhea = vr_find_table(face, VR_TABLE_TAG('h','h','e','a'));
  if (!hhea || hhea->offset + hhea->length > face->file_size) return VR_ERR_INVALID_FONT;
  st = vr_parse_hhea(face, face->file_data + hhea->offset, hhea->length);
  if (st != VR_OK) return st;

  const vr_table_record_t* hmtx = vr_find_table(face, VR_TABLE_TAG('h','m','t','x'));
  if (!hmtx || hmtx->offset + hmtx->length > face->file_size) {
    return VR_ERR_NOT_FOUND;
  }
  face->hmtx = (uint8_t*)face->file_data + hmtx->offset;

  const vr_table_record_t* glyf = vr_find_table(face, VR_TABLE_TAG('g','l','y','f'));
  if (!glyf || glyf->offset + glyf->length > face->file_size) return VR_ERR_INVALID_FONT;
  face->glyf = (uint8_t*)face->file_data + glyf->offset;

  st = vr_parse_loca(face);
  if (st != VR_OK) return st;

  st = vr_parse_cmap(face);
  if (st != VR_OK) return st;

  st = vr_parse_kern(face);
  if (st != VR_OK && st != VR_ERR_NOT_FOUND && st != VR_ERR_UNSUPPORTED) return st;

  st = vr_read_fvar(face);
  if (st != VR_OK) return st;
  st = vr_parse_avar(face);
  if (st != VR_OK && st != VR_ERR_NOT_FOUND) return st;
  st = vr_parse_gvar(face);
  if (st != VR_OK && st != VR_ERR_NOT_FOUND) return st;

  for (uint16_t i = 0; i < face->fvar.axis_count && i < VR_MAX_AXES; ++i) {
    face->axis_values[i] = vr_apply_avar_mapping(face, i, 0.0f);
  }

  if (face->cfg.px_size <= 0.0f) {
    face->cfg.px_size = VR_FONT_PARSER_DEFAULT_PX_SIZE;
  }

  if (face->cfg.atlas_width == 0) {
    face->cfg.atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  }
  if (face->cfg.atlas_height == 0) {
    face->cfg.atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  }
  if (face->cfg.atlas_pad == 0) {
    face->cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  }
  if (face->cfg.atlas_format == VR_FONT_ATLAS_FORMAT_UNSPECIFIED) {
    face->cfg.atlas_format = VR_FONT_DEFAULT_ATLAS_FORMAT;
  }

  return VR_OK;
}
