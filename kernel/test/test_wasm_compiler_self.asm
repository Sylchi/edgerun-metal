; EdgeRun host-side WASM compiler self-test.
; Emits a deterministic WASM module and executes it through the interpreter.

%define HAVE_ER_WASM_RUNTIME_PTR
%define ER_WASMC_NO_EXTERN_RUN
%define ER_TSX_PARSER_NO_EXTERN_WASMC
%include "x86_64/wasm/wasm_interpreter.asm"
%include "x86_64/wasm/wasm_compiler.asm"
%include "x86_64/wasm/tsx_parser.asm"
%include "x86_64/wasm/wasm_test_data.asm"
%include "test/test_macros.inc"

SECTION .data
dummy_mem: times WASM_PAGE_SIZE db 0
export_name: db "f"
EXPORT_NAME_LEN equ $ - export_name
call_export_name: db "call_sum"
CALL_EXPORT_NAME_LEN equ $ - call_export_name
call_pair_export_name: db "call_pair"
CALL_PAIR_EXPORT_NAME_LEN equ $ - call_pair_export_name
call_param_export_name: db "call_param"
CALL_PARAM_EXPORT_NAME_LEN equ $ - call_param_export_name
add_export_name: db "add"
ADD_EXPORT_NAME_LEN equ $ - add_export_name
wasm_add_i32:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x07,0x01,0x60,0x02,0x7f,0x7f,0x01,0x7f
    db 0x03,0x02,0x01,0x00
    db 0x07,0x07,0x01,0x03,0x61,0x64,0x64,0x00,0x00
    db 0x0a,0x09,0x01,0x07,0x00,0x20,0x00,0x20,0x01,0x6a,0x0b
wasm_add_i32_len equ $ - wasm_add_i32
wasm_elem_active:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x04,0x01,0x60,0x00,0x00
    db 0x03,0x03,0x02,0x00,0x00
    db 0x04,0x04,0x01,0x70,0x00,0x02
    db 0x09,0x08,0x01,0x00,0x41,0x01,0x0b,0x00,0x01,0x01
    db 0x0a,0x07,0x02,0x02,0x00,0x0b,0x02,0x00,0x0b
wasm_elem_active_len equ $ - wasm_elem_active
wasm_elem_expr_unsupported:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x04,0x01,0x60,0x00,0x00
    db 0x03,0x03,0x02,0x00,0x00
    db 0x04,0x04,0x01,0x70,0x00,0x02
    db 0x09,0x09,0x01,0x04,0x41,0x00,0x0b,0x01,0xd2,0x01,0x0b
    db 0x0a,0x07,0x02,0x02,0x00,0x0b,0x02,0x00,0x0b
wasm_elem_expr_unsupported_len equ $ - wasm_elem_expr_unsupported
wasm_table_bulk:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x05,0x01,0x60,0x00,0x01,0x7f
    db 0x03,0x03,0x02,0x00,0x00
    db 0x04,0x04,0x01,0x70,0x00,0x04
    db 0x07,0x05,0x01,0x01,0x66,0x00,0x00
    db 0x09,0x05,0x01,0x01,0x00,0x01,0x01
    db 0x0a,0x3a,0x02
    db 0x33,0x00
    db 0x41,0x00,0xd2,0x00,0x41,0x03,0xfc,0x11,0x80,0x00
    db 0x41,0x01,0x41,0x00,0x41,0x02,0xfc,0x0e,0x00,0x00
    db 0xd2,0x01,0x41,0x01,0xfc,0x0f,0x00,0x1a
    db 0xfc,0x10,0x00,0x1a
    db 0x41,0x04,0x41,0x00,0x41,0x01,0xfc,0x0c,0x00,0x00
    db 0xfc,0x0d,0x00
    db 0x41,0x04,0x25,0x00,0x0b
    db 0x04,0x00,0x41,0x63,0x0b
wasm_table_bulk_len equ $ - wasm_table_bulk
wasm_bad_memory_index:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x05,0x01,0x60,0x00,0x01,0x7f
    db 0x03,0x02,0x01,0x00
    db 0x05,0x03,0x01,0x00,0x00
    db 0x07,0x05,0x01,0x01,0x66,0x00,0x00
    db 0x0a,0x10,0x01,0x0e,0x00
    db 0x41,0x00,0x41,0x00,0x41,0x00,0xfc,0x0a,0x01,0x00
    db 0x41,0x01,0x0b
wasm_bad_memory_index_len equ $ - wasm_bad_memory_index
wasm_bad_table_index:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x05,0x01,0x60,0x00,0x01,0x7f
    db 0x03,0x03,0x02,0x00,0x00
    db 0x04,0x04,0x01,0x70,0x00,0x01
    db 0x07,0x05,0x01,0x01,0x66,0x00,0x00
    db 0x0a,0x12,0x02
    db 0x0b,0x00,0x41,0x00,0xd2,0x00,0x41,0x01,0xfc,0x11,0x01,0x0b
    db 0x04,0x00,0x41,0x63,0x0b
wasm_bad_table_index_len equ $ - wasm_bad_table_index
wasm_memory_init_passive:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x05,0x01,0x60,0x00,0x01,0x7f
    db 0x03,0x02,0x01,0x00
    db 0x05,0x03,0x01,0x00,0x01
    db 0x07,0x05,0x01,0x01,0x66,0x00,0x00
    db 0x0c,0x01,0x01
    db 0x0a,0x17,0x01,0x15,0x00
    db 0x41,0x00,0x41,0x00,0x41,0x01,0xfc,0x08,0x00,0x80,0x00
    db 0xfc,0x09,0x00
    db 0x41,0x00,0x2d,0x00,0x00,0x0b
    db 0x0b,0x04,0x01,0x01,0x01,0x41
wasm_memory_init_passive_len equ $ - wasm_memory_init_passive
wasm_if_skip_memory_immediates:
    db 0x00,0x61,0x73,0x6d, 0x01,0x00,0x00,0x00
    db 0x01,0x05,0x01,0x60,0x00,0x01,0x7f
    db 0x03,0x02,0x01,0x00
    db 0x05,0x03,0x01,0x00,0x01
    db 0x07,0x05,0x01,0x01,0x66,0x00,0x00
    db 0x0a,0x13,0x01,0x11,0x00
    db 0x41,0x00,0x04,0x7f
    db 0x41,0x00,0x28,0x00,0x05,0x41,0x63
    db 0x05,0x41,0x2a,0x0b,0x0b
