#include "test_common.h"
#include "../src/er_ui_components_internal.h"

#define ER_UI_TEST_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_TEST_COMPONENT_BUTTON_ID 3001u
#define ER_UI_TEST_COMPONENT_SELECT_ID 3002u
#define ER_UI_TEST_COMPONENT_SLIDER_ID 3003u
#define ER_UI_TEST_COMPONENT_FIELD_ID 3004u
#define ER_UI_TEST_COMPONENT_TEXTAREA_ID 3005u
#define ER_UI_TEST_COMPONENT_CHECKBOX_ID 3006u
#define ER_UI_TEST_COMPONENT_SWITCH_ID 3007u
#define ER_UI_TEST_COMPONENT_TABS_ID 3010u
#define ER_UI_TEST_COMPONENT_LIST_ROW_ID 3013u
#define ER_UI_TEST_COMPONENT_RADIO_ID 3014u
#define ER_UI_TEST_COMPONENT_TABLE_ID 3015u
#define ER_UI_TEST_COMPONENT_BREADCRUMB_ID 3020u
#define ER_UI_TEST_COMPONENT_CHART_ID 3024u
#define ER_UI_TEST_COMPONENT_THREAD_ROW_ID 3030u
#define ER_UI_TEST_COMPONENT_ATTACHMENT_ID 3031u
#define ER_UI_TEST_COMPONENT_INVALID_BUTTON_ID 9u
#define ER_UI_TEST_COMPONENT_TABS_ACTIVE_INDEX 1u
#define ER_UI_TEST_COMPONENT_BREADCRUMB_CURRENT_INDEX 2u
#define ER_UI_TEST_COMPONENT_CHART_ACTIVE_INDEX 1u
#define ER_UI_TEST_COMPONENT_MIN_INITIAL_RECTS 8u
#define ER_UI_TEST_COMPONENT_MIN_INITIAL_HITS 10u
#define ER_UI_TEST_COMPONENT_NARROW_ID_OFFSET 80u
#define ER_UI_TEST_COMPONENT_INVOICE_ID_OFFSET 240u

static float test_component_text_max_x_since(const er_ui_scene_t* scene, size_t first_quad) {
  float max_x = 0.0f;
  if (!scene) return max_x;
  for (size_t i = first_quad; i < scene->text_quad_count; ++i) {
    float right = scene->text_quads[i].x + scene->text_quads[i].w;
    if (right > max_x) max_x = right;
  }
  return max_x;
}

