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
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .xor_eax_zero
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .mov_exit_rax
    pop     rax
    xor     r10d, r10d
    jmp     .mov_exit_operand_ok
.mov_exit_rax:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    mov     r10d, 1
.mov_exit_operand_ok:
    er_expect_comma_result
    jz      .bad
    cmp     r10d, 0
    jne     .mov_exit_u32
    er_push_expect_token_operand_result tok_edi, tok_edi_len
    jz      .mov_exit_not_edi
    pop     rax
    er_expect_line_end_result
    jz      .bad
    call    emit_mov_eax_edi
    mov     qword [rel exit_instr_step], 7
    jmp     .done
.mov_exit_not_edi:
    pop     r14
.mov_exit_u32:
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
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
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .cmp_dil_low
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_line_end_result
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
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .mov_status
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_xor_edi_edi
    inc     qword [rel exit_instr_step]
    jmp     .done
.mov_status:
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .bad
    er_expect_token_operand_push_result tok_edi, tok_edi_len
    jz      .mov_status_rdi
    pop     rax
    xor     r10d, r10d
    jmp     .mov_status_operand_ok
.mov_status_rdi:
    er_pop_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    mov     r10d, 1
.mov_status_operand_ok:
    er_expect_comma_result
    jz      .bad
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
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
    er_match_source_token_result tok_syscall, tok_syscall_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_syscall
    inc     qword [rel exit_instr_step]
    jmp     .done
.jb_false:
    er_match_source_token_result tok_jb, tok_jb_len
    jz      .bad
    call    expect_target_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
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
    er_match_source_token_result tok_ja, tok_ja_len
    jz      .bad
    call    expect_target_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_ja_placeholder
    mov     qword [rel exit_instr_step], 23
    jmp     .done
.jnz_false:
    er_match_source_token_result tok_jnz, tok_jnz_len
    jz      .bad
    call    expect_target_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
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
    er_ret_true
.stack_macros:
    call    match_stack_macros
    test    eax, eax
    jz      .ret_macro
    er_ret_true
.ret_macro:
    call    match_ret_line
    test    eax, eax
    jz      .er_ok
    call    emit_ret
    er_ret_true
.er_ok:
    er_match_source_token_result tok_er_ok, tok_er_ok_len
    jz      .er_err
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x31, 0xd2
    er_ret_true
.er_err:
    er_match_source_token_result tok_er_call, tok_er_call_len
    jz      .pause
    call    match_er_call_macro
    ret
.pause:
    er_match_source_token_result tok_pause, tok_pause_len
    jz      .er_err_real
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf3, 0x90
    er_ret_true
.er_err_real:
    er_match_source_token_result tok_er_err, tok_er_err_len
    jz      .check_zero
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xba
    er_emit_imm_u32_value
    er_ret_true
.check_zero:
    push    qword [rel text_len]
    push    r14
    call    match_generic_common_instruction
    test    eax, eax
    jz      .generic_common_miss
    pop     r11
    pop     r10
    er_ret_true
.generic_common_miss:
    pop     r14
    pop     rax
.check_zero_real:
    call    match_check_zero_macro
    test    eax, eax
    jz      .test_same
    er_ret_true
.test_same:
    push    r14
    jmp     .direct_add_dx
.direct_add_dx:
    pop     r14
    push    r14
    call    match_direct_add_dx_imm8
    test    eax, eax
    jz      .direct_add_eax
    pop     r11
    er_ret_true
.direct_add_eax:
    jmp     .direct_add_r11d
.direct_add_r11d:
    pop     r14
    push    r14
    call    match_direct_add_r11d_reg32
    test    eax, eax
    jz      .direct_add_dl
    pop     r11
    er_ret_true
.direct_add_dl:
    pop     r14
    push    r14
    call    match_direct_add_dl_imm8
    test    eax, eax
    jz      .direct_add_rsp
    pop     r11
    er_ret_true
.direct_add_rsp:
    jmp     .direct_test_al
.direct_test_al:
    pop     r14
    push    r14
    call    match_direct_test_al_imm8
    test    eax, eax
    jz      .direct_or_reg32
    pop     r11
    er_ret_true
.direct_or_reg32:
    pop     r14
    push    r14
    call    match_direct_or_reg32
    test    eax, eax
    jz      .direct_test_r9d
    pop     r11
    er_ret_true
.direct_test_r9d:
    jmp     .direct_shl_r9
.direct_shl_r9:
    pop     r14
    push    r14
    call    match_direct_shl_r9_imm8
    test    eax, eax
    jz      .direct_shr_rax
    pop     r11
    er_ret_true
.direct_shr_rax:
    jmp     .direct_lodsb
.direct_lodsb:
    pop     r14
    push    r14
    call    match_direct_lodsb
    test    eax, eax
    jz      .early_common_mov
    pop     r11
    er_ret_true
.early_common_mov:
    pop     r14
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .acpi_ops_no_restore
    push    r14
    call    match_direct_mov_dx_imm16
    test    eax, eax
    jz      .early_common_mov_after_dx_imm
    pop     r11
    er_ret_true
.early_common_mov_after_dx_imm:
    jmp     .early_common_mov_after_edx_imm
.early_common_mov_after_edx_imm:
    pop     r14
    push    r14
    call    match_direct_mov_sil_rsp_rcx
    test    eax, eax
    jz      .early_common_mov_after_sil_rsp_rcx
    pop     r11
    er_ret_true
.early_common_mov_after_sil_rsp_rcx:
    pop     r14
    push    r14
    call    match_direct_mov_rsp_rcx_dl
    test    eax, eax
    jz      .early_common_mov_after_rsp_rcx_dl
    pop     r11
    er_ret_true
.early_common_mov_after_rsp_rcx_dl:
    pop     r14
    push    r14
    call    match_direct_mov_byte_rsp10_imm8
    test    eax, eax
    jz      .early_common_mov_after_rsp10
    pop     r11
    er_ret_true
.early_common_mov_after_rsp10:
    jmp     .early_common_mov_after_ecx_imm
.early_common_mov_after_ecx_imm:
    pop     r14
    push    r14
    call    match_rel_mem_ops
    test    eax, eax
    jz      .early_common_mov_after_rel
    pop     r11
    er_ret_true
.early_common_mov_after_rel:
    pop     r14
    push    r14
    call    match_sized_mem_imm
    test    eax, eax
    jz      .early_common_mov_after_sized
    pop     r11
    er_ret_true
.early_common_mov_after_sized:
    pop     r14
    push    r14
    call    match_cmos_time_ops
    test    eax, eax
    jz      .early_common_mov_after_cmos_time
    pop     r11
    er_ret_true
.early_common_mov_after_cmos_time:
    pop     r14
    push    r14
    call    match_cmos_arith_ops
    test    eax, eax
    jz      .early_common_mov_after_cmos_arith
    pop     r11
    er_ret_true
.early_common_mov_after_cmos_arith:
    pop     r14
    push    r14
    call    match_byte_reg_ops
    test    eax, eax
    jz      .early_common_mov_after_byte_reg
    pop     r11
    er_ret_true
.early_common_mov_after_byte_reg:
    pop     r14
    push    r14
    call    match_common_mov
    test    eax, eax
    jz      .acpi_ops
    pop     r11
    er_ret_true
.acpi_ops:
    pop     r14
.acpi_ops_no_restore:
    call    match_acpi_direct_mov_fields
    test    eax, eax
    jz      .acpi_misc_ops
    er_ret_true
.acpi_misc_ops:
    call    match_acpi_ebda_movzx
    test    eax, eax
    jz      .acpi_mcfg_ops
    er_ret_true
.acpi_mcfg_ops:
    call    match_acpi_mcfg_ops
    test    eax, eax
    jz      .acpi_find_table_setup_ops
    er_ret_true
.acpi_find_table_setup_ops:
    call    match_acpi_find_table_setup_ops
    test    eax, eax
    jz      .acpi_checksum_ops
    er_ret_true
.acpi_checksum_ops:
    call    match_acpi_checksum_ops
    test    eax, eax
    jz      .mov
    er_ret_true
.mov:
    push    r14
    call    match_rel_mem_ops
    test    eax, eax
    jz      .mov_common
    pop     rax
    er_ret_true
.mov_common:
    pop     r14
    push    r14
    call    match_cmos_time_ops
    test    eax, eax
    jz      .mov_cmos_arith
    pop     r11
    er_ret_true
.mov_cmos_arith:
    pop     r14
    push    r14
    call    match_cmos_arith_ops
    test    eax, eax
    jz      .mov_byte_reg
    pop     r11
    er_ret_true
.mov_byte_reg:
    pop     r14
    push    r14
    call    match_byte_reg_ops
    test    eax, eax
    jz      .mov_sized_mem
    pop     r11
    er_ret_true
.mov_sized_mem:
    pop     r14
    push    r14
    call    match_sized_mem_imm
    test    eax, eax
    jz      .mov_reg_moves
    pop     r11
    er_ret_true
.mov_reg_moves:
    pop     r14
    push    r14
    call    match_simple_reg_movs
    test    eax, eax
    jz      .mov_existing
    pop     r11
    er_ret_true
.mov_existing:
    pop     r14
    push    r14
    call    match_common_mov
    test    eax, eax
    jz      .math_mov
    pop     r11
    er_ret_true
.math_mov:
    pop     r14
.math_mov_try_more:
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .math_mov_try_more_runtime
    push    r14
    jmp     .math_mov_after_more
.math_mov_try_more_runtime:
    er_match_source_token_result tok_shl, tok_shl_len
    jnz     .math_mov_skip_more_runtime
    er_match_source_token_result tok_shr, tok_shr_len
    jnz     .math_mov_skip_more_runtime
    er_match_source_token_result tok_test, tok_test_len
    jnz     .math_mov_skip_more_runtime
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .math_mov_after_more
    pop     r11
    er_ret_true
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
    er_ret_true
.math_mov_hash:
    pop     r14
    push    r14
    call    match_math_hash_mov
    test    eax, eax
    jnz     .math_mov_hash_done
    pop     r14
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .xor
    call    match_math_int_ops
    test    eax, eax
    jnz     .math_mov_done
    er_ret_false
.math_mov_hash_done:
    pop     r11
.math_mov_done:
    er_ret_true
.xor:
    push    r14
    call    match_xor_eax_eax
    test    eax, eax
    jz      .xor_more
    pop     r11
    call    emit_xor_eax_eax
    er_ret_true
.xor_more:
    pop     r14
    push    r14
    call    match_xor_edi_edi
    test    eax, eax
    jz      .xor_same32
    pop     r11
    call    emit_xor_edi_edi
    er_ret_true
.xor_same32:
    pop     r14
    push    r14
    call    match_direct_xor_same32
    test    eax, eax
    jz      .xor_more_runtime
    pop     r11
    er_ret_true
.xor_more_runtime:
    pop     r14
    er_match_source_token_result tok_shl, tok_shl_len
    jnz     .xor_more_runtime_skip
    er_match_source_token_result tok_shr, tok_shr_len
    jnz     .xor_more_runtime_skip
    er_match_source_token_result tok_test, tok_test_len
    jnz     .xor_more_runtime_skip
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .shift
    pop     r11
    er_ret_true
.xor_more_runtime_skip:
    push    r14
    jmp     .shift
.shift:
    pop     r14
    er_match_source_token_result tok_test, tok_test_len
    jnz     .test
    push    r14
    call    match_math_hash_xor
    test    eax, eax
    jz      .shift_int_ops
    pop     r11
    er_ret_true
.shift_int_ops:
    pop     r14
    call    match_math_int_ops
    test    eax, eax
    jz      .shift_ops
    er_ret_true
.shift_ops:
    call    match_math_hash_shift
    test    eax, eax
    jz      .test
    er_ret_true
.test:
    call    match_math_hash_test
    test    eax, eax
    jz      .test_int
    er_ret_true
.test_int:
    call    match_math_int_ops
    test    eax, eax
    jz      .cmp
    er_ret_true
.cmp:
    push    r14
    call    match_more_byte_arith
    test    eax, eax
    jz      .cmp_math
    pop     r11
    er_ret_true
.cmp_math:
    pop     r14
    call    match_math_hash_cmp
    test    eax, eax
    jz      .arith
    er_ret_true
.arith:
    push    r14
    call    match_more_byte_arith
    test    eax, eax
    jz      .arith_more
    pop     r11
    er_ret_true
.arith_more:
    pop     r14
    push    r14
    call    match_more_unary
    test    eax, eax
    jz      .arith_math
    pop     r11
    er_ret_true
.arith_math:
    pop     r14
    push    r14
    call    match_math_hash_arith
    test    eax, eax
    jz      .arith_int
    pop     r11
    er_ret_true
.arith_int:
    pop     r14
    call    match_math_int_ops
    test    eax, eax
    jz      .branch
    er_ret_true
.branch:
    call    match_math_hash_branch
    test    eax, eax
    jz      .crc32
    er_ret_true
.crc32:
    call    match_math_hash_crc32
    test    eax, eax
    jz      .movzx
    er_ret_true
.movzx:
    call    match_math_hash_movzx
    test    eax, eax
    jz      .int_ops
    er_ret_true
.int_ops:
    call    match_math_int_ops
    test    eax, eax
    jz      .mul
    er_ret_true
.mul:
    call    match_math_hash_mul
    test    eax, eax
    jz      .call
    er_ret_true
.call:
    call    match_call_label
    test    eax, eax
    jz      .portio
    er_ret_true
.portio:
    call    match_in_al_dx
    test    eax, eax
    jz      .out_dx_al
    call    emit_in_al_dx
    er_ret_true
.out_dx_al:
    call    match_out_dx_al
    test    eax, eax
    jz      .syscall
    call    emit_out_dx_al
    er_ret_true
.syscall:
    er_match_source_token_result tok_syscall, tok_syscall_len
    jz      .lea
    er_expect_line_end_result
    jz      .bad
    call    emit_syscall
    er_ret_true
.bad:
    er_ret_false
.lea:
    call    match_lea_rel_label
    test    eax, eax
    jz      .lea_runtime
    er_ret_true
.lea_runtime:
    call    match_lea_runtime
    test    eax, eax
    jz      .test_exit
    er_ret_true
.test_exit:
    call    match_cmos_macros
    test    eax, eax
    jz      .test_exit_total
    er_ret_true
.test_exit_total:
    call    match_test_exit_passed_total_macro
    test    eax, eax
    jz      .cmp_below
    er_ret_true
.cmp_below:
    call    match_cmp_below_macro
    test    eax, eax
    jz      .test_call_eax
    er_ret_true
.test_call_eax:
    call    match_test_call_eax_macro
    test    eax, eax
    jz      .test_exit_real
    er_ret_true
.test_exit_real:
    call    match_test_exit_macro
    test    eax, eax
    jz      .no
    er_ret_true
.no:
    er_ret_false

er_fn expect_r12_plus_symbol_close
    push    rdi
    push    rsi
    er_expect_token_operand_result tok_mem_r12_open, tok_mem_r12_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    mov     rdi, [rsp + 8]
    mov     rsi, [rsp]
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    pop     rsi
    pop     rdi
    ret

