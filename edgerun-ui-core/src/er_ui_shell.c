#include "er_ui_shell.h"

static const size_t ER_UI_SHELL_INITIAL_SURFACE_CAP = 4u;
static const float ER_UI_SHELL_PAD = 8.0f;
static const float ER_UI_SHELL_LAUNCHER_WIDTH = 280.0f;
static const float ER_UI_SHELL_LAUNCHER_BUTTON = 32.0f;
static const float ER_UI_WORKSPACE_TAB_WIDTH = 132.0f;
static const float ER_UI_WORKSPACE_CLOSE_SIZE = 20.0f;

static bool er_ui_shell_allocator_valid(er_ui_allocator_t allocator) {
  return allocator.alloc != 0 && allocator.free != 0;
}

static void er_ui_shell_zero(void* ptr, size_t size) {
  unsigned char* bytes = (unsigned char*)ptr;
  for (size_t i = 0u; i < size; ++i) bytes[i] = 0u;
}

static void er_ui_shell_copy(void* dst, const void* src, size_t size) {
  unsigned char* out = (unsigned char*)dst;
  const unsigned char* in = (const unsigned char*)src;
  for (size_t i = 0u; i < size; ++i) out[i] = in[i];
}

static void er_ui_shell_free(er_ui_allocator_t allocator, void* ptr, size_t size, size_t align) {
  if (ptr && er_ui_shell_allocator_valid(allocator)) allocator.free(allocator.user, ptr, size, align);
}

static bool er_ui_shell_reserve_surfaces(er_ui_shell_state_t* state, size_t count) {
  if (!state || count < state->surface_capacity) return true;
  if (!er_ui_shell_allocator_valid(state->allocator)) return false;

  size_t next_capacity = state->surface_capacity == 0u ? ER_UI_SHELL_INITIAL_SURFACE_CAP : state->surface_capacity;
  while (next_capacity <= count) {
    if (next_capacity > ((size_t)-1) / 2u) return false;
    next_capacity *= 2u;
  }
  if (next_capacity > ((size_t)-1) / sizeof(*state->surfaces)) return false;

  size_t old_size = state->surface_capacity * sizeof(*state->surfaces);
  size_t next_size = next_capacity * sizeof(*state->surfaces);
  er_ui_workspace_surface_t* next = (er_ui_workspace_surface_t*)state->allocator.alloc(state->allocator.user, next_size, 4u);
  if (!next) return false;
  if (state->surfaces && old_size > 0u) er_ui_shell_copy(next, state->surfaces, old_size);
  er_ui_shell_free(state->allocator, state->surfaces, old_size, 4u);
  state->surfaces = next;
  state->surface_capacity = next_capacity;
  return true;
}

static size_t er_ui_workspace_find_surface(const er_ui_shell_state_t* state, uint32_t surface_id) {
  if (!state) return (size_t)-1;
  for (size_t i = 0u; i < state->surface_count; ++i) {
    if (state->surfaces[i].id == surface_id) return i;
  }
  return (size_t)-1;
}

er_ui_status_t er_ui_shell_state_init(er_ui_shell_state_t* state) {
  er_ui_allocator_t allocator = {0};
  return er_ui_shell_state_init_with_allocator(state, allocator);
}

