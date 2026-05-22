#include "test_core_internal.h"

ErWasmHostCalls g_host_calls = {0};

#include "test_core_basic.c"
#include "test_core_pci_mmio.c"
#include "test_core_rtw89.c"
#include "test_core_mt7922.c"
#include "test_core_iwlwifi.c"
#include "test_core_firmware_loader.c"
#include "test_core_virtio.c"
#include "test_core_platform.c"
#include "test_core_wasm_imports.c"
#include "test_core_storage_medium.c"
#include "test_core_node_id.c"
#include "test_core_device_routes.c"
#include "test_core_jurisdiction.c"
#include "test_core_seal.c"
#include "test_core_boot_admission_record.c"
#include "test_core_boot_efi_vars.c"
#include "test_core_boot_config.c"
#include "test_core_boot_services.c"
#include "test_core_pi_zero2w.c"
#include "test_core_pi_zero_w_v1_1.c"
#include "test_core_pi_zero_w_v1_1_boot_log.c"
#include "test_core_pi_zero_w_v1_1_ota.c"
#include "test_core_pi_usb_control.c"
#include "test_core_ieee80211_ap.c"
#include "test_core_cyw43438_d11.c"
#include "test_core_cyw43438_sdpcm.c"
#include "test_core_cyw43438_owned_firmware.c"
#include "test_core_st7789.c"
#include "test_core_node_control.c"
#include "test_core_ble_adv.c"
#include "test_core_network.c"
#include "test_core_disk_analyzer.c"
#include "test_core_boot_erwire.c"
#include "test_core_ui_surface.c"
#include "test_core_input.c"
#include "test_core_tls_tpm.c"
#include "test_core_tls.c"

int main(void) {
  test_mem_helpers();
  test_ui_boot_allocator_reuses_freed_blocks();
  test_blake3();
  test_bar_decode();
  test_pci_config_addressing();
  test_acpi_tables();
  test_tpm_crb_direct_transport();
  test_tls_tpm_handshake_core();
  test_tls_tpm_adapter();
  test_pci_device_classification();
  test_rtw89_pci_prepare();
  test_mt7922_pci_prepare();
  test_iwlwifi_pci_prepare();
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
  test_storage_medium_init_record();
  test_node_id_sources();
  test_device_relay_identity();
  test_ephemeral_node_identity();
  test_jurisdiction_policy_and_node_instances();
  test_sealed_content_record_format();
  test_sealed_content_key_wrap();
  test_boot_admission_record();
  test_boot_efi_vars();
  test_boot_config_and_seal_strategy();
  test_boot_services_boundary();
  test_pi_zero2w_bringup_boundary();
  test_pi_zero_w_v1_1_bringup_boundary();
  test_pi_zero_w_v1_1_boot_log();
  test_pi_zero_w_v1_1_ota_receiver();
  test_pi_zero_w_v1_1_ota_rejects_bad_sequence();
  test_pi_zero_w_v1_1_ota_l2_receiver();
  test_pi_usb_control_requests();
  test_ieee80211_open_ap_frames();
  test_cyw43438_d11_registers();
  test_cyw43438_sdpcm_frames();
  test_cyw43438_owned_firmware_payload();
  test_st7789_driver();
  test_node_control_relay_assignment();
  test_ble_adv();
  test_network_coordinator();
  test_disk_analyzer_storage_foundation();
  test_work_admitted_relay_route();
  test_boot_profiles();
  test_hw_relay_endpoints();
  test_erwire_native_eth_sink();
  test_erwire_parse_and_native_poll();
  test_native_boot_erwire_eth_sink();
  test_native_boot_endpoint_intent();
  test_vfs_requires_canonical_objects();
  test_native_boot_storage_endpoint_intent();
  test_netlog_disabled_path();
  test_gfx_console_disabled_path();
  test_print_routes_firmware_before_serial();
  test_ui_surface_renderer_surface();
  test_ui_surface_renderer_4k_tile_plan();
  test_ui_frame_timing_4k120_budget();
  test_ui_boot_dirty_render_state();
  test_ui_boot_dirty_present_rect_coalescing();
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
