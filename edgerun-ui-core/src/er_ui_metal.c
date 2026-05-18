#include "er_ui_metal.h"
#include "er_ui_node.h"
#include "er_ui_painter.h"

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
static const uint32_t ER_UI_METAL_BOARD_BASE_ID = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 4600u;

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
  status = er_ui_scene_push_ascii_text(scene, font, label, 96u, bounds.x + 10.0f, bounds.y + 19.0f, theme.colors.muted);
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_ascii_text(scene, font, value, 96u, bounds.x + 10.0f, bounds.y + 38.0f, theme.colors.text);
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
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.panel, theme.colors.sidebar));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_rect(scene, er_ui_rect_border(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.panel, er_ui_color_with_alpha(theme.colors.border, 0.54f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_scene_push_ascii_text(scene, font, "Menu", 64u, bounds.x + 12.0f, bounds.y + 28.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;
  for (size_t i = 0u; i < sizeof(labels) / sizeof(labels[0]); ++i) {
    er_ui_bounds_t row = er_ui_bounds(bounds.x + 8.0f, bounds.y + 44.0f + (float)i * 48.0f, bounds.w - 16.0f, 42.0f);
    status = er_ui_metal_emit_rail_item(scene, font, row, theme, labels[i], values[i], icons[i], ER_UI_METAL_BOARD_BASE_ID + (uint32_t)i);
    if (status != ER_UI_OK) return status;
  }
  status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 8.0f, bounds.y + bounds.h - 84.0f, bounds.w - 16.0f, 32.0f), theme,
                                    "Shuffle", ER_UI_METAL_BOARD_BASE_ID + 50u, ER_UI_SHADCN_BUTTON_SECONDARY, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 8.0f, bounds.y + bounds.h - 44.0f, bounds.w - 16.0f, 32.0f), theme,
                                  "Get Code", ER_UI_METAL_BOARD_BASE_ID + 51u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
}

static er_ui_status_t er_ui_metal_emit_showcase_topbar(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  er_ui_painter_t painter = er_ui_painter(scene);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, theme.radius.panel, er_ui_color_with_alpha(theme.colors.bg, 0.96f)));
  if (status != ER_UI_OK) return status;
  status = er_ui_painter_icon(&painter, er_ui_bounds(bounds.x + 12.0f, bounds.y + 15.0f, 20.0f, 20.0f), ER_UI_ICON_SPARKLES, theme.colors.accent);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(bounds.x + 44.0f, bounds.y + 9.0f, 96.0f, 34.0f), theme, "Components",
                                    ER_UI_METAL_BOARD_BASE_ID + 60u, ER_UI_SHADCN_BUTTON_GHOST, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_command_palette_emit(scene, font, er_ui_bounds(bounds.x + 154.0f, bounds.y + 7.0f, bounds.w - 430.0f, 38.0f), theme,
                                             "Search components, blocks, charts...", ER_UI_METAL_BOARD_BASE_ID + 61u);
  if (status != ER_UI_OK) return status;
  status = er_ui_metal_emit_icon_bar(scene, font, er_ui_bounds(bounds.x + bounds.w - 252.0f, bounds.y + 8.0f, 252.0f, 36.0f), theme);
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y + bounds.h - 1.0f, bounds.w, 1.0f, 0.0f, er_ui_color_with_alpha(theme.colors.border, 0.56f)));
}

