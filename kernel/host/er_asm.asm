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
ER_ASM_TEXT_CAP equ 65536
ER_ASM_SYM_NAME_CAP equ 30
ER_ASM_EQU_CAP equ 256
ER_ASM_INCLUDE_CAP equ 4
ER_ASM_GLOBAL_CAP equ 256
ER_ASM_LABEL_CAP equ 256
ER_ASM_BRANCH_CAP equ 256
ER_ASM_PATH_SIZE equ 4096
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
include_dir_ptr: resq ER_ASM_INCLUDE_CAP
include_dir_count: resq 1
source_dir_path: resq 1
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
source_dir_buf: resb ER_ASM_PATH_SIZE
include_path_buf: resb ER_ASM_PATH_SIZE
num_buf:        resb 32

SECTION .text
global _start

_start:
    mov     r12, [rsp]
    lea     r13, [rsp + 8]
    cmp     r12, 3
    jb      .usage
    mov     rdi, [r13 + 8]
    lea     rsi, [rel arg_parse_only]
    call    streq
    test    eax, eax
    jz      .assembler_args
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
