#include "test_common.h"

static const char* const VR_ATLAS_TEXT = "Hello";
static const float VR_ATLAS_RENDER_X = 0.0f;
static const float VR_ATLAS_RENDER_Y = 0.0f;
static const float VR_ATLAS_CACHED_SIZE = 80.0f;

void run_atlas_tests(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "atlas: test font opens");
  if (!face) return;

  size_t cp_count = 0;
  uint32_t* cps = test_ascii_codepoints(VR_ATLAS_TEXT, &cp_count);
  test_expect(cps != NULL && cp_count == 5, "atlas: ascii conversion for shape input");
  if (!cps) {
    test_close_face(face);
    return;
  }

  vr_shaped_glyph_t* shaped = NULL;
  size_t shaped_count = 0;
  vr_status_t st = vr_font_shape_text(face, cps, cp_count, &shaped, &shaped_count);
  test_expect_status(st, VR_OK, "atlas: shape returns OK");

  if (st == VR_OK && shaped_count > 0) {
    vr_vertex_t* verts = NULL;
    vr_vertex_atlas_range_t* ranges = NULL;
    size_t vert_count = 0;
    size_t range_count = 0;

    st = vr_font_build_vertex_batches_by_atlas(
      face,
      shaped,
      shaped_count,
      VR_ATLAS_RENDER_X,
      VR_ATLAS_RENDER_Y,
      &verts,
      &vert_count,
      &ranges,
      &range_count);
    test_expect_status(st, VR_OK, "atlas: atlas batch build returns OK");
    test_expect(range_count > 0, "atlas: batch build emits one or more ranges");

    if (range_count > 0) {
      size_t total = 0;
      for (size_t i = 0; i < range_count; ++i) {
        test_expect(ranges[i].atlas_id < vr_font_atlas_count(face), "atlas: range atlas id is valid");
        test_expect(ranges[i].start_vertex + ranges[i].vertex_count <= vert_count,
                    "atlas: range range stays within vertex buffer");

        uint32_t tex = 0;
        vr_status_t tex_status = vr_font_atlas_texture(face, ranges[i].atlas_id, &tex);
        test_expect_status(tex_status, VR_OK, "atlas: atlas texture lookup works");
        test_expect(tex == 0, "atlas: texture id is zero without GL callbacks");
        total += ranges[i].vertex_count;
      }
      test_expect(total == vert_count, "atlas: ranges sum to vertex count");
    }

    vr_font_free_vertex_atlas_ranges(ranges);
    st = vr_font_free_vertices(face, verts);
    test_expect_status(st, VR_OK, "atlas: free vertices returns OK");
  }

  st = vr_font_free_shaped(face, shaped);
  test_expect_status(st, VR_OK, "atlas: free shaped returns OK");
  test_free_codepoints(cps);
  test_close_face(face);
}

void run_cache_tests(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "cache: test font opens");
  if (!face) return;

  size_t before_atlases = vr_font_atlas_count(face);

  size_t cp_count = 0;
  uint32_t* cps = test_ascii_codepoints(VR_ATLAS_TEXT, &cp_count);
  test_expect(cps != NULL && cp_count == 5, "cache: ascii conversion for cache input");
  if (!cps) {
    test_close_face(face);
    return;
  }

  vr_shaped_glyph_t* shaped = NULL;
  size_t shaped_count = 0;
  vr_status_t st = vr_font_shape_text(face, cps, cp_count, &shaped, &shaped_count);
  test_expect_status(st, VR_OK, "cache: shape returns OK");

  vr_vertex_t* verts = NULL;
  size_t vert_count = 0;
  st = vr_font_build_vertex_batch(face, shaped, shaped_count, VR_ATLAS_RENDER_X, VR_ATLAS_RENDER_Y, &verts, &vert_count);
  test_expect_status(st, VR_OK, "cache: first batch build returns OK");
  test_expect(vert_count > 0, "cache: first batch produces geometry");
  st = vr_font_free_vertices(face, verts);
  test_expect_status(st, VR_OK, "cache: first free vertices returns OK");
  st = vr_font_free_shaped(face, shaped);
  test_expect_status(st, VR_OK, "cache: first free shaped returns OK");

  st = vr_font_clear_cache(face);
  test_expect_status(st, VR_OK, "cache: clear cache returns OK");

  st = vr_font_set_size(face, VR_ATLAS_CACHED_SIZE);
  test_expect_status(st, VR_OK, "cache: set_size after clear cache succeeds");

  st = vr_font_shape_text(face, cps, cp_count, &shaped, &shaped_count);
  test_expect_status(st, VR_OK, "cache: shape after size change succeeds");

  st = vr_font_build_vertex_batch(face, shaped, shaped_count, VR_ATLAS_RENDER_X, VR_ATLAS_RENDER_Y, &verts, &vert_count);
  test_expect_status(st, VR_OK, "cache: batch after size change succeeds");
  size_t after_atlases = vr_font_atlas_count(face);
  test_expect(after_atlases >= before_atlases, "cache: atlas count is non-decreasing");
  test_expect(vert_count > 0, "cache: second batch produces geometry");

  st = vr_font_free_vertices(face, verts);
  test_expect_status(st, VR_OK, "cache: second free vertices returns OK");
  st = vr_font_free_shaped(face, shaped);
  test_expect_status(st, VR_OK, "cache: second free shaped returns OK");
  test_free_codepoints(cps);
  test_close_face(face);
}
