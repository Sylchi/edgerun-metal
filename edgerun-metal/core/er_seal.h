#ifndef ER_SEAL_H
#define ER_SEAL_H

/*
 * Purpose: choose recipient-sealing envelope shape before crypto implementation details.
 * Intention: encrypt payload bytes once when fanout or durable reuse would make per-recipient sealing wasteful.
 */

#include "er_types.h"
#include "er_crypto.h"

#define ER_SEAL_ABI_VERSION 1u
#define ER_SEAL_ALGORITHM_AES256_GCM 1u
#define ER_SEAL_CONTENT_KEY_THRESHOLD_BYTES 4096u
#define ER_SEAL_CONTENT_KEY_REUSE_MIN 2u
#define ER_SEAL_RECIPIENT_COUNT_DIRECT 1u

typedef enum {
  ER_SEAL_STRATEGY_INVALID = 0,
  ER_SEAL_STRATEGY_DIRECT_RECIPIENT = 1,
  ER_SEAL_STRATEGY_CONTENT_KEY_WRAP = 2
} ErSealStrategy;

typedef struct {
  UINT16 abi_version;
  UINT16 strategy;
  UINT16 algorithm;
  UINT16 reserved;
  ErIdentity recipient;
  ErHash plaintext_object_id;
  UINT64 plaintext_len;
  ErHash aad_hash;
  ErHash sealed_payload_hash;
  UINT64 sealed_payload_len;
  ErHash sealed_object_id;
} ErSealedContentObjectHeader;

ErSealStrategy er_seal_select_strategy(UINT32 recipient_count,
                                       UINT64 plaintext_len,
                                       UINT32 expected_reuse_count);
const char* er_seal_strategy_label(ErSealStrategy strategy);
UINT8 er_seal_prepare_content_object(const ErCryptoProvider* crypto,
                                     const ErIdentity* recipient,
                                     const ErByteSpan* aad,
                                     const ErByteSpan* plaintext,
                                     UINT32 expected_reuse_count,
                                     ErMutableBytes* sealed_out,
                                     ErSealedContentObjectHeader* out_header);
UINT8 er_seal_content_object_valid(const ErCryptoProvider* crypto,
                                   const ErSealedContentObjectHeader* header,
                                   const ErByteSpan* aad,
                                   const UINT8* sealed_payload,
                                   UINTN sealed_payload_len);

#endif
