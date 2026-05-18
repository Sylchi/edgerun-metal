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

static void test_spacing_default_matches_tokens(void) {
  er_ui_spacing_t spacing = er_ui_spacing_default();
  expect_float(spacing.card_radius_max, ER_UI_CARD_RADIUS_MAX, "spacing: card radius token");
  expect_float(spacing.card_pad_x, ER_UI_CARD_PAD_X, "spacing: card pad x token");
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
  expect_bounds(er_ui_responsive_grid_cell(wide, ER_TEST_RESPONSIVE_GRID_SECOND_ROW_SECOND_INDEX, 96.0f),
                er_ui_bounds(10.0f + wide.column_w + 16.0f, 20.0f + 96.0f + 18.0f, wide.column_w, 96.0f),
                "spacing: responsive grid cell wraps by derived column count");
  expect_bounds(er_ui_responsive_grid_span(wide, ER_TEST_RESPONSIVE_GRID_SECOND_ROW_FIRST_INDEX, ER_TEST_RESPONSIVE_GRID_SPAN_COLUMNS, 96.0f),
                er_ui_bounds(10.0f, 20.0f + 96.0f + 18.0f, wide.column_w * 2.0f + 16.0f, 96.0f),
                "spacing: responsive grid span derives width from columns");
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
}

void run_spacing_tests(void) {
  test_spacing_default_matches_tokens();
  test_component_padding_density_tokens_are_monotonic();
  test_responsive_app_surface_spacing();
  test_responsive_grid_derives_columns_from_available_width();
  test_system_panel_and_row_geometry();
  test_scroll_geometry_uses_shared_padding_and_hit_contract();
}
