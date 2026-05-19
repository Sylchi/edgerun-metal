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
  ER_PI_SDIO_FUNCTION_BITS = 28u,
  ER_PI_SDIO_RAW_FLAG_BIT = 27u,
  ER_PI_SDIO_BLOCK_MODE_BIT = 27u,
  ER_PI_SDIO_INCREMENTING_ADDRESS_BIT = 26u,
  ER_PI_SDIO_ADDRESS_BITS = 9u,
  ER_PI_SDIO_RW_FLAG_BIT = 31u,
  ER_PI_SDIO_FUNCTION_MASK = 0x07u,
  ER_PI_SDIO_ADDRESS_MASK = 0x0001ffffu,
  ER_PI_SDIO_CMD53_COUNT_MASK = 0x000001ffu,
  ER_PI_MMC_RCA_MASK = 0x0000ffffu,
  ER_PI_MMC_RCA_ARGUMENT_BITS = 16u,
  ER_PI_EMMC_CMDTM_RESPONSE_BITS = 16u,
  ER_PI_EMMC_CMDTM_RESPONSE_NONE = 0u,
  ER_PI_EMMC_CMDTM_RESPONSE_48 = 2u,
  ER_PI_EMMC_CMDTM_CRC_CHECK = 1u << 19u,
  ER_PI_EMMC_CMDTM_INDEX_CHECK = 1u << 20u,
  ER_PI_EMMC_CMDTM_INDEX_BITS = 24u,
  ER_PI_EMMC_INTERRUPT_ALL = 0xffffffffu,
  ER_PI_ZERO2W_SDIO_OCR_3V3 = 0x00300000u,
  ER_PI_ZERO2W_SDIO_NO_ARGUMENT = 0u
};

UINT64 er_pi_zero2w_peripheral_phys(UINT64 offset) {
  return ER_PI_ZERO2W_PERIPHERAL_BASE + offset;
}

static INT64 er_pi_zero2w_map_child(UINT64 offset, UINT64 len) {
  return er_mmio_map((INT64)er_pi_zero2w_peripheral_phys(offset), (INT64)len);
}

UINT8 er_pi_zero2w_mmio_map(ErPiZero2wMmio* out_mmio) {
  if (out_mmio == 0) {
    return 0u;
  }

  out_mmio->mapped = 0u;
  out_mmio->peripheral_handle =
      er_mmio_map((INT64)ER_PI_ZERO2W_PERIPHERAL_BASE,
                  (INT64)ER_PI_ZERO2W_PERIPHERAL_BYTES);
  out_mmio->mailbox_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_MAILBOX_OFFSET,
                             ER_PI_ZERO2W_MAILBOX_BYTES);
  out_mmio->gpio_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_GPIO_OFFSET,
                             ER_PI_ZERO2W_GPIO_BYTES);
  out_mmio->sdhost_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_SDHOST_OFFSET,
                             ER_PI_ZERO2W_SDHOST_BYTES);
  out_mmio->emmc_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_EMMC_OFFSET,
                             ER_PI_ZERO2W_EMMC_BYTES);
  out_mmio->aux_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_AUX_OFFSET,
                             ER_PI_ZERO2W_AUX_BYTES);

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

UINT32 er_pi_sdio_cmd52_argument(UINT8 write,
                                 UINT8 function,
                                 UINT8 raw,
                                 UINT32 address,
                                 UINT8 data) {
  UINT32 argument = 0u;

  if (write != 0u) {
    argument |= 1u << ER_PI_SDIO_RW_FLAG_BIT;
  }
  argument |= ((UINT32)function & ER_PI_SDIO_FUNCTION_MASK) <<
              ER_PI_SDIO_FUNCTION_BITS;
  if (raw != 0u) {
    argument |= 1u << ER_PI_SDIO_RAW_FLAG_BIT;
  }
  argument |= (address & ER_PI_SDIO_ADDRESS_MASK) << ER_PI_SDIO_ADDRESS_BITS;
  argument |= (UINT32)data;
  return argument;
}

UINT32 er_pi_sdio_cmd53_argument(UINT8 write,
                                 UINT8 function,
                                 UINT8 block_mode,
                                 UINT8 incrementing_address,
                                 UINT32 address,
                                 UINT32 count) {
  UINT32 argument = 0u;

  if (write != 0u) {
    argument |= 1u << ER_PI_SDIO_RW_FLAG_BIT;
  }
  argument |= ((UINT32)function & ER_PI_SDIO_FUNCTION_MASK) <<
              ER_PI_SDIO_FUNCTION_BITS;
  if (block_mode != 0u) {
    argument |= 1u << ER_PI_SDIO_BLOCK_MODE_BIT;
  }
  if (incrementing_address != 0u) {
    argument |= 1u << ER_PI_SDIO_INCREMENTING_ADDRESS_BIT;
  }
  argument |= (address & ER_PI_SDIO_ADDRESS_MASK) << ER_PI_SDIO_ADDRESS_BITS;
  argument |= count & ER_PI_SDIO_CMD53_COUNT_MASK;
  return argument;
}

UINT32 er_pi_mmc_relative_card_argument(UINT32 relative_card_address) {
  return (relative_card_address & ER_PI_MMC_RCA_MASK) <<
         ER_PI_MMC_RCA_ARGUMENT_BITS;
}

UINT32 er_pi_mmc_relative_card_from_r6(UINT32 response) {
  return (response >> ER_PI_MMC_RCA_ARGUMENT_BITS) & ER_PI_MMC_RCA_MASK;
}

static UINT8 er_pi_mmc_response_requires_crc(UINT32 response_kind) {
  switch (response_kind) {
    case ER_PI_MMC_RESPONSE_R1:
    case ER_PI_MMC_RESPONSE_R5:
    case ER_PI_MMC_RESPONSE_R6:
      return 1u;
    case ER_PI_MMC_RESPONSE_NONE:
    case ER_PI_MMC_RESPONSE_R4:
      return 0u;
    default:
      return 0u;
  }
}

static UINT8 er_pi_mmc_response_requires_index(UINT32 response_kind) {
  switch (response_kind) {
    case ER_PI_MMC_RESPONSE_R1:
    case ER_PI_MMC_RESPONSE_R5:
    case ER_PI_MMC_RESPONSE_R6:
      return 1u;
    case ER_PI_MMC_RESPONSE_NONE:
    case ER_PI_MMC_RESPONSE_R4:
      return 0u;
    default:
      return 0u;
  }
}

static UINT32 er_pi_emmc_response_bits(UINT32 response_kind) {
  switch (response_kind) {
    case ER_PI_MMC_RESPONSE_NONE:
      return ER_PI_EMMC_CMDTM_RESPONSE_NONE;
    case ER_PI_MMC_RESPONSE_R1:
    case ER_PI_MMC_RESPONSE_R4:
    case ER_PI_MMC_RESPONSE_R5:
    case ER_PI_MMC_RESPONSE_R6:
      return ER_PI_EMMC_CMDTM_RESPONSE_48;
    default:
      return ER_PI_EMMC_CMDTM_RESPONSE_NONE;
  }
}

static UINT32 er_pi_emmc_command_value(const ErPiMmcCommand* command) {
  UINT32 value;

  value = command->command_index << ER_PI_EMMC_CMDTM_INDEX_BITS;
  value |= er_pi_emmc_response_bits(command->response_kind) <<
           ER_PI_EMMC_CMDTM_RESPONSE_BITS;
  if (er_pi_mmc_response_requires_crc(command->response_kind) != 0u) {
    value |= ER_PI_EMMC_CMDTM_CRC_CHECK;
  }
  if (er_pi_mmc_response_requires_index(command->response_kind) != 0u) {
    value |= ER_PI_EMMC_CMDTM_INDEX_CHECK;
  }
  return value;
}

UINT8 er_pi_mmc_command_prepare(UINT32 command_index,
                                UINT32 argument,
                                UINT32 response_kind,
                                ErPiMmcCommand* out_command) {
  if (out_command == 0) {
    return 0u;
  }

  switch (command_index) {
    case ER_PI_MMC_CMD_GO_IDLE_STATE:
      if (response_kind != ER_PI_MMC_RESPONSE_NONE) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_IO_SEND_OP_COND:
      if (response_kind != ER_PI_MMC_RESPONSE_R4) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_SEND_RELATIVE_ADDR:
      if (response_kind != ER_PI_MMC_RESPONSE_R6) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_SELECT_CARD:
      if (response_kind != ER_PI_MMC_RESPONSE_R1) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_IO_RW_DIRECT:
    case ER_PI_MMC_CMD_IO_RW_EXTENDED:
      if (response_kind != ER_PI_MMC_RESPONSE_R5) {
        return 0u;
      }
      break;
    default:
      return 0u;
  }

  out_command->command_index = command_index;
  out_command->argument = argument;
  out_command->response_kind = response_kind;
  return 1u;
}

UINT8 er_pi_emmc_command_io_prepare(const ErPiMmcCommand* command,
                                    ErPiEmmcCommandIo* out_io) {
  ErPiMmcCommand prepared;

  if (command == 0 ||
      out_io == 0 ||
      er_pi_mmc_command_prepare(command->command_index,
                                command->argument,
                                command->response_kind,
                                &prepared) == 0u) {
    return 0u;
  }

  out_io->interrupt_offset = ER_PI_EMMC_REG_INTERRUPT;
  out_io->interrupt_clear_value = ER_PI_EMMC_INTERRUPT_ALL;
  out_io->argument_offset = ER_PI_EMMC_REG_ARG1;
  out_io->argument_value = prepared.argument;
  out_io->command_offset = ER_PI_EMMC_REG_CMDTM;
  out_io->command_value = er_pi_emmc_command_value(&prepared);
  out_io->response_offset = ER_PI_EMMC_REG_RESP0;
  out_io->response_kind = prepared.response_kind;
  return 1u;
}

UINT8 er_pi_emmc_command_begin(INT64 emmc_handle,
                               const ErPiMmcCommand* command,
                               ErPiEmmcCommandIo* out_io) {
  ErPiEmmcCommandIo io;

  if (out_io == 0 ||
      er_pi_emmc_command_io_prepare(command, &io) == 0u ||
      er_mmio_write32(emmc_handle,
                      (INT64)io.interrupt_offset,
                      io.interrupt_clear_value) == 0u ||
      er_mmio_write32(emmc_handle,
                      (INT64)io.argument_offset,
                      io.argument_value) == 0u ||
      er_mmio_write32(emmc_handle,
                      (INT64)io.command_offset,
                      io.command_value) == 0u) {
    return 0u;
  }

  *out_io = io;
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

UINT8 er_pi_zero2w_apply_boot_report(ErBootServicesReport* report) {
  ErPiZero2wMmio mmio;

  if (report == 0) {
    return 0u;
  }

  if (er_pi_zero2w_mmio_map(&mmio) == 0u) {
    return 0u;
  }

  if (er_boot_services_set_wifi_runtime(report,
                                        ER_BOOT_WIFI_KIND_CYW43439_SDIO,
                                        0u,
                                        ER_PI_ZERO2W_WIFI_DEFAULT_CHANNEL) == 0u ||
      er_boot_services_set_bluetooth_runtime(
          report,
          ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART,
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
