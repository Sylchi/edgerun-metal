#include "test_core_internal.h"

enum {
  TEST_SEAL_ROOT_KEY_SEED = 0x5au,
  TEST_SEAL_RECIPIENT_SEED = 0x20u,
  TEST_SEAL_OTHER_RECIPIENT_SEED = 0x40u
};

static void check_bytes_equal(const char* name,
                              const UINT8* actual,
                              const UINT8* expected,
                              UINTN len) {
  UINTN i;

  ++g_total;
  for (i = 0u; i < len; ++i) {
    if (actual[i] != expected[i]) {
      fprintf(stderr, "FAIL %s: byte %llu got 0x%02x expected 0x%02x\n",
              name, (unsigned long long)i, actual[i], expected[i]);
      ++g_failed;
      return;
    }
  }
}

static void test_sealed_content_object_format(void) {
  static const UINT8 aad_bytes[] = {'r', 'o', 'u', 't', 'e'};
  static const UINT8 plaintext_bytes[] = {'p', 'a', 'c', 'k', 'a', 'g', 'e'};
  ErCryptoProvider crypto;
  ErCryptoBlake3Sealer sealer;
  ErIdentity recipient;
  ErIdentity other_recipient;
  ErByteSpan aad;
  ErByteSpan plaintext;
  ErMutableBytes sealed_out;
  ErSealedContentObjectHeader header;
  UINT8 root_key[ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN];
  UINT8 recipient_key[ER_PUBLIC_KEY_LEN];
  UINT8 other_recipient_key[ER_PUBLIC_KEY_LEN];
  UINT8 sealed_bytes[128];
  UINT8 opened_bytes[64];

  test_fill_bytes(root_key, (UINTN)sizeof(root_key), TEST_SEAL_ROOT_KEY_SEED);
  check_int64("seal blake3 sealer init",
              er_crypto_blake3_sealer_init(&sealer, root_key), 1);
  er_crypto_blake3_sealing_provider(&sealer, &crypto);
  test_fill_bytes(recipient_key, (UINTN)sizeof(recipient_key),
                  TEST_SEAL_RECIPIENT_SEED);
  test_fill_bytes(other_recipient_key, (UINTN)sizeof(other_recipient_key),
                  TEST_SEAL_OTHER_RECIPIENT_SEED);
  check_int64("seal recipient identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  recipient_key,
                                  (UINT16)sizeof(recipient_key),
                                  &recipient),
              1);
  check_int64("seal other recipient identity",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_ED25519,
                                  other_recipient_key,
                                  (UINT16)sizeof(other_recipient_key),
                                  &other_recipient),
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
              ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH);
  check_uint64("seal content plaintext len", header.plaintext_len,
               (UINT64)sizeof(plaintext_bytes));
  check_uint64("seal content payload len", header.sealed_payload_len,
               (UINT64)(ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN +
                        sizeof(plaintext_bytes) +
                        ER_CRYPTO_BLAKE3_SEAL_TAG_LEN));
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
    check_bytes_equal("seal content opened bytes", opened_bytes,
                      plaintext_bytes, (UINTN)sizeof(plaintext_bytes));
    check_int64("seal content reject wrong recipient",
                er_crypto_open(&crypto, &other_recipient, &aad, &sealed_span,
                               &plaintext_out),
                0);
    aad.len = 0u;
    check_int64("seal content reject open aad mismatch",
                er_crypto_open(&crypto, &recipient, &aad, &sealed_span,
                               &plaintext_out),
                0);
    aad.len = (UINTN)sizeof(aad_bytes);
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
