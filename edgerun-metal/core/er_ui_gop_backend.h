#ifndef ER_UI_GOP_BACKEND_H
#define ER_UI_GOP_BACKEND_H

/*
 * Purpose: keep UEFI GOP discovery and global renderer wrappers separate from surface raster code.
 * Intention: make the renderer source describe software drawing, while this file owns firmware binding.
 */

UINT8 er_ui_gop_renderer_init(EFI_SYSTEM_TABLE* st) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL* gop = 0;
  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION* info;

  g_ready = 0u;
  if (st == 0 || st->BootServices == 0 || st->BootServices->LocateProtocol == 0) {
    return 0u;
  }
  if (st->BootServices->LocateProtocol(&g_gop_guid, 0, (void**)&gop) != EFI_SUCCESS ||
      gop == 0 || gop->Mode == 0 || gop->Mode->Info == 0) {
    return 0u;
  }

  info = gop->Mode->Info;
  if (info->PixelFormat != PixelRedGreenBlueReserved8BitPerColor &&
      info->PixelFormat != PixelBlueGreenRedReserved8BitPerColor) {
    return 0u;
  }
  if (gop->Mode->FrameBufferBase == 0u || info->HorizontalResolution == 0u ||
      info->VerticalResolution == 0u || info->PixelsPerScanLine == 0u) {
    return 0u;
  }

  g_surface.pixels = (UINT32*)(UINTN)gop->Mode->FrameBufferBase;
  g_surface.width = info->HorizontalResolution;
  g_surface.height = info->VerticalResolution;
  g_surface.stride = info->PixelsPerScanLine;
  g_surface.pixel_format = info->PixelFormat == PixelBlueGreenRedReserved8BitPerColor ?
    ER_UI_GOP_PIXEL_BGRX : ER_UI_GOP_PIXEL_RGBX;
  g_ready = er_ui_gop_surface_valid(&g_surface);
  return g_ready;
}

UINT8 er_ui_gop_renderer_ready(void) {
  return g_ready;
}

UINT8 er_ui_gop_renderer_mode(ErUiGopMode* out_mode) {
  if (out_mode != 0) {
    *out_mode = (ErUiGopMode){0};
  }
  if (g_ready == 0u || out_mode == 0) {
    return 0u;
  }
  out_mode->width = g_surface.width;
  out_mode->height = g_surface.height;
  out_mode->stride = g_surface.stride;
  out_mode->refresh_hz = 1u;
  out_mode->pixel_format = g_surface.pixel_format;
  return er_ui_gop_mode_valid(out_mode);
}

UINT8 er_ui_gop_renderer_tile_plan(UINT32 tile_width, UINT32 tile_height,
                                   UINT32 max_dirty_tiles, ErUiGopTilePlan* out_plan) {
  if (g_ready == 0u) {
    if (out_plan != 0) {
      *out_plan = (ErUiGopTilePlan){0};
    }
    return 0u;
  }
  return er_ui_gop_tile_plan(&g_surface, tile_width, tile_height, max_dirty_tiles, out_plan);
}

UINT8 er_ui_gop_renderer_render_scene(const er_ui_scene_t* scene) {
  return er_ui_gop_renderer_render_scene_with_atlas(scene, 0);
}

UINT8 er_ui_gop_renderer_render_scene_with_atlas(const er_ui_scene_t* scene, const ErUiGopAlphaAtlas* atlas) {
  if (g_ready == 0u) {
    return 0u;
  }
  return er_ui_gop_surface_render_scene_with_atlas(&g_surface, scene, atlas);
}

UINT8 er_ui_gop_renderer_render_scene_with_font(const er_ui_scene_t* scene, const vr_font_face_t* font) {
  return er_ui_gop_renderer_render_scene_with_font_stats(scene, font, 0);
}

UINT8 er_ui_gop_renderer_render_scene_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font,
                                                      ErUiGopRenderStats* out_stats) {
  if (g_ready == 0u) {
    return 0u;
  }
  return er_ui_gop_surface_render_scene_with_font_stats(&g_surface, scene, font, out_stats);
}

UINT8 er_ui_gop_renderer_render_scene_tile_with_font_stats(const er_ui_scene_t* scene, const vr_font_face_t* font,
                                                           const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                           ErUiGopRenderStats* out_stats) {
  if (g_ready == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiGopRenderStats){0};
    }
    return 0u;
  }
  return er_ui_gop_surface_render_scene_tile_with_font_stats(&g_surface, scene, font, plan, tile_id, out_stats);
}

UINT8 er_ui_gop_renderer_render_scene_dirty_tiles_with_font_stats(const er_ui_scene_t* scene,
                                                                  const vr_font_face_t* font,
                                                                  const ErUiGopTilePlan* plan,
                                                                  const ErUiGopDirtyTileList* dirty_tiles,
                                                                  ErUiGopRenderStats* out_stats) {
  if (g_ready == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiGopRenderStats){0};
    }
    return 0u;
  }
  return er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(&g_surface, scene, font, plan,
                                                                    dirty_tiles, out_stats);
}

#endif
