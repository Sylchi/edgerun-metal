#define TEST_TLS_TPM_START_METHOD_CRB 6u
#define TEST_TLS_TPM_HANDLE_HMAC 0x80000010u
#define TEST_TLS_TPM_HANDLE_AES 0x80000011u
#define TEST_TLS_TPM_HANDLE_VERIFY 0x80000012u
#define TEST_TLS_TPM_HANDLE_ECDH 0x80000013u
#define TEST_TLS_TPM_DIGEST_SEED 0x33u
#define TEST_TLS_TPM_RANDOM_SEED 0x90u
#define TEST_TLS_TPM_CIPHER_SEED 0xa0u
#define TEST_TLS_TPM_IV_SEED 0xb0u
#define TEST_TLS_TPM_POINT_X_SEED 0x44u
#define TEST_TLS_TPM_POINT_Y_SEED 0x64u
#define TEST_TLS_TPM_PRIMARY_X_SEED 0x71u
#define TEST_TLS_TPM_PRIMARY_Y_SEED 0x91u

typedef struct {
  UINT32 calls;
  UINT32 last_command_code;
  UINT32 last_command_len;
  UINT8 last_command[ER_TLS_TPM_COMMAND_BYTES];
} TestTlsTpmScript;

static UINT32 test_tls_tpm_read_be32(const UINT8* bytes) {
  return ((UINT32)bytes[0] << 24u) |
         ((UINT32)bytes[1] << 16u) |
         ((UINT32)bytes[2] << 8u) |
         (UINT32)bytes[3];
}

static void test_tls_tpm_response_header(UINT8* response, UINT32 response_len) {
  response[0] = 0x80u;
  response[1] = 0x01u;
  test_put_be32(response + 2u, response_len);
  test_put_be32(response + 6u, ER_TPM_RC_SUCCESS);
}

static UINT8 test_tls_tpm_handle_response(UINT8* response,
                                          UINT32 response_capacity,
                                          UINT32* out_response_len,
                                          UINT32 handle) {
  if (response_capacity < ER_TPM_HEADER_LEN + 4u) {
    return 0u;
  }
  test_tls_tpm_response_header(response, ER_TPM_HEADER_LEN + 4u);
  test_put_be32(response + ER_TPM_HEADER_LEN, handle);
  *out_response_len = ER_TPM_HEADER_LEN + 4u;
  return 1u;
}

static UINT8 test_tls_tpm_digest_response(UINT8* response,
                                          UINT32 response_capacity,
                                          UINT32* out_response_len) {
  if (response_capacity < ER_TPM_HEADER_LEN + 2u + ER_TPM_SHA256_DIGEST_LEN) {
    return 0u;
  }
  test_tls_tpm_response_header(response, ER_TPM_HEADER_LEN + 2u + ER_TPM_SHA256_DIGEST_LEN);
  test_put_be16(response + ER_TPM_HEADER_LEN, ER_TPM_SHA256_DIGEST_LEN);
  test_fill_bytes(response + ER_TPM_HEADER_LEN + 2u, ER_TPM_SHA256_DIGEST_LEN, TEST_TLS_TPM_DIGEST_SEED);
  *out_response_len = ER_TPM_HEADER_LEN + 2u + ER_TPM_SHA256_DIGEST_LEN;
  return 1u;
}

static UINT8 test_tls_tpm_random_response(const UINT8* command,
                                          UINT8* response,
                                          UINT32 response_capacity,
                                          UINT32* out_response_len) {
  UINT16 requested = (UINT16)(((UINT16)command[10] << 8u) | (UINT16)command[11]);
  UINT32 response_len = ER_TPM_HEADER_LEN + 2u + (UINT32)requested;

  if (response_capacity < response_len) {
    return 0u;
  }
  test_tls_tpm_response_header(response, response_len);
  test_put_be16(response + ER_TPM_HEADER_LEN, requested);
  test_fill_bytes(response + ER_TPM_HEADER_LEN + 2u, requested, TEST_TLS_TPM_RANDOM_SEED);
  *out_response_len = response_len;
  return 1u;
}

static UINT8 test_tls_tpm_crypt_response(UINT8* response,
                                         UINT32 response_capacity,
                                         UINT32* out_response_len) {
  UINT32 response_len = ER_TPM_HEADER_LEN + 4u + 2u + ER_TPM_AES_BLOCK_LEN + 2u + ER_TPM_AES_BLOCK_LEN;

  if (response_capacity < response_len) {
    return 0u;
  }
  response[0] = 0x80u;
  response[1] = 0x02u;
  test_put_be32(response + 2u, response_len);
  test_put_be32(response + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response + ER_TPM_HEADER_LEN, 4u + ER_TPM_AES_BLOCK_LEN + ER_TPM_AES_BLOCK_LEN);
  test_put_be16(response + 14u, ER_TPM_AES_BLOCK_LEN);
  test_fill_bytes(response + 16u, ER_TPM_AES_BLOCK_LEN, TEST_TLS_TPM_CIPHER_SEED);
  test_put_be16(response + 32u, ER_TPM_AES_BLOCK_LEN);
  test_fill_bytes(response + 34u, ER_TPM_AES_BLOCK_LEN, TEST_TLS_TPM_IV_SEED);
  *out_response_len = response_len;
  return 1u;
}

static UINT8 test_tls_tpm_point_response(UINT8* response,
                                         UINT32 response_capacity,
                                         UINT32* out_response_len) {
  UINT32 response_len = ER_TPM_HEADER_LEN + 2u + 2u + 32u + 2u + 32u;

  if (response_capacity < response_len) {
    return 0u;
  }
  test_tls_tpm_response_header(response, response_len);
  test_put_be16(response + 10u, 68u);
  test_put_be16(response + 12u, 32u);
  test_fill_bytes(response + 14u, 32u, TEST_TLS_TPM_POINT_X_SEED);
  test_put_be16(response + 46u, 32u);
  test_fill_bytes(response + 48u, 32u, TEST_TLS_TPM_POINT_Y_SEED);
  *out_response_len = response_len;
  return 1u;
}

static UINT8 test_tls_tpm_verify_response(UINT8* response,
                                          UINT32 response_capacity,
                                          UINT32* out_response_len) {
  if (response_capacity < 18u) {
    return 0u;
  }
  test_tls_tpm_response_header(response, 18u);
  test_put_be16(response + 10u, ER_TPM_ST_HASHCHECK);
  test_put_be32(response + 12u, ER_TPM_RH_NULL);
  test_put_be16(response + 16u, 0u);
  *out_response_len = 18u;
  return 1u;
}

static UINT8 test_tls_tpm_signature_response(UINT8* response,
                                             UINT32 response_capacity,
                                             UINT32* out_response_len) {
  UINT32 response_len = ER_TPM_HEADER_LEN + 4u + 2u + 32u + 2u + 32u;

  if (response_capacity < response_len) {
    return 0u;
  }
  test_tls_tpm_response_header(response, response_len);
  test_put_be16(response + 10u, ER_TPM_ALG_ECDSA);
  test_put_be16(response + 12u, ER_TPM_ALG_SHA256);
  test_put_be16(response + 14u, 32u);
  test_fill_bytes(response + 16u, 32u, 0x41u);
  test_put_be16(response + 48u, 32u);
  test_fill_bytes(response + 50u, 32u, 0x61u);
  *out_response_len = response_len;
  return 1u;
}

static UINT8 test_tls_tpm_create_primary_response(UINT8* response,
                                                  UINT32 response_capacity,
                                                  UINT32* out_response_len) {
  UINT32 offset;

  if (response_capacity < 126u) {
    return 0u;
  }
  response[0] = 0x80u;
  response[1] = 0x02u;
  test_put_be32(response + 2u, 126u);
  test_put_be32(response + 6u, ER_TPM_RC_SUCCESS);
  test_put_be32(response + 10u, TEST_TLS_TPM_HANDLE_ECDH);
  test_put_be32(response + 14u, 90u);
  offset = 18u;
  test_put_be16(response + offset, 88u);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ALG_ECC);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ALG_SHA256);
  offset += 2u;
  test_put_be32(response + offset, 0x00040472u);
  offset += 4u;
  test_put_be16(response + offset, 0u);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ALG_NULL);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ALG_ECDSA);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ALG_SHA256);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ECC_NIST_P256);
  offset += 2u;
  test_put_be16(response + offset, ER_TPM_ALG_NULL);
  offset += 2u;
  test_put_be16(response + offset, 32u);
  offset += 2u;
  test_fill_bytes(response + offset, 32u, TEST_TLS_TPM_PRIMARY_X_SEED);
  offset += 32u;
  test_put_be16(response + offset, 32u);
  offset += 2u;
  test_fill_bytes(response + offset, 32u, TEST_TLS_TPM_PRIMARY_Y_SEED);
  *out_response_len = 126u;
  return 1u;
}

static UINT8 test_tls_tpm_transact(void* user,
                                   const UINT8* command,
                                   UINT32 command_len,
                                   UINT8* response,
                                   UINT32 response_capacity,
                                   UINT32* out_response_len) {
  TestTlsTpmScript* script = (TestTlsTpmScript*)user;
  UINT32 command_code;

  if (script == 0 || command == 0 || response == 0 || out_response_len == 0 ||
      command_len > sizeof(script->last_command)) {
    return 0u;
  }
  er_mem_copy(script->last_command, command, command_len);
  script->last_command_len = command_len;
  command_code = test_tls_tpm_read_be32(command + 6u);
  script->last_command_code = command_code;
  ++script->calls;

  switch (command_code) {
    case ER_TPM_CC_GET_RANDOM:
      return test_tls_tpm_random_response(command, response, response_capacity, out_response_len);
    case ER_TPM_CC_HASH:
    case ER_TPM_CC_HMAC:
      return test_tls_tpm_digest_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_LOAD_EXTERNAL:
      if (command_len == 60u) return test_tls_tpm_handle_response(response, response_capacity, out_response_len, TEST_TLS_TPM_HANDLE_AES);
      if (command_len == 74u) return test_tls_tpm_handle_response(response, response_capacity, out_response_len, TEST_TLS_TPM_HANDLE_HMAC);
      return test_tls_tpm_handle_response(response, response_capacity, out_response_len, TEST_TLS_TPM_HANDLE_VERIFY);
    case ER_TPM_CC_ENCRYPT_DECRYPT2:
      return test_tls_tpm_crypt_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_CREATE_PRIMARY:
      return test_tls_tpm_create_primary_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_ECDH_ZGEN:
      return test_tls_tpm_point_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_VERIFY_SIGNATURE:
      return test_tls_tpm_verify_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_SIGN:
      return test_tls_tpm_signature_response(response, response_capacity, out_response_len);
    case ER_TPM_CC_FLUSH_CONTEXT:
      test_tls_tpm_response_header(response, ER_TPM_HEADER_LEN);
      *out_response_len = ER_TPM_HEADER_LEN;
      return 1u;
    default:
      return 0u;
  }
}

static void test_tls_tpm_profiles(ErTpm2Info* info,
                                  ErTpmAlgorithmProfile* algorithms,
                                  ErTpmCommandProfile* commands) {
  er_mem_zero((UINT8*)info, (UINTN)sizeof(*info));
  er_mem_zero((UINT8*)algorithms, (UINTN)sizeof(*algorithms));
  er_mem_zero((UINT8*)commands, (UINTN)sizeof(*commands));

  info->found = 1u;
  info->control_area = 0x1000u;
  info->start_method = TEST_TLS_TPM_START_METHOD_CRB;
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
  commands->has_hmac = 1u;
  commands->has_load_external = 1u;
  commands->has_sign = 1u;
  commands->has_verify_signature = 1u;
}

