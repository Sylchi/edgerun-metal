; EdgeRun AV1 IVF self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_ivf_is
extern er_av1_ivf_decode_header
extern er_av1_ivf_read_frame
extern er_av1_ivf_count_frames
extern er_av1_ivf_validate_frame_count
extern er_av1_ivf_validate_timestamps
extern er_av1_ivf_seek_frame
extern er_av1_ivf_encode_header
extern er_av1_ivf_write_frame

SECTION .bss
passed:     resq 1
failed:     resq 1
ivf_desc:   resb AV1_IVF_HDR_SIZE
frame_desc: resb AV1_IVF_FRAME_SIZE
out_buf:    resb 64

SECTION .data
ivf_av1:
    db 'D','K','I','F'
    dw 0
    dw AV1_IVF_HEADER_SIZE
    db 'A','V','0','1'
    dw 64
    dw 32
    dd 30
    dd 1
    dd 2
    dd 0
    db 2, 0, 0, 0
    dq 5
    db 0x0a, 0x00
    db 3, 0, 0, 0
    dq 6
    db 0x0a, 0x01, 0xaa
ivf_av1_len equ $ - ivf_av1

ivf_bad_timestamp:
    db 'D','K','I','F'
    dw 0
    dw AV1_IVF_HEADER_SIZE
    db 'A','V','0','1'
    dw 64
    dw 32
    dd 30
    dd 1
    dd 2
    dd 0
    db 1, 0, 0, 0
    dq 6
    db 0x0a
    db 1, 0, 0, 0
    dq 5
    db 0x0b
ivf_bad_timestamp_len equ $ - ivf_bad_timestamp

ivf_bad_sig:
    db 'N','O','P','E'
    times AV1_IVF_HEADER_SIZE - 4 db 0

ivf_vp8:
    db 'D','K','I','F'
    dw 0
    dw AV1_IVF_HEADER_SIZE
    db 'V','P','8','0'
    times AV1_IVF_HEADER_SIZE - 12 db 0

ivf_zero_width:
    db 'D','K','I','F'
    dw 0
    dw AV1_IVF_HEADER_SIZE
    db 'A','V','0','1'
    dw 0
    dw 32
    times AV1_IVF_HEADER_SIZE - 16 db 0

ivf_trunc_frame:
    db 'D','K','I','F'
    dw 0
    dw AV1_IVF_HEADER_SIZE
    db 'A','V','0','1'
    dw 64
    dw 32
    dd 30
    dd 1
    dd 1
    dd 0
    db 4, 0, 0, 0
    dq 7
    db 0xaa
ivf_trunc_frame_len equ $ - ivf_trunc_frame

ivf_empty:
    db 'D','K','I','F'
    dw 0
    dw AV1_IVF_HEADER_SIZE
    db 'A','V','0','1'
    dw 64
    dw 32
    dd 30
    dd 1
    dd 0
    dd 0

frame_payload:
    db 0x0a, 0x01, 0xaa

SECTION .text
global _start
_start:
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    call    er_av1_ivf_is
    cmp     eax, 1
    jne     .fail_is
    test    edx, edx
    jnz     .fail_is
    inc     qword [rel passed]
    jmp     .is_no
.fail_is:
    inc     qword [rel failed]

.is_no:
    mov     rdi, ivf_bad_sig
    mov     esi, AV1_IVF_HEADER_SIZE
    call    er_av1_ivf_is
    test    eax, eax
    jnz     .fail_is_no
    test    edx, edx
    jnz     .fail_is_no
    inc     qword [rel passed]
    jmp     .decode_header
.fail_is_no:
    inc     qword [rel failed]

