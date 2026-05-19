#include "efi_boot_internal.h"

#include <stdio.h>

enum {
  BENCH_UI_WIDTH = 3840u,
  BENCH_UI_HEIGHT = 2160u,
  BENCH_UI_STRIDE = 3840u,
  BENCH_UI_TILE_WIDTH = 128u,
  BENCH_UI_TILE_HEIGHT = 64u,
  BENCH_UI_MAX_DIRTY_TILES = 2048u,
  BENCH_UI_RECT_COUNT = 64u,
  BENCH_UI_PANEL_COLUMNS = 8u,
  BENCH_UI_PANEL_W = 360u,
  BENCH_UI_PANEL_H = 180u,
  BENCH_UI_PANEL_GAP_X = 40u,
  BENCH_UI_PANEL_GAP_Y = 34u,
  BENCH_UI_PANEL_START_X = 80u,
  BENCH_UI_PANEL_START_Y = 90u,
  BENCH_UI_MUTATED_RECT = 17u,
  BENCH_UI_PRESENT_COMMANDS_PER_RECT = 2u,
  BENCH_UI_PRESENT_COMMAND_COST = 4096u,
  BENCH_UI_RATIO_SCALE = 1000u,
  BENCH_UI_EPOCH_TICKS_PER_SLOT = 1099511627776ull,
  BENCH_UI_EPOCH_SLOTS_PER_EPOCH = 1024u,
  BENCH_UI_EPOCHS_PER_ERA = 1024u
};

static UINT32 g_bench_pixels[BENCH_UI_WIDTH * BENCH_UI_HEIGHT];
static UINT8 g_tile_marks[BENCH_UI_MAX_DIRTY_TILES];
static UINT32 g_dirty_tile_ids[BENCH_UI_MAX_DIRTY_TILES];
static ErUiSurfacePixelRect g_present_rects[BENCH_UI_MAX_DIRTY_TILES];
static er_ui_rect_t g_prev_rects[BENCH_UI_RECT_COUNT];
static er_ui_rect_t g_next_rects[BENCH_UI_RECT_COUNT];

typedef struct {
  UINT64 raster_bytes;
  UINT64 present_bytes;
  UINT64 present_rects;
  UINT64 present_commands;
  UINT64 work_ticks;
  ErEpochStamp stamp;
} BenchUiWork;

static void bench_ui_rects(er_ui_rect_t* rects, UINT8 mutated) {
  UINT32 i;
  UINT32 column;
  UINT32 row;
  float x;
  float y;
  er_ui_color4_t color;

  for (i = 0u; i < BENCH_UI_RECT_COUNT; ++i) {
    column = i % BENCH_UI_PANEL_COLUMNS;
    row = i / BENCH_UI_PANEL_COLUMNS;
    x = (float)(BENCH_UI_PANEL_START_X +
                column * (BENCH_UI_PANEL_W + BENCH_UI_PANEL_GAP_X));
    y = (float)(BENCH_UI_PANEL_START_Y +
                row * (BENCH_UI_PANEL_H + BENCH_UI_PANEL_GAP_Y));
    color = er_ui_color_rgb_u8((uint8_t)(30u + i),
                               (uint8_t)(80u + i),
                               (uint8_t)(120u + i));
    if (mutated != 0u && i == BENCH_UI_MUTATED_RECT) {
      x += 96.0f;
      y += 64.0f;
      color = er_ui_color_rgb_u8(220u, 48u, 80u);
    }
    rects[i] = er_ui_rect_fill(x, y,
                               (float)BENCH_UI_PANEL_W,
                               (float)BENCH_UI_PANEL_H,
                               0.0f,
                               color);
  }
}

static UINT8 bench_ui_clock_advance(ErEpochClock* clock, UINT64 ticks) {
  ErEpochClockModifier modifier;

  if (ticks == 0u) {
    return 1u;
  }
  modifier.tick_stride = ticks;
  return er_epoch_clock_advance_with_modifier(clock, &modifier, 0);
}

