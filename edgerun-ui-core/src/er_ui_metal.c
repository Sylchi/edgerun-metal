#include "er_ui_metal.h"
#include "er_ui_node.h"
#include "er_ui_painter.h"
#include "er_ui_spacing.h"

static const float ER_UI_METAL_SCREEN_PAD = 120.0f;
static const float ER_UI_METAL_COMPACT_SCREEN_PAD = 28.0f;
static const float ER_UI_METAL_HEADER_H = 116.0f;
static const float ER_UI_METAL_COMPACT_HEADER_H = 76.0f;
static const float ER_UI_METAL_TAB_Y_GAP = 28.0f;
static const float ER_UI_METAL_COMPACT_TAB_Y_GAP = 16.0f;
static const float ER_UI_METAL_TAB_W = 660.0f;
static const float ER_UI_METAL_COMPACT_TAB_W = 560.0f;
static const float ER_UI_METAL_TAB_H = 48.0f;
static const float ER_UI_METAL_COMPACT_TAB_H = 42.0f;
static const float ER_UI_METAL_BLOCK_GAP = 32.0f;
static const float ER_UI_METAL_COMPACT_BLOCK_GAP = 14.0f;
static const float ER_UI_METAL_METRIC_H = 176.0f;
static const float ER_UI_METAL_COMPACT_METRIC_H = 132.0f;
static const float ER_UI_METAL_LOWER_H = 1020.0f;
static const float ER_UI_METAL_LEFT_W = 900.0f;
static const float ER_UI_METAL_COMPACT_LEFT_W = 460.0f;
static const float ER_UI_METAL_COMPACT_RAIL_MIN_W = 160.0f;
static const float ER_UI_METAL_COMPACT_RAIL_W = 176.0f;
static const float ER_UI_METAL_COMPACT_MAIN_MIN_W = 220.0f;
static const float ER_UI_METAL_COMPACT_RAIL_STACKED_H = 560.0f;
static const float ER_UI_METAL_COMPACT_TOPBAR_H = 52.0f;
static const float ER_UI_METAL_TOPBAR_LEFT_W = 154.0f;
static const float ER_UI_METAL_TOPBAR_GAP = 12.0f;
static const float ER_UI_METAL_TOPBAR_PAD_Y = 7.0f;
static const float ER_UI_METAL_TOPBAR_COMMAND_MIN_W = 220.0f;
static const float ER_UI_METAL_TOPBAR_COMMAND_H = 38.0f;
static const float ER_UI_METAL_TOPBAR_ICON_BAR_W = 256.0f;
static const float ER_UI_METAL_TOPBAR_ICON_BAR_H = 36.0f;
static const float ER_UI_METAL_TOPBAR_STACKED_H = 100.0f;
static const float ER_UI_METAL_ICON_BUTTON_SIZE = 36.0f;
static const float ER_UI_METAL_ICON_BUTTON_MIN_SIZE = 28.0f;
static const float ER_UI_METAL_ICON_BUTTON_GAP = 8.0f;
static const float ER_UI_METAL_TOAST_H = 86.0f;
static const float ER_UI_METAL_COMPACT_TOAST_H = 54.0f;
static const float ER_UI_METAL_ROUTE_H = 156.0f;
static const float ER_UI_METAL_COMPACT_ROUTE_H = 112.0f;
static const float ER_UI_METAL_TABLE_Y = 180.0f;
static const float ER_UI_METAL_COMPACT_TABLE_Y = 132.0f;
static const float ER_UI_METAL_TABLE_H = 184.0f;
static const float ER_UI_METAL_COMPACT_TABLE_H = 132.0f;
static const float ER_UI_METAL_CHART_Y = 396.0f;
static const float ER_UI_METAL_COMPACT_CHART_Y = 284.0f;
static const float ER_UI_METAL_CHART_H = 220.0f;
static const float ER_UI_METAL_COMPACT_CHART_H = 160.0f;
static const float ER_UI_METAL_COMMAND_Y = 648.0f;
static const float ER_UI_METAL_COMPACT_COMMAND_Y = 464.0f;
static const float ER_UI_METAL_COMMAND_H = 64.0f;
static const float ER_UI_METAL_COMPACT_COMMAND_H = 54.0f;
static const float ER_UI_METAL_GRANT_Y = 744.0f;
static const float ER_UI_METAL_COMPACT_GRANT_Y = 538.0f;
static const float ER_UI_METAL_PROOF_Y = 840.0f;
static const float ER_UI_METAL_COMPACT_PROOF_Y = 608.0f;
static const float ER_UI_METAL_ROW_H = 76.0f;
static const float ER_UI_METAL_COMPACT_ROW_H = 54.0f;
static const float ER_UI_METAL_METRIC_MIN_W = 660.0f;
static const size_t ER_UI_METAL_METRIC_COLUMN_COUNT = 3u;
static const float ER_UI_METAL_COMPACT_MAX_WIDTH = 2400.0f;
static const uint32_t ER_UI_METAL_TAB_BASE_ID = ER_UI_COMPONENT_PREVIEW_BASE_ID + 4100u;
static const uint32_t ER_UI_METAL_HEADER_ACTION_ID = ER_UI_COMPONENT_PREVIEW_BASE_ID + 4200u;
static const uint32_t ER_UI_METAL_ROUTE_BASE_ID = ER_UI_COMPONENT_PREVIEW_BASE_ID + 4300u;
static const uint32_t ER_UI_METAL_ICON_BASE_ID = ER_UI_COMPONENT_PREVIEW_BASE_ID + 4400u;
static const uint32_t ER_UI_METAL_BOARD_BASE_ID = ER_UI_COMPONENT_PREVIEW_BASE_ID + 4600u;
#define ER_UI_METAL_TEXT_BUDGET 96u
#define ER_UI_METAL_AMOUNT_TEXT_BUDGET 32u
#define ER_UI_METAL_MENU_TEXT_BUDGET 64u
#define ER_UI_METAL_SHUFFLE_BUTTON_ID (ER_UI_METAL_BOARD_BASE_ID + 50u)
#define ER_UI_METAL_GET_CODE_BUTTON_ID (ER_UI_METAL_BOARD_BASE_ID + 51u)
#define ER_UI_METAL_COMPONENTS_BUTTON_ID (ER_UI_METAL_BOARD_BASE_ID + 60u)
#define ER_UI_METAL_SEARCH_COMMAND_ID (ER_UI_METAL_BOARD_BASE_ID + 61u)
#define ER_UI_METAL_SELECTED_TAB_INDEX 3u
#define ER_UI_METAL_DISPLAY_METRIC_INDEX 0u
#define ER_UI_METAL_EXECUTOR_METRIC_INDEX 1u
#define ER_UI_METAL_HARDWARE_METRIC_INDEX 2u
#define ER_UI_METAL_BUS_TABLE_ROWS 3u
#define ER_UI_METAL_FRAME_BUDGET_ID (ER_UI_METAL_ROUTE_BASE_ID + 100u)
#define ER_UI_METAL_ROUTE_SEARCH_ID (ER_UI_METAL_ROUTE_BASE_ID + 200u)
#define ER_UI_METAL_CAPABILITY_GRANT_ID (ER_UI_METAL_ROUTE_BASE_ID + 300u)
#define ER_UI_METAL_PROOF_EVENT_ID (ER_UI_METAL_ROUTE_BASE_ID + 301u)