static void test_component_render_primitives(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_palette_slate_950(), er_ui_test_allocator()), ER_UI_OK,
                "component render: scene init succeeds");

  vr_font_face_t* face =
      er_ui_test_open_font(14.0f, "component render: bundled variable font loads", "component render: variable font opens from memory");
  if (!face) {
    er_ui_scene_destroy(&scene);
    return;
  }

  er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
  expect_status(er_ui_component_card_emit(&scene, er_ui_bounds(4.0f, 4.0f, 220.0f, 156.0f), theme), ER_UI_OK,
                "component render: card emits");
  expect_status(er_ui_component_button_emit(&scene, face, er_ui_bounds(16.0f, 16.0f, 128.0f, 48.0f), theme, "Deploy", ER_UI_TEST_COMPONENT_BUTTON_ID,
                                         ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true),
                ER_UI_OK, "component render: button emits");
  expect_status(er_ui_component_select_emit(&scene, face, er_ui_bounds(16.0f, 66.0f, 188.0f, 62.0f), theme, "Currency", "USD",
                                         ER_UI_TEST_COMPONENT_SELECT_ID, true),
                ER_UI_OK, "component render: select emits");
  expect_status(er_ui_component_slider_emit(&scene, face, er_ui_bounds(16.0f, 126.0f, 188.0f, 48.0f), theme, "Minimum payout", 0.42f,
                                         ER_UI_TEST_COMPONENT_SLIDER_ID),
                ER_UI_OK, "component render: slider emits");
  expect_status(er_ui_component_badge_emit(&scene, face, er_ui_bounds(232.0f, 16.0f, 88.0f, 26.0f), theme, "Active",
                                        ER_UI_COMPONENT_BADGE_SECONDARY),
                ER_UI_OK, "component render: badge emits");
  expect_status(er_ui_component_field_emit(&scene, face, er_ui_bounds(232.0f, 48.0f, 160.0f, 58.0f), theme, "Name", "Example",
                                        ER_UI_TEST_COMPONENT_FIELD_ID, false),
                ER_UI_OK, "component render: field emits");
  expect_status(er_ui_component_field_emit(&scene, face, er_ui_bounds(232.0f, 110.0f, 160.0f, 86.0f), theme, "Notes", "Verified cache",
                                        ER_UI_TEST_COMPONENT_TEXTAREA_ID, true),
                ER_UI_OK, "component render: textarea emits");
  size_t passive_hit_count = scene.hit_count;
  expect_status(er_ui_component_select_static_emit(&scene, face, er_ui_bounds(232.0f, 198.0f, 160.0f, 58.0f), theme, "Currency", "USD", false),
                ER_UI_OK, "component render: passive select emits");
  expect_status(er_ui_component_field_static_emit(&scene, face, er_ui_bounds(232.0f, 260.0f, 160.0f, 58.0f), theme, "Account", "Studio", false),
                ER_UI_OK, "component render: passive field emits");
  expect_size(scene.hit_count, passive_hit_count, "component render: passive controls do not emit hits");
  er_ui_bounds_t narrow_select = er_ui_bounds(232.0f, 322.0f, 108.0f, 58.0f);
  size_t narrow_text_start = scene.text_quad_count;
  expect_status(er_ui_component_select_static_emit(&scene, face, narrow_select, theme, "Currency", "USD - United States Dollar", false),
                ER_UI_OK, "component render: narrow passive select emits");
  expect_true(test_component_text_max_x_since(&scene, narrow_text_start) <= narrow_select.x + narrow_select.w,
              "component render: narrow passive select text stays inside control");
  er_ui_bounds_t narrow_choice = er_ui_bounds(232.0f, 384.0f, 112.0f, 32.0f);
  narrow_text_start = scene.text_quad_count;
  expect_status(er_ui_component_checkbox_emit(&scene, face, narrow_choice, theme, "Cache verified bytes before retrieval", true,
                                           ER_UI_TEST_COMPONENT_CHECKBOX_ID + ER_UI_TEST_COMPONENT_NARROW_ID_OFFSET),
                ER_UI_OK, "component render: narrow checkbox emits");
  expect_true(test_component_text_max_x_since(&scene, narrow_text_start) <= narrow_choice.x + narrow_choice.w,
              "component render: narrow checkbox text stays inside control");
  er_ui_bounds_t narrow_tabs = er_ui_bounds(232.0f, 422.0f, 132.0f, 34.0f);
  const char *const narrow_tab_labels[] = {"Overview", "Transactions", "Settings"};
  narrow_text_start = scene.text_quad_count;
  expect_status(er_ui_component_tabs_emit(&scene, face, narrow_tabs, theme, narrow_tab_labels, ER_UI_TEST_ARRAY_COUNT(narrow_tab_labels),
                                       ER_UI_TEST_COMPONENT_TABS_ACTIVE_INDEX, ER_UI_TEST_COMPONENT_TABS_ID + ER_UI_TEST_COMPONENT_NARROW_ID_OFFSET),
                ER_UI_OK, "component render: narrow tabs emit");
  expect_true(test_component_text_max_x_since(&scene, narrow_text_start) <= narrow_tabs.x + narrow_tabs.w,
              "component render: narrow tab labels stay inside segmented control");
  er_ui_bounds_t narrow_table = er_ui_bounds(232.0f, 462.0f, 132.0f, 82.0f);
  const char *const narrow_headers[] = {"Destination", "Status"};
  const char *const narrow_cells[] = {"Main settlement account", "Pending review"};
  narrow_text_start = scene.text_quad_count;
  expect_status(er_ui_component_table_emit(&scene, face, narrow_table, theme, narrow_headers, ER_UI_TEST_ARRAY_COUNT(narrow_headers),
                                        narrow_cells, 1u, ER_UI_TEST_COMPONENT_TABLE_ID + ER_UI_TEST_COMPONENT_NARROW_ID_OFFSET),
                ER_UI_OK, "component render: narrow table emits");
  expect_true(test_component_text_max_x_since(&scene, narrow_text_start) <= narrow_table.x + narrow_table.w,
              "component render: narrow table text stays inside card");
  expect_status(er_ui_component_checkbox_emit(&scene, face, er_ui_bounds(16.0f, 180.0f, 188.0f, 32.0f), theme, "Cache verified bytes", true,
                                           ER_UI_TEST_COMPONENT_CHECKBOX_ID),
                ER_UI_OK, "component render: checkbox emits");
  expect_status(er_ui_component_progress_emit(&scene, er_ui_bounds(232.0f, 204.0f, 160.0f, 8.0f), theme, 0.64f), ER_UI_OK,
                "component render: progress emits");
  expect_status(er_ui_component_switch_emit(&scene, er_ui_bounds(16.0f, 220.0f, 44.0f, 24.0f), theme, true, ER_UI_TEST_COMPONENT_SWITCH_ID), ER_UI_OK,
                "component render: switch emits");
  expect_status(er_ui_component_separator_emit(&scene, er_ui_bounds(72.0f, 231.0f, 132.0f, 1.0f), theme), ER_UI_OK,
                "component render: separator emits");
  const char *const tabs[] = {"Preview", "Code", "A11y"};
  expect_status(er_ui_component_tabs_emit(&scene, face, er_ui_bounds(232.0f, 224.0f, 180.0f, 38.0f), theme, tabs, ER_UI_TEST_ARRAY_COUNT(tabs),
                                       ER_UI_TEST_COMPONENT_TABS_ACTIVE_INDEX, ER_UI_TEST_COMPONENT_TABS_ID),
                ER_UI_OK, "component render: tabs emit");
  expect_status(er_ui_component_list_row_emit(&scene, face, er_ui_bounds(420.0f, 148.0f, 180.0f, 48.0f), theme, "Billing", "Command B",
                                           ER_UI_TEST_COMPONENT_LIST_ROW_ID, true),
                ER_UI_OK, "component render: list row emits");
  expect_status(er_ui_component_radio_emit(&scene, face, er_ui_bounds(420.0f, 202.0f, 180.0f, 30.0f), theme, "Default", true,
                                        ER_UI_TEST_COMPONENT_RADIO_ID),
                ER_UI_OK, "component render: radio emits");
  const char *const headers[] = {"Invoice", "Status"};
  const char *const cells[] = {"INV001", "Paid", "INV002", "Pending"};
  expect_status(er_ui_component_table_emit(&scene, face, er_ui_bounds(420.0f, 238.0f, 180.0f, 96.0f), theme, headers,
	                                        ER_UI_TEST_ARRAY_COUNT(headers), cells, ER_UI_TEST_ARRAY_COUNT(headers), ER_UI_TEST_COMPONENT_TABLE_ID),
                ER_UI_OK, "component render: table emits");
  const char *const invoice_items[] = {"Design System License", "Priority Support", "Custom Components"};
  const char *const invoice_qty[] = {"1", "12", "3"};
  const char *const invoice_rates[] = {"$499.00", "$99.00", "$250.00"};
  const char *const invoice_amounts[] = {"$499.00", "$1,188.00", "$750.00"};
  expect_status(er_ui_component_invoice_card_emit(&scene, face, er_ui_bounds(880.0f, 16.0f, 420.0f, 500.0f), theme,
                                                  "Invoice #INV-2847", "Due March 30, 2026", "Pending",
                                                  invoice_items, invoice_qty, invoice_rates, invoice_amounts,
                                                  ER_UI_TEST_ARRAY_COUNT(invoice_items), "$2,437.00", "$0.00", "$2,437.00",
                                                  "Download PDF", "Pay Now", ER_UI_TEST_COMPONENT_TABLE_ID + ER_UI_TEST_COMPONENT_INVOICE_ID_OFFSET),
                ER_UI_OK, "component render: invoice card emits composed billing surface");
  expect_status(er_ui_component_skeleton_emit(&scene, er_ui_bounds(420.0f, 340.0f, 120.0f, 16.0f), theme), ER_UI_OK,
                "component render: skeleton emits");
  expect_status(er_ui_component_toast_emit(&scene, face, er_ui_bounds(420.0f, 362.0f, 180.0f, 44.0f), theme, "Scheduled", theme.colors.accent), ER_UI_OK,
                "component render: toast emits");
  expect_status(er_ui_component_empty_emit(&scene, face, er_ui_bounds(420.0f, 412.0f, 180.0f, 110.0f), theme, "No results", "Try another filter"), ER_UI_OK,
                "component render: empty emits");
  expect_status(er_ui_component_thread_row_emit(&scene, face, er_ui_bounds(606.0f, 332.0f, 220.0f, 58.0f), theme, "Settlement", "Payout approved",
                                             true, ER_UI_TEST_COMPONENT_THREAD_ROW_ID),
                ER_UI_OK, "component render: thread row emits through icon row primitive");
  expect_status(er_ui_component_attachment_preview_emit(&scene, face, er_ui_bounds(606.0f, 396.0f, 220.0f, 58.0f), theme, "schema.json", "Component schema",
                                                     ER_UI_TEST_COMPONENT_ATTACHMENT_ID),
                ER_UI_OK, "component render: attachment preview emits through icon row primitive");
  expect_status(er_ui_component_alert_emit(&scene, face, er_ui_bounds(606.0f, 16.0f, 220.0f, 72.0f), theme, "Heads up", "Reusable components", theme.colors.warning),
                ER_UI_OK, "component render: alert emits");
  expect_status(er_ui_component_avatar_emit(&scene, face, er_ui_bounds(606.0f, 96.0f, 42.0f, 42.0f), theme, "ER", theme.colors.accent, true),
                ER_UI_OK, "component render: avatar emits");
  const char *const crumbs[] = {"Docs", "Components", "Breadcrumb"};
  expect_status(er_ui_component_breadcrumb_emit(&scene, face, er_ui_bounds(606.0f, 146.0f, 220.0f, 32.0f), theme, crumbs,
                                             ER_UI_TEST_ARRAY_COUNT(crumbs), ER_UI_TEST_COMPONENT_BREADCRUMB_CURRENT_INDEX,
                                             ER_UI_TEST_COMPONENT_BREADCRUMB_ID),
                ER_UI_OK, "component render: breadcrumb emits");
  const char *const chart_labels[] = {"Jan", "Feb", "Mar"};
  const float chart_values[] = {0.4f, 0.8f, 0.6f};
  expect_status(er_ui_component_bar_chart_emit(&scene, face, er_ui_bounds(606.0f, 186.0f, 180.0f, 120.0f), theme, "Visitors", chart_labels,
                                            chart_values, ER_UI_TEST_ARRAY_COUNT(chart_labels), ER_UI_TEST_COMPONENT_CHART_ID,
                                            ER_UI_TEST_COMPONENT_CHART_ACTIVE_INDEX),
                ER_UI_OK, "component render: bar chart emits");
  expect_true(scene.rect_count >= ER_UI_TEST_COMPONENT_MIN_INITIAL_RECTS, "component render: primitives emit geometry");
  expect_true(scene.hit_count >= ER_UI_TEST_COMPONENT_MIN_INITIAL_HITS, "component render: interactive primitives emit hits");
  expect_true(scene.text_quad_count > 0u, "component render: primitives use variable font text");
  expect_true(scene.icon_quad_count > 0u, "component render: primitives use canonical Tabler icons");
  expect_status(er_ui_component_button_emit(&scene, NULL, er_ui_bounds(0.0f, 0.0f, 40.0f, 40.0f), theme, "Nope",
                                         ER_UI_TEST_COMPONENT_INVALID_BUTTON_ID,
                                         ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true),
                ER_UI_ERR_INVALID_ARGUMENT, "component render: missing variable font is rejected");

  vr_font_face_destroy(face);
  er_ui_scene_destroy(&scene);
}

void run_component_tests(void) {
  size_t state_count = 0u;
  const er_ui_component_state_t* states = er_ui_component_states(&state_count);
  expect_true(states != 0, "component states: states are exposed");
  expect_size(state_count, ER_UI_COMPONENT_STATE_COUNT, "component states: state count matches public contract");

  test_component_render_primitives();
}
