er_fn match_math_hash_mov
    er_match_source_token tok_mov, tok_mov_len
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_mem_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc2
    jmp     .yes
.rax_mem_rdi:
    pop     r14
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
    er_expect_token_operand tok_mem_rdi, tok_mem_rdi_len
    test    eax, eax
    jz      .rax_imm64
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x8b, 0x07
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
    er_emit_text_bytes 0x48, 0xb8
    er_emit_imm_u64_value
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
    er_ret_false
.eax_math_generic:
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_edi, tok_edi_len
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
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc2
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
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x07
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
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .r8_imm64
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf0
    jmp     .yes
.r8_imm64:
    pop     r14
    call    expect_u64_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0xb8
    er_emit_imm_u64_value
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
    push    r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .mov_rax_rdi
    pop     r11
    mov     r8d, 0xd0
    jmp     .mov64_emit
.mov_rax_rdi:
    pop     r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xf8
.mov64_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd1
    jmp     .yes
.r10_rsi:
    pop     r14
    er_expect_token_operand tok_r10, tok_r10_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf2
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_xor
    er_match_source_token tok_xor, tok_xor_len
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
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x31, 0xd0
    jmp     .yes
.rcx_rcx:
    pop     r14
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x31, 0xc9
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_shift
    er_match_source_token tok_shl, tok_shl_len
    test    eax, eax
    jz      .try_shr
    mov     r10d, 0xe2
    jmp     .operands
.try_shr:
    er_match_source_token tok_shr, tok_shr_len
    test    eax, eax
    jz      .bad
    mov     r10d, 0xea
.operands:
    er_expect_token_operand tok_rdx, tok_rdx_len
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
    er_emit_text_bytes 0x48, 0xc1, r10d
    er_emit_imm_byte_value
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_test
    er_match_source_token tok_test, tok_test_len
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
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xd2
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
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xc9
    jmp     .yes
.rsi:
    pop     r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xf6
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_cmp
    er_match_source_token tok_cmp, tok_cmp_len
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
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .rdi_rcx_cmp
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x39, 0xf7
    jmp     .yes
.rdi_rcx_cmp:
    pop     r14
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x39, 0xcf
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
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x39, 0xd0
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
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x39, 0xc8
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
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x38, 0xc2
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
    er_emit_text_bytes 0x48, 0x83, 0xf9
    er_emit_imm_byte_value
    jmp     .yes
.r10:
    pop     r14
    er_expect_token_operand tok_r10, tok_r10_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x39, 0xd1
    jmp     .yes
.ebx_cmp:
    pop     r14
    er_expect_token_operand tok_ebx, tok_ebx_len
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
    er_emit_text_bytes 0x83, 0xfb
    er_emit_imm_byte_value
    jmp     .yes
.bad_pop:
    pop     r11
.bad:
    er_ret_false
.yes:
    er_ret_true

er_fn match_math_hash_arith
    er_match_source_token tok_add, tok_add_len
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
    er_emit_text_bytes 0x49, 0x83, 0xc0
    er_emit_imm_byte_value
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
    er_emit_text_bytes 0x48, 0x83, 0xc7
    er_emit_imm_byte_value
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
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x01, 0xc8
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
    er_emit_text_bytes 0x48, 0x83, 0xc6
    er_emit_imm_byte_value
    jmp     .yes
.add_r12_imm:
    pop     r14
    er_expect_token_operand tok_r12, tok_r12_len
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
    er_emit_text_bytes 0x49, 0x83, 0xc4
    er_emit_imm_byte_value
    jmp     .yes
.sub:
    er_match_source_token tok_sub, tok_sub_len
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
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x29, 0xc8
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
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .sub_eax_imm_arith
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
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
    er_emit_text_bytes 0x2c
    er_emit_imm_byte_value
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
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
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
    er_emit_text_bytes 0x48, 0x83, 0xe9
    er_emit_imm_byte_value
    jmp     .yes
.sub_rcx_rdi_after_comma:
    pop     r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x29, 0xf9
    jmp     .yes
.sub_rcx_rdi:
    pop     r14
    jmp     .bad
.inc:
    er_match_source_token tok_inc, tok_inc_len
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
    er_emit_text_bytes 0x49, 0xff, 0xc0
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
    er_emit_text_bytes 0x48, 0xff, 0xc1
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
    er_emit_text_bytes 0x48, 0xff, 0xc7
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
    er_emit_text_bytes 0x48, 0xff, 0xc6
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
    er_emit_text_bytes 0x49, 0xff, 0xc1
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
    er_emit_text_bytes 0x49, 0xff, 0xc2
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
    er_emit_text_bytes 0x49, 0xff, 0xc0
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
    er_emit_text_bytes 0x49, 0xff, 0xc4
    jmp     .yes
