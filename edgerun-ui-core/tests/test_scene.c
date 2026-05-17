#include "er_ui_scene.h"
#include "test_common.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int g_tests_total = 0;
int g_tests_failed = 0;

static const float ER_TEST_EPSILON = 0.0001f;
static const er_ui_color4_t ER_TEST_BG = {0.01f, 0.012f, 0.015f, 1.0f};
static const er_ui_color4_t ER_TEST_TEXT = {0.94f, 0.96f, 0.99f, 1.0f};

void expect_true(bool condition, const char* name) {
  g_tests_total++;
  if (!condition) {
    g_tests_failed++;
    fprintf(stderr, "FAIL: %s\n", name);
  }
}

void expect_status(er_ui_status_t got, er_ui_status_t expected, const char* name) {
  expect_true(got == expected, name);
}

void expect_size(size_t got, size_t expected, const char* name) {
  expect_true(got == expected, name);
}

void expect_u32(uint32_t got, uint32_t expected, const char* name) {
  expect_true(got == expected, name);
}

void expect_float(float got, float expected, const char* name) {
  expect_true(fabsf(got - expected) <= ER_TEST_EPSILON, name);
}

void expect_string(const char* got, const char* expected, const char* name) {
  expect_true(got != NULL && expected != NULL && strcmp(got, expected) == 0, name);
}

static void* test_alloc(void* user, size_t size, size_t align) {
  (void)user;
  (void)align;
  return malloc(size);
}

static void test_free(void* user, void* ptr, size_t size, size_t align) {
  (void)user;
  (void)size;
  (void)align;
  free(ptr);
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

er_ui_allocator_t er_ui_test_allocator(void) {
  er_ui_allocator_t allocator = {0};
  allocator.alloc = test_alloc;
  allocator.free = test_free;
  return allocator;
}

static vr_font_allocator_t er_ui_test_vr_allocator(void) {
  vr_font_allocator_t allocator = {0};
  allocator.alloc = test_vr_alloc;
  allocator.realloc = test_vr_realloc;
  allocator.free = test_vr_free;
  return allocator;
}

static unsigned char* er_ui_test_read_file(const char* path, size_t* out_size) {
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

void run_runtime_tests(void);

static void test_scene_stats_and_clear(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "scene: init succeeds");

  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 10.0f, 10.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "scene: push rect succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, 7u, 1.0f, 1.0f, 8.0f, 8.0f)), ER_UI_OK,
                "scene: push hit succeeds");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_opacity(90u, 0.0f, 1.0f, 120u)), ER_UI_OK,
                "scene: push transition succeeds");
  bool pushed = false;
  expect_status(er_ui_scene_push_clip(&scene, er_ui_clip(0.0f, 0.0f, 5.0f, 5.0f), &pushed), ER_UI_OK,
                "scene: push clip succeeds");
  expect_true(pushed, "scene: valid clip is pushed");

  er_ui_scene_stats_t stats = er_ui_scene_stats(&scene);
  expect_size(stats.rects, 1u, "scene: stats track rects");
  expect_size(stats.hits, 1u, "scene: stats track hits");
  expect_size(stats.transitions, 1u, "scene: stats track transitions");
  expect_size(stats.clips, 1u, "scene: stats track clips");

  er_ui_scene_clear_commands(&scene);
  stats = er_ui_scene_stats(&scene);
  expect_size(stats.rects, 0u, "scene: clear removes rects");
  expect_size(stats.hits, 0u, "scene: clear removes hits");
  expect_size(stats.transitions, 0u, "scene: clear removes transitions");
  expect_size(stats.clips, 0u, "scene: clear removes clips");
  expect_float(scene.clear.r, ER_TEST_BG.r, "scene: clear color is preserved");

  er_ui_scene_destroy(&scene);
}

static void test_scene_reserve_handles_large_public_count(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "reserve: init succeeds");

  scene.rect_count = 20u;
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 10.0f, 10.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "reserve: sparse public count grows enough capacity");
  expect_true(scene.rect_capacity > 20u, "reserve: capacity covers inserted sparse index");
  expect_size(scene.rect_count, 21u, "reserve: count advances from public count");

  er_ui_scene_destroy(&scene);
}