er_ui_status_t er_ui_shell_state_init_with_allocator(er_ui_shell_state_t* state, er_ui_allocator_t allocator) {
  if (!state || !er_ui_shell_allocator_valid(allocator)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_shell_zero(state, sizeof(*state));
  state->allocator = allocator;
  return ER_UI_OK;
}

void er_ui_shell_state_destroy(er_ui_shell_state_t* state) {
  if (!state) return;
  er_ui_allocator_t allocator = state->allocator;
  er_ui_shell_free(allocator, state->surfaces, state->surface_capacity * sizeof(*state->surfaces), 4u);
  er_ui_shell_zero(state, sizeof(*state));
}

bool er_ui_shell_launcher_open(const er_ui_shell_state_t* state) {
  return state && state->launcher_open;
}

void er_ui_shell_set_launcher_open(er_ui_shell_state_t* state, bool open) {
  if (state) state->launcher_open = open;
}

void er_ui_shell_toggle_launcher(er_ui_shell_state_t* state) {
  if (state) state->launcher_open = !state->launcher_open;
}

static uint32_t er_ui_shell_action_target_id(er_ui_action_t action) {
  return action.has_hit ? action.hit.id : action.id;
}

er_ui_status_t er_ui_shell_apply_action(er_ui_shell_state_t* state, er_ui_action_t action, bool* out_changed) {
  if (out_changed) *out_changed = false;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;

  if (action.kind == ER_UI_ACTION_CANCELLED) {
    if (state->launcher_open) {
      state->launcher_open = false;
      if (out_changed) *out_changed = true;
    }
    return ER_UI_OK;
  }

  if (action.has_hit && action.hit.kind == ER_UI_HIT_SHELL_LAUNCHER && action.kind == ER_UI_ACTION_ACTIVATED) {
    state->launcher_open = !state->launcher_open;
    if (out_changed) *out_changed = true;
    return ER_UI_OK;
  }

  if ((action.kind == ER_UI_ACTION_TAB_SELECTED) ||
      (action.has_hit && action.hit.kind == ER_UI_HIT_WORKSPACE_TAB &&
       (action.kind == ER_UI_ACTION_ACTIVATED || action.kind == ER_UI_ACTION_FOCUSED))) {
    uint32_t surface_id = er_ui_shell_action_target_id(action);
    uint32_t previous = state->focused_surface_id;
    er_ui_status_t status = er_ui_workspace_focus_surface(state, surface_id);
    if (status != ER_UI_OK) return status;
    if (out_changed) *out_changed = previous != state->focused_surface_id;
    return ER_UI_OK;
  }

  if (action.has_hit && action.hit.kind == ER_UI_HIT_WORKSPACE_CLOSE && action.kind == ER_UI_ACTION_ACTIVATED) {
    er_ui_status_t status = er_ui_workspace_remove_surface(state, action.hit.id);
    if (status != ER_UI_OK) return status;
    if (out_changed) *out_changed = true;
    return ER_UI_OK;
  }

  return ER_UI_OK;
}

er_ui_status_t er_ui_workspace_add_surface(er_ui_shell_state_t* state, uint32_t surface_id) {
  if (!state || surface_id == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_workspace_find_surface(state, surface_id) != (size_t)-1) {
    state->focused_surface_id = surface_id;
    return ER_UI_OK;
  }
  if (!er_ui_shell_reserve_surfaces(state, state->surface_count)) return ER_UI_ERR_OOM;
  state->surfaces[state->surface_count].id = surface_id;
  state->surface_count++;
  state->focused_surface_id = surface_id;
  return ER_UI_OK;
}

er_ui_status_t er_ui_workspace_remove_surface(er_ui_shell_state_t* state, uint32_t surface_id) {
  if (!state || surface_id == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  size_t index = er_ui_workspace_find_surface(state, surface_id);
  if (index == (size_t)-1) return ER_UI_ERR_INVALID_ARGUMENT;
  for (size_t i = index + 1u; i < state->surface_count; ++i) {
    state->surfaces[i - 1u] = state->surfaces[i];
  }
  state->surface_count--;
  if (state->focused_surface_id == surface_id) {
    state->focused_surface_id = state->surface_count > 0u ? state->surfaces[state->surface_count - 1u].id : 0u;
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_workspace_focus_surface(er_ui_shell_state_t* state, uint32_t surface_id) {
  if (!state || surface_id == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_workspace_find_surface(state, surface_id) == (size_t)-1) return ER_UI_ERR_INVALID_ARGUMENT;
  state->focused_surface_id = surface_id;
  return ER_UI_OK;
}

size_t er_ui_workspace_surface_count(const er_ui_shell_state_t* state) {
  return state ? state->surface_count : 0u;
}

uint32_t er_ui_workspace_focused_surface_id(const er_ui_shell_state_t* state) {
  return state ? state->focused_surface_id : 0u;
}

bool er_ui_workspace_surface_bounds(const er_ui_shell_state_t* state, er_ui_bounds_t workspace_bounds, uint32_t surface_id, er_ui_bounds_t* out_bounds) {
  if (!state || !out_bounds || state->surface_count == 0u || !er_ui_bounds_valid(workspace_bounds)) return false;
  size_t index = er_ui_workspace_find_surface(state, surface_id);
  if (index == (size_t)-1) return false;
  float tile_w = workspace_bounds.w / (float)state->surface_count;
  *out_bounds = er_ui_bounds(workspace_bounds.x + tile_w * (float)index, workspace_bounds.y, tile_w, workspace_bounds.h);
  return er_ui_bounds_valid(*out_bounds);
}

static er_ui_status_t er_ui_shell_emit_topbar(er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, ER_UI_SHELL_TOPBAR_HEIGHT, 0.0f, theme.colors.topbar));
  if (status != ER_UI_OK) return status;
  er_ui_bounds_t launcher = er_ui_bounds(bounds.x + ER_UI_SHELL_PAD, bounds.y + 4.0f, ER_UI_SHELL_LAUNCHER_BUTTON, ER_UI_SHELL_LAUNCHER_BUTTON);
  status = er_ui_scene_push_rect(scene, er_ui_rect_fill(launcher.x, launcher.y, launcher.w, launcher.h, theme.radius.control, theme.colors.row));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SHELL_LAUNCHER, ER_UI_SHELL_LAUNCHER_ID, launcher.x, launcher.y, launcher.w, launcher.h));
}

