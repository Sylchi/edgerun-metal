; EdgeRun host-side WASM compiler primitives.
; Emits deterministic MVP WASM bytes into caller-owned memory.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

default rel

ER_WASMC_MAGIC_0        equ 0x00
ER_WASMC_MAGIC_1        equ 0x61
ER_WASMC_MAGIC_2        equ 0x73
ER_WASMC_MAGIC_3        equ 0x6d
ER_WASMC_VERSION        equ 0x01
ER_WASMC_SECTION_TYPE   equ 0x01
ER_WASMC_SECTION_FUNC   equ 0x03
ER_WASMC_SECTION_EXPORT equ 0x07
ER_WASMC_SECTION_CODE   equ 0x0a
ER_WASMC_TYPE_FUNC      equ 0x60
ER_WASMC_TYPE_I32       equ 0x7f
ER_WASMC_EXPORT_FUNC    equ 0x00
ER_WASMC_OP_I32_CONST   equ 0x41
ER_WASMC_OP_END         equ 0x0b

WASMC_MAX_SHORT_ULEB equ 127
WASMC_FIXED_BYTES_WITHOUT_NAME equ 32

SECTION .text

; er_wasmc_emit_i32_const_export(out=rdi, cap=rsi, value=edx, name=rcx, name_len=r8)
; Returns rax=bytes_written, rdx=ERROR_OK on success.
; Current first slice intentionally emits one exported function:
;   (func (export name) (result i32) i32.const value)
er_fn er_wasmc_emit_i32_const_export
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16

    test    rdi, rdi
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument
    test    r8, r8
    jz      .bad_argument
    cmp     r8, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument

    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15, rcx
    mov     rbx, r8

    lea     rdi, [rbp - 48]
    mov     esi, r14d
    call    _er_wasmc_i32_sleb_len
    test    rdx, rdx
    jnz     .error

    mov     r10, rax
    mov     r9, WASMC_FIXED_BYTES_WITHOUT_NAME
    add     r9, rbx
    add     r9, r10
    cmp     r13, r9
    jb      .no_space

    mov     rdi, r12

    mov     byte [rdi + 0], ER_WASMC_MAGIC_0
    mov     byte [rdi + 1], ER_WASMC_MAGIC_1
    mov     byte [rdi + 2], ER_WASMC_MAGIC_2
    mov     byte [rdi + 3], ER_WASMC_MAGIC_3
    mov     byte [rdi + 4], ER_WASMC_VERSION
    mov     byte [rdi + 5], 0
    mov     byte [rdi + 6], 0
    mov     byte [rdi + 7], 0
    add     rdi, 8

    mov     byte [rdi + 0], ER_WASMC_SECTION_TYPE
    mov     byte [rdi + 1], 5
    mov     byte [rdi + 2], 1
    mov     byte [rdi + 3], ER_WASMC_TYPE_FUNC
    mov     byte [rdi + 4], 0
    mov     byte [rdi + 5], 1
    mov     byte [rdi + 6], ER_WASMC_TYPE_I32
    add     rdi, 7

    mov     byte [rdi + 0], ER_WASMC_SECTION_FUNC
    mov     byte [rdi + 1], 2
    mov     byte [rdi + 2], 1
    mov     byte [rdi + 3], 0
    add     rdi, 4

    mov     byte [rdi + 0], ER_WASMC_SECTION_EXPORT
    lea     rax, [rbx + 4]
    mov     [rdi + 1], al
    mov     byte [rdi + 2], 1
    mov     [rdi + 3], bl
    add     rdi, 4

    mov     rcx, rbx
    mov     rsi, r15
    rep     movsb

    mov     byte [rdi + 0], ER_WASMC_EXPORT_FUNC
    mov     byte [rdi + 1], 0
    add     rdi, 2

    mov     byte [rdi + 0], ER_WASMC_SECTION_CODE
    lea     rax, [r10 + 5]
    mov     [rdi + 1], al
    mov     byte [rdi + 2], 1
    lea     rax, [r10 + 3]
    mov     [rdi + 3], al
    mov     byte [rdi + 4], 0
    mov     byte [rdi + 5], ER_WASMC_OP_I32_CONST
    add     rdi, 6

    lea     rsi, [rbp - 48]
    mov     rcx, r10
    rep     movsb

    mov     byte [rdi], ER_WASMC_OP_END
    inc     rdi

    mov     rax, rdi
    sub     rax, r12
    xor     edx, edx
    jmp     .done

.bad_argument:
    xor     eax, eax
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.no_space:
    xor     eax, eax
    mov     edx, ERROR_NO_SPACE
    jmp     .done
.error:
    xor     eax, eax
.done:
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_wasmc_i32_sleb_len(out=rdi, value=esi)
; Writes signed LEB128 for i32 value into out. Returns rax=len, rdx=0.
er_fn _er_wasmc_i32_sleb_len
    er_frame_push
    push    rbx

    mov     eax, esi
    xor     ebx, ebx

.loop:
    mov     ecx, eax
    and     ecx, 0x7f
    sar     eax, 7

    mov     edx, ecx
    and     edx, 0x40
    cmp     eax, 0
    jne     .check_negative_done
    test    edx, edx
    jz      .last

.check_negative_done:
    cmp     eax, -1
    jne     .more
    test    edx, edx
    jnz     .last

.more:
    or      ecx, 0x80
    mov     [rdi + rbx], cl
    inc     rbx
    jmp     .loop

.last:
    mov     [rdi + rbx], cl
    inc     rbx
    mov     rax, rbx
    xor     edx, edx
    pop     rbx
    pop     rbp
    ret
