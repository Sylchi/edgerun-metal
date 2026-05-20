#include "er_ui_gop_renderer.h"

//@optimizer-ignore-constant UEFI GOP protocol GUID is ABI-defined by firmware
static EFI_GUID g_gop_guid = {
  0x9042a9deu, 0x23dcu, 0x4a38u, {0x96u, 0xfbu, 0x7au, 0xdeu, 0xd0u, 0x80u, 0x51u, 0x6au}
};

static ErUiGopSurface g_surface;
static UINT8 g_ready;

UINT8 er_ui_gop_surface_valid(const ErUiGopSurface* surface) {
  return er_ui_surface_valid(surface);
}

UINT8 er_ui_gop_mode_valid(const ErUiGopMode* mode) {
  return er_ui_surface_mode_valid(mode);
}

UINT8 er_ui_gop_tile_plan_from_mode(const ErUiGopMode* mode, UINT32 tile_width, UINT32 tile_height,
                                    UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  return er_ui_surface_tile_plan_from_mode(mode, tile_width, tile_height, max_dirty_tiles, out_plan);
}

UINT8 er_ui_gop_tile_plan(const ErUiGopSurface* surface, UINT32 tile_width, UINT32 tile_height,
                          UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  return er_ui_surface_tile_plan(surface, tile_width, tile_height, max_dirty_tiles, out_plan);
}

UINT8 er_ui_gop_bandwidth_plan_from_mode(const ErUiGopMode* mode, UINT32 overdraw_budget,
                                         ErUiGopBandwidthPlan* out_plan) {
  return er_ui_surface_bandwidth_plan_from_mode(mode, overdraw_budget, out_plan);
}

UINT8 er_ui_gop_memory_plan_from_tile_plan(const ErUiGopTilePlan* tile_plan, UINT32 backing_buffer_count,
                                           UINT64 command_bytes, UINT64 glyph_cache_bytes,
                                           UINT64 surface_bytes, ErUiGopMemoryPlan* out_plan) {
  return er_ui_surface_memory_plan_from_tile_plan(tile_plan, backing_buffer_count, command_bytes,
                                                 glyph_cache_bytes, surface_bytes, out_plan);
}

UINT8 er_ui_gop_memory_plan_fits_budget(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget) {
  return er_ui_surface_memory_plan_fits_budget(plan, budget);
}

UINT8 er_ui_gop_memory_plan_first_budget_violation(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget,
                                                   ErUiGopMemoryBudgetViolation* out_violation) {
  return er_ui_surface_memory_plan_first_budget_violation(plan, budget, out_violation);
}

UINT8 er_ui_gop_tile_rect(const ErUiGopTilePlan* plan, UINT32 tile_id, ErUiGopPixelRect* out_rect) {
  return er_ui_surface_tile_rect(plan, tile_id, out_rect);
}

UINT8 er_ui_gop_dirty_tiles_reset(const ErUiGopTilePlan* plan, UINT8* tile_marks,
                                  UINT64 tile_mark_count, ErUiGopDirtyTileList* list) {
  return er_ui_surface_dirty_tiles_reset(plan, tile_marks, tile_mark_count, list);
}

UINT8 er_ui_gop_dirty_tiles_mark_rect(const ErUiGopTilePlan* plan, float x, float y, float w, float h,
                                      UINT8* tile_marks, UINT64 tile_mark_count,
                                      ErUiGopDirtyTileList* list) {
  return er_ui_surface_dirty_tiles_mark_rect(plan, x, y, w, h, tile_marks, tile_mark_count, list);
}

UINT8 er_ui_gop_dirty_tiles_mark_scene(const ErUiGopTilePlan* plan, const er_ui_scene_t* scene,
                                       UINT8* tile_marks, UINT64 tile_mark_count,
                                       ErUiGopDirtyTileList* list) {
  return er_ui_surface_dirty_tiles_mark_scene(plan, scene, tile_marks, tile_mark_count, list);
}

