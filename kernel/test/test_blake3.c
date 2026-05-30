// EdgeRun BLAKE3 ASM test — validates er_blake3_compress via single-chunk hash

typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned long      size_t;

extern int  er_memcmp(const void* a, const void* b, size_t n);
extern void er_blake3_compress(uint32_t* cv, uint32_t* block_words, uint64_t counter,
                                uint32_t block_len, uint32_t flags, uint32_t* out);
extern void er_blake3_compress_cv(uint32_t* cv, uint8_t* block, uint64_t counter,
                                   uint32_t block_len, uint32_t flags, uint32_t* new_cv);
extern void er_blake3_hash_chunk(const uint8_t* input, size_t len, uint64_t counter,
                                  uint32_t flags, uint32_t* out_cv);
extern void er_blake3_parent_cv(const uint32_t* left_cv, const uint32_t* right_cv,
                                 uint32_t* out_cv);
extern int  er_blake3_hash_one_chunk(const uint8_t* input, size_t len, uint8_t* out);
extern int  er_blake3_hash_bytes(const uint8_t* input, size_t len, uint8_t* out);

#define BLOCK_LEN  64
#define OUT_LEN    32
#define CHUNK_LEN  1024
#define CHUNK_START 1
#define CHUNK_END   2
#define PARENT      4
#define ROOT        8

