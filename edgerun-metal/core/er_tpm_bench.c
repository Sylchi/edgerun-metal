#include "er_tpm_bench.h"

#include "er_acpi.h"
#include "er_mem.h"
#include "er_print.h"
#include "er_tls.h"
#include "er_tpm_acpi.h"

enum {
  ER_TPM_BENCH_CALIBRATION_US = 100000u,
  ER_TPM_BENCH_GET_RANDOM_ITERATIONS = 128u,
  ER_TPM_BENCH_SHA256_ITERATIONS = 128u,
  ER_TPM_BENCH_HMAC_ITERATIONS = 128u,
  ER_TPM_BENCH_AES_ITERATIONS = 128u,
  ER_TPM_BENCH_RECORD_ITERATIONS = 64u,
  ER_TPM_BENCH_RANDOM_BYTES = 16u,
  ER_TPM_BENCH_RECORD_HEADER_BYTES = 5u,
  ER_TPM_BENCH_DATA_BYTES = 32u,
  ER_TPM_BENCH_RECORD_BYTES = 16u,
  ER_TPM_BENCH_RECORD_FROM_CLIENT = 1u,
  ER_TPM_BENCH_NS_PER_US = 1000u,
  ER_TPM_BENCH_NS_PER_SECOND = 1000000000u,
  ER_TPM_BENCH_DATA_SEED = 0u,
  ER_TPM_BENCH_KEY_SEED = 0x40u,
  ER_TPM_BENCH_IV_SEED = 0x80u,
  ER_TPM_BENCH_ALGORITHM_PROPERTY_START = 0u,
  ER_TPM_BENCH_CAPABILITY_COUNT = 128u,
  ER_TPM_BENCH_KEY_HMAC_SHA256 = 1u,
  ER_TPM_BENCH_KEY_AES_128 = 2u,
  ER_TPM_BENCH_DIGEST_SHA256 = 1u,
  ER_TPM_BENCH_DIGEST_HMAC_SHA256 = 2u,
  ER_TPM_BENCH_COMMAND_BYTES = 512u,
  ER_TPM_BENCH_RESPONSE_BYTES = 4096u
};

typedef UINT8 (*ErTpmBenchCaseFn)(void* user);

typedef struct {
  ErTpmCrbTransport transport;
  UINT32 calls;
} ErTpmBenchTransport;

typedef struct {
  ErTpmBenchTransport transport;
  ErTlsTpm tls_tpm;
  UINT32 hmac_handle;
  UINT32 aes_handle;
  UINT8 data[ER_TPM_BENCH_DATA_BYTES];
  UINT8 digest[ER_TPM_SHA256_DIGEST_LEN];
  UINT8 random[ER_TPM_BENCH_RANDOM_BYTES];
  UINT8 key[ER_TPM_AES_128_KEY_LEN];
  UINT8 iv[ER_TPM_AES_BLOCK_LEN];
  UINT8 out_iv[ER_TPM_AES_BLOCK_LEN];
  UINT8 ciphertext[ER_TPM_BENCH_RECORD_BYTES];
  UINT8 record[ER_TPM_BENCH_RECORD_HEADER_BYTES + ER_TPM_BENCH_RECORD_BYTES +
                ER_TLS_RECORD_TAG_BYTES];
  ErTlsRecordKeys record_keys;
  UINT8 hmac_ready;
  UINT8 aes_ready;
  UINT8 record_ready;
  UINT64 sink;
} ErTpmBenchState;

static UINT8 er_tpm_bench_read_cycles(UINT64* out_cycles) {
#if defined(ER_TARGET_X86_64)
  UINT32 low;
  UINT32 high;

  if (out_cycles == 0) {
    return 0u;
  }
  __asm__ __volatile__("rdtsc" : "=a"(low), "=d"(high));
  *out_cycles = ((UINT64)high << 32u) | (UINT64)low;
  return 1u;
#elif defined(ER_TARGET_AARCH64)
  UINT64 value;

  if (out_cycles == 0) {
    return 0u;
  }
  __asm__ __volatile__("mrs %0, cntvct_el0" : "=r"(value));
  *out_cycles = value;
  return 1u;
#else
  (void)out_cycles;
  return 0u;
#endif
}

static UINT8 er_tpm_bench_calibrate_cycles(EFI_SYSTEM_TABLE* system_table,
                                           UINT64* out_cycles_per_us) {
  UINT64 begin;
  UINT64 end;
  UINT64 elapsed;

  if (system_table == 0 || system_table->BootServices == 0 ||
      system_table->BootServices->Stall == 0 ||
      out_cycles_per_us == 0 ||
      er_tpm_bench_read_cycles(&begin) == 0u ||
      system_table->BootServices->Stall(ER_TPM_BENCH_CALIBRATION_US) != EFI_SUCCESS ||
      er_tpm_bench_read_cycles(&end) == 0u ||
      end <= begin) {
    return 0u;
  }
  elapsed = end - begin;
  if (elapsed < ER_TPM_BENCH_CALIBRATION_US) {
    return 0u;
  }
  *out_cycles_per_us = elapsed / ER_TPM_BENCH_CALIBRATION_US;
  return (UINT8)(*out_cycles_per_us != 0u);
}

static UINT8 er_tpm_bench_transport_transact(ErTpmBenchTransport* transport,
                                             const UINT8* command,
                                             UINT32 command_len,
                                             UINT8* response,
                                             UINT32 response_capacity,
                                             UINT32* out_response_len) {
  if (transport == 0 || command == 0 || response == 0 || out_response_len == 0) {
    return 0u;
  }
  ++transport->calls;
  return er_tpm_crb_transact(&transport->transport,
                             command,
                             command_len,
                             response,
                             response_capacity,
                             out_response_len);
}

static UINT8 er_tpm_bench_crb_transact(void* user,
                                       const UINT8* command,
                                       UINT32 command_len,
                                       UINT8* response,
                                       UINT32 response_capacity,
                                       UINT32* out_response_len) {
  return er_tpm_bench_transport_transact((ErTpmBenchTransport*)user,
                                         command,
                                         command_len,
                                         response,
                                         response_capacity,
                                         out_response_len);
}

static UINT8 er_tpm_bench_get_capability(ErTpmBenchTransport* transport,
                                         UINT32 capability,
                                         UINT32 property,
                                         UINT8* response,
                                         UINT32 response_capacity,
                                         UINT32* out_response_len) {
  UINT8 command[ER_TPM_BENCH_COMMAND_BYTES];
  UINT32 command_len;

  if (transport == 0 || response == 0 || out_response_len == 0 ||
      er_tpm_build_get_capability_command(capability,
                                          property,
                                          ER_TPM_BENCH_CAPABILITY_COUNT,
                                          command,
                                          (UINT32)sizeof(command),
                                          &command_len) == 0u) {
    return 0u;
  }
  return er_tpm_bench_transport_transact(transport,
                                         command,
                                         command_len,
                                         response,
                                         response_capacity,
                                         out_response_len);
}

static UINT8 er_tpm_bench_startup(ErTpmBenchTransport* transport) {
  UINT8 command[ER_TPM_BENCH_COMMAND_BYTES];
  UINT8 response[ER_TPM_BENCH_RESPONSE_BYTES];
  UINT32 command_len;
  UINT32 response_len;
  UINT32 response_code;

  if (transport == 0 ||
      er_tpm_build_startup_command(ER_TPM_SU_CLEAR,
                                   command,
                                   (UINT32)sizeof(command),
                                   &command_len) == 0u ||
      er_tpm_crb_transact(&transport->transport,
                          command,
                          command_len,
                          response,
                          (UINT32)sizeof(response),
                          &response_len) == 0u) {
    return 0u;
  }
  ++transport->calls;
  response_code = er_tpm_response_code(response, response_len);
  return (UINT8)(response_code == ER_TPM_RC_SUCCESS ||
                 response_code == ER_TPM_RC_INITIALIZE);
}

static UINT8 er_tpm_bench_key_load_result(ErTpmBenchState* state,
                                          UINT8 key_loaded,
                                          UINT32* out_response_code) {
  if (state == 0 || out_response_code == 0) {
    return 0u;
  }
  if (key_loaded == 0u) {
    *out_response_code = er_tpm_response_code(state->tls_tpm.response,
                                              state->tls_tpm.last_response_len);
    return 0u;
  }
  *out_response_code = ER_TPM_RC_SUCCESS;
  return 1u;
}

static void er_tpm_bench_fill_sequence(UINT8* buffer, UINT32 buffer_len, UINT8 seed) {
  UINT32 i;

  if (buffer == 0) {
    return;
  }
  for (i = 0u; i < buffer_len; ++i) {
    buffer[i] = (UINT8)((UINT32)seed + i);
  }
}

static UINT8 er_tpm_bench_load_key(ErTpmBenchState* state,
                                   UINT8 key_type,
                                   UINT32* out_handle,
                                   UINT32* out_response_code) {
  if (state == 0 || out_handle == 0 || out_response_code == 0) {
    return 0u;
  }
  *out_response_code = ER_TPM_RC_METAL_PROTOCOL;
  switch (key_type) {
    case ER_TPM_BENCH_KEY_HMAC_SHA256:
      return er_tpm_bench_key_load_result(
          state,
          er_tls_tpm_load_hmac_sha256_key(&state->tls_tpm,
                                          state->data,
                                          ER_TPM_SHA256_DIGEST_LEN,
                                          out_handle),
          out_response_code);
    case ER_TPM_BENCH_KEY_AES_128:
      return er_tpm_bench_key_load_result(
          state,
          er_tls_tpm_load_aes_key(&state->tls_tpm,
                                  state->key,
                                  ER_TPM_AES_128_KEY_LEN,
                                  ER_TPM_AES_128_KEY_BITS,
                                  out_handle),
          out_response_code);
    default:
      return 0u;
  }
}

static UINT8 er_tpm_bench_init(EFI_SYSTEM_TABLE* system_table,
                               ErTpmBenchState* state) {
  ErAcpiRsdpInfo rsdp;
  ErAcpiTableList tables;
  ErTpm2Info tpm2;
  ErTpmAlgorithmProfile algorithms;
  ErTpmCommandProfile commands;
  UINT8 response[ER_TPM_BENCH_RESPONSE_BYTES];
  UINT32 response_len;
  UINT32 response_code;

  if (system_table == 0 || state == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)state, (UINTN)sizeof(*state));
  if (er_acpi_find_rsdp(system_table, &rsdp) == 0u) {
    er_println("TPM real bench failed: stage=acpi-rsdp");
    return 0u;
  }
  if (er_acpi_enumerate_tables(&rsdp, &tables) == 0u) {
    er_println("TPM real bench failed: stage=acpi-tables");
    return 0u;
  }
  if (er_tpm_find_tpm2_table(&tables, &tpm2) == 0u) {
    er_println("TPM real bench failed: stage=tpm2-table");
    return 0u;
  }
  if (er_tpm_crb_from_tpm2_info(&tpm2, &state->transport.transport) == 0u) {
    er_println("TPM real bench failed: stage=crb-transport");
    return 0u;
  }
  if (er_tpm_bench_startup(&state->transport) == 0u) {
    er_println("TPM real bench failed: stage=startup");
    return 0u;
  }
  if (er_tpm_bench_get_capability(&state->transport,
                                  ER_TPM_CAP_ALGS,
                                  ER_TPM_BENCH_ALGORITHM_PROPERTY_START,
                                  response,
                                  (UINT32)sizeof(response),
                                  &response_len) == 0u) {
    er_println("TPM real bench failed: stage=cap-algs");
    return 0u;
  }
  if (er_tpm_parse_algorithm_profile_response(response, response_len, &algorithms) == 0u) {
    er_println("TPM real bench failed: stage=parse-algs");
    return 0u;
  }
  if (er_tpm_bench_get_capability(&state->transport,
                                  ER_TPM_CAP_COMMANDS,
                                  ER_TPM_CC_CREATE_PRIMARY,
                                  response,
                                  (UINT32)sizeof(response),
                                  &response_len) == 0u) {
    er_println("TPM real bench failed: stage=cap-commands");
    return 0u;
  }
  if (er_tpm_parse_command_profile_response(response, response_len, &commands) == 0u) {
    er_println("TPM real bench failed: stage=parse-commands");
    return 0u;
  }
  if (er_tls_tpm_init(&state->tls_tpm,
                      er_tpm_bench_crb_transact,
                      &state->transport,
                      &tpm2,
                      &algorithms,
                      &commands) == 0u) {
    er_println("TPM real bench failed: stage=tls-profile");
    return 0u;
  }

  er_tpm_bench_fill_sequence(state->data,
                             ER_TPM_BENCH_DATA_BYTES,
                             ER_TPM_BENCH_DATA_SEED);
  er_tpm_bench_fill_sequence(state->key,
                             ER_TPM_AES_128_KEY_LEN,
                             ER_TPM_BENCH_KEY_SEED);
  er_tpm_bench_fill_sequence(state->iv,
                             ER_TPM_AES_BLOCK_LEN,
                             ER_TPM_BENCH_IV_SEED);

  if (er_tpm_bench_load_key(state,
                            ER_TPM_BENCH_KEY_HMAC_SHA256,
                            &state->hmac_handle,
                            &response_code) != 0u) {
    state->hmac_ready = 1u;
    state->record_keys.client_hmac_handle = state->hmac_handle;
  } else {
    er_print("TPM real bench unsupported: case=hmac-sha256-32 stage=load-hmac-key rc=");
    er_print_u64_hex((UINT64)response_code);
    er_println("");
  }
  if (er_tpm_bench_load_key(state,
                            ER_TPM_BENCH_KEY_AES_128,
                            &state->aes_handle,
                            &response_code) != 0u) {
    state->aes_ready = 1u;
    state->record_keys.client_aes_handle = state->aes_handle;
  } else {
    er_print("TPM real bench unsupported: case=aes-crypt-16 stage=load-aes-key rc=");
    er_print_u64_hex((UINT64)response_code);
    er_println("");
  }
  if (state->hmac_ready != 0u && state->aes_ready != 0u) {
    er_mem_copy(state->record_keys.client_iv, state->iv, ER_TLS_RECORD_IV_BYTES);
    state->record_keys.ready = 1u;
    state->record_ready = 1u;
  } else {
    er_println("TPM real bench unsupported: case=tls-record-protect-16 stage=record-keys");
  }
  return 1u;
}

static UINT8 er_tpm_bench_get_random_case(void* user) {
  ErTpmBenchState* state = (ErTpmBenchState*)user;

  if (state == 0 ||
      er_tls_tpm_get_random(&state->tls_tpm,
                            state->random,
                            ER_TPM_BENCH_RANDOM_BYTES) == 0u) {
    return 0u;
  }
  state->sink += state->random[0];
  return 1u;
}

static UINT8 er_tpm_bench_digest_case(ErTpmBenchState* state, UINT8 digest_case) {
  UINT8 ok;

  if (state == 0) {
    return 0u;
  }
  switch (digest_case) {
    case ER_TPM_BENCH_DIGEST_SHA256:
      ok = er_tls_tpm_sha256(&state->tls_tpm,
                             state->data,
                             ER_TPM_BENCH_DATA_BYTES,
                             state->digest);
      break;
    case ER_TPM_BENCH_DIGEST_HMAC_SHA256:
      if (state->hmac_ready == 0u) {
        return 0u;
      }
      ok = er_tls_tpm_hmac_sha256(&state->tls_tpm,
                                  state->hmac_handle,
                                  state->data,
                                  ER_TPM_BENCH_DATA_BYTES,
                                  state->digest);
      break;
    default:
      return 0u;
  }
  if (ok == 0u) {
    return 0u;
  }
  state->sink += state->digest[0];
  return 1u;
}

static UINT8 er_tpm_bench_sha256_case(void* user) {
  return er_tpm_bench_digest_case((ErTpmBenchState*)user,
                                  ER_TPM_BENCH_DIGEST_SHA256);
}

static UINT8 er_tpm_bench_hmac_case(void* user) {
  return er_tpm_bench_digest_case((ErTpmBenchState*)user,
                                  ER_TPM_BENCH_DIGEST_HMAC_SHA256);
}

static UINT8 er_tpm_bench_aes_case(void* user) {
  ErTpmBenchState* state = (ErTpmBenchState*)user;
  UINT32 data_len;
  UINT32 iv_len;

  if (state == 0 ||
      state->aes_ready == 0u ||
      er_tls_tpm_record_crypt(&state->tls_tpm,
                              state->aes_handle,
                              0u,
                              state->iv,
                              ER_TPM_AES_BLOCK_LEN,
                              state->data,
                              ER_TPM_BENCH_RECORD_BYTES,
                              state->ciphertext,
                              (UINT32)sizeof(state->ciphertext),
                              &data_len,
                              state->out_iv,
                              (UINT32)sizeof(state->out_iv),
                              &iv_len) == 0u ||
      data_len != ER_TPM_BENCH_RECORD_BYTES ||
      iv_len != ER_TPM_AES_BLOCK_LEN) {
    return 0u;
  }
  state->sink += state->ciphertext[0];
  return 1u;
}

static UINT8 er_tpm_bench_record_case(void* user) {
  ErTpmBenchState* state = (ErTpmBenchState*)user;
  UINT16 record_len;
  UINT8 status;

  if (state == 0 || state->record_ready == 0u) {
    return 0u;
  }
  state->record_keys.client_sequence = 0u;
  er_mem_copy(state->record_keys.client_iv, state->iv, ER_TLS_RECORD_IV_BYTES);
  status = er_tls_record_protect(&state->tls_tpm,
                                 &state->record_keys,
                                 ER_TPM_BENCH_RECORD_FROM_CLIENT,
                                 state->data,
                                 ER_TPM_BENCH_RECORD_BYTES,
                                 state->record,
                                 (UINT16)sizeof(state->record),
                                 &record_len);
  if (status != ER_TLS_STATUS_OK) {
    return 0u;
  }
  state->sink += record_len;
  return 1u;
}

static void er_tpm_bench_print_result(const char* name,
                                      UINT32 iterations,
                                      UINT32 tpm_calls,
                                      UINT64 elapsed_cycles,
                                      UINT64 cycles_per_us) {
  UINT64 cycles_per_op;
  UINT64 ns_per_op;
  UINT64 ops_per_second;

  cycles_per_op = elapsed_cycles / iterations;
  ns_per_op = (cycles_per_op * ER_TPM_BENCH_NS_PER_US) / cycles_per_us;
  ops_per_second = ns_per_op == 0u ? 0u : ER_TPM_BENCH_NS_PER_SECOND / ns_per_op;
  er_print("TPM real bench: case=");
  er_print(name);
  er_print(" iterations=");
  er_print_u64_dec((UINT64)iterations);
  er_print(" tpm-calls=");
  er_print_u64_dec((UINT64)tpm_calls);
  er_print(" cycles-total=");
  er_print_u64_dec(elapsed_cycles);
  er_print(" cycles-op=");
  er_print_u64_dec(cycles_per_op);
  er_print(" ns-op-est=");
  er_print_u64_dec(ns_per_op);
  er_print(" ops-sec-est=");
  er_print_u64_dec(ops_per_second);
  er_println("");
}

static UINT8 er_tpm_bench_run_case(ErTpmBenchState* state,
                                   const char* name,
                                   ErTpmBenchCaseFn fn,
                                   UINT32 iterations,
                                   UINT64 cycles_per_us) {
  UINT32 i;
  UINT32 calls_before;
  UINT32 calls_after;
  UINT64 begin;
  UINT64 end;

  if (state == 0 || name == 0 || fn == 0 || iterations == 0u ||
      cycles_per_us == 0u ||
      er_tpm_bench_read_cycles(&begin) == 0u) {
    return 0u;
  }
  calls_before = state->transport.calls;
  for (i = 0u; i < iterations; ++i) {
    if (fn(state) == 0u) {
      er_print("TPM real bench failed: case=");
      er_print(name);
      er_print(" iteration=");
      er_print_u64_dec((UINT64)i);
      er_println("");
      return 0u;
    }
  }
  if (er_tpm_bench_read_cycles(&end) == 0u || end <= begin) {
    return 0u;
  }
  calls_after = state->transport.calls;
  er_tpm_bench_print_result(name,
                            iterations,
                            calls_after - calls_before,
                            end - begin,
                            cycles_per_us);
  return 1u;
}

void er_tpm_real_benchmark(EFI_SYSTEM_TABLE* system_table) {
  ErTpmBenchState state;
  UINT64 cycles_per_us;
  UINT8 ok;

  er_println("TPM real bench: transport=CRB source=hardware");
  if (er_tpm_bench_calibrate_cycles(system_table, &cycles_per_us) == 0u) {
    er_println("TPM real bench failed: cycle calibration unavailable");
    return;
  }
  er_print("TPM real bench: cycles-per-us=");
  er_print_u64_dec(cycles_per_us);
  er_println("");
  if (er_tpm_bench_init(system_table, &state) == 0u) {
    er_println("TPM real bench failed: hardware init unavailable");
    return;
  }
  ok = (UINT8)(er_tpm_bench_run_case(&state,
                                     "get-random-16",
                                     er_tpm_bench_get_random_case,
                                     ER_TPM_BENCH_GET_RANDOM_ITERATIONS,
                                     cycles_per_us) != 0u &&
               er_tpm_bench_run_case(&state,
                                     "sha256-32",
                                     er_tpm_bench_sha256_case,
                                     ER_TPM_BENCH_SHA256_ITERATIONS,
                                     cycles_per_us) != 0u);
  if (ok != 0u && state.hmac_ready != 0u) {
    ok = er_tpm_bench_run_case(&state,
                               "hmac-sha256-32",
                               er_tpm_bench_hmac_case,
                               ER_TPM_BENCH_HMAC_ITERATIONS,
                               cycles_per_us);
  }
  if (ok != 0u && state.aes_ready != 0u) {
    ok = er_tpm_bench_run_case(&state,
                               "aes-crypt-16",
                               er_tpm_bench_aes_case,
                               ER_TPM_BENCH_AES_ITERATIONS,
                               cycles_per_us);
  }
  if (ok != 0u && state.record_ready != 0u) {
    ok = er_tpm_bench_run_case(&state,
                               "tls-record-protect-16",
                               er_tpm_bench_record_case,
                               ER_TPM_BENCH_RECORD_ITERATIONS,
                               cycles_per_us);
  }
  if (ok == 0u) {
    (void)er_tls_record_keys_close(&state.tls_tpm, &state.record_keys);
    return;
  }
  er_print("TPM real bench: sink=");
  er_print_u64_dec(state.sink);
  er_print(" total-tpm-calls=");
  er_print_u64_dec((UINT64)state.transport.calls);
  er_println("");
  (void)er_tls_record_keys_close(&state.tls_tpm, &state.record_keys);
}
