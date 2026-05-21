#include "er_vfs.h"
#include "er_mem.h"

_Static_assert(sizeof(ErVfsObjectPacketHeader) ==
               ER_VFS_OBJECT_PACKET_HEADER_BYTES,
               "VFS object packet header wire size must stay stable");

/*
 * Purpose: build VFS packet records from canonical object bytes.
 * Intention: labels remain app-facing names while object identity comes from
 * edgerun-object, not a VFS-private hash domain.
 */

static const UINT8 g_payload_domain[] = "edgerun:c:v1:vfs:object-payload";
static const UINT8 g_packet_domain[] = "edgerun:c:v1:vfs:object-packet";
static const UINT8 g_manifest_ref_domain[] = "edgerun:c:v1:vfs:object-label";
static const UINT8 g_transform_domain[] = "edgerun:c:v1:vfs:object-transform";

enum {
  ER_VFS_U16_FIELD_BYTES = 2u,
  ER_VFS_U32_FIELD_BYTES = 4u,
  ER_VFS_U64_FIELD_BYTES = 8u,
  ER_VFS_U16_HIGH_SHIFT = 8u,
  ER_VFS_U32_HIGH24_SHIFT = 24u,
  ER_VFS_U32_HIGH16_SHIFT = 16u,
  ER_VFS_U64_HIGH32_SHIFT = 32u,
  ER_VFS_BE_BYTE0 = 0u,
  ER_VFS_BE_BYTE1 = 1u,
  ER_VFS_BE_BYTE2 = 2u,
  ER_VFS_BE_BYTE3 = 3u,
  ER_VFS_U8_MASK = 0xffu,
  ER_VFS_U32_MASK = 0xffffffffu,
  ER_VFS_PACKET_INDEX_MAX = 0xffffu,
  ER_VFS_PACKET_COUNT_MAX = 0x10000u,
  ER_VFS_LABEL_REF_SPAN_COUNT = 3u,
  ER_VFS_LABEL_REF_LABEL_SPAN = 0u,
  ER_VFS_LABEL_REF_OBJECT_ID_SPAN = 1u,
  ER_VFS_LABEL_REF_OBJECT_LEN_SPAN = 2u,
  ER_VFS_TRANSFORM_REF_SPAN_COUNT = 3u,
  ER_VFS_TRANSFORM_PLAINTEXT_ID_SPAN = 0u,
  ER_VFS_TRANSFORM_TRANSPORT_ID_SPAN = 1u,
  ER_VFS_TRANSFORM_FIELDS_SPAN = 2u,
  ER_VFS_TRANSFORM_U16_FIELD_COUNT = 2u,
  ER_VFS_TRANSFORM_U64_FIELD_COUNT = 2u,
  ER_VFS_TRANSFORM_FIELD_BYTES =
      (ER_VFS_U16_FIELD_BYTES * ER_VFS_TRANSFORM_U16_FIELD_COUNT) +
      (ER_VFS_U64_FIELD_BYTES * ER_VFS_TRANSFORM_U64_FIELD_COUNT),
  ER_VFS_PACKET_ABI_OFFSET = 0u,
  ER_VFS_PACKET_INDEX_OFFSET = ER_VFS_PACKET_ABI_OFFSET + ER_VFS_U16_FIELD_BYTES,
  ER_VFS_PACKET_COUNT_OFFSET = ER_VFS_PACKET_INDEX_OFFSET + ER_VFS_U32_FIELD_BYTES,
  ER_VFS_PACKET_OBJECT_OFFSET_OFFSET = ER_VFS_PACKET_COUNT_OFFSET + ER_VFS_U32_FIELD_BYTES,
  ER_VFS_PACKET_OBJECT_ID_OFFSET = ER_VFS_PACKET_OBJECT_OFFSET_OFFSET + ER_VFS_U64_FIELD_BYTES,
  ER_VFS_PACKET_PAYLOAD_HASH_OFFSET = ER_VFS_PACKET_OBJECT_ID_OFFSET + ER_HASH_LEN,
  ER_VFS_PACKET_PREIMAGE_BYTES = ER_VFS_PACKET_PAYLOAD_HASH_OFFSET + ER_HASH_LEN
};

