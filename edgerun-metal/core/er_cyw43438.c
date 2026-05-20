#include "er_cyw43438.h"
#include "er_mem.h"

enum {
  ER_CYW43438_BEACON_SEQUENCE = 0u,
  ER_CYW43438_PROBE_RESPONSE_SEQUENCE = 1u,
  ER_CYW43438_STAGE_SDIO_IDENTITY_INDEX = 0u,
  ER_CYW43438_STAGE_SDIO_CLAIM_INDEX = 1u,
  ER_CYW43438_STAGE_BEACON_INDEX = 2u,
  ER_CYW43438_STAGE_PROBE_RESPONSE_INDEX = 3u
};

void er_cyw43438_clear_firmware_set(ErCyw43438FirmwareSet* firmware) {
  if (firmware == 0) {
    return;
  }
  er_firmware_loader_clear_image(&firmware->ram);
  er_firmware_loader_clear_image(&firmware->nvram);
  er_firmware_loader_clear_image(&firmware->clm_blob);
}

void er_cyw43438_clear_open_ap_boot_device(
    ErCyw43438OpenApBootDevice* device) {
  if (device == 0) {
    return;
  }
  er_mem_zero((UINT8*)device, (UINTN)sizeof(*device));
}

static void er_cyw43438_stage_init(ErCyw43438ApStage* stage,
                                   UINT16 kind,
                                   UINT32 blocked_reason) {
  er_mem_zero((UINT8*)stage, (UINTN)sizeof(*stage));
  stage->abi_version = ER_CYW43438_ABI_VERSION;
  stage->kind = kind;
  stage->blocked_reason = blocked_reason;
}

static UINT8 er_cyw43438_prepare_template(
    const ErIeee80211OpenApConfig* config,
    UINT16 template_kind,
    const UINT8 probe_station_mac[ER_NET_MAC_LEN],
    ErCyw43438ApTemplate* out_template) {
  UINT32 frame_len;
  UINT8 ok;

  if (config == 0 || out_template == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_template, (UINTN)sizeof(*out_template));
  out_template->abi_version = ER_CYW43438_ABI_VERSION;
  out_template->kind = template_kind;
  if (template_kind == ER_CYW43438_AP_TEMPLATE_BEACON) {
    ok = er_ieee80211_open_ap_build_beacon(config,
                                           ER_CYW43438_BEACON_SEQUENCE,
                                           out_template->frame,
                                           ER_IEEE80211_AP_FRAME_MAX,
                                           &frame_len);
  } else if (template_kind == ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE) {
    ok = er_ieee80211_open_ap_build_probe_response(
        config,
        probe_station_mac,
        ER_CYW43438_PROBE_RESPONSE_SEQUENCE,
        out_template->frame,
        ER_IEEE80211_AP_FRAME_MAX,
        &frame_len);
  } else {
    ok = 0u;
  }
  if (ok == 0u) {
    er_mem_zero((UINT8*)out_template, (UINTN)sizeof(*out_template));
    return 0u;
  }
  out_template->frame_len = frame_len;
  return 1u;
}

