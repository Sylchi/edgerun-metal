#define _POSIX_C_SOURCE 200809L

#include "er_store.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

enum {
  BENCH_STORE_IO_CAP = 512u * 1024u * 1024u,
  BENCH_STORE_ARENA_BYTES = 128u * 1024u * 1024u,
  BENCH_STORE_BLOB_BYTES = 64u * 1024u,
  BENCH_STORE_OBJECT_BYTES = 8u * 1024u * 1024u,
  BENCH_STORE_OBJECT_CHUNK = 64u * 1024u,
  BENCH_STORE_BLOB_ITERS = 512u,
  BENCH_STORE_DEDUP_ITERS = 8192u,
  BENCH_STORE_OBJECT_ITERS = 16u,
  BENCH_STORE_REPLAY_OBJECTS = 64u,
  BENCH_STORE_INDEX_QUICK_ITERS = 20000u,
  BENCH_STORE_INDEX_MEDIUM_ITERS = 100000u,
  BENCH_STORE_BLOB_SLOTS = 32768u,
  BENCH_STORE_KEY_SLOTS = 131072u,
  BENCH_STORE_TYPE_SLOTS = 1024u,
  BENCH_STORE_INDEX_SLOTS = 1024u,
  BENCH_STORE_NS_PER_SECOND = 1000000000ull,
  BENCH_STORE_BYTES_PER_MIB = 1024u * 1024u,
  BENCH_STORE_PATTERN_MULT = 131u,
  BENCH_STORE_PATTERN_ADD = 17u,
  BENCH_STORE_PATTERN_MASK = 0xffu
};

typedef struct {
  uint8_t* bytes;
  uint64_t size;
  uint64_t cap;
  uint64_t writes;
  uint64_t reads;
  uint64_t syncs;
} BenchIo;

static volatile uint8_t g_bench_store_sink;

static void bench_store_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

static void bench_store_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static void bench_store_fill(uint8_t* dst, size_t len, uint8_t seed) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    dst[i] = (uint8_t)(((i * BENCH_STORE_PATTERN_MULT) + BENCH_STORE_PATTERN_ADD + seed) &
                       BENCH_STORE_PATTERN_MASK);
  }
}

static uint64_t bench_store_now_ns(void) {
  struct timespec ts;

  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0u;
  }
  return ((uint64_t)ts.tv_sec * BENCH_STORE_NS_PER_SECOND) + (uint64_t)ts.tv_nsec;
}

static int bench_read_at(void* ctx, uint64_t off, void* buf, size_t len) {
  BenchIo* io = (BenchIo*)ctx;

  if (off > io->size || len > (size_t)(io->size - off)) {
    return -1;
  }
  bench_store_copy(buf, &io->bytes[off], len);
  ++io->reads;
  return 0;
}

static int bench_write_at(void* ctx, uint64_t off, const void* buf, size_t len) {
  BenchIo* io = (BenchIo*)ctx;
  uint64_t end = off + len;

  if (end < off || end > io->cap) {
    return -1;
  }
  if (off > io->size) {
    bench_store_zero(&io->bytes[io->size], (size_t)(off - io->size));
  }
  bench_store_copy(&io->bytes[off], buf, len);
  if (end > io->size) {
    io->size = end;
  }
  ++io->writes;
  return 0;
}

static int bench_sync(void* ctx) {
  BenchIo* io = (BenchIo*)ctx;

  ++io->syncs;
  return 0;
}

static int bench_size(void* ctx, uint64_t* out_size) {
  BenchIo* io = (BenchIo*)ctx;

  *out_size = io->size;
  return 0;
}

static int bench_truncate(void* ctx, uint64_t size) {
  BenchIo* io = (BenchIo*)ctx;

  if (size > io->cap) {
    return -1;
  }
  io->size = size;
  return 0;
}

static er_io_t bench_make_io(BenchIo* io) {
  er_io_t out;

  out.ctx = io;
  out.read_at = bench_read_at;
  out.write_at = bench_write_at;
  out.sync = bench_sync;
  out.size = bench_size;
  out.truncate = bench_truncate;
  return out;
}

static int bench_store_open(er_store_t* store, BenchIo* io, uint8_t* arena) {
  er_store_config_t config;

  bench_store_zero(&config, sizeof(config));
  config.blob_slots = BENCH_STORE_BLOB_SLOTS;
  config.key_slots = BENCH_STORE_KEY_SLOTS;
  config.type_slots = BENCH_STORE_TYPE_SLOTS;
  config.index_slots = BENCH_STORE_INDEX_SLOTS;
  return er_store_open(store, bench_make_io(io), arena, BENCH_STORE_ARENA_BYTES, &config);
}

static double bench_store_mib_per_s(size_t bytes, size_t iters, uint64_t elapsed_ns) {
  double seconds = (double)elapsed_ns / (double)BENCH_STORE_NS_PER_SECOND;
  double mib = ((double)bytes * (double)iters) / (double)BENCH_STORE_BYTES_PER_MIB;

  return mib / seconds;
}

static int bench_blob_put(BenchIo* io, uint8_t* arena, uint8_t* data) {
  er_store_t store;
  uint8_t hash[ER_HASH_SIZE];
  uint64_t start;
  uint64_t elapsed;
  size_t i;

  io->size = 0u;
  if (bench_store_open(&store, io, arena) != ER_OK) {
    return 0;
  }
  start = bench_store_now_ns();
  for (i = 0u; i < BENCH_STORE_BLOB_ITERS; ++i) {
    data[0] = (uint8_t)i;
    if (er_store_put_blob(&store, data, BENCH_STORE_BLOB_BYTES, hash) != ER_OK) {
      return 0;
    }
    g_bench_store_sink ^= hash[i & (ER_HASH_SIZE - 1u)];
  }
  elapsed = bench_store_now_ns() - start;
  printf("blob-put   %7u x %7u bytes %9.2f MiB/s log=%llu\n",
         (unsigned)BENCH_STORE_BLOB_ITERS, (unsigned)BENCH_STORE_BLOB_BYTES,
         bench_store_mib_per_s(BENCH_STORE_BLOB_BYTES, BENCH_STORE_BLOB_ITERS, elapsed),
         (unsigned long long)io->size);
  return 1;
}

static int bench_blob_dedup(BenchIo* io, uint8_t* arena, uint8_t* data) {
  er_store_t store;
  uint8_t hash[ER_HASH_SIZE];
  uint64_t start;
  uint64_t elapsed;
  uint64_t size_before;
  size_t i;

  io->size = 0u;
  if (bench_store_open(&store, io, arena) != ER_OK ||
      er_store_put_blob(&store, data, BENCH_STORE_BLOB_BYTES, hash) != ER_OK) {
    return 0;
  }
  size_before = io->size;
  start = bench_store_now_ns();
  for (i = 0u; i < BENCH_STORE_DEDUP_ITERS; ++i) {
    if (er_store_put_blob(&store, data, BENCH_STORE_BLOB_BYTES, hash) != ER_OK) {
      return 0;
    }
    g_bench_store_sink ^= hash[i & (ER_HASH_SIZE - 1u)];
  }
  elapsed = bench_store_now_ns() - start;
  printf("blob-dedup %7u x %7u bytes %9.2f MiB/s log-delta=%llu\n",
         (unsigned)BENCH_STORE_DEDUP_ITERS, (unsigned)BENCH_STORE_BLOB_BYTES,
         bench_store_mib_per_s(BENCH_STORE_BLOB_BYTES, BENCH_STORE_DEDUP_ITERS, elapsed),
         (unsigned long long)(io->size - size_before));
  return 1;
}

