#include "er_tls_tpm.h"

#include "er_mem.h"

#define ER_TLS_TPM_SHA256_ONESHOT_MAX_BYTES 238u
#define ER_TLS_TPM_SHA256_UPDATE_MAX_BYTES 227u
#define ER_TLS_TPM_EXTERNAL_KEY_MATERIAL_MAX_BYTES \
  (ER_TPM_SHA256_DIGEST_LEN + ER_TPM_AES_256_KEY_LEN)

enum {
  ER_TLS_TPM_EXTERNAL_KEY_HMAC_SHA256 = 1u,
  ER_TLS_TPM_EXTERNAL_KEY_AES = 2u
};

enum {
  ER_TLS_TPM_SHA256_COMMAND_ONESHOT = 1u,
  ER_TLS_TPM_SHA256_COMMAND_SEQUENCE_COMPLETE = 2u
};

static UINT8 er_tls_tpm_run(ErTlsTpm* tls_tpm, UINT32 command_len, UINT32* out_response_len) {
  UINT8 ok;

  if (tls_tpm == 0 || tls_tpm->transact == 0 || command_len == 0u || out_response_len == 0) {
    return 0u;
  }
  ok = tls_tpm->transact(tls_tpm->user,
                         tls_tpm->command,
                         command_len,
                         tls_tpm->response,
                         (UINT32)sizeof(tls_tpm->response),
                         out_response_len);
  if (ok == 0u) {
    tls_tpm->last_response_len = 0u;
    return 0u;
  }
  tls_tpm->last_response_len = *out_response_len;
  return 1u;
}

static void er_tls_tpm_scrub_command(ErTlsTpm* tls_tpm) {
  if (tls_tpm != 0) {
    er_mem_scrub(tls_tpm->command, (UINTN)sizeof(tls_tpm->command));
  }
}

static UINT8 er_tls_tpm_run_or_scrub(ErTlsTpm* tls_tpm,
                                     UINT32 command_len,
                                     UINT32* out_response_len) {
  if (er_tls_tpm_run(tls_tpm, command_len, out_response_len) == 0u) {
    er_tls_tpm_scrub_command(tls_tpm);
    return 0u;
  }
  return 1u;
}

static UINT8 er_tls_tpm_parse_digest_and_scrub(
    ErTlsTpm* tls_tpm,
    UINT32 response_len,
    UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]) {
  UINT8 ok;

  if (tls_tpm == 0 || out_digest == 0) {
    return 0u;
  }
  ok = er_tpm_parse_sha256_digest_response(tls_tpm->response, response_len, out_digest);
  er_tls_tpm_scrub_command(tls_tpm);
  return ok;
}

static UINT8 er_tls_tpm_run_digest_command(ErTlsTpm* tls_tpm,
                                           UINT32 command_len,
                                           UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]) {
  UINT32 response_len;

  if (er_tls_tpm_run_or_scrub(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tls_tpm_parse_digest_and_scrub(tls_tpm, response_len, out_digest);
}

static UINT8 er_tls_tpm_build_sha256_finish_command(
    ErTlsTpm* tls_tpm,
    UINT8 command_kind,
    UINT32 sequence_handle,
    const UINT8* data,
    UINT16 data_len,
    UINT32* out_command_len) {
  if (tls_tpm == 0 || data == 0 || out_command_len == 0) {
    return 0u;
  }
  switch (command_kind) {
    case ER_TLS_TPM_SHA256_COMMAND_ONESHOT:
      return er_tpm_build_hash_sha256_command(data,
                                              data_len,
                                              ER_TPM_RH_NULL,
                                              tls_tpm->command,
                                              (UINT32)sizeof(tls_tpm->command),
                                              out_command_len);
    case ER_TLS_TPM_SHA256_COMMAND_SEQUENCE_COMPLETE:
      return er_tpm_build_sequence_complete_command(sequence_handle,
                                                    data,
                                                    data_len,
                                                    ER_TPM_RH_NULL,
                                                    tls_tpm->command,
                                                    (UINT32)sizeof(tls_tpm->command),
                                                    out_command_len);
    default:
      return 0u;
  }
}

static UINT8 er_tls_tpm_external_key_unique(ErTlsTpm* tls_tpm,
                                            const UINT8* key,
                                            UINT16 key_len,
                                            UINT8 seed[ER_TPM_SHA256_DIGEST_LEN],
                                            UINT8 unique[ER_TPM_SHA256_DIGEST_LEN]) {
  UINT8 material[ER_TLS_TPM_EXTERNAL_KEY_MATERIAL_MAX_BYTES];
  UINT8 ok;

  if (tls_tpm == 0 || key == 0 || seed == 0 || unique == 0 ||
      key_len == 0u ||
      (UINT32)key_len > ER_TLS_TPM_EXTERNAL_KEY_MATERIAL_MAX_BYTES -
                            ER_TPM_SHA256_DIGEST_LEN ||
      er_tls_tpm_get_random(tls_tpm, seed, ER_TPM_SHA256_DIGEST_LEN) == 0u) {
    return 0u;
  }
  er_mem_copy(material, seed, ER_TPM_SHA256_DIGEST_LEN);
  er_mem_copy(material + ER_TPM_SHA256_DIGEST_LEN, key, key_len);
  ok = er_tls_tpm_sha256(tls_tpm,
                         material,
                         (UINT16)(ER_TPM_SHA256_DIGEST_LEN + key_len),
                         unique);
  er_mem_scrub(material, (UINTN)sizeof(material));
  return ok;
}

static UINT8 er_tls_tpm_parse_external_key_handle_and_scrub(
    ErTlsTpm* tls_tpm,
    UINT32 response_len,
    UINT8 seed[ER_TPM_SHA256_DIGEST_LEN],
    UINT8 unique[ER_TPM_SHA256_DIGEST_LEN],
    UINT32* out_handle) {
  UINT8 ok;

  if (tls_tpm == 0 || seed == 0 || unique == 0 || out_handle == 0) {
    return 0u;
  }
  ok = er_tpm_parse_handle_response(tls_tpm->response, response_len, out_handle);
  er_mem_scrub(seed, ER_TPM_SHA256_DIGEST_LEN);
  er_mem_scrub(unique, ER_TPM_SHA256_DIGEST_LEN);
  er_tls_tpm_scrub_command(tls_tpm);
  return ok;
}

static UINT8 er_tls_tpm_build_load_external_key_command(
    ErTlsTpm* tls_tpm,
    UINT8 key_kind,
    const UINT8* key,
    UINT16 key_len,
    UINT16 key_bits,
    const UINT8 seed[ER_TPM_SHA256_DIGEST_LEN],
    const UINT8 unique[ER_TPM_SHA256_DIGEST_LEN],
    UINT32* out_command_len) {
  if (tls_tpm == 0 || key == 0 || seed == 0 || unique == 0 || out_command_len == 0) {
    return 0u;
  }
  switch (key_kind) {
    case ER_TLS_TPM_EXTERNAL_KEY_HMAC_SHA256:
      return er_tpm_build_load_external_hmac_sha256_key_command(
          key,
          key_len,
          seed,
          unique,
          tls_tpm->command,
          (UINT32)sizeof(tls_tpm->command),
          out_command_len);
    case ER_TLS_TPM_EXTERNAL_KEY_AES:
      return er_tpm_build_load_external_aes_key_command(key,
                                                        key_len,
                                                        key_bits,
                                                        tls_tpm->record_mode,
                                                        seed,
                                                        unique,
                                                        tls_tpm->command,
                                                        (UINT32)sizeof(tls_tpm->command),
                                                        out_command_len);
    default:
      return 0u;
  }
}

static UINT8 er_tls_tpm_load_external_key(ErTlsTpm* tls_tpm,
                                          UINT8 key_kind,
                                          const UINT8* key,
                                          UINT16 key_len,
                                          UINT16 key_bits,
                                          UINT32* out_handle) {
  UINT32 command_len;
  UINT32 response_len;
  UINT8 seed[ER_TPM_SHA256_DIGEST_LEN];
  UINT8 unique[ER_TPM_SHA256_DIGEST_LEN];
  UINT8 ok;

  if (tls_tpm == 0 || key == 0 || out_handle == 0) {
    return 0u;
  }
  ok = (UINT8)(er_tls_tpm_external_key_unique(tls_tpm, key, key_len, seed, unique) != 0u &&
               er_tls_tpm_build_load_external_key_command(tls_tpm,
                                                          key_kind,
                                                          key,
                                                          key_len,
                                                          key_bits,
                                                          seed,
                                                          unique,
                                                          &command_len) != 0u &&
               er_tls_tpm_run_or_scrub(tls_tpm, command_len, &response_len) != 0u);
  if (ok == 0u) {
    er_mem_scrub(seed, (UINTN)sizeof(seed));
    er_mem_scrub(unique, (UINTN)sizeof(unique));
    er_tls_tpm_scrub_command(tls_tpm);
    return 0u;
  }
  return er_tls_tpm_parse_external_key_handle_and_scrub(tls_tpm, response_len,
                                                       seed, unique, out_handle);
}

UINT8 er_tls_tpm_init(ErTlsTpm* tls_tpm,
                      ErTlsTpmTransactFn transact,
                      void* user,
                      const ErTpm2Info* info,
                      const ErTpmAlgorithmProfile* algorithms,
                      const ErTpmCommandProfile* commands) {
  UINT16 mode;

  if (tls_tpm == 0 || transact == 0 ||
      er_tpm_tls_compat_profile_supported(info, algorithms, commands) == 0u ||
      er_tpm_select_record_cipher_mode(algorithms, &mode) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)tls_tpm, (UINTN)sizeof(*tls_tpm));
  tls_tpm->transact = transact;
  tls_tpm->user = user;
  tls_tpm->record_mode = mode;
  return 1u;
}

UINT16 er_tls_tpm_record_mode(const ErTlsTpm* tls_tpm) {
  if (tls_tpm == 0) {
    return ER_TPM_ALG_NULL;
  }
  return tls_tpm->record_mode;
}

UINT8 er_tls_tpm_get_random(ErTlsTpm* tls_tpm,
                            UINT8* out_random,
                            UINT16 random_len) {
  UINT32 command_len;
  UINT32 response_len;
  UINT32 parsed_len;

  if (tls_tpm == 0 || out_random == 0 || random_len == 0u ||
      er_tpm_build_get_random_command(random_len,
                                      tls_tpm->command,
                                      (UINT32)sizeof(tls_tpm->command),
                                      &command_len) == 0u ||
      er_tls_tpm_run_or_scrub(tls_tpm, command_len, &response_len) == 0u ||
      er_tpm_parse_get_random_response(tls_tpm->response,
                                       response_len,
                                       out_random,
                                       (UINT32)random_len,
                                       &parsed_len) == 0u ||
      parsed_len != random_len) {
    return 0u;
  }
  return 1u;
}

UINT8 er_tls_tpm_sha256(ErTlsTpm* tls_tpm,
                        const UINT8* data,
                        UINT16 data_len,
                        UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]) {
  UINT32 command_len;
  UINT32 response_len;
  UINT32 cursor;
  UINT32 chunk_len;
  UINT32 sequence_handle;

  if (tls_tpm == 0 || data == 0 || out_digest == 0 ||
      data_len == 0u) {
    return 0u;
  }
  if (data_len <= ER_TLS_TPM_SHA256_ONESHOT_MAX_BYTES) {
    if (er_tls_tpm_build_sha256_finish_command(tls_tpm,
                                               ER_TLS_TPM_SHA256_COMMAND_ONESHOT,
                                               0u,
                                               data,
                                               data_len,
                                               &command_len) == 0u) {
      return 0u;
    }
    return er_tls_tpm_run_digest_command(tls_tpm, command_len, out_digest);
  }
  if (er_tpm_build_hash_sequence_start_sha256_command(tls_tpm->command,
                                                      (UINT32)sizeof(tls_tpm->command),
                                                      &command_len) == 0u ||
      er_tls_tpm_run_or_scrub(tls_tpm, command_len, &response_len) == 0u ||
      er_tpm_parse_handle_response(tls_tpm->response, response_len, &sequence_handle) == 0u) {
    er_tls_tpm_scrub_command(tls_tpm);
    return 0u;
  }
  cursor = 0u;
  while ((UINT32)data_len - cursor > ER_TLS_TPM_SHA256_UPDATE_MAX_BYTES) {
    chunk_len = ER_TLS_TPM_SHA256_UPDATE_MAX_BYTES;
    if (er_tpm_build_sequence_update_command(sequence_handle,
                                             data + cursor,
                                             (UINT16)chunk_len,
                                             tls_tpm->command,
                                             (UINT32)sizeof(tls_tpm->command),
                                             &command_len) == 0u ||
        er_tls_tpm_run_or_scrub(tls_tpm, command_len, &response_len) == 0u ||
        er_tpm_response_success(tls_tpm->response, response_len) == 0u) {
      er_tls_tpm_scrub_command(tls_tpm);
      return 0u;
    }
    er_tls_tpm_scrub_command(tls_tpm);
    cursor += chunk_len;
  }
  chunk_len = (UINT32)data_len - cursor;
  if (er_tls_tpm_build_sha256_finish_command(
          tls_tpm,
          ER_TLS_TPM_SHA256_COMMAND_SEQUENCE_COMPLETE,
          sequence_handle,
          data + cursor,
          (UINT16)chunk_len,
          &command_len) == 0u) {
    return 0u;
  }
  return er_tls_tpm_run_digest_command(tls_tpm, command_len, out_digest);
}

UINT8 er_tls_tpm_load_hmac_sha256_key(ErTlsTpm* tls_tpm,
                                      const UINT8* key,
                                      UINT16 key_len,
                                      UINT32* out_handle) {
  return er_tls_tpm_load_external_key(tls_tpm,
                                      ER_TLS_TPM_EXTERNAL_KEY_HMAC_SHA256,
                                      key,
                                      key_len,
                                      0u,
                                      out_handle);
}

UINT8 er_tls_tpm_hmac_sha256(ErTlsTpm* tls_tpm,
                             UINT32 handle,
                             const UINT8* data,
                             UINT16 data_len,
                             UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]) {
  UINT32 command_len;

  if (tls_tpm == 0 || data == 0 || out_digest == 0 ||
      er_tpm_build_hmac_sha256_command(handle,
                                       data,
                                       data_len,
                                       tls_tpm->command,
                                       (UINT32)sizeof(tls_tpm->command),
                                       &command_len) == 0u) {
    return 0u;
  }
  return er_tls_tpm_run_digest_command(tls_tpm, command_len, out_digest);
}

UINT8 er_tls_tpm_load_aes_key(ErTlsTpm* tls_tpm,
                              const UINT8* key,
                              UINT16 key_len,
                              UINT16 key_bits,
                              UINT32* out_handle) {
  return er_tls_tpm_load_external_key(tls_tpm,
                                      ER_TLS_TPM_EXTERNAL_KEY_AES,
                                      key,
                                      key_len,
                                      key_bits,
                                      out_handle);
}

UINT8 er_tls_tpm_record_crypt(ErTlsTpm* tls_tpm,
                              UINT32 handle,
                              UINT8 decrypt,
                              const UINT8* iv,
                              UINT16 iv_len,
                              const UINT8* input,
                              UINT16 input_len,
                              UINT8* out_data,
                              UINT32 out_data_capacity,
                              UINT32* out_data_len,
                              UINT8* out_iv,
                              UINT32 out_iv_capacity,
                              UINT32* out_iv_len) {
  UINT32 command_len;
  UINT32 response_len;
  UINT8 ok;

  if (tls_tpm == 0 || iv == 0 || input == 0 || out_data == 0 || out_data_len == 0 ||
      out_iv == 0 || out_iv_len == 0 ||
      er_tpm_build_encrypt_decrypt2_command(handle,
                                            decrypt,
                                            tls_tpm->record_mode,
                                            iv,
                                            iv_len,
                                            input,
                                            input_len,
                                            tls_tpm->command,
                                            (UINT32)sizeof(tls_tpm->command),
                                            &command_len) == 0u ||
      er_tls_tpm_run_or_scrub(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  ok = er_tpm_parse_encrypt_decrypt2_response(tls_tpm->response,
                                              response_len,
                                              out_data,
                                              out_data_capacity,
                                              out_data_len,
                                              out_iv,
                                              out_iv_capacity,
                                              out_iv_len);
  er_tls_tpm_scrub_command(tls_tpm);
  return ok;
}

UINT8 er_tls_tpm_create_p256_ecdh_key(ErTlsTpm* tls_tpm,
                                      ErTpmP256Primary* out_primary) {
  UINT32 command_len;
  UINT32 response_len;

  if (tls_tpm == 0 || out_primary == 0 ||
      er_tpm_build_create_primary_p256_ecdh_command(tls_tpm->command,
                                                    (UINT32)sizeof(tls_tpm->command),
                                                    &command_len) == 0u ||
      er_tls_tpm_run(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tpm_parse_create_primary_p256_response(tls_tpm->response, response_len, out_primary);
}

UINT8 er_tls_tpm_ecdh_zgen(ErTlsTpm* tls_tpm,
                           UINT32 handle,
                           const UINT8 peer_public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
                           UINT8 out_shared_point[ER_TPM_P256_PUBLIC_KEY_LEN]) {
  UINT32 command_len;
  UINT32 response_len;

  if (tls_tpm == 0 || peer_public_key == 0 || out_shared_point == 0 ||
      er_tpm_build_ecdh_zgen_p256_command(handle,
                                          peer_public_key,
                                          tls_tpm->command,
                                          (UINT32)sizeof(tls_tpm->command),
                                          &command_len) == 0u ||
      er_tls_tpm_run(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tpm_parse_p256_point_response(tls_tpm->response, response_len, out_shared_point);
}

UINT8 er_tls_tpm_load_p256_verify_key(ErTlsTpm* tls_tpm,
                                      const UINT8 public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
                                      UINT32* out_handle) {
  UINT32 command_len;
  UINT32 response_len;

  if (tls_tpm == 0 || public_key == 0 || out_handle == 0 ||
      er_tpm_build_load_external_p256_verify_key_command(public_key,
                                                         tls_tpm->command,
                                                         (UINT32)sizeof(tls_tpm->command),
                                                         &command_len) == 0u ||
      er_tls_tpm_run(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tpm_parse_handle_response(tls_tpm->response, response_len, out_handle);
}

UINT8 er_tls_tpm_verify_p256_sha256(ErTlsTpm* tls_tpm,
                                    UINT32 handle,
                                    const UINT8 digest[ER_TPM_SHA256_DIGEST_LEN],
                                    const UINT8 signature[64]) {
  UINT32 command_len;
  UINT32 response_len;

  if (tls_tpm == 0 || digest == 0 || signature == 0 ||
      er_tpm_build_verify_p256_sha256_command(handle,
                                              digest,
                                              signature,
                                              tls_tpm->command,
                                              (UINT32)sizeof(tls_tpm->command),
                                              &command_len) == 0u ||
      er_tls_tpm_run(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tpm_parse_verify_ticket_response(tls_tpm->response, response_len);
}

UINT8 er_tls_tpm_sign_p256_sha256(ErTlsTpm* tls_tpm,
                                  UINT32 handle,
                                  const UINT8 digest[ER_TPM_SHA256_DIGEST_LEN],
                                  UINT8 out_signature[64]) {
  UINT32 command_len;
  UINT32 response_len;

  if (tls_tpm == 0 || digest == 0 || out_signature == 0 ||
      er_tpm_build_sign_p256_sha256_command(handle,
                                            digest,
                                            tls_tpm->command,
                                            (UINT32)sizeof(tls_tpm->command),
                                            &command_len) == 0u ||
      er_tls_tpm_run(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tpm_parse_p256_sha256_signature_response(tls_tpm->response,
                                                     response_len,
                                                     out_signature);
}

UINT8 er_tls_tpm_flush(ErTlsTpm* tls_tpm, UINT32 handle) {
  UINT32 command_len;
  UINT32 response_len;

  if (tls_tpm == 0 ||
      er_tpm_build_flush_context_command(handle,
                                         tls_tpm->command,
                                         (UINT32)sizeof(tls_tpm->command),
                                         &command_len) == 0u ||
      er_tls_tpm_run(tls_tpm, command_len, &response_len) == 0u) {
    return 0u;
  }
  return er_tpm_response_success(tls_tpm->response, response_len);
}
