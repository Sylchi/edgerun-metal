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

er_ui_responsive_sidecar_t er_ui_responsive_sidecar(
  er_ui_bounds_t bounds,
  float min_side_w,
  float preferred_side_w,
  float min_main_w,
  float gap,
  float stacked_side_h) {
  er_ui_responsive_sidecar_t layout = {0};
  if (!er_ui_bounds_valid(bounds) || min_side_w <= 0.0f || preferred_side_w < min_side_w || min_main_w <= 0.0f || gap < 0.0f || stacked_side_h <= 0.0f) {
    return layout;
  }

  float preferred_total_w = preferred_side_w + gap + min_main_w;
  if (bounds.w >= preferred_total_w) {
    layout.side = er_ui_bounds(bounds.x, bounds.y, preferred_side_w, bounds.h);
    layout.main = er_ui_bounds(bounds.x + preferred_side_w + gap, bounds.y, bounds.w - preferred_side_w - gap, bounds.h);
    return layout;
  }

  float minimum_total_w = min_side_w + gap + min_main_w;
  if (bounds.w >= minimum_total_w) {
    float side_w = er_ui_float_max(min_side_w, bounds.w - gap - min_main_w);
    layout.side = er_ui_bounds(bounds.x, bounds.y, side_w, bounds.h);
    layout.main = er_ui_bounds(bounds.x + side_w + gap, bounds.y, bounds.w - side_w - gap, bounds.h);
    return layout;
  }

  layout.stacked = true;
  float side_h = er_ui_float_min(stacked_side_h, bounds.h);
  float main_y = bounds.y + side_h + gap;
  layout.side = er_ui_bounds(bounds.x, bounds.y, bounds.w, side_h);
  layout.main = er_ui_bounds(bounds.x, main_y, bounds.w, er_ui_float_max(bounds.y + bounds.h - main_y, 0.0f));
  return layout;
}

er_ui_responsive_grid_t er_ui_responsive_grid(
  er_ui_bounds_t bounds,
  float min_column_w,
  size_t max_columns,
  float gap_x,
  float gap_y) {
  er_ui_responsive_grid_t grid = {0};
  if (!er_ui_bounds_valid(bounds) || min_column_w <= 0.0f || max_columns == 0u || gap_x < 0.0f || gap_y < 0.0f) return grid;
  grid.bounds = bounds;
  grid.columns = 1u;
  grid.gap_x = gap_x;
  grid.gap_y = gap_y;
  while (grid.columns < max_columns) {
    size_t next_columns = grid.columns + 1u;
    float required_w = min_column_w * (float)next_columns + gap_x * (float)(next_columns - 1u);
    if (required_w > bounds.w) break;
    grid.columns = next_columns;
  }
  float total_gap = gap_x * (float)(grid.columns - 1u);
  grid.column_w = er_ui_float_max((bounds.w - total_gap) / (float)grid.columns, 0.0f);
  return grid;
}

er_ui_bounds_t er_ui_responsive_grid_cell(er_ui_responsive_grid_t grid, size_t index, float row_h) {
  return er_ui_responsive_grid_span(grid, index, 1u, row_h);
}

size_t er_ui_responsive_grid_row_count(er_ui_responsive_grid_t grid, size_t item_count) {
  if (grid.columns == 0u || item_count == 0u) return 0u;
  return (item_count + grid.columns - 1u) / grid.columns;
}

float er_ui_responsive_grid_height(er_ui_responsive_grid_t grid, size_t item_count, float row_h) {
  if (row_h <= 0.0f) return 0.0f;
  size_t rows = er_ui_responsive_grid_row_count(grid, item_count);
  if (rows == 0u) return 0.0f;
  return row_h * (float)rows + grid.gap_y * (float)(rows - 1u);
}

er_ui_bounds_t er_ui_responsive_grid_span(er_ui_responsive_grid_t grid, size_t index, size_t column_span, float row_h) {
  if (grid.columns == 0u || grid.column_w <= 0.0f || row_h <= 0.0f || !er_ui_bounds_valid(grid.bounds)) return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  if (column_span == 0u) return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  size_t column = index % grid.columns;
  size_t row = index / grid.columns;
  size_t remaining_columns = grid.columns - column;
  size_t span = column_span < remaining_columns ? column_span : remaining_columns;
  float width = grid.column_w * (float)span + grid.gap_x * (float)(span - 1u);
  return er_ui_bounds(
    grid.bounds.x + (grid.column_w + grid.gap_x) * (float)column,
    grid.bounds.y + (row_h + grid.gap_y) * (float)row,
    width,
    row_h);
}

