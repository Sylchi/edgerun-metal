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
#define ER_UI_COMPONENT_ICON_ROW_TILE_X 12.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_Y 15.0f
#define ER_UI_COMPONENT_ICON_ROW_TILE_SIZE 28.0f
#define ER_UI_COMPONENT_ICON_ROW_TEXT_X 48.0f
#define ER_UI_COMPONENT_ICON_ROW_TITLE_Y 24.0f
#define ER_UI_COMPONENT_ICON_ROW_DETAIL_Y 46.0f
#define ER_UI_COMPONENT_ROW_SEPARATOR_H 1.0f
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

static bool er_ui_component_streq(const char* a, const char* b) {
  if (!a || !b) return false;
  while (*a && *b) { if (*a != *b) return false; a++; b++; }
  return *a == *b;
}

static bool er_ui_component_list_contains(const char* const* values, size_t count, const char* value) {
  if (!values || !value) return false;
  for (size_t i = 0u; i < count; ++i) if (er_ui_component_streq(values[i], value)) return true;
  return false;
}

static bool er_ui_component_range_starts_with(const char* start, const char* end, const char* prefix, size_t prefix_len) {
  if (!start || !end || !prefix || end < start || (size_t)(end - start) < prefix_len) return false;
  const char* cursor = start;
  const char* prefix_cursor = prefix;
  const char* prefix_end = prefix + prefix_len;
  while (prefix_cursor < prefix_end) {
    if (*cursor != *prefix_cursor) return false;
    cursor++;
    prefix_cursor++;
  }
  return true;
}

static bool er_ui_component_ends_with_len(const char* start, const char* end, const char* suffix, size_t suffix_len) {
  if (!start || !end || !suffix || end < start || (size_t)(end - start) <= suffix_len) return false;
  const char* candidate = end - suffix_len;
  for (size_t i = 0u; i < suffix_len; ++i) if (candidate[i] != suffix[i]) return false;
  return true;
}

static er_ui_status_t er_ui_component_push_ascii_text(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  er_ui_color4_t color) {
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_COMPONENT_TEXT_CAPACITY, x, y, color);
}

static er_ui_status_t er_ui_component_push_icon(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_icon_t icon,
  er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_icon(&painter, bounds, icon, color);
}

static er_ui_status_t er_ui_component_icon_tile(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_icon_t icon,
  er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_rect_t tile_fill =
    er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 7.0f, er_ui_color_with_alpha(color, 0.18f));
  er_ui_status_t status = er_ui_scene_push_rect(scene, tile_fill);
  if (status != ER_UI_OK) return status;
  (void)theme;
  float icon_size = er_ui_float_min(bounds.w, bounds.h) - 10.0f;
  if (icon_size < 8.0f) icon_size = er_ui_float_min(bounds.w, bounds.h);
  float icon_x = bounds.x + (bounds.w - icon_size) * 0.5f;
  float icon_y = bounds.y + (bounds.h - icon_size) * 0.5f;
  er_ui_bounds_t icon_bounds = er_ui_bounds(icon_x, icon_y, icon_size, icon_size);
  return er_ui_component_push_icon(scene, icon_bounds, icon, color);
}

static er_ui_status_t er_ui_component_push_text_pair(
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
  bool emit_empty_secondary) {
  if (!scene || !font || !primary || !secondary) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, primary, primary_x, primary_y, primary_color);
  if (status != ER_UI_OK) return status;
  if (emit_empty_secondary || secondary[0]) {
    status = er_ui_component_push_ascii_text(scene, font, secondary, secondary_x, secondary_y, secondary_color);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_component_fill_border(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  float radius,
  er_ui_color4_t fill,
  er_ui_color4_t border) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, radius,
                                                                       fill));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, radius,
                                                       border));
}

static er_ui_status_t er_ui_component_row_frame_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  bool has_hit,
  float radius,
  er_ui_color4_t fill) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (has_hit) {
    er_ui_hit_t hit = er_ui_hit(hit_kind, id, bounds.x, bounds.y, bounds.w, bounds.h);
    er_ui_status_t status = er_ui_scene_push_hit(scene, hit);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, radius, fill));
}

static er_ui_status_t er_ui_component_row_body_emit(
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
  float detail_y) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_row_frame_emit(scene, bounds, hit_kind, id, has_hit, radius, fill);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_text_pair(scene, font, title, bounds.x + 12.0f, bounds.y + title_y, theme.colors.text,
                                        detail, bounds.x + 12.0f, bounds.y + detail_y, theme.colors.muted, false);
}

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

static er_ui_component_icon_text_row_t er_ui_component_icon_text_row(
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
  bool separator) {
  er_ui_component_icon_text_row_t row = {
    hit_kind,
    id,
    radius,
    fill,
    icon,
    icon_color,
    er_ui_bounds(bounds.x + ER_UI_COMPONENT_ICON_ROW_TILE_X, bounds.y + tile_y,
                 ER_UI_COMPONENT_ICON_ROW_TILE_SIZE, ER_UI_COMPONENT_ICON_ROW_TILE_SIZE),
    text_x,
    title_y,
    detail_y,
    border,
    separator};
  return row;
}

static er_ui_status_t er_ui_component_icon_text_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_component_icon_text_row_t* row,
  const char* title,
  const char* detail) {
  if (!scene || !font || !row || !title || !detail || !er_ui_bounds_valid(bounds) || !er_ui_bounds_valid(row->icon_bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_status_t status = er_ui_component_row_frame_emit(scene, bounds, row->hit_kind, row->id, true, row->radius, row->fill);
  if (status != ER_UI_OK) return status;
  if (row->border) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, row->radius,
                                                           er_ui_color_with_alpha(theme.colors.border, 0.68f)));
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_component_icon_tile(scene, row->icon_bounds, theme, row->icon, row->icon_color);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_text_pair(scene, font, title, bounds.x + row->text_x, bounds.y + row->title_y, theme.colors.text,
                                          detail, bounds.x + row->text_x, bounds.y + row->detail_y, theme.colors.muted, true);
  if (status != ER_UI_OK) return status;
  if (!row->separator) return ER_UI_OK;
  return er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - ER_UI_COMPONENT_ROW_SEPARATOR_H,
                                                           bounds.w, ER_UI_COMPONENT_ROW_SEPARATOR_H), theme);
}

static er_ui_status_t er_ui_component_bottom_separator_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  return er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - ER_UI_COMPONENT_ROW_SEPARATOR_H,
                                                           bounds.w, ER_UI_COMPONENT_ROW_SEPARATOR_H), theme);
}

static er_ui_status_t er_ui_component_badged_icon_card_emit(
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
  float detail_y) {
  if (!scene || !font || !title || !detail || !badge || !er_ui_bounds_valid(bounds) || icon_size <= 0.0f) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_icon_tile(scene,
                                     er_ui_bounds(bounds.x + ER_UI_COMPONENT_BADGED_CARD_ICON_X,
                                                  bounds.y + ER_UI_COMPONENT_BADGED_CARD_ICON_Y, icon_size, icon_size),
                                     theme, icon, icon_color);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_text_pair(scene, font, title, bounds.x + text_x, bounds.y + title_y, theme.colors.text,
                                          detail, bounds.x + text_x, bounds.y + detail_y, theme.colors.muted, true);
  if (status != ER_UI_OK) return status;
  return er_ui_component_badge_emit(scene, font,
                                    er_ui_bounds(bounds.x + ER_UI_COMPONENT_BADGED_CARD_BADGE_X,
                                                 bounds.y + bounds.h - ER_UI_COMPONENT_BADGED_CARD_BADGE_BOTTOM,
                                                 ER_UI_COMPONENT_BADGED_CARD_BADGE_W, ER_UI_COMPONENT_BADGED_CARD_BADGE_H),
                                    theme, badge, ER_UI_COMPONENT_BADGE_SECONDARY);
}

static er_ui_color4_t er_ui_component_button_fill(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE: return er_ui_color_with_alpha(theme.colors.danger, 0.18f);
    case ER_UI_COMPONENT_BUTTON_OUTLINE: return er_ui_color_with_alpha(theme.colors.panel, 0.74f);
    case ER_UI_COMPONENT_BUTTON_SECONDARY: return er_ui_color_with_alpha(theme.colors.row, 0.82f);
    case ER_UI_COMPONENT_BUTTON_GHOST:
    case ER_UI_COMPONENT_BUTTON_LINK: return er_ui_color_with_alpha(theme.colors.panel, 0.0f);
    case ER_UI_COMPONENT_BUTTON_DEFAULT:
    default: return theme.colors.accent;
  }
}

static er_ui_color4_t er_ui_component_button_border(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE: return theme.colors.danger;
    case ER_UI_COMPONENT_BUTTON_DEFAULT: return theme.colors.accent;
    default: return theme.colors.border;
  }
}

static er_ui_color4_t er_ui_component_button_text(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_DEFAULT: return theme.colors.accent_text;
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE: return theme.colors.danger;
    case ER_UI_COMPONENT_BUTTON_GHOST:
    case ER_UI_COMPONENT_BUTTON_LINK: return theme.colors.muted;
    default: return theme.colors.text;
  }
}

static er_ui_color4_t er_ui_component_badge_fill(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BADGE_SECONDARY: return er_ui_color_with_alpha(theme.colors.row, 0.86f);
    case ER_UI_COMPONENT_BADGE_DESTRUCTIVE: return er_ui_color_with_alpha(theme.colors.danger, 0.18f);
    case ER_UI_COMPONENT_BADGE_OUTLINE: return er_ui_color_with_alpha(theme.colors.panel, 0.0f);
    case ER_UI_COMPONENT_BADGE_DEFAULT:
    default: return theme.colors.accent;
  }
}

static er_ui_color4_t er_ui_component_badge_text(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BADGE_DEFAULT: return theme.colors.accent_text;
    case ER_UI_COMPONENT_BADGE_DESTRUCTIVE: return theme.colors.danger;
    default: return theme.colors.text;
  }
}

static const er_ui_component_test_id_t component_test_ids[] = {
  ER_UI_COMPONENT_NETWORK_APP_PROMPT,
  ER_UI_COMPONENT_APP_STORE_CARD,
  ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS,
  ER_UI_COMPONENT_RUNTIME_EVENT_ROW,
  ER_UI_COMPONENT_PACKAGE_PROOF_ROW,
  ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW,
  ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW,
  ER_UI_COMPONENT_NODE_INSTANCE_ROW,
  ER_UI_COMPONENT_ADMISSION_POLICY_ROW,
  ER_UI_COMPONENT_ROUTE_BUDGET_ROW,
  ER_UI_COMPONENT_DATA_TABLE_CONTROLS,
  ER_UI_COMPONENT_ICON_ONLY_BUTTON,
  ER_UI_COMPONENT_SEGMENTED_CONTROL,
  ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW,
  ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW,
  ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL
};

static const er_ui_component_state_t component_states[] = {
  ER_UI_COMPONENT_STATE_DEFAULT,
  ER_UI_COMPONENT_STATE_HOVER,
  ER_UI_COMPONENT_STATE_FOCUS,
  ER_UI_COMPONENT_STATE_ACTIVE,
  ER_UI_COMPONENT_STATE_DISABLED,
  ER_UI_COMPONENT_STATE_LOADING,
  ER_UI_COMPONENT_STATE_ERROR
};

static const er_ui_component_projected_field_t network_app_prompt_fields[] = {
  {"app_name", true},
  {"package_size", false},
  {"retrieval_cost", false},
  {"policy_hash", false},
  {"run_once_id", true},
  {"verify_cache_id", true},
  {"cancel_id", true},
};
static const er_ui_component_projected_field_t app_store_card_fields[] = {
  {"name", true},
  {"developer", false},
  {"release", false},
  {"package_hash", false},
  {"app_policy_hash", false},
  {"access_mode", false},
  {"detail_id", true},
  {"run_id", true},
};
static const er_ui_component_projected_field_t trust_manager_action_fields[] = {
  {"open_identity_id", true},
  {"open_app_store_id", true},
  {"revoke_grant_id", true},
  {"remove_cache_id", true},
};
static const er_ui_component_projected_field_t runtime_event_row_fields[] = {
  {"title", true},
  {"detail", false},
  {"event_hash", true},
  {"status", false},
  {"id", true},
  {"accent", false},
};
static const er_ui_component_projected_field_t package_proof_row_fields[] = {
  {"package_hash", true},
  {"manifest_hash", true},
  {"developer", false},
  {"release", false},
  {"status", false},
  {"id", true},
};
static const er_ui_component_projected_field_t import_sync_source_row_fields[] = {
  {"kind", true},
  {"name", false},
  {"detail", false},
  {"policy_hash", false},
  {"status", false},
  {"id", true},
  {"sync_id", false},
  {"configure_id", false},
};
static const er_ui_component_projected_field_t publish_from_node_row_fields[] = {
  {"kind", true},
  {"title", false},
  {"node_instance", false},
  {"route_scope", false},
  {"policy_hash", false},
  {"budget", false},
  {"status", false},
  {"id", true},
  {"publish_id", false},
  {"configure_id", false},
};
static const er_ui_component_projected_field_t node_instance_row_fields[] = {
  {"role", true},
  {"runtime_target", false},
  {"route_scope", false},
  {"policy_hash", false},
  {"status", false},
  {"id", true},
  {"open_id", false},
};
static const er_ui_component_projected_field_t admission_policy_row_fields[] = {
  {"source", true},
  {"policy_hash", true},
  {"admission_node", false},
  {"validity", false},
  {"status", false},
  {"id", true},
  {"inspect_id", false},
};
static const er_ui_component_projected_field_t route_budget_row_fields[] = {
  {"route", true},
  {"admitted_budget", true},
  {"spent", false},
  {"channel", false},
  {"status", false},
  {"id", true},
  {"inspect_id", false},
};
static const er_ui_component_projected_field_t data_table_control_fields[] = {
  {"title", false},
  {"filter_label", false},
  {"filter_value", false},
  {"filter_id", true},
  {"clear_filter_id", false},
  {"columns", true},
};
//@optimizer-ignore-constant icon-only projection metadata is returned with an explicit field count by component id switch
static const er_ui_component_projected_field_t icon_only_button_fields[] = {
  {"icon", true},
  {"id", true},
  {"label", true},
  {"active", false},
};
static const er_ui_component_projected_field_t segmented_control_fields[] = {
  {"items", true},
  {"selected", true},
};
static const er_ui_component_projected_field_t receipt_payment_row_fields[] = {
  {"label", true},
  {"receipt_id", false},
  {"policy_hash", false},
  {"amount", true},
  {"status", true},
  {"id", true},
  {"action", false},
};
static const er_ui_component_projected_field_t capability_grant_row_fields[] = {
  {"app", true},
  {"capability", true},
  {"scope", false},
  {"policy_hash", false},
  {"expiry", false},
  {"status", false},
  {"id", true},
  {"revoke_id", false},
};
static const er_ui_component_projected_field_t system_surface_state_panel_fields[] = {
  {"kind", true},
  {"state", true},
  {"title", false},
  {"detail", false},
  {"reference", false},
  {"id", true},
  {"action", false},
};

static const char *const network_app_prompt_labels[] = {
  "app_name",
};
static const char *const app_store_card_labels[] = {
  "name",
  "developer",
  "app_policy_hash",
};
static const char *const trust_manager_action_labels[] = {
  "open_identity_id",
  "open_app_store_id",
  "revoke_grant_id",
  "remove_cache_id",
};
static const char *const runtime_event_row_labels[] = {
  "title",
  "event_hash",
  "status",
};
static const char *const package_proof_row_labels[] = {
  "package_hash",
  "manifest_hash",
  "status",
};
static const char *const import_sync_source_row_labels[] = {
  "kind",
  "name",
  "policy_hash",
  "status",
};
static const char *const publish_from_node_row_labels[] = {
  "kind",
  "title",
  "node_instance",
  "policy_hash",
  "status",
};
static const char *const node_instance_row_labels[] = {
  "role",
  "runtime_target",
  "policy_hash",
  "status",
};
static const char *const admission_policy_row_labels[] = {
  "source",
  "policy_hash",
  "admission_node",
  "status",
};
static const char *const route_budget_row_labels[] = {
  "route",
  "admitted_budget",
  "status",
};
static const char *const data_table_control_labels[] = {
  "title",
  "filter_label",
  "columns",
};
static const char *const icon_only_button_labels[] = {
  "label",
};
static const char *const segmented_control_labels[] = {
  "items",
};
static const char *const receipt_payment_row_labels[] = {
  "label",
  "receipt_id",
  "amount",
  "status",
};
static const char *const capability_grant_row_labels[] = {
  "app",
  "capability",
  "scope",
  "status",
};
static const char *const system_surface_state_panel_labels[] = {
  "kind",
  "state",
  "title",
  "detail",
};

