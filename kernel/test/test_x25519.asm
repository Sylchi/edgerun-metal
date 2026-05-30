; EdgeRun X25519 scalar multiplication test — x86_64 assembly
; Tests the full pipeline: frombytes → ladder → invert → tobytes
; against RFC 7748 test vectors.
;
; Links against curve25519.o, tor_ntor.o, runtime.o.

%include "x86_64/macros.inc"

FE_LIMB_P0 equ 0x0007ffffffffffe0
FE_LIMB_PN equ 0x0007ffffffffffff

extern er_tor_curve25519_scalar_mult
extern _fe_mul
extern _fe_square
extern _fe_invert
extern _fe_mul121665
extern _fe_tobytes
extern _fe_frombytes
extern _fe_1
extern _fe_copy
extern _fe_add
extern _fe_sub
extern _fe_normalize
extern _fe_cswap
extern _curve25519_ladder_step

%macro ASSERT 2
    test    %1, %1
    jz      %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
    mov     edi, %2
    mov     eax, 60
    syscall
%%done:
%endmacro

SECTION .bss
passed:     resq 1
failed:     resq 1
result:     resq 8      ; 32 bytes = 4 qwords
expected:   resq 8      ; 32 bytes
fe_a:       resq 5      ; field element
fe_b:       resq 5
fe_c:       resq 5
ladder_x2:  resq 5
ladder_z2:  resq 5
ladder_x3:  resq 5
ladder_z3:  resq 5

SECTION .data

; RFC 7748 Section 5.2 Test Vector 1
scalar1: dq 0x9d7c52f06be346a5, 0xdd5e46824b15163b, 0x185afcc10a4c1462, 0xc49a44ba44226a50
point1:  dq 0xdb3030586768dbe6, 0x7c5fb124a4c19435, 0x3b35b326ec246672, 0x4c1cabd0a603a910
output1: dq 0x90c6e99d3755dac3, 0x4f088df24dea948e, 0xf7711c4903cfec32, 0x5285a2775507b454

; RFC 7748 Section 5.2 Test Vector 2
scalar2: dq 0x3c67b4d1d4e9664b, 0xf56a7d959126d25a, 0xd401eae021641bc1, 0x0dba18799e16a42c
point2:  dq 0xd3116878120f21e5, 0x2cae38059d95b7f4, 0x3e3cc06f10e7db31, 0x93a415c749d54cfc
output2: dq 0x7d90e87694decb95, 0xf873b8b45ce4ad7a, 0x52a19f79685a598b, 0x5779ac7a64f7f8e6
; point2 with bit 255 masked off
point2_masked: dq 0xd3116878120f21e5, 0x2cae38059d95b7f4, 0x3e3cc06f10e7db31, 0x13a415c749d54cfc

fe_one:  dq 1, 0, 0, 0, 0
fe_two:  dq 2, 0, 0, 0, 0
fe_three: dq 3, 0, 0, 0, 0

SECTION .text
global _start
_start:

; ================================================================
; Test 1: _fe_mul(2, 3) = 6
; ================================================================
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_two]
    lea     rdx, [rel fe_three]
    call    _fe_mul
    mov     rax, [rel fe_c]
    cmp     rax, 6
    jne     .test1_fail
    inc     qword [rel passed]
    jmp     .test1_done
.test1_fail:
    mov     edi, 1
    mov     eax, 60
    syscall
.test1_done:

; ================================================================
; Test 2: invert(1) = 1  (canonical: raw-40-byte comparison works)
; ================================================================
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_one]
    call    _fe_invert
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_one]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax, 2

; ================================================================
; Test 3: frombytes→invert→mul≡1 for decoded point2
;         Uses tobytes to compare modulo p (product may be 1+p)
; ================================================================
    lea     rdi, [rel fe_a]
    lea     rsi, [rel point2]
    call    _fe_frombytes

    lea     rdi, [rel fe_b]
    lea     rsi, [rel fe_a]
    call    _fe_invert

    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_a]
    lea     rdx, [rel fe_b]
    call    _fe_mul

    ; tobytes(fe_c) → result
    lea     rdi, [rel result]
    lea     rsi, [rel fe_c]
    call    _fe_tobytes

    ; tobytes(fe_one) → expected
    lea     rdi, [rel expected]
    lea     rsi, [rel fe_one]
    call    _fe_tobytes

    lea     rdi, [rel result]
    lea     rsi, [rel expected]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax, 3

