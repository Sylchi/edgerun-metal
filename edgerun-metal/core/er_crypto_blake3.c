#include "er_crypto_blake3.h"
#include "er_blake3.h"
#include "er_credential.h"
#include "er_mem.h"

static const UINT8 g_blake3_seal_nonce_domain[] = "edgerun:c:v1:crypto:blake3-seal:nonce";
static const UINT8 g_blake3_seal_stream_domain[] = "edgerun:c:v1:crypto:blake3-seal:stream";
static const UINT8 g_blake3_seal_tag_domain[] = "edgerun:c:v1:crypto:blake3-seal:tag";

enum {
  ER_CRYPTO_BLAKE3_SEAL_ABI_VERSION = 1u,
  ER_CRYPTO_BLAKE3_SEAL_ALGORITHM = 1u,
  ER_CRYPTO_BLAKE3_SEAL_U16_BYTES = 2u,
  ER_CRYPTO_BLAKE3_SEAL_U64_BYTES = 8u,
  ER_CRYPTO_BLAKE3_SEAL_ABI_OFFSET = 0u,
  ER_CRYPTO_BLAKE3_SEAL_ALGORITHM_OFFSET = 2u,
  ER_CRYPTO_BLAKE3_SEAL_CIPHERTEXT_LEN_OFFSET = 4u,
  ER_CRYPTO_BLAKE3_SEAL_NONCE_OFFSET = 12u,
  ER_CRYPTO_BLAKE3_SEAL_U8_BITS = 8u,
  ER_CRYPTO_BLAKE3_SEAL_U16_SHIFT = 8u,
  ER_CRYPTO_BLAKE3_SEAL_U8_MASK = 0xffu,
  ER_CRYPTO_BLAKE3_SEAL_NONCE_SPAN_COUNT = 4u,
  ER_CRYPTO_BLAKE3_SEAL_NONCE_ROOT_SPAN = 0u,
  ER_CRYPTO_BLAKE3_SEAL_NONCE_RECIPIENT_SPAN = 1u,
  ER_CRYPTO_BLAKE3_SEAL_NONCE_AAD_SPAN = 2u,
  ER_CRYPTO_BLAKE3_SEAL_NONCE_PLAINTEXT_SPAN = 3u,
  ER_CRYPTO_BLAKE3_SEAL_STREAM_SPAN_COUNT = 3u,
  ER_CRYPTO_BLAKE3_SEAL_STREAM_ROOT_SPAN = 0u,
  ER_CRYPTO_BLAKE3_SEAL_STREAM_NONCE_SPAN = 1u,
  ER_CRYPTO_BLAKE3_SEAL_STREAM_COUNTER_SPAN = 2u,
  ER_CRYPTO_BLAKE3_SEAL_TAG_SPAN_COUNT = 5u,
  ER_CRYPTO_BLAKE3_SEAL_TAG_ROOT_SPAN = 0u,
  ER_CRYPTO_BLAKE3_SEAL_TAG_RECIPIENT_SPAN = 1u,
  ER_CRYPTO_BLAKE3_SEAL_TAG_AAD_SPAN = 2u,
  ER_CRYPTO_BLAKE3_SEAL_TAG_NONCE_SPAN = 3u,
  ER_CRYPTO_BLAKE3_SEAL_TAG_CIPHERTEXT_SPAN = 4u
};

static void er_crypto_blake3_set_span(ErByteSpan* span,
                                      const UINT8* bytes,
                                      UINTN len) {
  span->bytes = bytes;
  span->len = len;
}

static void er_crypto_blake3_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> ER_CRYPTO_BLAKE3_SEAL_U16_SHIFT) &
                   ER_CRYPTO_BLAKE3_SEAL_U8_MASK);
  dst[1] = (UINT8)(value & ER_CRYPTO_BLAKE3_SEAL_U8_MASK);
}

static UINT16 er_crypto_blake3_read_be16(const UINT8* src) {
  return (UINT16)(((UINT16)src[0] << ER_CRYPTO_BLAKE3_SEAL_U16_SHIFT) |
                  (UINT16)src[1]);
}

static void er_crypto_blake3_put_be64(UINT8* dst, UINT64 value) {
  UINTN i;
  UINT32 shift;

  for (i = 0u; i < ER_CRYPTO_BLAKE3_SEAL_U64_BYTES; ++i) {
    shift = (UINT32)((ER_CRYPTO_BLAKE3_SEAL_U64_BYTES - 1u - i) *
                     ER_CRYPTO_BLAKE3_SEAL_U8_BITS);
    dst[i] = (UINT8)((value >> shift) & ER_CRYPTO_BLAKE3_SEAL_U8_MASK);
  }
}

