#include "vr_font_utils_internal.h"

void vr_init_gvar_phantoms(
  const vr_font_face_t* face,
  uint16_t glyph_id,
  vr_glyph_outline_t* outline) {
  int16_t lsb = vr_get_glyph_h_lsb_units(face, glyph_id);
  uint16_t adv = vr_get_glyph_h_advance_units(face, glyph_id);

  outline->has_phantom_points = true;
  outline->phantom_x[0] = (int32_t)lsb;
  outline->phantom_x[1] = (int32_t)lsb + (int32_t)adv;
  outline->phantom_y[0] = 0;
  outline->phantom_y[1] = 0;
  outline->phantom_x[2] = 0;
  outline->phantom_x[3] = 0;
  outline->phantom_y[2] = (int32_t)outline->y_max;
  outline->phantom_y[3] = (int32_t)outline->y_min;
}

//@optimizer-ignore-function gvar point index decoding must expand compressed point runs from the font table
vr_status_t vr_decode_point_indices(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  size_t all_points_hint,
  bool* out_all_points,
  uint16_t** out_points,
  size_t* out_count,
  size_t* out_consumed) {
  const uint8_t* start = p;
  if (!p || !end || !out_all_points || !out_count || !out_consumed) return VR_ERR_INVALID_FONT;
  if (p >= end) return VR_ERR_INVALID_FONT;

  *out_points = NULL;
  *out_count = 0;
  *out_all_points = false;
  *out_consumed = 0;

  uint8_t first = *p++;
  size_t count = 0;

  if (first == 0) {
    *out_all_points = true;
    count = all_points_hint;
    *out_count = count;
    *out_consumed = (size_t)(p - start);
    return VR_OK;
  }

  if ((first & 0x80u) != 0) {
    if (p >= end) return VR_ERR_INVALID_FONT;
    count = ((size_t)(first & 0x7Fu) << 8) | (size_t)(*p++);
  } else {
    count = (size_t)first;
  }
  if (count > ((SIZE_MAX - 1) / sizeof(uint16_t))) return VR_ERR_INVALID_FONT;

  uint16_t* points = (uint16_t*)vr_alloc(face, count * sizeof(uint16_t), 2u);
  if (!points && count > 0) return VR_ERR_OOM;
  if (count == 0) {
    *out_points = NULL;
    *out_count = 0;
    *out_consumed = (size_t)(p - start);
    return VR_OK;
  }

  size_t parsed = 0;
  uint16_t last = 0;
  while (parsed < count) {
    if (p >= end) {
      vr_dealloc(face, points, count * sizeof(*points), 2u);
      return VR_ERR_INVALID_FONT;
    }

    uint8_t run_ctl = *p++;
    size_t run_count = (size_t)(run_ctl & 0x7Fu) + 1;
    bool words = (run_ctl & 0x80u) != 0;

    for (size_t i = 0; i < run_count; ++i) {
      uint16_t delta = 0;
      if (words) {
        if (p + 2 > end) {
          vr_dealloc(face, points, count * sizeof(*points), 2u);
          return VR_ERR_INVALID_FONT;
        }
        delta = vr_u16(p);
        p += 2;
      } else {
        if (p >= end) {
          vr_dealloc(face, points, count * sizeof(*points), 2u);
          return VR_ERR_INVALID_FONT;
        }
        delta = (uint16_t)(*p++);
      }

      last = (uint16_t)(last + delta);
      if (parsed < count) {
        points[parsed++] = last;
      }
    }
  }

  *out_points = points;
  *out_count = count;
  *out_consumed = (size_t)(p - start);
  return VR_OK;
}

//@optimizer-ignore-function gvar delta decoding must expand zero, byte, and word run encodings point-by-point
vr_status_t vr_decode_delta_runs(
  const uint8_t* p,
  const uint8_t* end,
  int16_t* out_deltas,
  size_t out_count,
  size_t* out_used) {
  if (!p || !end || !out_deltas || !out_used) return VR_ERR_INVALID_FONT;
  if (out_count == 0) {
    *out_used = 0;
    return VR_OK;
  }

  size_t produced = 0;
  const uint8_t* start = p;

  while (produced < out_count) {
    if (p >= end) {
      return VR_ERR_INVALID_FONT;
    }
    uint8_t ctl = *p++;
    size_t run_count = (size_t)(ctl & 0x3Fu) + 1;

    if ((ctl & 0x80u) != 0) {
      for (size_t i = 0; i < run_count && produced < out_count; ++i) {
        out_deltas[produced++] = 0;
      }
      continue;
    }

    if ((ctl & 0x40u) != 0) {
      size_t bytes = run_count * 2;
      if ((size_t)(end - p) < bytes) return VR_ERR_INVALID_FONT;
      for (size_t i = 0; i < run_count; ++i) {
        int16_t v = (int16_t)vr_u16(p);
        p += 2;
        if (produced < out_count) out_deltas[produced] = v;
        produced++;
      }
      continue;
    }

    if ((size_t)(end - p) < run_count) return VR_ERR_INVALID_FONT;
    for (size_t i = 0; i < run_count; ++i) {
      int16_t v = (int8_t)(*p++);
      if (produced < out_count) out_deltas[produced] = v;
      produced++;
    }
  }

  *out_used = (size_t)(p - start);
  return produced == out_count ? VR_OK : VR_ERR_INVALID_FONT;
}

