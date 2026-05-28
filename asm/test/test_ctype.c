// EdgeRun ctype assembly function test harness
// Freestanding — no libc.

extern int er_isdigit(int c);
extern int er_isalpha(int c);
extern int er_isalnum(int c);
extern int er_isspace(int c);
extern int er_isxdigit(int c);
extern int er_islower(int c);
extern int er_isupper(int c);
extern int er_tolower(int c);
extern int er_toupper(int c);

static int total_tests = 0;
static int passed_tests = 0;

#define TEST_I(actual, expected) do { \
    total_tests++; \
    if ((actual) == (expected)) { passed_tests++; } \
} while(0)

int main(void) {
    TEST_I(er_isdigit('0'), 1);
    TEST_I(er_isdigit('5'), 1);
    TEST_I(er_isdigit('9'), 1);
    TEST_I(er_isdigit('A'), 0);
    TEST_I(er_isdigit(' '), 0);
    TEST_I(er_isdigit(0),   0);

    TEST_I(er_isalpha('A'), 1);
    TEST_I(er_isalpha('Z'), 1);
    TEST_I(er_isalpha('a'), 1);
    TEST_I(er_isalpha('z'), 1);
    TEST_I(er_isalpha('0'), 0);
    TEST_I(er_isalpha('['), 0);

    TEST_I(er_isalnum('A'), 1);
    TEST_I(er_isalnum('z'), 1);
    TEST_I(er_isalnum('0'), 1);
    TEST_I(er_isalnum('9'), 1);
    TEST_I(er_isalnum(' '), 0);
    TEST_I(er_isalnum('@'), 0);

    TEST_I(er_isspace(' '),  1);
    TEST_I(er_isspace('\t'), 1);
    TEST_I(er_isspace('\n'), 1);
    TEST_I(er_isspace('\r'), 1);
    TEST_I(er_isspace('A'),  0);
    TEST_I(er_isspace('0'),  0);

    TEST_I(er_isxdigit('0'), 1);
    TEST_I(er_isxdigit('9'), 1);
    TEST_I(er_isxdigit('A'), 1);
    TEST_I(er_isxdigit('F'), 1);
    TEST_I(er_isxdigit('a'), 1);
    TEST_I(er_isxdigit('f'), 1);
    TEST_I(er_isxdigit('G'), 0);
    TEST_I(er_isxdigit(' '), 0);

    TEST_I(er_islower('a'), 1);
    TEST_I(er_islower('z'), 1);
    TEST_I(er_islower('A'), 0);
    TEST_I(er_islower('0'), 0);

    TEST_I(er_isupper('A'), 1);
    TEST_I(er_isupper('Z'), 1);
    TEST_I(er_isupper('a'), 0);
    TEST_I(er_isupper('0'), 0);

    TEST_I(er_tolower('A'), 'a');
    TEST_I(er_tolower('Z'), 'z');
    TEST_I(er_tolower('a'), 'a');
    TEST_I(er_tolower('0'), '0');
    TEST_I(er_tolower('['), '[');

    TEST_I(er_toupper('a'), 'A');
    TEST_I(er_toupper('z'), 'Z');
    TEST_I(er_toupper('A'), 'A');
    TEST_I(er_toupper('0'), '0');
    TEST_I(er_toupper('{'), '{');

    return (passed_tests == total_tests) ? 0 : 1;
}
