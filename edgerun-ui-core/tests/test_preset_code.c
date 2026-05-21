#include "test_common.h"

#define ER_UI_TEST_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define ER_UI_TEST_STYLE_FAMILY_COUNT 7u
#define ER_UI_TEST_STYLE_TOKEN_COUNT 27u
#define ER_UI_TEST_FIRST_INDEX 0u
#define ER_UI_TEST_SERA_INDEX 6u
#define ER_UI_TEST_DESTRUCTIVE_TOKEN_INDEX 15u
#define ER_UI_TEST_CHART_FIVE_TOKEN_INDEX 26u

typedef struct {
  er_ui_style_family_t family;
  const char* code;
} er_ui_test_family_code_t;

static void expect_preset_status(er_ui_status_t got, er_ui_status_t expected, const char* name) {
  expect_true(got == expected, name);
}

static void test_preset_codes_encode_captured_families(void) {
  const er_ui_test_family_code_t expected[] = {
    {ER_UI_STYLE_FAMILY_VEGA, "bIkeymG"},
    {ER_UI_STYLE_FAMILY_NOVA, "b2fA"},
    {ER_UI_STYLE_FAMILY_MAIA, "bbVKFP6"},
    {ER_UI_STYLE_FAMILY_LYRA, "buFznsW"},
    {ER_UI_STYLE_FAMILY_MIRA, "b1D0eCA4"},
    {ER_UI_STYLE_FAMILY_LUMA, "b1VlIttI"},
    {ER_UI_STYLE_FAMILY_SERA, "b4xFeBLg4O"}
  };
  char code[ER_UI_PRESET_CODE_MAX_LEN];
  size_t len = 0u;
  for (size_t i = 0u; i < ER_UI_TEST_ARRAY_COUNT(expected); ++i) {
    er_ui_preset_recipe_t recipe = er_ui_preset_recipe_for_style_family(expected[i].family);
    expect_preset_status(er_ui_preset_encode(recipe, code, sizeof(code), &len), ER_UI_OK, "preset code: family encodes");
    expect_string(code, expected[i].code, "preset code: captured code matches Rust");
    expect_true(er_ui_preset_recipe_matches_code(recipe, expected[i].code), "preset code: recipe matches encoded value");
  }
}

static void test_preset_code_decodes_sera_and_validates_shape(void) {
  er_ui_preset_recipe_t recipe = {0};
  expect_preset_status(er_ui_preset_decode("b4xFeBLg4O", &recipe), ER_UI_OK, "preset code: Sera decodes");
  expect_string(recipe.style, "sera", "preset code: Sera style");
  expect_string(recipe.base_color, "taupe", "preset code: Sera base color");
  expect_string(recipe.theme, "taupe", "preset code: Sera theme");
  expect_string(recipe.chart_color, "taupe", "preset code: Sera chart color");
  expect_string(recipe.font, "noto-sans", "preset code: Sera font");
  expect_string(recipe.font_heading, "playfair-display", "preset code: Sera heading font");
  expect_string(recipe.encoded_radius, "default", "preset code: Sera encoded radius");
  expect_string(recipe.effective_radius, "none", "preset code: Sera effective radius");
  expect_true(er_ui_preset_is_code("b4xFeBLg4O"), "preset code: valid b code is accepted");
  expect_true(!er_ui_preset_is_code("a123"), "preset code: noncanonical prefix rejected");
  expect_true(!er_ui_preset_is_code("b4xFeBLg4O!"), "preset code: punctuation rejected");
  expect_preset_status(er_ui_preset_decode("a123", &recipe), ER_UI_ERR_INVALID_ARGUMENT, "preset code: decode requires b prefix");
}

static void test_preset_code_encodes_live_sera_deltas(void) {
  char code[ER_UI_PRESET_CODE_MAX_LEN];
  size_t len = 0u;
  er_ui_preset_recipe_t sera = er_ui_preset_recipe_for_style_family(ER_UI_STYLE_FAMILY_SERA);
  er_ui_preset_recipe_t neutral = sera;
  neutral.base_color = "neutral";
  neutral.theme = "neutral";
  neutral.chart_color = "neutral";
  expect_preset_status(er_ui_preset_encode(neutral, code, sizeof(code), &len), ER_UI_OK, "preset code: neutral Sera delta encodes");
  expect_string(code, "b4pl227H7Y", "preset code: neutral Sera delta");
  er_ui_preset_recipe_t heading = sera;
  heading.font_heading = "inter";
  expect_preset_status(er_ui_preset_encode(heading, code, sizeof(code), &len), ER_UI_OK, "preset code: heading delta encodes");
  expect_string(code, "bRVJIXa1w", "preset code: heading delta");
  er_ui_preset_recipe_t font = sera;
  font.font = "inter";
  expect_preset_status(er_ui_preset_encode(font, code, sizeof(code), &len), ER_UI_OK, "preset code: font delta encodes");
  expect_string(code, "b4xFeBLfns", "preset code: font delta");
  er_ui_preset_recipe_t icon = sera;
  icon.icon_library = "hugeicons";
  expect_preset_status(er_ui_preset_encode(icon, code, sizeof(code), &len), ER_UI_OK, "preset code: icon delta encodes");
  expect_string(code, "b4xFeBLx7Q", "preset code: icon delta");
  er_ui_preset_recipe_t accent = sera;
  accent.menu_accent = "bold";
  expect_preset_status(er_ui_preset_encode(accent, code, sizeof(code), &len), ER_UI_OK, "preset code: accent delta encodes");
  expect_string(code, "b4xFeBLg4W", "preset code: accent delta");
}