static void test_scene_topmost_queries(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "query: init succeeds");

  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, 1u, 0.0f, 0.0f, 30.0f, 30.0f)), ER_UI_OK,
                "query: first hit push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, 2u, 0.0f, 0.0f, 30.0f, 30.0f)), ER_UI_OK,
                "query: second hit push succeeds");
  expect_status(er_ui_scene_push_drag_source(&scene, er_ui_drag_source(10u, 1u, 0u, 0.0f, 0.0f, 30.0f, 30.0f)), ER_UI_OK,
                "query: first drag source push succeeds");
  expect_status(er_ui_scene_push_drag_source(&scene, er_ui_drag_source(10u, 2u, 1u, 0.0f, 0.0f, 30.0f, 30.0f)), ER_UI_OK,
                "query: second drag source push succeeds");
  expect_status(er_ui_scene_push_drop_target(&scene, er_ui_drop_target(10u, 0u, 0.0f, 0.0f, 30.0f, 30.0f)), ER_UI_OK,
                "query: first drop target push succeeds");
  expect_status(er_ui_scene_push_drop_target(&scene, er_ui_drop_target(10u, 1u, 0.0f, 0.0f, 30.0f, 30.0f)), ER_UI_OK,
                "query: second drop target push succeeds");

  er_ui_hit_t hit = {0};
  er_ui_drag_source_t source = {0};
  er_ui_drop_target_t target = {0};
  expect_true(er_ui_scene_hit_test(&scene, 4.0f, 4.0f, &hit), "query: hit is found");
  expect_u32(hit.id, 2u, "query: latest hit is topmost");
  expect_true(er_ui_scene_drag_source_at(&scene, 4.0f, 4.0f, &source), "query: drag source is found");
  expect_u32(source.item_id, 2u, "query: latest drag source is topmost");
  expect_true(er_ui_scene_drop_target_at(&scene, 4.0f, 4.0f, 10u, &target), "query: drop target is found");
  expect_size(target.index, 1u, "query: latest scoped drop target is topmost");
  expect_true(!er_ui_scene_drop_target_at(&scene, 4.0f, 4.0f, 11u, &target), "query: drop target scope is enforced");

  er_ui_scene_destroy(&scene);
}

static void test_scene_validation_and_clipping(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "clip: init succeeds");

  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 0.0f, 10.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "clip: zero width rect is ignored without error");
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(NAN, 0.0f, 10.0f, 10.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "clip: nan rect is ignored without error");
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 20.0f, 10.0f, 999.0f, ER_TEST_TEXT)), ER_UI_OK,
                "clip: oversized radius rect is accepted");
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_shadow(24.0f, 0.0f, 20.0f, 10.0f, -4.0f, ER_TEST_TEXT, -8.0f)), ER_UI_OK,
                "clip: negative shadow rect is accepted");
  expect_size(scene.rect_count, 2u, "clip: invalid rects are not inserted");
  expect_float(scene.rects[0].radius, 5.0f, "clip: radius clamps to half height");
  expect_float(scene.rects[1].radius, 0.0f, "clip: negative radius clamps to zero");
  expect_float(scene.rects[1].shadow, 0.0f, "clip: negative shadow clamps to zero");

  er_ui_scene_clear_commands(&scene);
  bool pushed = false;
  expect_status(er_ui_scene_push_clip(&scene, er_ui_clip(5.0f, 0.0f, 10.0f, 10.0f), &pushed), ER_UI_OK,
                "clip: push clip succeeds");
  expect_true(pushed, "clip: clip was pushed");
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_shadow(0.0f, 0.0f, 20.0f, 20.0f, 12.0f, ER_TEST_TEXT, 6.0f)), ER_UI_OK,
                "clip: clipped rect push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, 8u, 0.0f, 0.0f, 20.0f, 20.0f)), ER_UI_OK,
                "clip: clipped hit push succeeds");
  expect_status(er_ui_scene_push_text_quad(&scene, er_ui_quad(0.0f, 0.0f, 20.0f, 10.0f, 0.0f, 0.0f, 1.0f, 1.0f, ER_TEST_TEXT)), ER_UI_OK,
                "clip: clipped text quad push succeeds");

  expect_float(scene.rects[0].x, 5.0f, "clip: rect x clipped");
  expect_float(scene.rects[0].w, 10.0f, "clip: rect width clipped");
  expect_float(scene.rects[0].radius, 5.0f, "clip: clipped rect radius reclamped");
  expect_float(scene.hits[0].x, 5.0f, "clip: hit x clipped");
  expect_float(scene.hits[0].w, 10.0f, "clip: hit width clipped");
  expect_size(scene.text_quad_count, 1u, "clip: text quad inserted");
  expect_float(scene.text_quads[0].x, 5.0f, "clip: text quad x clipped");
  expect_float(scene.text_quads[0].u0, 0.25f, "clip: text quad u0 remapped");
  expect_float(scene.text_quads[0].u1, 0.75f, "clip: text quad u1 remapped");

  er_ui_scene_destroy(&scene);
}

static void test_scene_cursor_mutations(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "cursor: init succeeds");
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "cursor: base rect push succeeds");
  er_ui_scene_cursor_t cursor = er_ui_scene_cursor(&scene);
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(1.0f, 2.0f, 4.0f, 4.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "cursor: later rect push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, 3u, 1.0f, 2.0f, 4.0f, 4.0f)), ER_UI_OK,
                "cursor: later hit push succeeds");
  expect_status(er_ui_scene_push_icon_quad(&scene, er_ui_quad(1.0f, 2.0f, 4.0f, 4.0f, 0.0f, 0.0f, 1.0f, 1.0f, ER_TEST_TEXT)), ER_UI_OK,
                "cursor: later icon push succeeds");

  er_ui_scene_apply_opacity_since(&scene, cursor, 0.5f);
  er_ui_scene_translate_since(&scene, cursor, 3.0f, 4.0f);

  expect_float(scene.rects[0].x, 0.0f, "cursor: prior rect x unchanged");
  expect_float(scene.rects[0].color.a, 1.0f, "cursor: prior rect alpha unchanged");
  expect_float(scene.rects[1].x, 4.0f, "cursor: later rect x translated");
  expect_float(scene.rects[1].y, 6.0f, "cursor: later rect y translated");
  expect_float(scene.rects[1].color.a, 0.5f, "cursor: later rect alpha changed");
  expect_float(scene.hits[0].x, 4.0f, "cursor: later hit x translated");
  expect_float(scene.icon_quads[0].color.a, 0.5f, "cursor: later icon alpha changed");

  er_ui_scene_destroy(&scene);
}

static void test_transition_and_budget_contracts(void) {
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_LINEAR, 0.25f), 0.25f, "transition: linear easing samples directly");
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_EASE_IN, 0.5f), 0.25f, "transition: ease-in matches Rust formula");
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_EASE_OUT, 0.5f), 0.75f, "transition: ease-out matches Rust formula");
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_EASE_IN_OUT, 0.5f), 0.5f, "transition: ease-in-out midpoint is stable");

  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "transition: init succeeds");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_opacity(1u, 0.0f, 1.0f, 0u)), ER_UI_OK,
                "transition: zero duration ignored without error");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_opacity(2u, 0.0f, 1.0f, ER_UI_SCENE_TRANSITION_MAX_DURATION_MS + 1u)), ER_UI_OK,
                "transition: excessive duration ignored without error");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_translate_y(3u, -8.0f, 0.0f, 160u)), ER_UI_OK,
                "transition: valid transition accepted");
  expect_size(scene.transition_count, 1u, "transition: only valid transition inserted");
  er_ui_scene_destroy(&scene);

  er_ui_scene_stats_t stats = {11u, 4u, 0u, 0u, 0u, 0u, 0u, 0u};
  er_ui_scene_budget_t budget = {10u, 8u, 1u, 1u, 1u, 1u, 1u};
  er_ui_scene_budget_violation_t violation = {0};
  expect_true(er_ui_scene_first_budget_violation(stats, budget, &violation), "budget: violation is reported");
  expect_true(strcmp(violation.name, "rects") == 0, "budget: first violation names rects");
  expect_size(violation.actual, 11u, "budget: violation actual is reported");
  expect_size(violation.limit, 10u, "budget: violation limit is reported");
  expect_true(!er_ui_scene_stats_fits_budget(stats, budget), "budget: over-budget stats do not fit");
  expect_true(er_ui_scene_stats_fits_budget(stats, er_ui_scene_budget_native_interactive_frame()), "budget: native frame budget accepts fixture");
}

