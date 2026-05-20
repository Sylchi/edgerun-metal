#include "er_seal.h"
#include "er_identity.h"
#include "er_mem.h"

static const UINT8 g_seal_plaintext_domain[] = "edgerun:c:v1:seal:plaintext";
static const UINT8 g_seal_aad_domain[] = "edgerun:c:v1:seal:aad";
static const UINT8 g_seal_payload_domain[] = "edgerun:c:v1:seal:payload";
static const UINT8 g_seal_object_domain[] = "edgerun:c:v1:seal:object";
static const UINT8 g_seal_content_key_domain[] = "edgerun:c:v1:seal:content-key";
static const UINT8 g_seal_key_wrap_domain[] = "edgerun:c:v1:seal:key-wrap";

enum {
  ER_SEAL_U16_FIELD_BYTES = 2u,
  ER_SEAL_U64_FIELD_BYTES = 8u,
  ER_SEAL_U8_BITS = 8u,
  ER_SEAL_U16_HIGH_SHIFT = 8u,
  ER_SEAL_U8_MASK = 0xffu,
  ER_SEAL_U16_MAX = 0xffffu,
  ER_SEAL_OBJECT_SPAN_COUNT = 7u,
  ER_SEAL_OBJECT_FIELDS_SPAN = 0u,
  ER_SEAL_OBJECT_RECIPIENT_SPAN = 1u,
  ER_SEAL_OBJECT_PLAINTEXT_ID_SPAN = 2u,
  ER_SEAL_OBJECT_AAD_HASH_SPAN = 3u,
  ER_SEAL_OBJECT_PAYLOAD_HASH_SPAN = 4u,
  ER_SEAL_OBJECT_SEALED_PAYLOAD_SPAN = 5u,
  ER_SEAL_OBJECT_RECIPIENT_MATERIAL_SPAN = 6u,
  ER_SEAL_OBJECT_U16_FIELD_COUNT = 4u,
  ER_SEAL_OBJECT_U64_FIELD_COUNT = 2u,
  ER_SEAL_OBJECT_FIELD_BYTES =
      (ER_SEAL_U16_FIELD_BYTES * ER_SEAL_OBJECT_U16_FIELD_COUNT) +
      (ER_SEAL_U64_FIELD_BYTES * ER_SEAL_OBJECT_U64_FIELD_COUNT),
  ER_SEAL_KEY_WRAP_SPAN_COUNT = 6u,
  ER_SEAL_KEY_WRAP_FIELDS_SPAN = 0u,
  ER_SEAL_KEY_WRAP_RECIPIENT_SPAN = 1u,
  ER_SEAL_KEY_WRAP_CONTENT_KEY_HASH_SPAN = 2u,
  ER_SEAL_KEY_WRAP_AAD_HASH_SPAN = 3u,
  ER_SEAL_KEY_WRAP_WRAPPED_KEY_HASH_SPAN = 4u,
  ER_SEAL_KEY_WRAP_WRAPPED_KEY_SPAN = 5u,
  ER_SEAL_KEY_WRAP_U16_FIELD_COUNT = 4u,
  ER_SEAL_KEY_WRAP_FIELD_BYTES =
      ER_SEAL_U16_FIELD_BYTES * ER_SEAL_KEY_WRAP_U16_FIELD_COUNT
};

static void er_seal_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> ER_SEAL_U16_HIGH_SHIFT) & ER_SEAL_U8_MASK);
  dst[1] = (UINT8)(value & ER_SEAL_U8_MASK);
}

static void er_seal_put_be64(UINT8* dst, UINT64 value) {
  UINTN i;
  UINT32 shift;

  for (i = 0u; i < ER_SEAL_U64_FIELD_BYTES; ++i) {
    shift = (UINT32)((ER_SEAL_U64_FIELD_BYTES - 1u - i) * ER_SEAL_U8_BITS);
    dst[i] = (UINT8)((value >> shift) & ER_SEAL_U8_MASK);
  }
}

