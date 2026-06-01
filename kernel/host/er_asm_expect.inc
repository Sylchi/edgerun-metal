er_fn expect_operand
    er_push rbx, r12, r13
    mov     rbx, rdi
    mov     r12, rsi
    call    skip_space_inline
    mov     r13, r14
    call    skip_operand_token
    mov     rdi, r13
    mov     rsi, r14
    sub     rsi, r13
    mov     rdx, rbx
    mov     rcx, r12
    call    token_eq
    er_pop  rbx, r12, r13
    ret

er_fn expect_mem_rdi_plus_rcx
    lea     rdi, [rel tok_mem_rdi_rcx]
    mov     esi, tok_mem_rdi_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx_close]
    mov     esi, tok_rcx_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_rdx
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx_close]
    mov     esi, tok_rdx_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_minus_one_operand
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '-'
    jne     .bad
    inc     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    cmp     qword [rel imm_u32_value], 1
    jne     .bad
    mov     qword [rel imm_u32_value], -1
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_rdx_minus_one
    call    expect_rsi_plus_rdx_prefix
    test    eax, eax
    jz      .bad
    call    expect_minus_one_close
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdi_plus_rdx_minus_one
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_minus_one_close
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdi_plus_rcx_minus_one
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_minus_one_close
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_rcx_minus_one
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rcx]
    mov     esi, tok_rcx_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_minus_one_close
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdi_minus_one
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_minus_one_close
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_minus_one
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    expect_minus_one_close
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdi_plus_one
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_one_close]
    mov     esi, tok_one_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_r12_plus_one
    lea     rdi, [rel tok_mem_r12_open]
    mov     esi, tok_mem_r12_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_one_close]
    mov     esi, tok_one_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_one
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_one_close]
    mov     esi, tok_one_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_two
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_two_close]
    mov     esi, tok_two_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_three
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_three_close]
    mov     esi, tok_three_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_r8_plain_mem
    lea     rdi, [rel tok_mem_r8]
    mov     esi, tok_mem_r8_len
    call    expect_operand
    ret

er_fn expect_rdi_plus_r8
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8_close]
    mov     esi, tok_r8_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdi_plus_r8_plus_one
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8]
    mov     esi, tok_r8_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_one_close]
    mov     esi, tok_one_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_r8
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8_close]
    mov     esi, tok_r8_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_r9
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r9_close]
    mov     esi, tok_r9_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_r10
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r10_close]
    mov     esi, tok_r10_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdi_plus_r9
    lea     rdi, [rel tok_mem_rdi_open]
    mov     esi, tok_mem_rdi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r9_close]
    mov     esi, tok_r9_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdx_plus_r8_times_2
    lea     rdi, [rel tok_mem_rdx_open]
    mov     esi, tok_mem_rdx_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8_times_2_close]
    mov     esi, tok_r8_times_2_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdx_plus_r8_times_2_plus_one
    lea     rdi, [rel tok_mem_rdx_open]
    mov     esi, tok_mem_rdx_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r8_times_2]
    mov     esi, tok_r8_times_2_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_one_close]
    mov     esi, tok_one_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rdx_plus_r9
    lea     rdi, [rel tok_mem_rdx_open]
    mov     esi, tok_mem_rdx_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_r9_close]
    mov     esi, tok_r9_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_rsi_plus_rdx_prefix
    lea     rdi, [rel tok_mem_rsi_open]
    mov     esi, tok_mem_rsi_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_plus]
    mov     esi, tok_plus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_rdx]
    mov     esi, tok_rdx_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

er_fn expect_minus_one_close
    lea     rdi, [rel tok_minus]
    mov     esi, tok_minus_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    lea     rdi, [rel tok_one_close]
    mov     esi, tok_one_close_len
    call    expect_operand
    ret
.bad:
    xor     eax, eax
    ret

; expect_u32_operand() -> eax=1/0, imm_u32_value=value.
er_fn expect_u32_operand
    er_push rbx, r12, r13
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, '-'
    je      .negative
    cmp     al, ASCII_SQUOTE
    je      .char
    cmp     al, ASCII_0
    jb      .symbol
    cmp     al, ASCII_9
    ja      .symbol
    xor     ebx, ebx
    xor     r12d, r12d
    call    operand_has_hex_prefix
    test    eax, eax
    jnz     .hex_loop
.loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    cmp     al, ASCII_0
    jb      .finish
    cmp     al, ASCII_9
    ja      .finish
    sub     al, ASCII_0
    movzx   r13d, al
    cmp     rbx, U32_DIV10
    ja      .bad
    jne     .accumulate
    cmp     r13d, U32_LAST_DIGIT
    ja      .bad
.accumulate:
    imul    rbx, rbx, 10
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .loop
.finish:
    test    r12d, r12d
    jz      .bad
    mov     [rel imm_u32_value], rbx
    mov     eax, 1
    jmp     .done
.hex_loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    call    hex_digit_value
    cmp     eax, 16
    jae     .finish
    mov     r13d, eax
    cmp     rbx, U32_DIV16
    ja      .bad
    shl     rbx, 4
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .hex_loop
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret
.symbol:
    call    expect_equ_operand
    jmp     .done
.char:
    call    expect_char_operand
    jmp     .done
.negative:
    inc     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .done
    mov     rbx, [rel imm_u32_value]
    neg     ebx
    mov     [rel imm_u32_value], rbx
    mov     eax, 1
    jmp     .done

er_fn expect_imm8_operand
    call    expect_u32_operand
    test    eax, eax
    jz      .done
    cmp     qword [rel imm_u32_value], 255
    ja      .bad
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
.done:
    ret

er_fn expect_imm8_expr_operand
    push    r14
    call    skip_space_inline
    call    expect_char_operand
    test    eax, eax
    jz      .plain
    mov     rdx, [rel imm_u32_value]
    push    rdx
    lea     rdi, [rel tok_minus]
    mov     esi, tok_minus_len
    call    expect_operand
    test    eax, eax
    jz      .bad_pop
    call    expect_imm8_operand
    test    eax, eax
    jz      .bad_pop
    pop     rdx
    sub     rdx, [rel imm_u32_value]
    cmp     rdx, 255
    ja      .bad
    mov     [rel imm_u32_value], rdx
    pop     r11
    mov     eax, 1
    ret
.bad_pop:
    pop     r11
.plain:
    pop     r14
    call    expect_imm8_operand
    ret
.bad:
    pop     r11
    xor     eax, eax
    ret

; expect_u64_operand() -> eax=1/0, imm_u32_value=value.
er_fn expect_u64_operand
    er_push rbx, r12, r13
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    xor     ebx, ebx
    xor     r12d, r12d
    call    operand_has_hex_prefix
    test    eax, eax
    jnz     .hex_loop
.dec_loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    cmp     al, ASCII_0
    jb      .finish
    cmp     al, ASCII_9
    ja      .finish
    sub     al, ASCII_0
    movzx   r13d, al
    imul    rbx, rbx, 10
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .dec_loop
.hex_loop:
    cmp     r14, r15
    jae     .finish
    movzx   eax, byte [r14]
    call    hex_digit_value
    cmp     eax, 16
    jae     .finish
    mov     r13d, eax
    shl     rbx, 4
    add     rbx, r13
    inc     r14
    mov     r12d, 1
    jmp     .hex_loop
.finish:
    test    r12d, r12d
    jz      .bad
    mov     [rel imm_u32_value], rbx
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

er_fn expect_value_operand
    push    r14
    call    expect_u32_operand
    test    eax, eax
    jz      .symbol
    pop     r11
    mov     eax, 1
    ret
.symbol:
    pop     r14
    call    expect_symbol_value_operand
    ret

er_fn expect_symbol_value_operand
    er_push r10, r11
    call    skip_space_inline
    mov     r10, r14
    call    skip_operand_token
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    call    find_label_value
    test    eax, eax
    jz      .equ
    mov     [rel imm_u32_value], rdx
    mov     eax, 1
    jmp     .done
.equ:
    push    r14
    mov     r14, r10
    call    expect_equ_operand
    pop     r11
    test    eax, eax
    jz      .bad
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11
    ret

er_fn expect_rel_label_value
    er_push r10, r11
    call    skip_space_inline
    lea     rdi, [rel tok_rel_open]
    mov     esi, tok_rel_open_len
    call    expect_operand
    test    eax, eax
    jz      .bad
    call    skip_space_inline
    mov     r10, r14
