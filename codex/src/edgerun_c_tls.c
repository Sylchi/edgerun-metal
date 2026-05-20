#define ER_CODEX_TLS_TPM_START_METHOD_CRB 6u
#define ER_CODEX_TLS_TPM_HANDLE_ECDH 0x80000013u
#define ER_CODEX_TLS_TPM_RANDOM_SEED 0x90u
#define ER_CODEX_TLS_TPM_PRIMARY_X_SEED 0x71u
#define ER_CODEX_TLS_TPM_PRIMARY_Y_SEED 0x91u
#define ER_CODEX_TLS_TPM_POINT_X_SEED 0x44u
#define ER_CODEX_TLS_TPM_POINT_Y_SEED 0x64u
#define ER_CODEX_TLS_SERVER_RANDOM_SEED 0xa5u
#define ER_CODEX_TLS_SERVER_KEY_SEED 0xd0u
#define ER_CODEX_TLS_HOST_LEN 11u
#define ER_CODEX_TLS_SERVER_HELLO_MAX 160u

#include "../../edgerun-metal/core/er_mem.c"
#include "../../edgerun-metal/core/er_tpm.c"
#include "../../edgerun-metal/core/er_tls_tpm.c"
#include "../../edgerun-metal/core/er_tls.c"

typedef struct {
    int fd;
} ErTlsConnection;

typedef struct {
    unsigned char *bytes;
    UINT16 len;
} ErCodexTlsWriter;

typedef struct {
    UINT32 calls;
    UINT32 last_command_code;
} ErCodexTlsTpmScript;

static UINT32 er_codex_tls_read_be32(const UINT8 *bytes) {
    return ((UINT32)bytes[0] << 24u) |
           ((UINT32)bytes[1] << 16u) |
           ((UINT32)bytes[2] << 8u) |
           (UINT32)bytes[3];
}

static void er_codex_tls_put_be16(UINT8 *bytes, UINT16 value) {
    bytes[0] = (UINT8)((value >> 8u) & 0xffu);
    bytes[1] = (UINT8)(value & 0xffu);
}

static void er_codex_tls_put_be32(UINT8 *bytes, UINT32 value) {
    bytes[0] = (UINT8)((value >> 24u) & 0xffu);
    bytes[1] = (UINT8)((value >> 16u) & 0xffu);
    bytes[2] = (UINT8)((value >> 8u) & 0xffu);
    bytes[3] = (UINT8)(value & 0xffu);
}

static void er_codex_tls_fill(UINT8 *bytes, UINTN len, UINT8 seed) {
    UINTN i;

    for (i = 0u; i < len; ++i) {
        bytes[i] = (UINT8)(seed + (UINT8)i);
    }
}

static void er_codex_tls_response_header(UINT8 *response, UINT32 response_len) {
    response[0] = 0x80u;
    response[1] = 0x01u;
    er_codex_tls_put_be32(response + 2u, response_len);
    er_codex_tls_put_be32(response + 6u, ER_TPM_RC_SUCCESS);
}

static UINT8 er_codex_tls_random_response(const UINT8 *command,
                                          UINT8 *response,
                                          UINT32 response_capacity,
                                          UINT32 *out_response_len) {
    UINT16 requested = (UINT16)(((UINT16)command[10] << 8u) | (UINT16)command[11]);
    UINT32 response_len = ER_TPM_HEADER_LEN + 2u + (UINT32)requested;

    if (response_capacity < response_len) {
        return 0u;
    }
    er_codex_tls_response_header(response, response_len);
    er_codex_tls_put_be16(response + ER_TPM_HEADER_LEN, requested);
    er_codex_tls_fill(response + ER_TPM_HEADER_LEN + 2u, requested, ER_CODEX_TLS_TPM_RANDOM_SEED);
    *out_response_len = response_len;
    return 1u;
}

