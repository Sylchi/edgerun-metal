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
%include "x86_64/wasm/wasm_compiler.inc"

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

; Compiled function body storage (populated by expression compiler)
; body_buf_pos = current write offset in body_buf
global body_offsets, body_lens, body_param_counts, body_buf, body_buf_pos, body_param_base
body_offsets:     resd    MAX_PARSED_EXPORTS
body_lens:        resd    MAX_PARSED_EXPORTS
body_param_counts: resd   MAX_PARSED_EXPORTS
body_buf:         resb    COMPILED_BODY_BUF_SIZE
body_buf_pos:     resd    1

; Per-function param name storage (flat length-prefixed buffer)
; For each function: [count_byte][len1][name1...][len2][name2...]...
body_param_base:  resd    MAX_PARSED_EXPORTS  ; offset into param_names_buf
param_names_buf:  resb    1024                 ; param name data
param_buf_pos:    resd    1                    ; current write pos

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
    er_frame_push
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
    er_frame_push
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
    er_frame_push
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
    er_frame_push
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
    er_frame_push
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
    er_frame_push
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

    mov     [parser_result_buf + 16], r15    ; args_off = '(' position

    ; Parse args (balanced parens)
    mov     al, '('
    mov     ah, ')'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    scan_balanced
    jc      .fail

    ; Store args_len
    mov     rax, rdx
    sub     rax, [parser_result_buf + 16]
    mov     [parser_result_buf + 24], rax    ; args_len (includes parens)

    ; Parse params between '(' and ')'
    ; args_off at +16 points to '(', args_len at +24 includes both parens
    ; Param region: from args_off+1 to args_off+args_len-2
    push    rdx                     ; save index after ')'

    xor     ecx, ecx               ; param count
    mov     r10d, [parser_result_buf + 16]
    inc     r10d                    ; skip '('
    mov     r11d, eax
    sub     r11d, 2                 ; len of content between parens
    add     r11d, r10d              ; end offset of content

    ; Save param_names offset
    mov     edx, [param_buf_pos]    ; current position in param_names_buf
    mov     [parser_result_buf + 80], edx

    ; If no params (empty parens), skip
    cmp     r10d, r11d
    jae     .params_done

.params_loop:
    ; Skip whitespace
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, r10d
    call    skip_space
    jc      .params_done
    mov     r10d, edx
    cmp     r10d, r11d
    jae     .params_done

    ; Check for comma or end
    movzx   eax, byte [r12 + r10]
    cmp     al, ','
    je      .params_next
    cmp     al, ')'
    je      .params_done

    ; Found a param - parse name up to ':'
    push    rcx                     ; save param count
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, r10d
    call    scan_identifier_end
    pop     rcx
    jc      .params_next            ; no ident, skip
    ; rdx = end of name, r10 = start of name
    push    r11                     ; save end offset
    push    r10                     ; save name start
    push    rdx                     ; save name end
    push    rcx                     ; save param count

    ; Store param name in param_names_buf
    mov     edi, [param_buf_pos]
    mov     r8d, edx
    sub     r8d, r10d               ; name length
    cmp     edi, 1020               ; bounds check
    jae     .params_store_overflow
    mov     [param_names_buf + edi], r8b  ; length byte
    inc     edi
    ; Copy name bytes
    xor     r9d, r9d
.params_copy_name:
    cmp     r9d, r8d
    jae     .params_name_copied
    lea     rbx, [r12 + r10]
    movzx   eax, byte [rbx + r9]
    lea     rbx, [param_names_buf + edi]
    mov     [rbx + r9], al
    inc     r9d
    jmp     .params_copy_name
.params_name_copied:
    add     edi, r8d
    mov     [param_buf_pos], edi

.params_store_overflow:
    pop     rcx                     ; param count
    pop     rdx                     ; name end
    pop     r10                     ; name start
    pop     r11                     ; end offset

    inc     ecx                     ; count this param

    ; Scan forward to ',' or end
.params_scan_next:
    cmp     r10d, r11d
    jae     .params_done
    movzx   eax, byte [r12 + r10]
    inc     r10d
    cmp     al, ','
    je      .params_next
    cmp     al, ')'
    je      .params_done
    jmp     .params_scan_next

