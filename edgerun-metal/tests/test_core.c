#include "test_core_internal.h"

ErWasmHostCalls g_host_calls = {0};

#include "test_core_basic.c"
#include "test_core_pci_mmio.c"
#include "test_core_rtw89.c"
#include "test_core_mt7922.c"
#include "test_core_firmware_loader.c"
#include "test_core_virtio.c"
#include "test_core_platform.c"
#include "test_core_wasm_imports.c"
#include "test_core_wasm_apps.c"
#include "test_core_app_routes.c"
#include "test_core_device_routes.c"
#include "test_core_seal.c"
#include "test_core_boot_admission_record.c"
#include "test_core_boot_efi_vars.c"
#include "test_core_boot_config.c"
#include "test_core_boot_services.c"
#include "test_core_ble_adv.c"
#include "test_core_boot_erwire.c"
#include "test_core_ui_surface.c"
#include "test_core_input.c"

int main(void) {
  test_mem_helpers();
  test_ui_boot_allocator_reuses_freed_blocks();
  test_blake3();
  test_bar_decode();
  test_pci_config_addressing();
  test_acpi_tables();
  test_tpm_crb_direct_transport();
  test_pci_device_classification();
  test_rtw89_pci_prepare();
  test_mt7922_pci_prepare();
  test_firmware_loader();
  test_mmio_handles();
  test_bus_addresses();
  test_driver_event_queue();
  test_driver_policy();
  test_virtio_mmio_transport();
  test_virtio_modern_pci_transport_registers();
  test_virtio_split_queue();
  test_virtio_blk_mmio();
  test_virtio_net_mmio();
  test_virtio_gpu_mmio();
  test_net_frame_builders();
  test_native_eth_endpoint();
  test_wasm_log_imports();
  test_wasm_pci_imports();
  test_wasm_mmio_imports();
  test_wasm_bus_exec_import();
  test_wasm_public_region_imports();
  test_relay_packets();
  test_wasm_relay_imports();
  test_wasm_ui_command_stats_records();
  test_wasm_ui_emit_import();
  test_wasm_c_generated_hostcall_modules();
  test_epoch_clock_rollover();
  test_ui_wasm_app_runner();
  test_ui_wasm_app_multiple_runtimes();
  test_ui_boot_apply_input_routes_to_active_wasm_app();
  test_ui_boot_package_loads_from_endpoint_storage();
  test_vfs_object_packets();
  test_storage_endpoint_object_store();
  test_storage_endpoint_object_cache();
  test_storage_endpoint_sealed_relay_capture();
  test_app_identity_routes();
  test_device_relay_identity();
  test_sealed_content_object_format();
  test_sealed_content_key_wrap();
  test_boot_admission_record();
  test_boot_efi_vars();
  test_boot_config_and_seal_strategy();
  test_boot_services_boundary();
  test_ble_adv();
  test_work_admitted_relay_route();
  test_boot_profiles();
  test_hw_relay_endpoints();
  test_erwire_native_eth_sink();
  test_erwire_parse_and_native_poll();
  test_native_boot_erwire_eth_sink();
  test_native_boot_endpoint_intent();
  test_native_boot_storage_endpoint_intent();
  test_os_native_relay_dispatch();
  test_netlog_disabled_path();
  test_gfx_console_disabled_path();
  test_print_routes_firmware_before_serial();
  test_ui_surface_renderer_surface();
  test_ui_surface_renderer_4k_tile_plan();
  test_ui_frame_timing_4k120_budget();
  test_ui_surface_renderer_varfont_text();
  test_ui_ledger_app_switching();
  test_ps2_keyboard_set1_decoder();

  if (g_failed != 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_failed, g_total);
    return 1;
  }

  printf("OK %d checks passed\n", g_total);
  return 0;
}
