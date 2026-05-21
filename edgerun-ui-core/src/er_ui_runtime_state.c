#include "er_ui_runtime_internal.h"

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

er_ui_status_t er_ui_runtime_state_init(er_ui_runtime_state_t* state) {
  er_ui_allocator_t allocator = {0};
  return er_ui_runtime_state_init_with_allocator(state, allocator);
}

er_ui_status_t er_ui_runtime_state_init_with_allocator(er_ui_runtime_state_t* state, er_ui_allocator_t allocator) {
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_mem_zero(state, sizeof(*state));
  state->allocator = allocator;
  return ER_UI_OK;
}

//@optimizer-ignore-function runtime destroy must free each owned dynamic state collection
void er_ui_runtime_state_destroy(er_ui_runtime_state_t* state) {
  if (!state) return;
  er_ui_allocator_t allocator = state->allocator;
  er_ui_allocator_free(allocator, state->transitions, state->transition_capacity * sizeof(*state->transitions), 4u);
  er_ui_allocator_free(allocator, state->scroll_offsets, state->scroll_offset_capacity * sizeof(*state->scroll_offsets), 4u);
  er_ui_allocator_free(allocator, state->toggle_values, state->toggle_value_capacity * sizeof(*state->toggle_values), 4u);
  er_ui_allocator_free(allocator, state->slider_values, state->slider_value_capacity * sizeof(*state->slider_values), 4u);
  er_ui_allocator_free(allocator, state->open_values, state->open_value_capacity * sizeof(*state->open_values), 4u);
  for (size_t i = 0u; i < state->text_value_count; ++i) {
    er_ui_allocator_free(allocator, state->text_values[i].value, er_ui_cstr_len(state->text_values[i].value) + 1u, 1u);
  }
  er_ui_allocator_free(allocator, state->text_values, state->text_value_capacity * sizeof(*state->text_values), 4u);
  er_ui_allocator_free(allocator, state->selected_tab_ids, state->selected_tab_id_capacity * sizeof(*state->selected_tab_ids), 4u);
  for (size_t i = 0u; i < state->focus_scope_count; ++i) {
    er_ui_allocator_free(allocator, state->focus_scopes[i].hits, state->focus_scopes[i].hit_capacity * sizeof(*state->focus_scopes[i].hits), 4u);
  }
  er_ui_allocator_free(allocator, state->focus_scopes, state->focus_scope_capacity * sizeof(*state->focus_scopes), 4u);
  er_ui_mem_zero(state, sizeof(*state));
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

//@optimizer-ignore-function transition advance must visit each active transition once per frame
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

er_ui_status_t er_ui_runtime_read_scroll_offset(const er_ui_runtime_state_t* state, uint32_t id, float* out_offset) {
  if (!state || !out_offset) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_offset = 0.0f;
  for (size_t i = 0u; i < state->scroll_offset_count; ++i) {
    if (state->scroll_offsets[i].id == id) {
      *out_offset = state->scroll_offsets[i].value;
      return ER_UI_OK;
    }
  }
  return ER_UI_ERR_NOT_FOUND;
}

er_ui_status_t er_ui_runtime_read_toggle(const er_ui_runtime_state_t* state, uint32_t id, bool* out_value) {
  if (!state || !out_value) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_value = false;
  for (size_t i = 0u; i < state->toggle_value_count; ++i) {
    if (state->toggle_values[i].id == id) {
      *out_value = state->toggle_values[i].value;
      return ER_UI_OK;
    }
  }
  return ER_UI_ERR_NOT_FOUND;
}

er_ui_status_t er_ui_runtime_read_slider(const er_ui_runtime_state_t* state, uint32_t id, float* out_value) {
  if (!state || !out_value) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_value = 0.0f;
  for (size_t i = 0u; i < state->slider_value_count; ++i) {
    if (state->slider_values[i].id == id) {
      *out_value = er_ui_runtime_clamp_float(state->slider_values[i].value, 0.0f, 1.0f);
      return ER_UI_OK;
    }
  }
  return ER_UI_ERR_NOT_FOUND;
}

er_ui_status_t er_ui_runtime_read_open(const er_ui_runtime_state_t* state, uint32_t id, bool* out_open) {
  if (!state || !out_open) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_open = false;
  for (size_t i = 0u; i < state->open_value_count; ++i) {
    if (state->open_values[i].id == id) {
      *out_open = state->open_values[i].value;
      return ER_UI_OK;
    }
  }
  return ER_UI_ERR_NOT_FOUND;
}

size_t er_ui_runtime_selected_tab_index(const er_ui_runtime_state_t* state, uint32_t base_id, size_t len) {
  if (len == 0u) return 0u;
  if (!state) return 0u;
  for (size_t i = state->selected_tab_id_count; i > 0u; --i) {
    uint32_t selected_id = state->selected_tab_ids[i - 1u];
    if (selected_id >= base_id && selected_id < base_id + (uint32_t)len) return (size_t)(selected_id - base_id);
  }
  return 0u;
}

er_ui_status_t er_ui_runtime_read_text(const er_ui_runtime_state_t* state, uint32_t id, const char** out_value) {
  if (!state || !out_value) return ER_UI_ERR_INVALID_ARGUMENT;
  *out_value = "";
  for (size_t i = 0u; i < state->text_value_count; ++i) {
    if (state->text_values[i].id == id) {
      *out_value = state->text_values[i].value ? state->text_values[i].value : "";
      return ER_UI_OK;
    }
  }
  return ER_UI_ERR_NOT_FOUND;
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
        er_ui_mem_move(state->open_values + i, state->open_values + i + 1u, (state->open_value_count - i - 1u) * sizeof(*state->open_values));
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

//@optimizer-ignore-function text state replacement must scan ids and free the replaced value
er_ui_status_t er_ui_runtime_set_text(er_ui_runtime_state_t* state, uint32_t id, const char* value) {
  if (!state || !value) return ER_UI_ERR_INVALID_ARGUMENT;
  char* copy = NULL;
  er_ui_status_t status = er_ui_strdup_validated(state->allocator, value, &copy);
  if (status != ER_UI_OK) return status;

  for (size_t i = 0u; i < state->text_value_count; ++i) {
    if (state->text_values[i].id == id) {
      er_ui_allocator_free(state->allocator, state->text_values[i].value, er_ui_cstr_len(state->text_values[i].value) + 1u, 1u);
      state->text_values[i].value = copy;
      return ER_UI_OK;
    }
  }

  if (!er_ui_runtime_reserve(state->allocator, (void**)&state->text_values, &state->text_value_capacity, state->text_value_count,
                             sizeof(*state->text_values))) {
    er_ui_allocator_free(state->allocator, copy, er_ui_cstr_len(copy) + 1u, 1u);
    return ER_UI_ERR_OOM;
  }
  state->text_values[state->text_value_count].id = id;
  state->text_values[state->text_value_count].value = copy;
  state->text_value_count++;
  return ER_UI_OK;
}
