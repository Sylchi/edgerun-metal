#ifndef ER_UI_NODE_H
#define ER_UI_NODE_H

#include "er_ui_components.h"
#include "er_ui_icon.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_NODE_MAX_CHILDREN 16u

typedef enum {
  ER_UI_NODE_ROW = 0,
  ER_UI_NODE_COLUMN,
  ER_UI_NODE_CARD,
  ER_UI_NODE_ICON,
  ER_UI_NODE_ICON_BUTTON,
  ER_UI_NODE_TEXT,
  ER_UI_NODE_BADGE,
  ER_UI_NODE_BUTTON,
  ER_UI_NODE_CARD_SUMMARY,
  ER_UI_NODE_BUTTON_GROUP,
  ER_UI_NODE_CHECKBOX,
  ER_UI_NODE_RADIO,
  ER_UI_NODE_SELECT,
  ER_UI_NODE_SLIDER,
  ER_UI_NODE_SEPARATOR,
  ER_UI_NODE_SKELETON,
  ER_UI_NODE_ALERT,
  ER_UI_NODE_AVATAR,
  ER_UI_NODE_PROGRESS,
  ER_UI_NODE_SWITCH,
  ER_UI_NODE_TOGGLE_GROUP,
  ER_UI_NODE_TABLE,
  ER_UI_NODE_BREADCRUMB,
  ER_UI_NODE_TOAST,
  ER_UI_NODE_EMPTY,
  ER_UI_NODE_LIST_ROW,
  ER_UI_NODE_FIELD,
  ER_UI_NODE_TEXT_AREA,
  ER_UI_NODE_TABS,
  ER_UI_NODE_BAR_CHART,
  ER_UI_NODE_COMMAND_PALETTE,
  ER_UI_NODE_TREE_ITEM,
  ER_UI_NODE_SECTION,
  ER_UI_NODE_IDENTITY_CARD,
  ER_UI_NODE_CONTACT_CARD,
  ER_UI_NODE_THREAD_ROW,
  ER_UI_NODE_ATTACHMENT_PREVIEW,
  ER_UI_NODE_CAPABILITY_GRANT_ROW,
  ER_UI_NODE_PROOF_EVENT_ROW,
  ER_UI_NODE_PAGINATION,
  ER_UI_NODE_COLLAPSIBLE,
  ER_UI_NODE_ACCORDION,
  ER_UI_NODE_HOVER_CARD,
  ER_UI_NODE_POPOVER,
  ER_UI_NODE_SHEET,
  ER_UI_NODE_KBD,
  ER_UI_NODE_MENUBAR,
  ER_UI_NODE_RADIO_GROUP,
  ER_UI_NODE_INPUT_GROUP,
  ER_UI_NODE_INPUT_OTP,
  ER_UI_NODE_NAVIGATION_MENU,
  ER_UI_NODE_RESIZABLE,
  ER_UI_NODE_SIDEBAR,
  ER_UI_NODE_SONNER,
  ER_UI_NODE_ASPECT_RATIO,
  ER_UI_NODE_ALERT_DIALOG,
  ER_UI_NODE_DIRECTION,
  ER_UI_NODE_DRAWER,
  ER_UI_NODE_DROPDOWN_MENU,
  ER_UI_NODE_CONTEXT_MENU,
  ER_UI_NODE_DATE_PICKER,
  ER_UI_NODE_CAROUSEL,
  ER_UI_NODE_CALENDAR,
  ER_UI_NODE_COMBOBOX,
  ER_UI_NODE_DIFF_BODY,
  ER_UI_NODE_CHAT_MESSAGE,
  ER_UI_NODE_CONVERSATION,
  ER_UI_NODE_ROUTE_PATH,
  ER_UI_NODE_PACKAGE_CARD,
  ER_UI_NODE_RECEIPT_ROW,
  ER_UI_NODE_PANEL_HEADER,
  ER_UI_NODE_METRIC_CARD,
  ER_UI_NODE_TRANSACTION_ROW,
  ER_UI_NODE_MENU_ITEM,
  ER_UI_NODE_CONTROL_ROW,
  ER_UI_NODE_GRID,
  ER_UI_NODE_MASONRY,
  ER_UI_NODE_BENTO_GRID,
  ER_UI_NODE_SCROLL_AREA,
  ER_UI_NODE_SPACER,
  ER_UI_NODE_TOOLTIP,
  ER_UI_NODE_DIALOG,
  ER_UI_NODE_PROGRESS_RING
} er_ui_node_kind_t;

