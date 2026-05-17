#include "test_common.h"

static void test_shadcn_render_primitives(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_palette_slate_950(), er_ui_test_allocator()), ER_UI_OK,
                "shadcn render: scene init succeeds");

  vr_font_face_t* face =
      er_ui_test_open_font(14.0f, "shadcn render: bundled variable font loads", "shadcn render: variable font opens from memory");
  if (!face) {
    er_ui_scene_destroy(&scene);
    return;
  }

  er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
  expect_status(er_ui_shadcn_card_emit(&scene, er_ui_bounds(4.0f, 4.0f, 220.0f, 156.0f), theme), ER_UI_OK,
                "shadcn render: card emits");
  expect_status(er_ui_shadcn_button_emit(&scene, face, er_ui_bounds(16.0f, 16.0f, 128.0f, 48.0f), theme, "Deploy", 3001u,
                                         ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true),
                ER_UI_OK, "shadcn render: button emits");
  expect_status(er_ui_shadcn_select_emit(&scene, face, er_ui_bounds(16.0f, 66.0f, 188.0f, 62.0f), theme, "Currency", "USD", 3002u, true),
                ER_UI_OK, "shadcn render: select emits");
  expect_status(er_ui_shadcn_slider_emit(&scene, face, er_ui_bounds(16.0f, 126.0f, 188.0f, 48.0f), theme, "Minimum payout", 0.42f, 3003u),
                ER_UI_OK, "shadcn render: slider emits");
  expect_status(er_ui_shadcn_badge_emit(&scene, face, er_ui_bounds(232.0f, 16.0f, 88.0f, 26.0f), theme, "Active",
                                        ER_UI_SHADCN_BADGE_SECONDARY),
                ER_UI_OK, "shadcn render: badge emits");
  expect_status(er_ui_shadcn_field_emit(&scene, face, er_ui_bounds(232.0f, 48.0f, 160.0f, 58.0f), theme, "Name", "EdgeRun", 3004u, false),
                ER_UI_OK, "shadcn render: field emits");
  expect_status(er_ui_shadcn_field_emit(&scene, face, er_ui_bounds(232.0f, 110.0f, 160.0f, 86.0f), theme, "Notes", "Verified cache", 3005u, true),
                ER_UI_OK, "shadcn render: textarea emits");
  expect_status(er_ui_shadcn_checkbox_emit(&scene, face, er_ui_bounds(16.0f, 180.0f, 188.0f, 32.0f), theme, "Cache verified bytes", true, 3006u),
                ER_UI_OK, "shadcn render: checkbox emits");
  expect_status(er_ui_shadcn_progress_emit(&scene, er_ui_bounds(232.0f, 204.0f, 160.0f, 8.0f), theme, 0.64f), ER_UI_OK,
                "shadcn render: progress emits");
  expect_status(er_ui_shadcn_switch_emit(&scene, er_ui_bounds(16.0f, 220.0f, 44.0f, 24.0f), theme, true, 3007u), ER_UI_OK,
                "shadcn render: switch emits");
  expect_status(er_ui_shadcn_separator_emit(&scene, er_ui_bounds(72.0f, 231.0f, 132.0f, 1.0f), theme), ER_UI_OK,
                "shadcn render: separator emits");
  const char* const tabs[] = {"Preview", "Code", "A11y"};
  expect_status(er_ui_shadcn_tabs_emit(&scene, face, er_ui_bounds(232.0f, 224.0f, 180.0f, 38.0f), theme, tabs, 3u, 1u, 3010u), ER_UI_OK,
                "shadcn render: tabs emit");
  expect_status(er_ui_shadcn_list_row_emit(&scene, face, er_ui_bounds(420.0f, 148.0f, 180.0f, 48.0f), theme, "Billing", "Command B", 3013u, true),
                ER_UI_OK, "shadcn render: list row emits");
  expect_status(er_ui_shadcn_radio_emit(&scene, face, er_ui_bounds(420.0f, 202.0f, 180.0f, 30.0f), theme, "Default", true, 3014u),
                ER_UI_OK, "shadcn render: radio emits");
  const char* const headers[] = {"Invoice", "Status"};
  const char* const cells[] = {"INV001", "Paid", "INV002", "Pending"};
  expect_status(er_ui_shadcn_table_emit(&scene, face, er_ui_bounds(420.0f, 238.0f, 180.0f, 96.0f), theme, headers, 2u, cells, 2u, 3015u),
                ER_UI_OK, "shadcn render: table emits");
  expect_status(er_ui_shadcn_skeleton_emit(&scene, er_ui_bounds(420.0f, 340.0f, 120.0f, 16.0f), theme), ER_UI_OK,
                "shadcn render: skeleton emits");
  expect_status(er_ui_shadcn_toast_emit(&scene, face, er_ui_bounds(420.0f, 362.0f, 180.0f, 44.0f), theme, "Scheduled", theme.colors.accent), ER_UI_OK,
                "shadcn render: toast emits");
  expect_status(er_ui_shadcn_empty_emit(&scene, face, er_ui_bounds(420.0f, 412.0f, 180.0f, 110.0f), theme, "No results", "Try another filter"), ER_UI_OK,
                "shadcn render: empty emits");
  expect_status(er_ui_shadcn_alert_emit(&scene, face, er_ui_bounds(606.0f, 16.0f, 220.0f, 72.0f), theme, "Heads up", "Reusable components", theme.colors.warning),
                ER_UI_OK, "shadcn render: alert emits");
  expect_status(er_ui_shadcn_avatar_emit(&scene, face, er_ui_bounds(606.0f, 96.0f, 42.0f, 42.0f), theme, "ER", theme.colors.accent, true),
                ER_UI_OK, "shadcn render: avatar emits");
  const char* const crumbs[] = {"Docs", "Components", "Breadcrumb"};
  expect_status(er_ui_shadcn_breadcrumb_emit(&scene, face, er_ui_bounds(606.0f, 146.0f, 220.0f, 32.0f), theme, crumbs, 3u, 2u, 3020u),
                ER_UI_OK, "shadcn render: breadcrumb emits");
  const char* const chart_labels[] = {"Jan", "Feb", "Mar"};
  const float chart_values[] = {0.4f, 0.8f, 0.6f};
  expect_status(er_ui_shadcn_bar_chart_emit(&scene, face, er_ui_bounds(606.0f, 186.0f, 180.0f, 120.0f), theme, "Visitors", chart_labels, chart_values, 3u, 3024u, 1u),
                ER_UI_OK, "shadcn render: bar chart emits");
  expect_true(scene.rect_count >= 8u, "shadcn render: primitives emit geometry");
  expect_true(scene.hit_count >= 10u, "shadcn render: interactive primitives emit hits");
  expect_true(scene.text_quad_count > 0u, "shadcn render: primitives use variable font text");
  expect_status(er_ui_shadcn_button_emit(&scene, NULL, er_ui_bounds(0.0f, 0.0f, 40.0f, 40.0f), theme, "Nope", 9u,
                                         ER_UI_SHADCN_BUTTON_DEFAULT, ER_UI_SHADCN_BUTTON_SIZE_DEFAULT, true),
                ER_UI_ERR_INVALID_ARGUMENT, "shadcn render: missing variable font is rejected");
  expect_true(er_ui_shadcn_component_scene_preview_available("button"), "shadcn scene preview: button is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("accordion"), "shadcn scene preview: accordion is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("alert-dialog"), "shadcn scene preview: alert dialog is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("avatar"), "shadcn scene preview: avatar is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("chart"), "shadcn scene preview: chart is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("combobox"), "shadcn scene preview: combobox is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("label"), "shadcn scene preview: label is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("sheet"), "shadcn scene preview: sheet is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("tabs"), "shadcn scene preview: tabs are available");
  expect_true(er_ui_shadcn_component_scene_preview_available("data-table"), "shadcn scene preview: data table is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("radio-group"), "shadcn scene preview: radio group is available");
  expect_true(er_ui_shadcn_component_scene_preview_available("toast"), "shadcn scene preview: toast is available");
  expect_true(!er_ui_shadcn_component_scene_preview_available("unknown-demo"), "shadcn scene preview: unknown body is not claimed");
  expect_status(er_ui_shadcn_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 16.0f, 180.0f, 58.0f), theme, "button", NULL),
                ER_UI_OK, "shadcn scene preview: selected body emits");
  expect_status(er_ui_shadcn_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 530.0f, 220.0f, 112.0f), theme, "data-table", NULL),
                ER_UI_OK, "shadcn scene preview: table body emits");
  expect_status(er_ui_shadcn_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 646.0f, 240.0f, 132.0f), theme, "calendar", NULL),
                ER_UI_OK, "shadcn scene preview: calendar body emits");
  expect_status(er_ui_shadcn_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 82.0f, 180.0f, 58.0f), theme, "accordion", NULL),
                ER_UI_OK, "shadcn scene preview: accordion body emits");
  expect_status(er_ui_shadcn_component_scene_preview_emit(&scene, face, er_ui_bounds(420.0f, 782.0f, 180.0f, 58.0f), theme, "unknown-demo", NULL),
                ER_UI_ERR_INVALID_ARGUMENT, "shadcn scene preview: unknown body is rejected");
  er_ui_shadcn_demo_gallery_state_t state = {0};
  er_ui_shadcn_demo_gallery_state_init(&state);
  expect_status(er_ui_shadcn_showcase_emit(&scene, face, er_ui_bounds(0.0f, 280.0f, 720.0f, 360.0f), theme, "button", &state), ER_UI_OK,
                "shadcn showcase: component reference emits");
  expect_true(scene.hit_count >= 20u, "shadcn showcase: catalog rows and preview controls emit hits");
  expect_true(scene.text_quad_count > 20u, "shadcn showcase: catalog and preview use variable font text");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_edgerun_metal_surface_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 3840.0f, 2160.0f), theme, &state), ER_UI_OK,
                "metal surface: ui-core owns boot scene composition");
  expect_true(scene.hit_count >= 20u, "metal surface: showcase and controls emit hits");
  expect_true(scene.text_quad_count > 80u, "metal surface: boot UI emits variable font text");
  expect_true(er_ui_scene_stats_fits_budget(er_ui_scene_stats(&scene), er_ui_scene_budget_native_interactive_frame()),
              "metal surface: boot scene fits native frame budget");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_edgerun_metal_surface_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 1920.0f, 1080.0f), theme, &state), ER_UI_OK,
                "metal surface: qemu 1080p scene emits");
  expect_true(scene.hit_count >= 20u, "metal surface: qemu 1080p controls emit hits");
  expect_true(er_ui_scene_stats_fits_budget(er_ui_scene_stats(&scene), er_ui_scene_budget_native_interactive_frame()),
              "metal surface: qemu 1080p scene fits native frame budget");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_edgerun_metal_surface_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 1280.0f, 720.0f), theme, &state), ER_UI_OK,
                "metal surface: qemu 720p scene emits");
  expect_true(scene.hit_count >= 20u, "metal surface: qemu 720p controls emit hits");
  expect_true(scene.icon_quad_count >= 6u, "metal surface: qemu 720p icon nodes emit quads");
  expect_true(er_ui_scene_stats_fits_budget(er_ui_scene_stats(&scene), er_ui_scene_budget_native_interactive_frame()),
              "metal surface: qemu 720p scene fits native frame budget");

  for (size_t i = 0u; i < er_ui_shadcn_demo_count(); ++i) {
    const er_ui_shadcn_demo_spec_t* spec = er_ui_shadcn_demo_at(i);
    expect_true(spec != NULL, "shadcn scene preview: indexed spec exists");
    if (!spec) continue;
    expect_true(er_ui_shadcn_component_scene_preview_available(spec->slug), "shadcn scene preview: every catalog component is claimed");
    expect_status(er_ui_shadcn_component_scene_preview_emit(&scene, face, er_ui_bounds(8.0f, 860.0f, 360.0f, 190.0f), theme, spec->slug, &state), ER_UI_OK,
                  "shadcn scene preview: every catalog component emits");
  }

  vr_font_face_destroy(face);
  er_ui_scene_destroy(&scene);
}

