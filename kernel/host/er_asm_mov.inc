er_fn match_common_mov
    er_match_source_token_result tok_mov, tok_mov_len
    jz      .bad
    er_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .not_rdx_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc2
    jmp     .yes
.not_rdx_rax:
    er_pop_expect_token_operand_push_result tok_mem_rdi, tok_mem_rdi_len
    jz      .not_mem_rdi_rax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x07
    jmp     .yes
.not_mem_rdi_rax:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .not_r8_imm64
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .r8_not_rsi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf0
    jmp     .yes
.r8_not_rsi:
    pop     r14
    er_push_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .r8_not_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xd0
    jmp     .yes
.r8_not_rdx:
    pop     r14
    er_push_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .r8_not_rdi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf8
    jmp     .yes
.r8_not_rdi:
    pop     r14
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xb8
    er_emit_imm_u64_value
    jmp     .yes
.not_r8_imm64:
    er_pop_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .not_r9_rcx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .r9_not_rcx_src
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.r9_not_rcx_src:
    er_pop_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf1
    jmp     .yes
.not_r9_rcx:
    er_pop_expect_token_operand_push_result tok_r9d, tok_r9d_len
    jz      .not_r9d_esi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_esi, tok_esi_len
    jz      .eax_not_esi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0xf1
    jmp     .yes
.not_r9d_esi:
    er_pop_expect_token_operand_push_result tok_r10, tok_r10_len
    jz      .not_r10_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf2
    jmp     .yes
.not_r10_rsi:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .not_early_ecx_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_u32_result
    jz      .early_ecx_try_madt_entries
    pop     r11
    jmp     .early_ecx_value_ok
.early_ecx_try_madt_entries:
    er_pop_expect_token_operand_result tok_madt_entries, tok_madt_entries_len
    jz      .bad
    mov     qword [rel imm_u32_value], 44
.early_ecx_value_ok:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    jmp     .yes
.not_early_ecx_imm:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .not_rcx_rdx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .rcx_not_rdx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd1
    jmp     .yes
.rcx_not_rdx:
    pop     r14
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.not_rcx_rdx:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .not_rsi_rdx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd6
    jmp     .yes
.not_rsi_rdx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .not_edx_ecx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .edx_not_ecx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xca
    jmp     .yes
.edx_not_ecx:
    er_pop_expect_token_operand_result tok_eax, tok_eax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc2
    jmp     .yes
.not_edx_ecx:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .not_eax_esi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_esi, tok_esi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xf0
    jmp     .yes
.eax_not_esi:
    er_pop_expect_token_operand_result tok_r9d, tok_r9d_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x44, 0x89, 0xc8
    jmp     .yes
.not_eax_esi:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .not_ecx_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_u32_result
    jz      .ecx_try_madt_entries
    pop     r11
    jmp     .ecx_value_ok
.ecx_try_madt_entries:
    er_pop_expect_token_operand_result tok_madt_entries, tok_madt_entries_len
    jz      .bad
    mov     qword [rel imm_u32_value], 44
.ecx_value_ok:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    jmp     .yes
.not_ecx_imm:
    er_pop_expect_token_operand_push_result tok_mem_r8, tok_mem_r8_len
    jz      .not_mem_r8_eax
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .mem_r8_not_eax
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0x00
    jmp     .yes
.mem_r8_not_eax:
    er_pop_expect_token_operand_result tok_rax, tok_rax_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0x00
    jmp     .yes
.not_mem_r8_eax:
    er_pop_expect_token_operand_push_result tok_mem_r9, tok_mem_r9_len
    jz      .not_mem_r9_edx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edx, tok_edx_len
    jz      .mem_r9_not_edx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0x11
    jmp     .yes
.mem_r9_not_edx:
    er_pop_expect_token_operand_result tok_rdx, tok_rdx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0x11
    jmp     .yes
.not_mem_r9_edx:
    er_pop_expect_token_operand_push_result tok_rbx, tok_rbx_len
    jz      .not_rbx_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xfb
    jmp     .yes
