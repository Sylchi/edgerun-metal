#include "vr_font_utils_internal.h"

vr_status_t vr_apply_gvar_variation(const vr_font_face_t* face, uint16_t glyph_id, vr_glyph_outline_t* outline) {
  if (!face || !outline) return VR_ERR_INVALID_FONT;
  if (face->gvar.axis_count == 0 || face->gvar.glyph_count == 0) return VR_OK;
  if (face->gvar.glyph_variation_offsets == NULL || glyph_id >= face->gvar.glyph_count) return VR_OK;
  if (outline->point_count < 0) return VR_OK;
  if (face->gvar.axis_count > VR_MAX_AXES) return VR_ERR_INVALID_FONT;
  vr_init_gvar_phantoms(face, glyph_id, outline);

  const vr_table_record_t* gvar = vr_find_table(face, VR_TABLE_TAG('g', 'v', 'a', 'r'));
  if (!gvar) return VR_OK;

  uint32_t start = face->gvar.glyph_variation_offsets[glyph_id];
  uint32_t end = face->gvar.glyph_variation_offsets[glyph_id + 1];
  if (start >= end || gvar->offset + gvar->length < gvar->offset + end) return VR_OK;

  const uint8_t* p = face->file_data + gvar->offset;
  const uint8_t* glyph_data = p + start;
  const uint8_t* glyph_data_end = p + end;
  if (glyph_data + 4 > glyph_data_end) return VR_OK;

  size_t total_points = (size_t)outline->point_count + 4u;
  int16_t* base_x = NULL;
  int16_t* base_y = NULL;
  if (outline->point_count > 0) {
    base_x = (int16_t*)vr_alloc(face, (size_t)outline->point_count * sizeof(*base_x), 2u);
    base_y = (int16_t*)vr_alloc(face, (size_t)outline->point_count * sizeof(*base_y), 2u);
    if (!base_x || !base_y) {
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_OOM;
    }
    for (size_t i = 0u; i < (size_t)outline->point_count; ++i) {
      base_x[i] = outline->x[i];
      base_y[i] = outline->y[i];
    }
  }
  uint16_t tuple_count = vr_u16(glyph_data) & VR_GVAR_TUPLE_COUNT_MASK;
  uint16_t table_flags = vr_u16(glyph_data) & 0xF000u;
  size_t data_offset = (size_t)vr_u16(glyph_data + 2);
  const uint8_t* serialized = glyph_data + data_offset;
  if (serialized > glyph_data_end) {
    vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
    vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
    return VR_OK;
  }

  uint16_t* shared_points = NULL;
  bool shared_points_all = false;
  size_t shared_point_count = 0;
  size_t shared_consumed = 0;
  const uint8_t* tuple_data = serialized;

  if ((table_flags & VR_GVAR_TUPLE_SHARED_POINTS) != 0) {
    vr_status_t st = vr_decode_point_indices(face, serialized, glyph_data_end, total_points, &shared_points_all,
                                             &shared_points, &shared_point_count, &shared_consumed);
    if (st != VR_OK) {
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return st;
    }
    tuple_data += shared_consumed;
    if (shared_points == NULL && shared_point_count > 0) {
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_OOM;
    }
  }

  const uint8_t* header = glyph_data + 4;
  for (uint16_t tvi = 0; tvi < tuple_count; ++tvi) {
    if (tuple_data > glyph_data_end) {
      break;
    }
    if (header + 4 > glyph_data_end) {
      vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_INVALID_FONT;
    }

    uint16_t tuple_data_size = vr_u16(header);
    uint16_t tuple_index = vr_u16(header + 2);
    header += 4;
    if (tuple_data + tuple_data_size > glyph_data_end) {
      vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
      vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
      vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
      return VR_ERR_INVALID_FONT;
    }

    bool embedded_peak = (tuple_index & VR_GVAR_TUPLE_EMBEDDED_PEAK) != 0;
    bool intermediate = (tuple_index & VR_GVAR_TUPLE_INTERMEDIATE) != 0;
    bool private_points = (tuple_index & VR_GVAR_TUPLE_PRIVATE_POINTS) != 0;

    float peak[VR_MAX_AXES];
    float start_curve[VR_MAX_AXES];
    float end_curve[VR_MAX_AXES];

    if (embedded_peak) {
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        if (header + 2 > glyph_data_end) {
          vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
          vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
          vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
          return VR_ERR_INVALID_FONT;
        }
        peak[i] = vr_utils_f2dot14_to_float(vr_u16(header));
        header += 2;
      }
    } else {
      uint16_t shared_index = tuple_index & VR_GVAR_TUPLE_COUNT_MASK;
      if (shared_index >= face->gvar.shared_tuple_count || face->gvar.shared_tuples == NULL) {
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_INVALID_FONT;
      }
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        peak[i] = face->gvar.shared_tuples[(size_t)shared_index * face->gvar.axis_count + i];
      }
    }

    if (intermediate) {
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        if (header + 2 > glyph_data_end || header + 4 > glyph_data_end) {
          vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
          vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
          vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
          return VR_ERR_INVALID_FONT;
        }
        start_curve[i] = vr_utils_f2dot14_to_float(vr_u16(header));
        end_curve[i] = vr_utils_f2dot14_to_float(vr_u16(header + 2));
        header += 4;
      }
    } else {
      for (uint16_t i = 0; i < face->gvar.axis_count; ++i) {
        if (peak[i] > 0.0f) {
          start_curve[i] = 0.0f;
          end_curve[i] = peak[i];
        } else if (peak[i] < 0.0f) {
          start_curve[i] = peak[i];
          end_curve[i] = 0.0f;
        } else {
          start_curve[i] = 0.0f;
          end_curve[i] = 0.0f;
        }
      }
    }

    bool tuple_all = false;
    uint16_t* tuple_points = NULL;
    size_t tuple_point_count = 0;
    size_t local_bytes = 0;

    if (private_points) {
      vr_status_t st = vr_decode_point_indices(face, tuple_data, glyph_data_end, total_points, &tuple_all,
                                               &tuple_points, &tuple_point_count, &local_bytes);
      if (st != VR_OK) {
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return st;
      }
      if (tuple_points == NULL && tuple_point_count > 0) {
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_OOM;
      }
    } else if ((table_flags & VR_GVAR_TUPLE_SHARED_POINTS) != 0) {
      tuple_all = shared_points_all;
      tuple_points = shared_points;
      tuple_point_count = shared_point_count;
      local_bytes = 0;
    } else {
      tuple_all = true;
      tuple_point_count = total_points;
    }

    const uint8_t* delta_data = tuple_data + local_bytes;
    size_t point_apply_count = tuple_all ? total_points : tuple_point_count;
    if (point_apply_count > (size_t)UINT16_MAX) point_apply_count = (size_t)UINT16_MAX;

    int16_t* raw_dx = NULL;
    int16_t* raw_dy = NULL;
    int32_t* dx = NULL;
    int32_t* dy = NULL;
    uint8_t* touched = NULL;
    size_t used_x = 0;
    size_t used_y = 0;

    if (point_apply_count > 0) {
      raw_dx = (int16_t*)vr_calloc(face, point_apply_count, sizeof(int16_t), 2u);
      raw_dy = (int16_t*)vr_calloc(face, point_apply_count, sizeof(int16_t), 2u);
      dx = (int32_t*)vr_calloc(face, total_points, sizeof(int32_t), 4u);
      dy = (int32_t*)vr_calloc(face, total_points, sizeof(int32_t), 4u);
      touched = (uint8_t*)vr_calloc(face, total_points, sizeof(uint8_t), 1u);
      if (!raw_dx || !raw_dy || !dx || !dy || !touched) {
        vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
        vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
        vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
        vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
        vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
        if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_OOM;
      }

      vr_status_t sx = vr_decode_delta_runs(delta_data, glyph_data_end, raw_dx, point_apply_count, &used_x);
      vr_status_t sy = vr_decode_delta_runs(delta_data + used_x, glyph_data_end, raw_dy, point_apply_count, &used_y);
      if (sx != VR_OK || sy != VR_OK || (delta_data + used_x + used_y > tuple_data + tuple_data_size)) {
        vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
        vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
        vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
        vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
        vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
        if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);
        vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
        vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
        vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
        return VR_ERR_INVALID_FONT;
      }

      for (size_t i = 0; i < point_apply_count; ++i) {
        uint16_t pi = tuple_all ? (uint16_t)i : tuple_points[i];
        if (pi >= total_points) {
          continue;
        }
        dx[pi] = raw_dx[i];
        dy[pi] = raw_dy[i];
        touched[pi] = 1u;
      }
      if (!tuple_all && outline->point_count > 0) {
        vr_iup_interpolate_outline_deltas(outline, base_x, base_y, dx, dy, touched);
      }
    }

    float scalar = vr_compute_tuple_scalar(face, face->gvar.axis_count, start_curve, peak, end_curve);
    if (scalar > 0.0f && point_apply_count > 0) {
      for (size_t pi = 0; pi < total_points; ++pi) {
        int32_t nx = (int32_t)vr_lrintf((float)dx[pi] * scalar);
        int32_t ny = (int32_t)vr_lrintf((float)dy[pi] * scalar);

        if (pi < (uint16_t)outline->point_count) {
          int32_t next_x = (int32_t)outline->x[pi] + nx;
          int32_t next_y = (int32_t)outline->y[pi] + ny;
          if (next_x < INT16_MIN || next_x > INT16_MAX || next_y < INT16_MIN || next_y > INT16_MAX) {
            vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
            vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
            vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
            vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
            vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
            if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);
            vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
            vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
            vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
            return VR_ERR_INVALID_FONT;
          }
          outline->x[pi] = (int16_t)next_x;
          outline->y[pi] = (int16_t)next_y;
          continue;
        }
        if (outline->has_phantom_points && pi >= (uint16_t)outline->point_count && pi < (uint16_t)(outline->point_count + 4)) {
          size_t pp = (size_t)(pi - (uint16_t)outline->point_count);
          outline->phantom_x[pp] = outline->phantom_x[pp] + (int32_t)nx;
          outline->phantom_y[pp] = outline->phantom_y[pp] + (int32_t)ny;
        }
      }
    }

    vr_dealloc(face, raw_dx, point_apply_count * sizeof(*raw_dx), 2u);
    vr_dealloc(face, raw_dy, point_apply_count * sizeof(*raw_dy), 2u);
    vr_dealloc(face, dx, total_points * sizeof(*dx), 4u);
    vr_dealloc(face, dy, total_points * sizeof(*dy), 4u);
    vr_dealloc(face, touched, total_points * sizeof(*touched), 1u);
    if (private_points) vr_dealloc(face, tuple_points, tuple_point_count * sizeof(*tuple_points), 2u);

    tuple_data += tuple_data_size;
    (void)tuple_data_size;
  }

  vr_dealloc(face, shared_points, shared_point_count * sizeof(*shared_points), 2u);
  vr_dealloc(face, base_x, (size_t)outline->point_count * sizeof(*base_x), 2u);
  vr_dealloc(face, base_y, (size_t)outline->point_count * sizeof(*base_y), 2u);
  return VR_OK;
}
