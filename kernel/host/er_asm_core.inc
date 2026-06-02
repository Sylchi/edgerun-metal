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
    jnz     .format_next
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
.format_next:
    inc     r14
    cmp     r14, r12
    jae     .bad
    mov     r15, [r13 + r14 * 8]
    mov     rdi, r15
    lea     rsi, [rel arg_format_flat]
    call    streq
    test    eax, eax
    jz      .bad
    mov     qword [rel output_format], 1
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
    cmp     qword [rel output_format], 1
    jne     .bad
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
    er_ret_true
.bad:
    er_ret_false

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
    cmp     qword [rel pending_rel_count], 0
    jne     .no
    cmp     qword [rel generic_instr_bad], 0
    jne     .no
    cmp     qword [rel generic_instr_mode], 1
    je      .yes
    cmp     qword [rel exit_subset_bad], 0
    jne     .no
.yes:
    er_ret_true
.no:
    er_ret_false

; emit_flat_binary(path) -> eax=0/error.
er_fn emit_flat_binary
    er_push rbx
    call    open_output
    test    eax, eax
    js      .bad
    mov     ebx, eax
    cmp     qword [rel generic_instr_mode], 1
    je      .write
    cmp     qword [rel exit_subset_bad], 0
    jne     .bad
.write:
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
    mov     [rel source_body_len], rax
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
    mov     rdi, r12
    mov     rsi, r13
    call    normalize_erobj_source
    test    rax, rax
    js      .bad
    jmp     .done
.bad:
    mov     rax, -1
.done:
    er_pop  rbx, r12, r13
    ret

; normalize_erobj_source(buf, len) -> source len or -1.
; Plain source is returned unchanged. EROBJ001 bytes objects are validated and
; their body is copied down to the start of the same buffer.
er_fn normalize_erobj_source
    er_push rbx, r12, r13, r14, r15
    mov     r12, rdi
    mov     r13, rsi
    cmp     r13, 8
    jb      .plain
    mov     rax, [r12]
    mov     rcx, 0x3130304a424f5245
    cmp     rax, rcx
    jne     .plain
    cmp     r13, EROBJ_HEADER_SIZE
    jb      .bad
    cmp     word [r12 + 8], EROBJ_VERSION
    jne     .bad
    cmp     word [r12 + 10], EROBJ_KIND_BYTES
    jne     .bad
    cmp     dword [r12 + 12], 0
    jne     .bad
    cmp     word [r12 + 24], 0
    jne     .bad
    cmp     word [r12 + 26], 0
    jne     .bad
    cmp     dword [r12 + 28], 0
    jne     .bad
    mov     r14, [r12 + 32]
    cmp     [r12 + 16], r14
    jne     .bad
    mov     rax, r13
    sub     rax, EROBJ_HEADER_SIZE
    cmp     rax, r14
    jne     .bad
    lea     rbx, [r12 + 132]
    mov     ecx, 16
.reserved_loop:
    cmp     byte [rbx], 0
    jne     .bad
    inc     rbx
    loop    .reserved_loop
    mov     rdi, r12
    lea     rsi, [r12 + EROBJ_HEADER_SIZE]
    mov     rdx, r14
    call    erobj_copy_down
    mov     rax, r14
    jmp     .done
.plain:
    mov     rax, r13
    jmp     .done
.bad:
    mov     rax, -1
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

; erobj_copy_down(dst, src, len) handles overlapping downward copies.
er_fn erobj_copy_down
    test    rdx, rdx
    jz      .done
.loop:
    mov     al, [rsi]
    mov     [rdi], al
    inc     rdi
    inc     rsi
    dec     rdx
    jnz     .loop
.done:
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
    call    patch_pending_rels_for_label
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
    er_match_source_token_result tok_equ, tok_equ_len
    jz      .not_equ
    call    record_equ
    jmp     .directive
.not_equ:
    mov     r12, r10
    mov     r13, r11
    call    expand_macro_invocation
    test    eax, eax
    jnz     .skip_line
    cmp     qword [rel generic_instr_mode], 1
    je      .generic_instruction
    cmp     qword [rel exit_instr_step], 0
    jne     .exit_instruction
    cmp     qword [rel exit_subset_bad], 0
    jne     .exit_instruction
.try_real_instruction:
    push    qword [rel text_len]
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
    pop     rax
.exit_instruction:
    push    qword [rel text_len]
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
    pop     rax
    push    qword [rel text_len]
    call    track_exit_instruction
    pop     r10
    cmp     qword [rel exit_subset_bad], 0
    je      .instruction_done
    cmp     r10, 0
    jne     .instruction_done
    cmp     qword [rel text_len], r10
    jne     .instruction_done
    mov     qword [rel generic_instr_bad], 1
    jmp     .instruction_done
