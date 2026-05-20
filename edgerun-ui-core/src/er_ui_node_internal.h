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
er_ui_bounds_t er_ui_node_center_square(er_ui_bounds_t bounds, float size);
er_ui_status_t er_ui_node_emit_chrome(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_emit_background_gradient(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_emit_card_surface(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_emit_interaction(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds);
er_ui_status_t er_ui_node_render_children(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, er_ui_bounds_t bounds, er_ui_color4_t color);
er_ui_status_t er_ui_node_render_title_detail(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* title,
  const char* detail,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float title_h,
  float detail_y,
  float detail_h);
er_ui_status_t er_ui_node_render_icon(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_icon_t icon, er_ui_color4_t color);
er_ui_status_t er_ui_node_card_inner(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float pad,
  er_ui_bounds_t* out_inner);

er_ui_status_t er_ui_node_render_toast(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_card_summary(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_collapsible(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_accordion(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_hover_card(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_popover(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_sheet(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_kbd(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_menubar(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_radio_group(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_input_group(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_input_otp(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_navigation_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_resizable(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_sidebar(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_sonner(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_aspect_ratio(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_alert_dialog(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_direction(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_drawer(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_dropdown_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_context_menu(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_date_picker(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_carousel(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_calendar(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_combobox(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_diff_body(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_chat_message(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_node_render_label_group(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  bool toggle_group);
er_ui_status_t er_ui_node_render_pagination(
  const er_ui_node_t* node,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);

const char* er_ui_component_chat_role_label(er_ui_component_chat_role_t role);
er_ui_component_badge_variant_t er_ui_component_chat_role_badge(er_ui_component_chat_role_t role);
er_ui_icon_t er_ui_component_chat_role_icon(er_ui_component_chat_role_t role);
bool er_ui_component_chat_role_timeline(er_ui_component_chat_role_t role);

#endif
