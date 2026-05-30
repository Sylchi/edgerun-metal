// EdgeRun WASM Compiler test harness
// Freestanding — no libc.
typedef unsigned char      uint8_t;
typedef unsigned long      uint64_t;
typedef long               int64_t;
typedef unsigned int       uint32_t;
typedef int                int32_t;
typedef uint64_t           size_t;

// Compiler C ABI
extern uint32_t er_wasm_compiler_abi_version(void);
extern uint32_t er_wasm_compiler_init(void* mem, uint64_t mem_len);
extern uint32_t er_wasm_compiler_status(void);
extern void*    er_wasm_compiler_output_ptr(void);
extern uint64_t er_wasm_compiler_output_len(void);
extern const char* er_wasm_compiler_diagnostic_ptr(void);
extern uint32_t er_wasm_compiler_diagnostic_len(void);
extern uint32_t er_wasm_compiler_compile_wasm(
    void* compiler_mem, uint64_t compiler_mem_len,
    const char* source_name, uint64_t source_name_len,
    const uint8_t* source, uint64_t source_len);

// WASM constants
#define WASM_MAGIC0 0x00
#define WASM_MAGIC1 0x61
#define WASM_MAGIC2 0x73
#define WASM_MAGIC3 0x6d
#define WASM_SECTION_TYPE     1
#define WASM_SECTION_FUNCTION 3
#define WASM_SECTION_MEMORY   5
#define WASM_SECTION_EXPORT   7
#define WASM_SECTION_START    8
#define WASM_SECTION_CODE     10

static int total_tests = 0;
static int passed_tests = 0;

static int _failing_test = -1;
#define TEST(name, expr) do { \
    total_tests++; \
    int _ok = (expr); \
    if (_ok) { passed_tests++; } \
    else { _failing_test = total_tests; return 100 + total_tests; } \
} while(0)

static int wasm_read_leb128(const uint8_t* data, uint64_t* value) {
    *value = 0;
    int shift = 0;
    int bytes = 0;
    while (bytes < 5) {
        uint8_t b = data[bytes];
        *value |= (uint64_t)(b & 0x7f) << shift;
        shift += 7;
        bytes++;
        if (!(b & 0x80)) return bytes;
    }
    return bytes;
}

// Validate WASM binary structure
// Returns 0 on success, -1 on failure
// Count exports in the export section
// Returns export count on success, -1 on error
static int wasm_export_count(const uint8_t* wasm, uint64_t wasm_len) {
    uint64_t pos = 8;
    while (pos < wasm_len) {
        if (pos + 1 > wasm_len) return -1;
        uint8_t sid = wasm[pos++];
        if (pos + 5 > wasm_len) return -1;
        uint64_t slen;
        int leb = wasm_read_leb128(wasm + pos, &slen);
        pos += leb;
        if (pos + slen > wasm_len) return -1;
        if (sid == 7) {
            // Export section: first value is count
            if (pos + 5 > wasm_len) return -1;
            uint64_t count;
            wasm_read_leb128(wasm + pos, &count);
            return (int)count;
        }
        pos += slen;
    }
    return -1;
}

// Find export name in export section
// Returns 1 if found, 0 if not found, -1 on error
static int wasm_has_export(const uint8_t* wasm, uint64_t wasm_len,
                            const char* name, uint64_t name_len) {
    uint64_t pos = 8;
    while (pos < wasm_len) {
        if (pos + 1 > wasm_len) return -1;
        uint8_t sid = wasm[pos++];
        if (pos + 5 > wasm_len) return -1;
        uint64_t slen;
        int leb = wasm_read_leb128(wasm + pos, &slen);
        pos += leb;
        if (pos + slen > wasm_len) return -1;
        if (sid == 7) {
            uint64_t pos_end = pos + slen;
            uint64_t count;
            pos += wasm_read_leb128(wasm + pos, &count);
            while (count > 0 && pos < pos_end) {
                uint64_t ename_len_val;
                int elen = wasm_read_leb128(wasm + pos, &ename_len_val);
                uint64_t ename_len = ename_len_val;
                pos += elen;
                if (pos + ename_len + 1 + 1 > pos_end) return -1;
                if (ename_len == name_len) {
                    int match = 1;
                    for (uint64_t i = 0; i < name_len; i++) {
                        if (wasm[pos + i] != (uint8_t)name[i]) { match = 0; break; }
                    }
                    if (match) return 1;
                }
                pos += ename_len;
                pos += 1;             // skip kind
                pos += wasm_read_leb128(wasm + pos, &ename_len_val); // skip index
                count--;
            }
            return 0;
        }
        pos += slen;
    }
    return -1;
}

