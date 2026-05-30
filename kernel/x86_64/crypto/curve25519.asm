; EdgeRun Curve25519 arithmetic — x86_64 assembly
; Field elements: 5 × 51-bit limbs (radix 2^51), 40 bytes total
; Each limb stored as u64 with bottom 51 bits valid after carry.
;
; Primitives layered from bottom up:
;   _fe_copy, _fe_1, _fe_normalize, _fe_add, _fe_sub, _fe_mul, _fe_square,
;   _fe_mul121665, _fe_frombytes, _fe_tobytes, _fe_cswap
;
; Composite:
;   _fe_invert, _curve25519_ladder_step, er_tor_curve25519_scalar_mult
;
; All primitives use SysV ABI: rdi=1st arg, rsi=2nd, rdx=3rd, rcx=4th, r8=5th

%include "x86_64/macros.inc"

; ==================================================================
; SECTION .rodata — read-only constants
; ==================================================================
SECTION .rodata

; ==================================================================
; SECTION .data — initialized data (copied to BSS at boot)
; ==================================================================
SECTION .data

fe_one_data:
  dq 1, 0, 0, 0, 0
fe_base_data:
  dq 9, 0, 0, 0, 0
fe_zero_data:
  dq 0, 0, 0, 0, 0

; ==================================================================
; SECTION .bss — runtime constants
; ==================================================================
SECTION .bss

GLOBAL fe_one
GLOBAL fe_base
GLOBAL fe_zero

fe_one:   resq 5
fe_base:  resq 5
fe_zero:  resq 5

; Kernel smoke test temporaries (referenced by kernel_main.asm)
GLOBAL fe_tmp0
GLOBAL fe_tmp1
GLOBAL fe_tmp2
GLOBAL fe_tmp3
GLOBAL fe_tmp4

fe_tmp0:  resq 5
fe_tmp1:  resq 5
fe_tmp2:  resq 5
fe_tmp3:  resq 5
fe_tmp4:  resq 5

; ==================================================================
; SECTION .text
; ==================================================================
SECTION .text

extern er_memcpy

GLOBAL _curve25519_init
GLOBAL _fe_copy
GLOBAL _fe_1
GLOBAL _fe_normalize
GLOBAL _fe_add
GLOBAL _fe_sub
GLOBAL _fe_mul
GLOBAL _fe_square
GLOBAL _fe_sq          ; alias
GLOBAL _fe_mul121665
GLOBAL _fe_frombytes
GLOBAL _fe_tobytes
GLOBAL _fe_cswap
GLOBAL _fe_invert
GLOBAL _curve25519_ladder_step
GLOBAL er_tor_curve25519_scalar_mult

; ==================================================================
; _curve25519_init — copy rodata constants into BSS
; Call once at boot before using curve25519 operations.
; ==================================================================
_curve25519_init:
    push    rbx
    lea     rbx, [rel fe_one_data]
    lea     rdi, [rel fe_one]
    mov     rsi, rbx
    call    _fe_copy
    lea     rbx, [rel fe_base_data]
    lea     rdi, [rel fe_base]
    mov     rsi, rbx
    call    _fe_copy
    lea     rbx, [rel fe_zero_data]
    lea     rdi, [rel fe_zero]
    mov     rsi, rbx
    call    _fe_copy
    pop     rbx
    ret

; ==================================================================
; _fe_copy(void *dst, const void *src) — copy 5 limbs (40 bytes)
; ==================================================================
_fe_copy:
    mov     rax, [rsi]
    mov     rcx, [rsi + 8]
    mov     rdx, [rsi + 16]
    mov     r8,  [rsi + 24]
    mov     r9,  [rsi + 32]
    mov     [rdi], rax
    mov     [rdi + 8], rcx
    mov     [rdi + 16], rdx
    mov     [rdi + 24], r8
    mov     [rdi + 32], r9
    ret

; ==================================================================
; _fe_1(void *out) — set to 1
; ==================================================================
_fe_1:
    mov     qword [rdi], 1
    xor     eax, eax
    mov     [rdi + 8], rax
    mov     [rdi + 16], rax
    mov     [rdi + 24], rax
    mov     [rdi + 32], rax
    ret

