#ifndef ER_TPM_BENCH_H
#define ER_TPM_BENCH_H

#include "er_types.h"

/*
 * Purpose: run opt-in TPM hardware benchmarks through the real CRB transport.
 * Intention: report measured silicon latency only, never canned transport data.
 */

void er_tpm_real_benchmark(EFI_SYSTEM_TABLE* system_table);

#endif
