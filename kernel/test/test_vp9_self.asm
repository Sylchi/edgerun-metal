; EdgeRun VP9 self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/vp9_constants.inc"
%include "test/test_macros.inc"

extern er_vp9_parse_frame_header
extern er_vp9_is_key_frame
extern er_vp8_bool_reader_init
extern er_vp8_bool_read_flag
extern er_vp8_bool_read_literal
extern er_vp9_read_tx_mode
extern er_vp9_parse_tx_size_probability_updates
extern er_vp9_parse_compressed_header_prefix
extern er_vp9_parse_superframe_index
extern er_vp9_validate_frame_payload
extern er_vp9_ivf_is
extern er_vp9_ivf_decode_header
extern er_vp9_ivf_read_frame
extern er_vp9_ivf_count_frames
extern er_vp9_ivf_validate_frame_count
extern er_vp9_ivf_validate_timestamps
extern er_vp9_ivf_seek_frame
extern er_vp9_ivf_validate_payloads

TEST_BSS_PASSED_FAILED
header_desc: resb VP9_HEADER_DESC_SIZE
super_desc:  resb VP9_SUPERFRAME_DESC_SIZE
bool_reader: resb VP9_BOOL_READER_SIZE
compressed_desc: resb VP9_COMPRESSED_HEADER_SIZE
ivf_hdr:     resb VP9_IVF_HDR_SIZE
ivf_frame:   resb VP9_IVF_FRAME_SIZE

SECTION .data
key_frame_640x360:
    db 0x42
    db 0x49,0x83,0x42
    db 0xf1,0x27,0x70,0x16,0x00
key_frame_render_640x360:
    db 0x42
    db 0x49,0x83,0x42
    db 0xf1,0x27,0x70,0x16,0xf0,0x4f,0xe0,0x2c,0x00
inter_frame:
    db 0x62
show_existing_5:
    db 0xb2
bad_marker:
    db 0x40
bad_sync:
    db 0x42
    db 0x49,0x83,0x43
    db 0xf1,0x27,0x70,0x16,0x00
profile3_reserved:
    db 0x5e
profile1_key:
    db 0x46
    db 0x49,0x83,0x42
    db 0xf1,0x27,0x70,0x16,0x00
bool_zero:
    db 0x00,0x00,0x00
bool_one:
    db 0xff,0xff,0xff
compressed_select_no_updates:
    db 0xdf,0x40,0x00
superframe_two:
    db 0x62
    db 0x62
    db 0xc1, 1, 1, 0xc1
superframe_two_len equ $ - superframe_two
superframe_size4:
    db 0x42
    db 0x62
    db 0xd9, 1, 0, 0, 0, 1, 0, 0, 0, 0xd9
superframe_size4_len equ $ - superframe_size4
superframe_bad_sum:
    db 0x42
    db 0x62
    db 0xc1, 1, 2, 0xc1
superframe_bad_sum_len equ $ - superframe_bad_sum
superframe_bad_marker:
    db 0x42
    db 0x62
    db 0xc0, 1, 1, 0xc1
superframe_bad_marker_len equ $ - superframe_bad_marker
superframe_bad_subheader:
    db 0x40
    db 0x62
    db 0xc1, 1, 1, 0xc1
superframe_bad_subheader_len equ $ - superframe_bad_subheader
superframe_truncated:
    db 0xc7
ivf_vp9_two:
    db 0x44,0x4b,0x49,0x46
    dw 0, VP9_IVF_HEADER_SIZE
    db "VP90"
    dw 640, 360
    dd 30, 1, 2, 0
    dd VP9_KEY_HEADER_SIZE
    dq 0
    db 0x42
    db 0x49,0x83,0x42
    db 0xf1,0x27,0x70,0x16,0x00
    dd superframe_two_len
    dq 1
    db 0x62
    db 0x62
    db 0xc1, 1, 1, 0xc1
ivf_vp9_two_len equ $ - ivf_vp9_two
ivf_vp9_bad_codec:
    db 0x44,0x4b,0x49,0x46
    dw 0, VP9_IVF_HEADER_SIZE
    db "VP80"
    dw 640, 360
    dd 30, 1, 2, 0
ivf_vp9_bad_count:
    db 0x44,0x4b,0x49,0x46
    dw 0, VP9_IVF_HEADER_SIZE
    db "VP90"
    dw 640, 360
    dd 30, 1, 3, 0
    dd VP9_KEY_HEADER_SIZE
    dq 0
    db 0x42
    db 0x49,0x83,0x42
    db 0xf1,0x27,0x70,0x16,0x00
    dd superframe_two_len
    dq 1
    db 0x62
    db 0x62
    db 0xc1, 1, 1, 0xc1