void run_component_tests(void) {
  expect_size(er_ui_shadcn_demo_count(), 57u, "shadcn catalog: component count matches Rust source");
  expect_true(er_ui_shadcn_find_demo_by_slug("accordion") != 0, "shadcn catalog: accordion exists");
  expect_true(er_ui_shadcn_find_demo_by_slug("tooltip") != 0, "shadcn catalog: tooltip exists");
  expect_true(er_ui_shadcn_find_demo_by_slug("data-table") != 0, "shadcn catalog: data-table exists");
  expect_true(er_ui_shadcn_find_demo_by_slug("input-otp") != 0, "shadcn catalog: input-otp exists");

  const er_ui_shadcn_demo_spec_t* input_group = er_ui_shadcn_find_demo_by_source_component("InputGroup");
  expect_true(input_group != 0, "shadcn catalog: InputGroup resolves by source component");
  if (input_group) expect_string(input_group->slug, "input-group", "shadcn catalog: InputGroup slug matches");
  const er_ui_shadcn_demo_spec_t* button = er_ui_shadcn_find_demo_by_slug("button");
  expect_true(er_ui_shadcn_demo_uses_state(button, "disabled"), "shadcn catalog: button has disabled state");
  expect_true(er_ui_shadcn_demo_uses_slot(er_ui_shadcn_find_demo_by_slug("dialog"), "dialog-content"), "shadcn catalog: dialog content slot exists");

  er_ui_shadcn_parity_contract_t contract = {0};
  expect_true(er_ui_shadcn_parity_contract_for_slug("button", &contract), "shadcn parity: button contract exists");
  expect_string(contract.aria_pattern, "button", "shadcn parity: button aria pattern matches");
  expect_true(er_ui_shadcn_contract_supports_variant(&contract, "destructive"), "shadcn parity: button destructive variant exists");
  expect_true(er_ui_shadcn_contract_supports_variant(&contract, "ghost"), "shadcn parity: button ghost variant exists");
  expect_true(er_ui_shadcn_contract_supports_interaction(&contract, "click"), "shadcn parity: button click interaction exists");
  expect_size(contract.keyboard_count, 2u, "shadcn parity: button keyboard count matches");

  er_ui_shadcn_resolved_demo_t resolved = {0};
  expect_true(er_ui_shadcn_resolve_demo_identifier("button", &resolved), "shadcn resolve: slug resolves");
  expect_string(resolved.spec->slug, "button", "shadcn resolve: slug result matches");
  expect_true(resolved.kind == ER_UI_SHADCN_RESOLVE_SLUG, "shadcn resolve: slug kind matches");
  expect_true(er_ui_shadcn_resolve_demo_identifier("Button", &resolved), "shadcn resolve: source component resolves");
  expect_true(resolved.kind == ER_UI_SHADCN_RESOLVE_SOURCE_COMPONENT, "shadcn resolve: source kind matches");
  expect_true(er_ui_shadcn_resolve_demo_identifier("@/components/ui/input-otp", &resolved), "shadcn resolve: module path resolves");
  expect_true(resolved.kind == ER_UI_SHADCN_RESOLVE_MODULE_PATH, "shadcn resolve: module path kind matches");
  expect_true(er_ui_shadcn_resolve_demo_identifier("components/ui/card.tsx", &resolved), "shadcn resolve: tsx path resolves");
  expect_string(resolved.spec->slug, "card", "shadcn resolve: tsx path slug matches");
  expect_true(er_ui_shadcn_resolve_demo_identifier("data-slot=\"card-header\"", &resolved), "shadcn resolve: data-slot resolves");
  expect_string(resolved.spec->slug, "card", "shadcn resolve: data-slot slug matches");
  expect_true(er_ui_shadcn_resolve_demo_identifier("CardHeader", &resolved), "shadcn resolve: pascal slot resolves");
  expect_true(resolved.kind == ER_UI_SHADCN_RESOLVE_SLOT, "shadcn resolve: slot kind matches");
  expect_true(!er_ui_shadcn_resolve_demo_identifier("UnknownThing", &resolved), "shadcn resolve: unknown is rejected");

  er_ui_shadcn_port_mapping_t mapping = {0};
  expect_true(er_ui_shadcn_port_mapping_for_identifier("@/components/ui/button", &mapping), "shadcn mapping: module path maps");
  expect_string(mapping.slug, "button", "shadcn mapping: slug matches");
  expect_string(mapping.source_component, "Button", "shadcn mapping: source component matches");
  expect_string(mapping.edge_builder, "button", "shadcn mapping: edge builder matches");
  expect_true(mapping.category == ER_UI_SHADCN_CATEGORY_FOUNDATION, "shadcn mapping: category matches");
  expect_true(mapping.status == ER_UI_SHADCN_STATUS_EXACT_PORT, "shadcn mapping: status matches");
  expect_true(mapping.native_renderer, "shadcn mapping: native renderer true");
  expect_true(mapping.exact_port, "shadcn mapping: exact port true");
  expect_true(!er_ui_shadcn_port_mapping_for_identifier("UnknownThing", &mapping), "shadcn mapping: unknown is rejected");

  expect_true(er_ui_shadcn_component_preview_available_by_source_component("InputGroup"), "shadcn preview: source component resolves");
  expect_true(er_ui_shadcn_component_preview_available_by_identifier("@/components/ui/button"), "shadcn preview: module identifier resolves");
  expect_true(er_ui_shadcn_component_preview_available_by_identifier("CardHeader"), "shadcn preview: slot component resolves");
  expect_true(er_ui_shadcn_component_preview_available_by_identifier("data-slot=\"dialog-content\""), "shadcn preview: data-slot identifier resolves");
  expect_true(!er_ui_shadcn_component_preview_available_by_identifier("UnknownThing"), "shadcn preview: unknown identifier is rejected");
  expect_true(er_ui_shadcn_demo_preview_available("accordion"), "shadcn preview: accordion demo exists");
  expect_true(er_ui_shadcn_demo_preview_available("button"), "shadcn preview: button demo exists");
  expect_true(er_ui_shadcn_demo_preview_available("input-group"), "shadcn preview: input-group demo exists");
  expect_true(!er_ui_shadcn_demo_preview_available("unknown-demo"), "shadcn preview: unknown demo is rejected");

  er_ui_shadcn_demo_gallery_state_t state = {0};
  er_ui_shadcn_demo_gallery_state_init(&state);
  expect_true(!state.has_open_select, "shadcn preview state: select starts closed");
  expect_size(state.currency_index, 0u, "shadcn preview state: currency default matches Rust");
  expect_size(state.order_index, 0u, "shadcn preview state: order default matches Rust");
  expect_size(state.ticker_index, 0u, "shadcn preview state: ticker default matches Rust");
  expect_size(state.contribution_bar, 5u, "shadcn preview state: contribution bar default matches Rust");
  expect_size(state.stock_bar, 5u, "shadcn preview state: stock bar default matches Rust");
  expect_size(state.power_bar, 6u, "shadcn preview state: power bar default matches Rust");

  er_ui_action_t action = {0};
  action.kind = ER_UI_ACTION_OPEN_CHANGED;
  action.id = ER_UI_SHADCN_SELECT_ORDER_TYPE_ID;
  action.bool_value = true;
  expect_true(er_ui_shadcn_demo_gallery_apply_action(&state, action), "shadcn preview state: open select action applies");
  expect_true(er_ui_shadcn_demo_gallery_select_open(&state, ER_UI_SHADCN_SELECT_ORDER_TYPE_ID), "shadcn preview state: opened select is tracked");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_MENU_ITEM, ER_UI_SHADCN_SELECT_ORDER_BASE_ID + 1u, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_true(er_ui_shadcn_demo_gallery_apply_action(&state, action), "shadcn preview state: order option applies");
  expect_size(state.order_index, 1u, "shadcn preview state: order option index matches");
  expect_true(!state.has_open_select, "shadcn preview state: select closes after menu selection");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_SLIDER_CHANGED;
  action.id = ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 943u;
  action.float_value = 0.72f;
  expect_true(er_ui_shadcn_demo_gallery_apply_action(&state, action), "shadcn preview state: slider action applies");
  expect_true(er_ui_shadcn_demo_gallery_slider(&state, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 943u, 0.0f) > 0.71f, "shadcn preview state: slider value is stored");
  action.float_value = 1.2f;
  expect_true(er_ui_shadcn_demo_gallery_apply_action(&state, action), "shadcn preview state: slider clamp action applies");
  expect_true(er_ui_shadcn_demo_gallery_slider(&state, ER_UI_SHADCN_DEMO_PREVIEW_BASE_ID + 943u, 0.0f) == 1.0f, "shadcn preview state: slider value clamps high");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_SHADCN_CHART_STOCK_BASE_ID + 2u, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_true(er_ui_shadcn_demo_gallery_apply_action(&state, action), "shadcn preview state: chart button applies");
  expect_size(state.stock_bar, 2u, "shadcn preview state: stock chart index matches");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_BUTTON, 42u, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_true(!er_ui_shadcn_demo_gallery_apply_action(&state, action), "shadcn preview state: unrelated action is rejected");

  expect_size(er_ui_shadcn_native_demo_count(), 57u, "shadcn progress: native count matches Rust source");
  expect_size(er_ui_shadcn_exact_demo_count(), 57u, "shadcn progress: exact count matches Rust source");
  expect_size(er_ui_shadcn_exact_parity_count(), 57u, "shadcn progress: parity count matches Rust source");
  expect_size(er_ui_shadcn_count_by_status(ER_UI_SHADCN_STATUS_NATIVE_PRIMITIVE), 0u, "shadcn progress: native primitive count matches Rust source");
  expect_true(er_ui_shadcn_count_by_category(ER_UI_SHADCN_CATEGORY_FOUNDATION) > 0u, "shadcn progress: foundation category populated");
  expect_true(er_ui_shadcn_count_by_category(ER_UI_SHADCN_CATEGORY_OVERLAY) > 0u, "shadcn progress: overlay category populated");

  for (size_t i = 0u; i < er_ui_shadcn_demo_count(); ++i) {
    const er_ui_shadcn_demo_spec_t* spec = er_ui_shadcn_demo_at(i);
    expect_true(spec != 0, "shadcn catalog: indexed spec exists");
    if (!spec) continue;
    expect_true(spec->route && spec->route[0] == '/' && spec->route[1] == 'd', "shadcn catalog: docs route is stable");
    expect_true(spec->edge_builder && spec->edge_builder[0] != '\0', "shadcn catalog: edge builder is present");
    expect_true(spec->source_component && spec->source_component[0] != '\0', "shadcn catalog: source component is present");
    expect_true(er_ui_shadcn_parity_contract_for_slug(spec->slug, &contract), "shadcn parity: every exact component has a contract");
    expect_true(contract.compound == (spec->slot_count > 1u), "shadcn parity: compound flag matches slot count");
    expect_true(er_ui_shadcn_contract_supports_interaction(&contract, "render"), "shadcn parity: every contract renders");
    expect_true(er_ui_shadcn_component_preview_available(spec->slug), "shadcn preview: every native component has a preview");
    expect_true(er_ui_shadcn_demo_preview_available(spec->slug), "shadcn preview: every native demo has a preview");
  }

  test_shadcn_render_primitives();
}
