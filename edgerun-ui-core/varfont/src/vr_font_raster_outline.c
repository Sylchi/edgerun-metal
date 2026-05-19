#include "vr_font_raster_internal.h"

vr_status_t vr_append_outline_point(
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

vr_status_t vr_collect_contour_points(
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

vr_status_t vr_line_segments_from_quad(
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
