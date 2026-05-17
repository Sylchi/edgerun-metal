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
  const UINT8* pixels;
  UINT32 width;
  UINT32 height;
  UINT32 bytes_per_pixel;
} ErUiGopAlphaAtlas;

UINT8 er_ui_gop_surface_valid(const ErUiGopSurface* surface);
UINT32 er_ui_gop_pack_rgb(ErUiGopPixelFormat format, UINT8 r, UINT8 g, UINT8 b);
UINT8 er_ui_gop_surface_clear(ErUiGopSurface* surface, er_ui_color4_t color);
UINT8 er_ui_gop_surface_render_scene(ErUiGopSurface* surface, const er_ui_scene_t* scene);
UINT8 er_ui_gop_surface_render_scene_with_atlas(ErUiGopSurface* surface, const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas);
UINT8 er_ui_gop_surface_render_scene_with_font(ErUiGopSurface* surface, const er_ui_scene_t* scene, const vr_font_face_t* font);

UINT8 er_ui_gop_renderer_init(EFI_SYSTEM_TABLE* st);
UINT8 er_ui_gop_renderer_ready(void);
UINT8 er_ui_gop_renderer_render_scene(const er_ui_scene_t* scene);
UINT8 er_ui_gop_renderer_render_scene_with_atlas(const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas);
UINT8 er_ui_gop_renderer_render_scene_with_font(const er_ui_scene_t* scene, const vr_font_face_t* font);

#endif
