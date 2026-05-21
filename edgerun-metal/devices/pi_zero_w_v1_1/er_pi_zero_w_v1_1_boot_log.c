#include "er_pi_zero_w_v1_1_boot_log.h"
#include "er_mem.h"

enum {
  ER_PI_ZERO_W_V1_1_BOOT_LOG_MAGIC = 0x4c425245u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_VERSION = 1u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_U32_BYTES = 4u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_BYTE_BITS = 8u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_MAGIC_OFFSET = 0u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_VERSION_OFFSET = 4u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_RECORD_BYTES_OFFSET = 8u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_BOOT_ID_OFFSET = 12u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_SEQUENCE_OFFSET = 16u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_DROPPED_OFFSET = 20u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_OFFSET = 24u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG0_OFFSET = 28u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG1_OFFSET = 32u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG2_OFFSET = 36u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG3_OFFSET = 40u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_OFFSET = 508u,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_INITIAL = 0xffffffffu,
  ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_POLY = 0xedb88320u
};

static void er_pi_zero_w_v1_1_boot_log_put_le32(UINT8* out, UINT32 value) {
  out[0] = (UINT8)value;
  out[1] = (UINT8)(value >> ER_PI_ZERO_W_V1_1_BOOT_LOG_BYTE_BITS);
  out[2] = (UINT8)(value >> (ER_PI_ZERO_W_V1_1_BOOT_LOG_BYTE_BITS * 2u));
  out[3] = (UINT8)(value >> (ER_PI_ZERO_W_V1_1_BOOT_LOG_BYTE_BITS * 3u));
}

static UINT32 er_pi_zero_w_v1_1_boot_log_crc32(const UINT8* bytes,
                                               UINT32 len) {
  UINT32 crc = ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_INITIAL;
  UINT32 i;

  if (bytes == 0) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    UINT32 bit;
    crc ^= (UINT32)bytes[i];
    for (bit = 0u; bit < ER_PI_ZERO_W_V1_1_BOOT_LOG_BYTE_BITS; ++bit) {
      UINT32 mask = 0u - (crc & 1u);
      crc = (crc >> 1u) ^ (ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_POLY & mask);
    }
  }
  return ~crc;
}

static UINT8 er_pi_zero_w_v1_1_boot_log_write_event(
    ErPiZeroWV11BootLog* log,
    const ErPiZeroWV11BootLogEvent* event) {
  UINT8 block[ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES];
  UINT32 sequence;
  UINT32 block_address;
  UINT32 crc;

  if (log == 0 ||
      event == 0 ||
      log->write_block == 0 ||
      log->storage_enabled == 0u) {
    return 0u;
  }
  sequence = log->next_sequence;
  block_address =
      ER_PI_ZERO_W_V1_1_BOOT_LOG_START_BLOCK +
      (sequence % ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_COUNT);
  er_mem_zero(block, (UINTN)sizeof(block));
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_MAGIC_OFFSET,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_MAGIC);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_VERSION_OFFSET,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_VERSION);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_RECORD_BYTES_OFFSET,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_BOOT_ID_OFFSET,
      log->boot_id);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_SEQUENCE_OFFSET,
      sequence);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_DROPPED_OFFSET,
      log->dropped_count);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_OFFSET,
      event->event);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG0_OFFSET,
      event->arg0);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG1_OFFSET,
      event->arg1);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG2_OFFSET,
      event->arg2);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_ARG3_OFFSET,
      event->arg3);
  crc = er_pi_zero_w_v1_1_boot_log_crc32(
      block,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_OFFSET);
  er_pi_zero_w_v1_1_boot_log_put_le32(
      block + ER_PI_ZERO_W_V1_1_BOOT_LOG_CRC_OFFSET,
      crc);
  if (log->write_block(log->write_ctx, block_address, block) == 0u) {
    return 0u;
  }
  log->next_sequence = sequence + 1u;
  return 1u;
}

void er_pi_zero_w_v1_1_boot_log_init(ErPiZeroWV11BootLog* log,
                                     UINT32 boot_id) {
  if (log == 0) {
    return;
  }
  er_mem_zero((UINT8*)log, (UINTN)sizeof(*log));
  log->boot_id = boot_id;
}

UINT8 er_pi_zero_w_v1_1_boot_log_enable_storage(
    ErPiZeroWV11BootLog* log,
    ErPiZeroWV11BootLogWriteBlockFn write_block,
    void* write_ctx) {
  UINT32 i;

  if (log == 0 || write_block == 0) {
    return 0u;
  }
  log->write_block = write_block;
  log->write_ctx = write_ctx;
  log->storage_enabled = 1u;
  for (i = 0u; i < log->pending_count; ++i) {
    if (er_pi_zero_w_v1_1_boot_log_write_event(log,
                                               &log->pending[i]) == 0u) {
      log->storage_enabled = 0u;
      return 0u;
    }
  }
  log->pending_count = 0u;
  return 1u;
}

UINT8 er_pi_zero_w_v1_1_boot_log_append(ErPiZeroWV11BootLog* log,
                                        UINT32 event,
                                        UINT32 arg0,
                                        UINT32 arg1,
                                        UINT32 arg2,
                                        UINT32 arg3) {
  ErPiZeroWV11BootLogEvent log_event;

  if (log == 0 || event == 0u) {
    return 0u;
  }
  log_event.event = event;
  log_event.arg0 = arg0;
  log_event.arg1 = arg1;
  log_event.arg2 = arg2;
  log_event.arg3 = arg3;
  if (log->storage_enabled != 0u) {
    return er_pi_zero_w_v1_1_boot_log_write_event(log, &log_event);
  }
  if (log->pending_count >= ER_PI_ZERO_W_V1_1_BOOT_LOG_PENDING_COUNT) {
    ++log->dropped_count;
    return 0u;
  }
  log->pending[log->pending_count] = log_event;
  ++log->pending_count;
  return 1u;
}
