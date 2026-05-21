#include "er_ui_scene.h"
#include "er_ui_internal.h"
#include "er_ui_primitives.h"

static const float ER_UI_COLOR_U8_SCALE = 255.0f;
static const float ER_UI_MIN_SCALE = 0.0f;
static const float ER_UI_MAX_SCALE = 1.0f;
static const float ER_UI_HALF = 0.5f;
static const size_t ER_UI_INITIAL_CAPACITY = 8u;
static const size_t ER_UI_ALIGN_F32 = 4u;
enum {
  ER_UI_SCENE_NATIVE_RECTS = 2000u,
  ER_UI_SCENE_NATIVE_TEXT_QUADS = 900u,
  ER_UI_SCENE_NATIVE_ICON_QUADS = 160u,
  ER_UI_SCENE_NATIVE_CLIPS = 160u,
  ER_UI_SCENE_NATIVE_HITS = 240u,
  ER_UI_SCENE_NATIVE_TRANSITIONS = 1200u,
  ER_UI_SCENE_NATIVE_VERTICES = 8000u
};

static bool er_ui_valid_geometry(float x, float y, float w, float h) {
  return er_ui_bounds_valid(er_ui_bounds(x, y, w, h));
}

static bool er_ui_reserve(er_ui_allocator_t allocator, void** data, size_t* capacity, size_t count, size_t item_size) {
  return er_ui_allocator_reserve(allocator, data, capacity, count, item_size, ER_UI_INITIAL_CAPACITY, ER_UI_ALIGN_F32);
}

static bool er_ui_clip_intersect(er_ui_clip_t a, er_ui_clip_t b, er_ui_clip_t* out_clip) {
  er_ui_bounds_t intersection = {0};
  if (!er_ui_bounds_intersect(er_ui_bounds(a.x, a.y, a.w, a.h), er_ui_bounds(b.x, b.y, b.w, b.h), &intersection)) return false;
  *out_clip = er_ui_clip(intersection.x, intersection.y, intersection.w, intersection.h);
  return true;
}

static bool er_ui_current_clip(const er_ui_scene_t* scene, er_ui_clip_t* out_clip) {
  if (!scene || scene->clip_count == 0u) return false;
  *out_clip = scene->clips[scene->clip_count - 1u];
  return true;
}

static bool er_ui_normalize_rect(er_ui_rect_t* rect) {
  if (!rect) return false;
  if (!er_ui_float_is_finite_value(rect->x) || !er_ui_float_is_finite_value(rect->y) || !er_ui_float_is_finite_value(rect->w) ||
      !er_ui_float_is_finite_value(rect->h) || !er_ui_float_is_finite_value(rect->radius) || !er_ui_float_is_finite_value(rect->shadow) ||
      rect->w <= 0.0f || rect->h <= 0.0f) {
    return false;
  }
  float radius_limit = er_ui_float_min(rect->w * ER_UI_HALF, rect->h * ER_UI_HALF);
  rect->radius = er_ui_float_clamp(rect->radius, 0.0f, radius_limit);
  if (rect->shadow < 0.0f) rect->shadow = 0.0f;
  return true;
}

static bool er_ui_clip_rect(const er_ui_scene_t* scene, er_ui_rect_t* rect) {
  if (!er_ui_normalize_rect(rect)) return false;

  er_ui_clip_t current = {0};
  if (!er_ui_current_clip(scene, &current)) return true;

  er_ui_clip_t clipped = {0};
  if (!er_ui_clip_intersect(er_ui_clip(rect->x, rect->y, rect->w, rect->h), current, &clipped)) {
    return false;
  }

  rect->x = clipped.x;
  rect->y = clipped.y;
  rect->w = clipped.w;
  rect->h = clipped.h;
  float radius_limit = er_ui_float_min(rect->w * ER_UI_HALF, rect->h * ER_UI_HALF);
  rect->radius = er_ui_float_min(rect->radius, radius_limit);
  return true;
}

