er_fn match_common_mov
    er_match_source_token tok_mov, tok_mov_len
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_rdx_rax
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
.not_rdx_rax:
    pop     r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_mem_rdi_rax
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
.not_mem_rdi_rax:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_r8_imm64
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .r8_not_rsi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf0
    jmp     .yes
.r8_not_rsi:
    pop     r14
    push    r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .r8_not_rdx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xd0
    jmp     .yes
.r8_not_rdx:
    pop     r14
    push    r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .r8_not_rdi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf8
    jmp     .yes
.r8_not_rdi:
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
.not_r8_imm64:
    pop     r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_r9_rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .r9_not_rcx_src
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.r9_not_rcx_src:
    pop     r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf1
    jmp     .yes
.not_r9_rcx:
    pop     r14
    lea     rdi, [rel tok_r9d]
    mov     esi, tok_r9d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_r9d_esi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_not_esi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0xf1
    jmp     .yes
.not_r9d_esi:
    pop     r14
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_r10_rsi
    pop     r11
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
    jmp     .yes
.not_r10_rsi:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_early_ecx_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_u32_operand
    test    eax, eax
    jz      .early_ecx_try_madt_entries
    pop     r11
    jmp     .early_ecx_value_ok
.early_ecx_try_madt_entries:
    pop     r14
    er_expect_token_operand tok_madt_entries, tok_madt_entries_len
    test    eax, eax
    jz      .bad
    mov     qword [rel imm_u32_value], 44
.early_ecx_value_ok:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    jmp     .yes
.not_early_ecx_imm:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_rcx_rdx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .rcx_not_rdx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd1
    jmp     .yes
.rcx_not_rdx:
    pop     r14
    call    expect_u64_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.not_rcx_rdx:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_rsi_rdx
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
    er_emit_text_bytes 0x48, 0x89, 0xd6
    jmp     .yes
.not_rsi_rdx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_edx_ecx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .edx_not_ecx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xca
    jmp     .yes
.edx_not_ecx:
    pop     r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xc2
    jmp     .yes
.not_edx_ecx:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_eax_esi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_esi, tok_esi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xf0
    jmp     .yes
.eax_not_esi:
    pop     r14
    er_expect_token_operand tok_r9d, tok_r9d_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x44, 0x89, 0xc8
    jmp     .yes
.not_eax_esi:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_ecx_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_u32_operand
    test    eax, eax
    jz      .ecx_try_madt_entries
    pop     r11
    jmp     .ecx_value_ok
.ecx_try_madt_entries:
    pop     r14
    er_expect_token_operand tok_madt_entries, tok_madt_entries_len
    test    eax, eax
    jz      .bad
    mov     qword [rel imm_u32_value], 44
.ecx_value_ok:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    jmp     .yes
.not_ecx_imm:
    pop     r14
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_mem_r8_eax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .mem_r8_not_eax
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0x00
    jmp     .yes
.mem_r8_not_eax:
    pop     r14
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0x00
    jmp     .yes
.not_mem_r8_eax:
    pop     r14
    lea     rdi, [rel tok_mem_r9]
    mov     esi, tok_mem_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_mem_r9_edx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .mem_r9_not_edx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0x11
    jmp     .yes
.mem_r9_not_edx:
    pop     r14
    er_expect_token_operand tok_rdx, tok_rdx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0x11
    jmp     .yes
.not_mem_r9_edx:
    pop     r14
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_rbx_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xfb
    jmp     .yes
.not_rbx_rdi:
    pop     r14
    lea     rdi, [rel tok_dx]
    mov     esi, tok_dx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_dx_r8w
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8w]
    mov     esi, tok_r8w_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dx_not_r8w
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x66, 0x44, 0x89, 0xc2
    jmp     .yes
.dx_not_r8w:
    pop     r14
    push    r14
    er_expect_token_operand tok_di, tok_di_len
    test    eax, eax
    jz      .dx_not_di
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x66, 0x89, 0xfa
    jmp     .yes
.dx_not_di:
    pop     r14
    er_expect_token_operand tok_bx, tok_bx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x66, 0x89, 0xda
    jmp     .yes
.not_dx_r8w:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_byte_store
    pop     r11
    push    r14
    er_expect_token_operand tok_mem_rdi, tok_mem_rdi_len
    test    eax, eax
    jz      .initial_byte_mem_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_cl, tok_cl_len
    test    eax, eax
    jz      .initial_byte_mem_rdi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0x0f
    jmp     .yes
.initial_byte_mem_rdi_imm:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xc6, 0x07
    er_emit_imm_byte_value
    jmp     .yes
.initial_byte_mem_rsi:
    pop     r14
    push    r14
    er_expect_token_operand tok_mem_r8, tok_mem_r8_len
    test    eax, eax
    jz      .initial_byte_mem_rsi_real
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_dl, tok_dl_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x88, 0x10
    jmp     .yes
.initial_byte_mem_rsi_real:
    pop     r14
    push    r14
    er_expect_token_operand tok_mem_rsi, tok_mem_rsi_len
    test    eax, eax
    jz      .byte_rdx_r8x2_al_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .initial_byte_store_dil
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.initial_byte_store_dil:
    pop     r14
    er_expect_token_operand tok_dil, tok_dil_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0x3e
    jmp     .yes
.not_initial_byte_store:
    pop     r14
    lea     rdi, [rel tok_qword]
    mov     esi, tok_qword_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_qword_mem_rsi_store
    pop     r11
    er_expect_token_operand tok_mem_rsi, tok_mem_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0x06
    er_emit_imm_u32_value
    jmp     .yes
.not_initial_qword_mem_rsi_store:
    pop     r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_mem_rdi_store
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_r9, tok_r9_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0x0f
    jmp     .yes
.not_initial_mem_rdi_store:
    pop     r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_mem_rsi_store
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .initial_mem_rsi_r8_store
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x0e
    jmp     .yes
.initial_mem_rsi_r8_store:
    pop     r14
    er_expect_token_operand tok_r8, tok_r8_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0x06
    jmp     .yes
.not_initial_mem_rsi_store:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_rcx_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .initial_rcx_r9
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf1
    jmp     .yes
.initial_rcx_r9:
    pop     r14
    push    r14
    er_expect_token_operand tok_r9, tok_r9_len
    test    eax, eax
    jz      .initial_rcx_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc9
    jmp     .yes
.initial_rcx_r8:
    pop     r14
    push    r14
    er_expect_token_operand tok_r8, tok_r8_len
    test    eax, eax
    jz      .initial_rcx_minus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc1
    jmp     .yes
.initial_rcx_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .r8_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0x3d
    mov     rax, [rel imm_u32_value]
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    mov     rdi, rax
    call    append_text_u32
    jmp     .yes
.not_initial_rel_store:
    pop     r14
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_dl_load
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_mem_r9, tok_mem_r9_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x8a, 0x11
    jmp     .yes
.not_initial_dl_load:
    pop     r14
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .r8_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xfc
    jmp     .yes
.r8_rdi:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_r12
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .r8_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf8
    jmp     .yes
.r8_rcx_common:
    pop     r14
    push    r14
    er_expect_token_operand tok_rcx, tok_rcx_len
    test    eax, eax
    jz      .r8_mem_rdi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc8
    jmp     .yes
.r8_mem_rdi_common:
    pop     r14
    er_expect_token_operand tok_mem_rdi, tok_mem_rdi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x8b, 0x07
    jmp     .yes
.rsi_r12:
    pop     r14
    lea     rdi, [rel tok_r13]
    mov     esi, tok_r13_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_r12_after_r13
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf5
    jmp     .yes
.rsi_r12_after_r13:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .rsi_r12_source
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf6
    jmp     .yes
.rsi_r12_source:
    pop     r14
    push    r14
    er_expect_token_operand tok_r12, tok_r12_len
    test    eax, eax
    jz      .rsi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xe6
    jmp     .yes