.real_instruction_done:
    pop     r11
    pop     r10
    cmp     qword [rel exit_subset_bad], 0
    je      .real_instruction_ok
    cmp     qword [rel text_len], r10
    jne     .real_instruction_ok
    mov     qword [rel generic_instr_bad], 1
.real_instruction_ok:
    mov     qword [rel generic_instr_mode], 1
    jmp     .instruction_done
.generic_instruction:
    push    qword [rel text_len]
    push    r14
    call    track_real_instruction
    test    eax, eax
    jnz     .real_instruction_done
    pop     r14
    pop     rax
    mov     qword [rel generic_instr_bad], 1
.instruction_done:
    inc     qword [rel instr_count]
    jmp     .skip_line
.directive:
    cmp     qword [rel exit_subset_bad], 0
    je      .directive_count
    cmp     qword [rel text_len], 0
    jne     .directive_count
    mov     qword [rel generic_instr_bad], 1
.directive_count:
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
    er_match_source_token_result tok_er_fn, tok_er_fn_len
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
    er_expect_line_end_result
    jz      .bad
    mov     r10, r12
    mov     r11, r13
    mov     rax, [rel text_len]
    call    add_global_symbol
    call    add_current_label_const
    call    patch_pending_branches_for_label
    call    patch_pending_calls_for_label
    call    patch_pending_rels_for_label
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
    er_match_source_token_result tok_global, tok_global_len
    jz      .bits
    call    record_global_operands
    jmp     .done
.bits:
    er_match_source_token_result tok_bits, tok_bits_len
    jz      .incbin
    call    emit_bits_directive
    jmp     .done
.incbin:
    er_match_source_token_result tok_incbin, tok_incbin_len
    jz      .db
    call    emit_incbin_directive
    jmp     .done
.db:
    er_match_source_token_result tok_db, tok_db_len
    jz      .dw
    call    emit_db_directive
    jmp     .done
.dw:
    er_match_source_token_result tok_dw, tok_dw_len
    jz      .dd
    mov     r10d, 2
    call    emit_int_directive
    jmp     .done
.dd:
    er_match_source_token_result tok_dd, tok_dd_len
    jz      .dq
    mov     r10d, 4
    call    emit_int_directive
    jmp     .done
.dq:
    er_match_source_token_result tok_dq, tok_dq_len
    jz      .resb
    call    emit_dq_directive
    jmp     .done
.resb:
    er_match_source_token_result tok_resb, tok_resb_len
    jz      .resw
    mov     r10d, 1
    call    emit_res_directive
    jmp     .done
.resw:
    er_match_source_token_result tok_resw, tok_resw_len
    jz      .resd
    mov     r10d, 2
    call    emit_res_directive
    jmp     .done
.resd:
    er_match_source_token_result tok_resd, tok_resd_len
    jz      .resq
    mov     r10d, 4
    call    emit_res_directive
    jmp     .done
.resq:
    er_match_source_token_result tok_resq, tok_resq_len
    jz      .done
    mov     r10d, 8
    call    emit_res_directive
.done:
    er_pop  r12, r13
    ret

er_fn emit_bits_directive
    er_expect_u32_result
    jz      .bad
    cmp     qword [rel imm_u32_value], 64
    jne     .bad
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    jne     .bad
    inc     r14
    er_expect_line_end_result
    jz      .bad
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    ret

er_fn emit_res_directive
    er_push rbx, r12
    mov     r12, r10
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    mov     rbx, [rel imm_u32_value]
    imul    rbx, r12
.loop:
    test    rbx, rbx
    jz      .done
    er_emit_zero_byte
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
    er_expect_line_end_result
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
    er_token_eq_result
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
    er_token_eq_result
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
    er_token_eq_result
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
    er_token_eq_result
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

er_fn patch_pending_rels_for_label
    er_push rbx, r12, r13, r14, r15
    xor     ebx, ebx
.loop:
    cmp     rbx, [rel pending_rel_count]
    jae     .done
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rel pending_rel_ptr + rbx * 8]
    mov     rcx, [rel pending_rel_len + rbx * 8]
    er_token_eq_result
    jz      .next
    mov     rdi, [rel pending_rel_off + rbx * 8]
    mov     rsi, [rel pending_rel_addend + rbx * 8]
    call    patch_rel32_to_current
    call    remove_pending_rel_at
    jmp     .loop
.next:
    inc     rbx
    jmp     .loop
.done:
    er_pop  rbx, r12, r13, r14, r15
    ret

er_fn remove_pending_rel_at
    mov     r14, rbx
