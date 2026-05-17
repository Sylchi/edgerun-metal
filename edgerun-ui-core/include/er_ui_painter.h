#ifndef ER_UI_PAINTER_H
#define ER_UI_PAINTER_H

#include "er_ui_primitives.h"
#include "er_ui_scene.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ER_UI_AXIS_HORIZONTAL = 0,
  ER_UI_AXIS_VERTICAL
} er_ui_axis_t;

typedef struct {
  er_ui_scene_t* scene;
} er_ui_painter_t;

er_ui_painter_t er_ui_painter(er_ui_scene_t* scene);
er_ui_status_t er_ui_painter_fill_rect(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t color);
er_ui_status_t er_ui_painter_border_rect(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t color);
er_ui_status_t er_ui_painter_shadow_rect(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t color, float shadow);
er_ui_status_t er_ui_painter_panel(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t fill, er_ui_color4_t border);
er_ui_status_t er_ui_painter_soft_card(er_ui_painter_t* painter, er_ui_bounds_t bounds, float radius, er_ui_color4_t fill);
er_ui_status_t er_ui_painter_divider(er_ui_painter_t* painter, float x, float y, float length, er_ui_axis_t axis, er_ui_color4_t color);
er_ui_status_t er_ui_painter_hit(er_ui_painter_t* painter, er_ui_hit_kind_t kind, uint32_t id, er_ui_bounds_t bounds);
er_ui_status_t er_ui_painter_drag_source(er_ui_painter_t* painter, uint32_t scope_id, uint32_t item_id, size_t index, er_ui_bounds_t bounds);
er_ui_status_t er_ui_painter_drop_target(er_ui_painter_t* painter, uint32_t scope_id, size_t index, er_ui_bounds_t bounds);
er_ui_status_t er_ui_painter_icon_quad(er_ui_painter_t* painter, er_ui_bounds_t bounds, float u0, float v0, float u1, float v1, er_ui_color4_t color);
er_ui_status_t er_ui_painter_text_quad(er_ui_painter_t* painter, er_ui_bounds_t bounds, float u0, float v0, float u1, float v1, er_ui_color4_t color);
er_ui_status_t er_ui_painter_transition(er_ui_painter_t* painter, er_ui_transition_t transition);

#ifdef __cplusplus
}
#endif

#endif