static bool er_ui_clip_hit(const er_ui_scene_t* scene, er_ui_hit_t* hit) {
  if (!hit || !er_ui_valid_geometry(hit->x, hit->y, hit->w, hit->h)) return false;

  er_ui_clip_t current = {0};
  if (!er_ui_current_clip(scene, &current)) return true;

  er_ui_clip_t clipped = {0};
  if (!er_ui_clip_intersect(er_ui_clip(hit->x, hit->y, hit->w, hit->h), current, &clipped)) {
    return false;
  }
  hit->x = clipped.x;
  hit->y = clipped.y;
  hit->w = clipped.w;
  hit->h = clipped.h;
  return true;
}

static bool er_ui_clip_drag_source(const er_ui_scene_t* scene, er_ui_drag_source_t* source) {
  if (!source || !er_ui_valid_geometry(source->x, source->y, source->w, source->h)) return false;

  er_ui_clip_t current = {0};
  if (!er_ui_current_clip(scene, &current)) return true;

  er_ui_clip_t clipped = {0};
  if (!er_ui_clip_intersect(er_ui_clip(source->x, source->y, source->w, source->h), current, &clipped)) {
    return false;
  }
  source->x = clipped.x;
  source->y = clipped.y;
  source->w = clipped.w;
  source->h = clipped.h;
  return true;
}

static bool er_ui_clip_drop_target(const er_ui_scene_t* scene, er_ui_drop_target_t* target) {
  if (!target || !er_ui_valid_geometry(target->x, target->y, target->w, target->h)) return false;

  er_ui_clip_t current = {0};
  if (!er_ui_current_clip(scene, &current)) return true;

  er_ui_clip_t clipped = {0};
  if (!er_ui_clip_intersect(er_ui_clip(target->x, target->y, target->w, target->h), current, &clipped)) {
    return false;
  }
  target->x = clipped.x;
  target->y = clipped.y;
  target->w = clipped.w;
  target->h = clipped.h;
  return true;
}

static bool er_ui_clip_quad(const er_ui_scene_t* scene, er_ui_quad_t* quad) {
  if (!quad || !er_ui_valid_geometry(quad->x, quad->y, quad->w, quad->h)) return false;

  er_ui_clip_t current = {0};
  if (!er_ui_current_clip(scene, &current)) return true;

  float x0 = quad->x;
  float y0 = quad->y;
  float x1 = quad->x + quad->w;
  float y1 = quad->y + quad->h;
  er_ui_clip_t clipped = {0};
  if (!er_ui_clip_intersect(er_ui_clip(quad->x, quad->y, quad->w, quad->h), current, &clipped)) {
    return false;
  }

  float u0 = quad->u0;
  float v0 = quad->v0;
  float u_span = quad->u1 - quad->u0;
  float v_span = quad->v1 - quad->v0;
  float left = er_ui_float_clamp((clipped.x - x0) / (x1 - x0), ER_UI_MIN_SCALE, ER_UI_MAX_SCALE);
  float top = er_ui_float_clamp((clipped.y - y0) / (y1 - y0), ER_UI_MIN_SCALE, ER_UI_MAX_SCALE);
  float right = er_ui_float_clamp((clipped.x + clipped.w - x0) / (x1 - x0), ER_UI_MIN_SCALE, ER_UI_MAX_SCALE);
  float bottom = er_ui_float_clamp((clipped.y + clipped.h - y0) / (y1 - y0), ER_UI_MIN_SCALE, ER_UI_MAX_SCALE);

  quad->x = clipped.x;
  quad->y = clipped.y;
  quad->w = clipped.w;
  quad->h = clipped.h;
  quad->u0 = u0 + u_span * left;
  quad->v0 = v0 + v_span * top;
  quad->u1 = u0 + u_span * right;
  quad->v1 = v0 + v_span * bottom;
  return true;
}

static bool er_ui_valid_transition(er_ui_transition_t transition) {
  return er_ui_float_is_finite_value(transition.from) && er_ui_float_is_finite_value(transition.to) && transition.duration_ms > 0u &&
         transition.duration_ms <= ER_UI_SCENE_TRANSITION_MAX_DURATION_MS;
}