UINT8 er_cyw43438_add_pi_zero_w_firmware_sources(ErBootConfig* config) {
  if (config == 0 ||
      config->firmware_source_count >
          (ER_BOOT_CONFIG_FIRMWARE_SOURCE_CAPACITY -
           ER_CYW43438_FIRMWARE_SOURCE_COUNT) ||
      er_boot_config_add_efi_firmware_source_instance(
          config,
          ER_CYW43438_SDIO_VENDOR_BROADCOM,
          ER_CYW43438_SDIO_DEVICE_BCM43430,
          ER_CYW43438_FIRMWARE_INSTANCE_RAM) == 0u ||
      er_boot_config_add_efi_firmware_source_instance(
          config,
          ER_CYW43438_SDIO_VENDOR_BROADCOM,
          ER_CYW43438_SDIO_DEVICE_BCM43430,
          ER_CYW43438_FIRMWARE_INSTANCE_NVRAM) == 0u ||
      er_boot_config_add_efi_firmware_source_instance(
          config,
          ER_CYW43438_SDIO_VENDOR_BROADCOM,
          ER_CYW43438_SDIO_DEVICE_BCM43430,
          ER_CYW43438_FIRMWARE_INSTANCE_CLM_BLOB) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_cyw43438_load_pi_zero_w_firmware(
    const ErCryptoProvider* crypto,
    const ErBootConfig* config,
    ErFirmwareReadFn read_fn,
    void* read_ctx,
    UINT8* ram_bytes,
    UINTN ram_capacity,
    UINT8* nvram_bytes,
    UINTN nvram_capacity,
    UINT8* clm_blob_bytes,
    UINTN clm_blob_capacity,
    ErCyw43438FirmwareSet* out_firmware) {
  er_cyw43438_clear_firmware_set(out_firmware);
  if (out_firmware == 0 ||
      er_firmware_loader_load_for_device_instance(
          crypto,
          config,
          ER_CYW43438_SDIO_VENDOR_BROADCOM,
          ER_CYW43438_SDIO_DEVICE_BCM43430,
          ER_CYW43438_FIRMWARE_INSTANCE_RAM,
          read_fn,
          read_ctx,
          ram_bytes,
          ram_capacity,
          &out_firmware->ram) == 0u ||
      er_firmware_loader_load_for_device_instance(
          crypto,
          config,
          ER_CYW43438_SDIO_VENDOR_BROADCOM,
          ER_CYW43438_SDIO_DEVICE_BCM43430,
          ER_CYW43438_FIRMWARE_INSTANCE_NVRAM,
          read_fn,
          read_ctx,
          nvram_bytes,
          nvram_capacity,
          &out_firmware->nvram) == 0u ||
      er_firmware_loader_load_for_device_instance(
          crypto,
          config,
          ER_CYW43438_SDIO_VENDOR_BROADCOM,
          ER_CYW43438_SDIO_DEVICE_BCM43430,
          ER_CYW43438_FIRMWARE_INSTANCE_CLM_BLOB,
          read_fn,
          read_ctx,
          clm_blob_bytes,
          clm_blob_capacity,
          &out_firmware->clm_blob) == 0u) {
    er_cyw43438_clear_firmware_set(out_firmware);
    return 0u;
  }
  return 1u;
}

UINT8 er_cyw43438_prepare_open_l2_ap_boot_device(
    const ErCryptoProvider* crypto,
    const ErBootConfig* config,
    ErFirmwareReadFn read_fn,
    void* read_ctx,
    UINT8* ram_bytes,
    UINTN ram_capacity,
    UINT8* nvram_bytes,
    UINTN nvram_capacity,
    UINT8* clm_blob_bytes,
    UINTN clm_blob_capacity,
    const ErWifiL2ApPlan* ap_plan,
    UINT32 relative_card_address,
    const UINT8 probe_station_mac[ER_NET_MAC_LEN],
    ErCyw43438OpenApBootDevice* out_device) {
  er_cyw43438_clear_open_ap_boot_device(out_device);
  if (out_device == 0 ||
      er_cyw43438_load_pi_zero_w_firmware(crypto,
                                          config,
                                          read_fn,
                                          read_ctx,
                                          ram_bytes,
                                          ram_capacity,
                                          nvram_bytes,
                                          nvram_capacity,
                                          clm_blob_bytes,
                                          clm_blob_capacity,
                                          &out_device->firmware) == 0u ||
      er_cyw43438_prepare_open_l2_ap_path(ap_plan,
                                          relative_card_address,
                                          probe_station_mac,
                                          &out_device->ap_path) == 0u) {
    er_cyw43438_clear_open_ap_boot_device(out_device);
    return 0u;
  }
  out_device->abi_version = ER_CYW43438_ABI_VERSION;
  return 1u;
}

UINT8 er_cyw43438_prepare_open_l2_ap_path(
    const ErWifiL2ApPlan* ap_plan,
    UINT32 relative_card_address,
    const UINT8 probe_station_mac[ER_NET_MAC_LEN],
    ErCyw43438ApPath* out_path) {
  UINT32 blocked_reason;

  if (er_wifi_l2_ap_plan_valid(ap_plan) == 0u ||
      probe_station_mac == 0 ||
      out_path == 0) {
    return 0u;
  }
  blocked_reason = ER_CYW43438_AP_BLOCKED_NO_FIRMWARE_REGISTER_EXECUTOR;
  if (relative_card_address == 0u) {
    blocked_reason |= ER_CYW43438_AP_BLOCKED_NO_RCA;
  }

  er_mem_zero((UINT8*)out_path, (UINTN)sizeof(*out_path));
  out_path->abi_version = ER_CYW43438_ABI_VERSION;
  out_path->stage_count = ER_CYW43438_AP_STAGE_COUNT;
  out_path->blocked_reason = blocked_reason;
  if (er_ieee80211_open_ap_config_from_l2_plan(ap_plan,
                                               &out_path->ap_config) == 0u) {
    er_mem_zero((UINT8*)out_path, (UINTN)sizeof(*out_path));
    return 0u;
  }

  er_cyw43438_stage_init(
      &out_path->stages[ER_CYW43438_STAGE_SDIO_IDENTITY_INDEX],
      ER_CYW43438_AP_STAGE_SDIO_IDENTITY,
      ER_CYW43438_AP_BLOCKED_NONE);
  if (er_pi_zero2w_sdio_identity_plan(
          &out_path->stages[ER_CYW43438_STAGE_SDIO_IDENTITY_INDEX].sdio_plan) == 0u) {
    er_mem_zero((UINT8*)out_path, (UINTN)sizeof(*out_path));
    return 0u;
  }

  er_cyw43438_stage_init(
      &out_path->stages[ER_CYW43438_STAGE_SDIO_CLAIM_INDEX],
      ER_CYW43438_AP_STAGE_SDIO_CLAIM,
      relative_card_address == 0u ? ER_CYW43438_AP_BLOCKED_NO_RCA :
                                    ER_CYW43438_AP_BLOCKED_NONE);
  if (relative_card_address != 0u &&
      er_pi_zero2w_sdio_claim_plan(
          relative_card_address,
          &out_path->stages[ER_CYW43438_STAGE_SDIO_CLAIM_INDEX].sdio_plan) == 0u) {
    er_mem_zero((UINT8*)out_path, (UINTN)sizeof(*out_path));
    return 0u;
  }

  er_cyw43438_stage_init(
      &out_path->stages[ER_CYW43438_STAGE_BEACON_INDEX],
      ER_CYW43438_AP_STAGE_INSTALL_BEACON_TEMPLATE,
      ER_CYW43438_AP_BLOCKED_NO_FIRMWARE_REGISTER_EXECUTOR);
  if (er_cyw43438_prepare_template(
          &out_path->ap_config,
          ER_CYW43438_AP_TEMPLATE_BEACON,
          probe_station_mac,
          &out_path->stages[ER_CYW43438_STAGE_BEACON_INDEX].ap_template) == 0u) {
    er_mem_zero((UINT8*)out_path, (UINTN)sizeof(*out_path));
    return 0u;
  }

  er_cyw43438_stage_init(
      &out_path->stages[ER_CYW43438_STAGE_PROBE_RESPONSE_INDEX],
      ER_CYW43438_AP_STAGE_INSTALL_PROBE_RESPONSE_TEMPLATE,
      ER_CYW43438_AP_BLOCKED_NO_FIRMWARE_REGISTER_EXECUTOR);
  if (er_cyw43438_prepare_template(
          &out_path->ap_config,
          ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE,
          probe_station_mac,
          &out_path->stages[ER_CYW43438_STAGE_PROBE_RESPONSE_INDEX].ap_template) == 0u) {
    er_mem_zero((UINT8*)out_path, (UINTN)sizeof(*out_path));
    return 0u;
  }

  return 1u;
}
