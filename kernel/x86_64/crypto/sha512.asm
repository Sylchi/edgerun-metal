; EdgeRun software SHA-512 - streaming implementation.
;
; Provides:
;   er_sha512_init(ctx)
;   er_sha512_update(ctx, data, len)
;   er_sha512_final(ctx, out64)
;   er_sha512(data, len, out64)
;
; Context structure (200 bytes):
;   +0:   H[0..7]     8 qwords
;   +64:  count       1 qword, total bytes processed
;   +72:  buf[128]    partial block
;   +200: size

%include "x86_64/macros.inc"

SECTION .rodata
align 16
K512:
    dq 0x428a2f98d728ae22, 0x7137449123ef65cd
    dq 0xb5c0fbcfec4d3b2f, 0xe9b5dba58189dbbc
    dq 0x3956c25bf348b538, 0x59f111f1b605d019
    dq 0x923f82a4af194f9b, 0xab1c5ed5da6d8118
    dq 0xd807aa98a3030242, 0x12835b0145706fbe
    dq 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2
    dq 0x72be5d74f27b896f, 0x80deb1fe3b1696b1
    dq 0x9bdc06a725c71235, 0xc19bf174cf692694
    dq 0xe49b69c19ef14ad2, 0xefbe4786384f25e3
    dq 0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65
    dq 0x2de92c6f592b0275, 0x4a7484aa6ea6e483
    dq 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5
    dq 0x983e5152ee66dfab, 0xa831c66d2db43210
    dq 0xb00327c898fb213f, 0xbf597fc7beef0ee4
    dq 0xc6e00bf33da88fc2, 0xd5a79147930aa725
    dq 0x06ca6351e003826f, 0x142929670a0e6e70
    dq 0x27b70a8546d22ffc, 0x2e1b21385c26c926
    dq 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df
    dq 0x650a73548baf63de, 0x766a0abb3c77b2a8
    dq 0x81c2c92e47edaee6, 0x92722c851482353b
    dq 0xa2bfe8a14cf10364, 0xa81a664bbc423001
    dq 0xc24b8b70d0f89791, 0xc76c51a30654be30
    dq 0xd192e819d6ef5218, 0xd69906245565a910
    dq 0xf40e35855771202a, 0x106aa07032bbd1b8
    dq 0x19a4c116b8d2d0c8, 0x1e376c085141ab53
    dq 0x2748774cdf8eeb99, 0x34b0bcb5e19b48a8
    dq 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb
    dq 0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3
    dq 0x748f82ee5defb2fc, 0x78a5636f43172f60
    dq 0x84c87814a1f0ab72, 0x8cc702081a6439ec
    dq 0x90befffa23631e28, 0xa4506cebde82bde9
    dq 0xbef9a3f7b2c67915, 0xc67178f2e372532b
    dq 0xca273eceea26619c, 0xd186b8c721c0c207
    dq 0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178
    dq 0x06f067aa72176fba, 0x0a637dc5a2c898a6
    dq 0x113f9804bef90dae, 0x1b710b35131c471b
    dq 0x28db77f523047d84, 0x32caab7b40c72493
    dq 0x3c9ebe0a15c9bebc, 0x431d67c49c100d4c
    dq 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a
    dq 0x5fcb6fab3ad6faec, 0x6c44198c4a475817

align 16
H512:
    dq 0x6a09e667f3bcc908, 0xbb67ae8584caa73b
    dq 0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1
    dq 0x510e527fade682d1, 0x9b05688c2b3e6c1f
    dq 0x1f83d9abfb41bd6b, 0x5be0cd19137e2179

%define SHA512_CTX_H       0
%define SHA512_CTX_COUNT   64
%define SHA512_CTX_BUF     72
%define SHA512_CTX_BUFLEN  200
%define SHA512_CTX_SIZE    208

SECTION .text

; rdi=ctx, rsi=block128
er_fn _sha512_compress
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 80 * 8 + 8

    mov     [rsp + 80 * 8], rdi

    lea     rdi, [rsp]
    xor     ecx, ecx
.load_w:
    mov     rax, [rsi]
    bswap   rax
    mov     [rdi], rax
    add     rsi, 8
    add     rdi, 8
    inc     ecx
    cmp     ecx, 16
    jb      .load_w

    mov     ecx, 16
