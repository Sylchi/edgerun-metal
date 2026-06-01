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
    pop     rax
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
    pop     rax
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
    pop     rax
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
    call    match_ret_line
    test    eax, eax
    jz      .er_ok
    call    emit_ret
    mov     eax, 1
    ret
.er_ok:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_ok]
    mov     ecx, tok_er_ok_len
    call    token_eq
    test    eax, eax
    jz      .er_err
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xd2
    call    append_text_byte
    mov     eax, 1
    ret
.er_err:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_err]
    mov     ecx, tok_er_err_len
    call    token_eq
    test    eax, eax
    jz      .check_zero
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
    mov     eax, 1
    ret
.check_zero:
    call    match_check_zero_macro
    test    eax, eax
    jz      .test_same
    mov     eax, 1
    ret
.test_same:
    call    match_direct_test_same
    test    eax, eax
    jz      .acpi_ops
    mov     eax, 1
    ret
.acpi_ops:
    call    match_acpi_checksum_ops
    test    eax, eax
    jz      .mov
    mov     eax, 1
    ret
.mov:
    push    r14
    call    match_rel_mem_ops
    test    eax, eax
    jz      .mov_common
    pop     rax
    mov     eax, 1
    ret
.mov_common:
    pop     r14
    push    r14
    call    match_cmos_time_ops
    test    eax, eax
    jz      .mov_cmos_arith
    pop     r11
    mov     eax, 1
    ret
.mov_cmos_arith:
    pop     r14
    push    r14
    call    match_cmos_arith_ops
    test    eax, eax
    jz      .mov_byte_reg
    pop     r11
    mov     eax, 1
    ret
.mov_byte_reg:
    pop     r14
    push    r14
    call    match_byte_reg_ops
    test    eax, eax
    jz      .mov_sized_mem
    pop     r11
    mov     eax, 1
    ret
.mov_sized_mem:
    pop     r14
    push    r14
    call    match_sized_mem_imm
    test    eax, eax
    jz      .mov_reg_moves
    pop     r11
    mov     eax, 1
    ret
.mov_reg_moves:
    pop     r14
    push    r14
    call    match_simple_reg_movs
    test    eax, eax
    jz      .mov_existing
    pop     r11
    mov     eax, 1
    ret
.mov_existing:
    pop     r14
    push    r14
    call    match_common_mov
    test    eax, eax
    jz      .math_mov
    pop     r11
    mov     eax, 1
    ret
.math_mov:
    pop     r14
.math_mov_try_more:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .math_mov_try_more_runtime
    push    r14
    jmp     .math_mov_after_more
.math_mov_try_more_runtime:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shl]
    mov     ecx, tok_shl_len
    call    token_eq
    test    eax, eax
    jnz     .math_mov_skip_more_runtime
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shr]
    mov     ecx, tok_shr_len
    call    token_eq
    test    eax, eax
    jnz     .math_mov_skip_more_runtime
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jnz     .math_mov_skip_more_runtime
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .math_mov_after_more
    pop     r11
    mov     eax, 1
    ret
.math_mov_skip_more_runtime:
    push    r14
    jmp     .math_mov_after_more
.math_mov_after_more:
    pop     r14
    push    r14
    call    match_mov_eax_imm32
    test    eax, eax
    jz      .math_mov_hash
    pop     r11
    call    emit_mov_eax_imm32
    mov     eax, 1
    ret
.math_mov_hash:
    pop     r14
    push    r14
    call    match_math_hash_mov
    test    eax, eax
    jnz     .math_mov_hash_done
    pop     r14
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .xor
    call    match_math_int_ops
    test    eax, eax
    jnz     .math_mov_done
    xor     eax, eax
    ret
.math_mov_hash_done:
    pop     r11
.math_mov_done:
    mov     eax, 1
    ret
.xor:
    push    r14
    call    match_xor_eax_eax
    test    eax, eax
    jz      .xor_more
    pop     r11
    call    emit_xor_eax_eax
    mov     eax, 1
    ret
.xor_more:
    pop     r14
    push    r14
    call    match_xor_edi_edi
    test    eax, eax
    jz      .xor_more_runtime
    pop     r11
    call    emit_xor_edi_edi
    mov     eax, 1
    ret
.xor_more_runtime:
    pop     r14
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shl]
    mov     ecx, tok_shl_len
    call    token_eq
    test    eax, eax
    jnz     .xor_more_runtime_skip
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shr]
    mov     ecx, tok_shr_len
    call    token_eq
    test    eax, eax
    jnz     .xor_more_runtime_skip
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jnz     .xor_more_runtime_skip
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .shift
    pop     r11
    mov     eax, 1
    ret