UINT8 er_ui_gop_dirty_tiles_mark_scene_diff(const ErUiGopTilePlan* plan, const er_ui_scene_t* prev,
                                            const er_ui_scene_t* next, UINT8* tile_marks,
                                            UINT64 tile_mark_count, ErUiGopDirtyTileList* list) {
  return er_ui_surface_dirty_tiles_mark_scene_diff(plan, prev, next, tile_marks, tile_mark_count, list);
}

void er_ui_gop_frame_state_reset(ErUiGopFrameState* state) {
  er_ui_surface_frame_state_reset(state);
}

UINT8 er_ui_gop_frame_dirty_tiles(const ErUiGopFrameState* state, const ErUiGopTilePlan* plan,
                                  const er_ui_scene_t* prev, const er_ui_scene_t* next,
                                  UINT8* tile_marks, UINT64 tile_mark_count,
                                  ErUiGopDirtyTileList* list) {
  return er_ui_surface_frame_dirty_tiles(state, plan, prev, next, tile_marks, tile_mark_count, list);
}

void er_ui_gop_frame_state_commit(ErUiGopFrameState* state) {
  er_ui_surface_frame_state_commit(state);
}

ErUiGopFrameBudget er_ui_gop_frame_budget_from_plan(const ErUiGopTilePlan* tile_plan,
                                                    er_ui_scene_budget_t scene_budget,
                                                    UINT32 overdraw_budget) {
  return er_ui_surface_frame_budget_from_plan(tile_plan, scene_budget, overdraw_budget);
}

UINT8 er_ui_gop_render_stats_fits_budget(ErUiGopRenderStats stats, ErUiGopFrameBudget budget) {
  return er_ui_surface_render_stats_fits_budget(stats, budget);
}

UINT8 er_ui_gop_render_stats_first_budget_violation(ErUiGopRenderStats stats, ErUiGopFrameBudget budget,
                                                    ErUiGopFrameBudgetViolation* out_violation) {
  return er_ui_surface_render_stats_first_budget_violation(stats, budget, out_violation);
}

UINT32 er_ui_gop_pack_rgb(ErUiGopPixelFormat format, UINT8 r, UINT8 g, UINT8 b) {
  return er_ui_surface_pack_rgb(format, r, g, b);
}

UINT8 er_ui_gop_surface_clear(ErUiGopSurface* surface, er_ui_color4_t color) {
  return er_ui_surface_clear(surface, color);
}

UINT8 er_ui_gop_surface_render_scene(ErUiGopSurface* surface, const er_ui_scene_t* scene) {
  return er_ui_surface_render_scene(surface, scene);
}

UINT8 er_ui_gop_surface_render_scene_with_atlas(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                const ErUiGopAlphaAtlas* atlas) {
  return er_ui_surface_render_scene_with_atlas(surface, scene, atlas);
}

UINT8 er_ui_gop_surface_render_scene_with_font(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                               const vr_font_face_t* font) {
  return er_ui_surface_render_scene_with_font(surface, scene, font);
}

UINT8 er_ui_gop_surface_render_scene_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                     const vr_font_face_t* font,
                                                     ErUiGopRenderStats* out_stats) {
  return er_ui_surface_render_scene_with_font_stats(surface, scene, font, out_stats);
}

UINT8 er_ui_gop_surface_render_scene_tile_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                          const vr_font_face_t* font,
                                                          const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                          ErUiGopRenderStats* out_stats) {
  return er_ui_surface_render_scene_tile_with_font_stats(surface, scene, font, plan, tile_id, out_stats);
}

UINT8 er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(ErUiGopSurface* surface,
                                                                 const er_ui_scene_t* scene,
                                                                 const vr_font_face_t* font,
                                                                 const ErUiGopTilePlan* plan,
                                                                 const ErUiGopDirtyTileList* dirty_tiles,
                                                                 ErUiGopRenderStats* out_stats) {
  return er_ui_surface_render_scene_dirty_tiles_with_font_stats(surface, scene, font, plan,
                                                               dirty_tiles, out_stats);
}

#include "er_ui_gop_backend.h"
