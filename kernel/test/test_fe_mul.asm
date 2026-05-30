; EdgeRun _fe_mul field multiplication test — x86_64 assembly
; Tests raw 512-bit product correctness against known values.
; Links against tor_ntor.o + runtime.o.
; No libc, no external dependencies. Exits via syscall.

%include "x86_64/macros.inc"

extern _fe_mul

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
result:     resq 4      ; 4 limbs
expected:   resq 4

SECTION .data
nine:       dq 9, 0, 0, 0
one:        dq 1, 0, 0, 0
eighty_one: dq 81, 0, 0, 0
p_minus_1:  dq 0xFFFFFFFFFFFFFFEC, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
p_minus_9:  dq 0xFFFFFFFFFFFFFFE4, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
p_plus_18:  dq 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
inv9_correct: dq 0xc71c71c71c71c712, 0x1c71c71c71c71c71, 0x71c71c71c71c71c7, 0x471c71c71c71c71c
inv9_buggy:   dq 0xc71c71c71c71c6ff, 0x1c71c71c71c71c71, 0x71c71c71c71c71c7, 0xc71c71c71c71c71c
high_shift: dq 0, 0, 0, 1
fe_one:     dq 1, 0, 0, 0
fe_324:     dq 324, 0, 0, 0
fe_9_at_192: dq 0, 0, 0, 9

SECTION .text
global _start
_start:

; ================================================================
; Test 1: 9 * 1 = 9
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel nine]
    lea     rdx, [rel one]
    call    _fe_mul

    lea     rdi, [rel result]
    lea     rsi, [rel nine]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 2: 9 * 9 = 81
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel nine]
    lea     rdx, [rel nine]
    call    _fe_mul

    lea     rdi, [rel result]
    lea     rsi, [rel eighty_one]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 3: 9 * (p-1) = p - 9  (-9 mod p)
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel nine]
    lea     rdx, [rel p_minus_1]
    call    _fe_mul

    lea     rdi, [rel result]
    lea     rsi, [rel p_minus_9]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 4: (p+18)^2 mod p = 324
; p+18 = 2^255 - 1 = all limbs 0xFF..FF, top 0x7F..FF
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel p_plus_18]
    lea     rdx, [rel p_plus_18]
    call    _fe_mul

    lea     rdi, [rel result]
    lea     rsi, [rel fe_324]
    mov     edx, 32
    call    _mem_eq
    ASSERT eax

; ================================================================
; Debug: dump result limbs for test 4 via write(1, buf, 32)
; ================================================================
    lea     rsi, [rel result]
    mov     edx, 32
    mov     edi, 1
    mov     eax, 1
    syscall             ; write(1, result, 32)

    ; newline
    push    10
    mov     rsi, rsp
    mov     edx, 1
    mov     edi, 1
    mov     eax, 1
    syscall
    add     rsp, 8

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
