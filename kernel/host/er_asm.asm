; EdgeRun owned assembler front-end - x86_64 Linux userspace assembly.
; Current milestone: parse source shape and emit one minimal ELF64 object subset.

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
ER_ASM_OBJ_SIZE equ 3904
ER_ASM_TEXT_OFF equ 64
ER_ASM_TEXT_CAP equ 2048
ER_ASM_SYMTAB_OFF equ 2112
ER_ASM_SYMTAB_CAP equ 408
ER_ASM_SYMTAB_ENTRY_SIZE equ 24
ER_ASM_STRTAB_OFF equ 2520
ER_ASM_STRTAB_CAP equ 1024
ER_ASM_SHSTRTAB_OFF equ 3544
ER_ASM_SHDR_OFF equ 3584
ER_ASM_SYM_NAME_CAP equ 30
ER_ASM_TEXT_SH_SIZE_OFF equ 3680
ER_ASM_SYMTAB_SH_SIZE_OFF equ 3744
ER_ASM_STRTAB_SH_SIZE_OFF equ 3808
ER_ASM_EQU_CAP equ 256
ER_ASM_INCLUDE_CAP equ 4
ER_ASM_GLOBAL_CAP equ 16
ER_ASM_LABEL_CAP equ 64
ER_ASM_BRANCH_CAP equ 64
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
object_buf:     resb ER_ASM_OBJ_SIZE
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
    call    emit_exit_object
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

; parse_assembler_args(argc=rdi, argv=rsi) -> eax=0/error.
er_fn parse_assembler_args
    er_push rbx, r12, r13, r14, r15
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, 1
.loop:
    cmp     r14, r12
    jae     .finish
    mov     r15, [r13 + r14 * 8]
    mov     rdi, r15
    lea     rsi, [rel arg_o]
    call    streq
    test    eax, eax
    jnz     .output_next
    mov     rdi, r15
    lea     rsi, [rel arg_f]
    call    streq
    test    eax, eax
    jnz     .skip_next
    mov     rdi, r15
    lea     rsi, [rel arg_i]
    call    streq
    test    eax, eax
    jnz     .include_next
    cmp     byte [r15], '-'
    jne     .source
    cmp     byte [r15 + 1], 'I'
    jne     .option
    cmp     byte [r15 + 2], 0
    je      .option
    lea     rax, [r15 + 2]
    mov     rdi, rax
    call    add_include_dir
    test    eax, eax
    jz      .bad
    inc     r14
    jmp     .loop
.option:
    inc     r14
    jmp     .loop
.output_next:
    inc     r14
    cmp     r14, r12
    jae     .bad
    mov     r15, [r13 + r14 * 8]
    mov     [rel output_path], r15
    inc     r14
    jmp     .loop
.skip_next:
    inc     r14
    cmp     r14, r12
    jae     .bad
    inc     r14
    jmp     .loop
.include_next:
    inc     r14
    cmp     r14, r12
    jae     .bad
    mov     r15, [r13 + r14 * 8]
    mov     rdi, r15
    call    add_include_dir
    test    eax, eax
    jz      .bad
    inc     r14
    jmp     .loop
.source:
    mov     [rel source_path], r15
    inc     r14
    jmp     .loop
.finish:
    cmp     qword [rel output_path], 0
    je      .bad
    cmp     qword [rel source_path], 0
    je      .bad
    xor     eax, eax
    jmp     .done
.bad:
    mov     eax, 1
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

; add_include_dir(path=rdi) -> eax=1/0.
er_fn add_include_dir
    mov     rax, [rel include_dir_count]
    cmp     rax, ER_ASM_INCLUDE_CAP
    jae     .bad
    mov     [rel include_dir_ptr + rax * 8], rdi
    inc     qword [rel include_dir_count]
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; open_output(path) -> eax=fd or negative errno.
er_fn open_output
    mov     esi, O_WRONLY | O_CREAT | O_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    ret

; is_supported_exit_subset() -> eax=1/0.
er_fn is_supported_exit_subset
    cmp     qword [rel exit_subset_bad], 0
    jne     .no
    cmp     qword [rel directive_count], 2
    jb      .no
    cmp     qword [rel instr_count], 1
    jae     .has_payload
    cmp     qword [rel text_len], 1
    jb      .no
.has_payload:
    cmp     qword [rel global_count], 1
    jb      .no
    cmp     qword [rel pending_global_count], 0
    jne     .no
    cmp     qword [rel pending_branch_count], 0
    jne     .no
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; emit_exit_object(path) -> eax=0/error.
er_fn emit_exit_object
    er_push rbx, r12
    call    open_output
    test    eax, eax
    js      .bad
    mov     ebx, eax
    call    build_exit_object
    cmp     qword [rel exit_subset_bad], 0
    jne     .bad
    mov     edi, ebx
    lea     rsi, [rel object_buf]
    mov     edx, ER_ASM_OBJ_SIZE
    mov     eax, SYS_write
    syscall
    cmp     rax, ER_ASM_OBJ_SIZE
    jne     .bad
    xor     eax, eax
    jmp     .done
.bad:
    mov     eax, 1
.done:
    er_pop  rbx, r12
    ret

er_fn build_exit_object
    er_push rbx, r12, r13
    lea     rbx, [rel object_buf]
    lea     r12, [rel exit_object_start]
    mov     r13d, ER_ASM_OBJ_SIZE
.copy_obj:
    test    r13, r13
    jz      .copy_text_start
    movzx   eax, byte [r12]
    mov     [rbx], al
    inc     r12
    inc     rbx
    dec     r13
    jmp     .copy_obj
.copy_text_start:
    lea     rbx, [rel object_buf + ER_ASM_TEXT_OFF]
    lea     r12, [rel text_buf]
    mov     r13, [rel text_len]
.copy_text:
    test    r13, r13
    jz      .patch
    movzx   eax, byte [r12]
    mov     [rbx], al
    inc     r12
    inc     rbx
    dec     r13
    jmp     .copy_text
.patch:
    mov     rax, [rel text_len]
    mov     [rel object_buf + ER_ASM_TEXT_SH_SIZE_OFF], rax
    call    patch_global_symbols
    er_pop  rbx, r12, r13
    ret

er_fn patch_global_symbols
    er_push rbx, r12, r13, r14, r15
    mov     r12, 1
    xor     r13d, r13d
.str_loop:
    cmp     r13, [rel global_count]
    jae     .sym_start
    mov     r14, [rel global_len + r13 * 8]
    lea     rax, [r12 + r14 + 1]
    cmp     rax, ER_ASM_STRTAB_CAP
    ja      .bad
    mov     [rel global_name_off + r13 * 8], r12
    lea     rbx, [rel object_buf + ER_ASM_STRTAB_OFF]
    add     rbx, r12
    mov     r15, [rel global_ptr + r13 * 8]
    xor     ecx, ecx
.copy_name:
    cmp     rcx, r14
    jae     .name_done
    movzx   eax, byte [r15 + rcx]
    mov     [rbx + rcx], al
    inc     ecx
    jmp     .copy_name
.name_done:
    mov     byte [rbx + rcx], 0
    lea     r12, [r12 + r14 + 1]
    inc     r13
    jmp     .str_loop
.sym_start:
    mov     rax, [rel global_count]
    inc     rax
    imul    rax, rax, ER_ASM_SYMTAB_ENTRY_SIZE
    mov     [rel object_buf + ER_ASM_SYMTAB_SH_SIZE_OFF], rax
    mov     [rel object_buf + ER_ASM_STRTAB_SH_SIZE_OFF], r12
    xor     r13d, r13d
.sym_loop:
    cmp     r13, [rel global_count]
    jae     .done
    cmp     r13, ER_ASM_GLOBAL_CAP
    jae     .bad
    lea     rbx, [rel object_buf + ER_ASM_SYMTAB_OFF + ER_ASM_SYMTAB_ENTRY_SIZE]
    imul    rax, r13, ER_ASM_SYMTAB_ENTRY_SIZE
    add     rbx, rax
    mov     eax, [rel global_name_off + r13 * 8]
    mov     [rbx], eax
    mov     byte [rbx + 4], 0x10
    mov     byte [rbx + 5], 0
    mov     word [rbx + 6], 1
    mov     rax, [rel global_value + r13 * 8]
    mov     [rbx + 8], rax
    mov     qword [rbx + 16], 0
    inc     r13
    jmp     .sym_loop
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

; parse_file(path) -> eax=0/error
er_fn parse_file
    er_push r14, r15
    call    capture_source_dir
    lea     rsi, [rel source_buf]
    call    read_file_to_buffer
    test    rax, rax
    js      .bad
    lea     r14, [rel source_buf]
    lea     r15, [r14 + rax]
    call    scan_source
    xor     eax, eax
    jmp     .done
.bad:
    mov     eax, 1
.done:
    er_pop  r14, r15
    ret

; capture_source_dir(path=rdi)
er_fn capture_source_dir
    er_push rbx, r12, r13, r14
    mov     qword [rel source_dir_path], 0
    mov     r12, rdi
    xor     r13d, r13d
    xor     r14d, r14d
.find:
    movzx   eax, byte [r12 + r13]
    test    al, al
    jz      .copy
    cmp     al, '/'
    jne     .next
    mov     r14, r13
.next:
    inc     r13
    jmp     .find
.copy:
    test    r14, r14
    jz      .done
    cmp     r14, ER_ASM_PATH_SIZE
    jae     .done
    lea     rbx, [rel source_dir_buf]
    xor     r13d, r13d
.copy_loop:
    cmp     r13, r14
    jae     .finish
    movzx   eax, byte [r12 + r13]
    mov     [rbx + r13], al
    inc     r13
    jmp     .copy_loop
.finish:
    mov     byte [rbx + r13], 0
    lea     rax, [rel source_dir_buf]
    mov     [rel source_dir_path], rax
.done:
    er_pop  rbx, r12, r13, r14
    ret

