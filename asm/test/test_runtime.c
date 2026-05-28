// EdgeRun assembly runtime function test harness
// Tests memset, memcpy, memcmp, strlen, strcmp, strcpy, memmove, etc.
// Freestanding — no libc.

typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef long long          int64_t;
typedef unsigned long      size_t;

extern void* er_memset(void* dst, int value, size_t num);
extern void* er_memcpy(void* dst, const void* src, size_t num);
extern int   er_memcmp(const void* ptr1, const void* ptr2, size_t num);
extern size_t er_strlen(const char* str);
extern int   er_strcmp(const char* str1, const char* str2);
extern char* er_strcpy(char* dst, const char* src);
extern int   er_strcmp_prefix(const char* str, const char* prefix);
extern void* er_memmove(void* dst, const void* src, size_t num);
extern void* er_memchr(const void* ptr, int value, size_t num);
extern void* er_memrchr(const void* ptr, int value, size_t num);
extern void* er_memset32(void* dst, uint32_t value, size_t count);
extern void* er_memset64(void* dst, uint64_t value, size_t count);
extern char* er_strchr(const char* str, int c);
extern char* er_strrchr(const char* str, int c);
extern char* er_strncpy(char* dst, const char* src, size_t n);
extern char* er_strncat(char* dst, const char* src, size_t n);
extern int   er_strncmp(const char* s1, const char* s2, size_t n);
extern int   er_strcasecmp(const char* s1, const char* s2);
extern char* er_strstr(const char* haystack, const char* needle);
extern uint64_t er_strtou64(const char* str, char** endptr);
extern int64_t  er_strtoi64(const char* str, char** endptr);
extern uint64_t er_strtou64_hex(const char* str, char** endptr);
extern size_t   er_strspn(const char* str, const char* accept);
extern size_t   er_strcspn(const char* str, const char* reject);
extern char*    er_strpbrk(const char* str, const char* accept);
extern void*    er_memccpy(void* dst, const void* src, int stop_char, size_t n);
extern int      er_memicmp(const void* ptr1, const void* ptr2, size_t n);
extern void     er_memswap(void* ptr1, void* ptr2, size_t n);
extern void     er_hex_encode(const void* data, size_t len, char* out);
extern size_t   er_hex_decode(const char* hex, size_t len, void* out);
extern int      er_utf8_encode(uint32_t codepoint, char* out);
extern uint32_t er_utf8_decode(const char* str, size_t* len);
extern char*    er_strtok(char* str, const char* delim);
extern uint64_t er_strtou64_base(const char* str, char** endptr, int base);
extern int64_t  er_strtoi64_base(const char* str, char** endptr, int base);

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
} while(0)

#define TEST_EQ(name, actual, expected) do { \
    total_tests++; \
    if ((unsigned long)(actual) == (unsigned long)(expected)) { passed_tests++; } \
} while(0)