.not_rbx_rdi:
    er_pop_expect_token_operand_push_result tok_dx, tok_dx_len
    jz      .not_dx_r8w
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_push_result tok_r8w, tok_r8w_len
    jz      .dx_not_r8w
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0x44, 0x89, 0xc2
    jmp     .yes
.dx_not_r8w:
    pop     r14
    er_push_expect_token_operand_result tok_di, tok_di_len
    jz      .dx_not_di
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0x89, 0xfa
    jmp     .yes
.dx_not_di:
    er_pop_expect_token_operand_result tok_bx, tok_bx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0x89, 0xda
    jmp     .yes
.not_dx_r8w:
    er_pop_expect_token_operand_push_result tok_byte, tok_byte_len
    jz      .not_initial_byte_store
    pop     r11
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .initial_byte_mem_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_cl, tok_cl_len
    jz      .initial_byte_mem_rdi_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x0f
    jmp     .yes
.initial_byte_mem_rdi_imm:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xc6, 0x07
    er_emit_imm_byte_value
    jmp     .yes
.initial_byte_mem_rsi:
    pop     r14
    er_push_expect_token_operand_result tok_mem_r8, tok_mem_r8_len
    jz      .initial_byte_mem_rsi_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dl, tok_dl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x88, 0x10
    jmp     .yes
.initial_byte_mem_rsi_real:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .byte_rdx_r8x2_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .initial_byte_store_dil
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.initial_byte_store_dil:
    er_pop_expect_token_operand_result tok_dil, tok_dil_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0x3e
    jmp     .yes
.not_initial_byte_store:
    er_pop_expect_token_operand_push_result tok_qword, tok_qword_len
    jz      .not_initial_qword_mem_rsi_store
    pop     r11
    er_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0x06
    er_emit_imm_u32_value
    jmp     .yes
.not_initial_qword_mem_rsi_store:
    er_pop_expect_token_operand_push_result tok_mem_rdi, tok_mem_rdi_len
    jz      .not_initial_mem_rdi_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r9, tok_r9_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0x0f
    jmp     .yes
.not_initial_mem_rdi_store:
    er_pop_expect_token_operand_push_result tok_mem_rsi, tok_mem_rsi_len
    jz      .not_initial_mem_rsi_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .initial_mem_rsi_r8_store
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x0e
    jmp     .yes
.initial_mem_rsi_r8_store:
    er_pop_expect_token_operand_result tok_r8, tok_r8_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0x06
    jmp     .yes
.not_initial_mem_rsi_store:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .not_initial_rcx_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .initial_rcx_r9
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf1
    jmp     .yes
.initial_rcx_r9:
    pop     r14
    er_push_expect_token_operand_result tok_r9, tok_r9_len
    jz      .initial_rcx_r8
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc9
    jmp     .yes
.initial_rcx_r8:
    pop     r14
    er_push_expect_token_operand_result tok_r8, tok_r8_len
    jz      .initial_rcx_minus_one
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc1
    jmp     .yes
.initial_rcx_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc1
    er_emit_imm_u32_value
    jmp     .yes
.not_initial_rcx_imm:
    pop     r14
    push    r14
    call    expect_rel_label_value
    test    eax, eax
    jz      .not_initial_rel_store
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .r8_rcx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x3d
    mov     rax, [rel imm_u32_value]
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    er_emit_rax_u32
    jmp     .yes
.not_initial_rel_store:
    er_pop_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .not_initial_dl_load
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
.not_initial_dl_load:
    er_pop_expect_token_operand_push_result tok_r12, tok_r12_len
    jz      .r8_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .r8_rcx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xfc
    jmp     .yes
.r8_rdi:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rsi_r12
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .r8_rcx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf8
    jmp     .yes
.r8_rcx_common:
    pop     r14
    er_push_expect_token_operand_result tok_rcx, tok_rcx_len
    jz      .r8_mem_rdi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc8
    jmp     .yes
.r8_mem_rdi_common:
    er_pop_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x8b, 0x07
    jmp     .yes
.rsi_r12:
    er_pop_expect_token_operand_push_result tok_r13, tok_r13_len
    jz      .rsi_r12_after_r13
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf5
    jmp     .yes
.rsi_r12_after_r13:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .rax_rdi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .rsi_r12_source
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf6
    jmp     .yes
.rsi_r12_source:
    pop     r14
    er_push_expect_token_operand_result tok_r12, tok_r12_len
    jz      .rsi_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xe6
    jmp     .yes
.rsi_imm:
    pop     r14
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc6
    er_emit_imm_u32_value
    jmp     .yes
.rax_rdi:
    er_pop_expect_token_operand_push_result tok_rax, tok_rax_len
    jz      .rdx_rsi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .rax_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf8
    jmp     .yes
.rax_imm:
    pop     r14
    er_push_expect_token_operand_result tok_r9, tok_r9_len
    jz      .rax_rcx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc8
    jmp     .yes
.rax_rcx_common:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .rax_rdx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc8
    jmp     .yes
.rax_rdx_common:
    er_pop_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rax_r8_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd0
    jmp     .yes
.rax_r8_common:
    er_pop_expect_token_operand_push_result tok_r8, tok_r8_len
    jz      .rax_rsi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc0
    jmp     .yes
.rax_rsi_common:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .rax_value
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf0
    jmp     .yes
.rax_value:
    pop     r14
    push    r14
    er_expect_value_result
    jz      .rax_minus_one
    pop     r11
    jmp     .rax_value_emit
.rax_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
.rax_value_emit:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc0
    er_emit_imm_u32_value
    jmp     .yes
.rdx_rsi:
    er_pop_expect_token_operand_push_result tok_rdx, tok_rdx_len
    jz      .rdi_rsp
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rsi, tok_rsi_len
    jz      .rdx_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf2
    jmp     .yes
.rdx_imm:
    pop     r14
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc2
    er_emit_imm_u32_value
    jmp     .yes
.rdi_rsp:
    er_pop_expect_token_operand_push_result tok_rdi, tok_rdi_len
    jz      .r12d_edi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rax, tok_rax_len
    jz      .rdi_rsp_source
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc7
    jmp     .yes
.rdi_rsp_source:
    pop     r14
    er_push_expect_token_operand_result tok_rdi, tok_rdi_len
    jz      .rdi_rsp_source_real
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xff
    jmp     .yes
.rdi_rsp_source_real:
    pop     r14
    er_push_expect_token_operand_result tok_rsp, tok_rsp_len
    jz      .rdi_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xe7
    jmp     .yes
.rdi_imm:
    pop     r14
    push    r14
    call    expect_rel_label_value
    test    eax, eax
    jz      .rdi_imm_value
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
.rdi_imm_value:
    pop     r14
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc7
    er_emit_imm_u32_value
    jmp     .yes
.r12d_edi:
    er_pop_expect_token_operand_push_result tok_r12d, tok_r12d_len
    jz      .ebx_r8d
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edi, tok_edi_len
    jz      .eax_esi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0xfc
    jmp     .yes
.ebx_r8d:
    er_pop_expect_token_operand_push_result tok_ebx, tok_ebx_len
    jz      .r8d_esi
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_r8d, tok_r8d_len
    jz      .ebx_edx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x44, 0x89, 0xc3
    jmp     .yes
.ebx_edx_common:
    er_pop_expect_token_operand_result tok_edx, tok_edx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xd3
    jmp     .yes
.r8d_esi:
    er_pop_expect_token_operand_push_result tok_r8d, tok_r8d_len
    jz      .eax_edi_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_esi, tok_esi_len
    jz      .r8d_imm_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0xf0
    jmp     .yes
.r8d_imm_common:
    pop     r14
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0xb8
    er_emit_imm_u32_value
    jmp     .yes
.eax_edi_common:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .al_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edi, tok_edi_len
    jz      .eax_esi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    call    emit_mov_eax_edi
    jmp     .yes
.eax_esi_common:
    er_pop_expect_token_operand_result tok_esi, tok_esi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xf0
    jmp     .yes
.al_imm:
    er_pop_expect_token_operand_push_result tok_al, tok_al_len
    jz      .cl_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
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
    jz      .al_cl
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xb0
    er_emit_imm_byte_value
    jmp     .yes
