#include "er_ui_node_internal.h"

er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds) {
  if (!node) return bounds;
  er_ui_bounds_t resolved = er_ui_bounds_valid(node->bounds) ? node->bounds : bounds;
  if (node->margin > 0.0f) return er_ui_bounds_inset(resolved, node->margin, node->margin);
  return resolved;
}

static er_ui_status_t er_ui_node_emit_chrome(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  (void)bounds;
  (void)theme;
  if (node->has_transition) {
    er_ui_status_t status = er_ui_scene_push_transition(scene, node->transition);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_emit_background_gradient(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->has_background_gradient) {
    return er_ui_scene_push_rect(scene,
                                 er_ui_rect_linear_gradient(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, node->background_gradient_from,
                                                           node->background_gradient_to));
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_emit_card_surface(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!node->has_background_gradient) return er_ui_component_card_emit(scene, bounds, theme);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_shadow(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card,
                                                                         er_ui_color_rgba(0.0f, 0.0f, 0.0f, 0.10f), 18.0f));
  if (status != ER_UI_OK) return status;
  status = er_ui_node_emit_background_gradient(node, scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card,
                                                       er_ui_color_with_alpha(theme.colors.border, 0.42f)));
}

static er_ui_status_t er_ui_node_emit_interaction(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->has_drag_source) {
    er_ui_drag_source_t source = node->drag_source;
    source.x = bounds.x;
    source.y = bounds.y;
    source.w = bounds.w;
    source.h = bounds.h;
    er_ui_status_t status = er_ui_scene_push_drag_source(scene, source);
    if (status != ER_UI_OK) return status;
  }
  if (node->has_drop_target) {
    er_ui_drop_target_t target = node->drop_target;
    target.x = bounds.x;
    target.y = bounds.y;
    target.w = bounds.w;
    target.h = bounds.h;
    er_ui_status_t status = er_ui_scene_push_drop_target(scene, target);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

//@optimizer-ignore-function node layout must recursively render each child in declaration order
static er_ui_status_t er_ui_node_render_children(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_OK;
  for (size_t i = 0u; i < node->child_count; ++i) {
    er_ui_bounds_t child_bounds = {0};
    er_ui_status_t bounds_status = er_ui_node_child_bounds(node, i, bounds, &child_bounds);
    if (bounds_status != ER_UI_OK) return bounds_status;
    er_ui_status_t status = er_ui_node_render(node->children[i], scene, font, child_bounds, theme);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_render_scroll_area(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->id != 0u) {
    er_ui_status_t hit_status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SCROLL_AREA, node->id, bounds.x, bounds.y, bounds.w, bounds.h));
    if (hit_status != ER_UI_OK) return hit_status;
  }
  bool pushed = false;
  er_ui_status_t status = er_ui_scene_push_clip(scene, er_ui_clip(bounds.x, bounds.y, bounds.w, bounds.h), &pushed);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_children(node, scene, font, bounds, theme);
  if (pushed) er_ui_scene_pop_clip(scene);
  return status;
}

static er_ui_status_t er_ui_node_render_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, er_ui_bounds_t bounds, er_ui_color4_t color) {
  if (!scene || !font || !text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_NODE_TEXT_BUDGET, bounds.x, bounds.y + er_ui_float_min(bounds.h * 0.62f, 22.0f), color);
}

static er_ui_status_t er_ui_node_render_icon(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_icon_t icon, er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_icon(&painter, bounds, icon, color);
}

static er_ui_bounds_t er_ui_node_center_square(er_ui_bounds_t bounds, float size);

