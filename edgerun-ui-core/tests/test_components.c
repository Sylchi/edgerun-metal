#include "test_common.h"

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
#define ER_UI_TEST_COMPONENT_INVALID_BUTTON_ID 9u
#define ER_UI_TEST_COMPONENT_TABS_ACTIVE_INDEX 1u
#define ER_UI_TEST_COMPONENT_BREADCRUMB_CURRENT_INDEX 2u
#define ER_UI_TEST_COMPONENT_CHART_ACTIVE_INDEX 1u
#define ER_UI_TEST_COMPONENT_MIN_INITIAL_RECTS 8u
#define ER_UI_TEST_COMPONENT_MIN_INITIAL_HITS 10u
#define ER_UI_TEST_COMPONENT_MIN_SHOWCASE_HITS 20u
#define ER_UI_TEST_COMPONENT_MIN_SHOWCASE_TEXT_QUADS 20u
#define ER_UI_TEST_COMPONENT_COMPACT_SHOWCASE_W 420.0f
#define ER_UI_TEST_COMPONENT_COMPACT_SHOWCASE_H 360.0f
#define ER_UI_TEST_COMPONENT_MIN_METAL_HITS 20u
#define ER_UI_TEST_COMPONENT_MIN_METAL_TEXT_QUADS 80u
#define ER_UI_TEST_COMPONENT_MIN_METAL_ICON_QUADS 6u
#define ER_UI_TEST_COMPONENT_COUNT 57u
#define ER_UI_TEST_COMPONENT_KEYBOARD_COUNT 2u
#define ER_UI_TEST_COMPONENT_ORDER_OPTION_INDEX 1u
#define ER_UI_TEST_COMPONENT_STOCK_BUTTON_INDEX 2u
#define ER_UI_TEST_COMPONENT_SLIDER_ACTION_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 943u)
#define ER_UI_TEST_COMPONENT_UNRELATED_BUTTON_ID 42u
#define ER_UI_TEST_APP_STORE_CARD_REQUIRED_FIELDS 3u
#define ER_UI_TEST_METAL_BOARD_BASE_ID (ER_UI_COMPONENT_PREVIEW_BASE_ID + 4600u)
#define ER_UI_TEST_METAL_PAYOUT_SELECT_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 120u)
#define ER_UI_TEST_METAL_PAYOUT_SLIDER_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 121u)
#define ER_UI_TEST_METAL_PAYOUT_NOTES_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 122u)
#define ER_UI_TEST_METAL_PAYOUT_SAVE_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 123u)
#define ER_UI_TEST_METAL_INVEST_AMOUNT_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 140u)
#define ER_UI_TEST_METAL_INVEST_ORDER_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 141u)
#define ER_UI_TEST_METAL_INVEST_REVIEW_ID (ER_UI_TEST_METAL_BOARD_BASE_ID + 143u)
#define ER_UI_TEST_METAL_COMPACT_FIRST_FORM_HIT_Y_MIN 150.0f

static const er_ui_hit_t* test_component_find_hit(const er_ui_scene_t* scene, uint32_t id) {
  if (!scene) return NULL;
  for (size_t i = 0u; i < scene->hit_count; ++i) {
    if (scene->hits[i].id == id) return &scene->hits[i];
  }
  return NULL;
}

