#include "er_cyw43438.h"
#include "er_mem.h"

enum {
  ER_CYW43438_BEACON_SEQUENCE = 0u,
  ER_CYW43438_PROBE_RESPONSE_SEQUENCE = 1u,
  ER_CYW43438_STAGE_SDIO_IDENTITY_INDEX = 0u,
  ER_CYW43438_STAGE_SDIO_CLAIM_INDEX = 1u,
  ER_CYW43438_STAGE_BEACON_INDEX = 2u,
  ER_CYW43438_STAGE_PROBE_RESPONSE_INDEX = 3u,
  ER_CYW43438_R5_DATA_MASK = 0xffu,
  ER_CYW43438_CCCR_IO_ENABLE_ADDR = 0x00000002u,
  ER_CYW43438_CCCR_IO_READY_ADDR = 0x00000003u,
  ER_CYW43438_CCCR_ENABLE_FUNCTION_1 = 0x02u,
  ER_CYW43438_CCCR_ENABLE_FUNCTION_2 = 0x04u,
  ER_CYW43438_WLAN_AP_CONTROL_ADDR = 0x00000001u,
  ER_CYW43438_WLAN_AP_CONTROL_ENABLE = 0x01u,
  ER_CYW43438_WLAN_BEACON_TEMPLATE_ADDR = 0x00001000u,
  ER_CYW43438_WLAN_PROBE_TEMPLATE_ADDR = 0x00001100u,
  ER_CYW43438_REGISTER_OP_ENABLE_INDEX = 0u,
  ER_CYW43438_REGISTER_OP_READY_INDEX = 1u,
  ER_CYW43438_REGISTER_OP_BEACON_INDEX = 2u,
  ER_CYW43438_REGISTER_OP_PROBE_INDEX = 3u,
  ER_CYW43438_REGISTER_OP_AP_ENABLE_INDEX = 4u
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

static void er_cyw43438_sdio_direct_result_clear(
    ErCyw43438SdioDirectResult* result) {
  if (result == 0) {
    return;
  }
  er_mem_zero((UINT8*)result, (UINTN)sizeof(*result));
}

static void er_cyw43438_sdio_transfer_result_clear(
    ErCyw43438SdioTransferResult* result) {
  if (result == 0) {
    return;
  }
  er_mem_zero((UINT8*)result, (UINTN)sizeof(*result));
}

static void er_cyw43438_register_executor_result_clear(
    ErCyw43438RegisterExecutorResult* result) {
  if (result == 0) {
    return;
  }
  er_mem_zero((UINT8*)result, (UINTN)sizeof(*result));
}

UINT8 er_cyw43438_sdio_function_valid(UINT8 function) {
  switch (function) {
    case ER_CYW43438_SDIO_FUNCTION_CCCR:
    case ER_CYW43438_SDIO_FUNCTION_BACKPLANE:
    case ER_CYW43438_SDIO_FUNCTION_WLAN:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_cyw43438_sdio_direct_execute(
    INT64 emmc_handle,
    UINT8 write,
    UINT8 function,
    UINT32 address,
    UINT8 value,
    UINT32 poll_budget,
    ErCyw43438SdioDirectResult* out_result) {
  ErPiMmcCommand command;
  ErPiEmmcCommandResult result;

  er_cyw43438_sdio_direct_result_clear(out_result);
  if (out_result == 0 ||
      er_cyw43438_sdio_function_valid(function) == 0u ||
      poll_budget == 0u ||
      er_pi_mmc_command_prepare(
          ER_PI_MMC_CMD_IO_RW_DIRECT,
          er_pi_sdio_cmd52_argument(write,
                                    function,
                                    ER_PI_SDIO_CMD52_NO_RAW,
                                    address,
                                    value),
          ER_PI_MMC_RESPONSE_R5,
          &command) == 0u ||
      er_pi_emmc_command_execute(emmc_handle,
                                 &command,
                                 poll_budget,
                                 &result) == 0u) {
    return 0u;
  }
  out_result->abi_version = ER_CYW43438_ABI_VERSION;
  out_result->function = function;
  out_result->address = address;
  out_result->response0 = result.response0;
  out_result->interrupt_value = result.interrupt_value;
  out_result->value = write == ER_PI_SDIO_WRITE ?
                      value :
                      (UINT8)(result.response0 & ER_CYW43438_R5_DATA_MASK);
  return 1u;
}

UINT8 er_cyw43438_sdio_read8(INT64 emmc_handle,
                             UINT8 function,
                             UINT32 address,
                             UINT32 poll_budget,
                             ErCyw43438SdioDirectResult* out_result) {
  return er_cyw43438_sdio_direct_execute(emmc_handle,
                                         ER_PI_SDIO_READ,
                                         function,
                                         address,
                                         0u,
                                         poll_budget,
                                         out_result);
}

UINT8 er_cyw43438_sdio_write8(INT64 emmc_handle,
                              UINT8 function,
                              UINT32 address,
                              UINT8 value,
                              UINT32 poll_budget,
                              ErCyw43438SdioDirectResult* out_result) {
  return er_cyw43438_sdio_direct_execute(emmc_handle,
                                         ER_PI_SDIO_WRITE,
                                         function,
                                         address,
                                         value,
                                         poll_budget,
                                         out_result);
}

static UINT8 er_cyw43438_sdio_transfer_finish(
    UINT8 function,
    UINT8 incrementing_address,
    UINT32 address,
    UINT32 bytes_len,
    const ErPiEmmcSdioTransferResult* transfer,
    ErCyw43438SdioTransferResult* out_result) {
  if (transfer == 0 || out_result == 0 || transfer->completed == 0u) {
    return 0u;
  }
  out_result->abi_version = ER_CYW43438_ABI_VERSION;
  out_result->function = function;
  out_result->incrementing_address = incrementing_address;
  out_result->address = address;
  out_result->bytes_len = bytes_len;
  out_result->response0 = transfer->response0;
  out_result->interrupt_value = transfer->interrupt_value;
  return 1u;
}

UINT8 er_cyw43438_sdio_read_bytes(
    INT64 emmc_handle,
    UINT8 function,
    UINT8 incrementing_address,
    UINT32 address,
    UINT8* out_bytes,
    UINT32 bytes_len,
    UINT32 poll_budget,
    ErCyw43438SdioTransferResult* out_result) {
  ErPiEmmcSdioTransferResult transfer;

  er_cyw43438_sdio_transfer_result_clear(out_result);
  if (out_result == 0 ||
      er_cyw43438_sdio_function_valid(function) == 0u ||
      er_pi_emmc_sdio_read_bytes(emmc_handle,
                                 function,
                                 incrementing_address,
                                 address,
                                 out_bytes,
                                 bytes_len,
                                 poll_budget,
                                 &transfer) == 0u) {
    return 0u;
  }
  return er_cyw43438_sdio_transfer_finish(function,
                                          incrementing_address,
                                          address,
                                          bytes_len,
                                          &transfer,
                                          out_result);
}

UINT8 er_cyw43438_sdio_write_bytes(
    INT64 emmc_handle,
    UINT8 function,
    UINT8 incrementing_address,
    UINT32 address,
    const UINT8* bytes,
    UINT32 bytes_len,
    UINT32 poll_budget,
    ErCyw43438SdioTransferResult* out_result) {
  ErPiEmmcSdioTransferResult transfer;

  er_cyw43438_sdio_transfer_result_clear(out_result);
  if (out_result == 0 ||
      er_cyw43438_sdio_function_valid(function) == 0u ||
      er_pi_emmc_sdio_write_bytes(emmc_handle,
                                  function,
                                  incrementing_address,
                                  address,
                                  bytes,
                                  bytes_len,
                                  poll_budget,
                                  &transfer) == 0u) {
    return 0u;
  }
  return er_cyw43438_sdio_transfer_finish(function,
                                          incrementing_address,
                                          address,
                                          bytes_len,
                                          &transfer,
                                          out_result);
}

static void er_cyw43438_stage_init(ErCyw43438ApStage* stage,
                                   UINT16 kind,
                                   UINT32 blocked_reason) {
  er_mem_zero((UINT8*)stage, (UINTN)sizeof(*stage));
  stage->abi_version = ER_CYW43438_ABI_VERSION;
  stage->kind = kind;
  stage->blocked_reason = blocked_reason;
}

static void er_cyw43438_register_op_init(ErCyw43438RegisterOp* op,
                                         UINT16 kind,
                                         UINT8 function,
                                         UINT8 template_kind,
                                         UINT32 address,
                                         UINT32 value,
                                         UINT32 value_mask,
                                         UINT32 bytes_len) {
  er_mem_zero((UINT8*)op, (UINTN)sizeof(*op));
  op->abi_version = ER_CYW43438_ABI_VERSION;
  op->kind = kind;
  op->function = function;
  op->template_kind = template_kind;
  op->address = address;
  op->value = value;
  op->value_mask = value_mask;
  op->bytes_len = bytes_len;
}

static const ErCyw43438ApTemplate* er_cyw43438_template_for_kind(
    const ErCyw43438ApPath* path,
    UINT8 template_kind) {
  if (path == 0) {
    return 0;
  }
  switch (template_kind) {
    case ER_CYW43438_AP_TEMPLATE_BEACON:
      return &path->stages[ER_CYW43438_STAGE_BEACON_INDEX].ap_template;
    case ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE:
      return &path->stages[ER_CYW43438_STAGE_PROBE_RESPONSE_INDEX].ap_template;
    default:
      return 0;
  }
}

static UINT8 er_cyw43438_template_valid(
    const ErCyw43438ApTemplate* template,
    UINT8 expected_kind) {
  return (UINT8)(template != 0 &&
                 template->abi_version == ER_CYW43438_ABI_VERSION &&
                 template->kind == expected_kind &&
                 template->frame_len != 0u &&
                 template->frame_len <= ER_IEEE80211_AP_FRAME_MAX);
}

static UINT8 er_cyw43438_register_op_valid(
    const ErCyw43438ApPath* path,
    const ErCyw43438RegisterOp* op) {
  const ErCyw43438ApTemplate* template;

  if (op == 0 ||
      op->abi_version != ER_CYW43438_ABI_VERSION ||
      er_cyw43438_sdio_function_valid(op->function) == 0u ||
      op->reserved != 0u) {
    return 0u;
  }
  switch (op->kind) {
    case ER_CYW43438_REGISTER_OP_WRITE8:
      return (UINT8)(op->template_kind == 0u &&
                     op->value <= ER_CYW43438_R5_DATA_MASK &&
                     op->value_mask == ER_CYW43438_R5_DATA_MASK &&
                     op->bytes_len == 0u);
    case ER_CYW43438_REGISTER_OP_READ8_EXPECT:
      return (UINT8)(op->template_kind == 0u &&
                     op->value <= ER_CYW43438_R5_DATA_MASK &&
                     op->value_mask <= ER_CYW43438_R5_DATA_MASK &&
                     op->value_mask != 0u &&
                     op->bytes_len == 0u);
    case ER_CYW43438_REGISTER_OP_WRITE_TEMPLATE:
      template = er_cyw43438_template_for_kind(path, op->template_kind);
      return (UINT8)(op->function == ER_CYW43438_SDIO_FUNCTION_WLAN &&
                     op->value == 0u &&
                     op->value_mask == 0u &&
                     er_cyw43438_template_valid(template, op->template_kind) != 0u &&
                     op->bytes_len == template->frame_len);
    default:
      return 0u;
  }
}

static UINT8 er_cyw43438_register_executor_plan_valid(
    const ErCyw43438ApPath* path,
    const ErCyw43438RegisterExecutorPlan* plan) {
  UINT16 i;

  if (path == 0 ||
      plan == 0 ||
      plan->abi_version != ER_CYW43438_ABI_VERSION ||
      plan->op_count != ER_CYW43438_REGISTER_OP_CAPACITY) {
    return 0u;
  }
  for (i = 0u; i < plan->op_count; ++i) {
    if (er_cyw43438_register_op_valid(path, &plan->ops[i]) == 0u) {
      return 0u;
    }
  }
  return 1u;
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
                                          &out_device->ap_path) == 0u ||
      er_cyw43438_prepare_register_executor_plan(
          &out_device->ap_path,
          &out_device->register_executor) == 0u) {
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
  blocked_reason = ER_CYW43438_AP_BLOCKED_NONE;
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
      ER_CYW43438_AP_BLOCKED_NONE);
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
      ER_CYW43438_AP_BLOCKED_NONE);
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

UINT8 er_cyw43438_prepare_register_executor_plan(
    const ErCyw43438ApPath* path,
    ErCyw43438RegisterExecutorPlan* out_plan) {
  const ErCyw43438ApTemplate* beacon;
  const ErCyw43438ApTemplate* probe;
  UINT32 functions;

  if (path == 0 ||
      out_plan == 0 ||
      path->abi_version != ER_CYW43438_ABI_VERSION ||
      path->stage_count != ER_CYW43438_AP_STAGE_COUNT ||
      path->blocked_reason != ER_CYW43438_AP_BLOCKED_NONE) {
    return 0u;
  }
  beacon = er_cyw43438_template_for_kind(path, ER_CYW43438_AP_TEMPLATE_BEACON);
  probe = er_cyw43438_template_for_kind(path,
                                        ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE);
  if (er_cyw43438_template_valid(beacon, ER_CYW43438_AP_TEMPLATE_BEACON) == 0u ||
      er_cyw43438_template_valid(probe,
                                 ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE) == 0u) {
    return 0u;
  }

  functions = ER_CYW43438_CCCR_ENABLE_FUNCTION_1 |
              ER_CYW43438_CCCR_ENABLE_FUNCTION_2;
  er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
  out_plan->abi_version = ER_CYW43438_ABI_VERSION;
  out_plan->op_count = ER_CYW43438_REGISTER_OP_CAPACITY;
  er_cyw43438_register_op_init(
      &out_plan->ops[ER_CYW43438_REGISTER_OP_ENABLE_INDEX],
      ER_CYW43438_REGISTER_OP_WRITE8,
      ER_CYW43438_SDIO_FUNCTION_CCCR,
      0u,
      ER_CYW43438_CCCR_IO_ENABLE_ADDR,
      functions,
      ER_CYW43438_R5_DATA_MASK,
      0u);
  er_cyw43438_register_op_init(
      &out_plan->ops[ER_CYW43438_REGISTER_OP_READY_INDEX],
      ER_CYW43438_REGISTER_OP_READ8_EXPECT,
      ER_CYW43438_SDIO_FUNCTION_CCCR,
      0u,
      ER_CYW43438_CCCR_IO_READY_ADDR,
      functions,
      functions,
      0u);
  er_cyw43438_register_op_init(
      &out_plan->ops[ER_CYW43438_REGISTER_OP_BEACON_INDEX],
      ER_CYW43438_REGISTER_OP_WRITE_TEMPLATE,
      ER_CYW43438_SDIO_FUNCTION_WLAN,
      ER_CYW43438_AP_TEMPLATE_BEACON,
      ER_CYW43438_WLAN_BEACON_TEMPLATE_ADDR,
      0u,
      0u,
      beacon->frame_len);
  er_cyw43438_register_op_init(
      &out_plan->ops[ER_CYW43438_REGISTER_OP_PROBE_INDEX],
      ER_CYW43438_REGISTER_OP_WRITE_TEMPLATE,
      ER_CYW43438_SDIO_FUNCTION_WLAN,
      ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE,
      ER_CYW43438_WLAN_PROBE_TEMPLATE_ADDR,
      0u,
      0u,
      probe->frame_len);
  er_cyw43438_register_op_init(
      &out_plan->ops[ER_CYW43438_REGISTER_OP_AP_ENABLE_INDEX],
      ER_CYW43438_REGISTER_OP_WRITE8,
      ER_CYW43438_SDIO_FUNCTION_WLAN,
      0u,
      ER_CYW43438_WLAN_AP_CONTROL_ADDR,
      ER_CYW43438_WLAN_AP_CONTROL_ENABLE,
      ER_CYW43438_R5_DATA_MASK,
      0u);
  return er_cyw43438_register_executor_plan_valid(path, out_plan);
}

UINT8 er_cyw43438_execute_register_executor_plan(
    INT64 emmc_handle,
    const ErCyw43438ApPath* path,
    const ErCyw43438RegisterExecutorPlan* plan,
    UINT32 poll_budget,
    ErCyw43438RegisterExecutorResult* out_result) {
  UINT16 i;

  er_cyw43438_register_executor_result_clear(out_result);
  if (out_result == 0 ||
      poll_budget == 0u ||
      er_cyw43438_register_executor_plan_valid(path, plan) == 0u) {
    return 0u;
  }
  out_result->abi_version = ER_CYW43438_ABI_VERSION;
  for (i = 0u; i < plan->op_count; ++i) {
    const ErCyw43438RegisterOp* op = &plan->ops[i];
    ErCyw43438SdioDirectResult direct_result;
    ErCyw43438SdioTransferResult transfer_result;
    const ErCyw43438ApTemplate* template;

    out_result->failed_op = i;
    switch (op->kind) {
      case ER_CYW43438_REGISTER_OP_WRITE8:
        if (er_cyw43438_sdio_write8(emmc_handle,
                                    op->function,
                                    op->address,
                                    (UINT8)op->value,
                                    poll_budget,
                                    &direct_result) == 0u) {
          return 0u;
        }
        out_result->last_response0 = direct_result.response0;
        out_result->last_interrupt_value = direct_result.interrupt_value;
        break;
      case ER_CYW43438_REGISTER_OP_READ8_EXPECT:
        if (er_cyw43438_sdio_read8(emmc_handle,
                                   op->function,
                                   op->address,
                                   poll_budget,
                                   &direct_result) == 0u ||
            (((UINT32)direct_result.value & op->value_mask) != op->value)) {
          return 0u;
        }
        out_result->last_response0 = direct_result.response0;
        out_result->last_interrupt_value = direct_result.interrupt_value;
        break;
      case ER_CYW43438_REGISTER_OP_WRITE_TEMPLATE:
        template = er_cyw43438_template_for_kind(path, op->template_kind);
        if (template == 0 ||
            er_cyw43438_sdio_write_bytes(
                emmc_handle,
                op->function,
                ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS,
                op->address,
                template->frame,
                op->bytes_len,
                poll_budget,
                &transfer_result) == 0u) {
          return 0u;
        }
        out_result->last_response0 = transfer_result.response0;
        out_result->last_interrupt_value = transfer_result.interrupt_value;
        break;
      default:
        return 0u;
    }
    out_result->completed_ops = (UINT16)(i + 1u);
  }
  out_result->failed_op = 0u;
  out_result->completed = 1u;
  return 1u;
}
