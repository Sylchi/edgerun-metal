#define ER_TLS_RECORD_HANDSHAKE 22u
#define ER_TLS_RECORD_HEADER_BYTES 5u
#define ER_TLS_VERSION_1_2_MAJOR 0x03u
#define ER_TLS_VERSION_1_2_MINOR 0x03u
#define ER_TLS_VERSION_1_2_WIRE 0x0303u
#define ER_TLS_VERSION_1_3_WIRE 0x0304u
#define ER_TLS_HANDSHAKE_CLIENT_HELLO 1u
#define ER_TLS_HANDSHAKE_SERVER_HELLO 2u
#define ER_TLS_RANDOM_BYTES 32u
#define ER_TLS_MAX_SESSION_ID_BYTES 32u
#define ER_TLS_MAX_KEY_SHARE_BYTES 65u
#define ER_TLS_MAX_HOST_BYTES 255u
#define ER_TLS_CIPHER_ECDHE_ECDSA_AES_128_CBC_SHA256 0xc023u
#define ER_TLS_EXTENSION_SERVER_NAME 0x0000u
#define ER_TLS_EXTENSION_SUPPORTED_GROUPS 0x000au
#define ER_TLS_EXTENSION_EC_POINT_FORMATS 0x000bu
#define ER_TLS_EXTENSION_SIGNATURE_ALGORITHMS 0x000du
#define ER_TLS_EXTENSION_SUPPORTED_VERSIONS 0x002bu
#define ER_TLS_EXTENSION_KEY_SHARE 0x0033u
#define ER_TLS_NAMETYPE_HOST_NAME 0u
#define ER_TLS_GROUP_SECP256R1 0x0017u
#define ER_TLS_EC_POINT_FORMAT_UNCOMPRESSED 0u
#define ER_TLS_SIG_ECDSA_SECP256R1_SHA256 0x0403u
#define ER_TLS_U24_MAX 0xffffffu
#define ER_TLS_U16_MAX 0xffffu
#define ER_TLS_SELF_TEST_HELLO_BYTES 94u
#define ER_TLS_SELF_TEST_RECORD_BODY_BYTES 89u
#define ER_TLS_SELF_TEST_HANDSHAKE_BODY_BYTES 85u
#define ER_TLS_SELF_TEST_SESSION_ID_OFFSET 43u
#define ER_TLS_SELF_TEST_CIPHER_OFFSET 46u
#define ER_TLS_SELF_TEST_COMPRESSION_OFFSET 48u
#define ER_TLS_SELF_TEST_HOST_OFFSET 61u

typedef struct {
    unsigned char *data;
    size_t len;
} ErTlsBytes;

typedef struct {
    unsigned content_type;
    unsigned version;
    const unsigned char *fragment;
    size_t fragment_len;
    size_t consumed;
} ErTlsRecordView;

typedef struct {
    unsigned legacy_version;
    unsigned char random[ER_TLS_RANDOM_BYTES];
    unsigned char session_id[ER_TLS_MAX_SESSION_ID_BYTES];
    size_t session_id_len;
    unsigned cipher_suite;
    unsigned legacy_compression;
    unsigned supported_version;
    bool has_supported_version;
    unsigned key_share_group;
    unsigned char key_share[ER_TLS_MAX_KEY_SHARE_BYTES];
    size_t key_share_len;
} ErTlsServerHello;

static unsigned er_tls_read_u16(const unsigned char *bytes) {
    return ((unsigned)bytes[0] << 8u) | (unsigned)bytes[1];
}

static unsigned er_tls_read_u24(const unsigned char *bytes) {
    return ((unsigned)bytes[0] << 16u) | ((unsigned)bytes[1] << 8u) | (unsigned)bytes[2];
}

static void er_tls_append_u8(Buffer *b, unsigned value) {
    unsigned char byte = (unsigned char)(value & 0xffu);
    buffer_append(b, (const char *)&byte, sizeof(byte));
}

static void er_tls_append_u16(Buffer *b, unsigned value) {
    unsigned char bytes[2];
    bytes[0] = (unsigned char)((value >> 8u) & 0xffu);
    bytes[1] = (unsigned char)(value & 0xffu);
    buffer_append(b, (const char *)bytes, sizeof(bytes));
}

static void er_tls_append_u24(Buffer *b, unsigned value) {
    unsigned char bytes[3];
    bytes[0] = (unsigned char)((value >> 16u) & 0xffu);
    bytes[1] = (unsigned char)((value >> 8u) & 0xffu);
    bytes[2] = (unsigned char)(value & 0xffu);
    buffer_append(b, (const char *)bytes, sizeof(bytes));
}

static void er_tls_append_bytes(Buffer *b, const unsigned char *bytes, size_t len) {
    buffer_append(b, (const char *)bytes, len);
}

static bool er_tls_host_name_valid(const char *host, size_t *out_len) {
    size_t len;

    if (!host || !out_len) return false;
    len = strlen(host);
    if (len == 0 || len > ER_TLS_MAX_HOST_BYTES) return false;
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char)host[i];
        if (!(isalnum(c) || c == '.' || c == '-')) return false;
    }
    *out_len = len;
    return true;
}

static void er_tls_append_extension_header(Buffer *b, unsigned extension_type, size_t extension_len) {
    if (extension_len > ER_TLS_U16_MAX) die("tls extension too large");
    er_tls_append_u16(b, extension_type);
    er_tls_append_u16(b, (unsigned)extension_len);
}

static void er_tls_append_sni_extension(Buffer *extensions, const char *host, size_t host_len) {
    Buffer body;
    size_t server_name_len;

    buffer_init(&body);
    server_name_len = 1u + 2u + host_len;
    er_tls_append_u16(&body, (unsigned)server_name_len);
    er_tls_append_u8(&body, ER_TLS_NAMETYPE_HOST_NAME);
    er_tls_append_u16(&body, (unsigned)host_len);
    er_tls_append_bytes(&body, (const unsigned char *)host, host_len);
    er_tls_append_extension_header(extensions, ER_TLS_EXTENSION_SERVER_NAME, body.len);
    er_tls_append_bytes(extensions, (const unsigned char *)body.data, body.len);
    free(body.data);
}

static void er_tls_append_supported_groups_extension(Buffer *extensions) {
    Buffer body;

    buffer_init(&body);
    er_tls_append_u16(&body, 2u);
    er_tls_append_u16(&body, ER_TLS_GROUP_SECP256R1);
    er_tls_append_extension_header(extensions, ER_TLS_EXTENSION_SUPPORTED_GROUPS, body.len);
    er_tls_append_bytes(extensions, (const unsigned char *)body.data, body.len);
    free(body.data);
}

static void er_tls_append_ec_point_formats_extension(Buffer *extensions) {
    Buffer body;

    buffer_init(&body);
    er_tls_append_u8(&body, 1u);
    er_tls_append_u8(&body, ER_TLS_EC_POINT_FORMAT_UNCOMPRESSED);
    er_tls_append_extension_header(extensions, ER_TLS_EXTENSION_EC_POINT_FORMATS, body.len);
    er_tls_append_bytes(extensions, (const unsigned char *)body.data, body.len);
    free(body.data);
}

static void er_tls_append_signature_algorithms_extension(Buffer *extensions) {
    Buffer body;

    buffer_init(&body);
    er_tls_append_u16(&body, 2u);
    er_tls_append_u16(&body, ER_TLS_SIG_ECDSA_SECP256R1_SHA256);
    er_tls_append_extension_header(extensions, ER_TLS_EXTENSION_SIGNATURE_ALGORITHMS, body.len);
    er_tls_append_bytes(extensions, (const unsigned char *)body.data, body.len);
    free(body.data);
}

