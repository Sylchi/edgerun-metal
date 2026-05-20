#ifndef ER_TLS_TPM_H
#define ER_TLS_TPM_H

/*
 * Purpose: expose the TPM-backed operations that the TLS compatibility layer uses.
 * Intention: keep TLS from depending on software crypto or raw TPM command layout.
 */

#include "er_tpm.h"

#define ER_TLS_TPM_COMMAND_BYTES 256u
#define ER_TLS_TPM_RESPONSE_BYTES 512u

typedef UINT8 (*ErTlsTpmTransactFn)(void* user,
                                    const UINT8* command,
                                    UINT32 command_len,
                                    UINT8* response,
                                    UINT32 response_capacity,
                                    UINT32* out_response_len);

typedef struct {
  ErTlsTpmTransactFn transact;
  void* user;
  UINT16 record_mode;
  UINT32 last_response_len;
  UINT8 command[ER_TLS_TPM_COMMAND_BYTES];
  UINT8 response[ER_TLS_TPM_RESPONSE_BYTES];
} ErTlsTpm;

UINT8 er_tls_tpm_init(ErTlsTpm* tls_tpm,
                      ErTlsTpmTransactFn transact,
                      void* user,
                      const ErTpm2Info* info,
                      const ErTpmAlgorithmProfile* algorithms,
                      const ErTpmCommandProfile* commands);
UINT16 er_tls_tpm_record_mode(const ErTlsTpm* tls_tpm);
UINT8 er_tls_tpm_get_random(ErTlsTpm* tls_tpm,
                            UINT8* out_random,
                            UINT16 random_len);
UINT8 er_tls_tpm_sha256(ErTlsTpm* tls_tpm,
                        const UINT8* data,
                        UINT16 data_len,
                        UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]);
UINT8 er_tls_tpm_load_hmac_sha256_key(ErTlsTpm* tls_tpm,
                                      const UINT8* key,
                                      UINT16 key_len,
                                      UINT32* out_handle);
UINT8 er_tls_tpm_hmac_sha256(ErTlsTpm* tls_tpm,
                             UINT32 handle,
                             const UINT8* data,
                             UINT16 data_len,
                             UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]);
UINT8 er_tls_tpm_load_aes_key(ErTlsTpm* tls_tpm,
                              const UINT8* key,
                              UINT16 key_len,
                              UINT16 key_bits,
                              UINT32* out_handle);
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
                              UINT32* out_iv_len);
UINT8 er_tls_tpm_create_p256_ecdh_key(ErTlsTpm* tls_tpm,
                                      ErTpmP256Primary* out_primary);
UINT8 er_tls_tpm_ecdh_zgen(ErTlsTpm* tls_tpm,
                           UINT32 handle,
                           const UINT8 peer_public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
                           UINT8 out_shared_point[ER_TPM_P256_PUBLIC_KEY_LEN]);
UINT8 er_tls_tpm_load_p256_verify_key(ErTlsTpm* tls_tpm,
                                      const UINT8 public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
                                      UINT32* out_handle);
UINT8 er_tls_tpm_verify_p256_sha256(ErTlsTpm* tls_tpm,
                                    UINT32 handle,
                                    const UINT8 digest[ER_TPM_SHA256_DIGEST_LEN],
                                    const UINT8 signature[64]);
UINT8 er_tls_tpm_sign_p256_sha256(ErTlsTpm* tls_tpm,
                                  UINT32 handle,
                                  const UINT8 digest[ER_TPM_SHA256_DIGEST_LEN],
                                  UINT8 out_signature[64]);
UINT8 er_tls_tpm_flush(ErTlsTpm* tls_tpm, UINT32 handle);

#endif
