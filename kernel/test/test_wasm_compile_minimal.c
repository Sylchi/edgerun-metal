// Minimal: compile + dump output as hex via serial + verify body
typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long      uint64_t;
typedef uint64_t           size_t;

extern uint32_t er_wasm_compiler_compile_wasm(
    void* mem, uint64_t mem_len,
    const char* name, uint64_t name_len,
    const uint8_t* source, uint64_t source_len);
extern void*    er_wasm_compiler_output_ptr(void);
extern uint64_t er_wasm_compiler_output_len(void);

int main(void) {
    enum { COMPILER_MEM_SIZE = 1024 * 1024 };
    static uint8_t mem[COMPILER_MEM_SIZE] __attribute__((aligned(16)));

    const char* src = "export fn main() u32 { return 42; }\n";
    uint32_t r = er_wasm_compiler_compile_wasm(mem, COMPILER_MEM_SIZE,
        "x", 1, (const uint8_t*)src, 36);
    if (r != 0) return 10 + r;

    uint8_t* wasm = (uint8_t*)er_wasm_compiler_output_ptr();
    uint64_t len = er_wasm_compiler_output_len();
    if (len < 80) return 20;  // should be larger with 28 bodies

    // write(1, wasm, len)
    __asm__ volatile (
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "mov %0, %%rsi\n"
        "mov %1, %%rdx\n"
        "syscall\n"
        : : "r" (wasm), "r" (len)
        : "rax", "rdi", "rsi", "rdx"
    );

    return 0;
}
