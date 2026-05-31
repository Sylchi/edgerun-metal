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
ER_WASMC_OP_IF          equ 0x04
ER_WASMC_OP_ELSE        equ 0x05
ER_WASMC_OP_LOCAL_GET   equ 0x20
ER_WASMC_OP_LOCAL_SET   equ 0x21
ER_WASMC_OP_I32_CONST   equ 0x41
ER_WASMC_OP_I32_EQ      equ 0x46
ER_WASMC_OP_I32_NE      equ 0x47
ER_WASMC_OP_I32_LT_S    equ 0x48
ER_WASMC_OP_I32_GT_S    equ 0x4a
ER_WASMC_OP_I32_LE_S    equ 0x4c
ER_WASMC_OP_I32_GE_S    equ 0x4e
ER_WASMC_OP_I32_ADD     equ 0x6a
ER_WASMC_OP_I32_SUB     equ 0x6b
ER_WASMC_OP_I32_MUL     equ 0x6c
ER_WASMC_OP_I32_DIV_S   equ 0x6d
ER_WASMC_OP_I32_REM_S   equ 0x6f
ER_WASMC_OP_I32_AND     equ 0x71
ER_WASMC_OP_I32_OR      equ 0x72
ER_WASMC_OP_I32_XOR     equ 0x73
ER_WASMC_OP_I32_SHL     equ 0x74
ER_WASMC_OP_I32_SHR_S   equ 0x75
ER_WASMC_OP_I32_SHR_U   equ 0x76
ER_WASMC_OP_END         equ 0x0b

WASMC_MAX_SHORT_ULEB equ 127
WASMC_I32_LITERAL_MAX_POS equ 2147483647
WASMC_I32_LITERAL_MAX_NEG_ABS equ 2147483648
WASMC_FIXED_BYTES_WITH_BODY equ 31
WASMC_COMPILE_LOCAL_BYTES equ 512
WASMC_COMPILE_BODY_OFF equ 288
WASMC_COMPILE_BODY_MAX equ 120
WASMC_COMPILE_OP_OFF equ 384
WASMC_COMPILE_OP_MAX equ 32
WASMC_COMPILE_LOCAL_TABLE_OFF equ 512
WASMC_COMPILE_LOCAL_MAX equ 8
WASMC_OP_PLUS equ '+'
WASMC_OP_MINUS equ '-'
WASMC_OP_STAR equ '*'
WASMC_OP_SLASH equ '/'
WASMC_OP_PERCENT equ '%'
WASMC_OP_AMP equ '&'
WASMC_OP_PIPE equ '|'
WASMC_OP_CARET equ '^'
WASMC_OP_BANG equ '!'
WASMC_OP_EQUAL equ '='
WASMC_OP_LT equ '<'
WASMC_OP_GT equ '>'
WASMC_OP_LPAREN equ '('
WASMC_OP_RPAREN equ ')'
WASMC_I32_RESULT_COUNT equ 1
WASMC_EXPECT_OPERAND equ 1
WASMC_EXPECT_OPERATOR equ 0
WASMC_EXPR_FINAL equ 0
WASMC_EXPR_LET equ 1
WASMC_EXPR_IF_PART equ 2
WASMC_IF_PART_COND equ 1
WASMC_IF_PART_THEN equ 2
WASMC_IF_PART_ELSE equ 3

SECTION .rodata
wasmc_kw_export: db "export"
WASMC_KW_EXPORT_LEN equ 6
wasmc_kw_let: db "let"
WASMC_KW_LET_LEN equ 3
wasmc_kw_if: db "if"
WASMC_KW_IF_LEN equ 2

SECTION .text

%ifndef ER_WASMC_NO_EXTERN_RUN
extern er_fn_run
%endif

; er_wasmc_compile_source_run(out=rdi, cap=rsi, source=rdx, source_len=rcx, runtime=r8)
; Compiles one supported source export, then interprets that exported function.
; Returns rax=i32 result, rcx=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_compile_source_run
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 48

    test    rdi, rdi
    jz      .bad_argument
    test    rdx, rdx
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument
    test    r8, r8
    jz      .bad_argument

    mov     r12, rdi        ; out
    mov     r13, rsi        ; cap
    mov     r14, rdx        ; source
    lea     r15, [rdx + rcx]; source end
    mov     rbx, r8         ; runtime

    mov     rdi, r14
    mov     rsi, r15
    call    _er_wasmc_parse_export_header
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 48], rax ; export name ptr
    mov     [rbp - 56], rcx ; export name len

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    sub     rcx, r14
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 64], rax ; bytes written

    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, rax
    mov     rcx, [rbp - 48]
    mov     r8, [rbp - 56]
    call    er_fn_run
    cmp     rdx, WASMC_I32_RESULT_COUNT
    jne     .error
    mov     rcx, [rbp - 64]
    xor     edx, edx
    jmp     .done

.bad_argument:
    xor     eax, eax
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.error:
    xor     eax, eax
.done:
    add     rsp, 48
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; er_wasmc_compile_source(out=rdi, cap=rsi, source=rdx, source_len=rcx)
; Source form for the first real host-side compiler slice:
;   export name = signed_i32;
;   export name = signed_i32 + signed_i32;
;   export name = signed_i32 - signed_i32;
;   export name = signed_i32 * signed_i32;
;   export name = signed_i32 / signed_i32;
;   export name = signed_i32 & signed_i32;
;   export name = signed_i32 | signed_i32;
;   export name = signed_i32 ^ signed_i32;
;   export name = signed_i32 << signed_i32;
;   export name = signed_i32 >> signed_i32;
;   export name = signed_i32 >>> signed_i32;
;   export name = signed_i32 == signed_i32;
;   export name = let x = signed_i32; x + signed_i32;
;   export name = if (condition) (then_expr) (else_expr);
; Operators may be chained. Precedence is *, /, % then +, - then <<, >>, >>>
; then comparisons, &, ^, |.
; Operators with equal precedence are emitted left-associatively.
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_compile_source
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, WASMC_COMPILE_LOCAL_BYTES

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

    mov     rdi, r14
    mov     rsi, r15
    call    _er_wasmc_parse_export_header
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

    lea     r10, [rbp - WASMC_COMPILE_BODY_OFF]
    mov     [rbp - 64], r10 ; body ptr
    xor     r11d, r11d
    mov     [rbp - 72], r11 ; body len
    mov     [rbp - 96], r11 ; operator stack len
    mov     [rbp - 112], r11 ; local count
    mov     byte [rbp - 104], WASMC_EXPECT_OPERAND

.let_scan:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    lea     rdi, [rel wasmc_kw_let]
    mov     esi, WASMC_KW_LET_LEN
    mov     rdx, rbx
    mov     rcx, r15
    call    _er_wasmc_match_keyword
    test    rdx, rdx
    jnz     .try_if_expr

    mov     rdi, rax
    mov     rsi, r15
    call    _er_wasmc_require_ws
    test    rdx, rdx
    jnz     .parse_error
    mov     rdi, rax
    mov     rsi, r15
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 136], rax ; pending local name ptr
    mov     [rbp - 144], rcx ; pending local name len
    mov     rbx, r8

    lea     rdi, [rbp - WASMC_COMPILE_LOCAL_TABLE_OFF]
    mov     rsi, [rbp - 112]
    mov     rdx, [rbp - 136]
    mov     rcx, [rbp - 144]
    call    _er_wasmc_find_local
    test    rdx, rdx
    jz      .parse_error

    mov     r10, [rbp - 112]
    cmp     r10, WASMC_COMPILE_LOCAL_MAX
    jae     .no_space
    mov     [rbp - 128], r10 ; pending local index

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], '='
    jne     .parse_error
    inc     rbx

    xor     r11d, r11d
    mov     [rbp - 96], r11
    mov     byte [rbp - 104], WASMC_EXPECT_OPERAND
    mov     byte [rbp - 120], WASMC_EXPR_LET
    jmp     .expr_loop

.try_if_expr:
    lea     rdi, [rel wasmc_kw_if]
    mov     esi, WASMC_KW_IF_LEN
    mov     rdx, rbx
    mov     rcx, r15
    call    _er_wasmc_match_keyword
    test    rdx, rdx
    jnz     .start_final_expr

    mov     rbx, rax
    mov     byte [rbp - 160], WASMC_IF_PART_COND
    jmp     .start_if_part

.start_final_expr:
    xor     r11d, r11d
    mov     [rbp - 96], r11
    mov     byte [rbp - 104], WASMC_EXPECT_OPERAND
    mov     byte [rbp - 120], WASMC_EXPR_FINAL

.expr_loop:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    movzx   eax, byte [rbx]

    cmp     byte [rbp - 104], WASMC_EXPECT_OPERAND
    je      .expect_operand_token

    cmp     al, ';'
    je      .expect_semicolon
    cmp     al, WASMC_OP_RPAREN
    je      .close_group
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_operator_info
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 80], al ; wasm opcode
    mov     [rbp - 81], cl ; precedence
    mov     [rbp - 82], r8b ; source operator length

.flush_for_precedence:
    mov     r10, [rbp - 96]
    test    r10, r10
    jz      .push_operator
    dec     r10
    lea     r11, [rbp - WASMC_COMPILE_OP_OFF]
    cmp     byte [r11 + r10 * 2], 0
    je      .push_operator
    movzx   eax, byte [r11 + r10 * 2 + 1]
    cmp     al, [rbp - 81]
    jb      .push_operator

    movzx   edx, byte [r11 + r10 * 2]
    mov     [rbp - 96], r10
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    jmp     .flush_for_precedence

.push_operator:
    mov     r10, [rbp - 96]
    cmp     r10, WASMC_COMPILE_OP_MAX
    jae     .no_space
    lea     r11, [rbp - WASMC_COMPILE_OP_OFF]
    mov     al, [rbp - 80]
    mov     [r11 + r10 * 2], al
    mov     al, [rbp - 81]
    mov     [r11 + r10 * 2 + 1], al
    inc     r10
    mov     [rbp - 96], r10
    movzx   eax, byte [rbp - 82]
    add     rbx, rax
    mov     byte [rbp - 104], WASMC_EXPECT_OPERAND
    jmp     .expr_loop

.expect_operand_token:
    cmp     al, WASMC_OP_LPAREN
    je      .open_group

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_i32
    test    rdx, rdx
    jnz     .try_local_operand
    mov     [rbp - 88], rcx ; cursor after number
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    mov     edx, eax
    call    _er_wasmc_emit_body_i32_const
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    mov     rbx, [rbp - 88]
    mov     byte [rbp - 104], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.try_local_operand:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 88], r8 ; cursor after ident
    lea     rdi, [rbp - WASMC_COMPILE_LOCAL_TABLE_OFF]
    mov     rsi, [rbp - 112]
    mov     rdx, rax
    call    _er_wasmc_find_local
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 152], rax
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    mov     edx, ER_WASMC_OP_LOCAL_GET
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, [rbp - 64]
    mov     rsi, rax
    mov     edx, [rbp - 152]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    mov     rbx, [rbp - 88]
    mov     byte [rbp - 104], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.open_group:
    mov     r10, [rbp - 96]
    cmp     r10, WASMC_COMPILE_OP_MAX
    jae     .no_space
    lea     r11, [rbp - WASMC_COMPILE_OP_OFF]
    mov     byte [r11 + r10 * 2], 0
    mov     byte [r11 + r10 * 2 + 1], 0
    inc     r10
    mov     [rbp - 96], r10
    inc     rbx
    jmp     .expr_loop

.close_group:
    cmp     byte [rbp - 104], WASMC_EXPECT_OPERAND
    je      .parse_error
.flush_group:
    mov     r10, [rbp - 96]
    test    r10, r10
    jz      .parse_error
    dec     r10
    lea     r11, [rbp - WASMC_COMPILE_OP_OFF]
    movzx   edx, byte [r11 + r10 * 2]
    test    dl, dl
    jz      .pop_group
    mov     [rbp - 96], r10
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    jmp     .flush_group
.pop_group:
    mov     [rbp - 96], r10
    inc     rbx
    cmp     byte [rbp - 120], WASMC_EXPR_IF_PART
    jne     .group_continues
    test    r10, r10
    jz      .finish_if_part
.group_continues:
    mov     byte [rbp - 104], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.finish_if_part:
    cmp     byte [rbp - 160], WASMC_IF_PART_COND
    je      .finish_if_cond
    cmp     byte [rbp - 160], WASMC_IF_PART_THEN
    je      .finish_if_then
    cmp     byte [rbp - 160], WASMC_IF_PART_ELSE
    je      .finish_if_else
    jmp     .parse_error

.finish_if_cond:
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    mov     edx, ER_WASMC_OP_IF
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, [rbp - 64]
    mov     rsi, rax
    mov     edx, ER_WASMC_TYPE_I32
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    mov     byte [rbp - 160], WASMC_IF_PART_THEN
    jmp     .start_if_part

.finish_if_then:
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    mov     edx, ER_WASMC_OP_ELSE
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    mov     byte [rbp - 160], WASMC_IF_PART_ELSE
    jmp     .start_if_part

.finish_if_else:
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    mov     edx, ER_WASMC_OP_END
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    cmp     rax, r15
    jae     .parse_error
    cmp     byte [rax], ';'
    jne     .parse_error
    inc     rax
    mov     rdi, rax
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    cmp     rax, r15
    jne     .parse_error
    jmp     .emit_module

.start_if_part:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], WASMC_OP_LPAREN
    jne     .parse_error
    xor     r11d, r11d
    mov     [rbp - 96], r11
    mov     byte [rbp - 104], WASMC_EXPECT_OPERAND
    mov     byte [rbp - 120], WASMC_EXPR_IF_PART
    jmp     .expr_loop

.expect_semicolon:
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], ';'
    jne     .parse_error
    inc     rbx

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    cmp     byte [rbp - 120], WASMC_EXPR_LET
    je      .after_semicolon
    cmp     rax, r15
    jne     .parse_error
.after_semicolon:
    mov     rbx, rax

.flush_remaining:
    mov     r10, [rbp - 96]
    test    r10, r10
    jz      .finish_expression
    dec     r10
    lea     r11, [rbp - WASMC_COMPILE_OP_OFF]
    movzx   edx, byte [r11 + r10 * 2]
    test    dl, dl
    jz      .parse_error
    mov     [rbp - 96], r10
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax
    jmp     .flush_remaining

.finish_expression:
    cmp     byte [rbp - 120], WASMC_EXPR_LET
    je      .finish_let
    jmp     .emit_module

.finish_let:
    mov     rdi, [rbp - 64]
    mov     rsi, [rbp - 72]
    mov     edx, ER_WASMC_OP_LOCAL_SET
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, [rbp - 64]
    mov     rsi, rax
    mov     edx, [rbp - 128]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 72], rax

    mov     r10, [rbp - 112]
    lea     r11, [rbp - WASMC_COMPILE_LOCAL_TABLE_OFF]
    mov     rcx, r10
    shl     rcx, 4
    mov     rax, [rbp - 136]
    mov     [r11 + rcx], rax
    mov     rax, [rbp - 144]
    mov     [r11 + rcx + 8], rax
    inc     r10
    mov     [rbp - 112], r10
    jmp     .let_scan

.emit_module:
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rbp - 64]
    mov     rcx, [rbp - 72]
    mov     r8, [rbp - 48]
    mov     r9, [rbp - 56]
    mov     r10, [rbp - 112]
    call    er_wasmc_emit_i32_locals_body_export
    jmp     .done

.bad_argument:
    xor     eax, eax
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.parse_error:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    jmp     .done
.no_space:
    xor     eax, eax
    mov     edx, ERROR_NO_SPACE
    jmp     .done
.error:
    xor     eax, eax
.done:
    add     rsp, WASMC_COMPILE_LOCAL_BYTES
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_wasmc_parse_export_header(cursor=rdi, end=rsi)
; Returns rax=name_ptr, rcx=name_len, r8=cursor_after_name, rdx=0.
er_fn _er_wasmc_parse_export_header
    push    rbx
    mov     rbx, rsi

    call    _er_wasmc_skip_ws

    mov     rdi, rax
    mov     rsi, rbx
    lea     rdx, [rel wasmc_kw_export]
    mov     ecx, WASMC_KW_EXPORT_LEN
    call    _er_wasmc_expect_bytes
    test    rdx, rdx
    jnz     .bad

    mov     rdi, rax
    mov     rsi, rbx
    call    _er_wasmc_require_ws
    test    rdx, rdx
    jnz     .bad

    mov     rdi, rax
    mov     rsi, rbx
    call    _er_wasmc_parse_ident
    pop     rbx
    ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    pop     rbx
    ret

; _er_wasmc_match_keyword(token=rdi, len=rsi, cursor=rdx, end=rcx)
; Returns rax=cursor_after_keyword, rdx=0 on a bounded keyword match.
er_fn _er_wasmc_match_keyword
    push    rbx
    push    r12
    mov     rbx, rdi
    mov     r12, rsi
    mov     rax, rdx
    test    r12, r12
    jz      .bad
.loop:
    cmp     rax, rcx
    jae     .bad
    movzx   edx, byte [rax]
    cmp     dl, [rbx]
    jne     .bad
    inc     rax
    inc     rbx
    dec     r12
    jnz     .loop
    cmp     rax, rcx
    jae     .ok
    mov     r11, rax
    movzx   eax, byte [rax]
    call    _er_wasmc_is_ident_continue
    test    eax, eax
    jnz     .bad
    mov     rax, r11
.ok:
    xor     edx, edx
    pop     r12
    pop     rbx
    ret
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    pop     r12
    pop     rbx
    ret

; _er_wasmc_find_local(table=rdi, count=rsi, name=rdx, name_len=rcx)
; Returns rax=index, rdx=0 when found; rdx=ERROR_PARSE when missing.
er_fn _er_wasmc_find_local
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    xor     r15d, r15d
.next:
    cmp     r15, r12
    jae     .missing
    mov     rax, r15
    shl     rax, 4
    mov     rax, [rbx + rax + 8]
    cmp     rax, r14
    jne     .advance
    mov     rax, r15
    shl     rax, 4
    mov     rdi, [rbx + rax]
    mov     rsi, r13
    mov     rcx, r14
.compare:
    test    rcx, rcx
    jz      .found
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .advance
    inc     rdi
    inc     rsi
    dec     rcx
    jmp     .compare
.advance:
    inc     r15
    jmp     .next
.found:
    mov     rax, r15
    xor     edx, edx
    jmp     .done
.missing:
    xor     eax, eax
    mov     edx, ERROR_PARSE
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _er_wasmc_operator_info(cursor=rdi, end=rsi)
; Returns al=WASM opcode, cl=precedence, r8=source length, rdx=0 on success.
er_fn _er_wasmc_operator_info
    cmp     rdi, rsi
    jae     .bad
    movzx   eax, byte [rdi]
    mov     r8d, 1
    cmp     al, WASMC_OP_PLUS
    je      .add
    cmp     al, WASMC_OP_MINUS
    je      .sub
    cmp     al, WASMC_OP_STAR
    je      .mul
    cmp     al, WASMC_OP_SLASH
    je      .div_s
    cmp     al, WASMC_OP_PERCENT
    je      .rem_s
    cmp     al, WASMC_OP_AMP
    je      .and
    cmp     al, WASMC_OP_PIPE
    je      .or
    cmp     al, WASMC_OP_CARET
    je      .xor
    cmp     al, WASMC_OP_EQUAL
    je      .eq_match
    cmp     al, WASMC_OP_BANG
    je      .ne_match
.shift_left_match:
    cmp     al, WASMC_OP_LT
    jne     .shift_right_match
    lea     r9, [rdi + 1]
    cmp     r9, rsi
    jae     .bad
    cmp     byte [r9], WASMC_OP_LT
    je      .shl
    cmp     byte [r9], WASMC_OP_EQUAL
    je      .le_s
    jmp     .lt_s
.shift_right_match:
    cmp     al, WASMC_OP_GT
    jne     .bad
    lea     r9, [rdi + 1]
    cmp     r9, rsi
    jae     .gt_s
    cmp     byte [r9], WASMC_OP_GT
    jne     .gt_or_ge
    lea     r10, [rdi + 2]
    cmp     r10, rsi
    jae     .shr_s
    cmp     byte [r10], WASMC_OP_GT
    je      .shr_u
    jmp     .shr_s
.gt_or_ge:
    cmp     byte [r9], WASMC_OP_EQUAL
    je      .ge_s
    jmp     .gt_s
.eq_match:
    lea     r9, [rdi + 1]
    cmp     r9, rsi
    jae     .bad
    cmp     byte [r9], WASMC_OP_EQUAL
    je      .eq
    jmp     .bad
.ne_match:
    lea     r9, [rdi + 1]
    cmp     r9, rsi
    jae     .bad
    cmp     byte [r9], WASMC_OP_EQUAL
    je      .ne
    jmp     .bad
.bad:
    xor     eax, eax
    mov     edx, ERROR_PARSE
    ret
.add:
    mov     al, ER_WASMC_OP_I32_ADD
    mov     cl, 5
    jmp     .ok
.sub:
    mov     al, ER_WASMC_OP_I32_SUB
    mov     cl, 5
    jmp     .ok
.mul:
    mov     al, ER_WASMC_OP_I32_MUL
    mov     cl, 6
    jmp     .ok
.div_s:
    mov     al, ER_WASMC_OP_I32_DIV_S
    mov     cl, 6
    jmp     .ok
.rem_s:
    mov     al, ER_WASMC_OP_I32_REM_S
    mov     cl, 6
    jmp     .ok
.shl:
    mov     al, ER_WASMC_OP_I32_SHL
    mov     cl, 4
    jmp     .ok_two
.shr_s:
    mov     al, ER_WASMC_OP_I32_SHR_S
    mov     cl, 4
    jmp     .ok_two
.shr_u:
    mov     al, ER_WASMC_OP_I32_SHR_U
    mov     cl, 4
    mov     r8d, 3
    jmp     .ok
.eq:
    mov     al, ER_WASMC_OP_I32_EQ
    mov     cl, 3
    jmp     .ok_two
.ne:
    mov     al, ER_WASMC_OP_I32_NE
    mov     cl, 3
    jmp     .ok_two
.lt_s:
    mov     al, ER_WASMC_OP_I32_LT_S
    mov     cl, 3
    jmp     .ok
.gt_s:
    mov     al, ER_WASMC_OP_I32_GT_S
    mov     cl, 3
    jmp     .ok
.le_s:
    mov     al, ER_WASMC_OP_I32_LE_S
    mov     cl, 3
    jmp     .ok_two
.ge_s:
    mov     al, ER_WASMC_OP_I32_GE_S
    mov     cl, 3
    jmp     .ok_two
.ok_two:
    mov     r8d, 2
    jmp     .ok
.and:
    mov     al, ER_WASMC_OP_I32_AND
    mov     cl, 2
    jmp     .ok
.or:
    mov     al, ER_WASMC_OP_I32_OR
    mov     cl, 0
    jmp     .ok
.xor:
    mov     al, ER_WASMC_OP_I32_XOR
    mov     cl, 1
.ok:
    xor     edx, edx
    ret

; _er_wasmc_emit_body_byte(body=rdi, len=rsi, value=dl)
; Returns rax=new_len, rdx=0.
er_fn _er_wasmc_emit_body_byte
    cmp     rsi, WASMC_COMPILE_BODY_MAX
    jae     .no_space
    mov     [rdi + rsi], dl
    lea     rax, [rsi + 1]
    xor     edx, edx
    ret
.no_space:
    xor     eax, eax
    mov     edx, ERROR_NO_SPACE
    ret

; _er_wasmc_emit_body_i32_const(body=rdi, len=rsi, value=edx)
; Returns rax=new_len, rdx=0.
er_fn _er_wasmc_emit_body_i32_const
    er_frame_push
    push    rbx
    push    r12
    push    r13
    sub     rsp, 16

    mov     r12, rdi
    mov     r13, rsi
    mov     ebx, edx
    cmp     r13, WASMC_COMPILE_BODY_MAX - 6
    ja      .no_space

    mov     byte [r12 + r13], ER_WASMC_OP_I32_CONST
    lea     rdi, [r12 + r13 + 1]
    mov     esi, ebx
    call    _er_wasmc_i32_sleb_len
    test    rdx, rdx
    jnz     .error
    lea     rax, [r13 + rax + 1]
    jmp     .done
.no_space:
    xor     eax, eax
    mov     edx, ERROR_NO_SPACE
    jmp     .done
.error:
    xor     eax, eax
.done:
    add     rsp, 16
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; er_wasmc_emit_i32_body_export(out=rdi, cap=rsi, body=rdx, body_len=rcx, name=r8, name_len=r9)
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_emit_i32_body_export
    xor     r10d, r10d
    jmp     er_wasmc_emit_i32_locals_body_export

; er_wasmc_emit_i32_locals_body_export(out=rdi, cap=rsi, body=rdx, body_len=rcx, name=r8, name_len=r9, local_count=r10)
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_emit_i32_locals_body_export
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16

    test    rdi, rdi
    jz      .bad_argument
    test    rdx, rdx
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument
    cmp     rcx, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument
    test    r8, r8
    jz      .bad_argument
    test    r9, r9
    jz      .bad_argument
    cmp     r9, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument
    cmp     r10, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument

    mov     r12, rdi
    mov     r13, rsi
    mov     [rbp - 48], rdx ; body ptr
    mov     r14, rcx
    mov     r15, r8
    mov     rbx, r9
    mov     [rbp - 56], r10 ; local count

    mov     rax, WASMC_FIXED_BYTES_WITH_BODY
    add     rax, rbx
    add     rax, r14
    cmp     qword [rbp - 56], 0
    je      .have_total_size
    add     rax, 2
.have_total_size:
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
    mov     rsi, r15
    rep     movsb

    mov     byte [rdi + 0], ER_WASMC_EXPORT_FUNC
    mov     byte [rdi + 1], 0
    add     rdi, 2

    mov     byte [rdi + 0], ER_WASMC_SECTION_CODE
    lea     rax, [r14 + 4]
    cmp     qword [rbp - 56], 0
    je      .store_code_section_size
    add     rax, 2
.store_code_section_size:
    mov     [rdi + 1], al
    mov     byte [rdi + 2], 1
    lea     rax, [r14 + 2]
    cmp     qword [rbp - 56], 0
    je      .store_function_body_size
    add     rax, 2
.store_function_body_size:
    mov     [rdi + 3], al
    cmp     qword [rbp - 56], 0
    jne     .write_locals
    mov     byte [rdi + 4], 0
    add     rdi, 5
    jmp     .copy_body
.write_locals:
    mov     byte [rdi + 4], 1
    mov     rax, [rbp - 56]
    mov     [rdi + 5], al
    mov     byte [rdi + 6], ER_WASMC_TYPE_I32
    add     rdi, 7

.copy_body:
    mov     rcx, r14
    mov     rsi, [rbp - 48]
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
.done:
    add     rsp, 16
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
    xor     esi, esi
    mov     edx, r14d
    call    _er_wasmc_emit_body_i32_const
    test    rdx, rdx
    jnz     .error
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rbp - 48]
    mov     rcx, rax
    mov     r8, r15
    mov     r9, rbx
    call    er_wasmc_emit_i32_body_export
    jmp     .done

.bad_argument:
    xor     eax, eax
    mov     edx, ERROR_BAD_ARGUMENT
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

; er_wasmc_emit_i32_binary_export(out=rdi, cap=rsi, left=edx, right=ecx, name=r8, name_len=r9, opcode=r10b)
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_emit_i32_binary_export
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
    mov     [rbp - 72], r10b

    lea     rdi, [rbp - 56]
    xor     esi, esi
    mov     edx, r14d
    call    _er_wasmc_emit_body_i32_const
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 80], rax

    lea     rdi, [rbp - 56]
    mov     rsi, [rbp - 80]
    mov     edx, r15d
    call    _er_wasmc_emit_body_i32_const
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 80], rax

    lea     rdi, [rbp - 56]
    mov     rsi, [rbp - 80]
    mov     al, [rbp - 72]
    mov     dl, al
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 80], rax

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rbp - 56]
    mov     rcx, [rbp - 80]
    mov     r8, [rbp - 48]
    mov     r9, rbx
    call    er_wasmc_emit_i32_body_export
    jmp     .done

.bad_argument:
    xor     eax, eax
    mov     edx, ERROR_BAD_ARGUMENT
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
    push    r12
    push    r13
    mov     rbx, rdi
    xor     r12d, r12d
    mov     r13d, WASMC_I32_LITERAL_MAX_POS

    cmp     rbx, rsi
    jae     .bad
    cmp     byte [rbx], '-'
    jne     .digits
    mov     r12d, 1
    mov     r13d, WASMC_I32_LITERAL_MAX_NEG_ABS
    inc     rbx

.digits:
    cmp     rbx, rsi
    jae     .bad
    movzx   edx, byte [rbx]
    cmp     dl, '0'
    jb      .bad
    cmp     dl, '9'
    ja      .bad
    cmp     dl, '0'
    jne     .decimal_start
    lea     r9, [rbx + 1]
    cmp     r9, rsi
    jae     .decimal_start
    movzx   edx, byte [r9]
    cmp     dl, 'x'
    je      .hex_prefix
    cmp     dl, 'X'
    jne     .decimal_start

.hex_prefix:
    lea     rbx, [rbx + 2]
    xor     eax, eax
    xor     r8d, r8d
.hex_loop:
    cmp     rbx, rsi
    jae     .hex_finish
    movzx   edx, byte [rbx]
    cmp     dl, '0'
    jb      .hex_finish
    cmp     dl, '9'
    jbe     .hex_digit
    cmp     dl, 'A'
    jb      .hex_finish
    cmp     dl, 'F'
    jbe     .hex_upper
    cmp     dl, 'a'
    jb      .hex_finish
    cmp     dl, 'f'
    ja      .hex_finish
    sub     edx, 'a' - 10
    jmp     .hex_append
.hex_upper:
    sub     edx, 'A' - 10
    jmp     .hex_append
.hex_digit:
    sub     edx, '0'
.hex_append:
    mov     ecx, eax
    shl     rcx, 4
    add     rcx, rdx
    cmp     rcx, r13
    ja      .bad
    mov     eax, ecx
    inc     r8d
    inc     rbx
    jmp     .hex_loop
.hex_finish:
    test    r8d, r8d
    jz      .bad
    jmp     .finish

.decimal_start:
    xor     eax, eax
.decimal_loop:
    cmp     rbx, rsi
    jae     .finish
    movzx   edx, byte [rbx]
    cmp     dl, '0'
    jb      .finish
    cmp     dl, '9'
    ja      .finish
    sub     edx, '0'
    mov     ecx, eax
    imul    ecx, ecx, 10
    jc      .bad
    add     ecx, edx
    jc      .bad
    cmp     rcx, r13
    ja      .bad
    mov     eax, ecx
    inc     rbx
    jmp     .decimal_loop

.finish:
    test    r12d, r12d
    jz      .ok
    neg     eax
.ok:
    mov     rcx, rbx
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbx
    ret
.bad:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_PARSE
    pop     r13
    pop     r12
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