.shift:
    inc     r14
    cmp     r14, [rel pending_rel_count]
    jae     .finish
    mov     r15, [rel pending_rel_ptr + r14 * 8]
    mov     [rel pending_rel_ptr + r14 * 8 - 8], r15
    mov     r15, [rel pending_rel_len + r14 * 8]
    mov     [rel pending_rel_len + r14 * 8 - 8], r15
    mov     r15, [rel pending_rel_off + r14 * 8]
    mov     [rel pending_rel_off + r14 * 8 - 8], r15
    mov     r15, [rel pending_rel_addend + r14 * 8]
    mov     [rel pending_rel_addend + r14 * 8 - 8], r15
    jmp     .shift
.finish:
    dec     qword [rel pending_rel_count]
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
    er_expect_u32_result
    jz      .expr
    pop     r12
    er_expect_line_end_result
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
    er_expect_line_end_result
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
    er_match_source_token_result tok_percent_define, tok_percent_define_len
    jz      .include
    call    record_define
    jmp     .done
.include:
    er_match_source_token_result tok_percent_include, tok_percent_include_len
    jz      .macro
    cmp     qword [rel assemble_mode], 0
    je      .done
    call    record_include
    jmp     .done
.macro:
    er_match_source_token_result tok_percent_macro, tok_percent_macro_len
    jz      .ifdef
    call    record_macro_definition
    jmp     .done
.ifdef:
    er_match_source_token_result tok_percent_ifdef, tok_percent_ifdef_len
    jz      .ifndef
    call    skip_undefined_ifdef
    jmp     .done
.ifndef:
    er_match_source_token_result tok_percent_ifndef, tok_percent_ifndef_len
    jz      .else
    jmp     .done
.else:
    er_match_source_token_result tok_percent_else, tok_percent_else_len
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
    er_token_eq_result
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
    er_token_eq_result
    jnz     .found
    mov     r14, rbx
    jmp     .line
.found:
    mov     r14, rbx
.done:
    er_pop  rbx, r12, r13
    ret

er_fn record_macro_definition
    er_push rbx, r10, r11, r12, r13, r15
    mov     rbx, [rel macro_count]
    cmp     rbx, ER_ASM_MACRO_CAP
    jae     .bad
    call    skip_space_inline
    mov     r10, r14
    call    skip_token
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    er_expect_u32_result
    jz      .bad
    mov     rax, [rel imm_u32_value]
    cmp     rax, ER_ASM_MACRO_ARG_CAP
    ja      .bad
    mov     [rel macro_name_ptr + rbx * 8], r10
    mov     [rel macro_name_len + rbx * 8], r11
    mov     [rel macro_min_arg_count + rbx * 8], rax
    mov     [rel macro_arg_count + rbx * 8], rax
    mov     qword [rel macro_variadic + rbx * 8], 0
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '-'
    jne     .header_eol
    inc     r14
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '*'
    jne     .bad
    inc     r14
    mov     qword [rel macro_arg_count + rbx * 8], ER_ASM_MACRO_ARG_CAP
    mov     qword [rel macro_variadic + rbx * 8], 1
.header_eol:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    inc     r14
    cmp     al, 10
    jne     .header_eol
    mov     r12, r14
.find_line:
    cmp     r14, r15
    jae     .bad
    mov     r13, r14
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '%'
    jne     .next_line
    mov     rdi, r14
    call    skip_token
    mov     rsi, r14
    sub     rsi, rdi
    lea     rdx, [rel tok_percent_endmacro]
    mov     ecx, tok_percent_endmacro_len
    er_token_eq_result
    jnz     .found
    mov     r14, r13
    call    skip_space_inline
    mov     rdi, r14
    call    skip_token
    mov     rsi, r14
    sub     rsi, rdi
    lea     rdx, [rel tok_percent_endm]
    mov     ecx, tok_percent_endm_len
    er_token_eq_result
    jnz     .found
    mov     r14, r13
.next_line:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    inc     r14
    cmp     al, 10
    jne     .next_line
    jmp     .find_line
.found:
    mov     [rel macro_body_ptr + rbx * 8], r12
    mov     rax, r13
    sub     rax, r12
    mov     [rel macro_body_len + rbx * 8], rax
    mov     r14, r13
    inc     qword [rel macro_count]
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11, r12, r13, r15
    ret

er_fn expand_macro_invocation
    er_push rbx, r10, r11, r12, r13, r14, r15
    xor     ebx, ebx
.find:
    cmp     rbx, [rel macro_count]
    jae     .no
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rel macro_name_ptr + rbx * 8]
    mov     rcx, [rel macro_name_len + rbx * 8]
    er_token_eq_result
    jnz     .found
    inc     rbx
    jmp     .find