.decode_header:
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    mov     rdx, ivf_desc
    call    er_av1_ivf_decode_header
    cmp     eax, AV1_IVF_HEADER_SIZE
    jne     .fail_decode_header
    test    edx, edx
    jnz     .fail_decode_header
    cmp     dword [rel ivf_desc + AV1_IVF_HDR_CODEC], AV1_IVF_CODEC_AV01
    jne     .fail_decode_header
    cmp     word [rel ivf_desc + AV1_IVF_HDR_WIDTH], 64
    jne     .fail_decode_header
    cmp     word [rel ivf_desc + AV1_IVF_HDR_HEIGHT], 32
    jne     .fail_decode_header
    cmp     dword [rel ivf_desc + AV1_IVF_HDR_TIMEBASE_DEN], 30
    jne     .fail_decode_header
    cmp     dword [rel ivf_desc + AV1_IVF_HDR_TIMEBASE_NUM], 1
    jne     .fail_decode_header
    cmp     dword [rel ivf_desc + AV1_IVF_HDR_FRAME_COUNT], 2
    jne     .fail_decode_header
    inc     qword [rel passed]
    jmp     .decode_short
.fail_decode_header:
    inc     qword [rel failed]

.decode_short:
    mov     rdi, ivf_av1
    mov     esi, AV1_IVF_HEADER_SIZE - 1
    mov     rdx, ivf_desc
    call    er_av1_ivf_decode_header
    test    eax, eax
    jnz     .fail_decode_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_decode_short
    inc     qword [rel passed]
    jmp     .decode_vp8
.fail_decode_short:
    inc     qword [rel failed]

.decode_vp8:
    mov     rdi, ivf_vp8
    mov     esi, AV1_IVF_HEADER_SIZE
    mov     rdx, ivf_desc
    call    er_av1_ivf_decode_header
    test    eax, eax
    jnz     .fail_decode_vp8
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_decode_vp8
    inc     qword [rel passed]
    jmp     .decode_zero_width
.fail_decode_vp8:
    inc     qword [rel failed]

.decode_zero_width:
    mov     rdi, ivf_zero_width
    mov     esi, AV1_IVF_HEADER_SIZE
    mov     rdx, ivf_desc
    call    er_av1_ivf_decode_header
    test    eax, eax
    jnz     .fail_decode_zero_width
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_zero_width
    inc     qword [rel passed]
    jmp     .frame_one
.fail_decode_zero_width:
    inc     qword [rel failed]

.frame_one:
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    mov     edx, AV1_IVF_HEADER_SIZE
    mov     rcx, frame_desc
    call    er_av1_ivf_read_frame
    cmp     eax, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE + 2
    jne     .fail_frame_one
    test    edx, edx
    jnz     .fail_frame_one
    cmp     dword [rel frame_desc + AV1_IVF_FRAME_PAYLOAD_OFFSET], AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    jne     .fail_frame_one
    cmp     dword [rel frame_desc + AV1_IVF_FRAME_PAYLOAD_LEN], 2
    jne     .fail_frame_one
    cmp     qword [rel frame_desc + AV1_IVF_FRAME_TIMESTAMP], 5
    jne     .fail_frame_one
    inc     qword [rel passed]
    jmp     .frame_two
.fail_frame_one:
    inc     qword [rel failed]

.frame_two:
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    mov     edx, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE + 2
    mov     rcx, frame_desc
    call    er_av1_ivf_read_frame
    cmp     eax, ivf_av1_len
    jne     .fail_frame_two
    test    edx, edx
    jnz     .fail_frame_two
    cmp     dword [rel frame_desc + AV1_IVF_FRAME_PAYLOAD_LEN], 3
    jne     .fail_frame_two
    cmp     qword [rel frame_desc + AV1_IVF_FRAME_TIMESTAMP], 6
    jne     .fail_frame_two
    inc     qword [rel passed]
    jmp     .count_frames
.fail_frame_two:
    inc     qword [rel failed]

.count_frames:
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    call    er_av1_ivf_count_frames
    cmp     eax, 2
    jne     .fail_count_frames
    test    edx, edx
    jnz     .fail_count_frames
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    call    er_av1_ivf_validate_frame_count
    cmp     eax, 2
    jne     .fail_count_frames
    test    edx, edx
    jnz     .fail_count_frames
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    call    er_av1_ivf_validate_timestamps
    cmp     eax, 2
    jne     .fail_count_frames
    test    edx, edx
    jnz     .fail_count_frames
    mov     rdi, ivf_empty
    mov     esi, AV1_IVF_HEADER_SIZE
    call    er_av1_ivf_count_frames
    test    eax, eax
    jnz     .fail_count_frames
    test    edx, edx
    jnz     .fail_count_frames
    inc     qword [rel passed]
    jmp     .timestamp_mismatch
