#include "er_ui_node_internal.h"

er_ui_status_t er_ui_node_render_toast(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!node->active) return er_ui_component_toast_emit(scene, font, bounds, theme, node->label, node->color);
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t icon_box = er_ui_bounds(bounds.x + 10.0f, bounds.y + (bounds.h - 28.0f) * 0.5f, 28.0f, 28.0f);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(icon_box.x, icon_box.y, icon_box.w, icon_box.h, 8.0f, er_ui_color_with_alpha(node->color, 0.18f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(icon_box, 16.0f), node->icon, node->color);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->label, er_ui_bounds(bounds.x + 46.0f, bounds.y, bounds.w - 56.0f, bounds.h), theme.colors.text);
}

er_ui_status_t er_ui_node_render_card_summary(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float pad = 16.0f;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_title_detail(scene, font, node->label, node->detail, inner, theme,
                                        26.0f, 28.0f, 24.0f);
}

er_ui_status_t er_ui_node_render_collapsible(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->active && node->row_count > 0u && (!node->labels || !node->cells)) return ER_UI_ERR_INVALID_ARGUMENT;
  float pad = 12.0f;
  float header_h = er_ui_float_min(36.0f, bounds.h - pad * 2.0f);
  if (header_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t title = er_ui_bounds(inner.x, inner.y, er_ui_float_max(0.0f, inner.w - header_h - 8.0f), header_h);
  er_ui_bounds_t trigger = er_ui_bounds(inner.x + inner.w - header_h, inner.y, header_h, header_h);
  status = er_ui_node_render_text(scene, font, node->label, title, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_button_emit(scene, font, trigger, theme, "", node->id, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_ICON, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(trigger, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.text);
  if (status != ER_UI_OK || !node->active) return status;

  float row_y = inner.y + header_h + node->gap;
  float row_h = 44.0f;
  for (size_t i = 0u; i < node->row_count; ++i) {
    er_ui_bounds_t row = er_ui_bounds(inner.x, row_y, inner.w, row_h);
    status = er_ui_component_list_row_emit(scene, font, row, theme, node->labels[i], node->cells[i], node->id + 1u + (uint32_t)i, false);
    if (status != ER_UI_OK) return status;
    row_y += row_h + node->gap;
  }
  return ER_UI_OK;
}

//@optimizer-ignore-function accordion rendering must visit each row to emit header, trigger, and expanded body
er_ui_status_t er_ui_node_render_accordion(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->row_count == 0u || !node->labels || !node->cells) return ER_UI_ERR_INVALID_ARGUMENT;
  float pad = 8.0f;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;
  float header_h = 40.0f;
  float body_h = 28.0f;
  float divider_h = 1.0f;
  float y = inner.y;
  for (size_t i = 0u; i < node->row_count; ++i) {
    er_ui_bounds_t header = er_ui_bounds(inner.x, y, inner.w, header_h);
    er_ui_bounds_t title = er_ui_bounds(header.x, header.y, er_ui_float_max(0.0f, header.w - header_h - 8.0f), header.h);
    er_ui_bounds_t trigger = er_ui_bounds(header.x + header.w - header_h, header.y, header_h, header_h);
    status = er_ui_node_render_text(scene, font, node->labels[i], title, theme.colors.text);
    if (status != ER_UI_OK) return status;
    status = er_ui_component_button_emit(scene, font, trigger, theme, "", node->id + (uint32_t)i, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_ICON, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_node_render_icon(scene, er_ui_node_center_square(trigger, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.text);
    if (status != ER_UI_OK) return status;
    y += header_h;

    status = er_ui_node_render_text(scene, font, node->cells[i], er_ui_bounds(inner.x, y, inner.w, body_h), theme.colors.muted);
    if (status != ER_UI_OK) return status;
    y += body_h + node->gap;
    if (i + 1u < node->row_count) {
      status = er_ui_component_separator_emit(scene, er_ui_bounds(inner.x, y, inner.w, divider_h), theme);
      if (status != ER_UI_OK) return status;
      y += divider_h + node->gap;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_hover_card(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !node->aux || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float avatar_size = er_ui_float_min(42.0f, bounds.h);
  er_ui_status_t status = er_ui_component_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, avatar_size, avatar_size), theme, node->label, node->color, false);
  if (status != ER_UI_OK) return status;
  float text_x = bounds.x + avatar_size + 12.0f;
  float text_w = er_ui_float_max(bounds.w - avatar_size - 12.0f, 0.0f);
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(text_x, bounds.y, text_w, 20.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(text_x, bounds.y + 22.0f, text_w, 20.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->aux, er_ui_bounds(bounds.x, bounds.y + avatar_size + node->gap, bounds.w, 28.0f), theme.colors.text);
}

er_ui_status_t er_ui_node_render_popover(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->value || !node->detail || !node->aux || !node->extra || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_bounds_t button = er_ui_bounds(bounds.x, bounds.y, er_ui_float_min(bounds.w, 136.0f), 38.0f);
  er_ui_status_t status = er_ui_component_button_emit(scene, font, button, theme, node->label, node->id, ER_UI_COMPONENT_BUTTON_SECONDARY,
                                                   ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + button.h + node->gap, er_ui_float_min(bounds.w, 320.0f), er_ui_float_max(bounds.h - button.h - node->gap, 96.0f));
  status = er_ui_component_card_emit(scene, card, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  status = er_ui_node_render_text(scene, font, node->value, er_ui_bounds(card.x + pad, card.y + pad, card.w - pad * 2.0f, 22.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(card.x + pad, card.y + 34.0f, card.w - pad * 2.0f, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_component_field_emit(scene, font, er_ui_bounds(card.x + pad, card.y + 62.0f, card.w - pad * 2.0f, 54.0f), theme, node->aux, node->extra,
                                 node->id + 1u, false);
}

er_ui_status_t er_ui_node_render_sheet(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->detail || !node->aux || !node->extra || !node->value || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  float pad = 16.0f;
  er_ui_bounds_t inner;
  er_ui_status_t status = er_ui_node_card_inner(scene, bounds, theme, pad, &inner);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_title_detail(scene, font, node->label, node->detail, inner, theme,
                                          24.0f, 26.0f, 22.0f);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_field_emit(scene, font, er_ui_bounds(inner.x, inner.y + 58.0f, inner.w, 54.0f), theme, node->aux, node->extra, node->id, false);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, er_ui_bounds(inner.x, inner.y + 124.0f, er_ui_float_min(inner.w, 160.0f), 40.0f), theme, node->value,
                                  node->id + 1u, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
}

er_ui_status_t er_ui_node_render_kbd(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float x = bounds.x;
  float badge_h = er_ui_float_min(bounds.h, 28.0f);
  float badge_y = bounds.y + (bounds.h - badge_h) * 0.5f;
  for (size_t i = 0u; i < node->label_count; ++i) {
    float badge_w = 22.0f + (float)er_ui_ascii_len(node->labels[i]) * 8.0f;
    er_ui_status_t status = er_ui_component_badge_emit(scene, font, er_ui_bounds(x, badge_y, badge_w, badge_h), theme, node->labels[i], ER_UI_COMPONENT_BADGE_SECONDARY);
    if (status != ER_UI_OK) return status;
    x += badge_w + node->gap;
  }
  return er_ui_node_render_text(scene, font, node->label, er_ui_bounds(x, bounds.y, er_ui_float_max(bounds.x + bounds.w - x, 0.0f), bounds.h), theme.colors.text);
}

er_ui_status_t er_ui_node_render_menubar(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.panel, 0.72f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.border, 0.42f)));
  if (status != ER_UI_OK) return status;

  float pad = 4.0f;
  float inner_h = er_ui_float_max(bounds.h - pad * 2.0f, 1.0f);
  float total_gap = node->gap * (float)(node->label_count - 1u);
  float item_w = (bounds.w - pad * 2.0f - total_gap) / (float)node->label_count;
  if (item_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_bounds_t item = er_ui_bounds(bounds.x + pad + (item_w + node->gap) * (float)i, bounds.y + pad, item_w, inner_h);
    er_ui_component_button_variant_t variant = i == node->selected ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST;
    status = er_ui_component_button_emit(scene, font, item, theme, node->labels[i], node->id + (uint32_t)i, variant, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_radio_group(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float row_h = 30.0f;
  float y = bounds.y;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_status_t status = er_ui_component_radio_emit(scene, font, er_ui_bounds(bounds.x, y, bounds.w, row_h), theme, node->labels[i], i == node->selected,
                                                    node->id + (uint32_t)i);
    if (status != ER_UI_OK) return status;
    y += row_h + node->gap;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_input_group(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !node->value || !node->detail || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float button_w = er_ui_float_min(80.0f, bounds.w * 0.36f);
  float field_w = er_ui_float_max(bounds.w - button_w - node->gap, 1.0f);
  er_ui_bounds_t field = er_ui_bounds(bounds.x, bounds.y, field_w, bounds.h);
  er_ui_bounds_t button = er_ui_bounds(bounds.x + field_w + node->gap, bounds.y + 9.0f, button_w, er_ui_float_max(bounds.h - 18.0f, 24.0f));
  er_ui_status_t status = er_ui_component_field_emit(scene, font, field, theme, node->label, node->value, node->id, false);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, button, theme, node->detail, node->id + 1u, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
}

//@optimizer-ignore-function OTP input rendering must visit each visible character cell
er_ui_status_t er_ui_node_render_input_otp(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float cell_w = 40.0f;
  float dash_w = 18.0f;
  float x = bounds.x;
  for (size_t i = 0u; i < node->label_count; ++i) {
    const char* value = node->labels[i];
    if (!value) return ER_UI_ERR_INVALID_ARGUMENT;
    bool dash = value[0] == '-' && value[1] == 0;
    if (dash) {
      er_ui_status_t status = er_ui_node_render_text(scene, font, value, er_ui_bounds(x, bounds.y, dash_w, bounds.h), theme.colors.muted);
      if (status != ER_UI_OK) return status;
      x += dash_w + node->gap;
      continue;
    }
    er_ui_bounds_t cell = er_ui_bounds(x, bounds.y, cell_w, bounds.h);
    er_ui_status_t status = er_ui_component_field_emit(scene, font, cell, theme, "", value, node->id + (uint32_t)i, false);
    if (status != ER_UI_OK) return status;
    if (i == node->selected) {
      status = er_ui_scene_push_rect(scene, er_ui_rect_border(cell.x, cell.y + 18.0f, cell.w, er_ui_float_max(cell.h - 18.0f, 24.0f), theme.radius.control,
                                                            er_ui_color_with_alpha(theme.colors.accent, 0.78f)));
      if (status != ER_UI_OK) return status;
    }
    x += cell_w + node->gap;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_render_navigation_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u || !node->label || !node->detail || !node->aux || !node->extra ||
      !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  float nav_h = 38.0f;
  float gap = node->gap;
  float total_gap = 4.0f * (float)(node->label_count - 1u);
  float item_w = (er_ui_float_min(bounds.w, 360.0f) - total_gap) / (float)node->label_count;
  if (item_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_bounds_t item = er_ui_bounds(bounds.x + (item_w + 4.0f) * (float)i, bounds.y, item_w, nav_h);
    er_ui_component_button_variant_t variant = i == node->selected ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST;
    er_ui_status_t status = er_ui_component_button_emit(scene, font, item, theme, node->labels[i], node->id + (uint32_t)i, variant, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
  }

  er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + nav_h + gap, er_ui_float_min(bounds.w, 340.0f), er_ui_float_max(bounds.h - nav_h - gap, 92.0f));
  er_ui_status_t status = er_ui_component_card_emit(scene, card, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(card.x + pad, card.y + pad, card.w - pad * 2.0f, 22.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(card.x + pad, card.y + 34.0f, card.w - pad * 2.0f, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_component_list_row_emit(scene, font, er_ui_bounds(card.x + pad, card.y + 62.0f, card.w - pad * 2.0f, 44.0f), theme, node->aux, node->extra,
                                    node->id + (uint32_t)node->label_count, false);
}
