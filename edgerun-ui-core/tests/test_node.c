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

    er_ui_node_t alert = er_ui_node_alert("Heads up", "Reusable components stay in UI core.", theme.colors.warning);
    er_ui_node_t avatar = er_ui_node_avatar("ER", theme.colors.accent, true);
    er_ui_node_t progress = er_ui_node_progress(0.66f);
    er_ui_node_t switch_node = er_ui_node_switch(true, 8002u);
    const char* const breadcrumb_labels[] = {"Docs", "Components", "Button"};
    er_ui_node_t breadcrumb = er_ui_node_breadcrumb(breadcrumb_labels, 3u, 2u, 8100u);
    const char* const table_headers[] = {"Invoice", "Status"};
    const char* const table_cells[] = {"INV001", "Paid", "INV002", "Pending"};
    er_ui_node_t table = er_ui_node_table(table_headers, 2u, table_cells, 2u, 8200u);
    er_ui_node_t toast = er_ui_node_toast("Scheduled", theme.colors.accent);
    er_ui_node_t empty = er_ui_node_empty("No results", "Try another filter.");
    er_ui_node_t list_row = er_ui_node_list_row("Billing", "Command B", 8300u, true);

    expect_status(er_ui_node_render(&alert, &scene, face, er_ui_bounds(0.0f, 170.0f, 360.0f, 76.0f), theme), ER_UI_OK, "node: alert renders");
    expect_status(er_ui_node_render(&avatar, &scene, face, er_ui_bounds(0.0f, 254.0f, 42.0f, 42.0f), theme), ER_UI_OK, "node: avatar renders");
    expect_status(er_ui_node_render(&progress, &scene, face, er_ui_bounds(54.0f, 268.0f, 180.0f, 8.0f), theme), ER_UI_OK,
                  "node: progress renders");
    expect_status(er_ui_node_render(&switch_node, &scene, face, er_ui_bounds(246.0f, 262.0f, 44.0f, 24.0f), theme), ER_UI_OK,
                  "node: switch renders");
    expect_status(er_ui_node_render(&breadcrumb, &scene, face, er_ui_bounds(0.0f, 308.0f, 320.0f, 34.0f), theme), ER_UI_OK,
                  "node: breadcrumb renders");
    expect_status(er_ui_node_render(&table, &scene, face, er_ui_bounds(0.0f, 354.0f, 320.0f, 112.0f), theme), ER_UI_OK, "node: table renders");
    expect_status(er_ui_node_render(&toast, &scene, face, er_ui_bounds(0.0f, 478.0f, 260.0f, 48.0f), theme), ER_UI_OK, "node: toast renders");
    expect_status(er_ui_node_render(&empty, &scene, face, er_ui_bounds(0.0f, 538.0f, 280.0f, 120.0f), theme), ER_UI_OK, "node: empty renders");
    expect_status(er_ui_node_render(&list_row, &scene, face, er_ui_bounds(0.0f, 670.0f, 220.0f, 44.0f), theme), ER_UI_OK,
                  "node: list row renders");

    expect_true(scene.rect_count > 0u, "node: render emits rect geometry");
    expect_true(scene.hit_count > 0u, "node: render emits hit targets");
    expect_true(scene.text_quad_count > 0u, "node: render uses variable font text");
    expect_status(er_ui_node_render(&root, &scene, NULL, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_ERR_INVALID_ARGUMENT,
                  "node: missing variable font is rejected");
    vr_font_face_destroy(face);
  }
  er_ui_scene_destroy(&scene);
}
