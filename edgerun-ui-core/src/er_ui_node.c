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

er_ui_node_t er_ui_node_alert(const char* title, const char* body, er_ui_color4_t accent) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ALERT);
  node.label = title;
  node.detail = body;
  node.color = accent;
  return node;
}

er_ui_node_t er_ui_node_avatar(const char* label, er_ui_color4_t color, bool online) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_AVATAR);
  node.label = label;
  node.color = color;
  node.active = online;
  return node;
}

er_ui_node_t er_ui_node_progress(float value) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_PROGRESS);
  node.number = value;
  return node;
}

er_ui_node_t er_ui_node_switch(bool checked, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SWITCH);
  node.active = checked;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_table(const char* const* headers, size_t header_count, const char* const* cells, size_t row_count, uint32_t id_base) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TABLE);
  node.labels = headers;
  node.label_count = header_count;
  node.cells = cells;
  node.row_count = row_count;
  node.id = id_base;
  return node;
}

er_ui_node_t er_ui_node_breadcrumb(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BREADCRUMB);
  node.labels = labels;
  node.label_count = label_count;
  node.selected = selected;
  node.id = base_id;
  return node;
}

er_ui_node_t er_ui_node_toast(const char* message, er_ui_color4_t accent) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TOAST);
  node.label = message;
  node.color = accent;
  return node;
}

er_ui_node_t er_ui_node_empty(const char* title, const char* body) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_EMPTY);
  node.label = title;
  node.detail = body;
  return node;
}

er_ui_node_t er_ui_node_list_row(const char* title, const char* detail, uint32_t id, bool selected) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_LIST_ROW);
  node.label = title;
  node.detail = detail;
  node.id = id;
  node.active = selected;
  return node;
}

er_ui_node_t er_ui_node_field(const char* label, const char* value, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_FIELD);
  node.label = label;
  node.value = value;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_text_area(const char* label, const char* value, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TEXT_AREA);
  node.label = label;
  node.value = value;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_tabs(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TABS);
  node.labels = labels;
  node.label_count = label_count;
  node.selected = selected;
  node.id = base_id;
  return node;
}

er_ui_node_t er_ui_node_bar_chart(const char* title, const char* const* labels, const float* values, size_t value_count, uint32_t base_id, size_t selected) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BAR_CHART);
  node.label = title;
  node.labels = labels;
  node.values = values;
  node.value_count = value_count;
  node.id = base_id;
  node.selected = selected;
  return node;
}

er_ui_node_t er_ui_node_command_palette(const char* placeholder, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_COMMAND_PALETTE);
  node.label = placeholder;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_tree_item(const char* label, const char* detail, uint8_t depth, bool expanded, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TREE_ITEM);
  node.label = label;
  node.detail = detail;
  node.number = (float)depth;
  node.active = expanded;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_section(const char* title, const char* detail) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SECTION);
  node.label = title;
  node.detail = detail;
  return node;
}

er_ui_node_t er_ui_node_identity_card(const char* name, const char* node_name, const char* policy, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_IDENTITY_CARD);
  node.label = name;
  node.value = node_name;
  node.detail = policy;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_contact_card(const char* name, const char* detail, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CONTACT_CARD);
  node.label = name;
  node.detail = detail;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_thread_row(const char* title, const char* last_message, bool unread, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_THREAD_ROW);
  node.label = title;
  node.detail = last_message;
  node.active = unread;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_attachment_preview(const char* name, const char* kind, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ATTACHMENT_PREVIEW);
  node.label = name;
  node.detail = kind;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_capability_grant_row(const char* app, const char* capability, const char* state, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CAPABILITY_GRANT_ROW);
  node.label = app;
  node.value = capability;
  node.detail = state;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_proof_event_row(const char* title, const char* hash, const char* status_text, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_PROOF_EVENT_ROW);
  node.label = title;
  node.value = hash;
  node.detail = status_text;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_route_path(const char* label, const char* const* hops, size_t hop_count) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ROUTE_PATH);
  node.label = label;
  node.labels = hops;
  node.label_count = hop_count;
  return node;
}

