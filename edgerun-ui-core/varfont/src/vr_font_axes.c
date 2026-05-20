#include "vr_font_utils_internal.h"

static const size_t VR_AVAR_HEADER_SIZE = 8u;
static const size_t VR_AVAR_AXIS_COUNT_OFFSET = 6u;
static const size_t VR_AVAR_AXIS_OFFSET_SIZE = 2u;
static const size_t VR_AVAR_SEGMENT_COUNT_SIZE = 2u;
static const size_t VR_AVAR_SEGMENT_MAP_VALUE_SIZE = 4u;
static const size_t VR_FVAR_AXIS_ARRAY_OFFSET_OFFSET = 4u;
static const size_t VR_FVAR_AXIS_COUNT_OFFSET = 8u;
static const size_t VR_FVAR_AXIS_SIZE_OFFSET = 10u;
static const size_t VR_FVAR_INSTANCE_COUNT_OFFSET = 12u;
static const size_t VR_FVAR_INSTANCE_SIZE_OFFSET = 14u;
static const uint16_t VR_FVAR_MIN_AXIS_ARRAY_OFFSET = 16u;
static const uint16_t VR_FVAR_MIN_AXIS_SIZE = 20u;
static const uint16_t VR_FVAR_MIN_INSTANCE_SIZE = 4u;
static const size_t VR_FVAR_AXIS_TAG_OFFSET = 0u;
static const size_t VR_FVAR_AXIS_MIN_VALUE_OFFSET = 4u;
static const size_t VR_FVAR_AXIS_DEFAULT_VALUE_OFFSET = 8u;
static const size_t VR_FVAR_AXIS_MAX_VALUE_OFFSET = 12u;
static const size_t VR_FVAR_AXIS_STEP_OFFSET = 16u;
static const uint32_t VR_FVAR_TAG_BYTE0_SHIFT = 24u;
static const uint32_t VR_FVAR_TAG_BYTE1_SHIFT = 16u;
static const uint32_t VR_FVAR_TAG_BYTE2_SHIFT = 8u;
static const size_t VR_FVAR_TAG_BYTE0_INDEX = 0u;
static const size_t VR_FVAR_TAG_BYTE1_INDEX = 1u;
static const size_t VR_FVAR_TAG_BYTE2_INDEX = 2u;
static const size_t VR_FVAR_TAG_BYTE3_INDEX = 3u;
static const size_t VR_FVAR_TAG_TERMINATOR_INDEX = 4u;

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
  if (t->length < VR_AVAR_HEADER_SIZE) return VR_ERR_INVALID_FONT;

  const uint8_t* p = face->file_data + t->offset;
  uint32_t version = vr_u32(p);
  uint16_t axis_count = vr_u16(p + VR_AVAR_AXIS_COUNT_OFFSET);

  if (version != VR_SFNT_VERSION_MAGIC || axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  if (face->fvar.axis_count != 0 && face->fvar.axis_count != axis_count) return VR_ERR_INVALID_FONT;
  if (t->length < VR_AVAR_HEADER_SIZE + (size_t)axis_count * VR_AVAR_AXIS_OFFSET_SIZE) return VR_ERR_INVALID_FONT;

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
  const uint8_t* map_offsets = p + VR_AVAR_HEADER_SIZE;
  for (uint16_t a = 0; a < axis_count; ++a) {
    uint16_t off = vr_u16(map_offsets + (size_t)a * VR_AVAR_AXIS_OFFSET_SIZE);
    if (off == 0) {
      continue;
    }
    if ((size_t)off + VR_AVAR_SEGMENT_COUNT_SIZE > t->length) {
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
    uint16_t off = vr_u16(map_offsets + (size_t)a * VR_AVAR_AXIS_OFFSET_SIZE);
    uint16_t sc = seg_counts[a];
    seg_offsets[a] = (size_t)cursor;

    if (off == 0 || sc == 0) {
      continue;
    }

    const uint8_t* map = p + off;
    size_t needed = VR_AVAR_SEGMENT_COUNT_SIZE + (size_t)sc * VR_AVAR_SEGMENT_MAP_VALUE_SIZE;
    if (off + needed > t->length) {
      vr_face_free_array(face, map_from, (size_t)total_segments, sizeof(float), 8u);
      vr_face_free_array(face, map_to, (size_t)total_segments, sizeof(float), 8u);
      vr_face_free_array(face, seg_counts, axis_count, sizeof(uint16_t), 2u);
      vr_face_free_array(face, seg_offsets, axis_count, sizeof(size_t), 8u);
      return VR_ERR_INVALID_FONT;
    }

    const uint8_t* from = map + VR_AVAR_SEGMENT_COUNT_SIZE;
    const uint8_t* to = from + (size_t)sc * VR_AVAR_AXIS_OFFSET_SIZE;
    for (uint16_t i = 0; i < sc; ++i) {
      map_from[cursor + i] = vr_utils_f2dot14_to_float(vr_u16(from + ((size_t)i * VR_AVAR_AXIS_OFFSET_SIZE)));
      map_to[cursor + i] = vr_utils_f2dot14_to_float(vr_u16(to + ((size_t)i * VR_AVAR_AXIS_OFFSET_SIZE)));
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
  uint16_t axis_offset = vr_u16(p + VR_FVAR_AXIS_ARRAY_OFFSET_OFFSET);
  uint16_t axis_count = vr_u16(p + VR_FVAR_AXIS_COUNT_OFFSET);
  uint16_t axis_size = vr_u16(p + VR_FVAR_AXIS_SIZE_OFFSET);
  uint16_t instance_count = vr_u16(p + VR_FVAR_INSTANCE_COUNT_OFFSET);
  uint16_t instance_size = vr_u16(p + VR_FVAR_INSTANCE_SIZE_OFFSET);
  if (version != VR_SFNT_VERSION_MAGIC || axis_count > VR_MAX_AXES || axis_size < VR_FVAR_MIN_AXIS_SIZE) {
    return VR_ERR_INVALID_FONT;
  }
  if (axis_offset > t->length || axis_offset < VR_FVAR_MIN_AXIS_ARRAY_OFFSET) {
    return VR_ERR_INVALID_FONT;
  }
  if (instance_size < VR_FVAR_MIN_INSTANCE_SIZE && instance_count != 0u) {
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
    if ((size_t)(a - p) + VR_FVAR_MIN_AXIS_SIZE > t->length) {
      return VR_ERR_INVALID_FONT;
    }
    uint32_t tag = vr_u32(a + VR_FVAR_AXIS_TAG_OFFSET);
    float minValue = vr_fixed_to_float(vr_u32(a + VR_FVAR_AXIS_MIN_VALUE_OFFSET));
    float defaultValue = vr_fixed_to_float(vr_u32(a + VR_FVAR_AXIS_DEFAULT_VALUE_OFFSET));
    float maxValue = vr_fixed_to_float(vr_u32(a + VR_FVAR_AXIS_MAX_VALUE_OFFSET));
    float step = vr_fixed_to_float(vr_u32(a + VR_FVAR_AXIS_STEP_OFFSET));
    (void)step;

    face->fvar.descriptors[i].tag[VR_FVAR_TAG_BYTE0_INDEX] = (char)(tag >> VR_FVAR_TAG_BYTE0_SHIFT);
    face->fvar.descriptors[i].tag[VR_FVAR_TAG_BYTE1_INDEX] = (char)(tag >> VR_FVAR_TAG_BYTE1_SHIFT);
    face->fvar.descriptors[i].tag[VR_FVAR_TAG_BYTE2_INDEX] = (char)(tag >> VR_FVAR_TAG_BYTE2_SHIFT);
    face->fvar.descriptors[i].tag[VR_FVAR_TAG_BYTE3_INDEX] = (char)tag;
    face->fvar.descriptors[i].tag[VR_FVAR_TAG_TERMINATOR_INDEX] = '\0';
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
