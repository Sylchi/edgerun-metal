#ifndef ER_UI_GOP_PLANNING_H
#define ER_UI_GOP_PLANNING_H

/*
 * Purpose: keep GOP surface validation, tile planning, dirty tracking, and frame budget logic
 * out of the pixel rasterizer body.
 * Intention: leave er_ui_gop_renderer.c focused on drawing primitives and GOP integration.
 */

UINT8 er_ui_gop_surface_valid(const ErUiGopSurface* surface) {
  return surface != 0 && surface->pixels != 0 && surface->width > 0u && surface->height > 0u &&
         surface->stride >= surface->width &&
         (surface->pixel_format == ER_UI_GOP_PIXEL_RGBX || surface->pixel_format == ER_UI_GOP_PIXEL_BGRX);
}

UINT8 er_ui_gop_mode_valid(const ErUiGopMode* mode) {
  return mode != 0 && mode->width > 0u && mode->height > 0u && mode->stride >= mode->width &&
         mode->refresh_hz > 0u &&
         (mode->pixel_format == ER_UI_GOP_PIXEL_RGBX || mode->pixel_format == ER_UI_GOP_PIXEL_BGRX);
}

static UINT32 er_ui_gop_div_ceil_u32(UINT32 value, UINT32 divisor) {
  return (value + divisor - 1u) / divisor;
}

static UINT8 er_ui_gop_add_u64(UINT64 a, UINT64 b, UINT64* out) {
  if (out == 0 || a > UINT64_MAX - b) {
    return 0u;
  }
  *out = a + b;
  return 1u;
}

static UINT8 er_ui_gop_mul_u64(UINT64 a, UINT64 b, UINT64* out) {
  if (out == 0 || (a != 0u && b > UINT64_MAX / a)) {
    return 0u;
  }
  *out = a * b;
  return 1u;
}

UINT8 er_ui_gop_tile_plan_from_mode(const ErUiGopMode* mode, UINT32 tile_width, UINT32 tile_height,
                                    UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  UINT32 columns;
  UINT32 rows;
  UINT64 tile_count;

  if (out_plan != 0) {
    *out_plan = (ErUiGopTilePlan){0};
  }
  if (er_ui_gop_mode_valid(mode) == 0u || tile_width == 0u || tile_height == 0u ||
      max_dirty_tiles == 0u || out_plan == 0) {
    return 0u;
  }

  columns = er_ui_gop_div_ceil_u32(mode->width, tile_width);
  rows = er_ui_gop_div_ceil_u32(mode->height, tile_height);
  tile_count = (UINT64)columns * (UINT64)rows;
  if ((UINT64)max_dirty_tiles > tile_count) {
    max_dirty_tiles = (UINT32)tile_count;
  }

  out_plan->width = mode->width;
  out_plan->height = mode->height;
  out_plan->stride = mode->stride;
  out_plan->bytes_per_pixel = ER_UI_GOP_BYTES_PER_PIXEL;
  out_plan->tile_width = tile_width;
  out_plan->tile_height = tile_height;
  out_plan->columns = columns;
  out_plan->rows = rows;
  out_plan->max_dirty_tiles = max_dirty_tiles;
  out_plan->tile_count = tile_count;
  out_plan->scanout_bytes = (UINT64)mode->stride * (UINT64)mode->height * ER_UI_GOP_BYTES_PER_PIXEL;
  out_plan->full_frame_bytes = (UINT64)mode->width * (UINT64)mode->height * ER_UI_GOP_BYTES_PER_PIXEL;
  out_plan->max_tile_bytes = (UINT64)tile_width * (UINT64)tile_height * ER_UI_GOP_BYTES_PER_PIXEL;
  out_plan->tile_state_bytes = tile_count;
  out_plan->dirty_queue_bytes = (UINT64)max_dirty_tiles * ER_UI_GOP_DIRTY_TILE_ID_BYTES;
  return 1u;
}

