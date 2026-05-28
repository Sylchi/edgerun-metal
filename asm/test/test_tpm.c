// EdgeRun TPM2 wire protocol test harness
// Uses HOSTED_TEST build: command buffers are captured to a global buffer.
// Freestanding — no libc.

typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned long      size_t;

extern void* er_memset(void* dst, int value, size_t num);
extern void* er_memcpy(void* dst, const void* src, size_t num);
extern int   er_memcmp(const void* ptr1, const void* ptr2, size_t num);

extern uint8_t  er_tpm_tx_buffer[4096];
extern uint64_t er_tpm_tx_count;
extern uint8_t  er_crb_shadow[4096];

extern uint8_t* er_tpm_startup(uint8_t* buf);
extern uint8_t* er_tpm_get_random(uint8_t* buf, uint16_t bytes);
extern uint8_t* er_tpm_get_capability(uint8_t* buf, uint32_t capability,
                                      uint32_t property, uint32_t property_count);
extern uint32_t er_tpm_response_code(uint8_t* response, uint32_t length);
extern uint8_t  er_tpm_response_success(uint8_t* response, uint32_t length);
extern uint32_t er_tpm_parse_get_random(uint8_t* response, uint32_t length,
                                        uint8_t* out, uint32_t out_size);
extern uint8_t  er_tpm_has_algorithm(uint8_t* response, uint32_t length,
                                     uint16_t alg_id);
extern uint8_t  er_tpm_has_command(uint8_t* response, uint32_t length,
                                   uint32_t cmd_code);
extern uint8_t  er_tpm_crb_present(void);
extern uint32_t er_tpm_crb_transfer(uint8_t* cmd, uint32_t cmd_size,
                                    uint8_t* rsp, uint32_t rsp_max);
extern uint32_t er_tpm_crb_command(uint8_t* cmd, uint32_t cmd_size,
                                   uint8_t* rsp, uint32_t rsp_max);

// New command builders
extern uint8_t* er_tpm_shutdown(uint8_t* buf, uint16_t shutdown_type);
extern uint8_t* er_tpm_flush_context(uint8_t* buf, uint32_t handle);
extern uint8_t* er_tpm_read_public(uint8_t* buf, uint32_t handle);
extern uint8_t* er_tpm_hash_sha256(uint8_t* buf, const uint8_t* data,
                                   uint32_t data_len, uint32_t hierarchy);
extern uint8_t* er_tpm_hash_sequence_start(uint8_t* buf);
extern uint8_t* er_tpm_sequence_update(uint8_t* buf, uint32_t handle,
                                       const uint8_t* data, uint32_t data_len);
extern uint8_t* er_tpm_sequence_complete(uint8_t* buf, uint32_t handle,
                                         const uint8_t* data, uint32_t data_len,
                                         uint32_t hierarchy);
extern uint8_t* er_tpm_hmac_sha256(uint8_t* buf, uint32_t handle,
                                   const uint8_t* data, uint32_t data_len);
extern uint8_t* er_tpm_sign_p256_sha256(uint8_t* buf, uint32_t handle,
                                        const uint8_t* digest);
extern uint8_t* er_tpm_verify_p256_sha256(uint8_t* buf, uint32_t handle,
                                          const uint8_t* digest,
                                          const uint8_t* sig_r,
                                          const uint8_t* sig_s);
extern uint8_t* er_tpm_create_primary_p256_signing(uint8_t* buf);
extern uint8_t* er_tpm_create_primary_p256_ecdh(uint8_t* buf);
extern uint8_t* er_tpm_load_external_p256_verify(uint8_t* buf,
                                                  const uint8_t* public_key);
extern uint8_t* er_tpm_ecdh_zgen_p256(uint8_t* buf, uint32_t handle,
                                       const uint8_t* peer_point);
extern uint8_t* er_tpm_encrypt_decrypt2(uint8_t* buf, uint32_t handle,
                                        const uint8_t* input, uint32_t input_len,
                                        const uint8_t* iv, uint16_t mode);

// New response parsers
extern uint32_t er_tpm_parse_handle(uint8_t* response, uint32_t length);
extern uint32_t er_tpm_parse_sha256_digest(uint8_t* response, uint32_t length,
                                           uint8_t* out);

