#include "er_ui_node_internal.h"

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
er_ui_status_t er_ui_node_render_diff_body(
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

er_ui_status_t er_ui_node_render_chat_message(
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

er_ui_status_t er_ui_node_render_label_group(
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

er_ui_status_t er_ui_node_render_pagination(
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
