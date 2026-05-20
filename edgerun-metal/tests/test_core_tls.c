#define TEST_TLS_SERVER_RANDOM_SEED 0xa5u
#define TEST_TLS_SERVER_KEY_SEED 0xd0u
#define TEST_TLS_SERVER_HELLO_MAX 160u
#define TEST_TLS_TRANSCRIPT_MAX 512u
#define TEST_TLS_CERT_VERIFY_MAX 80u
#define TEST_TLS_CERT_VERIFY_HANDSHAKE 15u
#define TEST_TLS_CERT_VERIFY_SCHEME 0x0403u
#define TEST_TLS_CERT_VERIFY_SIGNATURE_BYTES 64u
#define TEST_TLS_CERT_VERIFY_SIGNATURE_SEED 0x20u
#define TEST_TLS_FINISHED_MAX 40u
#define TEST_TLS_FINISHED_HANDSHAKE 20u
#define TEST_TLS_RECORD_MAX 128u
#define TEST_TLS_RECORD_HEADER_BYTES 5u
#define TEST_TLS_PLAINTEXT_BYTES 16u
#define TEST_TLS_AUTH_CALLS 10u
#define TEST_TLS_DERIVE_CALLS 35u
#define TEST_TLS_SERVER_FINISHED_CALLS 39u
#define TEST_TLS_CLIENT_FINISHED_CALLS 43u

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

static UINT16 test_tls_build_certificate_verify(UINT8* out, UINT16 out_capacity) {
  TestTlsWriter writer;

  (void)out_capacity;
  writer.bytes = out;
  writer.len = 0u;
  test_tls_write_u8(&writer, TEST_TLS_CERT_VERIFY_HANDSHAKE);
  test_tls_write_u24(&writer, 2u + 2u + TEST_TLS_CERT_VERIFY_SIGNATURE_BYTES);
  test_tls_write_u16(&writer, TEST_TLS_CERT_VERIFY_SCHEME);
  test_tls_write_u16(&writer, TEST_TLS_CERT_VERIFY_SIGNATURE_BYTES);
  test_fill_bytes(out + writer.len,
                  TEST_TLS_CERT_VERIFY_SIGNATURE_BYTES,
                  TEST_TLS_CERT_VERIFY_SIGNATURE_SEED);
  writer.len = (UINT16)(writer.len + TEST_TLS_CERT_VERIFY_SIGNATURE_BYTES);
  return writer.len;
}

static UINT16 test_tls_build_finished(UINT8* out, UINT16 out_capacity) {
  TestTlsWriter writer;

  (void)out_capacity;
  writer.bytes = out;
  writer.len = 0u;
  test_tls_write_u8(&writer, TEST_TLS_FINISHED_HANDSHAKE);
  test_tls_write_u24(&writer, ER_TLS_FINISHED_VERIFY_BYTES);
  test_fill_bytes(out + writer.len,
                  ER_TLS_FINISHED_VERIFY_BYTES,
                  TEST_TLS_TPM_DIGEST_SEED);
  writer.len = (UINT16)(writer.len + ER_TLS_FINISHED_VERIFY_BYTES);
  return writer.len;
}

static void test_tls_tpm_handshake_core(void) {
  TestTlsTpmScript script;
  ErTpm2Info info;
  ErTpmAlgorithmProfile algorithms;
  ErTpmCommandProfile commands;
  ErTlsTpm tls_tpm;
  ErTlsHandshake handshake;
  ErTlsRecordKeys keys;
  ErTlsServerHello parsed;
  UINT8 client_hello[ER_TLS_CLIENT_HELLO_MAX_BYTES];
  UINT8 server_hello[TEST_TLS_SERVER_HELLO_MAX];
  UINT8 certificate_verify[TEST_TLS_CERT_VERIFY_MAX];
  UINT8 server_finished[TEST_TLS_FINISHED_MAX];
  UINT8 client_finished[TEST_TLS_FINISHED_MAX];
  UINT8 transcript[TEST_TLS_TRANSCRIPT_MAX];
  UINT8 plaintext[TEST_TLS_PLAINTEXT_BYTES];
  UINT8 record[TEST_TLS_RECORD_MAX];
  UINT8 opened[TEST_TLS_PLAINTEXT_BYTES];
  UINT8 server_key[ER_TLS_P256_RAW_PUBLIC_BYTES];
  UINT16 client_hello_len = 0u;
  UINT16 server_hello_len;
  UINT16 certificate_verify_len;
  UINT16 server_finished_len;
  UINT16 client_finished_len = 0u;
  UINT16 transcript_len;
  UINT16 record_len = 0u;
  UINT16 opened_len = 0u;

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

  server_hello_len = test_tls_build_server_hello(server_hello,
                                                 (UINT16)sizeof(server_hello),
                                                 server_key);
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
  check_uint64("tls core server key stored",
               handshake.server_public_key[0],
               TEST_TLS_SERVER_KEY_SEED);
  check_uint64("tls core ecdh command", script.last_command_code, ER_TPM_CC_ECDH_ZGEN);
  if (client_hello_len + server_hello_len <= sizeof(transcript)) {
    er_mem_copy(transcript, client_hello, client_hello_len);
    er_mem_copy(transcript + client_hello_len, server_hello, server_hello_len);
  }
  transcript_len = (UINT16)(client_hello_len + server_hello_len);
  certificate_verify_len =
      test_tls_build_certificate_verify(certificate_verify,
                                        (UINT16)sizeof(certificate_verify));
  check_uint64("tls core certificate verify",
               er_tls_certificate_verify_accept(&tls_tpm,
                                                &handshake,
                                                server_key,
                                                transcript,
                                                transcript_len,
                                                certificate_verify,
                                                certificate_verify_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core authenticated", handshake.server_authenticated, 1u);
  check_uint64("tls core auth calls", script.calls, TEST_TLS_AUTH_CALLS);
  check_uint64("tls core auth flush", script.last_command_code, ER_TPM_CC_FLUSH_CONTEXT);

  check_uint64("tls core derive keys",
               er_tls_record_keys_derive(&tls_tpm,
                                         &handshake,
                                         transcript,
                                         transcript_len,
                                         &keys),
               ER_TLS_STATUS_OK);
  check_uint64("tls core key derive ready", keys.ready, 1u);
  check_uint64("tls core client aes handle", keys.client_aes_handle, TEST_TLS_TPM_HANDLE_AES);
  check_uint64("tls core server aes handle", keys.server_aes_handle, TEST_TLS_TPM_HANDLE_AES);
  check_uint64("tls core client hmac handle", keys.client_hmac_handle, TEST_TLS_TPM_HANDLE_HMAC);
  check_uint64("tls core server hmac handle", keys.server_hmac_handle, TEST_TLS_TPM_HANDLE_HMAC);
  check_uint64("tls core derive calls", script.calls, TEST_TLS_DERIVE_CALLS);

  if (transcript_len + certificate_verify_len <= sizeof(transcript)) {
    er_mem_copy(transcript + transcript_len, certificate_verify, certificate_verify_len);
  }
  transcript_len = (UINT16)(transcript_len + certificate_verify_len);
  server_finished_len = test_tls_build_finished(server_finished,
                                                (UINT16)sizeof(server_finished));
  check_uint64("tls core server finished",
               er_tls_server_finished_accept(&tls_tpm,
                                             &handshake,
                                             &keys,
                                             transcript,
                                             transcript_len,
                                             server_finished,
                                             server_finished_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core server finished flag", handshake.server_finished_verified, 1u);
  check_uint64("tls core server finished calls", script.calls, TEST_TLS_SERVER_FINISHED_CALLS);

  if (transcript_len + server_finished_len <= sizeof(transcript)) {
    er_mem_copy(transcript + transcript_len, server_finished, server_finished_len);
  }
  transcript_len = (UINT16)(transcript_len + server_finished_len);
  check_uint64("tls core client finished",
               er_tls_client_finished_build(&tls_tpm,
                                            &handshake,
                                            &keys,
                                            transcript,
                                            transcript_len,
                                            client_finished,
                                            (UINT16)sizeof(client_finished),
                                            &client_finished_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core client finished flag", handshake.client_finished_built, 1u);
  check_uint64("tls core client finished len", client_finished_len, server_finished_len);
  check_uint64("tls core client finished type", client_finished[0], TEST_TLS_FINISHED_HANDSHAKE);
  check_uint64("tls core client finished byte",
               client_finished[4u],
               TEST_TLS_TPM_DIGEST_SEED);
  check_uint64("tls core client finished calls", script.calls, TEST_TLS_CLIENT_FINISHED_CALLS);

  test_fill_bytes(plaintext, (UINTN)sizeof(plaintext), 0x11u);
  check_uint64("tls core protect record",
               er_tls_record_protect(&tls_tpm,
                                     &keys,
                                     1u,
                                     plaintext,
                                     (UINT16)sizeof(plaintext),
                                     record,
                                     (UINT16)sizeof(record),
                                     &record_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core protected type", record[0], 23u);
  check_uint64("tls core protected len",
               record_len,
               TEST_TLS_RECORD_HEADER_BYTES + TEST_TLS_PLAINTEXT_BYTES +
                   ER_TLS_RECORD_TAG_BYTES);
  check_uint64("tls core protected cipher",
               record[TEST_TLS_RECORD_HEADER_BYTES],
               TEST_TLS_TPM_CIPHER_SEED);
  check_uint64("tls core protected tag",
               record[TEST_TLS_RECORD_HEADER_BYTES + TEST_TLS_PLAINTEXT_BYTES],
               TEST_TLS_TPM_DIGEST_SEED);
  check_uint64("tls core client sequence", keys.client_sequence, 1u);

  keys.client_sequence = 0u;
  check_uint64("tls core unprotect record",
               er_tls_record_unprotect(&tls_tpm,
                                       &keys,
                                       1u,
                                       record,
                                       record_len,
                                       opened,
                                       (UINT16)sizeof(opened),
                                       &opened_len),
               ER_TLS_STATUS_OK);
  check_uint64("tls core opened len", opened_len, TEST_TLS_PLAINTEXT_BYTES);
  check_uint64("tls core opened byte", opened[0], TEST_TLS_TPM_CIPHER_SEED);
  check_uint64("tls core unprotect sequence", keys.client_sequence, 1u);

  check_uint64("tls core close keys",
               er_tls_record_keys_close(&tls_tpm, &keys),
               ER_TLS_STATUS_OK);
  check_uint64("tls core close keys clears", keys.ready, 0u);
  check_uint64("tls core close",
               er_tls_handshake_close(&tls_tpm, &handshake),
               ER_TLS_STATUS_OK);
  check_uint64("tls core close clears", handshake.ecdh_handle, 0u);
  check_uint64("tls core flush command", script.last_command_code, ER_TPM_CC_FLUSH_CONTEXT);
}
