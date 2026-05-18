#ifndef ER_UI_SPACING_H
#define ER_UI_SPACING_H

#include "er_ui_primitives.h"

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_SPACE_1 4.0f
#define ER_UI_SPACE_2 6.0f
#define ER_UI_SPACE_3 8.0f
#define ER_UI_SPACE_4 10.0f
#define ER_UI_SPACE_5 12.0f
#define ER_UI_SPACE_6 14.0f
#define ER_UI_SPACE_7 16.0f
#define ER_UI_SPACE_8 18.0f
#define ER_UI_SPACE_9 20.0f
#define ER_UI_SPACE_10 22.0f
#define ER_UI_SPACE_11 24.0f
#define ER_UI_SPACE_12 32.0f
#define ER_UI_SPACE_13 40.0f
#define ER_UI_SPACE_14 48.0f
#define ER_UI_SPACE_15 56.0f
#define ER_UI_SPACE_16 64.0f

#define ER_UI_CARD_RADIUS_MAX ER_UI_SPACE_3
#define ER_UI_CARD_PAD_X ER_UI_SPACE_7
#define ER_UI_CARD_PAD_Y ER_UI_SPACE_6
#define ER_UI_COMPONENT_PAD_X_DENSE ER_UI_SPACE_5
#define ER_UI_COMPONENT_PAD_Y_DENSE ER_UI_SPACE_4
#define ER_UI_COMPONENT_PAD_X ER_UI_CARD_PAD_X
#define ER_UI_COMPONENT_PAD_Y ER_UI_CARD_PAD_Y
#define ER_UI_COMPONENT_PAD_X_SPACIOUS ER_UI_SPACE_9
#define ER_UI_COMPONENT_PAD_Y_SPACIOUS ER_UI_SPACE_8
#define ER_UI_CONTROL_PAD_X ER_UI_SPACE_6
#define ER_UI_COMPACT_CONTROL_H ER_UI_SPACE_12
#define ER_UI_CONTROL_H ER_UI_SPACE_13
#define ER_UI_LARGE_CONTROL_H ER_UI_SPACE_14
#define ER_UI_BUTTON_H_COMPACT ER_UI_COMPACT_CONTROL_H
#define ER_UI_BUTTON_H ER_UI_CONTROL_H
#define ER_UI_BUTTON_H_LARGE ER_UI_LARGE_CONTROL_H
#define ER_UI_ICON_BUTTON_COMPACT ER_UI_SPACE_12
#define ER_UI_ICON_BUTTON ER_UI_CONTROL_H
#define ER_UI_ICON_BUTTON_LARGE ER_UI_LARGE_CONTROL_H
#define ER_UI_TOOLBAR_CONTROL ER_UI_CONTROL_H
#define ER_UI_TOOLBAR_ICON_BUTTON ER_UI_ICON_BUTTON
#define ER_UI_FORM_LABEL_H ER_UI_SPACE_9
#define ER_UI_FORM_LABEL_GAP ER_UI_SPACE_1
#define ER_UI_FORM_FIELD_Y (ER_UI_FORM_LABEL_H + ER_UI_FORM_LABEL_GAP)
#define ER_UI_FORM_HELPER_GAP ER_UI_SPACE_2
#define ER_UI_FORM_HELPER_Y (ER_UI_FORM_FIELD_Y + ER_UI_CONTROL_H + ER_UI_FORM_HELPER_GAP)
#define ER_UI_TEXT_AREA_PAD_Y ER_UI_SPACE_5
#define ER_UI_TEXT_AREA_LINE_H ER_UI_SPACE_10
#define ER_UI_TEXT_AREA_RESERVED_Y ER_UI_FORM_FIELD_Y
#define ER_UI_ROW_PAD_X ER_UI_SPACE_6
#define ER_UI_ROW_ICON 34.0f
#define ER_UI_ROW_ICON_GAP ER_UI_SPACE_5
#define ER_UI_ROW_TEXT_INSET (ER_UI_ROW_PAD_X + ER_UI_ROW_ICON + ER_UI_ROW_ICON_GAP)
#define ER_UI_ROW_H 58.0f
#define ER_UI_LIST_ROW_H ER_UI_ROW_H
#define ER_UI_MENU_ROW_H ER_UI_SPACE_14
#define ER_UI_COMMAND_ROW_H ER_UI_SPACE_14
#define ER_UI_TABLE_ROW_H ER_UI_SPACE_16
#define ER_UI_TABLE_CELL_PAD_X ER_UI_SPACE_5
#define ER_UI_TABLE_CELL_PAD_Y ER_UI_SPACE_3
#define ER_UI_OPERATION_ROW_H 78.0f
#define ER_UI_OPERATION_ROW_CONTENT_H (ER_UI_OPERATION_ROW_H - ER_UI_SPACE_1 * 0.5f)
#define ER_UI_OPERATION_ROW_PANEL_PAD ER_UI_SPACE_2
#define ER_UI_PACKAGE_CARD_H 112.0f
#define ER_UI_APP_STORE_CARD_H 138.0f
#define ER_UI_APP_CARD_GRID_GAP ER_UI_SPACE_4
#define ER_UI_NARROW_VIEWPORT_W 520.0f
#define ER_UI_WIDE_VIEWPORT_W 1180.0f
#define ER_UI_APP_SURFACE_INSET_X_NARROW ER_UI_SPACE_4
#define ER_UI_APP_SURFACE_INSET_Y_NARROW ER_UI_SPACE_4
#define ER_UI_APP_SURFACE_INSET_X ER_UI_SPACE_6
#define ER_UI_APP_SURFACE_INSET_Y ER_UI_SPACE_6
#define ER_UI_APP_SURFACE_INSET_X_WIDE ER_UI_SPACE_7
#define ER_UI_APP_SURFACE_INSET_Y_WIDE ER_UI_SPACE_7
#define ER_UI_SHELL_VIEWPORT_INSET ER_UI_SPACE_4
#define ER_UI_SHELL_PANEL_GAP ER_UI_SPACE_3
#define ER_UI_SHELL_TOPBAR_H 42.0f
#define ER_UI_SHELL_PANEL_W 360.0f
#define ER_UI_SHELL_PANEL_H 392.0f
#define ER_UI_SYSTEM_SURFACE_SAFE_INSET ER_UI_SHELL_VIEWPORT_INSET
#define ER_UI_WORKSPACE_CHROME_H 34.0f
#define ER_UI_WORKSPACE_GAP ER_UI_SPACE_2
#define ER_UI_WORKSPACE_MIN_TILE_W 220.0f
#define ER_UI_WORKSPACE_MIN_TILE_H 160.0f
#define ER_UI_WORKSPACE_TAB_MIN_W 82.0f
#define ER_UI_WORKSPACE_TAB_MAX_W 180.0f
#define ER_UI_TOOLTIP_PAD_X ER_UI_SPACE_4
#define ER_UI_DIALOG_CONTENT_INSET_X ER_UI_SPACE_8
#define ER_UI_DIALOG_CONTENT_INSET_Y 88.0f
#define ER_UI_TOAST_PAD_X ER_UI_SPACE_5
#define ER_UI_POPOVER_PAD_X ER_UI_SPACE_5
#define ER_UI_POPOVER_GAP ER_UI_SPACE_2
#define ER_UI_SCROLLBAR_RESERVED_W ER_UI_SPACE_4
#define ER_UI_SCROLLBAR_TRACK_W 3.0f
#define ER_UI_SCROLLBAR_HIT_W ER_UI_SPACE_4
#define ER_UI_SCROLLBAR_EDGE_INSET ER_UI_SPACE_2
#define ER_UI_MIN_TOUCH_TARGET 32.0f

