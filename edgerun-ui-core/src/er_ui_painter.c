#include "er_ui_painter.h"

er_ui_painter_t er_ui_painter(er_ui_scene_t* scene) {
  er_ui_painter_t painter = {scene};
  return painter;
}

er_ui_status_t er_ui_painter_fill_rect(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(painter->scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
}

er_ui_status_t er_ui_painter_border_rect(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t color) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(painter->scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, radius, color));
}

er_ui_status_t er_ui_painter_shadow_rect(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t color, float shadow) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(painter->scene, er_ui_rect_shadow(bounds.x, bounds.y, bounds.w, bounds.h, radius, color, shadow));
}

er_ui_status_t er_ui_painter_panel(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t fill, er_ui_color4_t border) {
  er_ui_status_t status = er_ui_painter_fill_rect(painter, bounds, radius, fill);
  if (status != ER_UI_OK) return status;
  return er_ui_painter_border_rect(painter, bounds, radius, border);
}

er_ui_status_t er_ui_painter_card(er_ui_painter_t* painter, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  er_ui_status_t status =
    er_ui_painter_shadow_rect(painter, bounds, theme.design.radius.xl, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 0.08f), 8.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_painter_panel(painter, bounds, theme.design.radius.xl, theme.design.colors.card, theme.design.colors.border);
}

er_ui_status_t er_ui_painter_soft_card(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t fill) {
  er_ui_bounds_t shadow = bounds;
  shadow.y += 10.0f;
  er_ui_status_t status = er_ui_painter_shadow_rect(painter, shadow, radius, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 0.22f), 24.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_painter_fill_rect(painter, bounds, radius, fill);
}

er_ui_status_t er_ui_painter_divider(er_ui_painter_t* painter, float x, float y, float length, er_ui_axis_t axis, er_ui_color4_t color) {
  er_ui_bounds_t bounds = axis == ER_UI_AXIS_VERTICAL ? er_ui_bounds(x, y, 1.0f, length) : er_ui_bounds(x, y, length, 1.0f);
  return er_ui_painter_fill_rect(painter, bounds, 0.0f, color);
}

er_ui_status_t er_ui_painter_hit(er_ui_painter_t* painter, er_ui_hit_kind_t kind, uint32_t id, er_ui_bounds_t bounds) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_hit(painter->scene, er_ui_hit(kind, id, bounds.x, bounds.y, bounds.w, bounds.h));
}

er_ui_status_t er_ui_painter_drag_source(er_ui_painter_t* painter, uint32_t scope_id, uint32_t item_id, size_t index, er_ui_bounds_t bounds) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_drag_source(painter->scene, er_ui_drag_source(scope_id, item_id, index, bounds.x, bounds.y, bounds.w, bounds.h));
}

er_ui_status_t er_ui_painter_drop_target(er_ui_painter_t* painter, uint32_t scope_id, size_t index, er_ui_bounds_t bounds) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_drop_target(painter->scene, er_ui_drop_target(scope_id, index, bounds.x, bounds.y, bounds.w, bounds.h));
}

er_ui_status_t er_ui_painter_icon(er_ui_painter_t* painter, er_ui_bounds_t bounds, er_ui_icon_t icon, er_ui_color4_t color) {
  uint32_t atlas_id;
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  atlas_id = er_ui_icon_atlas_id(icon);
  if (atlas_id == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_icon_quad(painter->scene, er_ui_quad_atlas(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, 0.0f, 1.0f, 1.0f, atlas_id, color));
}

er_ui_status_t er_ui_painter_icon_quad(er_ui_painter_t* painter, er_ui_bounds_t bounds, float u0, float v0, float u1, float v1, er_ui_color4_t color) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_icon_quad(painter->scene, er_ui_quad(bounds.x, bounds.y, bounds.w, bounds.h, u0, v0, u1, v1, color));
}

er_ui_status_t er_ui_painter_text_quad(er_ui_painter_t* painter, er_ui_bounds_t bounds, float u0, float v0, float u1, float v1, er_ui_color4_t color) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_text_quad(painter->scene, er_ui_quad(bounds.x, bounds.y, bounds.w, bounds.h, u0, v0, u1, v1, color));
}

er_ui_status_t er_ui_painter_transition(er_ui_painter_t* painter, er_ui_transition_t transition) {
  if (!painter || !painter->scene) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_transition(painter->scene, transition);
}
