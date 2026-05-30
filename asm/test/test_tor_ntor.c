// EdgeRun ntor / field arithmetic host-side test
// Links against tor_ntor.o (elf64) to test _fe_mul.

#include <stdint.h>
#include <stdio.h>

typedef uint64_t u64;

extern void _fe_mul(u64 *dst, const u64 *a, const u64 *b);

static void print_fe(const char *label, const u64 *fe) {
    printf("%s = [0x%016lx, 0x%016lx, 0x%016lx, 0x%016lx]\n",
           label, fe[0], fe[1], fe[2], fe[3]);
}

static int fe_eq(const u64 *a, const u64 *b) {
    return a[0]==b[0] && a[1]==b[1] && a[2]==b[2] && a[3]==b[3];
}

static int test_count, pass_count;
#define TEST(fn) do { test_count++; if (fn) pass_count++; \
    else printf("  FAIL: %s\n", #fn); } while(0)

int main(void) {
    u64 nine[4] = {9, 0, 0, 0};
    u64 one[4] = {1, 0, 0, 0};
    u64 result[4], expected[4];

    _fe_mul(result, nine, one);
    print_fe("  9*1", result);
    TEST(fe_eq(result, nine));

    u64 e81[4] = {81, 0, 0, 0};
    _fe_mul(result, nine, nine);
    print_fe("  9*9", result);
    TEST(fe_eq(result, e81));

    u64 pm1[4] = {0xFFFFFFFFFFFFFFEC, 0xFFFFFFFFFFFFFFFF,
                  0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF};
    u64 pm9[4] = {0xFFFFFFFFFFFFFFE4, 0xFFFFFFFFFFFFFFFF,
                  0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF};
    _fe_mul(result, nine, pm1);
    print_fe("  9*(p-1)", result);
    TEST(fe_eq(result, pm9));

    u64 pp18[4] = {0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF,
                   0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF};
    _fe_mul(result, pp18, pp18);
    expected[0] = 324; expected[1] = 0; expected[2] = 0; expected[3] = 0;
    print_fe("  (p+18)^2 mod p", result);
    TEST(fe_eq(result, expected));

    u64 inv9c[4] = {0xc71c71c71c71c712, 0x1c71c71c71c71c71,
                    0x71c71c71c71c71c7, 0x471c71c71c71c71c};
    _fe_mul(result, nine, inv9c);
    print_fe("  9 * correct_inv(9)", result);
    expected[0] = 1; expected[1] = 0; expected[2] = 0; expected[3] = 0;
    TEST(fe_eq(result, expected));

    u64 high[4] = {0, 0, 0, 1};
    _fe_mul(result, nine, high);
    print_fe("  9 * 2^192", result);
    expected[0] = 0; expected[1] = 0; expected[2] = 0; expected[3] = 9;
    TEST(fe_eq(result, expected));

    u64 inv9b[4] = {0xc71c71c71c71c6ff, 0x1c71c71c71c71c71,
                    0x71c71c71c71c71c7, 0xc71c71c71c71c71c};
    _fe_mul(result, nine, inv9b);
    print_fe("  9 * buggy_inv(9)", result);
    expected[0] = 1; expected[1] = 0; expected[2] = 0; expected[3] = 0;
    TEST(fe_eq(result, expected));

    printf("\n%d / %d tests passed\n", pass_count, test_count);
    return (pass_count == test_count) ? 0 : 1;
}
