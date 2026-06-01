er_fn match_common_mov
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .not_initial_byte_store
    pop     r11
    push    r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .initial_byte_mem_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .initial_byte_mem_rdi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.initial_byte_mem_rdi_imm:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xc6
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.initial_byte_mem_rsi:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    call    expect_operand
    test    eax, eax
    jz      .initial_byte_mem_rsi_real
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x10
    call    append_text_byte
    jmp     .yes
.initial_byte_mem_rsi_real:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .byte_rdx_r8x2_al_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .initial_byte_store_dil
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
    jmp     .yes
.initial_byte_store_dil:
    pop     r14
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x3e
    call    append_text_byte
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
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
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
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
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
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .initial_mem_rsi_r8_store
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
    jmp     .yes
.initial_mem_rsi_r8_store:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
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
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .initial_rcx_r9
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf1
    call    append_text_byte
    jmp     .yes
.initial_rcx_r9:
    pop     r14
    push    r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .initial_rcx_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.initial_rcx_r8:
    pop     r14
    push    r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .initial_rcx_minus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.initial_rcx_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .r8_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x3d
    call    append_text_byte
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
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_mem_r9]
    mov     esi, tok_mem_r9_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x11
    call    append_text_byte
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
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .r8_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xfc
    call    append_text_byte
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
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .r8_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .yes
.r8_rcx_common:
    pop     r14
    push    r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .r8_mem_rdi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.r8_mem_rdi_common:
    pop     r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x8b
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
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
    mov     edi, 0xf5
    call    append_text_byte
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
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .rsi_r12_source
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf6
    call    append_text_byte
    jmp     .yes
.rsi_r12_source:
    pop     r14
    push    r14
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
    call    expect_operand
    test    eax, eax
    jz      .rsi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xe6
    call    append_text_byte
    jmp     .yes
.rsi_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .rax_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .yes
.rax_imm:
    pop     r14
    push    r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .rax_rcx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xd0
    call    append_text_byte
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
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .rdx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf2
    call    append_text_byte
    jmp     .yes
.rdx_imm:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc2
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .rdi_rsp_source
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    jmp     .yes
.rdi_rsp_source:
    pop     r14
    push    r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .rdi_rsp_source_real
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rdi_rsp_source_real:
    pop     r14
    push    r14
    lea     rdi, [rel tok_rsp]
    mov     esi, tok_rsp_len
    call    expect_operand
    test    eax, eax
    jz      .rdi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xe7
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x8b
    call    append_text_byte
    mov     edi, 0x3d
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .eax_esi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xfc
    call    append_text_byte
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
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    call    expect_operand
    test    eax, eax
    jz      .ebx_edx_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc3
    call    append_text_byte
    jmp     .yes
.ebx_edx_common:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xd3
    call    append_text_byte
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
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    call    expect_operand
    test    eax, eax
    jz      .r8d_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .yes
.r8d_imm_common:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
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
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
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
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    expect_operand
    test    eax, eax
    jz      .sub_eax_imm_math
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x29
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
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
    mov     edi, 0xb0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
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
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
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
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
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
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xd0
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .cl_byte_mem_rsi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.cl_byte_mem_rsi_common:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .cl_byte_mem_rdi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
    jmp     .yes
.cl_byte_mem_rdi_common:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .cl_byte_rsi_r8_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.cl_byte_rsi_r8_common:
    pop     r14
    call    expect_rsi_plus_r8
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x0c
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
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
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .al_mem_rsi_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.al_mem_rsi_after_byte:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .al_mem_r9_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .byte_mem_rsi_store_after_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
    jmp     .yes
.byte_mem_rsi_store_after_byte:
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_store_dil_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
    jmp     .yes
.byte_mem_rsi_store_dil_after_byte:
    pop     r14
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x3e
    call    append_text_byte
    jmp     .yes
.al_mem_r9_after_byte:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_r9]
    mov     esi, tok_mem_r9_len
    call    expect_operand
    test    eax, eax
    jz      .al_mem_rsi_r9_after_byte
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x01
    call    append_text_byte
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x16
    call    append_text_byte
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.al_mem_rdi_rcx_minus_one_after_byte:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.al_mem_rdi_rcx_minus_one:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
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
    lea     rdi, [rel tok_di]
    mov     esi, tok_di_len
    call    expect_operand
    test    eax, eax
    jz      .dx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xfa
    call    append_text_byte
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
    mov     edi, 0x66
    call    append_text_byte
    mov     edi, 0xba
    call    append_text_byte
    mov     rax, [rel imm_u32_value]
    mov     edi, eax
    call    append_text_byte
    shr     rax, 8
    mov     edi, eax
    call    append_text_byte
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
    mov     edi, 0xba
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0xbd
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .edi_value
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    jmp     .yes
.edi_value:
    pop     r14
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xbf
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    xor     eax, eax
    ret