.rsi_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc6
    er_emit_imm_u32_value
    jmp     .yes
.rax_rdi:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdx_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .rax_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf8
    jmp     .yes
.rax_imm:
    pop     r14
    push    r14
    er_expect_token_operand tok_r9, tok_r9_len
    test    eax, eax
    jz      .rax_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc8
    jmp     .yes
.rax_rcx_common:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_rdx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc8
    jmp     .yes
.rax_rdx_common:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_r8_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xd0
    jmp     .yes
.rax_r8_common:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_rsi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x89, 0xc0
    jmp     .yes
.rax_rsi_common:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_value
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf0
    jmp     .yes
.rax_value:
    pop     r14
    push    r14
    call    expect_value_operand
    test    eax, eax
    jz      .rax_minus_one
    pop     r11
    jmp     .rax_value_emit
.rax_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
.rax_value_emit:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc0
    er_emit_imm_u32_value
    jmp     .yes
.rdx_rsi:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdi_rsp
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rsi, tok_rsi_len
    test    eax, eax
    jz      .rdx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xf2
    jmp     .yes
.rdx_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc2
    er_emit_imm_u32_value
    jmp     .yes
.rdi_rsp:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r12d_edi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .rdi_rsp_source
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xc7
    jmp     .yes
.rdi_rsp_source:
    pop     r14
    push    r14
    er_expect_token_operand tok_rdi, tok_rdi_len
    test    eax, eax
    jz      .rdi_rsp_source_real
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x89, 0xff
    jmp     .yes
.rdi_rsp_source_real:
    pop     r14
    push    r14
    er_expect_token_operand tok_rsp, tok_rsp_len
    test    eax, eax
    jz      .rdi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
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
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0x8b, 0x3d
    mov     rax, [rel imm_u32_value]
    mov     rdx, [rel text_len]
    add     rdx, 4
    sub     rax, rdx
    mov     rdi, rax
    call    append_text_u32
    jmp     .yes
.rdi_imm_value:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x48, 0xc7, 0xc7
    er_emit_imm_u32_value
    jmp     .yes
.r12d_edi:
    pop     r14
    lea     rdi, [rel tok_r12d]
    mov     esi, tok_r12d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .ebx_r8d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .eax_esi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0xfc
    jmp     .yes
.ebx_r8d:
    pop     r14
    lea     rdi, [rel tok_ebx]
    mov     esi, tok_ebx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8d_esi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_r8d, tok_r8d_len
    test    eax, eax
    jz      .ebx_edx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x44, 0x89, 0xc3
    jmp     .yes
.ebx_edx_common:
    pop     r14
    er_expect_token_operand tok_edx, tok_edx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xd3
    jmp     .yes
.r8d_esi:
    pop     r14
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_edi_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_esi, tok_esi_len
    test    eax, eax
    jz      .r8d_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x89, 0xf0
    jmp     .yes
.r8d_imm_common:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0xb8
    er_emit_imm_u32_value
    jmp     .yes
.eax_edi_common:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .eax_esi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_mov_eax_edi
    jmp     .yes
.eax_esi_common:
    pop     r14
    er_expect_token_operand tok_esi, tok_esi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xf0
    jmp     .yes
.al_imm:
    pop     r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cl_al_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    push    r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .sub_eax_imm_math
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x29, 0xc8
    jmp     .yes
.sub_eax_imm_math:
    pop     r14
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .al_cl
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xb0
    er_emit_imm_byte_value
    jmp     .yes
.al_cl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al_sil
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0xc8
    jmp     .yes
.al_sil:
    pop     r14
    lea     rdi, [rel tok_sil]
    mov     esi, tok_sil_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al_dl
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0xf0
    jmp     .yes
.al_dl:
    pop     r14
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al_mem_rdi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0xd0
    jmp     .yes
.cl_al_common:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dx_di
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .cl_byte_mem_rsi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0xc1
    jmp     .yes
