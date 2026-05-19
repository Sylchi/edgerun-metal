#ifndef VR_FONT_RASTER_INTERNAL_H
#define VR_FONT_RASTER_INTERNAL_H

#include "vr_font_internal.h"

#include <float.h>
#include <limits.h>

#define VR_GLYF_COMPOSITE_ARGS_ARE_XY_VALUES 0x0002u
#define VR_GLYF_COMPOSITE_ARG_1_AND_2_ARE_WORDS 0x0001u
#define VR_GLYF_COMPOSITE_MORE_COMPONENTS 0x0020u
#define VR_GLYF_COMPOSITE_WE_HAVE_A_SCALE 0x0008u
#define VR_GLYF_COMPOSITE_WE_HAVE_AN_X_AND_Y_SCALE 0x0040u
#define VR_GLYF_COMPOSITE_WE_HAVE_A_TWO_BY_TWO 0x0080u
#define VR_GLYF_COMPOSITE_WE_HAVE_INSTRUCTIONS 0x0100u

#define VR_GLYF_FLAG_REPEATED 0x08u
#define VR_GLYF_FLAG_X_SHORT 0x02u
#define VR_GLYF_FLAG_Y_SHORT 0x04u
#define VR_GLYF_FLAG_ON_CURVE 0x01u
#define VR_GLYF_FLAG_X_SIGNED 0x10u
#define VR_GLYF_FLAG_Y_SIGNED 0x20u

static const float VR_F2DOT14_SCALE = 16384.0f;
static const size_t VR_RASTER_SEGMENT_INITIAL_CAP = 64u;
static const size_t VR_RASTER_OUTLINE_POINT_INITIAL_CAP = 16u;
static const float VR_RASTER_SEGMENT_TOLERANCE = 1e-7f;
static const int VR_RASTER_ALPHA_SUPERSAMPLE = 4;
static const int VR_RASTER_MSDF_SUPERSAMPLE = 8;
static const float VR_RASTER_SDF_SPREAD = 1.0f;
static const float VR_RASTER_SDF_MID_ALPHA = 128.0f;
static const float VR_RASTER_SDF_EDGE_SCALE = 255.0f;
static const float VR_RASTER_SDF_SAMPLE_OFFSET = 0.5f;
static const float VR_RASTER_SDF_PADDING_SCALE = 1.0f;
static const int VR_RASTER_PADDING = 2;
static const int VR_RASTER_MAX_DEPTH = 8;
static const int VR_RASTER_TESSELLATION_SOFT_LIMIT = 12;
static const int VR_RASTER_TESSELLATION_HARD_LIMIT = 16;
static const float VR_RASTER_QUAD_BEZIER_TOLERANCE = 0.01f;
static const int VR_RASTER_CURVE_NEWTON_STEPS = 8;
static const int VR_RASTER_CURVE_DISTANCE_SAMPLES = 16;
static const float VR_RASTER_CURVE_NEWTON_EPSILON = 1e-5f;
static const float VR_RASTER_CURVE_LINEAR_TOLERANCE = 1e-12f;
static const float VR_RASTER_CURVE_CROSSING_EPSILON = 1e-7f;
#define VR_RASTER_MSDF_CHANNEL_COUNT 3u
static const float VR_RASTER_MSDF_CHANNEL_SCALE = 3.0f;
static const float VR_RASTER_MSDF_CHANNEL_HALF_BIN = 0.5f / VR_RASTER_MSDF_CHANNEL_SCALE;
static const float VR_RASTER_MSDF_MISSING_CHANNEL_EPSILON = 1e-6f;
static const uint8_t VR_RASTER_MSDF_CHANNEL_NEXT[VR_RASTER_MSDF_CHANNEL_COUNT] = {
  1u,
  2u,
  0u,
};
static const uint8_t VR_RASTER_MSDF_CHANNEL_PREV[VR_RASTER_MSDF_CHANNEL_COUNT] = {
  2u,
  0u,
  1u,
};
static const float VR_RASTER_MSDF_PI = 3.14159265359f;
static const float VR_RASTER_MSDF_TWO_PI = 6.28318530718f;
static const float VR_RASTER_ALPHA_MIN = 0.0f;
static const float VR_RASTER_ALPHA_MAX = 255.0f;
static const uint32_t VR_RASTER_MSDF_COLOR_INF_COST = 0x3FFFFFFFu;
static const uint8_t VR_RASTER_MSDF_CHANNEL_MAX_COST = 1u;
static const uint8_t VR_RASTER_USE_QUADRATIC_WINDING = 1u;

typedef struct {
  float x0;
  float y0;
  float x1;
  float y1;
  float x2;
  float y2;
} vr_raster_curve_t;

typedef enum {
  VR_MSDF_EDGE_KIND_LINE = 0u,
  VR_MSDF_EDGE_KIND_QUAD = 1u
} vr_msdf_edge_kind_t;

typedef struct {
  vr_msdf_edge_kind_t kind;
  vr_outline_point_t p0;
  vr_outline_point_t p1;
  vr_outline_point_t p2;
} vr_msdf_outline_edge_t;

vr_status_t vr_push_msdf_edge(
  const vr_font_face_t* face,
  vr_msdf_outline_edge_t** edges,
  size_t* edge_count,
  size_t* edge_cap,
  vr_msdf_edge_kind_t kind,
  vr_outline_point_t p0,
  vr_outline_point_t p1,
  vr_outline_point_t p2);
