#include "er_pi_mmc.h"
#include "er_mem.h"

/*
 * Purpose: own Raspberry Pi EMMC/MMC/SDIO command and block transfer helpers.
 * Intention: keep register sequencing shared while board folders own policy.
 */

enum {
  ER_PI_SDIO_FUNCTION_BITS = 28u,
  ER_PI_SDIO_RAW_FLAG_BIT = 27u,
  ER_PI_SDIO_BLOCK_MODE_BIT = 27u,
  ER_PI_SDIO_INCREMENTING_ADDRESS_BIT = 26u,
  ER_PI_SDIO_ADDRESS_BITS = 9u,
  ER_PI_SDIO_RW_FLAG_BIT = 31u,
  ER_PI_SDIO_FUNCTION_MASK = 0x07u,
  ER_PI_SDIO_ADDRESS_MASK = 0x0001ffffu,
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
  ER_PI_EMMC_WORD_BYTES = 4u,
  ER_PI_EMMC_SDIO_BYTE_TRANSFER_MAX = 512u
};

typedef struct {
  INT64 handle;
} ErPiEmmcMmioHandleCtx;

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

static UINT8 er_pi_mmc_command_requires_data_path(UINT32 command_index) {
  switch (command_index) {
    case ER_PI_MMC_CMD_READ_SINGLE_BLOCK:
    case ER_PI_MMC_CMD_WRITE_BLOCK:
    case ER_PI_MMC_CMD_IO_RW_EXTENDED:
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
      er_pi_mmc_command_requires_data_path(command->command_index) != 0u ||
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

static UINT8 er_pi_emmc_handle_read32(void* ctx,
                                      UINT32 offset,
                                      UINT32* out_value) {
  ErPiEmmcMmioHandleCtx* handle_ctx = (ErPiEmmcMmioHandleCtx*)ctx;
  INT64 value;

  if (handle_ctx == 0 || out_value == 0) {
    return 0u;
  }
  value = er_mmio_read32(handle_ctx->handle, (INT64)offset);
  if (value < 0) {
    return 0u;
  }
  *out_value = (UINT32)value;
  return 1u;
}

static UINT8 er_pi_emmc_handle_write32(void* ctx,
                                       UINT32 offset,
                                       UINT32 value) {
  ErPiEmmcMmioHandleCtx* handle_ctx = (ErPiEmmcMmioHandleCtx*)ctx;

  if (handle_ctx == 0) {
    return 0u;
  }
  return er_mmio_write32(handle_ctx->handle, (INT64)offset, value);
}

static UINT8 er_pi_emmc_mmio_ops_valid32(const ErPiEmmcMmioOps* ops) {
  if (ops == 0 || ops->read32 == 0 || ops->write32 == 0) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_pi_emmc_poll_interrupt_with_ops(
    const ErPiEmmcMmioOps* ops,
    UINT32 needed_interrupt,
    UINT32 poll_budget,
    UINT32* out_interrupt) {
  UINT32 poll;
  UINT32 interrupt;

  if (er_pi_emmc_mmio_ops_valid32(ops) == 0u ||
      out_interrupt == 0 ||
      needed_interrupt == 0u ||
      poll_budget == 0u) {
    return 0u;
  }
  *out_interrupt = 0u;
  for (poll = 0u; poll < poll_budget; ++poll) {
    if (ops->read32(ops->ctx, ER_PI_EMMC_REG_INTERRUPT, &interrupt) == 0u) {
      return 0u;
    }
    *out_interrupt = interrupt;
    if (er_pi_emmc_interrupt_is_error(interrupt) != 0u) {
      return 0u;
    }
    if ((interrupt & needed_interrupt) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_pi_emmc_block_begin_with_ops(const ErPiEmmcMmioOps* ops,
                                             const ErPiEmmcBlockIo* io) {
  if (er_pi_emmc_mmio_ops_valid32(ops) == 0u ||
      io == 0 ||
      ops->write32(ops->ctx,
                   io->command_io.interrupt_offset,
                   io->command_io.interrupt_clear_value) == 0u ||
      ops->write32(ops->ctx,
                   io->block_size_count_offset,
                   io->block_size_count_value) == 0u ||
      ops->write32(ops->ctx,
                   io->command_io.argument_offset,
                   io->command_io.argument_value) == 0u ||
      ops->write32(ops->ctx,
                   io->command_io.command_offset,
                   io->command_io.command_value) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_pi_emmc_wait_data_done_with_ops(
    const ErPiEmmcMmioOps* ops,
    UINT32 poll_budget,
    ErPiEmmcBlockResult* out_result) {
  UINT32 interrupt;
  UINT32 response;

  if (out_result == 0 ||
      er_pi_emmc_poll_interrupt_with_ops(ops,
                                         ER_PI_EMMC_INTERRUPT_DATA_DONE,
                                         poll_budget,
                                         &interrupt) == 0u) {
    if (out_result != 0) {
      out_result->error = 1u;
    }
    return 0u;
  }
  out_result->interrupt_value = interrupt;
  if (ops->read32(ops->ctx,
                  out_result->io.command_io.response_offset,
                  &response) == 0u ||
      ops->write32(ops->ctx,
                   out_result->io.command_io.interrupt_offset,
                   interrupt) == 0u) {
    out_result->error = 1u;
    return 0u;
  }
  out_result->response0 = response;
  out_result->completed = 1u;
  return 1u;
}

UINT8 er_pi_emmc_read_block_with_ops(const ErPiEmmcMmioOps* ops,
                                     UINT32 block_address,
                                     UINT8* out_block,
                                     UINT32 poll_budget,
                                     ErPiEmmcBlockResult* out_result) {
  UINT32 word_index;
  UINT32 interrupt;
  UINT32 data_word;
  ErPiEmmcBlockIo io;

  er_pi_emmc_block_result_clear(out_result);
  if (er_pi_emmc_mmio_ops_valid32(ops) == 0u ||
      out_block == 0 ||
      out_result == 0 ||
      er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_READ_SINGLE_BLOCK,
                                  block_address,
                                  &io) == 0u ||
      er_pi_emmc_block_begin_with_ops(ops, &io) == 0u ||
      er_pi_emmc_poll_interrupt_with_ops(ops,
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
    if (ops->read32(ops->ctx, io.data_offset, &data_word) == 0u) {
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
  return er_pi_emmc_wait_data_done_with_ops(ops, poll_budget, out_result);
}

UINT8 er_pi_emmc_write_block_with_ops(const ErPiEmmcMmioOps* ops,
                                      UINT32 block_address,
                                      const UINT8* block,
                                      UINT32 poll_budget,
                                      ErPiEmmcBlockResult* out_result) {
  UINT32 word_index;
  UINT32 word_value;
  UINT32 interrupt;
  ErPiEmmcBlockIo io;

  er_pi_emmc_block_result_clear(out_result);
  if (er_pi_emmc_mmio_ops_valid32(ops) == 0u ||
      block == 0 ||
      out_result == 0 ||
      er_pi_emmc_block_io_prepare(ER_PI_MMC_CMD_WRITE_BLOCK,
                                  block_address,
                                  &io) == 0u ||
      er_pi_emmc_block_begin_with_ops(ops, &io) == 0u ||
      er_pi_emmc_poll_interrupt_with_ops(ops,
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
    if (ops->write32(ops->ctx, io.data_offset, word_value) == 0u) {
      out_result->error = 1u;
      return 0u;
    }
  }
  return er_pi_emmc_wait_data_done_with_ops(ops, poll_budget, out_result);
}

UINT8 er_pi_emmc_read_block(INT64 emmc_handle,
                            UINT32 block_address,
                            UINT8* out_block,
                            UINT32 poll_budget,
                            ErPiEmmcBlockResult* out_result) {
  ErPiEmmcMmioHandleCtx ctx;
  ErPiEmmcMmioOps ops;

  ctx.handle = emmc_handle;
  ops.ctx = &ctx;
  ops.read32 = er_pi_emmc_handle_read32;
  ops.write32 = er_pi_emmc_handle_write32;
  ops.read8 = 0;
  ops.write8 = 0;
  return er_pi_emmc_read_block_with_ops(&ops,
                                        block_address,
                                        out_block,
                                        poll_budget,
                                        out_result);
}

UINT8 er_pi_emmc_write_block(INT64 emmc_handle,
                             UINT32 block_address,
                             const UINT8* block,
                             UINT32 poll_budget,
                             ErPiEmmcBlockResult* out_result) {
  ErPiEmmcMmioHandleCtx ctx;
  ErPiEmmcMmioOps ops;

  ctx.handle = emmc_handle;
  ops.ctx = &ctx;
  ops.read32 = er_pi_emmc_handle_read32;
  ops.write32 = er_pi_emmc_handle_write32;
  ops.read8 = 0;
  ops.write8 = 0;
  return er_pi_emmc_write_block_with_ops(&ops,
                                         block_address,
                                         block,
                                         poll_budget,
                                         out_result);
}

static void er_pi_emmc_sdio_transfer_result_clear(
    ErPiEmmcSdioTransferResult* result) {
  if (result == 0) {
    return;
  }
  er_mem_zero((UINT8*)result, (UINTN)sizeof(*result));
}

static UINT8 er_pi_sdio_function_valid(UINT8 function) {
  switch (function) {
    case ER_PI_SDIO_FUNCTION_BACKPLANE:
    case ER_PI_SDIO_FUNCTION_WLAN:
      return 1u;
    default:
      return 0u;
  }
}

static UINT32 er_pi_emmc_sdio_transfer_size_count(UINT32 data_len) {
  return (1u << ER_PI_EMMC_BLOCK_COUNT_BITS) | data_len;
}

static UINT8 er_pi_sdio_block_mode_valid(UINT8 block_mode) {
  switch (block_mode) {
    case ER_PI_SDIO_CMD53_BYTE_MODE:
    case ER_PI_SDIO_CMD53_BLOCK_MODE:
      return 1u;
    default:
      return 0u;
  }
}

static UINT32 er_pi_emmc_sdio_block_size_count(UINT8 block_mode,
                                               UINT32 block_size,
                                               UINT32 transfer_count,
                                               UINT32 data_len) {
  switch (block_mode) {
    case ER_PI_SDIO_CMD53_BYTE_MODE:
      return er_pi_emmc_sdio_transfer_size_count(data_len);
    case ER_PI_SDIO_CMD53_BLOCK_MODE:
      return (transfer_count << ER_PI_EMMC_BLOCK_COUNT_BITS) | block_size;
    default:
      return 0u;
  }
}

UINT8 er_pi_emmc_sdio_transfer_io_prepare(UINT8 write,
                                           UINT8 function,
                                           UINT8 block_mode,
                                           UINT8 incrementing_address,
                                           UINT32 address,
                                           UINT32 block_size,
                                           UINT32 transfer_count,
                                           UINT32 data_len,
                                           ErPiEmmcSdioTransferIo* out_io) {
  ErPiMmcCommand command;
  UINT32 argument;

  if (out_io == 0 ||
      er_pi_sdio_function_valid(function) == 0u ||
      er_pi_sdio_block_mode_valid(block_mode) == 0u ||
      data_len == 0u ||
      block_size == 0u ||
      transfer_count == 0u ||
      transfer_count > ER_PI_SDIO_CMD53_COUNT_MASK ||
      address > ER_PI_SDIO_ADDRESS_MASK) {
    return 0u;
  }
  if (block_mode == ER_PI_SDIO_CMD53_BYTE_MODE &&
      (data_len > ER_PI_EMMC_SDIO_BYTE_TRANSFER_MAX ||
       block_size != data_len ||
       transfer_count != data_len)) {
    return 0u;
  }

  argument = er_pi_sdio_cmd53_argument(write,
                                       function,
                                       block_mode,
                                       incrementing_address,
                                       address,
                                       transfer_count);
  if (er_pi_mmc_command_prepare(ER_PI_MMC_CMD_IO_RW_EXTENDED,
                                argument,
                                ER_PI_MMC_RESPONSE_R5,
                                &command) == 0u ||
      er_pi_emmc_command_io_prepare(&command, &out_io->command_io) == 0u) {
    return 0u;
  }

  out_io->block_size_count_offset = ER_PI_EMMC_REG_BLKSIZECNT;
  out_io->block_size_count_value =
      er_pi_emmc_sdio_block_size_count(block_mode,
                                       block_size,
                                       transfer_count,
                                       data_len);
  out_io->data_offset = ER_PI_EMMC_REG_DATA;
  out_io->data_len = data_len;
  out_io->read = (UINT8)(write == ER_PI_SDIO_READ);
  out_io->command_io.command_value |= ER_PI_EMMC_CMDTM_BLOCK_COUNT_ENABLE;
  out_io->command_io.command_value |= ER_PI_EMMC_CMDTM_IS_DATA;
  if (out_io->read != 0u) {
    out_io->command_io.command_value |= ER_PI_EMMC_CMDTM_DATA_READ;
  }
  return 1u;
}

static UINT8 er_pi_emmc_sdio_transfer_begin(
    INT64 emmc_handle,
    const ErPiEmmcSdioTransferIo* io) {
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

static UINT8 er_pi_emmc_sdio_transfer_done(
    INT64 emmc_handle,
    UINT32 poll_budget,
    ErPiEmmcSdioTransferResult* out_result) {
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

static UINT32 er_pi_emmc_sdio_transfer_ready_interrupt(UINT8 write) {
  switch (write) {
    case ER_PI_SDIO_READ:
      return ER_PI_EMMC_INTERRUPT_READ_RDY;
    case ER_PI_SDIO_WRITE:
      return ER_PI_EMMC_INTERRUPT_WRITE_RDY;
    default:
      return 0u;
  }
}

static UINT8 er_pi_emmc_sdio_move_byte(INT64 emmc_handle,
                                       UINT32 data_offset,
                                       UINT8 write,
                                       const UINT8* write_bytes,
                                       UINT8* read_bytes,
                                       UINT32 byte_index) {
  INT64 value;

  switch (write) {
    case ER_PI_SDIO_READ:
      if (read_bytes == 0) {
        return 0u;
      }
      value = er_mmio_read8(emmc_handle, (INT64)data_offset);
      if (value < 0) {
        return 0u;
      }
      read_bytes[byte_index] = (UINT8)value;
      return 1u;
    case ER_PI_SDIO_WRITE:
      if (write_bytes == 0) {
        return 0u;
      }
      return er_mmio_write8(emmc_handle,
                            (INT64)data_offset,
                            write_bytes[byte_index]);
    default:
      return 0u;
  }
}

static UINT8 er_pi_emmc_sdio_transfer_bytes(
    INT64 emmc_handle,
    UINT8 write,
    UINT8 function,
    UINT8 incrementing_address,
    UINT32 address,
    const UINT8* write_bytes,
    UINT8* read_bytes,
    UINT32 bytes_len,
    UINT32 poll_budget,
    ErPiEmmcSdioTransferResult* out_result) {
  UINT32 byte_index;
  UINT32 interrupt;
  UINT32 ready_interrupt;
  ErPiEmmcSdioTransferIo io;

  er_pi_emmc_sdio_transfer_result_clear(out_result);
  ready_interrupt = er_pi_emmc_sdio_transfer_ready_interrupt(write);
  if (ready_interrupt == 0u ||
      (write == ER_PI_SDIO_READ && read_bytes == 0) ||
      (write == ER_PI_SDIO_WRITE && write_bytes == 0) ||
      out_result == 0 ||
      er_pi_emmc_sdio_transfer_io_prepare(write,
                                          function,
                                          ER_PI_SDIO_CMD53_BYTE_MODE,
                                          incrementing_address,
                                          address,
                                          bytes_len,
                                          bytes_len,
                                          bytes_len,
                                          &io) == 0u ||
      er_pi_emmc_sdio_transfer_begin(emmc_handle, &io) == 0u ||
      er_pi_emmc_poll_interrupt(emmc_handle,
                                ready_interrupt,
                                poll_budget,
                                &interrupt) == 0u) {
    if (out_result != 0) {
      out_result->error = 1u;
    }
    return 0u;
  }
  out_result->io = io;
  out_result->interrupt_value = interrupt;
  for (byte_index = 0u; byte_index < bytes_len; ++byte_index) {
    if (er_pi_emmc_sdio_move_byte(emmc_handle,
                                  io.data_offset,
                                  write,
                                  write_bytes,
                                  read_bytes,
                                  byte_index) == 0u) {
      out_result->error = 1u;
      return 0u;
    }
  }
  return er_pi_emmc_sdio_transfer_done(emmc_handle, poll_budget, out_result);
}

UINT8 er_pi_emmc_sdio_read_bytes(INT64 emmc_handle,
                                 UINT8 function,
                                 UINT8 incrementing_address,
                                 UINT32 address,
                                 UINT8* out_bytes,
                                 UINT32 bytes_len,
                                 UINT32 poll_budget,
                                 ErPiEmmcSdioTransferResult* out_result) {
  return er_pi_emmc_sdio_transfer_bytes(emmc_handle,
                                        ER_PI_SDIO_READ,
                                        function,
                                        incrementing_address,
                                        address,
                                        0,
                                        out_bytes,
                                        bytes_len,
                                        poll_budget,
                                        out_result);
}

UINT8 er_pi_emmc_sdio_write_bytes(INT64 emmc_handle,
                                  UINT8 function,
                                  UINT8 incrementing_address,
                                  UINT32 address,
                                  const UINT8* bytes,
                                  UINT32 bytes_len,
                                  UINT32 poll_budget,
                                  ErPiEmmcSdioTransferResult* out_result) {
  return er_pi_emmc_sdio_transfer_bytes(emmc_handle,
                                        ER_PI_SDIO_WRITE,
                                        function,
                                        incrementing_address,
                                        address,
                                        bytes,
                                        0,
                                        bytes_len,
                                        poll_budget,
                                        out_result);
}
