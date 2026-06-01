; EdgeRun AV1 reduced-still stream self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"
%include "test/test_macros.inc"

extern er_av1_reduced_still_encode
extern er_av1_reduced_still_encode_split
extern er_av1_reduced_still_encode_ivf
extern er_av1_reduced_still_encode_raw420
extern er_av1_reduced_still_encode_raw420_redundant
extern er_av1_reduced_still_encode_raw420_delimited
extern er_av1_reduced_still_encode_raw420_with_metadata
extern er_av1_reduced_still_encode_raw420_with_metadata_padding
extern er_av1_reduced_still_append_raw420
extern er_av1_reduced_still_encode_ivf_raw420
extern er_av1_reduced_still_begin_ivf_raw420
extern er_av1_reduced_still_append_ivf_raw420
extern er_av1_reduced_still_decode
extern er_av1_reduced_still_decode_auto
extern er_av1_reduced_still_decode_ivf_frame
extern er_av1_reduced_still_decode_ivf_frame_raw420
extern er_av1_reduced_still_decode_raw_frame
extern er_av1_reduced_still_decode_raw_frame_raw420
extern er_av1_reduced_still_info_raw420
extern er_av1_reduced_still_info_raw_frame_raw420
extern er_av1_reduced_still_info_ivf_frame_raw420
extern er_av1_reduced_still_decode_raw420
extern er_av1_reduced_still_validate_raw420
extern er_av1_reduced_still_validate_ivf_frame_raw420
extern er_av1_reduced_still_count_raw_frames
extern er_av1_stream_decode_frame
extern er_av1_stream_encode_frame
extern er_av1_ivf_encode_header
extern er_av1_ivf_write_frame
extern er_av1_obu_decode_unit
extern er_av1_tile_raw420_fill_desc

TEST_BSS_PASSED_FAILED
raw_len: resd 1
raw_cursor: resd 1
ivf_len: resd 1
desc:    resb AV1_REDUCED_SIZE
stream_desc: resb AV1_STREAM_SIZE
entries: resb AV1_TILE_ENTRY_SIZE * 4
info:    resb AV1_INFO_SIZE
image:   resb AV1_IMAGE_SIZE
ivf_desc: resb AV1_IVF_HDR_SIZE
outbuf:  resb 128
ivfbuf:  resb 192
decoded_y: resb 8
decoded_u: resb 2
decoded_v: resb 2

SECTION .data
tile: db 0xaa, 0xbb, 0xcc
tile0: db 0x10, 0x11
tile1: db 0x20, 0x21, 0x22
tile2: db 0x30
tile3: db 0x40, 0x41, 0x42, 0x43
plane_y: db 1, 2, 3, 4, 5, 6, 7, 8
plane_u: db 9, 10
plane_v: db 11, 12
plane2_y: db 21, 22, 23, 24, 25, 26, 27, 28
plane2_u: db 29, 30
plane2_v: db 31, 32
metadata_cll: db 0x01, 0x02, 0x03, 0x04
bad_stream: db 0x32, 0x01, 0x00 ; OBU_FRAME with one zero payload byte, no sequence first

