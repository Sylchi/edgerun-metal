#include "er_ui_node.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"

static const float ER_UI_NODE_DEFAULT_GAP = 8.0f;
static const float ER_UI_NODE_DROPDOWN_GAP = 4.0f;
static const float ER_UI_NODE_MENU_GAP = 8.0f;
static const float ER_UI_NODE_CAROUSEL_GAP = 12.0f;
static const float ER_UI_NODE_CARD_PADDING = 12.0f;
static const float ER_UI_NODE_SIDEBAR_MIN_SIDE_W = 120.0f;
static const float ER_UI_NODE_SIDEBAR_PREFERRED_SIDE_W = 176.0f;
static const float ER_UI_NODE_SIDEBAR_MIN_MAIN_W = 120.0f;
static const float ER_UI_NODE_SIDEBAR_STACKED_SIDE_H = 96.0f;
static const float ER_UI_NODE_BENTO_CELL_ASPECT = 0.75f;
static const float ER_UI_NODE_MASONRY_DEFAULT_HEIGHT_RATIO = 0.78f;
static const float ER_UI_NODE_MASONRY_STEP_HEIGHT_RATIO = 0.18f;
enum { ER_UI_NODE_MASONRY_STEP_COUNT = 3u };
enum { ER_UI_NODE_BENTO_MAX_ROWS = ER_UI_NODE_MAX_CHILDREN * ER_UI_NODE_MAX_CHILDREN };
enum { ER_UI_NODE_TEXT_BUDGET = 128u };
enum {
  ER_UI_NODE_RESIZABLE_FIRST_INDEX = 0u,
  ER_UI_NODE_RESIZABLE_SECOND_INDEX = 1u,
  ER_UI_NODE_RESIZABLE_THIRD_INDEX = 2u
};

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

static er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds);

typedef struct {
  er_ui_uniform_grid_t grid;
} er_ui_node_grid_layout_t;

