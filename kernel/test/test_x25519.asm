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
extern _fe_add
extern _fe_sub
extern _fe_cswap
extern _curve25519_ladder_step

%macro ASSERT 2
    test    %1, %1
    jnz     %%pass
    inc     qword [rel failed]
    jmp     %%done
%%pass:
    inc     qword [rel passed]
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
ladder_x1:  resq 5

SECTION .data

; RFC 7748 Section 6.1 Test Vector 1
scalar1: dq 0xc49a44ba44226a50, 0x185afcc10a4c1462, 0xdd5e46824b15163b, 0x9d7c52f06be346a5
point1:  dq 0x4c1cabd0a603a910, 0x3b35b326ec246672, 0x7c5fb124a4c19435, 0xe6db6867583030db
output1: dq 0x90c6e99d3755dac3, 0x4f088df24dea948e, 0xf7711c4903cfec32, 0x5285a2775507b454

; RFC 7748 Section 6.1 Test Vector 2
scalar2: dq 0x0dba18799e16a42c, 0xd401eae021641bc1, 0xf56a7d959126d25a, 0x3c67b4d1d4e9664b
point2:  dq 0x93a415c749d54cfc, 0x3e3cc06f10e7db31, 0x2cae38059d95b7f4, 0xd3116878120f21e5
output2: dq 0xa4a9d29f28fda99c, 0xe259525afaa4a6fa, 0x722e27e7393e45be, 0x0767b8c3a7df13f1

fe_one:  dq 1, 0, 0, 0, 0
fe_two:  dq 2, 0, 0, 0, 0
nine:    dq 9, 0, 0, 0, 0
fe_324:  dq 0x144, 0, 0, 0, 0
fe_36:   dq 0x24, 0, 0, 0, 0
fe_6400: dq 0x1900, 0, 0, 0, 0
fe_z2_expected: dq 0x9660720, 0, 0, 0, 0

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
    call    dump_hex

    lea     rdi, [rel result]
    lea     rsi, [rel output1]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax, 1

; ================================================================
; Test 2: RFC 7748 Test Vector 2 — full scalar multiplication
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel scalar2]
    lea     rdx, [rel point2]
    call    er_tor_curve25519_scalar_mult

    lea     rdi, [rel result]
    call    dump_hex

    lea     rdi, [rel result]
    lea     rsi, [rel output2]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax, 2

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
    ASSERT eax, 3

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
    ASSERT eax, 4

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
    ASSERT eax, 5

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
    ASSERT eax, 6

; ================================================================
; Test 7: One Montgomery ladder step (X1=9, scalar bit=1)
; Expect: x2=6400, z2=157681440, x3=324, z3=36
; ================================================================
    ; post-cswap state for first iteration with bit=1:
    ; x2 = 9, z2 = 1, x3 = 1, z3 = 0
    lea     rdi, [rel ladder_x2]
    lea     rsi, [rel nine]
    call    _fe_copy

    lea     rdi, [rel ladder_z2]
    lea     rsi, [rel fe_one]
    call    _fe_copy

    lea     rdi, [rel ladder_x3]
    lea     rsi, [rel fe_one]
    call    _fe_copy

    xor     eax, eax
    lea     rdi, [rel ladder_z3]
    mov     [rdi], rax
    mov     [rdi + 8], rax
    mov     [rdi + 16], rax
    mov     [rdi + 24], rax
    mov     [rdi + 32], rax

    lea     rdi, [rel ladder_x1]
    lea     rsi, [rel nine]
    call    _fe_copy

    lea     rdi, [rel ladder_x2]
    lea     rsi, [rel ladder_z2]
    lea     rdx, [rel ladder_x3]
    lea     rcx, [rel ladder_z3]
    lea     r8,  [rel ladder_x1]
    call    _curve25519_ladder_step

    lea     rdi, [rel ladder_x3]
    lea     rsi, [rel fe_324]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax, 7

    lea     rdi, [rel ladder_z3]
    lea     rsi, [rel fe_36]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax, 8

    lea     rdi, [rel ladder_x2]
    lea     rsi, [rel fe_6400]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax, 9

    lea     rdi, [rel ladder_z2]
    lea     rsi, [rel fe_z2_expected]
    mov     edx, 40
    call    _mem_eq
    ASSERT eax, 10

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