static void er_seal_write_u16(UINT8** cursor, UINT16 value) {
  er_seal_put_be16(*cursor, value);
  *cursor += ER_SEAL_U16_FIELD_BYTES;
}

static void er_seal_write_u64(UINT8** cursor, UINT64 value) {
  er_seal_put_be64(*cursor, value);
  *cursor += ER_SEAL_U64_FIELD_BYTES;
}

static void er_seal_set_span(ErByteSpan* span, const UINT8* bytes, UINTN len) {
  span->bytes = bytes;
  span->len = len;
}

static UINT8 er_seal_hash_span(const ErCryptoProvider* crypto,
                               const UINT8* domain,
                               UINTN domain_len,
                               const UINT8* bytes,
                               UINTN len,
                               ErHash* out_hash) {
  ErByteSpan span;

  if (len > 0u && bytes == 0) {
    return 0u;
  }
  er_seal_set_span(&span, bytes, len);
  return er_crypto_hash(crypto, domain, domain_len, &span, 1u, out_hash);
}

static UINT8 er_seal_valid_strategy(UINT16 strategy) {
  switch (strategy) {
    case ER_SEAL_STRATEGY_DIRECT_RECIPIENT:
    case ER_SEAL_STRATEGY_CONTENT_KEY_WRAP:
      return 1u;
    case ER_SEAL_STRATEGY_INVALID:
    default:
      return 0u;
  }
}

static void er_seal_object_fields(const ErSealedContentObjectHeader* header,
                                  UINT8 fields[ER_SEAL_OBJECT_FIELD_BYTES]) {
  UINT8* cursor = fields;

  er_seal_write_u16(&cursor, header->abi_version);
  er_seal_write_u16(&cursor, header->strategy);
  er_seal_write_u16(&cursor, header->algorithm);
  er_seal_write_u16(&cursor, header->reserved);
  er_seal_write_u64(&cursor, header->plaintext_len);
  er_seal_write_u64(&cursor, header->sealed_payload_len);
}

static UINT8 er_seal_hash_object_id(const ErCryptoProvider* crypto,
                                    const ErSealedContentObjectHeader* header,
                                    const UINT8* sealed_payload,
                                    UINTN sealed_payload_len,
                                    ErHash* out_hash) {
  UINT8 fields[ER_SEAL_OBJECT_FIELD_BYTES];
  ErByteSpan spans[ER_SEAL_OBJECT_SPAN_COUNT];

  if (crypto == 0 || header == 0 || sealed_payload == 0 ||
      sealed_payload_len == 0u || out_hash == 0) {
    return 0u;
  }
  er_seal_object_fields(header, fields);
  er_seal_set_span(&spans[ER_SEAL_OBJECT_FIELDS_SPAN],
                   fields, (UINTN)sizeof(fields));
  er_seal_set_span(&spans[ER_SEAL_OBJECT_RECIPIENT_SPAN],
                   (const UINT8*)&header->recipient,
                   (UINTN)sizeof(header->recipient));
  er_seal_set_span(&spans[ER_SEAL_OBJECT_PLAINTEXT_ID_SPAN],
                   header->plaintext_object_id.bytes, ER_HASH_LEN);
  er_seal_set_span(&spans[ER_SEAL_OBJECT_AAD_HASH_SPAN],
                   header->aad_hash.bytes, ER_HASH_LEN);
  er_seal_set_span(&spans[ER_SEAL_OBJECT_PAYLOAD_HASH_SPAN],
                   header->sealed_payload_hash.bytes, ER_HASH_LEN);
  er_seal_set_span(&spans[ER_SEAL_OBJECT_SEALED_PAYLOAD_SPAN],
                   sealed_payload, sealed_payload_len);
  er_seal_set_span(&spans[ER_SEAL_OBJECT_RECIPIENT_MATERIAL_SPAN],
                   header->recipient.material, header->recipient.material_len);
  return er_crypto_hash(crypto, g_seal_object_domain,
                        (UINTN)(sizeof(g_seal_object_domain) - 1u),
                        spans, ER_SEAL_OBJECT_SPAN_COUNT, out_hash);
}