static er_ui_status_t er_ui_shell_emit_launcher(const er_ui_shell_state_t* state, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  if (!state->launcher_open) return ER_UI_OK;
  float w = bounds.w < ER_UI_SHELL_LAUNCHER_WIDTH ? bounds.w : ER_UI_SHELL_LAUNCHER_WIDTH;
  er_ui_bounds_t panel = er_ui_bounds(bounds.x, bounds.y + ER_UI_SHELL_TOPBAR_HEIGHT, w, bounds.h - ER_UI_SHELL_TOPBAR_HEIGHT);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(panel.x, panel.y, panel.w, panel.h, theme.radius.panel, theme.colors.sidebar));
  if (status != ER_UI_OK) return status;
  return er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_SHELL_LAUNCHER, ER_UI_SHELL_LAUNCHER_ID, panel.x, panel.y, panel.w, panel.h));
}

static er_ui_status_t er_ui_shell_emit_workspace(const er_ui_shell_state_t* state, er_ui_scene_t* scene, er_ui_bounds_t bounds, er_ui_resolved_theme_t theme) {
  er_ui_bounds_t tabs = er_ui_bounds(bounds.x, bounds.y + ER_UI_SHELL_TOPBAR_HEIGHT, bounds.w, ER_UI_WORKSPACE_TAB_HEIGHT);
  er_ui_bounds_t workspace = er_ui_bounds(bounds.x, tabs.y + tabs.h, bounds.w, bounds.h - ER_UI_SHELL_TOPBAR_HEIGHT - ER_UI_WORKSPACE_TAB_HEIGHT);
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tabs.x, tabs.y, tabs.w, tabs.h, 0.0f, theme.colors.panel));
  if (status != ER_UI_OK) return status;
  for (size_t i = 0u; i < state->surface_count; ++i) {
    uint32_t id = state->surfaces[i].id;
    float tab_x = tabs.x + (float)i * ER_UI_WORKSPACE_TAB_WIDTH;
    er_ui_bounds_t tab = er_ui_bounds(tab_x, tabs.y + 4.0f, ER_UI_WORKSPACE_TAB_WIDTH - 4.0f, tabs.h - 8.0f);
    er_ui_color4_t tab_color = id == state->focused_surface_id ? theme.colors.active : theme.colors.row;
    status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tab.x, tab.y, tab.w, tab.h, theme.radius.control, tab_color));
    if (status != ER_UI_OK) return status;
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_WORKSPACE_TAB, id, tab.x, tab.y, tab.w, tab.h));
    if (status != ER_UI_OK) return status;
    er_ui_bounds_t close = er_ui_bounds(tab.x + tab.w - ER_UI_WORKSPACE_CLOSE_SIZE - 4.0f, tab.y + 4.0f, ER_UI_WORKSPACE_CLOSE_SIZE, ER_UI_WORKSPACE_CLOSE_SIZE);
    status = er_ui_scene_push_hit(scene, er_ui_hit(ER_UI_HIT_WORKSPACE_CLOSE, id, close.x, close.y, close.w, close.h));
    if (status != ER_UI_OK) return status;

    er_ui_bounds_t tile = {0};
    if (er_ui_workspace_surface_bounds(state, workspace, id, &tile)) {
      er_ui_bounds_t inset = er_ui_bounds_inset(tile, ER_UI_SHELL_PAD, ER_UI_SHELL_PAD);
      er_ui_color4_t fill = id == state->focused_surface_id ? theme.colors.panel : theme.colors.row;
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(inset.x, inset.y, inset.w, inset.h, theme.radius.panel, fill));
      if (status != ER_UI_OK) return status;
      status = er_ui_scene_push_drop_target(scene, er_ui_drop_target(id, i, inset.x, inset.y, inset.w, inset.h));
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

er_ui_status_t er_ui_shell_emit_scene(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  if (!state || !scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;
  status = er_ui_shell_emit_topbar(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shell_emit_workspace(state, scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  return er_ui_shell_emit_launcher(state, scene, bounds, theme);
}
