#include "internal/efi_boot_internal.h"

static UINT64 er_boot_ble_wifi_node_nonce(const ErBootServicesReport* boot_report) {
  UINT64 nonce = ER_BOOT_BLE_WIFI_NODE_NONCE;
  UINT32 i;

  if (boot_report == 0 ||
      boot_report->boot_admission_present == 0u ||
      er_mem_any_nonzero(boot_report->boot_admission.record_hash.bytes, ER_HASH_LEN) == 0u) {
    return nonce;
  }

  nonce = 0u;
  for (i = 0u; i < sizeof(nonce); ++i) {
    nonce |= ((UINT64)boot_report->boot_admission.record_hash.bytes[i]) << (i * ER_BOOT_BYTE_BITS);
  }
  if (nonce == 0u) {
    return ER_BOOT_BLE_WIFI_NODE_NONCE;
  }
  return nonce;
}

static const char* er_boot_wifi_kind_label(UINT8 wifi_kind) {
  switch (wifi_kind) {
    case ER_BOOT_WIFI_KIND_NONE:
      return "none";
    case ER_BOOT_WIFI_KIND_OPEN_L2:
      return "open-l2";
    case ER_BOOT_WIFI_KIND_CYW43439_SDIO:
      return "cyw43439-sdio";
    default:
      return "invalid";
  }
}

static const char* er_boot_local_storage_kind_label(UINT8 storage_kind) {
  switch (storage_kind) {
    case ER_BOOT_LOCAL_STORAGE_KIND_NONE:
      return "none";
    case ER_BOOT_LOCAL_STORAGE_KIND_EFI_SYSTEM_PARTITION:
      return "efi-system-partition";
    case ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD:
      return "sd-card";
    default:
      return "invalid";
  }
}

static const char* er_boot_update_blocked_label(UINT8 reason) {
  switch (reason) {
    case ER_BOOT_UPDATE_READY:
      return "ready";
    case ER_BOOT_UPDATE_BLOCKED_NO_WIFI:
      return "no-wifi";
    case ER_BOOT_UPDATE_BLOCKED_NO_WRITABLE_STORAGE:
      return "no-writable-storage";
    case ER_BOOT_UPDATE_BLOCKED_NO_ARTIFACT_STORE:
      return "no-artifact-store";
    default:
      return "invalid";
  }
}

static const char* er_boot_bluetooth_kind_label(UINT8 bluetooth_kind) {
  switch (bluetooth_kind) {
    case ER_BOOT_BLUETOOTH_KIND_NONE:
      return "none";
    case ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART:
      return "cyw43439-hci-uart";
    default:
      return "invalid";
  }
}

