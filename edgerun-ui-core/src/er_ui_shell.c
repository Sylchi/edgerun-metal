#include "er_ui_shell.h"
#include "er_ui_components.h"
#include "er_ui_internal.h"

static const size_t ER_UI_SHELL_INITIAL_SURFACE_CAP = 4u;
static const float ER_UI_SHELL_PAD = 8.0f;
static const float ER_UI_SHELL_LAUNCHER_WIDTH = 280.0f;
static const float ER_UI_SHELL_LAUNCHER_BUTTON = 32.0f;
static const float ER_UI_WORKSPACE_TAB_WIDTH = 132.0f;
static const float ER_UI_WORKSPACE_CLOSE_SIZE = 20.0f;
static const float ER_UI_NETWORK_APP_PROMPT_WIDTH = 560.0f;
static const float ER_UI_NETWORK_APP_PROMPT_HEIGHT = 328.0f;
static const size_t ER_UI_SHELL_TEXT_MAX_CODEPOINTS = 192u;

static bool er_ui_shell_reserve_surfaces(er_ui_shell_state_t* state, size_t count) {
  if (!state || count < state->surface_capacity) return true;
  return er_ui_allocator_reserve(state->allocator, (void**)&state->surfaces, &state->surface_capacity, count, sizeof(*state->surfaces),
                                 ER_UI_SHELL_INITIAL_SURFACE_CAP, 4u);
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
  if (!state || !er_ui_allocator_is_valid(allocator)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_mem_zero(state, sizeof(*state));
  state->allocator = allocator;
  return ER_UI_OK;
}

void er_ui_shell_state_destroy(er_ui_shell_state_t* state) {
  if (!state) return;
  er_ui_allocator_t allocator = state->allocator;
  er_ui_allocator_free(allocator, state->surfaces, state->surface_capacity * sizeof(*state->surfaces), 4u);
  er_ui_mem_zero(state, sizeof(*state));
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

static bool er_ui_shell_prompt_choice_for_id(uint32_t id, er_ui_network_app_prompt_choice_t* out_choice) {
  er_ui_network_app_prompt_choice_t choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE;
  if (id == ER_UI_NETWORK_APP_PROMPT_RUN_ONCE_ID) {
    choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_RUN_ONCE;
  } else if (id == ER_UI_NETWORK_APP_PROMPT_VERIFY_CACHE_ID) {
    choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_VERIFY_CACHE;
  } else if (id == ER_UI_NETWORK_APP_PROMPT_CANCEL_ID) {
    choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_CANCEL;
  } else {
    return false;
  }
  if (out_choice) *out_choice = choice;
  return true;
}

er_ui_status_t er_ui_shell_apply_action(er_ui_shell_state_t* state, er_ui_action_t action, bool* out_changed) {
  if (out_changed) *out_changed = false;
  if (!state) return ER_UI_ERR_INVALID_ARGUMENT;

  if (action.kind == ER_UI_ACTION_CANCELLED) {
    if (state->network_app_prompt_open) {
      state->network_app_prompt_open = false;
      state->network_app_prompt_choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_CANCEL;
      if (out_changed) *out_changed = true;
      return ER_UI_OK;
    }
    if (state->launcher_open) {
      state->launcher_open = false;
      if (out_changed) *out_changed = true;
    }
    return ER_UI_OK;
  }

  if (state->network_app_prompt_open && action.kind == ER_UI_ACTION_ACTIVATED) {
    er_ui_network_app_prompt_choice_t choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE;
    uint32_t id = er_ui_shell_action_target_id(action);
    if (er_ui_shell_prompt_choice_for_id(id, &choice)) {
      state->network_app_prompt_open = false;
      state->network_app_prompt_choice = choice;
      if (out_changed) *out_changed = true;
      return ER_UI_OK;
    }
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

bool er_ui_shell_network_app_prompt_open(const er_ui_shell_state_t* state) {
  return state && state->network_app_prompt_open;
}

void er_ui_shell_show_network_app_prompt(er_ui_shell_state_t* state) {
  if (!state) return;
  state->network_app_prompt_open = true;
  state->network_app_prompt_choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE;
}

void er_ui_shell_clear_network_app_prompt_choice(er_ui_shell_state_t* state) {
  if (state) state->network_app_prompt_choice = ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE;
}

er_ui_network_app_prompt_choice_t er_ui_shell_network_app_prompt_choice(const er_ui_shell_state_t* state) {
  return state ? state->network_app_prompt_choice : ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE;
}

er_ui_status_t er_ui_workspace_add_surface(er_ui_shell_state_t* state, uint32_t surface_id) {
  return er_ui_workspace_add_named_surface(state, surface_id, NULL);
}

er_ui_status_t er_ui_workspace_add_named_surface(er_ui_shell_state_t* state, uint32_t surface_id, const char* title) {
  if (!state || surface_id == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  if (er_ui_workspace_find_surface(state, surface_id) != (size_t)-1) {
    state->focused_surface_id = surface_id;
    return ER_UI_OK;
  }
  if (!er_ui_shell_reserve_surfaces(state, state->surface_count)) return ER_UI_ERR_OOM;
  state->surfaces[state->surface_count].id = surface_id;
  state->surfaces[state->surface_count].title = title;
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

bool er_ui_workspace_focused_surface_bounds(const er_ui_shell_state_t* state, er_ui_bounds_t shell_bounds, er_ui_bounds_t* out_bounds) {
  if (!state || !out_bounds || state->focused_surface_id == 0u || !er_ui_bounds_valid(shell_bounds)) return false;
  er_ui_bounds_t tabs = er_ui_bounds(shell_bounds.x, shell_bounds.y + ER_UI_SHELL_TOPBAR_HEIGHT, shell_bounds.w, ER_UI_WORKSPACE_TAB_HEIGHT);
  er_ui_bounds_t workspace = er_ui_bounds(shell_bounds.x, tabs.y + tabs.h, shell_bounds.w,
                                          shell_bounds.h - ER_UI_SHELL_TOPBAR_HEIGHT - ER_UI_WORKSPACE_TAB_HEIGHT);
  if (!er_ui_bounds_valid(workspace)) return false;
  er_ui_bounds_t inner = er_ui_bounds_inset(workspace, ER_UI_SHELL_PAD, ER_UI_SHELL_PAD);
  if (!er_ui_bounds_valid(inner)) return false;
  return er_ui_workspace_surface_bounds(state, inner, state->focused_surface_id, out_bounds);
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

static er_ui_status_t er_ui_shell_emit_workspace(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font,
  er_ui_shell_surface_emit_fn emit_surface,
  void* user) {
  er_ui_bounds_t tabs = er_ui_bounds(bounds.x, bounds.y + ER_UI_SHELL_TOPBAR_HEIGHT, bounds.w, ER_UI_WORKSPACE_TAB_HEIGHT);
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
  }

  er_ui_bounds_t workspace = er_ui_bounds(bounds.x, tabs.y + tabs.h, bounds.w,
                                          bounds.h - ER_UI_SHELL_TOPBAR_HEIGHT - ER_UI_WORKSPACE_TAB_HEIGHT);
  er_ui_bounds_t inner = er_ui_bounds_inset(workspace, ER_UI_SHELL_PAD, ER_UI_SHELL_PAD);
  if (er_ui_bounds_valid(inner)) {
    for (size_t i = 0u; i < state->surface_count; ++i) {
      er_ui_bounds_t tile = {0};
      if (!er_ui_workspace_surface_bounds(state, inner, state->surfaces[i].id, &tile)) continue;
      er_ui_color4_t fill = state->surfaces[i].id == state->focused_surface_id ? theme.colors.panel : er_ui_color_with_alpha(theme.colors.panel, 0.58f);
      status = er_ui_scene_push_rect(scene, er_ui_rect_fill(tile.x, tile.y, tile.w, tile.h, theme.radius.panel, fill));
      if (status != ER_UI_OK) return status;
      status = er_ui_scene_push_drop_target(scene, er_ui_drop_target(state->surfaces[i].id, i, tile.x, tile.y, tile.w, tile.h));
      if (status != ER_UI_OK) return status;
    }
  }

  er_ui_bounds_t focused = {0};
  if (er_ui_workspace_focused_surface_bounds(state, bounds, &focused)) {
    status = er_ui_scene_push_rect(scene, er_ui_rect_border(focused.x, focused.y, focused.w, focused.h, theme.radius.panel, er_ui_color_with_alpha(theme.colors.accent, 0.42f)));
    if (status != ER_UI_OK) return status;
    if (emit_surface) {
      status = emit_surface(state->focused_surface_id, scene, font, focused, theme, user);
      if (status != ER_UI_OK) return status;
    }
  }
  return ER_UI_OK;
}

static er_ui_status_t er_ui_shell_push_ascii_text(er_ui_scene_t* scene, vr_font_face_t* font, const char* text, float x, float y, er_ui_color4_t color) {
  return er_ui_scene_push_ascii_text(scene, font, text, ER_UI_SHELL_TEXT_MAX_CODEPOINTS, x, y, color);
}

static size_t er_ui_shell_u32_to_ascii(uint32_t value, char* out, size_t out_capacity) {
  if (!out || out_capacity == 0u) return 0u;
  char reversed[10u];
  size_t count = 0u;
  do {
    reversed[count++] = (char)('0' + (value % 10u));
    value /= 10u;
  } while (value != 0u && count < sizeof(reversed));
  if (count + 1u > out_capacity) return 0u;
  for (size_t i = 0u; i < count; ++i) out[i] = reversed[count - 1u - i];
  out[count] = '\0';
  return count;
}

static er_ui_status_t er_ui_shell_push_surface_label(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  uint32_t surface_id,
  float x,
  float y,
  er_ui_color4_t color) {
  if (state) {
    size_t index = er_ui_workspace_find_surface(state, surface_id);
    if (index != (size_t)-1 && state->surfaces[index].title) {
      return er_ui_shell_push_ascii_text(scene, font, state->surfaces[index].title, x, y, color);
    }
  }
  char label[24u] = {'S', 'u', 'r', 'f', 'a', 'c', 'e', ' ', '\0'};
  size_t prefix_len = 8u;
  size_t digits = er_ui_shell_u32_to_ascii(surface_id, label + prefix_len, sizeof(label) - prefix_len);
  if (digits == 0u) return ER_UI_ERR_INVALID_ARGUMENT;
  return er_ui_shell_push_ascii_text(scene, font, label, x, y, color);
}

static er_ui_status_t er_ui_shell_emit_text_labels(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font) {
  if (!font) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_shell_push_ascii_text(scene, font, "EdgeRun", bounds.x + 52.0f, bounds.y + 27.0f, theme.colors.text);
  if (status != ER_UI_OK) return status;

  float tabs_y = bounds.y + ER_UI_SHELL_TOPBAR_HEIGHT;
  for (size_t i = 0u; i < state->surface_count; ++i) {
    uint32_t id = state->surfaces[i].id;
    float tab_x = bounds.x + (float)i * ER_UI_WORKSPACE_TAB_WIDTH;
    er_ui_color4_t text = id == state->focused_surface_id ? theme.colors.accent_text : theme.colors.text;
    status = er_ui_shell_push_surface_label(state, scene, font, id, tab_x + 12.0f, tabs_y + 27.0f, text);
    if (status != ER_UI_OK) return status;
  }

  return ER_UI_OK;
}

static er_ui_status_t er_ui_shell_emit_network_app_prompt(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font) {
  if (!state->network_app_prompt_open) return ER_UI_OK;
  if (!font) return ER_UI_ERR_INVALID_ARGUMENT;

  er_ui_color4_t overlay = {0.0f, 0.0f, 0.0f, 0.54f};
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, overlay));
  if (status != ER_UI_OK) return status;

  float panel_w = bounds.w - 32.0f;
  if (panel_w > ER_UI_NETWORK_APP_PROMPT_WIDTH) panel_w = ER_UI_NETWORK_APP_PROMPT_WIDTH;
  if (panel_w <= 0.0f || bounds.h <= ER_UI_NETWORK_APP_PROMPT_HEIGHT) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_bounds_t panel = er_ui_bounds(bounds.x + (bounds.w - panel_w) * 0.5f, bounds.y + (bounds.h - ER_UI_NETWORK_APP_PROMPT_HEIGHT) * 0.5f,
                                      panel_w, ER_UI_NETWORK_APP_PROMPT_HEIGHT);
  return er_ui_network_app_prompt_emit(
    scene,
    font,
    panel,
    theme,
    "Network app",
    "Signed package",
    "Policy priced",
    "blake3 policy verified before launch",
    ER_UI_NETWORK_APP_PROMPT_RUN_ONCE_ID,
    ER_UI_NETWORK_APP_PROMPT_VERIFY_CACHE_ID,
    ER_UI_NETWORK_APP_PROMPT_CANCEL_ID);
}

static er_ui_status_t er_ui_shell_emit_scene_base(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font,
  er_ui_shell_surface_emit_fn emit_surface,
  void* user) {
  if (!state || !scene || !er_ui_bounds_valid(bounds)) return ER_UI_ERR_INVALID_ARGUMENT;
  er_ui_status_t status = er_ui_scene_push_rect(scene, er_ui_rect_fill(bounds.x, bounds.y, bounds.w, bounds.h, 0.0f, theme.colors.bg));
  if (status != ER_UI_OK) return status;
  status = er_ui_shell_emit_topbar(scene, bounds, theme);
  if (status != ER_UI_OK) return status;
  status = er_ui_shell_emit_workspace(state, scene, bounds, theme, font, emit_surface, user);
  if (status != ER_UI_OK) return status;
  return er_ui_shell_emit_launcher(state, scene, bounds, theme);
}

er_ui_status_t er_ui_shell_emit_scene(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme) {
  return er_ui_shell_emit_scene_base(state, scene, bounds, theme, NULL, NULL, NULL);
}

er_ui_status_t er_ui_shell_emit_scene_with_font(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font) {
  return er_ui_shell_emit_scene_with_font_and_surfaces(state, scene, bounds, theme, font, NULL, NULL);
}

er_ui_status_t er_ui_shell_emit_scene_with_font_and_surfaces(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font,
  er_ui_shell_surface_emit_fn emit_surface,
  void* user) {
  er_ui_status_t status = er_ui_shell_emit_scene_base(state, scene, bounds, theme, font, emit_surface, user);
  if (status != ER_UI_OK) return status;
  status = er_ui_shell_emit_text_labels(state, scene, bounds, theme, font);
  if (status != ER_UI_OK) return status;
  return er_ui_shell_emit_network_app_prompt(state, scene, bounds, theme, font);
}