er_fn expect_rdi_plus_symbol_close
    push    rdi
    push    rsi
    er_expect_token_operand_result tok_mem_rdi_open, tok_mem_rdi_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    mov     rdi, [rsp + 8]
    mov     rsi, [rsp]
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    pop     rsi
    pop     rdi
    ret

er_fn expect_rdi_sdt_header_rcx
    er_expect_token_operand_result tok_mem_rdi_open, tok_mem_rdi_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand_result tok_sdt_header_len, tok_sdt_header_len_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand tok_rcx_close, tok_rcx_close_len
    ret
.bad:
    er_ret_false

er_fn expect_r12_plus_rcx
    er_expect_token_operand_result tok_mem_r12_open, tok_mem_r12_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand tok_rcx_close, tok_rcx_close_len
    ret
.bad:
    er_ret_false

er_fn expect_r12_plus_rcx_plus_one
    er_expect_token_operand_result tok_mem_r12_open, tok_mem_r12_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand tok_one_close, tok_one_close_len
    ret
.bad:
    er_ret_false

er_fn expect_r12_plus_rcx_symbol
    push    rdi
    push    rsi
    er_expect_token_operand_result tok_mem_r12_open, tok_mem_r12_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    mov     rdi, [rsp + 8]
    mov     rsi, [rsp]
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    pop     rsi
    pop     rdi
    ret

er_fn expect_rdi_mcfg_field
    push    rdi
    push    rsi
    er_expect_token_operand_result tok_mem_rdi_open, tok_mem_rdi_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand_result tok_mcfg_allocations, tok_mcfg_allocations_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    mov     rdi, [rsp + 8]
    mov     rsi, [rsp]
    call    expect_operand
    test    eax, eax
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    pop     rsi
    pop     rdi
    ret

er_fn match_direct_mov_byte_rsp10_imm8
    er_expect_token_operand_push_result tok_byte, tok_byte_len
    jz      .no_pop
    er_expect_token_operand_result tok_mem_rsp_open, tok_mem_rsp_open_len
    jz      .no_pop
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .no_pop
    er_expect_token_operand_result tok_ten_close, tok_ten_close_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_imm8_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0xc6, 0x44, 0x24, 10
    er_emit_imm_byte_value
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_direct_mov_rsp_rcx_dl
    er_expect_token_operand_push_result tok_mem_rsp_open, tok_mem_rsp_open_len
    jz      .no_pop
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .no_pop
    er_expect_token_operand_result tok_rcx_close, tok_rcx_close_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_dl, tok_dl_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x88, 0x14, 0x0c
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_direct_mov_sil_rsp_rcx
    er_expect_token_operand_push_result tok_sil, tok_sil_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_mem_rsp_open, tok_mem_rsp_open_len
    jz      .no_pop
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .no_pop
    er_expect_token_operand_result tok_rcx_close, tok_rcx_close_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x40, 0x8a, 0x34, 0x0c
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_direct_mov_dx_imm16
    er_expect_token_operand_push_result tok_dx, tok_dx_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_value_result
    jz      .no_pop
    cmp     qword [rel imm_u32_value], 0xffff
    ja      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x66, 0xba
    mov     rax, [rel imm_u32_value]
    mov     rdi, rax
    and     rdi, 0xff
    call    append_text_byte
    mov     rax, [rel imm_u32_value]
    shr     rax, 8
    mov     rdi, rax
    and     rdi, 0xff
    call    append_text_byte
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_direct_add_dx_imm8
    er_match_source_token_result tok_add, tok_add_len
    jz      .no
    er_expect_token_operand_push_result tok_dx, tok_dx_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .not_al
    pop     r11
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x84, 0xc0
    er_ret_true
.not_al:
    pop     r14
    push    r14
    er_expect_imm8_result
    jz      .symbol
    pop     r11
    jmp     .emit
.symbol:
    pop     r14
    lea     rdi, [rel tok_uart_dll]
    mov     esi, tok_uart_dll_len
    xor     r10d, r10d
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_uart_dlm]
    mov     esi, tok_uart_dlm_len
    mov     r10d, 1
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_uart_ier]
    mov     esi, tok_uart_ier_len
    mov     r10d, 1
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_uart_fcr]
    mov     esi, tok_uart_fcr_len
    mov     r10d, 2
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_uart_lcr]
    mov     esi, tok_uart_lcr_len
    mov     r10d, 3
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_uart_mcr]
    mov     esi, tok_uart_mcr_len
    mov     r10d, 4
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_uart_lsr]
    mov     esi, tok_uart_lsr_len
    mov     r10d, 5
    call    match_direct_symbol_imm8
    test    eax, eax
    jz      .no_pop
.symbol_ok:
    mov     qword [rel imm_u32_value], r10
.emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x66, 0x83, 0xc2
    er_emit_imm_byte_value
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_direct_add_dl_imm8
    er_match_source_token_result tok_add, tok_add_len
    jz      .no
    er_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_imm8_result
    jz      .char
    pop     r11
    jmp     .emit
.char:
    pop     r14
    call    expect_char_operand
    test    eax, eax
    jz      .no_pop
.emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x80, 0xc2
    er_emit_imm_byte_value
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_direct_add_r11d_reg32
    er_match_source_token_result tok_add, tok_add_len
    jz      .no
    er_expect_token_operand_push_result tok_r11d, tok_r11d_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .try_esi
    pop     r11
    mov     r10d, 0xc3
    jmp     .emit
.try_esi:
    er_pop_expect_token_operand_result tok_esi, tok_esi_len
    jz      .no_pop
    mov     r10d, 0xf3
.emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x41, 0x01, r10d
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_direct_xor_same32
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .no
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    mov     r10d, 0xf6
    xor     r11d, r11d
    call    match_emit_xor_same32_operand
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r9d]
    mov     esi, tok_r9d_len
    mov     r10d, 0xc9
    mov     r11d, 0x45
    call    match_emit_xor_same32_operand
    test    eax, eax
    jnz     .yes
.no:
    er_ret_false
.yes:
    er_ret_true

er_fn match_emit_xor_same32_operand
    push    r10
    push    r11
    push    rdi
    push    rsi
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    mov     rdi, [rsp + 16]
    mov     rsi, [rsp + 8]
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    pop     rsi
    pop     rdi
    pop     r11
    pop     r10
    test    r11d, r11d
    jz      .opcode
    er_emit_text_bytes r11d
.opcode:
    er_emit_text_bytes 0x31, r10d
    er_ret_true
.no_pop:
    pop     r14
    pop     rsi
    pop     rdi
    pop     r11
    pop     r10
    er_ret_false

er_fn match_direct_or_reg32
    er_match_source_token_result tok_or, tok_or_len
    jz      .no
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    lea     rdx, [rel tok_ebx]
    mov     ecx, tok_ebx_len
    mov     r10d, 0xd8
    call    match_emit_two_reg32_operands
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_ebx]
    mov     esi, tok_ebx_len
    lea     rdx, [rel tok_eax]
    mov     ecx, tok_eax_len
    mov     r10d, 0xc3
    call    match_emit_two_reg32_operands
    test    eax, eax
    jz      .no
.yes:
    er_emit_text_bytes 0x09, r10d
    er_ret_true
.no:
    er_ret_false

er_fn match_emit_two_reg32_operands
    push    r10
    push    rdx
    push    rcx
    push    rdi
    push    rsi
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    mov     rdi, [rsp + 32]
    mov     rsi, [rsp + 24]
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rdx
    pop     r10
    er_ret_true
.no_pop:
    pop     r14
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rdx
    pop     r10
    er_ret_false

er_fn match_direct_test_al_imm8
    er_match_source_token_result tok_test, tok_test_len
    jz      .no
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_imm8_result
    jz      .symbol
    pop     r11
    jmp     .emit
.symbol:
    pop     r14
    lea     rdi, [rel tok_lsr_thr_empty]
    mov     esi, tok_lsr_thr_empty_len
    mov     r10d, 0x20
    call    match_direct_symbol_imm8
    test    eax, eax
    jnz     .symbol_ok
    lea     rdi, [rel tok_lsr_data_ready]
    mov     esi, tok_lsr_data_ready_len
    mov     r10d, 0x01
    call    match_direct_symbol_imm8
    test    eax, eax
    jz      .no_pop
.symbol_ok:
    mov     qword [rel imm_u32_value], r10
.emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0xa8
    er_emit_imm_byte_value
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_direct_lodsb
    er_match_source_token_result tok_lodsb, tok_lodsb_len
    jz      .no
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0xac
    er_ret_true
.no:
    er_ret_false

er_fn match_direct_shl_r9_imm8
    er_match_source_token_result tok_shl, tok_shl_len
    jz      .no
    er_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_imm8_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x49, 0xc1, 0xe1
    er_emit_imm_byte_value
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_direct_symbol_imm8
    push    r10
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .bad
    pop     r11
    pop     r10
    er_ret_true
.bad:
    pop     r14
    pop     r10
    er_ret_false

er_fn match_acpi_ebda_movzx
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .no
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_word, tok_word_len
    jz      .no_pop
    er_expect_token_operand_result tok_mem_ebda_seg_ptr, tok_mem_ebda_seg_ptr_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x0f, 0xb7, 0x04, 0x25
    mov     edi, 0x40e
    call    append_text_u32
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_acpi_mcfg_ops
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .movzx
    er_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .store_rdx_rax
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_mcfg_alloc_base_close]
    mov     esi, tok_mcfg_alloc_base_close_len
    call    expect_rdi_mcfg_field
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x48, 0x8b, 0x47, 44
    jmp     .yes
.store_rdx_rax:
    er_pop_expect_token_operand_push_result tok_mem_rdx, tok_mem_rdx_len
    jz      .store_rcx_al
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x48, 0x89, 0x02
    jmp     .yes
.store_rcx_al:
    er_pop_expect_token_operand_push_result tok_mem_rcx, tok_mem_rcx_len
    jz      .store_r8_al
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .store_rcx_eax
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x88, 0x01
    jmp     .yes
.store_rcx_eax:
    er_pop_expect_token_operand_result tok_eax, tok_eax_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x89, 0x01
    jmp     .yes
.store_r8_al:
    er_pop_expect_token_operand_push_result tok_mem_r8, tok_mem_r8_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x41, 0x88
    er_emit_zero_byte
    jmp     .yes
.movzx:
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .no
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_push_expect_token_operand_result tok_byte, tok_byte_len
    jz      .movzx_not_byte
    pop     rax
    er_push_expect_token_operand_result tok_mem_rdx_open, tok_mem_rdx_open_len
    jz      .movzx_not_rdx_rbx
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .movzx_not_rdx_rbx
    er_expect_token_operand_result tok_rbx_close, tok_rbx_close_len
    jz      .movzx_not_rdx_rbx
    er_expect_line_end_result
    jz      .movzx_not_rdx_rbx
    pop     r11
    pop     r14
    er_emit_text_bytes 0x0f, 0xb6, 0x04, 0x1a
    jmp     .yes
.movzx_not_rdx_rbx:
    pop     r14
    lea     rdi, [rel tok_mcfg_alloc_start_close]
    mov     esi, tok_mcfg_alloc_start_close_len
    push    r14
    call    expect_rdi_mcfg_field
    test    eax, eax
    jz      .movzx_end
    pop     r14
    mov     r10d, 54
    jmp     .movzx_emit
.movzx_not_byte:
    pop     r14
    jmp     .no_pop
.movzx_end:
    pop     r14
    lea     rdi, [rel tok_mcfg_alloc_end_close]
    mov     esi, tok_mcfg_alloc_end_close_len
    call    expect_rdi_mcfg_field
    test    eax, eax
    jz      .no_pop
    mov     r10d, 55
.movzx_emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x0f, 0xb6, 0x47, r10d
.yes:
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_acpi_find_table_setup_ops
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .xor
    er_expect_token_operand_push_result tok_r14d, tok_r14d_len
    jz      .mov_r13d_esi
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_edx, tok_edx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x89, 0xd6
    jmp     .yes
.mov_r13d_esi:
    er_pop_expect_token_operand_push_result tok_r13d, tok_r13d_len
    jz      .mov_r13_rsi
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_esi, tok_esi_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x89, 0xf5
    jmp     .yes
.mov_r13_rsi:
    er_pop_expect_token_operand_push_result tok_r13, tok_r13_len
    jz      .mov_r14_rdx
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x89, 0xf5
    jmp     .yes
.mov_r14_rdx:
    er_pop_expect_token_operand_push_result tok_r14, tok_r14_len
    jz      .mov_r15_rcx
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x89, 0xd6
    jmp     .yes
.mov_r15_rcx:
    er_pop_expect_token_operand_push_result tok_r15, tok_r15_len
    jz      .mov_rbx_r8
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x89, 0xcf
    jmp     .yes
.mov_rbx_r8:
    er_pop_expect_token_operand_push_result tok_rbx, tok_rbx_len
    jz      .mov_rdi_r12
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r8, tok_r8_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x4c, 0x89, 0xc3
    jmp     .yes
.mov_rdi_r12:
    er_pop_expect_token_operand_push_result tok_r12, tok_r12_len
    jz      .mov_rdi_r12_dest
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x89, 0xfc
    jmp     .yes
.mov_rdi_r12_dest:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .mov_ebx_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_push_result tok_r12, tok_r12_len
    jz      .mov_rdi_r13
    pop     rax
    mov     r10d, 0xe7
    jmp     .mov_rdi_emit
.mov_rdi_r13:
    er_pop_expect_token_operand_result tok_r13, tok_r13_len
    jz      .no_pop
    mov     r10d, 0xef
.mov_rdi_emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x4c, 0x89, r10d
    jmp     .yes
.mov_ebx_imm:
    er_pop_expect_token_operand_push_result tok_ebx, tok_ebx_len
    jz      .mov_esi_sdt_length
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_u32_result
    jz      .mov_ebx_imm_not_u32
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0xbb
    er_emit_imm_u32_value
    jmp     .yes
.mov_ebx_imm_not_u32:
    pop     r14
    jmp     .no_pop
.mov_esi_sdt_length:
    er_pop_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .mov_r8d_entry
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_sdt_length_close]
    mov     esi, tok_sdt_length_close_len
    call    expect_rdi_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x8b, 0x77, 4
    jmp     .yes
.mov_r8d_entry:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    match_acpi_mov_eax_madt_lapic
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r14]
    mov     esi, tok_mem_r14_len
    call    match_acpi_store_eax_ptr
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    match_acpi_mov_ecx_imm
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    mov     r10d, 0x44
    mov     r11d, 0x8b
    mov     ebx, 0x44
    call    match_acpi_entry_load
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    mov     r10d, 0x4c
    mov     r11d, 0x8b
    mov     ebx, 0x4c
    call    match_acpi_entry_load
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    match_acpi_mov_r9_r8
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r9d]
    mov     esi, tok_r9d_len
    lea     rdx, [rel tok_madt_ioapic_addr_close]
    mov     ecx, tok_madt_ioapic_addr_close_len
    mov     r10d, 0x4c
    mov     r11d, 4
    call    match_acpi_madt_indexed_load
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_r10d]
    mov     esi, tok_r10d_len
    lea     rdx, [rel tok_madt_ioapic_gsi_base_close]
    mov     ecx, tok_madt_ioapic_gsi_base_close_len
    mov     r10d, 0x54
    mov     r11d, 8
    call    match_acpi_madt_indexed_load
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    match_acpi_mov_eax_mem_r9
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    match_acpi_mov_rax_r9
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r15]
    mov     esi, tok_mem_r15_len
    call    match_acpi_store_r9d_ptr
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_rbx]
    mov     esi, tok_mem_rbx_len
    call    match_acpi_store_r10d_ptr
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r15]
    mov     esi, tok_mem_r15_len
    call    match_acpi_store_rax_ptr
    test    eax, eax
    jnz     .yes
    er_ret_false
