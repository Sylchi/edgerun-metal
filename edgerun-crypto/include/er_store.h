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
#define ER_STORE_MAX_NAME 64u
#define ER_STORE_MAX_CHUNKS 1024u
#define ER_STORE_BLOB_CAPACITY 4096u
#define ER_STORE_INDEX_CAPACITY 4096u
#define ER_STORE_TYPE_CAPACITY 1024u
#define ER_STORE_INDEX_DEF_CAPACITY 1024u
#define ER_STORE_ARENA_MIN_SIZE (2u * 1024u * 1024u)
#define ER_STORE_TYPE_RAW 0u
#define ER_STORE_TYPE_OBJECT_MANIFEST 1u
#define ER_STORE_INDEX_DEFAULT 0u
#define ER_STORE_VALUE_UNKNOWN 0u
#define ER_STORE_VALUE_BLOB 1u
#define ER_STORE_VALUE_OBJECT 2u

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
  uint32_t content_type;
  uint64_t offset; //@optimizer-ignore blob offsets mirror the fixed 64-bit record log ABI
  uint64_t size; //@optimizer-ignore blob sizes mirror the fixed 64-bit record log ABI
} er_blob_t;

typedef struct er_index_entry {
  uint32_t index_id;
  uint32_t value_kind;
  uint32_t content_type;
  char key[ER_STORE_MAX_KEY];
  uint8_t hash[ER_HASH_SIZE];
  uint64_t value_size; //@optimizer-ignore index values mirror fixed 64-bit blob/object sizes
} er_index_entry_t;

typedef struct er_store_index_cursor {
  struct er_store* store;
  uint32_t index_id;
  char prefix[ER_STORE_MAX_KEY];
  size_t prefix_len;
  size_t pos;
} er_store_index_cursor_t;

typedef struct er_store_config {
  size_t blob_slots;
  size_t key_slots;
  size_t type_slots;
  size_t index_slots;
  size_t cache_bytes;
} er_store_config_t;

typedef struct er_store_stats {
  size_t blob_slots;
  size_t key_slots;
  size_t type_slots;
  size_t index_slots;
  size_t blob_count;
  size_t key_count;
  size_t type_count;
  size_t index_count;
  size_t cache_bytes;
  size_t cache_used;
  size_t cache_hits;
  size_t cache_misses;
  size_t cache_admissions;
  size_t cache_rejects;
} er_store_stats_t;

typedef struct er_store {
  er_io_t io;
  void* blob_slots;
  void* key_slots;
  void* sorted_key_slots;
  void* type_slots;
  void* index_slots;
  uint8_t* cache;
  size_t blob_count;
  size_t key_count;
  size_t sorted_key_count;
  size_t type_count;
  size_t index_count;
  size_t blob_capacity;
  size_t key_capacity;
  int sorted_key_dirty;
  size_t type_capacity;
  size_t index_capacity;
  size_t cache_len;
  size_t cache_used;
  size_t cache_hits;
  size_t cache_misses;
  size_t cache_admissions;
  size_t cache_rejects;
  size_t defer_sync_depth;
  int sync_pending;
  int superblock_dirty;
  uint64_t log_start; //@optimizer-ignore log offsets mirror the fixed 64-bit record log ABI
  uint64_t log_end; //@optimizer-ignore log offsets mirror the fixed 64-bit record log ABI
  uint64_t next_seq; //@optimizer-ignore sequence values mirror the fixed 64-bit record header ABI
  uint8_t last_record_hash[ER_HASH_SIZE];
} er_store_t;

int er_store_open(er_store_t* store, er_io_t io, void* arena, size_t arena_len,
                  const er_store_config_t* config);
int er_store_close(er_store_t* store);
int er_store_stats(er_store_t* store, er_store_stats_t* out_stats);

int er_store_put_blob(er_store_t* store, const void* data, size_t len, uint8_t out_hash[ER_HASH_SIZE]);
int er_store_put_typed_blob(er_store_t* store, uint32_t content_type, const void* data, size_t len,
                            uint8_t out_hash[ER_HASH_SIZE]);
int er_store_put_object(er_store_t* store, const void* data, size_t len, size_t chunk_size,
                        uint8_t out_object_hash[ER_HASH_SIZE]);
int er_store_get_object(er_store_t* store, const uint8_t object_hash[ER_HASH_SIZE], void* out, size_t out_cap,
                        size_t* out_len);
int er_store_get_blob(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], void* out, size_t out_cap,
                      size_t* out_len);
int er_store_get_blob_info(er_store_t* store, const uint8_t hash[ER_HASH_SIZE], er_blob_t* out_blob);

int er_store_define_content_type(er_store_t* store, uint32_t content_type, const char* name);
int er_store_define_index(er_store_t* store, uint32_t index_id, uint32_t content_type, const char* name);
int er_store_index_put(er_store_t* store, uint32_t index_id, const char* key,
                       const uint8_t hash[ER_HASH_SIZE]);
int er_store_blob_index_put(er_store_t* store, uint32_t index_id, const char* key,
                            const uint8_t blob_hash[ER_HASH_SIZE]);
int er_store_object_index_put(er_store_t* store, uint32_t index_id, const char* key,
                              const uint8_t object_hash[ER_HASH_SIZE]);
int er_store_index_get(er_store_t* store, uint32_t index_id, const char* key,
                       uint8_t out_hash[ER_HASH_SIZE]);
int er_store_index_get_entry(er_store_t* store, uint32_t index_id, const char* key,
                             er_index_entry_t* out_entry);

int er_store_index_scan_prefix(er_store_t* store, uint32_t index_id, const char* prefix,
                               er_index_entry_t* out_entries, size_t max_entries, size_t* out_count);
int er_store_index_cursor_open(er_store_t* store, uint32_t index_id, const char* prefix,
                               er_store_index_cursor_t* out_cursor);
int er_store_index_cursor_next(er_store_index_cursor_t* cursor, er_index_entry_t* out_entry);

int er_store_verify(er_store_t* store);

#endif
