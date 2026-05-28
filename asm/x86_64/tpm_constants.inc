; EdgeRun TPM2 shared protocol constants
; Included by both tpm.asm and consumers (e.g. kernel_main.asm)
; to avoid duplicate definitions.

; ─── Tags ──────────────────────────────────────────────────────────
%define TPM_ST_NO_SESSIONS      0x8001
%define TPM_ST_SESSIONS         0x8002
%define TPM_ST_VERIFIED         0x8022
%define TPM_ST_HASHCHECK        0x8024

; ─── Response codes ───────────────────────────────────────────────
%define TPM_RC_SUCCESS          0x00000000
%define TPM_RC_METAL_PROTOCOL   0xFFFFFFFC

; ─── Common command codes ─────────────────────────────────────────
%define TPM_CC_STARTUP          0x00000144
%define TPM_CC_SHUTDOWN         0x00000145
%define TPM_CC_CREATE_PRIMARY   0x00000131
%define TPM_CC_ECDH_ZGEN        0x00000154
%define TPM_CC_HMAC             0x00000155
%define TPM_CC_LOAD_EXTERNAL    0x00000167
%define TPM_CC_GET_CAPABILITY   0x0000017a
%define TPM_CC_GET_RANDOM       0x0000017b
%define TPM_CC_HASH             0x0000017d
%define TPM_CC_ENCRYPT_DECRYPT2 0x00000193
%define TPM_CC_HASH_SEQUENCE_START 0x00000186
%define TPM_CC_SEQUENCE_COMPLETE 0x0000013e
%define TPM_CC_SEQUENCE_UPDATE  0x0000015c
%define TPM_CC_SIGN             0x0000015d
%define TPM_CC_VERIFY_SIGNATURE 0x00000177
%define TPM_CC_FLUSH_CONTEXT    0x00000165
%define TPM_CC_READ_PUBLIC      0x00000173

; ─── Startup/Shutdown types ───────────────────────────────────────
%define TPM_SU_CLEAR            0x0000
%define TPM_SU_STATE            0x0001

; ─── Capability types ─────────────────────────────────────────────
%define TPM_CAP_ALGS            0x00000000
%define TPM_CAP_COMMANDS        0x00000002
%define TPM_CAP_TPM_PROPERTIES  0x00000006

; ─── TPM properties ───────────────────────────────────────────────
%define TPM_PT_NV_INDEX_MAX     0x00000117
%define TPM_PT_NV_BUFFER_MAX    0x0000012c

; ─── Common algorithm IDs ─────────────────────────────────────────
%define TPM_ALG_SHA256          0x000b
%define TPM_ALG_ECC             0x0023
%define TPM_ALG_NULL            0x0010
%define TPM_ALG_HMAC            0x0005
%define TPM_ALG_KEYEDHASH       0x0008
%define TPM_ALG_ECDH            0x0019
%define TPM_ALG_ECDSA           0x0018
%define TPM_ALG_AES             0x0006
%define TPM_ALG_SYMCIPHER       0x0025
%define TPM_ALG_CTR             0x0040
%define TPM_ALG_OFB             0x0041
%define TPM_ALG_CBC             0x0042
%define TPM_ALG_CFB             0x0043
%define TPM_ALG_ECB             0x0044

; ─── ECC curves ───────────────────────────────────────────────────
%define TPM_ECC_NIST_P256       0x0003

; ─── Handle values ────────────────────────────────────────────────
%define TPM_RH_OWNER            0x40000001
%define TPM_RH_NULL             0x40000007
%define TPM_RH_ENDORSEMENT      0x4000000b
%define TPM_RH_PLATFORM         0x4000000c

; ─── Object attributes ────────────────────────────────────────────
%define TPM_OA_FIXED_TPM        0x00000002
%define TPM_OA_FIXED_PARENT     0x00000010
%define TPM_OA_SENSITIVE_DATA_ORIGIN 0x00000020
%define TPM_OA_USER_WITH_AUTH   0x00000040
%define TPM_OA_NODA             0x00000400
%define TPM_OA_SIGN_ENCRYPT     0x00040000
%define TPM_OA_DECRYPT          0x00020000

; ─── Protocol sizes ───────────────────────────────────────────────
%define TPM_HEADER_LEN          10
%define TPM_CMD_SIZE_OFFSET     2
%define TPM_CMD_CODE_OFFSET     6
%define TPM_RSP_SIZE_OFFSET     2
%define TPM_RSP_CODE_OFFSET     6
%define TPM_RANDOM_OFFSET       12
%define TPM_SHA256_DIGEST_LEN   32
%define TPM_P256_PUBLIC_KEY_LEN 64
%define TPM_P256_POINT_BYTES    32
%define TPM_TAG_PROPERTY_LEN    8
%define TPM_TPM2B_LEN_BYTES     2
%define TPM_AUTH_VALUE_LEN      9
%define TPM_RS_PW               0x40000009
%define TPM_SIG_SCHEME_HASH_LEN 4
%define TPM_SIG_MAX_COMP_LEN    32
%define TPM_ECC_PARAMS_LEN      10
%define TPM_P256_POINT_BODY_LEN 68
%define TPM_CREATE_PRIMARY_PUBLIC_AREA_LEN 24
%define TPM_EMPTY_SENSITIVE_CREATE_LEN 4
%define TPM_LOAD_EXT_P256_PUBLIC_AREA_LEN 88
%define TPM_LOAD_EXT_KEYEDHASH_PUBLIC_AREA_LEN 46
%define TPM_LOAD_EXT_SYMCIPHER_PUBLIC_AREA_LEN 50
%define TPM_LOAD_EXT_HMAC_SENSITIVE_HEADER_LEN 8
%define TPM_LOAD_EXT_AES_SENSITIVE_HEADER_LEN 8
%define TPM_TPMT_PUBLIC_FIXED_LEN 10
%define TPM_PUBLIC_AUTH_POLICY_OFFSET 8

; ─── Command size constants ───────────────────────────────────────
%define TPM_CMD_STARTUP_LEN             12
%define TPM_CMD_SHUTDOWN_LEN            12
%define TPM_CMD_GET_RANDOM_LEN          12
%define TPM_CMD_GET_CAP_LEN             22
%define TPM_CMD_FLUSH_CONTEXT_LEN       14
%define TPM_CMD_READ_PUBLIC_LEN         14
%define TPM_CMD_HASH_SEQUENCE_START_LEN 14
%define TPM_CMD_CREATE_PRIMARY_LEN      65
%define TPM_CMD_SIGN_LEN                73
%define TPM_CMD_VERIFY_SHA256_LEN       120
%define TPM_CMD_ECDH_ZGEN_LEN           97
%define TPM_CMD_HASH_FIXED_LEN          18
%define TPM_CMD_HMAC_FIXED_LEN          31
%define TPM_CMD_SEQ_UPDATE_FIXED_LEN    29
%define TPM_CMD_SEQ_COMPLETE_FIXED_LEN  33
%define TPM_CMD_ENC_DEC2_FIXED_LEN      34
%define TPM_CMD_LOAD_EXT_P256_LEN       106
%define TPM_CMD_LOAD_EXT_KEYEDHASH_FIXED_LEN 104
%define TPM_CMD_LOAD_EXT_SYMCIPHER_FIXED_LEN 108
