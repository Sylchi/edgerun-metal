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

er_ui_node_t er_ui_node_icon(er_ui_icon_t icon, const char* label, er_ui_color4_t color) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ICON);
  node.icon = icon;
  node.label = label;
  node.color = color;
  return node;
}

er_ui_node_t er_ui_node_icon_button(er_ui_icon_t icon, const char* label, uint32_t id, er_ui_shadcn_button_variant_t variant) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ICON_BUTTON);
  node.icon = icon;
  node.label = label;
  node.id = id;
  node.button_variant = variant;
  node.button_size = ER_UI_SHADCN_BUTTON_SIZE_ICON;
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

er_ui_node_t er_ui_node_button_group(const char* const* labels, size_t label_count, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BUTTON_GROUP);
  node.labels = labels;
  node.label_count = label_count;
  node.id = base_id;
  node.gap = 0.0f;
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

er_ui_node_t er_ui_node_toggle_group(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TOGGLE_GROUP);
  node.labels = labels;
  node.label_count = label_count;
  node.selected = selected;
  node.id = base_id;
  node.gap = 4.0f;
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

er_ui_node_t er_ui_node_pagination(const char* const* pages, size_t page_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_PAGINATION);
  node.labels = pages;
  node.label_count = page_count;
  node.selected = selected;
  node.id = base_id;
  node.gap = 4.0f;
  return node;
}

er_ui_node_t er_ui_node_collapsible(const char* title, const char* const* row_titles, const char* const* row_details, size_t row_count, bool open,
                                    uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_COLLAPSIBLE);
  node.label = title;
  node.labels = row_titles;
  node.cells = row_details;
  node.row_count = row_count;
  node.active = open;
  node.id = base_id;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_accordion(const char* const* item_titles, const char* const* item_bodies, size_t item_count, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ACCORDION);
  node.labels = item_titles;
  node.cells = item_bodies;
  node.row_count = item_count;
  node.id = base_id;
  node.gap = 4.0f;
  return node;
}

er_ui_node_t er_ui_node_hover_card(const char* label, const char* detail, const char* body, er_ui_color4_t color) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_HOVER_CARD);
  node.label = label;
  node.detail = detail;
  node.aux = body;
  node.color = color;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_popover(const char* button_label, const char* title, const char* detail, const char* field_label, const char* field_value,
                                uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_POPOVER);
  node.label = button_label;
  node.value = title;
  node.detail = detail;
  node.aux = field_label;
  node.extra = field_value;
  node.id = base_id;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_sheet(const char* title, const char* detail, const char* field_label, const char* field_value, const char* button_label,
                              uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SHEET);
  node.label = title;
  node.detail = detail;
  node.aux = field_label;
  node.extra = field_value;
  node.value = button_label;
  node.id = base_id;
  node.gap = 12.0f;
  return node;
}

er_ui_node_t er_ui_node_kbd(const char* const* keys, size_t key_count, const char* label) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_KBD);
  node.labels = keys;
  node.label_count = key_count;
  node.label = label;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_menubar(const char* const* items, size_t item_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_MENUBAR);
  node.labels = items;
  node.label_count = item_count;
  node.selected = selected;
  node.id = base_id;
  node.gap = 4.0f;
  return node;
}

er_ui_node_t er_ui_node_radio_group(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_RADIO_GROUP);
  node.labels = labels;
  node.label_count = label_count;
  node.selected = selected;
  node.id = base_id;
  node.gap = 8.0f;
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

er_ui_node_t er_ui_node_panel_header(const char* title, const char* subtitle, const char* action_label, uint32_t action_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_PANEL_HEADER);
  node.label = title;
  node.detail = subtitle;
  node.value = action_label;
  node.id = action_id;
  return node;
}

er_ui_node_t er_ui_node_metric_card(const char* title, const char* value, const char* detail, bool has_progress, float progress, er_ui_color4_t accent) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_METRIC_CARD);
  node.label = title;
  node.value = value;
  node.detail = detail;
  node.active = has_progress;
  node.number = progress;
  node.color = accent;
  return node;
}

er_ui_node_t er_ui_node_transaction_row(const char* title, const char* subtitle, const char* date, const char* amount, bool positive, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TRANSACTION_ROW);
  node.label = title;
  node.value = subtitle;
  node.aux = date;
  node.detail = amount;
  node.active = positive;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_menu_item(const char* label, const char* detail, const char* badge, bool selected, er_ui_color4_t accent, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_MENU_ITEM);
  node.label = label;
  node.detail = detail;
  node.value = badge;
  node.active = selected;
  node.color = accent;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_control_row(const char* label, const char* detail, const char* accessory, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CONTROL_ROW);
  node.label = label;
  node.detail = detail;
  node.value = accessory;
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_grid(size_t columns) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_GRID);
  node.selected = columns == 0u ? 1u : columns;
  return node;
}

er_ui_node_t er_ui_node_masonry(size_t columns) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_MASONRY);
  node.selected = columns == 0u ? 1u : columns;
  return node;
}

er_ui_node_t er_ui_node_bento_grid(size_t columns) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BENTO_GRID);
  node.selected = columns == 0u ? 1u : columns;
  return node;
}

er_ui_node_t er_ui_node_scroll_area(float offset_px, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SCROLL_AREA);
  node.number = er_ui_float_max(offset_px, 0.0f);
  node.id = id;
  return node;
}

er_ui_node_t er_ui_node_spacer(void) {
  return er_ui_node_base(ER_UI_NODE_SPACER);
}

er_ui_node_t er_ui_node_tooltip(const char* text) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TOOLTIP);
  node.label = text;
  return node;
}

er_ui_node_t er_ui_node_dialog(const char* title, const char* body, er_ui_color4_t accent) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_DIALOG);
  node.label = title;
  node.detail = body;
  node.color = accent;
  return node;
}

er_ui_node_t er_ui_node_progress_ring(float value, er_ui_color4_t color) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_PROGRESS_RING);
  node.number = value;
  node.color = color;
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

er_ui_node_t* er_ui_node_set_draggable(er_ui_node_t* node, uint32_t scope_id, uint32_t item_id, size_t index) {
  if (!node) return node;
  node->has_drag_source = true;
  node->drag_source.scope_id = scope_id;
  node->drag_source.item_id = item_id;
  node->drag_source.index = index;
  return node;
}

er_ui_node_t* er_ui_node_set_drop_target(er_ui_node_t* node, uint32_t scope_id, size_t index) {
  if (!node) return node;
  node->has_drop_target = true;
  node->drop_target.scope_id = scope_id;
  node->drop_target.index = index;
  return node;
}

er_ui_node_t* er_ui_node_set_reorderable(er_ui_node_t* node, uint32_t scope_id, uint32_t item_id, size_t index) {
  er_ui_node_set_draggable(node, scope_id, item_id, index);
  return er_ui_node_set_drop_target(node, scope_id, index);
}

er_ui_status_t er_ui_node_add_child(er_ui_node_t* parent, er_ui_node_t* child) {
  if (!parent || !child) return ER_UI_ERR_INVALID_ARGUMENT;
  if (parent->child_count >= ER_UI_NODE_MAX_CHILDREN) return ER_UI_ERR_OOM;
  parent->children[parent->child_count++] = child;
  return ER_UI_OK;
}

const char* er_ui_icon_label(er_ui_icon_t icon) {
  switch (icon) {
    case ER_UI_ICON_ACTIVITY: return "activity";
    case ER_UI_ICON_APP: return "app";
    case ER_UI_ICON_BELL: return "bell";
    case ER_UI_ICON_CHAT: return "chat";
    case ER_UI_ICON_CHECK: return "check";
    case ER_UI_ICON_CHEVRON_RIGHT: return "chevron-right";
    case ER_UI_ICON_CODE: return "code";
    case ER_UI_ICON_CPU: return "cpu";
    case ER_UI_ICON_DATABASE: return "database";
    case ER_UI_ICON_EYE: return "eye";
    case ER_UI_ICON_FILE: return "file";
    case ER_UI_ICON_KEY: return "key";
    case ER_UI_ICON_LOCK: return "lock";
    case ER_UI_ICON_MENU: return "menu";
    case ER_UI_ICON_MESSAGE_PLUS: return "message-plus";
    case ER_UI_ICON_NETWORK: return "network";
    case ER_UI_ICON_ROUTE: return "route";
    case ER_UI_ICON_SEARCH: return "search";
    case ER_UI_ICON_SEND: return "send";
    case ER_UI_ICON_SERVER: return "server";
    case ER_UI_ICON_SETTINGS: return "settings";
    case ER_UI_ICON_SHIELD: return "shield";
    case ER_UI_ICON_SPARKLES: return "sparkles";
    case ER_UI_ICON_STORAGE: return "storage";
    case ER_UI_ICON_TERMINAL: return "terminal";
    case ER_UI_ICON_TRUST: return "trust";
    case ER_UI_ICON_TRASH: return "trash";
    case ER_UI_ICON_USER: return "user";
    case ER_UI_ICON_WALLET: return "wallet";
    case ER_UI_ICON_WARNING: return "warning";
    case ER_UI_ICON_X: return "x";
    case ER_UI_ICON_COUNT:
    default: return "unknown";
  }
}

uint32_t er_ui_icon_atlas_id(er_ui_icon_t icon) {
  if ((uint32_t)icon >= (uint32_t)ER_UI_ICON_COUNT) return 0u;
  return (uint32_t)icon + 1u;
}

const char* er_ui_icon_provider_name(er_ui_icon_t icon, er_ui_icon_provider_t provider) {
  if (provider == ER_UI_ICON_PROVIDER_TABLER) {
    switch (icon) {
      case ER_UI_ICON_ACTIVITY: return "activity";
      case ER_UI_ICON_APP: return "apps";
      case ER_UI_ICON_BELL: return "bell";
      case ER_UI_ICON_CHAT: return "message-circle";
      case ER_UI_ICON_CHECK: return "check";
      case ER_UI_ICON_CHEVRON_RIGHT: return "chevron-right";
      case ER_UI_ICON_CODE: return "code";
      case ER_UI_ICON_CPU: return "cpu";
      case ER_UI_ICON_DATABASE: return "database";
      case ER_UI_ICON_EYE: return "eye";
      case ER_UI_ICON_FILE: return "file";
      case ER_UI_ICON_KEY: return "key";
      case ER_UI_ICON_LOCK: return "lock";
      case ER_UI_ICON_MENU: return "menu-2";
      case ER_UI_ICON_MESSAGE_PLUS: return "message-plus";
      case ER_UI_ICON_NETWORK: return "network";
      case ER_UI_ICON_ROUTE: return "route";
      case ER_UI_ICON_SEARCH: return "search";
      case ER_UI_ICON_SEND: return "arrow-up";
      case ER_UI_ICON_SERVER: return "server";
      case ER_UI_ICON_SETTINGS: return "settings";
      case ER_UI_ICON_SHIELD: return "shield-check";
      case ER_UI_ICON_SPARKLES: return "sparkles";
      case ER_UI_ICON_STORAGE: return "database";
      case ER_UI_ICON_TERMINAL: return "terminal-2";
      case ER_UI_ICON_TRUST: return "shield-check";
      case ER_UI_ICON_TRASH: return "trash";
      case ER_UI_ICON_USER: return "user";
      case ER_UI_ICON_WALLET: return "wallet";
      case ER_UI_ICON_WARNING: return "alert-triangle";
      case ER_UI_ICON_X: return "x";
      case ER_UI_ICON_COUNT:
      default: return NULL;
    }
  }
  if (provider == ER_UI_ICON_PROVIDER_LUCIDE) {
    switch (icon) {
      case ER_UI_ICON_ACTIVITY: return "activity";
      case ER_UI_ICON_APP: return "app-window";
      case ER_UI_ICON_BELL: return "bell";
      case ER_UI_ICON_CHAT: return "message-circle";
      case ER_UI_ICON_CHECK: return "check";
      case ER_UI_ICON_CHEVRON_RIGHT: return "chevron-right";
      case ER_UI_ICON_CODE: return "code";
      case ER_UI_ICON_CPU: return "cpu";
      case ER_UI_ICON_DATABASE: return "database";
      case ER_UI_ICON_EYE: return "eye";
      case ER_UI_ICON_FILE: return "file";
      case ER_UI_ICON_KEY: return "key";
      case ER_UI_ICON_LOCK: return "lock";
      case ER_UI_ICON_MENU: return "menu";
      case ER_UI_ICON_MESSAGE_PLUS: return "message-circle-plus";
      case ER_UI_ICON_NETWORK: return "network";
      case ER_UI_ICON_ROUTE: return "route";
      case ER_UI_ICON_SEARCH: return "search";
      case ER_UI_ICON_SEND: return "arrow-up";
      case ER_UI_ICON_SERVER: return "server";
      case ER_UI_ICON_SETTINGS: return "settings";
      case ER_UI_ICON_SHIELD: return "shield-check";
      case ER_UI_ICON_SPARKLES: return "sparkles";
      case ER_UI_ICON_STORAGE: return "database";
      case ER_UI_ICON_TERMINAL: return "square-terminal";
      case ER_UI_ICON_TRUST: return "shield-check";
      case ER_UI_ICON_TRASH: return "trash-2";
      case ER_UI_ICON_USER: return "user";
      case ER_UI_ICON_WALLET: return "wallet";
      case ER_UI_ICON_WARNING: return "triangle-alert";
      case ER_UI_ICON_X: return "x";
      case ER_UI_ICON_COUNT:
      default: return NULL;
    }
  }
  return NULL;
}

const char* er_ui_node_kind_label(er_ui_node_kind_t kind) {
  switch (kind) {
    case ER_UI_NODE_ROW: return "row";
    case ER_UI_NODE_COLUMN: return "column";
    case ER_UI_NODE_CARD: return "card";
    case ER_UI_NODE_ICON: return "icon";
    case ER_UI_NODE_ICON_BUTTON: return "icon-button";
    case ER_UI_NODE_TEXT: return "text";
    case ER_UI_NODE_BADGE: return "badge";
    case ER_UI_NODE_BUTTON: return "button";
    case ER_UI_NODE_BUTTON_GROUP: return "button-group";
    case ER_UI_NODE_CHECKBOX: return "checkbox";
    case ER_UI_NODE_RADIO: return "radio";
    case ER_UI_NODE_SELECT: return "select";
    case ER_UI_NODE_SLIDER: return "slider";
    case ER_UI_NODE_SEPARATOR: return "separator";
    case ER_UI_NODE_SKELETON: return "skeleton";
    case ER_UI_NODE_ALERT: return "alert";
    case ER_UI_NODE_AVATAR: return "avatar";
    case ER_UI_NODE_PROGRESS: return "progress";
    case ER_UI_NODE_SWITCH: return "switch";
    case ER_UI_NODE_TOGGLE_GROUP: return "toggle-group";
    case ER_UI_NODE_TABLE: return "table";
    case ER_UI_NODE_BREADCRUMB: return "breadcrumb";
    case ER_UI_NODE_TOAST: return "toast";
    case ER_UI_NODE_EMPTY: return "empty";
    case ER_UI_NODE_LIST_ROW: return "list-row";
    case ER_UI_NODE_FIELD: return "field";
    case ER_UI_NODE_TEXT_AREA: return "text-area";
    case ER_UI_NODE_TABS: return "tabs";
    case ER_UI_NODE_BAR_CHART: return "bar-chart";
    case ER_UI_NODE_COMMAND_PALETTE: return "command-palette";
    case ER_UI_NODE_TREE_ITEM: return "tree-item";
    case ER_UI_NODE_SECTION: return "section";
    case ER_UI_NODE_IDENTITY_CARD: return "identity-card";
    case ER_UI_NODE_CONTACT_CARD: return "contact-card";
    case ER_UI_NODE_THREAD_ROW: return "thread-row";
    case ER_UI_NODE_ATTACHMENT_PREVIEW: return "attachment-preview";
    case ER_UI_NODE_CAPABILITY_GRANT_ROW: return "capability-grant-row";
    case ER_UI_NODE_PROOF_EVENT_ROW: return "proof-event-row";
    case ER_UI_NODE_PAGINATION: return "pagination";
    case ER_UI_NODE_COLLAPSIBLE: return "collapsible";
    case ER_UI_NODE_ACCORDION: return "accordion";
    case ER_UI_NODE_HOVER_CARD: return "hover-card";
    case ER_UI_NODE_POPOVER: return "popover";
    case ER_UI_NODE_SHEET: return "sheet";
    case ER_UI_NODE_KBD: return "kbd";
    case ER_UI_NODE_MENUBAR: return "menubar";
    case ER_UI_NODE_RADIO_GROUP: return "radio-group";
    case ER_UI_NODE_ROUTE_PATH: return "route-path";
    case ER_UI_NODE_PACKAGE_CARD: return "package-card";
    case ER_UI_NODE_RECEIPT_ROW: return "receipt-row";
    case ER_UI_NODE_PANEL_HEADER: return "panel-header";
    case ER_UI_NODE_METRIC_CARD: return "metric-card";
    case ER_UI_NODE_TRANSACTION_ROW: return "transaction-row";
    case ER_UI_NODE_MENU_ITEM: return "menu-item";
    case ER_UI_NODE_CONTROL_ROW: return "control-row";
    case ER_UI_NODE_GRID: return "grid";
    case ER_UI_NODE_MASONRY: return "masonry";
    case ER_UI_NODE_BENTO_GRID: return "bento-grid";
    case ER_UI_NODE_SCROLL_AREA: return "scroll-area";
    case ER_UI_NODE_SPACER: return "spacer";
    case ER_UI_NODE_TOOLTIP: return "tooltip";
    case ER_UI_NODE_DIALOG: return "dialog";
    case ER_UI_NODE_PROGRESS_RING: return "progress-ring";
    default: return "unknown";
  }
}

const char* er_ui_node_composition_issue_label(er_ui_node_composition_issue_kind_t kind) {
  switch (kind) {
    case ER_UI_NODE_COMPOSITION_OK: return "ok";
    case ER_UI_NODE_COMPOSITION_NESTED_CARD: return "nested-card";
    default: return "unknown";
  }
}

static bool er_ui_node_is_card_like(er_ui_node_kind_t kind) {
  return kind == ER_UI_NODE_CARD ||
         kind == ER_UI_NODE_IDENTITY_CARD ||
         kind == ER_UI_NODE_CONTACT_CARD ||
         kind == ER_UI_NODE_PACKAGE_CARD ||
         kind == ER_UI_NODE_METRIC_CARD;
}

static void er_ui_node_clear_composition_issue(er_ui_node_composition_issue_t* out_issue) {
  if (!out_issue) return;
  out_issue->kind = ER_UI_NODE_COMPOSITION_OK;
  out_issue->ancestor_kind = ER_UI_NODE_ROW;
  out_issue->parent_kind = ER_UI_NODE_ROW;
  out_issue->node_kind = ER_UI_NODE_ROW;
  out_issue->child_index = 0u;
  out_issue->depth = 0u;
}

static er_ui_status_t er_ui_node_validate_composition_inner(
  const er_ui_node_t* node,
  bool inside_card,
  er_ui_node_kind_t card_ancestor,
  er_ui_node_kind_t parent_kind,
  size_t child_index,
  size_t depth,
  er_ui_node_composition_issue_t* out_issue) {
  if (!node) return ER_UI_ERR_INVALID_ARGUMENT;
  bool card_like = er_ui_node_is_card_like(node->kind);
  if (card_like && inside_card) {
    if (out_issue) {
      out_issue->kind = ER_UI_NODE_COMPOSITION_NESTED_CARD;
      out_issue->ancestor_kind = card_ancestor;
      out_issue->parent_kind = parent_kind;
      out_issue->node_kind = node->kind;
      out_issue->child_index = child_index;
      out_issue->depth = depth;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  bool next_inside_card = inside_card || card_like;
  er_ui_node_kind_t next_card_ancestor = inside_card ? card_ancestor : node->kind;
  for (size_t i = 0u; i < node->child_count; ++i) {
    er_ui_status_t status = er_ui_node_validate_composition_inner(
      node->children[i],
      next_inside_card,
      next_card_ancestor,
      node->kind,
      i,
      depth + 1u,
      out_issue);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_validate_composition(const er_ui_node_t* node, er_ui_node_composition_issue_t* out_issue) {
  if (!node) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_node_clear_composition_issue(out_issue);
  return er_ui_node_validate_composition_inner(node, false, node->kind, node->kind, 0u, 0u, out_issue);
}

static er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds);

static er_ui_status_t er_ui_node_linear_child_bounds(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_bounds_t bounds,
  bool row,
  er_ui_bounds_t* out_bounds) {
  if (!node || !out_bounds) return ER_UI_ERR_INVALID_ARGUMENT;
  if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  float total_gap = node->gap * (float)(node->child_count - 1u);
  float step = row ? (content.w - total_gap) / (float)node->child_count : (content.h - total_gap) / (float)node->child_count;
  if (step <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t child_bounds = content;
  if (row) {
    child_bounds.x = content.x + (step + node->gap) * (float)child_index;
    child_bounds.w = step;
  } else {
    child_bounds.y = content.y + (step + node->gap) * (float)child_index;
    child_bounds.h = step;
  }
  *out_bounds = er_ui_node_resolve_bounds(node->children[child_index], child_bounds);
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_grid_child_bounds(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_bounds_t bounds,
  er_ui_bounds_t* out_bounds) {
  if (!node || !out_bounds) return ER_UI_ERR_INVALID_ARGUMENT;
  if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t columns = node->selected == 0u ? 1u : node->selected;
  if (columns > node->child_count) columns = node->child_count;
  size_t rows = (node->child_count + columns - 1u) / columns;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  float total_gap_x = node->gap * (float)(columns - 1u);
  float total_gap_y = node->gap * (float)(rows - 1u);
  float cell_w = (content.w - total_gap_x) / (float)columns;
  float cell_h = (content.h - total_gap_y) / (float)rows;
  if (cell_w <= 0.0f || cell_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t col = child_index % columns;
  size_t row = child_index / columns;
  er_ui_bounds_t child_bounds = er_ui_bounds(content.x + (cell_w + node->gap) * (float)col, content.y + (cell_h + node->gap) * (float)row, cell_w, cell_h);
  *out_bounds = er_ui_node_resolve_bounds(node->children[child_index], child_bounds);
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_child_bounds(const er_ui_node_t* node, size_t child_index, er_ui_bounds_t bounds, er_ui_bounds_t* out_bounds) {
  if (!node || !out_bounds) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t rect = er_ui_node_resolve_bounds(node, bounds);
  switch (node->kind) {
    case ER_UI_NODE_ROW:
      return er_ui_node_linear_child_bounds(node, child_index, rect, true, out_bounds);
    case ER_UI_NODE_COLUMN:
    case ER_UI_NODE_CARD:
      return er_ui_node_linear_child_bounds(node, child_index, rect, false, out_bounds);
    case ER_UI_NODE_GRID:
    case ER_UI_NODE_MASONRY:
    case ER_UI_NODE_BENTO_GRID:
      return er_ui_node_grid_child_bounds(node, child_index, rect, out_bounds);
    case ER_UI_NODE_SCROLL_AREA: {
      er_ui_bounds_t scrolled = rect;
      scrolled.y -= node->number;
      return er_ui_node_linear_child_bounds(node, child_index, scrolled, false, out_bounds);
    }
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
}

const char* er_ui_a11y_role_label(er_ui_a11y_role_t role) {
  switch (role) {
    case ER_UI_A11Y_GROUP: return "group";
    case ER_UI_A11Y_TEXT: return "text";
    case ER_UI_A11Y_BUTTON: return "button";
    case ER_UI_A11Y_CHECKBOX: return "checkbox";
    case ER_UI_A11Y_RADIO: return "radio";
    case ER_UI_A11Y_TEXTBOX: return "textbox";
    case ER_UI_A11Y_COMBOBOX: return "combobox";
    case ER_UI_A11Y_DIALOG: return "dialog";
    case ER_UI_A11Y_TOOLTIP: return "tooltip";
    case ER_UI_A11Y_STATUS: return "status";
    case ER_UI_A11Y_PROGRESSBAR: return "progressbar";
    case ER_UI_A11Y_TABLE: return "table";
    case ER_UI_A11Y_ROW: return "row";
    case ER_UI_A11Y_CELL: return "cell";
    case ER_UI_A11Y_TAB_LIST: return "tab-list";
    case ER_UI_A11Y_TAB: return "tab";
    case ER_UI_A11Y_MENU_ITEM: return "menu-item";
    case ER_UI_A11Y_LIST_ITEM: return "list-item";
    case ER_UI_A11Y_NAVIGATION: return "navigation";
    case ER_UI_A11Y_SEPARATOR: return "separator";
    case ER_UI_A11Y_IMAGE: return "image";
    case ER_UI_A11Y_SLIDER: return "slider";
    case ER_UI_A11Y_GENERIC:
    default: return "generic";
  }
}

static er_ui_a11y_node_t er_ui_a11y_base(er_ui_a11y_role_t role, const char* label, bool has_id, uint32_t id) {
  er_ui_a11y_node_t out = {0};
  out.role = role;
  out.label = label ? label : "";
  out.value = "";
  out.has_id = has_id;
  out.id = id;
  return out;
}

static void er_ui_a11y_set_value(er_ui_a11y_node_t* out, const char* value) {
  if (!out) return;
  out->value = value ? value : "";
  out->states |= ER_UI_A11Y_STATE_HAS_VALUE;
}

er_ui_status_t er_ui_node_accessibility(const er_ui_node_t* node, er_ui_a11y_node_t* out_a11y) {
  if (!node || !out_a11y) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_GENERIC, "", false, 0u);
  switch (node->kind) {
    case ER_UI_NODE_ROW:
    case ER_UI_NODE_COLUMN:
    case ER_UI_NODE_GRID:
    case ER_UI_NODE_MASONRY:
    case ER_UI_NODE_BENTO_GRID:
    case ER_UI_NODE_CARD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "", false, 0u);
      break;
    case ER_UI_NODE_SCROLL_AREA:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "scroll area", node->id != 0u, node->id);
      break;
    case ER_UI_NODE_TEXT:
    case ER_UI_NODE_BADGE:
      out = er_ui_a11y_base(ER_UI_A11Y_TEXT, node->label, false, 0u);
      break;
    case ER_UI_NODE_ICON:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label ? node->label : er_ui_icon_label(node->icon), false, 0u);
      break;
    case ER_UI_NODE_BUTTON:
    case ER_UI_NODE_ICON_BUTTON:
      out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      break;
    case ER_UI_NODE_BUTTON_GROUP:
    case ER_UI_NODE_TOGGLE_GROUP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->kind == ER_UI_NODE_BUTTON_GROUP ? "button group" : "toggle group", false, 0u);
      break;
    case ER_UI_NODE_CHECKBOX:
      out = er_ui_a11y_base(ER_UI_A11Y_CHECKBOX, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CHECKED;
      break;
    case ER_UI_NODE_RADIO:
      out = er_ui_a11y_base(ER_UI_A11Y_RADIO, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CHECKED;
      break;
    case ER_UI_NODE_SELECT:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_FIELD:
    case ER_UI_NODE_TEXT_AREA:
      out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_SLIDER:
      out = er_ui_a11y_base(ER_UI_A11Y_SLIDER, node->label, true, node->id);
      out.numeric_value = node->number;
      out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      break;
    case ER_UI_NODE_TOOLTIP:
      out = er_ui_a11y_base(ER_UI_A11Y_TOOLTIP, node->label, false, 0u);
      break;
    case ER_UI_NODE_DIALOG:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      break;
    case ER_UI_NODE_TOAST:
      out = er_ui_a11y_base(ER_UI_A11Y_STATUS, node->label, false, 0u);
      break;
    case ER_UI_NODE_EMPTY:
    case ER_UI_NODE_SECTION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      break;
    case ER_UI_NODE_SKELETON:
      out = er_ui_a11y_base(ER_UI_A11Y_GENERIC, "loading", false, 0u);
      break;
    case ER_UI_NODE_PROGRESS:
    case ER_UI_NODE_PROGRESS_RING:
      out = er_ui_a11y_base(ER_UI_A11Y_PROGRESSBAR, "progress", false, 0u);
      out.numeric_value = node->number;
      out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      break;
    case ER_UI_NODE_TABLE:
      out = er_ui_a11y_base(ER_UI_A11Y_TABLE, "table", true, node->id);
      break;
    case ER_UI_NODE_BREADCRUMB:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "breadcrumb", false, 0u);
      break;
    case ER_UI_NODE_PAGINATION:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "pagination", false, 0u);
      break;
    case ER_UI_NODE_COLLAPSIBLE:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      if (node->active) out.states |= ER_UI_A11Y_STATE_EXPANDED | ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_ACCORDION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "accordion", false, 0u);
      break;
    case ER_UI_NODE_HOVER_CARD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_POPOVER:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->value, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_SHEET:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_KBD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      break;
    case ER_UI_NODE_MENUBAR:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "menubar", false, 0u);
      break;
    case ER_UI_NODE_RADIO_GROUP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "radio group", false, 0u);
      break;
    case ER_UI_NODE_TABS:
      out = er_ui_a11y_base(ER_UI_A11Y_TAB_LIST, "tabs", false, 0u);
      break;
    case ER_UI_NODE_COMMAND_PALETTE:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      break;
    case ER_UI_NODE_TREE_ITEM:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_EXPANDED;
      break;
    case ER_UI_NODE_IDENTITY_CARD:
    case ER_UI_NODE_CONTACT_CARD:
    case ER_UI_NODE_ATTACHMENT_PREVIEW:
    case ER_UI_NODE_PACKAGE_CARD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, true, node->id);
      break;
    case ER_UI_NODE_THREAD_ROW:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CURRENT;
      break;
    case ER_UI_NODE_CAPABILITY_GRANT_ROW:
    case ER_UI_NODE_PROOF_EVENT_ROW:
    case ER_UI_NODE_RECEIPT_ROW:
    case ER_UI_NODE_TRANSACTION_ROW:
    case ER_UI_NODE_LIST_ROW:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, true, node->id);
      break;
    case ER_UI_NODE_ROUTE_PATH:
    case ER_UI_NODE_PANEL_HEADER:
    case ER_UI_NODE_METRIC_CARD:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      if (node->kind == ER_UI_NODE_METRIC_CARD) er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_MENU_ITEM:
      out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_SELECTED;
      break;
    case ER_UI_NODE_CONTROL_ROW:
      out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->label, node->id != 0u, node->id);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_SWITCH:
      out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "toggle", true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CHECKED;
      break;
    case ER_UI_NODE_AVATAR:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label, false, 0u);
      if (node->active) out.states |= ER_UI_A11Y_STATE_CURRENT;
      break;
    case ER_UI_NODE_BAR_CHART:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label, false, 0u);
      break;
    case ER_UI_NODE_ALERT:
      out = er_ui_a11y_base(ER_UI_A11Y_STATUS, node->label, false, 0u);
      break;
    case ER_UI_NODE_SEPARATOR:
      out = er_ui_a11y_base(ER_UI_A11Y_SEPARATOR, "", false, 0u);
      break;
    case ER_UI_NODE_SPACER:
    default:
      out = er_ui_a11y_base(ER_UI_A11Y_GENERIC, "", false, 0u);
      break;
  }
  *out_a11y = out;
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_accessibility_child(const er_ui_node_t* node, size_t child_index, er_ui_a11y_node_t* out_a11y) {
  if (!node || !out_a11y) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->kind == ER_UI_NODE_TABS) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TAB, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_BUTTON_GROUP || node->kind == ER_UI_NODE_TOGGLE_GROUP) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (node->kind == ER_UI_NODE_TOGGLE_GROUP && child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_MENUBAR) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_RADIO_GROUP) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_RADIO, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_CHECKED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_BREADCRUMB) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_CURRENT;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_PAGINATION) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    const char* label = child_index == 0u ? "Previous" : (child_index == node->label_count + 1u ? "Next" : node->labels[child_index - 1u]);
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, label, true, node->id + (uint32_t)child_index);
    if (child_index > 0u && child_index <= node->label_count && child_index - 1u == node->selected) out.states |= ER_UI_A11Y_STATE_CURRENT;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_COLLAPSIBLE) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      if (node->active) out.states |= ER_UI_A11Y_STATE_EXPANDED | ER_UI_A11Y_STATE_OPEN;
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (!node->active || !node->labels || child_index - 1u >= node->row_count) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->labels[child_index - 1u], true, node->id + (uint32_t)child_index);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_ACCORDION) {
    if (!node->labels || child_index >= node->row_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
    out.states |= ER_UI_A11Y_STATE_EXPANDED | ER_UI_A11Y_STATE_OPEN;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_POPOVER) {
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->aux, true, node->id + 1u);
      er_ui_a11y_set_value(&out, node->extra);
      *out_a11y = out;
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_SHEET) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->aux, true, node->id);
      er_ui_a11y_set_value(&out, node->extra);
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->value, true, node->id + 1u);
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_TABLE) {
    if (node->label_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_ROW, "header", false, 0u);
      return ER_UI_OK;
    }
    size_t row = child_index - 1u;
    if (row >= node->row_count) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_ROW, "", true, node->id + (uint32_t)row);
    return ER_UI_OK;
  }
  if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_node_accessibility(node->children[child_index], out_a11y);
}

static er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds) {
  if (!node) return bounds;
  if (er_ui_bounds_valid(node->bounds)) return node->bounds;
  return bounds;
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

static er_ui_status_t er_ui_node_render_grid(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_OK;
  size_t columns = node->selected == 0u ? 1u : node->selected;
  if (columns > node->child_count) columns = node->child_count;
  size_t rows = (node->child_count + columns - 1u) / columns;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  float total_gap_x = node->gap * (float)(columns - 1u);
  float total_gap_y = node->gap * (float)(rows - 1u);
  float cell_w = (content.w - total_gap_x) / (float)columns;
  float cell_h = (content.h - total_gap_y) / (float)rows;
  if (cell_w <= 0.0f || cell_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < node->child_count; ++i) {
    size_t col = i % columns;
    size_t row = i / columns;
    er_ui_bounds_t child_bounds = er_ui_bounds(content.x + (cell_w + node->gap) * (float)col, content.y + (cell_h + node->gap) * (float)row, cell_w, cell_h);
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
  er_ui_bounds_t scrolled = bounds;
  scrolled.y -= node->number;
  status = er_ui_node_render_children(node, scene, font, scrolled, theme, false);
  if (pushed) er_ui_scene_pop_clip(scene);
  return status;
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

static er_ui_status_t er_ui_node_render_icon(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_icon_t icon, er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  uint32_t atlas_id = er_ui_icon_atlas_id(icon);
  if (atlas_id == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_icon_quad(scene, er_ui_quad_atlas(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, 0.0f, 1.0f, 1.0f, atlas_id, color));
}

static er_ui_bounds_t er_ui_node_center_square(er_ui_bounds_t bounds, float size);

static er_ui_status_t er_ui_node_render_collapsible(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !node->label || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->active && node->row_count > 0u && (!node->labels || !node->cells)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;

  float pad = 12.0f;
  float header_h = er_ui_float_min(36.0f, bounds.h - pad * 2.0f);
  if (header_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t inner = er_ui_bounds(bounds.x + pad, bounds.y + pad, bounds.w - pad * 2.0f, bounds.h - pad * 2.0f);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t title = er_ui_bounds(inner.x, inner.y, er_ui_float_max(0.0f, inner.w - header_h - 8.0f), header_h);
  er_ui_bounds_t trigger = er_ui_bounds(inner.x + inner.w - header_h, inner.y, header_h, header_h);
  status = er_ui_node_render_text(scene, font, node->label, title, theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_button_emit(scene, font, trigger, theme, "", node->id, ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_ICON, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_icon(scene, er_ui_node_center_square(trigger, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.text);
  if (status != ER_UI_OK || !node->active) return status;

  float row_y = inner.y + header_h + node->gap;
  float row_h = 44.0f;
  for (size_t i = 0u; i < node->row_count; ++i) {
    er_ui_bounds_t row = er_ui_bounds(inner.x, row_y, inner.w, row_h);
    status = er_ui_shadcn_list_row_emit(scene, font, row, theme, node->labels[i], node->cells[i], node->id + 1u + (uint32_t)i, false);
    if (status != ER_UI_OK) return status;
    row_y += row_h + node->gap;
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_render_accordion(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!node || !scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->row_count == 0u || !node->labels || !node->cells) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;

  float pad = 8.0f;
  er_ui_bounds_t inner = er_ui_bounds(bounds.x + pad, bounds.y + pad, bounds.w - pad * 2.0f, bounds.h - pad * 2.0f);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
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
    status = er_ui_shadcn_button_emit(scene, font, trigger, theme, "", node->id + (uint32_t)i, ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_ICON, true);
    if (status != ER_UI_OK) return status;
    status = er_ui_node_render_icon(scene, er_ui_node_center_square(trigger, 16.0f), ER_UI_ICON_CHEVRON_RIGHT, theme.colors.text);
    if (status != ER_UI_OK) return status;
    y += header_h;

    status = er_ui_node_render_text(scene, font, node->cells[i], er_ui_bounds(inner.x, y, inner.w, body_h), theme.colors.muted);
    if (status != ER_UI_OK) return status;
    y += body_h + node->gap;
    if (i + 1u < node->row_count) {
      status = er_ui_shadcn_separator_emit(scene, er_ui_bounds(inner.x, y, inner.w, divider_h), theme);
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
  er_ui_status_t status = er_ui_shadcn_avatar_emit(scene, font, er_ui_bounds(bounds.x, bounds.y, avatar_size, avatar_size), theme, node->label, node->color, false);
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
  er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, button, theme, node->label, node->id, ER_UI_SHADCN_BUTTON_SECONDARY,
                                                   ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t card = er_ui_bounds(bounds.x, bounds.y + button.h + node->gap, er_ui_float_min(bounds.w, 320.0f), er_ui_float_max(bounds.h - button.h - node->gap, 96.0f));
  status = er_ui_shadcn_card_emit(scene, card, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  status = er_ui_node_render_text(scene, font, node->value, er_ui_bounds(card.x + pad, card.y + pad, card.w - pad * 2.0f, 22.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(card.x + pad, card.y + 34.0f, card.w - pad * 2.0f, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_field_emit(scene, font, er_ui_bounds(card.x + pad, card.y + 62.0f, card.w - pad * 2.0f, 54.0f), theme, node->aux, node->extra,
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
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 16.0f;
  er_ui_bounds_t inner = er_ui_bounds(bounds.x + pad, bounds.y + pad, bounds.w - pad * 2.0f, bounds.h - pad * 2.0f);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(inner.x, inner.y, inner.w, 24.0f), theme.colors.text);
  if (status != ER_UI_OK) return status;
  status = er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(inner.x, inner.y + 26.0f, inner.w, 22.0f), theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(inner.x, inner.y + 58.0f, inner.w, 54.0f), theme, node->aux, node->extra, node->id, false);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(inner.x, inner.y + 124.0f, er_ui_float_min(inner.w, 160.0f), 40.0f), theme, node->value,
                                  node->id + 1u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
}

static size_t er_ui_node_ascii_len(const char* text) {
  size_t len = 0u;
  if (!text) return 0u;
  while (text[len]) len++;
  return len;
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
    float badge_w = 22.0f + (float)er_ui_node_ascii_len(node->labels[i]) * 8.0f;
    er_ui_status_t status = er_ui_shadcn_badge_emit(scene, font, er_ui_bounds(x, badge_y, badge_w, badge_h), theme, node->labels[i], ER_UI_SHADCN_BADGE_SECONDARY);
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
    er_ui_shadcn_button_variant_t variant = i == node->selected ? ER_UI_SHADCN_BUTTON_SECONDARY : ER_UI_SHADCN_BUTTON_GHOST;
    status = er_ui_shadcn_button_emit(scene, font, item, theme, node->labels[i], node->id + (uint32_t)i, variant, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
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
    er_ui_status_t status = er_ui_shadcn_radio_emit(scene, font, er_ui_bounds(bounds.x, y, bounds.w, row_h), theme, node->labels[i], i == node->selected,
                                                    node->id + (uint32_t)i);
    if (status != ER_UI_OK) return status;
    y += row_h + node->gap;
  }
  return ER_UI_OK;
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
    er_ui_shadcn_button_variant_t variant = ER_UI_SHADCN_BUTTON_SECONDARY;
    if (toggle_group && i != node->selected) variant = ER_UI_SHADCN_BUTTON_GHOST;
    er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, item, theme, node->labels[i], node->id + (uint32_t)i, variant, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
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
  er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(x, bounds.y, previous_w, bounds.h), theme, "Previous", node->id,
                                                   ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, false);
  if (status != ER_UI_OK) return status;
  x += previous_w + gap;
  for (size_t i = 0u; i < node->label_count; ++i) {
    er_ui_shadcn_button_variant_t variant = i == node->selected ? ER_UI_SHADCN_BUTTON_SECONDARY : ER_UI_SHADCN_BUTTON_GHOST;
    status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(x, bounds.y, page_w, bounds.h), theme, node->labels[i], node->id + 1u + (uint32_t)i,
                                      variant, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
    if (status != ER_UI_OK) return status;
    x += page_w + gap;
  }
  return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(x, bounds.y, next_w, bounds.h), theme, "Next", node->id + 1u + (uint32_t)node->label_count,
                                  ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true);
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
  er_ui_bounds_t rect = er_ui_node_resolve_bounds(node, bounds);
  er_ui_status_t interaction_status = er_ui_node_emit_interaction(node, scene, rect);
  if (interaction_status != ER_UI_OK) return interaction_status;
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
    case ER_UI_NODE_ICON:
      return er_ui_node_render_icon(scene, er_ui_node_center_square(rect, 20.0f), node->icon, node->color.a > 0.0f ? node->color : theme.colors.muted);
    case ER_UI_NODE_TEXT:
      return er_ui_node_render_text(scene, font, node->label, rect, theme.colors.text);
    case ER_UI_NODE_BADGE:
      return er_ui_shadcn_badge_emit(scene, font, rect, theme, node->label, node->badge_variant);
    case ER_UI_NODE_BUTTON:
      return er_ui_shadcn_button_emit(scene, font, rect, theme, node->label, node->id, node->button_variant, node->button_size, node->active);
    case ER_UI_NODE_BUTTON_GROUP:
      return er_ui_node_render_label_group(node, scene, font, rect, theme, false);
    case ER_UI_NODE_ICON_BUTTON: {
      er_ui_status_t status = er_ui_shadcn_button_emit(scene, font, rect, theme, "", node->id, node->button_variant, ER_UI_SHADCN_BUTTON_SIZE_ICON, node->active);
      if (status != ER_UI_OK) return status;
      return er_ui_node_render_icon(scene, er_ui_node_center_square(rect, 16.0f), node->icon, theme.colors.text);
    }
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
    case ER_UI_NODE_TOGGLE_GROUP:
      return er_ui_node_render_label_group(node, scene, font, rect, theme, true);
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
    case ER_UI_NODE_ROUTE_PATH:
      return er_ui_shadcn_route_path_emit(scene, font, rect, theme, node->label, node->labels, node->label_count);
    case ER_UI_NODE_PACKAGE_CARD:
      return er_ui_shadcn_package_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_RECEIPT_ROW:
      return er_ui_shadcn_receipt_row_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->id);
    case ER_UI_NODE_PANEL_HEADER:
      return er_ui_shadcn_panel_header_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->id);
    case ER_UI_NODE_METRIC_CARD:
      return er_ui_shadcn_metric_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->active, node->number, node->color);
    case ER_UI_NODE_TRANSACTION_ROW:
      return er_ui_shadcn_transaction_row_emit(scene, font, rect, theme, node->label, node->value, node->aux, node->detail, node->active, node->id);
    case ER_UI_NODE_MENU_ITEM:
      return er_ui_shadcn_menu_item_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->active, node->color, node->id);
    case ER_UI_NODE_CONTROL_ROW:
      return er_ui_shadcn_control_row_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->id);
    case ER_UI_NODE_GRID:
    case ER_UI_NODE_MASONRY:
    case ER_UI_NODE_BENTO_GRID:
      return er_ui_node_render_grid(node, scene, font, rect, theme);
    case ER_UI_NODE_SCROLL_AREA:
      return er_ui_node_render_scroll_area(node, scene, font, rect, theme);
    case ER_UI_NODE_SPACER:
      return ER_UI_OK;
    case ER_UI_NODE_TOOLTIP:
      return er_ui_shadcn_tooltip_emit(scene, font, rect, theme, node->label);
    case ER_UI_NODE_DIALOG:
      return er_ui_shadcn_dialog_emit(scene, font, rect, theme, node->label, node->detail, node->color);
    case ER_UI_NODE_PROGRESS_RING:
      return er_ui_shadcn_progress_ring_emit(scene, rect, theme, node->number, node->color);
    default:
      return ER_UI_ERR_INVALID_ARGUMENT;
  }
}