static ErTlsBytes er_tls_client_hello_new(const char *host,
                                          const unsigned char random[ER_TLS_RANDOM_BYTES]) {
    Buffer handshake;
    Buffer body;
    Buffer extensions;
    ErTlsBytes out;
    size_t host_len;

    if (!er_tls_host_name_valid(host, &host_len) || !random) {
        die("tls client hello invalid input");
    }
    buffer_init(&handshake);
    buffer_init(&body);
    buffer_init(&extensions);

    er_tls_append_u8(&body, ER_TLS_VERSION_1_2_MAJOR);
    er_tls_append_u8(&body, ER_TLS_VERSION_1_2_MINOR);
    er_tls_append_bytes(&body, random, ER_TLS_RANDOM_BYTES);
    er_tls_append_u8(&body, 0u);
    er_tls_append_u16(&body, 2u);
    er_tls_append_u16(&body, ER_TLS_CIPHER_ECDHE_ECDSA_AES_128_CBC_SHA256);
    er_tls_append_u8(&body, 1u);
    er_tls_append_u8(&body, 0u);

    er_tls_append_sni_extension(&extensions, host, host_len);
    er_tls_append_supported_groups_extension(&extensions);
    er_tls_append_ec_point_formats_extension(&extensions);
    er_tls_append_signature_algorithms_extension(&extensions);
    if (extensions.len > ER_TLS_U16_MAX || body.len + 2u + extensions.len > ER_TLS_U24_MAX) {
        die("tls client hello too large");
    }
    er_tls_append_u16(&body, (unsigned)extensions.len);
    er_tls_append_bytes(&body, (const unsigned char *)extensions.data, extensions.len);

    er_tls_append_u8(&handshake, ER_TLS_RECORD_HANDSHAKE);
    er_tls_append_u8(&handshake, ER_TLS_VERSION_1_2_MAJOR);
    er_tls_append_u8(&handshake, ER_TLS_VERSION_1_2_MINOR);
    er_tls_append_u16(&handshake, (unsigned)(4u + body.len));
    er_tls_append_u8(&handshake, ER_TLS_HANDSHAKE_CLIENT_HELLO);
    er_tls_append_u24(&handshake, (unsigned)body.len);
    er_tls_append_bytes(&handshake, (const unsigned char *)body.data, body.len);

    out.data = (unsigned char *)handshake.data;
    out.len = handshake.len;
    free(body.data);
    free(extensions.data);
    return out;
}

static void er_tls_free_bytes(ErTlsBytes *bytes) {
    if (!bytes) return;
    free(bytes->data);
    bytes->data = NULL;
    bytes->len = 0;
}

static void er_tls_buffer_free(Buffer *buffer) {
    if (!buffer) return;
    free(buffer->data);
    buffer->data = NULL;
    buffer->len = 0;
    buffer->cap = 0;
}

static bool er_tls_record_parse(const unsigned char *data, size_t len, ErTlsRecordView *out) {
    size_t fragment_len;

    if (!data || !out || len < ER_TLS_RECORD_HEADER_BYTES) return false;
    fragment_len = (size_t)er_tls_read_u16(data + 3u);
    if (fragment_len > len - ER_TLS_RECORD_HEADER_BYTES) return false;
    out->content_type = data[0];
    out->version = er_tls_read_u16(data + 1u);
    out->fragment = data + ER_TLS_RECORD_HEADER_BYTES;
    out->fragment_len = fragment_len;
    out->consumed = ER_TLS_RECORD_HEADER_BYTES + fragment_len;
    return true;
}

static bool er_tls_server_hello_parse_extension(ErTlsServerHello *out,
                                                unsigned extension_type,
                                                const unsigned char *data,
                                                size_t len) {
    size_t key_share_len;

    switch (extension_type) {
        case ER_TLS_EXTENSION_KEY_SHARE:
            if (len < 4u) return false;
            key_share_len = (size_t)er_tls_read_u16(data + 2u);
            if (key_share_len > sizeof(out->key_share) || key_share_len > len - 4u) return false;
            out->key_share_group = er_tls_read_u16(data);
            memcpy(out->key_share, data + 4u, key_share_len);
            out->key_share_len = key_share_len;
            return true;
        case ER_TLS_EXTENSION_SUPPORTED_VERSIONS:
            if (len != 2u) return false;
            out->supported_version = er_tls_read_u16(data);
            out->has_supported_version = true;
            return true;
        default:
            return true;
    }
}

