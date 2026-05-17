#include "er_crypto.h"

/*
 * Purpose: keep crypto dispatch checks in one small freestanding unit.
 * Intention: callers fail closed when no runtime crypto provider is installed.
 */

UINT8 er_crypto_hash(const ErCryptoProvider* provider, const UINT8* domain, UINTN domain_len,
                     const ErByteSpan* spans, UINTN span_count, ErHash* out_hash) {
  if (provider == 0 || provider->hash == 0 || domain == 0 || out_hash == 0) {
    return 0;
  }
  if (span_count > 0u && spans == 0) {
    return 0;
  }
  return provider->hash(provider->ctx, domain, domain_len, spans, span_count, out_hash);
}
