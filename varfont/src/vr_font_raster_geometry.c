#include "vr_font_raster_internal.h"

int vr_segment_crossing_sign(float x, float y, const vr_segment_t* seg) {
  float y1 = seg->y1;
  float y2 = seg->y2;
  if (!((y1 <= y && y2 > y) || (y2 <= y && y1 > y))) {
    return 0;
  }

  float x1 = seg->x1;
  float x2 = seg->x2;
  float dy = y2 - y1;
  if (vr_absf(dy) <= VR_RASTER_SEGMENT_TOLERANCE) {
    return 0;
  }

  float x_int = (x2 - x1) * (y - y1) / dy + x1;
  if (x >= x_int) {
    return 0;
  }
  return (y2 > y1) ? 1 : -1;
}

int vr_quadratic_crossing_sign(float x, float y, const vr_raster_curve_t* curve) {
  if (!curve) {
    return 0;
  }

  float y0 = curve->y0;
  float y1 = curve->y1;
  float y2 = curve->y2;
  if (!((y0 <= y && y2 > y) || (y2 <= y && y0 > y))) {
    return 0;
  }

  float a = y0 - 2.0f * y1 + y2;
  float b = 2.0f * (y1 - y0);
  float c = y0 - y;
  float disc = b * b - 4.0f * a * c;
  if (disc < 0.0f) {
    return 0;
  }

  float sqrt_disc = vr_sqrtf(disc);
  int winding = 0;
  float inv2a = (vr_absf(a) <= VR_RASTER_SEGMENT_TOLERANCE) ? 0.0f : (0.5f / a);
  float invb = (vr_absf(b) <= VR_RASTER_SEGMENT_TOLERANCE) ? 0.0f : (1.0f / b);

  float t_candidates[2u];
  size_t candidate_count = 0u;
  if (vr_absf(a) > VR_RASTER_SEGMENT_TOLERANCE) {
    float t0 = (-b - sqrt_disc) * inv2a;
    float t1 = (-b + sqrt_disc) * inv2a;
    if (t0 > VR_RASTER_CURVE_CROSSING_EPSILON && t0 < 1.0f - VR_RASTER_CURVE_CROSSING_EPSILON) {
      t_candidates[candidate_count++] = t0;
    }
    if (t1 > VR_RASTER_CURVE_CROSSING_EPSILON && t1 < 1.0f - VR_RASTER_CURVE_CROSSING_EPSILON) {
      if ((candidate_count == 0u) || (vr_absf(t1 - t_candidates[0u]) > VR_RASTER_CURVE_CROSSING_EPSILON)) {
        t_candidates[candidate_count++] = t1;
      }
    }
  } else if (vr_absf(b) > VR_RASTER_SEGMENT_TOLERANCE) {
    float t = -c * invb;
    if (t > VR_RASTER_CURVE_CROSSING_EPSILON && t < 1.0f - VR_RASTER_CURVE_CROSSING_EPSILON) {
      t_candidates[candidate_count++] = t;
    }
  }

  if (candidate_count == 0u) {
    return 0;
  }

  for (size_t i = 0u; i < candidate_count; ++i) {
    float t = t_candidates[i];
    float omt = 1.0f - t;
    float x_int = omt * omt * curve->x0 + 2.0f * omt * t * curve->x1 + t * t * curve->x2;
    if (x >= x_int) {
      continue;
    }

    float dy_dt = 2.0f * (omt * (y1 - y0) + t * (y2 - y1));
    if (vr_absf(dy_dt) <= VR_RASTER_SEGMENT_TOLERANCE) {
      continue;
    }
    winding += (dy_dt > 0.0f) ? 1 : -1;
  }
  return winding;
}

float vr_sample_offset(int index, int samples) {
  return (float)(index + 0.5f) / (float)samples - VR_RASTER_SDF_SAMPLE_OFFSET;
}

float vr_segment_distance_sq(float px, float py, const vr_segment_t* seg) {
  float vx = seg->x2 - seg->x1;
  float vy = seg->y2 - seg->y1;
  float wx = px - seg->x1;
  float wy = py - seg->y1;

  float seg_len_sq = vx * vx + vy * vy;
  float t;
  if (seg_len_sq <= VR_RASTER_SEGMENT_TOLERANCE) {
    t = 0.0f;
  } else {
    t = (wx * vx + wy * vy) / seg_len_sq;
  }

  t = vr_clampf(t, 0.0f, 1.0f);
  float proj_x = seg->x1 + t * vx;
  float proj_y = seg->y1 + t * vy;
  float dx = px - proj_x;
  float dy = py - proj_y;
  return dx * dx + dy * dy;
}

float vr_quadratic_point_x(float t, const vr_raster_curve_t* curve) {
  float omt = 1.0f - t;
  float t2 = t * t;
  float omt2 = omt * omt;
  return omt2 * curve->x0 + 2.0f * omt * t * curve->x1 + t2 * curve->x2;
}

float vr_quadratic_point_y(float t, const vr_raster_curve_t* curve) {
  float omt = 1.0f - t;
  float t2 = t * t;
  float omt2 = omt * omt;
  return omt2 * curve->y0 + 2.0f * omt * t * curve->y1 + t2 * curve->y2;
}

float vr_quadratic_point_distance_sq(float px, float py, const vr_raster_curve_t* curve, float t) {
  float x = vr_quadratic_point_x(t, curve);
  float y = vr_quadratic_point_y(t, curve);
  float dx = px - x;
  float dy = py - y;
  return dx * dx + dy * dy;
}

//@optimizer-ignore-function quadratic distance search samples fixed curve points and Newton-refines candidates
float vr_quadratic_distance_sq(float px, float py, const vr_raster_curve_t* curve) {
  float ax = curve->x0 - 2.0f * curve->x1 + curve->x2;
  float ay = curve->y0 - 2.0f * curve->y1 + curve->y2;
  float bx = 2.0f * (curve->x1 - curve->x0);
  float by = 2.0f * (curve->y1 - curve->y0);
  float cx = curve->x0 - px;
  float cy = curve->y0 - py;

  float quad_accel = ax * ax + ay * ay;
  if (quad_accel <= VR_RASTER_CURVE_LINEAR_TOLERANCE) {
    return vr_segment_distance_sq(px, py, &(vr_segment_t){curve->x0, curve->y0, curve->x2, curve->y2});
  }

  float c0 = cx * bx + cy * by;
  float c1 = 2.0f * (cx * ax + cy * ay) + bx * bx + by * by;
  float c2 = 2.0f * (bx * ax + by * ay);
  float c3 = 2.0f * quad_accel;

  float best_sq = vr_quadratic_point_distance_sq(px, py, curve, 0.0f);

  float end_sq = vr_quadratic_point_distance_sq(px, py, curve, 1.0f);
  if (end_sq < best_sq) {
    best_sq = end_sq;
  }

  for (int sample = 0; sample <= VR_RASTER_CURVE_DISTANCE_SAMPLES; ++sample) {
    float t = (float)sample / (float)VR_RASTER_CURVE_DISTANCE_SAMPLES;
    for (int step = 0; step < VR_RASTER_CURVE_NEWTON_STEPS; ++step) {
      float derivative = ((3.0f * c3 * t + 2.0f * c2) * t + c1) * t + c0;
      float derivative_slope = (3.0f * c3 * t + 2.0f * c2) * t + c1;
      if (vr_absf(derivative_slope) <= VR_RASTER_SEGMENT_TOLERANCE) {
        break;
      }
      float next_t = t - derivative / derivative_slope;
      if (next_t < 0.0f) {
        next_t = 0.0f;
      } else if (next_t > 1.0f) {
        next_t = 1.0f;
      }
      if (vr_absf(next_t - t) <= VR_RASTER_CURVE_NEWTON_EPSILON) {
        t = next_t;
        break;
      }
      t = next_t;
    }

    float sq = vr_quadratic_point_distance_sq(px, py, curve, t);
    if (sq < best_sq) {
      best_sq = sq;
    }
  }

  return best_sq;
}

int vr_point_inside_outline(
  float px,
  float py,
  const vr_segment_t* segments,
  size_t seg_count,
  const vr_raster_curve_t* curves,
  size_t curve_count) {
  int winding = 0;
  for (size_t s = 0u; s < seg_count; ++s) {
    winding += vr_segment_crossing_sign(px, py, &segments[s]);
  }
  for (size_t c = 0u; c < curve_count; ++c) {
    winding += vr_quadratic_crossing_sign(px, py, &curves[c]);
  }
  return winding != 0;
}

void vr_msdf_nearest_channel_distance_sq(
  float px,
  float py,
  const vr_segment_t* segments,
  const uint8_t* seg_colors,
  size_t seg_count,
  const vr_raster_curve_t* curves,
  const uint8_t* curve_colors,
  size_t curve_count,
  float out_channel_sq[VR_RASTER_MSDF_CHANNEL_COUNT],
  bool out_channel_present[VR_RASTER_MSDF_CHANNEL_COUNT],
  float* out_nearest_sq_all) {
  for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
    out_channel_sq[color] = FLT_MAX;
    out_channel_present[color] = false;
  }

  *out_nearest_sq_all = FLT_MAX;

  for (size_t s = 0u; s < seg_count; ++s) {
    float d_sq = vr_segment_distance_sq(px, py, &segments[s]);
    if (d_sq < *out_nearest_sq_all) {
      *out_nearest_sq_all = d_sq;
    }
    uint8_t color = seg_colors[s];
    if (color < VR_RASTER_MSDF_CHANNEL_COUNT && d_sq < out_channel_sq[color]) {
      out_channel_sq[color] = d_sq;
      out_channel_present[color] = true;
    }
  }

  for (size_t c = 0u; c < curve_count; ++c) {
    float d_sq = vr_quadratic_distance_sq(px, py, &curves[c]);
    if (d_sq < *out_nearest_sq_all) {
      *out_nearest_sq_all = d_sq;
    }
    uint8_t color = curve_colors[c];
    if (color < VR_RASTER_MSDF_CHANNEL_COUNT && d_sq < out_channel_sq[color]) {
      out_channel_sq[color] = d_sq;
      out_channel_present[color] = true;
    }
  }
}

void vr_msdf_signed_distances_to_outline(
  float px,
  float py,
  const vr_segment_t* segments,
  size_t seg_count,
  const uint8_t* seg_colors,
  const vr_raster_curve_t* curves,
  size_t curve_count,
  const uint8_t* curve_colors,
  float out_distances[VR_RASTER_MSDF_CHANNEL_COUNT]) {
  float nearest_sq_all = FLT_MAX;
  float nearest_channel_sq[VR_RASTER_MSDF_CHANNEL_COUNT];
  bool channel_present[VR_RASTER_MSDF_CHANNEL_COUNT];
  float distances[VR_RASTER_MSDF_CHANNEL_COUNT];
  vr_msdf_nearest_channel_distance_sq(
    px,
    py,
    segments,
    seg_colors,
    seg_count,
    curves,
    curve_colors,
    curve_count,
    nearest_channel_sq,
    channel_present,
    &nearest_sq_all);

  float fallback = vr_sqrtf(nearest_sq_all);
  if (!vr_float_is_finite(fallback)) {
    fallback = VR_RASTER_SEGMENT_TOLERANCE;
  }

  for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
    float nearest_sq = nearest_channel_sq[color];
    if (nearest_sq < FLT_MAX) {
      distances[color] = vr_sqrtf(nearest_sq);
    } else {
      distances[color] = fallback;
    }
  }

  bool all_missing = true;
  for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
    if (channel_present[color]) {
      all_missing = false;
      break;
    }
  }
  if (all_missing) {
    for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
      out_distances[color] = -fallback;
    }
    return;
  }

  for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
    if (!channel_present[color]) {
      distances[color] = vr_msdf_resolve_missing_channel_distance(
        channel_present,
        distances,
        color);
    }
  }

  int winding = 0;
  for (size_t s = 0u; s < seg_count; ++s) {
    winding += vr_segment_crossing_sign(px, py, &segments[s]);
  }
  if (VR_RASTER_USE_QUADRATIC_WINDING != 0u) {
    for (size_t c = 0u; c < curve_count; ++c) {
      winding += vr_quadratic_crossing_sign(px, py, &curves[c]);
    }
  }

  float sign = (winding == 0) ? -1.0f : 1.0f;
  out_distances[0u] = sign * distances[0u];
  out_distances[1u] = sign * distances[1u];
  out_distances[2u] = sign * distances[2u];
}

uint8_t vr_alpha_from_signed_distance(float signed_distance, float spread) {
  if (spread <= VR_RASTER_SEGMENT_TOLERANCE) {
    return 0u;
  }

  float normalized = (float)VR_RASTER_SDF_MID_ALPHA + (signed_distance * VR_RASTER_SDF_EDGE_SCALE) / spread;
  float clamped = vr_clampf(normalized, VR_RASTER_ALPHA_MIN, VR_RASTER_ALPHA_MAX);
  return (uint8_t)(clamped + 0.5f);
}

float vr_sdf_spread_from_padding(uint32_t atlas_pad) {
  float spread = VR_RASTER_SDF_SPREAD;
  if (atlas_pad > 0u && (float)atlas_pad > spread) {
    spread = (float)atlas_pad;
  }
  return spread;
}
