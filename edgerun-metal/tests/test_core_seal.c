#include "test_core_internal.h"

enum {
  TEST_SEAL_TAG_BYTES = 16u
};

static UINT8 test_seal_bytes(void* ctx, const ErIdentity* recipient,
                             const ErByteSpan* aad,
                             const ErByteSpan* plaintext,
                             ErMutableBytes* sealed_out) {
  UINTN i;
  UINT8 key = (UINT8)(UINTN)ctx;

  if (er_identity_valid(recipient) == 0u || aad == 0 ||
      plaintext == 0 || plaintext->bytes == 0 || plaintext->len == 0u ||
      sealed_out == 0 || sealed_out->bytes == 0 ||
      sealed_out->capacity < plaintext->len + TEST_SEAL_TAG_BYTES) {
    return 0u;
  }
  if (aad->len > 0u && aad->bytes == 0) {
    return 0u;
  }
  for (i = 0u; i < plaintext->len; ++i) {
    sealed_out->bytes[i] = (UINT8)(plaintext->bytes[i] ^ key ^
                                   recipient->material[i % recipient->material_len]);
  }
  for (i = 0u; i < TEST_SEAL_TAG_BYTES; ++i) {
    sealed_out->bytes[plaintext->len + i] =
        (UINT8)(key + recipient->material[i % recipient->material_len] +
                (aad->len == 0u ? 0u : aad->bytes[i % aad->len]) + (UINT8)i);
  }
  sealed_out->len = plaintext->len + TEST_SEAL_TAG_BYTES;
  return 1u;
}

static UINT8 test_open_bytes(void* ctx, const ErIdentity* recipient,
                             const ErByteSpan* aad,
                             const ErByteSpan* sealed,
                             ErMutableBytes* plaintext_out) {
  UINTN i;
  UINTN plaintext_len;
  UINT8 key = (UINT8)(UINTN)ctx;

  if (er_identity_valid(recipient) == 0u || aad == 0 ||
      sealed == 0 || sealed->bytes == 0 || sealed->len <= TEST_SEAL_TAG_BYTES ||
      plaintext_out == 0 || plaintext_out->bytes == 0) {
    return 0u;
  }
  if (aad->len > 0u && aad->bytes == 0) {
    return 0u;
  }
  plaintext_len = sealed->len - TEST_SEAL_TAG_BYTES;
  if (plaintext_out->capacity < plaintext_len) {
    return 0u;
  }
  for (i = 0u; i < plaintext_len; ++i) {
    plaintext_out->bytes[i] = (UINT8)(sealed->bytes[i] ^ key ^
                                      recipient->material[i % recipient->material_len]);
  }
  plaintext_out->len = plaintext_len;
  return 1u;
}

static void test_sealed_content_object_format(void) {
  static const UINT8 aad_bytes[] = {'r', 'o', 'u', 't', 'e'};
  static const UINT8 plaintext_bytes[] = {'p', 'a', 'c', 'k', 'a', 'g', 'e'};
  ErCryptoProvider crypto;
  ErIdentity recipient;
  ErByteSpan aad;
  ErByteSpan plaintext;
  ErMutableBytes sealed_out;
  ErSealedContentObjectHeader header;
  UINT8 recipient_key[ER_PUBLIC_KEY_LEN];
  UINT8 sealed_bytes[64];
  UINT8 opened_bytes[64];

  crypto.ctx = (void*)(UINTN)0x5au;
  crypto.hash = test_hash;
  crypto.seal = test_seal_bytes;
  crypto.open = test_open_bytes;
  crypto.sign = 0;
  crypto.verify = 0;

  test_fill_bytes(recipient_key, (UINTN)sizeof(recipient_key), 0x20u);
  check_int64("seal recipient identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  recipient_key,
                                  (UINT16)sizeof(recipient_key),
                                  &recipient),
              1);

  aad.bytes = aad_bytes;
  aad.len = (UINTN)sizeof(aad_bytes);
  plaintext.bytes = plaintext_bytes;
  plaintext.len = (UINTN)sizeof(plaintext_bytes);
  sealed_out.bytes = sealed_bytes;
  sealed_out.len = 0u;
  sealed_out.capacity = (UINTN)sizeof(sealed_bytes);

  check_int64("seal content object prepare",
              er_seal_prepare_content_object(&crypto, &recipient, &aad,
                                             &plaintext, 1u, &sealed_out,
                                             &header),
              1);
  check_int64("seal content abi", header.abi_version, ER_SEAL_ABI_VERSION);
  check_int64("seal content strategy", header.strategy,
              ER_SEAL_STRATEGY_DIRECT_RECIPIENT);
  check_int64("seal content algorithm", header.algorithm,
              ER_SEAL_ALGORITHM_AES256_GCM);
  check_uint64("seal content plaintext len", header.plaintext_len,
               (UINT64)sizeof(plaintext_bytes));
  check_uint64("seal content payload len", header.sealed_payload_len,
               (UINT64)(sizeof(plaintext_bytes) + TEST_SEAL_TAG_BYTES));
  check_int64("seal content valid",
              er_seal_content_object_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              1);
  {
    ErByteSpan sealed_span;
    ErMutableBytes plaintext_out;

    sealed_span.bytes = sealed_bytes;
    sealed_span.len = sealed_out.len;
    plaintext_out.bytes = opened_bytes;
    plaintext_out.len = 0u;
    plaintext_out.capacity = (UINTN)sizeof(opened_bytes);
    check_int64("seal content open dispatch",
                er_crypto_open(&crypto, &recipient, &aad, &sealed_span,
                               &plaintext_out),
                1);
    check_uint64("seal content open len", plaintext_out.len,
                 (UINT64)sizeof(plaintext_bytes));
    check_int64("seal content opened byte", opened_bytes[0], plaintext_bytes[0]);
  }

  sealed_bytes[0] ^= 1u;
  check_int64("seal content reject payload tamper",
              er_seal_content_object_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              0);
  sealed_bytes[0] ^= 1u;
  header.reserved = 1u;
  check_int64("seal content reject reserved",
              er_seal_content_object_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              0);
  header.reserved = 0u;
  aad.len = 0u;
  check_int64("seal content reject aad mismatch",
              er_seal_content_object_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              0);
}
