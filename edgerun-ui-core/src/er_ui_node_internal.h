#ifndef ER_UI_NODE_INTERNAL_H
#define ER_UI_NODE_INTERNAL_H

#include "er_ui_node.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"

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

er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds);

const char* er_ui_component_chat_role_label(er_ui_component_chat_role_t role);
er_ui_component_badge_variant_t er_ui_component_chat_role_badge(er_ui_component_chat_role_t role);
er_ui_icon_t er_ui_component_chat_role_icon(er_ui_component_chat_role_t role);
bool er_ui_component_chat_role_timeline(er_ui_component_chat_role_t role);

#endif