static void test_tls_tpm_adapter(void) {
  TestTlsTpmScript script;
  ErTpm2Info info;
  ErTpmAlgorithmProfile algorithms;
  ErTpmCommandProfile commands;
  ErTpmP256Primary primary;
  ErTlsTpm tls_tpm;
  UINT8 random[ER_TPM_SHA256_DIGEST_LEN];
  UINT8 digest[ER_TPM_SHA256_DIGEST_LEN];
  UINT8 key[ER_TPM_AES_128_KEY_LEN];
  UINT8 iv[ER_TPM_AES_BLOCK_LEN];
  UINT8 cipher[ER_TPM_AES_BLOCK_LEN];
  UINT8 out_iv[ER_TPM_AES_BLOCK_LEN];
  UINT8 point[ER_TPM_P256_PUBLIC_KEY_LEN];
  UINT8 signature[64];
  UINT32 handle;
  UINT32 out_len;
  UINT32 out_iv_len;

  er_mem_zero((UINT8*)&script, (UINTN)sizeof(script));
  test_tls_tpm_profiles(&info, &algorithms, &commands);
  check_int64("tls tpm init",
              er_tls_tpm_init(&tls_tpm, test_tls_tpm_transact, &script,
                              &info, &algorithms, &commands),
              1);
  check_uint64("tls tpm record mode", er_tls_tpm_record_mode(&tls_tpm), ER_TPM_ALG_CTR);

  commands.has_hmac = 0u;
  check_int64("tls tpm init rejects incomplete profile",
              er_tls_tpm_init(&tls_tpm, test_tls_tpm_transact, &script,
                              &info, &algorithms, &commands),
              0);
  commands.has_hmac = 1u;

  check_int64("tls tpm random",
              er_tls_tpm_get_random(&tls_tpm, random, ER_TPM_SHA256_DIGEST_LEN), 1);
  check_uint64("tls tpm random command", script.last_command_code, ER_TPM_CC_GET_RANDOM);
  check_uint64("tls tpm random byte", random[0], TEST_TLS_TPM_RANDOM_SEED);

  check_int64("tls tpm sha256",
              er_tls_tpm_sha256(&tls_tpm, random, ER_TPM_SHA256_DIGEST_LEN, digest), 1);
  check_uint64("tls tpm hash command", script.last_command_code, ER_TPM_CC_HASH);
  check_uint64("tls tpm hash byte", digest[0], TEST_TLS_TPM_DIGEST_SEED);

  test_fill_bytes(key, (UINTN)sizeof(key), 0xc0u);
  check_int64("tls tpm load hmac",
              er_tls_tpm_load_hmac_sha256_key(&tls_tpm, digest, ER_TPM_SHA256_DIGEST_LEN, &handle), 1);
  check_uint64("tls tpm hmac handle", handle, TEST_TLS_TPM_HANDLE_HMAC);
  check_int64("tls tpm hmac",
              er_tls_tpm_hmac_sha256(&tls_tpm, handle, random, ER_TPM_SHA256_DIGEST_LEN, digest), 1);
  check_uint64("tls tpm hmac command", script.last_command_code, ER_TPM_CC_HMAC);

  check_int64("tls tpm load aes",
              er_tls_tpm_load_aes_key(&tls_tpm, key, ER_TPM_AES_128_KEY_LEN, ER_TPM_AES_128_KEY_BITS, &handle), 1);
  check_uint64("tls tpm aes handle", handle, TEST_TLS_TPM_HANDLE_AES);
  check_uint64("tls tpm aes mode", script.last_command[53], ER_TPM_ALG_CTR);

  test_fill_bytes(iv, (UINTN)sizeof(iv), 0x50u);
  check_int64("tls tpm record crypt",
              er_tls_tpm_record_crypt(&tls_tpm, handle, 0u,
                                      iv, ER_TPM_AES_BLOCK_LEN,
                                      random, ER_TPM_AES_BLOCK_LEN,
                                      cipher, (UINT32)sizeof(cipher), &out_len,
                                      out_iv, (UINT32)sizeof(out_iv), &out_iv_len),
              1);
  check_uint64("tls tpm crypt command", script.last_command_code, ER_TPM_CC_ENCRYPT_DECRYPT2);
  check_uint64("tls tpm crypt len", out_len, ER_TPM_AES_BLOCK_LEN);
  check_uint64("tls tpm crypt byte", cipher[0], TEST_TLS_TPM_CIPHER_SEED);
  check_uint64("tls tpm crypt iv len", out_iv_len, ER_TPM_AES_BLOCK_LEN);
  check_uint64("tls tpm crypt iv byte", out_iv[0], TEST_TLS_TPM_IV_SEED);

  check_int64("tls tpm create ecdh",
              er_tls_tpm_create_p256_ecdh_key(&tls_tpm, &primary), 1);
  check_uint64("tls tpm primary handle", primary.handle, TEST_TLS_TPM_HANDLE_ECDH);
  check_uint64("tls tpm primary x", primary.public_key[0], TEST_TLS_TPM_PRIMARY_X_SEED);
  check_int64("tls tpm ecdh zgen",
              er_tls_tpm_ecdh_zgen(&tls_tpm, primary.handle, primary.public_key, point), 1);
  check_uint64("tls tpm ecdh command", script.last_command_code, ER_TPM_CC_ECDH_ZGEN);
  check_uint64("tls tpm ecdh x", point[0], TEST_TLS_TPM_POINT_X_SEED);
  check_uint64("tls tpm ecdh y", point[32], TEST_TLS_TPM_POINT_Y_SEED);

  check_int64("tls tpm load verify",
              er_tls_tpm_load_p256_verify_key(&tls_tpm, primary.public_key, &handle), 1);
  check_uint64("tls tpm verify handle", handle, TEST_TLS_TPM_HANDLE_VERIFY);
  test_fill_bytes(signature, (UINTN)sizeof(signature), 0x20u);
  check_int64("tls tpm verify",
              er_tls_tpm_verify_p256_sha256(&tls_tpm, handle, digest, signature), 1);
  check_uint64("tls tpm verify command", script.last_command_code, ER_TPM_CC_VERIFY_SIGNATURE);

  check_int64("tls tpm sign",
              er_tls_tpm_sign_p256_sha256(&tls_tpm, primary.handle, digest, signature), 1);
  check_uint64("tls tpm sign command", script.last_command_code, ER_TPM_CC_SIGN);
  check_uint64("tls tpm sign r", signature[0], 0x41u);
  check_uint64("tls tpm sign s", signature[32], 0x61u);

  check_int64("tls tpm flush", er_tls_tpm_flush(&tls_tpm, primary.handle), 1);
  check_uint64("tls tpm flush command", script.last_command_code, ER_TPM_CC_FLUSH_CONTEXT);
  check_uint64("tls tpm calls", script.calls, 12u);
}
