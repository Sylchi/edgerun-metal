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
ER_ASM_OBJ_SIZE equ 1600
ER_ASM_TEXT_OFF equ 64
ER_ASM_TEXT_CAP equ 512
ER_ASM_SYMTAB_OFF equ 576
ER_ASM_SYMTAB_CAP equ 408
ER_ASM_SYMTAB_ENTRY_SIZE equ 24
ER_ASM_STRTAB_OFF equ 984
ER_ASM_STRTAB_CAP equ 256
ER_ASM_SHSTRTAB_OFF equ 1240
ER_ASM_SHDR_OFF equ 1280
ER_ASM_SYM_SIZE_OFF equ 616
ER_ASM_SYM_NAME_OFF equ 985
ER_ASM_SYM_NAME_CAP equ 30
ER_ASM_TEXT_SH_SIZE_OFF equ 1376
ER_ASM_SYMTAB_SH_SIZE_OFF equ 1440
ER_ASM_STRTAB_SH_SIZE_OFF equ 1504
ER_ASM_EQU_CAP equ 8
ER_ASM_INCLUDE_CAP equ 4
ER_ASM_GLOBAL_CAP equ 16
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
exit_subset_bad: resq 1
text_len:       resq 1
imm_u32_value:  resq 1
branch1_patch_off: resq 1
branch2_patch_off: resq 1
equ_name_ptr:   resq ER_ASM_EQU_CAP
equ_name_len:   resq ER_ASM_EQU_CAP
equ_value:      resq ER_ASM_EQU_CAP
equ_count:      resq 1
global_name_ptr: resq 1
global_name_len: resq 1
global_ptr:     resq ER_ASM_GLOBAL_CAP
global_len:     resq ER_ASM_GLOBAL_CAP
global_value:   resq ER_ASM_GLOBAL_CAP
global_name_off: resq ER_ASM_GLOBAL_CAP
global_count:   resq 1
pending_global_ptr: resq 1
pending_global_len: resq 1
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
    jb      .no
    cmp     qword [rel global_count], 1
    jb      .no
    cmp     qword [rel pending_global_ptr], 0
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
    call    record_global_directive
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
    call    track_exit_instruction
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

er_fn record_global_directive
    er_push r12, r13
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_global]
    mov     ecx, tok_global_len
    call    token_eq
    test    eax, eax
    jz      .done
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    cmp     r13, ER_ASM_SYM_NAME_CAP
    ja      .bad
    mov     [rel pending_global_ptr], r12
    mov     [rel pending_global_len], r13
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r12, r13
    ret

er_fn record_pending_global_label
    mov     r10, [rel pending_global_ptr]
    test    r10, r10
    jz      .done
    mov     r11, [rel pending_global_len]
    test    r11, r11
    jz      .done
    mov     rax, [rel text_len]
    call    add_global_symbol
    test    eax, eax
    jz      .bad
    mov     qword [rel pending_global_ptr], 0
    mov     qword [rel pending_global_len], 0
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
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
    jz      .bad
    call    emit_cmp_dil_imm8
    mov     qword [rel exit_instr_step], 20
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
    jz      .bad
    call    emit_ret
    mov     qword [rel exit_instr_step], 8
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
.mov_branch_true:
    call    match_mov_eax_imm32
    test    eax, eax
    jz      .bad
    call    emit_mov_eax_imm32
    mov     qword [rel exit_instr_step], 24
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
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r12, r13
    ret

er_fn handle_code_label
    cmp     qword [rel exit_instr_step], 25
    jne     .done
    call    patch_branches_to_current
    cmp     qword [rel exit_subset_bad], 0
    jne     .done
    mov     qword [rel exit_instr_step], 0
.done:
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

er_fn patch_branches_to_current
    mov     rdi, [rel branch1_patch_off]
    call    patch_branch_to_current
    mov     rdi, [rel branch2_patch_off]
    jmp     patch_branch_to_current

er_fn patch_branch_to_current
    test    rdi, rdi
    jz      .bad
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
tok_er_fn: db "er_fn"
tok_er_fn_len equ $ - tok_er_fn
tok_er_ret: db "er_ret"
tok_er_ret_len equ $ - tok_er_ret
tok_mov: db "mov"
tok_mov_len equ $ - tok_mov
tok_xor: db "xor"
tok_xor_len equ $ - tok_xor
tok_cmp: db "cmp"
tok_cmp_len equ $ - tok_cmp
tok_jb: db "jb"
tok_jb_len equ $ - tok_jb
tok_ja: db "ja"
tok_ja_len equ $ - tok_ja
tok_syscall: db "syscall"
tok_syscall_len equ $ - tok_syscall
tok_ret: db "ret"
tok_ret_len equ $ - tok_ret
tok_eax: db "eax"
tok_eax_len equ $ - tok_eax
tok_edi: db "edi"
tok_edi_len equ $ - tok_edi
tok_rax: db "rax"
tok_rax_len equ $ - tok_rax
tok_rdi: db "rdi"
tok_rdi_len equ $ - tok_rdi
tok_dil: db "dil"
tok_dil_len equ $ - tok_dil
align 8
exit_object_start:
    db 0x7f, "ELF", 2, 1, 1, 0
    dq 0
    dw 1
    dw 62
    dd 1
    dq 0
    dq 0
    dq 1280
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
    dq 64
    dq 0
    dd 0
    dd 0
    dq 1
    dq 0

    dd 7
    dd 2
    dq 0
    dq 0
    dq 576
    dq 408
    dd 3
    dd 1
    dq 8
    dq 24

    dd 15
    dd 3
    dq 0
    dq 0
    dq 984
    dq 256
    dd 0
    dd 0
    dq 1
    dq 0

    dd 23
    dd 3
    dq 0
    dq 0
    dq 1240
    dq 33
    dd 0
    dd 0
    dq 1
    dq 0
exit_object_end:
