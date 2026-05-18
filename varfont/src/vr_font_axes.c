#include "vr_font_utils_internal.h"

float vr_apply_avar_mapping(const vr_font_face_t* face, uint16_t axis_index, float value) {
  if (!face || face->avar.axis_count == 0 || axis_index >= face->avar.axis_count) return value;
  if (!face->avar.map_from || !face->avar.map_to || !face->avar.segment_count || !face->avar.segment_offset) {
    return value;
  }

  uint16_t seg_count = face->avar.segment_count[axis_index];
  if (seg_count == 0) return value;

  size_t base = face->avar.segment_offset[axis_index];
  if (base >= face->avar.total_segment_count) return value;

  if (seg_count == 1) {
    return face->avar.map_to[base];
  }

  float first_in = face->avar.map_from[base];
  float last_in = face->avar.map_from[base + (size_t)seg_count - 1u];
  if (value <= first_in) return face->avar.map_to[base];
  if (value >= last_in) return face->avar.map_to[base + (size_t)seg_count - 1u];

  for (uint16_t i = 0; i + 1 < seg_count; ++i) {
    size_t k = base + (size_t)i;
    float in0 = face->avar.map_from[k];
    float in1 = face->avar.map_from[k + 1];
    float out0 = face->avar.map_to[k];
    float out1 = face->avar.map_to[k + 1];
    if (value >= in0 && value <= in1) {
      float denom = in1 - in0;
      if (denom == 0.0f) return out1;
      return out0 + (value - in0) * (out1 - out0) / denom;
    }
  }

  return value;
}

vr_status_t vr_parse_avar(vr_font_face_t* face) {
  const vr_table_record_t* t = vr_find_table(face, VR_TABLE_TAG('a', 'v', 'a', 'r'));
  if (!t) {
    face->avar.axis_count = face->fvar.axis_count;
    return VR_ERR_NOT_FOUND;
  }
  if (t->offset + t->length > face->file_size) return VR_ERR_INVALID_FONT;
  if (t->length < 8) return VR_ERR_INVALID_FONT;

  const uint8_t* p = face->file_data + t->offset;
  uint32_t version = vr_u32(p);
  uint16_t axis_count = vr_u16(p + 6);

  if (version != VR_SFNT_VERSION_MAGIC || axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  if (face->fvar.axis_count != 0 && face->fvar.axis_count != axis_count) return VR_ERR_INVALID_FONT;
  if (t->length < 8u + (size_t)axis_count * 2u) return VR_ERR_INVALID_FONT;

  face->avar.axis_count = axis_count;
  if (axis_count == 0) {
    return VR_OK;
  }

  uint16_t* seg_counts = (uint16_t*)vr_face_alloc_array(face, axis_count, sizeof(uint16_t), 2u);
  size_t* seg_offsets = (size_t*)vr_face_alloc_array(face, axis_count, sizeof(size_t), 8u);
  if (!seg_counts || !seg_offsets) {
    vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
    return VR_ERR_OOM;
  }

  uint32_t total_segments = 0;
  const uint8_t* map_offsets = p + 8;
  for (uint16_t a = 0; a < axis_count; ++a) {
    uint16_t off = vr_u16(map_offsets + (size_t)a * 2u);
    if (off == 0) {
      continue;
    }
    if ((size_t)off + 2 > t->length) {
      vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
      vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
      return VR_ERR_INVALID_FONT;
    }
    seg_counts[a] = vr_u16(p + off);
    total_segments += seg_counts[a];
  }

  if (total_segments == 0) {
    vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
    return VR_OK;
  }

  float* map_from = (float*)vr_face_alloc_array(face, (size_t)total_segments, sizeof(float), 8u);
  float* map_to = (float*)vr_face_alloc_array(face, (size_t)total_segments, sizeof(float), 8u);
  if (!map_from || !map_to) {
    vr_face_free_array(face, map_from, (size_t)total_segments, sizeof(float), 8u);
    vr_face_free_array(face, map_to, (size_t)total_segments, sizeof(float), 8u);
    vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
    vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
    return VR_ERR_OOM;
  }

  uint32_t cursor = 0;
  for (uint16_t a = 0; a < axis_count; ++a) {
    uint16_t off = vr_u16(map_offsets + (size_t)a * 2u);
    uint16_t sc = seg_counts[a];
    seg_offsets[a] = (size_t)cursor;

    if (off == 0 || sc == 0) {
      continue;
    }

    const uint8_t* map = p + off;
    size_t needed = 2u + (size_t)sc * 4u;
    if (off + needed > t->length) {
      vr_face_free_array(face, map_from, (size_t)total_segments, sizeof(float), 8u);
      vr_face_free_array(face, map_to, (size_t)total_segments, sizeof(float), 8u);
      vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
      vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
      return VR_ERR_INVALID_FONT;
    }

    const uint8_t* from = map + 2;
    const uint8_t* to = from + (size_t)sc * 2u;
    for (uint16_t i = 0; i < sc; ++i) {
      map_from[cursor + i] = vr_utils_f2dot14_to_float(vr_u16(from + ((size_t)i * 2u)));
      map_to[cursor + i] = vr_utils_f2dot14_to_float(vr_u16(to + ((size_t)i * 2u)));
    }
    cursor += sc;
  }

  face->avar.segment_count = seg_counts;
  face->avar.segment_offset = seg_offsets;
  face->avar.total_segment_count = (size_t)total_segments;
  face->avar.map_from = map_from;
  face->avar.map_to = map_to;
  return VR_OK;
}

vr_status_t vr_read_fvar(vr_font_face_t* face) {
  const vr_table_record_t* t = vr_find_table(face, VR_TABLE_TAG('f','v','a','r'));
  if (!t) {
    face->fvar.axis_count = 0;
    return VR_OK;
  }
  if (t->offset + t->length > face->file_size) {
    return VR_ERR_INVALID_FONT;
  }

  const uint8_t* p = face->file_data + t->offset;
  uint32_t version = vr_u32(p);
  uint16_t axis_offset = vr_u16(p + 4);
  uint16_t axis_count = vr_u16(p + 8);
  uint16_t axis_size = vr_u16(p + 10);
  uint16_t instance_count = vr_u16(p + 12);
  uint16_t instance_size = vr_u16(p + 14);
  if (version != VR_SFNT_VERSION_MAGIC || axis_count > VR_MAX_AXES || axis_size < 20) {
    return VR_ERR_INVALID_FONT;
  }
  if (axis_offset > t->length || axis_offset < 16u) {
    return VR_ERR_INVALID_FONT;
  }
  if (instance_size < 4u && instance_count != 0u) {
    return VR_ERR_INVALID_FONT;
  }
  size_t instance_records_size = (size_t)instance_count * (size_t)instance_size;
  if (instance_records_size > (size_t)t->length || axis_offset + instance_records_size > t->length) {
    return VR_ERR_INVALID_FONT;
  }

  face->fvar.axis_count = axis_count;
  face->fvar.default_instance_index = 0;
  face->fvar.axis_value_record_count = 0;

  const uint8_t* a = p + axis_offset;
  for (uint16_t i = 0; i < axis_count; ++i) {
    if ((size_t)(a - p) + 20 > t->length) {
      return VR_ERR_INVALID_FONT;
    }
    uint32_t tag = vr_u32(a);
    float minValue = vr_fixed_to_float(vr_u32(a + 4));
    float defaultValue = vr_fixed_to_float(vr_u32(a + 8));
    float maxValue = vr_fixed_to_float(vr_u32(a + 12));
    float step = vr_fixed_to_float(vr_u32(a + 16));
    (void)step;

    face->fvar.descriptors[i].tag[0] = (char)(tag >> 24);
    face->fvar.descriptors[i].tag[1] = (char)(tag >> 16);
    face->fvar.descriptors[i].tag[2] = (char)(tag >> 8);
    face->fvar.descriptors[i].tag[3] = (char)tag;
    face->fvar.descriptors[i].tag[4] = '\0';
    face->fvar.descriptors[i].min = minValue;
    face->fvar.descriptors[i].default_value = defaultValue;
    face->fvar.descriptors[i].max = maxValue;

    a += axis_size;
  }

  vr_set_axis_data(face);
  return VR_OK;
}

float vr_map_axis_value(const vr_font_face_t* face, const char* tag, float user_value, float* out_norm) {
  *out_norm = 0.0f;
  for (uint16_t i = 0; i < face->fvar.axis_count; ++i) {
    if (vr_tag_compare(face->fvar.descriptors[i].tag, tag) == 0) {
      float clamped = user_value;
      if (clamped < face->fvar.descriptors[i].min) clamped = face->fvar.descriptors[i].min;
      if (clamped > face->fvar.descriptors[i].max) clamped = face->fvar.descriptors[i].max;
      float dmin = face->fvar.descriptors[i].min;
      float dfl = face->fvar.descriptors[i].default_value;
      float dmax = face->fvar.descriptors[i].max;
      if (clamped >= dfl) {
        float denom = (dmax - dfl);
        *out_norm = (denom != 0.0f) ? ((clamped - dfl) / denom) : 0.0f;
      } else {
        float denom = (dfl - dmin);
        *out_norm = (denom != 0.0f) ? -((dfl - clamped) / denom) : 0.0f;
      }
      if (*out_norm > 1.0f) *out_norm = 1.0f;
      if (*out_norm < -1.0f) *out_norm = -1.0f;
      return clamped;
    }
  }
  return user_value;
}