UINT8 er_ui_gop_tile_plan(const ErUiGopSurface* surface, UINT32 tile_width, UINT32 tile_height,
                          UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  ErUiGopMode mode;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    if (out_plan != 0) {
      *out_plan = (ErUiGopTilePlan){0};
    }
    return 0u;
  }

  mode.width = surface->width;
  mode.height = surface->height;
  mode.stride = surface->stride;
  mode.refresh_hz = 1u;
  mode.pixel_format = surface->pixel_format;
  return er_ui_gop_tile_plan_from_mode(&mode, tile_width, tile_height, max_dirty_tiles, out_plan);
}

UINT8 er_ui_gop_bandwidth_plan_from_mode(const ErUiGopMode* mode, UINT32 overdraw_budget,
                                         ErUiGopBandwidthPlan* out_plan) {
  UINT64 scanout_bytes;
  UINT64 full_frame_bytes;
  UINT64 scanout_bytes_per_second;
  UINT64 full_frame_bytes_per_second;
  UINT64 budget_bytes_per_second;

  if (out_plan != 0) {
    *out_plan = (ErUiGopBandwidthPlan){0};
  }
  if (er_ui_gop_mode_valid(mode) == 0u || overdraw_budget == 0u || out_plan == 0) {
    return 0u;
  }
  if (er_ui_gop_mul_u64((UINT64)mode->stride, (UINT64)mode->height, &scanout_bytes) == 0u ||
      er_ui_gop_mul_u64(scanout_bytes, ER_UI_GOP_BYTES_PER_PIXEL, &scanout_bytes) == 0u ||
      er_ui_gop_mul_u64((UINT64)mode->width, (UINT64)mode->height, &full_frame_bytes) == 0u ||
      er_ui_gop_mul_u64(full_frame_bytes, ER_UI_GOP_BYTES_PER_PIXEL, &full_frame_bytes) == 0u ||
      er_ui_gop_mul_u64(scanout_bytes, (UINT64)mode->refresh_hz, &scanout_bytes_per_second) == 0u ||
      er_ui_gop_mul_u64(full_frame_bytes, (UINT64)mode->refresh_hz, &full_frame_bytes_per_second) == 0u ||
      er_ui_gop_mul_u64(full_frame_bytes_per_second, (UINT64)overdraw_budget, &budget_bytes_per_second) == 0u) {
    return 0u;
  }

  out_plan->refresh_hz = mode->refresh_hz;
  out_plan->overdraw_budget = overdraw_budget;
  out_plan->scanout_bytes_per_second = scanout_bytes_per_second;
  out_plan->full_frame_bytes_per_second = full_frame_bytes_per_second;
  out_plan->budget_bytes_per_second = budget_bytes_per_second;
  return 1u;
}

UINT8 er_ui_gop_memory_plan_from_tile_plan(const ErUiGopTilePlan* tile_plan, UINT32 backing_buffer_count,
                                           UINT64 command_bytes, UINT64 glyph_cache_bytes,
                                           UINT64 surface_bytes, ErUiGopMemoryPlan* out_plan) {
  UINT64 backing_bytes;
  UINT64 total;

  if (out_plan != 0) {
    *out_plan = (ErUiGopMemoryPlan){0};
  }
  if (tile_plan == 0 || out_plan == 0 || tile_plan->tile_count == 0u) {
    return 0u;
  }
  if (er_ui_gop_mul_u64(tile_plan->scanout_bytes, (UINT64)backing_buffer_count, &backing_bytes) == 0u) {
    return 0u;
  }

  total = tile_plan->scanout_bytes;
  if (er_ui_gop_add_u64(total, backing_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, tile_plan->tile_state_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, tile_plan->dirty_queue_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, command_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, glyph_cache_bytes, &total) == 0u ||
      er_ui_gop_add_u64(total, surface_bytes, &total) == 0u) {
    return 0u;
  }

  out_plan->backing_buffer_count = backing_buffer_count;
  out_plan->scanout_bytes = tile_plan->scanout_bytes;
  out_plan->backing_bytes = backing_bytes;
  out_plan->tile_state_bytes = tile_plan->tile_state_bytes;
  out_plan->dirty_queue_bytes = tile_plan->dirty_queue_bytes;
  out_plan->command_bytes = command_bytes;
  out_plan->glyph_cache_bytes = glyph_cache_bytes;
  out_plan->surface_bytes = surface_bytes;
  out_plan->total_bytes = total;
  return 1u;
}

