#include "er_vfs.h"
#include "er_mem.h"

/*
 * Purpose: build content-addressed VFS object records from in-memory bytes.
 * Intention: files remain app-facing labels; wire/durable identity is sealed object data.
 */

static const UINT8 g_object_domain[] = "edgerun:c:v1:vfs:object";
static const UINT8 g_payload_domain[] = "edgerun:c:v1:vfs:object-payload";
static const UINT8 g_packet_domain[] = "edgerun:c:v1:vfs:object-packet";
static const UINT8 g_file_ref_domain[] = "edgerun:c:v1:vfs:file-ref";
static const UINT8 g_transform_domain[] = "edgerun:c:v1:vfs:object-transform";

enum {
  ER_VFS_U16_FIELD_BYTES = 2u,
  ER_VFS_U64_FIELD_BYTES = 8u,
  ER_VFS_TRANSFORM_U16_FIELD_COUNT = 2u,
  ER_VFS_TRANSFORM_U64_FIELD_COUNT = 2u,
  ER_VFS_TRANSFORM_FIELD_BYTES =
      (ER_VFS_U16_FIELD_BYTES * ER_VFS_TRANSFORM_U16_FIELD_COUNT) +
      (ER_VFS_U64_FIELD_BYTES * ER_VFS_TRANSFORM_U64_FIELD_COUNT)
};

static void er_vfs_put_be16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)((value >> 8) & 0xffu);
  dst[1] = (UINT8)(value & 0xffu);
}

static void er_vfs_put_be32(UINT8* dst, UINT32 value) {
  dst[0] = (UINT8)((value >> 24) & 0xffu);
  dst[1] = (UINT8)((value >> 16) & 0xffu);
  dst[2] = (UINT8)((value >> 8) & 0xffu);
  dst[3] = (UINT8)(value & 0xffu);
}

static void er_vfs_put_be64(UINT8* dst, UINT64 value) {
  er_vfs_put_be32(dst, (UINT32)(value >> 32));
  er_vfs_put_be32(dst + 4, (UINT32)(value & 0xffffffffu));
}

static void er_vfs_put_transform_field16(UINT8** cursor, UINT16 value) {
  er_vfs_put_be16(*cursor, value);
  *cursor += ER_VFS_U16_FIELD_BYTES;
}

static void er_vfs_put_transform_field64(UINT8** cursor, UINT64 value) {
  er_vfs_put_be64(*cursor, value);
  *cursor += ER_VFS_U64_FIELD_BYTES;
}

UINT8 er_vfs_path_label_valid(const char* path, UINTN path_len) {
  UINTN i;
  UINT8 last_was_slash = 0;

  if (path == 0 || path_len == 0u || path_len > ER_VFS_PATH_MAX) {
    return 0;
  }
  if (path[0] == '/' || path[path_len - 1u] == '/') {
    return 0;
  }
  for (i = 0; i < path_len; ++i) {
    char c = path[i];

    if (c == 0 || c == '\\') {
      return 0;
    }
    if (c == '/') {
      if (last_was_slash != 0u) {
        return 0;
      }
      last_was_slash = 1;
      continue;
    }
    if (c == '.') {
      UINT8 at_part_start = (i == 0u || path[i - 1u] == '/') ? 1u : 0u;
      UINT8 at_part_end = (i + 1u == path_len || path[i + 1u] == '/') ? 1u : 0u;
      UINT8 dotdot = (i + 1u < path_len && path[i + 1u] == '.' &&
                      (i + 2u == path_len || path[i + 2u] == '/')) ? 1u : 0u;

      if (at_part_start != 0u && (at_part_end != 0u || dotdot != 0u)) {
        return 0;
      }
    }
    last_was_slash = 0;
  }
  return 1;
}

static UINT8 er_vfs_hash_object(const ErCryptoProvider* crypto, const UINT8* object_bytes, UINTN object_len,
                                ErHash* out_hash) {
  ErByteSpan span;

  span.bytes = object_bytes;
  span.len = object_len;
  if (object_len > 0u && object_bytes == 0) {
    return 0;
  }
  return er_crypto_hash(crypto, g_object_domain, (UINTN)(sizeof(g_object_domain) - 1u), &span, 1u, out_hash);
}

UINT8 er_vfs_prepare_object_packet(const ErCryptoProvider* crypto, const UINT8* object_bytes, UINTN object_len,
                                   UINTN offset, UINT32 packet_index, UINT32 packet_count,
                                   ErVfsObjectPacket* out_packet) {
  UINTN remaining;
  UINTN chunk_len;
  UINT8 packet_preimage[2u + 4u + 4u + 8u + ER_HASH_LEN + ER_HASH_LEN];
  ErByteSpan payload_span;
  ErByteSpan packet_spans[1];

  if (out_packet == 0 || packet_count == 0u || packet_index >= packet_count) {
    return 0;
  }
  if (object_len > 0u && object_bytes == 0) {
    return 0;
  }
  if (offset > object_len) {
    return 0;
  }

  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  remaining = object_len - offset;
  chunk_len = remaining;
  if (chunk_len > ER_VFS_OBJECT_PACKET_BYTES) {
    chunk_len = ER_VFS_OBJECT_PACKET_BYTES;
  }
  if (chunk_len > 0u) {
    er_mem_copy(out_packet->bytes, object_bytes + offset, chunk_len);
  }

  out_packet->header.abi_version = ER_VFS_ABI_VERSION;
  out_packet->header.packet_index = (UINT16)packet_index;
  out_packet->header.packet_count = packet_count;
  out_packet->header.object_len = (UINT64)object_len;
  out_packet->header.offset = (UINT64)offset;
  out_packet->header.bytes_len = (UINT32)chunk_len;

  if (er_vfs_hash_object(crypto, object_bytes, object_len, &out_packet->header.object_id) == 0u) {
    return 0;
  }

  payload_span.bytes = out_packet->bytes;
  payload_span.len = chunk_len;
  if (er_crypto_hash(crypto, g_payload_domain, (UINTN)(sizeof(g_payload_domain) - 1u),
                     &payload_span, 1u, &out_packet->header.payload_hash) == 0u) {
    return 0;
  }

  er_vfs_put_be16(&packet_preimage[0], out_packet->header.abi_version);
  er_vfs_put_be32(&packet_preimage[2], packet_index);
  er_vfs_put_be32(&packet_preimage[6], packet_count);
  er_vfs_put_be64(&packet_preimage[10], out_packet->header.offset);
  er_mem_copy(&packet_preimage[18], out_packet->header.object_id.bytes, ER_HASH_LEN);
  er_mem_copy(&packet_preimage[18u + ER_HASH_LEN], out_packet->header.payload_hash.bytes, ER_HASH_LEN);
  packet_spans[0].bytes = packet_preimage;
  packet_spans[0].len = (UINTN)sizeof(packet_preimage);
  return er_crypto_hash(crypto, g_packet_domain, (UINTN)(sizeof(g_packet_domain) - 1u),
                        packet_spans, 1u, &out_packet->header.packet_id);
}

UINT8 er_vfs_prepare_file_ref(const ErCryptoProvider* crypto, const char* path, UINTN path_len,
                              const UINT8* object_bytes, UINTN object_len, ErVfsFileRef* out_ref) {
  UINT8 len_be[8];
  ErByteSpan spans[3];

  if (out_ref == 0 || er_vfs_path_label_valid(path, path_len) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)out_ref, (UINTN)sizeof(*out_ref));
  out_ref->abi_version = ER_VFS_ABI_VERSION;
  out_ref->path_len = (UINT16)path_len;
  er_mem_copy((UINT8*)out_ref->path, (const UINT8*)path, path_len);
  out_ref->object_len = (UINT64)object_len;
  if (er_vfs_hash_object(crypto, object_bytes, object_len, &out_ref->object_id) == 0u) {
    return 0;
  }

  er_vfs_put_be64(len_be, out_ref->object_len);
  spans[0].bytes = (const UINT8*)path;
  spans[0].len = path_len;
  spans[1].bytes = out_ref->object_id.bytes;
  spans[1].len = ER_HASH_LEN;
  spans[2].bytes = len_be;
  spans[2].len = (UINTN)sizeof(len_be);
  return er_crypto_hash(crypto, g_file_ref_domain, (UINTN)(sizeof(g_file_ref_domain) - 1u),
                        spans, 3u, &out_ref->file_hash);
}

UINT8 er_vfs_prepare_transform_ref(const ErCryptoProvider* crypto, const ErHash* plaintext_object_id,
                                   UINT64 plaintext_len, const ErHash* transport_object_id,
                                   UINT64 transport_len, UINT16 compression_kind, UINT16 seal_kind,
                                   ErVfsObjectTransformRef* out_ref) {
  UINT8 fields[ER_VFS_TRANSFORM_FIELD_BYTES];
  UINT8* field_cursor = fields;
  ErByteSpan spans[3];

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
  spans[0].bytes = plaintext_object_id->bytes;
  spans[0].len = ER_HASH_LEN;
  spans[1].bytes = transport_object_id->bytes;
  spans[1].len = ER_HASH_LEN;
  spans[2].bytes = fields;
  spans[2].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_transform_domain, (UINTN)(sizeof(g_transform_domain) - 1u),
                        spans, 3u, &out_ref->transform_hash);
}