wasm_if_skip_memory_immediates_len equ $ - wasm_if_skip_memory_immediates
body_i32_40: db 0x41, 0x28
BODY_I32_40_LEN equ $ - body_i32_40
body_i32_20: db 0x41, 0x14
BODY_I32_20_LEN equ $ - body_i32_20
body_i32_22: db 0x41, 0x16
BODY_I32_22_LEN equ $ - body_i32_22
body_call0_add2: db 0x10, 0x00, 0x41, 0x02, 0x6a
BODY_CALL0_ADD2_LEN equ $ - body_call0_add2
body_call0_call1_add: db 0x10, 0x00, 0x10, 0x01, 0x6a
BODY_CALL0_CALL1_ADD_LEN equ $ - body_call0_call1_add
body_param_add: db 0x20, 0x00, 0x20, 0x01, 0x6a
BODY_PARAM_ADD_LEN equ $ - body_param_add
body_call_param_add: db 0x41, 0x13, 0x41, 0x17, 0x10, 0x00
BODY_CALL_PARAM_ADD_LEN equ $ - body_call_param_add
body_table_call_pair:
    dq body_i32_20, BODY_I32_20_LEN
    dq body_i32_22, BODY_I32_22_LEN
    dq body_call0_call1_add, BODY_CALL0_CALL1_ADD_LEN
body_table_call_param:
    dq body_param_add, BODY_PARAM_ADD_LEN
    dq body_call_param_add, BODY_CALL_PARAM_ADD_LEN
sig_table_call_param:
    dq 2, 0
    dq 0, 0
