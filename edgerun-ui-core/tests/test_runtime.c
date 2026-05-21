#include "er_ui_runtime.h"
#include "test_common.h"

#include <string.h>

#define ER_UI_TEST_TEXT_SET_CURSOR_CHARS 9u
#define ER_UI_TEST_TEXT_INSERT_CURSOR_CHARS 13u
#define ER_UI_TEST_TEXT_UTF8_CURSOR_CHARS 4u
#define ER_UI_TEST_TRANSITION_ID 88u
#define ER_UI_TEST_TRANSITION_DURATION_MS 100u
#define ER_UI_TEST_TRANSITION_DELAY_MS 20u
#define ER_UI_TEST_TRANSITION_STEP_MS 50u
#define ER_UI_TEST_RUNTIME_SCROLL_ID 7u
#define ER_UI_TEST_RUNTIME_TOGGLE_ID 3u
#define ER_UI_TEST_RUNTIME_SLIDER_ID 9u
#define ER_UI_TEST_RUNTIME_OPEN_ONE_ID 1u
#define ER_UI_TEST_RUNTIME_OPEN_TWO_ID 2u
#define ER_UI_TEST_RUNTIME_TAB_GROUP_ID 100u
#define ER_UI_TEST_RUNTIME_TAB_COUNT 3u
#define ER_UI_TEST_RUNTIME_TAB_FIRST_ID 101u
#define ER_UI_TEST_RUNTIME_TAB_SECOND_ID 102u
#define ER_UI_TEST_RUNTIME_EMPTY_TAB_GROUP_ID 200u
#define ER_UI_TEST_RUNTIME_EMPTY_TAB_COUNT 0u
#define ER_UI_TEST_RUNTIME_TEXT_ID 44u
#define ER_UI_TEST_RUNTIME_INVALID_TEXT_ID 45u
#define ER_UI_TEST_FOCUS_SCOPE_ID 99u
#define ER_UI_TEST_FOCUS_SCOPE_INPUT_COUNT 3u
#define ER_UI_TEST_FOCUS_SCOPE_FOCUSABLE_COUNT 2u
#define ER_UI_TEST_POINTER_BUTTON_ID 1u
#define ER_UI_TEST_POINTER_TOGGLE_ID 2u
#define ER_UI_TEST_POINTER_SELECT_ID 3u
#define ER_UI_TEST_POINTER_SLIDER_ID 4u
#define ER_UI_TEST_POINTER_SLIDER_W 100.0f
#define ER_UI_TEST_POINTER_SLIDER_X 75.0f
#define ER_UI_TEST_INPUT_BUTTON_ID 10u
#define ER_UI_TEST_INPUT_TEXT_ID 11u
#define ER_UI_TEST_INPUT_SCROLL_ID 12u
#define ER_UI_TEST_INPUT_DRAG_SCOPE_ID 20u
#define ER_UI_TEST_INPUT_DRAG_ITEM_ID 101u
#define ER_UI_TEST_INPUT_DRAG_FROM_INDEX 0u
#define ER_UI_TEST_INPUT_DROP_INDEX 2u
#define ER_UI_TEST_INPUT_DRAG_Y 130.0f
#define ER_UI_TEST_INPUT_OPEN_ID 50u

static void expect_action(er_ui_text_buffer_action_t got, er_ui_text_buffer_action_t expected, const char* name) {
  expect_true(got == expected, name);
}

static void expect_runtime_scroll(const er_ui_runtime_state_t* state, uint32_t id, float expected, const char* name) {
  float value = 0.0f;
  expect_status(er_ui_runtime_read_scroll_offset(state, id, &value), ER_UI_OK, name);
  expect_float(value, expected, name);
}

static void expect_runtime_toggle(const er_ui_runtime_state_t* state, uint32_t id, bool expected, const char* name) {
  bool value = false;
  expect_status(er_ui_runtime_read_toggle(state, id, &value), ER_UI_OK, name);
  expect_true(value == expected, name);
}

static void expect_runtime_slider(const er_ui_runtime_state_t* state, uint32_t id, float expected, const char* name) {
  float value = 0.0f;
  expect_status(er_ui_runtime_read_slider(state, id, &value), ER_UI_OK, name);
  expect_float(value, expected, name);
}

static void expect_runtime_open(const er_ui_runtime_state_t* state, uint32_t id, bool expected, const char* name) {
  bool open = false;
  expect_status(er_ui_runtime_read_open(state, id, &open), ER_UI_OK, name);
  expect_true(open == expected, name);
}

static void expect_runtime_text(const er_ui_runtime_state_t* state, uint32_t id, const char* expected, const char* name) {
  const char* value = NULL;
  expect_status(er_ui_runtime_read_text(state, id, &value), ER_UI_OK, name);
  expect_string(value, expected, name);
}

