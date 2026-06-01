; EdgeRun AV1 reduced-still stream self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_reduced_still_encode
extern er_av1_reduced_still_encode_split
extern er_av1_reduced_still_encode_ivf
extern er_av1_reduced_still_encode_raw420
extern er_av1_reduced_still_encode_raw420_delimited
extern er_av1_reduced_still_encode_ivf_raw420
extern er_av1_reduced_still_begin_ivf_raw420
extern er_av1_reduced_still_append_ivf_raw420
extern er_av1_reduced_still_decode
extern er_av1_reduced_still_decode_auto
extern er_av1_reduced_still_decode_ivf_frame
extern er_av1_reduced_still_decode_ivf_frame_raw420
extern er_av1_reduced_still_decode_raw420
extern er_av1_reduced_still_validate_raw420
extern er_av1_reduced_still_validate_ivf_frame_raw420
extern er_av1_ivf_encode_header
extern er_av1_ivf_write_frame
extern er_av1_tile_raw420_fill_desc

SECTION .bss
passed:  resq 1
failed:  resq 1
raw_len: resd 1
ivf_len: resd 1
desc:    resb AV1_REDUCED_SIZE
image:   resb AV1_IMAGE_SIZE
ivf_desc: resb AV1_IVF_HDR_SIZE
outbuf:  resb 128
ivfbuf:  resb 192
decoded_y: resb 8
decoded_u: resb 2
decoded_v: resb 2

SECTION .data
tile: db 0xaa, 0xbb, 0xcc
plane_y: db 1, 2, 3, 4, 5, 6, 7, 8
plane_u: db 9, 10
plane_v: db 11, 12
plane2_y: db 21, 22, 23, 24, 25, 26, 27, 28
plane2_u: db 29, 30
plane2_v: db 31, 32
bad_stream: db 0x32, 0x01, 0x00 ; OBU_FRAME with one zero payload byte, no sequence first

SECTION .text
global _start
_start:
    mov     rdi, outbuf
    mov     esi, 128
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode
    test    eax, eax
    jz      .fail_encode
    test    edx, edx
    jnz     .fail_encode
    mov     [rel raw_len], eax
    inc     qword [rel passed]
    jmp     .decode
.fail_encode:
    inc     qword [rel failed]

.decode:
    mov     rdi, outbuf
    mov     esi, eax
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jz      .fail_decode
    test    edx, edx
    jnz     .fail_decode
    cmp     byte [rel desc + AV1_REDUCED_SEEN_SEQUENCE], 1
    jne     .fail_decode
    cmp     byte [rel desc + AV1_REDUCED_SEEN_FRAME], 1
    jne     .fail_decode
    cmp     dword [rel desc + AV1_REDUCED_SEQ + AV1_SEQ_MAX_WIDTH], 64
    jne     .fail_decode
    cmp     dword [rel desc + AV1_REDUCED_SEQ + AV1_SEQ_MAX_HEIGHT], 32
    jne     .fail_decode
    cmp     dword [rel desc + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH], 64
    jne     .fail_decode
    cmp     dword [rel desc + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT], 32
    jne     .fail_decode
    cmp     dword [rel desc + AV1_REDUCED_TILE_LEN], 3
    jne     .fail_decode
    mov     eax, [rel desc + AV1_REDUCED_TILE_OFFSET]
    cmp     byte [rel outbuf + rax], 0xaa
    jne     .fail_decode
    cmp     byte [rel outbuf + rax + 1], 0xbb
    jne     .fail_decode
    cmp     byte [rel outbuf + rax + 2], 0xcc
    jne     .fail_decode
    inc     qword [rel passed]
    jmp     .wrap_ivf
.fail_decode:
    inc     qword [rel failed]