static UINT64 bench_ui_present_bytes(const ErUiSurfacePixelRect* rects,
                                     UINT32 rect_count) {
  UINT64 bytes = 0u;
  UINT32 i;

  for (i = 0u; i < rect_count; ++i) {
    bytes += (UINT64)(rects[i].x1 - rects[i].x0) *
             (UINT64)(rects[i].y1 - rects[i].y0) *
             ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL;
  }
  return bytes;
}

static UINT8 bench_ui_work_from_render(ErEpochClock* clock,
                                       UINT64 raster_bytes,
                                       UINT64 present_bytes,
                                       UINT64 present_rects,
                                       BenchUiWork* out_work) {
  UINT64 command_count;
  UINT64 work_ticks;

  if (clock == 0 || out_work == 0) {
    return 0u;
  }
  command_count = present_rects * BENCH_UI_PRESENT_COMMANDS_PER_RECT;
  work_ticks = raster_bytes + present_bytes +
               command_count * BENCH_UI_PRESENT_COMMAND_COST;
  if (bench_ui_clock_advance(clock, work_ticks) == 0u) {
    return 0u;
  }
  out_work->raster_bytes = raster_bytes;
  out_work->present_bytes = present_bytes;
  out_work->present_rects = present_rects;
  out_work->present_commands = command_count;
  out_work->work_ticks = work_ticks;
  out_work->stamp = clock->now;
  return 1u;
}

static void bench_ui_print_work(const char* name, BenchUiWork work) {
  printf("%s raster_bytes=%llu present_bytes=%llu present_rects=%llu present_commands=%llu work_ticks=%llu epoch=%llu slot=%llu tick=%llu\n",
         name,
         (unsigned long long)work.raster_bytes,
         (unsigned long long)work.present_bytes,
         (unsigned long long)work.present_rects,
         (unsigned long long)work.present_commands,
         (unsigned long long)work.work_ticks,
         (unsigned long long)work.stamp.epoch,
         (unsigned long long)work.stamp.slot,
         (unsigned long long)work.stamp.tick);
}

