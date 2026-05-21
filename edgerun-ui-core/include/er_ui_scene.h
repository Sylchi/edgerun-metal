#ifndef ER_UI_SCENE_H
#define ER_UI_SCENE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_SCENE_TRANSITION_MAX_DURATION_MS 60000u

typedef enum {
  ER_UI_OK = 0,
  ER_UI_ERR_INVALID_ARGUMENT,
  ER_UI_ERR_OOM
} er_ui_status_t;

typedef void* (*er_ui_alloc_fn)(void* user, size_t size, size_t align);
typedef void (*er_ui_free_fn)(void* user, void* ptr, size_t size, size_t align);

typedef struct {
  void* user;
  er_ui_alloc_fn alloc;
  er_ui_free_fn free;
} er_ui_allocator_t;

typedef enum {
  ER_UI_RECT_FILL = 0,
  ER_UI_RECT_SHADOW,
  ER_UI_RECT_BORDER,
  ER_UI_RECT_LINEAR_GRADIENT
} er_ui_rect_mode_t;

typedef enum {
  ER_UI_HIT_CONTACT = 0,
  ER_UI_HIT_COMPOSER,
  ER_UI_HIT_SEND,
  ER_UI_HIT_BUTTON,
  ER_UI_HIT_TAB,
  ER_UI_HIT_TOGGLE,
  ER_UI_HIT_LIST_ROW,
  ER_UI_HIT_INPUT,
  ER_UI_HIT_TEXT_AREA,
  ER_UI_HIT_SLIDER,
  ER_UI_HIT_CHECKBOX,
  ER_UI_HIT_RADIO,
  ER_UI_HIT_SELECT,
  ER_UI_HIT_BREADCRUMB,
  ER_UI_HIT_TREE_ITEM,
  ER_UI_HIT_MENU_ITEM,
  ER_UI_HIT_TRANSACTION_ROW,
  ER_UI_HIT_SCROLL_AREA,
  ER_UI_HIT_SCROLLBAR,
  ER_UI_HIT_WORKSPACE_TAB,
  ER_UI_HIT_WORKSPACE_CLOSE,
  ER_UI_HIT_WORKSPACE_SPLIT,
  ER_UI_HIT_SHELL_LAUNCHER,
  ER_UI_HIT_APP_LAUNCHER_ITEM
} er_ui_hit_kind_t;

typedef enum {
  ER_UI_TRANSITION_OPACITY = 0,
  ER_UI_TRANSITION_TRANSLATE_X,
  ER_UI_TRANSITION_TRANSLATE_Y
} er_ui_transition_property_t;

typedef enum {
  ER_UI_EASING_LINEAR = 0,
  ER_UI_EASING_EASE_IN,
  ER_UI_EASING_EASE_OUT,
  ER_UI_EASING_EASE_IN_OUT
} er_ui_transition_easing_t;

typedef enum {
  ER_UI_COLOR_SCHEME_DARK = 0,
  ER_UI_COLOR_SCHEME_LIGHT = 1,
  ER_UI_COLOR_SCHEME_TERMINAL = 2
} er_ui_color_scheme_t;

typedef struct {
  float r;
  float g;
  float b;
  float a;
} er_ui_color4_t;

typedef struct {
  float x;
  float y;
  float w;
  float h;
} er_ui_clip_t;

typedef struct {
  float x;
  float y;
  float w;
  float h;
  float radius;
  er_ui_color4_t color;
  er_ui_color4_t color2;
  er_ui_rect_mode_t mode;
  float shadow;
} er_ui_rect_t;

typedef struct {
  er_ui_hit_kind_t kind;
  uint32_t id;
  float x;
  float y;
  float w;
  float h;
} er_ui_hit_t;

typedef struct {
  uint32_t scope_id;
  uint32_t item_id;
  size_t index;
  float x;
  float y;
  float w;
  float h;
} er_ui_drag_source_t;

typedef struct {
  uint32_t scope_id;
  size_t index;
  float x;
  float y;
  float w;
  float h;
} er_ui_drop_target_t;

