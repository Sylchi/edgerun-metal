#include "er_ui_scene.h"
#include "er_math.h"
#include "test_common.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ER_TEST_ASCII_LEDGER_LEN 6u

int g_tests_total = 0;
int g_tests_failed = 0;

static const float ER_TEST_EPSILON = 0.0001f;
static const er_ui_color4_t ER_TEST_BG = {0.01f, 0.012f, 0.015f, 1.0f};
static const er_ui_color4_t ER_TEST_TEXT = {0.94f, 0.96f, 0.99f, 1.0f};
static const uint32_t ER_TEST_SCENE_HIT_ID = 7u;
static const uint32_t ER_TEST_SCENE_TRANSITION_ID = 90u;
static const uint32_t ER_TEST_SCENE_TRANSITION_MS = 120u;
static const size_t ER_TEST_SCENE_SPARSE_RECT_COUNT = 20u;
static const size_t ER_TEST_SCENE_SPARSE_RECT_NEXT_COUNT = 21u;
static const uint32_t ER_TEST_CLIPPED_HIT_ID = 8u;
static const uint32_t ER_TEST_CURSOR_HIT_ID = 3u;
static const uint32_t ER_TEST_TRANSITION_IGNORED_ZERO_ID = 1u;
static const uint32_t ER_TEST_TRANSITION_IGNORED_LONG_ID = 2u;
static const uint32_t ER_TEST_TRANSITION_VALID_ID = 3u;
static const uint32_t ER_TEST_TRANSITION_VALID_MS = 160u;
static const size_t ER_TEST_BUDGET_ACTUAL_RECTS = 11u;
static const size_t ER_TEST_BUDGET_ACTUAL_HITS = 4u;
static const size_t ER_TEST_BUDGET_LIMIT_RECTS = 10u;
static const uint8_t ER_TEST_COLOR_U8_MAX = 255u;
static const uint8_t ER_TEST_COLOR_U8_MID = 128u;

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
  expect_true(er_math_absf(got - expected) <= ER_TEST_EPSILON, name);
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

er_ui_allocator_t er_ui_test_allocator(void) {
  er_ui_allocator_t allocator = {0};
  allocator.alloc = test_alloc;
  allocator.free = test_free;
  return allocator;
}

static void test_scene_stats_and_clear(void) {
  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "scene: init succeeds");

  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 10.0f, 10.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "scene: push rect succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, ER_TEST_SCENE_HIT_ID, 1.0f, 1.0f, 8.0f, 8.0f)), ER_UI_OK,
                "scene: push hit succeeds");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_opacity(ER_TEST_SCENE_TRANSITION_ID, 0.0f, 1.0f, ER_TEST_SCENE_TRANSITION_MS)),
                ER_UI_OK,
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

  scene.rect_count = ER_TEST_SCENE_SPARSE_RECT_COUNT;
  expect_status(er_ui_scene_push_rect(&scene, er_ui_rect_fill(0.0f, 0.0f, 10.0f, 10.0f, 0.0f, ER_TEST_TEXT)), ER_UI_OK,
                "reserve: sparse public count grows enough capacity");
  expect_true(scene.rect_capacity > ER_TEST_SCENE_SPARSE_RECT_COUNT, "reserve: capacity covers inserted sparse index");
  expect_size(scene.rect_count, ER_TEST_SCENE_SPARSE_RECT_NEXT_COUNT, "reserve: count advances from public count");

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
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, ER_TEST_CLIPPED_HIT_ID, 0.0f, 0.0f, 20.0f, 20.0f)), ER_UI_OK,
                "clip: clipped hit push succeeds");
  expect_status(er_ui_scene_push_text_quad(&scene, er_ui_quad(0.0f, 0.0f, 20.0f, 10.0f, 0.0f, 0.0f, 1.0f, 1.0f, ER_TEST_TEXT)), ER_UI_OK,
                "clip: clipped text quad push succeeds");

  expect_float(scene.rects[0].x, 5.0f, "clip: rect x clipped");
  expect_float(scene.rects[0].w, 10.0f, "clip: rect width clipped");
  expect_float(scene.rects[0].radius, 5.0f, "clip: clipped rect radius reclamped");
  expect_float(scene.hits[0].x, 5.0f, "clip: hit x clipped");
  expect_float(scene.hits[0].w, 10.0f, "clip: hit width clipped");
  expect_size(scene.text_quad_count, 1u, "clip: text quad inserted");
  const er_ui_quad_t* clipped_text_quad = scene.text_quads;
  expect_float(clipped_text_quad->x, 5.0f, "clip: text quad x clipped");
  expect_float(clipped_text_quad->u0, 0.25f, "clip: text quad u0 remapped");
  expect_float(clipped_text_quad->u1, 0.75f, "clip: text quad u1 remapped");

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
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, ER_TEST_CURSOR_HIT_ID, 1.0f, 2.0f, 4.0f, 4.0f)), ER_UI_OK,
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
  const er_ui_quad_t* later_icon_quad = scene.icon_quads;
  expect_float(later_icon_quad->color.a, 0.5f, "cursor: later icon alpha changed");

  er_ui_scene_destroy(&scene);
}

