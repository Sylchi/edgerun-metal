// EdgeRun object.asm test — freestanding

typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;

extern int  er_memcmp(const void* a, const void* b, uint64_t n);
extern void er_memset(void* s, int c, uint64_t n);

// object.asm functions
extern int  er_object_requirements_encode(uint8_t* out, const uint8_t* req);
extern int  er_object_requirements_decode(const uint8_t* in, uint8_t* req);
extern int  er_object_requirements_hash(const uint8_t* req, uint8_t* out);

extern int  er_object_header_encode(uint8_t* out, const uint8_t* header);
extern int  er_object_header_decode(const uint8_t* in, uint8_t* header);
extern int  er_object_header_id(const uint8_t* canonical, uint32_t len, uint8_t* out);

extern int  er_object_owner_encode(uint8_t* out, const uint8_t* owner);
extern int  er_object_owner_decode(const uint8_t* in, uint8_t* owner);

extern int  er_object_envelope_encode(uint8_t* out, const uint8_t* envelope, const uint8_t* owner);
extern int  er_object_envelope_decode(const uint8_t* in, uint8_t* envelope);
extern int  er_object_envelope_validate(const uint8_t* envelope, const uint8_t* owner);

extern int  er_object_child_encode(uint8_t* out, const uint8_t* child);
extern int  er_object_child_decode(const uint8_t* in, uint64_t expected_offset, uint8_t* child);

extern int  er_object_canonical_size(uint32_t kind, uint64_t body_len,
                                     uint16_t owners, uint16_t envelopes,
                                     uint32_t children, uint64_t* out_size);

extern int  er_object_view_decode(const uint8_t* canonical, uint32_t len,
                                   uint8_t* view);

// bytes.asm (dependency)
extern void er_bytes_zero(void* buf, uint32_t len);
extern int  er_bytes_nonzero(const void* buf, uint32_t len);
extern int  er_store16(void* out, uint32_t value);
extern int  er_store32(void* out, uint32_t value);
extern int  er_store64(void* out, uint64_t value);
extern int  er_load16(const void* in);
extern int  er_load32(const void* in);
extern int  er_load64(const void* in);

static volatile int total_tests = 0;
static volatile int passed_tests = 0;
static volatile int first_fail = 0;
static volatile int first_fail_val = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    int _test_res = (expr); \
    if (_test_res) { passed_tests++; } \
    else if (first_fail == 0) { \
        first_fail = total_tests; \
        first_fail_val = _test_res; \
    } \
} while(0)

#define REQ_SIZE 28
#define OWNER_SIZE 36
#define ENVELOPE_SIZE 76
#define CHILD_SIZE 84
#define HEADER_SIZE 148
#define HEADER_STRUCT_SIZE 124
#define ID_SIZE 32

// ─── Requirements struct offsets ──────────────────────────────────
enum {
    REQ_DURABILITY      = 0,
    REQ_CONFIDENTIALITY = 4,
    REQ_PORTABILITY     = 8,
    REQ_INTEGRITY       = 12,
    REQ_LIFETIME        = 16,
    REQ_VISIBILITY      = 20,
    REQ_ACCESS          = 24,
};

// ─── Owner struct offsets ─────────────────────────────────────────
enum {
    OWNER_KIND   = 0,  // u32
    OWNER_NODE_ID = 4, // 32 bytes
};

// ─── Envelope struct offsets ──────────────────────────────────────
enum {
    ENV_KIND          = 0,  // u32
    ENV_OWNER_INDEX   = 4,  // u16
    ENV_ALGORITHM     = 6,  // u16
    ENV_FLAGS         = 8,  // u32
    ENV_KEY_ID        = 12, // 32 bytes
    ENV_METADATA_HASH = 44, // 32 bytes
};

// ─── Header struct offsets ────────────────────────────────────────
enum {
    HDR_KIND        = 0,  // u16
    HDR_FLAGS       = 4,  // u32
    HDR_LOGICAL_LEN = 8,  // u64
    HDR_OWNER_CNT   = 16, // u16
    HDR_ENV_CNT     = 18, // u16
    HDR_CHILD_CNT   = 20, // u32
    HDR_BODY_LEN    = 24, // u64
    HDR_EPOCH       = 32, // 64 bytes
    HDR_REQUIREMENTS = 96, // 28 bytes
};

// ─── Child struct offsets ─────────────────────────────────────────
enum {
    CHILD_OBJECT_ID       = 0,  // 32 bytes
    CHILD_LOGICAL_OFFSET  = 32, // u64
    CHILD_LOGICAL_LEN     = 40, // u64
    CHILD_KIND            = 48, // u16
    CHILD_REQUIREMENTS_HASH = 52, // 32 bytes
};

// ─── Kind values ──────────────────────────────────────────────────
#define KIND_BYTES  1
#define KIND_TREE   2
#define KIND_RECEIPT 4

// ─── Owner kind values ────────────────────────────────────────────
#define OWNER_KIND_DEVICE  1
#define OWNER_KIND_STORAGE 2
#define OWNER_KIND_APP     3
#define OWNER_KIND_USER    4

// ─── Envelope kind values ─────────────────────────────────────────
#define ENV_KIND_NONE      0
#define ENV_KIND_DEVICE    1
#define ENV_KIND_STORAGE   2
#define ENV_KIND_APP       3
#define ENV_KIND_USER      4
#define ENV_KIND_SIGNATURE 5

// ─── Algorithm values ─────────────────────────────────────────────
#define ALG_AES_GCM_256         1
#define ALG_XCHACHA20_POLY1305  2
#define ALG_ED25519             3
#define ALG_SHA256              4
#define ALG_BLAKE3              5

static int memeq(const uint8_t* a, const uint8_t* b, uint64_t n) {
    return er_memcmp(a, b, n) == 0;
}

int main(void) {
    // ─── Requirements encode/decode round-trip ────────────────────
    {
        uint8_t req[REQ_SIZE];
        uint8_t buf[REQ_SIZE];
        uint8_t decoded[REQ_SIZE];

        // Write req struct fields
        *(uint32_t*)(req + REQ_DURABILITY)      = 1;  // standard durability
        *(uint32_t*)(req + REQ_CONFIDENTIALITY)  = 2;  // confidential
        *(uint32_t*)(req + REQ_PORTABILITY)      = 1;  // portable
        *(uint32_t*)(req + REQ_INTEGRITY)        = 1;  // integrity protected
        *(uint32_t*)(req + REQ_LIFETIME)         = 1;  // persistent
        *(uint32_t*)(req + REQ_VISIBILITY)       = 1;  // visible
        *(uint32_t*)(req + REQ_ACCESS)           = 1;  // unrestricted

        er_bytes_zero(buf, REQ_SIZE);
        er_bytes_zero(decoded, REQ_SIZE);

        int enc_ok = er_object_requirements_encode(buf, req);
        TEST("requirements encode returns 1", enc_ok == 1);

        // Check buf != zero
        TEST("requirements buf non-zero after encode",
             er_bytes_nonzero(buf, REQ_SIZE) == 1);

        int dec_ok = er_object_requirements_decode(buf, decoded);
        TEST("requirements decode returns 1", dec_ok == 1);

        // Compare
        TEST("requirements round-trip match", memeq(req, decoded, REQ_SIZE));
    }

    // ─── Requirements decode corruption ───────────────────────────
    {
        uint8_t bad_buf[REQ_SIZE];
        uint8_t decoded[REQ_SIZE];
        er_bytes_zero(bad_buf, REQ_SIZE);
        // All zeros — durability=0 which is invalid
        int dec_ok = er_object_requirements_decode(bad_buf, decoded);
        TEST("requirements decode all-zero fails", dec_ok == 0);
    }

    // ─── Requirements hash ────────────────────────────────────────
    {
        uint8_t req[REQ_SIZE];
        uint8_t hash[ID_SIZE];

        *(uint32_t*)(req + REQ_DURABILITY)      = 1;
        *(uint32_t*)(req + REQ_CONFIDENTIALITY)  = 2;
        *(uint32_t*)(req + REQ_PORTABILITY)      = 1;
        *(uint32_t*)(req + REQ_INTEGRITY)        = 1;
        *(uint32_t*)(req + REQ_LIFETIME)         = 1;
        *(uint32_t*)(req + REQ_VISIBILITY)       = 1;
        *(uint32_t*)(req + REQ_ACCESS)           = 1;

        er_bytes_zero(hash, ID_SIZE);
        int hash_ok = er_object_requirements_hash(req, hash);
        TEST("requirements hash returns 1", hash_ok == 1);

        // Hash must be non-zero
        TEST("requirements hash non-zero", er_bytes_nonzero(hash, ID_SIZE) == 1);
    }

    // ─── Owner encode/decode round-trip ───────────────────────────
    {
        uint8_t owner[OWNER_SIZE];
        uint8_t buf[OWNER_SIZE];
        uint8_t decoded[OWNER_SIZE];

        *(uint32_t*)(owner + OWNER_KIND) = OWNER_KIND_DEVICE;
        // Fill node_id with known pattern
        for (int i = 0; i < 32; i++)
            owner[OWNER_NODE_ID + i] = (uint8_t)(0xA0 + i);

        er_bytes_zero(buf, OWNER_SIZE);
        er_bytes_zero(decoded, OWNER_SIZE);

        int enc_ok = er_object_owner_encode(buf, owner);
        TEST("owner encode returns 1", enc_ok == 1);

        int dec_ok = er_object_owner_decode(buf, decoded);
        TEST("owner decode returns 1", dec_ok == 1);

        TEST("owner round-trip match", memeq(owner, decoded, OWNER_SIZE));
    }

    // ─── Owner decode invalid kind ────────────────────────────────
    {
        uint8_t buf[OWNER_SIZE];
        uint8_t decoded[OWNER_SIZE];

        er_bytes_zero(buf, OWNER_SIZE);
        *(uint32_t*)(buf + OWNER_KIND) = 99;  // invalid kind
        // node_id must be non-zero to pass node_id validation
        for (int i = 0; i < 32; i++)
            buf[OWNER_NODE_ID + i] = 0xBB;

        int dec_ok = er_object_owner_decode(buf, decoded);
        TEST("owner decode invalid kind fails", dec_ok == 0);
    }

    // ─── Envelope encode/decode round-trip ────────────────────────
    {
        uint8_t env[ENVELOPE_SIZE];
        uint8_t buf[ENVELOPE_SIZE];
        uint8_t decoded[ENVELOPE_SIZE];
        uint8_t owner[OWNER_SIZE];

        *(uint32_t*)(env + ENV_KIND)        = ENV_KIND_DEVICE;
        *(uint16_t*)(env + ENV_OWNER_INDEX)  = 0;
        *(uint16_t*)(env + ENV_ALGORITHM)    = ALG_AES_GCM_256;
        *(uint32_t*)(env + ENV_FLAGS)        = 0;
        // key_id
        for (int i = 0; i < 32; i++)
            env[ENV_KEY_ID + i] = (uint8_t)(0x10 + i);
        // metadata_hash
        for (int i = 0; i < 32; i++)
            env[ENV_METADATA_HASH + i] = (uint8_t)(0x20 + i);

        // Owner must match envelope kind
        *(uint32_t*)(owner + OWNER_KIND) = OWNER_KIND_DEVICE;
        for (int i = 0; i < 32; i++)
            owner[OWNER_NODE_ID + i] = (uint8_t)(0xA0 + i);

        er_bytes_zero(buf, ENVELOPE_SIZE);
        er_bytes_zero(decoded, ENVELOPE_SIZE);

        int enc_ok = er_object_envelope_encode(buf, env, owner);
        TEST("envelope encode returns 1", enc_ok == 1);

        int dec_ok = er_object_envelope_decode(buf, decoded);
        TEST("envelope decode returns 1", dec_ok == 1);

        TEST("envelope round-trip match", memeq(env, decoded, ENVELOPE_SIZE));
    }

    // ─── Child encode/decode round-trip ───────────────────────────
    {
        uint8_t child[CHILD_SIZE];
        uint8_t buf[CHILD_SIZE];
        uint8_t decoded[CHILD_SIZE];

        er_bytes_zero(child, CHILD_SIZE);
        for (int i = 0; i < 32; i++)
            child[CHILD_OBJECT_ID + i] = (uint8_t)(0x50 + i);
        *(uint64_t*)(child + CHILD_LOGICAL_OFFSET) = 0;
        *(uint64_t*)(child + CHILD_LOGICAL_LEN)    = 100;
        *(uint16_t*)(child + CHILD_KIND)           = KIND_BYTES;
        for (int i = 0; i < 32; i++)
            child[CHILD_REQUIREMENTS_HASH + i] = (uint8_t)(0x70 + i);

        er_bytes_zero(buf, CHILD_SIZE);
        er_bytes_zero(decoded, CHILD_SIZE);

        int enc_ok = er_object_child_encode(buf, child);
        TEST("child encode returns 1", enc_ok == 1);

        int dec_ok = er_object_child_decode(buf, *(uint64_t*)(child + CHILD_LOGICAL_OFFSET), decoded);
        TEST("child decode returns 1", dec_ok == 1);

        TEST("child round-trip match", memeq(child, decoded, CHILD_SIZE));
    }

    // ─── Canonical size ──────────────────────────────────────────
    {
        uint64_t size = 0;

        int ok = er_object_canonical_size(KIND_BYTES, 64, 0, 0, 0, &size);
        TEST("canonical size bytes returns 1", ok == 1);
        TEST("canonical size bytes = 212", size == 148 + 64);
    }



    return passed_tests == total_tests ? 0 : 1;
}
