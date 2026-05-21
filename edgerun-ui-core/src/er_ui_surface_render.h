#ifndef ER_UI_SURFACE_SURFACE_RENDER_H
#define ER_UI_SURFACE_SURFACE_RENDER_H

/*
 * Purpose: collect surface-level clear and scene render entry points.
 * Intention: keep primitive raster helpers separate from frame orchestration.
 */

//@optimizer-ignore-function surface clear must write each framebuffer pixel in the target rectangle
static uint8_t er_ui_surface_clear_rect_stats(ErUiSurface* surface, er_ui_color4_t color,
                                                const ErUiSurfacePixelRect* clip,
                                                ErUiSurfaceRenderStats* stats) {
  uint32_t y;
  uint32_t x;
  uint32_t packed;
  uint32_t x0 = 0u;
  uint32_t y0 = 0u;
  uint32_t x1;
  uint32_t y1;

  if (er_ui_surface_valid(surface) == 0u) {
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

  packed = er_ui_surface_pack_rgb(surface->pixel_format,
                              er_ui_surface_u8_from_unit(color.r),
                              er_ui_surface_u8_from_unit(color.g),
                              er_ui_surface_u8_from_unit(color.b));
  if (stats != 0) {
    ++stats->clears;
    er_ui_surface_stats_add_pixels(stats, (uint64_t)(x1 - x0) * (uint64_t)(y1 - y0), 0u, 0u);
  }
  for (y = y0; y < y1; ++y) {
    uint32_t* row = surface->pixels + ((size_t)y * (size_t)surface->stride);
    for (x = x0; x < x1; ++x) {
      row[x] = packed;
    }
  }
  return 1u;
}

static uint8_t er_ui_surface_clear_stats(ErUiSurface* surface, er_ui_color4_t color,
                                           ErUiSurfaceRenderStats* stats) {
  return er_ui_surface_clear_rect_stats(surface, color, 0, stats);
}

uint8_t er_ui_surface_clear(ErUiSurface* surface, er_ui_color4_t color) {
  return er_ui_surface_clear_stats(surface, color, 0);
}

//@optimizer-ignore-function scene rendering must visit each recorded primitive stream in deterministic order
static uint8_t er_ui_surface_render_clipped(ErUiSurface* surface,
                                                                  const er_ui_scene_t* scene,
                                                                  const ErUiSurfaceAlphaAtlas* atlas,
                                                                  const ErUiSurfacePixelRect* clip,
                                                                  ErUiSurfaceRenderStats* stats) {
  size_t i;

  if (stats != 0) {
    *stats = (ErUiSurfaceRenderStats){0};
  }
  if (er_ui_surface_valid(surface) == 0u || scene == 0) {
    return 0u;
  }

  if (er_ui_surface_clear_rect_stats(surface, scene->clear, clip, stats) == 0u) {
    return 0u;
  }

  for (i = 0u; i < scene->rect_count; ++i) {
    er_ui_surface_render_rect(surface, scene->rects[i], clip, stats);
  }
  for (i = 0u; i < scene->icon_quad_count; ++i) {
    er_ui_surface_render_icon_quad(surface, &scene->icon_quads[i], clip, stats);
  }
  if (atlas != 0) {
    for (i = 0u; i < scene->text_quad_count; ++i) {
      er_ui_surface_render_text_quad_with_alpha_atlas(surface, &scene->text_quads[i], atlas, clip, stats);
    }
  }
  return 1u;
}

//@optimizer-ignore-function font-backed scene rendering must visit each text quad after base primitive rendering
static uint8_t er_ui_surface_render_tile(ErUiSurface* surface, const ErUiSurfaceRenderDesc* desc) {
  size_t i;
  ErUiSurfacePixelRect clip;
  const ErUiSurfacePixelRect* clip_ptr = 0;

  if (er_ui_surface_valid(surface) == 0u) {
    if (desc->out_stats != 0) {
      *desc->out_stats = (ErUiSurfaceRenderStats){0};
    }
    return 0u;
  }
  if (desc->mode == ER_UI_SURFACE_RENDER_TILE) {
    if (desc->tile_plan == 0 ||
        er_ui_surface_tile_rect(desc->tile_plan, desc->tile_id, &clip) == 0u ||
        desc->tile_plan->width != surface->width ||
        desc->tile_plan->height != surface->height ||
        desc->tile_plan->stride != surface->stride) {
      if (desc->out_stats != 0) {
        *desc->out_stats = (ErUiSurfaceRenderStats){0};
      }
      return 0u;
    }
    clip_ptr = &clip;
  }

  if (desc->font != 0 && desc->atlas != 0) {
    if (desc->out_stats != 0) {
      *desc->out_stats = (ErUiSurfaceRenderStats){0};
    }
    return 0u;
  }
  if (er_ui_surface_render_clipped(surface, desc->scene, desc->atlas, clip_ptr, desc->out_stats) == 0u) {
    return 0u;
  }
  if (clip_ptr != 0 && desc->out_stats != 0) {
    desc->out_stats->tiles_rendered = 1u;
  }
  if (desc->font != 0) {
    for (i = 0u; i < desc->scene->text_quad_count; ++i) {
      er_ui_surface_render_text_quad(surface, &desc->scene->text_quads[i], desc->font, clip_ptr, desc->out_stats);
    }
  }
  return 1u;
}

//@optimizer-ignore-function dirty rendering must redraw each requested tile deterministically
static uint8_t er_ui_surface_render_dirty_tiles(ErUiSurface* surface, const ErUiSurfaceRenderDesc* desc) {
  uint32_t i;
  ErUiSurfaceRenderStats total;

  if (desc->out_stats != 0) {
    *desc->out_stats = (ErUiSurfaceRenderStats){0};
  }
  if (surface == 0 || desc->scene == 0 || desc->tile_plan == 0 ||
      desc->dirty_tiles == 0 || desc->dirty_tiles->tile_ids == 0 ||
      desc->dirty_tiles->overflowed != 0u || desc->dirty_tiles->count > desc->dirty_tiles->capacity) {
    return 0u;
  }

  total = (ErUiSurfaceRenderStats){0};
  total.dirty_tiles_requested = desc->dirty_tiles->count;
  for (i = 0u; i < desc->dirty_tiles->count; ++i) {
    ErUiSurfaceRenderStats tile_stats;
    ErUiSurfaceRenderDesc tile_desc = *desc;
    tile_desc.mode = ER_UI_SURFACE_RENDER_TILE;
    tile_desc.tile_id = desc->dirty_tiles->tile_ids[i];
    tile_desc.out_stats = &tile_stats;
    if (er_ui_surface_render_tile(surface, &tile_desc) == 0u) {
      if (desc->out_stats != 0) {
        *desc->out_stats = (ErUiSurfaceRenderStats){0};
      }
      return 0u;
    }
    er_ui_surface_stats_add(&total, &tile_stats);
  }
  if (desc->out_stats != 0) {
    total.dirty_tiles_requested = desc->dirty_tiles->count;
    *desc->out_stats = total;
  }
  return 1u;
}

uint8_t er_ui_surface_render(ErUiSurface* surface, const ErUiSurfaceRenderDesc* desc) {
  if (desc == 0 || desc->scene == 0) {
    return 0u;
  }
  switch (desc->mode) {
    case ER_UI_SURFACE_RENDER_FULL:
    case ER_UI_SURFACE_RENDER_TILE:
      return er_ui_surface_render_tile(surface, desc);
    case ER_UI_SURFACE_RENDER_DIRTY_TILES:
      return er_ui_surface_render_dirty_tiles(surface, desc);
    default:
      return 0u;
  }
}

#endif