static void test_color_helpers_and_scheme_codes(void) {
  er_ui_color4_t color = er_ui_color_rgb_u8(255u, 128u, 0u);
  expect_float(color.r, 1.0f, "color: u8 red converts to float");
  expect_float(color.g, 128.0f / 255.0f, "color: u8 green converts to float");
  expect_float(color.b, 0.0f, "color: u8 blue converts to float");
  expect_float(color.a, 1.0f, "color: rgb helper sets alpha");
  color = er_ui_color_with_alpha(color, 0.25f);
  expect_float(color.a, 0.25f, "color: alpha helper updates alpha");

  expect_true(er_ui_color_scheme_from_code(1u) == ER_UI_COLOR_SCHEME_LIGHT, "scheme: light code decodes");
  expect_true(er_ui_color_scheme_from_code(2u) == ER_UI_COLOR_SCHEME_TERMINAL, "scheme: terminal code decodes");
  expect_true(er_ui_color_scheme_from_code(99u) == ER_UI_COLOR_SCHEME_DARK, "scheme: unknown code decodes dark");
  expect_u32(er_ui_color_scheme_code(ER_UI_COLOR_SCHEME_LIGHT), 1u, "scheme: light code encodes");
  expect_u32(er_ui_color_scheme_code(ER_UI_COLOR_SCHEME_TERMINAL), 2u, "scheme: terminal code encodes");
  expect_u32(er_ui_color_scheme_code(ER_UI_COLOR_SCHEME_DARK), 0u, "scheme: dark code encodes");
}

static void test_primitive_bounds_helpers(void) {
  er_ui_bounds_t bounds = er_ui_bounds(10.0f, 20.0f, 100.0f, 60.0f);

  er_ui_bounds_t inset = er_ui_bounds_inset(bounds, 8.0f, 4.0f);
  expect_float(inset.x, 18.0f, "bounds: inset x advances");
  expect_float(inset.y, 24.0f, "bounds: inset y advances");
  expect_float(inset.w, 84.0f, "bounds: inset width shrinks");
  expect_float(inset.h, 52.0f, "bounds: inset height shrinks");

  er_ui_bounds_t ltrb = er_ui_bounds_inset_ltrb(bounds, 2.0f, 3.0f, 5.0f, 7.0f);
  expect_float(ltrb.x, 12.0f, "bounds: ltrb x advances");
  expect_float(ltrb.y, 23.0f, "bounds: ltrb y advances");
  expect_float(ltrb.w, 93.0f, "bounds: ltrb width shrinks");
  expect_float(ltrb.h, 50.0f, "bounds: ltrb height shrinks");

  er_ui_bounds_t centered_h = er_ui_bounds_with_height_centered(bounds, 20.0f);
  expect_float(centered_h.y, 40.0f, "bounds: centered height y advances");
  expect_float(centered_h.h, 20.0f, "bounds: centered height clamps");
  er_ui_bounds_t centered_w = er_ui_bounds_with_width_centered(bounds, 40.0f);
  expect_float(centered_w.x, 40.0f, "bounds: centered width x advances");
  expect_float(centered_w.w, 40.0f, "bounds: centered width clamps");

  er_ui_bounds_t right = er_ui_bounds_right(bounds, 24.0f);
  expect_float(right.x, 86.0f, "bounds: right slice x advances");
  expect_float(right.w, 24.0f, "bounds: right slice width stored");
  er_ui_bounds_t bottom = er_ui_bounds_bottom(bounds, 16.0f);
  expect_float(bottom.y, 64.0f, "bounds: bottom slice y advances");
  expect_float(bottom.h, 16.0f, "bounds: bottom slice height stored");

  expect_true(er_ui_bounds_contains(bounds, 10.0f, 20.0f), "bounds: contains includes top left edge");
  expect_true(er_ui_bounds_contains(bounds, 110.0f, 80.0f), "bounds: contains includes bottom right edge");
  expect_true(!er_ui_bounds_contains(bounds, 111.0f, 80.0f), "bounds: contains rejects outside point");

  er_ui_bounds_t intersection = {0};
  expect_true(er_ui_bounds_intersect(bounds, er_ui_bounds(50.0f, 40.0f, 80.0f, 80.0f), &intersection),
              "bounds: intersection succeeds");
  expect_float(intersection.x, 50.0f, "bounds: intersection x");
  expect_float(intersection.y, 40.0f, "bounds: intersection y");
  expect_float(intersection.w, 60.0f, "bounds: intersection width");
  expect_float(intersection.h, 40.0f, "bounds: intersection height");
  expect_true(!er_ui_bounds_intersect(bounds, er_ui_bounds(200.0f, 200.0f, 10.0f, 10.0f), &intersection),
              "bounds: disjoint intersection fails");

  expect_true(er_ui_bounds_valid(bounds), "bounds: valid geometry is accepted");
  expect_true(!er_ui_bounds_valid(er_ui_bounds(0.0f, 0.0f, 0.0f, 1.0f)), "bounds: zero width is invalid");
  expect_true(!er_ui_float_is_finite_value(NAN), "bounds: nan is not finite");
}