static void test_text_buffer_insert_and_cursor(void) {
  er_ui_text_buffer_t buffer = {0};
  expect_status(er_ui_text_buffer_init_with_allocator(&buffer, er_ui_test_allocator()), ER_UI_OK, "text: init succeeds");
  expect_true(er_ui_text_buffer_is_empty(&buffer), "text: new buffer is empty");

  expect_status(er_ui_text_buffer_set_text(&buffer, "run cache"), ER_UI_OK, "text: set text succeeds");
  expect_string(er_ui_text_buffer_value(&buffer), "run cache", "text: set text stores value");
  expect_size(er_ui_text_buffer_cursor_chars(&buffer), ER_UI_TEST_TEXT_SET_CURSOR_CHARS, "text: set text moves cursor to end");

  er_ui_text_buffer_move_cursor_left(&buffer);
  er_ui_text_buffer_move_cursor_left(&buffer);
  er_ui_text_buffer_move_cursor_left(&buffer);
  er_ui_text_buffer_move_cursor_left(&buffer);
  er_ui_text_buffer_move_cursor_left(&buffer);
  expect_status(er_ui_text_buffer_insert(&buffer, "& verify "), ER_UI_OK, "text: insert at cursor succeeds");
  expect_string(er_ui_text_buffer_value(&buffer), "run & verify cache", "text: insert uses character cursor");
  expect_size(er_ui_text_buffer_cursor_chars(&buffer), ER_UI_TEST_TEXT_INSERT_CURSOR_CHARS, "text: insert advances cursor by inserted characters");

  char* with_cursor = NULL;
  expect_status(er_ui_text_buffer_value_with_cursor(&buffer, "|", &with_cursor), ER_UI_OK, "text: value with cursor succeeds");
  expect_string(with_cursor, "run & verify |cache", "text: cursor marker is inserted at cursor");
  er_ui_text_buffer_free_text(&buffer, with_cursor);

  er_ui_text_buffer_destroy(&buffer);
}