typedef struct {
  float x;
  float y;
  float w;
  float h;
  float u0;
  float v0;
  float u1;
  float v1;
  uint32_t atlas_id;
  er_ui_color4_t color;
} er_ui_quad_t;

typedef struct {
  uint32_t id;
  er_ui_transition_property_t property;
  float from;
  float to;
  uint32_t duration_ms;
  uint32_t delay_ms;
  er_ui_transition_easing_t easing;
} er_ui_transition_t;

typedef struct {
  size_t rects;
  size_t hits;
  size_t drag_sources;
  size_t drop_targets;
  size_t transitions;
  size_t clips;
  size_t icon_quads;
  size_t text_quads;
} er_ui_scene_stats_t;

typedef struct {
  size_t rects;
  size_t hits;
  size_t drag_sources;
  size_t drop_targets;
  size_t transitions;
  size_t icon_quads;
  size_t text_quads;
} er_ui_scene_cursor_t;

typedef struct {
  size_t rects;
  size_t hits;
  size_t drag_sources;
  size_t drop_targets;
  size_t transitions;
  size_t icon_quads;
  size_t text_quads;
} er_ui_scene_budget_t;

typedef struct {
  const char* name;
  size_t actual;
  size_t limit;
} er_ui_scene_budget_violation_t;

typedef struct {
  er_ui_allocator_t allocator;
  er_ui_color4_t clear;
  er_ui_rect_t* rects;
  size_t rect_count;
  size_t rect_capacity;
  er_ui_hit_t* hits;
  size_t hit_count;
  size_t hit_capacity;
  er_ui_drag_source_t* drag_sources;
  size_t drag_source_count;
  size_t drag_source_capacity;
  er_ui_drop_target_t* drop_targets;
  size_t drop_target_count;
  size_t drop_target_capacity;
  er_ui_transition_t* transitions;
  size_t transition_count;
  size_t transition_capacity;
  er_ui_clip_t* clips;
  size_t clip_count;
  size_t clip_capacity;
  er_ui_quad_t* icon_quads;
  size_t icon_quad_count;
  size_t icon_quad_capacity;
  er_ui_quad_t* text_quads;
  size_t text_quad_count;
  size_t text_quad_capacity;
} er_ui_scene_t;

er_ui_color4_t er_ui_color_rgba(float r, float g, float b, float a);
er_ui_color4_t er_ui_color_rgb_u8(uint8_t r, uint8_t g, uint8_t b);
er_ui_color4_t er_ui_color_rgba_u8(uint8_t r, uint8_t g, uint8_t b, uint8_t a);
er_ui_color4_t er_ui_color_with_alpha(er_ui_color4_t color, float alpha);

er_ui_rect_t er_ui_rect_fill(float x, float y, float w, float h, float radius, er_ui_color4_t color);
er_ui_rect_t er_ui_rect_border(float x, float y, float w, float h, float radius, er_ui_color4_t color);
er_ui_rect_t er_ui_rect_shadow(float x, float y, float w, float h, float radius, er_ui_color4_t color, float shadow);
er_ui_rect_t er_ui_rect_linear_gradient(
  float x,
  float y,
  float w,
  float h,
  float radius,
  er_ui_color4_t from,
  er_ui_color4_t to);

er_ui_clip_t er_ui_clip(float x, float y, float w, float h);
er_ui_hit_t er_ui_hit(er_ui_hit_kind_t kind, uint32_t id, float x, float y, float w, float h);
er_ui_drag_source_t er_ui_drag_source(
  uint32_t scope_id,
  uint32_t item_id,
  size_t index,
  float x,
  float y,
  float w,
  float h);
er_ui_drop_target_t er_ui_drop_target(uint32_t scope_id, size_t index, float x, float y, float w, float h);
er_ui_quad_t er_ui_quad(
  float x,
  float y,
  float w,
  float h,
  float u0,
  float v0,
  float u1,
  float v1,
  er_ui_color4_t color);
er_ui_quad_t er_ui_quad_atlas(
  float x,
  float y,
  float w,
  float h,
  float u0,
  float v0,
  float u1,
  float v1,
  uint32_t atlas_id,
  er_ui_color4_t color);
