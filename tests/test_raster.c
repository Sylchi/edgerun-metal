#include "test_common.h"

#include "vr_font_internal.h"

#include <stdbool.h>

static const uint16_t VR_RASTER_TEST_MAX_X = 100u;
static const uint16_t VR_RASTER_TEST_MAX_Y = 80u;
static const uint16_t VR_RASTER_TEST_ZERO_COUNT = 0u;
static const uint8_t VR_RASTER_TEST_ALPHA_HIGH = 240u;
static const uint8_t VR_RASTER_TEST_ALPHA_LOW = 16u;
static const uint8_t VR_RASTER_TEST_ALPHA_MAX = 255u;

static bool test_bitmap_has_coverage(const uint8_t* bitmap, int w, int h) {
  size_t total = (size_t)w * (size_t)h;
  for (size_t i = 0; i < total; ++i) {
    if (bitmap[i] > 0u) return true;
  }
  return false;
}

static uint8_t test_bitmap_max_alpha(const uint8_t* bitmap, int w, int h) {
  size_t total = (size_t)w * (size_t)h;
  uint8_t max = 0u;
  for (size_t i = 0; i < total; ++i) {
    if (bitmap[i] > max) {
      max = bitmap[i];
    }
  }
  return max;
}

static void test_rasterize_square_outline(void) {
  int16_t xs[4] = {0, 100, 100, 0};
  int16_t ys[4] = {0, 0, 100, 100};
  bool on[4] = {true, true, true, true};
  uint16_t contour_end[1] = {3u};

  vr_font_face_t face = {0};
  face.cfg.px_size = VR_FONT_DEFAULT_PX_SIZE;
  face.units_per_em = VR_FONT_DEFAULT_PX_SIZE;

  vr_glyph_outline_t outline = {
    .number_of_contours = 1u,
    .point_count = 4u,
    .point_count_alloc = 4u,
    .x = xs,
    .y = ys,
    .on_curve = on,
    .contour_end_pts = contour_end,
    .x_min = 0,
    .y_min = 0,
    .x_max = 100,
    .y_max = 100,
  };

  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;

  vr_status_t st = vr_rasterize_outline(&face, &outline, &bitmap, &out_w, &out_h, &out_left, &out_top);
    test_expect_status(st, VR_OK, "raster: square-like outline returns OK");
  if (st == VR_OK) {
    test_expect(out_w > 0 && out_h > 0, "raster: square-like outline produces bitmap dimensions");
    test_expect(bitmap[(size_t)(out_h / 2) * (size_t)out_w + (out_w / 2)] >= VR_RASTER_TEST_ALPHA_HIGH,
      "raster: square-like outline center is high alpha");
    test_expect(test_bitmap_max_alpha(bitmap, out_w, out_h) == VR_RASTER_TEST_ALPHA_MAX,
      "raster: square-like outline reaches saturated SDF alpha");
    test_expect(bitmap[0u] <= VR_RASTER_TEST_ALPHA_LOW,
      "raster: square-like outline corner is background");
    test_expect(test_bitmap_has_coverage(bitmap, out_w, out_h), "raster: square-like outline writes non-zero coverage");
    test_expect(bitmap[(size_t)(out_h / 2) * (size_t)out_w + (out_w / 2)] > bitmap[(size_t)(out_w * out_h) - 1u],
      "raster: square-like center alpha brighter than corner");
    free(bitmap);
  }
}

static void test_rasterize_off_curve_start_outline(void) {
  int16_t xs[3] = {0, 50, 100};
  int16_t ys[3] = {0, 80, 0};
  bool on[3] = {false, false, true};
  uint16_t contour_end[1] = {2u};

  vr_font_face_t face = {0};
  face.cfg.px_size = VR_FONT_DEFAULT_PX_SIZE;
  face.units_per_em = VR_FONT_DEFAULT_PX_SIZE;

  vr_glyph_outline_t outline = {
    .number_of_contours = 1u,
    .point_count = 3u,
    .point_count_alloc = 3u,
    .x = xs,
    .y = ys,
    .on_curve = on,
    .contour_end_pts = contour_end,
    .x_min = 0,
    .y_min = 0,
    .x_max = VR_RASTER_TEST_MAX_X,
    .y_max = VR_RASTER_TEST_MAX_Y,
  };

  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;

  vr_status_t st = vr_rasterize_outline(&face, &outline, &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_OK, "raster: off-curve-start outline returns OK");
  if (st == VR_OK) {
    test_expect(out_w > 0 && out_h > 0, "raster: off-curve-start outline produces bitmap dimensions");
    test_expect(test_bitmap_has_coverage(bitmap, out_w, out_h), "raster: off-curve-start outline writes non-zero coverage");
    free(bitmap);
  }
}

static void test_rasterize_validation(void) {
  vr_font_face_t face = {0};
  face.cfg.px_size = VR_FONT_DEFAULT_PX_SIZE;
  face.units_per_em = VR_FONT_DEFAULT_PX_SIZE;
  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;
  vr_glyph_outline_t invalid = {0};

  vr_status_t st = vr_rasterize_outline(NULL, &invalid, &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null face is rejected");
  st = vr_rasterize_outline(&face, NULL, &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null outline is rejected");
  st = vr_rasterize_outline(&face, &invalid, NULL, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null bitmap output is rejected");
  st = vr_rasterize_outline(&face, &invalid, &bitmap, NULL, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null width output is rejected");
  invalid.point_count = 0u;
  invalid.number_of_contours = 0u;
  st = vr_rasterize_outline(&face, &invalid, &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_UNSUPPORTED, "raster: zero contour outline is rejected");
}

static void test_rasterize_real_font_outline(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "raster: default font opens");
  if (!face) {
    return;
  }

  vr_glyph_outline_t outline = {0};
  uint32_t codepoint = (uint32_t)'A';
  uint16_t glyph_id = vr_find_glyph_id(face, codepoint);
  vr_status_t st = (glyph_id == 0u) ? VR_ERR_NOT_FOUND : vr_load_glyph_outline(face, glyph_id, &outline);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "raster: real font glyph resolves");
    test_close_face(face);
    return;
  }

  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;
  st = vr_rasterize_outline(face, &outline, &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_OK, "raster: real font outline returns OK");
  if (st == VR_OK) {
    test_expect(test_bitmap_has_coverage(bitmap, out_w, out_h), "raster: real font outline writes coverage");
    free(bitmap);
  }

  vr_free_outline(&outline);
  test_close_face(face);
}

void run_raster_tests(void) {
  test_rasterize_square_outline();
  test_rasterize_off_curve_start_outline();
  test_rasterize_validation();
  test_rasterize_real_font_outline();
}
