; EdgeRun AV1 reduced-still frame header decoder/encoder — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written

SECTION .text

; er_av1_frame_decode_reduced_still(payload, len, seq_desc, frame_desc)
; rdi=payload, esi=len, rdx=seq_desc, rcx=frame_desc. Returns eax=header_bytes.
er_fn er_av1_frame_decode_reduced_still
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 1
    jne     .unsupported
    mov     r12, rdx
    mov     r13, rcx
    mov     r14d, esi
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .done

    mov     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    mov     byte [r13 + AV1_FRAME_SHOW_FRAME], 1

    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_WIDTH], eax

    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_HEIGHT], eax

    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jnz     .render_different
    mov     eax, [r13 + AV1_FRAME_WIDTH]
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    mov     eax, [r13 + AV1_FRAME_HEIGHT]
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax
    jmp     .allow_intrabc

.render_different:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax

.allow_intrabc:
    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_ALLOW_INTRABC], al
    mov     ebx, [rsp + AV1_BITS_POS]
    mov     [r13 + AV1_FRAME_HEADER_BITS], ebx
    lea     eax, [rbx + 7]
    shr     eax, 3
    cmp     eax, r14d
    ja      .no_data
    mov     [r13 + AV1_FRAME_TILE_OFFSET], eax
    mov     ecx, r14d
    sub     ecx, eax
    mov     [r13 + AV1_FRAME_TILE_LEN], ecx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_frame_encode_reduced_still(out, cap, seq_desc, width, height)
; rdi=out, esi=cap, rdx=seq_desc, ecx=width, r8d=height. Returns eax=bytes.
er_fn er_av1_frame_encode_reduced_still
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    test    r8d, r8d
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 1
    jne     .unsupported
    mov     r12, rdx
    mov     r13d, ecx
    mov     r14d, r8d
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .done
    mov     esi, r13d
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, r14d
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret
