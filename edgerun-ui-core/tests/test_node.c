#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>

static void* node_vr_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void* node_vr_realloc(void* user, void* ptr, size_t old_size, size_t new_size, size_t align) {
  (void)user;
  (void)old_size;
  (void)align;
  return realloc(ptr, new_size);
}

static void node_vr_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
}

static vr_font_allocator_t node_vr_allocator(void) {
  vr_font_allocator_t allocator = {0};
  allocator.alloc = node_vr_alloc;
  allocator.realloc = node_vr_realloc;
  allocator.free = node_vr_free;
  return allocator;
}

static unsigned char* node_read_file(const char* path, size_t* out_size) {
  if (out_size) *out_size = 0u;
  FILE* file = fopen(path, "rb");
  if (!file) return NULL;
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  long len = ftell(file);
  if (len <= 0) {
    fclose(file);
    return NULL;
  }
  rewind(file);
  unsigned char* data = (unsigned char*)malloc((size_t)len);
  if (!data) {
    fclose(file);
    return NULL;
  }
  size_t read = fread(data, 1u, (size_t)len, file);
  fclose(file);
  if (read != (size_t)len) {
    free(data);
    return NULL;
  }
  if (out_size) *out_size = (size_t)len;
  return data;
}

static vr_font_face_t* node_open_test_font(void) {
  size_t font_size = 0u;
  unsigned char* font_data = node_read_file(ER_UI_REPO_ROOT "/varfont/fonts/Geist[wght].ttf", &font_size);
  expect_true(font_data != NULL && font_size > 0u, "node: bundled variable font loads");
  if (!font_data) return NULL;
  vr_font_config_t cfg = {0};
  cfg.px_size = 14.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = node_vr_allocator();
  vr_font_face_t* face = NULL;
  expect_status((er_ui_status_t)vr_font_face_create_from_memory(&face, font_data, font_size, &cfg), (er_ui_status_t)VR_OK,
                "node: variable font opens from memory");
  free(font_data);
  return face;
}

void run_node_tests(void) {
  er_ui_node_t root = er_ui_node_card();
  er_ui_node_set_padding(&root, 10.0f);
  er_ui_node_set_gap(&root, 8.0f);
  er_ui_node_t title = er_ui_node_text("Create project");
  er_ui_node_t row = er_ui_node_row();
  er_ui_node_set_gap(&row, 6.0f);
  er_ui_node_t badge = er_ui_node_badge("Native", ER_UI_SHADCN_BADGE_SECONDARY);
  er_ui_node_t button = er_ui_node_button("Deploy", 8001u, ER_UI_SHADCN_BUTTON_DEFAULT);
  expect_status(er_ui_node_add_child(&row, &badge), ER_UI_OK, "node: row accepts badge child");
  expect_status(er_ui_node_add_child(&row, &button), ER_UI_OK, "node: row accepts button child");
  expect_status(er_ui_node_add_child(&root, &title), ER_UI_OK, "node: card accepts title child");
  expect_status(er_ui_node_add_child(&root, &row), ER_UI_OK, "node: card accepts row child");

  er_ui_node_t full = er_ui_node_row();
  er_ui_node_t children[ER_UI_NODE_MAX_CHILDREN + 1u];
  for (size_t i = 0u; i < ER_UI_NODE_MAX_CHILDREN; ++i) {
    children[i] = er_ui_node_skeleton();
    expect_status(er_ui_node_add_child(&full, &children[i]), ER_UI_OK, "node: fixed child slot accepts within capacity");
  }
  children[ER_UI_NODE_MAX_CHILDREN] = er_ui_node_skeleton();
  expect_status(er_ui_node_add_child(&full, &children[ER_UI_NODE_MAX_CHILDREN]), ER_UI_ERR_OOM, "node: fixed child capacity rejects overflow");

  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_palette_slate_950(), er_ui_test_allocator()), ER_UI_OK, "node: scene init succeeds");
  vr_font_face_t* face = node_open_test_font();
  if (face) {
    er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
    expect_status(er_ui_node_render(&root, &scene, face, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_OK,
                  "node: card tree renders");
    expect_true(scene.rect_count > 0u, "node: render emits rect geometry");
    expect_true(scene.hit_count > 0u, "node: render emits hit targets");
    expect_true(scene.text_quad_count > 0u, "node: render uses variable font text");
    expect_status(er_ui_node_render(&root, &scene, NULL, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_ERR_INVALID_ARGUMENT,
                  "node: missing variable font is rejected");
    vr_font_face_destroy(face);
  }
  er_ui_scene_destroy(&scene);
}
