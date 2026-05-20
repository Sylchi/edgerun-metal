#ifndef ER_TPM_H
#define ER_TPM_H

/*
 * Purpose: speak TPM2 directly from the metal runtime.
 * Intention: make hardware identity available without Linux, TSS, or host services.
 */

#include "er_acpi.h"

#define ER_TPM_HEADER_LEN 10u
#define ER_TPM_CRB_MAX_BUFFER_SIZE 65536u
#define ER_TPM_DEFAULT_TIMEOUT_POLLS 1000000u

#define ER_TPM_ST_NO_SESSIONS 0x8001u
#define ER_TPM_ST_SESSIONS 0x8002u
#define ER_TPM_ST_HASHCHECK 0x8024u

#define ER_TPM_RC_SUCCESS 0x00000000u
#define ER_TPM_RC_INITIALIZE 0x00000100u
#define ER_TPM_RC_FAILURE 0x00000101u
#define ER_TPM_RC_TESTING 0x0000000Au
#define ER_TPM_RC_METAL_TIMEOUT 0xfffffffeu
#define ER_TPM_RC_METAL_PROTOCOL 0xfffffffcu
#define ER_TPM_RC_METAL_UNSUPPORTED 0xfffffffau

#define ER_TPM_CC_STARTUP 0x00000144u
#define ER_TPM_CC_CREATE_PRIMARY 0x00000131u
#define ER_TPM_CC_ECDH_ZGEN 0x00000154u
#define ER_TPM_CC_HMAC 0x00000155u
#define ER_TPM_CC_LOAD_EXTERNAL 0x00000167u
#define ER_TPM_CC_ENCRYPT_DECRYPT2 0x00000193u
#define ER_TPM_CC_GET_CAPABILITY 0x0000017Au
#define ER_TPM_CC_GET_RANDOM 0x0000017Bu
#define ER_TPM_CC_HASH 0x0000017Du
#define ER_TPM_CC_HASH_SEQUENCE_START 0x00000186u
#define ER_TPM_CC_READ_PUBLIC 0x00000173u
#define ER_TPM_CC_SEQUENCE_COMPLETE 0x0000013Eu
#define ER_TPM_CC_SEQUENCE_UPDATE 0x0000015Cu
#define ER_TPM_CC_SIGN 0x0000015Du
#define ER_TPM_CC_VERIFY_SIGNATURE 0x00000177u
#define ER_TPM_CC_FLUSH_CONTEXT 0x00000165u

#define ER_TPM_SU_CLEAR 0x0000u
#define ER_TPM_RS_PW 0x40000009u
#define ER_TPM_RH_OWNER 0x40000001u
#define ER_TPM_RH_ENDORSEMENT 0x4000000Bu
#define ER_TPM_RH_PLATFORM 0x4000000Cu
#define ER_TPM_RH_NULL 0x40000007u

#define ER_TPM_ALG_NULL 0x0010u
#define ER_TPM_ALG_AES 0x0006u
#define ER_TPM_ALG_HMAC 0x0005u
#define ER_TPM_ALG_KEYEDHASH 0x0008u
#define ER_TPM_ALG_SHA256 0x000Bu
#define ER_TPM_ALG_ECDSA 0x0018u
#define ER_TPM_ALG_ECC 0x0023u
#define ER_TPM_ALG_ECDH 0x0019u
#define ER_TPM_ALG_SYMCIPHER 0x0025u
#define ER_TPM_ALG_CTR 0x0040u
#define ER_TPM_ALG_OFB 0x0041u
#define ER_TPM_ALG_CBC 0x0042u
#define ER_TPM_ALG_CFB 0x0043u
#define ER_TPM_ALG_ECB 0x0044u
#define ER_TPM_ECC_NIST_P256 0x0003u

#define ER_TPM_CAP_ALGS 0x00000000u
#define ER_TPM_CAP_COMMANDS 0x00000002u
#define ER_TPM_CAP_TPM_PROPERTIES 0x00000006u
#define ER_TPM_PT_FIXED 0x00000100u
#define ER_TPM_PT_NV_INDEX_MAX 0x00000117u
#define ER_TPM_PT_NV_BUFFER_MAX 0x0000012Cu

#define ER_TPM_P256_PUBLIC_KEY_LEN 64u
#define ER_TPM_SHA256_DIGEST_LEN 32u
#define ER_TPM_AES_BLOCK_LEN 16u
#define ER_TPM_AES_128_KEY_LEN 16u
#define ER_TPM_AES_256_KEY_LEN 32u
#define ER_TPM_AES_128_KEY_BITS 128u
#define ER_TPM_AES_256_KEY_BITS 256u

typedef struct {
  UINT8 found;
  UINT8 checksum_valid;
  UINT16 platform_class;
  UINT64 control_area;
  UINT32 start_method;
} ErTpm2Info;

typedef struct {
  UINT64 control_area;
  UINT64 command_buffer;
  UINT64 command_buffer_size;
  UINT64 response_buffer;
  UINT64 response_buffer_size;
  UINT32 timeout_polls;
} ErTpmCrbTransport;

typedef struct {
  UINT32 handle;
  UINT8 public_key[ER_TPM_P256_PUBLIC_KEY_LEN];
} ErTpmP256Primary;

typedef struct {
  UINT8 has_nv_index_max;
  UINT8 has_nv_buffer_max;
  UINT16 reserved;
  UINT32 nv_index_max;
  UINT32 nv_buffer_max;
} ErTpmNvLimits;

typedef struct {
  UINT8 has_sha256;
  UINT8 has_hmac;
  UINT8 has_keyedhash;
  UINT8 has_ecc;
  UINT8 has_ecdh;
  UINT8 has_ecdsa;
  UINT8 has_aes;
  UINT8 has_symcipher;
  UINT8 has_ctr;
  UINT8 has_ofb;
  UINT8 has_cbc;
  UINT8 has_cfb;
  UINT8 has_ecb;
} ErTpmAlgorithmProfile;

typedef struct {
  UINT8 has_create_primary;
  UINT8 has_ecdh_zgen;
  UINT8 has_encrypt_decrypt2;
  UINT8 has_get_random;
  UINT8 has_hash;
  UINT8 has_hash_sequence_start;
  UINT8 has_hmac;
  UINT8 has_load_external;
  UINT8 has_sequence_complete;
  UINT8 has_sequence_update;
  UINT8 has_sign;
  UINT8 has_verify_signature;
} ErTpmCommandProfile;

UINT8 er_tpm_parse_tpm2_table(UINT64 tpm2_address, ErTpm2Info* out_info);
UINT8 er_tpm_find_tpm2_table(const ErAcpiTableList* tables, ErTpm2Info* out_info);
UINT8 er_tpm2_info_is_crb(const ErTpm2Info* info);

UINT8 er_tpm_crb_from_register_base(UINT64 register_base, ErTpmCrbTransport* out_transport);
UINT8 er_tpm_crb_from_tpm2_info(const ErTpm2Info* info, ErTpmCrbTransport* out_transport);
UINT8 er_tpm_crb_transact(ErTpmCrbTransport* transport,
                          const UINT8* command, UINT32 command_len,
                          UINT8* response, UINT32 response_capacity,
                          UINT32* out_response_len);

UINT8 er_tpm_build_startup_command(UINT16 startup_type,
                                   UINT8* out_command, UINT32 command_capacity,
                                   UINT32* out_command_len);
UINT8 er_tpm_build_create_primary_p256_signing_command(UINT8* out_command,
                                                       UINT32 command_capacity,
                                                       UINT32* out_command_len);
UINT8 er_tpm_build_create_primary_p256_ecdh_command(UINT8* out_command,
                                                    UINT32 command_capacity,
                                                    UINT32* out_command_len);
UINT8 er_tpm_build_get_random_command(UINT16 bytes_requested,
                                      UINT8* out_command, UINT32 command_capacity,
                                      UINT32* out_command_len);
UINT8 er_tpm_build_hash_sha256_command(const UINT8* data, UINT16 data_len,
                                       UINT32 hierarchy,
                                       UINT8* out_command,
                                       UINT32 command_capacity,
                                       UINT32* out_command_len);
UINT8 er_tpm_build_hash_sequence_start_sha256_command(UINT8* out_command,
                                                      UINT32 command_capacity,
                                                      UINT32* out_command_len);
UINT8 er_tpm_build_sequence_update_command(UINT32 handle,
                                           const UINT8* data, UINT16 data_len,
                                           UINT8* out_command,
                                           UINT32 command_capacity,
                                           UINT32* out_command_len);
UINT8 er_tpm_build_sequence_complete_command(UINT32 handle,
                                             const UINT8* data, UINT16 data_len,
                                             UINT32 hierarchy,
                                             UINT8* out_command,
                                             UINT32 command_capacity,
                                             UINT32* out_command_len);
UINT8 er_tpm_build_hmac_sha256_command(UINT32 handle,
                                       const UINT8* data, UINT16 data_len,
                                       UINT8* out_command,
                                       UINT32 command_capacity,
                                       UINT32* out_command_len);
UINT8 er_tpm_build_get_capability_command(UINT32 capability, UINT32 property,
                                          UINT32 property_count,
                                          UINT8* out_command,
                                          UINT32 command_capacity,
                                          UINT32* out_command_len);
UINT8 er_tpm_build_read_public_command(UINT32 handle,
                                       UINT8* out_command, UINT32 command_capacity,
                                       UINT32* out_command_len);
UINT8 er_tpm_build_load_external_p256_verify_key_command(
    const UINT8 public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
    UINT8* out_command,
    UINT32 command_capacity,
    UINT32* out_command_len);
UINT8 er_tpm_build_load_external_hmac_sha256_key_command(
    const UINT8* key, UINT16 key_len,
    UINT8* out_command,
    UINT32 command_capacity,
    UINT32* out_command_len);
UINT8 er_tpm_build_load_external_aes_key_command(
    const UINT8* key, UINT16 key_len,
    UINT16 key_bits,
    UINT16 mode,
    UINT8* out_command,
    UINT32 command_capacity,
    UINT32* out_command_len);
UINT8 er_tpm_build_sign_p256_sha256_command(UINT32 handle,
                                            const UINT8 digest[32],
                                            UINT8* out_command,
                                            UINT32 command_capacity,
                                            UINT32* out_command_len);
UINT8 er_tpm_build_verify_p256_sha256_command(UINT32 handle,
                                              const UINT8 digest[ER_TPM_SHA256_DIGEST_LEN],
                                              const UINT8 signature[64],
                                              UINT8* out_command,
                                              UINT32 command_capacity,
                                              UINT32* out_command_len);
UINT8 er_tpm_build_encrypt_decrypt2_command(UINT32 handle,
                                            UINT8 decrypt,
                                            UINT16 mode,
                                            const UINT8* iv, UINT16 iv_len,
                                            const UINT8* input, UINT16 input_len,
                                            UINT8* out_command,
                                            UINT32 command_capacity,
                                            UINT32* out_command_len);
UINT8 er_tpm_build_ecdh_zgen_p256_command(UINT32 handle,
                                          const UINT8 peer_public_key[ER_TPM_P256_PUBLIC_KEY_LEN],
                                          UINT8* out_command,
                                          UINT32 command_capacity,
                                          UINT32* out_command_len);
UINT8 er_tpm_build_flush_context_command(UINT32 handle,
                                         UINT8* out_command, UINT32 command_capacity,
                                         UINT32* out_command_len);

UINT32 er_tpm_response_code(const UINT8* response, UINT32 response_len);
UINT8 er_tpm_response_success(const UINT8* response, UINT32 response_len);
UINT8 er_tpm_parse_get_random_response(const UINT8* response, UINT32 response_len,
                                       UINT8* out_random, UINT32 random_capacity,
                                       UINT32* out_random_len);
UINT8 er_tpm_parse_sha256_digest_response(const UINT8* response, UINT32 response_len,
                                          UINT8 out_digest[ER_TPM_SHA256_DIGEST_LEN]);
UINT8 er_tpm_parse_handle_response(const UINT8* response, UINT32 response_len,
                                   UINT32* out_handle);
UINT8 er_tpm_parse_verify_ticket_response(const UINT8* response, UINT32 response_len);
UINT8 er_tpm_parse_encrypt_decrypt2_response(const UINT8* response, UINT32 response_len,
                                             UINT8* out_data, UINT32 out_data_capacity,
                                             UINT32* out_data_len,
                                             UINT8* out_iv, UINT32 out_iv_capacity,
                                             UINT32* out_iv_len);
UINT8 er_tpm_parse_algorithm_profile_response(const UINT8* response,
                                              UINT32 response_len,
                                              ErTpmAlgorithmProfile* out_profile);
UINT8 er_tpm_parse_command_profile_response(const UINT8* response,
                                            UINT32 response_len,
                                            ErTpmCommandProfile* out_profile);
UINT8 er_tpm_tls_compat_profile_supported(const ErTpm2Info* info,
                                          const ErTpmAlgorithmProfile* algorithms,
                                          const ErTpmCommandProfile* commands);
UINT8 er_tpm_select_record_cipher_mode(const ErTpmAlgorithmProfile* algorithms,
                                       UINT16* out_mode);
UINT8 er_tpm_parse_nv_storage_limits_response(const UINT8* response,
                                              UINT32 response_len,
                                              ErTpmNvLimits* out_limits);
UINT8 er_tpm_parse_create_primary_p256_response(const UINT8* response,
                                                UINT32 response_len,
                                                ErTpmP256Primary* out_primary);
UINT8 er_tpm_parse_p256_point_response(const UINT8* response, UINT32 response_len,
                                       UINT8 out_public_key[ER_TPM_P256_PUBLIC_KEY_LEN]);
UINT8 er_tpm_parse_p256_sha256_signature_response(const UINT8* response,
                                                  UINT32 response_len,
                                                  UINT8 out_signature[64]);

#endif
