; EdgeRun 5×51 field multiplication test — x86_64 assembly
; Tests _fe_mul correctness with 5×51 limb representation (40 bytes/fe).
; Links against curve25519.o + runtime.o.

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
result:     resq 5      ; 5 limbs × 51 bits = 255 bits
expected:   resq 5

SECTION .data
; 5×51 limb field elements (40 bytes each)
; p = 2^255-19 = [2^51-19, 2^51-1, 2^51-1, 2^51-1, 2^51-1]
p0: equ 0x7FFFFFFFFFFED   ; 2^51 - 19
p1: equ 0x7FFFFFFFFFFFF   ; 2^51 - 1

nine:       dq 9, 0, 0, 0, 0
one:        dq 1, 0, 0, 0, 0
eighty_one: dq 81, 0, 0, 0, 0
p_minus_1:  dq p0-1, p1, p1, p1, p1      ; 2^255 - 20
p_minus_9:  dq p0-9, p1, p1, p1, p1      ; 2^255 - 28
p_plus_18:  dq p1, p1, p1, p1, p1        ; 2^255 - 1 (all 255 bits set)
fe_324:     dq 324, 0, 0, 0, 0

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
    mov     edx, 40
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
    mov     edx, 40
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
    mov     edx, 40
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 4: (p+18)^2 mod p = 324
; p+18 = 2^255 - 1 (all 5 limbs = 2^51-1)
; 2^255-1 ≡ 18 mod p, 18^2 = 324
; ================================================================
    lea     rdi, [rel result]
    lea     rsi, [rel p_plus_18]
    lea     rdx, [rel p_plus_18]
    call    _fe_mul

    lea     rdi, [rel result]
    lea     rsi, [rel fe_324]
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