static int bench_object_put_get(BenchIo* io, uint8_t* arena, uint8_t* data, uint8_t* out) {
  er_store_t store;
  uint8_t hash[ER_HASH_SIZE];
  uint64_t start;
  uint64_t elapsed;
  size_t out_len = 0u;
  size_t i;

  io->size = 0u;
  if (bench_store_open(&store, io, arena) != ER_OK) {
    return 0;
  }
  start = bench_store_now_ns();
  for (i = 0u; i < BENCH_STORE_OBJECT_ITERS; ++i) {
    data[0] = (uint8_t)i;
    if (er_store_put_object(&store, data, BENCH_STORE_OBJECT_BYTES, BENCH_STORE_OBJECT_CHUNK, hash) != ER_OK) {
      return 0;
    }
    g_bench_store_sink ^= hash[i & (ER_HASH_SIZE - 1u)];
  }
  elapsed = bench_store_now_ns() - start;
  printf("object-put %7u x %7u bytes %9.2f MiB/s log=%llu\n",
         (unsigned)BENCH_STORE_OBJECT_ITERS, (unsigned)BENCH_STORE_OBJECT_BYTES,
         bench_store_mib_per_s(BENCH_STORE_OBJECT_BYTES, BENCH_STORE_OBJECT_ITERS, elapsed),
         (unsigned long long)io->size);
  start = bench_store_now_ns();
  if (er_store_get_object(&store, hash, out, BENCH_STORE_OBJECT_BYTES, &out_len) != ER_OK ||
      out_len != BENCH_STORE_OBJECT_BYTES) {
    return 0;
  }
  elapsed = bench_store_now_ns() - start;
  g_bench_store_sink ^= out[BENCH_STORE_OBJECT_BYTES - 1u];
  printf("object-get %7u x %7u bytes %9.2f MiB/s\n", 1u, (unsigned)BENCH_STORE_OBJECT_BYTES,
         bench_store_mib_per_s(BENCH_STORE_OBJECT_BYTES, 1u, elapsed));
  return 1;
}

//@optimizer-ignore-function benchmark replay setup intentionally mirrors blob/object setup for comparable timings
static int bench_replay(BenchIo* io, uint8_t* arena, uint8_t* data) {
  er_store_t store;
  uint8_t hash[ER_HASH_SIZE];
  uint64_t start;
  uint64_t elapsed;
  size_t i;

  io->size = 0u;
  if (bench_store_open(&store, io, arena) != ER_OK) {
    return 0;
  }
  for (i = 0u; i < BENCH_STORE_REPLAY_OBJECTS; ++i) {
    data[0] = (uint8_t)i;
    if (er_store_put_object(&store, data, BENCH_STORE_BLOB_BYTES, BENCH_STORE_OBJECT_CHUNK, hash) != ER_OK) {
      return 0;
    }
  }
  start = bench_store_now_ns();
  if (bench_store_open(&store, io, arena) != ER_OK) {
    return 0;
  }
  elapsed = bench_store_now_ns() - start;
  printf("replay     %7u objects log=%llu %9.3f ms\n",
         (unsigned)BENCH_STORE_REPLAY_OBJECTS, (unsigned long long)io->size,
         (double)elapsed / 1000000.0);
  return 1;
}

static void bench_index_key(char* out, size_t out_len, size_t value) {
  (void)snprintf(out, out_len, "row/%05u", (unsigned)value);
}

