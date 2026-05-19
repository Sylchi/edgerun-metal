#include "test_common.h"

static void expect_bounds(er_ui_bounds_t got, er_ui_bounds_t expected, const char* name) {
  expect_float(got.x, expected.x, name);
  expect_float(got.y, expected.y, name);
  expect_float(got.w, expected.w, name);
  expect_float(got.h, expected.h, name);
}

static const size_t ER_TEST_RESPONSIVE_GRID_MAX_COLUMNS = 3u;
static const size_t ER_TEST_RESPONSIVE_GRID_SECOND_ROW_FIRST_INDEX = 3u;
static const size_t ER_TEST_RESPONSIVE_GRID_SECOND_ROW_SECOND_INDEX = 4u;
static const size_t ER_TEST_RESPONSIVE_GRID_SPAN_COLUMNS = 2u;
static const size_t ER_TEST_RESPONSIVE_GRID_ITEM_COUNT = 5u;
static const size_t ER_TEST_RESPONSIVE_GRID_EXPECTED_ROWS = 2u;
static const float ER_TEST_RESPONSIVE_GRID_ROW_H = 96.0f;
static const size_t ER_TEST_UNIFORM_GRID_COLUMNS = 3u;
static const size_t ER_TEST_UNIFORM_GRID_ROWS = 2u;
static const size_t ER_TEST_UNIFORM_GRID_SECOND_ROW_FIRST_INDEX = 3u;
static const size_t ER_TEST_UNIFORM_GRID_SECOND_ROW_SECOND_INDEX = 4u;
static const size_t ER_TEST_UNIFORM_GRID_SPAN_COLUMNS = 2u;
static const float ER_TEST_SIDECAR_MIN_SIDE_W = 160.0f;
static const float ER_TEST_SIDECAR_PREFERRED_SIDE_W = 220.0f;
static const float ER_TEST_SIDECAR_MIN_MAIN_W = 300.0f;
static const float ER_TEST_SIDECAR_GAP = 24.0f;
static const float ER_TEST_SIDECAR_STACKED_H = 120.0f;
static const float ER_TEST_VERTICAL_FLOW_GAP = 12.0f;
static const float ER_TEST_VERTICAL_FLOW_FIRST_H = 110.0f;
static const float ER_TEST_VERTICAL_FLOW_SECOND_H = 80.0f;
static const float ER_TEST_SCROLL_VIEWPORT_CONTENT_H = 360.0f;
static const float ER_TEST_SCROLL_VIEWPORT_VALUE = 0.25f;
static const float ER_TEST_SCROLL_VIEWPORT_MIN_THUMB_H = 30.0f;
static const float ER_TEST_SCROLL_VIEWPORT_OVERFLOW_H = 180.0f;
static const float ER_TEST_SCROLL_VIEWPORT_OFFSET_Y = 45.0f;
static const float ER_TEST_SCROLL_VIEWPORT_THUMB_H = 90.0f;
static const float ER_TEST_SCROLL_VIEWPORT_THUMB_Y = 42.5f;

static void test_spacing_default_matches_tokens(void) {
  er_ui_spacing_t spacing = er_ui_spacing_default();
  expect_float(spacing.card_radius_max, ER_UI_CARD_RADIUS_MAX, "spacing: card radius token");
  expect_float(spacing.card_pad_x, ER_UI_CARD_PAD_X, "spacing: card pad x token");
  expect_float(spacing.control_h, 36.0f, "spacing: control height follows design Vega");
  expect_float(spacing.component_pad.x, ER_UI_COMPONENT_PAD_X, "spacing: component pad x token");
  expect_float(spacing.row_text_inset, ER_UI_ROW_TEXT_INSET, "spacing: row text inset token");
  expect_float(spacing.list_row_h, ER_UI_LIST_ROW_H, "spacing: list row height token");
  expect_float(spacing.workspace_gap, ER_UI_WORKSPACE_GAP, "spacing: workspace gap token");
  expect_float(spacing.min_touch_target, ER_UI_MIN_TOUCH_TARGET, "spacing: touch target token");
}

