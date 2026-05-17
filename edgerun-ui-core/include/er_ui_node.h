#ifndef ER_UI_NODE_H
#define ER_UI_NODE_H

#include "er_ui_components.h"

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
  ER_UI_NODE_TEXT,
  ER_UI_NODE_BADGE,
  ER_UI_NODE_BUTTON,
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
  const char* label;
  const char* value;
  const char* detail;
  const char* aux;
  const char* const* labels;
  size_t label_count;
  const char* const* cells;
  size_t row_count;
  const float* values;
  size_t value_count;
  size_t selected;
  uint32_t id;
  bool active;
  float number;
  er_ui_shadcn_button_variant_t button_variant;
  er_ui_shadcn_button_size_t button_size;
  er_ui_shadcn_badge_variant_t badge_variant;
  er_ui_color4_t color;
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
er_ui_node_t er_ui_node_text(const char* value);
er_ui_node_t er_ui_node_badge(const char* label, er_ui_shadcn_badge_variant_t variant);
er_ui_node_t er_ui_node_button(const char* label, uint32_t id, er_ui_shadcn_button_variant_t variant);
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
er_ui_node_t er_ui_node_table(const char* const* headers, size_t header_count, const char* const* cells, size_t row_count, uint32_t id_base);
er_ui_node_t er_ui_node_breadcrumb(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id);
er_ui_node_t er_ui_node_toast(const char* message, er_ui_color4_t accent);
er_ui_node_t er_ui_node_empty(const char* title, const char* body);
er_ui_node_t er_ui_node_list_row(const char* title, const char* detail, uint32_t id, bool selected);
er_ui_node_t er_ui_node_field(const char* label, const char* value, uint32_t id);
er_ui_node_t er_ui_node_text_area(const char* label, const char* value, uint32_t id);
er_ui_node_t er_ui_node_tabs(const char* const* labels, size_t label_count, size_t selected, uint32_t base_id);
er_ui_node_t er_ui_node_bar_chart(const char* title, const char* const* labels, const float* values, size_t value_count, uint32_t base_id, size_t selected);
er_ui_node_t er_ui_node_command_palette(const char* placeholder, uint32_t id);
er_ui_node_t er_ui_node_tree_item(const char* label, const char* detail, uint8_t depth, bool expanded, uint32_t id);
er_ui_node_t er_ui_node_section(const char* title, const char* detail);
er_ui_node_t er_ui_node_identity_card(const char* name, const char* node, const char* policy, uint32_t id);
er_ui_node_t er_ui_node_contact_card(const char* name, const char* detail, uint32_t id);
er_ui_node_t er_ui_node_thread_row(const char* title, const char* last_message, bool unread, uint32_t id);
er_ui_node_t er_ui_node_attachment_preview(const char* name, const char* kind, uint32_t id);
er_ui_node_t er_ui_node_capability_grant_row(const char* app, const char* capability, const char* state, uint32_t id);
er_ui_node_t er_ui_node_proof_event_row(const char* title, const char* hash, const char* status_text, uint32_t id);
er_ui_node_t er_ui_node_route_path(const char* label, const char* const* hops, size_t hop_count);
er_ui_node_t er_ui_node_package_card(const char* name, const char* policy, const char* hash, uint32_t id);
er_ui_node_t er_ui_node_receipt_row(const char* label, const char* amount, const char* status_text, uint32_t id);
er_ui_node_t er_ui_node_panel_header(const char* title, const char* subtitle, const char* action_label, uint32_t action_id);
er_ui_node_t er_ui_node_metric_card(const char* title, const char* value, const char* detail, bool has_progress, float progress, er_ui_color4_t accent);
er_ui_node_t er_ui_node_transaction_row(const char* title, const char* subtitle, const char* date, const char* amount, bool positive, uint32_t id);
er_ui_node_t er_ui_node_menu_item(const char* label, const char* detail, const char* badge, bool selected, er_ui_color4_t accent, uint32_t id);
er_ui_node_t er_ui_node_control_row(const char* label, const char* detail, const char* accessory, uint32_t id);
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
er_ui_node_t* er_ui_node_set_draggable(er_ui_node_t* node, uint32_t scope_id, uint32_t item_id, size_t index);
er_ui_node_t* er_ui_node_set_drop_target(er_ui_node_t* node, uint32_t scope_id, size_t index);
er_ui_node_t* er_ui_node_set_reorderable(er_ui_node_t* node, uint32_t scope_id, uint32_t item_id, size_t index);
er_ui_status_t er_ui_node_add_child(er_ui_node_t* parent, er_ui_node_t* child);
const char* er_ui_a11y_role_label(er_ui_a11y_role_t role);
er_ui_status_t er_ui_node_accessibility(const er_ui_node_t* node, er_ui_a11y_node_t* out_a11y);
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
