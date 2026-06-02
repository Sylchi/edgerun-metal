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
    er_emit_text_bytes 0xb8
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_mov_rax_imm32
    er_emit_text_bytes 0x48, 0xc7, 0xc0
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_xor_edi_edi
    er_emit_text_bytes 0x31
    mov     edi, 0xff
    jmp     append_text_byte

er_fn emit_xor_eax_eax
    er_emit_text_bytes 0x31
    mov     edi, 0xc0
    jmp     append_text_byte

er_fn emit_mov_eax_edi
    er_emit_text_bytes 0x89
    mov     edi, 0xf8
    jmp     append_text_byte

er_fn emit_add_eax_imm8
    er_emit_text_bytes 0x83, 0xc0
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_byte

er_fn emit_sub_eax_imm8
    er_emit_text_bytes 0x83, 0xe8
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_byte

er_fn emit_cmp_dil_imm8
    er_emit_text_bytes 0x40, 0x80, 0xff
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_byte

er_fn emit_jb_placeholder
    er_emit_text_bytes 0x72
    mov     rax, [rel text_len]
    mov     [rel branch1_patch_off], rax
    xor     edi, edi
    jmp     append_text_byte

er_fn emit_jnz_placeholder
    er_emit_text_bytes 0x75
    mov     rax, [rel text_len]
    mov     [rel branch1_patch_off], rax
    xor     edi, edi
    jmp     append_text_byte

er_fn emit_ja_placeholder
    er_emit_text_bytes 0x77
    mov     rax, [rel text_len]
    mov     [rel branch2_patch_off], rax
    xor     edi, edi
    jmp     append_text_byte

er_fn emit_mov_edi_imm32
    er_emit_text_bytes 0xbf
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_mov_rdi_imm32
    er_emit_text_bytes 0x48, 0xc7, 0xc7
    mov     rdi, [rel imm_u32_value]
    jmp     append_text_u32

er_fn emit_syscall
    er_emit_text_bytes 0x0f
    mov     edi, 0x05
    jmp     append_text_byte

er_fn emit_ret
    mov     edi, 0xc3
    jmp     append_text_byte

er_fn emit_test_edi_edi
    er_emit_text_bytes 0x85
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
    er_emit_shifted_text_bytes 4
    er_pop  rbx
    ret

er_fn append_text_u64
    er_push rbx
    mov     rbx, rdi
    er_emit_shifted_text_bytes 8
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

er_fn patch_near_branch_to_current
    mov     rax, [rel text_len]
    sub     rax, rdi
    sub     rax, 4
    lea     rdx, [rel text_buf]
    add     rdx, rdi
    mov     [rdx], eax
    ret

er_fn patch_call_to_current
    mov     rax, [rel text_len]
    sub     rax, rdi
    sub     rax, 4
    lea     rdx, [rel text_buf]
    add     rdx, rdi
    mov     [rdx], eax
    ret

; patch_rel32_to_current(rdi=disp offset, rsi=addend).
er_fn patch_rel32_to_current
    mov     rax, [rel text_len]
    add     rax, rsi
    sub     rax, rdi
    sub     rax, 4
    lea     rdx, [rel text_buf]
    add     rdx, rdi
    mov     [rdx], eax
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
    er_match_source_token_result tok_er_in_al_dx_sym, tok_er_in_al_dx_sym_len
    jnz     .inline_in_al_dx
    er_match_source_token_result tok_er_out_dx_al_sym, tok_er_out_dx_al_sym_len
    jnz     .inline_out_dx_al
    er_expect_line_end_result
    jz      .bad
    cmp     ebx, 0xeb
    jne     .near_cond
    er_emit_text_bytes 0xe9
    jmp     .near_offset
.near_cond:
    er_emit_text_bytes 0x0f
    lea     edi, [ebx + 0x10]
    call    append_text_byte
.near_offset:
    mov     rax, [rel text_len]
    mov     rbx, rax
    er_emit_zero_u32
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .pending
    mov     rax, rdx
    sub     rax, rbx
    sub     rax, 4
    cmp     rax, -128
    jl      .patch_near
    cmp     rax, 127
    jg      .patch_near
.patch_near:
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], eax
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
.inline_in_al_dx:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xec
    mov     eax, 1
    jmp     .done
.inline_out_dx_al:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xee
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; emit_call_label_operand() -> eax=1/0.
er_fn emit_call_label_operand
    er_push rbx, r12, r13
    call    skip_space_inline
    mov     r12, r14
    call    skip_operand_token
    mov     r13, r14
    sub     r13, r12
    test    r13, r13
    jz      .bad
    er_match_source_token_result tok_er_in_al_dx_sym, tok_er_in_al_dx_sym_len
    jnz     .inline_in_al_dx
    er_match_source_token_result tok_er_out_dx_al_sym, tok_er_out_dx_al_sym_len
    jnz     .inline_out_dx_al
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xe8
    mov     rax, [rel text_len]
    mov     rbx, rax
    er_emit_zero_u32
    mov     r10, r12
    mov     r11, r13
    call    find_label_value
    test    eax, eax
    jz      .pending
    mov     rax, rdx
    sub     rax, rbx
    sub     rax, 4
    lea     rdx, [rel text_buf]
    mov     [rdx + rbx], eax
    mov     eax, 1
    jmp     .done
.pending:
    mov     rax, [rel pending_call_count]
    cmp     rax, ER_ASM_BRANCH_CAP
    jae     .bad
    mov     [rel pending_call_ptr + rax * 8], r12
    mov     [rel pending_call_len + rax * 8], r13
    mov     [rel pending_call_off + rax * 8], rbx
    inc     qword [rel pending_call_count]
    mov     eax, 1
    jmp     .done
.inline_in_al_dx:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xec
    mov     eax, 1
    jmp     .done
.inline_out_dx_al:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xee
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; expect_operand(token, len) -> eax=1/0.
