#include "er_pi_zero2w.h"

/*
 * Purpose: build the first executable Pi Zero 2 W board bring-up boundary.
 * Intention: no guessed packet path; expose the exact MMIO/radio/storage state
 * that must become ready before remote update traffic is admitted.
 */

enum {
  ER_PI_MAILBOX_TWO_VALUE_BUFFER_BYTES = 8u,
  ER_PI_MAILBOX_MESSAGE_WORDS = 8u,
  ER_PI_ZERO2W_STORAGE_BLOCK_BYTES = 512u,
  ER_PI_ZERO2W_SDIO_OCR_3V3 = 0x00300000u,
  ER_PI_ZERO2W_SD_MEMORY_IF_COND_3V3_CHECK = 0x000001aau,
  ER_PI_ZERO2W_SD_MEMORY_OCR_3V3_HCS = 0x40300000u,
  ER_PI_ZERO2W_SDIO_NO_ARGUMENT = 0u
};

static const ErPiBoardProfile g_er_pi_zero2w_profile = {
  ER_PI_ZERO2W_PERIPHERAL_BASE,
  ER_PI_ZERO2W_PERIPHERAL_BYTES,
  ER_PI_ZERO2W_MAILBOX_OFFSET,
  ER_PI_ZERO2W_MAILBOX_BYTES,
  ER_PI_ZERO2W_GPIO_OFFSET,
  ER_PI_ZERO2W_GPIO_BYTES,
  ER_PI_ZERO2W_SDHOST_OFFSET,
  ER_PI_ZERO2W_SDHOST_BYTES,
  ER_PI_ZERO2W_EMMC_OFFSET,
  ER_PI_ZERO2W_EMMC_BYTES,
  ER_PI_ZERO2W_AUX_OFFSET,
  ER_PI_ZERO2W_AUX_BYTES,
  ER_BOOT_WIFI_KIND_CYW43439_SDIO,
  ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART,
  ER_PI_ZERO2W_WIFI_DEFAULT_CHANNEL
};

static const ErPiBoardProfile g_er_pi_zero_w_v1_1_profile = {
  ER_PI_ZERO_W_V1_1_PERIPHERAL_BASE,
  ER_PI_ZERO_W_V1_1_PERIPHERAL_BYTES,
  ER_PI_ZERO2W_MAILBOX_OFFSET,
  ER_PI_ZERO2W_MAILBOX_BYTES,
  ER_PI_ZERO2W_GPIO_OFFSET,
  ER_PI_ZERO2W_GPIO_BYTES,
  ER_PI_ZERO2W_SDHOST_OFFSET,
  ER_PI_ZERO2W_SDHOST_BYTES,
  ER_PI_ZERO2W_EMMC_OFFSET,
  ER_PI_ZERO2W_EMMC_BYTES,
  ER_PI_ZERO2W_AUX_OFFSET,
  ER_PI_ZERO2W_AUX_BYTES,
  ER_BOOT_WIFI_KIND_CYW43438_SDIO,
  ER_BOOT_BLUETOOTH_KIND_CYW43438_HCI_UART,
  ER_PI_ZERO_W_V1_1_WIFI_DEFAULT_CHANNEL
};

const ErPiBoardProfile* er_pi_zero2w_profile(void) {
  return &g_er_pi_zero2w_profile;
}

const ErPiBoardProfile* er_pi_zero_w_v1_1_profile(void) {
  return &g_er_pi_zero_w_v1_1_profile;
}

UINT64 er_pi_board_peripheral_phys(const ErPiBoardProfile* profile,
                                   UINT64 offset) {
  if (profile == 0) {
    return 0u;
  }
  return profile->peripheral_base + offset;
}

UINT64 er_pi_zero2w_peripheral_phys(UINT64 offset) {
  return er_pi_board_peripheral_phys(er_pi_zero2w_profile(), offset);
}

static INT64 er_pi_board_map_child(const ErPiBoardProfile* profile,
                                   UINT64 offset,
                                   UINT64 len) {
  return er_mmio_map((INT64)er_pi_board_peripheral_phys(profile, offset),
                     (INT64)len);
}

