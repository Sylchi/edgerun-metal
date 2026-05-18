#include "test_common.h"

#include <stddef.h>
#include <stdint.h>

#define ER_TEST_TEXT_EDGE_LEN 4u

static const er_ui_color4_t ER_TEST_TEXT_COLOR = {0.94f, 0.96f, 0.99f, 1.0f};
static const er_ui_color4_t ER_TEST_TEXT_BG = {0.01f, 0.012f, 0.015f, 1.0f};
static const size_t ER_TEST_TEXT_PARTIAL_VERTEX_COUNT = 2u;
static const uint32_t ER_TEST_TEXT_PARTIAL_ATLAS_ID = 7u;
static const size_t ER_TEST_TEXT_UNDERSIZED_BUDGET = 3u;

static void test_text_measure_empty_and_rejects_invalid_inputs(void) {
  vr_font_face_t* face = er_ui_test_open_font(24.0f, "text measure: bundled font bytes load", "text measure: font opens");
  if (!face) return;

  er_ui_varfont_text_metrics_t metrics = {0};
  expect_status(er_ui_varfont_measure_text(face, NULL, 0u, &metrics), ER_UI_OK, "text measure: empty text succeeds");
  expect_float(metrics.advance_width, 0.0f, "text measure: empty text has zero advance");
  expect_true(metrics.line_height > 0.0f, "text measure: empty text still reports line height");
  expect_true(metrics.ascender > 0.0f, "text measure: empty text still reports ascender");

  uint32_t codepoints[ER_TEST_TEXT_EDGE_LEN] = {0};
  uint32_t* codepoint_cursor = codepoints;
  *codepoint_cursor = 'E';
  codepoint_cursor++;
  *codepoint_cursor = 'd';
  codepoint_cursor++;
  *codepoint_cursor = 'g';
  codepoint_cursor++;
  *codepoint_cursor = 'e';
  expect_status(er_ui_varfont_measure_text(face, codepoints, ER_TEST_TEXT_EDGE_LEN, NULL), ER_UI_ERR_INVALID_ARGUMENT,
                "text measure: missing metrics output is rejected");
  expect_status(er_ui_varfont_measure_text(NULL, codepoints, ER_TEST_TEXT_EDGE_LEN, &metrics), ER_UI_ERR_INVALID_ARGUMENT,
                "text measure: missing face is rejected");
  expect_status(er_ui_varfont_measure_text(face, NULL, ER_TEST_TEXT_EDGE_LEN, &metrics), ER_UI_ERR_INVALID_ARGUMENT,
                "text measure: missing non-empty codepoint buffer is rejected");

  vr_font_face_destroy(face);
}

static void test_text_vertex_and_ascii_helpers_validate_boundaries(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_TEXT_BG, er_ui_test_allocator()), ER_UI_OK,
                "text helpers: scene init succeeds");

  expect_status(er_ui_scene_push_varfont_vertices(&scene, NULL, 0u, ER_TEST_TEXT_COLOR), ER_UI_OK,
                "text helpers: empty vertex batch succeeds");
  expect_size(scene.text_quad_count, 0u, "text helpers: empty vertex batch emits no quads");

  const vr_vertex_t partial[] = {
    {10.0f, 20.0f, 0.10f, 0.20f, 1.0f, 1.0f, 1.0f, 1.0f, ER_TEST_TEXT_PARTIAL_ATLAS_ID},
    {18.0f, 20.0f, 0.30f, 0.20f, 1.0f, 1.0f, 1.0f, 1.0f, ER_TEST_TEXT_PARTIAL_ATLAS_ID},
  };
  expect_status(er_ui_scene_push_varfont_vertices(&scene, partial, ER_TEST_TEXT_PARTIAL_VERTEX_COUNT, ER_TEST_TEXT_COLOR), ER_UI_ERR_INVALID_ARGUMENT,
                "text helpers: partial glyph vertex batch is rejected");

  vr_font_face_t* face = er_ui_test_open_font(24.0f, "text helpers: bundled font bytes load", "text helpers: font opens");
  if (face) {
    expect_status(er_ui_scene_push_ascii_text(&scene, face, "", 0u, 4.0f, 24.0f, ER_TEST_TEXT_COLOR), ER_UI_OK,
                  "text helpers: empty ascii text fits zero budget");
    expect_status(er_ui_scene_push_ascii_text(&scene, face, "Edge", ER_TEST_TEXT_EDGE_LEN, 4.0f, 48.0f, ER_TEST_TEXT_COLOR), ER_UI_OK,
                  "text helpers: ascii text fits exact budget");
    expect_true(scene.text_quad_count > 0u, "text helpers: ascii text emits quads");
    expect_status(er_ui_scene_push_ascii_text(&scene, face, "Edge", ER_TEST_TEXT_UNDERSIZED_BUDGET, 4.0f, 72.0f, ER_TEST_TEXT_COLOR),
                  ER_UI_ERR_INVALID_ARGUMENT, "text helpers: ascii text rejects undersized budget");
    expect_status(er_ui_scene_push_ascii_text(&scene, face, NULL, ER_TEST_TEXT_EDGE_LEN, 4.0f, 96.0f, ER_TEST_TEXT_COLOR),
                  ER_UI_ERR_INVALID_ARGUMENT, "text helpers: ascii text rejects missing string");

    vr_font_face_destroy(face);
  }

  er_ui_scene_destroy(&scene);
}

void run_text_tests(void) {
  test_text_measure_empty_and_rejects_invalid_inputs();
  test_text_vertex_and_ascii_helpers_validate_boundaries();
}
