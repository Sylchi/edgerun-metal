#define _POSIX_C_SOURCE 199309L

#include "er_blake3.h"

#define BENCH_BLAKE3_OUT_LEN ER_BLAKE3_OUT_LEN
#define BENCH_BLAKE3_CHUNK_LEN ER_BLAKE3_CHUNK_LEN

static uint8_t bench_blake3_hash(const uint8_t* bytes, size_t len, uint8_t digest[BENCH_BLAKE3_OUT_LEN]) {
  return er_blake3_hash_bytes(bytes, len, digest);
}

static const char* bench_blake3_backend_name(void) {
  return er_blake3_backend_name();
}

#include "bench_blake3_common.h"