.fail_count_frames:
    inc     qword [rel failed]

.timestamp_mismatch:
    mov     rdi, ivf_bad_timestamp
    mov     esi, ivf_bad_timestamp_len
    call    er_av1_ivf_validate_timestamps
    test    eax, eax
    jnz     .fail_timestamp_mismatch
    cmp     edx, ERROR_CORRUPT
    jne     .fail_timestamp_mismatch
    inc     qword [rel passed]
    jmp     .seek_frame
.fail_timestamp_mismatch:
    inc     qword [rel failed]

.seek_frame:
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    mov     edx, 1
    mov     rcx, frame_desc
    call    er_av1_ivf_seek_frame
    cmp     eax, ivf_av1_len
    jne     .fail_seek_frame
    test    edx, edx
    jnz     .fail_seek_frame
    cmp     dword [rel frame_desc + AV1_IVF_FRAME_PAYLOAD_LEN], 3
    jne     .fail_seek_frame
    cmp     qword [rel frame_desc + AV1_IVF_FRAME_TIMESTAMP], 6
    jne     .fail_seek_frame
    mov     rdi, ivf_av1
    mov     esi, ivf_av1_len
    mov     edx, 2
    mov     rcx, frame_desc
    call    er_av1_ivf_seek_frame
    test    eax, eax
    jnz     .fail_seek_frame
    cmp     edx, ERROR_NOT_FOUND
    jne     .fail_seek_frame
    mov     rdi, ivf_trunc_frame
    mov     esi, ivf_trunc_frame_len
    xor     edx, edx
    mov     rcx, frame_desc
    call    er_av1_ivf_seek_frame
    test    eax, eax
    jnz     .fail_seek_frame
    cmp     edx, ERROR_NO_DATA
    jne     .fail_seek_frame
    inc     qword [rel passed]
    jmp     .count_mismatch
.fail_seek_frame:
    inc     qword [rel failed]

.count_mismatch:
    mov     dword [rel out_buf], AV1_IVF_SIGNATURE
    mov     word [rel out_buf + AV1_IVF_FILE_VERSION], 0
    mov     word [rel out_buf + AV1_IVF_FILE_HEADER_LEN], AV1_IVF_HEADER_SIZE
    mov     dword [rel out_buf + AV1_IVF_FILE_CODEC], AV1_IVF_CODEC_AV01
    mov     word [rel out_buf + AV1_IVF_FILE_WIDTH], 64
    mov     word [rel out_buf + AV1_IVF_FILE_HEIGHT], 32
    mov     dword [rel out_buf + AV1_IVF_FILE_TIMEBASE_DEN], 30
    mov     dword [rel out_buf + AV1_IVF_FILE_TIMEBASE_NUM], 1
    mov     dword [rel out_buf + AV1_IVF_FILE_FRAME_COUNT], 1
    mov     dword [rel out_buf + AV1_IVF_FILE_RESERVED], 0
    mov     rdi, out_buf
    mov     esi, AV1_IVF_HEADER_SIZE
    call    er_av1_ivf_validate_frame_count
    test    eax, eax
    jnz     .fail_count_mismatch
    cmp     edx, ERROR_CORRUPT
    jne     .fail_count_mismatch
    mov     rdi, ivf_trunc_frame
    mov     esi, ivf_trunc_frame_len
    call    er_av1_ivf_count_frames
    test    eax, eax
    jnz     .fail_count_mismatch
    cmp     edx, ERROR_NO_DATA
    jne     .fail_count_mismatch
    inc     qword [rel passed]
    jmp     .frame_trunc
.fail_count_mismatch:
    inc     qword [rel failed]