UINT8 er_ui_gop_memory_plan_first_budget_violation(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget,
                                                   ErUiGopMemoryBudgetViolation* out_violation) {
  return (UINT8)(
      er_ui_gop_memory_violation("scanout_bytes", plan.scanout_bytes, budget.scanout_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("backing_bytes", plan.backing_bytes, budget.backing_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("tile_state_bytes", plan.tile_state_bytes, budget.tile_state_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("dirty_queue_bytes", plan.dirty_queue_bytes, budget.dirty_queue_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("command_bytes", plan.command_bytes, budget.command_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("glyph_cache_bytes", plan.glyph_cache_bytes, budget.glyph_cache_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("surface_bytes", plan.surface_bytes, budget.surface_bytes, out_violation) != 0u ||
      er_ui_gop_memory_violation("total_bytes", plan.total_bytes, budget.total_bytes, out_violation) != 0u);
}

UINT8 er_ui_gop_memory_plan_fits_budget(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget) {
  return er_ui_gop_memory_plan_first_budget_violation(plan, budget, 0) == 0u;
}

UINT8 er_ui_gop_tile_rect(const ErUiGopTilePlan* plan, UINT32 tile_id, ErUiGopPixelRect* out_rect) {
  UINT32 tx;
  UINT32 ty;

  if (out_rect != 0) {
    *out_rect = (ErUiGopPixelRect){0};
  }
  if (plan == 0 || out_rect == 0 || plan->tile_count == 0u || (UINT64)tile_id >= plan->tile_count ||
      plan->columns == 0u || plan->tile_width == 0u || plan->tile_height == 0u) {
    return 0u;
  }

  tx = tile_id % plan->columns;
  ty = tile_id / plan->columns;
  out_rect->x0 = tx * plan->tile_width;
  out_rect->y0 = ty * plan->tile_height;
  out_rect->x1 = out_rect->x0 + plan->tile_width;
  out_rect->y1 = out_rect->y0 + plan->tile_height;
  if (out_rect->x1 > plan->width) out_rect->x1 = plan->width;
  if (out_rect->y1 > plan->height) out_rect->y1 = plan->height;
  return out_rect->x0 < out_rect->x1 && out_rect->y0 < out_rect->y1;
}

UINT8 er_ui_gop_dirty_tiles_reset(const ErUiGopTilePlan* plan, UINT8* tile_marks,
                                  UINT64 tile_mark_count, ErUiGopDirtyTileList* list) {
  UINT64 i;

  if (plan == 0 || tile_marks == 0 || list == 0 || list->tile_ids == 0 ||
      plan->tile_count == 0u || plan->tile_count > tile_mark_count ||
      plan->tile_count > UINT32_MAX || list->capacity < plan->max_dirty_tiles) {
    return 0u;
  }

  for (i = 0u; i < plan->tile_count; ++i) {
    tile_marks[i] = 0u;
  }
  list->count = 0u;
  list->overflowed = 0u;
  return 1u;
}

//@optimizer-ignore-function dirty tracking must mark every tile overlapped by the changed rectangle
UINT8 er_ui_gop_dirty_tiles_mark_rect(const ErUiGopTilePlan* plan, float x, float y, float w, float h,
                                      UINT8* tile_marks, UINT64 tile_mark_count,
                                      ErUiGopDirtyTileList* list) {
  INT64 x0;
  INT64 y0;
  INT64 x1;
  INT64 y1;
  UINT32 tx0;
  UINT32 ty0;
  UINT32 tx1;
  UINT32 ty1;
  UINT32 ty;
  UINT32 tx;

  if (plan == 0 || tile_marks == 0 || list == 0 || list->tile_ids == 0 ||
      plan->tile_count == 0u || plan->tile_count > tile_mark_count ||
      plan->tile_count > UINT32_MAX || !(w > 0.0f) || !(h > 0.0f)) {
    return 0u;
  }

  x0 = er_ui_gop_floor_i64(x);
  y0 = er_ui_gop_floor_i64(y);
  x1 = er_ui_gop_ceil_i64(x + w);
  y1 = er_ui_gop_ceil_i64(y + h);
  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 > (INT64)plan->width) x1 = (INT64)plan->width;
  if (y1 > (INT64)plan->height) y1 = (INT64)plan->height;
  if (x0 >= x1 || y0 >= y1) {
    return 1u;
  }

  tx0 = (UINT32)x0 / plan->tile_width;
  ty0 = (UINT32)y0 / plan->tile_height;
  tx1 = er_ui_gop_div_ceil_u32((UINT32)x1, plan->tile_width);
  ty1 = er_ui_gop_div_ceil_u32((UINT32)y1, plan->tile_height);
  if (tx1 > plan->columns) tx1 = plan->columns;
  if (ty1 > plan->rows) ty1 = plan->rows;

  for (ty = ty0; ty < ty1; ++ty) {
    for (tx = tx0; tx < tx1; ++tx) {
      UINT64 tile_id64 = (UINT64)ty * (UINT64)plan->columns + (UINT64)tx;
      UINT32 tile_id = (UINT32)tile_id64;
      if (tile_id64 >= plan->tile_count || tile_marks[tile_id] != 0u) {
        continue;
      }
      tile_marks[tile_id] = 1u;
      if (list->count < list->capacity && list->count < plan->max_dirty_tiles) {
        list->tile_ids[list->count++] = tile_id;
      } else {
        list->overflowed = 1u;
      }
    }
  }
  return 1u;
}

static UINT8 er_ui_gop_color_equal(er_ui_color4_t a, er_ui_color4_t b) {
  return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
}

static UINT8 er_ui_gop_rect_equal(er_ui_rect_t a, er_ui_rect_t b) {
  return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h &&
         a.radius == b.radius && a.mode == b.mode && a.shadow == b.shadow &&
         er_ui_gop_color_equal(a.color, b.color) != 0u &&
         er_ui_gop_color_equal(a.color2, b.color2) != 0u;
}

static UINT8 er_ui_gop_quad_equal(er_ui_quad_t a, er_ui_quad_t b) {
  return a.x == b.x && a.y == b.y && a.w == b.w && a.h == b.h &&
         a.u0 == b.u0 && a.v0 == b.v0 && a.u1 == b.u1 && a.v1 == b.v1 &&
         a.atlas_id == b.atlas_id && er_ui_gop_color_equal(a.color, b.color) != 0u;
}

static UINT8 er_ui_gop_dirty_mark_quad(const ErUiGopTilePlan* plan, er_ui_quad_t quad,
                                       UINT8* tile_marks, UINT64 tile_mark_count,
                                       ErUiGopDirtyTileList* list) {
  return er_ui_gop_dirty_tiles_mark_rect(plan, quad.x, quad.y, quad.w, quad.h,
                                         tile_marks, tile_mark_count, list);
}

UINT8 er_ui_gop_dirty_tiles_mark_scene(const ErUiGopTilePlan* plan, const er_ui_scene_t* scene,
                                       UINT8* tile_marks, UINT64 tile_mark_count,
                                       ErUiGopDirtyTileList* list) {
  size_t i;

  if (plan == 0 || scene == 0) {
    return 0u;
  }

  for (i = 0u; i < scene->rect_count; ++i) {
    er_ui_rect_t rect = scene->rects[i];
    if (er_ui_gop_dirty_tiles_mark_rect(plan, rect.x, rect.y, rect.w, rect.h,
                                        tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = 0u; i < scene->icon_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, scene->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = 0u; i < scene->text_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, scene->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_ui_gop_dirty_tiles_mark_scene_diff(const ErUiGopTilePlan* plan, const er_ui_scene_t* prev,
                                            const er_ui_scene_t* next, UINT8* tile_marks,
                                            UINT64 tile_mark_count, ErUiGopDirtyTileList* list) {
  size_t i;
  size_t common;

  if (plan == 0 || prev == 0 || next == 0) {
    return 0u;
  }

  if (er_ui_gop_color_equal(prev->clear, next->clear) == 0u) {
    return er_ui_gop_dirty_tiles_mark_rect(plan, 0.0f, 0.0f, (float)plan->width, (float)plan->height,
                                           tile_marks, tile_mark_count, list);
  }

  common = prev->rect_count < next->rect_count ? prev->rect_count : next->rect_count;
  for (i = 0u; i < common; ++i) {
    if (er_ui_gop_rect_equal(prev->rects[i], next->rects[i]) == 0u) {
      er_ui_rect_t prev_rect = prev->rects[i];
      er_ui_rect_t next_rect = next->rects[i];
      if (er_ui_gop_dirty_tiles_mark_rect(plan, prev_rect.x, prev_rect.y, prev_rect.w, prev_rect.h,
                                          tile_marks, tile_mark_count, list) == 0u ||
          er_ui_gop_dirty_tiles_mark_rect(plan, next_rect.x, next_rect.y, next_rect.w, next_rect.h,
                                          tile_marks, tile_mark_count, list) == 0u) {
        return 0u;
      }
    }
  }
  for (i = common; i < prev->rect_count; ++i) {
    er_ui_rect_t rect = prev->rects[i];
    if (er_ui_gop_dirty_tiles_mark_rect(plan, rect.x, rect.y, rect.w, rect.h,
                                        tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = common; i < next->rect_count; ++i) {
    er_ui_rect_t rect = next->rects[i];
    if (er_ui_gop_dirty_tiles_mark_rect(plan, rect.x, rect.y, rect.w, rect.h,
                                        tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }

  common = prev->icon_quad_count < next->icon_quad_count ? prev->icon_quad_count : next->icon_quad_count;
  for (i = 0u; i < common; ++i) {
    if (er_ui_gop_quad_equal(prev->icon_quads[i], next->icon_quads[i]) == 0u) {
      if (er_ui_gop_dirty_mark_quad(plan, prev->icon_quads[i], tile_marks, tile_mark_count, list) == 0u ||
          er_ui_gop_dirty_mark_quad(plan, next->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
        return 0u;
      }
    }
  }
  for (i = common; i < prev->icon_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, prev->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = common; i < next->icon_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, next->icon_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }

  common = prev->text_quad_count < next->text_quad_count ? prev->text_quad_count : next->text_quad_count;
  for (i = 0u; i < common; ++i) {
    if (er_ui_gop_quad_equal(prev->text_quads[i], next->text_quads[i]) == 0u) {
      if (er_ui_gop_dirty_mark_quad(plan, prev->text_quads[i], tile_marks, tile_mark_count, list) == 0u ||
          er_ui_gop_dirty_mark_quad(plan, next->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
        return 0u;
      }
    }
  }
  for (i = common; i < prev->text_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, prev->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }
  for (i = common; i < next->text_quad_count; ++i) {
    if (er_ui_gop_dirty_mark_quad(plan, next->text_quads[i], tile_marks, tile_mark_count, list) == 0u) {
      return 0u;
    }
  }

  return 1u;
}

void er_ui_gop_frame_state_reset(ErUiGopFrameState* state) {
  if (state != 0) {
    *state = (ErUiGopFrameState){0};
  }
}

UINT8 er_ui_gop_frame_dirty_tiles(const ErUiGopFrameState* state, const ErUiGopTilePlan* plan,
                                  const er_ui_scene_t* prev, const er_ui_scene_t* next,
                                  UINT8* tile_marks, UINT64 tile_mark_count,
                                  ErUiGopDirtyTileList* list) {
  UINT8 has_previous;

  if (state == 0 || plan == 0 || next == 0) {
    return 0u;
  }
  if (er_ui_gop_dirty_tiles_reset(plan, tile_marks, tile_mark_count, list) == 0u) {
    return 0u;
  }

  has_previous = state->has_previous_scene != 0u && prev != 0;
  if (has_previous == 0u) {
    return er_ui_gop_dirty_tiles_mark_rect(plan, 0.0f, 0.0f, (float)plan->width, (float)plan->height,
                                           tile_marks, tile_mark_count, list) != 0u &&
           er_ui_gop_dirty_tiles_mark_scene(plan, next, tile_marks, tile_mark_count, list) != 0u;
  }

  return er_ui_gop_dirty_tiles_mark_scene_diff(plan, prev, next, tile_marks, tile_mark_count, list);
}

void er_ui_gop_frame_state_commit(ErUiGopFrameState* state) {
  if (state != 0) {
    state->has_previous_scene = 1u;
  }
}

ErUiGopFrameBudget er_ui_gop_frame_budget_from_plan(const ErUiGopTilePlan* tile_plan,
                                                    er_ui_scene_budget_t scene_budget,
                                                    UINT32 overdraw_budget) {
  ErUiGopFrameBudget budget = {0};
  UINT64 frame_pixels;
  UINT64 primitive_limit;

  if (tile_plan == 0 || overdraw_budget == 0u) {
    return budget;
  }

  frame_pixels = (UINT64)tile_plan->width * (UINT64)tile_plan->height;
  primitive_limit = (UINT64)scene_budget.rects + (UINT64)scene_budget.icon_quads + (UINT64)scene_budget.text_quads;
  budget.pixels_written = frame_pixels * (UINT64)overdraw_budget;
  budget.bytes_written = tile_plan->full_frame_bytes * (UINT64)overdraw_budget;
  budget.blend_pixels = frame_pixels * (UINT64)overdraw_budget;
  budget.text_pixels = frame_pixels;
  budget.rects = (UINT64)scene_budget.rects;
  budget.icon_quads = (UINT64)scene_budget.icon_quads;
  budget.text_quads = (UINT64)scene_budget.text_quads;
  budget.tiles_rendered = tile_plan->tile_count;
  budget.dirty_tiles_requested = (UINT64)tile_plan->max_dirty_tiles;
  budget.clipped_primitives = primitive_limit * tile_plan->tile_count;
  budget.rejected_primitives = primitive_limit * tile_plan->tile_count;
  return budget;
}

UINT8 er_ui_gop_render_stats_first_budget_violation(ErUiGopRenderStats stats, ErUiGopFrameBudget budget,
                                                    ErUiGopFrameBudgetViolation* out_violation) {
  return (UINT8)(
      er_ui_gop_frame_violation("pixels_written", stats.pixels_written, budget.pixels_written, out_violation) != 0u ||
      er_ui_gop_frame_violation("bytes_written", stats.bytes_written, budget.bytes_written, out_violation) != 0u ||
      er_ui_gop_frame_violation("blend_pixels", stats.blend_pixels, budget.blend_pixels, out_violation) != 0u ||
      er_ui_gop_frame_violation("text_pixels", stats.text_pixels, budget.text_pixels, out_violation) != 0u ||
      er_ui_gop_frame_violation("rects", stats.rects, budget.rects, out_violation) != 0u ||
      er_ui_gop_frame_violation("icon_quads", stats.icon_quads, budget.icon_quads, out_violation) != 0u ||
      er_ui_gop_frame_violation("text_quads", stats.text_quads, budget.text_quads, out_violation) != 0u ||
      er_ui_gop_frame_violation("tiles_rendered", stats.tiles_rendered, budget.tiles_rendered, out_violation) != 0u ||
      er_ui_gop_frame_violation("dirty_tiles_requested", stats.dirty_tiles_requested, budget.dirty_tiles_requested, out_violation) != 0u ||
      er_ui_gop_frame_violation("clipped_primitives", stats.clipped_primitives, budget.clipped_primitives, out_violation) != 0u ||
      er_ui_gop_frame_violation("rejected_primitives", stats.rejected_primitives, budget.rejected_primitives, out_violation) != 0u);
}

UINT8 er_ui_gop_render_stats_fits_budget(ErUiGopRenderStats stats, ErUiGopFrameBudget budget) {
  return er_ui_gop_render_stats_first_budget_violation(stats, budget, 0) == 0u;
}

UINT32 er_ui_gop_pack_rgb(ErUiGopPixelFormat format, UINT8 r, UINT8 g, UINT8 b) {
  if (format == ER_UI_GOP_PIXEL_BGRX) {
    return ((UINT32)b << ER_UI_GOP_COLOR_RED_SHIFT) |
           ((UINT32)g << ER_UI_GOP_COLOR_GREEN_SHIFT) |
           (UINT32)r;
  }
  return ((UINT32)r << ER_UI_GOP_COLOR_RED_SHIFT) |
         ((UINT32)g << ER_UI_GOP_COLOR_GREEN_SHIFT) |
         (UINT32)b;
}

#endif
