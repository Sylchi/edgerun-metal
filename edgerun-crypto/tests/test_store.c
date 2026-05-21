#include "er_store.h"

#include <stdint.h>
#include <stdio.h>

enum {
  TEST_IO_CAP = 65536u,
  TEST_ARENA_SIZE = ER_STORE_ARENA_MIN_SIZE,
  TEST_LARGE_ARENA_SIZE = ER_STORE_ARENA_MIN_SIZE + (4u * 1024u * 1024u),
  TEST_FIRST_PAYLOAD_OFF = 68u + 92u,
  TEST_TRAILING_JUNK = 7u,
  TEST_TYPE_ROW = 17u,
  TEST_INDEX_BY_NAME = 23u,
  TEST_OBJECT_BYTES = 8192u,
  TEST_OBJECT_CHUNK = 512u,
  TEST_OBJECT_PATTERN_MOD = 251u
};

typedef struct {
  uint8_t bytes[TEST_IO_CAP];
  uint64_t size;
  unsigned int sync_count;
} TestIo;

static int g_failed = 0;
static int g_total = 0;

static void test_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* bytes = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    bytes[i] = 0u;
  }
}

static void test_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

static int test_bytes_equal(const uint8_t* a, const uint8_t* b, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (a[i] != b[i]) {
      return 0;
    }
  }
  return 1;
}

static int test_read_at(void* ctx, uint64_t off, void* buf, size_t len) {
  TestIo* io = (TestIo*)ctx;

  if (off > io->size || len > (size_t)(io->size - off)) {
    return -1;
  }
  test_copy(buf, &io->bytes[off], len);
  return 0;
}

static int test_write_at(void* ctx, uint64_t off, const void* buf, size_t len) {
  TestIo* io = (TestIo*)ctx;
  uint64_t end = off + len;

  if (end < off || end > TEST_IO_CAP) {
    return -1;
  }
  if (off > io->size) {
    test_zero(&io->bytes[io->size], (size_t)(off - io->size));
  }
  test_copy(&io->bytes[off], buf, len);
  if (end > io->size) {
    io->size = end;
  }
  return 0;
}

static int test_sync(void* ctx) {
  TestIo* io = (TestIo*)ctx;

  ++io->sync_count;
  return 0;
}

static int test_size(void* ctx, uint64_t* out_size) {
  TestIo* io = (TestIo*)ctx;

  *out_size = io->size;
  return 0;
}

static int test_truncate(void* ctx, uint64_t size) {
  TestIo* io = (TestIo*)ctx;

  if (size > TEST_IO_CAP) {
    return -1;
  }
  if (size > io->size) {
    test_zero(&io->bytes[io->size], (size_t)(size - io->size));
  }
  io->size = size;
  return 0;
}

static er_io_t test_make_io(TestIo* io) {
  er_io_t out;

  out.ctx = io;
  out.read_at = test_read_at;
  out.write_at = test_write_at;
  out.sync = test_sync;
  out.size = test_size;
  out.truncate = test_truncate;
  return out;
}

static void check_int(const char* name, int actual, int expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got %d expected %d\n", name, actual, expected);
    ++g_failed;
  }
}

static void check_size(const char* name, size_t actual, size_t expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got %zu expected %zu\n", name, actual, expected);
    ++g_failed;
  }
}

static void check_u64(const char* name, uint64_t actual, uint64_t expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got %llu expected %llu\n", name, (unsigned long long)actual,
            (unsigned long long)expected);
    ++g_failed;
  }
}

static void check_bytes(const char* name, const uint8_t* actual, const uint8_t* expected, size_t len) {
  ++g_total;
  if (!test_bytes_equal(actual, expected, len)) {
    fprintf(stderr, "FAIL %s: byte mismatch\n", name);
    ++g_failed;
  }
}