.inc_r13:
    pop     r14
    er_expect_token_operand tok_r13, tok_r13_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc5
    jmp     .yes
.dec:
    er_match_source_token tok_dec, tok_dec_len
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
    er_emit_text_bytes 0x48, 0xff, 0xc9
    jmp     .yes
.dec_rdx:
    pop     r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xff, 0xca
    jmp     .yes
.bad:
    er_ret_false
.yes:
    er_ret_true

er_fn match_math_hash_branch
    er_match_source_token tok_jz, tok_jz_len
    test    eax, eax
    jz      .je
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.je:
    er_match_source_token tok_je, tok_je_len
    test    eax, eax
    jz      .jb
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.jb:
    er_match_source_token tok_jne, tok_jne_len
    test    eax, eax
    jz      .jnz
    mov     edi, 0x75
    jmp     emit_short_branch_operand
.jnz:
    er_match_source_token tok_jnz, tok_jnz_len
    test    eax, eax
    jz      .jae
    mov     edi, 0x75
    jmp     emit_short_branch_operand
.jae:
    er_match_source_token tok_jae, tok_jae_len
    test    eax, eax
    jz      .jbe
    mov     edi, 0x73
    jmp     emit_short_branch_operand
.jbe:
    er_match_source_token tok_jbe, tok_jbe_len
    test    eax, eax
    jz      .jle
    mov     edi, 0x76
    jmp     emit_short_branch_operand
.jle:
    er_match_source_token tok_jle, tok_jle_len
    test    eax, eax
    jz      .jl
    mov     edi, 0x7e
    jmp     emit_short_branch_operand
.jl:
    er_match_source_token tok_jl, tok_jl_len
    test    eax, eax
    jz      .jg
    mov     edi, 0x7c
    jmp     emit_short_branch_operand
.jg:
    er_match_source_token tok_jg, tok_jg_len
    test    eax, eax
    jz      .ja
    mov     edi, 0x7f
    jmp     emit_short_branch_operand
.ja:
    er_match_source_token tok_ja, tok_ja_len
    test    eax, eax
    jz      .jb_real
    mov     edi, 0x77
    jmp     emit_short_branch_operand
.jb_real:
    er_match_source_token tok_jb, tok_jb_len
    test    eax, eax
    jz      .jc
    mov     edi, 0x72
    jmp     emit_short_branch_operand
.jc:
    er_match_source_token tok_jc, tok_jc_len
    test    eax, eax
    jz      .jmp
    mov     edi, 0x72
    jmp     emit_short_branch_operand
.jmp:
    er_match_source_token tok_jmp, tok_jmp_len
    test    eax, eax
    jz      .bad
    mov     edi, 0xeb
    jmp     emit_short_branch_operand
.bad:
    er_ret_false

er_fn match_math_hash_crc32
    er_match_source_token tok_crc32, tok_crc32_len
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
    er_expect_token_operand tok_qword, tok_qword_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_mem_r8, tok_mem_r8_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf2, 0x49, 0x0f, 0x38, 0xf1
    er_emit_zero_byte
    jmp     .yes
.eax:
    pop     r14
    er_expect_token_operand tok_eax, tok_eax_len
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
    er_expect_token_operand tok_mem_r8, tok_mem_r8_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf2, 0x41, 0x0f, 0x38, 0xf1
    er_emit_zero_byte
    jmp     .yes
.byte:
    pop     r14
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_mem_r8, tok_mem_r8_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf2, 0x41, 0x0f, 0x38, 0xf0
    er_emit_zero_byte
    jmp     .yes
.bad:
    er_ret_false
.yes:
    er_ret_true

er_fn match_math_hash_movzx
    er_match_source_token tok_movzx, tok_movzx_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x0f, 0xb6, 0x14, 0x0f
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_mul
    er_match_source_token tok_mul, tok_mul_len
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
    er_emit_text_bytes 0x49, 0xf7, 0xe0
    er_ret_true

.rbx:
    pop     r14
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mul_rsi
    pop     r11
    mov     r8d, 0xe3
    jmp     .mul64_emit
.mul_rsi:
    pop     r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xe6
.mul64_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xf7, r8d
    er_ret_true