typedef struct er_ui_node_t er_ui_node_t;

typedef enum {
  ER_UI_COMPONENT_CHAT_ROLE_USER = 0,
  ER_UI_COMPONENT_CHAT_ROLE_ASSISTANT,
  ER_UI_COMPONENT_CHAT_ROLE_REASONING,
  ER_UI_COMPONENT_CHAT_ROLE_DIFF,
  ER_UI_COMPONENT_CHAT_ROLE_TOOL_RUNNING,
  ER_UI_COMPONENT_CHAT_ROLE_TOOL_SUCCESS,
  ER_UI_COMPONENT_CHAT_ROLE_TOOL_ERROR,
  ER_UI_COMPONENT_CHAT_ROLE_ERROR
} er_ui_component_chat_role_t;

typedef enum {
  ER_UI_NODE_COMPOSITION_OK = 0,
  ER_UI_NODE_COMPOSITION_NESTED_CARD
} er_ui_node_composition_issue_kind_t;

typedef struct {
  er_ui_node_composition_issue_kind_t kind;
  er_ui_node_kind_t ancestor_kind;
  er_ui_node_kind_t parent_kind;
  er_ui_node_kind_t node_kind;
  size_t child_index;
  size_t depth;
} er_ui_node_composition_issue_t;

typedef enum {
  ER_UI_A11Y_GENERIC = 0,
  ER_UI_A11Y_GROUP,
  ER_UI_A11Y_TEXT,
  ER_UI_A11Y_BUTTON,
  ER_UI_A11Y_CHECKBOX,
  ER_UI_A11Y_RADIO,
  ER_UI_A11Y_TEXTBOX,
  ER_UI_A11Y_COMBOBOX,
  ER_UI_A11Y_DIALOG,
  ER_UI_A11Y_TOOLTIP,
  ER_UI_A11Y_STATUS,
  ER_UI_A11Y_PROGRESSBAR,
  ER_UI_A11Y_TABLE,
  ER_UI_A11Y_ROW,
  ER_UI_A11Y_CELL,
  ER_UI_A11Y_TAB_LIST,
  ER_UI_A11Y_TAB,
  ER_UI_A11Y_MENU_ITEM,
  ER_UI_A11Y_LIST_ITEM,
  ER_UI_A11Y_NAVIGATION,
  ER_UI_A11Y_SEPARATOR,
  ER_UI_A11Y_IMAGE,
  ER_UI_A11Y_SLIDER
} er_ui_a11y_role_t;

enum {
  ER_UI_A11Y_STATE_DISABLED = 1u << 0,
  ER_UI_A11Y_STATE_CHECKED = 1u << 1,
  ER_UI_A11Y_STATE_SELECTED = 1u << 2,
  ER_UI_A11Y_STATE_EXPANDED = 1u << 3,
  ER_UI_A11Y_STATE_FOCUSED = 1u << 4,
  ER_UI_A11Y_STATE_CURRENT = 1u << 5,
  ER_UI_A11Y_STATE_INVALID = 1u << 6,
  ER_UI_A11Y_STATE_OPEN = 1u << 7,
  ER_UI_A11Y_STATE_HAS_VALUE = 1u << 8
};

typedef struct {
  er_ui_a11y_role_t role;
  const char* label;
  const char* value;
  bool has_id;
  uint32_t id;
  uint32_t states;
  float numeric_value;
} er_ui_a11y_node_t;

