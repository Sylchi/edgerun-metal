#include "er_ui_node.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"

static const float ER_UI_NODE_DEFAULT_GAP = 8.0f;
static const float ER_UI_NODE_DROPDOWN_GAP = 4.0f;
static const float ER_UI_NODE_MENU_GAP = 8.0f;
static const float ER_UI_NODE_CAROUSEL_GAP = 12.0f;
static const float ER_UI_NODE_CARD_PADDING = 12.0f;
static er_ui_node_t er_ui_node_base(er_ui_node_kind_t kind) {
  er_ui_node_t node = {0};
  node.kind = kind;
  node.gap = ER_UI_NODE_DEFAULT_GAP;
  node.padding = 0.0f;
  node.margin = 0.0f;
  node.column_span = 1u;
  node.row_span = 1u;
  node.active = true;
  node.button_size = ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT;
  node.button_variant = ER_UI_COMPONENT_BUTTON_DEFAULT;
  node.badge_variant = ER_UI_COMPONENT_BADGE_DEFAULT;
  return node;
}

static er_ui_node_t er_ui_node_option_list(
  er_ui_node_kind_t kind,
  const char* const* labels,
  const char* const* cells,
  size_t item_count,
  size_t selected,
  uint32_t base_id,
  float gap) {
  er_ui_node_t node = er_ui_node_base(kind);
  node.labels = labels;
  node.cells = cells;
  node.label_count = item_count;
  node.selected = selected;
  node.id = base_id;
  node.gap = gap;
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
  node.padding = ER_UI_NODE_CARD_PADDING;
  return node;
}

er_ui_node_t er_ui_node_icon(er_ui_icon_t icon, const char* label, er_ui_color4_t color) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ICON);
  node.icon = icon;
  node.label = label;
  node.color = color;
  return node;
}

er_ui_node_t er_ui_node_icon_button(er_ui_icon_t icon, const char* label, uint32_t id, er_ui_component_button_variant_t variant) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ICON_BUTTON);
  node.icon = icon;
  node.label = label;
  node.id = id;
  node.button_variant = variant;
  node.button_size = ER_UI_COMPONENT_BUTTON_SIZE_ICON;
  return node;
}

er_ui_node_t er_ui_node_text(const char* value) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TEXT);
  node.label = value;
  return node;
}

er_ui_node_t er_ui_node_badge(const char* label, er_ui_component_badge_variant_t variant) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BADGE);
  node.label = label;
  node.badge_variant = variant;
  return node;
}

er_ui_node_t er_ui_node_button(const char* label, uint32_t id, er_ui_component_button_variant_t variant) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_BUTTON);
  node.label = label;
  node.id = id;
  node.button_variant = variant;
  return node;
}

er_ui_node_t er_ui_node_card_summary(const char* title, const char* detail) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CARD_SUMMARY);
  node.label = title;
  node.detail = detail;
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
  node.active = false;
  return node;
}

er_ui_node_t er_ui_node_toast_icon(const char* message, er_ui_icon_t icon, er_ui_color4_t accent) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_TOAST);
  node.label = message;
  node.icon = icon;
  node.color = accent;
  node.active = true;
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

er_ui_node_t er_ui_node_input_group(const char* label, const char* value, const char* button_label, uint32_t id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_INPUT_GROUP);
  node.label = label;
  node.value = value;
  node.detail = button_label;
  node.id = id;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_input_otp(const char* const* values, size_t value_count, size_t focused_index, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_INPUT_OTP);
  node.labels = values;
  node.label_count = value_count;
  node.selected = focused_index;
  node.id = base_id;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_navigation_menu(const char* const* tabs, size_t tab_count, size_t selected, const char* title, const char* detail,
                                        const char* row_title, const char* row_detail, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_NAVIGATION_MENU);
  node.labels = tabs;
  node.label_count = tab_count;
  node.selected = selected;
  node.label = title;
  node.detail = detail;
  node.aux = row_title;
  node.extra = row_detail;
  node.id = base_id;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_resizable(const char* const* labels, size_t label_count) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_RESIZABLE);
  node.labels = labels;
  node.label_count = label_count;
  node.gap = 4.0f;
  return node;
}

er_ui_node_t er_ui_node_sidebar(const char* title, const char* detail, const char* const* items, size_t item_count, size_t selected, const char* main_title,
                                const char* main_detail, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SIDEBAR);
  node.label = title;
  node.detail = detail;
  node.labels = items;
  node.label_count = item_count;
  node.selected = selected;
  node.value = main_title;
  node.aux = main_detail;
  node.id = base_id;
  node.gap = 12.0f;
  return node;
}

er_ui_node_t er_ui_node_sonner(const char* const* messages, const er_ui_icon_t* icons, const er_ui_color4_t* accents, size_t message_count) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_SONNER);
  node.labels = messages;
  node.icons = icons;
  node.colors = accents;
  node.label_count = message_count;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_aspect_ratio(const char* label, er_ui_icon_t icon) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ASPECT_RATIO);
  node.label = label;
  node.icon = icon;
  return node;
}

er_ui_node_t er_ui_node_alert_dialog(const char* title, const char* body, er_ui_icon_t icon) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_ALERT_DIALOG);
  node.label = title;
  node.detail = body;
  node.icon = icon;
  return node;
}

er_ui_node_t er_ui_node_direction(const char* ltr_text, const char* rtl_text) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_DIRECTION);
  node.label = ltr_text;
  node.detail = rtl_text;
  node.gap = 8.0f;
  return node;
}

er_ui_node_t er_ui_node_drawer(const char* title, const char* detail, const char* slider_label, float value, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_DRAWER);
  node.label = title;
  node.detail = detail;
  node.aux = slider_label;
  node.number = value;
  node.id = base_id;
  node.gap = 12.0f;
  return node;
}

er_ui_node_t er_ui_node_dropdown_menu(const char* const* labels, const char* const* shortcuts, size_t item_count, size_t selected, uint32_t base_id) {
  return er_ui_node_option_list(ER_UI_NODE_DROPDOWN_MENU, labels, shortcuts, item_count, selected, base_id, ER_UI_NODE_DROPDOWN_GAP);
}

er_ui_node_t er_ui_node_context_menu(const char* title, const char* detail, const char* const* labels, const char* const* shortcuts, size_t item_count,
                                     size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_option_list(ER_UI_NODE_CONTEXT_MENU, labels, shortcuts, item_count, selected, base_id, ER_UI_NODE_MENU_GAP);
  node.label = title;
  node.detail = detail;
  return node;
}

er_ui_node_t er_ui_node_date_picker(const char* label, const char* month, const char* const* days, size_t day_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_option_list(ER_UI_NODE_DATE_PICKER, days, NULL, day_count, selected, base_id, ER_UI_NODE_MENU_GAP);
  node.label = label;
  node.detail = month;
  return node;
}

er_ui_node_t er_ui_node_carousel(const char* const* items, size_t item_count, uint32_t base_id) {
  return er_ui_node_option_list(ER_UI_NODE_CAROUSEL, items, NULL, item_count, 0u, base_id, ER_UI_NODE_CAROUSEL_GAP);
}

er_ui_node_t er_ui_node_calendar(const char* month, const char* const* days, size_t day_count, size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_option_list(ER_UI_NODE_CALENDAR, days, NULL, day_count, selected, base_id, ER_UI_NODE_MENU_GAP);
  node.label = month;
  return node;
}

er_ui_node_t er_ui_node_combobox(const char* label, const char* value, const char* placeholder, const char* const* options, size_t option_count,
                                 size_t selected, uint32_t base_id) {
  er_ui_node_t node = er_ui_node_option_list(ER_UI_NODE_COMBOBOX, options, NULL, option_count, selected, base_id, ER_UI_NODE_MENU_GAP);
  node.label = label;
  node.value = value;
  node.detail = placeholder;
  return node;
}

er_ui_node_t er_ui_node_diff_body(const char* const* lines, size_t line_count, bool truncated) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_DIFF_BODY);
  node.labels = lines;
  node.label_count = line_count;
  node.active = truncated;
  node.gap = 4.0f;
  return node;
}

er_ui_node_t er_ui_node_chat_message(er_ui_component_chat_role_t role, const char* heading, const char* detail) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CHAT_MESSAGE);
  node.selected = (size_t)role;
  node.label = heading;
  node.detail = detail;
  return node;
}

er_ui_node_t er_ui_node_chat_diff_message(const char* heading, const char* const* lines, size_t line_count, bool truncated) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CHAT_MESSAGE);
  node.selected = (size_t)ER_UI_COMPONENT_CHAT_ROLE_DIFF;
  node.label = heading;
  node.labels = lines;
  node.label_count = line_count;
  node.active = truncated;
  return node;
}

er_ui_node_t er_ui_node_conversation(float scroll_offset_px, uint32_t scroll_id) {
  er_ui_node_t node = er_ui_node_base(ER_UI_NODE_CONVERSATION);
  node.number = er_ui_float_max(scroll_offset_px, 0.0f);
  node.id = scroll_id;
  node.padding = 16.0f;
  node.gap = 16.0f;
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

er_ui_node_t* er_ui_node_set_margin(er_ui_node_t* node, float margin) {
  if (!node) return node;
  node->margin = er_ui_float_max(margin, 0.0f);
  return node;
}

er_ui_node_t* er_ui_node_set_spacing(er_ui_node_t* node, float padding, float gap, float margin) {
  er_ui_node_set_padding(node, padding);
  er_ui_node_set_gap(node, gap);
  return er_ui_node_set_margin(node, margin);
}

er_ui_node_t* er_ui_node_set_grid_span(er_ui_node_t* node, size_t column_span, size_t row_span) {
  if (!node) return node;
  node->column_span = column_span == 0u ? 1u : column_span;
  node->row_span = row_span == 0u ? 1u : row_span;
  return node;
}

er_ui_node_t* er_ui_node_set_background_gradient(er_ui_node_t* node, er_ui_color4_t from, er_ui_color4_t to) {
  if (!node) return node;
  node->has_background_gradient = true;
  node->background_gradient_from = from;
  node->background_gradient_to = to;
  return node;
}

er_ui_node_t* er_ui_node_set_transition(er_ui_node_t* node, er_ui_transition_t transition) {
  if (!node) return node;
  node->has_transition = true;
  node->transition = transition;
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
    case ER_UI_NODE_CARD_SUMMARY: return "card-summary";
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
    case ER_UI_NODE_INPUT_GROUP: return "input-group";
    case ER_UI_NODE_INPUT_OTP: return "input-otp";
    case ER_UI_NODE_NAVIGATION_MENU: return "navigation-menu";
    case ER_UI_NODE_RESIZABLE: return "resizable";
    case ER_UI_NODE_SIDEBAR: return "sidebar";
    case ER_UI_NODE_SONNER: return "sonner";
    case ER_UI_NODE_ASPECT_RATIO: return "aspect-ratio";
    case ER_UI_NODE_ALERT_DIALOG: return "alert-dialog";
    case ER_UI_NODE_DIRECTION: return "direction";
    case ER_UI_NODE_DRAWER: return "drawer";
    case ER_UI_NODE_DROPDOWN_MENU: return "dropdown-menu";
    case ER_UI_NODE_CONTEXT_MENU: return "context-menu";
    case ER_UI_NODE_DATE_PICKER: return "date-picker";
    case ER_UI_NODE_CAROUSEL: return "carousel";
    case ER_UI_NODE_CALENDAR: return "calendar";
    case ER_UI_NODE_COMBOBOX: return "combobox";
    case ER_UI_NODE_DIFF_BODY: return "diff-body";
    case ER_UI_NODE_CHAT_MESSAGE: return "chat-message";
    case ER_UI_NODE_CONVERSATION: return "conversation";
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
    default: return 0;
  }
}

const char* er_ui_node_composition_issue_label(er_ui_node_composition_issue_kind_t kind) {
  switch (kind) {
    case ER_UI_NODE_COMPOSITION_OK: return "ok";
    case ER_UI_NODE_COMPOSITION_NESTED_CARD: return "nested-card";
    default: return 0;
  }
}

static bool er_ui_node_is_card_like(er_ui_node_kind_t kind) {
  return kind == ER_UI_NODE_CARD ||
         kind == ER_UI_NODE_CARD_SUMMARY ||
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
