#ifndef ER_TLS_H
#define ER_TLS_H

/*
 * Purpose: provide the minimal TLS compatibility handshake core.
 * Intention: keep cryptographic operations behind TPM-backed er_tls_tpm calls.
 */

#include "er_tls_tpm.h"

#define ER_TLS_RANDOM_BYTES 32u
#define ER_TLS_P256_RAW_PUBLIC_BYTES ER_TPM_P256_PUBLIC_KEY_LEN
#define ER_TLS_P256_SEC1_PUBLIC_BYTES (ER_TLS_P256_RAW_PUBLIC_BYTES + 1u)
#define ER_TLS_CLIENT_HELLO_MAX_BYTES 256u
#define ER_TLS_HANDSHAKE_MAX_BYTES 512u
#define ER_TLS_SHA256_BYTES ER_TPM_SHA256_DIGEST_LEN
#define ER_TLS_AES_128_KEY_BYTES ER_TPM_AES_128_KEY_LEN
#define ER_TLS_RECORD_IV_BYTES ER_TPM_AES_BLOCK_LEN
#define ER_TLS_RECORD_TAG_BYTES ER_TPM_SHA256_DIGEST_LEN
#define ER_TLS_FINISHED_VERIFY_BYTES ER_TPM_SHA256_DIGEST_LEN
#define ER_TLS_RECORD_PLAINTEXT_MAX_BYTES 1024u
#define ER_TLS_RECORD_WIRE_MAX_BYTES \
  (5u + ER_TLS_RECORD_PLAINTEXT_MAX_BYTES + ER_TLS_RECORD_TAG_BYTES)

typedef enum {
  ER_TLS_STATUS_OK = 0,
  ER_TLS_STATUS_INVALID_ARGUMENT = 1,
  ER_TLS_STATUS_BUFFER_TOO_SMALL = 2,
  ER_TLS_STATUS_TPM_FAILURE = 3,
  ER_TLS_STATUS_PARSE_FAILURE = 4,
  ER_TLS_STATUS_UNSUPPORTED = 5
} ErTlsStatus;

typedef struct {
  UINT8 client_random[ER_TLS_RANDOM_BYTES];
  UINT8 server_random[ER_TLS_RANDOM_BYTES];
  UINT8 client_public_key[ER_TLS_P256_RAW_PUBLIC_BYTES];
  UINT8 server_public_key[ER_TLS_P256_RAW_PUBLIC_BYTES];
  UINT8 shared_point[ER_TLS_P256_RAW_PUBLIC_BYTES];
  UINT32 ecdh_handle;
  UINT16 cipher_suite;
  UINT16 supported_version;
  UINT8 server_authenticated;
  UINT8 server_finished_verified;
  UINT8 client_finished_built;
  UINT8 ready;
} ErTlsHandshake;

typedef struct {
  UINT32 client_aes_handle;
  UINT32 server_aes_handle;
  UINT32 client_hmac_handle;
  UINT32 server_hmac_handle;
  UINT8 client_iv[ER_TLS_RECORD_IV_BYTES];
  UINT8 server_iv[ER_TLS_RECORD_IV_BYTES];
  UINT64 client_sequence;
  UINT64 server_sequence;
  UINT8 ready;
} ErTlsRecordKeys;

typedef struct {
  UINT16 legacy_version;
  UINT8 random[ER_TLS_RANDOM_BYTES];
  UINT16 cipher_suite;
  UINT16 supported_version;
  UINT8 has_supported_version;
  UINT8 server_public_key[ER_TLS_P256_RAW_PUBLIC_BYTES];
  UINT8 has_server_public_key;
} ErTlsServerHello;

UINT8 er_tls_client_hello_build(ErTlsTpm* tpm,
                                ErTlsHandshake* handshake,
                                const UINT8* host,
                                UINT16 host_len,
                                UINT8* out_bytes,
                                UINT16 out_capacity,
                                UINT16* out_len);
UINT8 er_tls_server_hello_parse(const UINT8* bytes,
                                UINT16 len,
                                ErTlsServerHello* out_hello);
UINT8 er_tls_handshake_accept_server_hello(ErTlsTpm* tpm,
                                           ErTlsHandshake* handshake,
                                           const UINT8* bytes,
                                           UINT16 len);
UINT8 er_tls_certificate_verify_accept(ErTlsTpm* tpm,
                                       ErTlsHandshake* handshake,
                                       const UINT8 server_verify_key[ER_TLS_P256_RAW_PUBLIC_BYTES],
                                       const UINT8* transcript,
                                       UINT16 transcript_len,
                                       const UINT8* message,
                                       UINT16 message_len);
UINT8 er_tls_handshake_close(ErTlsTpm* tpm, ErTlsHandshake* handshake);
UINT8 er_tls_record_keys_derive(ErTlsTpm* tpm,
                                const ErTlsHandshake* handshake,
                                const UINT8* transcript,
                                UINT16 transcript_len,
                                ErTlsRecordKeys* out_keys);
UINT8 er_tls_server_finished_accept(ErTlsTpm* tpm,
                                    ErTlsHandshake* handshake,
                                    const ErTlsRecordKeys* keys,
                                    const UINT8* transcript,
                                    UINT16 transcript_len,
                                    const UINT8* message,
                                    UINT16 message_len);
UINT8 er_tls_client_finished_build(ErTlsTpm* tpm,
                                   ErTlsHandshake* handshake,
                                   const ErTlsRecordKeys* keys,
                                   const UINT8* transcript,
                                   UINT16 transcript_len,
                                   UINT8* out_message,
                                   UINT16 out_capacity,
                                   UINT16* out_message_len);
UINT8 er_tls_record_protect(ErTlsTpm* tpm,
                            ErTlsRecordKeys* keys,
                            UINT8 from_client,
                            const UINT8* plaintext,
                            UINT16 plaintext_len,
                            UINT8* out_record,
                            UINT16 out_capacity,
                            UINT16* out_record_len);
UINT8 er_tls_record_unprotect(ErTlsTpm* tpm,
                              ErTlsRecordKeys* keys,
                              UINT8 from_client,
                              const UINT8* record,
                              UINT16 record_len,
                              UINT8* out_plaintext,
                              UINT16 out_capacity,
                              UINT16* out_plaintext_len);
UINT8 er_tls_record_keys_close(ErTlsTpm* tpm, ErTlsRecordKeys* keys);

#endif
