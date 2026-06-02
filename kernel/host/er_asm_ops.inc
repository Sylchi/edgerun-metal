er_fn match_more_test
    er_match_source_token_result tok_test, tok_test_len
    jz      .no
    er_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xff
    jmp     .yes
.rax:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .r11
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x85, 0xc0
    jmp     .yes
.r11:
    er_pop_expect_token_operand_push_result tok_r11, tok_r11_len
    jz      .r10
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r11, tok_r11_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4d, 0x85, 0xdb
    jmp     .yes
.r10:
    er_pop_expect_token_operand_push_result tok_r10, tok_r10_len
    jz      .r13
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r10, tok_r10_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4d, 0x85, 0xd2
    jmp     .yes
.r13:
    er_pop_expect_token_operand_push_result tok_r13, tok_r13_len
    jz      .al
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r13, tok_r13_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4d, 0x85, 0xed
    jmp     .yes
.al:
    er_pop_expect_token_operand_push_result tok_al, tok_al_len
    jz      .cl
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x84, 0xc0
    jmp     .yes
.cl:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .dl
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_cl, tok_cl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x84, 0xc9
    jmp     .yes
.dl:
    er_pop_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .sil_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dl, tok_dl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x84, 0xd2
    jmp     .yes
.sil_imm:
    er_pop_expect_token_operand_result tok_sil, tok_sil_len
    jz      .no
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0xf6, 0xc6
    er_emit_imm_byte_value
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_more_xor
    er_match_source_token_result tok_xor, tok_xor_len
    jz      .no
    er_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x31, 0xc9
    jmp     .yes
.rcx:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .edx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x31, 0xc9
    jmp     .yes
.edx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .r8d
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_edx, tok_edx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x31, 0xd2
    jmp     .yes
.r8d:
    er_pop_expect_token_operand_push_result tok_r8d, tok_r8d_len
    jz      .r9d
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r8d, tok_r8d_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x45, 0x31, 0xc0
    jmp     .yes
.r9d:
    er_pop_expect_token_operand_push_result tok_r9d, tok_r9d_len
    jz      .r10d
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r9d, tok_r9d_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x45, 0x31, 0xc9
    jmp     .yes
.r10d:
    er_pop_expect_token_operand_push_result tok_r10d, tok_r10d_len
    jz      .r11d
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r10d, tok_r10d_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x45, 0x31, 0xd2
    jmp     .yes
.r11d:
    er_pop_expect_token_operand_result tok_r11d, tok_r11d_len
    jz      .no
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r11d, tok_r11d_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x45, 0x31, 0xdb
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_more_and
    er_match_source_token_result tok_and, tok_and_len
    jz      .shl
    er_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .and_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .sub_eax_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
    jmp     .yes
.sub_eax_imm:
    pop     r14
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x83, 0xe1
    er_emit_imm_byte_value
    jmp     .yes
.and_r8:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .and_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .sub_eax_imm_math
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
    jmp     .yes
.sub_eax_imm_math:
    pop     r14
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x83, 0xe0
    er_emit_imm_byte_value
    jmp     .yes
.and_rcx:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .and_rcx_real
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
.and_rcx_real:
    er_pop_expect_token_operand_push_result tok_al, tok_al_len
    jz      .and_rcx_real_actual
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x24
    er_emit_imm_byte_value
    jmp     .yes
.and_rcx_real_actual:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .and_cl
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x83, 0xe1
    er_emit_imm_byte_value
    jmp     .yes
.and_cl:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .and_cl_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    cmp     qword [rel imm_u32_value], 255
    ja      .and_edx_u32
    er_emit_text_bytes 0x83, 0xe2
    er_emit_imm_byte_value
    jmp     .yes
.and_edx_u32:
    er_emit_text_bytes 0x81, 0xe2
    er_emit_imm_u32_value
    jmp     .yes
.and_cl_real:
    er_pop_expect_token_operand_result tok_cl, tok_cl_len
    jz      .no
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x80, 0xe1
    er_emit_imm_byte_value
    jmp     .yes
.shl:
    er_match_source_token_result tok_shl, tok_shl_len
    jz      .shr
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc0, 0xe0
    er_emit_imm_byte_value
    jmp     .yes
.shr:
    er_match_source_token_result tok_shr, tok_shr_len
    jz      .mov
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .shr_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc0, 0xe8
    er_emit_imm_byte_value
    jmp     .yes
.shr_rcx:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .shr_rcx_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc1, 0xe8
    er_emit_imm_byte_value
    jmp     .yes
