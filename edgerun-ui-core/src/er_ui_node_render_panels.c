#include "er_ui_node_internal.h"

static const char* er_ui_node_label_at(const er_ui_node_t* node, size_t index, const char* default_label) {
  if (!node || !node->labels || index >= node->label_count || !node->labels[index]) return default_label;
  return node->labels[index];
}

er_ui_status_t er_ui_node_render_resizable(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float gap = node->gap;
  float divider_w = 4.0f;
  float first_w = er_ui_float_max((bounds.w - divider_w - gap * 2.0f) * 0.50f, 1.0f);
  float second_w = er_ui_float_max(bounds.w - first_w - divider_w - gap * 2.0f, 1.0f);
  er_ui_bounds_t first = er_ui_bounds(bounds.x, bounds.y, first_w, bounds.h);
  er_ui_bounds_t divider = er_ui_bounds(first.x + first.w + gap, bounds.y, divider_w, bounds.h);
  er_ui_bounds_t right = er_ui_bounds(divider.x + divider.w + gap, bounds.y, second_w, bounds.h);
  float stacked_h = er_ui_float_max((right.h - gap) * 0.5f, 1.0f);
  er_ui_bounds_t second = er_ui_bounds(right.x, right.y, right.w, stacked_h);
  er_ui_bounds_t third = er_ui_bounds(right.x, right.y + stacked_h + gap, right.w, stacked_h);

  er_ui_status_t status = er_ui_component_card_emit(scene, first, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(
    scene,
    font,
    er_ui_node_label_at(node, ER_UI_NODE_RESIZABLE_FIRST_INDEX, "One"),
    er_ui_bounds(first.x + 12.0f, first.y + 8.0f, first.w - 24.0f, 28.0f),
    theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_separator_emit(scene, divider, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_card_emit(scene, second, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(
    scene,
    font,
    er_ui_node_label_at(node, ER_UI_NODE_RESIZABLE_SECOND_INDEX, "Two"),
    er_ui_bounds(second.x + 12.0f, second.y + 8.0f, second.w - 24.0f, 24.0f),
    theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_card_emit(scene, third, theme);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(
    scene,
    font,
    er_ui_node_label_at(node, ER_UI_NODE_RESIZABLE_THIRD_INDEX, "Three"),
    er_ui_bounds(third.x + 12.0f, third.y + 8.0f, third.w - 24.0f, 24.0f),
    theme.colors.text);
}

er_ui_status_t er_ui_node_render_sidebar(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !node->value || !node->aux || !node->labels || node->label_count == 0u ||
      !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_responsive_sidecar_t layout =
    er_ui_responsive_sidecar(bounds, ER_UI_NODE_SIDEBAR_MIN_SIDE_W, ER_UI_NODE_SIDEBAR_PREFERRED_SIDE_W, ER_UI_NODE_SIDEBAR_MIN_MAIN_W, node->gap,
                             ER_UI_NODE_SIDEBAR_STACKED_SIDE_H);
  if (!er_ui_bounds_valid(layout.side) || !er_ui_bounds_valid(layout.main)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t side = layout.side;
  er_ui_bounds_t main = layout.main;
  er_ui_status_t status = er_ui_component_card_emit(scene, side, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_title_detail(
    scene,
    font,
    node->label,
    node->detail,
    er_ui_bounds(side.x + 12.0f, side.y + 8.0f, side.w - 24.0f, 44.0f),
    theme,
    22.0f,
    22.0f,
    20.0f);
  if (status != ER_UI_OK) return status;
  float y = side.y + 54.0f;
  for (size_t i = 0u; i < node->label_count; ++i) {
    status = er_ui_component_menu_item_emit(scene, font, er_ui_bounds(side.x + 8.0f, y, side.w - 16.0f, 34.0f), theme, node->labels[i], "", "", i == node->selected,
                                         theme.colors.accent, node->id + (uint32_t)i);
    if (status != ER_UI_OK) return status;
    y += 38.0f;
  }
  status = er_ui_component_card_emit(scene, main, theme);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_title_detail(
    scene,
    font,
    node->value,
    node->aux,
    er_ui_bounds(main.x + 16.0f, main.y + 14.0f, main.w - 32.0f, 48.0f),
    theme,
    24.0f,
    26.0f,
    22.0f);
}

//@optimizer-ignore-function sonner rendering must visit each queued toast and its icon
er_ui_status_t er_ui_node_render_sonner(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || !node->icons || !node->colors || node->label_count == 0u || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  float toast_h = 48.0f;
  float y = bounds.y;
  float w = er_ui_float_min(bounds.w, 280.0f);
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_bounds_t toast = er_ui_bounds(bounds.x, y, w, toast_h);
    er_ui_status_t status = er_ui_component_toast_emit(scene, font, toast, theme, node->labels[i], node->colors[i]);
    if (status != ER_UI_OK) return status;
    status = er_ui_node_render_icon(scene, er_ui_bounds(toast.x + 10.0f, toast.y + 16.0f, 16.0f, 16.0f), node->icons[i], node->colors[i]);
    if (status != ER_UI_OK) return status;
    y += toast_h + node->gap;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_aspect_ratio(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 0.0f;
  float max_w = bounds.w - pad * 2.0f;
  float max_h = bounds.h - pad * 2.0f;
  float panel_w = max_w;
  float panel_h = panel_w * 9.0f / 16.0f;
  if (panel_h > max_h) {
    panel_h = max_h;
    panel_w = panel_h * 16.0f / 9.0f;
  }
  er_ui_bounds_t panel = er_ui_bounds(bounds.x + (bounds.w - panel_w) * 0.5f, bounds.y + (bounds.h - panel_h) * 0.5f, panel_w, panel_h);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(panel.x, panel.y, panel.w, panel.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.row, 0.62f)));
  if (status != ER_UI_OK) return status;
  float center_y = panel.y + panel.h * 0.5f;
  status = er_ui_node_render_icon(scene, er_ui_bounds(panel.x + (panel.w - 32.0f) * 0.5f, center_y - 32.0f, 32.0f, 32.0f), node->icon, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->label, er_ui_bounds(panel.x + 12.0f, center_y + 8.0f, panel.w - 24.0f, 28.0f), theme.colors.text);
}

er_ui_status_t er_ui_node_render_alert_dialog(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t icon_box = er_ui_bounds(bounds.x + 18.0f, bounds.y + 18.0f, 36.0f, 36.0f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(icon_box.x, icon_box.y, icon_box.w, icon_box.h, 10.0f, er_ui_color_with_alpha(theme.colors.warning, 0.24f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(icon_box, 20.0f), node->icon, theme.colors.warning);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(bounds.x + 66.0f, bounds.y + 20.0f, bounds.w - 84.0f, 28.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(bounds.x + 66.0f, bounds.y + 48.0f, bounds.w - 84.0f, 44.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_component_separator_emit(scene, er_ui_bounds(bounds.x + 18.0f, bounds.y + 92.0f, bounds.w - 36.0f, 1.0f), theme);
}

er_ui_status_t er_ui_node_render_direction(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float row_h = er_ui_float_min(28.0f, (bounds.h - node->gap) * 0.5f);
  if (row_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  float badge_w = 44.0f;
  er_ui_bounds_t ltr_badge = er_ui_bounds(bounds.x, bounds.y + 1.0f, badge_w, 26.0f);
  er_ui_status_t status = er_ui_component_badge_emit(scene, font, ltr_badge, theme, "LTR", ER_UI_COMPONENT_BADGE_DEFAULT);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(bounds.x + badge_w + node->gap, bounds.y, bounds.w - badge_w - node->gap, row_h),
                                  theme.colors.text);
  if (status != ER_UI_OK) return status;

  float y = bounds.y + row_h + node->gap;
  er_ui_bounds_t rtl_badge = er_ui_bounds(bounds.x + er_ui_float_max(bounds.w - badge_w, 0.0f), y + 1.0f, badge_w, 26.0f);
  float rtl_text_w = er_ui_float_max(bounds.w - badge_w - node->gap, 0.0f);
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(bounds.x, y, rtl_text_w, row_h), theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_component_badge_emit(scene, font, rtl_badge, theme, "RTL", ER_UI_COMPONENT_BADGE_SECONDARY);
}

er_ui_status_t er_ui_node_render_drawer(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !node->aux || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float pad = 16.0f;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_title_detail(scene, font, node->label, node->detail, inner, theme,
                                          24.0f, 26.0f, 22.0f);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_slider_emit(scene, font, er_ui_bounds(inner.x, inner.y + 62.0f, inner.w, 48.0f), theme, node->aux, node->number, node->id);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, er_ui_bounds(inner.x, inner.y + 122.0f, er_ui_float_min(inner.w, 120.0f), 40.0f), theme, "Submit",
                                  node->id + 1u, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
}

er_ui_status_t er_ui_node_render_menu_items(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float row_h) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float y = bounds.y;
  for (size_t i = 0u; i < node->label_count; ++i) {
    const char* shortcut = node->cells ? node->cells[i] : "";
    er_ui_status_t status = er_ui_component_menu_item_emit(scene, font, er_ui_bounds(bounds.x, y, bounds.w, row_h), theme, node->labels[i], shortcut, "",
                                                        i == node->selected, theme.colors.accent, node->id + (uint32_t)i);
    if (status != ER_UI_OK) return status;
    y += row_h + node->gap;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_dropdown_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  return er_ui_node_render_menu_items(node, scene, font, bounds, theme, 44.0f);
}

er_ui_status_t er_ui_node_render_context_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  float pad = 12.0f;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_title_detail(scene, font, node->label, node->detail, inner, theme,
                                          24.0f, 24.0f, 22.0f);
  if (status != ER_UI_OK) return status;

  return er_ui_node_render_menu_items(node, scene, font, er_ui_bounds(inner.x, inner.y + 54.0f, inner.w, inner.h - 54.0f), theme, 44.0f);
}

er_ui_status_t er_ui_node_render_date_picker(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_bounds_t trigger = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 140.0f), 38.0f);
  er_ui_status_t status = er_ui_component_button_emit(scene, font, trigger, theme, node->label, node->id, ER_UI_COMPONENT_BUTTON_SECONDARY,
                                                   ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + trigger.h + node->gap, er_ui_float_min(bounds.w, 360.0f),
                                     er_ui_float_max(bounds.h - trigger.h - node->gap, 84.0f));
  status = er_ui_component_card_emit(scene, card, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  er_ui_bounds_t inner = er_ui_bounds(card.x + pad, card.y + pad, card.w - pad * 2.0f, card.h - pad * 2.0f);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(inner.x, inner.y, inner.w, 24.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;

  float gap = 4.0f;
  float total_gap = gap * (float)(node->label_count - 1u);
  float day_w = (inner.w - total_gap) / (float)node->label_count;
  if (day_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  float day_y = inner.y + 32.0f;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_component_button_variant_t variant = i == node->selected ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(inner.x + (day_w + gap) * (float)i, day_y, day_w, 38.0f), theme, node->labels[i],
                                      node->id + 1u + (uint32_t)i, variant, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

//@optimizer-ignore-function carousel rendering must visit each visible slide card in order
er_ui_status_t er_ui_node_render_carousel(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float button_w = er_ui_float_min(40.0f, bounds.w * 0.18f);
  float gap = node->gap;
  float cards_w = bounds.w - button_w * 2.0f - gap * (float)(node->label_count + 1u);
  float card_w = cards_w / (float)node->label_count;
  if (button_w <= 0.0f || card_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_bounds_t prev = er_ui_bounds(bounds.x, bounds.y + (bounds.h - button_w) * 0.5f, button_w, button_w);
  er_ui_status_t status = er_ui_component_button_emit(scene, font, prev, theme, "", node->id, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_ICON, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(prev, 16.0f), ER_UI_ICON_CHEVRON_LEFT, theme.colors.text);
  if (status != ER_UI_OK) return status;

  float x = bounds.x + button_w + gap;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_bounds_t card = er_ui_bounds(x, bounds.y, card_w, bounds.h);
    status = er_ui_component_card_emit(scene, card, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_node_render_text(scene, font, node->labels[i], er_ui_bounds(card.x + 16.0f, card.y + (card.h - 28.0f) * 0.5f, card.w - 32.0f, 28.0f),
                                    theme.colors.text);
    if (status != ER_UI_OK) return status;
    x += card_w + gap;
  }

  er_ui_bounds_t next = er_ui_bounds(x, bounds.y + (bounds.h - button_w) * 0.5f, button_w, button_w);
  status = er_ui_component_button_emit(scene, font, next, theme, "", node->id + 1u, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_ICON, true);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_icon(scene, er_ui_node_center_square(next, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.text);
}

//@optimizer-ignore-function calendar rendering must visit each weekday header and day cell
er_ui_status_t er_ui_node_render_calendar(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float pad = 12.0f;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t prev = er_ui_bounds(inner.x, inner.y, 36.0f, 36.0f);
  status = er_ui_component_button_emit(scene, font, prev, theme, "", node->id, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_ICON, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(prev, 16.0f), ER_UI_ICON_CHEVRON_LEFT, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(inner.x + 44.0f, inner.y + 4.0f, inner.w - 88.0f, 28.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t next = er_ui_bounds(inner.x + inner.w - 36.0f, inner.y, 36.0f, 36.0f);
  status = er_ui_component_button_emit(scene, font, next, theme, "", node->id + 1u, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_ICON, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(next, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.text);
  if (status != ER_UI_OK) return status;

  static const char* const weekdays[] = {"S", "M", "T", "W", "T", "F", "S"};
  float gap = 4.0f;
  float cell_w = (inner.w - gap * 6.0f) / 7.0f;
  if (cell_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  float header_y = inner.y + 46.0f;
  for (size_t i = 0u; i < 7u; ++i) {
    status = er_ui_node_render_text(scene, font, weekdays[i], er_ui_bounds(inner.x + (cell_w + gap) * (float)i, header_y, cell_w, 22.0f), theme.colors.muted);
    if (status != ER_UI_OK) return status;
  }
  float day_y = header_y + 28.0f;
  size_t col = 0u;
  size_t row = 0u;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_component_button_variant_t variant = i == node->selected ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(inner.x + (cell_w + gap) * (float)col, day_y + 38.0f * (float)row, cell_w, 34.0f), theme,
                                      node->labels[i], node->id + 2u + (uint32_t)i, variant, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
    ++col;
    if (col == 7u) {
      col = 0u;
      ++row;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_combobox(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->value || !node->detail || !node->labels || node->label_count == 0u ||
      !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_status_t status = er_ui_component_select_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, bounds.w, 46.0f), theme, node->label, node->value,
                                                   node->id, false);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_command_palette_emit(scene, font, er_ui_bounds(bounds.x, bounds.y + 46.0f + node->gap, bounds.w, 46.0f), theme, node->detail,
                                             node->id + 1u);
  if (status != ER_UI_OK) return status;
  float y = bounds.y + 46.0f + node->gap + 46.0f + node->gap;
  for (size_t i = 0u; i < node->label_count; ++i) {
    status = er_ui_component_menu_item_emit(scene, font, er_ui_bounds(bounds.x, y, bounds.w, 44.0f), theme, node->labels[i], "", "",
                                         i == node->selected, theme.colors.accent, node->id + 2u + (uint32_t)i);
    if (status != ER_UI_OK) return status;
    y += 44.0f + node->gap;
  }
  return ER_UI_OK;
}
