// EdgeRun serial driver test harness
// Uses HOSTED_TEST build: serial output goes to a global buffer.

#include <stdio.h>
#include <stdint.h>
#include <string.h>

// Hosted-test globals exposed by serial.asm
extern uint8_t  er_serial_tx_buffer[4096];
extern uint64_t er_serial_tx_count;

// Assembly functions under test
extern void er_serial_putchar(uint16_t port, unsigned char c);
extern void er_serial_puts(uint16_t port, const char* str);
extern void er_serial_puthex32(uint16_t port, uint32_t value);
extern void er_serial_puthex64(uint16_t port, uint64_t value);
extern void er_serial_putdec32(uint16_t port, uint32_t value);
extern void er_serial_crlf(uint16_t port);

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
    else { printf("  FAIL %s (line %d)\n", name, __LINE__); } \
} while(0)

#define TEST_STR(name, actual, expected) do { \
    total_tests++; \
    if (strcmp(actual, expected) == 0) { passed_tests++; } \
    else { printf("  FAIL %s (line %d): got \"%s\", expected \"%s\"\n", \
           name, __LINE__, actual, expected); } \
} while(0)

static void reset_buffer(void) {
    er_serial_tx_count = 0;
    memset(er_serial_tx_buffer, 0, sizeof(er_serial_tx_buffer));
}

int main(void) {
    printf("asm/serial test harness\n");
    printf("----------------------\n\n");

    // ---- er_serial_putchar ----------------------------------------
    printf("er_serial_putchar:\n");
    {
        reset_buffer();
        er_serial_putchar(0x3f8, 'H');
        er_serial_putchar(0x3f8, 'i');
        er_serial_putchar(0x3f8, '!');
        TEST_STR("putchar Hi!", er_serial_tx_buffer, "Hi!");
    }

    // ---- er_serial_puts -------------------------------------------
    printf("\ner_serial_puts:\n");
    {
        reset_buffer();
        er_serial_puts(0x3f8, "Hello, World!");
        TEST_STR("puts Hello World", er_serial_tx_buffer, "Hello, World!");

        reset_buffer();
        er_serial_puts(0x3f8, "");
        TEST("puts empty", er_serial_tx_count == 0);
    }

    // ---- er_serial_crlf -------------------------------------------
    printf("\ner_serial_crlf:\n");
    {
        reset_buffer();
        er_serial_crlf(0x3f8);
        TEST_STR("crlf", er_serial_tx_buffer, "\r\n");
    }

    // ---- er_serial_puthex32 ---------------------------------------
    printf("\ner_serial_puthex32:\n");
    {
        reset_buffer();
        er_serial_puthex32(0x3f8, 0x0);
        TEST_STR("hex32 zero", er_serial_tx_buffer, "0x00000000");

        reset_buffer();
        er_serial_puthex32(0x3f8, 0xdeadbeef);
        TEST_STR("hex32 deadbeef", er_serial_tx_buffer, "0xdeadbeef");

        reset_buffer();
        er_serial_puthex32(0x3f8, 0xffffffff);
        TEST_STR("hex32 all ones", er_serial_tx_buffer, "0xffffffff");

        reset_buffer();
        er_serial_puthex32(0x3f8, 0x12345678);
        TEST_STR("hex32 12345678", er_serial_tx_buffer, "0x12345678");
    }

    // ---- er_serial_puthex64 ---------------------------------------
    printf("\ner_serial_puthex64:\n");
    {
        reset_buffer();
        er_serial_puthex64(0x3f8, 0x0);
        TEST_STR("hex64 zero", er_serial_tx_buffer, "0x0000000000000000");

        reset_buffer();
        er_serial_puthex64(0x3f8, 0xdeadbeefcafebabeULL);
        TEST_STR("hex64 deadbeefcafebabe", er_serial_tx_buffer, "0xdeadbeefcafebabe");

        reset_buffer();
        er_serial_puthex64(0x3f8, 0xffffffffffffffffULL);
        TEST_STR("hex64 all ones", er_serial_tx_buffer, "0xffffffffffffffff");
    }

    // ---- er_serial_putdec32 ---------------------------------------
    printf("\ner_serial_putdec32:\n");
    {
        reset_buffer();
        er_serial_putdec32(0x3f8, 0);
        TEST_STR("dec32 zero", er_serial_tx_buffer, "0");

        reset_buffer();
        er_serial_putdec32(0x3f8, 1);
        TEST_STR("dec32 one", er_serial_tx_buffer, "1");

        reset_buffer();
        er_serial_putdec32(0x3f8, 42);
        TEST_STR("dec32 42", er_serial_tx_buffer, "42");

        reset_buffer();
        er_serial_putdec32(0x3f8, 1234567890);
        TEST_STR("dec32 1234567890", er_serial_tx_buffer, "1234567890");

        reset_buffer();
        er_serial_putdec32(0x3f8, 4294967295U);
        TEST_STR("dec32 max uint32", er_serial_tx_buffer, "4294967295");
    }

    printf("\n----------------------\n");
    printf("%d / %d tests passed\n", passed_tests, total_tests);
    return (passed_tests == total_tests) ? 0 : 1;
}
