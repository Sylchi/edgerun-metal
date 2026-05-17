#ifndef ER_UI_GOP_RENDERER_H
#define ER_UI_GOP_RENDERER_H

/*
 * Purpose: render platform-neutral EdgeRun UI scenes into a UEFI GOP framebuffer.
 * Intention: keep the metal display backend explicit, testable, and independent of host APIs.
 */

#include "er_types.h"
#include "er_ui_scene.h"
#include "vr_font.h"

typedef enum {
  ER_UI_GOP_PIXEL_RGBX = 0,
  ER_UI_GOP_PIXEL_BGRX = 1
} ErUiGopPixelFormat;

typedef struct {
  UINT32* pixels;
  UINT32 width;
  UINT32 height;
  UINT32 stride;
  ErUiGopPixelFormat pixel_format;
} ErUiGopSurface;

typedef struct {
  UINT32 width;
  UINT32 height;
  UINT32 stride;
  UINT32 refresh_hz;
  ErUiGopPixelFormat pixel_format;
} ErUiGopMode;

typedef struct {
  const UINT8* pixels;
  UINT32 width;
  UINT32 height;
  UINT32 bytes_per_pixel;
} ErUiGopAlphaAtlas;

typedef struct {
  UINT64 pixels_written;
  UINT64 bytes_written;
  UINT64 blend_pixels;
  UINT64 text_pixels;
  UINT64 clears;
  UINT64 rects;
  UINT64 solid_rects;
  UINT64 gradient_rects;
  UINT64 border_rects;
  UINT64 icon_quads;
  UINT64 text_quads;
  UINT64 tiles_rendered;
  UINT64 dirty_tiles_requested;
  UINT64 clipped_primitives;
  UINT64 rejected_primitives;
} ErUiGopRenderStats;

typedef struct {
  UINT64 pixels_written;
  UINT64 bytes_written;
  UINT64 blend_pixels;
  UINT64 text_pixels;
  UINT64 rects;
  UINT64 icon_quads;
  UINT64 text_quads;
  UINT64 tiles_rendered;
  UINT64 dirty_tiles_requested;
  UINT64 clipped_primitives;
  UINT64 rejected_primitives;
} ErUiGopFrameBudget;

typedef struct {
  const char* name;
  UINT64 actual;
  UINT64 limit;
} ErUiGopFrameBudgetViolation;

typedef struct {
  UINT32 width;
  UINT32 height;
  UINT32 stride;
  UINT32 bytes_per_pixel;
  UINT32 tile_width;
  UINT32 tile_height;
  UINT32 columns;
  UINT32 rows;
  UINT32 max_dirty_tiles;
  UINT64 tile_count;
  UINT64 scanout_bytes;
  UINT64 full_frame_bytes;
  UINT64 max_tile_bytes;
  UINT64 tile_state_bytes;
  UINT64 dirty_queue_bytes;
} ErUiGopTilePlan;

typedef struct {
  UINT32 refresh_hz;
  UINT32 overdraw_budget;
  UINT64 scanout_bytes_per_second;
  UINT64 full_frame_bytes_per_second;
  UINT64 budget_bytes_per_second;
} ErUiGopBandwidthPlan;

typedef struct {
  UINT32 backing_buffer_count;
  UINT64 scanout_bytes;
  UINT64 backing_bytes;
  UINT64 tile_state_bytes;
  UINT64 dirty_queue_bytes;
  UINT64 command_bytes;
  UINT64 glyph_cache_bytes;
  UINT64 surface_bytes;
  UINT64 total_bytes;
} ErUiGopMemoryPlan;

typedef struct {
  UINT64 scanout_bytes;
  UINT64 backing_bytes;
  UINT64 tile_state_bytes;
  UINT64 dirty_queue_bytes;
  UINT64 command_bytes;
  UINT64 glyph_cache_bytes;
  UINT64 surface_bytes;
  UINT64 total_bytes;
} ErUiGopMemoryBudget;

typedef struct {
  const char* name;
  UINT64 actual;
  UINT64 limit;
} ErUiGopMemoryBudgetViolation;

typedef struct {
  UINT32* tile_ids;
  UINT32 capacity;
  UINT32 count;
  UINT8 overflowed;
} ErUiGopDirtyTileList;

typedef struct {
  UINT32 x0;
  UINT32 y0;
  UINT32 x1;
  UINT32 y1;
} ErUiGopPixelRect;

typedef struct {
  UINT8 has_previous_scene;
} ErUiGopFrameState;

UINT8 er_ui_gop_surface_valid(const ErUiGopSurface* surface);
UINT8 er_ui_gop_mode_valid(const ErUiGopMode* mode);
UINT8 er_ui_gop_tile_plan_from_mode(const ErUiGopMode* mode, UINT32 tile_width, UINT32 tile_height,
                                    UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan);
UINT8 er_ui_gop_tile_plan(const ErUiGopSurface* surface, UINT32 tile_width, UINT32 tile_height,
                          UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan);
UINT8 er_ui_gop_bandwidth_plan_from_mode(const ErUiGopMode* mode, UINT32 overdraw_budget,
                                         ErUiGopBandwidthPlan* out_plan);
UINT8 er_ui_gop_memory_plan_from_tile_plan(const ErUiGopTilePlan* tile_plan, UINT32 backing_buffer_count,
                                           UINT64 command_bytes, UINT64 glyph_cache_bytes,
                                           UINT64 surface_bytes, ErUiGopMemoryPlan* out_plan);
UINT8 er_ui_gop_memory_plan_fits_budget(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget);
UINT8 er_ui_gop_memory_plan_first_budget_violation(ErUiGopMemoryPlan plan, ErUiGopMemoryBudget budget,
                                                   ErUiGopMemoryBudgetViolation* out_violation);
UINT8 er_ui_gop_tile_rect(const ErUiGopTilePlan* plan, UINT32 tile_id, ErUiGopPixelRect* out_rect);
UINT8 er_ui_gop_dirty_tiles_reset(const ErUiGopTilePlan* plan, UINT8* tile_marks,
                                  UINT64 tile_mark_count, ErUiGopDirtyTileList* list);
UINT8 er_ui_gop_dirty_tiles_mark_rect(const ErUiGopTilePlan* plan, float x, float y, float w, float h,
                                      UINT8* tile_marks, UINT64 tile_mark_count,
                                      ErUiGopDirtyTileList* list);
UINT8 er_ui_gop_dirty_tiles_mark_scene(const ErUiGopTilePlan* plan, const er_ui_scene_t* scene,
                                       UINT8* tile_marks, UINT64 tile_mark_count,
                                       ErUiGopDirtyTileList* list);
UINT8 er_ui_gop_dirty_tiles_mark_scene_diff(const ErUiGopTilePlan* plan, const er_ui_scene_t* prev,
                                            const er_ui_scene_t* next, UINT8* tile_marks,
                                            UINT64 tile_mark_count, ErUiGopDirtyTileList* list);
void er_ui_gop_frame_state_reset(ErUiGopFrameState* state);
UINT8 er_ui_gop_frame_dirty_tiles(const ErUiGopFrameState* state, const ErUiGopTilePlan* plan,
                                  const er_ui_scene_t* prev, const er_ui_scene_t* next,
                                  UINT8* tile_marks, UINT64 tile_mark_count,
                                  ErUiGopDirtyTileList* list);
void er_ui_gop_frame_state_commit(ErUiGopFrameState* state);
ErUiGopFrameBudget er_ui_gop_frame_budget_from_plan(const ErUiGopTilePlan* tile_plan,
                                                    er_ui_scene_budget_t scene_budget,
                                                    UINT32 overdraw_budget);
UINT8 er_ui_gop_render_stats_fits_budget(ErUiGopRenderStats stats, ErUiGopFrameBudget budget);
UINT8 er_ui_gop_render_stats_first_budget_violation(ErUiGopRenderStats stats, ErUiGopFrameBudget budget,
                                                    ErUiGopFrameBudgetViolation* out_violation);
UINT32 er_ui_gop_pack_rgb(ErUiGopPixelFormat format, UINT8 r, UINT8 g, UINT8 b);
UINT8 er_ui_gop_surface_clear(ErUiGopSurface* surface, er_ui_color4_t color);
UINT8 er_ui_gop_surface_render_scene(ErUiGopSurface* surface, const er_ui_scene_t* scene);
UINT8 er_ui_gop_surface_render_scene_with_atlas(ErUiGopSurface* surface, const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas);
UINT8 er_ui_gop_surface_render_scene_with_font(ErUiGopSurface* surface, const er_ui_scene_t* scene, const vr_font_face_t* font);
UINT8 er_ui_gop_surface_render_scene_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene, const vr_font_face_t* font, ErUiGopRenderStats* out_stats);
UINT8 er_ui_gop_surface_render_scene_tile_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                          const vr_font_face_t* font,
                                                          const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                          ErUiGopRenderStats* out_stats);
UINT8 er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(ErUiGopSurface* surface,
                                                                 const er_ui_scene_t* scene,
                                                                 const vr_font_face_t* font,
                                                                 const ErUiGopTilePlan* plan,
                                                                 const ErUiGopDirtyTileList* dirty_tiles,
                                                                 ErUiGopRenderStats* out_stats);

UINT8 er_ui_gop_renderer_init(EFI_SYSTEM_TABLE* st);
UINT8 er_ui_gop_renderer_ready(void);
UINT8 er_ui_gop_renderer_mode(ErUiGopMode* out_mode);
UINT8 er_ui_gop_renderer_tile_plan(UINT32 tile_width, UINT32 tile_height,
                                    UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan);
UINT8 er_ui_gop_renderer_render_scene(const er_ui_scene_t* scene);
UINT8 er_ui_gop_renderer_render_scene_with_atlas(const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas);
UINT8 er_ui_gop_renderer_render_scene_with_font(const er_ui_scene_t* scene, const vr_font_face_t* font);
UINT8 er_ui_gop_renderer_render_scene_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font, ErUiGopRenderStats* out_stats);
UINT8 er_ui_gop_renderer_render_scene_tile_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font,
                                                           const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                           ErUiGopRenderStats* out_stats);
UINT8 er_ui_gop_renderer_render_scene_dirty_tiles_with_font_stats(const er_ui_scene_t* scene,
                                                                  const vr_font_face_t* font,
                                                                  const ErUiGopTilePlan* plan,
                                                                  const ErUiGopDirtyTileList* dirty_tiles,
                                                                  ErUiGopRenderStats* out_stats);

#endif
