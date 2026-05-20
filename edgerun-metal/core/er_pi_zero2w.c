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
  ER_PI_EMMC_CMDTM_RESPONSE_136 = 1u,
  ER_PI_EMMC_CMDTM_RESPONSE_48 = 2u,
  ER_PI_EMMC_CMDTM_BLOCK_COUNT_ENABLE = 1u << 1u,
  ER_PI_EMMC_CMDTM_DATA_READ = 1u << 4u,
  ER_PI_EMMC_CMDTM_CRC_CHECK = 1u << 19u,
  ER_PI_EMMC_CMDTM_INDEX_CHECK = 1u << 20u,
  ER_PI_EMMC_CMDTM_IS_DATA = 1u << 21u,
  ER_PI_EMMC_CMDTM_INDEX_BITS = 24u,
  ER_PI_EMMC_BLOCK_COUNT_BITS = 16u,
  ER_PI_EMMC_WORD_BYTES = 4u,
  ER_PI_EMMC_INTERRUPT_ALL = 0xffffffffu,
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
    case ER_PI_MMC_RESPONSE_R2:
    case ER_PI_MMC_RESPONSE_R5:
    case ER_PI_MMC_RESPONSE_R6:
    case ER_PI_MMC_RESPONSE_R7:
      return 1u;
    case ER_PI_MMC_RESPONSE_NONE:
    case ER_PI_MMC_RESPONSE_R3:
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
    case ER_PI_MMC_RESPONSE_R7:
      return 1u;
    case ER_PI_MMC_RESPONSE_NONE:
    case ER_PI_MMC_RESPONSE_R2:
    case ER_PI_MMC_RESPONSE_R3:
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
    case ER_PI_MMC_RESPONSE_R2:
      return ER_PI_EMMC_CMDTM_RESPONSE_136;
    case ER_PI_MMC_RESPONSE_R1:
    case ER_PI_MMC_RESPONSE_R3:
    case ER_PI_MMC_RESPONSE_R4:
    case ER_PI_MMC_RESPONSE_R5:
    case ER_PI_MMC_RESPONSE_R6:
    case ER_PI_MMC_RESPONSE_R7:
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

static UINT8 er_pi_mmc_command_is_block_data(UINT32 command_index) {
  switch (command_index) {
    case ER_PI_MMC_CMD_READ_SINGLE_BLOCK:
    case ER_PI_MMC_CMD_WRITE_BLOCK:
      return 1u;
    default:
      return 0u;
  }
}

static UINT32 er_pi_emmc_block_command_value(const ErPiMmcCommand* command) {
  UINT32 value;

  value = er_pi_emmc_command_value(command);
  value |= ER_PI_EMMC_CMDTM_BLOCK_COUNT_ENABLE;
  value |= ER_PI_EMMC_CMDTM_IS_DATA;
  if (command->command_index == ER_PI_MMC_CMD_READ_SINGLE_BLOCK) {
    value |= ER_PI_EMMC_CMDTM_DATA_READ;
  }
  return value;
}

