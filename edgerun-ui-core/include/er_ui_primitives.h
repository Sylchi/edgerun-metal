#ifndef ER_UI_PRIMITIVES_H
#define ER_UI_PRIMITIVES_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
  float x;
  float y;
  float w;
  float h;
} er_ui_bounds_t;

er_ui_bounds_t er_ui_bounds(float x, float y, float w, float h);
er_ui_bounds_t er_ui_bounds_inset(er_ui_bounds_t bounds, float dx, float dy);
er_ui_bounds_t er_ui_bounds_inset_ltrb(er_ui_bounds_t bounds, float left, float top, float right, float bottom);
er_ui_bounds_t er_ui_bounds_with_height_centered(er_ui_bounds_t bounds, float h);
er_ui_bounds_t er_ui_bounds_with_width_centered(er_ui_bounds_t bounds, float w);
er_ui_bounds_t er_ui_bounds_right(er_ui_bounds_t bounds, float w);
er_ui_bounds_t er_ui_bounds_bottom(er_ui_bounds_t bounds, float h);
bool er_ui_bounds_contains(er_ui_bounds_t bounds, float x, float y);
bool er_ui_bounds_intersect(er_ui_bounds_t a, er_ui_bounds_t b, er_ui_bounds_t* out_bounds);
bool er_ui_bounds_valid(er_ui_bounds_t bounds);
float er_ui_float_clamp(float value, float min_value, float max_value);
float er_ui_float_min(float a, float b);
float er_ui_float_max(float a, float b);
bool er_ui_float_is_finite_value(float value);

#ifdef __cplusplus
}
#endif

#endif
