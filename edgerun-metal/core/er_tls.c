#include "er_tls.h"

#include "er_mem.h"

#define ER_TLS_RECORD_HANDSHAKE 22u
#define ER_TLS_RECORD_HEADER_BYTES 5u
#define ER_TLS_RECORD_VERSION 0x0303u
#define ER_TLS_HANDSHAKE_CLIENT_HELLO 1u
#define ER_TLS_HANDSHAKE_SERVER_HELLO 2u
#define ER_TLS_VERSION_1_3 0x0304u
#define ER_TLS_CIPHER_TLS_AES_128_GCM_SHA256 0x1301u
#define ER_TLS_EXTENSION_SERVER_NAME 0x0000u
#define ER_TLS_EXTENSION_SUPPORTED_GROUPS 0x000au
#define ER_TLS_EXTENSION_SIGNATURE_ALGORITHMS 0x000du
#define ER_TLS_EXTENSION_SUPPORTED_VERSIONS 0x002bu
#define ER_TLS_EXTENSION_KEY_SHARE 0x0033u
#define ER_TLS_NAMED_GROUP_SECP256R1 0x0017u
#define ER_TLS_SIGNATURE_ECDSA_SECP256R1_SHA256 0x0403u
#define ER_TLS_HOST_NAME_TYPE 0u
#define ER_TLS_NULL_COMPRESSION_BYTES 2u
#define ER_TLS_U24_MAX 0x00ffffffu
#define ER_TLS_SEC1_UNCOMPRESSED 0x04u

typedef struct {
  UINT8* bytes;
  UINT16 capacity;
  UINT16 len;
} ErTlsWriter;

static UINT16 er_tls_read_u16(const UINT8* bytes) {
  return (UINT16)(((UINT16)bytes[0] << 8u) | (UINT16)bytes[1]);
}

static UINT32 er_tls_read_u24(const UINT8* bytes) {
  return ((UINT32)bytes[0] << 16u) | ((UINT32)bytes[1] << 8u) | (UINT32)bytes[2];
}

static UINT8 er_tls_write_bytes(ErTlsWriter* writer, const UINT8* bytes, UINT16 len) {
  if (writer == 0 || bytes == 0 || len > writer->capacity || writer->len > writer->capacity - len) {
    return 0u;
  }
  er_mem_copy(writer->bytes + writer->len, bytes, len);
  writer->len = (UINT16)(writer->len + len);
  return 1u;
}

static UINT8 er_tls_write_u8(ErTlsWriter* writer, UINT8 value) {
  return er_tls_write_bytes(writer, &value, 1u);
}

static UINT8 er_tls_write_u16(ErTlsWriter* writer, UINT16 value) {
  UINT8 bytes[2];
  bytes[0] = (UINT8)((value >> 8u) & 0xffu);
  bytes[1] = (UINT8)(value & 0xffu);
  return er_tls_write_bytes(writer, bytes, (UINT16)sizeof(bytes));
}

static UINT8 er_tls_write_u24(ErTlsWriter* writer, UINT32 value) {
  UINT8 bytes[3];
  if (value > ER_TLS_U24_MAX) {
    return 0u;
  }
  bytes[0] = (UINT8)((value >> 16u) & 0xffu);
  bytes[1] = (UINT8)((value >> 8u) & 0xffu);
  bytes[2] = (UINT8)(value & 0xffu);
  return er_tls_write_bytes(writer, bytes, (UINT16)sizeof(bytes));
}

static UINT8 er_tls_patch_u16(ErTlsWriter* writer, UINT16 offset, UINT16 value) {
  if (writer == 0 || offset > writer->len || writer->len - offset < 2u) {
    return 0u;
  }
  writer->bytes[offset] = (UINT8)((value >> 8u) & 0xffu);
  writer->bytes[offset + 1u] = (UINT8)(value & 0xffu);
  return 1u;
}

static UINT8 er_tls_patch_u24(ErTlsWriter* writer, UINT16 offset, UINT32 value) {
  if (writer == 0 || value > ER_TLS_U24_MAX || offset > writer->len || writer->len - offset < 3u) {
    return 0u;
  }
  writer->bytes[offset] = (UINT8)((value >> 16u) & 0xffu);
  writer->bytes[offset + 1u] = (UINT8)((value >> 8u) & 0xffu);
  writer->bytes[offset + 2u] = (UINT8)(value & 0xffu);
  return 1u;
}

