#include "er_tls.h"

#include "er_mem.h"

#define ER_TLS_RECORD_HANDSHAKE 22u
#define ER_TLS_RECORD_HEADER_BYTES 5u
#define ER_TLS_RECORD_VERSION 0x0303u
#define ER_TLS_HANDSHAKE_CLIENT_HELLO 1u
#define ER_TLS_HANDSHAKE_SERVER_HELLO 2u
#define ER_TLS_HANDSHAKE_CERTIFICATE_VERIFY 15u
#define ER_TLS_HANDSHAKE_FINISHED 20u
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
#define ER_TLS_RECORD_APPLICATION_DATA 23u
#define ER_TLS_RECORD_AUTH_PREFIX_BYTES 13u
#define ER_TLS_HANDSHAKE_HEADER_BYTES 4u
#define ER_TLS_RECORD_SEQUENCE_BYTES 8u
#define ER_TLS_CERT_VERIFY_BODY_MIN_BYTES 4u
#define ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES 64u
#define ER_TLS_P256_SIGNATURE_BYTES 64u
#define ER_TLS_FINISHED_MESSAGE_BYTES \
  (ER_TLS_HANDSHAKE_HEADER_BYTES + ER_TLS_FINISHED_VERIFY_BYTES)
#define ER_TLS_RECORD_CLIENT_TO_SERVER 1u
#define ER_TLS_RECORD_SERVER_TO_CLIENT 0u
#define ER_TLS_DERIVE_LABEL_CLIENT_KEY 1u
#define ER_TLS_DERIVE_LABEL_SERVER_KEY 2u
#define ER_TLS_DERIVE_LABEL_CLIENT_IV 3u
#define ER_TLS_DERIVE_LABEL_SERVER_IV 4u
#define ER_TLS_DERIVE_LABEL_CLIENT_MAC 5u
#define ER_TLS_DERIVE_LABEL_SERVER_MAC 6u
#define ER_TLS_U8_BITS 8u
#define ER_TLS_U8_MASK 0xffu
#define ER_TLS_U16_BYTES 2u
#define ER_TLS_U24_BYTES 3u

static const UINT8 er_tls_server_certificate_verify_context[] =
    "TLS 1.3, server CertificateVerify";

typedef struct {
  UINT8* bytes;
  UINT16 capacity;
  UINT16 len;
} ErTlsWriter;

typedef struct {
  UINT32 aes_handle;
  UINT32 hmac_handle;
  UINT8* iv;
  UINT64 sequence;
} ErTlsRecordDirection;

static UINT32 er_tls_read_be(const UINT8* bytes, UINT16 byte_count) {
  UINT16 i;
  UINT32 value = 0u;

  for (i = 0u; i < byte_count; ++i) {
    value = (value << ER_TLS_U8_BITS) | (UINT32)bytes[i];
  }
  return value;
}

static void er_tls_put_be(UINT8* bytes, UINT16 byte_count, UINT64 value) {
  UINT16 i;
  UINT32 shift;

  for (i = 0u; i < byte_count; ++i) {
    shift = (UINT32)((byte_count - 1u - i) * ER_TLS_U8_BITS);
    bytes[i] = (UINT8)((value >> shift) & ER_TLS_U8_MASK);
  }
}

static UINT16 er_tls_read_u16(const UINT8* bytes) {
  return (UINT16)er_tls_read_be(bytes, ER_TLS_U16_BYTES);
}

static UINT32 er_tls_read_u24(const UINT8* bytes) {
  return er_tls_read_be(bytes, ER_TLS_U24_BYTES);
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
  UINT8 bytes[ER_TLS_U16_BYTES];

  er_tls_put_be(bytes, (UINT16)sizeof(bytes), value);
  return er_tls_write_bytes(writer, bytes, (UINT16)sizeof(bytes));
}

