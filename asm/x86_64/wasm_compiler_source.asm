; ==================================================================
; EdgeRun WASM Compiler — Source Tokenizer and Parser
; ASM port of edgerun-zig/compiler/zig/src/edgerun_source.zig
;
; Externs (from wasm_compiler.asm):
;   is_ident_start, is_ident_continue, skip_space,
;   scan_identifier_end, scan_balanced
;
; Exports: source_parse, parse_function, tokenizer_init,
;          tokenizer_next, tokenizer_peek
; ==================================================================

%include "x86_64/macros.inc"
%include "x86_64/wasm_compiler.inc"

extern is_ident_start
extern is_ident_continue
extern skip_space
extern scan_identifier_end
extern scan_balanced

; ==================================================================
; Token types (returned in eax)
; ==================================================================
%define TOKEN_EOF                0
%define TOKEN_INVALID            1
%define TOKEN_IDENTIFIER         2
%define TOKEN_INTEGER_LITERAL    3
%define TOKEN_FLOAT_LITERAL      4
%define TOKEN_STRING_LITERAL     5
%define TOKEN_CHAR_LITERAL       6
%define TOKEN_BUILTIN            7

%define TOKEN_KW_CONST         100
%define TOKEN_KW_VAR           101
%define TOKEN_KW_FN            102
%define TOKEN_KW_EXPORT        103
%define TOKEN_KW_RETURN        104
%define TOKEN_KW_PUB           105
%define TOKEN_KW_IF            106
%define TOKEN_KW_ELSE          107
%define TOKEN_KW_WHILE         108
%define TOKEN_KW_TRUE          109
%define TOKEN_KW_FALSE         110

%define TOKEN_LPAREN           200
%define TOKEN_RPAREN           201
%define TOKEN_LBRACE           202
%define TOKEN_RBRACE           203
%define TOKEN_LBRACKET         204
%define TOKEN_RBRACKET         205
%define TOKEN_COLON            206
%define TOKEN_SEMICOLON        207
%define TOKEN_COMMA            208
%define TOKEN_EQUALS           209
%define TOKEN_DOT              210
%define TOKEN_PLUS             211
%define TOKEN_MINUS            212
%define TOKEN_STAR             213
%define TOKEN_SLASH            214

; ==================================================================
; BSS
; ==================================================================
SECTION .bss

tokenizer_source_ptr:   resq    1
tokenizer_source_len:   resq    1
tokenizer_index:        resq    1

; result layout: name_ptr(8) name_len(8) args_off(8) args_len(8)
;                sig_off(8) sig_len(8) body_off(8) body_len(8)
;                next_idx(8) exported(1) = 81 bytes
parser_result_buf:      resb    128

parse_stats_decl_count:     resd    1
parse_stats_export_count:   resd    1
parse_stats_export_bytes:   resd    1

; Export name storage (filled by source_parse)
MAX_PARSED_EXPORTS equ 64
global export_name_ptrs, export_name_lens, export_name_count
global return_values
export_name_ptrs:   resq    MAX_PARSED_EXPORTS
export_name_lens:   resd    MAX_PARSED_EXPORTS
export_name_count:  resd    1
return_values:      resd    MAX_PARSED_EXPORTS

; Const name/value table (populated by source_parse)
MAX_CONST_DECLS equ 64
const_name_ptrs:   resq    MAX_CONST_DECLS
const_name_lens:   resd    MAX_CONST_DECLS
const_values:      resd    MAX_CONST_DECLS
const_decl_count:  resd    1

; ==================================================================
; .rodata
; ==================================================================
SECTION .rodata

; keyword strings for match_keyword
kw_str:
.k_const:     db "const", 0
.k_var:       db "var", 0
.k_fn:        db "fn", 0
.k_export:    db "export", 0
.k_return:    db "return", 0
.k_pub:       db "pub", 0
.k_if:        db "if", 0
.k_else:      db "else", 0
.k_while:     db "while", 0
.k_true:      db "true", 0
.k_false:     db "false", 0

; prefix strings for check_prefix
prefix_const:       db "const "
prefix_var:         db "var "
prefix_fn:          db "fn "
prefix_export_fn:   db "export fn "
prefix_pub_export:  db "pub export fn "
prefix_return:      db "return "

; Keyword lookup table: { ptr(8), len(8), type(8) } = 24 bytes/entry
align 8
kw_table:
    dq  kw_str.k_const,  5, TOKEN_KW_CONST
    dq  kw_str.k_var,    3, TOKEN_KW_VAR
    dq  kw_str.k_fn,     2, TOKEN_KW_FN
    dq  kw_str.k_export, 6, TOKEN_KW_EXPORT
    dq  kw_str.k_return, 6, TOKEN_KW_RETURN
    dq  kw_str.k_pub,    3, TOKEN_KW_PUB
    dq  kw_str.k_if,     2, TOKEN_KW_IF
    dq  kw_str.k_else,   4, TOKEN_KW_ELSE
    dq  kw_str.k_while,  5, TOKEN_KW_WHILE
    dq  kw_str.k_true,   4, TOKEN_KW_TRUE
    dq  kw_str.k_false,  5, TOKEN_KW_FALSE
KW_TABLE_COUNT  equ 11

; ==================================================================
; .text
; ==================================================================
SECTION .text

; ------------------------------------------------------------------
; tokenizer_init(source_ptr=rdi, source_len=rsi)
; ------------------------------------------------------------------
global tokenizer_init
tokenizer_init:
    mov     [tokenizer_source_ptr], rdi
    mov     [tokenizer_source_len], rsi
    mov     qword [tokenizer_index], 0
    ret

; ------------------------------------------------------------------
; keyword_match(word_ptr=rdi, word_len=rsi, kw_ptr=rdx)
; Returns ZF set if equal. Clobbers rax,rcx,rdi,rsi
; ------------------------------------------------------------------
keyword_match:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    mov     rdi, rdx
    xor     eax, eax
    mov     rcx, -1
    repne   scasb
    not     rcx
    dec     rcx                 ; rcx = kw length
    cmp     r13, rcx
    jne     .no
    mov     rsi, r12
    mov     rdi, rdx
    mov     rcx, r13
    repe    cmpsb
    jne     .no
    cmp     al, al              ; ZF set
    pop     r13
    pop     r12
    pop     rbp
    ret
.no:
    xor     eax, eax
    inc     eax                 ; ZF clear
    pop     r13
    pop     r12
    pop     rbp
    ret

; ------------------------------------------------------------------
; match_keyword(word_ptr=rdi, word_len=rsi)
; Returns eax = token type (TOKEN_IDENTIFIER if no match)
; ------------------------------------------------------------------
match_keyword:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r13, rsi
    lea     r14, [kw_table]      ; table base
    xor     ebx, ebx
.loop:
    cmp     ebx, KW_TABLE_COUNT
    jae     .not_found
    mov     rax, rbx
    imul    rax, 24
    ; check length at table[idx].len (offset 8)
    mov     r8d, [r14 + rax + 8]
    cmp     r13, r8
    jne     .next
    ; compare words
    mov     rdx, [r14 + rax]     ; keyword ptr
    mov     rdi, r12
    mov     rsi, r13
    call    keyword_match
    jz      .found
.next:
    inc     ebx
    jmp     .loop
.found:
    mov     rax, rbx
    imul    rax, 24
    mov     eax, [r14 + rax + 16]
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.not_found:
    mov     eax, TOKEN_IDENTIFIER
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; lex_string: rdi=source, rsi=len, rdx=index (at ")
; Returns rdx = index after closing "
; ------------------------------------------------------------------
lex_string:
    inc     rdx
.loop:
    cmp     rdx, rsi
    jae     .done
    movzx   eax, byte [rdi + rdx]
    cmp     al, '"'
    je      .close
    cmp     al, 0x5C
    jne     .norm
    inc     rdx
    cmp     rdx, rsi
    jae     .done
.norm:
    inc     rdx
    jmp     .loop
.close:
    inc     rdx
.done:
    ret

; ------------------------------------------------------------------
; lex_char: rdi=source, rsi=len, rdx=index (at ')
; Returns rdx = index after closing '
; ------------------------------------------------------------------
lex_char:
    inc     rdx
    cmp     rdx, rsi
    jae     .done
    movzx   eax, byte [rdi + rdx]
    cmp     al, 0x5C
    jne     .norm
    inc     rdx
    cmp     rdx, rsi
    jae     .done
.norm:
    inc     rdx
    cmp     rdx, rsi
    jae     .done
    movzx   eax, byte [rdi + rdx]
    cmp     al, 0x27
    jne     .done
    inc     rdx
.done:
    ret

; ------------------------------------------------------------------
; tokenizer_next()
; Returns: eax=token type, rdi=data_ptr, ecx=data_len
; ------------------------------------------------------------------
global tokenizer_next
tokenizer_next:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rdi, [tokenizer_source_ptr]
    mov     rsi, [tokenizer_source_len]
    mov     rdx, [tokenizer_index]
    call    skip_space
    mov     [tokenizer_index], rdx
    jnc     .have_byte
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.have_byte:
    mov     rdi, [tokenizer_source_ptr]
    mov     rsi, [tokenizer_source_len]
    movzx   eax, byte [rdi + rdx]
    mov     r12, rdx

    cmp     al, '@'
    je      .builtin

    call    is_ident_start
    jz      .ident

    cmp     al, '0'
    jb      .chk_str
    cmp     al, '9'
    ja      .chk_str
    jmp     .number

.chk_str:
    cmp     al, '"'
    je      .string
    cmp     al, 0x27
    je      .char
    jmp     .punct

; --- @builtin ---
.builtin:
    inc     rdx
    mov     rbx, rdx
.b_name:
    cmp     rdx, rsi
    jae     .b_done
    movzx   eax, byte [rdi + rdx]
    call    is_ident_continue
    jnz     .b_done
    inc     rdx
    jmp     .b_name
.b_done:
    cmp     rbx, rdx
    jb      .b_ok
    mov     [tokenizer_index], rdx
    mov     eax, TOKEN_INVALID
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.b_ok:
    mov     [tokenizer_index], rdx
    mov     eax, TOKEN_BUILTIN
    mov     rdi, [tokenizer_source_ptr]
    add     rdi, r12
    mov     ecx, edx
    sub     ecx, r12d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; --- identifier / keyword ---
.ident:
    inc     rdx
.i_loop:
    cmp     rdx, rsi
    jae     .i_done
    movzx   eax, byte [rdi + rdx]
    call    is_ident_continue
    jnz     .i_done
    inc     rdx
    jmp     .i_loop
.i_done:
    mov     [tokenizer_index], rdx
    mov     rdi, [tokenizer_source_ptr]
    push    rdx
    add     rdi, r12
    mov     rsi, rdx
    sub     rsi, r12
    push    r12
    call    match_keyword
    pop     r12
    pop     rdx
    cmp     eax, TOKEN_IDENTIFIER
    je      .i_ret_id
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.i_ret_id:
    mov     eax, TOKEN_IDENTIFIER
    mov     rdi, [tokenizer_source_ptr]
    add     rdi, r12
    mov     ecx, edx
    sub     ecx, r12d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; --- number ---
.number:
.n_loop:
    inc     rdx
    cmp     rdx, rsi
    jae     .int_done
    movzx   eax, byte [rdi + rdx]
    cmp     al, '0'
    jb      .may_float
    cmp     al, '9'
    jbe     .n_loop
.may_float:
    cmp     al, '.'
    jne     .int_done
    cmp     rdx, rsi
    jae     .int_done
    movzx   eax, byte [rdi + rdx + 1]
    cmp     al, '.'
    je      .int_done
    inc     rdx
.f_frac:
    cmp     rdx, rsi
    jae     .float_done
    movzx   eax, byte [rdi + rdx]
    cmp     al, '0'
    jb      .f_exp_chk
    cmp     al, '9'
    ja      .f_exp_chk
    inc     rdx
    jmp     .f_frac
.f_exp_chk:
    cmp     al, 'e'
    je      .f_exp
    cmp     al, 'E'
    je      .f_exp
    jmp     .float_done
.f_exp:
    inc     rdx
    cmp     rdx, rsi
    jae     .float_done
    movzx   eax, byte [rdi + rdx]
    cmp     al, '+'
    je      .f_exp_s
    cmp     al, '-'
    je      .f_exp_s
    jmp     .f_exp_d
.f_exp_s:
    inc     rdx
.f_exp_d:
    cmp     rdx, rsi
    jae     .float_done
    movzx   eax, byte [rdi + rdx]
    cmp     al, '0'
    jb      .float_done
    cmp     al, '9'
    ja      .float_done
    inc     rdx
    jmp     .f_exp_d
.float_done:
    mov     [tokenizer_index], rdx
    mov     eax, TOKEN_FLOAT_LITERAL
    mov     rdi, [tokenizer_source_ptr]
    add     rdi, r12
    mov     ecx, edx
    sub     ecx, r12d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.int_done:
    mov     [tokenizer_index], rdx
    mov     eax, TOKEN_INTEGER_LITERAL
    mov     rdi, [tokenizer_source_ptr]
    add     rdi, r12
    mov     ecx, edx
    sub     ecx, r12d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; --- string ---
.string:
    call    lex_string
    mov     [tokenizer_index], rdx
    mov     eax, TOKEN_STRING_LITERAL
    mov     rdi, [tokenizer_source_ptr]
    add     rdi, r12
    mov     ecx, edx
    sub     ecx, r12d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; --- char ---
.char:
    call    lex_char
    mov     [tokenizer_index], rdx
    mov     eax, TOKEN_CHAR_LITERAL
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; --- punctuation ---
.punct:
    inc     rdx
    mov     [tokenizer_index], rdx
    movzx   eax, byte [rdi + r12]

    cmp     al, '('
    jne     .pp_rp
    mov     eax, TOKEN_LPAREN
    jmp     .pret
.pp_rp: cmp al, ')'
    jne     .pp_lb
    mov     eax, TOKEN_RPAREN
    jmp     .pret
.pp_lb: cmp al, '{'
    jne     .pp_rb
    mov     eax, TOKEN_LBRACE
    jmp     .pret
.pp_rb: cmp al, '}'
    jne     .pp_lbrk
    mov     eax, TOKEN_RBRACE
    jmp     .pret
.pp_lbrk: cmp al, '['
    jne     .pp_rbrk
    mov     eax, TOKEN_LBRACKET
    jmp     .pret
.pp_rbrk: cmp al, ']'
    jne     .pp_col
    mov     eax, TOKEN_RBRACKET
    jmp     .pret
.pp_col: cmp al, ':'
    jne     .pp_semi
    mov     eax, TOKEN_COLON
    jmp     .pret
.pp_semi: cmp al, ';'
    jne     .pp_com
    mov     eax, TOKEN_SEMICOLON
    jmp     .pret
.pp_com: cmp al, ','
    jne     .pp_eq
    mov     eax, TOKEN_COMMA
    jmp     .pret
.pp_eq: cmp al, '='
    jne     .pp_dot
    mov     eax, TOKEN_EQUALS
    jmp     .pret
.pp_dot: cmp al, '.'
    jne     .pp_pl
    mov     eax, TOKEN_DOT
    jmp     .pret
.pp_pl: cmp al, '+'
    jne     .pp_mi
    mov     eax, TOKEN_PLUS
    jmp     .pret
.pp_mi: cmp al, '-'
    jne     .pp_st
    mov     eax, TOKEN_MINUS
    jmp     .pret
.pp_st: cmp al, '*'
    jne     .pp_sl
    mov     eax, TOKEN_STAR
    jmp     .pret
.pp_sl: cmp al, '/'
    jne     .pp_inv
    mov     eax, TOKEN_SLASH
    jmp     .pret
.pp_inv:
    mov     eax, TOKEN_INVALID
.pret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; tokenizer_peek() — return next token type without consuming
; ------------------------------------------------------------------
global tokenizer_peek
tokenizer_peek:
    push    rbp
    mov     rbp, rsp
    mov     rax, [tokenizer_index]
    push    rax
    call    tokenizer_next
    pop     rcx
    mov     [tokenizer_index], rcx
    pop     rbp
    ret

; ------------------------------------------------------------------
; check_prefix: does source at current index match prefix?
; rdi=source, rsi=len, rdx=index, r10=prefix ptr, r11=prefix len
; Returns carry clear on match (tokenizer_index advanced)
; ------------------------------------------------------------------
check_prefix:
    push    rbp
    mov     rbp, rsp
    push    rcx
    push    rdi             ; saved original rdi (source ptr)
    push    rsi             ; saved original rsi (source len)
    push    r8
    mov     r8, rsi
    sub     r8, rdx
    cmp     r8, r11
    jb      .no
    ; Use the rdi argument directly instead of reloading from tokenizer_source_ptr
    add     rdi, rdx        ; rdi = source_ptr + index
    mov     rsi, r10
    mov     rcx, r11
    repe    cmpsb
    jne     .no
    add     rdx, r11
    mov     [tokenizer_index], rdx
    clc
    pop     r8
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rbp
    ret
.no:
    stc
    pop     r8
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rbp
    ret

; ------------------------------------------------------------------
; parse_function(source_ptr=rdi, source_len=rsi, index=rdx)
; Returns carry set on failure. populates parser_result_buf.
; ------------------------------------------------------------------
global parse_function
parse_function:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8              ; align

    mov     r12, rdi
    mov     r13, rsi
    xor     r14b, r14b          ; exported flag
    mov     r15, rdx

    ; Normalize position: skip whitespace
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    skip_space
    jc      .fail
    mov     r15, rdx

    ; "pub export fn "
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    lea     r10, [prefix_pub_export]
    mov     r11, 14
    call    check_prefix
    jnc     .got_export_fn

    ; "export fn "
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    lea     r10, [prefix_export_fn]
    mov     r11, 10
    call    check_prefix
    jnc     .got_export_fn

    ; "fn " (not exported)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    lea     r10, [prefix_fn]
    mov     r11, 3
    call    check_prefix
    jnc     .got_fn

    jmp     .fail

.got_export_fn:
    mov     r14b, 1              ; exported
.got_fn:
    mov     r15, [tokenizer_index]

    ; Function name
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    scan_identifier_end
    jc      .fail
    ; rdx = end of identifier
    mov     [parser_result_buf + 0], r15    ; name offset
    mov     rax, rdx
    sub     rax, r15
    mov     [parser_result_buf + 8], rax    ; name len

    ; Find and skip '('
    mov     r15, rdx
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    skip_space
    jc      .fail
    mov     r15, rdx
    cmp     r15, r13
    jae     .fail
    movzx   eax, byte [r12 + r15]
    cmp     al, '('
    jne     .fail

    ; Parse args (balanced parens)
    mov     al, '('
    mov     ah, ')'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    scan_balanced
    jc      .fail
    mov     r15, rdx            ; index after ')'

    ; Scan for '{'
.sig_scan:
    cmp     r15, r13
    jae     .fail
    movzx   eax, byte [r12 + r15]
    cmp     al, '{'
    je      .found_brace
    cmp     al, ';'
    je      .fail
    inc     r15
    jmp     .sig_scan
.found_brace:
    ; Parse body (balanced braces)
    mov     al, '{'
    mov     ah, '}'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    scan_balanced
    jc      .fail
    ; rdx = index past '}'
    mov     [parser_result_buf + 64], rdx    ; next index
    mov     [parser_result_buf + 72], r14b   ; exported

    clc
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail:
    stc
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; source_parse(source_ptr=rdi, source_len=rsi)
; Count declarations and exports.
; Returns carry set on failure, populates parse_stats_*.
; ------------------------------------------------------------------
global source_parse
source_parse:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    xor     r14d, r14d          ; decl count
    xor     r15d, r15d          ; export count
    xor     ebx, ebx            ; export name bytes
    mov     dword [const_decl_count], 0

    call    tokenizer_init

.loop:
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [tokenizer_index]
    call    skip_space
    jc      .done
    mov     [tokenizer_index], rdx

    ; "const "
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [tokenizer_index]
    lea     r10, [prefix_const]
    mov     r11, 6
    call    check_prefix
    jnc     .handle_const

    ; "var "
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [tokenizer_index]
    lea     r10, [prefix_var]
    mov     r11, 4
    call    check_prefix
    jnc     .handle_var

    ; function
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [tokenizer_index]
    call    parse_function
    jnc     .handle_fn

    ; skip one byte
    mov     rdx, [tokenizer_index]
    inc     rdx
    mov     [tokenizer_index], rdx
    jmp     .loop

.handle_const:
    inc     r14d
    ; [tokenizer_index] points past "const ". r12=src, r13=len.
    mov     rdx, [tokenizer_index]

    ; Parse identifier name
    mov     rdi, r12
    mov     rsi, r13
    mov     r10, rdx                ; save name start offset
    call    scan_identifier_end
    jc      .const_scan_semi        ; no ident, skip to semicolon

    ; r10 = name start offset, rdx = name end offset
    mov     r8d, [const_decl_count]
    cmp     r8d, MAX_CONST_DECLS
    jae     .const_scan_val         ; table full

    lea     rax, [r12 + r10]
    mov     [const_name_ptrs + r8*8], rax
    mov     eax, edx
    sub     eax, r10d
    mov     [const_name_lens + r8*4], eax

.const_scan_val:
    ; Scan forward for '='
    mov     rdi, r12
    mov     rsi, r13
.const_scan_eq:
    cmp     rdx, r13
    jae     .const_scan_semi
    movzx   eax, byte [r12 + rdx]
    cmp     al, '='
    je      .const_got_eq
    cmp     al, ';'
    je      .const_scan_semi
    inc     rdx
    jmp     .const_scan_eq
.const_got_eq:
    inc     rdx                     ; skip '='

    ; Skip whitespace before value
    call    skip_space
    jc      .const_scan_semi

    ; Parse decimal value
    xor     ecx, ecx
.const_val_loop:
    cmp     rdx, r13
    jae     .const_val_done
    movzx   eax, byte [r12 + rdx]
    cmp     al, '0'
    jb      .const_val_done
    cmp     al, '9'
    ja      .const_val_done
    imul    ecx, 10
    sub     al, '0'
    add     ecx, eax
    inc     rdx
    jmp     .const_val_loop
.const_val_done:
    cmp     r8d, MAX_CONST_DECLS
    jae     .const_scan_semi
    mov     [const_values + r8*4], ecx
    inc     dword [const_decl_count]

.const_scan_semi:
    mov     rdi, r12
    mov     rsi, r13
    jmp     .scan_semicolon

.handle_var:
    inc     r14d
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [tokenizer_index]
    add     rdx, 4              ; skip "var "
.scan_semicolon:
    cmp     rdx, rsi
    jae     .fail
    cmp     byte [rdi + rdx], ';'
    je      .semi_found
    inc     rdx
    jmp     .scan_semicolon
.semi_found:
    inc     rdx
    mov     [tokenizer_index], rdx
    jmp     .loop

.handle_fn:
    inc     r14d
    cmp     byte [parser_result_buf + 72], 0
    je      .fn_skip
    inc     r15d
    mov     rax, [parser_result_buf + 8]
    add     ebx, eax
    mov     ecx, [export_name_count]
    cmp     ecx, MAX_PARSED_EXPORTS
    jae     .fn_skip
    mov     rdx, [parser_result_buf + 0]    ; name offset in source
    add     rdx, r12                        ; name ptr
    mov     [export_name_ptrs + rcx*8], rdx
    mov     [export_name_lens + rcx*4], eax
    inc     dword [export_name_count]

    ; Extract return literal from body
    push    qword [tokenizer_index]

    mov     rdx, [parser_result_buf + 48]  ; body offset
    inc     rdx                            ; skip '{'

    mov     rdi, r12
    mov     rsi, r13
    call    skip_space
    mov     r8d, 0               ; default value
    jc      .ret_done

    lea     r10, [prefix_return]
    mov     r11, 7
    call    check_prefix
    mov     r8d, 0
    jc      .ret_done

.ret_parse:
    cmp     rdx, r13
    jae     .ret_done
    movzx   r9d, byte [r12 + rdx]
    cmp     r9b, '0'
    jb      .ret_check_ident
    cmp     r9b, '9'
    ja      .ret_check_ident
    ; Digit: accumulate
    imul    r8d, 10
    sub     r9b, '0'
    add     r8d, r9d
    inc     rdx
    jmp     .ret_parse

.ret_check_ident:
    ; Not a digit. Check if identifier start.
    movzx   eax, r9b
    call    is_ident_start
    jz      .ret_lookup_const
    ; Neither digit nor ident → done
    jmp     .ret_done

.ret_lookup_const:
    ; rdx = start of identifier
    push    rdx                    ; save ident start
    mov     rdi, r12
    mov     rsi, r13
    call    scan_identifier_end
    pop     rdi                    ; rdi = ident start offset
    jc      .ret_done
    ; rdx = ident end, rdi = ident start
    mov     r9d, edx
    sub     r9d, edi               ; r9d = ident length
    lea     r10, [r12 + rdi]       ; r10 = absolute ptr to ident

    ; Linear search of const table
    push    rcx                    ; save export index
    push    r15                    ; save export count → use as loop index
    mov     r11d, [const_decl_count]
    xor     r15d, r15d
.const_lookup_loop:
    cmp     r15d, r11d
    jae     .const_lookup_not_found
    mov     eax, [const_name_lens + r15*4]
    cmp     r9d, eax
    jne     .const_lookup_next
    mov     rdi, r10
    mov     rsi, [const_name_ptrs + r15*8]
    mov     ecx, r9d
    repe    cmpsb
    jne     .const_lookup_next
    ; Found!
    mov     r8d, [const_values + r15*4]
    jmp     .const_lookup_done
.const_lookup_next:
    inc     r15d
    jmp     .const_lookup_loop
.const_lookup_not_found:
    ; r8d stays 0 (default)
.const_lookup_done:
    pop     r15                    ; restore export count
    pop     rcx                    ; restore export index
    jmp     .ret_done

.ret_done:
    pop     qword [tokenizer_index]
    mov     [return_values + ecx*4], r8d
.fn_skip:
    mov     rdx, [parser_result_buf + 64]
    mov     [tokenizer_index], rdx
    jmp     .loop

.done:
    test    r14d, r14d
    jz      .fail
    test    r15d, r15d
    jz      .fail

    mov     [parse_stats_decl_count], r14d
    mov     [parse_stats_export_count], r15d
    mov     [parse_stats_export_bytes], ebx
    clc
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail:
    stc
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
