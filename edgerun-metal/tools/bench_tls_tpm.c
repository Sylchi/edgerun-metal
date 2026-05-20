#define _POSIX_C_SOURCE 200809L

#include "er_tls.h"
#include "er_mem.h"

#include <stdio.h>
#include <time.h>

enum {
  BENCH_TLS_TPM_BYTE0_INDEX = 0u,
  BENCH_TLS_TPM_BYTE1_INDEX = 1u,
  BENCH_TLS_TPM_BYTE2_INDEX = 2u,
  BENCH_TLS_TPM_BYTE3_INDEX = 3u,
  BENCH_TLS_TPM_U16_BYTES = 2u,
  BENCH_TLS_TPM_U32_BYTES = 4u,
  BENCH_TLS_TPM_BE16_HIGH_BITS = 8u,
  BENCH_TLS_TPM_BE32_HIGH_BITS = 24u,
  BENCH_TLS_TPM_BE32_MID_BITS = 16u,
  BENCH_TLS_TPM_RESPONSE_SIZE_OFFSET = 2u,
  BENCH_TLS_TPM_COMMAND_CODE_OFFSET = 6u,
  BENCH_TLS_TPM_RESPONSE_TAG_BYTE0 = 0x80u,
  BENCH_TLS_TPM_RESPONSE_TAG_NO_SESSIONS = 0x01u,
  BENCH_TLS_TPM_RESPONSE_TAG_SESSIONS = 0x02u,
  BENCH_TLS_TPM_RESPONSE_HANDLE_BYTES = 4u,
  BENCH_TLS_TPM_RESPONSE_PARAMETER_SIZE_BYTES = 4u,
  BENCH_TLS_TPM_VERIFY_TICKET_TAG_OFFSET = 10u,
  BENCH_TLS_TPM_VERIFY_TICKET_HIERARCHY_OFFSET = 12u,
  BENCH_TLS_TPM_VERIFY_TICKET_DIGEST_LEN_OFFSET = 16u,
  BENCH_TLS_TPM_LOAD_EXTERNAL_AES_COMMAND_LEN = 60u,
  BENCH_TLS_TPM_LOAD_EXTERNAL_HMAC_COMMAND_LEN = 74u,
  BENCH_TLS_TPM_VERIFY_TICKET_LEN = 18u,
  BENCH_TLS_TPM_NS_PER_SECOND = 1000000000ull,
  BENCH_TLS_TPM_HANDLE_HMAC = 0x80000010u,
  BENCH_TLS_TPM_HANDLE_AES = 0x80000011u,
  BENCH_TLS_TPM_HANDLE_VERIFY = 0x80000012u,
  BENCH_TLS_TPM_HANDLE_SEQUENCE = 0x80000013u,
  BENCH_TLS_TPM_DIGEST_SEED = 0x33u,
  BENCH_TLS_TPM_CIPHER_SEED = 0xa0u,
  BENCH_TLS_TPM_IV_SEED = 0xb0u,
  BENCH_TLS_TPM_SHORT_ITERATIONS = 200000u,
  BENCH_TLS_TPM_MEDIUM_ITERATIONS = 100000u,
  BENCH_TLS_TPM_VERIFY_ITERATIONS = 50000u,
  BENCH_TLS_TPM_LONG_BYTES = 384u,
  BENCH_TLS_TPM_RECORD_HEADER_BYTES = 5u,
  BENCH_TLS_TPM_RECORD_BYTES = 16u,
  BENCH_TLS_TPM_RECORD_FROM_CLIENT = 1u,
  BENCH_TLS_TPM_RECORD_WIRE_BYTES =
      BENCH_TLS_TPM_RECORD_HEADER_BYTES + BENCH_TLS_TPM_RECORD_BYTES +
      ER_TLS_RECORD_TAG_BYTES
};

typedef UINT8 (*BenchTlsTpmCaseFn)(void* user);

typedef struct {
  UINT32 calls;
  UINT32 last_command_code;
} BenchTlsTpmScript;

typedef struct {
  BenchTlsTpmScript script;
  ErTlsTpm tpm;
  UINT32 hmac_handle;
  UINT32 aes_handle;
  UINT32 verify_handle;
  UINT8 digest[ER_TPM_SHA256_DIGEST_LEN];
  UINT8 key[ER_TPM_AES_128_KEY_LEN];
  UINT8 long_input[BENCH_TLS_TPM_LONG_BYTES];
  UINT8 iv[ER_TPM_AES_BLOCK_LEN];
  UINT8 out_iv[ER_TPM_AES_BLOCK_LEN];
  UINT8 plaintext[BENCH_TLS_TPM_RECORD_BYTES];
  UINT8 ciphertext[BENCH_TLS_TPM_RECORD_BYTES];
  UINT8 signature[64];
  UINT8 public_key[ER_TPM_P256_PUBLIC_KEY_LEN];
  UINT8 record[BENCH_TLS_TPM_RECORD_WIRE_BYTES];
  ErTlsRecordKeys record_keys;
  UINT64 sink;
} BenchTlsTpmState;

static void bench_tls_tpm_put_be16(UINT8* bytes, UINT16 value) {
  bytes[BENCH_TLS_TPM_BYTE0_INDEX] =
      (UINT8)((value >> BENCH_TLS_TPM_BE16_HIGH_BITS) & 0xffu);
  bytes[BENCH_TLS_TPM_BYTE1_INDEX] = (UINT8)(value & 0xffu);
}

static void bench_tls_tpm_put_be32(UINT8* bytes, UINT32 value) {
  bytes[BENCH_TLS_TPM_BYTE0_INDEX] =
      (UINT8)((value >> BENCH_TLS_TPM_BE32_HIGH_BITS) & 0xffu);
  bytes[BENCH_TLS_TPM_BYTE1_INDEX] =
      (UINT8)((value >> BENCH_TLS_TPM_BE32_MID_BITS) & 0xffu);
  bytes[BENCH_TLS_TPM_BYTE2_INDEX] =
      (UINT8)((value >> BENCH_TLS_TPM_BE16_HIGH_BITS) & 0xffu);
  bytes[BENCH_TLS_TPM_BYTE3_INDEX] = (UINT8)(value & 0xffu);
}

static UINT32 bench_tls_tpm_read_be32(const UINT8* bytes) {
  return ((UINT32)bytes[BENCH_TLS_TPM_BYTE0_INDEX] << BENCH_TLS_TPM_BE32_HIGH_BITS) |
         ((UINT32)bytes[BENCH_TLS_TPM_BYTE1_INDEX] << BENCH_TLS_TPM_BE32_MID_BITS) |
         ((UINT32)bytes[BENCH_TLS_TPM_BYTE2_INDEX] << BENCH_TLS_TPM_BE16_HIGH_BITS) |
         (UINT32)bytes[BENCH_TLS_TPM_BYTE3_INDEX];
}

static void bench_tls_tpm_fill(UINT8* bytes, UINT32 len, UINT8 seed) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = (UINT8)(seed + (UINT8)i);
  }
}

static void bench_tls_tpm_response_header(UINT8* response, UINT32 response_len) {
  response[BENCH_TLS_TPM_BYTE0_INDEX] = BENCH_TLS_TPM_RESPONSE_TAG_BYTE0;
  response[BENCH_TLS_TPM_BYTE1_INDEX] = BENCH_TLS_TPM_RESPONSE_TAG_NO_SESSIONS;
  bench_tls_tpm_put_be32(response + BENCH_TLS_TPM_RESPONSE_SIZE_OFFSET, response_len);
  bench_tls_tpm_put_be32(response + BENCH_TLS_TPM_COMMAND_CODE_OFFSET, ER_TPM_RC_SUCCESS);
}

static UINT8 bench_tls_tpm_handle_response(UINT8* response,
                                           UINT32 response_capacity,
                                           UINT32* out_response_len,
                                           UINT32 handle) {
  if (response_capacity < ER_TPM_HEADER_LEN + BENCH_TLS_TPM_RESPONSE_HANDLE_BYTES) {
    return 0u;
  }
  bench_tls_tpm_response_header(response,
                                ER_TPM_HEADER_LEN + BENCH_TLS_TPM_RESPONSE_HANDLE_BYTES);
  bench_tls_tpm_put_be32(response + ER_TPM_HEADER_LEN, handle);
  *out_response_len = ER_TPM_HEADER_LEN + BENCH_TLS_TPM_RESPONSE_HANDLE_BYTES;
  return 1u;
}

static UINT8 bench_tls_tpm_digest_response(UINT8* response,
                                           UINT32 response_capacity,
                                           UINT32* out_response_len) {
  if (response_capacity <
      ER_TPM_HEADER_LEN + BENCH_TLS_TPM_U16_BYTES + ER_TPM_SHA256_DIGEST_LEN) {
    return 0u;
  }
  bench_tls_tpm_response_header(response,
                                ER_TPM_HEADER_LEN + BENCH_TLS_TPM_U16_BYTES +
                                    ER_TPM_SHA256_DIGEST_LEN);
  bench_tls_tpm_put_be16(response + ER_TPM_HEADER_LEN, ER_TPM_SHA256_DIGEST_LEN);
  bench_tls_tpm_fill(response + ER_TPM_HEADER_LEN + BENCH_TLS_TPM_U16_BYTES,
                     ER_TPM_SHA256_DIGEST_LEN,
                     BENCH_TLS_TPM_DIGEST_SEED);
  *out_response_len =
      ER_TPM_HEADER_LEN + BENCH_TLS_TPM_U16_BYTES + ER_TPM_SHA256_DIGEST_LEN;
  return 1u;
}

static UINT8 bench_tls_tpm_crypt_response(UINT8* response,
                                          UINT32 response_capacity,
                                          UINT32* out_response_len) {
  UINT32 response_len = ER_TPM_HEADER_LEN + BENCH_TLS_TPM_RESPONSE_PARAMETER_SIZE_BYTES +
                        BENCH_TLS_TPM_U16_BYTES + BENCH_TLS_TPM_RECORD_BYTES +
                        BENCH_TLS_TPM_U16_BYTES + ER_TPM_AES_BLOCK_LEN;

  if (response_capacity < response_len) {
    return 0u;
  }
  response[BENCH_TLS_TPM_BYTE0_INDEX] = BENCH_TLS_TPM_RESPONSE_TAG_BYTE0;
  response[BENCH_TLS_TPM_BYTE1_INDEX] = BENCH_TLS_TPM_RESPONSE_TAG_SESSIONS;
  bench_tls_tpm_put_be32(response + BENCH_TLS_TPM_RESPONSE_SIZE_OFFSET, response_len);
  bench_tls_tpm_put_be32(response + BENCH_TLS_TPM_COMMAND_CODE_OFFSET, ER_TPM_RC_SUCCESS);
  bench_tls_tpm_put_be32(response + ER_TPM_HEADER_LEN,
                         BENCH_TLS_TPM_U32_BYTES + BENCH_TLS_TPM_RECORD_BYTES +
                             ER_TPM_AES_BLOCK_LEN);
  bench_tls_tpm_put_be16(response + ER_TPM_HEADER_LEN +
                             BENCH_TLS_TPM_RESPONSE_PARAMETER_SIZE_BYTES,
                         BENCH_TLS_TPM_RECORD_BYTES);
  bench_tls_tpm_fill(response + ER_TPM_HEADER_LEN +
                         BENCH_TLS_TPM_RESPONSE_PARAMETER_SIZE_BYTES +
                         BENCH_TLS_TPM_U16_BYTES,
                     BENCH_TLS_TPM_RECORD_BYTES,
                     BENCH_TLS_TPM_CIPHER_SEED);
  bench_tls_tpm_put_be16(response + ER_TPM_HEADER_LEN +
                             BENCH_TLS_TPM_RESPONSE_PARAMETER_SIZE_BYTES +
                             BENCH_TLS_TPM_U16_BYTES + BENCH_TLS_TPM_RECORD_BYTES,
                         ER_TPM_AES_BLOCK_LEN);
  bench_tls_tpm_fill(response + ER_TPM_HEADER_LEN +
                         BENCH_TLS_TPM_RESPONSE_PARAMETER_SIZE_BYTES +
                         BENCH_TLS_TPM_U16_BYTES + BENCH_TLS_TPM_RECORD_BYTES +
                         BENCH_TLS_TPM_U16_BYTES,
                     ER_TPM_AES_BLOCK_LEN,
                     BENCH_TLS_TPM_IV_SEED);
  *out_response_len = response_len;
  return 1u;
}

static UINT8 bench_tls_tpm_verify_response(UINT8* response,
                                           UINT32 response_capacity,
                                           UINT32* out_response_len) {
  if (response_capacity < BENCH_TLS_TPM_VERIFY_TICKET_LEN) {
    return 0u;
  }
  bench_tls_tpm_response_header(response, BENCH_TLS_TPM_VERIFY_TICKET_LEN);
  bench_tls_tpm_put_be16(response + BENCH_TLS_TPM_VERIFY_TICKET_TAG_OFFSET,
                         ER_TPM_ST_HASHCHECK);
  bench_tls_tpm_put_be32(response + BENCH_TLS_TPM_VERIFY_TICKET_HIERARCHY_OFFSET,
                         ER_TPM_RH_NULL);
  bench_tls_tpm_put_be16(response + BENCH_TLS_TPM_VERIFY_TICKET_DIGEST_LEN_OFFSET, 0u);
  *out_response_len = BENCH_TLS_TPM_VERIFY_TICKET_LEN;
  return 1u;
}

static UINT8 bench_tls_tpm_transact(void* user,
                                    const UINT8* command,
                                    UINT32 command_len,
                                    UINT8* response,
                                    UINT32 response_capacity,
                                    UINT32* out_response_len) {
  BenchTlsTpmScript* script = (BenchTlsTpmScript*)user;
  UINT32 command_code;

  if (script == 0 || command == 0 || command_len < ER_TPM_HEADER_LEN ||
      response == 0 || out_response_len == 0) {
    return 0u;
  }
  command_code = bench_tls_tpm_read_be32(command + BENCH_TLS_TPM_COMMAND_CODE_OFFSET);
  script->last_command_code = command_code;
  ++script->calls;
  switch (command_code) {
    case ER_TPM_CC_HASH:
    case ER_TPM_CC_HMAC:
    case ER_TPM_CC_SEQUENCE_COMPLETE:
      return bench_tls_tpm_digest_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_HASH_SEQUENCE_START:
      return bench_tls_tpm_handle_response(response,
                                           response_capacity,
                                           out_response_len,
                                           BENCH_TLS_TPM_HANDLE_SEQUENCE);
    case ER_TPM_CC_SEQUENCE_UPDATE:
    case ER_TPM_CC_FLUSH_CONTEXT:
      bench_tls_tpm_response_header(response, ER_TPM_HEADER_LEN);
      *out_response_len = ER_TPM_HEADER_LEN;
      return 1u;
    case ER_TPM_CC_LOAD_EXTERNAL:
      if (command_len == BENCH_TLS_TPM_LOAD_EXTERNAL_AES_COMMAND_LEN) {
        return bench_tls_tpm_handle_response(response,
                                             response_capacity,
                                             out_response_len,
                                             BENCH_TLS_TPM_HANDLE_AES);
      }
      if (command_len == BENCH_TLS_TPM_LOAD_EXTERNAL_HMAC_COMMAND_LEN) {
        return bench_tls_tpm_handle_response(response,
                                             response_capacity,
                                             out_response_len,
                                             BENCH_TLS_TPM_HANDLE_HMAC);
      }
      return bench_tls_tpm_handle_response(response,
                                           response_capacity,
                                           out_response_len,
                                           BENCH_TLS_TPM_HANDLE_VERIFY);
    case ER_TPM_CC_ENCRYPT_DECRYPT2:
      return bench_tls_tpm_crypt_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_VERIFY_SIGNATURE:
      return bench_tls_tpm_verify_response(response, response_capacity, out_response_len);
    default:
      return 0u;
  }
}

static UINT64 bench_tls_tpm_now_ns(void) {
  struct timespec now;

  if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
    return 0u;
  }
  return (UINT64)now.tv_sec * BENCH_TLS_TPM_NS_PER_SECOND + (UINT64)now.tv_nsec;
}

static void bench_tls_tpm_profiles(ErTpm2Info* info,
                                   ErTpmAlgorithmProfile* algorithms,
                                   ErTpmCommandProfile* commands) {
  er_mem_zero((UINT8*)info, (UINTN)sizeof(*info));
  er_mem_zero((UINT8*)algorithms, (UINTN)sizeof(*algorithms));
  er_mem_zero((UINT8*)commands, (UINTN)sizeof(*commands));
  info->found = 1u;
  info->control_area = 0x1000u;
  info->start_method = 6u;
  algorithms->has_sha256 = 1u;
  algorithms->has_hmac = 1u;
  algorithms->has_keyedhash = 1u;
  algorithms->has_ecc = 1u;
  algorithms->has_ecdh = 1u;
  algorithms->has_ecdsa = 1u;
  algorithms->has_aes = 1u;
  algorithms->has_symcipher = 1u;
  algorithms->has_ctr = 1u;
  commands->has_create_primary = 1u;
  commands->has_ecdh_zgen = 1u;
  commands->has_encrypt_decrypt2 = 1u;
  commands->has_get_random = 1u;
  commands->has_hash = 1u;
  commands->has_hash_sequence_start = 1u;
  commands->has_hmac = 1u;
  commands->has_load_external = 1u;
  commands->has_sequence_complete = 1u;
  commands->has_sequence_update = 1u;
  commands->has_sign = 1u;
  commands->has_verify_signature = 1u;
}

static UINT8 bench_tls_tpm_sha256_short(void* user) {
  BenchTlsTpmState* state = (BenchTlsTpmState*)user;
  UINT8 ok = er_tls_tpm_sha256(&state->tpm,
                               state->digest,
                               ER_TPM_SHA256_DIGEST_LEN,
                               state->digest);
  state->sink += state->digest[0];
  return ok;
}

static UINT8 bench_tls_tpm_sha256_long(void* user) {
  BenchTlsTpmState* state = (BenchTlsTpmState*)user;
  UINT8 ok = er_tls_tpm_sha256(&state->tpm,
                               state->long_input,
                               BENCH_TLS_TPM_LONG_BYTES,
                               state->digest);
  state->sink += state->digest[0];
  return ok;
}

static UINT8 bench_tls_tpm_hmac(void* user) {
  BenchTlsTpmState* state = (BenchTlsTpmState*)user;
  UINT8 ok = er_tls_tpm_hmac_sha256(&state->tpm,
                                    state->hmac_handle,
                                    state->digest,
                                    ER_TPM_SHA256_DIGEST_LEN,
                                    state->digest);
  state->sink += state->digest[0];
  return ok;
}

static UINT8 bench_tls_tpm_verify(void* user) {
  BenchTlsTpmState* state = (BenchTlsTpmState*)user;
  UINT8 ok = er_tls_tpm_verify_p256_sha256(&state->tpm,
                                           state->verify_handle,
                                           state->digest,
                                           state->signature);
  state->sink += state->script.last_command_code;
  return ok;
}

static UINT8 bench_tls_tpm_record_crypt(void* user) {
  BenchTlsTpmState* state = (BenchTlsTpmState*)user;
  UINT32 data_len = 0u;
  UINT32 iv_len = 0u;
  UINT8 ok = er_tls_tpm_record_crypt(&state->tpm,
                                     state->aes_handle,
                                     0u,
                                     state->iv,
                                     ER_TPM_AES_BLOCK_LEN,
                                     state->plaintext,
                                     BENCH_TLS_TPM_RECORD_BYTES,
                                     state->ciphertext,
                                     (UINT32)sizeof(state->ciphertext),
                                     &data_len,
                                     state->out_iv,
                                     (UINT32)sizeof(state->out_iv),
                                     &iv_len);
  state->sink += data_len + iv_len + state->ciphertext[0];
  return ok;
}

static UINT8 bench_tls_tpm_record_protect(void* user) {
  BenchTlsTpmState* state = (BenchTlsTpmState*)user;
  UINT16 record_len = 0u;
  UINT8 status = er_tls_record_protect(&state->tpm,
                                       &state->record_keys,
                                       BENCH_TLS_TPM_RECORD_FROM_CLIENT,
                                       state->plaintext,
                                       BENCH_TLS_TPM_RECORD_BYTES,
                                       state->record,
                                       (UINT16)sizeof(state->record),
                                       &record_len);
  state->record_keys.client_sequence = 0u;
  state->sink += record_len + state->record[0];
  return status == ER_TLS_STATUS_OK ? 1u : 0u;
}

static UINT8 bench_tls_tpm_run_case(BenchTlsTpmState* state,
                                    const char* name,
                                    BenchTlsTpmCaseFn fn,
                                    UINT32 iterations) {
  UINT32 i;
  UINT32 calls_before;
  UINT32 calls_after;
  UINT64 start_ns;
  UINT64 end_ns;
  UINT64 elapsed_ns;
  double ns_per_op;
  double ops_per_sec;

  calls_before = state->script.calls;
  start_ns = bench_tls_tpm_now_ns();
  for (i = 0u; i < iterations; ++i) {
    if (fn(state) == 0u) {
      printf("tls-tpm-bench %s failed at iteration=%u\n", name, i);
      return 0u;
    }
  }
  end_ns = bench_tls_tpm_now_ns();
  calls_after = state->script.calls;
  elapsed_ns = end_ns - start_ns;
  ns_per_op = (double)elapsed_ns / (double)iterations;
  ops_per_sec = (double)BENCH_TLS_TPM_NS_PER_SECOND / ns_per_op;
  printf("%-20s iterations=%u tpm_calls=%u ns_total=%llu ns_per_op=%.1f ops_per_sec=%.1f\n",
         name,
         iterations,
         calls_after - calls_before,
         (unsigned long long)elapsed_ns,
         ns_per_op,
         ops_per_sec);
  return 1u;
}

static UINT8 bench_tls_tpm_init(BenchTlsTpmState* state) {
  ErTpm2Info info;
  ErTpmAlgorithmProfile algorithms;
  ErTpmCommandProfile commands;

  er_mem_zero((UINT8*)state, (UINTN)sizeof(*state));
  bench_tls_tpm_profiles(&info, &algorithms, &commands);
  bench_tls_tpm_fill(state->digest, ER_TPM_SHA256_DIGEST_LEN, 0x10u);
  bench_tls_tpm_fill(state->key, ER_TPM_AES_128_KEY_LEN, 0x30u);
  bench_tls_tpm_fill(state->long_input, BENCH_TLS_TPM_LONG_BYTES, 0x50u);
  bench_tls_tpm_fill(state->iv, ER_TPM_AES_BLOCK_LEN, 0x70u);
  bench_tls_tpm_fill(state->plaintext, BENCH_TLS_TPM_RECORD_BYTES, 0x90u);
  bench_tls_tpm_fill(state->signature, (UINT32)sizeof(state->signature), 0xb0u);
  bench_tls_tpm_fill(state->public_key, (UINT32)sizeof(state->public_key), 0xd0u);
  if (er_tls_tpm_init(&state->tpm,
                      bench_tls_tpm_transact,
                      &state->script,
                      &info,
                      &algorithms,
                      &commands) == 0u ||
      er_tls_tpm_load_hmac_sha256_key(&state->tpm,
                                      state->digest,
                                      ER_TPM_SHA256_DIGEST_LEN,
                                      &state->hmac_handle) == 0u ||
      er_tls_tpm_load_aes_key(&state->tpm,
                              state->key,
                              ER_TPM_AES_128_KEY_LEN,
                              ER_TPM_AES_128_KEY_BITS,
                              &state->aes_handle) == 0u ||
      er_tls_tpm_load_p256_verify_key(&state->tpm,
                                      state->public_key,
                                      &state->verify_handle) == 0u) {
    return 0u;
  }
  state->record_keys.client_aes_handle = state->aes_handle;
  state->record_keys.client_hmac_handle = state->hmac_handle;
  er_mem_copy(state->record_keys.client_iv, state->iv, ER_TLS_RECORD_IV_BYTES);
  state->record_keys.ready = 1u;
  return 1u;
}

int main(void) {
  BenchTlsTpmState state;

  if (bench_tls_tpm_init(&state) == 0u) {
    printf("tls-tpm-bench init failed\n");
    return 1;
  }
  if (bench_tls_tpm_run_case(&state,
                             "sha256-short",
                             bench_tls_tpm_sha256_short,
                             BENCH_TLS_TPM_SHORT_ITERATIONS) == 0u ||
      bench_tls_tpm_run_case(&state,
                             "sha256-sequence",
                             bench_tls_tpm_sha256_long,
                             BENCH_TLS_TPM_MEDIUM_ITERATIONS) == 0u ||
      bench_tls_tpm_run_case(&state,
                             "hmac-sha256",
                             bench_tls_tpm_hmac,
                             BENCH_TLS_TPM_SHORT_ITERATIONS) == 0u ||
      bench_tls_tpm_run_case(&state,
                             "p256-verify",
                             bench_tls_tpm_verify,
                             BENCH_TLS_TPM_VERIFY_ITERATIONS) == 0u ||
      bench_tls_tpm_run_case(&state,
                             "aes-record-crypt",
                             bench_tls_tpm_record_crypt,
                             BENCH_TLS_TPM_MEDIUM_ITERATIONS) == 0u ||
      bench_tls_tpm_run_case(&state,
                             "tls-record-protect",
                             bench_tls_tpm_record_protect,
                             BENCH_TLS_TPM_MEDIUM_ITERATIONS) == 0u) {
    return 1;
  }
  printf("tls-tpm-bench sink=%llu total_tpm_calls=%u\n",
         (unsigned long long)state.sink,
         state.script.calls);
  return 0;
}
