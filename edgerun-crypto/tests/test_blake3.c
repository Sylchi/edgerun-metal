#include "er_blake3.h"

#include <stdint.h>
#include <stdio.h>

static int g_failed = 0;
static int g_total = 0;

static uint8_t hex_nibble(char c) {
  if (c >= '0' && c <= '9') {
    return (uint8_t)(c - '0');
  }
  if (c >= 'a' && c <= 'f') {
    return (uint8_t)(c - 'a' + 10);
  }
  if (c >= 'A' && c <= 'F') {
    return (uint8_t)(c - 'A' + 10);
  }
  return 0xffu;
}

static void check_hash_hex(const char* name, const uint8_t actual[ER_BLAKE3_OUT_LEN], const char* expected_hex) {
  size_t i;
  uint8_t high;
  uint8_t low;
  uint8_t expected;

  ++g_total;
  for (i = 0u; i < ER_BLAKE3_OUT_LEN; ++i) {
    high = hex_nibble(expected_hex[i * 2u]);
    low = hex_nibble(expected_hex[(i * 2u) + 1u]);
    expected = (uint8_t)((high << 4u) | low);
    if (high > 0x0fu || low > 0x0fu || actual[i] != expected) {
      fprintf(stderr, "FAIL %s: byte %zu got 0x%02x expected 0x%02x\n", name, i, actual[i], expected);
      ++g_failed;
      return;
    }
  }
}

static void check_int(const char* name, int actual, int expected) {
  ++g_total;
  if (actual != expected) {
    fprintf(stderr, "FAIL %s: got %d expected %d\n", name, actual, expected);
    ++g_failed;
  }
}

int main(void) {
  static const uint8_t abc[] = {'a', 'b', 'c'};
  uint8_t large[4096];
  uint8_t huge[65536];
  uint8_t digest[ER_BLAKE3_OUT_LEN];
  ErBlake3Hasher hasher;
  size_t i;

  check_int("empty hash", er_blake3_hash_bytes(0, 0u, digest), 1);
  check_hash_hex("empty digest", digest, "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262");

  check_int("abc hash", er_blake3_hash_bytes(abc, sizeof(abc), digest), 1);
  check_hash_hex("abc digest", digest, "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85");

  for (i = 0u; i < sizeof(large); ++i) {
    large[i] = (uint8_t)(i % 251u);
  }
  for (i = 0u; i < sizeof(huge); ++i) {
    huge[i] = (uint8_t)(i % 251u);
  }
  check_int("large hash", er_blake3_hash_bytes(large, 1255u, digest), 1);
  check_hash_hex("large digest", digest, "8b929b2d329f8795b15060a2e5d087ea507aeba8dcf19fb00eb92ceb890d179e");

  check_int("full chunk hash", er_blake3_hash_bytes(large, 1024u, digest), 1);
  check_hash_hex("full chunk digest", digest, "42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7");

  check_int("chunk plus one hash", er_blake3_hash_bytes(large, 1025u, digest), 1);
  check_hash_hex("chunk plus one digest", digest, "d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444");

  check_int("four chunk hash", er_blake3_hash_bytes(large, sizeof(large), digest), 1);
  check_hash_hex("four chunk digest", digest, "015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969");

  check_int("many chunk hash", er_blake3_hash_bytes(huge, sizeof(huge), digest), 1);
  check_hash_hex("many chunk digest", digest, "68d647e619a930e7b1082f74f334b0c65a315725569bdc123f0ee11881717bfe");

  er_blake3_init(&hasher);
  check_int("update a", er_blake3_update(&hasher, large, 17u), 1);
  check_int("update b", er_blake3_update(&hasher, &large[17], 1255u - 17u), 1);
  check_int("final", er_blake3_final(&hasher, digest), 1);
  check_hash_hex("incremental digest", digest, "8b929b2d329f8795b15060a2e5d087ea507aeba8dcf19fb00eb92ceb890d179e");

  if (g_failed != 0) {
    fprintf(stderr, "FAILED %d/%d checks\n", g_failed, g_total);
    return 1;
  }
  printf("OK %d checks passed\n", g_total);
  return 0;
}
