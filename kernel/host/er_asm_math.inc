er_fn match_math_hash_mov
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .bad
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rax_mem_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc2
    jmp     .yes
.rax_mem_rdi:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .eax_edi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .rax_imm64
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x8b, 0x07
    jmp     .yes
.rax_imm64:
    pop     r14
    er_expect_u64_result
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    jbe     .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xb8
    er_emit_imm_u64_value
    jmp     .yes
.eax_edi:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .rdx_rax
    cmp     qword [rel generic_instr_mode], 0
    jne     .eax_math_generic
    cmp     qword [rel exit_instr_step], 0
    jne     .eax_math_generic
    pop     r14
    er_ret_false
.eax_math_generic:
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_mov_eax_edi
    jmp     .yes
.rdx_rax:
    er_pop_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .mem_rdi_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc2
    jmp     .yes
.mem_rdi_rax:
    er_pop_expect_token_operand_push_result tok_mem_rdi, tok_mem_rdi_len
    jz      .r8_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x07
    jmp     .yes
.r8_rsi:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rcx_rdx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .r8_imm64
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf0
    jmp     .yes
.r8_imm64:
    pop     r14
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xb8
    er_emit_imm_u64_value
    jmp     .yes
.rcx_rdx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .r10_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .mov_rax_rdi
    pop     r11
    mov     r8d, 0xd0
    jmp     .mov64_emit
.mov_rax_rdi:
    er_pop_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    mov     r8d, 0xf8
.mov64_emit:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd1
    jmp     .yes
.r10_rsi:
    er_pop_expect_token_operand_result tok_r10, tok_r10_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf2
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_xor
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .bad
    er_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .rcx_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x31, 0xd0
    jmp     .yes
.rcx_rcx:
    er_pop_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x31, 0xc9
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_shift
    er_match_source_token_result tok_shl, tok_shl_len
    jz      .try_shr
    mov     r10d, 0xe2
    jmp     .operands
.try_shr:
    er_match_source_token_result tok_shr, tok_shr_len
    jz      .bad
    mov     r10d, 0xea
.operands:
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc1, r10d
    er_emit_imm_byte_value
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_test
    er_match_source_token_result tok_test, tok_test_len
    jz      .bad
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xd2
    jmp     .yes
.rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xc9
    jmp     .yes
.rsi:
    er_pop_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xf6
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_cmp
    er_match_source_token_result tok_cmp, tok_cmp_len
    jz      .bad
    er_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .eax_cmp
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .rdi_rcx_cmp
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x39, 0xf7
    jmp     .yes
.rdi_rcx_cmp:
    er_pop_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x39, 0xcf
    jmp     .yes
.eax_cmp:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .eax_cmp_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x39, 0xd0
    jmp     .yes
.eax_cmp_real:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .dl_al_cmp
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x39, 0xc8
    jmp     .yes
.dl_al_cmp:
    er_pop_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .rcx_cmp_no_pop
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x38, 0xc2
    jmp     .yes
.rcx_cmp_no_pop:
    pop     r14
.rcx_cmp:
    er_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .ebx_cmp
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_imm8_result
    jz      .r10
    er_expect_line_end_result
    jz      .bad_pop
    pop     r11
    er_emit_text_bytes 0x48, 0x83, 0xf9
    er_emit_imm_byte_value
    jmp     .yes
.r10:
    er_pop_expect_token_operand_result tok_r10, tok_r10_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x39, 0xd1
    jmp     .yes
.ebx_cmp:
    er_pop_expect_token_operand_result tok_ebx, tok_ebx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
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
    er_match_source_token_result tok_add, tok_add_len
    jz      .sub
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .add_r8_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_add_eax_imm8
    jmp     .yes
.add_r8_imm:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .add_rdi_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x83, 0xc0
    er_emit_imm_byte_value
    jmp     .yes
.add_rdi_imm:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .add_rsi_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x83, 0xc7
    er_emit_imm_byte_value
    jmp     .yes
.add_rsi_imm:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .add_rsi_imm_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x01, 0xc8
    jmp     .yes
.add_rsi_imm_real:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .add_r12_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x83, 0xc6
    er_emit_imm_byte_value
    jmp     .yes
.add_r12_imm:
    er_pop_expect_token_operand_result tok_r12, tok_r12_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x83, 0xc4
    er_emit_imm_byte_value
    jmp     .yes
.sub:
    er_match_source_token_result tok_sub, tok_sub_len
    jz      .inc
    er_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .sub_eax_first
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x29, 0xc8
    jmp     .yes
.sub_eax_first:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .sub_al
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .sub_eax_imm_arith
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
    jmp     .yes
