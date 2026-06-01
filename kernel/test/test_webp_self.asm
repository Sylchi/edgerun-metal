; EdgeRun WebP self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/webp_constants.inc"
%include "test/test_macros.inc"

extern er_webp_is
extern er_webp_validate_riff_len
extern er_webp_read_chunk
extern er_webp_parse_vp8x
extern er_webp_parse_vp8l_header
extern er_webp_parse_header
extern er_webp_decode_vp8_key_frame
extern er_webp_apply_alpha_values

TEST_BSS_PASSED_FAILED
hdr:        resb WEBP_HDR_SIZE
chunk:      resb WEBP_CHUNK_DESC_SIZE
yuv:        resb 6
rgba:       resd 4
alpha_rgba: resd 6

SECTION .data
vp8_gray_payload:
    db 0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00
    db 0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00
    db 0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00
vp8_gray_payload_len equ $ - vp8_gray_payload

webp_vp8l:
    db 'R','I','F','F'
    dd webp_vp8l_len - 8
    db 'W','E','B','P'
    db 'V','P','8','L'
    dd 5
    db 0x2f, 0x01, 0x80, 0x00, 0x00
    db 0
webp_vp8l_len equ $ - webp_vp8l

webp_vp8x_vp8:
    db 'R','I','F','F'
    dd webp_vp8x_vp8_len - 8
    db 'W','E','B','P'
    db 'V','P','8','X'
    dd WEBP_VP8X_PAYLOAD_SIZE
    db 0
    db 0, 0, 0
    db 1, 0, 0
    db 1, 0, 0
    db 'V','P','8',' '
    dd vp8_gray_payload_len
    db 0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00
    db 0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00
    db 0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00
webp_vp8x_vp8_len equ $ - webp_vp8x_vp8

webp_alpha_vp8:
    db 'R','I','F','F'
    dd webp_alpha_vp8_len - 8
    db 'W','E','B','P'
    db 'V','P','8','X'
    dd WEBP_VP8X_PAYLOAD_SIZE
    db WEBP_VP8X_FLAG_ALPHA
    db 0, 0, 0
    db 1, 0, 0
    db 1, 0, 0
    db 'A','L','P','H'
    dd 1
    db 0
    db 0
    db 'V','P','8',' '
    dd vp8_gray_payload_len
    db 0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00
    db 0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00
    db 0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00
webp_alpha_vp8_len equ $ - webp_alpha_vp8

webp_alpha_raw_vp8:
    db 'R','I','F','F'
    dd webp_alpha_raw_vp8_len - 8
    db 'W','E','B','P'
    db 'V','P','8','X'
    dd WEBP_VP8X_PAYLOAD_SIZE
    db WEBP_VP8X_FLAG_ALPHA
    db 0, 0, 0
    db 1, 0, 0
    db 1, 0, 0
    db 'A','L','P','H'
    dd 5
    db WEBP_ALPH_COMPRESSION_NONE
    db 0, 64, 128, 255
    db 0
    db 'V','P','8',' '
    dd vp8_gray_payload_len
    db 0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00
    db 0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00
    db 0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00
webp_alpha_raw_vp8_len equ $ - webp_alpha_raw_vp8

webp_bad_riff_len:
    db 'R','I','F','F'
    dd 5
    db 'W','E','B','P'

webp_anim:
    db 'R','I','F','F'
    dd webp_anim_len - 8
    db 'W','E','B','P'
    db 'A','N','I','M'
    dd 6
    times 6 db 0
webp_anim_len equ $ - webp_anim

webp_dup_primary:
    db 'R','I','F','F'
    dd webp_dup_primary_len - 8
    db 'W','E','B','P'
    db 'V','P','8','L'
    dd 5
    db 0x2f, 0x00, 0x00, 0x00, 0x00
    db 0
    db 'V','P','8','L'
    dd 5
    db 0x2f, 0x00, 0x00, 0x00, 0x00
    db 0
webp_dup_primary_len equ $ - webp_dup_primary

vp8x_payload:
    db WEBP_VP8X_FLAG_ALPHA
    db 0, 0, 0
    db 1, 0, 0
    db 2, 0, 0

vp8l_header:
    db 0x2f, 0x01, 0x80, 0x00, 0x00

alpha_raw_payload:
    db WEBP_ALPH_COMPRESSION_NONE
    db 0, 64, 128, 255