static void test_transition_and_budget_contracts(void) {
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_LINEAR, 0.25f), 0.25f, "transition: linear easing samples directly");
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_EASE_IN, 0.5f), 0.25f, "transition: ease-in matches Rust formula");
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_EASE_OUT, 0.5f), 0.75f, "transition: ease-out matches Rust formula");
  expect_float(er_ui_transition_easing_sample(ER_UI_EASING_EASE_IN_OUT, 0.5f), 0.5f, "transition: ease-in-out midpoint is stable");

  er_ui_scene_t scene = {0};
  expect_status(er_ui_scene_init_with_allocator(&scene, ER_TEST_BG, er_ui_test_allocator()), ER_UI_OK, "transition: init succeeds");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_opacity(ER_TEST_TRANSITION_IGNORED_ZERO_ID, 0.0f, 1.0f, 0u)), ER_UI_OK,
                "transition: zero duration ignored without error");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_opacity(ER_TEST_TRANSITION_IGNORED_LONG_ID, 0.0f, 1.0f,
                                                                             ER_UI_SCENE_TRANSITION_MAX_DURATION_MS + 1u)),
                ER_UI_OK,
                "transition: excessive duration ignored without error");
  expect_status(er_ui_scene_push_transition(&scene, er_ui_transition_translate_y(ER_TEST_TRANSITION_VALID_ID, -8.0f, 0.0f, ER_TEST_TRANSITION_VALID_MS)), ER_UI_OK,
                "transition: valid transition accepted");
  expect_size(scene.transition_count, 1u, "transition: only valid transition inserted");
  er_ui_scene_destroy(&scene);

  er_ui_scene_stats_t stats = {ER_TEST_BUDGET_ACTUAL_RECTS, ER_TEST_BUDGET_ACTUAL_HITS, 0u, 0u, 0u, 0u, 0u, 0u};
  er_ui_scene_budget_t budget = {ER_TEST_BUDGET_LIMIT_RECTS, 8u, 1u, 1u, 1u, 1u, 1u};
  er_ui_scene_budget_violation_t violation = {0};
  expect_true(er_ui_scene_first_budget_violation(stats, budget, &violation), "budget: violation is reported");
  expect_true(strcmp(violation.name, "rects") == 0, "budget: first violation names rects");
  expect_size(violation.actual, ER_TEST_BUDGET_ACTUAL_RECTS, "budget: violation actual is reported");
  expect_size(violation.limit, ER_TEST_BUDGET_LIMIT_RECTS, "budget: violation limit is reported");
  expect_true(!er_ui_scene_stats_fits_budget(stats, budget), "budget: over-budget stats do not fit");
  expect_true(er_ui_scene_stats_fits_budget(stats, er_ui_scene_frame_budget()), "budget: frame budget accepts fixture");
}

static void test_color_helpers(void) {
  er_ui_color4_t color = er_ui_color_rgb_u8(ER_TEST_COLOR_U8_MAX, ER_TEST_COLOR_U8_MID, 0u);
  expect_float(color.r, 1.0f, "color: u8 red converts to float");
  expect_float(color.g, (float)ER_TEST_COLOR_U8_MID / (float)ER_TEST_COLOR_U8_MAX, "color: u8 green converts to float");
  expect_float(color.b, 0.0f, "color: u8 blue converts to float");
  expect_float(color.a, 1.0f, "color: rgb helper sets alpha");
  color = er_ui_color_with_alpha(color, 0.25f);
  expect_float(color.a, 0.25f, "color: alpha helper updates alpha");
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
  expect_size(er_ui_ascii_len(NULL), 0u, "primitives: null ascii len is zero");
  expect_size(er_ui_ascii_len(""), 0u, "primitives: empty ascii len is zero");
  expect_size(er_ui_ascii_len("Ledger"), ER_TEST_ASCII_LEDGER_LEN, "primitives: ascii len counts bytes");
}

int main(void) {
  test_primitive_bounds_helpers();
  test_scene_stats_and_clear();
  test_scene_reserve_handles_large_public_count();
  test_scene_validation_and_clipping();
  test_scene_cursor_mutations();
  test_transition_and_budget_contracts();
  test_color_helpers();

  if (g_tests_failed > 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_tests_failed, g_tests_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_tests_total);
  return 0;
}