static const char* const no_variants[] = {0};
static const char* const no_keyboard[] = {0};
static const char* const static_interactions[] = {"render"};
static const char* const click_interactions[] = {"render", "click"};
static const char* const input_interactions[] = {"render", "focus", "input", "disabled"};
static const char* const disclosure_interactions[] = {"render", "open", "close", "focus", "disabled"};
static const char* const overlay_interactions[] = {"render", "trigger", "open", "close", "focus-trap"};
static const char* const menu_interactions[] = {"render", "trigger", "open", "close", "select", "disabled"};
static const char* const collection_interactions[] = {"render", "select", "keyboard-nav", "disabled"};
static const char* const drag_interactions[] = {"render", "drag", "keyboard-nav", "disabled"};
static const char* const text_input_keyboard[] = {"Tab", "Shift+Tab", "Input"};
static const char* const menu_keyboard[] = {"Enter", "Space", "Escape", "ArrowUp", "ArrowDown", "Home", "End"};
static const char* const horizontal_keyboard[] = {"Enter", "Space", "ArrowLeft", "ArrowRight", "Home", "End"};
static const char* const overlay_keyboard[] = {"Escape", "Tab", "Shift+Tab"};
static const char* const dialog_keyboard[] = {"Escape", "Tab", "Shift+Tab", "Enter"};
static const char* const input_otp_keyboard[] = {
  "Tab",
  "Shift+Tab",
  "ArrowLeft",
  "ArrowRight",
  "Backspace",
  "Input",
  "Paste"};
static const char* const slider_keyboard[] = {"ArrowLeft", "ArrowRight", "Home", "End", "PageUp", "PageDown"};
static const char* const button_variants[] = {"default", "destructive", "outline", "secondary", "ghost", "link"};
static const char* const badge_variants[] = {"default", "secondary", "destructive", "outline"};
static const char* const alert_variants[] = {"default", "destructive"};
static const char* const sheet_sides[] = {"top", "right", "bottom", "left"};
static const char* const field_variants[] = {"default", "invalid"};
static const char* const orientation_variants[] = {"horizontal", "vertical"};
static const char* const toast_variants[] = {"default", "destructive", "success", "warning", "info"};
static const char* const direction_variants[] = {"ltr", "rtl"};

static const char* const slots_accordion[] = {
  "accordion",
  "accordion-item",
  "accordion-trigger",
  "accordion-content",
};
static const char* const states_accordion[] = {
  "data-state=open",
  "data-state=closed",
  "disabled",
};
static const char* const slots_alert[] = {
  "alert",
  "alert-title",
  "alert-description",
};
static const char* const states_alert[] = {
  "default",
  "destructive",
};
static const char* const slots_alert_dialog[] = {
  "alert-dialog",
  "alert-dialog-trigger",
  "alert-dialog-content",
  "alert-dialog-header",
  "alert-dialog-footer",
  "alert-dialog-title",
  "alert-dialog-description",
  "alert-dialog-action",
  "alert-dialog-cancel",
};
static const char* const states_alert_dialog[] = {
  "open",
  "closed",
  "focus-trap",
};
static const char* const slots_aspect_ratio[] = {
  "aspect-ratio",
};
static const char* const states_aspect_ratio[] = {
  0,
};
static const char* const slots_avatar[] = {
  "avatar",
  "avatar-image",
  "avatar-fallback",
};
static const char* const states_avatar[] = {
  "loaded",
  "fallback",
};
static const char* const slots_badge[] = {
  "badge",
};
static const char* const states_badge[] = {
  "default",
  "secondary",
  "outline",
  "destructive",
};
static const char* const slots_breadcrumb[] = {
  "breadcrumb",
  "breadcrumb-list",
  "breadcrumb-item",
  "breadcrumb-link",
  "breadcrumb-page",
  "breadcrumb-separator",
  "breadcrumb-ellipsis",
};
static const char* const states_breadcrumb[] = {
  "current-page",
};
static const char* const slots_button[] = {
  "button",
};
static const char* const states_button[] = {
  "default",
  "destructive",
  "outline",
  "secondary",
  "ghost",
  "link",
  "disabled",
  "loading",
};
static const char* const slots_button_group[] = {
  "button-group",
  "button-group-item",
  "button-group-separator",
};
static const char* const states_button_group[] = {
  "horizontal",
  "vertical",
  "attached",
};
static const char* const slots_calendar[] = {
  "calendar",
  "calendar-month",
  "calendar-day",
  "calendar-caption",
};
static const char* const states_calendar[] = {
  "selected",
  "today",
  "disabled",
  "range-start",
  "range-end",
};
static const char* const slots_card[] = {
  "card",
  "card-header",
  "card-title",
  "card-description",
  "card-content",
  "card-footer",
};
static const char* const states_card[] = {
  "default",
  "sm",
};
static const char* const slots_carousel[] = {
  "carousel",
  "carousel-content",
  "carousel-item",
  "carousel-previous",
  "carousel-next",
};
static const char* const states_carousel[] = {
  "can-scroll-prev",
  "can-scroll-next",
};
static const char* const slots_chart[] = {
  "chart-container",
  "chart-tooltip",
  "chart-legend",
};
static const char* const states_chart[] = {
  "hovered",
  "active",
};
static const char* const slots_checkbox[] = {
  "checkbox",
};
static const char* const states_checkbox[] = {
  "checked",
  "unchecked",
  "indeterminate",
  "disabled",
};
static const char* const slots_collapsible[] = {
  "collapsible",
  "collapsible-trigger",
  "collapsible-content",
};
static const char* const states_collapsible[] = {
  "open",
  "closed",
  "disabled",
};
static const char* const slots_combobox[] = {
  "combobox",
  "popover",
  "command",
  "command-input",
  "command-item",
};
static const char* const states_combobox[] = {
  "open",
  "closed",
  "selected",
  "empty",
};
static const char* const slots_command[] = {
  "command",
  "command-input",
  "command-list",
  "command-group",
  "command-item",
  "command-empty",
};
static const char* const states_command[] = {
  "selected",
  "empty",
  "disabled",
};
static const char* const slots_context_menu[] = {
  "context-menu",
  "context-menu-trigger",
  "context-menu-content",
  "context-menu-item",
};
static const char* const states_context_menu[] = {
  "open",
  "closed",
  "checked",
  "disabled",
};
static const char* const slots_data_table[] = {
  "table",
  "table-header",
  "table-body",
  "table-row",
  "table-cell",
};
static const char* const states_data_table[] = {
  "sorted",
  "selected",
  "loading",
  "empty",
};
static const char* const slots_date_picker[] = {
  "popover",
  "calendar",
  "button",
  "field",
};
static const char* const states_date_picker[] = {
  "open",
  "selected",
  "empty",
};
static const char* const slots_dialog[] = {
  "dialog",
  "dialog-trigger",
  "dialog-content",
  "dialog-header",
  "dialog-footer",
};
static const char* const states_dialog[] = {
  "open",
  "closed",
  "focus-trap",
};
static const char* const slots_direction[] = {
  "direction-provider",
};
static const char* const states_direction[] = {
  "ltr",
  "rtl",
};
static const char* const slots_drawer[] = {
  "drawer",
  "drawer-trigger",
  "drawer-content",
  "drawer-header",
  "drawer-footer",
};
static const char* const states_drawer[] = {
  "open",
  "closed",
  "dragging",
};
static const char* const slots_dropdown_menu[] = {
  "dropdown-menu",
  "dropdown-menu-trigger",
  "dropdown-menu-content",
  "dropdown-menu-item",
};
static const char* const states_dropdown_menu[] = {
  "open",
  "closed",
  "checked",
  "disabled",
};
static const char* const slots_empty[] = {
  "empty",
  "empty-header",
  "empty-icon",
  "empty-title",
  "empty-description",
  "empty-content",
};
static const char* const states_empty[] = {
  "default",
  "loading",
};
static const char* const slots_field[] = {
  "field",
  "field-label",
  "field-title",
  "field-description",
  "field-error",
};
static const char* const states_field[] = {
  "invalid",
  "disabled",
  "required",
};
static const char* const slots_hover_card[] = {
  "hover-card",
  "hover-card-trigger",
  "hover-card-content",
};
static const char* const states_hover_card[] = {
  "open",
  "closed",
};
static const char* const slots_input[] = {
  "input",
};
static const char* const states_input[] = {
  "placeholder",
  "focus",
  "disabled",
  "invalid",
};
static const char* const slots_input_group[] = {
  "input-group",
  "input-group-input",
  "input-group-addon",
  "input-group-button",
};
static const char* const states_input_group[] = {
  "focus-within",
  "disabled",
  "invalid",
};
static const char* const slots_input_otp[] = {
  "input-otp",
  "input-otp-group",
  "input-otp-slot",
  "input-otp-separator",
};
static const char* const states_input_otp[] = {
  "active",
  "filled",
  "disabled",
};
static const char* const slots_item[] = {
  "item",
  "item-media",
  "item-content",
  "item-title",
  "item-description",
  "item-actions",
};
static const char* const states_item[] = {
  "selected",
  "disabled",
};
static const char* const slots_kbd[] = {
  "kbd",
};
static const char* const states_kbd[] = {
  0,
};
static const char* const slots_label[] = {
  "label",
};
static const char* const states_label[] = {
  "disabled",
};
static const char* const slots_menubar[] = {
  "menubar",
  "menubar-menu",
  "menubar-trigger",
  "menubar-content",
  "menubar-item",
};
static const char* const states_menubar[] = {
  "open",
  "closed",
  "checked",
  "disabled",
};
static const char* const slots_native_select[] = {
  "native-select",
};
static const char* const states_native_select[] = {
  "disabled",
  "invalid",
};
static const char* const slots_navigation_menu[] = {
  "navigation-menu",
  "navigation-menu-list",
  "navigation-menu-item",
  "navigation-menu-content",
};
static const char* const states_navigation_menu[] = {
  "open",
  "closed",
  "active",
};
static const char* const slots_pagination[] = {
  "pagination",
  "pagination-content",
  "pagination-item",
  "pagination-link",
};
static const char* const states_pagination[] = {
  "active",
  "disabled",
};
static const char* const slots_popover[] = {
  "popover",
  "popover-trigger",
  "popover-content",
  "popover-anchor",
};
static const char* const states_popover[] = {
  "open",
  "closed",
};
static const char* const slots_progress[] = {
  "progress",
  "progress-indicator",
};
static const char* const states_progress[] = {
  "determinate",
  "indeterminate",
};
static const char* const slots_radio_group[] = {
  "radio-group",
  "radio-group-item",
};
static const char* const states_radio_group[] = {
  "checked",
  "unchecked",
  "disabled",
};
static const char* const slots_resizable[] = {
  "resizable-panel-group",
  "resizable-panel",
  "resizable-handle",
};
static const char* const states_resizable[] = {
  "dragging",
  "horizontal",
  "vertical",
};
static const char* const slots_scroll_area[] = {
  "scroll-area",
  "scroll-area-viewport",
  "scroll-area-scrollbar",
  "scroll-area-thumb",
};
static const char* const states_scroll_area[] = {
  "scrolling",
  "horizontal",
  "vertical",
};
static const char* const slots_select[] = {
  "select",
  "select-trigger",
  "select-content",
  "select-item",
  "select-value",
};
static const char* const states_select[] = {
  "open",
  "closed",
  "selected",
  "disabled",
};
static const char* const slots_separator[] = {
  "separator",
};
static const char* const states_separator[] = {
  "horizontal",
  "vertical",
};
static const char* const slots_sheet[] = {
  "sheet",
  "sheet-trigger",
  "sheet-content",
  "sheet-header",
  "sheet-footer",
};
static const char* const states_sheet[] = {
  "open",
  "closed",
  "side-top",
  "side-right",
  "side-bottom",
  "side-left",
};
static const char* const slots_sidebar[] = {
  "sidebar",
  "sidebar-header",
  "sidebar-content",
  "sidebar-footer",
  "sidebar-menu",
};
static const char* const states_sidebar[] = {
  "expanded",
  "collapsed",
  "mobile",
  "active",
};
static const char* const slots_skeleton[] = {
  "skeleton",
};
static const char* const states_skeleton[] = {
  "loading",
};
static const char* const slots_slider[] = {
  "slider",
  "slider-track",
  "slider-range",
  "slider-thumb",
};
static const char* const states_slider[] = {
  "dragging",
  "disabled",
};
static const char* const slots_sonner[] = {
  "toaster",
  "toast",
  "toast-title",
  "toast-description",
  "toast-action",
};
static const char* const states_sonner[] = {
  "success",
  "info",
  "warning",
  "error",
  "loading",
};
static const char* const slots_switch[] = {
  "switch",
  "switch-thumb",
};
static const char* const states_switch[] = {
  "checked",
  "unchecked",
  "disabled",
};
static const char* const slots_table[] = {
  "table",
  "table-header",
  "table-body",
  "table-footer",
  "table-row",
  "table-cell",
};
static const char* const states_table[] = {
  "selected",
  "sortable",
};
static const char* const slots_tabs[] = {
  "tabs",
  "tabs-list",
  "tabs-trigger",
  "tabs-content",
};
static const char* const states_tabs[] = {
  "active",
  "inactive",
  "disabled",
};
static const char* const slots_textarea[] = {
  "textarea",
};
static const char* const states_textarea[] = {
  "placeholder",
  "focus",
  "disabled",
  "invalid",
};
static const char* const slots_toast[] = {
  "toast",
  "toast-title",
  "toast-description",
  "toast-action",
  "toast-close",
};
static const char* const states_toast[] = {
  "open",
  "closed",
  "success",
  "destructive",
};
static const char* const slots_toggle[] = {
  "toggle",
};
static const char* const states_toggle[] = {
  "pressed",
  "unpressed",
  "disabled",
};
static const char* const slots_toggle_group[] = {
  "toggle-group",
  "toggle-group-item",
};
static const char* const states_toggle_group[] = {
  "single",
  "multiple",
  "pressed",
  "disabled",
};
static const char* const slots_tooltip[] = {
  "tooltip",
  "tooltip-trigger",
  "tooltip-content",
};
static const char* const states_tooltip[] = {
  "open",
  "closed",
  "side-top",
  "side-right",
  "side-bottom",
  "side-left",
};

