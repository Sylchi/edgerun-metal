#include "test_common.h"

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
  }
}