static void test_text_buffer_key_handling(void) {
  er_ui_text_buffer_t buffer = {0};
  er_ui_text_buffer_action_t action = ER_UI_TEXT_ACTION_NONE;
  expect_status(er_ui_text_buffer_init_with_allocator(&buffer, er_ui_test_allocator()), ER_UI_OK, "keys: init succeeds");
  expect_status(er_ui_text_buffer_set_text(&buffer, "alpha beta gamma"), ER_UI_OK, "keys: set text succeeds");

  expect_status(er_ui_text_buffer_handle_key_with_modifiers(&buffer, er_ui_key_other('a'), er_ui_key_modifiers(false, true, false, false), &action),
                ER_UI_OK, "keys: ctrl-a succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "keys: ctrl-a reports changed");
  expect_size(er_ui_text_buffer_cursor_chars(&buffer), 0u, "keys: ctrl-a moves to start");

  expect_status(er_ui_text_buffer_handle_key_with_modifiers(&buffer, er_ui_key_other('e'), er_ui_key_modifiers(false, true, false, false), &action),
                ER_UI_OK, "keys: ctrl-e succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "keys: ctrl-e reports changed");
  expect_size(er_ui_text_buffer_cursor_chars(&buffer), strlen("alpha beta gamma"), "keys: ctrl-e moves to end");

  expect_status(er_ui_text_buffer_handle_key_with_modifiers(&buffer, er_ui_key_other('w'), er_ui_key_modifiers(false, true, false, false), &action),
                ER_UI_OK, "keys: ctrl-w succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "keys: ctrl-w reports changed");
  expect_string(er_ui_text_buffer_value(&buffer), "alpha beta ", "keys: ctrl-w deletes prior word");

  expect_status(er_ui_text_buffer_handle_key(&buffer, er_ui_key(ER_UI_KEY_BACKSPACE), false, &action), ER_UI_OK, "keys: backspace succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "keys: backspace reports changed");
  expect_string(er_ui_text_buffer_value(&buffer), "alpha beta", "keys: backspace deletes prior character");

  expect_status(er_ui_text_buffer_handle_key(&buffer, er_ui_key(ER_UI_KEY_HOME), false, &action), ER_UI_OK, "keys: home succeeds");
  expect_status(er_ui_text_buffer_handle_key(&buffer, er_ui_key(ER_UI_KEY_DELETE), false, &action), ER_UI_OK, "keys: delete succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "keys: delete reports changed");
  expect_string(er_ui_text_buffer_value(&buffer), "lpha beta", "keys: delete removes character after cursor");

  expect_status(er_ui_text_buffer_handle_key(&buffer, er_ui_key(ER_UI_KEY_ENTER), false, &action), ER_UI_OK, "keys: enter succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_SUBMIT, "keys: enter submits without shift");
  expect_status(er_ui_text_buffer_handle_key(&buffer, er_ui_key(ER_UI_KEY_ENTER), true, &action), ER_UI_OK, "keys: shift-enter succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "keys: shift-enter changes text");
  expect_string(er_ui_text_buffer_value(&buffer), "\nlpha beta", "keys: shift-enter inserts newline");

  er_ui_text_buffer_destroy(&buffer);
}

static void test_text_buffer_text_input_validation(void) {
  er_ui_text_buffer_t buffer = {0};
  er_ui_text_buffer_action_t action = ER_UI_TEXT_ACTION_NONE;
  expect_status(er_ui_text_buffer_init_with_allocator(&buffer, er_ui_test_allocator()), ER_UI_OK, "input: init succeeds");

  expect_status(er_ui_text_buffer_handle_text_input(&buffer, "a\tb\nc", &action), ER_UI_OK, "input: control characters are accepted for filtering");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "input: filtered input changed buffer");
  expect_string(er_ui_text_buffer_value(&buffer), "abc", "input: control characters are filtered");

  const char invalid_utf8[] = {(char)0xC0, (char)0xAF, '\0'};
  expect_status(er_ui_text_buffer_handle_text_input(&buffer, invalid_utf8, &action), ER_UI_ERR_INVALID_ARGUMENT,
                "input: invalid utf8 is rejected");

  expect_status(er_ui_text_buffer_set_text(&buffer, "node"), ER_UI_OK, "input: reset text succeeds");
  er_ui_text_buffer_move_cursor_left(&buffer);
  expect_status(er_ui_text_buffer_handle_text_input(&buffer, "é", &action), ER_UI_OK, "input: utf8 insert succeeds");
  expect_action(action, ER_UI_TEXT_ACTION_CHANGED, "input: utf8 insert reports changed");
  expect_string(er_ui_text_buffer_value(&buffer), "nodée", "input: utf8 insert preserves byte sequence");
  expect_size(er_ui_text_buffer_cursor_chars(&buffer), ER_UI_TEST_TEXT_UTF8_CURSOR_CHARS, "input: utf8 cursor advances by character");

  er_ui_text_buffer_destroy(&buffer);
}

static void test_text_buffer_delete_ranges(void) {
  er_ui_text_buffer_t buffer = {0};
  expect_status(er_ui_text_buffer_init_with_allocator(&buffer, er_ui_test_allocator()), ER_UI_OK, "delete: init succeeds");
  expect_status(er_ui_text_buffer_set_text(&buffer, "own your data"), ER_UI_OK, "delete: set text succeeds");

  er_ui_text_buffer_move_cursor_to_start(&buffer);
  er_ui_text_buffer_move_cursor_right(&buffer);
  er_ui_text_buffer_move_cursor_right(&buffer);
  er_ui_text_buffer_move_cursor_right(&buffer);
  er_ui_text_buffer_delete_after_cursor_all(&buffer);
  expect_string(er_ui_text_buffer_value(&buffer), "own", "delete: delete after cursor truncates");

  expect_status(er_ui_text_buffer_set_text(&buffer, "publish from node"), ER_UI_OK, "delete: reset text succeeds");
  er_ui_text_buffer_move_cursor_to_start(&buffer);
  for (size_t i = 0u; i < strlen("publish"); ++i) {
    er_ui_text_buffer_move_cursor_right(&buffer);
  }
  er_ui_text_buffer_delete_before_cursor_all(&buffer);
  expect_string(er_ui_text_buffer_value(&buffer), " from node", "delete: delete before cursor removes prefix");
  expect_size(er_ui_text_buffer_cursor_chars(&buffer), 0u, "delete: delete before cursor resets cursor");

  er_ui_text_buffer_destroy(&buffer);
}

static void test_text_buffer_display_value(void) {
  er_ui_text_buffer_t buffer = {0};
  char* display = NULL;
  expect_status(er_ui_text_buffer_init_with_allocator(&buffer, er_ui_test_allocator()), ER_UI_OK, "display: init succeeds");
  expect_status(er_ui_text_buffer_display_value(&buffer, "placeholder", "|", &display), ER_UI_OK, "display: placeholder succeeds");
  expect_string(display, "placeholder", "display: empty buffer returns placeholder");
  er_ui_text_buffer_free_text(&buffer, display);

  expect_status(er_ui_text_buffer_set_text(&buffer, "identity"), ER_UI_OK, "display: set text succeeds");
  er_ui_text_buffer_move_cursor_to_start(&buffer);
  expect_status(er_ui_text_buffer_display_value(&buffer, "placeholder", "|", &display), ER_UI_OK, "display: cursor value succeeds");
  expect_string(display, "|identity", "display: non-empty buffer returns value with cursor");
  er_ui_text_buffer_free_text(&buffer, display);

  er_ui_text_buffer_destroy(&buffer);
}

static void test_runtime_transitions_sync_and_advance(void) {
  er_ui_runtime_state_t state = {0};
  er_ui_scene_t scene = {0};
  bool changed = false;
  expect_status(er_ui_runtime_state_init_with_allocator(&state, er_ui_test_allocator()), ER_UI_OK, "runtime transitions: state init succeeds");
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f), er_ui_test_allocator()), ER_UI_OK,
                "runtime transitions: scene init succeeds");

  er_ui_transition_t spec = er_ui_transition(ER_UI_TEST_TRANSITION_ID, ER_UI_TRANSITION_OPACITY, 0.0f, 1.0f,
                                             ER_UI_TEST_TRANSITION_DURATION_MS, ER_UI_TEST_TRANSITION_DELAY_MS, ER_UI_EASING_LINEAR);
  expect_float(er_ui_runtime_transition_value(&state, spec), 1.0f, "runtime transitions: missing transition resolves to target");
  expect_status(er_ui_scene_push_transition(&scene, spec), ER_UI_OK, "runtime transitions: scene transition push succeeds");
  expect_status(er_ui_runtime_sync_transitions(&state, &scene, &changed), ER_UI_OK, "runtime transitions: sync succeeds");
  expect_true(changed, "runtime transitions: first sync reports changed");
  expect_float(er_ui_runtime_transition_value(&state, spec), 0.0f, "runtime transitions: synced delayed transition starts at from");
  expect_true(er_ui_runtime_transitions_active(&state), "runtime transitions: synced transition is active");

  expect_true(er_ui_runtime_advance_transitions(&state, ER_UI_TEST_TRANSITION_DELAY_MS), "runtime transitions: delay advance requests redraw");
  expect_float(er_ui_runtime_transition_value(&state, spec), 0.0f, "runtime transitions: delay keeps from value");
  expect_true(er_ui_runtime_advance_transitions(&state, ER_UI_TEST_TRANSITION_STEP_MS), "runtime transitions: active advance requests redraw");
  expect_float(er_ui_runtime_transition_value(&state, spec), 0.5f, "runtime transitions: active advance samples easing");
  expect_true(er_ui_runtime_advance_transitions(&state, ER_UI_TEST_TRANSITION_STEP_MS), "runtime transitions: final advance requests redraw");
  expect_float(er_ui_runtime_transition_value(&state, spec), 1.0f, "runtime transitions: final value reaches target");
  expect_true(!er_ui_runtime_advance_transitions(&state, 1u), "runtime transitions: completed transition does not redraw");
  expect_true(!er_ui_runtime_transitions_active(&state), "runtime transitions: completed transition is inactive");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_runtime_sync_transitions(&state, &scene, &changed), ER_UI_OK, "runtime transitions: stale sync succeeds");
  expect_true(changed, "runtime transitions: stale removal reports changed");
  expect_size(state.transition_count, 0u, "runtime transitions: stale transition removed");
  expect_float(er_ui_runtime_transition_value(&state, spec), 1.0f, "runtime transitions: stale transition resolves to target");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&state);
}

static void test_runtime_value_stores(void) {
  er_ui_runtime_state_t state = {0};
  expect_status(er_ui_runtime_state_init_with_allocator(&state, er_ui_test_allocator()), ER_UI_OK, "runtime values: state init succeeds");

  float scroll = 0.0f;
  expect_status(er_ui_runtime_read_scroll_offset(&state, ER_UI_TEST_RUNTIME_SCROLL_ID, &scroll), ER_UI_ERR_NOT_FOUND,
                "runtime values: missing scroll reports not found");
  expect_status(er_ui_runtime_set_scroll_offset(&state, ER_UI_TEST_RUNTIME_SCROLL_ID, 1.5f), ER_UI_OK, "runtime values: set scroll succeeds");
  expect_runtime_scroll(&state, ER_UI_TEST_RUNTIME_SCROLL_ID, 1.0f, "runtime values: scroll clamps high");
  expect_status(er_ui_runtime_set_scroll_offset(&state, ER_UI_TEST_RUNTIME_SCROLL_ID, -0.5f), ER_UI_OK, "runtime values: update scroll succeeds");
  expect_runtime_scroll(&state, ER_UI_TEST_RUNTIME_SCROLL_ID, 0.0f, "runtime values: scroll clamps low");

  bool toggle = false;
  expect_status(er_ui_runtime_read_toggle(&state, ER_UI_TEST_RUNTIME_TOGGLE_ID, &toggle), ER_UI_ERR_NOT_FOUND,
                "runtime values: missing toggle reports not found");
  expect_status(er_ui_runtime_set_toggle(&state, ER_UI_TEST_RUNTIME_TOGGLE_ID, false), ER_UI_OK, "runtime values: set toggle succeeds");
  expect_runtime_toggle(&state, ER_UI_TEST_RUNTIME_TOGGLE_ID, false, "runtime values: toggle returns stored value");

  float slider = 0.0f;
  expect_status(er_ui_runtime_read_slider(&state, ER_UI_TEST_RUNTIME_SLIDER_ID, &slider), ER_UI_ERR_NOT_FOUND,
                "runtime values: missing slider reports not found");
  expect_status(er_ui_runtime_set_slider(&state, ER_UI_TEST_RUNTIME_SLIDER_ID, 0.25f), ER_UI_OK, "runtime values: set slider succeeds");
  expect_runtime_slider(&state, ER_UI_TEST_RUNTIME_SLIDER_ID, 0.25f, "runtime values: slider returns stored value");

  bool open = false;
  expect_status(er_ui_runtime_read_open(&state, ER_UI_TEST_RUNTIME_OPEN_ONE_ID, &open), ER_UI_ERR_NOT_FOUND,
                "runtime values: missing open reports not found");
  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_RUNTIME_OPEN_ONE_ID, true), ER_UI_OK, "runtime values: set open one succeeds");
  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_RUNTIME_OPEN_TWO_ID, true), ER_UI_OK, "runtime values: set open two succeeds");
  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_RUNTIME_OPEN_ONE_ID, true), ER_UI_OK, "runtime values: reopening existing scope succeeds");
  expect_u32(state.open_values[state.open_value_count - 1u].id, ER_UI_TEST_RUNTIME_OPEN_ONE_ID, "runtime values: reopened scope moves to top");
  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_RUNTIME_OPEN_ONE_ID, false), ER_UI_OK, "runtime values: close open succeeds");
  expect_runtime_open(&state, ER_UI_TEST_RUNTIME_OPEN_ONE_ID, false, "runtime values: open returns stored closed value");

  er_ui_runtime_state_destroy(&state);
}

static void test_runtime_tabs_and_text_values(void) {
  er_ui_runtime_state_t state = {0};
  expect_status(er_ui_runtime_state_init_with_allocator(&state, er_ui_test_allocator()), ER_UI_OK, "runtime tabs: state init succeeds");

  expect_size(er_ui_runtime_selected_tab_index(&state, ER_UI_TEST_RUNTIME_TAB_GROUP_ID, ER_UI_TEST_RUNTIME_TAB_COUNT),
              0u, "runtime tabs: missing selection is first index");
  expect_status(er_ui_runtime_select_tab(&state, ER_UI_TEST_RUNTIME_TAB_FIRST_ID), ER_UI_OK, "runtime tabs: select tab 101 succeeds");
  expect_status(er_ui_runtime_select_tab(&state, ER_UI_TEST_RUNTIME_TAB_SECOND_ID), ER_UI_OK, "runtime tabs: select tab 102 succeeds");
  expect_status(er_ui_runtime_select_tab(&state, ER_UI_TEST_RUNTIME_TAB_FIRST_ID), ER_UI_OK, "runtime tabs: duplicate select is ignored");
  expect_size(state.selected_tab_id_count, ER_UI_TEST_RUNTIME_OPEN_TWO_ID, "runtime tabs: duplicate tab id is not stored twice");
  expect_size(er_ui_runtime_selected_tab_index(&state, ER_UI_TEST_RUNTIME_TAB_GROUP_ID, ER_UI_TEST_RUNTIME_TAB_COUNT),
              ER_UI_TEST_RUNTIME_TAB_COUNT - 1u, "runtime tabs: latest matching tab wins");
  expect_size(er_ui_runtime_selected_tab_index(&state, ER_UI_TEST_RUNTIME_EMPTY_TAB_GROUP_ID, ER_UI_TEST_RUNTIME_EMPTY_TAB_COUNT),
              0u, "runtime tabs: empty tab set returns zero");

  const char* text = NULL;
  expect_status(er_ui_runtime_read_text(&state, ER_UI_TEST_RUNTIME_TEXT_ID, &text), ER_UI_ERR_NOT_FOUND,
                "runtime text: missing text reports not found");
  expect_status(er_ui_runtime_set_text(&state, ER_UI_TEST_RUNTIME_TEXT_ID, "Trust Container"), ER_UI_OK, "runtime text: set text succeeds");
  expect_runtime_text(&state, ER_UI_TEST_RUNTIME_TEXT_ID, "Trust Container", "runtime text: stored text is returned");
  expect_status(er_ui_runtime_set_text(&state, ER_UI_TEST_RUNTIME_TEXT_ID, "Proof dashboard"), ER_UI_OK, "runtime text: update text succeeds");
  expect_runtime_text(&state, ER_UI_TEST_RUNTIME_TEXT_ID, "Proof dashboard", "runtime text: updated text is returned");
  const char invalid_utf8[] = {(char)0xE0, (char)0x80, (char)0x80, '\0'};
  expect_status(er_ui_runtime_set_text(&state, ER_UI_TEST_RUNTIME_INVALID_TEXT_ID, invalid_utf8), ER_UI_ERR_INVALID_ARGUMENT,
                "runtime text: invalid utf8 is rejected");

  er_ui_runtime_state_destroy(&state);
}

static void test_runtime_focus_helpers_and_scopes(void) {
  er_ui_runtime_state_t state = {0};
  er_ui_scene_t scene = {0};
  expect_status(er_ui_runtime_state_init_with_allocator(&state, er_ui_test_allocator()), ER_UI_OK, "runtime focus: state init succeeds");
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f), er_ui_test_allocator()), ER_UI_OK,
                "runtime focus: scene init succeeds");

  er_ui_hit_t outside = er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_TEST_POINTER_BUTTON_ID, 0.0f, 0.0f, 80.0f, 32.0f);
  er_ui_hit_t first = er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_TEST_INPUT_BUTTON_ID, 100.0f, 0.0f, 80.0f, 32.0f);
  er_ui_hit_t second = er_ui_hit(ER_UI_HIT_INPUT, ER_UI_TEST_INPUT_TEXT_ID, 190.0f, 0.0f, 80.0f, 32.0f);
  er_ui_hit_t ignored = er_ui_hit(ER_UI_HIT_SCROLL_AREA, ER_UI_TEST_INPUT_SCROLL_ID, 280.0f, 0.0f, 80.0f, 32.0f);

  expect_true(er_ui_runtime_is_focusable_hit(first), "runtime focus: button is focusable");
  expect_true(er_ui_runtime_is_text_hit(second), "runtime focus: input is text hit");
  expect_true(!er_ui_runtime_is_focusable_hit(ignored), "runtime focus: scroll area is not focusable");
  expect_true(!er_ui_runtime_is_text_hit(first), "runtime focus: button is not text hit");

  expect_status(er_ui_scene_push_hit(&scene, outside), ER_UI_OK, "runtime focus: outside push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, first), ER_UI_OK, "runtime focus: first push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, ignored), ER_UI_OK, "runtime focus: ignored push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, second), ER_UI_OK, "runtime focus: second push succeeds");

  er_ui_hit_t focused = {0};
  expect_true(er_ui_runtime_focus_first(&state, &scene, &focused), "runtime focus: focus first succeeds without scope");
  expect_u32(focused.id, outside.id, "runtime focus: focus first uses scene order without scope");
  expect_true(er_ui_runtime_focused(&state, &focused), "runtime focus: focused getter succeeds");
  expect_u32(focused.id, outside.id, "runtime focus: focused getter returns current focus");

  er_ui_hit_t scope_hits[] = {first, ignored, second};
  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_FOCUS_SCOPE_ID, true), ER_UI_OK, "runtime focus: open scope succeeds");
  expect_status(er_ui_runtime_set_focus_scope(&state, ER_UI_TEST_FOCUS_SCOPE_ID, scope_hits, ER_UI_TEST_FOCUS_SCOPE_INPUT_COUNT), ER_UI_OK,
                "runtime focus: set focus scope succeeds");
  uint32_t open_id = 0u;
  expect_true(er_ui_runtime_active_focus_scope_id(&state, &open_id), "runtime focus: active scope id is present");
  expect_u32(open_id, ER_UI_TEST_FOCUS_SCOPE_ID, "runtime focus: active scope id matches");
  expect_size(state.focus_scopes[0].hit_count, ER_UI_TEST_FOCUS_SCOPE_FOCUSABLE_COUNT, "runtime focus: non-focusable scope hit is filtered");
  expect_true(!er_ui_runtime_hit_allowed_by_focus_scope(&state, outside), "runtime focus: outside hit is blocked by scope");
  expect_true(er_ui_runtime_hit_allowed_by_focus_scope(&state, first), "runtime focus: scoped hit is allowed");

  expect_true(er_ui_runtime_focus_first(&state, &scene, &focused), "runtime focus: scoped focus first succeeds");
  expect_u32(focused.id, first.id, "runtime focus: scoped focus first skips outside");
  expect_true(er_ui_runtime_focus_next(&state, &scene, false, &focused), "runtime focus: focus next succeeds");
  expect_u32(focused.id, second.id, "runtime focus: focus next advances inside scope");
  expect_true(er_ui_runtime_focus_next(&state, &scene, false, &focused), "runtime focus: focus next wraps");
  expect_u32(focused.id, first.id, "runtime focus: focus next wraps to first scoped hit");
  expect_true(er_ui_runtime_focus_next(&state, &scene, true, &focused), "runtime focus: reverse focus succeeds");
  expect_u32(focused.id, second.id, "runtime focus: reverse focus wraps to last scoped hit");

  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_FOCUS_SCOPE_ID, false), ER_UI_OK, "runtime focus: close scope succeeds");
  expect_true(!er_ui_runtime_active_focus_scope_id(&state, &open_id), "runtime focus: closed scope is cleared");
  expect_size(state.focus_scope_count, 0u, "runtime focus: close removes focus scope entries");
  expect_true(er_ui_runtime_hit_allowed_by_focus_scope(&state, outside), "runtime focus: outside hit allowed after close");

  er_ui_runtime_clear_focus(&state);
  expect_true(!er_ui_runtime_focused(&state, &focused), "runtime focus: clear focus removes focused hit");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&state);
}

static void test_runtime_pointer_activation_dispatch(void) {
  er_ui_runtime_state_t state = {0};
  er_ui_scene_t scene = {0};
  expect_status(er_ui_runtime_state_init_with_allocator(&state, er_ui_test_allocator()), ER_UI_OK, "dispatch pointer: state init succeeds");
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f), er_ui_test_allocator()), ER_UI_OK,
                "dispatch pointer: scene init succeeds");

  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_TEST_POINTER_BUTTON_ID, 0.0f, 0.0f, 80.0f, 30.0f)), ER_UI_OK,
                "dispatch pointer: button hit push succeeds");
  er_ui_action_t action = er_ui_runtime_pointer_down(&state, &scene, 10.0f, 10.0f);
  expect_true(action.kind == ER_UI_ACTION_FOCUSED, "dispatch pointer: pointer down focuses button");
  expect_true(er_ui_action_needs_redraw(action), "dispatch pointer: focus action redraws");
  action = er_ui_runtime_pointer_up(&state, &scene, 10.0f, 10.0f);
  expect_true(action.kind == ER_UI_ACTION_ACTIVATED, "dispatch pointer: pointer up activates button");
  expect_u32(action.id, ER_UI_TEST_POINTER_BUTTON_ID, "dispatch pointer: activation carries hit id");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_TOGGLE, ER_UI_TEST_POINTER_TOGGLE_ID, 0.0f, 0.0f, 80.0f, 30.0f)), ER_UI_OK,
                "dispatch pointer: toggle hit push succeeds");
  (void)er_ui_runtime_pointer_down(&state, &scene, 10.0f, 10.0f);
  action = er_ui_runtime_pointer_up(&state, &scene, 10.0f, 10.0f);
  expect_true(action.kind == ER_UI_ACTION_TOGGLED, "dispatch pointer: toggle reports toggled");
  expect_true(action.bool_value, "dispatch pointer: toggle action carries value");
  expect_runtime_toggle(&state, ER_UI_TEST_POINTER_TOGGLE_ID, true, "dispatch pointer: toggle store updated");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_SELECT, ER_UI_TEST_POINTER_SELECT_ID, 0.0f, 0.0f, 80.0f, 30.0f)), ER_UI_OK,
                "dispatch pointer: select hit push succeeds");
  (void)er_ui_runtime_pointer_down(&state, &scene, 10.0f, 10.0f);
  action = er_ui_runtime_pointer_up(&state, &scene, 10.0f, 10.0f);
  expect_true(action.kind == ER_UI_ACTION_OPEN_CHANGED, "dispatch pointer: select opens");
  expect_runtime_open(&state, ER_UI_TEST_POINTER_SELECT_ID, true, "dispatch pointer: open store updated");

  er_ui_scene_clear_commands(&scene);
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_SLIDER, ER_UI_TEST_POINTER_SLIDER_ID, 0.0f, 0.0f, ER_UI_TEST_POINTER_SLIDER_W, 30.0f)),
                ER_UI_OK,
                "dispatch pointer: slider hit push succeeds");
  action = er_ui_runtime_pointer_down(&state, &scene, ER_UI_TEST_POINTER_SLIDER_X, 10.0f);
  expect_true(action.kind == ER_UI_ACTION_SLIDER_CHANGED, "dispatch pointer: slider changes on pointer down");
  expect_float(action.float_value, 0.75f, "dispatch pointer: slider action carries pointer value");
  expect_runtime_slider(&state, ER_UI_TEST_POINTER_SLIDER_ID, 0.75f, "dispatch pointer: slider store updated");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&state);
}