.cl_byte_mem_rsi_common:
    pop     r14
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_mem_rsi, tok_mem_rsi_len
    test    eax, eax
    jz      .cl_byte_mem_rdi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x8a, 0x0e
    jmp     .yes
.cl_byte_mem_rdi_common:
    pop     r14
    push    r14
    er_expect_token_operand tok_mem_rdi, tok_mem_rdi_len
    test    eax, eax
    jz      .cl_byte_rsi_r8_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x8a, 0x0f
    jmp     .yes
.cl_byte_rsi_r8_common:
    pop     r14
    call    expect_rsi_plus_r8
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x0c, 0x06
    jmp     .yes
.al_mem_rdi:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al_mem_rdi_rcx_minus_one
    pop     r11
    push    r14
    er_expect_token_operand tok_mem_rdi, tok_mem_rdi_len
    test    eax, eax
    jz      .al_mem_rsi_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x8a, 0x07
    jmp     .yes
.al_mem_rsi_after_byte:
    pop     r14
    push    r14
    er_expect_token_operand tok_mem_rsi, tok_mem_rsi_len
    test    eax, eax
    jz      .al_mem_r9_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .byte_mem_rsi_store_after_byte
    er_emit_text_bytes 0x8a, 0x06
    jmp     .yes
.byte_mem_rsi_store_after_byte:
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .byte_mem_rsi_store_dil_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.byte_mem_rsi_store_dil_after_byte:
    pop     r14
    er_expect_token_operand tok_dil, tok_dil_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x40, 0x88, 0x3e
    jmp     .yes
.al_mem_r9_after_byte:
    pop     r14
    push    r14
    er_expect_token_operand tok_mem_r9, tok_mem_r9_len
    test    eax, eax
    jz      .al_mem_rsi_r9_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
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
    call    expect_line_end
    test    eax, eax
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
    call    expect_line_end
    test    eax, eax
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
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0x8a, 0x04, 0x07
    jmp     .yes
.al_mem_rdi_rcx_minus_one_after_byte:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x8a, 0x44, 0x0f, 0xff
    jmp     .yes
.al_mem_rdi_rcx_minus_one:
    pop     r14
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x8a, 0x44, 0x0f, 0xff
    jmp     .yes
.dx_di:
    pop     r14
    lea     rdi, [rel tok_dx]
    mov     esi, tok_dx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edx_imm
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_di, tok_di_len
    test    eax, eax
    jz      .dx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x66, 0x89, 0xfa
    jmp     .yes
.dx_imm:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 0xffff
    ja      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x66, 0xba
    mov     rax, [rel imm_u32_value]
    er_emit_text_bytes eax
    shr     rax, 8
    er_emit_text_bytes eax
    jmp     .yes
.edx_imm:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r13d_imm
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
    er_emit_text_bytes 0xba
    er_emit_imm_u32_value
    jmp     .yes
.r13d_imm:
    pop     r14
    lea     rdi, [rel tok_r13d]
    mov     esi, tok_r13d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edi_imm
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
    er_emit_text_bytes 0x41, 0xbd
    er_emit_imm_u32_value
    jmp     .yes
.edi_imm:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_imm_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .edi_value
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xc7
    jmp     .yes
.edi_value:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xbf
    er_emit_imm_u32_value
    jmp     .yes
.eax_imm_common:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r10b_imm_common
    pop     r11
    cmp     qword [rel generic_instr_mode], 0
    jne     .eax_generic
    cmp     qword [rel exit_instr_step], 0
    jne     .eax_generic
    er_ret_false
.eax_generic:
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_edi, tok_edi_len
    test    eax, eax
    jz      .eax_value_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    call    emit_mov_eax_edi
    jmp     .yes
.eax_value_common:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    ja      .bad
    er_emit_text_bytes 0xb8
    er_emit_imm_u32_value
    jmp     .yes
.r10b_imm_common:
    pop     r14
    lea     rdi, [rel tok_r10b]
    mov     esi, tok_r10b_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rbx_imm_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .r10b_byte_load_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0xb2
    er_emit_imm_byte_value
    jmp     .yes