.shr_rcx_real:
    er_pop_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .no
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc1, 0xe9
    er_emit_imm_byte_value
    jmp     .yes
.mov:
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .no
    er_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .r11_imm_first
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .r9_minus_one
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.r9_minus_one:
    pop     r14
    push    r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .r9_imm64_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xc7, 0xc1
    mov     edi, 0xffffffff
    call    append_text_u32
    jmp     .yes
.r9_imm64_more:
    pop     r14
    push    r14
    er_expect_u64_result
    jz      .r9_rax_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.r9_rax_more:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .r9_rsi_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc1
    jmp     .yes
.r9_rsi_more:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .r11_imm_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf1
    jmp     .yes
.r11_imm_more:
    er_pop_expect_token_operand_push_result tok_r11, tok_r11_len
    jz      .r9_mem_rsi_more
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xc7, 0xc3
    er_emit_imm_u32_value
    jmp     .yes
.r9_mem_rsi_more:
    er_pop_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x8b, 0x0e
    jmp     .yes
.r11_imm_first:
    er_pop_expect_token_operand_push_result tok_r11, tok_r11_len
    jz      .rcx_r9
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xc7, 0xc3
    er_emit_imm_u32_value
    jmp     .yes
.rcx_r9:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .rcx_r9_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc1
    jmp     .yes
.rcx_r9_real:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .rax_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_r9, tok_r9_len
    jz      .rcx_eax
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc9
    jmp     .yes
.rcx_eax:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .rcx_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc1
    jmp     .yes
.rcx_rdx:
    er_pop_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rcx_r8
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd1
    jmp     .yes
.rcx_r8:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rcx_rsi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc1
    jmp     .yes
.rcx_rsi:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .rcx_minus_one
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf1
    jmp     .yes
.rcx_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc1
    mov     edi, 0xffffffff
    call    append_text_u32
    jmp     .yes
.rax_r8:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .eax_esi_more
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_r8, tok_r8_len
    jz      .rax_r9_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc0
    jmp     .yes
.rax_r9_more:
    pop     r14
    er_push_expect_token_operand_result tok_r9, tok_r9_len
    jz      .rax_rsi_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc8
    jmp     .yes
.rax_rsi_more:
    pop     r14
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .rax_rcx_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf0
    jmp     .yes
.rax_rcx_more:
    pop     r14
    er_push_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .rax_rdx_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc8
    jmp     .yes
.rax_rdx_more:
    pop     r14
    er_push_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .rax_mem_rdi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd0
    jmp     .yes
.rax_mem_rdi:
    er_pop_expect_token_operand_push_result tok_mem_rdi, tok_mem_rdi_len
    jz      .rax_imm64_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x8b, 0x07
    jmp     .yes
.rax_imm64_more:
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
.eax_esi_more:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .r8_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_esi, tok_esi_len
    jz      .eax_edi_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xf0
    jmp     .yes
.eax_edi_more:
    er_pop_expect_token_operand_result tok_edi, tok_edi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xf8
    jmp     .yes
.r8_rcx:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rdi_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .r8_rsi_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc8
    jmp     .yes
.r8_rsi_more:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .r8_mem_rdi_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf0
    jmp     .yes
.r8_mem_rdi_more:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .r8_imm64_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x8b, 0x07
    jmp     .yes
.r8_imm64_more:
    pop     r14
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xb8
    er_emit_imm_u64_value
    jmp     .yes
.rdi_rax:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .rbx_imm_more
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rax, tok_rax_len
    jz      .rdi_rel_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc7
    jmp     .yes
.rdi_rel_more:
    pop     r14
    push    r14
    call    expect_rel_label_value
    test    eax, eax
    jz      .rdi_rdi_more
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x8b, 0x3d
    mov     rax, [rel imm_u32_value]
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    er_emit_rax_u32
    jmp     .yes
.rdi_rdi_more:
    er_pop_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xff
    jmp     .yes
.rbx_imm_more:
    er_pop_expect_token_operand_push_result tok_rbx, tok_rbx_len
    jz      .rsi_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    ja      .rbx_imm64_more
    er_emit_text_bytes 0x48, 0xc7, 0xc3
    er_emit_imm_u32_value
    jmp     .yes
.rbx_imm64_more:
    er_emit_text_bytes 0x48, 0xbb
    er_emit_imm_u64_value
    jmp     .yes
.rsi_rsi:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .dl_mem_r9
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf6
    jmp     .yes