static UINT64 er_crypto_blake3_read_be64(const UINT8* src) {
  UINTN i;
  UINT32 shift;
  UINT64 value = 0u;

  for (i = 0u; i < ER_CRYPTO_BLAKE3_SEAL_U64_BYTES; ++i) {
    shift = (UINT32)((ER_CRYPTO_BLAKE3_SEAL_U64_BYTES - 1u - i) *
                     ER_CRYPTO_BLAKE3_SEAL_U8_BITS);
    value |= ((UINT64)src[i] << shift);
  }
  return value;
}

static UINT8 er_crypto_blake3_equal_constant_time(const UINT8* left,
                                                  const UINT8* right,
                                                  UINTN len) {
  UINTN i;
  UINT8 diff = 0u;

  if (left == 0 || right == 0 || len == 0u) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    diff = (UINT8)(diff | (left[i] ^ right[i]));
  }
  return (UINT8)(diff == 0u);
}

static UINT8 er_crypto_blake3_sealer_valid(const ErCryptoBlake3Sealer* sealer) {
  if (sealer == 0) {
    return 0u;
  }
  return er_mem_any_nonzero(sealer->root_key,
                            ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN);
}

static UINT8 er_crypto_blake3_nonce(const ErCryptoBlake3Sealer* sealer,
                                    const ErCredential* recipient,
                                    const ErByteSpan* aad,
                                    const ErByteSpan* plaintext,
                                    UINT8 nonce[ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN]) {
  ErByteSpan spans[ER_CRYPTO_BLAKE3_SEAL_NONCE_SPAN_COUNT];
  ErHash hash;

  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_NONCE_ROOT_SPAN],
                            sealer->root_key,
                            ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_NONCE_RECIPIENT_SPAN],
                            (const UINT8*)recipient, (UINTN)sizeof(*recipient));
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_NONCE_AAD_SPAN],
                            aad->bytes, aad->len);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_NONCE_PLAINTEXT_SPAN],
                            plaintext->bytes, plaintext->len);
  if (er_crypto_blake3_hash(0, g_blake3_seal_nonce_domain,
                            (UINTN)(sizeof(g_blake3_seal_nonce_domain) - 1u),
                            spans, ER_CRYPTO_BLAKE3_SEAL_NONCE_SPAN_COUNT,
                            &hash) == 0u) {
    return 0u;
  }
  er_mem_copy(nonce, hash.bytes, ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN);
  return 1u;
}

static UINT8 er_crypto_blake3_stream_block(const ErCryptoBlake3Sealer* sealer,
                                           const UINT8 nonce[ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN],
                                           UINT64 counter,
                                           UINT8 stream[ER_HASH_LEN]) {
  UINT8 counter_bytes[ER_CRYPTO_BLAKE3_SEAL_U64_BYTES];
  ErByteSpan spans[ER_CRYPTO_BLAKE3_SEAL_STREAM_SPAN_COUNT];
  ErHash hash;

  er_crypto_blake3_put_be64(counter_bytes, counter);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_STREAM_ROOT_SPAN],
                            sealer->root_key,
                            ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_STREAM_NONCE_SPAN],
                            nonce, ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_STREAM_COUNTER_SPAN],
                            counter_bytes, (UINTN)sizeof(counter_bytes));
  if (er_crypto_blake3_hash(0, g_blake3_seal_stream_domain,
                            (UINTN)(sizeof(g_blake3_seal_stream_domain) - 1u),
                            spans, ER_CRYPTO_BLAKE3_SEAL_STREAM_SPAN_COUNT,
                            &hash) == 0u) {
    return 0u;
  }
  er_mem_copy(stream, hash.bytes, ER_HASH_LEN);
  return 1u;
}

