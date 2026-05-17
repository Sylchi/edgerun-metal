#include "er_crypto_blake3.h"
#include "er_blake3.h"

UINT8 er_crypto_blake3_hash(void* ctx, const UINT8* domain, UINTN domain_len,
                            const ErByteSpan* spans, UINTN span_count, ErHash* out_hash) {
  static const UINT8 separator[1] = {0u};
  ErBlake3Hasher hasher;
  UINTN i;

  (void)ctx;
  if (domain == 0 || out_hash == 0 || (span_count > 0u && spans == 0)) {
    return 0u;
  }
  er_blake3_init(&hasher);
  if (er_blake3_update(&hasher, domain, (size_t)domain_len) == 0u ||
      er_blake3_update(&hasher, separator, 1u) == 0u) {
    return 0u;
  }
  for (i = 0u; i < span_count; ++i) {
    if (spans[i].len > 0u && spans[i].bytes == 0) {
      return 0u;
    }
    if (er_blake3_update(&hasher, spans[i].bytes, (size_t)spans[i].len) == 0u) {
      return 0u;
    }
  }
  return er_blake3_final(&hasher, out_hash->bytes);
}

void er_crypto_blake3_provider(ErCryptoProvider* out_provider) {
  if (out_provider == 0) {
    return;
  }
  out_provider->ctx = 0;
  out_provider->hash = er_crypto_blake3_hash;
  out_provider->seal = 0;
  out_provider->open = 0;
  out_provider->sign = 0;
  out_provider->verify = 0;
}
