#include "er_ui_spacing.h"

enum {
  ER_UI_SPACING_PAD_TOP = 0u,
  ER_UI_SPACING_PAD_RIGHT = 1u,
  ER_UI_SPACING_PAD_BOTTOM = 2u,
  ER_UI_SPACING_PAD_LEFT = 3u
};

er_ui_component_padding_t er_ui_component_padding_for_density(er_ui_component_density_t density) {
  switch (density) {
    case ER_UI_COMPONENT_DENSITY_DENSE:
      return (er_ui_component_padding_t){ER_UI_COMPONENT_PAD_X_DENSE, ER_UI_COMPONENT_PAD_Y_DENSE};
    case ER_UI_COMPONENT_DENSITY_SPACIOUS:
      return (er_ui_component_padding_t){ER_UI_COMPONENT_PAD_X_SPACIOUS, ER_UI_COMPONENT_PAD_Y_SPACIOUS};
    case ER_UI_COMPONENT_DENSITY_DEFAULT:
    default:
      return (er_ui_component_padding_t){ER_UI_COMPONENT_PAD_X, ER_UI_COMPONENT_PAD_Y};
  }
}

er_ui_spacing_t er_ui_spacing_default(void) {
  er_ui_spacing_t spacing = {0};
  spacing.card_radius_max = ER_UI_CARD_RADIUS_MAX;
  spacing.card_pad_x = ER_UI_CARD_PAD_X;
  spacing.card_pad_y = ER_UI_CARD_PAD_Y;
  spacing.component_pad_dense = er_ui_component_padding_for_density(ER_UI_COMPONENT_DENSITY_DENSE);
  spacing.component_pad = er_ui_component_padding_for_density(ER_UI_COMPONENT_DENSITY_DEFAULT);
  spacing.component_pad_spacious = er_ui_component_padding_for_density(ER_UI_COMPONENT_DENSITY_SPACIOUS);
  spacing.control_pad_x = ER_UI_CONTROL_PAD_X;
  spacing.control_h = ER_UI_CONTROL_H;
  spacing.compact_control_h = ER_UI_COMPACT_CONTROL_H;
  spacing.large_control_h = ER_UI_LARGE_CONTROL_H;
  spacing.row_pad_x = ER_UI_ROW_PAD_X;
  spacing.row_icon = ER_UI_ROW_ICON;
  spacing.row_icon_gap = ER_UI_ROW_ICON_GAP;
  spacing.row_text_inset = ER_UI_ROW_TEXT_INSET;
  spacing.row_h = ER_UI_ROW_H;
  spacing.list_row_h = ER_UI_LIST_ROW_H;
  spacing.menu_row_h = ER_UI_MENU_ROW_H;
  spacing.command_row_h = ER_UI_COMMAND_ROW_H;
  spacing.table_row_h = ER_UI_TABLE_ROW_H;
  spacing.operation_row_h = ER_UI_OPERATION_ROW_H;
  spacing.package_card_h = ER_UI_PACKAGE_CARD_H;
  spacing.app_store_card_h = ER_UI_APP_STORE_CARD_H;
  spacing.app_surface_inset_x = ER_UI_APP_SURFACE_INSET_X;
  spacing.app_surface_inset_y = ER_UI_APP_SURFACE_INSET_Y;
  spacing.shell_viewport_inset = ER_UI_SHELL_VIEWPORT_INSET;
  spacing.shell_panel_gap = ER_UI_SHELL_PANEL_GAP;
  spacing.shell_topbar_h = ER_UI_SHELL_TOPBAR_H;
  spacing.workspace_chrome_h = ER_UI_WORKSPACE_CHROME_H;
  spacing.workspace_gap = ER_UI_WORKSPACE_GAP;
  spacing.min_touch_target = ER_UI_MIN_TOUCH_TARGET;
  return spacing;
}

er_ui_bounds_t er_ui_row_icon_slot(er_ui_bounds_t row) {
  return er_ui_bounds_with_height_centered(er_ui_bounds(row.x + ER_UI_ROW_PAD_X, row.y, ER_UI_ROW_ICON, row.h), ER_UI_ROW_ICON);
}

