#include "vr_font_raster_internal.h"

float vr_f2dot14_to_float(uint16_t v) {
  return (float)(int16_t)v / VR_F2DOT14_SCALE;
}

void* vr_raster_realloc_array(const vr_font_face_t* face, void* ptr, size_t old_cap, size_t new_cap, size_t elem_size) {
  if (elem_size != 0u && (old_cap > SIZE_MAX / elem_size || new_cap > SIZE_MAX / elem_size)) return NULL;
  return vr_realloc(face, ptr, old_cap * elem_size, new_cap * elem_size, 8u);
}

void vr_raster_free_array(const vr_font_face_t* face, void* ptr, size_t cap, size_t elem_size) {
  if (elem_size != 0u && cap > SIZE_MAX / elem_size) return;
  vr_dealloc(face, ptr, cap * elem_size, 8u);
}

vr_status_t vr_ensure_segments_capacity(const vr_font_face_t* face, vr_segment_t** segs, size_t* seg_cap, size_t needed) {
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

vr_status_t vr_push_segment(const vr_font_face_t* face, vr_segment_t** segs, size_t* seg_count, size_t* seg_cap, float x1, float y1, float x2, float y2) {
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

vr_status_t vr_ensure_curves_capacity(const vr_font_face_t* face, vr_raster_curve_t** curves, size_t* curve_cap, size_t needed) {
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

vr_status_t vr_ensure_u8_capacity(const vr_font_face_t* face, uint8_t** values, size_t* values_cap, size_t needed) {
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

vr_status_t vr_push_msdf_segment_color(const vr_font_face_t* face, uint8_t** seg_colors, size_t* seg_color_count, size_t* seg_color_cap, uint8_t color) {
  if (vr_ensure_u8_capacity(face, seg_colors, seg_color_cap, *seg_color_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*seg_colors)[*seg_color_count] = color;
  ++(*seg_color_count);
  return VR_OK;
}

vr_status_t vr_push_msdf_edge(
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

vr_status_t vr_ensure_msdf_edges_capacity(
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

vr_status_t vr_push_msdf_curve_color(const vr_font_face_t* face, uint8_t** curve_colors, size_t* curve_color_count, size_t* curve_color_cap, uint8_t color) {
  if (vr_ensure_u8_capacity(face, curve_colors, curve_color_cap, *curve_color_count + 1u) != VR_OK) {
    return VR_ERR_OOM;
  }
  (*curve_colors)[*curve_color_count] = color;
  ++(*curve_color_count);
  return VR_OK;
}
