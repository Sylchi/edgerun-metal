#include "er_ui_components_internal.h"

er_ui_bounds_t er_ui_component_button_bounds(er_ui_bounds_t bounds, er_ui_component_button_size_t size) {
  switch (size) {
    case ER_UI_COMPONENT_BUTTON_SIZE_SM: return er_ui_bounds_with_height_centered(bounds, 32.0f);
    case ER_UI_COMPONENT_BUTTON_SIZE_LG: return er_ui_bounds_with_height_centered(bounds, 40.0f);
    case ER_UI_COMPONENT_BUTTON_SIZE_ICON: {
      er_ui_bounds_t centered = er_ui_bounds_with_height_centered(bounds, 36.0f);
      return er_ui_bounds_with_width_centered(centered, 36.0f);
    }
    case ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT:
    default: return er_ui_bounds_with_height_centered(bounds, 36.0f);
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
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  if (variant != ER_UI_COMPONENT_BUTTON_LINK) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(rect.x, rect.y, rect.w, rect.h, theme.shadcn.radius.md, fill));
    if (status != ER_UI_OK) return status;
  }
  if (variant != ER_UI_COMPONENT_BUTTON_GHOST && variant != ER_UI_COMPONENT_BUTTON_LINK) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(rect.x, rect.y, rect.w, rect.h, theme.shadcn.radius.md,
                                                           er_ui_component_button_border(theme, variant)));
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
  bool interactive,
  float control_h,
  er_ui_color4_t fill,
  float border_alpha,
  er_ui_bounds_t* out_control) {
  if (!scene || !font || !label || !out_control || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.shadcn.colors.foreground);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t control = er_ui_bounds(bounds.x, bounds.y + 18.0f, bounds.w, control_h);
  if (!er_ui_bounds_valid(control)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (interactive) {
    status = er_ui_scene_push_hit(scene, er_ui_hit(hit_kind, id, control.x, control.y, control.w, control.h));
    if (status != ER_UI_OK) return status;
  }
  (void)border_alpha;
  status = er_ui_component_fill_border(scene, control, theme.shadcn.radius.md, fill, theme.shadcn.colors.input);
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
  er_ui_color4_t fill =
    open ? er_ui_color_with_alpha(theme.shadcn.colors.muted, 0.72f) : er_ui_color_with_alpha(theme.shadcn.colors.input, 0.30f);
  er_ui_bounds_t control;
  er_ui_status_t status = er_ui_component_labeled_control_frame(
    scene, font, bounds, theme, label, ER_UI_HIT_SELECT, id, true, er_ui_float_min(bounds.h - 18.0f, theme.shadcn.metrics.control_h), fill, 0.40f, &control);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, value, control.x + theme.shadcn.metrics.control_pad_x, control.y + 23.0f,
                                           theme.shadcn.colors.foreground);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_icon(scene, er_ui_bounds(control.x + control.w - 24.0f, control.y + (control.h - 16.0f) * 0.5f, 16.0f, 16.0f),
                                open ? ER_UI_ICON_X : ER_UI_ICON_CHEVRON_RIGHT, theme.shadcn.colors.muted_foreground);
}

er_ui_status_t er_ui_component_select_static_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  bool open) {
  if (!scene || !font || !label || !value || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill =
    open ? er_ui_color_with_alpha(theme.shadcn.colors.muted, 0.72f) : er_ui_color_with_alpha(theme.shadcn.colors.input, 0.30f);
  er_ui_bounds_t control;
  er_ui_status_t status = er_ui_component_labeled_control_frame(
    scene, font, bounds, theme, label, ER_UI_HIT_SELECT, 0u, false, er_ui_float_min(bounds.h - 18.0f, theme.shadcn.metrics.control_h), fill, 0.40f, &control);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_push_ascii_text(scene, font, value, control.x + theme.shadcn.metrics.control_pad_x, control.y + 23.0f,
                                           theme.shadcn.colors.foreground);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_icon(scene, er_ui_bounds(control.x + control.w - 24.0f, control.y + (control.h - 16.0f) * 0.5f, 16.0f, 16.0f),
                                  open ? ER_UI_ICON_X : ER_UI_ICON_CHEVRON_RIGHT, theme.shadcn.colors.muted_foreground);
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
  er_ui_status_t status = er_ui_component_push_ascii_text(scene, font, label, bounds.x, bounds.y + 13.0f, theme.shadcn.colors.foreground);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t track = er_ui_bounds(bounds.x, bounds.y + bounds.h - 18.0f, bounds.w, theme.shadcn.metrics.progress_h);
  status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SLIDER, id, track.x, track.y - 12.0f, track.w, 30.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(track.x, track.y, track.w, track.h, 999.0f, theme.shadcn.colors.muted));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(track.x, track.y, track.w * clamped, track.h, 999.0f, theme.shadcn.colors.primary));
  if (status != ER_UI_OK) return status;
  float thumb = theme.shadcn.metrics.slider_thumb;
  float thumb_x = track.x + track.w * clamped - thumb * 0.5f;
  return er_ui_component_fill_border(scene, er_ui_bounds(thumb_x, track.y - 5.0f, thumb, thumb), thumb * 0.5f,
                                     theme.shadcn.colors.foreground, theme.shadcn.colors.primary);
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
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, theme.shadcn.colors.border));
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
    true,
    er_ui_float_max(bounds.h - 18.0f, 24.0f),
    er_ui_color_with_alpha(theme.shadcn.colors.input, 0.30f),
    0.44f,
    &control);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, value, control.x + theme.shadcn.metrics.control_pad_x, control.y + 23.0f,
                                         theme.shadcn.colors.foreground);
}

er_ui_status_t er_ui_component_field_static_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
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
    0u,
    false,
    er_ui_float_max(bounds.h - 18.0f, 24.0f),
    er_ui_color_with_alpha(theme.shadcn.colors.input, 0.30f),
    0.44f,
    &control);
  if (status != ER_UI_OK) return status;
  return er_ui_component_push_ascii_text(scene, font, value, control.x + theme.shadcn.metrics.control_pad_x, control.y + 23.0f,
                                         theme.shadcn.colors.foreground);
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
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(box.x, box.y, box.w, box.h, 4.0f,
                                                       checked ? theme.shadcn.colors.primary : er_ui_color_with_alpha(theme.shadcn.colors.input, 0.30f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(box.x, box.y, box.w, box.h, 4.0f,
                                                         checked ? theme.shadcn.colors.primary : theme.shadcn.colors.input));
  if (status != ER_UI_OK) return status;
  if (checked) {
    status = er_ui_component_push_icon(scene, er_ui_bounds(box.x + 3.0f, box.y + 3.0f, 12.0f, 12.0f), ER_UI_ICON_CHECK,
                                    theme.shadcn.colors.primary_foreground);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_push_ascii_text(scene, font, label, bounds.x + 28.0f, bounds.y + bounds.h * 0.62f, theme.shadcn.colors.foreground);
}

er_ui_status_t er_ui_component_progress_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, float value) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float clamped = er_ui_component_clamp01(value);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, theme.shadcn.colors.muted));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w * clamped, bounds.h, theme.radius.pill, theme.shadcn.colors.primary));
}

er_ui_status_t er_ui_component_switch_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme, bool checked, uint32_t id) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TOGGLE, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  er_ui_color4_t fill = checked ? theme.shadcn.colors.primary : theme.shadcn.colors.input;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.pill, fill));
  if (status != ER_UI_OK) return status;
  float thumb = er_ui_float_min(bounds.h - 6.0f, 20.0f);
  float thumb_x = checked ? bounds.x + bounds.w - thumb - 3.0f : bounds.x + 3.0f;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(thumb_x, bounds.y + (bounds.h - thumb) * 0.5f, thumb, thumb, thumb * 0.5f,
                                                     checked ? theme.shadcn.colors.primary_foreground : theme.shadcn.colors.foreground));
}

er_ui_status_t er_ui_component_separator_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.shadcn.colors.border));
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
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.shadcn.radius.md,
                                                                      er_ui_color_with_alpha(theme.shadcn.colors.muted, 0.62f)));
  if (status != ER_UI_OK) return status;
  float tab_w = bounds.w / (float)label_count;
  const char* const* label_cursor = labels;
  for (size_t i = 0u; i < label_count; ++i) {
    const char* label = *label_cursor;
    er_ui_bounds_t tab = er_ui_bounds(bounds.x + tab_w * (float)i, bounds.y, tab_w, bounds.h);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_TAB, base_id + (uint32_t)i, tab.x, tab.y, tab.w, tab.h));
    if (status != ER_UI_OK) return status;
    if (i == selected) {
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tab.x + 3.0f, tab.y + 3.0f, tab.w - 6.0f, tab.h - 6.0f, theme.shadcn.radius.md,
                                                           theme.shadcn.colors.card));
      if (status != ER_UI_OK) return status;
    }
    status = er_ui_component_push_ascii_text(scene, font, label, tab.x + 12.0f, tab.y + tab.h * 0.62f,
                                             i == selected ? theme.shadcn.colors.foreground : theme.shadcn.colors.muted_foreground);
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
  er_ui_color4_t fill = selected ? theme.shadcn.colors.muted : er_ui_color_with_alpha(theme.shadcn.colors.card, 0.0f);
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
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.shadcn.radius.md, theme.shadcn.colors.muted));
}

er_ui_status_t er_ui_component_spinner_emit(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float size = er_ui_float_min(bounds.w, bounds.h);
  if (size <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  float x = bounds.x + (bounds.w - size) * 0.5f;
  float y = bounds.y + (bounds.h - size) * 0.5f;
  float dot = er_ui_float_max(size * 0.14f, 2.0f);
  const struct { float x; float y; float alpha; } dots[] = {
    {0.50f, 0.00f, 1.00f},
    {0.86f, 0.14f, 0.86f},
    {1.00f, 0.50f, 0.72f},
    {0.86f, 0.86f, 0.58f},
    {0.50f, 1.00f, 0.44f},
    {0.14f, 0.86f, 0.36f},
    {0.00f, 0.50f, 0.28f},
    {0.14f, 0.14f, 0.20f},
  };
  for (size_t i = 0u; i < ER_UI_COMPONENT_ARRAY_COUNT(dots); ++i) {
    er_ui_status_t status = er_ui_scene_push_rect(scene,
      er_ui_rect_fill(x + size * dots[i].x - dot * 0.5f, y + size * dots[i].y - dot * 0.5f, dot, dot, dot * 0.5f,
                      er_ui_color_with_alpha(theme.shadcn.colors.primary, dots[i].alpha)));
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
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