; ==================================================================
; _fe_normalize(fe *x)
; In-place radix-51 carry normalization.
; Input/output: 5 limbs, each u64.
; Clobbers caller-saved regs only.
; ==================================================================
_fe_normalize:
    mov     r11d, 1
    shl     r11, 51
    dec     r11                     ; mask51

%macro FE_CARRY_PASS 0
    mov     rax, [rdi + 0]
    mov     rcx, [rdi + 8]
    mov     rdx, [rdi + 16]
    mov     r8,  [rdi + 24]
    mov     r9,  [rdi + 32]

    mov     r10, rax
    shr     r10, 51
    and     rax, r11
    add     rcx, r10

    mov     r10, rcx
    shr     r10, 51
    and     rcx, r11
    add     rdx, r10

    mov     r10, rdx
    shr     r10, 51
    and     rdx, r11
    add     r8, r10

    mov     r10, r8
    shr     r10, 51
    and     r8, r11
    add     r9, r10

    mov     r10, r9
    shr     r10, 51
    and     r9, r11
    imul    r10, r10, 19
    add     rax, r10

    mov     [rdi + 0], rax
    mov     [rdi + 8], rcx
    mov     [rdi + 16], rdx
    mov     [rdi + 24], r8
    mov     [rdi + 32], r9
%endmacro

    FE_CARRY_PASS
    FE_CARRY_PASS
    FE_CARRY_PASS
    ret

; ==================================================================
; _fe_add(out, a, b)
; out = a + b mod p, radix-51
; ==================================================================
_fe_add:
    mov     rax, [rsi + 0]
    add     rax, [rdx + 0]
    mov     [rdi + 0], rax

    mov     rax, [rsi + 8]
    add     rax, [rdx + 8]
    mov     [rdi + 8], rax

    mov     rax, [rsi + 16]
    add     rax, [rdx + 16]
    mov     [rdi + 16], rax

    mov     rax, [rsi + 24]
    add     rax, [rdx + 24]
    mov     [rdi + 24], rax

    mov     rax, [rsi + 32]
    add     rax, [rdx + 32]
    mov     [rdi + 32], rax

    jmp     _fe_normalize

; ==================================================================
; _fe_sub(out, a, b)
; out = a - b mod p
; Constant-time: computes a + 2p - b, then normalizes.
;
; p = 2^255 - 19
; radix-51 p limbs:
;   p0 = 2^51 - 19
;   p1..p4 = 2^51 - 1
; ==================================================================
_fe_sub:
    ; c0 = 2p0 = 2^52 - 38
    mov     r10d, 1
    shl     r10, 52
    sub     r10, 38

    mov     rax, [rsi + 0]
    add     rax, r10
    sub     rax, [rdx + 0]
    mov     [rdi + 0], rax

    ; c = 2p_high = 2^52 - 2
    mov     r10d, 1
    shl     r10, 52
    sub     r10, 2

    mov     rax, [rsi + 8]
    add     rax, r10
    sub     rax, [rdx + 8]
    mov     [rdi + 8], rax

    mov     rax, [rsi + 16]
    add     rax, r10
    sub     rax, [rdx + 16]
    mov     [rdi + 16], rax

    mov     rax, [rsi + 24]
    add     rax, r10
    sub     rax, [rdx + 24]
    mov     [rdi + 24], rax

    mov     rax, [rsi + 32]
    add     rax, r10
    sub     rax, [rdx + 32]
    mov     [rdi + 32], rax

    jmp     _fe_normalize

; ==================================================================
; _fe_mul(out, a, b)
; 5×51 Curve25519 multiplication.
;
; c0 = a0*b0 + 19*(a1*b4 + a2*b3 + a3*b2 + a4*b1)
; c1 = a0*b1 + a1*b0 + 19*(a2*b4 + a3*b3 + a4*b2)
; c2 = a0*b2 + a1*b1 + a2*b0 + 19*(a3*b4 + a4*b3)
; c3 = a0*b3 + a1*b2 + a2*b1 + a3*b0 + 19*(a4*b4)
; c4 = a0*b4 + a1*b3 + a2*b2 + a3*b1 + a4*b0
;
; Each cN is 128-bit on stack: lo,hi.
; ==================================================================
_fe_mul:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; out
    mov     r13, rsi        ; a
    mov     r14, rdx        ; b

    ; 5 coefficients × 16 bytes = 80 bytes
    sub     rsp, 80

    xor     eax, eax
    mov     [rsp + 0],  rax
    mov     [rsp + 8],  rax
    mov     [rsp + 16], rax
    mov     [rsp + 24], rax
    mov     [rsp + 32], rax
    mov     [rsp + 40], rax
    mov     [rsp + 48], rax
    mov     [rsp + 56], rax
    mov     [rsp + 64], rax
    mov     [rsp + 72], rax