typedef enum {
  ER_UI_COMPONENT_DENSITY_DENSE = 0,
  ER_UI_COMPONENT_DENSITY_DEFAULT,
  ER_UI_COMPONENT_DENSITY_SPACIOUS
} er_ui_component_density_t;

typedef struct {
  float x;
  float y;
} er_ui_component_padding_t;

typedef struct {
  float card_radius_max;
  float card_pad_x;
  float card_pad_y;
  er_ui_component_padding_t component_pad_dense;
  er_ui_component_padding_t component_pad;
  er_ui_component_padding_t component_pad_spacious;
  float control_pad_x;
  float control_h;
  float compact_control_h;
  float large_control_h;
  float row_pad_x;
  float row_icon;
  float row_icon_gap;
  float row_text_inset;
  float row_h;
  float list_row_h;
  float menu_row_h;
  float command_row_h;
  float table_row_h;
  float operation_row_h;
  float package_card_h;
  float app_store_card_h;
  float app_surface_inset_x;
  float app_surface_inset_y;
  float shell_viewport_inset;
  float shell_panel_gap;
  float shell_topbar_h;
  float workspace_chrome_h;
  float workspace_gap;
  float min_touch_target;
} er_ui_spacing_t;

typedef struct {
  er_ui_bounds_t bounds;
  size_t columns;
  float column_w;
  float gap_x;
  float gap_y;
} er_ui_responsive_grid_t;

