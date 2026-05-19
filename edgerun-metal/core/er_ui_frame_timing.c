#include "er_ui_frame_timing.h"
#include "er_mem.h"

static UINT8 er_ui_frame_timing_config_valid(ErUiFrameTimingConfig config) {
  return (UINT8)(config.width != 0u &&
                 config.height != 0u &&
                 config.refresh_hz != 0u &&
                 config.ticks_per_second != 0u &&
                 config.ticks_per_second <= ER_UI_FRAME_TIMING_NS_PER_SECOND);
}

static UINT8 er_ui_frame_timing_ticks_to_ns(UINT64 ticks_per_second,
                                            UINT64 start_ticks,
                                            UINT64 end_ticks,
                                            UINT64* out_ns) {
  UINT64 delta;
  UINT64 whole_seconds;
  UINT64 remainder_ticks;
  UINT64 whole_ns;
  UINT64 remainder_ns;

  if (out_ns == 0 || ticks_per_second == 0u ||
      ticks_per_second > ER_UI_FRAME_TIMING_NS_PER_SECOND ||
      end_ticks < start_ticks) {
    return 0u;
  }
  delta = end_ticks - start_ticks;
  whole_seconds = delta / ticks_per_second;
  remainder_ticks = delta % ticks_per_second;
  if (whole_seconds > UINT64_MAX / ER_UI_FRAME_TIMING_NS_PER_SECOND) {
    return 0u;
  }
  whole_ns = whole_seconds * ER_UI_FRAME_TIMING_NS_PER_SECOND;
  if (remainder_ticks > UINT64_MAX / ER_UI_FRAME_TIMING_NS_PER_SECOND) {
    return 0u;
  }
  remainder_ns = (remainder_ticks * ER_UI_FRAME_TIMING_NS_PER_SECOND) /
                 ticks_per_second;
  if (whole_ns > UINT64_MAX - remainder_ns) {
    return 0u;
  }
  *out_ns = whole_ns + remainder_ns;
  return 1u;
}

UINT8 er_ui_frame_timing_config_from_mode(const ErUiSurfaceMode* mode,
                                          UINT64 ticks_per_second,
                                          ErUiFrameTimingConfig* out_config) {
  ErUiFrameTimingConfig config;

  if (mode == 0 || out_config == 0 || er_ui_surface_mode_valid(mode) == 0u) {
    return 0u;
  }
  config.width = mode->width;
  config.height = mode->height;
  config.refresh_hz = mode->refresh_hz;
  config.ticks_per_second = ticks_per_second;
  if (er_ui_frame_timing_config_valid(config) == 0u) {
    return 0u;
  }
  *out_config = config;
  return 1u;
}

UINT8 er_ui_frame_timing_is_4k120_target(ErUiFrameTimingConfig config) {
  return (UINT8)(config.width >= ER_UI_FRAME_TIMING_TARGET_4K_WIDTH &&
                 config.height >= ER_UI_FRAME_TIMING_TARGET_4K_HEIGHT &&
                 config.refresh_hz >= ER_UI_FRAME_TIMING_TARGET_120HZ);
}

UINT8 er_ui_frame_timing_begin(ErUiFrameTimingConfig config,
                               UINT64 frame_begin_ticks,
                               ErUiFrameTiming* out_timing) {
  if (out_timing == 0 || er_ui_frame_timing_config_valid(config) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_timing, (UINTN)sizeof(*out_timing));
  out_timing->config = config;
  out_timing->target_frame_ns = ER_UI_FRAME_TIMING_NS_PER_SECOND /
                                (UINT64)config.refresh_hz;
  out_timing->frame_begin_ticks = frame_begin_ticks;
  return (UINT8)(out_timing->target_frame_ns != 0u);
}

UINT8 er_ui_frame_timing_finish_scene(ErUiFrameTiming* timing,
                                      UINT64 scene_end_ticks) {
  UINT64 scene_ns;

  if (timing == 0 || er_ui_frame_timing_config_valid(timing->config) == 0u ||
      er_ui_frame_timing_ticks_to_ns(timing->config.ticks_per_second,
                                     timing->frame_begin_ticks,
                                     scene_end_ticks,
                                     &scene_ns) == 0u) {
    return 0u;
  }
  timing->scene_end_ticks = scene_end_ticks;
  timing->stage_ns[ER_UI_FRAME_TIMING_STAGE_SCENE] = scene_ns;
  return 1u;
}

UINT8 er_ui_frame_timing_finish_raster(ErUiFrameTiming* timing,
                                       UINT64 raster_end_ticks) {
  UINT64 raster_ns;

  if (timing == 0 || timing->scene_end_ticks == 0u ||
      er_ui_frame_timing_ticks_to_ns(timing->config.ticks_per_second,
                                     timing->scene_end_ticks,
                                     raster_end_ticks,
                                     &raster_ns) == 0u) {
    return 0u;
  }
  timing->raster_end_ticks = raster_end_ticks;
  timing->stage_ns[ER_UI_FRAME_TIMING_STAGE_RASTER] = raster_ns;
  return 1u;
}

UINT8 er_ui_frame_timing_finish_present(ErUiFrameTiming* timing,
                                        UINT64 present_end_ticks) {
  UINT64 present_ns;
  UINT64 total_ns;

  if (timing == 0 || timing->raster_end_ticks == 0u ||
      er_ui_frame_timing_ticks_to_ns(timing->config.ticks_per_second,
                                     timing->raster_end_ticks,
                                     present_end_ticks,
                                     &present_ns) == 0u ||
      er_ui_frame_timing_ticks_to_ns(timing->config.ticks_per_second,
                                     timing->frame_begin_ticks,
                                     present_end_ticks,
                                     &total_ns) == 0u) {
    return 0u;
  }
  timing->present_end_ticks = present_end_ticks;
  timing->stage_ns[ER_UI_FRAME_TIMING_STAGE_PRESENT] = present_ns;
  timing->stage_ns[ER_UI_FRAME_TIMING_STAGE_TOTAL] = total_ns;
  timing->complete = 1u;
  return 1u;
}

UINT8 er_ui_frame_timing_first_budget_violation(
    const ErUiFrameTiming* timing,
    ErUiFrameTimingViolation* out_violation) {
  if (timing == 0 || timing->complete == 0u ||
      er_ui_frame_timing_config_valid(timing->config) == 0u) {
    return 0u;
  }
  if (timing->stage_ns[ER_UI_FRAME_TIMING_STAGE_TOTAL] <=
      timing->target_frame_ns) {
    return 0u;
  }
  if (out_violation != 0) {
    out_violation->name = "frame_total_ns";
    out_violation->actual_ns =
        timing->stage_ns[ER_UI_FRAME_TIMING_STAGE_TOTAL];
    out_violation->limit_ns = timing->target_frame_ns;
  }
  return 1u;
}

UINT8 er_ui_frame_timing_fits_budget(const ErUiFrameTiming* timing) {
  if (timing == 0 || timing->complete == 0u) {
    return 0u;
  }
  return (UINT8)(er_ui_frame_timing_first_budget_violation(timing, 0) == 0u);
}
