#include "er_storage_medium.h"
#include "er_mem.h"

enum {
  ER_STORAGE_MEDIUM_BYTE_BITS = 8u,
  ER_STORAGE_MEDIUM_BYTE_MASK = 0xffu,
  ER_STORAGE_MEDIUM_INDEX_ID = 0x45534d49u,
  ER_STORAGE_MEDIUM_CONTENT_TYPE_INIT = 0x45534d42u,
  ER_STORAGE_MEDIUM_U16_BYTES = 2u,
  ER_STORAGE_MEDIUM_U32_BYTES = 4u,
  ER_STORAGE_MEDIUM_U64_BYTES = 8u,
  ER_STORAGE_MEDIUM_ABI_OFFSET = 0u,
  ER_STORAGE_MEDIUM_KIND_OFFSET =
      ER_STORAGE_MEDIUM_ABI_OFFSET + ER_STORAGE_MEDIUM_U16_BYTES,
  ER_STORAGE_MEDIUM_FLAGS_OFFSET =
      ER_STORAGE_MEDIUM_KIND_OFFSET + ER_STORAGE_MEDIUM_U16_BYTES,
  ER_STORAGE_MEDIUM_BLOCK_BYTES_OFFSET =
      ER_STORAGE_MEDIUM_FLAGS_OFFSET + ER_STORAGE_MEDIUM_U32_BYTES,
  ER_STORAGE_MEDIUM_TOTAL_BLOCKS_OFFSET =
      ER_STORAGE_MEDIUM_BLOCK_BYTES_OFFSET + ER_STORAGE_MEDIUM_U32_BYTES,
  ER_STORAGE_MEDIUM_BENCH_START_OFFSET =
      ER_STORAGE_MEDIUM_TOTAL_BLOCKS_OFFSET + ER_STORAGE_MEDIUM_U64_BYTES,
  ER_STORAGE_MEDIUM_BENCH_BLOCKS_OFFSET =
      ER_STORAGE_MEDIUM_BENCH_START_OFFSET + ER_STORAGE_MEDIUM_U64_BYTES,
  ER_STORAGE_MEDIUM_WRITE_BPS_OFFSET =
      ER_STORAGE_MEDIUM_BENCH_BLOCKS_OFFSET + ER_STORAGE_MEDIUM_U64_BYTES,
  ER_STORAGE_MEDIUM_VERIFY_BPS_OFFSET =
      ER_STORAGE_MEDIUM_WRITE_BPS_OFFSET + ER_STORAGE_MEDIUM_U64_BYTES,
  ER_STORAGE_MEDIUM_READ_BPS_OFFSET =
      ER_STORAGE_MEDIUM_VERIFY_BPS_OFFSET + ER_STORAGE_MEDIUM_U64_BYTES,
  ER_STORAGE_MEDIUM_RECORD_BYTES =
      ER_STORAGE_MEDIUM_READ_BPS_OFFSET + ER_STORAGE_MEDIUM_U64_BYTES,
  ER_STORAGE_MEDIUM_FLAGS_KNOWN =
      ER_STORAGE_MEDIUM_FLAG_VERIFIED_ADDRESSING |
      ER_STORAGE_MEDIUM_FLAG_DESTRUCTIVE_PROBE
};

static const char g_storage_medium_init_key[] = "medium/init";

static void er_storage_medium_put_be(UINT8* dst,
                                     UINT64 value,
                                     UINTN byte_count) {
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    UINTN shift = (byte_count - 1u - i) * ER_STORAGE_MEDIUM_BYTE_BITS;
    dst[i] = (UINT8)((value >> shift) & ER_STORAGE_MEDIUM_BYTE_MASK);
  }
}

static UINT64 er_storage_medium_get_be(const UINT8* src, UINTN byte_count) {
  UINT64 value = 0u;
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    value = (value << ER_STORAGE_MEDIUM_BYTE_BITS) | (UINT64)src[i];
  }
  return value;
}

static UINT8 er_storage_medium_kind_valid(UINT16 medium_kind) {
  switch (medium_kind) {
    case ER_STORAGE_MEDIUM_KIND_SDCARD:
    case ER_STORAGE_MEDIUM_KIND_NVME:
    case ER_STORAGE_MEDIUM_KIND_CUSTOM_BLOCK:
      return 1u;
    default:
      return 0u;
  }
}