static void test_component_padding_density_tokens_are_monotonic(void) {
  er_ui_component_padding_t dense = er_ui_component_padding_for_density(ER_UI_COMPONENT_DENSITY_DENSE);
  er_ui_component_padding_t normal = er_ui_component_padding_for_density(ER_UI_COMPONENT_DENSITY_DEFAULT);
  er_ui_component_padding_t spacious = er_ui_component_padding_for_density(ER_UI_COMPONENT_DENSITY_SPACIOUS);
  expect_true(dense.x < normal.x, "spacing: dense x smaller than default");
  expect_true(dense.y < normal.y, "spacing: dense y smaller than default");
  expect_true(normal.x < spacious.x, "spacing: default x smaller than spacious");
  expect_true(normal.y < spacious.y, "spacing: default y smaller than spacious");
  expect_float(normal.x, ER_UI_CARD_PAD_X, "spacing: default x follows card pad");
  expect_float(normal.y, ER_UI_CARD_PAD_Y, "spacing: default y follows card pad");
  expect_bounds(er_ui_component_content_rect(er_ui_bounds(10.0f, 20.0f, 220.0f, 140.0f), ER_UI_COMPONENT_DENSITY_DEFAULT),
                er_ui_bounds(10.0f + normal.x, 20.0f + normal.y, 220.0f - normal.x * 2.0f, 140.0f - normal.y * 2.0f),
                "spacing: component content rect follows density padding");
}

static void test_responsive_app_surface_spacing(void) {
  er_ui_component_padding_t narrow = er_ui_app_surface_padding_for_width(390.0f);
  er_ui_component_padding_t normal = er_ui_app_surface_padding_for_width(900.0f);
  er_ui_component_padding_t wide = er_ui_app_surface_padding_for_width(1440.0f);
  expect_float(narrow.x, ER_UI_APP_SURFACE_INSET_X_NARROW, "spacing: narrow app inset");
  expect_float(normal.x, ER_UI_APP_SURFACE_INSET_X, "spacing: default app inset");
  expect_float(wide.x, ER_UI_APP_SURFACE_INSET_X_WIDE, "spacing: wide app inset");
  expect_true(narrow.x < normal.x, "spacing: narrow less than default");
  expect_true(normal.x < wide.x, "spacing: default less than wide");
  expect_bounds(er_ui_app_surface_content_rect(er_ui_bounds(0.0f, 0.0f, 390.0f, 260.0f)), er_ui_bounds(10.0f, 10.0f, 370.0f, 240.0f),
                "spacing: app surface content rect");
}

static void test_responsive_grid_derives_columns_from_available_width(void) {
  er_ui_responsive_grid_t narrow =
    er_ui_responsive_grid(er_ui_bounds(10.0f, 20.0f, 360.0f, 400.0f), 220.0f, ER_TEST_RESPONSIVE_GRID_MAX_COLUMNS, 16.0f, 18.0f);
  er_ui_responsive_grid_t wide =
    er_ui_responsive_grid(er_ui_bounds(10.0f, 20.0f, 720.0f, 400.0f), 220.0f, ER_TEST_RESPONSIVE_GRID_MAX_COLUMNS, 16.0f, 18.0f);
  expect_size(narrow.columns, 1u, "spacing: narrow responsive grid uses one column");
  expect_float(narrow.column_w, 360.0f, "spacing: narrow responsive grid stretches column");
  expect_size(wide.columns, ER_TEST_RESPONSIVE_GRID_MAX_COLUMNS, "spacing: wide responsive grid uses max fitting columns");
  expect_float(wide.column_w, (720.0f - 32.0f) / 3.0f, "spacing: wide responsive grid derives column width");
  expect_size(er_ui_responsive_grid_row_count(wide, ER_TEST_RESPONSIVE_GRID_ITEM_COUNT),
              ER_TEST_RESPONSIVE_GRID_EXPECTED_ROWS,
              "spacing: responsive grid row count wraps items by columns");
  expect_float(er_ui_responsive_grid_row_height(wide, ER_TEST_RESPONSIVE_GRID_EXPECTED_ROWS),
               (400.0f - 18.0f) / 2.0f,
               "spacing: responsive grid row height derives from rows");
  expect_float(er_ui_responsive_grid_height(wide, ER_TEST_RESPONSIVE_GRID_ITEM_COUNT, ER_TEST_RESPONSIVE_GRID_ROW_H),
               ER_TEST_RESPONSIVE_GRID_ROW_H * 2.0f + 18.0f,
               "spacing: responsive grid height includes row gaps");
  expect_bounds(er_ui_responsive_grid_cell(wide, ER_TEST_RESPONSIVE_GRID_SECOND_ROW_SECOND_INDEX, ER_TEST_RESPONSIVE_GRID_ROW_H),
                er_ui_bounds(10.0f + wide.column_w + 16.0f, 20.0f + ER_TEST_RESPONSIVE_GRID_ROW_H + 18.0f, wide.column_w,
                             ER_TEST_RESPONSIVE_GRID_ROW_H),
                "spacing: responsive grid cell wraps by derived column count");
  expect_bounds(er_ui_responsive_grid_span(wide, ER_TEST_RESPONSIVE_GRID_SECOND_ROW_FIRST_INDEX, ER_TEST_RESPONSIVE_GRID_SPAN_COLUMNS,
                                           ER_TEST_RESPONSIVE_GRID_ROW_H),
                er_ui_bounds(10.0f, 20.0f + ER_TEST_RESPONSIVE_GRID_ROW_H + 18.0f, wide.column_w * 2.0f + 16.0f,
                             ER_TEST_RESPONSIVE_GRID_ROW_H),
                "spacing: responsive grid span derives width from columns");
}