//@optimizer-ignore-function the 720p board deliberately places varied cards in a stable masonry-like order
static er_ui_status_t er_ui_metal_emit_component_board(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  static const char* const months[] = {"Dec", "Jan", "Feb", "Mar", "Apr", "May"};
  static const float month_values[] = {0.42f, 0.66f, 0.48f, 0.78f, 0.38f, 0.84f};
  static const char* const tx_headers[] = {"Name", "Date", "Amount"};
  static const char* const tx_cells[] = {
    "Blue Bottle", "Today", "-$6.50",
    "Stripe Payout", "Oct 12", "+$4,200",
    "Netflix", "Oct 10", "-$19.99"
  };
  float gap = 14.0f;
  float col_w = (bounds.w - gap * 3.0f) * 0.25f;
  er_ui_bounds_t c0 = er_ui_bounds(bounds.x, bounds.y, col_w, 288.0f);
  er_ui_bounds_t c1 = er_ui_bounds(bounds.x + (col_w + gap), bounds.y, col_w, 288.0f);
  er_ui_bounds_t c2 = er_ui_bounds(bounds.x + (col_w + gap) * 2.0f, bounds.y, col_w, 198.0f);
  er_ui_bounds_t c3 = er_ui_bounds(bounds.x + (col_w + gap) * 3.0f, bounds.y, col_w, 288.0f);
  er_ui_bounds_t wide = er_ui_bounds(c1.x, bounds.y + 302.0f, col_w * 2.0f + gap, 198.0f);
  er_ui_status_t status = er_ui_shadcn_card_emit(scene, c0, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_bar_chart_emit(scene, font, er_ui_bounds(c0.x + 14.0f, c0.y + 14.0f, c0.w - 28.0f, 164.0f), theme,
                                       "Contribution History", months, month_values, 6u, ER_UI_METAL_BOARD_BASE_ID + 100u, 5u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(c0.x + 14.0f, c0.y + 190.0f, c0.w - 28.0f, 72.0f), theme,
                                         "Upcoming", "May 25, 2024", "", false, 0.0f, theme.colors.accent);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_card_emit(scene, c1, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_select_emit(scene, font, er_ui_bounds(c1.x + 14.0f, c1.y + 18.0f, c1.w - 28.0f, 58.0f), theme,
                                    "Preferred Currency", "USD - United States Dollar", ER_UI_METAL_BOARD_BASE_ID + 120u, false);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_slider_emit(scene, font, er_ui_bounds(c1.x + 14.0f, c1.y + 92.0f, c1.w - 28.0f, 70.0f), theme,
                                    "Minimum Payout Amount", 0.24f, ER_UI_METAL_BOARD_BASE_ID + 121u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(c1.x + 14.0f, c1.y + 168.0f, c1.w - 28.0f, 72.0f), theme,
                                   "Notes", "Monthly threshold", ER_UI_METAL_BOARD_BASE_ID + 122u, false);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(c1.x + 14.0f, c1.y + 246.0f, c1.w - 28.0f, 32.0f), theme, "Save Threshold",
                                    ER_UI_METAL_BOARD_BASE_ID + 123u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_metric_card_emit(scene, font, c2, theme, "Savings Targets", "$420,000", "65% achieved", true, 0.65f, theme.colors.success);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(c2.x, c2.y + c2.h + gap, c2.w, 86.0f), theme,
                                         "Real Estate", "$85,000", "32% achieved", true, 0.32f, theme.colors.info);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_card_emit(scene, c3, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_field_emit(scene, font, er_ui_bounds(c3.x + 14.0f, c3.y + 14.0f, c3.w - 28.0f, 58.0f), theme,
                                   "Amount to Invest", "$1,000.00", ER_UI_METAL_BOARD_BASE_ID + 140u, false);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_select_emit(scene, font, er_ui_bounds(c3.x + 14.0f, c3.y + 84.0f, c3.w - 28.0f, 58.0f), theme,
                                    "Order Type", "Market Order", ER_UI_METAL_BOARD_BASE_ID + 141u, false);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_receipt_row_emit(scene, font, er_ui_bounds(c3.x + 14.0f, c3.y + 158.0f, c3.w - 28.0f, 54.0f), theme,
                                         "Estimated Shares", "1.95", "VOO", ER_UI_METAL_BOARD_BASE_ID + 142u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_button_emit(scene, font, er_ui_bounds(c3.x + 14.0f, c3.y + 238.0f, c3.w - 28.0f, 34.0f), theme, "Review Order",
                                    ER_UI_METAL_BOARD_BASE_ID + 143u, ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_SM, true);
  if (status != ER_UI_OK) return status;

  status = er_ui_shadcn_table_emit(scene, font, wide, theme, tx_headers, 3u, tx_cells, 3u, ER_UI_METAL_BOARD_BASE_ID + 160u);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_empty_emit(scene, font, er_ui_bounds(c0.x, c0.y + c0.h + gap, c0.w, 198.0f), theme,
                                   "Distribute Track", "Upload your first master to reach listeners.");
  if (status != ER_UI_OK) return status;
  return er_ui_shadcn_card_emit(scene, er_ui_bounds(c3.x, c3.y + c3.h + gap, c3.w, 198.0f), theme);
}

er_ui_status_t er_ui_edgerun_metal_surface_emit(
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  const er_ui_shadcn_demo_gallery_state_t* state) {
  static const char* const tabs[] = {"Executor", "Buses", "Renderer", "Components"};
  static const char* const route_hops[] = {"device", "executor", "ui-core", "scanout"};
  static const char* const bus_headers[] = {"Bus", "Addressing", "Status"};
  static const char* const bus_cells[] = {
    "Display", "scanout surface", "admitted",
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
    er_ui_bounds_t rail = er_ui_bounds(content.x, content.y, 176.0f, content.h);
    er_ui_bounds_t main = er_ui_bounds(rail.x + rail.w + layout.block_gap, content.y, content.w - rail.w - layout.block_gap, content.h);
    er_ui_bounds_t topbar = er_ui_bounds(main.x, main.y, main.w, 52.0f);
    er_ui_bounds_t board = er_ui_bounds(main.x, topbar.y + topbar.h + layout.block_gap, main.w, main.h - topbar.h - layout.block_gap);
    if (!er_ui_bounds_valid(board)) return ER_UI_ERR_INVALID_ARGUMENT;

    status = er_ui_metal_emit_style_rail(scene, font, rail, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_metal_emit_showcase_topbar(scene, font, topbar, theme);
    if (status != ER_UI_OK) return status;
    status = er_ui_metal_emit_component_board(scene, font, board, theme);
    if (status != ER_UI_OK) return status;
    (void)state;
    return ER_UI_OK;
  }

  status = er_ui_shadcn_panel_header_emit(scene, font, header, theme, "EdgeRun Metal", "UI scene commands admitted to display relay", "READY", ER_UI_METAL_HEADER_ACTION_ID);
  if (status != ER_UI_OK) return status;
  status = er_ui_shadcn_tabs_emit(scene, font, tabs_bounds, theme, tabs, sizeof(tabs) / sizeof(tabs[0]), 3u, ER_UI_METAL_TAB_BASE_ID);
  if (status != ER_UI_OK) return status;

  float metric_w = (metric_row.w - layout.block_gap * 2.0f) / ER_UI_METAL_METRIC_COLUMNS;
  status = er_ui_shadcn_metric_card_emit(scene, font, er_ui_bounds(metric_row.x, metric_row.y, metric_w, metric_row.h), theme, "Display", "Relay",
                                         "scanout surface active", true, 0.82f, theme.colors.accent);
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