static void er_seal_key_wrap_fields(const ErSealedContentKeyWrap* wrap,
                                    UINT8 fields[ER_SEAL_KEY_WRAP_FIELD_BYTES]) {
  UINT8* cursor = fields;

  er_seal_write_u16(&cursor, wrap->abi_version);
  er_seal_write_u16(&cursor, wrap->algorithm);
  er_seal_write_u16(&cursor, wrap->reserved);
  er_seal_write_u16(&cursor, wrap->wrapped_key_len);
}

static UINT8 er_seal_hash_key_wrap_id(const ErCryptoProvider* crypto,
                                      const ErSealedContentKeyWrap* wrap,
                                      const UINT8* wrapped_key,
                                      UINTN wrapped_key_len,
                                      ErHash* out_hash) {
  UINT8 fields[ER_SEAL_KEY_WRAP_FIELD_BYTES];
  ErByteSpan spans[ER_SEAL_KEY_WRAP_SPAN_COUNT];

  if (crypto == 0 || wrap == 0 || wrapped_key == 0 ||
      wrapped_key_len == 0u || out_hash == 0) {
    return 0u;
  }
  er_seal_key_wrap_fields(wrap, fields);
  er_seal_set_span(&spans[ER_SEAL_KEY_WRAP_FIELDS_SPAN],
                   fields, (UINTN)sizeof(fields));
  er_seal_set_span(&spans[ER_SEAL_KEY_WRAP_RECIPIENT_SPAN],
                   (const UINT8*)&wrap->recipient,
                   (UINTN)sizeof(wrap->recipient));
  er_seal_set_span(&spans[ER_SEAL_KEY_WRAP_CONTENT_KEY_HASH_SPAN],
                   wrap->content_key_hash.bytes, ER_HASH_LEN);
  er_seal_set_span(&spans[ER_SEAL_KEY_WRAP_AAD_HASH_SPAN],
                   wrap->wrap_aad_hash.bytes, ER_HASH_LEN);
  er_seal_set_span(&spans[ER_SEAL_KEY_WRAP_WRAPPED_KEY_HASH_SPAN],
                   wrap->wrapped_key_hash.bytes, ER_HASH_LEN);
  er_seal_set_span(&spans[ER_SEAL_KEY_WRAP_WRAPPED_KEY_SPAN],
                   wrapped_key, wrapped_key_len);
  return er_crypto_hash(crypto, g_seal_key_wrap_domain,
                        (UINTN)(sizeof(g_seal_key_wrap_domain) - 1u),
                        spans, ER_SEAL_KEY_WRAP_SPAN_COUNT, out_hash);
}

ErSealStrategy er_seal_select_strategy(UINT32 recipient_count,
                                       UINT64 plaintext_len,
                                       UINT32 expected_reuse_count) {
  if (recipient_count == 0u || plaintext_len == 0u || expected_reuse_count == 0u) {
    return ER_SEAL_STRATEGY_INVALID;
  }

  if (recipient_count == ER_SEAL_RECIPIENT_COUNT_DIRECT &&
      plaintext_len < ER_SEAL_CONTENT_KEY_THRESHOLD_BYTES &&
      expected_reuse_count < ER_SEAL_CONTENT_KEY_REUSE_MIN) {
    return ER_SEAL_STRATEGY_DIRECT_RECIPIENT;
  }

  return ER_SEAL_STRATEGY_CONTENT_KEY_WRAP;
}

const char* er_seal_strategy_label(ErSealStrategy strategy) {
  switch (strategy) {
    case ER_SEAL_STRATEGY_DIRECT_RECIPIENT:
      return "direct-recipient";
    case ER_SEAL_STRATEGY_CONTENT_KEY_WRAP:
      return "content-key-wrap";
    case ER_SEAL_STRATEGY_INVALID:
    default:
      return "invalid";
  }
}