.found:
    mov     rax, [rel macro_expand_depth]
    cmp     rax, ER_ASM_MACRO_DEPTH_CAP
    jae     .bad
    mov     r11, ER_ASM_MACRO_EXPAND_CAP
    mul     r11
    lea     r11, [rel macro_expand_buf]
    add     r11, rax
    mov     [rel macro_expand_base_ptr], r11
    lea     rax, [r11 + ER_ASM_MACRO_EXPAND_CAP]
    mov     [rel macro_expand_limit_ptr], rax
    inc     qword [rel macro_expand_depth]
    inc     qword [rel macro_invocation_seq]
    mov     rax, [rel macro_invocation_seq]
    mov     [rel macro_invocation_id], rax
    mov     r10, [rel macro_arg_count + rbx * 8]
    mov     [rel macro_arg_expected_count], r10
    mov     r10, [rel macro_min_arg_count + rbx * 8]
    mov     [rel macro_arg_min_active_count], r10
    mov     r10, [rel macro_variadic + rbx * 8]
    mov     [rel macro_arg_variadic_active], r10
    mov     r10, [rel macro_arg_expected_count]
    mov     [rel macro_arg_active_count], r10
    call    parse_macro_args
    test    eax, eax
    jz      .bad_depth
    mov     r12, [rel macro_body_ptr + rbx * 8]
    mov     r13, [rel macro_body_len + rbx * 8]
    call    build_macro_expansion
    test    eax, eax
    jz      .bad_depth
    mov     r14, [rel macro_expand_base_ptr]
    lea     r15, [r14 + rax]
    call    scan_source
    dec     qword [rel macro_expand_depth]
    mov     eax, 1
    jmp     .done
.bad_depth:
    dec     qword [rel macro_expand_depth]
.bad:
    mov     qword [rel generic_instr_bad], 1
    mov     eax, 1
    jmp     .done
.no:
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11, r12, r13, r14, r15
    ret

; parse_macro_args(r14=cursor after macro name) -> eax=1/0.
er_fn parse_macro_args
    er_push rbx, r12, r13
    xor     ebx, ebx
    call    skip_space_inline
    call    expect_line_end
    test    eax, eax
    jnz     .line_end
.arg_loop:
    cmp     rbx, [rel macro_arg_expected_count]
    jae     .bad
    call    skip_space_inline
    mov     r12, r14
    mov     r13, r14
.scan_arg:
    cmp     r14, r15
    jae     .arg_done
    movzx   eax, byte [r14]
    cmp     al, ','
    je      .arg_done
    cmp     al, 10
    je      .arg_done
    cmp     al, ';'
    je      .arg_done
    inc     r14
    mov     r13, r14
    jmp     .scan_arg
.arg_done:
    cmp     r13, r12
    jb      .bad
.trim:
    cmp     r13, r12
    jbe     .store
    movzx   eax, byte [r13 - 1]
    cmp     al, ' '
    jne     .store
    dec     r13
    jmp     .trim
.store:
    mov     [rel macro_arg_ptr + rbx * 8], r12
    mov     rax, r13
    sub     rax, r12
    mov     [rel macro_arg_len + rbx * 8], rax
    inc     rbx
    cmp     r14, r15
    jae     .check_end
    cmp     byte [r14], ','
    jne     .check_end
    inc     r14
    jmp     .arg_loop
.check_end:
    call    expect_line_end
    test    eax, eax
    jz      .bad
.validate:
    cmp     rbx, [rel macro_arg_min_active_count]
    jb      .bad
    cmp     qword [rel macro_arg_variadic_active], 0
    jne     .ok
    cmp     rbx, [rel macro_arg_expected_count]
    jne     .bad
.ok:
    mov     [rel macro_arg_active_count], rbx
    mov     eax, 1
    jmp     .done
.line_end:
    xor     ebx, ebx
    jmp     .validate
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; build_macro_expansion(r12=body ptr, r13=body len) -> eax=len or 0 on failure.
er_fn build_macro_expansion
    er_push rbx, r10, r11, r12, r13, r14, r15
    mov     r14, [rel macro_expand_base_ptr]
    xor     ebx, ebx
.copy:
    cmp     rbx, r13
    jae     .finish
    movzx   eax, byte [r12 + rbx]
    cmp     al, '%'
    jne     .copy_byte
    call    append_macro_rep_if_current
    cmp     eax, 1
    je      .rep_done
    cmp     eax, -1
    je      .bad
    mov     r10, rbx
    inc     r10
    cmp     r10, r13
    jae     .copy_byte
    movzx   eax, byte [r12 + r10]
    cmp     al, '%'
    je      .copy_local
    cmp     al, '0'
    je      .copy_arg_count
    cmp     al, '1'
    jb      .copy_percent
    cmp     al, '8'
    ja      .copy_percent
    sub     al, '1'
    movzx   r11d, al
    mov     r15, [rel macro_arg_len + r11 * 8]
    mov     r10, [rel macro_arg_ptr + r11 * 8]
.copy_arg:
    test    r15, r15
    jz      .arg_done
    movzx   eax, byte [r10]
    push    rax
    call    macro_expand_room
    test    eax, eax
    jz      .bad_pop
    pop     rax
    mov     [r14], al
    inc     r14
    inc     r10
    dec     r15
    jmp     .copy_arg
