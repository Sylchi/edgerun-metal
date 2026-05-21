#include "internal/efi_boot_internal.h"

UINT8 er_ui_boot_render_scene(er_ui_scene_t* scene,
                                     er_ui_ledger_app_state_t* ledger_state,
                                     ErUiBootRenderContext* render) {
  er_ui_scene_stats_t scene_stats;
  er_ui_scene_budget_violation_t scene_violation;
  ErUiSurfaceRenderStats render_stats;
  ErUiSurfaceFrameBudgetViolation frame_violation;
  ErUiFrameTiming frame_timing;
  ErUiFrameTimingConfig timing_config;
  ErUiFrameTimingViolation timing_violation;
  ErUiSurfaceDirtyTileList dirty_tiles;
  UINT64 frame_begin_ticks = 0u;
  UINT64 scene_end_ticks = 0u;
  UINT64 raster_end_ticks = 0u;
  UINT64 present_end_ticks = 0u;
  UINT8 timing_enabled = 0u;

  if (scene == 0 || ledger_state == 0 || render == 0 || render->font == 0 ||
      render->surface == 0 || render->tile_plan == 0 ||
      render->previous_scene == 0 || render->tile_marks == 0 ||
      render->dirty_tile_ids == 0) {
    return 0u;
  }

  er_mem_zero((UINT8*)&frame_timing, (UINTN)sizeof(frame_timing));
  if (render->frame_clock.read != 0 &&
      er_ui_frame_timing_config_from_mode(&render->mode,
                                          render->frame_clock.ticks_per_second,
                                          &timing_config) != 0u) {
    if (render->frame_clock.read(render->frame_clock.user, &frame_begin_ticks) == 0u ||
        er_ui_frame_timing_begin(timing_config, frame_begin_ticks, &frame_timing) == 0u) {
      er_println("ui renderer: frame clock failed");
      return 0u;
    }
    timing_enabled = 1u;
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
  if (timing_enabled != 0u) {
    if (render->frame_clock.read(render->frame_clock.user, &scene_end_ticks) == 0u ||
        er_ui_frame_timing_finish_scene(&frame_timing, scene_end_ticks) == 0u) {
      er_println("ui renderer: frame scene timing failed");
      return 0u;
    }
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

  if (er_ui_boot_prepare_dirty_tiles(render, scene, &dirty_tiles) == 0u) {
    er_println("ui renderer: dirty tile planning failed");
    return 0u;
  }
  ErUiSurfaceRenderDesc render_desc = {
    .scene = scene,
    .font = render->font,
    .tile_plan = render->tile_plan,
    .dirty_tiles = &dirty_tiles,
    .out_stats = &render_stats,
    .mode = ER_UI_SURFACE_RENDER_DIRTY_TILES
  };
  if (er_ui_surface_render(render->surface, &render_desc) == 0u) {
    er_println("ui renderer: render failed");
    return 0u;
  }
  if (timing_enabled != 0u) {
    if (render->frame_clock.read(render->frame_clock.user, &raster_end_ticks) == 0u ||
        er_ui_frame_timing_finish_raster(&frame_timing, raster_end_ticks) == 0u) {
      er_println("ui renderer: frame raster timing failed");
      return 0u;
    }
  }
  if (er_ui_boot_gpu_present(render) == 0u) {
    er_println("ui renderer: virtio gpu present failed");
    return 0u;
  }
  if (timing_enabled != 0u) {
    if (render->frame_clock.read(render->frame_clock.user, &present_end_ticks) == 0u ||
        er_ui_frame_timing_finish_present(&frame_timing, present_end_ticks) == 0u) {
      er_println("ui renderer: frame present timing failed");
      return 0u;
    }
    render->last_frame_timing = frame_timing;
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
  if (er_ui_boot_commit_rendered_scene(render, scene) == 0u) {
    er_println("ui renderer: scene commit failed");
    return 0u;
  }

  er_print("ui renderer: surface=");
  er_print_u64_dec((UINT64)er_ui_workspace_focused_surface_id(&ledger_state->shell));
  er_print(" bytes=");
  er_print_u64_dec(render_stats.bytes_written);
  er_print(" rects=");
  er_print_u64_dec(render_stats.rects);
  er_print(" text=");
  er_print_u64_dec(render_stats.text_quads);
  er_print(" dirty=");
  er_print_u64_dec((UINT64)dirty_tiles.count);
  er_print(" tile_bytes=");
  er_print_u64_dec(render->tile_plan->max_tile_bytes);
  er_print(" mem=");
  er_print_u64_dec(render->memory_plan.total_bytes);
  if (timing_enabled != 0u) {
    er_print(" frame_ns=");
    er_print_u64_dec(frame_timing.stage_ns[ER_UI_FRAME_TIMING_STAGE_TOTAL]);
    er_print(" target_ns=");
    er_print_u64_dec(frame_timing.target_frame_ns);
    er_print(" scene_ns=");
    er_print_u64_dec(frame_timing.stage_ns[ER_UI_FRAME_TIMING_STAGE_SCENE]);
    er_print(" raster_ns=");
    er_print_u64_dec(frame_timing.stage_ns[ER_UI_FRAME_TIMING_STAGE_RASTER]);
    er_print(" present_ns=");
    er_print_u64_dec(frame_timing.stage_ns[ER_UI_FRAME_TIMING_STAGE_PRESENT]);
    if (er_ui_frame_timing_first_budget_violation(&frame_timing, &timing_violation) != 0u) {
      er_print(" timing_exceeded=");
      er_print(timing_violation.name);
    }
  }
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
    UINT8 redraw = 0u;

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