.sub_eax_imm_arith:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_sub_eax_imm8
    jmp     .yes
.sub_al:
    er_pop_expect_token_operand_push_result tok_al, tok_al_len
    jz      .sub_eax_after
    pop     r11
    er_expect_comma_result
    jz      .bad
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x2c
    er_emit_imm_byte_value
    jmp     .yes
.sub_eax_after:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .sub_rcx_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
    jmp     .yes
.sub_rcx_imm:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .sub_rcx_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_imm8_result
    jz      .sub_rcx_rdi_after_comma
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x83, 0xe9
    er_emit_imm_byte_value
    jmp     .yes
.sub_rcx_rdi_after_comma:
    er_pop_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x29, 0xf9
    jmp     .yes
.sub_rcx_rdi:
    pop     r14
    jmp     .bad
.inc:
    er_match_source_token_result tok_inc, tok_inc_len
    jz      .dec
    er_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .inc_rcx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc0
    jmp     .yes
.inc_rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .inc_rdi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xff, 0xc1
    jmp     .yes
.inc_rdi:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .inc_rsi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xff, 0xc7
    jmp     .yes
.inc_rsi:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .inc_r9
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xff, 0xc6
    jmp     .yes
.inc_r9:
    er_pop_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .inc_r10
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc1
    jmp     .yes
.inc_r10:
    er_pop_expect_token_operand_push_result tok_r10, tok_r10_len
    jz      .inc_r8_again
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc2
    jmp     .yes
.inc_r8_again:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .inc_r12
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc0
    jmp     .yes
.inc_r12:
    er_pop_expect_token_operand_push_result tok_r12, tok_r12_len
    jz      .inc_r13
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc4
    jmp     .yes
.inc_r13:
    er_pop_expect_token_operand_result tok_r13, tok_r13_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xff, 0xc5
    jmp     .yes
.dec:
    er_match_source_token_result tok_dec, tok_dec_len
    jz      .bad
    er_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .dec_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xff, 0xc9
    jmp     .yes
.dec_rdx:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xff, 0xca
    jmp     .yes
.bad:
    er_ret_false
.yes:
    er_ret_true

er_fn match_math_hash_branch
    er_match_source_token_result tok_jz, tok_jz_len
    jz      .je
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.je:
    er_match_source_token_result tok_je, tok_je_len
    jz      .jb
    mov     edi, 0x74
    jmp     emit_short_branch_operand
.jb:
    er_match_source_token_result tok_jne, tok_jne_len
    jz      .jnz
    mov     edi, 0x75
    jmp     emit_short_branch_operand
.jnz:
    er_match_source_token_result tok_jnz, tok_jnz_len
    jz      .jae
    mov     edi, 0x75
    jmp     emit_short_branch_operand
.jae:
    er_match_source_token_result tok_jae, tok_jae_len
    jz      .jbe
    mov     edi, 0x73
    jmp     emit_short_branch_operand
.jbe:
    er_match_source_token_result tok_jbe, tok_jbe_len
    jz      .jle
    mov     edi, 0x76
    jmp     emit_short_branch_operand
.jle:
    er_match_source_token_result tok_jle, tok_jle_len
    jz      .jl
    mov     edi, 0x7e
    jmp     emit_short_branch_operand
.jl:
    er_match_source_token_result tok_jl, tok_jl_len
    jz      .jg
    mov     edi, 0x7c
    jmp     emit_short_branch_operand
.jg:
    er_match_source_token_result tok_jg, tok_jg_len
    jz      .ja
    mov     edi, 0x7f
    jmp     emit_short_branch_operand
.ja:
    er_match_source_token_result tok_ja, tok_ja_len
    jz      .jb_real
    mov     edi, 0x77
    jmp     emit_short_branch_operand
.jb_real:
    er_match_source_token_result tok_jb, tok_jb_len
    jz      .jc
    mov     edi, 0x72
    jmp     emit_short_branch_operand
.jc:
    er_match_source_token_result tok_jc, tok_jc_len
    jz      .jmp
    mov     edi, 0x72
    jmp     emit_short_branch_operand
.jmp:
    er_match_source_token_result tok_jmp, tok_jmp_len
    jz      .bad
    mov     edi, 0xeb
    jmp     emit_short_branch_operand
.bad:
    er_ret_false

er_fn match_math_hash_crc32
    er_match_source_token_result tok_crc32, tok_crc32_len
    jz      .bad
    er_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .eax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_qword, tok_qword_len
    jz      .bad
    er_expect_token_operand_result tok_mem_r8, tok_mem_r8_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf2, 0x49, 0x0f, 0x38, 0xf1
    er_emit_zero_byte
    jmp     .yes