.wrap_ivf:
    mov     dword [rel ivf_desc + AV1_IVF_HDR_CODEC], AV1_IVF_CODEC_AV01
    mov     word [rel ivf_desc + AV1_IVF_HDR_WIDTH], 64
    mov     word [rel ivf_desc + AV1_IVF_HDR_HEIGHT], 32
    mov     dword [rel ivf_desc + AV1_IVF_HDR_TIMEBASE_DEN], 30
    mov     dword [rel ivf_desc + AV1_IVF_HDR_TIMEBASE_NUM], 1
    mov     dword [rel ivf_desc + AV1_IVF_HDR_FRAME_COUNT], 1
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     rdx, ivf_desc
    call    er_av1_ivf_encode_header
    cmp     eax, AV1_IVF_HEADER_SIZE
    jne     .fail_wrap_ivf
    test    edx, edx
    jnz     .fail_wrap_ivf
    mov     rdi, ivfbuf + AV1_IVF_HEADER_SIZE
    mov     esi, 192 - AV1_IVF_HEADER_SIZE
    mov     rdx, outbuf
    mov     ecx, [rel raw_len]
    xor     r8d, r8d
    call    er_av1_ivf_write_frame
    test    eax, eax
    jz      .fail_wrap_ivf
    test    edx, edx
    jnz     .fail_wrap_ivf
    mov     rdi, ivfbuf
    mov     esi, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    add     esi, [rel raw_len]
    mov     rdx, desc
    call    er_av1_reduced_still_decode_auto
    mov     ecx, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    add     ecx, [rel raw_len]
    cmp     eax, ecx
    jne     .fail_wrap_ivf
    test    edx, edx
    jnz     .fail_wrap_ivf
    cmp     dword [rel desc + AV1_REDUCED_TILE_LEN], 3
    jne     .fail_wrap_ivf
    mov     eax, [rel desc + AV1_REDUCED_TILE_OFFSET]
    cmp     byte [rel ivfbuf + rax], 0xaa
    jne     .fail_wrap_ivf
    cmp     byte [rel ivfbuf + rax + 1], 0xbb
    jne     .fail_wrap_ivf
    cmp     byte [rel ivfbuf + rax + 2], 0xcc
    jne     .fail_wrap_ivf
    inc     qword [rel passed]
    jmp     .encode_split
.fail_wrap_ivf:
    inc     qword [rel failed]

.encode_split:
    mov     rdi, outbuf
    mov     esi, 128
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_split
    test    eax, eax
    jz      .fail_encode_split
    test    edx, edx
    jnz     .fail_encode_split
    inc     qword [rel passed]
    mov     rdi, outbuf
    mov     esi, eax
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jz      .fail_encode_split
    test    edx, edx
    jnz     .fail_encode_split
    cmp     dword [rel desc + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH], 64
    jne     .fail_encode_split
    cmp     dword [rel desc + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT], 32
    jne     .fail_encode_split
    cmp     dword [rel desc + AV1_REDUCED_TILE_LEN], 3
    jne     .fail_encode_split
    mov     eax, [rel desc + AV1_REDUCED_TILE_OFFSET]
    cmp     byte [rel outbuf + rax], 0xaa
    jne     .fail_encode_split
    cmp     byte [rel outbuf + rax + 1], 0xbb
    jne     .fail_encode_split
    cmp     byte [rel outbuf + rax + 2], 0xcc
    jne     .fail_encode_split
    inc     qword [rel passed]
    jmp     .encode_split_no_space
.fail_encode_split:
    inc     qword [rel failed]

.encode_split_no_space:
    mov     rdi, outbuf
    mov     esi, 2
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_split
    test    eax, eax
    jnz     .fail_encode_split_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_encode_split_no_space
    inc     qword [rel passed]
    jmp     .encode_ivf
.fail_encode_split_no_space:
    inc     qword [rel failed]