alpha_horizontal_payload:
    db WEBP_ALPH_FILTER_HORIZONTAL << WEBP_ALPH_FILTER_SHIFT
    db 10, 10, 10, 30, 10, 10

alpha_gradient_payload:
    db WEBP_ALPH_FILTER_GRADIENT << WEBP_ALPH_FILTER_SHIFT
    db 10, 10, 10, 10, 10, 10

alpha_compressed_payload:
    db WEBP_ALPH_COMPRESSION_VP8L
    db 0, 0, 0, 0

SECTION .text
global _start
_start:
    mov     rdi, webp_vp8l
    mov     esi, webp_vp8l_len
    call    er_webp_is
    cmp     eax, 1
    jne     .fail_is
    test    edx, edx
    jnz     .fail_is
    inc     qword [rel passed]
    jmp     .bad_riff
.fail_is:
    inc     qword [rel failed]

.bad_riff:
    mov     rdi, webp_bad_riff_len
    mov     esi, WEBP_RIFF_HEADER_SIZE
    call    er_webp_validate_riff_len
    test    eax, eax
    jnz     .fail_bad_riff
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_riff
    inc     qword [rel passed]
    jmp     .read_chunk
.fail_bad_riff:
    inc     qword [rel failed]

.read_chunk:
    mov     rdi, webp_vp8l
    mov     esi, webp_vp8l_len
    mov     edx, WEBP_RIFF_HEADER_SIZE
    mov     rcx, chunk
    call    er_webp_read_chunk
    cmp     eax, webp_vp8l_len
    jne     .fail_read_chunk
    test    edx, edx
    jnz     .fail_read_chunk
    cmp     dword [rel chunk + WEBP_CHUNK_DESC_TYPE], WEBP_CHUNK_VP8L
    jne     .fail_read_chunk
    cmp     dword [rel chunk + WEBP_CHUNK_DESC_DATA_OFFSET], WEBP_RIFF_HEADER_SIZE + WEBP_CHUNK_HEADER_SIZE
    jne     .fail_read_chunk
    cmp     dword [rel chunk + WEBP_CHUNK_DESC_DATA_LEN], 5
    jne     .fail_read_chunk
    inc     qword [rel passed]
    jmp     .parse_vp8x
.fail_read_chunk:
    inc     qword [rel failed]

.parse_vp8x:
    mov     rdi, vp8x_payload
    mov     esi, WEBP_VP8X_PAYLOAD_SIZE
    mov     rdx, hdr
    call    er_webp_parse_vp8x
    cmp     eax, WEBP_HDR_SIZE
    jne     .fail_parse_vp8x
    test    edx, edx
    jnz     .fail_parse_vp8x
    cmp     dword [rel hdr + WEBP_HDR_WIDTH], 2
    jne     .fail_parse_vp8x
    cmp     dword [rel hdr + WEBP_HDR_HEIGHT], 3
    jne     .fail_parse_vp8x
    cmp     byte [rel hdr + WEBP_HDR_FLAGS], WEBP_VP8X_FLAG_ALPHA
    jne     .fail_parse_vp8x
    inc     qword [rel passed]
    jmp     .parse_vp8l_header
.fail_parse_vp8x:
    inc     qword [rel failed]

.parse_vp8l_header:
    mov     rdi, vp8l_header
    mov     esi, WEBP_VP8L_HEADER_SIZE
    mov     rdx, hdr
    call    er_webp_parse_vp8l_header
    cmp     eax, WEBP_HDR_SIZE
    jne     .fail_parse_vp8l_header
    test    edx, edx
    jnz     .fail_parse_vp8l_header
    cmp     dword [rel hdr + WEBP_HDR_WIDTH], 2
    jne     .fail_parse_vp8l_header
    cmp     dword [rel hdr + WEBP_HDR_HEIGHT], 3
    jne     .fail_parse_vp8l_header
    inc     qword [rel passed]
    jmp     .parse_vp8l_webp
.fail_parse_vp8l_header:
    inc     qword [rel failed]

