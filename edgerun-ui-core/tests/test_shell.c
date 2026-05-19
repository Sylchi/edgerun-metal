#include "test_common.h"

static const uint32_t ER_TEST_SHELL_FIRST_SURFACE_ID = 10u;
static const uint32_t ER_TEST_SHELL_SECOND_SURFACE_ID = 20u;
static const uint32_t ER_TEST_SHELL_UPDATE_SURFACE_ID = 30u;
static const uint32_t ER_TEST_SHELL_REMOVED_SURFACE_ID = 40u;
static const uint32_t ER_TEST_SHELL_THIRD_SURFACE_ID = 50u;
static const uint32_t ER_TEST_SHELL_LAUNCHER_APP_ID = 100u;
static const uint32_t ER_TEST_SHELL_LAUNCHER_UPDATE_ID = 101u;
static const uint32_t ER_TEST_SHELL_LAUNCHER_REMOVED_ID = 102u;
static const size_t ER_TEST_SHELL_SURFACE_COUNT = 2u;
static const size_t ER_TEST_SHELL_LAUNCHER_APP_COUNT = 3u;
static const size_t ER_TEST_SHELL_MIN_CHROME_RECTS = 6u;
static const size_t ER_TEST_SHELL_MIN_CHROME_HITS = 6u;
static const size_t ER_TEST_SHELL_MIN_ICON_QUADS = 5u;
static const size_t ER_TEST_SHELL_MIN_FONT_ICON_QUADS = 3u;
static const float ER_TEST_SHELL_PANEL_PAD = 8.0f;

static bool shell_scene_has_hit_id(const er_ui_scene_t* scene, uint32_t id) {
  if (!scene) return false;
  for (size_t i = 0u; i < scene->hit_count; ++i) {
    if (scene->hits[i].id == id) return true;
  }
  return false;
}

static const er_ui_drop_target_t* shell_scene_drop_target(const er_ui_scene_t* scene, uint32_t scope_id) {
  if (!scene) return NULL;
  for (size_t i = 0u; i < scene->drop_target_count; ++i) {
    if (scene->drop_targets[i].scope_id == scope_id) return &scene->drop_targets[i];
  }
  return NULL;
}

