; EdgeRun software SHA-256 — streaming implementation
;
; Provides:
;   er_sha256_init(ctx)         — init digest state
;   er_sha256_update(ctx, data, len) — feed data, process full blocks
;   er_sha256_final(ctx, out)   — pad + output 32-byte digest
;
; Context structure (108 bytes):
;   +0:  H[0..7]    8 dwords   (32 bytes)
;   +32: count      1 qword    (8 bytes, total bytes processed)
;   +40: buf[64]    64 bytes   (partial block)
;   +104: buflen    1 dword    (4 bytes, 0..63)
;
; All functions preserve callee-saved registers (rbx, rbp, r12-r15).

%include "x86_64/macros.inc"

; ─── SHA-256 round constants K[0..63] ────────────────────────────────
SECTION .rodata
align 16
K256:
    dd 0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5
    dd 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5
    dd 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3
    dd 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174
    dd 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc
    dd 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da
    dd 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7
    dd 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967
    dd 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13
    dd 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85
    dd 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3
    dd 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070
    dd 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5
    dd 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3
    dd 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208
    dd 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2

; ─── Initial hash values H[0..7] ─────────────────────────────────────
align 16
H0:
    dd 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    dd 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

; ─── Context offsets ─────────────────────────────────────────────────
%define SHA256_CTX_H      0      ; 8 dwords = 32 bytes
%define SHA256_CTX_COUNT  32     ; 1 qword
%define SHA256_CTX_BUF    40     ; 64 bytes
%define SHA256_CTX_BUFLEN 104    ; 1 dword
%define SHA256_CTX_SIZE   108

; ─── SHA-256 compression function (one 64-byte block) ───────────────
; rdi = ctx (state updated in-place)
; rsi = block (64 bytes, big-endian words)
; Clobbers: rax, rcx, rdx, rsi, rdi, r8-r15
; =====================================================================
; SHA-256 compression function (one 64-byte block)
; rdi = ctx (state updated in-place)
; rsi = block (64 bytes, big-endian words)
; Clobbers: rax, rcx, rdx, rsi, rdi, r8-r15
; =====================================================================
er_fn _sha256_compress
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 64 * 4 + 8   ; W[0..63] + 8 bytes for ctx save

    ; Save ctx at [rsp + 256] (dedicated slot, not overlapping saved regs)
    mov     [rsp + 256], rdi

    ; Copy first 16 words from block to W[0..15], byte-swap to LE
    lea     rdi, [rsp]         ; rdi = W base pointer
    xor     ecx, ecx
.load_w:
    mov     eax, [rsi]
    bswap   eax
    mov     [rdi], eax
    add     rsi, 4
    add     rdi, 4
    inc     ecx
    cmp     ecx, 16
    jb      .load_w

    ; Extend W[16..63] — use rdi advancing pointer
    mov     ecx, 16
.extend_w:
    ; W[t] = σ1(W[t-2]) + W[t-7] + σ0(W[t-15]) + W[t-16]
    mov     eax, [rdi - 2*4]
    mov     edx, eax
    ror     edx, 17
    mov     ebx, eax
    ror     ebx, 19
    xor     edx, ebx
    shr     eax, 10
    xor     edx, eax
    add     edx, [rdi - 7*4]

    mov     eax, [rdi - 15*4]
    mov     ebx, eax
    ror     ebx, 7
    mov     ebp, eax
    ror     ebp, 18
    xor     ebx, ebp
    shr     eax, 3
    xor     ebx, eax
    add     edx, ebx
    add     edx, [rdi - 16*4]

    mov     [rdi], edx
    add     rdi, 4
    inc     ecx
    cmp     ecx, 64
    jb      .extend_w

    ; Set up ctx, W base, K table pointers
    mov     rbx, [rsp + 256]   ; rbx = ctx
    lea     rbp, [rel K256]    ; rbp = K table

    ; Initialize a-h from H[0..7]
    mov     r8d,  [rbx + SHA256_CTX_H + 0]
    mov     r9d,  [rbx + SHA256_CTX_H + 4]
    mov     r10d, [rbx + SHA256_CTX_H + 8]
    mov     r11d, [rbx + SHA256_CTX_H + 12]
    mov     r12d, [rbx + SHA256_CTX_H + 16]
    mov     r13d, [rbx + SHA256_CTX_H + 20]
    mov     r14d, [rbx + SHA256_CTX_H + 24]
    mov     r15d, [rbx + SHA256_CTX_H + 28]

    ; 64 rounds
    xor     ecx, ecx
.round:
    ; T1 = h + Σ1(e) + Ch(e,f,g) + K[t] + W[t]
    mov     eax, r12d
    mov     edx, eax
    ror     edx, 6
    mov     esi, eax
    ror     esi, 11
    xor     edx, esi
    mov     esi, eax
    ror     esi, 25
    xor     edx, esi

    mov     eax, r12d
    mov     ebx, eax
    and     eax, r13d
    not     ebx
    and     ebx, r14d
    xor     eax, ebx

    add     edx, r15d
    add     edx, eax
    add     edx, [rsp + rcx * 4]  ; + W[t]
    add     edx, [rbp + rcx * 4]  ; + K[t]

    ; T2 = Σ0(a) + Maj(a,b,c)
    mov     eax, r8d
    mov     esi, eax
    ror     esi, 2
    mov     edi, eax
    ror     edi, 13
    xor     esi, edi
    mov     edi, eax
    ror     edi, 22
    xor     esi, edi

    mov     eax, r8d
    and     eax, r9d
    mov     edi, r8d
    and     edi, r10d
    xor     eax, edi
    mov     edi, r9d
    and     edi, r10d
    xor     eax, edi
    add     esi, eax

    ; Rotate
    mov     r15d, r14d
    mov     r14d, r13d
    mov     r13d, r12d
    mov     eax, r11d
    add     eax, edx
    mov     r12d, eax
    mov     r11d, r10d
    mov     r10d, r9d
    mov     r9d,  r8d
    add     edx, esi
    mov     r8d,  edx

    inc     ecx
    cmp     ecx, 64
    jb      .round

    ; Add a-h to H[0..7]
    mov     rdi, [rsp + 256]
    add     [rdi + SHA256_CTX_H + 0],  r8d
    add     [rdi + SHA256_CTX_H + 4],  r9d
    add     [rdi + SHA256_CTX_H + 8],  r10d
    add     [rdi + SHA256_CTX_H + 12], r11d
    add     [rdi + SHA256_CTX_H + 16], r12d
    add     [rdi + SHA256_CTX_H + 20], r13d
    add     [rdi + SHA256_CTX_H + 24], r14d
    add     [rdi + SHA256_CTX_H + 28], r15d

    add     rsp, 64 * 4 + 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

; =====================================================================
; er_sha256_init — initialize SHA-256 context
; void er_sha256_init(er_sha256_ctx* ctx)
; rdi = ctx → rax = ctx
; =====================================================================
er_fn er_sha256_init
    test    rdi, rdi
    jz      .err

    push    rdi
    push    rsi
    push    rcx

    ; Copy H[0..7] from rodata
    lea     rsi, [rel H0]
    mov     ecx, 8
.loop:
    mov     eax, [rsi + rcx*4 - 4]
    mov     [rdi + SHA256_CTX_H + rcx*4 - 4], eax
    dec     ecx
    jnz     .loop

    ; Zero count
    mov     qword [rdi + SHA256_CTX_COUNT], 0

    ; Zero buffer and buflen
    xor     eax, eax
    mov     [rdi + SHA256_CTX_BUFLEN], eax
    lea     rdi, [rdi + SHA256_CTX_BUF]
    mov     ecx, 64 / 4
    rep     stosd

    pop     rcx
    pop     rsi
    pop     rax            ; return original ctx pointer
    ret

.err:
    xor     eax, eax
    ret

; =====================================================================
; er_sha256_update — feed data into SHA-256 context
; void er_sha256_update(er_sha256_ctx* ctx, const void* data, uint64_t len)
; rdi = ctx, rsi = data, rdx = len
; Returns: rax = ctx if any data was consumed, 0 on error
; =====================================================================
er_fn er_sha256_update
    test    rdi, rdi
    jz      .err
    test    rdx, rdx
    jz      .err_rdx

    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi           ; r12 = ctx
    mov     r13, rsi           ; r13 = data
    mov     r14, rdx           ; r14 = remaining bytes

    ; Update total count
    add     [r12 + SHA256_CTX_COUNT], r14

    ; Process partial buffer first
    mov     r15d, [r12 + SHA256_CTX_BUFLEN]  ; r15 = bytes in buffer
    test    r15d, r15d
    jz      .full_blocks

    ; Calculate how many bytes to fill the buffer
    mov     ebp, 64
    sub     ebp, r15d          ; ebp = space in buffer (64 - buflen)
    cmp     r14d, ebp
    jb      .copy_partial      ; not enough to fill buffer

    ; Fill buffer and process
    lea     rdi, [r12 + SHA256_CTX_BUF + r15]
    mov     rsi, r13
    mov     ecx, ebp
    rep     movsb

    ; Process full buffer
    lea     rdi, [r12 + SHA256_CTX_BUF]
    call    _sha256_compress

    ; Update remaining
    add     r13, rbp
    sub     r14, rbp
    mov     dword [r12 + SHA256_CTX_BUFLEN], 0

.full_blocks:
    ; Process full 64-byte blocks
    mov     ebx, r14d
    shr     ebx, 6             ; ebx = number of full blocks
    jz      .partial_copy

.full_loop:
    mov     rdi, r12
    mov     rsi, r13
    call    _sha256_compress
    add     r13, 64
    sub     r14, 64
    dec     ebx
    jnz     .full_loop

.partial_copy:
    ; Copy remaining bytes to buffer
    test    r14d, r14d
    jz      .done
    mov     dword [r12 + SHA256_CTX_BUFLEN], r14d
    lea     rdi, [r12 + SHA256_CTX_BUF]
    mov     rsi, r13
    mov     ecx, r14d
    rep     movsb
    jmp     .done

.copy_partial:
    ; Not enough to fill buffer — just copy
    lea     rdi, [r12 + SHA256_CTX_BUF + r15]
    mov     rsi, r13
    mov     ecx, r14d
    rep     movsb
    add     [r12 + SHA256_CTX_BUFLEN], r14d

.done:
    mov     rax, r12
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

.err:
    xor     eax, eax
    ret

.err_rdx:
    xor     eax, eax
    ret

; =====================================================================
; er_sha256_final — finalize SHA-256, output 32-byte digest
; void er_sha256_final(er_sha256_ctx* ctx, uint8_t out[32])
; rdi = ctx, rsi = out
; Returns: rax = out
; =====================================================================
er_fn er_sha256_final
    test    rdi, rdi
    jz      .err
    test    rsi, rsi
    jz      .err

    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi           ; r12 = ctx
    mov     r13, rsi           ; r13 = out

    ; Padding: append 0x80
    mov     r14d, [r12 + SHA256_CTX_BUFLEN]  ; r14d = buflen (use r14 as 64-bit index)
    mov     byte [r12 + SHA256_CTX_BUF + r14], 0x80
    inc     r14d                              ; r14d = position after 0x80

    ; If position > 56, need an extra block
    cmp     r14d, 56
    ja      .extra_block

    ; Pad zeros from position to 55
    cmp     r14d, 56
    jae     .write_len         ; exactly at 56, no zeros needed
    lea     rdi, [r12 + SHA256_CTX_BUF + r14]
    mov     ecx, 56
    sub     ecx, r14d          ; ecx = zero count
    xor     eax, eax
    rep     stosb
    jmp     .write_len

.extra_block:
    ; Pad zeros to end of buffer (64)
    lea     rdi, [r12 + SHA256_CTX_BUF + r14]
    mov     ecx, 64
    sub     ecx, r14d          ; ecx = bytes to fill
    xor     eax, eax
    rep     stosb

    ; Process this block
    mov     rdi, r12
    lea     rsi, [r12 + SHA256_CTX_BUF]
    call    _sha256_compress

    ; Zero first 56 bytes of buffer for second block
    xor     eax, eax
    lea     rdi, [r12 + SHA256_CTX_BUF]
    mov     ecx, 56 / 4
    rep     stosd

.write_len:
    ; Write 64-bit bit count at buffer offset 56 (big-endian)
    mov     rax, [r12 + SHA256_CTX_COUNT]
    shl     rax, 3
    bswap   rax
    mov     [r12 + SHA256_CTX_BUF + 56], rax

    ; Process final block
    mov     rdi, r12
    lea     rsi, [r12 + SHA256_CTX_BUF]
    call    _sha256_compress

    ; Output H[0..7] as big-endian bytes
    mov     rdi, r13
    xor     rcx, rcx
.out_loop:
    mov     eax, [r12 + SHA256_CTX_H + rcx * 4]
    bswap   eax
    mov     [rdi + rcx * 4], eax
    inc     rcx
    cmp     rcx, 8
    jb      .out_loop

    mov     rax, r13
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.err:
    xor     eax, eax
    ret