.frame_trunc:
    mov     rdi, ivf_trunc_frame
    mov     esi, ivf_trunc_frame_len
    mov     edx, AV1_IVF_HEADER_SIZE
    mov     rcx, frame_desc
    call    er_av1_ivf_read_frame
    test    eax, eax
    jnz     .fail_frame_trunc
    cmp     edx, ERROR_NO_DATA
    jne     .fail_frame_trunc
    inc     qword [rel passed]
    jmp     .encode_header
.fail_frame_trunc:
    inc     qword [rel failed]

.encode_header:
    mov     rdi, out_buf
    mov     esi, 64
    mov     rdx, ivf_desc
    call    er_av1_ivf_encode_header
    cmp     eax, AV1_IVF_HEADER_SIZE
    jne     .fail_encode_header
    test    edx, edx
    jnz     .fail_encode_header
    cmp     dword [rel out_buf], AV1_IVF_SIGNATURE
    jne     .fail_encode_header
    cmp     word [rel out_buf + AV1_IVF_FILE_HEADER_LEN], AV1_IVF_HEADER_SIZE
    jne     .fail_encode_header
    cmp     dword [rel out_buf + AV1_IVF_FILE_CODEC], AV1_IVF_CODEC_AV01
    jne     .fail_encode_header
    cmp     word [rel out_buf + AV1_IVF_FILE_WIDTH], 64
    jne     .fail_encode_header
    cmp     word [rel out_buf + AV1_IVF_FILE_HEIGHT], 32
    jne     .fail_encode_header
    cmp     dword [rel out_buf + AV1_IVF_FILE_TIMEBASE_DEN], 30
    jne     .fail_encode_header
    cmp     dword [rel out_buf + AV1_IVF_FILE_TIMEBASE_NUM], 1
    jne     .fail_encode_header
    cmp     dword [rel out_buf + AV1_IVF_FILE_FRAME_COUNT], 2
    jne     .fail_encode_header
    cmp     dword [rel out_buf + AV1_IVF_FILE_RESERVED], 0
    jne     .fail_encode_header
    inc     qword [rel passed]
    jmp     .encode_header_no_space
.fail_encode_header:
    inc     qword [rel failed]

.encode_header_no_space:
    mov     rdi, out_buf
    mov     esi, AV1_IVF_HEADER_SIZE - 1
    mov     rdx, ivf_desc
    call    er_av1_ivf_encode_header
    test    eax, eax
    jnz     .fail_encode_header_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_encode_header_no_space
    inc     qword [rel passed]
    jmp     .write_frame
.fail_encode_header_no_space:
    inc     qword [rel failed]

.write_frame:
    mov     rdi, out_buf
    mov     esi, 64
    mov     rdx, frame_payload
    mov     ecx, 3
    mov     r8, 9
    call    er_av1_ivf_write_frame
    cmp     eax, AV1_IVF_FRAME_HEADER_SIZE + 3
    jne     .fail_write_frame
    test    edx, edx
    jnz     .fail_write_frame
    cmp     dword [rel out_buf], 3
    jne     .fail_write_frame
    cmp     qword [rel out_buf + AV1_IVF_FRAME_RECORD_TIMESTAMP], 9
    jne     .fail_write_frame
    cmp     byte [rel out_buf + AV1_IVF_FRAME_HEADER_SIZE], 0x0a
    jne     .fail_write_frame
    cmp     byte [rel out_buf + AV1_IVF_FRAME_HEADER_SIZE + 1], 0x01
    jne     .fail_write_frame
    cmp     byte [rel out_buf + AV1_IVF_FRAME_HEADER_SIZE + 2], 0xaa
    jne     .fail_write_frame
    inc     qword [rel passed]
    jmp     .write_frame_no_space
.fail_write_frame:
    inc     qword [rel failed]

.write_frame_no_space:
    mov     rdi, out_buf
    mov     esi, AV1_IVF_FRAME_HEADER_SIZE + 2
    mov     rdx, frame_payload
    mov     ecx, 3
    mov     r8, 9
    call    er_av1_ivf_write_frame
    test    eax, eax
    jnz     .fail_write_frame_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_write_frame_no_space
    inc     qword [rel passed]
    jmp     .done
.fail_write_frame_no_space:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
