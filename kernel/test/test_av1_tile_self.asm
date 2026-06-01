; EdgeRun AV1 tile-group self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"
%include "test/test_macros.inc"

extern er_av1_tile_group_decode_single
extern er_av1_tile_entries_validate_entropy
extern er_av1_tile_group_decode_entropy
extern er_av1_tile_group_decode
extern er_av1_tile_group_decode_uniform
extern er_av1_tile_group_encode_single
extern er_av1_tile_group_encode
extern er_av1_tile_group_encode_uniform
extern er_av1_tile_info_decode
extern er_av1_tile_info_encode
extern er_av1_tile_raw420_size
extern er_av1_tile_raw420_fill_desc
extern er_av1_tile_raw420_validate
extern er_av1_tile_raw420_encode
extern er_av1_tile_raw420_decode

TEST_BSS_PASSED_FAILED
desc:      resb AV1_TILE_GROUP_SIZE
tileinfo:  resb AV1_TILE_INFO_SIZE
entries:   resb AV1_TILE_ENTRY_SIZE * 4
image:     resb AV1_IMAGE_SIZE
outbuf:    resb 32
decoded_y: resb 8
decoded_u: resb 2
decoded_v: resb 2

SECTION .data
tile: db 0xaa, 0xbb, 0xcc
entropy_tiles_good: db 0x80, 0x80
entropy_tiles_bad_marker: db 0x00
entropy_tiles_bad_padding: db 0xc0
tile0: db 0x10, 0x11
tile1: db 0x20, 0x21, 0x22
tile2: db 0x30
tile3: db 0x40, 0x41, 0x42, 0x43
plane_y: db 1, 2, 3, 4, 5, 6, 7, 8
plane_u: db 9, 10
plane_v: db 11, 12

SECTION .text
global _start
_start:
    mov     byte [rel tileinfo + AV1_TILE_INFO_UNIFORM], 1
    mov     byte [rel tileinfo + AV1_TILE_INFO_COLS_LOG2], 1
    mov     byte [rel tileinfo + AV1_TILE_INFO_ROWS_LOG2], 1
    mov     byte [rel tileinfo + AV1_TILE_INFO_TILE_SIZE_BYTES], 2
    mov     dword [rel tileinfo + AV1_TILE_INFO_CONTEXT_UPDATE_ID], 2
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    call    er_av1_tile_info_encode
    test    eax, eax
    jz      .fail_tile_info_encode
    test    edx, edx
    jnz     .fail_tile_info_encode
    inc     qword [rel passed]
    jmp     .tile_info_decode
.fail_tile_info_encode:
    inc     qword [rel failed]

.tile_info_decode:
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    call    er_av1_tile_info_decode
    test    eax, eax
    jz      .fail_tile_info_decode
    test    edx, edx
    jnz     .fail_tile_info_decode
    cmp     byte [rel tileinfo + AV1_TILE_INFO_UNIFORM], 1
    jne     .fail_tile_info_decode
    cmp     byte [rel tileinfo + AV1_TILE_INFO_COLS_LOG2], 1
    jne     .fail_tile_info_decode
    cmp     byte [rel tileinfo + AV1_TILE_INFO_ROWS_LOG2], 1
    jne     .fail_tile_info_decode
    cmp     dword [rel tileinfo + AV1_TILE_INFO_COLS], 2
    jne     .fail_tile_info_decode
    cmp     dword [rel tileinfo + AV1_TILE_INFO_ROWS], 2
    jne     .fail_tile_info_decode
    cmp     dword [rel tileinfo + AV1_TILE_INFO_COUNT], 4
    jne     .fail_tile_info_decode
    cmp     dword [rel tileinfo + AV1_TILE_INFO_CONTEXT_UPDATE_ID], 2
    jne     .fail_tile_info_decode
    cmp     byte [rel tileinfo + AV1_TILE_INFO_TILE_SIZE_BYTES], 2
    jne     .fail_tile_info_decode
    inc     qword [rel passed]
    jmp     .tile_info_nonuniform_reject
.fail_tile_info_decode:
    inc     qword [rel failed]

.tile_info_nonuniform_reject:
    mov     byte [rel outbuf], 0
    mov     rdi, outbuf
    mov     esi, 1
    mov     rdx, tileinfo
    call    er_av1_tile_info_decode
    test    eax, eax
    jnz     .fail_tile_info_nonuniform_reject
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_tile_info_nonuniform_reject
    inc     qword [rel passed]
    jmp     .uniform_setup_entries
.fail_tile_info_nonuniform_reject:
    inc     qword [rel failed]

.uniform_setup_entries:
    lea     rax, [rel tile0]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 2
    lea     rax, [rel tile1]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_LEN], 3
    lea     rax, [rel tile2]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_LEN], 1
    lea     rax, [rel tile3]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_LEN], 4
    jmp     .uniform_encode

.uniform_encode:
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    mov     rcx, entries
    mov     r8d, 4
    call    er_av1_tile_group_encode_uniform
    cmp     eax, 16
    jne     .fail_uniform_encode
    test    edx, edx
    jnz     .fail_uniform_encode
    cmp     byte [rel outbuf + 0], 1
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 1], 0
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 2], 0x10
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 3], 0x11
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 4], 2
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 5], 0
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 6], 0x20
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 8], 0x22
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 9], 0
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 10], 0
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 11], 0x30
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 12], 0x40
    jne     .fail_uniform_encode
    cmp     byte [rel outbuf + 15], 0x43
    jne     .fail_uniform_encode
    inc     qword [rel passed]
    jmp     .uniform_encode_no_space
.fail_uniform_encode:
    inc     qword [rel failed]

.uniform_encode_no_space:
    mov     rdi, outbuf
    mov     esi, 15
    mov     rdx, tileinfo
    mov     rcx, entries
    mov     r8d, 4
    call    er_av1_tile_group_encode_uniform
    test    eax, eax
    jnz     .fail_uniform_encode_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_uniform_encode_no_space
    inc     qword [rel passed]
    jmp     .uniform_decode
.fail_uniform_encode_no_space:
    inc     qword [rel failed]

.uniform_decode:
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, tileinfo
    mov     rcx, entries
    mov     r8d, 4
    call    er_av1_tile_group_decode_uniform
    cmp     eax, 16
    jne     .fail_uniform_decode
    test    edx, edx
    jnz     .fail_uniform_decode
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 2
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 2
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_ROW], 0
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_COL], 0
    jne     .fail_uniform_decode
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_OFFSET], 6
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_LEN], 3
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_ROW], 0
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_COL], 1
    jne     .fail_uniform_decode
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_OFFSET], 11
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_LEN], 1
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_ROW], 1
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_COL], 0
    jne     .fail_uniform_decode
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_OFFSET], 12
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_LEN], 4
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_ROW], 1
    jne     .fail_uniform_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_COL], 1
    jne     .fail_uniform_decode
    inc     qword [rel passed]
    jmp     .uniform_decode_no_data
.fail_uniform_decode:
    inc     qword [rel failed]

.uniform_decode_no_data:
    mov     rdi, outbuf
    mov     esi, 10
    mov     rdx, tileinfo
    mov     rcx, entries
    mov     r8d, 4
    call    er_av1_tile_group_decode_uniform
    test    eax, eax
    jnz     .fail_uniform_decode_no_data
    cmp     edx, ERROR_NO_DATA
    jne     .fail_uniform_decode_no_data
    inc     qword [rel passed]
    jmp     .obu_group_setup_full
.fail_uniform_decode_no_data:
    inc     qword [rel failed]

.obu_group_setup_full:
    mov     dword [rel desc + AV1_TILE_GROUP_START], 0
    mov     dword [rel desc + AV1_TILE_GROUP_END], 3
    lea     rax, [rel tile0]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 2
    lea     rax, [rel tile1]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_LEN], 3
    lea     rax, [rel tile2]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 2 + AV1_TILE_ENTRY_LEN], 1
    lea     rax, [rel tile3]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_LEN], 4
    jmp     .obu_group_encode_full