static er_ui_status_t er_ui_node_card_inner(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float pad,
  er_ui_bounds_t* out_inner) {
  if (!out_inner) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_inner = inner;
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_render_toast(
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

static er_ui_status_t er_ui_node_render_card_summary(
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
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(inner.x, inner.y, inner.w, 26.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(inner.x, inner.y + 28.0f, inner.w, 24.0f),
                                theme.colors.muted);
}

static er_ui_status_t er_ui_node_render_collapsible(
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
static er_ui_status_t er_ui_node_render_accordion(
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

static er_ui_status_t er_ui_node_render_hover_card(
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

static er_ui_status_t er_ui_node_render_popover(
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

static er_ui_status_t er_ui_node_render_sheet(
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
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(inner.x, inner.y, inner.w, 24.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(inner.x, inner.y + 26.0f, inner.w, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_field_emit(scene, font, er_ui_bounds(inner.x, inner.y + 58.0f, inner.w, 54.0f), theme, node->aux, node->extra, node->id, false);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, er_ui_bounds(inner.x, inner.y + 124.0f, er_ui_float_min(inner.w, 160.0f), 40.0f), theme, node->value,
                                  node->id + 1u, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
}

static er_ui_status_t er_ui_node_render_kbd(
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

static er_ui_status_t er_ui_node_render_menubar(
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

static er_ui_status_t er_ui_node_render_radio_group(
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

static er_ui_status_t er_ui_node_render_input_group(
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
static er_ui_status_t er_ui_node_render_input_otp(
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

static er_ui_status_t er_ui_node_render_navigation_menu(
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

static const char* er_ui_node_label_or_default(const er_ui_node_t* node, size_t index, const char* fallback) {
  if (!node || !node->labels || index >= node->label_count || !node->labels[index]) return fallback;
  return node->labels[index];
}

static er_ui_status_t er_ui_node_render_resizable(
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
    er_ui_node_label_or_default(node, ER_UI_NODE_RESIZABLE_FIRST_INDEX, "One"),
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
    er_ui_node_label_or_default(node, ER_UI_NODE_RESIZABLE_SECOND_INDEX, "Two"),
    er_ui_bounds(second.x + 12.0f, second.y + 8.0f, second.w - 24.0f, 24.0f),
    theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_card_emit(scene, third, theme);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(
    scene,
    font,
    er_ui_node_label_or_default(node, ER_UI_NODE_RESIZABLE_THIRD_INDEX, "Three"),
    er_ui_bounds(third.x + 12.0f, third.y + 8.0f, third.w - 24.0f, 24.0f),
    theme.colors.text);
}

static er_ui_status_t er_ui_node_render_sidebar(
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
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(side.x + 12.0f, side.y + 8.0f, side.w - 24.0f, 22.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(side.x + 12.0f, side.y + 30.0f, side.w - 24.0f, 20.0f), theme.colors.muted);
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
  status = er_ui_node_render_text(scene, font, node->value, er_ui_bounds(main.x + 16.0f, main.y + 14.0f, main.w - 32.0f, 24.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->aux, er_ui_bounds(main.x + 16.0f, main.y + 40.0f, main.w - 32.0f, 22.0f), theme.colors.muted);
}

//@optimizer-ignore-function sonner rendering must visit each queued toast and its icon
static er_ui_status_t er_ui_node_render_sonner(
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

static er_ui_status_t er_ui_node_render_aspect_ratio(
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

static er_ui_status_t er_ui_node_render_alert_dialog(
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

static er_ui_status_t er_ui_node_render_direction(
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

static er_ui_status_t er_ui_node_render_drawer(
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
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(inner.x, inner.y, inner.w, 24.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(inner.x, inner.y + 26.0f, inner.w, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_slider_emit(scene, font, er_ui_bounds(inner.x, inner.y + 62.0f, inner.w, 48.0f), theme, node->aux, node->number, node->id);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, er_ui_bounds(inner.x, inner.y + 122.0f, er_ui_float_min(inner.w, 120.0f), 40.0f), theme, "Submit",
                                  node->id + 1u, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
}

static er_ui_status_t er_ui_node_render_menu_items(
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

static er_ui_status_t er_ui_node_render_dropdown_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  return er_ui_node_render_menu_items(node, scene, font, bounds, theme, 44.0f);
}

static er_ui_status_t er_ui_node_render_context_menu(
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
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(inner.x, inner.y, inner.w, 24.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(inner.x, inner.y + 24.0f, inner.w, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;

  return er_ui_node_render_menu_items(node, scene, font, er_ui_bounds(inner.x, inner.y + 54.0f, inner.w, inner.h - 54.0f), theme, 44.0f);
}

static er_ui_status_t er_ui_node_render_date_picker(
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
static er_ui_status_t er_ui_node_render_carousel(
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
static er_ui_status_t er_ui_node_render_calendar(
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

static er_ui_status_t er_ui_node_render_combobox(
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

static bool er_ui_node_diff_line_starts_with(const char* line, const char* prefix) {
  if (!line || !prefix) return false;
  size_t i = 0u;
  while (prefix[i]) {
    if (line[i] != prefix[i]) return false;
    i++;
  }
  return true;
}

static er_ui_color4_t er_ui_node_diff_line_color(const char* line, er_ui_resolved_theme_t theme) {
  if (er_ui_node_diff_line_starts_with(line, "+") && !er_ui_node_diff_line_starts_with(line, "+++")) return theme.colors.success;
  if (er_ui_node_diff_line_starts_with(line, "-") && !er_ui_node_diff_line_starts_with(line, "---")) return theme.colors.danger;
  if (er_ui_node_diff_line_starts_with(line, "@@") || er_ui_node_diff_line_starts_with(line, "***")) return theme.colors.muted;
  return theme.colors.text;
}

//@optimizer-ignore-function diff viewer rendering must visit each visible diff line
static er_ui_status_t er_ui_node_render_diff_body(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float y = bounds.y;
  float line_h = 20.0f;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_status_t status = er_ui_node_render_text(scene, font, node->labels[i], er_ui_bounds(bounds.x, y, bounds.w, line_h),
                                                   er_ui_node_diff_line_color(node->labels[i], theme));
    if (status != ER_UI_OK) return status;
    y += line_h + node->gap;
  }
  if (node->active) {
    return er_ui_node_render_text(scene, font, "[diff preview truncated]", er_ui_bounds(bounds.x, y, bounds.w, line_h), theme.colors.muted);
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_render_chat_header(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  er_ui_component_chat_role_t role,
  const char* heading,
  float icon_size) {
  if (!scene || !font || !heading || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_node_render_icon(scene, er_ui_bounds(bounds.x, bounds.y + (bounds.h - icon_size) * 0.5f, icon_size, icon_size),
                                                 er_ui_component_chat_role_icon(role), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  float badge_x = bounds.x + icon_size + 8.0f;
  status = er_ui_component_badge_emit(scene, font, er_ui_bounds(badge_x, bounds.y + (bounds.h - 24.0f) * 0.5f, 92.0f, 24.0f), theme,
                                   er_ui_component_chat_role_label(role), er_ui_component_chat_role_badge(role));
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, heading, er_ui_bounds(badge_x + 100.0f, bounds.y, er_ui_float_max(bounds.w - badge_x - 100.0f, 0.0f), bounds.h),
                                theme.colors.muted);
}

static er_ui_status_t er_ui_node_render_chat_message(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_component_chat_role_t role = (er_ui_component_chat_role_t)node->selected;
  if (role == ER_UI_COMPONENT_CHAT_ROLE_DIFF) {
    if (!node->labels || node->label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
    if (status != ER_UI_OK) return status;
    float pad = 12.0f;
    er_ui_bounds_t header = er_ui_bounds(bounds.x + pad, bounds.y + pad, bounds.w - pad * 2.0f, 28.0f);
    status = er_ui_node_render_chat_header(scene, font, header, theme, role, node->label, 16.0f);
    if (status != ER_UI_OK) return status;
    er_ui_node_t diff = er_ui_node_diff_body(node->labels, node->label_count, node->active);
    return er_ui_node_render_diff_body(&diff, scene, font, er_ui_bounds(bounds.x + pad, bounds.y + 48.0f, bounds.w - pad * 2.0f, bounds.h - 60.0f), theme);
  }

  if (!node->detail) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_component_chat_role_timeline(role)) {
    er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, theme.colors.bg));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, er_ui_color_with_alpha(theme.colors.border, 0.42f)));
    if (status != ER_UI_OK) return status;
    float pad = 12.0f;
    status = er_ui_node_render_icon(scene, er_ui_bounds(bounds.x + pad, bounds.y + pad, 20.0f, 20.0f), er_ui_component_chat_role_icon(role), theme.colors.muted);
    if (status != ER_UI_OK) return status;
    float text_x = bounds.x + pad + 32.0f;
    er_ui_bounds_t header = er_ui_bounds(text_x, bounds.y + pad - 2.0f, bounds.w - text_x + bounds.x - pad, 28.0f);
    status = er_ui_component_badge_emit(scene, font, er_ui_bounds(header.x, header.y + 2.0f, 92.0f, 24.0f), theme, er_ui_component_chat_role_label(role),
                                     er_ui_component_chat_role_badge(role));
    if (status != ER_UI_OK) return status;
    status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(header.x + 100.0f, header.y, er_ui_float_max(header.w - 100.0f, 0.0f), header.h),
                                    theme.colors.muted);
    if (status != ER_UI_OK) return status;
    return er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(text_x, bounds.y + 42.0f, bounds.w - text_x + bounds.x - pad, bounds.h - 48.0f),
                                  theme.colors.text);
  }

  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  status = er_ui_node_render_chat_header(scene, font, er_ui_bounds(bounds.x + pad, bounds.y + pad, bounds.w - pad * 2.0f, 28.0f), theme, role, node->label, 16.0f);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(bounds.x + pad, bounds.y + 48.0f, bounds.w - pad * 2.0f, bounds.h - 56.0f),
                                theme.colors.text);
}

static er_ui_status_t er_ui_node_render_label_group(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  bool toggle_group) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  float gap = toggle_group ? 4.0f : 0.0f;
  float total_gap = gap * (float)(node->label_count - 1u);
  float item_w = (bounds.w - total_gap) / (float)node->label_count;
  if (item_w <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_bounds_t item = er_ui_bounds(bounds.x + (item_w + gap) * (float)i, bounds.y, item_w, bounds.h);
    er_ui_component_button_variant_t variant = ER_UI_COMPONENT_BUTTON_SECONDARY;
    if (toggle_group && i != node->selected) variant = ER_UI_COMPONENT_BUTTON_GHOST;
    er_ui_status_t status = er_ui_component_button_emit(scene, font, item, theme, node->labels[i], node->id + (uint32_t)i, variant, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_render_pagination(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->labels || node->label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t item_count = node->label_count + 2u;
  float gap = node->gap;
  float total_gap = gap * (float)(item_count - 1u);
  float page_w = 42.0f;
  float previous_w = 90.0f;
  float next_w = 68.0f;
  float needed_w = previous_w + next_w + page_w * (float)node->label_count + total_gap;
  if (bounds.w < needed_w) {
    float scale = bounds.w / needed_w;
    previous_w *= scale;
    next_w *= scale;
    page_w *= scale;
  }
  float x = bounds.x;
  er_ui_status_t status = er_ui_component_button_emit(scene, font, er_ui_bounds(x, bounds.y, previous_w, bounds.h), theme, "Previous", node->id,
                                                   ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, false);
  if (status != ER_UI_OK) return status;
  x += previous_w + gap;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_component_button_variant_t variant = i == node->selected ? ER_UI_COMPONENT_BUTTON_SECONDARY : ER_UI_COMPONENT_BUTTON_GHOST;
    status = er_ui_component_button_emit(scene, font, er_ui_bounds(x, bounds.y, page_w, bounds.h), theme, node->labels[i], node->id + 1u + (uint32_t)i,
                                      variant, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    x += page_w + gap;
  }
  return er_ui_component_button_emit(scene, font, er_ui_bounds(x, bounds.y, next_w, bounds.h), theme, "Next", node->id + 1u + (uint32_t)node->label_count,
                                  ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true);
}

static er_ui_bounds_t er_ui_node_center_square(er_ui_bounds_t bounds, float size) {
  float w = er_ui_float_min(size, er_ui_float_min(bounds.w, bounds.h));
  return er_ui_bounds(bounds.x + (bounds.w - w) * 0.5f, bounds.y + (bounds.h - w) * 0.5f, w, w);
}

er_ui_status_t er_ui_node_render(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_node_composition_issue_t composition_issue = {0};
  er_ui_status_t composition_status = er_ui_node_validate_composition(node, &composition_issue);
  if (composition_status != ER_UI_OK) return composition_status;
  er_ui_bounds_t rect = er_ui_node_resolve_bounds(node, bounds);
  er_ui_status_t chrome_status = er_ui_node_emit_chrome(node, scene, rect, theme);
  if (chrome_status != ER_UI_OK) return chrome_status;
  er_ui_status_t interaction_status = er_ui_node_emit_interaction(node, scene, rect);
  if (interaction_status != ER_UI_OK) return interaction_status;
  switch (node->kind) {
    case ER_UI_NODE_ROW: {
      er_ui_status_t status = er_ui_node_emit_background_gradient(node, scene, rect, theme);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_children(node, scene, font, rect, theme);
    }
    case ER_UI_NODE_COLUMN: {
      er_ui_status_t status = er_ui_node_emit_background_gradient(node, scene, rect, theme);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_children(node, scene, font, rect, theme);
    }
    case ER_UI_NODE_CARD: {
      er_ui_status_t status = er_ui_node_emit_card_surface(node, scene, rect, theme);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_children(node, scene, font, rect, theme);
    }
    case ER_UI_NODE_ICON:
      return er_ui_node_render_icon(scene, er_ui_node_center_square(rect, 20.0f), node->icon, node->color.a > 0.0f ? node->color : theme.colors.muted);
    case ER_UI_NODE_TEXT:
      return er_ui_node_render_text(scene, font, node->label, rect, theme.colors.text);
    case ER_UI_NODE_BADGE:
      return er_ui_component_badge_emit(scene, font, rect, theme, node->label, node->badge_variant);
    case ER_UI_NODE_BUTTON:
      return er_ui_component_button_emit(scene, font, rect, theme, node->label, node->id, node->button_variant, node->button_size, node->active);
    case ER_UI_NODE_CARD_SUMMARY:
      return er_ui_node_render_card_summary(node, scene, font, rect, theme);
    case ER_UI_NODE_BUTTON_GROUP:
      return er_ui_node_render_label_group(node, scene, font, rect, theme, false);
    case ER_UI_NODE_ICON_BUTTON: {
      er_ui_status_t status = er_ui_component_button_emit(scene, font, rect, theme, "", node->id, node->button_variant, ER_UI_COMPONENT_BUTTON_SIZE_ICON, node->active);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_icon(scene, er_ui_node_center_square(rect, 16.0f), node->icon, theme.colors.text);
    }
    case ER_UI_NODE_CHECKBOX:
      return er_ui_component_checkbox_emit(scene, font, rect, theme, node->label, node->active, node->id);
    case ER_UI_NODE_RADIO:
      return er_ui_component_radio_emit(scene, font, rect, theme, node->label, node->active, node->id);
    case ER_UI_NODE_SELECT:
      return er_ui_component_select_emit(scene, font, rect, theme, node->label, node->value, node->id, false);
    case ER_UI_NODE_SLIDER:
      return er_ui_component_slider_emit(scene, font, rect, theme, node->label, node->number, node->id);
    case ER_UI_NODE_SEPARATOR:
      return er_ui_component_separator_emit(scene, rect, theme);
    case ER_UI_NODE_SKELETON:
      return er_ui_component_skeleton_emit(scene, rect, theme);
    case ER_UI_NODE_ALERT:
      return er_ui_component_alert_emit(scene, font, rect, theme, node->label, node->detail, node->color);
    case ER_UI_NODE_AVATAR:
      return er_ui_component_avatar_emit(scene, font, rect, theme, node->label, node->color, node->active);
    case ER_UI_NODE_PROGRESS:
      return er_ui_component_progress_emit(scene, rect, theme, node->number);
    case ER_UI_NODE_SWITCH:
      return er_ui_component_switch_emit(scene, rect, theme, node->active, node->id);
    case ER_UI_NODE_TOGGLE_GROUP:
      return er_ui_node_render_label_group(node, scene, font, rect, theme, true);
    case ER_UI_NODE_TABLE:
      return er_ui_component_table_emit(scene, font, rect, theme, node->labels, node->label_count, node->cells, node->row_count, node->id);
    case ER_UI_NODE_BREADCRUMB:
      return er_ui_component_breadcrumb_emit(scene, font, rect, theme, node->labels, node->label_count, node->selected, node->id);
    case ER_UI_NODE_TOAST:
      return er_ui_node_render_toast(node, scene, font, rect, theme);
    case ER_UI_NODE_EMPTY:
      return er_ui_component_empty_emit(scene, font, rect, theme, node->label, node->detail);
    case ER_UI_NODE_LIST_ROW:
      return er_ui_component_list_row_emit(scene, font, rect, theme, node->label, node->detail, node->id, node->active);
    case ER_UI_NODE_FIELD:
      return er_ui_component_field_emit(scene, font, rect, theme, node->label, node->value, node->id, false);
    case ER_UI_NODE_TEXT_AREA:
      return er_ui_component_field_emit(scene, font, rect, theme, node->label, node->value, node->id, true);
    case ER_UI_NODE_TABS:
      return er_ui_component_tabs_emit(scene, font, rect, theme, node->labels, node->label_count, node->selected, node->id);
    case ER_UI_NODE_BAR_CHART:
      return er_ui_component_bar_chart_emit(scene, font, rect, theme, node->label, node->labels, node->values, node->value_count, node->id, node->selected);
    case ER_UI_NODE_COMMAND_PALETTE:
      return er_ui_component_command_palette_emit(scene, font, rect, theme, node->label, node->id);
    case ER_UI_NODE_TREE_ITEM:
      return er_ui_component_tree_item_emit(scene, font, rect, theme, node->label, node->detail, (uint8_t)node->number, node->active, node->id);
    case ER_UI_NODE_SECTION:
      return er_ui_component_section_header_emit(scene, font, rect, theme, node->label, node->detail);
    case ER_UI_NODE_IDENTITY_CARD:
      return er_ui_component_identity_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_CONTACT_CARD:
      return er_ui_component_contact_card_emit(scene, font, rect, theme, node->label, node->detail, node->id);
    case ER_UI_NODE_THREAD_ROW:
      return er_ui_component_thread_row_emit(scene, font, rect, theme, node->label, node->detail, node->active, node->id);
    case ER_UI_NODE_ATTACHMENT_PREVIEW:
      return er_ui_component_attachment_preview_emit(scene, font, rect, theme, node->label, node->detail, node->id);
    case ER_UI_NODE_CAPABILITY_GRANT_ROW:
      return er_ui_component_capability_grant_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_PROOF_EVENT_ROW:
      return er_ui_component_proof_event_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_PAGINATION:
      return er_ui_node_render_pagination(node, scene, font, rect, theme);
    case ER_UI_NODE_COLLAPSIBLE:
      return er_ui_node_render_collapsible(node, scene, font, rect, theme);
    case ER_UI_NODE_ACCORDION:
      return er_ui_node_render_accordion(node, scene, font, rect, theme);
    case ER_UI_NODE_HOVER_CARD:
      return er_ui_node_render_hover_card(node, scene, font, rect, theme);
    case ER_UI_NODE_POPOVER:
      return er_ui_node_render_popover(node, scene, font, rect, theme);
    case ER_UI_NODE_SHEET:
      return er_ui_node_render_sheet(node, scene, font, rect, theme);
    case ER_UI_NODE_KBD:
      return er_ui_node_render_kbd(node, scene, font, rect, theme);
    case ER_UI_NODE_MENUBAR:
      return er_ui_node_render_menubar(node, scene, font, rect, theme);
    case ER_UI_NODE_RADIO_GROUP:
      return er_ui_node_render_radio_group(node, scene, font, rect, theme);
    case ER_UI_NODE_INPUT_GROUP:
      return er_ui_node_render_input_group(node, scene, font, rect, theme);
    case ER_UI_NODE_INPUT_OTP:
      return er_ui_node_render_input_otp(node, scene, font, rect, theme);
    case ER_UI_NODE_NAVIGATION_MENU:
      return er_ui_node_render_navigation_menu(node, scene, font, rect, theme);
    case ER_UI_NODE_RESIZABLE:
      return er_ui_node_render_resizable(node, scene, font, rect, theme);
    case ER_UI_NODE_SIDEBAR:
      return er_ui_node_render_sidebar(node, scene, font, rect, theme);
    case ER_UI_NODE_SONNER:
      return er_ui_node_render_sonner(node, scene, font, rect, theme);
    case ER_UI_NODE_ASPECT_RATIO:
      return er_ui_node_render_aspect_ratio(node, scene, font, rect, theme);
    case ER_UI_NODE_ALERT_DIALOG:
      return er_ui_node_render_alert_dialog(node, scene, font, rect, theme);
    case ER_UI_NODE_DIRECTION:
      return er_ui_node_render_direction(node, scene, font, rect, theme);
    case ER_UI_NODE_DRAWER:
      return er_ui_node_render_drawer(node, scene, font, rect, theme);
    case ER_UI_NODE_DROPDOWN_MENU:
      return er_ui_node_render_dropdown_menu(node, scene, font, rect, theme);
    case ER_UI_NODE_CONTEXT_MENU:
      return er_ui_node_render_context_menu(node, scene, font, rect, theme);
    case ER_UI_NODE_DATE_PICKER:
      return er_ui_node_render_date_picker(node, scene, font, rect, theme);
    case ER_UI_NODE_CAROUSEL:
      return er_ui_node_render_carousel(node, scene, font, rect, theme);
    case ER_UI_NODE_CALENDAR:
      return er_ui_node_render_calendar(node, scene, font, rect, theme);
    case ER_UI_NODE_COMBOBOX:
      return er_ui_node_render_combobox(node, scene, font, rect, theme);
    case ER_UI_NODE_DIFF_BODY:
      return er_ui_node_render_diff_body(node, scene, font, rect, theme);
    case ER_UI_NODE_CHAT_MESSAGE:
      return er_ui_node_render_chat_message(node, scene, font, rect, theme);
    case ER_UI_NODE_CONVERSATION:
      return er_ui_node_render_scroll_area(node, scene, font, rect, theme);
    case ER_UI_NODE_ROUTE_PATH:
      return er_ui_component_route_path_emit(scene, font, rect, theme, node->label, node->labels, node->label_count);
    case ER_UI_NODE_PACKAGE_CARD:
      return er_ui_component_package_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_RECEIPT_ROW:
      return er_ui_component_receipt_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_PANEL_HEADER:
      return er_ui_component_panel_header_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->id);
    case ER_UI_NODE_METRIC_CARD:
      return er_ui_component_metric_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->active, node->number, node->color);
    case ER_UI_NODE_TRANSACTION_ROW:
      return er_ui_component_transaction_row_emit(scene, font, rect, theme, node->label, node->value, node->aux, node->detail, node->active, node->id);
    case ER_UI_NODE_MENU_ITEM:
      return er_ui_component_menu_item_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->active, node->color, node->id);
    case ER_UI_NODE_CONTROL_ROW:
      return er_ui_component_control_row_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->id);
    case ER_UI_NODE_GRID:
    case ER_UI_NODE_MASONRY:
    case ER_UI_NODE_BENTO_GRID: {
      er_ui_status_t status = er_ui_node_emit_background_gradient(node, scene, rect, theme);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_children(node, scene, font, rect, theme);
    }
    case ER_UI_NODE_SCROLL_AREA:
      return er_ui_node_render_scroll_area(node, scene, font, rect, theme);
    case ER_UI_NODE_SPACER:
      return ER_UI_OK;
    case ER_UI_NODE_TOOLTIP:
      return er_ui_component_tooltip_emit(scene, font, rect, theme, node->label);
    case ER_UI_NODE_DIALOG:
      return er_ui_component_dialog_emit(scene, font, rect, theme, node->label, node->detail, node->color);
    case ER_UI_NODE_PROGRESS_RING:
      return er_ui_component_progress_ring_emit(scene, rect, theme, node->number, node->color);
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
}
