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

UINT8 er_crypto_sign(const ErCryptoProvider* provider, const ErByteSpan* preimage,
                     ErWorkSignature* out_signature) {
  if (provider == 0 || provider->sign == 0 || preimage == 0 ||
      preimage->bytes == 0 || preimage->len == 0u || out_signature == 0) {
    return 0u;
  }
  return provider->sign(provider->ctx, preimage, out_signature);
}

UINT8 er_crypto_verify(const ErCryptoProvider* provider, const ErIdentity* identity,
                       const ErByteSpan* preimage, const ErWorkSignature* signature) {
  if (provider == 0 || provider->verify == 0 || identity == 0 ||
      preimage == 0 || preimage->bytes == 0 || preimage->len == 0u ||
      signature == 0) {
    return 0u;
  }
  return provider->verify(provider->ctx, identity, preimage, signature);
}