int main(void) {
  ErUiSurface surface;
  ErUiSurfaceTilePlan tile_plan;
  ErUiSurfaceRenderStats full_stats;
  ErUiSurfaceRenderStats dirty_stats;
  ErUiSurfaceDirtyTileList dirty_tiles;
  ErUiBootRenderContext render;
  ErEpochClockLimits limits;
  ErEpochClock full_clock;
  ErEpochClock dirty_clock;
  BenchUiWork full_work;
  BenchUiWork dirty_work;
  er_ui_scene_t prev_scene;
  er_ui_scene_t next_scene;

  er_mem_zero((UINT8*)&render, (UINTN)sizeof(render));
  er_mem_zero((UINT8*)&prev_scene, (UINTN)sizeof(prev_scene));
  er_mem_zero((UINT8*)&next_scene, (UINTN)sizeof(next_scene));

  bench_ui_rects(g_prev_rects, 0u);
  bench_ui_rects(g_next_rects, 1u);
  prev_scene.clear = er_ui_color_rgb_u8(8u, 10u, 14u);
  prev_scene.rects = g_prev_rects;
  prev_scene.rect_count = BENCH_UI_RECT_COUNT;
  prev_scene.rect_capacity = BENCH_UI_RECT_COUNT;
  next_scene.clear = prev_scene.clear;
  next_scene.rects = g_next_rects;
  next_scene.rect_count = BENCH_UI_RECT_COUNT;
  next_scene.rect_capacity = BENCH_UI_RECT_COUNT;

  surface.pixels = g_bench_pixels;
  surface.width = BENCH_UI_WIDTH;
  surface.height = BENCH_UI_HEIGHT;
  surface.stride = BENCH_UI_STRIDE;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  if (er_ui_surface_tile_plan(&surface,
                              BENCH_UI_TILE_WIDTH,
                              BENCH_UI_TILE_HEIGHT,
                              BENCH_UI_MAX_DIRTY_TILES,
                              &tile_plan) == 0u) {
    printf("ui-dirty-bench: tile plan failed\n");
    return 1;
  }

  limits.ticks_per_slot = BENCH_UI_EPOCH_TICKS_PER_SLOT;
  limits.slots_per_epoch = BENCH_UI_EPOCH_SLOTS_PER_EPOCH;
  limits.epochs_per_era = BENCH_UI_EPOCHS_PER_ERA;
  if (er_epoch_clock_init(&limits, &full_clock) == 0u ||
      er_epoch_clock_init(&limits, &dirty_clock) == 0u) {
    printf("ui-dirty-bench: clock init failed\n");
    return 1;
  }

  if (er_ui_surface_render_scene_with_font_stats(&surface,
                                                 &next_scene,
                                                 0,
                                                 &full_stats) == 0u ||
      bench_ui_work_from_render(&full_clock,
                                full_stats.bytes_written,
                                tile_plan.full_frame_bytes,
                                1u,
                                &full_work) == 0u) {
    printf("ui-dirty-bench: full render failed\n");
    return 1;
  }

  render.tile_plan = &tile_plan;
  render.previous_scene = &prev_scene;
  render.tile_marks = g_tile_marks;
  render.tile_mark_count = BENCH_UI_MAX_DIRTY_TILES;
  render.dirty_tile_ids = g_dirty_tile_ids;
  render.dirty_tile_capacity = BENCH_UI_MAX_DIRTY_TILES;
  render.present_rects = g_present_rects;
  render.present_rect_capacity = BENCH_UI_MAX_DIRTY_TILES;
  er_ui_surface_frame_state_commit(&render.frame_state);

  if (er_ui_boot_prepare_dirty_tiles(&render, &next_scene, &dirty_tiles) == 0u ||
      er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface,
                                                             &next_scene,
                                                             0,
                                                             &tile_plan,
                                                             &dirty_tiles,
                                                             &dirty_stats) == 0u ||
      er_ui_boot_dirty_present_rects(&render) == 0u ||
      bench_ui_work_from_render(&dirty_clock,
                                dirty_stats.bytes_written,
                                bench_ui_present_bytes(g_present_rects,
                                                       render.last_present_rect_count),
                                render.last_present_rect_count,
                                &dirty_work) == 0u) {
    printf("ui-dirty-bench: dirty render failed\n");
    return 1;
  }

  printf("UI dirty render benchmark: %ux%u tile=%ux%u scene_rects=%u mutated_rect=%u\n",
         (unsigned)BENCH_UI_WIDTH,
         (unsigned)BENCH_UI_HEIGHT,
         (unsigned)BENCH_UI_TILE_WIDTH,
         (unsigned)BENCH_UI_TILE_HEIGHT,
         (unsigned)BENCH_UI_RECT_COUNT,
         (unsigned)BENCH_UI_MUTATED_RECT);
  bench_ui_print_work("full", full_work);
  bench_ui_print_work("dirty", dirty_work);
  printf("ratio raster_x1000=%llu present_x1000=%llu work_x1000=%llu dirty_tiles=%u\n",
         (unsigned long long)((dirty_work.raster_bytes * BENCH_UI_RATIO_SCALE) /
                              full_work.raster_bytes),
         (unsigned long long)((dirty_work.present_bytes * BENCH_UI_RATIO_SCALE) /
                              full_work.present_bytes),
         (unsigned long long)((dirty_work.work_ticks * BENCH_UI_RATIO_SCALE) /
                              full_work.work_ticks),
         dirty_tiles.count);

  if (dirty_work.raster_bytes >= full_work.raster_bytes ||
      dirty_work.present_bytes >= full_work.present_bytes ||
      dirty_work.work_ticks >= full_work.work_ticks ||
      dirty_work.present_commands <= full_work.present_commands) {
    printf("ui-dirty-bench: dirty path did not reduce expected work\n");
    return 1;
  }
  return 0;
}