.eax_generic:
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
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
    call    expect_value_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     rax, 0xffffffff
    cmp     [rel imm_u32_value], rax
    ja      .bad
    mov     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0xb2
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.r10b_byte_load_common:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x54
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc3
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.rbx_imm64_common:
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xbb
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
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
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .r9_rsi_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
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
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf1
    call    append_text_byte
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
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
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
    mov     edi, 0x4c
    call    append_text_byte
    mov     edi, 0x8b
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
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
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xb9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
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
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xbb
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
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
    lea     rdi, [rel tok_r12]
    mov     esi, tok_r12_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4d
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0x65
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
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
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    call    expect_operand
    test    eax, eax
    jz      .ecx_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.ecx_imm_common:
    pop     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xb9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
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
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0xb8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.byte_mem_rsi_al_common_after_r8d:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .byte_rdx_r8x2_al_common
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .byte_mem_rsi_dil_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x06
    call    append_text_byte
    jmp     .yes
.byte_mem_rsi_dil_common:
    pop     r14
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x3e
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x46
    call    append_text_byte
    mov     edi, 0x01
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x46
    call    append_text_byte
    mov     edi, 0x02
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x46
    call    append_text_byte
    mov     edi, 0x03
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
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
    lea     rdi, [rel tok_r10b]
    mov     esi, tok_r10b_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x54
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x42
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x01
    call    append_text_byte
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
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x0c
    call    append_text_byte
    mov     edi, 0x0a
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .byte_rdi_r9_imm_common
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.byte_rdi_r9_imm_common:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.yes:
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn match_more_runtime_ops
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_movzx]
    mov     ecx, tok_movzx_len
    call    token_eq
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
    lea     rdi, [rel tok_sil]
    mov     esi, tok_sil_len
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_mem_rdi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
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
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_mem_rdi_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    mov     edi, 0x01
    call    append_text_byte
    jmp     .yes
.movzx_eax_mem_r12:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_r12]
    mov     esi, tok_mem_r12_len
    call    expect_operand
    test    eax, eax
    jz      .movzx_eax_mem_r12_plus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x24
    call    append_text_byte
    jmp     .yes
.movzx_eax_mem_r12_plus_one:
    pop     r14
    call    expect_r12_plus_one
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x44
    call    append_text_byte
    mov     edi, 0x24
    call    append_text_byte
    mov     edi, 0x01
    call    append_text_byte
    jmp     .yes
.movzx_eax_al_direct:
    pop     r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .cl_byte_load
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
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
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x14
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.movzx_edx_mem_rcx:
    pop     r14
    lea     rdi, [rel tok_mem_rcx]
    mov     esi, tok_mem_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x11
    call    append_text_byte
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
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
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
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.movzx_ecx_al_direct:
    pop     r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
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
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xda
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .cl_byte_operand
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.cl_byte_operand:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_mem_rcx]
    mov     esi, tok_mem_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0x11
    call    append_text_byte
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
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.movzx_ecx_cl:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x0f
    call    append_text_byte
    mov     edi, 0xb6
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.cld:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cld]
    mov     ecx, tok_cld_len
    call    token_eq
    test    eax, eax
    jz      .std
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xfc
    call    append_text_byte
    jmp     .yes
.std:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_std]
    mov     ecx, tok_std_len
    call    token_eq
    test    eax, eax
    jz      .clc
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xfd
    call    append_text_byte
    jmp     .yes
.clc:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_clc]
    mov     ecx, tok_clc_len
    call    token_eq
    test    eax, eax
    jz      .stc
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .yes
.stc:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_stc]
    mov     ecx, tok_stc_len
    call    token_eq
    test    eax, eax
    jz      .repne
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf9
    call    append_text_byte
    jmp     .yes
.repne:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_repne]
    mov     ecx, tok_repne_len
    call    token_eq
    test    eax, eax
    jz      .rep
    lea     rdi, [rel tok_scasb]
    mov     esi, tok_scasb_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf2
    call    append_text_byte
    mov     edi, 0xae
    call    append_text_byte
    jmp     .yes
.rep:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_rep]
    mov     ecx, tok_rep_len
    call    token_eq
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
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xab
    call    append_text_byte
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
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0xaa
    call    append_text_byte
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
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xa5
    call    append_text_byte
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
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0xa4
    call    append_text_byte
    jmp     .yes
.stosd:
    pop     r14
    lea     rdi, [rel tok_stosd]
    mov     esi, tok_stosd_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0xf3
    call    append_text_byte
    mov     edi, 0xab
    call    append_text_byte
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
    xor     eax, eax
    ret
.bad:
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret
