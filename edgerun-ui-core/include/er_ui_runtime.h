#ifndef ER_UI_RUNTIME_H
#define ER_UI_RUNTIME_H

#include "er_ui_scene.h"

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_TEXT_BUFFER_MAX_BYTES 4096u

typedef enum {
  ER_UI_KEY_BACKSPACE = 0,
  ER_UI_KEY_DELETE,
  ER_UI_KEY_ENTER,
  ER_UI_KEY_ESCAPE,
  ER_UI_KEY_TAB,
  ER_UI_KEY_HOME,
  ER_UI_KEY_END,
  ER_UI_KEY_PAGE_UP,
  ER_UI_KEY_PAGE_DOWN,
  ER_UI_KEY_ARROW_LEFT,
  ER_UI_KEY_ARROW_RIGHT,
  ER_UI_KEY_ARROW_UP,
  ER_UI_KEY_ARROW_DOWN,
  ER_UI_KEY_OTHER
} er_ui_key_kind_t;

typedef enum {
  ER_UI_TEXT_ACTION_NONE = 0,
  ER_UI_TEXT_ACTION_CHANGED,
  ER_UI_TEXT_ACTION_SUBMIT
} er_ui_text_buffer_action_t;

typedef enum {
  ER_UI_ACTION_NONE = 0,
  ER_UI_ACTION_HOVERED,
  ER_UI_ACTION_FOCUSED,
  ER_UI_ACTION_ACTIVATED,
  ER_UI_ACTION_DRAG_STARTED,
  ER_UI_ACTION_DRAG_MOVED,
  ER_UI_ACTION_DROPPED,
  ER_UI_ACTION_REORDERED,
  ER_UI_ACTION_DRAG_CANCELLED,
  ER_UI_ACTION_TOGGLED,
  ER_UI_ACTION_TAB_SELECTED,
  ER_UI_ACTION_SLIDER_CHANGED,
  ER_UI_ACTION_OPEN_CHANGED,
  ER_UI_ACTION_SCROLL_CHANGED,
  ER_UI_ACTION_SUBMITTED,
  ER_UI_ACTION_CANCELLED
} er_ui_action_kind_t;

typedef struct {
  er_ui_key_kind_t kind;
  uint32_t codepoint;
} er_ui_key_t;

typedef struct {
  bool shift;
  bool ctrl;
  bool alt;
  bool meta;
} er_ui_key_modifiers_t;

typedef struct {
  er_ui_allocator_t allocator;
  char* value;
  size_t byte_len;
  size_t byte_capacity;
  size_t cursor_chars;
} er_ui_text_buffer_t;

typedef struct {
  uint32_t id;
  uint32_t elapsed_ms;
  uint32_t total_ms;
} er_ui_transition_state_t;

typedef struct {
  uint32_t id;
  float value;
} er_ui_pair_f32_t;

typedef struct {
  uint32_t id;
  bool value;
} er_ui_pair_bool_t;

typedef struct {
  uint32_t id;
  char* value;
} er_ui_pair_text_t;

typedef struct {
  er_ui_hit_kind_t kind;
  uint32_t id;
} er_ui_hit_ref_t;

typedef struct {
  uint32_t open_id;
  er_ui_hit_ref_t* hits;
  size_t hit_count;
  size_t hit_capacity;
} er_ui_focus_scope_t;

typedef struct {
  er_ui_drag_source_t source;
  bool has_target;
  er_ui_drop_target_t target;
  float start_x;
  float start_y;
  float current_x;
  float current_y;
  bool started;
} er_ui_drag_state_t;

typedef struct {
  er_ui_action_kind_t kind;
  bool has_hit;
  er_ui_hit_t hit;
  bool has_source;
  er_ui_drag_source_t source;
  bool has_target;
  er_ui_drop_target_t target;
  uint32_t id;
  uint32_t scope_id;
  uint32_t item_id;
  size_t from_index;
  size_t to_index;
  bool bool_value;
  float float_value;
} er_ui_action_t;

