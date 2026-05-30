; EdgeRun hash/PRNG functions — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx

; ==================================================================
; er_xorshift64 — xorshift64 PRNG (deterministic)
; Returns next pseudo-random uint64, updates state in place.
; uint64_t er_xorshift64(uint64_t* state)
; Algorithm: state ^= state << 13; state ^= state >> 7; state ^= state << 17
; ==================================================================
er_fn er_xorshift64
    mov     rax, [rdi]
    mov     rdx, rax
    shl     rdx, 13
    xor     rax, rdx
    mov     rdx, rax
    shr     rdx, 7
    xor     rax, rdx
    mov     rdx, rax
    shl     rdx, 17
    xor     rax, rdx
    mov     [rdi], rax
    er_ret

; ==================================================================
; er_crc32c — compute CRC-32C (Castagnoli) checksum
; Uses x86 SSE 4.2 crc32 instruction.
; uint32_t er_crc32c(uint32_t crc, const void* data, size_t len)
; ==================================================================
er_fn er_crc32c
    mov     eax, edi            ; crc
    test    rdx, rdx
    jz      .crc32c_done
    mov     r8, rsi             ; data ptr
    mov     rcx, rdx            ; len
.crc32c_8:
    cmp     rcx, 8
    jb      .crc32c_4
    crc32   rax, qword [r8]
    add     r8, 8
    sub     rcx, 8
    jmp     .crc32c_8
.crc32c_4:
    cmp     rcx, 4
    jb      .crc32c_1
    crc32   eax, dword [r8]
    add     r8, 4
    sub     rcx, 4
    jmp     .crc32c_4
.crc32c_1:
    test    rcx, rcx
    jz      .crc32c_done
    crc32   eax, byte [r8]
    inc     r8
    dec     rcx
    jmp     .crc32c_1
.crc32c_done:
    er_ret

; ==================================================================
; er_fnv1a64 — FNV-1a 64-bit hash
; uint64_t er_fnv1a64(const void* data, size_t len)
; ==================================================================
er_fn er_fnv1a64
    mov     rax, 0xcbf29ce484222325   ; FNV offset basis
    test    rsi, rsi
    jz      .fnv1a_done
    xor     rcx, rcx
    mov     r10, rsi
.fnv1a_loop:
    movzx   rdx, byte [rdi + rcx]
    xor     rax, rdx
    mov     r8, 0x100000001b3         ; FNV prime
    mul     r8
    inc     rcx
    cmp     rcx, r10
    jb      .fnv1a_loop
.fnv1a_done:
    er_ret