.encode_ivf:
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_ivf
    test    eax, eax
    jz      .fail_encode_ivf
    test    edx, edx
    jnz     .fail_encode_ivf
    cmp     dword [rel ivfbuf], AV1_IVF_SIGNATURE
    jne     .fail_encode_ivf
    cmp     dword [rel ivfbuf + 8], AV1_IVF_CODEC_AV01
    jne     .fail_encode_ivf
    cmp     word [rel ivfbuf + AV1_IVF_FILE_WIDTH], 64
    jne     .fail_encode_ivf
    cmp     word [rel ivfbuf + AV1_IVF_FILE_HEIGHT], 32
    jne     .fail_encode_ivf
    cmp     dword [rel ivfbuf + 16], AV1_IVF_DEFAULT_TIMEBASE_DEN
    jne     .fail_encode_ivf
    cmp     dword [rel ivfbuf + 20], AV1_IVF_DEFAULT_TIMEBASE_NUM
    jne     .fail_encode_ivf
    cmp     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], AV1_IVF_SINGLE_FRAME_COUNT
    jne     .fail_encode_ivf
    inc     qword [rel passed]
    mov     rdi, ivfbuf
    mov     esi, eax
    mov     rdx, desc
    call    er_av1_reduced_still_decode_auto
    test    eax, eax
    jz      .fail_encode_ivf
    test    edx, edx
    jnz     .fail_encode_ivf
    cmp     dword [rel desc + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH], 64
    jne     .fail_encode_ivf
    cmp     dword [rel desc + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT], 32
    jne     .fail_encode_ivf
    cmp     dword [rel desc + AV1_REDUCED_TILE_LEN], 3
    jne     .fail_encode_ivf
    mov     eax, [rel desc + AV1_REDUCED_TILE_OFFSET]
    cmp     byte [rel ivfbuf + rax], 0xaa
    jne     .fail_encode_ivf
    cmp     byte [rel ivfbuf + rax + 1], 0xbb
    jne     .fail_encode_ivf
    cmp     byte [rel ivfbuf + rax + 2], 0xcc
    jne     .fail_encode_ivf
    inc     qword [rel passed]
    jmp     .encode_ivf_no_space
.fail_encode_ivf:
    inc     qword [rel failed]

.encode_ivf_no_space:
    mov     rdi, ivfbuf
    mov     esi, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE - 1
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_ivf
    test    eax, eax
    jnz     .fail_encode_ivf_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_encode_ivf_no_space
    inc     qword [rel passed]
    jmp     .encode_ivf_bad_dimension
.fail_encode_ivf_no_space:
    inc     qword [rel failed]

.encode_ivf_bad_dimension:
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, AV1_IVF_DIMENSION_MAX + 1
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_ivf
    test    eax, eax
    jnz     .fail_encode_ivf_bad_dimension
    cmp     edx, ERROR_CORRUPT
    jne     .fail_encode_ivf_bad_dimension
    inc     qword [rel passed]
    jmp     .decode_ivf_dimension_mismatch
.fail_encode_ivf_bad_dimension:
    inc     qword [rel failed]

.decode_ivf_dimension_mismatch:
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_ivf
    test    eax, eax
    jz      .fail_decode_ivf_dimension_mismatch
    test    edx, edx
    jnz     .fail_decode_ivf_dimension_mismatch
    mov     word [rel ivfbuf + AV1_IVF_FILE_WIDTH], 63
    mov     rdi, ivfbuf
    mov     esi, eax
    mov     rdx, desc
    call    er_av1_reduced_still_decode_auto
    test    eax, eax
    jnz     .fail_decode_ivf_dimension_mismatch
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_ivf_dimension_mismatch
    inc     qword [rel passed]
    jmp     .decode_auto_ivf_count_mismatch
.fail_decode_ivf_dimension_mismatch:
    inc     qword [rel failed]

.decode_auto_ivf_count_mismatch:
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode_ivf
    test    eax, eax
    jz      .fail_decode_auto_ivf_count_mismatch
    test    edx, edx
    jnz     .fail_decode_auto_ivf_count_mismatch
    mov     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], 2
    mov     rdi, ivfbuf
    mov     esi, eax
    mov     rdx, desc
    call    er_av1_reduced_still_decode_auto
    test    eax, eax
    jnz     .fail_decode_auto_ivf_count_mismatch
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_auto_ivf_count_mismatch
    inc     qword [rel passed]
    jmp     .decode_auto_ivf_bad_timestamp
.fail_decode_auto_ivf_count_mismatch:
    inc     qword [rel failed]

