er_fn match_more_test
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_test]
    mov     ecx, tok_test_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
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
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r11
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
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.r11:
    pop     r14
    lea     rdi, [rel tok_r11]
    mov     esi, tok_r11_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r10
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r11]
    mov     esi, tok_r11_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4d
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xdb
    call    append_text_byte
    jmp     .yes
.r10:
    pop     r14
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r13
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4d
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xd2
    call    append_text_byte
    jmp     .yes
.r13:
    pop     r14
    lea     rdi, [rel tok_r13]
    mov     esi, tok_r13_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .al
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r13]
    mov     esi, tok_r13_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x4d
    call    append_text_byte
    mov     edi, 0x85
    call    append_text_byte
    mov     edi, 0xed
    call    append_text_byte
    jmp     .yes
.al:
    pop     r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cl
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
    mov     edi, 0x84
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.cl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dl
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
    mov     edi, 0x84
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.dl:
    pop     r14
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .sil_imm
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
    mov     edi, 0x84
    call    append_text_byte
    mov     edi, 0xd2
    call    append_text_byte
    jmp     .yes
.sil_imm:
    pop     r14
    lea     rdi, [rel tok_sil]
    mov     esi, tok_sil_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x40
    call    append_text_byte
    mov     edi, 0xf6
    call    append_text_byte
    mov     edi, 0xc6
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
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

er_fn match_more_xor
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_xor]
    mov     ecx, tok_xor_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx
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
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.rcx:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .edx
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
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.edx:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xd2
    call    append_text_byte
    jmp     .yes
.r8d:
    pop     r14
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8d]
    mov     esi, tok_r8d_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x45
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc0
    call    append_text_byte
    jmp     .yes
.r9d:
    pop     r14
    lea     rdi, [rel tok_r9d]
    mov     esi, tok_r9d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r10d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r9d]
    mov     esi, tok_r9d_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x45
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xc9
    call    append_text_byte
    jmp     .yes
.r10d:
    pop     r14
    lea     rdi, [rel tok_r10d]
    mov     esi, tok_r10d_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r11d
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r10d]
    mov     esi, tok_r10d_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x45
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xd2
    call    append_text_byte
    jmp     .yes
.r11d:
    pop     r14
    lea     rdi, [rel tok_r11d]
    mov     esi, tok_r11d_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r11d]
    mov     esi, tok_r11d_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x45
    call    append_text_byte
    mov     edi, 0x31
    call    append_text_byte
    mov     edi, 0xdb
    call    append_text_byte
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

er_fn match_more_and
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_and]
    mov     ecx, tok_and_len
    call    token_eq
    test    eax, eax
    jz      .shl
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_r8
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    call    expect_operand
    test    eax, eax
    jz      .sub_eax_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x29
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.sub_eax_imm:
    pop     r14
    call    expect_imm8_expr_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xe1
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.and_r8:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
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
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xe0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.and_rcx:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_rcx_real
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
    mov     edi, 0x25
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.and_rcx_real:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_cl
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
    mov     edi, 0xe1
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.and_cl:
    pop     r14
    lea     rdi, [rel tok_edx]
    mov     esi, tok_edx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .and_cl_real
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
    cmp     qword [rel imm_u32_value], 255
    ja      .and_edx_u32
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xe2
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.and_edx_u32:
    mov     edi, 0x81
    call    append_text_byte
    mov     edi, 0xe2
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.and_cl_real:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0xe1
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.shl:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shl]
    mov     ecx, tok_shl_len
    call    token_eq
    test    eax, eax
    jz      .shr
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
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
    mov     edi, 0xc0
    call    append_text_byte
    mov     edi, 0xe0
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.shr:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_shr]
    mov     ecx, tok_shr_len
    call    token_eq
    test    eax, eax
    jz      .mov
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .shr_rcx
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
    mov     edi, 0xc0
    call    append_text_byte
    mov     edi, 0xe8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.shr_rcx:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .shr_rcx_real
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
    mov     edi, 0xc1
    call    append_text_byte
    mov     edi, 0xe8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.shr_rcx_real:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .no
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
    mov     edi, 0xe9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.mov:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_mov]
    mov     ecx, tok_mov_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r11_imm_first
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .r9_minus_one
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
.r9_minus_one:
    pop     r14
    push    r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .r9_imm64_more
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    mov     edi, 0xffffffff
    call    append_text_u32
    jmp     .yes
.r9_imm64_more:
    pop     r14
    push    r14
    call    expect_u64_operand
    test    eax, eax
    jz      .r9_rax_more
    pop     r11
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
.r9_rax_more:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9_rsi_more
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
.r9_rsi_more:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r11_imm_more
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
.r11_imm_more:
    pop     r14
    lea     rdi, [rel tok_r11]
    mov     esi, tok_r11_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r9_mem_rsi_more
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
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc3
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.r9_mem_rsi_more:
    pop     r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
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
    mov     edi, 0x0e
    call    append_text_byte
    jmp     .yes
.r11_imm_first:
    pop     r14
    lea     rdi, [rel tok_r11]
    mov     esi, tok_r11_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_r9
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
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc3
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.rcx_r9:
    pop     r14
    lea     rdi, [rel tok_ecx]
    mov     esi, tok_ecx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_r9_real
    pop     r11
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
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.rcx_r9_real:
    pop     r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_r8
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .rcx_eax
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
.rcx_eax:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_rdx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.rcx_rdx:
    pop     r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_r8
    pop     r11
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
.rcx_r8:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_rsi
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
.rcx_rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rcx_minus_one
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
.rcx_minus_one:
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
    mov     edi, 0xffffffff
    call    append_text_u32
    jmp     .yes
.rax_r8:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .eax_esi_more
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .rax_r9_more
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
.rax_r9_more:
    pop     r14
    push    r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .rax_rsi_more
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
.rax_rsi_more:
    pop     r14
    push    r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .rax_rcx_more
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
.rax_rcx_more:
    pop     r14
    push    r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .rax_rdx_more
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
.rax_rdx_more:
    pop     r14
    push    r14
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .rax_mem_rdi
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
.rax_mem_rdi:
    pop     r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rax_imm64_more
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
.rax_imm64_more:
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
.eax_esi_more:
    pop     r14
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8_rcx
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_esi]
    mov     esi, tok_esi_len
    call    expect_operand
    test    eax, eax
    jz      .eax_edi_more
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .yes
.eax_edi_more:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf8
    call    append_text_byte
    jmp     .yes
.r8_rcx:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rdi_rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .r8_rsi_more
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
.r8_rsi_more:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .r8_mem_rdi_more
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
.r8_mem_rdi_more:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .r8_imm64_more
    pop     r11
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
.r8_imm64_more:
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
.rdi_rax:
    pop     r14
    lea     rdi, [rel tok_rdi]
    mov     esi, tok_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rbx_imm_more
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    call    expect_operand
    test    eax, eax
    jz      .rdi_rel_more
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
.rdi_rel_more:
    pop     r14
    push    r14
    call    expect_rel_label_value
    test    eax, eax
    jz      .rdi_rdi_more
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
.rdi_rdi_more:
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
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.rbx_imm_more:
    pop     r14
    lea     rdi, [rel tok_rbx]
    mov     esi, tok_rbx_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .rsi_rsi
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
    ja      .rbx_imm64_more
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xc7
    call    append_text_byte
    mov     edi, 0xc3
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.rbx_imm64_more:
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0xbb
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u64
    jmp     .yes
.rsi_rsi:
    pop     r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .dl_mem_r9
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
    mov     edi, 0x48
    call    append_text_byte
    mov     edi, 0x89
    call    append_text_byte
    mov     edi, 0xf6
    call    append_text_byte
    jmp     .yes
.dl_mem_r9:
    pop     r14
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_r8_dl
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
.mem_r8_dl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_r8_dl_real
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
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .cl_mem_rsi
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.cl_mem_rsi:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .cl_mem_rsi_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x8a
    call    append_text_byte
    mov     edi, 0x0e
    call    append_text_byte
    jmp     .yes
.cl_mem_rsi_r8:
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
.mem_r8_dl_real:
    pop     r14
    lea     rdi, [rel tok_r10b]
    mov     esi, tok_r10b_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_r8_dl_byte_store
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .r10b_byte_load
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
.r10b_byte_load:
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
.mem_r8_dl_byte_store:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_rdi_r9_qword
    pop     r11
    push    r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .mem_rsi_al_store
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .mem_rdi_imm_byte_store
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x88
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.mem_rsi_al_store:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .mem_rdi_r9_store
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
    mov     edi, 0x06
    call    append_text_byte
    jmp     .yes