.arg_done:
    add     rbx, 2
    jmp     .copy
.copy_arg_count:
    mov     rdi, [rel macro_arg_active_count]
    call    append_macro_u64_value
    test    eax, eax
    jz      .bad
    add     rbx, 2
    jmp     .copy
.copy_local:
    mov     r10, rbx
    add     r10, 2
    mov     r11, r10
.local_scan:
    cmp     r11, r13
    jae     .local_done
    movzx   eax, byte [r12 + r11]
    cmp     al, '_'
    je      .local_next
    cmp     al, '0'
    jb      .local_done
    cmp     al, '9'
    jbe     .local_next
    cmp     al, 'A'
    jb      .local_done
    cmp     al, 'Z'
    jbe     .local_next
    cmp     al, 'a'
    jb      .local_done
    cmp     al, 'z'
    ja      .local_done
.local_next:
    inc     r11
    jmp     .local_scan
.local_done:
    sub     r11, r10
    test    r11, r11
    jz      .bad
    lea     r10, [r12 + r10]
    call    append_macro_local_label
    test    eax, eax
    jz      .bad
    add     rbx, 2
    add     rbx, r11
    jmp     .copy
.copy_percent:
    mov     eax, '%'
.copy_byte:
    push    rax
    call    macro_expand_room
    test    eax, eax
    jz      .bad_pop
    pop     rax
    mov     [r14], al
    inc     r14
    inc     rbx
    jmp     .copy
.rep_done:
    mov     rbx, rdx
    jmp     .copy
.finish:
    mov     rax, [rel macro_expand_base_ptr]
    mov     rdx, r14
    sub     rdx, rax
    mov     rax, rdx
    jmp     .done
.bad:
    xor     eax, eax
    jmp     .done
.bad_pop:
    pop     rax
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11, r12, r13, r14, r15
    ret

; append_macro_rep_if_current(body=r12, body_len=r13, index=rbx)
; returns eax=1 handled with rdx=new index, eax=0 not %rep, eax=-1 bad.
er_fn append_macro_rep_if_current
    er_push r8, r9, r10, r11, r15
    lea     rdi, [r12 + rbx]
    mov     rsi, tok_percent_rep_len
    lea     rdx, [rel tok_percent_rep]
    mov     ecx, tok_percent_rep_len
    call    token_eq
    test    eax, eax
    jz      .no
    mov     r15, rbx
    add     r15, tok_percent_rep_len
    call    parse_macro_rep_count
    test    eax, eax
    jz      .bad
    mov     r9, rdx                 ; repeat count
    call    macro_index_after_line
    test    eax, eax
    jz      .bad
    mov     r10, rdx                ; body start index
    mov     r15, r10
    call    find_macro_endrep
    test    eax, eax
    jz      .bad
    mov     r11, rdx                ; body end index
    mov     r8, rax                 ; index after %endrep line
.repeat:
    test    r9, r9
    jz      .handled
    lea     rdi, [r12 + r10]
    lea     rsi, [r12 + r11]
    push    r8
    push    r9
    call    append_macro_range_no_rep
    pop     r9
    pop     r8
    test    eax, eax
    jz      .bad
    dec     r9
    jmp     .repeat
.handled:
    mov     rdx, r8
    mov     eax, 1
    jmp     .done
.no:
    xor     eax, eax
    jmp     .done
.bad:
    mov     eax, -1
.done:
    er_pop  r8, r9, r10, r11, r15
    ret

; parse_macro_rep_count(r12=body, r13=len, r15=index after %rep) -> eax=1, rdx=count.
er_fn parse_macro_rep_count
    xor     edx, edx
.space:
    cmp     r15, r13
    jae     .bad
    movzx   eax, byte [r12 + r15]
    cmp     al, ' '
    je      .space_next
    cmp     al, 9
    jne     .value
.space_next:
    inc     r15
    jmp     .space
.value:
    cmp     al, '%'
    jne     .decimal
    inc     r15
    cmp     r15, r13
    jae     .bad
    cmp     byte [r12 + r15], '0'
    jne     .bad
    inc     r15
    mov     rdx, [rel macro_arg_active_count]
    jmp     .line_end
.decimal:
    cmp     al, '0'
    jb      .bad
    cmp     al, '9'
    ja      .bad
.digit:
    cmp     r15, r13
    jae     .line_end
    movzx   eax, byte [r12 + r15]
    cmp     al, '0'
    jb      .line_end
    cmp     al, '9'
    ja      .line_end
    imul    rdx, rdx, 10
    sub     al, '0'
    movzx   eax, al
    add     rdx, rax
    inc     r15
    jmp     .digit
