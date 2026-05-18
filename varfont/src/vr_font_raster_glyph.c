#include "vr_font_raster_internal.h"

vr_status_t vr_append_transformed_points(
  const vr_font_face_t* face,
  vr_glyph_outline_t* dst,
  const vr_glyph_outline_t* src,
  float xx,
  float yx,
  float xy,
  float yy,
  int16_t dx,
  int16_t dy) {
  if (!dst || !src || src->point_count == 0) return VR_OK;

  size_t dst_point_cap = (size_t)dst->point_count_alloc;
  size_t base_points = (size_t)dst->point_count;
  size_t add_points = (size_t)src->point_count;
  size_t need_points = base_points + add_points;
  if (need_points < base_points || need_points > (size_t)UINT16_MAX) {
    return VR_ERR_INVALID_FONT;
  }

  if (need_points > dst_point_cap) {
    size_t cap = (dst_point_cap == 0) ? 64 : dst_point_cap;
    while (cap < need_points) {
      cap *= 2u;
      if (cap > (size_t)UINT16_MAX) {
        cap = need_points;
        break;
      }
    }

    int16_t* nx = (int16_t*)vr_realloc(face, dst->x, dst_point_cap * sizeof(int16_t), cap * sizeof(int16_t), 8u);
    if (!nx) {
      return VR_ERR_OOM;
    }
    int16_t* ny = (int16_t*)vr_realloc(face, dst->y, dst_point_cap * sizeof(int16_t), cap * sizeof(int16_t), 8u);
    if (!ny) {
      vr_dealloc(face, nx, cap * sizeof(int16_t), 8u);
      return VR_ERR_OOM;
    }
    bool* noc = (bool*)vr_realloc(face, dst->on_curve, dst_point_cap * sizeof(bool), cap * sizeof(bool), 8u);
    if (!noc) {
      vr_dealloc(face, nx, cap * sizeof(int16_t), 8u);
      vr_dealloc(face, ny, cap * sizeof(int16_t), 8u);
      return VR_ERR_OOM;
    }
    dst->x = nx;
    dst->y = ny;
    dst->on_curve = noc;
    dst->point_count_alloc = (int)cap;
  }

  size_t base = base_points;
  for (size_t i = 0; i < add_points; ++i) {
    float ox = (float)src->x[i];
    float oy = (float)src->y[i];
    float tx = ox * xx + oy * xy + (float)dx;
    float ty = ox * yx + oy * yy + (float)dy;
    int32_t xi = (int32_t)vr_lrintf(tx);
    int32_t yi = (int32_t)vr_lrintf(ty);
    if (xi > INT16_MAX || xi < INT16_MIN || yi > INT16_MAX || yi < INT16_MIN) {
      return VR_ERR_INVALID_FONT;
    }
    dst->x[base + i] = (int16_t)xi;
    dst->y[base + i] = (int16_t)yi;
    dst->on_curve[base + i] = src->on_curve[i];
  }

  bool has_bounds = (dst->point_count > 0);
  for (size_t i = 0; i < add_points; ++i) {
    int16_t x = dst->x[base + i];
    int16_t y = dst->y[base + i];
    if (!has_bounds) {
      dst->x_min = x;
      dst->y_min = y;
      dst->x_max = x;
      dst->y_max = y;
      has_bounds = true;
    } else {
      if (x < dst->x_min) dst->x_min = x;
      if (x > dst->x_max) dst->x_max = x;
      if (y < dst->y_min) dst->y_min = y;
      if (y > dst->y_max) dst->y_max = y;
    }
  }

  size_t dst_contours = (size_t)dst->number_of_contours;
  size_t new_contours = dst_contours + (size_t)src->number_of_contours;
  if (new_contours > UINT16_MAX) {
    return VR_ERR_INVALID_FONT;
  }

  uint16_t* new_ends = (uint16_t*)vr_realloc(face, dst->contour_end_pts, dst_contours * sizeof(uint16_t), new_contours * sizeof(uint16_t), 8u);
  if (!new_ends) return VR_ERR_OOM;
  dst->contour_end_pts = new_ends;

  for (size_t i = 0; i < (size_t)src->number_of_contours; ++i) {
    uint32_t end = (uint32_t)src->contour_end_pts[i] + (uint32_t)base_points;
    if (end > UINT16_MAX) return VR_ERR_INVALID_FONT;
    dst->contour_end_pts[dst_contours + i] = (uint16_t)end;
  }

  dst->number_of_contours += src->number_of_contours;
  dst->point_count += (int)add_points;
  return VR_OK;
}

