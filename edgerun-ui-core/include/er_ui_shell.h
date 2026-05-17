#ifndef ER_UI_SHELL_H
#define ER_UI_SHELL_H

#include "er_ui_primitives.h"
#include "er_ui_runtime.h"
#include "er_ui_scene.h"
#include "er_ui_theme.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_SHELL_LAUNCHER_ID 1u
#define ER_UI_SHELL_TOPBAR_HEIGHT 40.0f
#define ER_UI_WORKSPACE_TAB_HEIGHT 36.0f

typedef struct {
  uint32_t id;
} er_ui_workspace_surface_t;

typedef struct {
  er_ui_allocator_t allocator;
  bool launcher_open;
  uint32_t focused_surface_id;
  er_ui_workspace_surface_t* surfaces;
  size_t surface_count;
  size_t surface_capacity;
} er_ui_shell_state_t;

er_ui_status_t er_ui_shell_state_init(er_ui_shell_state_t* state);
er_ui_status_t er_ui_shell_state_init_with_allocator(er_ui_shell_state_t* state, er_ui_allocator_t allocator);
void er_ui_shell_state_destroy(er_ui_shell_state_t* state);

bool er_ui_shell_launcher_open(const er_ui_shell_state_t* state);
void er_ui_shell_set_launcher_open(er_ui_shell_state_t* state, bool open);
void er_ui_shell_toggle_launcher(er_ui_shell_state_t* state);
er_ui_status_t er_ui_shell_apply_action(er_ui_shell_state_t* state, er_ui_action_t action, bool* out_changed);

er_ui_status_t er_ui_workspace_add_surface(er_ui_shell_state_t* state, uint32_t surface_id);
er_ui_status_t er_ui_workspace_remove_surface(er_ui_shell_state_t* state, uint32_t surface_id);
er_ui_status_t er_ui_workspace_focus_surface(er_ui_shell_state_t* state, uint32_t surface_id);
size_t er_ui_workspace_surface_count(const er_ui_shell_state_t* state);
uint32_t er_ui_workspace_focused_surface_id(const er_ui_shell_state_t* state);
bool er_ui_workspace_surface_bounds(const er_ui_shell_state_t* state, er_ui_bounds_t workspace_bounds, uint32_t surface_id, er_ui_bounds_t* out_bounds);

er_ui_status_t er_ui_shell_emit_scene(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);

#ifdef __cplusplus
}
#endif

#endif
