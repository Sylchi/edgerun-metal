#ifndef ER_UI_SURFACE_RENDERER_H
#define ER_UI_SURFACE_RENDERER_H

/*
 * Purpose: platform-neutral software surface rendering for UI scenes.
 * Intention: every display backend owns scanout/window integration while UI core owns
 * deterministic scene rasterization into caller-provided memory.
 */

#include "er_ui_scene.h"
#include "vr_font.h"

#include <stddef.h>
#include <stdint.h>

typedef enum {
  ER_UI_SURFACE_PIXEL_RGBX = 0,
  ER_UI_SURFACE_PIXEL_BGRX = 1
} ErUiSurfacePixelFormat;

typedef struct {
  uint32_t* pixels;
  uint32_t width;
  uint32_t height;
  uint32_t stride;
  ErUiSurfacePixelFormat pixel_format;
} ErUiSurface;

typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t stride;
  uint32_t refresh_hz;
  ErUiSurfacePixelFormat pixel_format;
} ErUiSurfaceMode;

typedef struct {
  const uint8_t* pixels;
  uint32_t width;
  uint32_t height;
  uint32_t bytes_per_pixel;
} ErUiSurfaceAlphaAtlas;
typedef ErUiSurfaceAlphaAtlas ErUiAlphaAtlas;

typedef struct {
  uint64_t pixels_written;
  uint64_t bytes_written;
  uint64_t blend_pixels;
  uint64_t text_pixels;
  uint64_t clears;
  uint64_t rects;
  uint64_t solid_rects;
  uint64_t gradient_rects;
  uint64_t border_rects;
  uint64_t icon_quads;
  uint64_t text_quads;
  uint64_t tiles_rendered;
  uint64_t dirty_tiles_requested;
  uint64_t clipped_primitives;
  uint64_t rejected_primitives;
} ErUiSurfaceRenderStats;

typedef struct {
  uint64_t pixels_written;
  uint64_t bytes_written;
  uint64_t blend_pixels;
  uint64_t text_pixels;
  uint64_t rects;
  uint64_t icon_quads;
  uint64_t text_quads;
  uint64_t tiles_rendered;
  uint64_t dirty_tiles_requested;
  uint64_t clipped_primitives;
  uint64_t rejected_primitives;
} ErUiSurfaceFrameBudget;

typedef struct {
  const char* name;
  uint64_t actual;
  uint64_t limit;
} ErUiSurfaceBudgetViolation;

typedef ErUiSurfaceBudgetViolation ErUiSurfaceFrameBudgetViolation;

typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t stride;
  uint32_t bytes_per_pixel;
  uint32_t tile_width;
  uint32_t tile_height;
  uint32_t columns;
  uint32_t rows;
  uint32_t max_dirty_tiles;
  uint64_t tile_count;
  uint64_t scanout_bytes;
  uint64_t full_frame_bytes;
  uint64_t max_tile_bytes;
  uint64_t tile_state_bytes;
  uint64_t dirty_queue_bytes;
} ErUiSurfaceTilePlan;

typedef struct {
  uint32_t refresh_hz;
  uint32_t overdraw_budget;
  uint64_t scanout_bytes_per_second;
  uint64_t full_frame_bytes_per_second;
  uint64_t budget_bytes_per_second;
} ErUiSurfaceBandwidthPlan;

typedef struct {
  uint32_t backing_buffer_count;
  uint64_t scanout_bytes;
  uint64_t backing_bytes;
  uint64_t tile_state_bytes;
  uint64_t dirty_queue_bytes;
  uint64_t command_bytes;
  uint64_t glyph_cache_bytes;
  uint64_t surface_bytes;
  uint64_t total_bytes;
} ErUiSurfaceMemoryPlan;

typedef struct {
  uint64_t scanout_bytes;
  uint64_t backing_bytes;
  uint64_t tile_state_bytes;
  uint64_t dirty_queue_bytes;
  uint64_t command_bytes;
  uint64_t glyph_cache_bytes;
  uint64_t surface_bytes;
  uint64_t total_bytes;
} ErUiSurfaceMemoryBudget;

typedef ErUiSurfaceBudgetViolation ErUiSurfaceMemoryBudgetViolation;

typedef struct {
  uint32_t* tile_ids;
  uint32_t capacity;
  uint32_t count;
  uint8_t overflowed;
} ErUiSurfaceDirtyTileList;

typedef struct {
  uint32_t x0;
  uint32_t y0;
  uint32_t x1;
  uint32_t y1;
} ErUiSurfacePixelRect;

typedef struct {
  uint8_t has_previous_scene;
} ErUiSurfaceFrameState;

typedef enum {
  ER_UI_SURFACE_RENDER_FULL = 0,
  ER_UI_SURFACE_RENDER_TILE,
  ER_UI_SURFACE_RENDER_DIRTY_TILES
} ErUiSurfaceRenderMode;