//@optimizer-ignore-function variation tuple scalar must evaluate each active axis support interval
float vr_compute_tuple_scalar(const vr_font_face_t* face, uint16_t axis_count,
                                    const float* start, const float* peak, const float* end) {
  float scalar = 1.0f;
  for (uint16_t i = 0; i < axis_count; ++i) {
    float as = 1.0f;
    float sc = start[i];
    float pk = peak[i];
    float en = end[i];
    float n = face->axis_values[i];

    if (!(sc <= pk && pk <= en)) {
      return 0.0f;
    }

    if (n < sc || n > en) {
      as = 0.0f;
    } else if (pk == sc || pk == en) {
      as = (n == pk) ? 1.0f : 0.0f;
    } else if (n < pk) {
      as = (pk - sc > 0.0f) ? ((n - sc) / (pk - sc)) : 0.0f;
    } else if (n > pk) {
      as = (en - pk > 0.0f) ? ((en - n) / (en - pk)) : 0.0f;
    } else {
      as = 1.0f;
    }

    scalar *= as;
    if (scalar <= 0.0f) {
      return 0.0f;
    }
  }
  return scalar;
}

size_t vr_iup_next_index(size_t index, size_t start, size_t end) {
  return (index >= end) ? start : (index + 1u);
}

int32_t vr_iup_interpolate_delta(int16_t coord, int16_t coord_a, int16_t coord_b, int32_t delta_a, int32_t delta_b) {
  if (coord_a == coord_b) {
    return delta_a;
  }

  int16_t min_coord = coord_a;
  int16_t max_coord = coord_b;
  int32_t min_delta = delta_a;
  int32_t max_delta = delta_b;
  if (coord_a > coord_b) {
    min_coord = coord_b;
    max_coord = coord_a;
    min_delta = delta_b;
    max_delta = delta_a;
  }

  if (coord <= min_coord) {
    return min_delta;
  }
  if (coord >= max_coord) {
    return max_delta;
  }

  float ratio = (float)(coord - min_coord) / (float)(max_coord - min_coord);
  return (int32_t)vr_lrintf((float)min_delta + ((float)(max_delta - min_delta) * ratio));
}

void vr_iup_interpolate_contour_axis(
  const int16_t* coords,
  int32_t* deltas,
  const uint8_t* touched,
  size_t start,
  size_t end) {
  size_t first_touched = end + 1u;
  size_t touched_count = 0u;
  for (size_t i = start; i <= end; ++i) {
    if (touched[i] != 0u) {
      if (first_touched > end) {
        first_touched = i;
      }
      ++touched_count;
    }
  }

  if (touched_count == 0u) {
    return;
  }
  if (touched_count == 1u) {
    int32_t delta = deltas[first_touched];
    for (size_t i = start; i <= end; ++i) {
      if (touched[i] == 0u) {
        deltas[i] = delta;
      }
    }
    return;
  }

  size_t left = first_touched;
  do {
    size_t right = vr_iup_next_index(left, start, end);
    while (right != left && touched[right] == 0u) {
      right = vr_iup_next_index(right, start, end);
    }

    size_t fill = vr_iup_next_index(left, start, end);
    while (fill != right) {
      deltas[fill] = vr_iup_interpolate_delta(coords[fill], coords[left], coords[right], deltas[left], deltas[right]);
      fill = vr_iup_next_index(fill, start, end);
    }
    left = right;
  } while (left != first_touched);
}

void vr_iup_interpolate_outline_deltas(
  const vr_glyph_outline_t* outline,
  const int16_t* base_x,
  const int16_t* base_y,
  int32_t* dx,
  int32_t* dy,
  const uint8_t* touched) {
  if (!outline || !base_x || !base_y || !dx || !dy || !touched || outline->point_count <= 0) {
    return;
  }

  for (uint16_t c = 0u; c < outline->number_of_contours; ++c) {
    size_t start = (c == 0u) ? 0u : ((size_t)outline->contour_end_pts[c - 1u] + 1u);
    size_t end = (size_t)outline->contour_end_pts[c];
    if (start > end || end >= (size_t)outline->point_count) {
      continue;
    }
    vr_iup_interpolate_contour_axis(base_x, dx, touched, start, end);
    vr_iup_interpolate_contour_axis(base_y, dy, touched, start, end);
  }
}