static UINT8 er_tls_write_u24(ErTlsWriter* writer, UINT32 value) {
  UINT8 bytes[ER_TLS_U24_BYTES];

  if (value > ER_TLS_U24_MAX) {
    return 0u;
  }
  er_tls_put_be(bytes, (UINT16)sizeof(bytes), value);
  return er_tls_write_bytes(writer, bytes, (UINT16)sizeof(bytes));
}

static UINT8 er_tls_patch_u16(ErTlsWriter* writer, UINT16 offset, UINT16 value) {
  if (writer == 0 || offset > writer->len ||
      writer->len - offset < ER_TLS_U16_BYTES) {
    return 0u;
  }
  er_tls_put_be(writer->bytes + offset, ER_TLS_U16_BYTES, value);
  return 1u;
}

static UINT8 er_tls_patch_u24(ErTlsWriter* writer, UINT16 offset, UINT32 value) {
  if (writer == 0 || value > ER_TLS_U24_MAX || offset > writer->len ||
      writer->len - offset < ER_TLS_U24_BYTES) {
    return 0u;
  }
  er_tls_put_be(writer->bytes + offset, ER_TLS_U24_BYTES, value);
  return 1u;
}

static void er_tls_write_seq(UINT8 out[ER_TLS_RECORD_SEQUENCE_BYTES], UINT64 value) {
  er_tls_put_be(out, ER_TLS_RECORD_SEQUENCE_BYTES, value);
}

