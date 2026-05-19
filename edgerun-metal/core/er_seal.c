#include "er_seal.h"
#include "er_identity.h"
#include "er_mem.h"

static const UINT8 g_seal_plaintext_domain[] = "edgerun:c:v1:seal:plaintext";
static const UINT8 g_seal_aad_domain[] = "edgerun:c:v1:seal:aad";
static const UINT8 g_seal_payload_domain[] = "edgerun:c:v1:seal:payload";
static const UINT8 g_seal_object_domain[] = "edgerun:c:v1:seal:object";

enum {
  ER_SEAL_U16_FIELD_BYTES = 2u,
  ER_SEAL_U64_FIELD_BYTES = 8u,
  ER_SEAL_U16_HIGH_SHIFT = 8u,
  ER_SEAL_U64_SHIFT_56 = 56u,
  ER_SEAL_U64_SHIFT_48 = 48u,
  ER_SEAL_U64_SHIFT_40 = 40u,
  ER_SEAL_U64_SHIFT_32 = 32u,
  ER_SEAL_U64_SHIFT_24 = 24u,
  ER_SEAL_U64_SHIFT_16 = 16u,
  ER_SEAL_U64_SHIFT_8 = 8u,
  ER_SEAL_U8_MASK = 0xffu,
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
      (ER_SEAL_U64_FIELD_BYTES * ER_SEAL_OBJECT_U64_FIELD_COUNT)
};

static void er_seal_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> ER_SEAL_U16_HIGH_SHIFT) & ER_SEAL_U8_MASK);
  dst[1] = (UINT8)(value & ER_SEAL_U8_MASK);
}

static void er_seal_put_be64(UINT8* dst, UINT64 value) {
  dst[0] = (UINT8)((value >> ER_SEAL_U64_SHIFT_56) & ER_SEAL_U8_MASK);
  dst[1] = (UINT8)((value >> ER_SEAL_U64_SHIFT_48) & ER_SEAL_U8_MASK);
  dst[2] = (UINT8)((value >> ER_SEAL_U64_SHIFT_40) & ER_SEAL_U8_MASK);
  dst[3] = (UINT8)((value >> ER_SEAL_U64_SHIFT_32) & ER_SEAL_U8_MASK);
  dst[4] = (UINT8)((value >> ER_SEAL_U64_SHIFT_24) & ER_SEAL_U8_MASK);
  dst[5] = (UINT8)((value >> ER_SEAL_U64_SHIFT_16) & ER_SEAL_U8_MASK);
  dst[6] = (UINT8)((value >> ER_SEAL_U64_SHIFT_8) & ER_SEAL_U8_MASK);
  dst[7] = (UINT8)(value & ER_SEAL_U8_MASK);
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
  header.algorithm = ER_SEAL_ALGORITHM_AES256_GCM;
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
      header->algorithm != ER_SEAL_ALGORITHM_AES256_GCM ||
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
