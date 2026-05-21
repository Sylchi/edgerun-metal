#include "vr_font_raster_internal.h"

vr_status_t vr_free_bitmap(const vr_font_face_t* face, uint8_t* bitmap, int width, int height, vr_font_atlas_format_t atlas_format) {
  if (!bitmap) return VR_OK;
  if (!face || width <= 0 || height <= 0) return VR_ERR_INVALID_FONT;

  size_t channels = 0u;
  switch (atlas_format) {
    case VR_FONT_ATLAS_FORMAT_ALPHA8:
      channels = 1u;
      break;
    case VR_FONT_ATLAS_FORMAT_MSDF_RGB:
      channels = VR_RASTER_MSDF_CHANNEL_COUNT;
      break;
    case VR_FONT_ATLAS_FORMAT_UNSPECIFIED:
    default:
      return VR_ERR_INVALID_FONT;
  }

  size_t w = (size_t)width;
  size_t h = (size_t)height;
  if (w > SIZE_MAX / h || (w * h) > SIZE_MAX / channels) return VR_ERR_INVALID_FONT;
  vr_dealloc(face, bitmap, w * h * channels, 8u);
  return VR_OK;
}

//@optimizer-ignore-function glyph rasterization must visit each output pixel and each configured subpixel sample
vr_status_t vr_rasterize_outline_with_mode(
  const vr_font_face_t* face,
  const vr_glyph_outline_t* outline,
  vr_font_atlas_format_t atlas_format,
  uint8_t** out_bitmap,
  int* out_w,
  int* out_h,
  int* out_left,
  int* out_top) {
  size_t out_channels = 0u;
  switch (atlas_format) {
    case VR_FONT_ATLAS_FORMAT_ALPHA8:
      out_channels = 1u;
      break;
    case VR_FONT_ATLAS_FORMAT_MSDF_RGB:
      out_channels = 3u;
      break;
    case VR_FONT_ATLAS_FORMAT_UNSPECIFIED:
      return VR_ERR_INVALID_FONT;
    default:
      return VR_ERR_INVALID_FONT;
  }

  if (!face || !outline || !out_bitmap || !out_w || !out_h) return VR_ERR_INVALID_FONT;
  if (outline->point_count <= 0 || outline->number_of_contours == 0) return VR_ERR_UNSUPPORTED;

  float scale = face->cfg.px_size / (float)face->units_per_em;

  int x0 = (int)vr_floorf((float)outline->x_min * scale);
  int y0 = (int)vr_floorf((float)outline->y_min * scale);
  int x1 = (int)vr_ceilf((float)outline->x_max * scale);
  int y1 = (int)vr_ceilf((float)outline->y_max * scale);

  int base_w = x1 - x0;
  int base_h = y1 - y0;
  if (base_w <= 0 || base_h <= 0) return VR_ERR_UNSUPPORTED;

  float sdf_spread = vr_sdf_spread_from_padding(face->cfg.atlas_pad);
  int pad = (int)vr_ceilf(sdf_spread * VR_RASTER_SDF_PADDING_SCALE);
  if (pad < VR_RASTER_PADDING) {
    pad = VR_RASTER_PADDING;
  }

  int w = base_w + (pad * 2);
  int h = base_h + (pad * 2);
  if (w <= 0 || h <= 0) return VR_ERR_UNSUPPORTED;

  const bool using_msdf = (atlas_format == VR_FONT_ATLAS_FORMAT_MSDF_RGB);
  const int ss = using_msdf ? VR_RASTER_MSDF_SUPERSAMPLE : VR_RASTER_ALPHA_SUPERSAMPLE;
  const float inv_ss = 1.0f / (float)(ss * ss);
  const float sdf_pad_f = sdf_spread * VR_RASTER_SDF_PADDING_SCALE;
  float sample_offsets_x[ss];
  float sample_offsets_y[ss];
  for (int s = 0; s < ss; ++s) {
    float offset = vr_sample_offset(s, ss);
    sample_offsets_x[s] = offset;
    sample_offsets_y[s] = offset;
  }

  vr_segment_t* segments = NULL;
  size_t seg_count = 0;
  size_t seg_cap = 0;
  uint8_t* seg_colors = NULL;
  size_t seg_color_count = 0u;
  size_t seg_color_cap = 0u;
  vr_raster_curve_t* curves = NULL;
  size_t curve_count = 0;
  size_t curve_cap = 0;
  uint8_t* curve_colors = NULL;
  size_t curve_color_count = 0u;
  size_t curve_color_cap = 0u;

  for (uint16_t c = 0; c < outline->number_of_contours; ++c) {
    uint16_t start = (c == 0) ? 0 : (outline->contour_end_pts[c - 1] + 1);
    uint16_t end = outline->contour_end_pts[c];
    uint16_t count = (end - start + 1);
    if (count < 2) continue;

    vr_outline_point_t* contour_points = NULL;
    size_t contour_point_count = 0u;
    size_t contour_point_cap = 0u;
    vr_status_t collect_status = vr_collect_contour_points(face, outline, start, end, scale, &contour_points, &contour_point_count, &contour_point_cap);
    if (collect_status != VR_OK) {
      vr_raster_free_array(face, segments, seg_cap, sizeof(*segments));
      vr_raster_free_array(face, seg_colors, seg_color_cap, sizeof(*seg_colors));
      vr_raster_free_array(face, curves, curve_cap, sizeof(*curves));
      vr_raster_free_array(face, curve_colors, curve_color_cap, sizeof(*curve_colors));
      return collect_status;
    }

    vr_status_t emit_status = vr_emit_contour_segments(
      face,
      contour_points,
      contour_point_count,
      &segments,
      &seg_count,
      &seg_cap,
      &seg_colors,
      &seg_color_count,
      &seg_color_cap,
      &curves,
      &curve_count,
      &curve_cap,
      &curve_colors,
      &curve_color_count,
      &curve_color_cap,
      using_msdf);
    vr_raster_free_array(face, contour_points, contour_point_cap, sizeof(*contour_points));
    if (emit_status != VR_OK) {
      vr_raster_free_array(face, segments, seg_cap, sizeof(*segments));
      vr_raster_free_array(face, seg_colors, seg_color_cap, sizeof(*seg_colors));
      vr_raster_free_array(face, curves, curve_cap, sizeof(*curves));
      vr_raster_free_array(face, curve_colors, curve_color_cap, sizeof(*curve_colors));
      return emit_status;
    }
  }

  if (
    (seg_count == 0u && curve_count == 0u) ||
    (!segments && seg_count > 0u) ||
    (!curves && curve_count > 0u) ||
    (using_msdf && (!seg_colors && seg_color_count > 0u)) ||
    (using_msdf && (!curve_colors && curve_color_count > 0u))) {
    vr_raster_free_array(face, segments, seg_cap, sizeof(*segments));
    vr_raster_free_array(face, seg_colors, seg_color_cap, sizeof(*seg_colors));
    vr_raster_free_array(face, curves, curve_cap, sizeof(*curves));
    vr_raster_free_array(face, curve_colors, curve_color_cap, sizeof(*curve_colors));
    return VR_ERR_UNSUPPORTED;
  }

  size_t pixel_count = (size_t)w * (size_t)h * out_channels;
  uint8_t* bitmap = (uint8_t*)vr_calloc(face, pixel_count, 1, 8u);
  if (!bitmap) {
    vr_raster_free_array(face, segments, seg_cap, sizeof(*segments));
    vr_raster_free_array(face, seg_colors, seg_color_cap, sizeof(*seg_colors));
    vr_raster_free_array(face, curves, curve_cap, sizeof(*curves));
    vr_raster_free_array(face, curve_colors, curve_color_cap, sizeof(*curve_colors));
    return VR_ERR_OOM;
  }

  float sx_base = (float)x0 - (float)pad;
  float sy_base = (float)(y1 - 1 + pad);
  for (int y = 0; y < h; ++y) {
    float fy = sy_base - (float)y;
    for (int x = 0; x < w; ++x) {
      float fx = sx_base + (float)x;
      size_t out_idx = ((size_t)y * (size_t)w + (size_t)x);

      if (using_msdf) {
        float msdf_total[VR_RASTER_MSDF_CHANNEL_COUNT] = {0.0f};
        for (int sy = 0; sy < ss; ++sy) {
          float sample_fy = fy + sample_offsets_y[sy];
          for (int sx = 0; sx < ss; ++sx) {
            float sample_fx = fx + sample_offsets_x[sx];
            float sample_distances[VR_RASTER_MSDF_CHANNEL_COUNT];
            vr_msdf_signed_distances_to_outline(
              sample_fx,
              sample_fy,
              segments,
              seg_count,
              seg_colors,
              curves,
              curve_count,
              curve_colors,
              sample_distances);
            msdf_total[0u] += sample_distances[0u];
            msdf_total[1u] += sample_distances[1u];
            msdf_total[2u] += sample_distances[2u];
          }
        }

        size_t pixel_idx = out_idx * out_channels;
        for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
          float signed_distance = msdf_total[color] * inv_ss;
          bitmap[pixel_idx + (size_t)color] = vr_alpha_from_signed_distance(signed_distance, sdf_pad_f);
        }
      } else {
        int covered_samples = 0;
        for (int sy = 0; sy < ss; ++sy) {
          float sample_fy = fy + sample_offsets_y[sy];
          for (int sx = 0; sx < ss; ++sx) {
            float sample_fx = fx + sample_offsets_x[sx];
            covered_samples += vr_point_inside_outline(
              sample_fx,
              sample_fy,
              segments,
              seg_count,
              curves,
              curve_count);
          }
        }
        bitmap[out_idx] = vr_u8_from_unitf((float)covered_samples * inv_ss);
      }
    }
  }

  vr_raster_free_array(face, segments, seg_cap, sizeof(*segments));
  vr_raster_free_array(face, seg_colors, seg_color_cap, sizeof(*seg_colors));
  vr_raster_free_array(face, curves, curve_cap, sizeof(*curves));
  vr_raster_free_array(face, curve_colors, curve_color_cap, sizeof(*curve_colors));
  *out_bitmap = bitmap;
  *out_w = w;
  *out_h = h;
  *out_left = x0 - pad;
  *out_top = y1 - 1 + pad;

  return VR_OK;
}
