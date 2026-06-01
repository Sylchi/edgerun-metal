; EdgeRun conversion/encoding operations — included by runtime.asm

; ==================================================================
; er_strtou64 — parse decimal string to uint64
; uint64_t er_strtou64(const char* str, char** endptr)
; Skips whitespace. Handles optional +/-. Sets endptr if non-NULL.
; Returns parsed value, or 0 on parse failure.
; ==================================================================
er_fn er_strtou64
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, rsi
    xor     r10d, r10d
    xor     r9d, r9d
    xor     r11d, r11d
.strtou64_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .strtou64_skip_inc
    cmp     al, 9
    je      .strtou64_skip_inc
    cmp     al, 10
    je      .strtou64_skip_inc
    cmp     al, 13
    je      .strtou64_skip_inc
    jmp     .strtou64_sign
.strtou64_skip_inc:
    inc     r12
    jmp     .strtou64_skip
.strtou64_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .strtou64_sign_plus
    cmp     al, '-'
    je      .strtou64_sign_minus
    jmp     .strtou64_parse
.strtou64_sign_plus:
    inc     r12
    jmp     .strtou64_parse
.strtou64_sign_minus:
    mov     r10b, 1
    inc     r12
.strtou64_parse:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jb      .strtou64_done
    cmp     al, '9'
    ja      .strtou64_done
    sub     al, '0'
    movzx   ecx, al
    er_check_nonzero r11, .strtou64_consume
    mov     rax, r9
    mov     rbx, 10
    mul     rbx
    er_check_nonzero rdx, .strtou64_overflow
    add     rax, rcx
    jc      .strtou64_overflow
    mov     r9, rax
    inc     r12
    jmp     .strtou64_parse
.strtou64_overflow:
    mov     r11, 1
.strtou64_consume:
    inc     r12
    jmp     .strtou64_parse
.strtou64_done:
    er_check_zero r13, .strtou64_ret
    mov     [r13], r12
.strtou64_ret:
    er_check_zero r10, .strtou64_return_accum
    neg     r9
.strtou64_return_accum:
    er_check_zero r11, .strtou64_no_overflow
    mov     r9, -1
.strtou64_no_overflow:
    mov     rax, r9
    er_pop  rbx, r12, r13
    er_ret

; ==================================================================
; er_strtoi64 — parse decimal string to int64
; int64_t er_strtoi64(const char* str, char** endptr)
; Skips whitespace. Handles sign. Sets endptr if non-NULL.
; Returns parsed value, clamped to INT64_MIN/INT64_MAX on overflow.
; ==================================================================
er_fn er_strtoi64
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, rsi
    xor     r10d, r10d
    xor     r9d, r9d
    xor     r11d, r11d
.strtoi64_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .strtoi64_skip_inc
    cmp     al, 9
    je      .strtoi64_skip_inc
    cmp     al, 10
    je      .strtoi64_skip_inc
    cmp     al, 13
    je      .strtoi64_skip_inc
    jmp     .strtoi64_sign
.strtoi64_skip_inc:
    inc     r12
    jmp     .strtoi64_skip
.strtoi64_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .strtoi64_sign_plus
    cmp     al, '-'
    je      .strtoi64_sign_minus
    jmp     .strtoi64_parse
.strtoi64_sign_plus:
    inc     r12
    jmp     .strtoi64_parse
.strtoi64_sign_minus:
    mov     r10b, 1
    inc     r12
.strtoi64_parse:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jb      .strtoi64_done
    cmp     al, '9'
    ja      .strtoi64_done
    sub     al, '0'
    movzx   ecx, al
    er_check_nonzero r11, .strtoi64_consume
    mov     rax, r9
    mov     rbx, 10
    mul     rbx
    er_check_nonzero rdx, .strtoi64_overflow
    add     rax, rcx
    jc      .strtoi64_overflow
    mov     r9, rax
    inc     r12
    jmp     .strtoi64_parse
.strtoi64_overflow:
    mov     r11, 1
.strtoi64_consume:
    inc     r12
    jmp     .strtoi64_parse
.strtoi64_done:
    er_check_zero r13, .strtoi64_ret
    mov     [r13], r12
.strtoi64_ret:
    er_check_nonzero r11, .strtoi64_clamp
    er_check_zero r10, .strtoi64_pos
    mov     rax, r9
    mov     rbx, 0x7fffffffffffffff
    cmp     rax, rbx
    ja      .strtoi64_neg_overflow
    neg     r9
    jmp     .strtoi64_pos
.strtoi64_neg_overflow:
    mov     r9, 0x8000000000000000
    jmp     .strtoi64_pos
.strtoi64_clamp:
    er_check_nonzero r10, .strtoi64_clamp_neg
    mov     r9, 0x7fffffffffffffff
    jmp     .strtoi64_pos
.strtoi64_clamp_neg:
    mov     r9, 0x8000000000000000
.strtoi64_pos:
    mov     rax, r9
    er_pop  rbx, r12, r13
    er_ret

; ==================================================================
; er_strtou64_hex — parse hex string to uint64
; uint64_t er_strtou64_hex(const char* str, char** endptr)
; Skips optional "0x" or "0X" prefix. Sets endptr if non-NULL.
; ==================================================================
er_fn er_strtou64_hex
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, rsi
    xor     r9d, r9d
    xor     r11d, r11d
.strtou64_hex_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .strtou64_hex_skip_inc
    cmp     al, 9
    je      .strtou64_hex_skip_inc
    cmp     al, 10
    je      .strtou64_hex_skip_inc
    cmp     al, 13
    je      .strtou64_hex_skip_inc
    jmp     .strtou64_hex_prefix
.strtou64_hex_skip_inc:
    inc     r12
    jmp     .strtou64_hex_skip
.strtou64_hex_prefix:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jne     .strtou64_hex_parse
    movzx   eax, byte [r12 + 1]
    cmp     al, 'x'
    je      .strtou64_hex_skip2
    cmp     al, 'X'
    jne     .strtou64_hex_parse
.strtou64_hex_skip2:
    add     r12, 2
.strtou64_hex_parse:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jb      .strtou64_hex_done
    cmp     al, '9'
    ja      .strtou64_hex_alpha_upper
    sub     al, '0'
    jmp     .strtou64_hex_digit
.strtou64_hex_alpha_upper:
    cmp     al, 'A'
    jb      .strtou64_hex_done
    cmp     al, 'F'
    ja      .strtou64_hex_alpha_lower
    sub     al, 'A' - 10
    jmp     .strtou64_hex_digit
.strtou64_hex_alpha_lower:
    cmp     al, 'a'
    jb      .strtou64_hex_done
    cmp     al, 'f'
    ja      .strtou64_hex_done
    sub     al, 'a' - 10
.strtou64_hex_digit:
    movzx   ecx, al
    er_check_nonzero r11, .strtou64_hex_consume
    mov     rax, r9
    mov     rbx, 16
    mul     rbx
    er_check_nonzero rdx, .strtou64_hex_overflow
    add     rax, rcx
    jc      .strtou64_hex_overflow
    mov     r9, rax
    inc     r12
    jmp     .strtou64_hex_parse
.strtou64_hex_overflow:
    mov     r11, 1
.strtou64_hex_consume:
    inc     r12
    jmp     .strtou64_hex_parse
.strtou64_hex_done:
    er_check_zero r13, .strtou64_hex_ret
    mov     [r13], r12
.strtou64_hex_ret:
    er_check_zero r11, .strtou64_hex_no_overflow
    mov     r9, -1
.strtou64_hex_no_overflow:
    mov     rax, r9
    er_pop  rbx, r12, r13
    er_ret

; ==================================================================
; er_hex_encode — encode bytes to lowercase hex string
; void er_hex_encode(const void* data, size_t len, char* out)
; out must have space for len*2 characters (no null terminator added)
; ==================================================================
er_fn er_hex_encode
    er_check_zero rsi, .hexenc_done
    xor     r8d, r8d
.hexenc_loop:
    cmp     r8, rsi
    jae     .hexenc_done
    movzx   eax, byte [rdi + r8]
    mov     ecx, eax
    shr     al, 4
    and     cl, 0x0f
    cmp     al, 10
    jb      .hexenc_hi_digit
    add     al, 'a' - 10
    jmp     .hexenc_store_hi