static UINT8 er_tls_host_valid(const UINT8* host, UINT16 host_len) {
  UINT16 i;

  if (host == 0 || host_len == 0u) {
    return 0u;
  }
  for (i = 0u; i < host_len; ++i) {
    UINT8 c = host[i];
    if (!((c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') ||
          c == '.' ||
          c == '-')) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_tls_write_extension_header(ErTlsWriter* writer,
                                           UINT16 extension_type,
                                           UINT16 extension_len) {
  return (UINT8)(er_tls_write_u16(writer, extension_type) != 0u &&
                 er_tls_write_u16(writer, extension_len) != 0u);
}

static UINT8 er_tls_write_sni_extension(ErTlsWriter* writer,
                                        const UINT8* host,
                                        UINT16 host_len) {
  UINT16 extension_len = (UINT16)(2u + 1u + 2u + host_len);
  UINT16 list_len = (UINT16)(1u + 2u + host_len);

  return (UINT8)(er_tls_write_extension_header(writer, ER_TLS_EXTENSION_SERVER_NAME, extension_len) != 0u &&
                 er_tls_write_u16(writer, list_len) != 0u &&
                 er_tls_write_u8(writer, ER_TLS_HOST_NAME_TYPE) != 0u &&
                 er_tls_write_u16(writer, host_len) != 0u &&
                 er_tls_write_bytes(writer, host, host_len) != 0u);
}

static UINT8 er_tls_write_supported_versions_extension(ErTlsWriter* writer) {
  return (UINT8)(er_tls_write_extension_header(writer, ER_TLS_EXTENSION_SUPPORTED_VERSIONS, 3u) != 0u &&
                 er_tls_write_u8(writer, 2u) != 0u &&
                 er_tls_write_u16(writer, ER_TLS_VERSION_1_3) != 0u);
}

static UINT8 er_tls_write_supported_groups_extension(ErTlsWriter* writer) {
  return (UINT8)(er_tls_write_extension_header(writer, ER_TLS_EXTENSION_SUPPORTED_GROUPS, 4u) != 0u &&
                 er_tls_write_u16(writer, 2u) != 0u &&
                 er_tls_write_u16(writer, ER_TLS_NAMED_GROUP_SECP256R1) != 0u);
}

static UINT8 er_tls_write_signature_algorithms_extension(ErTlsWriter* writer) {
  return (UINT8)(er_tls_write_extension_header(writer, ER_TLS_EXTENSION_SIGNATURE_ALGORITHMS, 4u) != 0u &&
                 er_tls_write_u16(writer, 2u) != 0u &&
                 er_tls_write_u16(writer, ER_TLS_SIGNATURE_ECDSA_SECP256R1_SHA256) != 0u);
}

static UINT8 er_tls_write_key_share_extension(ErTlsWriter* writer,
                                              const UINT8 raw_public[ER_TLS_P256_RAW_PUBLIC_BYTES]) {
  return (UINT8)(er_tls_write_extension_header(writer, ER_TLS_EXTENSION_KEY_SHARE,
                                               2u + 2u + 2u + ER_TLS_P256_SEC1_PUBLIC_BYTES) != 0u &&
                 er_tls_write_u16(writer, 2u + 2u + ER_TLS_P256_SEC1_PUBLIC_BYTES) != 0u &&
                 er_tls_write_u16(writer, ER_TLS_NAMED_GROUP_SECP256R1) != 0u &&
                 er_tls_write_u16(writer, ER_TLS_P256_SEC1_PUBLIC_BYTES) != 0u &&
                 er_tls_write_u8(writer, ER_TLS_SEC1_UNCOMPRESSED) != 0u &&
                 er_tls_write_bytes(writer, raw_public, ER_TLS_P256_RAW_PUBLIC_BYTES) != 0u);
}

static UINT8 er_tls_server_key_share_parse(ErTlsServerHello* out_hello,
                                           const UINT8* data,
                                           UINT16 len) {
  UINT16 key_len;

  if (out_hello == 0 || data == 0 || len != 4u + ER_TLS_P256_SEC1_PUBLIC_BYTES ||
      er_tls_read_u16(data) != ER_TLS_NAMED_GROUP_SECP256R1) {
    return 0u;
  }
  key_len = er_tls_read_u16(data + 2u);
  if (key_len != ER_TLS_P256_SEC1_PUBLIC_BYTES || data[4] != ER_TLS_SEC1_UNCOMPRESSED) {
    return 0u;
  }
  er_mem_copy(out_hello->server_public_key, data + 5u, ER_TLS_P256_RAW_PUBLIC_BYTES);
  out_hello->has_server_public_key = 1u;
  return 1u;
}

static UINT8 er_tls_server_hello_extension_parse(ErTlsServerHello* out_hello,
                                                 UINT16 extension_type,
                                                 const UINT8* data,
                                                 UINT16 len) {
  switch (extension_type) {
    case ER_TLS_EXTENSION_SUPPORTED_VERSIONS:
      if (len != 2u) {
        return 0u;
      }
      out_hello->supported_version = er_tls_read_u16(data);
      out_hello->has_supported_version = 1u;
      return 1u;
    case ER_TLS_EXTENSION_KEY_SHARE:
      return er_tls_server_key_share_parse(out_hello, data, len);
    default:
      return 1u;
  }
}

UINT8 er_tls_client_hello_build(ErTlsTpm* tpm,
                                ErTlsHandshake* handshake,
                                const UINT8* host,
                                UINT16 host_len,
                                UINT8* out_bytes,
                                UINT16 out_capacity,
                                UINT16* out_len) {
  ErTlsWriter writer;
  ErTpmP256Primary ecdh;
  UINT16 record_len_offset;
  UINT16 handshake_len_offset;
  UINT16 body_start;
  UINT16 extension_len_offset;
  UINT16 extension_start;

  if (tpm == 0 || handshake == 0 || er_tls_host_valid(host, host_len) == 0u ||
      out_bytes == 0 || out_len == 0 || out_capacity < ER_TLS_CLIENT_HELLO_MAX_BYTES) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  er_mem_zero((UINT8*)handshake, (UINTN)sizeof(*handshake));
  if (er_tls_tpm_get_random(tpm, handshake->client_random, ER_TLS_RANDOM_BYTES) == 0u ||
      er_tls_tpm_create_p256_ecdh_key(tpm, &ecdh) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  handshake->ecdh_handle = ecdh.handle;
  er_mem_copy(handshake->client_public_key, ecdh.public_key, ER_TLS_P256_RAW_PUBLIC_BYTES);

  writer.bytes = out_bytes;
  writer.capacity = out_capacity;
  writer.len = 0u;

  if (er_tls_write_u8(&writer, ER_TLS_RECORD_HANDSHAKE) == 0u ||
      er_tls_write_u16(&writer, ER_TLS_RECORD_VERSION) == 0u) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  record_len_offset = writer.len;
  if (er_tls_write_u16(&writer, 0u) == 0u ||
      er_tls_write_u8(&writer, ER_TLS_HANDSHAKE_CLIENT_HELLO) == 0u) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  handshake_len_offset = writer.len;
  if (er_tls_write_u24(&writer, 0u) == 0u) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  body_start = writer.len;
  if (er_tls_write_u16(&writer, ER_TLS_RECORD_VERSION) == 0u ||
      er_tls_write_bytes(&writer, handshake->client_random, ER_TLS_RANDOM_BYTES) == 0u ||
      er_tls_write_u8(&writer, 0u) == 0u ||
      er_tls_write_u16(&writer, 2u) == 0u ||
      er_tls_write_u16(&writer, ER_TLS_CIPHER_TLS_AES_128_GCM_SHA256) == 0u ||
      er_tls_write_u8(&writer, ER_TLS_NULL_COMPRESSION_BYTES) == 0u ||
      er_tls_write_u8(&writer, 0u) == 0u) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  extension_len_offset = writer.len;
  if (er_tls_write_u16(&writer, 0u) == 0u) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  extension_start = writer.len;
  if (er_tls_write_supported_versions_extension(&writer) == 0u ||
      er_tls_write_supported_groups_extension(&writer) == 0u ||
      er_tls_write_signature_algorithms_extension(&writer) == 0u ||
      er_tls_write_key_share_extension(&writer, handshake->client_public_key) == 0u ||
      er_tls_write_sni_extension(&writer, host, host_len) == 0u ||
      er_tls_patch_u16(&writer, extension_len_offset, (UINT16)(writer.len - extension_start)) == 0u ||
      er_tls_patch_u24(&writer, handshake_len_offset, (UINT32)(writer.len - body_start)) == 0u ||
      er_tls_patch_u16(&writer, record_len_offset,
                       (UINT16)(writer.len - ER_TLS_RECORD_HEADER_BYTES)) == 0u) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  *out_len = writer.len;
  return ER_TLS_STATUS_OK;
}

UINT8 er_tls_server_hello_parse(const UINT8* bytes,
                                UINT16 len,
                                ErTlsServerHello* out_hello) {
  UINT16 record_len;
  UINT32 body_len;
  UINT16 body_start;
  UINT16 body_end;
  UINT16 pos;
  UINT16 session_len;
  UINT16 extension_len;
  UINT16 extension_end;

  if (bytes == 0 || out_hello == 0 || len < ER_TLS_RECORD_HEADER_BYTES + 4u ||
      bytes[0] != ER_TLS_RECORD_HANDSHAKE ||
      er_tls_read_u16(bytes + 1u) != ER_TLS_RECORD_VERSION) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  record_len = er_tls_read_u16(bytes + 3u);
  if (record_len > len - ER_TLS_RECORD_HEADER_BYTES ||
      bytes[ER_TLS_RECORD_HEADER_BYTES] != ER_TLS_HANDSHAKE_SERVER_HELLO) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  body_len = er_tls_read_u24(bytes + ER_TLS_RECORD_HEADER_BYTES + 1u);
  if (body_len > ER_TLS_U24_MAX || body_len > record_len - 4u) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  body_start = ER_TLS_RECORD_HEADER_BYTES + 4u;
  body_end = (UINT16)(body_start + body_len);
  if (body_end > len || body_end - body_start < 2u + ER_TLS_RANDOM_BYTES + 1u) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  er_mem_zero((UINT8*)out_hello, (UINTN)sizeof(*out_hello));
  pos = body_start;
  out_hello->legacy_version = er_tls_read_u16(bytes + pos);
  pos = (UINT16)(pos + 2u);
  er_mem_copy(out_hello->random, bytes + pos, ER_TLS_RANDOM_BYTES);
  pos = (UINT16)(pos + ER_TLS_RANDOM_BYTES);
  session_len = bytes[pos];
  pos = (UINT16)(pos + 1u);
  if (session_len > body_end - pos) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  pos = (UINT16)(pos + session_len);
  if (body_end - pos < 5u) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  out_hello->cipher_suite = er_tls_read_u16(bytes + pos);
  pos = (UINT16)(pos + 2u);
  if (bytes[pos] != 0u) {
    return ER_TLS_STATUS_UNSUPPORTED;
  }
  pos = (UINT16)(pos + 1u);
  extension_len = er_tls_read_u16(bytes + pos);
  pos = (UINT16)(pos + 2u);
  if (extension_len > body_end - pos) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  extension_end = (UINT16)(pos + extension_len);
  while (pos < extension_end) {
    UINT16 extension_type;
    UINT16 current_len;

    if (extension_end - pos < 4u) {
      return ER_TLS_STATUS_PARSE_FAILURE;
    }
    extension_type = er_tls_read_u16(bytes + pos);
    current_len = er_tls_read_u16(bytes + pos + 2u);
    pos = (UINT16)(pos + 4u);
    if (current_len > extension_end - pos ||
        er_tls_server_hello_extension_parse(out_hello, extension_type, bytes + pos, current_len) == 0u) {
      return ER_TLS_STATUS_PARSE_FAILURE;
    }
    pos = (UINT16)(pos + current_len);
  }
  if (out_hello->legacy_version != ER_TLS_RECORD_VERSION ||
      out_hello->cipher_suite != ER_TLS_CIPHER_TLS_AES_128_GCM_SHA256 ||
      out_hello->has_supported_version == 0u ||
      out_hello->supported_version != ER_TLS_VERSION_1_3 ||
      out_hello->has_server_public_key == 0u) {
    return ER_TLS_STATUS_UNSUPPORTED;
  }
  return ER_TLS_STATUS_OK;
}

UINT8 er_tls_handshake_accept_server_hello(ErTlsTpm* tpm,
                                           ErTlsHandshake* handshake,
                                           const UINT8* bytes,
                                           UINT16 len) {
  ErTlsServerHello server_hello;
  UINT8 status;

  if (tpm == 0 || handshake == 0) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  status = er_tls_server_hello_parse(bytes, len, &server_hello);
  if (status != ER_TLS_STATUS_OK) {
    return status;
  }
  if (er_tls_tpm_ecdh_zgen(tpm,
                           handshake->ecdh_handle,
                           server_hello.server_public_key,
                           handshake->shared_point) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  er_mem_copy(handshake->server_random, server_hello.random, ER_TLS_RANDOM_BYTES);
  er_mem_copy(handshake->server_public_key, server_hello.server_public_key, ER_TLS_P256_RAW_PUBLIC_BYTES);
  handshake->cipher_suite = server_hello.cipher_suite;
  handshake->supported_version = server_hello.supported_version;
  handshake->ready = 1u;
  return ER_TLS_STATUS_OK;
}

UINT8 er_tls_handshake_close(ErTlsTpm* tpm, ErTlsHandshake* handshake) {
  UINT32 handle;

  if (tpm == 0 || handshake == 0) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  handle = handshake->ecdh_handle;
  er_mem_zero((UINT8*)handshake, (UINTN)sizeof(*handshake));
  if (handle == 0u) {
    return ER_TLS_STATUS_OK;
  }
  return er_tls_tpm_flush(tpm, handle) == 0u ? ER_TLS_STATUS_TPM_FAILURE : ER_TLS_STATUS_OK;
}
