#include "er_ui_runtime.h"

static const size_t ER_UI_TEXT_INITIAL_CAPACITY = 32u;
static const size_t ER_UI_RUNTIME_INITIAL_CAPACITY = 8u;
static const float ER_UI_DRAG_START_THRESHOLD_PX = 5.0f;
static const float ER_UI_WHEEL_SCROLL_SCALE = 900.0f;
static const float ER_UI_KEY_SLIDER_STEP = 0.05f;
static const uint32_t ER_UI_CODEPOINT_ASCII_DELETE = 0x7Fu;
static const uint32_t ER_UI_CODEPOINT_C1_FIRST = 0x80u;
static const uint32_t ER_UI_CODEPOINT_C1_LAST = 0x9Fu;

typedef struct {
  uint32_t codepoint;
  size_t byte_len;
} er_ui_utf8_char_t;

static bool er_ui_utf8_validate_and_count(const char* text, size_t* out_byte_len, size_t* out_char_count);
bool er_ui_runtime_open_value(const er_ui_runtime_state_t* state, uint32_t id, bool fallback);
bool er_ui_runtime_is_focusable_hit(er_ui_hit_t hit);
void er_ui_runtime_clear_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id);

static void er_ui_zero_bytes(void* ptr, size_t size) {
  unsigned char* bytes = (unsigned char*)ptr;
  for (size_t i = 0u; i < size; ++i) bytes[i] = 0u;
}

static void er_ui_copy_bytes(void* dst, const void* src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  for (size_t i = 0u; i < size; ++i) out[i] = in[i];
}

static void er_ui_move_bytes(void* dst, const void* src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  if (out == in || size == 0u) return;
  if (out < in) {
    for (size_t i = 0u; i < size; ++i) out[i] = in[i];
  } else {
    for (size_t i = size; i > 0u; --i) out[i - 1u] = in[i - 1u];
  }
}

static size_t er_ui_cstr_len(const char* text) {
  size_t len = 0u;
  if (!text) return 0u;
  while (text[len] != '\0') len++;
  return len;
}

static bool er_ui_allocator_valid(er_ui_allocator_t allocator) {
  return allocator.alloc != 0 && allocator.free != 0;
}

static void er_ui_free_alloc(er_ui_allocator_t allocator, void* ptr, size_t size, size_t align) {
  if (ptr && er_ui_allocator_valid(allocator)) allocator.free(allocator.user, ptr, size, align);
}

static bool er_ui_text_reserve(er_ui_text_buffer_t* buffer, size_t byte_len) {
  if (!buffer) return false;
  if (!er_ui_allocator_valid(buffer->allocator)) return false;
  size_t needed = byte_len + 1u;
  if (needed <= buffer->byte_capacity) return true;

  size_t next_capacity = buffer->byte_capacity == 0u ? ER_UI_TEXT_INITIAL_CAPACITY : buffer->byte_capacity;
  while (next_capacity < needed) {
    if (next_capacity > ((size_t)-1) / 2u) return false;
    next_capacity *= 2u;
  }

  char* next = (char*)buffer->allocator.alloc(buffer->allocator.user, next_capacity, 1u);
  if (!next) return false;
  if (buffer->value && buffer->byte_capacity > 0u) er_ui_copy_bytes(next, buffer->value, buffer->byte_len + 1u);
  er_ui_free_alloc(buffer->allocator, buffer->value, buffer->byte_capacity, 1u);
  buffer->value = next;
  buffer->byte_capacity = next_capacity;
  return true;
}

static bool er_ui_runtime_reserve(er_ui_allocator_t allocator, void** data, size_t* capacity, size_t count, size_t item_size) {
  if (count < *capacity) return true;
  if (!er_ui_allocator_valid(allocator)) return false;

  size_t next_capacity = *capacity == 0u ? ER_UI_RUNTIME_INITIAL_CAPACITY : *capacity * 2u;
  if (next_capacity <= *capacity) return false;
  if (item_size != 0u && next_capacity > ((size_t)-1) / item_size) return false;

  size_t old_size = *capacity * item_size;
  size_t next_size = next_capacity * item_size;
  void* next = allocator.alloc(allocator.user, next_size, 4u);
  if (!next) return false;
  if (*data && old_size > 0u) er_ui_copy_bytes(next, *data, old_size);
  er_ui_free_alloc(allocator, *data, old_size, 4u);
  *data = next;
  *capacity = next_capacity;
  return true;
}

static float er_ui_runtime_clamp_float(float value, float min_value, float max_value) {
  if (value < min_value) return min_value;
  if (value > max_value) return max_value;
  return value;
}

static er_ui_transition_state_t er_ui_transition_state_new(er_ui_transition_t spec) {
  er_ui_transition_state_t state = {spec.id, 0u, spec.delay_ms + spec.duration_ms};
  if (state.total_ms < spec.delay_ms) state.total_ms = UINT32_MAX;
  return state;
}

static float er_ui_transition_state_value(er_ui_transition_state_t state, er_ui_transition_t spec) {
  if (state.elapsed_ms <= spec.delay_ms) return spec.from;
  uint32_t active_ms = state.elapsed_ms - spec.delay_ms;
  float t = (float)active_ms / (float)(spec.duration_ms == 0u ? 1u : spec.duration_ms);
  float eased = er_ui_transition_easing_sample(spec.easing, t);
  return spec.from + (spec.to - spec.from) * eased;
}

static bool er_ui_scene_has_transition(const er_ui_scene_t* scene, uint32_t id) {
  if (!scene) return false;
  for (size_t i = 0u; i < scene->transition_count; ++i) {
    if (scene->transitions[i].id == id) return true;
  }
  return false;
}

static bool er_ui_runtime_has_transition(const er_ui_runtime_state_t* state, uint32_t id) {
  if (!state) return false;
  for (size_t i = 0u; i < state->transition_count; ++i) {
    if (state->transitions[i].id == id) return true;
  }
  return false;
}

static er_ui_status_t er_ui_set_pair_f32(er_ui_allocator_t allocator, er_ui_pair_f32_t** values, size_t* count, size_t* capacity, uint32_t id, float value) {
  if (!values || !count || !capacity) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < *count; ++i) {
    if ((*values)[i].id == id) {
      (*values)[i].value = value;
      return ER_UI_OK;
    }
  }
  if (!er_ui_runtime_reserve(allocator, (void**)values, capacity, *count, sizeof(**values))) return ER_UI_ERR_OOM;
  (*values)[*count].id = id;
  (*values)[*count].value = value;
  (*count)++;
  return ER_UI_OK;
}

static er_ui_status_t er_ui_set_pair_bool(er_ui_allocator_t allocator, er_ui_pair_bool_t** values, size_t* count, size_t* capacity, uint32_t id, bool value) {
  if (!values || !count || !capacity) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < *count; ++i) {
    if ((*values)[i].id == id) {
      (*values)[i].value = value;
      return ER_UI_OK;
    }
  }
  if (!er_ui_runtime_reserve(allocator, (void**)values, capacity, *count, sizeof(**values))) return ER_UI_ERR_OOM;
  (*values)[*count].id = id;
  (*values)[*count].value = value;
  (*count)++;
  return ER_UI_OK;
}

static er_ui_status_t er_ui_strdup_validated(er_ui_allocator_t allocator, const char* value, char** out_value) {
  if (!value || !out_value) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_allocator_valid(allocator)) return ER_UI_ERR_OOM;
  size_t byte_len = 0u;
  size_t char_count = 0u;
  if (!er_ui_utf8_validate_and_count(value, &byte_len, &char_count)) return ER_UI_ERR_INVALID_ARGUMENT;
  (void)char_count;
  char* copy = (char*)allocator.alloc(allocator.user, byte_len + 1u, 1u);
  if (!copy) return ER_UI_ERR_OOM;
  er_ui_copy_bytes(copy, value, byte_len + 1u);
  *out_value = copy;
  return ER_UI_OK;
}