.eax:
    er_pop_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_dword, tok_dword_len
    jz      .byte
    pop     r11
    er_expect_token_operand_result tok_mem_r8, tok_mem_r8_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf2, 0x41, 0x0f, 0x38, 0xf1
    er_emit_zero_byte
    jmp     .yes
.byte:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_expect_token_operand_result tok_mem_r8, tok_mem_r8_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf2, 0x41, 0x0f, 0x38, 0xf0
    er_emit_zero_byte
    jmp     .yes
.bad:
    er_ret_false
.yes:
    er_ret_true

er_fn match_math_hash_movzx
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x0f, 0xb6, 0x14, 0x0f
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_hash_mul
    er_match_source_token_result tok_mul, tok_mul_len
    jz      .try_div
    er_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rbx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xf7, 0xe0
    er_ret_true

.rbx:
    er_pop_expect_token_operand_push_result tok_rbx, tok_rbx_len
    jz      .mul_rsi
    pop     r11
    mov     r8d, 0xe3
    jmp     .mul64_emit
.mul_rsi:
    er_pop_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    mov     r8d, 0xe6
.mul64_emit:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xf7, r8d
    er_ret_true
.try_div:
    er_match_source_token_result tok_div, tok_div_len
    jz      .try_imul
    er_expect_token_operand_push_result tok_rbx, tok_rbx_len
    jz      .div_rsi
    pop     r11
    mov     r8d, 0xf3
    mov     r9d, 1
    jmp     .div_emit
.div_rsi:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .div_esi
    pop     r11
    mov     r8d, 0xf6
    mov     r9d, 1
    jmp     .div_emit
.div_esi:
    er_pop_expect_token_operand_result tok_esi, tok_esi_len
    jz      .bad
    mov     r8d, 0xf6
    xor     r9d, r9d
.div_emit:
    er_expect_line_end_result
    jz      .bad
    test    r9d, r9d
    jz      .div_no_rex
    er_emit_text_bytes 0x48
.div_no_rex:
    er_emit_text_bytes 0xf7, r8d
    er_ret_true
.try_imul:
    er_match_source_token_result tok_imul, tok_imul_len
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xf7, 0xee
    er_ret_true
.bad:
    er_ret_false

er_fn match_math_int_ops
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .cdq
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .mov_edx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .mov_eax_edx
    pop     r11
    mov     r8d, 0xc8
    jmp     .mov32_emit
.mov_eax_edx:
    er_pop_expect_token_operand_result tok_edx, tok_edx_len
    jz      .bad
    mov     r8d, 0xd0
.mov32_emit:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, r8d
    jmp     .yes
.mov_edx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .mov_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc2
    jmp     .yes
.mov_rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .mov_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.mov_r8:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .mov_r9
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xd0
    jmp     .yes
.mov_r9:
    er_pop_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .mov_mem_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.mov_mem_r8:
    er_pop_expect_token_operand_push_result tok_mem_r8, tok_mem_r8_len
    jz      .mov_mem_r9
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .mov_mem_r8_rax
    pop     r11
    mov     r8d, 0
    jmp     .mov_mem_r8_emit
.mov_mem_r8_rax:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    mov     r8d, 1
.mov_mem_r8_emit:
    er_expect_line_end_result
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
    er_pop_expect_token_operand_push_result tok_mem_r9, tok_mem_r9_len
    jz      .mov_sized_zero
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edx, tok_edx_len
    jz      .mov_mem_r9_rdx
    pop     r11
    mov     r8d, 0
    jmp     .mov_mem_r9_emit
.mov_mem_r9_rdx:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    mov     r8d, 1
.mov_mem_r9_emit:
    er_expect_line_end_result
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
    er_pop_expect_token_operand_push_result tok_dword, tok_dword_len
    jz      .mov_qword_zero
    pop     r11
    mov     r8d, 0
    jmp     .mov_sized_zero_mem
.mov_qword_zero:
    er_pop_expect_token_operand_result tok_qword, tok_qword_len
    jz      .mov_rax
    mov     r8d, 1
.mov_sized_zero_mem:
    er_push_expect_token_operand_result tok_mem_rdx, tok_mem_rdx_len
    jz      .mov_sized_zero_rcx
    pop     r11
    mov     r9d, 0x02
    jmp     .mov_sized_zero_emit
.mov_sized_zero_rcx:
    er_pop_expect_token_operand_result tok_mem_rcx, tok_mem_rcx_len
    jz      .bad
    mov     r9d, 0x01