er_ui_uniform_grid_t er_ui_uniform_grid(er_ui_bounds_t bounds, size_t columns, size_t rows, float gap_x, float gap_y) {
  er_ui_uniform_grid_t grid = {0};
  if (!er_ui_bounds_valid(bounds) || columns == 0u || rows == 0u || gap_x < 0.0f || gap_y < 0.0f) return grid;
  float total_gap_x = gap_x * (float)(columns - 1u);
  float total_gap_y = gap_y * (float)(rows - 1u);
  float cell_w = (bounds.w - total_gap_x) / (float)columns;
  float cell_h = (bounds.h - total_gap_y) / (float)rows;
  if (cell_w <= 0.0f || cell_h <= 0.0f) return grid;
  grid.bounds = bounds;
  grid.columns = columns;
  grid.rows = rows;
  grid.cell_w = cell_w;
  grid.cell_h = cell_h;
  grid.gap_x = gap_x;
  grid.gap_y = gap_y;
  return grid;
}

er_ui_bounds_t er_ui_uniform_grid_cell(er_ui_uniform_grid_t grid, size_t index) {
  return er_ui_uniform_grid_span(grid, index, 1u, 1u);
}

er_ui_bounds_t er_ui_uniform_grid_span(er_ui_uniform_grid_t grid, size_t index, size_t column_span, size_t row_span) {
  if (grid.columns == 0u || grid.rows == 0u || grid.cell_w <= 0.0f || grid.cell_h <= 0.0f || !er_ui_bounds_valid(grid.bounds)) {
    return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  }
  if (column_span == 0u || row_span == 0u) return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  size_t column = index % grid.columns;
  size_t row = index / grid.columns;
  if (row >= grid.rows) return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  size_t available_columns = grid.columns - column;
  size_t available_rows = grid.rows - row;
  size_t columns = column_span < available_columns ? column_span : available_columns;
  size_t rows = row_span < available_rows ? row_span : available_rows;
  float width = grid.cell_w * (float)columns + grid.gap_x * (float)(columns - 1u);
  float height = grid.cell_h * (float)rows + grid.gap_y * (float)(rows - 1u);
  return er_ui_bounds(
    grid.bounds.x + (grid.cell_w + grid.gap_x) * (float)column,
    grid.bounds.y + (grid.cell_h + grid.gap_y) * (float)row,
    width,
    height);
}

er_ui_vertical_flow_t er_ui_vertical_flow(er_ui_bounds_t bounds, float gap) {
  er_ui_vertical_flow_t flow = {0};
  if (!er_ui_bounds_valid(bounds) || gap < 0.0f) return flow;
  flow.bounds = bounds;
  flow.cursor_y = bounds.y;
  flow.gap = gap;
  return flow;
}

er_ui_bounds_t er_ui_vertical_flow_next(er_ui_vertical_flow_t* flow, float preferred_h) {
  if (!flow || preferred_h <= 0.0f || !er_ui_bounds_valid(flow->bounds)) return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  float remaining_h = er_ui_float_max(flow->bounds.y + flow->bounds.h - flow->cursor_y, 0.0f);
  float h = er_ui_float_min(preferred_h, remaining_h);
  er_ui_bounds_t item = er_ui_bounds(flow->bounds.x, flow->cursor_y, flow->bounds.w, h);
  flow->cursor_y += h + flow->gap;
  return item;
}

er_ui_bounds_t er_ui_vertical_flow_remaining(const er_ui_vertical_flow_t* flow) {
  if (!flow || !er_ui_bounds_valid(flow->bounds)) return er_ui_bounds(0.0f, 0.0f, 0.0f, 0.0f);
  float h = er_ui_float_max(flow->bounds.y + flow->bounds.h - flow->cursor_y, 0.0f);
  return er_ui_bounds(flow->bounds.x, flow->cursor_y, flow->bounds.w, h);
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