.xor:
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .test
    er_expect_token_operand_push_result tok_ebx, tok_ebx_len
    jz      .xor_r9d
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_ebx, tok_ebx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x31, 0xdb
    jmp     .yes
.xor_r9d:
    er_pop_expect_token_operand_push_result tok_r9d, tok_r9d_len
    jz      .xor_r10d
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r9d, tok_r9d_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x45, 0x31, 0xc9
    jmp     .yes
.xor_r10d:
    er_pop_expect_token_operand_push_result tok_r10d, tok_r10d_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r10d, tok_r10d_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x45, 0x31, 0xd2
    jmp     .yes
.test:
    er_match_source_token_result tok_test, tok_test_len
    jz      .sub
    er_expect_token_operand_push_result tok_r13, tok_r13_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r13, tok_r13_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x4d, 0x85, 0xed
    jmp     .yes
.sub:
    er_match_source_token_result tok_sub, tok_sub_len
    jz      .no
    er_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_u32_result
    jz      .sub_esi_not_u32
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x81, 0xee
    er_emit_imm_u32_value
    jmp     .yes
.sub_esi_not_u32:
    pop     r14
    jmp     .no_pop
.yes:
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_acpi_direct_mov_fields
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .no
    er_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_rsdp_length_close]
    mov     esi, tok_rsdp_length_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x8b, 0x74, 0x24, 20
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_acpi_checksum_ops
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .add
    er_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .movzx_ebx_r12_revision
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .no_pop
    push    r14
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .movzx_edx_r12_rcx_one
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0xb6, 0x14, 0x0f
    jmp     .yes
.movzx_edx_r12_rcx_one:
    pop     r14
    call    expect_r12_plus_rcx_plus_one
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x54, 0x0c, 1
    jmp     .yes
.movzx_ebx_r12_revision:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .movzx_ebx_r12_revision_real
    er_expect_comma_result
    jz      .no_pop
    er_push_expect_token_operand_result tok_byte, tok_byte_len
    jz      .movzx_eax_al_after_comma
    pop     rax
    push    r14
    call    expect_r12_plus_rcx
    test    eax, eax
    jz      .movzx_eax_mcfg_start
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x04, 0x0c
    jmp     .yes
.movzx_eax_mcfg_start:
    pop     r14
    lea     rdi, [rel tok_mcfg_alloc_start_close]
    mov     esi, tok_mcfg_alloc_start_close_len
    push    r14
    call    expect_rdi_mcfg_field
    test    eax, eax
    jz      .movzx_eax_mcfg_end
    pop     rax
    mov     r10d, 54
    jmp     .movzx_eax_mcfg_emit
.movzx_eax_mcfg_end:
    pop     r14
    lea     rdi, [rel tok_mcfg_alloc_end_close]
    mov     esi, tok_mcfg_alloc_end_close_len
    call    expect_rdi_mcfg_field
    test    eax, eax
    jz      .no_pop
    mov     r10d, 55
.movzx_eax_mcfg_emit:
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0xb6, 0x47, r10d
    jmp     .yes
.movzx_eax_al_after_comma:
    er_pop_expect_token_operand_push_result tok_al, tok_al_len
    jz      .movzx_eax_word_after_comma
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0xb6, 0xc0
    jmp     .yes
.movzx_eax_word_after_comma:
    er_pop_expect_token_operand_result tok_word, tok_word_len
    jz      .no_pop
    er_expect_token_operand_result tok_mem_ebda_seg_ptr, tok_mem_ebda_seg_ptr_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0xb7, 0x04, 0x25
    mov     edi, 0x40e
    call    append_text_u32
    jmp     .yes
.movzx_ebx_r12_revision_real:
    er_pop_expect_token_operand_push_result tok_ebx, tok_ebx_len
    jz      .movzx_eax_word
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .no_pop
    lea     rdi, [rel tok_rsdp_revision_close]
    mov     esi, tok_rsdp_revision_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x5c, 0x24, 15
    jmp     .yes
.movzx_eax_word:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .movzx_eax_al
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_word, tok_word_len
    jz      .no_pop
    er_expect_token_operand_result tok_mem_ebda_seg_ptr, tok_mem_ebda_seg_ptr_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0xb7, 0x04, 0x25
    mov     edi, 0x40e
    call    append_text_u32
    jmp     .yes
.movzx_eax_al:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .cmp_esi_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0xb6, 0xc0
    jmp     .yes
.add:
    er_match_source_token_result tok_add, tok_add_len
    jz      .shl
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .add_ecx_ebx
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_edx, tok_edx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x01, 0xd0
    jmp     .yes
.add_ecx_ebx:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .add_edi_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_push_result tok_ebx, tok_ebx_len
    jz      .add_ecx_edx
    pop     rax
    mov     r10d, 0xd9
    jmp     .add_ecx_reg_line
.add_ecx_edx:
    er_pop_expect_token_operand_result tok_edx, tok_edx_len
    jz      .no_pop
    mov     r10d, 0xd1
.add_ecx_reg_line:
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x01, r10d
    jmp     .yes
.add_edi_imm:
    er_pop_expect_token_operand_push_result tok_edi, tok_edi_len
    jz      .cmp_mem_edi
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_u32_result
    jz      .mov_esi_field_after_comma
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x81, 0xc7
    er_emit_imm_u32_value
    jmp     .yes
.shl:
    er_match_source_token_result tok_shl, tok_shl_len
    jz      .inc
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_imm8_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0xc1, 0xe0
    er_emit_imm_byte_value
    jmp     .yes
.inc:
    er_match_source_token_result tok_inc, tok_inc_len
    jz      .cmp
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0xff, 0xc1
    jmp     .yes
.cmp:
    er_match_source_token_result tok_cmp, tok_cmp_len
    jz      .setz
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .cmp_esi_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .cmp_ecx_r13d
    pop     rax
    mov     r10d, 0
    jmp     .cmp_ecx_reg_line
.cmp_ecx_r13d:
    er_pop_expect_token_operand_result tok_r13d, tok_r13d_len
    jz      .no_pop
    mov     r10d, 1
.cmp_ecx_reg_line:
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    test    r10d, r10d
    jz      .cmp_ecx_esi_emit
    er_emit_text_bytes 0x44
.cmp_ecx_esi_emit:
    er_emit_text_bytes 0x39
    test    r10d, r10d
    jz      .cmp_ecx_esi_modrm
    er_emit_text_bytes 0xe9
    jmp     .yes
.cmp_ecx_esi_modrm:
    er_emit_text_bytes 0xf1
    jmp     .yes
.cmp_esi_imm:
    er_pop_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .cmp_eax_r14d
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_u32_result
    jz      .cmp_esi_mcfg_alloc_sum
    er_expect_line_end_result
    jz      .cmp_esi_mcfg_alloc_sum
    pop     rax
    pop     rax
    er_emit_text_bytes 0x81, 0xfe
    er_emit_imm_u32_value
    jmp     .yes
.cmp_esi_mcfg_alloc_sum:
    er_pop_expect_token_operand_result tok_mcfg_allocations, tok_mcfg_allocations_len
    jz      .no_pop
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .no_pop
    er_expect_token_operand_result tok_mcfg_alloc_entry, tok_mcfg_alloc_entry_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x81, 0xfe
    mov     edi, 60
    call    append_text_u32
    jmp     .yes
.cmp_eax_r14d:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .cmp_edx_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_push_result tok_r14d, tok_r14d_len
    jz      .cmp_eax_imm_after_comma
    pop     rax
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x44, 0x39, 0xf0
    jmp     .yes
.cmp_eax_imm_after_comma:
    pop     r14
    er_expect_u32_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x81, 0xf8
    er_emit_imm_u32_value
    jmp     .yes
.cmp_edx_imm:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .cmp_eax_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_u32_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x81, 0xfa
    er_emit_imm_u32_value
    jmp     .yes
.cmp_eax_imm:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .cmp_bl_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_u32_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x81, 0xf8
    er_emit_imm_u32_value
    jmp     .yes
.cmp_bl_imm:
    er_pop_expect_token_operand_push_result tok_bl, tok_bl_len
    jz      .cmp_mem_edi
    er_expect_comma_result
    jz      .no_pop
    er_expect_imm8_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x80, 0xfb
    er_emit_imm_byte_value
    jmp     .yes
.cmp_mem_edi:
    er_pop_expect_token_operand_push_result tok_dword, tok_dword_len
    jz      .no_pop
    er_expect_token_operand_push_result tok_mem_edi, tok_mem_edi_len
    jz      .cmp_mem_rdi
    pop     rax
    mov     r10d, 0x3f
    xor     r11d, r11d
    xor     r8d, r8d
    jmp     .cmp_mem_imm
.cmp_mem_rdi:
    er_pop_expect_token_operand_push_result tok_mem_rdi, tok_mem_rdi_len
    jz      .cmp_mem_r12
    pop     rax
    mov     r10d, 0x3f
    xor     r11d, r11d
    mov     r8d, 2
    jmp     .cmp_mem_imm
.cmp_mem_r12:
    er_pop_expect_token_operand_push_result tok_mem_r12, tok_mem_r12_len
    jz      .cmp_mem_edi_plus4
    pop     rax
    mov     r10d, 0x3c
    xor     r11d, r11d
    mov     r8d, 1
    jmp     .cmp_mem_imm
.cmp_mem_edi_plus4:
    er_pop_expect_token_operand_result tok_mem_edi_open, tok_mem_edi_open_len
    jz      .no_pop
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .no_pop
    er_expect_token_operand_result tok_four_close, tok_four_close_len
    jz      .no_pop
    mov     r10d, 0x7f
    mov     r11d, 4
    xor     r8d, r8d
.cmp_mem_imm:
    er_expect_comma_result
    jz      .no_pop
    er_expect_u32_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    cmp     r8d, 2
    je      .cmp_mem_opcode
    test    r8d, r8d
    jnz     .cmp_mem_r12_prefix
    er_emit_text_bytes 0x67
    jmp     .cmp_mem_opcode
.cmp_mem_r12_prefix:
    er_emit_text_bytes 0x41
.cmp_mem_opcode:
    er_emit_text_bytes 0x81, r10d
    test    r8d, r8d
    jz      .cmp_mem_disp
    er_emit_text_bytes 0x24
.cmp_mem_disp:
    test    r11d, r11d
    jz      .cmp_mem_disp_done
    er_emit_text_bytes r11d
.cmp_mem_disp_done:
    er_emit_imm_u32_value
    jmp     .yes
.setz:
    er_match_source_token_result tok_setz, tok_setz_len
    jz      .mov_store
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x0f, 0x94, 0xc0
    jmp     .yes
.mov_store:
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .no
    er_expect_token_operand_push_result tok_mem_r12, tok_mem_r12_len
    jz      .mov_r15_rcx
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x89, 0x3c, 0x24
    jmp     .yes
.mov_r15_rcx:
    er_pop_expect_token_operand_push_result tok_r15, tok_r15_len
    jz      .mov_edi_r12d
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x89, 0xcf
    jmp     .yes
.mov_edi_r12d:
    er_pop_expect_token_operand_push_result tok_edi, tok_edi_len
    jz      .mov_esi_imm
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r12d, tok_r12d_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x44, 0x89, 0xe7
    jmp     .yes
.mov_esi_imm:
    er_pop_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .mov_field_load
    er_expect_comma_result
    jz      .no_pop
    er_expect_u32_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0xbe
    er_emit_imm_u32_value
    jmp     .yes
.mov_esi_field_after_comma:
    pop     r14
    lea     rdi, [rel tok_rsdp_length_close]
    mov     esi, tok_rsdp_length_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x8b, 0x74, 0x24, 20
    jmp     .yes
.mov_field_load:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .mov_rax_field
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_rsdp_rsdt_addr_close]
    mov     esi, tok_rsdp_rsdt_addr_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x8b, 0x44, 0x24, 16
    jmp     .yes
.mov_rax_field:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .mov_esi_field
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_rsdp_xsdt_addr_close]
    mov     esi, tok_rsdp_xsdt_addr_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x49, 0x8b, 0x44, 0x24, 24
    jmp     .yes
.mov_esi_field:
    er_pop_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .mov_store_outputs
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_rsdp_length_close]
    mov     esi, tok_rsdp_length_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x8b, 0x74, 0x24, 20
    jmp     .yes
.mov_store_outputs:
    pop     r14
    lea     rdi, [rel tok_mem_r13]
    mov     esi, tok_mem_r13_len
    mov     r10d, 0x45
    call    match_acpi_store_rax_ptr
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r14]
    mov     esi, tok_mem_r14_len
    mov     r10d, 0x06
    call    match_acpi_store_rax_ptr
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r15]
    mov     esi, tok_mem_r15_len
    call    match_acpi_store_bl_ptr
    test    eax, eax
    jnz     .yes
    jmp     .no_pop
.yes:
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false

er_fn match_acpi_store_rax_ptr
    push    r10
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    pop     r10
    er_emit_text_bytes 0x49, 0x89, r10d
    cmp     r10d, 0x45
    jne     .yes
    er_emit_zero_byte
.yes:
    er_ret_true
.no_pop:
    pop     r14
    pop     r10
    er_ret_false

er_fn match_acpi_store_bl_ptr
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_bl, tok_bl_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x41, 0x88, 0x1f
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_entry_load
    push    r10
    push    r11
    push    rbx
    push    rdi
    push    rsi
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    call    expect_rdi_sdt_header_rcx
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    pop     rsi
    pop     rdi
    pop     rbx
    pop     r11
    pop     r10
    er_emit_text_bytes r10d, r11d, ebx, 0x0f, 36
    er_ret_true
.no_pop:
    pop     r14
    pop     rsi
    pop     rdi
    pop     rbx
    pop     r11
    pop     r10
    er_ret_false

er_fn match_acpi_madt_indexed_load
    push    r10
    push    r11
    push    rdx
    push    rcx
    push    rdi
    push    rsi
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    mov     rdi, [rsp + 32]
    mov     rsi, [rsp + 24]
    call    expect_r12_plus_rcx_symbol
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rdx
    pop     r11
    pop     r10
    er_emit_text_bytes 0x45, 0x8b, r10d, 0x0c, r11d
    er_ret_true
.no_pop:
    pop     r14
    pop     rsi
    pop     rdi
    pop     rcx
    pop     rdx
    pop     r11
    pop     r10
    er_ret_false

er_fn match_acpi_mov_eax_madt_lapic
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    lea     rdi, [rel tok_madt_lapic_addr_close]
    mov     esi, tok_madt_lapic_addr_close_len
    call    expect_r12_plus_symbol_close
    test    eax, eax
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x41, 0x8b, 0x44, 0x24, 36
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_store_eax_ptr
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x41, 0x89, 0x06
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_mov_ecx_imm
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    push    r14
    er_expect_u32_result
    jz      .try_madt_entries
    pop     r11
    jmp     .value_ok
