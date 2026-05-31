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
ER_WASMC_OP_I32_ADD     equ 0x6a
ER_WASMC_OP_END         equ 0x0b

WASMC_MAX_SHORT_ULEB equ 127
WASMC_FIXED_BYTES_WITHOUT_NAME equ 32

SECTION .rodata
wasmc_kw_export: db "export"
WASMC_KW_EXPORT_LEN equ 6

SECTION .text

; er_wasmc_compile_source(out=rdi, cap=rsi, source=rdx, source_len=rcx)
; Source form for the first real host-side compiler slice:
;   export name = decimal_i32;
;   export name = decimal_i32 + decimal_i32;
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_compile_source
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 32

    test    rdi, rdi
    jz      .bad_argument
    test    rdx, rdx
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument

    mov     r12, rdi        ; out
    mov     r13, rsi        ; cap
    mov     r14, rdx        ; source start
    lea     r15, [rdx + rcx]; source end
    mov     rbx, r14        ; cursor

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r15
    lea     rdx, [rel wasmc_kw_export]
    mov     ecx, WASMC_KW_EXPORT_LEN
    call    _er_wasmc_expect_bytes
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_require_ws
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 48], rax ; name ptr
    mov     [rbp - 56], rcx ; name len
    mov     rbx, r8

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], '='
    jne     .parse_error
    inc     rbx

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_i32
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 60], eax ; left i32
    mov     rbx, rcx

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    xor     r11d, r11d      ; expression kind: 0 const, 1 add
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], '+'
    jne     .expect_semicolon

    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_i32
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 64], eax ; right i32
    mov     rbx, rcx
    mov     r11d, 1

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax

.expect_semicolon:
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], ';'
    jne     .parse_error
    inc     rbx

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    cmp     rax, r15
    jne     .parse_error

    test    r11d, r11d
    jnz     .emit_add
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, [rbp - 60]
    mov     rcx, [rbp - 48]
    mov     r8, [rbp - 56]
    call    er_wasmc_emit_i32_const_export
    jmp     .done

.emit_add:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, [rbp - 60]
    mov     ecx, [rbp - 64]
    mov     r8, [rbp - 48]
    mov     r9, [rbp - 56]
    call    er_wasmc_emit_i32_add_export
    jmp     .done

.bad_argument:
    xor     eax, eax
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.parse_error:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    jmp     .done
.error:
    xor     eax, eax
.done:
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

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

; er_wasmc_emit_i32_add_export(out=rdi, cap=rsi, left=edx, right=ecx, name=r8, name_len=r9)
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_emit_i32_add_export
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 32

    test    rdi, rdi
    jz      .bad_argument
    test    r8, r8
    jz      .bad_argument
    test    r9, r9
    jz      .bad_argument
    cmp     r9, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument

    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15d, ecx
    mov     rbx, r9
    mov     [rbp - 48], r8

    lea     rdi, [rbp - 56]
    mov     esi, r14d
    call    _er_wasmc_i32_sleb_len
    test    rdx, rdx
    jnz     .error
    mov     r10, rax

    lea     rdi, [rbp - 64]
    mov     esi, r15d
    call    _er_wasmc_i32_sleb_len
    test    rdx, rdx
    jnz     .error
    mov     r11, rax

    mov     rax, 34
    add     rax, rbx
    add     rax, r10
    add     rax, r11
    cmp     r13, rax
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
    mov     rsi, [rbp - 48]
    rep     movsb

    mov     byte [rdi + 0], ER_WASMC_EXPORT_FUNC
    mov     byte [rdi + 1], 0
    add     rdi, 2

    mov     byte [rdi + 0], ER_WASMC_SECTION_CODE
    lea     rax, [r10 + r11 + 7]
    mov     [rdi + 1], al
    mov     byte [rdi + 2], 1
    lea     rax, [r10 + r11 + 5]
    mov     [rdi + 3], al
    mov     byte [rdi + 4], 0
    mov     byte [rdi + 5], ER_WASMC_OP_I32_CONST
    add     rdi, 6

    lea     rsi, [rbp - 56]
    mov     rcx, r10
    rep     movsb

    mov     byte [rdi], ER_WASMC_OP_I32_CONST
    inc     rdi
    lea     rsi, [rbp - 64]
    mov     rcx, r11
    rep     movsb

    mov     byte [rdi + 0], ER_WASMC_OP_I32_ADD
    mov     byte [rdi + 1], ER_WASMC_OP_END
    add     rdi, 2

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
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_wasmc_skip_ws(cursor=rdi, end=rsi) -> rax=cursor
er_fn _er_wasmc_skip_ws
    mov     rax, rdi
.loop:
    cmp     rax, rsi
    jae     .done
    movzx   ecx, byte [rax]
    cmp     cl, ' '
    je      .advance
    cmp     cl, 9
    je      .advance
    cmp     cl, 10
    je      .advance
    cmp     cl, 13
    jne     .done
.advance:
    inc     rax
    jmp     .loop
.done:
    xor     edx, edx
    ret

; _er_wasmc_require_ws(cursor=rdi, end=rsi) -> rax=cursor_after_ws
er_fn _er_wasmc_require_ws
    cmp     rdi, rsi
    jae     .bad
    movzx   eax, byte [rdi]
    cmp     al, ' '
    je      .ok
    cmp     al, 9
    je      .ok
    cmp     al, 10
    je      .ok
    cmp     al, 13
    jne     .bad
.ok:
    call    _er_wasmc_skip_ws
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    ret

; _er_wasmc_expect_bytes(cursor=rdi, end=rsi, token=rdx, len=rcx)
; Returns rax=cursor_after_token, rdx=0.
er_fn _er_wasmc_expect_bytes
    push    rbx
    mov     rax, rdi
    mov     rbx, rdx
    test    rcx, rcx
    jz      .ok
.loop:
    cmp     rax, rsi
    jae     .bad
    movzx   edx, byte [rax]
    cmp     dl, [rbx]
    jne     .bad
    inc     rax
    inc     rbx
    dec     rcx
    jnz     .loop
.ok:
    xor     edx, edx
    pop     rbx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     rbx
    ret

; _er_wasmc_parse_ident(cursor=rdi, end=rsi)
; Returns rax=name_ptr, rcx=name_len, r8=cursor_after_name, rdx=0.
er_fn _er_wasmc_parse_ident
    cmp     rdi, rsi
    jae     .bad
    movzx   eax, byte [rdi]
    call    _er_wasmc_is_ident_start
    test    eax, eax
    jz      .bad
    mov     r8, rdi
    inc     r8
.loop:
    cmp     r8, rsi
    jae     .done
    movzx   eax, byte [r8]
    call    _er_wasmc_is_ident_continue
    test    eax, eax
    jz      .done
    inc     r8
    jmp     .loop
.done:
    mov     rcx, r8
    sub     rcx, rdi
    cmp     rcx, WASMC_MAX_SHORT_ULEB
    ja      .bad
    mov     rax, rdi
    xor     edx, edx
    ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     edx, ERROR_PARSE
    ret

; _er_wasmc_parse_i32(cursor=rdi, end=rsi)
; Returns eax=value, rcx=cursor_after_number, rdx=0.
er_fn _er_wasmc_parse_i32
    push    rbx
    mov     rbx, rdi

    cmp     rbx, rsi
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, '0'
    jb      .bad
    cmp     dl, '9'
    ja      .bad

    xor     eax, eax
.loop:
    cmp     rbx, rsi
    jae     .finish
    movzx   edx, byte [rbx]
    cmp     dl, '0'
    jb      .finish
    cmp     dl, '9'
    ja      .finish
    imul    eax, eax, 10
    sub     edx, '0'
    add     eax, edx
    inc     rbx
    jmp     .loop

.finish:
    mov     rcx, rbx
    xor     edx, edx
    pop     rbx
    ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_PARSE
    pop     rbx
    ret

; al input, eax=1 true / 0 false.
er_fn _er_wasmc_is_ident_start
    cmp     al, '_'
    je      .true
    cmp     al, 'A'
    jb      .false
    cmp     al, 'Z'
    jbe     .true
    cmp     al, 'a'
    jb      .false
    cmp     al, 'z'
    jbe     .true
.false:
    xor     eax, eax
    ret
.true:
    mov     eax, 1
    ret

; al input, eax=1 true / 0 false.
er_fn _er_wasmc_is_ident_continue
    cmp     al, '0'
    jb      _er_wasmc_is_ident_start
    cmp     al, '9'
    jbe     .true
    jmp     _er_wasmc_is_ident_start
.true:
    mov     eax, 1
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
