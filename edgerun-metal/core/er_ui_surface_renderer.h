#ifndef ER_UI_SURFACE_RENDERER_H
#define ER_UI_SURFACE_RENDERER_H

/*
 * Purpose: expose the platform-neutral software surface renderer used by metal display backends.
 * Intention: keep UI scenes, tiled raster planning, and render accounting independent of GOP,
 * VirtIO GPU, native GL, or any other scanout provider.
 */

#include "er_ui_gop_renderer.h"

typedef ErUiGopPixelFormat ErUiSurfacePixelFormat;
enum {
  ER_UI_SURFACE_PIXEL_RGBX = ER_UI_GOP_PIXEL_RGBX,
  ER_UI_SURFACE_PIXEL_BGRX = ER_UI_GOP_PIXEL_BGRX
};

typedef ErUiGopSurface ErUiSurface;
typedef ErUiGopMode ErUiSurfaceMode;
typedef ErUiGopAlphaAtlas ErUiAlphaAtlas;
typedef ErUiGopRenderStats ErUiSurfaceRenderStats;
typedef ErUiGopFrameBudget ErUiSurfaceFrameBudget;
typedef ErUiGopFrameBudgetViolation ErUiSurfaceFrameBudgetViolation;
typedef ErUiGopTilePlan ErUiSurfaceTilePlan;
typedef ErUiGopBandwidthPlan ErUiSurfaceBandwidthPlan;
typedef ErUiGopMemoryPlan ErUiSurfaceMemoryPlan;
typedef ErUiGopMemoryBudget ErUiSurfaceMemoryBudget;
typedef ErUiGopMemoryBudgetViolation ErUiSurfaceMemoryBudgetViolation;
typedef ErUiGopDirtyTileList ErUiSurfaceDirtyTileList;
typedef ErUiGopPixelRect ErUiSurfacePixelRect;
typedef ErUiGopFrameState ErUiSurfaceFrameState;

static inline UINT8 er_ui_surface_valid(const ErUiSurface* surface) {
  return er_ui_gop_surface_valid(surface);
}

static inline UINT8 er_ui_surface_mode_valid(const ErUiSurfaceMode* mode) {
  return er_ui_gop_mode_valid(mode);
}

static inline UINT8 er_ui_surface_tile_plan_from_mode(const ErUiSurfaceMode* mode,
                                                      UINT32 tile_width,
                                                      UINT32 tile_height,
                                                      UINT32 max_dirty_tiles,
                                                      ErUiSurfaceTilePlan* out_plan) {
  return er_ui_gop_tile_plan_from_mode(mode, tile_width, tile_height, max_dirty_tiles, out_plan);
}

static inline UINT8 er_ui_surface_tile_plan(const ErUiSurface* surface,
                                            UINT32 tile_width,
                                            UINT32 tile_height,
                                            UINT32 max_dirty_tiles,
                                            ErUiSurfaceTilePlan* out_plan) {
  return er_ui_gop_tile_plan(surface, tile_width, tile_height, max_dirty_tiles, out_plan);
}

static inline UINT8 er_ui_surface_bandwidth_plan_from_mode(const ErUiSurfaceMode* mode,
                                                           UINT32 overdraw_budget,
                                                           ErUiSurfaceBandwidthPlan* out_plan) {
  return er_ui_gop_bandwidth_plan_from_mode(mode, overdraw_budget, out_plan);
}

static inline UINT8 er_ui_surface_memory_plan_from_tile_plan(const ErUiSurfaceTilePlan* tile_plan,
                                                             UINT32 backing_buffer_count,
                                                             UINT64 command_bytes,
                                                             UINT64 glyph_cache_bytes,
                                                             UINT64 surface_bytes,
                                                             ErUiSurfaceMemoryPlan* out_plan) {
  return er_ui_gop_memory_plan_from_tile_plan(tile_plan,
                                              backing_buffer_count,
                                              command_bytes,
                                              glyph_cache_bytes,
                                              surface_bytes,
                                              out_plan);
}

static inline UINT8 er_ui_surface_memory_plan_fits_budget(ErUiSurfaceMemoryPlan plan,
                                                          ErUiSurfaceMemoryBudget budget) {
  return er_ui_gop_memory_plan_fits_budget(plan, budget);
}

static inline UINT8 er_ui_surface_memory_plan_first_budget_violation(
    ErUiSurfaceMemoryPlan plan,
    ErUiSurfaceMemoryBudget budget,
    ErUiSurfaceMemoryBudgetViolation* out_violation) {
  return er_ui_gop_memory_plan_first_budget_violation(plan, budget, out_violation);
}

static inline UINT8 er_ui_surface_tile_rect(const ErUiSurfaceTilePlan* plan,
                                            UINT32 tile_id,
                                            ErUiSurfacePixelRect* out_rect) {
  return er_ui_gop_tile_rect(plan, tile_id, out_rect);
}

static inline UINT8 er_ui_surface_dirty_tiles_reset(const ErUiSurfaceTilePlan* plan,
                                                    UINT8* tile_marks,
                                                    UINT64 tile_mark_count,
                                                    ErUiSurfaceDirtyTileList* list) {
  return er_ui_gop_dirty_tiles_reset(plan, tile_marks, tile_mark_count, list);
}

static inline UINT8 er_ui_surface_dirty_tiles_mark_rect(const ErUiSurfaceTilePlan* plan,
                                                        float x,
                                                        float y,
                                                        float w,
                                                        float h,
                                                        UINT8* tile_marks,
                                                        UINT64 tile_mark_count,
                                                        ErUiSurfaceDirtyTileList* list) {
  return er_ui_gop_dirty_tiles_mark_rect(plan, x, y, w, h, tile_marks, tile_mark_count, list);
}

