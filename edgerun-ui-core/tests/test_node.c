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

  er_ui_a11y_node_t a11y = {0};
  expect_status(er_ui_node_accessibility(&button, &a11y), ER_UI_OK, "node: button accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_BUTTON, "node: button accessibility role");
  expect_true(a11y.has_id && a11y.id == 8001u, "node: button accessibility id");
  expect_true(a11y.label == button.label, "node: button accessibility label is borrowed");

  er_ui_node_t checked = er_ui_node_checkbox("Remember", true, 8002u);
  expect_status(er_ui_node_accessibility(&checked, &a11y), ER_UI_OK, "node: checkbox accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_CHECKBOX, "node: checkbox accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_CHECKED) != 0u, "node: checkbox accessibility checked state");

  er_ui_node_t field_a11y = er_ui_node_field("Email", "name@example.com", 8003u);
  expect_status(er_ui_node_accessibility(&field_a11y, &a11y), ER_UI_OK, "node: field accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_TEXTBOX, "node: field accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_HAS_VALUE) != 0u, "node: field accessibility value state");
  expect_true(a11y.value == field_a11y.value, "node: field accessibility value is borrowed");

  er_ui_node_t tree_a11y = er_ui_node_tree_item("src", "expanded", 1u, true, 8004u);
  expect_status(er_ui_node_accessibility(&tree_a11y, &a11y), ER_UI_OK, "node: tree accessibility maps");
  expect_size(a11y.role, ER_UI_A11Y_LIST_ITEM, "node: tree accessibility role");
  expect_true((a11y.states & ER_UI_A11Y_STATE_EXPANDED) != 0u, "node: tree accessibility expanded state");
  expect_true(er_ui_a11y_role_label(a11y.role) != NULL, "node: accessibility role has stable label");

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
    er_ui_node_t field = er_ui_node_field("Email", "name@example.com", 8400u);
    er_ui_node_t text_area = er_ui_node_text_area("Message", "Type your message here.", 8401u);
    const char* const tab_labels[] = {"Account", "Billing", "Team"};
    er_ui_node_t tabs = er_ui_node_tabs(tab_labels, 3u, 1u, 8500u);
    const char* const chart_labels[] = {"Jan", "Feb", "Mar"};
    const float chart_values[] = {0.25f, 0.72f, 0.54f};
    er_ui_node_t chart = er_ui_node_bar_chart("Visitors", chart_labels, chart_values, 3u, 8600u, 1u);
    er_ui_node_t command = er_ui_node_command_palette("Search components...", 8700u);
    er_ui_node_t tree_item = er_ui_node_tree_item("src", "expanded", 1u, true, 8800u);
    er_ui_node_t section = er_ui_node_section("Proof", "Verified rows");
    er_ui_node_t identity = er_ui_node_identity_card("Ken", "browser-node", "personal", 8801u);
    er_ui_node_t contact = er_ui_node_contact_card("Ada", "publisher", 8802u);
    er_ui_node_t thread = er_ui_node_thread_row("Sync complete", "Drive import finished", true, 8803u);
    er_ui_node_t attachment = er_ui_node_attachment_preview("manifest.rkyv", "package manifest", 8804u);
    er_ui_node_t grant = er_ui_node_capability_grant_row("Mail", "contacts:read", "granted", 8805u);
    er_ui_node_t proof = er_ui_node_proof_event_row("Package hash", "b3:abc123", "verified", 8806u);
    const char* const route_hops[] = {"browser", "admission", "relay"};
    er_ui_node_t route = er_ui_node_route_path("Admission route", route_hops, 3u);
    er_ui_node_t package = er_ui_node_package_card("Docs", "cache-ok", "b3:def456", 8807u);
    er_ui_node_t receipt = er_ui_node_receipt_row("Retrieval", "4 units", "settled", 8808u);
    er_ui_node_t panel = er_ui_node_panel_header("Dashboard", "Reusable UI primitives", "Run", 8809u);
    er_ui_node_t metric = er_ui_node_metric_card("Budget", "184", "units reserved", true, 0.64f, theme.colors.accent);
    er_ui_node_t transaction = er_ui_node_transaction_row("Storage", "verified retrieval", "today", "8 units", false, 8810u);
    er_ui_node_t menu = er_ui_node_menu_item("Verify package", "content hash", "new", true, theme.colors.accent, 8811u);
    er_ui_node_t control = er_ui_node_control_row("Cache package", "avoid repeated retrieval", "enabled", 8812u);
    er_ui_node_t grid = er_ui_node_grid(2u);
    er_ui_node_set_gap(&grid, 4.0f);
    er_ui_node_t grid_badge_a = er_ui_node_badge("One", ER_UI_SHADCN_BADGE_DEFAULT);
    er_ui_node_t grid_badge_b = er_ui_node_badge("Two", ER_UI_SHADCN_BADGE_SECONDARY);
    er_ui_node_t grid_badge_c = er_ui_node_badge("Three", ER_UI_SHADCN_BADGE_OUTLINE);
    expect_status(er_ui_node_add_child(&grid, &grid_badge_a), ER_UI_OK, "node: grid accepts first child");
    expect_status(er_ui_node_add_child(&grid, &grid_badge_b), ER_UI_OK, "node: grid accepts second child");
    expect_status(er_ui_node_add_child(&grid, &grid_badge_c), ER_UI_OK, "node: grid accepts third child");
    er_ui_node_t scroll = er_ui_node_scroll_area(20.0f, 8813u);
    er_ui_node_set_gap(&scroll, 4.0f);
    er_ui_node_t scroll_a = er_ui_node_list_row("Top", "scrolled", 8814u, false);
    er_ui_node_t scroll_b = er_ui_node_list_row("Bottom", "visible", 8815u, true);
    expect_status(er_ui_node_add_child(&scroll, &scroll_a), ER_UI_OK, "node: scroll accepts first child");
    expect_status(er_ui_node_add_child(&scroll, &scroll_b), ER_UI_OK, "node: scroll accepts second child");
    er_ui_node_t spacer = er_ui_node_spacer();
    er_ui_node_t tooltip = er_ui_node_tooltip("Verify package");
    er_ui_node_t dialog = er_ui_node_dialog("Run network app", "Verify signed package bytes first.", theme.colors.accent);
    er_ui_node_t ring = er_ui_node_progress_ring(0.58f, theme.colors.success);
    er_ui_node_t reorderable = er_ui_node_list_row("Drag me", "reorderable", 8816u, false);
    er_ui_node_set_reorderable(&reorderable, 42u, 8816u, 3u);

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
    expect_status(er_ui_node_render(&field, &scene, face, er_ui_bounds(0.0f, 726.0f, 240.0f, 58.0f), theme), ER_UI_OK, "node: field renders");
    expect_status(er_ui_node_render(&text_area, &scene, face, er_ui_bounds(0.0f, 796.0f, 280.0f, 84.0f), theme), ER_UI_OK,
                  "node: text area renders");
    expect_status(er_ui_node_render(&tabs, &scene, face, er_ui_bounds(0.0f, 892.0f, 300.0f, 38.0f), theme), ER_UI_OK, "node: tabs render");
    expect_status(er_ui_node_render(&chart, &scene, face, er_ui_bounds(0.0f, 942.0f, 320.0f, 160.0f), theme), ER_UI_OK,
                  "node: bar chart renders");
    expect_status(er_ui_node_render(&command, &scene, face, er_ui_bounds(0.0f, 1114.0f, 300.0f, 46.0f), theme), ER_UI_OK,
                  "node: command palette renders");
    expect_status(er_ui_node_render(&tree_item, &scene, face, er_ui_bounds(0.0f, 1172.0f, 320.0f, 42.0f), theme), ER_UI_OK,
                  "node: tree item renders");
    expect_status(er_ui_node_render(&section, &scene, face, er_ui_bounds(0.0f, 1226.0f, 320.0f, 34.0f), theme), ER_UI_OK,
                  "node: section renders");
    expect_status(er_ui_node_render(&identity, &scene, face, er_ui_bounds(0.0f, 1272.0f, 320.0f, 110.0f), theme), ER_UI_OK,
                  "node: identity card renders");
    expect_status(er_ui_node_render(&contact, &scene, face, er_ui_bounds(0.0f, 1394.0f, 320.0f, 64.0f), theme), ER_UI_OK,
                  "node: contact card renders");
    expect_status(er_ui_node_render(&thread, &scene, face, er_ui_bounds(0.0f, 1470.0f, 320.0f, 58.0f), theme), ER_UI_OK,
                  "node: thread row renders");
    expect_status(er_ui_node_render(&attachment, &scene, face, er_ui_bounds(0.0f, 1540.0f, 320.0f, 64.0f), theme), ER_UI_OK,
                  "node: attachment preview renders");
    expect_status(er_ui_node_render(&grant, &scene, face, er_ui_bounds(0.0f, 1616.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: capability grant row renders");
    expect_status(er_ui_node_render(&proof, &scene, face, er_ui_bounds(0.0f, 1686.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: proof event row renders");
    expect_status(er_ui_node_render(&route, &scene, face, er_ui_bounds(0.0f, 1756.0f, 360.0f, 86.0f), theme), ER_UI_OK,
                  "node: route path renders");
    expect_status(er_ui_node_render(&package, &scene, face, er_ui_bounds(0.0f, 1854.0f, 320.0f, 110.0f), theme), ER_UI_OK,
                  "node: package card renders");
    expect_status(er_ui_node_render(&receipt, &scene, face, er_ui_bounds(0.0f, 1976.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: receipt row renders");
    expect_status(er_ui_node_render(&panel, &scene, face, er_ui_bounds(0.0f, 2046.0f, 360.0f, 56.0f), theme), ER_UI_OK,
                  "node: panel header renders");
    expect_status(er_ui_node_render(&metric, &scene, face, er_ui_bounds(0.0f, 2114.0f, 220.0f, 132.0f), theme), ER_UI_OK,
                  "node: metric card renders");
    expect_status(er_ui_node_render(&transaction, &scene, face, er_ui_bounds(0.0f, 2258.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: transaction row renders");
    expect_status(er_ui_node_render(&menu, &scene, face, er_ui_bounds(0.0f, 2328.0f, 260.0f, 58.0f), theme), ER_UI_OK,
                  "node: menu item renders");
    expect_status(er_ui_node_render(&control, &scene, face, er_ui_bounds(0.0f, 2398.0f, 360.0f, 58.0f), theme), ER_UI_OK,
                  "node: control row renders");
    expect_status(er_ui_node_render(&grid, &scene, face, er_ui_bounds(0.0f, 2468.0f, 260.0f, 80.0f), theme), ER_UI_OK,
                  "node: grid renders children");
    expect_status(er_ui_node_render(&scroll, &scene, face, er_ui_bounds(0.0f, 2560.0f, 260.0f, 64.0f), theme), ER_UI_OK,
                  "node: scroll area renders clipped children");
    expect_status(er_ui_node_render(&spacer, &scene, face, er_ui_bounds(0.0f, 2636.0f, 24.0f, 24.0f), theme), ER_UI_OK,
                  "node: spacer renders as no-op");
    expect_status(er_ui_node_render(&tooltip, &scene, face, er_ui_bounds(0.0f, 2672.0f, 180.0f, 34.0f), theme), ER_UI_OK,
                  "node: tooltip renders");
    expect_status(er_ui_node_render(&dialog, &scene, face, er_ui_bounds(0.0f, 2718.0f, 360.0f, 140.0f), theme), ER_UI_OK,
                  "node: dialog renders");
    expect_status(er_ui_node_render(&ring, &scene, face, er_ui_bounds(0.0f, 2870.0f, 48.0f, 48.0f), theme), ER_UI_OK,
                  "node: progress ring renders");
    size_t drag_sources_before = scene.drag_source_count;
    size_t drop_targets_before = scene.drop_target_count;
    expect_status(er_ui_node_render(&reorderable, &scene, face, er_ui_bounds(0.0f, 2930.0f, 260.0f, 52.0f), theme), ER_UI_OK,
                  "node: reorderable row renders");
    expect_size(scene.drag_source_count, drag_sources_before + 1u, "node: reorderable emits drag source");
    expect_size(scene.drop_target_count, drop_targets_before + 1u, "node: reorderable emits drop target");
    expect_size(scene.drag_sources[drag_sources_before].scope_id, 42u, "node: drag source scope is preserved");
    expect_size(scene.drag_sources[drag_sources_before].item_id, 8816u, "node: drag source item is preserved");
    expect_size(scene.drop_targets[drop_targets_before].index, 3u, "node: drop target index is preserved");

    expect_true(scene.rect_count > 0u, "node: render emits rect geometry");
    expect_true(scene.hit_count > 0u, "node: render emits hit targets");
    expect_true(scene.text_quad_count > 0u, "node: render uses variable font text");
    expect_status(er_ui_node_render(&root, &scene, NULL, er_ui_bounds(0.0f, 0.0f, 320.0f, 160.0f), theme), ER_UI_ERR_INVALID_ARGUMENT,
                  "node: missing variable font is rejected");
    vr_font_face_destroy(face);
  }
  er_ui_scene_destroy(&scene);
}