; read_file_to_buffer(path=rdi, buf=rsi) -> rax=length or -1.
er_fn read_file_to_buffer
    er_push rbx, r12, r13
    mov     r12, rsi
    mov     esi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .bad
    mov     ebx, eax
    mov     edi, ebx
    mov     rsi, r12
    mov     edx, ER_ASM_BUF_SIZE
    mov     eax, SYS_read
    syscall
    mov     r13, rax
    mov     edi, ebx
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      .bad
    test    r13, r13
    js      .bad
    cmp     r13, ER_ASM_BUF_SIZE
    jae     .bad
    mov     rax, r13
    jmp     .done
.bad:
    mov     rax, -1
.done:
    er_pop  rbx, r12, r13
    ret

; scan_source(r14=cursor, r15=end)
er_fn scan_source
    er_push rbx, r12, r13, r14, r15
.line:
    cmp     r14, r15
    jae     .done
    inc     qword [rel line_count]
    call    skip_space_inline
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .next_line
    cmp     al, ';'
    je      .skip_line
    cmp     al, '%'
    jne     .token
    inc     qword [rel preproc_count]
    call    handle_preproc
    jmp     .skip_line
.token:
    mov     r12, r14
    call    skip_token
    mov     r13, r14
    sub     r13, r12
    cmp     r14, r15
    jae     .classify
    cmp     byte [r14], ':'
    jne     .classify
    inc     qword [rel label_count]
    call    record_label_symbol
    call    patch_pending_branches_for_label
    call    handle_code_label
    call    record_pending_global_label
    inc     r14
    call    skip_space_inline
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .next_line
    cmp     al, ';'
    je      .skip_line
    mov     r12, r14
    call    skip_token
    mov     r13, r14
    sub     r13, r12
.classify:
    call    record_er_fn_directive
    test    eax, eax
    jnz     .directive
    mov     rdi, r12
    mov     rsi, r13
    call    is_directive
    test    eax, eax
    jz      .maybe_equ
    call    handle_directive_emit
    jmp     .directive
.maybe_equ:
    mov     r10, r12
    mov     r11, r13
    call    skip_space_inline
    mov     rbx, r14
    mov     r12, r14
    call    skip_token
    mov     r13, r14
    sub     r13, r12
    mov     r14, rbx
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_equ]
    mov     ecx, tok_equ_len
    call    token_eq
    test    eax, eax
    jz      .not_equ
    call    record_equ
    jmp     .directive
.not_equ:
    mov     r12, r10
    mov     r13, r11
    cmp     qword [rel generic_instr_mode], 1
    je      .try_real_instruction
    cmp     qword [rel exit_instr_step], 0
    jne     .exit_instruction
.try_real_instruction:
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
.exit_instruction:
    call    track_exit_instruction
    jmp     .instruction_done
.real_instruction_done:
    pop     r11
    mov     qword [rel generic_instr_mode], 1
.instruction_done:
    inc     qword [rel instr_count]
    jmp     .skip_line
.directive:
    inc     qword [rel directive_count]
    jmp     .skip_line
.next_line:
    inc     r14
    jmp     .line
.skip_line:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    inc     r14
    cmp     al, 10
    jne     .skip_line
    jmp     .line
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

er_fn record_er_fn_directive
    er_push r12, r13
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_fn]
    mov     ecx, tok_er_fn_len
    call    token_eq
    test    eax, eax
    jz      .no
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    cmp     r13, ER_ASM_SYM_NAME_CAP
    ja      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     r10, r12
    mov     r11, r13
    mov     rax, [rel text_len]
    call    add_global_symbol
    mov     qword [rel exit_instr_step], 0
    inc     qword [rel label_count]
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    jmp     .done
.no:
    xor     eax, eax
.done:
    er_pop  r12, r13
    ret

er_fn handle_directive_emit
    er_push r12, r13
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_global]
    mov     ecx, tok_global_len
    call    token_eq
    test    eax, eax
    jz      .incbin
    call    record_global_operands
    jmp     .done
.incbin:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_incbin]
    mov     ecx, tok_incbin_len
    call    token_eq
    test    eax, eax
    jz      .db
    call    emit_incbin_directive
    jmp     .done
.db:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_db]
    mov     ecx, tok_db_len
    call    token_eq
    test    eax, eax
    jz      .dq
    call    emit_db_directive
    jmp     .done
.dq:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_dq]
    mov     ecx, tok_dq_len
    call    token_eq
    test    eax, eax
    jz      .done
    call    emit_dq_directive
.done:
    er_pop  r12, r13
    ret

er_fn record_global_operands
    er_push r12, r13
.next_operand:
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    cmp     r13, ER_ASM_SYM_NAME_CAP
    ja      .bad
    call    record_global_operand
    test    eax, eax
    jz      .bad
    call    skip_space_inline
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, ','
    jne     .line_end
    inc     r14
    jmp     .next_operand
.line_end:
    call    expect_line_end
    test    eax, eax
    jnz     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r12, r13
    ret

er_fn record_global_operand
    er_push r10, r11
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .pending
    mov     r10, r12
    mov     r11, r13
    mov     rax, rdx
    call    add_global_symbol
    jmp     .done
.pending:
    mov     rax, [rel pending_global_count]
    cmp     rax, ER_ASM_GLOBAL_CAP
    jae     .bad
    mov     [rel pending_global_ptr + rax * 8], r12
    mov     [rel pending_global_len + rax * 8], r13
    inc     qword [rel pending_global_count]
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11
    ret

er_fn record_label_symbol
    er_push rbx, r10, r11
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jnz     .ok
    mov     rbx, [rel label_symbol_count]
    cmp     rbx, ER_ASM_LABEL_CAP
    jae     .bad
    mov     [rel label_symbol_ptr + rbx * 8], r12
    mov     [rel label_symbol_len + rbx * 8], r13
    mov     rax, [rel text_len]
    mov     [rel label_symbol_value + rbx * 8], rax
    inc     qword [rel label_symbol_count]
.ok:
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11
    ret

; find_label_value(name=r10, name_len=r11) -> eax=1/0, rdx=value.
er_fn find_label_value
    er_push rbx
    xor     ebx, ebx
.loop:
    cmp     rbx, [rel label_symbol_count]
    jae     .no
    mov     rdi, r10
    mov     rsi, r11
    mov     rdx, [rel label_symbol_ptr + rbx * 8]
    mov     rcx, [rel label_symbol_len + rbx * 8]
    call    token_eq
    test    eax, eax
    jnz     .yes
    inc     rbx
    jmp     .loop
.yes:
    mov     rdx, [rel label_symbol_value + rbx * 8]
    mov     eax, 1
    jmp     .done
.no:
    xor     eax, eax
.done:
    er_pop  rbx
    ret

er_fn record_pending_global_label
    er_push rbx, r12, r13, r14, r15
    xor     ebx, ebx
.loop:
    cmp     rbx, [rel pending_global_count]
    jae     .done
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rel pending_global_ptr + rbx * 8]
    mov     rcx, [rel pending_global_len + rbx * 8]
    call    token_eq
    test    eax, eax
    jz      .next
    mov     r10, [rel pending_global_ptr + rbx * 8]
    mov     r11, [rel pending_global_len + rbx * 8]
    mov     rax, [rel text_len]
    call    add_global_symbol
    test    eax, eax
    jz      .bad
    call    remove_pending_global_at
    jmp     .loop
.next:
    inc     rbx
    jmp     .loop
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

; remove_pending_global_at(index=rbx)
er_fn remove_pending_global_at
    mov     r14, rbx
.shift:
    inc     r14
    cmp     r14, [rel pending_global_count]
    jae     .finish
    mov     r15, [rel pending_global_ptr + r14 * 8]
    mov     [rel pending_global_ptr + r14 * 8 - 8], r15
    mov     r15, [rel pending_global_len + r14 * 8]
    mov     [rel pending_global_len + r14 * 8 - 8], r15
    jmp     .shift
.finish:
    dec     qword [rel pending_global_count]
    ret

er_fn patch_pending_branches_for_label
    er_push rbx, r12, r13, r14, r15
    xor     ebx, ebx
.loop:
    cmp     rbx, [rel pending_branch_count]
    jae     .done
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rel pending_branch_ptr + rbx * 8]
    mov     rcx, [rel pending_branch_len + rbx * 8]
    call    token_eq
    test    eax, eax
    jz      .next
    mov     rdi, [rel pending_branch_off + rbx * 8]
    call    patch_branch_to_current
    call    remove_pending_branch_at
    jmp     .loop
.next:
    inc     rbx
    jmp     .loop
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

; remove_pending_branch_at(index=rbx)
er_fn remove_pending_branch_at
    mov     r14, rbx
.shift:
    inc     r14
    cmp     r14, [rel pending_branch_count]
    jae     .finish
    mov     r15, [rel pending_branch_ptr + r14 * 8]
    mov     [rel pending_branch_ptr + r14 * 8 - 8], r15
    mov     r15, [rel pending_branch_len + r14 * 8]
    mov     [rel pending_branch_len + r14 * 8 - 8], r15
    mov     r15, [rel pending_branch_off + r14 * 8]
    mov     [rel pending_branch_off + r14 * 8 - 8], r15
    jmp     .shift
.finish:
    dec     qword [rel pending_branch_count]
    ret

er_fn add_global_symbol
    er_push rbx
    mov     rbx, [rel global_count]
    cmp     rbx, ER_ASM_GLOBAL_CAP
    jae     .bad
    mov     [rel global_ptr + rbx * 8], r10
    mov     [rel global_len + rbx * 8], r11
    mov     [rel global_value + rbx * 8], rax
    inc     qword [rel global_count]
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx
    ret

; record_equ(name=r10, name_len=r11, r14=equ token).
er_fn record_equ
    er_push r10, r11
    call    skip_token
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r10, r11
    ret

; handle_preproc(r14=line cursor at %).
er_fn handle_preproc
    er_push r12, r13, r14, r15
    mov     r12, r14
    call    skip_token
    mov     r13, r14
    sub     r13, r12
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_percent_define]
    mov     ecx, tok_percent_define_len
    call    token_eq
    test    eax, eax
    jz      .include
    call    record_define
    jmp     .done
.include:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_percent_include]
    mov     ecx, tok_percent_include_len
    call    token_eq
    test    eax, eax
    jz      .done
    cmp     qword [rel assemble_mode], 0
    je      .done
    call    record_include