.decode_auto_ivf_bad_timestamp:
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, 4
    mov     ecx, 2
    mov     r8d, AV1_IVF_DEFAULT_TIMEBASE_DEN
    mov     r9d, AV1_IVF_DEFAULT_TIMEBASE_NUM
    call    er_av1_reduced_still_begin_ivf_raw420
    cmp     eax, AV1_IVF_HEADER_SIZE
    jne     .fail_decode_auto_ivf_bad_timestamp
    test    edx, edx
    jnz     .fail_decode_auto_ivf_bad_timestamp
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane_y
    mov     r8, plane_u
    mov     r9, plane_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_auto_ivf_bad_timestamp
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, AV1_IVF_HEADER_SIZE
    mov     rcx, image
    mov     r8d, 7
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jz      .fail_decode_auto_ivf_bad_timestamp
    test    edx, edx
    jnz     .fail_decode_auto_ivf_bad_timestamp
    mov     [rel ivf_len], eax
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane2_y
    mov     r8, plane2_u
    mov     r9, plane2_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_auto_ivf_bad_timestamp
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, [rel ivf_len]
    mov     rcx, image
    mov     r8d, 8
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jz      .fail_decode_auto_ivf_bad_timestamp
    test    edx, edx
    jnz     .fail_decode_auto_ivf_bad_timestamp
    mov     [rel ivf_len], eax
    mov     qword [rel ivfbuf + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_RECORD_TIMESTAMP], 9
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, desc
    call    er_av1_reduced_still_decode_auto
    test    eax, eax
    jnz     .fail_decode_auto_ivf_bad_timestamp
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_auto_ivf_bad_timestamp
    inc     qword [rel passed]
    jmp     .encode_ivf_raw420
.fail_decode_auto_ivf_bad_timestamp:
    inc     qword [rel failed]

.encode_ivf_raw420:
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane_y
    mov     r8, plane_u
    mov     r9, plane_v
    call    er_av1_tile_raw420_fill_desc
    cmp     eax, 12
    jne     .fail_encode_ivf_raw420
    test    edx, edx
    jnz     .fail_encode_ivf_raw420
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     rdx, image
    call    er_av1_reduced_still_encode_ivf_raw420
    test    eax, eax
    jz      .fail_encode_ivf_raw420
    test    edx, edx
    jnz     .fail_encode_ivf_raw420
    mov     [rel ivf_len], eax
    cmp     dword [rel ivfbuf], AV1_IVF_SIGNATURE
    jne     .fail_encode_ivf_raw420
    cmp     word [rel ivfbuf + AV1_IVF_FILE_WIDTH], 4
    jne     .fail_encode_ivf_raw420
    cmp     word [rel ivfbuf + AV1_IVF_FILE_HEIGHT], 2
    jne     .fail_encode_ivf_raw420
    inc     qword [rel passed]
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, decoded_y
    mov     r8, decoded_u
    mov     r9, decoded_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_encode_ivf_raw420
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, desc
    call    er_av1_reduced_still_validate_raw420
    test    eax, eax
    jz      .fail_encode_ivf_raw420
    test    edx, edx
    jnz     .fail_encode_ivf_raw420
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, image
    mov     rcx, desc
    call    er_av1_reduced_still_decode_raw420
    test    eax, eax
    jz      .fail_encode_ivf_raw420
    test    edx, edx
    jnz     .fail_encode_ivf_raw420
    cmp     byte [rel decoded_y], 1
    jne     .fail_encode_ivf_raw420
    cmp     byte [rel decoded_y + 7], 8
    jne     .fail_encode_ivf_raw420
    cmp     byte [rel decoded_u], 9
    jne     .fail_encode_ivf_raw420
    cmp     byte [rel decoded_u + 1], 10
    jne     .fail_encode_ivf_raw420
    cmp     byte [rel decoded_v], 11
    jne     .fail_encode_ivf_raw420
    cmp     byte [rel decoded_v + 1], 12
    jne     .fail_encode_ivf_raw420
    inc     qword [rel passed]
    jmp     .encode_ivf_raw420_no_space
.fail_encode_ivf_raw420:
    inc     qword [rel failed]

.encode_ivf_raw420_no_space:
    mov     rdi, ivfbuf
    mov     esi, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    mov     rdx, image
    call    er_av1_reduced_still_encode_ivf_raw420
    test    eax, eax
    jnz     .fail_encode_ivf_raw420_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_encode_ivf_raw420_no_space
    inc     qword [rel passed]
    jmp     .encode_raw420
.fail_encode_ivf_raw420_no_space:
    inc     qword [rel failed]

