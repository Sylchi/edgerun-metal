// EdgeRun WASM compile + pipeline integration test
typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long      uint64_t;
typedef uint64_t           size_t;
typedef long               int64_t;

typedef struct {
    void*  memory_ptr;
    uint64_t memory_len;
    void*  execution_ticks_ptr;
    void*  memory_grow_fn;
    void*  memory_grow_ctx;
    void*  table_grow_fn;
    void*  table_grow_ctx;
    uint64_t initial_pages;
    uint8_t has_initial_pages;
} runtime_t;

extern uint32_t er_wasm_compiler_compile_wasm(
    void* mem, uint64_t mem_len,
    const char* name, uint64_t name_len,
    const uint8_t* source, uint64_t source_len);
extern void*    er_wasm_compiler_output_ptr(void);
extern uint64_t er_wasm_compiler_output_len(void);

extern uint64_t module_load(const char* name, size_t name_len,
                            const uint8_t* wasm, size_t wasm_len);
extern uint64_t module_run_export(uint64_t mid, runtime_t* runtime,
                                  const char* name, size_t name_len);

#define WASM_PAGE_SIZE 65536ULL
#define COMPILER_MEM_SIZE (1024 * 1024)

int main(void) {
    static uint8_t compiler_mem[COMPILER_MEM_SIZE] __attribute__((aligned(16)));
    static uint8_t wasm_memory[WASM_PAGE_SIZE];
    static uint64_t ticks = 0;

    runtime_t rt;
    rt.memory_ptr = wasm_memory;
    rt.memory_len = WASM_PAGE_SIZE;
    rt.execution_ticks_ptr = &ticks;
    rt.memory_grow_fn = 0;
    rt.memory_grow_ctx = 0;
    rt.table_grow_fn = 0;
    rt.table_grow_ctx = 0;
    rt.initial_pages = 1;
    rt.has_initial_pages = 1;

    // Test compiled wasm
    const char* src = "export fn main() u32 { return 42; }\n";
    uint32_t r = er_wasm_compiler_compile_wasm(compiler_mem, COMPILER_MEM_SIZE,
        "x", 1, (const uint8_t*)src, 36);
    if (r != 0) return 20;

    uint64_t mid = module_load("comp_mod", 8,
        (const uint8_t*)er_wasm_compiler_output_ptr(),
        er_wasm_compiler_output_len());
    if (mid == 0xFFFFFFFFFFFFFFFFULL) return 21;

    uint64_t val = module_run_export(mid, &rt, "main", 4);
    if (val != 42) return 22;

    return 0;
}