.obu_group_encode_full:
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 4
    call    er_av1_tile_group_encode
    cmp     eax, 17
    jne     .fail_obu_group_encode_full
    test    edx, edx
    jnz     .fail_obu_group_encode_full
    cmp     byte [rel outbuf], 0
    jne     .fail_obu_group_encode_full
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_OFFSET], 1
    jne     .fail_obu_group_encode_full
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_LEN], 16
    jne     .fail_obu_group_encode_full
    cmp     byte [rel outbuf + 1], 1
    jne     .fail_obu_group_encode_full
    cmp     byte [rel outbuf + 3], 0x10
    jne     .fail_obu_group_encode_full
    cmp     byte [rel outbuf + 16], 0x43
    jne     .fail_obu_group_encode_full
    inc     qword [rel passed]
    jmp     .obu_group_decode_full
.fail_obu_group_encode_full:
    inc     qword [rel failed]

.obu_group_decode_full:
    mov     rdi, outbuf
    mov     esi, 17
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 4
    call    er_av1_tile_group_decode
    cmp     eax, 17
    jne     .fail_obu_group_decode_full
    test    edx, edx
    jnz     .fail_obu_group_decode_full
    cmp     dword [rel desc + AV1_TILE_GROUP_START], 0
    jne     .fail_obu_group_decode_full
    cmp     dword [rel desc + AV1_TILE_GROUP_END], 3
    jne     .fail_obu_group_decode_full
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_OFFSET], 1
    jne     .fail_obu_group_decode_full
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_LEN], 16
    jne     .fail_obu_group_decode_full
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 3
    jne     .fail_obu_group_decode_full
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 2
    jne     .fail_obu_group_decode_full
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_ROW], 0
    jne     .fail_obu_group_decode_full
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_COL], 0
    jne     .fail_obu_group_decode_full
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_OFFSET], 13
    jne     .fail_obu_group_decode_full
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_LEN], 4
    jne     .fail_obu_group_decode_full
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_ROW], 1
    jne     .fail_obu_group_decode_full
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_COL], 1
    jne     .fail_obu_group_decode_full
    inc     qword [rel passed]
    jmp     .obu_group_setup_range
.fail_obu_group_decode_full:
    inc     qword [rel failed]

.obu_group_setup_range:
    mov     dword [rel desc + AV1_TILE_GROUP_START], 1
    mov     dword [rel desc + AV1_TILE_GROUP_END], 2
    lea     rax, [rel tile1]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 3
    lea     rax, [rel tile2]
    mov     [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_PTR], rax
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_LEN], 1
    jmp     .obu_group_encode_range

.obu_group_encode_range:
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 2
    call    er_av1_tile_group_encode
    cmp     eax, 7
    jne     .fail_obu_group_encode_range
    test    edx, edx
    jnz     .fail_obu_group_encode_range
    cmp     byte [rel outbuf], 0xb0
    jne     .fail_obu_group_encode_range
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_OFFSET], 1
    jne     .fail_obu_group_encode_range
    cmp     dword [rel desc + AV1_TILE_GROUP_DATA_LEN], 6
    jne     .fail_obu_group_encode_range
    cmp     byte [rel outbuf + 1], 2
    jne     .fail_obu_group_encode_range
    cmp     byte [rel outbuf + 3], 0x20
    jne     .fail_obu_group_encode_range
    cmp     byte [rel outbuf + 6], 0x30
    jne     .fail_obu_group_encode_range
    inc     qword [rel passed]
    jmp     .obu_group_decode_range
.fail_obu_group_encode_range:
    inc     qword [rel failed]

.obu_group_decode_range:
    mov     rdi, outbuf
    mov     esi, 7
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 2
    call    er_av1_tile_group_decode
    cmp     eax, 7
    jne     .fail_obu_group_decode_range
    test    edx, edx
    jnz     .fail_obu_group_decode_range
    cmp     dword [rel desc + AV1_TILE_GROUP_START], 1
    jne     .fail_obu_group_decode_range
    cmp     dword [rel desc + AV1_TILE_GROUP_END], 2
    jne     .fail_obu_group_decode_range
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 3
    jne     .fail_obu_group_decode_range
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 3
    jne     .fail_obu_group_decode_range
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_ROW], 0
    jne     .fail_obu_group_decode_range
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_COL], 1
    jne     .fail_obu_group_decode_range
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_OFFSET], 6
    jne     .fail_obu_group_decode_range
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_LEN], 1
    jne     .fail_obu_group_decode_range
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_ROW], 1
    jne     .fail_obu_group_decode_range
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_COL], 0
    jne     .fail_obu_group_decode_range
    inc     qword [rel passed]
    jmp     .obu_group_decode_bad_padding
