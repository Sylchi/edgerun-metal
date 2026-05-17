#ifndef ER_UI_COMPONENTS_H
#define ER_UI_COMPONENTS_H

#include "er_ui_painter.h"
#include "er_ui_text.h"
#include "er_ui_theme.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
  ER_UI_COMPONENT_BUTTON_PRIMARY = 0,
  ER_UI_COMPONENT_BUTTON_SECONDARY,
  ER_UI_COMPONENT_BUTTON_OUTLINE,
  ER_UI_COMPONENT_BUTTON_GHOST,
  ER_UI_COMPONENT_BUTTON_DESTRUCTIVE
} er_ui_component_button_variant_t;

typedef enum {
  ER_UI_COMPONENT_BADGE_DEFAULT = 0,
  ER_UI_COMPONENT_BADGE_SECONDARY,
  ER_UI_COMPONENT_BADGE_OUTLINE,
  ER_UI_COMPONENT_BADGE_SUCCESS,
  ER_UI_COMPONENT_BADGE_WARNING,
  ER_UI_COMPONENT_BADGE_DANGER
} er_ui_component_badge_variant_t;

typedef struct {
  uint32_t first_id;
  size_t component_count;
  size_t button_count;
  size_t text_label_count;
} er_ui_shadcn_showcase_stats_t;

er_ui_status_t er_ui_component_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, float x, float y, er_ui_color4_t color);
er_ui_status_t er_ui_component_card(er_ui_painter_t* painter, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_button(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* label,
  er_ui_component_button_variant_t variant,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_badge(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  const char* label,
  er_ui_component_badge_variant_t variant,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_input(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* value,
  const char* placeholder,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_checkbox(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* label,
  bool checked,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_switch(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* label,
  bool checked,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_slider(
  er_ui_painter_t* painter,
  er_ui_bounds_t bounds,
  uint32_t id,
  float value,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_tabs(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t first_id,
  const char* first_label,
  const char* second_label,
  size_t selected_index,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_shadcn_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  uint32_t first_id,
  er_ui_shadcn_showcase_stats_t* out_stats);

#ifdef __cplusplus
}
#endif

#endif