.xor_more_runtime_skip:
    push    r14
    jmp     .shift
.shift:
    pop     r14
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jnz     .test
    push    r14
    call    match_math_hash_xor
    test    eax, eax
    jz      .shift_int_ops
    pop     r11
    mov     eax, 1
    ret
.shift_int_ops:
    pop     r14
    call    match_math_int_ops
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
    jz      .test_int
    mov     eax, 1
    ret
.test_int:
    call    match_math_int_ops
    test    eax, eax
    jz      .cmp
    mov     eax, 1
    ret
.cmp:
    push    r14
    call    match_more_byte_arith
    test    eax, eax
    jz      .cmp_math
    pop     r11
    mov     eax, 1
    ret
.cmp_math:
    pop     r14
    call    match_math_hash_cmp
    test    eax, eax
    jz      .arith
    mov     eax, 1
    ret
.arith:
    push    r14
    call    match_more_byte_arith
    test    eax, eax
    jz      .arith_more
    pop     r11
    mov     eax, 1
    ret
.arith_more:
    pop     r14
    push    r14
    call    match_more_unary
    test    eax, eax
    jz      .arith_math
    pop     r11
    mov     eax, 1
    ret
.arith_math:
    pop     r14
    push    r14
    call    match_math_hash_arith
    test    eax, eax
    jz      .arith_int
    pop     r11
    mov     eax, 1
    ret
.arith_int:
    pop     r14
    call    match_math_int_ops
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
    jz      .int_ops
    mov     eax, 1
    ret
.int_ops:
    call    match_math_int_ops
    test    eax, eax
    jz      .mul
    mov     eax, 1
    ret
.mul:
    call    match_math_hash_mul
    test    eax, eax
    jz      .call
    mov     eax, 1
    ret
.call:
    call    match_call_label
    test    eax, eax
    jz      .portio
    mov     eax, 1
    ret
.portio:
    call    match_in_al_dx
    test    eax, eax
    jz      .out_dx_al
    call    emit_in_al_dx
    mov     eax, 1
    ret
.out_dx_al:
    call    match_out_dx_al
    test    eax, eax
    jz      .syscall
    call    emit_out_dx_al
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
    jz      .lea_runtime
    mov     eax, 1
    ret
.lea_runtime:
    call    match_lea_runtime
    test    eax, eax
    jz      .test_exit
    mov     eax, 1
    ret
.test_exit:
    call    match_cmos_macros
    test    eax, eax
    jz      .test_exit_total
    mov     eax, 1
    ret
.test_exit_total:
    call    match_test_exit_passed_total_macro
    test    eax, eax
    jz      .cmp_below
    mov     eax, 1
    ret
.cmp_below:
    call    match_cmp_below_macro
    test    eax, eax
    jz      .test_call_eax
    mov     eax, 1
    ret
.test_call_eax:
    call    match_test_call_eax_macro
    test    eax, eax
    jz      .test_exit_real
    mov     eax, 1
    ret
.test_exit_real:
    call    match_test_exit_macro
    test    eax, eax
    jz      .no
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_acpi_checksum_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_movzx]
    mov     ecx, tok_movzx_len
    call    token_eq
    test    eax, eax
    jz      .add
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_word
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x14
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.movzx_eax_word:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_al
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_word]
    mov     esi, tok_word_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_mem_ebda_seg_ptr]
    mov     esi, tok_mem_ebda_seg_ptr_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb7
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x25
    call    append_text_byte
    mov     edi, 0x40e
    call    append_text_u32
    jmp     .yes
.movzx_eax_al:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_mem_edi
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.add:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_add]
    mov     ecx, tok_add_len
    call    token_eq
    test    eax, eax
    jz      .shl
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_edi_imm
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x01
    call    append_text_byte
    mov     edi, 0xd0
    call    append_text_byte
    jmp     .yes
.add_edi_imm:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_mem_edi
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    call    expect_u32_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x81
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.shl:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shl]
    mov     ecx, tok_shl_len
    call    token_eq
    test    eax, eax
    jz      .inc
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_mem_edi
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    call    expect_imm8_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0xc1
    call    append_text_byte
    mov     edi, 0xe0
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
    jz      .cmp
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.cmp:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmp]
    mov     ecx, tok_cmp_len
    call    token_eq
    test    eax, eax
    jz      .setz
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_mem_edi
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xf1
    call    append_text_byte
    jmp     .yes
.cmp_mem_edi:
    pop     r14
    lea     rdi, [rel tok_dword]
    mov     esi, tok_dword_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_mem_edi]
    mov     esi, tok_mem_edi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_mem_edi_plus4
    pop     rax
    mov     r10d, 0x3f
    xor     r11d, r11d
    jmp     .cmp_mem_imm
.cmp_mem_edi_plus4:
    pop     r14
    lea     rdi, [rel tok_mem_edi_open]
    mov     esi, tok_mem_edi_open_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_four_close]
    mov     esi, tok_four_close_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    mov     r10d, 0x7f
    mov     r11d, 4
.cmp_mem_imm:
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    call    expect_u32_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x67
    call    append_text_byte
    mov     edi, 0x81
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    test    r11d, r11d
    jz      .cmp_mem_disp_done
    mov     edi, r11d
    call    append_text_byte
.cmp_mem_disp_done:
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.setz:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_setz]
    mov     ecx, tok_setz_len
    call    token_eq
    test    eax, eax
    jz      .mov_store
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0x94
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.mov_store:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_mem_r12]
    mov     esi, tok_mem_r12_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x3c
    call    append_text_byte
    mov     edi, 0x24
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.no_pop:
    pop     r14
.no:
    xor     eax, eax
    ret

er_fn match_direct_test_same
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    mov     r10d, 0xf6
    xor     r11d, r11d
    call    match_emit_test_same_operand
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    mov     r10d, 0xc0
    xor     r11d, r11d
    call    match_emit_test_same_operand
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    mov     r10d, 0xc0
    mov     r11d, 1
    call    match_emit_test_same_operand
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    match_emit_test_al_al
    test    eax, eax
    jnz     .yes
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_emit_test_same_operand
    push    r10
    push    r11
    push    rdi
    push    rsi
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    mov     rdi, [rsp + 16]
    mov     rsi, [rsp + 8]
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    pop     rsi
    pop     rdi
    pop     r11
    pop     r10
    test    r11d, r11d
    jz      .opcode
    mov     edi, 0x48
    call    append_text_byte
.opcode:
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    mov     eax, 1
    ret
.no_pop:
    pop     r14
    pop     rsi
    pop     rdi
    pop     r11
    pop     r10
    xor     eax, eax
    ret

er_fn match_emit_test_al_al
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x84
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     eax, 1
    ret
.no_pop:
    pop     r14
    xor     eax, eax
    ret

er_fn match_cmos_time_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .movzx
    call    match_cmos_mov_time_ops
    ret
.movzx:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_movzx]
    mov     ecx, tok_movzx_len
    call    token_eq
    test    eax, eax
    jz      .no
    call    match_cmos_movzx_time_ops
    ret
.no:
    xor     eax, eax
    ret

er_fn match_cmos_mov_time_ops
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8b_al
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    call    expect_imm8_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     r11
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0xb7
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.r8b_al:
    pop     r14
    lea     rdi, [rel tok_r8b]
    mov     esi, tok_r8b_len
    mov     r10d, 0xc0
    call    match_cmos_mov_byte_from_al
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r9b]
    mov     esi, tok_r9b_len
    mov     r10d, 0xc1
    call    match_cmos_mov_byte_from_al
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r10b]
    mov     esi, tok_r10b_len
    mov     r10d, 0xc2
    call    match_cmos_mov_byte_from_al
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r12]
    mov     esi, tok_mem_r12_len
    mov     r10d, 0
    call    match_cmos_store_ax
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r13]
    mov     esi, tok_mem_r13_len
    mov     r10d, 1
    call    match_cmos_store_ax
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r14]
    mov     esi, tok_mem_r14_len
    mov     r10d, 2
    call    match_cmos_store_ax
    test    eax, eax
    jnz     .yes
    xor     eax, eax
    ret
.no_pop:
    pop     r14
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_cmos_mov_byte_from_al
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    mov     eax, 1
    ret
.no_pop:
    pop     r14
    xor     eax, eax
    ret

er_fn match_cmos_store_ax
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_ax]
    mov     esi, tok_ax_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     r11
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    cmp     r10d, 0
    jne     .r13
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x24
    call    append_text_byte
    jmp     .yes
.r13:
    cmp     r10d, 1
    jne     .r14
    mov     edi, 0x45
    call    append_text_byte
    mov     edi, 0x00
    call    append_text_byte
    jmp     .yes
