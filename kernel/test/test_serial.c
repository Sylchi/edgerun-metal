// EdgeRun serial driver test harness
// Uses HOSTED_TEST build: serial output goes to a global buffer.
// Freestanding — no libc.

typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef unsigned long      size_t;

extern void* er_memset(void* dst, int value, size_t num);
extern int   er_strcmp(const char* str1, const char* str2);
extern size_t er_strlen(const char* str);

extern uint8_t  er_serial_tx_buffer[4096];
extern uint64_t er_serial_tx_count;

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
} while(0)

#define TEST_STR(name, actual, expected) do { \
    total_tests++; \
    if (er_strcmp((const char*)(actual), expected) == 0) { passed_tests++; } \
} while(0)

static void reset_buffer(void) {
    er_serial_tx_count = 0;
    er_memset(er_serial_tx_buffer, 0, sizeof(er_serial_tx_buffer));
}

int main(void) {
    reset_buffer();
    er_serial_putchar(0x3f8, 'H');
    er_serial_putchar(0x3f8, 'i');
    er_serial_putchar(0x3f8, '!');
    TEST_STR("putchar Hi!", er_serial_tx_buffer, "Hi!");

    reset_buffer();
    er_serial_puts(0x3f8, "Hello, World!");
    TEST_STR("puts Hello World", er_serial_tx_buffer, "Hello, World!");

    reset_buffer();
    er_serial_puts(0x3f8, "");
    TEST("puts empty", er_serial_tx_count == 0);

    reset_buffer();
    er_serial_crlf(0x3f8);
    TEST_STR("crlf", er_serial_tx_buffer, "\r\n");

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

    reset_buffer();
    er_serial_puthex64(0x3f8, 0x0);
    TEST_STR("hex64 zero", er_serial_tx_buffer, "0x0000000000000000");

    reset_buffer();
    er_serial_puthex64(0x3f8, 0xdeadbeefcafebabeULL);
    TEST_STR("hex64 deadbeefcafebabe", er_serial_tx_buffer, "0xdeadbeefcafebabe");

    reset_buffer();
    er_serial_puthex64(0x3f8, 0xffffffffffffffffULL);
    TEST_STR("hex64 all ones", er_serial_tx_buffer, "0xffffffffffffffff");

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

    return (passed_tests == total_tests) ? 0 : 1;
}