static void test_painter_facade_pushes_scene_commands(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "painter: scene init succeeds");
  er_ui_painter_t painter = er_ui_painter(&scene);
  er_ui_color4_t border = er_ui_color_rgba(0.2f, 0.3f, 0.4f, 1.0f);

  expect_status(er_ui_painter_soft_card(&painter, er_ui_bounds(10.0f, 20.0f, 100.0f, 40.0f), 8.0f, ER_TEST_TEXT), ER_UI_OK,
                "painter: soft card succeeds");
  expect_size(scene.rect_count, 2u, "painter: soft card emits shadow and fill");
  expect_true(scene.rects[0].mode == ER_UI_RECT_SHADOW, "painter: soft card first rect is shadow");
  expect_float(scene.rects[0].y, 30.0f, "painter: soft card shadow y is offset");
  expect_true(scene.rects[1].mode == ER_UI_RECT_FILL, "painter: soft card second rect is fill");

  expect_status(er_ui_painter_panel(&painter, er_ui_bounds(0.0f, 0.0f, 30.0f, 20.0f), 6.0f, ER_TEST_TEXT, border), ER_UI_OK,
                "painter: panel succeeds");
  expect_size(scene.rect_count, 4u, "painter: panel emits fill and border");
  expect_true(scene.rects[3].mode == ER_UI_RECT_BORDER, "painter: panel second rect is border");
  expect_float(scene.rects[3].color.g, border.g, "painter: panel border color stored");

  expect_status(er_ui_painter_divider(&painter, 5.0f, 6.0f, 50.0f, ER_UI_AXIS_HORIZONTAL, border), ER_UI_OK,
                "painter: horizontal divider succeeds");
  expect_float(scene.rects[4].w, 50.0f, "painter: horizontal divider width stored");
  expect_float(scene.rects[4].h, 1.0f, "painter: horizontal divider height stored");
  expect_status(er_ui_painter_divider(&painter, 7.0f, 8.0f, 30.0f, ER_UI_AXIS_VERTICAL, border), ER_UI_OK,
                "painter: vertical divider succeeds");
  expect_float(scene.rects[5].w, 1.0f, "painter: vertical divider width stored");
  expect_float(scene.rects[5].h, 30.0f, "painter: vertical divider height stored");

  expect_status(er_ui_painter_hit(&painter, ER_UI_HIT_BUTTON, 44u, er_ui_bounds(1.0f, 2.0f, 3.0f, 4.0f)), ER_UI_OK,
                "painter: hit succeeds");
  expect_status(er_ui_painter_drag_source(&painter, 9u, 10u, 1u, er_ui_bounds(2.0f, 3.0f, 4.0f, 5.0f)), ER_UI_OK,
                "painter: drag source succeeds");
  expect_status(er_ui_painter_drop_target(&painter, 9u, 2u, er_ui_bounds(3.0f, 4.0f, 5.0f, 6.0f)), ER_UI_OK,
                "painter: drop target succeeds");
  expect_size(scene.hit_count, 1u, "painter: hit count increments");
  expect_size(scene.drag_source_count, 1u, "painter: drag source count increments");
  expect_size(scene.drop_target_count, 1u, "painter: drop target count increments");

  expect_status(er_ui_painter_icon_quad(&painter, er_ui_bounds(0.0f, 0.0f, 16.0f, 16.0f), 0.0f, 0.0f, 1.0f, 1.0f, ER_TEST_TEXT),
                ER_UI_OK, "painter: icon quad succeeds");
  expect_status(er_ui_painter_text_quad(&painter, er_ui_bounds(0.0f, 20.0f, 16.0f, 16.0f), 0.0f, 0.0f, 1.0f, 1.0f, ER_TEST_TEXT),
                ER_UI_OK, "painter: text quad succeeds");
  expect_status(er_ui_painter_transition(&painter, er_ui_transition_opacity(123u, 0.0f, 1.0f, 120u)), ER_UI_OK,
                "painter: transition succeeds");
  expect_size(scene.icon_quad_count, 1u, "painter: icon quad count increments");
  expect_size(scene.text_quad_count, 1u, "painter: text quad count increments");
  expect_size(scene.transition_count, 1u, "painter: transition count increments");

  er_ui_scene_destroy(&scene);
}

static void test_theme_presets_and_semantic_colors(void) {
  expect_true(er_ui_radius_preset_next(ER_UI_RADIUS_NONE) == ER_UI_RADIUS_COMPACT, "theme: radius none cycles compact");
  expect_true(er_ui_radius_preset_next(ER_UI_RADIUS_SOFT) == ER_UI_RADIUS_NONE, "theme: radius soft cycles none");
  expect_true(er_ui_accent_preset_next(ER_UI_ACCENT_NEUTRAL) == ER_UI_ACCENT_CYAN, "theme: accent neutral cycles cyan");
  expect_true(er_ui_accent_preset_next(ER_UI_ACCENT_AMBER) == ER_UI_ACCENT_NEUTRAL, "theme: accent amber cycles neutral");
  expect_true(er_ui_density_next(ER_UI_DENSITY_COMFORTABLE) == ER_UI_DENSITY_COMPACT, "theme: density comfortable cycles compact");
  expect_true(er_ui_color_scheme_next(ER_UI_COLOR_SCHEME_DARK) == ER_UI_COLOR_SCHEME_TERMINAL, "theme: dark cycles terminal");
  expect_true(er_ui_color_scheme_next(ER_UI_COLOR_SCHEME_LIGHT) == ER_UI_COLOR_SCHEME_DARK, "theme: light cycles dark");

  er_ui_radius_scale_t none = er_ui_radius_scale_from_preset(ER_UI_RADIUS_NONE);
  er_ui_radius_scale_t soft = er_ui_radius_scale_from_preset(ER_UI_RADIUS_SOFT);
  expect_float(none.card, 0.0f, "theme: none radius has zero card radius");
  expect_float(soft.card, 8.0f, "theme: soft radius respects card radius max");
  expect_float(soft.pill, 999.0f, "theme: soft radius keeps pill radius");

  er_ui_semantic_colors_t dark = er_ui_semantic_colors_for_scheme(ER_UI_COLOR_SCHEME_DARK);
  expect_float(dark.bg.r, 9.0f / 255.0f, "theme: dark bg red matches slate 950");
  expect_float(dark.sidebar.a, 0.86f, "theme: dark sidebar alpha matches Rust palette");
  expect_float(dark.border.a, 0.32f, "theme: dark border alpha matches Rust palette");

  er_ui_semantic_colors_t terminal = er_ui_semantic_colors_for_scheme(ER_UI_COLOR_SCHEME_TERMINAL);
  expect_float(terminal.bg.r, 0.0f, "theme: terminal bg is black");
  expect_float(terminal.border.g, 185.0f / 255.0f, "theme: terminal border uses green");
  expect_float(terminal.border.a, 0.34f, "theme: terminal border alpha matches Rust palette");

  er_ui_style_preset_t preset = er_ui_style_preset_user_default();
  preset.accent = ER_UI_ACCENT_GREEN;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(ER_UI_STYLE_AUTHORITY_USER, preset);
  expect_true(theme.authority == ER_UI_STYLE_AUTHORITY_USER, "theme: authority stored");
  expect_float(theme.colors.accent.g, 185.0f / 255.0f, "theme: green accent applied");
  expect_float(theme.colors.active.a, 0.42f, "theme: active row alpha follows accent override");
  expect_float(theme.radius.card, 8.0f, "theme: default card radius stored");
  expect_true(theme.density == ER_UI_DENSITY_COMFORTABLE, "theme: resolved density defaults comfortable");

  er_ui_color4_t token_color = er_ui_theme_color(theme, ER_UI_COLOR_TOKEN_ACCENT);
  expect_float(token_color.g, theme.colors.accent.g, "theme: accent token resolves");
  token_color = er_ui_theme_color(theme, ER_UI_COLOR_TOKEN_DANGER);
  expect_float(token_color.r, 225.0f / 255.0f, "theme: danger token resolves");

  er_ui_resolved_theme_t author = er_ui_resolved_theme(ER_UI_STYLE_AUTHORITY_AUTHOR_VISION, er_ui_style_preset_author_vision());
  expect_true(author.authority == ER_UI_STYLE_AUTHORITY_AUTHOR_VISION, "theme: author vision authority stored");
  expect_true(author.preset.scheme == ER_UI_COLOR_SCHEME_TERMINAL, "theme: author vision uses terminal scheme");
  expect_float(author.radius.control, 6.0f, "theme: author vision uses compact radius");
}