.al_cl:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .al_sil
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0xc8
    jmp     .yes
.al_sil:
    er_pop_expect_token_operand_push_result tok_sil, tok_sil_len
    jz      .al_dl
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0xf0
    jmp     .yes
.al_dl:
    er_pop_expect_token_operand_push_result tok_dl, tok_dl_len
    jz      .al_mem_rdi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0xd0
    jmp     .yes
.cl_al_common:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .dx_di
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .cl_byte_mem_rsi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0xc1
    jmp     .yes
.cl_byte_mem_rsi_common:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .cl_byte_mem_rdi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x0e
    jmp     .yes
.cl_byte_mem_rdi_common:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .cl_byte_rsi_r8_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x0f
    jmp     .yes
.cl_byte_rsi_r8_common:
    pop     r14
    call    expect_rsi_plus_r8
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x0c, 0x06
    jmp     .yes
.al_mem_rdi:
    er_pop_expect_token_operand_push_result tok_byte, tok_byte_len
    jz      .al_mem_rdi_rcx_minus_one
    pop     r11
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .al_mem_rsi_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x07
    jmp     .yes
.al_mem_rsi_after_byte:
    pop     r14
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .al_mem_r9_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .byte_mem_rsi_store_after_byte
    er_emit_text_bytes 0x8a, 0x06
    jmp     .yes
.byte_mem_rsi_store_after_byte:
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .byte_mem_rsi_store_dil_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.byte_mem_rsi_store_dil_after_byte:
    er_pop_expect_token_operand_result tok_dil, tok_dil_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0x3e
    jmp     .yes
.al_mem_r9_after_byte:
    pop     r14
    er_push_expect_token_operand_result tok_mem_r9, tok_mem_r9_len
    jz      .al_mem_rsi_r9_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x8a, 0x01
    jmp     .yes
.al_mem_rsi_r9_after_byte:
    pop     r14
    push    r14
    call    expect_rsi_plus_r9
    test    eax, eax
    jz      .al_mem_rsi_r10_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x04, 0x0e
    jmp     .yes
.al_mem_rsi_r10_after_byte:
    pop     r14
    push    r14
    call    expect_rsi_plus_r10
    test    eax, eax
    jz      .al_mem_rdi_r8_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x04, 0x16
    jmp     .yes
.al_mem_rdi_r8_after_byte:
    pop     r14
    push    r14
    call    expect_rdi_plus_r8
    test    eax, eax
    jz      .al_mem_rdi_rcx_minus_one_after_byte
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x04, 0x07
    jmp     .yes
.al_mem_rdi_rcx_minus_one_after_byte:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x44, 0x0f, 0xff
    jmp     .yes
.al_mem_rdi_rcx_minus_one:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x8a, 0x44, 0x0f, 0xff
    jmp     .yes
.dx_di:
    er_pop_expect_token_operand_push_result tok_dx, tok_dx_len
    jz      .edx_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_di, tok_di_len
    jz      .dx_imm
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0x89, 0xfa
    jmp     .yes
.dx_imm:
    pop     r14
    er_expect_u32_result
    jz      .bad
    cmp     qword [rel imm_u32_value], 0xffff
    ja      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x66, 0xba
    mov     rax, [rel imm_u32_value]
    er_emit_text_bytes eax
    shr     rax, 8
    er_emit_text_bytes eax
    jmp     .yes
.edx_imm:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .r13d_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xba
    er_emit_imm_u32_value
    jmp     .yes
.r13d_imm:
    er_pop_expect_token_operand_push_result tok_r13d, tok_r13d_len
    jz      .edi_imm
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0xbd
    er_emit_imm_u32_value
    jmp     .yes
.edi_imm:
    er_pop_expect_token_operand_push_result tok_edi, tok_edi_len
    jz      .eax_imm_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .edi_value
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc7
    jmp     .yes
.edi_value:
    pop     r14
    er_expect_value_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xbf
    er_emit_imm_u32_value
    jmp     .yes
.eax_imm_common:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .r10b_imm_common
    pop     r11
    cmp     qword [rel generic_instr_mode], 0
    jne     .eax_generic
    cmp     qword [rel exit_instr_step], 0
    jne     .eax_generic
    er_ret_false
