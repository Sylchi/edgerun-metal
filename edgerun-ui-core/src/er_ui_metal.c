#include "er_ui_metal.h"
#include "er_ui_node.h"

static const float ER_UI_METAL_SCREEN_PAD = 120.0f;
static const float ER_UI_METAL_COMPACT_SCREEN_PAD = 48.0f;
static const float ER_UI_METAL_HEADER_H = 116.0f;
static const float ER_UI_METAL_COMPACT_HEADER_H = 76.0f;
static const float ER_UI_METAL_TAB_Y_GAP = 28.0f;
static const float ER_UI_METAL_COMPACT_TAB_Y_GAP = 16.0f;
static const float ER_UI_METAL_TAB_W = 660.0f;
static const float ER_UI_METAL_COMPACT_TAB_W = 560.0f;
static const float ER_UI_METAL_TAB_H = 48.0f;
static const float ER_UI_METAL_COMPACT_TAB_H = 42.0f;
static const float ER_UI_METAL_BLOCK_GAP = 32.0f;
static const float ER_UI_METAL_COMPACT_BLOCK_GAP = 20.0f;
static const float ER_UI_METAL_METRIC_H = 176.0f;
static const float ER_UI_METAL_COMPACT_METRIC_H = 132.0f;
static const float ER_UI_METAL_LOWER_H = 1020.0f;
static const float ER_UI_METAL_LEFT_W = 900.0f;
static const float ER_UI_METAL_COMPACT_LEFT_W = 460.0f;
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
static const float ER_UI_METAL_METRIC_COLUMNS = 3.0f;
static const float ER_UI_METAL_COMPACT_MAX_WIDTH = 2400.0f;
static const uint32_t ER_UI_METAL_TAB_BASE_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4100u;
static const uint32_t ER_UI_METAL_HEADER_ACTION_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4200u;
static const uint32_t ER_UI_METAL_ROUTE_BASE_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4300u;
static const uint32_t ER_UI_METAL_ICON_BASE_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4400u;

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
  const float size = 36.0f;
  const float gap = 8.0f;
  const size_t count = sizeof(icons) / sizeof(icons[0]);

  if (!scene || !font || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < count; ++i) {
    er_ui_node_t button = er_ui_node_icon_button(icons[i], labels[i], ER_UI_METAL_ICON_BASE_ID + (uint32_t)i, ER_UI_SHADCN_BUTTON_GHOST);
    er_ui_status_t status = er_ui_node_render(&button, scene, font, er_ui_bounds(bounds.x + (size + gap) * (float)i, bounds.y, size, size), theme);
    if (status != ER_UI_OK) return status;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_edgerun_metal_surface_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_shadcn_demo_gallery_state_t* state) {
  static const char* const tabs[] = {"Executor", "Buses", "Renderer", "Components"};
  static const char* const route_hops[] = {"firmware", "executor", "ui-core", "gop"};
  static const char* const bus_headers[] = {"Bus", "Addressing", "Status"};
  static const char* const bus_cells[] = {
    "GOP", "framebuffer", "mapped",
    "ACPI", "tables", "scanned",
    "PCI", "config space", "captured"
  };
  static const char* const budget_labels[] = {"memory", "tiles", "commands", "glyphs"};
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
  er_ui_bounds_t header = er_ui_bounds(content.x, content.y, content.w, layout.header_h);
  er_ui_bounds_t tabs_bounds = er_ui_bounds(content.x, header.y + header.h + layout.tab_y_gap, layout.tab_w, layout.tab_h);
  er_ui_bounds_t metric_row = er_ui_bounds(content.x, tabs_bounds.y + tabs_bounds.h + layout.block_gap, content.w, layout.metric_h);
  float lower_y = metric_row.y + metric_row.h + layout.block_gap;
  float lower_h = layout.compact ? content.y + content.h - layout.toast_h - layout.block_gap - lower_y : ER_UI_METAL_LOWER_H;
  if (lower_h <= 0.0f) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t lower = er_ui_bounds(content.x, lower_y, content.w, lower_h);
  er_ui_bounds_t left = er_ui_bounds(lower.x, lower.y, layout.left_w, lower.h);
  float showcase_x = left.x + left.w + layout.block_gap;
  float showcase_w = lower.w - left.w - layout.block_gap;
  er_ui_bounds_t showcase = er_ui_bounds(showcase_x, lower.y, showcase_w, lower.h);
  er_ui_bounds_t footer = er_ui_bounds(content.x, content.y + content.h - layout.toast_h, content.w, layout.toast_h);
  if (!er_ui_bounds_valid(showcase)) return ER_UI_ERR_INVALID_ARGUMENT;

  if (layout.compact) {
    er_ui_bounds_t compact_header = er_ui_bounds(content.x, content.y, content.w, layout.header_h);
    er_ui_bounds_t icon_bar = er_ui_bounds(content.x + content.w - 258.0f, content.y + 6.0f, 258.0f, 36.0f);
    er_ui_bounds_t compact_showcase = er_ui_bounds(content.x, content.y + layout.header_h + layout.block_gap, content.w,
                                                   content.h - layout.header_h - layout.block_gap - layout.toast_h - layout.block_gap);
    er_ui_bounds_t compact_footer = er_ui_bounds(content.x, content.y + content.h - layout.toast_h, content.w, layout.toast_h);
    if (!er_ui_bounds_valid(compact_showcase)) return ER_UI_ERR_INVALID_ARGUMENT;

    status = er_ui_shadcn_panel_header_emit(scene, font, compact_header, theme, "EdgeRun UI Core", "shadcn catalog rendered by GOP", "COMPACT", ER_UI_METAL_HEADER_ACTION_ID);
    if (status != ER_UI_OK) return status;
    status = er_ui_metal_emit_icon_bar(scene, font, icon_bar, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_shadcn_showcase_emit(scene, font, compact_showcase, theme, "dialog", state);
    if (status != ER_UI_OK) return status;
    return er_ui_shadcn_toast_emit(scene, font, compact_footer, theme, "UI-core shadcn components, node icons, hits, text, and GOP rendering are active.",
                                   theme.colors.accent);
  }

  status = er_ui_shadcn_panel_header_emit(scene, font, header, theme, "EdgeRun Metal", "GOP rendering UI-core components", "READY", ER_UI_METAL_HEADER_ACTION_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_tabs_emit(scene, font, tabs_bounds, theme, tabs, sizeof(tabs) / sizeof(tabs[0]), 3u, ER_UI_METAL_TAB_BASE_ID);
  if (status != ER_UI_OK) return status;

  float metric_w = (metric_row.w - layout.block_gap * 2.0f) / ER_UI_METAL_METRIC_COLUMNS;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x, metric_row.y, metric_w, metric_row.h), theme, "Renderer", "GOP",
                                         "CPU tile renderer active", true, 0.82f, theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x + metric_w + layout.block_gap, metric_row.y, metric_w, metric_row.h), theme,
                                         "Executor", "WASM", "drivers run as bounded apps", true, 0.58f, theme.colors.info);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x + (metric_w + layout.block_gap) * 2.0f, metric_row.y, metric_w, metric_row.h), theme,
                                         "Hardware", "Buses", "addressed byte routes", true, 0.64f, theme.colors.success);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_route_path_emit(scene, font, er_ui_bounds(left.x, left.y, left.w, layout.route_h), theme, "Boot UI scene", route_hops,
                                        sizeof(route_hops) / sizeof(route_hops[0]));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_table_emit(scene, font, er_ui_bounds(left.x, left.y + layout.table_y, left.w, layout.table_h), theme, bus_headers,
                                   sizeof(bus_headers) / sizeof(bus_headers[0]), bus_cells, 3u, ER_UI_METAL_ROUTE_BASE_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_bar_chart_emit(scene, font, er_ui_bounds(left.x, left.y + layout.chart_y, left.w, layout.chart_h), theme, "Frame budget",
                                       budget_labels, budget_values, sizeof(budget_values) / sizeof(budget_values[0]), ER_UI_METAL_ROUTE_BASE_ID + 100u, 1u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_command_palette_emit(scene, font, er_ui_bounds(left.x, left.y + layout.command_y, left.w, layout.command_h), theme,
                                             "Search component, bus, packet route...", ER_UI_METAL_ROUTE_BASE_ID + 200u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_capability_grant_row_emit(scene, font, er_ui_bounds(left.x, left.y + layout.grant_y, left.w, layout.row_h), theme, "ui-core",
                                                  "scene.emit", "owned", ER_UI_METAL_ROUTE_BASE_ID + 300u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_proof_event_row_emit(scene, font, er_ui_bounds(left.x, left.y + layout.proof_y, left.w, layout.row_h), theme, "metal boot scene",
                                             "component catalog mounted", "verified", ER_UI_METAL_ROUTE_BASE_ID + 301u);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_showcase_emit(scene, font, showcase, theme, "button", state);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_toast_emit(scene, font, footer, theme, "Metal only renders commands; UI composition lives in edgerun-ui-core.", theme.colors.accent);
}