float vr_get_glyph_advance(const vr_font_face_t* face, uint16_t glyph_id) {
  if (!face || !face->hmtx) return 0.0f;

  uint16_t base_adv = vr_get_glyph_h_advance_units(face, glyph_id);
  if (base_adv == 0 && face->num_h_metrics == 0) {
    return 0.0f;
  }
  float scale = face->cfg.px_size / (float)face->units_per_em;
  int32_t adv_units = (int32_t)base_adv;

  if (face->gvar.axis_count == 0 || !face->gvar.glyph_variation_offsets || face->gvar.glyph_count == 0) {
    return (float)adv_units * scale;
  }

  if (glyph_id >= face->gvar.glyph_count) {
    return (float)adv_units * scale;
  }

  vr_glyph_outline_t outline;
  vr_zero(&outline, sizeof(outline));

  vr_status_t out_status = vr_load_glyph_outline(face, glyph_id, &outline);
  if (out_status != VR_OK && out_status != VR_ERR_UNSUPPORTED) {
    vr_free_outline(face, &outline);
    return (float)adv_units * scale;
  }

  int16_t lsb = vr_get_glyph_h_lsb_units(face, glyph_id);
  outline.has_phantom_points = true;
  outline.phantom_x[0] = (int32_t)lsb;
  outline.phantom_x[1] = (int32_t)lsb + (int32_t)base_adv;
  outline.phantom_y[0] = 0;
  outline.phantom_y[1] = 0;
  outline.phantom_x[2] = 0;
  outline.phantom_x[3] = 0;
  outline.phantom_y[2] = (int32_t)outline.y_max;
  outline.phantom_y[3] = (int32_t)outline.y_min;

  (void)vr_apply_gvar_variation(face, glyph_id, &outline);

  if (outline.has_phantom_points) {
    adv_units = outline.phantom_x[1] - outline.phantom_x[0];
  }
  vr_free_outline(face, &outline);
  return (float)adv_units * scale;
}

void vr_free_outline(const vr_font_face_t* face, vr_glyph_outline_t* outline) {
  if (!outline) return;
  vr_dealloc(face, outline->contour_end_pts, (size_t)outline->number_of_contours * sizeof(*outline->contour_end_pts), 8u);
  vr_dealloc(face, outline->x, (size_t)outline->point_count_alloc * sizeof(*outline->x), 8u);
  vr_dealloc(face, outline->y, (size_t)outline->point_count_alloc * sizeof(*outline->y), 8u);
  vr_dealloc(face, outline->on_curve, (size_t)outline->point_count_alloc * sizeof(*outline->on_curve), 8u);
  vr_zero(outline, sizeof(*outline));
}