UINT8 er_seal_prepare_content_key(const UINT8 key_bytes[ER_SEAL_CONTENT_KEY_LEN],
                                  ErSealContentKey* out_key) {
  if (key_bytes == 0 || out_key == 0 ||
      er_mem_any_nonzero(key_bytes, ER_SEAL_CONTENT_KEY_LEN) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_key, (UINTN)sizeof(*out_key));
  er_mem_copy(out_key->bytes, key_bytes, ER_SEAL_CONTENT_KEY_LEN);
  return 1u;
}

UINT8 er_seal_prepare_content_object(const ErCryptoProvider* crypto,
                                     const ErIdentity* recipient,
                                     const ErByteSpan* aad,
                                     const ErByteSpan* plaintext,
                                     UINT32 expected_reuse_count,
                                     ErMutableBytes* sealed_out,
                                     ErSealedContentObjectHeader* out_header) {
  ErSealedContentObjectHeader header;
  ErHash object_id;

  if (crypto == 0 || recipient == 0 || aad == 0 || plaintext == 0 ||
      plaintext->bytes == 0 || plaintext->len == 0u ||
      sealed_out == 0 || out_header == 0 ||
      er_identity_valid(recipient) == 0u) {
    return 0u;
  }
  if (aad->len > 0u && aad->bytes == 0) {
    return 0u;
  }

  er_mem_zero((UINT8*)&header, (UINTN)sizeof(header));
  header.abi_version = ER_SEAL_ABI_VERSION;
  header.strategy = (UINT16)er_seal_select_strategy(ER_SEAL_RECIPIENT_COUNT_DIRECT,
                                                    (UINT64)plaintext->len,
                                                    expected_reuse_count);
  header.algorithm = ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH;
  header.recipient = *recipient;
  header.plaintext_len = (UINT64)plaintext->len;
  if (er_seal_valid_strategy(header.strategy) == 0u ||
      er_seal_hash_span(crypto, g_seal_plaintext_domain,
                        (UINTN)(sizeof(g_seal_plaintext_domain) - 1u),
                        plaintext->bytes, plaintext->len,
                        &header.plaintext_object_id) == 0u ||
      er_seal_hash_span(crypto, g_seal_aad_domain,
                        (UINTN)(sizeof(g_seal_aad_domain) - 1u),
                        aad->bytes, aad->len, &header.aad_hash) == 0u ||
      er_crypto_seal(crypto, recipient, aad, plaintext, sealed_out) == 0u ||
      sealed_out->len == 0u ||
      sealed_out->len > sealed_out->capacity ||
      er_seal_hash_span(crypto, g_seal_payload_domain,
                        (UINTN)(sizeof(g_seal_payload_domain) - 1u),
                        sealed_out->bytes, sealed_out->len,
                        &header.sealed_payload_hash) == 0u) {
    return 0u;
  }
  header.sealed_payload_len = (UINT64)sealed_out->len;
  if (er_seal_hash_object_id(crypto, &header, sealed_out->bytes,
                             sealed_out->len, &object_id) == 0u ||
      er_hash_nonzero(&object_id) == 0u) {
    return 0u;
  }
  header.sealed_object_id = object_id;
  *out_header = header;
  return 1u;
}

UINT8 er_seal_content_object_valid(const ErCryptoProvider* crypto,
                                   const ErSealedContentObjectHeader* header,
                                   const ErByteSpan* aad,
                                   const UINT8* sealed_payload,
                                   UINTN sealed_payload_len) {
  ErHash aad_hash;
  ErHash payload_hash;
  ErHash object_id;

  if (crypto == 0 || header == 0 || aad == 0 || sealed_payload == 0 ||
      sealed_payload_len == 0u ||
      header->abi_version != ER_SEAL_ABI_VERSION ||
      er_seal_valid_strategy(header->strategy) == 0u ||
      header->algorithm != ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH ||
      header->reserved != 0u ||
      header->plaintext_len == 0u ||
      header->sealed_payload_len != (UINT64)sealed_payload_len ||
      er_identity_valid(&header->recipient) == 0u ||
      er_hash_nonzero(&header->plaintext_object_id) == 0u ||
      er_hash_nonzero(&header->aad_hash) == 0u ||
      er_hash_nonzero(&header->sealed_payload_hash) == 0u ||
      er_hash_nonzero(&header->sealed_object_id) == 0u) {
    return 0u;
  }
  if (aad->len > 0u && aad->bytes == 0) {
    return 0u;
  }
  if (er_seal_hash_span(crypto, g_seal_aad_domain,
                        (UINTN)(sizeof(g_seal_aad_domain) - 1u),
                        aad->bytes, aad->len, &aad_hash) == 0u ||
      er_hash_equal(&aad_hash, &header->aad_hash) == 0u) {
    return 0u;
  }
  if (er_seal_hash_span(crypto, g_seal_payload_domain,
                        (UINTN)(sizeof(g_seal_payload_domain) - 1u),
                        sealed_payload, sealed_payload_len,
                        &payload_hash) == 0u ||
      er_hash_equal(&payload_hash, &header->sealed_payload_hash) == 0u) {
    return 0u;
  }
  if (er_seal_hash_object_id(crypto, header, sealed_payload,
                             sealed_payload_len, &object_id) == 0u) {
    return 0u;
  }
  return er_hash_equal(&object_id, &header->sealed_object_id);
}

UINT8 er_seal_wrap_content_key(const ErCryptoProvider* crypto,
                               const ErIdentity* recipient,
                               const ErByteSpan* wrap_aad,
                               const ErSealContentKey* content_key,
                               ErMutableBytes* wrapped_key_out,
                               ErSealedContentKeyWrap* out_wrap) {
  ErSealedContentKeyWrap wrap;
  ErByteSpan key_plaintext;
  ErHash wrap_id;

  if (crypto == 0 || recipient == 0 || wrap_aad == 0 ||
      content_key == 0 || wrapped_key_out == 0 || out_wrap == 0 ||
      er_identity_valid(recipient) == 0u ||
      er_mem_any_nonzero(content_key->bytes, ER_SEAL_CONTENT_KEY_LEN) == 0u) {
    return 0u;
  }
  if (wrap_aad->len > 0u && wrap_aad->bytes == 0) {
    return 0u;
  }

  er_mem_zero((UINT8*)&wrap, (UINTN)sizeof(wrap));
  wrap.abi_version = ER_SEAL_ABI_VERSION;
  wrap.algorithm = ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH;
  wrap.recipient = *recipient;
  key_plaintext.bytes = content_key->bytes;
  key_plaintext.len = ER_SEAL_CONTENT_KEY_LEN;
  if (er_seal_hash_span(crypto, g_seal_content_key_domain,
                        (UINTN)(sizeof(g_seal_content_key_domain) - 1u),
                        content_key->bytes, ER_SEAL_CONTENT_KEY_LEN,
                        &wrap.content_key_hash) == 0u ||
      er_seal_hash_span(crypto, g_seal_aad_domain,
                        (UINTN)(sizeof(g_seal_aad_domain) - 1u),
                        wrap_aad->bytes, wrap_aad->len,
                        &wrap.wrap_aad_hash) == 0u ||
      er_crypto_seal(crypto, recipient, wrap_aad, &key_plaintext,
                     wrapped_key_out) == 0u ||
      wrapped_key_out->len == 0u ||
      wrapped_key_out->len > wrapped_key_out->capacity ||
      wrapped_key_out->len > ER_SEAL_U16_MAX ||
      er_seal_hash_span(crypto, g_seal_payload_domain,
                        (UINTN)(sizeof(g_seal_payload_domain) - 1u),
                        wrapped_key_out->bytes, wrapped_key_out->len,
                        &wrap.wrapped_key_hash) == 0u) {
    return 0u;
  }
  wrap.wrapped_key_len = (UINT16)wrapped_key_out->len;
  if (er_seal_hash_key_wrap_id(crypto, &wrap, wrapped_key_out->bytes,
                               wrapped_key_out->len, &wrap_id) == 0u ||
      er_hash_nonzero(&wrap_id) == 0u) {
    return 0u;
  }
  wrap.wrap_id = wrap_id;
  *out_wrap = wrap;
  return 1u;
}

