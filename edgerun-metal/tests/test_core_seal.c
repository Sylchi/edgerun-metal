#include "test_core_internal.h"

enum {
  TEST_SEAL_ROOT_KEY_SEED = 0x5au,
  TEST_SEAL_RECIPIENT_SEED = 0x20u,
  TEST_SEAL_OTHER_RECIPIENT_SEED = 0x40u,
  TEST_SEAL_CONTENT_KEY_SEED = 0x70u
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

static void test_sealed_content_record_format(void) {
  static const UINT8 aad_bytes[] = {'r', 'o', 'u', 't', 'e'};
  static const UINT8 plaintext_bytes[] = {'p', 'a', 'c', 'k', 'a', 'g', 'e'};
  ErCryptoProvider crypto;
  ErCryptoBlake3Sealer sealer;
  ErCredential recipient;
  ErCredential other_recipient;
  ErByteSpan aad;
  ErByteSpan plaintext;
  ErMutableBytes sealed_out;
  ErSealedContentRecordHeader header;
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
              er_credential_prepare(ER_CREDENTIAL_KIND_PUBLIC_KEY,
                                  ER_CREDENTIAL_BACKING_ED25519,
                                  recipient_key,
                                  (UINT16)sizeof(recipient_key),
                                  &recipient),
              1);
  check_int64("seal other recipient identity",
              er_credential_prepare(ER_CREDENTIAL_KIND_PUBLIC_KEY,
                                  ER_CREDENTIAL_BACKING_ED25519,
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

  check_int64("seal content record prepare",
              er_seal_prepare_content_record(&crypto, &recipient, &aad,
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
              er_seal_content_record_valid(&crypto, &header, &aad,
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
              er_seal_content_record_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              0);
  sealed_bytes[0] ^= 1u;
  header.reserved = 1u;
  check_int64("seal content reject reserved",
              er_seal_content_record_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              0);
  header.reserved = 0u;
  aad.len = 0u;
  check_int64("seal content reject aad mismatch",
              er_seal_content_record_valid(&crypto, &header, &aad,
                                           sealed_bytes, sealed_out.len),
              0);
}

static void test_sealed_content_key_wrap(void) {
  static const UINT8 wrap_aad_bytes[] = {'o', 'b', 'j', 'e', 'c', 't'};
  ErCryptoProvider crypto;
  ErCryptoBlake3Sealer sealer;
  ErCredential recipient;
  ErByteSpan wrap_aad;
  ErMutableBytes wrapped_key_out;
  ErSealedContentKeyWrap wrap;
  ErSealedContentKeyWrap tampered_wrap;
  ErSealContentKey content_key;
  ErSealContentKey opened_key;
  UINT8 root_key[ER_CRYPTO_BLAKE3_SEAL_ROOT_KEY_LEN];
  UINT8 recipient_key[ER_PUBLIC_KEY_LEN];
  UINT8 content_key_bytes[ER_SEAL_CONTENT_KEY_LEN];
  UINT8 wrapped_key[128];

  test_fill_bytes(root_key, (UINTN)sizeof(root_key), TEST_SEAL_ROOT_KEY_SEED);
  test_fill_bytes(recipient_key, (UINTN)sizeof(recipient_key),
                  TEST_SEAL_RECIPIENT_SEED);
  test_fill_bytes(content_key_bytes, (UINTN)sizeof(content_key_bytes),
                  TEST_SEAL_CONTENT_KEY_SEED);
  check_int64("seal wrap sealer init",
              er_crypto_blake3_sealer_init(&sealer, root_key), 1);
  er_crypto_blake3_sealing_provider(&sealer, &crypto);
  check_int64("seal wrap recipient identity",
              er_credential_prepare(ER_CREDENTIAL_KIND_PUBLIC_KEY,
                                  ER_CREDENTIAL_BACKING_ED25519,
                                  recipient_key,
                                  (UINT16)sizeof(recipient_key),
                                  &recipient),
              1);
  check_int64("seal prepare content key",
              er_seal_prepare_content_key(content_key_bytes, &content_key), 1);

  wrap_aad.bytes = wrap_aad_bytes;
  wrap_aad.len = (UINTN)sizeof(wrap_aad_bytes);
  wrapped_key_out.bytes = wrapped_key;
  wrapped_key_out.len = 0u;
  wrapped_key_out.capacity = (UINTN)sizeof(wrapped_key);
  check_int64("seal wrap content key",
              er_seal_wrap_content_key(&crypto, &recipient, &wrap_aad,
                                       &content_key, &wrapped_key_out,
                                       &wrap),
              1);
  check_int64("seal wrap abi", wrap.abi_version, ER_SEAL_ABI_VERSION);
  check_int64("seal wrap algorithm", wrap.algorithm,
              ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH);
  check_uint64("seal wrap len", wrap.wrapped_key_len,
               wrapped_key_out.len);
  check_int64("seal wrap valid",
              er_seal_content_key_wrap_valid(&crypto, &wrap, &wrap_aad,
                                             wrapped_key,
                                             wrapped_key_out.len),
              1);
  check_int64("seal open content key",
              er_seal_open_content_key(&crypto, &wrap, &wrap_aad,
                                       wrapped_key, wrapped_key_out.len,
                                       &opened_key),
              1);
  check_bytes_equal("seal opened content key", opened_key.bytes,
                    content_key.bytes, ER_SEAL_CONTENT_KEY_LEN);

  wrapped_key[ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN] ^= 1u;
  check_int64("seal wrap reject payload tamper",
              er_seal_content_key_wrap_valid(&crypto, &wrap, &wrap_aad,
                                             wrapped_key,
                                             wrapped_key_out.len),
              0);
  wrapped_key[ER_CRYPTO_BLAKE3_SEAL_HEADER_LEN] ^= 1u;
  tampered_wrap = wrap;
  tampered_wrap.reserved = 1u;
  check_int64("seal wrap reject reserved",
              er_seal_content_key_wrap_valid(&crypto, &tampered_wrap,
                                             &wrap_aad, wrapped_key,
                                             wrapped_key_out.len),
              0);
  wrap_aad.len = 0u;
  check_int64("seal wrap reject aad mismatch",
              er_seal_open_content_key(&crypto, &wrap, &wrap_aad,
                                       wrapped_key, wrapped_key_out.len,
                                       &opened_key),
              0);
}
