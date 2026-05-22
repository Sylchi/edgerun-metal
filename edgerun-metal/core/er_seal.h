#ifndef ER_SEAL_H
#define ER_SEAL_H

/*
 * Purpose: choose recipient-sealing envelope shape before crypto implementation details.
 * Intention: encrypt payload bytes once when fanout or durable reuse would make per-recipient sealing wasteful.
 */

#include "er_types.h"
#include "er_crypto.h"

#define ER_SEAL_ABI_VERSION 1u
#define ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH 1u
#define ER_SEAL_CONTENT_KEY_THRESHOLD_BYTES 4096u
#define ER_SEAL_CONTENT_KEY_REUSE_MIN 2u
#define ER_SEAL_RECIPIENT_COUNT_DIRECT 1u
#define ER_SEAL_CONTENT_KEY_LEN 32u

typedef enum {
  ER_SEAL_STRATEGY_INVALID = 0,
  ER_SEAL_STRATEGY_DIRECT_RECIPIENT = 1,
  ER_SEAL_STRATEGY_CONTENT_KEY_WRAP = 2
} ErSealStrategy;

typedef struct {
  UINT8 bytes[ER_SEAL_CONTENT_KEY_LEN];
} ErSealContentKey;

typedef struct {
  UINT16 abi_version;
  UINT16 strategy;
  UINT16 algorithm;
  UINT16 reserved;
  ErIdentity recipient;
  ErHash plaintext_hash;
  UINT64 plaintext_len;
  ErHash aad_hash;
  ErHash sealed_payload_hash;
  UINT64 sealed_payload_len;
  ErHash sealed_record_id;
} ErSealedContentRecordHeader;

typedef struct {
  UINT16 abi_version;
  UINT16 algorithm;
  UINT16 reserved;
  UINT16 wrapped_key_len;
  ErIdentity recipient;
  ErHash content_key_hash;
  ErHash wrap_aad_hash;
  ErHash wrapped_key_hash;
  ErHash wrap_id;
} ErSealedContentKeyWrap;

ErSealStrategy er_seal_select_strategy(UINT32 recipient_count,
                                       UINT64 plaintext_len,
                                       UINT32 expected_reuse_count);
const char* er_seal_strategy_label(ErSealStrategy strategy);
UINT8 er_seal_prepare_content_key(const UINT8 key_bytes[ER_SEAL_CONTENT_KEY_LEN],
                                  ErSealContentKey* out_key);
UINT8 er_seal_prepare_content_record(const ErCryptoProvider* crypto,
                                     const ErIdentity* recipient,
                                     const ErByteSpan* aad,
                                     const ErByteSpan* plaintext,
                                     UINT32 expected_reuse_count,
                                     ErMutableBytes* sealed_out,
                                     ErSealedContentRecordHeader* out_header);
UINT8 er_seal_content_record_valid(const ErCryptoProvider* crypto,
                                   const ErSealedContentRecordHeader* header,
                                   const ErByteSpan* aad,
                                   const UINT8* sealed_payload,
                                   UINTN sealed_payload_len);
UINT8 er_seal_wrap_content_key(const ErCryptoProvider* crypto,
                               const ErIdentity* recipient,
                               const ErByteSpan* wrap_aad,
                               const ErSealContentKey* content_key,
                               ErMutableBytes* wrapped_key_out,
                               ErSealedContentKeyWrap* out_wrap);
UINT8 er_seal_content_key_wrap_valid(const ErCryptoProvider* crypto,
                                     const ErSealedContentKeyWrap* wrap,
                                     const ErByteSpan* wrap_aad,
                                     const UINT8* wrapped_key,
                                     UINTN wrapped_key_len);
UINT8 er_seal_open_content_key(const ErCryptoProvider* crypto,
                               const ErSealedContentKeyWrap* wrap,
                               const ErByteSpan* wrap_aad,
                               const UINT8* wrapped_key,
                               UINTN wrapped_key_len,
                               ErSealContentKey* out_key);

#endif
