#include "er_ui_runtime_internal.h"

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

//@optimizer-ignore-function focus scope registration must filter hit refs and replace existing scope storage
er_ui_status_t er_ui_runtime_set_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id, const er_ui_hit_t* hits, size_t hit_count) {
  if (!state || (!hits && hit_count > 0u)) return ER_UI_ERR_INVALID_ARGUMENT;

  size_t focusable_count = 0u;
  for (size_t i = 0u; i < hit_count; ++i) {
    if (er_ui_runtime_is_focusable_hit(hits[i])) focusable_count++;
  }

  er_ui_hit_ref_t* refs = NULL;
  if (focusable_count > 0u) {
    if (!er_ui_allocator_is_valid(state->allocator)) return ER_UI_ERR_OOM;
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
      er_ui_allocator_free(state->allocator, state->focus_scopes[i].hits, state->focus_scopes[i].hit_capacity * sizeof(*state->focus_scopes[i].hits), 4u);
      state->focus_scopes[i].hits = refs;
      state->focus_scopes[i].hit_count = focusable_count;
      state->focus_scopes[i].hit_capacity = focusable_count;
      return ER_UI_OK;
    }
  }

  if (!er_ui_runtime_reserve(state->allocator, (void**)&state->focus_scopes, &state->focus_scope_capacity, state->focus_scope_count,
                             sizeof(*state->focus_scopes))) {
    er_ui_allocator_free(state->allocator, refs, focusable_count * sizeof(*refs), 4u);
    return ER_UI_ERR_OOM;
  }

  state->focus_scopes[state->focus_scope_count].open_id = open_id;
  state->focus_scopes[state->focus_scope_count].hits = refs;
  state->focus_scopes[state->focus_scope_count].hit_count = focusable_count;
  state->focus_scopes[state->focus_scope_count].hit_capacity = focusable_count;
  state->focus_scope_count++;
  return ER_UI_OK;
}

//@optimizer-ignore-function focus scope clear must free matching scope storage and compact the array
void er_ui_runtime_clear_focus_scope(er_ui_runtime_state_t* state, uint32_t open_id) {
  if (!state) return;
  for (size_t i = 0u; i < state->focus_scope_count; ++i) {
    if (state->focus_scopes[i].open_id != open_id) continue;
    er_ui_allocator_free(state->allocator, state->focus_scopes[i].hits, state->focus_scopes[i].hit_capacity * sizeof(*state->focus_scopes[i].hits), 4u);
    if (i + 1u < state->focus_scope_count) {
      er_ui_mem_move(state->focus_scopes + i, state->focus_scopes + i + 1u, (state->focus_scope_count - i - 1u) * sizeof(*state->focus_scopes));
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