.done:
    er_pop  r12, r13, r14, r15
    ret

er_fn record_define
    er_push r10, r11
    call    skip_space_inline
    mov     r10, r14
    call    skip_token
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .has_value
    mov     qword [rel imm_u32_value], 1
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.has_value:
    call    expect_u32_operand
    test    eax, eax
    jz      .skip_unsupported
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.skip_unsupported:
    call    expect_line_end
    test    eax, eax
    jz      .skip_to_line
    jmp     .done
.skip_to_line:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .done
    inc     r14
    jmp     .skip_to_line
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r10, r11
    ret

er_fn record_include
    er_push r12
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '"'
    jne     .bad
    inc     r14
    mov     r10, r14
.name:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, '"'
    je      .name_done
    cmp     al, 10
    je      .bad
    inc     r14
    jmp     .name
.name_done:
    mov     r11, r14
    sub     r11, r10
    inc     r14
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_x86_macros_inc]
    mov     ecx, tok_x86_macros_inc_len
    call    token_eq
    test    eax, eax
    jnz     .done
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_test_macros_inc]
    mov     ecx, tok_test_macros_inc_len
    call    token_eq
    test    eax, eax
    jnz     .done
    call    build_include_path
    test    rax, rax
    jz      .bad
    er_push r10, r11
    mov     rdi, rax
    lea     rsi, [rel include_buf]
    call    read_file_to_buffer
    test    rax, rax
    jns     .read_ok
    er_pop  r10, r11
    xor     r12d, r12d
.include_dir_loop:
    cmp     r12, [rel include_dir_count]
    jae     .bad
    mov     rdi, [rel include_dir_ptr + r12 * 8]
    call    build_include_path_with_dir
    test    rax, rax
    jz      .next_include_dir
    er_push r10, r11
    mov     rdi, rax
    lea     rsi, [rel include_buf]
    call    read_file_to_buffer
    test    rax, rax
    jns     .read_ok
    er_pop  r10, r11
.next_include_dir:
    inc     r12
    jmp     .include_dir_loop
    jmp     .scan
.read_ok:
    er_pop  r10, r11
.scan:
    er_push r14, r15
    lea     r14, [rel include_buf]
    lea     r15, [r14 + rax]
    call    scan_source
    er_pop  r14, r15
.done:
    er_pop  r12
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_pop  r12
    ret

er_fn emit_incbin_directive
    er_push r10, r11
    call    parse_quoted_name
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    build_include_path
    test    rax, rax
    jz      .bad
    mov     rdi, rax
    lea     rsi, [rel include_buf]
    call    read_file_to_buffer
    test    rax, rax
    js      .bad
    lea     rsi, [rel include_buf]
    mov     rcx, rax
    call    append_text_bytes
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r10, r11
    ret

er_fn emit_db_directive
    er_push r12, r13
.next_value:
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '"'
    jne     .number
    inc     r14
.string_loop:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, '"'
    je      .string_done
    cmp     al, 10
    je      .bad
    mov     edi, eax
    call    append_text_byte
    inc     r14
    jmp     .string_loop
.string_done:
    inc     r14
    jmp     .separator
.number:
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .bad
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
.separator:
    call    skip_space_inline
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, ','
    jne     .line_end
    inc     r14
    jmp     .next_value
.line_end:
    call    expect_line_end
    test    eax, eax
    jnz     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r12, r13
    ret

er_fn emit_dq_directive
    er_push r12, r13, rbx
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .bad
    mov     rbx, rdx
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '-'
    jne     .bad
    inc     r14
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .bad
    sub     rbx, rdx
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     rdi, rbx
    call    append_text_u64
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r12, r13, rbx
    ret

; parse_quoted_name() -> eax=1/0, r10=name, r11=len.
er_fn parse_quoted_name
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '"'
    jne     .bad
    inc     r14
    mov     r10, r14
.loop:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, '"'
    je      .done_name
    cmp     al, 10
    je      .bad
    inc     r14
    jmp     .loop
.done_name:
    mov     r11, r14
    sub     r11, r10
    inc     r14
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; build_include_path(name=r10, len=r11) -> rax=cstr path or 0.
er_fn build_include_path
    mov     rdi, [rel source_dir_path]
    jmp     build_include_path_with_dir

; build_include_path_with_dir(dir=rdi, name=r10, len=r11) -> rax=cstr path or 0.
er_fn build_include_path_with_dir
    er_push rbx, r12, r13
    lea     rbx, [rel include_path_buf]
    mov     r13, ER_ASM_PATH_SIZE
    mov     r12, rdi
    test    r12, r12
    jz      .copy_name
.copy_dir:
    cmp     r13, 2
    jb      .bad
    movzx   eax, byte [r12]
    test    al, al
    jz      .slash
    mov     [rbx], al
    inc     r12
    inc     rbx
    dec     r13
    jmp     .copy_dir
.slash:
    mov     byte [rbx], '/'
    inc     rbx
    dec     r13
.copy_name:
    test    r11, r11
    jz      .bad
    cmp     r11, r13
    jae     .bad
    xor     r12d, r12d
.copy_name_loop:
    cmp     r12, r11
    jae     .finish
    movzx   eax, byte [r10 + r12]
    mov     [rbx], al
    inc     rbx
    inc     r12
    jmp     .copy_name_loop
.finish:
    mov     byte [rbx], 0
    lea     rax, [rel include_path_buf]
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; add_equ_symbol(name=r10, name_len=r11, imm_u32_value=value) -> eax=1/0.
er_fn add_equ_symbol
    er_push rbx
    call    equ_name_exists
    test    eax, eax
    jnz     .bad
    mov     rbx, [rel equ_count]
    cmp     rbx, ER_ASM_EQU_CAP
    jae     .bad
    mov     [rel equ_name_ptr + rbx * 8], r10
    mov     [rel equ_name_len + rbx * 8], r11
    mov     rax, [rel imm_u32_value]
    mov     [rel equ_value + rbx * 8], rax
    inc     qword [rel equ_count]
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx
    ret

; equ_name_exists(name=r10, name_len=r11) -> eax=1/0.
er_fn equ_name_exists
    er_push rbx
    xor     ebx, ebx
.loop:
    cmp     rbx, [rel equ_count]
    jae     .no
    mov     rdi, r10
    mov     rsi, r11
    mov     rdx, [rel equ_name_ptr + rbx * 8]
    mov     rcx, [rel equ_name_len + rbx * 8]
    call    token_eq
    test    eax, eax
    jnz     .yes
    inc     rbx
    jmp     .loop
.yes:
    mov     eax, 1
    jmp     .done
.no:
    xor     eax, eax
.done:
    er_pop  rbx
    ret

er_fn skip_space_inline
.loop:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .advance
    cmp     al, 9
    je      .advance
    cmp     al, 13
    je      .advance
    ret
.advance:
    inc     r14
    jmp     .loop
.done:
    ret

er_fn skip_token
.loop:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .done
    cmp     al, 9
    je      .done
    cmp     al, 10
    je      .done
    cmp     al, 13
    je      .done
    cmp     al, ';'
    je      .done
    cmp     al, ':'
    je      .done
    inc     r14
    jmp     .loop
.done:
    ret

er_fn skip_operand_token
.loop:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .done
    cmp     al, 9
    je      .done
    cmp     al, 10
    je      .done
    cmp     al, 13
    je      .done
    cmp     al, ';'
    je      .done
    cmp     al, ','
    je      .done
    inc     r14
    jmp     .loop
.done:
    ret

; track_exit_instruction(mnemonic=r12, len=r13, r14=operand cursor).
er_fn track_exit_instruction
    er_push rbx, r12, r13
    cmp     qword [rel exit_subset_bad], 0
    jne     .done
    mov     rbx, [rel exit_instr_step]
    cmp     rbx, 0
    je      .mov_exit
    cmp     rbx, 1
    je      .ret_or_xor_zero
    cmp     rbx, 2
    je      .syscall
    cmp     rbx, 4
    je      .bad
    cmp     rbx, 5
    je      .ret_after_xor_eax
    cmp     rbx, 7
    je      .ret_after_mov_eax_edi
    cmp     rbx, 20
    je      .jb_false
    cmp     rbx, 21
    je      .cmp_dil_high
    cmp     rbx, 22
    je      .ja_false
    cmp     rbx, 23
    je      .mov_branch_true
    cmp     rbx, 24
    je      .ret_branch_true
    cmp     rbx, 26
    je      .xor_branch_false
    cmp     rbx, 27
    je      .ret_branch_false
    cmp     rbx, 31
    je      .jnz_false
    cmp     rbx, 35
    je      .ret_after_adjust
    cmp     rbx, 36
    je      .ret_after_adjust
    cmp     rbx, 40
    je      .ret_after_portio
    jmp     .bad
.mov_exit:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .xor_eax_zero
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_exit_rax
    pop     r11
    xor     r10d, r10d
    jmp     .mov_exit_operand_ok
.mov_exit_rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     r10d, 1
.mov_exit_operand_ok:
    call    expect_comma
    test    eax, eax
    jz      .bad
    cmp     r10d, 0
    jne     .mov_exit_u32
    push    r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .mov_exit_not_edi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_mov_eax_edi
    mov     qword [rel exit_instr_step], 7
    jmp     .done
.mov_exit_not_edi:
    pop     r14
.mov_exit_u32:
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r10d, r10d
    jnz     .emit_mov_rax_exit
    call    emit_mov_eax_imm32
    jmp     .mov_exit_done
.emit_mov_rax_exit:
    call    emit_mov_rax_imm32
.mov_exit_done:
    inc     qword [rel exit_instr_step]
    jmp     .done
.xor_eax_zero:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
    call    token_eq
    test    eax, eax
    jz      .cmp_dil_low
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_xor_eax_eax
    mov     qword [rel exit_instr_step], 5
    jmp     .done
.cmp_dil_low:
    call    match_cmp_dil_imm8
    test    eax, eax
    jz      .test_edi_zero
    call    emit_cmp_dil_imm8
    mov     qword [rel exit_instr_step], 20
    jmp     .done