.eax_generic:
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_edi, tok_edi_len
    jz      .eax_value_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    call    emit_mov_eax_edi
    jmp     .yes
.eax_value_common:
    pop     r14
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    ja      .bad
    er_emit_text_bytes 0xb8
    er_emit_imm_u32_value
    jmp     .yes
.r10b_imm_common:
    er_pop_expect_token_operand_push_result tok_r10b, tok_r10b_len
    jz      .rbx_imm_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    push    r14
    er_expect_imm8_result
    jz      .r10b_byte_load_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0xb2
    er_emit_imm_byte_value
    jmp     .yes
.r10b_byte_load_common:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x44, 0x8a, 0x54, 0x0e, 0xff
    jmp     .yes
.rbx_imm_common:
    er_pop_expect_token_operand_push_result tok_rbx, tok_rbx_len
    jz      .r9_rax_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    ja      .rbx_imm64_common
    er_emit_text_bytes 0x48, 0xc7, 0xc3
    er_emit_imm_u32_value
    jmp     .yes
.rbx_imm64_common:
    er_emit_text_bytes 0x48, 0xbb
    er_emit_imm_u64_value
    jmp     .yes
.r9_rax_common:
    er_pop_expect_token_operand_push_result tok_r9, tok_r9_len
    jz      .byte_mem_rsi_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_rax, tok_rax_len
    jz      .r9_rsi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc1
    jmp     .yes
.r9_rsi_common:
    er_pop_expect_token_operand_push_result tok_rsi, tok_rsi_len
    jz      .r9_rcx_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf1
    jmp     .yes
.r9_rcx_common:
    er_pop_expect_token_operand_push_result tok_rcx, tok_rcx_len
    jz      .r9_mem_rsi_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.r9_mem_rsi_common:
    er_pop_expect_token_operand_push_result tok_mem_rsi, tok_mem_rsi_len
    jz      .r9_imm_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4c, 0x8b, 0x0e
    jmp     .yes
.r9_imm_common:
    pop     r14
    push    r14
    er_expect_u64_result
    jz      .r9_minus_one_common
    pop     r11
    jmp     .r9_imm_emit_common
.r9_minus_one_common:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
.r9_imm_emit_common:
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.byte_mem_rsi_al_common:
    er_pop_expect_token_operand_push_result tok_r11, tok_r11_len
    jz      .byte_mem_rsi_al_common_after_r11
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u64_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x49, 0xbb
    er_emit_imm_u64_value
    jmp     .yes
.byte_mem_rsi_al_common_after_r11:
    er_pop_expect_token_operand_push_result tok_mem_r13, tok_mem_r13_len
    jz      .byte_mem_rsi_al_common_after_mem_r13
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r12, tok_r12_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x4d, 0x89, 0x65
    er_emit_zero_byte
    jmp     .yes
.byte_mem_rsi_al_common_after_mem_r13:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .byte_mem_rsi_al_common_after_ecx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_eax, tok_eax_len
    jz      .ecx_imm_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x89, 0xc1
    jmp     .yes
.ecx_imm_common:
    pop     r14
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    jmp     .yes
.byte_mem_rsi_al_common_after_ecx:
    er_pop_expect_token_operand_push_result tok_r8d, tok_r8d_len
    jz      .byte_mem_rsi_al_common_after_r8d
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_u32_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0xb8
    er_emit_imm_u32_value
    jmp     .yes
.byte_mem_rsi_al_common_after_r8d:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_push_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .byte_rdx_r8x2_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .byte_mem_rsi_dil_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.byte_mem_rsi_dil_common:
    er_pop_expect_token_operand_result tok_dil, tok_dil_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0x3e
    jmp     .yes
.byte_rdx_r8x2_al_common:
    pop     r14
    push    r14
    call    expect_rsi_plus_one
    test    eax, eax
    jz      .byte_rsi_plus_two_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x46, 0x01
    jmp     .yes
.byte_rsi_plus_two_al_common:
    pop     r14
    push    r14
    call    expect_rsi_plus_two
    test    eax, eax
    jz      .byte_rsi_plus_three_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x46, 0x02
    jmp     .yes