static bool er_tls_server_hello_parse(const unsigned char *data, size_t len, ErTlsServerHello *out) {
    const unsigned char *msg;
    size_t msg_len;
    size_t pos;
    size_t session_id_len;

    if (!data || !out || len < 4u || data[0] != ER_TLS_HANDSHAKE_SERVER_HELLO) return false;
    msg_len = (size_t)er_tls_read_u24(data + 1u);
    if (msg_len > len - 4u) return false;
    msg = data + 4u;
    pos = 0;
    memset(out, 0, sizeof(*out));

    if (msg_len < 2u + ER_TLS_RANDOM_BYTES + 1u) return false;
    out->legacy_version = er_tls_read_u16(msg);
    pos += 2u;
    memcpy(out->random, msg + pos, ER_TLS_RANDOM_BYTES);
    pos += ER_TLS_RANDOM_BYTES;

    session_id_len = msg[pos++];
    if (session_id_len > sizeof(out->session_id) || session_id_len > msg_len - pos) return false;
    memcpy(out->session_id, msg + pos, session_id_len);
    out->session_id_len = session_id_len;
    pos += session_id_len;

    if (msg_len - pos < 3u) return false;
    out->cipher_suite = er_tls_read_u16(msg + pos);
    pos += 2u;
    out->legacy_compression = msg[pos++];

    if (pos < msg_len) {
        size_t extensions_len;
        size_t extensions_end;

        if (msg_len - pos < 2u) return false;
        extensions_len = (size_t)er_tls_read_u16(msg + pos);
        pos += 2u;
        if (extensions_len > msg_len - pos) return false;
        extensions_end = pos + extensions_len;
        while (pos < extensions_end) {
            unsigned extension_type;
            size_t extension_len;

            if (extensions_end - pos < 4u) return false;
            extension_type = er_tls_read_u16(msg + pos);
            extension_len = (size_t)er_tls_read_u16(msg + pos + 2u);
            pos += 4u;
            if (extension_len > extensions_end - pos) return false;
            if (!er_tls_server_hello_parse_extension(out, extension_type, msg + pos, extension_len)) return false;
            pos += extension_len;
        }
    }
    return true;
}

