#include "test_core_internal.h"

static void test_netlog_disabled_path(void) {
  check_int64("netlog starts disabled", er_netlog_ready(), 0);
  check_int64("netlog null init stays disabled", (er_netlog_init(0), er_netlog_ready()), 0);
  check_int64("netlog disabled write fails", er_netlog_write_bytes_wait((const UINT8*)"x", 1u, 0u), 0);
  check_int64("netlog disabled empty write fails", er_netlog_write_bytes_wait((const UINT8*)"", 0u, 0u), 0);
  er_netlog_write(0);
  er_netlog_write_text("queued\n");
  er_netlog_flush_text();
}

static void test_gfx_console_disabled_path(void) {
  er_gfx_console_set_enabled(0u);
  er_gfx_console_write("disabled path");
  er_gfx_console_write(0);
  er_gfx_console_init(0);
  er_gfx_console_write("still disabled");
  check_int64("gfx console disabled path reached", 1, 1);
}

static UINT64 g_print_test_firmware_byte_count;

static EFI_STATUS test_print_output_string(EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL* self,
                                           const CHAR16* text) {
  UINTN i;

  (void)self;
  if (text == 0) {
    return 1u;
  }
  for (i = 0u; text[i] != 0u; ++i) {
    ++g_print_test_firmware_byte_count;
  }
  return 0u;
}

static void test_print_routes_firmware_before_serial(void) {
  EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL conout;
  EFI_SYSTEM_TABLE st;

  er_mem_zero((UINT8*)&conout, (UINTN)sizeof(conout));
  er_mem_zero((UINT8*)&st, (UINTN)sizeof(st));
  g_print_test_firmware_byte_count = 0u;
  conout.OutputString = test_print_output_string;
  st.ConOut = &conout;

  er_print_test_reset(&st);
  er_print("firmware");
  check_uint64("print firmware route bytes", g_print_test_firmware_byte_count, 8u);
  check_uint64("print firmware route skips serial",
               er_print_test_serial_byte_count(), 0u);

  er_print_set_firmware_console_enabled(0u);
  er_print("serial");
  check_uint64("print serial route after firmware disabled",
               er_print_test_serial_byte_count(), 6u);
}

