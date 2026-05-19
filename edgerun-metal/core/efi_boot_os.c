#include "efi_boot_internal.h"

void er_run_os_path(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE* SystemTable,
                    const ErBootServicesReport* boot_report) {
  er_ui_scene_budget_t scene_budget;
  ErUiSurfaceMode mode;
  ErUiSurfaceFrameBudget frame_budget;
  ErUiSurfaceTilePlan tile_plan;
  ErUiSurfaceMemoryPlan memory_plan;
  ErUiSurfaceMemoryBudget memory_budget;
  ErUiSurfaceMemoryBudgetViolation memory_violation;
  er_ui_resolved_theme_t theme = er_ui_resolved_theme(
    ER_UI_STYLE_AUTHORITY_USER,
    (er_ui_style_preset_t){ER_UI_COLOR_SCHEME_DARK, ER_UI_ACCENT_NEUTRAL, ER_UI_RADIUS_DEFAULT});
  er_ui_scene_t scene = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_ledger_app_state_t ledger_state = {0};
  ErUiBootAppContext apps[ER_UI_BOOT_APP_COUNT];
  ErVirtioGpu gpu;
  ErVirtioGpuFramebuffer framebuffer;
  ErVirtioGpuDisplayInfo display_info;
  ErUiSurface surface;
  ErUiBootRenderContext render_context = {0};
  ErNativeBootState native_relay;
  ErBleAdvEfi ble_adv;
  ErBleAdvPacket ble_packet;
  vr_font_face_t* font = 0;
  static const UINT8 ble_payload[] = {
    'e', 'd', 'g', 'e', 'r', 'u', 'n', '-', 'e', 'f', 'i', '-', 'b', 'l', 'e'
  };

  er_mem_zero((UINT8*)apps, (UINTN)sizeof(apps));
  er_mem_zero((UINT8*)&native_relay, (UINTN)sizeof(native_relay));

  er_println("boot path: os");
  if (er_boot_services_runtime_entry_allowed(boot_report) == 0u) {
    ErBootServicesAction action = er_boot_services_decide_action(boot_report);
    er_print("boot services: runtime entry blocked action=");
    er_print(er_boot_services_action_label(action));
    er_println("");
    return;
  }
  if (er_ble_adv_prepare_packet(ER_BLE_ADV_CHANNEL_ID,
                                ER_BOOT_BLE_ADV_SEQUENCE,
                                0u,
                                1u,
                                ble_payload,
                                (UINT8)sizeof(ble_payload),
                                &ble_packet) == 0u ||
      er_ble_adv_efi_init(SystemTable, &ble_adv) == 0u ||
      er_ble_adv_efi_start_advertising(&ble_adv, &ble_packet) == 0u) {
    er_println("ble adv: unavailable");
    return;
  }
  er_println("ble adv: advertising");
  if (er_virtio_gpu_init_first_pci(&gpu) == 0u) {
    er_println("ui renderer: virtio gpu unavailable");
    return;
  }
  if (er_virtio_gpu_submit_get_display_info(&gpu) == 0u) {
    er_println("ui renderer: virtio gpu display submit failed");
    return;
  }
  er_mem_zero((UINT8*)&display_info, (UINTN)sizeof(display_info));
  if (er_virtio_gpu_wait_display_info(&gpu, &display_info) == 0u) {
    er_println("ui renderer: virtio gpu display poll failed");
    return;
  }
  er_print("ui renderer: virtio gpu scanout0 width=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.width);
  er_print(" height=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.height);
  er_println("");
  if (er_ui_boot_gpu_prepare_scanout(&gpu, &framebuffer, &surface, &mode) == 0u) {
    er_println("ui renderer: virtio gpu scanout failed");
    return;
  }
  if (er_ui_surface_tile_plan(&surface, ER_UI_BOOT_TILE_WIDTH, ER_UI_BOOT_TILE_HEIGHT,
                              ER_UI_BOOT_MAX_DIRTY_TILES, &tile_plan) == 0u ||
      tile_plan.tile_count > ER_UI_BOOT_MAX_TILE_MARKS) {
    er_println("ui renderer: tile plan failed");
    return;
  }
  er_println("ui renderer: init font");
  if (er_ui_boot_create_font(mode.height, &font) == 0u) {
    er_println("ui renderer: font failed");
    return;
  }

  scene_budget = er_ui_scene_budget_native_interactive_frame();
  if (er_ui_surface_memory_plan_from_tile_plan(&tile_plan, ER_UI_BOOT_BACKING_BUFFERS,
                                           ER_UI_BOOT_COMMAND_BYTES, ER_UI_BOOT_GLYPH_CACHE_BYTES,
                                           ER_UI_BOOT_SURFACE_BYTES, &memory_plan) == 0u) {
    er_println("ui renderer: memory plan failed");
    vr_font_face_destroy(font);
    return;
  }
  memory_budget.scanout_bytes = memory_plan.scanout_bytes;
  memory_budget.backing_bytes = memory_plan.backing_bytes;
  memory_budget.tile_state_bytes = memory_plan.tile_state_bytes;
  memory_budget.dirty_queue_bytes = memory_plan.dirty_queue_bytes;
  memory_budget.command_bytes = ER_UI_BOOT_COMMAND_BYTES;
  memory_budget.glyph_cache_bytes = ER_UI_BOOT_GLYPH_CACHE_BYTES;
  memory_budget.surface_bytes = ER_UI_BOOT_SURFACE_BYTES;
  memory_budget.total_bytes = ER_UI_BOOT_MEMORY_BUDGET_BYTES;
  if (er_ui_surface_memory_plan_first_budget_violation(memory_plan, memory_budget, &memory_violation) != 0u) {
    er_print("ui renderer: memory budget exceeded ");
    er_print(memory_violation.name);
    er_print(" actual=");
    er_print_u64_dec(memory_violation.actual);
    er_print(" limit=");
    er_print_u64_dec(memory_violation.limit);
    er_println("");
    vr_font_face_destroy(font);
    return;
  }
  frame_budget = er_ui_surface_frame_budget_from_plan(&tile_plan, scene_budget, ER_UI_BOOT_RENDER_OVERDRAW_BUDGET);
  render_context.font = font;
  render_context.mode = mode;
  render_context.surface = &surface;
  render_context.gpu = &gpu;
  render_context.framebuffer = &framebuffer;
  render_context.tile_plan = &tile_plan;
  render_context.memory_plan = memory_plan;
  render_context.scene_budget = scene_budget;
  render_context.frame_budget = frame_budget;
  render_context.theme = theme;
  render_context.apps = apps;
  render_context.app_count = ER_UI_BOOT_APP_COUNT;
  render_context.active_app = 0u;
  render_context.scene = &scene;

  if (er_ui_ledger_app_state_init(&ledger_state, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: ledger app state failed");
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_runtime_state_init_with_allocator(&runtime, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: runtime state failed");
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_scene_init_with_allocator(&scene, theme.colors.bg, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: scene state failed");
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_boot_prepare_app_contexts(apps, ER_UI_BOOT_APP_COUNT, &scene_budget,
                                      theme.colors.bg) == 0u) {
    er_println("ui renderer: app contexts failed");
    er_ui_scene_destroy(&scene);
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  if (er_native_boot_configure_pci_erwire_eth_sink(&native_relay) == 0u) {
    er_println("relay ingress: virtio net unavailable");
    er_ui_boot_destroy_app_contexts(apps, ER_UI_BOOT_APP_COUNT);
    er_ui_scene_destroy(&scene);
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  render_context.native_relay = &native_relay;

  er_println("ui renderer: first frame deferred until boot services exit");
  er_println("boot services: exiting");
  er_gfx_console_set_enabled(0u);
  er_print_set_firmware_console_enabled(0u);
  if (er_exit_boot_services(ImageHandle, SystemTable) == 0u) {
    er_ui_boot_destroy_app_contexts(apps, ER_UI_BOOT_APP_COUNT);
    er_ui_scene_destroy(&scene);
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  if (er_ui_boot_render_scene(&scene, &ledger_state, &render_context) == 0u) {
    er_idle_forever();
  }
  er_ui_boot_input_loop(&ledger_state, &runtime, &scene, &render_context);
}
