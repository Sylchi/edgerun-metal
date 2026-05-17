#include "test_common.h"

#include <stdbool.h>

static const char* const VR_SHAPE_TEXT = "Hello";
static const float VR_SHAPE_RENDER_X = 10.0f;
static const float VR_SHAPE_RENDER_Y = 10.0f;
static const uint32_t VR_SHAPE_SENTINEL_GLYPH = 0x1u;

static void test_shape_ascii_text(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "shape: test font opens");
  if (!face) return;

  uint32_t* cps = test_ascii_codepoints(VR_SHAPE_TEXT, NULL);
  test_expect(cps == NULL, "shape: ascii helper fails when count pointer is null");

  size_t cp_count = 0;
  cps = test_ascii_codepoints(VR_SHAPE_TEXT, &cp_count);
  test_expect(cps != NULL && cp_count == 5, "shape: ascii conversion creates 5 codepoints");
  if (!cps) {
    test_close_face(face);
    return;
  }

  vr_shaped_glyph_t* shaped = NULL;
  size_t shaped_count = 0;
  vr_status_t st = vr_font_shape_text(face, cps, cp_count, &shaped, &shaped_count);
  test_expect_status(st, VR_OK, "shape: text shaping returns OK");
  test_expect(shaped_count == cp_count, "shape: one shaped glyph per input codepoint");

  if (shaped_count > 0) {
    bool any_visible = false;
    for (size_t i = 0; i < shaped_count; ++i) {
      if (shaped[i].glyph != 0u && shaped[i].x_advance > 0.0f) {
        any_visible = true;
        break;
      }
    }
    test_expect(any_visible, "shape: non-empty shaped set has positive advances");
  }

  vr_vertex_t* verts = NULL;
  size_t vert_count = 0;
  st = vr_font_build_vertex_batch(face, shaped, shaped_count, VR_SHAPE_RENDER_X, VR_SHAPE_RENDER_Y, &verts, &vert_count);
  test_expect_status(st, VR_OK, "shape: single-atlas batch builder returns OK");
  test_expect((vert_count % VR_FONT_VERTICES_PER_GLYPH) == 0, "shape: vertex count is triangle-multiple");

  st = vr_font_free_vertices(face, verts, vert_count);
  test_expect_status(st, VR_OK, "shape: free vertices returns OK");
  st = vr_font_free_shaped(face, shaped, shaped_count);
  test_expect_status(st, VR_OK, "shape: free shaped returns OK");
  test_free_codepoints(cps);
  test_close_face(face);
}

static void test_shape_zero_count_paths(vr_font_face_t* face) {
  vr_shaped_glyph_t* shaped = (vr_shaped_glyph_t*)(uintptr_t)VR_SHAPE_SENTINEL_GLYPH;
  size_t shaped_count = 0;
  uint32_t cps = 'x';

  vr_status_t st = vr_font_shape_text(NULL, &cps, 0, &shaped, &shaped_count);
  test_expect_status(st, VR_ERR_INVALID_FONT, "shape: null face rejected");

  st = vr_font_shape_text(face, &cps, 0, &shaped, &shaped_count);
  test_expect_status(st, VR_OK, "shape: empty codepoint count is accepted");
  test_expect(shaped == NULL && shaped_count == 0, "shape: empty input returns zero shaped output");

  vr_vertex_t* verts = (vr_vertex_t*)0x1;
  size_t vert_count = 1;
  vr_shaped_glyph_t dummy = {0};
  st = vr_font_build_vertex_batch(face, &dummy, 0, 0.0f, 0.0f, &verts, &vert_count);
  test_expect_status(st, VR_OK, "shape: zero shaped count returns OK");
  test_expect(verts == NULL && vert_count == 0, "shape: zero shaped count yields zero vertices");
}

void run_shape_tests(void) {
  test_shape_ascii_text();

  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "shape: test font opens for empty-path checks");
  if (!face) return;

  test_shape_zero_count_paths(face);
  test_close_face(face);
}