static const er_ui_component_spec_t component_catalog[] = {
  ER_UI_COMPONENT_ENTRY(
    "Accordion",
    "accordion",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Accordion",
    "accordion_node",
    slots_accordion,
    states_accordion),
  ER_UI_COMPONENT_ENTRY(
    "Alert",
    "alert",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Alert",
    "alert_node",
    slots_alert,
    states_alert),
  ER_UI_COMPONENT_ENTRY(
    "Alert Dialog",
    "alert-dialog",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "AlertDialog",
    "alert_dialog_node",
    slots_alert_dialog,
    states_alert_dialog),
  ER_UI_COMPONENT_EMPTY(
    "Aspect Ratio",
    "aspect-ratio",
    ER_UI_COMPONENT_CATEGORY_MEDIA,
    "AspectRatio",
    "aspect_ratio_node",
    slots_aspect_ratio,
    states_aspect_ratio),
  ER_UI_COMPONENT_ENTRY(
    "Avatar",
    "avatar",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Avatar",
    "avatar_node",
    slots_avatar,
    states_avatar),
  ER_UI_COMPONENT_ENTRY(
    "Badge",
    "badge",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Badge",
    "badge",
    slots_badge,
    states_badge),
  ER_UI_COMPONENT_ENTRY(
    "Breadcrumb",
    "breadcrumb",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Breadcrumb",
    "breadcrumb",
    slots_breadcrumb,
    states_breadcrumb),
  ER_UI_COMPONENT_ENTRY(
    "Button",
    "button",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Button",
    "button",
    slots_button,
    states_button),
  ER_UI_COMPONENT_ENTRY(
    "Button Group",
    "button-group",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "ButtonGroup",
    "button_group_node",
    slots_button_group,
    states_button_group),
  ER_UI_COMPONENT_ENTRY(
    "Calendar",
    "calendar",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Calendar",
    "calendar_node",
    slots_calendar,
    states_calendar),
  ER_UI_COMPONENT_ENTRY(
    "Card",
    "card",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Card",
    "card",
    slots_card,
    states_card),
  ER_UI_COMPONENT_ENTRY(
    "Carousel",
    "carousel",
    ER_UI_COMPONENT_CATEGORY_MEDIA,
    "Carousel",
    "carousel_node",
    slots_carousel,
    states_carousel),
  ER_UI_COMPONENT_ENTRY(
    "Chart",
    "chart",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Chart",
    "chart_node",
    slots_chart,
    states_chart),
  ER_UI_COMPONENT_ENTRY(
    "Checkbox",
    "checkbox",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Checkbox",
    "checkbox",
    slots_checkbox,
    states_checkbox),
  ER_UI_COMPONENT_ENTRY(
    "Collapsible",
    "collapsible",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Collapsible",
    "collapsible_node",
    slots_collapsible,
    states_collapsible),
  ER_UI_COMPONENT_ENTRY(
    "Combobox",
    "combobox",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Combobox",
    "combobox_node",
    slots_combobox,
    states_combobox),
  ER_UI_COMPONENT_ENTRY(
    "Command",
    "command",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Command",
    "command_palette",
    slots_command,
    states_command),
  ER_UI_COMPONENT_ENTRY(
    "Context Menu",
    "context-menu",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "ContextMenu",
    "context_menu_node",
    slots_context_menu,
    states_context_menu),
  ER_UI_COMPONENT_ENTRY(
    "Data Table",
    "data-table",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "DataTable",
    "data_table_node",
    slots_data_table,
    states_data_table),
  ER_UI_COMPONENT_ENTRY(
    "Date Picker",
    "date-picker",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "DatePicker",
    "date_picker_node",
    slots_date_picker,
    states_date_picker),
  ER_UI_COMPONENT_ENTRY(
    "Dialog",
    "dialog",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Dialog",
    "dialog",
    slots_dialog,
    states_dialog),
  ER_UI_COMPONENT_ENTRY(
    "Direction",
    "direction",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "DirectionProvider",
    "direction_node",
    slots_direction,
    states_direction),
  ER_UI_COMPONENT_ENTRY(
    "Drawer",
    "drawer",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Drawer",
    "drawer_node",
    slots_drawer,
    states_drawer),
  ER_UI_COMPONENT_ENTRY(
    "Dropdown Menu",
    "dropdown-menu",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "DropdownMenu",
    "dropdown_menu_node",
    slots_dropdown_menu,
    states_dropdown_menu),
  ER_UI_COMPONENT_ENTRY(
    "Empty",
    "empty",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Empty",
    "empty_state",
    slots_empty,
    states_empty),
  ER_UI_COMPONENT_ENTRY(
    "Field",
    "field",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Field",
    "field_node",
    slots_field,
    states_field),
  ER_UI_COMPONENT_ENTRY(
    "Hover Card",
    "hover-card",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "HoverCard",
    "hover_card_node",
    slots_hover_card,
    states_hover_card),
  ER_UI_COMPONENT_ENTRY(
    "Input",
    "input",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Input",
    "field_node",
    slots_input,
    states_input),
  ER_UI_COMPONENT_ENTRY(
    "Input Group",
    "input-group",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "InputGroup",
    "input_group_node",
    slots_input_group,
    states_input_group),
  ER_UI_COMPONENT_ENTRY(
    "Input OTP",
    "input-otp",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "InputOTP",
    "input_otp_node",
    slots_input_otp,
    states_input_otp),
  ER_UI_COMPONENT_ENTRY(
    "Item",
    "item",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Item",
    "list_row_node",
    slots_item,
    states_item),
  ER_UI_COMPONENT_EMPTY(
    "Kbd",
    "kbd",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Kbd",
    "kbd_node",
    slots_kbd,
    states_kbd),
  ER_UI_COMPONENT_ENTRY(
    "Label",
    "label",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Label",
    "text",
    slots_label,
    states_label),
  ER_UI_COMPONENT_ENTRY(
    "Menubar",
    "menubar",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Menubar",
    "menubar_node",
    slots_menubar,
    states_menubar),
  ER_UI_COMPONENT_ENTRY(
    "Native Select",
    "native-select",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "NativeSelect",
    "select_node",
    slots_native_select,
    states_native_select),
  ER_UI_COMPONENT_ENTRY(
    "Navigation Menu",
    "navigation-menu",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "NavigationMenu",
    "navigation_menu_node",
    slots_navigation_menu,
    states_navigation_menu),
  ER_UI_COMPONENT_ENTRY(
    "Pagination",
    "pagination",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Pagination",
    "pagination_node",
    slots_pagination,
    states_pagination),
  ER_UI_COMPONENT_ENTRY(
    "Popover",
    "popover",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Popover",
    "popover_node",
    slots_popover,
    states_popover),
  ER_UI_COMPONENT_ENTRY(
    "Progress",
    "progress",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Progress",
    "progress_bar_node",
    slots_progress,
    states_progress),
  ER_UI_COMPONENT_ENTRY(
    "Radio Group",
    "radio-group",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "RadioGroup",
    "radio",
    slots_radio_group,
    states_radio_group),
  ER_UI_COMPONENT_ENTRY(
    "Resizable",
    "resizable",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Resizable",
    "resizable_node",
    slots_resizable,
    states_resizable),
  ER_UI_COMPONENT_ENTRY(
    "Scroll Area",
    "scroll-area",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "ScrollArea",
    "scroll_area",
    slots_scroll_area,
    states_scroll_area),
  ER_UI_COMPONENT_ENTRY(
    "Select",
    "select",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Select",
    "select_node",
    slots_select,
    states_select),
  ER_UI_COMPONENT_ENTRY(
    "Separator",
    "separator",
    ER_UI_COMPONENT_CATEGORY_LAYOUT,
    "Separator",
    "divider",
    slots_separator,
    states_separator),
  ER_UI_COMPONENT_ENTRY(
    "Sheet",
    "sheet",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Sheet",
    "sheet_node",
    slots_sheet,
    states_sheet),
  ER_UI_COMPONENT_ENTRY(
    "Sidebar",
    "sidebar",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Sidebar",
    "sidebar_node",
    slots_sidebar,
    states_sidebar),
  ER_UI_COMPONENT_ENTRY(
    "Skeleton",
    "skeleton",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Skeleton",
    "skeleton",
    slots_skeleton,
    states_skeleton),
  ER_UI_COMPONENT_ENTRY(
    "Slider",
    "slider",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Slider",
    "slider_node",
    slots_slider,
    states_slider),
  ER_UI_COMPONENT_ENTRY(
    "Sonner",
    "sonner",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Sonner",
    "toast",
    slots_sonner,
    states_sonner),
  ER_UI_COMPONENT_ENTRY(
    "Switch",
    "switch",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Switch",
    "toggle_node",
    slots_switch,
    states_switch),
  ER_UI_COMPONENT_ENTRY(
    "Table",
    "table",
    ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY,
    "Table",
    "table_node",
    slots_table,
    states_table),
  ER_UI_COMPONENT_ENTRY(
    "Tabs",
    "tabs",
    ER_UI_COMPONENT_CATEGORY_NAVIGATION,
    "Tabs",
    "tabs_node",
    slots_tabs,
    states_tabs),
  ER_UI_COMPONENT_ENTRY(
    "Textarea",
    "textarea",
    ER_UI_COMPONENT_CATEGORY_FORM,
    "Textarea",
    "text_area_node",
    slots_textarea,
    states_textarea),
  ER_UI_COMPONENT_ENTRY(
    "Toast",
    "toast",
    ER_UI_COMPONENT_CATEGORY_FEEDBACK,
    "Toast",
    "toast",
    slots_toast,
    states_toast),
  ER_UI_COMPONENT_ENTRY(
    "Toggle",
    "toggle",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "Toggle",
    "toggle_node",
    slots_toggle,
    states_toggle),
  ER_UI_COMPONENT_ENTRY(
    "Toggle Group",
    "toggle-group",
    ER_UI_COMPONENT_CATEGORY_FOUNDATION,
    "ToggleGroup",
    "toggle_group_node",
    slots_toggle_group,
    states_toggle_group),
  ER_UI_COMPONENT_ENTRY(
    "Tooltip",
    "tooltip",
    ER_UI_COMPONENT_CATEGORY_OVERLAY,
    "Tooltip",
    "tooltip",
    slots_tooltip,
    states_tooltip),
};

const char* er_ui_component_category_label(er_ui_component_category_t category) {
  switch (category) {
    case ER_UI_COMPONENT_CATEGORY_FOUNDATION: return "Foundation";
    case ER_UI_COMPONENT_CATEGORY_FORM: return "Form";
    case ER_UI_COMPONENT_CATEGORY_OVERLAY: return "Overlay";
    case ER_UI_COMPONENT_CATEGORY_NAVIGATION: return "Navigation";
    case ER_UI_COMPONENT_CATEGORY_DATA_DISPLAY: return "Data Display";
    case ER_UI_COMPONENT_CATEGORY_FEEDBACK: return "Feedback";
    case ER_UI_COMPONENT_CATEGORY_LAYOUT: return "Layout";
    case ER_UI_COMPONENT_CATEGORY_MEDIA: return "Media";
    default: return "";
  }
}

const char* er_ui_component_status_label(er_ui_component_status_t status) {
  switch (status) {
    case ER_UI_COMPONENT_STATUS_CATALOGED: return "Cataloged";
    case ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE: return "Native primitive";
    case ER_UI_COMPONENT_STATUS_EXACT_PORT: return "Exact port";
    default: return "";
  }
}

const char* er_ui_component_resolve_kind_label(er_ui_component_resolve_kind_t kind) {
  switch (kind) {
    case ER_UI_COMPONENT_RESOLVE_SLUG: return "Slug";
    case ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT: return "Source component";
    case ER_UI_COMPONENT_RESOLVE_MODULE_PATH: return "Module path";
    case ER_UI_COMPONENT_RESOLVE_SLOT: return "Slot";
    default: return "";
  }
}

const er_ui_component_spec_t* er_ui_component_at(size_t index) {
  return index < ER_UI_COMPONENT_COUNT ? &component_catalog[index] : 0;
}

size_t er_ui_component_count(void) { return ER_UI_COMPONENT_COUNT; }

bool er_ui_component_has_native_renderer(const er_ui_component_spec_t* spec) {
  return spec
    && (spec->status == ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE
      || spec->status == ER_UI_COMPONENT_STATUS_EXACT_PORT);
}

bool er_ui_component_is_exact_port(const er_ui_component_spec_t* spec) {
  return spec && spec->status == ER_UI_COMPONENT_STATUS_EXACT_PORT;
}

bool er_ui_component_uses_slot(const er_ui_component_spec_t* spec, const char* slot) {
  return spec && er_ui_component_list_contains(spec->slots, spec->slot_count, slot);
}

bool er_ui_component_uses_state(const er_ui_component_spec_t* spec, const char* state) {
  return spec && er_ui_component_list_contains(spec->states, spec->state_count, state);
}

const er_ui_component_spec_t* er_ui_component_find_by_slug(const char* slug) {
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    if (er_ui_component_streq(component_catalog[i].slug, slug)) {
      return &component_catalog[i];
    }
  }
  return 0;
}

const er_ui_component_spec_t* er_ui_component_find_by_source_component(const char* source_component) {
  for (size_t i = 0u; i < ER_UI_COMPONENT_COUNT; ++i) {
    if (er_ui_component_streq(component_catalog[i].source_component, source_component)) {
      return &component_catalog[i];
    }
  }
  return 0;
}

static bool er_ui_component_is_upper(char c) { return c >= 'A' && c <= 'Z'; }
static char er_ui_component_lower(char c) {
  return er_ui_component_is_upper(c) ? (char)(c + 32) : c;
}

static bool er_ui_component_normalize_identifier(const char* identifier, char* out, size_t cap, bool* out_from_path) {
  if (!identifier || !out || cap == 0u || !out_from_path) return false;
  static const char data_slot_prefix[] = "data-slot=";
  const size_t data_slot_prefix_len = ER_UI_COMPONENT_ARRAY_COUNT(data_slot_prefix) - 1u;
  const char* start = identifier;
  while (*start == ' ' || *start == '\t' || *start == '\n' || *start == '\r') start++;
  const char* end = start;
  while (*end) end++;
  while (end > start && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\n' || end[-1] == '\r')) end--;
  if (er_ui_component_range_starts_with(start, end, data_slot_prefix, data_slot_prefix_len)) {
    start += data_slot_prefix_len;
    while (start < end && (*start == '\"' || *start == '\'')) start++;
    while (end > start && (end[-1] == '\"' || end[-1] == '\'')) end--;
  }
  *out_from_path = false;
  const char* last = start;
  for (const char* p = start; p < end; ++p) {
    if (*p == '/') { *out_from_path = true; last = p + 1; }
  }
  start = last;
  if (er_ui_component_ends_with_len(start, end, ".tsx", ER_UI_COMPONENT_SUFFIX_TSX_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_TSX_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".jsx", ER_UI_COMPONENT_SUFFIX_JSX_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_JSX_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".ts", ER_UI_COMPONENT_SUFFIX_TS_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_TS_LEN;
  } else if (er_ui_component_ends_with_len(start, end, ".js", ER_UI_COMPONENT_SUFFIX_JS_LEN)) {
    end -= ER_UI_COMPONENT_SUFFIX_JS_LEN;
  }
  bool needs_kebab = false;
  for (const char* p = start; p < end; ++p) {
    if (er_ui_component_is_upper(*p) || *p == '_' || *p == ' ') needs_kebab = true;
  }
  size_t n = 0u;
  bool previous_was_separator = true;
  for (const char* p = start; p < end; ++p) {
    char ch = *p;
    if (needs_kebab && (ch == '_' || ch == ' ')) {
      if (!previous_was_separator) {
        if (n + 1u >= cap) return false;
        out[n++] = '-';
      }
      previous_was_separator = true;
      continue;
    }
    if (needs_kebab && er_ui_component_is_upper(ch)) {
      if (!previous_was_separator) {
        if (n + 1u >= cap) return false;
        out[n++] = '-';
      }
      if (n + 1u >= cap) return false;
      out[n++] = er_ui_component_lower(ch);
      previous_was_separator = false;
      continue;
    }
    if (n + 1u >= cap) return false;
    out[n++] = er_ui_component_lower(ch);
    previous_was_separator = ch == '-';
  }
  out[n] = '\0';
  return n > 0u;
}

bool er_ui_component_resolve_identifier(const char* identifier, er_ui_component_resolved_t* out_resolved) {
  if (!identifier || !out_resolved) return false;
  const char* trimmed = identifier;
  while (*trimmed == ' ' || *trimmed == '\t' || *trimmed == '\n' || *trimmed == '\r') trimmed++;
  const er_ui_component_spec_t* direct_source = er_ui_component_find_by_source_component(trimmed);
  if (direct_source) {
    out_resolved->spec = direct_source;
    out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT;
    return true;
  }
  char normalized[ER_UI_COMPONENT_IDENTIFIER_CAPACITY];
  bool from_path = false;
  if (!er_ui_component_normalize_identifier(identifier, normalized, sizeof(normalized), &from_path)) return false;
  const er_ui_component_spec_t* by_slug = er_ui_component_find_by_slug(normalized);
  if (by_slug) {
    out_resolved->spec = by_slug;
    out_resolved->kind = from_path ? ER_UI_COMPONENT_RESOLVE_MODULE_PATH : ER_UI_COMPONENT_RESOLVE_SLUG;
    return true;
  }
  const er_ui_component_spec_t* by_source = er_ui_component_find_by_source_component(normalized);
  if (by_source) {
    out_resolved->spec = by_source;
    out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT;
    return true;
  }
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (er_ui_component_uses_slot(component, normalized)) {
      out_resolved->spec = component;
      out_resolved->kind = ER_UI_COMPONENT_RESOLVE_SLOT;
      return true;
    }
    component++;
  }
  return false;
}

bool er_ui_component_port_mapping_for_identifier(const char* identifier, er_ui_component_port_mapping_t* out_mapping) {
  if (!identifier || !out_mapping) return false;
  er_ui_component_resolved_t resolved = {0};
  if (!er_ui_component_resolve_identifier(identifier, &resolved)) return false;
  out_mapping->identifier = identifier;
  out_mapping->resolve_kind = resolved.kind;
  out_mapping->slug = resolved.spec->slug;
  out_mapping->source_component = resolved.spec->source_component;
  out_mapping->edge_builder = resolved.spec->edge_builder;
  out_mapping->category = resolved.spec->category;
  out_mapping->status = resolved.spec->status;
  out_mapping->native_renderer = er_ui_component_has_native_renderer(resolved.spec);
  out_mapping->exact_port = er_ui_component_is_exact_port(resolved.spec);
  return true;
}

size_t er_ui_component_native_count(void) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->status == ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE
      || component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT) {
      count++;
    }
    component++;
  }
  return count;
}
size_t er_ui_component_exact_count(void) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT) count++;
    component++;
  }
  return count;
}
size_t er_ui_component_count_by_category(er_ui_component_category_t category) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->category == category) count++;
    component++;
  }
  return count;
}
size_t er_ui_component_count_by_status(er_ui_component_status_t status) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    if (component->status == status) count++;
    component++;
  }
  return count;
}
static const char* const* er_ui_component_variants_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  if (er_ui_component_streq(slug, "alert")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(alert_variants);
    return alert_variants;
  }
  if (er_ui_component_streq(slug, "badge")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(badge_variants);
    return badge_variants;
  }
  if (er_ui_component_streq(slug, "button")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(button_variants);
    return button_variants;
  }
  if (er_ui_component_streq(slug, "button-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(orientation_variants);
    return orientation_variants;
  }
  if (er_ui_component_streq(slug, "separator")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(orientation_variants);
    return orientation_variants;
  }
  if (er_ui_component_streq(slug, "resizable")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(orientation_variants);
    return orientation_variants;
  }
  static const char* const card_variants[] = {"default", "sm"};
  if (er_ui_component_streq(slug, "card")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(card_variants);
    return card_variants;
  }
  if (er_ui_component_streq(slug, "direction")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(direction_variants);
    return direction_variants;
  }
  if (er_ui_component_streq(slug, "field")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "input")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "input-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "native-select")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "select")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "textarea")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(field_variants);
    return field_variants;
  }
  if (er_ui_component_streq(slug, "sheet")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(sheet_sides);
    return sheet_sides;
  }
  if (er_ui_component_streq(slug, "sonner")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(toast_variants);
    return toast_variants;
  }
  if (er_ui_component_streq(slug, "toast")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(toast_variants);
    return toast_variants;
  }
  static const char* const toggle_group_variants[] = {"single", "multiple"};
  if (er_ui_component_streq(slug, "toggle-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(toggle_group_variants);
    return toggle_group_variants;
  }
  *out_count = 0u;
  return no_variants;
}

