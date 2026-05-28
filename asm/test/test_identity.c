// EdgeRun identity test — freestanding
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned long      size_t;

extern int  er_memcmp(const void* a, const void* b, size_t n);
extern void er_memset(void* s, int c, size_t n);
extern int  er_blake3_hash_bytes(const uint8_t* input, size_t len, uint8_t* out);

extern int  er_identity_source_prepare(uint16_t kind,
    const uint8_t* material, uint32_t material_len, void* out_source);
extern int  er_identity_source_prepare_delegation(const uint8_t parent_id[32],
    const uint8_t delegate_id[32], const uint8_t scope_hash[32], void* out_source);
extern int  er_identity_source_valid(const void* source);
extern int  er_identity_source_id(const void* source, uint8_t out_id[32]);
extern int  er_identity_init(uint16_t kind, const void* source,
    const void* epoch, void* out_identity);
extern int  er_identity_valid(const void* identity);
extern int  er_identity_eql(const void* a, const void* b);

// ID size from identity.asm
#define ID_SIZE 32
#define HASH_SIZE 32
#define MATERIAL_MAX 96
#define EPOCH_SIZE 64

// Source struct
struct source {
    uint16_t kind;       // 0
    uint8_t  pad0[6];    // 2
    uint8_t  material[MATERIAL_MAX]; // 8
    uint64_t len;        // 104
};

// Identity struct
struct identity {
    uint16_t kind;       // 0
    uint8_t  pad1[6];    // 2
    uint8_t  epoch[64];  // 8
    uint8_t  id[32];     // 72
    struct source source; // 104
};

// Stamp struct for epoch
struct stamp {
    uint8_t  keeper[32];
    uint64_t tick;
    uint64_t slot;
    uint64_t epoch;
    uint64_t era;
};

static int total = 0;
static int passed = 0;

static void putch(const char c) {
    const char* p = &c;
    __asm__ volatile (
        "mov $1, %%rax\nmov $1, %%rdi\nmov %0, %%rsi\nmov $1, %%rdx\nsyscall"
        :: "r"(p) : "rax", "rdi", "rsi", "rdx", "memory"
    );
}

static void puts(const char* s) {
    for (; *s; s++) putch(*s);
}

#define TEST(msg, expr) do { \
    total++; \
    if (expr) { passed++; } \
    else { puts("FAIL: "); puts(msg); puts("\n"); } \
} while(0)

int main(void) {
    // ── identity_source_prepare ─────────────────────────────────
    {
        // Valid hash source (material len must be 32)
        uint8_t mat[32];
        er_memset(mat, 0xAB, 32);
        struct source s;
        er_memset(&s, 0, sizeof(s));

        int r = er_identity_source_prepare(1, mat, 32, &s);
        TEST("source prepare hash ok", r == 1);
        TEST("source kind=hash", s.kind == 1);
        TEST("source len=32", s.len == 32);
        TEST("source material matches", er_memcmp(s.material, mat, 32) == 0);
    }
    {
        // Invalid material length for hash
        uint8_t mat[10];
        er_memset(mat, 0xAB, 10);
        struct source s;
        int r = er_identity_source_prepare(1, mat, 10, &s);
        TEST("source prepare hash wrong_len", r == 0);
    }
    {
        // All-zero material rejected
        uint8_t mat[32];
        er_memset(mat, 0, 32);
        struct source s;
        int r = er_identity_source_prepare(1, mat, 32, &s);
        TEST("source prepare zero material", r == 0);
    }
    {
        // Endpoint source (any len 1..96)
        uint8_t mat[5];
        er_memset(mat, 0xCD, 5);
        struct source s;
        int r = er_identity_source_prepare(6, mat, 5, &s);
        TEST("source prepare endpoint ok", r == 1);
        TEST("source endpoint kind=6", s.kind == 6);
        TEST("source endpoint len=5", s.len == 5);
    }
    {
        // Endpoint too large
        uint8_t mat[97];
        er_memset(mat, 0xCD, 97);
        struct source s;
        int r = er_identity_source_prepare(6, mat, 97, &s);
        TEST("source prepare endpoint oversized", r == 0);
    }

    // ── identity_source_valid ───────────────────────────────────
    {
        uint8_t mat[32];
        er_memset(mat, 0xAB, 32);
        struct source s;
        er_identity_source_prepare(1, mat, 32, &s);
        TEST("source valid (hash)", er_identity_source_valid(&s) == 1);

        // Corrupt length
        s.len = 10;
        TEST("source invalid (wrong len)", er_identity_source_valid(&s) == 0);
    }

    // ── identity_source_id ──────────────────────────────────────
    {
        // Source ID is deterministic: blake3(domain + header + material)
        uint8_t mat[32];
        er_memset(mat, 0xAB, 32);
        struct source s;
        er_identity_source_prepare(1, mat, 32, &s);

        uint8_t id1[32], id2[32];
        int r1 = er_identity_source_id(&s, id1);
        int r2 = er_identity_source_id(&s, id2);
        TEST("source id ok", r1 == 1 && r2 == 1);
        TEST("source id deterministic", er_memcmp(id1, id2, 32) == 0);
        TEST("source id nonzero", er_memcmp(id1, mat, 32) != 0);

        // Different material → different ID
        uint8_t mat2[32];
        er_memset(mat2, 0xCD, 32);
        struct source s2;
        er_identity_source_prepare(1, mat2, 32, &s2);
        uint8_t id3[32];
        er_identity_source_id(&s2, id3);
        TEST("source id differs per material", er_memcmp(id1, id3, 32) != 0);
    }

    // ── identity_source_prepare_delegation ──────────────────────
    {
        uint8_t parent[32], delegate[32], scope[32];
        er_memset(parent, 0xAA, 32);
        er_memset(delegate, 0xBB, 32);
        er_memset(scope, 0xCC, 32);
        struct source s;
        int r = er_identity_source_prepare_delegation(parent, delegate, scope, &s);
        TEST("delegation prepare ok", r == 1);
        TEST("delegation kind=8", s.kind == 8);
        TEST("delegation len=96", s.len == 96);
        TEST("delegation parent match", er_memcmp(s.material, parent, 32) == 0);
        TEST("delegation delegate match", er_memcmp(s.material + 32, delegate, 32) == 0);
        TEST("delegation scope match", er_memcmp(s.material + 64, scope, 32) == 0);
    }
    {
        // Zero parent → fail
        uint8_t parent[32], delegate[32], scope[32];
        er_memset(parent, 0, 32);
        er_memset(delegate, 0xBB, 32);
        er_memset(scope, 0xCC, 32);
        struct source s;
        int r = er_identity_source_prepare_delegation(parent, delegate, scope, &s);
        TEST("delegation zero parent rejected", r == 0);
    }

    // ── identity_init + identity_valid ──────────────────────────
    {
        uint8_t keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        struct stamp epoch;
        er_memset(&epoch, 0, sizeof(epoch));
        { int jj; for (jj = 0; jj < 32; jj++) ((uint8_t*)&epoch.keeper)[jj] = keeper[jj]; }
        epoch.tick = 1;

        uint8_t mat[32];
        er_memset(mat, 0xAB, 32);
        struct source src;
        er_identity_source_prepare(1, mat, 32, &src);

        struct identity ident;
        er_memset(&ident, 0, sizeof(ident));
        int r = er_identity_init(3, &src, &epoch, &ident);
        TEST("identity init ok", r == 1);
        TEST("identity kind=3 (app)", ident.kind == 3);
        TEST("identity epoch keeper match", er_memcmp(ident.epoch, keeper, 32) == 0);

        // Auto-computed ID
        uint8_t expected_id[32];
        er_identity_source_id(&src, expected_id);
        TEST("identity id matches source.id", er_memcmp(ident.id, expected_id, 32) == 0);

        TEST("identity valid", er_identity_valid(&ident) == 1);

        // Corrupt identity -> invalid
        ident.kind = 0;
        TEST("identity corrupt kind invalid", er_identity_valid(&ident) == 0);
    }

    // ── identity_eql ────────────────────────────────────────────
    {
        uint8_t keeper[32];
        er_memset(keeper, 0, 32);
        keeper[0] = 0x42;
        struct stamp epoch;
        er_memset(&epoch, 0, sizeof(epoch));
        { int jj; for (jj = 0; jj < 32; jj++) ((uint8_t*)&epoch.keeper)[jj] = keeper[jj]; }
        epoch.tick = 1;

        uint8_t mat[32];
        er_memset(mat, 0xAB, 32);
        struct source src;
        er_identity_source_prepare(1, mat, 32, &src);

        struct identity a, b;
        er_identity_init(3, &src, &epoch, &a);
        er_identity_init(3, &src, &epoch, &b);

        TEST("identity eql equal", er_identity_eql(&a, &b) == 1);
        TEST("identity eql self", er_identity_eql(&a, &a) == 1);

        // Different kind → not equal
        struct identity c;
        er_identity_init(1, &src, &epoch, &c);
        c.id[0] = a.id[0]; c.id[1] = a.id[1]; // must manually set since init recomputes
        // Actually init recomputes the ID, so c.id will already be correct
        TEST("identity eql different kind", er_identity_eql(&a, &c) == 0);
    }

    if (passed == total) {
        return 0;
    }
    return total - passed;
}
