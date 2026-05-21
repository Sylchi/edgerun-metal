#ifndef ER_UI_GOP_RENDERER_H
#define ER_UI_GOP_RENDERER_H

/*
 * Purpose: GOP-backed display adapter declarations.
 * Intention: GOP remains only the firmware scanout provider; UI core owns surface rendering.
 */

#include "er_types.h"
#include "er_ui_surface_renderer.h"
#include "er_ui_scene.h"
#include "vr_font.h"

UINT8 er_ui_gop_renderer_init(EFI_SYSTEM_TABLE* st);
UINT8 er_ui_gop_renderer_ready(void);
UINT8 er_ui_gop_renderer_mode(ErUiSurfaceMode* out_mode);
UINT8 er_ui_gop_renderer_tile_plan(UINT32 tile_width, UINT32 tile_height,
                                    UINT32 max_dirty_tiles, ErUiSurfaceTilePlan* out_plan);
UINT8 er_ui_gop_renderer_render_scene(const er_ui_scene_t* scene);
UINT8 er_ui_gop_renderer_render_scene_with_atlas(const er_ui_scene_t* scene, const ErUiSurfaceAlphaAtlas* atlas);
UINT8 er_ui_gop_renderer_render_scene_with_font(const er_ui_scene_t* scene, const vr_font_face_t* font);
UINT8 er_ui_gop_renderer_render_scene_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font,
                                                      ErUiSurfaceRenderStats* out_stats);
UINT8 er_ui_gop_renderer_render_scene_tile_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font,
                                                           const ErUiSurfaceTilePlan* plan, UINT32 tile_id,
                                                           ErUiSurfaceRenderStats* out_stats);
UINT8 er_ui_gop_renderer_render_scene_dirty_tiles_with_font_stats(const er_ui_scene_t* scene,
                                                                  const vr_font_face_t* font,
                                                                  const ErUiSurfaceTilePlan* plan,
                                                                  const ErUiSurfaceDirtyTileList* dirty_tiles,
                                                                  ErUiSurfaceRenderStats* out_stats);

#endif
