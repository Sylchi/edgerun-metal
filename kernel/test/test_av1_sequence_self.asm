; EdgeRun AV1 sequence header self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written
extern er_av1_sequence_decode_reduced_still
extern er_av1_sequence_encode_reduced_still

SECTION .bss
passed: resq 1
failed: resq 1
bitctx: resb AV1_BITS_SIZE
seq:    resb AV1_SEQ_SIZE
outbuf: resb 16

SECTION .data
bit_src:     db 0xb1
bad_profile: db 0x20
short_seq:   db 0x18

SECTION .text
global _start
_start:
    mov     rdi, bitctx
    mov     rsi, bit_src
    mov     edx, 1
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .fail_bit_read
    mov     rdi, bitctx
    mov     esi, 3
    call    er_av1_bits_read
    cmp     eax, 5
    jne     .fail_bit_read
    test    edx, edx
    jnz     .fail_bit_read
    mov     rdi, bitctx
    mov     esi, 5
    call    er_av1_bits_read
    cmp     eax, 17
    jne     .fail_bit_read
    test    edx, edx
    jnz     .fail_bit_read
    inc     qword [rel passed]
    jmp     .bit_write
.fail_bit_read:
    inc     qword [rel failed]

.bit_write:
    mov     byte [rel outbuf], 0
    mov     rdi, bitctx
    mov     rsi, outbuf
    mov     edx, 1
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .fail_bit_write
    mov     rdi, bitctx
    mov     esi, 5
    mov     edx, 3
    call    er_av1_bits_write
    test    edx, edx
    jnz     .fail_bit_write
    mov     rdi, bitctx
    mov     esi, 17
    mov     edx, 5
    call    er_av1_bits_write
    test    edx, edx
    jnz     .fail_bit_write
    cmp     byte [rel outbuf], 0xb1
    jne     .fail_bit_write
    mov     rdi, bitctx
    call    er_av1_bits_bytes_written
    cmp     eax, 1
    jne     .fail_bit_write
    test    edx, edx
    jnz     .fail_bit_write
    inc     qword [rel passed]
    jmp     .sequence_encode
.fail_bit_write:
    inc     qword [rel failed]

.sequence_encode:
    mov     rdi, outbuf
    mov     esi, 16
    mov     edx, 64
    mov     ecx, 32
    call    er_av1_sequence_encode_reduced_still
    cmp     eax, 8
    jne     .fail_sequence_encode
    test    edx, edx
    jnz     .fail_sequence_encode
    inc     qword [rel passed]
    jmp     .sequence_decode
.fail_sequence_encode:
    inc     qword [rel failed]

.sequence_decode:
    mov     rdi, outbuf
    mov     esi, 8
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    eax, eax
    jz      .fail_sequence_decode
    test    edx, edx
    jnz     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_PROFILE], AV1_SEQ_PROFILE_MAIN
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_STILL_PICTURE], 1
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_REDUCED_STILL], 1
    jne     .fail_sequence_decode
    cmp     dword [rel seq + AV1_SEQ_MAX_WIDTH], 64
    jne     .fail_sequence_decode
    cmp     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 32
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_SUBSAMPLING_X], 1
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_SUBSAMPLING_Y], 1
    jne     .fail_sequence_decode
    inc     qword [rel passed]
    jmp     .sequence_bad_profile
.fail_sequence_decode:
    inc     qword [rel failed]

.sequence_bad_profile:
    mov     rdi, bad_profile
    mov     esi, 1
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    eax, eax
    jnz     .fail_sequence_bad_profile
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_sequence_bad_profile
    inc     qword [rel passed]
    jmp     .sequence_short
.fail_sequence_bad_profile:
    inc     qword [rel failed]

.sequence_short:
    mov     rdi, short_seq
    mov     esi, 1
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    eax, eax
    jnz     .fail_sequence_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_sequence_short
    inc     qword [rel passed]
    jmp     .sequence_encode_invalid
.fail_sequence_short:
    inc     qword [rel failed]

.sequence_encode_invalid:
    mov     rdi, outbuf
    mov     esi, 16
    xor     edx, edx
    mov     ecx, 32
    call    er_av1_sequence_encode_reduced_still
    test    eax, eax
    jnz     .fail_sequence_encode_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_sequence_encode_invalid
    inc     qword [rel passed]
    jmp     .done
.fail_sequence_encode_invalid:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