static const char* const* er_ui_component_interactions_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  if (er_ui_component_streq(slug, "accordion")
    || er_ui_component_streq(slug, "collapsible")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(disclosure_interactions);
    return disclosure_interactions;
  }
  if (er_ui_component_streq(slug, "alert-dialog")
    || er_ui_component_streq(slug, "dialog")
    || er_ui_component_streq(slug, "drawer")
    || er_ui_component_streq(slug, "hover-card")
    || er_ui_component_streq(slug, "popover")
    || er_ui_component_streq(slug, "sheet")
    || er_ui_component_streq(slug, "tooltip")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(overlay_interactions);
    return overlay_interactions;
  }
  if (er_ui_component_streq(slug, "button")
    || er_ui_component_streq(slug, "button-group")
    || er_ui_component_streq(slug, "pagination")
    || er_ui_component_streq(slug, "toggle")
    || er_ui_component_streq(slug, "toggle-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(click_interactions);
    return click_interactions;
  }
  if (er_ui_component_streq(slug, "calendar")
    || er_ui_component_streq(slug, "carousel")
    || er_ui_component_streq(slug, "checkbox")
    || er_ui_component_streq(slug, "combobox")
    || er_ui_component_streq(slug, "command")
    || er_ui_component_streq(slug, "date-picker")
    || er_ui_component_streq(slug, "menubar")
    || er_ui_component_streq(slug, "navigation-menu")
    || er_ui_component_streq(slug, "radio-group")
    || er_ui_component_streq(slug, "select")
    || er_ui_component_streq(slug, "tabs")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(collection_interactions);
    return collection_interactions;
  }
  if (er_ui_component_streq(slug, "context-menu")
    || er_ui_component_streq(slug, "dropdown-menu")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(menu_interactions);
    return menu_interactions;
  }
  if (er_ui_component_streq(slug, "field")
    || er_ui_component_streq(slug, "input")
    || er_ui_component_streq(slug, "input-group")
    || er_ui_component_streq(slug, "input-otp")
    || er_ui_component_streq(slug, "native-select")
    || er_ui_component_streq(slug, "textarea")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(input_interactions);
    return input_interactions;
  }
  if (er_ui_component_streq(slug, "resizable")
    || er_ui_component_streq(slug, "slider")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(drag_interactions);
    return drag_interactions;
  }
  *out_count = ER_UI_COMPONENT_ARRAY_COUNT(static_interactions);
  return static_interactions;
}

static const char* const* er_ui_component_keyboard_for_slug(const char* slug, size_t* out_count) {
  if (!out_count) return 0;
  static const char* const enter_space_keyboard[] = {"Enter", "Space"};
  if (er_ui_component_streq(slug, "accordion")
    || er_ui_component_streq(slug, "button")
    || er_ui_component_streq(slug, "button-group")
    || er_ui_component_streq(slug, "checkbox")
    || er_ui_component_streq(slug, "collapsible")
    || er_ui_component_streq(slug, "toggle")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(enter_space_keyboard);
    return enter_space_keyboard;
  }
  if (er_ui_component_streq(slug, "alert-dialog")
    || er_ui_component_streq(slug, "dialog")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(dialog_keyboard);
    return dialog_keyboard;
  }
  if (er_ui_component_streq(slug, "context-menu")
    || er_ui_component_streq(slug, "dropdown-menu")
    || er_ui_component_streq(slug, "command")
    || er_ui_component_streq(slug, "combobox")
    || er_ui_component_streq(slug, "select")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(menu_keyboard);
    return menu_keyboard;
  }
  if (er_ui_component_streq(slug, "calendar")
    || er_ui_component_streq(slug, "carousel")
    || er_ui_component_streq(slug, "menubar")
    || er_ui_component_streq(slug, "navigation-menu")
    || er_ui_component_streq(slug, "pagination")
    || er_ui_component_streq(slug, "radio-group")
    || er_ui_component_streq(slug, "tabs")
    || er_ui_component_streq(slug, "toggle-group")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(horizontal_keyboard);
    return horizontal_keyboard;
  }
  if (er_ui_component_streq(slug, "date-picker")
    || er_ui_component_streq(slug, "drawer")
    || er_ui_component_streq(slug, "hover-card")
    || er_ui_component_streq(slug, "popover")
    || er_ui_component_streq(slug, "sheet")
    || er_ui_component_streq(slug, "tooltip")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(overlay_keyboard);
    return overlay_keyboard;
  }
  if (er_ui_component_streq(slug, "field")
    || er_ui_component_streq(slug, "input")
    || er_ui_component_streq(slug, "input-group")
    || er_ui_component_streq(slug, "native-select")
    || er_ui_component_streq(slug, "textarea")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(text_input_keyboard);
    return text_input_keyboard;
  }
  if (er_ui_component_streq(slug, "input-otp")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(input_otp_keyboard);
    return input_otp_keyboard;
  }
  if (er_ui_component_streq(slug, "resizable")
    || er_ui_component_streq(slug, "slider")) {
    *out_count = ER_UI_COMPONENT_ARRAY_COUNT(slider_keyboard);
    return slider_keyboard;
  }
  *out_count = 0u;
  return no_keyboard;
}

static const char* er_ui_component_aria_pattern_for_slug(const char* slug) {
  if (er_ui_component_streq(slug, "accordion")) return "accordion";
  if (er_ui_component_streq(slug, "alert")) return "alert";
  if (er_ui_component_streq(slug, "alert-dialog")) return "alertdialog";
  if (er_ui_component_streq(slug, "breadcrumb")) return "breadcrumb-navigation";
  if (er_ui_component_streq(slug, "button")) return "button";
  if (er_ui_component_streq(slug, "button-group")) return "button";
  if (er_ui_component_streq(slug, "toggle")) return "button";
  if (er_ui_component_streq(slug, "toggle-group")) return "button";
  if (er_ui_component_streq(slug, "calendar")) return "grid";
  if (er_ui_component_streq(slug, "date-picker")) return "grid";
  if (er_ui_component_streq(slug, "carousel")) return "region";
  if (er_ui_component_streq(slug, "chart")) return "figure";
  if (er_ui_component_streq(slug, "checkbox")) return "checkbox";
  if (er_ui_component_streq(slug, "collapsible")) return "disclosure";
  if (er_ui_component_streq(slug, "combobox")) return "combobox";
  if (er_ui_component_streq(slug, "command")) return "command-menu";
  if (er_ui_component_streq(slug, "context-menu")) return "menu";
  if (er_ui_component_streq(slug, "dropdown-menu")) return "menu";
  if (er_ui_component_streq(slug, "menubar")) return "menu";
  if (er_ui_component_streq(slug, "data-table")) return "table";
  if (er_ui_component_streq(slug, "table")) return "table";
  if (er_ui_component_streq(slug, "dialog")) return "dialog";
  if (er_ui_component_streq(slug, "drawer")) return "dialog";
  if (er_ui_component_streq(slug, "sheet")) return "dialog";
  if (er_ui_component_streq(slug, "field")) return "form-control";
  if (er_ui_component_streq(slug, "input")) return "form-control";
  if (er_ui_component_streq(slug, "input-group")) return "form-control";
  if (er_ui_component_streq(slug, "input-otp")) return "form-control";
  if (er_ui_component_streq(slug, "textarea")) return "form-control";
  if (er_ui_component_streq(slug, "hover-card")) return "non-modal-dialog";
  if (er_ui_component_streq(slug, "popover")) return "non-modal-dialog";
  if (er_ui_component_streq(slug, "navigation-menu")) return "navigation";
  if (er_ui_component_streq(slug, "pagination")) return "navigation";
  if (er_ui_component_streq(slug, "sidebar")) return "navigation";
  if (er_ui_component_streq(slug, "native-select")) return "listbox";
  if (er_ui_component_streq(slug, "select")) return "listbox";
  if (er_ui_component_streq(slug, "progress")) return "progressbar";
  if (er_ui_component_streq(slug, "radio-group")) return "radiogroup";
  if (er_ui_component_streq(slug, "resizable")) return "slider";
  if (er_ui_component_streq(slug, "slider")) return "slider";
  if (er_ui_component_streq(slug, "scroll-area")) return "scroll-region";
  if (er_ui_component_streq(slug, "separator")) return "separator";
  if (er_ui_component_streq(slug, "tabs")) return "tabs";
  if (er_ui_component_streq(slug, "toast")) return "status";
  if (er_ui_component_streq(slug, "sonner")) return "status";
  if (er_ui_component_streq(slug, "tooltip")) return "tooltip";
  return "presentation";
}

bool er_ui_component_parity_contract_for_slug(const char* slug, er_ui_component_parity_contract_t* out_contract) {
  if (!slug || !out_contract) return false;
  const er_ui_component_spec_t* spec = er_ui_component_find_by_slug(slug);
  if (!spec) return false;
  *out_contract = (er_ui_component_parity_contract_t){0};
  out_contract->slug = spec->slug;
  out_contract->slots = spec->slots;
  out_contract->slot_count = spec->slot_count;
  out_contract->states = spec->states;
  out_contract->state_count = spec->state_count;
  out_contract->variants = er_ui_component_variants_for_slug(spec->slug, &out_contract->variant_count);
  out_contract->interactions = er_ui_component_interactions_for_slug(spec->slug, &out_contract->interaction_count);
  out_contract->keyboard = er_ui_component_keyboard_for_slug(spec->slug, &out_contract->keyboard_count);
  out_contract->aria_pattern = er_ui_component_aria_pattern_for_slug(spec->slug);
  out_contract->compound = spec->slot_count > 1u;
  return true;
}

size_t er_ui_component_exact_parity_count(void) {
  size_t count = 0u;
  const er_ui_component_spec_t* component = component_catalog;
  const er_ui_component_spec_t* end = component_catalog + ER_UI_COMPONENT_COUNT;
  while (component < end) {
    er_ui_component_parity_contract_t contract = {0};
    if (component->status == ER_UI_COMPONENT_STATUS_EXACT_PORT
      && er_ui_component_parity_contract_for_slug(component->slug, &contract)) {
      count++;
    }
    component++;
  }
  return count;
}

bool er_ui_component_contract_supports_slot(const er_ui_component_parity_contract_t* contract, const char* slot) {
  return contract && er_ui_component_list_contains(contract->slots, contract->slot_count, slot);
}
bool er_ui_component_contract_supports_state(const er_ui_component_parity_contract_t* contract, const char* state) {
  return contract && er_ui_component_list_contains(contract->states, contract->state_count, state);
}
bool er_ui_component_contract_supports_variant(const er_ui_component_parity_contract_t* contract, const char* variant) {
  return contract && er_ui_component_list_contains(contract->variants, contract->variant_count, variant);
}
bool er_ui_component_contract_supports_interaction(
  const er_ui_component_parity_contract_t* contract,
  const char* interaction) {
  return contract && er_ui_component_list_contains(contract->interactions, contract->interaction_count, interaction);
}

const char* er_ui_component_selector(er_ui_component_test_id_t component) {
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT: return "edgerun.network_app_prompt";
    case ER_UI_COMPONENT_APP_STORE_CARD: return "edgerun.app_store_card";
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS: return "edgerun.trust_manager_actions";
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW: return "edgerun.runtime_event_row";
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW: return "edgerun.package_proof_row";
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW: return "edgerun.import_sync_source_row";
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW: return "edgerun.publish_from_node_row";
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW: return "edgerun.node_instance_row";
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW: return "edgerun.admission_policy_row";
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW: return "edgerun.route_budget_row";
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS: return "edgerun.data_table_controls";
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON: return "edgerun.icon_only_button";
    case ER_UI_COMPONENT_SEGMENTED_CONTROL: return "edgerun.segmented_control";
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW: return "edgerun.receipt_payment_row";
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW: return "edgerun.capability_grant_detail_row";
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL: return "edgerun.system_surface_state_panel";
    default: return "";
  }
}

const char* er_ui_component_name(er_ui_component_test_id_t component) {
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT: return "NetworkAppPrompt";
    case ER_UI_COMPONENT_APP_STORE_CARD: return "AppStoreCard";
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS: return "TrustManagerActions";
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW: return "RuntimeEventRow";
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW: return "PackageProofRow";
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW: return "ImportSyncSourceRow";
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW: return "PublishFromNodeRow";
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW: return "NodeInstanceRow";
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW: return "AdmissionPolicyRow";
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW: return "RouteBudgetRow";
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS: return "DataTableControls";
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON: return "IconOnlyButton";
    case ER_UI_COMPONENT_SEGMENTED_CONTROL: return "SegmentedControl";
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW: return "ReceiptPaymentRow";
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW: return "CapabilityGrantDetailRow";
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL: return "SystemSurfaceStatePanel";
    default: return "";
  }
}

const er_ui_component_test_id_t* er_ui_component_test_ids(size_t* out_count) {
  if (out_count) *out_count = sizeof(component_test_ids) / sizeof(component_test_ids[0]);
  return component_test_ids;
}

const char* er_ui_component_state_selector(er_ui_component_state_t state) {
  switch (state) {
    case ER_UI_COMPONENT_STATE_DEFAULT: return "state.default";
    case ER_UI_COMPONENT_STATE_HOVER: return "state.hover";
    case ER_UI_COMPONENT_STATE_FOCUS: return "state.focus";
    case ER_UI_COMPONENT_STATE_ACTIVE: return "state.active";
    case ER_UI_COMPONENT_STATE_DISABLED: return "state.disabled";
    case ER_UI_COMPONENT_STATE_LOADING: return "state.loading";
    case ER_UI_COMPONENT_STATE_ERROR: return "state.error";
    default: return "";
  }
}

const char* er_ui_component_state_label(er_ui_component_state_t state) {
  switch (state) {
    case ER_UI_COMPONENT_STATE_DEFAULT: return "Default";
    case ER_UI_COMPONENT_STATE_HOVER: return "Hover";
    case ER_UI_COMPONENT_STATE_FOCUS: return "Focus";
    case ER_UI_COMPONENT_STATE_ACTIVE: return "Active";
    case ER_UI_COMPONENT_STATE_DISABLED: return "Disabled";
    case ER_UI_COMPONENT_STATE_LOADING: return "Loading";
    case ER_UI_COMPONENT_STATE_ERROR: return "Error";
    default: return "";
  }
}

const er_ui_component_state_t* er_ui_component_states(size_t* out_count) {
  if (out_count) *out_count = ER_UI_COMPONENT_STATE_COUNT;
  return component_states;
}

const char* er_ui_component_a11y_role_label(er_ui_component_a11y_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_A11Y_GROUP: return "group";
    case ER_UI_COMPONENT_A11Y_BUTTON: return "button";
    case ER_UI_COMPONENT_A11Y_DIALOG: return "dialog";
    case ER_UI_COMPONENT_A11Y_LIST_ITEM: return "list-item";
    case ER_UI_COMPONENT_A11Y_STATUS: return "status";
    case ER_UI_COMPONENT_A11Y_TAB_LIST: return "tab-list";
    case ER_UI_COMPONENT_A11Y_GENERIC:
    default: return "generic";
  }
}

bool er_ui_component_state_matrix_for(
  er_ui_component_test_id_t component,
  er_ui_component_state_matrix_t* out_matrix) {
  if (!out_matrix || component >= ER_UI_COMPONENT_TEST_ID_COUNT) return false;
  out_matrix->component = component;
  out_matrix->states = component_states;
  out_matrix->state_count = ER_UI_COMPONENT_STATE_COUNT;
  return true;
}

bool er_ui_component_state_matrix_has_state(
  const er_ui_component_state_matrix_t* matrix,
  er_ui_component_state_t state) {
  if (!matrix || !matrix->states) return false;
  for (size_t i = 0u; i < matrix->state_count; ++i) {
    if (matrix->states[i] == state) return true;
  }
  return false;
}

//@optimizer-ignore-function component field metadata lookup is a fixed switch over known component ids
static bool er_ui_component_field_set_for(
  er_ui_component_test_id_t component,
  const er_ui_component_projected_field_t** out_fields,
  size_t* out_count) {
  if (!out_fields || !out_count) return false;
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT:
      ER_UI_COMPONENT_FIELD_SET(network_app_prompt_fields);
    case ER_UI_COMPONENT_APP_STORE_CARD:
      ER_UI_COMPONENT_FIELD_SET(app_store_card_fields);
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS:
      ER_UI_COMPONENT_FIELD_SET(trust_manager_action_fields);
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW:
      ER_UI_COMPONENT_FIELD_SET(runtime_event_row_fields);
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW:
      ER_UI_COMPONENT_FIELD_SET(package_proof_row_fields);
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW:
      ER_UI_COMPONENT_FIELD_SET(import_sync_source_row_fields);
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW:
      ER_UI_COMPONENT_FIELD_SET(publish_from_node_row_fields);
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW:
      ER_UI_COMPONENT_FIELD_SET(node_instance_row_fields);
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW:
      ER_UI_COMPONENT_FIELD_SET(admission_policy_row_fields);
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW:
      ER_UI_COMPONENT_FIELD_SET(route_budget_row_fields);
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS:
      ER_UI_COMPONENT_FIELD_SET(data_table_control_fields);
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON:
      ER_UI_COMPONENT_FIELD_SET(icon_only_button_fields);
    case ER_UI_COMPONENT_SEGMENTED_CONTROL:
      ER_UI_COMPONENT_FIELD_SET(segmented_control_fields);
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW:
      ER_UI_COMPONENT_FIELD_SET(receipt_payment_row_fields);
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW:
      ER_UI_COMPONENT_FIELD_SET(capability_grant_row_fields);
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL:
      ER_UI_COMPONENT_FIELD_SET(system_surface_state_panel_fields);
    default: return false;
  }
}

bool er_ui_component_projection_contract_for(
  er_ui_component_test_id_t component,
  er_ui_component_projection_contract_t* out_contract) {
  if (!out_contract) return false;
  const er_ui_component_projected_field_t* fields = 0;
  size_t field_count = 0u;
  //@optimizer-ignore component field metadata lookup is a fixed switch over known component ids
  if (!er_ui_component_field_set_for(component, &fields, &field_count)) return false;
  out_contract->component = component;
  out_contract->fields = fields;
  out_contract->field_count = field_count;
  return true;
}