static bool er_ui_hit_refs_match(er_ui_hit_ref_t ref, er_ui_hit_t hit) {
  return ref.kind == hit.kind && ref.id == hit.id;
}

static bool er_ui_focus_scope_contains_hit(const er_ui_focus_scope_t* scope, er_ui_hit_t hit) {
  if (!scope) return false;
  for (size_t i = 0u; i < scope->hit_count; ++i) {
    if (er_ui_hit_refs_match(scope->hits[i], hit)) return true;
  }
  return false;
}

static const er_ui_focus_scope_t* er_ui_runtime_active_focus_scope(const er_ui_runtime_state_t* state) {
  if (!state) return NULL;
  for (size_t i = state->focus_scope_count; i > 0u; --i) {
    const er_ui_focus_scope_t* scope = &state->focus_scopes[i - 1u];
    if (scope->hit_count > 0u && er_ui_runtime_open_value(state, scope->open_id, false)) return scope;
  }
  return NULL;
}

static bool er_ui_runtime_scene_hit_focusable_in_scope(const er_ui_runtime_state_t* state, er_ui_hit_t hit) {
  if (!er_ui_runtime_is_focusable_hit(hit)) return false;
  const er_ui_focus_scope_t* scope = er_ui_runtime_active_focus_scope(state);
  if (!scope) return true;
  return er_ui_focus_scope_contains_hit(scope, hit);
}

static size_t er_ui_runtime_focusable_count(const er_ui_runtime_state_t* state, const er_ui_scene_t* scene) {
  if (!scene) return 0u;
  size_t count = 0u;
  for (size_t i = 0u; i < scene->hit_count; ++i) {
    if (er_ui_runtime_scene_hit_focusable_in_scope(state, scene->hits[i])) count++;
  }
  return count;
}

static bool er_ui_runtime_focusable_at(const er_ui_runtime_state_t* state, const er_ui_scene_t* scene, size_t target_index, er_ui_hit_t* out_hit) {
  if (!scene || !out_hit) return false;
  size_t focus_index = 0u;
  for (size_t i = 0u; i < scene->hit_count; ++i) {
    er_ui_hit_t hit = scene->hits[i];
    if (!er_ui_runtime_scene_hit_focusable_in_scope(state, hit)) continue;
    if (focus_index == target_index) {
      *out_hit = hit;
      return true;
    }
    focus_index++;
  }
  return false;
}

static bool er_ui_runtime_focused_index(const er_ui_runtime_state_t* state, const er_ui_scene_t* scene, size_t* out_index) {
  if (!state || !scene || !state->has_focused || !out_index) return false;
  size_t focus_index = 0u;
  for (size_t i = 0u; i < scene->hit_count; ++i) {
    er_ui_hit_t hit = scene->hits[i];
    if (!er_ui_runtime_scene_hit_focusable_in_scope(state, hit)) continue;
    if (hit.kind == state->focused.kind && hit.id == state->focused.id) {
      *out_index = focus_index;
      return true;
    }
    focus_index++;
  }
  return false;
}

static er_ui_action_t er_ui_action_none(void) {
  er_ui_action_t action;
  er_ui_zero_bytes(&action, sizeof(action));
  action.kind = ER_UI_ACTION_NONE;
  return action;
}

static er_ui_action_t er_ui_action_for_hit(er_ui_action_kind_t kind, er_ui_hit_t hit) {
  er_ui_action_t action = er_ui_action_none();
  action.kind = kind;
  action.has_hit = true;
  action.hit = hit;
  action.id = hit.id;
  return action;
}

static er_ui_action_t er_ui_action_bool(er_ui_action_kind_t kind, uint32_t id, bool value) {
  er_ui_action_t action = er_ui_action_none();
  action.kind = kind;
  action.id = id;
  action.bool_value = value;
  return action;
}

static er_ui_action_t er_ui_action_float(er_ui_action_kind_t kind, uint32_t id, float value) {
  er_ui_action_t action = er_ui_action_none();
  action.kind = kind;
  action.id = id;
  action.float_value = value;
  return action;
}

static er_ui_action_t er_ui_action_drag(er_ui_action_kind_t kind, er_ui_drag_source_t source, bool has_target, er_ui_drop_target_t target) {
  er_ui_action_t action = er_ui_action_none();
  action.kind = kind;
  action.has_source = true;
  action.source = source;
  action.scope_id = source.scope_id;
  action.item_id = source.item_id;
  action.from_index = source.index;
  if (has_target) {
    action.has_target = true;
    action.target = target;
    action.to_index = target.index;
  }
  return action;
}

static bool er_ui_hits_match(er_ui_hit_t a, er_ui_hit_t b) {
  return a.kind == b.kind && a.id == b.id;
}

static bool er_ui_drop_targets_match(er_ui_drop_target_t a, er_ui_drop_target_t b) {
  return a.scope_id == b.scope_id && a.index == b.index;
}

static bool er_ui_hit_contains(er_ui_hit_t hit, float x, float y) {
  return x >= hit.x && y >= hit.y && x <= hit.x + hit.w && y <= hit.y + hit.h;
}

static bool er_ui_drag_moved_far_enough(er_ui_drag_state_t drag, float x, float y) {
  float dx = x - drag.start_x;
  float dy = y - drag.start_y;
  return dx * dx + dy * dy >= ER_UI_DRAG_START_THRESHOLD_PX * ER_UI_DRAG_START_THRESHOLD_PX;
}

static float er_ui_slider_value_from_pointer(er_ui_hit_t hit, float x) {
  if (hit.w <= 0.0f) return 0.0f;
  return er_ui_runtime_clamp_float((x - hit.x) / hit.w, 0.0f, 1.0f);
}

static bool er_ui_scene_scroll_hit_at(const er_ui_scene_t* scene, float x, float y, er_ui_hit_t* out_hit) {
  if (!scene || !out_hit) return false;
  for (size_t i = scene->hit_count; i > 0u; --i) {
    er_ui_hit_t hit = scene->hits[i - 1u];
    if ((hit.kind == ER_UI_HIT_SCROLL_AREA || hit.kind == ER_UI_HIT_SCROLLBAR) && er_ui_hit_contains(hit, x, y)) {
      *out_hit = hit;
      return true;
    }
  }
  return false;
}

static bool er_ui_close_top_open_scope(er_ui_runtime_state_t* state, uint32_t* out_id) {
  if (!state || state->open_value_count == 0u) return false;
  for (size_t i = state->open_value_count; i > 0u; --i) {
    er_ui_pair_bool_t open = state->open_values[i - 1u];
    if (!open.value) continue;
    if (er_ui_runtime_set_open(state, open.id, false) != ER_UI_OK) return false;
    if (out_id) *out_id = open.id;
    return true;
  }
  return false;
}