.params_next:
    ; r10d is past ',' or at current position
    jmp     .params_loop

.params_done:
    ; Store param count
    mov     [parser_result_buf + 76], ecx

    pop     rdx                     ; restore index after ')'
    mov     r15, rdx                ; index after ')'

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
    mov     [parser_result_buf + 48], r15    ; body_off = '{' position

    ; Parse body (balanced braces)
    mov     al, '{'
    mov     ah, '}'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r15
    call    scan_balanced
    jc      .fail
    ; rdx = index past '}'
    mov     rax, rdx
    sub     rax, [parser_result_buf + 48]    ; body_len
    mov     [parser_result_buf + 56], rax    ; body_len

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
    er_frame_push
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

    ; Store param info
    mov     eax, [parser_result_buf + 76]
    mov     [body_param_counts + ecx*4], eax
    mov     eax, [parser_result_buf + 80]
    mov     [body_param_base + ecx*4], eax

    ; Compile function body expression
    push    qword [tokenizer_index]
    push    rcx                     ; save export index
    push    r15                     ; save export count

    mov     rdx, [parser_result_buf + 48]  ; body offset
    inc     rdx                            ; skip '{'

    mov     rdi, r12
    mov     rsi, r13
    call    skip_space
    jc      .compile_body_done       ; empty body → skip

    lea     r10, [prefix_return]
    mov     r11, 7
    call    check_prefix
    jc      .compile_body_done       ; no "return " → skip

    ; rdx points past "return "
    ; Set current function index and call compile_fn_body
    mov     ecx, [rsp + 8]          ; export index from stack
    mov     [compile_current_fn_idx], ecx
    mov     rdi, r12
    mov     rsi, r13
    call    compile_fn_body

.compile_body_done:
    pop     r15                     ; restore export count
    pop     rcx                     ; restore export index
    pop     qword [tokenizer_index]
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

; ==================================================================
; Expression Compiler
; ==================================================================

; ------------------------------------------------------------------
; body_putc — write one byte to body_buf
; sil = byte to write
; Returns carry set if body_buf full
; ------------------------------------------------------------------
body_putc:
    er_frame_push
    mov     eax, [body_buf_pos]
    cmp     eax, COMPILED_BODY_BUF_SIZE - 1
    jae     .bp_overflow
    mov     [body_buf + rax], sil
    inc     dword [body_buf_pos]
    clc
    pop     rbp
    ret
.bp_overflow:
    stc
    pop     rbp
    ret

; ------------------------------------------------------------------
; body_put_leb — write LEB128 u32 to body_buf
; eax = value
; Returns carry set on overflow
; ------------------------------------------------------------------
body_put_leb:
    er_frame_push
    push    rbx
    mov     ebx, eax
.bpl_loop:
    mov     eax, [body_buf_pos]
    cmp     eax, COMPILED_BODY_BUF_SIZE - 1
    jae     .bpl_overflow
    mov     eax, ebx
    and     eax, 0x7f
    shr     ebx, 7
    test    ebx, ebx
    jz      .bpl_last
    or      al, 0x80
.bpl_last:
    mov     edx, [body_buf_pos]
    mov     [body_buf + edx], al
    inc     dword [body_buf_pos]
    test    ebx, ebx
    jnz     .bpl_loop
    clc
    pop     rbx
    pop     rbp
    ret
.bpl_overflow:
    stc
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; body_put_leb_s32 — write signed LEB128 i32 to body_buf
; eax = value (signed)
; ------------------------------------------------------------------
body_put_leb_s32:
    er_frame_push
    push    rbx
    mov     ebx, eax
    xor     ecx, ecx
.bpls_loop:
    mov     eax, [body_buf_pos]
    cmp     eax, COMPILED_BODY_BUF_SIZE - 1
    jae     .bpls_overflow
    mov     eax, ebx
    and     eax, 0x7f
    mov     edx, ebx
    sar     edx, 7
    mov     ebx, edx
    test    edx, edx
    jz      .bpls_check_sign
    or      al, 0x80
.bpls_write:
    mov     edx, [body_buf_pos]
    mov     [body_buf + edx], al
    inc     dword [body_buf_pos]
    jmp     .bpls_loop
.bpls_check_sign:
    ; Check sign bit
    test    al, 0x40
    jz      .bpls_done
    ; Need one more byte
    or      al, 0x80
    jmp     .bpls_write
.bpls_done:
    clc
    pop     rbx
    pop     rbp
    ret
.bpls_overflow:
    stc
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; skip_whitespace_and_comma — skip whitespace and commas
; rdi=source, rsi=len, rdx=pos
; Returns rdx = updated position, carry set if past end
; ------------------------------------------------------------------
skip_whitespace_and_comma:
    er_frame_push
.swc_loop:
    cmp     rdx, rsi
    jae     .swc_done
    movzx   eax, byte [rdi + rdx]
    cmp     al, ' '
    je      .swc_skip
    cmp     al, 0x09
    je      .swc_skip
    cmp     al, 0x0a
    je      .swc_skip
    cmp     al, 0x0d
    je      .swc_skip
    cmp     al, ','
    je      .swc_skip
    clc
    pop     rbp
    ret
.swc_skip:
    inc     rdx
    jmp     .swc_loop
.swc_done:
    stc
    pop     rbp
    ret

; ------------------------------------------------------------------
; is_token_char — check if char is valid in tokens (not delimiter)
; al = char
; Returns ZF set if token character (part of identifiers, numbers)
; ------------------------------------------------------------------
is_token_char:
    cmp     al, '0'
    jb      .no
    cmp     al, '9'
    jbe     .yes
    ; Check identifier chars
    call    is_ident_continue
    jz      .yes
    ; Also check '+' '-' '*' '/' '%' ')' ';' etc
    ; Actually these are delimiters
.no:
    xor     eax, eax
    inc     eax
    ret
.yes:
    cmp     al, al
    ret

; ------------------------------------------------------------------
; parse_integer — parse decimal integer at source[pos]
; rdi=source, rsi=len, rdx=pos
; Returns eax=value, rdx=end position, carry set on error
; ------------------------------------------------------------------
parse_integer:
    er_frame_push
    push    rbx
    cmp     rdx, rsi
    jae     .pi_err
    xor     eax, eax
    mov     rcx, rdx                ; save start
.pi_loop:
    cmp     rdx, rsi
    jae     .pi_done
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, '0'
    jb      .pi_done
    cmp     bl, '9'
    ja      .pi_done
    imul    eax, 10
    sub     ebx, '0'
    add     eax, ebx
    inc     rdx
    jmp     .pi_loop
.pi_done:
    cmp     rdx, rcx
    je      .pi_err                 ; no digits consumed
    pop     rbx
    pop     rbp
    ret
.pi_err:
    stc
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; compile_fn_body — compile function body from "return <expr>;"
; rdi=source, rsi=len, rdx=pos (past "return "), ecx=export_idx
; Returns carry set on error
; ------------------------------------------------------------------
global compile_fn_body
compile_fn_body:
    er_frame_push
    push    r12                     ; source
    push    r13                     ; source len
    push    r14                     ; current pos
    push    r15                     ; export index

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15d, ecx

    ; Save starting position in body_buf
    mov     eax, [body_buf_pos]
    mov     [body_offsets + r15*4], eax

    ; Write local count = 0
    mov     sil, 0x00
    call    body_putc
    jc      .cfb_error

    ; Parse and compile expression
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_expr
    jc      .cfb_error
    mov     r14, rdx

    ; Write end opcode
    mov     sil, WASM_OPCODE_END
    call    body_putc
    jc      .cfb_error

    ; Store body length
    mov     eax, [body_buf_pos]
    sub     eax, [body_offsets + r15*4]
    mov     [body_lens + r15*4], eax

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.cfb_error:
    ; Reset body_buf_pos on error (or leave as-is and let emit skip it)
    stc
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ------------------------------------------------------------------
; compile_expr — parse and compile addition/subtraction
; rdi=source, rsi=len, rdx=pos
; Returns rdx=updated pos, carry set on error
; ------------------------------------------------------------------
compile_expr:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx

    ; Parse first term
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx

.ce_loop:
    ; Skip whitespace
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .ce_done
    mov     r14, rdx
    cmp     r14, r13
    jae     .ce_done

    ; Check for '+' or '-'
    movzx   eax, byte [r12 + r14]
    cmp     al, '+'
    je      .ce_add
    cmp     al, '-'
    je      .ce_sub
    cmp     al, '='
    je      .ce_eq
    cmp     al, '!'
    je      .ce_neq
    cmp     al, '<'
    je      .ce_lt
    cmp     al, '>'
    je      .ce_gt
    jmp     .ce_done

.ce_add:
    inc     r14                     ; skip '+'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_ADD
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop

.ce_sub:
    inc     r14                     ; skip '-'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_SUB
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop

.ce_eq:
    inc     r14
    cmp     r14, r13
    jae     .ce_done
    cmp     byte [r12 + r14], '='
    jne     .ce_done
    inc     r14
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_EQ
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop

.ce_neq:
    inc     r14
    cmp     r14, r13
    jae     .ce_done
    cmp     byte [r12 + r14], '='
    jne     .ce_done
    inc     r14
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_NE
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop

.ce_lt:
    inc     r14
    cmp     r14, r13
    jae     .ce_done
    cmp     byte [r12 + r14], '='
    je      .ce_le
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_LT_S
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop
.ce_le:
    inc     r14
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_LE_S
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop

.ce_gt:
    inc     r14
    cmp     r14, r13
    jae     .ce_done
    cmp     byte [r12 + r14], '='
    je      .ce_ge
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_GT_S
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop
.ce_ge:
    inc     r14
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_term
    jc      .ce_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_GE_S
    call    body_putc
    jc      .ce_error
    jmp     .ce_loop

.ce_done:
    clc
    mov     rdx, r14
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.ce_error:
    stc
    mov     rdx, r14
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; compile_term — parse and compile multiplication/division/mod
; rdi=source, rsi=len, rdx=pos
; Returns rdx=updated pos, carry set on error
; ------------------------------------------------------------------
compile_term:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx

    ; Parse first factor
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_factor
    jc      .ct_error
    mov     r14, rdx

.ct_loop:
    ; Skip whitespace
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .ct_done
    mov     r14, rdx
    cmp     r14, r13
    jae     .ct_done

    ; Check for '*', '/', or '%'
    movzx   eax, byte [r12 + r14]
    cmp     al, '*'
    je      .ct_mul
    cmp     al, '/'
    je      .ct_div
    cmp     al, '%'
    je      .ct_rem
    jmp     .ct_done

.ct_mul:
    inc     r14                     ; skip '*'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_factor
    jc      .ct_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_MUL
    call    body_putc
    jc      .ct_error
    jmp     .ct_loop

.ct_div:
    inc     r14                     ; skip '/'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_factor
    jc      .ct_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_DIV_S
    call    body_putc
    jc      .ct_error
    jmp     .ct_loop

.ct_rem:
    inc     r14                     ; skip '%'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_factor
    jc      .ct_error
    mov     r14, rdx
    mov     sil, WASM_OPCODE_I32_REM_S
    call    body_putc
    jc      .ct_error
    jmp     .ct_loop

.ct_done:
    clc
    mov     rdx, r14
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.ct_error:
    stc
    mov     rdx, r14
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; compile_factor — parse and compile a primary expression
; rdi=source, rsi=len, rdx=pos
; Returns rdx=updated pos, carry set on error
; ------------------------------------------------------------------
compile_factor:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 16                 ; local vars: ident_off, ident_len

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx

    ; Skip whitespace
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cf_error
    mov     r14, rdx
    cmp     r14, r13
    jae     .cf_error

    movzx   eax, byte [r12 + r14]

    ; '(' → grouped expression
    cmp     al, '('
    je      .cf_parens

    ; Digit → integer literal
    cmp     al, '0'
    jb      .cf_ident
    cmp     al, '9'
    jbe     .cf_integer