.line_end:
    cmp     r15, r13
    jae     .yes
    movzx   eax, byte [r12 + r15]
    cmp     al, ' '
    je      .line_next
    cmp     al, 9
    je      .line_next
    cmp     al, 10
    je      .yes
    cmp     al, ';'
    je      .yes
    jmp     .bad
.line_next:
    inc     r15
    jmp     .line_end
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; macro_index_after_line(r12=body, r13=len, r15=index on current line) -> eax=1, rdx=next line index.
er_fn macro_index_after_line
.scan:
    cmp     r15, r13
    jae     .bad
    movzx   eax, byte [r12 + r15]
    inc     r15
    cmp     al, 10
    jne     .scan
    mov     rdx, r15
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; find_macro_endrep(r12=body, r13=len, r15=start index) -> eax=after line index, rdx=body end index.
er_fn find_macro_endrep
    er_push r8, r9, r10, r11
    xor     r9d, r9d
.line:
    cmp     r15, r13
    jae     .bad
    mov     r10, r15                ; line start
    mov     r11, r15
.skip_space:
    cmp     r11, r13
    jae     .bad
    movzx   eax, byte [r12 + r11]
    cmp     al, ' '
    je      .space_next
    cmp     al, 9
    jne     .check
.space_next:
    inc     r11
    jmp     .skip_space
.check:
    lea     rdi, [r12 + r11]
    mov     rsi, tok_percent_rep_len
    lea     rdx, [rel tok_percent_rep]
    mov     ecx, tok_percent_rep_len
    push    r9
    call    token_eq
    pop     r9
    test    eax, eax
    jnz     .nested_rep
    lea     rdi, [r12 + r11]
    mov     rsi, tok_percent_endrep_len
    lea     rdx, [rel tok_percent_endrep]
    mov     ecx, tok_percent_endrep_len
    push    r9
    call    token_eq
    pop     r9
    test    eax, eax
    jnz     .maybe_done
.next_line:
    cmp     r15, r13
    jae     .bad
    movzx   eax, byte [r12 + r15]
    inc     r15
    cmp     al, 10
    jne     .next_line
    jmp     .line
.nested_rep:
    inc     r9
    jmp     .next_line
.maybe_done:
    test    r9, r9
    jz      .found
    dec     r9
    jmp     .next_line
.found:
    mov     r8, r15
.end_line:
    cmp     r15, r13
    jae     .bad
    movzx   eax, byte [r12 + r15]
    inc     r15
    cmp     al, 10
    jne     .end_line
    mov     rax, r15
    mov     rdx, r10
    jmp     .done
.bad:
    xor     eax, eax
    xor     edx, edx
.done:
    er_pop  r8, r9, r10, r11
    ret

; append_macro_range_no_rep(rdi=start, rsi=end) -> eax=1/0. Handles args, %%locals, and %rotate.
er_fn append_macro_range_no_rep
    er_push rbx, r10, r11, r12, r13, r15
    mov     rbx, rdi
    mov     r13, rsi
.copy:
    cmp     rbx, r13
    jae     .yes
    movzx   eax, byte [rbx]
    cmp     al, '%'
    jne     .copy_byte
    mov     rdi, rbx
    mov     rsi, tok_percent_rotate_len
    lea     rdx, [rel tok_percent_rotate]
    mov     ecx, tok_percent_rotate_len
    call    token_eq
    test    eax, eax
    jnz     .rotate
    lea     r10, [rbx + 1]
    cmp     r10, r13
    jae     .copy_byte
    movzx   eax, byte [r10]
    cmp     al, '%'
    je      .copy_local
    cmp     al, '0'
    je      .copy_arg_count
    cmp     al, '1'
    jb      .copy_percent
    cmp     al, '8'
    ja      .copy_percent
    sub     al, '1'
    movzx   r11d, al
    cmp     r11, [rel macro_arg_active_count]
    jae     .bad
    mov     r15, [rel macro_arg_len + r11 * 8]
    mov     r10, [rel macro_arg_ptr + r11 * 8]
.copy_arg:
    test    r15, r15
    jz      .arg_done
    movzx   eax, byte [r10]
    push    rax
    call    macro_expand_room
    test    eax, eax
    jz      .bad_pop
    pop     rax
    mov     [r14], al
    inc     r14
    inc     r10
    dec     r15
    jmp     .copy_arg
.arg_done:
    add     rbx, 2
    jmp     .copy
.copy_arg_count:
    mov     rdi, [rel macro_arg_active_count]
    call    append_macro_u64_value
    test    eax, eax
    jz      .bad
    add     rbx, 2
    jmp     .copy
.copy_local:
    lea     r10, [rbx + 2]
    mov     r11, r10