static void er_boot_log_runtime_capabilities(const ErBootServicesReport* boot_report) {
  const ErBootRuntimeCapabilities* capabilities;

  if (boot_report == 0 ||
      boot_report->runtime_capabilities.abi_version !=
          ER_BOOT_RUNTIME_CAPABILITY_ABI_VERSION) {
    er_println("runtime capabilities: unavailable");
    return;
  }
  capabilities = &boot_report->runtime_capabilities;
  er_print("runtime wifi: kind=");
  er_print(er_boot_wifi_kind_label(capabilities->wifi_kind));
  er_print(" ready=");
  er_print_u64_dec((UINT64)capabilities->wifi_ready);
  er_print(" channel=");
  er_print_u64_dec((UINT64)capabilities->wifi_channel);
  er_println("");
  er_print("runtime bluetooth: kind=");
  er_print(er_boot_bluetooth_kind_label(capabilities->bluetooth_kind));
  er_print(" ready=");
  er_print_u64_dec((UINT64)capabilities->bluetooth_ready);
  er_println("");
  er_print("runtime storage: kind=");
  er_print(er_boot_local_storage_kind_label(capabilities->local_storage_kind));
  er_print(" writable=");
  er_print_u64_dec((UINT64)capabilities->local_storage_writable);
  er_print(" block_bytes=");
  er_print_u64_dec(capabilities->local_storage_block_bytes);
  er_print(" block_count=");
  er_print_u64_dec(capabilities->local_storage_block_count);
  er_println("");
  er_print("runtime update: ready=");
  er_print_u64_dec((UINT64)capabilities->update_ready);
  er_print(" reason=");
  er_print(er_boot_update_blocked_label(capabilities->update_blocked_reason));
  er_print(" artifact_capacity=");
  er_print_u64_dec(capabilities->update_artifact_capacity_bytes);
  er_println("");
}

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
  er_ui_scene_t previous_scene = {0};
  er_ui_runtime_state_t runtime = {0};
  er_ui_ledger_app_state_t ledger_state = {0};
  ErVirtioGpu gpu;
  ErVirtioGpuFramebuffer framebuffer;
  ErVirtioGpuDisplayInfo display_info;
  ErUiSurface surface;
  ErUiBootRenderContext render_context = {0};
  ErBleAdvEfi ble_adv;
  ErBleAdvPacket ble_packet;
  ErBleWifiRoleAdvert ble_wifi_role;
  UINT8 ble_payload[ER_BLE_ADV_PAYLOAD_BYTES];
  UINT8 tile_marks[ER_UI_BOOT_MAX_TILE_MARKS];
  UINT32 dirty_tile_ids[ER_UI_BOOT_MAX_DIRTY_TILES];
  ErUiSurfacePixelRect present_rects[ER_UI_BOOT_MAX_DIRTY_TILES];
  UINT64 ble_node_nonce;
  vr_font_face_t* font = 0;

  er_println("boot path: os");
  if (er_boot_services_runtime_entry_allowed(boot_report) == 0u) {
    ErBootServicesAction action = er_boot_services_decide_action(boot_report);
    er_print("boot services: runtime entry blocked action=");
    er_print(er_boot_services_action_label(action));
    er_println("");
    return;
  }
  er_boot_log_runtime_capabilities(boot_report);
  ble_node_nonce = er_boot_ble_wifi_node_nonce(boot_report);
  if (er_ble_wifi_role_advert_prepare(ER_BLE_WIFI_CAPABILITY_AP | ER_BLE_WIFI_CAPABILITY_STA,
                                      ER_BLE_WIFI_ROLE_NONE,
                                      ER_BOOT_BLE_WIFI_PRIORITY,
                                      ER_BOOT_BLE_WIFI_CHANNEL,
                                      ER_BOOT_BLE_WIFI_GROUP_ID,
                                      ble_node_nonce,
                                      &ble_wifi_role) == 0u ||
      er_ble_wifi_role_encode_payload(&ble_wifi_role, ble_payload) == 0u ||
      er_ble_adv_prepare_packet(ER_BLE_ADV_CHANNEL_ID,
                                ER_BOOT_BLE_ADV_SEQUENCE,
                                0u,
                                1u,
                                ble_payload,
                                ER_BLE_ADV_PAYLOAD_BYTES,
                                &ble_packet) == 0u ||
      er_ble_adv_efi_init(SystemTable, &ble_adv) == 0u ||
      er_ble_adv_efi_start_advertising(&ble_adv, &ble_packet) == 0u) {
    er_println("ble adv: unavailable");
  } else {
    er_println("ble adv: advertising");
  }
  if (er_virtio_gpu_init_first_pci(&gpu) == 0u) {
    er_println("ui renderer: virtio gpu unavailable");
    er_println("boot path: headless idle");
    er_idle_forever();
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
  er_print("ui renderer: virtio gpu initial scanout0 width=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.width);
  er_print(" height=");
  er_print_u64_dec((UINT64)display_info.scanouts[0].rect.height);
  er_println("");
  if (er_ui_boot_gpu_prepare_scanout(&gpu, &framebuffer, &surface, &mode) == 0u) {
    er_println("ui renderer: virtio gpu scanout failed");
    return;
  }
  er_print("ui renderer: framebuffer width=");
  er_print_u64_dec((UINT64)mode.width);
  er_print(" height=");
  er_print_u64_dec((UINT64)mode.height);
  er_println("");
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

  scene_budget = er_ui_scene_frame_budget();
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
  render_context.scene = &scene;
  render_context.previous_scene = &previous_scene;
  render_context.tile_marks = tile_marks;
  render_context.tile_mark_count = ER_UI_BOOT_MAX_TILE_MARKS;
  render_context.dirty_tile_ids = dirty_tile_ids;
  render_context.dirty_tile_capacity = ER_UI_BOOT_MAX_DIRTY_TILES;
  render_context.present_rects = present_rects;
  render_context.present_rect_capacity = ER_UI_BOOT_MAX_DIRTY_TILES;

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
  if (er_ui_scene_init_with_allocator(&previous_scene, theme.colors.bg, er_ui_boot_allocator()) != ER_UI_OK) {
    er_println("ui renderer: previous scene state failed");
    er_ui_scene_destroy(&scene);
    er_ui_runtime_state_destroy(&runtime);
    er_ui_ledger_app_state_destroy(&ledger_state);
    vr_font_face_destroy(font);
    return;
  }
  er_println("ui renderer: first frame deferred until boot services exit");
  er_println("boot services: exiting");
  er_gfx_console_set_enabled(0u);
  er_print_set_firmware_console_enabled(0u);
  if (er_exit_boot_services(ImageHandle, SystemTable) == 0u) {
    er_ui_scene_destroy(&previous_scene);
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
