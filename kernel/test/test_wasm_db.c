typedef unsigned char      uint8_t;
typedef unsigned int       uint32_t;
typedef unsigned long      uint64_t;
typedef uint64_t           size_t;

extern uint32_t er_wasm_compiler_compile_wasm(
    void* mem, uint64_t mem_len,
    const char* name, uint64_t name_len,
    const uint8_t* source, uint64_t source_len);

extern int* er_get_body_buf_pos(void);
extern uint8_t* er_get_body_buf(void);
extern int* er_get_body_lens(void);

static void putstr(const char* s, size_t len) {
    __asm__ volatile ("mov $1, %%rax\nmov $1, %%rdi\nsyscall\n"
        : : "r" (s), "r" (len) : "rax", "rdi", "rsi", "rdx");
}
static void puthex(uint8_t b) {
    const char hex[] = "0123456789abcdef";
    putstr(hex + (b >> 4), 1);
    putstr(hex + (b & 0xf), 1);
}

int main(void) {
    enum { COMPILER_MEM_SIZE = 1024 * 1024 };
    static uint8_t mem[COMPILER_MEM_SIZE] __attribute__((aligned(16)));
    const char* src = "export fn main() u32 { return 42; }\n";
    
    // Call compile
    uint32_t r = er_wasm_compiler_compile_wasm(mem, COMPILER_MEM_SIZE,
        "x", 1, (const uint8_t*)src, 36);
    
    int bp = *er_get_body_buf_pos();
    int bl = *er_get_body_lens();
    uint8_t* bb = er_get_body_buf();
    
    // Print diagnostics
    putstr("body_buf_pos=", 13);
    puthex(bp >> 24); puthex(bp >> 16); puthex(bp >> 8); puthex(bp);
    putstr("\nbody_lens[0]=", 14);
    puthex(bl >> 24); puthex(bl >> 16); puthex(bl >> 8); puthex(bl);
    putstr("\nbody_bytes:", 12);
    for (int i = 0; i < bp && i < 16; i++) {
        putchar(' '); puthex(bb[i]);
    }
    putstr("\n", 1);
    
    return r;
}