.byte_rsi_plus_three_al_common:
    pop     r14
    push    r14
    call    expect_rsi_plus_three
    test    eax, eax
    jz      .byte_rsi_rcx_minus_one_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x46, 0x03
    jmp     .yes
.byte_rsi_rcx_minus_one_al_common:
    pop     r14
    push    r14
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .byte_rdi_rcx_minus_one_r10b_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0x44, 0x0e, 0xff
    jmp     .yes
.byte_rdi_rcx_minus_one_r10b_common:
    pop     r14
    push    r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .byte_rdx_r8x2_al_common_real
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_r10b, tok_r10b_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x44, 0x88, 0x54, 0x0f, 0xff
    jmp     .yes
.byte_rdx_r8x2_al_common_real:
    pop     r14
    push    r14
    call    expect_rdx_plus_r8_times_2
    test    eax, eax
    jz      .byte_rdx_r8x2_plus_one_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x04, 0x42
    jmp     .yes
.byte_rdx_r8x2_plus_one_al_common:
    pop     r14
    push    r14
    call    expect_rdx_plus_r8_times_2_plus_one
    test    eax, eax
    jz      .byte_rdx_r9_cl_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x44, 0x42, 0x01
    jmp     .yes
.byte_rdx_r9_cl_common:
    pop     r14
    push    r14
    call    expect_rdx_plus_r9
    test    eax, eax
    jz      .byte_rdi_r9_al_common
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_cl, tok_cl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x0c, 0x0a
    jmp     .yes
.byte_rdi_r9_al_common:
    pop     r14
    call    expect_rdi_plus_r9
    test    eax, eax
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .byte_rdi_r9_imm_common
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x04, 0x0f
    jmp     .yes
.byte_rdi_r9_imm_common:
    pop     r14
    er_expect_imm8_result
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0xc6, 0x04, 0x0f
    er_emit_imm_byte_value
    jmp     .yes
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_more_runtime_ops
    er_match_source_token_result tok_movzx, tok_movzx_len
    jz      .cld
    er_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .movzx_ecx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_sil, tok_sil_len
    jz      .movzx_eax_mem_rdi
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x40, 0x0f, 0xb6, 0xc6
    jmp     .yes
.movzx_eax_mem_rdi:
    er_pop_expect_token_operand_push_result tok_byte, tok_byte_len
    jz      .movzx_eax_al_direct
    pop     r11
    er_push_expect_token_operand_result tok_mem_rdi, tok_mem_rdi_len
    jz      .movzx_eax_mem_rdi_r8
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x07
    jmp     .yes
.movzx_eax_mem_rdi_r8:
    pop     r14
    push    r14
    call    expect_rdi_plus_r8
    test    eax, eax
    jz      .movzx_eax_mem_rdi_r8_plus_one
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x0f, 0xb6, 0x04, 0x07
    jmp     .yes
.movzx_eax_mem_rdi_r8_plus_one:
    pop     r14
    push    r14
    call    expect_rdi_plus_r8_plus_one
    test    eax, eax
    jz      .movzx_eax_mem_r12
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x0f, 0xb6, 0x44, 0x07, 0x01
    jmp     .yes
.movzx_eax_mem_r12:
    pop     r14
    er_push_expect_token_operand_result tok_mem_r12, tok_mem_r12_len
    jz      .movzx_eax_mem_r12_plus_one
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x04, 0x24
    jmp     .yes
.movzx_eax_mem_r12_plus_one:
    pop     r14
    call    expect_r12_plus_one
    test    eax, eax
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x44, 0x24, 0x01
    jmp     .yes
.movzx_eax_al_direct:
    er_pop_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc0
    jmp     .yes
.movzx_ecx:
    er_pop_expect_token_operand_push_result tok_ecx, tok_ecx_len
    jz      .movzx_edx_rdi_r8
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .cl_byte_load
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0xc1
    jmp     .yes