.parse_vp8l_webp:
    mov     rdi, webp_vp8l
    mov     esi, webp_vp8l_len
    mov     rdx, hdr
    call    er_webp_parse_header
    cmp     eax, WEBP_HDR_SIZE
    jne     .fail_parse_vp8l_webp
    test    edx, edx
    jnz     .fail_parse_vp8l_webp
    cmp     dword [rel hdr + WEBP_HDR_WIDTH], 2
    jne     .fail_parse_vp8l_webp
    cmp     dword [rel hdr + WEBP_HDR_HEIGHT], 3
    jne     .fail_parse_vp8l_webp
    cmp     dword [rel hdr + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8L
    jne     .fail_parse_vp8l_webp
    inc     qword [rel passed]
    jmp     .parse_vp8_webp
.fail_parse_vp8l_webp:
    inc     qword [rel failed]

.parse_vp8_webp:
    mov     rdi, webp_vp8x_vp8
    mov     esi, webp_vp8x_vp8_len
    mov     rdx, hdr
    call    er_webp_parse_header
    cmp     eax, WEBP_HDR_SIZE
    jne     .fail_parse_vp8_webp
    test    edx, edx
    jnz     .fail_parse_vp8_webp
    cmp     dword [rel hdr + WEBP_HDR_WIDTH], 2
    jne     .fail_parse_vp8_webp
    cmp     dword [rel hdr + WEBP_HDR_HEIGHT], 2
    jne     .fail_parse_vp8_webp
    cmp     dword [rel hdr + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8
    jne     .fail_parse_vp8_webp
    inc     qword [rel passed]
    jmp     .decode_vp8_webp
.fail_parse_vp8_webp:
    inc     qword [rel failed]

.decode_vp8_webp:
    mov     rdi, webp_vp8x_vp8
    mov     esi, webp_vp8x_vp8_len
    mov     rdx, yuv
    mov     ecx, 6
    mov     r8, rgba
    mov     r9d, 4
    call    er_webp_decode_vp8_key_frame
    cmp     eax, 4
    jne     .fail_decode_vp8_webp
    test    edx, edx
    jnz     .fail_decode_vp8_webp
    cmp     dword [rel rgba], 0xff7e7e7e
    jne     .fail_decode_vp8_webp
    cmp     dword [rel rgba + 12], 0xff7e7e7e
    jne     .fail_decode_vp8_webp
    inc     qword [rel passed]
    jmp     .parse_alpha_webp
.fail_decode_vp8_webp:
    inc     qword [rel failed]

.parse_alpha_webp:
    mov     rdi, webp_alpha_vp8
    mov     esi, webp_alpha_vp8_len
    mov     rdx, hdr
    call    er_webp_parse_header
    cmp     eax, WEBP_HDR_SIZE
    jne     .fail_parse_alpha_webp
    test    edx, edx
    jnz     .fail_parse_alpha_webp
    cmp     dword [rel hdr + WEBP_HDR_ALPHA_LEN], 1
    jne     .fail_parse_alpha_webp
    cmp     byte [rel hdr + WEBP_HDR_FLAGS], WEBP_VP8X_FLAG_ALPHA
    jne     .fail_parse_alpha_webp
    inc     qword [rel passed]
    jmp     .apply_raw_alpha
.fail_parse_alpha_webp:
    inc     qword [rel failed]

.apply_raw_alpha:
    mov     dword [rel alpha_rgba], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 4], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 8], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 12], 0xff7e7e7e
    mov     rdi, alpha_raw_payload
    mov     esi, 5
    mov     edx, 2
    mov     ecx, 2
    mov     r8, alpha_rgba
    mov     r9d, 4
    call    er_webp_apply_alpha_values
    cmp     eax, 4
    jne     .fail_apply_raw_alpha
    test    edx, edx
    jnz     .fail_apply_raw_alpha
    cmp     byte [rel alpha_rgba + 3], 0
    jne     .fail_apply_raw_alpha
    cmp     byte [rel alpha_rgba + 7], 64
    jne     .fail_apply_raw_alpha
    cmp     byte [rel alpha_rgba + 11], 128
    jne     .fail_apply_raw_alpha
    cmp     byte [rel alpha_rgba + 15], 255
    jne     .fail_apply_raw_alpha
    inc     qword [rel passed]
    jmp     .apply_filtered_alpha
.fail_apply_raw_alpha:
    inc     qword [rel failed]

