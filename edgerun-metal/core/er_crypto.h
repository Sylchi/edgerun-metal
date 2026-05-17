#ifndef ER_CRYPTO_H
#define ER_CRYPTO_H

/*
 * Purpose: describe the cryptographic provider boundary used by runtime records.
 * Intention: keep hashing, signing, and sealing explicit without baking in host or TLS assumptions.
 */

#include "er_work.h"

typedef struct {
  const UINT8* bytes;
  UINTN len;
} ErByteSpan;

typedef struct {
  UINT8* bytes;
  UINTN len;
  UINTN capacity;
} ErMutableBytes;

typedef UINT8 (*ErCryptoHashFn)(void* ctx, const UINT8* domain, UINTN domain_len,
                                const ErByteSpan* spans, UINTN span_count, ErHash* out_hash);
typedef UINT8 (*ErCryptoSealFn)(void* ctx, const ErPublicKey* recipient, const ErByteSpan* aad,
                                const ErByteSpan* plaintext, ErMutableBytes* sealed_out);
typedef UINT8 (*ErCryptoOpenFn)(void* ctx, const ErPublicKey* recipient, const ErByteSpan* aad,
                                const ErByteSpan* sealed, ErMutableBytes* plaintext_out);
typedef UINT8 (*ErCryptoSignFn)(void* ctx, const ErByteSpan* preimage, ErWorkSignature* out_signature);
typedef UINT8 (*ErCryptoVerifyFn)(void* ctx, const ErPublicKey* public_key, const ErByteSpan* preimage,
                                  const ErWorkSignature* signature);

typedef struct {
  void* ctx;
  ErCryptoHashFn hash;
  ErCryptoSealFn seal;
  ErCryptoOpenFn open;
  ErCryptoSignFn sign;
  ErCryptoVerifyFn verify;
} ErCryptoProvider;

UINT8 er_crypto_hash(const ErCryptoProvider* provider, const UINT8* domain, UINTN domain_len,
                     const ErByteSpan* spans, UINTN span_count, ErHash* out_hash);

#endif