.mov_sized_zero_emit:
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edx, tok_edx_len
    jz      .sub_eax_ecx
    pop     r11
    mov     r8d, 0x29
    jmp     .sub_eax_reg_emit
.sub_eax_ecx:
    pop     r14
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .sub_eax_imm
    pop     r11
    mov     r8d, 0x29
    mov     r9d, 0xc8
    jmp     .sub_eax_reg_emit_mod
.sub_eax_reg_emit:
    mov     r9d, 0xd0
.sub_eax_reg_emit_mod:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes r8d, r9d
    jmp     .yes
.sub_eax_imm:
    pop     r14
    er_expect_u32_result
    jz      .bad
    cmp     qword [rel imm_u32_value], 0
    jne     .bad
    er_expect_line_end_result
    jz      .bad
    test    r8d, r8d
    jz      .mov_sized_zero_no_rex
    er_emit_text_bytes 0x48
.mov_sized_zero_no_rex:
    er_emit_text_bytes 0xc7, r9d
    er_emit_zero_u32
    jmp     .yes
.mov_rax:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .mov_rax_rdi
    pop     r11
    mov     r8d, 0xd0
    jmp     .mov64_emit
.mov_rax_rdi:
    er_pop_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    mov     r8d, 0xf8
.mov64_emit:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, r8d
    jmp     .yes
.cdq:
    er_match_source_token_result tok_cdq, tok_cdq_len
    jz      .cqo
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x99
    jmp     .yes
.cqo:
    er_match_source_token_result tok_cqo, tok_cqo_len
    jz      .bsr
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x99
    jmp     .yes
.bsr:
    er_match_source_token_result tok_bsr, tok_bsr_len
    jz      .bsf
    mov     r8d, 0xbd
    jmp     .bit_scan
.bsf:
    er_match_source_token_result tok_bsf, tok_bsf_len
    jz      .idiv
    mov     r8d, 0xbc
.bit_scan:
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .bs_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, r8d, 0xc8
    jmp     .yes
.bs_rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .bs_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x0f, r8d, 0xc8
    jmp     .yes
.bs_rax:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x0f, r8d, 0xc7
    jmp     .yes
.idiv:
    er_match_source_token_result tok_idiv, tok_idiv_len
    jz      .xor
    er_expect_token_operand_result tok_esi, tok_esi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf7, 0xfe
    jmp     .yes
.xor:
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .sub
    mov     r8d, 0x31
    jmp     .eax_edx_arith
.sub:
    er_match_source_token_result tok_sub, tok_sub_len
    jz      .add
    mov     r8d, 0x29
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .sub_reg
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edx, tok_edx_len
    jz      .sub_eax_ecx_int
    pop     r11
    mov     r9d, 0xd0
    jmp     .sub_eax_reg_emit_int
.sub_eax_ecx_int:
    pop     r14
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .sub_eax_imm_int
    pop     r11
    mov     r9d, 0xc8
.sub_eax_reg_emit_int:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x29, r9d
    jmp     .yes
.sub_eax_imm_int:
    pop     r14
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
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
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .sub_reg_not_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x83, 0xe9
    er_emit_imm_byte_value
    jmp     .yes
.sub_reg_not_rcx:
    pop     r14
    jmp     .eax_edx_arith
.add:
    er_match_source_token_result tok_add, tok_add_len
    jz      .and
    mov     r8d, 0x01
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .add_reg
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edx, tok_edx_len
    jz      .add_eax_imm_int
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x01, 0xd0
    jmp     .yes
.add_eax_imm_int:
    pop     r14
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
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
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .add_reg_not_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x83, 0xc0
    er_emit_imm_byte_value
    jmp     .yes
.add_reg_not_r8:
    pop     r14
    jmp     .eax_edx_arith
.and:
    er_match_source_token_result tok_and, tok_and_len
    jz      .test
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .and_edx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x25
    er_emit_imm_u32_value
    jmp     .yes
.and_edx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .and_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x81, 0xe2
    er_emit_imm_u32_value
    jmp     .yes
.and_rax:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .and_rdx
    pop     r11
    mov     r8d, 0xc8
    jmp     .and64_reg
.and_rdx:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    mov     r8d, 0xca
.and64_reg:
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x21, r8d
    jmp     .yes
.test:
    er_match_source_token_result tok_test, tok_test_len
    jz      .shr
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .test_rax
    pop     r11
    mov     r8d, 0xc0
    lea     r10, [rel tok_eax]
    mov     r11d, tok_eax_len
    jmp     .test32_same
