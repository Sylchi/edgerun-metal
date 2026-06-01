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
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_in_al_dx_sym]
    mov     ecx, tok_er_in_al_dx_sym_len
    call    token_eq
    test    eax, eax
    jnz     .inline_in_al_dx
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_out_dx_al_sym]
    mov     ecx, tok_er_out_dx_al_sym_len
    call    token_eq
    test    eax, eax
    jnz     .inline_out_dx_al
    call    expect_line_end
    test    eax, eax
    jz      .bad
    cmp     ebx, 0xeb
    jne     .near_cond
    mov     edi, 0xe9
    call    append_text_byte
    jmp     .near_offset
.near_cond:
    mov     edi, 0x0f
    call    append_text_byte
    lea     edi, [ebx + 0x10]
    call    append_text_byte
.near_offset:
    mov     rax, [rel text_len]
    mov     rbx, rax
    xor     edi, edi
    call    append_text_u32
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
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xec
    call    append_text_byte
    mov     eax, 1
    jmp     .done
.inline_out_dx_al:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xee
    call    append_text_byte
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
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_in_al_dx_sym]
    mov     ecx, tok_er_in_al_dx_sym_len
    call    token_eq
    test    eax, eax
    jnz     .inline_in_al_dx
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_er_out_dx_al_sym]
    mov     ecx, tok_er_out_dx_al_sym_len
    call    token_eq
    test    eax, eax
    jnz     .inline_out_dx_al
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xe8
    call    append_text_byte
    mov     rax, [rel text_len]
    mov     rbx, rax
    xor     edi, edi
    call    append_text_u32
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
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xec
    call    append_text_byte
    mov     eax, 1
    jmp     .done
.inline_out_dx_al:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xee
    call    append_text_byte
    mov     eax, 1
    jmp     .done
.bad:
    mov     qword [rel exit_subset_bad], 1
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

; expect_operand(token, len) -> eax=1/0.
