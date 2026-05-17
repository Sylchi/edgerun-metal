#include "er_ui_components.h"

static const size_t ER_UI_COMPONENT_TEXT_MAX_CODEPOINTS = 192u;

static er_ui_status_t er_ui_component_text_color_for_button(
  er_ui_component_button_variant_t variant,
  er_ui_resolved_theme_t theme,
  er_ui_color4_t* out_fill,
  er_ui_color4_t* out_text,
  er_ui_color4_t* out_border) {
  if (!out_fill || !out_text || !out_border) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_border = theme.colors.border;
  switch (variant) {
    case ER_UI_COMPONENT_BUTTON_PRIMARY:
      *out_fill = theme.colors.accent;
      *out_text = theme.colors.accent_text;
      break;
    case ER_UI_COMPONENT_BUTTON_SECONDARY:
      *out_fill = theme.colors.row;
      *out_text = theme.colors.text;
      break;
    case ER_UI_COMPONENT_BUTTON_OUTLINE:
      *out_fill = theme.colors.panel;
      *out_text = theme.colors.text;
      break;
    case ER_UI_COMPONENT_BUTTON_GHOST:
      *out_fill = er_ui_color_with_alpha(theme.colors.row, 0.0f);
      *out_text = theme.colors.text;
      *out_border = er_ui_color_with_alpha(theme.colors.border, 0.0f);
      break;
    case ER_UI_COMPONENT_BUTTON_DESTRUCTIVE:
      *out_fill = theme.colors.danger;
      *out_text = theme.colors.accent_text;
      break;
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
  return ER_UI_OK;
}

static er_ui_color4_t er_ui_component_badge_fill(er_ui_component_badge_variant_t variant, er_ui_resolved_theme_t theme) {
  switch (variant) {
    case ER_UI_COMPONENT_BADGE_SUCCESS: return er_ui_color_with_alpha(theme.colors.success, 0.24f);
    case ER_UI_COMPONENT_BADGE_WARNING: return er_ui_color_with_alpha(theme.colors.warning, 0.24f);
    case ER_UI_COMPONENT_BADGE_DANGER: return er_ui_color_with_alpha(theme.colors.danger, 0.24f);
    case ER_UI_COMPONENT_BADGE_OUTLINE: return theme.colors.panel;
    case ER_UI_COMPONENT_BADGE_SECONDARY: return theme.colors.row;
    case ER_UI_COMPONENT_BADGE_DEFAULT:
    default: return er_ui_color_with_alpha(theme.colors.accent, 0.22f);
  }
}

static er_ui_color4_t er_ui_component_badge_text(er_ui_component_badge_variant_t variant, er_ui_resolved_theme_t theme) {
  switch (variant) {
    case ER_UI_COMPONENT_BADGE_SUCCESS: return theme.colors.success;
    case ER_UI_COMPONENT_BADGE_WARNING: return theme.colors.warning;
    case ER_UI_COMPONENT_BADGE_DANGER: return theme.colors.danger;
    case ER_UI_COMPONENT_BADGE_DEFAULT: return theme.colors.accent;
    case ER_UI_COMPONENT_BADGE_SECONDARY:
    case ER_UI_COMPONENT_BADGE_OUTLINE:
    default: return theme.colors.text;
  }
}

er_ui_status_t er_ui_component_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, float x, float y, er_ui_color4_t color) {
  if (!scene || !font || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  uint32_t codepoints[192u];
  size_t count = 0u;
  while (text[count] != '\0') {
    if (count >= ER_UI_COMPONENT_TEXT_MAX_CODEPOINTS) return ER_UI_ERR_INVALID_ARGUMENT;
    unsigned char ch = (unsigned char)text[count];
    if (ch > 0x7Fu) return ER_UI_ERR_INVALID_ARGUMENT;
    codepoints[count] = (uint32_t)ch;
    count++;
  }
  if (count == 0u) return ER_UI_OK;
  return er_ui_scene_push_varfont_text(scene, font, codepoints, count, x, y, color);
}

er_ui_status_t er_ui_component_card(er_ui_painter_t* painter, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_painter_fill_rect(painter, bounds, theme.radius.card, theme.colors.panel);
  if (status != ER_UI_OK) return status;
  return er_ui_painter_border_rect(painter, bounds, theme.radius.card, theme.colors.border);
}

er_ui_status_t er_ui_component_button(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* label,
  er_ui_component_button_variant_t variant,
  er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !font || !label || id == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t fill = {0};
  er_ui_color4_t text = {0};
  er_ui_color4_t border = {0};
  er_ui_status_t status = er_ui_component_text_color_for_button(variant, theme, &fill, &text, &border);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_fill_rect(painter, bounds, theme.radius.control, fill);
  if (status != ER_UI_OK) return status;
  if (variant == ER_UI_COMPONENT_BUTTON_OUTLINE || variant == ER_UI_COMPONENT_BUTTON_GHOST) {
    status = er_ui_painter_border_rect(painter, bounds, theme.radius.control, border);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_painter_hit(painter, ER_UI_HIT_BUTTON, id, bounds);
  if (status != ER_UI_OK) return status;
  return er_ui_component_text(painter->scene, font, label, bounds.x + 14.0f, bounds.y + 27.0f, text);
}

er_ui_status_t er_ui_component_badge(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  const char* label,
  er_ui_component_badge_variant_t variant,
  er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !font || !label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_painter_fill_rect(painter, bounds, bounds.h * 0.5f, er_ui_component_badge_fill(variant, theme));
  if (status != ER_UI_OK) return status;
  if (variant == ER_UI_COMPONENT_BADGE_OUTLINE) {
    status = er_ui_painter_border_rect(painter, bounds, bounds.h * 0.5f, theme.colors.border);
    if (status != ER_UI_OK) return status;
  }
  return er_ui_component_text(painter->scene, font, label, bounds.x + 10.0f, bounds.y + 21.0f, er_ui_component_badge_text(variant, theme));
}

er_ui_status_t er_ui_component_input(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* value,
  const char* placeholder,
  er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !font || id == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  const char* text = value && value[0] != '\0' ? value : placeholder;
  if (!text) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_color4_t text_color = value && value[0] != '\0' ? theme.colors.text : theme.colors.muted;
  er_ui_status_t status = er_ui_painter_fill_rect(painter, bounds, theme.radius.control, theme.colors.composer);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_border_rect(painter, bounds, theme.radius.control, theme.colors.border);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_hit(painter, ER_UI_HIT_INPUT, id, bounds);
  if (status != ER_UI_OK) return status;
  return er_ui_component_text(painter->scene, font, text, bounds.x + 12.0f, bounds.y + 27.0f, text_color);
}

er_ui_status_t er_ui_component_checkbox(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* label,
  bool checked,
  er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !font || !label || id == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t box = er_ui_bounds(bounds.x, bounds.y + 2.0f, 18.0f, 18.0f);
  er_ui_status_t status = er_ui_painter_fill_rect(painter, box, 4.0f, checked ? theme.colors.accent : theme.colors.panel);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_border_rect(painter, box, 4.0f, checked ? theme.colors.accent : theme.colors.border);
  if (status != ER_UI_OK) return status;
  if (checked) {
    status = er_ui_component_text(painter->scene, font, "x", box.x + 5.0f, box.y + 16.0f, theme.colors.accent_text);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_painter_hit(painter, ER_UI_HIT_CHECKBOX, id, er_ui_bounds(bounds.x, bounds.y, bounds.w, 28.0f));
  if (status != ER_UI_OK) return status;
  return er_ui_component_text(painter->scene, font, label, bounds.x + 28.0f, bounds.y + 19.0f, theme.colors.text);
}

er_ui_status_t er_ui_component_switch(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t id,
  const char* label,
  bool checked,
  er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !font || !label || id == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t track = er_ui_bounds(bounds.x, bounds.y + 2.0f, 42.0f, 22.0f);
  er_ui_bounds_t knob = er_ui_bounds(track.x + (checked ? 21.0f : 3.0f), track.y + 3.0f, 16.0f, 16.0f);
  er_ui_status_t status = er_ui_painter_fill_rect(painter, track, 11.0f, checked ? theme.colors.accent : theme.colors.row);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_fill_rect(painter, knob, 8.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_hit(painter, ER_UI_HIT_TOGGLE, id, er_ui_bounds(bounds.x, bounds.y, bounds.w, 30.0f));
  if (status != ER_UI_OK) return status;
  return er_ui_component_text(painter->scene, font, label, bounds.x + 54.0f, bounds.y + 20.0f, theme.colors.text);
}

er_ui_status_t er_ui_component_slider(er_ui_painter_t* painter, er_ui_bounds_t bounds, uint32_t id, float value, er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || id == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float clamped = er_ui_float_clamp(value, 0.0f, 1.0f);
  er_ui_bounds_t track = er_ui_bounds(bounds.x, bounds.y + bounds.h * 0.5f - 2.0f, bounds.w, 4.0f);
  er_ui_bounds_t fill = er_ui_bounds(track.x, track.y, track.w * clamped, track.h);
  er_ui_bounds_t knob = er_ui_bounds(track.x + track.w * clamped - 7.0f, bounds.y + bounds.h * 0.5f - 7.0f, 14.0f, 14.0f);
  er_ui_status_t status = er_ui_painter_fill_rect(painter, track, 2.0f, theme.colors.row);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_fill_rect(painter, fill, 2.0f, theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_fill_rect(painter, knob, 7.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_painter_hit(painter, ER_UI_HIT_SLIDER, id, bounds);
}

er_ui_status_t er_ui_component_tabs(
  er_ui_painter_t* painter,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  uint32_t first_id,
  const char* first_label,
  const char* second_label,
  size_t selected_index,
  er_ui_resolved_theme_t theme) {
  if (!painter || !painter->scene || !font || !first_label || !second_label || first_id == 0u || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_status_t status = er_ui_painter_fill_rect(painter, bounds, theme.radius.control, theme.colors.row);
  if (status != ER_UI_OK) return status;
  float item_w = bounds.w * 0.5f;
  for (size_t i = 0u; i < 2u; ++i) {
    er_ui_bounds_t item = er_ui_bounds(bounds.x + item_w * (float)i + 3.0f, bounds.y + 3.0f, item_w - 6.0f, bounds.h - 6.0f);
    if (i == selected_index) {
      status = er_ui_painter_fill_rect(painter, item, theme.radius.control, theme.colors.panel);
      if (status != ER_UI_OK) return status;
    }
    status = er_ui_painter_hit(painter, ER_UI_HIT_TAB, first_id + (uint32_t)i, item);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_text(painter->scene, font, i == 0u ? first_label : second_label, item.x + 12.0f, item.y + 24.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_showcase_section_title(er_ui_scene_t* scene, vr_font_face_t* font, const char* label, float x, float y, er_ui_resolved_theme_t theme) {
  return er_ui_component_text(scene, font, label, x, y, theme.colors.text);
}

er_ui_status_t er_ui_shadcn_showcase_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  uint32_t first_id,
  er_ui_shadcn_showcase_stats_t* out_stats) {
  if (out_stats) *out_stats = (er_ui_shadcn_showcase_stats_t){0};
  if (!scene || !font || first_id == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_painter_t painter = er_ui_painter(scene);
  uint32_t id = first_id;
  size_t components = 0u;
  size_t buttons = 0u;
  size_t text_labels = 0u;

  er_ui_status_t status = er_ui_painter_fill_rect(&painter, bounds, 0.0f, theme.colors.bg);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_text(scene, font, "shadcn component showcase", bounds.x + 24.0f, bounds.y + 36.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  text_labels++;
  status = er_ui_component_text(scene, font, "Reusable UI core primitives, no app inventory.", bounds.x + 24.0f, bounds.y + 64.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  text_labels++;

  er_ui_bounds_t card = er_ui_bounds(bounds.x + 24.0f, bounds.y + 88.0f, 344.0f, 212.0f);
  status = er_ui_component_card(&painter, card, theme);
  if (status != ER_UI_OK) return status;
  components++;
  status = er_ui_showcase_section_title(scene, font, "Buttons", card.x + 18.0f, card.y + 32.0f, theme);
  if (status != ER_UI_OK) return status;
  text_labels++;
  const er_ui_component_button_variant_t variants[] = {
    ER_UI_COMPONENT_BUTTON_PRIMARY,
    ER_UI_COMPONENT_BUTTON_SECONDARY,
    ER_UI_COMPONENT_BUTTON_OUTLINE,
    ER_UI_COMPONENT_BUTTON_GHOST,
    ER_UI_COMPONENT_BUTTON_DESTRUCTIVE,
  };
  const char* labels[] = {"Primary", "Secondary", "Outline", "Ghost", "Destroy"};
  for (size_t i = 0u; i < 5u; ++i) {
    er_ui_bounds_t button = er_ui_bounds(card.x + 18.0f + (float)(i % 2u) * 150.0f, card.y + 52.0f + (float)(i / 2u) * 48.0f, 132.0f, 36.0f);
    status = er_ui_component_button(&painter, font, button, id++, labels[i], variants[i], theme);
    if (status != ER_UI_OK) return status;
    components++;
    buttons++;
    text_labels++;
  }

  card = er_ui_bounds(bounds.x + 392.0f, bounds.y + 88.0f, 336.0f, 212.0f);
  status = er_ui_component_card(&painter, card, theme);
  if (status != ER_UI_OK) return status;
  components++;
  status = er_ui_showcase_section_title(scene, font, "Form controls", card.x + 18.0f, card.y + 32.0f, theme);
  if (status != ER_UI_OK) return status;
  text_labels++;
  status = er_ui_component_input(&painter, font, er_ui_bounds(card.x + 18.0f, card.y + 52.0f, 220.0f, 36.0f), id++, "", "Identity name", theme);
  if (status != ER_UI_OK) return status;
  components++;
  text_labels++;
  status = er_ui_component_checkbox(&painter, font, er_ui_bounds(card.x + 18.0f, card.y + 104.0f, 220.0f, 28.0f), id++, "Cache verified bytes", true, theme);
  if (status != ER_UI_OK) return status;
  components++;
  text_labels++;
  status = er_ui_component_switch(&painter, font, er_ui_bounds(card.x + 18.0f, card.y + 144.0f, 220.0f, 30.0f), id++, "Earning mode", false, theme);
  if (status != ER_UI_OK) return status;
  components++;
  text_labels++;

  card = er_ui_bounds(bounds.x + 24.0f, bounds.y + 324.0f, 344.0f, 208.0f);
  status = er_ui_component_card(&painter, card, theme);
  if (status != ER_UI_OK) return status;
  components++;
  status = er_ui_showcase_section_title(scene, font, "Status badges", card.x + 18.0f, card.y + 32.0f, theme);
  if (status != ER_UI_OK) return status;
  text_labels++;
  const er_ui_component_badge_variant_t badge_variants[] = {
    ER_UI_COMPONENT_BADGE_DEFAULT,
    ER_UI_COMPONENT_BADGE_SECONDARY,
    ER_UI_COMPONENT_BADGE_OUTLINE,
    ER_UI_COMPONENT_BADGE_SUCCESS,
    ER_UI_COMPONENT_BADGE_WARNING,
    ER_UI_COMPONENT_BADGE_DANGER,
  };
  const char* badge_labels[] = {"Verified", "Cached", "Policy", "Paid", "Pending", "Denied"};
  for (size_t i = 0u; i < 6u; ++i) {
    er_ui_bounds_t badge = er_ui_bounds(card.x + 18.0f + (float)(i % 3u) * 98.0f, card.y + 58.0f + (float)(i / 3u) * 38.0f, 84.0f, 26.0f);
    status = er_ui_component_badge(&painter, font, badge, badge_labels[i], badge_variants[i], theme);
    if (status != ER_UI_OK) return status;
    components++;
    text_labels++;
  }
  status = er_ui_component_slider(&painter, er_ui_bounds(card.x + 18.0f, card.y + 152.0f, 220.0f, 28.0f), id++, 0.62f, theme);
  if (status != ER_UI_OK) return status;
  components++;

  card = er_ui_bounds(bounds.x + 392.0f, bounds.y + 324.0f, 336.0f, 208.0f);
  status = er_ui_component_card(&painter, card, theme);
  if (status != ER_UI_OK) return status;
  components++;
  status = er_ui_showcase_section_title(scene, font, "Tabs and rows", card.x + 18.0f, card.y + 32.0f, theme);
  if (status != ER_UI_OK) return status;
  text_labels++;
  status = er_ui_component_tabs(&painter, font, er_ui_bounds(card.x + 18.0f, card.y + 52.0f, 206.0f, 38.0f), id, "Proofs", "Policy", 0u, theme);
  if (status != ER_UI_OK) return status;
  id += 2u;
  components++;
  text_labels += 2u;
  for (size_t i = 0u; i < 3u; ++i) {
    er_ui_bounds_t row = er_ui_bounds(card.x + 18.0f, card.y + 106.0f + (float)i * 30.0f, 276.0f, 26.0f);
    status = er_ui_painter_fill_rect(&painter, row, theme.radius.control, i == 1u ? theme.colors.row : theme.colors.panel);
    if (status != ER_UI_OK) return status;
    status = er_ui_painter_hit(&painter, ER_UI_HIT_LIST_ROW, id++, row);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_text(scene, font, i == 0u ? "Package hash verified" : (i == 1u ? "Publisher policy active" : "Receipt ready"), row.x + 10.0f,
                                  row.y + 19.0f, theme.colors.text);
    if (status != ER_UI_OK) return status;
    components++;
    text_labels++;
  }

  if (out_stats) {
    out_stats->first_id = first_id;
    out_stats->component_count = components;
    out_stats->button_count = buttons;
    out_stats->text_label_count = text_labels;
  }
  return ER_UI_OK;
}
