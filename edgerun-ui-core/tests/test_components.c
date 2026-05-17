#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>

static void* component_vr_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* component_vr_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void component_vr_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static vr_font_allocator_t component_vr_allocator(void) {
  vr_font_allocator_t allocator = {0};
  allocator.alloc = component_vr_alloc;
  allocator.realloc = component_vr_realloc;
  allocator.free = component_vr_free;
  return allocator;
}

static unsigned char* component_read_file(const char* path, size_t* out_size) {
  if (!path || !out_size) return NULL;
  *out_size = 0u;
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
  unsigned char* data = (unsigned char*)malloc((size_t)size);
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

void run_component_tests(void) {
  er_ui_scene_t scene = {0};
  er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
  expect_status(er_ui_scene_init_with_allocator(&scene, theme.colors.bg, er_ui_test_allocator()), ER_UI_OK, "components: scene init succeeds");

  size_t font_size = 0u;
  unsigned char* font_data = component_read_file(ER_UI_REPO_ROOT "/varfont/fonts/Geist[wght].ttf", &font_size);
  expect_true(font_data != NULL && font_size > 0u, "components: bundled variable font loads");
  if (!font_data) {
    er_ui_scene_destroy(&scene);
    return;
  }

  vr_font_config_t cfg = {0};
  cfg.px_size = 16.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = component_vr_allocator();

  vr_font_face_t* face = NULL;
  expect_status((er_ui_status_t)vr_font_face_create_from_memory(&face, font_data, font_size, &cfg), (er_ui_status_t)VR_OK,
                "components: variable font opens from memory");
  free(font_data);
  if (!face) {
    er_ui_scene_destroy(&scene);
    return;
  }

  er_ui_painter_t painter = er_ui_painter(&scene);
  expect_status(er_ui_component_button(&painter, face, er_ui_bounds(8.0f, 8.0f, 120.0f, 36.0f), 10u, "Primary",
                                       ER_UI_COMPONENT_BUTTON_PRIMARY, theme),
                ER_UI_OK, "components: button emits");
  expect_status(er_ui_component_input(&painter, face, er_ui_bounds(8.0f, 54.0f, 180.0f, 36.0f), 11u, "", "Identity name", theme), ER_UI_OK,
                "components: input emits");
  expect_status(er_ui_component_checkbox(&painter, face, er_ui_bounds(8.0f, 100.0f, 220.0f, 30.0f), 12u, "Cache verified bytes", true, theme),
                ER_UI_OK, "components: checkbox emits");
  expect_true(scene.hit_count >= 3u, "components: basic controls emit hits");
  expect_true(scene.text_quad_count > 0u, "components: basic controls emit variable font text");

  er_ui_scene_clear_commands(&scene);
  er_ui_shadcn_showcase_stats_t stats = {0};
  expect_status(er_ui_shadcn_showcase_emit(&scene, face, er_ui_bounds(0.0f, 0.0f, 760.0f, 560.0f), theme, 1000u, &stats), ER_UI_OK,
                "showcase: shadcn reference emits");
  expect_true(stats.component_count >= 20u, "showcase: enough component examples are counted");
  expect_size(stats.button_count, 5u, "showcase: button variants are counted");
  expect_true(stats.text_label_count >= 18u, "showcase: text labels are counted");
  expect_true(scene.rect_count >= 25u, "showcase: visual rect commands emit");
  expect_true(scene.hit_count >= 13u, "showcase: interactive hit commands emit");
  expect_true(scene.text_quad_count > 80u, "showcase: variable font text quads emit");
  expect_status(er_ui_shadcn_showcase_emit(&scene, NULL, er_ui_bounds(0.0f, 0.0f, 760.0f, 560.0f), theme, 1000u, NULL),
                ER_UI_ERR_INVALID_ARGUMENT, "showcase: missing variable font is rejected");

  vr_font_face_destroy(face);
  er_ui_scene_destroy(&scene);
}