.local_scan:
    cmp     r11, r13
    jae     .local_done
    movzx   eax, byte [r11]
    cmp     al, '_'
    je      .local_next
    cmp     al, '0'
    jb      .local_done
    cmp     al, '9'
    jbe     .local_next
    cmp     al, 'A'
    jb      .local_done
    cmp     al, 'Z'
    jbe     .local_next
    cmp     al, 'a'
    jb      .local_done
    cmp     al, 'z'
    ja      .local_done
.local_next:
    inc     r11
    jmp     .local_scan
.local_done:
    sub     r11, r10
    test    r11, r11
    jz      .bad
    call    append_macro_local_label
    test    eax, eax
    jz      .bad
    add     rbx, 2
    add     rbx, r11
    jmp     .copy
.rotate:
    add     rbx, tok_percent_rotate_len
    call    parse_macro_rotate_count_from_ptr
    test    eax, eax
    jz      .bad
    mov     rdi, rdx
    call    macro_rotate_args
    test    eax, eax
    jz      .bad
.rotate_skip:
    cmp     rbx, r13
    jae     .yes
    movzx   eax, byte [rbx]
    inc     rbx
    cmp     al, 10
    jne     .rotate_skip
    jmp     .copy
.copy_percent:
    mov     eax, '%'
.copy_byte:
    push    rax
    call    macro_expand_room
    test    eax, eax
    jz      .bad_pop
    pop     rax
    mov     [r14], al
    inc     r14
    inc     rbx
    jmp     .copy
.yes:
    mov     eax, 1
    jmp     .done
.bad_pop:
    pop     rax
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11, r12, r13, r15
    ret

; parse_macro_rotate_count_from_ptr(rbx points after %rotate, r13=end) -> eax=1, rdx=signed count.
er_fn parse_macro_rotate_count_from_ptr
    xor     edx, edx
    xor     r12d, r12d
.space:
    cmp     rbx, r13
    jae     .bad
    movzx   eax, byte [rbx]
    cmp     al, ' '
    je      .space_next
    cmp     al, 9
    jne     .sign
.space_next:
    inc     rbx
    jmp     .space
.sign:
    cmp     al, '-'
    jne     .digit_start
    mov     r12d, 1
    inc     rbx
.digit_start:
    cmp     rbx, r13
    jae     .bad
    movzx   eax, byte [rbx]
    cmp     al, '0'
    jb      .bad
    cmp     al, '9'
    ja      .bad
.digit:
    cmp     rbx, r13
    jae     .finish
    movzx   eax, byte [rbx]
    cmp     al, '0'
    jb      .finish
    cmp     al, '9'
    ja      .finish
    imul    rdx, rdx, 10
    sub     al, '0'
    movzx   eax, al
    add     rdx, rax
    inc     rbx
    jmp     .digit
.finish:
    test    r12d, r12d
    jz      .yes
    neg     rdx
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; macro_rotate_args(rdi=signed count) -> eax=1/0.
er_fn macro_rotate_args
    test    rdi, rdi
    jz      .yes
    cmp     qword [rel macro_arg_active_count], 0
    je      .yes
    cmp     rdi, 0
    jl      .right_loop
.left_loop:
    test    rdi, rdi
    jz      .yes
    call    macro_rotate_left_once
    dec     rdi
    jmp     .left_loop
.right_loop:
    test    rdi, rdi
    jz      .yes
    call    macro_rotate_right_once
    inc     rdi
    jmp     .right_loop
.yes:
    mov     eax, 1
    ret

er_fn macro_rotate_left_once
    er_push rbx, r10, r11
    mov     rbx, [rel macro_arg_active_count]
    cmp     rbx, 1
    jbe     .done
    mov     r10, [rel macro_arg_ptr]
    mov     r11, [rel macro_arg_len]
    xor     eax, eax
.shift:
    inc     rax
    cmp     rax, rbx
    jae     .store_last
    mov     rdx, [rel macro_arg_ptr + rax * 8]
    mov     [rel macro_arg_ptr + rax * 8 - 8], rdx
    mov     rdx, [rel macro_arg_len + rax * 8]
    mov     [rel macro_arg_len + rax * 8 - 8], rdx
    jmp     .shift
.store_last:
    dec     rbx
    mov     [rel macro_arg_ptr + rbx * 8], r10
    mov     [rel macro_arg_len + rbx * 8], r11
.done:
    er_pop  rbx, r10, r11
    ret

er_fn macro_rotate_right_once
    er_push rbx, r10, r11
    mov     rbx, [rel macro_arg_active_count]
    cmp     rbx, 1
    jbe     .done
    dec     rbx
    mov     r10, [rel macro_arg_ptr + rbx * 8]
    mov     r11, [rel macro_arg_len + rbx * 8]
.shift:
    test    rbx, rbx
    jz      .store_first
    mov     rdx, [rel macro_arg_ptr + rbx * 8 - 8]
    mov     [rel macro_arg_ptr + rbx * 8], rdx
    mov     rdx, [rel macro_arg_len + rbx * 8 - 8]
    mov     [rel macro_arg_len + rbx * 8], rdx
    dec     rbx
    jmp     .shift