source_call_pair: db "export base = 40; export call_sum = base() + 2;"
SOURCE_CALL_PAIR_LEN equ $ - source_call_pair
source_call_id: db "export base = 42; export call_id = base();"
SOURCE_CALL_ID_LEN equ $ - source_call_id
source_call_product: db "export base = 6; export call_product = base() * 7;"
SOURCE_CALL_PRODUCT_LEN equ $ - source_call_product
source_call_eq: db "export base = 42; export call_eq = base() == 42;"
SOURCE_CALL_EQ_LEN equ $ - source_call_eq
source_call_rhs_sub: db "export base = 8; export call_rhs_sub = 50 - base();"
SOURCE_CALL_RHS_SUB_LEN equ $ - source_call_rhs_sub
source_call_rhs_eq: db "export base = 42; export call_rhs_eq = 42 == base();"
SOURCE_CALL_RHS_EQ_LEN equ $ - source_call_rhs_eq
source_call_callee_expr: db "export base = 6 * 7; export call_callee_expr = base();"
SOURCE_CALL_CALLEE_EXPR_LEN equ $ - source_call_callee_expr
source_call_callee_rhs: db "export base = 50 - 8; export call_callee_rhs = 84 / base();"
SOURCE_CALL_CALLEE_RHS_LEN equ $ - source_call_callee_rhs
source_call_callee_chain: db "export base = 10 + 20 + 12; export call_callee_chain = base();"
SOURCE_CALL_CALLEE_CHAIN_LEN equ $ - source_call_callee_chain
source_call_callee_paren: db "export base = (6 + 1) * 6; export call_callee_paren = base();"
SOURCE_CALL_CALLEE_PAREN_LEN equ $ - source_call_callee_paren
source_call_callee_precedence: db "export base = 2 + 4 * 10; export call_callee_precedence = base();"
SOURCE_CALL_CALLEE_PRECEDENCE_LEN equ $ - source_call_callee_precedence
source_call_chain: db "export base = 5; export call_chain = base() + 10 + 27;"
SOURCE_CALL_CHAIN_LEN equ $ - source_call_chain
source_call_paren: db "export base = 6; export call_paren = (base() + 1) * 6;"
SOURCE_CALL_PAREN_LEN equ $ - source_call_paren
source_call_precedence: db "export base = 4; export call_precedence = 2 + base() * 10;"
SOURCE_CALL_PRECEDENCE_LEN equ $ - source_call_precedence
source_call_twice_add: db "export base = 21; export call_twice_add = base() + base();"
SOURCE_CALL_TWICE_ADD_LEN equ $ - source_call_twice_add
source_call_twice_mul: db "export base = 6; export call_twice_mul = base() * base() + 6;"
SOURCE_CALL_TWICE_MUL_LEN equ $ - source_call_twice_mul
source_call_named_callee: db "export seed = 14; export call_named_callee = seed() * 3;"
SOURCE_CALL_NAMED_CALLEE_LEN equ $ - source_call_named_callee
source_call_spaced: db "export base = 40; export call_spaced = base ( ) + 2;"
SOURCE_CALL_SPACED_LEN equ $ - source_call_spaced
source_call_two_callees: db "export left = 20; export right = 22; export call_pair = left() + right();"
SOURCE_CALL_TWO_CALLEES_LEN equ $ - source_call_two_callees
source_call_four_exports: db "export a = 5; export b = 7; export c = a() + b(); export d = a() + b() + c() + 18;"
SOURCE_CALL_FOUR_EXPORTS_LEN equ $ - source_call_four_exports
source_call_param_source: db "export add2(a, b) = a + b; export call_param_source = add2(19, 23);"
SOURCE_CALL_PARAM_SOURCE_LEN equ $ - source_call_param_source
source_call_param_forward_local: db "export add23(x) = x + 23; export call_param_forward = add23(19);"
SOURCE_CALL_PARAM_FORWARD_LOCAL_LEN equ $ - source_call_param_forward_local
source_call_param_final_arg: db "export add23(x) = x + 23; export call_param_final(y) = add23(y);"
SOURCE_CALL_PARAM_FINAL_ARG_LEN equ $ - source_call_param_final_arg
source_call_param_expr_arg: db "export add2(a, b) = a + b; export call_param_expr = add2(10 + 9, 20 + 3);"
SOURCE_CALL_PARAM_EXPR_ARG_LEN equ $ - source_call_param_expr_arg
source_call_param_group_arg: db "export add2(a, b) = a + b; export call_param_group = add2((50 - 31), (5 * 4) + 3);"
SOURCE_CALL_PARAM_GROUP_ARG_LEN equ $ - source_call_param_group_arg
source_call_param_nested_arg: db "export add2(a, b) = a + b; export nineteen = 19; export call_param_nested = add2(nineteen(), add2(20, 3));"
SOURCE_CALL_PARAM_NESTED_ARG_LEN equ $ - source_call_param_nested_arg
source_call_local_callee: db "export add_local(a) = let b = a + 20; b + 3; export call_local_callee = add_local(19);"
SOURCE_CALL_LOCAL_CALLEE_LEN equ $ - source_call_local_callee
source_call_local_final: db "export add2(a, b) = a + b; export call_local_final = let x = 19; let y = 23; add2(x, y);"
SOURCE_CALL_LOCAL_FINAL_LEN equ $ - source_call_local_final
param_final_name: db "call_param_final"
PARAM_FINAL_NAME_LEN equ $ - param_final_name
source_call_div_zero: db "export base = 42; export call_div_zero = base() / 0;"
SOURCE_CALL_DIV_ZERO_LEN equ $ - source_call_div_zero
source_call_rhs_div_zero: db "export base = 0; export call_rhs_div_zero = 84 / base();"
SOURCE_CALL_RHS_DIV_ZERO_LEN equ $ - source_call_rhs_div_zero
source_call_rhs_rem_zero: db "export base = 0; export call_rhs_rem_zero = 84 % base();"
SOURCE_CALL_RHS_REM_ZERO_LEN equ $ - source_call_rhs_rem_zero
source_call_callee_div_zero: db "export base = 42 / 0; export call_callee_div_zero = base();"
SOURCE_CALL_CALLEE_DIV_ZERO_LEN equ $ - source_call_callee_div_zero
source_call_callee_rem_zero: db "export base = 42 % 0; export call_callee_rem_zero = base();"
SOURCE_CALL_CALLEE_REM_ZERO_LEN equ $ - source_call_callee_rem_zero
source_call_callee_div_over: db "export base = -2147483648 / -1; export call_callee_div_over = base();"
SOURCE_CALL_CALLEE_DIV_OVER_LEN equ $ - source_call_callee_div_over
source_call_unknown: db "export base = 40; export bad_call = missing() + 2;"
SOURCE_CALL_UNKNOWN_LEN equ $ - source_call_unknown
source_call_unknown_after_call: db "export base = 40; export bad_call_after = base() + missing();"
SOURCE_CALL_UNKNOWN_AFTER_CALL_LEN equ $ - source_call_unknown_after_call
source_call_prefix_unknown: db "export seed = 40; export bad_prefix = seed_extra() + 2;"
SOURCE_CALL_PREFIX_UNKNOWN_LEN equ $ - source_call_prefix_unknown
source_call_dup_export: db "export base = 40; export base = base() + 2;"
SOURCE_CALL_DUP_EXPORT_LEN equ $ - source_call_dup_export
source_call_bad_arity: db "export base = 40; export bad_arity = base(1);"
SOURCE_CALL_BAD_ARITY_LEN equ $ - source_call_bad_arity
source_call_rhs_bad_arity: db "export base = 40; export bad_arity_rhs = 1 + base(1);"
SOURCE_CALL_RHS_BAD_ARITY_LEN equ $ - source_call_rhs_bad_arity
source_call_group_bad_arity: db "export base = 40; export bad_arity_group = (base(1));"
SOURCE_CALL_GROUP_BAD_ARITY_LEN equ $ - source_call_group_bad_arity
source_call_spaced_bad_arity: db "export base = 40; export bad_arity_spaced = base ( 1 );"
SOURCE_CALL_SPACED_BAD_ARITY_LEN equ $ - source_call_spaced_bad_arity
source_call_two_callees_bad_arity: db "export left = 20; export right = 22; export bad_pair = left() + right(1);"
SOURCE_CALL_TWO_CALLEES_BAD_ARITY_LEN equ $ - source_call_two_callees_bad_arity
source_call_three_dup_first: db "export left = 20; export right = 22; export left = right();"
SOURCE_CALL_THREE_DUP_FIRST_LEN equ $ - source_call_three_dup_first
source_call_three_dup_second: db "export left = 20; export right = 22; export right = left();"
SOURCE_CALL_THREE_DUP_SECOND_LEN equ $ - source_call_three_dup_second
source_call_four_dup_middle: db "export a = 5; export b = 7; export c = a() + b(); export b = c();"
SOURCE_CALL_FOUR_DUP_MIDDLE_LEN equ $ - source_call_four_dup_middle
source_call_too_many: db "export a = 1; export b = 2; export c = 3; export d = 4; export e = a();"
SOURCE_CALL_TOO_MANY_LEN equ $ - source_call_too_many
source_call_param_too_few: db "export add2(a, b) = a + b; export bad_param_few = add2(19);"
SOURCE_CALL_PARAM_TOO_FEW_LEN equ $ - source_call_param_too_few
source_call_param_too_many: db "export add2(a, b) = a + b; export bad_param_many = add2(19, 20, 3);"
SOURCE_CALL_PARAM_TOO_MANY_LEN equ $ - source_call_param_too_many
source_call_local_dup_param: db "export bad_local_dup_param(a) = let a = 1; a; export call_bad_local_dup = bad_local_dup_param(1);"
SOURCE_CALL_LOCAL_DUP_PARAM_LEN equ $ - source_call_local_dup_param
source_call_local_dup_local: db "export bad_local_dup_local = let a = 1; let a = 2; a; export call_bad_local_dup = bad_local_dup_local();"
SOURCE_CALL_LOCAL_DUP_LOCAL_LEN equ $ - source_call_local_dup_local
source_return42: db "export f = 42;"
SOURCE_RETURN42_LEN equ $ - source_return42
source_param_add: db "export add2(a, b) = a + b;"
SOURCE_PARAM_ADD_LEN equ $ - source_param_add
source_param_local: db "export add_local(a, b) = let c = a + b; c + 1;"
SOURCE_PARAM_LOCAL_LEN equ $ - source_param_local
param_add_name: db "add2"
PARAM_ADD_NAME_LEN equ $ - param_add_name
param_local_name: db "add_local"
PARAM_LOCAL_NAME_LEN equ $ - param_local_name
source_param_dup: db "export dup_param(a, a) = a;"
SOURCE_PARAM_DUP_LEN equ $ - source_param_dup
source_param_trailing_comma: db "export bad_param(a,) = a;"
SOURCE_PARAM_TRAILING_COMMA_LEN equ $ - source_param_trailing_comma
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
tsx_single: db "<App />"
TSX_SINGLE_LEN equ $ - tsx_single
tsx_nested: db "<App><Title text=",34,"hi",34,"/><Body count={40 + 2}>ok</Body></App>"
TSX_NESTED_LEN equ $ - tsx_nested
tsx_boolean_attr: db "<Input disabled value='x' />"
TSX_BOOLEAN_ATTR_LEN equ $ - tsx_boolean_attr
tsx_quoted_lt_attr: db "<Input pattern=",34,"<tag attr='x'> &amp; &#65;",34," />"
TSX_QUOTED_LT_ATTR_LEN equ $ - tsx_quoted_lt_attr
tsx_svg_names: db "<svg:path stroke-width='2' xlink:href={url} />"
TSX_SVG_NAMES_LEN equ $ - tsx_svg_names
tsx_utf8_names: db "<Caf",0xc3,0xa9," data-",0xce,0xbb,"='x' />"
TSX_UTF8_NAMES_LEN equ $ - tsx_utf8_names
tsx_deep: db "<A><B><C><D /></C></B></A>"
TSX_DEEP_LEN equ $ - tsx_deep
tsx_fragment: db "<><App /><span data-x='1'>text</span></>"
TSX_FRAGMENT_LEN equ $ - tsx_fragment
tsx_member_expr: db "<UI.Card data-id={",34,"a<b",34,"}>{items.map(x => <Row key={x.id} />)}</UI.Card>"
TSX_MEMBER_EXPR_LEN equ $ - tsx_member_expr
tsx_conditional_expr: db "<App>{ready ? <Ready /> : <Fallback />}</App>"
TSX_CONDITIONAL_EXPR_LEN equ $ - tsx_conditional_expr
tsx_template_expr_child: db "<App>{`${<Icon name='x' />}`}</App>"
TSX_TEMPLATE_EXPR_CHILD_LEN equ $ - tsx_template_expr_child
tsx_spread_attr: db "<Panel {...props} a={/* comment */ `x{y}`} />"
TSX_SPREAD_ATTR_LEN equ $ - tsx_spread_attr
tsx_spread_attr_jsx: db "<Panel {...{ icon: <Icon name='x' /> }} />"
TSX_SPREAD_ATTR_JSX_LEN equ $ - tsx_spread_attr_jsx
tsx_attr_expr_jsx: db "<Button icon={<Icon name='x' />} />"
TSX_ATTR_EXPR_JSX_LEN equ $ - tsx_attr_expr_jsx
tsx_attr_comments: db "<Button /* primary */ disabled // tail",10,"/>"
TSX_ATTR_COMMENTS_LEN equ $ - tsx_attr_comments
tsx_expr_comment_child: db "<App>{/* hidden <Tag /> */}{items // comment",10,"}</App>"
TSX_EXPR_COMMENT_CHILD_LEN equ $ - tsx_expr_comment_child
tsx_text_before_expr: db "<App>hi{value}there{again}</App>"
TSX_TEXT_BEFORE_EXPR_LEN equ $ - tsx_text_before_expr
tsx_entity_text: db "<Text>&nbsp;ready &#65; &#x41; &amp; set</Text>"
TSX_ENTITY_TEXT_LEN equ $ - tsx_entity_text
tsx_wrapped: db "  ((<App />));  "
TSX_WRAPPED_LEN equ $ - tsx_wrapped
tsx_as_assertion: db "(<App /> as JSX.Element)"
TSX_AS_ASSERTION_LEN equ $ - tsx_as_assertion
tsx_satisfies_assertion: db "<App /> satisfies { node: JSX.Element };"
TSX_SATISFIES_ASSERTION_LEN equ $ - tsx_satisfies_assertion
tsx_non_null_assertion: db "(<App />)! as JSX.Element;"
TSX_NON_NULL_ASSERTION_LEN equ $ - tsx_non_null_assertion
tsx_non_null_only: db "<App />!"
TSX_NON_NULL_ONLY_LEN equ $ - tsx_non_null_only
tsx_leading_not: db "!(<App />)"
TSX_LEADING_NOT_LEN equ $ - tsx_leading_not
tsx_raw_text: db "<script>if (a < b && raw &bad) { draw(); }</script>"
TSX_RAW_TEXT_LEN equ $ - tsx_raw_text
tsx_style_raw_text: db "<style>.a > .b { content: '&bad'; }</style>"
TSX_STYLE_RAW_TEXT_LEN equ $ - tsx_style_raw_text
tsx_regex_attr: db "<App matcher={/}/} />"
TSX_REGEX_ATTR_LEN equ $ - tsx_regex_attr
tsx_regex_child: db "<App>{/}/.test(x) && <B />}</App>"
TSX_REGEX_CHILD_LEN equ $ - tsx_regex_child
tsx_generic_tag: db "<List<Item> items={items} />"
TSX_GENERIC_TAG_LEN equ $ - tsx_generic_tag
tsx_generic_pair_tag: db "<List<Item>><Row /></List>"
TSX_GENERIC_PAIR_TAG_LEN equ $ - tsx_generic_pair_tag
tsx_nested_generic_tag: db "<Box<Map<Key, Value>> />"
TSX_NESTED_GENERIC_TAG_LEN equ $ - tsx_nested_generic_tag
tsx_generic_comment_tag: db "<Box</* > */Item> />"
TSX_GENERIC_COMMENT_TAG_LEN equ $ - tsx_generic_comment_tag
tsx_generic_object_tag: db "<Box<Record<string, { value: Item }>> />"
TSX_GENERIC_OBJECT_TAG_LEN equ $ - tsx_generic_object_tag
tsx_source_file:
    db "import x from 'y';",10
    db "const fake = ",34,"<Nope />",34,";",10
    db "if (a < B) { value = 1; }",10
    db "const id = <T,>(value: T) => value;",10
    db "const cast = <Thing>value;",10
    db "const rx = /(<Fake \/>|<StillNope>)/g;",10
    db "const templateFake = `<Nope />`;",10
    db "const templateExpr = `${<Inline />}`;",10
    db "const templateNested = `${`inner ${<NestedInline />}`}`;",10
    db "const view = <App foo=",34,"x",34," />;",10
    db "const object = { view: <ObjectView /> };",10
    db "const list = [<Item />, <Item />];",10
    db "render(<Arg />, <Second />);",10
    db "const grouped = (<One />, <Two />);",10
    db "const arrow = () => <Arrow />;",10
    db "const ternary = ready ? <Ready /> : <Fallback />;",10
    db "function render() { return (<Panel><Child /></Panel>); }",10
    db "function* g() { yield <Yielded />; }",10
    db "void <VoidView />;",10
    db "switch (kind) { case <CaseView />: break; }",10
    db "const kind = typeof <Typed />;",10
    db "async function h() { await <Awaited />; }",10
    db "export default <DefaultView />;",10
    db "function fail() { throw <Thrown />; }",10
    db "do <LoopBody />; while (again);",10
    db "for (const item of <Items />) { item; }",10
    db "if (name in <Registry />) { name; }",10
    db "delete <Disposable />.field;",10
    db "const ok = value instanceof <Ctor />;",10
    db "using resource = <Resource />;",10
    db "const instance = new <Constructed />;",10
    db "if (ready) /(<StillNo \/>)/.test(text);",10
    db "if (ready) <Ready />; else <Fallback />;",10
    db "<Statement />;",10
    db "// trailing comment"
