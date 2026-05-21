#include "er_ui_runtime_internal.h"

static er_ui_action_t er_ui_action_none(void) {
  er_ui_action_t action;
  er_ui_mem_zero(&action, sizeof(action));
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
      bool value = false;
      er_ui_status_t read_status = er_ui_runtime_read_toggle(state, hit.id, &value);
      if (read_status != ER_UI_OK && read_status != ER_UI_ERR_NOT_FOUND) return er_ui_action_none();
      bool next = !value;
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
      bool open = false;
      er_ui_status_t read_status = er_ui_runtime_read_open(state, hit.id, &open);
      if (read_status != ER_UI_OK && read_status != ER_UI_ERR_NOT_FOUND) return er_ui_action_none();
      bool next = !open;
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
      er_ui_runtime_begin_drag(state, source, x, y);
    }

    if (hit.kind == ER_UI_HIT_SLIDER) return er_ui_activate_hit(state, hit, x);
    return er_ui_action_for_hit(er_ui_runtime_is_focusable_hit(hit) ? ER_UI_ACTION_FOCUSED : ER_UI_ACTION_HOVERED, hit);
  }

  state->has_active = false;
  state->has_hovered = false;
  er_ui_runtime_clear_focus(state);

  if (has_source) {
    er_ui_runtime_begin_drag(state, source, x, y);
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
    er_ui_mem_zero(&state->drag, sizeof(state->drag));
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

  float offset = 0.0f;
  er_ui_status_t read_status = er_ui_runtime_read_scroll_offset(state, hit.id, &offset);
  if (read_status != ER_UI_OK && read_status != ER_UI_ERR_NOT_FOUND) return er_ui_action_none();
  float next = offset + delta_y / ER_UI_WHEEL_SCROLL_SCALE;
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
      er_ui_mem_zero(&state->drag, sizeof(state->drag));
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
    float value = 0.0f;
    er_ui_status_t read_status = er_ui_runtime_read_slider(state, state->focused.id, &value);
    if (read_status != ER_UI_OK && read_status != ER_UI_ERR_NOT_FOUND) return er_ui_action_none();
    float next = value + delta;
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
  er_ui_mem_zero(&state->drag, sizeof(state->drag));
  return changed ? er_ui_action_bool(ER_UI_ACTION_CANCELLED, 0u, false) : er_ui_action_none();
}
