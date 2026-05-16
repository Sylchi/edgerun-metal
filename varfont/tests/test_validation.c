#include "test_common.h"

#include <string.h>

static const float VR_VALIDATION_ZERO = 0.0f;

static void test_face_create_validation(void) {
  vr_font_config_t cfg = test_default_font_config();

  vr_status_t st = vr_font_face_create(NULL, test_font_path(), &cfg);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: null face output pointer is rejected");

  vr_font_face_t* face = NULL;
  st = vr_font_face_create(&face, NULL, &cfg);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: null path is rejected");

  st = vr_font_face_create(&face, test_font_path(), NULL);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: null config is rejected");

  st = vr_font_face_create(&face, "fonts/does-not-exist.ttf", &cfg);
  test_expect_status(st, VR_ERR_IO, "validation: missing font returns IO");
}

static void test_runtime_null_validation(vr_font_face_t* face) {
  uint32_t dummy = 0;
  size_t count = 0;
  vr_shaped_glyph_t* shaped = NULL;
  size_t out_count = 1;
  vr_vertex_t* dummy_vertices = NULL;

  vr_status_t st = vr_font_shape_text(face, NULL, 1, &shaped, &out_count);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: shape rejects null codepoint pointer");

  st = vr_font_shape_text(face, &dummy, 1, NULL, &out_count);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: shape rejects null out_glyphs pointer");

  st = vr_font_shape_text(face, &dummy, 1, &shaped, NULL);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: shape rejects null out_count pointer");

  st = vr_font_build_vertex_batch(face, NULL, 1, VR_VALIDATION_ZERO, VR_VALIDATION_ZERO, &dummy_vertices, &count);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: batch rejects null shaped array");

  st = vr_font_build_vertex_batch(face, NULL, 1, VR_VALIDATION_ZERO, VR_VALIDATION_ZERO, &dummy_vertices, NULL);
  test_expect_status(st, VR_ERR_INVALID_FONT, "validation: batch rejects null out_vertices");
}

void run_validation_tests(void) {
  test_face_create_validation();

  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "validation: test font opens");
  if (!face) return;

  test_runtime_null_validation(face);
  test_close_face(face);
}