TSX_SOURCE_FILE_LEN equ $ - tsx_source_file
tsx_bad_source_comment: db "const view = <App />; /* open"
TSX_BAD_SOURCE_COMMENT_LEN equ $ - tsx_bad_source_comment
tsx_mismatch: db "<App><Body /></Panel>"
TSX_MISMATCH_LEN equ $ - tsx_mismatch
tsx_unclosed: db "<App><Body /></App"
TSX_UNCLOSED_LEN equ $ - tsx_unclosed
tsx_bad_attr: db "<App value={40 + 2 />"
TSX_BAD_ATTR_LEN equ $ - tsx_bad_attr
tsx_bad_entity: db "<Text>&bad</Text>"
TSX_BAD_ENTITY_LEN equ $ - tsx_bad_entity
tsx_bad_attr_entity: db "<Input label='&bad' />"
TSX_BAD_ATTR_ENTITY_LEN equ $ - tsx_bad_attr_entity
tsx_bad_numeric_entity: db "<Text>&#x;</Text>"
TSX_BAD_NUMERIC_ENTITY_LEN equ $ - tsx_bad_numeric_entity
tsx_two_roots: db "<A /><B />"
TSX_TWO_ROOTS_LEN equ $ - tsx_two_roots
tsx_top_text: db "text<App />"
TSX_TOP_TEXT_LEN equ $ - tsx_top_text
tsx_too_deep: db "<A><B><C><D><E><F><G><H><I><J><K><L><M><N><O><P><Q></Q></P></O></N></M></L></K></J></I></H></G></F></E></D></C></B></A>"
TSX_TOO_DEEP_LEN equ $ - tsx_too_deep
wasm_compile_tsx_valid_cases:
    dq tsx_single, TSX_SINGLE_LEN, 1, 0, 0
    dq tsx_nested, TSX_NESTED_LEN, 3, 2, 1
    dq tsx_boolean_attr, TSX_BOOLEAN_ATTR_LEN, 1, 2, 0
    dq tsx_quoted_lt_attr, TSX_QUOTED_LT_ATTR_LEN, 1, 1, 0
    dq tsx_svg_names, TSX_SVG_NAMES_LEN, 1, 2, 0
    dq tsx_utf8_names, TSX_UTF8_NAMES_LEN, 1, 1, 0
    dq tsx_deep, TSX_DEEP_LEN, 4, 0, 0
    dq tsx_fragment, TSX_FRAGMENT_LEN, 3, 1, 1
    dq tsx_member_expr, TSX_MEMBER_EXPR_LEN, 2, 2, 0
    dq tsx_conditional_expr, TSX_CONDITIONAL_EXPR_LEN, 3, 0, 0
    dq tsx_template_expr_child, TSX_TEMPLATE_EXPR_CHILD_LEN, 2, 1, 0
    dq tsx_spread_attr, TSX_SPREAD_ATTR_LEN, 1, 2, 0
    dq tsx_spread_attr_jsx, TSX_SPREAD_ATTR_JSX_LEN, 2, 2, 0
    dq tsx_attr_expr_jsx, TSX_ATTR_EXPR_JSX_LEN, 2, 2, 0
    dq tsx_attr_comments, TSX_ATTR_COMMENTS_LEN, 1, 1, 0
    dq tsx_expr_comment_child, TSX_EXPR_COMMENT_CHILD_LEN, 1, 0, 0
    dq tsx_text_before_expr, TSX_TEXT_BEFORE_EXPR_LEN, 1, 0, 2
    dq tsx_entity_text, TSX_ENTITY_TEXT_LEN, 1, 0, 1
    dq tsx_wrapped, TSX_WRAPPED_LEN, 1, 0, 0
    dq tsx_as_assertion, TSX_AS_ASSERTION_LEN, 1, 0, 0
    dq tsx_satisfies_assertion, TSX_SATISFIES_ASSERTION_LEN, 1, 0, 0
    dq tsx_non_null_assertion, TSX_NON_NULL_ASSERTION_LEN, 1, 0, 0
    dq tsx_non_null_only, TSX_NON_NULL_ONLY_LEN, 1, 0, 0
    dq tsx_leading_not, TSX_LEADING_NOT_LEN, 1, 0, 0
    dq tsx_raw_text, TSX_RAW_TEXT_LEN, 1, 0, 1
    dq tsx_style_raw_text, TSX_STYLE_RAW_TEXT_LEN, 1, 0, 1
    dq tsx_regex_attr, TSX_REGEX_ATTR_LEN, 1, 1, 0
    dq tsx_regex_child, TSX_REGEX_CHILD_LEN, 2, 0, 0
    dq tsx_generic_tag, TSX_GENERIC_TAG_LEN, 1, 1, 0
    dq tsx_generic_pair_tag, TSX_GENERIC_PAIR_TAG_LEN, 2, 0, 0
    dq tsx_nested_generic_tag, TSX_NESTED_GENERIC_TAG_LEN, 1, 0, 0
    dq tsx_generic_comment_tag, TSX_GENERIC_COMMENT_TAG_LEN, 1, 0, 0
    dq tsx_generic_object_tag, TSX_GENERIC_OBJECT_TAG_LEN, 1, 0, 0