static void store_be16(uint8_t* p, uint16_t v) {
    p[0] = (v >> 8) & 0xFF;
    p[1] = v & 0xFF;
}
static void store_be32(uint8_t* p, uint32_t v) {
    p[0] = (v >> 24) & 0xFF;
    p[1] = (v >> 16) & 0xFF;
    p[2] = (v >> 8) & 0xFF;
    p[3] = v & 0xFF;
}
static uint16_t load_be16(const uint8_t* p) {
    return (uint16_t)p[0] << 8 | p[1];
}
static uint32_t load_be32(const uint8_t* p) {
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 |
           (uint32_t)p[2] << 8 | p[3];
}

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
} while(0)

static void reset_tx(void) {
    er_tpm_tx_count = 0;
    er_memset(er_tpm_tx_buffer, 0, sizeof(er_tpm_tx_buffer));
}

static void fill_response(uint8_t* buf, uint32_t size) {
    er_memcpy(er_crb_shadow + 0x800, buf, size);
}

int main(void) {
    uint8_t cmd_buf[512];
    uint8_t rsp_buf[512];
    uint8_t out_buf[64];

    {
        reset_tx();
        uint8_t* result = er_tpm_startup(cmd_buf);
        TEST("startup returns non-null", result != 0);
        TEST("startup returns same buffer", result == cmd_buf);

        TEST("startup tag = 0x8001", load_be16(cmd_buf + 0) == 0x8001);
        TEST("startup size = 12",    load_be32(cmd_buf + 2) == 12);
        TEST("startup cc = 0x144",   load_be32(cmd_buf + 6) == 0x00000144);
        TEST("startup type = SU_CLEAR", load_be16(cmd_buf + 10) == 0x0000);
    }

    {
        reset_tx();
        uint8_t* result = er_tpm_get_random(cmd_buf, 16);
        TEST("get_random returns non-null", result != 0);
        TEST("get_random tag = 0x8001",  load_be16(cmd_buf + 0) == 0x8001);
        TEST("get_random size = 12",     load_be32(cmd_buf + 2) == 12);
        TEST("get_random cc = 0x17b",    load_be32(cmd_buf + 6) == 0x0000017b);
        TEST("get_random count = 16",    load_be16(cmd_buf + 10) == 16);

        result = er_tpm_get_random(cmd_buf, 0);
        TEST("get_random zero bytes returns null", result == 0);
    }

    {
        reset_tx();
        uint8_t* result = er_tpm_get_capability(cmd_buf, 0x00000000, 0, 32);
        TEST("get_cap returns non-null", result != 0);
        TEST("get_cap tag = 0x8001",   load_be16(cmd_buf + 0) == 0x8001);
        TEST("get_cap size = 22",      load_be32(cmd_buf + 2) == 22);
        TEST("get_cap cc = 0x17a",     load_be32(cmd_buf + 6) == 0x0000017a);
        TEST("get_cap cap = ALGS",     load_be32(cmd_buf + 10) == 0x00000000);

        result = er_tpm_get_capability(cmd_buf, 0x00000000, 0, 0);
        TEST("get_cap zero count returns null", result == 0);
    }

    {
        uint8_t ok_rsp[10];
        store_be16(ok_rsp + 0, 0x8001);
        store_be32(ok_rsp + 2, 10);
        store_be32(ok_rsp + 6, 0x00000000);

        uint32_t rc = er_tpm_response_code(ok_rsp, 10);
        TEST("success response code = 0", rc == 0);

        uint8_t ok = er_tpm_response_success(ok_rsp, 10);
        TEST("success returns 1", ok == 1);

        uint8_t fail_rsp[10];
        store_be16(fail_rsp + 0, 0x8001);
        store_be32(fail_rsp + 2, 10);
        store_be32(fail_rsp + 6, 0x0000012b);

        ok = er_tpm_response_success(fail_rsp, 10);
        TEST("failure returns 0", ok == 0);

        rc = er_tpm_response_code(ok_rsp, 5);
        TEST("short response rc = 0xFFFFFFFC", rc == 0xFFFFFFFC);

        uint8_t bad_rsp[12];
        store_be16(bad_rsp + 0, 0x8001);
        store_be32(bad_rsp + 2, 10);
        store_be32(bad_rsp + 6, 0x00000000);
        rc = er_tpm_response_code(bad_rsp, 12);
        TEST("mismatched size rc = 0xFFFFFFFC", rc == 0xFFFFFFFC);
    }

    {
        uint8_t rsp[28];
        store_be16(rsp + 0, 0x8001);
        store_be32(rsp + 2, 28);
        store_be32(rsp + 6, 0x00000000);
        store_be16(rsp + 10, 16);
        er_memset(rsp + 12, 0xAB, 16);

        uint32_t n = er_tpm_parse_get_random(rsp, 28, out_buf, 64);
        TEST("parsed random count = 16", n == 16);
        TEST("parsed random bytes correct",
             out_buf[0] == 0xAB && out_buf[15] == 0xAB);

        n = er_tpm_parse_get_random(rsp, 10, out_buf, 64);
        TEST("truncated rsp returns 0", n == 0);
    }

    {
        uint8_t rsp[10 + 1 + 4 + 4 + 6 * 3];
        int ofs = 0;
        store_be16(rsp + ofs, 0x8001); ofs += 2;
        store_be32(rsp + ofs, sizeof(rsp)); ofs += 4;
        store_be32(rsp + ofs, 0x00000000); ofs += 4;
        rsp[ofs++] = 0x00;
        store_be32(rsp + ofs, 0x00000000); ofs += 4;
        store_be32(rsp + ofs, 3); ofs += 4;
        store_be16(rsp + ofs, 0x000b); ofs += 2;
        store_be16(rsp + ofs, 0); ofs += 2;
        store_be16(rsp + ofs, 0); ofs += 2;
        store_be16(rsp + ofs, 0x0005); ofs += 2;
        store_be16(rsp + ofs, 0); ofs += 2;
        store_be16(rsp + ofs, 0); ofs += 2;
        store_be16(rsp + ofs, 0x0023); ofs += 2;
        store_be16(rsp + ofs, 0); ofs += 2;
        store_be16(rsp + ofs, 0); ofs += 2;

        uint8_t found = er_tpm_has_algorithm(rsp, sizeof(rsp), 0x000b);
        TEST("has SHA256 = 1", found == 1);

        found = er_tpm_has_algorithm(rsp, sizeof(rsp), 0x0023);
        TEST("has ECC = 1", found == 1);

        found = er_tpm_has_algorithm(rsp, sizeof(rsp), 0x0006);
        TEST("no AES = 0", found == 0);

        found = er_tpm_has_algorithm(rsp, 10, 0x000b);
        TEST("short rsp has alg = 0", found == 0);
    }

    {
        uint8_t present = er_tpm_crb_present();
        TEST("crb present (hosted test)", present == 1);
    }

    {
        uint8_t* cmd = er_tpm_startup(cmd_buf);
        TEST("startup cmd != NULL", cmd != 0);

        uint8_t ok_rsp[10];
        store_be16(ok_rsp + 0, 0x8001);
        store_be32(ok_rsp + 2, 10);
        store_be32(ok_rsp + 6, 0x00000000);
        er_memcpy(er_crb_shadow + 0x800, ok_rsp, 10);

        uint32_t n = er_tpm_crb_transfer(cmd_buf, 12, rsp_buf, sizeof(rsp_buf));
        TEST("crb transfer returns > 0", n > 0);
        uint8_t ok = er_tpm_response_success(rsp_buf, n);
        TEST("crb response success", ok == 1);
    }

    // ─── New command builder tests ────────────────────────────────

    {
        uint8_t* result = er_tpm_flush_context(cmd_buf, 0x80000001);
        TEST("flush_context returns non-null", result != 0);
        TEST("flush_context tag = 0x8001", load_be16(cmd_buf + 0) == 0x8001);
        TEST("flush_context size = 14", load_be32(cmd_buf + 2) == 14);
        TEST("flush_context cc = 0x165", load_be32(cmd_buf + 6) == 0x00000165);
        TEST("flush_context handle = 0x80000001",
             load_be32(cmd_buf + 10) == 0x80000001);

        result = er_tpm_flush_context(cmd_buf, 0);
        TEST("flush_context zero handle returns null", result == 0);
    }

    {
        uint8_t* result = er_tpm_read_public(cmd_buf, 0x80000001);
        TEST("read_public returns non-null", result != 0);
        TEST("read_public size = 14", load_be32(cmd_buf + 2) == 14);
        TEST("read_public cc = 0x173", load_be32(cmd_buf + 6) == 0x00000173);
    }

    {
        uint8_t* result = er_tpm_hash_sequence_start(cmd_buf);
        TEST("hash_sequence_start returns non-null", result != 0);
        TEST("hash_sequence_start size = 18",
             load_be32(cmd_buf + 2) == 18);
        TEST("hash_sequence_start cc = 0x186",
             load_be32(cmd_buf + 6) == 0x00000186);
        TEST("hash_sequence_start alg = SHA256",
             load_be16(cmd_buf + 10) == 0x000B);
        TEST("hash_sequence_start hierarchy = RH_NULL",
             load_be32(cmd_buf + 12) == 0x40000007);
    }

    {
        uint8_t data[4] = {0x01, 0x02, 0x03, 0x04};
        uint8_t* result = er_tpm_hash_sha256(cmd_buf, data, 4, 0x40000007);
        TEST("hash_sha256 returns non-null", result != 0);
        TEST("hash_sha256 size = 24", load_be32(cmd_buf + 2) == 24);
        TEST("hash_sha256 cc = 0x17d",
             load_be32(cmd_buf + 6) == 0x0000017d);
        TEST("hash_sha256 data len = 4", load_be16(cmd_buf + 10) == 4);
        TEST("hash_sha256 data[0] = 0x01", cmd_buf[12] == 0x01);
        TEST("hash_sha256 data[3] = 0x04", cmd_buf[15] == 0x04);
        TEST("hash_sha256 alg = SHA256",
             load_be16(cmd_buf + 16) == 0x000B);
        TEST("hash_sha256 hierarchy = RH_NULL",
             load_be32(cmd_buf + 18) == 0x40000007);

        result = er_tpm_hash_sha256(cmd_buf, data, 0, 0x40000007);
        TEST("hash_sha256 zero data returns null", result == 0);
    }

    {
        uint8_t data[4] = {0x01, 0x02, 0x03, 0x04};
        uint8_t* result = er_tpm_sequence_update(cmd_buf, 0x80000001,
                                                  data, 4);
        TEST("sequence_update returns non-null", result != 0);
        TEST("sequence_update size = 33",
             load_be32(cmd_buf + 2) == 33);
        TEST("sequence_update cc = 0x15c",
             load_be32(cmd_buf + 6) == 0x0000015c);
        TEST("sequence_update tag = 0x8002",
             load_be16(cmd_buf + 0) == 0x8002);
    }

    {
        uint8_t data[4] = {0x01, 0x02, 0x03, 0x04};
        uint8_t* result = er_tpm_hmac_sha256(cmd_buf, 0x80000001, data, 4);
        TEST("hmac_sha256 returns non-null", result != 0);
        TEST("hmac_sha256 size = 35",
             load_be32(cmd_buf + 2) == 35);
        TEST("hmac_sha256 cc = 0x155",
             load_be32(cmd_buf + 6) == 0x00000155);
    }

    {
        uint8_t digest[32];
        er_memset(digest, 0xAB, 32);
        uint8_t* result = er_tpm_sign_p256_sha256(cmd_buf, 0x80000001,
                                                    digest);
        TEST("sign_p256 returns non-null", result != 0);
        TEST("sign_p256 size = 73", load_be32(cmd_buf + 2) == 73);
        TEST("sign_p256 cc = 0x15d",
             load_be32(cmd_buf + 6) == 0x0000015d);
        TEST("sign_p256 tag = 0x8002",
             load_be16(cmd_buf + 0) == 0x8002);
    }

    {
        uint8_t digest[32];
        uint8_t sig_r[32], sig_s[32];
        er_memset(digest, 0xAB, 32);
        er_memset(sig_r, 0xCD, 32);
        er_memset(sig_s, 0xEF, 32);
        uint8_t* result = er_tpm_verify_p256_sha256(cmd_buf, 0x80000001,
                                                     digest, sig_r, sig_s);
        TEST("verify_p256 returns non-null", result != 0);
        TEST("verify_p256 size = 120",
             load_be32(cmd_buf + 2) == 120);
        TEST("verify_p256 cc = 0x177",
             load_be32(cmd_buf + 6) == 0x00000177);
    }

    {
        uint8_t* result = er_tpm_create_primary_p256_signing(cmd_buf);
        TEST("create_primary_signing returns non-null", result != 0);
        TEST("create_primary size = 65",
             load_be32(cmd_buf + 2) == 65);
        TEST("create_primary cc = 0x131",
             load_be32(cmd_buf + 6) == 0x00000131);
        TEST("create_primary rh_owner = 0x40000001",
             load_be32(cmd_buf + 10) == 0x40000001);

        result = er_tpm_create_primary_p256_ecdh(cmd_buf);
        TEST("create_primary_ecdh returns non-null", result != 0);
        TEST("create_primary_ecdh size = 65",
             load_be32(cmd_buf + 2) == 65);
    }

    {
        uint8_t pub_key[64];
        er_memset(pub_key, 0x42, 64);
        uint8_t* result = er_tpm_load_external_p256_verify(cmd_buf, pub_key);
        TEST("load_ext_p256 returns non-null", result != 0);
        TEST("load_ext_p256 size = 106",
             load_be32(cmd_buf + 2) == 106);
        TEST("load_ext_p256 cc = 0x167",
             load_be32(cmd_buf + 6) == 0x00000167);
        TEST("load_ext_p256 X[0] = 0x42", cmd_buf[36] == 0x42);
        TEST("load_ext_p256 X[31] = 0x42", cmd_buf[67] == 0x42);
        TEST("load_ext_p256 Y[0] = 0x42", cmd_buf[70] == 0x42);
        TEST("load_ext_p256 Y[31] = 0x42", cmd_buf[101] == 0x42);
    }

    {
        uint8_t point[64];
        er_memset(point, 0x77, 64);
        uint8_t* result = er_tpm_ecdh_zgen_p256(cmd_buf, 0x80000001, point);
        TEST("ecdh_zgen returns non-null", result != 0);
        TEST("ecdh_zgen size = 97",
             load_be32(cmd_buf + 2) == 97);
        TEST("ecdh_zgen cc = 0x154",
             load_be32(cmd_buf + 6) == 0x00000154);
        TEST("ecdh_zgen X[0] = 0x77", cmd_buf[31] == 0x77);
        TEST("ecdh_zgen Y[0] = 0x77", cmd_buf[65] == 0x77);
    }

    {
        uint8_t iv[16];
        uint8_t input[8] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08};
        er_memset(iv, 0xAA, 16);
        uint8_t* result = er_tpm_encrypt_decrypt2(cmd_buf, 0x80000001,
                                                   input, 8, iv, 0x0043);
        TEST("encrypt_decrypt2 returns non-null", result != 0);
        TEST("encrypt_decrypt2 size = 60"
             "(34+16+8+2)", load_be32(cmd_buf + 2) == 60);
        TEST("encrypt_decrypt2 cc = 0x193",
             load_be32(cmd_buf + 6) == 0x00000193);
    }

    // ─── Response parser tests ────────────────────────────────────

    {
        uint8_t rsp[26];
        store_be16(rsp + 0, 0x8001);
        store_be32(rsp + 2, 26);
        store_be32(rsp + 6, 0x00000000);
        store_be32(rsp + 10, 0x80000001);
        store_be16(rsp + 14, 32);
        er_memset(rsp + 16, 0xBB, 32);

        uint32_t handle = er_tpm_parse_handle(rsp, 26);
        TEST("parse_handle = 0x80000001", handle == 0x80000001);

        uint32_t n = er_tpm_parse_sha256_digest(rsp, 26, out_buf);
        TEST("parse_sha256_digest count = 32", n == 32);
        TEST("parse_sha256_digest data[0] = 0xBB", out_buf[0] == 0xBB);
        TEST("parse_sha256_digest data[31] = 0xBB", out_buf[31] == 0xBB);
    }

    return (passed_tests == total_tests) ? 0 : 1;
}