static bool er_ui_hit_contains(er_ui_hit_t hit, float x, float y) {
  return x >= hit.x && y >= hit.y && x <= hit.x + hit.w && y <= hit.y + hit.h;
}

static bool er_ui_drag_source_contains(er_ui_drag_source_t source, float x, float y) {
  return x >= source.x && y >= source.y && x <= source.x + source.w && y <= source.y + source.h;
}

static bool er_ui_drop_target_contains(er_ui_drop_target_t target, float x, float y) {
  return x >= target.x && y >= target.y && x <= target.x + target.w && y <= target.y + target.h;
}

er_ui_color4_t er_ui_color_rgba(float r, float g, float b, float a) {
  er_ui_color4_t color = {r, g, b, a};
  return color;
}

er_ui_color4_t er_ui_color_rgb_u8(uint8_t r, uint8_t g, uint8_t b) {
  return er_ui_color_rgba((float)r / ER_UI_COLOR_U8_SCALE, (float)g / ER_UI_COLOR_U8_SCALE,
                          (float)b / ER_UI_COLOR_U8_SCALE, 1.0f);
}

er_ui_color4_t er_ui_color_rgba_u8(uint8_t r, uint8_t g, uint8_t b, uint8_t a) {
  return er_ui_color_rgba((float)r / ER_UI_COLOR_U8_SCALE, (float)g / ER_UI_COLOR_U8_SCALE,
                          (float)b / ER_UI_COLOR_U8_SCALE, (float)a / ER_UI_COLOR_U8_SCALE);
}

er_ui_color4_t er_ui_color_with_alpha(er_ui_color4_t color, float alpha) {
  color.a = alpha;
  return color;
}

er_ui_rect_t er_ui_rect_fill(float x, float y, float w, float h, float radius, er_ui_color4_t color) {
  er_ui_rect_t rect = {x, y, w, h, radius, color, color, ER_UI_RECT_FILL, 0.0f};
  return rect;
}

er_ui_rect_t er_ui_rect_border(float x, float y, float w, float h, float radius, er_ui_color4_t color) {
  er_ui_rect_t rect = {x, y, w, h, radius, color, color, ER_UI_RECT_BORDER, 0.0f};
  return rect;
}

er_ui_rect_t er_ui_rect_shadow(float x, float y, float w, float h, float radius, er_ui_color4_t color, float shadow) {
  er_ui_rect_t rect = {x, y, w, h, radius, color, color, ER_UI_RECT_SHADOW, shadow};
  return rect;
}

er_ui_rect_t er_ui_rect_linear_gradient(float x, float y, float w, float h, float radius, er_ui_color4_t from, er_ui_color4_t to) {
  er_ui_rect_t rect = {x, y, w, h, radius, from, to, ER_UI_RECT_LINEAR_GRADIENT, 0.0f};
  return rect;
}

er_ui_clip_t er_ui_clip(float x, float y, float w, float h) {
  er_ui_clip_t clip = {x, y, w, h};
  return clip;
}

er_ui_hit_t er_ui_hit(er_ui_hit_kind_t kind, uint32_t id, float x, float y, float w, float h) {
  er_ui_hit_t hit = {kind, id, x, y, w, h};
  return hit;
}

er_ui_drag_source_t er_ui_drag_source(uint32_t scope_id, uint32_t item_id, size_t index, float x, float y, float w, float h) {
  er_ui_drag_source_t source = {scope_id, item_id, index, x, y, w, h};
  return source;
}

er_ui_drop_target_t er_ui_drop_target(uint32_t scope_id, size_t index, float x, float y, float w, float h) {
  er_ui_drop_target_t target = {scope_id, index, x, y, w, h};
  return target;
}