SECTION .text
global _start
_start:
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_PROFILE], AV1_SEQ_PROFILE_MAIN
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_STILL_PICTURE], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_REDUCED_STILL], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_LEVEL_IDX], AV1_SEQ_LEVEL_2_0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_WIDTH_BITS], 16
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_HEIGHT_BITS], 16
    mov     dword [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_MAX_WIDTH], 320
    mov     dword [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_MAX_HEIGHT], 240
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_TIMING_INFO_PRESENT], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_INITIAL_DISPLAY_DELAY], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_OPERATING_POINTS_MINUS_1], 0
    mov     word [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_OPERATING_POINT_IDC], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_USE_128X128_SUPERBLOCK], 1
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_FILTER_INTRA], 1
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_INTRA_EDGE_FILTER], 1
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_INTERINTRA_COMPOUND], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_MASKED_COMPOUND], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_WARPED_MOTION], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_DUAL_FILTER], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_ORDER_HINT], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_JNT_COMP], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_REF_FRAME_MVS], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], AV1_SEQ_SELECT_SCREEN_CONTENT_TOOLS
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_FORCE_INTEGER_MV], AV1_SEQ_SELECT_INTEGER_MV
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ORDER_HINT_BITS], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_SUPERRES], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_CDEF], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_ENABLE_RESTORATION], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_MONO_CHROME], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_COLOR_DESCRIPTION_PRESENT], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_COLOR_RANGE], 1
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_CHROMA_SAMPLE_POSITION], AV1_CHROMA_SAMPLE_POSITION_UNKNOWN
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_SEPARATE_UV_DELTA_Q], 0
    mov     byte [rel stream_desc + AV1_STREAM_SEQ + AV1_SEQ_FILM_GRAIN], 0
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_SHOW_FRAME], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_DISABLE_CDF_UPDATE], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_FORCE_INTEGER_MV], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_FRAME_SIZE_OVERRIDE], 1
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_WIDTH], 320
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_HEIGHT], 240
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_RENDER_WIDTH], 320
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_RENDER_HEIGHT], 240
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_ALLOW_INTRABC], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_COLS_LOG2], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_ROWS_LOG2], 1
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 2
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 2
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_COLS], 2
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_ROWS], 2
    mov     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TILE_INFO_COUNT], 4
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_SKIP_MODE_PRESENT], 0
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
    mov     rdi, ivfbuf
    mov     esi, 192
    lea     rdx, [rel stream_desc + AV1_STREAM_SEQ]
    lea     rcx, [rel stream_desc + AV1_STREAM_FRAME]
    mov     r8, entries
    mov     r9d, 4
    call    er_av1_stream_encode_frame
    test    eax, eax
    jz      .fail_stream_encode
    test    edx, edx
    jnz     .fail_stream_encode
    mov     [rel ivf_len], eax
    inc     qword [rel passed]
    jmp     .stream_decode
.fail_stream_encode:
    inc     qword [rel failed]

.stream_decode:
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, stream_desc
    mov     rcx, entries
    mov     r8d, 4
    call    er_av1_stream_decode_frame
    cmp     eax, [rel ivf_len]
    jne     .fail_stream_decode
    test    edx, edx
    jnz     .fail_stream_decode
    cmp     byte [rel stream_desc + AV1_STREAM_SEEN_SEQUENCE], 1
    jne     .fail_stream_decode
    cmp     byte [rel stream_desc + AV1_STREAM_SEEN_FRAME], 1
    jne     .fail_stream_decode
    cmp     byte [rel stream_desc + AV1_STREAM_SEEN_TILE], 1
    jne     .fail_stream_decode
    cmp     dword [rel stream_desc + AV1_STREAM_FRAME + AV1_FRAME_WIDTH], 320
    jne     .fail_stream_decode
    cmp     dword [rel stream_desc + AV1_STREAM_TILE_GROUP + AV1_TILE_GROUP_START], 0
    jne     .fail_stream_decode
    cmp     dword [rel stream_desc + AV1_STREAM_TILE_GROUP + AV1_TILE_GROUP_END], 3
    jne     .fail_stream_decode
    cmp     qword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_OFFSET], 13
    jne     .fail_stream_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_LEN], 4
    jne     .fail_stream_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_ROW], 1
    jne     .fail_stream_decode
    cmp     dword [rel entries + AV1_TILE_ENTRY_SIZE * 3 + AV1_TILE_ENTRY_COL], 1
    jne     .fail_stream_decode
    inc     qword [rel passed]
    jmp     .stream_decode_small_cap
.fail_stream_decode:
    inc     qword [rel failed]

.stream_decode_small_cap:
    mov     rdi, ivfbuf
    mov     esi, [rel ivf_len]
    mov     rdx, stream_desc
    mov     rcx, entries
    mov     r8d, 3
    call    er_av1_stream_decode_frame
    test    eax, eax
    jnz     .fail_stream_decode_small_cap
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_stream_decode_small_cap
    inc     qword [rel passed]
    jmp     .encode
.fail_stream_decode_small_cap:
    inc     qword [rel failed]

.encode:
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
    jmp     .duplicate_sequence_before_frame
.fail_decode:
    inc     qword [rel failed]

.duplicate_sequence_before_frame:
    mov     rdi, outbuf
    mov     esi, [rel raw_len]
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    test    eax, eax
    jz      .fail_duplicate_sequence_before_frame
    test    edx, edx
    jnz     .fail_duplicate_sequence_before_frame
    mov     [rel raw_cursor], eax
    mov     ecx, eax
    mov     rsi, outbuf
    mov     rdi, ivfbuf