.name:
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, ']'
    je      .name_done
    cmp     al, 10
    je      .bad
    cmp     al, ';'
    je      .bad
    inc     r14
    jmp     .name
.name_done:
    mov     r11, r14
    sub     r11, r10
    test    r11, r11
    jz      .bad
    inc     r14
    call    find_label_value
    test    eax, eax
    jz      .bad
    mov     [rel imm_u32_value], rdx
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  r10, r11
    ret

er_fn expect_target_operand
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    mov     rax, r14
    call    skip_operand_token
    cmp     r14, rax
    je      .bad
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; expect_char_operand() -> eax=1/0, imm_u32_value=byte.
er_fn expect_char_operand
    inc     r14
    cmp     r14, r15
    jae     .bad
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .bad
    movzx   edx, al
    inc     r14
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], ASCII_SQUOTE
    jne     .bad
    inc     r14
    mov     [rel imm_u32_value], rdx
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

; expect_equ_operand() -> eax=1/0, imm_u32_value=value.
er_fn expect_equ_operand
    er_push rbx, r12, r13
    mov     rbx, r14
    call    skip_operand_token
    mov     r12, r14
    sub     r12, rbx
    xor     r13d, r13d
.loop:
    cmp     r13, [rel equ_count]
    jae     .bad
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, [rel equ_name_ptr + r13 * 8]
    mov     rcx, [rel equ_name_len + r13 * 8]
    call    token_eq
    test    eax, eax
    jnz     .found
    inc     r13
    jmp     .loop
.found:
    mov     rax, [rel equ_value + r13 * 8]
    mov     [rel imm_u32_value], rax
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx, r12, r13
    ret

er_fn expect_equ_mul_operand
    er_push rbx
    call    expect_equ_operand
    test    eax, eax
    jz      .bad
    mov     rbx, [rel imm_u32_value]
    call    skip_space_inline
    cmp     r14, r15
    jae     .bad
    cmp     byte [r14], '*'
    jne     .bad
    inc     r14
    call    expect_u32_operand
    test    eax, eax
    jz      .bad
    imul    rbx, [rel imm_u32_value]
    mov     [rel imm_u32_value], rbx
    mov     eax, 1
    jmp     .done
.bad:
    xor     eax, eax
.done:
    er_pop  rbx
    ret

; operand_has_hex_prefix() -> eax=1/0; consumes 0x prefix when present.
er_fn operand_has_hex_prefix
    cmp     r14, r15
    jae     .no
    cmp     byte [r14], ASCII_0
    jne     .no
    lea     rax, [r14 + 1]
    cmp     rax, r15
    jae     .no
    movzx   eax, byte [r14 + 1]
    cmp     al, ASCII_x
    je      .yes
    cmp     al, ASCII_X
    jne     .no
.yes:
    add     r14, 2
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

; hex_digit_value(ch=al) -> eax=value, or 16 when invalid.
er_fn hex_digit_value
    cmp     al, ASCII_0
    jb      .invalid
    cmp     al, ASCII_9
    jbe     .digit
    cmp     al, ASCII_A
    jb      .lower
    cmp     al, ASCII_F
    jbe     .upper_digit
.lower:
    cmp     al, ASCII_a
    jb      .invalid
    cmp     al, ASCII_f
    ja      .invalid
    sub     al, ASCII_a - 10
    movzx   eax, al
    ret
.upper_digit:
    sub     al, ASCII_A - 10
    movzx   eax, al
    ret
.digit:
    sub     al, ASCII_0
    movzx   eax, al
    ret
.invalid:
    mov     eax, 16
    ret

er_fn expect_comma
    call    skip_space_inline
    cmp     r14, r15
    jae     .no
    cmp     byte [r14], ','
    jne     .no
    inc     r14
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

er_fn expect_line_end
    call    skip_space_inline
    cmp     r14, r15
    jae     .yes
    movzx   eax, byte [r14]
    cmp     al, 10
    je      .yes
    cmp     al, ';'
    je      .yes
    xor     eax, eax
    ret
.yes:
    mov     eax, 1
    ret
