#include "vr_font_raster_internal.h"

uint8_t vr_msdf_edge_color(float dx, float dy, size_t fallback_index) {
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

uint8_t vr_msdf_preferred_edge_color(
  float dx,
  float dy,
  size_t fallback_index) {
  uint8_t color = vr_msdf_edge_color(dx, dy, fallback_index);
  return color;
}

uint8_t vr_msdf_color_cost(uint8_t color, uint8_t preferred_color) {
  return (uint8_t)(color == preferred_color ? 0u : VR_RASTER_MSDF_CHANNEL_MAX_COST);
}

vr_status_t vr_msdf_color_edges_cycle(
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

float vr_msdf_resolve_missing_channel_distance(
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