.r10b_byte_load_common:
    pop     r14
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x44, 0x8a, 0x54, 0x0e, 0xff
    jmp     .yes
.rbx_imm_common:
    pop     r14
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9_rax_common
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
    pop     r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_al_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_rax, tok_rax_len
    test    eax, eax
    jz      .r9_rsi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc1
    jmp     .yes
.r9_rsi_common:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xf1
    jmp     .yes
.r9_rcx_common:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9_mem_rsi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0x89, 0xc9
    jmp     .yes
.r9_mem_rsi_common:
    pop     r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4c, 0x8b, 0x0e
    jmp     .yes
.r9_imm_common:
    pop     r14
    push    r14
    call    expect_u64_operand
    test    eax, eax
    jz      .r9_minus_one_common
    pop     r11
    jmp     .r9_imm_emit_common
.r9_minus_one_common:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
.r9_imm_emit_common:
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x49, 0xb9
    er_emit_imm_u64_value
    jmp     .yes
.byte_mem_rsi_al_common:
    pop     r14
    lea     rdi, [rel tok_r11]
    mov     esi, tok_r11_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_al_common_after_r11
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
    er_emit_text_bytes 0x49, 0xbb
    er_emit_imm_u64_value
    jmp     .yes
.byte_mem_rsi_al_common_after_r11:
    pop     r14
    lea     rdi, [rel tok_mem_r13]
    mov     esi, tok_mem_r13_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_al_common_after_mem_r13
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_r12, tok_r12_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x4d, 0x89, 0x65
    er_emit_zero_byte
    jmp     .yes
.byte_mem_rsi_al_common_after_mem_r13:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_al_common_after_ecx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_eax, tok_eax_len
    test    eax, eax
    jz      .ecx_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x89, 0xc1
    jmp     .yes
.ecx_imm_common:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xb9
    er_emit_imm_u32_value
    jmp     .yes
.byte_mem_rsi_al_common_after_ecx:
    pop     r14
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_al_common_after_r8d
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
    er_emit_text_bytes 0x41, 0xb8
    er_emit_imm_u32_value
    jmp     .yes
.byte_mem_rsi_al_common_after_r8d:
    pop     r14
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_mem_rsi, tok_mem_rsi_len
    test    eax, eax
    jz      .byte_rdx_r8x2_al_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .byte_mem_rsi_dil_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0x06
    jmp     .yes
.byte_mem_rsi_dil_common:
    pop     r14
    er_expect_token_operand tok_dil, tok_dil_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_r10b, tok_r10b_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_cl, tok_cl_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x0c, 0x0a
    jmp     .yes
.byte_rdi_r9_al_common:
    pop     r14
    call    expect_rdi_plus_r9
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .byte_rdi_r9_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0x88, 0x04, 0x0f
    jmp     .yes
.byte_rdi_r9_imm_common:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0xc6, 0x04, 0x0f
    er_emit_imm_byte_value
    jmp     .yes
.yes:
    er_ret_true
.bad:
    er_ret_false

er_fn match_more_runtime_ops
    er_match_source_token tok_movzx, tok_movzx_len
    test    eax, eax
    jz      .cld
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_ecx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_sil, tok_sil_len
    test    eax, eax
    jz      .movzx_eax_mem_rdi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x40, 0x0f, 0xb6, 0xc6
    jmp     .yes
.movzx_eax_mem_rdi:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_al_direct
    pop     r11
    push    r14
    er_expect_token_operand tok_mem_rdi, tok_mem_rdi_len
    test    eax, eax
    jz      .movzx_eax_mem_rdi_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
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
    call    expect_line_end
    test    eax, eax
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
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0x0f, 0xb6, 0x44, 0x07, 0x01
    jmp     .yes
.movzx_eax_mem_r12:
    pop     r14
    push    r14
    er_expect_token_operand tok_mem_r12, tok_mem_r12_len
    test    eax, eax
    jz      .movzx_eax_mem_r12_plus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x04, 0x24
    jmp     .yes