//@optimizer-ignore-function avar mapping must scan ordered axis segments and interpolate the containing interval
vr_status_t vr_parse_gvar(vr_font_face_t* face) {
  const vr_table_record_t* t = vr_find_table(face, VR_TABLE_TAG('g', 'v', 'a', 'r'));
  if (!t) {
    face->gvar.axis_count = 0;
    face->gvar.glyph_count = face->num_glyphs;
    return VR_ERR_NOT_FOUND;
  }
  if (t->length < 20 || t->offset + t->length > face->file_size) return VR_ERR_INVALID_FONT;

  const uint8_t* p = face->file_data + t->offset;
  uint16_t major = vr_u16(p);
  uint16_t minor = vr_u16(p + 2);
  uint16_t axis_count = vr_u16(p + 4);
  uint16_t shared_tuple_count = vr_u16(p + 6);
  uint32_t shared_tuples_offset = vr_u32(p + 8);
  uint16_t glyph_count = vr_u16(p + 12);
  uint16_t flags = vr_u16(p + 14);
  uint32_t glyph_data_array_offset = vr_u32(p + 16);

  if (major != VR_GVAR_MAJOR_VERSION || minor != VR_GVAR_MINOR_VERSION) return VR_ERR_INVALID_FONT;
  if (axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  if (face->fvar.axis_count != 0 && axis_count != face->fvar.axis_count) return VR_ERR_INVALID_FONT;
  if (glyph_count != face->num_glyphs) return VR_ERR_INVALID_FONT;

  bool use32 = (flags & VR_GVAR_OFFSET_FORMAT_32) != 0u;
  size_t offset_size = use32 ? 4u : 2u;
  size_t offset_count = (size_t)glyph_count + 1;
  size_t header_len = 20;
  size_t offset_bytes = offset_count * offset_size;

  if (shared_tuples_offset > t->length) return VR_ERR_INVALID_FONT;
  if (glyph_data_array_offset > t->length) return VR_ERR_INVALID_FONT;
  if (header_len + offset_bytes > t->length) return VR_ERR_INVALID_FONT;
  if (shared_tuples_offset < header_len + offset_bytes) return VR_ERR_INVALID_FONT;
  if (glyph_data_array_offset < shared_tuples_offset) return VR_ERR_INVALID_FONT;

  uint32_t* glyph_off = (uint32_t*)vr_face_alloc_array(face, offset_count, sizeof(uint32_t), 4u);
  if (!glyph_off) return VR_ERR_OOM;

  const uint8_t* offset_base = p + header_len;
  for (size_t i = 0; i < offset_count; ++i) {
    uint32_t rel = use32 ? vr_u32(offset_base + i * 4u) :
                           ((uint32_t)vr_u16(offset_base + i * 2u) * VR_GVAR_OFFSET_MULTIPLIER_16);
    uint64_t abs = (uint64_t)glyph_data_array_offset + rel;
    if (abs > (uint64_t)t->length) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_INVALID_FONT;
    }
    glyph_off[i] = (uint32_t)abs;
  }

  if (shared_tuple_count > 0 && axis_count > 0) {
    size_t shared_bytes = (size_t)shared_tuple_count * (size_t)axis_count * 2u;
    uint32_t shared_end = shared_tuples_offset + (uint32_t)shared_bytes;
    if (shared_end > glyph_data_array_offset) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_INVALID_FONT;
    }
    if (shared_end > t->length) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_INVALID_FONT;
    }

    size_t tuple_values = (size_t)shared_tuple_count * (size_t)axis_count;
    float* shared_tuples = (float*)vr_face_alloc_array(face, tuple_values, sizeof(float), 8u);
    if (!shared_tuples) {
      vr_face_free_array(face, glyph_off, offset_count, sizeof(uint32_t), 4u);
      return VR_ERR_OOM;
    }

    const uint8_t* tuple = p + shared_tuples_offset;
    for (uint16_t i = 0; i < shared_tuple_count; ++i) {
      for (uint16_t a = 0; a < axis_count; ++a) {
        shared_tuples[(size_t)i * axis_count + a] = vr_utils_f2dot14_to_float(vr_u16(tuple));
        tuple += 2;
      }
    }
    face->gvar.shared_tuples = shared_tuples;
  }

  face->gvar.glyph_count = glyph_count;
  face->gvar.axis_count = axis_count;
  face->gvar.flags = flags;
  face->gvar.shared_tuple_count = shared_tuple_count;
  face->gvar.shared_tuples_offset = shared_tuples_offset;
  face->gvar.glyph_data_array_offset = glyph_data_array_offset;
  face->gvar.offset_format = use32 ? VR_GVAR_TUPLE_DATA_OFFSET_32 : VR_GVAR_TUPLE_DATA_OFFSET_16;
  face->gvar.glyph_variation_offsets = glyph_off;
  return VR_OK;
}

//@optimizer-ignore-function avar parsing must decode each axis segment map from variable-font tables