UINT8 er_pi_board_mmio_map(const ErPiBoardProfile* profile,
                           ErPiZero2wMmio* out_mmio) {
  if (profile == 0 || out_mmio == 0) {
    return 0u;
  }

  out_mmio->mapped = 0u;
  out_mmio->peripheral_handle =
      er_mmio_map((INT64)profile->peripheral_base,
                  (INT64)profile->peripheral_bytes);
  out_mmio->mailbox_handle =
      er_pi_board_map_child(profile, profile->mailbox_offset,
                            profile->mailbox_bytes);
  out_mmio->gpio_handle =
      er_pi_board_map_child(profile, profile->gpio_offset,
                            profile->gpio_bytes);
  out_mmio->sdhost_handle =
      er_pi_board_map_child(profile, profile->sdhost_offset,
                            profile->sdhost_bytes);
  out_mmio->emmc_handle =
      er_pi_board_map_child(profile, profile->emmc_offset,
                            profile->emmc_bytes);
  out_mmio->aux_handle =
      er_pi_board_map_child(profile, profile->aux_offset,
                            profile->aux_bytes);

  if (out_mmio->peripheral_handle <= 0 ||
      out_mmio->mailbox_handle <= 0 ||
      out_mmio->gpio_handle <= 0 ||
      out_mmio->sdhost_handle <= 0 ||
      out_mmio->emmc_handle <= 0 ||
      out_mmio->aux_handle <= 0) {
    return 0u;
  }

  out_mmio->mapped = 1u;
  return 1u;
}

UINT8 er_pi_zero2w_mmio_map(ErPiZero2wMmio* out_mmio) {
  return er_pi_board_mmio_map(er_pi_zero2w_profile(), out_mmio);
}

UINT8 er_pi_mailbox_two_value_request(UINT32 tag_id,
                                      UINT32 value0,
                                      UINT32 value1,
                                      ErPiMailboxTwoValueMessage* out_message) {
  if (out_message == 0 ||
      tag_id == ER_PI_MAILBOX_TAG_LAST) {
    return 0u;
  }

  out_message->size_bytes =
      (UINT32)(ER_PI_MAILBOX_MESSAGE_WORDS * sizeof(UINT32));
  out_message->request_code = ER_PI_MAILBOX_REQUEST_CODE;
  out_message->tag_id = tag_id;
  out_message->value_buffer_bytes = ER_PI_MAILBOX_TWO_VALUE_BUFFER_BYTES;
  out_message->request_value_bytes = 0u;
  out_message->value0 = value0;
  out_message->value1 = value1;
  out_message->end_tag = ER_PI_MAILBOX_TAG_LAST;
  return 1u;
}

static UINT8 er_pi_zero2w_sdio_plan_add(ErPiZero2wSdioBringupPlan* plan,
                                        UINT32 command_index,
                                        UINT32 argument,
                                        UINT32 response_kind) {
  if (plan == 0 ||
      plan->command_count >= ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY ||
      er_pi_mmc_command_prepare(command_index,
                                argument,
                                response_kind,
                                &plan->commands[plan->command_count]) == 0u) {
    return 0u;
  }

  plan->command_count += 1u;
  return 1u;
}

static UINT8 er_pi_zero2w_sd_memory_plan_add(
    ErPiZero2wSdMemoryBringupPlan* plan,
    UINT32 command_index,
    UINT32 argument,
    UINT32 response_kind) {
  if (plan == 0 ||
      plan->command_count >= ER_PI_ZERO2W_SD_MEMORY_BRINGUP_COMMAND_CAPACITY ||
      er_pi_mmc_command_prepare(command_index,
                                argument,
                                response_kind,
                                &plan->commands[plan->command_count]) == 0u) {
    return 0u;
  }

  plan->command_count += 1u;
  return 1u;
}

UINT8 er_pi_zero2w_sd_memory_identity_plan(
    ErPiZero2wSdMemoryBringupPlan* out_plan) {
  if (out_plan == 0) {
    return 0u;
  }

  out_plan->command_count = 0u;
  if (er_pi_zero2w_sd_memory_plan_add(out_plan,
                                      ER_PI_MMC_CMD_GO_IDLE_STATE,
                                      ER_PI_ZERO2W_SDIO_NO_ARGUMENT,
                                      ER_PI_MMC_RESPONSE_NONE) == 0u ||
      er_pi_zero2w_sd_memory_plan_add(
          out_plan,
          ER_PI_MMC_CMD_SEND_IF_COND,
          ER_PI_ZERO2W_SD_MEMORY_IF_COND_3V3_CHECK,
          ER_PI_MMC_RESPONSE_R7) == 0u ||
      er_pi_zero2w_sd_memory_plan_add(out_plan,
                                      ER_PI_MMC_CMD_APP_CMD,
                                      ER_PI_ZERO2W_SDIO_NO_ARGUMENT,
                                      ER_PI_MMC_RESPONSE_R1) == 0u ||
      er_pi_zero2w_sd_memory_plan_add(out_plan,
                                      ER_PI_MMC_ACMD_SD_SEND_OP_COND,
                                      ER_PI_ZERO2W_SD_MEMORY_OCR_3V3_HCS,
                                      ER_PI_MMC_RESPONSE_R3) == 0u ||
      er_pi_zero2w_sd_memory_plan_add(out_plan,
                                      ER_PI_MMC_CMD_ALL_SEND_CID,
                                      ER_PI_ZERO2W_SDIO_NO_ARGUMENT,
                                      ER_PI_MMC_RESPONSE_R2) == 0u ||
      er_pi_zero2w_sd_memory_plan_add(out_plan,
                                      ER_PI_MMC_CMD_SEND_RELATIVE_ADDR,
                                      ER_PI_ZERO2W_SDIO_NO_ARGUMENT,
                                      ER_PI_MMC_RESPONSE_R6) == 0u) {
    return 0u;
  }

  return 1u;
}