static void test_varfont_vertices_emit_text_quads(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "varfont: scene init succeeds");

  vr_vertex_t vertices[VR_FONT_VERTICES_PER_GLYPH] = {
    {10.0f, 20.0f, 0.10f, 0.20f, 1.0f, 1.0f, 1.0f, 1.0f, 7u},
    {18.0f, 20.0f, 0.30f, 0.20f, 1.0f, 1.0f, 1.0f, 1.0f, 7u},
    {18.0f, 32.0f, 0.30f, 0.50f, 1.0f, 1.0f, 1.0f, 1.0f, 7u},
    {10.0f, 20.0f, 0.10f, 0.20f, 1.0f, 1.0f, 1.0f, 1.0f, 7u},
    {18.0f, 32.0f, 0.30f, 0.50f, 1.0f, 1.0f, 1.0f, 1.0f, 7u},
    {10.0f, 32.0f, 0.10f, 0.50f, 1.0f, 1.0f, 1.0f, 1.0f, 7u},
  };

  expect_status(er_ui_scene_push_varfont_vertices(&scene, vertices, VR_FONT_VERTICES_PER_GLYPH, ER_TEST_TEXT), ER_UI_OK,
                "varfont: vertex batch converts to text quad");
  expect_size(scene.text_quad_count, 1u, "varfont: one glyph emits one text quad");
  expect_float(scene.text_quads[0].x, 10.0f, "varfont: quad x copied");
  expect_float(scene.text_quads[0].y, 20.0f, "varfont: quad y copied");
  expect_float(scene.text_quads[0].w, 8.0f, "varfont: quad width derived");
  expect_float(scene.text_quads[0].h, 12.0f, "varfont: quad height derived");
  expect_float(scene.text_quads[0].u0, 0.10f, "varfont: quad u0 copied");
  expect_float(scene.text_quads[0].v1, 0.50f, "varfont: quad v1 copied");
  expect_u32(scene.text_quads[0].atlas_id, 7u, "varfont: atlas id copied");
  expect_status(er_ui_scene_push_varfont_vertices(&scene, vertices, 1u, ER_TEST_TEXT), ER_UI_ERR_INVALID_ARGUMENT,
                "varfont: partial vertex batch is rejected");

  er_ui_scene_destroy(&scene);
}