static void er_storage_medium_encode(
    const ErStorageMediumBenchmark* benchmark,
    UINT8 bytes[ER_STORAGE_MEDIUM_RECORD_BYTES]) {
  er_mem_zero(bytes, ER_STORAGE_MEDIUM_RECORD_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_ABI_OFFSET,
                           benchmark->abi_version,
                           ER_STORAGE_MEDIUM_U16_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_KIND_OFFSET,
                           benchmark->medium_kind,
                           ER_STORAGE_MEDIUM_U16_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_FLAGS_OFFSET,
                           benchmark->flags,
                           ER_STORAGE_MEDIUM_U32_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_BLOCK_BYTES_OFFSET,
                           benchmark->block_bytes,
                           ER_STORAGE_MEDIUM_U32_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_TOTAL_BLOCKS_OFFSET,
                           benchmark->total_blocks,
                           ER_STORAGE_MEDIUM_U64_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_BENCH_START_OFFSET,
                           benchmark->benchmark_start_block,
                           ER_STORAGE_MEDIUM_U64_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_BENCH_BLOCKS_OFFSET,
                           benchmark->benchmark_block_count,
                           ER_STORAGE_MEDIUM_U64_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_WRITE_BPS_OFFSET,
                           benchmark->write_blocks_per_second,
                           ER_STORAGE_MEDIUM_U64_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_VERIFY_BPS_OFFSET,
                           benchmark->verify_blocks_per_second,
                           ER_STORAGE_MEDIUM_U64_BYTES);
  er_storage_medium_put_be(bytes + ER_STORAGE_MEDIUM_READ_BPS_OFFSET,
                           benchmark->read_blocks_per_second,
                           ER_STORAGE_MEDIUM_U64_BYTES);
}

static UINT8 er_storage_medium_decode(
    const UINT8 bytes[ER_STORAGE_MEDIUM_RECORD_BYTES],
    ErStorageMediumBenchmark* out_benchmark) {
  if (bytes == 0 || out_benchmark == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_benchmark, (UINTN)sizeof(*out_benchmark));
  out_benchmark->abi_version =
      (UINT16)er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_ABI_OFFSET,
                                       ER_STORAGE_MEDIUM_U16_BYTES);
  out_benchmark->medium_kind =
      (UINT16)er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_KIND_OFFSET,
                                       ER_STORAGE_MEDIUM_U16_BYTES);
  out_benchmark->flags =
      (UINT32)er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_FLAGS_OFFSET,
                                       ER_STORAGE_MEDIUM_U32_BYTES);
  out_benchmark->block_bytes =
      (UINT32)er_storage_medium_get_be(
          bytes + ER_STORAGE_MEDIUM_BLOCK_BYTES_OFFSET,
          ER_STORAGE_MEDIUM_U32_BYTES);
  out_benchmark->total_blocks =
      er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_TOTAL_BLOCKS_OFFSET,
                               ER_STORAGE_MEDIUM_U64_BYTES);
  out_benchmark->benchmark_start_block =
      er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_BENCH_START_OFFSET,
                               ER_STORAGE_MEDIUM_U64_BYTES);
  out_benchmark->benchmark_block_count =
      er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_BENCH_BLOCKS_OFFSET,
                               ER_STORAGE_MEDIUM_U64_BYTES);
  out_benchmark->write_blocks_per_second =
      er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_WRITE_BPS_OFFSET,
                               ER_STORAGE_MEDIUM_U64_BYTES);
  out_benchmark->verify_blocks_per_second =
      er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_VERIFY_BPS_OFFSET,
                               ER_STORAGE_MEDIUM_U64_BYTES);
  out_benchmark->read_blocks_per_second =
      er_storage_medium_get_be(bytes + ER_STORAGE_MEDIUM_READ_BPS_OFFSET,
                               ER_STORAGE_MEDIUM_U64_BYTES);
  return er_storage_medium_benchmark_valid(out_benchmark);
}

