#ifndef ER_UI_GOP_SURFACE_RENDER_H
#define ER_UI_GOP_SURFACE_RENDER_H

/*
 * Purpose: collect surface-level clear and scene render entry points.
 * Intention: keep primitive raster helpers separate from frame orchestration.
 */

//@optimizer-ignore-function GOP clear must write each framebuffer pixel in the target rectangle
static UINT8 er_ui_gop_surface_clear_rect_stats(ErUiGopSurface* surface, er_ui_color4_t color,
                                                const ErUiGopPixelRect* clip,
                                                ErUiGopRenderStats* stats) {
  UINT32 y;
  UINT32 x;
  UINT32 packed;
  UINT32 x0 = 0u;
  UINT32 y0 = 0u;
  UINT32 x1;
  UINT32 y1;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    return 0u;
  }
  x1 = surface->width;
  y1 = surface->height;
  if (clip != 0) {
    x0 = clip->x0;
    y0 = clip->y0;
    x1 = clip->x1;
    y1 = clip->y1;
    if (x0 > surface->width) x0 = surface->width;
    if (y0 > surface->height) y0 = surface->height;
    if (x1 > surface->width) x1 = surface->width;
    if (y1 > surface->height) y1 = surface->height;
    if (x0 >= x1 || y0 >= y1) return 0u;
  }

  packed = er_ui_gop_pack_rgb(surface->pixel_format,
                              er_ui_gop_u8_from_unit(color.r),
                              er_ui_gop_u8_from_unit(color.g),
                              er_ui_gop_u8_from_unit(color.b));
  if (stats != 0) {
    ++stats->clears;
    er_ui_gop_stats_add_pixels(stats, (UINT64)(x1 - x0) * (UINT64)(y1 - y0), 0u, 0u);
  }
  for (y = y0; y < y1; ++y) {
    UINT32* row = surface->pixels + ((UINTN)y * (UINTN)surface->stride);
    for (x = x0; x < x1; ++x) {
      row[x] = packed;
    }
  }
  return 1u;
}

static UINT8 er_ui_gop_surface_clear_stats(ErUiGopSurface* surface, er_ui_color4_t color,
                                           ErUiGopRenderStats* stats) {
  return er_ui_gop_surface_clear_rect_stats(surface, color, 0, stats);
}

UINT8 er_ui_gop_surface_clear(ErUiGopSurface* surface, er_ui_color4_t color) {
  return er_ui_gop_surface_clear_stats(surface, color, 0);
}

UINT8 er_ui_gop_surface_render_scene(ErUiGopSurface* surface, const er_ui_scene_t* scene) {
  return er_ui_gop_surface_render_scene_with_atlas(surface, scene, 0);
}

UINT8 er_ui_gop_surface_render_scene_with_atlas(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                const ErUiGopAlphaAtlas* atlas) {
  return er_ui_gop_surface_render_scene_with_atlas_stats(surface, scene, atlas, 0);
}

//@optimizer-ignore-function scene rendering must visit each recorded primitive stream in deterministic order
static UINT8 er_ui_gop_surface_render_scene_with_atlas_clip_stats(ErUiGopSurface* surface,
                                                                  const er_ui_scene_t* scene,
                                                                  const ErUiGopAlphaAtlas* atlas,
                                                                  const ErUiGopPixelRect* clip,
                                                                  ErUiGopRenderStats* stats) {
  size_t i;

  if (stats != 0) {
    *stats = (ErUiGopRenderStats){0};
  }
  if (er_ui_gop_surface_valid(surface) == 0u || scene == 0) {
    return 0u;
  }

  if (er_ui_gop_surface_clear_rect_stats(surface, scene->clear, clip, stats) == 0u) {
    return 0u;
  }

  for (i = 0u; i < scene->rect_count; ++i) {
    er_ui_gop_render_rect(surface, scene->rects[i], clip, stats);
  }
  for (i = 0u; i < scene->icon_quad_count; ++i) {
    er_ui_gop_render_icon_quad(surface, &scene->icon_quads[i], clip, stats);
  }
  if (atlas != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_gop_render_text_quad_with_alpha_atlas(surface, &scene->text_quads[i], atlas, clip, stats);
    }
  }
  return 1u;
}

