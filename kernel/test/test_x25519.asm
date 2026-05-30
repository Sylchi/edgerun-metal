; EdgeRun X25519 scalar multiplication test — x86_64 assembly
; Tests the full pipeline: frombytes → ladder → invert → tobytes
; against RFC 7748 test vectors.
;
; Links against curve25519.o, tor_ntor.o, runtime.o.

%include "x86_64/macros.inc"

extern er_tor_curve25519_scalar_mult
extern _fe_mul
extern _fe_square
extern _fe_invert
extern _fe_tobytes
extern _fe_frombytes
extern _fe_1
extern _fe_copy

%macro ASSERT 1
    test    %1, %1
    jz      %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
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

SECTION .data

; RFC 7748 Section 6.1 Test Vector 1
scalar1: dq 0xc49a44ba44226a50, 0x185afcc10a4c1462, 0xdd5e46824b15163b, 0x9d7c52f06be346a5
point1:  dq 0x4c1cabd0a603a910, 0x3b35b326ec246672, 0x7c5fb124a4c19435, 0xdb3030586768dbe6
output1: dq 0x5285a2775507b454, 0xf7711c4903cfec32, 0x4f088df24dea948e, 0x90c6e99d3755dac3

; RFC 7748 Section 6.1 Test Vector 2
scalar2: dq 0x0dba18799e16a42c, 0xd401eae021641bc1, 0xf56a7d959126d25a, 0x3c67b4d1d4e9664b
point2:  dq 0x93a415c749d54cfc, 0x3e3cc06f10e7db31, 0x2cae38059d95b7f4, 0xd3116878120f21e5
output2: dq 0x5779ac7a64f7f8e6, 0x52a19f79685a598b, 0xf873b8b45ce4ad7a, 0x7d90e87694decb95

fe_one:  dq 1, 0, 0, 0, 0
fe_two:  dq 2, 0, 0, 0, 0
nine:    dq 9, 0, 0, 0, 0

SECTION .text
global _start
_start:

; ================================================================
; Test 1: RFC 7748 Test Vector 1 — full scalar multiplication
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel scalar1]
    lea     rdx, [rel point1]
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel result]
    lea     rsi, [rel output1]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 2: RFC 7748 Test Vector 2 — full scalar multiplication
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel scalar2]
    lea     rdx, [rel point2]
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel result]
    lea     rsi, [rel output2]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 3: frombytes(tobytes(x)) == x  (round-trip canonical)
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel fe_two]
    call    _fe_tobytes

    lea     rdi, [rel fe_a]
    lea     rsi, [rel result]
    call    _fe_frombytes

    lea     rdi, [rel fe_a]
    lea     rsi, [rel fe_two]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 4: mul(x, invert(x)) == 1 for x = 2
; ================================================================
    lea     rdi, [rel fe_a]
    lea     rsi, [rel fe_two]
    call    _fe_invert

    lea     rdi, [rel fe_b]
    lea     rsi, [rel fe_two]
    lea     rdx, [rel fe_a]
    call    _fe_mul

    lea     rdi, [rel fe_b]
    lea     rsi, [rel fe_one]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 5: square(x) == mul(x, x) for x = 9
; ================================================================
    lea     rdi, [rel fe_a]
    lea     rsi, [rel nine]
    call    _fe_square

    lea     rdi, [rel fe_b]
    lea     rsi, [rel nine]
    lea     rdx, [rel nine]
    call    _fe_mul

    lea     rdi, [rel fe_a]
    lea     rsi, [rel fe_b]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 6: mul(x, 1) == x for x = 9
; ================================================================
    lea     rdi, [rel fe_a]
    lea     rsi, [rel nine]
    lea     rdx, [rel fe_one]
    call    _fe_mul

    lea     rdi, [rel fe_a]
    lea     rsi, [rel nine]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax

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
