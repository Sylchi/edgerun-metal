#include "er_ui_node_internal.h"

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
