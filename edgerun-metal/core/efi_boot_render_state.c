#include "internal/efi_boot_internal.h"

enum {
  ER_UI_BOOT_PRESENT_TILE_CLEAN = 0u,
  ER_UI_BOOT_PRESENT_TILE_DIRTY = 1u,
  ER_UI_BOOT_PRESENT_TILE_USED = 2u
};

static UINT32 er_ui_boot_present_tile_id(const ErUiSurfaceTilePlan* plan,
                                         UINT32 column,
                                         UINT32 row) {
  return row * plan->columns + column;
}

static UINT8 er_ui_boot_present_row_run_dirty(const ErUiBootRenderContext* render,
                                              UINT32 row,
                                              UINT32 column,
                                              UINT32 column_count) {
  UINT32 i;

  for (i = 0u; i < column_count; ++i) {
    if (render->tile_marks[er_ui_boot_present_tile_id(render->tile_plan,
                                                      column + i,
                                                      row)] !=
        ER_UI_BOOT_PRESENT_TILE_DIRTY) {
      return 0u;
    }
  }
  return 1u;
}

static void er_ui_boot_present_mark_run_used(ErUiBootRenderContext* render,
                                             UINT32 row,
                                             UINT32 column,
                                             UINT32 column_count) {
  UINT32 i;

  for (i = 0u; i < column_count; ++i) {
    render->tile_marks[er_ui_boot_present_tile_id(render->tile_plan,
                                                  column + i,
                                                  row)] =
      ER_UI_BOOT_PRESENT_TILE_USED;
  }
}

static UINT8 er_ui_boot_copy_render_primitives(er_ui_scene_t* dst,
                                               const er_ui_scene_t* src) {
  size_t i;

  if (dst == 0 || src == 0) {
    return 0u;
  }

  er_ui_scene_clear_commands(dst);
  dst->clear = src->clear;

  for (i = 0u; i < src->rect_count; ++i) {
    if (er_ui_scene_push_rect(dst, src->rects[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < src->icon_quad_count; ++i) {
    if (er_ui_scene_push_icon_quad(dst, src->icon_quads[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < src->text_quad_count; ++i) {
    if (er_ui_scene_push_text_quad(dst, src->text_quads[i]) != ER_UI_OK) {
      return 0u;
    }
  }

  return 1u;
}

UINT8 er_ui_boot_dirty_present_rects(ErUiBootRenderContext* render) {
  UINT32 i;
  UINT32 row;
  UINT32 column;
  UINT32 run_columns;
  UINT32 run_rows;
  UINT32 tile_id;
  ErUiSurfacePixelRect* rect;

  if (render == 0 || render->tile_plan == 0 ||
      render->tile_marks == 0 || render->present_rects == 0 ||
      render->present_rect_capacity == 0u ||
      render->tile_plan->tile_count == 0u ||
      render->tile_plan->tile_count > render->tile_mark_count ||
      render->tile_plan->tile_count > UINT32_MAX ||
      render->last_dirty_tiles.overflowed != 0u ||
      render->last_dirty_tiles.tile_ids == 0) {
    return 0u;
  }

  render->last_present_rect_count = 0u;
  for (i = 0u; i < render->tile_plan->tile_count; ++i) {
    render->tile_marks[i] = ER_UI_BOOT_PRESENT_TILE_CLEAN;
  }
  for (i = 0u; i < render->last_dirty_tiles.count; ++i) {
    tile_id = render->last_dirty_tiles.tile_ids[i];
    if ((UINT64)tile_id >= render->tile_plan->tile_count) {
      return 0u;
    }
    render->tile_marks[tile_id] = ER_UI_BOOT_PRESENT_TILE_DIRTY;
  }

  for (row = 0u; row < render->tile_plan->rows; ++row) {
    for (column = 0u; column < render->tile_plan->columns; ++column) {
      tile_id = er_ui_boot_present_tile_id(render->tile_plan, column, row);
      if (render->tile_marks[tile_id] != ER_UI_BOOT_PRESENT_TILE_DIRTY) {
        continue;
      }
      run_columns = 0u;
      while (column + run_columns < render->tile_plan->columns &&
             render->tile_marks[er_ui_boot_present_tile_id(render->tile_plan,
                                                           column + run_columns,
                                                           row)] ==
               ER_UI_BOOT_PRESENT_TILE_DIRTY) {
        ++run_columns;
      }
      run_rows = 1u;
      while (row + run_rows < render->tile_plan->rows &&
             er_ui_boot_present_row_run_dirty(render,
                                              row + run_rows,
                                              column,
                                              run_columns) != 0u) {
        ++run_rows;
      }
      if (render->last_present_rect_count >= render->present_rect_capacity) {
        return 0u;
      }
      rect = &render->present_rects[render->last_present_rect_count];
      rect->x0 = column * render->tile_plan->tile_width;
      rect->y0 = row * render->tile_plan->tile_height;
      rect->x1 = (column + run_columns) * render->tile_plan->tile_width;
      rect->y1 = (row + run_rows) * render->tile_plan->tile_height;
      if (rect->x1 > render->tile_plan->width) rect->x1 = render->tile_plan->width;
      if (rect->y1 > render->tile_plan->height) rect->y1 = render->tile_plan->height;
      if (rect->x0 >= rect->x1 || rect->y0 >= rect->y1) {
        return 0u;
      }
      for (i = 0u; i < run_rows; ++i) {
        er_ui_boot_present_mark_run_used(render, row + i, column, run_columns);
      }
      ++render->last_present_rect_count;
    }
  }
  return 1u;
}

UINT8 er_ui_boot_prepare_dirty_tiles(ErUiBootRenderContext* render,
                                     const er_ui_scene_t* scene,
                                     ErUiSurfaceDirtyTileList* out_dirty_tiles) {
  if (render == 0 || scene == 0 || out_dirty_tiles == 0 ||
      render->tile_plan == 0 || render->tile_marks == 0 ||
      render->tile_mark_count == 0u || render->dirty_tile_ids == 0 ||
      render->dirty_tile_capacity == 0u || render->previous_scene == 0) {
    return 0u;
  }

  *out_dirty_tiles = (ErUiSurfaceDirtyTileList){
    render->dirty_tile_ids,
    render->dirty_tile_capacity,
    0u,
    0u
  };
  if (er_ui_surface_frame_dirty_tiles(&render->frame_state,
                                      render->tile_plan,
                                      render->previous_scene,
                                      scene,
                                      render->tile_marks,
                                      render->tile_mark_count,
                                      out_dirty_tiles) == 0u ||
      out_dirty_tiles->overflowed != 0u) {
    return 0u;
  }

  render->last_dirty_tiles = *out_dirty_tiles;
  return 1u;
}

UINT8 er_ui_boot_commit_rendered_scene(ErUiBootRenderContext* render,
                                       const er_ui_scene_t* scene) {
  if (render == 0 || scene == 0 || render->previous_scene == 0) {
    return 0u;
  }
  if (er_ui_boot_copy_render_primitives(render->previous_scene, scene) == 0u) {
    return 0u;
  }
  er_ui_surface_frame_state_commit(&render->frame_state);
  return 1u;
}