static void test_responsive_sidecar_adapts_without_fixed_content_math(void) {
  er_ui_responsive_sidecar_t wide = er_ui_responsive_sidecar(
    er_ui_bounds(10.0f, 20.0f, 760.0f, 420.0f),
    ER_TEST_SIDECAR_MIN_SIDE_W,
    ER_TEST_SIDECAR_PREFERRED_SIDE_W,
    ER_TEST_SIDECAR_MIN_MAIN_W,
    ER_TEST_SIDECAR_GAP,
    ER_TEST_SIDECAR_STACKED_H);
  er_ui_responsive_sidecar_t compressed = er_ui_responsive_sidecar(
    er_ui_bounds(10.0f, 20.0f, 500.0f, 420.0f),
    ER_TEST_SIDECAR_MIN_SIDE_W,
    ER_TEST_SIDECAR_PREFERRED_SIDE_W,
    ER_TEST_SIDECAR_MIN_MAIN_W,
    ER_TEST_SIDECAR_GAP,
    ER_TEST_SIDECAR_STACKED_H);
  er_ui_responsive_sidecar_t stacked = er_ui_responsive_sidecar(
    er_ui_bounds(10.0f, 20.0f, 420.0f, 420.0f),
    ER_TEST_SIDECAR_MIN_SIDE_W,
    ER_TEST_SIDECAR_PREFERRED_SIDE_W,
    ER_TEST_SIDECAR_MIN_MAIN_W,
    ER_TEST_SIDECAR_GAP,
    ER_TEST_SIDECAR_STACKED_H);
  expect_true(!wide.stacked, "spacing: wide sidecar remains horizontal");
  expect_bounds(wide.side, er_ui_bounds(10.0f, 20.0f, ER_TEST_SIDECAR_PREFERRED_SIDE_W, 420.0f), "spacing: wide sidecar uses preferred side");
  expect_float(wide.main.x, wide.side.x + wide.side.w + ER_TEST_SIDECAR_GAP, "spacing: wide sidecar main follows side gap");
  expect_true(!compressed.stacked, "spacing: compressed sidecar remains horizontal");
  expect_float(compressed.side.w, ER_TEST_SIDECAR_MIN_SIDE_W + 16.0f, "spacing: compressed sidecar shares extra width");
  expect_float(compressed.main.w, ER_TEST_SIDECAR_MIN_MAIN_W, "spacing: compressed sidecar preserves main minimum");
  expect_true(stacked.stacked, "spacing: narrow sidecar stacks");
  expect_bounds(stacked.side, er_ui_bounds(10.0f, 20.0f, 420.0f, ER_TEST_SIDECAR_STACKED_H), "spacing: stacked sidecar side becomes top region");
  expect_float(stacked.main.y, stacked.side.y + stacked.side.h + ER_TEST_SIDECAR_GAP, "spacing: stacked sidecar main follows vertical gap");
}

static void test_uniform_grid_divides_exact_tracks_without_callsite_math(void) {
  er_ui_uniform_grid_t grid = er_ui_uniform_grid(er_ui_bounds(10.0f, 20.0f, 720.0f, 260.0f),
                                                ER_TEST_UNIFORM_GRID_COLUMNS,
                                                ER_TEST_UNIFORM_GRID_ROWS,
                                                16.0f,
                                                18.0f);
  expect_size(grid.columns, ER_TEST_UNIFORM_GRID_COLUMNS, "spacing: uniform grid preserves exact columns");
  expect_size(grid.rows, ER_TEST_UNIFORM_GRID_ROWS, "spacing: uniform grid preserves exact rows");
  expect_float(grid.cell_w, (720.0f - 32.0f) / 3.0f, "spacing: uniform grid derives cell width");
  expect_float(grid.cell_h, (260.0f - 18.0f) / 2.0f, "spacing: uniform grid derives cell height");
  expect_bounds(er_ui_uniform_grid_cell(grid, ER_TEST_UNIFORM_GRID_SECOND_ROW_SECOND_INDEX),
                er_ui_bounds(10.0f + grid.cell_w + 16.0f, 20.0f + grid.cell_h + 18.0f, grid.cell_w, grid.cell_h),
                "spacing: uniform grid cell wraps by exact columns");
  expect_bounds(er_ui_uniform_grid_span(grid, ER_TEST_UNIFORM_GRID_SECOND_ROW_FIRST_INDEX, ER_TEST_UNIFORM_GRID_SPAN_COLUMNS, 1u),
                er_ui_bounds(10.0f, 20.0f + grid.cell_h + 18.0f, grid.cell_w * 2.0f + 16.0f, grid.cell_h),
                "spacing: uniform grid span derives exact track bounds");
}

static void test_vertical_flow_allocates_stack_and_remaining_bounds(void) {
  er_ui_vertical_flow_t flow = er_ui_vertical_flow(er_ui_bounds(10.0f, 20.0f, 320.0f, 260.0f), ER_TEST_VERTICAL_FLOW_GAP);
  er_ui_bounds_t first = er_ui_vertical_flow_next(&flow, ER_TEST_VERTICAL_FLOW_FIRST_H);
  er_ui_bounds_t second = er_ui_vertical_flow_next(&flow, ER_TEST_VERTICAL_FLOW_SECOND_H);
  er_ui_bounds_t remaining = er_ui_vertical_flow_remaining(&flow);
  expect_bounds(first, er_ui_bounds(10.0f, 20.0f, 320.0f, ER_TEST_VERTICAL_FLOW_FIRST_H), "spacing: vertical flow first item");
  expect_bounds(second,
                er_ui_bounds(10.0f, 20.0f + ER_TEST_VERTICAL_FLOW_FIRST_H + ER_TEST_VERTICAL_FLOW_GAP, 320.0f, ER_TEST_VERTICAL_FLOW_SECOND_H),
                "spacing: vertical flow second item");
  expect_bounds(remaining,
                er_ui_bounds(10.0f, second.y + second.h + ER_TEST_VERTICAL_FLOW_GAP, 320.0f,
                             260.0f - ER_TEST_VERTICAL_FLOW_FIRST_H - ER_TEST_VERTICAL_FLOW_SECOND_H - ER_TEST_VERTICAL_FLOW_GAP * 2.0f),
                "spacing: vertical flow remaining item");
}

static void test_system_panel_and_row_geometry(void) {
  er_ui_bounds_t row = er_ui_bounds(10.0f, 20.0f, 360.0f, ER_UI_ROW_H);
  er_ui_bounds_t icon = er_ui_row_icon_slot(row);
  er_ui_bounds_t text = er_ui_row_text_rect(row, 120.0f);
  expect_bounds(icon, er_ui_bounds(24.0f, 32.0f, ER_UI_ROW_ICON, ER_UI_ROW_ICON), "spacing: row icon slot");
  expect_float(text.x, row.x + ER_UI_ROW_TEXT_INSET, "spacing: row text x");
  expect_float(text.w, row.w - ER_UI_ROW_TEXT_INSET - ER_UI_ROW_PAD_X - 120.0f, "spacing: row text width");

  er_ui_bounds_t safe = er_ui_system_surface_safe_rect(er_ui_bounds(0.0f, 0.0f, 360.0f, 260.0f));
  er_ui_bounds_t panel = er_ui_centered_system_panel(safe, 320.0f, 520.0f, 320.0f, 220.0f);
  expect_bounds(safe, er_ui_bounds(10.0f, 10.0f, 340.0f, 240.0f), "spacing: system safe rect");
  expect_true(panel.x >= safe.x, "spacing: panel stays inside safe x");
  expect_true(panel.y >= safe.y, "spacing: panel stays inside safe y");
  expect_true(panel.x + panel.w <= safe.x + safe.w, "spacing: panel stays inside safe width");
  expect_true(panel.y + panel.h <= safe.y + safe.h, "spacing: panel stays inside safe height");
}

static void test_scroll_geometry_uses_shared_padding_and_hit_contract(void) {
  er_ui_bounds_t bounds = er_ui_bounds(10.0f, 20.0f, 220.0f, 180.0f);
  const float padding[] = {12.0f, 14.0f, 16.0f, 18.0f};
  er_ui_bounds_t content = er_ui_scroll_content_rect(bounds, padding);
  er_ui_bounds_t track = er_ui_scrollbar_track_rect(bounds, content);
  er_ui_bounds_t hit = er_ui_scrollbar_hit_rect(track);
  expect_bounds(content, er_ui_bounds(28.0f, 32.0f, 220.0f - 18.0f - 14.0f - ER_UI_SCROLLBAR_RESERVED_W, 180.0f - 12.0f - 16.0f),
                "spacing: scroll content rect");
  expect_float(track.w, ER_UI_SCROLLBAR_TRACK_W, "spacing: scrollbar track width");
  expect_float(track.h, content.h, "spacing: scrollbar track height");
  expect_float(hit.w, ER_UI_SCROLLBAR_HIT_W, "spacing: scrollbar hit width");
  expect_float(hit.h, track.h, "spacing: scrollbar hit height");
  expect_true(hit.x <= track.x, "spacing: scrollbar hit covers track");

  er_ui_scroll_viewport_t viewport =
    er_ui_scroll_viewport(bounds, ER_TEST_SCROLL_VIEWPORT_CONTENT_H, ER_TEST_SCROLL_VIEWPORT_VALUE, ER_TEST_SCROLL_VIEWPORT_MIN_THUMB_H);
  expect_true(viewport.scrollable, "spacing: scroll viewport reports overflow");
  expect_float(viewport.overflow_h, ER_TEST_SCROLL_VIEWPORT_OVERFLOW_H, "spacing: scroll viewport overflow height");
  expect_float(viewport.scroll_px, ER_TEST_SCROLL_VIEWPORT_OFFSET_Y, "spacing: scroll viewport pixel offset");
  expect_bounds(viewport.content, er_ui_bounds(bounds.x, bounds.y - ER_TEST_SCROLL_VIEWPORT_OFFSET_Y, bounds.w, ER_TEST_SCROLL_VIEWPORT_CONTENT_H),
                "spacing: scroll viewport content bounds");
  expect_bounds(viewport.thumb, er_ui_bounds(track.x, ER_TEST_SCROLL_VIEWPORT_THUMB_Y, track.w, ER_TEST_SCROLL_VIEWPORT_THUMB_H),
                "spacing: scroll viewport thumb bounds");
}

void run_spacing_tests(void) {
  test_spacing_default_matches_tokens();
  test_component_padding_density_tokens_are_monotonic();
  test_responsive_app_surface_spacing();
  test_responsive_grid_derives_columns_from_available_width();
  test_responsive_sidecar_adapts_without_fixed_content_math();
  test_uniform_grid_divides_exact_tracks_without_callsite_math();
  test_vertical_flow_allocates_stack_and_remaining_bounds();
  test_system_panel_and_row_geometry();
  test_scroll_geometry_uses_shared_padding_and_hit_contract();
}
