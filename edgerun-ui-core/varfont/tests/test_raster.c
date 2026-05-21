#include "test_common.h"

#include "vr_font_internal.h"

#include <stdlib.h>

#include <stdbool.h>

static const uint16_t VR_RASTER_TEST_MAX_X = 100u;
static const uint16_t VR_RASTER_TEST_MAX_Y = 80u;
static const uint16_t VR_RASTER_TEST_ZERO_COUNT = 0u;
static const uint8_t VR_RASTER_TEST_ALPHA_HIGH = 240u;
static const uint8_t VR_RASTER_TEST_ALPHA_LOW = 16u;
static const uint8_t VR_RASTER_TEST_ALPHA_MID_LOW = 32u;
static const uint8_t VR_RASTER_TEST_ALPHA_MID_HIGH = 224u;
static const uint8_t VR_RASTER_TEST_ALPHA_MAX = 255u;
static const uint8_t VR_RASTER_TEST_CHANNEL_INDEX_R = 0u;
static const uint8_t VR_RASTER_TEST_CHANNEL_INDEX_G = 1u;
static const uint8_t VR_RASTER_TEST_CHANNEL_INDEX_B = 2u;
static const size_t VR_RASTER_TEST_MSDF_CHANNEL_COUNT = 3u;
static const float VR_RASTER_TEST_HEAVY_SIZE = 58.0f;
static const float VR_RASTER_TEST_HEAVY_WEIGHT = 900.0f;
static const char* const VR_RASTER_TEST_WEIGHT_AXIS = "wght";

static void test_init_synthetic_face(vr_font_face_t* face) {
  vr_font_config_t cfg = test_default_font_config();
  face->cfg = cfg;
  face->allocator = cfg.allocator;
  face->units_per_em = VR_FONT_DEFAULT_PX_SIZE;
}

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

static bool test_msdf_has_distance_ramp(const uint8_t* bitmap, int w, int h) {
  size_t total = (size_t)w * (size_t)h * VR_RASTER_TEST_MSDF_CHANNEL_COUNT;
  bool has_low = false;
  bool has_mid = false;
  bool has_high = false;
  for (size_t i = 0u; i < total; ++i) {
    uint8_t value = bitmap[i];
    if (value <= VR_RASTER_TEST_ALPHA_LOW) {
      has_low = true;
    } else if (value >= VR_RASTER_TEST_ALPHA_HIGH) {
      has_high = true;
    } else if (value >= VR_RASTER_TEST_ALPHA_MID_LOW && value <= VR_RASTER_TEST_ALPHA_MID_HIGH) {
      has_mid = true;
    }
  }
  return has_low && has_mid && has_high;
}

static size_t test_bitmap_covered_count(const uint8_t* bitmap, int w, int h, uint8_t threshold) {
  size_t total = (size_t)w * (size_t)h;
  size_t covered = 0u;
  for (size_t i = 0u; i < total; ++i) {
    if (bitmap[i] >= threshold) {
      ++covered;
    }
  }
  return covered;
}

static void test_rasterize_square_outline(void) {
  int16_t xs[4] = {0, 100, 100, 0};
  int16_t ys[4] = {0, 0, 100, 100};
  bool on[4] = {true, true, true, true};
  uint16_t contour_end[1] = {3u};

  vr_font_face_t face = {0};
  test_init_synthetic_face(&face);

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

  vr_status_t st = vr_rasterize_outline_with_mode(&face, &outline, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                                  &bitmap, &out_w, &out_h, &out_left, &out_top);
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
    (void)vr_free_bitmap(&face, bitmap, out_w, out_h, VR_FONT_ATLAS_FORMAT_ALPHA8);
  }
}

static void test_rasterize_off_curve_start_outline(void) {
  int16_t xs[3] = {0, 50, 100};
  int16_t ys[3] = {0, 80, 0};
  bool on[3] = {false, false, true};
  uint16_t contour_end[1] = {2u};

  vr_font_face_t face = {0};
  test_init_synthetic_face(&face);

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

  vr_status_t st = vr_rasterize_outline_with_mode(&face, &outline, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                                  &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_OK, "raster: off-curve-start outline returns OK");
  if (st == VR_OK) {
    test_expect(out_w > 0 && out_h > 0, "raster: off-curve-start outline produces bitmap dimensions");
    test_expect(test_bitmap_has_coverage(bitmap, out_w, out_h), "raster: off-curve-start outline writes non-zero coverage");
    (void)vr_free_bitmap(&face, bitmap, out_w, out_h, VR_FONT_ATLAS_FORMAT_ALPHA8);
  }
}