.r14:
    mov     edi, 0x06
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.no_pop:
    pop     r14
    xor     eax, eax
    ret

er_fn match_cmos_movzx_time_ops
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    mov     r10d, 0xf8
    call    match_cmos_movzx_high_byte
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    mov     r10d, 0xc0
    call    match_cmos_movzx_high_byte
    test    eax, eax
    jnz     .yes
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret

er_fn match_cmos_movzx_high_byte
    push    r14
    push    r10
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_r8b]
    mov     esi, tok_r8b_len
    call    match_cmos_movzx_src
    test    eax, eax
    jnz     .src_r8
    lea     rdi, [rel tok_r9b]
    mov     esi, tok_r9b_len
    call    match_cmos_movzx_src
    test    eax, eax
    jnz     .src_r9
    lea     rdi, [rel tok_r10b]
    mov     esi, tok_r10b_len
    call    match_cmos_movzx_src
    test    eax, eax
    jz      .no_pop
.src_r10:
    pop     r10
    add     r10d, 2
    jmp     .line_end
.src_r9:
    pop     r10
    add     r10d, 1
    jmp     .line_end
.src_r8:
    pop     r10
.emit:
.line_end:
    push    r10
    call    expect_line_end
    test    eax, eax
    jz      .no_pop_modrm
    pop     r10
    pop     rax
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    mov     eax, 1
    ret
.no_pop:
    pop     r10
    pop     r14
    xor     eax, eax
    ret
.no_pop_modrm:
    pop     r10
    pop     r14
    xor     eax, eax
    ret

er_fn match_cmos_movzx_src
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     rax
    mov     eax, 1
    ret
.no_pop:
    pop     r14
    xor     eax, eax
    ret

er_fn match_cmos_arith_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_movzx]
    mov     ecx, tok_movzx_len
    call    token_eq
    test    eax, eax
    jz      .mov
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
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
    mov     edi, 0xc7
    call    append_text_byte
    jmp     .yes
.mov:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .add
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     r11
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
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.add:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_add]
    mov     ecx, tok_add_len
    call    token_eq
    test    eax, eax
    jz      .shr
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_comma
    test    eax, eax
    jz      .no_pop
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    call    expect_line_end
    test    eax, eax
    jz      .no_pop
    pop     r11
    mov     edi, 0x01
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.shr:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shr]
    mov     ecx, tok_shr_len
    call    token_eq
    test    eax, eax
    jz      .imul
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xc1
    call    append_text_byte
    mov     edi, 0xe9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.imul:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_imul]
    mov     ecx, tok_imul_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x6b
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
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
.no_pop:
    pop     r14
    xor     eax, eax
    ret

er_fn match_byte_reg_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .test
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    mov     eax, 1
    ret
.test:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
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
    mov     edi, 0xa8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    mov     eax, 1
    ret
.no_pop:
    pop     r14
.no:
    xor     eax, eax
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret

er_fn match_sized_mem_imm
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_dword]
    mov     esi, tok_dword_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     r11
    lea     rdi, [rel tok_mem_rdx]
    mov     esi, tok_mem_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_rcx
    pop     r11
    mov     r10d, 0x02
    jmp     .operand
.mem_rcx:
    pop     r14
    lea     rdi, [rel tok_mem_rcx]
    mov     esi, tok_mem_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     r10d, 0x01
.operand:
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    mov     eax, 1
    ret
.no_pop:
    pop     r14
.no:
    xor     eax, eax
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret

er_fn match_simple_reg_movs
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edx_ecx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_src_not_rdx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xd6
    call    append_text_byte
    jmp     .yes
.edx_ecx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_rdx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edx_src_not_ecx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xca
    call    append_text_byte
    jmp     .yes
.rcx_rdx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_esi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_src_not_rdx
    pop     r11
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
.eax_esi:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r14_rdx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_src_not_esi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .yes
.r14_rdx:
    pop     r14
    lea     rdi, [rel tok_r14]
    mov     esi, tok_r14_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_not_esi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r14_src_not_rdx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xd6
    call    append_text_byte
.yes:
    mov     eax, 1
    ret
.eax_not_esi:
    pop     r14
    xor     eax, eax
    ret
.eax_src_not_esi:
    pop     r14
    xor     eax, eax
    ret
.rsi_src_not_rdx:
    pop     r14
    xor     eax, eax
    ret