%macro ADDMUL 4
    ; ADDMUL coeff_offset, a_offset, b_offset, mul19
    mov     rax, [r13 + %2]
    mov     rbx, [r14 + %3]
%if %4 = 1
    imul    rbx, rbx, 19
%endif
    mul     rbx
    add     qword [rsp + %1], rax
    adc     qword [rsp + %1 + 8], rdx
%endmacro

    ; c0
    ADDMUL 0,  0,  0, 0
    ADDMUL 0,  8, 32, 1
    ADDMUL 0, 16, 24, 1
    ADDMUL 0, 24, 16, 1
    ADDMUL 0, 32,  8, 1

    ; c1
    ADDMUL 16,  0,  8, 0
    ADDMUL 16,  8,  0, 0
    ADDMUL 16, 16, 32, 1
    ADDMUL 16, 24, 24, 1
    ADDMUL 16, 32, 16, 1

    ; c2
    ADDMUL 32,  0, 16, 0
    ADDMUL 32,  8,  8, 0
    ADDMUL 32, 16,  0, 0
    ADDMUL 32, 24, 32, 1
    ADDMUL 32, 32, 24, 1

    ; c3
    ADDMUL 48,  0, 24, 0
    ADDMUL 48,  8, 16, 0
    ADDMUL 48, 16,  8, 0
    ADDMUL 48, 24,  0, 0
    ADDMUL 48, 32, 32, 1

    ; c4
    ADDMUL 64,  0, 32, 0
    ADDMUL 64,  8, 24, 0
    ADDMUL 64, 16, 16, 0
    ADDMUL 64, 24,  8, 0
    ADDMUL 64, 32,  0, 0

%undef ADDMUL

    ; mask51
    mov     r11d, 1
    shl     r11, 51
    dec     r11

    xor     r10, r10        ; carry

%macro REDUCE_COEFF 2
    ; REDUCE_COEFF coeff_offset, limb_store_offset
    mov     rax, [rsp + %1]
    mov     rdx, [rsp + %1 + 8]

    add     rax, r10
    adc     rdx, 0

    mov     r10, rax
    shr     r10, 51

    mov     r15, rdx
    shl     r15, 13
    or      r10, r15

    and     rax, r11
    mov     [rsp + %2], rax
%endmacro

    REDUCE_COEFF 0,  0
    REDUCE_COEFF 16, 8
    REDUCE_COEFF 32, 16
    REDUCE_COEFF 48, 24
    REDUCE_COEFF 64, 32

%undef REDUCE_COEFF

    ; carry from limb4 wraps as carry*19 into limb0
    imul    r10, r10, 19
    add     [rsp + 0], r10

    ; copy limbs to output
    mov     rax, [rsp + 0]
    mov     [r12 + 0], rax
    mov     rax, [rsp + 8]
    mov     [r12 + 8], rax
    mov     rax, [rsp + 16]
    mov     [r12 + 16], rax
    mov     rax, [rsp + 24]
    mov     [r12 + 24], rax
    mov     rax, [rsp + 32]
    mov     [r12 + 32], rax

    ; normalize output
    mov     rdi, r12
    call    _fe_normalize

    add     rsp, 80

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _fe_square(void *out, const void *a) — out = a^2
; ==================================================================
_fe_square:
    mov     rdx, rsi
    jmp     _fe_mul

; ==================================================================
; _fe_sq — alias for backward compat
; ==================================================================
_fe_sq:
    jmp     _fe_square

; ==================================================================
; _fe_mul121665(out, a)
; out = a * 121665 mod p
; ==================================================================
_fe_mul121665:
    mov     r8, rdi         ; out
    xor     r10, r10        ; carry
    mov     r11d, 1
    shl     r11, 51
    dec     r11             ; mask51

%macro MUL_CONST_LIMB 1
    mov     rax, [rsi + %1]
    mov     edx, 121665
    mul     rdx

    add     rax, r10
    adc     rdx, 0

    mov     r10, rax
    shr     r10, 51

    mov     r9, rdx
    shl     r9, 13
    or      r10, r9

    and     rax, r11
    mov     [r8 + %1], rax
%endmacro

    MUL_CONST_LIMB 0
    MUL_CONST_LIMB 8
    MUL_CONST_LIMB 16
    MUL_CONST_LIMB 24
    MUL_CONST_LIMB 32

%undef MUL_CONST_LIMB

    imul    r10, r10, 19
    add     [r8 + 0], r10

    mov     rdi, r8
    jmp     _fe_normalize

; ==================================================================
; _fe_frombytes(void *out, const u8 in[32])
; Decode 32-byte little-endian to 5×51 limbs.
; ==================================================================
_fe_frombytes:
    push    rbx
    mov     ebx, 1
    shl     rbx, 51
    dec     rbx                     ; rbx = 2^51-1 = mask51

    mov     rax, [rsi]
    and     rax, rbx
    mov     [rdi], rax

    mov     rax, [rsi + 6]
    shr     rax, 3
    and     rax, rbx
    mov     [rdi + 8], rax

    mov     rax, [rsi + 12]
    shr     rax, 6
    and     rax, rbx
    mov     [rdi + 16], rax

    mov     rax, [rsi + 19]
    shr     rax, 1
    and     rax, rbx
    mov     [rdi + 24], rax

    mov     rax, [rsi + 24]
    shr     rax, 12
    and     rax, rbx
    mov     [rdi + 32], rax

    ; Canonical reduction: add 19 if bit 255 was set (2^255 ≡ 19 mod p)
    mov     rax, [rsi + 24]
    shr     rax, 63
    imul    rax, rax, 19
    add     [rdi], rax

    pop     rbx
    ret

; ==================================================================
; _fe_tobytes(out[32], in)
; Canonical little-endian encoding.
;
; Computes x normalized.
; Computes y = x + 19.
; If y carries past bit255, x >= p, so encode y with carry dropped.
; Otherwise encode x.
; ==================================================================
_fe_tobytes:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; out
    mov     r13, rsi        ; in

    ; stack:
    ; x[5] = 40 bytes
    ; y[5] = 40 bytes
    ; totals 80 — keeps rsp 16-byte aligned after 5 pushes
    sub     rsp, 80

    ; copy x
    mov     rax, [r13 + 0]
    mov     [rsp + 0], rax
    mov     rax, [r13 + 8]
    mov     [rsp + 8], rax
    mov     rax, [r13 + 16]
    mov     [rsp + 16], rax
    mov     rax, [r13 + 24]
    mov     [rsp + 24], rax
    mov     rax, [r13 + 32]
    mov     [rsp + 32], rax

    ; normalize x
    mov     rdi, rsp
    call    _fe_normalize

    ; y = x
    mov     rax, [rsp + 0]
    mov     [rsp + 40], rax
    mov     rax, [rsp + 8]
    mov     [rsp + 48], rax
    mov     rax, [rsp + 16]
    mov     [rsp + 56], rax
    mov     rax, [rsp + 24]
    mov     [rsp + 64], rax
    mov     rax, [rsp + 32]
    mov     [rsp + 72], rax

    ; mask51
    mov     r11d, 1
    shl     r11, 51
    dec     r11

    ; y += 19 and carry through 5 limbs
    add     qword [rsp + 40], 19

    mov     rax, [rsp + 40]
    mov     r10, rax
    shr     r10, 51
    and     rax, r11
    mov     [rsp + 40], rax
    add     [rsp + 48], r10

    mov     rax, [rsp + 48]
    mov     r10, rax
    shr     r10, 51
    and     rax, r11
    mov     [rsp + 48], rax
    add     [rsp + 56], r10

    mov     rax, [rsp + 56]
    mov     r10, rax
    shr     r10, 51
    and     rax, r11
    mov     [rsp + 56], rax
    add     [rsp + 64], r10

    mov     rax, [rsp + 64]
    mov     r10, rax
    shr     r10, 51
    and     rax, r11
    mov     [rsp + 64], rax
    add     [rsp + 72], r10

    mov     rax, [rsp + 72]
    mov     r10, rax
    shr     r10, 51          ; q = carry past bit255
    and     rax, r11
    mov     [rsp + 72], rax

    ; select y if q=1 else x
    ; mask = -q
    neg     r10
    mov     r14, r10
    not     r14              ; inverse mask

%macro SELECT_LIMB 1
    mov     rax, [rsp + %1]          ; x
    mov     rbx, [rsp + 40 + %1]     ; y
    and     rax, r14
    and     rbx, r10
    or      rax, rbx
    mov     [rsp + %1], rax
%endmacro

    SELECT_LIMB 0
    SELECT_LIMB 8
    SELECT_LIMB 16
    SELECT_LIMB 24
    SELECT_LIMB 32

%undef SELECT_LIMB

    ; pack x limbs to 32-byte little-endian
    mov     rax, [rsp + 0]
    mov     rdx, [rsp + 8]
    shl     rdx, 51
    or      rax, rdx
    mov     [r12 + 0], rax

    mov     rax, [rsp + 8]
    shr     rax, 13
    mov     rdx, [rsp + 16]
    shl     rdx, 38
    or      rax, rdx
    mov     [r12 + 8], rax

    mov     rax, [rsp + 16]
    shr     rax, 26
    mov     rdx, [rsp + 24]
    shl     rdx, 25
    or      rax, rdx
    mov     [r12 + 16], rax

    mov     rax, [rsp + 24]
    shr     rax, 39
    mov     rdx, [rsp + 32]
    shl     rdx, 12
    or      rax, rdx
    mov     [r12 + 24], rax

    add     rsp, 80

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _fe_cswap(void *a, void *b, u64 swap)
; Constant-time conditional swap. swap=0 → no-op, swap=1 → swap.
; ==================================================================
_fe_cswap:
    neg     rdx                 ; 0→0, 1→0xFFFFFFFFFFFFFFFF
    mov     rcx, rdx

    mov     rax, [rdi]
    mov     rdx, [rsi]
    mov     r8,  rax
    xor     r8,  rdx
    and     r8,  rcx
    xor     rax, r8
    xor     rdx, r8
    mov     [rdi], rax
    mov     [rsi], rdx

    mov     rax, [rdi + 8]
    mov     rdx, [rsi + 8]
    mov     r8,  rax
    xor     r8,  rdx
    and     r8,  rcx
    xor     rax, r8
    xor     rdx, r8
    mov     [rdi + 8], rax
    mov     [rsi + 8], rdx

    mov     rax, [rdi + 16]
    mov     rdx, [rsi + 16]
    mov     r8,  rax
    xor     r8,  rdx
    and     r8,  rcx
    xor     rax, r8
    xor     rdx, r8
    mov     [rdi + 16], rax
    mov     [rsi + 16], rdx

    mov     rax, [rdi + 24]
    mov     rdx, [rsi + 24]
    mov     r8,  rax
    xor     r8,  rdx
    and     r8,  rcx
    xor     rax, r8
    xor     rdx, r8
    mov     [rdi + 24], rax
    mov     [rsi + 24], rdx

    mov     rax, [rdi + 32]
    mov     rdx, [rsi + 32]
    mov     r8,  rax
    xor     r8,  rdx
    and     r8,  rcx
    xor     rax, r8
    xor     rdx, r8
    mov     [rdi + 32], rax
    mov     [rsi + 32], rdx

    ret

; ==================================================================
; _fe_invert(void *out, const void *z)
; out = z^(2^255 - 21) mod (2^255-19)
; Uses standard addition-chain exponentiation.
; fe size = 40 bytes, stack allocs use 48-byte spacing for alignment.
; ==================================================================
_fe_invert:
    push    rbp
    mov     rbp, rsp

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; out
    mov     r13, rsi        ; z

    ; t0,t1,t2,t3 = 4 × 48 = 192 bytes + 8 for alignment
    sub     rsp, 200

    %define t0 rsp
    %define t1 rsp+48
    %define t2 rsp+96
    %define t3 rsp+144

    ; t0 = z^2
    lea     rdi, [t0]
    mov     rsi, r13
    call    _fe_square

    ; t1 = z^4  (t0^2)
    lea     rdi, [t1]
    lea     rsi, [t0]
    call    _fe_square

    ; t1 = z^8  (t1^2)
    lea     rdi, [t1]
    lea     rsi, [t1]
    call    _fe_square

    ; t1 = z^9 = z^8 * z
    lea     rdi, [t1]
    lea     rsi, [t1]
    mov     rdx, r13
    call    _fe_mul

    ; t0 = z^11 = z^2 * z^9
    lea     rdi, [t0]
    lea     rsi, [t0]
    lea     rdx, [t1]
    call    _fe_mul

    ; t2 = z^22 = (z^11)^2  (preserve t0 = z^11)
    lea     rdi, [t2]
    lea     rsi, [t0]
    call    _fe_square

    ; t1 = z^31 = z^9 * z^22 (z^(2^5 - 2^0))
    lea     rdi, [t1]
    lea     rsi, [t1]
    lea     rdx, [t2]
    call    _fe_mul

    ; t2 = z^(2^10 - 2^5) = (z^31)^2^5
    lea     rdi, [t2]
    lea     rsi, [t1]
    call    _fe_square
    mov     r14d, 4
.inv_loop_5_10:
    lea     rdi, [t2]
    lea     rsi, [t2]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_5_10

    ; t1 = z^(2^10 - 2^0) = t2 * t1
    lea     rdi, [t1]
    lea     rsi, [t2]
    lea     rdx, [t1]
    call    _fe_mul

    ; t2 = z^(2^20 - 2^10) = (t1)^2^10
    lea     rdi, [t2]
    lea     rsi, [t1]
    call    _fe_square
    mov     r14d, 9
.inv_loop_10_20:
    lea     rdi, [t2]
    lea     rsi, [t2]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_10_20

    ; t2 = z^(2^20 - 2^0) = t2 * t1
    lea     rdi, [t2]
    lea     rsi, [t2]
    lea     rdx, [t1]
    call    _fe_mul

    ; t3 = z^(2^40 - 2^20) = (t2)^2^20
    lea     rdi, [t3]
    lea     rsi, [t2]
    call    _fe_square
    mov     r14d, 19
.inv_loop_20_40:
    lea     rdi, [t3]
    lea     rsi, [t3]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_20_40

    ; t3 = z^(2^40 - 2^0) = t3 * t2
    lea     rdi, [t3]
    lea     rsi, [t3]
    lea     rdx, [t2]
    call    _fe_mul

    ; square 10 times: t3 = z^(2^50 - 2^10)
    lea     rdi, [t3]
    lea     rsi, [t3]
    call    _fe_square
    mov     r14d, 9
.inv_loop_40_50:
    lea     rdi, [t3]
    lea     rsi, [t3]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_40_50

    ; t1 = z^(2^50 - 2^0) = t3 * t1
    lea     rdi, [t1]
    lea     rsi, [t3]
    lea     rdx, [t1]
    call    _fe_mul

    ; t2 = z^(2^100 - 2^50) = (t1)^2^50
    lea     rdi, [t2]
    lea     rsi, [t1]
    call    _fe_square
    mov     r14d, 49
.inv_loop_50_100:
    lea     rdi, [t2]
    lea     rsi, [t2]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_50_100

    ; t2 = z^(2^100 - 2^0) = t2 * t1
    lea     rdi, [t2]
    lea     rsi, [t2]
    lea     rdx, [t1]
    call    _fe_mul

    ; t3 = z^(2^200 - 2^100) = (t2)^2^100
    lea     rdi, [t3]
    lea     rsi, [t2]
    call    _fe_square
    mov     r14d, 99
.inv_loop_100_200:
    lea     rdi, [t3]
    lea     rsi, [t3]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_100_200

    ; t3 = z^(2^200 - 2^0) = t3 * t2
    lea     rdi, [t3]
    lea     rsi, [t3]
    lea     rdx, [t2]
    call    _fe_mul

    ; square 50 times: t3 = z^(2^250 - 2^50)
    lea     rdi, [t3]
    lea     rsi, [t3]
    call    _fe_square
    mov     r14d, 49
.inv_loop_200_250:
    lea     rdi, [t3]
    lea     rsi, [t3]
    call    _fe_square
    dec     r14d
    jnz     .inv_loop_200_250

    ; t1 = z^(2^250 - 2^0) = t3 * t1
    lea     rdi, [t1]
    lea     rsi, [t3]
    lea     rdx, [t1]
    call    _fe_mul

    ; square 5 times: t1 = z^(2^255 - 2^5)
    lea     rdi, [t1]
    lea     rsi, [t1]
    call    _fe_square
    lea     rdi, [t1]
    lea     rsi, [t1]
    call    _fe_square
    lea     rdi, [t1]
    lea     rsi, [t1]
    call    _fe_square
    lea     rdi, [t1]
    lea     rsi, [t1]
    call    _fe_square
    lea     rdi, [t1]
    lea     rsi, [t1]
    call    _fe_square

    ; out = z^(2^255 - 21) = z^(2^255 - 2^5 + 11) = t1 * t0
    ; (t0 = z^11)
    mov     rdi, r12
    lea     rsi, [t1]
    lea     rdx, [t0]
    call    _fe_mul

    add     rsp, 200

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; _curve25519_ladder_step — Montgomery differential addition/doubling
;
; void _curve25519_ladder_step(
;     fe *x2, fe *z2, fe *x3, fe *z3, const fe *x1)
;
; rdi=x2, rsi=z2, rdx=x3, rcx=z3, r8=x1
; ==================================================================
_curve25519_ladder_step:
    push    rbp
    mov     rbp, rsp

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; x2
    mov     r13, rsi        ; z2
    mov     r14, rdx        ; x3
    mov     r15, rcx        ; z3
    mov     rbx, r8         ; x1

    ; 11 temps × 48 bytes = 528 + 8 alignment = 536, round to 552
    sub     rsp, 552

    %define A   rsp
    %define AA  rsp+48
    %define B   rsp+96
    %define BB  rsp+144
    %define E   rsp+192
    %define C   rsp+240
    %define D   rsp+288
    %define DA  rsp+336
    %define CB  rsp+384
    %define T0  rsp+432
    %define T1  rsp+480

    ; A = x2 + z2
    lea     rdi, [A]
    mov     rsi, r12
    mov     rdx, r13
    call    _fe_add

    ; AA = A^2
    lea     rdi, [AA]
    lea     rsi, [A]
    call    _fe_square

    ; B = x2 - z2
    lea     rdi, [B]
    mov     rsi, r12
    mov     rdx, r13
    call    _fe_sub

    ; BB = B^2
    lea     rdi, [BB]
    lea     rsi, [B]
    call    _fe_square

    ; E = AA - BB
    lea     rdi, [E]
    lea     rsi, [AA]
    lea     rdx, [BB]
    call    _fe_sub

    ; C = x3 + z3
    lea     rdi, [C]
    mov     rsi, r14
    mov     rdx, r15
    call    _fe_add

    ; D = x3 - z3
    lea     rdi, [D]
    mov     rsi, r14
    mov     rdx, r15
    call    _fe_sub

    ; DA = D * A
    lea     rdi, [DA]
    lea     rsi, [D]
    lea     rdx, [A]
    call    _fe_mul

    ; CB = C * B
    lea     rdi, [CB]
    lea     rsi, [C]
    lea     rdx, [B]
    call    _fe_mul

    ; T0 = DA + CB
    lea     rdi, [T0]
    lea     rsi, [DA]
    lea     rdx, [CB]
    call    _fe_add

    ; x3 = T0^2
    mov     rdi, r14
    lea     rsi, [T0]
    call    _fe_square

    ; T1 = DA - CB
    lea     rdi, [T1]
    lea     rsi, [DA]
    lea     rdx, [CB]
    call    _fe_sub

    ; T1 = T1^2
    lea     rdi, [T1]
    lea     rsi, [T1]
    call    _fe_square

    ; z3 = x1 * T1
    mov     rdi, r15
    mov     rsi, rbx
    lea     rdx, [T1]
    call    _fe_mul

    ; x2 = AA * BB
    mov     rdi, r12
    lea     rsi, [AA]
    lea     rdx, [BB]
    call    _fe_mul

    ; T0 = a24 * E  (via _fe_mul121665)
    lea     rdi, [T0]
    lea     rsi, [E]
    call    _fe_mul121665

    ; T0 = AA + T0
    lea     rdi, [T0]
    lea     rsi, [AA]
    lea     rdx, [T0]
    call    _fe_add

    ; z2 = E * T0
    mov     rdi, r13
    lea     rsi, [E]
    lea     rdx, [T0]
    call    _fe_mul

    add     rsp, 552

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; er_tor_curve25519_scalar_mult
;
; void er_tor_curve25519_scalar_mult(
;     u8 out[32], const u8 scalar[32], const u8 point[32])
;
; RFC 7748 Montgomery ladder. Clamps scalar, imports point,
; runs 255-bit ladder, inverts, exports.
; ==================================================================
er_tor_curve25519_scalar_mult:
    push    rbp
    mov     rbp, rsp

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; out
    mov     r13, rsi        ; scalar
    mov     r14, rdx        ; point

    ; Stack layout:
    ;   scalar copy: 32 bytes
    ;   X1..TMP: 7 field elements × 48 bytes = 336
    ;   BITTMP: 4 bytes
    ;   total: 372, rounded to 424
    sub     rsp, 424

    %define SCALAR rsp
    %define X1     rsp+48
    %define X2     rsp+96
    %define Z2     rsp+144
    %define X3     rsp+192
    %define Z3     rsp+240
    %define Z2INV  rsp+288
    %define TMP    rsp+336
    %define BITTMP rsp+384

    ; Copy scalar to local stack
    lea     rdi, [SCALAR]
    mov     rsi, r13
    mov     edx, 32
    call    er_memcpy

    ; Clamp scalar
    and     byte [SCALAR], 248
    and     byte [SCALAR + 31], 127
    or      byte [SCALAR + 31], 64

    ; X1 = point (u-coordinate)
    lea     rdi, [X1]
    mov     rsi, r14
    call    _fe_frombytes

    ; X2 = 1
    lea     rdi, [X2]
    call    _fe_1

    ; Z2 = 0
    xor     eax, eax
    mov     [Z2], rax
    mov     [Z2 + 8], rax
    mov     [Z2 + 16], rax
    mov     [Z2 + 24], rax
    mov     [Z2 + 32], rax

    ; X3 = X1
    lea     rdi, [X3]
    lea     rsi, [X1]
    call    _fe_copy

    ; Z3 = 1
    lea     rdi, [Z3]
    call    _fe_1

    xor     r15d, r15d      ; swap flag = 0
    mov     ebx, 254        ; bit index

.scalar_loop:
    ; bit = (scalar[byte >> 3] >> (byte & 7)) & 1
    mov     eax, ebx
    shr     eax, 3
    movzx   eax, byte [SCALAR + rax]
    mov     ecx, ebx
    and     ecx, 7
    shr     eax, cl
    and     eax, 1

    ; swap ^= bit  (conditional swap decision)
    xor     r15d, eax
    mov     [BITTMP], eax      ; save bit to stack (ABI-safe across calls)

    ; cswap(X2, X3, swap)
    lea     rdi, [X2]
    lea     rsi, [X3]
    mov     edx, r15d
    call    _fe_cswap

    ; cswap(Z2, Z3, swap)
    lea     rdi, [Z2]
    lea     rsi, [Z3]
    mov     edx, r15d
    call    _fe_cswap

    ; swap = bit
    mov     r15d, [BITTMP]

    ; ladder_step(X2, Z2, X3, Z3, X1)
    lea     rdi, [X2]
    lea     rsi, [Z2]
    lea     rdx, [X3]
    lea     rcx, [Z3]
    lea     r8,  [X1]
    call    _curve25519_ladder_step

    dec     ebx
    jns     .scalar_loop

    ; Final cswap
    lea     rdi, [X2]
    lea     rsi, [X3]
    mov     edx, r15d
    call    _fe_cswap

    lea     rdi, [Z2]
    lea     rsi, [Z3]
    mov     edx, r15d
    call    _fe_cswap

    ; Z2INV = invert(Z2)
    lea     rdi, [Z2INV]
    lea     rsi, [Z2]
    call    _fe_invert

    ; X2 = X2 * Z2INV
    lea     rdi, [X2]
    lea     rsi, [X2]
    lea     rdx, [Z2INV]
    call    _fe_mul

    ; out = tobytes(X2)
    mov     rdi, r12
    lea     rsi, [X2]
    call    _fe_tobytes

    add     rsp, 424

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