bool er_ui_component_projection_contract_has_field(
  const er_ui_component_projection_contract_t* contract,
  const char* name) {
  if (!contract || !contract->fields || !name) return false;
  for (size_t i = 0u; i < contract->field_count; ++i) {
    if (er_ui_component_streq(contract->fields[i].name, name)) return true;
  }
  return false;
}

bool er_ui_component_projection_contract_requires_field(
  const er_ui_component_projection_contract_t* contract,
  const char* name) {
  if (!contract || !contract->fields || !name) return false;
  for (size_t i = 0u; i < contract->field_count; ++i) {
    if (contract->fields[i].required && er_ui_component_streq(contract->fields[i].name, name)) {
      return true;
    }
  }
  return false;
}

size_t er_ui_component_projection_required_field_count(const er_ui_component_projection_contract_t* contract) {
  if (!contract || !contract->fields) return 0u;
  size_t count = 0u;
  for (size_t i = 0u; i < contract->field_count; ++i) if (contract->fields[i].required) count++;
  return count;
}

//@optimizer-ignore-function component accessibility metadata lookup is a fixed switch over known component ids
static bool er_ui_component_accessibility_set_for(
  er_ui_component_test_id_t component,
  er_ui_component_a11y_role_t* out_role,
  const char* const** out_label_fields,
  size_t* out_count) {
  if (!out_role || !out_label_fields || !out_count) return false;
  switch (component) {
    case ER_UI_COMPONENT_NETWORK_APP_PROMPT:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_DIALOG, network_app_prompt_labels);
    case ER_UI_COMPONENT_APP_STORE_CARD:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, app_store_card_labels);
    case ER_UI_COMPONENT_TRUST_MANAGER_ACTIONS:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_GROUP, trust_manager_action_labels);
    case ER_UI_COMPONENT_RUNTIME_EVENT_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, runtime_event_row_labels);
    case ER_UI_COMPONENT_PACKAGE_PROOF_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, package_proof_row_labels);
    case ER_UI_COMPONENT_IMPORT_SYNC_SOURCE_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, import_sync_source_row_labels);
    case ER_UI_COMPONENT_PUBLISH_FROM_NODE_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, publish_from_node_row_labels);
    case ER_UI_COMPONENT_NODE_INSTANCE_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, node_instance_row_labels);
    case ER_UI_COMPONENT_ADMISSION_POLICY_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, admission_policy_row_labels);
    case ER_UI_COMPONENT_ROUTE_BUDGET_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, route_budget_row_labels);
    case ER_UI_COMPONENT_DATA_TABLE_CONTROLS:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_GROUP, data_table_control_labels);
    case ER_UI_COMPONENT_ICON_ONLY_BUTTON:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_BUTTON, icon_only_button_labels);
    case ER_UI_COMPONENT_SEGMENTED_CONTROL:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_TAB_LIST, segmented_control_labels);
    case ER_UI_COMPONENT_RECEIPT_PAYMENT_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, receipt_payment_row_labels);
    case ER_UI_COMPONENT_CAPABILITY_GRANT_DETAIL_ROW:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_LIST_ITEM, capability_grant_row_labels);
    case ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL:
      ER_UI_COMPONENT_A11Y_SET(ER_UI_COMPONENT_A11Y_STATUS, system_surface_state_panel_labels);
    default: return false;
  }
}

bool er_ui_component_accessibility_metadata_for(
  er_ui_component_test_id_t component,
  er_ui_component_accessibility_metadata_t* out_metadata) {
  if (!out_metadata) return false;
  er_ui_component_a11y_role_t role = ER_UI_COMPONENT_A11Y_GENERIC;
  const char* const* label_fields = 0;
  size_t label_field_count = 0u;
  //@optimizer-ignore component accessibility metadata lookup is a fixed switch over known component ids
  if (!er_ui_component_accessibility_set_for(component, &role, &label_fields, &label_field_count)) return false;
  out_metadata->component = component;
  out_metadata->role = role;
  out_metadata->label_fields = label_fields;
  out_metadata->label_field_count = label_field_count;
  return true;
}

bool er_ui_component_accessibility_metadata_has_label_field(
  const er_ui_component_accessibility_metadata_t* metadata,
  const char* name) {
  if (!metadata || !metadata->label_fields || !name) return false;
  return er_ui_component_list_contains(metadata->label_fields, metadata->label_field_count, name);
}

static bool er_ui_component_preview_select_id(uint32_t id) {
  return id == ER_UI_COMPONENT_SELECT_PREFERRED_CURRENCY_ID ||
         id == ER_UI_COMPONENT_SELECT_ORDER_TYPE_ID ||
         id == ER_UI_COMPONENT_SELECT_DEFAULT_CURRENCY_ID ||
         id == ER_UI_COMPONENT_SELECT_TICKER_ID;
}

static float er_ui_component_clamp01(float value) {
  return er_math_clamp01f(value);
}

static bool er_ui_component_gallery_set_slider(
  er_ui_component_gallery_state_t* state,
  uint32_t id,
  float value) {
  if (!state) return false;
  for (size_t i = 0u; i < state->slider_count; ++i) {
    if (state->sliders[i].id == id) {
      state->sliders[i].value = er_ui_component_clamp01(value);
      return true;
    }
  }
  if (state->slider_count >= ER_UI_COMPONENT_GALLERY_SLIDER_CAPACITY) return false;
  state->sliders[state->slider_count++] = (er_ui_component_slider_value_t){
    id,
    er_ui_component_clamp01(value)
  };
  return true;
}

void er_ui_component_gallery_state_init(er_ui_component_gallery_state_t* state) {
  if (!state) return;
  *state = (er_ui_component_gallery_state_t){0};
  state->contribution_bar = ER_UI_COMPONENT_CHART_CONTRIBUTION_DEFAULT_INDEX;
  state->stock_bar = ER_UI_COMPONENT_CHART_STOCK_DEFAULT_INDEX;
  state->power_bar = ER_UI_COMPONENT_CHART_POWER_DEFAULT_INDEX;
}

size_t er_ui_component_option_index(uint32_t id, uint32_t base, size_t len, bool* out_has_index) {
  if (out_has_index) *out_has_index = false;
  if (id < base) return 0u;
  uint32_t offset = id - base;
  if ((size_t)offset >= len) return 0u;
  if (out_has_index) *out_has_index = true;
  return (size_t)offset;
}

bool er_ui_component_gallery_apply_action(er_ui_component_gallery_state_t* state, er_ui_action_t action) {
  if (!state) return false;
  if (action.kind == ER_UI_ACTION_OPEN_CHANGED) {
    if (!er_ui_component_preview_select_id(action.id)) return false;
    state->has_open_select = action.bool_value;
    state->open_select = action.bool_value ? action.id : 0u;
    return true;
  }
  if (action.kind == ER_UI_ACTION_SLIDER_CHANGED) {
    return er_ui_component_gallery_set_slider(state, action.id, action.float_value);
  }
  if (action.kind != ER_UI_ACTION_ACTIVATED || !action.has_hit) return false;
  if (action.hit.kind == ER_UI_HIT_MENU_ITEM) {
    bool has_index = false;
    size_t index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_SELECT_CURRENCY_BASE_ID,
      ER_UI_COMPONENT_SELECT_CURRENCY_COUNT,
      &has_index);
    if (has_index) {
      state->currency_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_SELECT_ORDER_BASE_ID,
      ER_UI_COMPONENT_SELECT_ORDER_COUNT,
      &has_index);
    if (has_index) {
      state->order_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_SELECT_TICKER_BASE_ID,
      ER_UI_COMPONENT_SELECT_TICKER_COUNT,
      &has_index);
    if (has_index) {
      state->ticker_index = index;
      state->has_open_select = false;
      state->open_select = 0u;
      return true;
    }
  }
  if (action.hit.kind == ER_UI_HIT_BUTTON) {
    bool has_index = false;
    size_t index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_CHART_CONTRIBUTION_BASE_ID,
      ER_UI_COMPONENT_CHART_CONTRIBUTION_COUNT,
      &has_index);
    if (has_index) {
      state->contribution_bar = index;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_CHART_STOCK_BASE_ID,
      ER_UI_COMPONENT_CHART_STOCK_COUNT,
      &has_index);
    if (has_index) {
      state->stock_bar = index;
      return true;
    }
    index = er_ui_component_option_index(
      action.hit.id,
      ER_UI_COMPONENT_CHART_POWER_BASE_ID,
      ER_UI_COMPONENT_CHART_POWER_COUNT,
      &has_index);
    if (has_index) {
      state->power_bar = index;
      return true;
    }
  }
  return false;
}

bool er_ui_component_gallery_select_open(const er_ui_component_gallery_state_t* state, uint32_t id) {
  return state && state->has_open_select && state->open_select == id;
}

float er_ui_component_gallery_slider(const er_ui_component_gallery_state_t* state, uint32_t id, float fallback) {
  if (!state) return fallback;
  for (size_t i = 0u; i < state->slider_count; ++i) {
    if (state->sliders[i].id == id) return state->sliders[i].value;
  }
  return fallback;
}

bool er_ui_component_preview_available(const char* slug) {
  const er_ui_component_spec_t* spec = er_ui_component_find_by_slug(slug);
  return er_ui_component_has_native_renderer(spec);
}

bool er_ui_component_catalog_preview_available(const char* slug) {
  return er_ui_component_preview_available(slug);
}

bool er_ui_component_preview_available_by_source_component(const char* source_component) {
  const er_ui_component_spec_t* spec = er_ui_component_find_by_source_component(source_component);
  return er_ui_component_has_native_renderer(spec);
}

bool er_ui_component_preview_available_by_identifier(const char* identifier) {
  er_ui_component_resolved_t resolved = {0};
  if (!er_ui_component_resolve_identifier(identifier, &resolved)) return false;
  return er_ui_component_has_native_renderer(resolved.spec);
}

bool er_ui_component_catalog_preview_available_by_identifier(const char* identifier) {
  return er_ui_component_preview_available_by_identifier(identifier);
}

er_ui_bounds_t er_ui_component_button_bounds(er_ui_bounds_t bounds, er_ui_component_button_size_t size) {
  switch (size) {
    case ER_UI_COMPONENT_BUTTON_SIZE_SM: return er_ui_bounds_with_height_centered(bounds, 36.0f);
    case ER_UI_COMPONENT_BUTTON_SIZE_LG: return er_ui_bounds_with_height_centered(bounds, 44.0f);
    case ER_UI_COMPONENT_BUTTON_SIZE_ICON: {
      er_ui_bounds_t centered = er_ui_bounds_with_height_centered(bounds, 40.0f);
      return er_ui_bounds_with_width_centered(centered, 40.0f);
    }
    case ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT:
    default: return er_ui_bounds_with_height_centered(bounds, 40.0f);
  }
}

er_ui_status_t er_ui_component_card_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_card(&painter, bounds, theme);
}

er_ui_status_t er_ui_component_button_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  uint32_t id,
  er_ui_component_button_variant_t variant,
  er_ui_component_button_size_t size,
  bool active) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t rect = er_ui_component_button_bounds(bounds, size);
  er_ui_color4_t fill = er_ui_component_button_fill(theme, variant);
  if (!active) fill = er_ui_color_with_alpha(fill, fill.a * 0.74f);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, id, rect.x, rect.y, rect.w, rect.h));
  if (status != ER_UI_OK) return status;
  if (variant != ER_UI_COMPONENT_BUTTON_LINK) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(rect.x, rect.y, rect.w, rect.h, theme.radius.control, fill));
    if (status != ER_UI_OK) return status;
  }
  if (variant != ER_UI_COMPONENT_BUTTON_GHOST && variant != ER_UI_COMPONENT_BUTTON_LINK) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(rect.x, rect.y, rect.w, rect.h, theme.radius.control,
                                                           er_ui_color_with_alpha(er_ui_component_button_border(theme, variant), active ? 0.32f : 0.18f)));
    if (status != ER_UI_OK) return status;
  }
  float text_w = (float)er_ui_ascii_len(label) * 7.0f;
  float text_x = rect.x + (rect.w - text_w) * 0.5f;
  if (text_x < rect.x + 10.0f) text_x = rect.x + 10.0f;
  return er_ui_component_push_ascii_text(scene, font, label, text_x, rect.y + rect.h * 0.62f, er_ui_component_button_text(theme, variant));
}

static er_ui_status_t er_ui_component_labeled_control_frame(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_hit_kind_t hit_kind,
  uint32_t id,
  float control_h,
  er_ui_color4_t fill,
  float border_alpha,
  er_ui_bounds_t* out_control) {
  if (!scene || !font || !label || !out_control || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t control = er_ui_bounds(bounds.x, bounds.y + 18.0f, bounds.w, control_h);
  if (!er_ui_bounds_valid(control)) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_scene_push_hit(scene, er_ui_hit(hit_kind, id, control.x, control.y, control.w, control.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_fill_border(scene, control, theme.radius.control, fill,
                                       er_ui_color_with_alpha(theme.colors.border, border_alpha));
  if (status != ER_UI_OK) return status;
  *out_control = control;
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_select_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool open) {
  if (!scene || !font || !label || !value || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = open ? er_ui_color_with_alpha(theme.colors.active, 0.58f) : er_ui_color_with_alpha(theme.colors.row, 0.74f);
  er_ui_bounds_t control;
  er_ui_status_t status = er_ui_component_labeled_control_frame(
    scene, font, bounds, theme, label, ER_UI_HIT_SELECT, id, er_ui_float_min(bounds.h - 18.0f, 40.0f), fill, 0.40f, &control);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, value, control.x + 12.0f, control.y + 26.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_icon(scene, er_ui_bounds(control.x + control.w - 24.0f, control.y + (control.h - 16.0f) * 0.5f, 16.0f, 16.0f),
                                open ? ER_UI_ICON_X : ER_UI_ICON_CHEVRON_RIGHT, theme.colors.muted);
}

er_ui_status_t er_ui_component_slider_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  float value,
  uint32_t id) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float clamped = er_ui_component_clamp01(value);
  er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t track = er_ui_bounds(bounds.x, bounds.y + bounds.h - 18.0f, bounds.w, 6.0f);
  status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SLIDER, id, track.x, track.y - 12.0f, track.w, 30.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(track.x, track.y, track.w, track.h, 999.0f, er_ui_color_with_alpha(theme.colors.row, 0.86f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(track.x, track.y, track.w * clamped, track.h, 999.0f, theme.colors.accent));
  if (status != ER_UI_OK) return status;
  float thumb_x = track.x + track.w * clamped - 7.0f;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(thumb_x, track.y - 5.0f, 16.0f, 16.0f, 8.0f, theme.colors.accent_text));
}

er_ui_status_t er_ui_component_badge_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_component_badge_variant_t variant) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = er_ui_component_badge_fill(theme, variant);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, fill));
  if (status != ER_UI_OK) return status;
  if (variant == ER_UI_COMPONENT_BADGE_OUTLINE) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, er_ui_color_with_alpha(theme.colors.border, 0.52f)));
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_push_ascii_text(scene, font, label, bounds.x + 10.0f, bounds.y + bounds.h * 0.64f, er_ui_component_badge_text(theme, variant));
}

er_ui_status_t er_ui_component_field_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  uint32_t id,
  bool text_area) {
  if (!scene || !font || !label || !value || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_hit_kind_t hit_kind = text_area ? ER_UI_HIT_TEXT_AREA : ER_UI_HIT_INPUT;
  er_ui_bounds_t control;
  er_ui_status_t status = er_ui_component_labeled_control_frame(
    scene,
    font,
    bounds,
    theme,
    label,
    hit_kind,
    id,
    er_ui_float_max(bounds.h - 18.0f, 24.0f),
    er_ui_color_with_alpha(theme.colors.row, 0.62f),
    0.44f,
    &control);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, value, control.x + 12.0f, control.y + 25.0f, theme.colors.text);
}

er_ui_status_t er_ui_component_checkbox_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool checked,
  uint32_t id) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t box = er_ui_bounds(bounds.x, bounds.y + (bounds.h - 18.0f) * 0.5f, 18.0f, 18.0f);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_CHECKBOX, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(box.x, box.y, box.w, box.h, 4.0f, checked ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.row, 0.74f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(box.x, box.y, box.w, box.h, 4.0f, checked ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.border, 0.54f)));
  if (status != ER_UI_OK) return status;
  if (checked) {
    status = er_ui_component_push_icon(scene, er_ui_bounds(box.x + 3.0f, box.y + 3.0f, 12.0f, 12.0f), ER_UI_ICON_CHECK, theme.colors.accent_text);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_push_ascii_text(scene, font, label, bounds.x + 28.0f, bounds.y + bounds.h * 0.62f, theme.colors.text);
}

er_ui_status_t er_ui_component_progress_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, float value) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float clamped = er_ui_component_clamp01(value);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, er_ui_color_with_alpha(theme.colors.row, 0.86f)));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w * clamped, bounds.h, theme.radius.pill, theme.colors.accent));
}

er_ui_status_t er_ui_component_switch_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, bool checked, uint32_t id) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TOGGLE, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  er_ui_color4_t fill = checked ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.row, 0.84f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, fill));
  if (status != ER_UI_OK) return status;
  float thumb = er_ui_float_min(bounds.h - 6.0f, 20.0f);
  float thumb_x = checked ? bounds.x + bounds.w - thumb - 3.0f : bounds.x + 3.0f;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(thumb_x, bounds.y + (bounds.h - thumb) * 0.5f, thumb, thumb, thumb * 0.5f, theme.colors.accent_text));
}