UINT8 er_pi_zero2w_sd_memory_claim_plan(
    UINT32 relative_card_address,
    ErPiZero2wSdMemoryBringupPlan* out_plan) {
  if (out_plan == 0 ||
      relative_card_address == 0u ||
      relative_card_address > ER_PI_MMC_RCA_MASK) {
    return 0u;
  }

  out_plan->command_count = 0u;
  return er_pi_zero2w_sd_memory_plan_add(
      out_plan,
      ER_PI_MMC_CMD_SELECT_CARD,
      er_pi_mmc_relative_card_argument(relative_card_address),
      ER_PI_MMC_RESPONSE_R1);
}

static void er_pi_zero2w_sd_memory_state_clear(
    ErPiZero2wSdMemoryBringupState* state) {
  UINT32 i;

  if (state == 0) {
    return;
  }
  state->command_count = 0u;
  state->completed_count = 0u;
  state->relative_card_address = 0u;
  state->operating_conditions = 0u;
  for (i = 0u; i < ER_PI_ZERO2W_SD_MEMORY_BRINGUP_COMMAND_CAPACITY; ++i) {
    state->responses[i] = 0u;
  }
  state->last_interrupt_value = 0u;
  state->completed = 0u;
  state->error = 0u;
}

UINT8 er_pi_zero2w_sd_memory_execute_plan(
    INT64 emmc_handle,
    const ErPiZero2wSdMemoryBringupPlan* plan,
    UINT32 poll_budget_per_command,
    ErPiZero2wSdMemoryBringupState* out_state) {
  UINT32 command_index;
  ErPiEmmcCommandResult result;

  er_pi_zero2w_sd_memory_state_clear(out_state);
  if (plan == 0 ||
      out_state == 0 ||
      plan->command_count == 0u ||
      plan->command_count > ER_PI_ZERO2W_SD_MEMORY_BRINGUP_COMMAND_CAPACITY ||
      poll_budget_per_command == 0u) {
    return 0u;
  }
  out_state->command_count = plan->command_count;
  for (command_index = 0u;
       command_index < plan->command_count;
       ++command_index) {
    if (er_pi_emmc_command_execute(emmc_handle,
                                   &plan->commands[command_index],
                                   poll_budget_per_command,
                                   &result) == 0u) {
      out_state->last_interrupt_value = result.interrupt_value;
      out_state->error = 1u;
      return 0u;
    }
    out_state->responses[command_index] = result.response0;
    out_state->last_interrupt_value = result.interrupt_value;
    out_state->completed_count += 1u;
    if (plan->commands[command_index].response_kind == ER_PI_MMC_RESPONSE_R3) {
      out_state->operating_conditions = result.response0;
    }
    if (plan->commands[command_index].response_kind == ER_PI_MMC_RESPONSE_R6) {
      out_state->relative_card_address =
          er_pi_mmc_relative_card_from_r6(result.response0);
      if (out_state->relative_card_address == 0u) {
        out_state->error = 1u;
        return 0u;
      }
    }
  }
  out_state->completed = 1u;
  return 1u;
}

UINT8 er_pi_zero2w_sdio_identity_plan(ErPiZero2wSdioBringupPlan* out_plan) {
  if (out_plan == 0) {
    return 0u;
  }

  out_plan->command_count = 0u;
  if (er_pi_zero2w_sdio_plan_add(out_plan,
                                 ER_PI_MMC_CMD_GO_IDLE_STATE,
                                 ER_PI_ZERO2W_SDIO_NO_ARGUMENT,
                                 ER_PI_MMC_RESPONSE_NONE) == 0u ||
      er_pi_zero2w_sdio_plan_add(out_plan,
                                 ER_PI_MMC_CMD_IO_SEND_OP_COND,
                                 ER_PI_ZERO2W_SDIO_OCR_3V3,
                                 ER_PI_MMC_RESPONSE_R4) == 0u ||
      er_pi_zero2w_sdio_plan_add(out_plan,
                                 ER_PI_MMC_CMD_SEND_RELATIVE_ADDR,
                                 ER_PI_ZERO2W_SDIO_NO_ARGUMENT,
                                 ER_PI_MMC_RESPONSE_R6) == 0u) {
    return 0u;
  }

  return 1u;
}

