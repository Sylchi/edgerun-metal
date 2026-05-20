#define TEST_TLS_SERVER_RANDOM_SEED 0xa5u
#define TEST_TLS_SERVER_KEY_SEED 0xd0u
#define TEST_TLS_SERVER_HELLO_MAX 160u

typedef struct {
  UINT8* bytes;
  UINT16 len;
} TestTlsWriter;

static void test_tls_write_u8(TestTlsWriter* writer, UINT8 value) {
  writer->bytes[writer->len] = value;
  writer->len = (UINT16)(writer->len + 1u);
}

static void test_tls_write_u16(TestTlsWriter* writer, UINT16 value) {
  test_put_be16(writer->bytes + writer->len, value);
  writer->len = (UINT16)(writer->len + 2u);
}

static void test_tls_write_u24(TestTlsWriter* writer, UINT32 value) {
  writer->bytes[writer->len] = (UINT8)((value >> 16u) & 0xffu);
  writer->bytes[writer->len + 1u] = (UINT8)((value >> 8u) & 0xffu);
  writer->bytes[writer->len + 2u] = (UINT8)(value & 0xffu);
  writer->len = (UINT16)(writer->len + 3u);
}

static void test_tls_write_bytes(TestTlsWriter* writer, const UINT8* bytes, UINT16 len) {
  er_mem_copy(writer->bytes + writer->len, bytes, len);
  writer->len = (UINT16)(writer->len + len);
}

static void test_tls_patch_u16(UINT8* bytes, UINT16 offset, UINT16 value) {
  test_put_be16(bytes + offset, value);
}

static void test_tls_patch_u24(UINT8* bytes, UINT16 offset, UINT32 value) {
  bytes[offset] = (UINT8)((value >> 16u) & 0xffu);
  bytes[offset + 1u] = (UINT8)((value >> 8u) & 0xffu);
  bytes[offset + 2u] = (UINT8)(value & 0xffu);
}

static UINT16 test_tls_build_server_hello(UINT8* out, UINT16 out_capacity, UINT8* server_key) {
  TestTlsWriter writer;
  UINT16 record_len_offset;
  UINT16 handshake_len_offset;
  UINT16 body_start;
  UINT16 extension_len_offset;
  UINT16 extension_start;

  (void)out_capacity;
  test_fill_bytes(server_key, ER_TLS_P256_RAW_PUBLIC_BYTES, TEST_TLS_SERVER_KEY_SEED);
  writer.bytes = out;
  writer.len = 0u;
  test_tls_write_u8(&writer, 22u);
  test_tls_write_u16(&writer, 0x0303u);
  record_len_offset = writer.len;
  test_tls_write_u16(&writer, 0u);
  test_tls_write_u8(&writer, 2u);
  handshake_len_offset = writer.len;
  test_tls_write_u24(&writer, 0u);
  body_start = writer.len;
  test_tls_write_u16(&writer, 0x0303u);
  test_fill_bytes(out + writer.len, ER_TLS_RANDOM_BYTES, TEST_TLS_SERVER_RANDOM_SEED);
  writer.len = (UINT16)(writer.len + ER_TLS_RANDOM_BYTES);
  test_tls_write_u8(&writer, 0u);
  test_tls_write_u16(&writer, 0x1301u);
  test_tls_write_u8(&writer, 0u);
  extension_len_offset = writer.len;
  test_tls_write_u16(&writer, 0u);
  extension_start = writer.len;
  test_tls_write_u16(&writer, 0x002bu);
  test_tls_write_u16(&writer, 2u);
  test_tls_write_u16(&writer, 0x0304u);
  test_tls_write_u16(&writer, 0x0033u);
  test_tls_write_u16(&writer, 69u);
  test_tls_write_u16(&writer, 0x0017u);
  test_tls_write_u16(&writer, 65u);
  test_tls_write_u8(&writer, 0x04u);
  test_tls_write_bytes(&writer, server_key, ER_TLS_P256_RAW_PUBLIC_BYTES);
  test_tls_patch_u16(out, extension_len_offset, (UINT16)(writer.len - extension_start));
  test_tls_patch_u24(out, handshake_len_offset, (UINT32)(writer.len - body_start));
  test_tls_patch_u16(out, record_len_offset, (UINT16)(writer.len - 5u));
  return writer.len;
}

static void test_tls_tpm_handshake_core(void) {
  TestTlsTpmScript script;
  ErTpm2Info info;
  ErTpmAlgorithmProfile algorithms;
  ErTpmCommandProfile commands;
  ErTlsTpm tls_tpm;
  ErTlsHandshake handshake;
  ErTlsServerHello parsed;
  UINT8 client_hello[ER_TLS_CLIENT_HELLO_MAX_BYTES];
  UINT8 server_hello[TEST_TLS_SERVER_HELLO_MAX];
  UINT8 server_key[ER_TLS_P256_RAW_PUBLIC_BYTES];
  UINT16 client_hello_len = 0u;
  UINT16 server_hello_len;

  er_mem_zero((UINT8*)&script, (UINTN)sizeof(script));
  test_tls_tpm_profiles(&info, &algorithms, &commands);
  check_int64("tls core tpm init",
              er_tls_tpm_init(&tls_tpm, test_tls_tpm_transact, &script,
                              &info, &algorithms, &commands),
              1);
  check_uint64("tls core initial calls", script.calls, 0u);
  check_uint64("tls core client hello",
               er_tls_client_hello_build(&tls_tpm,
                                         &handshake,
                                         (const UINT8*)"example.com",
                                         11u,
                                         client_hello,
                                         (UINT16)sizeof(client_hello),
                                         &client_hello_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core client hello record", client_hello[0], 22u);
  check_uint64("tls core client random", handshake.client_random[0], TEST_TLS_TPM_RANDOM_SEED);
  check_uint64("tls core public key", handshake.client_public_key[0], TEST_TLS_TPM_PRIMARY_X_SEED);
  check_uint64("tls core ecdh handle", handshake.ecdh_handle, TEST_TLS_TPM_HANDLE_ECDH);
  check_uint64("tls core build calls", script.calls, 2u);

  server_hello_len = test_tls_build_server_hello(server_hello, (UINT16)sizeof(server_hello), server_key);
  check_uint64("tls core parse server hello",
               er_tls_server_hello_parse(server_hello, server_hello_len, &parsed),
               ER_TLS_STATUS_OK);
  check_uint64("tls core parsed version", parsed.supported_version, 0x0304u);
  check_uint64("tls core parsed key", parsed.server_public_key[0], TEST_TLS_SERVER_KEY_SEED);

  check_uint64("tls core accept server hello",
               er_tls_handshake_accept_server_hello(&tls_tpm,
                                                    &handshake,
                                                    server_hello,
                                                    server_hello_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core ready", handshake.ready, 1u);
  check_uint64("tls core shared x", handshake.shared_point[0], TEST_TLS_TPM_POINT_X_SEED);
  check_uint64("tls core shared y", handshake.shared_point[32], TEST_TLS_TPM_POINT_Y_SEED);
  check_uint64("tls core server key stored", handshake.server_public_key[0], TEST_TLS_SERVER_KEY_SEED);
  check_uint64("tls core ecdh command", script.last_command_code, ER_TPM_CC_ECDH_ZGEN);
  check_uint64("tls core close",
               er_tls_handshake_close(&tls_tpm, &handshake),
               ER_TLS_STATUS_OK);
  check_uint64("tls core close clears", handshake.ecdh_handle, 0u);
  check_uint64("tls core flush command", script.last_command_code, ER_TPM_CC_FLUSH_CONTEXT);
}
