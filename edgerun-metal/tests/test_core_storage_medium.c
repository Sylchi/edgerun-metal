#include "test_core_internal.h"

enum {
  TEST_STORAGE_MEDIUM_IO_BYTES = 65536u,
  TEST_STORAGE_MEDIUM_ARENA_BYTES = ER_STORE_ARENA_MIN_SIZE,
  TEST_STORAGE_MEDIUM_BLOCK_BYTES = 512u,
  TEST_STORAGE_MEDIUM_TOTAL_BLOCKS = 8192u,
  TEST_STORAGE_MEDIUM_BENCH_BLOCKS = 64u,
  TEST_STORAGE_MEDIUM_WRITE_BPS = 2000u,
  TEST_STORAGE_MEDIUM_VERIFY_BPS = 1800u,
  TEST_STORAGE_MEDIUM_READ_BPS = 3000u,
  TEST_STORAGE_MEDIUM_STORE_ID_SEED = 0x42u,
  TEST_STORAGE_MEDIUM_CLOCK_SEED = 0x24u
};

typedef struct {
  UINT8 bytes[TEST_STORAGE_MEDIUM_IO_BYTES];
  UINT64 size;
  UINT32 sync_count;
} TestStorageMediumIo;

typedef struct {
  UINT32 calls;
  ErStorageMediumBenchmark benchmark;
} TestStorageMediumBenchCtx;

static int test_storage_medium_read_at(void* ctx,
                                       uint64_t off,
                                       void* buf,
                                       size_t len) {
  TestStorageMediumIo* io = (TestStorageMediumIo*)ctx;

  if (io == 0 || buf == 0 || off > io->size ||
      len > (size_t)(io->size - off)) {
    return -1;
  }
  er_mem_copy((UINT8*)buf, io->bytes + off, (UINTN)len);
  return 0;
}

static int test_storage_medium_write_at(void* ctx,
                                        uint64_t off,
                                        const void* buf,
                                        size_t len) {
  TestStorageMediumIo* io = (TestStorageMediumIo*)ctx;
  UINT64 end = off + (UINT64)len;

  if (io == 0 || (len != 0u && buf == 0) || end < off ||
      end > TEST_STORAGE_MEDIUM_IO_BYTES) {
    return -1;
  }
  if (off > io->size) {
    er_mem_zero(io->bytes + io->size, (UINTN)(off - io->size));
  }
  er_mem_copy(io->bytes + off, (const UINT8*)buf, (UINTN)len);
  if (end > io->size) {
    io->size = end;
  }
  return 0;
}

static int test_storage_medium_sync(void* ctx) {
  TestStorageMediumIo* io = (TestStorageMediumIo*)ctx;

  if (io == 0) {
    return -1;
  }
  ++io->sync_count;
  return 0;
}

static int test_storage_medium_size(void* ctx, uint64_t* out_size) {
  TestStorageMediumIo* io = (TestStorageMediumIo*)ctx;

  if (io == 0 || out_size == 0) {
    return -1;
  }
  *out_size = io->size;
  return 0;
}

static int test_storage_medium_truncate(void* ctx, uint64_t size) {
  TestStorageMediumIo* io = (TestStorageMediumIo*)ctx;

  if (io == 0 || size > TEST_STORAGE_MEDIUM_IO_BYTES) {
    return -1;
  }
  if (size > io->size) {
    er_mem_zero(io->bytes + io->size, (UINTN)(size - io->size));
  }
  io->size = size;
  return 0;
}

static er_io_t test_storage_medium_io(TestStorageMediumIo* io) {
  er_io_t out;

  out.ctx = io;
  out.read_at = test_storage_medium_read_at;
  out.write_at = test_storage_medium_write_at;
  out.sync = test_storage_medium_sync;
  out.size = test_storage_medium_size;
  out.truncate = test_storage_medium_truncate;
  return out;
}

static er_store_config_t test_storage_medium_store_config(void) {
  er_store_config_t config;
  UINTN i;

  er_mem_zero((UINT8*)&config, (UINTN)sizeof(config));
  for (i = 0u; i < ER_STORE_IDENTITY_ID_SIZE; ++i) {
    config.storage_identity_id[i] =
        (UINT8)(TEST_STORAGE_MEDIUM_STORE_ID_SEED + (UINT8)i);
  }
  for (i = 0u; i < ER_CLOCK_KEEPER_ID_SIZE; ++i) {
    config.epoch.keeper_id.bytes[i] =
        (UINT8)(TEST_STORAGE_MEDIUM_CLOCK_SEED + (UINT8)i);
  }
  return config;
}

static UINT8 test_storage_medium_benchmark(void* ctx,
                                           ErStorageMediumBenchmark* out) {
  TestStorageMediumBenchCtx* bench = (TestStorageMediumBenchCtx*)ctx;

  if (bench == 0 || out == 0) {
    return 0u;
  }
  ++bench->calls;
  *out = bench->benchmark;
  return 1u;
}

static ErStorageMediumBenchmark test_storage_medium_good_benchmark(void) {
  ErStorageMediumBenchmark benchmark;

  er_mem_zero((UINT8*)&benchmark, (UINTN)sizeof(benchmark));
  benchmark.abi_version = ER_STORAGE_MEDIUM_ABI_VERSION;
  benchmark.medium_kind = ER_STORAGE_MEDIUM_KIND_SDCARD;
  benchmark.flags = ER_STORAGE_MEDIUM_FLAG_VERIFIED_ADDRESSING |
                    ER_STORAGE_MEDIUM_FLAG_DESTRUCTIVE_PROBE;
  benchmark.block_bytes = TEST_STORAGE_MEDIUM_BLOCK_BYTES;
  benchmark.total_blocks = TEST_STORAGE_MEDIUM_TOTAL_BLOCKS;
  benchmark.benchmark_start_block = 0u;
  benchmark.benchmark_block_count = TEST_STORAGE_MEDIUM_BENCH_BLOCKS;
  benchmark.write_blocks_per_second = TEST_STORAGE_MEDIUM_WRITE_BPS;
  benchmark.verify_blocks_per_second = TEST_STORAGE_MEDIUM_VERIFY_BPS;
  benchmark.read_blocks_per_second = TEST_STORAGE_MEDIUM_READ_BPS;
  return benchmark;
}

static void test_storage_medium_init_record(void) {
  static UINT8 arena[TEST_STORAGE_MEDIUM_ARENA_BYTES];
  TestStorageMediumIo io;
  TestStorageMediumBenchCtx bench;
  er_store_config_t store_config;
  er_store_t store;
  ErStorageMediumInitResult init_result;
  ErStorageMediumBenchmark restored;
  ErHash first_hash;
  ErHash second_hash;

  er_mem_zero((UINT8*)&io, (UINTN)sizeof(io));
  er_mem_zero(arena, (UINTN)sizeof(arena));
  er_mem_zero((UINT8*)&bench, (UINTN)sizeof(bench));
  store_config = test_storage_medium_store_config();
  bench.benchmark = test_storage_medium_good_benchmark();

  check_int64("storage medium rejects null",
              er_storage_medium_benchmark_valid(0),
              0);
  restored = bench.benchmark;
  restored.flags = 0x80000000u;
  check_int64("storage medium rejects unknown flags",
              er_storage_medium_benchmark_valid(&restored),
              0);
  restored = bench.benchmark;
  restored.block_bytes = 500u;
  check_int64("storage medium rejects unaligned block",
              er_storage_medium_benchmark_valid(&restored),
              0);
  restored = bench.benchmark;
  restored.benchmark_start_block = TEST_STORAGE_MEDIUM_TOTAL_BLOCKS;
  restored.benchmark_block_count = 1u;
  check_int64("storage medium rejects overrun",
              er_storage_medium_benchmark_valid(&restored),
              0);

  check_int64("storage medium store open",
              er_store_open(&store,
                            test_storage_medium_io(&io),
                            arena,
                            (size_t)sizeof(arena),
                            &store_config),
              ER_OK);
  check_int64("storage medium not initialized",
              er_storage_medium_initialized(&store, 0),
              0);
  check_int64("storage medium init",
              er_storage_medium_init_if_needed(&store,
                                               test_storage_medium_benchmark,
                                               &bench,
                                               &init_result),
              1);
  check_int64("storage medium benchmark ran", init_result.benchmark_ran, 1);
  check_uint64("storage medium benchmark calls", bench.calls, 1u);
  check_uint64("storage medium no implicit sync", io.sync_count, 0u);
  first_hash = init_result.benchmark_hash;
  check_int64("storage medium read init",
              er_storage_medium_read_init(&store, &restored, &second_hash),
              1);
  check_hash_equal("storage medium hash stable", &first_hash, &second_hash);
  check_uint64("storage medium restored block bytes",
               restored.block_bytes,
               TEST_STORAGE_MEDIUM_BLOCK_BYTES);
  check_uint64("storage medium restored write bps",
               restored.write_blocks_per_second,
               TEST_STORAGE_MEDIUM_WRITE_BPS);

  check_int64("storage medium init idempotent",
              er_storage_medium_init_if_needed(&store,
                                               test_storage_medium_benchmark,
                                               &bench,
                                               &init_result),
              1);
  check_int64("storage medium already initialized",
              init_result.already_initialized,
              1);
  check_uint64("storage medium no rerun", bench.calls, 1u);
}