static er_ui_action_t er_ui_activate_hit(er_ui_runtime_state_t* state, er_ui_hit_t hit, float x) {
  if (!state) return er_ui_action_none();
  switch (hit.kind) {
    case ER_UI_HIT_TOGGLE:
    case ER_UI_HIT_CHECKBOX: {
      bool next = !er_ui_runtime_toggle_value(state, hit.id, false);
      if (er_ui_runtime_set_toggle(state, hit.id, next) != ER_UI_OK) return er_ui_action_none();
      return er_ui_action_bool(ER_UI_ACTION_TOGGLED, hit.id, next);
    }
    case ER_UI_HIT_RADIO:
      if (er_ui_runtime_set_toggle(state, hit.id, true) != ER_UI_OK) return er_ui_action_none();
      return er_ui_action_bool(ER_UI_ACTION_TOGGLED, hit.id, true);
    case ER_UI_HIT_TAB:
    case ER_UI_HIT_WORKSPACE_TAB:
      if (er_ui_runtime_select_tab(state, hit.id) != ER_UI_OK) return er_ui_action_none();
      return er_ui_action_for_hit(ER_UI_ACTION_TAB_SELECTED, hit);
    case ER_UI_HIT_SLIDER: {
      float value = er_ui_slider_value_from_pointer(hit, x);
      if (er_ui_runtime_set_slider(state, hit.id, value) != ER_UI_OK) return er_ui_action_none();
      return er_ui_action_float(ER_UI_ACTION_SLIDER_CHANGED, hit.id, value);
    }
    case ER_UI_HIT_SELECT: {
      bool next = !er_ui_runtime_open_value(state, hit.id, false);
      if (er_ui_runtime_set_open(state, hit.id, next) != ER_UI_OK) return er_ui_action_none();
      return er_ui_action_bool(ER_UI_ACTION_OPEN_CHANGED, hit.id, next);
    }
    case ER_UI_HIT_INPUT:
    case ER_UI_HIT_TEXT_AREA:
    case ER_UI_HIT_COMPOSER:
      return er_ui_action_for_hit(ER_UI_ACTION_FOCUSED, hit);
    default:
      return er_ui_action_for_hit(ER_UI_ACTION_ACTIVATED, hit);
  }
}

static bool er_ui_utf8_decode_one(const char* text, size_t available, er_ui_utf8_char_t* out_char) {
  if (!text || available == 0u || !out_char) return false;

  const unsigned char b0 = (unsigned char)text[0];
  if (b0 <= 0x7Fu) {
    out_char->codepoint = b0;
    out_char->byte_len = 1u;
    return true;
  }

  if (b0 >= 0xC2u && b0 <= 0xDFu) {
    if (available < 2u) return false;
    const unsigned char b1 = (unsigned char)text[1];
    if ((b1 & 0xC0u) != 0x80u) return false;
    out_char->codepoint = ((uint32_t)(b0 & 0x1Fu) << 6u) | (uint32_t)(b1 & 0x3Fu);
    out_char->byte_len = 2u;
    return true;
  }

  if (b0 >= 0xE0u && b0 <= 0xEFu) {
    if (available < 3u) return false;
    const unsigned char b1 = (unsigned char)text[1];
    const unsigned char b2 = (unsigned char)text[2];
    if ((b1 & 0xC0u) != 0x80u || (b2 & 0xC0u) != 0x80u) return false;
    if (b0 == 0xE0u && b1 < 0xA0u) return false;
    if (b0 == 0xEDu && b1 >= 0xA0u) return false;
    out_char->codepoint = ((uint32_t)(b0 & 0x0Fu) << 12u) | ((uint32_t)(b1 & 0x3Fu) << 6u) | (uint32_t)(b2 & 0x3Fu);
    out_char->byte_len = 3u;
    return true;
  }

  if (b0 >= 0xF0u && b0 <= 0xF4u) {
    if (available < 4u) return false;
    const unsigned char b1 = (unsigned char)text[1];
    const unsigned char b2 = (unsigned char)text[2];
    const unsigned char b3 = (unsigned char)text[3];
    if ((b1 & 0xC0u) != 0x80u || (b2 & 0xC0u) != 0x80u || (b3 & 0xC0u) != 0x80u) return false;
    if (b0 == 0xF0u && b1 < 0x90u) return false;
    if (b0 == 0xF4u && b1 > 0x8Fu) return false;
    out_char->codepoint = ((uint32_t)(b0 & 0x07u) << 18u) | ((uint32_t)(b1 & 0x3Fu) << 12u) |
                          ((uint32_t)(b2 & 0x3Fu) << 6u) | (uint32_t)(b3 & 0x3Fu);
    out_char->byte_len = 4u;
    return true;
  }

  return false;
}

static bool er_ui_utf8_validate_and_count(const char* text, size_t* out_byte_len, size_t* out_char_count) {
  if (!text || !out_byte_len || !out_char_count) return false;
  size_t byte_len = er_ui_cstr_len(text);
  size_t offset = 0u;
  size_t char_count = 0u;
  while (offset < byte_len) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(text + offset, byte_len - offset, &ch)) return false;
    offset += ch.byte_len;
    char_count++;
  }
  *out_byte_len = byte_len;
  *out_char_count = char_count;
  return true;
}

static size_t er_ui_text_cursor_byte_index(const er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return 0u;
  size_t offset = 0u;
  size_t char_index = 0u;
  while (offset < buffer->byte_len && char_index < buffer->cursor_chars) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(buffer->value + offset, buffer->byte_len - offset, &ch)) return buffer->byte_len;
    offset += ch.byte_len;
    char_index++;
  }
  return offset;
}

static size_t er_ui_text_char_count(const er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return 0u;
  size_t offset = 0u;
  size_t char_count = 0u;
  while (offset < buffer->byte_len) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(buffer->value + offset, buffer->byte_len - offset, &ch)) return char_count;
    offset += ch.byte_len;
    char_count++;
  }
  return char_count;
}

static bool er_ui_codepoint_is_control(uint32_t codepoint) {
  return codepoint <= 0x1Fu || codepoint == ER_UI_CODEPOINT_ASCII_DELETE ||
         (codepoint >= ER_UI_CODEPOINT_C1_FIRST && codepoint <= ER_UI_CODEPOINT_C1_LAST);
}

static bool er_ui_codepoint_is_whitespace(uint32_t codepoint) {
  switch (codepoint) {
    case 0x09u:
    case 0x0Au:
    case 0x0Bu:
    case 0x0Cu:
    case 0x0Du:
    case 0x20u:
    case 0x85u:
    case 0xA0u:
    case 0x1680u:
    case 0x2000u:
    case 0x2001u:
    case 0x2002u:
    case 0x2003u:
    case 0x2004u:
    case 0x2005u:
    case 0x2006u:
    case 0x2007u:
    case 0x2008u:
    case 0x2009u:
    case 0x200Au:
    case 0x2028u:
    case 0x2029u:
    case 0x202Fu:
    case 0x205Fu:
    case 0x3000u:
      return true;
    default:
      return false;
  }
}

static uint32_t er_ui_text_codepoint_before_cursor(const er_ui_text_buffer_t* buffer) {
  if (!buffer || buffer->cursor_chars == 0u) return 0u;
  size_t offset = 0u;
  size_t char_index = 0u;
  uint32_t codepoint = 0u;
  while (offset < buffer->byte_len && char_index < buffer->cursor_chars) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(buffer->value + offset, buffer->byte_len - offset, &ch)) return 0u;
    codepoint = ch.codepoint;
    offset += ch.byte_len;
    char_index++;
  }
  return codepoint;
}

er_ui_key_t er_ui_key(er_ui_key_kind_t kind) {
  er_ui_key_t key = {kind, 0u};
  return key;
}

er_ui_key_t er_ui_key_other(uint32_t codepoint) {
  er_ui_key_t key = {ER_UI_KEY_OTHER, codepoint};
  return key;
}

er_ui_key_modifiers_t er_ui_key_modifiers(bool shift, bool ctrl, bool alt, bool meta) {
  er_ui_key_modifiers_t modifiers = {shift, ctrl, alt, meta};
  return modifiers;
}

er_ui_key_modifiers_t er_ui_key_modifiers_shift(bool shift) {
  return er_ui_key_modifiers(shift, false, false, false);
}

er_ui_status_t er_ui_text_buffer_init(er_ui_text_buffer_t* buffer) {
  er_ui_allocator_t allocator = {0};
  return er_ui_text_buffer_init_with_allocator(buffer, allocator);
}

