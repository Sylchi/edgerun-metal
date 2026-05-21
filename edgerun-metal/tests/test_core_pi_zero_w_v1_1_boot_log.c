#include "test_core_internal.h"

enum {
  TEST_PI_BOOT_LOG_BLOCKS = 4u,
  TEST_PI_BOOT_LOG_BOOT_ID = 0x12345678u,
  TEST_PI_BOOT_LOG_MAGIC = 0x4c425245u,
  TEST_PI_BOOT_LOG_VERSION = 1u,
  TEST_PI_BOOT_LOG_EVENT_OFFSET = 24u,
  TEST_PI_BOOT_LOG_ARG0_OFFSET = 28u,
  TEST_PI_BOOT_LOG_SEQUENCE_OFFSET = 16u,
  TEST_PI_BOOT_LOG_DROPPED_OFFSET = 20u
};

typedef struct {
  UINT32 calls;
  UINT32 block_address[TEST_PI_BOOT_LOG_BLOCKS];
  UINT8 block[TEST_PI_BOOT_LOG_BLOCKS]
             [ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES];
} TestPiBootLogIo;

static UINT32 test_pi_boot_log_get_le32(const UINT8* bytes) {
  return (UINT32)bytes[0] |
         ((UINT32)bytes[1] << 8u) |
         ((UINT32)bytes[2] << 16u) |
         ((UINT32)bytes[3] << 24u);
}

static UINT8 test_pi_boot_log_write(
    void* ctx,
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES]) {
  TestPiBootLogIo* io = (TestPiBootLogIo*)ctx;

  if (io == 0 || block == 0 || io->calls >= TEST_PI_BOOT_LOG_BLOCKS) {
    return 0u;
  }
  io->block_address[io->calls] = block_address;
  er_mem_copy(io->block[io->calls],
              block,
              ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES);
  ++io->calls;
  return 1u;
}

static void test_pi_zero_w_v1_1_boot_log(void) {
  ErPiZeroWV11BootLog log;
  TestPiBootLogIo io;

  er_mem_zero((UINT8*)&io, (UINTN)sizeof(io));
  er_pi_zero_w_v1_1_boot_log_init(&log, TEST_PI_BOOT_LOG_BOOT_ID);
  check_int64("pi boot log queues before storage",
              er_pi_zero_w_v1_1_boot_log_append(
                  &log,
                  ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_BOOT_ENTRY,
                  1u,
                  2u,
                  3u,
                  4u),
              1);
  check_uint64("pi boot log no storage write", io.calls, 0u);
  check_int64("pi boot log enables storage",
              er_pi_zero_w_v1_1_boot_log_enable_storage(
                  &log,
                  test_pi_boot_log_write,
                  &io),
              1);
  check_uint64("pi boot log flushed queued", io.calls, 1u);
  check_uint64("pi boot log first block",
               io.block_address[0],
               ER_PI_ZERO_W_V1_1_BOOT_LOG_START_BLOCK);
  check_uint64("pi boot log magic",
               test_pi_boot_log_get_le32(io.block[0]),
               TEST_PI_BOOT_LOG_MAGIC);
  check_uint64("pi boot log version",
               test_pi_boot_log_get_le32(io.block[0] + 4u),
               TEST_PI_BOOT_LOG_VERSION);
  check_uint64("pi boot log sequence",
               test_pi_boot_log_get_le32(
                   io.block[0] + TEST_PI_BOOT_LOG_SEQUENCE_OFFSET),
               0u);
  check_uint64("pi boot log event",
               test_pi_boot_log_get_le32(
                   io.block[0] + TEST_PI_BOOT_LOG_EVENT_OFFSET),
               ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_BOOT_ENTRY);
  check_uint64("pi boot log arg0",
               test_pi_boot_log_get_le32(
                   io.block[0] + TEST_PI_BOOT_LOG_ARG0_OFFSET),
               1u);
  check_int64("pi boot log writes live event",
              er_pi_zero_w_v1_1_boot_log_append(
                  &log,
                  ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_STORAGE_READY,
                  5u,
                  6u,
                  7u,
                  8u),
              1);
  check_uint64("pi boot log live calls", io.calls, 2u);
  check_uint64("pi boot log live sequence",
               test_pi_boot_log_get_le32(
                   io.block[1] + TEST_PI_BOOT_LOG_SEQUENCE_OFFSET),
               1u);
  check_uint64("pi boot log dropped count",
               test_pi_boot_log_get_le32(
                   io.block[1] + TEST_PI_BOOT_LOG_DROPPED_OFFSET),
               0u);
}