.test_edi_zero:
    call    match_test_edi_edi
    test    eax, eax
    jz      .portio
    call    emit_test_edi_edi
    mov     qword [rel exit_instr_step], 31
    jmp     .done
.portio:
    call    match_in_al_dx
    test    eax, eax
    jz      .out_dx_al
    call    emit_in_al_dx
    mov     qword [rel exit_instr_step], 40
    jmp     .done
.out_dx_al:
    call    match_out_dx_al
    test    eax, eax
    jz      .ret_only
    call    emit_out_dx_al
    mov     qword [rel exit_instr_step], 40
    jmp     .done
.ret_only:
    call    match_ret_line
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 4
    jmp     .done
.ret_or_xor_zero:
    call    match_ret_line
    test    eax, eax
    jz      .xor_zero
    call    emit_ret
    mov     qword [rel exit_instr_step], 4
    jmp     .done
.ret_after_xor_eax:
    call    match_ret_line
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 6
    jmp     .done
.ret_after_mov_eax_edi:
    call    match_ret_line
    test    eax, eax
    jz      .cmp_after_mov_eax_edi
    call    emit_ret
    mov     qword [rel exit_instr_step], 8
    jmp     .done
.cmp_after_mov_eax_edi:
    call    match_cmp_dil_imm8
    test    eax, eax
    jz      .bad
    call    emit_cmp_dil_imm8
    mov     qword [rel exit_instr_step], 20
    jmp     .done
.xor_zero:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
    call    token_eq
    test    eax, eax
    jz      .mov_status
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_xor_edi_edi
    inc     qword [rel exit_instr_step]
    jmp     .done
.mov_status:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_status_rdi
    pop     r11
    xor     r10d, r10d
    jmp     .mov_status_operand_ok
.mov_status_rdi:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     r10d, 1
.mov_status_operand_ok:
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r10d, r10d
    jnz     .emit_mov_rdi_status
    call    emit_mov_edi_imm32
    jmp     .mov_status_done
.emit_mov_rdi_status:
    call    emit_mov_rdi_imm32
.mov_status_done:
    inc     qword [rel exit_instr_step]
    jmp     .done
.syscall:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_syscall]
    mov     ecx, tok_syscall_len
    call    token_eq
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_syscall
    inc     qword [rel exit_instr_step]
    jmp     .done
.jb_false:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jb]
    mov     ecx, tok_jb_len
    call    token_eq
    test    eax, eax
    jz      .bad
    call    expect_target_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_jb_placeholder
    mov     qword [rel exit_instr_step], 21
    jmp     .done
.cmp_dil_high:
    call    match_cmp_dil_imm8
    test    eax, eax
    jz      .bad
    call    emit_cmp_dil_imm8
    mov     qword [rel exit_instr_step], 22
    jmp     .done
.ja_false:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_ja]
    mov     ecx, tok_ja_len
    call    token_eq
    test    eax, eax
    jz      .bad
    call    expect_target_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_ja_placeholder
    mov     qword [rel exit_instr_step], 23
    jmp     .done
.jnz_false:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jnz]
    mov     ecx, tok_jnz_len
    call    token_eq
    test    eax, eax
    jz      .bad
    call    expect_target_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_jnz_placeholder
    mov     qword [rel exit_instr_step], 23
    jmp     .done
.mov_branch_true:
    call    match_mov_eax_imm32
    test    eax, eax
    jz      .adjust_eax
    call    emit_mov_eax_imm32
    mov     qword [rel exit_instr_step], 24
    jmp     .done
.adjust_eax:
    call    match_addsub_eax_imm8
    test    eax, eax
    jz      .bad
    cmp     r10d, 0
    jne     .emit_sub_eax
    call    emit_add_eax_imm8
    mov     qword [rel exit_instr_step], 35
    jmp     .done
.emit_sub_eax:
    call    emit_sub_eax_imm8
    mov     qword [rel exit_instr_step], 35
    jmp     .done
.ret_branch_true:
    call    match_ret_line
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 25
    jmp     .done
.xor_branch_false:
    call    match_xor_eax_eax
    test    eax, eax
    jz      .bad
    call    emit_xor_eax_eax
    mov     qword [rel exit_instr_step], 27
    jmp     .done
.ret_branch_false:
    call    match_ret_line
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 28
    jmp     .done
.ret_after_adjust:
    call    match_ret_line
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 37
    jmp     .done
.ret_after_portio:
    call    match_ret_line
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 41
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r12, r13
    ret

er_fn handle_code_label
    cmp     qword [rel exit_instr_step], 4
    je      .reset
    cmp     qword [rel exit_instr_step], 6
    je      .reset
    cmp     qword [rel exit_instr_step], 8
    je      .reset
    cmp     qword [rel exit_instr_step], 41
    je      .reset
    cmp     qword [rel exit_instr_step], 35
    je      .adjust_done
    cmp     qword [rel exit_instr_step], 25
    jne     .done
    call    patch_branches_to_current
    cmp     qword [rel exit_subset_bad], 0
    jne     .done
    mov     qword [rel exit_instr_step], 0
    jmp     .done
.adjust_done:
    call    patch_branches_to_current
    cmp     qword [rel exit_subset_bad], 0
    jne     .done
    mov     qword [rel exit_instr_step], 36
    jmp     .done
.reset:
    mov     qword [rel exit_instr_step], 0
.done:
    ret

er_fn track_real_instruction
    call    match_test_layout_macros
    test    eax, eax
    jz      .stack_macros
    mov     eax, 1
    ret
.stack_macros:
    call    match_stack_macros
    test    eax, eax
    jz      .ret_macro
    mov     eax, 1
    ret
.ret_macro:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_ret]
    mov     ecx, tok_er_ret_len
    call    token_eq
    test    eax, eax
    jz      .mov
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_ret
    mov     eax, 1
    ret
.mov:
    push    r14
    call    match_common_mov
    test    eax, eax
    jz      .math_mov
    pop     r11
    mov     eax, 1
    ret
.math_mov:
    pop     r14
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .math_mov_after_more
    pop     r11
    mov     eax, 1
    ret
.math_mov_after_more:
    pop     r14
    call    match_math_hash_mov
    test    eax, eax
    jz      .xor
    mov     eax, 1
    ret
.xor:
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .shift
    pop     r11
    mov     eax, 1
    ret
.shift:
    pop     r14
    call    match_math_hash_xor
    test    eax, eax
    jz      .shift_ops
    mov     eax, 1
    ret
.shift_ops:
    call    match_math_hash_shift
    test    eax, eax
    jz      .test
    mov     eax, 1
    ret
.test:
    call    match_math_hash_test
    test    eax, eax
    jz      .cmp
    mov     eax, 1
    ret
.cmp:
    call    match_math_hash_cmp
    test    eax, eax
    jz      .arith
    mov     eax, 1
    ret
.arith:
    call    match_math_hash_arith
    test    eax, eax
    jz      .branch
    mov     eax, 1
    ret
.branch:
    call    match_math_hash_branch
    test    eax, eax
    jz      .crc32
    mov     eax, 1
    ret
.crc32:
    call    match_math_hash_crc32
    test    eax, eax
    jz      .movzx
    mov     eax, 1
    ret
.movzx:
    call    match_math_hash_movzx
    test    eax, eax
    jz      .mul
    mov     eax, 1
    ret
.mul:
    call    match_math_hash_mul
    test    eax, eax
    jz      .syscall
    mov     eax, 1
    ret
.syscall:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_syscall]
    mov     ecx, tok_syscall_len
    call    token_eq
    test    eax, eax
    jz      .lea
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_syscall
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret
.lea:
    call    match_lea_rel_label
    test    eax, eax
    jz      .test_exit
    mov     eax, 1
    ret
.test_exit:
    call    match_test_exit_macro
    test    eax, eax
    jz      .no
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_stack_macros
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_frame_push]
    mov     ecx, tok_er_frame_push_len
    call    token_eq
    test    eax, eax
    jz      .frame_pop
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x55
    call    append_text_byte
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xe5
    call    append_text_byte
    jmp     .yes
.frame_pop:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_frame_pop]
    mov     ecx, tok_er_frame_pop_len
    call    token_eq
    test    eax, eax
    jz      .er_push
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x5d
    call    append_text_byte
    jmp     .yes
.er_push:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_push]
    mov     ecx, tok_er_push_len
    call    token_eq
    test    eax, eax
    jz      .er_pop
    mov     r10d, 0
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
    jmp     .yes
.er_pop:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_pop]
    mov     ecx, tok_er_pop_len
    call    token_eq
    test    eax, eax
    jz      .push
    mov     r10d, 1
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
    jmp     .yes
.push:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_push]
    mov     ecx, tok_push_len
    call    token_eq
    test    eax, eax
    jz      .pop
    mov     r10d, 0
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
    jmp     .yes
.pop:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_pop]
    mov     ecx, tok_pop_len
    call    token_eq
    test    eax, eax
    jz      .no
    mov     r10d, 1
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
.yes:
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; emit_push_pop_list(r10d=0 push, 1 pop) -> eax=1/0.
er_fn emit_push_pop_list
    er_push r12, r13
.next:
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    call    emit_push_pop_reg
    test    eax, eax
    jz      .bad
    call    skip_space_inline
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, ','
    jne     .line_end
    inc     r14
    jmp     .next
.line_end:
    call    expect_line_end
    test    eax, eax
    jz      .bad
.done:
    mov     eax, 1
    jmp     .out
.bad:
    xor     eax, eax
.out:
    er_pop  r12, r13
    ret