.movzx_edx_rdi_r8:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .movzx_ebx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    push    r14
    call    expect_rdi_plus_r8
    test    eax, eax
    jz      .movzx_edx_mem_rcx
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x42, 0x0f, 0xb6, 0x14, 0x07
    jmp     .yes
.movzx_edx_mem_rcx:
    er_pop_expect_token_operand_result tok_mem_rcx, tok_mem_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x11
    jmp     .yes
.cl_byte_load:
    er_pop_expect_token_operand_push_result tok_byte, tok_byte_len
    jz      .movzx_ecx_cl_direct
    pop     r11
    er_expect_token_operand_result tok_mem_rsi, tok_mem_rsi_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x0e
    jmp     .yes
.movzx_ecx_cl_direct:
    er_pop_expect_token_operand_push_result tok_cl, tok_cl_len
    jz      .movzx_ecx_al_direct
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc9
    jmp     .yes
.movzx_ecx_al_direct:
    er_pop_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc8
    jmp     .yes
.movzx_ebx:
    er_pop_expect_token_operand_push_result tok_ebx, tok_ebx_len
    jz      .movzx_edx
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_dl, tok_dl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xda
    jmp     .yes
.movzx_edx:
    er_pop_expect_token_operand_push_result tok_edx, tok_edx_len
    jz      .movzx_eax_al
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_push_expect_token_operand_result tok_al, tok_al_len
    jz      .cl_byte_operand
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x88, 0xc1
    jmp     .yes
.cl_byte_operand:
    er_pop_expect_token_operand_result tok_byte, tok_byte_len
    jz      .bad
    er_expect_token_operand_result tok_mem_rcx, tok_mem_rcx_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x11
    jmp     .yes
.movzx_eax_al:
    er_pop_expect_token_operand_push_result tok_eax, tok_eax_len
    jz      .movzx_ecx_cl
    pop     r11
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_al, tok_al_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc0
    jmp     .yes
.movzx_ecx_cl:
    er_pop_expect_token_operand_result tok_ecx, tok_ecx_len
    jz      .bad
    er_expect_comma_result
    jz      .bad
    er_expect_token_operand_result tok_cl, tok_cl_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc9
    jmp     .yes
.cld:
    er_match_source_token_result tok_cld, tok_cld_len
    jz      .std
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xfc
    jmp     .yes
.std:
    er_match_source_token_result tok_std, tok_std_len
    jz      .clc
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xfd
    jmp     .yes
.clc:
    er_match_source_token_result tok_clc, tok_clc_len
    jz      .stc
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf8
    jmp     .yes
.stc:
    er_match_source_token_result tok_stc, tok_stc_len
    jz      .repne
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf9
    jmp     .yes
.repne:
    er_match_source_token_result tok_repne, tok_repne_len
    jz      .rep
    er_expect_token_operand_result tok_scasb, tok_scasb_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf2, 0xae
    jmp     .yes
.rep:
    er_match_source_token_result tok_rep, tok_rep_len
    jz      .test
    er_expect_token_operand_push_result tok_stosq, tok_stosq_len
    jz      .stosb
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf3, 0x48, 0xab
    jmp     .yes
.stosb:
    er_pop_expect_token_operand_push_result tok_stosb, tok_stosb_len
    jz      .movsq
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf3, 0xaa
    jmp     .yes
.movsq:
    er_pop_expect_token_operand_push_result tok_movsq, tok_movsq_len
    jz      .movsb
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf3, 0x48, 0xa5
    jmp     .yes
.movsb:
    er_pop_expect_token_operand_push_result tok_movsb, tok_movsb_len
    jz      .stosd
    pop     r11
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf3, 0xa4
    jmp     .yes
.stosd:
    er_pop_expect_token_operand_result tok_stosd, tok_stosd_len
    jz      .bad
    er_expect_line_end_result
    jz      .bad
    er_emit_text_bytes 0xf3, 0xab
    jmp     .yes
.test:
    call    match_more_test
    test    eax, eax
    jnz     .yes
    call    match_more_xor
    test    eax, eax
    jnz     .yes
    call    match_more_and
    test    eax, eax
    jnz     .yes
    er_ret_false
.bad:
    er_ret_false
.yes:
    er_ret_true
