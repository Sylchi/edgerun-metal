#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int g_tests_total = 0;
int g_tests_failed = 0;

void test_expect(bool cond, const char* name) {
  ++g_tests_total;
  if (!cond) {
    ++g_tests_failed;
    fprintf(stderr, "FAIL: %s\n", name);
  }
}

void test_expect_status(vr_status_t got, vr_status_t expected, const char* name) {
  test_expect(got == expected, name);
  if (got != expected) {
    fprintf(stderr, "  got=%u expected=%u\n", (unsigned)got, (unsigned)expected);
  }
}

void test_expect_u32_eq(uint32_t got, uint32_t expected, const char* name) {
  test_expect(got == expected, name);
  if (got != expected) {
    fprintf(stderr, "  got=%u expected=%u\n", (unsigned)got, (unsigned)expected);
  }
}

static void* test_vr_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* test_vr_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void test_vr_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

vr_font_config_t test_default_font_config(void) {
  vr_font_config_t cfg = {0};
  cfg.px_size = VR_FONT_DEFAULT_PX_SIZE;
  cfg.atlas_width = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  cfg.atlas_height = VR_FONT_DEFAULT_ATLAS_DIMENSION;
  cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  cfg.allocator.alloc = test_vr_alloc;
  cfg.allocator.realloc = test_vr_realloc;
  cfg.allocator.free = test_vr_free;
  cfg.gl.create_texture = NULL;
  cfg.gl.update_texture = NULL;
  cfg.gl.destroy_texture = NULL;
  cfg.gl.user = NULL;
  return cfg;
}

uint8_t* test_read_file_bytes(const char* path, size_t* out_size) {
  if (!path || !out_size) return NULL;
  *out_size = 0;
  FILE* file = fopen(path, "rb");
  if (!file) return NULL;
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  long size = ftell(file);
  if (size <= 0) {
    fclose(file);
    return NULL;
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return NULL;
  }
  uint8_t* data = (uint8_t*)malloc((size_t)size);
  if (!data) {
    fclose(file);
    return NULL;
  }
  size_t read = fread(data, 1u, (size_t)size, file);
  fclose(file);
  if (read != (size_t)size) {
    free(data);
    return NULL;
  }
  *out_size = (size_t)size;
  return data;
}

const char* test_font_path(void) {
  const char* override = getenv("VR_FONT_TEST_PATH");
  if (override != NULL && override[0] != '\0') {
    return override;
  }

#ifndef VRFONT_PROJECT_ROOT
#define VRFONT_PROJECT_ROOT "."
#endif

  static char path[1024];
  int written = snprintf(path, sizeof(path), "%s/%s", VRFONT_PROJECT_ROOT, TEST_FONT_PATH);
  if (written <= 0 || written >= (int)sizeof(path)) {
    return TEST_FONT_PATH;
  }
  return path;
}

vr_font_face_t* test_open_face(const char* path) {
  vr_font_config_t cfg = test_default_font_config();
  vr_font_face_t* face = NULL;
  size_t size = 0;
  uint8_t* data = test_read_file_bytes(path, &size);
  if (!data) return NULL;
  vr_status_t st = vr_font_face_create_from_memory(&face, data, size, &cfg);
  free(data);
  if (st != VR_OK) {
    return NULL;
  }
  return face;
}

vr_font_face_t* test_open_default_face(void) {
  return test_open_face(test_font_path());
}

void test_close_face(vr_font_face_t* face) {
  vr_font_face_destroy(face);
}

uint32_t* test_ascii_codepoints(const char* text, size_t* out_count) {
  if (!text || !out_count) return NULL;

  *out_count = 0;
  size_t len = strlen(text);
  if (len == 0) {
    return NULL;
  }

  uint32_t* cps = (uint32_t*)malloc(len * sizeof(uint32_t));
  if (!cps) {
    return NULL;
  }

  for (size_t i = 0; i < len; ++i) {
    cps[i] = (uint32_t)(unsigned char)text[i];
  }

  *out_count = len;
  return cps;
}

void test_free_codepoints(uint32_t* cps) {
  free(cps);
}

void test_report_results(void) {
  if (g_tests_failed > 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_tests_failed, g_tests_total);
    return;
  }
  fprintf(stdout, "OK %d checks passed\n", g_tests_total);
}
