// EdgeRun bytes.asm test — freestanding

typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned long      size_t;

extern int  er_memcmp(const void* a, const void* b, size_t n);
extern void er_memset(void* s, int c, size_t n);

extern int  er_bytes_nonzero(const void* buf, uint32_t len);
extern int  er_bytes_eql(const void* a, uint32_t len_a, const void* b, uint32_t len_b);
extern int  er_bytes_order(const void* a, uint32_t len_a, const void* b, uint32_t len_b);
extern void er_bytes_zero(void* buf, uint32_t len);
extern int  er_store16(void* out, uint32_t value);
extern int  er_store32(void* out, uint32_t value);
extern int  er_store64(void* out, uint64_t value);
extern int  er_storebe16(void* out, uint32_t value);
extern int  er_storebe32(void* out, uint32_t value);
extern int  er_storebe64(void* out, uint64_t value);
extern int  er_load16(const void* in, uint32_t len);
extern int  er_load32(const void* in, uint32_t len);
extern int  er_loadbe16(const void* in, uint32_t len);
extern int  er_loadbe32(const void* in, uint32_t len);
extern int  er_starts_with(const void* haystack, uint32_t hay_len,
                            const void* needle, uint32_t needle_len);
extern int  er_ends_with(const void* haystack, uint32_t hay_len,
                          const void* needle, uint32_t needle_len);
extern int  er_index_of(const void* haystack, uint32_t hay_len,
                         const void* needle, uint32_t needle_len);

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
} while(0)