static void test_varfont_memory_face_emits_ui_text(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "varfont text: scene init succeeds");

  size_t font_size = 0u;
  unsigned char* font_data = er_ui_test_read_file(ER_UI_REPO_ROOT "/varfont/fonts/Geist[wght].ttf", &font_size);
  expect_true(font_data != NULL && font_size > 0u, "varfont text: bundled font bytes load");
  if (!font_data) {
    er_ui_scene_destroy(&scene);
    return;
  }

  vr_font_config_t cfg = {0};
  cfg.px_size = 24.0f;
  cfg.atlas_width = 256u;
  cfg.atlas_height = 256u;
  cfg.atlas_pad = VR_FONT_DEFAULT_ATLAS_PADDING;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = er_ui_test_vr_allocator();

  vr_font_face_t* face = NULL;
  expect_status((er_ui_status_t)vr_font_face_create_from_memory(&face, font_data, font_size, &cfg), (er_ui_status_t)VR_OK,
                "varfont text: memory face opens");
  free(font_data);
  if (!face) {
    er_ui_scene_destroy(&scene);
    return;
  }

  const uint32_t text[] = {'R', 'u', 'n'};
  er_ui_varfont_text_metrics_t measured = {0};
  expect_status(er_ui_varfont_measure_text(face, text, 3u, &measured), ER_UI_OK, "varfont text: measure succeeds");
  expect_true(measured.advance_width > 0.0f, "varfont text: measured advance is positive");
  expect_true(measured.line_height > 0.0f, "varfont text: measured line height is positive");
  expect_true(measured.ascender > 0.0f, "varfont text: measured ascender is positive");
  expect_status(er_ui_varfont_measure_text(face, NULL, 1u, &measured), ER_UI_ERR_INVALID_ARGUMENT,
                "varfont text: measure rejects missing codepoints");

  expect_status(er_ui_scene_push_varfont_text(&scene, face, text, 3u, 4.0f, 40.0f, ER_TEST_TEXT), ER_UI_OK,
                "varfont text: shaped text emits scene quads");
  expect_true(scene.text_quad_count > 0u, "varfont text: emitted at least one quad");
  size_t atlas_count = vr_font_atlas_count(face);
  expect_true(atlas_count > 0u, "varfont text: atlas page was created");
  expect_true(scene.text_quads[0].atlas_id < atlas_count, "varfont text: emitted quad references a valid atlas page");
  uint32_t atlas_texture = 0u;
  expect_status((er_ui_status_t)vr_font_atlas_texture(face, scene.text_quads[0].atlas_id, &atlas_texture), (er_ui_status_t)VR_OK,
                "varfont text: emitted atlas page resolves");

  vr_font_face_destroy(face);
  er_ui_scene_destroy(&scene);
}

int main(void) {
  test_primitive_bounds_helpers();
  test_painter_facade_pushes_scene_commands();
  test_theme_presets_and_semantic_colors();
  test_varfont_vertices_emit_text_quads();
  test_varfont_memory_face_emits_ui_text();
  test_scene_stats_and_clear();
  test_scene_reserve_handles_large_public_count();
  test_scene_topmost_queries();
  test_scene_validation_and_clipping();
  test_scene_cursor_mutations();
  test_transition_and_budget_contracts();
  test_color_helpers_and_scheme_codes();
  run_runtime_tests();

  if (g_tests_failed > 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_tests_failed, g_tests_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_tests_total);
  return 0;
}