.test_rax:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .test_esi
    pop     r11
    mov     r8d, 0xc0
    lea     r10, [rel tok_rax]
    mov     r11d, tok_rax_len
    jmp     .test64_same
.test_esi:
    er_pop_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .test_rsi
    pop     r11
    mov     r8d, 0xf6
    lea     r10, [rel tok_esi]
    mov     r11d, tok_esi_len
    jmp     .test32_same
.test_rsi:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .test_edi
    pop     r11
    mov     r8d, 0xf6
    lea     r10, [rel tok_rsi]
    mov     r11d, tok_rsi_len
    jmp     .test64_same
.test_edi:
    er_pop_expect_token_operand_push_result tok_edi, tok_edi_len
    jz      .test_rdi
    pop     r11
    mov     r8d, 0xff
    lea     r10, [rel tok_edi]
    mov     r11d, tok_edi_len
    jmp     .test32_same
.test_rdi:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .test_rdx
    pop     r11
    mov     r8d, 0xff
    lea     r10, [rel tok_rdi]
    mov     r11d, tok_rdi_len
    jmp     .test64_same
.test_rdx:
    er_pop_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .test_rcx
    pop     r11
    mov     r8d, 0xd2
    lea     r10, [rel tok_rdx]
    mov     r11d, tok_rdx_len
    jmp     .test64_same
.test_rcx:
    er_pop_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    mov     r8d, 0xc9
    lea     r10, [rel tok_rcx]
    mov     r11d, tok_rcx_len
    jmp     .test64_same
.test32_same:
    er_expect_comma_result
    jz      .bad
    mov     rdi, r10
    mov     rsi, r11
    call    expect_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x85, r8d
    jmp     .yes
.test64_same:
    er_expect_comma_result
    jz      .bad
    mov     rdi, r10
    mov     rsi, r11
    call    expect_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, r8d
    jmp     .yes
.shr:
    er_match_source_token_result tok_shr, tok_shr_len
    jz      .no
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .shr_rax
    pop     r11
    mov     r8d, 0
    mov     r9d, 0xe8
    jmp     .shr_imm
.shr_rax:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .shr_edx
    pop     r11
    mov     r8d, 1
    mov     r9d, 0xe8
    jmp     .shr_imm
.shr_edx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .shr_rdx
    pop     r11
    mov     r8d, 0
    mov     r9d, 0xea
    jmp     .shr_imm
.shr_rdx:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    mov     r8d, 1
    mov     r9d, 0xea
.shr_imm:
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    test    r8d, r8d
    jz      .shr32_emit
    er_emit_text_bytes 0x48
.shr32_emit:
    er_emit_text_bytes 0xc1, r9d
    er_emit_imm_byte_value
    jmp     .yes
.eax_edx_arith:
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .edx_edx_arith
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edx, tok_edx_len
    jz      .eax_ecx_arith
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes r8d, 0xd0
    jmp     .yes
.eax_ecx_arith:
    er_pop_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes r8d, 0xc8
    jmp     .yes
.edx_edx_arith:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .rax_rdx_arith
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_edx, tok_edx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes r8d, 0xd2
    jmp     .yes
.rax_rdx_arith:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .rdx_rdx_arith
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, r8d, 0xd0
    jmp     .yes
.rdx_rdx_arith:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
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
    er_match_source_token_result tok_cmp, tok_cmp_len
    jz      .bad
    er_expect_token_operand_result tok_dil, tok_dil_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_test_edi_edi
    er_match_source_token_result tok_test, tok_test_len
    jz      .bad
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_in_al_dx
    er_match_source_token_result tok_in, tok_in_len
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dx, tok_dx_len
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_out_dx_al
    er_match_source_token_result tok_out, tok_out_len
    jz      .bad
    er_expect_token_operand_result tok_dx, tok_dx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_mov_eax_imm32
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

; match add/sub eax, imm8. r10d=0 for add, 1 for sub.
er_fn match_addsub_eax_imm8
    er_match_source_token_result tok_add, tok_add_len
    jz      .try_sub
    xor     r10d, r10d
    jmp     .operands
.try_sub:
    er_match_source_token_result tok_sub, tok_sub_len
    jz      .bad
    mov     r10d, 1
.operands:
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_xor_eax_eax
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_xor_edi_edi
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .bad
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    call    expect_line_end
    ret
.bad:
    er_ret_false

er_fn match_ret_line
    er_match_source_token_result tok_ret, tok_ret_len
    jnz     .line_end
    er_match_source_token_result tok_er_ret, tok_er_ret_len
    jz      .bad
.line_end:
    call    expect_line_end
    ret
.bad:
    er_ret_false