typedef struct er_ui_metal_layout_s {
  float screen_pad;
  float header_h;
  float tab_y_gap;
  float tab_w;
  float tab_h;
  float block_gap;
  float metric_h;
  float left_w;
  float toast_h;
  float route_h;
  float table_y;
  float table_h;
  float chart_y;
  float chart_h;
  float command_y;
  float command_h;
  float grant_y;
  float proof_y;
  float row_h;
  bool compact;
} er_ui_metal_layout_t;

static er_ui_metal_layout_t er_ui_metal_layout_for_bounds(er_ui_bounds_t bounds) {
  bool compact = bounds.w <= ER_UI_METAL_COMPACT_MAX_WIDTH;
  return (er_ui_metal_layout_t){
    compact ? ER_UI_METAL_COMPACT_SCREEN_PAD : ER_UI_METAL_SCREEN_PAD,
    compact ? ER_UI_METAL_COMPACT_HEADER_H : ER_UI_METAL_HEADER_H,
    compact ? ER_UI_METAL_COMPACT_TAB_Y_GAP : ER_UI_METAL_TAB_Y_GAP,
    compact ? ER_UI_METAL_COMPACT_TAB_W : ER_UI_METAL_TAB_W,
    compact ? ER_UI_METAL_COMPACT_TAB_H : ER_UI_METAL_TAB_H,
    compact ? ER_UI_METAL_COMPACT_BLOCK_GAP : ER_UI_METAL_BLOCK_GAP,
    compact ? ER_UI_METAL_COMPACT_METRIC_H : ER_UI_METAL_METRIC_H,
    compact ? ER_UI_METAL_COMPACT_LEFT_W : ER_UI_METAL_LEFT_W,
    compact ? ER_UI_METAL_COMPACT_TOAST_H : ER_UI_METAL_TOAST_H,
    compact ? ER_UI_METAL_COMPACT_ROUTE_H : ER_UI_METAL_ROUTE_H,
    compact ? ER_UI_METAL_COMPACT_TABLE_Y : ER_UI_METAL_TABLE_Y,
    compact ? ER_UI_METAL_COMPACT_TABLE_H : ER_UI_METAL_TABLE_H,
    compact ? ER_UI_METAL_COMPACT_CHART_Y : ER_UI_METAL_CHART_Y,
    compact ? ER_UI_METAL_COMPACT_CHART_H : ER_UI_METAL_CHART_H,
    compact ? ER_UI_METAL_COMPACT_COMMAND_Y : ER_UI_METAL_COMMAND_Y,
    compact ? ER_UI_METAL_COMPACT_COMMAND_H : ER_UI_METAL_COMMAND_H,
    compact ? ER_UI_METAL_COMPACT_GRANT_Y : ER_UI_METAL_GRANT_Y,
    compact ? ER_UI_METAL_COMPACT_PROOF_Y : ER_UI_METAL_PROOF_Y,
    compact ? ER_UI_METAL_COMPACT_ROW_H : ER_UI_METAL_ROW_H,
    compact
  };
}