static bool test_component_hit_before(const er_ui_hit_t* a, const er_ui_hit_t* b) {
  return a && b && a->y + a->h <= b->y;
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
  expect_status(er_ui_component_field_emit(&scene, face, er_ui_bounds(232.0f, 48.0f, 160.0f, 58.0f), theme, "Name", "EdgeRun",
                                        ER_UI_TEST_COMPONENT_FIELD_ID, false),
                ER_UI_OK, "component render: field emits");
  expect_status(er_ui_component_field_emit(&scene, face, er_ui_bounds(232.0f, 110.0f, 160.0f, 86.0f), theme, "Notes", "Verified cache",
                                        ER_UI_TEST_COMPONENT_TEXTAREA_ID, true),
                ER_UI_OK, "component render: textarea emits");
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
  expect_status(er_ui_component_skeleton_emit(&scene, er_ui_bounds(420.0f, 340.0f, 120.0f, 16.0f), theme), ER_UI_OK,
                "component render: skeleton emits");
  expect_status(er_ui_component_toast_emit(&scene, face, er_ui_bounds(420.0f, 362.0f, 180.0f, 44.0f), theme, "Scheduled", theme.colors.accent), ER_UI_OK,
                "component render: toast emits");
  expect_status(er_ui_component_empty_emit(&scene, face, er_ui_bounds(420.0f, 412.0f, 180.0f, 110.0f), theme, "No results", "Try another filter"), ER_UI_OK,
                "component render: empty emits");
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
  expect_true(scene.icon_quad_count > 0u, "component render: primitives use canonical Tabler-compatible icons");
  expect_status(er_ui_component_button_emit(&scene, NULL, er_ui_bounds(0.0f, 0.0f, 40.0f, 40.0f), theme, "Nope",
                                         ER_UI_TEST_COMPONENT_INVALID_BUTTON_ID,
                                         ER_UI_COMPONENT_BUTTON_DEFAULT, ER_UI_COMPONENT_BUTTON_SIZE_DEFAULT, true),
                ER_UI_ERR_INVALID_ARGUMENT, "component render: missing variable font is rejected");
  expect_true(er_ui_component_scene_preview_available("button"), "component scene preview: button is available");
  expect_true(er_ui_component_scene_preview_available("accordion"), "component scene preview: accordion is available");
  expect_true(er_ui_component_scene_preview_available("alert-dialog"), "component scene preview: alert dialog is available");
  expect_true(er_ui_component_scene_preview_available("avatar"), "component scene preview: avatar is available");
  expect_true(er_ui_component_scene_preview_available("chart"), "component scene preview: chart is available");
  expect_true(er_ui_component_scene_preview_available("combobox"), "component scene preview: combobox is available");
  expect_true(er_ui_component_scene_preview_available("label"), "component scene preview: label is available");
  expect_true(er_ui_component_scene_preview_available("sheet"), "component scene preview: sheet is available");
  expect_true(er_ui_component_scene_preview_available("tabs"), "component scene preview: tabs are available");
  expect_true(er_ui_component_scene_preview_available("data-table"), "component scene preview: data table is available");
  expect_true(er_ui_component_scene_preview_available("radio-group"), "component scene preview: radio group is available");
  expect_true(er_ui_component_scene_preview_available("toast"), "component scene preview: toast is available");
  expect_true(!er_ui_component_scene_preview_available("unknown-component"), "component scene preview: unknown body is not claimed");
  expect_status(er_ui_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 16.0f, 180.0f, 58.0f), theme, "button", NULL),
                ER_UI_OK, "component scene preview: selected body emits");
  expect_status(er_ui_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 530.0f, 220.0f, 112.0f), theme, "data-table", NULL),
                ER_UI_OK, "component scene preview: table body emits");
  expect_status(er_ui_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 646.0f, 240.0f, 132.0f), theme, "calendar", NULL),
                ER_UI_OK, "component scene preview: calendar body emits");
  expect_status(er_ui_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 82.0f, 180.0f, 58.0f), theme, "accordion", NULL),
                ER_UI_OK, "component scene preview: accordion body emits");
  expect_status(er_ui_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 782.0f, 180.0f, 58.0f), theme, "unknown-component", NULL),
                ER_UI_ERR_INVALID_ARGUMENT, "component scene preview: unknown body is rejected");
  er_ui_component_gallery_state_t state = {0};
  er_ui_component_gallery_state_init(&state);
  expect_status(er_ui_component_showcase_emit(&scene, face, er_ui_bounds(0.0f, 280.0f, 720.0f, 360.0f), theme, "button", &state), ER_UI_OK,
                "component showcase: component reference emits");
  expect_true(scene.hit_count >= ER_UI_TEST_COMPONENT_MIN_SHOWCASE_HITS, "component showcase: catalog rows and preview controls emit hits");
  expect_true(scene.text_quad_count > ER_UI_TEST_COMPONENT_MIN_SHOWCASE_TEXT_QUADS, "component showcase: catalog and preview use variable font text");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_component_showcase_emit(&scene, face, er_ui_bounds(0.0f, 280.0f, ER_UI_TEST_COMPONENT_COMPACT_SHOWCASE_W,
                                                                          ER_UI_TEST_COMPONENT_COMPACT_SHOWCASE_H),
                                              theme, "button", &state),
                ER_UI_OK, "component showcase: compact stacked reference emits");
  expect_true(scene.hit_count > 0u, "component showcase: compact catalog and preview emit hits");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_edgerun_metal_surface_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 3840.0f, 2160.0f), theme, &state), ER_UI_OK,
                "metal surface: ui-core owns boot scene composition");
  expect_true(scene.hit_count >= ER_UI_TEST_COMPONENT_MIN_METAL_HITS, "metal surface: showcase and controls emit hits");
  expect_true(scene.text_quad_count > ER_UI_TEST_COMPONENT_MIN_METAL_TEXT_QUADS, "metal surface: boot UI emits variable font text");
  expect_true(er_ui_scene_stats_fits_budget(er_ui_scene_stats(&scene), er_ui_scene_budget_native_interactive_frame()),
              "metal surface: boot scene fits native frame budget");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_edgerun_metal_surface_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 1920.0f, 1080.0f), theme, &state), ER_UI_OK,
                "metal surface: qemu 1080p scene emits");
  expect_true(scene.hit_count >= ER_UI_TEST_COMPONENT_MIN_METAL_HITS, "metal surface: qemu 1080p controls emit hits");
  expect_true(er_ui_scene_stats_fits_budget(er_ui_scene_stats(&scene), er_ui_scene_budget_native_interactive_frame()),
              "metal surface: qemu 1080p scene fits native frame budget");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_edgerun_metal_surface_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 1280.0f, 720.0f), theme, &state), ER_UI_OK,
                "metal surface: qemu 720p scene emits");
  expect_true(scene.hit_count >= ER_UI_TEST_COMPONENT_MIN_METAL_HITS, "metal surface: qemu 720p controls emit hits");
  expect_true(scene.icon_quad_count >= ER_UI_TEST_COMPONENT_MIN_METAL_ICON_QUADS, "metal surface: qemu 720p icon nodes emit quads");
  expect_true(er_ui_scene_stats_fits_budget(er_ui_scene_stats(&scene), er_ui_scene_budget_native_interactive_frame()),
              "metal surface: qemu 720p scene fits native frame budget");
  const er_ui_hit_t* payout_select = test_component_find_hit(&scene, ER_UI_TEST_METAL_PAYOUT_SELECT_ID);
  const er_ui_hit_t* payout_slider = test_component_find_hit(&scene, ER_UI_TEST_METAL_PAYOUT_SLIDER_ID);
  const er_ui_hit_t* payout_notes = test_component_find_hit(&scene, ER_UI_TEST_METAL_PAYOUT_NOTES_ID);
  const er_ui_hit_t* payout_save = test_component_find_hit(&scene, ER_UI_TEST_METAL_PAYOUT_SAVE_ID);
  const er_ui_hit_t* invest_amount = test_component_find_hit(&scene, ER_UI_TEST_METAL_INVEST_AMOUNT_ID);
  const er_ui_hit_t* invest_order = test_component_find_hit(&scene, ER_UI_TEST_METAL_INVEST_ORDER_ID);
  const er_ui_hit_t* invest_review = test_component_find_hit(&scene, ER_UI_TEST_METAL_INVEST_REVIEW_ID);
  expect_true(payout_select && payout_select->y >= ER_UI_TEST_METAL_COMPACT_FIRST_FORM_HIT_Y_MIN,
              "metal surface: compact payout controls clear card title band");
  expect_true(invest_amount && invest_amount->y >= ER_UI_TEST_METAL_COMPACT_FIRST_FORM_HIT_Y_MIN,
              "metal surface: compact investment controls clear card title band");
  expect_true(test_component_hit_before(payout_select, payout_slider), "metal surface: compact payout select precedes slider");
  expect_true(test_component_hit_before(payout_slider, payout_notes), "metal surface: compact payout slider precedes notes field");
  expect_true(test_component_hit_before(payout_notes, payout_save), "metal surface: compact payout notes precede save action");
  expect_true(test_component_hit_before(invest_amount, invest_order), "metal surface: compact investment amount precedes order select");
  expect_true(test_component_hit_before(invest_order, invest_review), "metal surface: compact investment order precedes review action");

  for (size_t i = 0u; i < er_ui_component_count(); ++i) {
    const er_ui_component_spec_t* spec = er_ui_component_at(i);
    expect_true(spec != NULL, "component scene preview: indexed spec exists");
    if (!spec) continue;
    expect_true(er_ui_component_scene_preview_available(spec->slug), "component scene preview: every catalog component is claimed");
    expect_status(er_ui_component_scene_preview_emit(&scene, face, er_ui_bounds(8.0f, 860.0f, 360.0f, 190.0f), theme, spec->slug, &state), ER_UI_OK,
                  "component scene preview: every catalog component emits");
  }

  vr_font_face_destroy(face);
  er_ui_scene_destroy(&scene);
}