//@optimizer-ignore-function simple glyph parsing must expand repeated flags and coordinate deltas point-by-point
vr_status_t vr_parse_simple_glyph(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  int16_t contours,
  vr_glyph_outline_t* out) {
  (void)face;
  size_t n = (size_t)contours;
  const uint8_t* q = p + 10;
  if (q > end) return VR_ERR_INVALID_FONT;

  for (uint16_t i = 0; i < contours; ++i) {
    out->contour_end_pts[i] = vr_u16(q + (size_t)i * 2u);
  }

  uint16_t instruction_len = vr_u16(q + n * 2u);
  q += n * 2u + 2u;
  if (q + instruction_len > end) return VR_ERR_INVALID_FONT;
  q += instruction_len;

  uint16_t points = out->contour_end_pts[n - 1] + 1;
  out->point_count = points;
  out->point_count_alloc = points;
  out->x = (int16_t*)vr_calloc(face, points, sizeof(int16_t), 8u);
  out->y = (int16_t*)vr_calloc(face, points, sizeof(int16_t), 8u);
  out->on_curve = (bool*)vr_calloc(face, points, sizeof(bool), 8u);
  if (!out->x || !out->y || !out->on_curve) {
    return VR_ERR_OOM;
  }

  uint8_t* flags = (uint8_t*)vr_alloc(face, points, 8u);
  if (!flags) {
    return VR_ERR_OOM;
  }

  for (uint16_t i = 0; i < points;) {
    if (q >= end) {
      vr_dealloc(face, flags, points, 8u);
      return VR_ERR_INVALID_FONT;
    }
    uint8_t flag = *q++;
    uint16_t repeat = 1u;
    if ((flag & VR_GLYF_FLAG_REPEATED) != 0u) {
      if (q >= end) {
        vr_dealloc(face, flags, points, 8u);
        return VR_ERR_INVALID_FONT;
      }
      repeat = (uint16_t)((uint16_t)(*q++) + 1u);
    }
    for (uint16_t r = 0u; r < repeat && i < points; ++r, ++i) {
      flags[i] = flag;
    }
  }

  int16_t cx = 0;
  int16_t cy = 0;
  for (uint16_t i = 0; i < points; ++i) {
    uint8_t flag = flags[i];
    if (flag & VR_GLYF_FLAG_X_SHORT) {
      if (q >= end) {
        vr_dealloc(face, flags, points, 8u);
        return VR_ERR_INVALID_FONT;
      }
      uint16_t raw = (uint16_t)*q++;
      int16_t delta = (int16_t)(flag & VR_GLYF_FLAG_X_SIGNED ? raw : (uint16_t)(~raw + 1u));
      cx += delta;
    } else if ((flag & VR_GLYF_FLAG_X_SIGNED) != 0u) {
      cx += 0;
    } else {
      if ((q + 1) >= end) {
        vr_dealloc(face, flags, points, 8u);
        return VR_ERR_INVALID_FONT;
      }
      cx += (int16_t)vr_i16(q);
      q += 2;
    }
    out->x[i] = cx;
    out->on_curve[i] = (flag & VR_GLYF_FLAG_ON_CURVE) != 0;
  }

  for (uint16_t i = 0; i < points; ++i) {
    uint8_t flag = flags[i];
    if (flag & VR_GLYF_FLAG_Y_SHORT) {
      if (q >= end) {
        vr_dealloc(face, flags, points, 8u);
        return VR_ERR_INVALID_FONT;
      }
      uint16_t raw = (uint16_t)*q++;
      int16_t delta = (int16_t)(flag & VR_GLYF_FLAG_Y_SIGNED ? raw : (uint16_t)(~raw + 1u));
      cy += delta;
    } else if ((flag & VR_GLYF_FLAG_Y_SIGNED) != 0u) {
      cy += 0;
    } else {
      if ((q + 1) >= end) {
        vr_dealloc(face, flags, points, 8u);
        return VR_ERR_INVALID_FONT;
      }
      cy += (int16_t)vr_i16(q);
      q += 2;
    }
    out->y[i] = cy;
  }

  vr_dealloc(face, flags, points, 8u);
  out->has_phantom_points = false;
  if (out->point_count > 0) {
    out->x_min = out->x[0];
    out->y_min = out->y[0];
    out->x_max = out->x[0];
    out->y_max = out->y[0];
    for (uint16_t i = 1; i < points; ++i) {
      int16_t x = out->x[i];
      int16_t y = out->y[i];
      if (x < out->x_min) out->x_min = x;
      if (x > out->x_max) out->x_max = x;
      if (y < out->y_min) out->y_min = y;
      if (y > out->y_max) out->y_max = y;
    }
  }
  return VR_OK;
}