.fail_obu_group_decode_range:
    inc     qword [rel failed]

.obu_group_decode_bad_padding:
    mov     byte [rel outbuf], 0xb1
    mov     rdi, outbuf
    mov     esi, 7
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 2
    call    er_av1_tile_group_decode
    test    eax, eax
    jnz     .fail_obu_group_decode_bad_padding
    cmp     edx, ERROR_CORRUPT
    jne     .fail_obu_group_decode_bad_padding
    inc     qword [rel passed]
    jmp     .obu_group_decode_bad_range
.fail_obu_group_decode_bad_padding:
    inc     qword [rel failed]

.obu_group_decode_bad_range:
    mov     byte [rel outbuf], 0xc8
    mov     rdi, outbuf
    mov     esi, 7
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 2
    call    er_av1_tile_group_decode
    test    eax, eax
    jnz     .fail_obu_group_decode_bad_range
    cmp     edx, ERROR_CORRUPT
    jne     .fail_obu_group_decode_bad_range
    inc     qword [rel passed]
    jmp     .obu_group_decode_small_cap
.fail_obu_group_decode_bad_range:
    inc     qword [rel failed]

.obu_group_decode_small_cap:
    mov     byte [rel outbuf], 0xb0
    mov     rdi, outbuf
    mov     esi, 7
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 1
    call    er_av1_tile_group_decode
    test    eax, eax
    jnz     .fail_obu_group_decode_small_cap
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_obu_group_decode_small_cap
    inc     qword [rel passed]
    jmp     .obu_group_encode_bad_range
.fail_obu_group_decode_small_cap:
    inc     qword [rel failed]

.obu_group_encode_bad_range:
    mov     dword [rel desc + AV1_TILE_GROUP_START], 3
    mov     dword [rel desc + AV1_TILE_GROUP_END], 1
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 2
    call    er_av1_tile_group_encode
    test    eax, eax
    jnz     .fail_obu_group_encode_bad_range
    cmp     edx, ERROR_CORRUPT
    jne     .fail_obu_group_encode_bad_range
    inc     qword [rel passed]
    jmp     .obu_group_encode_bad_count
.fail_obu_group_encode_bad_range:
    inc     qword [rel failed]

.obu_group_encode_bad_count:
    mov     dword [rel desc + AV1_TILE_GROUP_START], 1
    mov     dword [rel desc + AV1_TILE_GROUP_END], 2
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 1
    call    er_av1_tile_group_encode
    test    eax, eax
    jnz     .fail_obu_group_encode_bad_count
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_obu_group_encode_bad_count
    inc     qword [rel passed]
    jmp     .obu_group_encode_no_space
.fail_obu_group_encode_bad_count:
    inc     qword [rel failed]

.obu_group_encode_no_space:
    mov     dword [rel desc + AV1_TILE_GROUP_START], 1
    mov     dword [rel desc + AV1_TILE_GROUP_END], 2
    mov     rdi, outbuf
    xor     esi, esi
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 2
    call    er_av1_tile_group_encode
    test    eax, eax
    jnz     .fail_obu_group_encode_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_obu_group_encode_no_space
    inc     qword [rel passed]
    jmp     .decode
.fail_obu_group_encode_no_space:
    inc     qword [rel failed]

.decode:
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
    jmp     .entropy_validate_setup
.fail_raw_validate_bad_len:
    inc     qword [rel failed]

.entropy_validate_setup:
    mov     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 0
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 1
    mov     qword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_OFFSET], 1
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 1 + AV1_TILE_ENTRY_LEN], 1
    jmp     .entropy_validate_good

.entropy_validate_good:
    mov     rdi, entropy_tiles_good
    mov     esi, 2
    mov     rdx, entries
    mov     ecx, 2
    call    er_av1_tile_entries_validate_entropy
    cmp     eax, 2
    jne     .fail_entropy_validate_good
    test    edx, edx
    jnz     .fail_entropy_validate_good
    inc     qword [rel passed]
    jmp     .entropy_validate_bad_marker