void run_component_tests(void) {
  expect_size(er_ui_component_count(), ER_UI_TEST_COMPONENT_COUNT, "component catalog: component count matches Rust source");
  expect_true(er_ui_component_find_by_slug("accordion") != 0, "component catalog: accordion exists");
  expect_true(er_ui_component_find_by_slug("tooltip") != 0, "component catalog: tooltip exists");
  expect_true(er_ui_component_find_by_slug("data-table") != 0, "component catalog: data-table exists");
  expect_true(er_ui_component_find_by_slug("input-otp") != 0, "component catalog: input-otp exists");

  const er_ui_component_spec_t* input_group = er_ui_component_find_by_source_component("InputGroup");
  expect_true(input_group != 0, "component catalog: InputGroup resolves by source component");
  if (input_group) expect_string(input_group->slug, "input-group", "component catalog: InputGroup slug matches");
  const er_ui_component_spec_t* button = er_ui_component_find_by_slug("button");
  expect_true(er_ui_component_uses_state(button, "disabled"), "component catalog: button has disabled state");
  expect_true(er_ui_component_uses_slot(er_ui_component_find_by_slug("dialog"), "dialog-content"), "component catalog: dialog content slot exists");

  er_ui_component_parity_contract_t contract = {0};
  expect_true(er_ui_component_parity_contract_for_slug("button", &contract), "component parity: button contract exists");
  expect_string(contract.aria_pattern, "button", "component parity: button aria pattern matches");
  expect_true(er_ui_component_contract_supports_variant(&contract, "destructive"), "component parity: button destructive variant exists");
  expect_true(er_ui_component_contract_supports_variant(&contract, "ghost"), "component parity: button ghost variant exists");
  expect_true(er_ui_component_contract_supports_interaction(&contract, "click"), "component parity: button click interaction exists");
  expect_size(contract.keyboard_count, ER_UI_TEST_COMPONENT_KEYBOARD_COUNT, "component parity: button keyboard count matches");

  er_ui_component_resolved_t resolved = {0};
  expect_true(er_ui_component_resolve_identifier("button", &resolved), "component resolve: slug resolves");
  expect_string(resolved.spec->slug, "button", "component resolve: slug result matches");
  expect_true(resolved.kind == ER_UI_COMPONENT_RESOLVE_SLUG, "component resolve: slug kind matches");
  expect_true(er_ui_component_resolve_identifier("Button", &resolved), "component resolve: source component resolves");
  expect_true(resolved.kind == ER_UI_COMPONENT_RESOLVE_SOURCE_COMPONENT, "component resolve: source kind matches");
  expect_true(er_ui_component_resolve_identifier("@/components/ui/input-otp", &resolved), "component resolve: module path resolves");
  expect_true(resolved.kind == ER_UI_COMPONENT_RESOLVE_MODULE_PATH, "component resolve: module path kind matches");
  expect_true(er_ui_component_resolve_identifier("components/ui/card.tsx", &resolved), "component resolve: tsx path resolves");
  expect_string(resolved.spec->slug, "card", "component resolve: tsx path slug matches");
  expect_true(er_ui_component_resolve_identifier("data-slot=\"card-header\"", &resolved), "component resolve: data-slot resolves");
  expect_string(resolved.spec->slug, "card", "component resolve: data-slot slug matches");
  expect_true(er_ui_component_resolve_identifier("CardHeader", &resolved), "component resolve: pascal slot resolves");
  expect_true(resolved.kind == ER_UI_COMPONENT_RESOLVE_SLOT, "component resolve: slot kind matches");
  expect_true(!er_ui_component_resolve_identifier("UnknownThing", &resolved), "component resolve: unknown is rejected");

  er_ui_component_port_mapping_t mapping = {0};
  expect_true(er_ui_component_port_mapping_for_identifier("@/components/ui/button", &mapping), "component mapping: module path maps");
  expect_string(mapping.slug, "button", "component mapping: slug matches");
  expect_string(mapping.source_component, "Button", "component mapping: source component matches");
  expect_string(mapping.edge_builder, "button", "component mapping: edge builder matches");
  expect_true(mapping.category == ER_UI_COMPONENT_CATEGORY_FOUNDATION, "component mapping: category matches");
  expect_true(mapping.status == ER_UI_COMPONENT_STATUS_EXACT_PORT, "component mapping: status matches");
  expect_true(mapping.native_renderer, "component mapping: native renderer true");
  expect_true(mapping.exact_port, "component mapping: exact port true");
  expect_true(!er_ui_component_port_mapping_for_identifier("UnknownThing", &mapping), "component mapping: unknown is rejected");

  expect_true(er_ui_component_preview_available_by_source_component("InputGroup"), "component preview: source component resolves");
  expect_true(er_ui_component_preview_available_by_identifier("@/components/ui/button"), "component preview: module identifier resolves");
  expect_true(er_ui_component_preview_available_by_identifier("CardHeader"), "component preview: slot component resolves");
  expect_true(er_ui_component_preview_available_by_identifier("data-slot=\"dialog-content\""), "component preview: data-slot identifier resolves");
  expect_true(!er_ui_component_preview_available_by_identifier("UnknownThing"), "component preview: unknown identifier is rejected");
  expect_true(er_ui_component_catalog_preview_available("accordion"), "component preview: accordion component exists");
  expect_true(er_ui_component_catalog_preview_available("button"), "component preview: button component exists");
  expect_true(er_ui_component_catalog_preview_available("input-group"), "component preview: input-group component exists");
  expect_true(!er_ui_component_catalog_preview_available("unknown-component"), "component preview: unknown component is rejected");

  er_ui_component_gallery_state_t state = {0};
  er_ui_component_gallery_state_init(&state);
  expect_true(!state.has_open_select, "component preview state: select starts closed");
  expect_size(state.currency_index, 0u, "component preview state: currency default matches Rust");
  expect_size(state.order_index, 0u, "component preview state: order default matches Rust");
  expect_size(state.ticker_index, 0u, "component preview state: ticker default matches Rust");
  expect_size(state.contribution_bar, ER_UI_COMPONENT_CHART_CONTRIBUTION_DEFAULT_INDEX, "component preview state: contribution bar default matches Rust");
  expect_size(state.stock_bar, ER_UI_COMPONENT_CHART_STOCK_DEFAULT_INDEX, "component preview state: stock bar default matches Rust");
  expect_size(state.power_bar, ER_UI_COMPONENT_CHART_POWER_DEFAULT_INDEX, "component preview state: power bar default matches Rust");

  er_ui_action_t action = {0};
  action.kind = ER_UI_ACTION_OPEN_CHANGED;
  action.id = ER_UI_COMPONENT_SELECT_ORDER_TYPE_ID;
  action.bool_value = true;
  expect_true(er_ui_component_gallery_apply_action(&state, action), "component preview state: open select action applies");
  expect_true(er_ui_component_gallery_select_open(&state, ER_UI_COMPONENT_SELECT_ORDER_TYPE_ID), "component preview state: opened select is tracked");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_MENU_ITEM, ER_UI_COMPONENT_SELECT_ORDER_BASE_ID + ER_UI_TEST_COMPONENT_ORDER_OPTION_INDEX, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_true(er_ui_component_gallery_apply_action(&state, action), "component preview state: order option applies");
  expect_size(state.order_index, ER_UI_TEST_COMPONENT_ORDER_OPTION_INDEX, "component preview state: order option index matches");
  expect_true(!state.has_open_select, "component preview state: select closes after menu selection");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_SLIDER_CHANGED;
  action.id = ER_UI_TEST_COMPONENT_SLIDER_ACTION_ID;
  action.float_value = 0.72f;
  expect_true(er_ui_component_gallery_apply_action(&state, action), "component preview state: slider action applies");
  expect_true(er_ui_component_gallery_slider(&state, ER_UI_TEST_COMPONENT_SLIDER_ACTION_ID, 0.0f) > 0.71f,
              "component preview state: slider value is stored");
  action.float_value = 1.2f;
  expect_true(er_ui_component_gallery_apply_action(&state, action), "component preview state: slider clamp action applies");
  expect_true(er_ui_component_gallery_slider(&state, ER_UI_TEST_COMPONENT_SLIDER_ACTION_ID, 0.0f) == 1.0f,
              "component preview state: slider value clamps high");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_COMPONENT_CHART_STOCK_BASE_ID + ER_UI_TEST_COMPONENT_STOCK_BUTTON_INDEX, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_true(er_ui_component_gallery_apply_action(&state, action), "component preview state: chart button applies");
  expect_size(state.stock_bar, ER_UI_TEST_COMPONENT_STOCK_BUTTON_INDEX, "component preview state: stock chart index matches");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_TEST_COMPONENT_UNRELATED_BUTTON_ID, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_true(!er_ui_component_gallery_apply_action(&state, action), "component preview state: unrelated action is rejected");

  expect_size(er_ui_component_native_count(), ER_UI_TEST_COMPONENT_COUNT, "component progress: native count matches Rust source");
  expect_size(er_ui_component_exact_count(), ER_UI_TEST_COMPONENT_COUNT, "component progress: exact count matches Rust source");
  expect_size(er_ui_component_exact_parity_count(), ER_UI_TEST_COMPONENT_COUNT, "component progress: parity count matches Rust source");
  expect_size(er_ui_component_count_by_status(ER_UI_COMPONENT_STATUS_NATIVE_PRIMITIVE), 0u, "component progress: native primitive count matches Rust source");
  expect_true(er_ui_component_count_by_category(ER_UI_COMPONENT_CATEGORY_FOUNDATION) > 0u, "component progress: foundation category populated");
  expect_true(er_ui_component_count_by_category(ER_UI_COMPONENT_CATEGORY_OVERLAY) > 0u, "component progress: overlay category populated");

  size_t component_count = 0u;
  const er_ui_component_test_id_t* component_ids = er_ui_component_test_ids(&component_count);
  expect_true(component_ids != 0, "component contracts: ids are exposed");
  expect_size(component_count, ER_UI_COMPONENT_TEST_ID_COUNT, "component contracts: id count matches Rust source");
  expect_string(er_ui_component_selector(ER_UI_COMPONENT_NETWORK_APP_PROMPT), "edgerun.network_app_prompt",
                "component contracts: network prompt selector matches Rust source");
  expect_string(er_ui_component_name(ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL), "SystemSurfaceStatePanel",
                "component contracts: state panel name matches Rust source");
  expect_string(er_ui_component_state_selector(ER_UI_COMPONENT_STATE_LOADING), "state.loading",
                "component contracts: state selector matches Rust source");
  expect_string(er_ui_component_state_label(ER_UI_COMPONENT_STATE_ERROR), "Error",
                "component contracts: state label matches Rust source");
  expect_string(er_ui_component_a11y_role_label(ER_UI_COMPONENT_A11Y_TAB_LIST), "tab-list",
                "component contracts: a11y role label matches Rust source");

  size_t state_count = 0u;
  const er_ui_component_state_t* states = er_ui_component_states(&state_count);
  expect_true(states != 0, "component contracts: states are exposed");
  expect_size(state_count, ER_UI_COMPONENT_STATE_COUNT, "component contracts: state count matches Rust source");

  er_ui_component_state_matrix_t matrix = {0};
  expect_true(er_ui_component_state_matrix_for(ER_UI_COMPONENT_SEGMENTED_CONTROL, &matrix),
              "component contracts: segmented control state matrix exists");
  expect_size(matrix.state_count, ER_UI_COMPONENT_STATE_COUNT, "component contracts: every component covers full state matrix");
  expect_true(er_ui_component_state_matrix_has_state(&matrix, ER_UI_COMPONENT_STATE_DISABLED),
              "component contracts: disabled state is covered");
  expect_true(er_ui_component_state_matrix_has_state(&matrix, ER_UI_COMPONENT_STATE_ERROR),
              "component contracts: error state is covered");

  er_ui_component_projection_contract_t projection = {0};
  expect_true(er_ui_component_projection_contract_for(ER_UI_COMPONENT_APP_STORE_CARD, &projection),
              "component contracts: app store card projection exists");
  expect_true(er_ui_component_projection_contract_requires_field(&projection, "name"),
              "component contracts: app store card name is required");
  expect_true(er_ui_component_projection_contract_requires_field(&projection, "run_id"),
              "component contracts: app store card run id is required");
  expect_true(er_ui_component_projection_contract_has_field(&projection, "app_policy_hash"),
              "component contracts: app store card policy hash is projected");
  expect_true(!er_ui_component_projection_contract_requires_field(&projection, "developer"),
              "component contracts: app store card developer remains optional");
  expect_size(er_ui_component_projection_required_field_count(&projection), ER_UI_TEST_APP_STORE_CARD_REQUIRED_FIELDS,
              "component contracts: app store card required count matches Rust source");
  expect_true(er_ui_component_projection_contract_for(ER_UI_COMPONENT_DATA_TABLE_CONTROLS, &projection),
              "component contracts: data table controls projection exists");
  expect_true(er_ui_component_projection_contract_requires_field(&projection, "filter_id"),
              "component contracts: data table filter id is required");
  expect_true(er_ui_component_projection_contract_requires_field(&projection, "columns"),
              "component contracts: data table columns are required");

  er_ui_component_accessibility_metadata_t metadata = {0};
  expect_true(er_ui_component_accessibility_metadata_for(ER_UI_COMPONENT_NETWORK_APP_PROMPT, &metadata),
              "component contracts: network prompt accessibility exists");
  expect_true(metadata.role == ER_UI_COMPONENT_A11Y_DIALOG, "component contracts: network prompt is a dialog");
  expect_true(er_ui_component_accessibility_metadata_has_label_field(&metadata, "app_name"),
              "component contracts: network prompt labels by app name");
  expect_true(er_ui_component_accessibility_metadata_for(ER_UI_COMPONENT_SYSTEM_SURFACE_STATE_PANEL, &metadata),
              "component contracts: state panel accessibility exists");
  expect_true(metadata.role == ER_UI_COMPONENT_A11Y_STATUS, "component contracts: state panel is a status");
  expect_true(er_ui_component_accessibility_metadata_has_label_field(&metadata, "detail"),
              "component contracts: state panel detail participates in label");
  expect_true(er_ui_component_accessibility_metadata_for(ER_UI_COMPONENT_ICON_ONLY_BUTTON, &metadata),
              "component contracts: icon-only button accessibility exists");
  expect_true(metadata.role == ER_UI_COMPONENT_A11Y_BUTTON, "component contracts: icon-only button is a button");
  expect_true(er_ui_component_accessibility_metadata_has_label_field(&metadata, "label"),
              "component contracts: icon-only button requires a projected label");

  for (size_t i = 0u; i < er_ui_component_count(); ++i) {
    const er_ui_component_spec_t* spec = er_ui_component_at(i);
    expect_true(spec != 0, "component catalog: indexed spec exists");
    if (!spec) continue;
    expect_true(spec->route && spec->route[0] == '/' && spec->route[1] == 'd', "component catalog: docs route is stable");
    expect_true(spec->edge_builder && spec->edge_builder[0] != '\0', "component catalog: edge builder is present");
    expect_true(spec->source_component && spec->source_component[0] != '\0', "component catalog: source component is present");
    expect_true(er_ui_component_parity_contract_for_slug(spec->slug, &contract), "component parity: every exact component has a contract");
    expect_true(contract.compound == (spec->slot_count > 1u), "component parity: compound flag matches slot count");
    expect_true(er_ui_component_contract_supports_interaction(&contract, "render"), "component parity: every contract renders");
    expect_true(er_ui_component_preview_available(spec->slug), "component preview: every native component has a preview");
    expect_true(er_ui_component_catalog_preview_available(spec->slug), "component preview: every native component has a preview");
  }

  test_component_render_primitives();
}