er_ui_transition_t er_ui_transition(
  uint32_t id,
  er_ui_transition_property_t property,
  float from,
  float to,
  uint32_t duration_ms,
  uint32_t delay_ms,
  er_ui_transition_easing_t easing);
er_ui_transition_t er_ui_transition_opacity(uint32_t id, float from, float to, uint32_t duration_ms);
er_ui_transition_t er_ui_transition_translate_x(uint32_t id, float from, float to, uint32_t duration_ms);
er_ui_transition_t er_ui_transition_translate_y(uint32_t id, float from, float to, uint32_t duration_ms);
float er_ui_transition_easing_sample(er_ui_transition_easing_t easing, float t);

er_ui_status_t er_ui_scene_init(er_ui_scene_t* scene, er_ui_color4_t clear);
er_ui_status_t er_ui_scene_init_with_allocator(er_ui_scene_t* scene, er_ui_color4_t clear, er_ui_allocator_t allocator);
void er_ui_scene_destroy(er_ui_scene_t* scene);
void er_ui_scene_clear_commands(er_ui_scene_t* scene);

er_ui_status_t er_ui_scene_push_rect(er_ui_scene_t* scene, er_ui_rect_t rect);
er_ui_status_t er_ui_scene_push_hit(er_ui_scene_t* scene, er_ui_hit_t hit);
er_ui_status_t er_ui_scene_push_drag_source(er_ui_scene_t* scene, er_ui_drag_source_t source);
er_ui_status_t er_ui_scene_push_drop_target(er_ui_scene_t* scene, er_ui_drop_target_t target);
er_ui_status_t er_ui_scene_push_transition(er_ui_scene_t* scene, er_ui_transition_t transition);
er_ui_status_t er_ui_scene_push_clip(er_ui_scene_t* scene, er_ui_clip_t clip, bool* out_pushed);
void er_ui_scene_pop_clip(er_ui_scene_t* scene);
er_ui_status_t er_ui_scene_push_icon_quad(er_ui_scene_t* scene, er_ui_quad_t quad);
er_ui_status_t er_ui_scene_push_text_quad(er_ui_scene_t* scene, er_ui_quad_t quad);

er_ui_scene_cursor_t er_ui_scene_cursor(const er_ui_scene_t* scene);
er_ui_scene_stats_t er_ui_scene_stats(const er_ui_scene_t* scene);
void er_ui_scene_apply_opacity_since(er_ui_scene_t* scene, er_ui_scene_cursor_t cursor, float opacity);
void er_ui_scene_translate_since(er_ui_scene_t* scene, er_ui_scene_cursor_t cursor, float dx, float dy);

bool er_ui_scene_hit_test(const er_ui_scene_t* scene, float x, float y, er_ui_hit_t* out_hit);
bool er_ui_scene_drag_source_at(const er_ui_scene_t* scene, float x, float y, er_ui_drag_source_t* out_source);
bool er_ui_scene_drop_target_at(
  const er_ui_scene_t* scene,
  float x,
  float y,
  uint32_t scope_id,
  er_ui_drop_target_t* out_target);

er_ui_scene_budget_t er_ui_scene_budget_native_interactive_frame(void);
er_ui_scene_budget_t er_ui_scene_budget_browser_interactive_frame(void);
er_ui_scene_budget_t er_ui_scene_budget_public_showcase_frame(void);
bool er_ui_scene_stats_fits_budget(er_ui_scene_stats_t stats, er_ui_scene_budget_t budget);
bool er_ui_scene_first_budget_violation(
  er_ui_scene_stats_t stats,
  er_ui_scene_budget_t budget,
  er_ui_scene_budget_violation_t* out_violation);

bool er_ui_color_scheme_from_code(uint32_t code, er_ui_color_scheme_t* out_scheme);
bool er_ui_color_scheme_code(er_ui_color_scheme_t scheme, uint32_t* out_code);

#ifdef __cplusplus
}
#endif

#endif