er_ui_status_t er_ui_component_separator_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, er_ui_color_with_alpha(theme.colors.border, 0.56f)));
}

er_ui_status_t er_ui_component_tabs_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id) {
  if (!scene || !font || (!labels && label_count > 0u) || !er_ui_bounds_valid(bounds) || label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.42f)));
  if (status != ER_UI_OK) return status;
  float tab_w = bounds.w / (float)label_count;
  const char* const* label_cursor = labels;
  for (size_t i = 0u; i < label_count; ++i) {
    const char* label = *label_cursor;
    er_ui_bounds_t tab = er_ui_bounds(bounds.x + tab_w * (float)i, bounds.y, tab_w, bounds.h);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TAB, base_id + (uint32_t)i, tab.x, tab.y, tab.w, tab.h));
    if (status != ER_UI_OK) return status;
    if (i == selected) {
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tab.x + 3.0f, tab.y + 3.0f, tab.w - 6.0f, tab.h - 6.0f, theme.radius.control, theme.colors.panel));
      if (status != ER_UI_OK) return status;
    }
    status = er_ui_component_push_ascii_text(scene, font, label, tab.x + 12.0f, tab.y + tab.h * 0.62f, i == selected ? theme.colors.text : theme.colors.muted);
    if (status != ER_UI_OK) return status;
    label_cursor++;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_list_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail,
  uint32_t id,
  bool selected) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = selected ? er_ui_color_with_alpha(theme.colors.active, 0.54f) : er_ui_color_with_alpha(theme.colors.row, 0.34f);
  return er_ui_component_row_body_emit(scene, font, bounds, theme, ER_UI_HIT_LIST_ROW, id, true, title, detail, theme.radius.control, fill,
                                       20.0f, 40.0f);
}

er_ui_status_t er_ui_component_radio_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  bool selected,
  uint32_t id) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t dot = er_ui_bounds(bounds.x, bounds.y + (bounds.h - 18.0f) * 0.5f, 18.0f, 18.0f);
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_RADIO, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(dot.x, dot.y, dot.w, dot.h, 9.0f, selected ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.border, 0.58f)));
  if (status != ER_UI_OK) return status;
  if (selected) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(dot.x + 5.0f, dot.y + 5.0f, 8.0f, 8.0f, 4.0f, theme.colors.accent));
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_push_ascii_text(scene, font, label, bounds.x + 28.0f, bounds.y + bounds.h * 0.62f, theme.colors.text);
}

//@optimizer-ignore-function table rendering must visit each visible row and column cell
er_ui_status_t er_ui_component_table_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* headers,
  size_t header_count,
  const char* const* cells,
  size_t row_count,
  uint32_t id_base) {
  if (!scene || !font || !headers || !cells || header_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float col_w = (bounds.w - 24.0f) / (float)header_count;
  float y = bounds.y + 24.0f;
  for (size_t h = 0u; h < header_count; ++h) {
    status = er_ui_component_push_ascii_text(scene, font, headers[h], bounds.x + 12.0f + col_w * (float)h, y, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x + 10.0f, bounds.y + 34.0f, bounds.w - 20.0f, 1.0f), theme);
  if (status != ER_UI_OK) return status;
  for (size_t r = 0u; r < row_count; ++r) {
    er_ui_bounds_t row = er_ui_bounds(bounds.x + 8.0f, bounds.y + 42.0f + (float)r * 28.0f, bounds.w - 16.0f, 26.0f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TRANSACTION_ROW, id_base + (uint32_t)r, row.x, row.y, row.w, row.h));
    if (status != ER_UI_OK) return status;
    for (size_t h = 0u; h < header_count; ++h) {
      const char* value = cells[r * header_count + h];
      status = er_ui_component_push_ascii_text(scene, font, value, bounds.x + 12.0f + col_w * (float)h, row.y + 18.0f, theme.colors.text);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_skeleton_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.64f)));
}

er_ui_status_t er_ui_component_toast_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* message,
  er_ui_color4_t accent) {
  if (!scene || !font || !message || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_icon_tile(scene, er_ui_bounds(bounds.x + 10.0f, bounds.y + (bounds.h - 28.0f) * 0.5f, 28.0f, 28.0f), theme,
                                  ER_UI_ICON_BELL, accent);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, message, bounds.x + 48.0f, bounds.y + bounds.h * 0.60f, theme.colors.text);
}

er_ui_status_t er_ui_component_empty_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body) {
  if (!scene || !font || !title || !body || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + (bounds.w - 44.0f) * 0.5f, bounds.y, 44.0f, 44.0f, 22.0f,
                                                                     er_ui_color_with_alpha(theme.colors.row, 0.62f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, title, bounds.x + 10.0f, bounds.y + 70.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, body, bounds.x + 10.0f, bounds.y + 94.0f, theme.colors.muted);
}

er_ui_status_t er_ui_component_tooltip_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* text) {
  if (!scene || !font || !text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_fill_border(scene, bounds, theme.radius.card, theme.colors.topbar,
                                                      er_ui_color_with_alpha(theme.colors.border, 0.72f));
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, text, bounds.x + 10.0f, bounds.y + bounds.h * 0.62f, theme.colors.text);
}

er_ui_status_t er_ui_component_dialog_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body,
  er_ui_color4_t accent) {
  if (!scene || !font || !title || !body || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_icon_tile(scene, er_ui_bounds(bounds.x + 18.0f, bounds.y + 18.0f, 34.0f, 34.0f), theme, ER_UI_ICON_WARNING, accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, title, bounds.x + 64.0f, bounds.y + 32.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, body, bounds.x + 64.0f, bounds.y + 56.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x + 18.0f, bounds.y + 74.0f, bounds.w - 36.0f, 1.0f), theme);
}

er_ui_status_t er_ui_component_progress_ring_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, float value, er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float size = er_ui_float_min(bounds.w, bounds.h);
  float x = bounds.x + (bounds.w - size) * 0.5f;
  float y = bounds.y + (bounds.h - size) * 0.5f;
  float t = er_ui_float_max(size * 0.10f, 2.0f);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_border(x, y, size, size, size * 0.5f, er_ui_color_with_alpha(theme.colors.border, 0.70f)));
  if (status != ER_UI_OK) return status;
  float clamped = er_ui_float_clamp(value, 0.0f, 1.0f);
  const struct { float x; float y; } points[] = {
    {0.50f, 0.06f}, {0.70f, 0.10f}, {0.84f, 0.24f}, {0.90f, 0.44f},
    {0.84f, 0.64f}, {0.70f, 0.80f}, {0.50f, 0.86f}, {0.30f, 0.80f},
    {0.16f, 0.64f}, {0.10f, 0.44f}, {0.16f, 0.24f}, {0.30f, 0.10f},
  };
  const size_t point_count = ER_UI_COMPONENT_ARRAY_COUNT(points);
  size_t segments = (size_t)(clamped * (float)point_count + 0.5f);
  for (size_t i = 0u; i < segments && i < point_count; ++i) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(x + size * points[i].x - t * 0.5f, y + size * points[i].y - t * 0.5f, t, t, t * 0.5f, color));
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_alert_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* body,
  er_ui_color4_t accent) {
  if (!scene || !font || !title || !body || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_fill_border(scene, bounds, theme.radius.card, er_ui_color_with_alpha(theme.colors.row, 0.28f),
                                                      er_ui_color_with_alpha(theme.colors.border, 0.46f));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_icon(scene, er_ui_bounds(bounds.x + 12.0f, bounds.y + 14.0f, 16.0f, 16.0f), ER_UI_ICON_WARNING, accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, title, bounds.x + 34.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, body, bounds.x + 34.0f, bounds.y + 46.0f, theme.colors.muted);
}

er_ui_status_t er_ui_component_avatar_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  er_ui_color4_t color,
  bool online) {
  if (!scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float size = er_ui_float_min(bounds.w, bounds.h);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, size, size, size * 0.5f, er_ui_color_with_alpha(color, 0.54f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, label, bounds.x + size * 0.30f, bounds.y + size * 0.62f, color);
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + size - 8.0f, bounds.y + size - 8.0f, 8.0f, 8.0f, 4.0f,
                                                     online ? theme.colors.success : theme.colors.muted));
}

er_ui_status_t er_ui_component_breadcrumb_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id) {
  if (!scene || !font || (!labels && label_count > 0u) || label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float x = bounds.x;
  const char* const* label_cursor = labels;
  for (size_t i = 0u; i < label_count; ++i) {
    const char* label = *label_cursor;
    er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BREADCRUMB, base_id + (uint32_t)i, x, bounds.y, 96.0f, bounds.h));
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, label, x, bounds.y + bounds.h * 0.62f, i == selected ? theme.colors.text : theme.colors.muted);
    if (status != ER_UI_OK) return status;
    x += 82.0f;
    label_cursor++;
    if (i + 1u < label_count) {
      status = er_ui_component_push_ascii_text(scene, font, "/", x - 18.0f, bounds.y + bounds.h * 0.62f, theme.colors.muted);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_command_palette_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* placeholder,
  uint32_t id) {
  if (!scene || !font || !placeholder || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_INPUT, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_fill_border(scene, bounds, theme.radius.control, theme.colors.composer, er_ui_color_with_alpha(theme.colors.border, 0.54f));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_icon(scene, er_ui_bounds(bounds.x + 14.0f, bounds.y + (bounds.h - 16.0f) * 0.5f, 16.0f, 16.0f),
                                  ER_UI_ICON_SEARCH, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, placeholder, bounds.x + 44.0f, bounds.y + bounds.h * 0.62f, theme.colors.muted);
}

er_ui_status_t er_ui_component_tree_item_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  uint8_t depth,
  bool expanded,
  uint32_t id) {
  if (!scene || !font || !label || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TREE_ITEM, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  float indent = 12.0f + (float)depth * 18.0f;
  status = er_ui_component_push_icon(scene, er_ui_bounds(bounds.x + indent, bounds.y + (bounds.h - 16.0f) * 0.5f, 16.0f, 16.0f),
                                  expanded ? ER_UI_ICON_CHEVRON_RIGHT : ER_UI_ICON_FILE, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_text_pair(scene, font, label, bounds.x + indent + 24.0f, bounds.y + bounds.h * 0.45f, theme.colors.text,
                                        detail, bounds.x + bounds.w * 0.58f, bounds.y + bounds.h * 0.45f, theme.colors.muted, true);
}

er_ui_status_t er_ui_component_section_header_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* detail) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_push_text_pair(scene, font, title, bounds.x, bounds.y + 18.0f, theme.colors.text,
                                                         detail, bounds.x + bounds.w * 0.58f, bounds.y + 18.0f, theme.colors.muted, true);
  if (status != ER_UI_OK) return status;
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_identity_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* node,
  const char* policy,
  uint32_t id) {
  if (!scene || !font || !name || !node || !policy || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_component_badged_icon_card_emit(scene, font, bounds, theme, id, name, node, policy, ER_UI_ICON_SHIELD,
                                               theme.colors.accent, 34.0f, 62.0f, 30.0f, 53.0f);
}

er_ui_status_t er_ui_component_contact_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* detail,
  uint32_t id) {
  if (!scene || !font || !name || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x + 12.0f, bounds.y + 12.0f, 36.0f, 36.0f), theme, name, theme.colors.accent, true);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_text_pair(scene, font, name, bounds.x + 58.0f, bounds.y + 27.0f, theme.colors.text,
                                        detail, bounds.x + 58.0f, bounds.y + 49.0f, theme.colors.muted, true);
}