static void test_runtime_wheel_key_drag_and_blur_dispatch(void) {
  er_ui_runtime_state_t state = {0};
  er_ui_scene_t scene = {0};
  expect_status(er_ui_runtime_state_init_with_allocator(&state, er_ui_test_allocator()), ER_UI_OK, "dispatch input: state init succeeds");
  expect_status(er_ui_scene_init_with_allocator(&scene, er_ui_color_rgba(0.0f, 0.0f, 0.0f, 1.0f), er_ui_test_allocator()), ER_UI_OK,
                "dispatch input: scene init succeeds");

  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_TEST_INPUT_BUTTON_ID, 0.0f, 0.0f, 60.0f, 30.0f)), ER_UI_OK,
                "dispatch input: button push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_INPUT, ER_UI_TEST_INPUT_TEXT_ID, 70.0f, 0.0f, 60.0f, 30.0f)), ER_UI_OK,
                "dispatch input: input push succeeds");
  expect_status(er_ui_scene_push_hit(&scene, er_ui_hit(ER_UI_HIT_SCROLL_AREA, ER_UI_TEST_INPUT_SCROLL_ID, 0.0f, 40.0f, 160.0f, 80.0f)), ER_UI_OK,
                "dispatch input: scroll hit push succeeds");
  expect_status(er_ui_scene_push_drag_source(&scene, er_ui_drag_source(ER_UI_TEST_INPUT_DRAG_SCOPE_ID, ER_UI_TEST_INPUT_DRAG_ITEM_ID,
                                                                       ER_UI_TEST_INPUT_DRAG_FROM_INDEX, 0.0f, ER_UI_TEST_INPUT_DRAG_Y, 40.0f, 30.0f)),
                ER_UI_OK,
                "dispatch input: drag source push succeeds");
  expect_status(er_ui_scene_push_drop_target(&scene, er_ui_drop_target(ER_UI_TEST_INPUT_DRAG_SCOPE_ID, ER_UI_TEST_INPUT_DROP_INDEX, 100.0f,
                                                                       ER_UI_TEST_INPUT_DRAG_Y, 40.0f, 30.0f)),
                ER_UI_OK,
                "dispatch input: drop target push succeeds");

  er_ui_action_t action = er_ui_runtime_key_down(&state, &scene, er_ui_key(ER_UI_KEY_TAB), er_ui_key_modifiers_shift(false));
  expect_true(action.kind == ER_UI_ACTION_FOCUSED, "dispatch input: tab focuses first hit");
  expect_u32(action.id, ER_UI_TEST_INPUT_BUTTON_ID, "dispatch input: first focus is button");
  action = er_ui_runtime_key_down(&state, &scene, er_ui_key(ER_UI_KEY_TAB), er_ui_key_modifiers_shift(false));
  expect_true(action.kind == ER_UI_ACTION_FOCUSED, "dispatch input: second tab focuses next hit");
  expect_u32(action.id, ER_UI_TEST_INPUT_TEXT_ID, "dispatch input: second focus is input");

  action = er_ui_runtime_wheel(&state, &scene, 10.0f, 50.0f, 450.0f);
  expect_true(action.kind == ER_UI_ACTION_SCROLL_CHANGED, "dispatch input: wheel changes scroll");
  expect_runtime_scroll(&state, ER_UI_TEST_INPUT_SCROLL_ID, 0.5f, "dispatch input: wheel updates scroll store");

  action = er_ui_runtime_pointer_down(&state, &scene, 10.0f, 140.0f);
  expect_true(action.kind == ER_UI_ACTION_FOCUSED, "dispatch input: drag pointer down records source");
  action = er_ui_runtime_pointer_move(&state, &scene, 20.0f, 140.0f);
  expect_true(action.kind == ER_UI_ACTION_DRAG_STARTED, "dispatch input: drag starts after threshold");
  action = er_ui_runtime_pointer_move(&state, &scene, 110.0f, 140.0f);
  expect_true(action.kind == ER_UI_ACTION_DRAG_MOVED, "dispatch input: drag move reports target");
  expect_true(action.has_target, "dispatch input: drag move carries target");
  action = er_ui_runtime_pointer_up(&state, &scene, 110.0f, 140.0f);
  expect_true(action.kind == ER_UI_ACTION_REORDERED, "dispatch input: drag drop reports reorder");
  expect_size(action.from_index, ER_UI_TEST_INPUT_DRAG_FROM_INDEX, "dispatch input: reorder action carries source index");
  expect_size(action.to_index, ER_UI_TEST_INPUT_DROP_INDEX, "dispatch input: reorder action carries target index");

  expect_status(er_ui_runtime_set_open(&state, ER_UI_TEST_INPUT_OPEN_ID, true), ER_UI_OK, "dispatch input: open value set succeeds");
  action = er_ui_runtime_key_down(&state, &scene, er_ui_key(ER_UI_KEY_ESCAPE), er_ui_key_modifiers_shift(false));
  expect_true(action.kind == ER_UI_ACTION_OPEN_CHANGED, "dispatch input: escape closes top open scope");
  expect_runtime_open(&state, ER_UI_TEST_INPUT_OPEN_ID, false, "dispatch input: escape updates open store");

  (void)er_ui_runtime_pointer_down(&state, &scene, 10.0f, 10.0f);
  action = er_ui_runtime_blur(&state);
  expect_true(action.kind == ER_UI_ACTION_CANCELLED, "dispatch input: blur cancels active state");
  expect_true(!er_ui_runtime_focused(&state, &(er_ui_hit_t){0}), "dispatch input: blur clears focus");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&state);
}

void run_runtime_tests(void) {
  test_text_buffer_insert_and_cursor();
  test_text_buffer_key_handling();
  test_text_buffer_text_input_validation();
  test_text_buffer_delete_ranges();
  test_text_buffer_display_value();
  test_runtime_transitions_sync_and_advance();
  test_runtime_value_stores();
  test_runtime_tabs_and_text_values();
  test_runtime_focus_helpers_and_scopes();
  test_runtime_pointer_activation_dispatch();
  test_runtime_wheel_key_drag_and_blur_dispatch();
}
