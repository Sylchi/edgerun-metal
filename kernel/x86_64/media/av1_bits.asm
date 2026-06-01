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
