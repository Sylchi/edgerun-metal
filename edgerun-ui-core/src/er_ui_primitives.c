#include "er_ui_primitives.h"

static const float ER_UI_FLOAT_MAX_VALUE = 3.4028234663852886e38f;

float er_ui_float_clamp(float value, float min_value, float max_value) {
  if (value < min_value) return min_value;
  if (value > max_value) return max_value;
  return value;
}

float er_ui_float_min(float a, float b) {
  return a < b ? a : b;
}

float er_ui_float_max(float a, float b) {
  return a > b ? a : b;
}

bool er_ui_float_is_finite_value(float value) {
  return value == value && value <= ER_UI_FLOAT_MAX_VALUE && value >= -ER_UI_FLOAT_MAX_VALUE;
}

er_ui_bounds_t er_ui_bounds(float x, float y, float w, float h) {
  er_ui_bounds_t bounds = {x, y, w, h};
  return bounds;
}

er_ui_bounds_t er_ui_bounds_inset(er_ui_bounds_t bounds, float dx, float dy) {
  bounds.x += dx;
  bounds.y += dy;
  bounds.w = er_ui_float_max(bounds.w - dx * 2.0f, 0.0f);
  bounds.h = er_ui_float_max(bounds.h - dy * 2.0f, 0.0f);
  return bounds;
}

er_ui_bounds_t er_ui_bounds_inset_ltrb(er_ui_bounds_t bounds, float left, float top, float right, float bottom) {
  bounds.x += left;
  bounds.y += top;
  bounds.w = er_ui_float_max(bounds.w - left - right, 0.0f);
  bounds.h = er_ui_float_max(bounds.h - top - bottom, 0.0f);
  return bounds;
}

er_ui_bounds_t er_ui_bounds_with_height_centered(er_ui_bounds_t bounds, float h) {
  h = er_ui_float_clamp(h, 0.0f, bounds.h);
  bounds.y += (bounds.h - h) * 0.5f;
  bounds.h = h;
  return bounds;
}

er_ui_bounds_t er_ui_bounds_with_width_centered(er_ui_bounds_t bounds, float w) {
  w = er_ui_float_clamp(w, 0.0f, bounds.w);
  bounds.x += (bounds.w - w) * 0.5f;
  bounds.w = w;
  return bounds;
}

er_ui_bounds_t er_ui_bounds_right(er_ui_bounds_t bounds, float w) {
  bounds.x = bounds.x + bounds.w - w;
  bounds.w = w;
  return bounds;
}

er_ui_bounds_t er_ui_bounds_bottom(er_ui_bounds_t bounds, float h) {
  bounds.y = bounds.y + bounds.h - h;
  bounds.h = h;
  return bounds;
}

bool er_ui_bounds_contains(er_ui_bounds_t bounds, float x, float y) {
  return x >= bounds.x && y >= bounds.y && x <= bounds.x + bounds.w && y <= bounds.y + bounds.h;
}

bool er_ui_bounds_intersect(er_ui_bounds_t a, er_ui_bounds_t b, er_ui_bounds_t* out_bounds) {
  if (!out_bounds) return false;
  float x0 = er_ui_float_max(a.x, b.x);
  float y0 = er_ui_float_max(a.y, b.y);
  float x1 = er_ui_float_min(a.x + a.w, b.x + b.w);
  float y1 = er_ui_float_min(a.y + a.h, b.y + b.h);
  float w = x1 - x0;
  float h = y1 - y0;
  if (w <= 0.0f || h <= 0.0f) return false;
  *out_bounds = er_ui_bounds(x0, y0, w, h);
  return true;
}

bool er_ui_bounds_valid(er_ui_bounds_t bounds) {
  return er_ui_float_is_finite_value(bounds.x) && er_ui_float_is_finite_value(bounds.y) && er_ui_float_is_finite_value(bounds.w) &&
         er_ui_float_is_finite_value(bounds.h) && bounds.w > 0.0f && bounds.h > 0.0f;
}