er_ui_bounds_t er_ui_row_text_rect(er_ui_bounds_t row, float trailing_reserved_w) {
  float width = er_ui_float_max(row.w - ER_UI_ROW_TEXT_INSET - ER_UI_ROW_PAD_X - trailing_reserved_w, 0.0f);
  return er_ui_bounds(row.x + ER_UI_ROW_TEXT_INSET, row.y, width, row.h);
}

er_ui_component_padding_t er_ui_app_surface_padding_for_width(float width) {
  if (width <= ER_UI_NARROW_VIEWPORT_W) {
    return (er_ui_component_padding_t){ER_UI_APP_SURFACE_INSET_X_NARROW, ER_UI_APP_SURFACE_INSET_Y_NARROW};
  }
  if (width >= ER_UI_WIDE_VIEWPORT_W) {
    return (er_ui_component_padding_t){ER_UI_APP_SURFACE_INSET_X_WIDE, ER_UI_APP_SURFACE_INSET_Y_WIDE};
  }
  return (er_ui_component_padding_t){ER_UI_APP_SURFACE_INSET_X, ER_UI_APP_SURFACE_INSET_Y};
}

er_ui_bounds_t er_ui_app_surface_content_rect(er_ui_bounds_t bounds) {
  er_ui_component_padding_t pad = er_ui_app_surface_padding_for_width(bounds.w);
  return er_ui_bounds_inset(bounds, pad.x, pad.y);
}

er_ui_bounds_t er_ui_system_surface_safe_rect(er_ui_bounds_t bounds) {
  return er_ui_bounds_inset(bounds, ER_UI_SYSTEM_SURFACE_SAFE_INSET, ER_UI_SYSTEM_SURFACE_SAFE_INSET);
}

er_ui_bounds_t er_ui_centered_system_panel(er_ui_bounds_t safe, float min_w, float max_w, float preferred_h, float min_h) {
  float panel_w = safe.w >= min_w ? er_ui_float_clamp(safe.w, min_w, max_w) : er_ui_float_max(safe.w, 0.0f);
  float panel_h = safe.h >= min_h ? er_ui_float_max(er_ui_float_min(preferred_h, safe.h), min_h) : er_ui_float_max(safe.h, 0.0f);
  return er_ui_bounds(safe.x + (safe.w - panel_w) * 0.5f, safe.y + (safe.h - panel_h) * 0.5f, panel_w, panel_h);
}

er_ui_bounds_t er_ui_scroll_content_rect(er_ui_bounds_t bounds, const float padding_trbl[4u]) {
  if (!padding_trbl) return er_ui_bounds(bounds.x, bounds.y, 0.0f, 0.0f);
  float top = padding_trbl[ER_UI_SPACING_PAD_TOP];
  float right = padding_trbl[ER_UI_SPACING_PAD_RIGHT];
  float bottom = padding_trbl[ER_UI_SPACING_PAD_BOTTOM];
  float left = padding_trbl[ER_UI_SPACING_PAD_LEFT];
  return er_ui_bounds(bounds.x + left, bounds.y + top, er_ui_float_max(bounds.w - left - right - ER_UI_SCROLLBAR_RESERVED_W, 0.0f),
                      er_ui_float_max(bounds.h - top - bottom, 0.0f));
}

er_ui_bounds_t er_ui_scrollbar_track_rect(er_ui_bounds_t bounds, er_ui_bounds_t content) {
  return er_ui_bounds(bounds.x + bounds.w - ER_UI_SCROLLBAR_EDGE_INSET, content.y, ER_UI_SCROLLBAR_TRACK_W, content.h);
}

er_ui_bounds_t er_ui_scrollbar_hit_rect(er_ui_bounds_t track) {
  return er_ui_bounds(track.x - (ER_UI_SCROLLBAR_HIT_W - track.w), track.y, ER_UI_SCROLLBAR_HIT_W, track.h);
}
