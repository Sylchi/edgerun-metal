// EdgeRun assembly runtime function test harness
// Tests memset, memcpy, memcmp, strlen, strcmp, strcpy, memmove
// Host-side: libc allowed for I/O

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Assembly functions under test
extern void* er_memset(void* dst, int value, size_t num);
extern void* er_memcpy(void* dst, const void* src, size_t num);
extern int   er_memcmp(const void* ptr1, const void* ptr2, size_t num);
extern size_t er_strlen(const char* str);
extern int   er_strcmp(const char* str1, const char* str2);
extern char* er_strcpy(char* dst, const char* src);
extern int   er_strcmp_prefix(const char* str, const char* prefix);
extern void* er_memmove(void* dst, const void* src, size_t num);

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
    else { printf("  FAIL %s (line %d)\n", name, __LINE__); } \
} while(0)

#define TEST_EQ(name, actual, expected) do { \
    total_tests++; \
    if ((actual) == (expected)) { passed_tests++; } \
    else { printf("  FAIL %s (line %d): got %lu, expected %lu\n", \
           name, __LINE__, (unsigned long)(actual), (unsigned long)(expected)); } \
} while(0)

int main(void) {
    printf("asm/runtime test harness\n");
    printf("-----------------------\n\n");

    // ---- er_memset ------------------------------------------------
    printf("er_memset:\n");
    {
        uint8_t buf[32];
        memset(buf, 0xcc, sizeof(buf));
        er_memset(buf, 0x00, sizeof(buf));
        int ok = 1;
        for (size_t i = 0; i < sizeof(buf); i++)
            if (buf[i] != 0x00) { ok = 0; break; }
        TEST("memset zero all", ok);

        er_memset(buf, 0xab, 16);
        ok = 1;
        for (size_t i = 0; i < 16; i++)
            if (buf[i] != 0xab) { ok = 0; break; }
        for (size_t i = 16; i < sizeof(buf); i++)
            if (buf[i] != 0x00) { ok = 0; break; }
        TEST("memset partial", ok);

        // Return value
        void* result = er_memset(buf, 0xff, 0);
        TEST("memset returns dst", result == buf);
    }

    // ---- er_memcpy ------------------------------------------------
    printf("\ner_memcpy:\n");
    {
        uint8_t src[32] = {0};
        uint8_t dst[32] = {0};
        for (size_t i = 0; i < 16; i++) src[i] = (uint8_t)(i + 1);
        memset(dst, 0xcc, sizeof(dst));

        er_memcpy(dst, src, 16);
        int ok = 1;
        for (size_t i = 0; i < 16; i++)
            if (dst[i] != src[i]) { ok = 0; break; }
        for (size_t i = 16; i < sizeof(dst); i++)
            if (dst[i] != 0xcc) { ok = 0; break; }
        TEST("memcpy partial", ok);

        // Return value
        void* result = er_memcpy(dst, src, 0);
        TEST("memcpy returns dst", result == dst);
    }

    // ---- er_memcmp ------------------------------------------------
    printf("\ner_memcmp:\n");
    {
        uint8_t a[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
        uint8_t b[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
        uint8_t c[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,17};

        TEST("memcmp equal",       er_memcmp(a, b, 16) == 0);
        TEST("memcmp not equal",   er_memcmp(a, c, 16) != 0);
        TEST("memcmp diff sign",   er_memcmp(a, c, 16) < 0);
        TEST("memcmp diff sign r", er_memcmp(c, a, 16) > 0);
        TEST("memcmp zero len",    er_memcmp(a, c, 0) == 0);
        TEST("memcmp first byte",  er_memcmp(a, c, 1) == 0);
    }

    // ---- er_strlen ------------------------------------------------
    printf("\ner_strlen:\n");
    {
        TEST_EQ("strlen empty",     er_strlen(""),     0);
        TEST_EQ("strlen hello",     er_strlen("hello"), 5);
        TEST_EQ("strlen null",      er_strlen(0),       0);
        TEST_EQ("strlen long",      er_strlen("EdgeRun x86_64 bare metal"), 25);
    }

    // ---- er_strcmp ------------------------------------------------
    printf("\ner_strcmp:\n");
    {
        TEST("strcmp equal",        er_strcmp("hello", "hello") == 0);
        TEST("strcmp lt",           er_strcmp("abc", "abd") < 0);
        TEST("strcmp gt",           er_strcmp("abd", "abc") > 0);
        TEST("strcmp prefix",       er_strcmp("ab", "abc") < 0);
        TEST("strcmp suffix",       er_strcmp("abc", "ab") > 0);
        TEST("strcmp empty",        er_strcmp("", "") == 0);
        TEST("strcmp empty vs val", er_strcmp("", "a") < 0);
    }

    // ---- er_strcpy ------------------------------------------------
    printf("\ner_strcpy:\n");
    {
        char buf[32];
        memset(buf, 0xcc, sizeof(buf));

        char* result = er_strcpy(buf, "hello");
        TEST("strcpy returns dst", result == buf);
        TEST("strcpy content",     strcmp(buf, "hello") == 0);
        TEST("strcpy null term",   buf[5] == 0);
    }

    // ---- er_strcmp_prefix -----------------------------------------
    printf("\ner_strcmp_prefix:\n");
    {
        TEST("prefix match",    er_strcmp_prefix("hello world", "hello") == 0);
        TEST("prefix no match", er_strcmp_prefix("hello world", "world") != 0);
        TEST("prefix exact",    er_strcmp_prefix("hello", "hello") == 0);
        TEST("prefix longer",   er_strcmp_prefix("hel", "hello") != 0);
        TEST("prefix empty",    er_strcmp_prefix("anything", "") == 0);
    }

    // ---- er_memmove (overlapping) ----------------------------------
    printf("\ner_memmove:\n");
    {
        uint8_t buf[32];

        // Non-overlapping (same as memcpy)
        memset(buf, 0xcc, sizeof(buf));
        for (size_t i = 0; i < 8; i++) buf[i] = (uint8_t)(i + 1);
        er_memmove(buf + 16, buf, 8);
        int ok = 1;
        for (size_t i = 0; i < 8; i++)
            if (buf[16 + i] != (uint8_t)(i + 1)) { ok = 0; break; }
        TEST("memmove non-overlap fwd", ok);

        // Forward overlap (dst > src)
        memset(buf, 0, sizeof(buf));
        for (size_t i = 0; i < 16; i++) buf[i] = (uint8_t)(i + 1);
        er_memmove(buf + 4, buf, 12);
        ok = 1;
        for (size_t i = 0; i < 12; i++)
            if (buf[4 + i] != (uint8_t)(i + 1)) { ok = 0; break; }
        TEST("memmove forward overlap", ok);

        // Backward overlap (dst < src)
        memset(buf, 0, sizeof(buf));
        for (size_t i = 0; i < 16; i++) buf[i] = (uint8_t)(i + 1);
        er_memmove(buf, buf + 4, 12);
        ok = 1;
        for (size_t i = 0; i < 12; i++)
            if (buf[i] != (uint8_t)(i + 5)) { ok = 0; break; }
        TEST("memmove backward overlap", ok);
    }

    printf("\n-----------------------\n");
    printf("%d / %d tests passed\n", passed_tests, total_tests);
    return (passed_tests == total_tests) ? 0 : 1;
}
