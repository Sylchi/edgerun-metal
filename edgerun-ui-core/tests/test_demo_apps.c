#include "er_ui_demo_apps.h"
#include "test_common.h"

static const er_ui_color4_t ER_TEST_DEMO_BG = {0.01f, 0.012f, 0.015f, 1.0f};
static const size_t ER_TEST_DEMO_APP_SURFACE_COUNT = 3u;
static const size_t ER_TEST_DEMO_APP_HITS = 6u;

static void test_demo_apps_state_and_surface_switching(void) {
  er_ui_demo_apps_state_t apps = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_scene_t scene = {0};
  er_ui_bounds_t focused = {0};
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  bool changed = false;

  vr_font_face_t* font = er_ui_test_open_font(24.0f, "demo apps: bundled font bytes load", "demo apps: font opens");
  if (!font) return;

  expect_status(er_ui_demo_apps_state_init(&apps, er_ui_test_allocator()), ER_UI_OK, "demo apps: state init succeeds");
  expect_size(er_ui_workspace_surface_count(&apps.shell), ER_TEST_DEMO_APP_SURFACE_COUNT, "demo apps: three surfaces are registered");
  expect_u32(er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_DEMO_APP_LEDGER_ID, "demo apps: ledger starts focused");
  expect_true(er_ui_workspace_focused_surface_bounds(&apps.shell, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), &focused),
              "demo apps: focused surface bounds resolve");
  expect_true(focused.w > 0.0f && focused.h > 0.0f, "demo apps: focused surface bounds are positive");

  expect_status(er_ui_runtime_state_init_with_allocator(&runtime, er_ui_test_allocator()), ER_UI_OK, "demo apps: runtime init succeeds");
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_DEMO_BG, er_ui_test_allocator()), ER_UI_OK, "demo apps: scene init succeeds");
  expect_status(er_ui_demo_apps_emit_scene(&apps, &scene, font, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), theme), ER_UI_OK,
                "demo apps: scene emits");

  er_ui_scene_stats_t stats = er_ui_scene_stats(&scene);
  expect_true(stats.rects > 0u, "demo apps: scene emits rects");
  expect_size(stats.hits, ER_TEST_DEMO_APP_HITS, "demo apps: scene emits expected hits");
  expect_true(stats.text_quads > 0u, "demo apps: scene emits text");

  er_ui_action_t down = er_ui_runtime_pointer_down(&runtime, &scene, 40.0f, 138.0f);
  expect_size(down.kind, ER_UI_ACTION_FOCUSED, "demo apps: nav pointer down focuses");
  er_ui_action_t up = er_ui_runtime_pointer_up(&runtime, &scene, 40.0f, 138.0f);
  expect_size(up.kind, ER_UI_ACTION_TAB_SELECTED, "demo apps: nav pointer up selects");
  expect_status(er_ui_demo_apps_apply_action(&apps, up, &changed), ER_UI_OK, "demo apps: selected tab action applies");
  expect_true(changed, "demo apps: tab action reports state change");
  expect_u32(er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_DEMO_APP_PAYMENTS_ID, "demo apps: payments surface becomes focused");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_demo_apps_state_destroy(&apps);
  vr_font_face_destroy(font);
}

void run_demo_apps_tests(void) {
  test_demo_apps_state_and_surface_switching();
}
