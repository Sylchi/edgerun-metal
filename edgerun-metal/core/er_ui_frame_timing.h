#ifndef ER_UI_FRAME_TIMING_H
#define ER_UI_FRAME_TIMING_H

/*
 * Purpose: account UI frame build, raster, and present time against explicit display targets.
 * Intention: make 4K/120 Hz claims depend on measured frame budgets, not renderer shape alone.
 */

#include "er_types.h"
#include "er_ui_surface_renderer.h"

#define ER_UI_FRAME_TIMING_NS_PER_SECOND 1000000000ull
#define ER_UI_FRAME_TIMING_TARGET_4K_WIDTH 3840u
#define ER_UI_FRAME_TIMING_TARGET_4K_HEIGHT 2160u
#define ER_UI_FRAME_TIMING_TARGET_120HZ 120u

typedef enum {
  ER_UI_FRAME_TIMING_STAGE_SCENE = 0,
  ER_UI_FRAME_TIMING_STAGE_RASTER = 1,
  ER_UI_FRAME_TIMING_STAGE_PRESENT = 2,
  ER_UI_FRAME_TIMING_STAGE_TOTAL = 3,
  ER_UI_FRAME_TIMING_STAGE_COUNT = 4
} ErUiFrameTimingStage;

typedef struct {
  UINT32 width;
  UINT32 height;
  UINT32 refresh_hz;
  UINT64 ticks_per_second;
} ErUiFrameTimingConfig;

typedef struct {
  ErUiFrameTimingConfig config;
  UINT64 target_frame_ns;
  UINT64 frame_begin_ticks;
  UINT64 scene_end_ticks;
  UINT64 raster_end_ticks;
  UINT64 present_end_ticks;
  UINT64 stage_ns[ER_UI_FRAME_TIMING_STAGE_COUNT];
  UINT8 complete;
} ErUiFrameTiming;

typedef struct {
  const char* name;
  UINT64 actual_ns;
  UINT64 limit_ns;
} ErUiFrameTimingViolation;

UINT8 er_ui_frame_timing_config_from_mode(const ErUiSurfaceMode* mode,
                                          UINT64 ticks_per_second,
                                          ErUiFrameTimingConfig* out_config);
UINT8 er_ui_frame_timing_is_4k120_target(ErUiFrameTimingConfig config);
UINT8 er_ui_frame_timing_begin(ErUiFrameTimingConfig config,
                               UINT64 frame_begin_ticks,
                               ErUiFrameTiming* out_timing);
UINT8 er_ui_frame_timing_finish_scene(ErUiFrameTiming* timing,
                                      UINT64 scene_end_ticks);
UINT8 er_ui_frame_timing_finish_raster(ErUiFrameTiming* timing,
                                       UINT64 raster_end_ticks);
UINT8 er_ui_frame_timing_finish_present(ErUiFrameTiming* timing,
                                        UINT64 present_end_ticks);
UINT8 er_ui_frame_timing_first_budget_violation(
    const ErUiFrameTiming* timing,
    ErUiFrameTimingViolation* out_violation);
UINT8 er_ui_frame_timing_fits_budget(const ErUiFrameTiming* timing);

#endif