static int bench_index(BenchIo* io, uint8_t* arena, uint8_t* data, const char* label, size_t count) {
  er_store_t store;
  uint8_t hash[ER_HASH_SIZE];
  uint8_t got[ER_HASH_SIZE];
  char key[ER_STORE_MAX_KEY];
  er_store_index_cursor_t cursor;
  er_index_entry_t entry;
  uint64_t start;
  uint64_t elapsed;
  size_t i;
  size_t cursor_count = 0u;

  io->size = 0u;
  if (bench_store_open(&store, io, arena) != ER_OK ||
      er_store_put_blob(&store, data, BENCH_STORE_BLOB_BYTES, hash) != ER_OK) {
    return 0;
  }
  start = bench_store_now_ns();
  for (i = 0u; i < count; ++i) {
    bench_index_key(key, sizeof(key), i);
    if (er_store_blob_index_put(&store, ER_STORE_INDEX_DEFAULT, key, hash) != ER_OK) {
      return 0;
    }
  }
  elapsed = bench_store_now_ns() - start;
  printf("%s-put %7u keys %9.2f keys/s\n", label, (unsigned)count,
         ((double)count * (double)BENCH_STORE_NS_PER_SECOND) / (double)elapsed);

  start = bench_store_now_ns();
  for (i = 0u; i < count; ++i) {
    bench_index_key(key, sizeof(key), i);
    if (er_store_index_get(&store, ER_STORE_INDEX_DEFAULT, key, got) != ER_OK) {
      return 0;
    }
    g_bench_store_sink ^= got[i & (ER_HASH_SIZE - 1u)];
  }
  elapsed = bench_store_now_ns() - start;
  printf("%s-get %7u keys %9.2f keys/s\n", label, (unsigned)count,
         ((double)count * (double)BENCH_STORE_NS_PER_SECOND) / (double)elapsed);

  start = bench_store_now_ns();
  for (i = 0u; i < count; ++i) {
    bench_index_key(key, sizeof(key), i);
    if (er_store_index_get_entry(&store, ER_STORE_INDEX_DEFAULT, key, &entry) != ER_OK ||
        entry.value_kind != ER_STORE_VALUE_BLOB ||
        entry.value_size != BENCH_STORE_BLOB_BYTES) {
      return 0;
    }
    g_bench_store_sink ^= entry.hash[i & (ER_HASH_SIZE - 1u)];
  }
  elapsed = bench_store_now_ns() - start;
  printf("%s-entry %5u keys %9.2f keys/s\n", label, (unsigned)count,
         ((double)count * (double)BENCH_STORE_NS_PER_SECOND) / (double)elapsed);

  start = bench_store_now_ns();
  if (er_store_index_cursor_open(&store, ER_STORE_INDEX_DEFAULT, "row/0", &cursor) != ER_OK) {
    return 0;
  }
  while (er_store_index_cursor_next(&cursor, &entry) == ER_OK) {
    g_bench_store_sink ^= entry.hash[cursor_count & (ER_HASH_SIZE - 1u)];
    ++cursor_count;
  }
  elapsed = bench_store_now_ns() - start;
  printf("%s-prefix %5u hits %9.2f keys/s\n", label, (unsigned)cursor_count,
         ((double)cursor_count * (double)BENCH_STORE_NS_PER_SECOND) / (double)elapsed);
  return cursor_count != 0u ? 1 : 0;
}

int main(void) {
  BenchIo io;
  uint8_t* arena;
  uint8_t* data;
  uint8_t* out;
  int ok;

  io.bytes = (uint8_t*)malloc(BENCH_STORE_IO_CAP);
  arena = (uint8_t*)malloc(BENCH_STORE_ARENA_BYTES);
  data = (uint8_t*)malloc(BENCH_STORE_OBJECT_BYTES);
  out = (uint8_t*)malloc(BENCH_STORE_OBJECT_BYTES);
  if (io.bytes == 0 || arena == 0 || data == 0 || out == 0) {
    fprintf(stderr, "bench_store allocation failed\n");
    free(io.bytes);
    free(arena);
    free(data);
    free(out);
    return 1;
  }
  io.cap = BENCH_STORE_IO_CAP;
  io.size = 0u;
  io.writes = 0u;
  io.reads = 0u;
  io.syncs = 0u;
  bench_store_fill(data, BENCH_STORE_OBJECT_BYTES, 0u);

  printf("store benchmark\n");
  ok = bench_blob_put(&io, arena, data) != 0 &&
       bench_blob_dedup(&io, arena, data) != 0 &&
       bench_object_put_get(&io, arena, data, out) != 0 &&
       bench_replay(&io, arena, data) != 0 &&
       bench_index(&io, arena, data, "index20k", BENCH_STORE_INDEX_QUICK_ITERS) != 0 &&
       bench_index(&io, arena, data, "index100k", BENCH_STORE_INDEX_MEDIUM_ITERS) != 0;
  printf("io reads=%llu writes=%llu syncs=%llu sink=%u\n",
         (unsigned long long)io.reads, (unsigned long long)io.writes,
         (unsigned long long)io.syncs, (unsigned)g_bench_store_sink);

  free(io.bytes);
  free(arena);
  free(data);
  free(out);
  return ok != 0 ? 0 : 1;
}