er_ui_quad_t er_ui_quad(float x, float y, float w, float h, float u0, float v0, float u1, float v1, er_ui_color4_t color) {
  return er_ui_quad_atlas(x, y, w, h, u0, v0, u1, v1, 0u, color);
}

er_ui_quad_t er_ui_quad_atlas(float x, float y, float w, float h, float u0, float v0, float u1, float v1, uint32_t atlas_id, er_ui_color4_t color) {
  er_ui_quad_t quad = {x, y, w, h, u0, v0, u1, v1, atlas_id, color};
  return quad;
}

er_ui_transition_t er_ui_transition(uint32_t id, er_ui_transition_property_t property, float from, float to, uint32_t duration_ms, uint32_t delay_ms, er_ui_transition_easing_t easing) {
  er_ui_transition_t transition = {id, property, from, to, duration_ms, delay_ms, easing};
  return transition;
}

er_ui_transition_t er_ui_transition_opacity(uint32_t id, float from, float to, uint32_t duration_ms) {
  return er_ui_transition(id, ER_UI_TRANSITION_OPACITY, from, to, duration_ms, 0u, ER_UI_EASING_EASE_OUT);
}

er_ui_transition_t er_ui_transition_translate_x(uint32_t id, float from, float to, uint32_t duration_ms) {
  return er_ui_transition(id, ER_UI_TRANSITION_TRANSLATE_X, from, to, duration_ms, 0u, ER_UI_EASING_EASE_OUT);
}

er_ui_transition_t er_ui_transition_translate_y(uint32_t id, float from, float to, uint32_t duration_ms) {
  return er_ui_transition(id, ER_UI_TRANSITION_TRANSLATE_Y, from, to, duration_ms, 0u, ER_UI_EASING_EASE_OUT);
}

float er_ui_transition_easing_sample(er_ui_transition_easing_t easing, float t) {
  float clamped = er_ui_float_clamp(t, ER_UI_MIN_SCALE, ER_UI_MAX_SCALE);
  switch (easing) {
    case ER_UI_EASING_LINEAR:
      return clamped;
    case ER_UI_EASING_EASE_IN:
      return clamped * clamped;
    case ER_UI_EASING_EASE_OUT: {
      float inv = 1.0f - clamped;
      return 1.0f - inv * inv;
    }
    case ER_UI_EASING_EASE_IN_OUT:
      if (clamped < ER_UI_HALF) return 2.0f * clamped * clamped;
      {
        float q = -2.0f * clamped + 2.0f;
        return 1.0f - q * q * ER_UI_HALF;
      }
    default:
      return clamped;
  }
}

er_ui_status_t er_ui_scene_init(er_ui_scene_t* scene, er_ui_color4_t clear) {
  er_ui_allocator_t allocator = {0};
  return er_ui_scene_init_with_allocator(scene, clear, allocator);
}

er_ui_status_t er_ui_scene_init_with_allocator(er_ui_scene_t* scene, er_ui_color4_t clear, er_ui_allocator_t allocator) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_mem_zero(scene, sizeof(*scene));
  scene->allocator = allocator;
  scene->clear = clear;
  return ER_UI_OK;
}

void er_ui_scene_destroy(er_ui_scene_t* scene) {
  if (!scene) return;
  er_ui_allocator_t allocator = scene->allocator;
  er_ui_allocator_free(allocator, scene->rects, scene->rect_capacity * sizeof(*scene->rects), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->hits, scene->hit_capacity * sizeof(*scene->hits), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->drag_sources, scene->drag_source_capacity * sizeof(*scene->drag_sources), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->drop_targets, scene->drop_target_capacity * sizeof(*scene->drop_targets), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->transitions, scene->transition_capacity * sizeof(*scene->transitions), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->clips, scene->clip_capacity * sizeof(*scene->clips), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->icon_quads, scene->icon_quad_capacity * sizeof(*scene->icon_quads), ER_UI_ALIGN_F32);
  er_ui_allocator_free(allocator, scene->text_quads, scene->text_quad_capacity * sizeof(*scene->text_quads), ER_UI_ALIGN_F32);
  er_ui_mem_zero(scene, sizeof(*scene));
}