UINT8 er_seal_content_key_wrap_valid(const ErCryptoProvider* crypto,
                                     const ErSealedContentKeyWrap* wrap,
                                     const ErByteSpan* wrap_aad,
                                     const UINT8* wrapped_key,
                                     UINTN wrapped_key_len) {
  ErHash aad_hash;
  ErHash wrapped_key_hash;
  ErHash wrap_id;

  if (crypto == 0 || wrap == 0 || wrap_aad == 0 ||
      wrapped_key == 0 || wrapped_key_len == 0u ||
      wrapped_key_len > ER_SEAL_U16_MAX ||
      wrap->abi_version != ER_SEAL_ABI_VERSION ||
      wrap->algorithm != ER_SEAL_ALGORITHM_BLAKE3_STREAM_AUTH ||
      wrap->reserved != 0u ||
      wrap->wrapped_key_len != (UINT16)wrapped_key_len ||
      er_identity_valid(&wrap->recipient) == 0u ||
      er_hash_nonzero(&wrap->content_key_hash) == 0u ||
      er_hash_nonzero(&wrap->wrap_aad_hash) == 0u ||
      er_hash_nonzero(&wrap->wrapped_key_hash) == 0u ||
      er_hash_nonzero(&wrap->wrap_id) == 0u) {
    return 0u;
  }
  if (wrap_aad->len > 0u && wrap_aad->bytes == 0) {
    return 0u;
  }
  if (er_seal_hash_span(crypto, g_seal_aad_domain,
                        (UINTN)(sizeof(g_seal_aad_domain) - 1u),
                        wrap_aad->bytes, wrap_aad->len,
                        &aad_hash) == 0u ||
      er_hash_equal(&aad_hash, &wrap->wrap_aad_hash) == 0u) {
    return 0u;
  }
  if (er_seal_hash_span(crypto, g_seal_payload_domain,
                        (UINTN)(sizeof(g_seal_payload_domain) - 1u),
                        wrapped_key, wrapped_key_len,
                        &wrapped_key_hash) == 0u ||
      er_hash_equal(&wrapped_key_hash, &wrap->wrapped_key_hash) == 0u) {
    return 0u;
  }
  if (er_seal_hash_key_wrap_id(crypto, wrap, wrapped_key,
                               wrapped_key_len, &wrap_id) == 0u) {
    return 0u;
  }
  return er_hash_equal(&wrap_id, &wrap->wrap_id);
}

UINT8 er_seal_open_content_key(const ErCryptoProvider* crypto,
                               const ErSealedContentKeyWrap* wrap,
                               const ErByteSpan* wrap_aad,
                               const UINT8* wrapped_key,
                               UINTN wrapped_key_len,
                               ErSealContentKey* out_key) {
  UINT8 opened_key_bytes[ER_SEAL_CONTENT_KEY_LEN];
  ErByteSpan sealed_span;
  ErMutableBytes plaintext_out;
  ErHash content_key_hash;

  if (out_key == 0 ||
      er_seal_content_key_wrap_valid(crypto, wrap, wrap_aad, wrapped_key,
                                     wrapped_key_len) == 0u) {
    return 0u;
  }
  sealed_span.bytes = wrapped_key;
  sealed_span.len = wrapped_key_len;
  plaintext_out.bytes = opened_key_bytes;
  plaintext_out.len = 0u;
  plaintext_out.capacity = (UINTN)sizeof(opened_key_bytes);
  if (er_crypto_open(crypto, &wrap->recipient, wrap_aad, &sealed_span,
                     &plaintext_out) == 0u ||
      plaintext_out.len != ER_SEAL_CONTENT_KEY_LEN ||
      er_seal_hash_span(crypto, g_seal_content_key_domain,
                        (UINTN)(sizeof(g_seal_content_key_domain) - 1u),
                        opened_key_bytes, (UINTN)sizeof(opened_key_bytes),
                        &content_key_hash) == 0u ||
      er_hash_equal(&content_key_hash, &wrap->content_key_hash) == 0u) {
    return 0u;
  }
  return er_seal_prepare_content_key(opened_key_bytes, out_key);
}
