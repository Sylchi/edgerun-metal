// EdgeRun preimage test — freestanding
// Tests domain-separated BLAKE3 hashing via preimage.asm

typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned long      size_t;

extern int  er_memcmp(const void* a, const void* b, size_t n);
extern void er_memset(void* s, int c, size_t n);
extern int  er_blake3_hash_bytes(const uint8_t* input, size_t len, uint8_t* out);

extern int  er_preimage_hash(const void* domain, uint32_t domain_len,
                             const void* value, uint32_t value_len,
                             uint8_t* out32);
extern int  er_preimage_raw_hash(const void* value, uint32_t value_len,
                                 uint8_t* out32);
extern void er_preimage_builder_init(void* state, const void* domain,
                                     uint32_t domain_len);
extern int  er_preimage_builder_update(void* state, const void* data,
                                       uint32_t data_len);
extern int  er_preimage_builder_final(void* state, uint8_t* out32);

extern int  er_preimage_builder_id(void* state, const uint8_t id[32]);
extern int  er_preimage_builder_hash(void* state, const uint8_t hash[32]);
extern void er_preimage_builder_write_u64(void* state, uint64_t value);
extern int  er_preimage_encode_epoch(const void* stamp, uint8_t* out, uint32_t out_len);
extern int  er_preimage_decode_epoch(const uint8_t* in, uint32_t in_len, void* stamp);
extern void er_preimage_writer_init(void* writer, uint8_t* buf, uint64_t len);
extern uint64_t er_preimage_writer_written(const void* writer);
extern int  er_preimage_writer_raw(void* writer, const uint8_t* data, uint64_t len);
extern int  er_preimage_writer_write_u16(void* writer, uint16_t value);
extern int  er_preimage_writer_write_u32(void* writer, uint32_t value);
extern int  er_preimage_writer_write_u64(void* writer, uint64_t value);
extern int  er_preimage_writer_id(void* writer, const uint8_t id[32]);
extern int  er_preimage_writer_hash(void* writer, const uint8_t hash[32]);
extern int  er_preimage_writer_epoch(void* writer, const void* stamp);
extern int  er_keeper_id_valid(const uint8_t* keeper);

#define PREIMAGE_BUFFER_SIZE 4096
#define HASH_SIZE 32
#define KEEPER_ID_SIZE 32
#define EPOCH_SIZE 64

// Preimage state structure (must match preimage.asm)
struct preimage_state {
    uint8_t  buffer[PREIMAGE_BUFFER_SIZE];
    uint32_t pos;
    uint32_t domain_len;
    uint64_t pad;
};

// Stamp structure (must match clock.asm)
struct stamp {
    uint8_t  keeper[32];
    uint64_t tick;
    uint64_t slot;
    uint64_t epoch;
    uint64_t era;
};

// Writer structure (must match preimage.asm)
struct writer_state {
    uint8_t* buf;
    uint64_t len;
    uint64_t pos;
};

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
    else { writes("FAIL: "); writes(name); writes("\n"); } \
} while(0)

static void writes(const char* s) {
    while (*s) {
        __asm__ volatile (
            "mov $1, %%rax\nmov $1, %%rdi\nmov %0, %%rsi\nmov $1, %%rdx\nsyscall"
            :: "r"(s) : "rax", "rdi", "rsi", "rdx", "memory"
        );
        s++;
    }
}

static void print_hex(const char* label, const uint8_t* data, size_t n) {
    size_t i;
    static const char hex[] = "0123456789abcdef";
    char buf[3];
    for (i = 0; i < n && i < 32; i++) {
        buf[0] = hex[data[i] >> 4];
        buf[1] = hex[data[i] & 0xf];
        buf[2] = '\n';
        __asm__ volatile (
            "mov $1, %%rax\n"
            "mov $1, %%rdi\n"
            "lea %0, %%rsi\n"
            "mov $3, %%rdx\n"
            "syscall"
            :: "m"(buf) : "rax", "rdi", "rsi", "rdx", "memory"
        );
    }
}

int main(void) {
    // ─── er_preimage_raw_hash vs known BLAKE3 vectors ────────────
    {
        // Raw hash of "abc" must match known BLAKE3("abc")
        uint8_t out[HASH_SIZE];
        static const uint8_t abc[] = {'a', 'b', 'c'};
        static const uint8_t expected[HASH_SIZE] = {
            0x64, 0x37, 0xb3, 0xac, 0x38, 0x46, 0x51, 0x33,
            0xff, 0xb6, 0x3b, 0x75, 0x27, 0x3a, 0x8d, 0xb5,
            0x48, 0xc5, 0x58, 0x46, 0x5d, 0x79, 0xdb, 0x03,
            0xfd, 0x35, 0x9c, 0x6c, 0xd5, 0xbd, 0x9d, 0x85
        };
        int r = er_preimage_raw_hash(abc, 3, out);
        TEST("raw_hash abc success", r == 1);
        TEST("raw_hash abc matches", er_memcmp(out, expected, HASH_SIZE) == 0);
    }
    {
        // Raw hash of empty input
        uint8_t out[HASH_SIZE];
        static const uint8_t expected[HASH_SIZE] = {
            0xaf, 0x13, 0x49, 0xb9, 0xf5, 0xf9, 0xa1, 0xa6,
            0xa0, 0x40, 0x4d, 0xea, 0x36, 0xdc, 0xc9, 0x49,
            0x9b, 0xcb, 0x25, 0xc9, 0xad, 0xc1, 0x12, 0xb7,
            0xcc, 0x9a, 0x93, 0xca, 0xe4, 0x1f, 0x32, 0x62
        };
        int r = er_preimage_raw_hash(0, 0, out);
        TEST("raw_hash empty success", r == 1);
        TEST("raw_hash empty matches", er_memcmp(out, expected, HASH_SIZE) == 0);
    }

    // ─── er_preimage_hash domain-separated ───────────────────────
    {
        // hash("test", "abc") must equal blake3("testabc")
        uint8_t out[HASH_SIZE];
        uint8_t expected[HASH_SIZE];
        static const uint8_t combined[] = {'t','e','s','t','a','b','c'};
        er_blake3_hash_bytes(combined, 7, expected);
        int r = er_preimage_hash("test", 4, "abc", 3, out);
        TEST("preimage_hash test+abc success", r == 1);
        TEST("preimage_hash test+abc matches blake3(testabc)",
             er_memcmp(out, expected, HASH_SIZE) == 0);
    }
    {
        // Different domains produce different hashes
        uint8_t hash1[HASH_SIZE], hash2[HASH_SIZE];
        er_preimage_hash("domain_a", 8, "value", 5, hash1);
        er_preimage_hash("domain_b", 8, "value", 5, hash2);
        TEST("different domains differ", er_memcmp(hash1, hash2, HASH_SIZE) != 0);
    }
    {
        // Same domain+value produce same hash
        uint8_t hash1[HASH_SIZE], hash2[HASH_SIZE];
        er_preimage_hash("same", 4, "data", 4, hash1);
        er_preimage_hash("same", 4, "data", 4, hash2);
        TEST("same domain+value same hash", er_memcmp(hash1, hash2, HASH_SIZE) == 0);
    }
    {
        // Empty domain test
        uint8_t out[HASH_SIZE];
        static const uint8_t value[] = {'a'};
        uint8_t expected[HASH_SIZE];
        er_blake3_hash_bytes(value, 1, expected);
        er_preimage_hash("", 0, value, 1, out);
        TEST("empty domain matches raw",
             er_memcmp(out, expected, HASH_SIZE) == 0);
    }

    // ─── Builder API ─────────────────────────────────────────────
    {
        // Builder init(domain) + update(value) + final = one-shot hash
        uint8_t one_shot[HASH_SIZE], builder_out[HASH_SIZE];
        struct preimage_state state;

        er_preimage_hash("builder", 7, "test", 4, one_shot);

        er_preimage_builder_init(&state, "builder", 7);
        er_preimage_builder_update(&state, "test", 4);
        er_preimage_builder_final(&state, builder_out);

        TEST("builder matches one-shot",
             er_memcmp(one_shot, builder_out, HASH_SIZE) == 0);
    }
    {
        // Builder with multiple updates
        struct preimage_state state;
        uint8_t one_shot[HASH_SIZE], builder_out[HASH_SIZE];

        er_preimage_hash("multi", 5, "abcdef", 6, one_shot);

        er_preimage_builder_init(&state, "multi", 5);
        er_preimage_builder_update(&state, "abc", 3);
        er_preimage_builder_update(&state, "def", 3);
        er_preimage_builder_final(&state, builder_out);

        TEST("builder multi-update matches",
             er_memcmp(one_shot, builder_out, HASH_SIZE) == 0);
    }
    {
        // Builder overflow check
        struct preimage_state state;
        er_preimage_builder_init(&state, "x", 1);

        // Fill buffer to exactly max
        char big[PREIMAGE_BUFFER_SIZE - 1];
        er_memset(big, 'A', sizeof(big));
        TEST("builder update full buffer", er_preimage_builder_update(&state, big, sizeof(big)) == 1);

        // One more byte should overflow
        TEST("builder overflow rejected", er_preimage_builder_update(&state, "!", 1) == 0);
    }

    // ─── Builder helper methods ──────────────────────────────────
    {
        // Builder.id appends 32 bytes from an Id
        struct preimage_state state;
        uint8_t id_bytes[32];
        er_memset(id_bytes, 0, 32);
        id_bytes[0] = 0xAA; id_bytes[1] = 0xBB;

        er_preimage_builder_init(&state, "dom", 3);
        TEST("builder.id succeeds", er_preimage_builder_id(&state, id_bytes) == 1);
        TEST("builder.id advances pos by 32", state.pos == 3 + 32);
        TEST("builder.id content match", er_memcmp(state.buffer + 3, id_bytes, 32) == 0);
    }
    {
        // Builder.hash appends 32 bytes
        struct preimage_state state;
        uint8_t hash_val[32];
        er_memset(hash_val, 0xCD, 32);

        er_preimage_builder_init(&state, "dom", 3);
        TEST("builder.hash succeeds", er_preimage_builder_hash(&state, hash_val) == 1);
        TEST("builder.hash advances pos by 32", state.pos == 3 + 32);
        TEST("builder.hash content match", er_memcmp(state.buffer + 3, hash_val, 32) == 0);
    }
    {
        // Builder.writeU64 appends 8 little-endian bytes
        struct preimage_state state;
        er_preimage_builder_init(&state, "dom", 3);
        er_preimage_builder_write_u64(&state, 0x0102030405060708ULL);
        TEST("builder.writeU64 advances pos by 8", state.pos == 3 + 8);
        TEST("builder.writeU64 byte 0", state.buffer[3] == 0x08);
        TEST("builder.writeU64 byte 7", state.buffer[10] == 0x01);
    }

    // ─── encodeEpoch / decodeEpoch ────────────────────────────────
    {
        uint8_t raw[64];
        struct stamp s;
        struct stamp decoded;
        er_memset(&s, 0, sizeof(s));
        s.keeper[0] = 0x42;
        s.tick = 1;
        s.slot = 2;
        s.epoch = 3;
        s.era = 4;

        int enc_ok = er_preimage_encode_epoch(&s, raw, 64);
        TEST("encodeEpoch success", enc_ok == 1);
        TEST("encodeEpoch keeper[0] matches", raw[0] == 0x42);
        TEST("encodeEpoch tick at offset 32", raw[32] == 1);
        TEST("encodeEpoch slot at offset 40", raw[40] == 2);
        TEST("encodeEpoch epoch at offset 48", raw[48] == 3);
        TEST("encodeEpoch era at offset 56", raw[56] == 4);

        int dec_ok = er_preimage_decode_epoch(raw, 64, &decoded);
        TEST("decodeEpoch success", dec_ok == 1);
        TEST("decodeEpoch keeper matches", er_memcmp(decoded.keeper, s.keeper, 32) == 0);
        TEST("decodeEpoch tick matches", decoded.tick == 1);
        TEST("decodeEpoch slot matches", decoded.slot == 2);
        TEST("decodeEpoch epoch matches", decoded.epoch == 3);
        TEST("decodeEpoch era matches", decoded.era == 4);
    }
    {
        // encode fails on too-small output
        uint8_t raw[10];
        struct stamp s;
        er_memset(&s, 0, sizeof(s));
        s.keeper[0] = 0x42;
        int r = er_preimage_encode_epoch(&s, raw, 10);
        TEST("encodeEpoch fails on small out", r == 0);
    }
    {
        // decode fails on too-small input
        uint8_t raw[10];
        struct stamp s;
        int r = er_preimage_decode_epoch(raw, 10, &s);
        TEST("decodeEpoch fails on small in", r == 0);
    }
    {
        // decode fails on invalid stamp (all-zero keeper)
        uint8_t raw[64];
        er_memset(raw, 0, 64);
        struct stamp s;
        int r = er_preimage_decode_epoch(raw, 64, &s);
        TEST("decodeEpoch invalid stamp rejected", r == 0);
    }

    // ─── Writer ───────────────────────────────────────────────────
    {
        // Writer init + written
        uint8_t buf[256];
        struct writer_state w;
        er_memset(buf, 0xFF, sizeof(buf));
        er_preimage_writer_init(&w, buf, 256);
        TEST("writer init zeros buffer", buf[0] == 0);
        TEST("writer init zeros buffer middle", buf[128] == 0);
        TEST("writer init pos=0", w.pos == 0);
        TEST("writer written=0", er_preimage_writer_written(&w) == 0);
    }
    {
        // Writer raw
        uint8_t buf[256];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 256);

        static const uint8_t data[] = {0x01, 0x02, 0x03, 0x04};
        int r = er_preimage_writer_raw(&w, data, 4);
        TEST("writer raw success", r == 1);
        TEST("writer raw pos=4", w.pos == 4);
        TEST("writer raw content", er_memcmp(buf, data, 4) == 0);

        r = er_preimage_writer_raw(&w, data, 4);
        TEST("writer raw second write", r == 1);
        TEST("writer raw pos=8 after second", w.pos == 8);
        TEST("writer written=8", er_preimage_writer_written(&w) == 8);
    }
    {
        // Writer raw overflow rejection
        uint8_t buf[4];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 4);

        static const uint8_t data[] = {1, 2, 3, 4};
        TEST("writer raw fits", er_preimage_writer_raw(&w, data, 4) == 1);
        TEST("writer overflow rejected", er_preimage_writer_raw(&w, data, 1) == 0);
        TEST("writer pos unchanged on overflow", w.pos == 4);
    }
    {
        // Writer id and hash
        uint8_t buf[128];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 128);

        uint8_t id_val[32];
        er_memset(id_val, 0xAA, 32);
        TEST("writer id success", er_preimage_writer_id(&w, id_val) == 1);
        TEST("writer id pos=32", w.pos == 32);
        TEST("writer id content", er_memcmp(buf, id_val, 32) == 0);

        uint8_t hash_val[32];
        er_memset(hash_val, 0xBB, 32);
        TEST("writer hash success", er_preimage_writer_hash(&w, hash_val) == 1);
        TEST("writer hash pos=64", w.pos == 64);
        TEST("writer hash content", er_memcmp(buf + 32, hash_val, 32) == 0);
    }
    {
        // Writer writeU16/U32/U64
        uint8_t buf[32];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 32);

        TEST("writeU16 success", er_preimage_writer_write_u16(&w, 0x0102) == 1);
        // LE: 0x02, 0x01
        TEST("writeU16 pos=2", w.pos == 2);
        TEST("writeU16 byte 0", buf[0] == 0x02);
        TEST("writeU16 byte 1", buf[1] == 0x01);

        TEST("writeU32 success", er_preimage_writer_write_u32(&w, 0x01020304) == 1);
        TEST("writeU32 pos=6", w.pos == 6);
        TEST("writeU32 byte 2", buf[2] == 0x04);

        TEST("writeU64 success", er_preimage_writer_write_u64(&w, 0x0102030405060708ULL) == 1);
        TEST("writeU64 pos=14", w.pos == 14);
        TEST("writeU64 byte 6", buf[6] == 0x08);
        TEST("writeU64 byte 13", buf[13] == 0x01);
    }
    {
        // Writer epoch
        uint8_t buf[128];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 128);

        struct stamp s;
        er_memset(&s, 0, sizeof(s));
        s.keeper[0] = 0x42;
        s.tick = 7;

        TEST("writer epoch success", er_preimage_writer_epoch(&w, &s) == 1);
        TEST("writer epoch pos=64", w.pos == 64);
        TEST("writer epoch keeper[0]", buf[0] == 0x42);
        TEST("writer epoch tick at offset 32", buf[32] == 7);
        TEST("writer written=64", er_preimage_writer_written(&w) == 64);
    }
    {
        // Writer epoch rejects invalid stamp
        uint8_t buf[128];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 128);

        struct stamp s;
        er_memset(&s, 0, sizeof(s));  // all-zero = invalid keeper
        TEST("writer epoch rejects invalid", er_preimage_writer_epoch(&w, &s) == 0);
        TEST("writer epoch pos unchanged on reject", w.pos == 0);
    }
    {
        // Writer epoch rejects when insufficient space
        uint8_t buf[60];
        struct writer_state w;
        er_preimage_writer_init(&w, buf, 60);

        struct stamp s;
        er_memset(&s, 0, sizeof(s));
        s.keeper[0] = 0x42;
        TEST("writer epoch fails on small buf", er_preimage_writer_epoch(&w, &s) == 0);
    }

    if (passed_tests == total_tests) {
        return 0;
    }
    return total_tests - passed_tests;
}
