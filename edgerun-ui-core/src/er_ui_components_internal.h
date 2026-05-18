#ifndef ER_UI_COMPONENTS_INTERNAL_H
#define ER_UI_COMPONENTS_INTERNAL_H

#include "er_ui_components.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"
#include "er_math.h"

#define ER_UI_COMPONENT_TEXT_CAPACITY 128u
#define ER_UI_COMPONENT_SUFFIX_TSX_LEN 4u
#define ER_UI_COMPONENT_SUFFIX_TS_LEN 3u
#define ER_UI_COMPONENT_SUFFIX_JSX_LEN 4u
#define ER_UI_COMPONENT_SUFFIX_JS_LEN 3u
#define ER_UI_COMPONENT_EMPTY_COUNT 0u
#define ER_UI_COMPONENT_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_COMPONENT_SHOWCASE_MIN_LIST_W 160.0f
#define ER_UI_COMPONENT_SHOWCASE_PREFERRED_LIST_W 260.0f
#define ER_UI_COMPONENT_SHOWCASE_MIN_PREVIEW_W 220.0f
#define ER_UI_COMPONENT_SHOWCASE_INSET 16.0f
#define ER_UI_COMPONENT_SHOWCASE_STACKED_LIST_H 168.0f
#define ER_UI_COMPONENT_SHOWCASE_GRID_MIN_CARD_W 292.0f
#define ER_UI_COMPONENT_SHOWCASE_GRID_MAX_COLUMNS 4u
#define ER_UI_COMPONENT_SHOWCASE_GRID_GAP 18.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_H 250.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_PAD 18.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_HEADER_H 54.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_PREVIEW_MIN_W 190.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_PREVIEW_MIN_H 110.0f
#define ER_UI_COMPONENT_SHOWCASE_CARD_DETAIL_MIN_H 64.0f
#define ER_UI_COMPONENT_SHOWCASE_SCROLL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 4200u)
#define ER_UI_COMPONENT_SHOWCASE_SCROLL_THUMB_MIN_H 48.0f
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
#define ER_UI_COMPONENT_SPEC( \
  title, \
  slug, \
  category, \
  source, \
  fixture, \
  slots, \
  states, \
  state_count) \
  { \
    title, \
    slug, \
    "/docs/components/" slug, \
    category, \
    source, \
    fixture, \
    slots, \
    ER_UI_COMPONENT_ARRAY_COUNT(slots), \
    states, \
    state_count, \
    ER_UI_COMPONENT_STATUS_EXACT_PORT \
  }
#define ER_UI_COMPONENT_ENTRY(title, slug, category, source, fixture, slots, states) \
  ER_UI_COMPONENT_SPEC( \
    title, \
    slug, \
    category, \
    source, \
    fixture, \
    slots, \
    states, \
    ER_UI_COMPONENT_ARRAY_COUNT(states))
#define ER_UI_COMPONENT_EMPTY(title, slug, category, source, fixture, slots, states) \
  ER_UI_COMPONENT_SPEC( \
    title, \
    slug, \
    category, \
    source, \
    fixture, \
    slots, \
    states, \
    ER_UI_COMPONENT_EMPTY_COUNT)
#define ER_UI_COMPONENT_FIELD_SET(fields) \
  do { \
    *out_fields = fields; \
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(fields); \
    return true; \
  } while (0)
#define ER_UI_COMPONENT_A11Y_SET(role, labels) \
  do { \
    *out_role = role; \
    *out_label_fields = labels; \
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(labels); \
    return true; \
  } while (0)