static void test_open_empty_store(void) {
  static uint8_t arena[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store;

  test_zero(&io, sizeof(io));
  check_int("open empty", er_store_open(&store, test_make_io(&io), arena, sizeof(arena)), ER_OK);
  check_u64("empty superblock size", io.size, 68u);
  check_int("close empty", er_store_close(&store), ER_OK);
}

static void test_put_get_and_duplicate(void) {
  static uint8_t arena[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store;
  uint8_t hash_a[ER_HASH_SIZE];
  uint8_t hash_b[ER_HASH_SIZE];
  uint8_t out[32];
  size_t out_len = 0u;
  uint64_t size_after_first;
  static const uint8_t data[] = {1u, 2u, 3u, 4u, 5u};

  test_zero(&io, sizeof(io));
  check_int("open put", er_store_open(&store, test_make_io(&io), arena, sizeof(arena)), ER_OK);
  check_int("put blob", er_store_put_blob(&store, data, sizeof(data), hash_a), ER_OK);
  size_after_first = io.size;
  check_int("duplicate blob", er_store_put_blob(&store, data, sizeof(data), hash_b), ER_OK);
  check_u64("duplicate no write", io.size, size_after_first);
  check_bytes("duplicate same hash", hash_a, hash_b, ER_HASH_SIZE);
  check_int("get blob", er_store_get_blob(&store, hash_a, out, sizeof(out), &out_len), ER_OK);
  check_size("get blob len", out_len, sizeof(data));
  check_bytes("get blob bytes", out, data, sizeof(data));
}

static void test_index_and_scan(void) {
  static uint8_t arena[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store;
  uint8_t alpha_hash[ER_HASH_SIZE];
  uint8_t beta_hash[ER_HASH_SIZE];
  uint8_t got[ER_HASH_SIZE];
  er_index_entry_t entries[4];
  er_store_index_cursor_t cursor;
  er_index_entry_t cursor_entry;
  size_t count = 0u;
  size_t cursor_count = 0u;
  static const uint8_t alpha[] = {10u};
  static const uint8_t beta[] = {20u, 21u};

  test_zero(&io, sizeof(io));
  check_int("open index", er_store_open(&store, test_make_io(&io), arena, sizeof(arena)), ER_OK);
  check_int("put alpha", er_store_put_blob(&store, alpha, sizeof(alpha), alpha_hash), ER_OK);
  check_int("put beta", er_store_put_blob(&store, beta, sizeof(beta), beta_hash), ER_OK);
  check_int("index put alpha", er_store_index_put(&store, "app/alpha", alpha_hash), ER_OK);
  check_int("index put beta", er_store_index_put(&store, "app/beta", beta_hash), ER_OK);
  check_int("index get alpha", er_store_index_get(&store, "app/alpha", got), ER_OK);
  check_bytes("index get alpha hash", got, alpha_hash, ER_HASH_SIZE);
  check_int("missing key", er_store_index_get(&store, "app/missing", got), ER_ERR_NOTFOUND);
  check_int("prefix scan", er_store_index_scan_prefix(&store, "app/", entries, 4u, &count), ER_OK);
  check_size("prefix scan count", count, 2u);
  check_int("cursor open", er_store_index_cursor_open(&store, ER_STORE_INDEX_DEFAULT, "app/", &cursor), ER_OK);
  while (er_store_index_cursor_next(&cursor, &cursor_entry) == ER_OK) {
    ++cursor_count;
  }
  check_size("cursor count", cursor_count, 2u);
}

static void test_reopen_rebuild_and_latest_wins(void) {
  static uint8_t arena_a[TEST_ARENA_SIZE];
  static uint8_t arena_b[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store_a;
  er_store_t store_b;
  uint8_t first_hash[ER_HASH_SIZE];
  uint8_t second_hash[ER_HASH_SIZE];
  uint8_t got[ER_HASH_SIZE];
  static const uint8_t first[] = {31u, 32u};
  static const uint8_t second[] = {41u, 42u, 43u};

  test_zero(&io, sizeof(io));
  check_int("open rebuild a", er_store_open(&store_a, test_make_io(&io), arena_a, sizeof(arena_a)), ER_OK);
  check_int("put first", er_store_put_blob(&store_a, first, sizeof(first), first_hash), ER_OK);
  check_int("put second", er_store_put_blob(&store_a, second, sizeof(second), second_hash), ER_OK);
  check_int("index first value", er_store_index_put(&store_a, "row/current", first_hash), ER_OK);
  check_int("index second value", er_store_index_put(&store_a, "row/current", second_hash), ER_OK);
  check_int("close rebuild a", er_store_close(&store_a), ER_OK);
  check_int("open rebuild b", er_store_open(&store_b, test_make_io(&io), arena_b, sizeof(arena_b)), ER_OK);
  check_int("rebuilt get", er_store_index_get(&store_b, "row/current", got), ER_OK);
  check_bytes("latest wins", got, second_hash, ER_HASH_SIZE);
}

static void test_trailing_corruption_truncates(void) {
  static uint8_t arena_a[TEST_ARENA_SIZE];
  static uint8_t arena_b[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store_a;
  er_store_t store_b;
  uint8_t hash[ER_HASH_SIZE];
  uint64_t valid_size;
  static const uint8_t data[] = {55u, 56u, 57u};
  static const uint8_t junk[TEST_TRAILING_JUNK] = {1u, 1u, 2u, 3u, 5u, 8u, 13u};

  test_zero(&io, sizeof(io));
  check_int("open corrupt tail a", er_store_open(&store_a, test_make_io(&io), arena_a, sizeof(arena_a)), ER_OK);
  check_int("put corrupt tail blob", er_store_put_blob(&store_a, data, sizeof(data), hash), ER_OK);
  valid_size = io.size;
  check_int("append corrupt tail", test_write_at(&io, io.size, junk, sizeof(junk)), 0);
  check_u64("tail grew", io.size, valid_size + sizeof(junk));
  check_int("open corrupt tail b", er_store_open(&store_b, test_make_io(&io), arena_b, sizeof(arena_b)), ER_OK);
  check_u64("tail truncated", io.size, valid_size);
}

static void test_verify_detects_wrong_hash(void) {
  static uint8_t arena[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store;
  uint8_t hash[ER_HASH_SIZE];
  static const uint8_t data[] = {71u, 72u, 73u, 74u};

  test_zero(&io, sizeof(io));
  check_int("open verify", er_store_open(&store, test_make_io(&io), arena, sizeof(arena)), ER_OK);
  check_int("put verify blob", er_store_put_blob(&store, data, sizeof(data), hash), ER_OK);
  io.bytes[TEST_FIRST_PAYLOAD_OFF] ^= 0x01u;
  check_int("verify wrong hash", er_store_verify(&store), ER_ERR_CORRUPT);
}

static void test_configured_cache_and_capacities(void) {
  static uint8_t arena[TEST_LARGE_ARENA_SIZE];
  TestIo io;
  er_store_t store;
  er_store_config_t config;
  er_store_stats_t stats;
  uint8_t hash[ER_HASH_SIZE];
  uint8_t out[16];
  size_t out_len = 0u;
  static const uint8_t data[] = {81u, 82u, 83u, 84u};

  test_zero(&io, sizeof(io));
  config.blob_slots = 8192u;
  config.key_slots = 8192u;
  config.type_slots = 1024u;
  config.index_slots = 1024u;
  config.cache_bytes = 65536u;
  check_int("open configured", er_store_open_config(&store, test_make_io(&io), arena, sizeof(arena), &config),
            ER_OK);
  check_int("stats configured", er_store_stats(&store, &stats), ER_OK);
  check_size("configured blob slots", stats.blob_slots, 8192u);
  check_size("configured key slots", stats.key_slots, 8192u);
  check_size("configured cache bytes", stats.cache_bytes, config.cache_bytes);
  check_int("configured put", er_store_put_blob(&store, data, sizeof(data), hash), ER_OK);
  check_int("configured get", er_store_get_blob(&store, hash, out, sizeof(out), &out_len), ER_OK);
  check_int("configured stats after cache", er_store_stats(&store, &stats), ER_OK);
  check_size("configured cache used", stats.cache_used, sizeof(data));
}

static void test_typed_blob_and_custom_index_rebuild(void) {
  static uint8_t arena_a[TEST_ARENA_SIZE];
  static uint8_t arena_b[TEST_ARENA_SIZE];
  TestIo io;
  er_store_t store_a;
  er_store_t store_b;
  er_blob_t info;
  uint8_t hash[ER_HASH_SIZE];
  uint8_t got[ER_HASH_SIZE];
  er_index_entry_t entries[4];
  size_t count = 0u;
  static const uint8_t data[] = {91u, 92u, 93u};

  test_zero(&io, sizeof(io));
  check_int("open typed a", er_store_open(&store_a, test_make_io(&io), arena_a, sizeof(arena_a)), ER_OK);
  check_int("define content type", er_store_define_content_type(&store_a, TEST_TYPE_ROW, "row"), ER_OK);
  check_int("define index", er_store_define_index(&store_a, TEST_INDEX_BY_NAME, TEST_TYPE_ROW, "by-name"),
            ER_OK);
  check_int("put typed blob", er_store_put_typed_blob(&store_a, TEST_TYPE_ROW, data, sizeof(data), hash),
            ER_OK);
  check_int("typed info", er_store_get_blob_info(&store_a, hash, &info), ER_OK);
  check_int("typed info type", (int)info.content_type, (int)TEST_TYPE_ROW);
  check_int("custom index put", er_store_index_put_ex(&store_a, TEST_INDEX_BY_NAME, "row/alice", hash), ER_OK);
  check_int("custom index get", er_store_index_get_ex(&store_a, TEST_INDEX_BY_NAME, "row/alice", got), ER_OK);
  check_bytes("custom index hash", got, hash, ER_HASH_SIZE);
  check_int("close typed a", er_store_close(&store_a), ER_OK);
  check_int("open typed b", er_store_open(&store_b, test_make_io(&io), arena_b, sizeof(arena_b)), ER_OK);
  check_int("rebuilt typed info", er_store_get_blob_info(&store_b, hash, &info), ER_OK);
  check_int("rebuilt typed info type", (int)info.content_type, (int)TEST_TYPE_ROW);
  check_int("custom prefix scan",
            er_store_index_scan_prefix_ex(&store_b, TEST_INDEX_BY_NAME, "row/", entries, 4u, &count), ER_OK);
  check_size("custom prefix count", count, 1u);
  check_int("custom prefix index id", (int)entries[0].index_id, (int)TEST_INDEX_BY_NAME);
}

static void test_chunked_object_roundtrip_and_chunk_reuse(void) {
  static uint8_t arena[TEST_LARGE_ARENA_SIZE];
  static uint8_t data[TEST_OBJECT_BYTES];
  static uint8_t out[TEST_OBJECT_BYTES];
  TestIo io;
  er_store_t store;
  er_store_stats_t stats;
  er_blob_t info;
  uint8_t object_hash_a[ER_HASH_SIZE];
  uint8_t object_hash_b[ER_HASH_SIZE];
  size_t out_len = 0u;
  size_t i;
  uint8_t pattern = 0u;
  size_t blob_count_after_first;
  uint64_t size_after_first;

  for (i = 0u; i < sizeof(data); ++i) {
    data[i] = pattern;
    ++pattern;
    if (pattern == TEST_OBJECT_PATTERN_MOD) {
      pattern = 0u;
    }
  }
  test_zero(&io, sizeof(io));
  check_int("open object", er_store_open(&store, test_make_io(&io), arena, sizeof(arena)), ER_OK);
  check_int("put object a",
            er_store_put_object(&store, data, sizeof(data), TEST_OBJECT_CHUNK, object_hash_a), ER_OK);
  check_int("object info", er_store_get_blob_info(&store, object_hash_a, &info), ER_OK);
  check_int("object manifest type", (int)info.content_type, (int)ER_STORE_TYPE_OBJECT_MANIFEST);
  check_int("get object", er_store_get_object(&store, object_hash_a, out, sizeof(out), &out_len), ER_OK);
  check_size("get object len", out_len, sizeof(data));
  check_bytes("get object bytes", out, data, sizeof(data));
  check_int("object stats a", er_store_stats(&store, &stats), ER_OK);
  blob_count_after_first = stats.blob_count;
  size_after_first = io.size;
  check_int("put object duplicate",
            er_store_put_object(&store, data, sizeof(data), TEST_OBJECT_CHUNK, object_hash_b), ER_OK);
  check_bytes("object duplicate hash", object_hash_a, object_hash_b, ER_HASH_SIZE);
  check_int("object stats b", er_store_stats(&store, &stats), ER_OK);
  check_size("object chunk reuse count", stats.blob_count, blob_count_after_first);
  check_u64("object chunk reuse size", io.size, size_after_first);
}

int main(void) {
  test_open_empty_store();
  test_put_get_and_duplicate();
  test_index_and_scan();
  test_reopen_rebuild_and_latest_wins();
  test_trailing_corruption_truncates();
  test_verify_detects_wrong_hash();
  test_configured_cache_and_capacities();
  test_typed_blob_and_custom_index_rebuild();
  test_chunked_object_roundtrip_and_chunk_reuse();

  if (g_failed != 0) {
    fprintf(stderr, "store tests failed: %d/%d\n", g_failed, g_total);
    return 1;
  }
  printf("store tests passed: %d\n", g_total);
  return 0;
}
