#include "er_ui_components_internal.h"

bool er_ui_component_streq(const char* a, const char* b) {
  if (!a || !b) return false;
  while (*a && *b) { if (*a != *b) return false; a++; b++; }
  return *a == *b;
}

bool er_ui_component_list_contains(const char* const* values, size_t count, const char* value) {
  if (!values || !value) return false;
  for (size_t i = 0u; i < count; ++i) if (er_ui_component_streq(values[i], value)) return true;
  return false;
}

bool er_ui_component_range_starts_with(const char* start, const char* end, const char* prefix, size_t prefix_len) {
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

bool er_ui_component_ends_with_len(const char* start, const char* end, const char* suffix, size_t suffix_len) {
  if (!start || !end || !suffix || end < start || (size_t)(end - start) <= suffix_len) return false;
  const char* candidate = end - suffix_len;
  for (size_t i = 0u; i < suffix_len; ++i) if (candidate[i] != suffix[i]) return false;
  return true;
}

er_ui_status_t er_ui_component_push_ascii_text(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  er_ui_color4_t color) {
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_COMPONENT_TEXT_CAPACITY, x, y, color);
}

er_ui_status_t er_ui_component_push_ascii_text_clipped(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* text,
  float x,
  float y,
  float max_w,
  er_ui_color4_t color) {
  if (!scene || !font || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  if (max_w <= 0.0f) return ER_UI_OK;
  size_t len = er_ui_ascii_len(text);
  size_t max_chars = (size_t)(max_w / ER_UI_COMPONENT_TEXT_ADVANCE);
  if (max_chars == 0u) return ER_UI_OK;
  if (max_chars >= len) return er_ui_component_push_ascii_text(scene, font, text, x, y, color);
  if (max_chars > ER_UI_COMPONENT_TEXT_CAPACITY) max_chars = ER_UI_COMPONENT_TEXT_CAPACITY;
  return er_ui_scene_push_ascii_text_n(scene, font, text, max_chars, x, y, color);
}

er_ui_status_t er_ui_component_push_icon(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_icon_t icon,
  er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_icon(&painter, bounds, icon, color);
}

er_ui_status_t er_ui_component_icon_tile(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_icon_t icon,
  er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_rect_t tile_fill =
    er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.design.radius.md, er_ui_color_with_alpha(theme.design.colors.muted, 0.72f));
  er_ui_status_t status = er_ui_scene_push_rect(scene, tile_fill);
  if (status != ER_UI_OK) return status;
  float icon_size = er_ui_float_min(bounds.w, bounds.h) - 10.0f;
  if (icon_size < 8.0f) icon_size = er_ui_float_min(bounds.w, bounds.h);
  float icon_x = bounds.x + (bounds.w - icon_size) * 0.5f;
  float icon_y = bounds.y + (bounds.h - icon_size) * 0.5f;
  er_ui_bounds_t icon_bounds = er_ui_bounds(icon_x, icon_y, icon_size, icon_size);
  return er_ui_component_push_icon(scene, icon_bounds, icon, color);
}

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

er_ui_status_t er_ui_component_fill_border(
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

er_ui_status_t er_ui_component_row_frame_emit(
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
  float detail_y) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_row_frame_emit(scene, bounds, hit_kind, id, has_hit, radius, fill);
  if (status != ER_UI_OK) return status;
  float text_x = bounds.x + ER_UI_COMPONENT_ROW_TEXT_PAD_RIGHT;
  float text_w = bounds.w - ER_UI_COMPONENT_ROW_TEXT_PAD_RIGHT * 2.0f;
  status = er_ui_component_push_ascii_text_clipped(scene, font, title, text_x, bounds.y + title_y, text_w, theme.colors.text);
  if (status != ER_UI_OK) return status;
  if (!detail[0]) return ER_UI_OK;
  return er_ui_component_push_ascii_text_clipped(scene, font, detail, text_x, bounds.y + detail_y, text_w, theme.colors.muted);
}


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

er_ui_status_t er_ui_component_icon_text_row_emit(
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
  float text_x = bounds.x + row->text_x;
  float text_w = bounds.x + bounds.w - text_x - ER_UI_COMPONENT_ROW_TEXT_PAD_RIGHT;
  status = er_ui_component_push_ascii_text_clipped(scene, font, title, text_x, bounds.y + row->title_y, text_w, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text_clipped(scene, font, detail, text_x, bounds.y + row->detail_y, text_w, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  if (!row->separator) return ER_UI_OK;
  return er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - ER_UI_COMPONENT_ROW_SEPARATOR_H,
                                                           bounds.w, ER_UI_COMPONENT_ROW_SEPARATOR_H), theme);
}

er_ui_status_t er_ui_component_bottom_separator_emit(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  return er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x, bounds.y + bounds.h - ER_UI_COMPONENT_ROW_SEPARATOR_H,
                                                           bounds.w, ER_UI_COMPONENT_ROW_SEPARATOR_H), theme);
}

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

er_ui_color4_t er_ui_component_button_fill(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE: return er_ui_color_with_alpha(theme.design.colors.destructive, 0.20f);
    case ER_UI_COMPONENT_BUTTON_OUTLINE: return er_ui_color_with_alpha(theme.design.colors.input, 0.30f);
    case ER_UI_COMPONENT_BUTTON_SECONDARY: return theme.design.colors.secondary;
    case ER_UI_COMPONENT_BUTTON_GHOST:
    case ER_UI_COMPONENT_BUTTON_LINK: return er_ui_color_with_alpha(theme.design.colors.card, 0.0f);
    case ER_UI_COMPONENT_BUTTON_DEFAULT:
    default: return theme.design.colors.primary;
  }
}

er_ui_color4_t er_ui_component_button_border(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE: return er_ui_color_with_alpha(theme.design.colors.destructive, 0.40f);
    case ER_UI_COMPONENT_BUTTON_DEFAULT: return er_ui_color_with_alpha(theme.design.colors.primary, 0.0f);
    case ER_UI_COMPONENT_BUTTON_OUTLINE: return theme.design.colors.input;
    default: return er_ui_color_with_alpha(theme.design.colors.border, 0.0f);
  }
}

er_ui_color4_t er_ui_component_button_text(er_ui_resolved_theme_t theme, er_ui_component_button_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_DEFAULT: return theme.design.colors.primary_foreground;
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE: return theme.design.colors.destructive;
    case ER_UI_COMPONENT_BUTTON_SECONDARY: return theme.design.colors.secondary_foreground;
    case ER_UI_COMPONENT_BUTTON_GHOST: return theme.design.colors.foreground;
    case ER_UI_COMPONENT_BUTTON_LINK: return theme.design.colors.primary;
    default: return theme.design.colors.foreground;
  }
}

er_ui_color4_t er_ui_component_badge_fill(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BADGE_SECONDARY: return theme.design.colors.secondary;
    case ER_UI_COMPONENT_BADGE_DESTRUCTIVE: return er_ui_color_with_alpha(theme.design.colors.destructive, 0.20f);
    case ER_UI_COMPONENT_BADGE_OUTLINE: return er_ui_color_with_alpha(theme.design.colors.card, 0.0f);
    case ER_UI_COMPONENT_BADGE_DEFAULT:
    default: return theme.design.colors.primary;
  }
}

er_ui_color4_t er_ui_component_badge_text(er_ui_resolved_theme_t theme, er_ui_component_badge_variant_t variant) {
  switch (variant) {
    case ER_UI_COMPONENT_BADGE_DEFAULT: return theme.design.colors.primary_foreground;
    case ER_UI_COMPONENT_BADGE_DESTRUCTIVE: return theme.design.colors.destructive;
    case ER_UI_COMPONENT_BADGE_SECONDARY: return theme.design.colors.secondary_foreground;
    default: return theme.design.colors.foreground;
  }
}


float er_ui_component_clamp01(float value) {
  return er_math_clamp01f(value);
}
