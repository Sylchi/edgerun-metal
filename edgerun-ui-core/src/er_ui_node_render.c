#include "er_ui_node_internal.h"

er_ui_bounds_t er_ui_node_resolve_bounds(const er_ui_node_t* node, er_ui_bounds_t bounds) {
  if (!node) return bounds;
  er_ui_bounds_t resolved = er_ui_bounds_valid(node->bounds) ? node->bounds : bounds;
  if (node->margin > 0.0f) return er_ui_bounds_inset(resolved, node->margin, node->margin);
  return resolved;
}

er_ui_status_t er_ui_node_emit_chrome(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  (void)bounds;
  (void)theme;
  if (node->has_transition) {
    er_ui_status_t status = er_ui_scene_push_transition(scene, node->transition);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_emit_background_gradient(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!node || !scene) return ER_UI_ERR_INVALID_ARGUMENT;
  if (node->has_background_gradient) {
    return er_ui_scene_push_rect(scene,
                                 er_ui_rect_linear_gradient(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.card, node->background_gradient_from,
                                                           node->background_gradient_to));
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_node_emit_card_surface(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
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

er_ui_status_t er_ui_node_emit_interaction(const er_ui_node_t* node, er_ui_scene_t* scene, er_ui_bounds_t bounds) {
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
er_ui_status_t er_ui_node_render_children(
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

er_ui_status_t er_ui_node_render_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, er_ui_bounds_t bounds, er_ui_color4_t color) {
  if (!scene || !font || !text || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_NODE_TEXT_BUDGET, bounds.x, bounds.y + er_ui_float_min(bounds.h * 0.62f, 22.0f), color);
}

er_ui_status_t er_ui_node_render_title_detail(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  const char* title,
  const char* detail,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float title_h,
  float detail_y,
  float detail_h) {
  if (!scene || !font || !title || !detail || !er_ui_bounds_valid(bounds)) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }
  er_ui_status_t status =
    er_ui_node_render_text(scene, font, title, er_ui_bounds(bounds.x, bounds.y, bounds.w, title_h), theme.colors.text);
  if (status != ER_UI_OK) return status;
  return er_ui_node_render_text(scene, font, detail, er_ui_bounds(bounds.x, bounds.y + detail_y, bounds.w, detail_h), theme.colors.muted);
}

er_ui_status_t er_ui_node_render_icon(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_icon_t icon, er_ui_color4_t color) {
  if (!scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_icon(&painter, bounds, icon, color);
}

er_ui_status_t er_ui_node_card_inner(
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  float pad,
  er_ui_bounds_t* out_inner) {
  if (!out_inner) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_component_card_emit(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t inner = er_ui_bounds_inset(bounds, pad, pad);
  if (!er_ui_bounds_valid(inner)) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_inner = inner;
  return ER_UI_OK;
}
er_ui_bounds_t er_ui_node_center_square(er_ui_bounds_t bounds, float size) {
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
    case ER_UI_NODE_CONTACT_CARD:
      return er_ui_component_contact_card_emit(scene, font, rect, theme, node->label, node->detail, node->id);
    case ER_UI_NODE_THREAD_ROW:
      return er_ui_component_thread_row_emit(scene, font, rect, theme, node->label, node->detail, node->active, node->id);
    case ER_UI_NODE_ATTACHMENT_PREVIEW:
      return er_ui_component_attachment_preview_emit(scene, font, rect, theme, node->label, node->detail, node->id);
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
    case ER_UI_NODE_PANEL_HEADER:
      return er_ui_component_panel_header_emit(scene, font, rect, theme, node->label, node->detail, node->value, node->id);
    case ER_UI_NODE_METRIC_CARD:
      return er_ui_component_metric_card_emit(scene, font, rect, theme, node->label, node->value, node->detail, node->active, node->number, node->color);
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