static UINT8 er_tls_slice_equal(const UINT8* a, const UINT8* b, UINT16 len) {
  UINT16 i;
  UINT8 diff = 0u;

  if (a == 0 || b == 0) {
    return 0u;
  }
  for (i = 0u; i < len; ++i) {
    diff = (UINT8)(diff | (UINT8)(a[i] ^ b[i]));
  }
  return (UINT8)(diff == 0u);
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

UINT8 er_tls_certificate_verify_accept(ErTlsTpm* tpm,
                                       ErTlsHandshake* handshake,
                                       const UINT8 server_verify_key[ER_TLS_P256_RAW_PUBLIC_BYTES],
                                       const UINT8* transcript,
                                       UINT16 transcript_len,
                                       const UINT8* message,
                                       UINT16 message_len) {
  UINT32 body_len;
  UINT16 signature_scheme;
  UINT16 signature_len;
  UINT8 transcript_hash[ER_TLS_SHA256_BYTES];
  UINT8 signed_content[ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES +
                       sizeof(er_tls_server_certificate_verify_context) +
                       ER_TLS_SHA256_BYTES];
  UINT8 signed_hash[ER_TLS_SHA256_BYTES];
  UINT16 signed_content_len;
  UINT32 verify_handle = 0u;
  UINT16 i;
  UINT8 status = ER_TLS_STATUS_TPM_FAILURE;

  if (tpm == 0 || handshake == 0 || handshake->ready == 0u ||
      server_verify_key == 0 || transcript == 0 || transcript_len == 0u ||
      message == 0 ||
      message_len < ER_TLS_HANDSHAKE_HEADER_BYTES + ER_TLS_CERT_VERIFY_BODY_MIN_BYTES) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  if (message[0] != ER_TLS_HANDSHAKE_CERTIFICATE_VERIFY) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  body_len = er_tls_read_u24(message + 1u);
  if (body_len != message_len - ER_TLS_HANDSHAKE_HEADER_BYTES ||
      body_len < ER_TLS_CERT_VERIFY_BODY_MIN_BYTES) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  signature_scheme = er_tls_read_u16(message + ER_TLS_HANDSHAKE_HEADER_BYTES);
  signature_len = er_tls_read_u16(message + ER_TLS_HANDSHAKE_HEADER_BYTES + 2u);
  if (signature_scheme != ER_TLS_SIGNATURE_ECDSA_SECP256R1_SHA256 ||
      signature_len != ER_TLS_P256_SIGNATURE_BYTES ||
      body_len != ER_TLS_CERT_VERIFY_BODY_MIN_BYTES + ER_TLS_P256_SIGNATURE_BYTES) {
    return ER_TLS_STATUS_UNSUPPORTED;
  }
  for (i = 0u; i < ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES; ++i) {
    signed_content[i] = 0x20u;
  }
  if (er_tls_tpm_sha256(tpm, transcript, transcript_len, transcript_hash) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  er_mem_copy(signed_content + ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES,
              er_tls_server_certificate_verify_context,
              (UINTN)(sizeof(er_tls_server_certificate_verify_context) - 1u));
  signed_content[ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES +
                 sizeof(er_tls_server_certificate_verify_context) - 1u] = 0u;
  er_mem_copy(signed_content + ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES +
                  sizeof(er_tls_server_certificate_verify_context),
              transcript_hash,
              ER_TLS_SHA256_BYTES);
  signed_content_len = (UINT16)(ER_TLS_CERT_VERIFY_PREFIX_SPACE_BYTES +
                                sizeof(er_tls_server_certificate_verify_context) +
                                ER_TLS_SHA256_BYTES);
  if (er_tls_tpm_sha256(tpm, signed_content, signed_content_len, signed_hash) == 0u ||
      er_tls_tpm_load_p256_verify_key(tpm, server_verify_key, &verify_handle) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  if (er_tls_tpm_verify_p256_sha256(tpm,
                                    verify_handle,
                                    signed_hash,
                                    message + ER_TLS_HANDSHAKE_HEADER_BYTES +
                                        ER_TLS_CERT_VERIFY_BODY_MIN_BYTES) != 0u) {
    handshake->server_authenticated = 1u;
    status = ER_TLS_STATUS_OK;
  }
  if (er_tls_tpm_flush(tpm, verify_handle) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  return status;
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

static UINT8 er_tls_derive_material(ErTlsTpm* tpm,
                                    UINT32 secret_handle,
                                    UINT8 label,
                                    const UINT8 transcript_hash[ER_TLS_SHA256_BYTES],
                                    UINT8 out_material[ER_TLS_SHA256_BYTES]) {
  UINT8 input[1u + ER_TLS_SHA256_BYTES];

  input[0] = label;
  er_mem_copy(input + 1u, transcript_hash, ER_TLS_SHA256_BYTES);
  return er_tls_tpm_hmac_sha256(tpm,
                                secret_handle,
                                input,
                                (UINT16)sizeof(input),
                                out_material);
}

static UINT8 er_tls_load_key_material(ErTlsTpm* tpm,
                                      ErTlsRecordKeys* keys,
                                      const UINT8 client_key[ER_TLS_SHA256_BYTES],
                                      const UINT8 server_key[ER_TLS_SHA256_BYTES],
                                      const UINT8 client_mac[ER_TLS_SHA256_BYTES],
                                      const UINT8 server_mac[ER_TLS_SHA256_BYTES]) {
  if (er_tls_tpm_load_aes_key(tpm,
                              client_key,
                              ER_TLS_AES_128_KEY_BYTES,
                              ER_TPM_AES_128_KEY_BITS,
                              &keys->client_aes_handle) == 0u ||
      er_tls_tpm_load_aes_key(tpm,
                              server_key,
                              ER_TLS_AES_128_KEY_BYTES,
                              ER_TPM_AES_128_KEY_BITS,
                              &keys->server_aes_handle) == 0u ||
      er_tls_tpm_load_hmac_sha256_key(tpm,
                                      client_mac,
                                      ER_TLS_SHA256_BYTES,
                                      &keys->client_hmac_handle) == 0u ||
      er_tls_tpm_load_hmac_sha256_key(tpm,
                                      server_mac,
                                      ER_TLS_SHA256_BYTES,
                                      &keys->server_hmac_handle) == 0u) {
    return 0u;
  }
  return 1u;
}

UINT8 er_tls_record_keys_derive(ErTlsTpm* tpm,
                                const ErTlsHandshake* handshake,
                                const UINT8* transcript,
                                UINT16 transcript_len,
                                ErTlsRecordKeys* out_keys) {
  UINT8 transcript_hash[ER_TLS_SHA256_BYTES];
  UINT8 client_key[ER_TLS_SHA256_BYTES];
  UINT8 server_key[ER_TLS_SHA256_BYTES];
  UINT8 client_iv[ER_TLS_SHA256_BYTES];
  UINT8 server_iv[ER_TLS_SHA256_BYTES];
  UINT8 client_mac[ER_TLS_SHA256_BYTES];
  UINT8 server_mac[ER_TLS_SHA256_BYTES];
  UINT32 secret_handle;

  if (tpm == 0 || handshake == 0 || handshake->ready == 0u ||
      handshake->server_authenticated == 0u ||
      transcript == 0 || transcript_len == 0u || out_keys == 0) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  er_mem_zero((UINT8*)out_keys, (UINTN)sizeof(*out_keys));
  if (er_tls_tpm_sha256(tpm, transcript, transcript_len, transcript_hash) == 0u ||
      er_tls_tpm_load_hmac_sha256_key(tpm,
                                      handshake->shared_point,
                                      ER_TLS_SHA256_BYTES,
                                      &secret_handle) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  if (er_tls_derive_material(tpm, secret_handle, ER_TLS_DERIVE_LABEL_CLIENT_KEY,
                             transcript_hash, client_key) == 0u ||
      er_tls_derive_material(tpm, secret_handle, ER_TLS_DERIVE_LABEL_SERVER_KEY,
                             transcript_hash, server_key) == 0u ||
      er_tls_derive_material(tpm, secret_handle, ER_TLS_DERIVE_LABEL_CLIENT_IV,
                             transcript_hash, client_iv) == 0u ||
      er_tls_derive_material(tpm, secret_handle, ER_TLS_DERIVE_LABEL_SERVER_IV,
                             transcript_hash, server_iv) == 0u ||
      er_tls_derive_material(tpm, secret_handle, ER_TLS_DERIVE_LABEL_CLIENT_MAC,
                             transcript_hash, client_mac) == 0u ||
      er_tls_derive_material(tpm, secret_handle, ER_TLS_DERIVE_LABEL_SERVER_MAC,
                             transcript_hash, server_mac) == 0u ||
      er_tls_tpm_flush(tpm, secret_handle) == 0u ||
      er_tls_load_key_material(tpm,
                               out_keys,
                               client_key,
                               server_key,
                               client_mac,
                               server_mac) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  er_mem_copy(out_keys->client_iv, client_iv, ER_TLS_RECORD_IV_BYTES);
  er_mem_copy(out_keys->server_iv, server_iv, ER_TLS_RECORD_IV_BYTES);
  out_keys->ready = 1u;
  return ER_TLS_STATUS_OK;
}

static UINT8 er_tls_finished_data(ErTlsTpm* tpm,
                                  UINT32 hmac_handle,
                                  const UINT8* transcript,
                                  UINT16 transcript_len,
                                  UINT8 out_verify[ER_TLS_FINISHED_VERIFY_BYTES]) {
  UINT8 transcript_hash[ER_TLS_SHA256_BYTES];

  if (er_tls_tpm_sha256(tpm, transcript, transcript_len, transcript_hash) == 0u) {
    return 0u;
  }
  return er_tls_tpm_hmac_sha256(tpm,
                                hmac_handle,
                                transcript_hash,
                                ER_TLS_SHA256_BYTES,
                                out_verify);
}

UINT8 er_tls_server_finished_accept(ErTlsTpm* tpm,
                                    ErTlsHandshake* handshake,
                                    const ErTlsRecordKeys* keys,
                                    const UINT8* transcript,
                                    UINT16 transcript_len,
                                    const UINT8* message,
                                    UINT16 message_len) {
  UINT8 expected[ER_TLS_FINISHED_VERIFY_BYTES];

  if (tpm == 0 || handshake == 0 || keys == 0 || keys->ready == 0u ||
      handshake->ready == 0u || handshake->server_authenticated == 0u ||
      transcript == 0 || transcript_len == 0u || message == 0) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  if (message_len != ER_TLS_FINISHED_MESSAGE_BYTES ||
      message[0] != ER_TLS_HANDSHAKE_FINISHED ||
      er_tls_read_u24(message + 1u) != ER_TLS_FINISHED_VERIFY_BYTES) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  if (er_tls_finished_data(tpm,
                           keys->server_hmac_handle,
                           transcript,
                           transcript_len,
                           expected) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  if (er_tls_slice_equal(expected,
                         message + ER_TLS_HANDSHAKE_HEADER_BYTES,
                         ER_TLS_FINISHED_VERIFY_BYTES) == 0u) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  handshake->server_finished_verified = 1u;
  return ER_TLS_STATUS_OK;
}

UINT8 er_tls_client_finished_build(ErTlsTpm* tpm,
                                   ErTlsHandshake* handshake,
                                   const ErTlsRecordKeys* keys,
                                   const UINT8* transcript,
                                   UINT16 transcript_len,
                                   UINT8* out_message,
                                   UINT16 out_capacity,
                                   UINT16* out_message_len) {
  ErTlsWriter writer;

  if (tpm == 0 || handshake == 0 || keys == 0 || keys->ready == 0u ||
      handshake->server_finished_verified == 0u ||
      transcript == 0 || transcript_len == 0u ||
      out_message == 0 || out_message_len == 0) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  if (out_capacity < ER_TLS_FINISHED_MESSAGE_BYTES) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  writer.bytes = out_message;
  writer.capacity = out_capacity;
  writer.len = 0u;
  if (er_tls_write_u8(&writer, ER_TLS_HANDSHAKE_FINISHED) == 0u ||
      er_tls_write_u24(&writer, ER_TLS_FINISHED_VERIFY_BYTES) == 0u ||
      er_tls_finished_data(tpm,
                           keys->client_hmac_handle,
                           transcript,
                           transcript_len,
                           out_message + ER_TLS_HANDSHAKE_HEADER_BYTES) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  writer.len = ER_TLS_FINISHED_MESSAGE_BYTES;
  *out_message_len = writer.len;
  handshake->client_finished_built = 1u;
  return ER_TLS_STATUS_OK;
}

static UINT8 er_tls_record_mac(ErTlsTpm* tpm,
                               UINT32 hmac_handle,
                               UINT64 sequence,
                               const UINT8* header,
                               const UINT8* data,
                               UINT16 data_len,
                               UINT8 out_tag[ER_TLS_RECORD_TAG_BYTES]) {
  UINT8 mac_input[ER_TLS_RECORD_AUTH_PREFIX_BYTES + ER_TLS_RECORD_PLAINTEXT_MAX_BYTES];
  UINT8 seq[8];

  if (data_len > ER_TLS_RECORD_PLAINTEXT_MAX_BYTES) {
    return 0u;
  }
  er_tls_write_seq(seq, sequence);
  er_mem_copy(mac_input, seq, (UINTN)sizeof(seq));
  er_mem_copy(mac_input + sizeof(seq), header, ER_TLS_RECORD_HEADER_BYTES);
  er_mem_copy(mac_input + ER_TLS_RECORD_AUTH_PREFIX_BYTES, data, data_len);
  return er_tls_tpm_hmac_sha256(tpm,
                                hmac_handle,
                                mac_input,
                                (UINT16)(ER_TLS_RECORD_AUTH_PREFIX_BYTES + data_len),
                                out_tag);
}

static UINT8 er_tls_record_direction(ErTlsRecordKeys* keys,
                                     UINT8 from_client,
                                     ErTlsRecordDirection* out_direction) {
  if (keys == 0 || out_direction == 0) {
    return 0u;
  }
  if (from_client == ER_TLS_RECORD_CLIENT_TO_SERVER) {
    out_direction->aes_handle = keys->client_aes_handle;
    out_direction->hmac_handle = keys->client_hmac_handle;
    out_direction->iv = keys->client_iv;
    out_direction->sequence = keys->client_sequence;
    return 1u;
  }
  out_direction->aes_handle = keys->server_aes_handle;
  out_direction->hmac_handle = keys->server_hmac_handle;
  out_direction->iv = keys->server_iv;
  out_direction->sequence = keys->server_sequence;
  return 1u;
}

static void er_tls_record_advance_sequence(ErTlsRecordKeys* keys, UINT8 from_client) {
  if (from_client == ER_TLS_RECORD_CLIENT_TO_SERVER) {
    ++keys->client_sequence;
  } else {
    ++keys->server_sequence;
  }
}

UINT8 er_tls_record_protect(ErTlsTpm* tpm,
                            ErTlsRecordKeys* keys,
                            UINT8 from_client,
                            const UINT8* plaintext,
                            UINT16 plaintext_len,
                            UINT8* out_record,
                            UINT16 out_capacity,
                            UINT16* out_record_len) {
  UINT32 data_len = 0u;
  UINT32 iv_len = 0u;
  ErTlsRecordDirection direction;
  UINT8 tag[ER_TLS_RECORD_TAG_BYTES];

  if (tpm == 0 || keys == 0 || keys->ready == 0u || plaintext == 0 ||
      plaintext_len == 0u || plaintext_len > ER_TLS_RECORD_PLAINTEXT_MAX_BYTES ||
      out_record == 0 || out_record_len == 0 ||
      out_capacity < ER_TLS_RECORD_HEADER_BYTES + plaintext_len + ER_TLS_RECORD_TAG_BYTES) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  if (er_tls_record_direction(keys, from_client, &direction) == 0u) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  out_record[0] = ER_TLS_RECORD_APPLICATION_DATA;
  er_tls_put_be(out_record + 1u, ER_TLS_U16_BYTES, ER_TLS_RECORD_VERSION);
  er_tls_put_be(out_record + 3u,
                ER_TLS_U16_BYTES,
                (UINT16)(plaintext_len + ER_TLS_RECORD_TAG_BYTES));
  if (er_tls_tpm_record_crypt(tpm,
                              direction.aes_handle,
                              0u,
                              direction.iv,
                              ER_TLS_RECORD_IV_BYTES,
                              plaintext,
                              plaintext_len,
                              out_record + ER_TLS_RECORD_HEADER_BYTES,
                              out_capacity - ER_TLS_RECORD_HEADER_BYTES,
                              &data_len,
                              direction.iv,
                              ER_TLS_RECORD_IV_BYTES,
                              &iv_len) == 0u ||
      data_len != plaintext_len ||
      iv_len != ER_TLS_RECORD_IV_BYTES ||
      er_tls_record_mac(tpm,
                        direction.hmac_handle,
                        direction.sequence,
                        out_record,
                        out_record + ER_TLS_RECORD_HEADER_BYTES,
                        plaintext_len, tag) == 0u) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  er_mem_copy(out_record + ER_TLS_RECORD_HEADER_BYTES + plaintext_len,
              tag,
              ER_TLS_RECORD_TAG_BYTES);
  *out_record_len = (UINT16)(ER_TLS_RECORD_HEADER_BYTES +
                             plaintext_len +
                             ER_TLS_RECORD_TAG_BYTES);
  er_tls_record_advance_sequence(keys, from_client);
  return ER_TLS_STATUS_OK;
}

UINT8 er_tls_record_unprotect(ErTlsTpm* tpm,
                              ErTlsRecordKeys* keys,
                              UINT8 from_client,
                              const UINT8* record,
                              UINT16 record_len,
                              UINT8* out_plaintext,
                              UINT16 out_capacity,
                              UINT16* out_plaintext_len) {
  UINT16 encrypted_len;
  UINT16 plaintext_len;
  UINT32 data_len = 0u;
  UINT32 iv_len = 0u;
  ErTlsRecordDirection direction;
  UINT8 expected_tag[ER_TLS_RECORD_TAG_BYTES];

  if (tpm == 0 || keys == 0 || keys->ready == 0u || record == 0 ||
      record_len < ER_TLS_RECORD_HEADER_BYTES + ER_TLS_RECORD_TAG_BYTES || out_plaintext == 0 ||
      out_plaintext_len == 0 || record[0] != ER_TLS_RECORD_APPLICATION_DATA ||
      er_tls_read_u16(record + 1u) != ER_TLS_RECORD_VERSION) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  encrypted_len = er_tls_read_u16(record + 3u);
  if (encrypted_len != record_len - ER_TLS_RECORD_HEADER_BYTES ||
      encrypted_len < ER_TLS_RECORD_TAG_BYTES) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  plaintext_len = (UINT16)(encrypted_len - ER_TLS_RECORD_TAG_BYTES);
  if (plaintext_len > out_capacity || plaintext_len > ER_TLS_RECORD_PLAINTEXT_MAX_BYTES) {
    return ER_TLS_STATUS_BUFFER_TOO_SMALL;
  }
  if (er_tls_record_direction(keys, from_client, &direction) == 0u) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  if (er_tls_record_mac(tpm,
                        direction.hmac_handle,
                        direction.sequence,
                        record,
                        record + ER_TLS_RECORD_HEADER_BYTES,
                        plaintext_len, expected_tag) == 0u ||
      er_tls_slice_equal(expected_tag,
                         record + ER_TLS_RECORD_HEADER_BYTES + plaintext_len,
                         ER_TLS_RECORD_TAG_BYTES) == 0u) {
    return ER_TLS_STATUS_PARSE_FAILURE;
  }
  if (er_tls_tpm_record_crypt(tpm,
                              direction.aes_handle,
                              1u,
                              direction.iv,
                              ER_TLS_RECORD_IV_BYTES,
                              record + ER_TLS_RECORD_HEADER_BYTES,
                              plaintext_len,
                              out_plaintext,
                              out_capacity,
                              &data_len,
                              direction.iv,
                              ER_TLS_RECORD_IV_BYTES,
                              &iv_len) == 0u ||
      data_len != plaintext_len ||
      iv_len != ER_TLS_RECORD_IV_BYTES) {
    return ER_TLS_STATUS_TPM_FAILURE;
  }
  *out_plaintext_len = (UINT16)data_len;
  er_tls_record_advance_sequence(keys, from_client);
  return ER_TLS_STATUS_OK;
}

UINT8 er_tls_record_keys_close(ErTlsTpm* tpm, ErTlsRecordKeys* keys) {
  UINT8 ok = 1u;

  if (tpm == 0 || keys == 0) {
    return ER_TLS_STATUS_INVALID_ARGUMENT;
  }
  if (keys->client_aes_handle != 0u &&
      er_tls_tpm_flush(tpm, keys->client_aes_handle) == 0u) {
    ok = 0u;
  }
  if (keys->server_aes_handle != 0u &&
      er_tls_tpm_flush(tpm, keys->server_aes_handle) == 0u) {
    ok = 0u;
  }
  if (keys->client_hmac_handle != 0u &&
      er_tls_tpm_flush(tpm, keys->client_hmac_handle) == 0u) {
    ok = 0u;
  }
  if (keys->server_hmac_handle != 0u &&
      er_tls_tpm_flush(tpm, keys->server_hmac_handle) == 0u) {
    ok = 0u;
  }
  er_mem_zero((UINT8*)keys, (UINTN)sizeof(*keys));
  return ok == 0u ? ER_TLS_STATUS_TPM_FAILURE : ER_TLS_STATUS_OK;
}
