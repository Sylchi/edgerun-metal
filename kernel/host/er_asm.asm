; EdgeRun owned assembler front-end - x86_64 Linux userspace assembly.
; Current milestone: parse source shape and emit a deterministic flat x86_64 byte stream.

%include "x86_64/macros.inc"

SYS_read        equ 0
SYS_write       equ 1
SYS_open        equ 2
SYS_close       equ 3
SYS_exit_group  equ 231
STDOUT_FD       equ 1
STDERR_FD       equ 2
O_RDONLY        equ 0
O_WRONLY        equ 1
O_CREAT         equ 64
O_TRUNC         equ 512
FILE_MODE_0644  equ 420
ER_ASM_BUF_SIZE equ 1048576
EROBJ_HEADER_SIZE equ 148
EROBJ_KIND_BYTES equ 1
EROBJ_VERSION equ 1
ER_ASM_TEXT_CAP equ 65536
ER_ASM_SYM_NAME_CAP equ 30
ER_ASM_EQU_CAP equ 512
ER_ASM_INCLUDE_CAP equ 4
ER_ASM_GLOBAL_CAP equ 256
ER_ASM_LABEL_CAP equ 256
ER_ASM_BRANCH_CAP equ 256
ER_ASM_PATH_SIZE equ 4096
ER_ASM_MACRO_CAP equ 64
ER_ASM_MACRO_ARG_CAP equ 8
ER_ASM_MACRO_EXPAND_CAP equ 16384
ER_ASM_MACRO_DEPTH_CAP equ 8
ASCII_0 equ '0'
ASCII_9 equ '9'
ASCII_A equ 'A'
ASCII_F equ 'F'
ASCII_SQUOTE equ 39
ASCII_X equ 'X'
ASCII_a equ 'a'
ASCII_f equ 'f'
ASCII_x equ 'x'
U32_DIV10 equ 429496729
U32_LAST_DIGIT equ 5
U32_DIV16 equ 268435455

