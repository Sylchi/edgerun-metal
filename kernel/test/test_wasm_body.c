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

// Read LEB128 u32
static int read_leb(const uint8_t* p, uint32_t* val) {
    *val = 0; int shift = 0, bytes = 0;
    while (bytes < 5) {
        uint8_t b = p[bytes];
        *val |= (uint32_t)(b & 0x7f) << shift;
        shift += 7; bytes++;
        if (!(b & 0x80)) return bytes;
    }
    return bytes;
}

int main(void) {
    enum { MEM_SZ = 1024 * 1024 };
    static uint8_t mem[MEM_SZ] __attribute__((aligned(16)));

    const char* src = "export fn main() u32 { return 42; }\n";
    uint32_t r = er_wasm_compiler_compile_wasm(mem, MEM_SZ,
        "x", 1, (const uint8_t*)src, 36);
    if (r != 0) return 10 + r;

    uint8_t* wasm = (uint8_t*)er_wasm_compiler_output_ptr();
    uint64_t len = er_wasm_compiler_output_len();
    if (len < 80) return 20;

    // Walk sections to find code section (id=10)
    uint64_t pos = 8;
    while (pos < len) {
        if (pos + 1 > len) return 30;
        uint8_t sid = wasm[pos++];
        uint32_t slen;
        int leb = read_leb(wasm + pos, &slen);
        pos += leb;
        if (pos + slen > len) return 31;
        if (sid == 10) {
            // Found code section. Decode function count.
            uint32_t fcount;
            pos += read_leb(wasm + pos, &fcount);
            // Find last function body (user function)
            for (uint32_t fi = 0; fi < fcount; fi++) {
                uint32_t body_size;
                pos += read_leb(wasm + pos, &body_size);
                if (fi == fcount - 1) {
                    // User function: check body
                    if (pos + 4 > len) return 40;
                    // body[0] = local count
                    if (wasm[pos] != 0) return 41;
                    // body[1] = i32.const
                    if (wasm[pos+1] != 0x41) return 42;
                    // body[2] = LEB128 value
                    uint32_t val;
                    read_leb(wasm + pos + 2, &val);
                    if (val != 42) return 43;
                    // body[3..] = end
                    // skip body
                }
                pos += body_size;
            }
            return 0;  // success
        }
        pos += slen;
    }
    return 50;  // no code section
}
