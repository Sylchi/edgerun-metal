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
    call    match_ret_line
    test    eax, eax
    jz      .mov
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
    push    r14
    call    match_more_runtime_ops
    test    eax, eax
    jz      .math_mov_after_more
    pop     r11
    mov     eax, 1
    ret
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
    call    match_math_hash_mov
    test    eax, eax
    jnz     .math_mov_done
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .xor
    xor     eax, eax
    ret
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
    jz      .call
    mov     eax, 1
    ret
.call:
    call    match_call_label
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
    call    match_lea_runtime
    test    eax, eax
    jz      .lea_rel
    mov     eax, 1
    ret
.lea_rel:
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

