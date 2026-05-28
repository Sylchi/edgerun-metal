; EdgeRun BLAKE3 hash — pure x86_64 scalar assembly
; Faithful port of edgerun-crypto/src/er_blake3.c scalar path
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, arg5=r8, arg6=r9
; No libc, no SIMD, no external dependencies.

%include "x86_64/macros.inc"

default rel

; ==================================================================
; BLAKE3 constants
; ==================================================================
%define BLAKE3_OUT_LEN       32
%define BLAKE3_BLOCK_LEN     64
%define BLAKE3_CHUNK_LEN     1024
%define BLAKE3_MAX_DEPTH     54
%define BLAKE3_COMPRESS_ROUNDS 7

; Flags
%define BLAKE3_CHUNK_START   1
%define BLAKE3_CHUNK_END     2
%define BLAKE3_PARENT        4
%define BLAKE3_ROOT          8

; ==================================================================
; .rodata
; ==================================================================
SECTION .rodata

blake3_iv:
    dd 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    dd 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

; Message permutation schedule: 7 rounds x 16 indices
blake3_perm:
    db  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
    db  2, 6, 3,10, 7, 0, 4,13, 1,11,12, 5, 9,14,15, 8
    db  3, 4,10,12,13, 2, 7,14, 6, 5, 9, 0,11,15, 8, 1
    db 10, 7,12, 9,14, 3,13,15, 4, 0,11, 2, 5, 8, 1, 6
    db 12,13, 9,11,15,10,14, 8, 7, 2, 5, 3, 0, 1, 6, 4
    db  9,14,11, 5, 8,12,15, 1,13, 3, 0,10, 2, 6, 4, 7
    db 11,15, 5, 0, 1, 9, 8, 6,14,10, 2,12, 3, 4, 7,13

; ==================================================================
; G function helper macro
; state = rdi (16 x uint32_t), mx/my in registers, indices 0..15
; ==================================================================
%macro _blake3_g 4
    ; %1 = a, %2 = b, %3 = c, %4 = d  (indices 0-15)
    ; mx = first msg reg, my = second msg reg (stack-relative)
    mov     r10d, [rdi + %1 * 4]
    add     r10d, [rdi + %2 * 4]
    add     r10d, [rsp + 0]        ; mx
    mov     [rdi + %1 * 4], r10d
    mov     r11d, [rdi + %4 * 4]
    xor     r11d, r10d
    ror     r11d, 16
    mov     [rdi + %4 * 4], r11d
    mov     r10d, [rdi + %3 * 4]
    add     r10d, r11d
    mov     [rdi + %3 * 4], r10d
    mov     r11d, [rdi + %2 * 4]
    xor     r11d, r10d
    ror     r11d, 12
    mov     [rdi + %2 * 4], r11d
    mov     r10d, [rdi + %1 * 4]
    add     r10d, r11d
    add     r10d, [rsp + 4]        ; my
    mov     [rdi + %1 * 4], r10d
    mov     r11d, [rdi + %4 * 4]
    xor     r11d, r10d
    ror     r11d, 8
    mov     [rdi + %4 * 4], r11d
    mov     r10d, [rdi + %3 * 4]
    add     r10d, r11d
    mov     [rdi + %3 * 4], r10d
    mov     r11d, [rdi + %2 * 4]
    xor     r11d, r10d
    ror     r11d, 7
    mov     [rdi + %2 * 4], r11d
%endm

; ==================================================================
; Column step: 4 G calls
; rdi = state, perm table address in rbx
; ==================================================================
%macro _blake3_column 0
    movzx   r8d, byte [rbx]       ; perm[0]
    movzx   r9d, byte [rbx + 1]   ; perm[1]
    mov     r10d, [r13 + r8 * 4]   ; mx
    mov     r11d, [r13 + r9 * 4]   ; my
    push    r11
    push    r10
    _blake3_g 0, 4, 8,12
    add     rsp, 8

    movzx   r8d, byte [rbx + 2]
    movzx   r9d, byte [rbx + 3]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 1, 5, 9,13
    add     rsp, 8

    movzx   r8d, byte [rbx + 4]
    movzx   r9d, byte [rbx + 5]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 2, 6,10,14
    add     rsp, 8

    movzx   r8d, byte [rbx + 6]
    movzx   r9d, byte [rbx + 7]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 3, 7,11,15
    add     rsp, 8
%endm

; ==================================================================
; Diagonal step: 4 G calls
; ==================================================================
%macro _blake3_diagonal 0
    movzx   r8d, byte [rbx + 8]
    movzx   r9d, byte [rbx + 9]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 0, 5,10,15
    add     rsp, 8

    movzx   r8d, byte [rbx + 10]
    movzx   r9d, byte [rbx + 11]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 1, 6,11,12
    add     rsp, 8

    movzx   r8d, byte [rbx + 12]
    movzx   r9d, byte [rbx + 13]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 2, 7, 8,13
    add     rsp, 8

    movzx   r8d, byte [rbx + 14]
    movzx   r9d, byte [rbx + 15]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    push    r11
    push    r10
    _blake3_g 3, 4, 9,14
    add     rsp, 8
%endm

; ==================================================================
; One round: column + diagonal
; rdi = state, rbx = perm ptr, r13 = block_words
; ==================================================================
%macro _blake3_round 0
    _blake3_column
    _blake3_diagonal
%endm

; ==================================================================
; SECTION .text
; ==================================================================
SECTION .text

; ==================================================================
; er_blake3_words_from_block — deserialize 64 bytes to 16 x uint32_t LE
; rdi = block[64], rsi = words[16]
; =================================================================+
er_blake3_words_from_block:
    er_frame_push
    xor     ecx, ecx
.loop:
    mov     eax, [rdi + rcx * 4]
    bswap   eax
    mov     [rsi + rcx * 4], eax
    inc     ecx
    cmp     ecx, 16
    jb      .loop
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_store32 — store uint32_t as 4 little-endian bytes
; rdi = dst, esi = word
; =================================================================+
er_blake3_store32:
    mov     eax, esi
    bswap   eax
    mov     [rdi], eax
    er_ret

; ==================================================================
; er_blake3_compress — 7-round compression
; rdi = cv[8], rsi = block_words[16], rdx = counter (uint64_t)
; rcx = block_len, r8 = flags, r9 = out[16]
; =================================================================+
er_fn er_blake3_compress
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 64             ; state[16] on stack

    mov     r12, rdi            ; cv
    mov     r13, rsi            ; block_words
    mov     r14, rdx            ; counter
    mov     r15, r9             ; out

    ; state[0..7] = cv[0..7]
    xor     ecx, ecx
.icv:
    mov     eax, [r12 + rcx * 4]
    mov     [rsp + rcx * 4], eax
    inc     ecx
    cmp     ecx, 8
    jb      .icv

    ; state[8..11] = IV[0..3]
    lea     rbx, [rel blake3_iv]
    xor     ecx, ecx
.iiv:
    mov     eax, [rbx + rcx * 4]
    mov     [rsp + (8 + rcx) * 4], eax
    inc     ecx
    cmp     ecx, 4
    jb      .iiv

    ; state[12] = counter[31:0]
    mov     [rsp + 12 * 4], r14d
    ; state[13] = counter[63:32]
    mov     eax, r14d
    shr     r14, 32
    mov     [rsp + 13 * 4], r14d
    ; state[14] = block_len
    mov     [rsp + 14 * 4], ecx
    ; state[15] = flags
    mov     [rsp + 15 * 4], r8d

    ; 7 rounds
    lea     rbx, [rel blake3_perm]
    mov     rdi, rsp            ; state ptr in rdi for macros

    ; Round 0: perm offset 0
    lea     rbx, [rel blake3_perm]
    _blake3_round

    ; Round 1: perm offset 16
    lea     rbx, [rel blake3_perm + 16]
    _blake3_round

    ; Round 2: perm offset 32
    lea     rbx, [rel blake3_perm + 32]
    _blake3_round

    ; Round 3: perm offset 48
    lea     rbx, [rel blake3_perm + 48]
    _blake3_round

    ; Round 4: perm offset 64
    lea     rbx, [rel blake3_perm + 64]
    _blake3_round

    ; Round 5: perm offset 80
    lea     rbx, [rel blake3_perm + 80]
    _blake3_round

    ; Round 6: perm offset 96
    lea     rbx, [rel blake3_perm + 96]
    _blake3_round

    ; Finalization XOR
    xor     ecx, ecx
.fxor:
    mov     eax, [rsp + ecx * 4]
    mov     ebx, [rsp + (ecx + 8) * 4]
    xor     eax, ebx
    mov     [r15 + ecx * 4], eax
    xor     ebx, [r12 + ecx * 4]
    mov     [r15 + (ecx + 8) * 4], ebx
    inc     ecx
    cmp     ecx, 8
    jb      .fxor

    add     rsp, 64
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    er_ret