UINT8 er_pi_zero2w_sdio_claim_plan(UINT32 relative_card_address,
                                   ErPiZero2wSdioBringupPlan* out_plan) {
  if (out_plan == 0 ||
      relative_card_address == 0u ||
      relative_card_address > ER_PI_MMC_RCA_MASK) {
    return 0u;
  }

  out_plan->command_count = 0u;
  if (er_pi_zero2w_sdio_plan_add(
          out_plan,
          ER_PI_MMC_CMD_SELECT_CARD,
          er_pi_mmc_relative_card_argument(relative_card_address),
          ER_PI_MMC_RESPONSE_R1) == 0u ||
      er_pi_zero2w_sdio_plan_add(
          out_plan,
          ER_PI_MMC_CMD_IO_RW_DIRECT,
          er_pi_sdio_cmd52_argument(ER_PI_SDIO_CMD52_READ,
                                    ER_PI_SDIO_FUNCTION_BACKPLANE,
                                    ER_PI_SDIO_CMD52_NO_RAW,
                                    0u,
                                    0u),
          ER_PI_MMC_RESPONSE_R5) == 0u) {
    return 0u;
  }

  return 1u;
}

static void er_pi_zero2w_sdio_state_clear(ErPiZero2wSdioBringupState* state) {
  UINT32 i;

  if (state == 0) {
    return;
  }
  state->command_count = 0u;
  state->completed_count = 0u;
  state->relative_card_address = 0u;
  for (i = 0u; i < ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY; ++i) {
    state->responses[i] = 0u;
  }
  state->last_interrupt_value = 0u;
  state->completed = 0u;
  state->error = 0u;
}

UINT8 er_pi_zero2w_sdio_execute_plan(
    INT64 emmc_handle,
    const ErPiZero2wSdioBringupPlan* plan,
    UINT32 poll_budget_per_command,
    ErPiZero2wSdioBringupState* out_state) {
  UINT32 command_index;
  ErPiEmmcCommandResult result;

  er_pi_zero2w_sdio_state_clear(out_state);
  if (plan == 0 ||
      out_state == 0 ||
      plan->command_count == 0u ||
      plan->command_count > ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY ||
      poll_budget_per_command == 0u) {
    return 0u;
  }
  out_state->command_count = plan->command_count;
  for (command_index = 0u;
       command_index < plan->command_count;
       ++command_index) {
    if (er_pi_emmc_command_execute(emmc_handle,
                                   &plan->commands[command_index],
                                   poll_budget_per_command,
                                   &result) == 0u) {
      out_state->last_interrupt_value = result.interrupt_value;
      out_state->error = 1u;
      return 0u;
    }
    out_state->responses[command_index] = result.response0;
    out_state->last_interrupt_value = result.interrupt_value;
    out_state->completed_count += 1u;
    if (plan->commands[command_index].response_kind == ER_PI_MMC_RESPONSE_R6) {
      out_state->relative_card_address =
          er_pi_mmc_relative_card_from_r6(result.response0);
      if (out_state->relative_card_address == 0u) {
        out_state->error = 1u;
        return 0u;
      }
    }
  }
  out_state->completed = 1u;
  return 1u;
}

UINT8 er_pi_board_apply_boot_report(const ErPiBoardProfile* profile,
                                    ErBootServicesReport* report) {
  ErPiZero2wMmio mmio;

  if (profile == 0 || report == 0) {
    return 0u;
  }

  if (er_pi_board_mmio_map(profile, &mmio) == 0u) {
    return 0u;
  }

  if (er_boot_services_set_wifi_runtime(report,
                                        profile->wifi_kind,
                                        0u,
                                        profile->wifi_default_channel) == 0u ||
      er_boot_services_set_bluetooth_runtime(
          report,
          profile->bluetooth_kind,
          0u) == 0u ||
      er_boot_services_set_local_storage(
          report,
          ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD,
          0u,
          ER_PI_ZERO2W_STORAGE_BLOCK_BYTES,
          ER_PI_ZERO2W_STORAGE_BLOCK_BYTES) == 0u ||
      er_boot_services_set_update_artifact_store(report, 0u, 0u) == 0u) {
    return 0u;
  }

  return 1u;
}

UINT8 er_pi_zero2w_apply_boot_report(ErBootServicesReport* report) {
  return er_pi_board_apply_boot_report(er_pi_zero2w_profile(), report);
}

UINT8 er_pi_zero_w_v1_1_apply_boot_report(ErBootServicesReport* report) {
  return er_pi_board_apply_boot_report(er_pi_zero_w_v1_1_profile(), report);
}
