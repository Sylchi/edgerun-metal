#ifndef ER_CRYPTO_BLAKE3_H
#define ER_CRYPTO_BLAKE3_H

/*
 * Purpose: adapt the reusable BLAKE3 module to the metal crypto provider boundary.
 * Intention: keep algorithm code outside the EFI runtime while preserving ErCryptoProvider wiring.
 */

#include "er_crypto.h"

#define ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN 32u
#define ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN 32u
#define ER_CRYPTO_BLAKE3_SEAL_TAG_LEN 32u
#define ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN 44u

typedef struct {
  UINT8 root_key[ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN];
} ErCryptoBlake3Sealer;

UINT8 er_crypto_blake3_hash(void* ctx, const UINT8* domain, UINTN domain_len,
                            const ErByteSpan* spans, UINTN span_count, ErHash* out_hash);
UINT8 er_crypto_blake3_sealer_init(ErCryptoBlake3Sealer* sealer,
                                   const UINT8 root_key[ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN]);
void er_crypto_blake3_provider(ErCryptoProvider* out_provider);
void er_crypto_blake3_sealing_provider(ErCryptoBlake3Sealer* sealer,
                                       ErCryptoProvider* out_provider);

#endif