.apply_filtered_alpha:
    mov     dword [rel alpha_rgba], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 4], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 8], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 12], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 16], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 20], 0xff7e7e7e
    mov     rdi, alpha_horizontal_payload
    mov     esi, 7
    mov     edx, 3
    mov     ecx, 2
    mov     r8, alpha_rgba
    mov     r9d, 6
    call    er_webp_apply_alpha_values
    cmp     eax, 6
    jne     .fail_apply_filtered_alpha
    test    edx, edx
    jnz     .fail_apply_filtered_alpha
    cmp     byte [rel alpha_rgba + 3], 10
    jne     .fail_apply_filtered_alpha
    cmp     byte [rel alpha_rgba + 7], 20
    jne     .fail_apply_filtered_alpha
    cmp     byte [rel alpha_rgba + 11], 30
    jne     .fail_apply_filtered_alpha
    cmp     byte [rel alpha_rgba + 15], 40
    jne     .fail_apply_filtered_alpha
    cmp     byte [rel alpha_rgba + 19], 50
    jne     .fail_apply_filtered_alpha
    cmp     byte [rel alpha_rgba + 23], 60
    jne     .fail_apply_filtered_alpha
    inc     qword [rel passed]
    jmp     .apply_gradient_alpha
.fail_apply_filtered_alpha:
    inc     qword [rel failed]

.apply_gradient_alpha:
    mov     dword [rel alpha_rgba], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 4], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 8], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 12], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 16], 0xff7e7e7e
    mov     dword [rel alpha_rgba + 20], 0xff7e7e7e
    mov     rdi, alpha_gradient_payload
    mov     esi, 7
    mov     edx, 3
    mov     ecx, 2
    mov     r8, alpha_rgba
    mov     r9d, 6
    call    er_webp_apply_alpha_values
    cmp     eax, 6
    jne     .fail_apply_gradient_alpha
    test    edx, edx
    jnz     .fail_apply_gradient_alpha
    cmp     byte [rel alpha_rgba + 3], 10
    jne     .fail_apply_gradient_alpha
    cmp     byte [rel alpha_rgba + 7], 20
    jne     .fail_apply_gradient_alpha
    cmp     byte [rel alpha_rgba + 11], 30
    jne     .fail_apply_gradient_alpha
    cmp     byte [rel alpha_rgba + 15], 20
    jne     .fail_apply_gradient_alpha
    cmp     byte [rel alpha_rgba + 19], 40
    jne     .fail_apply_gradient_alpha
    cmp     byte [rel alpha_rgba + 23], 60
    jne     .fail_apply_gradient_alpha
    inc     qword [rel passed]
    jmp     .decode_alpha_webp
.fail_apply_gradient_alpha:
    inc     qword [rel failed]

.decode_alpha_webp:
    mov     rdi, webp_alpha_raw_vp8
    mov     esi, webp_alpha_raw_vp8_len
    mov     rdx, yuv
    mov     ecx, 6
    mov     r8, rgba
    mov     r9d, 4
    call    er_webp_decode_vp8_key_frame
    cmp     eax, 4
    jne     .fail_decode_alpha_webp
    test    edx, edx
    jnz     .fail_decode_alpha_webp
    cmp     byte [rel rgba + 3], 0
    jne     .fail_decode_alpha_webp
    cmp     byte [rel rgba + 7], 64
    jne     .fail_decode_alpha_webp
    cmp     byte [rel rgba + 11], 128
    jne     .fail_decode_alpha_webp
    cmp     byte [rel rgba + 15], 255
    jne     .fail_decode_alpha_webp
    inc     qword [rel passed]
    jmp     .reject_compressed_alpha
.fail_decode_alpha_webp:
    inc     qword [rel failed]

.reject_compressed_alpha:
    mov     rdi, alpha_compressed_payload
    mov     esi, 5
    mov     edx, 2
    mov     ecx, 2
    mov     r8, alpha_rgba
    mov     r9d, 4
    call    er_webp_apply_alpha_values
    test    eax, eax
    jnz     .fail_reject_compressed_alpha
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_reject_compressed_alpha
    inc     qword [rel passed]
    jmp     .reject_anim
.fail_reject_compressed_alpha:
    inc     qword [rel failed]

.reject_anim:
    mov     rdi, webp_anim
    mov     esi, webp_anim_len
    mov     rdx, hdr
    call    er_webp_parse_header
    test    eax, eax
    jnz     .fail_reject_anim
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_reject_anim
    inc     qword [rel passed]
    jmp     .reject_dup
.fail_reject_anim:
    inc     qword [rel failed]

.reject_dup:
    mov     rdi, webp_dup_primary
    mov     esi, webp_dup_primary_len
    mov     rdx, hdr
    call    er_webp_parse_header
    test    eax, eax
    jnz     .fail_reject_dup
    cmp     edx, ERROR_CORRUPT
    jne     .fail_reject_dup
    inc     qword [rel passed]
    jmp     .done
.fail_reject_dup:
    inc     qword [rel failed]

.done:
    TEST_EXIT_FAILED
