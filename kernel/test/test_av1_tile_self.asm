; EdgeRun AV1 tile-group self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_tile_group_decode_single
extern er_av1_tile_group_encode_single
extern er_av1_tile_raw420_size
extern er_av1_tile_raw420_fill_desc
extern er_av1_tile_raw420_validate
extern er_av1_tile_raw420_encode
extern er_av1_tile_raw420_decode

SECTION .bss
passed:    resq 1
failed:    resq 1
desc:      resb AV1_TILE_GROUP_SIZE
image:     resb AV1_IMAGE_SIZE
outbuf:    resb 32
decoded_y: resb 8
decoded_u: resb 2
decoded_v: resb 2

SECTION .data
tile: db 0xaa, 0xbb, 0xcc
plane_y: db 1, 2, 3, 4, 5, 6, 7, 8
plane_u: db 9, 10
plane_v: db 11, 12

SECTION .text
global _start
_start:
    mov     rdi, tile
    mov     esi, 3
    mov     rdx, desc
    call    er_av1_tile_group_decode_single
    cmp     eax, 3
    jne     .fail_decode
    test    edx, edx
    jnz     .fail_decode
    cmp     dword [rel desc + AV1_TILE_GROUP_START], 0
    jne     .fail_decode
    cmp     dword [rel desc + AV1_TILE_GROUP_END], 0
    jne     .fail_decode
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_OFFSET], 0
    jne     .fail_decode
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_LEN], 3
    jne     .fail_decode
    inc     qword [rel passed]
    jmp     .encode
.fail_decode:
    inc     qword [rel failed]

.encode:
    mov     rdi, outbuf
    mov     esi, 8
    mov     rdx, tile
    mov     ecx, 3
    call    er_av1_tile_group_encode_single
    cmp     eax, 3
    jne     .fail_encode
    test    edx, edx
    jnz     .fail_encode
    cmp     byte [rel outbuf], 0xaa
    jne     .fail_encode
    cmp     byte [rel outbuf + 1], 0xbb
    jne     .fail_encode
    cmp     byte [rel outbuf + 2], 0xcc
    jne     .fail_encode
    inc     qword [rel passed]
    jmp     .no_space
.fail_encode:
    inc     qword [rel failed]

.no_space:
    mov     rdi, outbuf
    mov     esi, 2
    mov     rdx, tile
    mov     ecx, 3
    call    er_av1_tile_group_encode_single
    test    eax, eax
    jnz     .fail_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_no_space
    inc     qword [rel passed]
    jmp     .raw_size
.fail_no_space:
    inc     qword [rel failed]

.raw_size:
    mov     edi, 4
    mov     esi, 2
    call    er_av1_tile_raw420_size
    cmp     eax, 12
    jne     .fail_raw_size
    test    edx, edx
    jnz     .fail_raw_size
    inc     qword [rel passed]
    jmp     .raw_fill
.fail_raw_size:
    inc     qword [rel failed]

.raw_fill:
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, plane_y
    mov     r8, plane_u
    mov     r9, plane_v
    call    er_av1_tile_raw420_fill_desc
    cmp     eax, 12
    jne     .fail_raw_fill
    test    edx, edx
    jnz     .fail_raw_fill
    cmp     dword [rel image + AV1_IMAGE_WIDTH], 4
    jne     .fail_raw_fill
    cmp     dword [rel image + AV1_IMAGE_HEIGHT], 2
    jne     .fail_raw_fill
    cmp     dword [rel image + AV1_IMAGE_Y_LEN], 8
    jne     .fail_raw_fill
    cmp     dword [rel image + AV1_IMAGE_U_LEN], 2
    jne     .fail_raw_fill
    cmp     dword [rel image + AV1_IMAGE_V_LEN], 2
    jne     .fail_raw_fill
    inc     qword [rel passed]
    jmp     .raw_encode
.fail_raw_fill:
    inc     qword [rel failed]

.raw_encode:
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, image
    call    er_av1_tile_raw420_encode
    cmp     eax, 12
    jne     .fail_raw_encode
    test    edx, edx
    jnz     .fail_raw_encode
    cmp     byte [rel outbuf], 1
    jne     .fail_raw_encode
    cmp     byte [rel outbuf + 7], 8
    jne     .fail_raw_encode
    cmp     byte [rel outbuf + 8], 9
    jne     .fail_raw_encode
    cmp     byte [rel outbuf + 9], 10
    jne     .fail_raw_encode
    cmp     byte [rel outbuf + 10], 11
    jne     .fail_raw_encode
    cmp     byte [rel outbuf + 11], 12
    jne     .fail_raw_encode
    inc     qword [rel passed]
    jmp     .raw_decode_setup
.fail_raw_encode:
    inc     qword [rel failed]

.raw_decode_setup:
    mov     rdi, image
    mov     esi, 4
    mov     edx, 2
    mov     rcx, decoded_y
    mov     r8, decoded_u
    mov     r9, decoded_v
    call    er_av1_tile_raw420_fill_desc
    test    edx, edx
    jnz     .fail_raw_decode
    mov     rdi, outbuf
    mov     esi, 12
    mov     rdx, image
    call    er_av1_tile_raw420_decode
    cmp     eax, 12
    jne     .fail_raw_decode
    test    edx, edx
    jnz     .fail_raw_decode
    cmp     byte [rel decoded_y], 1
    jne     .fail_raw_decode
    cmp     byte [rel decoded_y + 7], 8
    jne     .fail_raw_decode
    cmp     byte [rel decoded_u], 9
    jne     .fail_raw_decode
    cmp     byte [rel decoded_u + 1], 10
    jne     .fail_raw_decode
    cmp     byte [rel decoded_v], 11
    jne     .fail_raw_decode
    cmp     byte [rel decoded_v + 1], 12
    jne     .fail_raw_decode
    inc     qword [rel passed]
    jmp     .raw_encode_no_space
.fail_raw_decode:
    inc     qword [rel failed]

.raw_encode_no_space:
    mov     rdi, outbuf
    mov     esi, 11
    mov     rdx, image
    call    er_av1_tile_raw420_encode
    test    eax, eax
    jnz     .fail_raw_encode_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_raw_encode_no_space
    inc     qword [rel passed]
    jmp     .raw_decode_no_data
.fail_raw_encode_no_space:
    inc     qword [rel failed]

.raw_decode_no_data:
    mov     rdi, outbuf
    mov     esi, 11
    mov     rdx, image
    call    er_av1_tile_raw420_decode
    test    eax, eax
    jnz     .fail_raw_decode_no_data
    cmp     edx, ERROR_NO_DATA
    jne     .fail_raw_decode_no_data
    inc     qword [rel passed]
    jmp     .raw_validate_bad_len
.fail_raw_decode_no_data:
    inc     qword [rel failed]

.raw_validate_bad_len:
    mov     dword [rel image + AV1_IMAGE_U_LEN], 1
    mov     rdi, image
    call    er_av1_tile_raw420_validate
    test    eax, eax
    jnz     .fail_raw_validate_bad_len
    cmp     edx, ERROR_CORRUPT
    jne     .fail_raw_validate_bad_len
    inc     qword [rel passed]
    jmp     .done
.fail_raw_validate_bad_len:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