.try_div:
    er_match_source_token tok_div, tok_div_len
    test    eax, eax
    jz      .try_imul
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .div_rsi
    pop     r11
    mov     r8d, 0xf3
    mov     r9d, 1
    jmp     .div_emit
.div_rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .div_esi
    pop     r11
    mov     r8d, 0xf6
    mov     r9d, 1
    jmp     .div_emit
.div_esi:
    pop     r14
    er_expect_token_operand tok_esi, tok_esi_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xf6
    xor     r9d, r9d
.div_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r9d, r9d
    jz      .div_no_rex
    er_emit_text_bytes 0x48
.div_no_rex:
    er_emit_text_bytes 0xf7, r8d
    er_ret_true
.try_imul:
    er_match_source_token tok_imul, tok_imul_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xf7, 0xee
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_int_ops
    er_match_source_token tok_mov, tok_mov_len
    test    eax, eax
    jz      .cdq
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_edx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .mov_eax_edx
    pop     r11
    mov     r8d, 0xc8
    jmp     .mov32_emit
.mov_eax_edx:
    pop     r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xd0
.mov32_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, r8d
    jmp     .yes
.mov_edx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xc2
    jmp     .yes
.mov_rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_r8
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u64_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.mov_r8:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_r9
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xd0
    jmp     .yes
.mov_r9:
    pop     r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_mem_r8
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.mov_mem_r8:
    pop     r14
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_mem_r9
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .mov_mem_r8_rax
    pop     r11
    mov     r8d, 0
    jmp     .mov_mem_r8_emit
.mov_mem_r8_rax:
    pop     r14
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    mov     r8d, 1
.mov_mem_r8_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r8d, r8d
    jz      .mov_mem_r8_32
    er_emit_text_bytes 0x49
    jmp     .mov_mem_r8_opcode
.mov_mem_r8_32:
    er_emit_text_bytes 0x41
.mov_mem_r8_opcode:
    er_emit_text_bytes 0x89
    er_emit_zero_byte
    jmp     .yes
.mov_mem_r9:
    pop     r14
    lea     rdi, [rel tok_mem_r9]
    mov     esi, tok_mem_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_sized_zero
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .mov_mem_r9_rdx
    pop     r11
    mov     r8d, 0
    jmp     .mov_mem_r9_emit
.mov_mem_r9_rdx:
    pop     r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    mov     r8d, 1
.mov_mem_r9_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r8d, r8d
    jz      .mov_mem_r9_32
    er_emit_text_bytes 0x49
    jmp     .mov_mem_r9_opcode
.mov_mem_r9_32:
    er_emit_text_bytes 0x41
.mov_mem_r9_opcode:
    er_emit_text_bytes 0x89, 0x11
    jmp     .yes
.mov_sized_zero:
    pop     r14
    lea     rdi, [rel tok_dword]
    mov     esi, tok_dword_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mov_qword_zero
    pop     r11
    mov     r8d, 0
    jmp     .mov_sized_zero_mem
.mov_qword_zero:
    pop     r14
    er_expect_token_operand tok_qword, tok_qword_len
    test    eax, eax
    jz      .mov_rax
    mov     r8d, 1
.mov_sized_zero_mem:
    push    r14
    er_expect_token_operand tok_mem_rdx, tok_mem_rdx_len
    test    eax, eax
    jz      .mov_sized_zero_rcx
    pop     r11
    mov     r9d, 0x02
    jmp     .mov_sized_zero_emit
.mov_sized_zero_rcx:
    pop     r14
    er_expect_token_operand tok_mem_rcx, tok_mem_rcx_len
    test    eax, eax
    jz      .bad
    mov     r9d, 0x01
.mov_sized_zero_emit:
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .sub_eax_ecx
    pop     r11
    mov     r8d, 0x29
    jmp     .sub_eax_reg_emit
.sub_eax_ecx:
    pop     r14
    push    r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .sub_eax_imm
    pop     r11
    mov     r8d, 0x29
    mov     r9d, 0xc8
    jmp     .sub_eax_reg_emit_mod
.sub_eax_reg_emit:
    mov     r9d, 0xd0
.sub_eax_reg_emit_mod:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes r8d, r9d
    jmp     .yes
.sub_eax_imm:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 0
    jne     .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r8d, r8d
    jz      .mov_sized_zero_no_rex
    er_emit_text_bytes 0x48
.mov_sized_zero_no_rex:
    er_emit_text_bytes 0xc7, r9d
    er_emit_zero_u32
    jmp     .yes