er_ui_node_t er_ui_node_package_card(const char* name, const char* policy, const char* hash, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_PACKAGE_CARD);
  node.label = name;
  node.value = policy;
  node.detail = hash;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_receipt_row(const char* label, const char* amount, const char* status_text, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_RECEIPT_ROW);
  node.label = label;
  node.value = amount;
  node.detail = status_text;
  node.id = id;
  return node;
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
    case ER_UI_NODE_ALERT:
      return er_ui_shadcn_alert_emit(scene, font, rect, theme, node->label, node->detail, node->color);
    case ER_UI_NODE_AVATAR:
      return er_ui_shadcn_avatar_emit(scene, font, rect, theme, node->label, node->color, node->active);
    case ER_UI_NODE_PROGRESS:
      return er_ui_shadcn_progress_emit(scene, rect, theme, node->number);
    case ER_UI_NODE_SWITCH:
      return er_ui_shadcn_switch_emit(scene, rect, theme, node->active, node->id);
    case ER_UI_NODE_TABLE:
      return er_ui_shadcn_table_emit(scene, font, rect, theme, node->labels, node->label_count, node->cells, node->row_count, node->id);
    case ER_UI_NODE_BREADCRUMB:
      return er_ui_shadcn_breadcrumb_emit(scene, font, rect, theme, node->labels, node->label_count, node->selected, node->id);
    case ER_UI_NODE_TOAST:
      return er_ui_shadcn_toast_emit(scene, font, rect, theme, node->label, node->color);
    case ER_UI_NODE_EMPTY:
      return er_ui_shadcn_empty_emit(scene, font, rect, theme, node->label, node->detail);
    case ER_UI_NODE_LIST_ROW:
      return er_ui_shadcn_list_row_emit(scene, font, rect, theme, node->label, node->detail, node->id, node->active);
    case ER_UI_NODE_FIELD:
      return er_ui_shadcn_field_emit(scene, font, rect, theme, node->label, node->value, node->id, false);
    case ER_UI_NODE_TEXT_AREA:
      return er_ui_shadcn_field_emit(scene, font, rect, theme, node->label, node->value, node->id, true);
    case ER_UI_NODE_TABS:
      return er_ui_shadcn_tabs_emit(scene, font, rect, theme, node->labels, node->label_count, node->selected, node->id);
    case ER_UI_NODE_BAR_CHART:
      return er_ui_shadcn_bar_chart_emit(scene, font, rect, theme, node->label, node->labels, node->values, node->value_count, node->id, node->selected);
    case ER_UI_NODE_COMMAND_PALETTE:
      return er_ui_shadcn_command_palette_emit(scene, font, rect, theme, node->label, node->id);
    case ER_UI_NODE_TREE_ITEM:
      return er_ui_shadcn_tree_item_emit(scene, font, rect, theme, node->label, node->detail, (uint8_t)node->number, node->active, node->id);
    case ER_UI_NODE_SECTION:
      return er_ui_shadcn_section_header_emit(scene, font, rect, theme, node->label, node->detail);
    case ER_UI_NODE_IDENTITY_CARD:
      return er_ui_shadcn_identity_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_CONTACT_CARD:
      return er_ui_shadcn_contact_card_emit(scene, font, rect, theme, node->label, node->detail, node->id);
    case ER_UI_NODE_THREAD_ROW:
      return er_ui_shadcn_thread_row_emit(scene, font, rect, theme, node->label, node->detail, node->active, node->id);
    case ER_UI_NODE_ATTACHMENT_PREVIEW:
      return er_ui_shadcn_attachment_preview_emit(scene, font, rect, theme, node->label, node->detail, node->id);
    case ER_UI_NODE_CAPABILITY_GRANT_ROW:
      return er_ui_shadcn_capability_grant_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_PROOF_EVENT_ROW:
      return er_ui_shadcn_proof_event_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_ROUTE_PATH:
      return er_ui_shadcn_route_path_emit(scene, font, rect, theme, node->label, node->labels, node->label_count);
    case ER_UI_NODE_PACKAGE_CARD:
      return er_ui_shadcn_package_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_RECEIPT_ROW:
      return er_ui_shadcn_receipt_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
}
