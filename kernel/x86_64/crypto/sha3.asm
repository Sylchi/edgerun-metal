; EdgeRun software SHA3-256 — one-shot Keccak-f[1600].
;
; Provides:
;   er_sha3_256(data, len, out[32])
;   er_shake256(data, len, out, out_len)

%include "x86_64/macros.inc"

%define SHA3_256_RATE 136
%define KECCAK_LANES 25
%define KECCAK_ROUNDS 24

SECTION .rodata
align 8
keccak_rc:
    dq 0x0000000000000001, 0x0000000000008082
    dq 0x800000000000808a, 0x8000000080008000
    dq 0x000000000000808b, 0x0000000080000001
    dq 0x8000000080008081, 0x8000000000008009
    dq 0x000000000000008a, 0x0000000000000088
    dq 0x0000000080008009, 0x000000008000000a
    dq 0x000000008000808b, 0x800000000000008b
    dq 0x8000000000008089, 0x8000000000008003
    dq 0x8000000000008002, 0x8000000000000080
    dq 0x000000000000800a, 0x800000008000000a
    dq 0x8000000080008081, 0x8000000000008080
    dq 0x0000000080000001, 0x8000000080008008

keccak_rho:
    db 0, 1, 62, 28, 27
    db 36, 44, 6, 55, 20
    db 3, 10, 43, 25, 39
    db 41, 45, 15, 21, 8
    db 18, 2, 61, 56, 14

keccak_pi:
    db 0, 10, 20, 5, 15
    db 16, 1, 11, 21, 6
    db 7, 17, 2, 12, 22
    db 23, 8, 18, 3, 13
    db 14, 24, 9, 19, 4

SECTION .bss
align 8
sha3_state: resq KECCAK_LANES
sha3_b: resq KECCAK_LANES
sha3_c: resq 5
sha3_d: resq 5
sha3_block: resb SHA3_256_RATE

SECTION .text

; _sha3_absorb_rate(rdi=block[136])
_sha3_absorb_rate:
    push    rbx
    push    r12
    xor     edx, edx
.absorb_byte:
    movzx   eax, byte [rdi + rdx]
    mov     ebx, edx
    and     ebx, 7
    shl     ebx, 3
    mov     r12, rax
    mov     cl, bl
    shl     r12, cl
    mov     eax, edx
    shr     eax, 3
    xor     [rel sha3_state + rax * 8], r12
    inc     edx
    cmp     edx, SHA3_256_RATE
    jb      .absorb_byte
    pop     r12
    pop     rbx
    ret

_keccak_f1600:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    xor     r15d, r15d
.round:
    ; Theta: C[x] = A[x,0] xor ... xor A[x,4].
    xor     r8d, r8d
.theta_c:
    mov     rax, [rel sha3_state + r8 * 8]
    mov     rbx, [rel sha3_state + r8 * 8 + 5 * 8]
    xor     rax, rbx
    mov     rbx, [rel sha3_state + r8 * 8 + 10 * 8]
    xor     rax, rbx
    mov     rbx, [rel sha3_state + r8 * 8 + 15 * 8]
    xor     rax, rbx
    mov     rbx, [rel sha3_state + r8 * 8 + 20 * 8]
    xor     rax, rbx
    mov     [rel sha3_c + r8 * 8], rax
    inc     r8d
    cmp     r8d, 5
    jb      .theta_c

    ; D[x] = C[x-1] xor rot(C[x+1], 1).
    xor     r8d, r8d
.theta_d:
    mov     eax, r8d
    add     eax, 4
    xor     edx, edx
    mov     ecx, 5
    div     ecx
    mov     rax, [rel sha3_c + rdx * 8]
    mov     r12, rax
    mov     eax, r8d
    inc     eax
    xor     edx, edx
    mov     ecx, 5
    div     ecx
    mov     rbx, [rel sha3_c + rdx * 8]
    rol     rbx, 1
    mov     rax, r12
    xor     rax, rbx
    mov     [rel sha3_d + r8 * 8], rax
    inc     r8d
    cmp     r8d, 5
    jb      .theta_d

    ; A[x,y] ^= D[x].
    xor     r9d, r9d
.theta_y:
    xor     r8d, r8d
.theta_x:
    mov     eax, r9d
    imul    eax, 5
    add     eax, r8d
    mov     rbx, [rel sha3_d + r8 * 8]
    xor     [rel sha3_state + rax * 8], rbx
    inc     r8d
    cmp     r8d, 5
    jb      .theta_x
    inc     r9d
    cmp     r9d, 5
    jb      .theta_y

    ; Rho and Pi.
    xor     r8d, r8d
.rho_pi:
    mov     rax, [rel sha3_state + r8 * 8]
    movzx   ecx, byte [rel keccak_rho + r8]
    rol     rax, cl
    movzx   ebx, byte [rel keccak_pi + r8]
    mov     [rel sha3_b + rbx * 8], rax
    inc     r8d
    cmp     r8d, KECCAK_LANES
    jb      .rho_pi

    ; Chi.
    xor     r9d, r9d
.chi_y:
    xor     r8d, r8d
.chi_x:
    mov     eax, r9d
    imul    eax, 5
    add     eax, r8d
    mov     r10d, eax
    mov     r11d, r8d
    inc     r11d
    cmp     r11d, 5
    jb      .chi_next_ok
    xor     r11d, r11d
.chi_next_ok:
    mov     eax, r9d
    imul    eax, 5
    add     eax, r11d
    mov     rbx, [rel sha3_b + rax * 8]
    not     rbx
    mov     r11d, r8d
    add     r11d, 2
    cmp     r11d, 5
    jb      .chi_next2_ok
    sub     r11d, 5
.chi_next2_ok:
    mov     eax, r9d
    imul    eax, 5
    add     eax, r11d
    and     rbx, [rel sha3_b + rax * 8]
    mov     rax, [rel sha3_b + r10 * 8]
    xor     rax, rbx
    mov     [rel sha3_state + r10 * 8], rax
    inc     r8d
    cmp     r8d, 5
    jb      .chi_x
    inc     r9d
    cmp     r9d, 5
    jb      .chi_y

    ; Iota.
    mov     rax, [rel keccak_rc + r15 * 8]
    xor     [rel sha3_state], rax
    inc     r15d
    cmp     r15d, KECCAK_ROUNDS
    jb      .round
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

global er_sha3_256
er_fn er_sha3_256
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    test    r14, r14
    jz      .fail
    test    r13, r13
    jz      .clear_ok
    test    r12, r12
    jz      .fail

    ; Clear state.
.clear_ok:
    xor     eax, eax
    xor     ecx, ecx
.zero_state:
    mov     [rel sha3_state + rcx * 8], rax
    inc     ecx
    cmp     ecx, KECCAK_LANES
    jb      .zero_state

.full_block:
    cmp     r13, SHA3_256_RATE
    jb      .final_block
    mov     rdi, r12
    call    _sha3_absorb_rate
    call    _keccak_f1600
    add     r12, SHA3_256_RATE
    sub     r13, SHA3_256_RATE
    jmp     .full_block

.final_block:
    xor     eax, eax
    xor     ecx, ecx
.zero_block:
    mov     [rel sha3_block + rcx], al
    inc     ecx
    cmp     ecx, SHA3_256_RATE
    jb      .zero_block
    xor     ecx, ecx
.copy_tail:
    cmp     rcx, r13
    jae     .pad
    mov     al, [r12 + rcx]
    mov     [rel sha3_block + rcx], al
    inc     rcx
    jmp     .copy_tail
.pad:
    xor     byte [rel sha3_block + r13], 0x06
    xor     byte [rel sha3_block + SHA3_256_RATE - 1], 0x80
    lea     rdi, [rel sha3_block]
    call    _sha3_absorb_rate
    call    _keccak_f1600

    ; SHA3 output is the little-endian byte stream of the state lanes.
    mov     rdi, r14
    lea     rsi, [rel sha3_state]
    mov     ecx, 4
.store_out:
    mov     rax, [rsi]
    mov     [rdi], rax
    add     rsi, 8
    add     rdi, 8
    dec     ecx
    jnz     .store_out
    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

global er_shake256
er_fn er_shake256
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx
    test    r15, r15
    jz      .shake_ok_empty
    test    r14, r14
    jz      .shake_fail
    test    r13, r13
    jz      .shake_clear
    test    r12, r12
    jz      .shake_fail

.shake_clear:
    xor     eax, eax
    xor     ecx, ecx
.shake_zero_state:
    mov     [rel sha3_state + rcx * 8], rax
    inc     ecx
    cmp     ecx, KECCAK_LANES
    jb      .shake_zero_state

.shake_full_block:
    cmp     r13, SHA3_256_RATE
    jb      .shake_final_block
    mov     rdi, r12
    call    _sha3_absorb_rate
    call    _keccak_f1600
    add     r12, SHA3_256_RATE
    sub     r13, SHA3_256_RATE
    jmp     .shake_full_block

.shake_final_block:
    xor     eax, eax
    xor     ecx, ecx
.shake_zero_block:
    mov     [rel sha3_block + rcx], al
    inc     ecx
    cmp     ecx, SHA3_256_RATE
    jb      .shake_zero_block
    xor     ecx, ecx
.shake_copy_tail:
    cmp     rcx, r13
    jae     .shake_pad
    mov     al, [r12 + rcx]
    mov     [rel sha3_block + rcx], al
    inc     rcx
    jmp     .shake_copy_tail
.shake_pad:
    xor     byte [rel sha3_block + r13], 0x1f
    xor     byte [rel sha3_block + SHA3_256_RATE - 1], 0x80
    lea     rdi, [rel sha3_block]
    call    _sha3_absorb_rate
    call    _keccak_f1600

.shake_squeeze_block:
    xor     edx, edx
.shake_squeeze_byte:
    test    r15, r15
    jz      .shake_done
    mov     eax, edx
    shr     eax, 3
    mov     rbx, [rel sha3_state + rax * 8]
    mov     ecx, edx
    and     ecx, 7
    shl     ecx, 3
    shr     rbx, cl
    mov     [r14], bl
    inc     r14
    dec     r15
    inc     edx
    cmp     edx, SHA3_256_RATE
    jb      .shake_squeeze_byte
    call    _keccak_f1600
    jmp     .shake_squeeze_block

.shake_done:
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.shake_ok_empty:
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.shake_fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