.encode_raw420:
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, image
    call    er_av1_reduced_still_encode_raw420
    test    eax, eax
    jz      .fail_encode_raw420
    test    edx, edx
    jnz     .fail_encode_raw420
    mov     [rel raw_len], eax
    inc     qword [rel passed]
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, decoded_y
    mov     r8, decoded_u
    mov     r9, decoded_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_encode_raw420
    mov     rdi, outbuf
    mov     esi, [rel raw_len]
    mov     rdx, desc
    call    er_av1_reduced_still_validate_raw420
    test    eax, eax
    jz      .fail_encode_raw420
    test    edx, edx
    jnz     .fail_encode_raw420
    mov     rdi, outbuf
    mov     esi, [rel raw_len]
    mov     rdx, image
    mov     rcx, desc
    call    er_av1_reduced_still_decode_raw420
    test    eax, eax
    jz      .fail_encode_raw420
    test    edx, edx
    jnz     .fail_encode_raw420
    cmp     byte [rel decoded_y], 1
    jne     .fail_encode_raw420
    cmp     byte [rel decoded_y + 7], 8
    jne     .fail_encode_raw420
    cmp     byte [rel decoded_u], 9
    jne     .fail_encode_raw420
    cmp     byte [rel decoded_u + 1], 10
    jne     .fail_encode_raw420
    cmp     byte [rel decoded_v], 11
    jne     .fail_encode_raw420
	cmp     byte [rel decoded_v + 1], 12
	jne     .fail_encode_raw420
	inc     qword [rel passed]
	jmp     .encode_raw420_delimited
.fail_encode_raw420:
	inc     qword [rel failed]

.encode_raw420_delimited:
	mov     rdi, outbuf
	mov     esi, 128
	mov     rdx, image
	call    er_av1_reduced_still_encode_raw420_delimited
	test    eax, eax
	jz      .fail_encode_raw420_delimited
	test    edx, edx
	jnz     .fail_encode_raw420_delimited
	mov     [rel raw_len], eax
	cmp     byte [rel outbuf], 0x12
	jne     .fail_encode_raw420_delimited
	cmp     byte [rel outbuf + 1], 0x00
	jne     .fail_encode_raw420_delimited
	mov     rdi, outbuf
	mov     esi, [rel raw_len]
	mov     rdx, desc
	call    er_av1_reduced_still_validate_raw420
	test    eax, eax
	jz      .fail_encode_raw420_delimited
	test    edx, edx
	jnz     .fail_encode_raw420_delimited
	mov     qword [rel decoded_y], 0
	mov     word [rel decoded_u], 0
	mov     word [rel decoded_v], 0
	mov     rdi, image
	mov     esi, 4
	mov     edx, 2
	mov     rcx, decoded_y
	mov     r8, decoded_u
	mov     r9, decoded_v
	call    er_av1_tile_raw420_fill_desc
	test    edx, edx
	jnz     .fail_encode_raw420_delimited
	mov     rdi, outbuf
	mov     esi, [rel raw_len]
	mov     rdx, image
	mov     rcx, desc
	call    er_av1_reduced_still_decode_raw420
	test    eax, eax
	jz      .fail_encode_raw420_delimited
	test    edx, edx
	jnz     .fail_encode_raw420_delimited
	cmp     byte [rel decoded_y], 1
	jne     .fail_encode_raw420_delimited
	cmp     byte [rel decoded_y + 7], 8
	jne     .fail_encode_raw420_delimited
	cmp     byte [rel decoded_u], 9
	jne     .fail_encode_raw420_delimited
	cmp     byte [rel decoded_v + 1], 12
	jne     .fail_encode_raw420_delimited
	inc     qword [rel passed]
	jmp     .decode_raw420_overlong_tile
.fail_encode_raw420_delimited:
	inc     qword [rel failed]

.decode_raw420_overlong_tile:
	mov     rdi, ivfbuf
	mov     esi, 192
    mov     edx, 4
    mov     ecx, 2
    mov     r8, plane_y
    mov     r9d, 13
    call    er_av1_reduced_still_encode
    test    eax, eax
    jz      .fail_decode_raw420_overlong_tile
    test    edx, edx
    jnz     .fail_decode_raw420_overlong_tile
    mov     [rel ivf_len], eax
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, decoded_y
    mov     r8, decoded_u
    mov     r9, decoded_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_raw420_overlong_tile
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, desc
    call    er_av1_reduced_still_validate_raw420
    test    eax, eax
    jnz     .fail_decode_raw420_overlong_tile
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_raw420_overlong_tile
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, image
    mov     rcx, desc
    call    er_av1_reduced_still_decode_raw420
    test    eax, eax
    jnz     .fail_decode_raw420_overlong_tile
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_raw420_overlong_tile
    inc     qword [rel passed]
    jmp     .decode_ivf_frame_index
