; EdgeRun host-side WASM compiler self-test.
; Emits a deterministic WASM module and executes it through the interpreter.

%define HAVE_ER_WASM_RUNTIME_PTR
%define ER_WASMC_NO_EXTERN_RUN
%include "x86_64/wasm/wasm_interpreter.asm"
%include "x86_64/wasm/wasm_compiler.asm"
%include "x86_64/wasm/wasm_test_data.asm"

LINUX_SYS_EXIT equ 60

SECTION .data
dummy_mem: times 256 db 0
export_name: db "f"
EXPORT_NAME_LEN equ $ - export_name
source_return42: db "export f = 42;"
SOURCE_RETURN42_LEN equ $ - source_return42
source_named: db "  export answer_1 = 123;  "
SOURCE_NAMED_LEN equ $ - source_named
source_i32_max: db "export max_i32 = 2147483647;"
SOURCE_I32_MAX_LEN equ $ - source_i32_max
source_i32_min: db "export min_i32 = -2147483648;"
SOURCE_I32_MIN_LEN equ $ - source_i32_min
source_hex: db "export hex = 0x2a;"
SOURCE_HEX_LEN equ $ - source_hex
source_hex_upper: db "export hex_upper = 0X2A;"
SOURCE_HEX_UPPER_LEN equ $ - source_hex_upper
source_hex_min: db "export hex_min = -0x80000000;"
SOURCE_HEX_MIN_LEN equ $ - source_hex_min
source_let: db "export let_sum = let x = 40; x + 2;"
SOURCE_LET_LEN equ $ - source_let
source_let_chain: db "export let_chain = let x = 5; let y = x * 8; y + 2;"
SOURCE_LET_CHAIN_LEN equ $ - source_let_chain
source_let_expr: db "export let_expr = let x = 6 + 1; (x * x) - 7;"
SOURCE_LET_EXPR_LEN equ $ - source_let_expr
source_if_true: db "export if_true = if (1) (42) (7);"
SOURCE_IF_TRUE_LEN equ $ - source_if_true
source_if_false: db "export if_false = if (0) (7) (42);"
SOURCE_IF_FALSE_LEN equ $ - source_if_false
source_if_expr: db "export if_expr = if (6 * 7 == 42) (40 + 2) (1);"
SOURCE_IF_EXPR_LEN equ $ - source_if_expr
source_if_local: db "export if_local = let x = 42; if (x == 42) (x) (0);"
SOURCE_IF_LOCAL_LEN equ $ - source_if_local
source_add: db "export sum = 40 + 2;"
SOURCE_ADD_LEN equ $ - source_add
source_sub: db "export diff = 50 - 8;"
SOURCE_SUB_LEN equ $ - source_sub
source_mul: db "export product = 6 * 7;"
SOURCE_MUL_LEN equ $ - source_mul
source_div: db "export quotient = 84 / 2;"
SOURCE_DIV_LEN equ $ - source_div
source_div_round: db "export div_round = 43 / 5;"
SOURCE_DIV_ROUND_LEN equ $ - source_div_round
source_rem: db "export rem = 47 % 5;"
SOURCE_REM_LEN equ $ - source_rem
source_shl: db "export shl = 21 << 1;"
SOURCE_SHL_LEN equ $ - source_shl
source_shr: db "export shr = 84 >> 1;"
SOURCE_SHR_LEN equ $ - source_shr
source_ushr: db "export ushr = -84 >>> 1;"
SOURCE_USHR_LEN equ $ - source_ushr
source_eq: db "export eq = 42 == 42;"
SOURCE_EQ_LEN equ $ - source_eq
source_ne: db "export ne = 42 != 41;"
SOURCE_NE_LEN equ $ - source_ne
source_lt: db "export lt = -1 < 1;"
SOURCE_LT_LEN equ $ - source_lt
source_gt: db "export gt = 42 > 41;"
SOURCE_GT_LEN equ $ - source_gt
source_le: db "export le = 42 <= 42;"
SOURCE_LE_LEN equ $ - source_le
source_ge: db "export ge = 42 >= 42;"
SOURCE_GE_LEN equ $ - source_ge
source_and: db "export mask = 46 & 58;"
SOURCE_AND_LEN equ $ - source_and
source_or: db "export bits = 40 | 2;"
SOURCE_OR_LEN equ $ - source_or
source_xor: db "export flip = 46 ^ 4;"
SOURCE_XOR_LEN equ $ - source_xor
source_add_chain: db "export add_chain = 10 + 5 + 20 + 7;"
SOURCE_ADD_CHAIN_LEN equ $ - source_add_chain
source_or_chain: db "export or_chain = 2 | 8 | 32;"
SOURCE_OR_CHAIN_LEN equ $ - source_or_chain
source_mul_precedence: db "export mul_prec = 2 + 5 * 8;"
SOURCE_MUL_PRECEDENCE_LEN equ $ - source_mul_precedence
source_rem_precedence: db "export rem_prec = 2 + 47 % 5 * 8;"
SOURCE_REM_PRECEDENCE_LEN equ $ - source_rem_precedence
source_shift_precedence: db "export shift_prec = 1 + 5 << 2;"
SOURCE_SHIFT_PRECEDENCE_LEN equ $ - source_shift_precedence
source_ushr_precedence: db "export ushr_prec = 1 + 5 >>> 1;"
SOURCE_USHR_PRECEDENCE_LEN equ $ - source_ushr_precedence
source_cmp_precedence: db "export cmp_prec = 1 + 5 == 6;"
SOURCE_CMP_PRECEDENCE_LEN equ $ - source_cmp_precedence
source_cmp_bit: db "export cmp_bit = 8 | 5 < 3;"
SOURCE_CMP_BIT_LEN equ $ - source_cmp_bit
source_shift_bit: db "export shift_bit = 8 | 5 << 3;"
SOURCE_SHIFT_BIT_LEN equ $ - source_shift_bit
source_bit_precedence: db "export bit_prec = 40 | 6 & 2;"
SOURCE_BIT_PRECEDENCE_LEN equ $ - source_bit_precedence
source_sub_assoc: db "export sub_assoc = 50 - 5 - 3;"
SOURCE_SUB_ASSOC_LEN equ $ - source_sub_assoc
source_div_assoc: db "export div_assoc = 168 / 2 / 2;"
SOURCE_DIV_ASSOC_LEN equ $ - source_div_assoc
source_paren_mul: db "export paren_mul = (2 + 5) * 6;"
SOURCE_PAREN_MUL_LEN equ $ - source_paren_mul
source_nested: db "export nested = (50 - (5 + 3)) | 0;"
SOURCE_NESTED_LEN equ $ - source_nested
source_negative: db "export neg = -7;"
SOURCE_NEGATIVE_LEN equ $ - source_negative
source_add_negative: db "export sum_neg = -40 + 2;"
SOURCE_ADD_NEGATIVE_LEN equ $ - source_add_negative
source_sub_negative: db "export diff_neg = -40 - 2;"
SOURCE_SUB_NEGATIVE_LEN equ $ - source_sub_negative
source_rem_negative: db "export rem_neg = -47 % 5;"
SOURCE_REM_NEGATIVE_LEN equ $ - source_rem_negative
source_shr_negative: db "export neg_shr = -84 >> 1;"
SOURCE_SHR_NEGATIVE_LEN equ $ - source_shr_negative
source_div_zero: db "export div_zero = 42 / 0;"
SOURCE_DIV_ZERO_LEN equ $ - source_div_zero
source_rem_zero: db "export rem_zero = 42 % 0;"
SOURCE_REM_ZERO_LEN equ $ - source_rem_zero
source_unclosed_group: db "export bad_group = (1 + 2;"
SOURCE_UNCLOSED_GROUP_LEN equ $ - source_unclosed_group
source_bad_close: db "export bad_close = 1 + 2);"
SOURCE_BAD_CLOSE_LEN equ $ - source_bad_close
source_empty_group: db "export empty_group = ();"
SOURCE_EMPTY_GROUP_LEN equ $ - source_empty_group
source_bad_shift: db "export bad_shift = 1 < 2;"
SOURCE_BAD_SHIFT_LEN equ $ - source_bad_shift
source_bad_gt: db "export bad_gt = 1 > 2;"
SOURCE_BAD_GT_LEN equ $ - source_bad_gt
source_bad_ushr: db "export bad_ushr = 1 >>>> 2;"
SOURCE_BAD_USHR_LEN equ $ - source_bad_ushr
source_bad_eq: db "export bad_eq = 1 = 1;"
SOURCE_BAD_EQ_LEN equ $ - source_bad_eq
source_bad_bang: db "export bad_bang = 1 ! 1;"
SOURCE_BAD_BANG_LEN equ $ - source_bad_bang
source_i32_over: db "export too_big = 2147483648;"
SOURCE_I32_OVER_LEN equ $ - source_i32_over
source_i32_under: db "export too_small = -2147483649;"
SOURCE_I32_UNDER_LEN equ $ - source_i32_under
source_hex_over: db "export hex_over = 0x80000000;"
SOURCE_HEX_OVER_LEN equ $ - source_hex_over
source_hex_under: db "export hex_under = -0x80000001;"
SOURCE_HEX_UNDER_LEN equ $ - source_hex_under
source_hex_empty: db "export hex_empty = 0x;"
SOURCE_HEX_EMPTY_LEN equ $ - source_hex_empty
source_unknown_local: db "export bad_local = missing + 1;"
SOURCE_UNKNOWN_LOCAL_LEN equ $ - source_unknown_local
source_dup_local: db "export dup_local = let x = 1; let x = 2; x;"
SOURCE_DUP_LOCAL_LEN equ $ - source_dup_local
source_if_missing_else: db "export if_missing_else = if (1) (42);"
SOURCE_IF_MISSING_ELSE_LEN equ $ - source_if_missing_else
source_if_bad_arm: db "export if_bad_arm = if (1) 42 (0);"
SOURCE_IF_BAD_ARM_LEN equ $ - source_if_bad_arm
source_bad: db "export = 1;"
SOURCE_BAD_LEN equ $ - source_bad
wasm_compile_run_cases:
    dq source_named, SOURCE_NAMED_LEN, 123
    dq source_i32_max, SOURCE_I32_MAX_LEN, 0x7fffffff
    dq source_i32_min, SOURCE_I32_MIN_LEN, 0x80000000
    dq source_hex, SOURCE_HEX_LEN, 42
    dq source_hex_upper, SOURCE_HEX_UPPER_LEN, 42
    dq source_hex_min, SOURCE_HEX_MIN_LEN, 0x80000000
    dq source_let, SOURCE_LET_LEN, 42
    dq source_let_chain, SOURCE_LET_CHAIN_LEN, 42
    dq source_let_expr, SOURCE_LET_EXPR_LEN, 42
    dq source_if_true, SOURCE_IF_TRUE_LEN, 42
    dq source_if_false, SOURCE_IF_FALSE_LEN, 42
    dq source_if_expr, SOURCE_IF_EXPR_LEN, 42
    dq source_if_local, SOURCE_IF_LOCAL_LEN, 42
    dq source_add, SOURCE_ADD_LEN, 42
    dq source_sub, SOURCE_SUB_LEN, 42
    dq source_mul, SOURCE_MUL_LEN, 42
    dq source_div, SOURCE_DIV_LEN, 42
    dq source_div_round, SOURCE_DIV_ROUND_LEN, 8
    dq source_rem, SOURCE_REM_LEN, 2
    dq source_shl, SOURCE_SHL_LEN, 42
    dq source_shr, SOURCE_SHR_LEN, 42
    dq source_ushr, SOURCE_USHR_LEN, 0x7fffffd6
    dq source_eq, SOURCE_EQ_LEN, 1
    dq source_ne, SOURCE_NE_LEN, 1
    dq source_lt, SOURCE_LT_LEN, 1
    dq source_gt, SOURCE_GT_LEN, 1
    dq source_le, SOURCE_LE_LEN, 1
    dq source_ge, SOURCE_GE_LEN, 1
    dq source_and, SOURCE_AND_LEN, 42
    dq source_or, SOURCE_OR_LEN, 42
    dq source_xor, SOURCE_XOR_LEN, 42
    dq source_add_chain, SOURCE_ADD_CHAIN_LEN, 42
    dq source_or_chain, SOURCE_OR_CHAIN_LEN, 42
    dq source_mul_precedence, SOURCE_MUL_PRECEDENCE_LEN, 42
    dq source_rem_precedence, SOURCE_REM_PRECEDENCE_LEN, 18
    dq source_shift_precedence, SOURCE_SHIFT_PRECEDENCE_LEN, 24
    dq source_ushr_precedence, SOURCE_USHR_PRECEDENCE_LEN, 3
    dq source_cmp_precedence, SOURCE_CMP_PRECEDENCE_LEN, 1
    dq source_cmp_bit, SOURCE_CMP_BIT_LEN, 8
    dq source_shift_bit, SOURCE_SHIFT_BIT_LEN, 40
    dq source_bit_precedence, SOURCE_BIT_PRECEDENCE_LEN, 42
    dq source_sub_assoc, SOURCE_SUB_ASSOC_LEN, 42
    dq source_div_assoc, SOURCE_DIV_ASSOC_LEN, 42
    dq source_paren_mul, SOURCE_PAREN_MUL_LEN, 42
    dq source_nested, SOURCE_NESTED_LEN, 42
    dq source_negative, SOURCE_NEGATIVE_LEN, 0xfffffff9
    dq source_add_negative, SOURCE_ADD_NEGATIVE_LEN, 0xffffffda
    dq source_sub_negative, SOURCE_SUB_NEGATIVE_LEN, 0xffffffd6
    dq source_rem_negative, SOURCE_REM_NEGATIVE_LEN, 0xfffffffe
    dq source_shr_negative, SOURCE_SHR_NEGATIVE_LEN, 0xffffffd6
    dq source_bad_shift, SOURCE_BAD_SHIFT_LEN, 1
    dq source_bad_gt, SOURCE_BAD_GT_LEN, 0
WASM_COMPILE_RUN_CASE_SIZE equ 24
wasm_compile_run_cases_end:
WASM_COMPILE_RUN_CASES equ (wasm_compile_run_cases_end - wasm_compile_run_cases) / WASM_COMPILE_RUN_CASE_SIZE
wasm_compile_parse_error_cases:
    dq source_bad, SOURCE_BAD_LEN
    dq source_unclosed_group, SOURCE_UNCLOSED_GROUP_LEN
    dq source_bad_close, SOURCE_BAD_CLOSE_LEN
    dq source_empty_group, SOURCE_EMPTY_GROUP_LEN
    dq source_bad_ushr, SOURCE_BAD_USHR_LEN
    dq source_bad_eq, SOURCE_BAD_EQ_LEN
    dq source_bad_bang, SOURCE_BAD_BANG_LEN
    dq source_i32_over, SOURCE_I32_OVER_LEN
    dq source_i32_under, SOURCE_I32_UNDER_LEN
    dq source_hex_over, SOURCE_HEX_OVER_LEN
    dq source_hex_under, SOURCE_HEX_UNDER_LEN
    dq source_hex_empty, SOURCE_HEX_EMPTY_LEN
    dq source_unknown_local, SOURCE_UNKNOWN_LOCAL_LEN
    dq source_dup_local, SOURCE_DUP_LOCAL_LEN
    dq source_if_missing_else, SOURCE_IF_MISSING_ELSE_LEN
    dq source_if_bad_arm, SOURCE_IF_BAD_ARM_LEN
WASM_COMPILE_PARSE_ERROR_CASE_SIZE equ 16
wasm_compile_parse_error_cases_end:
WASM_COMPILE_PARSE_ERROR_CASES equ (wasm_compile_parse_error_cases_end - wasm_compile_parse_error_cases) / WASM_COMPILE_PARSE_ERROR_CASE_SIZE
wasm_compile_run_error_cases:
    dq source_bad, SOURCE_BAD_LEN, ERROR_PARSE
    dq source_unclosed_group, SOURCE_UNCLOSED_GROUP_LEN, ERROR_PARSE
    dq source_bad_close, SOURCE_BAD_CLOSE_LEN, ERROR_PARSE
    dq source_empty_group, SOURCE_EMPTY_GROUP_LEN, ERROR_PARSE
    dq source_bad_ushr, SOURCE_BAD_USHR_LEN, ERROR_PARSE
    dq source_bad_eq, SOURCE_BAD_EQ_LEN, ERROR_PARSE
    dq source_bad_bang, SOURCE_BAD_BANG_LEN, ERROR_PARSE
    dq source_i32_over, SOURCE_I32_OVER_LEN, ERROR_PARSE
    dq source_i32_under, SOURCE_I32_UNDER_LEN, ERROR_PARSE
    dq source_hex_over, SOURCE_HEX_OVER_LEN, ERROR_PARSE
    dq source_hex_under, SOURCE_HEX_UNDER_LEN, ERROR_PARSE
    dq source_hex_empty, SOURCE_HEX_EMPTY_LEN, ERROR_PARSE
    dq source_unknown_local, SOURCE_UNKNOWN_LOCAL_LEN, ERROR_PARSE
    dq source_dup_local, SOURCE_DUP_LOCAL_LEN, ERROR_PARSE
    dq source_if_missing_else, SOURCE_IF_MISSING_ELSE_LEN, ERROR_PARSE
    dq source_if_bad_arm, SOURCE_IF_BAD_ARM_LEN, ERROR_PARSE
    dq source_div_zero, SOURCE_DIV_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_rem_zero, SOURCE_REM_ZERO_LEN, ERROR_ARITHMETIC_TRAP
WASM_COMPILE_RUN_ERROR_CASE_SIZE equ 24
wasm_compile_run_error_cases_end:
WASM_COMPILE_RUN_ERROR_CASES equ (wasm_compile_run_error_cases_end - wasm_compile_run_error_cases) / WASM_COMPILE_RUN_ERROR_CASE_SIZE

SECTION .bss
runtime: resb RUNTIME_SIZE
compiled_wasm: resb 128
compiled_wasm_b: resb 128

global er_wasm_runtime_ptr
er_wasm_runtime_ptr: resq 1

SECTION .text
global _start
_start:
    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    mov     edx, 42
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_wasmc_emit_i32_const_export
    test    rdx, rdx
    jnz     .fail

    mov     r12, rax
    mov     rdi, [rel wasm_return42_len]
    cmp     r12, rdi
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel wasm_return42_start]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel dummy_mem]
    mov     esi, 256
    xor     edx, edx
    call    er_fn_init

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_return42]
    mov     ecx, SOURCE_RETURN42_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail

    mov     r12, rax
    mov     rdi, [rel wasm_return42_len]
    cmp     r12, rdi
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel wasm_return42_start]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rbx, [rel wasm_compile_run_cases]
    mov     r12d, WASM_COMPILE_RUN_CASES
.compile_run_loop:
    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    mov     rdx, [rbx]
    mov     rcx, [rbx + 8]
    lea     r8, [rel runtime]
    call    er_wasmc_compile_source_run
    test    rdx, rdx
    jnz     .fail
    mov     r13, rcx
    cmp     eax, [rbx + 16]
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    mov     rdx, [rbx]
    mov     rcx, [rbx + 8]
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail
    cmp     rax, r13
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r13
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    add     rbx, WASM_COMPILE_RUN_CASE_SIZE
    dec     r12d
    jnz     .compile_run_loop

    lea     rbx, [rel wasm_compile_parse_error_cases]
    mov     r12d, WASM_COMPILE_PARSE_ERROR_CASES
.parse_error_loop:
    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    mov     rdx, [rbx]
    mov     rcx, [rbx + 8]
    call    er_wasmc_compile_source
    cmp     rdx, ERROR_PARSE
    jne     .fail
    add     rbx, WASM_COMPILE_PARSE_ERROR_CASE_SIZE
    dec     r12d
    jnz     .parse_error_loop

    lea     rbx, [rel wasm_compile_run_error_cases]
    mov     r12d, WASM_COMPILE_RUN_ERROR_CASES
.run_error_loop:
    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    mov     rdx, [rbx]
    mov     rcx, [rbx + 8]
    lea     r8, [rel runtime]
    call    er_wasmc_compile_source_run
    cmp     rdx, [rbx + 16]
    jne     .fail
    add     rbx, WASM_COMPILE_RUN_ERROR_CASE_SIZE
    dec     r12d
    jnz     .run_error_loop

    xor     edi, edi
    mov     eax, LINUX_SYS_EXIT
    syscall

.fail:
    mov     edi, 1
    mov     eax, LINUX_SYS_EXIT
    syscall

_bytes_equal:
    test    rdx, rdx
    jz      .equal
.loop:
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .not_equal
    inc     rdi
    inc     rsi
    dec     rdx
    jnz     .loop
.equal:
    mov     eax, 1
    ret
.not_equal:
    xor     eax, eax
    ret