static inline UINT8 er_ui_surface_dirty_tiles_mark_scene(const ErUiSurfaceTilePlan* plan,
                                                         const er_ui_scene_t* scene,
                                                         UINT8* tile_marks,
                                                         UINT64 tile_mark_count,
                                                         ErUiSurfaceDirtyTileList* list) {
  return er_ui_gop_dirty_tiles_mark_scene(plan, scene, tile_marks, tile_mark_count, list);
}

static inline UINT8 er_ui_surface_dirty_tiles_mark_scene_diff(const ErUiSurfaceTilePlan* plan,
                                                              const er_ui_scene_t* prev,
                                                              const er_ui_scene_t* next,
                                                              UINT8* tile_marks,
                                                              UINT64 tile_mark_count,
                                                              ErUiSurfaceDirtyTileList* list) {
  return er_ui_gop_dirty_tiles_mark_scene_diff(plan, prev, next, tile_marks, tile_mark_count, list);
}

static inline void er_ui_surface_frame_state_reset(ErUiSurfaceFrameState* state) {
  er_ui_gop_frame_state_reset(state);
}

static inline UINT8 er_ui_surface_frame_dirty_tiles(const ErUiSurfaceFrameState* state,
                                                    const ErUiSurfaceTilePlan* plan,
                                                    const er_ui_scene_t* prev,
                                                    const er_ui_scene_t* next,
                                                    UINT8* tile_marks,
                                                    UINT64 tile_mark_count,
                                                    ErUiSurfaceDirtyTileList* list) {
  return er_ui_gop_frame_dirty_tiles(state, plan, prev, next, tile_marks, tile_mark_count, list);
}

static inline void er_ui_surface_frame_state_commit(ErUiSurfaceFrameState* state) {
  er_ui_gop_frame_state_commit(state);
}

static inline ErUiSurfaceFrameBudget er_ui_surface_frame_budget_from_plan(
    const ErUiSurfaceTilePlan* tile_plan,
    er_ui_scene_budget_t scene_budget,
    UINT32 overdraw_budget) {
  return er_ui_gop_frame_budget_from_plan(tile_plan, scene_budget, overdraw_budget);
}

static inline UINT8 er_ui_surface_render_stats_fits_budget(ErUiSurfaceRenderStats stats,
                                                           ErUiSurfaceFrameBudget budget) {
  return er_ui_gop_render_stats_fits_budget(stats, budget);
}

static inline UINT8 er_ui_surface_render_stats_first_budget_violation(
    ErUiSurfaceRenderStats stats,
    ErUiSurfaceFrameBudget budget,
    ErUiSurfaceFrameBudgetViolation* out_violation) {
  return er_ui_gop_render_stats_first_budget_violation(stats, budget, out_violation);
}

static inline UINT32 er_ui_surface_pack_rgb(ErUiSurfacePixelFormat format,
                                            UINT8 r,
                                            UINT8 g,
                                            UINT8 b) {
  return er_ui_gop_pack_rgb(format, r, g, b);
}

static inline UINT8 er_ui_surface_clear(ErUiSurface* surface, er_ui_color4_t color) {
  return er_ui_gop_surface_clear(surface, color);
}

static inline UINT8 er_ui_surface_render_scene(ErUiSurface* surface, const er_ui_scene_t* scene) {
  return er_ui_gop_surface_render_scene(surface, scene);
}

static inline UINT8 er_ui_surface_render_scene_with_atlas(ErUiSurface* surface,
                                                          const er_ui_scene_t* scene,
                                                          const ErUiAlphaAtlas* atlas) {
  return er_ui_gop_surface_render_scene_with_atlas(surface, scene, atlas);
}

static inline UINT8 er_ui_surface_render_scene_with_font(ErUiSurface* surface,
                                                         const er_ui_scene_t* scene,
                                                         const vr_font_face_t* font) {
  return er_ui_gop_surface_render_scene_with_font(surface, scene, font);
}

static inline UINT8 er_ui_surface_render_scene_with_font_stats(ErUiSurface* surface,
                                                               const er_ui_scene_t* scene,
                                                               const vr_font_face_t* font,
                                                               ErUiSurfaceRenderStats* out_stats) {
  return er_ui_gop_surface_render_scene_with_font_stats(surface, scene, font, out_stats);
}

static inline UINT8 er_ui_surface_render_scene_tile_with_font_stats(
    ErUiSurface* surface,
    const er_ui_scene_t* scene,
    const vr_font_face_t* font,
    const ErUiSurfaceTilePlan* plan,
    UINT32 tile_id,
    ErUiSurfaceRenderStats* out_stats) {
  return er_ui_gop_surface_render_scene_tile_with_font_stats(surface, scene, font, plan, tile_id, out_stats);
}

static inline UINT8 er_ui_surface_render_scene_dirty_tiles_with_font_stats(
    ErUiSurface* surface,
    const er_ui_scene_t* scene,
    const vr_font_face_t* font,
    const ErUiSurfaceTilePlan* plan,
    const ErUiSurfaceDirtyTileList* dirty_tiles,
    ErUiSurfaceRenderStats* out_stats) {
  return er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(surface,
                                                                    scene,
                                                                    font,
                                                                    plan,
                                                                    dirty_tiles,
                                                                    out_stats);
}

#endif
