#define _POSIX_C_SOURCE 199309L

#include "blake3.h"

#include <stdio.h>

#define BENCH_BLAKE3_OUT_LEN BLAKE3_OUT_LEN
#define BENCH_BLAKE3_CHUNK_LEN BLAKE3_CHUNK_LEN

static uint8_t bench_blake3_hash(const uint8_t* bytes, size_t len, uint8_t digest[BENCH_BLAKE3_OUT_LEN]) {
  blake3_hasher hasher;

  blake3_hasher_init(&hasher);
#if defined(BLAKE3_USE_TBB)
  blake3_hasher_update_tbb(&hasher, bytes, len);
#else
  blake3_hasher_update(&hasher, bytes, len);
#endif
  blake3_hasher_finalize(&hasher, digest, BLAKE3_OUT_LEN);
  return 1u;
}

static const char* bench_blake3_backend_name(void) {
#if defined(BLAKE3_USE_TBB)
  static char name[64];

  snprintf(name, sizeof(name), "upstream %s, tbb", blake3_version());
  return name;
#else
  static char name[64];

  snprintf(name, sizeof(name), "upstream %s, amd64-asm", blake3_version());
  return name;
#endif
}

#include "bench_blake3_common.h"