; emit_push_pop_reg(token=r12/r13, r10d=0 push, 1 pop) -> eax=1/0.
er_fn emit_push_pop_reg
    lea     rdx, [rel tok_rax]
    mov     ecx, tok_rax_len
    mov     r11d, 0
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rcx]
    mov     ecx, tok_rcx_len
    mov     r11d, 1
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rdx]
    mov     ecx, tok_rdx_len
    mov     r11d, 2
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rbx]
    mov     ecx, tok_rbx_len
    mov     r11d, 3
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rsp]
    mov     ecx, tok_rsp_len
    mov     r11d, 4
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rbp]
    mov     ecx, tok_rbp_len
    mov     r11d, 5
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rsi]
    mov     ecx, tok_rsi_len
    mov     r11d, 6
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_rdi]
    mov     ecx, tok_rdi_len
    mov     r11d, 7
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r12]
    mov     ecx, tok_r12_len
    mov     r11d, 12
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r13]
    mov     ecx, tok_r13_len
    mov     r11d, 13
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r14]
    mov     ecx, tok_r14_len
    mov     r11d, 14
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r15]
    mov     ecx, tok_r15_len
    mov     r11d, 15
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_emit_gpr_stack
    mov     rdi, r12
    mov     rsi, r13
    call    token_eq
    test    eax, eax
    jz      .no
    cmp     r11d, 8
    jb      .low
    mov     edi, 0x41
    call    append_text_byte
    mov     eax, r11d
    sub     eax, 8
    jmp     .opcode
.low:
    mov     eax, r11d
.opcode:
    cmp     r10d, 0
    jne     .pop
    add     eax, 0x50
    jmp     .emit
.pop:
    add     eax, 0x58
.emit:
    mov     edi, eax
    call    append_text_byte
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_test_layout_macros
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_bss_passed_failed]
    mov     ecx, tok_test_bss_passed_failed_len
    call    token_eq
    test    eax, eax
    jz      .data_passed_failed
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_passed_failed_layout
    jmp     .yes
.data_passed_failed:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_data_passed_failed]
    mov     ecx, tok_test_data_passed_failed_len
    call    token_eq
    test    eax, eax
    jz      .bss_total_passed
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_passed_failed_layout
    jmp     .yes
.bss_total_passed:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_bss_total_passed]
    mov     ecx, tok_test_bss_total_passed_len
    call    token_eq
    test    eax, eax
    jz      .bss_total_passed_failed
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_total_passed_layout
    jmp     .yes
.bss_total_passed_failed:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_bss_total_passed_failed]
    mov     ecx, tok_test_bss_total_passed_failed_len
    call    token_eq
    test    eax, eax
    jz      .data_total_passed_failed
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_total_passed_failed_layout
    jmp     .yes
.data_total_passed_failed:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_data_total_passed_failed]
    mov     ecx, tok_test_data_total_passed_failed_len
    call    token_eq
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_total_passed_failed_layout
    jmp     .yes
.bad:
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_test_exit_macro
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_exit]
    mov     ecx, tok_test_exit_len
    call    token_eq
    test    eax, eax
    jz      .no
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xb8
    call    append_text_byte
    mov     edi, 60
    call    append_text_u32
    mov     edi, 0xbf
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    call    emit_syscall
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_lea_rel_label
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_lea]
    mov     ecx, tok_lea_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdi
    pop     r11
    mov     r10d, 0x35
    jmp     .operand
.rdi:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx
    pop     r11
    mov     r10d, 0x3d
    jmp     .operand
.rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdx
    pop     r11
    mov     r10d, 0x0d
    jmp     .operand
.rdx:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .no
    mov     r10d, 0x15
.operand:
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_rel_label_value
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    mov     rax, [rel imm_u32_value]
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    mov     rdi, rax
    call    append_text_u32
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn emit_passed_failed_layout
    lea     r10, [rel tok_passed_sym]
    mov     r11d, tok_passed_sym_len
    call    add_current_label_const
    call    append_zero_qword
    lea     r10, [rel tok_failed_sym]
    mov     r11d, tok_failed_sym_len
    call    add_current_label_const
    jmp     append_zero_qword

er_fn emit_total_passed_layout
    lea     r10, [rel tok_total_sym]
    mov     r11d, tok_total_sym_len
    call    add_current_label_const
    call    append_zero_qword
    lea     r10, [rel tok_passed_sym]
    mov     r11d, tok_passed_sym_len
    call    add_current_label_const
    jmp     append_zero_qword

er_fn emit_total_passed_failed_layout
    call    emit_total_passed_layout
    lea     r10, [rel tok_failed_sym]
    mov     r11d, tok_failed_sym_len
    call    add_current_label_const
    jmp     append_zero_qword

er_fn add_current_label_const
    er_push rbx
    call    find_label_value
    test    eax, eax
    jnz     .done
    mov     rbx, [rel label_symbol_count]
    cmp     rbx, ER_ASM_LABEL_CAP
    jae     .bad
    mov     [rel label_symbol_ptr + rbx * 8], r10
    mov     [rel label_symbol_len + rbx * 8], r11
    mov     rax, [rel text_len]
    mov     [rel label_symbol_value + rbx * 8], rax
    inc     qword [rel label_symbol_count]
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx
    ret

er_fn append_zero_qword
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    xor     edi, edi
    jmp     append_text_byte

er_fn match_common_mov
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xfc
    call    append_text_byte
    jmp     .yes
.r8_rdi:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_r12
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .yes
.rsi_r12:
    pop     r14
    lea     rdi, [rel tok_r13]
    mov     esi, tok_r13_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_r12_after_r13
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf5
    call    append_text_byte
    jmp     .yes
.rsi_r12_after_r13:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
    call    expect_operand
    test    eax, eax
    jz      .rsi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xe6
    call    append_text_byte
    jmp     .yes
.rsi_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.rax_rdi:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdx_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .rax_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .yes
.rax_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.rdx_rsi:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdi_rsp
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .rdx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf2
    call    append_text_byte
    jmp     .yes
.rdx_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc2
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.rdi_rsp:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r12d_edi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rsp]
    mov     esi, tok_rsp_len
    call    expect_operand
    test    eax, eax
    jz      .rdi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xe7
    call    append_text_byte
    jmp     .yes
.rdi_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.r12d_edi:
    pop     r14
    lea     rdi, [rel tok_r12d]
    mov     esi, tok_r12d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .ebx_r8d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xfc
    call    append_text_byte
    jmp     .yes
.ebx_r8d:
    pop     r14
    lea     rdi, [rel tok_ebx]
    mov     esi, tok_ebx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8d_esi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc3
    call    append_text_byte
    jmp     .yes
.r8d_esi:
    pop     r14
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .yes
.al_imm:
    pop     r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dx_di
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .al_cl
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xb0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.al_cl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.dx_di:
    pop     r14
    lea     rdi, [rel tok_dx]
    mov     esi, tok_dx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edx_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_di]
    mov     esi, tok_di_len
    call    expect_operand
    test    eax, eax
    jz      .dx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xfa
    call    append_text_byte
    jmp     .yes
.dx_imm:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 0xffff
    ja      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0xba
    call    append_text_byte
    mov     rax, [rel imm_u32_value]
    mov     edi, eax
    call    append_text_byte
    shr     rax, 8
    mov     edi, eax
    call    append_text_byte
    jmp     .yes
.edx_imm:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r13d_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xba
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.r13d_imm:
    pop     r14
    lea     rdi, [rel tok_r13d]
    mov     esi, tok_r13d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edi_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0xbd
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.edi_imm:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xbf
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_more_runtime_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_movzx]
    mov     ecx, tok_movzx_len
    call    token_eq
    test    eax, eax
    jz      .cld
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_sil]
    mov     esi, tok_sil_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    jmp     .yes
.cld:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cld]
    mov     ecx, tok_cld_len
    call    token_eq
    test    eax, eax
    jz      .rep
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xfc
    call    append_text_byte
    jmp     .yes
.rep:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_rep]
    mov     ecx, tok_rep_len
    call    token_eq
    test    eax, eax
    jz      .test
    lea     rdi, [rel tok_stosq]
    mov     esi, tok_stosq_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .stosb
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xab
    call    append_text_byte
    jmp     .yes
.stosb:
    pop     r14
    lea     rdi, [rel tok_stosb]
    mov     esi, tok_stosb_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0xaa
    call    append_text_byte
    jmp     .yes
.test:
    call    match_more_test
    test    eax, eax
    jnz     .yes
    call    match_more_xor
    test    eax, eax
    jnz     .yes
    call    match_more_and
    test    eax, eax
    jnz     .yes
    xor     eax, eax
    ret
.bad:
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_more_test
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_more_xor
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.r8d:
    pop     r14
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x45
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_more_and
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_and]
    mov     ecx, tok_and_len
    call    token_eq
    test    eax, eax
    jz      .shr
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xe1
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.shr:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shr]
    mov     ecx, tok_shr_len
    call    token_eq
    test    eax, eax
    jz      .mov
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    mov     edi, 0xe9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.mov:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_r9
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.rcx_r9:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_r8
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.rax_r8:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.yes:
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_math_hash_mov
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_edi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .rax_imm64
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8b
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.rax_imm64:
    pop     r14
    call    expect_u64_operand
    test    eax, eax
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    jbe     .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
    jmp     .yes
.eax_edi:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdx_rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_instr_mode], 1
    jne     .bad
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_mov_eax_edi
    jmp     .yes
.rdx_rax:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_rdi_rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc2
    call    append_text_byte
    jmp     .yes
.mem_rdi_rax:
    pop     r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.r8_rsi:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_rdx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .r8_imm64
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .yes
.r8_imm64:
    pop     r14
    call    expect_u64_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
    jmp     .yes
.rcx_rdx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r10_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xd1
    call    append_text_byte
    jmp     .yes
.r10_rsi:
    pop     r14
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf2
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_math_hash_xor
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xd0
    call    append_text_byte
    jmp     .yes
.rcx_rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_math_hash_shift
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shl]
    mov     ecx, tok_shl_len
    call    token_eq
    test    eax, eax
    jz      .try_shr
    mov     r10d, 0xe2
    jmp     .operands
.try_shr:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shr]
    mov     ecx, tok_shr_len
    call    token_eq
    test    eax, eax
    jz      .bad
    mov     r10d, 0xea
.operands:
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_math_hash_test
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xd2
    call    append_text_byte
    jmp     .yes
.rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xf6
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_math_hash_cmp
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmp]
    mov     ecx, tok_cmp_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .r10
    call    expect_line_end
    test    eax, eax
    jz      .bad_pop
    pop     r11
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xf9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.r10:
    pop     r14
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xd1
    call    append_text_byte
    jmp     .yes
.bad_pop:
    pop     r11
.bad:
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_math_hash_arith
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_add]
    mov     ecx, tok_add_len
    call    token_eq
    test    eax, eax
    jz      .sub
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.sub:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_sub]
    mov     ecx, tok_sub_len
    call    token_eq
    test    eax, eax
    jz      .inc
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xe9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.inc:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_inc]
    mov     ecx, tok_inc_len
    call    token_eq
    test    eax, eax
    jz      .dec
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_rcx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.inc_rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.dec:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_dec]
    mov     ecx, tok_dec_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.bad:
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_math_hash_branch
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jz]
    mov     ecx, tok_jz_len
    call    token_eq
    test    eax, eax
    jz      .jb
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.jb:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jb]
    mov     ecx, tok_jb_len
    call    token_eq
    test    eax, eax
    jz      .jmp
    mov     edi, 0x72
    jmp     emit_short_branch_operand
.jmp:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jmp]
    mov     ecx, tok_jmp_len
    call    token_eq
    test    eax, eax
    jz      .bad
    mov     edi, 0xeb
    jmp     emit_short_branch_operand
.bad:
    xor     eax, eax
    ret

er_fn match_math_hash_crc32
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_crc32]
    mov     ecx, tok_crc32_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_qword]
    mov     esi, tok_qword_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf2
    call    append_text_byte
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0xf1
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    jmp     .yes
.eax:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dword]
    mov     esi, tok_dword_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .byte
    pop     r11
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf2
    call    append_text_byte
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0xf1
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    jmp     .yes
.byte:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf2
    call    append_text_byte
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    jmp     .yes
.bad:
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_math_hash_movzx
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_movzx]
    mov     ecx, tok_movzx_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x14
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_math_hash_mul
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mul]
    mov     ecx, tok_mul_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xf7
    call    append_text_byte
    mov     edi, 0xe0
    call    append_text_byte
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_cmp_dil_imm8
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmp]
    mov     ecx, tok_cmp_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_test_edi_edi
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_in_al_dx
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_in]
    mov     ecx, tok_in_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dx]
    mov     esi, tok_dx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_out_dx_al
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_out]
    mov     ecx, tok_out_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dx]
    mov     esi, tok_dx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_mov_eax_imm32
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

; match add/sub eax, imm8. r10d=0 for add, 1 for sub.
er_fn match_addsub_eax_imm8
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_add]
    mov     ecx, tok_add_len
    call    token_eq
    test    eax, eax
    jz      .try_sub
    xor     r10d, r10d
    jmp     .operands
.try_sub:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_sub]
    mov     ecx, tok_sub_len
    call    token_eq
    test    eax, eax
    jz      .bad
    mov     r10d, 1
.operands:
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_xor_eax_eax
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_ret_line
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_ret]
    mov     ecx, tok_ret_len
    call    token_eq
    test    eax, eax
    jnz     .line_end
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_ret]
    mov     ecx, tok_er_ret_len
    call    token_eq
    test    eax, eax
    jz      .bad
.line_end:
    call    expect_line_end
    ret
.bad:
    xor     eax, eax
    ret

er_fn append_text_byte
    mov     rax, [rel text_len]
    cmp     rax, ER_ASM_TEXT_CAP
    jae     .bad
    lea     rdx, [rel text_buf]
    mov     [rdx + rax], dil
    inc     qword [rel text_len]
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    ret

er_fn emit_mov_eax_imm32
    mov     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_mov_rax_imm32
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_xor_edi_edi
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xff
    jmp     append_text_byte

er_fn emit_xor_eax_eax
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc0
    jmp     append_text_byte

er_fn emit_mov_eax_edi
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf8
    jmp     append_text_byte

er_fn emit_add_eax_imm8
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_byte

er_fn emit_sub_eax_imm8
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xe8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_byte

er_fn emit_cmp_dil_imm8
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_byte

er_fn emit_jb_placeholder
    mov     edi, 0x72
    call    append_text_byte
    mov     rax, [rel text_len]
    mov     [rel branch1_patch_off], rax
    xor     edi, edi
    jmp     append_text_byte

er_fn emit_jnz_placeholder
    mov     edi, 0x75
    call    append_text_byte
    mov     rax, [rel text_len]
    mov     [rel branch1_patch_off], rax
    xor     edi, edi
    jmp     append_text_byte

er_fn emit_ja_placeholder
    mov     edi, 0x77
    call    append_text_byte
    mov     rax, [rel text_len]
    mov     [rel branch2_patch_off], rax
    xor     edi, edi
    jmp     append_text_byte

er_fn emit_mov_edi_imm32
    mov     edi, 0xbf
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_mov_rdi_imm32
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_syscall
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0x05
    jmp     append_text_byte

er_fn emit_ret
    mov     edi, 0xc3
    jmp     append_text_byte

er_fn emit_test_edi_edi
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xff
    jmp     append_text_byte

er_fn emit_in_al_dx
    mov     edi, 0xec
    jmp     append_text_byte

er_fn emit_out_dx_al
    mov     edi, 0xee
    jmp     append_text_byte

er_fn append_text_u32
    er_push rbx
    mov     rbx, rdi
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    er_pop  rbx
    ret

er_fn append_text_u64
    er_push rbx
    mov     rbx, rdi
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    shr     rbx, 8
    mov     edi, ebx
    call    append_text_byte
    er_pop  rbx
    ret

; append_text_bytes(rsi=buf, rcx=len).
er_fn append_text_bytes
    er_push rbx, r12
    mov     rbx, rsi
    mov     r12, rcx
.loop:
    test    r12, r12
    jz      .done
    movzx   edi, byte [rbx]
    call    append_text_byte
    inc     rbx
    dec     r12
    jmp     .loop
.done:
    er_pop  rbx, r12
    ret

er_fn patch_branches_to_current
    mov     rdi, [rel branch1_patch_off]
    call    patch_branch_to_current
    mov     rdi, [rel branch2_patch_off]
    jmp     patch_branch_to_current

er_fn patch_branch_to_current
    test    rdi, rdi
    jz      .done
    mov     rax, [rel text_len]
    sub     rax, rdi
    dec     rax
    cmp     rax, 127
    ja      .bad
    lea     rdx, [rel text_buf]
    mov     [rdx + rdi], al
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    ret

; emit_short_branch_operand(opcode=dil) -> eax=1/0.
er_fn emit_short_branch_operand
    er_push rbx, r12, r13
    mov     ebx, edi
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, ebx
    call    append_text_byte
    mov     rax, [rel text_len]
    mov     rbx, rax
    xor     edi, edi
    call    append_text_byte
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .pending
    mov     rax, rdx
    sub     rax, rbx
    dec     rax
    cmp     rax, -128
    jl      .bad
    cmp     rax, 127
    jg      .bad
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], al
    mov     eax, 1
    jmp     .done
.pending:
    mov     rax, [rel pending_branch_count]
    cmp     rax, ER_ASM_BRANCH_CAP
    jae     .bad
    mov     [rel pending_branch_ptr + rax * 8], r12
    mov     [rel pending_branch_len + rax * 8], r13
    mov     [rel pending_branch_off + rax * 8], rbx
    inc     qword [rel pending_branch_count]
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; expect_operand(token, len) -> eax=1/0.
er_fn expect_operand
    er_push rbx, r12, r13
    mov     rbx, rdi
    mov     r12, rsi
    call    skip_space_inline
    mov     r13, r14
    call    skip_operand_token
    mov     rdi, r13
    mov     rsi, r14
    sub     rsi, r13
    mov     rdx, rbx
    mov     rcx, r12
    call    token_eq
    er_pop  rbx, r12, r13
    ret

er_fn expect_mem_rdi_plus_rcx
    lea     rdi, [rel tok_mem_rdi_rcx]
    mov     esi, tok_mem_rdi_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx_close]
    mov     esi, tok_rcx_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

; expect_u32_operand() -> eax=1/0, imm_u32_value=value.
er_fn expect_u32_operand
    er_push rbx, r12, r13
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, ASCII_SQUOTE
    je      .char
    cmp     al, ASCII_0
    jb      .symbol
    cmp     al, ASCII_9
    ja      .symbol
    xor     ebx, ebx
    xor     r12d, r12d
    call    operand_has_hex_prefix
    test    eax, eax
    jnz     .hex_loop
.loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    cmp     al, ASCII_0
    jb      .finish
    cmp     al, ASCII_9
    ja      .finish
    sub     al, ASCII_0
    movzx   r13d, al
    cmp     rbx, U32_DIV10
    ja      .bad
    jne     .accumulate
    cmp     r13d, U32_LAST_DIGIT
    ja      .bad
.accumulate:
    imul    rbx, rbx, 10
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .loop
.finish:
    test    r12d, r12d
    jz      .bad
    mov     [rel imm_u32_value], rbx
    mov     eax, 1
    jmp     .done
.hex_loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    call    hex_digit_value
    cmp     eax, 16
    jae     .finish
    mov     r13d, eax
    cmp     rbx, U32_DIV16
    ja      .bad
    shl     rbx, 4
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .hex_loop
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret
.symbol:
    call    expect_equ_operand
    jmp     .done
.char:
    call    expect_char_operand
    jmp     .done

er_fn expect_imm8_operand
    call    expect_u32_operand
    test    eax, eax
    jz      .done
    cmp     qword [rel imm_u32_value], 255
    ja      .bad
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
.done:
    ret

; expect_u64_operand() -> eax=1/0, imm_u32_value=value.
er_fn expect_u64_operand
    er_push rbx, r12, r13
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    xor     ebx, ebx
    xor     r12d, r12d
    call    operand_has_hex_prefix
    test    eax, eax
    jnz     .hex_loop
.dec_loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    cmp     al, ASCII_0
    jb      .finish
    cmp     al, ASCII_9
    ja      .finish
    sub     al, ASCII_0
    movzx   r13d, al
    imul    rbx, rbx, 10
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .dec_loop
.hex_loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    call    hex_digit_value
    cmp     eax, 16
    jae     .finish
    mov     r13d, eax
    shl     rbx, 4
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .hex_loop
.finish:
    test    r12d, r12d
    jz      .bad
    mov     [rel imm_u32_value], rbx
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