static er_ui_status_t er_ui_node_grid_layout(const er_ui_node_t* node, er_ui_bounds_t bounds, er_ui_node_grid_layout_t* out_layout) {
  if (!node || !out_layout) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t columns = node->selected == 0u ? 1u : node->selected;
  if (columns > node->child_count) columns = node->child_count;
  size_t rows = (node->child_count + columns - 1u) / columns;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  er_ui_uniform_grid_t grid = er_ui_uniform_grid(content, columns, rows, node->gap, node->gap);
  if (grid.columns == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  out_layout->grid = grid;
  return ER_UI_OK;
}

static er_ui_bounds_t er_ui_node_grid_cell_bounds(const er_ui_node_grid_layout_t* layout, size_t child_index) {
  return er_ui_uniform_grid_cell(layout->grid, child_index);
}

static float er_ui_node_child_requested_height(const er_ui_node_t* child, float width, size_t child_index) {
  if (child && er_ui_bounds_valid(child->bounds)) return child->bounds.h;
  float step = (float)(child_index % ER_UI_NODE_MASONRY_STEP_COUNT);
  return width * (ER_UI_NODE_MASONRY_DEFAULT_HEIGHT_RATIO + ER_UI_NODE_MASONRY_STEP_HEIGHT_RATIO * step);
}

//@optimizer-ignore-function masonry layout must place each prior child into the current shortest column
static er_ui_status_t er_ui_node_masonry_child_bounds(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_bounds_t bounds,
  er_ui_bounds_t* out_bounds) {
  if (!node || !out_bounds) return ER_UI_ERR_INVALID_ARGUMENT;
  if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->child_count == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t columns = node->selected == 0u ? 1u : node->selected;
  if (columns > ER_UI_NODE_MAX_CHILDREN) columns = ER_UI_NODE_MAX_CHILDREN;
  if (columns > node->child_count) columns = node->child_count;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  float total_gap_x = node->gap * (float)(columns - 1u);
  float column_w = (content.w - total_gap_x) / (float)columns;
  if (column_w <= 0.0f || content.h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  float heights[ER_UI_NODE_MAX_CHILDREN] = {0};
  er_ui_bounds_t selected = content;
  for (size_t i = 0u; i <= child_index; ++i) {
    size_t column = 0u;
    float min_height = heights[0];
    for (size_t candidate = 1u; candidate < columns; ++candidate) {
      if (heights[candidate] < min_height) {
        column = candidate;
        min_height = heights[candidate];
      }
    }
    float requested_h = er_ui_node_child_requested_height(node->children[i], column_w, i);
    er_ui_bounds_t placed = er_ui_bounds(content.x + (column_w + node->gap) * (float)column, content.y + heights[column], column_w, requested_h);
    if (i == child_index) selected = placed;
    heights[column] += requested_h + node->gap;
  }
  *out_bounds = er_ui_node_resolve_bounds(node->children[child_index], selected);
  return ER_UI_OK;
}

static size_t er_ui_node_child_column_span(const er_ui_node_t* child, size_t columns) {
  size_t span = child && child->column_span > 0u ? child->column_span : 1u;
  return span > columns ? columns : span;
}

static size_t er_ui_node_child_row_span(const er_ui_node_t* child) {
  return child && child->row_span > 0u ? child->row_span : 1u;
}

//@optimizer-ignore-function bento layout must test every cell covered by a candidate span
static bool er_ui_node_bento_cells_available(
  const bool occupied[ER_UI_NODE_BENTO_MAX_ROWS][ER_UI_NODE_MAX_CHILDREN],
  size_t row,
  size_t column,
  size_t row_span,
  size_t column_span,
  size_t columns) {
  if (column + column_span > columns) return false;
  if (row + row_span > ER_UI_NODE_BENTO_MAX_ROWS) return false;
  for (size_t y = row; y < row + row_span; ++y) {
    for (size_t x = column; x < column + column_span; ++x) {
      if (occupied[y][x]) return false;
    }
  }
  return true;
}

//@optimizer-ignore-function bento layout must mark every occupied cell covered by a placed span
static void er_ui_node_bento_mark_cells(
  bool occupied[ER_UI_NODE_BENTO_MAX_ROWS][ER_UI_NODE_MAX_CHILDREN],
  size_t row,
  size_t column,
  size_t row_span,
  size_t column_span) {
  for (size_t y = row; y < row + row_span; ++y) {
    for (size_t x = column; x < column + column_span; ++x) occupied[y][x] = true;
  }
}

//@optimizer-ignore-function bento layout must scan bounded rows and columns to find the first fitting span
static er_ui_status_t er_ui_node_bento_find_cell(
  const bool occupied[ER_UI_NODE_BENTO_MAX_ROWS][ER_UI_NODE_MAX_CHILDREN],
  size_t row_span,
  size_t column_span,
  size_t columns,
  size_t* out_row,
  size_t* out_column) {
  if (!out_row || !out_column) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t row = 0u; row < ER_UI_NODE_BENTO_MAX_ROWS; ++row) {
    for (size_t column = 0u; column < columns; ++column) {
      if (er_ui_node_bento_cells_available(occupied, row, column, row_span, column_span, columns)) {
        *out_row = row;
        *out_column = column;
        return ER_UI_OK;
      }
    }
  }
  return ER_UI_ERR_INVALID_ARGUMENT;
}

static er_ui_status_t er_ui_node_bento_child_bounds(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_bounds_t bounds,
  er_ui_bounds_t* out_bounds) {
  if (!node || !out_bounds) return ER_UI_ERR_INVALID_ARGUMENT;
  if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t columns = node->selected == 0u ? 1u : node->selected;
  if (columns > ER_UI_NODE_MAX_CHILDREN) columns = ER_UI_NODE_MAX_CHILDREN;
  er_ui_bounds_t content = er_ui_bounds_inset(bounds, node->padding, node->padding);
  float total_gap_x = node->gap * (float)(columns - 1u);
  float cell_w = (content.w - total_gap_x) / (float)columns;
  float cell_h = cell_w * ER_UI_NODE_BENTO_CELL_ASPECT;
  if (cell_w <= 0.0f || cell_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  bool occupied[ER_UI_NODE_BENTO_MAX_ROWS][ER_UI_NODE_MAX_CHILDREN] = {{false}};
  er_ui_bounds_t selected = content;
  for (size_t i = 0u; i <= child_index; ++i) {
    const er_ui_node_t* child = node->children[i];
    size_t col_span = er_ui_node_child_column_span(child, columns);
    size_t row_span = er_ui_node_child_row_span(child);
    size_t row = 0u;
    size_t column = 0u;
    er_ui_status_t cell_status = er_ui_node_bento_find_cell(occupied, row_span, col_span, columns, &row, &column);
    if (cell_status != ER_UI_OK) return cell_status;
    float w = cell_w * (float)col_span + node->gap * (float)(col_span - 1u);
    float h = cell_h * (float)row_span + node->gap * (float)(row_span - 1u);
    er_ui_bounds_t placed = er_ui_bounds(content.x + (cell_w + node->gap) * (float)column, content.y + (cell_h + node->gap) * (float)row, w, h);
    if (i == child_index) selected = placed;
    er_ui_node_bento_mark_cells(occupied, row, column, row_span, col_span);
  }
  *out_bounds = er_ui_node_resolve_bounds(node->children[child_index], selected);
  return ER_UI_OK;
}

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
  er_ui_node_grid_layout_t layout;
  er_ui_status_t status = er_ui_node_grid_layout(node, bounds, &layout);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t child_bounds = er_ui_node_grid_cell_bounds(&layout, child_index);
  *out_bounds = er_ui_node_resolve_bounds(node->children[child_index], child_bounds);
  return ER_UI_OK;
}

static er_ui_status_t er_ui_node_scrolled_child_bounds(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_bounds_t rect,
  er_ui_bounds_t* out_bounds) {
  er_ui_bounds_t scrolled = rect;
  scrolled.y -= node->number;
  return er_ui_node_linear_child_bounds(node, child_index, scrolled, false, out_bounds);
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
      return er_ui_node_grid_child_bounds(node, child_index, rect, out_bounds);
    case ER_UI_NODE_MASONRY:
      return er_ui_node_masonry_child_bounds(node, child_index, rect, out_bounds);
    case ER_UI_NODE_BENTO_GRID:
      return er_ui_node_bento_child_bounds(node, child_index, rect, out_bounds);
    case ER_UI_NODE_SCROLL_AREA:
    case ER_UI_NODE_CONVERSATION:
      return er_ui_node_scrolled_child_bounds(node, child_index, rect, out_bounds);
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

static er_ui_status_t er_ui_node_menu_item_accessibility(const er_ui_node_t* node, size_t child_index, er_ui_a11y_node_t* out_a11y) {
  if (!node || !out_a11y || !node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->labels[child_index], true, node->id + (uint32_t)child_index);
  if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
  if (node->cells) er_ui_a11y_set_value(&out, node->cells[child_index]);
  *out_a11y = out;
  return ER_UI_OK;
}

static const char* er_ui_component_chat_role_label(er_ui_component_chat_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_CHAT_ROLE_USER: return "user";
    case ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT: return "assistant";
    case ER_UI_COMPONENT_CHAT_ROLE_REASONING: return "reasoning";
    case ER_UI_COMPONENT_CHAT_ROLE_DIFF: return "diff";
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING: return "tool running";
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS: return "tool ok";
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR: return "tool failed";
    case ER_UI_COMPONENT_CHAT_ROLE_ERROR: return "error";
    default: return "assistant";
  }
}

static er_ui_component_badge_variant_t er_ui_component_chat_role_badge(er_ui_component_chat_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR:
    case ER_UI_COMPONENT_CHAT_ROLE_ERROR: return ER_UI_COMPONENT_BADGE_DESTRUCTIVE;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING: return ER_UI_COMPONENT_BADGE_DEFAULT;
    case ER_UI_COMPONENT_CHAT_ROLE_DIFF:
    case ER_UI_COMPONENT_CHAT_ROLE_REASONING:
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS: return ER_UI_COMPONENT_BADGE_SECONDARY;
    case ER_UI_COMPONENT_CHAT_ROLE_USER:
    case ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT:
    default: return ER_UI_COMPONENT_BADGE_OUTLINE;
  }
}