.dl_mem_r9:
    er_pop_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .mem_r8_dl
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_expect_token_operand_result tok_mem_r9, tok_mem_r9_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x8a, 0x11
    jmp     .yes
.mem_r8_dl:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .mem_r8_dl_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .cl_mem_rsi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x0f
    jmp     .yes
.cl_mem_rsi:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .cl_mem_rsi_r8
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x0e
    jmp     .yes
.cl_mem_rsi_r8:
    pop     r14
    call    expect_rsi_plus_r8
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x0c, 0x06
    jmp     .yes
.mem_r8_dl_real:
    er_pop_expect_token_operand_push_result tok_r10b, tok_r10b_len
    jz      .mem_r8_dl_byte_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_imm8_result
    jz      .r10b_byte_load
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0xb2
    er_emit_imm_byte_value
    jmp     .yes
.r10b_byte_load:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x44, 0x8a, 0x54, 0x0e, 0xff
    jmp     .yes
.mem_r8_dl_byte_store:
    er_pop_expect_token_operand_push_result tok_byte, tok_byte_len
    jz      .mem_rdi_r9_qword
    pop     r11
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .mem_rsi_al_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_cl, tok_cl_len
    jz      .mem_rdi_imm_byte_store
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x0f
    jmp     .yes
.mem_rsi_al_store:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .mem_rdi_r9_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.mem_rdi_imm_byte_store:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc6, 0x07
    er_emit_imm_byte_value
    jmp     .yes
.mem_rdi_r9_store:
    pop     r14
    push    r14
    call    expect_rdi_plus_r9
    test    eax, eax
    jz      .mem_r8_dl_indexed_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .mem_rdi_r9_imm_store
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x04, 0x0f
    jmp     .yes
.mem_rdi_r9_imm_store:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0xc6, 0x04, 0x0f
    er_emit_imm_byte_value
    jmp     .yes
.mem_r8_dl_indexed_store:
    pop     r14
    er_push_expect_token_operand_result tok_mem_r8, tok_mem_r8_len
    jz      .mem_rsi_rcx_al
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dl, tok_dl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x88, 0x10
    jmp     .yes
.mem_rsi_rcx_al:
    pop     r14
    push    r14
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .mem_rdx_r8x2_al
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x44, 0x0e, 0xff
    jmp     .yes
.mem_rdx_r8x2_al:
    pop     r14
    push    r14
    call    expect_rdx_plus_r8_times_2
    test    eax, eax
    jz      .mem_rdx_r8x2_plus_one_al
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x04, 0x42
    jmp     .yes
.mem_rdx_r8x2_plus_one_al:
    pop     r14
    push    r14
    call    expect_rdx_plus_r8_times_2_plus_one
    test    eax, eax
    jz      .mem_rdx_r9_cl
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x44, 0x42, 0x01
    jmp     .yes
.mem_rdx_r9_cl:
    pop     r14
    push    r14
    call    expect_rdx_plus_r9
    test    eax, eax
    jz      .mem_rdi_rcx_r10b
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_cl, tok_cl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x0c, 0x0a
    jmp     .yes
.mem_rdi_rcx_r10b:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r10b, tok_r10b_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x44, 0x88, 0x54, 0x0f, 0xff
    jmp     .yes
.mem_rdi_r9_qword:
    er_pop_expect_token_operand_push_result tok_mem_rdi, tok_mem_rdi_len
    jz      .mem_rsi_r8_qword
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_r9, tok_r9_len
    jz      .mem_rdi_rax_qword
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0x0f
    jmp     .yes
.mem_rdi_rax_qword:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x07
    jmp     .yes
.mem_rsi_r8_qword:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .rel_store_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r8, tok_r8_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0x06
    jmp     .yes
.rel_store_rdi:
    pop     r14
    push    r14
    call    expect_rel_label_value
    test    eax, eax
    jz      .mem_r13_r12_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x3d
    mov     rax, [rel imm_u32_value]
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    er_emit_rax_u32
    jmp     .yes
.mem_r13_r12_store:
    er_pop_expect_token_operand_result tok_mem_r13, tok_mem_r13_len
    jz      .no
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r12, tok_r12_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4d, 0x89, 0x65
    er_emit_zero_byte
    jmp     .yes
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_more_byte_arith
    er_match_source_token_result tok_add, tok_add_len
    jz      .cmp
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .add_cl
    pop     r11
    er_expect_comma_result
    jz      .bad
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x04
    er_emit_imm_byte_value
    jmp     .yes
