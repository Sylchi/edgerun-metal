; EdgeRun Tor AES self-hosted test runner — x86_64 assembly
; Tests AES-128-CTR with NIST known-answer vectors and roundtrip.
; No libc, no external dependencies beyond runtime.o. Exits via syscall.

%include "x86_64/macros.inc"

extern er_tor_aes_ctr
extern er_memcpy

SECTION .data
passed: dq 0
failed: dq 0

test_key: db 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6
          db 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c

test_iv:  db 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7
          db 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff

test_pt:  db 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96
          db 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a
          db 0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c
          db 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51
          db 0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11
          db 0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef
          db 0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17
          db 0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10

test_ct:  db 0x87, 0x4d, 0x61, 0x91, 0xb6, 0x20, 0xe3, 0x26
          db 0x1b, 0xef, 0x68, 0x64, 0x99, 0x0d, 0xb6, 0xce
          db 0x5d, 0xea, 0xc2, 0xde, 0x49, 0x33, 0xce, 0xf5
          db 0xf1, 0x9d, 0x09, 0xc6, 0x8f, 0xc3, 0x64, 0x84
          db 0x01, 0xed, 0x7d, 0x9a, 0x56, 0xc9, 0xa8, 0xd9
          db 0x57, 0x89, 0xb6, 0x0a, 0x64, 0x29, 0x7b, 0x6e
          db 0x83, 0x5d, 0x87, 0x7d, 0xde, 0xb1, 0x07, 0x50
          db 0x3d, 0x37, 0x4f, 0xca, 0x66, 0xff, 0xbc, 0xd4

SECTION .bss
buf:      resb 64
iv_copy:  resb 16

%macro ASSERT 1
    test    %1, %1
    jz      %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

%macro ASSERT_EQ 2
    cmp     %1, %2
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

SECTION .text
global _start
_start:

%macro TEST_LABEL 1
    jmp     %%done
%%str: db %1, 0
%%done:
    push    rcx
    push    r11
    push    rdi
    push    rsi
    push    rdx
    push    rax
    mov     rdi, 1
    lea     rsi, [rel %%str]
    mov     rdx, 2
    mov     rax, 1
    syscall
    pop     rax
    pop     rdx
    pop     rsi
    pop     rdi
    pop     r11
    pop     rcx
%endmacro

; ================================================================
; Test 1: AES-128-CTR encrypt — known-answer test
; NIST SP 800-38A test vector F.5.1 (64 bytes, key=2b...)
; ================================================================
    TEST_LABEL "1\n"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 64
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    lea     rsi, [rel buf]
    lea     rdi, [rel test_ct]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax
    ; Dump first 16 bytes of buf to stdout
    push    rax
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    mov     rdi, 1
    lea     rsi, [rel buf]
    mov     rdx, 16
    mov     rax, 1
    syscall
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rax

; ================================================================
; Test 2: AES-128-CTR roundtrip (decrypt = same operation in CTR)
; ================================================================
    TEST_LABEL "2\n"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 64
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel buf]
    mov     edx, 64
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    lea     rsi, [rel buf]
    lea     rdi, [rel test_pt]
    mov     edx, 64
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 3: Partial block (non-16-byte aligned length)
; ================================================================
    TEST_LABEL "3\n"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 7
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ; First 7 bytes should match known ciphertext
    lea     rsi, [rel buf]
    lea     rdi, [rel test_ct]
    mov     edx, 7
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 4: Empty length (should be no-op)
; ================================================================
    TEST_LABEL "4\n"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    xor     edx, edx
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ; IV should be unchanged (no blocks encrypted)
    lea     rsi, [rel iv_copy]
    lea     rdi, [rel test_iv]
    mov     edx, 16
    call    _mem_eq
    ASSERT eax

; ================================================================
; Test 5: Multi-block XOR (3 blocks = 48 bytes)
; ================================================================
    TEST_LABEL "5\n"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 48
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    lea     rsi, [rel buf]
    lea     rdi, [rel test_ct]
    mov     edx, 48
    call    _mem_eq
    ASSERT eax

; ================================================================
; Done — report results
; ================================================================
    mov     rax, [rel failed]
    test    rax, rax
    jnz     .exit_fail
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
