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
  UINT8 ready;
} ErTlsHandshake;

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
UINT8 er_tls_handshake_close(ErTlsTpm* tpm, ErTlsHandshake* handshake);

#endif
