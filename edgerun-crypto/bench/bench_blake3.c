#include "er_blake3.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct {
  const char* name;
  size_t bytes_len;
  size_t iterations;
} BenchCase;

static volatile uint8_t g_bench_sink;

static uint64_t bench_now_ns(void) {
  struct timespec ts;

  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0u;
  }
  return ((uint64_t)ts.tv_sec * 1000000000ull) + (uint64_t)ts.tv_nsec;
}

static void bench_fill(uint8_t* bytes, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = (uint8_t)((i * 131u + 17u) & 0xffu);
  }
}

static uint8_t bench_run_case(const BenchCase* c, const uint8_t* bytes) {
  uint8_t digest[ER_BLAKE3_OUT_LEN];
  uint64_t start;
  uint64_t end;
  double seconds;
  double mib;
  double ns_per_byte;
  size_t i;

  start = bench_now_ns();
  if (start == 0u) {
    return 0u;
  }
  for (i = 0u; i < c->iterations; ++i) {
    if (er_blake3_hash_bytes(bytes, c->bytes_len, digest) == 0u) {
      return 0u;
    }
    g_bench_sink ^= digest[i & (ER_BLAKE3_OUT_LEN - 1u)];
  }
  end = bench_now_ns();
  if (end <= start) {
    return 0u;
  }

  seconds = (double)(end - start) / 1000000000.0;
  mib = ((double)c->bytes_len * (double)c->iterations) / (1024.0 * 1024.0);
  ns_per_byte = (double)(end - start) / ((double)c->bytes_len * (double)c->iterations);
  printf("%-10s %9zu bytes x %-8zu %9.2f MiB/s %8.3f ns/B\n",
         c->name, c->bytes_len, c->iterations, mib / seconds, ns_per_byte);
  return 1u;
}

int main(void) {
  static const BenchCase cases[] = {
    {"small", 64u, 500000u},
    {"chunk", ER_BLAKE3_CHUNK_LEN, 100000u},
    {"64k", 65536u, 5000u},
    {"1m", 1048576u, 500u}
  };
  uint8_t* bytes;
  size_t max_len = 0u;
  size_t i;

  for (i = 0u; i < sizeof(cases) / sizeof(cases[0]); ++i) {
    if (cases[i].bytes_len > max_len) {
      max_len = cases[i].bytes_len;
    }
  }

  bytes = (uint8_t*)malloc(max_len);
  if (bytes == 0) {
    fprintf(stderr, "failed to allocate %zu bytes\n", max_len);
    return 1;
  }
  bench_fill(bytes, max_len);

  printf("BLAKE3 portable benchmark\n");
  for (i = 0u; i < sizeof(cases) / sizeof(cases[0]); ++i) {
    if (bench_run_case(&cases[i], bytes) == 0u) {
      free(bytes);
      return 1;
    }
  }
  printf("sink: %u\n", (unsigned)g_bench_sink);

  free(bytes);
  return 0;
}
