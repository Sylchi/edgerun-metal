#include "efi_boot_internal.h"

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