int main(void) {
    // ─── er_bytes_nonzero ────────────────────────────────────────
    {
        uint8_t all_zero[] = {0, 0, 0, 0};
        uint8_t has_one[]  = {0, 0, 1, 0};
        TEST("nonzero all zero false", er_bytes_nonzero(all_zero, 4) == 0);
        TEST("nonzero has one true",   er_bytes_nonzero(has_one, 4) == 1);
        TEST("nonzero empty false",    er_bytes_nonzero(all_zero, 0) == 0);
    }

    // ─── er_bytes_eql ────────────────────────────────────────────
    {
        uint8_t a[] = {1, 2, 3, 4};
        uint8_t b[] = {1, 2, 3, 4};
        uint8_t c[] = {1, 2, 3, 5};
        uint8_t d[] = {1, 2, 3};
        TEST("eql equal",       er_bytes_eql(a, 4, b, 4) == 1);
        TEST("eql diff content", er_bytes_eql(a, 4, c, 4) == 0);
        TEST("eql diff length", er_bytes_eql(a, 4, d, 3) == 0);
        TEST("eql both empty",  er_bytes_eql(a, 0, d, 0) == 1);
    }

    // ─── er_bytes_order ──────────────────────────────────────────
    {
        uint8_t a[] = {1, 2, 3};
        uint8_t b[] = {1, 2, 4};
        uint8_t c[] = {1, 2, 3, 4};
        TEST("order equal",        er_bytes_order(a, 3, a, 3) == 0);
        TEST("order less",         er_bytes_order(a, 3, b, 3) == -1);
        TEST("order greater",      er_bytes_order(b, 3, a, 3) == 1);
        TEST("order shorter less", er_bytes_order(a, 3, c, 4) == -1);
    }

    // ─── er_bytes_zero ───────────────────────────────────────────
    {
        uint8_t buf[] = {1, 2, 3, 4};
        er_bytes_zero(buf, 4);
        TEST("zero all zero", er_memcmp(buf, "\0\0\0\0", 4) == 0);
        er_bytes_zero(buf, 0);
        TEST("zero no-op empty", 1);
    }

    // ─── er_store16 / er_load16 ──────────────────────────────────
    {
        uint8_t buf[4] = {0};
        er_store16(buf, 0xAABB);
        TEST("store16 correct", buf[0] == 0xBB && buf[1] == 0xAA);
        TEST("store16 ret", 1);
    }
    {
        uint8_t buf[4] = {0xBB, 0xAA, 0, 0};
        uint32_t v = er_load16(buf, 4);
        TEST("load16 correct", v == 0xAABB);
    }
    {
        uint8_t buf[2] = {0xBB, 0xAA};
        uint32_t v = er_load16(buf, 2);
        TEST("load16 exact len", v == 0xAABB);
    }

    // ─── er_store32 / er_load32 ──────────────────────────────────
    {
        uint8_t buf[8] = {0};
        er_store32(buf, 0x11223344);
        TEST("store32 correct",
             buf[0] == 0x44 && buf[1] == 0x33 &&
             buf[2] == 0x22 && buf[3] == 0x11);
    }
    {
        uint8_t buf[8] = {0x44, 0x33, 0x22, 0x11, 0, 0, 0, 0};
        uint32_t v = er_load32(buf, 8);
        TEST("load32 correct", v == 0x11223344);
    }

    // ─── er_storebe16 / er_loadbe16 ──────────────────────────────
    {
        uint8_t buf[4] = {0};
        er_storebe16(buf, 0xAABB);
        TEST("storebe16 correct", buf[0] == 0xAA && buf[1] == 0xBB);
    }
    {
        uint8_t buf[4] = {0xAA, 0xBB, 0, 0};
        uint32_t v = er_loadbe16(buf, 4);
        TEST("loadbe16 correct", v == 0xAABB);
    }

    // ─── er_storebe32 / er_loadbe32 ──────────────────────────────
    {
        uint8_t buf[8] = {0};
        er_storebe32(buf, 0x11223344);
        TEST("storebe32 correct",
             buf[0] == 0x11 && buf[1] == 0x22 &&
             buf[2] == 0x33 && buf[3] == 0x44);
    }
    {
        uint8_t buf[8] = {0x11, 0x22, 0x33, 0x44, 0, 0, 0, 0};
        uint32_t v = er_loadbe32(buf, 8);
        TEST("loadbe32 correct", v == 0x11223344);
    }

    // ─── er_store64 / er_storebe64 ────────────────────────────────
    {
        uint8_t buf[16] = {0};
        er_store64(buf, 0x0102030405060708ULL);
        TEST("store64 correct",
             buf[0] == 0x08 && buf[1] == 0x07 && buf[2] == 0x06 && buf[3] == 0x05 &&
             buf[4] == 0x04 && buf[5] == 0x03 && buf[6] == 0x02 && buf[7] == 0x01);
    }
    {
        uint8_t buf[16] = {0};
        er_storebe64(buf, 0x0102030405060708ULL);
        TEST("storebe64 correct",
             buf[0] == 0x01 && buf[1] == 0x02 && buf[2] == 0x03 && buf[3] == 0x04 &&
             buf[4] == 0x05 && buf[5] == 0x06 && buf[6] == 0x07 && buf[7] == 0x08);
    }

    // ─── er_starts_with ──────────────────────────────────────────
    {
        uint8_t hay[] = "hello world";
        TEST("starts_with match",    er_starts_with(hay, 11, "hello", 5) == 1);
        TEST("starts_with mismatch", er_starts_with(hay, 11, "world", 5) == 0);
        TEST("starts_with needle too long",
             er_starts_with(hay, 5, "hello!", 6) == 0);
        TEST("starts_with empty needle",
             er_starts_with(hay, 11, "", 0) == 1);
    }

    // ─── er_ends_with ────────────────────────────────────────────
    {
        uint8_t hay[] = "hello world";
        TEST("ends_with match",    er_ends_with(hay, 11, "world", 5) == 1);
        TEST("ends_with mismatch", er_ends_with(hay, 11, "hello", 5) == 0);
        TEST("ends_with needle too long",
             er_ends_with(hay, 5, "hello!", 6) == 0);
        TEST("ends_with empty needle",
             er_ends_with(hay, 11, "", 0) == 1);
    }

    // ─── er_index_of ─────────────────────────────────────────────
    {
        uint8_t hay[] = "hello world hello";
        int idx;

        idx = er_index_of(hay, 17, "world", 5);
        TEST("index_of find", idx == 6);

        idx = er_index_of(hay, 17, "hello", 5);
        TEST("index_of first", idx == 0);

        idx = er_index_of(hay, 17, "xyz", 3);
        TEST("index_of not found", idx == -1);

        idx = er_index_of(hay, 17, "", 0);
        TEST("index_of empty needle", idx == 0);

        idx = er_index_of(hay, 5, "hello!", 6);
        TEST("index_of needle too long", idx == -1);
    }

    if (passed_tests == total_tests) {
        return 0;
    }
    return total_tests - passed_tests;
}