static void er_vfs_put_be16(UINT8* dst, UINT16 value) {
  dst[ER_VFS_BE_BYTE0] = (UINT8)((value >> ER_VFS_U16_HIGH_SHIFT) & ER_VFS_U8_MASK);
  dst[ER_VFS_BE_BYTE1] = (UINT8)(value & ER_VFS_U8_MASK);
}

static void er_vfs_put_be32(UINT8* dst, UINT32 value) {
  dst[ER_VFS_BE_BYTE0] = (UINT8)((value >> ER_VFS_U32_HIGH24_SHIFT) & ER_VFS_U8_MASK);
  dst[ER_VFS_BE_BYTE1] = (UINT8)((value >> ER_VFS_U32_HIGH16_SHIFT) & ER_VFS_U8_MASK);
  dst[ER_VFS_BE_BYTE2] = (UINT8)((value >> ER_VFS_U16_HIGH_SHIFT) & ER_VFS_U8_MASK);
  dst[ER_VFS_BE_BYTE3] = (UINT8)(value & ER_VFS_U8_MASK);
}

static void er_vfs_put_be64(UINT8* dst, UINT64 value) {
  er_vfs_put_be32(dst, (UINT32)(value >> ER_VFS_U64_HIGH32_SHIFT));
  er_vfs_put_be32(dst + ER_VFS_U32_FIELD_BYTES, (UINT32)(value & ER_VFS_U32_MASK));
}

static void er_vfs_put_transform_field16(UINT8** cursor, UINT16 value) {
  er_vfs_put_be16(*cursor, value);
  *cursor += ER_VFS_U16_FIELD_BYTES;
}

static void er_vfs_put_transform_field64(UINT8** cursor, UINT64 value) {
  er_vfs_put_be64(*cursor, value);
  *cursor += ER_VFS_U64_FIELD_BYTES;
}

static void er_vfs_set_span(ErByteSpan* span, const UINT8* bytes, UINTN len) {
  span->bytes = bytes;
  span->len = len;
}

static UINT8 er_vfs_char_is_slash(char value) {
  return (UINT8)(value == '/' ? 1u : 0u);
}

UINT8 er_vfs_label_valid(const char* label, UINTN label_len) {
  UINTN i;
  UINT8 last_was_slash = 0;

  if (label == 0 || label_len == 0u || label_len > ER_VFS_LABEL_MAX) {
    return 0;
  }
  if (er_vfs_char_is_slash(*label) != 0u ||
      er_vfs_char_is_slash(*(label + label_len - 1u)) != 0u) {
    return 0;
  }
  for (i = 0; i < label_len; ++i) {
    const char* label_at = label + i;
    char c = *label_at;

    if (c == 0 || c == '\\') {
      return 0;
    }
    if (er_vfs_char_is_slash(c) != 0u) {
      if (last_was_slash != 0u) {
        return 0;
      }
      last_was_slash = 1;
      continue;
    }
    if (c == '.') {
      UINT8 at_part_start = (i == 0u || er_vfs_char_is_slash(*(label_at - 1u)) != 0u) ? 1u : 0u;
      UINT8 at_part_end = (i + 1u == label_len || er_vfs_char_is_slash(*(label_at + 1u)) != 0u) ? 1u : 0u;
      UINT8 dotdot = (i + 1u < label_len && *(label_at + 1u) == '.' &&
                      (i + 2u == label_len || er_vfs_char_is_slash(*(label_at + 2u)) != 0u)) ? 1u : 0u;

      if (at_part_start != 0u && (at_part_end != 0u || dotdot != 0u)) {
        return 0;
      }
    }
    last_was_slash = 0;
  }
  return 1;
}

