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
    cmp     qword [rel generic_instr_mode], 0
    jne     .eax_math_generic
    cmp     qword [rel exit_instr_step], 0
    jne     .eax_math_generic
    pop     r14
    xor     eax, eax
    ret
.eax_math_generic:
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
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_cmp
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .rdi_rcx_cmp
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xf7
    call    append_text_byte
    jmp     .yes
.rdi_rcx_cmp:
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
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xcf
    call    append_text_byte
    jmp     .yes
.eax_cmp:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_cmp_real
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
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xd0
    call    append_text_byte
    jmp     .yes
.eax_cmp_real:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dl_al_cmp
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
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.dl_al_cmp:
    pop     r14
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_cmp_no_pop
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0xc2
    call    append_text_byte
    jmp     .yes
.rcx_cmp_no_pop:
    pop     r14
.rcx_cmp:
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .ebx_cmp
    pop     r11
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
.ebx_cmp:
    pop     r14
    lea     rdi, [rel tok_ebx]
    mov     esi, tok_ebx_len
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
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xfb
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
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
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_r8_imm
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
    call    emit_add_eax_imm8
    jmp     .yes
.add_r8_imm:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_rdi_imm
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
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.add_rdi_imm:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_rsi_imm
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.add_rsi_imm:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_rsi_imm_real
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
    mov     edi, 0x01
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.add_rsi_imm_real:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_r12_imm
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.add_r12_imm:
    pop     r14
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
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
    mov     edi, 0xc4
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
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sub_eax_first
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
    mov     edi, 0x29
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.sub_eax_first:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sub_al
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    expect_operand
    test    eax, eax
    jz      .sub_eax_imm_arith
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x29
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.sub_eax_imm_arith:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_sub_eax_imm8
    jmp     .yes
.sub_al:
    pop     r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sub_eax_after
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x2c
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.sub_eax_after:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sub_rcx_imm
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
    mov     edi, 0x29
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.sub_rcx_imm:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sub_rcx_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .sub_rcx_rdi_after_comma
    pop     r11
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
.sub_rcx_rdi_after_comma:
    pop     r14
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
    mov     edi, 0x29
    call    append_text_byte
    mov     edi, 0xf9
    call    append_text_byte
    jmp     .yes
.sub_rcx_rdi:
    pop     r14
    jmp     .bad
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
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_rdi
    pop     r11
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
.inc_rdi:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_rsi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    jmp     .yes
.inc_rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_r9
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    jmp     .yes
.inc_r9:
    pop     r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_r10
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.inc_r10:
    pop     r14
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_r8_again
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc2
    call    append_text_byte
    jmp     .yes
.inc_r8_again:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_r12
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
.inc_r12:
    pop     r14
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .inc_r13
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc4
    call    append_text_byte
    jmp     .yes
.inc_r13:
    pop     r14
    lea     rdi, [rel tok_r13]
    mov     esi, tok_r13_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xc5
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
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dec_rdx
    pop     r11
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
.dec_rdx:
    pop     r14
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
    mov     edi, 0xff
    call    append_text_byte
    mov     edi, 0xca
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
    jz      .je
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.je:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_je]
    mov     ecx, tok_je_len
    call    token_eq
    test    eax, eax
    jz      .jb
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.jb:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jne]
    mov     ecx, tok_jne_len
    call    token_eq
    test    eax, eax
    jz      .jnz
    mov     edi, 0x75
    jmp     emit_short_branch_operand
.jnz:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jnz]
    mov     ecx, tok_jnz_len
    call    token_eq
    test    eax, eax
    jz      .jae
    mov     edi, 0x75
    jmp     emit_short_branch_operand
.jae:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jae]
    mov     ecx, tok_jae_len
    call    token_eq
    test    eax, eax
    jz      .jbe
    mov     edi, 0x73
    jmp     emit_short_branch_operand
.jbe:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jbe]
    mov     ecx, tok_jbe_len
    call    token_eq
    test    eax, eax
    jz      .jle
    mov     edi, 0x76
    jmp     emit_short_branch_operand
.jle:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jle]
    mov     ecx, tok_jle_len
    call    token_eq
    test    eax, eax
    jz      .jl
    mov     edi, 0x7e
    jmp     emit_short_branch_operand
.jl:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jl]
    mov     ecx, tok_jl_len
    call    token_eq
    test    eax, eax
    jz      .jg
    mov     edi, 0x7c
    jmp     emit_short_branch_operand
.jg:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jg]
    mov     ecx, tok_jg_len
    call    token_eq
    test    eax, eax
    jz      .ja
    mov     edi, 0x7f
    jmp     emit_short_branch_operand
.ja:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_ja]
    mov     ecx, tok_ja_len
    call    token_eq
    test    eax, eax
    jz      .jb_real
    mov     edi, 0x77
    jmp     emit_short_branch_operand
.jb_real:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jb]
    mov     ecx, tok_jb_len
    call    token_eq
    test    eax, eax
    jz      .jc
    mov     edi, 0x72
    jmp     emit_short_branch_operand
.jc:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_jc]
    mov     ecx, tok_jc_len
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
    jz      .try_div
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rbx
    pop     r11
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
.rbx:
    pop     r14
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xf7
    call    append_text_byte
    mov     edi, 0xe3
    call    append_text_byte
    mov     eax, 1
    ret
.try_div:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_div]
    mov     ecx, tok_div_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xf7
    call    append_text_byte
    mov     edi, 0xf3
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

er_fn match_xor_edi_edi
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
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