SECTION .bss
source_buf:     resb ER_ASM_BUF_SIZE
include_buf:    resb ER_ASM_BUF_SIZE
text_buf:       resb ER_ASM_TEXT_CAP
output_path:    resq 1
source_path:    resq 1
output_format:  resq 1
include_dir_ptr: resq ER_ASM_INCLUDE_CAP
include_dir_count: resq 1
source_dir_path: resq 1
source_body_len: resq 1
report_fd:      resd 1
assemble_mode:  resq 1
line_count:     resq 1
preproc_count:  resq 1
directive_count: resq 1
label_count:    resq 1
instr_count:    resq 1
exit_instr_step: resq 1
generic_instr_mode: resq 1
exit_subset_bad: resq 1
generic_instr_bad: resq 1
text_len:       resq 1
imm_u32_value:  resq 1
generic_op1_kind: resq 1
generic_op1_width: resq 1
generic_op1_reg: resq 1
generic_op1_index: resq 1
generic_op1_imm: resq 1
generic_op1_sym_ptr: resq 1
generic_op1_sym_len: resq 1
generic_op2_kind: resq 1
generic_op2_width: resq 1
generic_op2_reg: resq 1
generic_op2_index: resq 1
generic_op2_imm: resq 1
generic_op2_sym_ptr: resq 1
generic_op2_sym_len: resq 1
generic_mem_sym_ptr: resq 1
generic_mem_sym_len: resq 1
generic_mem_index: resq 1
generic_opcode_ext: resq 1
branch1_patch_off: resq 1
branch2_patch_off: resq 1
equ_name_ptr:   resq ER_ASM_EQU_CAP
equ_name_len:   resq ER_ASM_EQU_CAP
equ_value:      resq ER_ASM_EQU_CAP
equ_count:      resq 1
global_ptr:     resq ER_ASM_GLOBAL_CAP
global_len:     resq ER_ASM_GLOBAL_CAP
global_value:   resq ER_ASM_GLOBAL_CAP
global_name_off: resq ER_ASM_GLOBAL_CAP
global_count:   resq 1
pending_global_ptr: resq ER_ASM_GLOBAL_CAP
pending_global_len: resq ER_ASM_GLOBAL_CAP
pending_global_count: resq 1
label_symbol_ptr: resq ER_ASM_LABEL_CAP
label_symbol_len: resq ER_ASM_LABEL_CAP
label_symbol_value: resq ER_ASM_LABEL_CAP
label_symbol_count: resq 1
pending_branch_ptr: resq ER_ASM_BRANCH_CAP
pending_branch_len: resq ER_ASM_BRANCH_CAP
pending_branch_off: resq ER_ASM_BRANCH_CAP
pending_branch_count: resq 1
pending_call_ptr: resq ER_ASM_BRANCH_CAP
pending_call_len: resq ER_ASM_BRANCH_CAP
pending_call_off: resq ER_ASM_BRANCH_CAP
pending_call_count: resq 1
pending_rel_ptr: resq ER_ASM_BRANCH_CAP
pending_rel_len: resq ER_ASM_BRANCH_CAP
pending_rel_off: resq ER_ASM_BRANCH_CAP
pending_rel_addend: resq ER_ASM_BRANCH_CAP
pending_rel_count: resq 1
macro_name_ptr: resq ER_ASM_MACRO_CAP
macro_name_len: resq ER_ASM_MACRO_CAP
macro_arg_count: resq ER_ASM_MACRO_CAP
macro_min_arg_count: resq ER_ASM_MACRO_CAP
macro_variadic: resq ER_ASM_MACRO_CAP
macro_body_ptr: resq ER_ASM_MACRO_CAP
macro_body_len: resq ER_ASM_MACRO_CAP
macro_count: resq 1
macro_arg_ptr: resq ER_ASM_MACRO_ARG_CAP
macro_arg_len: resq ER_ASM_MACRO_ARG_CAP
macro_arg_active_count: resq 1
macro_arg_expected_count: resq 1
macro_arg_min_active_count: resq 1
macro_arg_variadic_active: resq 1
macro_expand_depth: resq 1
macro_expand_base_ptr: resq 1
macro_expand_limit_ptr: resq 1
macro_invocation_seq: resq 1
macro_invocation_id: resq 1
macro_expand_buf: resb ER_ASM_MACRO_EXPAND_CAP * ER_ASM_MACRO_DEPTH_CAP
source_dir_buf: resb ER_ASM_PATH_SIZE
include_path_buf: resb ER_ASM_PATH_SIZE
num_buf:        resb 32

SECTION .text
global _start

%macro er_emit_text_bytes 1-*
    %rep %0
        mov     edi, %1
        call    append_text_byte
        %rotate 1
    %endrep
%endm

%macro er_emit_shifted_text_bytes 1
    %assign %%remaining %1
    %rep %%remaining
        er_emit_text_bytes ebx
        %assign %%remaining %%remaining - 1
        %if %%remaining > 0
            shr     rbx, 8
        %endif
    %endrep
%endm

%macro er_emit_imm_u32_value 0
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
%endm

%macro er_emit_imm_u64_value 0
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
%endm

%macro er_emit_imm_byte_value 0
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
%endm

%macro er_emit_zero_u32 0
    xor     edi, edi
    call    append_text_u32
%endm

%macro er_emit_zero_byte 0
    xor     edi, edi
    call    append_text_byte
%endm

%macro er_ret_true 0
    mov     eax, 1
    ret
%endm

%macro er_ret_false 0
    xor     eax, eax
    ret
%endm

%macro er_match_source_token 2
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel %1]
    mov     ecx, %2
    call    token_eq
%endm

%macro er_match_source_token_result 2
    er_match_source_token %1, %2
    test    eax, eax
%endm

%macro er_token_eq_result 0
    call    token_eq
    test    eax, eax
%endm

%macro er_expect_token_operand 2
    lea     rdi, [rel %1]
    mov     esi, %2
    call    expect_operand
%endm

%macro er_expect_token_operand_result 2
    er_expect_token_operand %1, %2
    test    eax, eax
%endm

%macro er_push_expect_token_operand_result 2
    push    r14
    er_expect_token_operand_result %1, %2
%endm

%macro er_pop_expect_token_operand_result 2
    pop     r14
    er_expect_token_operand_result %1, %2
%endm

%macro er_expect_token_operand_push_result 2
    lea     rdi, [rel %1]
    mov     esi, %2
    push    r14
    call    expect_operand
    test    eax, eax
%endm

%macro er_pop_expect_token_operand_push_result 2
    pop     r14
    er_expect_token_operand_push_result %1, %2
%endm

%macro er_expect_comma_result 0
    call    expect_comma
    test    eax, eax
%endm

%macro er_expect_line_end_result 0
    call    expect_line_end
    test    eax, eax
%endm

%macro er_expect_u32_result 0
    call    expect_u32_operand
    test    eax, eax
%endm

%macro er_expect_u64_result 0
    call    expect_u64_operand
    test    eax, eax
%endm

%macro er_expect_imm8_result 0
    call    expect_imm8_operand
    test    eax, eax
%endm

%macro er_expect_value_result 0
    call    expect_value_operand
    test    eax, eax
%endm

%macro er_emit_short_branch_result 0
    call    emit_short_branch_operand
    test    eax, eax
%endm

%macro er_emit_rax_u32 0
    mov     rdi, rax
    call    append_text_u32
%endm

%macro er_match_same_token_operands 4-5
    er_push_expect_token_operand_result %1, %2
    jz      %%not_match
    pop     r11
    er_expect_comma_result
    jz      %%bad
    er_expect_token_operand_result %1, %2
    jz      %%bad
    er_expect_line_end_result
    jz      %%bad
    %if %0 = 4
        er_emit_text_bytes %3, %4
    %else
        er_emit_text_bytes %3, %4, %5
    %endif
    er_ret_true
%%bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
%%not_match:
    pop     r14
%endm

%macro er_match_line_token_operand 4-5
    er_push_expect_token_operand_result %1, %2
    jz      %%not_match
    pop     r11
    er_expect_line_end_result
    jz      %%bad
    %if %0 = 4
        er_emit_text_bytes %3, %4
    %else
        er_emit_text_bytes %3, %4, %5
    %endif
    er_ret_true
%%bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
%%not_match:
    pop     r14
%endm

_start:
    mov     r12, [rsp]
    lea     r13, [rsp + 8]
    cmp     r12, 3
    jb      .usage
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_parse_only]
    call    streq
    test    eax, eax
    jnz     .parse_mode
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_interpret]
    call    streq
    test    eax, eax
    jz      .assembler_args
.parse_mode:
    mov     rdi, [r13 + 16]
    call    parse_file
    test    eax, eax
    jnz     .fail
    mov     dword [rel report_fd], STDOUT_FD
    call    print_report
    xor     edi, edi
    jmp     exit_now
.assembler_args:
    mov     rdi, r12
    mov     rsi, r13
    call    parse_assembler_args
    test    eax, eax
    jnz     .usage
    mov     qword [rel assemble_mode], 1
    mov     rdi, [rel source_path]
    call    parse_file
    test    eax, eax
    jnz     .fail
    call    is_supported_exit_subset
    test    eax, eax
    jz      .unsupported
    mov     rdi, [rel output_path]
    call    emit_flat_binary
    test    eax, eax
    jnz     .fail
    xor     edi, edi
    jmp     exit_now
.usage:
    lea     rdi, [rel msg_usage]
    call    write_stderr
    mov     edi, 2
    jmp     exit_now
.fail:
    lea     rdi, [rel msg_fail]
    call    write_stderr
    mov     edi, 1
    jmp     exit_now
.unsupported:
    lea     rdi, [rel msg_unsupported]
    call    write_stderr
    mov     edi, 1
    jmp     exit_now

; Implementation chunks are split by assembler subsystem.
%include "host/er_asm_core.inc"
%include "host/er_asm_flow.inc"
%include "host/er_asm_mov.inc"
%include "host/er_asm_ops.inc"
%include "host/er_asm_math.inc"
%include "host/er_asm_emit.inc"
%include "host/er_asm_expect.inc"
%include "host/er_asm_report.inc"
%include "host/er_asm_data.inc"