.store_first:
    mov     [rel macro_arg_ptr], r10
    mov     [rel macro_arg_len], r11
.done:
    er_pop  rbx, r10, r11
    ret

er_fn macro_expand_room
    mov     rax, [rel macro_expand_limit_ptr]
    cmp     r14, rax
    jae     .no
    er_ret_true
.no:
    er_ret_false

; append_macro_local_label(r10=name ptr, r11=name len, r14=out) -> eax=1/0.
er_fn append_macro_local_label
    er_push rbx, r10, r11, r12, r13, r15
    mov     r12, r10
    mov     r13, r11
    mov     eax, '_'
    call    append_macro_expand_byte
    test    eax, eax
    jz      .bad
    mov     eax, '_'
    call    append_macro_expand_byte
    test    eax, eax
    jz      .bad
    mov     eax, 'm'
    call    append_macro_expand_byte
    test    eax, eax
    jz      .bad
    mov     rdi, [rel macro_invocation_id]
    call    append_macro_u64_value
    test    eax, eax
    jz      .bad
    mov     eax, '_'
    call    append_macro_expand_byte
    test    eax, eax
    jz      .bad
.name_copy:
    test    r13, r13
    jz      .yes
    movzx   eax, byte [r12]
    call    append_macro_expand_byte
    test    eax, eax
    jz      .bad
    inc     r12
    dec     r13
    jmp     .name_copy
.yes:
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11, r12, r13, r15
    ret

; append_macro_u64_value(rdi=value, r14=out) -> eax=1/0.
er_fn append_macro_u64_value
    er_push rbx, r12, r15
    lea     r15, [rel num_buf + 31]
    mov     rax, rdi
    mov     ecx, 10
.num_loop:
    xor     edx, edx
    div     rcx
    add     dl, '0'
    dec     r15
    mov     [r15], dl
    test    rax, rax
    jnz     .num_loop
.num_copy:
    lea     rbx, [rel num_buf + 31]
    cmp     r15, rbx
    jae     .yes
    movzx   eax, byte [r15]
    call    append_macro_expand_byte
    test    eax, eax
    jz      .bad
    inc     r15
    jmp     .num_copy
.yes:
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r15
    ret

; append_macro_expand_byte(al=byte, r14=out) -> eax=1/0, advances r14.
er_fn append_macro_expand_byte
    push    rax
    call    macro_expand_room
    test    eax, eax
    jz      .bad
    pop     rax
    mov     [r14], al
    inc     r14
    er_ret_true
.bad:
    pop     rax
    er_ret_false

er_fn record_define
    er_push r10, r11
    call    skip_space_inline
    mov     r10, r14
    call    skip_token
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    er_expect_line_end_result
    jz      .has_value
    mov     qword [rel imm_u32_value], 1
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.has_value:
    er_expect_u32_result
    jz      .skip_unsupported
    er_expect_line_end_result
    jz      .maybe_product
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.maybe_product:
    mov     rax, [rel imm_u32_value]
    push    rax
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad_pop
    cmp     byte [r14], '*'
    jne     .bad_pop
    inc     r14
    er_expect_u32_result
    jz      .bad_pop
    pop     rax
    imul    rax, [rel imm_u32_value]
    mov     [rel imm_u32_value], rax
    er_expect_line_end_result
    jz      .bad
    call    add_equ_symbol
    test    eax, eax
    jz      .bad
    jmp     .done
.bad_pop:
    pop     rax
    jmp     .bad
.skip_unsupported:
    er_expect_line_end_result
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
    er_expect_line_end_result
    jz      .bad
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_x86_macros_inc]
    mov     ecx, tok_x86_macros_inc_len
    er_token_eq_result
    jnz     .done
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_test_macros_inc]
    mov     ecx, tok_test_macros_inc_len
    er_token_eq_result
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
    er_expect_line_end_result
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
    er_emit_text_bytes eax
    inc     r14
    jmp     .string_loop
.string_done:
    inc     r14
    jmp     .separator
.number:
    er_expect_u32_result
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .bad
    er_emit_imm_byte_value
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
    er_expect_line_end_result
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
    er_expect_u32_result
    jz      .bad
    cmp     r12, 2
    jne     .dword
    cmp     qword [rel imm_u32_value], 65535
    ja      .bad
    er_emit_imm_byte_value
    mov     rdi, [rel imm_u32_value]
    shr     rdi, 8
    call    append_text_byte
    jmp     .separator
.dword:
    er_emit_imm_u32_value
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
    er_expect_line_end_result
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
    er_expect_line_end_result
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
    er_ret_true
.bad:
    er_ret_false

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
    er_token_eq_result
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