.fail_entropy_validate_good:
    inc     qword [rel failed]

.entropy_validate_bad_marker:
    mov     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 0
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 1
    mov     rdi, entropy_tiles_bad_marker
    mov     esi, 1
    mov     rdx, entries
    mov     ecx, 1
    call    er_av1_tile_entries_validate_entropy
    test    eax, eax
    jnz     .fail_entropy_validate_bad_marker
    cmp     edx, ERROR_CORRUPT
    jne     .fail_entropy_validate_bad_marker
    inc     qword [rel passed]
    jmp     .entropy_validate_bad_padding
.fail_entropy_validate_bad_marker:
    inc     qword [rel failed]

.entropy_validate_bad_padding:
    mov     rdi, entropy_tiles_bad_padding
    mov     esi, 1
    mov     rdx, entries
    mov     ecx, 1
    call    er_av1_tile_entries_validate_entropy
    test    eax, eax
    jnz     .fail_entropy_validate_bad_padding
    cmp     edx, ERROR_CORRUPT
    jne     .fail_entropy_validate_bad_padding
    inc     qword [rel passed]
    jmp     .entropy_validate_no_data
.fail_entropy_validate_bad_padding:
    inc     qword [rel failed]

.entropy_validate_no_data:
    mov     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 1
    mov     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 1
    mov     rdi, entropy_tiles_good
    mov     esi, 1
    mov     rdx, entries
    mov     ecx, 1
    call    er_av1_tile_entries_validate_entropy
    test    eax, eax
    jnz     .fail_entropy_validate_no_data
    cmp     edx, ERROR_NO_DATA
    jne     .fail_entropy_validate_no_data
    inc     qword [rel passed]
    jmp     .entropy_group_setup
.fail_entropy_validate_no_data:
    inc     qword [rel failed]

.entropy_group_setup:
    mov     byte [rel tileinfo + AV1_TILE_INFO_UNIFORM], 1
    mov     byte [rel tileinfo + AV1_TILE_INFO_COLS_LOG2], 0
    mov     byte [rel tileinfo + AV1_TILE_INFO_ROWS_LOG2], 0
    mov     byte [rel tileinfo + AV1_TILE_INFO_TILE_SIZE_BYTES], 1
    mov     dword [rel tileinfo + AV1_TILE_INFO_COLS], 1
    mov     dword [rel tileinfo + AV1_TILE_INFO_ROWS], 1
    mov     dword [rel tileinfo + AV1_TILE_INFO_COUNT], 1
    jmp     .entropy_group_decode_good

.entropy_group_decode_good:
    mov     rdi, entropy_tiles_good
    mov     esi, 1
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 1
    call    er_av1_tile_group_decode_entropy
    cmp     eax, 1
    jne     .fail_entropy_group_decode_good
    test    edx, edx
    jnz     .fail_entropy_group_decode_good
    cmp     dword [rel desc + AV1_TILE_GROUP_START], 0
    jne     .fail_entropy_group_decode_good
    cmp     dword [rel desc + AV1_TILE_GROUP_END], 0
    jne     .fail_entropy_group_decode_good
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_OFFSET], 0
    jne     .fail_entropy_group_decode_good
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 0 + AV1_TILE_ENTRY_LEN], 1
    jne     .fail_entropy_group_decode_good
    inc     qword [rel passed]
    jmp     .entropy_group_decode_bad
.fail_entropy_group_decode_good:
    inc     qword [rel failed]

.entropy_group_decode_bad:
    mov     rdi, entropy_tiles_bad_marker
    mov     esi, 1
    mov     rdx, tileinfo
    mov     rcx, desc
    mov     r8, entries
    mov     r9d, 1
    call    er_av1_tile_group_decode_entropy
    test    eax, eax
    jnz     .fail_entropy_group_decode_bad
    cmp     edx, ERROR_CORRUPT
    jne     .fail_entropy_group_decode_bad
    inc     qword [rel passed]
    jmp     .done
.fail_entropy_group_decode_bad:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
