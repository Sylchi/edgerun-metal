#include "test_common.h"

void run_shell_tests(void) {
  er_ui_shell_state_t shell = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_scene_t scene = {0};
  er_ui_bounds_t surface_bounds = {0};
  er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
  bool changed = false;

  expect_status(er_ui_shell_state_init_with_allocator(&shell, er_ui_test_allocator()), ER_UI_OK, "shell: state init succeeds");
  expect_status(er_ui_runtime_state_init_with_allocator(&runtime, er_ui_test_allocator()), ER_UI_OK, "shell runtime: state init succeeds");
  expect_true(!er_ui_shell_launcher_open(&shell), "shell: launcher starts closed");
  er_ui_shell_toggle_launcher(&shell);
  expect_true(er_ui_shell_launcher_open(&shell), "shell: launcher toggles open");

  expect_status(er_ui_workspace_add_surface(&shell, 10u), ER_UI_OK, "workspace: first surface opens");
  expect_status(er_ui_workspace_add_surface(&shell, 20u), ER_UI_OK, "workspace: second surface opens");
  expect_size(er_ui_workspace_surface_count(&shell), 2u, "workspace: surface count tracks opened surfaces");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), 20u, "workspace: newest surface is focused");
  expect_status(er_ui_workspace_focus_surface(&shell, 10u), ER_UI_OK, "workspace: focus existing surface succeeds");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), 10u, "workspace: focus switches to requested surface");

  er_ui_bounds_t workspace = er_ui_bounds(0.0f, 76.0f, 400.0f, 224.0f);
  expect_true(er_ui_workspace_surface_bounds(&shell, workspace, 20u, &surface_bounds), "workspace: surface bounds resolve");
  expect_float(surface_bounds.x, 200.0f, "workspace: second tile x splits width");
  expect_float(surface_bounds.w, 200.0f, "workspace: tile width splits evenly");

  expect_status(er_ui_scene_init_with_allocator(&scene, theme.colors.bg, er_ui_test_allocator()), ER_UI_OK, "shell scene: init succeeds");
  expect_status(er_ui_shell_emit_scene(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 400.0f, 300.0f), theme), ER_UI_OK,
                "shell scene: emit succeeds");
  expect_true(scene.rect_count >= 6u, "shell scene: chrome and surfaces emit rects");
  expect_true(scene.hit_count >= 5u, "shell scene: launcher tabs and closes emit hits");
  expect_size(scene.drop_target_count, 2u, "shell scene: surface tiles emit drop targets");

  er_ui_hit_t hit = {0};
  expect_true(er_ui_scene_hit_test(&scene, 12.0f, 12.0f, &hit), "shell scene: launcher hit is queryable");
  expect_true(hit.kind == ER_UI_HIT_SHELL_LAUNCHER, "shell scene: launcher hit kind is shell launcher");
  expect_u32(hit.id, ER_UI_SHELL_LAUNCHER_ID, "shell scene: launcher hit id is stable");

  er_ui_action_t action = er_ui_runtime_pointer_down(&runtime, &scene, 12.0f, 12.0f);
  expect_true(action.kind == ER_UI_ACTION_FOCUSED, "shell action: pointer down focuses launcher");
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: focused launcher applies");
  expect_true(!changed, "shell action: focused launcher does not toggle");
  expect_true(er_ui_shell_launcher_open(&shell), "shell action: launcher remains open after focus");
  action = er_ui_runtime_pointer_up(&runtime, &scene, 12.0f, 12.0f);
  expect_true(action.kind == ER_UI_ACTION_ACTIVATED, "shell action: pointer up activates launcher");
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: activated launcher applies");
  expect_true(changed, "shell action: activated launcher reports changed");
  expect_true(!er_ui_shell_launcher_open(&shell), "shell action: activated launcher toggles closed");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_CANCELLED;
  er_ui_shell_set_launcher_open(&shell, true);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: cancel applies");
  expect_true(changed, "shell action: cancel closes launcher");
  expect_true(!er_ui_shell_launcher_open(&shell), "shell action: cancel leaves launcher closed");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_TAB_SELECTED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_WORKSPACE_TAB, 20u, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: tab selected applies");
  expect_true(changed, "shell action: tab selected reports focus change");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), 20u, "shell action: tab selected focuses surface");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_WORKSPACE_CLOSE, 20u, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: close applies");
  expect_true(changed, "shell action: close reports changed");
  expect_size(er_ui_workspace_surface_count(&shell), 1u, "shell action: close removes one surface");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), 10u, "shell action: close falls focus back");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_HOVERED;
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: ignored action applies");
  expect_true(!changed, "shell action: ignored action reports unchanged");

  expect_status(er_ui_workspace_remove_surface(&shell, 10u), ER_UI_OK, "workspace: remove final surface succeeds");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), 0u, "workspace: focus clears when empty");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_shell_state_destroy(&shell);
}
