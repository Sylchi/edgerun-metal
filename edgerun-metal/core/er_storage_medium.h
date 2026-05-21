#ifndef ER_STORAGE_MEDIUM_H
#define ER_STORAGE_MEDIUM_H

/*
 * Purpose: record explicit storage-medium initialization facts above er_store.
 * Intention: make SD/NVMe capacity and benchmark evidence a durable input to
 * storage budgeting without giving er_store benchmark, cache, or policy logic.
 */

#include "er_crypto.h"
#include "er_store.h"

#define ER_STORAGE_MEDIUM_ABI_VERSION 1u
#define ER_STORAGE_MEDIUM_KIND_SDCARD 1u
#define ER_STORAGE_MEDIUM_KIND_NVME 2u
#define ER_STORAGE_MEDIUM_KIND_CUSTOM_BLOCK 3u

#define ER_STORAGE_MEDIUM_FLAG_VERIFIED_ADDRESSING 0x00000001u
#define ER_STORAGE_MEDIUM_FLAG_DESTRUCTIVE_PROBE 0x00000002u

typedef struct {
  UINT16 abi_version;
  UINT16 medium_kind;
  UINT32 flags;
  UINT32 block_bytes;
  UINT64 total_blocks;
  UINT64 benchmark_start_block;
  UINT64 benchmark_block_count;
  UINT64 write_blocks_per_second;
  UINT64 verify_blocks_per_second;
  UINT64 read_blocks_per_second;
} ErStorageMediumBenchmark;

typedef UINT8 (*ErStorageMediumBenchmarkFn)(
    void* ctx,
    ErStorageMediumBenchmark* out_benchmark);

typedef struct {
  UINT8 already_initialized;
  UINT8 benchmark_ran;
  ErHash benchmark_hash;
} ErStorageMediumInitResult;

UINT8 er_storage_medium_benchmark_valid(
    const ErStorageMediumBenchmark* benchmark);
UINT8 er_storage_medium_initialized(er_store_t* store, ErHash* out_hash);
UINT8 er_storage_medium_read_init(er_store_t* store,
                                  ErStorageMediumBenchmark* out_benchmark,
                                  ErHash* out_hash);
UINT8 er_storage_medium_record_init(er_store_t* store,
                                    const ErStorageMediumBenchmark* benchmark,
                                    ErHash* out_hash);
UINT8 er_storage_medium_init_if_needed(er_store_t* store,
                                       ErStorageMediumBenchmarkFn benchmark_fn,
                                       void* benchmark_ctx,
                                       ErStorageMediumInitResult* out_result);

#endif