static UINT8 er_codex_tls_point_response(UINT8 *response,
                                         UINT32 response_capacity,
                                         UINT32 *out_response_len) {
    UINT32 response_len = ER_TPM_HEADER_LEN + 2u + 2u + 32u + 2u + 32u;

    if (response_capacity < response_len) {
        return 0u;
    }
    er_codex_tls_response_header(response, response_len);
    er_codex_tls_put_be16(response + 10u, 68u);
    er_codex_tls_put_be16(response + 12u, 32u);
    er_codex_tls_fill(response + 14u, 32u, ER_CODEX_TLS_TPM_POINT_X_SEED);
    er_codex_tls_put_be16(response + 46u, 32u);
    er_codex_tls_fill(response + 48u, 32u, ER_CODEX_TLS_TPM_POINT_Y_SEED);
    *out_response_len = response_len;
    return 1u;
}

static UINT8 er_codex_tls_create_primary_response(UINT8 *response,
                                                  UINT32 response_capacity,
                                                  UINT32 *out_response_len) {
    UINT32 offset;

    if (response_capacity < 126u) {
        return 0u;
    }
    response[0] = 0x80u;
    response[1] = 0x02u;
    er_codex_tls_put_be32(response + 2u, 126u);
    er_codex_tls_put_be32(response + 6u, ER_TPM_RC_SUCCESS);
    er_codex_tls_put_be32(response + 10u, ER_CODEX_TLS_TPM_HANDLE_ECDH);
    er_codex_tls_put_be32(response + 14u, 90u);
    offset = 18u;
    er_codex_tls_put_be16(response + offset, 88u);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ALG_ECC);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ALG_SHA256);
    offset += 2u;
    er_codex_tls_put_be32(response + offset, 0x00040472u);
    offset += 4u;
    er_codex_tls_put_be16(response + offset, 0u);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ALG_NULL);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ALG_ECDSA);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ALG_SHA256);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ECC_NIST_P256);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, ER_TPM_ALG_NULL);
    offset += 2u;
    er_codex_tls_put_be16(response + offset, 32u);
    offset += 2u;
    er_codex_tls_fill(response + offset, 32u, ER_CODEX_TLS_TPM_PRIMARY_X_SEED);
    offset += 32u;
    er_codex_tls_put_be16(response + offset, 32u);
    offset += 2u;
    er_codex_tls_fill(response + offset, 32u, ER_CODEX_TLS_TPM_PRIMARY_Y_SEED);
    *out_response_len = 126u;
    return 1u;
}

static UINT8 er_codex_tls_tpm_transact(void *user,
                                       const UINT8 *command,
                                       UINT32 command_len,
                                       UINT8 *response,
                                       UINT32 response_capacity,
                                       UINT32 *out_response_len) {
    ErCodexTlsTpmScript *script = (ErCodexTlsTpmScript *)user;
    UINT32 command_code;

    if (script == 0 || command == 0 || response == 0 || out_response_len == 0 ||
        command_len < ER_TPM_HEADER_LEN) {
        return 0u;
    }
    command_code = er_codex_tls_read_be32(command + 6u);
    script->last_command_code = command_code;
    ++script->calls;

    switch (command_code) {
        case ER_TPM_CC_GET_RANDOM:
            return er_codex_tls_random_response(command, response, response_capacity, out_response_len);
        case ER_TPM_CC_CREATE_PRIMARY:
            return er_codex_tls_create_primary_response(response, response_capacity, out_response_len);
        case ER_TPM_CC_ECDH_ZGEN:
            return er_codex_tls_point_response(response, response_capacity, out_response_len);
        case ER_TPM_CC_FLUSH_CONTEXT:
            er_codex_tls_response_header(response, ER_TPM_HEADER_LEN);
            *out_response_len = ER_TPM_HEADER_LEN;
            return 1u;
        default:
            return 0u;
    }
}

static void er_codex_tls_tpm_profiles(ErTpm2Info *info,
                                      ErTpmAlgorithmProfile *algorithms,
                                      ErTpmCommandProfile *commands) {
    er_mem_zero((UINT8 *)info, (UINTN)sizeof(*info));
    er_mem_zero((UINT8 *)algorithms, (UINTN)sizeof(*algorithms));
    er_mem_zero((UINT8 *)commands, (UINTN)sizeof(*commands));

    info->found = 1u;
    info->control_area = 0x1000u;
    info->start_method = ER_CODEX_TLS_TPM_START_METHOD_CRB;
    algorithms->has_sha256 = 1u;
    algorithms->has_hmac = 1u;
    algorithms->has_keyedhash = 1u;
    algorithms->has_ecc = 1u;
    algorithms->has_ecdh = 1u;
    algorithms->has_ecdsa = 1u;
    algorithms->has_aes = 1u;
    algorithms->has_symcipher = 1u;
    algorithms->has_ctr = 1u;
    commands->has_create_primary = 1u;
    commands->has_ecdh_zgen = 1u;
    commands->has_encrypt_decrypt2 = 1u;
    commands->has_get_random = 1u;
    commands->has_hash = 1u;
    commands->has_hash_sequence_start = 1u;
    commands->has_hmac = 1u;
    commands->has_load_external = 1u;
    commands->has_sequence_complete = 1u;
    commands->has_sequence_update = 1u;
    commands->has_sign = 1u;
    commands->has_verify_signature = 1u;
}