.mov_rax:
    pop     r14
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .mov_rax_rdi
    pop     r11
    mov     r8d, 0xd0
    jmp     .mov64_emit
.mov_rax_rdi:
    pop     r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xf8
.mov64_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, r8d
    jmp     .yes
.cdq:
    er_match_source_token tok_cdq, tok_cdq_len
    test    eax, eax
    jz      .cqo
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x99
    jmp     .yes
.cqo:
    er_match_source_token tok_cqo, tok_cqo_len
    test    eax, eax
    jz      .bsr
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x99
    jmp     .yes
.bsr:
    er_match_source_token tok_bsr, tok_bsr_len
    test    eax, eax
    jz      .bsf
    mov     r8d, 0xbd
    jmp     .bit_scan
.bsf:
    er_match_source_token tok_bsf, tok_bsf_len
    test    eax, eax
    jz      .idiv
    mov     r8d, 0xbc
.bit_scan:
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .bs_rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, r8d, 0xc8
    jmp     .yes
.bs_rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .bs_rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x0f, r8d, 0xc8
    jmp     .yes
.bs_rax:
    pop     r14
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x0f, r8d, 0xc7
    jmp     .yes
.idiv:
    er_match_source_token tok_idiv, tok_idiv_len
    test    eax, eax
    jz      .xor
    er_expect_token_operand tok_esi, tok_esi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf7, 0xfe
    jmp     .yes
.xor:
    er_match_source_token tok_xor, tok_xor_len
    test    eax, eax
    jz      .sub
    mov     r8d, 0x31
    jmp     .eax_edx_arith
.sub:
    er_match_source_token tok_sub, tok_sub_len
    test    eax, eax
    jz      .add
    mov     r8d, 0x29
    push    r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .sub_reg
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .sub_eax_ecx_int
    pop     r11
    mov     r9d, 0xd0
    jmp     .sub_eax_reg_emit_int
.sub_eax_ecx_int:
    pop     r14
    push    r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .sub_eax_imm_int
    pop     r11
    mov     r9d, 0xc8
.sub_eax_reg_emit_int:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x29, r9d
    jmp     .yes
.sub_eax_imm_int:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .sub_eax_imm32
    er_emit_text_bytes 0x83, 0xe8
    er_emit_imm_byte_value
    jmp     .yes
.sub_eax_imm32:
    er_emit_text_bytes 0x2d
    er_emit_imm_u32_value
    jmp     .yes
.sub_reg:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sub_reg_not_rcx
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
    er_emit_text_bytes 0x48, 0x83, 0xe9
    er_emit_imm_byte_value
    jmp     .yes
.sub_reg_not_rcx:
    pop     r14
    jmp     .eax_edx_arith
.add:
    er_match_source_token tok_add, tok_add_len
    test    eax, eax
    jz      .and
    mov     r8d, 0x01
    push    r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .add_reg
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .add_eax_imm_int
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x01, 0xd0
    jmp     .yes
.add_eax_imm_int:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .add_eax_imm32
    er_emit_text_bytes 0x83, 0xc0
    er_emit_imm_byte_value
    jmp     .yes
.add_eax_imm32:
    er_emit_text_bytes 0x05
    er_emit_imm_u32_value
    jmp     .yes
.add_reg:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_reg_not_r8
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
    er_emit_text_bytes 0x49, 0x83, 0xc0
    er_emit_imm_byte_value
    jmp     .yes
.add_reg_not_r8:
    pop     r14
    jmp     .eax_edx_arith
.and:
    er_match_source_token tok_and, tok_and_len
    test    eax, eax
    jz      .test
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_edx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x25
    er_emit_imm_u32_value
    jmp     .yes
.and_edx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x81, 0xe2
    er_emit_imm_u32_value
    jmp     .yes
.and_rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_rdx
    pop     r11
    mov     r8d, 0xc8
    jmp     .and64_reg
.and_rdx:
    pop     r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xca
.and64_reg:
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x21, r8d
    jmp     .yes
.test:
    er_match_source_token tok_test, tok_test_len
    test    eax, eax
    jz      .shr
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_rax
    pop     r11
    mov     r8d, 0xc0
    lea     r10, [rel tok_eax]
    mov     r11d, tok_eax_len
    jmp     .test32_same
.test_rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_esi
    pop     r11
    mov     r8d, 0xc0
    lea     r10, [rel tok_rax]
    mov     r11d, tok_rax_len
    jmp     .test64_same