ivf_vp9_bad_count_len equ $ - ivf_vp9_bad_count
ivf_vp9_bad_timestamp:
    db 0x44,0x4b,0x49,0x46
    dw 0, VP9_IVF_HEADER_SIZE
    db "VP90"
    dw 640, 360
    dd 30, 1, 2, 0
    dd VP9_KEY_HEADER_SIZE
    dq 1
    db 0x42
    db 0x49,0x83,0x42
    db 0xf1,0x27,0x70,0x16,0x00
    dd superframe_two_len
    dq 1
    db 0x62
    db 0x62
    db 0xc1, 1, 1, 0xc1
ivf_vp9_bad_timestamp_len equ $ - ivf_vp9_bad_timestamp
ivf_vp9_bad_payload:
    db 0x44,0x4b,0x49,0x46
    dw 0, VP9_IVF_HEADER_SIZE
    db "VP90"
    dw 640, 360
    dd 30, 1, 1, 0
    dd 1
    dq 0
    db 0x40
ivf_vp9_bad_payload_len equ $ - ivf_vp9_bad_payload

SECTION .text
global _start
_start:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE + 2
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_KEY_HEADER_SIZE
    jne     .fail_key
    test    edx, edx
    jnz     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_MARKER], VP9_FRAME_MARKER
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_PROFILE], 0
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_EXISTING], 0
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_KEY
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_FRAME], 1
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_ERROR_RESILIENT], 0
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_WIDTH], 640
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_HEIGHT], 360
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_RENDER_WIDTH], 640
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_RENDER_HEIGHT], 360
    jne     .fail_key
    inc     qword [rel passed]
    jmp     .key_render
.fail_key:
    inc     qword [rel failed]

.key_render:
    mov     rdi, key_frame_render_640x360
    mov     esi, VP9_KEY_HEADER_RENDER_SIZE
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_KEY_HEADER_RENDER_SIZE
    jne     .fail_key_render
    test    edx, edx
    jnz     .fail_key_render
    cmp     word [rel header_desc + VP9_HEADER_DESC_WIDTH], 640
    jne     .fail_key_render
    cmp     word [rel header_desc + VP9_HEADER_DESC_HEIGHT], 360
    jne     .fail_key_render
    cmp     word [rel header_desc + VP9_HEADER_DESC_RENDER_WIDTH], 640
    jne     .fail_key_render
    cmp     word [rel header_desc + VP9_HEADER_DESC_RENDER_HEIGHT], 360
    jne     .fail_key_render
    inc     qword [rel passed]
    jmp     .short_render
.fail_key_render:
    inc     qword [rel failed]

.short_render:
    mov     rdi, key_frame_render_640x360
    mov     esi, VP9_KEY_HEADER_RENDER_SIZE - 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_short_render
    cmp     edx, ERROR_NO_DATA
    jne     .fail_short_render
    inc     qword [rel passed]
    jmp     .is_key
.fail_short_render:
    inc     qword [rel failed]

.is_key:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE
    call    er_vp9_is_key_frame
    cmp     eax, 1
    jne     .fail_is_key
    test    edx, edx
    jnz     .fail_is_key
    inc     qword [rel passed]
    jmp     .inter
.fail_is_key:
    inc     qword [rel failed]

.inter:
    mov     rdi, inter_frame
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_INTER_HEADER_SIZE
    jne     .fail_inter
    test    edx, edx
    jnz     .fail_inter
    cmp     byte [rel header_desc + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_INTER
    jne     .fail_inter
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_FRAME], 1
    jne     .fail_inter
    cmp     byte [rel header_desc + VP9_HEADER_DESC_ERROR_RESILIENT], 0
    jne     .fail_inter
    inc     qword [rel passed]
    jmp     .show_existing
.fail_inter:
    inc     qword [rel failed]

.show_existing:
    mov     rdi, show_existing_5
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_SHOW_EXISTING_HEADER_SIZE
    jne     .fail_show_existing
    test    edx, edx
    jnz     .fail_show_existing
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_EXISTING], 1
    jne     .fail_show_existing
    cmp     byte [rel header_desc + VP9_HEADER_DESC_EXISTING_FRAME_IDX], 5
    jne     .fail_show_existing
    inc     qword [rel passed]
    jmp     .short_key
