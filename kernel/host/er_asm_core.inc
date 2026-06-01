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
    cmp     qword [rel text_len], 1
    jb      .no
    cmp     qword [rel pending_branch_count], 0
    jne     .no
    cmp     qword [rel pending_call_count], 0
    jne     .no
    cmp     qword [rel generic_instr_bad], 0
    jne     .no
    cmp     qword [rel generic_instr_mode], 1
    je      .yes
    cmp     qword [rel exit_subset_bad], 0
    jne     .no
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; emit_flat_binary(path) -> eax=0/error.
er_fn emit_flat_binary
    er_push rbx
    call    open_output
    test    eax, eax
    js      .bad
    mov     ebx, eax
    cmp     qword [rel exit_subset_bad], 0
    jne     .bad
    mov     edi, ebx
    lea     rsi, [rel text_buf]
    mov     rdx, [rel text_len]
    mov     eax, SYS_write
    syscall
    cmp     rax, [rel text_len]
    jne     .bad
    xor     eax, eax
    jmp     .done
.bad:
    mov     eax, 1
.done:
    er_pop  rbx
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
    call    patch_pending_calls_for_label
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
    je      .generic_instruction
    cmp     qword [rel exit_instr_step], 0
    jne     .exit_instruction
    cmp     qword [rel exit_subset_bad], 0
    jne     .exit_instruction
.try_real_instruction:
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
.exit_instruction:
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
    call    track_exit_instruction
    jmp     .instruction_done
.real_instruction_done:
    pop     r11
    mov     qword [rel generic_instr_mode], 1
    jmp     .instruction_done
.generic_instruction:
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
    mov     qword [rel generic_instr_bad], 1
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
    jz      .dw
    call    emit_db_directive
    jmp     .done
.dw:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_dw]
    mov     ecx, tok_dw_len
    call    token_eq
    test    eax, eax
    jz      .dd
    mov     r10d, 2
    call    emit_int_directive
    jmp     .done
.dd:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_dd]
    mov     ecx, tok_dd_len
    call    token_eq
    test    eax, eax
    jz      .dq
    mov     r10d, 4
    call    emit_int_directive
    jmp     .done
.dq:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_dq]
    mov     ecx, tok_dq_len
    call    token_eq
    test    eax, eax
    jz      .resb
    call    emit_dq_directive
    jmp     .done
.resb:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_resb]
    mov     ecx, tok_resb_len
    call    token_eq
    test    eax, eax
    jz      .resw
    mov     r10d, 1
    call    emit_res_directive
    jmp     .done
.resw:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_resw]
    mov     ecx, tok_resw_len
    call    token_eq
    test    eax, eax
    jz      .resd
    mov     r10d, 2
    call    emit_res_directive
    jmp     .done
.resd:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_resd]
    mov     ecx, tok_resd_len
    call    token_eq
    test    eax, eax
    jz      .resq
    mov     r10d, 4
    call    emit_res_directive
    jmp     .done
.resq:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_resq]
    mov     ecx, tok_resq_len
    call    token_eq
    test    eax, eax
    jz      .done
    mov     r10d, 8
    call    emit_res_directive
.done:
    er_pop  r12, r13
    ret

er_fn emit_res_directive
    er_push rbx, r12
    mov     r12, r10
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     rbx, [rel imm_u32_value]
    imul    rbx, r12
.loop:
    test    rbx, rbx
    jz      .done
    xor     edi, edi
    call    append_text_byte
    dec     rbx
    jmp     .loop
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  rbx, r12
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
    call    patch_near_branch_to_current
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

er_fn patch_pending_calls_for_label
    er_push rbx, r12, r13, r14, r15
    xor     ebx, ebx
.loop:
    cmp     rbx, [rel pending_call_count]
    jae     .done
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rel pending_call_ptr + rbx * 8]
    mov     rcx, [rel pending_call_len + rbx * 8]
    call    token_eq
    test    eax, eax
    jz      .next
    mov     rdi, [rel pending_call_off + rbx * 8]
    call    patch_call_to_current
    call    remove_pending_call_at
    jmp     .loop
.next:
    inc     rbx
    jmp     .loop
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

; remove_pending_call_at(index=rbx)
er_fn remove_pending_call_at
    mov     r14, rbx