static void er_codex_tls_write_u8(ErCodexTlsWriter *writer, UINT8 value) {
    writer->bytes[writer->len] = value;
    writer->len = (UINT16)(writer->len + 1u);
}

static void er_codex_tls_write_u16(ErCodexTlsWriter *writer, UINT16 value) {
    er_codex_tls_put_be16(writer->bytes + writer->len, value);
    writer->len = (UINT16)(writer->len + 2u);
}

static void er_codex_tls_write_u24(ErCodexTlsWriter *writer, UINT32 value) {
    writer->bytes[writer->len] = (UINT8)((value >> 16u) & 0xffu);
    writer->bytes[writer->len + 1u] = (UINT8)((value >> 8u) & 0xffu);
    writer->bytes[writer->len + 2u] = (UINT8)(value & 0xffu);
    writer->len = (UINT16)(writer->len + 3u);
}

static void er_codex_tls_write_bytes(ErCodexTlsWriter *writer, const UINT8 *bytes, UINT16 len) {
    er_mem_copy(writer->bytes + writer->len, bytes, len);
    writer->len = (UINT16)(writer->len + len);
}

static UINT16 er_codex_tls_server_hello_build(UINT8 *out, UINT8 *server_key) {
    ErCodexTlsWriter writer;
    UINT16 record_len_offset;
    UINT16 handshake_len_offset;
    UINT16 body_start;
    UINT16 extension_len_offset;
    UINT16 extension_start;

    er_codex_tls_fill(server_key, ER_TLS_P256_RAW_PUBLIC_BYTES, ER_CODEX_TLS_SERVER_KEY_SEED);
    writer.bytes = out;
    writer.len = 0u;
    er_codex_tls_write_u8(&writer, 22u);
    er_codex_tls_write_u16(&writer, 0x0303u);
    record_len_offset = writer.len;
    er_codex_tls_write_u16(&writer, 0u);
    er_codex_tls_write_u8(&writer, 2u);
    handshake_len_offset = writer.len;
    er_codex_tls_write_u24(&writer, 0u);
    body_start = writer.len;
    er_codex_tls_write_u16(&writer, 0x0303u);
    er_codex_tls_fill(out + writer.len, ER_TLS_RANDOM_BYTES, ER_CODEX_TLS_SERVER_RANDOM_SEED);
    writer.len = (UINT16)(writer.len + ER_TLS_RANDOM_BYTES);
    er_codex_tls_write_u8(&writer, 0u);
    er_codex_tls_write_u16(&writer, 0x1301u);
    er_codex_tls_write_u8(&writer, 0u);
    extension_len_offset = writer.len;
    er_codex_tls_write_u16(&writer, 0u);
    extension_start = writer.len;
    er_codex_tls_write_u16(&writer, 0x002bu);
    er_codex_tls_write_u16(&writer, 2u);
    er_codex_tls_write_u16(&writer, 0x0304u);
    er_codex_tls_write_u16(&writer, 0x0033u);
    er_codex_tls_write_u16(&writer, 69u);
    er_codex_tls_write_u16(&writer, 0x0017u);
    er_codex_tls_write_u16(&writer, 65u);
    er_codex_tls_write_u8(&writer, 0x04u);
    er_codex_tls_write_bytes(&writer, server_key, ER_TLS_P256_RAW_PUBLIC_BYTES);
    er_codex_tls_put_be16(out + extension_len_offset, (UINT16)(writer.len - extension_start));
    out[handshake_len_offset] = 0u;
    er_codex_tls_put_be16(out + handshake_len_offset + 1u, (UINT16)(writer.len - body_start));
    er_codex_tls_put_be16(out + record_len_offset, (UINT16)(writer.len - 5u));
    return writer.len;
}

static ErTlsConnection er_tls_connection_open(const char *host, int fd) {
    ErTlsConnection conn;

    if (host == NULL || *host == 0 || fd < 0) {
        die("tls connection invalid input");
    }
    memset(&conn, 0, sizeof(conn));
    conn.fd = fd;
    close(fd);
    conn.fd = -1;
    die("codex HTTPS requires host TPM transport wired to repo-owned TLS");
    return conn;
}

static void er_tls_connection_close(ErTlsConnection *conn) {
    if (!conn) return;
    if (conn->fd >= 0) close(conn->fd);
    memset(conn, 0, sizeof(*conn));
    conn->fd = -1;
}

static void er_tls_write_all(ErTlsConnection *conn, const char *data, size_t len) {
    (void)conn;
    (void)data;
    (void)len;
    die("codex HTTPS write requires repo-owned TPM-backed TLS");
}

static char *er_tls_read_response_new(ErTlsConnection *conn) {
    (void)conn;
    die("codex HTTPS read requires repo-owned TPM-backed TLS");
    return NULL;
}

static int er_tls_self_test(void) {
    ErCodexTlsTpmScript script;
    ErTpm2Info info;
    ErTpmAlgorithmProfile algorithms;
    ErTpmCommandProfile commands;
    ErTlsTpm tls_tpm;
    ErTlsHandshake handshake;
    ErTlsServerHello parsed;
    UINT8 client_hello[ER_TLS_CLIENT_HELLO_MAX_BYTES];
    UINT8 server_hello[ER_CODEX_TLS_SERVER_HELLO_MAX];
    UINT8 server_key[ER_TLS_P256_RAW_PUBLIC_BYTES];
    UINT16 client_hello_len = 0u;
    UINT16 server_hello_len;

    er_mem_zero((UINT8 *)&script, (UINTN)sizeof(script));
    er_codex_tls_tpm_profiles(&info, &algorithms, &commands);
    if (er_tls_tpm_init(&tls_tpm, er_codex_tls_tpm_transact, &script,
                        &info, &algorithms, &commands) == 0u) {
        return 1;
    }
    if (er_tls_client_hello_build(&tls_tpm,
                                  &handshake,
                                  (const UINT8 *)"example.com",
                                  ER_CODEX_TLS_HOST_LEN,
                                  client_hello,
                                  (UINT16)sizeof(client_hello),
                                  &client_hello_len) != ER_TLS_STATUS_OK) {
        return 2;
    }
    if (client_hello_len == 0u ||
        client_hello[0] != 22u ||
        handshake.client_random[0] != ER_CODEX_TLS_TPM_RANDOM_SEED ||
        handshake.client_public_key[0] != ER_CODEX_TLS_TPM_PRIMARY_X_SEED ||
        handshake.ecdh_handle != ER_CODEX_TLS_TPM_HANDLE_ECDH ||
        script.calls != 2u) {
        return 3;
    }
    server_hello_len = er_codex_tls_server_hello_build(server_hello, server_key);
    if (er_tls_server_hello_parse(server_hello, server_hello_len, &parsed) != ER_TLS_STATUS_OK ||
        parsed.supported_version != 0x0304u ||
        parsed.server_public_key[0] != ER_CODEX_TLS_SERVER_KEY_SEED) {
        return 4;
    }
    if (er_tls_handshake_accept_server_hello(&tls_tpm,
                                             &handshake,
                                             server_hello,
                                             server_hello_len) != ER_TLS_STATUS_OK ||
        handshake.ready == 0u ||
        handshake.shared_point[0] != ER_CODEX_TLS_TPM_POINT_X_SEED ||
        script.last_command_code != ER_TPM_CC_ECDH_ZGEN) {
        return 5;
    }
    if (er_tls_handshake_close(&tls_tpm, &handshake) != ER_TLS_STATUS_OK ||
        script.last_command_code != ER_TPM_CC_FLUSH_CONTEXT) {
        return 6;
    }
    return 0;
}
