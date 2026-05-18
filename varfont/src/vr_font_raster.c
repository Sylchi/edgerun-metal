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

static vr_status_t vr_push_msdf_edge(
  const vr_font_face_t* face,
  vr_msdf_outline_edge_t** edges,
  size_t* edge_count,
  size_t* edge_cap,
  vr_msdf_edge_kind_t kind,
  vr_outline_point_t p0,
  vr_outline_point_t p1,
  vr_outline_point_t p2);
static vr_status_t vr_ensure_msdf_edges_capacity(const vr_font_face_t* face, vr_msdf_outline_edge_t** edges, size_t* edge_cap, size_t needed);
static vr_status_t vr_line_segments_from_quad(const vr_font_face_t* face, const vr_outline_point_t p0, const vr_outline_point_t p1, const vr_outline_point_t p2,
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
static vr_status_t vr_ensure_curves_capacity(const vr_font_face_t* face, vr_raster_curve_t** curves, size_t* curve_cap, size_t needed);
static vr_status_t vr_push_curve(
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
static vr_status_t vr_ensure_u8_capacity(const vr_font_face_t* face, uint8_t** values, size_t* values_cap, size_t needed);
static vr_status_t vr_push_msdf_segment_color(const vr_font_face_t* face, uint8_t** seg_colors, size_t* seg_color_count, size_t* seg_color_cap, uint8_t color);
static vr_status_t vr_push_msdf_curve_color(const vr_font_face_t* face, uint8_t** curve_colors, size_t* curve_color_count, size_t* curve_color_cap, uint8_t color);
static uint8_t vr_msdf_edge_color(float dx, float dy, size_t fallback_index);
static vr_status_t vr_msdf_color_edges_cycle(
  const vr_font_face_t* face,
  const vr_msdf_outline_edge_t* edges,
  size_t edge_count,
  uint8_t* out_colors);
static uint8_t vr_msdf_color_cost(uint8_t color, uint8_t preferred_color);
static int vr_quadratic_crossing_sign(float x, float y, const vr_raster_curve_t* curve);
static void vr_msdf_signed_distances_to_outline(
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

static float vr_f2dot14_to_float(uint16_t v) {
  return (float)(int16_t)v / VR_F2DOT14_SCALE;
}

static void* vr_raster_realloc_array(const vr_font_face_t* face, void* ptr, size_t old_cap, size_t new_cap, size_t elem_size) {
  if (elem_size != 0u && (old_cap > SIZE_MAX / elem_size || new_cap > SIZE_MAX / elem_size)) return NULL;
  return vr_realloc(face, ptr, old_cap * elem_size, new_cap * elem_size, 8u);
}

static void vr_raster_free_array(const vr_font_face_t* face, void* ptr, size_t cap, size_t elem_size) {
  if (elem_size != 0u && cap > SIZE_MAX / elem_size) return;
  vr_dealloc(face, ptr, cap * elem_size, 8u);
}

//@optimizer-ignore-function TrueType glyph outline loading must expand repeated flags and coordinate deltas point-by-point
static vr_status_t vr_load_glyph_outline_internal(
  const vr_font_face_t* face,
  uint16_t glyph_id,
  vr_glyph_outline_t* out,
  uint16_t depth);
static float vr_f2dot14_to_float(uint16_t v);

static vr_status_t vr_ensure_segments_capacity(const vr_font_face_t* face, vr_segment_t** segs, size_t* seg_cap, size_t needed) {
  if (*seg_cap >= needed) return VR_OK;

  size_t cap = (*seg_cap == 0u) ? VR_RASTER_SEGMENT_INITIAL_CAP : *seg_cap;
  while (cap < needed) {
    if (cap > (SIZE_MAX >> 1u)) return VR_ERR_OOM;
    cap *= 2u;
  }
  vr_segment_t* ns = (vr_segment_t*)vr_raster_realloc_array(face, *segs, *seg_cap, cap, sizeof(vr_segment_t));
  if (!ns) return VR_ERR_OOM;
  *segs = ns;
  *seg_cap = cap;
  return VR_OK;
}

static vr_status_t vr_push_segment(const vr_font_face_t* face, vr_segment_t** segs, size_t* seg_count, size_t* seg_cap, float x1, float y1, float x2, float y2) {
  if (vr_ensure_segments_capacity(face, segs, seg_cap, *seg_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*segs)[*seg_count].x1 = x1;
  (*segs)[*seg_count].y1 = y1;
  (*segs)[*seg_count].x2 = x2;
  (*segs)[*seg_count].y2 = y2;
  ++(*seg_count);
  return VR_OK;
}

static vr_status_t vr_ensure_curves_capacity(const vr_font_face_t* face, vr_raster_curve_t** curves, size_t* curve_cap, size_t needed) {
  if (*curve_cap >= needed) return VR_OK;

  size_t cap = (*curve_cap == 0u) ? VR_RASTER_SEGMENT_INITIAL_CAP : *curve_cap;
  while (cap < needed) {
    if (cap > (SIZE_MAX >> 1u)) return VR_ERR_OOM;
    cap *= 2u;
  }
  vr_raster_curve_t* nc = (vr_raster_curve_t*)vr_raster_realloc_array(face, *curves, *curve_cap, cap, sizeof(vr_raster_curve_t));
  if (!nc) return VR_ERR_OOM;
  *curves = nc;
  *curve_cap = cap;
  return VR_OK;
}

static vr_status_t vr_ensure_u8_capacity(const vr_font_face_t* face, uint8_t** values, size_t* values_cap, size_t needed) {
  if (*values_cap >= needed) return VR_OK;
  size_t cap = (*values_cap == 0u) ? VR_RASTER_SEGMENT_INITIAL_CAP : *values_cap;
  while (cap < needed) {
    if (cap > (SIZE_MAX >> 1u)) return VR_ERR_OOM;
    cap *= 2u;
  }
  uint8_t* nv = (uint8_t*)vr_raster_realloc_array(face, *values, *values_cap, cap, sizeof(uint8_t));
  if (!nv) return VR_ERR_OOM;
  *values = nv;
  *values_cap = cap;
  return VR_OK;
}

static vr_status_t vr_push_curve(
  const vr_font_face_t* face,
  vr_raster_curve_t** curves,
  size_t* curve_count,
  size_t* curve_cap,
  float x0,
  float y0,
  float x1,
  float y1,
  float x2,
  float y2) {
  if (vr_ensure_curves_capacity(face, curves, curve_cap, *curve_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*curves)[*curve_count].x0 = x0;
  (*curves)[*curve_count].y0 = y0;
  (*curves)[*curve_count].x1 = x1;
  (*curves)[*curve_count].y1 = y1;
  (*curves)[*curve_count].x2 = x2;
  (*curves)[*curve_count].y2 = y2;
  ++(*curve_count);
  return VR_OK;
}

static vr_status_t vr_push_msdf_segment_color(const vr_font_face_t* face, uint8_t** seg_colors, size_t* seg_color_count, size_t* seg_color_cap, uint8_t color) {
  if (vr_ensure_u8_capacity(face, seg_colors, seg_color_cap, *seg_color_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*seg_colors)[*seg_color_count] = color;
  ++(*seg_color_count);
  return VR_OK;
}

static vr_status_t vr_push_msdf_edge(
  const vr_font_face_t* face,
  vr_msdf_outline_edge_t** edges,
  size_t* edge_count,
  size_t* edge_cap,
  vr_msdf_edge_kind_t kind,
  vr_outline_point_t p0,
  vr_outline_point_t p1,
  vr_outline_point_t p2) {
  if (vr_ensure_msdf_edges_capacity(face, edges, edge_cap, *edge_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*edges)[*edge_count].kind = kind;
  (*edges)[*edge_count].p0 = p0;
  (*edges)[*edge_count].p1 = p1;
  (*edges)[*edge_count].p2 = p2;
  ++(*edge_count);
  return VR_OK;
}

static vr_status_t vr_ensure_msdf_edges_capacity(
  const vr_font_face_t* face,
  vr_msdf_outline_edge_t** edges,
  size_t* edge_cap,
  size_t needed) {
  if (!edges || !edge_cap) {
    return VR_ERR_INVALID_FONT;
  }
  if (*edge_cap >= needed) return VR_OK;

  size_t cap = (*edge_cap == 0u) ? VR_RASTER_SEGMENT_INITIAL_CAP : *edge_cap;
  while (cap < needed) {
    if (cap > (SIZE_MAX >> 1u)) return VR_ERR_OOM;
    cap *= 2u;
  }
  vr_msdf_outline_edge_t* ne = (vr_msdf_outline_edge_t*)vr_raster_realloc_array(face, *edges, *edge_cap, cap, sizeof(vr_msdf_outline_edge_t));
  if (!ne) return VR_ERR_OOM;
  *edges = ne;
  *edge_cap = cap;
  return VR_OK;
}

static vr_status_t vr_push_msdf_curve_color(const vr_font_face_t* face, uint8_t** curve_colors, size_t* curve_color_count, size_t* curve_color_cap, uint8_t color) {
  if (vr_ensure_u8_capacity(face, curve_colors, curve_color_cap, *curve_color_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*curve_colors)[*curve_color_count] = color;
  ++(*curve_color_count);
  return VR_OK;
}

static uint8_t vr_msdf_edge_color(float dx, float dy, size_t fallback_index) {
  if ((vr_absf(dx) <= VR_RASTER_SEGMENT_TOLERANCE) && (vr_absf(dy) <= VR_RASTER_SEGMENT_TOLERANCE)) {
    return (uint8_t)(fallback_index % VR_RASTER_MSDF_CHANNEL_COUNT);
  }

  float angle = vr_atan2f(dy, dx) + VR_RASTER_MSDF_PI;
  if (angle < 0.0f) {
    angle = 0.0f;
  } else if (angle >= VR_RASTER_MSDF_TWO_PI) {
    angle = VR_RASTER_MSDF_TWO_PI;
  }
  float normalized = angle / VR_RASTER_MSDF_TWO_PI;
  float biased = normalized + VR_RASTER_MSDF_CHANNEL_HALF_BIN;
  if (biased >= 1.0f) {
    biased -= 1.0f;
  }
  uint8_t color = (uint8_t)vr_floorf(biased * VR_RASTER_MSDF_CHANNEL_SCALE);
  if (color >= VR_RASTER_MSDF_CHANNEL_COUNT) {
    color = (uint8_t)(VR_RASTER_MSDF_CHANNEL_COUNT - 1u);
  }
  return color;
}

static uint8_t vr_msdf_preferred_edge_color(
  float dx,
  float dy,
  size_t fallback_index) {
  uint8_t color = vr_msdf_edge_color(dx, dy, fallback_index);
  return color;
}

static uint8_t vr_msdf_color_cost(uint8_t color, uint8_t preferred_color) {
  return (uint8_t)(color == preferred_color ? 0u : VR_RASTER_MSDF_CHANNEL_MAX_COST);
}

static vr_status_t vr_msdf_color_edges_cycle(
  const vr_font_face_t* face,
  const vr_msdf_outline_edge_t* edges,
  size_t edge_count,
  uint8_t* out_colors) {
  if (edge_count == 0u) return VR_OK;
  if (!edges || !out_colors) return VR_ERR_INVALID_FONT;
  if (edge_count == 1u) {
    vr_outline_point_t p0 = edges[0u].p0;
    vr_outline_point_t p1 = (edges[0u].kind == VR_MSDF_EDGE_KIND_QUAD) ? edges[0u].p2 : edges[0u].p1;
    out_colors[0u] = vr_msdf_preferred_edge_color(p1.x - p0.x, p1.y - p0.y, 0u);
    return VR_OK;
  }

  if (edge_count > (SIZE_MAX / VR_RASTER_MSDF_CHANNEL_COUNT)) {
    return VR_ERR_INVALID_FONT;
  }

  uint8_t* preferred_colors = (uint8_t*)vr_alloc(face, edge_count * sizeof(uint8_t), 8u);
  if (!preferred_colors) return VR_ERR_OOM;
  for (size_t i = 0u; i < edge_count; ++i) {
    vr_outline_point_t p0 = edges[i].p0;
    vr_outline_point_t p1 = (edges[i].kind == VR_MSDF_EDGE_KIND_QUAD) ? edges[i].p2 : edges[i].p1;
    preferred_colors[i] = vr_msdf_preferred_edge_color(p1.x - p0.x, p1.y - p0.y, i);
  }

  uint8_t* parent = (uint8_t*)vr_alloc(face, edge_count * VR_RASTER_MSDF_CHANNEL_COUNT * sizeof(uint8_t), 8u);
  if (!parent) {
    vr_dealloc(face, preferred_colors, edge_count * sizeof(uint8_t), 8u);
    return VR_ERR_OOM;
  }

  uint32_t best_cost = VR_RASTER_MSDF_COLOR_INF_COST;
  uint8_t best_first_color = 0u;
  uint8_t best_last_color = 0u;

  //@optimizer-ignore fixed three-channel MSDF color search
  for (uint8_t first_color = 0u; first_color < VR_RASTER_MSDF_CHANNEL_COUNT; ++first_color) {
    uint32_t dp_prev[VR_RASTER_MSDF_CHANNEL_COUNT];
    uint32_t dp_next[VR_RASTER_MSDF_CHANNEL_COUNT];
    //@optimizer-ignore fixed channel initialization
    for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
      dp_prev[color] = VR_RASTER_MSDF_COLOR_INF_COST;
      dp_next[color] = VR_RASTER_MSDF_COLOR_INF_COST;
    }
    dp_prev[first_color] = vr_msdf_color_cost(first_color, preferred_colors[0u]);

    //@optimizer-ignore dynamic programming over glyph outline edges
    for (size_t edge = 1u; edge < edge_count; ++edge) {
      //@optimizer-ignore fixed channel initialization
      for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
        dp_next[color] = VR_RASTER_MSDF_COLOR_INF_COST;
      }
      //@optimizer-ignore fixed previous-channel scan
      for (uint8_t prev = 0u; prev < VR_RASTER_MSDF_CHANNEL_COUNT; ++prev) {
        if (dp_prev[prev] == VR_RASTER_MSDF_COLOR_INF_COST) {
          continue;
        }
        //@optimizer-ignore fixed channel transition scan
        for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
          if (color == prev) continue;
          uint32_t cost = dp_prev[prev] + vr_msdf_color_cost(color, preferred_colors[edge]);
          if (cost < dp_next[color]) {
            dp_next[color] = cost;
          }
        }
      }
      //@optimizer-ignore fixed channel copy
      for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
        dp_prev[color] = dp_next[color];
      }
    }

    //@optimizer-ignore fixed final-channel scan
    for (uint8_t last_color = 0u; last_color < VR_RASTER_MSDF_CHANNEL_COUNT; ++last_color) {
      if (last_color == first_color) continue;
      uint32_t candidate = dp_prev[last_color];
      bool better = false;
      if (candidate < best_cost) {
        better = true;
      } else if (candidate == best_cost) {
        if (first_color < best_first_color) better = true;
        else if (first_color == best_first_color && last_color < best_last_color) better = true;
      }

      if (better) {
        best_cost = candidate;
        best_first_color = first_color;
        best_last_color = last_color;
      }
    }
  }

  //@optimizer-ignore fixed parent-table clear for MSDF backtracking
  for (size_t edge = 0u; edge < edge_count; ++edge) {
    //@optimizer-ignore fixed channel initialization
    for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
      parent[edge * VR_RASTER_MSDF_CHANNEL_COUNT + color] = 0u;
    }
  }

  uint32_t dp_prev[VR_RASTER_MSDF_CHANNEL_COUNT];
  uint32_t dp_next[VR_RASTER_MSDF_CHANNEL_COUNT];
  //@optimizer-ignore fixed channel initialization
  for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
    dp_prev[color] = VR_RASTER_MSDF_COLOR_INF_COST;
    dp_next[color] = VR_RASTER_MSDF_COLOR_INF_COST;
  }
  dp_prev[best_first_color] = vr_msdf_color_cost(best_first_color, preferred_colors[0u]);

  //@optimizer-ignore dynamic programming over glyph outline edges
  for (size_t edge = 1u; edge < edge_count; ++edge) {
    //@optimizer-ignore fixed channel initialization
    for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
      dp_next[color] = VR_RASTER_MSDF_COLOR_INF_COST;
    }
    //@optimizer-ignore fixed previous-channel scan
    for (uint8_t prev = 0u; prev < VR_RASTER_MSDF_CHANNEL_COUNT; ++prev) {
      if (dp_prev[prev] == VR_RASTER_MSDF_COLOR_INF_COST) {
        continue;
      }
      //@optimizer-ignore fixed channel transition scan
      for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
        if (color == prev) continue;
        uint32_t cost = dp_prev[prev] + vr_msdf_color_cost(color, preferred_colors[edge]);
        if (cost < dp_next[color]) {
          dp_next[color] = cost;
          parent[edge * VR_RASTER_MSDF_CHANNEL_COUNT + color] = prev;
        }
      }
    }
    //@optimizer-ignore fixed channel copy
    for (uint8_t color = 0u; color < VR_RASTER_MSDF_CHANNEL_COUNT; ++color) {
      dp_prev[color] = dp_next[color];
    }
  }

  if (best_cost == VR_RASTER_MSDF_COLOR_INF_COST || best_last_color >= VR_RASTER_MSDF_CHANNEL_COUNT) {
    vr_dealloc(face, preferred_colors, edge_count * sizeof(uint8_t), 8u);
    vr_dealloc(face, parent, edge_count * VR_RASTER_MSDF_CHANNEL_COUNT * sizeof(uint8_t), 8u);
    return VR_ERR_INVALID_FONT;
  }

  out_colors[edge_count - 1u] = best_last_color;
  for (size_t edge = edge_count - 1u; edge > 0u; --edge) {
    uint8_t current_color = out_colors[edge];
    uint8_t prev_color = parent[edge * VR_RASTER_MSDF_CHANNEL_COUNT + current_color];
    out_colors[edge - 1u] = prev_color;
  }

  vr_dealloc(face, preferred_colors, edge_count * sizeof(uint8_t), 8u);
  vr_dealloc(face, parent, edge_count * VR_RASTER_MSDF_CHANNEL_COUNT * sizeof(uint8_t), 8u);
  return VR_OK;
}