.extend_w:
    mov     rax, [rdi - 2 * 8]
    mov     rdx, rax
    ror     rdx, 19
    mov     rbx, rax
    ror     rbx, 61
    xor     rdx, rbx
    shr     rax, 6
    xor     rdx, rax
    add     rdx, [rdi - 7 * 8]

    mov     rax, [rdi - 15 * 8]
    mov     rbx, rax
    ror     rbx, 1
    mov     rbp, rax
    ror     rbp, 8
    xor     rbx, rbp
    shr     rax, 7
    xor     rbx, rax
    add     rdx, rbx
    add     rdx, [rdi - 16 * 8]

    mov     [rdi], rdx
    add     rdi, 8
    inc     ecx
    cmp     ecx, 80
    jb      .extend_w

    mov     rbx, [rsp + 80 * 8]
    lea     rbp, [rel K512]
    mov     r8,  [rbx + SHA512_CTX_H + 0]
    mov     r9,  [rbx + SHA512_CTX_H + 8]
    mov     r10, [rbx + SHA512_CTX_H + 16]
    mov     r11, [rbx + SHA512_CTX_H + 24]
    mov     r12, [rbx + SHA512_CTX_H + 32]
    mov     r13, [rbx + SHA512_CTX_H + 40]
    mov     r14, [rbx + SHA512_CTX_H + 48]
    mov     r15, [rbx + SHA512_CTX_H + 56]

    xor     ecx, ecx
.round:
    mov     rax, r12
    mov     rdx, rax
    ror     rdx, 14
    mov     rsi, rax
    ror     rsi, 18
    xor     rdx, rsi
    mov     rsi, rax
    ror     rsi, 41
    xor     rdx, rsi

    mov     rax, r12
    and     rax, r13
    mov     rdi, r12
    not     rdi
    and     rdi, r14
    xor     rax, rdi

    add     rdx, r15
    add     rdx, rax
    add     rdx, [rsp + rcx * 8]
    add     rdx, [rbp + rcx * 8]

    mov     rax, r8
    mov     rsi, rax
    ror     rsi, 28
    mov     rdi, rax
    ror     rdi, 34
    xor     rsi, rdi
    mov     rdi, rax
    ror     rdi, 39
    xor     rsi, rdi

    mov     rax, r8
    and     rax, r9
    mov     rdi, r8
    and     rdi, r10
    xor     rax, rdi
    mov     rdi, r9
    and     rdi, r10
    xor     rax, rdi
    add     rsi, rax

    mov     r15, r14
    mov     r14, r13
    mov     r13, r12
    mov     rax, r11
    add     rax, rdx
    mov     r12, rax
    mov     r11, r10
    mov     r10, r9
    mov     r9,  r8
    add     rdx, rsi
    mov     r8,  rdx

    inc     ecx
    cmp     ecx, 80
    jb      .round

    mov     rdi, [rsp + 80 * 8]
    add     [rdi + SHA512_CTX_H + 0],  r8
    add     [rdi + SHA512_CTX_H + 8],  r9
    add     [rdi + SHA512_CTX_H + 16], r10
    add     [rdi + SHA512_CTX_H + 24], r11
    add     [rdi + SHA512_CTX_H + 32], r12
    add     [rdi + SHA512_CTX_H + 40], r13
    add     [rdi + SHA512_CTX_H + 48], r14
    add     [rdi + SHA512_CTX_H + 56], r15

    add     rsp, 80 * 8 + 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

er_fn er_sha512_init
    test    rdi, rdi
    jz      .err
    push    rdi
    push    rsi
    push    rcx
    lea     rsi, [rel H512]
    mov     ecx, 8
.copy_h:
    mov     rax, [rsi + rcx * 8 - 8]
    mov     [rdi + SHA512_CTX_H + rcx * 8 - 8], rax
    dec     ecx
    jnz     .copy_h
    mov     qword [rdi + SHA512_CTX_COUNT], 0
    mov     dword [rdi + SHA512_CTX_BUFLEN], 0
    lea     rdi, [rdi + SHA512_CTX_BUF]
    xor     eax, eax
    mov     ecx, 128 / 8
    rep     stosq
    pop     rcx
    pop     rsi
    pop     rax
    ret
.err:
    xor     eax, eax
    ret

er_fn er_sha512_update
    test    rdi, rdi
    jz      .err
    test    rdx, rdx
    jz      .done_empty
    test    rsi, rsi
    jz      .err
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    add     [r12 + SHA512_CTX_COUNT], r14

    mov     r15d, [r12 + SHA512_CTX_BUFLEN]
    test    r15d, r15d
    jz      .full_blocks
    mov     ebp, 128
    sub     ebp, r15d
    cmp     r14, rbp
    jb      .copy_partial
    lea     rdi, [r12 + SHA512_CTX_BUF + r15]
    mov     rsi, r13
    mov     ecx, ebp
    rep     movsb
    mov     rdi, r12
    lea     rsi, [r12 + SHA512_CTX_BUF]
    call    _sha512_compress
    add     r13, rbp
    sub     r14, rbp
    mov     dword [r12 + SHA512_CTX_BUFLEN], 0

.full_blocks:
    mov     rbx, r14
    shr     rbx, 7
    jz      .partial_copy
.full_loop:
    mov     rdi, r12
    mov     rsi, r13
    call    _sha512_compress
    add     r13, 128
    sub     r14, 128
    dec     rbx
    jnz     .full_loop

.partial_copy:
    test    r14, r14
    jz      .done
    mov     [r12 + SHA512_CTX_BUFLEN], r14d
    lea     rdi, [r12 + SHA512_CTX_BUF]
    mov     rsi, r13
    mov     ecx, r14d
    rep     movsb
    jmp     .done

.copy_partial:
    lea     rdi, [r12 + SHA512_CTX_BUF + r15]
    mov     rsi, r13
    mov     ecx, r14d
    rep     movsb
    add     [r12 + SHA512_CTX_BUFLEN], r14d

.done:
    mov     rax, r12
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret
.done_empty:
    mov     rax, rdi
    ret
.err:
    xor     eax, eax
    ret

er_fn er_sha512_final
    test    rdi, rdi
    jz      .err
    test    rsi, rsi
    jz      .err
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r13, rsi

    mov     r14d, [r12 + SHA512_CTX_BUFLEN]
    mov     byte [r12 + SHA512_CTX_BUF + r14], 0x80
    inc     r14d
    cmp     r14d, 112
    ja      .extra_block
    cmp     r14d, 112
    jae     .write_len
    lea     rdi, [r12 + SHA512_CTX_BUF + r14]
    mov     ecx, 112
    sub     ecx, r14d
    xor     eax, eax
    rep     stosb
    jmp     .write_len

.extra_block:
    lea     rdi, [r12 + SHA512_CTX_BUF + r14]
    mov     ecx, 128
    sub     ecx, r14d
    xor     eax, eax
    rep     stosb
    mov     rdi, r12
    lea     rsi, [r12 + SHA512_CTX_BUF]
    call    _sha512_compress
    xor     eax, eax
    lea     rdi, [r12 + SHA512_CTX_BUF]
    mov     ecx, 112 / 8
    rep     stosq

.write_len:
    mov     qword [r12 + SHA512_CTX_BUF + 112], 0
    mov     rax, [r12 + SHA512_CTX_COUNT]
    shr     rax, 61
    bswap   rax
    mov     [r12 + SHA512_CTX_BUF + 120 - 8], rax
    mov     rax, [r12 + SHA512_CTX_COUNT]
    shl     rax, 3
    bswap   rax
    mov     [r12 + SHA512_CTX_BUF + 120], rax

    mov     rdi, r12
    lea     rsi, [r12 + SHA512_CTX_BUF]
    call    _sha512_compress

    xor     rcx, rcx
.out_loop:
    mov     rax, [r12 + SHA512_CTX_H + rcx * 8]
    bswap   rax
    mov     [r13 + rcx * 8], rax
    inc     rcx
    cmp     rcx, 8
    jb      .out_loop

    mov     rax, r13
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err:
    xor     eax, eax
    ret

er_fn er_sha512
    test    rdx, rdx
    jz      .err
    sub     rsp, SHA512_CTX_SIZE + 8
    mov     [rsp + SHA512_CTX_SIZE], rdx
    mov     r8, rdi
    mov     r9, rsi
    lea     rdi, [rsp]
    call    er_sha512_init
    test    rax, rax
    jz      .fail
    lea     rdi, [rsp]
    mov     rsi, r8
    mov     rdx, r9
    call    er_sha512_update
    test    rax, rax
    jz      .fail
    lea     rdi, [rsp]
    mov     rsi, [rsp + SHA512_CTX_SIZE]
    call    er_sha512_final
    test    rax, rax
    jz      .fail
    mov     rax, [rsp + SHA512_CTX_SIZE]
    add     rsp, SHA512_CTX_SIZE + 8
    ret
.fail:
    add     rsp, SHA512_CTX_SIZE + 8
.err:
    xor     eax, eax
    ret
