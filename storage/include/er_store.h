#ifndef ER_STORE_H
#define ER_STORE_H

/*
 * Purpose: provide a tiny append-only content-addressed store.
 * Intention: make blobs and key projections rebuildable from one deterministic
 * record log without libc, malloc, paths, threads, or operating-system calls.
 *
 * Boundary: storage is deliberately content-blind. It does not authenticate
 * callers, authorize keys, parse object bytes, validate schemas, interpret
 * package formats, or decide whether a blob is safe to execute or reveal.
 * Callers own admission, signatures, encryption, access policy, object
 * semantics, and lifecycle policy above this byte store.
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
#define ER_STORE_HANDLE_BYTES 384u
#define ER_STORE_INDEX_CURSOR_BYTES 320u

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
  uint64_t opaque[ER_STORE_INDEX_CURSOR_BYTES / sizeof(uint64_t)];
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
  uint64_t opaque[ER_STORE_HANDLE_BYTES / sizeof(uint64_t)];
} er_store_t;

/*
 * Reports the minimum caller-owned arena size for a config. A null config uses
 * default table capacities. The returned size includes alignment slack.
 */
int er_store_arena_min_size(const er_store_config_t* config, size_t* out_arena_len);
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
/*
 * Index writes require an existing store value. Blob entries reference blobs
 * written with er_store_put_blob or er_store_put_typed_blob. Object entries
 * reference manifests created by er_store_put_object.
 */
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
/*
 * Cursors are invalid after any write to the same store. Open a fresh cursor
 * after blob, object, type, or index mutation.
 */
int er_store_index_cursor_open(er_store_t* store, uint32_t index_id, const char* prefix,
                               er_store_index_cursor_t* out_cursor);
int er_store_index_cursor_next(er_store_index_cursor_t* cursor, er_index_entry_t* out_entry);

int er_store_verify(er_store_t* store);

#endif