er_ui_status_t er_ui_text_buffer_init_with_allocator(er_ui_text_buffer_t* buffer, er_ui_allocator_t allocator) {
  if (!buffer) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_zero_bytes(buffer, sizeof(*buffer));
  buffer->allocator = allocator;
  if (!er_ui_text_reserve(buffer, 0u)) return ER_UI_ERR_OOM;
  buffer->value[0] = '\0';
  return ER_UI_OK;
}

void er_ui_text_buffer_destroy(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  er_ui_allocator_t allocator = buffer->allocator;
  er_ui_free_alloc(allocator, buffer->value, buffer->byte_capacity, 1u);
  er_ui_zero_bytes(buffer, sizeof(*buffer));
}

void er_ui_text_buffer_clear(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  buffer->value[0] = '\0';
  buffer->byte_len = 0u;
  buffer->cursor_chars = 0u;
}

bool er_ui_text_buffer_is_empty(const er_ui_text_buffer_t* buffer) {
  return !buffer || buffer->byte_len == 0u;
}

const char* er_ui_text_buffer_value(const er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return "";
  return buffer->value;
}

size_t er_ui_text_buffer_byte_len(const er_ui_text_buffer_t* buffer) {
  return buffer ? buffer->byte_len : 0u;
}

size_t er_ui_text_buffer_cursor_chars(const er_ui_text_buffer_t* buffer) {
  return buffer ? buffer->cursor_chars : 0u;
}