.fail_decode_raw420_overlong_tile:
    inc     qword [rel failed]

.decode_ivf_frame_index:
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, 4
    mov     ecx, 2
    mov     r8d, AV1_IVF_DEFAULT_TIMEBASE_DEN
    mov     r9d, AV1_IVF_DEFAULT_TIMEBASE_NUM
    call    er_av1_reduced_still_begin_ivf_raw420
    cmp     eax, AV1_IVF_HEADER_SIZE
    jne     .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    cmp     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], 0
    jne     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, AV1_IVF_HEADER_SIZE - 1
    mov     edx, 4
    mov     ecx, 2
    mov     r8d, AV1_IVF_DEFAULT_TIMEBASE_DEN
    mov     r9d, AV1_IVF_DEFAULT_TIMEBASE_NUM
    call    er_av1_reduced_still_begin_ivf_raw420
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, 192
    xor     edx, edx
    mov     ecx, 2
    mov     r8d, AV1_IVF_DEFAULT_TIMEBASE_DEN
    mov     r9d, AV1_IVF_DEFAULT_TIMEBASE_NUM
    call    er_av1_reduced_still_begin_ivf_raw420
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_decode_ivf_frame_index
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane_y
    mov     r8, plane_u
    mov     r9, plane_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, AV1_IVF_HEADER_SIZE
    mov     rcx, image
    xor     r8d, r8d
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jz      .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     [rel ivf_len], eax
    cmp     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], 1
    jne     .fail_decode_ivf_frame_index
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane2_y
    mov     r8, plane2_u
    mov     r9, plane2_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, [rel ivf_len]
    mov     rcx, image
    mov     r8d, 1
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jz      .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     [rel ivf_len], eax
    cmp     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], 2
    jne     .fail_decode_ivf_frame_index
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, decoded_y
    mov     r8, decoded_u
    mov     r9, decoded_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, 1
    mov     rcx, desc
    call    er_av1_reduced_still_decode_ivf_frame
    test    eax, eax
    jz      .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    cmp     dword [rel desc + AV1_REDUCED_TILE_LEN], 12
    jne     .fail_decode_ivf_frame_index
    mov     eax, [rel desc + AV1_REDUCED_TILE_OFFSET]
    cmp     byte [rel ivfbuf + rax], 21
    jne     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, 2
    mov     rcx, desc
    call    er_av1_reduced_still_decode_ivf_frame
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_NOT_FOUND
    jne     .fail_decode_ivf_frame_index
    mov     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], 1
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, 1
    mov     rcx, desc
    call    er_av1_reduced_still_decode_ivf_frame
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_ivf_frame_index
    mov     dword [rel ivfbuf + AV1_IVF_FILE_FRAME_COUNT], 2
    mov     qword [rel ivfbuf + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_RECORD_TIMESTAMP], 9
    mov     eax, [rel ivfbuf + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_RECORD_LEN]
    add     eax, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE + AV1_IVF_FRAME_RECORD_TIMESTAMP
    mov     qword [rel ivfbuf + rax], 8
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, 1
    mov     rcx, desc
    call    er_av1_reduced_still_decode_ivf_frame
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_ivf_frame_index
    mov     qword [rel ivfbuf + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_RECORD_TIMESTAMP], 0
    mov     eax, [rel ivfbuf + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_RECORD_LEN]
    add     eax, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE + AV1_IVF_FRAME_RECORD_TIMESTAMP
    mov     qword [rel ivfbuf + rax], 1
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, 1
    mov     rcx, desc
    call    er_av1_reduced_still_validate_ivf_frame_raw420
    test    eax, eax
    jz      .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, 1
    mov     rcx, image
    mov     r8, desc
    call    er_av1_reduced_still_decode_ivf_frame_raw420
    test    eax, eax
    jz      .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    cmp     byte [rel decoded_y], 21
    jne     .fail_decode_ivf_frame_index
    cmp     byte [rel decoded_y + 7], 28
    jne     .fail_decode_ivf_frame_index
    cmp     byte [rel decoded_u], 29
    jne     .fail_decode_ivf_frame_index
    cmp     byte [rel decoded_u + 1], 30
    jne     .fail_decode_ivf_frame_index
    cmp     byte [rel decoded_v], 31
    jne     .fail_decode_ivf_frame_index
    cmp     byte [rel decoded_v + 1], 32
    jne     .fail_decode_ivf_frame_index
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane2_y
    mov     r8, plane2_u
    mov     r9, plane2_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, [rel ivf_len]
    mov     rcx, image
    mov     r8d, 1
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     edx, [rel ivf_len]
    mov     rcx, image
    mov     r8d, 2
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_decode_ivf_frame_index
    mov     rdi, image
    mov     esi, 2
    mov     edx, 2
    mov     rcx, plane_y
    mov     r8, plane_u
    mov     r9, plane_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     edx, [rel ivf_len]
    mov     rcx, image
    mov     r8d, 2
    call    er_av1_reduced_still_append_ivf_raw420
    test    eax, eax
    jnz     .fail_decode_ivf_frame_index
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_ivf_frame_index
    inc     qword [rel passed]
    jmp     .encode_raw420_no_space
.fail_decode_ivf_frame_index:
    inc     qword [rel failed]

.encode_raw420_no_space:
    mov     rdi, outbuf
    mov     esi, 2
    mov     rdx, image
    call    er_av1_reduced_still_encode_raw420
    test    eax, eax
    jnz     .fail_encode_raw420_no_space
	cmp     edx, ERROR_NO_SPACE
	jne     .fail_encode_raw420_no_space
	inc     qword [rel passed]
	jmp     .encode_raw420_delimited_no_space
.fail_encode_raw420_no_space:
	inc     qword [rel failed]

.encode_raw420_delimited_no_space:
	mov     rdi, outbuf
	mov     esi, 1
	mov     rdx, image
	call    er_av1_reduced_still_encode_raw420_delimited
	test    eax, eax
	jnz     .fail_encode_raw420_delimited_no_space
	cmp     edx, ERROR_NO_SPACE
	jne     .fail_encode_raw420_delimited_no_space
	inc     qword [rel passed]
	jmp     .encode_raw420_bad_desc
.fail_encode_raw420_delimited_no_space:
	inc     qword [rel failed]

.encode_raw420_bad_desc:
	mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane_y
    mov     r8, plane_u
    mov     r9, plane_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_encode_raw420_bad_desc
    mov     dword [rel image + AV1_IMAGE_U_LEN], 1
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, image
    call    er_av1_reduced_still_encode_raw420
    test    eax, eax
    jnz     .fail_encode_raw420_bad_desc
    cmp     edx, ERROR_CORRUPT
    jne     .fail_encode_raw420_bad_desc
    mov     rdi, ivfbuf
    mov     esi, 192
    mov     rdx, image
    call    er_av1_reduced_still_encode_ivf_raw420
    test    eax, eax
    jnz     .fail_encode_raw420_bad_desc
    cmp     edx, ERROR_CORRUPT
    jne     .fail_encode_raw420_bad_desc
    inc     qword [rel passed]
    jmp     .encode_no_space
.fail_encode_raw420_bad_desc:
    inc     qword [rel failed]

.encode_no_space:
    mov     rdi, outbuf
    mov     esi, 2
    mov     edx, 64
    mov     ecx, 32
    mov     r8, tile
    mov     r9d, 3
    call    er_av1_reduced_still_encode
    test    eax, eax
    jnz     .fail_encode_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_encode_no_space
    inc     qword [rel passed]
    jmp     .decode_no_sequence
.fail_encode_no_space:
    inc     qword [rel failed]

.decode_no_sequence:
    mov     rdi, bad_stream
    mov     esi, 3
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jnz     .fail_decode_no_sequence
    cmp     edx, ERROR_CORRUPT
    jne     .fail_decode_no_sequence
    inc     qword [rel passed]
    jmp     .done
.fail_decode_no_sequence:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
