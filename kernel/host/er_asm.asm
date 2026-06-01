; EdgeRun owned assembler front-end - x86_64 Linux userspace assembly.
; Current milestone: parse source shape and emit one minimal ELF64 object subset.

%include "x86_64/macros.inc"

SYS_read        equ 0
SYS_write       equ 1
SYS_open        equ 2
SYS_exit_group  equ 231
STDOUT_FD       equ 1
STDERR_FD       equ 2
O_RDONLY        equ 0
O_WRONLY        equ 1
O_CREAT         equ 64
O_TRUNC         equ 512
FILE_MODE_0644  equ 420
ER_ASM_BUF_SIZE equ 1048576
ER_ASM_OBJ_SIZE equ 496
ER_ASM_TEXT_OFF equ 64
ER_ASM_TEXT_CAP equ 16
ER_ASM_SYM_SIZE_OFF equ 120
ER_ASM_TEXT_SH_SIZE_OFF equ 272
ER_ASM_EQU_CAP equ 8
ASCII_0 equ '0'
ASCII_9 equ '9'
ASCII_A equ 'A'
ASCII_F equ 'F'
ASCII_X equ 'X'
ASCII_a equ 'a'
ASCII_f equ 'f'
ASCII_x equ 'x'
U32_DIV10 equ 429496729
U32_LAST_DIGIT equ 5
U32_DIV16 equ 268435455

SECTION .bss
source_buf:     resb ER_ASM_BUF_SIZE
object_buf:     resb ER_ASM_OBJ_SIZE
text_buf:       resb ER_ASM_TEXT_CAP
output_path:    resq 1
source_path:    resq 1
report_fd:      resd 1
line_count:     resq 1
preproc_count:  resq 1
directive_count: resq 1
label_count:    resq 1
instr_count:    resq 1
exit_instr_step: resq 1
exit_subset_bad: resq 1
text_len:       resq 1
imm_u32_value:  resq 1
equ_name_ptr:   resq ER_ASM_EQU_CAP
equ_name_len:   resq ER_ASM_EQU_CAP
equ_value:      resq ER_ASM_EQU_CAP
equ_count:      resq 1
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
    jnz     .skip_next
    cmp     byte [r15], '-'
    jne     .source
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

; open_output(path) -> eax=fd or negative errno.
er_fn open_output
    mov     esi, O_WRONLY | O_CREAT | O_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    ret

; is_supported_exit_subset() -> eax=1/0.
er_fn is_supported_exit_subset
    cmp     qword [rel preproc_count], 0
    jne     .no
    cmp     qword [rel label_count], 1
    jne     .no
    cmp     qword [rel instr_count], 3
    jne     .no
    cmp     qword [rel exit_instr_step], 3
    jne     .no
    cmp     qword [rel exit_subset_bad], 0
    jne     .no
    cmp     qword [rel directive_count], 2
    jb      .no
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
    mov     [rel object_buf + ER_ASM_SYM_SIZE_OFF], rax
    mov     [rel object_buf + ER_ASM_TEXT_SH_SIZE_OFF], rax
    er_pop  rbx, r12, r13
    ret

; parse_file(path) -> eax=0/error
er_fn parse_file
    er_push rbx, r12, r13, r14, r15
    mov     r12, rdi
    mov     rdi, r12
    mov     esi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .bad
    mov     ebx, eax
    mov     edi, ebx
    lea     rsi, [rel source_buf]
    mov     edx, ER_ASM_BUF_SIZE
    mov     eax, SYS_read
    syscall
    test    rax, rax
    js      .bad
    cmp     rax, ER_ASM_BUF_SIZE
    jae     .bad
    lea     r14, [rel source_buf]
    lea     r15, [r14 + rax]
    call    scan_source
    xor     eax, eax
    jmp     .done
.bad:
    mov     eax, 1
.done:
    er_pop  rbx, r12, r13, r14, r15
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
    mov     rdi, r12
    mov     rsi, r13
    call    is_directive
    test    eax, eax
    jnz     .directive
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

; record_equ(name=r10, name_len=r11, r14=equ token).
er_fn record_equ
    er_push rbx, r10, r11
    call    skip_token
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    mov     rbx, [rel equ_count]
    cmp     rbx, ER_ASM_EQU_CAP
    jae     .bad
    mov     [rel equ_name_ptr + rbx * 8], r10
    mov     [rel equ_name_len + rbx * 8], r11
    mov     rax, [rel imm_u32_value]
    mov     [rel equ_value + rbx * 8], rax
    inc     qword [rel equ_count]
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r10, r11
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
    je      .xor_zero
    cmp     rbx, 2
    je      .syscall
    jmp     .bad
.mov_exit:
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
    test    eax, eax
    jz      .bad
    call    emit_mov_eax_imm32
    inc     qword [rel exit_instr_step]
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
    test    eax, eax
    jz      .bad
    call    emit_mov_edi_imm32
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
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r12, r13
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

er_fn emit_xor_edi_edi
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xff
    jmp     append_text_byte

er_fn emit_mov_edi_imm32
    mov     edi, 0xbf
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_syscall
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0x05
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
tok_mov: db "mov"
tok_mov_len equ $ - tok_mov
tok_xor: db "xor"
tok_xor_len equ $ - tok_xor
tok_syscall: db "syscall"
tok_syscall_len equ $ - tok_syscall
tok_eax: db "eax"
tok_eax_len equ $ - tok_eax
tok_edi: db "edi"
tok_edi_len equ $ - tok_edi
align 8
exit_object_start:
    db 0x7f, "ELF", 2, 1, 1, 0
    dq 0
    dw 1
    dw 62
    dd 1
    dq 0
    dq 0
    dq 176
    dd 0
    dw 64
    dw 0
    dw 0
    dw 64
    dw 5
    dw 4

    times ER_ASM_TEXT_CAP db 0

    dq 0
    dq 0
    dq 0
    dd 1
    db 0x10
    db 0
    dw 1
    dq 0
    dq 0

    db 0, "_start", 0
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
    dq 80
    dq 48
    dd 3
    dd 1
    dq 8
    dq 24

    dd 15
    dd 3
    dq 0
    dq 0
    dq 128
    dq 8
    dd 0
    dd 0
    dq 1
    dq 0

    dd 23
    dd 3
    dq 0
    dq 0
    dq 136
    dq 33
    dd 0
    dd 0
    dq 1
    dq 0
exit_object_end:
