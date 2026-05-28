// EdgeRun assembly math function test harness
// Freestanding — no libc, no libm.
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef int                int32_t;
typedef long long          int64_t;
typedef unsigned long      size_t;

extern void* er_memset(void* dst, int value, size_t num);
extern int   er_memcmp(const void* ptr1, const void* ptr2, size_t num);

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

extern int32_t   er_abs_i32(int32_t value);
extern int64_t   er_abs_i64(int64_t value);
extern uint32_t  er_clz32(uint32_t value);
extern uint64_t  er_clz64(uint64_t value);
extern uint32_t  er_ctz32(uint32_t value);
extern uint64_t  er_ctz64(uint64_t value);
extern uint32_t  er_popcount32(uint32_t value);
extern uint64_t  er_popcount64(uint64_t value);
extern uint64_t  er_umulhi(uint64_t a, uint64_t b);
extern int64_t   er_smulhi(int64_t a, int64_t b);
extern uint32_t  er_div_u32(uint32_t dividend, uint32_t divisor);
extern uint32_t  er_mod_u32(uint32_t dividend, uint32_t divisor);
extern uint64_t  er_div_u64(uint64_t dividend, uint64_t divisor);
extern uint64_t  er_mod_u64(uint64_t dividend, uint64_t divisor);
extern void      er_divmod_u32(uint32_t dividend, uint32_t divisor, uint32_t* quot, uint32_t* rem);
extern void      er_divmod_u64(uint64_t dividend, uint64_t divisor, uint64_t* quot, uint64_t* rem);
extern void      er_divmod_i32(int32_t dividend, int32_t divisor, int32_t* quot, int32_t* rem);
extern int       er_is_power_of_two_u64(uint64_t value);
extern uint64_t  er_align_down_u64(uint64_t value, uint64_t alignment);
extern uint64_t  er_align_up_u64(uint64_t value, uint64_t alignment);
extern uint64_t  er_min_u64(uint64_t a, uint64_t b);
extern uint64_t  er_max_u64(uint64_t a, uint64_t b);
extern uint64_t  er_clamp_u64(uint64_t value, uint64_t min_v, uint64_t max_v);
extern uint64_t  er_div_ceil_u64(uint64_t dividend, uint64_t divisor);
extern uint64_t  er_log2_u64(uint64_t value);
extern uint64_t  er_round_up_pow2_u64(uint64_t value);
extern uint32_t  er_rotl32(uint32_t value, unsigned int count);
extern uint32_t  er_rotr32(uint32_t value, unsigned int count);
extern uint64_t  er_rotl64(uint64_t value, unsigned int count);
extern uint64_t  er_rotr64(uint64_t value, unsigned int count);
extern uint16_t  er_bswap16(uint16_t value);
extern uint32_t  er_bswap32(uint32_t value);
extern uint64_t  er_bswap64(uint64_t value);
extern uint64_t  er_xorshift64(uint64_t* state);
extern uint32_t  er_min_u32(uint32_t a, uint32_t b);
extern uint32_t  er_max_u32(uint32_t a, uint32_t b);
extern uint32_t  er_clamp_u32(uint32_t value, uint32_t min_v, uint32_t max_v);
extern int32_t   er_min_i32(int32_t a, int32_t b);
extern int32_t   er_max_i32(int32_t a, int32_t b);
extern int32_t   er_clamp_i32(int32_t value, int32_t min_v, int32_t max_v);
extern int64_t   er_min_i64(int64_t a, int64_t b);
extern int64_t   er_max_i64(int64_t a, int64_t b);
extern int64_t   er_clamp_i64(int64_t value, int64_t min_v, int64_t max_v);
extern uint32_t  er_div_ceil_u32(uint32_t dividend, uint32_t divisor);
extern uint32_t  er_crc32c(uint32_t crc, const void* data, size_t len);
extern uint64_t  er_fnv1a64(const void* data, size_t len);

typedef union { float f; uint32_t u; } f32_bits;

static int total_tests = 0;
static int passed_tests = 0;

static int f32_eq(float a, float b) {
    f32_bits ba, bb;
    ba.f = a; bb.f = b;
    return ba.u == bb.u;
}

static int f32_is_nan(float v) {
    f32_bits b;
    b.f = v;
    return (b.u & 0x7fffffff) > 0x7f800000;
}

#define TEST(name, actual, expected) do { \
    total_tests++; \
    if (f32_eq(actual, expected)) { passed_tests++; } \
} while(0)

#define TEST_I(name, actual, expected) do { \
    total_tests++; \
    if ((actual) == (expected)) { passed_tests++; } \
} while(0)

int main(void) {
    TEST("absF(0.0)",         er_absF(0.0f),          0.0f);
    TEST("absF(-0.0)",        er_absF(-0.0f),         0.0f);
    TEST("absF(1.0)",         er_absF(1.0f),          1.0f);
    TEST("absF(-1.0)",        er_absF(-1.0f),         1.0f);
    TEST("absF(3.14159)",     er_absF(3.14159f),      3.14159f);
    TEST("absF(-3.14159)",    er_absF(-3.14159f),     3.14159f);
    {
        f32_bits inf_p, inf_n;
        inf_p.u = 0x7f800000;
        inf_n.u = 0xff800000;
        TEST("absF(inf)",         er_absF(inf_p.f),     inf_p.f);
        TEST("absF(-inf)",        er_absF(inf_n.f),     inf_p.f);
    }
    {
        f32_bits nan_test;
        nan_test.u = 0x7fc00000;
        float nan_result = er_absF(nan_test.f);
        total_tests++;
        if (f32_is_nan(nan_result)) { passed_tests++; }
    }

    TEST("minF(1.0, 2.0)",    er_minF(1.0f, 2.0f),    1.0f);
    TEST("minF(2.0, 1.0)",    er_minF(2.0f, 1.0f),    1.0f);
    TEST("minF(-1.0, 1.0)",   er_minF(-1.0f, 1.0f),  -1.0f);
    TEST("minF(0.0, 0.0)",    er_minF(0.0f, 0.0f),    0.0f);
    TEST("minF(-0.0, 0.0)",   er_minF(-0.0f, 0.0f),  0.0f);
    {
        f32_bits neg_inf, pos_inf;
        neg_inf.u = 0xff800000;
        pos_inf.u = 0x7f800000;
        TEST("minF(-inf, inf)",   er_minF(neg_inf.f, pos_inf.f), neg_inf.f);
    }

    TEST("maxF(1.0, 2.0)",    er_maxF(1.0f, 2.0f),    2.0f);
    TEST("maxF(2.0, 1.0)",    er_maxF(2.0f, 1.0f),    2.0f);
    TEST("maxF(-1.0, 1.0)",   er_maxF(-1.0f, 1.0f),   1.0f);
    TEST("maxF(0.0, 0.0)",    er_maxF(0.0f, 0.0f),    0.0f);
    TEST("maxF(-0.0, 0.0)",   er_maxF(-0.0f, 0.0f),   0.0f);
    {
        f32_bits neg_inf, pos_inf;
        neg_inf.u = 0xff800000;
        pos_inf.u = 0x7f800000;
        TEST("maxF(-inf, inf)",   er_maxF(neg_inf.f, pos_inf.f), pos_inf.f);
    }

    TEST("clampF(0.5, 0.0, 1.0)",   er_clampF(0.5f, 0.0f, 1.0f),    0.5f);
    TEST("clampF(-1.0, 0.0, 1.0)",  er_clampF(-1.0f, 0.0f, 1.0f),   0.0f);
    TEST("clampF(2.0, 0.0, 1.0)",   er_clampF(2.0f, 0.0f, 1.0f),    1.0f);
    TEST("clampF(5.0, -1.0, 1.0)",  er_clampF(5.0f, -1.0f, 1.0f),   1.0f);
    TEST("clampF(-5.0, -1.0, 1.0)", er_clampF(-5.0f, -1.0f, 1.0f), -1.0f);

    TEST("clamp01F(0.5)",  er_clamp01F(0.5f),  0.5f);
    TEST("clamp01F(-1.0)", er_clamp01F(-1.0f), 0.0f);
    TEST("clamp01F(2.0)",  er_clamp01F(2.0f),  1.0f);
    TEST("clamp01F(0.0)",  er_clamp01F(0.0f),  0.0f);
    TEST("clamp01F(1.0)",  er_clamp01F(1.0f),  1.0f);

    TEST("sqrtF(0.0)",    er_sqrtF(0.0f),      0.0f);
    TEST("sqrtF(1.0)",    er_sqrtF(1.0f),      1.0f);
    TEST("sqrtF(4.0)",    er_sqrtF(4.0f),      2.0f);
    TEST("sqrtF(9.0)",    er_sqrtF(9.0f),      3.0f);
    TEST("sqrtF(2.0)",    er_sqrtF(2.0f),      1.41421356f);
    TEST("sqrtF(0.25)",   er_sqrtF(0.25f),     0.5f);
    TEST("sqrtF(-1.0)",   er_sqrtF(-1.0f),     0.0f);

    {
        // NR-SQRT seed constant matching math.asm
        #define NR_SQRT_SEED_BIAS 0x1fc00000
        float sqrt_nr_ref(float v) {
            if (v <= 0.0f) return 0.0f;
            uint32_t bits;
            f32_bits fb; fb.f = v; bits = fb.u;
            bits = (bits >> 1) + NR_SQRT_SEED_BIAS;
            fb.u = bits;
            float est = fb.f;
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
    }

    {
        #define RSQRT_MAGIC   0x5f3759df
        #define RSQRT_REFINE  1.5f
        float rsqrt_ref(float v) {
            if (v <= 0.0f) return 0.0f;
            float half = v * 0.5f;
            uint32_t bits;
            f32_bits fb; fb.f = v; bits = fb.u;
            bits = RSQRT_MAGIC - (bits >> 1);
            fb.u = bits;
            float est = fb.f;
            est = est * (RSQRT_REFINE - half * est * est);
            est = est * (RSQRT_REFINE - half * est * est);
            return est;
        }
        TEST("rsqrtF(0.0)",    er_rsqrtF(0.0f),     rsqrt_ref(0.0f));
        TEST("rsqrtF(1.0)",    er_rsqrtF(1.0f),     rsqrt_ref(1.0f));
        TEST("rsqrtF(4.0)",    er_rsqrtF(4.0f),     rsqrt_ref(4.0f));
        TEST("rsqrtF(0.25)",   er_rsqrtF(0.25f),    rsqrt_ref(0.25f));
        TEST("rsqrtF(-1.0)",   er_rsqrtF(-1.0f),    rsqrt_ref(-1.0f));
    }

    TEST("floorF(1.5)",    er_floorF(1.5f),      1.0f);
    TEST("floorF(-1.5)",   er_floorF(-1.5f),    -2.0f);
    TEST("floorF(0.0)",    er_floorF(0.0f),      0.0f);
    TEST("floorF(3.0)",    er_floorF(3.0f),      3.0f);
    TEST("floorF(-0.5)",   er_floorF(-0.5f),    -1.0f);
    TEST("floorF(-1.0)",   er_floorF(-1.0f),    -1.0f);

    TEST("ceilF(1.5)",     er_ceilF(1.5f),       2.0f);
    TEST("ceilF(-1.5)",    er_ceilF(-1.5f),     -1.0f);
    TEST("ceilF(0.0)",     er_ceilF(0.0f),       0.0f);
    TEST("ceilF(3.0)",     er_ceilF(3.0f),       3.0f);
    TEST("ceilF(-0.5)",    er_ceilF(-0.5f),      0.0f);
    TEST("ceilF(-1.0)",    er_ceilF(-1.0f),     -1.0f);

    {
        f32_bits inf_p, inf_n, nan_v;
        inf_p.u = 0x7f800000;
        inf_n.u = 0xff800000;
        nan_v.u = 0x7fc00000;
        TEST_I("isFiniteF(0.0)",       er_isFiniteF(0.0f),       1);
        TEST_I("isFiniteF(1.0)",       er_isFiniteF(1.0f),       1);
        TEST_I("isFiniteF(-1.0)",      er_isFiniteF(-1.0f),      1);
        TEST_I("isFiniteF(3.14)",      er_isFiniteF(3.14f),      1);
        TEST_I("isFiniteF(+inf)",  er_isFiniteF(inf_p.f),  0);
        TEST_I("isFiniteF(-inf)",  er_isFiniteF(inf_n.f),  0);
        TEST_I("isFiniteF(NaN)",   er_isFiniteF(nan_v.f),  0);
    }

    TEST_I("u8FromUnitF(0.0)",     er_u8FromUnitF(0.0f),     0);
    TEST_I("u8FromUnitF(1.0)",     er_u8FromUnitF(1.0f),     255);
    TEST_I("u8FromUnitF(0.5)",     er_u8FromUnitF(0.5f),     128);
    TEST_I("u8FromUnitF(0.0)",     er_u8FromUnitF(0.0f),     0);
    TEST_I("u8FromUnitF(-1.0)",    er_u8FromUnitF(-1.0f),    0);
    TEST_I("u8FromUnitF(2.0)",     er_u8FromUnitF(2.0f),     255);
    TEST_I("u8FromUnitF(0.003921568627451)", er_u8FromUnitF(0.003921568627451f), 1);

    TEST_I("abs_i32(0)",       er_abs_i32(0),        0);
    TEST_I("abs_i32(1)",       er_abs_i32(1),        1);
    TEST_I("abs_i32(-1)",      er_abs_i32(-1),       1);
    TEST_I("abs_i32(100)",     er_abs_i32(100),      100);
    TEST_I("abs_i32(-100)",    er_abs_i32(-100),     100);
    TEST_I("abs_i32(max)",     er_abs_i32(0x7fffffff), 0x7fffffff);
    TEST_I("abs_i32(min+1)",   er_abs_i32(-0x7fffffff), 0x7fffffff);

    #define TEST_I64(name, actual, expected) do { \
        total_tests++; \
        int64_t a_ = (actual), e_ = (expected); \
        if (a_ == e_) { passed_tests++; } \
    } while(0)
    TEST_I64("abs_i64(0)",       er_abs_i64(0),         0);
    TEST_I64("abs_i64(1)",       er_abs_i64(1),         1);
    TEST_I64("abs_i64(-1)",      er_abs_i64(-1),        1);
    TEST_I64("abs_i64(1<<62)",   er_abs_i64(1LL<<62),   1LL<<62);
    TEST_I64("abs_i64(-(1<<62))", er_abs_i64(-(1LL<<62)), 1LL<<62);

    TEST_I("clz32(0)",         er_clz32(0),           32);
    TEST_I("clz32(1)",         er_clz32(1),           31);
    TEST_I("clz32(2)",         er_clz32(2),           30);
    TEST_I("clz32(0x80000000)", er_clz32(0x80000000u), 0);
    TEST_I("clz32(0x00FF0000)", er_clz32(0x00FF0000u), 8);
    TEST_I("clz32(0x0FFFFFFF)", er_clz32(0x0FFFFFFFu), 4);

    TEST_I("clz64(0)",         er_clz64(0),           64);
    TEST_I("clz64(1)",         er_clz64(1),           63);
    TEST_I("clz64(1ULL<<63)",  er_clz64(1ULL<<63),    0);
    TEST_I("clz64(0x00FF000000000000)", er_clz64(0x00FF000000000000ULL), 8);

    TEST_I("ctz32(0)",         er_ctz32(0),           32);
    TEST_I("ctz32(1)",         er_ctz32(1),           0);
    TEST_I("ctz32(2)",         er_ctz32(2),           1);
    TEST_I("ctz32(0x80000000)", er_ctz32(0x80000000u), 31);
    TEST_I("ctz32(0x00FF0000)", er_ctz32(0x00FF0000u), 16);

    TEST_I("ctz64(0)",         er_ctz64(0),           64);
    TEST_I("ctz64(1)",         er_ctz64(1),           0);
    TEST_I("ctz64(2)",         er_ctz64(2),           1);
    TEST_I("ctz64(1ULL<<63)",  er_ctz64(1ULL<<63),    63);

    TEST_I("popcount32(0)",        er_popcount32(0),         0);
    TEST_I("popcount32(0xFFFFFFFF)", er_popcount32(0xFFFFFFFFu), 32);
    TEST_I("popcount32(0x55555555)", er_popcount32(0x55555555u), 16);
    TEST_I("popcount32(0xAAAAAAAA)", er_popcount32(0xAAAAAAAAu), 16);
    TEST_I("popcount32(0x00FF00FF)", er_popcount32(0x00FF00FFu), 16);

    TEST_I("popcount64(0)", er_popcount64(0), 0);
    TEST_I("popcount64(0xFFFFFFFFFFFFFFFF)", er_popcount64(0xFFFFFFFFFFFFFFFFULL), 64);
    TEST_I("popcount64(0x5555555555555555)", er_popcount64(0x5555555555555555ULL), 32);
    TEST_I("popcount64(1)", er_popcount64(1), 1);

    TEST_I64("umulhi(0, 0)",      er_umulhi(0, 0),       0);
    TEST_I64("umulhi(1, 1)",      er_umulhi(1, 1),       0);
    TEST_I64("umulhi(3, 5)",      er_umulhi(3, 5),       0);
    TEST_I64("umulhi(1<<32, 1)",  er_umulhi(1ULL<<32, 1), 0);
    TEST_I64("umulhi(1<<32, 1<<32)", er_umulhi(1ULL<<32, 1ULL<<32), 1);
    TEST_I64("umulhi(0xFFFFFFFF, 0xFFFFFFFF)", er_umulhi(0xFFFFFFFFu, 0xFFFFFFFFu), 0);

    TEST_I64("smulhi(0, 0)",      er_smulhi(0, 0),       0);
    TEST_I64("smulhi(1, 1)",      er_smulhi(1, 1),       0);
    TEST_I64("smulhi(-1, -1)",    er_smulhi(-1, -1),      0);
    TEST_I64("smulhi(1<<62, 2)",  er_smulhi(1LL<<62, 2), 0);
    TEST_I64("smulhi(-1, 2)",     er_smulhi(-1, 2), -1);
    TEST_I64("smulhi(-1, -1)",    er_smulhi(-1, -1), 0);
    TEST_I64("smulhi(3, 5)",      er_smulhi(3, 5),       0);

    TEST_I("div_u32(10, 3)",   er_div_u32(10, 3),   3);
    TEST_I("mod_u32(10, 3)",   er_mod_u32(10, 3),   1);
    TEST_I("div_u32(0, 5)",    er_div_u32(0, 5),    0);
    TEST_I("mod_u32(0, 5)",    er_mod_u32(0, 5),    0);
    TEST_I("div_u32(100,1)",   er_div_u32(100, 1),  100);
    TEST_I("mod_u32(100,1)",   er_mod_u32(100, 1),  0);
    TEST_I("div_u32(5, 0)",    er_div_u32(5, 0),    0);
    TEST_I("mod_u32(5, 0)",    er_mod_u32(5, 0),    0);

    TEST_I64("div_u64(10, 3)",     er_div_u64(10, 3),      3);
    TEST_I64("mod_u64(10, 3)",     er_mod_u64(10, 3),      1);
    TEST_I64("div_u64(1ULL<<63, 2)", er_div_u64(1ULL<<63, 2), 1ULL<<62);
    TEST_I64("mod_u64(1ULL<<63, 2)", er_mod_u64(1ULL<<63, 2), 0);
    TEST_I64("div_u64(5, 0)",      er_div_u64(5, 0),       0);
    TEST_I64("mod_u64(5, 0)",      er_mod_u64(5, 0),       0);

    {
        uint32_t q, r;
        er_divmod_u32(10, 3, &q, &r);
        TEST_I("divmod_u32 quot", q, 3);
        TEST_I("divmod_u32 rem",  r, 1);
        er_divmod_u32(0, 5, &q, &r);
        TEST_I("divmod_u32 zero quot", q, 0);
        TEST_I("divmod_u32 zero rem",  r, 0);
        er_divmod_u32(5, 0, &q, &r);
        TEST_I("divmod_u32 div0 quot", q, 0);
        TEST_I("divmod_u32 div0 rem",  r, 0);
    }
    {
        uint64_t q, r;
        er_divmod_u64(10, 3, &q, &r);
        TEST_I64("divmod_u64 quot", q, 3);
        TEST_I64("divmod_u64 rem",  r, 1);
        er_divmod_u64(1ULL<<63, 1ULL<<62, &q, &r);
        TEST_I64("divmod_u64 large quot", q, 2);
        TEST_I64("divmod_u64 large rem",  r, 0);
        er_divmod_u64(5, 0, &q, &r);
        TEST_I64("divmod_u64 div0 quot", q, 0);
        TEST_I64("divmod_u64 div0 rem",  r, 0);
    }
    {
        int32_t q, r;
        er_divmod_i32(10, 3, &q, &r);
        TEST_I("divmod_i32 quot", q, 3);
        TEST_I("divmod_i32 rem",  r, 1);
        er_divmod_i32(-10, 3, &q, &r);
        TEST_I("divmod_i32 neg quot", q, -3);
        TEST_I("divmod_i32 neg rem",  r, -1);
        er_divmod_i32(5, 0, &q, &r);
        TEST_I("divmod_i32 div0 quot", q, 0);
        TEST_I("divmod_i32 div0 rem",  r, 0);
    }

    TEST_I("is_pow2(0)",      er_is_power_of_two_u64(0),         0);
    TEST_I("is_pow2(1)",      er_is_power_of_two_u64(1),         1);
    TEST_I("is_pow2(2)",      er_is_power_of_two_u64(2),         1);
    TEST_I("is_pow2(3)",      er_is_power_of_two_u64(3),         0);
    TEST_I("is_pow2(1024)",   er_is_power_of_two_u64(1024),      1);
    TEST_I("is_pow2(1025)",   er_is_power_of_two_u64(1025),      0);
    TEST_I("is_pow2(1<<63)",  er_is_power_of_two_u64(1ULL<<63),  1);

    TEST_I64("align_down(15, 8)",  er_align_down_u64(15, 8),    8);
    TEST_I64("align_down(16, 8)",  er_align_down_u64(16, 8),    16);
    TEST_I64("align_down(0, 8)",   er_align_down_u64(0, 8),     0);
    TEST_I64("align_down(7, 8)",   er_align_down_u64(7, 8),     0);
    TEST_I64("align_down(15, 0)",  er_align_down_u64(15, 0),    15);

    TEST_I64("align_up(15, 8)",    er_align_up_u64(15, 8),      16);
    TEST_I64("align_up(16, 8)",    er_align_up_u64(16, 8),      16);
    TEST_I64("align_up(0, 8)",     er_align_up_u64(0, 8),       0);
    TEST_I64("align_up(1, 8)",     er_align_up_u64(1, 8),       8);
    TEST_I64("align_up(15, 0)",    er_align_up_u64(15, 0),      15);

    TEST_I64("min_u64(0,0)",     er_min_u64(0, 0),       0);
    TEST_I64("min_u64(1,2)",     er_min_u64(1, 2),       1);
    TEST_I64("min_u64(5,3)",     er_min_u64(5, 3),       3);
    TEST_I64("min_u64(max,0)",   er_min_u64(-1, 0),      0);

    TEST_I64("max_u64(0,0)",     er_max_u64(0, 0),       0);
    TEST_I64("max_u64(1,2)",     er_max_u64(1, 2),       2);
    TEST_I64("max_u64(5,3)",     er_max_u64(5, 3),       5);
    TEST_I64("max_u64(max,0)",   er_max_u64(-1, 0),      -1);

    TEST_I64("clamp_u64(5,0,10)",   er_clamp_u64(5, 0, 10),     5);
    TEST_I64("clamp_u64(20,0,10)",  er_clamp_u64(20, 0, 10),    10);
    TEST_I64("clamp_u64(5,10,20)",  er_clamp_u64(5, 10, 20),    10);
    TEST_I64("clamp_u64(15,10,20)", er_clamp_u64(15, 10, 20),   15);
    TEST_I64("clamp_u64(25,10,20)", er_clamp_u64(25, 10, 20),   20);
    TEST_I64("clamp_u64(5,20,10)",  er_clamp_u64(5, 20, 10),    5);

    TEST_I64("div_ceil(10,3)",   er_div_ceil_u64(10, 3),     4);
    TEST_I64("div_ceil(9,3)",    er_div_ceil_u64(9, 3),      3);
    TEST_I64("div_ceil(0,5)",    er_div_ceil_u64(0, 5),      0);
    TEST_I64("div_ceil(5,0)",    er_div_ceil_u64(5, 0),      0);
    TEST_I64("div_ceil(1,1)",    er_div_ceil_u64(1, 1),      1);
    TEST_I64("div_ceil(1,2)",    er_div_ceil_u64(1, 2),      1);
    TEST_I64("div_ceil(100,1)",  er_div_ceil_u64(100, 1),    100);

    TEST_I64("log2(0)",      er_log2_u64(0),         0);
    TEST_I64("log2(1)",      er_log2_u64(1),         0);
    TEST_I64("log2(2)",      er_log2_u64(2),         1);
    TEST_I64("log2(3)",      er_log2_u64(3),         1);
    TEST_I64("log2(4)",      er_log2_u64(4),         2);
    TEST_I64("log2(1024)",   er_log2_u64(1024),      10);
    TEST_I64("log2(1<<63)",  er_log2_u64(1ULL<<63),  63);

    TEST_I64("pow2(0)",      er_round_up_pow2_u64(0),        0);
    TEST_I64("pow2(1)",      er_round_up_pow2_u64(1),        1);
    TEST_I64("pow2(2)",      er_round_up_pow2_u64(2),        2);
    TEST_I64("pow2(3)",      er_round_up_pow2_u64(3),        4);
    TEST_I64("pow2(4)",      er_round_up_pow2_u64(4),        4);
    TEST_I64("pow2(5)",      er_round_up_pow2_u64(5),        8);
    TEST_I64("pow2(1023)",   er_round_up_pow2_u64(1023),     1024);
    TEST_I64("pow2(1024)",   er_round_up_pow2_u64(1024),     1024);
    TEST_I64("pow2(1<<62)",  er_round_up_pow2_u64(1ULL<<62), 1ULL<<62);
    TEST_I64("pow2(1<<63)",  er_round_up_pow2_u64(1ULL<<63), 1ULL<<63);
    TEST_I64("pow2(1<<63+1)", er_round_up_pow2_u64((1ULL<<63) + 1), 0);
    TEST_I64("pow2(max)",     er_round_up_pow2_u64(-1), 0);

    TEST_I("rotl32(1, 0)",       er_rotl32(1, 0),       1);
    TEST_I("rotl32(1, 1)",       er_rotl32(1, 1),       2);
    TEST_I("rotl32(1, 31)",      er_rotl32(1, 31),      0x80000000u);
    TEST_I("rotl32(1, 32)",      er_rotl32(1, 32),      1);
    TEST_I("rotr32(1, 1)",       er_rotr32(1, 1),       0x80000000u);
    TEST_I("rotr32(2, 1)",       er_rotr32(2, 1),       1);
    TEST_I("rotr32(0x80000000, 31)", er_rotr32(0x80000000u, 31), 1);

    TEST_I64("rotl64(1, 0)",     er_rotl64(1, 0),       1);
    TEST_I64("rotl64(1, 1)",     er_rotl64(1, 1),       2);
    TEST_I64("rotl64(1, 63)",    er_rotl64(1, 63),      1ULL<<63);
    TEST_I64("rotl64(1, 64)",    er_rotl64(1, 64),      1);
    TEST_I64("rotr64(1, 1)",     er_rotr64(1, 1),       1ULL<<63);
    TEST_I64("rotr64(2, 1)",     er_rotr64(2, 1),       1);

    TEST_I("bswap16(0x1234)",        er_bswap16(0x1234),           0x3412);
    TEST_I("bswap16(0x0001)",        er_bswap16(0x0001),           0x0100);
    TEST_I("bswap32(0x12345678)",    er_bswap32(0x12345678),       0x78563412u);
    TEST_I("bswap32(0x00000001)",    er_bswap32(0x00000001),       0x01000000u);
    TEST_I64("bswap64(0x0102030405060708)", er_bswap64(0x0102030405060708ULL), 0x0807060504030201ULL);
    TEST_I64("bswap64(0)",           er_bswap64(0),                0);
    TEST_I64("bswap64(0xFFFFFFFFFFFFFFFF)", er_bswap64(0xFFFFFFFFFFFFFFFFULL), 0xFFFFFFFFFFFFFFFFULL);

    {
        uint64_t state = 1;
        uint64_t r1 = er_xorshift64(&state);
        TEST_I("xorshift64 updates state", state != 1, 1);
        uint64_t state2 = 1;
        uint64_t r2 = er_xorshift64(&state2);
        TEST_I("xorshift64 deterministic", r1 == r2, 1);
        TEST_I("xorshift64 state matches", state == state2, 1);
        uint64_t state3 = 2;
        uint64_t r3 = er_xorshift64(&state3);
        TEST_I("xorshift64 different seed", r1 != r3, 1);
        TEST_I("xorshift64 non-zero", r1 != 0, 1);
    }

    TEST_I("min_u32(1,2)",       er_min_u32(1, 2), 1);
    TEST_I("min_u32(5,3)",       er_min_u32(5, 3), 3);
    TEST_I("max_u32(1,2)",       er_max_u32(1, 2), 2);
    TEST_I("max_u32(5,3)",       er_max_u32(5, 3), 5);
    TEST_I("clamp_u32(5,0,10)",  er_clamp_u32(5, 0, 10), 5);
    TEST_I("clamp_u32(20,0,10)", er_clamp_u32(20, 0, 10), 10);
    TEST_I("clamp_u32(5,10,20)", er_clamp_u32(5, 10, 20), 10);

    TEST_I("min_i32(1,2)",       er_min_i32(1, 2), 1);
    TEST_I("min_i32(-5,3)",      er_min_i32(-5, 3), -5);
    TEST_I("max_i32(1,2)",       er_max_i32(1, 2), 2);
    TEST_I("max_i32(-5,3)",      er_max_i32(-5, 3), 3);
    TEST_I("clamp_i32(5,0,10)",  er_clamp_i32(5, 0, 10), 5);
    TEST_I("clamp_i32(-5,0,10)", er_clamp_i32(-5, 0, 10), 0);
    TEST_I("clamp_i32(20,0,10)", er_clamp_i32(20, 0, 10), 10);

    {
        #define TEST_I64n(name, actual, expected) do { \
            total_tests++; \
            int64_t a_ = (actual), e_ = (expected); \
            if (a_ == e_) { passed_tests++; } \
        } while(0)
        TEST_I64n("min_i64(1,2)",      er_min_i64(1, 2), 1);
        TEST_I64n("min_i64(-5,3)",     er_min_i64(-5, 3), -5);
        TEST_I64n("max_i64(1,2)",      er_max_i64(1, 2), 2);
        TEST_I64n("max_i64(-5,3)",     er_max_i64(-5, 3), 3);
        TEST_I64n("clamp_i64(5,0,10)", er_clamp_i64(5, 0, 10), 5);
        TEST_I64n("clamp_i64(-5,0,10)", er_clamp_i64(-5, 0, 10), 0);
    }

    TEST_I("div_ceil32(10,3)",   er_div_ceil_u32(10, 3), 4);
    TEST_I("div_ceil32(9,3)",    er_div_ceil_u32(9, 3), 3);
    TEST_I("div_ceil32(0,5)",    er_div_ceil_u32(0, 5), 0);
    TEST_I("div_ceil32(5,0)",    er_div_ceil_u32(5, 0), 0);
    TEST_I("div_ceil32(1,2)",    er_div_ceil_u32(1, 2), 1);

    {
        TEST_I("crc32c empty",      er_crc32c(0, "", 0), 0);
        TEST_I("crc32c non-empty",  er_crc32c(0, "A", 1) != 0, 1);
        uint32_t c1 = er_crc32c(0, "AB", 2);
        uint32_t c2 = er_crc32c(er_crc32c(0, "A", 1), "B", 1);
        TEST_I("crc32c chain",      c1 == c2, 1);
        TEST_I("crc32c diff",       er_crc32c(0, "A", 1) != er_crc32c(0, "B", 1), 1);
        uint64_t align8 = 0x0102030405060708ULL;
        uint32_t crc8 = er_crc32c(0, &align8, 8);
        TEST_I("crc32c 8byte",      crc8 != 0, 1);
    }

    {
        TEST_I64("fnv1a empty",     er_fnv1a64("", 0),     0xcbf29ce484222325ULL);
        TEST_I64("fnv1a non-zero",  er_fnv1a64("a", 1),    0xaf63dc4c8601ec8cULL);
        TEST_I64("fnv1a b",         er_fnv1a64("b", 1),    0xaf63df4c8601f1a5ULL);
        TEST_I64("fnv1a foobar",    er_fnv1a64("foobar", 6), 0x85944171f73967e8ULL);
    }

#undef TEST_I64
    return (passed_tests == total_tests) ? 0 : 1;
}