static int validate_wasm(const uint8_t* wasm, uint64_t wasm_len) {
    if (wasm_len < 8) return -1;
    if (wasm[0] != WASM_MAGIC0 || wasm[1] != WASM_MAGIC1 ||
        wasm[2] != WASM_MAGIC2 || wasm[3] != WASM_MAGIC3) return -1;
    if (wasm[4] != 1 || wasm[5] != 0 || wasm[6] != 0 || wasm[7] != 0) return -1;

    uint64_t pos = 8;
    int seen_type = 0, seen_func = 0, seen_mem = 0;
    int seen_export = 0, seen_start = 0, seen_code = 0;

    while (pos < wasm_len) {
        if (pos + 1 > wasm_len) return -1;
        uint8_t section_id = wasm[pos++];
        if (pos + 5 > wasm_len) return -1;
        uint64_t section_len;
        int leb = wasm_read_leb128(wasm + pos, &section_len);
        pos += leb;
        if (pos + section_len > wasm_len) return -1;

        switch (section_id) {
        case WASM_SECTION_TYPE:     seen_type = 1; break;
        case WASM_SECTION_FUNCTION: seen_func = 1; break;
        case WASM_SECTION_MEMORY:   seen_mem = 1; break;
        case WASM_SECTION_EXPORT:   seen_export = 1; break;
        case WASM_SECTION_START:    seen_start = 1; break;
        case WASM_SECTION_CODE:     seen_code = 1; break;
        }
        pos += section_len;
    }

    if (!seen_type) return -1;
    if (!seen_func) return -1;
    if (!seen_mem) return -1;
    if (!seen_export) return -1;
    if (!seen_start) return -1;
    if (!seen_code) return -1;
    return 0;
}

// Simple EdgeRun source to compile
static const char test_source[] =
    "export fn main() u32 {\n"
    "    return 42;\n"
    "}\n";

// EdgeRun source with multiple exports
static const char multi_export_source[] =
    "const x: u32 = 10;\n"
    "export fn main() u32 {\n"
    "    return x;\n"
    "}\n"
    "export fn helper() u32 {\n"
    "    return 0;\n"
    "}\n";

// EdgeRun source with binary expression
static const char expr_source[] =
    "export fn double(x: u32) u32 {\n"
    "    return x * 2;\n"
    "}\n";

// EdgeRun source with add expression
static const char add_source[] =
    "export fn add(a: u32, b: u32) u32 {\n"
    "    return a + b;\n"
    "}\n";

// EdgeRun source with complex expression
static const char complex_expr_source[] =
    "export fn compute(x: u32) u32 {\n"
    "    return x * 3 + 1;\n"
    "}\n";

// EdgeRun source with function call
static const char call_source[] =
    "export fn double(x: u32) u32 {\n"
    "    return x * 2;\n"
    "}\n"
    "export fn main() u32 {\n"
    "    return double(21);\n"
    "}\n";