.movzx_eax_mem_r12_plus_one:
    pop     r14
    call    expect_r12_plus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x41, 0x0f, 0xb6, 0x44, 0x24, 0x01
    jmp     .yes
.movzx_eax_al_direct:
    pop     r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc0
    jmp     .yes
.movzx_ecx:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_edx_rdi_r8
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .cl_byte_load
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0xc1
    jmp     .yes
.movzx_edx_rdi_r8:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_ebx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_rdi_plus_r8
    test    eax, eax
    jz      .movzx_edx_mem_rcx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x42, 0x0f, 0xb6, 0x14, 0x07
    jmp     .yes
.movzx_edx_mem_rcx:
    pop     r14
    er_expect_token_operand tok_mem_rcx, tok_mem_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x11
    jmp     .yes
.cl_byte_load:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_ecx_cl_direct
    pop     r11
    er_expect_token_operand tok_mem_rsi, tok_mem_rsi_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x0e
    jmp     .yes
.movzx_ecx_cl_direct:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_ecx_al_direct
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc9
    jmp     .yes
.movzx_ecx_al_direct:
    pop     r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc8
    jmp     .yes
.movzx_ebx:
    pop     r14
    lea     rdi, [rel tok_ebx]
    mov     esi, tok_ebx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_edx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_dl, tok_dl_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xda
    jmp     .yes
.movzx_edx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_al
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    er_expect_token_operand tok_al, tok_al_len
    test    eax, eax
    jz      .cl_byte_operand
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x88, 0xc1
    jmp     .yes
.cl_byte_operand:
    pop     r14
    er_expect_token_operand tok_byte, tok_byte_len
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_mem_rcx, tok_mem_rcx_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0x11
    jmp     .yes
.movzx_eax_al:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movzx_ecx_cl
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
    er_emit_text_bytes 0x0f, 0xb6, 0xc0
    jmp     .yes
.movzx_ecx_cl:
    pop     r14
    er_expect_token_operand tok_ecx, tok_ecx_len
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    er_expect_token_operand tok_cl, tok_cl_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0x0f, 0xb6, 0xc9
    jmp     .yes
.cld:
    er_match_source_token tok_cld, tok_cld_len
    test    eax, eax
    jz      .std
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xfc
    jmp     .yes
.std:
    er_match_source_token tok_std, tok_std_len
    test    eax, eax
    jz      .clc
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xfd
    jmp     .yes
.clc:
    er_match_source_token tok_clc, tok_clc_len
    test    eax, eax
    jz      .stc
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf8
    jmp     .yes
.stc:
    er_match_source_token tok_stc, tok_stc_len
    test    eax, eax
    jz      .repne
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf9
    jmp     .yes
.repne:
    er_match_source_token tok_repne, tok_repne_len
    test    eax, eax
    jz      .rep
    er_expect_token_operand tok_scasb, tok_scasb_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf2, 0xae
    jmp     .yes
.rep:
    er_match_source_token tok_rep, tok_rep_len
    test    eax, eax
    jz      .test
    lea     rdi, [rel tok_stosq]
    mov     esi, tok_stosq_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .stosb
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf3, 0x48, 0xab
    jmp     .yes
.stosb:
    pop     r14
    lea     rdi, [rel tok_stosb]
    mov     esi, tok_stosb_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movsq
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf3, 0xaa
    jmp     .yes
.movsq:
    pop     r14
    lea     rdi, [rel tok_movsq]
    mov     esi, tok_movsq_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .movsb
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf3, 0x48, 0xa5
    jmp     .yes
.movsb:
    pop     r14
    lea     rdi, [rel tok_movsb]
    mov     esi, tok_movsb_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .stosd
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    er_emit_text_bytes 0xf3, 0xa4
    jmp     .yes
.stosd:
    pop     r14
    er_expect_token_operand tok_stosd, tok_stosd_len
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
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