WASM_COMPILE_TSX_VALID_CASE_SIZE equ 40
wasm_compile_tsx_valid_cases_end:
WASM_COMPILE_TSX_VALID_CASES equ (wasm_compile_tsx_valid_cases_end - wasm_compile_tsx_valid_cases) / WASM_COMPILE_TSX_VALID_CASE_SIZE
wasm_compile_tsx_error_cases:
    dq tsx_mismatch, TSX_MISMATCH_LEN, ERROR_PARSE
    dq tsx_unclosed, TSX_UNCLOSED_LEN, ERROR_PARSE
    dq tsx_bad_attr, TSX_BAD_ATTR_LEN, ERROR_PARSE
    dq tsx_bad_entity, TSX_BAD_ENTITY_LEN, ERROR_PARSE
    dq tsx_bad_attr_entity, TSX_BAD_ATTR_ENTITY_LEN, ERROR_PARSE
    dq tsx_bad_numeric_entity, TSX_BAD_NUMERIC_ENTITY_LEN, ERROR_PARSE
    dq tsx_two_roots, TSX_TWO_ROOTS_LEN, ERROR_PARSE
    dq tsx_top_text, TSX_TOP_TEXT_LEN, ERROR_PARSE
    dq tsx_too_deep, TSX_TOO_DEEP_LEN, ERROR_NO_SPACE
WASM_COMPILE_TSX_ERROR_CASE_SIZE equ 24
wasm_compile_tsx_error_cases_end:
WASM_COMPILE_TSX_ERROR_CASES equ (wasm_compile_tsx_error_cases_end - wasm_compile_tsx_error_cases) / WASM_COMPILE_TSX_ERROR_CASE_SIZE
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
    dq source_call_pair, SOURCE_CALL_PAIR_LEN, 42
    dq source_call_id, SOURCE_CALL_ID_LEN, 42
    dq source_call_product, SOURCE_CALL_PRODUCT_LEN, 42
    dq source_call_eq, SOURCE_CALL_EQ_LEN, 1
    dq source_call_rhs_sub, SOURCE_CALL_RHS_SUB_LEN, 42
    dq source_call_rhs_eq, SOURCE_CALL_RHS_EQ_LEN, 1
    dq source_call_callee_expr, SOURCE_CALL_CALLEE_EXPR_LEN, 42
    dq source_call_callee_rhs, SOURCE_CALL_CALLEE_RHS_LEN, 2
    dq source_call_callee_chain, SOURCE_CALL_CALLEE_CHAIN_LEN, 42
    dq source_call_callee_paren, SOURCE_CALL_CALLEE_PAREN_LEN, 42
    dq source_call_callee_precedence, SOURCE_CALL_CALLEE_PRECEDENCE_LEN, 42
    dq source_call_chain, SOURCE_CALL_CHAIN_LEN, 42
    dq source_call_paren, SOURCE_CALL_PAREN_LEN, 42
    dq source_call_precedence, SOURCE_CALL_PRECEDENCE_LEN, 42
    dq source_call_twice_add, SOURCE_CALL_TWICE_ADD_LEN, 42
    dq source_call_twice_mul, SOURCE_CALL_TWICE_MUL_LEN, 42
    dq source_call_named_callee, SOURCE_CALL_NAMED_CALLEE_LEN, 42
    dq source_call_spaced, SOURCE_CALL_SPACED_LEN, 42
    dq source_call_two_callees, SOURCE_CALL_TWO_CALLEES_LEN, 42
    dq source_call_four_exports, SOURCE_CALL_FOUR_EXPORTS_LEN, 42
    dq source_call_param_source, SOURCE_CALL_PARAM_SOURCE_LEN, 42
    dq source_call_param_forward_local, SOURCE_CALL_PARAM_FORWARD_LOCAL_LEN, 42
    dq source_call_param_expr_arg, SOURCE_CALL_PARAM_EXPR_ARG_LEN, 42
    dq source_call_param_group_arg, SOURCE_CALL_PARAM_GROUP_ARG_LEN, 42
    dq source_call_param_nested_arg, SOURCE_CALL_PARAM_NESTED_ARG_LEN, 42
    dq source_call_local_callee, SOURCE_CALL_LOCAL_CALLEE_LEN, 42
    dq source_call_local_final, SOURCE_CALL_LOCAL_FINAL_LEN, 42
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
    dq source_call_dup_export, SOURCE_CALL_DUP_EXPORT_LEN
    dq source_call_bad_arity, SOURCE_CALL_BAD_ARITY_LEN
    dq source_call_rhs_bad_arity, SOURCE_CALL_RHS_BAD_ARITY_LEN
    dq source_call_group_bad_arity, SOURCE_CALL_GROUP_BAD_ARITY_LEN
    dq source_call_spaced_bad_arity, SOURCE_CALL_SPACED_BAD_ARITY_LEN
    dq source_call_two_callees_bad_arity, SOURCE_CALL_TWO_CALLEES_BAD_ARITY_LEN
    dq source_call_three_dup_first, SOURCE_CALL_THREE_DUP_FIRST_LEN
    dq source_call_three_dup_second, SOURCE_CALL_THREE_DUP_SECOND_LEN
    dq source_call_four_dup_middle, SOURCE_CALL_FOUR_DUP_MIDDLE_LEN
    dq source_param_dup, SOURCE_PARAM_DUP_LEN
    dq source_param_trailing_comma, SOURCE_PARAM_TRAILING_COMMA_LEN
    dq source_call_param_too_few, SOURCE_CALL_PARAM_TOO_FEW_LEN
    dq source_call_param_too_many, SOURCE_CALL_PARAM_TOO_MANY_LEN
    dq source_call_local_dup_param, SOURCE_CALL_LOCAL_DUP_PARAM_LEN
    dq source_call_local_dup_local, SOURCE_CALL_LOCAL_DUP_LOCAL_LEN
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
    dq source_call_unknown, SOURCE_CALL_UNKNOWN_LEN, ERROR_PARSE
    dq source_call_unknown_after_call, SOURCE_CALL_UNKNOWN_AFTER_CALL_LEN, ERROR_PARSE
    dq source_call_prefix_unknown, SOURCE_CALL_PREFIX_UNKNOWN_LEN, ERROR_PARSE
    dq source_call_dup_export, SOURCE_CALL_DUP_EXPORT_LEN, ERROR_PARSE
    dq source_call_bad_arity, SOURCE_CALL_BAD_ARITY_LEN, ERROR_PARSE
    dq source_call_rhs_bad_arity, SOURCE_CALL_RHS_BAD_ARITY_LEN, ERROR_PARSE
    dq source_call_group_bad_arity, SOURCE_CALL_GROUP_BAD_ARITY_LEN, ERROR_PARSE
    dq source_call_spaced_bad_arity, SOURCE_CALL_SPACED_BAD_ARITY_LEN, ERROR_PARSE
    dq source_call_two_callees_bad_arity, SOURCE_CALL_TWO_CALLEES_BAD_ARITY_LEN, ERROR_PARSE
    dq source_call_three_dup_first, SOURCE_CALL_THREE_DUP_FIRST_LEN, ERROR_PARSE
    dq source_call_three_dup_second, SOURCE_CALL_THREE_DUP_SECOND_LEN, ERROR_PARSE
    dq source_call_four_dup_middle, SOURCE_CALL_FOUR_DUP_MIDDLE_LEN, ERROR_PARSE
    dq source_call_too_many, SOURCE_CALL_TOO_MANY_LEN, ERROR_NO_SPACE
    dq source_param_dup, SOURCE_PARAM_DUP_LEN, ERROR_PARSE
    dq source_param_trailing_comma, SOURCE_PARAM_TRAILING_COMMA_LEN, ERROR_PARSE
    dq source_call_param_too_few, SOURCE_CALL_PARAM_TOO_FEW_LEN, ERROR_PARSE
    dq source_call_param_too_many, SOURCE_CALL_PARAM_TOO_MANY_LEN, ERROR_PARSE
    dq source_call_local_dup_param, SOURCE_CALL_LOCAL_DUP_PARAM_LEN, ERROR_PARSE
    dq source_call_local_dup_local, SOURCE_CALL_LOCAL_DUP_LOCAL_LEN, ERROR_PARSE
    dq source_call_div_zero, SOURCE_CALL_DIV_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_call_rhs_div_zero, SOURCE_CALL_RHS_DIV_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_call_rhs_rem_zero, SOURCE_CALL_RHS_REM_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_call_callee_div_zero, SOURCE_CALL_CALLEE_DIV_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_call_callee_rem_zero, SOURCE_CALL_CALLEE_REM_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_call_callee_div_over, SOURCE_CALL_CALLEE_DIV_OVER_LEN, ERROR_ARITHMETIC_TRAP
    dq source_div_zero, SOURCE_DIV_ZERO_LEN, ERROR_ARITHMETIC_TRAP
    dq source_rem_zero, SOURCE_REM_ZERO_LEN, ERROR_ARITHMETIC_TRAP
WASM_COMPILE_RUN_ERROR_CASE_SIZE equ 24
wasm_compile_run_error_cases_end:
WASM_COMPILE_RUN_ERROR_CASES equ (wasm_compile_run_error_cases_end - wasm_compile_run_error_cases) / WASM_COMPILE_RUN_ERROR_CASE_SIZE

SECTION .bss
runtime: resb RUNTIME_SIZE
compiled_wasm: resb 128
compiled_wasm_b: resb 128
call_args: resq 2
tsx_nodes: resb 120

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
    mov     esi, WASM_PAGE_SIZE
    xor     edx, edx
    call    er_fn_init
    lea     rax, [rel dummy_mem]
    mov     qword [rel runtime + RUNTIME_MEMORY_PTR_OFF], rax
    mov     qword [rel runtime + RUNTIME_MEMORY_LEN_OFF], WASM_PAGE_SIZE
    mov     qword [rel runtime + RUNTIME_TICKS_PTR_OFF], 0

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

    mov     qword [rel call_args], 19
    mov     qword [rel call_args + 8], 23
    mov     eax, 2
    push    rax
    lea     rdi, [rel runtime]
    lea     rsi, [rel wasm_add_i32]
    mov     edx, wasm_add_i32_len
    lea     rcx, [rel add_export_name]
    mov     r8d, ADD_EXPORT_NAME_LEN
    lea     r9, [rel call_args]
    call    er_fn_run_args
    add     rsp, 8
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel wasm_add_i32]
    mov     rdx, wasm_add_i32_len
    call    er_fn_load
    test    rdx, rdx
    jnz     .fail
    mov     qword [rel call_args], 40
    mov     qword [rel call_args + 8], 2
    lea     rdi, [rel runtime]
    lea     rsi, [rel add_export_name]
    mov     edx, ADD_EXPORT_NAME_LEN
    lea     rcx, [rel call_args]
    mov     r8d, 2
    call    er_fn_call_args
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 42
    jne     .fail

    mov     rax, 0x7777777777777777
    mov     qword [rel table_entries], rax
    mov     qword [rel table_entries + 8], rax
    lea     rdi, [rel wasm_elem_active]
    mov     esi, wasm_elem_active_len
    call    er_wasm_parse_module
    test    rdx, rdx
    jnz     .fail
    cmp     qword [rel table_min], 2
    jne     .fail
    cmp     qword [rel table_entries], 0
    jne     .fail
    cmp     qword [rel table_entries + 8], 1
    jne     .fail

    lea     rdi, [rel wasm_elem_expr_unsupported]
    mov     esi, wasm_elem_expr_unsupported_len
    call    er_wasm_parse_module
    cmp     rdx, ERROR_UNSUPPORTED
    jne     .fail

    lea     rdi, [rel wasm_bad_memory_index]
    mov     esi, wasm_bad_memory_index_len
    call    er_wasm_parse_module
    cmp     rdx, ERROR_UNSUPPORTED
    jne     .fail

    lea     rdi, [rel wasm_bad_table_index]
    mov     esi, wasm_bad_table_index_len
    call    er_wasm_parse_module
    cmp     rdx, ERROR_UNSUPPORTED
    jne     .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel wasm_table_bulk]
    mov     rdx, wasm_table_bulk_len
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 1
    jne     .fail

    mov     byte [rel dummy_mem], 0
    lea     rdi, [rel runtime]
    lea     rsi, [rel wasm_memory_init_passive]
    mov     rdx, wasm_memory_init_passive_len
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 0x41
    jne     .fail
    mov     byte [rel dummy_mem], 0

    lea     rdi, [rel runtime]
    lea     rsi, [rel wasm_if_skip_memory_immediates]
    mov     rdx, wasm_if_skip_memory_immediates_len
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_param_add]
    mov     ecx, SOURCE_PARAM_ADD_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    mov     qword [rel call_args], 19
    mov     qword [rel call_args + 8], 23
    mov     eax, 2
    push    rax
    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel param_add_name]
    mov     r8d, PARAM_ADD_NAME_LEN
    lea     r9, [rel call_args]
    call    er_fn_run_args
    add     rsp, 8
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_param_local]
    mov     ecx, SOURCE_PARAM_LOCAL_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    mov     qword [rel call_args], 19
    mov     qword [rel call_args + 8], 22
    mov     eax, 2
    push    rax
    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel param_local_name]
    mov     r8d, PARAM_LOCAL_NAME_LEN
    lea     r9, [rel call_args]
    call    er_fn_run_args
    add     rsp, 8
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_call_param_final_arg]
    mov     ecx, SOURCE_CALL_PARAM_FINAL_ARG_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    mov     qword [rel call_args], 19
    mov     eax, 1
    push    rax
    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel param_final_name]
    mov     r8d, PARAM_FINAL_NAME_LEN
    lea     r9, [rel call_args]
    call    er_fn_run_args
    add     rsp, 8
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

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel body_i32_40]
    mov     ecx, BODY_I32_40_LEN
    lea     r8, [rel body_call0_add2]
    mov     r9d, BODY_CALL0_ADD2_LEN
    lea     r10, [rel call_export_name]
    mov     r11d, CALL_EXPORT_NAME_LEN
    call    er_wasmc_emit_i32_two_body_export
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel body_i32_40]
    mov     ecx, BODY_I32_40_LEN
    lea     r8, [rel body_call0_add2]
    mov     r9d, BODY_CALL0_ADD2_LEN
    lea     r10, [rel call_export_name]
    mov     r11d, CALL_EXPORT_NAME_LEN
    call    er_wasmc_emit_i32_two_body_export
    test    rdx, rdx
    jnz     .fail
    cmp     rax, r12
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel call_export_name]
    mov     r8d, CALL_EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel body_table_call_pair]
    mov     ecx, 3
    lea     r8, [rel call_pair_export_name]
    mov     r9d, CALL_PAIR_EXPORT_NAME_LEN
    mov     r10d, 2
    call    er_wasmc_emit_i32_body_table_export
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel body_table_call_pair]
    mov     ecx, 3
    lea     r8, [rel call_pair_export_name]
    mov     r9d, CALL_PAIR_EXPORT_NAME_LEN
    mov     r10d, 2
    call    er_wasmc_emit_i32_body_table_export
    test    rdx, rdx
    jnz     .fail
    cmp     rax, r12
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel call_pair_export_name]
    mov     r8d, CALL_PAIR_EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel body_table_call_param]
    mov     ecx, 2
    lea     r8, [rel call_param_export_name]
    mov     r9d, CALL_PARAM_EXPORT_NAME_LEN
    mov     r10d, 1
    lea     r11, [rel sig_table_call_param]
    call    er_wasmc_emit_i32_sig_body_table_export
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel body_table_call_param]
    mov     ecx, 2
    lea     r8, [rel call_param_export_name]
    mov     r9d, CALL_PARAM_EXPORT_NAME_LEN
    mov     r10d, 1
    lea     r11, [rel sig_table_call_param]
    call    er_wasmc_emit_i32_sig_body_table_export
    test    rdx, rdx
    jnz     .fail
    cmp     rax, r12
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel call_param_export_name]
    mov     r8d, CALL_PARAM_EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_call_pair]
    mov     ecx, SOURCE_CALL_PAIR_LEN
    call    er_wasmc_compile_call_source
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_pair]
    mov     ecx, SOURCE_CALL_PAIR_LEN
    call    er_wasmc_compile_call_source
    test    rdx, rdx
    jnz     .fail
    cmp     rax, r12
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel call_export_name]
    mov     r8d, CALL_EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_unknown]
    mov     ecx, SOURCE_CALL_UNKNOWN_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_unknown_after_call]
    mov     ecx, SOURCE_CALL_UNKNOWN_AFTER_CALL_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_prefix_unknown]
    mov     ecx, SOURCE_CALL_PREFIX_UNKNOWN_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_dup_export]
    mov     ecx, SOURCE_CALL_DUP_EXPORT_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_bad_arity]
    mov     ecx, SOURCE_CALL_BAD_ARITY_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_rhs_bad_arity]
    mov     ecx, SOURCE_CALL_RHS_BAD_ARITY_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_group_bad_arity]
    mov     ecx, SOURCE_CALL_GROUP_BAD_ARITY_LEN
    call    er_wasmc_compile_call_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_call_pair]
    mov     ecx, SOURCE_CALL_PAIR_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail
    mov     r12, rax

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_pair]
    mov     ecx, SOURCE_CALL_PAIR_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail
    cmp     rax, r12
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel call_export_name]
    mov     r8d, CALL_EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_call_unknown]
    mov     ecx, SOURCE_CALL_UNKNOWN_LEN
    call    er_wasmc_compile_source
    cmp     rdx, ERROR_PARSE
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

    lea     rbx, [rel wasm_compile_tsx_valid_cases]
    mov     r12d, WASM_COMPILE_TSX_VALID_CASES
.tsx_valid_loop:
    mov     rdi, [rbx]
    mov     rsi, [rbx + 8]
    call    er_wasmc_parse_tsx
    test    rdx, rdx
    jnz     .fail
    cmp     rax, [rbx + 16]
    jne     .fail
    cmp     rcx, [rbx + 24]
    jne     .fail
    cmp     r8, [rbx + 32]
    jne     .fail
    add     rbx, WASM_COMPILE_TSX_VALID_CASE_SIZE
    dec     r12d
    jnz     .tsx_valid_loop

    lea     rbx, [rel wasm_compile_tsx_error_cases]
    mov     r12d, WASM_COMPILE_TSX_ERROR_CASES
.tsx_error_loop:
    mov     rdi, [rbx]
    mov     rsi, [rbx + 8]
    call    er_wasmc_parse_tsx
    cmp     rdx, [rbx + 16]
    jne     .fail
    add     rbx, WASM_COMPILE_TSX_ERROR_CASE_SIZE
    dec     r12d
    jnz     .tsx_error_loop

    lea     rdi, [rel tsx_nested]
    mov     esi, TSX_NESTED_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 3
    call    er_wasmc_parse_tsx_tree
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 3
    jne     .fail
    cmp     rcx, 2
    jne     .fail
    cmp     r8, 1
    jne     .fail
    lea     rdi, [rel tsx_nested + 1]
    cmp     [rel tsx_nodes], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 8], 3
    jne     .fail
    cmp     qword [rel tsx_nodes + 16], -1
    jne     .fail
    cmp     qword [rel tsx_nodes + 24], 0
    jne     .fail
    cmp     qword [rel tsx_nodes + 32], 0
    jne     .fail
    lea     rdi, [rel tsx_nested + 6]
    cmp     [rel tsx_nodes + 40], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 48], 5
    jne     .fail
    cmp     qword [rel tsx_nodes + 56], 0
    jne     .fail
    cmp     qword [rel tsx_nodes + 64], 1
    jne     .fail
    cmp     qword [rel tsx_nodes + 72], 0
    jne     .fail
    lea     rdi, [rel tsx_nested + 24]
    cmp     [rel tsx_nodes + 80], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 88], 4
    jne     .fail
    cmp     qword [rel tsx_nodes + 96], 0
    jne     .fail
    cmp     qword [rel tsx_nodes + 104], 1
    jne     .fail
    cmp     qword [rel tsx_nodes + 112], 1
    jne     .fail

    lea     rdi, [rel tsx_nested]
    mov     esi, TSX_NESTED_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 2
    call    er_wasmc_parse_tsx_tree
    cmp     rdx, ERROR_NO_SPACE
    jne     .fail

    lea     rdi, [rel tsx_nested]
    mov     esi, TSX_NESTED_LEN
    xor     edx, edx
    mov     ecx, 0
    call    er_wasmc_parse_tsx_tree
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 3
    jne     .fail
    cmp     rcx, 2
    jne     .fail
    cmp     r8, 1
    jne     .fail

    lea     rdi, [rel tsx_conditional_expr]
    mov     esi, TSX_CONDITIONAL_EXPR_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 3
    call    er_wasmc_parse_tsx_tree
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 3
    jne     .fail
    test    rcx, rcx
    jne     .fail
    test    r8, r8
    jne     .fail
    cmp     qword [rel tsx_nodes + 16], -1
    jne     .fail
    lea     rdi, [rel tsx_conditional_expr + 15]
    cmp     [rel tsx_nodes + 40], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 48], 5
    jne     .fail
    cmp     qword [rel tsx_nodes + 56], 0
    jne     .fail
    lea     rdi, [rel tsx_conditional_expr + 27]
    cmp     [rel tsx_nodes + 80], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 88], 8
    jne     .fail
    cmp     qword [rel tsx_nodes + 96], 0
    jne     .fail

    lea     rdi, [rel tsx_template_expr_child]
    mov     esi, TSX_TEMPLATE_EXPR_CHILD_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 2
    call    er_wasmc_parse_tsx_tree
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 2
    jne     .fail
    cmp     rcx, 1
    jne     .fail
    test    r8, r8
    jne     .fail
    cmp     qword [rel tsx_nodes + 16], -1
    jne     .fail
    lea     rdi, [rel tsx_template_expr_child + 10]
    cmp     [rel tsx_nodes + 40], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 48], 4
    jne     .fail
    cmp     qword [rel tsx_nodes + 56], 0
    jne     .fail
    cmp     qword [rel tsx_nodes + 64], 1
    jne     .fail

    lea     rdi, [rel tsx_conditional_expr]
    mov     esi, TSX_CONDITIONAL_EXPR_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 2
    call    er_wasmc_parse_tsx_tree
    cmp     rdx, ERROR_NO_SPACE
    jne     .fail

    lea     rdi, [rel tsx_attr_expr_jsx]
    mov     esi, TSX_ATTR_EXPR_JSX_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 2
    call    er_wasmc_parse_tsx_tree
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 2
    jne     .fail
    cmp     rcx, 2
    jne     .fail
    test    r8, r8
    jne     .fail
    cmp     qword [rel tsx_nodes + 16], -1
    jne     .fail
    lea     rdi, [rel tsx_attr_expr_jsx + 15]
    cmp     [rel tsx_nodes + 40], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 48], 4
    jne     .fail
    cmp     qword [rel tsx_nodes + 56], 0
    jne     .fail
    cmp     qword [rel tsx_nodes + 64], 1
    jne     .fail

    lea     rdi, [rel tsx_spread_attr_jsx]
    mov     esi, TSX_SPREAD_ATTR_JSX_LEN
    lea     rdx, [rel tsx_nodes]
    mov     ecx, 2
    call    er_wasmc_parse_tsx_tree
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 2
    jne     .fail
    cmp     rcx, 2
    jne     .fail
    test    r8, r8
    jne     .fail
    cmp     qword [rel tsx_nodes + 16], -1
    jne     .fail
    lea     rdi, [rel tsx_spread_attr_jsx + 20]
    cmp     [rel tsx_nodes + 40], rdi
    jne     .fail
    cmp     qword [rel tsx_nodes + 48], 4
    jne     .fail
    cmp     qword [rel tsx_nodes + 56], 0
    jne     .fail
    cmp     qword [rel tsx_nodes + 64], 1
    jne     .fail

    lea     rdi, [rel tsx_source_file]
    mov     esi, TSX_SOURCE_FILE_LEN
    call    er_wasmc_scan_tsx_source
    test    rdx, rdx
    jnz     .fail
    cmp     rax, 31
    jne     .fail
    cmp     rcx, 32
    jne     .fail
    cmp     r8, 1
    jne     .fail
    cmp     r9, 0
    jne     .fail

    lea     rdi, [rel tsx_bad_source_comment]
    mov     esi, TSX_BAD_SOURCE_COMMENT_LEN
    call    er_wasmc_scan_tsx_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    TEST_EXIT 0

.fail:
    TEST_EXIT 1

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
