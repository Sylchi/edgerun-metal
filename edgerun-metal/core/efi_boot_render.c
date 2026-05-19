#include "efi_boot_internal.h"

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
