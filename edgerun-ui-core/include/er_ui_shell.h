#ifndef ER_UI_SHELL_H
#define ER_UI_SHELL_H

#include "er_ui_primitives.h"
#include "er_ui_runtime.h"
#include "er_ui_scene.h"
#include "er_ui_theme.h"
#include "er_ui_text.h"

#ifdef __cplusplus
extern "C" {
#endif

#define ER_UI_SHELL_LAUNCHER_ID 1u
#define ER_UI_SHELL_TOPBAR_HEIGHT 40.0f
#define ER_UI_WORKSPACE_TAB_HEIGHT 36.0f
#define ER_UI_NETWORK_APP_PROMPT_RUN_ONCE_ID 0xED010001u
#define ER_UI_NETWORK_APP_PROMPT_VERIFY_CACHE_ID 0xED010002u
#define ER_UI_NETWORK_APP_PROMPT_CANCEL_ID 0xED010003u

typedef enum {
  ER_UI_LAUNCHER_APP_INSTALLED = 0,
  ER_UI_LAUNCHER_APP_UPDATE_AVAILABLE,
  ER_UI_LAUNCHER_APP_REMOVED,
  ER_UI_LAUNCHER_APP_ROLLED_BACK
} er_ui_launcher_app_status_t;

typedef enum {
  ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE = 0,
  ER_UI_NETWORK_APP_PROMPT_CHOICE_RUN_ONCE,
  ER_UI_NETWORK_APP_PROMPT_CHOICE_VERIFY_CACHE,
  ER_UI_NETWORK_APP_PROMPT_CHOICE_CANCEL
} er_ui_network_app_prompt_choice_t;

typedef struct {
  uint32_t id;
  const char* title;
} er_ui_workspace_surface_t;

typedef struct {
  uint32_t launch_id;
  uint32_t surface_id;
  const char* name;
  er_ui_launcher_app_status_t status;
  const char* package_hash;
  const char* provenance;
  const char* permissions;
} er_ui_launcher_app_t;

typedef struct {
  er_ui_allocator_t allocator;
  bool launcher_open;
  bool network_app_prompt_open;
  er_ui_network_app_prompt_choice_t network_app_prompt_choice;
  uint32_t focused_surface_id;
  er_ui_workspace_surface_t* surfaces;
  size_t surface_count;
  size_t surface_capacity;
  er_ui_launcher_app_t* launcher_apps;
  size_t launcher_app_count;
  size_t launcher_app_capacity;
} er_ui_shell_state_t;

er_ui_status_t er_ui_shell_state_init(er_ui_shell_state_t* state);
er_ui_status_t er_ui_shell_state_init_with_allocator(er_ui_shell_state_t* state, er_ui_allocator_t allocator);
void er_ui_shell_state_destroy(er_ui_shell_state_t* state);

bool er_ui_shell_launcher_open(const er_ui_shell_state_t* state);
void er_ui_shell_set_launcher_open(er_ui_shell_state_t* state, bool open);
void er_ui_shell_toggle_launcher(er_ui_shell_state_t* state);
er_ui_status_t er_ui_shell_apply_action(er_ui_shell_state_t* state, er_ui_action_t action, bool* out_changed);
bool er_ui_shell_network_app_prompt_open(const er_ui_shell_state_t* state);
/*
 * UI core owns the prompt component, not app inventory. Hosts call this after
 * their app/package model selects a network app.
 */
void er_ui_shell_show_network_app_prompt(er_ui_shell_state_t* state);
void er_ui_shell_clear_network_app_prompt_choice(er_ui_shell_state_t* state);
er_ui_network_app_prompt_choice_t er_ui_shell_network_app_prompt_choice(const er_ui_shell_state_t* state);

er_ui_status_t er_ui_shell_add_launcher_app(er_ui_shell_state_t* state, er_ui_launcher_app_t app);
size_t er_ui_shell_launcher_app_count(const er_ui_shell_state_t* state);

er_ui_status_t er_ui_workspace_add_surface(er_ui_shell_state_t* state, uint32_t surface_id);
er_ui_status_t er_ui_workspace_add_named_surface(er_ui_shell_state_t* state, uint32_t surface_id, const char* title);
er_ui_status_t er_ui_workspace_remove_surface(er_ui_shell_state_t* state, uint32_t surface_id);
er_ui_status_t er_ui_workspace_focus_surface(er_ui_shell_state_t* state, uint32_t surface_id);
size_t er_ui_workspace_surface_count(const er_ui_shell_state_t* state);
uint32_t er_ui_workspace_focused_surface_id(const er_ui_shell_state_t* state);
bool er_ui_workspace_surface_bounds(
  const er_ui_shell_state_t* state,
  er_ui_bounds_t workspace_bounds,
  uint32_t surface_id,
  er_ui_bounds_t* out_bounds);
bool er_ui_workspace_focused_surface_bounds(
  const er_ui_shell_state_t* state,
  er_ui_bounds_t shell_bounds,
  er_ui_bounds_t* out_bounds);

typedef er_ui_status_t (*er_ui_shell_surface_emit_fn)(
  uint32_t surface_id,
  er_ui_scene_t* scene,
  vr_font_face_t* font,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  void* user);

er_ui_status_t er_ui_shell_emit_scene(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme);
er_ui_status_t er_ui_shell_emit_scene_with_font(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font);
er_ui_status_t er_ui_shell_emit_scene_with_font_and_surfaces(
  const er_ui_shell_state_t* state,
  er_ui_scene_t* scene,
  er_ui_bounds_t bounds,
  er_ui_resolved_theme_t theme,
  vr_font_face_t* font,
  er_ui_shell_surface_emit_fn emit_surface,
  void* user);

#ifdef __cplusplus
}
#endif

#endif
