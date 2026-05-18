#include "er_ui_ledger_app.h"
#include "test_common.h"

static const er_ui_color4_t ER_TEST_LEDGER_BG = {0.01f, 0.012f, 0.015f, 1.0f};
static const size_t ER_TEST_LEDGER_APP_SURFACE_COUNT = 3u;
static const size_t ER_TEST_LEDGER_APP_HITS = 6u;
static const size_t ER_TEST_LEDGER_ACCESS_HITS = 4u;
static const size_t ER_TEST_LEDGER_PAYMENTS_HITS = 4u;
static const uint32_t ER_TEST_LEDGER_ACTION_BASE = 0xED024000u;
static const uint32_t ER_TEST_LEDGER_INVEST_BUTTON_ID = ER_TEST_LEDGER_ACTION_BASE + 2u;
static const uint32_t ER_TEST_LEDGER_SAVE_THRESHOLD_BUTTON_ID = ER_TEST_LEDGER_ACTION_BASE + 8u;
static const float ER_TEST_LEDGER_BUTTON_LABEL_MIN_CENTER_X = 0.25f;
static const er_ui_bounds_t ER_TEST_LEDGER_COMPACT_BOUNDS = {240.0f, 80.0f, 760.0f, 760.0f};
static const er_ui_bounds_t ER_TEST_LEDGER_STACKED_BOUNDS = {0.0f, 0.0f, 390.0f, 1100.0f};

static const er_ui_hit_t* test_ledger_find_hit(const er_ui_scene_t* scene, uint32_t id) {
  if (!scene) return NULL;
  for (size_t h = 0u; h < scene->hit_count; ++h) {
    if (scene->hits[h].id == id) return &scene->hits[h];
  }
  return NULL;
}

static bool test_ledger_hit_has_fill_rect(const er_ui_scene_t* scene, uint32_t id) {
  const er_ui_hit_t* hit = test_ledger_find_hit(scene, id);
  if (!scene) return false;
  if (!hit) return false;
  for (size_t r = 0u; r < scene->rect_count; ++r) {
    const er_ui_rect_t* rect = &scene->rects[r];
    if (rect->mode == ER_UI_RECT_FILL &&
        rect->x == hit->x &&
        rect->y == hit->y &&
        rect->w == hit->w &&
        rect->h == hit->h) {
      return true;
    }
  }
  return false;
}

static bool test_ledger_hit_label_starts_centered(const er_ui_scene_t* scene, uint32_t id) {
  const er_ui_hit_t* hit = test_ledger_find_hit(scene, id);
  if (!scene || !hit) return false;
  for (size_t q = 0u; q < scene->text_quad_count; ++q) {
    const er_ui_quad_t* quad = &scene->text_quads[q];
    bool overlaps_x = quad->x < hit->x + hit->w && quad->x + quad->w > hit->x;
    bool overlaps_y = quad->y < hit->y + hit->h && quad->y + quad->h > hit->y;
    if (overlaps_x && overlaps_y && quad->x >= hit->x + hit->w * ER_TEST_LEDGER_BUTTON_LABEL_MIN_CENTER_X) {
      return true;
    }
  }
  return false;
}

static bool test_ledger_hits_stay_inside(const er_ui_scene_t* scene, er_ui_bounds_t bounds) {
  if (!scene) return false;
  for (size_t h = 0u; h < scene->hit_count; ++h) {
    const er_ui_hit_t* hit = &scene->hits[h];
    if (hit->x < bounds.x || hit->y < bounds.y || hit->x + hit->w > bounds.x + bounds.w || hit->y + hit->h > bounds.y + bounds.h) return false;
  }
  return true;
}