.fail_show_existing:
    inc     qword [rel failed]

.short_key:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE - 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_short_key
    cmp     edx, ERROR_NO_DATA
    jne     .fail_short_key
    inc     qword [rel passed]
    jmp     .bad_marker
.fail_short_key:
    inc     qword [rel failed]

.bad_marker:
    mov     rdi, bad_marker
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_bad_marker
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_marker
    inc     qword [rel passed]
    jmp     .bad_sync
.fail_bad_marker:
    inc     qword [rel failed]

.bad_sync:
    mov     rdi, bad_sync
    mov     esi, VP9_KEY_HEADER_SIZE
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_bad_sync
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_sync
    inc     qword [rel passed]
    jmp     .profile3_reserved
.fail_bad_sync:
    inc     qword [rel failed]

.profile3_reserved:
    mov     rdi, profile3_reserved
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_profile3_reserved
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_profile3_reserved
    inc     qword [rel passed]
    jmp     .profile1_key
.fail_profile3_reserved:
    inc     qword [rel failed]

.profile1_key:
    mov     rdi, profile1_key
    mov     esi, VP9_KEY_HEADER_SIZE
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_profile1_key
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_profile1_key
    inc     qword [rel passed]
    jmp     .bool_reader
.fail_profile1_key:
    inc     qword [rel failed]

.bool_reader:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    cmp     eax, VP9_BOOL_READER_SIZE
    jne     .fail_bool_reader
    test    edx, edx
    jnz     .fail_bool_reader
    mov     rdi, bool_reader
    call    er_vp8_bool_read_flag
    test    eax, eax
    jnz     .fail_bool_reader
    test    edx, edx
    jnz     .fail_bool_reader
    mov     rdi, bool_reader
    mov     esi, 2
    call    er_vp8_bool_read_literal
    test    eax, eax
    jnz     .fail_bool_reader
    test    edx, edx
    jnz     .fail_bool_reader
    inc     qword [rel passed]
    jmp     .bool_short
.fail_bool_reader:
    inc     qword [rel failed]

.bool_short:
    mov     rdi, bool_zero
    mov     esi, 1
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    test    eax, eax
    jnz     .fail_bool_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_bool_short
    inc     qword [rel passed]
    jmp     .tx_mode
.fail_bool_short:
    inc     qword [rel failed]

.tx_mode:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    test    edx, edx
    jnz     .fail_tx_mode
    mov     rdi, bool_reader
    call    er_vp9_read_tx_mode
    cmp     eax, VP9_TX_MODE_ONLY_4X4
    jne     .fail_tx_mode
    test    edx, edx
    jnz     .fail_tx_mode
    mov     rdi, bool_one
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    test    edx, edx
    jnz     .fail_tx_mode
    mov     rdi, bool_reader
    call    er_vp9_read_tx_mode
    cmp     eax, VP9_TX_MODE_SELECT
    jne     .fail_tx_mode
    test    edx, edx
    jnz     .fail_tx_mode
    inc     qword [rel passed]
    jmp     .tx_prob_updates
.fail_tx_mode:
    inc     qword [rel failed]

.tx_prob_updates:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    test    edx, edx
    jnz     .fail_tx_prob_updates
    mov     rdi, bool_reader
    lea     rsi, [compressed_desc + VP9_COMPRESSED_HEADER_TX_UPDATES]
    call    er_vp9_parse_tx_size_probability_updates
    test    eax, eax
    jnz     .fail_tx_prob_updates
    test    edx, edx
    jnz     .fail_tx_prob_updates
    cmp     byte [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_UPDATES], 0
    jne     .fail_tx_prob_updates
    cmp     byte [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_UPDATES + VP9_TX_PROB_UPDATE_TOTAL - 1], 0
    jne     .fail_tx_prob_updates
    inc     qword [rel passed]
    jmp     .compressed_header_prefix
.fail_tx_prob_updates:
    inc     qword [rel failed]

.compressed_header_prefix:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, compressed_desc
    call    er_vp9_parse_compressed_header_prefix
    cmp     eax, VP9_COMPRESSED_HEADER_SIZE
    jne     .fail_compressed_header_prefix
    test    edx, edx
    jnz     .fail_compressed_header_prefix
    cmp     dword [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_MODE], VP9_TX_MODE_ONLY_4X4
    jne     .fail_compressed_header_prefix
    cmp     dword [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_UPDATE_COUNT], 0
    jne     .fail_compressed_header_prefix
    cmp     dword [rel compressed_desc + VP9_COMPRESSED_HEADER_READER + VP9_BOOL_READER_INPUT_INDEX], VP9_BOOL_INITIAL_BYTES
    jne     .fail_compressed_header_prefix
    mov     rdi, compressed_select_no_updates
    mov     esi, 4
    mov     rdx, compressed_desc
    call    er_vp9_parse_compressed_header_prefix
    cmp     eax, VP9_COMPRESSED_HEADER_SIZE
    jne     .fail_compressed_header_prefix
    test    edx, edx
    jnz     .fail_compressed_header_prefix
    cmp     dword [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_MODE], VP9_TX_MODE_SELECT
    jne     .fail_compressed_header_prefix
    cmp     dword [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_UPDATE_COUNT], 0
    jne     .fail_compressed_header_prefix
    cmp     byte [rel compressed_desc + VP9_COMPRESSED_HEADER_TX_UPDATES + VP9_TX_PROB_UPDATE_TOTAL - 1], 0
    jne     .fail_compressed_header_prefix
    inc     qword [rel passed]
    jmp     .superframe
.fail_compressed_header_prefix:
    inc     qword [rel failed]

.superframe:
    mov     rdi, superframe_two
    mov     esi, superframe_two_len
    mov     rdx, super_desc
    call    er_vp9_parse_superframe_index
    cmp     eax, 2
    jne     .fail_superframe
    test    edx, edx
    jnz     .fail_superframe
    cmp     byte [rel super_desc + VP9_SUPERFRAME_DESC_FRAME_COUNT], 2
    jne     .fail_superframe
    cmp     byte [rel super_desc + VP9_SUPERFRAME_DESC_SIZE_BYTES], 1
    jne     .fail_superframe
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_INDEX_OFFSET], 2
    jne     .fail_superframe
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_PAYLOAD_END], 2
    jne     .fail_superframe
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_FRAME_SIZES], 1
    jne     .fail_superframe
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_FRAME_SIZES + 4], 1
    jne     .fail_superframe
    inc     qword [rel passed]
    jmp     .superframe_size4
.fail_superframe:
    inc     qword [rel failed]

.superframe_size4:
    mov     rdi, superframe_size4
    mov     esi, superframe_size4_len
    mov     rdx, super_desc
    call    er_vp9_parse_superframe_index
    cmp     eax, 2
    jne     .fail_superframe_size4
    test    edx, edx
    jnz     .fail_superframe_size4
    cmp     byte [rel super_desc + VP9_SUPERFRAME_DESC_SIZE_BYTES], VP9_SUPERFRAME_MAX_SIZE_BYTES
    jne     .fail_superframe_size4
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_FRAME_SIZES], 1
    jne     .fail_superframe_size4
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_FRAME_SIZES + 4], 1
    jne     .fail_superframe_size4
    inc     qword [rel passed]
    jmp     .not_superframe
.fail_superframe_size4:
    inc     qword [rel failed]

.not_superframe:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE
    mov     rdx, super_desc
    call    er_vp9_parse_superframe_index
    test    eax, eax
    jnz     .fail_not_superframe
    test    edx, edx
    jnz     .fail_not_superframe
    cmp     byte [rel super_desc + VP9_SUPERFRAME_DESC_FRAME_COUNT], 0
    jne     .fail_not_superframe
    cmp     dword [rel super_desc + VP9_SUPERFRAME_DESC_PAYLOAD_END], VP9_KEY_HEADER_SIZE
    jne     .fail_not_superframe
    inc     qword [rel passed]
    jmp     .superframe_bad_sum
.fail_not_superframe:
    inc     qword [rel failed]

.superframe_bad_sum:
    mov     rdi, superframe_bad_sum
    mov     esi, superframe_bad_sum_len
    mov     rdx, super_desc
    call    er_vp9_parse_superframe_index
    test    eax, eax
    jnz     .fail_superframe_bad_sum
    cmp     edx, ERROR_CORRUPT
    jne     .fail_superframe_bad_sum
    inc     qword [rel passed]
    jmp     .superframe_bad_marker
.fail_superframe_bad_sum:
    inc     qword [rel failed]

.superframe_bad_marker:
    mov     rdi, superframe_bad_marker
    mov     esi, superframe_bad_marker_len
    mov     rdx, super_desc
    call    er_vp9_parse_superframe_index
    test    eax, eax
    jnz     .fail_superframe_bad_marker
    cmp     edx, ERROR_CORRUPT
    jne     .fail_superframe_bad_marker
    inc     qword [rel passed]
    jmp     .superframe_truncated
.fail_superframe_bad_marker:
    inc     qword [rel failed]

.superframe_truncated:
    mov     rdi, superframe_truncated
    mov     esi, 1
    mov     rdx, super_desc
    call    er_vp9_parse_superframe_index
    test    eax, eax
    jnz     .fail_superframe_truncated
    cmp     edx, ERROR_NO_DATA
    jne     .fail_superframe_truncated
    inc     qword [rel passed]
    jmp     .validate_single
.fail_superframe_truncated:
    inc     qword [rel failed]

.validate_single:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE
    call    er_vp9_validate_frame_payload
    cmp     eax, 1
    jne     .fail_validate_single
    test    edx, edx
    jnz     .fail_validate_single
    inc     qword [rel passed]
    jmp     .validate_superframe
.fail_validate_single:
    inc     qword [rel failed]

.validate_superframe:
    mov     rdi, superframe_two
    mov     esi, superframe_two_len
    call    er_vp9_validate_frame_payload
    cmp     eax, 2
    jne     .fail_validate_superframe
    test    edx, edx
    jnz     .fail_validate_superframe
    inc     qword [rel passed]
    jmp     .validate_bad_subheader
.fail_validate_superframe:
    inc     qword [rel failed]

.validate_bad_subheader:
    mov     rdi, superframe_bad_subheader
    mov     esi, superframe_bad_subheader_len
    call    er_vp9_validate_frame_payload
    test    eax, eax
    jnz     .fail_validate_bad_subheader
    cmp     edx, ERROR_CORRUPT
    jne     .fail_validate_bad_subheader
    inc     qword [rel passed]
    jmp     .validate_empty
.fail_validate_bad_subheader:
    inc     qword [rel failed]

.validate_empty:
    mov     rdi, key_frame_640x360
    xor     esi, esi
    call    er_vp9_validate_frame_payload
    test    eax, eax
    jnz     .fail_validate_empty
    cmp     edx, ERROR_NO_DATA
    jne     .fail_validate_empty
    inc     qword [rel passed]
    jmp     .ivf_is
.fail_validate_empty:
    inc     qword [rel failed]

.ivf_is:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    call    er_vp9_ivf_is
    cmp     eax, 1
    jne     .fail_ivf_is
    test    edx, edx
    jnz     .fail_ivf_is
    mov     rdi, bad_marker
    mov     esi, 1
    call    er_vp9_ivf_is
    test    eax, eax
    jnz     .fail_ivf_is
    test    edx, edx
    jnz     .fail_ivf_is
    inc     qword [rel passed]
    jmp     .ivf_header
.fail_ivf_is:
    inc     qword [rel failed]

.ivf_header:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    mov     rdx, ivf_hdr
    call    er_vp9_ivf_decode_header
    cmp     eax, VP9_IVF_HEADER_SIZE
    jne     .fail_ivf_header
    test    edx, edx
    jnz     .fail_ivf_header
    cmp     dword [rel ivf_hdr + VP9_IVF_HDR_CODEC], VP9_IVF_CODEC_VP90
    jne     .fail_ivf_header
    cmp     word [rel ivf_hdr + VP9_IVF_HDR_WIDTH], 640
    jne     .fail_ivf_header
    cmp     word [rel ivf_hdr + VP9_IVF_HDR_HEIGHT], 360
    jne     .fail_ivf_header
    cmp     dword [rel ivf_hdr + VP9_IVF_HDR_FRAME_COUNT], 2
    jne     .fail_ivf_header
    inc     qword [rel passed]
    jmp     .ivf_bad_codec
.fail_ivf_header:
    inc     qword [rel failed]

.ivf_bad_codec:
    mov     rdi, ivf_vp9_bad_codec
    mov     esi, VP9_IVF_HEADER_SIZE
    mov     rdx, ivf_hdr
    call    er_vp9_ivf_decode_header
    test    eax, eax
    jnz     .fail_ivf_bad_codec
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_ivf_bad_codec
    inc     qword [rel passed]
    jmp     .ivf_read_frame
.fail_ivf_bad_codec:
    inc     qword [rel failed]