static UINT8 er_crypto_blake3_xor_stream(const ErCryptoBlake3Sealer* sealer,
                                         const UINT8 nonce[ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN],
                                         const UINT8* input,
                                         UINTN input_len,
                                         UINT8* output) {
  UINTN i;
  UINTN block_offset;
  UINT64 counter = 0u;
  UINT8 stream[ER_HASH_LEN];

  if (input == 0 || output == 0 || input_len == 0u) {
    return 0u;
  }
  block_offset = 0u;
  for (i = 0u; i < input_len; ++i) {
    if (block_offset == 0u &&
        er_crypto_blake3_stream_block(sealer, nonce, counter, stream) == 0u) {
      return 0u;
    }
    output[i] = (UINT8)(input[i] ^ stream[block_offset]);
    ++block_offset;
    if (block_offset == ER_HASH_LEN) {
      block_offset = 0u;
      ++counter;
    }
  }
  return 1u;
}

static UINT8 er_crypto_blake3_tag(const ErCryptoBlake3Sealer* sealer,
                                  const ErCredential* recipient,
                                  const ErByteSpan* aad,
                                  const UINT8 nonce[ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN],
                                  const UINT8* ciphertext,
                                  UINTN ciphertext_len,
                                  UINT8 tag[ER_CRYPTO_BLAKE3_SEAL_TAG_LEN]) {
  ErByteSpan spans[ER_CRYPTO_BLAKE3_SEAL_TAG_SPAN_COUNT];
  ErHash hash;

  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_TAG_ROOT_SPAN],
                            sealer->root_key,
                            ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_TAG_RECIPIENT_SPAN],
                            (const UINT8*)recipient, (UINTN)sizeof(*recipient));
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_TAG_AAD_SPAN],
                            aad->bytes, aad->len);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_TAG_NONCE_SPAN],
                            nonce, ER_CRYPTO_BLAKE3_SEAL_NONCE_LEN);
  er_crypto_blake3_set_span(&spans[ER_CRYPTO_BLAKE3_SEAL_TAG_CIPHERTEXT_SPAN],
                            ciphertext, ciphertext_len);
  if (er_crypto_blake3_hash(0, g_blake3_seal_tag_domain,
                            (UINTN)(sizeof(g_blake3_seal_tag_domain) - 1u),
                            spans, ER_CRYPTO_BLAKE3_SEAL_TAG_SPAN_COUNT,
                            &hash) == 0u) {
    return 0u;
  }
  er_mem_copy(tag, hash.bytes, ER_CRYPTO_BLAKE3_SEAL_TAG_LEN);
  return 1u;
}

static UINT8 er_crypto_blake3_seal(void* ctx, const ErCredential* recipient,
                                   const ErByteSpan* aad,
                                   const ErByteSpan* plaintext,
                                   ErMutableBytes* sealed_out) {
  ErCryptoBlake3Sealer* sealer = (ErCryptoBlake3Sealer*)ctx;
  UINT8* nonce;
  UINT8* ciphertext;
  UINT8* tag;
  UINTN sealed_len;

  if (er_crypto_blake3_sealer_valid(sealer) == 0u ||
      er_credential_valid(recipient) == 0u || aad == 0 ||
      plaintext == 0 || plaintext->bytes == 0 || plaintext->len == 0u ||
      sealed_out == 0 || sealed_out->bytes == 0) {
    return 0u;
  }
  if (aad->len > 0u && aad->bytes == 0) {
    return 0u;
  }
  sealed_len = ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN + plaintext->len +
               ER_CRYPTO_BLAKE3_SEAL_TAG_LEN;
  if (sealed_len < plaintext->len || sealed_out->capacity < sealed_len) {
    return 0u;
  }

  er_mem_zero(sealed_out->bytes, sealed_out->capacity);
  er_crypto_blake3_put_be16(sealed_out->bytes + ER_CRYPTO_BLAKE3_SEAL_ABI_OFFSET,
                            ER_CRYPTO_BLAKE3_SEAL_ABI_VERSION);
  er_crypto_blake3_put_be16(sealed_out->bytes + ER_CRYPTO_BLAKE3_SEAL_ALGORITHM_OFFSET,
                            ER_CRYPTO_BLAKE3_SEAL_ALGORITHM);
  er_crypto_blake3_put_be64(sealed_out->bytes + ER_CRYPTO_BLAKE3_SEAL_CIPHERTEXT_LEN_OFFSET,
                            (UINT64)plaintext->len);
  nonce = sealed_out->bytes + ER_CRYPTO_BLAKE3_SEAL_NONCE_OFFSET;
  ciphertext = sealed_out->bytes + ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN;
  tag = ciphertext + plaintext->len;
  if (er_crypto_blake3_nonce(sealer, recipient, aad, plaintext, nonce) == 0u ||
      er_crypto_blake3_xor_stream(sealer, nonce, plaintext->bytes,
                                  plaintext->len, ciphertext) == 0u ||
      er_crypto_blake3_tag(sealer, recipient, aad, nonce, ciphertext,
                           plaintext->len, tag) == 0u) {
    return 0u;
  }
  sealed_out->len = sealed_len;
  return 1u;
}