.try_madt_entries:
    er_pop_expect_token_operand_result tok_madt_entries, tok_madt_entries_len
    jz      .no_pop
    mov     qword [rel imm_u32_value], 44
.value_ok:
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_mov_r9_r8
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r8, tok_r8_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x4d, 0x89, 0xc1
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_store_r9d_ptr
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r9d, tok_r9d_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x45, 0x89, 0x0f
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_store_r10d_ptr
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r10d, tok_r10d_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x44, 0x89, 0x13
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_mov_eax_mem_r9
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_mem_r9, tok_mem_r9_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x41, 0x8b, 0x01
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_acpi_mov_rax_r9
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_r9, tok_r9_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r14
    er_emit_text_bytes 0x4c, 0x89, 0xc8
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_er_call_macro
    er_push rbx, r10, r11, r12, r13
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_emit_text_bytes 0xe8
    mov     rax, [rel text_len]
    mov     rbx, rax
    er_emit_zero_u32
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .pending_call
    mov     rax, rdx
    sub     rax, rbx
    sub     rax, 4
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], eax
    jmp     .branch
.pending_call:
    mov     rax, [rel pending_call_count]
    cmp     rax, ER_ASM_BRANCH_CAP
    jae     .bad
    mov     [rel pending_call_ptr + rax * 8], r12
    mov     [rel pending_call_len + rax * 8], r13
    mov     [rel pending_call_off + rax * 8], rbx
    inc     qword [rel pending_call_count]
.branch:
    mov     edi, 0x72
    er_emit_short_branch_result
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r10, r11, r12, r13
    ret

er_fn match_generic_common_instruction
    er_match_source_token_result tok_mov, tok_mov_len
    jnz     .mov
    er_match_source_token_result tok_test, tok_test_len
    jnz     .test
    er_match_source_token_result tok_cmp, tok_cmp_len
    jnz     .cmp
    er_match_source_token_result tok_add, tok_add_len
    jnz     .add
    er_match_source_token_result tok_sub, tok_sub_len
    jnz     .sub
    er_match_source_token_result tok_and, tok_and_len
    jnz     .and
    er_match_source_token_result tok_or, tok_or_len
    jnz     .or
    er_match_source_token_result tok_xor, tok_xor_len
    jnz     .xor
    er_match_source_token_result tok_shl, tok_shl_len
    jnz     .shl
    er_match_source_token_result tok_shr, tok_shr_len
    jnz     .shr
    er_match_source_token_result tok_dec, tok_dec_len
    jnz     .dec
    er_match_source_token_result tok_inc, tok_inc_len
    jnz     .inc
    er_match_source_token_result tok_movzx, tok_movzx_len
    jnz     .movzx
    er_match_source_token_result tok_neg, tok_neg_len
    jnz     .neg
    er_match_source_token_result tok_not, tok_not_len
    jnz     .not
    er_match_source_token_result tok_mul, tok_mul_len
    jnz     .mul
    er_match_source_token_result tok_div, tok_div_len
    jnz     .div
    er_match_source_token_result tok_lea, tok_lea_len
    jnz     .lea
    er_match_source_token_result tok_setz, tok_setz_len
    jnz     .setz
    er_match_source_token_result tok_setne, tok_setne_len
    jnz     .setne
    er_match_source_token_result tok_jz, tok_jz_len
    jnz     .jz
    er_match_source_token_result tok_je, tok_je_len
    jnz     .jz
    er_ret_false
.mov:
    call    parse_generic_two_operands
    test    eax, eax
    jz      .bad
    call    emit_generic_mov
    ret
.test:
    call    parse_generic_two_operands
    test    eax, eax
    jz      .bad
    call    emit_generic_test
    ret
.cmp:
    mov     r10d, 7
    jmp     .group1
.add:
    mov     r10d, 0
    jmp     .group1
.or:
    mov     r10d, 1
    jmp     .group1
.and:
    mov     r10d, 4
    jmp     .group1
.sub:
    mov     r10d, 5
    jmp     .group1
.xor:
    mov     r10d, 6
.group1:
    mov     [rel generic_opcode_ext], r10
    call    parse_generic_two_operands
    test    eax, eax
    jz      .bad
    call    emit_generic_group1
    ret
.shl:
    mov     r10d, 4
    jmp     .shift
.shr:
    mov     r10d, 5
.shift:
    mov     [rel generic_opcode_ext], r10
    call    parse_generic_two_operands
    test    eax, eax
    jz      .bad
    call    emit_generic_shift
    ret
.dec:
    mov     r10d, 1
    jmp     .incdec
.inc:
    xor     r10d, r10d
.incdec:
    call    parse_generic_one_reg_operand
    test    eax, eax
    jz      .bad
    call    emit_generic_incdec
    ret
.movzx:
    call    parse_generic_movzx_operands
    test    eax, eax
    jz      .bad
    call    emit_generic_movzx
    ret
.neg:
    mov     r10d, 3
    jmp     .group3
.not:
    mov     r10d, 2
    jmp     .group3
.mul:
    mov     r10d, 4
    jmp     .group3
.div:
    mov     r10d, 6
.group3:
    mov     [rel generic_opcode_ext], r10
    call    parse_generic_one_reg_operand
    test    eax, eax
    jz      .bad
    call    emit_generic_group3
    ret
.lea:
    push    r14
    call    parse_generic_lea_rsp_disp
    test    eax, eax
    jz      .lea_mem
    pop     r11
    call    emit_generic_lea_rsp_disp
    ret
.lea_mem:
    pop     r14
    call    parse_generic_lea_mem
    test    eax, eax
    jz      .bad
    call    emit_generic_lea_mem
    ret
.setz:
    mov     r10d, 0x94
    jmp     .setcc
.setne:
    mov     r10d, 0x95
.setcc:
    mov     [rel generic_opcode_ext], r10
    call    parse_generic_one_reg_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_op1_width], 8
    jne     .bad
    mov     r10, [rel generic_opcode_ext]
    call    emit_generic_setcc
    ret
.jz:
    mov     edi, 0x74
    call    emit_short_branch_operand
    ret
.bad:
    er_ret_false

er_fn parse_generic_two_operands
    call    parse_generic_operand1
    test    eax, eax
    jz      .bad
    er_expect_comma_result
    jz      .bad
    call    parse_generic_operand2
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn parse_generic_one_reg_operand
    call    parse_generic_operand1
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn parse_generic_movzx_operands
    call    parse_generic_operand1
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    cmp     qword [rel generic_op1_width], 32
    jne     .bad
    er_expect_comma_result
    jz      .bad
    push    r14
    call    parse_generic_byte_mem_operand2
    test    eax, eax
    jnz     .mem_ok
    pop     r14
    push    r14
    call    parse_generic_mem_operand
    test    eax, eax
    jz      .reg8
    pop     r11
    mov     qword [rel generic_op2_kind], 4
    mov     [rel generic_op2_reg], rdx
    mov     [rel generic_op2_imm], r8
    mov     rax, [rel generic_mem_index]
    mov     [rel generic_op2_index], rax
    mov     rax, [rel generic_mem_sym_ptr]
    mov     [rel generic_op2_sym_ptr], rax
    mov     rax, [rel generic_mem_sym_len]
    mov     [rel generic_op2_sym_len], rax
    jmp     .line_end
.mem_ok:
    pop     r11
.line_end:
    call    expect_line_end
    ret
.reg8:
    pop     r14
    call    parse_generic_operand2
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_op2_kind], 1
    jne     .bad
    cmp     qword [rel generic_op2_width], 8
    jne     .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn parse_generic_lea_rsp_disp
    call    parse_generic_operand1
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    cmp     qword [rel generic_op1_width], 64
    jne     .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_mem_rsp, tok_mem_rsp_len
    jz      .rsp_open
    pop     r11
    er_expect_line_end_result
    jz      .bad
    mov     qword [rel generic_op2_imm], 0
    er_ret_true
.rsp_open:
    er_pop_expect_token_operand_result tok_mem_rsp_open, tok_mem_rsp_open_len
    jz      .bad
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    jne     .plus
    inc     r14
    er_expect_line_end_result
    jz      .bad
    mov     qword [rel generic_op2_imm], 0
    er_ret_true
.plus:
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_u32_result
    jz      .bad
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    jne     .bad
    inc     r14
    er_expect_line_end_result
    jz      .bad
    mov     rax, [rel imm_u32_value]
    mov     [rel generic_op2_imm], rax
    er_ret_true
.bad:
    er_ret_false

er_fn parse_generic_lea_mem
    call    parse_generic_operand1
    test    eax, eax
    jz      .bad
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    er_expect_comma_result
    jz      .bad
    call    parse_generic_mem_operand
    test    eax, eax
    jz      .bad
    mov     qword [rel generic_op2_kind], 4
    mov     [rel generic_op2_reg], rdx
    mov     [rel generic_op2_imm], r8
    mov     rax, [rel generic_mem_index]
    mov     [rel generic_op2_index], rax
    mov     rax, [rel generic_mem_sym_ptr]
    mov     [rel generic_op2_sym_ptr], rax
    mov     rax, [rel generic_mem_sym_len]
    mov     [rel generic_op2_sym_len], rax
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn parse_generic_byte_mem_operand2
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    mov     qword [rel generic_op2_kind], 3
    mov     qword [rel generic_op2_width], 8
    mov     qword [rel generic_op2_index], -1
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    mov     r10d, 7
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    mov     r10d, 6
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_rdx]
    mov     esi, tok_mem_rdx_len
    mov     r10d, 2
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_rbx]
    mov     esi, tok_mem_rbx_len
    mov     r10d, 3
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    mov     r10d, 8
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r9]
    mov     esi, tok_mem_r9_len
    mov     r10d, 9
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r12]
    mov     esi, tok_mem_r12_len
    mov     r10d, 12
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r13]
    mov     esi, tok_mem_r13_len
    mov     r10d, 13
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r14]
    mov     esi, tok_mem_r14_len
    mov     r10d, 14
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    lea     rdi, [rel tok_mem_r15]
    mov     esi, tok_mem_r15_len
    mov     r10d, 15
    call    match_generic_mem_base
    test    eax, eax
    jnz     .yes
    push    r14
    call    parse_generic_rdx_plus_rbx_mem
    test    eax, eax
    jz      .generic_mem
    pop     r11
    jmp     .yes
.generic_mem:
    pop     r14
    call    parse_generic_mem_operand
    test    eax, eax
    jz      .bad
    mov     [rel generic_op2_reg], rdx
    mov     [rel generic_op2_imm], r8
    mov     rax, [rel generic_mem_sym_ptr]
    mov     [rel generic_op2_sym_ptr], rax
    mov     rax, [rel generic_mem_sym_len]
    mov     [rel generic_op2_sym_len], rax
    jmp     .yes
.bad:
    er_ret_false
.yes:
    er_ret_true

er_fn match_generic_mem_base
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no
    pop     r11
    mov     [rel generic_op2_reg], r10
    er_ret_true
.no:
    pop     r14
    er_ret_false

er_fn parse_generic_rdx_plus_rbx_mem
    er_expect_token_operand_result tok_mem_rdx_open, tok_mem_rdx_open_len
    jz      .bad
    er_expect_token_operand_result tok_plus, tok_plus_len
    jz      .bad
    er_expect_token_operand_result tok_rbx_close, tok_rbx_close_len
    jz      .bad
    mov     qword [rel generic_op2_reg], 2
    mov     qword [rel generic_op2_index], 3
    er_ret_true
.bad:
    er_ret_false

er_fn parse_generic_operand1
    push    r14
    mov     qword [rel generic_op1_index], -1
    call    parse_generic_sized_mem_operand1
    test    eax, eax
    jz      .not_sized_mem
    pop     r11
    er_ret_true
.not_sized_mem:
    pop     r14
    push    r14
    call    parse_generic_reg_operand
    test    eax, eax
    jz      .mem
    pop     r11
    mov     qword [rel generic_op1_kind], 1
    mov     [rel generic_op1_reg], rdx
    mov     [rel generic_op1_width], rcx
    er_ret_true
.mem:
    pop     r14
    call    parse_generic_mem_operand
    test    eax, eax
    jz      .bad
    mov     qword [rel generic_op1_kind], 4
    mov     [rel generic_op1_reg], rdx
    mov     [rel generic_op1_imm], r8
    mov     rax, [rel generic_mem_index]
    mov     [rel generic_op1_index], rax
    mov     rax, [rel generic_mem_sym_ptr]
    mov     [rel generic_op1_sym_ptr], rax
    mov     rax, [rel generic_mem_sym_len]
    mov     [rel generic_op1_sym_len], rax
    er_ret_true
.bad:
    er_ret_false

er_fn parse_generic_sized_mem_operand1
    push    r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    mov     r10d, 8
    call    match_generic_size_prefix
    test    eax, eax
    jnz     .have_size
    lea     rdi, [rel tok_word]
    mov     esi, tok_word_len
    mov     r10d, 16
    call    match_generic_size_prefix
    test    eax, eax
    jnz     .have_size
    lea     rdi, [rel tok_dword]
    mov     esi, tok_dword_len
    mov     r10d, 32
    call    match_generic_size_prefix
    test    eax, eax
    jnz     .have_size
    lea     rdi, [rel tok_qword]
    mov     esi, tok_qword_len
    mov     r10d, 64
    call    match_generic_size_prefix
    test    eax, eax
    jnz     .have_size
    pop     r14
    er_ret_false
.have_size:
    pop     r11
    call    parse_generic_mem_operand
    test    eax, eax
    jz      .bad
    mov     qword [rel generic_op1_kind], 4
    mov     [rel generic_op1_width], r10
    mov     [rel generic_op1_reg], rdx
    mov     [rel generic_op1_imm], r8
    mov     rax, [rel generic_mem_index]
    mov     [rel generic_op1_index], rax
    mov     rax, [rel generic_mem_sym_ptr]
    mov     [rel generic_op1_sym_ptr], rax
    mov     rax, [rel generic_mem_sym_len]
    mov     [rel generic_op1_sym_len], rax
    er_ret_true
.bad:
    er_ret_false

er_fn match_generic_size_prefix
    push    r10
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no
    pop     r11
    pop     r10
    er_ret_true
.no:
    pop     r14
    pop     r10
    er_ret_false

er_fn parse_generic_operand2
    push    r14
    mov     qword [rel generic_op2_index], -1
    call    parse_generic_reg_operand
    test    eax, eax
    jz      .imm
    pop     r11
    mov     qword [rel generic_op2_kind], 1
    mov     [rel generic_op2_reg], rdx
    mov     [rel generic_op2_width], rcx
    er_ret_true
.imm:
    pop     r14
    push    r14
    call    parse_generic_mem_operand
    test    eax, eax
    jz      .imm_real
    pop     r11
    mov     qword [rel generic_op2_kind], 4
    mov     [rel generic_op2_reg], rdx
    mov     [rel generic_op2_imm], r8
    mov     rax, [rel generic_mem_index]
    mov     [rel generic_op2_index], rax
    mov     rax, [rel generic_mem_sym_ptr]
    mov     [rel generic_op2_sym_ptr], rax
    mov     rax, [rel generic_mem_sym_len]
    mov     [rel generic_op2_sym_len], rax
    er_ret_true