typedef struct {
  er_ui_allocator_t allocator;
  bool has_hovered;
  er_ui_hit_t hovered;
  bool has_active;
  er_ui_hit_t active;
  bool has_focused;
  er_ui_hit_t focused;
  bool has_drag;
  er_ui_drag_state_t drag;
  er_ui_transition_state_t* transitions;
  size_t transition_count;
  size_t transition_capacity;
  er_ui_pair_f32_t* scroll_offsets;
  size_t scroll_offset_count;
  size_t scroll_offset_capacity;
  er_ui_pair_bool_t* toggle_values;
  size_t toggle_value_count;
  size_t toggle_value_capacity;
  er_ui_pair_f32_t* slider_values;
  size_t slider_value_count;
  size_t slider_value_capacity;
  er_ui_pair_bool_t* open_values;
  size_t open_value_count;
  size_t open_value_capacity;
  er_ui_pair_text_t* text_values;
  size_t text_value_count;
  size_t text_value_capacity;
  uint32_t* selected_tab_ids;
  size_t selected_tab_id_count;
  size_t selected_tab_id_capacity;
  er_ui_focus_scope_t* focus_scopes;
  size_t focus_scope_count;
  size_t focus_scope_capacity;
} er_ui_runtime_state_t;

er_ui_key_t er_ui_key(er_ui_key_kind_t kind);
er_ui_key_t er_ui_key_other(uint32_t codepoint);
er_ui_key_modifiers_t er_ui_key_modifiers(bool shift, bool ctrl, bool alt, bool meta);
er_ui_key_modifiers_t er_ui_key_modifiers_shift(bool shift);

er_ui_status_t er_ui_text_buffer_init(er_ui_text_buffer_t* buffer);
er_ui_status_t er_ui_text_buffer_init_with_allocator(er_ui_text_buffer_t* buffer, er_ui_allocator_t allocator);
void er_ui_text_buffer_destroy(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_clear(er_ui_text_buffer_t* buffer);
bool er_ui_text_buffer_is_empty(const er_ui_text_buffer_t* buffer);
const char* er_ui_text_buffer_value(const er_ui_text_buffer_t* buffer);
size_t er_ui_text_buffer_byte_len(const er_ui_text_buffer_t* buffer);
size_t er_ui_text_buffer_cursor_chars(const er_ui_text_buffer_t* buffer);

er_ui_status_t er_ui_text_buffer_set_text(er_ui_text_buffer_t* buffer, const char* text);
er_ui_status_t er_ui_text_buffer_insert(er_ui_text_buffer_t* buffer, const char* text);
er_ui_status_t er_ui_text_buffer_handle_text_input(er_ui_text_buffer_t* buffer, const char* text, er_ui_text_buffer_action_t* out_action);
er_ui_status_t er_ui_text_buffer_handle_key(er_ui_text_buffer_t* buffer, er_ui_key_t key, bool shift, er_ui_text_buffer_action_t* out_action);
er_ui_status_t er_ui_text_buffer_handle_key_with_modifiers(er_ui_text_buffer_t* buffer, er_ui_key_t key, er_ui_key_modifiers_t modifiers, er_ui_text_buffer_action_t* out_action);

void er_ui_text_buffer_delete_before_cursor(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_delete_after_cursor(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_delete_before_cursor_all(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_delete_after_cursor_all(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_delete_word_before_cursor(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_move_cursor_left(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_move_cursor_right(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_move_cursor_to_start(er_ui_text_buffer_t* buffer);
void er_ui_text_buffer_move_cursor_to_end(er_ui_text_buffer_t* buffer);

er_ui_status_t er_ui_text_buffer_value_with_cursor(const er_ui_text_buffer_t* buffer, const char* marker, char** out_text);
er_ui_status_t er_ui_text_buffer_display_value(const er_ui_text_buffer_t* buffer, const char* placeholder, const char* cursor_marker, char** out_text);
void er_ui_text_buffer_free_text(const er_ui_text_buffer_t* buffer, char* text);

er_ui_status_t er_ui_runtime_state_init(er_ui_runtime_state_t* state);
er_ui_status_t er_ui_runtime_state_init_with_allocator(er_ui_runtime_state_t* state, er_ui_allocator_t allocator);
void er_ui_runtime_state_destroy(er_ui_runtime_state_t* state);
float er_ui_runtime_transition_value(const er_ui_runtime_state_t* state, er_ui_transition_t spec);
er_ui_status_t er_ui_runtime_sync_transitions(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, bool* out_changed);
bool er_ui_runtime_advance_transitions(er_ui_runtime_state_t* state, uint32_t delta_ms);
bool er_ui_runtime_transitions_active(const er_ui_runtime_state_t* state);

float er_ui_runtime_scroll_offset(const er_ui_runtime_state_t* state, uint32_t id);
bool er_ui_runtime_toggle_value(const er_ui_runtime_state_t* state, uint32_t id, bool fallback);
float er_ui_runtime_slider_value(const er_ui_runtime_state_t* state, uint32_t id, float fallback);
bool er_ui_runtime_open_value(const er_ui_runtime_state_t* state, uint32_t id, bool fallback);
size_t er_ui_runtime_selected_tab_index(const er_ui_runtime_state_t* state, uint32_t base_id, size_t len, size_t fallback);
const char* er_ui_runtime_text_value(const er_ui_runtime_state_t* state, uint32_t id, const char* fallback);

er_ui_status_t er_ui_runtime_set_scroll_offset(er_ui_runtime_state_t* state, uint32_t id, float offset);
er_ui_status_t er_ui_runtime_set_toggle(er_ui_runtime_state_t* state, uint32_t id, bool value);
er_ui_status_t er_ui_runtime_set_slider(er_ui_runtime_state_t* state, uint32_t id, float value);
er_ui_status_t er_ui_runtime_set_open(er_ui_runtime_state_t* state, uint32_t id, bool open);
er_ui_status_t er_ui_runtime_select_tab(er_ui_runtime_state_t* state, uint32_t id);
er_ui_status_t er_ui_runtime_set_text(er_ui_runtime_state_t* state, uint32_t id, const char* value);

bool er_ui_runtime_is_focusable_hit(er_ui_hit_t hit);
bool er_ui_runtime_is_text_hit(er_ui_hit_t hit);
bool er_ui_runtime_focused(const er_ui_runtime_state_t* state, er_ui_hit_t* out_hit);
void er_ui_runtime_clear_focus(er_ui_runtime_state_t* state);
er_ui_status_t er_ui_runtime_set_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id, const er_ui_hit_t* hits, size_t hit_count);
void er_ui_runtime_clear_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id);
bool er_ui_runtime_active_focus_scope_id(const er_ui_runtime_state_t* state, uint32_t* out_open_id);
bool er_ui_runtime_hit_allowed_by_focus_scope(const er_ui_runtime_state_t* state, er_ui_hit_t hit);
bool er_ui_runtime_focus_first(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, er_ui_hit_t* out_hit);
bool er_ui_runtime_focus_next(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, bool reverse, er_ui_hit_t* out_hit);

bool er_ui_action_needs_redraw(er_ui_action_t action);
er_ui_action_t er_ui_runtime_pointer_down(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y);
er_ui_action_t er_ui_runtime_pointer_move(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y);
er_ui_action_t er_ui_runtime_pointer_up(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y);
er_ui_action_t er_ui_runtime_wheel(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y, float delta_y);
er_ui_action_t er_ui_runtime_key_down(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, er_ui_key_t key, er_ui_key_modifiers_t modifiers);
er_ui_action_t er_ui_runtime_blur(er_ui_runtime_state_t* state);

#ifdef __cplusplus
}
#endif

#endif