static void test_ledger_app_state_and_surface_switching(void) {
  er_ui_ledger_app_state_t apps = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_scene_t scene = {0};
  er_ui_bounds_t focused = {0};
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  bool changed = false;

  vr_font_face_t* font = er_ui_test_open_font(24.0f, "ledger app: bundled font bytes load", "ledger app: font opens");
  if (!font) return;

  expect_status(er_ui_ledger_app_state_init(&apps, er_ui_test_allocator()), ER_UI_OK, "ledger app: state init succeeds");
  expect_size(er_ui_workspace_surface_count(&apps.shell), ER_TEST_LEDGER_APP_SURFACE_COUNT, "ledger app: three surfaces are registered");
  expect_u32(er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_LEDGER_APP_LEDGER_ID, "ledger app: ledger starts focused");
  expect_true(er_ui_workspace_focused_surface_bounds(&apps.shell, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), &focused),
              "ledger app: focused surface bounds resolve");
  expect_true(focused.w > 0.0f && focused.h > 0.0f, "ledger app: focused surface bounds are positive");

  expect_status(er_ui_runtime_state_init_with_allocator(&runtime, er_ui_test_allocator()), ER_UI_OK, "ledger app: runtime init succeeds");
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_LEDGER_BG, er_ui_test_allocator()), ER_UI_OK, "ledger app: scene init succeeds");
  expect_status(er_ui_ledger_app_emit_scene(&apps, &scene, font, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), theme), ER_UI_OK,
                "ledger app: scene emits");

  er_ui_scene_stats_t stats = er_ui_scene_stats(&scene);
  expect_true(stats.rects > 0u, "ledger app: scene emits rects");
  expect_size(stats.hits, ER_TEST_LEDGER_APP_HITS, "ledger app: scene emits expected hits");
  expect_true(stats.text_quads > 0u, "ledger app: scene emits text");
  expect_true(test_ledger_hit_has_fill_rect(&scene, ER_TEST_LEDGER_SAVE_THRESHOLD_BUTTON_ID),
              "ledger app: save threshold action is visibly rendered");
  expect_true(test_ledger_hit_has_fill_rect(&scene, ER_TEST_LEDGER_INVEST_BUTTON_ID),
              "ledger app: review order action is visibly rendered");
  expect_true(test_ledger_hit_label_starts_centered(&scene, ER_TEST_LEDGER_SAVE_THRESHOLD_BUTTON_ID),
              "ledger app: save threshold label is centered in button");
  expect_true(test_ledger_hit_label_starts_centered(&scene, ER_TEST_LEDGER_INVEST_BUTTON_ID),
              "ledger app: review order label is centered in button");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_ledger_app_emit_scene(&apps, &scene, font, ER_TEST_LEDGER_COMPACT_BOUNDS, theme), ER_UI_OK,
                "ledger app: compact offset scene emits");
  stats = er_ui_scene_stats(&scene);
  expect_size(stats.hits, ER_TEST_LEDGER_APP_HITS, "ledger app: compact scene emits expected hits");
  expect_true(test_ledger_hit_has_fill_rect(&scene, ER_TEST_LEDGER_SAVE_THRESHOLD_BUTTON_ID),
              "ledger app: compact save threshold action is visibly rendered");
  expect_true(test_ledger_hit_has_fill_rect(&scene, ER_TEST_LEDGER_INVEST_BUTTON_ID),
              "ledger app: compact review order action is visibly rendered");
  expect_true(test_ledger_hits_stay_inside(&scene, ER_TEST_LEDGER_COMPACT_BOUNDS), "ledger app: compact hits stay inside surface bounds");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_ledger_app_emit_scene(&apps, &scene, font, ER_TEST_LEDGER_STACKED_BOUNDS, theme), ER_UI_OK,
                "ledger app: stacked narrow scene emits");
  stats = er_ui_scene_stats(&scene);
  expect_size(stats.hits, ER_TEST_LEDGER_APP_HITS, "ledger app: stacked scene emits expected hits");
  expect_true(test_ledger_hits_stay_inside(&scene, ER_TEST_LEDGER_STACKED_BOUNDS), "ledger app: stacked hits stay inside surface bounds");

  expect_status(er_ui_workspace_focus_surface(&apps.shell, ER_UI_LEDGER_APP_ACCESS_ID), ER_UI_OK, "ledger app: access surface focuses");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_ledger_app_emit_scene(&apps, &scene, font, ER_TEST_LEDGER_STACKED_BOUNDS, theme), ER_UI_OK,
                "ledger app: stacked access scene emits");
  stats = er_ui_scene_stats(&scene);
  expect_size(stats.hits, ER_TEST_LEDGER_ACCESS_HITS, "ledger app: stacked access scene emits expected hits");
  expect_true(test_ledger_hits_stay_inside(&scene, ER_TEST_LEDGER_STACKED_BOUNDS), "ledger app: stacked access hits stay inside surface bounds");
  expect_status(er_ui_workspace_focus_surface(&apps.shell, ER_UI_LEDGER_APP_LEDGER_ID), ER_UI_OK, "ledger app: dashboard refocuses");

  expect_status(er_ui_workspace_focus_surface(&apps.shell, ER_UI_LEDGER_APP_PAYMENTS_ID), ER_UI_OK, "ledger app: payments surface focuses");
  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_ledger_app_emit_scene(&apps, &scene, font, ER_TEST_LEDGER_STACKED_BOUNDS, theme), ER_UI_OK,
                "ledger app: stacked payments scene emits");
  stats = er_ui_scene_stats(&scene);
  expect_size(stats.hits, ER_TEST_LEDGER_PAYMENTS_HITS, "ledger app: stacked payments scene emits expected hits");
  expect_true(test_ledger_hits_stay_inside(&scene, ER_TEST_LEDGER_STACKED_BOUNDS), "ledger app: stacked payments hits stay inside surface bounds");
  expect_status(er_ui_workspace_focus_surface(&apps.shell, ER_UI_LEDGER_APP_LEDGER_ID), ER_UI_OK, "ledger app: dashboard refocuses again");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_ledger_app_emit_scene(&apps, &scene, font, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), theme), ER_UI_OK,
                "ledger app: scene re-emits for pointer interaction");

  er_ui_action_t down = er_ui_runtime_pointer_down(&runtime, &scene, 40.0f, 138.0f);
  expect_size(down.kind, ER_UI_ACTION_FOCUSED, "ledger app: nav pointer down focuses");
  er_ui_action_t up = er_ui_runtime_pointer_up(&runtime, &scene, 40.0f, 138.0f);
  expect_size(up.kind, ER_UI_ACTION_TAB_SELECTED, "ledger app: nav pointer up selects");
  expect_status(er_ui_ledger_app_apply_action(&apps, up, &changed), ER_UI_OK, "ledger app: selected tab action applies");
  expect_true(changed, "ledger app: tab action reports state change");
  expect_u32(er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_LEDGER_APP_PAYMENTS_ID, "ledger app: payments surface becomes focused");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_ledger_app_state_destroy(&apps);
  vr_font_face_destroy(font);
}

void run_ledger_app_tests(void) {
  test_ledger_app_state_and_surface_switching();
}