static void test_rasterize_validation(void) {
  vr_font_face_t face = {0};
  test_init_synthetic_face(&face);
  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;
  vr_glyph_outline_t invalid = {0};

  vr_status_t st = vr_rasterize_outline_with_mode(NULL, &invalid, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                                  &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null face is rejected");
  st = vr_rasterize_outline_with_mode(&face, NULL, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                      &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null outline is rejected");
  st = vr_rasterize_outline_with_mode(&face, &invalid, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                      NULL, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null bitmap output is rejected");
  st = vr_rasterize_outline_with_mode(&face, &invalid, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                      &bitmap, NULL, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_ERR_INVALID_FONT, "raster: null width output is rejected");
  invalid.point_count = 0u;
  invalid.number_of_contours = 0u;
  st = vr_rasterize_outline_with_mode(&face, &invalid, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                      &bitmap, &out_w, &out_h, &out_left, &out_top);
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
  st = vr_rasterize_outline_with_mode(face, &outline, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                      &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_OK, "raster: real font outline returns OK");
  if (st == VR_OK) {
    test_expect(test_bitmap_has_coverage(bitmap, out_w, out_h), "raster: real font outline writes coverage");
    (void)vr_free_bitmap(face, bitmap, out_w, out_h, VR_FONT_ATLAS_FORMAT_ALPHA8);
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
    test_expect(test_msdf_has_distance_ramp(bitmap, out_w, out_h), "raster: msdf mode preserves low/mid/high distance ramp");
    (void)vr_free_bitmap(face, bitmap, out_w, out_h, VR_FONT_ATLAS_FORMAT_MSDF_RGB);
  }

  vr_free_outline(face, &outline);
  test_close_face(face);
}

static void test_rasterize_heavy_z_stays_legible(void) {
  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "raster: default face opens for heavy z");
  if (!face) {
    return;
  }

  vr_status_t st = vr_font_set_size(face, VR_RASTER_TEST_HEAVY_SIZE);
  test_expect_status(st, VR_OK, "raster: heavy z size applies");
  st = vr_font_set_axis(face, VR_RASTER_TEST_WEIGHT_AXIS, VR_RASTER_TEST_HEAVY_WEIGHT);
  test_expect_status(st, VR_OK, "raster: heavy z weight applies");

  uint16_t glyph_id = vr_find_glyph_id(face, (uint32_t)'z');
  test_expect(glyph_id != 0u, "raster: z glyph maps");
  if (glyph_id == 0u) {
    test_close_face(face);
    return;
  }

  vr_glyph_outline_t outline = {0};
  st = vr_load_glyph_outline(face, glyph_id, &outline);
  if (st != VR_OK) {
    test_expect_status(st, VR_OK, "raster: heavy z outline loads");
    test_close_face(face);
    return;
  }
  st = vr_apply_gvar_variation(face, glyph_id, &outline);
  test_expect_status(st, VR_OK, "raster: heavy z variation applies");

  uint8_t* bitmap = NULL;
  int out_w = VR_RASTER_TEST_ZERO_COUNT;
  int out_h = VR_RASTER_TEST_ZERO_COUNT;
  int out_left = VR_RASTER_TEST_ZERO_COUNT;
  int out_top = VR_RASTER_TEST_ZERO_COUNT;
  st = vr_rasterize_outline_with_mode(face, &outline, VR_FONT_ATLAS_FORMAT_ALPHA8,
                                      &bitmap, &out_w, &out_h, &out_left, &out_top);
  test_expect_status(st, VR_OK, "raster: heavy z rasterizes");
  if (st == VR_OK) {
    size_t covered = test_bitmap_covered_count(bitmap, out_w, out_h, VR_RASTER_TEST_ALPHA_HIGH);
    size_t total = (size_t)out_w * (size_t)out_h;
    test_expect(covered > 0u, "raster: heavy z has covered pixels");
    test_expect(covered < total, "raster: heavy z keeps background pixels in bounds");
    test_expect(bitmap[(size_t)(out_h / 2) * (size_t)out_w + (size_t)(out_w / 2)] >= VR_RASTER_TEST_ALPHA_LOW,
                "raster: heavy z diagonal reaches center");
    (void)vr_free_bitmap(face, bitmap, out_w, out_h, VR_FONT_ATLAS_FORMAT_ALPHA8);
  }

  vr_free_outline(face, &outline);
  test_close_face(face);
}

static void test_rasterize_mode_invalid_format_rejected(void) {
  vr_font_face_t face = {0};
  test_init_synthetic_face(&face);
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
  test_rasterize_heavy_z_stays_legible();
  test_rasterize_mode_invalid_format_rejected();
}