.cf_ident:
    ; Identifier (or keyword that looks like one)
    push    r14                     ; save start
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    scan_identifier_end
    jc      .cf_error
    ; rdx = end of ident
    pop     r15                     ; r15 = ident start offset
    mov     r14, rdx                ; r14 = ident end

    ; Check for keywords: if, true, false
    lea     rdi, [r12 + r15]
    mov     rsi, r14
    sub     rsi, r15
    call    match_keyword

    cmp     eax, TOKEN_KW_IF
    je      .cf_handle_if
    cmp     eax, TOKEN_KW_TRUE
    je      .cf_handle_true
    cmp     eax, TOKEN_KW_FALSE
    je      .cf_handle_false

    ; Save ident info
    mov     [rsp], r15              ; ident_off
    mov     rax, r14
    sub     rax, r15
    mov     [rsp + 8], rax          ; ident_len

    ; Check if next non-whitespace char is '(' → function call
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cf_ident_ref           ; end of input → treat as identifier reference
    cmp     rdx, r13
    jae     .cf_ident_ref
    movzx   eax, byte [r12 + rdx]
    cmp     al, '('
    je      .cf_call

.cf_ident_ref:
    ; Identifier reference: look up params, then consts
    ; Get current function's export index from caller context
    ; r15 = ident start offset, [rsp+8] = ident length
    mov     ecx, [rsp]              ; ident start offset
    mov     r8d, [rsp + 8]          ; ident length
    lea     r10, [r12 + rcx]        ; absolute pointer to ident

    ; First, search params for current function
    ; We need the export index. It's stored in the caller's stack
    ; For now, we'll search from the function currently being compiled.
    ; The export index is in r15 (the outer r15), but we clobbered it.
    ; We'll use a different approach: search all functions' params.
    ; Actually, we need the current export index. It was passed to compile_fn_body.
    ; We can get it by searching back... or we can store it globally.

    ; Alternative: store current export index in a global during compilation
    mov     ecx, [compile_current_fn_idx]
    mov     eax, [body_param_counts + ecx*4]
    test    eax, eax
    jz      .cf_lookup_const        ; no params → skip param lookup

    ; Get param name base
    mov     edi, [body_param_base + ecx*4]
    xor     r9d, r9d               ; param index
.cf_param_loop:
    cmp     r9d, eax               ; param count
    jae     .cf_lookup_const
    cmp     edi, 1023
    jae     .cf_lookup_const
    movzx   ebx, byte [param_names_buf + edi]  ; name length
    inc     edi
    cmp     ebx, r8d
    jne     .cf_param_next
    ; Compare name
    push    rdi
    push    rcx
    push    r8
    lea     rsi, [param_names_buf + edi]
    mov     rdi, r10
    mov     ecx, r8d
    repe    cmpsb
    pop     r8
    pop     rcx
    pop     rdi
    jne     .cf_param_next
    ; Found! Emit local.get
    mov     sil, WASM_OPCODE_LOCAL_GET
    call    body_putc
    jc      .cf_error
    mov     eax, r9d
    call    body_put_leb
    jc      .cf_error
    jmp     .cf_done

.cf_param_next:
    add     edi, ebx               ; skip to next name
    inc     r9d
    jmp     .cf_param_loop

.cf_lookup_const:
    ; Look up in const table
    mov     r11d, [const_decl_count]
    xor     r9d, r9d
.cf_const_loop:
    cmp     r9d, r11d
    jae     .cf_const_default
    mov     eax, [const_name_lens + r9*4]
    cmp     r8d, eax
    jne     .cf_const_next
    mov     rdi, r10
    mov     rsi, [const_name_ptrs + r9*8]
    mov     ecx, r8d
    push    rcx
    push    rdi
    push    rsi
    repe    cmpsb
    pop     rsi
    pop     rdi
    pop     rcx
    jne     .cf_const_next
    ; Found const! Emit i32.const <value>
    mov     sil, WASM_I32_CONST
    call    body_putc
    jc      .cf_error
    mov     eax, [const_values + r9*4]
    call    body_put_leb
    jc      .cf_error
    jmp     .cf_done
.cf_const_next:
    inc     r9d
    jmp     .cf_const_loop

.cf_const_default:
    ; Not found: emit i32.const 0 as fallback
    mov     sil, WASM_I32_CONST
    call    body_putc
    jc      .cf_error
    xor     eax, eax
    call    body_put_leb
    jc      .cf_error
    jmp     .cf_done

.cf_call:
    ; Function call: identifier(args)
    ; r15 = ident start, [rsp+8] = ident len
    ; rdx (from skip_space) = position of '('
    ; Search export names (base + user) for function index

    ; First skip '('
    inc     rdx
    mov     r14, rdx

    ; Parse args (recursively)
    ; Count commas to determine number of args
    ; For now, parse one expression per arg
    ; Simple approach: just recursively parse expressions until ')'
    xor     r9d, r9d               ; arg count
.cf_call_args:
    ; Skip whitespace
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cf_call_end_parens
    mov     r14, rdx
    cmp     r14, r13
    jae     .cf_call_end_parens
    movzx   eax, byte [r12 + r14]
    cmp     al, ')'
    je      .cf_call_end_parens
    test    r9d, r9d
    jz      .cf_call_parse_arg
    ; Check for comma before next arg
    cmp     al, ','
    jne     .cf_call_end_parens
    inc     r14
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cf_error
    mov     r14, rdx

.cf_call_parse_arg:
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_expr
    jc      .cf_call_not_found
    mov     r14, rdx
    inc     r9d
    jmp     .cf_call_args

.cf_call_end_parens:
    ; r14 should be at ')'
    cmp     r14, r13
    jae     .cf_call_not_found
    movzx   eax, byte [r12 + r14]
    cmp     al, ')'
    jne     .cf_call_not_found
    inc     r14                    ; skip ')'

    ; Look up function index by name
    ; Search user exports first, then base functions
    mov     ecx, [export_name_count]
    xor     r9d, r9d
    mov     r10, r12
    add     r10, [rsp]             ; ident absolute ptr (rsp = ident_off)
    mov     r8d, [rsp + 8]         ; ident length
.cf_call_search:
    cmp     r9d, ecx
    jae     .cf_call_search_base
    mov     eax, [export_name_lens + r9*4]
    cmp     r8d, eax
    jne     .cf_call_search_next
    mov     rdi, r10
    mov     rsi, [export_name_ptrs + r9*8]
    mov     ecx, r8d
    push    rcx
    push    rdi
    push    rsi
    repe    cmpsb
    pop     rsi
    pop     rdi
    pop     rcx
    jne     .cf_call_search_next
    ; Found! Function index = 27 + r9d
    lea     eax, [r9 + SUCCESSOR_BASE_FUNCTION_COUNT]
    push    rax                     ; save func index (body_putc clobbers eax)
    mov     sil, WASM_OPCODE_CALL
    call    body_putc
    jc      .cf_call_ret_abort
    pop     rax                     ; restore func index
    call    body_put_leb
    jc      .cf_call_put_abort
    jmp     .cf_call_done

.cf_call_put_abort:
    jmp     .cf_call_not_found

.cf_call_ret_abort:
    add     rsp, 8
    jmp     .cf_call_not_found
    jmp     .cf_call_done

.cf_call_search_next:
    inc     r9d
    mov     ecx, [export_name_count]
    jmp     .cf_call_search

.cf_call_search_base:
    ; TODO: search base function export table
    ; For now, not found → return error
.cf_call_not_found:
    stc
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.cf_call_done:
    ; r14 already points past ')'
    jmp     .cf_done

.cf_handle_if:
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_if_expr
    jc      .cf_error
    mov     r14, rdx
    jmp     .cf_done

.cf_handle_true:
    mov     sil, WASM_I32_CONST
    call    body_putc
    jc      .cf_error
    mov     eax, 1
    call    body_put_leb
    jc      .cf_error
    jmp     .cf_done

.cf_handle_false:
    mov     sil, WASM_I32_CONST
    call    body_putc
    jc      .cf_error
    xor     eax, eax
    call    body_put_leb
    jc      .cf_error
    jmp     .cf_done

.cf_integer:
    ; Integer literal: parse and emit i32.const
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    parse_integer
    jc      .cf_error
    ; eax = value, rdx = end
    mov     r14, rdx
    push    rax                     ; save value (body_putc clobbers eax)
    mov     sil, WASM_I32_CONST
    call    body_putc
    jc      .cf_leb_abort
    pop     rax                     ; restore value for body_put_leb
    call    body_put_leb
    jc      .cf_error
    jmp     .cf_done

.cf_leb_abort:
    add     rsp, 8
    jmp     .cf_error

.cf_parens:
    ; '(' expr ')'
    inc     r14                    ; skip '('
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_expr
    jc      .cf_error
    mov     r14, rdx

    ; Expect ')'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cf_error
    mov     r14, rdx
    cmp     r14, r13
    jae     .cf_error
    movzx   eax, byte [r12 + r14]
    cmp     al, ')'
    jne     .cf_error
    inc     r14                    ; skip ')'
    jmp     .cf_done

.cf_error:
    stc
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.cf_done:
    mov     rdx, r14
    add     rsp, 16
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; compile_if_expr — parse and compile if/else expression
; rdi=source, rsi=len, rdx=pos (past "if")
; Expects: if <cond> { <then_expr> } else { <else_expr> }
; Returns rdx=updated pos, carry set on error
; ------------------------------------------------------------------
global compile_if_expr
compile_if_expr:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx

    ; Skip whitespace after "if"
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_error
    mov     r14, rdx

    ; Parse condition expression
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_expr
    jc      .cie_error
    mov     r14, rdx

    ; Expect '{'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_error
    mov     r14, rdx
    cmp     r14, r13
    jae     .cie_error
    cmp     byte [r12 + r14], '{'
    jne     .cie_error
    inc     r14                     ; skip '{'

    ; Emit IF opcode + i32 block type
    mov     sil, WASM_OPCODE_IF
    call    body_putc
    jc      .cie_error
    mov     sil, 0x7f               ; block type = i32
    call    body_putc
    jc      .cie_error

    ; Compile then-branch expression
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_close_brace
    mov     r14, rdx
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_expr
    jc      .cie_close_brace
    mov     r14, rdx

.cie_close_brace:
    ; Expect '}'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_error
    mov     r14, rdx
    cmp     r14, r13
    jae     .cie_error
    cmp     byte [r12 + r14], '}'
    jne     .cie_error
    inc     r14                     ; skip '}'

    ; Check for "else"
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_endif
    mov     r14, rdx
    cmp     r14, r13
    jae     .cie_endif

    ; Check if next word is "else"
    lea     rdi, [r12 + r14]
    mov     rsi, r13
    sub     rsi, r14
    lea     rdx, [kw_str.k_else]
    call    keyword_match
    jnz     .cie_endif

    ; It's "else"
    add     r14, 4                  ; skip "else"

    ; Emit ELSE opcode
    mov     sil, WASM_OPCODE_ELSE
    call    body_putc
    jc      .cie_error

    ; Expect '{'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_error
    mov     r14, rdx
    cmp     r14, r13
    jae     .cie_error
    cmp     byte [r12 + r14], '{'
    jne     .cie_error
    inc     r14                     ; skip '{'

    ; Compile else-branch expression
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_else_close
    mov     r14, rdx
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    compile_expr
    jc      .cie_else_close
    mov     r14, rdx

.cie_else_close:
    ; Expect '}'
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    call    skip_space
    jc      .cie_error
    mov     r14, rdx
    cmp     r14, r13
    jae     .cie_error
    cmp     byte [r12 + r14], '}'
    jne     .cie_error
    inc     r14                     ; skip '}'

.cie_endif:
    ; Emit END opcode
    mov     sil, WASM_OPCODE_END
    call    body_putc
    jc      .cie_error

    mov     rdx, r14
    clc
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.cie_error:
    stc
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Globals used during compilation
; ------------------------------------------------------------------
SECTION .bss
compile_current_fn_idx: resd 1
