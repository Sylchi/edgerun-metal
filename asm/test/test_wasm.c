// EdgeRun WASM interpreter test harness
// Minimal test: verify i32.const 42 is returned from a WASM module
// Freestanding — no libc.
typedef unsigned char      uint8_t;
typedef unsigned long      uint64_t;
typedef uint64_t           size_t;

// Runtime struct matching wasm_interpreter.asm expectations
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
} runtime_t;

// WASM interpreter entry point
// rdi = runtime_ptr, rsi = wasm_bytes, rdx = wasm_len, rcx = export_name, r8 = export_name_len
// Returns: rax = result value, rdx = error code
extern uint64_t er_fn_run(runtime_t* runtime, const uint8_t* wasm_bytes, size_t wasm_len, const char* export_name, size_t export_name_len);

// Minimal WASM module: (module (func (export "f") (result i32) i32.const 42))
// Generated manually per WASM binary format
static const uint8_t wasm_module[] = {
    0x00, 0x61, 0x73, 0x6d,  // magic \0asm
    0x01, 0x00, 0x00, 0x00,  // version 1
    // Type section (id=1)
    0x01,                      // section id
    0x05,                      // section length = 5
    0x01,                      // 1 type
    0x60,                      // functype
    0x00,                      // 0 params
    0x01,                      // 1 result
    0x7f,                      // i32
    // Function section (id=3)
    0x03,                      // section id
    0x02,                      // section length = 2
    0x01,                      // 1 function
    0x00,                      // type index 0
    // Export section (id=7)
    0x07,                      // section id
    0x05,                      // section length = 5
    0x01,                      // 1 export
    0x01,                      // name length = 1
    0x66,                      // 'f'
    0x00,                      // export kind: func
    0x00,                      // function index 0
    // Code section (id=10)
    0x0a,                      // section id
    0x06,                      // section length = 6
    0x01,                      // 1 code body
    0x04,                      // body size = 4 (locals + opcodes)
    0x00,                      // 0 local declarations
    0x41,                      // i32.const
    0x2a,                      // 42
    0x0b,                      // end
};

#define WASM_MODULE_SIZE sizeof(wasm_module)

// WASM page size = 64KB
#define WASM_PAGE_SIZE 65536ULL
#define INITIAL_MEMORY_PAGES 1

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do { \
    total_tests++; \
    if (expr) { passed_tests++; } \
} while(0)

int main(void) {
    // Allocate WASM linear memory
    static uint8_t wasm_memory[WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES];

    // Allocate the execution ticks counter
    static uint64_t execution_ticks = 0;

    // Setup the runtime
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

    uint64_t result = er_fn_run(&runtime, wasm_module, WASM_MODULE_SIZE, "f", 1);
    // result contains the return value from the WASM function
    // (rdx contains error code, which we ignore for now)

    TEST("wasm i32.const 42 returns 42", result == 42);
    TEST("wasm result is nonzero", result != 0);

    return (passed_tests == total_tests) ? 0 : 1;
}