static const uint32_t IV[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

static void store32(uint8_t* dst, uint32_t v) {
    dst[0] = (uint8_t)(v & 0xff);
    dst[1] = (uint8_t)((v >> 8) & 0xff);
    dst[2] = (uint8_t)((v >> 16) & 0xff);
    dst[3] = (uint8_t)((v >> 24) & 0xff);
}

static void pack_cv(uint8_t* dst, const uint32_t* cv) {
    size_t i;
    for (i = 0; i < 8; i++) store32(dst + i * 4, cv[i]);
}

// ── Single-chunk (len <= 1024) hash — delegated to ASM ──────────
static int hash_one_chunk(const uint8_t* input, size_t len, uint8_t out[OUT_LEN])
{
    return er_blake3_hash_one_chunk(input, len, out);
}

// Helper: compress cv-to-cv via words (needed by root_from_parent_cvs)
static void compress_cv_from_words(uint32_t* cv, uint32_t* block_words,
                                    uint64_t counter, uint32_t block_len,
                                    uint32_t flags, uint32_t* out8)
{
    uint32_t tmp[16];
    uint32_t i;
    er_blake3_compress(cv, block_words, counter, block_len, flags, tmp);
    for (i = 0; i < 8; i++) out8[i] = tmp[i];
}

// ── Multi-chunk BLAKE3 hash ────────────────────────────────────

static uint32_t round_down_pow2(uint32_t n) {
    uint32_t v = n;
    v |= v >> 1; v |= v >> 2; v |= v >> 4;
    v |= v >> 8; v |= v >> 16;
    return v - (v >> 1);
}

static void hash_chunk(const uint8_t* input, size_t len, uint64_t counter,
                       uint32_t flags, uint32_t cv[8])
{
    er_blake3_hash_chunk(input, len, counter, flags, cv);
}

static void parent_cv(const uint32_t left[8], const uint32_t right[8],
                      uint32_t out[8])
{
    er_blake3_parent_cv(left, right, out);
}

// Hashes len bytes where len is exact multiple of CHUNK_LEN and
// len/CHUNK_LEN is a power of two. Builds balanced binary tree.
// Returns the root-level parent CV from which the output hash
// is computed via root_from_parent_cvs.
static void hash_pow2_chunks(const uint8_t* input, size_t len, uint64_t counter,
                              uint32_t flags, uint32_t cv[8])
{
    uint32_t left_cv[8], right_cv[8];

    if (len == CHUNK_LEN) {
        hash_chunk(input, len, counter, flags, cv);
        return;
    }
    size_t half = len / 2;
    hash_pow2_chunks(input, half, counter, flags, left_cv);
    hash_pow2_chunks(input + half, half, counter + half / CHUNK_LEN, flags, right_cv);
    parent_cv(left_cv, right_cv, cv);
}

// Root output from parent CVs: compress(IV, left|right, 0, 64, PARENT|ROOT, hash)
static void root_from_parent_cvs(const uint32_t left[8], const uint32_t right[8],
                                 uint8_t out[OUT_LEN])
{
    uint32_t cv[8];
    uint8_t block[BLOCK_LEN];
    uint32_t block_words[16];
    size_t i;
    pack_cv(block, left);
    pack_cv(block + 32, right);
    for (i = 0; i < 16; i++) {
        uint8_t* p = block + i * 4;
        block_words[i] = (uint32_t)p[0] | ((uint32_t)p[1] << 8) |
                         ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
    }
    { uint32_t iv_copy[8]; size_t j; for (j = 0; j < 8; j++) iv_copy[j] = IV[j];
      compress_cv_from_words(iv_copy, block_words, 0, BLOCK_LEN, PARENT | ROOT, cv); }
    for (i = 0; i < OUT_LEN; i++) out[i] = ((uint8_t*)cv)[i];
}

// General subtree CV for arbitrary-length input
static void subtree_cv(const uint8_t* input, size_t len, uint64_t counter,
                        uint32_t flags, uint32_t cv[8])
{
    uint32_t left_cv[8], right_cv[8];
    size_t nfull, left_chunks, left_len;

    if (len <= CHUNK_LEN) {
        hash_chunk(input, len, counter, flags, cv);
        return;
    }

    nfull = len / CHUNK_LEN;
    left_chunks = round_down_pow2((uint32_t)nfull);

    if (left_chunks == nfull && len % CHUNK_LEN == 0) {
        hash_pow2_chunks(input, len, counter, flags, cv);
        return;
    }

    left_len = left_chunks * CHUNK_LEN;
    subtree_cv(input, left_len, counter, flags, left_cv);
    subtree_cv(input + left_len, len - left_len, counter + left_chunks, flags, right_cv);
    parent_cv(left_cv, right_cv, cv);
}

static int hash_bytes(const uint8_t* input, size_t len, uint8_t out[OUT_LEN])
{
    return er_blake3_hash_bytes(input, len, out);
}

// ── Test framework ──────────────────────────────────────────────
static int total, failed;

static void print_hex(const char* label, const uint8_t* data, size_t n) {
    size_t i;
    static const char hex[] = "0123456789abcdef";
    char buf[3];
    for (i = 0; i < n && i < 32; i++) {
        buf[0] = hex[data[i] >> 4];
        buf[1] = hex[data[i] & 0xf];
        buf[2] = '\n';
        __asm__ volatile (
            "mov $1, %%rax\n"   // SYS_write
            "mov $1, %%rdi\n"   // fd = stdout
            "lea %0, %%rsi\n"   // buf
            "mov $3, %%rdx\n"   // count
            "syscall"
            :: "m"(buf) : "rax", "rdi", "rsi", "rdx", "memory"
        );
    }
}

// Simple putchar via SYS_write
static void my_putchar(char c) {
    __asm__ volatile (
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "lea %0, %%rsi\n"
        "mov $1, %%rdx\n"
        "syscall"
        :: "m"(c) : "rax", "rdi", "rsi", "rdx", "memory"
    );
}

static void my_puts(const char* s) {
    while (*s) { my_putchar(*s); s++; }
}

static void check_bytes(const char* label, const uint8_t* got,
                        const uint8_t* want, size_t n)
{
    size_t i;
    total++;
    if (er_memcmp(got, want, n) != 0) {
        failed++;
    }
    // Debug: print failure
    if (er_memcmp(got, want, n) != 0) {
        size_t di;
        // "FAIL: XXX "
        __asm__ volatile (
            "mov $1, %%rax\n"
            "mov $1, %%rdi\n"
            "lea (%0), %%rsi\n"
            "mov $6, %%rdx\n"
            "syscall"
            :: "r"(label) : "rax", "rdi", "rsi", "rdx", "memory"
        );
        // Print got
        for (di = 0; di < 32; di++) {
            char hex[3];
            static const char hexchars[] = "0123456789abcdef";
            hex[0] = hexchars[got[di] >> 4];
            hex[1] = hexchars[got[di] & 0xf];
            hex[2] = '\n';
            __asm__ volatile (
                "mov $1, %%rax\n"
                "mov $1, %%rdi\n"
                "lea (%0), %%rsi\n"
                "mov $2, %%rdx\n"
                "syscall"
                :: "r"(hex) : "rax", "rdi", "rsi", "rdx", "memory"
            );
        }
    }
}

static void hex_bytes(uint8_t* out, const char* hex) {
    size_t i;
    for (i = 0; i < OUT_LEN; i++) {
        uint8_t hi = 0, lo = 0;
        char c;
        c = hex[i * 2];
        if (c >= '0' && c <= '9') hi = (uint8_t)(c - '0');
        else if (c >= 'a' && c <= 'f') hi = (uint8_t)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') hi = (uint8_t)(c - 'A' + 10);
        c = hex[i * 2 + 1];
        if (c >= '0' && c <= '9') lo = (uint8_t)(c - '0');
        else if (c >= 'a' && c <= 'f') lo = (uint8_t)(c - 'a' + 10);
        else if (c >= 'A' && c <= 'F') lo = (uint8_t)(c - 'A' + 10);
        out[i] = (uint8_t)((hi << 4) | lo);
    }
}

static void test_vec(const char* label, const uint8_t* data, size_t len,
                     const char* hex)
{
    uint8_t out[OUT_LEN], want[OUT_LEN];
    hex_bytes(want, hex);
    hash_bytes(data, len, out);
    check_bytes(label, out, want, OUT_LEN);
}

int main(void) {
    uint8_t large[4096];
    size_t i;

    for (i = 0; i < sizeof(large); i++) large[i] = (uint8_t)(i % 251);

    test_vec("empty", 0, 0,
        "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262");

    { static const uint8_t abc[] = {'a','b','c'};
      test_vec("abc", abc, 3,
        "6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85"); }

    test_vec("1255", large, 1255,
        "8b929b2d329f8795b15060a2e5d087ea507aeba8dcf19fb00eb92ceb890d179e");

    test_vec("1024", large, 1024,
        "42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7");

    test_vec("1025", large, 1025,
        "d00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444");

    test_vec("4096", large, 4096,
        "015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969");

    if (failed) return 1;
    return 0;
}
