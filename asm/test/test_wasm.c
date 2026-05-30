// EdgeRun WASM interpreter test harness
// Freestanding — no libc.
// Tests basic module execution + host import dispatch.
typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long      uint64_t;
typedef uint64_t           size_t;

// Runtime struct matching wasm_interpreter.asm RuntimeConfig layout
typedef struct {
    void*  memory_ptr;           // offset 0
    uint64_t memory_len;         // offset 8
    void*  execution_ticks_ptr;  // offset 16
    void*  memory_grow_fn;       // offset 24
    void*  memory_grow_ctx;      // offset 32
    void*  table_grow_fn;        // offset 40
    void*  table_grow_ctx;       // offset 48
    uint64_t initial_pages;      // offset 56
    uint8_t has_initial_pages;   // offset 64
    uint8_t _pad[7];             // offset 65-71
    void*  imports_ptr;          // offset 72
    uint64_t imports_len;        // offset 80
} runtime_t;

// HostImport struct matching wasm_defines.inc
typedef struct {
    const char* module_ptr;   // offset 0
    uint64_t    module_len;   // offset 8
    const char* name_ptr;     // offset 16
    uint64_t    name_len;     // offset 24
    uint64_t    fn_ptr;       // offset 32
} host_import_t;

// WASM interpreter entry point
extern uint64_t er_fn_run(runtime_t* runtime, const uint8_t* wasm_bytes, size_t wasm_len, const char* export_name, size_t export_name_len);

// Test 1: Minimal module — (module (func (export "f") (result i32) i32.const 42))
static const uint8_t wasm_simple[] = {
    0x00, 0x61, 0x73, 0x6d,  // magic \0asm
    0x01, 0x00, 0x00, 0x00,  // version 1
    // Type section (id=1)
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
    // Function section (id=3)
    0x03, 0x02, 0x01, 0x00,
    // Export section (id=7)
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
    // Code section (id=10)
    0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
};

// Test 2: Import module with no calls — import declared, function returns 42
// Type 0: () -> i32
static const uint8_t wasm_import_nocall[] = {
    0x00, 0x61, 0x73, 0x6d,
    0x01, 0x00, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
    0x02, 0x10, 0x01,
    0x04, 0x68, 0x6f, 0x73, 0x74,
    0x07, 0x70, 0x75, 0x74, 0x63, 0x68, 0x61, 0x72,
    0x00, 0x00,
    0x03, 0x02, 0x01, 0x00,
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x01,
    0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
};

// Test 3: Import module with calls — calls host.putchar('H'), host.putchar('\n'), returns 42
// Type 0: (i32) -> (i32) for import
// Type 1: () -> i32 for exported function
static const uint8_t wasm_import_called[] = {
    0x00, 0x61, 0x73, 0x6d,
    0x01, 0x00, 0x00, 0x00,
    0x01, 0x0a, 0x02,
    0x60, 0x01, 0x7f, 0x01, 0x7f,
    0x60, 0x00, 0x01, 0x7f,
    0x02, 0x10, 0x01,
    0x04, 0x68, 0x6f, 0x73, 0x74,
    0x07, 0x70, 0x75, 0x74, 0x63, 0x68, 0x61, 0x72,
    0x00, 0x00,
    0x03, 0x02, 0x01, 0x01,
    0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x01,
    0x0a, 0x10, 0x01, 0x0e, 0x00,
    0x41, 0x48, 0x10, 0x00, 0x1a,
    0x41, 0x0a, 0x10, 0x00, 0x1a,
    0x41, 0x2a, 0x0b,
};

// Test 4: f32.const 42.0 -> f32
static const uint8_t wasm_f32_const[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7d, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x09, 0x01, 0x07, 0x00, 0x43, 0x00, 0x00, 0x28, 0x42,
    0x0b,
};

// Test 5: f64.const 42.0 -> f64
static const uint8_t wasm_f64_const[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7c, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x0d, 0x01, 0x0b, 0x00, 0x44, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x45, 0x40, 0x0b,
};

// Test 6: f32.add (1.0 + 2.0) -> f32
static const uint8_t wasm_f32_add[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7d, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x43, 0x00, 0x00, 0x80, 0x3f,
    0x43, 0x00, 0x00, 0x00, 0x40, 0x92, 0x0b,
};

// Test 7: f32.eq (1.0 == 1.0) -> i32
static const uint8_t wasm_f32_eq[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x43, 0x00, 0x00, 0x80, 0x3f,
    0x43, 0x00, 0x00, 0x80, 0x3f, 0x5b, 0x0b,
};

