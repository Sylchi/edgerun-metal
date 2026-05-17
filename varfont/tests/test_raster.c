#include "test_common.h"

#include "vr_font_internal.h"

#include <stdlib.h>

#include <stdbool.h>

static const uint16_t VR_RASTER_TEST_MAX_X = 100u;
static const uint16_t VR_RASTER_TEST_MAX_Y = 80u;
static const uint16_t VR_RASTER_TEST_ZERO_COUNT = 0u;
static const uint8_t VR_RASTER_TEST_ALPHA_HIGH = 240u;
static const uint8_t VR_RASTER_TEST_ALPHA_LOW = 16u;
static const uint8_t VR_RASTER_TEST_ALPHA_MAX = 255u;
static const uint8_t VR_RASTER_TEST_CHANNEL_INDEX_R = 0u;
static const uint8_t VR_RASTER_TEST_CHANNEL_INDEX_G = 1u;
static const uint8_t VR_RASTER_TEST_CHANNEL_INDEX_B = 2u;
static const size_t VR_RASTER_TEST_MSDF_CHANNEL_COUNT = 3u;

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

static bool test_msdf_has_variation(const uint8_t* bitmap, int w, int h) {
  size_t total = (size_t)w * (size_t)h;
  for (size_t i = 0; i < total; ++i) {
    size_t base = i * VR_RASTER_TEST_MSDF_CHANNEL_COUNT;
    if (
      bitmap[base + VR_RASTER_TEST_CHANNEL_INDEX_R] != bitmap[base + VR_RASTER_TEST_CHANNEL_INDEX_G] ||
      bitmap[base + VR_RASTER_TEST_CHANNEL_INDEX_R] != bitmap[base + VR_RASTER_TEST_CHANNEL_INDEX_B]) {
      return true;
    }
  }
  return false;
}

static bool test_bitmap_equal(const uint8_t* a, const uint8_t* b, size_t count) {
  for (size_t i = 0u; i < count; ++i) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
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

  vr_free_outline(face, &outline);
  test_close_face(face);
}

static void test_rasterize_msdf_mode_outputs_channels(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "raster: default face opens for msdf mode");
  if (!face) {
    return;
  }

  uint16_t glyph_id = vr_find_glyph_id(face, (uint32_t)'A');
  test_expect(glyph_id != 0u, "raster: A glyph is mapped in test font");
  if (glyph_id == 0u) {
    test_close_face(face);
    return;
  }

  vr_glyph_outline_t outline = {0};
  vr_status_t st = vr_load_glyph_outline(face, glyph_id, &outline);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "raster: outline loads for msdf mode");
    test_close_face(face);
    return;
  }

  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;
  st = vr_rasterize_outline_with_mode(
    face,
    &outline,
    VR_FONT_ATLAS_FORMAT_MSDF_RGB,
    &bitmap,
    &out_w,
    &out_h,
    &out_left,
    &out_top);
  test_expect_status(st, VR_OK, "raster: msdf mode outline returns OK");
  if (st == VR_OK) {
    size_t channel_count = (size_t)out_w * (size_t)out_h * VR_RASTER_TEST_MSDF_CHANNEL_COUNT;
    test_expect(channel_count > 0u, "raster: msdf mode emits non-zero output bytes");
    test_expect(test_msdf_has_variation(bitmap, out_w, out_h), "raster: msdf mode channels diverge");
    free(bitmap);
  }

  vr_free_outline(face, &outline);
  test_close_face(face);
}

static void test_rasterize_alpha_mode_matches_legacy_interface(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "raster: default face opens for alpha mode parity");
  if (!face) {
    return;
  }

  vr_glyph_outline_t outline = {0};
  vr_status_t st = vr_load_glyph_outline(face, (uint16_t)vr_find_glyph_id(face, (uint32_t)'A'), &outline);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "raster: A glyph outline loads for alpha parity");
    vr_free_outline(face, &outline);
    test_close_face(face);
    return;
  }

  uint8_t* legacy_bitmap = NULL;
  uint8_t* mode_bitmap = NULL;
  int out_w_a = VR_RASTER_TEST_ZERO_COUNT;
  int out_h_a = VR_RASTER_TEST_ZERO_COUNT;
  int out_left_a = VR_RASTER_TEST_ZERO_COUNT;
  int out_top_a = VR_RASTER_TEST_ZERO_COUNT;
  int out_w_m = VR_RASTER_TEST_ZERO_COUNT;
  int out_h_m = VR_RASTER_TEST_ZERO_COUNT;
  int out_left_m = VR_RASTER_TEST_ZERO_COUNT;
  int out_top_m = VR_RASTER_TEST_ZERO_COUNT;

  vr_status_t legacy_status = vr_rasterize_outline(face, &outline, &legacy_bitmap, &out_w_a, &out_h_a, &out_left_a, &out_top_a);
  test_expect_status(legacy_status, VR_OK, "raster: legacy alpha path rasterizes");
  vr_status_t mode_status = vr_rasterize_outline_with_mode(
    face,
    &outline,
    VR_FONT_ATLAS_FORMAT_ALPHA8,
    &mode_bitmap,
    &out_w_m,
    &out_h_m,
    &out_left_m,
    &out_top_m);
  test_expect_status(mode_status, VR_OK, "raster: explicit alpha mode rasterizes");

  if (legacy_status == VR_OK && mode_status == VR_OK) {
    test_expect(out_w_a == out_w_m && out_h_a == out_h_m, "raster: alpha mode sizes match legacy");
    test_expect(out_left_a == out_left_m && out_top_a == out_top_m, "raster: alpha mode offsets match legacy");
    if (out_w_a == out_w_m && out_h_a == out_h_m) {
      size_t pixel_count = (size_t)out_w_a * (size_t)out_h_a;
      test_expect(test_bitmap_equal(legacy_bitmap, mode_bitmap, pixel_count), "raster: legacy alpha matches mode alpha bytes");
    }
  }

  free(legacy_bitmap);
  free(mode_bitmap);
  vr_free_outline(face, &outline);
  test_close_face(face);
}

static void test_rasterize_mode_invalid_format_rejected(void) {
  vr_font_face_t face = {0};
  face.cfg.px_size = VR_FONT_DEFAULT_PX_SIZE;
  face.units_per_em = VR_FONT_DEFAULT_PX_SIZE;
  face.glyph_cache_count = 1u;
  int16_t xs[4] = {0, 100, 100, 0};
  int16_t ys[4] = {0, 0, 100, 100};
  bool on[4] = {true, true, true, true};
  uint16_t contour_end[1] = {3u};
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
  vr_status_t st = vr_rasterize_outline_with_mode(
    &face,
    &outline,
    (vr_font_atlas_format_t)0u,
    &bitmap,
    &out_w,
    &out_h,
    &out_left,
    &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: invalid atlas format is rejected");
}

void run_raster_tests(void) {
  test_rasterize_square_outline();
  test_rasterize_off_curve_start_outline();
  test_rasterize_validation();
  test_rasterize_real_font_outline();
  test_rasterize_msdf_mode_outputs_channels();
  test_rasterize_alpha_mode_matches_legacy_interface();
  test_rasterize_mode_invalid_format_rejected();
}