//@optimizer-ignore-function fixed metal toolbar must render each icon button in order
static er_ui_status_t er_ui_metal_emit_icon_bar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  static const er_ui_icon_t icons[] = {
    ER_UI_ICON_APP,
    ER_UI_ICON_SEARCH,
    ER_UI_ICON_CPU,
    ER_UI_ICON_NETWORK,
    ER_UI_ICON_SHIELD,
    ER_UI_ICON_SETTINGS
  };
  static const char* const labels[] = {"Apps", "Search", "CPU", "Network", "Trust", "Settings"};
  float size = ER_UI_METAL_ICON_BUTTON_SIZE;
  float gap = ER_UI_METAL_ICON_BUTTON_GAP;
  const size_t count = sizeof(icons) / sizeof(icons[0]);

  if (!scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  float preferred_w = size * (float)count + gap * (float)(count - 1u);
  if (preferred_w > bounds.w) {
    float fitted_size = bounds.w / (float)count;
    if (fitted_size < ER_UI_METAL_ICON_BUTTON_MIN_SIZE) return ER_UI_ERR_INVALID_ARGUMENT;
    size = er_ui_float_min(size, fitted_size);
    gap = count > 1u ? (bounds.w - size * (float)count) / (float)(count - 1u) : 0.0f;
  }
  for (size_t i = 0u; i < count; ++i) {
    er_ui_node_t button = er_ui_node_icon_button(icons[i], labels[i], ER_UI_METAL_ICON_BASE_ID + (uint32_t)i, ER_UI_COMPONENT_BUTTON_GHOST);
    er_ui_status_t status = er_ui_node_render(&button, scene, font, er_ui_bounds(bounds.x + (size + gap) * (float)i, bounds.y, size, size), theme);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

static float er_ui_metal_showcase_topbar_height(float width) {
  float tools_w = width - ER_UI_METAL_TOPBAR_LEFT_W - ER_UI_METAL_TOPBAR_GAP;
  float inline_tools_w = ER_UI_METAL_TOPBAR_COMMAND_MIN_W + ER_UI_METAL_TOPBAR_GAP + ER_UI_METAL_TOPBAR_ICON_BAR_W;
  if (tools_w >= inline_tools_w) return ER_UI_METAL_COMPACT_TOPBAR_H;
  return ER_UI_METAL_TOPBAR_STACKED_H;
}

static er_ui_status_t er_ui_metal_emit_rail_item(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const char* label,
  const char* value,
  er_ui_icon_t icon,
  uint32_t id) {
  er_ui_status_t status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_BUTTON, id, bounds.x, bounds.y, bounds.w, bounds.h));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.control, er_ui_color_with_alpha(theme.colors.row, 0.34f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_ascii_text(scene, font, label, ER_UI_METAL_TEXT_BUDGET, bounds.x + 10.0f, bounds.y + 19.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_ascii_text(scene, font, value, ER_UI_METAL_TEXT_BUDGET, bounds.x + 10.0f, bounds.y + 38.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  er_ui_painter_t painter = er_ui_painter(scene);
  return er_ui_painter_icon(&painter, er_ui_bounds(bounds.x + bounds.w - 30.0f, bounds.y + 13.0f, 18.0f, 18.0f), icon, theme.colors.muted);
}

//@optimizer-ignore-function the 720p showcase rail intentionally lists style controls in visual order
static er_ui_status_t er_ui_metal_emit_style_rail(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  static const char* const labels[] = {"Style", "Base Color", "Theme", "Chart Color", "Heading", "Font", "Icons", "Radius", "Menu"};
  static const char* const values[] = {"Nova", "Neutral", "Dark", "Neutral", "Geist VF", "Geist VF", "Tabler", "Default", "Solid"};
  static const er_ui_icon_t icons[] = {
    ER_UI_ICON_APP,
    ER_UI_ICON_SPARKLES,
    ER_UI_ICON_EYE,
    ER_UI_ICON_ACTIVITY,
    ER_UI_ICON_CODE,
    ER_UI_ICON_CODE,
    ER_UI_ICON_SPARKLES,
    ER_UI_ICON_ROUTE,
    ER_UI_ICON_MENU
  };
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_linear_gradient(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.panel,
                                                                                 er_ui_color_with_alpha(theme.colors.sidebar, 0.98f),
                                                                                 er_ui_color_with_alpha(theme.colors.panel, 0.86f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.panel, er_ui_color_with_alpha(theme.colors.border, 0.54f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_ascii_text(scene, font, "Menu", ER_UI_METAL_MENU_TEXT_BUDGET, bounds.x + 12.0f, bounds.y + 28.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  for (size_t i = 0u; i < sizeof(labels) / sizeof(labels[0]); ++i) {
    er_ui_bounds_t row = er_ui_bounds(bounds.x + 8.0f, bounds.y + 44.0f + (float)i * 48.0f, bounds.w - 16.0f, 42.0f);
    status = er_ui_metal_emit_rail_item(scene, font, row, theme, labels[i], values[i], icons[i], ER_UI_METAL_BOARD_BASE_ID + (uint32_t)i);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 8.0f, bounds.y + bounds.h - 84.0f, bounds.w - 16.0f, 32.0f), theme,
                                    "Shuffle", ER_UI_METAL_SHUFFLE_BUTTON_ID, ER_UI_COMPONENT_BUTTON_SECONDARY, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;
  return er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 8.0f, bounds.y + bounds.h - 44.0f, bounds.w - 16.0f, 32.0f), theme,
                                  "Get Code", ER_UI_METAL_GET_CODE_BUTTON_ID, ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
}

static er_ui_status_t er_ui_metal_emit_showcase_topbar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  er_ui_painter_t painter = er_ui_painter(scene);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.panel, er_ui_color_with_alpha(theme.colors.panel, 0.52f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_icon(&painter, er_ui_bounds(bounds.x + 12.0f, bounds.y + 15.0f, 20.0f, 20.0f), ER_UI_ICON_SPARKLES, theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_button_emit(scene, font, er_ui_bounds(bounds.x + 42.0f, bounds.y + 9.0f, 112.0f, 34.0f), theme, "Components",
                                    ER_UI_METAL_COMPONENTS_BUTTON_ID, ER_UI_COMPONENT_BUTTON_GHOST, ER_UI_COMPONENT_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t tools = er_ui_bounds(
    bounds.x + ER_UI_METAL_TOPBAR_LEFT_W + ER_UI_METAL_TOPBAR_GAP,
    bounds.y + ER_UI_METAL_TOPBAR_PAD_Y,
    bounds.w - ER_UI_METAL_TOPBAR_LEFT_W - ER_UI_METAL_TOPBAR_GAP,
    bounds.h - ER_UI_METAL_TOPBAR_PAD_Y * 2.0f);
  if (!er_ui_bounds_valid(tools)) return ER_UI_ERR_INVALID_ARGUMENT;
  float command_preferred_w = tools.w - ER_UI_METAL_TOPBAR_GAP - ER_UI_METAL_TOPBAR_ICON_BAR_W;
  if (command_preferred_w < ER_UI_METAL_TOPBAR_COMMAND_MIN_W) command_preferred_w = ER_UI_METAL_TOPBAR_COMMAND_MIN_W;
  er_ui_responsive_sidecar_t tool_layout = er_ui_responsive_sidecar(
    tools,
    ER_UI_METAL_TOPBAR_COMMAND_MIN_W,
    command_preferred_w,
    ER_UI_METAL_TOPBAR_ICON_BAR_W,
    ER_UI_METAL_TOPBAR_GAP,
    ER_UI_METAL_TOPBAR_COMMAND_H);
  if (!er_ui_bounds_valid(tool_layout.side) || !er_ui_bounds_valid(tool_layout.main)) return ER_UI_ERR_INVALID_ARGUMENT;
  status = er_ui_component_command_palette_emit(scene, font, er_ui_bounds(tool_layout.side.x, tool_layout.side.y, tool_layout.side.w, ER_UI_METAL_TOPBAR_COMMAND_H), theme,
                                             "Search components...", ER_UI_METAL_SEARCH_COMMAND_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_metal_emit_icon_bar(scene, font, er_ui_bounds(tool_layout.main.x, tool_layout.main.y, tool_layout.main.w, ER_UI_METAL_TOPBAR_ICON_BAR_H), theme);
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y + bounds.h - 1.0f, bounds.w, 1.0f, 0.0f, er_ui_color_with_alpha(theme.colors.border, 0.56f)));
}

er_ui_status_t er_ui_edgerun_metal_surface_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_component_gallery_state_t* state) {
  static const char *const tabs[] = {"Executor", "Buses", "Renderer", "Components"};
  static const char *const route_hops[] = {"device", "executor", "ui-core", "scanout"};
  static const char *const bus_headers[] = {"Bus", "Addressing", "Status"};
  static const char *const bus_cells[] = {
    "Display", "scanout surface", "admitted",
    "ACPI", "tables", "scanned",
    "PCI", "config space", "captured"
  };
  static const char *const budget_labels[] = {"memory", "tiles", "commands", "glyphs"};
  static const float budget_values[] = {0.42f, 0.58f, 0.36f, 0.64f};

  if (!scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_metal_layout_t layout = er_ui_metal_layout_for_bounds(bounds);
  if (bounds.w <= layout.screen_pad * 2.0f || bounds.h <= layout.screen_pad * 2.0f) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t content = er_ui_bounds(
    bounds.x + layout.screen_pad,
    bounds.y + layout.screen_pad,
    bounds.w - layout.screen_pad * 2.0f,
    bounds.h - layout.screen_pad * 2.0f);

  if (layout.compact) {
    er_ui_responsive_sidecar_t compact = er_ui_responsive_sidecar(
      content,
      ER_UI_METAL_COMPACT_RAIL_MIN_W,
      ER_UI_METAL_COMPACT_RAIL_W,
      ER_UI_METAL_COMPACT_MAIN_MIN_W,
      layout.block_gap,
      ER_UI_METAL_COMPACT_RAIL_STACKED_H);
    if (!er_ui_bounds_valid(compact.side) || !er_ui_bounds_valid(compact.main)) return ER_UI_ERR_INVALID_ARGUMENT;
    er_ui_vertical_flow_t main_flow = er_ui_vertical_flow(compact.main, layout.block_gap);
    er_ui_bounds_t topbar = er_ui_vertical_flow_next(&main_flow, er_ui_metal_showcase_topbar_height(compact.main.w));
    er_ui_bounds_t board = er_ui_vertical_flow_remaining(&main_flow);
    if (!er_ui_bounds_valid(board)) return ER_UI_ERR_INVALID_ARGUMENT;

    status = er_ui_metal_emit_style_rail(scene, font, compact.side, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_metal_emit_showcase_topbar(scene, font, topbar, theme);
    if (status != ER_UI_OK) return status;
    return er_ui_component_showcase_emit(scene, font, board, theme, "button", state);
  }

  er_ui_bounds_t header = er_ui_bounds(content.x, content.y, content.w, layout.header_h);
  er_ui_bounds_t tabs_bounds = er_ui_bounds(content.x, header.y + header.h + layout.tab_y_gap, layout.tab_w, layout.tab_h);
  er_ui_bounds_t metric_seed = er_ui_bounds(content.x, tabs_bounds.y + tabs_bounds.h + layout.block_gap, content.w, layout.metric_h);
  er_ui_responsive_grid_t metric_grid =
    er_ui_responsive_grid(metric_seed, ER_UI_METAL_METRIC_MIN_W, ER_UI_METAL_METRIC_COLUMN_COUNT, layout.block_gap, layout.block_gap);
  if (metric_grid.columns == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  float metric_row_h = er_ui_responsive_grid_height(metric_grid, ER_UI_METAL_METRIC_COLUMN_COUNT, layout.metric_h);
  if (metric_row_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t metric_row = er_ui_bounds(metric_seed.x, metric_seed.y, metric_seed.w, metric_row_h);
  metric_grid = er_ui_responsive_grid(metric_row, ER_UI_METAL_METRIC_MIN_W, ER_UI_METAL_METRIC_COLUMN_COUNT, layout.block_gap, layout.block_gap);
  float lower_y = metric_row.y + metric_row.h + layout.block_gap;
  float lower_h = ER_UI_METAL_LOWER_H;
  if (lower_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t lower = er_ui_bounds(content.x, lower_y, content.w, lower_h);
  er_ui_bounds_t left = er_ui_bounds(lower.x, lower.y, layout.left_w, lower.h);
  float showcase_x = left.x + left.w + layout.block_gap;
  float showcase_w = lower.w - left.w - layout.block_gap;
  er_ui_bounds_t showcase = er_ui_bounds(showcase_x, lower.y, showcase_w, lower.h);
  er_ui_bounds_t footer = er_ui_bounds(content.x, content.y + content.h - layout.toast_h, content.w, layout.toast_h);
  if (!er_ui_bounds_valid(showcase)) return ER_UI_ERR_INVALID_ARGUMENT;

  status = er_ui_component_panel_header_emit(scene, font, header, theme, "EdgeRun Metal", "UI scene commands admitted to display relay", "READY", ER_UI_METAL_HEADER_ACTION_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_tabs_emit(scene, font, tabs_bounds, theme, tabs, sizeof(tabs) / sizeof(tabs[0]), ER_UI_METAL_SELECTED_TAB_INDEX, ER_UI_METAL_TAB_BASE_ID);
  if (status != ER_UI_OK) return status;

  status = er_ui_component_metric_card_emit(scene,
                                            font,
                                            er_ui_responsive_grid_cell(metric_grid, ER_UI_METAL_DISPLAY_METRIC_INDEX, layout.metric_h),
                                            theme,
                                            "Display",
                                            "Relay",
                                            "scanout surface active",
                                            true,
                                            0.82f,
                                            theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_metric_card_emit(scene,
                                            font,
                                            er_ui_responsive_grid_cell(metric_grid, ER_UI_METAL_EXECUTOR_METRIC_INDEX, layout.metric_h),
                                            theme,
                                            "Executor",
                                            "WASM",
                                            "drivers run as bounded apps",
                                            true,
                                            0.58f,
                                            theme.colors.info);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_metric_card_emit(scene,
                                            font,
                                            er_ui_responsive_grid_cell(metric_grid, ER_UI_METAL_HARDWARE_METRIC_INDEX, layout.metric_h),
                                            theme,
                                            "Hardware",
                                            "Buses",
                                            "addressed byte routes",
                                            true,
                                            0.64f,
                                            theme.colors.success);
  if (status != ER_UI_OK) return status;

  status = er_ui_component_route_path_emit(scene, font, er_ui_bounds(left.x, left.y, left.w, layout.route_h), theme, "Boot UI scene", route_hops,
                                        sizeof(route_hops) / sizeof(route_hops[0]));
  if (status != ER_UI_OK) return status;
  status = er_ui_component_table_emit(scene, font, er_ui_bounds(left.x, left.y + layout.table_y, left.w, layout.table_h), theme, bus_headers,
                                   sizeof(bus_headers) / sizeof(bus_headers[0]), bus_cells, ER_UI_METAL_BUS_TABLE_ROWS, ER_UI_METAL_ROUTE_BASE_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_bar_chart_emit(scene, font, er_ui_bounds(left.x, left.y + layout.chart_y, left.w, layout.chart_h), theme, "Frame budget",
	                                       budget_labels, budget_values, sizeof(budget_values) / sizeof(budget_values[0]), ER_UI_METAL_FRAME_BUDGET_ID, 1u);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_command_palette_emit(scene, font, er_ui_bounds(left.x, left.y + layout.command_y, left.w, layout.command_h), theme,
	                                             "Search component, bus, packet route...", ER_UI_METAL_ROUTE_SEARCH_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_capability_grant_row_emit(scene, font, er_ui_bounds(left.x, left.y + layout.grant_y, left.w, layout.row_h), theme, "ui-core",
	                                                  "scene.emit", "owned", ER_UI_METAL_CAPABILITY_GRANT_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_component_proof_event_row_emit(scene, font, er_ui_bounds(left.x, left.y + layout.proof_y, left.w, layout.row_h), theme, "metal boot scene",
	                                             "component catalog mounted", "verified", ER_UI_METAL_PROOF_EVENT_ID);
  if (status != ER_UI_OK) return status;

  status = er_ui_component_showcase_emit(scene, font, showcase, theme, "button", state);
  if (status != ER_UI_OK) return status;
  return er_ui_component_toast_emit(scene, font, footer, theme, "Metal only renders commands; UI composition lives in edgerun-ui-core.", theme.colors.accent);
}