er_ui_status_t er_ui_text_buffer_set_text(er_ui_text_buffer_t* buffer, const char* text) {
  if (!buffer || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t byte_len = 0u;
  size_t char_count = 0u;
  if (!er_ui_utf8_validate_and_count(text, &byte_len, &char_count)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (byte_len > ER_UI_TEXT_BUFFER_MAX_BYTES) return ER_UI_ERR_INVALID_ARGUMENT;
  if (!er_ui_text_reserve(buffer, byte_len)) return ER_UI_ERR_OOM;
  er_ui_copy_bytes(buffer->value, text, byte_len + 1u);
  buffer->byte_len = byte_len;
  buffer->cursor_chars = char_count;
  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_insert(er_ui_text_buffer_t* buffer, const char* text) {
  if (!buffer || !buffer->value || !text) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t insert_len = 0u;
  size_t insert_chars = 0u;
  if (!er_ui_utf8_validate_and_count(text, &insert_len, &insert_chars)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (insert_len == 0u) return ER_UI_OK;
  if (buffer->byte_len > ER_UI_TEXT_BUFFER_MAX_BYTES || insert_len > ER_UI_TEXT_BUFFER_MAX_BYTES - buffer->byte_len) {
    return ER_UI_ERR_INVALID_ARGUMENT;
  }

  size_t byte_index = er_ui_text_cursor_byte_index(buffer);
  if (!er_ui_text_reserve(buffer, buffer->byte_len + insert_len)) return ER_UI_ERR_OOM;
  er_ui_move_bytes(buffer->value + byte_index + insert_len, buffer->value + byte_index, buffer->byte_len - byte_index + 1u);
  er_ui_copy_bytes(buffer->value + byte_index, text, insert_len);
  buffer->byte_len += insert_len;
  buffer->cursor_chars += insert_chars;
  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_handle_text_input(er_ui_text_buffer_t* buffer, const char* text, er_ui_text_buffer_action_t* out_action) {
  if (!buffer || !buffer->value || !text || !out_action) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_action = ER_UI_TEXT_ACTION_NONE;

  size_t byte_len = 0u;
  size_t ignored_char_count = 0u;
  if (!er_ui_utf8_validate_and_count(text, &byte_len, &ignored_char_count)) return ER_UI_ERR_INVALID_ARGUMENT;

  size_t offset = 0u;
  while (offset < byte_len && buffer->byte_len < ER_UI_TEXT_BUFFER_MAX_BYTES) {
    er_ui_utf8_char_t ch = {0};
    if (!er_ui_utf8_decode_one(text + offset, byte_len - offset, &ch)) return ER_UI_ERR_INVALID_ARGUMENT;
    if (!er_ui_codepoint_is_control(ch.codepoint)) {
      size_t available = ER_UI_TEXT_BUFFER_MAX_BYTES - buffer->byte_len;
      if (ch.byte_len > available) break;
      char one[5] = {0};
      er_ui_copy_bytes(one, text + offset, ch.byte_len);
      er_ui_status_t status = er_ui_text_buffer_insert(buffer, one);
      if (status != ER_UI_OK) return status;
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
    }
    offset += ch.byte_len;
  }

  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_handle_key(er_ui_text_buffer_t* buffer, er_ui_key_t key, bool shift, er_ui_text_buffer_action_t* out_action) {
  return er_ui_text_buffer_handle_key_with_modifiers(buffer, key, er_ui_key_modifiers_shift(shift), out_action);
}

er_ui_status_t er_ui_text_buffer_handle_key_with_modifiers(er_ui_text_buffer_t* buffer, er_ui_key_t key, er_ui_key_modifiers_t modifiers, er_ui_text_buffer_action_t* out_action) {
  if (!buffer || !buffer->value || !out_action) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_action = ER_UI_TEXT_ACTION_NONE;
  size_t before = buffer->byte_len;

  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'a' || key.codepoint == 'A')) {
    er_ui_text_buffer_move_cursor_to_start(buffer);
    *out_action = ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'e' || key.codepoint == 'E')) {
    er_ui_text_buffer_move_cursor_to_end(buffer);
    *out_action = ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'u' || key.codepoint == 'U')) {
    er_ui_text_buffer_delete_before_cursor_all(buffer);
    *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'k' || key.codepoint == 'K')) {
    er_ui_text_buffer_delete_after_cursor_all(buffer);
    *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }
  if (key.kind == ER_UI_KEY_OTHER && modifiers.ctrl && (key.codepoint == 'w' || key.codepoint == 'W')) {
    er_ui_text_buffer_delete_word_before_cursor(buffer);
    *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
    return ER_UI_OK;
  }

  switch (key.kind) {
    case ER_UI_KEY_BACKSPACE:
      er_ui_text_buffer_delete_before_cursor(buffer);
      *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_DELETE:
      er_ui_text_buffer_delete_after_cursor(buffer);
      *out_action = buffer->byte_len == before ? ER_UI_TEXT_ACTION_NONE : ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_ENTER:
      if (modifiers.shift) {
        er_ui_status_t status = er_ui_text_buffer_insert(buffer, "\n");
        if (status != ER_UI_OK) return status;
        *out_action = ER_UI_TEXT_ACTION_CHANGED;
      } else {
        *out_action = ER_UI_TEXT_ACTION_SUBMIT;
      }
      break;
    case ER_UI_KEY_ARROW_LEFT:
      er_ui_text_buffer_move_cursor_left(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_ARROW_RIGHT:
      er_ui_text_buffer_move_cursor_right(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_HOME:
      er_ui_text_buffer_move_cursor_to_start(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    case ER_UI_KEY_END:
      er_ui_text_buffer_move_cursor_to_end(buffer);
      *out_action = ER_UI_TEXT_ACTION_CHANGED;
      break;
    default:
      *out_action = ER_UI_TEXT_ACTION_NONE;
      break;
  }

  return ER_UI_OK;
}

void er_ui_text_buffer_delete_before_cursor(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value || buffer->cursor_chars == 0u) return;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  buffer->cursor_chars--;
  size_t start = er_ui_text_cursor_byte_index(buffer);
  er_ui_move_bytes(buffer->value + start, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end - start;
}

void er_ui_text_buffer_delete_after_cursor(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  size_t start = er_ui_text_cursor_byte_index(buffer);
  if (start == buffer->byte_len) return;
  buffer->cursor_chars++;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  buffer->cursor_chars--;
  er_ui_move_bytes(buffer->value + start, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end - start;
}

void er_ui_text_buffer_delete_before_cursor_all(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  er_ui_move_bytes(buffer->value, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end;
  buffer->cursor_chars = 0u;
}

void er_ui_text_buffer_delete_after_cursor_all(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value) return;
  size_t start = er_ui_text_cursor_byte_index(buffer);
  buffer->value[start] = '\0';
  buffer->byte_len = start;
}

void er_ui_text_buffer_delete_word_before_cursor(er_ui_text_buffer_t* buffer) {
  if (!buffer || !buffer->value || buffer->cursor_chars == 0u) return;
  size_t end = er_ui_text_cursor_byte_index(buffer);
  while (buffer->cursor_chars > 0u && er_ui_codepoint_is_whitespace(er_ui_text_codepoint_before_cursor(buffer))) {
    buffer->cursor_chars--;
  }
  while (buffer->cursor_chars > 0u && !er_ui_codepoint_is_whitespace(er_ui_text_codepoint_before_cursor(buffer))) {
    buffer->cursor_chars--;
  }
  size_t start = er_ui_text_cursor_byte_index(buffer);
  er_ui_move_bytes(buffer->value + start, buffer->value + end, buffer->byte_len - end + 1u);
  buffer->byte_len -= end - start;
}

void er_ui_text_buffer_move_cursor_left(er_ui_text_buffer_t* buffer) {
  if (!buffer || buffer->cursor_chars == 0u) return;
  buffer->cursor_chars--;
}

void er_ui_text_buffer_move_cursor_right(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  size_t char_count = er_ui_text_char_count(buffer);
  if (buffer->cursor_chars < char_count) buffer->cursor_chars++;
}

void er_ui_text_buffer_move_cursor_to_start(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  buffer->cursor_chars = 0u;
}

void er_ui_text_buffer_move_cursor_to_end(er_ui_text_buffer_t* buffer) {
  if (!buffer) return;
  buffer->cursor_chars = er_ui_text_char_count(buffer);
}

er_ui_status_t er_ui_text_buffer_value_with_cursor(const er_ui_text_buffer_t* buffer, const char* marker, char** out_text) {
  if (!buffer || !buffer->value || !marker || !out_text) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t marker_len = 0u;
  size_t marker_chars = 0u;
  if (!er_ui_utf8_validate_and_count(marker, &marker_len, &marker_chars)) return ER_UI_ERR_INVALID_ARGUMENT;
  if (marker_chars != 1u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (buffer->byte_len > ((size_t)-1) - marker_len - 1u) return ER_UI_ERR_INVALID_ARGUMENT;

  size_t byte_index = er_ui_text_cursor_byte_index(buffer);
  if (!er_ui_allocator_valid(buffer->allocator)) return ER_UI_ERR_OOM;
  char* out = (char*)buffer->allocator.alloc(buffer->allocator.user, buffer->byte_len + marker_len + 1u, 1u);
  if (!out) return ER_UI_ERR_OOM;
  er_ui_copy_bytes(out, buffer->value, byte_index);
  er_ui_copy_bytes(out + byte_index, marker, marker_len);
  er_ui_copy_bytes(out + byte_index + marker_len, buffer->value + byte_index, buffer->byte_len - byte_index + 1u);
  *out_text = out;
  return ER_UI_OK;
}

er_ui_status_t er_ui_text_buffer_display_value(const er_ui_text_buffer_t* buffer, const char* placeholder, const char* cursor_marker, char** out_text) {
  if (!buffer || !placeholder || !cursor_marker || !out_text) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_text_buffer_is_empty(buffer)) {
    size_t placeholder_len = 0u;
    size_t placeholder_chars = 0u;
    if (!er_ui_utf8_validate_and_count(placeholder, &placeholder_len, &placeholder_chars)) return ER_UI_ERR_INVALID_ARGUMENT;
    if (!er_ui_allocator_valid(buffer->allocator)) return ER_UI_ERR_OOM;
    char* out = (char*)buffer->allocator.alloc(buffer->allocator.user, placeholder_len + 1u, 1u);
    if (!out) return ER_UI_ERR_OOM;
    er_ui_copy_bytes(out, placeholder, placeholder_len + 1u);
    *out_text = out;
    return ER_UI_OK;
  }
  return er_ui_text_buffer_value_with_cursor(buffer, cursor_marker, out_text);
}

void er_ui_text_buffer_free_text(const er_ui_text_buffer_t* buffer, char* text) {
  if (!buffer || !text) return;
  er_ui_free_alloc(buffer->allocator, text, er_ui_cstr_len(text) + 1u, 1u);
}

er_ui_status_t er_ui_runtime_state_init(er_ui_runtime_state_t* state) {
  er_ui_allocator_t allocator = {0};
  return er_ui_runtime_state_init_with_allocator(state, allocator);
}

er_ui_status_t er_ui_runtime_state_init_with_allocator(er_ui_runtime_state_t* state, er_ui_allocator_t allocator) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_zero_bytes(state, sizeof(*state));
  state->allocator = allocator;
  return ER_UI_OK;
}

void er_ui_runtime_state_destroy(er_ui_runtime_state_t* state) {
  if (!state) return;
  er_ui_allocator_t allocator = state->allocator;
  er_ui_free_alloc(allocator, state->transitions, state->transition_capacity * sizeof(*state->transitions), 4u);
  er_ui_free_alloc(allocator, state->scroll_offsets, state->scroll_offset_capacity * sizeof(*state->scroll_offsets), 4u);
  er_ui_free_alloc(allocator, state->toggle_values, state->toggle_value_capacity * sizeof(*state->toggle_values), 4u);
  er_ui_free_alloc(allocator, state->slider_values, state->slider_value_capacity * sizeof(*state->slider_values), 4u);
  er_ui_free_alloc(allocator, state->open_values, state->open_value_capacity * sizeof(*state->open_values), 4u);
  for (size_t i = 0u; i < state->text_value_count; ++i) {
    er_ui_free_alloc(allocator, state->text_values[i].value, er_ui_cstr_len(state->text_values[i].value) + 1u, 1u);
  }
  er_ui_free_alloc(allocator, state->text_values, state->text_value_capacity * sizeof(*state->text_values), 4u);
  er_ui_free_alloc(allocator, state->selected_tab_ids, state->selected_tab_id_capacity * sizeof(*state->selected_tab_ids), 4u);
  for (size_t i = 0u; i < state->focus_scope_count; ++i) {
    er_ui_free_alloc(allocator, state->focus_scopes[i].hits, state->focus_scopes[i].hit_capacity * sizeof(*state->focus_scopes[i].hits), 4u);
  }
  er_ui_free_alloc(allocator, state->focus_scopes, state->focus_scope_capacity * sizeof(*state->focus_scopes), 4u);
  er_ui_zero_bytes(state, sizeof(*state));
}

float er_ui_runtime_transition_value(const er_ui_runtime_state_t* state, er_ui_transition_t spec) {
  if (!state) return spec.to;
  for (size_t i = 0u; i < state->transition_count; ++i) {
    if (state->transitions[i].id == spec.id) return er_ui_transition_state_value(state->transitions[i], spec);
  }
  return spec.to;
}

er_ui_status_t er_ui_runtime_sync_transitions(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, bool* out_changed) {
  if (!state || !scene || !out_changed) return ER_UI_ERR_INVALID_ARGUMENT;
  bool changed = false;
  size_t before = state->transition_count;

  for (size_t i = 0u; i < scene->transition_count; ++i) {
    er_ui_transition_t spec = scene->transitions[i];
    if (!er_ui_runtime_has_transition(state, spec.id)) {
      if (!er_ui_runtime_reserve(state->allocator, (void**)&state->transitions, &state->transition_capacity, state->transition_count,
                                 sizeof(*state->transitions))) {
        return ER_UI_ERR_OOM;
      }
      state->transitions[state->transition_count++] = er_ui_transition_state_new(spec);
      changed = true;
    }
  }

  size_t write_index = 0u;
  for (size_t read_index = 0u; read_index < state->transition_count; ++read_index) {
    er_ui_transition_state_t item = state->transitions[read_index];
    if (er_ui_scene_has_transition(scene, item.id)) {
      state->transitions[write_index++] = item;
    }
  }
  state->transition_count = write_index;
  changed = changed || state->transition_count != before;
  *out_changed = changed;
  return ER_UI_OK;
}

bool er_ui_runtime_advance_transitions(er_ui_runtime_state_t* state, uint32_t delta_ms) {
  if (!state) return false;
  bool needs_redraw = false;
  for (size_t i = 0u; i < state->transition_count; ++i) {
    er_ui_transition_state_t* transition = &state->transitions[i];
    if (transition->elapsed_ms < transition->total_ms) {
      uint32_t next = transition->elapsed_ms + delta_ms;
      if (next < transition->elapsed_ms || next > transition->total_ms) next = transition->total_ms;
      transition->elapsed_ms = next;
      needs_redraw = true;
    }
  }
  return needs_redraw;
}

bool er_ui_runtime_transitions_active(const er_ui_runtime_state_t* state) {
  if (!state) return false;
  for (size_t i = 0u; i < state->transition_count; ++i) {
    if (state->transitions[i].elapsed_ms < state->transitions[i].total_ms) return true;
  }
  return false;
}

float er_ui_runtime_scroll_offset(const er_ui_runtime_state_t* state, uint32_t id) {
  if (!state) return 0.0f;
  for (size_t i = 0u; i < state->scroll_offset_count; ++i) {
    if (state->scroll_offsets[i].id == id) return state->scroll_offsets[i].value;
  }
  return 0.0f;
}

bool er_ui_runtime_toggle_value(const er_ui_runtime_state_t* state, uint32_t id, bool fallback) {
  if (!state) return fallback;
  for (size_t i = 0u; i < state->toggle_value_count; ++i) {
    if (state->toggle_values[i].id == id) return state->toggle_values[i].value;
  }
  return fallback;
}

float er_ui_runtime_slider_value(const er_ui_runtime_state_t* state, uint32_t id, float fallback) {
  float value = fallback;
  if (state) {
    for (size_t i = 0u; i < state->slider_value_count; ++i) {
      if (state->slider_values[i].id == id) {
        value = state->slider_values[i].value;
        break;
      }
    }
  }
  return er_ui_runtime_clamp_float(value, 0.0f, 1.0f);
}

bool er_ui_runtime_open_value(const er_ui_runtime_state_t* state, uint32_t id, bool fallback) {
  if (!state) return fallback;
  for (size_t i = 0u; i < state->open_value_count; ++i) {
    if (state->open_values[i].id == id) return state->open_values[i].value;
  }
  return fallback;
}

size_t er_ui_runtime_selected_tab_index(const er_ui_runtime_state_t* state, uint32_t base_id, size_t len, size_t fallback) {
  if (len == 0u) return 0u;
  if (!state) return fallback < len ? fallback : len - 1u;
  for (size_t i = state->selected_tab_id_count; i > 0u; --i) {
    uint32_t selected_id = state->selected_tab_ids[i - 1u];
    if (selected_id >= base_id && selected_id < base_id + (uint32_t)len) return (size_t)(selected_id - base_id);
  }
  return fallback < len ? fallback : len - 1u;
}

const char* er_ui_runtime_text_value(const er_ui_runtime_state_t* state, uint32_t id, const char* fallback) {
  if (!fallback) fallback = "";
  if (!state) return fallback;
  for (size_t i = 0u; i < state->text_value_count; ++i) {
    if (state->text_values[i].id == id) return state->text_values[i].value ? state->text_values[i].value : "";
  }
  return fallback;
}

er_ui_status_t er_ui_runtime_set_scroll_offset(er_ui_runtime_state_t* state, uint32_t id, float offset) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_set_pair_f32(state->allocator, &state->scroll_offsets, &state->scroll_offset_count, &state->scroll_offset_capacity, id,
                            er_ui_runtime_clamp_float(offset, 0.0f, 1.0f));
}

er_ui_status_t er_ui_runtime_set_toggle(er_ui_runtime_state_t* state, uint32_t id, bool value) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_set_pair_bool(state->allocator, &state->toggle_values, &state->toggle_value_count, &state->toggle_value_capacity, id, value);
}

er_ui_status_t er_ui_runtime_set_slider(er_ui_runtime_state_t* state, uint32_t id, float value) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_set_pair_f32(state->allocator, &state->slider_values, &state->slider_value_count, &state->slider_value_capacity, id,
                            er_ui_runtime_clamp_float(value, 0.0f, 1.0f));
}

er_ui_status_t er_ui_runtime_set_open(er_ui_runtime_state_t* state, uint32_t id, bool open) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < state->open_value_count; ++i) {
    if (state->open_values[i].id == id) {
      state->open_values[i].value = open;
      if (open && i + 1u < state->open_value_count) {
        er_ui_pair_bool_t entry = state->open_values[i];
        er_ui_move_bytes(state->open_values + i, state->open_values + i + 1u, (state->open_value_count - i - 1u) * sizeof(*state->open_values));
        state->open_values[state->open_value_count - 1u] = entry;
      }
      if (!open) er_ui_runtime_clear_focus_scope(state, id);
      return ER_UI_OK;
    }
  }
  if (!er_ui_runtime_reserve(state->allocator, (void**)&state->open_values, &state->open_value_capacity, state->open_value_count,
                             sizeof(*state->open_values))) {
    return ER_UI_ERR_OOM;
  }
  state->open_values[state->open_value_count].id = id;
  state->open_values[state->open_value_count].value = open;
  state->open_value_count++;
  if (!open) er_ui_runtime_clear_focus_scope(state, id);
  return ER_UI_OK;
}

er_ui_status_t er_ui_runtime_select_tab(er_ui_runtime_state_t* state, uint32_t id) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = 0u; i < state->selected_tab_id_count; ++i) {
    if (state->selected_tab_ids[i] == id) return ER_UI_OK;
  }
  if (!er_ui_runtime_reserve(state->allocator, (void**)&state->selected_tab_ids, &state->selected_tab_id_capacity, state->selected_tab_id_count,
                             sizeof(*state->selected_tab_ids))) {
    return ER_UI_ERR_OOM;
  }
  state->selected_tab_ids[state->selected_tab_id_count++] = id;
  return ER_UI_OK;
}

er_ui_status_t er_ui_runtime_set_text(er_ui_runtime_state_t* state, uint32_t id, const char* value) {
  if (!state || !value) return ER_UI_ERR_INVALID_ARGUMENT;
  char* copy = NULL;
  er_ui_status_t status = er_ui_strdup_validated(state->allocator, value, &copy);
  if (status != ER_UI_OK) return status;

  for (size_t i = 0u; i < state->text_value_count; ++i) {
    if (state->text_values[i].id == id) {
      er_ui_free_alloc(state->allocator, state->text_values[i].value, er_ui_cstr_len(state->text_values[i].value) + 1u, 1u);
      state->text_values[i].value = copy;
      return ER_UI_OK;
    }
  }

  if (!er_ui_runtime_reserve(state->allocator, (void**)&state->text_values, &state->text_value_capacity, state->text_value_count,
                             sizeof(*state->text_values))) {
    er_ui_free_alloc(state->allocator, copy, er_ui_cstr_len(copy) + 1u, 1u);
    return ER_UI_ERR_OOM;
  }
  state->text_values[state->text_value_count].id = id;
  state->text_values[state->text_value_count].value = copy;
  state->text_value_count++;
  return ER_UI_OK;
}