int main(void) {
    enum { COMPILER_MEM_SIZE = 1024 * 1024 };
    static uint8_t compiler_mem[COMPILER_MEM_SIZE]
        __attribute__((aligned(16)));

    // Test 1: ABI version
    {
        uint32_t ver = er_wasm_compiler_abi_version();
        TEST("ABI version", ver == 1);
    }

    // Test 2: Compile trivial source
    {
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)test_source, sizeof(test_source) - 1);

        uint32_t status = er_wasm_compiler_status();
        TEST("compile_wasm returns ok", result == 0 && status == 0);

        void* out_ptr = er_wasm_compiler_output_ptr();
        uint64_t out_len = er_wasm_compiler_output_len();
        TEST("output ptr non-null", out_ptr != 0);
        TEST("output len > 0", out_len > 8);

        int valid = validate_wasm((const uint8_t*)out_ptr, out_len);
        TEST("valid WASM binary", valid == 0);

        int ec = wasm_export_count((const uint8_t*)out_ptr, out_len);
        TEST("export count = 29 (28 base + 1 user)", ec == 29);

        int has_main = wasm_has_export((const uint8_t*)out_ptr, out_len,
                                       "main", 4);
        TEST("user export 'main' present", has_main == 1);
    }

    // Test 3: Compile with multiple exports
    {
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)multi_export_source,
            sizeof(multi_export_source) - 1);

        uint32_t status = er_wasm_compiler_status();
        TEST("multi-export compile ok", result == 0 && status == 0);

        void* out_ptr = er_wasm_compiler_output_ptr();
        uint64_t out_len = er_wasm_compiler_output_len();
        int valid = validate_wasm((const uint8_t*)out_ptr, out_len);
        TEST("multi-export valid WASM", valid == 0);

        int ec = wasm_export_count((const uint8_t*)out_ptr, out_len);
        TEST("multi-export count = 30 (28 base + 2 user)", ec == 30);

        int has_main = wasm_has_export((const uint8_t*)out_ptr, out_len,
                                       "main", 4);
        TEST("multi-export 'main' present", has_main == 1);

        int has_helper = wasm_has_export((const uint8_t*)out_ptr, out_len,
                                         "helper", 6);
        TEST("multi-export 'helper' present", has_helper == 1);
    }

    // Test 4: Empty source should fail
    {
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)"", 0);
        TEST("empty source fails", result != 0);
    }

    // Test 5: Compile with no exports should fail (source_parse requires exports)
    {
        const char no_export_src[] = "const x: u32 = 10;\n";
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)no_export_src,
            sizeof(no_export_src) - 1);
        TEST("no exports fails", result != 0);
    }

    // Test 6: Compile source with binary expression (double(x) = x * 2)
    {
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)expr_source, sizeof(expr_source) - 1);

        uint32_t status = er_wasm_compiler_status();
        TEST("expr_source compile ok", result == 0 && status == 0);

        void* out_ptr = er_wasm_compiler_output_ptr();
        uint64_t out_len = er_wasm_compiler_output_len();
        int valid = validate_wasm((const uint8_t*)out_ptr, out_len);
        TEST("expr_source valid WASM", valid == 0);

        int ec = wasm_export_count((const uint8_t*)out_ptr, out_len);
        TEST("expr_source export count = 29 (base + 1 user)", ec == 29);

        int has_double = wasm_has_export((const uint8_t*)out_ptr, out_len,
                                        "double", 6);
        TEST("expr_source export 'double' present", has_double == 1);
    }

    // Test 7: Compile source with add expression (add(a,b) = a + b)
    {
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)add_source, sizeof(add_source) - 1);

        uint32_t status = er_wasm_compiler_status();
        TEST("add_source compile ok", result == 0 && status == 0);

        void* out_ptr = er_wasm_compiler_output_ptr();
        uint64_t out_len = er_wasm_compiler_output_len();
        int valid = validate_wasm((const uint8_t*)out_ptr, out_len);
        TEST("add_source valid WASM", valid == 0);

        int ec = wasm_export_count((const uint8_t*)out_ptr, out_len);
        TEST("add_source export count = 29 (base + 1 user)", ec == 29);

        int has_add = wasm_has_export((const uint8_t*)out_ptr, out_len,
                                     "add", 3);
        TEST("add_source export 'add' present", has_add == 1);
    }

    // Test 8: Compile source with complex expression (compute(x) = x * 3 + 1)
    {
        uint32_t result = er_wasm_compiler_compile_wasm(
            compiler_mem, COMPILER_MEM_SIZE,
            "src/main.er", 11,
            (const uint8_t*)complex_expr_source,
            sizeof(complex_expr_source) - 1);

        uint32_t status = er_wasm_compiler_status();
        TEST("complex_expr_source compile ok", result == 0 && status == 0);

        void* out_ptr = er_wasm_compiler_output_ptr();
        uint64_t out_len = er_wasm_compiler_output_len();
        int valid = validate_wasm((const uint8_t*)out_ptr, out_len);
        TEST("complex_expr_source valid WASM", valid == 0);

        int ec = wasm_export_count((const uint8_t*)out_ptr, out_len);
        TEST("complex_expr_source export count = 29 (base + 1 user)", ec == 29);

        int has_compute = wasm_has_export((const uint8_t*)out_ptr, out_len,
                                          "compute", 7);
        TEST("complex_expr_source export 'compute' present", has_compute == 1);
    }

    if (passed_tests != total_tests) return 1;
    return 0;
}