struct er_ui_node_t {
  er_ui_node_kind_t kind;
  er_ui_bounds_t bounds;
  float gap;
  float padding;
  float margin;
  size_t column_span;
  size_t row_span;
  const char* label;
  const char* value;
  const char* detail;
  const char* aux;
  const char* extra;
  const char* const* labels;
  size_t label_count;
  const char* const* cells;
  size_t row_count;
  const float* values;
  size_t value_count;
  const er_ui_icon_t* icons;
  const er_ui_color4_t* colors;
  size_t selected;
  uint32_t id;
  bool active;
  float number;
  er_ui_component_button_variant_t button_variant;
  er_ui_component_button_size_t button_size;
  er_ui_component_badge_variant_t badge_variant;
  er_ui_icon_t icon;
  er_ui_color4_t color;
  bool has_background_gradient;
  er_ui_color4_t background_gradient_from;
  er_ui_color4_t background_gradient_to;
  bool has_transition;
  er_ui_transition_t transition;
  bool has_drag_source;
  er_ui_drag_source_t drag_source;
  bool has_drop_target;
  er_ui_drop_target_t drop_target;
  er_ui_node_t* children[ER_UI_NODE_MAX_CHILDREN];
  size_t child_count;
};

er_ui_node_t er_ui_node_row(void);
er_ui_node_t er_ui_node_column(void);
er_ui_node_t er_ui_node_card(void);
er_ui_node_t er_ui_node_icon(er_ui_icon_t icon, const char* label, er_ui_color4_t color);
er_ui_node_t er_ui_node_icon_button(
  er_ui_icon_t icon,
  const char* label,
  uint32_t id,
  er_ui_component_button_variant_t variant);