.hexenc_hi_digit:
    add     al, '0'
.hexenc_store_hi:
    mov     byte [rdx + r8*2], al
    mov     al, cl
    cmp     al, 10
    jb      .hexenc_lo_digit
    add     al, 'a' - 10
    jmp     .hexenc_store_lo
.hexenc_lo_digit:
    add     al, '0'
.hexenc_store_lo:
    mov     byte [rdx + r8*2 + 1], al
    inc     r8
    jmp     .hexenc_loop
.hexenc_done:
    er_ret

; ==================================================================
; er_hex_decode — decode hex string to bytes
; size_t er_hex_decode(const char* hex, size_t len, void* out)
; Returns number of bytes written, or 0 on invalid hex or odd length.
; ==================================================================
er_fn er_hex_decode
    er_check_zero rsi, .hexdec_done_zero
    test    sil, 1
    jnz     .hexdec_done_zero
    xor     r8d, r8d
    xor     r9d, r9d
.hexdec_loop:
    cmp     r8, rsi
    jae     .hexdec_done
    movzx   eax, byte [rdi + r8]
    call    .hexdec_nibble
    jc      .hexdec_done_zero
    shl     al, 4
    mov     cl, al
    movzx   eax, byte [rdi + r8 + 1]
    call    .hexdec_nibble
    jc      .hexdec_done_zero
    or      cl, al
    mov     byte [rdx + r9], cl
    add     r8, 2
    inc     r9
    jmp     .hexdec_loop
.hexdec_done:
    mov     rax, r9
    er_ret
.hexdec_done_zero:
    xor     eax, eax
    er_ret
.hexdec_nibble:
    cmp     al, '0'
    jb      .nibble_invalid
    cmp     al, '9'
    ja      .nibble_upper
    sub     al, '0'
    clc
    ret
.nibble_upper:
    cmp     al, 'A'
    jb      .nibble_invalid
    cmp     al, 'F'
    ja      .nibble_lower
    sub     al, 'A' - 10
    clc
    ret
.nibble_lower:
    cmp     al, 'a'
    jb      .nibble_invalid
    cmp     al, 'f'
    ja      .nibble_invalid
    sub     al, 'a' - 10
    clc
    ret
.nibble_invalid:
    stc
    ret

; ==================================================================
; er_utf8_encode — encode Unicode codepoint to UTF-8 bytes
; int er_utf8_encode(uint32_t codepoint, char* out)
; Returns number of bytes written (1-4), or 0 on invalid codepoint
; ==================================================================
er_fn er_utf8_encode
    cmp     edi, 0x7F
    jbe     .utf8enc_1byte
    cmp     edi, 0x7FF
    jbe     .utf8enc_2byte
    cmp     edi, 0xFFFF
    jbe     .utf8enc_3byte
    cmp     edi, 0x10FFFF
    ja      .utf8enc_invalid
    mov     eax, edi
    shr     eax, 18
    and     eax, 0x07
    or      eax, 0xF0
    mov     byte [rsi], al
    mov     eax, edi
    shr     eax, 12
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 1], al
    mov     eax, edi
    shr     eax, 6
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 2], al
    mov     eax, edi
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 3], al
    mov     eax, 4
    er_ret
.utf8enc_3byte:
    mov     eax, edi
    shr     eax, 12
    and     eax, 0x0F
    or      eax, 0xE0
    mov     byte [rsi], al
    mov     eax, edi
    shr     eax, 6
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 1], al
    mov     eax, edi
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 2], al
    mov     eax, 3
    er_ret
.utf8enc_2byte:
    mov     eax, edi
    shr     eax, 6
    and     eax, 0x1F
    or      eax, 0xC0
    mov     byte [rsi], al
    mov     eax, edi
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 1], al
    mov     eax, 2
    er_ret
.utf8enc_1byte:
    mov     byte [rsi], dil
    mov     eax, 1
    er_ret
.utf8enc_invalid:
    xor     eax, eax
    er_ret

; ==================================================================
; er_utf8_decode — decode single UTF-8 codepoint from bytes
; uint32_t er_utf8_decode(const char* str, size_t* len)
; Returns codepoint, sets *len to bytes consumed.
; Returns 0 and sets *len to 0 on invalid encoding.
; ==================================================================
er_fn er_utf8_decode
    movzx   eax, byte [rdi]
    er_check_zero al, .utf8dec_invalid
    test    al, 0x80
    jz      .utf8dec_1byte
    test    al, 0x20
    jz      .utf8dec_2byte
    test    al, 0x10
    jz      .utf8dec_3byte
    test    al, 0x08
    jnz     .utf8dec_invalid
    mov     ecx, 4
    and     eax, 0x07
    jmp     .utf8dec_continue
.utf8dec_3byte:
    mov     ecx, 3
    and     eax, 0x0F
    jmp     .utf8dec_continue
.utf8dec_2byte:
    mov     ecx, 2
    and     eax, 0x1F
    jmp     .utf8dec_continue
.utf8dec_1byte:
    mov     ecx, 1
    and     eax, 0x7F
    jmp     .utf8dec_store_len
.utf8dec_continue:
    mov     r8d, 1
.utf8dec_cont_loop:
    cmp     r8, rcx
    jae     .utf8dec_store_len
    movzx   edx, byte [rdi + r8]
    test    dl, 0x80
    jz      .utf8dec_invalid
    test    dl, 0x40
    jnz     .utf8dec_invalid
    shl     eax, 6
    and     edx, 0x3F
    or      eax, edx
    inc     r8
    jmp     .utf8dec_cont_loop
.utf8dec_store_len:
    er_check_zero rsi, .utf8dec_ret
    mov     [rsi], rcx
.utf8dec_ret:
    er_ret
.utf8dec_invalid:
    xor     eax, eax
    er_check_zero rsi, .utf8dec_ret
    mov     qword [rsi], 0
    er_ret

; ==================================================================
; er_digit_from_char — convert ASCII digit character to value (0-35)
; Internal helper used by strtou64_base and strtoi64_base
; Input: al = character, Output: al = digit value (0-35), CF=0
; On invalid: CF=1
; ==================================================================
er_digit_from_char:
    cmp     al, '0'
    jb      .dfc_invalid
    cmp     al, '9'
    ja      .dfc_upper
    sub     al, '0'
    clc
    ret
.dfc_upper:
    cmp     al, 'A'
    jb      .dfc_invalid
    cmp     al, 'Z'
    ja      .dfc_lower
    sub     al, 'A' - 10
    clc
    ret
.dfc_lower:
    cmp     al, 'a'
    jb      .dfc_invalid
    cmp     al, 'z'
    ja      .dfc_invalid
    sub     al, 'a' - 10
    clc
    ret
.dfc_invalid:
    stc
    ret

; ==================================================================
; er_strtou64_base — parse string to uint64 with configurable base (2-36)
; uint64_t er_strtou64_base(const char* str, char** endptr, int base)
; Skips whitespace, handles +/- sign. Returns 0 on parse failure.
; Overflow returns UINT64_MAX.
; ==================================================================
er_fn er_strtou64_base
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, rsi
    mov     ebx, edx
    xor     r10d, r10d
    xor     r9d, r9d
    xor     r11d, r11d
    cmp     ebx, 2
    jl      .stoub_set_endptr
    cmp     ebx, 36
    jg      .stoub_set_endptr
.stoub_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .stoub_skip_inc
    cmp     al, 9
    je      .stoub_skip_inc
    cmp     al, 10
    je      .stoub_skip_inc
    cmp     al, 13
    je      .stoub_skip_inc
    jmp     .stoub_sign
.stoub_skip_inc:
    inc     r12
    jmp     .stoub_skip
.stoub_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .stoub_sign_plus
    cmp     al, '-'
    jne     .stoub_parse
    mov     r10b, 1
    inc     r12
    jmp     .stoub_parse
.stoub_sign_plus:
    inc     r12