.shift:
    inc     r14
    cmp     r14, [rel pending_call_count]
    jae     .finish
    mov     r15, [rel pending_call_ptr + r14 * 8]
    mov     [rel pending_call_ptr + r14 * 8 - 8], r15
    mov     r15, [rel pending_call_len + r14 * 8]
    mov     [rel pending_call_len + r14 * 8 - 8], r15
    mov     r15, [rel pending_call_off + r14 * 8]
    mov     [rel pending_call_off + r14 * 8 - 8], r15
    jmp     .shift
.finish:
    dec     qword [rel pending_call_count]
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
    push    r14
    call    expect_u32_operand
    test    eax, eax
    jz      .expr
    pop     r12
    call    expect_line_end
    test    eax, eax
    jz      .expr_from_saved
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.expr_from_saved:
    mov     r14, r12
    jmp     .expr_have_cursor
.expr:
    pop     r14
.expr_have_cursor:
    call    expect_equ_mul_operand
    test    eax, eax
    jz      .skip_unsupported
    call    expect_line_end
    test    eax, eax
    jz      .skip_unsupported
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.skip_unsupported:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .done
    inc     r14
    jmp     .skip_unsupported
.bad:
    mov     qword [rel exit_subset_bad], 1
.done:
    er_pop  r10, r11
    ret

; handle_preproc(r14=line cursor at %).
er_fn handle_preproc
    er_push r12, r13, r15
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
    jz      .macro
    cmp     qword [rel assemble_mode], 0
    je      .done
    call    record_include
    jmp     .done
.macro:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_percent_macro]
    mov     ecx, tok_percent_macro_len
    call    token_eq
    test    eax, eax
    jz      .ifdef
    lea     rdx, [rel tok_percent_endmacro]
    mov     ecx, tok_percent_endmacro_len
    call    skip_to_preproc_token
    jmp     .done
.ifdef:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_percent_ifdef]
    mov     ecx, tok_percent_ifdef_len
    call    token_eq
    test    eax, eax
    jz      .ifndef
    call    skip_undefined_ifdef
    jmp     .done
.ifndef:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_percent_ifndef]
    mov     ecx, tok_percent_ifndef_len
    call    token_eq
    test    eax, eax
    jz      .else
    jmp     .done
.else:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_percent_else]
    mov     ecx, tok_percent_else_len
    call    token_eq
    test    eax, eax
    jz      .done
    lea     rdx, [rel tok_percent_endif]
    mov     ecx, tok_percent_endif_len
    call    skip_to_preproc_token
.done:
    er_pop  r12, r13, r15
    ret

er_fn skip_undefined_ifdef
    er_push rbx
    lea     rdx, [rel tok_percent_else]
    mov     ecx, tok_percent_else_len
    call    skip_to_preproc_token
    cmp     r14, r15
    jae     .done
    mov     rbx, r14
    call    skip_space_inline
    mov     rdi, r14
    call    skip_token
    mov     rsi, r14
    sub     rsi, rdi
    lea     rdx, [rel tok_percent_else]
    mov     ecx, tok_percent_else_len
    call    token_eq
    test    eax, eax
    jnz     .done
    mov     r14, rbx
.done:
    er_pop  rbx
    ret

er_fn skip_to_preproc_token
    er_push rbx, r12, r13
    mov     r12, rdx
    mov     r13, rcx
.line:
    cmp     r14, r15
    jae     .done
    movzx   eax, byte [r14]
    inc     r14
    cmp     al, 10
    jne     .line
    mov     rbx, r14
    call    skip_space_inline
    cmp     r14, r15
    jae     .done
    cmp     byte [r14], '%'
    jne     .line
    mov     rdi, r14
    call    skip_token
    mov     rsi, r14
    sub     rsi, rdi
    mov     rdx, r12
    mov     rcx, r13
    call    token_eq
    test    eax, eax
    jnz     .found
    mov     r14, rbx
    jmp     .line
.found:
    mov     r14, rbx
.done:
    er_pop  rbx, r12, r13
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

er_fn emit_int_directive
    er_push rbx, r12
    mov     r12, r10
.next_value:
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     r12, 2
    jne     .dword
    cmp     qword [rel imm_u32_value], 65535
    ja      .bad
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    shr     rdi, 8
    call    append_text_byte
    jmp     .separator
.dword:
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    er_pop  rbx, r12
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