.copy_seq_prefix:
    test    ecx, ecx
    jz      .copy_full_after_prefix
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_seq_prefix
.copy_full_after_prefix:
    mov     ecx, [rel raw_len]
    mov     rsi, outbuf
.copy_full_stream:
    test    ecx, ecx
    jz      .decode_duplicate_sequence_before_frame
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_full_stream
.decode_duplicate_sequence_before_frame:
    mov     esi, [rel raw_len]
    add     esi, [rel raw_cursor]
    mov     rdi, ivfbuf
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jz      .fail_duplicate_sequence_before_frame
    test    edx, edx
    jnz     .fail_duplicate_sequence_before_frame
    inc     qword [rel passed]
    jmp     .reject_sequence_after_frame
.fail_duplicate_sequence_before_frame:
    inc     qword [rel failed]

.reject_sequence_after_frame:
    mov     ecx, [rel raw_len]
    mov     rsi, outbuf
    mov     rdi, ivfbuf
.copy_full_before_suffix:
    test    ecx, ecx
    jz      .copy_seq_suffix
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_full_before_suffix
.copy_seq_suffix:
    mov     ecx, [rel raw_cursor]
    mov     rsi, outbuf
.copy_seq_suffix_loop:
    test    ecx, ecx
    jz      .decode_sequence_after_frame
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_seq_suffix_loop
.decode_sequence_after_frame:
    mov     esi, [rel raw_len]
    add     esi, [rel raw_cursor]
    mov     rdi, ivfbuf
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jnz     .fail_reject_sequence_after_frame
    cmp     edx, ERROR_CORRUPT
    jne     .fail_reject_sequence_after_frame
    inc     qword [rel passed]
    jmp     .wrap_ivf
.fail_reject_sequence_after_frame:
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
    mov     [rel raw_len], eax
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
    jmp     .reject_missing_split_tile
.fail_encode_split:
    inc     qword [rel failed]

.reject_missing_split_tile:
    mov     dword [rel raw_cursor], 0
.scan_split_tile_for_missing:
    mov     ecx, [rel raw_cursor]
    cmp     ecx, [rel raw_len]
    jae     .fail_reject_missing_split_tile
    mov     rdi, outbuf
    add     rdi, rcx
    mov     esi, [rel raw_len]
    sub     esi, ecx
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    test    eax, eax
    jz      .fail_reject_missing_split_tile
    test    edx, edx
    jnz     .fail_reject_missing_split_tile
    cmp     byte [rel desc + AV1_OBU_DESC_TYPE], AV1_OBU_TYPE_TILE_GROUP
    je      .decode_missing_split_tile
    add     [rel raw_cursor], eax
    jmp     .scan_split_tile_for_missing
.decode_missing_split_tile:
    mov     [rel ivf_len], eax
    mov     rdi, outbuf
    mov     esi, [rel raw_cursor]
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jnz     .fail_reject_missing_split_tile
    cmp     edx, ERROR_CORRUPT
    jne     .fail_reject_missing_split_tile
    inc     qword [rel passed]
    jmp     .reject_duplicate_split_tile
.fail_reject_missing_split_tile:
    inc     qword [rel failed]

.reject_duplicate_split_tile:
    mov     ecx, [rel raw_len]
    mov     rsi, outbuf
    mov     rdi, ivfbuf
.copy_split_stream:
    test    ecx, ecx
    jz      .copy_split_tile_again
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_split_stream
.copy_split_tile_again:
    mov     ecx, [rel ivf_len]
    mov     eax, [rel raw_cursor]
    lea     rsi, [rel outbuf + rax]
.copy_split_tile_again_loop:
    test    ecx, ecx
    jz      .decode_duplicate_split_tile
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jmp     .copy_split_tile_again_loop
.decode_duplicate_split_tile:
    mov     esi, [rel raw_len]
    add     esi, [rel ivf_len]
    mov     rdi, ivfbuf
    mov     rdx, desc
    call    er_av1_reduced_still_decode
    test    eax, eax
    jnz     .fail_reject_duplicate_split_tile
    cmp     edx, ERROR_CORRUPT
    jne     .fail_reject_duplicate_split_tile
    inc     qword [rel passed]
    jmp     .encode_split_no_space
.fail_reject_duplicate_split_tile:
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
    mov     rdi, outbuf
    mov     esi, [rel raw_len]
    mov     rdx, info
    call    er_av1_reduced_still_info_raw420
    test    eax, eax
    jz      .fail_encode_raw420
    test    edx, edx
    jnz     .fail_encode_raw420
    cmp     eax, [rel raw_len]
    jne     .fail_encode_raw420
    cmp     dword [rel info + AV1_INFO_WIDTH], 4
    jne     .fail_encode_raw420
    cmp     dword [rel info + AV1_INFO_HEIGHT], 2
    jne     .fail_encode_raw420
    cmp     dword [rel info + AV1_INFO_RAW420_LEN], 12
    jne     .fail_encode_raw420
    cmp     dword [rel info + AV1_INFO_TILE_LEN], 12
    jne     .fail_encode_raw420
    cmp     dword [rel info + AV1_INFO_BYTES_CONSUMED], eax
    jne     .fail_encode_raw420
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
	jmp     .encode_raw420_redundant
.fail_encode_raw420:
	inc     qword [rel failed]

.encode_raw420_redundant:
	mov     rdi, image
	mov     esi, 4
	mov     edx, 2
	mov     rcx, plane_y
	mov     r8, plane_u
	mov     r9, plane_v
	call    er_av1_tile_raw420_fill_desc
	test    edx, edx
	jnz     .fail_encode_raw420_redundant
	mov     rdi, outbuf
	mov     esi, 128
	mov     rdx, image
	call    er_av1_reduced_still_encode_raw420_redundant
	test    eax, eax
	jz      .fail_encode_raw420_redundant
	test    edx, edx
	jnz     .fail_encode_raw420_redundant
	mov     [rel raw_len], eax
	xor     ecx, ecx
.scan_redundant:
	cmp     ecx, [rel raw_len]
	jae     .fail_encode_raw420_redundant
	cmp     byte [rel outbuf + rcx], 0x3a
	je      .decode_redundant
	inc     ecx
	jmp     .scan_redundant
.decode_redundant:
	mov     [rel raw_cursor], ecx
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
	jnz     .fail_encode_raw420_redundant
	mov     rdi, outbuf
	mov     esi, [rel raw_len]
	mov     rdx, image
	mov     rcx, desc
	call    er_av1_reduced_still_decode_raw420
	test    eax, eax
	jz      .fail_encode_raw420_redundant
	test    edx, edx
	jnz     .fail_encode_raw420_redundant
	cmp     byte [rel decoded_y], 1
	jne     .fail_encode_raw420_redundant
	cmp     byte [rel decoded_y + 7], 8
	jne     .fail_encode_raw420_redundant
	cmp     byte [rel decoded_u], 9
	jne     .fail_encode_raw420_redundant
	cmp     byte [rel decoded_v + 1], 12
	jne     .fail_encode_raw420_redundant
	inc     qword [rel passed]
	jmp     .reject_bad_redundant
.fail_encode_raw420_redundant:
	inc     qword [rel failed]

.reject_bad_redundant:
	mov     eax, [rel raw_cursor]
	xor     byte [rel outbuf + rax + 2], 1
	mov     rdi, outbuf
	mov     esi, [rel raw_len]
	mov     rdx, desc
	call    er_av1_reduced_still_decode
	test    eax, eax
	jnz     .fail_reject_bad_redundant
	cmp     edx, ERROR_CORRUPT
	jne     .fail_reject_bad_redundant
	inc     qword [rel passed]
	jmp     .encode_raw420_delimited
.fail_reject_bad_redundant:
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
	jmp     .encode_raw420_metadata
.fail_encode_raw420_delimited:
	inc     qword [rel failed]

.encode_raw420_metadata:
	mov     rdi, image
	mov     esi, 4
	mov     edx, 2
	mov     rcx, plane_y
	mov     r8, plane_u
	mov     r9, plane_v
	call    er_av1_tile_raw420_fill_desc
	test    edx, edx
	jnz     .fail_encode_raw420_metadata
	mov     rdi, outbuf
	mov     esi, 128
	mov     rdx, image
	mov     ecx, AV1_METADATA_TYPE_HDR_CLL
	mov     r8, metadata_cll
	mov     r9d, AV1_METADATA_HDR_CLL_LEN
	call    er_av1_reduced_still_encode_raw420_with_metadata
	test    eax, eax
	jz      .fail_encode_raw420_metadata
	test    edx, edx
	jnz     .fail_encode_raw420_metadata
	mov     [rel raw_len], eax
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
	jnz     .fail_encode_raw420_metadata
	mov     rdi, outbuf
	mov     esi, [rel raw_len]
	mov     rdx, image
	mov     rcx, desc
	call    er_av1_reduced_still_decode_raw420
	test    eax, eax
	jz      .fail_encode_raw420_metadata
	test    edx, edx
	jnz     .fail_encode_raw420_metadata
	cmp     byte [rel decoded_y], 1
	jne     .fail_encode_raw420_metadata
	cmp     byte [rel decoded_y + 7], 8
	jne     .fail_encode_raw420_metadata
	cmp     byte [rel decoded_u], 9
	jne     .fail_encode_raw420_metadata
	cmp     byte [rel decoded_v + 1], 12
	jne     .fail_encode_raw420_metadata
	inc     qword [rel passed]
	jmp     .encode_raw420_metadata_padding
.fail_encode_raw420_metadata:
	inc     qword [rel failed]

.encode_raw420_metadata_padding:
	mov     rdi, image
	mov     esi, 4
	mov     edx, 2
	mov     rcx, plane_y
	mov     r8, plane_u
	mov     r9, plane_v
	call    er_av1_tile_raw420_fill_desc
	test    edx, edx
	jnz     .fail_encode_raw420_metadata_padding
	mov     rdi, outbuf
	mov     esi, 128
	mov     rdx, image
	mov     ecx, AV1_METADATA_TYPE_HDR_CLL
	mov     r8, metadata_cll
	mov     r9d, AV1_METADATA_HDR_CLL_LEN
	mov     r10d, 3
	call    er_av1_reduced_still_encode_raw420_with_metadata_padding
	test    eax, eax
	jz      .fail_encode_raw420_metadata_padding
	test    edx, edx
	jnz     .fail_encode_raw420_metadata_padding
	mov     [rel raw_len], eax
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
	jnz     .fail_encode_raw420_metadata_padding
	mov     rdi, outbuf
	mov     esi, [rel raw_len]
	mov     rdx, image
	mov     rcx, desc
	call    er_av1_reduced_still_decode_raw420
	test    eax, eax
	jz      .fail_encode_raw420_metadata_padding
	test    edx, edx
	jnz     .fail_encode_raw420_metadata_padding
	cmp     byte [rel decoded_y], 1
	jne     .fail_encode_raw420_metadata_padding
	cmp     byte [rel decoded_y + 7], 8
	jne     .fail_encode_raw420_metadata_padding
	cmp     byte [rel decoded_u], 9
	jne     .fail_encode_raw420_metadata_padding
	cmp     byte [rel decoded_v + 1], 12
	jne     .fail_encode_raw420_metadata_padding
	inc     qword [rel passed]
	jmp     .raw_append_count
.fail_encode_raw420_metadata_padding:
	inc     qword [rel failed]

.raw_append_count:
	mov     rdi, image
	mov     esi, 4
	mov     edx, 2
	mov     rcx, plane_y
	mov     r8, plane_u
	mov     r9, plane_v
	call    er_av1_tile_raw420_fill_desc
	test    edx, edx
	jnz     .fail_raw_append_count
	mov     rdi, ivfbuf
	mov     esi, 192
	xor     edx, edx
	mov     rcx, image
	call    er_av1_reduced_still_append_raw420
	test    eax, eax
	jz      .fail_raw_append_count
	test    edx, edx
	jnz     .fail_raw_append_count
	mov     [rel raw_cursor], eax
	mov     rdi, image
	mov     esi, 4
	mov     edx, 2
	mov     rcx, plane2_y
	mov     r8, plane2_u
	mov     r9, plane2_v
	call    er_av1_tile_raw420_fill_desc
	test    edx, edx
	jnz     .fail_raw_append_count
	mov     rdi, ivfbuf
	mov     esi, 192
	mov     edx, [rel raw_cursor]
	mov     rcx, image
	call    er_av1_reduced_still_append_raw420
	test    eax, eax
	jz      .fail_raw_append_count
	test    edx, edx
	jnz     .fail_raw_append_count
	mov     [rel raw_len], eax
	mov     rdi, ivfbuf
	mov     esi, [rel raw_len]
	call    er_av1_reduced_still_count_raw_frames
	cmp     eax, 2
	jne     .fail_raw_append_count
	test    edx, edx
	jnz     .fail_raw_append_count
	inc     qword [rel passed]
	jmp     .raw_info_second
.fail_raw_append_count:
	inc     qword [rel failed]

.raw_info_second:
	mov     rdi, ivfbuf
	mov     esi, [rel raw_len]
	mov     edx, 1
	mov     rcx, info
	call    er_av1_reduced_still_info_raw_frame_raw420
	test    eax, eax
	jz      .fail_raw_info_second
	test    edx, edx
	jnz     .fail_raw_info_second
	cmp     eax, [rel raw_len]
	jne     .fail_raw_info_second
	cmp     dword [rel info + AV1_INFO_WIDTH], 4
	jne     .fail_raw_info_second
	cmp     dword [rel info + AV1_INFO_HEIGHT], 2
	jne     .fail_raw_info_second
	cmp     dword [rel info + AV1_INFO_RAW420_LEN], 12
	jne     .fail_raw_info_second
	cmp     dword [rel info + AV1_INFO_BYTES_CONSUMED], eax
	jne     .fail_raw_info_second
	inc     qword [rel passed]
	jmp     .raw_seek_second
.fail_raw_info_second:
	inc     qword [rel failed]

.raw_seek_second:
	mov     rdi, ivfbuf
	mov     esi, [rel raw_len]
	mov     edx, 1
	mov     rcx, desc
	call    er_av1_reduced_still_decode_raw_frame
	test    eax, eax
	jz      .fail_raw_seek_second
	test    edx, edx
	jnz     .fail_raw_seek_second
	cmp     eax, [rel raw_len]
	jne     .fail_raw_seek_second
	mov     eax, [rel desc + AV1_REDUCED_TILE_OFFSET]
	cmp     byte [rel ivfbuf + rax], 21
	jne     .fail_raw_seek_second
	cmp     byte [rel ivfbuf + rax + 7], 28
	jne     .fail_raw_seek_second
	cmp     byte [rel ivfbuf + rax + 8], 29
	jne     .fail_raw_seek_second
	cmp     byte [rel ivfbuf + rax + 11], 32
	jne     .fail_raw_seek_second
	inc     qword [rel passed]
	jmp     .raw_decode_second
.fail_raw_seek_second:
	inc     qword [rel failed]

.raw_decode_second:
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
	jnz     .fail_raw_decode_second
	mov     rdi, ivfbuf
	mov     esi, [rel raw_len]
	mov     edx, 1
	mov     rcx, image
	mov     r8, desc
	call    er_av1_reduced_still_decode_raw_frame_raw420
	test    eax, eax
	jz      .fail_raw_decode_second
	test    edx, edx
	jnz     .fail_raw_decode_second
	cmp     byte [rel decoded_y], 21
	jne     .fail_raw_decode_second
	cmp     byte [rel decoded_y + 7], 28
	jne     .fail_raw_decode_second
	cmp     byte [rel decoded_u], 29
	jne     .fail_raw_decode_second
	cmp     byte [rel decoded_v + 1], 32
	jne     .fail_raw_decode_second
	inc     qword [rel passed]
	jmp     .raw_seek_missing
.fail_raw_decode_second:
	inc     qword [rel failed]

.raw_seek_missing:
	mov     rdi, ivfbuf
	mov     esi, [rel raw_len]
	mov     edx, 2
	mov     rcx, desc
	call    er_av1_reduced_still_decode_raw_frame
	test    eax, eax
	jnz     .fail_raw_seek_missing
	cmp     edx, ERROR_NO_DATA
	jne     .fail_raw_seek_missing
	inc     qword [rel passed]
	jmp     .decode_raw420_overlong_tile
.fail_raw_seek_missing:
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
    mov     rcx, info
    call    er_av1_reduced_still_info_ivf_frame_raw420
    test    eax, eax
    jz      .fail_decode_ivf_frame_index
    test    edx, edx
    jnz     .fail_decode_ivf_frame_index
    cmp     dword [rel info + AV1_INFO_WIDTH], 4
    jne     .fail_decode_ivf_frame_index
    cmp     dword [rel info + AV1_INFO_HEIGHT], 2
    jne     .fail_decode_ivf_frame_index
    cmp     dword [rel info + AV1_INFO_RAW420_LEN], 12
    jne     .fail_decode_ivf_frame_index
    cmp     dword [rel info + AV1_INFO_TILE_LEN], 12
    jne     .fail_decode_ivf_frame_index
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
    TEST_EXIT_FAILED