.add_cl:
    er_pop_expect_token_operand_result tok_cl, tok_cl_len
    jz      .no
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x80, 0xc1
    er_emit_imm_byte_value
    jmp     .yes
.cmp:
    er_match_source_token_result tok_cmp, tok_cmp_len
    jz      .no
    er_expect_token_operand_push_result tok_al, tok_al_len
    jz      .cmp_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_imm8_result
    jz      .cmp_al_cl
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x3c
    er_emit_imm_byte_value
    jmp     .yes
.cmp_rax:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .cmp_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rbx, tok_rbx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x39, 0xd8
    jmp     .yes
.cmp_al_cl:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .cmp_al_dl
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x38, 0xc8
    jmp     .yes
.cmp_al_dl:
    er_pop_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .cmp_al_mem_r8
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x38, 0xd0
    jmp     .yes
.cmp_al_mem_r8:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_expect_token_operand_result tok_mem_r8, tok_mem_r8_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x3a
    er_emit_zero_byte
    jmp     .yes
.cmp_r8:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .cmp_r9
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .cmp_r8_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x39, 0xf0
    jmp     .yes
.cmp_r8_rdx:
    pop     r14
    mov     r10d, 0xd0
    jmp     .cmp_r64_rdx_after_comma
.cmp_r9:
    er_pop_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .cmp_r10
    pop     r11
    mov     r10d, 0xd1
    jmp     .cmp_r64_rdx
.cmp_r10:
    er_pop_expect_token_operand_push_result tok_r10, tok_r10_len
    jz      .cmp_cl
    pop     r11
    mov     r10d, 0xd2
.cmp_r64_rdx:
    er_expect_comma_result
    jz      .bad
.cmp_r64_rdx_after_comma:
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x39, r10d
    jmp     .yes
.cmp_cl:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .cmp_dil
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x80, 0xf9
    er_emit_imm_byte_value
    jmp     .yes
.cmp_dil:
    er_pop_expect_token_operand_push_result tok_edi, tok_edi_len
    jz      .cmp_dil_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x81, 0xff
    er_emit_imm_u32_value
    jmp     .yes
.cmp_dil_real:
    er_pop_expect_token_operand_push_result tok_dil, tok_dil_len
    jz      .cmp_byte
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    call    emit_cmp_dil_imm8
    jmp     .yes
.cmp_byte:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .no
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .cmp_byte_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .cmp_byte_rdi_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x38, 0x07
    jmp     .yes
.cmp_byte_rdi_imm:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x80, 0x3f
    er_emit_imm_byte_value
    jmp     .yes
.cmp_byte_rsi:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .cmp_byte_rdi_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x80, 0x3e
    er_emit_imm_byte_value
    jmp     .yes
.cmp_byte_rdi_rcx:
    pop     r14
    push    r14
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .cmp_byte_rdi_r9
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .cmp_byte_rdi_rcx_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x38, 0x04, 0x0f
    jmp     .yes
.cmp_byte_rdi_rcx_imm:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x80, 0x3c, 0x0f
    er_emit_imm_byte_value
    jmp     .yes
.cmp_byte_rdi_r9:
    pop     r14
    call    expect_rdi_plus_r9
    test    eax, eax
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x80, 0x3c, 0x0f
    er_emit_imm_byte_value
    jmp     .yes
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false

er_fn match_more_unary
    er_match_source_token_result tok_not, tok_not_len
    jz      .or
    er_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xf7, 0xd1
    jmp     .yes
.or:
    er_match_source_token_result tok_or, tok_or_len
    jz      .neg
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .or_cl_al
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_imm8_result
    jz      .or_eax_minus_one
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x83, 0xc8
    er_emit_imm_byte_value
    jmp     .yes
.or_eax_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x83, 0xc8, 0xff
    jmp     .yes
.or_cl_al:
    er_pop_expect_token_operand_push_result tok_al, tok_al_len
    jz      .or_cl_al_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0c
    er_emit_imm_byte_value
    jmp     .yes
.or_cl_al_real:
    er_pop_expect_token_operand_result tok_cl, tok_cl_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x08, 0xc1
    jmp     .yes
.neg:
    er_match_source_token_result tok_neg, tok_neg_len
    jz      .no
    er_expect_token_operand_result tok_r9, tok_r9_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xf7, 0xd9
    jmp     .yes
.yes:
    er_ret_true
.bad:
    mov     qword [rel exit_subset_bad], 1
    er_ret_true
.no:
    er_ret_false
