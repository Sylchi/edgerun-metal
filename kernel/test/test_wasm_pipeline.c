// EdgeRun WASM pipeline test
// Tests sequential module execution with shared linear memory.
// Freestanding — no libc.

typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long      uint64_t;
typedef uint64_t           size_t;

// Runtime struct matching wasm_run.asm
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

// Module manager entry points
extern uint64_t module_load(const char* name, size_t name_len,
                            const uint8_t* wasm, size_t wasm_len);
extern uint64_t module_run_export(uint64_t module_id, runtime_t* runtime,
                                  const char* export_name, size_t export_name_len);
extern uint64_t module_find_by_name(const char* name, size_t name_len);
extern uint64_t module_count(void);

// er_fn_run for direct comparison
extern uint64_t er_fn_run(runtime_t* runtime, const uint8_t* wasm, size_t wasm_len,
                          const char* export_name, size_t export_name_len);

#define WASM_PAGE_SIZE 65536ULL
#define INITIAL_MEMORY_PAGES 1

// Sections must be in strictly increasing section-id order per WASM spec:
// Type(1) < Import(2) < Function(3) < Table(4) < Memory(5) < Global(6)
// < Export(7) < Start(8) < Element(9) < Code(10) < Data(11) < DataCount(12)

// ==================================================================
// WASM module "identity": exports "process" -> i32.const 42
// (module (func (export "process") (result i32) i32.const 42))
// Sections: Type(1), Function(3), Export(7), Code(10)
// ==================================================================
static const uint8_t wasm_identity[] = {
    0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00,  // magic + version
    0x01,0x05,0x01,0x60,0x00,0x01,0x7f,         // Type: 1 type, () -> i32
    0x03,0x02,0x01,0x00,                         // Function: 1 func, type 0
    0x07,0x0b,0x01,                              // Export: 1 export
    0x07,'p','r','o','c','e','s','s',0x00,0x00,  // "process" func#0
    0x0a,0x06,0x01,0x04,0x00,0x41,0x2a,0x0b,    // Code: i32.const 42
};
#define IDENTITY_SIZE sizeof(wasm_identity)

// ==================================================================
// WASM module "producer": exports "process" -> stores 21 at mem[0]
// (module (memory (export "memory") 1)
//   (func (export "process") (result i32)
//     i32.const 21  i32.const 0  i32.store  i32.const 0))
// Sections: Type(1), Function(3), Memory(5), Export(7), Code(10)
// ==================================================================
static const uint8_t wasm_producer[] = {
    0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00,  // magic + version
    0x01,0x05,0x01,0x60,0x00,0x01,0x7f,         // Type: () -> i32
    0x03,0x02,0x01,0x00,                         // Function: type 0
    0x05,0x03,0x01,0x00,0x01,                    // Memory: min=1
    0x07,0x14,0x02,                              // Export: 2 (20B content)
    0x06,'m','e','m','o','r','y',0x02,0x00,      // "memory" mem#0
    0x07,'p','r','o','c','e','s','s',0x00,0x00,  // "process" func#0
    0x0a,0x0d,0x01,0x0b,0x00,                    // Code: body size=11
    0x41,0x15,                                    // i32.const 21
    0x41,0x00,                                    // i32.const 0 (addr)
    0x36,0x02,0x00,                               // i32.store align=2 off=0
    0x41,0x00,                                    // i32.const 0 (ret val)
    0x0b,                                         // end
};
#define PRODUCER_SIZE sizeof(wasm_producer)

// ==================================================================
// WASM module "doubler": exports "process" -> mem[0] * 2
// (module (memory 1)
//   (func (export "process") (result i32)
//     i32.const 0  i32.load  i32.const 2  i32.mul))
// Sections: Type(1), Function(3), Memory(5), Export(7), Code(10)
// ==================================================================
static const uint8_t wasm_doubler[] = {
    0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00,  // magic + version
    0x01,0x05,0x01,0x60,0x00,0x01,0x7f,         // Type: () -> i32
    0x03,0x02,0x01,0x00,                         // Function: type 0
    0x05,0x03,0x01,0x00,0x01,                    // Memory: min=1
    0x07,0x0b,0x01,                              // Export: 1 (11B content)
    0x07,'p','r','o','c','e','s','s',0x00,0x00,  // "process" func#0
    0x0a,0x0c,0x01,0x0a,0x00,                    // Code: body size=10
    0x41,0x00,                                    // i32.const 0 (addr)
    0x28,0x02,0x00,                               // i32.load align=2 off=0
    0x41,0x02,                                    // i32.const 2
    0x6c,                                         // i32.mul
    0x0b,                                         // end
};
#define DOUBLER_SIZE sizeof(wasm_doubler)

static int total_tests = 0;
static int passed_tests = 0;

#define TEST(name, expr) do {    \
    total_tests++;               \
    if (expr) { passed_tests++; } \
    else { }                     \
} while(0)

int main(void) {
    static uint8_t wasm_memory[WASM_PAGE_SIZE * INITIAL_MEMORY_PAGES];
    static uint64_t execution_ticks = 0;
    uint64_t result;
    uint64_t mid;

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

    // -------------------------------------------------------
    // Test 1: Direct er_fn_run — baseline
    // -------------------------------------------------------
    result = er_fn_run(&runtime, wasm_identity, IDENTITY_SIZE, "process", 7);
    TEST("er_fn_run identity returns 42", result == 42);

    // -------------------------------------------------------
    // Test 2: module_load + module_run_export — single module
    // -------------------------------------------------------
    mid = module_load("identity", 8, wasm_identity, IDENTITY_SIZE);
    result = module_run_export(mid, &runtime, "process", 7);
    TEST("module_run_export identity returns 42", result == 42);

    // -------------------------------------------------------
    // Test 3: module_find_by_name
    // -------------------------------------------------------
    uint64_t found = module_find_by_name("identity", 8);
    TEST("module_find_by_name identity", found == mid);

    // -------------------------------------------------------
    // Test 4: Pipeline — producer stores 21, doubler reads * 2 = 42
    // -------------------------------------------------------
    uint64_t mid_prod = module_load("producer", 8, wasm_producer, PRODUCER_SIZE);
    uint64_t mid_dbl  = module_load("doubler",  7, wasm_doubler,  DOUBLER_SIZE);

    // Run producer: stores 21 at memory[0], returns 0
    result = module_run_export(mid_prod, &runtime, "process", 7);
    TEST("producer returns 0", result == 0);

    // Verify memory[0] = 21
    uint32_t mem_val;
    mem_val = *(volatile uint32_t*)&wasm_memory[0];
    TEST("producer wrote 21 to memory[0]", mem_val == 21);

    // Run doubler: reads memory[0], * 2 = 42, returns result
    result = module_run_export(mid_dbl, &runtime, "process", 7);
    TEST("doubler returns 42 from shared memory", result == 42);

    // -------------------------------------------------------
    // Test 5: module_count
    // -------------------------------------------------------
    uint64_t count = module_count();
    TEST("module_count == 3", count == 3);

    return (passed_tests == total_tests) ? 0 : 1;
}