.imm_real:
    pop     r14
    er_expect_value_result
    jz      .bad
    mov     qword [rel generic_op2_kind], 2
    mov     rax, [rel imm_u32_value]
    mov     [rel generic_op2_imm], rax
    er_ret_true
.bad:
    er_ret_false

; parse_generic_mem_operand() -> eax=1, rdx=base reg or -1 for RIP symbol, r8=disp.
er_fn parse_generic_mem_operand
    er_push r10, r11, r12, r13
    mov     qword [rel generic_mem_sym_ptr], 0
    mov     qword [rel generic_mem_sym_len], 0
    mov     qword [rel generic_mem_index], -1
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '['
    jne     .bad
    inc     r14
    call    skip_space_inline
    mov     r10, r14
.base:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .base_done
    cmp     al, '+'
    je      .base_done
    cmp     al, ']'
    je      .base_done
    inc     r14
    jmp     .base
.base_done:
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    call    parse_generic_reg_token
    test    eax, eax
    jz      .symbol_or_rel
    cmp     rcx, 64
    jne     .bad
    mov     r12, rdx
    xor     r13d, r13d
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    je      .close
    cmp     byte [r14], '+'
    jne     .bad
    inc     r14
    call    parse_generic_mem_index_or_disp
    test    eax, eax
    jz      .bad
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    jne     .bad
.close:
    inc     r14
    mov     rdx, r12
    mov     r8, r13
    mov     eax, 1
    jmp     .done
.symbol_or_rel:
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rel]
    mov     ecx, tok_rel_len
    er_token_eq_result
    jz      .symbol_have_name
    call    skip_space_inline
    mov     r10, r14
.rel_name:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .rel_name_done
    cmp     al, '+'
    je      .rel_name_done
    cmp     al, ']'
    je      .rel_name_done
    inc     r14
    jmp     .rel_name
.rel_name_done:
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
.symbol_have_name:
    mov     r12, -1
    xor     r13d, r13d
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    je      .symbol_close
    cmp     byte [r14], '+'
    jne     .bad
    inc     r14
    er_expect_value_result
    jz      .bad
    mov     r13, [rel imm_u32_value]
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ']'
    jne     .bad
.symbol_close:
    inc     r14
    mov     [rel generic_mem_sym_ptr], r10
    mov     [rel generic_mem_sym_len], r11
    mov     rdx, r12
    mov     r8, r13
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11, r12, r13
    ret

; parse_generic_mem_index_or_disp(base=r12, disp_out=r13) -> eax=1/0.
; Accepts either +u32 displacement or +64-bit index register.
er_fn parse_generic_mem_index_or_disp
    er_push r10, r11, r12
    call    skip_space_inline
    mov     r10, r14
.scan:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, ' '
    je      .scan_done
    cmp     al, 9
    je      .scan_done
    cmp     al, '+'
    je      .scan_done
    cmp     al, ']'
    je      .scan_done
    cmp     al, 10
    je      .bad
    cmp     al, ';'
    je      .bad
    inc     r14
    jmp     .scan
.scan_done:
    mov     r11, r14
    sub     r11, r10
    push    r14
    call    parse_generic_reg_token
    test    eax, eax
    jz      .disp
    cmp     rcx, 64
    jne     .disp
    cmp     rdx, 4
    je      .bad_pop
    pop     r11
    mov     [rel generic_mem_index], rdx
    mov     eax, 1
    jmp     .done
.disp:
    pop     r14
    er_expect_value_result
    jz      .bad
    mov     r13, [rel imm_u32_value]
    mov     eax, 1
    jmp     .done
.bad_pop:
    pop     r11
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11, r12
    ret

; parse_generic_reg_operand() -> eax=1, rdx=reg code 0..15, rcx=width bits.
er_fn parse_generic_reg_operand
    er_push r10, r11
    call    skip_space_inline
    mov     r10, r14
    call    skip_operand_token
    mov     r11, r14
    sub     r11, r10
    call    parse_generic_reg_token
    er_pop  r10, r11
    ret

; parse_generic_reg_token(r10=ptr, r11=len) -> eax=1, rdx=reg, rcx=width.
er_fn parse_generic_reg_token
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_al]
    mov     ecx, tok_al_len
    er_token_eq_result
    jnz     .al
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_cl]
    mov     ecx, tok_cl_len
    er_token_eq_result
    jnz     .cl
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_dl]
    mov     ecx, tok_dl_len
    er_token_eq_result
    jnz     .dl
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_bl]
    mov     ecx, tok_bl_len
    er_token_eq_result
    jnz     .bl
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_sil]
    mov     ecx, tok_sil_len
    er_token_eq_result
    jnz     .sil
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_dil]
    mov     ecx, tok_dil_len
    er_token_eq_result
    jnz     .dil
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r8b]
    mov     ecx, tok_r8b_len
    er_token_eq_result
    jnz     .r8b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r9b]
    mov     ecx, tok_r9b_len
    er_token_eq_result
    jnz     .r9b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r10b]
    mov     ecx, tok_r10b_len
    er_token_eq_result
    jnz     .r10b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r11b]
    mov     ecx, tok_r11b_len
    er_token_eq_result
    jnz     .r11b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r12b]
    mov     ecx, tok_r12b_len
    er_token_eq_result
    jnz     .r12b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r13b]
    mov     ecx, tok_r13b_len
    er_token_eq_result
    jnz     .r13b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r14b]
    mov     ecx, tok_r14b_len
    er_token_eq_result
    jnz     .r14b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r15b]
    mov     ecx, tok_r15b_len
    er_token_eq_result
    jnz     .r15b
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_ax]
    mov     ecx, tok_ax_len
    er_token_eq_result
    jnz     .ax
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_cx]
    mov     ecx, tok_cx_len
    er_token_eq_result
    jnz     .cx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_dx]
    mov     ecx, tok_dx_len
    er_token_eq_result
    jnz     .dxw
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_bx]
    mov     ecx, tok_bx_len
    er_token_eq_result
    jnz     .bxw
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_si]
    mov     ecx, tok_si_len
    er_token_eq_result
    jnz     .si
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_di]
    mov     ecx, tok_di_len
    er_token_eq_result
    jnz     .di
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r8w]
    mov     ecx, tok_r8w_len
    er_token_eq_result
    jnz     .r8w
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_eax]
    mov     ecx, tok_eax_len
    er_token_eq_result
    jnz     .eax
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_ecx]
    mov     ecx, tok_ecx_len
    er_token_eq_result
    jnz     .ecx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_edx]
    mov     ecx, tok_edx_len
    er_token_eq_result
    jnz     .edx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_ebx]
    mov     ecx, tok_ebx_len
    er_token_eq_result
    jnz     .ebx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_ebp]
    mov     ecx, tok_ebp_len
    er_token_eq_result
    jnz     .ebp
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_esi]
    mov     ecx, tok_esi_len
    er_token_eq_result
    jnz     .esi
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_edi]
    mov     ecx, tok_edi_len
    er_token_eq_result
    jnz     .edi
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r8d]
    mov     ecx, tok_r8d_len
    er_token_eq_result
    jnz     .r8d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r9d]
    mov     ecx, tok_r9d_len
    er_token_eq_result
    jnz     .r9d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r10d]
    mov     ecx, tok_r10d_len
    er_token_eq_result
    jnz     .r10d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r11d]
    mov     ecx, tok_r11d_len
    er_token_eq_result
    jnz     .r11d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r12d]
    mov     ecx, tok_r12d_len
    er_token_eq_result
    jnz     .r12d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r13d]
    mov     ecx, tok_r13d_len
    er_token_eq_result
    jnz     .r13d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r14d]
    mov     ecx, tok_r14d_len
    er_token_eq_result
    jnz     .r14d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r15d]
    mov     ecx, tok_r15d_len
    er_token_eq_result
    jnz     .r15d
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rax]
    mov     ecx, tok_rax_len
    er_token_eq_result
    jnz     .rax
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rcx]
    mov     ecx, tok_rcx_len
    er_token_eq_result
    jnz     .rcx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rdx]
    mov     ecx, tok_rdx_len
    er_token_eq_result
    jnz     .rdx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rbx]
    mov     ecx, tok_rbx_len
    er_token_eq_result
    jnz     .rbx
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rsp]
    mov     ecx, tok_rsp_len
    er_token_eq_result
    jnz     .rsp
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rbp]
    mov     ecx, tok_rbp_len
    er_token_eq_result
    jnz     .rbp
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rsi]
    mov     ecx, tok_rsi_len
    er_token_eq_result
    jnz     .rsi
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_rdi]
    mov     ecx, tok_rdi_len
    er_token_eq_result
    jnz     .rdi
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r8]
    mov     ecx, tok_r8_len
    er_token_eq_result
    jnz     .r8
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r9]
    mov     ecx, tok_r9_len
    er_token_eq_result
    jnz     .r9
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r10]
    mov     ecx, tok_r10_len
    er_token_eq_result
    jnz     .r10
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r11]
    mov     ecx, tok_r11_len
    er_token_eq_result
    jnz     .r11
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r12]
    mov     ecx, tok_r12_len
    er_token_eq_result
    jnz     .r12
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r13]
    mov     ecx, tok_r13_len
    er_token_eq_result
    jnz     .r13
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r14]
    mov     ecx, tok_r14_len
    er_token_eq_result
    jnz     .r14
    mov     rdi, r10
    mov     rsi, r11
    lea     rdx, [rel tok_r15]
    mov     ecx, tok_r15_len
    er_token_eq_result
    jnz     .r15
    er_ret_false
.al:   xor edx, edx    ; fallthrough width8 labels use rcx=8
       mov ecx, 8
       mov eax, 1
       ret
.cl:   mov edx, 1
       mov ecx, 8
       mov eax, 1
       ret
.dl:   mov edx, 2
       mov ecx, 8
       mov eax, 1
       ret
.bl:   mov edx, 3
       mov ecx, 8
       mov eax, 1
       ret
.sil:  mov edx, 6
       mov ecx, 8
       mov eax, 1
       ret
.dil:  mov edx, 7
       mov ecx, 8
       mov eax, 1
       ret
.r8b:  mov edx, 8
       mov ecx, 8
       mov eax, 1
       ret
.r9b:  mov edx, 9
       mov ecx, 8
       mov eax, 1
       ret
.r10b: mov edx, 10
       mov ecx, 8
       mov eax, 1
       ret
.r11b: mov edx, 11
       mov ecx, 8
       mov eax, 1
       ret
.r12b: mov edx, 12
       mov ecx, 8
       mov eax, 1
       ret
.r13b: mov edx, 13
       mov ecx, 8
       mov eax, 1
       ret
.r14b: mov edx, 14
       mov ecx, 8
       mov eax, 1
       ret
.r15b: mov edx, 15
       mov ecx, 8
       mov eax, 1
       ret
.ax:   xor edx, edx
       mov ecx, 16
       mov eax, 1
       ret
.cx:   mov edx, 1
       mov ecx, 16
       mov eax, 1
       ret
.dxw:  mov edx, 2
       mov ecx, 16
       mov eax, 1
       ret
.bxw:  mov edx, 3
       mov ecx, 16
       mov eax, 1
       ret
.si:   mov edx, 6
       mov ecx, 16
       mov eax, 1
       ret
.di:   mov edx, 7
       mov ecx, 16
       mov eax, 1
       ret
.r8w:  mov edx, 8
       mov ecx, 16
       mov eax, 1
       ret
.eax:  xor edx, edx
       mov ecx, 32
       mov eax, 1
       ret
.ecx:  mov edx, 1
       mov ecx, 32
       mov eax, 1
       ret
.edx:  mov edx, 2
       mov ecx, 32
       mov eax, 1
       ret
.ebx:  mov edx, 3
       mov ecx, 32
       mov eax, 1
       ret
.ebp:  mov edx, 5
       mov ecx, 32
       mov eax, 1
       ret
.esi:  mov edx, 6
       mov ecx, 32
       mov eax, 1
       ret
.edi:  mov edx, 7
       mov ecx, 32
       mov eax, 1
       ret
.r8d:  mov edx, 8
       mov ecx, 32
       mov eax, 1
       ret
.r9d:  mov edx, 9
       mov ecx, 32
       mov eax, 1
       ret
.r10d: mov edx, 10
       mov ecx, 32
       mov eax, 1
       ret
.r11d: mov edx, 11
       mov ecx, 32
       mov eax, 1
       ret
.r12d: mov edx, 12
       mov ecx, 32
       mov eax, 1
       ret
.r13d: mov edx, 13
       mov ecx, 32
       mov eax, 1
       ret
.r14d: mov edx, 14
       mov ecx, 32
       mov eax, 1
       ret
.r15d: mov edx, 15
       mov ecx, 32
       mov eax, 1
       ret
.rax:  xor edx, edx
       mov ecx, 64
       mov eax, 1
       ret
.rcx:  mov edx, 1
       mov ecx, 64
       mov eax, 1
       ret
.rdx:  mov edx, 2
       mov ecx, 64
       mov eax, 1
       ret
.rbx:  mov edx, 3
       mov ecx, 64
       mov eax, 1
       ret
.rsp:  mov edx, 4
       mov ecx, 64
       mov eax, 1
       ret
.rbp:  mov edx, 5
       mov ecx, 64
       mov eax, 1
       ret
.rsi:  mov edx, 6
       mov ecx, 64
       mov eax, 1
       ret
.rdi:  mov edx, 7
       mov ecx, 64
       mov eax, 1
       ret
.r8:   mov edx, 8
       mov ecx, 64
       mov eax, 1
       ret
.r9:   mov edx, 9
       mov ecx, 64
       mov eax, 1
       ret
.r10:  mov edx, 10
       mov ecx, 64
       mov eax, 1
       ret
.r11:  mov edx, 11
       mov ecx, 64
       mov eax, 1
       ret
.r12:  mov edx, 12
       mov ecx, 64
       mov eax, 1
       ret
.r13:  mov edx, 13
       mov ecx, 64
       mov eax, 1
       ret
.r14:  mov edx, 14
       mov ecx, 64
       mov eax, 1
       ret
.r15:  mov edx, 15
       mov ecx, 64
       mov eax, 1
       ret

er_fn emit_generic_rex
    ; rdi=width, rsi=reg field, rdx=rm field, r8=force byte rex.
    mov     eax, 0x40
    cmp     rdi, 64
    jne     .r
    or      eax, 0x08
.r:
    cmp     rsi, 8
    jb      .b
    or      eax, 0x04
.b:
    cmp     rdx, 8
    jb      .force
    or      eax, 0x01
.force:
    cmp     r8, 0
    jne     .emit_check
    cmp     eax, 0x40
    je      .done
.emit_check:
    er_emit_text_bytes eax
.done:
    ret

er_fn emit_generic_modrm_reg_reg
    ; rdi=opcode, rsi=width, rdx=reg field, rcx=rm field.
    er_push rbx, r12, r13
    mov     rbx, rdi
    mov     r12, rdx
    mov     r13, rcx
    cmp     rsi, 16
    jne     .rex_setup
    er_emit_text_bytes 0x66