typedef struct {
  er_ui_bounds_t side;
  er_ui_bounds_t main;
  bool stacked;
} er_ui_responsive_sidecar_t;

typedef struct {
  er_ui_bounds_t bounds;
  float cursor_y;
  float gap;
} er_ui_vertical_flow_t;

er_ui_component_padding_t er_ui_component_padding_for_density(er_ui_component_density_t density);
er_ui_spacing_t er_ui_spacing_default(void);
er_ui_responsive_sidecar_t er_ui_responsive_sidecar(
  er_ui_bounds_t bounds,
  float min_side_w,
  float preferred_side_w,
  float min_main_w,
  float gap,
  float stacked_side_h);
er_ui_responsive_grid_t er_ui_responsive_grid(
  er_ui_bounds_t bounds,
  float min_column_w,
  size_t max_columns,
  float gap_x,
  float gap_y);
size_t er_ui_responsive_grid_row_count(er_ui_responsive_grid_t grid, size_t item_count);
float er_ui_responsive_grid_height(er_ui_responsive_grid_t grid, size_t item_count, float row_h);
er_ui_bounds_t er_ui_responsive_grid_cell(er_ui_responsive_grid_t grid, size_t index, float row_h);
er_ui_bounds_t er_ui_responsive_grid_span(er_ui_responsive_grid_t grid, size_t index, size_t column_span, float row_h);
er_ui_vertical_flow_t er_ui_vertical_flow(er_ui_bounds_t bounds, float gap);
er_ui_bounds_t er_ui_vertical_flow_next(er_ui_vertical_flow_t* flow, float preferred_h);
er_ui_bounds_t er_ui_vertical_flow_remaining(const er_ui_vertical_flow_t* flow);
er_ui_bounds_t er_ui_row_icon_slot(er_ui_bounds_t row);
er_ui_bounds_t er_ui_row_text_rect(er_ui_bounds_t row, float trailing_reserved_w);
er_ui_component_padding_t er_ui_app_surface_padding_for_width(float width);
er_ui_bounds_t er_ui_app_surface_content_rect(er_ui_bounds_t bounds);
er_ui_bounds_t er_ui_system_surface_safe_rect(er_ui_bounds_t bounds);
er_ui_bounds_t er_ui_centered_system_panel(
  er_ui_bounds_t safe,
  float min_w,
  float max_w,
  float preferred_h,
  float min_h);
er_ui_bounds_t er_ui_scroll_content_rect(er_ui_bounds_t bounds, const float padding_trbl[4u]);
er_ui_bounds_t er_ui_scrollbar_track_rect(er_ui_bounds_t bounds, er_ui_bounds_t content);
er_ui_bounds_t er_ui_scrollbar_hit_rect(er_ui_bounds_t track);

#ifdef __cplusplus
}
#endif

#endif
