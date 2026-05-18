#include "test_common.h"

static void expect_asset_status(er_ui_asset_pack_status_t got, er_ui_asset_pack_status_t expected, const char* name) {
  expect_true(got == expected, name);
}

static void test_bundled_asset_packs_validate(void) {
  er_ui_asset_limits_t limits = er_ui_asset_limits_default();
  er_ui_asset_pack_spec_t tabler = er_ui_tabler_inter_asset_pack();
  er_ui_asset_pack_spec_t lucide = er_ui_lucide_geist_asset_pack();

  expect_asset_status(er_ui_asset_pack_validate(tabler, limits), ER_UI_ASSET_PACK_OK, "assets: bundled Tabler/Inter pack validates");
  expect_asset_status(er_ui_asset_pack_validate(lucide, limits), ER_UI_ASSET_PACK_OK, "assets: bundled Lucide/Geist pack validates");
  expect_string(lucide.name, "edgerun-lucide-geist", "assets: Lucide/Geist pack name");
  expect_string(lucide.fonts.faces[0u].name, "Geist", "assets: bundled Geist face");
  expect_size(tabler.icons.entry_count, (size_t)ER_UI_ICON_COUNT, "assets: bundled icon coverage count");
  expect_size(tabler.components.component_count, (size_t)ER_UI_COMPONENT_KIND_COUNT, "assets: bundled component coverage count");
  expect_string(er_ui_component_kind_label(ER_UI_COMPONENT_KIND_EDGERUN_DOMAIN), "EdgeRun Domain", "assets: component kind label");
}

static void test_icon_pack_rejects_missing_or_mismatched_icons(void) {
  er_ui_asset_limits_t limits = er_ui_asset_limits_default();
  er_ui_asset_pack_spec_t pack = er_ui_tabler_inter_asset_pack();
  er_ui_icon_pack_entry_t mismatched[2u] = {{ER_UI_ICON_ACTIVITY, "activity"}, {ER_UI_ICON_APP, "apps"}};

  pack.icons.entry_count = (size_t)ER_UI_ICON_COUNT - 1u;
  expect_asset_status(er_ui_asset_pack_validate(pack, limits), ER_UI_ASSET_PACK_MISSING_REQUIRED_ICON,
                      "assets: icon pack requires every canonical icon");

  pack = er_ui_tabler_inter_asset_pack();
  pack.icons.provider = ER_UI_ICON_PROVIDER_LUCIDE;
  pack.icons.entries = mismatched;
  pack.icons.entry_count = sizeof(mismatched) / sizeof(mismatched[0u]);
  expect_asset_status(er_ui_icon_pack_validate(pack.icons, limits), ER_UI_ASSET_PACK_ICON_PROVIDER_NAME_MISMATCH,
                      "assets: icon provider names must match selected provider");
}

static void test_font_emoji_and_component_validation(void) {
  er_ui_asset_limits_t limits = er_ui_asset_limits_default();
  er_ui_asset_pack_spec_t pack = er_ui_tabler_inter_asset_pack();
  er_ui_font_face_spec_t bad_font[] = {{"Inter", true, "abc"}};

  pack.fonts.faces = bad_font;
  pack.fonts.face_count = sizeof(bad_font) / sizeof(bad_font[0u]);
  expect_asset_status(er_ui_asset_pack_validate(pack, limits), ER_UI_ASSET_PACK_MISSING_FONT_CHAR,
                      "assets: font pack requires canonical glyph set");

  pack = er_ui_tabler_inter_asset_pack();
  pack.emoji.emoji_count = pack.emoji.emoji_count - 1u;
  expect_asset_status(er_ui_asset_pack_validate(pack, limits), ER_UI_ASSET_PACK_MISSING_REQUIRED_EMOJI,
                      "assets: emoji pack requires semantic emoji");

  pack = er_ui_tabler_inter_asset_pack();
  pack.components.component_count = pack.components.component_count - 1u;
  expect_asset_status(er_ui_asset_pack_validate(pack, limits), ER_UI_ASSET_PACK_MISSING_COMPONENT_KIND,
                      "assets: component pack requires every kind");
}

static void test_asset_pack_runtime_replaces_only_valid_packs(void) {
  er_ui_asset_pack_runtime_t runtime = {0};
  er_ui_asset_pack_spec_t tabler = er_ui_tabler_inter_asset_pack();
  er_ui_asset_pack_spec_t lucide = er_ui_lucide_geist_asset_pack();
  er_ui_asset_pack_spec_t invalid = lucide;

  expect_asset_status(er_ui_asset_pack_runtime_init(&runtime, tabler, er_ui_asset_limits_default()), ER_UI_ASSET_PACK_OK,
                      "assets: runtime accepts valid initial pack");
  expect_string(runtime.active.name, "edgerun-tabler-inter", "assets: runtime active initial pack");

  expect_asset_status(er_ui_asset_pack_runtime_replace(&runtime, lucide), ER_UI_ASSET_PACK_OK,
                      "assets: runtime accepts valid replacement pack");
  expect_string(runtime.active.name, "edgerun-lucide-geist", "assets: runtime active replacement pack");

  invalid.icons.entry_count = invalid.icons.entry_count - 1u;
  expect_asset_status(er_ui_asset_pack_runtime_replace(&runtime, invalid), ER_UI_ASSET_PACK_MISSING_REQUIRED_ICON,
                      "assets: runtime rejects invalid replacement pack");
  expect_string(runtime.active.name, "edgerun-lucide-geist", "assets: runtime preserves active pack after rejected replacement");
}

void run_asset_tests(void) {
  test_bundled_asset_packs_validate();
  test_icon_pack_rejects_missing_or_mismatched_icons();
  test_font_emoji_and_component_validation();
  test_asset_pack_runtime_replaces_only_valid_packs();
}
