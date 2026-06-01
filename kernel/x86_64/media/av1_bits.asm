; EdgeRun AV1 bit reader/writer — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

SECTION .text

; er_av1_bits_read_init(ctx, buf, len)
; rdi=ctx, rsi=buf, edx=len
er_fn er_av1_bits_read_init
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     [rdi + AV1_BITS_BUF], rsi
    mov     [rdi + AV1_BITS_LEN], edx
    mov     dword [rdi + AV1_BITS_POS], 0
    xor     eax, eax
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_av1_bits_read(ctx, count) -> eax=value, rdx=error
; Reads AV1 f(n), most-significant bit first.
; rdi=ctx, esi=count
er_fn er_av1_bits_read
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, 32
    ja      .invalid_param
    mov     r12, [rdi + AV1_BITS_BUF]
    mov     r13d, [rdi + AV1_BITS_LEN]
    mov     ebx, [rdi + AV1_BITS_POS]
    mov     eax, ebx
    add     eax, esi
    jc      .no_data
    mov     edx, r13d
    shl     edx, 3
    cmp     eax, edx
    ja      .no_data
    xor     eax, eax
    test    esi, esi
    jz      .store_pos
.loop:
    shl     eax, 1
    mov     ecx, ebx
    shr     ecx, 3
    movzx   edx, byte [r12 + rcx]
    mov     ecx, ebx
    and     ecx, 7
    xor     ecx, 7
    shr     edx, cl
    and     edx, 1
    or      eax, edx
    inc     ebx
    dec     esi
    jnz     .loop
.store_pos:
    mov     [rdi + AV1_BITS_POS], ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_av1_bits_write_init(ctx, buf, len)
; rdi=ctx, rsi=buf, edx=len
er_fn er_av1_bits_write_init
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     [rdi + AV1_BITS_BUF], rsi
    mov     [rdi + AV1_BITS_LEN], edx
    mov     dword [rdi + AV1_BITS_POS], 0
    xor     eax, eax
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_av1_bits_write(ctx, value, count) -> eax=bits_written, rdx=error
; rdi=ctx, esi=value, edx=count
er_fn er_av1_bits_write
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     edx, 32
    ja      .invalid_param
    mov     r12, [rdi + AV1_BITS_BUF]
    mov     r13d, [rdi + AV1_BITS_LEN]
    mov     ebx, [rdi + AV1_BITS_POS]
    mov     r14d, edx
    mov     r15d, esi
    mov     eax, ebx
    add     eax, edx
    jc      .no_space
    mov     ecx, r13d
    shl     ecx, 3
    cmp     eax, ecx
    ja      .no_space
    test    edx, edx
    jz      .store_pos
.loop:
    mov     ecx, r14d
    dec     ecx
    mov     eax, r15d
    shr     eax, cl
    and     eax, 1
    mov     esi, ebx
    shr     esi, 3
    mov     edx, ebx
    and     edx, 7
    xor     edx, 7
    mov     cl, dl
    mov     dl, 1
    shl     dl, cl
    not     dl
    and     [r12 + rsi], dl
    test    eax, eax
    jz      .bit_done
    not     dl
    or      [r12 + rsi], dl
.bit_done:
    inc     ebx
    dec     r14d
    jnz     .loop
.store_pos:
    mov     [rdi + AV1_BITS_POS], ebx
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_bits_bytes_written(ctx) -> eax=ceil(bit_pos / 8), rdx=0
; rdi=ctx
er_fn er_av1_bits_bytes_written
    test    rdi, rdi
    jz      .invalid_param
    mov     eax, [rdi + AV1_BITS_POS]
    add     eax, 7
    shr     eax, 3
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_av1_cdf_symbol(cdf, nsymbs, code) -> eax=symbol, rdx=error
; rdi=cdf u16 cumulative probabilities, esi=symbol count, edx=15-bit code
er_fn er_av1_cdf_symbol
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_CDF_SYMBOLS_MIN
    jb      .invalid_param
    cmp     esi, AV1_CDF_SYMBOLS_MAX
    ja      .invalid_param
    cmp     edx, AV1_CDF_PROB_TOP
    jae     .invalid_param
    mov     r8d, esi
    dec     r8d
    xor     eax, eax
    xor     r9d, r9d
    mov     r10d, esi
