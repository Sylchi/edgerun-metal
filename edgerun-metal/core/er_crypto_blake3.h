#ifndef ER_CRYPTO_BLAKE3_H
#define ER_CRYPTO_BLAKE3_H

/*
 * Purpose: adapt the reusable BLAKE3 module to the metal crypto provider boundary.
 * Intention: keep algorithm code outside the EFI runtime while preserving ErCryptoProvider wiring.
 */

#include "er_crypto.h"

UINT8 er_crypto_blake3_hash(void* ctx, const UINT8* domain, UINTN domain_len,
                            const ErByteSpan* spans, UINTN span_count, ErHash* out_hash);
void er_crypto_blake3_provider(ErCryptoProvider* out_provider);

#endif