.stoub_parse:
    movzx   eax, byte [r12]
    call    er_digit_from_char
    jc      .stoub_done
    cmp     al, bl
    jae     .stoub_done
    movzx   ecx, al
    er_check_nonzero r11, .stoub_consume
    mov     rax, -1
    sub     rax, rcx
    xor     edx, edx
    div     rbx
    cmp     r9, rax
    ja      .stoub_overflow
    mov     rax, r9
    mul     rbx
    add     rax, rcx
    mov     r9, rax
    inc     r12
    jmp     .stoub_parse
.stoub_overflow:
    mov     r11, 1
.stoub_consume:
    inc     r12
    jmp     .stoub_parse
.stoub_done:
    er_check_zero r13, .stoub_ret
    mov     [r13], r12
.stoub_ret:
    er_check_zero r10, .stoub_no_neg
    neg     r9
.stoub_no_neg:
    er_check_zero r11, .stoub_no_of
    mov     r9, -1
.stoub_no_of:
    mov     rax, r9
    er_pop  rbx, r12, r13
    er_ret
.stoub_set_endptr:
    er_check_zero r13, .stoub_ret_zero
    mov     [r13], r12
.stoub_ret_zero:
    xor     eax, eax
    er_pop  rbx, r12, r13
    er_ret

; ==================================================================
; er_strtoi64_base — parse string to int64 with configurable base (2-36)
; int64_t er_strtoi64_base(const char* str, char** endptr, int base)
; Skips whitespace, handles sign. Returns INT64_MIN/MAX on overflow.
; ==================================================================
er_fn er_strtoi64_base
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, rsi
    mov     ebx, edx
    xor     r10d, r10d
    xor     r9d, r9d
    xor     r11d, r11d
    cmp     ebx, 2
    jl      .stoib_set_endptr
    cmp     ebx, 36
    jg      .stoib_set_endptr
.stoib_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .stoib_skip_inc
    cmp     al, 9
    je      .stoib_skip_inc
    cmp     al, 10
    je      .stoib_skip_inc
    cmp     al, 13
    je      .stoib_skip_inc
    jmp     .stoib_sign
.stoib_skip_inc:
    inc     r12
    jmp     .stoib_skip
.stoib_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .stoib_sign_plus
    cmp     al, '-'
    jne     .stoib_parse
    mov     r10b, 1
    inc     r12
    jmp     .stoib_parse
.stoib_sign_plus:
    inc     r12
.stoib_parse:
    movzx   eax, byte [r12]
    call    er_digit_from_char
    jc      .stoib_done
    cmp     al, bl
    jae     .stoib_done
    movzx   ecx, al
    er_check_nonzero r11, .stoib_consume
    mov     rax, 0x7fffffffffffffff
    sub     rax, rcx
    xor     edx, edx
    div     rbx
    cmp     r9, rax
    ja      .stoib_overflow
    mov     rax, r9
    mul     rbx
    add     rax, rcx
    mov     r9, rax
    inc     r12
    jmp     .stoib_parse
.stoib_overflow:
    mov     r11, 1
.stoib_consume:
    inc     r12
    jmp     .stoib_parse
.stoib_done:
    er_check_zero r13, .stoib_ret
    mov     [r13], r12
.stoib_ret:
    er_check_nonzero r11, .stoib_clamp
    er_check_zero r10, .stoib_pos
    mov     rax, r9
    mov     rbx, 0x7fffffffffffffff
    cmp     rax, rbx
    ja      .stoib_neg_overflow
    neg     r9
    jmp     .stoib_pos
.stoib_neg_overflow:
    mov     r9, 0x8000000000000000
    jmp     .stoib_pos
.stoib_clamp:
    er_check_nonzero r10, .stoib_clamp_neg
    mov     r9, 0x7fffffffffffffff
    jmp     .stoib_pos
.stoib_clamp_neg:
    mov     r9, 0x8000000000000000
.stoib_pos:
    mov     rax, r9
    er_pop  rbx, r12, r13
    er_ret
.stoib_set_endptr:
    er_check_zero r13, .stoib_ret_zero
    mov     [r13], r12
.stoib_ret_zero:
    xor     eax, eax
    er_pop  rbx, r12, r13
    er_ret