static UINT8 er_vfs_canonical_object_id(const UINT8* object_bytes,
                                        UINTN object_len,
                                        ErHash* out_hash) {
  er_object_info_t info;

  if (out_hash == 0 || (object_len > 0u && object_bytes == 0)) {
    return 0;
  }
  if (er_object_verify(object_bytes, (size_t)object_len, &info) !=
      ER_OBJECT_OK) {
    return 0;
  }
  er_mem_copy(out_hash->bytes, info.object_id, ER_HASH_LEN);
  return 1;
}

static UINT8 er_vfs_hash_payload(const ErCryptoProvider* crypto, const UINT8* payload_bytes,
                                 UINTN payload_len, ErHash* out_hash) {
  ErByteSpan payload_span;

  if (payload_len > 0u && payload_bytes == 0) {
    return 0;
  }
  payload_span.bytes = payload_bytes;
  payload_span.len = payload_len;
  return er_crypto_hash(crypto, g_payload_domain, (UINTN)(sizeof(g_payload_domain) - 1u),
                        &payload_span, 1u, out_hash);
}

static UINT8 er_vfs_hash_packet_id(const ErCryptoProvider* crypto, UINT16 abi_version,
                                   UINT32 packet_index, UINT32 packet_count,
                                   UINT64 offset, const ErHash* object_id,
                                   const ErHash* payload_hash, ErHash* out_hash) {
  UINT8 packet_preimage[ER_VFS_PACKET_PREIMAGE_BYTES];
  ErByteSpan packet_span;

  if (object_id == 0 || payload_hash == 0 || out_hash == 0) {
    return 0;
  }
  er_vfs_put_be16(&packet_preimage[ER_VFS_PACKET_ABI_OFFSET], abi_version);
  er_vfs_put_be32(&packet_preimage[ER_VFS_PACKET_INDEX_OFFSET], packet_index);
  er_vfs_put_be32(&packet_preimage[ER_VFS_PACKET_COUNT_OFFSET], packet_count);
  er_vfs_put_be64(&packet_preimage[ER_VFS_PACKET_OBJECT_OFFSET_OFFSET], offset);
  er_mem_copy(&packet_preimage[ER_VFS_PACKET_OBJECT_ID_OFFSET], object_id->bytes, ER_HASH_LEN);
  er_mem_copy(&packet_preimage[ER_VFS_PACKET_PAYLOAD_HASH_OFFSET], payload_hash->bytes, ER_HASH_LEN);
  er_vfs_set_span(&packet_span, packet_preimage, (UINTN)sizeof(packet_preimage));
  return er_crypto_hash(crypto, g_packet_domain, (UINTN)(sizeof(g_packet_domain) - 1u),
                        &packet_span, 1u, out_hash);
}

static UINT32 er_vfs_expected_packet_bytes(UINT64 object_len, UINT32 packet_index) {
  UINT64 offset = (UINT64)packet_index * (UINT64)ER_VFS_OBJECT_PACKET_BYTES;
  UINT64 remaining;

  if (offset >= object_len) {
    return 0u;
  }
  remaining = object_len - offset;
  if (remaining > ER_VFS_OBJECT_PACKET_BYTES) {
    return ER_VFS_OBJECT_PACKET_BYTES;
  }
  return (UINT32)remaining;
}

static UINT32 er_vfs_expected_packet_count(UINT64 object_len) {
  UINT64 full_packets = object_len / ER_VFS_OBJECT_PACKET_BYTES;
  UINT64 remainder = object_len % ER_VFS_OBJECT_PACKET_BYTES;

  if (object_len == 0u) {
    return 1u;
  }
  return (UINT32)(full_packets + (remainder == 0u ? 0u : 1u));
}

