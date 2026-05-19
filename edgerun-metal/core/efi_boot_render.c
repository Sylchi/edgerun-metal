#include "efi_boot_internal.h"

ErUiBootAppContext* er_ui_boot_active_app(ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

const ErUiBootAppContext* er_ui_boot_active_app_const(const ErUiBootRenderContext* render) {
  if (render == 0 || render->apps == 0 || render->app_count == 0u ||
      render->active_app >= render->app_count ||
      render->apps[render->active_app].ready == 0u) {
    return 0;
  }
  return &render->apps[render->active_app];
}

UINT8 er_ui_boot_switch_app_for_surface(ErUiBootRenderContext* render, UINT32 surface_id) {
  UINT32 app_index;

  if (render == 0 || render->apps == 0 || render->app_count == 0u) {
    return 0u;
  }
  switch (surface_id) {
    case ER_UI_LEDGER_APP_LEDGER_ID:
      app_index = 0u;
      break;
    case ER_UI_LEDGER_APP_PAYMENTS_ID:
      app_index = render->app_count > 1u ? 1u : 0u;
      break;
    case ER_UI_LEDGER_APP_ACCESS_ID:
      app_index = 0u;
      break;
    default:
      return 1u;
  }
  if (app_index >= render->app_count || render->apps[app_index].ready == 0u) {
    return 0u;
  }
  render->active_app = app_index;
  return 1u;
}

UINT8 er_ui_boot_render_scene(er_ui_scene_t* scene,
                                     er_ui_ledger_app_state_t* ledger_state,
                                     const ErUiBootRenderContext* render) {
  er_ui_scene_stats_t scene_stats;
  er_ui_scene_budget_violation_t scene_violation;
  ErUiSurfaceRenderStats render_stats;
  ErUiSurfaceFrameBudgetViolation frame_violation;

  if (scene == 0 || ledger_state == 0 || render == 0 || render->font == 0 ||
      render->surface == 0 || render->tile_plan == 0) {
    return 0u;
  }

  er_ui_scene_clear_commands(scene);
  if (er_ui_ledger_app_emit_scene(ledger_state,
                                  scene,
                                  render->font,
                                  er_ui_bounds(0.0f, 0.0f, (float)render->mode.width, (float)render->mode.height),
                                  render->theme) != ER_UI_OK) {
    er_println("ui renderer: scene build failed");
    return 0u;
  }

  scene_stats = er_ui_scene_stats(scene);
  if (er_ui_scene_first_budget_violation(scene_stats, render->scene_budget, &scene_violation)) {
    er_print("ui renderer: scene budget exceeded ");
    er_print(scene_violation.name);
    er_print(" actual=");
    er_print_u64_dec((UINT64)scene_violation.actual);
    er_print(" limit=");
    er_print_u64_dec((UINT64)scene_violation.limit);
    er_println("");
    return 0u;
  }

  if (er_ui_surface_render_scene_with_font_stats(render->surface, scene, render->font, &render_stats) == 0u) {
    er_println("ui renderer: render failed");
    return 0u;
  }
  if (er_ui_boot_gpu_present(render) == 0u) {
    er_println("ui renderer: virtio gpu present failed");
    return 0u;
  }

  if (er_ui_surface_render_stats_first_budget_violation(render_stats, render->frame_budget, &frame_violation) != 0u) {
    er_print("ui renderer: frame budget exceeded ");
    er_print(frame_violation.name);
    er_print(" actual=");
    er_print_u64_dec(frame_violation.actual);
    er_print(" limit=");
    er_print_u64_dec(frame_violation.limit);
    er_println("");
    return 0u;
  }

  er_print("ui renderer: app=");
  er_print_u64_dec((UINT64)render->active_app);
  er_print(" surface=");
  er_print_u64_dec((UINT64)er_ui_workspace_focused_surface_id(&ledger_state->shell));
  er_print(" bytes=");
  er_print_u64_dec(render_stats.bytes_written);
  er_print(" rects=");
  er_print_u64_dec(render_stats.rects);
  er_print(" text=");
  er_print_u64_dec(render_stats.text_quads);
  er_print(" tile_bytes=");
  er_print_u64_dec(render->tile_plan->max_tile_bytes);
  er_print(" mem=");
  er_print_u64_dec(render->memory_plan.total_bytes);
  er_println("");

  return 1u;
}

er_ui_action_t er_ui_boot_action_from_ps2(er_ui_runtime_state_t* runtime,
                                                 const er_ui_scene_t* scene,
                                                 ErPs2KeyboardAction input) {
  er_ui_action_t action = {0};

  action.kind = ER_UI_ACTION_NONE;
  if (input.kind == ER_PS2_KEYBOARD_ACTION_UI_KEY) {
    return er_ui_runtime_key_down(runtime, scene, input.key, input.modifiers);
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE) {
    action.kind = ER_UI_ACTION_TAB_SELECTED;
    action.id = input.surface_id;
  }
  return action;
}

UINT8 er_ui_boot_apply_input(er_ui_ledger_app_state_t* ledger_state,
                                    er_ui_runtime_state_t* runtime,
                                    er_ui_scene_t* scene,
                                    ErUiBootRenderContext* render,
                                    ErPs2KeyboardAction input,
                                    UINT8* out_redraw) {
  ErUiBootAppContext* active_app;
  er_ui_action_t action;
  bool changed = false;

  if (out_redraw == 0) {
    return 0u;
  }
  *out_redraw = 0u;
  if (ledger_state == 0 || runtime == 0 || scene == 0) {
    return 0u;
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_NONE) {
    return 1u;
  }
  if (input.kind == ER_PS2_KEYBOARD_ACTION_SELECT_SURFACE) {
    if (er_ui_boot_switch_app_for_surface(render, input.surface_id) == 0u) {
      return 0u;
    }
    *out_redraw = 1u;
  }
  active_app = er_ui_boot_active_app(render);
  if (input.kind == ER_PS2_KEYBOARD_ACTION_UI_KEY && active_app != 0) {
    if (er_ui_wasm_app_deliver_key_input(&active_app->runtime,
                                         input.key, input.modifiers) != 0 ||
        er_ui_boot_execute_wasm_counter(&active_app->runtime) == 0u) {
      return 0u;
    }
    *out_redraw = 1u;
  }
  action = er_ui_boot_action_from_ps2(runtime, scene, input);
  if (action.kind == ER_UI_ACTION_NONE) {
    return 1u;
  }
  if (er_ui_ledger_app_apply_action(ledger_state, action, &changed) != ER_UI_OK) {
    return 0u;
  }
  *out_redraw = (UINT8)(changed || er_ui_action_needs_redraw(action));
  return 1u;
}

//@optimizer-ignore-function post-ExitBootServices input loop must poll PS/2 I/O and redraw after accepted key events
void er_ui_boot_input_loop(er_ui_ledger_app_state_t* ledger_state,
                                  er_ui_runtime_state_t* runtime,
                                  er_ui_scene_t* scene,
                                  ErUiBootRenderContext* render) {
  ErPs2KeyboardState keyboard = {0};

  for (;;) {
    ErPs2KeyboardAction input;
    UINT8 relay_redraw = 0u;
    UINT8 redraw = 0u;

    if (er_ui_boot_poll_native_relay(render, &relay_redraw) == 0u) {
      er_idle_forever();
    }
    if (relay_redraw != 0u &&
        er_ui_boot_render_scene(scene, ledger_state, render) == 0u) {
      er_idle_forever();
    }
    if (er_ps2_keyboard_poll(&keyboard, &input) == 0u) {
      er_idle_forever();
    }
    if (input.kind == ER_PS2_KEYBOARD_ACTION_QUIT) {
      er_idle_forever();
    }
    if (input.kind == ER_PS2_KEYBOARD_ACTION_NONE) {
      er_pause_once();
      continue;
    }
    if (er_ui_boot_apply_input(ledger_state, runtime, scene, render, input, &redraw) == 0u) {
      er_idle_forever();
    }
    if (redraw != 0u &&
        er_ui_boot_render_scene(scene, ledger_state, render) == 0u) {
      er_idle_forever();
    }
  }
}