static void test_source_captures_preserve_provenance(void) {
  expect_size(er_ui_extracted_source_capture_count(), ER_UI_TEST_STYLE_FAMILY_COUNT, "source captures: count");
  const er_ui_extracted_source_capture_t* first = er_ui_extracted_source_capture_at(ER_UI_TEST_FIRST_INDEX);
  expect_true(first != 0, "source captures: first exists");
  expect_string(first->path, "ui.html", "source captures: first path");
  expect_true(first->has_style_family && first->style_family == ER_UI_STYLE_FAMILY_MIRA, "source captures: first family");
  expect_string(first->preset_code, "b1D0eCA4", "source captures: first preset code");
  const er_ui_extracted_source_capture_t* sera = er_ui_extracted_source_capture_at(ER_UI_TEST_SERA_INDEX);
  expect_true(sera != 0, "source captures: Sera exists");
  expect_string(sera->path, "sera.html", "source captures: Sera path");
  expect_string(sera->project_slug, "radix-sera", "source captures: Sera slug");
  expect_string(sera->preset_recipe.base_color, "taupe", "source captures: Sera recipe base color");
  expect_true(er_ui_extracted_source_capture_at(ER_UI_TEST_STYLE_FAMILY_COUNT) == 0, "source captures: out of range is null");
}

static void test_style_family_specs_and_colors(void) {
  expect_size(er_ui_style_family_spec_count(), ER_UI_TEST_STYLE_FAMILY_COUNT, "style family: spec count");
  const er_ui_style_family_spec_t* vega = er_ui_style_family_spec_for_family(ER_UI_STYLE_FAMILY_VEGA);
  expect_true(vega != 0, "style family: Vega spec exists");
  expect_string(vega->name, "Vega", "style family: Vega name");
  expect_string(vega->preset_code, "bIkeymG", "style family: Vega preset code");
  expect_string(vega->role, "structured blue-black system surface", "style family: Vega role");
  const er_ui_style_family_spec_t* sera = er_ui_style_family_spec_at(ER_UI_TEST_SERA_INDEX);
  expect_true(sera != 0 && sera->family == ER_UI_STYLE_FAMILY_SERA, "style family: Sera spec by index");
  expect_string(sera->base_color, "taupe", "style family: Sera base color");
  er_ui_semantic_colors_t colors = er_ui_colors_for_style_family(ER_UI_STYLE_FAMILY_SERA);
  expect_float(colors.bg.r, 0.047f, "style family: Sera bg red");
  expect_float(colors.text.g, 0.981f, "style family: Sera text green");
  expect_float(colors.border.a, 0.1f, "style family: Sera border alpha");
  colors = er_ui_colors_for_style_family(ER_UI_STYLE_FAMILY_MAIA);
  expect_float(colors.accent.g, 0.74f, "style family: Maia accent green");
  expect_true(er_ui_style_family_spec_for_family(ER_UI_STYLE_FAMILY_COUNT) == 0, "style family: invalid spec is null");
}

static void test_extracted_style_tokens_preserve_classes_and_roles(void) {
  expect_size(er_ui_extracted_style_token_count(), ER_UI_TEST_STYLE_TOKEN_COUNT, "style tokens: count");
  expect_string(er_ui_extracted_style_token_kind_label(ER_UI_EXTRACTED_STYLE_TOKEN_ACTION), "Action", "style tokens: kind label");
  const er_ui_extracted_style_token_t* background = er_ui_extracted_style_token_at(ER_UI_TEST_FIRST_INDEX);
  expect_true(background != 0, "style tokens: background exists");
  expect_string(background->name, "background", "style tokens: background name");
  expect_string(background->css_var, "--background", "style tokens: background css var");
  expect_true(background->kind == ER_UI_EXTRACTED_STYLE_TOKEN_SURFACE, "style tokens: background kind");
  expect_true(er_ui_extracted_style_token_has_class(background, "bg-background"), "style tokens: background primary class");
  expect_true(er_ui_extracted_style_token_has_class(background, "bg-bg"), "style tokens: background alias class");
  expect_true(!er_ui_extracted_style_token_has_class(background, "text-muted"), "style tokens: background rejects unrelated class");

  const er_ui_extracted_style_token_t* destructive = er_ui_extracted_style_token_at(ER_UI_TEST_DESTRUCTIVE_TOKEN_INDEX);
  expect_true(destructive != 0, "style tokens: destructive exists");
  expect_string(destructive->css_var, "--destructive", "style tokens: destructive css var");
  expect_true(destructive->kind == ER_UI_EXTRACTED_STYLE_TOKEN_STATUS, "style tokens: destructive kind");
  expect_true(er_ui_extracted_style_token_has_class(destructive, "aria-invalid:border-destructive"), "style tokens: destructive aria class");

  const er_ui_extracted_style_token_t* chart = er_ui_extracted_style_token_at(ER_UI_TEST_CHART_FIVE_TOKEN_INDEX);
  expect_true(chart != 0, "style tokens: chart five exists");
  expect_string(chart->name, "chart 5", "style tokens: chart five name");
  expect_true(er_ui_extracted_style_token_has_class(chart, "text-chart-5"), "style tokens: chart five text class");
  expect_true(er_ui_extracted_style_token_at(ER_UI_TEST_STYLE_TOKEN_COUNT) == 0, "style tokens: out of range is null");
}

void run_preset_code_tests(void) {
  test_preset_codes_encode_captured_families();
  test_preset_code_decodes_sera_and_validates_shape();
  test_preset_code_encodes_live_sera_deltas();
  test_source_captures_preserve_provenance();
  test_style_family_specs_and_colors();
  test_extracted_style_tokens_preserve_classes_and_roles();
}