bool er_ui_runtime_is_focusable_hit(er_ui_hit_t hit) {
  switch (hit.kind) {
    case ER_UI_HIT_BUTTON:
    case ER_UI_HIT_TAB:
    case ER_UI_HIT_TOGGLE:
    case ER_UI_HIT_LIST_ROW:
    case ER_UI_HIT_INPUT:
    case ER_UI_HIT_TEXT_AREA:
    case ER_UI_HIT_SLIDER:
    case ER_UI_HIT_CHECKBOX:
    case ER_UI_HIT_RADIO:
    case ER_UI_HIT_SELECT:
    case ER_UI_HIT_BREADCRUMB:
    case ER_UI_HIT_TREE_ITEM:
    case ER_UI_HIT_MENU_ITEM:
    case ER_UI_HIT_TRANSACTION_ROW:
    case ER_UI_HIT_COMPOSER:
    case ER_UI_HIT_SEND:
    case ER_UI_HIT_WORKSPACE_TAB:
    case ER_UI_HIT_WORKSPACE_CLOSE:
    case ER_UI_HIT_WORKSPACE_SPLIT:
    case ER_UI_HIT_SHELL_LAUNCHER:
    case ER_UI_HIT_APP_LAUNCHER_ITEM:
      return true;
    default:
      return false;
  }
}

bool er_ui_runtime_is_text_hit(er_ui_hit_t hit) {
  switch (hit.kind) {
    case ER_UI_HIT_INPUT:
    case ER_UI_HIT_TEXT_AREA:
    case ER_UI_HIT_COMPOSER:
      return true;
    default:
      return false;
  }
}

bool er_ui_runtime_focused(const er_ui_runtime_state_t* state, er_ui_hit_t* out_hit) {
  if (!state || !state->has_focused || !out_hit) return false;
  *out_hit = state->focused;
  return true;
}

void er_ui_runtime_clear_focus(er_ui_runtime_state_t* state) {
  if (!state) return;
  state->has_focused = false;
}

er_ui_status_t er_ui_runtime_set_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id, const er_ui_hit_t* hits, size_t hit_count) {
  if (!state || (!hits && hit_count > 0u)) return ER_UI_ERR_INVALID_ARGUMENT;

  size_t focusable_count = 0u;
  for (size_t i = 0u; i < hit_count; ++i) {
    if (er_ui_runtime_is_focusable_hit(hits[i])) focusable_count++;
  }

  er_ui_hit_ref_t* refs = NULL;
  if (focusable_count > 0u) {
    if (!er_ui_allocator_valid(state->allocator)) return ER_UI_ERR_OOM;
    refs = (er_ui_hit_ref_t*)state->allocator.alloc(state->allocator.user, focusable_count * sizeof(*refs), 4u);
    if (!refs) return ER_UI_ERR_OOM;
    size_t write_index = 0u;
    for (size_t i = 0u; i < hit_count; ++i) {
      if (!er_ui_runtime_is_focusable_hit(hits[i])) continue;
      refs[write_index].kind = hits[i].kind;
      refs[write_index].id = hits[i].id;
      write_index++;
    }
  }

  for (size_t i = 0u; i < state->focus_scope_count; ++i) {
    if (state->focus_scopes[i].open_id == open_id) {
      er_ui_free_alloc(state->allocator, state->focus_scopes[i].hits, state->focus_scopes[i].hit_capacity * sizeof(*state->focus_scopes[i].hits), 4u);
      state->focus_scopes[i].hits = refs;
      state->focus_scopes[i].hit_count = focusable_count;
      state->focus_scopes[i].hit_capacity = focusable_count;
      return ER_UI_OK;
    }
  }

  if (!er_ui_runtime_reserve(state->allocator, (void**)&state->focus_scopes, &state->focus_scope_capacity, state->focus_scope_count,
                             sizeof(*state->focus_scopes))) {
    er_ui_free_alloc(state->allocator, refs, focusable_count * sizeof(*refs), 4u);
    return ER_UI_ERR_OOM;
  }

  state->focus_scopes[state->focus_scope_count].open_id = open_id;
  state->focus_scopes[state->focus_scope_count].hits = refs;
  state->focus_scopes[state->focus_scope_count].hit_count = focusable_count;
  state->focus_scopes[state->focus_scope_count].hit_capacity = focusable_count;
  state->focus_scope_count++;
  return ER_UI_OK;
}

void er_ui_runtime_clear_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id) {
  if (!state) return;
  for (size_t i = 0u; i < state->focus_scope_count; ++i) {
    if (state->focus_scopes[i].open_id != open_id) continue;
    er_ui_free_alloc(state->allocator, state->focus_scopes[i].hits, state->focus_scopes[i].hit_capacity * sizeof(*state->focus_scopes[i].hits), 4u);
    if (i + 1u < state->focus_scope_count) {
      er_ui_move_bytes(state->focus_scopes + i, state->focus_scopes + i + 1u, (state->focus_scope_count - i - 1u) * sizeof(*state->focus_scopes));
    }
    state->focus_scope_count--;
    return;
  }
}

bool er_ui_runtime_active_focus_scope_id(const er_ui_runtime_state_t* state, uint32_t* out_open_id) {
  const er_ui_focus_scope_t* scope = er_ui_runtime_active_focus_scope(state);
  if (!scope || !out_open_id) return false;
  *out_open_id = scope->open_id;
  return true;
}

bool er_ui_runtime_hit_allowed_by_focus_scope(const er_ui_runtime_state_t* state, er_ui_hit_t hit) {
  const er_ui_focus_scope_t* scope = er_ui_runtime_active_focus_scope(state);
  if (!scope) return true;
  return er_ui_focus_scope_contains_hit(scope, hit);
}

bool er_ui_runtime_focus_first(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, er_ui_hit_t* out_hit) {
  if (!state || !scene || !out_hit) return false;
  er_ui_hit_t hit = {0};
  if (!er_ui_runtime_focusable_at(state, scene, 0u, &hit)) {
    state->has_focused = false;
    return false;
  }
  state->focused = hit;
  state->has_focused = true;
  *out_hit = hit;
  return true;
}

bool er_ui_runtime_focus_next(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, bool reverse, er_ui_hit_t* out_hit) {
  if (!state || !scene || !out_hit) return false;
  size_t count = er_ui_runtime_focusable_count(state, scene);
  if (count == 0u) {
    state->has_focused = false;
    return false;
  }

  size_t index = 0u;
  if (!er_ui_runtime_focused_index(state, scene, &index)) {
    index = reverse ? 0u : count - 1u;
  }

  size_t next_index = 0u;
  if (reverse) {
    next_index = index == 0u ? count - 1u : index - 1u;
  } else {
    next_index = (index + 1u) % count;
  }

  er_ui_hit_t hit = {0};
  if (!er_ui_runtime_focusable_at(state, scene, next_index, &hit)) {
    state->has_focused = false;
    return false;
  }
  state->focused = hit;
  state->has_focused = true;
  *out_hit = hit;
  return true;
}

bool er_ui_action_needs_redraw(er_ui_action_t action) {
  return action.kind != ER_UI_ACTION_NONE;
}

