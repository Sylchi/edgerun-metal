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
  ER_UI_NODE_LIST_ROW
} er_ui_node_kind_t;

typedef struct er_ui_node_t er_ui_node_t;

struct er_ui_node_t {
  er_ui_node_kind_t kind;
  er_ui_bounds_t bounds;
  float gap;
  float padding;
  const char* label;
  const char* value;
  const char* detail;
  const char* const* labels;
  size_t label_count;
  const char* const* cells;
  size_t row_count;
  size_t selected;
  uint32_t id;
  bool active;
  float number;
  er_ui_shadcn_button_variant_t button_variant;
  er_ui_shadcn_button_size_t button_size;
  er_ui_shadcn_badge_variant_t badge_variant;
  er_ui_color4_t color;
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
er_ui_node_t* er_ui_node_set_bounds(er_ui_node_t* node, er_ui_bounds_t bounds);
er_ui_node_t* er_ui_node_set_gap(er_ui_node_t* node, float gap);
er_ui_node_t* er_ui_node_set_padding(er_ui_node_t* node, float padding);
er_ui_status_t er_ui_node_add_child(er_ui_node_t* parent, er_ui_node_t* child);
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