// Test 8: f64.add (3.0 + 7.0) -> f64
static const uint8_t wasm_f64_add[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7c, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x17, 0x01, 0x15, 0x00, 0x44, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0x40, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1c,
    0x40, 0xa0, 0x0b,
};

// Test 9: f32.ne (1.0 != 2.0) -> i32 (true)
static const uint8_t wasm_f32_ne[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x43, 0x00, 0x00, 0x80, 0x3f,
    0x43, 0x00, 0x00, 0x00, 0x40, 0x5c, 0x0b,
};

// Test 10: f32.convert_i32_s (42) -> f32
// Debug: i32.const 42 in function typed as () -> f32
static const uint8_t wasm_i32_in_f32[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7d, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x06, 0x01, 0x04, 0x00, 0x41, 0x2a, 0x0b,
};

static const uint8_t wasm_f32_convert[] = {
    0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x05, 0x01, 0x60,
    0x00, 0x01, 0x7d, 0x03, 0x02, 0x01, 0x00, 0x07, 0x05, 0x01, 0x01, 0x66,
    0x00, 0x00, 0x0a, 0x07, 0x01, 0x05, 0x00, 0x41, 0x2a, 0xb2, 0x0b,
};

#define WASM_PAGE_SIZE 65536ULL
#define INITIAL_MEMORY_PAGES 1

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
} while(0)

// Host putchar implementation — writes to a test buffer
static char putchar_buf[64];
static int putchar_len = 0;

static uint64_t test_putchar(uint64_t c) {
    if (putchar_len < 63) {
        putchar_buf[putchar_len++] = (char)c;
        putchar_buf[putchar_len] = '\0';
    }
    return 1;
}

int main(void) {
    static uint8_t wasm_memory[WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES];
    static uint64_t execution_ticks = 0;

    static host_import_t host_imports[] = {
        { "host", 4, "putchar", 7, (uint64_t)test_putchar },
    };

    // ================================================================
    // Test 1: Simple module — no imports, returns 42
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_simple, sizeof(wasm_simple), "f", 1);
        TEST("simple module returns 42", result == 42);
    }

    // ================================================================
    // Test 2: Import module with no calls
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = (void*)host_imports;
        runtime.imports_len = 1;

        uint64_t result = er_fn_run(&runtime, wasm_import_nocall, sizeof(wasm_import_nocall), "f", 1);
        TEST("import-nocall module returns 42", result == 42);
    }

    // ================================================================
    // Test 3: Import module with calls
    // ================================================================
    {
        putchar_len = 0;
        putchar_buf[0] = '\0';

        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = (void*)host_imports;
        runtime.imports_len = 1;

        uint64_t result = er_fn_run(&runtime, wasm_import_called, sizeof(wasm_import_called), "f", 1);
        TEST("import-called module returns 42", result == 42);
        TEST("import putchar wrote 'H'", putchar_len >= 1 && putchar_buf[0] == 'H');
        TEST("import putchar wrote newline", putchar_len >= 2 && putchar_buf[1] == '\n');
    }

    // ================================================================
    // Test 4: i32.const 42 in f32-typed function (f32 return type path)
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_i32_in_f32, sizeof(wasm_i32_in_f32), "f", 1);
        TEST("i32.const 42 in f32-type func returns 42", result == 42);
    }

    // ================================================================
    // Test 5: f32.const 42.0
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f32_const, sizeof(wasm_f32_const), "f", 1);
        uint32_t bits = (uint32_t)result;
        TEST("f32.const 42.0 returns correct bits", bits == 0x42280000);
    }

    // ================================================================
    // Test 6: f64.const 3.0 (64-bit float)
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f64_const, sizeof(wasm_f64_const), "f", 1);
        TEST("f64.const 42.0 returns correct bits", result == 0x4045000000000000ULL);
    }

    // ================================================================
    // Test 7: f32.add (1.0 + 2.0 = 3.0)
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f32_add, sizeof(wasm_f32_add), "f", 1);
        uint32_t bits = (uint32_t)result;
        TEST("f32.add 1+2=3 returns correct bits", bits == 0x40400000);
    }

    // ================================================================
    // Test 8: f32.eq (1.0 == 1.0) -> i32 1
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f32_eq, sizeof(wasm_f32_eq), "f", 1);
        TEST("f32.eq 1.0==1.0 returns 1", result == 1);
    }

    // ================================================================
    // Test 9: f64.add (3.0 + 7.0 = 10.0)
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f64_add, sizeof(wasm_f64_add), "f", 1);
        TEST("f64.add 3+7=10 returns correct bits", result == 0x4024000000000000ULL);
    }

    // ================================================================
    // Test 10: f32.ne (1.0 != 2.0) -> i32 1
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f32_ne, sizeof(wasm_f32_ne), "f", 1);
        TEST("f32.ne 1.0!=2.0 returns 1", result == 1);
    }

    // ================================================================
    // Test 11: f32.convert_i32_s (42) -> 42.0f
    // ================================================================
    {
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0;
        runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0;
        runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES;
        runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0;
        runtime.imports_len = 0;

        uint64_t result = er_fn_run(&runtime, wasm_f32_convert, sizeof(wasm_f32_convert), "f", 1);
        uint32_t bits = (uint32_t)result;
        TEST("f32.convert_i32_s 42 returns 42.0f", bits == 0x42280000);
    }

    // ================================================================
    // Test 12: i32.trunc_sat_f32_s (f32 1.0 → 1)
    // ================================================================
    {
        // (module (func (export "f") (result i32) f32.const 1.0 i32.trunc_sat_f32_s))
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0b, 0x01, 0x09, 0x00, 0x43, 0x00, 0x00, 0x80, 0x3f, 0xfc, 0x00, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f32_s 1.0 -> 1", result == 1);
    }

    // ================================================================
    // Test 13: i32.trunc_sat_f32_s (f32 NaN → 0)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0b, 0x01, 0x09, 0x00, 0x43, 0x00, 0x00, 0xc0, 0x7f, 0xfc, 0x00, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f32_s NaN -> 0", result == 0);
    }

    // ================================================================
    // Test 14: i32.trunc_sat_f32_u (f32 0.0 → 0)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0b, 0x01, 0x09, 0x00, 0x43, 0x00, 0x00, 0x00, 0x00, 0xfc, 0x01, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f32_u 0.0 -> 0", result == 0);
    }

    // ================================================================
    // Test 15: i32.trunc_sat_f32_u (f32 2^32 → UINT32_MAX)
    // ================================================================
    {
        // 2^32 as f32 = 0x4F800000
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0b, 0x01, 0x09, 0x00, 0x43, 0x00, 0x00, 0x80, 0x4f, 0xfc, 0x01, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f32_u 2^32 -> UINT32_MAX", result == 0xffffffffULL);
    }

    // ================================================================
    // Test 16: i32.trunc_sat_f64_s (f64 42.0 → 42)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x40, 0xfc, 0x02, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f64_s 42.0 -> 42", result == 42);
    }

    // ================================================================
    // Test 17: i64.trunc_sat_f64_s (f64 NaN → 0)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf8, 0x7f, 0xfc, 0x06, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f64_s NaN -> 0", result == 0);
    }

    // ================================================================
    // Test 18: i64.trunc_sat_f64_s (f64 -1.0 → -1)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0f, 0x01, 0x0d, 0x00, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf0, 0xbf, 0xfc, 0x06, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f64_s -1.0 -> -1", result == 0xffffffffffffffffULL);
    }

    // ================================================================
    // Test 19: i32.trunc_sat_f32_s (f32 -1.0 → -1)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0b, 0x01, 0x09, 0x00, 0x43, 0x00, 0x00, 0x80, 0xbf, 0xfc, 0x00, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f32_s -1.0 -> -1", result == 0xffffffffffffffffULL);
    }

    // ================================================================
    // Test 20: i32.trunc_sat_f32_u (f32 -1.0 → 0, negative saturates to 0)
    // ================================================================
    {
        static const uint8_t mod[] = {
            0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
            0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7f,
            0x03, 0x02, 0x01, 0x00,
            0x07, 0x05, 0x01, 0x01, 0x66, 0x00, 0x00,
            0x0a, 0x0b, 0x01, 0x09, 0x00, 0x43, 0x00, 0x00, 0x80, 0xbf, 0xfc, 0x01, 0x0b,
        };
        runtime_t runtime;
        runtime.memory_ptr = wasm_memory;
        runtime.memory_len = WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES;
        runtime.execution_ticks_ptr = &execution_ticks;
        runtime.memory_grow_fn = 0; runtime.memory_grow_ctx = 0;
        runtime.table_grow_fn = 0; runtime.table_grow_ctx = 0;
        runtime.initial_pages = INITIAL_MEMORY_PAGES; runtime.has_initial_pages = 1;
        runtime.imports_ptr = 0; runtime.imports_len = 0;
        uint64_t result = er_fn_run(&runtime, mod, sizeof(mod), "f", 1);
        TEST("trunc_sat_f32_u -1.0 -> 0", result == 0);
    }

    return (passed_tests == total_tests) ? 0 : 1;
}
