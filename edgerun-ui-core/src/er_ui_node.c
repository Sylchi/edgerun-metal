#include "er_ui_node.h"

static er_ui_node_t er_ui_node_base(er_ui_node_kind_t kind) {
  er_ui_node_t node = {0};
  node.kind = kind;
  node.gap = 8.0f;
  node.padding = 0.0f;
  node.active = true;
  node.button_size = ER_UI_SHADCN_BUTTON_SIZE_DEFAULT;
  node.button_variant = ER_UI_SHADCN_BUTTON_DEFAULT;
  node.badge_variant = ER_UI_SHADCN_BADGE_DEFAULT;
  return node;
}

er_ui_node_t er_ui_node_row(void) {
  return er_ui_node_base(ER_UI_NODE_ROW);
}

er_ui_node_t er_ui_node_column(void) {
  return er_ui_node_base(ER_UI_NODE_COLUMN);
}

er_ui_node_t er_ui_node_card(void) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CARD);
  node.padding = 12.0f;
  return node;
}

er_ui_node_t er_ui_node_text(const char* value) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TEXT);
  node.label = value;
  return node;
}

er_ui_node_t er_ui_node_badge(const char* label, er_ui_shadcn_badge_variant_t variant) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BADGE);
  node.label = label;
  node.badge_variant = variant;
  return node;
}

er_ui_node_t er_ui_node_button(const char* label, uint32_t id, er_ui_shadcn_button_variant_t variant) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BUTTON);
  node.label = label;
  node.id = id;
  node.button_variant = variant;
  return node;
}

er_ui_node_t er_ui_node_checkbox(const char* label, bool checked, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CHECKBOX);
  node.label = label;
  node.active = checked;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_radio(const char* label, bool selected, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_RADIO);
  node.label = label;
  node.active = selected;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_select(const char* label, const char* value, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SELECT);
  node.label = label;
  node.value = value;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_slider(const char* label, float value, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SLIDER);
  node.label = label;
  node.number = value;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_separator(void) {
  return er_ui_node_base(ER_UI_NODE_SEPARATOR);
}

er_ui_node_t er_ui_node_skeleton(void) {
  return er_ui_node_base(ER_UI_NODE_SKELETON);
}

er_ui_node_t* er_ui_node_set_bounds(er_ui_node_t* node, er_ui_bounds_t bounds) {
  if (!node) return node;
  node->bounds = bounds;
  return node;
}

er_ui_node_t* er_ui_node_set_gap(er_ui_node_t* node, float gap) {
  if (!node) return node;
  node->gap = er_ui_float_max(gap, 0.0f);
  return node;
}

er_ui_node_t* er_ui_node_set_padding(er_ui_node_t* node, float padding) {
  if (!node) return node;
  node->padding = er_ui_float_max(padding, 0.0f);
  return node;
}

er_ui_status_t er_ui_node_add_child(er_ui_node_t* parent, er_ui_node_t* child) {
  if (!parent || !child) return ER_UI_ERR_INVALID_ARGUMENT;
  if (parent->child_count >= ER_UI_NODE_MAX_CHILDREN) return ER_UI_ERR_OOM;
  parent->children[parent->child_count++] = child;
  return ER_UI_OK;
}

static er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds) {
  if (!node) return bounds;
  if (er_ui_bounds_valid(node->bounds)) return node->bounds;
  return bounds;
}

static er_ui_status_t er_ui_node_render_children(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  bool row) {
  if (!node) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_OK;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  float total_gap = node->gap * (float)(node->child_count - 1u);
  float step = row ? (content.w - total_gap) / (float)node->child_count : (content.h - total_gap) / (float)node->child_count;
  if (step <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < node->child_count; ++i) {
    er_ui_bounds_t child_bounds = content;
    if (row) {
      child_bounds.x = content.x + (step + node->gap) * (float)i;
      child_bounds.w = step;
    } else {
      child_bounds.y = content.y + (step + node->gap) * (float)i;
      child_bounds.h = step;
    }
    er_ui_status_t status = er_ui_node_render(node->children[i], scene, font, child_bounds, theme);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_render_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, er_ui_bounds_t bounds, er_ui_color4_t color) {
  if (!scene || !font || !text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  uint32_t codepoints[128u];
  size_t count = 0u;
  while (text[count] && count < 128u) {
    unsigned char byte = (unsigned char)text[count];
    codepoints[count] = byte < 0x80u ? (uint32_t)byte : (uint32_t)'?';
    count++;
  }
  return er_ui_scene_push_varfont_text(scene, font, codepoints, count, bounds.x, bounds.y + er_ui_float_min(bounds.h * 0.62f, 22.0f), color);
}

er_ui_status_t er_ui_node_render(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t rect = er_ui_node_resolve_bounds(node, bounds);
  switch (node->kind) {
    case ER_UI_NODE_ROW:
      return er_ui_node_render_children(node, scene, font, rect, theme, true);
    case ER_UI_NODE_COLUMN:
      return er_ui_node_render_children(node, scene, font, rect, theme, false);
    case ER_UI_NODE_CARD: {
      er_ui_status_t status = er_ui_shadcn_card_emit(scene, rect, theme);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_children(node, scene, font, rect, theme, false);
    }
    case ER_UI_NODE_TEXT:
      return er_ui_node_render_text(scene, font, node->label, rect, theme.colors.text);
    case ER_UI_NODE_BADGE:
      return er_ui_shadcn_badge_emit(scene, font, rect, theme, node->label, node->badge_variant);
    case ER_UI_NODE_BUTTON:
      return er_ui_shadcn_button_emit(scene, font, rect, theme, node->label, node->id, node->button_variant, node->button_size, node->active);
    case ER_UI_NODE_CHECKBOX:
      return er_ui_shadcn_checkbox_emit(scene, font, rect, theme, node->label, node->active, node->id);
    case ER_UI_NODE_RADIO:
      return er_ui_shadcn_radio_emit(scene, font, rect, theme, node->label, node->active, node->id);
    case ER_UI_NODE_SELECT:
      return er_ui_shadcn_select_emit(scene, font, rect, theme, node->label, node->value, node->id, false);
    case ER_UI_NODE_SLIDER:
      return er_ui_shadcn_slider_emit(scene, font, rect, theme, node->label, node->number, node->id);
    case ER_UI_NODE_SEPARATOR:
      return er_ui_shadcn_separator_emit(scene, rect, theme);
    case ER_UI_NODE_SKELETON:
      return er_ui_shadcn_skeleton_emit(scene, rect, theme);
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
}
