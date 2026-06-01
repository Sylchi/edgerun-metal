; EdgeRun Ed25519 helpers - x86_64 assembly.
;
; This file is the native signing path foundation. It starts with the RFC 8032
; seed hash split used by both normal and blinded Ed25519 signing:
;   az = SHA512(seed32)
;   scalar = clamp(az[0..32])
;   prefix = az[32..64]

%include "x86_64/macros.inc"

extern er_sha512
extern _fe_copy
extern _fe_add
extern _fe_sub
extern _fe_mul
extern _fe_square
extern _fe_invert
extern _fe_frombytes
extern _fe_tobytes

%define ED25519_SEED_LEN    32
%define ED25519_SCALAR_LEN  32
%define ED25519_PREFIX_LEN  32
%define ED25519_FE_SIZE     40
%define ED25519_POINT_SIZE  160
%define ED25519_POINT_X     0
%define ED25519_POINT_Y     40
%define ED25519_POINT_Z     80
%define ED25519_POINT_T     120

SECTION .rodata
ed25519_order_l:
    db 0xed,0xd3,0xf5,0x5c,0x1a,0x63,0x12,0x58
    db 0xd6,0x9c,0xf7,0xa2,0xde,0xf9,0xde,0x14
    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x10
ed25519_fe_zero:
    dq 0, 0, 0, 0, 0
ed25519_fe_one:
    dq 1, 0, 0, 0, 0
ed25519_fe_two:
    dq 2, 0, 0, 0, 0
ed25519_base_x_bytes:
    db 0x1a,0xd5,0x25,0x8f,0x60,0x2d,0x56,0xc9
    db 0xb2,0xa7,0x25,0x95,0x60,0xc7,0x2c,0x69
    db 0x5c,0xdc,0xd6,0xfd,0x31,0xe2,0xa4,0xc0
    db 0xfe,0x53,0x6e,0xcd,0xd3,0x36,0x69,0x21
ed25519_base_y_bytes:
    db 0x58,0x66,0x66,0x66,0x66,0x66,0x66,0x66
    db 0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66
    db 0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66
    db 0x66,0x66,0x66,0x66,0x66,0x66,0x66,0x66
ed25519_d2_bytes:
    db 0x59,0x18,0xf2,0x9f,0x4c,0xc9,0x46,0x63
    db 0xd6,0x70,0x58,0x5f,0x44,0x51,0x70,0x7a
    db 0x45,0x83,0x46,0xb4,0x3b,0x91,0x3d,0xa9
    db 0x50,0x9b,0x2f,0x5b,0xf1,0x56,0x36,0x2b

SECTION .text

_ed25519_point_identity:
    lea     rsi, [rel ed25519_fe_zero]
    lea     rdi, [rdi + ED25519_POINT_X]
    call    _fe_copy
    lea     rsi, [rel ed25519_fe_one]
    lea     rdi, [rdi + ED25519_POINT_Y - ED25519_POINT_X]
    call    _fe_copy
    lea     rsi, [rel ed25519_fe_one]
    lea     rdi, [rdi + ED25519_POINT_Z - ED25519_POINT_Y]
    call    _fe_copy
    lea     rsi, [rel ed25519_fe_zero]
    lea     rdi, [rdi + ED25519_POINT_T - ED25519_POINT_Z]
    jmp     _fe_copy

_ed25519_point_base:
    push    rbx
    mov     rbx, rdi
    lea     rdi, [rbx + ED25519_POINT_X]
    lea     rsi, [rel ed25519_base_x_bytes]
    call    _fe_frombytes
    lea     rdi, [rbx + ED25519_POINT_Y]
    lea     rsi, [rel ed25519_base_y_bytes]
    call    _fe_frombytes
    lea     rdi, [rbx + ED25519_POINT_Z]
    lea     rsi, [rel ed25519_fe_one]
    call    _fe_copy
    lea     rdi, [rbx + ED25519_POINT_T]
    lea     rsi, [rbx + ED25519_POINT_X]
    lea     rdx, [rbx + ED25519_POINT_Y]
    call    _fe_mul
    pop     rbx
    ret

_ed25519_point_copy:
    push    rbx
    push    r12
    mov     rbx, rdi
    mov     r12, rsi
    lea     rdi, [rbx + ED25519_POINT_X]
    lea     rsi, [r12 + ED25519_POINT_X]
    call    _fe_copy
    lea     rdi, [rbx + ED25519_POINT_Y]
    lea     rsi, [r12 + ED25519_POINT_Y]
    call    _fe_copy
    lea     rdi, [rbx + ED25519_POINT_Z]
    lea     rsi, [r12 + ED25519_POINT_Z]
    call    _fe_copy
    lea     rdi, [rbx + ED25519_POINT_T]
    lea     rsi, [r12 + ED25519_POINT_T]
    call    _fe_copy
    pop     r12
    pop     rbx
    ret

; _ed25519_point_add(out, p, q)
_ed25519_point_add:
    push    rbx
    push    r12
    push    r13
    push    r14
    sub     rsp, 360
    ; A=0 B=40 C=80 D=120 E=160 F=200 G=240 H=280 d2=320
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx

    lea     rdi, [rsp + 320]
    lea     rsi, [rel ed25519_d2_bytes]
    call    _fe_frombytes

    lea     rdi, [rsp + 160]
    lea     rsi, [r12 + ED25519_POINT_Y]
    lea     rdx, [r12 + ED25519_POINT_X]
    call    _fe_sub
    lea     rdi, [rsp + 200]
    lea     rsi, [r13 + ED25519_POINT_Y]
    lea     rdx, [r13 + ED25519_POINT_X]
    call    _fe_sub
    lea     rdi, [rsp + 0]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 200]
    call    _fe_mul

    lea     rdi, [rsp + 160]
    lea     rsi, [r12 + ED25519_POINT_Y]
    lea     rdx, [r12 + ED25519_POINT_X]
    call    _fe_add
    lea     rdi, [rsp + 200]
    lea     rsi, [r13 + ED25519_POINT_Y]
    lea     rdx, [r13 + ED25519_POINT_X]
    call    _fe_add
    lea     rdi, [rsp + 40]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 200]
    call    _fe_mul

    lea     rdi, [rsp + 80]
    lea     rsi, [r12 + ED25519_POINT_T]
    lea     rdx, [r13 + ED25519_POINT_T]
    call    _fe_mul
    lea     rdi, [rsp + 80]
    lea     rsi, [rsp + 80]
    lea     rdx, [rsp + 320]
    call    _fe_mul

    lea     rdi, [rsp + 120]
    lea     rsi, [r12 + ED25519_POINT_Z]
    lea     rdx, [r13 + ED25519_POINT_Z]
    call    _fe_mul
    lea     rdi, [rsp + 120]
    lea     rsi, [rsp + 120]
    lea     rdx, [rel ed25519_fe_two]
    call    _fe_mul

    lea     rdi, [rsp + 160]
    lea     rsi, [rsp + 40]
    lea     rdx, [rsp + 0]
    call    _fe_sub
    lea     rdi, [rsp + 200]
    lea     rsi, [rsp + 120]
    lea     rdx, [rsp + 80]
    call    _fe_sub
    lea     rdi, [rsp + 240]
    lea     rsi, [rsp + 120]
    lea     rdx, [rsp + 80]
    call    _fe_add
    lea     rdi, [rsp + 280]
    lea     rsi, [rsp + 40]
    lea     rdx, [rsp + 0]
    call    _fe_add

    lea     rdi, [rbx + ED25519_POINT_X]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 200]
    call    _fe_mul
    lea     rdi, [rbx + ED25519_POINT_Y]
    lea     rsi, [rsp + 240]
    lea     rdx, [rsp + 280]
    call    _fe_mul
    lea     rdi, [rbx + ED25519_POINT_T]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 280]
    call    _fe_mul
    lea     rdi, [rbx + ED25519_POINT_Z]
    lea     rsi, [rsp + 200]
    lea     rdx, [rsp + 240]
    call    _fe_mul

    add     rsp, 360
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _ed25519_point_double(out, p)
_ed25519_point_double:
    push    rbx
    push    r12
    sub     rsp, 320
    ; A=0 B=40 C=80 D=120 E=160 F=200 G=240 H=280
    mov     rbx, rdi
    mov     r12, rsi

    lea     rdi, [rsp + 0]
    lea     rsi, [r12 + ED25519_POINT_X]
    call    _fe_square
    lea     rdi, [rsp + 40]
    lea     rsi, [r12 + ED25519_POINT_Y]
    call    _fe_square
    lea     rdi, [rsp + 80]
    lea     rsi, [r12 + ED25519_POINT_Z]
    call    _fe_square
    lea     rdi, [rsp + 80]
    lea     rsi, [rsp + 80]
    lea     rdx, [rel ed25519_fe_two]
    call    _fe_mul
    lea     rdi, [rsp + 120]
    lea     rsi, [rel ed25519_fe_zero]
    lea     rdx, [rsp + 0]
    call    _fe_sub
    lea     rdi, [rsp + 160]
    lea     rsi, [r12 + ED25519_POINT_X]
    lea     rdx, [r12 + ED25519_POINT_Y]
    call    _fe_add
    lea     rdi, [rsp + 160]
    lea     rsi, [rsp + 160]
    call    _fe_square
    lea     rdi, [rsp + 160]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 0]
    call    _fe_sub
    lea     rdi, [rsp + 160]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 40]
    call    _fe_sub
    lea     rdi, [rsp + 240]
    lea     rsi, [rsp + 120]
    lea     rdx, [rsp + 40]
    call    _fe_add
    lea     rdi, [rsp + 200]
    lea     rsi, [rsp + 240]
    lea     rdx, [rsp + 80]
    call    _fe_sub
    lea     rdi, [rsp + 280]
    lea     rsi, [rsp + 120]
    lea     rdx, [rsp + 40]
    call    _fe_sub

    lea     rdi, [rbx + ED25519_POINT_X]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 200]
    call    _fe_mul
    lea     rdi, [rbx + ED25519_POINT_Y]
    lea     rsi, [rsp + 240]
    lea     rdx, [rsp + 280]
    call    _fe_mul
    lea     rdi, [rbx + ED25519_POINT_T]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 280]
    call    _fe_mul
    lea     rdi, [rbx + ED25519_POINT_Z]
    lea     rsi, [rsp + 200]
    lea     rdx, [rsp + 240]
    call    _fe_mul

    add     rsp, 320
    pop     r12
    pop     rbx
    ret

; er_ed25519_point_base_mul(out32, scalar32)
; Computes compressed [scalar]B. Returns rax=0,rdx=0 on success.
er_fn er_ed25519_point_base_mul
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 480
    ; result=0, current=160, tmp=320
    mov     r12, rdi
    mov     r13, rsi
    lea     rdi, [rsp]
    call    _ed25519_point_identity
    lea     rdi, [rsp + 160]
    call    _ed25519_point_base
    xor     r14d, r14d
.byte_loop:
    movzx   ebx, byte [r13 + r14]
    xor     r15d, r15d
.bit_loop:
    mov     eax, ebx
    mov     ecx, r15d
    shr     eax, cl
    test    eax, 1
    jz      .skip_add
    lea     rdi, [rsp + 320]
    lea     rsi, [rsp]
    lea     rdx, [rsp + 160]
    call    _ed25519_point_add
    lea     rdi, [rsp]
    lea     rsi, [rsp + 320]
    call    _ed25519_point_copy
.skip_add:
    lea     rdi, [rsp + 320]
    lea     rsi, [rsp + 160]
    call    _ed25519_point_double
    lea     rdi, [rsp + 160]
    lea     rsi, [rsp + 320]
    call    _ed25519_point_copy
    inc     r15d
    cmp     r15d, 8
    jb      .bit_loop
    inc     r14d
    cmp     r14d, ED25519_SCALAR_LEN
    jb      .byte_loop

    mov     rdi, r12
    lea     rsi, [rsp]
    call    _ed25519_point_encode
    xor     eax, eax
    er_ok
    add     rsp, 480
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.fail:
    mov     eax, -1
    mov     edx, 1
    ret

_ed25519_point_encode:
    push    rbx
    push    r12
    push    r13
    sub     rsp, 160
    ; zinv=0, x=40, y=80, xbytes=120
    mov     r12, rdi
    mov     r13, rsi
    lea     rdi, [rsp]
    lea     rsi, [r13 + ED25519_POINT_Z]
    call    _fe_invert
    lea     rdi, [rsp + 40]
    lea     rsi, [r13 + ED25519_POINT_X]
    lea     rdx, [rsp]
    call    _fe_mul
    lea     rdi, [rsp + 80]
    lea     rsi, [r13 + ED25519_POINT_Y]
    lea     rdx, [rsp]
    call    _fe_mul
    lea     rdi, [rsp + 120]
    lea     rsi, [rsp + 40]
    call    _fe_tobytes
    mov     rdi, r12
    lea     rsi, [rsp + 80]
    call    _fe_tobytes
    movzx   eax, byte [rsp + 120]
    and     eax, 1
    shl     eax, 7
    and     byte [r12 + 31], 0x7f
    or      [r12 + 31], al
    add     rsp, 160
    pop     r13
    pop     r12
    pop     rbx
    ret

; _ed25519_scalar_add_mod(acc32, addend32)
; acc = (acc + addend) mod l. Inputs must already be < l.
_ed25519_scalar_add_mod:
    push    rbx
    push    r12
    xor     r8d, r8d
    xor     ecx, ecx
.add_loop:
    movzx   eax, byte [rdi + rcx]
    movzx   edx, byte [rsi + rcx]
    add     eax, edx
    add     eax, r8d
    cmp     eax, 256
    setae   r8b
    mov     [rdi + rcx], al
    inc     ecx
    cmp     ecx, ED25519_SCALAR_LEN
    jb      .add_loop

    test    r8b, r8b
    jnz     .subtract_l
    mov     r9d, ED25519_SCALAR_LEN - 1
.cmp_loop:
    mov     al, [rdi + r9]
    mov     dl, [rel ed25519_order_l + r9]
    cmp     al, dl
    ja      .subtract_l
    jb      .done
    dec     r9d
    jns     .cmp_loop

.subtract_l:
    xor     r10d, r10d
    xor     r9d, r9d
.sub_loop:
    mov     dl, [rel ed25519_order_l + r9]
    add     dl, r10b
    mov     al, [rdi + r9]
    sub     al, dl
    mov     [rdi + r9], al
    setb    r10b
    inc     r9d
    cmp     r9d, ED25519_SCALAR_LEN
    jb      .sub_loop

.done:
    pop     r12
    pop     rbx
    ret

; _ed25519_scalar_double_mod(acc32)
; acc = (acc * 2) mod l. Input must already be < l.
_ed25519_scalar_double_mod:
    push    rbx
    xor     r8d, r8d
    xor     ecx, ecx
.dbl_loop:
    movzx   eax, byte [rdi + rcx]
    mov     edx, eax
    shr     edx, 7
    shl     eax, 1
    and     eax, 0xff
    or      eax, r8d
    mov     [rdi + rcx], al
    mov     r8d, edx
    inc     ecx
    cmp     ecx, ED25519_SCALAR_LEN
    jb      .dbl_loop

    test    r8b, r8b
    jnz     .subtract_l
    mov     r9d, ED25519_SCALAR_LEN - 1
.cmp_loop:
    mov     al, [rdi + r9]
    mov     dl, [rel ed25519_order_l + r9]
    cmp     al, dl
    ja      .subtract_l
    jb      .done
    dec     r9d
    jns     .cmp_loop

.subtract_l:
    xor     r10d, r10d
    xor     r9d, r9d
.sub_loop:
    mov     dl, [rel ed25519_order_l + r9]
    add     dl, r10b
    mov     al, [rdi + r9]
    sub     al, dl
    mov     [rdi + r9], al
    setb    r10b
    inc     r9d
    cmp     r9d, ED25519_SCALAR_LEN
    jb      .sub_loop

.done:
    pop     rbx
    ret

; er_ed25519_scalar_muladd(a32, b32, c32, out32)
; out = (a * b + c) mod l.
; Returns rax=0, rdx=0 on success; rax=-1, rdx=1 on invalid pointers.
er_fn er_ed25519_scalar_muladd
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail
    test    rdx, rdx
    jz      .fail
    test    rcx, rcx
    jz      .fail

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 192
    ; [rsp+0] result, [rsp+32] current addend, [rsp+64] reduced a,
    ; [rsp+96] reduce input scratch64, [rsp+160] caller out pointer.
    mov     [rsp + 160], rcx
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx

    lea     rdi, [rsp + 64]
    xor     eax, eax
    mov     ecx, ED25519_SCALAR_LEN / 8
    rep     stosq

    lea     rdi, [rsp + 96]
    xor     eax, eax
    mov     ecx, 8
    rep     stosq
    lea     rdi, [rsp + 96]
    mov     rsi, r12
    mov     ecx, ED25519_SCALAR_LEN
    rep     movsb
    lea     rdi, [rsp + 96]
    lea     rsi, [rsp + 64]
    call    er_ed25519_scalar_reduce64
    test    eax, eax
    jnz     .fail_pop

    lea     rdi, [rsp + 96]
    xor     eax, eax
    mov     ecx, 8
    rep     stosq
    lea     rdi, [rsp + 96]
    mov     rsi, r13
    mov     ecx, ED25519_SCALAR_LEN
    rep     movsb
    lea     rdi, [rsp + 96]
    lea     rsi, [rsp + 32]
    call    er_ed25519_scalar_reduce64
    test    eax, eax
    jnz     .fail_pop

    lea     rdi, [rsp + 96]
    xor     eax, eax
    mov     ecx, 8
    rep     stosq
    lea     rdi, [rsp + 96]
    mov     rsi, r14
    mov     ecx, ED25519_SCALAR_LEN
    rep     movsb
    lea     rdi, [rsp + 96]
    lea     rsi, [rsp]
    call    er_ed25519_scalar_reduce64
    test    eax, eax
    jnz     .fail_pop

    xor     r14d, r14d
.mul_byte_loop:
    movzx   ebx, byte [rsp + 64 + r14]
    xor     r15d, r15d
.mul_bit_loop:
    mov     eax, ebx
    mov     ecx, r15d
    shr     eax, cl
    test    eax, 1
    jz      .skip_add
    lea     rdi, [rsp]
    lea     rsi, [rsp + 32]
    call    _ed25519_scalar_add_mod
.skip_add:
    lea     rdi, [rsp + 32]
    call    _ed25519_scalar_double_mod
    inc     r15d
    cmp     r15d, 8
    jb      .mul_bit_loop
    inc     r14d
    cmp     r14d, ED25519_SCALAR_LEN
    jb      .mul_byte_loop

    mov     rdi, [rsp + 160]
    mov     rsi, rsp
    mov     ecx, ED25519_SCALAR_LEN
    rep     movsb
    xor     eax, eax
    er_ok
    add     rsp, 192
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.fail_pop:
    add     rsp, 192
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.fail:
    mov     eax, -1
    mov     edx, 1
    ret

; er_ed25519_scalar_reduce64(in64, out32)
; Reduces a 512-bit little-endian integer modulo the Ed25519 group order.
; Returns rax=0, rdx=0 on success; rax=-1, rdx=1 on invalid pointers.
er_fn er_ed25519_scalar_reduce64
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, ED25519_SCALAR_LEN

    mov     r12, rdi
    mov     r13, rsi
    mov     rdi, rsp
    xor     eax, eax
    mov     ecx, ED25519_SCALAR_LEN / 8
    rep     stosq

    mov     r14d, 63
.byte_loop:
    movzx   ebx, byte [r12 + r14]
    mov     r15d, 7
.bit_loop:
    mov     eax, ebx
    mov     ecx, r15d
    shr     eax, cl
    and     eax, 1
    mov     r10d, eax
    xor     r9d, r9d
.shift_loop:
    movzx   eax, byte [rsp + r9]
    mov     edx, eax
    shr     edx, 7
    shl     eax, 1
    and     eax, 0xff
    or      eax, r10d
    mov     [rsp + r9], al
    mov     r10d, edx
    inc     r9d
    cmp     r9d, ED25519_SCALAR_LEN
    jb      .shift_loop

    mov     r9d, ED25519_SCALAR_LEN - 1
.cmp_loop:
    mov     al, [rsp + r9]
    mov     dl, [rel ed25519_order_l + r9]
    cmp     al, dl
    ja      .subtract_l
    jb      .after_subtract
    dec     r9d
    jns     .cmp_loop

.subtract_l:
    xor     r10d, r10d
    xor     r9d, r9d
.sub_loop:
    mov     dl, [rel ed25519_order_l + r9]
    add     dl, r10b
    mov     al, [rsp + r9]
    sub     al, dl
    mov     [rsp + r9], al
    setb    r10b
    inc     r9d
    cmp     r9d, ED25519_SCALAR_LEN
    jb      .sub_loop

.after_subtract:
    dec     r15d
    jns     .bit_loop
    dec     r14d
    jns     .byte_loop

    mov     rdi, r13
    mov     rsi, rsp
    mov     ecx, ED25519_SCALAR_LEN
    rep     movsb

    xor     eax, eax
    er_ok
    add     rsp, ED25519_SCALAR_LEN
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.fail:
    mov     eax, -1
    mov     edx, 1
    ret

; er_ed25519_seed_scalar_prefix(seed32, out_scalar32, out_prefix32)
; Returns rax=0, rdx=0 on success; rax=-1, rdx=1 on invalid pointers.
er_fn er_ed25519_seed_scalar_prefix
    test    rdi, rdi
    jz      .fail
    test    rsi, rsi
    jz      .fail
    test    rdx, rdx
    jz      .fail

    push    rbx
    push    r12
    push    r13
    push    r14
    sub     rsp, 64

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx

    mov     rdi, r12
    mov     esi, ED25519_SEED_LEN
    lea     rdx, [rsp]
    call    er_sha512
    test    rax, rax
    jz      .fail_pop

    mov     rdi, r13
    lea     rsi, [rsp]
    mov     ecx, ED25519_SCALAR_LEN
    rep     movsb
    and     byte [r13], 248
    and     byte [r13 + 31], 63
    or      byte [r13 + 31], 64

    mov     rdi, r14
    lea     rsi, [rsp + ED25519_SCALAR_LEN]
    mov     ecx, ED25519_PREFIX_LEN
    rep     movsb

    xor     eax, eax
    er_ok
    add     rsp, 64
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.fail_pop:
    add     rsp, 64
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.fail:
    mov     eax, -1
    mov     edx, 1
    ret