static void test_ui_surface_renderer_surface(void) {
  UINT32 pixels[24] = {0};
  ErUiSurface surface;
  ErUiSurfaceRenderStats stats;
  ErUiSurfaceFrameBudget frame_budget;
  ErUiSurfaceFrameBudgetViolation frame_violation;
  ErUiSurfaceMode mode;
  ErUiSurfaceBandwidthPlan bandwidth_plan;
  ErUiSurfaceTilePlan tile_plan;
  ErUiSurfaceMemoryPlan memory_plan;
  ErUiSurfaceMemoryBudget memory_budget;
  ErUiSurfaceMemoryBudgetViolation memory_violation;
  ErUiSurfaceDirtyTileList dirty_tiles;
  UINT8 tile_marks[4] = {9u, 9u, 9u, 9u};
  UINT32 tile_ids[4] = {0};
  er_ui_rect_t rects[3];
  er_ui_rect_t next_rects[1];
  er_ui_quad_t icon_quads[1];
  er_ui_scene_t scene;
  er_ui_scene_t next_scene;
  ErUiSurfacePixelRect tile_rect;
  ErUiSurfaceFrameState frame_state;
  UINT32 rgb_red = er_ui_surface_pack_rgb(ER_UI_SURFACE_PIXEL_RGBX, 255u, 0u, 0u);
  UINT32 bgr_red = er_ui_surface_pack_rgb(ER_UI_SURFACE_PIXEL_BGRX, 255u, 0u, 0u);
  UINTN i;

  check_pixel("ui surface pack rgb red", rgb_red, 0x00ff0000u);
  check_pixel("ui surface pack bgr red", bgr_red, 0x000000ffu);

  surface.pixels = pixels;
  surface.width = 3u;
  surface.height = 2u;
  surface.stride = 4u;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui surface valid", er_ui_surface_valid(&surface), 1);
  check_int64("ui surface clear", er_ui_surface_clear(&surface, er_ui_color_rgb_u8(1u, 2u, 3u)), 1);
  check_pixel("ui surface clear first", pixels[0], 0x00010203u);
  check_pixel("ui surface clear row end", pixels[2], 0x00010203u);
  check_pixel("ui surface clear stride untouched", pixels[3], 0u);
  check_pixel("ui surface clear second row", pixels[4], 0x00010203u);
  mode.width = 3u;
  mode.height = 2u;
  mode.stride = 4u;
  mode.refresh_hz = 120u;
  mode.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui surface mode valid", er_ui_surface_mode_valid(&mode), 1);
  check_int64("ui surface mode tile plan", er_ui_surface_tile_plan_from_mode(&mode, 2u, 1u, 4u, &tile_plan), 1);
  check_uint64("ui surface mode tile scanout bytes", tile_plan.scanout_bytes, 32u);
  check_int64("ui surface bandwidth plan", er_ui_surface_bandwidth_plan_from_mode(&mode, 4u, &bandwidth_plan), 1);
  check_uint64("ui surface bandwidth scanout", bandwidth_plan.scanout_bytes_per_second, 3840u);
  check_uint64("ui surface bandwidth full frame", bandwidth_plan.full_frame_bytes_per_second, 2880u);
  check_uint64("ui surface bandwidth budget", bandwidth_plan.budget_bytes_per_second, 11520u);
  check_int64("ui surface bandwidth reject zero overdraw", er_ui_surface_bandwidth_plan_from_mode(&mode, 0u, &bandwidth_plan), 0);
  check_uint64("ui surface bandwidth reject zeroes output", bandwidth_plan.budget_bytes_per_second, 0u);
  mode.refresh_hz = 0u;
  check_int64("ui surface reject zero refresh mode", er_ui_surface_mode_valid(&mode), 0);
  check_int64("ui surface reject invalid mode plan", er_ui_surface_tile_plan_from_mode(&mode, 2u, 1u, 4u, &tile_plan), 0);
  check_int64("ui surface tile plan", er_ui_surface_tile_plan(&surface, 2u, 1u, 4u, &tile_plan), 1);
  check_uint64("ui surface tile columns", tile_plan.columns, 2u);
  check_uint64("ui surface tile rows", tile_plan.rows, 2u);
  check_uint64("ui surface tile count", tile_plan.tile_count, 4u);
  check_uint64("ui surface tile scanout bytes", tile_plan.scanout_bytes, 32u);
  check_uint64("ui surface tile frame bytes", tile_plan.full_frame_bytes, 24u);
  check_uint64("ui surface tile max bytes", tile_plan.max_tile_bytes, 8u);
  check_uint64("ui surface tile state bytes", tile_plan.tile_state_bytes, 4u);
  check_uint64("ui surface tile dirty queue bytes", tile_plan.dirty_queue_bytes, 16u);
  check_int64("ui surface memory plan",
              er_ui_surface_memory_plan_from_tile_plan(&tile_plan, 1u, 64u, 128u, 256u, &memory_plan),
              1);
  check_uint64("ui surface memory scanout", memory_plan.scanout_bytes, 32u);
  check_uint64("ui surface memory backing", memory_plan.backing_bytes, 32u);
  check_uint64("ui surface memory tile state", memory_plan.tile_state_bytes, 4u);
  check_uint64("ui surface memory dirty queue", memory_plan.dirty_queue_bytes, 16u);
  check_uint64("ui surface memory commands", memory_plan.command_bytes, 64u);
  check_uint64("ui surface memory glyph cache", memory_plan.glyph_cache_bytes, 128u);
  check_uint64("ui surface memory surfaces", memory_plan.surface_bytes, 256u);
  check_uint64("ui surface memory total", memory_plan.total_bytes, 532u);
  memory_budget.scanout_bytes = 32u;
  memory_budget.backing_bytes = 32u;
  memory_budget.tile_state_bytes = 4u;
  memory_budget.dirty_queue_bytes = 16u;
  memory_budget.command_bytes = 64u;
  memory_budget.glyph_cache_bytes = 128u;
  memory_budget.surface_bytes = 256u;
  memory_budget.total_bytes = 532u;
  check_int64("ui surface memory fits exact budget", er_ui_surface_memory_plan_fits_budget(memory_plan, memory_budget), 1);
  memory_budget.glyph_cache_bytes = 127u;
  check_int64("ui surface memory first budget violation",
              er_ui_surface_memory_plan_first_budget_violation(memory_plan, memory_budget, &memory_violation),
              1);
  check_cstr("ui surface memory budget violation name", memory_violation.name, "glyph_cache_bytes");
  check_uint64("ui surface memory budget violation actual", memory_violation.actual, 128u);
  check_uint64("ui surface memory budget violation limit", memory_violation.limit, 127u);
  check_int64("ui surface memory rejects over budget", er_ui_surface_memory_plan_fits_budget(memory_plan, memory_budget), 0);
  check_int64("ui surface memory reject overflow",
              er_ui_surface_memory_plan_from_tile_plan(&tile_plan, 1u, 0xffffffffffffffffull, 0u, 0u, &memory_plan),
              0);
  check_uint64("ui surface memory overflow zeroes output", memory_plan.total_bytes, 0u);
  frame_budget = er_ui_surface_frame_budget_from_plan(&tile_plan, er_ui_scene_budget_native_interactive_frame(), 4u);
  check_uint64("ui surface derived budget pixels", frame_budget.pixels_written, 24u);
  check_uint64("ui surface derived budget bytes", frame_budget.bytes_written, 96u);
  check_uint64("ui surface derived budget rects", frame_budget.rects, 2000u);
  check_uint64("ui surface derived budget icons", frame_budget.icon_quads, 1200u);
  check_uint64("ui surface derived budget text", frame_budget.text_quads, 8000u);
  check_uint64("ui surface derived budget tiles", frame_budget.tiles_rendered, 4u);
  check_uint64("ui surface derived budget dirty", frame_budget.dirty_tiles_requested, 4u);
  check_uint64("ui surface derived budget clipped", frame_budget.clipped_primitives, 44800u);
  frame_budget = er_ui_surface_frame_budget_from_plan(&tile_plan, er_ui_scene_budget_native_interactive_frame(), 0u);
  check_uint64("ui surface reject zero overdraw budget", frame_budget.bytes_written, 0u);
  check_int64("ui surface tile rect", er_ui_surface_tile_rect(&tile_plan, 3u, &tile_rect), 1);
  check_uint64("ui surface tile rect x0", tile_rect.x0, 2u);
  check_uint64("ui surface tile rect y0", tile_rect.y0, 1u);
  check_uint64("ui surface tile rect x1", tile_rect.x1, 3u);
  check_uint64("ui surface tile rect y1", tile_rect.y1, 2u);
  dirty_tiles.tile_ids = tile_ids;
  dirty_tiles.capacity = 4u;
  dirty_tiles.count = 99u;
  dirty_tiles.overflowed = 1u;
  check_int64("ui surface dirty reset", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_uint64("ui surface dirty reset count", dirty_tiles.count, 0u);
  check_uint64("ui surface dirty reset mark", tile_marks[0], 0u);
  check_int64("ui surface dirty mark clipped rect",
              er_ui_surface_dirty_tiles_mark_rect(&tile_plan, -1.0f, 0.0f, 3.0f, 2.0f, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty count", dirty_tiles.count, 2u);
  check_uint64("ui surface dirty first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui surface dirty second", dirty_tiles.tile_ids[1], 2u);
  check_uint64("ui surface dirty duplicate count before", dirty_tiles.count, 2u);
  check_int64("ui surface dirty mark duplicate",
              er_ui_surface_dirty_tiles_mark_rect(&tile_plan, 0.0f, 0.0f, 1.0f, 1.0f, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty duplicate count after", dirty_tiles.count, 2u);

  rects[0] = er_ui_rect_fill(-1.0f, 0.0f, 3.0f, 2.0f, 0.0f, er_ui_color_rgb_u8(10u, 20u, 30u));
  scene.clear = er_ui_color_rgb_u8(0u, 0u, 0u);
  scene.rects = rects;
  scene.rect_count = 1u;
  scene.rect_capacity = 1u;
  scene.hits = 0;
  scene.hit_count = 0u;
  scene.hit_capacity = 0u;
  scene.drag_sources = 0;
  scene.drag_source_count = 0u;
  scene.drag_source_capacity = 0u;
  scene.drop_targets = 0;
  scene.drop_target_count = 0u;
  scene.drop_target_capacity = 0u;
  scene.transitions = 0;
  scene.transition_count = 0u;
  scene.transition_capacity = 0u;
  scene.clips = 0;
  scene.clip_count = 0u;
  scene.clip_capacity = 0u;
  scene.icon_quads = 0;
  scene.icon_quad_count = 0u;
  scene.icon_quad_capacity = 0u;
  scene.text_quads = 0;
  scene.text_quad_count = 0u;
  scene.text_quad_capacity = 0u;
  check_int64("ui surface render clipped fill", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface clipped fill x0", pixels[0], 0x000a141eu);
  check_pixel("ui surface clipped fill x1", pixels[1], 0x000a141eu);
  check_pixel("ui surface clipped fill x2 clear", pixels[2], 0u);
  check_int64("ui surface render stats", er_ui_surface_render_scene_with_font_stats(&surface, &scene, 0, &stats), 1);
  check_uint64("ui surface stats clear count", stats.clears, 1u);
  check_uint64("ui surface stats rect count", stats.rects, 1u);
  check_uint64("ui surface stats solid count", stats.solid_rects, 1u);
  check_uint64("ui surface stats pixels", stats.pixels_written, 10u);
  check_uint64("ui surface stats bytes", stats.bytes_written, 40u);
  frame_budget.pixels_written = 10u;
  frame_budget.bytes_written = 40u;
  frame_budget.blend_pixels = 0u;
  frame_budget.text_pixels = 0u;
  frame_budget.rects = 1u;
  frame_budget.icon_quads = 0u;
  frame_budget.text_quads = 0u;
  frame_budget.tiles_rendered = 0u;
  frame_budget.dirty_tiles_requested = 0u;
  frame_budget.clipped_primitives = 0u;
  frame_budget.rejected_primitives = 0u;
  check_int64("ui surface stats fit exact budget", er_ui_surface_render_stats_fits_budget(stats, frame_budget), 1);
  frame_budget.bytes_written = 39u;
  check_int64("ui surface stats first budget violation",
              er_ui_surface_render_stats_first_budget_violation(stats, frame_budget, &frame_violation),
              1);
  check_cstr("ui surface stats budget violation name", frame_violation.name, "bytes_written");
  check_uint64("ui surface stats budget violation actual", frame_violation.actual, 40u);
  check_uint64("ui surface stats budget violation limit", frame_violation.limit, 39u);
  check_int64("ui surface stats reject over budget", er_ui_surface_render_stats_fits_budget(stats, frame_budget), 0);
  icon_quads[0] = er_ui_quad_atlas(0.0f, 0.0f, 2.0f, 2.0f, 0.0f, 0.0f, 1.0f, 1.0f, 2u, er_ui_color_rgb_u8(200u, 200u, 200u));
  scene.icon_quads = icon_quads;
  scene.icon_quad_count = 1u;
  scene.icon_quad_capacity = 1u;
  check_int64("ui surface render icon stats", er_ui_surface_render_scene_with_font_stats(&surface, &scene, 0, &stats), 1);
  check_uint64("ui surface stats icon count", stats.icon_quads, 1u);
  scene.icon_quads = 0;
  scene.icon_quad_count = 0u;
  scene.icon_quad_capacity = 0u;
  {
    UINT32 icon_pixels[576] = {0};
    ErUiSurface icon_surface;
    er_ui_scene_t icon_scene;
    er_ui_quad_t tabler_icon[1];
    ErUiTablerIconRect search_rect;
    UINT64 visible_icon_pixels = 0u;

    icon_surface.pixels = icon_pixels;
    icon_surface.width = 24u;
    icon_surface.height = 24u;
    icon_surface.stride = 24u;
    icon_surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
    icon_scene = (er_ui_scene_t){0};
    icon_scene.clear = er_ui_color_rgb_u8(0u, 0u, 0u);
    tabler_icon[0] = er_ui_quad_atlas(0.0f, 0.0f, 24.0f, 24.0f, 0.0f, 0.0f, 1.0f, 1.0f,
                                      er_ui_icon_atlas_id(ER_UI_ICON_SEARCH), er_ui_color_rgb_u8(255u, 255u, 255u));
    icon_scene.icon_quads = tabler_icon;
    icon_scene.icon_quad_count = 1u;
    icon_scene.icon_quad_capacity = 1u;
    check_int64("ui surface tabler search rect", er_ui_tabler_icon_rect(ER_UI_ICON_SEARCH, &search_rect), 1);
    check_uint64("ui surface tabler search atlas x", search_rect.x, 120u);
    check_int64("ui surface render tabler icon", er_ui_surface_render_scene_with_font_stats(&icon_surface, &icon_scene, 0, &stats), 1);
    check_uint64("ui surface tabler icon stats", stats.icon_quads, 1u);
    for (i = 0u; i < 576u; ++i) {
      if (icon_pixels[i] != 0u) ++visible_icon_pixels;
    }
    check_int64("ui surface tabler icon draws real atlas pixels", visible_icon_pixels > 20u, 1);
    check_int64("ui surface tabler icon keeps transparent interior", visible_icon_pixels < 260u, 1);
  }
  check_int64("ui surface dirty reset for scene", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui surface dirty mark scene",
              er_ui_surface_dirty_tiles_mark_scene(&tile_plan, &scene, tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty scene count", dirty_tiles.count, 2u);
  check_uint64("ui surface dirty scene first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui surface dirty scene second", dirty_tiles.tile_ids[1], 2u);
  er_ui_surface_frame_state_reset(&frame_state);
  check_int64("ui surface frame first dirty",
              er_ui_surface_frame_dirty_tiles(&frame_state, &tile_plan, 0, &scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface frame first count", dirty_tiles.count, 4u);
  er_ui_surface_frame_state_commit(&frame_state);
  next_rects[0] = er_ui_rect_fill(2.0f, 1.0f, 1.0f, 1.0f, 0.0f, er_ui_color_rgb_u8(40u, 50u, 60u));
  next_scene = scene;
  next_scene.rects = next_rects;
  check_int64("ui surface dirty reset for diff", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui surface dirty mark scene diff",
              er_ui_surface_dirty_tiles_mark_scene_diff(&tile_plan, &scene, &next_scene,
                                                    tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty diff count", dirty_tiles.count, 3u);
  check_uint64("ui surface dirty diff old first", dirty_tiles.tile_ids[0], 0u);
  check_uint64("ui surface dirty diff old second", dirty_tiles.tile_ids[1], 2u);
  check_uint64("ui surface dirty diff new", dirty_tiles.tile_ids[2], 3u);
  check_int64("ui surface frame next dirty",
              er_ui_surface_frame_dirty_tiles(&frame_state, &tile_plan, &scene, &next_scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface frame next count", dirty_tiles.count, 3u);
  check_int64("ui surface frame same dirty",
              er_ui_surface_frame_dirty_tiles(&frame_state, &tile_plan, &scene, &scene,
                                          tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface frame same count", dirty_tiles.count, 0u);
  check_int64("ui surface render empty dirty tile list",
              er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              1);
  check_uint64("ui surface empty dirty requested", stats.dirty_tiles_requested, 0u);
  check_uint64("ui surface empty dirty rendered", stats.tiles_rendered, 0u);
  check_uint64("ui surface empty dirty bytes", stats.bytes_written, 0u);
  next_scene.clear = er_ui_color_rgb_u8(1u, 1u, 1u);
  check_int64("ui surface dirty reset for clear diff", er_ui_surface_dirty_tiles_reset(&tile_plan, tile_marks, 4u, &dirty_tiles), 1);
  check_int64("ui surface dirty mark clear diff",
              er_ui_surface_dirty_tiles_mark_scene_diff(&tile_plan, &scene, &next_scene,
                                                    tile_marks, 4u, &dirty_tiles),
              1);
  check_uint64("ui surface dirty clear diff count", dirty_tiles.count, 4u);

  rects[0] = er_ui_rect_fill(0.0f, 0.0f, 1.0f, 1.0f, 0.0f, er_ui_color_rgba_u8(255u, 0u, 0u, 128u));
  check_int64("ui surface render alpha fill", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface alpha over clear", pixels[0], 0x00800000u);

  surface.width = 4u;
  surface.height = 4u;
  surface.stride = 4u;
  rects[0] = er_ui_rect_border(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, er_ui_color_rgb_u8(0u, 255u, 0u));
  check_int64("ui surface render border", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface border top", pixels[1], 0x0000ff00u);
  check_pixel("ui surface border left", pixels[4], 0x0000ff00u);
  check_pixel("ui surface border center clear", pixels[5], 0u);
  check_pixel("ui surface border right", pixels[7], 0x0000ff00u);
  check_pixel("ui surface border bottom", pixels[14], 0x0000ff00u);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui surface tile plan 4x4", er_ui_surface_tile_plan(&surface, 2u, 2u, 4u, &tile_plan), 1);
  rects[0] = er_ui_rect_fill(0.0f, 0.0f, 4.0f, 4.0f, 0.0f, er_ui_color_rgb_u8(255u, 0u, 0u));
  check_int64("ui surface render one tile",
              er_ui_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 3u, &stats),
              1);
  check_pixel("ui surface tile outside top left", pixels[0], 0x00abcdefu);
  check_pixel("ui surface tile outside top right", pixels[3], 0x00abcdefu);
  check_pixel("ui surface tile inside bottom right a", pixels[10], 0x00ff0000u);
  check_pixel("ui surface tile inside bottom right b", pixels[15], 0x00ff0000u);
  check_uint64("ui surface tile render clears", stats.clears, 1u);
  check_uint64("ui surface tile render pixels", stats.pixels_written, 8u);
  check_uint64("ui surface tile render count", stats.tiles_rendered, 1u);
  check_uint64("ui surface tile render clipped", stats.clipped_primitives, 1u);
  check_uint64("ui surface tile render rejected", stats.rejected_primitives, 0u);
  tile_ids[0] = 0u;
  tile_ids[1] = 3u;
  dirty_tiles.tile_ids = tile_ids;
  dirty_tiles.capacity = 4u;
  dirty_tiles.count = 2u;
  dirty_tiles.overflowed = 0u;
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui surface render dirty tile list",
              er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              1);
  check_pixel("ui surface dirty list top left", pixels[0], 0x00ff0000u);
  check_pixel("ui surface dirty list top right untouched", pixels[3], 0x00abcdefu);
  check_pixel("ui surface dirty list bottom left untouched", pixels[8], 0x00abcdefu);
  check_pixel("ui surface dirty list bottom right", pixels[15], 0x00ff0000u);
  check_uint64("ui surface dirty list clears", stats.clears, 2u);
  check_uint64("ui surface dirty list pixels", stats.pixels_written, 16u);
  check_uint64("ui surface dirty list tiles", stats.tiles_rendered, 2u);
  check_uint64("ui surface dirty list requested", stats.dirty_tiles_requested, 2u);
  check_uint64("ui surface dirty list clipped", stats.clipped_primitives, 2u);
  dirty_tiles.overflowed = 1u;
  check_int64("ui surface reject overflowed dirty list",
              er_ui_surface_render_scene_dirty_tiles_with_font_stats(&surface, &scene, 0,
                                                                         &tile_plan, &dirty_tiles, &stats),
              0);
  check_uint64("ui surface reject overflowed dirty stats", stats.pixels_written, 0u);
  dirty_tiles.overflowed = 0u;
  tile_plan.width = 3u;
  check_int64("ui surface reject mismatched tile plan",
              er_ui_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 3u, &stats),
              0);
  check_uint64("ui surface reject tile stats zero", stats.pixels_written, 0u);

  surface.width = 3u;
  surface.height = 1u;
  surface.stride = 3u;
  rects[0] = er_ui_rect_linear_gradient(0.0f, 0.0f, 3.0f, 1.0f, 0.0f,
                                        er_ui_color_rgb_u8(255u, 0u, 0u),
                                        er_ui_color_rgb_u8(0u, 0u, 255u));
  check_int64("ui surface render gradient", er_ui_surface_render_scene(&surface, &scene), 1);
  check_pixel("ui surface gradient left", pixels[0], 0x00ff0000u);
  check_pixel("ui surface gradient middle", pixels[1], 0x00800080u);
  check_pixel("ui surface gradient right", pixels[2], 0x000000ffu);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    pixels[i] = 0x00abcdefu;
  }
  check_int64("ui surface tile plan 3x1", er_ui_surface_tile_plan(&surface, 1u, 1u, 3u, &tile_plan), 1);
  check_int64("ui surface render gradient tile",
              er_ui_surface_render_scene_tile_with_font_stats(&surface, &scene, 0, &tile_plan, 1u, &stats),
              1);
  check_pixel("ui surface gradient tile outside left", pixels[0], 0x00abcdefu);
  check_pixel("ui surface gradient tile middle", pixels[1], 0x00800080u);
  check_pixel("ui surface gradient tile outside right", pixels[2], 0x00abcdefu);
  check_uint64("ui surface gradient tile clipped", stats.clipped_primitives, 1u);

  {
    UINT8 atlas_bytes[3] = {80u, 128u, 180u};
    ErUiAlphaAtlas atlas;
    er_ui_quad_t text_quads[1];

    atlas.pixels = atlas_bytes;
    atlas.width = 3u;
    atlas.height = 1u;
    atlas.bytes_per_pixel = 1u;
    text_quads[0] = er_ui_quad_atlas(0.0f, 0.0f, 3.0f, 1.0f, 0.0f, 0.0f, 1.0f, 1.0f, 0u,
                                     er_ui_color_rgb_u8(255u, 255u, 255u));
    scene.rect_count = 0u;
    scene.text_quads = text_quads;
    scene.text_quad_count = 1u;
    scene.text_quad_capacity = 1u;
    check_int64("ui surface render alpha atlas", er_ui_surface_render_scene_with_atlas(&surface, &scene, &atlas), 1);
    check_pixel("ui surface alpha low", pixels[0], 0x00505050u);
    check_pixel("ui surface alpha middle", pixels[1], 0x00808080u);
    check_pixel("ui surface alpha high", pixels[2], 0x00b4b4b4u);
    scene.text_quads = 0;
    scene.text_quad_count = 0u;
    scene.text_quad_capacity = 0u;
  }

  surface.pixels = 0;
  check_int64("ui surface invalid surface", er_ui_surface_valid(&surface), 0);
  check_int64("ui surface reject invalid surface", er_ui_surface_render_scene(&surface, &scene), 0);
  check_int64("ui surface reject invalid tile plan", er_ui_surface_tile_plan(&surface, 128u, 64u, 256u, &tile_plan), 0);
}

static void test_ui_surface_renderer_4k_tile_plan(void) {
  UINT32 pixel = 0u;
  ErUiSurface surface;
  ErUiSurfaceMode mode;
  ErUiSurfaceTilePlan plan;
  ErUiSurfaceBandwidthPlan bandwidth;
  ErUiSurfaceMemoryPlan memory;
  ErUiSurfaceFrameBudget budget;

  surface.pixels = &pixel;
  surface.width = 3840u;
  surface.height = 2160u;
  surface.stride = 3840u;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  mode.width = 3840u;
  mode.height = 2160u;
  mode.stride = 3840u;
  mode.refresh_hz = 120u;
  mode.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui surface 4k mode tile plan", er_ui_surface_tile_plan_from_mode(&mode, 128u, 64u, 256u, &plan), 1);
  check_uint64("ui surface 4k mode frame bytes", plan.full_frame_bytes, 33177600u);
  check_int64("ui surface 4k bandwidth plan", er_ui_surface_bandwidth_plan_from_mode(&mode, 4u, &bandwidth), 1);
  check_uint64("ui surface 4k bandwidth scanout", bandwidth.scanout_bytes_per_second, 3981312000u);
  check_uint64("ui surface 4k bandwidth full frame", bandwidth.full_frame_bytes_per_second, 3981312000u);
  check_uint64("ui surface 4k bandwidth budget", bandwidth.budget_bytes_per_second, 15925248000u);
  check_int64("ui surface 4k tile plan", er_ui_surface_tile_plan(&surface, 128u, 64u, 256u, &plan), 1);
  check_uint64("ui surface 4k tile columns", plan.columns, 30u);
  check_uint64("ui surface 4k tile rows", plan.rows, 34u);
  check_uint64("ui surface 4k tile count", plan.tile_count, 1020u);
  check_uint64("ui surface 4k frame bytes", plan.full_frame_bytes, 33177600u);
  check_uint64("ui surface 4k scanout bytes", plan.scanout_bytes, 33177600u);
  check_uint64("ui surface 4k max tile bytes", plan.max_tile_bytes, 32768u);
  check_uint64("ui surface 4k tile state bytes", plan.tile_state_bytes, 1020u);
  check_uint64("ui surface 4k dirty queue bytes", plan.dirty_queue_bytes, 1024u);
  check_int64("ui surface 4k memory plan",
              er_ui_surface_memory_plan_from_tile_plan(&plan, 1u, 262144u, 1048576u, 0u, &memory),
              1);
  check_uint64("ui surface 4k memory scanout", memory.scanout_bytes, 33177600u);
  check_uint64("ui surface 4k memory backing", memory.backing_bytes, 33177600u);
  check_uint64("ui surface 4k memory tile state", memory.tile_state_bytes, 1020u);
  check_uint64("ui surface 4k memory dirty queue", memory.dirty_queue_bytes, 1024u);
  check_uint64("ui surface 4k memory total", memory.total_bytes, 67667964u);
  budget = er_ui_surface_frame_budget_from_plan(&plan, er_ui_scene_budget_native_interactive_frame(), 4u);
  check_uint64("ui surface 4k budget pixels", budget.pixels_written, 33177600u);
  check_uint64("ui surface 4k budget bytes", budget.bytes_written, 132710400u);
  check_uint64("ui surface 4k budget text pixels", budget.text_pixels, 8294400u);
  check_uint64("ui surface 4k budget tiles", budget.tiles_rendered, 1020u);
  check_uint64("ui surface 4k budget dirty", budget.dirty_tiles_requested, 256u);
  check_uint64("ui surface 4k budget clipped", budget.clipped_primitives, 11424000u);
  check_int64("ui surface reject zero tile width", er_ui_surface_tile_plan(&surface, 0u, 64u, 256u, &plan), 0);
  check_int64("ui surface reject zero dirty budget", er_ui_surface_tile_plan(&surface, 128u, 64u, 0u, &plan), 0);
}

static void test_ui_surface_renderer_varfont_text(void) {
  vr_font_config_t cfg;
  vr_font_face_t* font = 0;
  vr_font_atlas_view_t atlas;
  er_ui_scene_t scene;
  UINT32 codepoints[5] = {'H', 'e', 'l', 'l', 'o'};
  UINT32 pixels[512u * 160u] = {0};
  ErUiSurface surface;
  UINTN i;
  UINTN lit_pixels = 0;

  cfg.px_size = 56.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = 2u;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = test_vr_allocator();
  cfg.gl.user = 0;
  cfg.gl.create_texture = 0;
  cfg.gl.update_texture = 0;
  cfg.gl.destroy_texture = 0;

  check_int64("ui text font create",
              vr_font_face_create_from_memory(&font, g_er_font_geist_ttf, ER_FONT_GEIST_TTF_SIZE, &cfg),
              VR_OK);
  if (font == 0) {
    return;
  }

  check_int64("ui text scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u), test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui text push",
              er_ui_scene_push_varfont_text(&scene, font, codepoints, 5u, 20.0f, 90.0f, er_ui_color_rgb_u8(255u, 255u, 255u)),
              ER_UI_OK);
  check_int64("ui text emits quads", scene.text_quad_count > 0u, 1);
  check_int64("ui text atlas exists", vr_font_atlas_count(font) > 0u, 1);
  check_int64("ui text atlas view", vr_font_atlas_view(font, 0u, &atlas), VR_OK);
  check_int64("ui text atlas alpha format", atlas.format, VR_FONT_ATLAS_FORMAT_ALPHA8);
  check_int64("ui text atlas bytes", atlas.bytes_per_pixel, 1);

  surface.pixels = pixels;
  surface.width = 512u;
  surface.height = 160u;
  surface.stride = 512u;
  surface.pixel_format = ER_UI_SURFACE_PIXEL_RGBX;
  check_int64("ui text render", er_ui_surface_render_scene_with_font(&surface, &scene, font), 1);
  for (i = 0u; i < (UINTN)(sizeof(pixels) / sizeof(pixels[0])); ++i) {
    if (pixels[i] != 0u) {
      ++lit_pixels;
    }
  }
  check_int64("ui text render lit pixels", lit_pixels > 0u, 1);

  er_ui_scene_destroy(&scene);
  vr_font_face_destroy(font);
}

static void test_ui_ledger_app_switching(void) {
  er_ui_ledger_app_state_t apps;
  er_ui_runtime_state_t runtime;
  er_ui_scene_t scene;
  er_ui_scene_stats_t stats;
  er_ui_bounds_t focused;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  vr_font_config_t cfg;
  vr_font_face_t* font = 0;
  er_ui_action_t down;
  er_ui_action_t up;
  bool changed = false;

  cfg.px_size = 24.0f;
  cfg.atlas_width = 512u;
  cfg.atlas_height = 512u;
  cfg.atlas_pad = 2u;
  cfg.atlas_format = VR_FONT_ATLAS_FORMAT_ALPHA8;
  cfg.allocator = test_vr_allocator();
  cfg.gl.user = 0;
  cfg.gl.create_texture = 0;
  cfg.gl.update_texture = 0;
  cfg.gl.destroy_texture = 0;

  check_int64("ui ledger font create",
              vr_font_face_create_from_memory(&font, g_er_font_geist_ttf, ER_FONT_GEIST_TTF_SIZE, &cfg),
              VR_OK);
  if (font == 0) {
    return;
  }

  check_int64("ui ledger state init", er_ui_ledger_app_state_init(&apps, test_ui_allocator()), ER_UI_OK);
  check_uint64("ui ledger app count", er_ui_workspace_surface_count(&apps.shell), 3u);
  check_uint64("ui ledger initial focus", er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_LEDGER_APP_LEDGER_ID);
  check_int64("ui ledger focused bounds",
              er_ui_workspace_focused_surface_bounds(&apps.shell, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), &focused),
              1);
  check_int64("ui ledger focused bounds positive", focused.w > 0.0f && focused.h > 0.0f, 1);

  check_int64("ui ledger runtime init", er_ui_runtime_state_init_with_allocator(&runtime, test_ui_allocator()), ER_UI_OK);
  check_int64("ui ledger scene init",
              er_ui_scene_init_with_allocator(&scene, theme.colors.bg, test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui ledger emit",
              er_ui_ledger_app_emit_scene(&apps, &scene, font, er_ui_bounds(0.0f, 0.0f, 1600.0f, 900.0f), theme),
              ER_UI_OK);
  stats = er_ui_scene_stats(&scene);
  check_int64("ui ledger emits rects", stats.rects > 0u, 1);
  check_uint64("ui ledger emits hits", stats.hits, 21u);
  check_int64("ui ledger emits text", stats.text_quads > 0u, 1);

  down = er_ui_runtime_pointer_down(&runtime, &scene, 40.0f, 138.0f);
  check_int64("ui ledger nav down focus", down.kind, ER_UI_ACTION_FOCUSED);
  up = er_ui_runtime_pointer_up(&runtime, &scene, 40.0f, 138.0f);
  check_int64("ui ledger nav up select", up.kind, ER_UI_ACTION_TAB_SELECTED);
  check_int64("ui ledger apply payments nav", er_ui_ledger_app_apply_action(&apps, up, &changed), ER_UI_OK);
  check_int64("ui ledger tab changed", changed, 1);
  check_uint64("ui ledger payments focus", er_ui_workspace_focused_surface_id(&apps.shell), ER_UI_LEDGER_APP_PAYMENTS_ID);

  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_ledger_app_state_destroy(&apps);
  vr_font_face_destroy(font);
}