static UINT8 er_crypto_blake3_open(void* ctx, const ErCredential* recipient,
                                   const ErByteSpan* aad,
                                   const ErByteSpan* sealed,
                                   ErMutableBytes* plaintext_out) {
  ErCryptoBlake3Sealer* sealer = (ErCryptoBlake3Sealer*)ctx;
  const UINT8* nonce;
  const UINT8* ciphertext;
  const UINT8* tag;
  UINT8 expected_tag[ER_CRYPTO_BLAKE3_SEAL_TAG_LEN];
  UINT64 ciphertext_len;
  UINTN expected_sealed_len;

  if (er_crypto_blake3_sealer_valid(sealer) == 0u ||
      er_credential_valid(recipient) == 0u || aad == 0 ||
      sealed == 0 || sealed->bytes == 0 ||
      sealed->len <= ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN + ER_CRYPTO_BLAKE3_SEAL_TAG_LEN ||
      plaintext_out == 0 || plaintext_out->bytes == 0) {
    return 0u;
  }
  if (aad->len > 0u && aad->bytes == 0) {
    return 0u;
  }
  if (er_crypto_blake3_read_be16(sealed->bytes + ER_CRYPTO_BLAKE3_SEAL_ABI_OFFSET) !=
          ER_CRYPTO_BLAKE3_SEAL_ABI_VERSION ||
      er_crypto_blake3_read_be16(sealed->bytes + ER_CRYPTO_BLAKE3_SEAL_ALGORITHM_OFFSET) !=
          ER_CRYPTO_BLAKE3_SEAL_ALGORITHM) {
    return 0u;
  }
  ciphertext_len =
      er_crypto_blake3_read_be64(sealed->bytes + ER_CRYPTO_BLAKE3_SEAL_CIPHERTEXT_LEN_OFFSET);
  if (ciphertext_len == 0u || ciphertext_len > (UINT64)plaintext_out->capacity) {
    return 0u;
  }
  expected_sealed_len = ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN +
                        (UINTN)ciphertext_len +
                        ER_CRYPTO_BLAKE3_SEAL_TAG_LEN;
  if ((UINT64)(UINTN)ciphertext_len != ciphertext_len ||
      expected_sealed_len < (UINTN)ciphertext_len ||
      expected_sealed_len != sealed->len) {
    return 0u;
  }
  nonce = sealed->bytes + ER_CRYPTO_BLAKE3_SEAL_NONCE_OFFSET;
  ciphertext = sealed->bytes + ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN;
  tag = ciphertext + (UINTN)ciphertext_len;
  if (er_crypto_blake3_tag(sealer, recipient, aad, nonce, ciphertext,
                           (UINTN)ciphertext_len, expected_tag) == 0u ||
      er_crypto_blake3_equal_constant_time(expected_tag, tag,
                                           ER_CRYPTO_BLAKE3_SEAL_TAG_LEN) == 0u ||
      er_crypto_blake3_xor_stream(sealer, nonce, ciphertext,
                                  (UINTN)ciphertext_len,
                                  plaintext_out->bytes) == 0u) {
    return 0u;
  }
  plaintext_out->len = (UINTN)ciphertext_len;
  return 1u;
}

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

UINT8 er_crypto_blake3_sealer_init(ErCryptoBlake3Sealer* sealer,
                                   const UINT8 root_key[ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN]) {
  if (sealer == 0 || root_key == 0 ||
      er_mem_any_nonzero(root_key, ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)sealer, (UINTN)sizeof(*sealer));
  er_mem_copy(sealer->root_key, root_key, ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN);
  return 1u;
}

void er_crypto_blake3_sealing_provider(ErCryptoBlake3Sealer* sealer,
                                       ErCryptoProvider* out_provider) {
  if (out_provider == 0) {
    return;
  }
  out_provider->ctx = sealer;
  out_provider->hash = er_crypto_blake3_hash;
  out_provider->seal = er_crypto_blake3_seal;
  out_provider->open = er_crypto_blake3_open;
  out_provider->sign = 0;
  out_provider->verify = 0;
}