.loop:
    cmp     eax, esi
    jae     .validated
    movzx   ecx, word [rdi + rax * 2]
    cmp     ecx, r9d
    jbe     .corrupt
    cmp     eax, r8d
    je      .check_final
    cmp     ecx, AV1_CDF_PROB_TOP
    jae     .corrupt
    jmp     .select
.check_final:
    cmp     ecx, AV1_CDF_PROB_TOP
    jne     .corrupt
.select:
    cmp     r10d, esi
    jne     .next
    cmp     edx, ecx
    jae     .next
    mov     r10d, eax
.next:
    mov     r9d, ecx
    inc     eax
    jmp     .loop
.validated:
    cmp     r10d, esi
    jae     .corrupt
    mov     eax, r10d
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_av1_symbol_init(ctx, buf, len) -> eax=initial_bits, rdx=error
; rdi=ctx, rsi=buf, edx=len
er_fn er_av1_symbol_init
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    mov     r12, rdi
    mov     [r12 + AV1_SYMBOL_BUF], rsi
    mov     [r12 + AV1_SYMBOL_LEN], edx
    mov     dword [r12 + AV1_SYMBOL_POS], 0
    mov     ebx, edx
    shl     ebx, 3
    jc      .invalid_param
    mov     esi, ebx
    cmp     esi, AV1_CDF_PROB_BITS
    jbe     .have_bits
    mov     esi, AV1_CDF_PROB_BITS
.have_bits:
    mov     r13d, esi
    mov     rdi, r12
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     ecx, AV1_CDF_PROB_BITS
    sub     ecx, r13d
    shl     eax, cl
    xor     eax, AV1_CDF_PROB_TOP - 1
    mov     [r12 + AV1_SYMBOL_VALUE], eax
    mov     dword [r12 + AV1_SYMBOL_RANGE], AV1_CDF_PROB_TOP
    sub     ebx, AV1_CDF_PROB_BITS
    mov     [r12 + AV1_SYMBOL_MAX_BITS], ebx
    mov     eax, r13d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_av1_symbol_read_symbol(ctx, cdf, nsymbs, disable_update) -> eax=symbol, rdx=error
; rdi=ctx, rsi=cdf u16[N+1], edx=N, ecx=disable_update
er_fn er_av1_symbol_read_symbol
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, AV1_CDF_SYMBOLS_MIN
    jb      .invalid_param
    cmp     edx, AV1_CDF_SYMBOLS_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15d, ecx
    mov     eax, [r12 + AV1_SYMBOL_RANGE]
    test    eax, eax
    jz      .corrupt
    xor     ebx, ebx
    xor     r9d, r9d
.validate_loop:
    cmp     ebx, r14d
    jae     .decode_start
    movzx   ecx, word [r13 + rbx * 2]
    cmp     ecx, r9d
    jbe     .corrupt
    mov     r8d, r14d
    dec     r8d
    cmp     ebx, r8d
    je      .validate_final
    cmp     ecx, AV1_CDF_PROB_TOP
    jae     .corrupt
    jmp     .validate_next
.validate_final:
    cmp     ecx, AV1_CDF_PROB_TOP
    jne     .corrupt
.validate_next:
    mov     r9d, ecx
    inc     ebx
    jmp     .validate_loop
.decode_start:
    xor     ebx, ebx
    mov     r11d, [r12 + AV1_SYMBOL_RANGE]
    mov     r10d, [r12 + AV1_SYMBOL_VALUE]
.decode_loop:
    mov     r8d, r11d
    movzx   ecx, word [r13 + rbx * 2]
    mov     eax, AV1_CDF_PROB_TOP
    sub     eax, ecx
    shr     eax, AV1_CDF_EC_PROB_SHIFT
    mov     ecx, [r12 + AV1_SYMBOL_RANGE]
    shr     ecx, 8
    imul    eax, ecx
    shr     eax, 7 - AV1_CDF_EC_PROB_SHIFT
    mov     ecx, r14d
    sub     ecx, ebx
    dec     ecx
    imul    ecx, AV1_CDF_EC_MIN_PROB
    add     eax, ecx
    cmp     r10d, eax
    jae     .selected
    inc     ebx
    cmp     ebx, r14d
    jb      .decode_loop
    jmp     .corrupt