static er_ui_icon_t er_ui_component_chat_role_icon(er_ui_component_chat_role_t role) {
  switch (role) {
    case ER_UI_COMPONENT_CHAT_ROLE_USER: return ER_UI_ICON_USER;
    case ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT: return ER_UI_ICON_CHAT;
    case ER_UI_COMPONENT_CHAT_ROLE_REASONING: return ER_UI_ICON_SPARKLES;
    case ER_UI_COMPONENT_CHAT_ROLE_DIFF: return ER_UI_ICON_FILE;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING: return ER_UI_ICON_TERMINAL;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS: return ER_UI_ICON_CHECK;
    case ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR:
    case ER_UI_COMPONENT_CHAT_ROLE_ERROR: return ER_UI_ICON_WARNING;
    default: return ER_UI_ICON_CHAT;
  }
}

static bool er_ui_component_chat_role_timeline(er_ui_component_chat_role_t role) {
  return role == ER_UI_COMPONENT_CHAT_ROLE_REASONING ||
         role == ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING ||
         role == ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS ||
         role == ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR ||
         role == ER_UI_COMPONENT_CHAT_ROLE_ERROR;
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
    case ER_UI_NODE_CARD_SUMMARY:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "", false, 0u);
      if (node->kind == ER_UI_NODE_CARD_SUMMARY) {
        out.label = node->label ? node->label : "";
        er_ui_a11y_set_value(&out, node->detail);
      }
      break;
    case ER_UI_NODE_SCROLL_AREA:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "scroll area", node->id != 0u, node->id);
      break;
    case ER_UI_NODE_CONVERSATION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "conversation", node->id != 0u, node->id);
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
    case ER_UI_NODE_INPUT_GROUP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->value);
      break;
    case ER_UI_NODE_INPUT_OTP:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "one-time password", false, 0u);
      break;
    case ER_UI_NODE_NAVIGATION_MENU:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, node->label, false, 0u);
      break;
    case ER_UI_NODE_RESIZABLE:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "resizable", false, 0u);
      break;
    case ER_UI_NODE_SIDEBAR:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, node->label, false, 0u);
      break;
    case ER_UI_NODE_SONNER:
      out = er_ui_a11y_base(ER_UI_A11Y_STATUS, "toaster", false, 0u);
      break;
    case ER_UI_NODE_ASPECT_RATIO:
      out = er_ui_a11y_base(ER_UI_A11Y_IMAGE, node->label, false, 0u);
      break;
    case ER_UI_NODE_ALERT_DIALOG:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_DIRECTION:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "direction", false, 0u);
      break;
    case ER_UI_NODE_DRAWER:
      out = er_ui_a11y_base(ER_UI_A11Y_DIALOG, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_DROPDOWN_MENU:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, "dropdown menu", false, 0u);
      break;
    case ER_UI_NODE_CONTEXT_MENU:
      out = er_ui_a11y_base(ER_UI_A11Y_NAVIGATION, node->label, false, 0u);
      er_ui_a11y_set_value(&out, node->detail);
      break;
    case ER_UI_NODE_DATE_PICKER:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->detail);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_CAROUSEL:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "carousel", false, 0u);
      break;
    case ER_UI_NODE_CALENDAR:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->label, false, 0u);
      break;
    case ER_UI_NODE_COMBOBOX:
      out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      break;
    case ER_UI_NODE_DIFF_BODY:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, "diff body", false, 0u);
      if (node->active) out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      break;
    case ER_UI_NODE_CHAT_MESSAGE:
      out = er_ui_a11y_base(ER_UI_A11Y_GROUP, er_ui_component_chat_role_label((er_ui_component_chat_role_t)node->selected), false, 0u);
      er_ui_a11y_set_value(&out, node->detail ? node->detail : node->label);
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
  if (node->kind == ER_UI_NODE_DROPDOWN_MENU) {
    return er_ui_node_menu_item_accessibility(node, child_index, out_a11y);
  }
  if (node->kind == ER_UI_NODE_CONTEXT_MENU) {
    return er_ui_node_menu_item_accessibility(node, child_index, out_a11y);
  }
  if (node->kind == ER_UI_NODE_DATE_PICKER) {
    if (!node->labels || child_index > node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->label, true, node->id);
      return ER_UI_OK;
    }
    size_t day_index = child_index - 1u;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[day_index], true, node->id + (uint32_t)child_index);
    if (day_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CAROUSEL) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Previous", true, node->id);
      return ER_UI_OK;
    }
    if (child_index == node->label_count + 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Next", true, node->id + 1u);
      return ER_UI_OK;
    }
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->labels[child_index - 1u], false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CALENDAR) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Previous month", true, node->id);
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Next month", true, node->id + 1u);
      return ER_UI_OK;
    }
    size_t day_index = child_index - 2u;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[day_index], true, node->id + (uint32_t)child_index);
    if (day_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_COMBOBOX) {
    if (!node->labels || child_index >= node->label_count + 2u) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      out.states |= ER_UI_A11Y_STATE_OPEN;
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_COMBOBOX, node->detail, true, node->id + 1u);
      return ER_UI_OK;
    }
    size_t option_index = child_index - 2u;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->labels[option_index], true, node->id + (uint32_t)child_index);
    if (option_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DIFF_BODY) {
    if (!node->labels || child_index >= node->label_count + (node->active ? 1u : 0u)) return ER_UI_ERR_INVALID_ARGUMENT;
    const char* label = child_index < node->label_count ? node->labels[child_index] : "[diff preview truncated]";
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, label, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CHAT_MESSAGE) {
    er_ui_component_chat_role_t role = (er_ui_component_chat_role_t)node->selected;
    if (role == ER_UI_COMPONENT_CHAT_ROLE_DIFF) {
      if (!node->labels || child_index >= node->label_count + 1u + (node->active ? 1u : 0u)) return ER_UI_ERR_INVALID_ARGUMENT;
      if (child_index == 0u) {
        *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, node->label, false, 0u);
        return ER_UI_OK;
      }
      const char* label = child_index - 1u < node->label_count ? node->labels[child_index - 1u] : "[diff preview truncated]";
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, label, false, 0u);
      return ER_UI_OK;
    }
    if (child_index > 1u) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, child_index == 0u ? node->label : node->detail, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_CONVERSATION) {
    if (child_index >= node->child_count || !node->children[child_index]) return ER_UI_ERR_INVALID_ARGUMENT;
    return er_ui_node_accessibility(node->children[child_index], out_a11y);
  }
  if (node->kind == ER_UI_NODE_RADIO_GROUP) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_RADIO, node->labels[child_index], true, node->id + (uint32_t)child_index);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_CHECKED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DIRECTION) {
    if (child_index > 1u) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_TEXT, child_index == 0u ? node->label : node->detail, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_DRAWER) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_SLIDER, node->aux, true, node->id);
      out.numeric_value = node->number;
      out.states |= ER_UI_A11Y_STATE_HAS_VALUE;
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, "Submit", true, node->id + 1u);
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_INPUT_GROUP) {
    if (child_index == 0u) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, node->label, true, node->id);
      er_ui_a11y_set_value(&out, node->value);
      *out_a11y = out;
      return ER_UI_OK;
    }
    if (child_index == 1u) {
      *out_a11y = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->detail, true, node->id + 1u);
      return ER_UI_OK;
    }
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  if (node->kind == ER_UI_NODE_INPUT_OTP) {
    if (!node->labels || child_index >= node->label_count || (node->labels[child_index] && node->labels[child_index][0] == '-' && node->labels[child_index][1] == 0)) {
      return ER_UI_ERR_INVALID_ARGUMENT;
    }
    er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_TEXTBOX, "otp digit", true, node->id + (uint32_t)child_index);
    er_ui_a11y_set_value(&out, node->labels[child_index]);
    if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_FOCUSED;
    *out_a11y = out;
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_NAVIGATION_MENU) {
    if (!node->labels || child_index > node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index < node->label_count) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_BUTTON, node->labels[child_index], true, node->id + (uint32_t)child_index);
      if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
      *out_a11y = out;
      return ER_UI_OK;
    }
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_LIST_ITEM, node->aux, true, node->id + (uint32_t)node->label_count);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_SIDEBAR) {
    if (!node->labels || child_index > node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    if (child_index < node->label_count) {
      er_ui_a11y_node_t out = er_ui_a11y_base(ER_UI_A11Y_MENU_ITEM, node->labels[child_index], true, node->id + (uint32_t)child_index);
      if (child_index == node->selected) out.states |= ER_UI_A11Y_STATE_SELECTED;
      *out_a11y = out;
      return ER_UI_OK;
    }
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_GROUP, node->value, false, 0u);
    return ER_UI_OK;
  }
  if (node->kind == ER_UI_NODE_SONNER) {
    if (!node->labels || child_index >= node->label_count) return ER_UI_ERR_INVALID_ARGUMENT;
    *out_a11y = er_ui_a11y_base(ER_UI_A11Y_STATUS, node->labels[child_index], false, 0u);
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 16.0f;
  status = er_ui_node_render_text(scene, font, node->label, er_ui_bounds(bounds.x + pad, bounds.y + pad, bounds.w - pad * 2.0f, 26.0f),
                                  theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, node->detail, er_ui_bounds(bounds.x + pad, bounds.y + pad + 28.0f, bounds.w - pad * 2.0f, 24.0f),
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;

  float pad = 12.0f;
  float header_h = er_ui_float_min(36.0f, bounds.h - pad * 2.0f);
  if (header_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;

  float pad = 8.0f;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 16.0f;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 16.0f;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
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
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  float pad = 12.0f;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;

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