static UINT32 er_pi_emmc_block_size_count_value(void) {
  return (1u << ER_PI_EMMC_BLOCK_COUNT_BITS) | ER_PI_EMMC_BLOCK_BYTES;
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
    case ER_PI_MMC_CMD_ALL_SEND_CID:
      if (response_kind != ER_PI_MMC_RESPONSE_R2) {
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
    case ER_PI_MMC_CMD_SEND_IF_COND:
      if (response_kind != ER_PI_MMC_RESPONSE_R7) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_READ_SINGLE_BLOCK:
    case ER_PI_MMC_CMD_WRITE_BLOCK:
      if (response_kind != ER_PI_MMC_RESPONSE_R1) {
        return 0u;
      }
      break;
    case ER_PI_MMC_ACMD_SD_SEND_OP_COND:
      if (response_kind != ER_PI_MMC_RESPONSE_R3) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_IO_RW_DIRECT:
    case ER_PI_MMC_CMD_IO_RW_EXTENDED:
      if (response_kind != ER_PI_MMC_RESPONSE_R5) {
        return 0u;
      }
      break;
    case ER_PI_MMC_CMD_APP_CMD:
      if (response_kind != ER_PI_MMC_RESPONSE_R1) {
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
  if (er_pi_mmc_command_is_block_data(prepared.command_index) != 0u) {
    out_io->command_value = er_pi_emmc_block_command_value(&prepared);
  } else {
    out_io->command_value = er_pi_emmc_command_value(&prepared);
  }
  out_io->response_offset = ER_PI_EMMC_REG_RESP0;
  out_io->response_kind = prepared.response_kind;
  return 1u;
}

UINT8 er_pi_emmc_command_begin(INT64 emmc_handle,
                               const ErPiMmcCommand* command,
                               ErPiEmmcCommandIo* out_io) {
  ErPiEmmcCommandIo io;

  if (out_io == 0 ||
      command == 0 ||
      er_pi_mmc_command_is_block_data(command->command_index) != 0u ||
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

static void er_pi_emmc_command_result_clear(ErPiEmmcCommandResult* result) {
  if (result == 0) {
    return;
  }
  result->io.interrupt_offset = 0u;
  result->io.interrupt_clear_value = 0u;
  result->io.argument_offset = 0u;
  result->io.argument_value = 0u;
  result->io.command_offset = 0u;
  result->io.command_value = 0u;
  result->io.response_offset = 0u;
  result->io.response_kind = 0u;
  result->interrupt_value = 0u;
  result->response0 = 0u;
  result->response1 = 0u;
  result->response2 = 0u;
  result->response3 = 0u;
  result->completed = 0u;
  result->error = 0u;
}

static UINT8 er_pi_emmc_interrupt_is_error(UINT32 interrupt_value) {
  return (UINT8)((interrupt_value & ER_PI_EMMC_INTERRUPT_ERROR_MASK) != 0u);
}

static UINT8 er_pi_emmc_interrupt_is_command_done(UINT32 interrupt_value) {
  return (UINT8)((interrupt_value & ER_PI_EMMC_INTERRUPT_CMD_DONE) != 0u);
}

static UINT8 er_pi_emmc_command_finish(INT64 emmc_handle,
                                       const ErPiEmmcCommandIo* io,
                                       UINT32 interrupt_value,
                                       ErPiEmmcCommandResult* out_result) {
  INT64 response;
  INT64 response1;
  INT64 response2;
  INT64 response3;

  if (io == 0 || out_result == 0) {
    return 0u;
  }
  out_result->io = *io;
  out_result->interrupt_value = interrupt_value;
  out_result->error = er_pi_emmc_interrupt_is_error(interrupt_value);
  out_result->completed =
      (UINT8)(out_result->error == 0u &&
              er_pi_emmc_interrupt_is_command_done(interrupt_value) != 0u);
  if (io->response_kind != ER_PI_MMC_RESPONSE_NONE) {
    response = er_mmio_read32(emmc_handle, (INT64)io->response_offset);
    if (response < 0) {
      out_result->error = 1u;
      out_result->completed = 0u;
      return 0u;
    }
    out_result->response0 = (UINT32)response;
    if (io->response_kind == ER_PI_MMC_RESPONSE_R2) {
      response1 = er_mmio_read32(emmc_handle, (INT64)ER_PI_EMMC_REG_RESP1);
      response2 = er_mmio_read32(emmc_handle, (INT64)ER_PI_EMMC_REG_RESP2);
      response3 = er_mmio_read32(emmc_handle, (INT64)ER_PI_EMMC_REG_RESP3);
      if (response1 < 0 || response2 < 0 || response3 < 0) {
        out_result->error = 1u;
        out_result->completed = 0u;
        return 0u;
      }
      out_result->response1 = (UINT32)response1;
      out_result->response2 = (UINT32)response2;
      out_result->response3 = (UINT32)response3;
    }
  }
  if (er_mmio_write32(emmc_handle,
                      (INT64)io->interrupt_offset,
                      interrupt_value) == 0u) {
    out_result->error = 1u;
    out_result->completed = 0u;
    return 0u;
  }
  return out_result->completed;
}

UINT8 er_pi_emmc_command_poll(INT64 emmc_handle,
                              const ErPiEmmcCommandIo* io,
                              UINT32 poll_budget,
                              ErPiEmmcCommandResult* out_result) {
  UINT32 poll;
  INT64 interrupt;

  er_pi_emmc_command_result_clear(out_result);
  if (io == 0 || out_result == 0 || poll_budget == 0u) {
    return 0u;
  }
  for (poll = 0u; poll < poll_budget; ++poll) {
    interrupt = er_mmio_read32(emmc_handle, (INT64)io->interrupt_offset);
    if (interrupt < 0) {
      out_result->error = 1u;
      return 0u;
    }
    out_result->interrupt_value = (UINT32)interrupt;
    if (er_pi_emmc_interrupt_is_error((UINT32)interrupt) != 0u ||
        er_pi_emmc_interrupt_is_command_done((UINT32)interrupt) != 0u) {
      return er_pi_emmc_command_finish(emmc_handle,
                                       io,
                                       (UINT32)interrupt,
                                       out_result);
    }
  }
  return 0u;
}

UINT8 er_pi_emmc_command_execute(INT64 emmc_handle,
                                 const ErPiMmcCommand* command,
                                 UINT32 poll_budget,
                                 ErPiEmmcCommandResult* out_result) {
  ErPiEmmcCommandIo io;

  er_pi_emmc_command_result_clear(out_result);
  if (out_result == 0 ||
      er_pi_emmc_command_begin(emmc_handle, command, &io) == 0u) {
    return 0u;
  }
  return er_pi_emmc_command_poll(emmc_handle, &io, poll_budget, out_result);
}

static void er_pi_emmc_block_result_clear(ErPiEmmcBlockResult* result) {
  if (result == 0) {
    return;
  }
  result->io.block_size_count_offset = 0u;
  result->io.block_size_count_value = 0u;
  result->io.data_offset = 0u;
  result->io.command_io.interrupt_offset = 0u;
  result->io.command_io.interrupt_clear_value = 0u;
  result->io.command_io.argument_offset = 0u;
  result->io.command_io.argument_value = 0u;
  result->io.command_io.command_offset = 0u;
  result->io.command_io.command_value = 0u;
  result->io.command_io.response_offset = 0u;
  result->io.command_io.response_kind = 0u;
  result->io.read = 0u;
  result->interrupt_value = 0u;
  result->response0 = 0u;
  result->completed = 0u;
  result->error = 0u;
}

UINT8 er_pi_emmc_block_io_prepare(UINT32 command_index,
                                  UINT32 block_address,
                                  ErPiEmmcBlockIo* out_io) {
  ErPiMmcCommand command;

  if (out_io == 0 ||
      er_pi_mmc_command_is_block_data(command_index) == 0u ||
      er_pi_mmc_command_prepare(command_index,
                                block_address,
                                ER_PI_MMC_RESPONSE_R1,
                                &command) == 0u ||
      er_pi_emmc_command_io_prepare(&command, &out_io->command_io) == 0u) {
    return 0u;
  }

  out_io->block_size_count_offset = ER_PI_EMMC_REG_BLKSIZECNT;
  out_io->block_size_count_value = er_pi_emmc_block_size_count_value();
  out_io->data_offset = ER_PI_EMMC_REG_DATA;
  out_io->read = (UINT8)(command_index == ER_PI_MMC_CMD_READ_SINGLE_BLOCK);
  return 1u;
}

static UINT8 er_pi_emmc_poll_interrupt(INT64 emmc_handle,
                                       UINT32 needed_interrupt,
                                       UINT32 poll_budget,
                                       UINT32* out_interrupt) {
  UINT32 poll;
  INT64 interrupt;

  if (out_interrupt == 0 || needed_interrupt == 0u || poll_budget == 0u) {
    return 0u;
  }
  *out_interrupt = 0u;
  for (poll = 0u; poll < poll_budget; ++poll) {
    interrupt = er_mmio_read32(emmc_handle, (INT64)ER_PI_EMMC_REG_INTERRUPT);
    if (interrupt < 0) {
      return 0u;
    }
    *out_interrupt = (UINT32)interrupt;
    if (er_pi_emmc_interrupt_is_error((UINT32)interrupt) != 0u) {
      return 0u;
    }
    if (((UINT32)interrupt & needed_interrupt) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_pi_emmc_block_begin(INT64 emmc_handle,
                                    const ErPiEmmcBlockIo* io) {
  if (io == 0 ||
      er_mmio_write32(emmc_handle,
                      (INT64)io->command_io.interrupt_offset,
                      io->command_io.interrupt_clear_value) == 0u ||
      er_mmio_write32(emmc_handle,
                      (INT64)io->block_size_count_offset,
                      io->block_size_count_value) == 0u ||
      er_mmio_write32(emmc_handle,
                      (INT64)io->command_io.argument_offset,
                      io->command_io.argument_value) == 0u ||
      er_mmio_write32(emmc_handle,
                      (INT64)io->command_io.command_offset,
                      io->command_io.command_value) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_pi_emmc_wait_data_done(INT64 emmc_handle,
                                       UINT32 poll_budget,
                                       ErPiEmmcBlockResult* out_result) {
  UINT32 interrupt;
  INT64 response;

  if (out_result == 0 ||
      er_pi_emmc_poll_interrupt(emmc_handle,
                                ER_PI_EMMC_INTERRUPT_DATA_DONE,
                                poll_budget,
                                &interrupt) == 0u) {
    if (out_result != 0) {
      out_result->error = 1u;
    }
    return 0u;
  }
  out_result->interrupt_value = interrupt;
  response = er_mmio_read32(emmc_handle,
                            (INT64)out_result->io.command_io.response_offset);
  if (response < 0 ||
      er_mmio_write32(emmc_handle,
                      (INT64)out_result->io.command_io.interrupt_offset,
                      interrupt) == 0u) {
    out_result->error = 1u;
    return 0u;
  }
  out_result->response0 = (UINT32)response;
  out_result->completed = 1u;
  return 1u;
}

UINT8 er_pi_emmc_read_block(INT64 emmc_handle,
                            UINT32 block_address,
                            UINT8* out_block,
                            UINT32 poll_budget,
                            ErPiEmmcBlockResult* out_result) {
  UINT32 word_index;
  UINT32 interrupt;
  INT64 data_word;
  ErPiEmmcBlockIo io;

  er_pi_emmc_block_result_clear(out_result);
  if (out_block == 0 ||
      out_result == 0 ||
      er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_READ_SINGLE_BLOCK,
                                  block_address,
                                  &io) == 0u ||
      er_pi_emmc_block_begin(emmc_handle, &io) == 0u ||
      er_pi_emmc_poll_interrupt(emmc_handle,
                                ER_PI_EMMC_INTERRUPT_READ_RDY,
                                poll_budget,
                                &interrupt) == 0u) {
    if (out_result != 0) {
      out_result->error = 1u;
      out_result->interrupt_value = 0u;
    }
    return 0u;
  }

  out_result->io = io;
  out_result->interrupt_value = interrupt;
  for (word_index = 0u;
       word_index < ER_PI_EMMC_BLOCK_BYTES / ER_PI_EMMC_WORD_BYTES;
       ++word_index) {
    data_word = er_mmio_read32(emmc_handle, (INT64)io.data_offset);
    if (data_word < 0) {
      out_result->error = 1u;
      return 0u;
    }
    out_block[(word_index * ER_PI_EMMC_WORD_BYTES)] =
        (UINT8)((UINT32)data_word);
    out_block[(word_index * ER_PI_EMMC_WORD_BYTES) + 1u] =
        (UINT8)((UINT32)data_word >> 8u);
    out_block[(word_index * ER_PI_EMMC_WORD_BYTES) + 2u] =
        (UINT8)((UINT32)data_word >> 16u);
    out_block[(word_index * ER_PI_EMMC_WORD_BYTES) + 3u] =
        (UINT8)((UINT32)data_word >> 24u);
  }
  return er_pi_emmc_wait_data_done(emmc_handle, poll_budget, out_result);
}

UINT8 er_pi_emmc_write_block(INT64 emmc_handle,
                             UINT32 block_address,
                             const UINT8* block,
                             UINT32 poll_budget,
                             ErPiEmmcBlockResult* out_result) {
  UINT32 word_index;
  UINT32 word_value;
  UINT32 interrupt;
  ErPiEmmcBlockIo io;

  er_pi_emmc_block_result_clear(out_result);
  if (block == 0 ||
      out_result == 0 ||
      er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_WRITE_BLOCK,
                                  block_address,
                                  &io) == 0u ||
      er_pi_emmc_block_begin(emmc_handle, &io) == 0u ||
      er_pi_emmc_poll_interrupt(emmc_handle,
                                ER_PI_EMMC_INTERRUPT_WRITE_RDY,
                                poll_budget,
                                &interrupt) == 0u) {
    if (out_result != 0) {
      out_result->error = 1u;
      out_result->interrupt_value = 0u;
    }
    return 0u;
  }

  out_result->io = io;
  out_result->interrupt_value = interrupt;
  for (word_index = 0u;
       word_index < ER_PI_EMMC_BLOCK_BYTES / ER_PI_EMMC_WORD_BYTES;
       ++word_index) {
    word_value = (UINT32)block[word_index * ER_PI_EMMC_WORD_BYTES];
    word_value |=
        (UINT32)block[(word_index * ER_PI_EMMC_WORD_BYTES) + 1u] << 8u;
    word_value |=
        (UINT32)block[(word_index * ER_PI_EMMC_WORD_BYTES) + 2u] << 16u;
    word_value |=
        (UINT32)block[(word_index * ER_PI_EMMC_WORD_BYTES) + 3u] << 24u;
    if (er_mmio_write32(emmc_handle, (INT64)io.data_offset, word_value) ==
        0u) {
      out_result->error = 1u;
      return 0u;
    }
  }
  return er_pi_emmc_wait_data_done(emmc_handle, poll_budget, out_result);
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