.selected:
    sub     r8d, eax
    jz      .corrupt
    sub     r10d, eax
    bsr     ecx, r8d
    mov     r9d, AV1_CDF_PROB_BITS
    sub     r9d, ecx
    mov     ecx, r9d
    shl     r8d, cl
    mov     [r12 + AV1_SYMBOL_RANGE], r8d
    mov     eax, [r12 + AV1_SYMBOL_MAX_BITS]
    test    eax, eax
    jg      .max_positive
    xor     r8d, r8d
    jmp     .read_new_bits
.max_positive:
    mov     r8d, r9d
    cmp     eax, r8d
    jae     .read_new_bits
    mov     r8d, eax
.read_new_bits:
    mov     rdi, r12
    mov     esi, r8d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     ecx, r9d
    sub     ecx, r8d
    shl     eax, cl
    mov     ecx, r9d
    inc     r10d
    shl     r10d, cl
    dec     r10d
    xor     eax, r10d
    mov     [r12 + AV1_SYMBOL_VALUE], eax
    mov     eax, [r12 + AV1_SYMBOL_MAX_BITS]
    sub     eax, r9d
    mov     [r12 + AV1_SYMBOL_MAX_BITS], eax
    test    r15d, r15d
    jnz     .return_symbol
    call    .update_cdf
.return_symbol:
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

.update_cdf:
    movzx   ecx, word [r13 + r14 * 2]
    mov     r15d, 3
    cmp     ecx, 15
    jbe     .rate_count_31
    inc     r15d
.rate_count_31:
    cmp     ecx, 31
    jbe     .rate_size
    inc     r15d
.rate_size:
    bsr     eax, r14d
    cmp     eax, 2
    jbe     .rate_add
    mov     eax, 2
.rate_add:
    add     r15d, eax
    xor     r10d, r10d
    xor     r8d, r8d
    mov     r9d, r14d
    dec     r9d
.update_loop:
    cmp     r8d, r9d
    jae     .update_count
    cmp     r8d, ebx
    jne     .update_value
    mov     r10d, AV1_CDF_PROB_TOP
.update_value:
    movzx   eax, word [r13 + r8 * 2]
    cmp     r10d, eax
    jae     .increase_value
    mov     edx, eax
    sub     edx, r10d
    mov     ecx, r15d
    shr     edx, cl
    sub     eax, edx
    jmp     .store_value
.increase_value:
    mov     edx, r10d
    sub     edx, eax
    mov     ecx, r15d
    shr     edx, cl
    add     eax, edx
.store_value:
    mov     [r13 + r8 * 2], ax
    inc     r8d
    jmp     .update_loop
.update_count:
    movzx   eax, word [r13 + r14 * 2]
    cmp     eax, 32
    jae     .update_done
    inc     eax
    mov     [r13 + r14 * 2], ax
.update_done:
    ret

; er_av1_symbol_read_bool(ctx) -> eax=bit, rdx=error
; rdi=ctx
er_fn er_av1_symbol_read_bool
    mov     rsi, av1_bool_cdf
    mov     edx, AV1_CDF_SYMBOLS_MIN
    mov     ecx, 1
    call    er_av1_symbol_read_symbol
    er_ret

; er_av1_symbol_read_literal(ctx, count) -> eax=value, rdx=error
; rdi=ctx, esi=count
er_fn er_av1_symbol_read_literal
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, 32
    ja      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    xor     ebx, ebx
    test    esi, esi
    jz      .return_value
.loop:
    mov     rdi, r12
    call    er_av1_symbol_read_bool
    test    edx, edx
    jnz     .done
    shl     ebx, 1
    or      ebx, eax
    dec     r13d
    jnz     .loop
.return_value:
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13
    er_ret

SECTION .data
av1_bool_cdf: dw AV1_CDF_BOOL_SPLIT, AV1_CDF_PROB_TOP, 0
