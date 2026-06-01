; EdgeRun AV1 sequence header decoder/encoder — x86_64 assembly.
; Implements the profile-0 reduced-still-picture sequence header path.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written

%macro call_read_bit 0
    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
%endmacro

%macro write_bits 2
    mov     rdi, rsp
    mov     esi, %1
    mov     edx, %2
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
%endmacro

SECTION .text

; er_av1_sequence_decode_reduced_still(payload, len, seq_desc)
; rdi=payload, esi=len, rdx=seq_desc. Returns eax=bits_consumed.
er_fn er_av1_sequence_decode_reduced_still
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdx
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .done

    mov     rdi, rsp
    mov     esi, 3
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_SEQ_PROFILE_MAIN
    jne     .unsupported
    mov     [r12 + AV1_SEQ_PROFILE], al

    call_read_bit
    cmp     eax, 1
    jne     .unsupported
    mov     [r12 + AV1_SEQ_STILL_PICTURE], al

    call_read_bit
    cmp     eax, 1
    jne     .unsupported
    mov     [r12 + AV1_SEQ_REDUCED_STILL], al

    mov     rdi, rsp
    mov     esi, 5
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_LEVEL_IDX], al

    mov     rdi, rsp
    mov     esi, 4
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_WIDTH_BITS], al
    mov     r14d, eax

    mov     rdi, rsp
    mov     esi, 4
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_HEIGHT_BITS], al
    mov     r15d, eax

    mov     rdi, rsp
    mov     esi, r14d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_MAX_WIDTH], eax

    mov     rdi, rsp
    mov     esi, r15d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_MAX_HEIGHT], eax

    call_read_bit
    test    eax, eax
    jnz     .unsupported
    mov     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8

    call_read_bit
    test    eax, eax
    jnz     .unsupported
    mov     [r12 + AV1_SEQ_MONO_CHROME], al

    call_read_bit
    test    eax, eax
    jnz     .unsupported

    call_read_bit
    mov     [r12 + AV1_SEQ_COLOR_RANGE], al

    mov     byte [r12 + AV1_SEQ_SUBSAMPLING_X], 1
    mov     byte [r12 + AV1_SEQ_SUBSAMPLING_Y], 1

    mov     rdi, rsp
    mov     esi, 2
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_CHROMA_SAMPLE_POSITION], al

    call_read_bit
    mov     [r12 + AV1_SEQ_FILM_GRAIN], al
    mov     eax, [rsp + AV1_BITS_POS]
    er_ok
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_sequence_encode_reduced_still(out, cap, width, height)
; rdi=out, esi=cap, edx=width, ecx=height. Returns eax=bytes_written.
er_fn er_av1_sequence_encode_reduced_still
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    edx, edx
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    cmp     edx, 65536
    ja      .invalid_param
    cmp     ecx, 65536
    ja      .invalid_param
    mov     r12d, edx
    mov     r13d, ecx
    mov     r14d, edx
    dec     r14d
    mov     r15d, ecx
    dec     r15d

    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .done

    write_bits AV1_SEQ_PROFILE_MAIN, 3
    write_bits 1, 1
    write_bits 1, 1
    write_bits AV1_SEQ_LEVEL_2_0, 5
    write_bits 15, 4
    write_bits 15, 4

    mov     rdi, rsp
    mov     esi, r14d
    mov     edx, 16
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    mov     esi, r15d
    mov     edx, 16
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

    write_bits 0, 1
    write_bits 0, 1
    write_bits 0, 1
    write_bits 0, 1
    write_bits AV1_CHROMA_SAMPLE_POSITION_UNKNOWN, 2
    write_bits 0, 1

    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret
