#ifndef ER_UI_COMPONENTS_INTERNAL_H
#define ER_UI_COMPONENTS_INTERNAL_H

#include "er_ui_components.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"
#include "er_math.h"

#define ER_UI_COMPONENT_TEXT_CAPACITY 128u
#define ER_UI_COMPONENT_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_COMPONENT_ICON_ROW_TILE_X 12.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_Y 15.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_SIZE 28.0f
#define ER_UI_COMPONENT_ICON_ROW_TEXT_X 48.0f
#define ER_UI_COMPONENT_ICON_ROW_TITLE_Y 24.0f
#define ER_UI_COMPONENT_ICON_ROW_DETAIL_Y 46.0f
#define ER_UI_COMPONENT_ROW_SEPARATOR_H 1.0f
#define ER_UI_COMPONENT_TEXT_ADVANCE 7.0f
#define ER_UI_COMPONENT_TEXT_PAD_X 10.0f
#define ER_UI_COMPONENT_ROW_TEXT_PAD_RIGHT 12.0f
#define ER_UI_COMPONENT_CONTROL_ICON_RESERVED_W 34.0f
#define ER_UI_COMPONENT_BADGED_CARD_ICON_X 16.0f
#define ER_UI_COMPONENT_BADGED_CARD_ICON_Y 18.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_X 16.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_BOTTOM 34.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_W 120.0f
#define ER_UI_COMPONENT_BADGED_CARD_BADGE_H 24.0f
size_t er_ui_component_option_index(uint32_t id, uint32_t base, size_t len, bool* out_has_index);
#define ER_UI_COMPONENT_INVOICE_SECONDARY_ACTION_OFFSET 100u
#define ER_UI_COMPONENT_INVOICE_PRIMARY_ACTION_OFFSET 101u

typedef struct {
  er_ui_hit_kind_t hit_kind;
  uint32_t id;
  float radius;
  er_ui_color4_t fill;
  er_ui_icon_t icon;
  er_ui_color4_t icon_color;
  er_ui_bounds_t icon_bounds;
  float text_x;
  float title_y;
  float detail_y;
  bool border;
  bool separator;
} er_ui_component_icon_text_row_t;

bool er_ui_component_streq(const char* a, const char* b);
bool er_ui_component_list_contains(const char* const* values, size_t count, const char* value);
er_ui_status_t er_ui_component_push_ascii_text(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_push_ascii_text_clipped(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  float max_w,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_push_icon(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_icon_t icon,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_icon_tile(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_icon_t icon,
  er_ui_color4_t color);
er_ui_status_t er_ui_component_push_text_pair(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* primary,
  float primary_x,
  float primary_y,
  er_ui_color4_t primary_color,
  const char* secondary,
  float secondary_x,
  float secondary_y,
  er_ui_color4_t secondary_color,
  bool emit_empty_secondary);
er_ui_status_t er_ui_component_fill_border(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  float radius,
  er_ui_color4_t fill,
  er_ui_color4_t border);
er_ui_status_t er_ui_component_row_frame_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  bool has_hit,
  float radius,
  er_ui_color4_t fill);
er_ui_status_t er_ui_component_row_body_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  bool has_hit,
  const char* title,
  const char* detail,
  float radius,
  er_ui_color4_t fill,
  float title_y,
  float detail_y);
er_ui_component_icon_text_row_t er_ui_component_icon_text_row(
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  float radius,
  er_ui_color4_t fill,
  er_ui_icon_t icon,
  er_ui_color4_t icon_color,
  er_ui_bounds_t bounds,
  float tile_y,
  float text_x,
  float title_y,
  float detail_y,
  bool border,
  bool separator);
er_ui_status_t er_ui_component_icon_text_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_component_icon_text_row_t* row,
  const char* title,
  const char* detail);
er_ui_status_t er_ui_component_bottom_separator_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_component_badged_icon_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  uint32_t id,
  const char* title,
  const char* detail,
  const char* badge,
  er_ui_icon_t icon,
  er_ui_color4_t icon_color,
  float icon_size,
  float text_x,
  float title_y,
  float detail_y);
er_ui_color4_t er_ui_component_button_fill(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant);
er_ui_color4_t er_ui_component_button_border(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant);
er_ui_color4_t er_ui_component_button_text(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant);
er_ui_color4_t er_ui_component_badge_fill(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant);
er_ui_color4_t er_ui_component_badge_text(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant);
float er_ui_component_clamp01(float value);

#endif
