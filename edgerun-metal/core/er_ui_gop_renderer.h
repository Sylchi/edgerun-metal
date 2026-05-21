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
UINT8 er_ui_gop_renderer_render(const ErUiSurfaceRenderDesc* desc);

#endif
