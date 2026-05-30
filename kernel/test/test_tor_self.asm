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
          db 0x98, 0x06, 0xf6, 0x6b, 0x79, 0x70, 0xfd, 0xff
          db 0x86, 0x17, 0x18, 0x7b, 0xb9, 0xff, 0xfd, 0xff
          db 0x5a, 0xe4, 0xdf, 0x3e, 0xdb, 0xd5, 0xd3, 0x5e
          db 0x5b, 0x4f, 0x09, 0x02, 0x0d, 0xb0, 0x3e, 0xab
          db 0x1e, 0x03, 0x1d, 0xda, 0x2f, 0xbe, 0x03, 0xd1
          db 0x79, 0x21, 0x70, 0xa0, 0xf3, 0x00, 0x9c, 0xee

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

; ================================================================
; Test 1: AES-128-CTR encrypt — known-answer test
; NIST SP 800-38A test vector F.5.1 (64 bytes, key=2b...)
; ================================================================
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

; ================================================================
; Test 2: AES-128-CTR roundtrip (decrypt = same operation in CTR)
; ================================================================
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