static int er_tls_self_test(void) {
    unsigned char random[ER_TLS_RANDOM_BYTES];
    unsigned char server_random[ER_TLS_RANDOM_BYTES];
    ErTlsBytes hello;
    Buffer server_hello;
    Buffer server_hello_body;
    Buffer server_hello_extensions;
    Buffer server_hello_record;
    ErTlsRecordView record;
    ErTlsServerHello parsed;
    size_t host_offset;

    for (size_t i = 0; i < sizeof(random); i++) random[i] = (unsigned char)i;
    hello = er_tls_client_hello_new("example.com", random);
    if (hello.len != ER_TLS_SELF_TEST_HELLO_BYTES) {
        er_tls_free_bytes(&hello);
        return 1;
    }
    if (hello.data[0] != ER_TLS_RECORD_HANDSHAKE ||
        hello.data[1] != ER_TLS_VERSION_1_2_MAJOR ||
        hello.data[2] != ER_TLS_VERSION_1_2_MINOR ||
        hello.data[3] != 0u ||
        hello.data[4] != ER_TLS_SELF_TEST_RECORD_BODY_BYTES ||
        hello.data[5] != ER_TLS_HANDSHAKE_CLIENT_HELLO ||
        hello.data[6] != 0u ||
        hello.data[7] != 0u ||
        hello.data[8] != ER_TLS_SELF_TEST_HANDSHAKE_BODY_BYTES ||
        hello.data[9] != ER_TLS_VERSION_1_2_MAJOR ||
        hello.data[10] != ER_TLS_VERSION_1_2_MINOR ||
        hello.data[11] != random[0] ||
        hello.data[ER_TLS_SELF_TEST_SESSION_ID_OFFSET] != 0u ||
        hello.data[ER_TLS_SELF_TEST_CIPHER_OFFSET] != 0xc0u ||
        hello.data[ER_TLS_SELF_TEST_CIPHER_OFFSET + 1u] != 0x23u ||
        hello.data[ER_TLS_SELF_TEST_COMPRESSION_OFFSET] != 1u ||
        hello.data[ER_TLS_SELF_TEST_COMPRESSION_OFFSET + 1u] != 0u) {
        er_tls_free_bytes(&hello);
        return 2;
    }
    host_offset = ER_TLS_SELF_TEST_HOST_OFFSET;
    if (memcmp(hello.data + host_offset, "example.com", strlen("example.com")) != 0) {
        er_tls_free_bytes(&hello);
        return 3;
    }
    er_tls_free_bytes(&hello);

    for (size_t i = 0; i < sizeof(server_random); i++) {
        server_random[i] = (unsigned char)(0xa0u + i);
    }
    buffer_init(&server_hello);
    buffer_init(&server_hello_body);
    buffer_init(&server_hello_extensions);
    buffer_init(&server_hello_record);
    er_tls_append_u16(&server_hello_body, ER_TLS_VERSION_1_2_WIRE);
    er_tls_append_bytes(&server_hello_body, server_random, sizeof(server_random));
    er_tls_append_u8(&server_hello_body, 0u);
    er_tls_append_u16(&server_hello_body, ER_TLS_CIPHER_ECDHE_ECDSA_AES_128_CBC_SHA256);
    er_tls_append_u8(&server_hello_body, 0u);
    er_tls_append_extension_header(&server_hello_extensions, ER_TLS_EXTENSION_SUPPORTED_VERSIONS, 2u);
    er_tls_append_u16(&server_hello_extensions, ER_TLS_VERSION_1_3_WIRE);
    er_tls_append_extension_header(&server_hello_extensions, ER_TLS_EXTENSION_KEY_SHARE, 4u);
    er_tls_append_u16(&server_hello_extensions, ER_TLS_GROUP_SECP256R1);
    er_tls_append_u16(&server_hello_extensions, 0u);
    er_tls_append_u16(&server_hello_body, (unsigned)server_hello_extensions.len);
    er_tls_append_bytes(&server_hello_body,
                        (const unsigned char *)server_hello_extensions.data,
                        server_hello_extensions.len);
    er_tls_append_u8(&server_hello, ER_TLS_HANDSHAKE_SERVER_HELLO);
    er_tls_append_u24(&server_hello, (unsigned)server_hello_body.len);
    er_tls_append_bytes(&server_hello, (const unsigned char *)server_hello_body.data, server_hello_body.len);
    er_tls_append_u8(&server_hello_record, ER_TLS_RECORD_HANDSHAKE);
    er_tls_append_u16(&server_hello_record, ER_TLS_VERSION_1_2_WIRE);
    er_tls_append_u16(&server_hello_record, (unsigned)server_hello.len);
    er_tls_append_bytes(&server_hello_record, (const unsigned char *)server_hello.data, server_hello.len);
    if (!er_tls_record_parse((const unsigned char *)server_hello_record.data,
                             server_hello_record.len,
                             &record) ||
        record.content_type != ER_TLS_RECORD_HANDSHAKE ||
        record.version != ER_TLS_VERSION_1_2_WIRE ||
        record.consumed != server_hello_record.len) {
        er_tls_buffer_free(&server_hello);
        er_tls_buffer_free(&server_hello_body);
        er_tls_buffer_free(&server_hello_extensions);
        er_tls_buffer_free(&server_hello_record);
        return 4;
    }
    if (!er_tls_server_hello_parse(record.fragment, record.fragment_len, &parsed) ||
        parsed.legacy_version != ER_TLS_VERSION_1_2_WIRE ||
        parsed.random[0] != server_random[0] ||
        parsed.session_id_len != 0u ||
        parsed.cipher_suite != ER_TLS_CIPHER_ECDHE_ECDSA_AES_128_CBC_SHA256 ||
        parsed.legacy_compression != 0u ||
        !parsed.has_supported_version ||
        parsed.supported_version != ER_TLS_VERSION_1_3_WIRE ||
        parsed.key_share_group != ER_TLS_GROUP_SECP256R1 ||
        parsed.key_share_len != 0u) {
        er_tls_buffer_free(&server_hello);
        er_tls_buffer_free(&server_hello_body);
        er_tls_buffer_free(&server_hello_extensions);
        er_tls_buffer_free(&server_hello_record);
        return 5;
    }
    er_tls_buffer_free(&server_hello);
    er_tls_buffer_free(&server_hello_body);
    er_tls_buffer_free(&server_hello_extensions);
    er_tls_buffer_free(&server_hello_record);
    return 0;
}