typedef struct {
  const er_ui_scene_t* scene;
  const ErUiSurfaceAlphaAtlas* atlas;
  const vr_font_face_t* font;
  const ErUiSurfaceTilePlan* tile_plan;
  const ErUiSurfaceDirtyTileList* dirty_tiles;
  ErUiSurfaceRenderStats* out_stats;
  ErUiSurfaceRenderMode mode;
  uint32_t tile_id;
} ErUiSurfaceRenderDesc;

uint8_t er_ui_surface_valid(const ErUiSurface* surface);
uint8_t er_ui_surface_mode_valid(const ErUiSurfaceMode* mode);
uint8_t er_ui_surface_tile_plan_from_mode(const ErUiSurfaceMode* mode, uint32_t tile_width, uint32_t tile_height,
                                    uint32_t max_dirty_tiles, ErUiSurfaceTilePlan* out_plan);
uint8_t er_ui_surface_tile_plan(const ErUiSurface* surface, uint32_t tile_width, uint32_t tile_height,
                          uint32_t max_dirty_tiles, ErUiSurfaceTilePlan* out_plan);
uint8_t er_ui_surface_bandwidth_plan_from_mode(const ErUiSurfaceMode* mode, uint32_t overdraw_budget,
                                         ErUiSurfaceBandwidthPlan* out_plan);
uint8_t er_ui_surface_memory_plan_from_tile_plan(const ErUiSurfaceTilePlan* tile_plan, uint32_t backing_buffer_count,
                                           uint64_t command_bytes, uint64_t glyph_cache_bytes,
                                           uint64_t surface_bytes, ErUiSurfaceMemoryPlan* out_plan);
uint8_t er_ui_surface_memory_plan_fits_budget(ErUiSurfaceMemoryPlan plan, ErUiSurfaceMemoryBudget budget);
uint8_t er_ui_surface_memory_plan_first_budget_violation(ErUiSurfaceMemoryPlan plan, ErUiSurfaceMemoryBudget budget,
                                                   ErUiSurfaceMemoryBudgetViolation* out_violation);
uint8_t er_ui_surface_tile_rect(const ErUiSurfaceTilePlan* plan, uint32_t tile_id, ErUiSurfacePixelRect* out_rect);
uint8_t er_ui_surface_dirty_tiles_reset(const ErUiSurfaceTilePlan* plan, uint8_t* tile_marks,
                                  uint64_t tile_mark_count, ErUiSurfaceDirtyTileList* list);
uint8_t er_ui_surface_dirty_tiles_mark_rect(const ErUiSurfaceTilePlan* plan, float x, float y, float w, float h,
                                      uint8_t* tile_marks, uint64_t tile_mark_count,
                                      ErUiSurfaceDirtyTileList* list);
uint8_t er_ui_surface_dirty_tiles_mark_scene(const ErUiSurfaceTilePlan* plan, const er_ui_scene_t* scene,
                                       uint8_t* tile_marks, uint64_t tile_mark_count,
                                       ErUiSurfaceDirtyTileList* list);
uint8_t er_ui_surface_dirty_tiles_mark_scene_diff(const ErUiSurfaceTilePlan* plan, const er_ui_scene_t* prev,
                                            const er_ui_scene_t* next, uint8_t* tile_marks,
                                            uint64_t tile_mark_count, ErUiSurfaceDirtyTileList* list);
void er_ui_surface_frame_state_reset(ErUiSurfaceFrameState* state);
uint8_t er_ui_surface_frame_dirty_tiles(const ErUiSurfaceFrameState* state, const ErUiSurfaceTilePlan* plan,
                                  const er_ui_scene_t* prev, const er_ui_scene_t* next,
                                  uint8_t* tile_marks, uint64_t tile_mark_count,
                                  ErUiSurfaceDirtyTileList* list);
void er_ui_surface_frame_state_commit(ErUiSurfaceFrameState* state);
ErUiSurfaceFrameBudget er_ui_surface_frame_budget_from_plan(const ErUiSurfaceTilePlan* tile_plan,
                                                    er_ui_scene_budget_t scene_budget,
                                                    uint32_t overdraw_budget);
uint8_t er_ui_surface_render_stats_fits_budget(ErUiSurfaceRenderStats stats, ErUiSurfaceFrameBudget budget);
uint8_t er_ui_surface_render_stats_first_budget_violation(ErUiSurfaceRenderStats stats, ErUiSurfaceFrameBudget budget,
                                                    ErUiSurfaceFrameBudgetViolation* out_violation);
uint32_t er_ui_surface_pack_rgb(ErUiSurfacePixelFormat format, uint8_t r, uint8_t g, uint8_t b);
uint8_t er_ui_surface_clear(ErUiSurface* surface, er_ui_color4_t color);
uint8_t er_ui_surface_render(ErUiSurface* surface, const ErUiSurfaceRenderDesc* desc);

#endif