int main(void) {
    {
        uint8_t buf[32];
        er_memset(buf, 0xcc, sizeof(buf));
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

        void* result = er_memset(buf, 0xff, 0);
        TEST("memset returns dst", result == buf);
    }

    {
        uint8_t src[32];
        uint8_t dst[32];
        for (size_t i = 0; i < 32; i++) src[i] = 0;
        for (size_t i = 0; i < 32; i++) dst[i] = 0;
        for (size_t i = 0; i < 16; i++) src[i] = (uint8_t)(i + 1);
        er_memset(dst, 0xcc, sizeof(dst));

        er_memcpy(dst, src, 16);
        int ok = 1;
        for (size_t i = 0; i < 16; i++)
            if (dst[i] != src[i]) { ok = 0; break; }
        for (size_t i = 16; i < sizeof(dst); i++)
            if (dst[i] != 0xcc) { ok = 0; break; }
        TEST("memcpy partial", ok);

        void* result = er_memcpy(dst, src, 0);
        TEST("memcpy returns dst", result == dst);
    }

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

    {
        TEST_EQ("strlen empty",     er_strlen(""),     0);
        TEST_EQ("strlen hello",     er_strlen("hello"), 5);
        TEST_EQ("strlen null",      er_strlen(0),       0);
        TEST_EQ("strlen long",      er_strlen("EdgeRun x86_64 bare metal"), 25);
    }

    {
        TEST("strcmp equal",        er_strcmp("hello", "hello") == 0);
        TEST("strcmp lt",           er_strcmp("abc", "abd") < 0);
        TEST("strcmp gt",           er_strcmp("abd", "abc") > 0);
        TEST("strcmp prefix",       er_strcmp("ab", "abc") < 0);
        TEST("strcmp suffix",       er_strcmp("abc", "ab") > 0);
        TEST("strcmp empty",        er_strcmp("", "") == 0);
        TEST("strcmp empty vs val", er_strcmp("", "a") < 0);
    }

    {
        char buf[32];
        er_memset(buf, 0xcc, sizeof(buf));

        char* result = er_strcpy(buf, "hello");
        TEST("strcpy returns dst", result == buf);
        TEST("strcpy content",     er_strcmp(buf, "hello") == 0);
        TEST("strcpy null term",   buf[5] == 0);
    }

    {
        TEST("prefix match",    er_strcmp_prefix("hello world", "hello") == 0);
        TEST("prefix no match", er_strcmp_prefix("hello world", "world") != 0);
        TEST("prefix exact",    er_strcmp_prefix("hello", "hello") == 0);
        TEST("prefix longer",   er_strcmp_prefix("hel", "hello") != 0);
        TEST("prefix empty",    er_strcmp_prefix("anything", "") == 0);
    }

    {
        uint8_t buf[32];

        er_memset(buf, 0xcc, sizeof(buf));
        for (size_t i = 0; i < 8; i++) buf[i] = (uint8_t)(i + 1);
        er_memmove(buf + 16, buf, 8);
        int ok = 1;
        for (size_t i = 0; i < 8; i++)
            if (buf[16 + i] != (uint8_t)(i + 1)) { ok = 0; break; }
        TEST("memmove non-overlap fwd", ok);

        er_memset(buf, 0, sizeof(buf));
        for (size_t i = 0; i < 16; i++) buf[i] = (uint8_t)(i + 1);
        er_memmove(buf + 4, buf, 12);
        ok = 1;
        for (size_t i = 0; i < 12; i++)
            if (buf[4 + i] != (uint8_t)(i + 1)) { ok = 0; break; }
        TEST("memmove forward overlap", ok);

        er_memset(buf, 0, sizeof(buf));
        for (size_t i = 0; i < 16; i++) buf[i] = (uint8_t)(i + 1);
        er_memmove(buf, buf + 4, 12);
        ok = 1;
        for (size_t i = 0; i < 12; i++)
            if (buf[i] != (uint8_t)(i + 5)) { ok = 0; break; }
        TEST("memmove backward overlap", ok);
    }

    {
        const char* str = "hello world";
        TEST("memchr find first 'l'",   er_memchr(str, 'l', 11) == str + 2);
        TEST("memchr find 'h'",         er_memchr(str, 'h', 11) == str);
        TEST("memchr find 'd'",         er_memchr(str, 'd', 11) == str + 10);
        TEST("memchr not found",        er_memchr(str, 'z', 11) == 0);
        TEST("memchr zero length",      er_memchr(str, 'h', 0)  == 0);
        TEST("memchr null ptr 0 len",   er_memchr(0, 'x', 0) == 0);
    }

    {
        const char* str = "hello world";
        TEST("memrchr find last 'l'",   er_memrchr(str, 'l', 11) == str + 9);
        TEST("memrchr find 'h'",        er_memrchr(str, 'h', 11) == str);
        TEST("memrchr find 'd'",        er_memrchr(str, 'd', 11) == str + 10);
        TEST("memrchr not found",       er_memrchr(str, 'z', 11) == 0);
        TEST("memrchr zero length",     er_memrchr(str, 'h', 0)  == 0);
    }

    {
        uint32_t buf[16];
        er_memset(buf, 0xcc, sizeof(buf));

        void* result = er_memset32(buf, 0xaabbccdd, 4);
        TEST("memset32 returns dst", result == buf);
        TEST_EQ("memset32 elem 0", buf[0], 0xaabbccddu);
        TEST_EQ("memset32 elem 1", buf[1], 0xaabbccddu);
        TEST_EQ("memset32 elem 2", buf[2], 0xaabbccddu);
        TEST_EQ("memset32 elem 3", buf[3], 0xaabbccddu);
        int ok = 1;
        for (int i = 4; i < 16; i++)
            if (buf[i] != 0xccccccccu) { ok = 0; break; }
        TEST("memset32 rest untouched", ok);
    }

    {
        uint64_t buf[16];
        er_memset(buf, 0xcc, sizeof(buf));

        void* result = er_memset64(buf, 0xdeadbeefcafebabeULL, 3);
        TEST("memset64 returns dst", result == buf);
        TEST_EQ("memset64 elem 0", buf[0], 0xdeadbeefcafebabeULL);
        TEST_EQ("memset64 elem 1", buf[1], 0xdeadbeefcafebabeULL);
        TEST_EQ("memset64 elem 2", buf[2], 0xdeadbeefcafebabeULL);
        int ok = 1;
        for (int i = 3; i < 16; i++)
            if (buf[i] != 0xccccccccccccccccULL) { ok = 0; break; }
        TEST("memset64 rest untouched", ok);
    }

    {
        const char* str = "hello world";
        TEST("strchr find 'h'",     er_strchr(str, 'h') == str);
        TEST("strchr find 'l'",     er_strchr(str, 'l') == str + 2);
        TEST("strchr find 'w'",     er_strchr(str, 'w') == str + 6);
        TEST("strchr find 'd'",     er_strchr(str, 'd') == str + 10);
        TEST("strchr find null",    er_strchr(str, 0)   == str + 11);
        TEST("strchr not found",    er_strchr(str, 'z') == 0);
        TEST("strchr null ptr",     er_strchr(0, 'x') == 0);
    }

    {
        const char* str = "hello world";
        TEST("strrchr find 'h'",    er_strrchr(str, 'h') == str);
        TEST("strrchr find 'l'",    er_strrchr(str, 'l') == str + 9);
        TEST("strrchr find 'd'",    er_strrchr(str, 'd') == str + 10);
        TEST("strrchr not found",   er_strrchr(str, 'z') == 0);
    }

    {
        char buf[32];
        er_memset(buf, 0xcc, sizeof(buf));

        char* result = er_strncpy(buf, "hello", 10);
        TEST("strncpy returns dst", result == buf);
        TEST("strncpy content",     er_strcmp(buf, "hello") == 0);
        TEST("strncpy null-padded", buf[5] == 0 && buf[6] == 0 && buf[7] == 0 && buf[8] == 0 && buf[9] == 0);

        er_memset(buf, 0xcc, sizeof(buf));
        er_strncpy(buf, "hello", 3);
        TEST("strncpy truncated",   er_memcmp(buf, "hel", 3) == 0);
        TEST("strncpy no null-term", buf[3] == (char)0xcc);

        er_memset(buf, 0xcc, sizeof(buf));
        er_strncpy(buf, "", 5);
        TEST("strncpy empty src",   buf[0] == 0 && buf[4] == 0);
    }

    {
        char buf[32];
        er_memset(buf, 0, sizeof(buf));
        er_strcpy(buf, "hello");

        char* result = er_strncat(buf, " world", 3);
        TEST("strncat returns dst", result == buf);
        TEST("strncat partial",     er_strcmp(buf, "hello wo") == 0);
        TEST("strncat null-term",   buf[9] == 0);

        er_memset(buf, 0, sizeof(buf));
        er_strcpy(buf, "hello");
        result = er_strncat(buf, " world", 10);
        TEST("strncat full",        er_strcmp(buf, "hello world") == 0);

        er_memset(buf, 0, sizeof(buf));
        er_strcpy(buf, "hello");
        result = er_strncat(buf, "", 5);
        TEST("strncat empty src",   er_strcmp(buf, "hello") == 0);
    }

    {
        TEST("strncmp equal",        er_strncmp("hello", "hello", 5) == 0);
        TEST("strncmp lt",           er_strncmp("abc", "abd", 3) < 0);
        TEST("strncmp gt",           er_strncmp("abd", "abc", 3) > 0);
        TEST("strncmp limited",      er_strncmp("abcde", "abcxy", 3) == 0);
        TEST("strncmp zero n",       er_strncmp("abc", "def", 0) == 0);
        TEST("strncmp past null",    er_strncmp("ab\0x", "ab\0y", 4) == 0);
    }

    {
        TEST("strcasecmp equal",        er_strcasecmp("hello", "hello") == 0);
        TEST("strcasecmp case diff",    er_strcasecmp("Hello", "hello") == 0);
        TEST("strcasecmp upper",        er_strcasecmp("HELLO", "hello") == 0);
        TEST("strcasecmp mixed",        er_strcasecmp("HeLLo", "hElLo") == 0);
        TEST("strcasecmp lt",           er_strcasecmp("abc", "abd") < 0);
        TEST("strcasecmp gt",           er_strcasecmp("abd", "abc") > 0);
        TEST("strcasecmp empty",        er_strcasecmp("", "") == 0);
    }

    {
        const char* haystack = "hello world";
        TEST("strstr find at start",  er_strstr(haystack, "hello") == haystack);
        TEST("strstr find middle",    er_strstr(haystack, "world") == haystack + 6);
        TEST("strstr find single",    er_strstr(haystack, " ")     == haystack + 5);
        TEST("strstr empty needle",   er_strstr(haystack, "")      == haystack);
        TEST("strstr not found",      er_strstr(haystack, "xyz")   == 0);
        TEST("strstr null haystack",  er_strstr(0, "x")           == 0);
        TEST("strstr null needle",    er_strstr("x", 0)           == 0);
    }

    {
        char* end;
        TEST_EQ("strtou64 basic",       er_strtou64("123", 0), 123);
        TEST_EQ("strtou64 zero",        er_strtou64("0", 0), 0);
        TEST_EQ("strtou64 leading ws",  er_strtou64("  456", 0), 456);
        TEST_EQ("strtou64 positive",    er_strtou64("+789", 0), 789);
        TEST_EQ("strtou64 negative",    er_strtou64("-42", 0), (uint64_t)-42);

        uint64_t val = er_strtou64("987xyz", &end);
        TEST_EQ("strtou64 endptr val", val, 987);
        TEST("strtou64 endptr pos", end != 0 && *end == 'x');

        TEST_EQ("strtou64 max",         er_strtou64("18446744073709551615", 0), -1ULL);
        TEST_EQ("strtou64 overflow",    er_strtou64("18446744073709551616", 0), -1ULL);
        TEST_EQ("strtou64 no digits",   er_strtou64("abc", 0), 0);
    }

    {
        TEST_EQ("strtoi64 basic",       (uint64_t)er_strtoi64("123", 0), 123);
        TEST_EQ("strtoi64 negative",    (uint64_t)er_strtoi64("-123", 0), (uint64_t)-123);
        TEST_EQ("strtoi64 zero",        (uint64_t)er_strtoi64("0", 0), 0);
        TEST_EQ("strtoi64 max",         (uint64_t)er_strtoi64("9223372036854775807", 0), 9223372036854775807ULL);
        TEST_EQ("strtoi64 min",         (uint64_t)er_strtoi64("-9223372036854775808", 0), 0x8000000000000000ULL);
        TEST_EQ("strtoi64 overflow pos", (uint64_t)er_strtoi64("999999999999999999999", 0), 9223372036854775807ULL);
        TEST_EQ("strtoi64 overflow neg", (uint64_t)er_strtoi64("-999999999999999999999", 0), 0x8000000000000000ULL);
    }

    {
        char* end;
        TEST_EQ("strtou64_hex basic",   er_strtou64_hex("ff", 0), 255);
        TEST_EQ("strtou64_hex prefix",  er_strtou64_hex("0xFF", 0), 255);
        TEST_EQ("strtou64_hex lower",   er_strtou64_hex("0x1a", 0), 26);
        TEST_EQ("strtou64_hex zero",    er_strtou64_hex("0", 0), 0);
        TEST_EQ("strtou64_hex leading ws", er_strtou64_hex("  0xabc", 0), 0xabc);
        TEST_EQ("strtou64_hex max",     er_strtou64_hex("FFFFFFFFFFFFFFFF", 0), -1ULL);
        TEST_EQ("strtou64_hex overflow", er_strtou64_hex("1FFFFFFFFFFFFFFFF", 0), -1ULL);

        uint64_t val = er_strtou64_hex("0xABCxyz", &end);
        TEST_EQ("strtou64_hex endptr val", val, 0xABC);
        TEST("strtou64_hex endptr pos", end != 0 && *end == 'x');
    }

    {
        TEST_EQ("strspn abc in abcdef", er_strspn("abcdef", "abc"), 3);
        TEST_EQ("strspn all match",     er_strspn("aaa", "a"), 3);
        TEST_EQ("strspn no match",      er_strspn("def", "abc"), 0);
        TEST_EQ("strspn empty str",     er_strspn("", "abc"), 0);
        TEST_EQ("strspn empty accept",  er_strspn("abc", ""), 0);
        TEST_EQ("strspn with digits",   er_strspn("123abc", "0123456789"), 3);
    }

    {
        TEST_EQ("strcspn stop at x",    er_strcspn("abcdef", "x"), 6);
        TEST_EQ("strcspn stop at d",    er_strcspn("abcdef", "d"), 3);
        TEST_EQ("strcspn empty str",    er_strcspn("", "abc"), 0);
        TEST_EQ("strcspn empty reject", er_strcspn("abc", ""), 3);
        TEST_EQ("strcspn first char",   er_strcspn("abcdef", "a"), 0);
    }

    {
        const char* str = "hello world";
        TEST("strpbrk find space",  er_strpbrk(str, " ")  == str + 5);
        TEST("strpbrk find o",      er_strpbrk(str, "wo") == str + 4);
        TEST("strpbrk not found",   er_strpbrk(str, "xyz") == 0);
        TEST("strpbrk empty set",   er_strpbrk(str, "")   == 0);
        TEST("strpbrk empty str",   er_strpbrk("", "abc") == 0);
    }

    {
        char buf[32];
        er_memset(buf, 0xcc, sizeof(buf));

        void* result = er_memccpy(buf, "hello|world", '|', 12);
        TEST("memccpy returns after stop", result == buf + 6);
        TEST("memccpy content before stop", er_memcmp(buf, "hello|", 6) == 0);

        result = er_memccpy(buf, "hello", 'x', 5);
        TEST("memccpy not found",  result == 0);
        TEST("memccpy copied all", er_memcmp(buf, "hello", 5) == 0);

        result = er_memccpy(buf, "ab|c", '|', 2);
        TEST("memccpy limit before stop", result == 0);
    }

    {
        TEST("memicmp equal",        er_memicmp("hello", "hello", 5) == 0);
        TEST("memicmp case diff",    er_memicmp("Hello", "hello", 5) == 0);
        TEST("memicmp upper",        er_memicmp("HELLO", "hello", 5) == 0);
        TEST("memicmp lt",           er_memicmp("abc", "abd", 3) < 0);
        TEST("memicmp zero len",     er_memicmp("abc", "xyz", 0) == 0);
    }

    {
        uint8_t a[16] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
        uint8_t b[16] = {16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1};
        uint8_t a_copy[16], b_copy[16];
        er_memcpy(a_copy, a, 16);
        er_memcpy(b_copy, b, 16);

        er_memswap(a, b, 16);
        int ok = 1;
        for (int i = 0; i < 16; i++)
            if (a[i] != b_copy[i] || b[i] != a_copy[i]) { ok = 0; break; }
        TEST("memswap full", ok);

        uint8_t c[4] = {1,2,3,4};
        uint8_t d[4] = {5,6,7,8};
        er_memswap(c, d, 3);
        TEST("memswap partial", c[0] == 5 && c[1] == 6 && c[2] == 7 && c[3] == 4);
        TEST("memswap partial b", d[0] == 1 && d[1] == 2 && d[2] == 3 && d[3] == 8);

        er_memswap(a, b, 0);
        TEST("memswap zero", a[0] == b_copy[0]);
    }

    {
        char hex[32];
        uint8_t data[16] = {0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE, 0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF};
        er_hex_encode(data, 16, hex);
        TEST("hex_encode result", er_memcmp(hex, "deadbeefcafebabe0123456789abcdef", 32) == 0);

        uint8_t decoded[16];
        size_t n = er_hex_decode(hex, 32, decoded);
        TEST_EQ("hex_decode count", n, 16);
        TEST("hex_decode roundtrip", er_memcmp(decoded, data, 16) == 0);

        er_hex_encode((const uint8_t*)"\x01\x02", 2, hex);
        TEST("hex_encode short", er_memcmp(hex, "0102", 4) == 0);

        n = er_hex_decode("", 0, decoded);
        TEST_EQ("hex_decode empty", n, 0);

        n = er_hex_decode("abc", 3, decoded);
        TEST_EQ("hex_decode odd", n, 0);

        n = er_hex_decode("xxyz", 4, decoded);
        TEST_EQ("hex_decode invalid", n, 0);
    }

    {
        char buf[8];

        int n = er_utf8_encode(0x41, buf);
        TEST_EQ("utf8_encode ASCII len", n, 1);
        TEST("utf8_encode ASCII val", buf[0] == 'A');

        n = er_utf8_encode(0xA9, buf);
        TEST_EQ("utf8_encode 2byte len", n, 2);
        TEST("utf8_encode 2byte bytes", (uint8_t)buf[0] == 0xC2 && (uint8_t)buf[1] == 0xA9);

        n = er_utf8_encode(0x4E00, buf);
        TEST_EQ("utf8_encode 3byte len", n, 3);
        TEST("utf8_encode 3byte lead", (uint8_t)buf[0] == 0xE4 && (uint8_t)buf[1] == 0xB8 && (uint8_t)buf[2] == 0x80);

        n = er_utf8_encode(0x1F600, buf);
        TEST_EQ("utf8_encode 4byte len", n, 4);
        TEST("utf8_encode 4byte lead", (uint8_t)buf[0] == 0xF0 && (uint8_t)buf[1] == 0x9F && (uint8_t)buf[2] == 0x98 && (uint8_t)buf[3] == 0x80);

        n = er_utf8_encode(0x110000, buf);
        TEST_EQ("utf8_encode invalid", n, 0);

        size_t len;
        uint32_t cp = er_utf8_decode("\xE4\xB8\x80", &len);
        TEST_EQ("utf8_decode 3byte len", len, 3);
        TEST_EQ("utf8_decode 3byte cp", cp, 0x4E00);

        cp = er_utf8_decode("\xF0\x9F\x98\x80", &len);
        TEST_EQ("utf8_decode 4byte len", len, 4);
        TEST_EQ("utf8_decode 4byte cp", cp, 0x1F600);

        cp = er_utf8_decode("\xE4\x00\x80", &len);
        TEST_EQ("utf8_decode invalid len", len, 0);
        TEST_EQ("utf8_decode invalid cp", cp, 0);

        cp = er_utf8_decode("A", &len);
        TEST_EQ("utf8_decode 1byte len", len, 1);
        TEST_EQ("utf8_decode 1byte cp", cp, 0x41);
    }

    {
        char str[] = "hello,world,test";
        char* tok = er_strtok(str, ",");
        TEST("strtok first", tok != 0 && er_strcmp(tok, "hello") == 0);
        tok = er_strtok(0, ",");
        TEST("strtok second", tok != 0 && er_strcmp(tok, "world") == 0);
        tok = er_strtok(0, ",");
        TEST("strtok third", tok != 0 && er_strcmp(tok, "test") == 0);
        tok = er_strtok(0, ",");
        TEST("strtok end", tok == 0);

        char str2[] = "a,,b,c";
        tok = er_strtok(str2, ",");
        TEST("strtok consec first", tok != 0 && er_strcmp(tok, "a") == 0);
        tok = er_strtok(0, ",");
        TEST("strtok consec second", tok != 0 && er_strcmp(tok, "b") == 0);

        char str3[] = "foo bar baz";
        tok = er_strtok(str3, " ");
        TEST("strtok space first", tok != 0 && er_strcmp(tok, "foo") == 0);
        tok = er_strtok(0, " ");
        TEST("strtok space second", tok != 0 && er_strcmp(tok, "bar") == 0);
    }

    {
        TEST_EQ("strtou64_base 10", er_strtou64_base("123", 0, 10), 123);
        TEST_EQ("strtoi64_base 10", (uint64_t)er_strtoi64_base("-123", 0, 10), (uint64_t)-123);

        TEST_EQ("strtou64_base 16", er_strtou64_base("FF", 0, 16), 255);
        TEST_EQ("strtou64_base 16b", er_strtou64_base("ff", 0, 16), 255);

        TEST_EQ("strtou64_base 2", er_strtou64_base("1010", 0, 2), 10);

        TEST_EQ("strtou64_base 36", er_strtou64_base("ZZ", 0, 36), 35*36 + 35);

        TEST_EQ("strtou64_base bad base", er_strtou64_base("123", 0, 1), 0);
        TEST_EQ("strtou64_base bad base2", er_strtou64_base("123", 0, 37), 0);

        char* end;
        uint64_t v = er_strtou64_base("1a2b", &end, 16);
        TEST_EQ("strtou64_base endptr val", v, 0x1a2b);
        TEST("strtou64_base endptr pos", end != 0 && *end == 0);

        v = er_strtou64_base("123xyz", &end, 10);
        TEST_EQ("strtou64_base partial val", v, 123);
        TEST("strtou64_base partial end", end != 0 && *end == 'x');

        TEST_EQ("strtoi64_base overflow pos", (uint64_t)er_strtoi64_base("999999999999999999999", 0, 10), 9223372036854775807ULL);
        TEST_EQ("strtoi64_base overflow neg", (uint64_t)er_strtoi64_base("-999999999999999999999", 0, 10), 0x8000000000000000ULL);
    }

    return (passed_tests == total_tests) ? 0 : 1;
}