.test_esi:
    pop     r14
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_rsi
    pop     r11
    mov     r8d, 0xf6
    lea     r10, [rel tok_esi]
    mov     r11d, tok_esi_len
    jmp     .test32_same
.test_rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_edi
    pop     r11
    mov     r8d, 0xf6
    lea     r10, [rel tok_rsi]
    mov     r11d, tok_rsi_len
    jmp     .test64_same
.test_edi:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_rdi
    pop     r11
    mov     r8d, 0xff
    lea     r10, [rel tok_edi]
    mov     r11d, tok_edi_len
    jmp     .test32_same
.test_rdi:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_rdx
    pop     r11
    mov     r8d, 0xff
    lea     r10, [rel tok_rdi]
    mov     r11d, tok_rdi_len
    jmp     .test64_same
.test_rdx:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .test_rcx
    pop     r11
    mov     r8d, 0xd2
    lea     r10, [rel tok_rdx]
    mov     r11d, tok_rdx_len
    jmp     .test64_same
.test_rcx:
    pop     r14
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .bad
    mov     r8d, 0xc9
    lea     r10, [rel tok_rcx]
    mov     r11d, tok_rcx_len
    jmp     .test64_same
.test32_same:
    call    expect_comma
    test    eax, eax
    jz      .bad
    mov     rdi, r10
    mov     rsi, r11
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x85, r8d
    jmp     .yes
.test64_same:
    call    expect_comma
    test    eax, eax
    jz      .bad
    mov     rdi, r10
    mov     rsi, r11
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, r8d
    jmp     .yes
.shr:
    er_match_source_token tok_shr, tok_shr_len
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .shr_rax
    pop     r11
    mov     r8d, 0
    mov     r9d, 0xe8
    jmp     .shr_imm
.shr_rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .shr_edx
    pop     r11
    mov     r8d, 1
    mov     r9d, 0xe8
    jmp     .shr_imm
.shr_edx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .shr_rdx
    pop     r11
    mov     r8d, 0
    mov     r9d, 0xea
    jmp     .shr_imm
.shr_rdx:
    pop     r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    mov     r8d, 1
    mov     r9d, 0xea
.shr_imm:
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    test    r8d, r8d
    jz      .shr32_emit
    er_emit_text_bytes 0x48
.shr32_emit:
    er_emit_text_bytes 0xc1, r9d
    er_emit_imm_byte_value
    jmp     .yes
.eax_edx_arith:
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edx_edx_arith
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .eax_ecx_arith
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes r8d, 0xd0
    jmp     .yes
.eax_ecx_arith:
    pop     r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes r8d, 0xc8
    jmp     .yes
.edx_edx_arith:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_rdx_arith
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes r8d, 0xd2
    jmp     .yes
.rax_rdx_arith:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdx_rdx_arith
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, r8d, 0xd0
    jmp     .yes
.rdx_rdx_arith:
    pop     r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, r8d, 0xd2
    jmp     .yes
.yes:
    er_ret_true
.bad:
    er_ret_false
.no:
    er_ret_false

er_fn match_cmp_dil_imm8
    er_match_source_token tok_cmp, tok_cmp_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_dil, tok_dil_len
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
    er_ret_false

er_fn match_test_edi_edi
    er_match_source_token tok_test, tok_test_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_in_al_dx
    er_match_source_token tok_in, tok_in_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_dx, tok_dx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_out_dx_al
    er_match_source_token tok_out, tok_out_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_dx, tok_dx_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_mov_eax_imm32
    er_match_source_token tok_mov, tok_mov_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_eax, tok_eax_len
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
    er_ret_false

; match add/sub eax, imm8. r10d=0 for add, 1 for sub.
er_fn match_addsub_eax_imm8
    er_match_source_token tok_add, tok_add_len
    test    eax, eax
    jz      .try_sub
    xor     r10d, r10d
    jmp     .operands
.try_sub:
    er_match_source_token tok_sub, tok_sub_len
    test    eax, eax
    jz      .bad
    mov     r10d, 1
.operands:
    er_expect_token_operand tok_eax, tok_eax_len
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
    er_ret_false

er_fn match_xor_eax_eax
    er_match_source_token tok_xor, tok_xor_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_xor_edi_edi
    er_match_source_token tok_xor, tok_xor_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_ret_line
    er_match_source_token tok_ret, tok_ret_len
    test    eax, eax
    jnz     .line_end
    er_match_source_token tok_er_ret, tok_er_ret_len
    test    eax, eax
    jz      .bad
.line_end:
    call    expect_line_end
    ret
.bad:
    er_ret_false
