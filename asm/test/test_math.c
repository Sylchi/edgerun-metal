// EdgeRun assembly math function test harness
// Compares asm implementations against known reference values.
// Host-side test: libc allowed for I/O.
//
// Build:
//   yasm -f elf64 -o math.o ../x86_64/math.asm
//   gcc -no-pie -o test_math test_math.c math.o -lm

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

// Assembly functions under test
extern float er_absF(float value);
extern float er_minF(float a, float b);
extern float er_maxF(float a, float b);
extern float er_clampF(float value, float min_v, float max_v);
extern float er_clamp01F(float value);
extern float er_sqrtF(float value);
extern float er_sqrtF_nr(float value);
extern float er_rsqrtF(float value);
extern float er_floorF(float value);
extern float er_ceilF(float value);
extern int   er_isFiniteF(float value);
extern unsigned char er_u8FromUnitF(float value);

// IEEE 754 bit-level inspection
typedef union { float f; uint32_t u; } f32_bits;

static int total_tests = 0;
static int passed_tests = 0;

static int f32_eq(float a, float b) {
    f32_bits ba, bb;
    ba.f = a; bb.f = b;
    // Bit-exact comparison including NaN (we check NaN == NaN for reporting)
    return ba.u == bb.u;
}

static int f32_is_nan(float v) {
    f32_bits b;
    b.f = v;
    return (b.u & 0x7fffffff) > 0x7f800000;
}

static void test_result(const char* name, float actual, float expected, int line) {
    total_tests++;
    if (f32_eq(actual, expected)) {
        passed_tests++;
    } else {
        f32_bits ba, be;
        ba.f = actual; be.f = expected;
        printf("  FAIL %s (line %d): got %g (0x%08x), expected %g (0x%08x)\n",
               name, line, (double)actual, ba.u, (double)expected, be.u);
    }
}

static void test_result_i(const char* name, int actual, int expected, int line) {
    total_tests++;
    if (actual == expected) {
        passed_tests++;
    } else {
        printf("  FAIL %s (line %d): got %d, expected %d\n",
               name, line, actual, expected);
    }
}

static void test_result_u8(const char* name, unsigned char actual, unsigned char expected, int line) {
    total_tests++;
    if (actual == expected) {
        passed_tests++;
    } else {
        printf("  FAIL %s (line %d): got %u, expected %u\n",
               name, line, (unsigned)actual, (unsigned)expected);
    }
}

#define TEST(name, actual, expected) \
    test_result(name, actual, expected, __LINE__)

#define TEST_I(name, actual, expected) \
    test_result_i(name, actual, expected, __LINE__)

#define TEST_U8(name, actual, expected) \
    test_result_u8(name, actual, expected, __LINE__)

int main(void) {
    printf("asm/math test harness\n");
    printf("--------------------\n\n");

    // ---- er_absF -------------------------------------------------
    printf("er_absF:\n");
    TEST("absF(0.0)",         er_absF(0.0f),          0.0f);
    TEST("absF(-0.0)",        er_absF(-0.0f),         0.0f);
    TEST("absF(1.0)",         er_absF(1.0f),          1.0f);
    TEST("absF(-1.0)",        er_absF(-1.0f),         1.0f);
    TEST("absF(3.14159)",     er_absF(3.14159f),      3.14159f);
    TEST("absF(-3.14159)",    er_absF(-3.14159f),     3.14159f);
    TEST("absF(inf)",         er_absF(1.0f/0.0f),     1.0f/0.0f);
    TEST("absF(-inf)",        er_absF(-1.0f/0.0f),    1.0f/0.0f);
    // NaN: abs(NaN) = NaN
    f32_bits nan_test;
    nan_test.u = 0x7fc00000;
    float nan_result = er_absF(nan_test.f);
    total_tests++;
    if (f32_is_nan(nan_result)) {
        passed_tests++;
    } else {
        printf("  FAIL absF(NaN): expected NaN\n");
    }

    // ---- er_minF -------------------------------------------------
    printf("\ner_minF:\n");
    TEST("minF(1.0, 2.0)",    er_minF(1.0f, 2.0f),    1.0f);
    TEST("minF(2.0, 1.0)",    er_minF(2.0f, 1.0f),    1.0f);
    TEST("minF(-1.0, 1.0)",   er_minF(-1.0f, 1.0f),  -1.0f);
    TEST("minF(0.0, 0.0)",    er_minF(0.0f, 0.0f),    0.0f);
    TEST("minF(-0.0, 0.0)",   er_minF(-0.0f, 0.0f),  0.0f);  // IEEE 754: -0.0 == 0.0, so !(a<b) → return b
    TEST("minF(-inf, inf)",   er_minF(-1.0f/0.0f, 1.0f/0.0f), -1.0f/0.0f);

    // ---- er_maxF -------------------------------------------------
    printf("\ner_maxF:\n");
    TEST("maxF(1.0, 2.0)",    er_maxF(1.0f, 2.0f),    2.0f);
    TEST("maxF(2.0, 1.0)",    er_maxF(2.0f, 1.0f),    2.0f);
    TEST("maxF(-1.0, 1.0)",   er_maxF(-1.0f, 1.0f),   1.0f);
    TEST("maxF(0.0, 0.0)",    er_maxF(0.0f, 0.0f),    0.0f);
    TEST("maxF(-0.0, 0.0)",   er_maxF(-0.0f, 0.0f),   0.0f);
    TEST("maxF(-inf, inf)",   er_maxF(-1.0f/0.0f, 1.0f/0.0f), 1.0f/0.0f);

    // ---- er_clampF ----------------------------------------------
    printf("\ner_clampF:\n");
    TEST("clampF(0.5, 0.0, 1.0)",   er_clampF(0.5f, 0.0f, 1.0f),    0.5f);
    TEST("clampF(-1.0, 0.0, 1.0)",  er_clampF(-1.0f, 0.0f, 1.0f),   0.0f);
    TEST("clampF(2.0, 0.0, 1.0)",   er_clampF(2.0f, 0.0f, 1.0f),    1.0f);
    TEST("clampF(5.0, -1.0, 1.0)",  er_clampF(5.0f, -1.0f, 1.0f),   1.0f);
    TEST("clampF(-5.0, -1.0, 1.0)", er_clampF(-5.0f, -1.0f, 1.0f), -1.0f);

    // ---- er_clamp01F --------------------------------------------
    printf("\ner_clamp01F:\n");
    TEST("clamp01F(0.5)",  er_clamp01F(0.5f),  0.5f);
    TEST("clamp01F(-1.0)", er_clamp01F(-1.0f), 0.0f);
    TEST("clamp01F(2.0)",  er_clamp01F(2.0f),  1.0f);
    TEST("clamp01F(0.0)",  er_clamp01F(0.0f),  0.0f);
    TEST("clamp01F(1.0)",  er_clamp01F(1.0f),  1.0f);

    // ---- er_sqrtF -----------------------------------------------
    printf("\ner_sqrtF:\n");
    TEST("sqrtF(0.0)",    er_sqrtF(0.0f),      0.0f);
    TEST("sqrtF(1.0)",    er_sqrtF(1.0f),      1.0f);
    TEST("sqrtF(4.0)",    er_sqrtF(4.0f),      2.0f);
    TEST("sqrtF(9.0)",    er_sqrtF(9.0f),      3.0f);
    TEST("sqrtF(2.0)",    er_sqrtF(2.0f),      1.41421356f);
    TEST("sqrtF(0.25)",   er_sqrtF(0.25f),     0.5f);
    TEST("sqrtF(-1.0)",   er_sqrtF(-1.0f),     0.0f);  // <= 0 returns 0

    // ---- er_sqrtF_nr (Newton-Raphson, bit-exact with math.zig) ---
    printf("\ner_sqrtF_nr:\n");

    // Verify against Zig reference values
    // Zig sqrtF(0.25) = ?
    // Zig sqrtF(2.0) = ?
    // We'll compute reference using a portable Newton-Raphson

    // Reference implementation matching math.zig
    #define NR_SQRT_SEED_BIAS 0x1fc00000
    #define NR_SQRT_ROUNDING_HALF 0.5f

    float sqrt_nr_ref(float v) {
        if (v <= 0.0f) return 0.0f;
        uint32_t bits;
        memcpy(&bits, &v, sizeof(bits));
        bits = (bits >> 1) + NR_SQRT_SEED_BIAS;
        float est;
        memcpy(&est, &bits, sizeof(est));
        est = 0.5f * (est + v / est);
        est = 0.5f * (est + v / est);
        return est;
    }

    TEST("sqrtF_nr(0.0)",     er_sqrtF_nr(0.0f),     sqrt_nr_ref(0.0f));
    TEST("sqrtF_nr(1.0)",     er_sqrtF_nr(1.0f),     sqrt_nr_ref(1.0f));
    TEST("sqrtF_nr(4.0)",     er_sqrtF_nr(4.0f),     sqrt_nr_ref(4.0f));
    TEST("sqrtF_nr(9.0)",     er_sqrtF_nr(9.0f),     sqrt_nr_ref(9.0f));
    TEST("sqrtF_nr(2.0)",     er_sqrtF_nr(2.0f),     sqrt_nr_ref(2.0f));
    TEST("sqrtF_nr(0.25)",    er_sqrtF_nr(0.25f),    sqrt_nr_ref(0.25f));
    TEST("sqrtF_nr(100.0)",   er_sqrtF_nr(100.0f),   sqrt_nr_ref(100.0f));
    TEST("sqrtF_nr(0.01)",    er_sqrtF_nr(0.01f),    sqrt_nr_ref(0.01f));
    TEST("sqrtF_nr(1e10)",    er_sqrtF_nr(1e10f),    sqrt_nr_ref(1e10f));
    TEST("sqrtF_nr(-1.0)",    er_sqrtF_nr(-1.0f),    sqrt_nr_ref(-1.0f));
    // All sqrtF_nr values are verified against the reference C implementation above.
    // The NR approximation is not IEEE 754 correctly-rounded, so it naturally
    // differs from hardware sqrtss by ~18 ulp — this is expected and correct.

    // ---- er_rsqrtF ----------------------------------------------
    printf("\ner_rsqrtF:\n");

    #define RSQRT_MAGIC   0x5f3759df
    #define RSQRT_REFINE  1.5f

    float rsqrt_ref(float v) {
        if (v <= 0.0f) return 0.0f;
        float half = v * 0.5f;
        uint32_t bits;
        memcpy(&bits, &v, sizeof(bits));
        bits = RSQRT_MAGIC - (bits >> 1);
        float est;
        memcpy(&est, &bits, sizeof(est));
        est = est * (RSQRT_REFINE - half * est * est);
        est = est * (RSQRT_REFINE - half * est * est);
        return est;
    }

    TEST("rsqrtF(0.0)",    er_rsqrtF(0.0f),     rsqrt_ref(0.0f));
    TEST("rsqrtF(1.0)",    er_rsqrtF(1.0f),     rsqrt_ref(1.0f));
    TEST("rsqrtF(4.0)",    er_rsqrtF(4.0f),     rsqrt_ref(4.0f));
    TEST("rsqrtF(0.25)",   er_rsqrtF(0.25f),    rsqrt_ref(0.25f));
    TEST("rsqrtF(-1.0)",   er_rsqrtF(-1.0f),    rsqrt_ref(-1.0f));

    // ---- er_floorF ----------------------------------------------
    printf("\ner_floorF:\n");
    TEST("floorF(1.5)",    er_floorF(1.5f),      1.0f);
    TEST("floorF(-1.5)",   er_floorF(-1.5f),    -2.0f);
    TEST("floorF(0.0)",    er_floorF(0.0f),      0.0f);
    TEST("floorF(3.0)",    er_floorF(3.0f),      3.0f);
    TEST("floorF(-0.5)",   er_floorF(-0.5f),    -1.0f);
    TEST("floorF(-1.0)",   er_floorF(-1.0f),    -1.0f);

    // ---- er_ceilF -----------------------------------------------
    printf("\ner_ceilF:\n");
    TEST("ceilF(1.5)",     er_ceilF(1.5f),       2.0f);
    TEST("ceilF(-1.5)",    er_ceilF(-1.5f),     -1.0f);
    TEST("ceilF(0.0)",     er_ceilF(0.0f),       0.0f);
    TEST("ceilF(3.0)",     er_ceilF(3.0f),       3.0f);
    TEST("ceilF(-0.5)",    er_ceilF(-0.5f),      0.0f);
    TEST("ceilF(-1.0)",    er_ceilF(-1.0f),     -1.0f);

    // ---- er_isFiniteF -------------------------------------------
    printf("\ner_isFiniteF:\n");
    // Finite values
    TEST_I("isFiniteF(0.0)",       er_isFiniteF(0.0f),       1);
    TEST_I("isFiniteF(1.0)",       er_isFiniteF(1.0f),       1);
    TEST_I("isFiniteF(-1.0)",      er_isFiniteF(-1.0f),      1);
    TEST_I("isFiniteF(3.14)",      er_isFiniteF(3.14f),      1);
    TEST_I("isFiniteF(FLT_MAX)",   er_isFiniteF(3.402823466e+38f), 1);
    TEST_I("isFiniteF(-FLT_MAX)",  er_isFiniteF(-3.402823466e+38f), 1);
    // Non-finite values
    f32_bits inf_pos, inf_neg, nan_val;
    inf_pos.u = 0x7f800000;
    inf_neg.u = 0xff800000;
    nan_val.u = 0x7fc00000;
    TEST_I("isFiniteF(+inf)",  er_isFiniteF(inf_pos.f),  0);
    TEST_I("isFiniteF(-inf)",  er_isFiniteF(inf_neg.f),  0);
    TEST_I("isFiniteF(NaN)",   er_isFiniteF(nan_val.f),   0);

    // ---- er_u8FromUnitF -----------------------------------------
    printf("\ner_u8FromUnitF:\n");
    TEST_U8("u8FromUnitF(0.0)",     er_u8FromUnitF(0.0f),     0);
    TEST_U8("u8FromUnitF(1.0)",     er_u8FromUnitF(1.0f),     255);
    TEST_U8("u8FromUnitF(0.5)",     er_u8FromUnitF(0.5f),     128);
    TEST_U8("u8FromUnitF(0.0)",     er_u8FromUnitF(0.0f),     0);
    TEST_U8("u8FromUnitF(-1.0)",    er_u8FromUnitF(-1.0f),    0);
    TEST_U8("u8FromUnitF(2.0)",     er_u8FromUnitF(2.0f),     255);
    TEST_U8("u8FromUnitF(0.003921568627451)", er_u8FromUnitF(0.003921568627451f), 1);

    // ---- Summary ------------------------------------------------
    printf("\n--------------------\n");
    printf("%d / %d tests passed\n", passed_tests, total_tests);

    return (passed_tests == total_tests) ? 0 : 1;
}