void er_ui_scene_clear_commands(er_ui_scene_t* scene) {
  if (!scene) return;
  scene->rect_count = 0u;
  scene->hit_count = 0u;
  scene->drag_source_count = 0u;
  scene->drop_target_count = 0u;
  scene->transition_count = 0u;
  scene->clip_count = 0u;
  scene->icon_quad_count = 0u;
  scene->text_quad_count = 0u;
}

er_ui_status_t er_ui_scene_push_rect(er_ui_scene_t* scene, er_ui_rect_t rect) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_clip_rect(scene, &rect)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->rects, &scene->rect_capacity, scene->rect_count, sizeof(*scene->rects))) return ER_UI_ERR_OOM;
  scene->rects[scene->rect_count++] = rect;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_hit(er_ui_scene_t* scene, er_ui_hit_t hit) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_clip_hit(scene, &hit)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->hits, &scene->hit_capacity, scene->hit_count, sizeof(*scene->hits))) return ER_UI_ERR_OOM;
  scene->hits[scene->hit_count++] = hit;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_drag_source(er_ui_scene_t* scene, er_ui_drag_source_t source) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_clip_drag_source(scene, &source)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->drag_sources, &scene->drag_source_capacity, scene->drag_source_count, sizeof(*scene->drag_sources))) return ER_UI_ERR_OOM;
  scene->drag_sources[scene->drag_source_count++] = source;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_drop_target(er_ui_scene_t* scene, er_ui_drop_target_t target) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_clip_drop_target(scene, &target)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->drop_targets, &scene->drop_target_capacity, scene->drop_target_count, sizeof(*scene->drop_targets))) return ER_UI_ERR_OOM;
  scene->drop_targets[scene->drop_target_count++] = target;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_transition(er_ui_scene_t* scene, er_ui_transition_t transition) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_valid_transition(transition)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->transitions, &scene->transition_capacity, scene->transition_count, sizeof(*scene->transitions))) return ER_UI_ERR_OOM;
  scene->transitions[scene->transition_count++] = transition;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_clip(er_ui_scene_t* scene, er_ui_clip_t clip, bool* out_pushed) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (out_pushed) *out_pushed = false;

  er_ui_clip_t next = {0};
  er_ui_clip_t current = {0};
  bool has_next = false;
  if (er_ui_current_clip(scene, &current)) {
    has_next = er_ui_clip_intersect(current, clip, &next);
  } else if (er_ui_valid_geometry(clip.x, clip.y, clip.w, clip.h)) {
    next = clip;
    has_next = true;
  }
  if (!has_next) return ER_UI_OK;

  if (!er_ui_reserve(scene->allocator, (void**)&scene->clips, &scene->clip_capacity, scene->clip_count, sizeof(*scene->clips))) return ER_UI_ERR_OOM;
  scene->clips[scene->clip_count++] = next;
  if (out_pushed) *out_pushed = true;
  return ER_UI_OK;
}

void er_ui_scene_pop_clip(er_ui_scene_t* scene) {
  if (!scene || scene->clip_count == 0u) return;
  scene->clip_count--;
}

er_ui_status_t er_ui_scene_push_icon_quad(er_ui_scene_t* scene, er_ui_quad_t quad) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_clip_quad(scene, &quad)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->icon_quads, &scene->icon_quad_capacity, scene->icon_quad_count, sizeof(*scene->icon_quads))) return ER_UI_ERR_OOM;
  scene->icon_quads[scene->icon_quad_count++] = quad;
  return ER_UI_OK;
}

er_ui_status_t er_ui_scene_push_text_quad(er_ui_scene_t* scene, er_ui_quad_t quad) {
  if (!scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_clip_quad(scene, &quad)) return ER_UI_OK;
  if (!er_ui_reserve(scene->allocator, (void**)&scene->text_quads, &scene->text_quad_capacity, scene->text_quad_count, sizeof(*scene->text_quads))) return ER_UI_ERR_OOM;
  scene->text_quads[scene->text_quad_count++] = quad;
  return ER_UI_OK;
}