.rex_setup:
    mov     rdi, rsi
    mov     rsi, r12
    mov     rdx, r13
    xor     r8d, r8d
    cmp     rdi, 8
    jne     .rex
    cmp     r12, 4
    jae     .byte_rex
    cmp     r13, 4
    jb      .rex
.byte_rex:
    mov     r8d, 1
.rex:
    call    emit_generic_rex
    er_emit_text_bytes ebx
    mov     rax, r12
    and     eax, 7
    shl     eax, 3
    mov     rdi, r13
    and     edi, 7
    or      edi, eax
    or      edi, 0xc0
    call    append_text_byte
    mov     eax, 1
    er_pop  rbx, r12, r13
    ret

; emit_generic_modrm_reg_rip(rdi=opcode, rsi=width, rdx=reg, r8=addend, r9=sym, r10=sym_len).
er_fn emit_generic_modrm_reg_rip
    er_push rbx, r12, r13, r14, r15
    mov     rbx, rdi
    mov     r12, rdx
    mov     r13, r8
    mov     r14, r9
    mov     r15, r10
    test    r15, r15
    jz      .bad
    cmp     rsi, 16
    jne     .rex_setup
    er_emit_text_bytes 0x66
.rex_setup:
    mov     rdi, rsi
    mov     rsi, r12
    xor     edx, edx
    xor     r8d, r8d
    call    emit_generic_rex
    er_emit_text_bytes ebx
    mov     rdx, r12
    mov     r8, r13
    mov     r9, r14
    mov     r10, r15
    call    emit_generic_modrm_rip_tail
    er_pop  rbx, r12, r13, r14, r15
    ret
.bad:
    xor     eax, eax
    er_pop  rbx, r12, r13, r14, r15
    ret

; emit_generic_modrm_rip_tail(rdx=reg field, r8=addend, r9=sym, r10=sym_len).
er_fn emit_generic_modrm_rip_tail
    er_push rbx, r12, r13, r14
    mov     rbx, rdx
    mov     r12, r8
    mov     r13, r9
    mov     r14, r10
    test    r14, r14
    jz      .bad
    mov     rdi, rbx
    and     edi, 7
    shl     edi, 3
    or      edi, 5
    call    append_text_byte
    mov     rax, [rel text_len]
    mov     rbx, rax
    er_emit_zero_u32
    mov     r10, r13
    mov     r11, r14
    call    find_label_value
    test    eax, eax
    jz      .pending
    mov     rax, rdx
    add     rax, r12
    sub     rax, rbx
    sub     rax, 4
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], eax
    mov     eax, 1
    jmp     .done
.pending:
    mov     rax, [rel pending_rel_count]
    cmp     rax, ER_ASM_BRANCH_CAP
    jae     .bad
    mov     [rel pending_rel_ptr + rax * 8], r13
    mov     [rel pending_rel_len + rax * 8], r14
    mov     [rel pending_rel_off + rax * 8], rbx
    mov     [rel pending_rel_addend + rax * 8], r12
    inc     qword [rel pending_rel_count]
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13, r14
    ret

er_fn emit_generic_modrm_reg_mem
    ; rdi=opcode, rsi=width, rdx=reg field, rcx=base field, r8=disp, r9=index or -1.
    er_push rbx, r12, r13, r14, r15
    mov     rbx, rdi
    mov     r12, rdx
    mov     r13, rcx
    mov     r14, r8
    mov     r15, r9
    cmp     rsi, 16
    jne     .rex_setup
    er_emit_text_bytes 0x66
.rex_setup:
    mov     rdi, rsi
    mov     rsi, r12
    mov     rdx, r13
    xor     r8d, r8d
    cmp     rdi, 8
    jne     .rex
    cmp     r12, 4
    jae     .byte_rex
    cmp     r13, 4
    jb      .rex
.byte_rex:
    mov     r8d, 1
.rex:
    cmp     r15, -1
    jne     .rex_sib
    call    emit_generic_rex
    jmp     .opcode
.rex_sib:
    call    emit_generic_rex_sib
.opcode:
    er_emit_text_bytes ebx
    xor     r11d, r11d
    test    r14, r14
    jz      .base_check
    cmp     r14, 127
    ja      .disp32_mod
    mov     r11d, 0x40
    jmp     .mod_ready
.disp32_mod:
    mov     r11d, 0x80
    jmp     .mod_ready
.base_check:
    cmp     r13, 5
    je      .disp8_zero
    cmp     r13, 13
    je      .disp8_zero
    jmp     .mod_ready
.disp8_zero:
    mov     r11d, 0x40
.mod_ready:
    mov     rdi, r12
    and     edi, 7
    shl     edi, 3
    mov     rax, r13
    and     eax, 7
    cmp     r15, -1
    jne     .sib
    cmp     eax, 4
    jne     .no_sib
    or      edi, 4
    or      edi, r11d
    call    append_text_byte
    mov     edi, 0x20
    mov     rax, r13
    and     eax, 7
    or      edi, eax
    call    append_text_byte
    jmp     .disp
.no_sib:
    or      edi, eax
    or      edi, r11d
    call    append_text_byte
    jmp     .disp
.sib:
    or      edi, 4
    or      edi, r11d
    call    append_text_byte
    mov     rdi, r15
    and     edi, 7
    shl     edi, 3
    mov     rax, r13
    and     eax, 7
    or      edi, eax
    call    append_text_byte
.disp:
    cmp     r11d, 0x40
    je      .disp8
    cmp     r11d, 0x80
    je      .disp32
    mov     eax, 1
    er_pop  rbx, r12, r13, r14, r15
    ret

.disp8:
    mov     rdi, r14
    call    append_text_byte
    mov     eax, 1
    er_pop  rbx, r12, r13, r14, r15
    ret
.disp32:
    mov     rdi, r14
    call    append_text_u32
    mov     eax, 1
    er_pop  rbx, r12, r13, r14, r15
    ret

; emit_generic_rex_sib(rdi=width, rsi=reg, rdx=base, r15=index, r8=force).
er_fn emit_generic_rex_sib
    mov     eax, 0x40
    cmp     rdi, 64
    jne     .r
    or      eax, 0x08
.r:
    cmp     rsi, 8
    jb      .x
    or      eax, 0x04
.x:
    cmp     r15, 8
    jb      .b
    or      eax, 0x02
.b:
    cmp     rdx, 8
    jb      .force
    or      eax, 0x01
.force:
    cmp     r8, 0
    jne     .emit_check
    cmp     eax, 0x40
    je      .done
.emit_check:
    er_emit_text_bytes eax
.done:
    ret

er_fn emit_generic_mov
    cmp     qword [rel generic_op1_kind], 4
    je      .mem_dest
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    cmp     qword [rel generic_op2_kind], 1
    je      .reg_reg
    cmp     qword [rel generic_op2_kind], 4
    je      .mem_src
    cmp     qword [rel generic_op2_kind], 2
    je      .imm
    jmp     .bad
.reg_reg:
    mov     rax, [rel generic_op1_width]
    cmp     rax, [rel generic_op2_width]
    jne     .bad
    mov     edi, 0x89
    cmp     rax, 8
    jne     .reg_reg_emit
    mov     edi, 0x88
.reg_reg_emit:
    mov     rsi, rax
    mov     rdx, [rel generic_op2_reg]
    mov     rcx, [rel generic_op1_reg]
    call    emit_generic_modrm_reg_reg
    ret
.mem_src:
    mov     rax, [rel generic_op1_width]
    mov     edi, 0x8b
    cmp     rax, 8
    jne     .mem_src_emit
    mov     edi, 0x8a
.mem_src_emit:
    cmp     qword [rel generic_op2_sym_len], 0
    jne     .mem_src_rip
    mov     rsi, rax
    mov     rdx, [rel generic_op1_reg]
    mov     rcx, [rel generic_op2_reg]
    mov     r8, [rel generic_op2_imm]
    mov     r9, [rel generic_op2_index]
    call    emit_generic_modrm_reg_mem
    ret
.mem_src_rip:
    mov     rsi, rax
    mov     rdx, [rel generic_op1_reg]
    mov     r8, [rel generic_op2_imm]
    mov     r9, [rel generic_op2_sym_ptr]
    mov     r10, [rel generic_op2_sym_len]
    call    emit_generic_modrm_reg_rip
    ret
.mem_dest:
    cmp     qword [rel generic_op2_kind], 1
    je      .mem_dest_reg
    cmp     qword [rel generic_op2_kind], 2
    je      .mem_dest_imm
    jmp     .bad
.mem_dest_reg:
    mov     rax, [rel generic_op2_width]
    mov     edi, 0x89
    cmp     rax, 8
    jne     .mem_dest_emit
    mov     edi, 0x88
.mem_dest_emit:
    cmp     qword [rel generic_op1_sym_len], 0
    jne     .mem_dest_rip
    mov     rsi, rax
    mov     rdx, [rel generic_op2_reg]
    mov     rcx, [rel generic_op1_reg]
    mov     r8, [rel generic_op1_imm]
    mov     r9, [rel generic_op1_index]
    call    emit_generic_modrm_reg_mem
    ret
.mem_dest_rip:
    mov     rsi, rax
    mov     rdx, [rel generic_op2_reg]
    mov     r8, [rel generic_op1_imm]
    mov     r9, [rel generic_op1_sym_ptr]
    mov     r10, [rel generic_op1_sym_len]
    call    emit_generic_modrm_reg_rip
    ret
.mem_dest_imm:
    mov     rax, [rel generic_op1_width]
    test    rax, rax
    jz      .bad
    mov     edi, 0xc7
    cmp     rax, 8
    jne     .mem_imm_emit
    mov     edi, 0xc6
.mem_imm_emit:
    cmp     qword [rel generic_op1_sym_len], 0
    jne     .mem_imm_rip
    mov     rsi, rax
    xor     edx, edx
    mov     rcx, [rel generic_op1_reg]
    mov     r8, [rel generic_op1_imm]
    mov     r9, [rel generic_op1_index]
    call    emit_generic_modrm_reg_mem
    jmp     .mem_imm_value
.mem_imm_rip:
    mov     rsi, rax
    xor     edx, edx
    mov     r8, [rel generic_op1_imm]
    mov     r9, [rel generic_op1_sym_ptr]
    mov     r10, [rel generic_op1_sym_len]
    call    emit_generic_modrm_reg_rip
.mem_imm_value:
    mov     rax, [rel generic_op1_width]
    cmp     rax, 8
    je      .mem_imm8
    cmp     rax, 16
    je      .mem_imm16
    mov     rdi, [rel generic_op2_imm]
    call    append_text_u32
    er_ret_true
.mem_imm16:
    mov     rax, [rel generic_op2_imm]
    mov     rdi, rax
    and     rdi, 0xff
    call    append_text_byte
    mov     rax, [rel generic_op2_imm]
    shr     rax, 8
    mov     rdi, rax
    and     rdi, 0xff
    call    append_text_byte
    er_ret_true
.mem_imm8:
    mov     rdi, [rel generic_op2_imm]
    call    append_text_byte
    er_ret_true
.imm:
    mov     rax, [rel generic_op1_width]
    cmp     rax, 8
    je      .imm8
    cmp     rax, 64
    je      .imm64_as_imm32
    mov     rdi, rax
    xor     esi, esi
    mov     rdx, [rel generic_op1_reg]
    xor     r8d, r8d
    call    emit_generic_rex
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    add     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel generic_op2_imm]
    call    append_text_u32
    er_ret_true
.imm64_as_imm32:
    mov     rdi, 64
    xor     esi, esi
    mov     rdx, [rel generic_op1_reg]
    xor     r8d, r8d
    call    emit_generic_rex
    er_emit_text_bytes 0xc7
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    or      edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel generic_op2_imm]
    call    append_text_u32
    er_ret_true
.imm8:
    mov     rdi, 8
    xor     esi, esi
    mov     rdx, [rel generic_op1_reg]
    mov     r8d, 1
    call    emit_generic_rex
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    add     edi, 0xb0
    call    append_text_byte
    mov     rdi, [rel generic_op2_imm]
    call    append_text_byte
    er_ret_true
.bad:
    er_ret_false

er_fn emit_generic_test
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    cmp     qword [rel generic_op2_kind], 1
    je      .reg_reg
    cmp     qword [rel generic_op2_kind], 2
    je      .imm
    jmp     .bad
.reg_reg:
    mov     rax, [rel generic_op1_width]
    cmp     rax, [rel generic_op2_width]
    jne     .bad
    mov     edi, 0x85
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x84
.reg_emit:
    mov     rsi, rax
    mov     rdx, [rel generic_op2_reg]
    mov     rcx, [rel generic_op1_reg]
    call    emit_generic_modrm_reg_reg
    ret
.imm:
    xor     r10d, r10d
    mov     [rel generic_opcode_ext], r10
    call    emit_generic_group_imm
    ret
.bad:
    er_ret_false

er_fn emit_generic_group1
    mov     r10, [rel generic_opcode_ext]
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    cmp     qword [rel generic_op2_kind], 1
    je      .reg_inline
    cmp     qword [rel generic_op2_kind], 2
    jne     .bad
    call    emit_generic_group_imm
    ret
.reg_inline:
    mov     rax, [rel generic_op1_width]
    cmp     rax, [rel generic_op2_width]
    jne     .bad
    cmp     r10, 0
    je      .reg_add
    cmp     r10, 1
    je      .reg_or
    cmp     r10, 4
    je      .reg_and
    cmp     r10, 5
    je      .reg_sub
    cmp     r10, 6
    je      .reg_xor
    cmp     r10, 7
    je      .reg_cmp
    jmp     .bad
.reg_add:
    mov     edi, 0x01
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x00
    jmp     .reg_emit
.reg_or:
    mov     edi, 0x09
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x08
    jmp     .reg_emit
.reg_and:
    mov     edi, 0x21
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x20
    jmp     .reg_emit
.reg_sub:
    mov     edi, 0x29
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x28
    jmp     .reg_emit
.reg_xor:
    mov     edi, 0x31
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x30
    jmp     .reg_emit
.reg_cmp:
    mov     edi, 0x39
    cmp     rax, 8
    jne     .reg_emit
    mov     edi, 0x38
.reg_emit:
    mov     rsi, rax
    mov     rdx, [rel generic_op2_reg]
    mov     rcx, [rel generic_op1_reg]
    call    emit_generic_modrm_reg_reg
    ret
.bad:
    er_ret_false

er_fn emit_generic_group_reg
    mov     rax, [rel generic_op1_width]
    cmp     rax, [rel generic_op2_width]
    jne     .bad
    cmp     r10, 0
    je      .add
    cmp     r10, 1
    je      .or
    cmp     r10, 4
    je      .and
    cmp     r10, 5
    je      .sub
    cmp     r10, 6
    je      .xor
    cmp     r10, 7
    je      .cmp
    jmp     .bad
.add:
    mov     edi, 0x01
    cmp     rax, 8
    jne     .emit
    mov     edi, 0x00
    jmp     .emit
.or:
    mov     edi, 0x09
    cmp     rax, 8
    jne     .emit
    mov     edi, 0x08
    jmp     .emit
.and:
    mov     edi, 0x21
    cmp     rax, 8
    jne     .emit
    mov     edi, 0x20
    jmp     .emit
