#ifndef ER_STORE_H
#define ER_STORE_H

/*
 * Purpose: provide a tiny append-only content-addressed store.
 * Intention: make blobs and key projections rebuildable from one deterministic
 * record log without libc, malloc, paths, threads, or operating-system calls.
 */

#include <stddef.h>
#include <stdint.h>

#define ER_OK 0
#define ER_ERR_IO -1
#define ER_ERR_CORRUPT -2
#define ER_ERR_NOSPACE -3
#define ER_ERR_NOTFOUND -4
#define ER_ERR_BADARG -5
#define ER_ERR_TOOBIG -6

#define ER_HASH_SIZE 32u
#define ER_STORE_MAX_KEY 256u
#define ER_STORE_MAX_CHUNKS 1024u
#define ER_STORE_BLOB_CAPACITY 4096u
#define ER_STORE_INDEX_CAPACITY 4096u
#define ER_STORE_ARENA_MIN_SIZE (2u * 1024u * 1024u)

typedef struct er_io {
  void* ctx;

  int (*read_at)(void* ctx, uint64_t off, void* buf, size_t len); //@optimizer-ignore record log offsets are fixed 64-bit on-disk ABI fields
  int (*write_at)(void* ctx, uint64_t off, const void* buf, size_t len); //@optimizer-ignore record log offsets are fixed 64-bit on-disk ABI fields
  int (*sync)(void* ctx);
  int (*size)(void* ctx, uint64_t* out_size); //@optimizer-ignore record log size is a fixed 64-bit on-disk ABI field
  int (*truncate)(void* ctx, uint64_t size); //@optimizer-ignore record log size is a fixed 64-bit on-disk ABI field
} er_io_t;

typedef struct er_blob {
  uint8_t hash[ER_HASH_SIZE];
  uint64_t offset; //@optimizer-ignore blob offsets mirror the fixed 64-bit record log ABI
  uint64_t size; //@optimizer-ignore blob sizes mirror the fixed 64-bit record log ABI
} er_blob_t;

typedef struct er_index_entry {
  char key[ER_STORE_MAX_KEY];
  uint8_t hash[ER_HASH_SIZE];
} er_index_entry_t;

typedef struct er_store {
  er_io_t io;
  void* blob_slots;
  void* key_slots;
  size_t blob_count;
  size_t key_count;
  uint64_t log_start; //@optimizer-ignore log offsets mirror the fixed 64-bit record log ABI
  uint64_t log_end; //@optimizer-ignore log offsets mirror the fixed 64-bit record log ABI
  uint64_t next_seq; //@optimizer-ignore sequence values mirror the fixed 64-bit record header ABI
  uint8_t last_record_hash[ER_HASH_SIZE];
} er_store_t;

int er_store_open(er_store_t* store, er_io_t io, void* arena, size_t arena_len);
int er_store_close(er_store_t* store);

int er_store_put_blob(er_store_t* store, const void* data, size_t len, uint8_t out_hash[ER_HASH_SIZE]);
int er_store_get_blob(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], void* out, size_t out_cap,
                      size_t* out_len);

int er_store_index_put(er_store_t* store, const char* key, const uint8_t hash[ER_HASH_SIZE]);
int er_store_index_get(er_store_t* store, const char* key, uint8_t out_hash[ER_HASH_SIZE]);

int er_store_index_scan_prefix(er_store_t* store, const char* prefix, er_index_entry_t* out_entries,
                               size_t max_entries, size_t* out_count);

int er_store_verify(er_store_t* store);

#endif