er_ui_scene_cursor_t er_ui_scene_cursor(const er_ui_scene_t* scene) {
  er_ui_scene_cursor_t cursor = {0};
  if (!scene) return cursor;
  cursor.rects = scene->rect_count;
  cursor.hits = scene->hit_count;
  cursor.drag_sources = scene->drag_source_count;
  cursor.drop_targets = scene->drop_target_count;
  cursor.transitions = scene->transition_count;
  cursor.icon_quads = scene->icon_quad_count;
  cursor.text_quads = scene->text_quad_count;
  return cursor;
}

er_ui_scene_stats_t er_ui_scene_stats(const er_ui_scene_t* scene) {
  er_ui_scene_stats_t stats = {0};
  if (!scene) return stats;
  stats.rects = scene->rect_count;
  stats.hits = scene->hit_count;
  stats.drag_sources = scene->drag_source_count;
  stats.drop_targets = scene->drop_target_count;
  stats.transitions = scene->transition_count;
  stats.clips = scene->clip_count;
  stats.icon_quads = scene->icon_quad_count;
  stats.text_quads = scene->text_quad_count;
  return stats;
}

void er_ui_scene_apply_opacity_since(er_ui_scene_t* scene, er_ui_scene_cursor_t cursor, float opacity) {
  if (!scene) return;
  float alpha = er_ui_float_clamp(opacity, ER_UI_MIN_SCALE, ER_UI_MAX_SCALE);
  for (size_t i = cursor.rects; i < scene->rect_count; ++i) scene->rects[i].color.a *= alpha;
  for (size_t i = cursor.icon_quads; i < scene->icon_quad_count; ++i) scene->icon_quads[i].color.a *= alpha;
  for (size_t i = cursor.text_quads; i < scene->text_quad_count; ++i) scene->text_quads[i].color.a *= alpha;
}

void er_ui_scene_translate_since(er_ui_scene_t* scene, er_ui_scene_cursor_t cursor, float dx, float dy) {
  if (!scene || !er_ui_float_is_finite_value(dx) || !er_ui_float_is_finite_value(dy)) return;
  for (size_t i = cursor.rects; i < scene->rect_count; ++i) {
    scene->rects[i].x += dx;
    scene->rects[i].y += dy;
  }
  for (size_t i = cursor.hits; i < scene->hit_count; ++i) {
    scene->hits[i].x += dx;
    scene->hits[i].y += dy;
  }
  for (size_t i = cursor.drag_sources; i < scene->drag_source_count; ++i) {
    scene->drag_sources[i].x += dx;
    scene->drag_sources[i].y += dy;
  }
  for (size_t i = cursor.drop_targets; i < scene->drop_target_count; ++i) {
    scene->drop_targets[i].x += dx;
    scene->drop_targets[i].y += dy;
  }
  for (size_t i = cursor.icon_quads; i < scene->icon_quad_count; ++i) {
    scene->icon_quads[i].x += dx;
    scene->icon_quads[i].y += dy;
  }
  for (size_t i = cursor.text_quads; i < scene->text_quad_count; ++i) {
    scene->text_quads[i].x += dx;
    scene->text_quads[i].y += dy;
  }
}

bool er_ui_scene_hit_test(const er_ui_scene_t* scene, float x, float y, er_ui_hit_t* out_hit) {
  if (!scene || !out_hit) return false;
  for (size_t i = scene->hit_count; i > 0u; --i) {
    er_ui_hit_t hit = scene->hits[i - 1u];
    if (er_ui_hit_contains(hit, x, y)) {
      *out_hit = hit;
      return true;
    }
  }
  return false;
}

bool er_ui_scene_drag_source_at(const er_ui_scene_t* scene, float x, float y, er_ui_drag_source_t* out_source) {
  if (!scene || !out_source) return false;
  for (size_t i = scene->drag_source_count; i > 0u; --i) {
    er_ui_drag_source_t source = scene->drag_sources[i - 1u];
    if (er_ui_drag_source_contains(source, x, y)) {
      *out_source = source;
      return true;
    }
  }
  return false;
}

bool er_ui_scene_drop_target_at(const er_ui_scene_t* scene, float x, float y, uint32_t scope_id, er_ui_drop_target_t* out_target) {
  if (!scene || !out_target) return false;
  for (size_t i = scene->drop_target_count; i > 0u; --i) {
    er_ui_drop_target_t target = scene->drop_targets[i - 1u];
    if (target.scope_id == scope_id && er_ui_drop_target_contains(target, x, y)) {
      *out_target = target;
      return true;
    }
  }
  return false;
}

er_ui_scene_budget_t er_ui_scene_frame_budget(void) {
  er_ui_scene_budget_t budget = {ER_UI_SCENE_NATIVE_RECTS, ER_UI_SCENE_NATIVE_TEXT_QUADS, ER_UI_SCENE_NATIVE_ICON_QUADS, ER_UI_SCENE_NATIVE_CLIPS,
                                 ER_UI_SCENE_NATIVE_HITS, ER_UI_SCENE_NATIVE_TRANSITIONS, ER_UI_SCENE_NATIVE_VERTICES};
  return budget;
}

bool er_ui_scene_stats_fits_budget(er_ui_scene_stats_t stats, er_ui_scene_budget_t budget) {
  return !er_ui_scene_first_budget_violation(stats, budget, NULL);
}

typedef struct {
  const char* name;
  size_t actual;
  size_t limit;
} er_ui_scene_budget_entry_t;

bool er_ui_scene_first_budget_violation(er_ui_scene_stats_t stats, er_ui_scene_budget_t budget, er_ui_scene_budget_violation_t* out_violation) {
  const er_ui_scene_budget_entry_t entries[] = {
    {"rects", stats.rects, budget.rects},
    {"hits", stats.hits, budget.hits},
    {"drag_sources", stats.drag_sources, budget.drag_sources},
    {"drop_targets", stats.drop_targets, budget.drop_targets},
    {"transitions", stats.transitions, budget.transitions},
    {"icon_quads", stats.icon_quads, budget.icon_quads},
    {"text_quads", stats.text_quads, budget.text_quads},
  };
  const er_ui_scene_budget_entry_t* entry = entries;
  const er_ui_scene_budget_entry_t* end = entries + (sizeof(entries) / sizeof(entries[0]));

  while (entry < end) {
    if (entry->actual > entry->limit) {
      if (out_violation) {
        out_violation->name = entry->name;
        out_violation->actual = entry->actual;
        out_violation->limit = entry->limit;
      }
      return true;
    }
    entry++;
  }
  return false;
}

bool er_ui_color_scheme_from_code(uint32_t code, er_ui_color_scheme_t* out_scheme) {
  if (!out_scheme) return false;
  switch (code) {
    case ER_UI_COLOR_SCHEME_LIGHT:
      *out_scheme = ER_UI_COLOR_SCHEME_LIGHT;
      return true;
    case ER_UI_COLOR_SCHEME_TERMINAL:
      *out_scheme = ER_UI_COLOR_SCHEME_TERMINAL;
      return true;
    case ER_UI_COLOR_SCHEME_DARK:
      *out_scheme = ER_UI_COLOR_SCHEME_DARK;
      return true;
    default:
      return false;
  }
}

bool er_ui_color_scheme_code(er_ui_color_scheme_t scheme, uint32_t* out_code) {
  if (!out_code) return false;
  switch (scheme) {
    case ER_UI_COLOR_SCHEME_LIGHT:
      *out_code = 1u;
      return true;
    case ER_UI_COLOR_SCHEME_TERMINAL:
      *out_code = 2u;
      return true;
    case ER_UI_COLOR_SCHEME_DARK:
      *out_code = 0u;
      return true;
    default:
      return false;
  }
}