.sub:
    mov     edi, 0x29
    cmp     rax, 8
    jne     .emit
    mov     edi, 0x28
    jmp     .emit
.xor:
    mov     edi, 0x31
    cmp     rax, 8
    jne     .emit
    mov     edi, 0x30
    jmp     .emit
.cmp:
    mov     edi, 0x39
    cmp     rax, 8
    jne     .emit
    mov     edi, 0x38
.emit:
    mov     rsi, rax
    mov     rdx, [rel generic_op2_reg]
    mov     rcx, [rel generic_op1_reg]
    call    emit_generic_modrm_reg_reg
    ret
.bad:
    er_ret_false

er_fn emit_generic_group_imm
    ; generic_opcode_ext holds the group extension selected by dispatch.
    er_push rbx, r12
    mov     rbx, [rel generic_opcode_ext]
    mov     r12, [rel generic_op1_width]
    cmp     qword [rel generic_op1_reg], 0
    jne     .normal
    cmp     r12, 8
    je      .accum
    cmp     qword [rel generic_op2_imm], 255
    jbe     .normal
.accum:
    call    emit_generic_accum_imm
    er_pop  rbx, r12
    ret
.normal:
    mov     rdi, r12
    mov     rsi, rbx
    mov     rdx, [rel generic_op1_reg]
    xor     r8d, r8d
    cmp     r12, 8
    jne     .rex
    mov     r8d, 1
.rex:
    call    emit_generic_rex
    cmp     r12, 8
    jne     .wide
    er_emit_text_bytes 0x80
    jmp     .modrm
.wide:
    cmp     qword [rel generic_op2_imm], 255
    ja      .imm32
    er_emit_text_bytes 0x83
    jmp     .modrm
.imm32:
    er_emit_text_bytes 0x81
.modrm:
    mov     rdi, rbx
    and     edi, 7
    shl     edi, 3
    mov     rax, [rel generic_op1_reg]
    and     eax, 7
    or      edi, eax
    or      edi, 0xc0
    call    append_text_byte
    cmp     r12, 8
    je      .emit_imm8
    cmp     qword [rel generic_op2_imm], 255
    ja      .emit_imm32
.emit_imm8:
    mov     rdi, [rel generic_op2_imm]
    call    append_text_byte
    mov     eax, 1
    er_pop  rbx, r12
    ret
.emit_imm32:
    mov     rdi, [rel generic_op2_imm]
    call    append_text_u32
    mov     eax, 1
    er_pop  rbx, r12
    ret

er_fn emit_generic_accum_imm
    ; rbx=group extension, r12=width.
    cmp     r12, 64
    jne     .opcode
    mov     rdi, 64
    xor     esi, esi
    xor     edx, edx
    xor     r8d, r8d
    call    emit_generic_rex
.opcode:
    cmp     rbx, 0
    je      .add
    cmp     rbx, 1
    je      .or
    cmp     rbx, 4
    je      .and
    cmp     rbx, 5
    je      .sub
    cmp     rbx, 6
    je      .xor
    cmp     rbx, 7
    je      .cmp
    er_ret_false
.add:
    mov     edi, 0x05
    cmp     r12, 8
    jne     .emit_opcode
    mov     edi, 0x04
    jmp     .emit_opcode
.or:
    mov     edi, 0x0d
    cmp     r12, 8
    jne     .emit_opcode
    mov     edi, 0x0c
    jmp     .emit_opcode
.and:
    mov     edi, 0x25
    cmp     r12, 8
    jne     .emit_opcode
    mov     edi, 0x24
    jmp     .emit_opcode
.sub:
    mov     edi, 0x2d
    cmp     r12, 8
    jne     .emit_opcode
    mov     edi, 0x2c
    jmp     .emit_opcode
.xor:
    mov     edi, 0x35
    cmp     r12, 8
    jne     .emit_opcode
    mov     edi, 0x34
    jmp     .emit_opcode
.cmp:
    mov     edi, 0x3d
    cmp     r12, 8
    jne     .emit_opcode
    mov     edi, 0x3c
.emit_opcode:
    call    append_text_byte
    mov     rdi, [rel generic_op2_imm]
    cmp     r12, 8
    jne     .imm32
    call    append_text_byte
    er_ret_true
.imm32:
    call    append_text_u32
    er_ret_true

er_fn emit_generic_shift
    cmp     qword [rel generic_op1_kind], 1
    jne     .bad
    cmp     qword [rel generic_op2_kind], 2
    jne     .bad
    mov     rdi, [rel generic_op1_width]
    mov     rsi, [rel generic_opcode_ext]
    mov     rdx, [rel generic_op1_reg]
    xor     r8d, r8d
    call    emit_generic_rex
    er_emit_text_bytes 0xc1
    mov     rdi, [rel generic_opcode_ext]
    and     edi, 7
    shl     edi, 3
    mov     rax, [rel generic_op1_reg]
    and     eax, 7
    or      edi, eax
    or      edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel generic_op2_imm]
    call    append_text_byte
    er_ret_true
.bad:
    er_ret_false

er_fn emit_generic_incdec
    mov     rdi, [rel generic_op1_width]
    mov     rsi, 1
    mov     rdx, [rel generic_op1_reg]
    xor     r8d, r8d
    call    emit_generic_rex
    er_emit_text_bytes 0xff
    mov     rax, [rel generic_op1_reg]
    and     eax, 7
    mov     edi, 0xc0
    test    r10d, r10d
    jz      .modrm
    mov     edi, 0xc8
.modrm:
    or      edi, eax
    call    append_text_byte
    er_ret_true

er_fn emit_generic_group3
    mov     rdi, [rel generic_op1_width]
    mov     rsi, [rel generic_opcode_ext]
    mov     rdx, [rel generic_op1_reg]
    xor     r8d, r8d
    cmp     rdi, 8
    jne     .rex
    mov     r8d, 1
.rex:
    call    emit_generic_rex
    mov     edi, 0xf7
    cmp     qword [rel generic_op1_width], 8
    jne     .opcode
    mov     edi, 0xf6
.opcode:
    call    append_text_byte
    mov     rdi, [rel generic_opcode_ext]
    and     edi, 7
    shl     edi, 3
    mov     rax, [rel generic_op1_reg]
    and     eax, 7
    or      edi, eax
    or      edi, 0xc0
    call    append_text_byte
    er_ret_true

er_fn emit_generic_movzx
    cmp     qword [rel generic_op2_kind], 1
    je      .reg8
    jmp     emit_generic_movzx_byte_mem
.reg8:
    mov     rdi, 32
    mov     rsi, [rel generic_op1_reg]
    mov     rdx, [rel generic_op2_reg]
    mov     r8d, 1
    call    emit_generic_rex
    er_emit_text_bytes 0x0f, 0xb6
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    shl     edi, 3
    mov     rax, [rel generic_op2_reg]
    and     eax, 7
    or      edi, eax
    or      edi, 0xc0
    call    append_text_byte
    er_ret_true

er_fn emit_generic_movzx_byte_mem
    er_push r12, r13, r14, r15
    mov     rdi, 32
    mov     rsi, [rel generic_op1_reg]
    mov     rdx, [rel generic_op2_reg]
    xor     r8d, r8d
    call    emit_generic_rex
    er_emit_text_bytes 0x0f, 0xb6
    cmp     qword [rel generic_op2_sym_len], 0
    jne     .rip
    mov     r12, [rel generic_op1_reg]
    mov     r13, [rel generic_op2_reg]
    mov     r14, [rel generic_op2_imm]
    xor     r15d, r15d
    test    r14, r14
    jz      .base_check
    cmp     r14, 127
    ja      .disp32_mod
    mov     r15d, 0x40
    jmp     .mod_ready
.disp32_mod:
    mov     r15d, 0x80
    jmp     .mod_ready
.base_check:
    cmp     r13, 5
    je      .disp8_zero
    cmp     r13, 13
    je      .disp8_zero
    jmp     .mod_ready
.disp8_zero:
    mov     r15d, 0x40
.mod_ready:
    mov     rdi, r12
    and     edi, 7
    shl     edi, 3
    mov     rax, r13
    and     eax, 7
    cmp     eax, 4
    jne     .no_sib
    or      edi, 4
    or      edi, r15d
    call    append_text_byte
    mov     edi, 0x20
    mov     rax, r13
    and     eax, 7
    or      edi, eax
    call    append_text_byte
    jmp     .disp
.no_sib:
    or      edi, eax
    or      edi, r15d
    call    append_text_byte
.disp:
    cmp     r15d, 0x40
    je      .disp8
    cmp     r15d, 0x80
    je      .disp32
    mov     eax, 1
    er_pop  r12, r13, r14, r15
    ret
.disp8:
    mov     rdi, r14
    call    append_text_byte
    mov     eax, 1
    er_pop  r12, r13, r14, r15
    ret
.disp32:
    mov     rdi, r14
    call    append_text_u32
    mov     eax, 1
    er_pop  r12, r13, r14, r15
    ret
.rip:
    mov     rdx, [rel generic_op1_reg]
    mov     r8, [rel generic_op2_imm]
    mov     r9, [rel generic_op2_sym_ptr]
    mov     r10, [rel generic_op2_sym_len]
    call    emit_generic_modrm_rip_tail
    er_pop  r12, r13, r14, r15
    ret

er_fn emit_generic_lea_rsp_disp
    mov     rdi, 64
    mov     rsi, [rel generic_op1_reg]
    mov     rdx, 4
    xor     r8d, r8d
    call    emit_generic_rex
    er_emit_text_bytes 0x8d
    cmp     qword [rel generic_op2_imm], 127
    ja      .disp32
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    shl     edi, 3
    or      edi, 0x44
    call    append_text_byte
    er_emit_text_bytes 0x24
    mov     rdi, [rel generic_op2_imm]
    call    append_text_byte
    er_ret_true
.disp32:
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    shl     edi, 3
    or      edi, 0x84
    call    append_text_byte
    er_emit_text_bytes 0x24
    mov     rdi, [rel generic_op2_imm]
    call    append_text_u32
    er_ret_true

er_fn emit_generic_lea_mem
    cmp     qword [rel generic_op2_sym_len], 0
    jne     .rip
    mov     edi, 0x8d
    mov     rsi, [rel generic_op1_width]
    mov     rdx, [rel generic_op1_reg]
    mov     rcx, [rel generic_op2_reg]
    mov     r8, [rel generic_op2_imm]
    mov     r9, [rel generic_op2_index]
    call    emit_generic_modrm_reg_mem
    ret
.rip:
    mov     edi, 0x8d
    mov     rsi, [rel generic_op1_width]
    mov     rdx, [rel generic_op1_reg]
    mov     r8, [rel generic_op2_imm]
    mov     r9, [rel generic_op2_sym_ptr]
    mov     r10, [rel generic_op2_sym_len]
    call    emit_generic_modrm_reg_rip
    ret

er_fn emit_generic_setcc
    mov     rdi, 8
    xor     esi, esi
    mov     rdx, [rel generic_op1_reg]
    mov     r8d, 1
    call    emit_generic_rex
    er_emit_text_bytes 0x0f, r10d
    mov     rdi, [rel generic_op1_reg]
    and     edi, 7
    or      edi, 0xc0
    call    append_text_byte
    er_ret_true

er_fn match_cmos_time_ops
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .movzx
    call    match_cmos_mov_time_ops
    ret
.movzx:
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .no
    call    match_cmos_movzx_time_ops
    ret
.no:
    er_ret_false

er_fn match_cmos_mov_time_ops
    er_expect_token_operand_push_result tok_dil, tok_dil_len
    jz      .r8b_al
    er_expect_comma_result
    jz      .no_pop
    er_expect_imm8_result
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r11
    er_emit_text_bytes 0x40, 0xb7
    er_emit_imm_byte_value
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
    er_ret_false
.no_pop:
    pop     r14
    er_ret_false
.yes:
    er_ret_true

er_fn match_cmos_mov_byte_from_al
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     rax
    er_emit_text_bytes 0x41, 0x88, r10d
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_cmos_store_ax
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_ax, tok_ax_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r11
    er_emit_text_bytes 0x66, 0x41, 0x89
    cmp     r10d, 0
    jne     .r13
    er_emit_text_bytes 0x04, 0x24
    jmp     .yes
.r13:
    cmp     r10d, 1
    jne     .r14
    er_emit_text_bytes 0x45, 0x00
    jmp     .yes
.r14:
    er_emit_text_bytes 0x06
.yes:
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

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
    er_ret_false
.yes:
    er_ret_true

er_fn match_cmos_movzx_high_byte
    push    r14
    push    r10
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    er_expect_comma_result
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
    er_expect_line_end_result
    jz      .no_pop_modrm
    pop     r10
    pop     rax
    er_emit_text_bytes 0x41, 0x0f, 0xb6, r10d
    er_ret_true
.no_pop:
    pop     r10
    pop     r14
    er_ret_false
.no_pop_modrm:
    pop     r10
    pop     r14
    er_ret_false

er_fn match_cmos_movzx_src
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .no_pop
    pop     rax
    er_ret_true
.no_pop:
    pop     r14
    er_ret_false

er_fn match_cmos_arith_ops
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .mov
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .no_pop
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dil, tok_dil_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x0f, 0xb6, 0xc7
    jmp     .yes
.mov:
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .add
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .no_pop
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc1
    jmp     .yes
.add:
    er_match_source_token_result tok_add, tok_add_len
    jz      .shr
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .no_pop
    er_expect_comma_result
    jz      .no_pop
    er_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .no_pop
    er_expect_line_end_result
    jz      .no_pop
    pop     r11
    er_emit_text_bytes 0x01, 0xc8
    jmp     .yes
.shr:
    er_match_source_token_result tok_shr, tok_shr_len
    jz      .imul
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .no_pop
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc1, 0xe9
    er_emit_imm_byte_value
    jmp     .yes
.imul:
    er_match_source_token_result tok_imul, tok_imul_len
    jz      .no
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .no_pop
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x6b, 0xc9
    er_emit_imm_byte_value
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false
.no_pop:
    pop     r14
    er_ret_false

er_fn match_byte_reg_ops
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .test
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .no_pop
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dil, tok_dil_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0xf8
    er_ret_true
.test:
    er_match_source_token_result tok_test, tok_test_len
    jz      .no
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xa8
    er_emit_imm_byte_value
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true

er_fn match_sized_mem_imm
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .no
    er_expect_token_operand_push_result tok_dword, tok_dword_len
    jz      .qword
    pop     r11
    er_expect_token_operand_push_result tok_mem_rdx, tok_mem_rdx_len
    jz      .mem_rcx
    pop     r11
    mov     r10d, 0x02
    jmp     .operand
.mem_rcx:
    er_pop_expect_token_operand_result tok_mem_rcx, tok_mem_rcx_len
    jz      .bad
    mov     r10d, 0x01
.operand:
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc7, r10d
    er_emit_imm_u32_value
    er_ret_true
.qword:
    er_pop_expect_token_operand_push_result tok_qword, tok_qword_len
    jz      .no_pop
    pop     r11
    er_expect_token_operand_push_result tok_mem_rdx, tok_mem_rdx_len
    jz      .qword_mem_rcx
    pop     r11
    mov     r10d, 0x02
    jmp     .qword_operand
