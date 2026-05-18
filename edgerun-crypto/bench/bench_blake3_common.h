#ifndef EDGERUN_CRYPTO_BENCH_BLAKE3_COMMON_H
#define EDGERUN_CRYPTO_BENCH_BLAKE3_COMMON_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

typedef struct {
  const char* name;
  size_t bytes_len;
  size_t iterations;
} BenchCase;

#define BENCH_RUNS 5u
#define BENCH_NS_PER_SECOND 1000000000ull
#define BENCH_BYTES_PER_KIB 1024u
#define BENCH_SMALL_BYTES 64u
#define BENCH_64K_BYTES (64u * BENCH_BYTES_PER_KIB)
#define BENCH_1M_BYTES (BENCH_BYTES_PER_KIB * BENCH_BYTES_PER_KIB)
#define BENCH_8M_BYTES (8u * BENCH_1M_BYTES)
#define BENCH_64M_BYTES (64u * BENCH_1M_BYTES)
#define BENCH_SMALL_ITERATIONS 500000u
#define BENCH_CHUNK_ITERATIONS 100000u
#define BENCH_64K_ITERATIONS 5000u
#define BENCH_1M_ITERATIONS 500u
#define BENCH_8M_ITERATIONS 64u
#define BENCH_64M_ITERATIONS 8u
#define BENCH_PATTERN_MULTIPLIER 131u
#define BENCH_PATTERN_ADDEND 17u
#define BENCH_PATTERN_BYTE_MASK 0xffu

static volatile uint8_t g_bench_sink;

static uint64_t bench_now_ns(void) {
  struct timespec ts;

  if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) {
    return 0u;
  }
  return ((uint64_t)ts.tv_sec * BENCH_NS_PER_SECOND) + (uint64_t)ts.tv_nsec;
}

static void bench_fill(uint8_t* bytes, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = (uint8_t)((i * BENCH_PATTERN_MULTIPLIER + BENCH_PATTERN_ADDEND) & BENCH_PATTERN_BYTE_MASK);
  }
}

static uint8_t bench_run_case_once(const BenchCase* c, const uint8_t* bytes, uint64_t* out_elapsed_ns) {
  uint8_t digest[BENCH_BLAKE3_OUT_LEN];
  uint64_t start;
  uint64_t end;
  size_t i;

  start = bench_now_ns();
  if (start == 0u) {
    return 0u;
  }
  //@optimizer-ignore benchmark intentionally repeats the hash workload for stable timing
  for (i = 0u; i < c->iterations; ++i) {
    //@optimizer-ignore benchmark hot loop intentionally calls the hash backend each iteration
    if (bench_blake3_hash(bytes, c->bytes_len, digest) == 0u) {
      return 0u;
    }
    g_bench_sink ^= digest[i & (BENCH_BLAKE3_OUT_LEN - 1u)];
  }
  end = bench_now_ns();
  if (end <= start) {
    return 0u;
  }
  *out_elapsed_ns = end - start;
  return 1u;
}

static uint8_t bench_run_case(const BenchCase* c, const uint8_t* bytes) {
  uint64_t elapsed_ns;
  uint64_t best_ns = 0u;
  double seconds;
  double mib;
  double ns_per_byte;
  size_t run;

  for (run = 0u; run < BENCH_RUNS; ++run) {
    if (bench_run_case_once(c, bytes, &elapsed_ns) == 0u) {
      return 0u;
    }
    if (best_ns == 0u || elapsed_ns < best_ns) {
      best_ns = elapsed_ns;
    }
  }

  seconds = (double)best_ns / (double)BENCH_NS_PER_SECOND;
  mib = ((double)c->bytes_len * (double)c->iterations) / ((double)BENCH_BYTES_PER_KIB * (double)BENCH_BYTES_PER_KIB);
  ns_per_byte = (double)best_ns / ((double)c->bytes_len * (double)c->iterations);
  printf("%-10s %9zu bytes x %-8zu best-of-%u %9.2f MiB/s %8.3f ns/B\n",
         c->name, c->bytes_len, c->iterations, (unsigned)BENCH_RUNS, mib / seconds, ns_per_byte);
  return 1u;
}

int main(void) {
  static const BenchCase cases[] = {
    {"small", BENCH_SMALL_BYTES, BENCH_SMALL_ITERATIONS},
    {"chunk", BENCH_BLAKE3_CHUNK_LEN, BENCH_CHUNK_ITERATIONS},
    {"64k", BENCH_64K_BYTES, BENCH_64K_ITERATIONS},
    {"1m", BENCH_1M_BYTES, BENCH_1M_ITERATIONS},
    {"8m", BENCH_8M_BYTES, BENCH_8M_ITERATIONS},
    {"64m", BENCH_64M_BYTES, BENCH_64M_ITERATIONS}
  };
  uint8_t* bytes;
  size_t max_len = 0u;
  size_t i;

  //@optimizer-ignore benchmark owns one shared input allocation and releases it on early failure
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

  printf("BLAKE3 benchmark (%s)\n", bench_blake3_backend_name());
  for (i = 0u; i < sizeof(cases) / sizeof(cases[0]); ++i) {
    if (bench_run_case(&cases[i], bytes) == 0u) {
      //@optimizer-ignore benchmark releases shared input allocation on early failure
      free(bytes);
      return 1;
    }
  }
  printf("sink: %u\n", (unsigned)g_bench_sink);

  free(bytes);
  return 0;
}

#endif