er_ui_status_t er_ui_component_thread_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* last_message,
  bool unread,
  uint32_t id) {
  if (!scene || !font || !title || !last_message || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = unread ? er_ui_color_with_alpha(theme.colors.active, 0.58f) : theme.colors.panel;
  er_ui_component_icon_text_row_t row = er_ui_component_icon_text_row(
    ER_UI_HIT_LIST_ROW, id, theme.radius.card, fill, ER_UI_ICON_CHAT,
    unread ? theme.colors.accent : theme.colors.muted, bounds, 14.0f, ER_UI_COMPONENT_ICON_ROW_TEXT_X,
    ER_UI_COMPONENT_ICON_ROW_TITLE_Y, ER_UI_COMPONENT_ICON_ROW_DETAIL_Y, false, false);
  return er_ui_component_icon_text_row_emit(scene, font, bounds, theme, &row, title, last_message);
}

er_ui_status_t er_ui_component_attachment_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* kind,
  uint32_t id) {
  if (!scene || !font || !name || !kind || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_component_icon_text_row_t row = er_ui_component_icon_text_row(
    ER_UI_HIT_LIST_ROW, id, theme.radius.card, theme.colors.row, ER_UI_ICON_FILE, theme.colors.accent, bounds,
    12.0f, 52.0f, 25.0f, 47.0f, true, false);
  return er_ui_component_icon_text_row_emit(scene, font, bounds, theme, &row, name, kind);
}

er_ui_status_t er_ui_component_capability_grant_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* app,
  const char* capability,
  const char* state,
  uint32_t id) {
  if (!scene || !font || !app || !capability || !state || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_component_icon_text_row_t row = er_ui_component_icon_text_row(
    ER_UI_HIT_LIST_ROW, id, 0.0f, theme.colors.panel, ER_UI_ICON_KEY, theme.colors.info, bounds,
    ER_UI_COMPONENT_ICON_ROW_TILE_Y, ER_UI_COMPONENT_ICON_ROW_TEXT_X, ER_UI_COMPONENT_ICON_ROW_TITLE_Y,
    ER_UI_COMPONENT_ICON_ROW_DETAIL_Y, false, false);
  er_ui_status_t status = er_ui_component_icon_text_row_emit(scene, font, bounds, theme, &row, app, capability);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + bounds.w - 96.0f, bounds.y + 18.0f, 84.0f, 24.0f), theme, state, ER_UI_COMPONENT_BADGE_DEFAULT);
  if (status != ER_UI_OK) return status;
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_proof_event_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* hash,
  const char* status_text,
  uint32_t id) {
  if (!scene || !font || !title || !hash || !status_text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_component_icon_text_row_t row = er_ui_component_icon_text_row(
    ER_UI_HIT_LIST_ROW, id, 0.0f, theme.colors.panel, ER_UI_ICON_CHECK, theme.colors.success, bounds,
    ER_UI_COMPONENT_ICON_ROW_TILE_Y, ER_UI_COMPONENT_ICON_ROW_TEXT_X, ER_UI_COMPONENT_ICON_ROW_TITLE_Y,
    ER_UI_COMPONENT_ICON_ROW_DETAIL_Y, false, false);
  er_ui_status_t status = er_ui_component_icon_text_row_emit(scene, font, bounds, theme, &row, title, hash);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + bounds.w - 96.0f, bounds.y + 18.0f, 84.0f, 24.0f), theme, status_text, ER_UI_COMPONENT_BADGE_DEFAULT);
  if (status != ER_UI_OK) return status;
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_route_path_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* const* hops,
  size_t hop_count) {
  if (!scene || !font || !label || (!hops && hop_count > 0u) || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, label, bounds.x + 14.0f, bounds.y + 24.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  float x = bounds.x + 16.0f;
  float y = bounds.y + 45.0f;
  const char* const* hop_cursor = hops;
  for (size_t i = 0u; i < hop_count; ++i) {
    const char* hop = *hop_cursor;
    if (x > bounds.x + bounds.w - 80.0f) break;
    status = er_ui_component_icon_tile(scene, er_ui_bounds(x, y, 22.0f, 22.0f), theme,
                                    i == 0u ? ER_UI_ICON_APP : (i + 1u == hop_count ? ER_UI_ICON_NETWORK : ER_UI_ICON_ROUTE),
                                    theme.colors.accent);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, hop, x + 28.0f, y + 18.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    x += 112.0f;
    hop_cursor++;
    if (i + 1u < hop_count) {
      status = er_ui_component_push_icon(scene, er_ui_bounds(x - 25.0f, y + 3.0f, 16.0f, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.muted);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_package_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* name,
  const char* policy,
  const char* hash,
  uint32_t id) {
  if (!scene || !font || !name || !policy || !hash || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_component_badged_icon_card_emit(scene, font, bounds, theme, id, name, hash, policy, ER_UI_ICON_APP,
                                               theme.colors.accent, 30.0f, 58.0f, 30.0f, 53.0f);
}

er_ui_status_t er_ui_component_receipt_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* amount,
  const char* status_text,
  uint32_t id) {
  if (!scene || !font || !label || !amount || !status_text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TRANSACTION_ROW, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_icon_tile(scene, er_ui_bounds(bounds.x + 12.0f, bounds.y + 15.0f, 28.0f, 28.0f), theme, ER_UI_ICON_WALLET, theme.colors.success);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, label, bounds.x + 48.0f, bounds.y + 34.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, status_text, bounds.x + bounds.w - 150.0f, bounds.y + 34.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, amount, bounds.x + bounds.w - 76.0f, bounds.y + 34.0f, theme.colors.success);
  if (status != ER_UI_OK) return status;
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_panel_header_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* subtitle,
  const char* action_label,
  uint32_t action_id) {
  if (!scene || !font || !title || !subtitle || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_push_text_pair(scene, font, title, bounds.x, bounds.y + 20.0f, theme.colors.text,
                                                         subtitle, bounds.x, bounds.y + 40.0f, theme.colors.muted, false);
  if (status != ER_UI_OK) return status;
  if (action_label && er_ui_ascii_len(action_label) > 0u) {
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + bounds.w - 96.0f, bounds.y + 4.0f, 96.0f, 36.0f), theme, action_label, action_id,
                                      ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_metric_card_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* value,
  const char* detail,
  bool has_progress,
  float progress,
  er_ui_color4_t accent) {
  if (!scene || !font || !title || !value || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_text_pair(scene, font, title, bounds.x + 14.0f, bounds.y + 24.0f, theme.colors.muted,
                                          value, bounds.x + 14.0f, bounds.y + 56.0f, theme.colors.text, true);
  if (status != ER_UI_OK) return status;
  if (detail[0]) {
    status = er_ui_component_push_ascii_text(scene, font, detail, bounds.x + 14.0f, bounds.y + 82.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  if (has_progress) {
    return er_ui_component_progress_emit(scene, er_ui_bounds(bounds.x + 14.0f, bounds.y + bounds.h - 18.0f, bounds.w - 28.0f, 8.0f),
                                      theme, progress);
  }
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x + bounds.w - 28.0f, bounds.y + 16.0f, 12.0f, 12.0f, 6.0f, accent));
}

er_ui_status_t er_ui_component_transaction_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* subtitle,
  const char* date,
  const char* amount,
  bool positive,
  uint32_t id) {
  if (!scene || !font || !title || !subtitle || !date || !amount || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_row_body_emit(scene, font, bounds, theme, ER_UI_HIT_TRANSACTION_ROW, id, true, title, subtitle, 0.0f,
                                                     theme.colors.panel, 22.0f, 44.0f);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, date, bounds.x + bounds.w - 170.0f, bounds.y + 22.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, amount, bounds.x + bounds.w - 86.0f, bounds.y + 34.0f, positive ? theme.colors.success : theme.colors.danger);
  if (status != ER_UI_OK) return status;
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_menu_item_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  const char* badge,
  bool selected,
  er_ui_color4_t accent,
  uint32_t id) {
  if (!scene || !font || !label || !detail || !badge || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = selected ? er_ui_color_with_alpha(accent, 0.18f) : theme.colors.panel;
  er_ui_status_t status = er_ui_component_row_body_emit(scene, font, bounds, theme, ER_UI_HIT_MENU_ITEM, id, true, label, detail, theme.radius.control, fill,
                                                        22.0f, 44.0f);
  if (status != ER_UI_OK) return status;
  if (badge[0]) {
    return er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + bounds.w - 84.0f, bounds.y + 17.0f, 72.0f, 24.0f), theme, badge,
                                   ER_UI_COMPONENT_BADGE_SECONDARY);
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_component_control_row_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* detail,
  const char* accessory,
  uint32_t id) {
  if (!scene || !font || !label || !detail || !accessory || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_row_body_emit(scene, font, bounds, theme, ER_UI_HIT_LIST_ROW, id, id != 0u, label, detail, 0.0f,
                                                     theme.colors.panel, 22.0f, 44.0f);
  if (status != ER_UI_OK) return status;
  if (accessory[0]) {
    status = er_ui_component_push_ascii_text(scene, font, accessory, bounds.x + bounds.w - 116.0f, bounds.y + 34.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_bottom_separator_emit(scene, bounds, theme);
}

er_ui_status_t er_ui_component_bar_chart_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* title,
  const char* const* labels,
  const float* values,
  size_t value_count,
  uint32_t base_id,
  size_t selected) {
  if (!scene || !font || !title || !labels || !values || value_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, title, bounds.x, bounds.y + 14.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  float gap = 8.0f;
  float bar_w = (bounds.w - gap * (float)(value_count - 1u)) / (float)value_count;
  if (bar_w < 4.0f) bar_w = 4.0f;
  float base_y = bounds.y + bounds.h - 22.0f;
  float max_h = er_ui_float_max(bounds.h - 48.0f, 8.0f);
  const char* const* label_cursor = labels;
  const float* value_cursor = values;
  for (size_t i = 0u; i < value_count; ++i) {
    const char* label = *label_cursor;
    float v = er_ui_component_clamp01(*value_cursor);
    float h = er_ui_float_max(max_h * v, 2.0f);
    float x = bounds.x + (bar_w + gap) * (float)i;
    er_ui_color4_t fill = i == selected ? theme.colors.accent : er_ui_color_with_alpha(theme.colors.accent, 0.48f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, base_id + (uint32_t)i, x, base_y - h, bar_w, h));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(x, base_y - h, bar_w, h, 4.0f, fill));
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, label, x, base_y + 14.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    label_cursor++;
    value_cursor++;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_network_app_prompt_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* app_name,
  const char* package_size,
  const char* retrieval_cost,
  const char* policy_hash,
  uint32_t run_once_id,
  uint32_t verify_cache_id,
  uint32_t cancel_id) {
  if (!scene || !font || !app_name || !package_size || !retrieval_cost) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!policy_hash || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t icon = er_ui_bounds(bounds.x + 20.0f, bounds.y + 20.0f, 38.0f, 38.0f);
  status = er_ui_component_icon_tile(scene, icon, theme, ER_UI_ICON_NETWORK, theme.colors.accent);
  if (status != ER_UI_OK) return status;

  const char* title = app_name[0] ? app_name : "Network app";
  status = er_ui_component_push_ascii_text(scene, font, title, bounds.x + 70.0f, bounds.y + 34.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 70.0f, bounds.y + 46.0f, 118.0f, 24.0f), theme, "Network Storage",
                                   ER_UI_COMPONENT_BADGE_SECONDARY);
  if (status != ER_UI_OK) return status;

  float text_x = bounds.x + 22.0f;
  float y = bounds.y + 96.0f;
  status = er_ui_component_push_ascii_text(scene, font, "Signed package bytes are retrieved, verified, and run locally.", text_x, y, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  y += 24.0f;
  status = er_ui_component_push_ascii_text(scene, font, "Cache verified bytes to avoid repeated retrieval payments.", text_x, y, theme.colors.muted);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t meta = er_ui_bounds(bounds.x + 20.0f, bounds.y + bounds.h - 118.0f, bounds.w - 40.0f, 54.0f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(meta.x, meta.y, meta.w, meta.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.46f)));
  if (status != ER_UI_OK) return status;
  if (package_size[0]) {
    status = er_ui_component_push_ascii_text(scene, font, package_size, meta.x + 12.0f, meta.y + 22.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
  }
  if (retrieval_cost[0]) {
    status = er_ui_component_push_ascii_text(scene, font, retrieval_cost, meta.x + meta.w * 0.38f, meta.y + 22.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
  }
  if (policy_hash[0]) {
    status = er_ui_component_push_ascii_text(scene, font, policy_hash, meta.x + 12.0f, meta.y + 44.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }

  float gap = 10.0f;
  float button_y = bounds.y + bounds.h - 48.0f;
  er_ui_bounds_t cancel = er_ui_bounds(bounds.x + bounds.w - 82.0f - 20.0f, button_y, 82.0f, 36.0f);
  er_ui_bounds_t cache = er_ui_bounds(cancel.x - gap - 142.0f, button_y, 142.0f, 36.0f);
  er_ui_bounds_t run = er_ui_bounds(cache.x - gap - 102.0f, button_y, 102.0f, 36.0f);
  if (run.x < bounds.x + 20.0f) {
    run = er_ui_bounds(bounds.x + 20.0f, button_y, 96.0f, 36.0f);
    cache = er_ui_bounds(run.x + run.w + gap, button_y, 132.0f, 36.0f);
    cancel = er_ui_bounds(cache.x + cache.w + gap, button_y, 78.0f, 36.0f);
  }

  status = er_ui_component_button_emit(scene, font, run, theme, "Run once", run_once_id, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_button_emit(scene, font, cache, theme, "Verify & cache", verify_cache_id, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, cancel, theme, "Cancel", cancel_id, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
}

bool er_ui_component_scene_preview_available(const char* slug) {
  return er_ui_component_find_by_slug(slug) != 0;
}

er_ui_status_t er_ui_component_scene_preview_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* slug,
  const er_ui_component_gallery_state_t* state) {
  if (!scene || !font || !slug || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_component_streq(slug, "accordion")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 110.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Is it accessible?", bounds.x + 14.0f, bounds.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Yes. It follows the WAI-ARIA design pattern.", bounds.x + 14.0f, bounds.y + 50.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x + 12.0f, bounds.y + 64.0f, er_ui_float_min(bounds.w, 360.0f) - 24.0f, 1.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Is it styled?", bounds.x + 14.0f, bounds.y + 88.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "alert")) {
    return er_ui_component_alert_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 390.0f), 76.0f), theme, "Heads up",
                                   "You can add components to your app using the CLI.", theme.colors.warning);
  }
  if (er_ui_component_streq(slug, "alert-dialog") || er_ui_component_streq(slug, "dialog")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 150.0f), theme);
    if (status != ER_UI_OK) return status;
    const char* title = er_ui_component_streq(slug, "alert-dialog") ? "Are you absolutely sure?" : "Edit profile";
    const char* body = er_ui_component_streq(slug, "alert-dialog") ? "This action cannot be undone." : "Make changes to your profile here.";
    status = er_ui_component_push_ascii_text(scene, font, title, bounds.x + 18.0f, bounds.y + 32.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, body, bounds.x + 18.0f, bounds.y + 56.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 160.0f, bounds.y + 96.0f, 80.0f, 40.0f), theme, "Cancel",
                                      ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CANCEL_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 248.0f, bounds.y + 96.0f, 84.0f, 40.0f), theme, "Confirm",
                                    ER_UI_COMPONENT_PREVIEW_ALERT_DIALOG_CONFIRM_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "aspect-ratio")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 146.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(card.x + 12.0f, card.y + 12.0f, card.w - 24.0f, card.h - 24.0f, theme.radius.control,
                                                         er_ui_color_with_alpha(theme.colors.row, 0.52f)));
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "16:9", card.x + card.w * 0.45f, card.y + card.h * 0.56f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "avatar")) {
    er_ui_status_t status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 42.0f, 42.0f), theme, "CN", theme.colors.accent, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x + 52.0f, bounds.y, 42.0f, 42.0f), theme, "ER", theme.colors.success, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x + 104.0f, bounds.y, 42.0f, 42.0f), theme, "UI", theme.colors.info, false);
  }
  if (er_ui_component_streq(slug, "badge")) {
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 82.0f, 26.0f), theme, "Default", ER_UI_COMPONENT_BADGE_DEFAULT);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 92.0f, bounds.y, 96.0f, 26.0f), theme, "Secondary", ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    return er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 34.0f, 112.0f, 26.0f), theme, "Destructive", ER_UI_COMPONENT_BADGE_DESTRUCTIVE);
  }
  if (er_ui_component_streq(slug, "button")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 96.0f, 42.0f), theme, "Button",
                                                     ER_UI_COMPONENT_PREVIEW_BUTTON_DEFAULT_ID,
                                                     ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 106.0f, bounds.y, 116.0f, 42.0f), theme, "Secondary",
                                      ER_UI_COMPONENT_PREVIEW_BUTTON_SECONDARY_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 232.0f, bounds.y, 86.0f, 42.0f), theme, "Ghost",
                                    ER_UI_COMPONENT_PREVIEW_BUTTON_GHOST_ID, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
  }
  if (er_ui_component_streq(slug, "breadcrumb")) {
    const char *const labels[] = {"Docs", "Components", "Breadcrumb"};
    return er_ui_component_breadcrumb_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 320.0f), 34.0f), theme, labels,
                                        ER_UI_COMPONENT_ARRAY_COUNT(labels), ER_UI_COMPONENT_PREVIEW_BREADCRUMB_CURRENT_INDEX,
                                        ER_UI_COMPONENT_PREVIEW_BREADCRUMB_ID);
  }
  if (er_ui_component_streq(slug, "button-group")) {
    const char *const labels[] = {"Copy", "Paste", "More"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 210.0f, 38.0f), theme, labels, ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u,
                                  ER_UI_COMPONENT_PREVIEW_BUTTON_GROUP_ID);
  }
  if (er_ui_component_streq(slug, "calendar") || er_ui_component_streq(slug, "date-picker")) {
    er_ui_status_t status = ER_UI_OK;
    if (er_ui_component_streq(slug, "date-picker")) {
      status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 120.0f, 38.0f), theme, "Pick a date", ER_UI_COMPONENT_PREVIEW_DATE_PICKER_ID,
                                        ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
      if (status != ER_UI_OK) return status;
      bounds.y += 46.0f;
    }
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, 260.0f, 132.0f);
    status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "June 2025", card.x + 14.0f, card.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    const char *const days[] = {"8", "9", "10", "11", "12", "13", "14"};
    for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(days); ++i) {
      status = er_ui_component_button_emit(scene, font, er_ui_bounds(card.x + 10.0f + (float)i * 34.0f, card.y + 58.0f, 30.0f, 34.0f), theme, days[i],
                                        ER_UI_COMPONENT_PREVIEW_CALENDAR_DAY_BASE_ID + (uint32_t)i,
                                        i == ER_UI_COMPONENT_PREVIEW_CALENDAR_SELECTED_INDEX ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST,
                                        ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
      if (status != ER_UI_OK) return status;
    }
    return ER_UI_OK;
  }
  if (er_ui_component_streq(slug, "card")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Create project", bounds.x + 16.0f, bounds.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Deploy your new project in one click.", bounds.x + 16.0f, bounds.y + 52.0f, theme.colors.muted);
  }
  if (er_ui_component_streq(slug, "carousel")) {
    er_ui_status_t status = ER_UI_OK;
    const char *const labels[] = {"1", "2", "3"};
    const char* const* label_cursor = labels;
    for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(labels); ++i) {
      const char* label = *label_cursor;
      er_ui_bounds_t card = er_ui_bounds(bounds.x + (float)i * 72.0f, bounds.y, 60.0f, 72.0f);
      status = er_ui_component_card_emit(scene, card, theme);
      if (status != ER_UI_OK) return status;
      status = er_ui_component_push_ascii_text(scene, font, label, card.x + 26.0f, card.y + 42.0f, theme.colors.text);
      if (status != ER_UI_OK) return status;
      label_cursor++;
    }
    return ER_UI_OK;
  }
  if (er_ui_component_streq(slug, "chart")) {
    const char *const labels[] = {"Jan", "Feb", "Mar", "Apr", "May", "Jun"};
    const float values[] = {0.42f, 0.68f, 0.51f, 0.82f, 0.56f, 0.74f};
    _Static_assert(ER_UI_COMPONENT_ARRAY_COUNT(labels) == ER_UI_COMPONENT_ARRAY_COUNT(values), "chart preview arrays must match");
    return er_ui_component_bar_chart_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 160.0f), theme, "Visitors", labels, values,
                                       ER_UI_COMPONENT_ARRAY_COUNT(values), ER_UI_COMPONENT_PREVIEW_CHART_ID, ER_UI_COMPONENT_PREVIEW_CHART_ACTIVE_INDEX);
  }
  if (er_ui_component_streq(slug, "checkbox")) {
    er_ui_status_t status = er_ui_component_checkbox_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 32.0f), theme, "Accept terms and conditions", true,
                                                       ER_UI_COMPONENT_PREVIEW_CHECKBOX_TERMS_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_checkbox_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 38.0f, bounds.w, 32.0f), theme, "Receive security emails", false,
                                      ER_UI_COMPONENT_PREVIEW_CHECKBOX_EMAILS_ID);
  }
  if (er_ui_component_streq(slug, "context-menu") || er_ui_component_streq(slug, "dropdown-menu")) {
    er_ui_status_t status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Profile", "Command P",
                                                       ER_UI_COMPONENT_PREVIEW_CONTEXT_PROFILE_ID, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Billing", "Command B",
                                        ER_UI_COMPONENT_PREVIEW_CONTEXT_BILLING_ID, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 96.0f, er_ui_float_min(bounds.w, 220.0f), 44.0f), theme, "Log out", "Shift Command Q",
                                      ER_UI_COMPONENT_PREVIEW_CONTEXT_LOGOUT_ID, false);
  }
  if (er_ui_component_streq(slug, "collapsible")) {
    er_ui_status_t status = er_ui_component_card_emit(scene, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 150.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "@peduarte starred 3 repositories", bounds.x + 14.0f, bounds.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x + 10.0f, bounds.y + 44.0f, 300.0f, 44.0f), theme, "@radix-ui/primitives",
                                        "Open source UI components", ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_PRIMITIVES_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x + 10.0f, bounds.y + 92.0f, 300.0f, 44.0f), theme, "@radix-ui/colors",
                                      "Beautiful color scales", ER_UI_COMPONENT_PREVIEW_COLLAPSIBLE_COLORS_ID, false);
  }
  if (er_ui_component_streq(slug, "combobox")) {
    er_ui_status_t status = er_ui_component_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 240.0f, 62.0f), theme, "Framework", "Select framework...",
                                                     ER_UI_COMPONENT_PREVIEW_COMBOBOX_SELECT_ID, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 70.0f, 240.0f, 54.0f), theme, "Search", "Search framework...",
                                     ER_UI_COMPONENT_PREVIEW_COMBOBOX_SEARCH_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 130.0f, 240.0f, 44.0f), theme, "Next.js", "selected",
                                      ER_UI_COMPONENT_PREVIEW_COMBOBOX_RESULT_ID, true);
  }
  if (er_ui_component_streq(slug, "command")) {
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 300.0f), 58.0f), theme, "Command",
                                   "Type a command or search...", ER_UI_COMPONENT_PREVIEW_COMMAND_ID, false);
  }
  if (er_ui_component_streq(slug, "data-table") || er_ui_component_streq(slug, "table")) {
    const char *const headers[] = {"Invoice", "Status", "Amount"};
    const char *const cells[] = {"INV001", "Paid", "$250.00", "INV002", "Pending", "$150.00"};
    _Static_assert(ER_UI_COMPONENT_ARRAY_COUNT(cells) % ER_UI_COMPONENT_ARRAY_COUNT(headers) == 0u, "table preview cells must fill rows");
    return er_ui_component_table_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 112.0f), theme, headers,
                                   ER_UI_COMPONENT_ARRAY_COUNT(headers), cells, ER_UI_COMPONENT_ARRAY_COUNT(cells) / ER_UI_COMPONENT_ARRAY_COUNT(headers),
                                   ER_UI_COMPONENT_PREVIEW_TABLE_ID);
  }
  if (er_ui_component_streq(slug, "empty")) {
    return er_ui_component_empty_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 280.0f), 120.0f), theme, "No results found",
                                   "Try adjusting your search or filters.");
  }
  if (er_ui_component_streq(slug, "direction")) {
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 44.0f, 26.0f), theme, "LTR", ER_UI_COMPONENT_BADGE_DEFAULT);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Left to right content", bounds.x + 56.0f, bounds.y + 19.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Right to left content", bounds.x, bounds.y + 56.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 160.0f, bounds.y + 36.0f, 44.0f, 26.0f), theme, "RTL", ER_UI_COMPONENT_BADGE_SECONDARY);
  }
  if (er_ui_component_streq(slug, "drawer")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 340.0f), 150.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Move goal", card.x + 16.0f, card.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Set your daily activity target.", card.x + 16.0f, card.y + 52.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_slider_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 70.0f, card.w - 32.0f, 42.0f), theme, "Calories", 0.58f,
                                      ER_UI_COMPONENT_PREVIEW_DRAWER_SLIDER_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 112.0f, 88.0f, 34.0f), theme, "Submit",
                                    ER_UI_COMPONENT_PREVIEW_DRAWER_SUBMIT_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "field") || er_ui_component_streq(slug, "input")) {
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 58.0f), theme, "Email", "name@example.com",
                                   ER_UI_COMPONENT_PREVIEW_FIELD_EMAIL_ID, false);
  }
  if (er_ui_component_streq(slug, "hover-card")) {
    er_ui_status_t status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 42.0f, 42.0f), theme, "ER", theme.colors.accent, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "ER", bounds.x + 54.0f, bounds.y + 18.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "UI infrastructure", bounds.x + 54.0f, bounds.y + 38.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "User-owned app surfaces with reusable native components.", bounds.x, bounds.y + 72.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "input-group")) {
    er_ui_status_t status = er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_max(bounds.w - 92.0f, 96.0f), 58.0f), theme, "URL",
                                                    "https://example.com", ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_FIELD_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font,
                                    er_ui_bounds(bounds.x + er_ui_float_max(bounds.w - 84.0f, 104.0f), bounds.y + 18.0f, 80.0f,
                                                 ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_H),
                                    theme, "Copy",
                                    ER_UI_COMPONENT_PREVIEW_INPUT_GROUP_BUTTON_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "input-otp")) {
    const char *const values[] = {"1", "2", "3", "-", "", "", ""};
    const char* const* value_cursor = values;
    for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(values); ++i) {
      const char* value = *value_cursor;
      if (er_ui_component_streq(value, "-")) {
        er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, "-", bounds.x + (float)i * 42.0f + 12.0f, bounds.y + 36.0f, theme.colors.muted);
        if (status != ER_UI_OK) return status;
        value_cursor++;
        continue;
      }
      er_ui_status_t status = er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x + (float)i * 42.0f, bounds.y, 36.0f, 52.0f), theme, "", value,
                                                      ER_UI_COMPONENT_PREVIEW_INPUT_OTP_BASE_ID + (uint32_t)i, false);
      if (status != ER_UI_OK) return status;
      value_cursor++;
    }
    return ER_UI_OK;
  }
  if (er_ui_component_streq(slug, "item")) {
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 280.0f), 52.0f), theme, "Payment successful",
                                      "Stripe payout completed", ER_UI_COMPONENT_PREVIEW_ITEM_ID, false);
  }
  if (er_ui_component_streq(slug, "kbd")) {
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 34.0f, 28.0f), theme, "Cmd", ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_badge_emit(scene, font, er_ui_bounds(bounds.x + 42.0f, bounds.y, 28.0f, 28.0f), theme, "K", ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Command menu", bounds.x + 84.0f, bounds.y + 20.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "label")) {
    er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, "Email", bounds.x, bounds.y + 16.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 24.0f, er_ui_float_min(bounds.w, 260.0f), 58.0f), theme, "", "name@example.com",
                                   ER_UI_COMPONENT_PREVIEW_LABEL_FIELD_ID, false);
  }
  if (er_ui_component_streq(slug, "menubar")) {
    const char *const labels[] = {"File", "Edit", "View", "Profiles"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 38.0f), theme, labels,
                                  ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_MENUBAR_ID);
  }
  if (er_ui_component_streq(slug, "native-select") || er_ui_component_streq(slug, "select")) {
    uint32_t id = ER_UI_COMPONENT_SELECT_TICKER_ID;
    bool open = er_ui_component_gallery_select_open(state, id);
    return er_ui_component_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 62.0f), theme, "Framework", "Next.js", id, open);
  }
  if (er_ui_component_streq(slug, "pagination")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 90.0f, 40.0f), theme, "Previous",
                                                     ER_UI_COMPONENT_PREVIEW_PAGINATION_PREVIOUS_ID,
                                                     ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 96.0f, bounds.y, 42.0f, 40.0f), theme, "1",
                                      ER_UI_COMPONENT_PREVIEW_PAGINATION_CURRENT_ID,
                                      ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 144.0f, bounds.y, 68.0f, 40.0f), theme, "Next",
                                    ER_UI_COMPONENT_PREVIEW_PAGINATION_NEXT_ID,
                                    ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
  }
  if (er_ui_component_streq(slug, "navigation-menu")) {
    const char *const labels[] = {"Getting started", "Components", "Docs"};
    er_ui_status_t status = er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 360.0f), 38.0f), theme, labels,
                                                   ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_NAVIGATION_TABS_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 50.0f, er_ui_float_min(bounds.w, 320.0f), 52.0f), theme, "Installation",
                                      "Add components to your app", ER_UI_COMPONENT_PREVIEW_NAVIGATION_INSTALL_ID, false);
  }
  if (er_ui_component_streq(slug, "popover")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 136.0f, 38.0f), theme, "Open popover",
                                                     ER_UI_COMPONENT_PREVIEW_POPOVER_BUTTON_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 300.0f), 120.0f);
    status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Dimensions", card.x + 14.0f, card.y + 26.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Set the dimensions for the layer.", card.x + 14.0f, card.y + 48.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_component_field_emit(scene, font, er_ui_bounds(card.x + 14.0f, card.y + 58.0f, card.w - 28.0f, 54.0f), theme, "Width", "100%",
                                   ER_UI_COMPONENT_PREVIEW_POPOVER_FIELD_ID, false);
  }
  if (er_ui_component_streq(slug, "progress")) {
    return er_ui_component_progress_emit(scene, er_ui_bounds(bounds.x, bounds.y + 20.0f, bounds.w, 8.0f), theme, 0.66f);
  }
  if (er_ui_component_streq(slug, "radio-group")) {
    er_ui_status_t status = er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 30.0f), theme, "Default", true,
                                                    ER_UI_COMPONENT_PREVIEW_RADIO_DEFAULT_ID);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 34.0f, bounds.w, 30.0f), theme, "Comfortable", false,
                                     ER_UI_COMPONENT_PREVIEW_RADIO_COMFORTABLE_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 68.0f, bounds.w, 30.0f), theme, "Compact", false,
                                   ER_UI_COMPONENT_PREVIEW_RADIO_COMPACT_ID);
  }
  if (er_ui_component_streq(slug, "resizable")) {
    er_ui_bounds_t first = er_ui_bounds(bounds.x, bounds.y, 90.0f, 92.0f);
    er_ui_bounds_t second = er_ui_bounds(bounds.x + 100.0f, bounds.y, 120.0f, 42.0f);
    er_ui_bounds_t third = er_ui_bounds(bounds.x + 100.0f, bounds.y + 50.0f, 120.0f, 42.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, first, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "One", first.x + 14.0f, first.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_card_emit(scene, second, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Two", second.x + 14.0f, second.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_card_emit(scene, third, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Three", third.x + 14.0f, third.y + 28.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "scroll-area")) {
    er_ui_status_t status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.0.0",
                                                       "Initial release", ER_UI_COMPONENT_PREVIEW_SCROLL_INITIAL_ID, false);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 48.0f, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.1.0",
                                        "Component updates", ER_UI_COMPONENT_PREVIEW_SCROLL_UPDATES_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_list_row_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 96.0f, er_ui_float_min(bounds.w, 260.0f), 44.0f), theme, "v1.2.0",
                                      "Preset builder", ER_UI_COMPONENT_PREVIEW_SCROLL_PRESET_ID, false);
  }
  if (er_ui_component_streq(slug, "separator")) {
    er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, "Radix Primitives", bounds.x, bounds.y + 12.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + 28.0f, bounds.w, 1.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Styled with EdgeRun UI tokens", bounds.x, bounds.y + 52.0f, theme.colors.muted);
  }
  if (er_ui_component_streq(slug, "sheet")) {
    er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 340.0f), 166.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Edit profile", card.x + 16.0f, card.y + 28.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "Make changes to your profile here.", card.x + 16.0f, card.y + 52.0f, theme.colors.muted);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_field_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 62.0f, card.w - 32.0f, 58.0f), theme, "Name", "EdgeRun",
                                     ER_UI_COMPONENT_PREVIEW_SHEET_FIELD_ID, false);
    if (status != ER_UI_OK) return status;
    return er_ui_component_button_emit(scene, font, er_ui_bounds(card.x + 16.0f, card.y + 124.0f, 120.0f, 36.0f), theme, "Save changes",
                                    ER_UI_COMPONENT_PREVIEW_SHEET_SAVE_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  }
  if (er_ui_component_streq(slug, "sidebar")) {
    er_ui_bounds_t side = er_ui_bounds(bounds.x, bounds.y, 150.0f, 154.0f);
    er_ui_status_t status = er_ui_component_card_emit(scene, side, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_push_ascii_text(scene, font, "App", side.x + 12.0f, side.y + 24.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(side.x + 8.0f, side.y + 40.0f, side.w - 16.0f, 34.0f), theme, "Dashboard", "",
                                        ER_UI_COMPONENT_PREVIEW_SIDEBAR_DASHBOARD_ID, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_list_row_emit(scene, font, er_ui_bounds(side.x + 8.0f, side.y + 78.0f, side.w - 16.0f, 34.0f), theme, "Transactions", "",
                                        ER_UI_COMPONENT_PREVIEW_SIDEBAR_TRANSACTIONS_ID, false);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t main = er_ui_bounds(bounds.x + 162.0f, bounds.y, er_ui_float_min(bounds.w - 170.0f, 220.0f), 154.0f);
    status = er_ui_component_card_emit(scene, main, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Dashboard", main.x + 16.0f, main.y + 28.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "skeleton")) {
    er_ui_status_t status = er_ui_component_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y, bounds.w, 18.0f), theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y + 28.0f, bounds.w * 0.66f, 18.0f), theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_skeleton_emit(scene, er_ui_bounds(bounds.x, bounds.y + 56.0f, bounds.w * 0.50f, 18.0f), theme);
  }
  if (er_ui_component_streq(slug, "slider")) {
    float value = er_ui_component_gallery_slider(state, ER_UI_COMPONENT_PREVIEW_SLIDER_ID, 0.42f);
    return er_ui_component_slider_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 48.0f), theme, "Volume", value, ER_UI_COMPONENT_PREVIEW_SLIDER_ID);
  }
  if (er_ui_component_streq(slug, "switch")) {
    er_ui_status_t status = er_ui_component_switch_emit(scene, er_ui_bounds(bounds.x, bounds.y, 44.0f, 24.0f), theme, true, ER_UI_COMPONENT_PREVIEW_SWITCH_ID);
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Airplane mode", bounds.x + 56.0f, bounds.y + 18.0f, theme.colors.text);
  }
  if (er_ui_component_streq(slug, "sonner")) {
    er_ui_status_t status = er_ui_component_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Event has been created",
                                                    theme.colors.success);
    if (status != ER_UI_OK) return status;
    return er_ui_component_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 56.0f, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Upload failed",
                                   theme.colors.danger);
  }
  if (er_ui_component_streq(slug, "tabs")) {
    const char *const labels[] = {"Account", "Password", "Settings"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 330.0f), 38.0f), theme, labels,
                                  ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_TABS_ID);
  }
  if (er_ui_component_streq(slug, "textarea")) {
    return er_ui_component_field_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 84.0f), theme, "Message", "Type your message here.",
                                   ER_UI_COMPONENT_PREVIEW_TEXTAREA_ID, true);
  }
  if (er_ui_component_streq(slug, "toast")) {
    return er_ui_component_toast_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 260.0f), 48.0f), theme, "Scheduled: Catch up",
                                   theme.colors.accent);
  }
  if (er_ui_component_streq(slug, "toggle")) {
    return er_ui_component_switch_emit(scene, er_ui_bounds(bounds.x, bounds.y, 44.0f, 24.0f), theme, true, ER_UI_COMPONENT_PREVIEW_TOGGLE_ID);
  }
  if (er_ui_component_streq(slug, "toggle-group")) {
    const char *const labels[] = {"B", "I", "U"};
    return er_ui_component_tabs_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 126.0f, 38.0f), theme, labels,
                                  ER_UI_COMPONENT_ARRAY_COUNT(labels), 0u, ER_UI_COMPONENT_PREVIEW_TOGGLE_GROUP_ID);
  }
  if (er_ui_component_streq(slug, "tooltip")) {
    er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, 80.0f, 38.0f), theme, "Hover",
                                                     ER_UI_COMPONENT_PREVIEW_TOOLTIP_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t tip = er_ui_bounds(bounds.x + 94.0f, bounds.y + 2.0f, 112.0f, 34.0f);
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tip.x, tip.y, tip.w, tip.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.panel, 0.96f)));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(tip.x, tip.y, tip.w, tip.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.border, 0.42f)));
    if (status != ER_UI_OK) return status;
    return er_ui_component_push_ascii_text(scene, font, "Add to library", tip.x + 10.0f, tip.y + 22.0f, theme.colors.text);
  }
  return ER_UI_ERR_INVALID_ARGUMENT;
}