#define ER_UI_COMPONENT_IDENTIFIER_CAPACITY ER_UI_COMPONENT_TEXT_CAPACITY
#define ER_UI_COMPONENT_PREVIEW_BREADCRUMB_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 1u)
#define ER_UI_COMPONENT_PREVIEW_BUTTON_DEFAULT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 2u)
#define ER_UI_COMPONENT_PREVIEW_BUTTON_SECONDARY_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 3u)
#define ER_UI_COMPONENT_PREVIEW_BUTTON_GHOST_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 4u)
#define ER_UI_COMPONENT_PREVIEW_CHECKBOX_TERMS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 6u)
#define ER_UI_COMPONENT_PREVIEW_CHECKBOX_EMAILS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 7u)
#define ER_UI_COMPONENT_PREVIEW_COMMAND_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 8u)
#define ER_UI_COMPONENT_PREVIEW_FIELD_EMAIL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 11u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 12u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 13u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_H 40.0f
#define ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CANCEL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 90u)
#define ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CONFIRM_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 91u)
#define ER_UI_COMPONENT_PREVIEW_BREADCRUMB_CURRENT_INDEX 2u
#define ER_UI_COMPONENT_PREVIEW_DATE_PICKER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 66u)
#define ER_UI_COMPONENT_PREVIEW_CALENDAR_DAY_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 48u)
#define ER_UI_COMPONENT_PREVIEW_CALENDAR_SELECTED_INDEX 2u
#define ER_UI_COMPONENT_PREVIEW_DRAWER_SLIDER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 34u)
#define ER_UI_COMPONENT_PREVIEW_DRAWER_SUBMIT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 35u)
#define ER_UI_COMPONENT_PREVIEW_CHART_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 120u)
#define ER_UI_COMPONENT_PREVIEW_CHART_ACTIVE_INDEX 3u
#define ER_UI_COMPONENT_PREVIEW_BUTTON_GROUP_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 27u)
#define ER_UI_COMPONENT_PREVIEW_CONTEXT_PROFILE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 9u)
#define ER_UI_COMPONENT_PREVIEW_CONTEXT_BILLING_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 10u)
#define ER_UI_COMPONENT_PREVIEW_CONTEXT_LOGOUT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 11u)
#define ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_PRIMITIVES_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 31u)
#define ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_COLORS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 32u)
#define ER_UI_COMPONENT_PREVIEW_COMBOBOX_SELECT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 59u)
#define ER_UI_COMPONENT_PREVIEW_COMBOBOX_SEARCH_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 60u)
#define ER_UI_COMPONENT_PREVIEW_COMBOBOX_RESULT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 61u)
#define ER_UI_COMPONENT_PREVIEW_TABLE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 43u)
#define ER_UI_COMPONENT_PREVIEW_INPUT_OTP_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 80u)
#define ER_UI_COMPONENT_PREVIEW_ITEM_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 13u)
#define ER_UI_COMPONENT_PREVIEW_LABEL_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 92u)
#define ER_UI_COMPONENT_PREVIEW_MENUBAR_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 70u)
#define ER_UI_COMPONENT_PREVIEW_PAGINATION_PREVIOUS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 37u)
#define ER_UI_COMPONENT_PREVIEW_PAGINATION_CURRENT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 38u)
#define ER_UI_COMPONENT_PREVIEW_PAGINATION_NEXT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 39u)
#define ER_UI_COMPONENT_PREVIEW_NAVIGATION_TABS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 74u)
#define ER_UI_COMPONENT_PREVIEW_NAVIGATION_INSTALL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 77u)
#define ER_UI_COMPONENT_PREVIEW_POPOVER_BUTTON_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 41u)
#define ER_UI_COMPONENT_PREVIEW_POPOVER_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 42u)
#define ER_UI_COMPONENT_PREVIEW_RADIO_DEFAULT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 14u)
#define ER_UI_COMPONENT_PREVIEW_RADIO_COMFORTABLE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 15u)
#define ER_UI_COMPONENT_PREVIEW_RADIO_COMPACT_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 16u)
#define ER_UI_COMPONENT_PREVIEW_SCROLL_INITIAL_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 17u)
#define ER_UI_COMPONENT_PREVIEW_SCROLL_UPDATES_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 18u)
#define ER_UI_COMPONENT_PREVIEW_SCROLL_PRESET_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 19u)
#define ER_UI_COMPONENT_PREVIEW_SHEET_FIELD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 42u)
#define ER_UI_COMPONENT_PREVIEW_SHEET_SAVE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 43u)
#define ER_UI_COMPONENT_PREVIEW_SIDEBAR_DASHBOARD_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 78u)
#define ER_UI_COMPONENT_PREVIEW_SIDEBAR_TRANSACTIONS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 79u)
#define ER_UI_COMPONENT_PREVIEW_SLIDER_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 21u)
#define ER_UI_COMPONENT_PREVIEW_SWITCH_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 22u)
#define ER_UI_COMPONENT_PREVIEW_TABS_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 23u)
#define ER_UI_COMPONENT_PREVIEW_TEXTAREA_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 45u)
#define ER_UI_COMPONENT_PREVIEW_TOGGLE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 24u)
#define ER_UI_COMPONENT_PREVIEW_TOGGLE_GROUP_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 44u)
#define ER_UI_COMPONENT_PREVIEW_TOOLTIP_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 26u)

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
bool er_ui_component_range_starts_with(const char* start, const char* end, const char* prefix, size_t prefix_len);
bool er_ui_component_ends_with_len(const char* start, const char* end, const char* suffix, size_t suffix_len);
const er_ui_component_spec_t* er_ui_component_catalog_data_at(size_t index);
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
