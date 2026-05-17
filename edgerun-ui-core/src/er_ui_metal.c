#include "er_ui_metal.h"

static const float ER_UI_METAL_SCREEN_PAD = 120.0f;
static const float ER_UI_METAL_HEADER_H = 116.0f;
static const float ER_UI_METAL_TAB_Y_GAP = 28.0f;
static const float ER_UI_METAL_TAB_W = 660.0f;
static const float ER_UI_METAL_TAB_H = 48.0f;
static const float ER_UI_METAL_BLOCK_GAP = 32.0f;
static const float ER_UI_METAL_METRIC_H = 176.0f;
static const float ER_UI_METAL_LOWER_H = 1020.0f;
static const float ER_UI_METAL_LEFT_W = 900.0f;
static const float ER_UI_METAL_TOAST_H = 86.0f;
static const float ER_UI_METAL_ROUTE_H = 156.0f;
static const float ER_UI_METAL_TABLE_Y = 180.0f;
static const float ER_UI_METAL_TABLE_H = 184.0f;
static const float ER_UI_METAL_CHART_Y = 396.0f;
static const float ER_UI_METAL_CHART_H = 220.0f;
static const float ER_UI_METAL_COMMAND_Y = 648.0f;
static const float ER_UI_METAL_COMMAND_H = 64.0f;
static const float ER_UI_METAL_GRANT_Y = 744.0f;
static const float ER_UI_METAL_PROOF_Y = 840.0f;
static const float ER_UI_METAL_ROW_H = 76.0f;
static const float ER_UI_METAL_METRIC_COLUMNS = 3.0f;
static const uint32_t ER_UI_METAL_TAB_BASE_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4100u;
static const uint32_t ER_UI_METAL_HEADER_ACTION_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4200u;
static const uint32_t ER_UI_METAL_ROUTE_BASE_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4300u;

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
  if (bounds.w <= ER_UI_METAL_SCREEN_PAD * 2.0f || bounds.h <= ER_UI_METAL_SCREEN_PAD * 2.0f) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;

  er_ui_bounds_t content = er_ui_bounds(
    bounds.x + ER_UI_METAL_SCREEN_PAD,
    bounds.y + ER_UI_METAL_SCREEN_PAD,
    bounds.w - ER_UI_METAL_SCREEN_PAD * 2.0f,
    bounds.h - ER_UI_METAL_SCREEN_PAD * 2.0f);
  er_ui_bounds_t header = er_ui_bounds(content.x, content.y, content.w, ER_UI_METAL_HEADER_H);
  er_ui_bounds_t tabs_bounds = er_ui_bounds(content.x, header.y + header.h + ER_UI_METAL_TAB_Y_GAP, ER_UI_METAL_TAB_W, ER_UI_METAL_TAB_H);
  er_ui_bounds_t metric_row = er_ui_bounds(content.x, tabs_bounds.y + tabs_bounds.h + ER_UI_METAL_BLOCK_GAP, content.w, ER_UI_METAL_METRIC_H);
  er_ui_bounds_t lower = er_ui_bounds(content.x, metric_row.y + metric_row.h + ER_UI_METAL_BLOCK_GAP, content.w, ER_UI_METAL_LOWER_H);
  er_ui_bounds_t left = er_ui_bounds(lower.x, lower.y, ER_UI_METAL_LEFT_W, lower.h);
  float showcase_x = left.x + left.w + ER_UI_METAL_BLOCK_GAP;
  float showcase_w = lower.w - left.w - ER_UI_METAL_BLOCK_GAP;
  er_ui_bounds_t showcase = er_ui_bounds(showcase_x, lower.y, showcase_w, lower.h);
  er_ui_bounds_t footer = er_ui_bounds(content.x, content.y + content.h - ER_UI_METAL_TOAST_H, content.w, ER_UI_METAL_TOAST_H);

  status = er_ui_shadcn_panel_header_emit(scene, font, header, theme, "EdgeRun Metal", "GOP rendering UI-core components", "READY", ER_UI_METAL_HEADER_ACTION_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_tabs_emit(scene, font, tabs_bounds, theme, tabs, sizeof(tabs) / sizeof(tabs[0]), 3u, ER_UI_METAL_TAB_BASE_ID);
  if (status != ER_UI_OK) return status;

  float metric_w = (metric_row.w - ER_UI_METAL_BLOCK_GAP * 2.0f) / ER_UI_METAL_METRIC_COLUMNS;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x, metric_row.y, metric_w, metric_row.h), theme, "Renderer", "GOP",
                                         "CPU tile renderer active", true, 0.82f, theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x + metric_w + ER_UI_METAL_BLOCK_GAP, metric_row.y, metric_w, metric_row.h), theme,
                                         "Executor", "WASM", "drivers run as bounded apps", true, 0.58f, theme.colors.info);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x + (metric_w + ER_UI_METAL_BLOCK_GAP) * 2.0f, metric_row.y, metric_w, metric_row.h), theme,
                                         "Hardware", "Buses", "addressed byte routes", true, 0.64f, theme.colors.success);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_route_path_emit(scene, font, er_ui_bounds(left.x, left.y, left.w, ER_UI_METAL_ROUTE_H), theme, "Boot UI scene", route_hops,
                                        sizeof(route_hops) / sizeof(route_hops[0]));
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_table_emit(scene, font, er_ui_bounds(left.x, left.y + ER_UI_METAL_TABLE_Y, left.w, ER_UI_METAL_TABLE_H), theme, bus_headers,
                                   sizeof(bus_headers) / sizeof(bus_headers[0]), bus_cells, 3u, ER_UI_METAL_ROUTE_BASE_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_bar_chart_emit(scene, font, er_ui_bounds(left.x, left.y + ER_UI_METAL_CHART_Y, left.w, ER_UI_METAL_CHART_H), theme, "Frame budget",
                                       budget_labels, budget_values, sizeof(budget_values) / sizeof(budget_values[0]), ER_UI_METAL_ROUTE_BASE_ID + 100u, 1u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_command_palette_emit(scene, font, er_ui_bounds(left.x, left.y + ER_UI_METAL_COMMAND_Y, left.w, ER_UI_METAL_COMMAND_H), theme,
                                             "Search component, bus, packet route...", ER_UI_METAL_ROUTE_BASE_ID + 200u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_capability_grant_row_emit(scene, font, er_ui_bounds(left.x, left.y + ER_UI_METAL_GRANT_Y, left.w, ER_UI_METAL_ROW_H), theme, "ui-core",
                                                  "scene.emit", "owned", ER_UI_METAL_ROUTE_BASE_ID + 300u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_proof_event_row_emit(scene, font, er_ui_bounds(left.x, left.y + ER_UI_METAL_PROOF_Y, left.w, ER_UI_METAL_ROW_H), theme, "metal boot scene",
                                             "component catalog mounted", "verified", ER_UI_METAL_ROUTE_BASE_ID + 301u);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_showcase_emit(scene, font, showcase, theme, "button", state);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_toast_emit(scene, font, footer, theme, "Metal only renders commands; UI composition lives in edgerun-ui-core.", theme.colors.accent);
}