er_ui_node_t er_ui_node_text(const char* value);
er_ui_node_t er_ui_node_badge(const char* label, er_ui_component_badge_variant_t variant);
er_ui_node_t er_ui_node_button(const char* label, uint32_t id, er_ui_component_button_variant_t variant);
er_ui_node_t er_ui_node_card_summary(const char* title, const char* detail);
er_ui_node_t er_ui_node_button_group(const char* const* labels, size_t label_count, uint32_t base_id);
er_ui_node_t er_ui_node_checkbox(const char* label, bool checked, uint32_t id);
er_ui_node_t er_ui_node_radio(const char* label, bool selected, uint32_t id);
er_ui_node_t er_ui_node_select(const char* label, const char* value, uint32_t id);
er_ui_node_t er_ui_node_slider(const char* label, float value, uint32_t id);
er_ui_node_t er_ui_node_separator(void);
er_ui_node_t er_ui_node_skeleton(void);
er_ui_node_t er_ui_node_alert(const char* title, const char* body, er_ui_color4_t accent);
er_ui_node_t er_ui_node_avatar(const char* label, er_ui_color4_t color, bool online);
er_ui_node_t er_ui_node_progress(float value);
er_ui_node_t er_ui_node_switch(bool checked, uint32_t id);
er_ui_node_t er_ui_node_toggle_group(
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_table(
  const char* const* headers,
  size_t header_count,
  const char* const* cells,
  size_t row_count,
  uint32_t id_base);
er_ui_node_t er_ui_node_breadcrumb(
  const char* const* labels,
  size_t label_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_toast(const char* message, er_ui_color4_t accent);
er_ui_node_t er_ui_node_toast_icon(const char* message, er_ui_icon_t icon, er_ui_color4_t accent);
er_ui_node_t er_ui_node_empty(const char* title, const char* body);
er_ui_node_t er_ui_node_list_row(const char* title, const char* detail, uint32_t id, bool selected);
er_ui_node_t er_ui_node_field(const char* label, const char* value, uint32_t id);
er_ui_node_t er_ui_node_text_area(const char* label, const char* value, uint32_t id);
er_ui_node_t er_ui_node_tabs(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id);
er_ui_node_t er_ui_node_bar_chart(
  const char* title,
  const char* const* labels,
  const float* values,
  size_t value_count,
  uint32_t base_id,
  size_t selected);
er_ui_node_t er_ui_node_command_palette(const char* placeholder, uint32_t id);
er_ui_node_t er_ui_node_tree_item(const char* label, const char* detail, uint8_t depth, bool expanded, uint32_t id);
er_ui_node_t er_ui_node_section(const char* title, const char* detail);
er_ui_node_t er_ui_node_pagination(const char* const* pages, size_t page_count, size_t selected, uint32_t base_id);
er_ui_node_t er_ui_node_collapsible(
  const char* title,
  const char* const* row_titles,
  const char* const* row_details,
  size_t row_count,
  bool open,
  uint32_t base_id);
er_ui_node_t er_ui_node_accordion(
  const char* const* item_titles,
  const char* const* item_bodies,
  size_t item_count,
  uint32_t base_id);
er_ui_node_t er_ui_node_hover_card(
  const char* label,
  const char* detail,
  const char* body,
  er_ui_color4_t color);
er_ui_node_t er_ui_node_popover(
  const char* button_label,
  const char* title,
  const char* detail,
  const char* field_label,
  const char* field_value,
  uint32_t base_id);
er_ui_node_t er_ui_node_sheet(
  const char* title,
  const char* detail,
  const char* field_label,
  const char* field_value,
  const char* button_label,
  uint32_t base_id);
er_ui_node_t er_ui_node_kbd(const char* const* keys, size_t key_count, const char* label);
er_ui_node_t er_ui_node_menubar(const char* const* items, size_t item_count, size_t selected, uint32_t base_id);
er_ui_node_t er_ui_node_radio_group(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id);
er_ui_node_t er_ui_node_input_group(const char* label, const char* value, const char* button_label, uint32_t id);
er_ui_node_t er_ui_node_input_otp(
  const char* const* values,
  size_t value_count,
  size_t focused_index,
  uint32_t base_id);
er_ui_node_t er_ui_node_navigation_menu(
  const char* const* tabs,
  size_t tab_count,
  size_t selected,
  const char* title,
  const char* detail,
  const char* row_title,
  const char* row_detail,
  uint32_t base_id);
er_ui_node_t er_ui_node_resizable(const char* const* labels, size_t label_count);
er_ui_node_t er_ui_node_sidebar(
  const char* title,
  const char* detail,
  const char* const* items,
  size_t item_count,
  size_t selected,
  const char* main_title,
  const char* main_detail,
  uint32_t base_id);
er_ui_node_t er_ui_node_sonner(
  const char* const* messages,
  const er_ui_icon_t* icons,
  const er_ui_color4_t* accents,
  size_t message_count);
er_ui_node_t er_ui_node_aspect_ratio(const char* label, er_ui_icon_t icon);
er_ui_node_t er_ui_node_alert_dialog(const char* title, const char* body, er_ui_icon_t icon);
er_ui_node_t er_ui_node_direction(const char* ltr_text, const char* rtl_text);
er_ui_node_t er_ui_node_drawer(
  const char* title,
  const char* detail,
  const char* slider_label,
  float value,
  uint32_t base_id);
er_ui_node_t er_ui_node_dropdown_menu(
  const char* const* labels,
  const char* const* shortcuts,
  size_t item_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_context_menu(
  const char* title,
  const char* detail,
  const char* const* labels,
  const char* const* shortcuts,
  size_t item_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_date_picker(
  const char* label,
  const char* month,
  const char* const* days,
  size_t day_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_carousel(const char* const* items, size_t item_count, uint32_t base_id);
er_ui_node_t er_ui_node_calendar(
  const char* month,
  const char* const* days,
  size_t day_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_combobox(
  const char* label,
  const char* value,
  const char* placeholder,
  const char* const* options,
  size_t option_count,
  size_t selected,
  uint32_t base_id);
er_ui_node_t er_ui_node_diff_body(const char* const* lines, size_t line_count, bool truncated);
er_ui_node_t er_ui_node_chat_diff_message(
  const char* heading,
  const char* const* lines,
  size_t line_count,
  bool truncated);
er_ui_node_t er_ui_node_conversation(float scroll_offset_px, uint32_t scroll_id);
er_ui_node_t er_ui_node_panel_header(
  const char* title,
  const char* subtitle,
  const char* action_label,
  uint32_t action_id);
er_ui_node_t er_ui_node_metric_card(
  const char* title,
  const char* value,
  const char* detail,
  bool has_progress,
  float progress,
  er_ui_color4_t accent);
er_ui_node_t er_ui_node_transaction_row(
  const char* title,
  const char* subtitle,
  const char* date,
  const char* amount,
  bool positive,
  uint32_t id);
er_ui_node_t er_ui_node_menu_item(
  const char* label,
  const char* detail,
  const char* badge,
  bool selected,
  er_ui_color4_t accent,
  uint32_t id);
er_ui_node_t er_ui_node_grid(size_t columns);
er_ui_node_t er_ui_node_masonry(size_t columns);
er_ui_node_t er_ui_node_bento_grid(size_t columns);
er_ui_node_t er_ui_node_scroll_area(float offset_px, uint32_t id);
er_ui_node_t er_ui_node_spacer(void);
er_ui_node_t er_ui_node_tooltip(const char* text);
er_ui_node_t er_ui_node_dialog(const char* title, const char* body, er_ui_color4_t accent);
er_ui_node_t er_ui_node_progress_ring(float value, er_ui_color4_t color);
er_ui_node_t* er_ui_node_set_bounds(er_ui_node_t* node, er_ui_bounds_t bounds);
er_ui_node_t* er_ui_node_set_gap(er_ui_node_t* node, float gap);
er_ui_node_t* er_ui_node_set_padding(er_ui_node_t* node, float padding);
er_ui_node_t* er_ui_node_set_margin(er_ui_node_t* node, float margin);
er_ui_node_t* er_ui_node_set_spacing(er_ui_node_t* node, float padding, float gap, float margin);
er_ui_node_t* er_ui_node_set_grid_span(er_ui_node_t* node, size_t column_span, size_t row_span);
er_ui_node_t* er_ui_node_set_background_gradient(
  er_ui_node_t* node,
  er_ui_color4_t from,
  er_ui_color4_t to);
er_ui_node_t* er_ui_node_set_transition(er_ui_node_t* node, er_ui_transition_t transition);
er_ui_node_t* er_ui_node_set_draggable(
  er_ui_node_t* node,
  uint32_t scope_id,
  uint32_t item_id,
  size_t index);
er_ui_node_t* er_ui_node_set_drop_target(er_ui_node_t* node, uint32_t scope_id, size_t index);
er_ui_node_t* er_ui_node_set_reorderable(
  er_ui_node_t* node,
  uint32_t scope_id,
  uint32_t item_id,
  size_t index);
er_ui_status_t er_ui_node_add_child(er_ui_node_t* parent, er_ui_node_t* child);
const char* er_ui_node_kind_label(er_ui_node_kind_t kind);
const char* er_ui_node_composition_issue_label(er_ui_node_composition_issue_kind_t kind);
er_ui_status_t er_ui_node_validate_composition(
  const er_ui_node_t* node,
  er_ui_node_composition_issue_t* out_issue);
er_ui_status_t er_ui_node_child_bounds(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_bounds_t bounds,
  er_ui_bounds_t* out_bounds);
const char* er_ui_a11y_role_label(er_ui_a11y_role_t role);
er_ui_status_t er_ui_node_accessibility(const er_ui_node_t* node, er_ui_a11y_node_t* out_a11y);
er_ui_status_t er_ui_node_accessibility_child(
  const er_ui_node_t* node,
  size_t child_index,
  er_ui_a11y_node_t* out_a11y);
er_ui_status_t er_ui_node_render(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);

#ifdef __cplusplus
}
#endif

#endif