.qword_mem_rcx:
    er_pop_expect_token_operand_result tok_mem_rcx, tok_mem_rcx_len
    jz      .bad
    mov     r10d, 0x01
.qword_operand:
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, r10d
    er_emit_imm_u32_value
    er_ret_true
.no_pop:
    pop     r14
.no:
    er_ret_false
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true

er_fn match_simple_reg_movs
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .no
    er_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rsi_rdx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf0
    jmp     .yes
.rsi_rdx:
    er_pop_expect_token_operand_push_result tok_r10, tok_r10_len
    jz      .rsi_rdx_after_r10
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf2
    jmp     .yes
.rsi_rdx_after_r10:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .edx_ecx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rsi_src_not_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd6
    jmp     .yes
.edx_ecx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .rcx_rdx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .edx_src_not_ecx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xca
    jmp     .yes
.rcx_rdx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .eax_esi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rcx_src_not_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd1
    jmp     .yes
.eax_esi:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .r14_rdx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .eax_src_not_esi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xf0
    jmp     .yes
.r14_rdx:
    er_pop_expect_token_operand_push_result tok_r14, tok_r14_len
    jz      .r12_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .r14_src_not_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xd6
.yes:
    er_ret_true
.r12_rdi:
    er_pop_expect_token_operand_push_result tok_r12, tok_r12_len
    jz      .eax_not_esi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .r12_src_not_rdi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xfc
    jmp     .yes
.eax_not_esi:
    pop     r14
    er_ret_false
.eax_src_not_esi:
    pop     r14
    er_ret_false
.rsi_src_not_rdx:
    pop     r14
    er_ret_false
.edx_src_not_ecx:
    pop     r14
    er_ret_false
.rcx_src_not_rdx:
    pop     r14
    er_ret_false
.r14_src_not_rdx:
    pop     r14
    er_ret_false
.r12_src_not_rdi:
    pop     r14
    er_ret_false
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_rel_mem_ops
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .inc
    call    expect_rel_label_value
    test    eax, eax
    jz      .no
    push    qword [rel imm_u32_value]
    er_expect_comma_result
    jz      .bad_pop
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .mov_ecx
    pop     r11
    mov     r10d, 0x05
    jmp     .mov_emit
.mov_ecx:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .mov_esi
    pop     r11
    mov     r10d, 0x0d
    jmp     .mov_emit
.mov_esi:
    er_pop_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .mov_edi
    pop     r11
    mov     r10d, 0x35
    jmp     .mov_emit
.mov_edi:
    er_pop_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad_pop
    mov     r10d, 0x3d
.mov_emit:
    er_expect_line_end_result
    jz      .bad_pop
    er_emit_text_bytes 0x89, r10d
    pop     rax
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    er_emit_rax_u32
    er_ret_true
.inc:
    er_match_source_token_result tok_inc, tok_inc_len
    jz      .no
    er_expect_token_operand_push_result tok_dword, tok_dword_len
    jz      .inc_not_rel_dword
    pop     r11
    call    expect_rel_label_value
    test    eax, eax
    jz      .bad
    push    qword [rel imm_u32_value]
    er_expect_line_end_result
    jz      .bad_pop
    er_emit_text_bytes 0xff, 0x05
    pop     rax
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    er_emit_rax_u32
    er_ret_true
.inc_not_rel_dword:
    pop     r14
    er_ret_false
.bad_pop:
    pop     r11
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_stack_macros
    er_match_source_token_result tok_er_frame_push, tok_er_frame_push_len
    jz      .frame_pop
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x55, 0x48, 0x89, 0xe5
    jmp     .yes
.frame_pop:
    er_match_source_token_result tok_er_frame_pop, tok_er_frame_pop_len
    jz      .er_push
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x5d
    jmp     .yes
.er_push:
    er_match_source_token_result tok_er_push, tok_er_push_len
    jz      .er_pop
    mov     r10d, 0
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
    jmp     .yes
.er_pop:
    er_match_source_token_result tok_er_pop, tok_er_pop_len
    jz      .push
    mov     r10d, 1
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
    jmp     .yes
.push:
    er_match_source_token_result tok_push, tok_push_len
    jz      .pop
    mov     r10d, 0
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
    jmp     .yes
.pop:
    er_match_source_token_result tok_pop, tok_pop_len
    jz      .no
    mov     r10d, 1
    call    emit_push_pop_list
    test    eax, eax
    jz      .bad
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

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
    er_expect_line_end_result
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
    er_ret_false
.yes:
    er_ret_true

er_fn match_emit_gpr_stack
    mov     rdi, r12
    mov     rsi, r13
    er_token_eq_result
    jz      .no
    cmp     r11d, 8
    jb      .low
    er_emit_text_bytes 0x41
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
    er_emit_text_bytes eax
    er_ret_true
.no:
    er_ret_false

er_fn match_test_layout_macros
    er_match_source_token_result tok_test_bss_passed_failed, tok_test_bss_passed_failed_len
    jz      .data_passed_failed
    er_expect_line_end_result
    jz      .bad
    call    emit_passed_failed_layout
    jmp     .yes
.data_passed_failed:
    er_match_source_token_result tok_test_data_passed_failed, tok_test_data_passed_failed_len
    jz      .bss_total_passed
    er_expect_line_end_result
    jz      .bad
    call    emit_passed_failed_layout
    jmp     .yes
.bss_total_passed:
    er_match_source_token_result tok_test_bss_total_passed, tok_test_bss_total_passed_len
    jz      .bss_total_passed_failed
    er_expect_line_end_result
    jz      .bad
    call    emit_total_passed_layout
    jmp     .yes
.bss_total_passed_failed:
    er_match_source_token_result tok_test_bss_total_passed_failed, tok_test_bss_total_passed_failed_len
    jz      .data_total_passed_failed
    er_expect_line_end_result
    jz      .bad
    call    emit_total_passed_failed_layout
    jmp     .yes
.data_total_passed_failed:
    er_match_source_token_result tok_test_data_total_passed_failed, tok_test_data_total_passed_failed_len
    jz      .no
    er_expect_line_end_result
    jz      .bad
    call    emit_total_passed_failed_layout
    jmp     .yes
.bad:
    er_ret_false
.yes:
    er_ret_true
.no:
    er_ret_false

er_fn match_check_zero_macro
    er_match_source_token_result tok_er_check_zero, tok_er_check_zero_len
    jz      .nonzero
    mov     r10d, 0x84
    jmp     .operand
.nonzero:
    er_match_source_token_result tok_er_check_nonzero, tok_er_check_nonzero_len
    jz      .no
    mov     r10d, 0x85
.operand:
    mov     r8d, 1
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rcx
    pop     r11
    mov     r9d, 0xd2
    jmp     .emit
.rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .rsi
    pop     r11
    mov     r9d, 0xc9
    jmp     .emit
.rsi:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .eax
    pop     r11
    mov     r9d, 0xf6
    jmp     .emit
.eax:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .rax
    pop     r11
    mov     r9d, 0xc0
    xor     r8d, r8d
    jmp     .emit
.rax:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .esi
    pop     r11
    mov     r9d, 0xc0
    mov     r8d, 1
    jmp     .emit
.esi:
    er_pop_expect_token_operand_result tok_esi, tok_esi_len
    jz      .bad
    mov     r9d, 0xf6
    xor     r8d, r8d
.emit:
    er_expect_comma_result
    jz      .bad
    test    r8d, r8d
    jz      .emit_test
    er_emit_text_bytes 0x48
.emit_test:
    er_emit_text_bytes 0x85, r9d
    mov     edi, r10d
    er_emit_short_branch_result
    jz      .bad
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_cmos_macros
    er_match_source_token_result tok_cmos_in_data, tok_cmos_in_data_len
    jz      .out_index
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0xba, 0x71
    er_emit_zero_byte
    call    emit_in_al_dx
    er_ret_true
.out_index:
    er_match_source_token_result tok_cmos_out_index, tok_cmos_out_index_len
    jz      .out_data
    mov     r10d, 0x70
    jmp     .out_macro
.out_data:
    er_match_source_token_result tok_cmos_out_data, tok_cmos_out_data_len
    jz      .no
    mov     r10d, 0x71
.out_macro:
    call    skip_space_inline
    er_push_expect_token_operand_result tok_dil, tok_dil_len
    jz      .arg_al
    pop     r11
    er_emit_text_bytes 0x40, 0x88, 0xf8
    jmp     .out_port
.arg_al:
    pop     r14
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .arg_sil
    pop     r11
    jmp     .out_port
.arg_sil:
    pop     r14
    er_push_expect_token_operand_result tok_sil, tok_sil_len
    jz      .arg_imm
    pop     r11
    er_emit_text_bytes 0x40, 0x88, 0xf0
    jmp     .out_port
.arg_imm:
    pop     r14
    er_expect_u32_result
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .bad
    er_emit_text_bytes 0xb0
    er_emit_imm_byte_value
.out_port:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0xba, r10d
    er_emit_zero_byte
    call    emit_out_dx_al
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_test_exit_passed_total_macro
    er_match_source_token_result tok_test_exit_passed_total, tok_test_exit_passed_total_len
    jz      .no
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xb8
    mov     edi, 60
    call    append_text_u32
    call    emit_xor_edi_edi
    call    emit_syscall
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_cmp_below_macro
    er_match_source_token_result tok_er_cmp_below, tok_er_cmp_below_len
    jz      .no
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r10, tok_r10_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x39, 0xd1
    mov     edi, 0x72
    er_emit_short_branch_result
    jz      .bad
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_test_call_eax_macro
    er_push r12, r13, rbx
    er_match_source_token_result tok_test_call_eax, tok_test_call_eax_len
    jz      .no
    call    skip_space_inline
    call    skip_operand_token
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    mov     rbx, [rel imm_u32_value]
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xbf
    mov     rdi, rbx
    call    append_text_u32
    er_emit_text_bytes 0xe8
    er_emit_zero_u32
    er_emit_text_bytes 0x3d
    er_emit_imm_u32_value
    er_emit_text_bytes 0x75
    mov     rbx, [rel text_len]
    er_emit_zero_byte
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
    er_emit_text_bytes 0x48, 0xff, 0x05
    mov     rax, rbx
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    er_emit_rax_u32
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_false

er_fn match_test_exit_macro
    er_match_source_token_result tok_test_exit, tok_test_exit_len
    jz      .no
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xb8
    mov     edi, 60
    call    append_text_u32
    er_emit_text_bytes 0xbf
    er_emit_imm_u32_value
    call    emit_syscall
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_lea_runtime
    er_match_source_token_result tok_lea, tok_lea_len
    jz      .no
    er_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .rsi_dst
    pop     r11
    er_expect_comma_result
    jz      .no
    call    expect_rsi_plus_rdx
    test    eax, eax
    jz      .no
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x0c, 0x16
    jmp     .yes
.rsi_dst:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .rdi_dst
    pop     r11
    er_expect_comma_result
    jz      .no
    call    expect_rsi_plus_rdx_minus_one
    test    eax, eax
    jz      .no
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x74, 0x16, 0xff
    jmp     .yes
.rdi_dst:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .rdx_dst
    pop     r11
    er_expect_comma_result
    jz      .no
    push    r14
    call    expect_rdi_plus_rdx_minus_one
    test    eax, eax
    jz      .rdi_rcx_minus_one
    pop     r11
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x7c, 0x17, 0xff
    jmp     .yes
.rdi_rcx_minus_one:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .no
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x7c, 0x0f, 0xff
    jmp     .yes
.rdx_dst:
    er_pop_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rax_dst
    pop     r11
    er_expect_comma_result
    jz      .no
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .no
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x14, 0x0f
    jmp     .yes
.rax_dst:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .no
    er_expect_comma_result
    jz      .no
    push    r14
    call    expect_rdi_minus_one
    test    eax, eax
    jz      .rax_rdi_plus_one
    pop     r11
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x47, 0xff
    jmp     .yes
.rax_rdi_plus_one:
    pop     r14
    push    r14
    call    expect_rdi_plus_one
    test    eax, eax
    jz      .rax_rdi_r8
    pop     r11
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x48, 0x8d, 0x47, 0x01
    jmp     .yes
.rax_rdi_r8:
    pop     r14
    push    r14
    call    expect_rdi_plus_r8
    test    eax, eax
    jz      .rax_r8_plain
    pop     r11
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x4a, 0x8d, 0x04, 0x07
    jmp     .yes
.rax_r8_plain:
    pop     r14
    call    expect_r8_plain_mem
    test    eax, eax
    jz      .no
    er_expect_line_end_result
    jz      .no
    er_emit_text_bytes 0x49, 0x8d, 0x00
    jmp     .yes
.yes:
    er_ret_true
.no:
    er_ret_false

er_fn match_lea_rel_label
    er_match_source_token_result tok_lea, tok_lea_len
    jz      .no
    er_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .rdi
    pop     r11
    mov     r10d, 0x35
    jmp     .operand
.rdi:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .rcx
    pop     r11
    mov     r10d, 0x3d
    jmp     .operand
.rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .rdx
    pop     r11
    mov     r10d, 0x0d
    jmp     .operand
.rdx:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .no
    mov     r10d, 0x15
.operand:
    er_expect_comma_result
    jz      .bad
    push    r10
    call    expect_rel_label_operand
    test    eax, eax
    jz      .bad_modrm
    pop     r13
    push    rax
    push    r10
    push    r11
    er_expect_line_end_result
    jz      .bad_pushed
    er_emit_text_bytes 0x48, 0x8d, r13d
    mov     rbx, [rel text_len]
    er_emit_zero_u32
    pop     r11
    pop     r10
    pop     rax
    cmp     eax, 1
    jne     .pending
    mov     rax, [rel imm_u32_value]
    mov     rdx, rbx
    add     rdx, 4
    sub     rax, rdx
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], eax
    jmp     .ok
.pending:
    mov     rax, [rel pending_call_count]
    cmp     rax, ER_ASM_BRANCH_CAP
    jae     .bad
    mov     [rel pending_call_ptr + rax * 8], r10
    mov     [rel pending_call_len + rax * 8], r11
    mov     [rel pending_call_off + rax * 8], rbx
    inc     qword [rel pending_call_count]
.ok:
    er_ret_true
.bad_pushed:
    pop     r11
    pop     r10
    pop     rax
    jmp     .bad
.bad_modrm:
    pop     r10
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

; expect_rel_label_operand() -> eax=1 known, eax=2 pending, r10/r11=name.
er_fn expect_rel_label_operand
    call    skip_space_inline
    er_expect_token_operand_result tok_rel_open, tok_rel_open_len
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
    jz      .pending
    mov     [rel imm_u32_value], rdx
    er_ret_true
.pending:
    mov     eax, 2
    ret
.bad:
    er_ret_false

er_fn match_call_label
    er_match_source_token_result tok_call, tok_call_len
    jz      .no
    jmp     emit_call_label_operand
.no:
    er_ret_false

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
    er_emit_zero_byte
    er_emit_zero_byte
    er_emit_zero_byte
    er_emit_zero_byte
    er_emit_zero_byte
    er_emit_zero_byte
    er_emit_zero_byte
    xor     edi, edi
    jmp     append_text_byte