.edx_src_not_ecx:
    pop     r14
    xor     eax, eax
    ret
.rcx_src_not_rdx:
    pop     r14
    xor     eax, eax
    ret
.r14_src_not_rdx:
    pop     r14
    xor     eax, eax
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_rel_mem_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .inc
    call    expect_rel_label_value
    test    eax, eax
    jz      .no
    push    qword [rel imm_u32_value]
    call    expect_comma
    test    eax, eax
    jz      .bad_pop
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_ecx
    pop     r11
    mov     r10d, 0x05
    jmp     .mov_emit
.mov_ecx:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_esi
    pop     r11
    mov     r10d, 0x0d
    jmp     .mov_emit
.mov_esi:
    pop     r14
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_edi
    pop     r11
    mov     r10d, 0x35
    jmp     .mov_emit
.mov_edi:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad_pop
    mov     r10d, 0x3d
.mov_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad_pop
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    pop     rax
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    mov     rdi, rax
    call    append_text_u32
    mov     eax, 1
    ret
.inc:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_inc]
    mov     ecx, tok_inc_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_dword]
    mov     esi, tok_dword_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_not_rel_dword
    pop     r11
    call    expect_rel_label_value
    test    eax, eax
    jz      .bad
    push    qword [rel imm_u32_value]
    call    expect_line_end
    test    eax, eax
    jz      .bad_pop
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0x05
    call    append_text_byte
    pop     rax
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    mov     rdi, rax
    call    append_text_u32
    mov     eax, 1
    ret
.inc_not_rel_dword:
    pop     r14
    xor     eax, eax
    ret
.bad_pop:
    pop     r11
.bad:
    mov     qword [rel exit_subset_bad], 1
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
    lea     rdx, [rel tok_r8]
    mov     ecx, tok_r8_len
    mov     r11d, 8
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r9]
    mov     ecx, tok_r9_len
    mov     r11d, 9
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r10]
    mov     ecx, tok_r10_len
    mov     r11d, 10
    call    match_emit_gpr_stack
    test    eax, eax
    jnz     .yes
    lea     rdx, [rel tok_r11]
    mov     ecx, tok_r11_len
    mov     r11d, 11
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

er_fn match_check_zero_macro
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_check_zero]
    mov     ecx, tok_er_check_zero_len
    call    token_eq
    test    eax, eax
    jz      .nonzero
    mov     r10d, 0x84
    jmp     .operand
.nonzero:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_check_nonzero]
    mov     ecx, tok_er_check_nonzero_len
    call    token_eq
    test    eax, eax
    jz      .no
    mov     r10d, 0x85
.operand:
    mov     r8d, 1
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx
    pop     r11
    mov     r9d, 0xd2
    jmp     .emit
.rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi
    pop     r11
    mov     r9d, 0xc9
    jmp     .emit
.rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax
    pop     r11
    mov     r9d, 0xf6
    jmp     .emit
.eax:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax
    pop     r11
    mov     r9d, 0xc0
    xor     r8d, r8d
    jmp     .emit
.rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .esi
    pop     r11
    mov     r9d, 0xc0
    mov     r8d, 1
    jmp     .emit
.esi:
    pop     r14
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     r9d, 0xf6
    xor     r8d, r8d
.emit:
    call    expect_comma
    test    eax, eax
    jz      .bad
    test    r8d, r8d
    jz      .emit_test
    mov     edi, 0x48
    call    append_text_byte
.emit_test:
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, r9d
    call    append_text_byte
    mov     edi, r10d
    call    emit_short_branch_operand
    test    eax, eax
    jz      .bad
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_cmos_macros
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmos_in_data]
    mov     ecx, tok_cmos_in_data_len
    call    token_eq
    test    eax, eax
    jz      .out_index
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0xba
    call    append_text_byte
    mov     edi, 0x71
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    call    emit_in_al_dx
    mov     eax, 1
    ret
.out_index:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmos_out_index]
    mov     ecx, tok_cmos_out_index_len
    call    token_eq
    test    eax, eax
    jz      .out_data
    mov     r10d, 0x70
    jmp     .out_macro
.out_data:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmos_out_data]
    mov     ecx, tok_cmos_out_data_len
    call    token_eq
    test    eax, eax
    jz      .no
    mov     r10d, 0x71
.out_macro:
    call    skip_space_inline
    push    r14
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    call    expect_operand
    test    eax, eax
    jz      .arg_al
    pop     r11
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .out_port
.arg_al:
    pop     r14
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .arg_sil
    pop     r11
    jmp     .out_port