void run_shell_tests(void) {
  er_ui_shell_state_t shell = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_scene_t scene = {0};
  er_ui_bounds_t surface_bounds = {0};
  er_ui_bounds_t focused_bounds = {0};
  er_ui_resolved_theme_t theme = er_ui_resolved_theme_user_default();
  bool changed = false;

  expect_status(er_ui_shell_state_init_with_allocator(&shell, er_ui_test_allocator()), ER_UI_OK, "shell: state init succeeds");
  expect_status(er_ui_runtime_state_init_with_allocator(&runtime, er_ui_test_allocator()), ER_UI_OK, "shell runtime: state init succeeds");
  expect_true(!er_ui_shell_launcher_open(&shell), "shell: launcher starts closed");
  er_ui_shell_toggle_launcher(&shell);
  expect_true(er_ui_shell_launcher_open(&shell), "shell: launcher toggles open");

  expect_status(er_ui_workspace_add_surface(&shell, ER_TEST_SHELL_FIRST_SURFACE_ID), ER_UI_OK, "workspace: first surface opens");
  expect_status(er_ui_workspace_add_surface(&shell, ER_TEST_SHELL_SECOND_SURFACE_ID), ER_UI_OK, "workspace: second surface opens");
  expect_status(er_ui_shell_add_launcher_app(&shell,
                                             (er_ui_launcher_app_t){
                                                 ER_TEST_SHELL_LAUNCHER_APP_ID,
                                                 ER_TEST_SHELL_FIRST_SURFACE_ID,
                                                 "Ledger",
                                                 ER_UI_LAUNCHER_APP_INSTALLED,
                                                 "pkg:0123456789abcdef",
                                                 "signed:authority-root",
                                                 "ui,storage"}),
                ER_UI_OK,
                "launcher: installed package record is accepted");
  expect_status(er_ui_shell_add_launcher_app(&shell,
                                             (er_ui_launcher_app_t){
                                                 ER_TEST_SHELL_LAUNCHER_UPDATE_ID,
                                                 ER_TEST_SHELL_UPDATE_SURFACE_ID,
                                                 "Charts",
                                                 ER_UI_LAUNCHER_APP_UPDATE_AVAILABLE,
                                                 "pkg:1123456789abcdef",
                                                 "signed:store-cache",
                                                 "ui,network"}),
                ER_UI_OK,
                "launcher: update-available package record is accepted");
  expect_status(er_ui_shell_add_launcher_app(&shell,
                                             (er_ui_launcher_app_t){
                                                 ER_TEST_SHELL_LAUNCHER_REMOVED_ID,
                                                 ER_TEST_SHELL_REMOVED_SURFACE_ID,
                                                 "Archive",
                                                 ER_UI_LAUNCHER_APP_REMOVED,
                                                 "pkg:2123456789abcdef",
                                                 "removed:local-index",
                                                 "none"}),
                ER_UI_OK,
                "launcher: removed package record is accepted");
  expect_size(er_ui_shell_launcher_app_count(&shell), ER_TEST_SHELL_LAUNCHER_APP_COUNT, "launcher: app inventory count tracks records");
  expect_size(er_ui_workspace_surface_count(&shell), ER_TEST_SHELL_SURFACE_COUNT, "workspace: surface count tracks opened surfaces");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_SECOND_SURFACE_ID, "workspace: newest surface is focused");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace: previous surface tracks displaced focus");
  expect_status(er_ui_workspace_focus_surface(&shell, ER_TEST_SHELL_FIRST_SURFACE_ID), ER_UI_OK, "workspace: focus existing surface succeeds");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace: focus switches to requested surface");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), ER_TEST_SHELL_SECOND_SURFACE_ID, "workspace: previous surface tracks explicit focus");

  er_ui_bounds_t workspace = er_ui_bounds(0.0f, 76.0f, 400.0f, 224.0f);
  expect_true(er_ui_workspace_surface_bounds(&shell, workspace, ER_TEST_SHELL_SECOND_SURFACE_ID, &surface_bounds), "workspace: surface bounds resolve");
  expect_float(surface_bounds.x, 200.0f, "workspace: second tile x splits width");
  expect_float(surface_bounds.w, 200.0f, "workspace: tile width splits evenly");
  expect_true(er_ui_workspace_focused_surface_bounds(&shell, er_ui_bounds(0.0f, 0.0f, 400.0f, 300.0f), &focused_bounds),
              "workspace: focused surface bounds resolve");
  expect_float(focused_bounds.x, 0.0f, "workspace: focused tile x matches focused surface");
  expect_float(focused_bounds.y, workspace.y, "workspace: focused tile y matches workspace");
  expect_float(focused_bounds.w, surface_bounds.w, "workspace: focused tile width matches surface tile width");
  expect_float(focused_bounds.h, workspace.h, "workspace: focused tile height matches workspace");

  expect_status(er_ui_scene_init_with_allocator(&scene, theme.colors.bg, er_ui_test_allocator()), ER_UI_OK, "shell scene: init succeeds");
  expect_status(er_ui_shell_emit_scene(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 400.0f, 300.0f), theme), ER_UI_OK,
                "shell scene: emit succeeds");
  expect_true(scene.rect_count >= ER_TEST_SHELL_MIN_CHROME_RECTS, "shell scene: chrome and surfaces emit rects");
  expect_true(scene.hit_count >= ER_TEST_SHELL_MIN_CHROME_HITS, "shell scene: launcher tabs and closes emit hits");
  expect_true(shell_scene_has_hit_id(&scene, ER_TEST_SHELL_LAUNCHER_APP_ID), "shell scene: launcher app hit emits");
  expect_true(shell_scene_has_hit_id(&scene, ER_TEST_SHELL_LAUNCHER_UPDATE_ID), "shell scene: update-available app hit emits");
  expect_true(!shell_scene_has_hit_id(&scene, ER_TEST_SHELL_LAUNCHER_REMOVED_ID), "shell scene: removed app is displayed without launch hit");
  expect_size(scene.drop_target_count, ER_TEST_SHELL_SURFACE_COUNT, "shell scene: surface tiles emit drop targets");
  expect_true(scene.icon_quad_count >= ER_TEST_SHELL_MIN_ICON_QUADS, "shell scene: launcher tabs and closes emit Tabler icon quads");
  const er_ui_drop_target_t* first_drop = shell_scene_drop_target(&scene, ER_TEST_SHELL_FIRST_SURFACE_ID);
  const er_ui_drop_target_t* second_drop = shell_scene_drop_target(&scene, ER_TEST_SHELL_SECOND_SURFACE_ID);
  expect_true(first_drop != NULL, "shell scene: focused surface drop target emits");
  expect_true(second_drop != NULL, "shell scene: second surface drop target emits");
  if (first_drop && second_drop) {
    expect_float(first_drop->x, focused_bounds.x + ER_TEST_SHELL_PANEL_PAD, "shell scene: first drop x matches first tile inset");
    expect_float(first_drop->y, focused_bounds.y + ER_TEST_SHELL_PANEL_PAD, "shell scene: first drop y matches workspace inset");
    expect_float(first_drop->w, focused_bounds.w - (ER_TEST_SHELL_PANEL_PAD * 2.0f), "shell scene: first drop width matches tile inset");
    expect_float(first_drop->h, focused_bounds.h - (ER_TEST_SHELL_PANEL_PAD * 2.0f), "shell scene: first drop height matches tile inset");
    expect_float(second_drop->x, surface_bounds.x + ER_TEST_SHELL_PANEL_PAD, "shell scene: second drop x matches second tile inset");
    expect_float(second_drop->w, surface_bounds.w - (ER_TEST_SHELL_PANEL_PAD * 2.0f), "shell scene: second drop width matches tile inset");
  }

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
  action.hit = er_ui_hit(ER_UI_HIT_WORKSPACE_TAB, ER_TEST_SHELL_SECOND_SURFACE_ID, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: tab selected applies");
  expect_true(changed, "shell action: tab selected reports focus change");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_SECOND_SURFACE_ID, "shell action: tab selected focuses surface");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "shell action: tab selection retains prior focus");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_WORKSPACE_CLOSE, ER_TEST_SHELL_SECOND_SURFACE_ID, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: close applies");
  expect_true(changed, "shell action: close reports changed");
  expect_size(er_ui_workspace_surface_count(&shell), 1u, "shell action: close removes one surface");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "shell action: close falls focus back");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), 0u, "shell action: close clears missing previous focus");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_HOVERED;
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell action: ignored action applies");
  expect_true(!changed, "shell action: ignored action reports unchanged");

  er_ui_shell_set_launcher_open(&shell, true);
  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_APP_LAUNCHER_ITEM, ER_TEST_SHELL_LAUNCHER_APP_ID, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "launcher action: installed app activates");
  expect_true(changed, "launcher action: installed app reports changed");
  expect_true(!er_ui_shell_launcher_open(&shell), "launcher action: installed app closes launcher");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "launcher action: installed app focuses target surface");

  expect_status(er_ui_workspace_add_surface(&shell, ER_TEST_SHELL_SECOND_SURFACE_ID), ER_UI_OK, "workspace nav: second surface reopens");
  expect_status(er_ui_workspace_add_surface(&shell, ER_TEST_SHELL_THIRD_SURFACE_ID), ER_UI_OK, "workspace nav: third surface opens");
  expect_status(er_ui_workspace_focus_surface(&shell, ER_TEST_SHELL_FIRST_SURFACE_ID), ER_UI_OK, "workspace nav: first surface refocuses");
  expect_status(er_ui_workspace_focus_surface(&shell, ER_TEST_SHELL_THIRD_SURFACE_ID), ER_UI_OK, "workspace nav: third surface refocuses");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace nav: previous focus is retained out of order");
  expect_status(er_ui_workspace_remove_surface(&shell, ER_TEST_SHELL_THIRD_SURFACE_ID), ER_UI_OK, "workspace nav: closing focused third succeeds");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace nav: close restores retained previous focus");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), ER_TEST_SHELL_SECOND_SURFACE_ID, "workspace nav: close keeps alternate switch target");
  expect_status(er_ui_workspace_focus_next_surface(&shell), ER_UI_OK, "workspace nav: next focus succeeds");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_SECOND_SURFACE_ID, "workspace nav: next focus advances");
  expect_u32(er_ui_workspace_previous_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace nav: next focus updates previous");
  expect_status(er_ui_workspace_focus_next_surface(&shell), ER_UI_OK, "workspace nav: next focus wraps");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace nav: next focus wraps to first");
  expect_status(er_ui_workspace_focus_previous_surface(&shell), ER_UI_OK, "workspace nav: previous focus wraps");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_SECOND_SURFACE_ID, "workspace nav: previous focus wraps to last");
  expect_status(er_ui_workspace_remove_surface(&shell, ER_TEST_SHELL_SECOND_SURFACE_ID), ER_UI_OK, "workspace nav: second surface closes");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "workspace nav: first surface remains focused");

  action = (er_ui_action_t){0};
  action.kind = ER_UI_ACTION_ACTIVATED;
  action.has_hit = true;
  action.hit = er_ui_hit(ER_UI_HIT_APP_LAUNCHER_ITEM, ER_TEST_SHELL_LAUNCHER_REMOVED_ID, 0.0f, 0.0f, 1.0f, 1.0f);
  expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "launcher action: removed app action applies");
  expect_true(!changed, "launcher action: removed app reports unchanged");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), ER_TEST_SHELL_FIRST_SURFACE_ID, "launcher action: removed app does not change focus");

  {
    vr_font_face_t* face =
        er_ui_test_open_font(18.0f, "shell prompt: bundled variable font loads", "shell prompt: variable font opens from memory");
    if (face) {
      er_ui_shell_set_launcher_open(&shell, true);
      er_ui_scene_clear_commands(&scene);
      expect_status(er_ui_shell_emit_scene_with_font(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 640.0f, 400.0f), theme, face), ER_UI_OK,
                    "shell font: normal shell emits with variable font");
      expect_true(scene.text_quad_count > 0u, "shell font: normal shell emits variable font text");
      expect_true(scene.icon_quad_count >= ER_TEST_SHELL_MIN_FONT_ICON_QUADS, "shell font: normal shell emits icon-backed chrome");
      expect_true(!shell_scene_has_hit_id(&scene, ER_UI_NETWORK_APP_PROMPT_RUN_ONCE_ID), "shell font: prompt actions are absent until host opens prompt");

      er_ui_scene_clear_commands(&scene);
      expect_status(er_ui_shell_emit_scene_with_font(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 640.0f, 400.0f), theme, NULL), ER_UI_ERR_INVALID_ARGUMENT,
                    "shell font: font-backed scene rejects missing variable font");

      er_ui_shell_show_network_app_prompt(&shell);
      expect_true(er_ui_shell_network_app_prompt_open(&shell), "shell prompt: prompt opens");
      er_ui_scene_clear_commands(&scene);
      expect_status(er_ui_shell_emit_scene_with_font(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 640.0f, 400.0f), theme, face), ER_UI_OK,
                    "shell prompt: scene emits with variable font");
      expect_true(scene.text_quad_count > 0u, "shell prompt: variable font text emits quads");
      expect_true(shell_scene_has_hit_id(&scene, ER_UI_NETWORK_APP_PROMPT_RUN_ONCE_ID), "shell prompt: run once hit emits");
      expect_true(shell_scene_has_hit_id(&scene, ER_UI_NETWORK_APP_PROMPT_VERIFY_CACHE_ID), "shell prompt: verify cache hit emits");
      expect_true(shell_scene_has_hit_id(&scene, ER_UI_NETWORK_APP_PROMPT_CANCEL_ID), "shell prompt: cancel hit emits");
      expect_true(scene.icon_quad_count > 0u, "shell prompt: reusable prompt emits canonical icon quads");

      action = er_ui_runtime_pointer_down(&runtime, &scene, 250.0f, 316.0f);
      expect_true(action.kind == ER_UI_ACTION_FOCUSED, "shell prompt: pointer down focuses run once");
      action = er_ui_runtime_pointer_up(&runtime, &scene, 250.0f, 316.0f);
      expect_true(action.kind == ER_UI_ACTION_ACTIVATED, "shell prompt: pointer up activates run once");
      expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell prompt: run once action applies");
      expect_true(changed, "shell prompt: run once reports changed");
      expect_true(!er_ui_shell_network_app_prompt_open(&shell), "shell prompt: run once closes prompt");
      expect_true(er_ui_shell_network_app_prompt_choice(&shell) == ER_UI_NETWORK_APP_PROMPT_CHOICE_RUN_ONCE, "shell prompt: run once records choice");
      er_ui_shell_show_network_app_prompt(&shell);
      er_ui_scene_clear_commands(&scene);
      expect_status(er_ui_shell_emit_scene_with_font(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 640.0f, 400.0f), theme, face), ER_UI_OK,
                    "shell prompt: scene re-emits after run once");

      action = (er_ui_action_t){0};
      action.kind = ER_UI_ACTION_ACTIVATED;
      action.has_hit = true;
      action.hit = er_ui_hit(ER_UI_HIT_BUTTON, ER_UI_NETWORK_APP_PROMPT_VERIFY_CACHE_ID, 0.0f, 0.0f, 1.0f, 1.0f);
      expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell prompt: verify cache action applies");
      expect_true(changed, "shell prompt: verify cache reports changed");
      expect_true(!er_ui_shell_network_app_prompt_open(&shell), "shell prompt: verify cache closes prompt");
      expect_true(er_ui_shell_network_app_prompt_choice(&shell) == ER_UI_NETWORK_APP_PROMPT_CHOICE_VERIFY_CACHE,
                  "shell prompt: verify cache records choice");
      er_ui_shell_clear_network_app_prompt_choice(&shell);
      expect_true(er_ui_shell_network_app_prompt_choice(&shell) == ER_UI_NETWORK_APP_PROMPT_CHOICE_NONE, "shell prompt: choice clears");

      er_ui_shell_show_network_app_prompt(&shell);
      er_ui_scene_clear_commands(&scene);
      expect_status(er_ui_shell_emit_scene_with_font(&shell, &scene, er_ui_bounds(0.0f, 0.0f, 640.0f, 400.0f), theme, face), ER_UI_OK,
                    "shell prompt: scene re-emits for cancel");
      action = er_ui_runtime_pointer_down(&runtime, &scene, 512.0f, 316.0f);
      expect_true(action.kind == ER_UI_ACTION_FOCUSED, "shell prompt: pointer down focuses cancel");
      action = er_ui_runtime_pointer_up(&runtime, &scene, 512.0f, 316.0f);
      expect_true(action.kind == ER_UI_ACTION_ACTIVATED, "shell prompt: pointer up activates cancel");
      expect_status(er_ui_shell_apply_action(&shell, action, &changed), ER_UI_OK, "shell prompt: cancel button applies");
      expect_true(changed, "shell prompt: cancel button reports changed");
      expect_true(!er_ui_shell_network_app_prompt_open(&shell), "shell prompt: cancel button closes prompt");
      expect_true(er_ui_shell_network_app_prompt_choice(&shell) == ER_UI_NETWORK_APP_PROMPT_CHOICE_CANCEL, "shell prompt: cancel button records choice");
      vr_font_face_destroy(face);
    }
  }

  expect_status(er_ui_workspace_remove_surface(&shell, ER_TEST_SHELL_FIRST_SURFACE_ID), ER_UI_OK, "workspace: remove final surface succeeds");
  expect_u32(er_ui_workspace_focused_surface_id(&shell), 0u, "workspace: focus clears when empty");

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_shell_state_destroy(&shell);
}