.mem_rdi_imm_byte_store:
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
.mem_rdi_r9_store:
    pop     r14
    push    r14
    call    expect_rdi_plus_r9
    test    eax, eax
    jz      .mem_r8_dl_indexed_store
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .mem_rdi_r9_imm_store
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
.mem_rdi_r9_imm_store:
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
.mem_r8_dl_indexed_store:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    call    expect_operand
    test    eax, eax
    jz      .mem_rsi_rcx_al
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
.mem_rsi_rcx_al:
    pop     r14
    push    r14
    call    expect_rsi_plus_rcx_minus_one
    test    eax, eax
    jz      .mem_rdx_r8x2_al
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
.mem_rdx_r8x2_al:
    pop     r14
    push    r14
    call    expect_rdx_plus_r8_times_2
    test    eax, eax
    jz      .mem_rdx_r8x2_plus_one_al
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
.mem_rdx_r8x2_plus_one_al:
    pop     r14
    push    r14
    call    expect_rdx_plus_r8_times_2_plus_one
    test    eax, eax
    jz      .mem_rdx_r9_cl
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
.mem_rdx_r9_cl:
    pop     r14
    push    r14
    call    expect_rdx_plus_r9
    test    eax, eax
    jz      .mem_rdi_rcx_r10b
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
.mem_rdi_rcx_r10b:
    pop     r14
    call    expect_rdi_plus_rcx_minus_one
    test    eax, eax
    jz      .bad
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
.mem_rdi_r9_qword:
    pop     r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .mem_rsi_r8_qword
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .mem_rdi_rax_qword
    pop     r11
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
.mem_rdi_rax_qword:
    pop     r14
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
.mem_rsi_r8_qword:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .rel_store_rdi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
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
.rel_store_rdi:
    pop     r14
    push    r14
    call    expect_rel_label_value
    test    eax, eax
    jz      .mem_r13_r12_store
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
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
.mem_r13_r12_store:
    pop     r14
    lea     rdi, [rel tok_mem_r13]
    mov     esi, tok_mem_r13_len
    call    expect_operand
    test    eax, eax
    jz      .no
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

er_fn match_more_byte_arith
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_add]
    mov     ecx, tok_add_len
    call    token_eq
    test    eax, eax
    jz      .cmp
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .add_cl
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
    mov     edi, 0x04
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.add_cl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    call    expect_operand
    test    eax, eax
    jz      .no
    call    expect_comma
    test    eax, eax
    jz      .bad
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.cmp:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_cmp]
    mov     ecx, tok_cmp_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_rax
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .cmp_al_cl
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x3c
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.cmp_rax:
    pop     r14
    lea     rdi, [rel tok_rax]
    mov     esi, tok_rax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_r8
    pop     r11
    call    expect_comma
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
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xd8
    call    append_text_byte
    jmp     .yes
.cmp_al_cl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_al_dl
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    jmp     .yes
.cmp_al_dl:
    pop     r14
    lea     rdi, [rel tok_dl]
    mov     esi, tok_dl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_al_mem_r8
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0xd0
    call    append_text_byte
    jmp     .yes
.cmp_al_mem_r8:
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
    mov     edi, 0x41
    call    append_text_byte
    mov     edi, 0x3a
    call    append_text_byte
    xor     edi, edi
    call    append_text_byte
    jmp     .yes
.cmp_r8:
    pop     r14
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_r9
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_rsi]
    mov     esi, tok_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .cmp_r8_rdx
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0x39
    call    append_text_byte
    mov     edi, 0xf0
    call    append_text_byte
    jmp     .yes
.cmp_r8_rdx:
    pop     r14
    mov     r10d, 0xd0
    jmp     .cmp_r64_rdx_after_comma
.cmp_r9:
    pop     r14
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_r10
    pop     r11
    mov     r10d, 0xd1
    jmp     .cmp_r64_rdx
.cmp_r10:
    pop     r14
    lea     rdi, [rel tok_r10]
    mov     esi, tok_r10_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_cl
    pop     r11
    mov     r10d, 0xd2
.cmp_r64_rdx:
    call    expect_comma
    test    eax, eax
    jz      .bad
.cmp_r64_rdx_after_comma:
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
    mov     edi, r10d
    call    append_text_byte
    jmp     .yes
.cmp_cl:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_dil
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
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0xf9
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.cmp_dil:
    pop     r14
    lea     rdi, [rel tok_edi]
    mov     esi, tok_edi_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_dil_real
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
    mov     edi, 0x81
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_u32
    jmp     .yes
.cmp_dil_real:
    pop     r14
    lea     rdi, [rel tok_dil]
    mov     esi, tok_dil_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .cmp_byte
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
    call    emit_cmp_dil_imm8
    jmp     .yes
.cmp_byte:
    pop     r14
    lea     rdi, [rel tok_byte]
    mov     esi, tok_byte_len
    call    expect_operand
    test    eax, eax
    jz      .no
    push    r14
    lea     rdi, [rel tok_mem_rdi]
    mov     esi, tok_mem_rdi_len
    call    expect_operand
    test    eax, eax
    jz      .cmp_byte_rsi
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .cmp_byte_rdi_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0x07
    call    append_text_byte
    jmp     .yes
.cmp_byte_rdi_imm:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0x3f
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.cmp_byte_rsi:
    pop     r14
    push    r14
    lea     rdi, [rel tok_mem_rsi]
    mov     esi, tok_mem_rsi_len
    call    expect_operand
    test    eax, eax
    jz      .cmp_byte_rdi_rcx
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
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0x3e
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.cmp_byte_rdi_rcx:
    pop     r14
    push    r14
    call    expect_mem_rdi_plus_rcx
    test    eax, eax
    jz      .cmp_byte_rdi_r9
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    lea     rdi, [rel tok_al]
    mov     esi, tok_al_len
    call    expect_operand
    test    eax, eax
    jz      .cmp_byte_rdi_rcx_imm
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x38
    call    append_text_byte
    mov     edi, 0x04
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    jmp     .yes
.cmp_byte_rdi_rcx_imm:
    pop     r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0x3c
    call    append_text_byte
    mov     edi, 0x0f
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.cmp_byte_rdi_r9:
    pop     r14
    call    expect_rdi_plus_r9
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
    mov     edi, 0x42
    call    append_text_byte
    mov     edi, 0x80
    call    append_text_byte
    mov     edi, 0x3c
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
    mov     qword [rel exit_subset_bad], 1
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn match_more_unary
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_not]
    mov     ecx, tok_not_len
    call    token_eq
    test    eax, eax
    jz      .or
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
    mov     edi, 0xf7
    call    append_text_byte
    mov     edi, 0xd1
    call    append_text_byte
    jmp     .yes
.or:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_or]
    mov     ecx, tok_or_len
    call    token_eq
    test    eax, eax
    jz      .neg
    lea     rdi, [rel tok_eax]
    mov     esi, tok_eax_len
    push    r14
    call    expect_operand
    test    eax, eax
    jz      .or_cl_al
    pop     r11
    call    expect_comma
    test    eax, eax
    jz      .bad
    push    r14
    call    expect_imm8_operand
    test    eax, eax
    jz      .or_eax_minus_one
    pop     r11
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    mov     rdi, [rel imm_u32_value]
    call    append_text_byte
    jmp     .yes
.or_eax_minus_one:
    pop     r14
    call    expect_minus_one_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x83
    call    append_text_byte
    mov     edi, 0xc8
    call    append_text_byte
    mov     edi, 0xff
    call    append_text_byte
    jmp     .yes
.or_cl_al:
    pop     r14
    lea     rdi, [rel tok_cl]
    mov     esi, tok_cl_len
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
    test    eax, eax
    jz      .bad
    mov     edi, 0x08
    call    append_text_byte
    mov     edi, 0xc1
    call    append_text_byte
    jmp     .yes
.neg:
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rel tok_neg]
    mov     ecx, tok_neg_len
    call    token_eq
    test    eax, eax
    jz      .no
    lea     rdi, [rel tok_r9]
    mov     esi, tok_r9_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_line_end
    test    eax, eax
    jz      .bad
    mov     edi, 0x49
    call    append_text_byte
    mov     edi, 0xf7
    call    append_text_byte
    mov     edi, 0xd9
    call    append_text_byte
    jmp     .yes
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