UINT8 er_storage_medium_benchmark_valid(
    const ErStorageMediumBenchmark* benchmark) {
  UINT64 benchmark_end;

  if (benchmark == 0 ||
      benchmark->abi_version != ER_STORAGE_MEDIUM_ABI_VERSION ||
      er_storage_medium_kind_valid(benchmark->medium_kind) == 0u ||
      (benchmark->flags & ~((UINT32)ER_STORAGE_MEDIUM_FLAGS_KNOWN)) != 0u ||
      benchmark->block_bytes == 0u ||
      benchmark->total_blocks == 0u ||
      benchmark->benchmark_block_count == 0u ||
      benchmark->write_blocks_per_second == 0u ||
      benchmark->verify_blocks_per_second == 0u ||
      benchmark->read_blocks_per_second == 0u) {
    return 0u;
  }
  if ((benchmark->block_bytes & (benchmark->block_bytes - 1u)) != 0u) {
    return 0u;
  }
  benchmark_end = benchmark->benchmark_start_block +
                  benchmark->benchmark_block_count;
  if (benchmark_end < benchmark->benchmark_start_block ||
      benchmark_end > benchmark->total_blocks) {
    return 0u;
  }
  return 1u;
}

UINT8 er_storage_medium_initialized(er_store_t* store, ErHash* out_hash) {
  UINT8 hash[ER_HASH_SIZE];

  if (store == 0 ||
      er_store_index_get(store,
                         ER_STORAGE_MEDIUM_INDEX_ID,
                         g_storage_medium_init_key,
                         hash) != ER_OK) {
    return 0u;
  }
  if (out_hash != 0) {
    er_mem_copy(out_hash->bytes, hash, ER_HASH_SIZE);
  }
  return 1u;
}

UINT8 er_storage_medium_read_init(er_store_t* store,
                                  ErStorageMediumBenchmark* out_benchmark,
                                  ErHash* out_hash) {
  UINT8 hash[ER_HASH_SIZE];
  UINT8 bytes[ER_STORAGE_MEDIUM_RECORD_BYTES];
  size_t bytes_len = 0u;

  if (store == 0 || out_benchmark == 0 ||
      er_store_index_get(store,
                         ER_STORAGE_MEDIUM_INDEX_ID,
                         g_storage_medium_init_key,
                         hash) != ER_OK ||
      er_store_get_blob(store,
                        hash,
                        bytes,
                        (size_t)sizeof(bytes),
                        &bytes_len) != ER_OK ||
      bytes_len != (size_t)sizeof(bytes) ||
      er_storage_medium_decode(bytes, out_benchmark) == 0u) {
    return 0u;
  }
  if (out_hash != 0) {
    er_mem_copy(out_hash->bytes, hash, ER_HASH_SIZE);
  }
  return 1u;
}

UINT8 er_storage_medium_record_init(er_store_t* store,
                                    const ErStorageMediumBenchmark* benchmark,
                                    ErHash* out_hash) {
  UINT8 bytes[ER_STORAGE_MEDIUM_RECORD_BYTES];
  UINT8 hash[ER_HASH_SIZE];

  if (store == 0 ||
      er_storage_medium_initialized(store, 0) != 0u ||
      er_storage_medium_benchmark_valid(benchmark) == 0u) {
    return 0u;
  }
  er_storage_medium_encode(benchmark, bytes);
  if (er_store_put_typed_blob(store,
                              ER_STORAGE_MEDIUM_CONTENT_TYPE_INIT,
                              bytes,
                              (size_t)sizeof(bytes),
                              hash) != ER_OK ||
      er_store_blob_index_put(store,
                              ER_STORAGE_MEDIUM_INDEX_ID,
                              g_storage_medium_init_key,
                              hash) != ER_OK) {
    return 0u;
  }
  if (out_hash != 0) {
    er_mem_copy(out_hash->bytes, hash, ER_HASH_SIZE);
  }
  return 1u;
}

UINT8 er_storage_medium_init_if_needed(er_store_t* store,
                                       ErStorageMediumBenchmarkFn benchmark_fn,
                                       void* benchmark_ctx,
                                       ErStorageMediumInitResult* out_result) {
  ErStorageMediumBenchmark benchmark;
  ErHash hash;

  if (store == 0 || benchmark_fn == 0 || out_result == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_result, (UINTN)sizeof(*out_result));
  if (er_storage_medium_initialized(store, &hash) != 0u) {
    out_result->already_initialized = 1u;
    out_result->benchmark_hash = hash;
    return 1u;
  }
  if (benchmark_fn(benchmark_ctx, &benchmark) == 0u ||
      er_storage_medium_record_init(store, &benchmark, &hash) == 0u) {
    return 0u;
  }
  out_result->benchmark_ran = 1u;
  out_result->benchmark_hash = hash;
  return 1u;
}
