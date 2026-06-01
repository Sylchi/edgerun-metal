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
ER_WASMC_OP_CALL        equ 0x10
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
WASMC_COMPILE_FUNC_MAX equ 4
WASMC_COMPILE_FUNC_BODY_STRIDE equ 128
WASMC_COMPILE_MULTI_SYMBOL_OFF equ 320
WASMC_COMPILE_MULTI_BODY_TABLE_OFF equ 448
WASMC_COMPILE_MULTI_SIG_TABLE_OFF equ 512
WASMC_COMPILE_MULTI_LOCAL_TABLE_OFF equ 1024
WASMC_COMPILE_MULTI_LOCAL_STRIDE equ 128
WASMC_COMPILE_MULTI_BODY_OFF equ 1536
WASMC_COMPILE_MULTI_OP_OFF equ 2048
WASMC_COMPILE_MULTI_LOCAL_BYTES equ 2304
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
WASMC_OP_COMMA equ ','
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
    mov     r9, r8

.run_export_scan_loop:
    cmp     r9, r15
    jae     .compile_source
    cmp     byte [r9], ';'
    je      .try_run_export
    inc     r9
    jmp     .run_export_scan_loop

.try_run_export:
    inc     r9
    mov     rdi, r9
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     r9, rax
    mov     rdi, rax
    mov     rsi, r15
    call    _er_wasmc_parse_export_header
    test    rdx, rdx
    jnz     .run_export_scan_loop
    mov     [rbp - 48], rax ; runnable export name ptr
    mov     [rbp - 56], rcx ; runnable export name len
    mov     r9, r8
    jmp     .run_export_scan_loop

.compile_source:
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

; er_wasmc_compile_call_source(out=rdi, cap=rsi, source=rdx, source_len=rcx)
; Source form:
;   export fn0 = i32_expr; export fn1 = i32_expr; ...
; Later functions may call earlier functions as zero-arg direct calls.
; Emits a multi-function module exporting the final function.
; Returns rax=bytes_written, rdx=0.
er_fn er_wasmc_compile_call_source
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, WASMC_COMPILE_MULTI_LOCAL_BYTES

    test    rdi, rdi
    jz      .bad_argument
    test    rdx, rdx
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    lea     r15, [rdx + rcx]
    mov     rbx, r14
    xor     eax, eax
    mov     [rbp - 48], rax

.parse_export_loop:
    mov     rax, [rbp - 48]
    cmp     rax, WASMC_COMPILE_FUNC_MAX
    jae     .no_space

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_export_header
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 88], rax ; current name ptr
    mov     [rbp - 96], rcx ; current name len
    mov     rbx, r8

    xor     r10d, r10d
.duplicate_loop:
    cmp     r10, [rbp - 48]
    jae     .name_unique
    mov     rax, r10
    shl     rax, 5
    mov     rdx, [rbp - 96]
    cmp     rdx, [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax + 8]
    jne     .next_duplicate
    mov     rdi, [rbp - 88]
    mov     rsi, [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax]
    mov     rcx, rdx
.duplicate_name_compare:
    test    rcx, rcx
    jz      .parse_error
    mov     dl, [rdi]
    cmp     dl, [rsi]
    jne     .next_duplicate
    inc     rdi
    inc     rsi
    dec     rcx
    jmp     .duplicate_name_compare
.next_duplicate:
    inc     r10
    jmp     .duplicate_loop
.name_unique:

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    mov     r10, [rbp - 48]
    mov     rax, r10
    shl     rax, 7
    lea     r11, [rbp - WASMC_COMPILE_MULTI_LOCAL_TABLE_OFF + rax]
    mov     [rbp - 112], r11 ; current local table
    xor     eax, eax
    mov     [rbp - 120], rax ; current local count
    mov     [rbp - 128], rax ; current param count
    cmp     byte [rbx], WASMC_OP_LPAREN
    je      .parse_multi_param_list
.after_multi_params:
    cmp     byte [rbx], '='
    jne     .parse_error
    inc     rbx
    jmp     .after_multi_equals

.parse_multi_param_list:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], WASMC_OP_RPAREN
    je      .finish_empty_multi_param_list
.multi_param_loop:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 136], rax
    mov     [rbp - 144], rcx
    mov     rbx, r8

    mov     rdi, [rbp - 112]
    mov     rsi, [rbp - 120]
    mov     rdx, [rbp - 136]
    mov     rcx, [rbp - 144]
    call    _er_wasmc_find_local
    test    rdx, rdx
    jz      .parse_error

    mov     r10, [rbp - 120]
    cmp     r10, WASMC_COMPILE_LOCAL_MAX
    jae     .no_space
    mov     r11, [rbp - 112]
    mov     rcx, r10
    shl     rcx, 4
    mov     rax, [rbp - 136]
    mov     [r11 + rcx], rax
    mov     rax, [rbp - 144]
    mov     [r11 + rcx + 8], rax
    inc     r10
    mov     [rbp - 120], r10
    mov     [rbp - 128], r10

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], WASMC_OP_COMMA
    je      .next_multi_param
    cmp     byte [rbx], WASMC_OP_RPAREN
    je      .finish_multi_param_list
    jmp     .parse_error
.next_multi_param:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    jmp     .multi_param_loop
.finish_empty_multi_param_list:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    jmp     .after_multi_params
.finish_multi_param_list:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    jmp     .after_multi_params

.after_multi_equals:
    mov     rax, [rbp - 48]
    shl     rax, 7
    lea     r11, [rbp - WASMC_COMPILE_MULTI_BODY_OFF + rax]
    mov     [rbp - 152], r11 ; current body ptr
    xor     eax, eax
    mov     [rbp - 104], rax ; current body len

.multi_let_scan:
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
    jnz     .emit_multi_final_expr

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

    mov     rdi, [rbp - 112]
    mov     rsi, [rbp - 120]
    mov     rdx, [rbp - 136]
    mov     rcx, [rbp - 144]
    call    _er_wasmc_find_local
    test    rdx, rdx
    jz      .parse_error

    mov     r10, [rbp - 120]
    cmp     r10, WASMC_COMPILE_LOCAL_MAX
    jae     .no_space
    mov     [rbp - 160], r10 ; pending local index

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], '='
    jne     .parse_error
    inc     rbx

    mov     rdi, [rbp - 152]
    add     rdi, [rbp - 104]
    mov     rsi, rbx
    mov     rdx, r15
    lea     rcx, [rbp - WASMC_COMPILE_MULTI_OP_OFF]
    lea     r8, [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF]
    mov     r9, [rbp - 48]
    mov     r10, [rbp - 112]
    mov     r11, [rbp - 120]
    call    _er_wasmc_emit_i32_multi_expr_until_semicolon
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    add     [rbp - 104], rcx

    mov     rdi, [rbp - 152]
    mov     rsi, [rbp - 104]
    mov     edx, ER_WASMC_OP_LOCAL_SET
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, [rbp - 152]
    mov     rsi, rax
    mov     edx, [rbp - 160]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 104], rax

    mov     r10, [rbp - 120]
    mov     r11, [rbp - 112]
    mov     rcx, r10
    shl     rcx, 4
    mov     rax, [rbp - 136]
    mov     [r11 + rcx], rax
    mov     rax, [rbp - 144]
    mov     [r11 + rcx + 8], rax
    inc     r10
    mov     [rbp - 120], r10
    jmp     .multi_let_scan

.emit_multi_final_expr:
    mov     rdi, [rbp - 152]
    add     rdi, [rbp - 104]
    mov     rsi, rbx
    mov     rdx, r15
    lea     rcx, [rbp - WASMC_COMPILE_MULTI_OP_OFF]
    lea     r8, [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF]
    mov     r9, [rbp - 48]
    mov     r10, [rbp - 112]
    mov     r11, [rbp - 120]
    call    _er_wasmc_emit_i32_multi_expr_until_semicolon
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    add     [rbp - 104], rcx

    mov     r10, [rbp - 48]
    mov     rax, r10
    shl     rax, 7
    lea     rdx, [rbp - WASMC_COMPILE_MULTI_BODY_OFF + rax]
    mov     rax, r10
    shl     rax, 4
    mov     [rbp - WASMC_COMPILE_MULTI_BODY_TABLE_OFF + rax], rdx
    mov     rdx, [rbp - 104]
    mov     [rbp - WASMC_COMPILE_MULTI_BODY_TABLE_OFF + rax + 8], rdx

    mov     rax, r10
    shl     rax, 5
    mov     rdx, [rbp - 88]
    mov     [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax], rdx
    mov     rdx, [rbp - 96]
    mov     [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax + 8], rdx
    mov     [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax + 16], r10
    mov     rdx, [rbp - 128]
    mov     [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax + 24], rdx
    mov     rax, r10
    shl     rax, 4
    mov     rdx, [rbp - 128]
    mov     [rbp - WASMC_COMPILE_MULTI_SIG_TABLE_OFF + rax], rdx
    mov     rdx, [rbp - 120]
    sub     rdx, [rbp - 128]
    mov     [rbp - WASMC_COMPILE_MULTI_SIG_TABLE_OFF + rax + 8], rdx
    inc     r10
    mov     [rbp - 48], r10

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jne     .parse_export_loop

    mov     r10, [rbp - 48]
    cmp     r10, 2
    jb      .parse_error
    dec     r10
    mov     rax, r10
    shl     rax, 5

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rbp - WASMC_COMPILE_MULTI_BODY_TABLE_OFF]
    mov     rcx, [rbp - 48]
    mov     r8, [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax]
    mov     r9, [rbp - WASMC_COMPILE_MULTI_SYMBOL_OFF + rax + 8]
    lea     r11, [rbp - WASMC_COMPILE_MULTI_SIG_TABLE_OFF]
    call    er_wasmc_emit_i32_sig_body_table_export
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
    add     rsp, WASMC_COMPILE_MULTI_LOCAL_BYTES
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

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    sub     rcx, r14
    call    er_wasmc_compile_call_source
    test    rdx, rdx
    jz      .done
    cmp     rdx, ERROR_PARSE
    jne     .error

    mov     rdi, r14
    mov     rsi, r15
    call    _er_wasmc_parse_export_header
    test    rdx, rdx
    jnz     .error
    mov     [rbp - 48], rax ; name ptr
    mov     [rbp - 56], rcx ; name len
    mov     rbx, r8
    xor     r11d, r11d
    mov     [rbp - 112], r11 ; local count, including params
    mov     [rbp - 168], r11 ; param count

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], WASMC_OP_LPAREN
    je      .parse_param_list
.expect_export_equals:
    cmp     byte [rbx], '='
    jne     .parse_error
    inc     rbx
    jmp     .after_export_equals

.parse_param_list:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], WASMC_OP_RPAREN
    je      .finish_empty_param_list
.param_loop:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 136], rax ; pending param name ptr
    mov     [rbp - 144], rcx ; pending param name len
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
    lea     r11, [rbp - WASMC_COMPILE_LOCAL_TABLE_OFF]
    mov     rcx, r10
    shl     rcx, 4
    mov     rax, [rbp - 136]
    mov     [r11 + rcx], rax
    mov     rax, [rbp - 144]
    mov     [r11 + rcx + 8], rax
    inc     r10
    mov     [rbp - 112], r10
    mov     [rbp - 168], r10

    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    cmp     byte [rbx], WASMC_OP_COMMA
    je      .next_param
    cmp     byte [rbx], WASMC_OP_RPAREN
    je      .finish_param_list
    jmp     .parse_error
.next_param:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    jmp     .param_loop
.finish_empty_param_list:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    jmp     .expect_export_equals
.finish_param_list:
    inc     rbx
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax
    cmp     rbx, r15
    jae     .parse_error
    jmp     .expect_export_equals

.after_export_equals:
    mov     rdi, rbx
    mov     rsi, r15
    call    _er_wasmc_skip_ws
    mov     rbx, rax

    lea     r10, [rbp - WASMC_COMPILE_BODY_OFF]
    mov     [rbp - 64], r10 ; body ptr
    xor     r11d, r11d
    mov     [rbp - 72], r11 ; body len
    mov     [rbp - 96], r11 ; operator stack len
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
    sub     r10, [rbp - 168]
    mov     r11, [rbp - 168]
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

; _er_wasmc_emit_i32_expr_until_semicolon(body=rdi, cursor=rsi, end=rdx, op_stack=rcx, symbols=r8, symbol_count=r9)
; Emits an i32 expression into body. If symbol_count is nonzero, calls resolve
; through the call0 symbol table. Returns rax=cursor_after_semicolon,
; rcx=body_len, rdx=ERROR_OK.
er_fn _er_wasmc_emit_i32_expr_until_semicolon
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 96

    test    rdi, rdi
    jz      .bad_argument
    test    rsi, rsi
    jz      .bad_argument
    test    rdx, rdx
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument

    mov     r12, rdi ; body
    mov     r13, rsi ; cursor
    mov     r14, rdx ; end
    mov     r15, rcx ; operator stack
    mov     [rbp - 48], r8 ; symbol table ptr
    mov     [rbp - 56], r9 ; symbol count
    xor     ebx, ebx ; body len
    xor     r11d, r11d
    mov     [rbp - 64], r11 ; operator stack len
    mov     byte [rbp - 65], WASMC_EXPECT_OPERAND

.expr_loop:
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_skip_ws
    mov     r13, rax
    cmp     r13, r14
    jae     .parse_error
    movzx   eax, byte [r13]
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .expect_operand

    cmp     al, ';'
    je      .expect_semicolon
    cmp     al, WASMC_OP_RPAREN
    je      .close_group
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_operator_info
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 66], al ; opcode
    mov     [rbp - 67], cl ; precedence
    mov     [rbp - 68], r8b ; source length

.flush_for_precedence:
    mov     r10, [rbp - 64]
    test    r10, r10
    jz      .push_operator
    dec     r10
    cmp     byte [r15 + r10 * 2], 0
    je      .push_operator
    movzx   eax, byte [r15 + r10 * 2 + 1]
    cmp     al, [rbp - 67]
    jb      .push_operator

    movzx   edx, byte [r15 + r10 * 2]
    mov     [rbp - 64], r10
    mov     rdi, r12
    mov     rsi, rbx
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    jmp     .flush_for_precedence

.push_operator:
    mov     r10, [rbp - 64]
    cmp     r10, WASMC_COMPILE_OP_MAX
    jae     .no_space
    mov     al, [rbp - 66]
    mov     [r15 + r10 * 2], al
    mov     al, [rbp - 67]
    mov     [r15 + r10 * 2 + 1], al
    inc     r10
    mov     [rbp - 64], r10
    movzx   eax, byte [rbp - 68]
    add     r13, rax
    mov     byte [rbp - 65], WASMC_EXPECT_OPERAND
    jmp     .expr_loop

.expect_operand:
    cmp     al, WASMC_OP_LPAREN
    je      .open_group

    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_parse_i32
    test    rdx, rdx
    jnz     .try_call
    mov     [rbp - 80], rcx
    mov     rdi, r12
    mov     rsi, rbx
    mov     edx, eax
    call    _er_wasmc_emit_body_i32_const
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    mov     r13, [rbp - 80]
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.try_call:
    mov     rdi, r13
    mov     rsi, r14
    mov     rdx, [rbp - 48]
    mov     rcx, [rbp - 56]
    call    _er_wasmc_resolve_call0_symbol
    test    rdx, rdx
    jnz     .parse_error
    mov     r13, rax
    mov     rdi, r12
    mov     rsi, rbx
    mov     edx, ER_WASMC_OP_CALL
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, r12
    mov     rsi, rax
    mov     edx, r8d
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.open_group:
    mov     r10, [rbp - 64]
    cmp     r10, WASMC_COMPILE_OP_MAX
    jae     .no_space
    mov     byte [r15 + r10 * 2], 0
    mov     byte [r15 + r10 * 2 + 1], 0
    inc     r10
    mov     [rbp - 64], r10
    inc     r13
    jmp     .expr_loop

.close_group:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error
.flush_group:
    mov     r10, [rbp - 64]
    test    r10, r10
    jz      .parse_error
    dec     r10
    movzx   edx, byte [r15 + r10 * 2]
    test    dl, dl
    jz      .pop_group
    mov     [rbp - 64], r10
    mov     rdi, r12
    mov     rsi, rbx
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    jmp     .flush_group
.pop_group:
    mov     [rbp - 64], r10
    inc     r13
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.expect_semicolon:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error
    inc     r13

.flush_remaining:
    mov     r10, [rbp - 64]
    test    r10, r10
    jz      .ok
    dec     r10
    movzx   edx, byte [r15 + r10 * 2]
    test    dl, dl
    jz      .parse_error
    mov     [rbp - 64], r10
    mov     rdi, r12
    mov     rsi, rbx
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    jmp     .flush_remaining

.ok:
    mov     rax, r13
    mov     rcx, rbx
    xor     edx, edx
    jmp     .done
.bad_argument:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.parse_error:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_PARSE
    jmp     .done
.no_space:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_NO_SPACE
    jmp     .done
.error:
    xor     eax, eax
    xor     ecx, ecx
.done:
    add     rsp, 96
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; _er_wasmc_emit_i32_multi_expr_until_semicolon(body=rdi, cursor=rsi, end=rdx, op_stack=rcx, symbols=r8, symbol_count=r9, locals=r10, local_count=r11)
; Emits an i32 expression with current-function locals and calls to prior symbols.
; Symbol entries are qword name_ptr, qword name_len, qword function_index,
; qword param_count. Call arguments are i32 literals or local identifiers.
; Returns rax=cursor_after_semicolon, rcx=body_len, rdx=ERROR_OK.
er_fn _er_wasmc_emit_i32_multi_expr_until_semicolon
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 160

    test    rdi, rdi
    jz      .bad_argument
    test    rsi, rsi
    jz      .bad_argument
    test    rdx, rdx
    jz      .bad_argument
    test    rcx, rcx
    jz      .bad_argument

    mov     r12, rdi ; body
    mov     r13, rsi ; cursor
    mov     r14, rdx ; end
    mov     r15, rcx ; operator stack
    mov     [rbp - 48], r8 ; symbol table ptr
    mov     [rbp - 56], r9 ; symbol count
    mov     [rbp - 88], r10 ; local table ptr
    mov     [rbp - 96], r11 ; local count
    xor     ebx, ebx ; body len
    xor     r11d, r11d
    mov     [rbp - 64], r11 ; operator stack len
    mov     byte [rbp - 65], WASMC_EXPECT_OPERAND

.expr_loop:
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_skip_ws
    mov     r13, rax
    cmp     r13, r14
    jae     .parse_error
    movzx   eax, byte [r13]
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .expect_operand

    cmp     al, ';'
    je      .expect_semicolon
    cmp     al, WASMC_OP_COMMA
    je      .maybe_comma_delimiter
    cmp     al, WASMC_OP_RPAREN
    je      .maybe_rparen_delimiter
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_operator_info
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 66], al
    mov     [rbp - 67], cl
    mov     [rbp - 68], r8b

.flush_for_precedence:
    mov     r10, [rbp - 64]
    test    r10, r10
    jz      .push_operator
    dec     r10
    cmp     byte [r15 + r10 * 2], 0
    je      .push_operator
    movzx   eax, byte [r15 + r10 * 2 + 1]
    cmp     al, [rbp - 67]
    jb      .push_operator

    movzx   edx, byte [r15 + r10 * 2]
    mov     [rbp - 64], r10
    mov     rdi, r12
    mov     rsi, rbx
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    jmp     .flush_for_precedence

.push_operator:
    mov     r10, [rbp - 64]
    cmp     r10, WASMC_COMPILE_OP_MAX
    jae     .no_space
    mov     al, [rbp - 66]
    mov     [r15 + r10 * 2], al
    mov     al, [rbp - 67]
    mov     [r15 + r10 * 2 + 1], al
    inc     r10
    mov     [rbp - 64], r10
    movzx   eax, byte [rbp - 68]
    add     r13, rax
    mov     byte [rbp - 65], WASMC_EXPECT_OPERAND
    jmp     .expr_loop

.expect_operand:
    cmp     al, WASMC_OP_LPAREN
    je      .open_group

    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_parse_i32
    test    rdx, rdx
    jnz     .try_ident_operand
    mov     [rbp - 80], rcx
    mov     rdi, r12
    mov     rsi, rbx
    mov     edx, eax
    call    _er_wasmc_emit_body_i32_const
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    mov     r13, [rbp - 80]
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.try_ident_operand:
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_parse_ident
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 104], rax ; ident ptr
    mov     [rbp - 112], rcx ; ident len
    mov     [rbp - 80], r8   ; cursor after ident

    mov     rdi, r8
    mov     rsi, r14
    call    _er_wasmc_skip_ws
    cmp     rax, r14
    jae     .emit_local_operand
    cmp     byte [rax], WASMC_OP_LPAREN
    je      .emit_call_operand

.emit_local_operand:
    mov     rdi, [rbp - 88]
    mov     rsi, [rbp - 96]
    mov     rdx, [rbp - 104]
    mov     rcx, [rbp - 112]
    call    _er_wasmc_find_local
    test    rdx, rdx
    jnz     .parse_error
    mov     [rbp - 120], rax
    mov     rdi, r12
    mov     rsi, rbx
    mov     edx, ER_WASMC_OP_LOCAL_GET
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, r12
    mov     rsi, rax
    mov     edx, [rbp - 120]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    mov     r13, [rbp - 80]
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.emit_call_operand:
    mov     r13, rax
    mov     qword [rbp - 120], 0
.find_symbol_loop:
    mov     r10, [rbp - 120]
    cmp     r10, [rbp - 56]
    jae     .parse_error
    mov     rax, r10
    shl     rax, 5
    mov     rdi, [rbp - 48]
    mov     rsi, [rdi + rax + 8]
    cmp     rsi, [rbp - 112]
    jne     .next_symbol
    mov     rdi, [rdi + rax]
    mov     rsi, [rbp - 104]
    mov     rcx, [rbp - 112]
.symbol_name_compare:
    test    rcx, rcx
    jz      .symbol_found
    mov     dl, [rdi]
    cmp     dl, [rsi]
    jne     .next_symbol
    inc     rdi
    inc     rsi
    dec     rcx
    jmp     .symbol_name_compare
.next_symbol:
    inc     qword [rbp - 120]
    jmp     .find_symbol_loop
.symbol_found:
    mov     rax, [rbp - 120]
    shl     rax, 5
    mov     rdi, [rbp - 48]
    mov     rcx, [rdi + rax + 16]
    mov     [rbp - 128], rcx ; function index
    mov     rcx, [rdi + rax + 24]
    mov     [rbp - 136], rcx ; expected arg count
    xor     eax, eax
    mov     [rbp - 144], rax ; seen arg count

    inc     r13
.call_arg_loop:
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_skip_ws
    mov     r13, rax
    cmp     r13, r14
    jae     .parse_error
    cmp     byte [r13], WASMC_OP_RPAREN
    je      .finish_call_args

    lea     rdi, [r12 + rbx]
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    mov     r8, [rbp - 48]
    mov     r9, [rbp - 56]
    mov     r10, [rbp - 88]
    mov     r11, [rbp - 96]
    call    _er_wasmc_emit_i32_multi_expr_until_semicolon
    test    rdx, rdx
    jnz     .error
    mov     r13, rax
    add     rbx, rcx
.call_arg_emitted:
    inc     qword [rbp - 144]
    mov     rdi, r13
    mov     rsi, r14
    call    _er_wasmc_skip_ws
    mov     r13, rax
    cmp     r13, r14
    jae     .parse_error
    cmp     byte [r13], WASMC_OP_COMMA
    je      .next_call_arg
    cmp     byte [r13], WASMC_OP_RPAREN
    je      .finish_call_args
    jmp     .parse_error
.next_call_arg:
    inc     r13
    jmp     .call_arg_loop
.finish_call_args:
    mov     rax, [rbp - 144]
    cmp     rax, [rbp - 136]
    jne     .parse_error
    inc     r13
    mov     rdi, r12
    mov     rsi, rbx
    mov     edx, ER_WASMC_OP_CALL
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rdi, r12
    mov     rsi, rax
    mov     edx, [rbp - 128]
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.maybe_comma_delimiter:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error
    mov     r10, [rbp - 64]
.comma_group_scan:
    test    r10, r10
    jz      .expect_delimiter
    dec     r10
    cmp     byte [r15 + r10 * 2], 0
    je      .parse_error
    jmp     .comma_group_scan

.maybe_rparen_delimiter:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error
    mov     r10, [rbp - 64]
.rparen_group_scan:
    test    r10, r10
    jz      .expect_delimiter
    dec     r10
    cmp     byte [r15 + r10 * 2], 0
    je      .close_group
    jmp     .rparen_group_scan

.open_group:
    mov     r10, [rbp - 64]
    cmp     r10, WASMC_COMPILE_OP_MAX
    jae     .no_space
    mov     byte [r15 + r10 * 2], 0
    mov     byte [r15 + r10 * 2 + 1], 0
    inc     r10
    mov     [rbp - 64], r10
    inc     r13
    jmp     .expr_loop

.close_group:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error
.flush_group:
    mov     r10, [rbp - 64]
    test    r10, r10
    jz      .parse_error
    dec     r10
    movzx   edx, byte [r15 + r10 * 2]
    test    dl, dl
    jz      .pop_group
    mov     [rbp - 64], r10
    mov     rdi, r12
    mov     rsi, rbx
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    jmp     .flush_group
.pop_group:
    mov     [rbp - 64], r10
    inc     r13
    mov     byte [rbp - 65], WASMC_EXPECT_OPERATOR
    jmp     .expr_loop

.expect_semicolon:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error
    inc     r13
    jmp     .flush_remaining

.expect_delimiter:
    cmp     byte [rbp - 65], WASMC_EXPECT_OPERAND
    je      .parse_error

.flush_remaining:
    mov     r10, [rbp - 64]
    test    r10, r10
    jz      .ok
    dec     r10
    movzx   edx, byte [r15 + r10 * 2]
    test    dl, dl
    jz      .parse_error
    mov     [rbp - 64], r10
    mov     rdi, r12
    mov     rsi, rbx
    call    _er_wasmc_emit_body_byte
    test    rdx, rdx
    jnz     .error
    mov     rbx, rax
    jmp     .flush_remaining

.ok:
    mov     rax, r13
    mov     rcx, rbx
    xor     edx, edx
    jmp     .done
.bad_argument:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_BAD_ARGUMENT
    jmp     .done
.parse_error:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_PARSE
    jmp     .done
.no_space:
    xor     eax, eax
    xor     ecx, ecx
    mov     edx, ERROR_NO_SPACE
    jmp     .done
.error:
    xor     eax, eax
    xor     ecx, ecx
.done:
    add     rsp, 160
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

; _er_wasmc_resolve_call0_symbol(cursor=rdi, end=rsi, symbols=rdx, symbol_count=rcx)
; Symbol entries are qword name_ptr, qword name_len, qword function_index.
; Returns rax=cursor_after_call, r8=function_index, rdx=0 on a zero-arg call.
er_fn _er_wasmc_resolve_call0_symbol
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rsi
    mov     r12, rdi
    mov     r13, rdx
    mov     r14, rcx
    test    r14, r14
    jz      .bad
    test    r13, r13
    jz      .bad

    xor     r15d, r15d
.symbol_loop:
    cmp     r15, r14
    jae     .bad
    mov     rax, r15
    lea     rax, [rax + rax * 2]
    shl     rax, 3
    mov     rdi, [r13 + rax]
    mov     rsi, [r13 + rax + 8]
    mov     rdx, r12
    mov     rcx, rbx
    call    _er_wasmc_match_keyword
    test    rdx, rdx
    jz      .matched_symbol
    inc     r15
    jmp     .symbol_loop

.matched_symbol:
    mov     r11, r15
    lea     r11, [r11 + r11 * 2]
    shl     r11, 3
    mov     r8, [r13 + r11 + 16]
    mov     rdi, rax
    mov     rsi, rbx
    call    _er_wasmc_skip_ws
    cmp     rax, rbx
    jae     .bad
    cmp     byte [rax], WASMC_OP_LPAREN
    jne     .bad
    inc     rax

    mov     rdi, rax
    mov     rsi, rbx
    call    _er_wasmc_skip_ws
    cmp     rax, rbx
    jae     .bad
    cmp     byte [rax], WASMC_OP_RPAREN
    jne     .bad
    inc     rax

    xor     edx, edx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.bad:
    xor     eax, eax
    xor     r8d, r8d
    mov     edx, ERROR_PARSE
    pop     r15
    pop     r14
    pop     r13
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
    xor     r11d, r11d
    jmp     er_wasmc_emit_i32_locals_body_export

; er_wasmc_emit_i32_locals_body_export(out=rdi, cap=rsi, body=rdx, body_len=rcx, name=r8, name_len=r9, local_count=r10, param_count=r11)
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_emit_i32_locals_body_export
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
    cmp     r11, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument

    mov     r12, rdi
    mov     r13, rsi
    mov     [rbp - 48], rdx ; body ptr
    mov     r14, rcx
    mov     r15, r8
    mov     rbx, r9
    mov     [rbp - 56], r10 ; local count
    mov     [rbp - 64], r11 ; param count

    mov     rax, WASMC_FIXED_BYTES_WITH_BODY
    add     rax, rbx
    add     rax, r14
    add     rax, [rbp - 64]
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
    mov     rax, [rbp - 64]
    add     rax, 5
    mov     [rdi + 1], al
    mov     byte [rdi + 2], 1
    mov     byte [rdi + 3], ER_WASMC_TYPE_FUNC
    mov     rax, [rbp - 64]
    mov     [rdi + 4], al
    add     rdi, 5
    xor     r10d, r10d
.write_param_types:
    cmp     r10, [rbp - 64]
    jae     .param_types_done
    mov     byte [rdi], ER_WASMC_TYPE_I32
    inc     rdi
    inc     r10
    jmp     .write_param_types
.param_types_done:
    mov     byte [rdi], 1
    mov     byte [rdi + 1], ER_WASMC_TYPE_I32
    add     rdi, 2

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
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; er_wasmc_emit_i32_two_body_export(out=rdi, cap=rsi, body0=rdx, body0_len=rcx, body1=r8, body1_len=r9, name=r10, name_len=r11)
; Emits two zero-arg i32 functions. Function 1 is exported as name.
; Returns rax=bytes_written, rdx=ERROR_OK on success.
er_fn er_wasmc_emit_i32_two_body_export
    er_frame_push
    sub     rsp, 32

    mov     [rbp - 32], rdx
    mov     [rbp - 24], rcx
    mov     [rbp - 16], r8
    mov     [rbp - 8], r9
    lea     rdx, [rbp - 32]
    mov     ecx, 2
    mov     r8, r10
    mov     r9, r11
    mov     r10d, 1
    call    er_wasmc_emit_i32_body_table_export

    add     rsp, 32
    pop     rbp
    ret

; er_wasmc_emit_i32_body_table_export(out=rdi, cap=rsi, body_table=rdx, func_count=rcx, name=r8, name_len=r9, export_index=r10)
; body_table entries are qword body_ptr, qword body_len. All functions are
; zero-arg i32 results with no locals. Returns rax=bytes_written, rdx=ERROR_OK.
er_fn er_wasmc_emit_i32_body_table_export
    xor     r11d, r11d
    jmp     er_wasmc_emit_i32_sig_body_table_export

; er_wasmc_emit_i32_sig_body_table_export(out=rdi, cap=rsi, body_table=rdx, func_count=rcx, name=r8, name_len=r9, export_index=r10, sig_table=r11)
; body_table entries are qword body_ptr, qword body_len. sig_table is optional;
; when nonzero, it has qword param_count, qword local_count per function.
; Returns rax=bytes_written, rdx=ERROR_OK.
er_fn er_wasmc_emit_i32_sig_body_table_export
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 96

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
    cmp     r9, WASMC_MAX_SHORT_ULEB - 4
    ja      .bad_argument
    cmp     r10, rcx
    jae     .bad_argument

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx
    mov     [rbp - 48], r8  ; export name ptr
    mov     rbx, r9         ; export name len
    mov     [rbp - 56], r10 ; export function index
    mov     [rbp - 72], r11 ; signature table ptr

    xor     r10d, r10d
    xor     r11d, r11d
    xor     eax, eax
    mov     [rbp - 80], rax ; total param type bytes
    mov     [rbp - 88], rax ; total local decl bytes
.validate_body_loop:
    cmp     r10, r15
    jae     .body_lengths_ok
    mov     rax, r10
    shl     rax, 4
    cmp     qword [r14 + rax], 0
    je      .bad_argument
    mov     rdx, [r14 + rax + 8]
    test    rdx, rdx
    jz      .bad_argument
    cmp     rdx, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument
    add     r11, rdx
    cmp     qword [rbp - 72], 0
    je      .validated_sig_entry
    mov     rax, r10
    shl     rax, 4
    mov     rcx, [rbp - 72]
    mov     rdx, [rcx + rax]
    cmp     rdx, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument
    add     [rbp - 80], rdx
    mov     rdx, [rcx + rax + 8]
    cmp     rdx, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument
    test    rdx, rdx
    jz      .validated_sig_entry
    add     qword [rbp - 88], 2
.validated_sig_entry:
    inc     r10
    jmp     .validate_body_loop
.body_lengths_ok:
    mov     [rbp - 64], r11 ; total body byte count

    mov     rax, r15
    lea     rax, [rax + rax * 2 + 1]
    add     rax, [rbp - 64]
    add     rax, [rbp - 88]
    cmp     rax, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument

    mov     rax, 23
    add     rax, rbx
    add     rax, [rbp - 64]
    add     rax, [rbp - 80]
    add     rax, [rbp - 88]
    mov     r11, r15
    imul    r11, 8
    add     rax, r11
    cmp     rax, WASMC_MAX_SHORT_ULEB
    ja      .bad_argument
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
    mov     rax, r15
    shl     rax, 2
    inc     rax
    add     rax, [rbp - 80]
    mov     [rdi + 1], al
    mov     [rdi + 2], r15b
    add     rdi, 3
    xor     r10d, r10d
.write_type_loop:
    cmp     r10, r15
    jae     .types_done
    mov     byte [rdi], ER_WASMC_TYPE_FUNC
    inc     rdi
    xor     eax, eax
    cmp     qword [rbp - 72], 0
    je      .have_type_param_count
    mov     r11, r10
    shl     r11, 4
    mov     rcx, [rbp - 72]
    mov     rax, [rcx + r11]
.have_type_param_count:
    mov     [rdi], al
    inc     rdi
    mov     r11, rax
.write_type_params:
    test    r11, r11
    jz      .type_params_done
    mov     byte [rdi], ER_WASMC_TYPE_I32
    inc     rdi
    dec     r11
    jmp     .write_type_params
.type_params_done:
    mov     byte [rdi], 1
    mov     byte [rdi + 1], ER_WASMC_TYPE_I32
    add     rdi, 2
    inc     r10
    jmp     .write_type_loop
.types_done:

    mov     byte [rdi + 0], ER_WASMC_SECTION_FUNC
    mov     rax, r15
    inc     rax
    mov     [rdi + 1], al
    mov     [rdi + 2], r15b
    add     rdi, 3
    xor     r10d, r10d
.write_func_type_loop:
    cmp     r10, r15
    jae     .func_types_done
    mov     [rdi], r10b
    inc     rdi
    inc     r10
    jmp     .write_func_type_loop
.func_types_done:

    mov     byte [rdi + 0], ER_WASMC_SECTION_EXPORT
    mov     rax, rbx
    add     rax, 4
    mov     [rdi + 1], al
    mov     byte [rdi + 2], 1
    mov     [rdi + 3], bl
    add     rdi, 4

    mov     rcx, rbx
    mov     rsi, [rbp - 48]
    rep     movsb

    mov     byte [rdi + 0], ER_WASMC_EXPORT_FUNC
    mov     rax, [rbp - 56]
    mov     [rdi + 1], al
    add     rdi, 2

    mov     byte [rdi + 0], ER_WASMC_SECTION_CODE
    mov     rax, r15
    lea     rax, [rax + rax * 2 + 1]
    add     rax, [rbp - 64]
    add     rax, [rbp - 88]
    mov     [rdi + 1], al
    mov     [rdi + 2], r15b
    add     rdi, 3

    xor     r10d, r10d
.write_body_loop:
    cmp     r10, r15
    jae     .bodies_done
    mov     rax, r10
    shl     rax, 4
    mov     rcx, [r14 + rax + 8]
    lea     r11, [rcx + 2]
    cmp     qword [rbp - 72], 0
    je      .have_body_size
    mov     rdx, [rbp - 72]
    cmp     qword [rdx + rax + 8], 0
    je      .have_body_size
    add     r11, 2
.have_body_size:
    mov     [rdi], r11b
    inc     rdi
    cmp     qword [rbp - 72], 0
    je      .write_zero_locals
    mov     rdx, [rbp - 72]
    mov     r11, [rdx + rax + 8]
    test    r11, r11
    jz      .write_zero_locals
    mov     byte [rdi], 1
    mov     [rdi + 1], r11b
    mov     byte [rdi + 2], ER_WASMC_TYPE_I32
    add     rdi, 3
    jmp     .copy_sig_body
.write_zero_locals:
    mov     byte [rdi], 0
    inc     rdi
.copy_sig_body:
    mov     rsi, [r14 + rax]
    rep     movsb
    mov     byte [rdi], ER_WASMC_OP_END
    inc     rdi
    inc     r10
    jmp     .write_body_loop
.bodies_done:

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
.done:
    add     rsp, 96
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