er_ui_action_t er_ui_runtime_pointer_down(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y) {
  if (!state || !scene) return er_ui_action_none();

  er_ui_drag_source_t source = {0};
  bool has_source = er_ui_scene_drag_source_at(scene, x, y, &source);

  er_ui_hit_t hit = {0};
  if (er_ui_scene_hit_test(scene, x, y, &hit) && er_ui_runtime_hit_allowed_by_focus_scope(state, hit)) {
    state->hovered = hit;
    state->has_hovered = true;
    state->active = hit;
    state->has_active = true;
    if (er_ui_runtime_is_focusable_hit(hit)) {
      state->focused = hit;
      state->has_focused = true;
    }
    if (has_source) {
      er_ui_zero_bytes(&state->drag, sizeof(state->drag));
      state->drag.source = source;
      state->drag.start_x = x;
      state->drag.start_y = y;
      state->drag.current_x = x;
      state->drag.current_y = y;
      state->has_drag = true;
    }

    if (hit.kind == ER_UI_HIT_SLIDER) return er_ui_activate_hit(state, hit, x);
    return er_ui_action_for_hit(er_ui_runtime_is_focusable_hit(hit) ? ER_UI_ACTION_FOCUSED : ER_UI_ACTION_HOVERED, hit);
  }

  state->has_active = false;
  state->has_hovered = false;
  er_ui_runtime_clear_focus(state);

  if (has_source) {
    er_ui_zero_bytes(&state->drag, sizeof(state->drag));
    state->drag.source = source;
    state->drag.start_x = x;
    state->drag.start_y = y;
    state->drag.current_x = x;
    state->drag.current_y = y;
    state->has_drag = true;
    return er_ui_action_drag(ER_UI_ACTION_FOCUSED, source, false, (er_ui_drop_target_t){0});
  }

  return er_ui_action_none();
}

er_ui_action_t er_ui_runtime_pointer_move(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y) {
  if (!state || !scene) return er_ui_action_none();

  if (state->has_drag) {
    state->drag.current_x = x;
    state->drag.current_y = y;
    if (!state->drag.started && er_ui_drag_moved_far_enough(state->drag, x, y)) {
      state->drag.started = true;
      return er_ui_action_drag(ER_UI_ACTION_DRAG_STARTED, state->drag.source, false, (er_ui_drop_target_t){0});
    }
    if (!state->drag.started) return er_ui_action_none();

    er_ui_drop_target_t target = {0};
    bool has_target = er_ui_scene_drop_target_at(scene, x, y, state->drag.source.scope_id, &target);
    bool changed = has_target != state->drag.has_target || (has_target && !er_ui_drop_targets_match(target, state->drag.target));
    state->drag.has_target = has_target;
    if (has_target) state->drag.target = target;
    return changed ? er_ui_action_drag(ER_UI_ACTION_DRAG_MOVED, state->drag.source, has_target, target) : er_ui_action_none();
  }

  er_ui_hit_t hit = {0};
  if (er_ui_scene_hit_test(scene, x, y, &hit) && er_ui_runtime_hit_allowed_by_focus_scope(state, hit)) {
    bool changed = !state->has_hovered || !er_ui_hits_match(state->hovered, hit);
    state->hovered = hit;
    state->has_hovered = true;
    return changed ? er_ui_action_for_hit(ER_UI_ACTION_HOVERED, hit) : er_ui_action_none();
  }

  if (state->has_hovered) {
    state->has_hovered = false;
    return er_ui_action_none();
  }
  return er_ui_action_none();
}

er_ui_action_t er_ui_runtime_pointer_up(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y) {
  if (!state || !scene) return er_ui_action_none();

  if (state->has_drag) {
    er_ui_drag_state_t drag = state->drag;
    state->has_drag = false;
    er_ui_zero_bytes(&state->drag, sizeof(state->drag));
    if (drag.started && drag.has_target) {
      er_ui_action_kind_t kind = drag.source.index == drag.target.index ? ER_UI_ACTION_DROPPED : ER_UI_ACTION_REORDERED;
      return er_ui_action_drag(kind, drag.source, true, drag.target);
    }
    return drag.started ? er_ui_action_drag(ER_UI_ACTION_DRAG_CANCELLED, drag.source, false, (er_ui_drop_target_t){0}) : er_ui_action_none();
  }

  er_ui_hit_t hit = {0};
  bool has_hit = er_ui_scene_hit_test(scene, x, y, &hit) && er_ui_runtime_hit_allowed_by_focus_scope(state, hit);
  bool activate = has_hit && state->has_active && er_ui_hits_match(state->active, hit) && er_ui_hit_contains(state->active, x, y);
  state->has_active = false;
  if (!activate) return er_ui_action_none();
  return er_ui_activate_hit(state, hit, x);
}

er_ui_action_t er_ui_runtime_wheel(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, float x, float y, float delta_y) {
  if (!state || !scene || delta_y == 0.0f) return er_ui_action_none();
  er_ui_hit_t hit = {0};
  if (!er_ui_scene_scroll_hit_at(scene, x, y, &hit)) return er_ui_action_none();

  float next = er_ui_runtime_scroll_offset(state, hit.id) + delta_y / ER_UI_WHEEL_SCROLL_SCALE;
  next = er_ui_runtime_clamp_float(next, 0.0f, 1.0f);
  if (er_ui_runtime_set_scroll_offset(state, hit.id, next) != ER_UI_OK) return er_ui_action_none();
  return er_ui_action_float(ER_UI_ACTION_SCROLL_CHANGED, hit.id, next);
}

er_ui_action_t er_ui_runtime_key_down(er_ui_runtime_state_t* state, const er_ui_scene_t* scene, er_ui_key_t key, er_ui_key_modifiers_t modifiers) {
  if (!state || !scene) return er_ui_action_none();

  if (key.kind == ER_UI_KEY_ESCAPE) {
    if (state->has_drag) {
      er_ui_drag_source_t source = state->drag.source;
      state->has_drag = false;
      er_ui_zero_bytes(&state->drag, sizeof(state->drag));
      return er_ui_action_drag(ER_UI_ACTION_DRAG_CANCELLED, source, false, (er_ui_drop_target_t){0});
    }
    uint32_t closed_id = 0u;
    if (er_ui_close_top_open_scope(state, &closed_id)) return er_ui_action_bool(ER_UI_ACTION_OPEN_CHANGED, closed_id, false);
    state->has_active = false;
    return er_ui_action_none();
  }

  if (key.kind == ER_UI_KEY_TAB) {
    er_ui_hit_t hit = {0};
    if (!er_ui_runtime_focus_next(state, scene, modifiers.shift, &hit)) return er_ui_action_none();
    return er_ui_action_for_hit(ER_UI_ACTION_FOCUSED, hit);
  }

  if (!state->has_focused) return er_ui_action_none();

  if (state->focused.kind == ER_UI_HIT_SLIDER && (key.kind == ER_UI_KEY_ARROW_LEFT || key.kind == ER_UI_KEY_ARROW_RIGHT)) {
    float delta = key.kind == ER_UI_KEY_ARROW_LEFT ? -ER_UI_KEY_SLIDER_STEP : ER_UI_KEY_SLIDER_STEP;
    float next = er_ui_runtime_slider_value(state, state->focused.id, 0.0f) + delta;
    next = er_ui_runtime_clamp_float(next, 0.0f, 1.0f);
    if (er_ui_runtime_set_slider(state, state->focused.id, next) != ER_UI_OK) return er_ui_action_none();
    return er_ui_action_float(ER_UI_ACTION_SLIDER_CHANGED, state->focused.id, next);
  }

  if (key.kind == ER_UI_KEY_ENTER || (key.kind == ER_UI_KEY_OTHER && key.codepoint == ' ')) {
    return er_ui_activate_hit(state, state->focused, state->focused.x + state->focused.w * 0.5f);
  }

  return er_ui_action_none();
}

er_ui_action_t er_ui_runtime_blur(er_ui_runtime_state_t* state) {
  if (!state) return er_ui_action_none();
  bool changed = state->has_hovered || state->has_active || state->has_focused || state->has_drag;
  state->has_hovered = false;
  state->has_active = false;
  state->has_focused = false;
  state->has_drag = false;
  er_ui_zero_bytes(&state->drag, sizeof(state->drag));
  return changed ? er_ui_action_bool(ER_UI_ACTION_CANCELLED, 0u, false) : er_ui_action_none();
}