vr_status_t vr_ensure_msdf_edges_capacity(const vr_font_face_t* face, vr_msdf_outline_edge_t** edges, size_t* edge_cap, size_t needed);
vr_status_t vr_line_segments_from_quad(const vr_font_face_t* face, const vr_outline_point_t p0, const vr_outline_point_t p1, const vr_outline_point_t p2,
  vr_segment_t** segs,
  size_t* count,
  size_t* cap,
  float tolerance_sq,
  int depth,
  uint8_t segment_color,
  uint8_t** seg_colors,
  size_t* seg_color_count,
  size_t* seg_color_cap,
  bool using_msdf);
vr_status_t vr_ensure_curves_capacity(const vr_font_face_t* face, vr_raster_curve_t** curves, size_t* curve_cap, size_t needed);
vr_status_t vr_push_curve(
  const vr_font_face_t* face,
  vr_raster_curve_t** curves,
  size_t* curve_count,
  size_t* curve_cap,
  float x0,
  float y0,
  float x1,
  float y1,
  float x2,
  float y2);
vr_status_t vr_ensure_u8_capacity(const vr_font_face_t* face, uint8_t** values, size_t* values_cap, size_t needed);
vr_status_t vr_push_msdf_segment_color(const vr_font_face_t* face, uint8_t** seg_colors, size_t* seg_color_count, size_t* seg_color_cap, uint8_t color);
vr_status_t vr_push_msdf_curve_color(const vr_font_face_t* face, uint8_t** curve_colors, size_t* curve_color_count, size_t* curve_color_cap, uint8_t color);
uint8_t vr_msdf_edge_color(float dx, float dy, size_t fallback_index);
vr_status_t vr_msdf_color_edges_cycle(
  const vr_font_face_t* face,
  const vr_msdf_outline_edge_t* edges,
  size_t edge_count,
  uint8_t* out_colors);
uint8_t vr_msdf_color_cost(uint8_t color, uint8_t preferred_color);
int vr_quadratic_crossing_sign(float x, float y, const vr_raster_curve_t* curve);
void vr_msdf_signed_distances_to_outline(
  float px,
  float py,
  const vr_segment_t* segments,
  size_t seg_count,
  const uint8_t* seg_colors,
  const vr_raster_curve_t* curves,
  size_t curve_count,
  const uint8_t* curve_colors,
  float out_distances[VR_RASTER_MSDF_CHANNEL_COUNT]);
vr_status_t vr_rasterize_outline_with_mode(
  const vr_font_face_t* face,
  const vr_glyph_outline_t* outline,
  vr_font_atlas_format_t atlas_format,
  uint8_t** out_bitmap,
  int* out_w,
  int* out_h,
  int* out_left,
  int* out_top);
float vr_f2dot14_to_float(uint16_t v);
void* vr_raster_realloc_array(const vr_font_face_t* face, void* ptr, size_t old_cap, size_t new_cap, size_t elem_size);
void vr_raster_free_array(const vr_font_face_t* face, void* ptr, size_t cap, size_t elem_size);
vr_status_t vr_load_glyph_outline_internal(
  const vr_font_face_t* face,
  uint16_t glyph_id,
  vr_glyph_outline_t* out,
  uint16_t depth);
vr_status_t vr_ensure_segments_capacity(const vr_font_face_t* face, vr_segment_t** segs, size_t* seg_cap, size_t needed);
vr_status_t vr_push_segment(const vr_font_face_t* face, vr_segment_t** segs, size_t* seg_count, size_t* seg_cap, float x1, float y1, float x2, float y2);
float vr_msdf_resolve_missing_channel_distance(
  const bool channel_present[VR_RASTER_MSDF_CHANNEL_COUNT],
  const float distances[VR_RASTER_MSDF_CHANNEL_COUNT],
  uint8_t color);
vr_status_t vr_append_transformed_points(
  const vr_font_face_t* face,
  vr_glyph_outline_t* dst,
  const vr_glyph_outline_t* src,
  float xx,
  float yx,
  float xy,
  float yy,
  int16_t dx,
  int16_t dy);
vr_status_t vr_append_outline_point(
  const vr_font_face_t* face,
  vr_outline_point_t** points,
  size_t* count,
  size_t* cap,
  float x,
  float y,
  bool on_curve);
vr_status_t vr_parse_simple_glyph(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  int16_t contours,
  vr_glyph_outline_t* out);
vr_status_t vr_parse_composite_glyph(
  const vr_font_face_t* face,
  const uint8_t* p,
  const uint8_t* end,
  vr_glyph_outline_t* out,
  uint16_t depth);
vr_status_t vr_collect_contour_points(
  const vr_font_face_t* face,
  const vr_glyph_outline_t* outline,
  uint16_t start,
  uint16_t end,
  float scale,
  vr_outline_point_t** out_points,
  size_t* out_count,
  size_t* out_cap);
vr_status_t vr_emit_contour_segments(
  const vr_font_face_t* face,
  const vr_outline_point_t* points,
  size_t point_count,
  vr_segment_t** segs,
  size_t* seg_count,
  size_t* seg_cap,
  uint8_t** seg_colors,
  size_t* seg_color_count,
  size_t* seg_color_cap,
  vr_raster_curve_t** curves,
  size_t* curve_count,
  size_t* curve_cap,
  uint8_t** curve_colors,
  size_t* curve_color_count,
  size_t* curve_color_cap,
  bool using_msdf);
float vr_sample_offset(int index, int samples);
int vr_point_inside_outline(
  float px,
  float py,
  const vr_segment_t* segments,
  size_t seg_count,
  const vr_raster_curve_t* curves,
  size_t curve_count);
uint8_t vr_alpha_from_signed_distance(float signed_distance, float spread);
float vr_sdf_spread_from_padding(uint32_t atlas_pad);

#endif