vr_status_t vr_parse_composite_glyph(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  vr_glyph_outline_t* out,
  uint16_t depth) {
  if (depth > VR_RASTER_MAX_DEPTH) {
    return VR_ERR_INVALID_FONT;
  }
  const uint8_t* q = p + 10;
  uint16_t flags = 0;
  do {
    if (q + 4 > end) return VR_ERR_INVALID_FONT;
    flags = vr_u16(q);
    uint16_t gid = vr_u16(q + 2);
    q += 4;

    int16_t arg1 = 0;
    int16_t arg2 = 0;
    if (flags & VR_GLYF_COMPOSITE_ARG_1_AND_2_ARE_WORDS) {
      if (q + 4 > end) return VR_ERR_INVALID_FONT;
      arg1 = (int16_t)vr_u16(q); q += 2;
      arg2 = (int16_t)vr_u16(q); q += 2;
    } else {
      if (q + 2 > end) return VR_ERR_INVALID_FONT;
      arg1 = (int8_t)*q++;
      arg2 = (int8_t)*q++;
    }

    if ((flags & VR_GLYF_COMPOSITE_ARGS_ARE_XY_VALUES) == 0) {
      arg1 = 0;
      arg2 = 0;
    }

    float xx = 1.0f;
    float yx = 0.0f;
    float xy = 0.0f;
    float yy = 1.0f;

    if (flags & VR_GLYF_COMPOSITE_WE_HAVE_A_SCALE) {
      if (q + 2 > end) return VR_ERR_INVALID_FONT;
      float s = vr_f2dot14_to_float(vr_u16(q));
      q += 2;
      xx = s;
      yy = s;
    } else if (flags & VR_GLYF_COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE) {
      if (q + 4 > end) return VR_ERR_INVALID_FONT;
      xx = vr_f2dot14_to_float(vr_u16(q));
      yy = vr_f2dot14_to_float(vr_u16(q + 2));
      q += 4;
    } else if (flags & VR_GLYF_COMPOSITE_WE_HAVE_A_TWO_BY_TWO) {
      if (q + 8 > end) return VR_ERR_INVALID_FONT;
      xx = vr_f2dot14_to_float(vr_u16(q));
      xy = vr_f2dot14_to_float(vr_u16(q + 2));
      yx = vr_f2dot14_to_float(vr_u16(q + 4));
      yy = vr_f2dot14_to_float(vr_u16(q + 6));
      q += 8;
    }

    vr_glyph_outline_t comp;
    vr_zero(&comp, sizeof(comp));
    vr_status_t st = vr_load_glyph_outline_internal(face, gid, &comp, (uint16_t)(depth + 1));
    if (st == VR_OK) {
      st = vr_append_transformed_points(face, out, &comp, xx, yx, xy, yy, arg1, arg2);
    } else if (st != VR_ERR_UNSUPPORTED) {
      vr_free_outline(face, &comp);
      return st;
    }
    vr_free_outline(face, &comp);
    if (st == VR_ERR_UNSUPPORTED) {
      continue;
    }
    if (st != VR_OK) {
      return st;
    }

    if (flags & VR_GLYF_COMPOSITE_WE_HAVE_INSTRUCTIONS) {
      if (q + 2 > end) return VR_ERR_INVALID_FONT;
      uint16_t instruction_len = vr_u16(q);
      q += 2;
      if (q + instruction_len > end) return VR_ERR_INVALID_FONT;
      q += instruction_len;
    }
  } while ((flags & VR_GLYF_COMPOSITE_MORE_COMPONENTS) != 0 && q <= end);

  return VR_OK;
}
vr_status_t vr_load_glyph_outline_internal(
  const vr_font_face_t* face,
  uint16_t glyph_id,
  vr_glyph_outline_t* out,
  uint16_t depth) {
  if (!face || !face->glyf || glyph_id >= face->num_glyphs || !out) return VR_ERR_INVALID_FONT;
  if (depth > 16) return VR_ERR_INVALID_FONT;

  uint32_t off = face->loca_offsets[glyph_id];
  uint32_t next_off = face->loca_offsets[glyph_id + 1];
  if (off > next_off || off >= (uint32_t)(face->file_size) || next_off > (uint32_t)(face->file_size)) {
    return VR_ERR_INVALID_FONT;
  }
  if (off == next_off) {
    out->number_of_contours = 0u;
    out->point_count = 0u;
    out->point_count_alloc = 0u;
    return VR_OK;
  }

  const uint8_t* p = face->glyf + off;
  int16_t number_of_contours = (int16_t)vr_i16(p);
  int32_t x_min = vr_i16(p + 2);
  int32_t y_min = vr_i16(p + 4);
  int32_t x_max = vr_i16(p + 6);
  int32_t y_max = vr_i16(p + 8);

  vr_zero(out, sizeof(*out));
  out->x_min = x_min;
  out->y_min = y_min;
  out->x_max = x_max;
  out->y_max = y_max;

  if (number_of_contours == 0) {
    out->number_of_contours = 0;
    out->point_count = 0;
    out->point_count_alloc = 0;
    return VR_OK;
  }

  if (number_of_contours > 0) {
    out->number_of_contours = (uint16_t)number_of_contours;
    out->contour_end_pts = (uint16_t*)vr_calloc(face, (size_t)number_of_contours, sizeof(uint16_t), 8u);
    if (!out->contour_end_pts) return VR_ERR_OOM;
    const uint8_t* end = face->glyf + next_off;
    vr_status_t status = vr_parse_simple_glyph(face, p, end, number_of_contours, out);
    if (status != VR_OK) {
      vr_free_outline(face, out);
      return status;
    }
    return VR_OK;
  }

  return vr_parse_composite_glyph(face, p, face->glyf + next_off, out, depth);
}

vr_status_t vr_load_glyph_outline(const vr_font_face_t* face, uint16_t glyph_id, vr_glyph_outline_t* out) {
  if (!face || !out) return VR_ERR_INVALID_FONT;
  vr_zero(out, sizeof(*out));
  return vr_load_glyph_outline_internal(face, glyph_id, out, 0);
}
