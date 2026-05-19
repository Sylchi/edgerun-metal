#include "vr_font_utils_internal.h"

vr_status_t vr_parse_cmap_format4(
  vr_font_face_t* face,
  const uint8_t* sub,
  uint16_t length) {
  face->cmap.format = VR_CMAP_FORMAT_4;
  face->cmap.length = length;
  face->cmap.language = vr_u16(sub + 4);
  uint16_t seg_count_x2 = vr_u16(sub + 6);
  face->cmap.u.format4.seg_count_x2 = seg_count_x2;

  uint16_t seg_count = (uint16_t)(seg_count_x2 / 2u);
  const uint8_t* q = sub + 14;
  size_t headers = (size_t)4u * 2u * (size_t)seg_count;
  if ((size_t)length < (size_t)(q - sub) + headers) return VR_ERR_INVALID_FONT;

  uint16_t* end_code = (uint16_t*)vr_face_alloc_array(face, seg_count, sizeof(uint16_t), 2u);
  uint16_t* start_code = (uint16_t*)vr_face_alloc_array(face, seg_count, sizeof(uint16_t), 2u);
  int16_t* id_delta = (int16_t*)vr_face_alloc_array(face, seg_count, sizeof(int16_t), 2u);
  uint16_t* id_range_offset = (uint16_t*)vr_face_alloc_array(face, seg_count, sizeof(uint16_t), 2u);
  if (!end_code || !start_code || !id_delta || !id_range_offset) {
    vr_face_free_array(face, end_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, start_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, id_delta, seg_count, sizeof(int16_t), 2u);
    vr_face_free_array(face, id_range_offset, seg_count, sizeof(uint16_t), 2u);
    return VR_ERR_OOM;
  }

  for (uint16_t i = 0; i < seg_count; ++i) {
    end_code[i] = vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u + 2u;
  for (uint16_t i = 0; i < seg_count; ++i) {
    start_code[i] = vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u;
  for (uint16_t i = 0; i < seg_count; ++i) {
    id_delta[i] = (int16_t)vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u;
  for (uint16_t i = 0; i < seg_count; ++i) {
    id_range_offset[i] = vr_u16(q + i * 2u);
  }
  q += (size_t)seg_count * 2u;

  size_t remaining = (size_t)length - (size_t)(q - sub);
  size_t glyph_count = remaining / 2u;
  uint16_t* glyph_id_array = NULL;
  if (glyph_count > 0u) {
    glyph_id_array = (uint16_t*)vr_face_alloc_array(face, glyph_count, sizeof(uint16_t), 2u);
  }
  if (glyph_count > 0u && !glyph_id_array) {
    vr_face_free_array(face, end_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, start_code, seg_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, id_delta, seg_count, sizeof(int16_t), 2u);
    vr_face_free_array(face, id_range_offset, seg_count, sizeof(uint16_t), 2u);
    return VR_ERR_OOM;
  }
  for (size_t i = 0; i < glyph_count; ++i) {
    glyph_id_array[i] = vr_u16(q + i * 2u);
  }

  face->cmap.u.format4.end_code = end_code;
  face->cmap.u.format4.start_code = start_code;
  face->cmap.u.format4.id_delta = id_delta;
  face->cmap.u.format4.id_range_offset = id_range_offset;
  face->cmap.u.format4.glyph_id_array_count = glyph_count;
  face->cmap.u.format4.glyph_id_array = glyph_id_array;
  return VR_OK;
}

vr_status_t vr_parse_cmap_format12(
  vr_font_face_t* face,
  const uint8_t* sub,
  uint16_t length) {
  face->cmap.format = VR_CMAP_FORMAT_12;
  face->cmap.language = vr_u16(sub + 4);

  if (length < 16u) return VR_ERR_INVALID_FONT;
  uint32_t n_groups = vr_u32(sub + 12);
  const uint8_t* q = sub + 16;
  size_t needed = 16u + (size_t)n_groups * 12u;
  if (needed > (size_t)length) return VR_ERR_INVALID_FONT;

  uint32_t* start_char = NULL;
  uint32_t* end_char = NULL;
  uint32_t* start_glyph = NULL;
  if (n_groups > 0u) {
    start_char = (uint32_t*)vr_face_alloc_array(face, n_groups, sizeof(uint32_t), 4u);
    end_char = (uint32_t*)vr_face_alloc_array(face, n_groups, sizeof(uint32_t), 4u);
    start_glyph = (uint32_t*)vr_face_alloc_array(face, n_groups, sizeof(uint32_t), 4u);
  }
  if (n_groups > 0u && (!start_char || !end_char || !start_glyph)) {
    vr_face_free_array(face, start_char, n_groups, sizeof(uint32_t), 4u);
    vr_face_free_array(face, end_char, n_groups, sizeof(uint32_t), 4u);
    vr_face_free_array(face, start_glyph, n_groups, sizeof(uint32_t), 4u);
    return VR_ERR_OOM;
  }

  for (uint32_t i = 0; i < n_groups; ++i) {
    start_char[i] = vr_u32(q + i * 12u);
    end_char[i] = vr_u32(q + i * 12u + 4u);
    start_glyph[i] = vr_u32(q + i * 12u + 8u);
  }

  face->cmap.u.format12.n_groups = n_groups;
  face->cmap.u.format12.start_char_code = start_char;
  face->cmap.u.format12.end_char_code = end_char;
  face->cmap.u.format12.start_glyph_id = start_glyph;
  return VR_OK;
}

uint32_t vr_find_preferred_cmap_offset(const vr_font_face_t* face, const uint8_t* p) {
  uint16_t count = vr_u16(p + 2);
  const uint8_t* enc = p + 4;
  uint32_t selected = 0u;
  bool preferred_found = false;

  for (uint16_t i = 0; i < count; ++i) {
    uint16_t platform_id = vr_u16(enc + (size_t)i * 8u);
    uint32_t offset = vr_u32(enc + (size_t)i * 8u + 4u);
    face->cmap_offsets[i] = offset;
    if (!preferred_found && (platform_id == VR_CMAP_PLATFORM_ID_WINDOWS || platform_id == VR_CMAP_PLATFORM_ID_UNICODE)) {
      selected = offset;
      preferred_found = true;
    }
  }
  if (!preferred_found && face->cmap_offset_count > 0) {
    selected = face->cmap_offsets[0];
  }
  return selected;
}

vr_status_t vr_parse_cmap(vr_font_face_t* face) {
  const vr_table_record_t* cmap = vr_find_table(face, VR_TABLE_TAG('c','m','a','p'));
  if (!cmap) {
    return VR_ERR_NOT_FOUND;
  }
  if (cmap->offset + cmap->length > face->file_size) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* p = face->file_data + cmap->offset;
  uint16_t version = vr_u16(p);
  if (version != VR_CMAP_TABLE_VERSION) {
    return VR_ERR_INVALID_FONT;
  }
  uint16_t numTables = vr_u16(p + 2);

  face->cmap_offset_count = numTables;
  face->cmap_offsets = NULL;
  if (numTables > 0u) {
    face->cmap_offsets = (uint32_t*)vr_face_alloc_array(face, numTables, sizeof(uint32_t), 4u);
  }
  if (numTables > 0u && !face->cmap_offsets) {
    return VR_ERR_OOM;
  }

  uint32_t sel = vr_find_preferred_cmap_offset(face, p);
  if (sel == 0) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* sub = p + sel;
  uint16_t length = vr_u16(sub + 2);
  vr_zero(&face->cmap, sizeof(vr_cmap_table_t));
  if (length == 0u || sub + length > p + cmap->length) {
    return VR_ERR_INVALID_FONT;
  }

  uint16_t format = vr_u16(sub);

  switch (format) {
    case VR_CMAP_FORMAT_4: {
      return vr_parse_cmap_format4(face, sub, length);
    }
    case VR_CMAP_FORMAT_12: {
      return vr_parse_cmap_format12(face, sub, length);
    }
    case VR_CMAP_FORMAT_0:
      return VR_ERR_UNSUPPORTED;
    default:
      return VR_ERR_UNSUPPORTED;
  }
}

uint16_t vr_find_glyph_id(vr_font_face_t* face, uint32_t codepoint) {
  if (!face || !face->cmap.format) return 0;
  switch (face->cmap.format) {
    case VR_CMAP_FORMAT_4: {
      uint16_t seg_count = face->cmap.u.format4.seg_count_x2 / 2u;
      for (uint16_t i = 0; i < seg_count; ++i) {
        uint16_t end_code = face->cmap.u.format4.end_code[i];
        uint16_t start_code = face->cmap.u.format4.start_code[i];
        if (codepoint < start_code || codepoint > end_code) continue;
        int16_t delta = face->cmap.u.format4.id_delta[i];
        uint16_t range_offset = face->cmap.u.format4.id_range_offset[i];
        if (range_offset == 0u) {
          return (uint16_t)(codepoint + delta);
        }

        size_t idx = (size_t)(range_offset / 2u) + (size_t)(codepoint - start_code) - (size_t)(seg_count - i);
        if (idx < face->cmap.u.format4.glyph_id_array_count) {
          uint16_t g = face->cmap.u.format4.glyph_id_array[idx];
          if (g == 0u) return 0u;
          return (uint16_t)(g + delta);
        }
        return 0u;
      }
      return 0u;
    }
    case VR_CMAP_FORMAT_12:
      for (uint32_t i = 0; i < face->cmap.u.format12.n_groups; ++i) {
        uint32_t s = face->cmap.u.format12.start_char_code[i];
        uint32_t e = face->cmap.u.format12.end_char_code[i];
        if (codepoint < s || codepoint > e) continue;
        uint32_t g = face->cmap.u.format12.start_glyph_id[i] + (codepoint - s);
        return (uint16_t)(g & 0xFFFFu);
      }
      return 0u;
    default:
      return 0u;
  }
}
