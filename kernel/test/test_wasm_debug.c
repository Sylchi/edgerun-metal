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

extern uint32_t er_wasm_compiler_status(void);
extern const char* er_wasm_compiler_diagnostic_ptr(void);
extern uint32_t er_wasm_compiler_diagnostic_len(void);

static void puthex(uint8_t b) {
    const char* hex = "0123456789abcdef";
    __asm__ volatile (
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "mov %0, %%rsi\n"
        "mov $1, %%rdx\n"
        "syscall\n"
        : : "r" (hex + (b >> 4))
        : "rax", "rdi", "rsi", "rdx"
    );
    __asm__ volatile (
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "mov %0, %%rsi\n"
        "mov $1, %%rdx\n"
        "syscall\n"
        : : "r" (hex + (b & 0xf))
        : "rax", "rdi", "rsi", "rdx"
    );
}

int main(void) {
    enum { COMPILER_MEM_SIZE = 1024 * 1024 };
    static uint8_t mem[COMPILER_MEM_SIZE] __attribute__((aligned(16)));

    const char* src = "export fn main() u32 { return 42; }\n";
    uint32_t r = er_wasm_compiler_compile_wasm(mem, COMPILER_MEM_SIZE,
        "x", 1, (const uint8_t*)src, 36);

    uint32_t status = er_wasm_compiler_status();
    if (r != 0) {
        const char* diag = er_wasm_compiler_diagnostic_ptr();
        uint32_t dlen = er_wasm_compiler_diagnostic_len();
        // write diag
        __asm__ volatile (
            "mov $1, %%rax\n"
            "mov $1, %%rdi\n"
            "mov %0, %%rsi\n"
            "mov %1, %%rdx\n"
            "syscall\n"
            : : "r" (diag), "r" ((uint64_t)dlen)
            : "rax", "rdi", "rsi", "rdx"
        );
        return 10 + r;
    }

    uint8_t* wasm = (uint8_t*)er_wasm_compiler_output_ptr();
    uint64_t len = er_wasm_compiler_output_len();

    // Dump last 16 bytes of WASM binary
    uint64_t start = len > 16 ? len - 16 : 0;
    for (uint64_t i = start; i < len; i++) {
        puthex(wasm[i]);
    }

    // Newline
    __asm__ volatile (
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "mov %0, %%rsi\n"
        "mov $1, %%rdx\n"
        "syscall\n"
        : : "r" ("\n")
        : "rax", "rdi", "rsi", "rdx"
    );

    return 0;
}