er_ui_status_t er_ui_component_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* selected_slug,
  const er_ui_component_gallery_state_t* state) {
  if (!scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  const er_ui_component_spec_t* selected = er_ui_component_find_by_slug(selected_slug ? selected_slug : "button");
  if (!selected) selected = er_ui_component_find_by_slug("button");
  if (!selected) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, ER_UI_COMPONENT_SHOWCASE_INSET, ER_UI_COMPONENT_SHOWCASE_INSET);
  er_ui_responsive_sidecar_t layout = er_ui_responsive_sidecar(
    content,
    ER_UI_COMPONENT_SHOWCASE_MIN_LIST_W,
    ER_UI_COMPONENT_SHOWCASE_PREFERRED_LIST_W,
    ER_UI_COMPONENT_SHOWCASE_MIN_PREVIEW_W,
    ER_UI_COMPONENT_SHOWCASE_INSET,
    ER_UI_COMPONENT_SHOWCASE_STACKED_LIST_H);
  if (!er_ui_bounds_valid(layout.side) || !er_ui_bounds_valid(layout.main)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t list = layout.side;
  er_ui_bounds_t preview = layout.main;
  status = er_ui_component_card_emit(scene, list, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, "component components", list.x + 14.0f, list.y + 28.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  size_t visible = er_ui_float_min((float)ER_UI_COMPONENT_COUNT, (list.h - 48.0f) / 24.0f);
  for (size_t i = 0u; i < visible; ++i) {
    const er_ui_component_spec_t* spec = er_ui_component_at(i);
    if (!spec) continue;
    er_ui_bounds_t row = er_ui_bounds(list.x + 8.0f, list.y + 44.0f + (float)i * 24.0f, list.w - 16.0f, 22.0f);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_LIST_ROW, ER_UI_COMPONENT_SHOWCASE_ROW_BASE_ID + (uint32_t)i, row.x, row.y, row.w, row.h));
    if (status != ER_UI_OK) return status;
    if (er_ui_component_streq(spec->slug, selected->slug)) {
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(row.x, row.y, row.w, row.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.active, 0.54f)));
      if (status != ER_UI_OK) return status;
    }
    status = er_ui_component_push_ascii_text(scene, font, spec->name, row.x + 8.0f, row.y + 16.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
  }

  status = er_ui_component_card_emit(scene, preview, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, selected->name, preview.x + 18.0f, preview.y + 30.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, er_ui_component_category_label(selected->category), preview.x + 18.0f, preview.y + 54.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t body = er_ui_bounds(preview.x + 18.0f, preview.y + 76.0f, preview.w - 36.0f, preview.h - 94.0f);
  return er_ui_component_scene_preview_emit(scene, font, body, theme, selected->slug, state);
}