.ivf_read_frame:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    mov     edx, VP9_IVF_HEADER_SIZE
    mov     rcx, ivf_frame
    call    er_vp9_ivf_read_frame
    cmp     eax, VP9_IVF_HEADER_SIZE + VP9_IVF_FRAME_HEADER_SIZE + VP9_KEY_HEADER_SIZE
    jne     .fail_ivf_read_frame
    test    edx, edx
    jnz     .fail_ivf_read_frame
    cmp     dword [rel ivf_frame + VP9_IVF_FRAME_PAYLOAD_OFFSET], VP9_IVF_HEADER_SIZE + VP9_IVF_FRAME_HEADER_SIZE
    jne     .fail_ivf_read_frame
    cmp     dword [rel ivf_frame + VP9_IVF_FRAME_PAYLOAD_LEN], VP9_KEY_HEADER_SIZE
    jne     .fail_ivf_read_frame
    cmp     qword [rel ivf_frame + VP9_IVF_FRAME_TIMESTAMP], 0
    jne     .fail_ivf_read_frame
    inc     qword [rel passed]
    jmp     .ivf_count
.fail_ivf_read_frame:
    inc     qword [rel failed]

.ivf_count:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    call    er_vp9_ivf_count_frames
    cmp     eax, 2
    jne     .fail_ivf_count
    test    edx, edx
    jnz     .fail_ivf_count
    inc     qword [rel passed]
    jmp     .ivf_validate_count
.fail_ivf_count:
    inc     qword [rel failed]

.ivf_validate_count:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    call    er_vp9_ivf_validate_frame_count
    cmp     eax, 2
    jne     .fail_ivf_validate_count
    test    edx, edx
    jnz     .fail_ivf_validate_count
    mov     rdi, ivf_vp9_bad_count
    mov     esi, ivf_vp9_bad_count_len
    call    er_vp9_ivf_validate_frame_count
    test    eax, eax
    jnz     .fail_ivf_validate_count
    cmp     edx, ERROR_CORRUPT
    jne     .fail_ivf_validate_count
    inc     qword [rel passed]
    jmp     .ivf_timestamps
.fail_ivf_validate_count:
    inc     qword [rel failed]

.ivf_timestamps:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    call    er_vp9_ivf_validate_timestamps
    cmp     eax, 2
    jne     .fail_ivf_timestamps
    test    edx, edx
    jnz     .fail_ivf_timestamps
    mov     rdi, ivf_vp9_bad_timestamp
    mov     esi, ivf_vp9_bad_timestamp_len
    call    er_vp9_ivf_validate_timestamps
    test    eax, eax
    jnz     .fail_ivf_timestamps
    cmp     edx, ERROR_CORRUPT
    jne     .fail_ivf_timestamps
    inc     qword [rel passed]
    jmp     .ivf_seek
.fail_ivf_timestamps:
    inc     qword [rel failed]

.ivf_seek:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    mov     edx, 1
    mov     rcx, ivf_frame
    call    er_vp9_ivf_seek_frame
    cmp     eax, ivf_vp9_two_len
    jne     .fail_ivf_seek
    test    edx, edx
    jnz     .fail_ivf_seek
    cmp     dword [rel ivf_frame + VP9_IVF_FRAME_PAYLOAD_LEN], superframe_two_len
    jne     .fail_ivf_seek
    cmp     qword [rel ivf_frame + VP9_IVF_FRAME_TIMESTAMP], 1
    jne     .fail_ivf_seek
    inc     qword [rel passed]
    jmp     .ivf_payloads
.fail_ivf_seek:
    inc     qword [rel failed]

.ivf_payloads:
    mov     rdi, ivf_vp9_two
    mov     esi, ivf_vp9_two_len
    call    er_vp9_ivf_validate_payloads
    cmp     eax, 2
    jne     .fail_ivf_payloads
    test    edx, edx
    jnz     .fail_ivf_payloads
    mov     rdi, ivf_vp9_bad_payload
    mov     esi, ivf_vp9_bad_payload_len
    call    er_vp9_ivf_validate_payloads
    test    eax, eax
    jnz     .fail_ivf_payloads
    cmp     edx, ERROR_CORRUPT
    jne     .fail_ivf_payloads
    inc     qword [rel passed]
    jmp     .done
.fail_ivf_payloads:
    inc     qword [rel failed]

.done:
    mov     rax, [rel failed]
    test    rax, rax
    jz      .ok
    mov     edi, 1
    mov     eax, 60
    syscall
.ok:
    xor     edi, edi
    mov     eax, 60
    syscall
