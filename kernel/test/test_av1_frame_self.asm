; EdgeRun AV1 reduced-still frame header self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_sequence_encode_reduced_still
extern er_av1_sequence_decode_reduced_still
extern er_av1_frame_decode_reduced_still
extern er_av1_frame_encode_reduced_still

SECTION .bss
passed: resq 1
failed: resq 1
seq:    resb AV1_SEQ_SIZE
frame:  resb AV1_FRAME_SIZE
seqbuf: resb 16
outbuf: resb 16

SECTION .text
global _start
_start:
    mov     rdi, seqbuf
    mov     esi, 16
    mov     edx, 64
    mov     ecx, 32
    call    er_av1_sequence_encode_reduced_still
    test    edx, edx
    jnz     .fail_seq
    mov     rdi, seqbuf
    mov     esi, eax
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .fail_seq
    inc     qword [rel passed]
    jmp     .encode_frame
.fail_seq:
    inc     qword [rel failed]

.encode_frame:
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, seq
    mov     ecx, 64
    mov     r8d, 32
    call    er_av1_frame_encode_reduced_still
    test    edx, edx
    jnz     .fail_encode_frame
    test    eax, eax
    jz      .fail_encode_frame
    inc     qword [rel passed]
    jmp     .decode_frame
.fail_encode_frame:
    inc     qword [rel failed]

.decode_frame:
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode_reduced_still
    test    eax, eax
    jz      .fail_decode_frame
    test    edx, edx
    jnz     .fail_decode_frame
    cmp     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    jne     .fail_decode_frame
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 64
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 32
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 64
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 32
    jne     .fail_decode_frame
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    jne     .fail_decode_frame
    inc     qword [rel passed]
    jmp     .short_frame
.fail_decode_frame:
    inc     qword [rel failed]

.short_frame:
    mov     rdi, outbuf
    mov     esi, 1
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode_reduced_still
    test    eax, eax
    jnz     .fail_short_frame
    cmp     edx, ERROR_NO_DATA
    jne     .fail_short_frame
    inc     qword [rel passed]
    jmp     .invalid_seq
.fail_short_frame:
    inc     qword [rel failed]

.invalid_seq:
    mov     byte [rel seq + AV1_SEQ_REDUCED_STILL], 0
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode_reduced_still
    test    eax, eax
    jnz     .fail_invalid_seq
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_invalid_seq
    inc     qword [rel passed]
    jmp     .done
.fail_invalid_seq:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