static UINT8 er_ui_gop_surface_render_scene_with_atlas_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                             const ErUiGopAlphaAtlas* atlas,
                                                             ErUiGopRenderStats* stats) {
  return er_ui_gop_surface_render_scene_with_atlas_clip_stats(surface, scene, atlas, 0, stats);
}

UINT8 er_ui_gop_surface_render_scene_with_font(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                               const vr_font_face_t* font) {
  return er_ui_gop_surface_render_scene_with_font_stats(surface, scene, font, 0);
}

UINT8 er_ui_gop_surface_render_scene_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                     const vr_font_face_t* font,
                                                     ErUiGopRenderStats* out_stats) {
  return er_ui_gop_surface_render_scene_tile_with_font_stats(surface, scene, font, 0, 0u, out_stats);
}

//@optimizer-ignore-function font-backed scene rendering must visit each text quad after base primitive rendering
UINT8 er_ui_gop_surface_render_scene_tile_with_font_stats(ErUiGopSurface* surface, const er_ui_scene_t* scene,
                                                          const vr_font_face_t* font,
                                                          const ErUiGopTilePlan* plan, UINT32 tile_id,
                                                          ErUiGopRenderStats* out_stats) {
  size_t i;
  ErUiGopPixelRect clip;
  const ErUiGopPixelRect* clip_ptr = 0;

  if (er_ui_gop_surface_valid(surface) == 0u) {
    if (out_stats != 0) {
      *out_stats = (ErUiGopRenderStats){0};
    }
    return 0u;
  }
  if (plan != 0) {
    if (er_ui_gop_tile_rect(plan, tile_id, &clip) == 0u ||
        plan->width != surface->width || plan->height != surface->height || plan->stride != surface->stride) {
      if (out_stats != 0) {
        *out_stats = (ErUiGopRenderStats){0};
      }
      return 0u;
    }
    clip_ptr = &clip;
  }

  if (er_ui_gop_surface_render_scene_with_atlas_clip_stats(surface, scene, 0, clip_ptr, out_stats) == 0u) {
    return 0u;
  }
  if (clip_ptr != 0 && out_stats != 0) {
    out_stats->tiles_rendered = 1u;
  }
  if (font != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_gop_render_text_quad(surface, &scene->text_quads[i], font, clip_ptr, out_stats);
    }
  }
  return 1u;
}

//@optimizer-ignore-function dirty rendering must redraw each requested tile deterministically
UINT8 er_ui_gop_surface_render_scene_dirty_tiles_with_font_stats(ErUiGopSurface* surface,
                                                                 const er_ui_scene_t* scene,
                                                                 const vr_font_face_t* font,
                                                                 const ErUiGopTilePlan* plan,
                                                                 const ErUiGopDirtyTileList* dirty_tiles,
                                                                 ErUiGopRenderStats* out_stats) {
  UINT32 i;
  ErUiGopRenderStats total;

  if (out_stats != 0) {
    *out_stats = (ErUiGopRenderStats){0};
  }
  if (surface == 0 || scene == 0 || plan == 0 || dirty_tiles == 0 || dirty_tiles->tile_ids == 0 ||
      dirty_tiles->overflowed != 0u || dirty_tiles->count > dirty_tiles->capacity) {
    return 0u;
  }

  total = (ErUiGopRenderStats){0};
  total.dirty_tiles_requested = dirty_tiles->count;
  for (i = 0u; i < dirty_tiles->count; ++i) {
    ErUiGopRenderStats tile_stats;
    if (er_ui_gop_surface_render_scene_tile_with_font_stats(surface, scene, font, plan,
                                                            dirty_tiles->tile_ids[i], &tile_stats) == 0u) {
      if (out_stats != 0) {
        *out_stats = (ErUiGopRenderStats){0};
      }
      return 0u;
    }
    er_ui_gop_stats_add(&total, &tile_stats);
  }
  if (out_stats != 0) {
    total.dirty_tiles_requested = dirty_tiles->count;
    *out_stats = total;
  }
  return 1u;
}

#endif