.arg_sil:
    pop     r14
    push    r14
    lea     rdi, [rel tok_sil]
    mov     esi, tok_sil_len
    call    expect_operand
    test    eax, eax
    jz      .arg_imm
    pop     r11
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .out_port
.arg_imm:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .bad
    mov     edi, 0xb0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
.out_port:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0xba
    call    append_text_byte
    mov     edi, r10d
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    call    emit_out_dx_al
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_test_exit_passed_total_macro
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_exit_passed_total]
    mov     ecx, tok_test_exit_passed_total_len
    call    token_eq
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xb8
    call    append_text_byte
    mov     edi, 60
    call    append_text_u32
    call    emit_xor_edi_edi
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

er_fn match_cmp_below_macro
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_cmp_below]
    mov     ecx, tok_er_cmp_below_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xd1
    call    append_text_byte
    mov     edi, 0x72
    call    emit_short_branch_operand
    test    eax, eax
    jz      .bad
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_test_call_eax_macro
    er_push r12, r13, rbx
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test_call_eax]
    mov     ecx, tok_test_call_eax_len
    call    token_eq
    test    eax, eax
    jz      .no
    call    skip_space_inline
    call    skip_operand_token
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    mov     rbx, [rel imm_u32_value]
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xbf
    call    append_text_byte
    mov     rdi, rbx
    call    append_text_u32
    mov     edi, 0xe8
    call    append_text_byte
    xor     edi, edi
    call    append_text_u32
    mov     edi, 0x3d
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    mov     edi, 0x75
    call    append_text_byte
    mov     rbx, [rel text_len]
    xor     edi, edi
    call    append_text_byte
    lea     r10, [rel tok_passed_sym]
    mov     r11d, tok_passed_sym_len
    call    emit_inc_qword_rel_symbol
    mov     rax, [rel text_len]
    sub     rax, rbx
    dec     rax
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], al
    lea     r10, [rel tok_total_sym]
    mov     r11d, tok_total_sym_len
    call    emit_inc_qword_rel_symbol
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    jmp     .done
.no:
    xor     eax, eax
.done:
    er_pop  r12, r13, rbx
    ret

er_fn emit_inc_qword_rel_symbol
    call    find_label_value
    test    eax, eax
    jz      .bad
    mov     rbx, rdx
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0x05
    call    append_text_byte
    mov     rax, rbx
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    mov     rdi, rax
    call    append_text_u32
    mov     eax, 1
    ret
.bad:
    mov     qword [rel exit_subset_bad], 1
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

er_fn match_lea_runtime
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_lea]
    mov     ecx, tok_lea_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_dst
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .no
    call    expect_rsi_plus_rdx
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x0c
    call    append_text_byte
    mov     edi, 0x16
    call    append_text_byte
    jmp     .yes
.rsi_dst:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdi_dst
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .no
    call    expect_rsi_plus_rdx_minus_one
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x74
    call    append_text_byte
    mov     edi, 0x16
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rdi_dst:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdx_dst
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .no
    push    r14
    call    expect_rdi_plus_rdx_minus_one
    test    eax, eax
    jz      .rdi_rcx_minus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x7c
    call    append_text_byte
    mov     edi, 0x17
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rdi_rcx_minus_one:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x7c
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rdx_dst:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_dst
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .no
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x14
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.rax_dst:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .no
    push    r14
    call    expect_rdi_minus_one
    test    eax, eax
    jz      .rax_rdi_plus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x47
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rax_rdi_plus_one:
    pop     r14
    push    r14
    call    expect_rdi_plus_one
    test    eax, eax
    jz      .rax_rdi_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x47
    call    append_text_byte
    mov     edi, 0x01
    call    append_text_byte
    jmp     .yes
.rax_rdi_r8:
    pop     r14
    push    r14
    call    expect_rdi_plus_r8
    test    eax, eax
    jz      .rax_r8_plain
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x4a
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.rax_r8_plain:
    pop     r14
    call    expect_r8_plain_mem
    test    eax, eax
    jz      .no
    call    expect_line_end
    test    eax, eax
    jz      .no
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x8d
    call    append_text_byte
    mov     edi, 0x00
    call    append_text_byte
    jmp     .yes
.yes:
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

er_fn match_call_label
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_call]
    mov     ecx, tok_call_len
    call    token_eq
    test    eax, eax
    jz      .no
    jmp     emit_call_label_operand
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