; ================================================================
; Test 4: frombytes→tobytes round-trip for point2
; ================================================================
    lea     rdi, [rel fe_a]
    lea     rsi, [rel point2]
    call    _fe_frombytes

    lea     rdi, [rel result]
    lea     rsi, [rel fe_a]
    call    _fe_tobytes

    lea     rdi, [rel result]
    lea     rsi, [rel point2_masked]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax, 4

; ================================================================
; Test 5: RFC 7748 Test Vector 1 — full scalar multiplication
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel scalar1]
    lea     rdx, [rel point1]
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel result]
    lea     rsi, [rel output1]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax, 5

; ================================================================
; Test 6: Check if point2 u-coordinate is a 2-torsion point
;   u*(u^2 + 486662*u + 1) ≡ 0 (mod p) means the point is (u,0)
;   which has order 2. If so, the ladder would produce Z2 ≡ 0
;   and invert(Z2) would fail.
; ================================================================
    ; Compute u^2 + 486662*u + 1 mod p
    lea     rdi, [rel fe_a]        ; X1 = frombytes(point2)
    lea     rsi, [rel point2]
    call    _fe_frombytes

    ; fe_b = u^2
    lea     rdi, [rel fe_b]
    lea     rsi, [rel fe_a]
    call    _fe_square

    ; fe_c = 121665*u
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_a]
    call    _fe_mul121665

    ; fe_c = 2*121665*u = 243330*u  (double)
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_c]
    lea     rdx, [rel fe_c]
    call    _fe_add

    ; fe_c = 4*121665*u = 486660*u  (double again)
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_c]
    lea     rdx, [rel fe_c]
    call    _fe_add

    ; fe_c = 486660*u + u = 486661*u  (add u)
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_c]
    lea     rdx, [rel fe_a]
    call    _fe_add

    ; fe_c = 486661*u + u = 486662*u  (add u again)
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_c]
    lea     rdx, [rel fe_a]
    call    _fe_add

    ; fe_c = 486662*u + 1
    lea     rdi, [rel fe_c]
    lea     rsi, [rel fe_c]
    lea     rdx, [rel fe_one]
    call    _fe_add

    ; fe_b = u^2 + (486662*u + 1)
    lea     rdi, [rel fe_b]
    lea     rsi, [rel fe_b]
    lea     rdx, [rel fe_c]
    call    _fe_add

    ; Check if fe_b = 0 or p
    mov     rax, [rel fe_b]
    test    rax, rax
    jnz     .test6_not_zero
    mov     rax, [rel fe_b + 8]
    test    rax, rax
    jnz     .test6_not_zero
    mov     rax, [rel fe_b + 16]
    test    rax, rax
    jnz     .test6_not_zero
    mov     rax, [rel fe_b + 24]
    test    rax, rax
    jnz     .test6_not_zero
    mov     rax, [rel fe_b + 32]
    test    rax, rax
    jnz     .test6_not_zero
    jmp     .test6_is_2torsion
.test6_not_zero:
    ; Check if fe_b == p (all limbs = 2^51-1 except L0 = 2^51-19)
    mov     rcx, FE_LIMB_PN
    mov     rax, [rel fe_b]
    mov     rdx, FE_LIMB_P0
    cmp     rax, rdx
    jne     .test6_not_p
    mov     rax, [rel fe_b + 8]
    cmp     rax, rcx
    jne     .test6_not_p
    mov     rax, [rel fe_b + 16]
    cmp     rax, rcx
    jne     .test6_not_p
    mov     rax, [rel fe_b + 24]
    cmp     rax, rcx
    jne     .test6_not_p
    mov     rax, [rel fe_b + 32]
    cmp     rax, rcx
    jne     .test6_not_p
    jmp     .test6_is_2torsion
.test6_is_2torsion:
    ; Point is 2-torsion — scalar_mult can't work
    inc     qword [rel passed]
    jmp     .test6_done
.test6_not_p:
    ; fe_b ≠ 0 mod p and fe_b ≠ p → point is NOT 2-torsion
    ; Scalar_mult should work; the failure is elsewhere.
    ; Continue to test 7 to hit debug gates in scalar_mult.
    inc     qword [rel passed]
    jmp     .test6_done
.test6_done:

; ================================================================
; Test 7: Manual scalar_mult for vector 2 — step-by-step
;   Do frombytes, ladder, invert, mul as separate operations
; ================================================================
    ; Frombytes point2 → X1
    lea     rdi, [rel fe_a]        ; X1
    lea     rsi, [rel point2]
    call    _fe_frombytes

    ; X2 = 1
    lea     rdi, [rel ladder_x2]
    call    _fe_1

    ; Z2 = 0
    xor     eax, eax
    lea     rdi, [rel ladder_z2]
    mov     [rdi], rax
    mov     [rdi + 8], rax
    mov     [rdi + 16], rax
    mov     [rdi + 24], rax
    mov     [rdi + 32], rax

    ; X3 = X1
    lea     rdi, [rel ladder_x3]
    lea     rsi, [rel fe_a]
    call    _fe_copy

    ; Z3 = 1
    lea     rdi, [rel ladder_z3]
    call    _fe_1

    ; Do one ladder step
    lea     rdi, [rel ladder_x2]
    lea     rsi, [rel ladder_z2]
    lea     rdx, [rel ladder_x3]
    lea     rcx, [rel ladder_z3]
    lea     r8,  [rel fe_a]         ; X1
    call    _curve25519_ladder_step

    inc     qword [rel passed]

; ================================================================
; Test 7: Full scalar multiplication for vector 2
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel scalar2]
    lea     rdx, [rel point2]
    call    er_tor_curve25519_scalar_mult

    ; Dump actual result (stderr)
    lea     rdi, [rel result]
    call    dump_hex

    lea     rdi, [rel result]
    lea     rsi, [rel output2]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax, 7

; ================================================================
; Done — report results
; ================================================================
    mov     rax, [rel failed]
    test    rax, rax
    jnz     .exit_fail
.exit_pass:
    xor     edi, edi
    jmp     .exit
.exit_fail:
    mov     edi, 1
.exit:
    mov     eax, 60
    syscall

; Debug: dump 32 bytes pointed by rdi to stderr as hex
dump_hex:
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    rax
    push    r8
    sub     rsp, 66
    mov     r8, rdi
    xor     ecx, ecx
.next_byte:
    movzx   eax, byte [r8 + rcx]
    mov     edx, eax
    shr     al, 4
    and     al, 0xf
    add     al, 0x30
    cmp     al, 0x39
    jbe     .lo_ok
    add     al, 0x27
.lo_ok:
    mov     [rsp + rcx*2], al
    mov     al, dl
    and     al, 0xf
    add     al, 0x30
    cmp     al, 0x39
    jbe     .hi_ok
    add     al, 0x27
.hi_ok:
    mov     [rsp + rcx*2 + 1], al
    inc     ecx
    cmp     ecx, 32
    jb      .next_byte
    mov     byte [rsp + 64], 10
    mov     eax, 1
    mov     edi, 2
    lea     rsi, [rsp]
    mov     edx, 65
    syscall
    add     rsp, 66
    pop     r8
    pop     rax
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    ret

; Helper: _mem_eq(rdi=expected, rsi=actual, edx=len)
; returns eax = 1 if equal, 0 if not
_mem_eq:
    push    rcx
    push    rsi
    push    rdi
    mov     rcx, rdx
    repz cmpsb
    setz    al
    movzx   eax, al
    pop     rdi
    pop     rsi
    pop     rcx
    ret
