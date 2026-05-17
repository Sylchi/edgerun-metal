#ifndef ER_BLAKE3_H
#define ER_BLAKE3_H

/*
 * Purpose: provide a small freestanding BLAKE3 hash implementation.
 * Intention: keep hashing reusable across EdgeRun C projects without runtime or libc assumptions.
 */

#include <stddef.h>
#include <stdint.h>

#define ER_BLAKE3_OUT_LEN 32u
#define ER_BLAKE3_BLOCK_LEN 64u
#define ER_BLAKE3_CHUNK_LEN 1024u
#define ER_BLAKE3_MAX_DEPTH 54u

typedef struct {
  uint32_t key[8];
  uint32_t chunk_cv[8];
  uint8_t block[ER_BLAKE3_BLOCK_LEN];
  size_t block_len;
  uint32_t blocks_compressed;
  uint64_t chunk_counter;
  uint32_t cv_stack[ER_BLAKE3_MAX_DEPTH][8];
  size_t cv_stack_len;
  uint32_t flags;
} ErBlake3Hasher;

typedef void (*ErBlake3JobFn)(void* job);
typedef uint8_t (*ErBlake3RunJobsFn)(void* user, ErBlake3JobFn job_fn, void* const* jobs, size_t job_count);

void er_blake3_init(ErBlake3Hasher* hasher);
uint8_t er_blake3_update(ErBlake3Hasher* hasher, const uint8_t* bytes, size_t len);
uint8_t er_blake3_final(const ErBlake3Hasher* hasher, uint8_t out[ER_BLAKE3_OUT_LEN]);
uint8_t er_blake3_hash_bytes(const uint8_t* bytes, size_t len, uint8_t out[ER_BLAKE3_OUT_LEN]);
/* Freestanding parallel primitive for full 1 KiB chunk inputs with power-of-two chunk counts. */
uint8_t er_blake3_hash_bytes_parallel(const uint8_t* bytes, size_t len, uint8_t out[ER_BLAKE3_OUT_LEN],
                                      ErBlake3RunJobsFn run_jobs, void* user, size_t max_jobs);
const char* er_blake3_backend_name(void);

#endif