static float vr_msdf_resolve_missing_channel_distance(
  const bool channel_present[VR_RASTER_MSDF_CHANNEL_COUNT],
  const float distances[VR_RASTER_MSDF_CHANNEL_COUNT],
  uint8_t color) {
  uint8_t next_color = VR_RASTER_MSDF_CHANNEL_NEXT[color];
  uint8_t prev_color = VR_RASTER_MSDF_CHANNEL_PREV[color];

  bool next_present = channel_present[next_color];
  bool prev_present = channel_present[prev_color];
  if (next_present && prev_present) {
    float next_distance = distances[next_color];
    float prev_distance = distances[prev_color];
    float separation = vr_absf(next_distance - prev_distance);
    if (separation <= VR_RASTER_MSDF_MISSING_CHANNEL_EPSILON) {
      return 0.5f * (next_distance + prev_distance);
    }
    return (next_distance < prev_distance) ? next_distance : prev_distance;
  }

  if (next_present) {
    return distances[next_color];
  }

  return prev_present ? distances[prev_color] : distances[color];
}

static vr_status_t vr_append_transformed_points(
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

static vr_status_t vr_append_outline_point(
  const vr_font_face_t* face,
  vr_outline_point_t** points,
  size_t* count,
  size_t* cap,
  float x,
  float y,
  bool on_curve) {
  if (*count >= *cap) {
    size_t new_cap = (*cap == 0u) ? VR_RASTER_OUTLINE_POINT_INITIAL_CAP : (*cap * 2u);
    if (new_cap < *cap) {
      return VR_ERR_INVALID_FONT;
    }
    vr_outline_point_t* np = (vr_outline_point_t*)vr_raster_realloc_array(face, *points, *cap, new_cap, sizeof(vr_outline_point_t));
    if (!np) return VR_ERR_OOM;
    *points = np;
    *cap = new_cap;
  }
  (*points)[*count].x = x;
  (*points)[*count].y = y;
  (*points)[*count].on_curve = on_curve ? 1u : 0u;
  ++(*count);
  return VR_OK;
}

static vr_status_t vr_collect_contour_points(
  const vr_font_face_t* face,
  const vr_glyph_outline_t* outline,
  uint16_t start,
  uint16_t end,
  float scale,
  vr_outline_point_t** out_points,
  size_t* out_count,
  size_t* out_cap) {
  *out_points = NULL;
  *out_count = 0u;
  *out_cap = 0u;

  size_t raw_count = (size_t)(end - start + 1u);
  if (raw_count > (SIZE_MAX - 2u) / 2u) {
    return VR_ERR_INVALID_FONT;
  }
  size_t cap = raw_count * 2u + 2u;
  vr_outline_point_t* points = (vr_outline_point_t*)vr_alloc(face, cap * sizeof(vr_outline_point_t), 8u);
  if (!points) return VR_ERR_OOM;
  size_t point_count = 0u;

  if (!outline->on_curve[start]) {
    uint16_t last = end;
    float mx = ((float)outline->x[last] + (float)outline->x[start]) * 0.5f * scale;
    float my = ((float)outline->y[last] + (float)outline->y[start]) * 0.5f * scale;
    vr_status_t inserted = vr_append_outline_point(face, &points, &point_count, &cap, mx, my, true);
    if (inserted != VR_OK) {
      vr_raster_free_array(face, points, cap, sizeof(*points));
      return inserted;
    }
  }

  for (size_t i = 0u; i < raw_count; ++i) {
    uint16_t idx = (uint16_t)(start + i);
    float x = (float)outline->x[idx] * scale;
    float y = (float)outline->y[idx] * scale;
    vr_status_t added = vr_append_outline_point(face, &points, &point_count, &cap, x, y, outline->on_curve[idx]);
    if (added != VR_OK) {
      vr_raster_free_array(face, points, cap, sizeof(*points));
      return added;
    }

    uint16_t next = (i + 1u == raw_count) ? start : (uint16_t)(idx + 1u);
    if (!outline->on_curve[idx] && !outline->on_curve[next]) {
      float nx = ((float)outline->x[idx] + (float)outline->x[next]) * 0.5f * scale;
      float ny = ((float)outline->y[idx] + (float)outline->y[next]) * 0.5f * scale;
      vr_status_t implied = vr_append_outline_point(face, &points, &point_count, &cap, nx, ny, true);
      if (implied != VR_OK) {
        vr_raster_free_array(face, points, cap, sizeof(*points));
        return implied;
      }
    }
  }

  if (point_count == 0u) {
    vr_raster_free_array(face, points, cap, sizeof(*points));
    return VR_ERR_INVALID_FONT;
  }

  vr_status_t closed = vr_append_outline_point(
    face,
    &points,
    &point_count,
    &cap,
    points[0].x,
    points[0].y,
    true);
  if (closed != VR_OK) {
    vr_raster_free_array(face, points, cap, sizeof(*points));
    return closed;
  }

  *out_points = points;
  *out_count = point_count;
  *out_cap = cap;
  return VR_OK;
}

static vr_status_t vr_emit_contour_segments(
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
  bool using_msdf) {
  if (point_count < 2u) {
    return VR_OK;
  }

  vr_msdf_outline_edge_t* msdf_edges = NULL;
  uint8_t* msdf_edge_colors = NULL;
  size_t edge_count = 0u;
  size_t edge_capacity = point_count;
  if (using_msdf) {
    msdf_edges = (vr_msdf_outline_edge_t*)vr_alloc(face, edge_capacity * sizeof(vr_msdf_outline_edge_t), 8u);
    if (!msdf_edges) {
      return VR_ERR_OOM;
    }
    msdf_edge_colors = (uint8_t*)vr_alloc(face, edge_capacity * sizeof(uint8_t), 8u);
    if (!msdf_edge_colors) {
      vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
      return VR_ERR_OOM;
    }
  }

  size_t i = 0u;
  while (i + 1u < point_count) {
    vr_outline_point_t p0 = points[i];
    vr_outline_point_t p1 = points[i + 1u];
    if (!p0.on_curve) {
      vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
      vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
      return VR_ERR_INVALID_FONT;
    }

    int segment_type = (p0.on_curve ? 2 : 0) | (p1.on_curve ? 1 : 0);
    switch (segment_type) {
      case 3: {
        if (!using_msdf) {
          vr_status_t line_status = vr_push_segment(face, segs, seg_count, seg_cap, p0.x, p0.y, p1.x, p1.y);
          if (line_status != VR_OK) {
            return line_status;
          }
        } else {
          vr_status_t edge_status = vr_push_msdf_edge(
            face,
            &msdf_edges,
            &edge_count,
            &edge_capacity,
            VR_MSDF_EDGE_KIND_LINE,
            p0,
            p1,
            (vr_outline_point_t){0.0f, 0.0f, 0u});
          if (edge_status != VR_OK) {
            vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
            vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
            return edge_status;
          }
        }
        i += 1u;
        break;
      }
      case 2: {
        if (i + 2u >= point_count || !points[i + 2u].on_curve) {
          vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
          vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
          return VR_ERR_INVALID_FONT;
        }
        if (!using_msdf) {
          vr_status_t curve_store_status = vr_push_curve(
            face,
            curves,
            curve_count,
            curve_cap,
            p0.x,
            p0.y,
            p1.x,
            p1.y,
            points[i + 2u].x,
            points[i + 2u].y);
          if (curve_store_status != VR_OK) {
            return curve_store_status;
          }
        } else {
          vr_status_t edge_status = vr_push_msdf_edge(
            face,
            &msdf_edges,
            &edge_count,
            &edge_capacity,
            VR_MSDF_EDGE_KIND_QUAD,
            p0,
            p1,
            points[i + 2u]);
          if (edge_status != VR_OK) {
            vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
            vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
            return edge_status;
          }
        }
        i += 2u;
        break;
      }
      case 1: {
        vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
        vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
        return VR_ERR_INVALID_FONT;
      }
      default:
        vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
        vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
        return VR_ERR_INVALID_FONT;
    }
  }

  if (!using_msdf) {
    return VR_OK;
  }

  if (edge_count == 0u) {
    vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
    vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
    return VR_OK;
  }

  vr_status_t color_status = vr_msdf_color_edges_cycle(face, msdf_edges, edge_count, msdf_edge_colors);
  if (color_status != VR_OK) {
    vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
    vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
    return color_status;
  }

  for (size_t edge_index = 0u; edge_index < edge_count; ++edge_index) {
    vr_msdf_outline_edge_t edge = msdf_edges[edge_index];
    uint8_t edge_color = msdf_edge_colors[edge_index];
    if (edge.kind == VR_MSDF_EDGE_KIND_LINE) {
      vr_status_t line_status = vr_push_segment(
        face,
        segs,
        seg_count,
        seg_cap,
        edge.p0.x,
        edge.p0.y,
        edge.p1.x,
        edge.p1.y);
      if (line_status != VR_OK) {
        vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
        vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
        return line_status;
      }
      vr_status_t line_color_status = vr_push_msdf_segment_color(face, seg_colors, seg_color_count, seg_color_cap, edge_color);
      if (line_color_status != VR_OK) {
        vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
        vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
        return line_color_status;
      }
      continue;
    }

    vr_status_t curve_store_status = vr_push_curve(
      face,
      curves,
      curve_count,
      curve_cap,
      edge.p0.x,
      edge.p0.y,
      edge.p1.x,
      edge.p1.y,
      edge.p2.x,
      edge.p2.y);
    if (curve_store_status != VR_OK) {
      vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
      vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
      return curve_store_status;
    }

    vr_status_t curve_color_status = vr_push_msdf_curve_color(
      face,
      curve_colors,
      curve_color_count,
      curve_color_cap,
      edge_color);
    if (curve_color_status != VR_OK) {
      vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
      vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
      return curve_color_status;
    }

    vr_status_t curve_status = vr_line_segments_from_quad(
      face,
      edge.p0,
      edge.p1,
      edge.p2,
      segs,
      seg_count,
      seg_cap,
      VR_RASTER_QUAD_BEZIER_TOLERANCE,
      0,
      edge_color,
      seg_colors,
      seg_color_count,
      seg_color_cap,
      using_msdf);
    if (curve_status != VR_OK) {
      vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
      vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
      return curve_status;
    }
  }

  vr_raster_free_array(face, msdf_edges, edge_capacity, sizeof(*msdf_edges));
  vr_raster_free_array(face, msdf_edge_colors, edge_capacity, sizeof(*msdf_edge_colors));
  return VR_OK;
}

static vr_status_t vr_line_segments_from_quad(
  const vr_font_face_t* face,
  const vr_outline_point_t p0,
  const vr_outline_point_t p1,
  const vr_outline_point_t p2,
  vr_segment_t** segs,
  size_t* count,
  size_t* cap,
  float tolerance_sq,
  int depth,
  uint8_t segment_color,
  uint8_t** seg_colors,
  size_t* seg_color_count,
  size_t* seg_color_cap,
  bool using_msdf) {
  if (depth > VR_RASTER_TESSELLATION_SOFT_LIMIT) {
    if (depth > VR_RASTER_TESSELLATION_HARD_LIMIT) return VR_OK;
  }

  float x0 = p0.x, y0 = p0.y;
  float x1 = p1.x, y1 = p1.y;
  float x2 = p2.x, y2 = p2.y;
  float midx = (x0 + 2.0f * x1 + x2) * 0.25f;
  float midy = (y0 + 2.0f * y1 + y2) * 0.25f;
  float lx = x0 + (2.0f * x1 + x2 - x0) * 0.5f;
  float ly = y0 + (2.0f * y1 + y2 - y0) * 0.5f;
  (void)lx;
  (void)ly;
  float dist2 = (x1 - midx) * (x1 - midx) + (y1 - midy) * (y1 - midy);
  if (dist2 <= tolerance_sq) {
    vr_status_t push_status = vr_push_segment(face, segs, count, cap, x0, y0, x2, y2);
    if (push_status != VR_OK) {
      return push_status;
    }
    if (using_msdf) {
      return vr_push_msdf_segment_color(face, seg_colors, seg_color_count, seg_color_cap, segment_color);
    }
    return VR_OK;
  }

  vr_outline_point_t q0 = {x0 + (x1 - x0) * 0.5f, y0 + (y1 - y0) * 0.5f, 1};
  vr_outline_point_t q1 = {x1 + (x2 - x1) * 0.5f, y1 + (y2 - y1) * 0.5f, 1};
  vr_outline_point_t r = {(q0.x + q1.x) * 0.5f, (q0.y + q1.y) * 0.5f, 1};
  vr_status_t st = vr_line_segments_from_quad(
    face,
    p0,
    q0,
    r,
    segs,
    count,
    cap,
    tolerance_sq,
    depth + 1,
    segment_color,
    seg_colors,
    seg_color_count,
    seg_color_cap,
    using_msdf);
  if (st != VR_OK) {
    return st;
  }
  return vr_line_segments_from_quad(
    face,
    r,
    q1,
    p2,
    segs,
    count,
    cap,
    tolerance_sq,
    depth + 1,
    segment_color,
    seg_colors,
    seg_color_count,
    seg_color_cap,
    using_msdf);
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
static vr_status_t vr_parse_simple_glyph(const vr_font_face_t* face, const uint8_t* p, const uint8_t* end, int16_t contours, vr_glyph_outline_t* out) {
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

static vr_status_t vr_parse_composite_glyph(
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

static vr_status_t vr_load_glyph_outline_internal(
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
 

static int vr_segment_crossing_sign(float x, float y, const vr_segment_t* seg) {
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

static int vr_quadratic_crossing_sign(float x, float y, const vr_raster_curve_t* curve) {
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

static float vr_sample_offset(int index, int samples) {
  return (float)(index + 0.5f) / (float)samples - VR_RASTER_SDF_SAMPLE_OFFSET;
}

static float vr_segment_distance_sq(float px, float py, const vr_segment_t* seg) {
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

static float vr_quadratic_point_x(float t, const vr_raster_curve_t* curve) {
  float omt = 1.0f - t;
  float t2 = t * t;
  float omt2 = omt * omt;
  return omt2 * curve->x0 + 2.0f * omt * t * curve->x1 + t2 * curve->x2;
}

static float vr_quadratic_point_y(float t, const vr_raster_curve_t* curve) {
  float omt = 1.0f - t;
  float t2 = t * t;
  float omt2 = omt * omt;
  return omt2 * curve->y0 + 2.0f * omt * t * curve->y1 + t2 * curve->y2;
}

static float vr_quadratic_point_distance_sq(float px, float py, const vr_raster_curve_t* curve, float t) {
  float x = vr_quadratic_point_x(t, curve);
  float y = vr_quadratic_point_y(t, curve);
  float dx = px - x;
  float dy = py - y;
  return dx * dx + dy * dy;
}

//@optimizer-ignore-function quadratic distance search samples fixed curve points and Newton-refines candidates
static float vr_quadratic_distance_sq(float px, float py, const vr_raster_curve_t* curve) {
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

static int vr_point_inside_outline(
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

static void vr_msdf_nearest_channel_distance_sq(
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

static void vr_msdf_signed_distances_to_outline(
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

static uint8_t vr_alpha_from_signed_distance(float signed_distance, float spread) {
  if (spread <= VR_RASTER_SEGMENT_TOLERANCE) {
    return 0u;
  }

  float normalized = (float)VR_RASTER_SDF_MID_ALPHA + (signed_distance * VR_RASTER_SDF_EDGE_SCALE) / spread;
  float clamped = vr_clampf(normalized, VR_RASTER_ALPHA_MIN, VR_RASTER_ALPHA_MAX);
  return (uint8_t)(clamped + 0.5f);
}

static float vr_sdf_spread_from_padding(uint32_t atlas_pad) {
  float spread = VR_RASTER_SDF_SPREAD;
  if (atlas_pad > 0u && (float)atlas_pad > spread) {
    spread = (float)atlas_pad;
  }
  return spread;
}

vr_status_t vr_rasterize_outline(const vr_font_face_t* face,
                                 const vr_glyph_outline_t* outline,
                                 uint8_t** out_bitmap,
                                 int* out_w,
                                 int* out_h,
                                 int* out_left,
                                 int* out_top) {
  return vr_rasterize_outline_with_mode(
    face,
    outline,
    VR_FONT_ATLAS_FORMAT_ALPHA8,
    out_bitmap,
    out_w,
    out_h,
    out_left,
    out_top);
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