static UINT8 er_vfs_object_packet_matches(const ErCryptoProvider* crypto,
                                          const ErVfsObjectPacket* packet,
                                          const ErHash* object_id,
                                          UINT64 object_len,
                                          UINT32 packet_count,
                                          UINT32 packet_index) {
  UINT64 expected_offset;
  UINT32 expected_bytes;
  ErHash expected_payload_hash;
  ErHash expected_packet_id;

  if (crypto == 0 || packet == 0 || object_id == 0 ||
      object_len == 0u ||
      packet_count == 0u ||
      packet_count > ER_VFS_PACKET_COUNT_MAX ||
      packet_index >= packet_count ||
      packet_index > ER_VFS_PACKET_INDEX_MAX ||
      packet->header.abi_version != ER_VFS_ABI_VERSION ||
      packet->header.packet_index != (UINT16)packet_index ||
      packet->header.packet_count != packet_count ||
      packet->header.object_len != object_len ||
      packet->header.bytes_len > ER_VFS_OBJECT_PACKET_BYTES ||
      er_hash_equal(&packet->header.object_id, object_id) == 0u ||
      er_hash_nonzero(&packet->header.payload_hash) == 0u ||
      er_hash_nonzero(&packet->header.packet_id) == 0u) {
    return 0u;
  }
  expected_offset = (UINT64)packet_index * (UINT64)ER_VFS_OBJECT_PACKET_BYTES;
  expected_bytes = er_vfs_expected_packet_bytes(object_len, packet_index);
  if (packet->header.offset != expected_offset ||
      packet->header.bytes_len != expected_bytes) {
    return 0u;
  }
  if (er_vfs_hash_payload(crypto, packet->bytes, packet->header.bytes_len,
                          &expected_payload_hash) == 0u ||
      er_hash_equal(&expected_payload_hash,
                    &packet->header.payload_hash) == 0u) {
    return 0u;
  }
  if (er_vfs_hash_packet_id(crypto, packet->header.abi_version,
                            packet->header.packet_index,
                            packet->header.packet_count,
                            packet->header.offset,
                            &packet->header.object_id,
                            &packet->header.payload_hash,
                            &expected_packet_id) == 0u ||
      er_hash_equal(&expected_packet_id,
                    &packet->header.packet_id) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_vfs_prepare_object_packet(const ErCryptoProvider* crypto,
                                   const UINT8* canonical_object_bytes,
                                   UINTN canonical_object_len,
                                   UINTN offset, UINT32 packet_index, UINT32 packet_count,
                                   ErVfsObjectPacket* out_packet) {
  UINTN remaining;
  UINTN chunk_len;

  if (out_packet == 0 || packet_count == 0u ||
      packet_count > ER_VFS_PACKET_COUNT_MAX ||
      packet_index >= packet_count ||
      packet_index > ER_VFS_PACKET_INDEX_MAX) {
    return 0;
  }
  if (canonical_object_len > 0u && canonical_object_bytes == 0) {
    return 0;
  }
  if (offset > canonical_object_len) {
    return 0;
  }

  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  remaining = canonical_object_len - offset;
  chunk_len = remaining;
  if (chunk_len > ER_VFS_OBJECT_PACKET_BYTES) {
    chunk_len = ER_VFS_OBJECT_PACKET_BYTES;
  }
  if (chunk_len > 0u) {
    er_mem_copy(out_packet->bytes, canonical_object_bytes + offset, chunk_len);
  }

  out_packet->header.abi_version = ER_VFS_ABI_VERSION;
  out_packet->header.packet_index = (UINT16)packet_index;
  out_packet->header.packet_count = packet_count;
  out_packet->header.object_len = (UINT64)canonical_object_len;
  out_packet->header.offset = (UINT64)offset;
  out_packet->header.bytes_len = (UINT32)chunk_len;

  if (er_vfs_canonical_object_id(canonical_object_bytes, canonical_object_len,
                                 &out_packet->header.object_id) == 0u) {
    return 0;
  }

  if (er_vfs_hash_payload(crypto, out_packet->bytes, chunk_len,
                          &out_packet->header.payload_hash) == 0u) {
    return 0;
  }

  return er_vfs_hash_packet_id(crypto, out_packet->header.abi_version, packet_index,
                               packet_count, out_packet->header.offset,
                               &out_packet->header.object_id,
                               &out_packet->header.payload_hash,
                               &out_packet->header.packet_id);
}

UINT8 er_vfs_object_packet_valid(const ErCryptoProvider* crypto,
                                 const ErVfsObjectPacket* packet) {
  if (packet == 0 || er_hash_nonzero(&packet->header.object_id) == 0u) {
    return 0u;
  }
  return er_vfs_object_packet_matches(crypto, packet,
                                      &packet->header.object_id,
                                      packet->header.object_len,
                                      packet->header.packet_count,
                                      packet->header.packet_index);
}

UINT8 er_vfs_assemble_object_packets(const ErCryptoProvider* crypto,
                                     const ErVfsObjectPacket* packets,
                                     UINT32 packet_count,
                                     UINT8* out_object_bytes,
                                     UINTN out_object_capacity,
                                     UINTN* out_object_len,
                                     ErHash* out_object_id) {
  UINT32 i;
  UINT64 object_len;
  ErHash object_id;

  if (crypto == 0 || packets == 0 || packet_count == 0u ||
      packet_count > ER_VFS_PACKET_COUNT_MAX ||
      out_object_bytes == 0 || out_object_len == 0 || out_object_id == 0) {
    return 0;
  }
  object_len = packets[0].header.object_len;
  object_id = packets[0].header.object_id;
  if (object_len > (UINT64)out_object_capacity ||
      object_len > (UINT64)((UINTN)packet_count * ER_VFS_OBJECT_PACKET_BYTES)) {
    return 0;
  }
  if (packet_count != er_vfs_expected_packet_count(object_len)) {
    return 0;
  }

  for (i = 0u; i < packet_count; ++i) {
    const ErVfsObjectPacket* packet = &packets[i];
    UINT64 expected_offset = (UINT64)i * (UINT64)ER_VFS_OBJECT_PACKET_BYTES;

    if (er_vfs_object_packet_matches(crypto, packet, &object_id, object_len,
                                     packet_count, i) == 0u) {
      return 0;
    }
    if (packet->header.bytes_len != 0u) {
      er_mem_copy(out_object_bytes + expected_offset, packet->bytes,
                  packet->header.bytes_len);
    }
  }
  if (er_vfs_canonical_object_id(out_object_bytes, (UINTN)object_len,
                                 out_object_id) == 0u ||
      er_hash_equal(out_object_id, &object_id) == 0u) {
    return 0;
  }
  *out_object_len = (UINTN)object_len;
  return 1;
}

UINT8 er_vfs_prepare_object_ref_from_object(const ErHash* object_id,
                                            UINT64 object_len,
                                            ErVfsObjectRef* out_ref) {
  if (object_id == 0 || out_ref == 0 || object_len == 0u ||
      er_hash_nonzero(object_id) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)out_ref, (UINTN)sizeof(*out_ref));
  out_ref->abi_version = ER_VFS_ABI_VERSION;
  out_ref->object_id = *object_id;
  out_ref->object_len = object_len;
  return 1;
}

UINT8 er_vfs_prepare_object_ref(const ErCryptoProvider* crypto,
                                const UINT8* canonical_object_bytes,
                                UINTN canonical_object_len,
                                ErVfsObjectRef* out_ref) {
  ErHash object_id;

  (void)crypto;
  if (er_vfs_canonical_object_id(canonical_object_bytes,
                                 canonical_object_len,
                                 &object_id) == 0u) {
    return 0;
  }
  return er_vfs_prepare_object_ref_from_object(&object_id,
                                               (UINT64)canonical_object_len,
                                               out_ref);
}

UINT8 er_vfs_prepare_object_label_ref(const ErCryptoProvider* crypto, const char* label, UINTN label_len,
                                      const UINT8* canonical_object_bytes,
                                      UINTN canonical_object_len,
                                      ErVfsObjectLabelRef* out_ref) {
  ErHash object_id;

  if (er_vfs_canonical_object_id(canonical_object_bytes,
                                 canonical_object_len,
                                 &object_id) == 0u) {
    return 0;
  }
  return er_vfs_prepare_object_label_ref_from_object(crypto, label, label_len, &object_id,
                                                    (UINT64)canonical_object_len, out_ref);
}

UINT8 er_vfs_prepare_object_label_ref_from_object(const ErCryptoProvider* crypto, const char* label,
                                                  UINTN label_len, const ErHash* object_id,
                                                  UINT64 object_len, ErVfsObjectLabelRef* out_ref) {
  UINT8 len_be[8];
  ErByteSpan spans[ER_VFS_LABEL_REF_SPAN_COUNT];
  const UINT8* manifest_bytes;
  UINTN manifest_len;

  if (out_ref == 0 || crypto == 0 || object_id == 0 || er_vfs_label_valid(label, label_len) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)out_ref, (UINTN)sizeof(*out_ref));
  out_ref->abi_version = ER_VFS_ABI_VERSION;
  out_ref->label_len = (UINT16)label_len;
  er_mem_copy((UINT8*)out_ref->label, (const UINT8*)label, label_len);
  out_ref->object_id = *object_id;
  out_ref->object_len = object_len;

  er_vfs_put_be64(len_be, out_ref->object_len);
  manifest_bytes = (const UINT8*)label;
  manifest_len = label_len;
  er_vfs_set_span(&spans[ER_VFS_LABEL_REF_LABEL_SPAN], manifest_bytes, manifest_len);
  er_vfs_set_span(&spans[ER_VFS_LABEL_REF_OBJECT_ID_SPAN], out_ref->object_id.bytes, ER_HASH_LEN);
  er_vfs_set_span(&spans[ER_VFS_LABEL_REF_OBJECT_LEN_SPAN], len_be, (UINTN)sizeof(len_be));
  return er_crypto_hash(crypto, g_manifest_ref_domain, (UINTN)(sizeof(g_manifest_ref_domain) - 1u),
                        spans, ER_VFS_LABEL_REF_SPAN_COUNT, &out_ref->label_hash);
}

UINT8 er_vfs_prepare_transform_ref(const ErCryptoProvider* crypto, const ErHash* plaintext_object_id,
                                   UINT64 plaintext_len, const ErHash* transport_object_id,
                                   UINT64 transport_len, UINT16 compression_kind, UINT16 seal_kind,
                                   ErVfsObjectTransformRef* out_ref) {
  UINT8 fields[ER_VFS_TRANSFORM_FIELD_BYTES];
  UINT8* field_cursor = fields;
  ErByteSpan spans[ER_VFS_TRANSFORM_REF_SPAN_COUNT];

  if (out_ref == 0 || crypto == 0 || plaintext_object_id == 0 || transport_object_id == 0) {
    return 0;
  }
  if (seal_kind == ER_VFS_SEAL_NONE) {
    return 0;
  }

  er_mem_zero((UINT8*)out_ref, (UINTN)sizeof(*out_ref));
  out_ref->abi_version = ER_VFS_ABI_VERSION;
  out_ref->compression_kind = compression_kind;
  out_ref->seal_kind = seal_kind;
  out_ref->plaintext_object_id = *plaintext_object_id;
  out_ref->plaintext_len = plaintext_len;
  out_ref->transport_object_id = *transport_object_id;
  out_ref->transport_len = transport_len;

  er_vfs_put_transform_field16(&field_cursor, compression_kind);
  er_vfs_put_transform_field16(&field_cursor, seal_kind);
  er_vfs_put_transform_field64(&field_cursor, plaintext_len);
  er_vfs_put_transform_field64(&field_cursor, transport_len);
  er_vfs_set_span(&spans[ER_VFS_TRANSFORM_PLAINTEXT_ID_SPAN], plaintext_object_id->bytes, ER_HASH_LEN);
  er_vfs_set_span(&spans[ER_VFS_TRANSFORM_TRANSPORT_ID_SPAN], transport_object_id->bytes, ER_HASH_LEN);
  er_vfs_set_span(&spans[ER_VFS_TRANSFORM_FIELDS_SPAN], fields, (UINTN)sizeof(fields));
  return er_crypto_hash(crypto, g_transform_domain, (UINTN)(sizeof(g_transform_domain) - 1u),
                        spans, ER_VFS_TRANSFORM_REF_SPAN_COUNT, &out_ref->transform_hash);
}
