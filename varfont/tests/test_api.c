#include "test_common.h"

#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char* const VR_FONT_EMPTY_PATH = "/tmp/vrfont-empty-font-invalid.ttf";
static const char* const VR_FONT_SHORT_PATH = "/tmp/vrfont-short-font-invalid.ttf";
static const uint32_t VR_INVALID_GLYPH_ID = (uint32_t)0xFFFFu;
static const uint32_t VR_TEST_GLYPH_CODE = 'H';
static const float VR_TEST_AXIS_VALUE = 400.0f;
static const float VR_TEST_RENDER_X = 0.0f;
static const float VR_TEST_RENDER_Y = 0.0f;
static const size_t VR_SHORT_FONT_BYTES = 8u;
static const int VR_FONT_FILE_MODE = 0644;
static const int VR_FILE_OPEN_FLAGS = O_CREAT | O_WRONLY | O_TRUNC;
static const uint8_t VR_SHORT_FONT_PAYLOAD[] = {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

static void test_invalid_font_file(const char* path, const uint8_t* payload, size_t payload_len, const char* label) {
  vr_font_config_t cfg = test_default_font_config();
  vr_font_face_t* face = NULL;

  if (unlink(path) != 0) {
    int unlink_errno = errno;
    if (unlink_errno != ENOENT) {
      test_expect(0, label);
      return;
    }
  }

  int fd = open(path, VR_FILE_OPEN_FLAGS, VR_FONT_FILE_MODE);
  if (fd < 0) {
    test_expect(0, label);
    return;
  }

  if (payload_len > 0u) {
    ssize_t written = write(fd, payload, payload_len);
    test_expect((size_t)written == payload_len, label);
  }
  close(fd);

  size_t size = 0;
  uint8_t* data = test_read_file_bytes(path, &size);
  vr_status_t st = data ? vr_font_face_create_from_memory(&face, data, size, &cfg) : VR_ERR_INVALID_FONT;
  free(data);
  test_expect_status(st, VR_ERR_INVALID_FONT, label);
  test_close_face(face);
  unlink(path);
}

static void test_invalid_font_file_variants(void) {
  test_invalid_font_file(VR_FONT_EMPTY_PATH, NULL, 0u, "api: empty font file is rejected");
  test_invalid_font_file(VR_FONT_SHORT_PATH, VR_SHORT_FONT_PAYLOAD, VR_SHORT_FONT_BYTES, "api: short invalid font file is rejected");
}

static void test_face_state_queries(void) {
  test_expect(vr_font_axis_count(NULL) == 0, "api: axis count query is safe for null face");
  test_expect(vr_font_axes(NULL) == NULL, "api: axis query is safe for null face");
  test_expect(vr_font_last_error(NULL) == VR_ERR_INVALID_FONT, "api: last_error query is safe for null face");
  test_expect(vr_font_atlas_count(NULL) == 0, "api: atlas count query is safe for null face");

  uint32_t out_texture = 0;
  vr_status_t st = vr_font_atlas_texture(NULL, 0u, &out_texture);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: atlas texture query rejects null face");

  st = vr_font_atlas_texture(NULL, 0u, NULL);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: atlas texture query rejects null output pointer");
}

static void test_mutating_api_validation(vr_font_face_t* face) {
  vr_status_t st = vr_font_clear_cache(NULL);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: clear_cache rejects null face");

  st = vr_font_clear_cache(face);
  test_expect_status(st, VR_OK, "api: clear_cache works on valid face");

  st = vr_font_set_size(NULL, VR_FONT_DEFAULT_PX_SIZE);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: set_size rejects null face");

  st = vr_font_set_size(face, 0.0f);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: set_size rejects non-positive size");

  st = vr_font_set_size(face, VR_FONT_DEFAULT_PX_SIZE);
  test_expect_status(st, VR_OK, "api: set_size accepts valid value");

  st = vr_font_set_axis(NULL, "wght", VR_TEST_AXIS_VALUE);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: set_axis rejects null face");

  st = vr_font_set_axis(face, NULL, VR_TEST_AXIS_VALUE);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: set_axis rejects null tag");

  st = vr_font_set_axis(face, "none", VR_TEST_AXIS_VALUE);
  test_expect_status(st, VR_ERR_NOT_FOUND, "api: set_axis rejects unknown tag");

  uint32_t out_texture = 0;
  size_t atlas_count = vr_font_atlas_count(face);
  st = vr_font_atlas_texture(face, (uint32_t)atlas_count, &out_texture);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: atlas texture rejects out-of-range atlas id");
  if (atlas_count > 0) {
    st = vr_font_atlas_texture(face, 0u, &out_texture);
    test_expect_status(st, VR_OK, "api: atlas texture accepts a valid atlas id");
  }
}

static void test_batch_and_bake_validation(vr_font_face_t* face) {
  vr_baked_glyph_t out = {0};
  vr_status_t st = vr_font_bake_glyph(NULL, VR_TEST_GLYPH_CODE, &out);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: bake rejects null face");

  st = vr_font_bake_glyph(face, VR_TEST_GLYPH_CODE, NULL);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: bake rejects null output");

  st = vr_font_bake_glyph(face, VR_INVALID_GLYPH_ID, &out);
  test_expect_status(st, VR_ERR_INVALID_FONT, "api: bake rejects glyph id outside font range");

  st = vr_font_free_shaped(face, NULL);
  test_expect_status(st, VR_OK, "api: free_shaped accepts null list");

  vr_vertex_t* verts = NULL;
  size_t vert_count = 0;
  st = vr_font_build_vertex_batch(face, NULL, 0, VR_TEST_RENDER_X, VR_TEST_RENDER_Y, &verts, &vert_count);
  test_expect_status(st, VR_OK, "api: batch accepts zero shaped count");
  test_expect(verts == NULL, "api: batch returns null when shaped_count is zero");
  test_expect(vert_count == 0, "api: batch returns zero when shaped_count is zero");

  st = vr_font_free_vertices(face, NULL);
  test_expect_status(st, VR_OK, "api: free_vertices accepts null vertices");

  vr_vertex_t* ranged_vertices = NULL;
  vr_vertex_atlas_range_t* ranges = NULL;
  size_t range_count = 0;
  uint32_t cps[] = {VR_TEST_GLYPH_CODE};
  vr_shaped_glyph_t* shaped = NULL;
  size_t shaped_count = 0;
  st = vr_font_shape_text(face, cps, 1, &shaped, &shaped_count);
  if (st == VR_OK && shaped_count == 1) {
    st = vr_font_build_vertex_batches_by_atlas(face, shaped, shaped_count, VR_TEST_RENDER_X, VR_TEST_RENDER_Y, &ranged_vertices, &vert_count, &ranges, &range_count);
    if (st == VR_OK) {
      if (range_count == 0) {
        test_expect(ranged_vertices == NULL, "api: atlas batch can emit zero ranges");
        test_expect(vert_count == 0, "api: atlas batch can emit zero vertices");
      } else {
        for (size_t i = 0; i < range_count; ++i) {
          test_expect((ranges[i].vertex_count % VR_FONT_VERTICES_PER_GLYPH) == 0, "api: atlas range vertex counts align to triangles");
          test_expect(ranges[i].atlas_id < vr_font_atlas_count(face), "api: atlas id is in-bounds");
        }
        vr_font_free_vertices(face, ranged_vertices);
        vr_font_free_vertex_atlas_ranges(ranges);
      }
    } else {
      test_expect(st == VR_ERR_INVALID_FONT || st == VR_ERR_UNSUPPORTED || st == VR_ERR_NO_SPACE,
                  "api: range batching may reject malformed/empty glyph outlines");
    }
    vr_font_free_shaped(face, shaped);
  }
}

void run_api_tests(void) {
  test_invalid_font_file_variants();

  test_face_state_queries();

  vr_font_face_t* face = test_open_default_face();
  test_expect(face != NULL, "api: test font opens for runtime checks");
  if (!face) return;

  test_mutating_api_validation(face);
  test_batch_and_bake_validation(face);
  test_close_face(face);
}