er_fn expect_value_operand
    push    r14
    call    expect_u32_operand
    test    eax, eax
    jz      .symbol
    pop     r11
    mov     eax, 1
    ret
.symbol:
    pop     r14
    call    expect_symbol_value_operand
    ret

er_fn expect_symbol_value_operand
    er_push r10, r11
    call    skip_space_inline
    mov     r10, r14
    call    skip_operand_token
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    call    find_label_value
    test    eax, eax
    jz      .equ
    mov     [rel imm_u32_value], rdx
    mov     eax, 1
    jmp     .done
.equ:
    push    r14
    mov     r14, r10
    call    expect_equ_operand
    pop     r11
    test    eax, eax
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11
    ret

er_fn expect_rel_label_value
    er_push r10, r11
    call    skip_space_inline
    lea     rdi, [rel tok_rel_open]
    mov     esi, tok_rel_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    skip_space_inline
    mov     r10, r14
.name:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, ']'
    je      .name_done
    cmp     al, 10
    je      .bad
    cmp     al, ';'
    je      .bad
    inc     r14
    jmp     .name
.name_done:
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    inc     r14
    call    find_label_value
    test    eax, eax
    jz      .bad
    mov     [rel imm_u32_value], rdx
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11
    ret

er_fn expect_target_operand
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    mov     rax, r14
    call    skip_operand_token
    cmp     r14, rax
    je      .bad
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; expect_char_operand() -> eax=1/0, imm_u32_value=byte.
er_fn expect_char_operand
    inc     r14
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .bad
    movzx   edx, al
    inc     r14
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ASCII_SQUOTE
    jne     .bad
    inc     r14
    mov     [rel imm_u32_value], rdx
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; expect_equ_operand() -> eax=1/0, imm_u32_value=value.
er_fn expect_equ_operand
    er_push rbx, r12, r13
    mov     rbx, r14
    call    skip_operand_token
    mov     r12, r14
    sub     r12, rbx
    xor     r13d, r13d
.loop:
    cmp     r13, [rel equ_count]
    jae     .bad
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, [rel equ_name_ptr + r13 * 8]
    mov     rcx, [rel equ_name_len + r13 * 8]
    call    token_eq
    test    eax, eax
    jnz     .found
    inc     r13
    jmp     .loop
.found:
    mov     rax, [rel equ_value + r13 * 8]
    mov     [rel imm_u32_value], rax
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; operand_has_hex_prefix() -> eax=1/0; consumes 0x prefix when present.
er_fn operand_has_hex_prefix
    cmp     r14, r15
    jae     .no
    cmp     byte [r14], ASCII_0
    jne     .no
    lea     rax, [r14 + 1]
    cmp     rax, r15
    jae     .no
    movzx   eax, byte [r14 + 1]
    cmp     al, ASCII_x
    je      .yes
    cmp     al, ASCII_X
    jne     .no
.yes:
    add     r14, 2
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; hex_digit_value(ch=al) -> eax=value, or 16 when invalid.
er_fn hex_digit_value
    cmp     al, ASCII_0
    jb      .invalid
    cmp     al, ASCII_9
    jbe     .digit
    cmp     al, ASCII_A
    jb      .lower
    cmp     al, ASCII_F
    jbe     .upper_digit
.lower:
    cmp     al, ASCII_a
    jb      .invalid
    cmp     al, ASCII_f
    ja      .invalid
    sub     al, ASCII_a - 10
    movzx   eax, al
    ret
.upper_digit:
    sub     al, ASCII_A - 10
    movzx   eax, al
    ret
.digit:
    sub     al, ASCII_0
    movzx   eax, al
    ret
.invalid:
    mov     eax, 16
    ret

er_fn expect_comma
    call    skip_space_inline
    cmp     r14, r15
    jae     .no
    cmp     byte [r14], ','
    jne     .no
    inc     r14
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn expect_line_end
    call    skip_space_inline
    cmp     r14, r15
    jae     .yes
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .yes
    cmp     al, ';'
    je      .yes
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

; is_directive(token, len) -> eax=1/0
er_fn is_directive
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12, rsi
%macro CHECK_DIR 2
    mov     rdi, rbx
    mov     rsi, r12
    lea     rdx, [rel %1]
    mov     ecx, %2
    call    token_eq
    test    eax, eax
    jnz     .yes
%endmacro
    CHECK_DIR tok_section, tok_section_len
    CHECK_DIR tok_global, tok_global_len
    CHECK_DIR tok_extern, tok_extern_len
    CHECK_DIR tok_default, tok_default_len
    CHECK_DIR tok_bits, tok_bits_len
    CHECK_DIR tok_db, tok_db_len
    CHECK_DIR tok_dw, tok_dw_len
    CHECK_DIR tok_dd, tok_dd_len
    CHECK_DIR tok_dq, tok_dq_len
    CHECK_DIR tok_resb, tok_resb_len
    CHECK_DIR tok_resw, tok_resw_len
    CHECK_DIR tok_resd, tok_resd_len
    CHECK_DIR tok_resq, tok_resq_len
    CHECK_DIR tok_times, tok_times_len
    CHECK_DIR tok_align, tok_align_len
    CHECK_DIR tok_incbin, tok_incbin_len
    CHECK_DIR tok_equ, tok_equ_len
    xor     eax, eax
    jmp     .done
.yes:
    mov     eax, 1
.done:
    er_pop  rbx, r12
    ret

; token_eq(token, len, str, str_len) -> eax=1/0
er_fn token_eq
    cmp     rsi, rcx
    jne     .no
    xor     r8d, r8d
.loop:
    cmp     r8, rsi
    jae     .yes
    movzx   eax, byte [rdi + r8]
    movzx   r9d, byte [rdx + r8]
    cmp     al, 'A'
    jb      .cmp
    cmp     al, 'Z'
    ja      .cmp
    add     al, 32
.cmp:
    cmp     r9b, 'A'
    jb      .cmp_folded
    cmp     r9b, 'Z'
    ja      .cmp_folded
    add     r9b, 32
.cmp_folded:
    cmp     al, r9b
    jne     .no
    inc     r8
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn print_report
    lea     rdi, [rel key_magic]
    call    write_report_cstr
    lea     rdi, [rel key_lines]
    mov     rsi, [rel line_count]
    call    print_kv
    lea     rdi, [rel key_preproc]
    mov     rsi, [rel preproc_count]
    call    print_kv
    lea     rdi, [rel key_directives]
    mov     rsi, [rel directive_count]
    call    print_kv
    lea     rdi, [rel key_labels]
    mov     rsi, [rel label_count]
    call    print_kv
    lea     rdi, [rel key_instructions]
    mov     rsi, [rel instr_count]
    call    print_kv
    lea     rdi, [rel key_exit_step]
    mov     rsi, [rel exit_instr_step]
    call    print_kv
    lea     rdi, [rel key_exit_bad]
    mov     rsi, [rel exit_subset_bad]
    call    print_kv
    lea     rdi, [rel key_equ_seen]
    mov     rsi, [rel equ_count]
    call    print_kv
    ret

; print_kv(cstr, value)
er_fn print_kv
    er_push r12, r13
    mov     r12, rdi
    mov     r13, rsi
    mov     rdi, r12
    call    write_report_cstr
    lea     rdi, [rel tab_str]
    call    write_report_cstr
    mov     rdi, r13
    call    print_u64
    lea     rdi, [rel nl_str]
    call    write_report_cstr
    er_pop  r12, r13
    ret

er_fn print_u64
    lea     rsi, [rel num_buf + 31]
    mov     byte [rsi], 0
    mov     rax, rdi
    mov     ecx, 10
.loop:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    dec     rsi
    mov     [rsi], dl
    test    rax, rax
    jnz     .loop
    mov     rdi, rsi
    jmp     write_report_cstr

er_fn write_report_cstr
    mov     esi, [rel report_fd]
    jmp     write_cstr_fd

er_fn streq
    xor     ecx, ecx
.loop:
    movzx   eax, byte [rdi + rcx]
    movzx   edx, byte [rsi + rcx]
    cmp     al, dl
    jne     .no
    test    al, al
    jz      .yes
    inc     rcx
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn write_stderr
    mov     esi, STDERR_FD
    jmp     write_cstr_fd

; write_cstr_fd(cstr, fd)
er_fn write_cstr_fd
    er_push rbx, r12
    mov     r12, rdi
    xor     edx, edx
.len:
    cmp     byte [r12 + rdx], 0
    je      .write
    inc     rdx
    jmp     .len
.write:
    mov     ebx, esi
    mov     edi, ebx
    mov     rsi, r12
    mov     eax, SYS_write
    syscall
    er_pop  rbx, r12
    ret

er_fn exit_now
    mov     eax, SYS_exit_group
    syscall

SECTION .data
arg_parse_only: db "--parse-only", 0
arg_o: db "-o", 0
arg_f: db "-f", 0
arg_i: db "-I", 0
msg_usage: db "usage: er_asm --parse-only <source.asm> | -f <fmt> [-I path] [-d name] [-D name] -o <out> <source.asm>", 10, 0
msg_fail: db "er_asm: parse failed", 10, 0
msg_unsupported: db "er_asm: unsupported source shape", 10, 0
key_magic: db "er_asm_parse", 9, "1", 10, 0
key_lines: db "lines", 0
key_preproc: db "preproc", 0
key_directives: db "directives", 0
key_labels: db "labels", 0
key_instructions: db "instructions", 0
key_exit_step: db "exit_step", 0
key_exit_bad: db "exit_bad", 0
key_equ_seen: db "equ_seen", 0
tab_str: db 9, 0
nl_str: db 10, 0

tok_section: db "section"
tok_section_len equ $ - tok_section
tok_global: db "global"
tok_global_len equ $ - tok_global
tok_extern: db "extern"
tok_extern_len equ $ - tok_extern
tok_default: db "default"
tok_default_len equ $ - tok_default
tok_bits: db "[bits"
tok_bits_len equ $ - tok_bits
tok_db: db "db"
tok_db_len equ $ - tok_db
tok_dw: db "dw"
tok_dw_len equ $ - tok_dw
tok_dd: db "dd"
tok_dd_len equ $ - tok_dd
tok_dq: db "dq"
tok_dq_len equ $ - tok_dq
tok_resb: db "resb"
tok_resb_len equ $ - tok_resb
tok_resw: db "resw"
tok_resw_len equ $ - tok_resw
tok_resd: db "resd"
tok_resd_len equ $ - tok_resd
tok_resq: db "resq"
tok_resq_len equ $ - tok_resq
tok_times: db "times"
tok_times_len equ $ - tok_times
tok_align: db "align"
tok_align_len equ $ - tok_align
tok_incbin: db "incbin"
tok_incbin_len equ $ - tok_incbin
tok_equ: db "equ"
tok_equ_len equ $ - tok_equ
tok_percent_define: db "%define"
tok_percent_define_len equ $ - tok_percent_define
tok_percent_include: db "%include"
tok_percent_include_len equ $ - tok_percent_include
tok_x86_macros_inc: db "x86_64/macros.inc"
tok_x86_macros_inc_len equ $ - tok_x86_macros_inc
tok_test_macros_inc: db "test/test_macros.inc"
tok_test_macros_inc_len equ $ - tok_test_macros_inc
tok_er_fn: db "er_fn"
tok_er_fn_len equ $ - tok_er_fn
tok_er_ret: db "er_ret"
tok_er_ret_len equ $ - tok_er_ret
tok_er_frame_push: db "er_frame_push"
tok_er_frame_push_len equ $ - tok_er_frame_push
tok_er_frame_pop: db "er_frame_pop"
tok_er_frame_pop_len equ $ - tok_er_frame_pop
tok_er_push: db "er_push"
tok_er_push_len equ $ - tok_er_push
tok_er_pop: db "er_pop"
tok_er_pop_len equ $ - tok_er_pop
tok_test_bss_passed_failed: db "TEST_BSS_PASSED_FAILED"
tok_test_bss_passed_failed_len equ $ - tok_test_bss_passed_failed
tok_test_data_passed_failed: db "TEST_DATA_PASSED_FAILED"
tok_test_data_passed_failed_len equ $ - tok_test_data_passed_failed
tok_test_bss_total_passed: db "TEST_BSS_TOTAL_PASSED"
tok_test_bss_total_passed_len equ $ - tok_test_bss_total_passed
tok_test_bss_total_passed_failed: db "TEST_BSS_TOTAL_PASSED_FAILED"
tok_test_bss_total_passed_failed_len equ $ - tok_test_bss_total_passed_failed
tok_test_data_total_passed_failed: db "TEST_DATA_TOTAL_PASSED_FAILED"
tok_test_data_total_passed_failed_len equ $ - tok_test_data_total_passed_failed
tok_test_exit: db "TEST_EXIT"
tok_test_exit_len equ $ - tok_test_exit
tok_total_sym: db "total"
tok_total_sym_len equ $ - tok_total_sym
tok_passed_sym: db "passed"
tok_passed_sym_len equ $ - tok_passed_sym
tok_failed_sym: db "failed"
tok_failed_sym_len equ $ - tok_failed_sym
tok_mov: db "mov"
tok_mov_len equ $ - tok_mov
tok_lea: db "lea"
tok_lea_len equ $ - tok_lea
tok_xor: db "xor"
tok_xor_len equ $ - tok_xor
tok_and: db "and"
tok_and_len equ $ - tok_and
tok_cmp: db "cmp"
tok_cmp_len equ $ - tok_cmp
tok_add: db "add"
tok_add_len equ $ - tok_add
tok_sub: db "sub"
tok_sub_len equ $ - tok_sub
tok_shl: db "shl"
tok_shl_len equ $ - tok_shl
tok_shr: db "shr"
tok_shr_len equ $ - tok_shr
tok_test: db "test"
tok_test_len equ $ - tok_test
tok_inc: db "inc"
tok_inc_len equ $ - tok_inc
tok_dec: db "dec"
tok_dec_len equ $ - tok_dec
tok_cld: db "cld"
tok_cld_len equ $ - tok_cld
tok_rep: db "rep"
tok_rep_len equ $ - tok_rep
tok_stosq: db "stosq"
tok_stosq_len equ $ - tok_stosq
tok_stosb: db "stosb"
tok_stosb_len equ $ - tok_stosb
tok_in: db "in"
tok_in_len equ $ - tok_in
tok_out: db "out"
tok_out_len equ $ - tok_out
tok_crc32: db "crc32"
tok_crc32_len equ $ - tok_crc32
tok_movzx: db "movzx"
tok_movzx_len equ $ - tok_movzx
tok_mul: db "mul"
tok_mul_len equ $ - tok_mul
tok_push: db "push"
tok_push_len equ $ - tok_push
tok_pop: db "pop"
tok_pop_len equ $ - tok_pop
tok_jb: db "jb"
tok_jb_len equ $ - tok_jb
tok_ja: db "ja"
tok_ja_len equ $ - tok_ja
tok_jz: db "jz"
tok_jz_len equ $ - tok_jz
tok_jnz: db "jnz"
tok_jnz_len equ $ - tok_jnz
tok_jmp: db "jmp"
tok_jmp_len equ $ - tok_jmp
tok_syscall: db "syscall"
tok_syscall_len equ $ - tok_syscall
tok_ret: db "ret"
tok_ret_len equ $ - tok_ret
tok_eax: db "eax"
tok_eax_len equ $ - tok_eax
tok_ebx: db "ebx"
tok_ebx_len equ $ - tok_ebx
tok_ecx: db "ecx"
tok_ecx_len equ $ - tok_ecx
tok_edx: db "edx"
tok_edx_len equ $ - tok_edx
tok_esi: db "esi"
tok_esi_len equ $ - tok_esi
tok_edi: db "edi"
tok_edi_len equ $ - tok_edi
tok_rax: db "rax"
tok_rax_len equ $ - tok_rax
tok_rdi: db "rdi"
tok_rdi_len equ $ - tok_rdi
tok_rsi: db "rsi"
tok_rsi_len equ $ - tok_rsi
tok_rcx: db "rcx"
tok_rcx_len equ $ - tok_rcx
tok_rdx: db "rdx"
tok_rdx_len equ $ - tok_rdx
tok_rbx: db "rbx"
tok_rbx_len equ $ - tok_rbx
tok_rbp: db "rbp"
tok_rbp_len equ $ - tok_rbp
tok_rsp: db "rsp"
tok_rsp_len equ $ - tok_rsp
tok_r8: db "r8"
tok_r8_len equ $ - tok_r8
tok_r8d: db "r8d"
tok_r8d_len equ $ - tok_r8d
tok_r9: db "r9"
tok_r9_len equ $ - tok_r9
tok_r10: db "r10"
tok_r10_len equ $ - tok_r10
tok_r12: db "r12"
tok_r12_len equ $ - tok_r12
tok_r12d: db "r12d"
tok_r12d_len equ $ - tok_r12d
tok_r13: db "r13"
tok_r13_len equ $ - tok_r13
tok_r13d: db "r13d"
tok_r13d_len equ $ - tok_r13d
tok_r14: db "r14"
tok_r14_len equ $ - tok_r14
tok_r15: db "r15"
tok_r15_len equ $ - tok_r15
tok_dil: db "dil"
tok_dil_len equ $ - tok_dil
tok_al: db "al"
tok_al_len equ $ - tok_al
tok_cl: db "cl"
tok_cl_len equ $ - tok_cl
tok_sil: db "sil"
tok_sil_len equ $ - tok_sil
tok_dx: db "dx"
tok_dx_len equ $ - tok_dx
tok_di: db "di"
tok_di_len equ $ - tok_di
tok_qword: db "qword"
tok_qword_len equ $ - tok_qword
tok_dword: db "dword"
tok_dword_len equ $ - tok_dword
tok_byte: db "byte"
tok_byte_len equ $ - tok_byte
tok_mem_rdi: db "[rdi]"
tok_mem_rdi_len equ $ - tok_mem_rdi
tok_mem_r8: db "[r8]"
tok_mem_r8_len equ $ - tok_mem_r8
tok_mem_rdi_rcx: db "[rdi"
tok_mem_rdi_rcx_len equ $ - tok_mem_rdi_rcx
tok_plus: db "+"
tok_plus_len equ $ - tok_plus
tok_rcx_close: db "rcx]"
tok_rcx_close_len equ $ - tok_rcx_close
tok_rel_open: db "[rel"
tok_rel_open_len equ $ - tok_rel_open
align 8
exit_object_start:
    db 0x7f, "ELF", 2, 1, 1, 0
    dq 0
    dw 1
    dw 62
    dd 1
    dq 0
    dq 0
    dq ER_ASM_SHDR_OFF
    dd 0
    dw 64
    dw 0
    dw 0
    dw 64
    dw 5
    dw 4

    times ER_ASM_TEXT_CAP db 0

    times ER_ASM_SYMTAB_CAP db 0

    times ER_ASM_STRTAB_CAP db 0

    db 0, ".text", 0, ".symtab", 0, ".strtab", 0, ".shstrtab", 0
    times 7 db 0

    dd 0
    dd 0
    dq 0
    dq 0
    dq 0
    dq 0
    dd 0
    dd 0
    dq 0
    dq 0

    dd 1
    dd 1
    dq 6
    dq 0
    dq ER_ASM_TEXT_OFF
    dq 0
    dd 0
    dd 0
    dq 1
    dq 0

    dd 7
    dd 2
    dq 0
    dq 0
    dq ER_ASM_SYMTAB_OFF
    dq ER_ASM_SYMTAB_CAP
    dd 3
    dd 1
    dq 8
    dq 24

    dd 15
    dd 3
    dq 0
    dq 0
    dq ER_ASM_STRTAB_OFF
    dq ER_ASM_STRTAB_CAP
    dd 0
    dd 0
    dq 1
    dq 0

    dd 23
    dd 3
    dq 0
    dq 0
    dq ER_ASM_SHSTRTAB_OFF
    dq 33
    dd 0
    dd 0
    dq 1
    dq 0
exit_object_end:
