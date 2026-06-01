; EdgeRun VP8 self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/vp8_constants.inc"
%include "test/test_macros.inc"

extern er_vp8_parse_frame_tag
extern er_vp8_write_visible_key_frame_tag
extern er_vp8_write_visible_inter_frame_tag
extern er_vp8_is_key_frame
extern er_vp8_parse_key_frame_header
extern er_vp8_parse_key_frame_payload
extern er_vp8_parse_inter_frame_payload
extern er_vp8_decode_key_frame
extern er_vp8_decode_frame_with_reference
extern er_vp8_bool_reader_init
extern er_vp8_bool_read
extern er_vp8_bool_read_flag
extern er_vp8_bool_read_literal
extern er_vp8_parse_token_partitions
extern er_vp8_token_partition_count
extern er_vp8_updated_motion_vector_probability
extern er_vp8_bool_read_signed_literal
extern er_vp8_bool_read_optional_signed_literal
extern er_vp8_parse_quant_indices
extern er_vp8_quant_index
extern er_vp8_segment_quant_base
extern er_vp8_dc_quant
extern er_vp8_ac_quant
extern er_vp8_build_dequant
extern er_vp8_parse_segmentation_header
extern er_vp8_parse_loop_filter_header
extern er_vp8_loop_filter_parameters
extern er_vp8_filter_macroblock
extern er_vp8_parse_compressed_key_frame_header
extern er_vp8_parse_compressed_inter_frame_header
extern er_vp8_read_key_macroblock_header
extern er_vp8_read_reference_name
extern er_vp8_read_inter_prediction
extern er_vp8_read_inter_split_motion
extern er_vp8_read_inter_macroblock_header
extern er_vp8_luma_mode_intra4_mode
extern er_vp8_memset
extern er_vp8_read_reference_copy
extern er_vp8_parse_inter_reference_header
extern er_vp8_apply_inter_reference_header
extern er_vp8_read_intra16_mode
extern er_vp8_read_chroma_mode
extern er_vp8_read_inter_intra16_mode
extern er_vp8_read_inter_chroma_mode
extern er_vp8_read_intra4_mode
extern er_vp8_read_category_coeff_value
extern er_vp8_read_signed_coeff
extern er_vp8_macroblock_dimension
extern er_vp8_macroblock_count
extern er_vp8_coeff_band
extern er_vp8_zigzag
extern er_vp8_coeff_probability_offset
extern er_vp8_coeff_probability_from
extern er_vp8_coeff_default_probability
extern er_vp8_copy_default_coeff_probabilities
extern er_vp8_read_large_coeff_value
extern er_vp8_read_coeff_block
extern er_vp8_read_residual_macroblock_single
extern er_vp8_skip_residual_context
extern er_vp8_read_residual_macroblock_context
extern er_vp8_init_default_edges
extern er_vp8_chroma_dimension
extern er_vp8_write_luma_macroblock
extern er_vp8_write_chroma_macroblock
extern er_vp8_read_reference_luma_nearest
extern er_vp8_read_reference_chroma_nearest
extern er_vp8_read_reference_luma_subpixel
extern er_vp8_read_reference_luma_split
extern er_vp8_average_split_chroma_motion
extern er_vp8_read_reference_chroma_subpixel
extern er_vp8_subpixel_filter_value
extern er_vp8_reference_horizontal_sample
extern er_vp8_reference_vertical_sample
extern er_vp8_reference_subpixel_sample
extern er_vp8_abs_diff_u8
extern er_vp8_saturate_i8
extern er_vp8_filter_normal_macroblock_vertical_edge
extern er_vp8_filter_normal_macroblock_horizontal_edge
extern er_vp8_filter_normal_subblock_vertical_edge
extern er_vp8_filter_normal_subblock_horizontal_edge
extern er_vp8_filter_simple_vertical_edge
extern er_vp8_filter_simple_horizontal_edge
extern er_vp8_dequantize_y2_block
extern er_vp8_dequantize_y_block_with_own_dc
extern er_vp8_dequantize_y_block_with_y2_dc
extern er_vp8_dequantize_uv_block
extern er_vp8_inverse_wht
extern er_vp8_idct_mul_shift
extern er_vp8_inverse_idct
extern er_vp8_clamp_u8
extern er_vp8_yuv_to_rgba
extern er_vp8_write_frame_rgba
extern er_vp8_add_pixel
extern er_vp8_add_idct_block
extern er_vp8_y_plane_block_offset
extern er_vp8_uv_plane_block_offset
extern er_vp8_add_luma_residuals_without_y2
extern er_vp8_add_luma_residuals_with_y2
extern er_vp8_add_chroma_residuals
extern er_vp8_reconstruct_bpred_luma
extern er_vp8_reconstruct_intra_luma
extern er_vp8_reconstruct_chroma
extern er_vp8_reconstruct_intra_macroblock
extern er_vp8_dc_prediction_value
extern er_vp8_predict_dc
extern er_vp8_predict_vertical
extern er_vp8_predict_horizontal
extern er_vp8_predict_true_motion
extern er_vp8_predict_luma
extern er_vp8_predict_chroma
extern er_vp8_avg2
extern er_vp8_avg3
extern er_vp8_write_intra4
extern er_vp8_predict_intra4_dc
extern er_vp8_predict_intra4_true_motion
extern er_vp8_predict_intra4_vertical
extern er_vp8_predict_intra4_horizontal
extern er_vp8_predict_intra4_left_down
extern er_vp8_predict_intra4_vertical_left
extern er_vp8_predict_intra4_horizontal_up
extern er_vp8_build_intra4_edge
extern er_vp8_predict_intra4_right_down
extern er_vp8_predict_intra4_vertical_right
extern er_vp8_predict_intra4_horizontal_down
extern er_vp8_predict_intra4_block
extern er_vp8_coeff_update_probability
extern er_vp8_parse_token_probability_updates
extern er_vp8_read_small_motion_vector_component
extern er_vp8_read_long_motion_vector_component
extern er_vp8_read_motion_vector_component
extern er_vp8_read_motion_vector
extern er_vp8_same_motion_vector
extern er_vp8_add_motion_vector
extern er_vp8_read_sub_motion_vector
extern er_vp8_sub_motion_context
extern er_vp8_inter_mode_context_probability
extern er_vp8_split_mv_partition
extern er_vp8_read_split_mv_partition

VP8_TEST_KEY_FIRST_PARTITION_LEN    equ 160
VP8_TEST_INTER_FIRST_PARTITION_LEN  equ 19
VP8_TEST_PAYLOAD_LEN                equ 16
VP8_TEST_PAYLOAD_CONSUMED           equ VP8_KEY_FRAME_HEADER_SIZE + 4
VP8_TEST_PAYLOAD_FIRST_LEN          equ 4
VP8_TEST_PAYLOAD_TOKEN_LEN          equ 2
VP8_TEST_PAYLOAD_EMPTY_LEN          equ VP8_KEY_FRAME_HEADER_SIZE
VP8_TEST_PAYLOAD_SHORT_LEN          equ 11
VP8_TEST_FRAME_WIDTH                equ 20
VP8_TEST_FRAME_HEIGHT               equ 18
VP8_TEST_CHROMA_WIDTH               equ 10
VP8_TEST_CHROMA_HEIGHT              equ 9
VP8_TEST_FRAME_Y_BYTES              equ VP8_TEST_FRAME_WIDTH * VP8_TEST_FRAME_HEIGHT
VP8_TEST_FRAME_UV_BYTES             equ VP8_TEST_CHROMA_WIDTH * VP8_TEST_CHROMA_HEIGHT
VP8_TEST_GRAY_PAYLOAD_LEN           equ 24
VP8_TEST_GRAY_YUV_BYTES             equ 6
VP8_TEST_WIDE_GRAY_PAYLOAD_LEN      equ 34
VP8_TEST_WIDE_GRAY_WIDTH            equ 32
VP8_TEST_WIDE_GRAY_HEIGHT           equ 16
VP8_TEST_WIDE_GRAY_PIXELS           equ VP8_TEST_WIDE_GRAY_WIDTH * VP8_TEST_WIDE_GRAY_HEIGHT
VP8_TEST_WIDE_GRAY_YUV_BYTES        equ VP8_TEST_WIDE_GRAY_PIXELS + 2 * ((VP8_TEST_WIDE_GRAY_WIDTH / 2) * (VP8_TEST_WIDE_GRAY_HEIGHT / 2))
VP8_TEST_INTER_DECODE_FIRST_LEN      equ VP8_TEST_KEY_FIRST_PARTITION_LEN
VP8_TEST_INTER_DECODE_LEN            equ VP8_FRAME_TAG_SIZE + VP8_TEST_INTER_DECODE_FIRST_LEN + VP8_BOOL_INITIAL_BYTES
VP8_TEST_LUMA_CLIP_FIRST            equ 16 * VP8_TEST_FRAME_WIDTH + 16
VP8_TEST_LUMA_CLIP_LAST             equ 17 * VP8_TEST_FRAME_WIDTH + 19
VP8_TEST_LUMA_CLIP_BEFORE           equ VP8_TEST_LUMA_CLIP_FIRST - 1
VP8_TEST_CHROMA_CLIP_FIRST          equ 8 * VP8_TEST_CHROMA_WIDTH + 8
VP8_TEST_CHROMA_CLIP_LAST           equ 8 * VP8_TEST_CHROMA_WIDTH + 9
VP8_TEST_CHROMA_CLIP_BEFORE         equ VP8_TEST_CHROMA_CLIP_FIRST - 1

TEST_BSS_PASSED_FAILED
tag_desc:       resb VP8_TAG_DESC_SIZE
key_header:     resb VP8_KEY_HEADER_SIZE
key_payload:    resb VP8_KEY_PAYLOAD_SIZE
out_tag:        resb VP8_FRAME_TAG_SIZE
bool_reader:    resb VP8_BOOL_READER_SIZE
partitions:     resb VP8_TOKEN_PARTITIONS_SIZE
quant:          resb VP8_QUANT_SIZE
dequant:        resb VP8_DEQUANT_SIZE
segment_desc:   resb VP8_SEGMENT_HEADER_SIZE
loop_filter:    resb VP8_LOOP_FILTER_HEADER_SIZE
loop_filter_params: resb VP8_LOOP_FILTER_PARAM_SIZE
reference:      resb VP8_REFERENCE_HEADER_SIZE
motion_vector:  resb VP8_MOTION_VECTOR_SIZE
motion_vector_other: resb VP8_MOTION_VECTOR_SIZE
split_partition: resb VP8_Y_BLOCK_COUNT
subpixel_taps:  resb VP8_SUBPIXEL_FILTER_TAP_COUNT
token_probabilities: resb VP8_COEFF_UPDATE_PROBABILITY_COUNT
compressed_header: resb VP8_COMPRESSED_HEADER_SIZE
macroblock_header: resb VP8_MACROBLOCK_HEADER_SIZE
first_partition_zero: resb VP8_TEST_KEY_FIRST_PARTITION_LEN
coeff_block:     resb VP8_COEFF_BLOCK_BYTES
macroblock_coeffs: resb VP8_MACROBLOCK_COEFF_BLOCK_COUNT * VP8_COEFF_BLOCK_BYTES
modes:           resb VP8_Y_BLOCK_COUNT
dequant_block:   resb VP8_DEQUANT_BLOCK_BYTES * 2
plane:           resb VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
u_plane:         resb VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
v_plane:         resb VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
frame_y:         resb VP8_TEST_FRAME_Y_BYTES
frame_u:         resb VP8_TEST_FRAME_UV_BYTES
frame_v:         resb VP8_TEST_FRAME_UV_BYTES
frame_rgba:      resd VP8_TEST_FRAME_WIDTH * VP8_TEST_FRAME_HEIGHT
gray_yuv:        resb VP8_TEST_GRAY_YUV_BYTES
gray_rgba:       resd 4
wide_gray_yuv:   resb VP8_TEST_WIDE_GRAY_YUV_BYTES
wide_gray_rgba:  resd VP8_TEST_WIDE_GRAY_PIXELS
edges:           resb VP8_EDGES_SIZE_16
intra4_top:      resb VP8_BLOCK_SIZE * 2
intra4_edge:     resb VP8_INTRA4_EDGE_SIZE
intra4_left:     resb VP8_BLOCK_SIZE
top_modes:       resb VP8_MAX_LUMA_TOKEN_COLUMNS
left_modes:      resb VP8_BLOCK_SIZE
residual_context: resb VP8_RESIDUAL_CONTEXT_SIZE
inter_decode_frame: resb VP8_TEST_INTER_DECODE_LEN

SECTION .data
key_tag:        db 0x30, 0x00, 0x00
inter_tag:      db 0x31, 0x00, 0x00
bad_version:    db 0x38, 0x00, 0x00
hidden_frame:   db 0x20, 0x00, 0x00
key_header_2x3: db 0x30, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00
bad_start_code: db 0x30, 0x00, 0x00, 0x9d, 0x01, 0x2b, 0x02, 0x00, 0x03, 0x00
zero_width:     db 0x30, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x00, 0x00, 0x03, 0x00
payload:        db 0x90, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00
                db 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff
payload_empty:  db 0x10, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00
payload_short:  db 0x50, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00
                db 0xaa
inter_payload:  db 0x31, 0x00, 0x00, 0xaa, 0xbb
bool_zero:      db 0x00, 0x00, 0xaa
bool_ones:      db 0xff, 0xff
bool_long_ones: db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
bool_lit:       db 0xa0, 0x00
bool_neg:       db 0xb0, 0x00
segment_full:   db 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
loop_filter_full: db 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
reference_zero: db 0x00, 0x00, 0x00, 0x00
reference_full: db 0xff, 0xff, 0x00, 0x00
reference_copy_golden: db 0x20, 0x00, 0x00, 0x00
reference_copy_alternate_last: db 0x90, 0x00, 0x00, 0x00
mode_zero:      db 0x00, 0x00
mode_full:      db 0xff, 0xff
mode_i16_vertical: db 0x80, 0x00
mode_i16_horizontal: db 0xc0, 0x00
mode_chroma_vertical: db 0xa0, 0x00
mode_chroma_horizontal: db 0xc0, 0x00
mode_bpred_dc:   db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
inter_intra16_probs: db 112, 86, 140, 37
inter_chroma_probs: db 162, 101, 204
inter_intra4_probs: db 120, 90, 79, 133, 87, 85, 80, 111, 151
mv_probs:       db 162, 128, 225, 146, 172, 147, 214, 39, 156, 128, 129, 132, 75, 145, 178, 206, 239, 254, 254
                db 164, 128, 204, 170, 119, 235, 140, 230, 228, 128, 130, 130, 74, 148, 180, 203, 236, 254, 254
token_parts:    db 0x03, 0x00, 0x00, 0xaa, 0xbb, 0xcc, 0xdd, 0xee
token_parts_bad: db 0x06, 0x00, 0x00, 0xaa
vp8_gray_payload: db 0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00
                  db 0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00
                  db 0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00
vp8_wide_gray_payload: db 0xb0, 0x02, 0x00, 0x9d, 0x01, 0x2a, 0x20, 0x00
                       db 0x10, 0x00, 0x3e, 0x6d, 0x2c, 0x93, 0x45, 0xa4
                       db 0x22, 0xa1, 0x98, 0x04, 0x00, 0x40, 0x06, 0xc4
                       db 0xb4, 0x80, 0x00, 0x4a, 0xc4, 0x00, 0x00, 0xe4
                       db 0x40, 0x00

SECTION .text
global _start
_start:
    mov     rdi, key_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    cmp     eax, VP8_FRAME_TAG_SIZE
    jne     .fail_parse_key
    test    edx, edx
    jnz     .fail_parse_key
    cmp     byte [rel tag_desc + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_KEY
    jne     .fail_parse_key
    cmp     byte [rel tag_desc + VP8_TAG_DESC_VERSION], 0
    jne     .fail_parse_key
    cmp     byte [rel tag_desc + VP8_TAG_DESC_SHOW_FRAME], VP8_SHOW_FRAME_VISIBLE
    jne     .fail_parse_key
    cmp     dword [rel tag_desc + VP8_TAG_DESC_FIRST_PARTITION_LEN], 1
    jne     .fail_parse_key
    inc     qword [rel passed]
    jmp     .parse_inter
.fail_parse_key:
    inc     qword [rel failed]

.parse_inter:
    mov     rdi, inter_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    test    edx, edx
    jnz     .fail_parse_inter
    cmp     byte [rel tag_desc + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_INTER
    jne     .fail_parse_inter
    inc     qword [rel passed]
    jmp     .reject_short
.fail_parse_inter:
    inc     qword [rel failed]

.reject_short:
    mov     rdi, key_tag
    mov     esi, VP8_FRAME_TAG_SIZE - 1
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    test    eax, eax
    jnz     .fail_reject_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_reject_short
    inc     qword [rel passed]
    jmp     .reject_version
.fail_reject_short:
    inc     qword [rel failed]

.reject_version:
    mov     rdi, bad_version
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    test    eax, eax
    jnz     .fail_reject_version
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_reject_version
    inc     qword [rel passed]
    jmp     .reject_hidden
.fail_reject_version:
    inc     qword [rel failed]

.reject_hidden:
    mov     rdi, hidden_frame
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    test    eax, eax
    jnz     .fail_reject_hidden
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_reject_hidden
    inc     qword [rel passed]
    jmp     .write_key
.fail_reject_hidden:
    inc     qword [rel failed]

.write_key:
    mov     rdi, out_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     edx, VP8_TEST_KEY_FIRST_PARTITION_LEN
    call    er_vp8_write_visible_key_frame_tag
    cmp     eax, VP8_FRAME_TAG_SIZE
    jne     .fail_write_key
    test    edx, edx
    jnz     .fail_write_key
    mov     rdi, out_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    test    edx, edx
    jnz     .fail_write_key
    cmp     byte [rel tag_desc + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_KEY
    jne     .fail_write_key
    cmp     dword [rel tag_desc + VP8_TAG_DESC_FIRST_PARTITION_LEN], VP8_TEST_KEY_FIRST_PARTITION_LEN
    jne     .fail_write_key
    inc     qword [rel passed]
    jmp     .write_inter
.fail_write_key:
    inc     qword [rel failed]

.write_inter:
    mov     rdi, out_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     edx, VP8_TEST_INTER_FIRST_PARTITION_LEN
    call    er_vp8_write_visible_inter_frame_tag
    test    edx, edx
    jnz     .fail_write_inter
    mov     rdi, out_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     rdx, tag_desc
    call    er_vp8_parse_frame_tag
    test    edx, edx
    jnz     .fail_write_inter
    cmp     byte [rel tag_desc + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_INTER
    jne     .fail_write_inter
    cmp     dword [rel tag_desc + VP8_TAG_DESC_FIRST_PARTITION_LEN], VP8_TEST_INTER_FIRST_PARTITION_LEN
    jne     .fail_write_inter
    inc     qword [rel passed]
    jmp     .write_range
.fail_write_inter:
    inc     qword [rel failed]

.write_range:
    mov     rdi, out_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     edx, VP8_FIRST_PARTITION_LEN_MAX + 1
    call    er_vp8_write_visible_key_frame_tag
    test    eax, eax
    jnz     .fail_write_range
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_write_range
    inc     qword [rel passed]
    jmp     .is_key
.fail_write_range:
    inc     qword [rel failed]

.is_key:
    mov     rdi, key_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    call    er_vp8_is_key_frame
    cmp     eax, 1
    jne     .fail_is_key
    test    edx, edx
    jnz     .fail_is_key
    mov     rdi, inter_tag
    mov     esi, VP8_FRAME_TAG_SIZE
    call    er_vp8_is_key_frame
    test    eax, eax
    jnz     .fail_is_key
    test    edx, edx
    jnz     .fail_is_key
    inc     qword [rel passed]
    jmp     .key_header
.fail_is_key:
    inc     qword [rel failed]

.key_header:
    mov     rdi, key_header_2x3
    mov     esi, VP8_KEY_FRAME_HEADER_SIZE
    mov     rdx, key_header
    call    er_vp8_parse_key_frame_header
    cmp     eax, VP8_KEY_FRAME_HEADER_SIZE
    jne     .fail_key_header
    test    edx, edx
    jnz     .fail_key_header
    cmp     word [rel key_header + VP8_KEY_HEADER_WIDTH], 2
    jne     .fail_key_header
    cmp     word [rel key_header + VP8_KEY_HEADER_HEIGHT], 3
    jne     .fail_key_header
    inc     qword [rel passed]
    jmp     .bad_key_header
.fail_key_header:
    inc     qword [rel failed]

.bad_key_header:
    mov     rdi, bad_start_code
    mov     esi, VP8_KEY_FRAME_HEADER_SIZE
    mov     rdx, key_header
    call    er_vp8_parse_key_frame_header
    test    eax, eax
    jnz     .fail_bad_key_header
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_key_header
    mov     rdi, zero_width
    mov     esi, VP8_KEY_FRAME_HEADER_SIZE
    mov     rdx, key_header
    call    er_vp8_parse_key_frame_header
    test    eax, eax
    jnz     .fail_bad_key_header
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_key_header
    inc     qword [rel passed]
    jmp     .payload
.fail_bad_key_header:
    inc     qword [rel failed]

.payload:
    mov     rdi, payload
    mov     esi, VP8_TEST_PAYLOAD_LEN
    mov     rdx, key_payload
    call    er_vp8_parse_key_frame_payload
    cmp     eax, VP8_TEST_PAYLOAD_CONSUMED
    jne     .fail_payload
    test    edx, edx
    jnz     .fail_payload
    cmp     word [rel key_payload + VP8_KEY_PAYLOAD_WIDTH], 2
    jne     .fail_payload
    cmp     word [rel key_payload + VP8_KEY_PAYLOAD_HEIGHT], 3
    jne     .fail_payload
    cmp     dword [rel key_payload + VP8_KEY_PAYLOAD_FIRST_OFFSET], VP8_KEY_FRAME_HEADER_SIZE
    jne     .fail_payload
    cmp     dword [rel key_payload + VP8_KEY_PAYLOAD_FIRST_LEN], VP8_TEST_PAYLOAD_FIRST_LEN
    jne     .fail_payload
    cmp     dword [rel key_payload + VP8_KEY_PAYLOAD_TOKEN_OFFSET], VP8_TEST_PAYLOAD_CONSUMED
    jne     .fail_payload
    cmp     dword [rel key_payload + VP8_KEY_PAYLOAD_TOKEN_LEN], VP8_TEST_PAYLOAD_TOKEN_LEN
    jne     .fail_payload
    inc     qword [rel passed]
    jmp     .inter_payload
.fail_payload:
    inc     qword [rel failed]

.inter_payload:
    mov     rdi, inter_payload
    mov     esi, 5
    mov     rdx, key_payload
    call    er_vp8_parse_inter_frame_payload
    cmp     eax, VP8_FRAME_TAG_SIZE + 1
    jne     .fail_inter_payload
    test    edx, edx
    jnz     .fail_inter_payload
    cmp     dword [rel key_payload + VP8_INTER_PAYLOAD_FIRST_OFFSET], VP8_FRAME_TAG_SIZE
    jne     .fail_inter_payload
    cmp     dword [rel key_payload + VP8_INTER_PAYLOAD_FIRST_LEN], 1
    jne     .fail_inter_payload
    cmp     dword [rel key_payload + VP8_INTER_PAYLOAD_TOKEN_OFFSET], VP8_FRAME_TAG_SIZE + 1
    jne     .fail_inter_payload
    cmp     dword [rel key_payload + VP8_INTER_PAYLOAD_TOKEN_LEN], 1
    jne     .fail_inter_payload
    inc     qword [rel passed]
    jmp     .decode_gray_payload
.fail_inter_payload:
    inc     qword [rel failed]

.decode_gray_payload:
    mov     rdi, vp8_gray_payload
    mov     esi, VP8_TEST_GRAY_PAYLOAD_LEN
    mov     rdx, gray_yuv
    mov     ecx, VP8_TEST_GRAY_YUV_BYTES
    mov     r8, gray_rgba
    mov     r9d, 4
    call    er_vp8_decode_key_frame
    cmp     eax, 4
    jne     .fail_decode_gray_payload
    test    edx, edx
    jnz     .fail_decode_gray_payload
    cmp     dword [rel gray_rgba], 0xff7e7e7e
    jne     .fail_decode_gray_payload
    cmp     dword [rel gray_rgba + 12], 0xff7e7e7e
    jne     .fail_decode_gray_payload
    inc     qword [rel passed]
    jmp     .decode_inter_reference_payload
.fail_decode_gray_payload:
    inc     qword [rel failed]

.decode_inter_reference_payload:
    mov     rdi, inter_decode_frame
    mov     esi, VP8_TEST_INTER_DECODE_LEN
    xor     edx, edx
    call    er_vp8_memset
    mov     rdi, inter_decode_frame
    mov     esi, VP8_FRAME_TAG_SIZE
    mov     edx, VP8_TEST_INTER_DECODE_FIRST_LEN
    call    er_vp8_write_visible_inter_frame_tag
    mov     rdi, inter_decode_frame
    mov     esi, VP8_TEST_INTER_DECODE_LEN
    mov     edx, 2
    mov     ecx, 2
    mov     r8, gray_yuv
    mov     r9, wide_gray_yuv
    push    4
    push    gray_rgba
    push    VP8_TEST_GRAY_YUV_BYTES
    call    er_vp8_decode_frame_with_reference
    add     rsp, 24
    cmp     eax, 4
    jne     .fail_decode_inter_reference_payload
    test    edx, edx
    jnz     .fail_decode_inter_reference_payload
    inc     qword [rel passed]
    jmp     .decode_wide_gray_payload
.fail_decode_inter_reference_payload:
    inc     qword [rel failed]

.decode_wide_gray_payload:
    mov     rdi, vp8_wide_gray_payload
    mov     esi, VP8_TEST_WIDE_GRAY_PAYLOAD_LEN
    mov     rdx, wide_gray_yuv
    mov     ecx, VP8_TEST_WIDE_GRAY_YUV_BYTES
    mov     r8, wide_gray_rgba
    mov     r9d, VP8_TEST_WIDE_GRAY_PIXELS
    call    er_vp8_decode_key_frame
    cmp     eax, VP8_TEST_WIDE_GRAY_PIXELS
    jne     .fail_decode_wide_gray_payload
    test    edx, edx
    jnz     .fail_decode_wide_gray_payload
    cmp     dword [rel wide_gray_rgba], 0xff7e7e7e
    jne     .fail_decode_wide_gray_payload
    cmp     dword [rel wide_gray_rgba + 16 * 4], 0xff7e7e7e
    jne     .fail_decode_wide_gray_payload
    cmp     dword [rel wide_gray_rgba + (VP8_TEST_WIDE_GRAY_PIXELS - 1) * 4], 0xff7e7e7e
    jne     .fail_decode_wide_gray_payload
    inc     qword [rel passed]
    jmp     .bad_payload
.fail_decode_wide_gray_payload:
    inc     qword [rel failed]

.bad_payload:
    mov     rdi, payload_empty
    mov     esi, VP8_TEST_PAYLOAD_EMPTY_LEN
    mov     rdx, key_payload
    call    er_vp8_parse_key_frame_payload
    test    eax, eax
    jnz     .fail_bad_payload
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_payload
    mov     rdi, payload_short
    mov     esi, VP8_TEST_PAYLOAD_SHORT_LEN
    mov     rdx, key_payload
    call    er_vp8_parse_key_frame_payload
    test    eax, eax
    jnz     .fail_bad_payload
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_payload
    inc     qword [rel passed]
    jmp     .bool_init
.fail_bad_payload:
    inc     qword [rel failed]

.bool_init:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    cmp     eax, VP8_BOOL_READER_SIZE
    jne     .fail_bool_init
    test    edx, edx
    jnz     .fail_bool_init
    cmp     qword [rel bool_reader + VP8_BOOL_READER_BUF], bool_zero
    jne     .fail_bool_init
    cmp     dword [rel bool_reader + VP8_BOOL_READER_LEN], 3
    jne     .fail_bool_init
    cmp     dword [rel bool_reader + VP8_BOOL_READER_INPUT_INDEX], VP8_BOOL_INITIAL_BYTES
    jne     .fail_bool_init
    cmp     dword [rel bool_reader + VP8_BOOL_READER_RANGE], VP8_BOOL_RANGE_INIT
    jne     .fail_bool_init
    cmp     dword [rel bool_reader + VP8_BOOL_READER_VALUE], 0
    jne     .fail_bool_init
    cmp     dword [rel bool_reader + VP8_BOOL_READER_BIT_COUNT], 0
    jne     .fail_bool_init
    inc     qword [rel passed]
    jmp     .bool_init_short
.fail_bool_init:
    inc     qword [rel failed]

.bool_init_short:
    mov     rdi, bool_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES - 1
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    test    eax, eax
    jnz     .fail_bool_init_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_bool_init_short
    inc     qword [rel passed]
    jmp     .bool_read_zero
.fail_bool_init_short:
    inc     qword [rel failed]

.bool_read_zero:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_bool_read_flag
    test    eax, eax
    jnz     .fail_bool_read_zero
    test    edx, edx
    jnz     .fail_bool_read_zero
    cmp     dword [rel bool_reader + VP8_BOOL_READER_RANGE], VP8_BOOL_RANGE_RENORM_MIN
    jne     .fail_bool_read_zero
    cmp     dword [rel bool_reader + VP8_BOOL_READER_VALUE], 0
    jne     .fail_bool_read_zero
    cmp     dword [rel bool_reader + VP8_BOOL_READER_BIT_COUNT], 0
    jne     .fail_bool_read_zero
    inc     qword [rel passed]
    jmp     .bool_read_one
.fail_bool_read_zero:
    inc     qword [rel failed]

.bool_read_one:
    mov     rdi, bool_ones
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_bool_read_flag
    cmp     eax, 1
    jne     .fail_bool_read_one
    test    edx, edx
    jnz     .fail_bool_read_one
    cmp     dword [rel bool_reader + VP8_BOOL_READER_RANGE], VP8_BOOL_RANGE_INIT - 1
    jne     .fail_bool_read_one
    cmp     dword [rel bool_reader + VP8_BOOL_READER_VALUE], 0xfffe
    jne     .fail_bool_read_one
    cmp     dword [rel bool_reader + VP8_BOOL_READER_BIT_COUNT], 1
    jne     .fail_bool_read_one
    inc     qword [rel passed]
    jmp     .bool_read_probability
.fail_bool_read_one:
    inc     qword [rel failed]

.bool_read_probability:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, VP8_BOOL_PROBABILITY_MAX
    call    er_vp8_bool_read
    test    eax, eax
    jnz     .fail_bool_read_probability
    test    edx, edx
    jnz     .fail_bool_read_probability
    cmp     dword [rel bool_reader + VP8_BOOL_READER_RANGE], VP8_BOOL_RANGE_INIT - 1
    jne     .fail_bool_read_probability
    inc     qword [rel passed]
    jmp     .bool_literal_zero
.fail_bool_read_probability:
    inc     qword [rel failed]

.bool_literal_zero:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 5
    call    er_vp8_bool_read_literal
    test    eax, eax
    jnz     .fail_bool_literal_zero
    test    edx, edx
    jnz     .fail_bool_literal_zero
    inc     qword [rel passed]
    jmp     .bool_literal_pattern
.fail_bool_literal_zero:
    inc     qword [rel failed]

.bool_literal_pattern:
    mov     rdi, bool_lit
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 4
    call    er_vp8_bool_read_literal
    cmp     eax, 10
    jne     .fail_bool_literal_pattern
    test    edx, edx
    jnz     .fail_bool_literal_pattern
    inc     qword [rel passed]
    jmp     .bool_literal_range
.fail_bool_literal_pattern:
    inc     qword [rel failed]

.bool_literal_range:
    mov     rdi, bool_reader
    mov     esi, VP8_BOOL_LITERAL_BITS_MAX + 1
    call    er_vp8_bool_read_literal
    test    eax, eax
    jnz     .fail_bool_literal_range
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_bool_literal_range
    inc     qword [rel passed]
    jmp     .token_partitions
.fail_bool_literal_range:
    inc     qword [rel failed]

.token_partitions:
    mov     rdi, token_parts
    mov     esi, 8
    mov     edx, 2
    mov     rcx, partitions
    call    er_vp8_parse_token_partitions
    cmp     eax, 2
    jne     .fail_token_partitions
    test    edx, edx
    jnz     .fail_token_partitions
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_COUNT], 2
    jne     .fail_token_partitions
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_TABLE + VP8_TOKEN_PARTITION_OFFSET], 3
    jne     .fail_token_partitions
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_TABLE + VP8_TOKEN_PARTITION_LEN], 3
    jne     .fail_token_partitions
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_TABLE + VP8_TOKEN_PARTITION_ENTRY_SIZE + VP8_TOKEN_PARTITION_OFFSET], 6
    jne     .fail_token_partitions
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_TABLE + VP8_TOKEN_PARTITION_ENTRY_SIZE + VP8_TOKEN_PARTITION_LEN], 2
    jne     .fail_token_partitions
    inc     qword [rel passed]
    jmp     .token_partition_single
.fail_token_partitions:
    inc     qword [rel failed]

.token_partition_single:
    mov     rdi, token_parts
    mov     esi, 8
    mov     edx, 1
    mov     rcx, partitions
    call    er_vp8_parse_token_partitions
    cmp     eax, 1
    jne     .fail_token_partition_single
    test    edx, edx
    jnz     .fail_token_partition_single
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_TABLE + VP8_TOKEN_PARTITION_OFFSET], 0
    jne     .fail_token_partition_single
    cmp     dword [rel partitions + VP8_TOKEN_PARTITIONS_TABLE + VP8_TOKEN_PARTITION_LEN], 8
    jne     .fail_token_partition_single
    inc     qword [rel passed]
    jmp     .token_partition_reject_count
.fail_token_partition_single:
    inc     qword [rel failed]

.token_partition_reject_count:
    mov     rdi, token_parts
    mov     esi, 8
    xor     edx, edx
    mov     rcx, partitions
    call    er_vp8_parse_token_partitions
    test    eax, eax
    jnz     .fail_token_partition_reject_count
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_token_partition_reject_count
    inc     qword [rel passed]
    jmp     .token_partition_reject_short
.fail_token_partition_reject_count:
    inc     qword [rel failed]

.token_partition_reject_short:
    mov     rdi, token_parts
    mov     esi, 2
    mov     edx, 2
    mov     rcx, partitions
    call    er_vp8_parse_token_partitions
    test    eax, eax
    jnz     .fail_token_partition_reject_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_token_partition_reject_short
    inc     qword [rel passed]
    jmp     .token_partition_reject_oversize
.fail_token_partition_reject_short:
    inc     qword [rel failed]

.token_partition_reject_oversize:
    mov     rdi, token_parts_bad
    mov     esi, 4
    mov     edx, 2
    mov     rcx, partitions
    call    er_vp8_parse_token_partitions
    test    eax, eax
    jnz     .fail_token_partition_reject_oversize
    cmp     edx, ERROR_CORRUPT
    jne     .fail_token_partition_reject_oversize
    inc     qword [rel passed]
    jmp     .token_partition_count
.fail_token_partition_reject_oversize:
    inc     qword [rel failed]

.token_partition_count:
    mov     edi, 0
    call    er_vp8_token_partition_count
    cmp     eax, 1
    jne     .fail_token_partition_count
    test    edx, edx
    jnz     .fail_token_partition_count
    mov     edi, 3
    call    er_vp8_token_partition_count
    cmp     eax, VP8_TOKEN_PARTITION_COUNT_MAX
    jne     .fail_token_partition_count
    test    edx, edx
    jnz     .fail_token_partition_count
    mov     edi, 4
    call    er_vp8_token_partition_count
    test    eax, eax
    jnz     .fail_token_partition_count
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_token_partition_count
    inc     qword [rel passed]
    jmp     .mv_probability
.fail_token_partition_count:
    inc     qword [rel failed]

.mv_probability:
    mov     edi, 0
    call    er_vp8_updated_motion_vector_probability
    cmp     eax, VP8_MOTION_VECTOR_UPDATE_ZERO
    jne     .fail_mv_probability
    test    edx, edx
    jnz     .fail_mv_probability
    mov     edi, 1
    call    er_vp8_updated_motion_vector_probability
    cmp     eax, 2
    jne     .fail_mv_probability
    test    edx, edx
    jnz     .fail_mv_probability
    mov     edi, 127
    call    er_vp8_updated_motion_vector_probability
    cmp     eax, 254
    jne     .fail_mv_probability
    test    edx, edx
    jnz     .fail_mv_probability
    inc     qword [rel passed]
    jmp     .signed_literal_positive
.fail_mv_probability:
    inc     qword [rel failed]

.signed_literal_positive:
    mov     rdi, bool_lit
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 3
    call    er_vp8_bool_read_signed_literal
    cmp     eax, 5
    jne     .fail_signed_literal_positive
    test    edx, edx
    jnz     .fail_signed_literal_positive
    inc     qword [rel passed]
    jmp     .signed_literal_negative
.fail_signed_literal_positive:
    inc     qword [rel failed]

.signed_literal_negative:
    mov     rdi, bool_neg
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 3
    call    er_vp8_bool_read_signed_literal
    cmp     eax, -5
    jne     .fail_signed_literal_negative
    test    edx, edx
    jnz     .fail_signed_literal_negative
    inc     qword [rel passed]
    jmp     .optional_signed_zero
.fail_signed_literal_negative:
    inc     qword [rel failed]

.optional_signed_zero:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, VP8_QUANT_DELTA_BITS
    call    er_vp8_bool_read_optional_signed_literal
    test    eax, eax
    jnz     .fail_optional_signed_zero
    test    edx, edx
    jnz     .fail_optional_signed_zero
    inc     qword [rel passed]
    jmp     .quant_zero
.fail_optional_signed_zero:
    inc     qword [rel failed]

.quant_zero:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, quant
    call    er_vp8_parse_quant_indices
    cmp     eax, VP8_QUANT_SIZE
    jne     .fail_quant_zero
    test    edx, edx
    jnz     .fail_quant_zero
    cmp     byte [rel quant + VP8_QUANT_Y_AC], 0
    jne     .fail_quant_zero
    cmp     byte [rel quant + VP8_QUANT_Y_DC_DELTA], 0
    jne     .fail_quant_zero
    cmp     byte [rel quant + VP8_QUANT_UV_AC_DELTA], 0
    jne     .fail_quant_zero
    inc     qword [rel passed]
    jmp     .quant_index
.fail_quant_zero:
    inc     qword [rel failed]

.quant_index:
    mov     edi, 10
    mov     esi, -20
    call    er_vp8_quant_index
    test    eax, eax
    jnz     .fail_quant_index
    test    edx, edx
    jnz     .fail_quant_index
    mov     edi, 10
    mov     esi, 5
    call    er_vp8_quant_index
    cmp     eax, 15
    jne     .fail_quant_index
    test    edx, edx
    jnz     .fail_quant_index
    mov     edi, VP8_QUANT_INDEX_MAX
    mov     esi, 10
    call    er_vp8_quant_index
    cmp     eax, VP8_QUANT_INDEX_MAX
    jne     .fail_quant_index
    test    edx, edx
    jnz     .fail_quant_index
    mov     edi, 10
    mov     esi, -20
    xor     edx, edx
    call    er_vp8_segment_quant_base
    test    eax, eax
    jnz     .fail_quant_index
    test    edx, edx
    jnz     .fail_quant_index
    mov     edi, 10
    mov     esi, -3
    mov     edx, 1
    call    er_vp8_segment_quant_base
    test    eax, eax
    jnz     .fail_quant_index
    test    edx, edx
    jnz     .fail_quant_index
    mov     edi, 10
    mov     esi, 7
    mov     edx, 1
    call    er_vp8_segment_quant_base
    cmp     eax, 7
    jne     .fail_quant_index
    test    edx, edx
    jnz     .fail_quant_index
    inc     qword [rel passed]
    jmp     .quant_tables
.fail_quant_index:
    inc     qword [rel failed]

.quant_tables:
    xor     edi, edi
    call    er_vp8_dc_quant
    cmp     eax, 4
    jne     .fail_quant_tables
    test    edx, edx
    jnz     .fail_quant_tables
    mov     edi, VP8_QUANT_INDEX_MAX
    call    er_vp8_ac_quant
    cmp     eax, 284
    jne     .fail_quant_tables
    test    edx, edx
    jnz     .fail_quant_tables
    mov     edi, VP8_QUANT_INDEX_MAX + 1
    call    er_vp8_dc_quant
    test    eax, eax
    jnz     .fail_quant_tables
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_quant_tables
    inc     qword [rel passed]
    jmp     .dequant_build
.fail_quant_tables:
    inc     qword [rel failed]

.dequant_build:
    mov     byte [rel quant + VP8_QUANT_Y_AC], 10
    mov     byte [rel quant + VP8_QUANT_Y_DC_DELTA], 1
    mov     byte [rel quant + VP8_QUANT_Y2_DC_DELTA], 2
    mov     byte [rel quant + VP8_QUANT_Y2_AC_DELTA], 3
    mov     byte [rel quant + VP8_QUANT_UV_DC_DELTA], -1
    mov     byte [rel quant + VP8_QUANT_UV_AC_DELTA], -2
    mov     byte [rel segment_desc + VP8_SEGMENT_QUANT_ABSOLUTE], 0
    mov     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS], 0
    mov     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS + 1], 5
    mov     rdi, quant
    mov     rsi, segment_desc
    mov     edx, 1
    mov     rcx, dequant
    call    er_vp8_build_dequant
    cmp     eax, VP8_DEQUANT_SIZE
    jne     .fail_dequant_build
    test    edx, edx
    jnz     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_Y_DC], 18
    jne     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_Y_AC], 19
    jne     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_Y2_DC], 38
    jne     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_Y2_AC], 34
    jne     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_UV_DC], 17
    jne     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_UV_AC], 17
    jne     .fail_dequant_build
    mov     byte [rel segment_desc + VP8_SEGMENT_QUANT_ABSOLUTE], 1
    mov     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS + 2], 7
    mov     rdi, quant
    mov     rsi, segment_desc
    mov     edx, 2
    mov     rcx, dequant
    call    er_vp8_build_dequant
    test    edx, edx
    jnz     .fail_dequant_build
    cmp     word [rel dequant + VP8_DEQUANT_Y_AC], 11
    jne     .fail_dequant_build
    inc     qword [rel passed]
    jmp     .segment_default
.fail_dequant_build:
    inc     qword [rel failed]

.segment_default:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, segment_desc
    call    er_vp8_parse_segmentation_header
    cmp     eax, VP8_SEGMENT_HEADER_SIZE
    jne     .fail_segment_default
    test    edx, edx
    jnz     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_UPDATE_MAP], 0
    jne     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_ABSOLUTE], 0
    jne     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_PROBABILITIES], VP8_SEGMENT_PROB_DEFAULT
    jne     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_PROBABILITIES + 1], VP8_SEGMENT_PROB_DEFAULT
    jne     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_PROBABILITIES + 2], VP8_SEGMENT_PROB_DEFAULT
    jne     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS], 0
    jne     .fail_segment_default
    cmp     byte [rel segment_desc + VP8_SEGMENT_LOOP_FILTER_DELTAS], 0
    jne     .fail_segment_default
    inc     qword [rel passed]
    jmp     .segment_full
.fail_segment_default:
    inc     qword [rel failed]

.segment_full:
    mov     rdi, segment_full
    mov     esi, 8
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, segment_desc
    call    er_vp8_parse_segmentation_header
    cmp     eax, VP8_SEGMENT_HEADER_SIZE
    jne     .fail_segment_full
    test    edx, edx
    jnz     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_UPDATE_MAP], 1
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_ABSOLUTE], 0
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_PROBABILITIES], VP8_SEGMENT_PROB_DEFAULT
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_PROBABILITIES + 1], 227
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_PROBABILITIES + 2], 143
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS], 15
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS + 1], 0
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS + 2], 0
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_QUANT_DELTAS + 3], 0x8f
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_LOOP_FILTER_DELTAS], 0xdd
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_LOOP_FILTER_DELTAS + 1], 0xf9
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_LOOP_FILTER_DELTAS + 2], 0
    jne     .fail_segment_full
    cmp     byte [rel segment_desc + VP8_SEGMENT_LOOP_FILTER_DELTAS + 3], 0
    jne     .fail_segment_full
    inc     qword [rel passed]
    jmp     .loop_filter_default
.fail_segment_full:
    inc     qword [rel failed]

.loop_filter_default:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, loop_filter
    call    er_vp8_parse_loop_filter_header
    cmp     eax, VP8_LOOP_FILTER_HEADER_SIZE
    jne     .fail_loop_filter_default
    test    edx, edx
    jnz     .fail_loop_filter_default
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_TYPE], 0
    jne     .fail_loop_filter_default
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_LEVEL], 0
    jne     .fail_loop_filter_default
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_SHARPNESS], 0
    jne     .fail_loop_filter_default
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_DELTA_ENABLED], 0
    jne     .fail_loop_filter_default
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_REF_DELTAS], 0
    jne     .fail_loop_filter_default
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_MODE_DELTAS], 0
    jne     .fail_loop_filter_default
    inc     qword [rel passed]
    jmp     .loop_filter_full
.fail_loop_filter_default:
    inc     qword [rel failed]

.loop_filter_full:
    mov     rdi, loop_filter_full
    mov     esi, 8
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, loop_filter
    call    er_vp8_parse_loop_filter_header
    cmp     eax, VP8_LOOP_FILTER_HEADER_SIZE
    jne     .fail_loop_filter_full
    test    edx, edx
    jnz     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_TYPE], 1
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_LEVEL], 60
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_SHARPNESS], 3
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_DELTA_ENABLED], 1
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_REF_DELTAS], 0
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_REF_DELTAS + 1], 0
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_REF_DELTAS + 2], 0
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_REF_DELTAS + 3], 0xc8
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_MODE_DELTAS], 0xcf
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_MODE_DELTAS + 1], 0xdd
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_MODE_DELTAS + 2], 0xf9
    jne     .fail_loop_filter_full
    cmp     byte [rel loop_filter + VP8_LOOP_FILTER_MODE_DELTAS + 3], 0
    jne     .fail_loop_filter_full
    inc     qword [rel passed]
    jmp     .loop_filter_parameters_disabled
.fail_loop_filter_full:
    inc     qword [rel failed]

.loop_filter_parameters_disabled:
    mov     rdi, compressed_header
    xor     esi, esi
    mov     edx, VP8_COMPRESSED_HEADER_SIZE
    call    er_vp8_memset
    mov     rdi, macroblock_header
    xor     esi, esi
    mov     edx, VP8_MACROBLOCK_HEADER_SIZE
    call    er_vp8_memset
    mov     rdi, loop_filter_params
    mov     esi, 0xaa
    mov     edx, VP8_LOOP_FILTER_PARAM_SIZE
    call    er_vp8_memset
    mov     rdi, compressed_header
    mov     rsi, macroblock_header
    mov     edx, VP8_FRAME_TYPE_KEY
    mov     rcx, loop_filter_params
    call    er_vp8_loop_filter_parameters
    test    eax, eax
    jnz     .fail_loop_filter_parameters_disabled
    test    edx, edx
    jnz     .fail_loop_filter_parameters_disabled
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_EDGE_LIMIT], 0
    jne     .fail_loop_filter_parameters_disabled
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_INTERIOR_LIMIT], 0
    jne     .fail_loop_filter_parameters_disabled
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_HEV_THRESHOLD], 0
    jne     .fail_loop_filter_parameters_disabled
    inc     qword [rel passed]
    jmp     .loop_filter_parameters_key
.fail_loop_filter_parameters_disabled:
    inc     qword [rel failed]

.loop_filter_parameters_key:
    mov     rdi, compressed_header
    xor     esi, esi
    mov     edx, VP8_COMPRESSED_HEADER_SIZE
    call    er_vp8_memset
    mov     rdi, macroblock_header
    xor     esi, esi
    mov     edx, VP8_MACROBLOCK_HEADER_SIZE
    call    er_vp8_memset
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_LEVEL], 20
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_PREDICTION], VP8_MACROBLOCK_PREDICTION_INTRA
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_LUMA_MODE], VP8_LUMA_MODE_DC
    mov     rdi, compressed_header
    mov     rsi, macroblock_header
    mov     edx, VP8_FRAME_TYPE_KEY
    mov     rcx, loop_filter_params
    call    er_vp8_loop_filter_parameters
    cmp     eax, 1
    jne     .fail_loop_filter_parameters_key
    test    edx, edx
    jnz     .fail_loop_filter_parameters_key
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_EDGE_LIMIT], 20
    jne     .fail_loop_filter_parameters_key
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_INTERIOR_LIMIT], 20
    jne     .fail_loop_filter_parameters_key
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_HEV_THRESHOLD], 1
    jne     .fail_loop_filter_parameters_key
    inc     qword [rel passed]
    jmp     .loop_filter_parameters_delta
.fail_loop_filter_parameters_key:
    inc     qword [rel failed]

.loop_filter_parameters_delta:
    mov     rdi, compressed_header
    xor     esi, esi
    mov     edx, VP8_COMPRESSED_HEADER_SIZE
    call    er_vp8_memset
    mov     rdi, macroblock_header
    xor     esi, esi
    mov     edx, VP8_MACROBLOCK_HEADER_SIZE
    call    er_vp8_memset
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_LEVEL], 30
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_SHARPNESS], 5
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_DELTA_ENABLED], 1
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_LOOP_FILTER_DELTAS + 2], 4
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_REF_DELTAS + VP8_LOOP_FILTER_REF_GOLDEN], 3
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_MODE_DELTAS + VP8_LOOP_FILTER_MODE_NEW], 0xf6
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_SEGMENT_ID], 2
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_PREDICTION], VP8_MACROBLOCK_PREDICTION_INTER_MOTION
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_REFERENCE], VP8_REFERENCE_NAME_GOLDEN
    mov     rdi, compressed_header
    mov     rsi, macroblock_header
    mov     edx, VP8_FRAME_TYPE_INTER
    mov     rcx, loop_filter_params
    call    er_vp8_loop_filter_parameters
    cmp     eax, 1
    jne     .fail_loop_filter_parameters_delta
    test    edx, edx
    jnz     .fail_loop_filter_parameters_delta
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_EDGE_LIMIT], 27
    jne     .fail_loop_filter_parameters_delta
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_INTERIOR_LIMIT], 4
    jne     .fail_loop_filter_parameters_delta
    cmp     byte [rel loop_filter_params + VP8_LOOP_FILTER_PARAM_HEV_THRESHOLD], 2
    jne     .fail_loop_filter_parameters_delta
    inc     qword [rel passed]
    jmp     .compressed_key_header
.fail_loop_filter_parameters_delta:
    inc     qword [rel failed]

.compressed_key_header:
    mov     rdi, first_partition_zero
    mov     esi, VP8_TEST_KEY_FIRST_PARTITION_LEN
    mov     rdx, token_probabilities
    mov     rcx, compressed_header
    call    er_vp8_parse_compressed_key_frame_header
    cmp     eax, VP8_COMPRESSED_HEADER_SIZE
    jne     .fail_compressed_key_header
    test    edx, edx
    jnz     .fail_compressed_key_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_TOKEN_COUNT], 1
    jne     .fail_compressed_key_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_QUANT + VP8_QUANT_Y_AC], 0
    jne     .fail_compressed_key_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_QUANT + VP8_QUANT_Y_DC_DELTA], 0
    jne     .fail_compressed_key_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_REFRESH_ENTROPY], 0
    jne     .fail_compressed_key_header
    cmp     dword [rel compressed_header + VP8_COMPRESSED_HEADER_TOKEN_UPDATES], 0
    jne     .fail_compressed_key_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_USE_SKIP], 0
    jne     .fail_compressed_key_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_SKIP_PROB], 0
    jne     .fail_compressed_key_header
    cmp     byte [rel token_probabilities], 128
    jne     .fail_compressed_key_header
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, compressed_header
    call    er_vp8_bool_reader_init
    cmp     eax, VP8_BOOL_READER_SIZE
    jne     .fail_compressed_key_header
    test    edx, edx
    jnz     .fail_compressed_key_header
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_UPDATE_MAP], 0
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_USE_SKIP], 0
    mov     rdi, top_modes
    mov     esi, VP8_INTRA4_MODE_DC
    mov     edx, VP8_MAX_LUMA_TOKEN_COLUMNS
    call    er_vp8_memset
    mov     rdi, left_modes
    mov     esi, VP8_INTRA4_MODE_DC
    mov     edx, VP8_BLOCK_SIZE
    call    er_vp8_memset
    mov     rdi, compressed_header
    xor     esi, esi
    mov     rdx, top_modes
    mov     rcx, left_modes
    mov     r8, macroblock_header
    call    er_vp8_read_key_macroblock_header
    cmp     eax, VP8_MACROBLOCK_HEADER_SIZE
    jne     .fail_compressed_key_header
    test    edx, edx
    jnz     .fail_compressed_key_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_SKIP], 0
    jne     .fail_compressed_key_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_LUMA_MODE], VP8_LUMA_MODE_TRUE_MOTION
    jne     .fail_compressed_key_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_CHROMA_MODE], VP8_CHROMA_MODE_TRUE_MOTION
    jne     .fail_compressed_key_header
    inc     qword [rel passed]
    jmp     .compressed_inter_header
.fail_compressed_key_header:
    inc     qword [rel failed]

.compressed_inter_header:
    mov     rdi, first_partition_zero
    mov     esi, VP8_TEST_KEY_FIRST_PARTITION_LEN
    mov     rdx, token_probabilities
    mov     rcx, compressed_header
    call    er_vp8_parse_compressed_inter_frame_header
    cmp     eax, VP8_COMPRESSED_HEADER_SIZE
    jne     .fail_compressed_inter_header
    test    edx, edx
    jnz     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_TOKEN_COUNT], 1
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_REFERENCE + VP8_REFERENCE_REFRESH_LAST], 0
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_REFERENCE + VP8_REFERENCE_REFRESH_GOLDEN], 0
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_REFERENCE + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_REFRESH_ENTROPY], 0
    jne     .fail_compressed_inter_header
    cmp     dword [rel compressed_header + VP8_COMPRESSED_HEADER_TOKEN_UPDATES], 0
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_USE_SKIP], 0
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_PROB_INTRA], 0
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_INTRA16_PROBS], 112
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_INTRA16_PROBS + 3], 37
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_CHROMA_PROBS], 162
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_CHROMA_PROBS + 2], 204
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_MV_PROBS], 162
    jne     .fail_compressed_inter_header
    cmp     byte [rel compressed_header + VP8_COMPRESSED_HEADER_MV_PROBS + VP8_MV_PROBABILITY_COUNT], 164
    jne     .fail_compressed_inter_header
    cmp     byte [rel token_probabilities], 128
    jne     .fail_compressed_inter_header
    inc     qword [rel passed]
    jmp     .inter_macroblock_header
.fail_compressed_inter_header:
    inc     qword [rel failed]

.inter_macroblock_header:
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, compressed_header
    call    er_vp8_bool_reader_init
    cmp     eax, VP8_BOOL_READER_SIZE
    jne     .fail_inter_macroblock_header
    test    edx, edx
    jnz     .fail_inter_macroblock_header
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_UPDATE_MAP], 0
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_USE_SKIP], 0
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_PROB_INTRA], 128
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_PROB_LAST], 128
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_PROB_GOLDEN], 128
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_INTRA16_PROBS], 112
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_INTRA16_PROBS + 1], 86
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_INTRA16_PROBS + 2], 140
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_INTRA16_PROBS + 3], 37
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_CHROMA_PROBS], 162
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_CHROMA_PROBS + 1], 101
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_CHROMA_PROBS + 2], 204
    mov     rdi, compressed_header
    xor     esi, esi
    mov     rdx, top_modes
    mov     rcx, left_modes
    mov     r8, macroblock_header
    call    er_vp8_read_inter_macroblock_header
    cmp     eax, VP8_MACROBLOCK_HEADER_SIZE
    jne     .fail_inter_macroblock_header
    test    edx, edx
    jnz     .fail_inter_macroblock_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_REFERENCE], VP8_REFERENCE_NAME_ALTERNATE
    jne     .fail_inter_macroblock_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_PREDICTION], VP8_MACROBLOCK_PREDICTION_INTER_SPLIT
    jne     .fail_inter_macroblock_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_LUMA_MODE], VP8_LUMA_MODE_DC
    jne     .fail_inter_macroblock_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_CHROMA_MODE], VP8_CHROMA_MODE_DC
    jne     .fail_inter_macroblock_header
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, compressed_header
    call    er_vp8_bool_reader_init
    cmp     eax, VP8_BOOL_READER_SIZE
    jne     .fail_inter_macroblock_header
    test    edx, edx
    jnz     .fail_inter_macroblock_header
    mov     rdi, compressed_header
    xor     esi, esi
    mov     rdx, top_modes
    mov     rcx, left_modes
    mov     r8, macroblock_header
    call    er_vp8_read_inter_macroblock_header
    cmp     eax, VP8_MACROBLOCK_HEADER_SIZE
    jne     .fail_inter_macroblock_header
    test    edx, edx
    jnz     .fail_inter_macroblock_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_PREDICTION], VP8_MACROBLOCK_PREDICTION_INTRA
    jne     .fail_inter_macroblock_header
    inc     qword [rel passed]
    jmp     .key_bpred_header
.fail_inter_macroblock_header:
    inc     qword [rel failed]

.key_bpred_header:
    mov     rdi, mode_bpred_dc
    mov     esi, 6
    mov     rdx, compressed_header
    call    er_vp8_bool_reader_init
    cmp     eax, VP8_BOOL_READER_SIZE
    jne     .fail_key_bpred_header
    test    edx, edx
    jnz     .fail_key_bpred_header
    mov     rdi, top_modes
    mov     esi, VP8_INTRA4_MODE_DC
    mov     edx, VP8_MAX_LUMA_TOKEN_COLUMNS
    call    er_vp8_memset
    mov     rdi, left_modes
    mov     esi, VP8_INTRA4_MODE_DC
    mov     edx, VP8_BLOCK_SIZE
    call    er_vp8_memset
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_UPDATE_MAP], 0
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_USE_SKIP], 0
    mov     rdi, compressed_header
    xor     esi, esi
    mov     rdx, top_modes
    mov     rcx, left_modes
    mov     r8, macroblock_header
    call    er_vp8_read_key_macroblock_header
    cmp     eax, VP8_MACROBLOCK_HEADER_SIZE
    jne     .fail_key_bpred_header
    test    edx, edx
    jnz     .fail_key_bpred_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_LUMA_MODE], VP8_LUMA_MODE_B_PRED
    jne     .fail_key_bpred_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_CHROMA_MODE], VP8_CHROMA_MODE_DC
    jne     .fail_key_bpred_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_INTRA4_MODES], VP8_INTRA4_MODE_DC
    jne     .fail_key_bpred_header
    cmp     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_INTRA4_MODES + VP8_Y_BLOCK_COUNT - 1], VP8_INTRA4_MODE_DC
    jne     .fail_key_bpred_header
    cmp     byte [rel top_modes], VP8_INTRA4_MODE_DC
    jne     .fail_key_bpred_header
    cmp     byte [rel left_modes + VP8_BLOCK_SIZE - 1], VP8_INTRA4_MODE_DC
    jne     .fail_key_bpred_header
    inc     qword [rel passed]
    jmp     .luma_mode_to_intra4
.fail_key_bpred_header:
    inc     qword [rel failed]

.luma_mode_to_intra4:
    mov     edi, VP8_LUMA_MODE_VERTICAL
    call    er_vp8_luma_mode_intra4_mode
    cmp     eax, VP8_INTRA4_MODE_VERTICAL
    jne     .fail_luma_mode_to_intra4
    test    edx, edx
    jnz     .fail_luma_mode_to_intra4
    mov     edi, VP8_LUMA_MODE_HORIZONTAL
    call    er_vp8_luma_mode_intra4_mode
    cmp     eax, VP8_INTRA4_MODE_HORIZONTAL
    jne     .fail_luma_mode_to_intra4
    test    edx, edx
    jnz     .fail_luma_mode_to_intra4
    inc     qword [rel passed]
    jmp     .reference_zero
.fail_luma_mode_to_intra4:
    inc     qword [rel failed]

.reference_zero:
    mov     rdi, reference_zero
    mov     esi, 4
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, reference
    call    er_vp8_parse_inter_reference_header
    cmp     eax, VP8_REFERENCE_HEADER_SIZE
    jne     .fail_reference_zero
    test    edx, edx
    jnz     .fail_reference_zero
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_GOLDEN], 0
    jne     .fail_reference_zero
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    jne     .fail_reference_zero
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_GOLDEN], VP8_REFERENCE_COPY_NONE
    jne     .fail_reference_zero
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_ALTERNATE], VP8_REFERENCE_COPY_NONE
    jne     .fail_reference_zero
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_ENTROPY], 0
    jne     .fail_reference_zero
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_LAST], 0
    jne     .fail_reference_zero
    inc     qword [rel passed]
    jmp     .reference_full
.fail_reference_zero:
    inc     qword [rel failed]

.reference_full:
    mov     rdi, reference_full
    mov     esi, 4
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, reference
    call    er_vp8_parse_inter_reference_header
    cmp     eax, VP8_REFERENCE_HEADER_SIZE
    jne     .fail_reference_full
    test    edx, edx
    jnz     .fail_reference_full
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_GOLDEN], 1
    jne     .fail_reference_full
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_ALTERNATE], 1
    jne     .fail_reference_full
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_GOLDEN], VP8_REFERENCE_COPY_NONE
    jne     .fail_reference_full
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_ALTERNATE], VP8_REFERENCE_COPY_NONE
    jne     .fail_reference_full
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_ENTROPY], 1
    jne     .fail_reference_full
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_LAST], 1
    jne     .fail_reference_full
    inc     qword [rel passed]
    jmp     .reference_copy_golden
.fail_reference_full:
    inc     qword [rel failed]

.reference_copy_golden:
    mov     rdi, reference_copy_golden
    mov     esi, 4
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, reference
    call    er_vp8_parse_inter_reference_header
    cmp     eax, VP8_REFERENCE_HEADER_SIZE
    jne     .fail_reference_copy_golden
    test    edx, edx
    jnz     .fail_reference_copy_golden
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_GOLDEN], 0
    jne     .fail_reference_copy_golden
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    jne     .fail_reference_copy_golden
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_GOLDEN], VP8_REFERENCE_COPY_GOLDEN
    jne     .fail_reference_copy_golden
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_ALTERNATE], VP8_REFERENCE_COPY_NONE
    jne     .fail_reference_copy_golden
    inc     qword [rel passed]
    jmp     .reference_copy_alternate
.fail_reference_copy_golden:
    inc     qword [rel failed]

.reference_copy_alternate:
    mov     rdi, reference_copy_alternate_last
    mov     esi, 4
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, reference
    call    er_vp8_parse_inter_reference_header
    cmp     eax, VP8_REFERENCE_HEADER_SIZE
    jne     .fail_reference_copy_alternate
    test    edx, edx
    jnz     .fail_reference_copy_alternate
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_GOLDEN], 1
    jne     .fail_reference_copy_alternate
    cmp     byte [rel reference + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    jne     .fail_reference_copy_alternate
    cmp     byte [rel reference + VP8_REFERENCE_COPY_TO_ALTERNATE], VP8_REFERENCE_COPY_LAST
    jne     .fail_reference_copy_alternate
    inc     qword [rel passed]
    jmp     .reference_apply
.fail_reference_copy_alternate:
    inc     qword [rel failed]

.reference_apply:
    mov     rdi, frame_y
    mov     esi, 0x11
    mov     edx, 16
    call    er_vp8_memset
    mov     rdi, frame_u
    mov     esi, 0x22
    mov     edx, 16
    call    er_vp8_memset
    mov     rdi, frame_v
    mov     esi, 0x33
    mov     edx, 16
    call    er_vp8_memset
    mov     rdi, plane
    mov     esi, 0x44
    mov     edx, 16
    call    er_vp8_memset
    mov     byte [rel reference + VP8_REFERENCE_REFRESH_GOLDEN], 1
    mov     byte [rel reference + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    mov     byte [rel reference + VP8_REFERENCE_COPY_TO_GOLDEN], VP8_REFERENCE_COPY_NONE
    mov     byte [rel reference + VP8_REFERENCE_COPY_TO_ALTERNATE], VP8_REFERENCE_COPY_LAST
    mov     byte [rel reference + VP8_REFERENCE_REFRESH_LAST], 1
    mov     rdi, reference
    mov     rsi, frame_y
    mov     rdx, frame_u
    mov     rcx, frame_v
    mov     r8, plane
    mov     r9d, 16
    call    er_vp8_apply_inter_reference_header
    cmp     eax, 3
    jne     .fail_reference_apply
    test    edx, edx
    jnz     .fail_reference_apply
    cmp     byte [rel frame_v], 0x11
    jne     .fail_reference_apply
    cmp     byte [rel plane], 0x22
    jne     .fail_reference_apply
    cmp     byte [rel frame_u], 0x11
    jne     .fail_reference_apply
    inc     qword [rel passed]
    jmp     .intra16_modes
.fail_reference_apply:
    inc     qword [rel failed]

.intra16_modes:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_intra16_mode
    cmp     eax, VP8_LUMA_MODE_DC
    jne     .fail_intra16_modes
    test    edx, edx
    jnz     .fail_intra16_modes
    mov     rdi, mode_i16_vertical
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_intra16_mode
    cmp     eax, VP8_LUMA_MODE_VERTICAL
    jne     .fail_intra16_modes
    test    edx, edx
    jnz     .fail_intra16_modes
    mov     rdi, mode_i16_horizontal
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_intra16_mode
    cmp     eax, VP8_LUMA_MODE_HORIZONTAL
    jne     .fail_intra16_modes
    test    edx, edx
    jnz     .fail_intra16_modes
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_intra16_mode
    cmp     eax, VP8_LUMA_MODE_TRUE_MOTION
    jne     .fail_intra16_modes
    test    edx, edx
    jnz     .fail_intra16_modes
    inc     qword [rel passed]
    jmp     .chroma_modes
.fail_intra16_modes:
    inc     qword [rel failed]

.chroma_modes:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_chroma_mode
    cmp     eax, VP8_CHROMA_MODE_DC
    jne     .fail_chroma_modes
    test    edx, edx
    jnz     .fail_chroma_modes
    mov     rdi, mode_chroma_vertical
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_chroma_mode
    cmp     eax, VP8_CHROMA_MODE_VERTICAL
    jne     .fail_chroma_modes
    test    edx, edx
    jnz     .fail_chroma_modes
    mov     rdi, mode_chroma_horizontal
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_chroma_mode
    cmp     eax, VP8_CHROMA_MODE_HORIZONTAL
    jne     .fail_chroma_modes
    test    edx, edx
    jnz     .fail_chroma_modes
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_chroma_mode
    cmp     eax, VP8_CHROMA_MODE_TRUE_MOTION
    jne     .fail_chroma_modes
    test    edx, edx
    jnz     .fail_chroma_modes
    inc     qword [rel passed]
    jmp     .inter_intra16_modes
.fail_chroma_modes:
    inc     qword [rel failed]

.inter_intra16_modes:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, inter_intra16_probs
    call    er_vp8_read_inter_intra16_mode
    cmp     eax, VP8_LUMA_MODE_DC
    jne     .fail_inter_intra16_modes
    test    edx, edx
    jnz     .fail_inter_intra16_modes
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, inter_intra16_probs
    call    er_vp8_read_inter_intra16_mode
    cmp     eax, VP8_LUMA_MODE_B_PRED
    jne     .fail_inter_intra16_modes
    test    edx, edx
    jnz     .fail_inter_intra16_modes
    inc     qword [rel passed]
    jmp     .inter_chroma_modes
.fail_inter_intra16_modes:
    inc     qword [rel failed]

.inter_chroma_modes:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, inter_chroma_probs
    call    er_vp8_read_inter_chroma_mode
    cmp     eax, VP8_CHROMA_MODE_DC
    jne     .fail_inter_chroma_modes
    test    edx, edx
    jnz     .fail_inter_chroma_modes
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, inter_chroma_probs
    call    er_vp8_read_inter_chroma_mode
    cmp     eax, VP8_CHROMA_MODE_TRUE_MOTION
    jne     .fail_inter_chroma_modes
    test    edx, edx
    jnz     .fail_inter_chroma_modes
    inc     qword [rel passed]
    jmp     .intra4_modes
.fail_inter_chroma_modes:
    inc     qword [rel failed]

.intra4_modes:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, inter_intra4_probs
    call    er_vp8_read_intra4_mode
    cmp     eax, VP8_INTRA4_MODE_DC
    jne     .fail_intra4_modes
    test    edx, edx
    jnz     .fail_intra4_modes
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, inter_intra4_probs
    call    er_vp8_read_intra4_mode
    cmp     eax, VP8_INTRA4_MODE_HORIZONTAL_UP
    jne     .fail_intra4_modes
    test    edx, edx
    jnz     .fail_intra4_modes
    inc     qword [rel passed]
    jmp     .coeff_category
.fail_intra4_modes:
    inc     qword [rel failed]

.coeff_category:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 0
    call    er_vp8_read_category_coeff_value
    cmp     eax, VP8_COEFF_CAT3_BASE
    jne     .fail_coeff_category
    test    edx, edx
    jnz     .fail_coeff_category
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 3
    call    er_vp8_read_category_coeff_value
    cmp     eax, VP8_COEFF_CAT6_BASE
    jne     .fail_coeff_category
    test    edx, edx
    jnz     .fail_coeff_category
    mov     rdi, bool_ones
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 0
    call    er_vp8_read_category_coeff_value
    cmp     eax, VP8_COEFF_CAT3_BASE + 7
    jne     .fail_coeff_category
    test    edx, edx
    jnz     .fail_coeff_category
    inc     qword [rel passed]
    jmp     .signed_coeff
.fail_coeff_category:
    inc     qword [rel failed]

.signed_coeff:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 2
    call    er_vp8_read_signed_coeff
    cmp     eax, 2
    jne     .fail_signed_coeff
    test    edx, edx
    jnz     .fail_signed_coeff
    mov     rdi, bool_ones
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     esi, 2
    call    er_vp8_read_signed_coeff
    cmp     eax, -2
    jne     .fail_signed_coeff
    test    edx, edx
    jnz     .fail_signed_coeff
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    xor     esi, esi
    call    er_vp8_read_signed_coeff
    test    eax, eax
    jnz     .fail_signed_coeff
    cmp     edx, ERROR_CORRUPT
    jne     .fail_signed_coeff
    inc     qword [rel passed]
    jmp     .macroblock_geometry
.fail_signed_coeff:
    inc     qword [rel failed]

.macroblock_geometry:
    mov     edi, 1
    call    er_vp8_macroblock_dimension
    cmp     eax, 1
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     edi, VP8_MACROBLOCK_SIZE
    call    er_vp8_macroblock_dimension
    cmp     eax, 1
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     edi, VP8_MACROBLOCK_SIZE + 1
    call    er_vp8_macroblock_dimension
    cmp     eax, 2
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    xor     edi, edi
    call    er_vp8_macroblock_dimension
    test    eax, eax
    jnz     .fail_macroblock_geometry
    cmp     edx, ERROR_CORRUPT
    jne     .fail_macroblock_geometry
    mov     edi, 17
    mov     esi, 33
    call    er_vp8_macroblock_count
    cmp     eax, 6
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     edi, VP8_TEST_FRAME_WIDTH
    call    er_vp8_chroma_dimension
    cmp     eax, VP8_TEST_CHROMA_WIDTH
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     rdi, edges
    mov     esi, VP8_MACROBLOCK_SIZE
    call    er_vp8_init_default_edges
    cmp     eax, VP8_EDGES_SIZE_16
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel edges + VP8_EDGES_TOP], VP8_PLANE_EDGE_DEFAULT
    jne     .fail_macroblock_geometry
    cmp     byte [rel edges + VP8_EDGES_LEFT_16], VP8_PLANE_LEFT_DEFAULT
    jne     .fail_macroblock_geometry
    cmp     byte [rel edges + VP8_EDGES_HAS_TOP_16], 0
    jne     .fail_macroblock_geometry
    cmp     byte [rel edges + VP8_EDGES_TOP_RIGHT_16], VP8_PLANE_EDGE_DEFAULT
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.clear_frame_y:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .clear_frame_u_start
    mov     byte [rel frame_y + rcx], 0
    inc     ecx
    jmp     .clear_frame_y
.clear_frame_u_start:
    xor     ecx, ecx
.clear_frame_u:
    cmp     ecx, VP8_TEST_FRAME_UV_BYTES
    jae     .clear_frame_v_start
    mov     byte [rel frame_u + rcx], 0
    inc     ecx
    jmp     .clear_frame_u
.clear_frame_v_start:
    xor     ecx, ecx
.clear_frame_v:
    cmp     ecx, VP8_TEST_FRAME_UV_BYTES
    jae     .fill_write_planes
    mov     byte [rel frame_v + rcx], 0
    inc     ecx
    jmp     .clear_frame_v
.fill_write_planes:
    xor     ecx, ecx
.fill_write_y:
    cmp     ecx, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    jae     .fill_write_u_start
    mov     byte [rel plane + rcx], 77
    inc     ecx
    jmp     .fill_write_y
.fill_write_u_start:
    xor     ecx, ecx
.fill_write_u:
    cmp     ecx, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jae     .fill_write_v_start
    mov     byte [rel u_plane + rcx], 88
    inc     ecx
    jmp     .fill_write_u
.fill_write_v_start:
    xor     ecx, ecx
.fill_write_v:
    cmp     ecx, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jae     .call_luma_write
    mov     byte [rel v_plane + rcx], 99
    inc     ecx
    jmp     .fill_write_v
.call_luma_write:
    mov     edi, VP8_TEST_FRAME_WIDTH
    mov     esi, VP8_TEST_FRAME_HEIGHT
    mov     edx, 1
    mov     ecx, 1
    mov     r8, plane
    mov     r9, frame_y
    call    er_vp8_write_luma_macroblock
    cmp     eax, 8
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + VP8_TEST_LUMA_CLIP_FIRST], 77
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + VP8_TEST_LUMA_CLIP_LAST], 77
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + VP8_TEST_LUMA_CLIP_BEFORE], 0
    jne     .fail_macroblock_geometry
    mov     edi, VP8_TEST_CHROMA_WIDTH
    mov     esi, VP8_TEST_CHROMA_HEIGHT
    mov     edx, 1
    mov     ecx, 1
    mov     r8, u_plane
    mov     r9, v_plane
    push    frame_v
    push    frame_u
    call    er_vp8_write_chroma_macroblock
    add     rsp, 16
    cmp     eax, 2
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_u + VP8_TEST_CHROMA_CLIP_FIRST], 88
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_v + VP8_TEST_CHROMA_CLIP_LAST], 99
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_u + VP8_TEST_CHROMA_CLIP_BEFORE], 0
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_reference_y:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .fill_reference_u_start
    mov     byte [rel frame_y + rcx], cl
    inc     ecx
    jmp     .fill_reference_y
.fill_reference_u_start:
    xor     ecx, ecx
.fill_reference_u:
    cmp     ecx, VP8_TEST_FRAME_UV_BYTES
    jae     .fill_reference_v_start
    mov     eax, ecx
    add     eax, 5
    mov     byte [rel frame_u + rcx], al
    inc     ecx
    jmp     .fill_reference_u
.fill_reference_v_start:
    xor     ecx, ecx
.fill_reference_v:
    cmp     ecx, VP8_TEST_FRAME_UV_BYTES
    jae     .call_reference_luma
    mov     eax, ecx
    add     eax, 9
    mov     byte [rel frame_v + rcx], al
    inc     ecx
    jmp     .fill_reference_v
.call_reference_luma:
    mov     edi, VP8_TEST_FRAME_WIDTH
    mov     esi, VP8_TEST_FRAME_HEIGHT
    mov     edx, 1
    mov     ecx, 1
    mov     r8d, -1
    mov     r9d, -2
    push    plane
    push    frame_y
    call    er_vp8_read_reference_luma_nearest
    add     rsp, 16
    cmp     eax, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel plane], 58
    jne     .fail_macroblock_geometry
    cmp     byte [rel plane + 255], 81
    jne     .fail_macroblock_geometry
    mov     edi, VP8_TEST_CHROMA_WIDTH
    mov     esi, VP8_TEST_CHROMA_HEIGHT
    mov     edx, 1
    mov     ecx, 1
    mov     r8d, -1
    mov     r9d, -1
    push    v_plane
    push    u_plane
    push    frame_v
    push    frame_u
    call    er_vp8_read_reference_chroma_nearest
    add     rsp, 32
    cmp     eax, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel u_plane], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel v_plane], 86
    jne     .fail_macroblock_geometry
    cmp     byte [rel u_plane + 63], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel v_plane + 63], 87
    jne     .fail_macroblock_geometry
    mov     byte [rel subpixel_taps + 0], 10
    mov     byte [rel subpixel_taps + 1], 20
    mov     byte [rel subpixel_taps + 2], 30
    mov     byte [rel subpixel_taps + 3], 40
    mov     byte [rel subpixel_taps + 4], 50
    mov     byte [rel subpixel_taps + 5], 60
    mov     rdi, subpixel_taps
    xor     esi, esi
    call    er_vp8_subpixel_filter_value
    cmp     eax, 30
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     rdi, subpixel_taps
    mov     esi, 2
    call    er_vp8_subpixel_filter_value
    cmp     eax, 32
    jne     .fail_macroblock_geometry
    mov     byte [rel subpixel_taps + 0], 0
    mov     byte [rel subpixel_taps + 1], 0
    mov     byte [rel subpixel_taps + 2], 0
    mov     byte [rel subpixel_taps + 3], 255
    mov     byte [rel subpixel_taps + 4], 255
    mov     byte [rel subpixel_taps + 5], 255
    mov     rdi, subpixel_taps
    mov     esi, 7
    call    er_vp8_subpixel_filter_value
    cmp     eax, 233
    jne     .fail_macroblock_geometry
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    mov     ecx, 1
    mov     r8d, 1
    mov     r9d, -1
    push    2
    push    -2
    call    er_vp8_reference_horizontal_sample
    add     rsp, 16
    test    edx, edx
    jnz     .fail_macroblock_geometry
    test    eax, eax
    jnz     .fail_macroblock_geometry
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    mov     ecx, 1
    mov     r8d, 1
    mov     r9d, -1
    push    2
    push    0
    call    er_vp8_reference_vertical_sample
    add     rsp, 16
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     eax, 5
    jne     .fail_macroblock_geometry
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    mov     ecx, 1
    mov     r8d, 1
    mov     r9d, -1
    push    2
    push    2
    push    -2
    call    er_vp8_reference_subpixel_sample
    add     rsp, 24
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     eax, 4
    jne     .fail_macroblock_geometry
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    mov     ecx, 3
    mov     r8d, 3
    xor     r9d, r9d
    push    2
    push    2
    push    0
    call    er_vp8_reference_subpixel_sample
    add     rsp, 24
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     eax, 68
    jne     .fail_macroblock_geometry
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9d, -1
    push    2
    push    2
    push    -2
    call    er_vp8_reference_subpixel_sample
    add     rsp, 24
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     [rel subpixel_taps + 2], al
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    xor     edx, edx
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r8d, -1
    mov     r9d, -2
    push    plane
    push    frame_y
    push    2
    push    2
    call    er_vp8_read_reference_luma_subpixel
    add     rsp, 32
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     eax, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    mov     al, [rel subpixel_taps + 2]
    cmp     byte [rel plane], al
    jne     .fail_macroblock_geometry
    mov     rdi, frame_u
    mov     esi, VP8_TEST_CHROMA_WIDTH
    mov     edx, VP8_TEST_CHROMA_HEIGHT
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9d, -1
    push    2
    push    2
    push    -1
    call    er_vp8_reference_subpixel_sample
    add     rsp, 24
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     [rel subpixel_taps], al
    mov     rdi, frame_v
    mov     esi, VP8_TEST_CHROMA_WIDTH
    mov     edx, VP8_TEST_CHROMA_HEIGHT
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9d, -1
    push    2
    push    2
    push    -1
    call    er_vp8_reference_subpixel_sample
    add     rsp, 24
    test    edx, edx
    jnz     .fail_macroblock_geometry
    mov     [rel subpixel_taps + 1], al
    mov     edi, VP8_TEST_CHROMA_WIDTH
    mov     esi, VP8_TEST_CHROMA_HEIGHT
    xor     edx, edx
    xor     ecx, ecx
    mov     r8d, -1
    mov     r9d, -1
    push    v_plane
    push    u_plane
    push    frame_v
    push    frame_u
    push    2
    push    2
    call    er_vp8_read_reference_chroma_subpixel
    add     rsp, 48
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     eax, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jne     .fail_macroblock_geometry
    mov     al, [rel subpixel_taps]
    cmp     byte [rel u_plane], al
    jne     .fail_macroblock_geometry
    mov     al, [rel subpixel_taps + 1]
    cmp     byte [rel v_plane], al
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.clear_split_vectors:
    cmp     ecx, VP8_Y_BLOCK_COUNT * VP8_MOTION_VECTOR_SIZE
    jae     .fill_split_reference_rows
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + rcx], 0
    inc     ecx
    jmp     .clear_split_vectors
.fill_split_reference_rows:
    xor     r8d, r8d
.fill_split_reference_row:
    cmp     r8d, VP8_TEST_FRAME_HEIGHT
    jae     .set_split_vectors
    xor     ecx, ecx
.fill_split_reference_col:
    cmp     ecx, VP8_TEST_FRAME_WIDTH
    jae     .next_split_reference_row
    mov     eax, r8d
    imul    eax, 10
    add     eax, ecx
    mov     edx, r8d
    imul    edx, VP8_TEST_FRAME_WIDTH
    add     edx, ecx
    mov     byte [rel frame_y + rdx], al
    inc     ecx
    jmp     .fill_split_reference_col
.next_split_reference_row:
    inc     r8d
    jmp     .fill_split_reference_row
.set_split_vectors:
    mov     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + 1 * VP8_MOTION_VECTOR_SIZE + VP8_MOTION_VECTOR_COL], 4
    mov     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + 4 * VP8_MOTION_VECTOR_SIZE + VP8_MOTION_VECTOR_ROW], 4
    mov     rdi, plane
    xor     esi, esi
    mov     edx, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    call    er_vp8_memset
    mov     edi, VP8_TEST_FRAME_WIDTH
    mov     esi, VP8_TEST_FRAME_HEIGHT
    xor     edx, edx
    xor     ecx, ecx
    lea     r8, [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS]
    mov     r9, frame_y
    push    plane
    call    er_vp8_read_reference_luma_split
    add     rsp, 8
    cmp     eax, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel plane], 0
    jne     .fail_macroblock_geometry
    cmp     byte [rel plane + 4], 5
    jne     .fail_macroblock_geometry
    cmp     byte [rel plane + 4 * VP8_MACROBLOCK_SIZE], 50
    jne     .fail_macroblock_geometry
    mov     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + 2 * VP8_MOTION_VECTOR_SIZE + VP8_MOTION_VECTOR_ROW], -8
    mov     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + 2 * VP8_MOTION_VECTOR_SIZE + VP8_MOTION_VECTOR_COL], 12
    lea     rdi, [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS]
    mov     rsi, motion_vector
    call    er_vp8_average_split_chroma_motion
    cmp     eax, VP8_MOTION_VECTOR_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], 0
    jne     .fail_macroblock_geometry
    cmp     word [rel motion_vector + VP8_MOTION_VECTOR_COL], 1
    jne     .fail_macroblock_geometry
    mov     rdi, subpixel_taps
    mov     esi, VP8_SUBPIXEL_FILTER_PHASE_COUNT
    call    er_vp8_subpixel_filter_value
    test    eax, eax
    jnz     .fail_macroblock_geometry
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_macroblock_geometry
    mov     edi, 10
    mov     esi, 19
    call    er_vp8_abs_diff_u8
    cmp     eax, 9
    jne     .fail_macroblock_geometry
    mov     edi, 200
    call    er_vp8_saturate_i8
    cmp     eax, 127
    jne     .fail_macroblock_geometry
    mov     edi, 128
    mov     esi, 128
    mov     edx, 128
    call    er_vp8_yuv_to_rgba
    cmp     eax, 0xff808080
    jne     .fail_macroblock_geometry
    mov     byte [rel frame_y], 128
    mov     byte [rel frame_y + 1], 128
    mov     byte [rel frame_y + 2], 128
    mov     byte [rel frame_y + 3], 128
    mov     byte [rel frame_u], 128
    mov     byte [rel frame_v], 128
    mov     rdi, frame_y
    mov     rsi, frame_u
    mov     rdx, frame_v
    mov     ecx, 2
    mov     r8d, 2
    mov     r9d, 1
    push    frame_rgba
    call    er_vp8_write_frame_rgba
    add     rsp, 8
    cmp     eax, 4
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     dword [rel frame_rgba], 0xff808080
    jne     .fail_macroblock_geometry
    cmp     dword [rel frame_rgba + 12], 0xff808080
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_filter_right
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_filter_plane
.paint_filter_right:
    xor     r8d, r8d
.paint_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_filter_vertical
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    add     eax, 8
    xor     ecx, ecx
.paint_filter_col:
    cmp     ecx, 12
    jae     .paint_filter_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_filter_col
.paint_filter_next_row:
    inc     r8d
    jmp     .paint_filter_row
.call_filter_vertical:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_MACROBLOCK_SIZE
    mov     ecx, 8
    xor     r8d, r8d
    mov     r9d, 20
    push    2
    push    0
    push    20
    call    er_vp8_filter_normal_macroblock_vertical_edge
    add     rsp, 24
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 5], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 10], 83
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_horizontal_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_horizontal_filter_bottom
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_horizontal_filter_plane
.paint_horizontal_filter_bottom:
    mov     r8d, 8
.paint_horizontal_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_filter_horizontal
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    xor     ecx, ecx
.paint_horizontal_filter_col:
    cmp     ecx, VP8_MACROBLOCK_SIZE
    jae     .paint_horizontal_filter_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_horizontal_filter_col
.paint_horizontal_filter_next_row:
    inc     r8d
    jmp     .paint_horizontal_filter_row
.call_filter_horizontal:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    xor     ecx, ecx
    mov     r8d, 8
    mov     r9d, 20
    push    2
    push    0
    push    20
    call    er_vp8_filter_normal_macroblock_horizontal_edge
    add     rsp, 24
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 5 * VP8_TEST_FRAME_WIDTH], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6 * VP8_TEST_FRAME_WIDTH], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7 * VP8_TEST_FRAME_WIDTH], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8 * VP8_TEST_FRAME_WIDTH], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9 * VP8_TEST_FRAME_WIDTH], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 10 * VP8_TEST_FRAME_WIDTH], 83
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_hev_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_hev_filter_edge
    mov     byte [rel frame_y + rcx], 40
    inc     ecx
    jmp     .fill_hev_filter_plane
.paint_hev_filter_edge:
    xor     r8d, r8d
.paint_hev_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_hev_filter_vertical
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    mov     byte [rel frame_y + rax + 7], 80
    mov     byte [rel frame_y + rax + 8], 84
    mov     byte [rel frame_y + rax + 9], 84
    mov     byte [rel frame_y + rax + 10], 84
    inc     r8d
    jmp     .paint_hev_filter_row
.call_hev_filter_vertical:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_MACROBLOCK_SIZE
    mov     ecx, 8
    xor     r8d, r8d
    mov     r9d, 20
    push    2
    push    0
    push    50
    call    er_vp8_filter_normal_macroblock_vertical_edge
    add     rsp, 24
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6], 40
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7], 76
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8], 88
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9], 84
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_simple_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_simple_filter_right
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_simple_filter_plane
.paint_simple_filter_right:
    xor     r8d, r8d
.paint_simple_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_simple_filter_vertical
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    add     eax, 8
    xor     ecx, ecx
.paint_simple_filter_col:
    cmp     ecx, 12
    jae     .paint_simple_filter_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_simple_filter_col
.paint_simple_filter_next_row:
    inc     r8d
    jmp     .paint_simple_filter_row
.call_simple_filter_vertical:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_MACROBLOCK_SIZE
    mov     ecx, 8
    xor     r8d, r8d
    mov     r9d, 20
    call    er_vp8_filter_simple_vertical_edge
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6], 80
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9], 84
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_simple_horizontal_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_simple_horizontal_filter_bottom
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_simple_horizontal_filter_plane
.paint_simple_horizontal_filter_bottom:
    mov     r8d, 8
.paint_simple_horizontal_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_simple_filter_horizontal
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    xor     ecx, ecx
.paint_simple_horizontal_filter_col:
    cmp     ecx, VP8_MACROBLOCK_SIZE
    jae     .paint_simple_horizontal_filter_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_simple_horizontal_filter_col
.paint_simple_horizontal_filter_next_row:
    inc     r8d
    jmp     .paint_simple_horizontal_filter_row
.call_simple_filter_horizontal:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    xor     ecx, ecx
    mov     r8d, 8
    mov     r9d, 20
    call    er_vp8_filter_simple_horizontal_edge
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6 * VP8_TEST_FRAME_WIDTH], 80
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7 * VP8_TEST_FRAME_WIDTH], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8 * VP8_TEST_FRAME_WIDTH], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9 * VP8_TEST_FRAME_WIDTH], 84
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_subblock_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_subblock_filter_right
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_subblock_filter_plane
.paint_subblock_filter_right:
    xor     r8d, r8d
.paint_subblock_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_subblock_filter_vertical
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    add     eax, 8
    xor     ecx, ecx
.paint_subblock_filter_col:
    cmp     ecx, 12
    jae     .paint_subblock_filter_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_subblock_filter_col
.paint_subblock_filter_next_row:
    inc     r8d
    jmp     .paint_subblock_filter_row
.call_subblock_filter_vertical:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_MACROBLOCK_SIZE
    mov     ecx, 8
    xor     r8d, r8d
    mov     r9d, 20
    push    2
    push    0
    push    20
    call    er_vp8_filter_normal_subblock_vertical_edge
    add     rsp, 24
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 10], 84
    jne     .fail_macroblock_geometry
    xor     ecx, ecx
.fill_subblock_horizontal_filter_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES
    jae     .paint_subblock_horizontal_filter_bottom
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_subblock_horizontal_filter_plane
.paint_subblock_horizontal_filter_bottom:
    mov     r8d, 8
.paint_subblock_horizontal_filter_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_subblock_filter_horizontal
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    xor     ecx, ecx
.paint_subblock_horizontal_filter_col:
    cmp     ecx, VP8_MACROBLOCK_SIZE
    jae     .paint_subblock_horizontal_filter_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_subblock_horizontal_filter_col
.paint_subblock_horizontal_filter_next_row:
    inc     r8d
    jmp     .paint_subblock_horizontal_filter_row
.call_subblock_filter_horizontal:
    mov     rdi, frame_y
    mov     esi, VP8_TEST_FRAME_WIDTH
    mov     edx, VP8_TEST_FRAME_HEIGHT
    xor     ecx, ecx
    mov     r8d, 8
    mov     r9d, 20
    push    2
    push    0
    push    20
    call    er_vp8_filter_normal_subblock_horizontal_edge
    add     rsp, 24
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 6 * VP8_TEST_FRAME_WIDTH], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 7 * VP8_TEST_FRAME_WIDTH], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 8 * VP8_TEST_FRAME_WIDTH], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 9 * VP8_TEST_FRAME_WIDTH], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 10 * VP8_TEST_FRAME_WIDTH], 84
    jne     .fail_macroblock_geometry
    mov     rdi, compressed_header
    xor     esi, esi
    mov     edx, VP8_COMPRESSED_HEADER_SIZE
    call    er_vp8_memset
    mov     rdi, macroblock_header
    xor     esi, esi
    mov     edx, VP8_MACROBLOCK_HEADER_SIZE
    call    er_vp8_memset
    mov     byte [rel compressed_header + VP8_COMPRESSED_HEADER_LOOP_FILTER + VP8_LOOP_FILTER_LEVEL], 20
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_PREDICTION], VP8_MACROBLOCK_PREDICTION_INTRA
    mov     byte [rel macroblock_header + VP8_MACROBLOCK_HEADER_LUMA_MODE], VP8_LUMA_MODE_DC
    xor     ecx, ecx
.fill_macroblock_filter_orchestrator_plane:
    cmp     ecx, VP8_TEST_FRAME_Y_BYTES + VP8_TEST_FRAME_UV_BYTES * 2
    jae     .paint_macroblock_filter_orchestrator_right
    mov     byte [rel frame_y + rcx], 80
    inc     ecx
    jmp     .fill_macroblock_filter_orchestrator_plane
.paint_macroblock_filter_orchestrator_right:
    xor     r8d, r8d
.paint_macroblock_filter_orchestrator_row:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .call_macroblock_filter_orchestrator
    mov     eax, r8d
    imul    eax, VP8_TEST_FRAME_WIDTH
    add     eax, 16
    xor     ecx, ecx
.paint_macroblock_filter_orchestrator_col:
    cmp     ecx, 4
    jae     .paint_macroblock_filter_orchestrator_next_row
    mov     byte [rel frame_y + rax + rcx], 84
    inc     ecx
    jmp     .paint_macroblock_filter_orchestrator_col
.paint_macroblock_filter_orchestrator_next_row:
    inc     r8d
    jmp     .paint_macroblock_filter_orchestrator_row
.call_macroblock_filter_orchestrator:
    mov     rdi, compressed_header
    mov     rsi, macroblock_header
    mov     edx, VP8_FRAME_TYPE_KEY
    mov     rcx, frame_y
    mov     r8d, VP8_TEST_FRAME_WIDTH
    mov     r9d, VP8_TEST_FRAME_HEIGHT
    push    0
    push    0
    push    1
    push    VP8_TEST_FRAME_UV_BYTES
    push    VP8_TEST_FRAME_Y_BYTES
    push    VP8_TEST_CHROMA_HEIGHT
    push    VP8_TEST_CHROMA_WIDTH
    call    er_vp8_filter_macroblock
    add     rsp, 56
    cmp     eax, VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_geometry
    test    edx, edx
    jnz     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 13], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 14], 81
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 15], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 16], 82
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 17], 83
    jne     .fail_macroblock_geometry
    cmp     byte [rel frame_y + 18], 83
    jne     .fail_macroblock_geometry
    inc     qword [rel passed]
    jmp     .coeff_tables
.fail_macroblock_geometry:
    inc     qword [rel failed]

.coeff_tables:
    mov     edi, 0
    call    er_vp8_coeff_band
    cmp     eax, 0
    jne     .fail_coeff_tables
    test    edx, edx
    jnz     .fail_coeff_tables
    mov     edi, 4
    call    er_vp8_coeff_band
    cmp     eax, 6
    jne     .fail_coeff_tables
    test    edx, edx
    jnz     .fail_coeff_tables
    mov     edi, 15
    call    er_vp8_coeff_band
    cmp     eax, 7
    jne     .fail_coeff_tables
    test    edx, edx
    jnz     .fail_coeff_tables
    mov     edi, 2
    call    er_vp8_zigzag
    cmp     eax, 4
    jne     .fail_coeff_tables
    test    edx, edx
    jnz     .fail_coeff_tables
    mov     edi, 15
    call    er_vp8_zigzag
    cmp     eax, 15
    jne     .fail_coeff_tables
    test    edx, edx
    jnz     .fail_coeff_tables
    inc     qword [rel passed]
    jmp     .coeff_probability_offset
.fail_coeff_tables:
    inc     qword [rel failed]

.coeff_probability_offset:
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    xor     ecx, ecx
    call    er_vp8_coeff_probability_offset
    test    eax, eax
    jnz     .fail_coeff_probability_offset
    test    edx, edx
    jnz     .fail_coeff_probability_offset
    mov     edi, 1
    mov     esi, 0
    mov     edx, 0
    mov     ecx, 2
    call    er_vp8_coeff_probability_offset
    cmp     eax, 266
    jne     .fail_coeff_probability_offset
    test    edx, edx
    jnz     .fail_coeff_probability_offset
    mov     edi, 3
    mov     esi, 7
    mov     edx, 2
    mov     ecx, 10
    call    er_vp8_coeff_probability_offset
    cmp     eax, VP8_COEFF_UPDATE_PROBABILITY_COUNT - 1
    jne     .fail_coeff_probability_offset
    test    edx, edx
    jnz     .fail_coeff_probability_offset
    mov     edi, VP8_COEFF_TYPE_COUNT
    xor     esi, esi
    xor     edx, edx
    xor     ecx, ecx
    call    er_vp8_coeff_probability_offset
    test    eax, eax
    jnz     .fail_coeff_probability_offset
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_coeff_probability_offset
    inc     qword [rel passed]
    jmp     .motion_vector_small
.fail_coeff_probability_offset:
    inc     qword [rel failed]

.coeff_default_probability:
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    mov     ecx, VP8_COEFF_EOB_PROBABILITY_INDEX
    call    er_vp8_coeff_default_probability
    cmp     eax, 128
    jne     .fail_coeff_default_probability
    test    edx, edx
    jnz     .fail_coeff_default_probability
    xor     edi, edi
    mov     esi, 1
    xor     edx, edx
    mov     ecx, VP8_COEFF_ZERO_PROBABILITY_INDEX
    call    er_vp8_coeff_default_probability
    cmp     eax, 136
    jne     .fail_coeff_default_probability
    test    edx, edx
    jnz     .fail_coeff_default_probability
    mov     edi, 1
    xor     esi, esi
    xor     edx, edx
    mov     ecx, VP8_COEFF_ONE_PROBABILITY_INDEX
    call    er_vp8_coeff_default_probability
    cmp     eax, 237
    jne     .fail_coeff_default_probability
    test    edx, edx
    jnz     .fail_coeff_default_probability
    mov     edi, 3
    xor     esi, esi
    mov     edx, 2
    mov     ecx, VP8_COEFF_LARGE_PROBABILITY_6
    call    er_vp8_coeff_default_probability
    cmp     eax, 216
    jne     .fail_coeff_default_probability
    test    edx, edx
    jnz     .fail_coeff_default_probability
    mov     rdi, token_probabilities
    call    er_vp8_copy_default_coeff_probabilities
    cmp     eax, VP8_COEFF_UPDATE_PROBABILITY_COUNT
    jne     .fail_coeff_default_probability
    test    edx, edx
    jnz     .fail_coeff_default_probability
    cmp     byte [rel token_probabilities], 128
    jne     .fail_coeff_default_probability
    cmp     byte [rel token_probabilities + 34], 136
    jne     .fail_coeff_default_probability
    cmp     byte [rel token_probabilities + 266], 237
    jne     .fail_coeff_default_probability
    inc     qword [rel passed]
    jmp     .large_coeff_value
.fail_coeff_default_probability:
    inc     qword [rel failed]

.large_coeff_value:
    mov     rdi, bool_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    xor     edx, edx
    mov     ecx, 1
    xor     r8d, r8d
    call    er_vp8_read_large_coeff_value
    cmp     eax, VP8_COEFF_MIN_LARGE_VALUE
    jne     .fail_large_coeff_value
    test    edx, edx
    jnz     .fail_large_coeff_value
    mov     rdi, bool_long_ones
    mov     esi, 8
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    xor     edx, edx
    mov     ecx, 1
    xor     r8d, r8d
    call    er_vp8_read_large_coeff_value
    cmp     eax, VP8_COEFF_CAT6_BASE + 2047
    jne     .fail_large_coeff_value
    test    edx, edx
    jnz     .fail_large_coeff_value
    xor     rdi, rdi
    mov     rsi, token_probabilities
    xor     edx, edx
    xor     ecx, ecx
    xor     r8d, r8d
    call    er_vp8_read_large_coeff_value
    test    eax, eax
    jnz     .fail_large_coeff_value
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_large_coeff_value
    inc     qword [rel passed]
    jmp     .coeff_block_decode
.fail_large_coeff_value:
    inc     qword [rel failed]

.coeff_block_decode:
    mov     rdi, bool_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     word [rel coeff_block], 77
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    xor     edx, edx
    mov     ecx, 1
    xor     r8d, r8d
    mov     r9, coeff_block
    call    er_vp8_read_coeff_block
    cmp     eax, 1
    jne     .fail_coeff_block_decode
    test    r8d, r8d
    jnz     .fail_coeff_block_decode
    test    edx, edx
    jnz     .fail_coeff_block_decode
    cmp     word [rel coeff_block], 0
    jne     .fail_coeff_block_decode
    mov     rdi, bool_long_ones
    mov     esi, 8
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    xor     edx, edx
    mov     ecx, 1
    xor     r8d, r8d
    mov     r9, coeff_block
    call    er_vp8_read_coeff_block
    cmp     eax, 16
    jne     .fail_coeff_block_decode
    cmp     r8d, 1
    jne     .fail_coeff_block_decode
    test    edx, edx
    jnz     .fail_coeff_block_decode
    cmp     word [rel coeff_block + 2], -(VP8_COEFF_CAT6_BASE + 2047)
    jne     .fail_coeff_block_decode
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    mov     edx, 1
    mov     rcx, macroblock_coeffs
    call    er_vp8_read_residual_macroblock_single
    test    eax, eax
    jnz     .fail_coeff_block_decode
    test    edx, edx
    jnz     .fail_coeff_block_decode
    cmp     word [rel macroblock_coeffs + VP8_Y2_BLOCK_INDEX * VP8_COEFF_BLOCK_BYTES], 0
    jne     .fail_coeff_block_decode
    mov     rdi, residual_context
    mov     esi, 1
    mov     edx, VP8_RESIDUAL_CONTEXT_SIZE
    call    er_vp8_memset
    mov     rdi, residual_context
    mov     esi, 2
    mov     edx, 1
    call    er_vp8_skip_residual_context
    cmp     eax, 1
    jne     .fail_coeff_block_decode
    test    edx, edx
    jnz     .fail_coeff_block_decode
    cmp     dword [rel residual_context + VP8_RESIDUAL_CONTEXT_TOP_Y + 8], 0
    jne     .fail_coeff_block_decode
    cmp     dword [rel residual_context + VP8_RESIDUAL_CONTEXT_LEFT_Y], 0
    jne     .fail_coeff_block_decode
    cmp     word [rel residual_context + VP8_RESIDUAL_CONTEXT_TOP_U + 4], 0
    jne     .fail_coeff_block_decode
    cmp     word [rel residual_context + VP8_RESIDUAL_CONTEXT_TOP_V + 4], 0
    jne     .fail_coeff_block_decode
    cmp     word [rel residual_context + VP8_RESIDUAL_CONTEXT_LEFT_U], 0
    jne     .fail_coeff_block_decode
    cmp     word [rel residual_context + VP8_RESIDUAL_CONTEXT_LEFT_V], 0
    jne     .fail_coeff_block_decode
    cmp     byte [rel residual_context + VP8_RESIDUAL_CONTEXT_TOP_Y2 + 2], 0
    jne     .fail_coeff_block_decode
    cmp     byte [rel residual_context + VP8_RESIDUAL_CONTEXT_LEFT_Y2], 0
    jne     .fail_coeff_block_decode
    mov     rdi, residual_context
    xor     esi, esi
    mov     edx, VP8_RESIDUAL_CONTEXT_SIZE
    call    er_vp8_memset
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    mov     edx, 1
    mov     rcx, macroblock_coeffs
    xor     r8d, r8d
    mov     r9, residual_context
    call    er_vp8_read_residual_macroblock_context
    test    eax, eax
    jnz     .fail_coeff_block_decode
    test    edx, edx
    jnz     .fail_coeff_block_decode
    inc     qword [rel passed]
    jmp     .dequantize_blocks
.fail_coeff_block_decode:
    inc     qword [rel failed]

.dequantize_blocks:
    mov     word [rel coeff_block], 2
    mov     word [rel coeff_block + 2], -3
    mov     word [rel coeff_block + 30], 4
    mov     word [rel dequant + VP8_DEQUANT_Y_DC], 5
    mov     word [rel dequant + VP8_DEQUANT_Y_AC], 7
    mov     word [rel dequant + VP8_DEQUANT_Y2_DC], 11
    mov     word [rel dequant + VP8_DEQUANT_Y2_AC], 13
    mov     word [rel dequant + VP8_DEQUANT_UV_DC], 17
    mov     word [rel dequant + VP8_DEQUANT_UV_AC], 19
    mov     rdi, coeff_block
    mov     rsi, dequant
    mov     rdx, dequant_block
    call    er_vp8_dequantize_y_block_with_own_dc
    cmp     eax, VP8_DEQUANT_BLOCK_BYTES
    jne     .fail_dequantize_blocks
    test    edx, edx
    jnz     .fail_dequantize_blocks
    cmp     dword [rel dequant_block], 10
    jne     .fail_dequantize_blocks
    cmp     dword [rel dequant_block + 4], -21
    jne     .fail_dequantize_blocks
    cmp     dword [rel dequant_block + 60], 28
    jne     .fail_dequantize_blocks
    mov     rdi, coeff_block
    mov     rsi, dequant
    mov     edx, 1234
    mov     rcx, dequant_block
    call    er_vp8_dequantize_y_block_with_y2_dc
    cmp     dword [rel dequant_block], 1234
    jne     .fail_dequantize_blocks
    cmp     dword [rel dequant_block + 4], -21
    jne     .fail_dequantize_blocks
    mov     rdi, coeff_block
    mov     rsi, dequant
    mov     rdx, dequant_block
    call    er_vp8_dequantize_y2_block
    cmp     dword [rel dequant_block], 22
    jne     .fail_dequantize_blocks
    cmp     dword [rel dequant_block + 4], -39
    jne     .fail_dequantize_blocks
    mov     rdi, coeff_block
    mov     rsi, dequant
    mov     rdx, dequant_block
    call    er_vp8_dequantize_uv_block
    cmp     dword [rel dequant_block], 34
    jne     .fail_dequantize_blocks
    cmp     dword [rel dequant_block + 4], -57
    jne     .fail_dequantize_blocks
    inc     qword [rel passed]
    jmp     .inverse_wht
.fail_dequantize_blocks:
    inc     qword [rel failed]

.inverse_wht:
    mov     dword [rel dequant_block], 16
    mov     dword [rel dequant_block + 4], 0
    mov     dword [rel dequant_block + 8], 0
    mov     dword [rel dequant_block + 12], 0
    mov     dword [rel dequant_block + 16], 0
    mov     dword [rel dequant_block + 20], 0
    mov     dword [rel dequant_block + 24], 0
    mov     dword [rel dequant_block + 28], 0
    mov     dword [rel dequant_block + 32], 0
    mov     dword [rel dequant_block + 36], 0
    mov     dword [rel dequant_block + 40], 0
    mov     dword [rel dequant_block + 44], 0
    mov     dword [rel dequant_block + 48], 0
    mov     dword [rel dequant_block + 52], 0
    mov     dword [rel dequant_block + 56], 0
    mov     dword [rel dequant_block + 60], 0
    mov     rdi, dequant_block
    mov     rsi, dequant_block + VP8_DEQUANT_BLOCK_BYTES
    call    er_vp8_inverse_wht
    cmp     eax, VP8_DEQUANT_BLOCK_BYTES
    jne     .fail_inverse_wht
    test    edx, edx
    jnz     .fail_inverse_wht
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES], 2
    jne     .fail_inverse_wht
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 60], 2
    jne     .fail_inverse_wht
    mov     dword [rel dequant_block], 8
    mov     dword [rel dequant_block + 4], -8
    mov     dword [rel dequant_block + 8], 4
    mov     dword [rel dequant_block + 12], -4
    mov     dword [rel dequant_block + 16], 0
    mov     dword [rel dequant_block + 20], 0
    mov     dword [rel dequant_block + 24], 0
    mov     dword [rel dequant_block + 28], 0
    mov     dword [rel dequant_block + 32], 0
    mov     dword [rel dequant_block + 36], 0
    mov     dword [rel dequant_block + 40], 0
    mov     dword [rel dequant_block + 44], 0
    mov     dword [rel dequant_block + 48], 0
    mov     dword [rel dequant_block + 52], 0
    mov     dword [rel dequant_block + 56], 0
    mov     dword [rel dequant_block + 60], 0
    mov     rdi, dequant_block
    mov     rsi, dequant_block + VP8_DEQUANT_BLOCK_BYTES
    call    er_vp8_inverse_wht
    test    edx, edx
    jnz     .fail_inverse_wht
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES], 0
    jne     .fail_inverse_wht
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 4], 2
    jne     .fail_inverse_wht
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 8], 1
    jne     .fail_inverse_wht
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 12], 1
    jne     .fail_inverse_wht
    inc     qword [rel passed]
    jmp     .idct_mul_shift
.fail_inverse_wht:
    inc     qword [rel failed]

.idct_mul_shift:
    mov     edi, 1
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    test    eax, eax
    jnz     .fail_idct_mul_shift
    test    edx, edx
    jnz     .fail_idct_mul_shift
    mov     edi, 2
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    cmp     eax, 1
    jne     .fail_idct_mul_shift
    test    edx, edx
    jnz     .fail_idct_mul_shift
    mov     edi, -2
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    cmp     eax, -2
    jne     .fail_idct_mul_shift
    test    edx, edx
    jnz     .fail_idct_mul_shift
    inc     qword [rel passed]
    jmp     .inverse_idct
.fail_idct_mul_shift:
    inc     qword [rel failed]

.inverse_idct:
    mov     dword [rel dequant_block], 16
    mov     dword [rel dequant_block + 4], 0
    mov     dword [rel dequant_block + 8], 0
    mov     dword [rel dequant_block + 12], 0
    mov     dword [rel dequant_block + 16], 0
    mov     dword [rel dequant_block + 20], 0
    mov     dword [rel dequant_block + 24], 0
    mov     dword [rel dequant_block + 28], 0
    mov     dword [rel dequant_block + 32], 0
    mov     dword [rel dequant_block + 36], 0
    mov     dword [rel dequant_block + 40], 0
    mov     dword [rel dequant_block + 44], 0
    mov     dword [rel dequant_block + 48], 0
    mov     dword [rel dequant_block + 52], 0
    mov     dword [rel dequant_block + 56], 0
    mov     dword [rel dequant_block + 60], 0
    mov     rdi, dequant_block
    mov     rsi, dequant_block + VP8_DEQUANT_BLOCK_BYTES
    call    er_vp8_inverse_idct
    cmp     eax, VP8_DEQUANT_BLOCK_BYTES
    jne     .fail_inverse_idct
    test    edx, edx
    jnz     .fail_inverse_idct
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES], 2
    jne     .fail_inverse_idct
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 60], 2
    jne     .fail_inverse_idct
    mov     dword [rel dequant_block], 8
    mov     dword [rel dequant_block + 4], -8
    mov     dword [rel dequant_block + 8], 4
    mov     dword [rel dequant_block + 12], -4
    mov     dword [rel dequant_block + 16], 0
    mov     dword [rel dequant_block + 20], 0
    mov     dword [rel dequant_block + 24], 0
    mov     dword [rel dequant_block + 28], 0
    mov     dword [rel dequant_block + 32], 0
    mov     dword [rel dequant_block + 36], 0
    mov     dword [rel dequant_block + 40], 0
    mov     dword [rel dequant_block + 44], 0
    mov     dword [rel dequant_block + 48], 0
    mov     dword [rel dequant_block + 52], 0
    mov     dword [rel dequant_block + 56], 0
    mov     dword [rel dequant_block + 60], 0
    mov     rdi, dequant_block
    mov     rsi, dequant_block + VP8_DEQUANT_BLOCK_BYTES
    call    er_vp8_inverse_idct
    test    edx, edx
    jnz     .fail_inverse_idct
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES], 0
    jne     .fail_inverse_idct
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 4], 2
    jne     .fail_inverse_idct
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 8], 1
    jne     .fail_inverse_idct
    cmp     dword [rel dequant_block + VP8_DEQUANT_BLOCK_BYTES + 12], 0
    jne     .fail_inverse_idct
    inc     qword [rel passed]
    jmp     .pixel_add
.fail_inverse_idct:
    inc     qword [rel failed]

.pixel_add:
    mov     edi, -3
    call    er_vp8_clamp_u8
    test    eax, eax
    jnz     .fail_pixel_add
    test    edx, edx
    jnz     .fail_pixel_add
    mov     edi, 300
    call    er_vp8_clamp_u8
    cmp     eax, 255
    jne     .fail_pixel_add
    mov     byte [rel plane], 10
    mov     rdi, plane
    xor     esi, esi
    mov     edx, -20
    call    er_vp8_add_pixel
    test    eax, eax
    jnz     .fail_pixel_add
    cmp     byte [rel plane], 0
    jne     .fail_pixel_add
    mov     byte [rel plane + 1], 250
    mov     rdi, plane
    mov     esi, 1
    mov     edx, 20
    call    er_vp8_add_pixel
    cmp     eax, 255
    jne     .fail_pixel_add
    cmp     byte [rel plane + 1], 255
    jne     .fail_pixel_add
    mov     byte [rel plane + 2], 100
    mov     rdi, plane
    mov     esi, 2
    mov     edx, -7
    call    er_vp8_add_pixel
    cmp     eax, 93
    jne     .fail_pixel_add
    cmp     byte [rel plane + 2], 93
    jne     .fail_pixel_add
    inc     qword [rel passed]
    jmp     .add_idct_block
.fail_pixel_add:
    inc     qword [rel failed]

.add_idct_block:
    mov     dword [rel dequant_block], 16
    mov     dword [rel dequant_block + 4], 0
    mov     dword [rel dequant_block + 8], 0
    mov     dword [rel dequant_block + 12], 0
    mov     dword [rel dequant_block + 16], 0
    mov     dword [rel dequant_block + 20], 0
    mov     dword [rel dequant_block + 24], 0
    mov     dword [rel dequant_block + 28], 0
    mov     dword [rel dequant_block + 32], 0
    mov     dword [rel dequant_block + 36], 0
    mov     dword [rel dequant_block + 40], 0
    mov     dword [rel dequant_block + 44], 0
    mov     dword [rel dequant_block + 48], 0
    mov     dword [rel dequant_block + 52], 0
    mov     dword [rel dequant_block + 56], 0
    mov     dword [rel dequant_block + 60], 0
    mov     byte [rel plane + 5], 10
    mov     byte [rel plane + 8], 254
    mov     rdi, dequant_block
    mov     rsi, plane
    mov     edx, 5
    mov     ecx, 3
    call    er_vp8_add_idct_block
    cmp     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    jne     .fail_add_idct_block
    test    edx, edx
    jnz     .fail_add_idct_block
    cmp     byte [rel plane + 5], 12
    jne     .fail_add_idct_block
    cmp     byte [rel plane + 8], 255
    jne     .fail_add_idct_block
    cmp     byte [rel plane + 17], 2
    jne     .fail_add_idct_block
    xor     rdi, rdi
    mov     rsi, plane
    xor     edx, edx
    mov     ecx, 4
    call    er_vp8_add_idct_block
    test    eax, eax
    jnz     .fail_add_idct_block
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_add_idct_block
    inc     qword [rel passed]
    jmp     .plane_block_offsets
.fail_add_idct_block:
    inc     qword [rel failed]

.plane_block_offsets:
    xor     edi, edi
    call    er_vp8_y_plane_block_offset
    test    eax, eax
    jnz     .fail_plane_block_offsets
    test    edx, edx
    jnz     .fail_plane_block_offsets
    mov     edi, 1
    call    er_vp8_y_plane_block_offset
    cmp     eax, 4
    jne     .fail_plane_block_offsets
    mov     edi, 4
    call    er_vp8_y_plane_block_offset
    cmp     eax, 64
    jne     .fail_plane_block_offsets
    mov     edi, 15
    call    er_vp8_y_plane_block_offset
    cmp     eax, 204
    jne     .fail_plane_block_offsets
    mov     edi, VP8_Y_BLOCK_COUNT
    call    er_vp8_y_plane_block_offset
    test    eax, eax
    jnz     .fail_plane_block_offsets
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_plane_block_offsets
    xor     edi, edi
    call    er_vp8_uv_plane_block_offset
    test    eax, eax
    jnz     .fail_plane_block_offsets
    mov     edi, 1
    call    er_vp8_uv_plane_block_offset
    cmp     eax, 4
    jne     .fail_plane_block_offsets
    mov     edi, 2
    call    er_vp8_uv_plane_block_offset
    cmp     eax, 32
    jne     .fail_plane_block_offsets
    mov     edi, 3
    call    er_vp8_uv_plane_block_offset
    cmp     eax, 36
    jne     .fail_plane_block_offsets
    inc     qword [rel passed]
    jmp     .macroblock_residual_adders
.fail_plane_block_offsets:
    inc     qword [rel failed]

.macroblock_residual_adders:
    xor     ecx, ecx
.clear_coeffs:
    cmp     ecx, VP8_MACROBLOCK_COEFF_BLOCK_COUNT * VP8_COEFF_BLOCK_BYTES
    jae     .fill_residual_planes
    mov     byte [rel macroblock_coeffs + rcx], 0
    inc     ecx
    jmp     .clear_coeffs
.fill_residual_planes:
    mov     word [rel dequant + VP8_DEQUANT_Y_DC], 4
    mov     word [rel dequant + VP8_DEQUANT_Y_AC], 4
    mov     word [rel dequant + VP8_DEQUANT_Y2_DC], 4
    mov     word [rel dequant + VP8_DEQUANT_Y2_AC], 4
    mov     word [rel dequant + VP8_DEQUANT_UV_DC], 4
    mov     word [rel dequant + VP8_DEQUANT_UV_AC], 4
    xor     ecx, ecx
.fill_y_plane:
    cmp     ecx, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    jae     .fill_u_plane_start
    mov     byte [rel plane + rcx], 100
    inc     ecx
    jmp     .fill_y_plane
.fill_u_plane_start:
    xor     ecx, ecx
.fill_u_plane:
    cmp     ecx, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jae     .fill_v_plane_start
    mov     byte [rel u_plane + rcx], 110
    inc     ecx
    jmp     .fill_u_plane
.fill_v_plane_start:
    xor     ecx, ecx
.fill_v_plane:
    cmp     ecx, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jae     .call_luma_without_y2
    mov     byte [rel v_plane + rcx], 120
    inc     ecx
    jmp     .fill_v_plane
.call_luma_without_y2:
    mov     rdi, dequant
    mov     rsi, macroblock_coeffs
    mov     rdx, plane
    call    er_vp8_add_luma_residuals_without_y2
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane], 100
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 255], 100
    jne     .fail_macroblock_residual_adders
    mov     word [rel macroblock_coeffs + VP8_COEFF_BLOCK_BYTES], 4
    mov     rdi, dequant
    mov     rsi, macroblock_coeffs
    mov     rdx, plane
    call    er_vp8_add_luma_residuals_without_y2
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane], 100
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 4], 102
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 55], 100
    jne     .fail_macroblock_residual_adders
    mov     word [rel macroblock_coeffs + VP8_COEFF_BLOCK_BYTES], 0
    mov     rdi, dequant
    mov     rsi, macroblock_coeffs
    mov     rdx, plane
    call    er_vp8_add_luma_residuals_with_y2
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 204], 100
    jne     .fail_macroblock_residual_adders
    mov     rdi, dequant
    mov     rsi, macroblock_coeffs
    mov     rdx, u_plane
    mov     rcx, v_plane
    call    er_vp8_add_chroma_residuals
    cmp     eax, VP8_CHROMA_COEFF_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel u_plane], 110
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel u_plane + 63], 110
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel v_plane], 120
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel v_plane + 63], 120
    jne     .fail_macroblock_residual_adders
    xor     ecx, ecx
.fill_bpred_edges:
    cmp     ecx, VP8_MACROBLOCK_SIZE
    jae     .fill_bpred_top_right
    mov     byte [rel edges + rcx], 10
    mov     byte [rel edges + VP8_EDGES_LEFT_16 + rcx], 20
    inc     ecx
    jmp     .fill_bpred_edges
.fill_bpred_top_right:
    mov     byte [rel edges + VP8_EDGES_TOP_LEFT_16], 7
    xor     ecx, ecx
.fill_bpred_right_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .fill_bpred_modes
    mov     byte [rel edges + VP8_EDGES_TOP_RIGHT_16 + rcx], 10
    inc     ecx
    jmp     .fill_bpred_right_loop
.fill_bpred_modes:
    xor     ecx, ecx
.fill_bpred_mode_loop:
    cmp     ecx, VP8_Y_BLOCK_COUNT
    jae     .call_bpred_reconstruct
    mov     byte [rel modes + rcx], VP8_INTRA4_MODE_DC
    inc     ecx
    jmp     .fill_bpred_mode_loop
.call_bpred_reconstruct:
    mov     rdi, dequant
    mov     rsi, edges
    mov     rdx, modes
    mov     rcx, macroblock_coeffs
    mov     r8, plane
    call    er_vp8_reconstruct_bpred_luma
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane], 15
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 3], 15
    jne     .fail_macroblock_residual_adders
    mov     edi, VP8_LUMA_MODE_HORIZONTAL
    mov     rsi, edges
    mov     rdx, plane
    call    er_vp8_predict_luma
    cmp     eax, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane], 20
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 255], 20
    jne     .fail_macroblock_residual_adders
    mov     edi, VP8_CHROMA_MODE_VERTICAL
    mov     rsi, edges
    mov     rdx, u_plane
    call    er_vp8_predict_chroma
    cmp     eax, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel u_plane], 10
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel u_plane + 63], 10
    jne     .fail_macroblock_residual_adders
    mov     rdi, dequant
    mov     esi, VP8_LUMA_MODE_HORIZONTAL
    mov     rdx, edges
    mov     rcx, macroblock_coeffs
    mov     r8, plane
    call    er_vp8_reconstruct_intra_luma
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane], 20
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 255], 20
    jne     .fail_macroblock_residual_adders
    mov     rdi, dequant
    mov     esi, VP8_CHROMA_MODE_VERTICAL
    mov     rdx, edges
    mov     rcx, edges
    mov     r8, macroblock_coeffs
    mov     r9, u_plane
    push    v_plane
    call    er_vp8_reconstruct_chroma
    add     rsp, 8
    cmp     eax, VP8_CHROMA_COEFF_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel u_plane], 10
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel v_plane + 63], 10
    jne     .fail_macroblock_residual_adders
    mov     rdi, dequant
    mov     esi, VP8_LUMA_MODE_HORIZONTAL
    mov     edx, VP8_CHROMA_MODE_VERTICAL
    mov     rcx, edges
    mov     r8, edges
    mov     r9, edges
    push    v_plane
    push    u_plane
    push    plane
    push    macroblock_coeffs
    push    modes
    call    er_vp8_reconstruct_intra_macroblock
    add     rsp, 40
    cmp     eax, VP8_MACROBLOCK_COEFF_BLOCK_COUNT
    jne     .fail_macroblock_residual_adders
    test    edx, edx
    jnz     .fail_macroblock_residual_adders
    cmp     byte [rel plane], 20
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel plane + 255], 20
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel u_plane], 10
    jne     .fail_macroblock_residual_adders
    cmp     byte [rel v_plane + 63], 10
    jne     .fail_macroblock_residual_adders
    inc     qword [rel passed]
    jmp     .intra_predictors
.fail_macroblock_residual_adders:
    inc     qword [rel failed]

.intra_predictors:
    mov     byte [rel edges + 0], 10
    mov     byte [rel edges + 1], 20
    mov     byte [rel edges + 2], 30
    mov     byte [rel edges + 3], 40
    mov     byte [rel edges + VP8_EDGES_LEFT_8 + 0], 50
    mov     byte [rel edges + VP8_EDGES_LEFT_8 + 1], 60
    mov     byte [rel edges + VP8_EDGES_LEFT_8 + 2], 70
    mov     byte [rel edges + VP8_EDGES_LEFT_8 + 3], 80
    mov     byte [rel edges + VP8_EDGES_TOP_LEFT_8], 20
    mov     byte [rel edges + VP8_EDGES_HAS_TOP_8], 1
    mov     byte [rel edges + VP8_EDGES_HAS_LEFT_8], 1
    mov     rdi, edges
    mov     esi, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_dc_prediction_value
    cmp     eax, 39
    jne     .fail_intra_predictors
    test    edx, edx
    jnz     .fail_intra_predictors
    mov     rdi, edges
    mov     rsi, plane
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_vertical
    cmp     byte [rel plane], 10
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 8], 10
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 10], 30
    jne     .fail_intra_predictors
    mov     rdi, edges
    mov     rsi, plane
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_horizontal
    cmp     byte [rel plane], 50
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 7], 50
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 8], 60
    jne     .fail_intra_predictors
    mov     rdi, edges
    mov     rsi, plane
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_true_motion
    cmp     byte [rel plane], 40
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 1], 50
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 8], 50
    jne     .fail_intra_predictors
    mov     byte [rel edges + VP8_EDGES_HAS_TOP_8], 0
    mov     byte [rel edges + VP8_EDGES_HAS_LEFT_8], 0
    mov     rdi, edges
    mov     rsi, plane
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_dc
    cmp     eax, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    jne     .fail_intra_predictors
    cmp     byte [rel plane], VP8_NEUTRAL_LUMA
    jne     .fail_intra_predictors
    cmp     byte [rel plane + 63], VP8_NEUTRAL_LUMA
    jne     .fail_intra_predictors
    inc     qword [rel passed]
    jmp     .intra4_predictors
.fail_intra_predictors:
    inc     qword [rel failed]

.intra4_predictors:
    mov     edi, 10
    mov     esi, 11
    call    er_vp8_avg2
    cmp     eax, 11
    jne     .fail_intra4_predictors
    mov     edi, 10
    mov     esi, 20
    mov     edx, 30
    call    er_vp8_avg3
    cmp     eax, 20
    jne     .fail_intra4_predictors
    mov     byte [rel intra4_top + 0], 10
    mov     byte [rel intra4_top + 1], 20
    mov     byte [rel intra4_top + 2], 30
    mov     byte [rel intra4_top + 3], 40
    mov     byte [rel intra4_top + 4], 50
    mov     byte [rel intra4_top + 5], 60
    mov     byte [rel intra4_top + 6], 70
    mov     byte [rel intra4_top + 7], 80
    mov     byte [rel intra4_left + 0], 70
    mov     byte [rel intra4_left + 1], 80
    mov     byte [rel intra4_left + 2], 90
    mov     byte [rel intra4_left + 3], 100
    mov     rdi, intra4_top
    mov     rsi, intra4_left
    mov     edx, 50
    mov     rcx, intra4_edge
    call    er_vp8_build_intra4_edge
    cmp     eax, VP8_INTRA4_EDGE_SIZE
    jne     .fail_intra4_predictors
    cmp     byte [rel intra4_edge + 0], 100
    jne     .fail_intra4_predictors
    cmp     byte [rel intra4_edge + 4], 50
    jne     .fail_intra4_predictors
    cmp     byte [rel intra4_edge + 8], 40
    jne     .fail_intra4_predictors
    mov     rdi, plane
    mov     esi, 4
    mov     edx, 4
    mov     ecx, 1
    mov     r8d, 2
    mov     r9d, 123
    call    er_vp8_write_intra4
    cmp     eax, 86
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 86], 123
    jne     .fail_intra4_predictors
    mov     rdi, intra4_top
    mov     rsi, intra4_left
    mov     rdx, plane
    xor     ecx, ecx
    xor     r8d, r8d
    call    er_vp8_predict_intra4_dc
    cmp     byte [rel plane], 55
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 51], 55
    jne     .fail_intra4_predictors
    mov     rdi, intra4_top
    mov     rsi, plane
    mov     edx, 4
    xor     ecx, ecx
    call    er_vp8_predict_intra4_vertical
    cmp     byte [rel plane + 4], 20
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 7], 50
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 20], 20
    jne     .fail_intra4_predictors
    mov     rdi, intra4_left
    mov     esi, 60
    mov     rdx, plane
    xor     ecx, ecx
    mov     r8d, 4
    call    er_vp8_predict_intra4_horizontal
    cmp     byte [rel plane + 64], 70
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 80], 80
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 112], 98
    jne     .fail_intra4_predictors
    mov     rdi, intra4_top
    mov     rsi, intra4_left
    mov     edx, 20
    mov     rcx, plane
    mov     r8d, 8
    mov     r9d, 8
    call    er_vp8_predict_intra4_true_motion
    cmp     byte [rel plane + 136], 60
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 137], 70
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 152], 70
    jne     .fail_intra4_predictors
    mov     rdi, intra4_top
    mov     rsi, plane
    xor     edx, edx
    mov     ecx, 8
    call    er_vp8_predict_intra4_left_down
    cmp     byte [rel plane + 128], 20
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 129], 30
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 145], 40
    jne     .fail_intra4_predictors
    mov     rdi, intra4_top
    mov     rsi, plane
    mov     edx, 4
    mov     ecx, 8
    call    er_vp8_predict_intra4_vertical_left
    cmp     byte [rel plane + 132], 15
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 133], 30
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 148], 20
    jne     .fail_intra4_predictors
    mov     rdi, intra4_left
    mov     rsi, plane
    mov     edx, 8
    xor     ecx, ecx
    call    er_vp8_predict_intra4_horizontal_up
    cmp     byte [rel plane + 8], 75
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 9], 80
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 25], 95
    jne     .fail_intra4_predictors
    mov     rdi, intra4_edge
    mov     rsi, plane
    xor     edx, edx
    xor     ecx, ecx
    call    er_vp8_predict_intra4_right_down
    cmp     byte [rel plane + 0], 45
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 3], 90
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 48], 30
    jne     .fail_intra4_predictors
    mov     rdi, intra4_edge
    mov     rsi, plane
    mov     edx, 4
    xor     ecx, ecx
    call    er_vp8_predict_intra4_vertical_right
    cmp     byte [rel plane + 4], 30
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 7], 80
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 55], 20
    jne     .fail_intra4_predictors
    mov     rdi, intra4_edge
    mov     rsi, plane
    mov     edx, 8
    xor     ecx, ecx
    call    er_vp8_predict_intra4_horizontal_down
    cmp     byte [rel plane + 8], 60
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 11], 95
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 56], 20
    jne     .fail_intra4_predictors
    mov     byte [rel edges + 0], 10
    mov     byte [rel edges + 1], 20
    mov     byte [rel edges + 2], 30
    mov     byte [rel edges + 3], 40
    mov     byte [rel edges + 4], 50
    mov     byte [rel edges + 5], 60
    mov     byte [rel edges + 6], 70
    mov     byte [rel edges + 7], 80
    mov     byte [rel edges + VP8_EDGES_TOP_RIGHT_16 + 0], 100
    mov     byte [rel edges + VP8_EDGES_TOP_RIGHT_16 + 1], 110
    mov     byte [rel edges + VP8_EDGES_TOP_RIGHT_16 + 2], 120
    mov     byte [rel edges + VP8_EDGES_TOP_RIGHT_16 + 3], 130
    mov     byte [rel edges + VP8_EDGES_LEFT_16 + 0], 11
    mov     byte [rel edges + VP8_EDGES_LEFT_16 + 1], 21
    mov     byte [rel edges + VP8_EDGES_LEFT_16 + 2], 31
    mov     byte [rel edges + VP8_EDGES_LEFT_16 + 3], 41
    mov     byte [rel edges + VP8_EDGES_TOP_LEFT_16], 7
    mov     edi, VP8_INTRA4_MODE_VERTICAL_LEFT
    mov     rsi, edges
    mov     rdx, plane
    xor     ecx, ecx
    call    er_vp8_predict_intra4_block
    cmp     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    jne     .fail_intra4_predictors
    test    edx, edx
    jnz     .fail_intra4_predictors
    cmp     byte [rel plane], 15
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 17], 40
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 51], 78
    jne     .fail_intra4_predictors
    mov     edi, VP8_INTRA4_MODE_HORIZONTAL_UP
    mov     rsi, edges
    mov     rdx, plane
    xor     ecx, ecx
    call    er_vp8_predict_intra4_block
    cmp     byte [rel plane], 16
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 19], 39
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 51], 41
    jne     .fail_intra4_predictors
    mov     edi, VP8_INTRA4_MODE_HORIZONTAL
    mov     rsi, edges
    mov     rdx, plane
    xor     ecx, ecx
    call    er_vp8_predict_intra4_block
    cmp     byte [rel plane], 13
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 16], 21
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 32], 31
    jne     .fail_intra4_predictors
    cmp     byte [rel plane + 48], 39
    jne     .fail_intra4_predictors
    inc     qword [rel passed]
    jmp     .coeff_update_probability
.fail_intra4_predictors:
    inc     qword [rel failed]

.coeff_update_probability:
    xor     edi, edi
    call    er_vp8_coeff_update_probability
    cmp     eax, VP8_COEFF_UPDATE_PROBABILITY_DEFAULT
    jne     .fail_coeff_update_probability
    test    edx, edx
    jnz     .fail_coeff_update_probability
    mov     edi, 33
    call    er_vp8_coeff_update_probability
    cmp     eax, 176
    jne     .fail_coeff_update_probability
    test    edx, edx
    jnz     .fail_coeff_update_probability
    mov     edi, 264
    call    er_vp8_coeff_update_probability
    cmp     eax, 217
    jne     .fail_coeff_update_probability
    test    edx, edx
    jnz     .fail_coeff_update_probability
    mov     edi, 1001
    call    er_vp8_coeff_update_probability
    cmp     eax, 250
    jne     .fail_coeff_update_probability
    test    edx, edx
    jnz     .fail_coeff_update_probability
    mov     edi, VP8_COEFF_UPDATE_PROBABILITY_COUNT - 1
    call    er_vp8_coeff_update_probability
    cmp     eax, VP8_COEFF_UPDATE_PROBABILITY_DEFAULT
    jne     .fail_coeff_update_probability
    test    edx, edx
    jnz     .fail_coeff_update_probability
    mov     edi, VP8_COEFF_UPDATE_PROBABILITY_COUNT
    call    er_vp8_coeff_update_probability
    test    eax, eax
    jnz     .fail_coeff_update_probability
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_coeff_update_probability
    inc     qword [rel passed]
    jmp     .token_probability_updates
.fail_coeff_update_probability:
    inc     qword [rel failed]

.token_probability_updates:
    mov     byte [rel token_probabilities], 17
    mov     byte [rel token_probabilities + 33], 19
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, token_probabilities
    call    er_vp8_parse_token_probability_updates
    test    eax, eax
    jnz     .fail_token_probability_updates
    test    edx, edx
    jnz     .fail_token_probability_updates
    cmp     byte [rel token_probabilities], 17
    jne     .fail_token_probability_updates
    cmp     byte [rel token_probabilities + 33], 19
    jne     .fail_token_probability_updates
    inc     qword [rel passed]
    jmp     .motion_vector_small
.fail_token_probability_updates:
    inc     qword [rel failed]

.motion_vector_small:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    call    er_vp8_read_small_motion_vector_component
    cmp     eax, 0
    jne     .fail_motion_vector_small
    test    edx, edx
    jnz     .fail_motion_vector_small
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    call    er_vp8_read_small_motion_vector_component
    cmp     eax, 7
    jne     .fail_motion_vector_small
    test    edx, edx
    jnz     .fail_motion_vector_small
    inc     qword [rel passed]
    jmp     .motion_vector_long
.fail_motion_vector_small:
    inc     qword [rel failed]

.motion_vector_long:
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    call    er_vp8_read_long_motion_vector_component
    cmp     eax, 1023
    jne     .fail_motion_vector_long
    test    edx, edx
    jnz     .fail_motion_vector_long
    mov     rdi, mode_i16_vertical
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    call    er_vp8_read_long_motion_vector_component
    cmp     eax, 9
    jne     .fail_motion_vector_long
    test    edx, edx
    jnz     .fail_motion_vector_long
    inc     qword [rel passed]
    jmp     .motion_vector_component
.fail_motion_vector_long:
    inc     qword [rel failed]

.motion_vector_component:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    call    er_vp8_read_motion_vector_component
    cmp     eax, 0
    jne     .fail_motion_vector_component
    test    edx, edx
    jnz     .fail_motion_vector_component
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    call    er_vp8_read_motion_vector_component
    cmp     eax, -1023
    jne     .fail_motion_vector_component
    test    edx, edx
    jne     .fail_motion_vector_component
    inc     qword [rel passed]
    jmp     .motion_vector_pair
.fail_motion_vector_component:
    inc     qword [rel failed]

.motion_vector_pair:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    mov     rsi, mv_probs
    mov     rdx, motion_vector
    call    er_vp8_read_motion_vector
    cmp     eax, VP8_MOTION_VECTOR_SIZE
    jne     .fail_motion_vector_pair
    test    edx, edx
    jnz     .fail_motion_vector_pair
    cmp     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], 0
    jne     .fail_motion_vector_pair
    cmp     word [rel motion_vector + VP8_MOTION_VECTOR_COL], 0
    jne     .fail_motion_vector_pair
    inc     qword [rel passed]
    jmp     .motion_vector_helpers
.fail_motion_vector_pair:
    inc     qword [rel failed]

.motion_vector_helpers:
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], -4
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_COL], 8
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], 2
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], -1
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    mov     rdx, motion_vector_other
    call    er_vp8_add_motion_vector
    cmp     eax, VP8_MOTION_VECTOR_SIZE
    jne     .fail_motion_vector_helpers
    test    edx, edx
    jnz     .fail_motion_vector_helpers
    cmp     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], -2
    jne     .fail_motion_vector_helpers
    cmp     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 7
    jne     .fail_motion_vector_helpers
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_same_motion_vector
    test    eax, eax
    jnz     .fail_motion_vector_helpers
    test    edx, edx
    jnz     .fail_motion_vector_helpers
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], -4
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 8
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_same_motion_vector
    cmp     eax, 1
    jne     .fail_motion_vector_helpers
    test    edx, edx
    jnz     .fail_motion_vector_helpers
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], 4
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_COL], -8
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], 12
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 16
    mov     rdi, bool_reader
    mov     rsi, compressed_header
    mov     rdx, motion_vector
    mov     rcx, motion_vector_other
    mov     r8, motion_vector_other
    lea     r9, [rel macroblock_header + VP8_MACROBLOCK_HEADER_MOTION_VECTOR]
    call    er_vp8_read_sub_motion_vector
    cmp     eax, VP8_MOTION_VECTOR_SIZE
    jne     .fail_motion_vector_helpers
    test    edx, edx
    jnz     .fail_motion_vector_helpers
    cmp     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_MOTION_VECTOR + VP8_MOTION_VECTOR_ROW], 4
    jne     .fail_motion_vector_helpers
    cmp     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_MOTION_VECTOR + VP8_MOTION_VECTOR_COL], -8
    jne     .fail_motion_vector_helpers
    inc     qword [rel passed]
    jmp     .sub_motion_context
.fail_motion_vector_helpers:
    inc     qword [rel failed]

.sub_motion_context:
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], 0
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_COL], 0
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], 0
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 0
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_sub_motion_context
    cmp     eax, VP8_SUB_MV_CONTEXT_LEFT_ABOVE_ZERO
    jne     .fail_sub_motion_context
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 4
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_sub_motion_context
    cmp     eax, VP8_SUB_MV_CONTEXT_LEFT_ZERO
    jne     .fail_sub_motion_context
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], -4
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_COL], 0
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], 0
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 0
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_sub_motion_context
    cmp     eax, VP8_SUB_MV_CONTEXT_ABOVE_ZERO
    jne     .fail_sub_motion_context
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_ROW], -4
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_sub_motion_context
    cmp     eax, VP8_SUB_MV_CONTEXT_LEFT_EQUALS_ABOVE
    jne     .fail_sub_motion_context
    mov     word [rel motion_vector_other + VP8_MOTION_VECTOR_COL], 4
    mov     rdi, motion_vector
    mov     rsi, motion_vector_other
    call    er_vp8_sub_motion_context
    cmp     eax, VP8_SUB_MV_CONTEXT_LEFT_DIFFERS_ABOVE
    jne     .fail_sub_motion_context
    inc     qword [rel passed]
    jmp     .inter_mode_context_probability
.fail_sub_motion_context:
    inc     qword [rel failed]

.inter_mode_context_probability:
    mov     edi, 0
    mov     esi, 0
    call    er_vp8_inter_mode_context_probability
    cmp     eax, 7
    jne     .fail_inter_mode_context_probability
    test    edx, edx
    jnz     .fail_inter_mode_context_probability
    mov     edi, 2
    mov     esi, 3
    call    er_vp8_inter_mode_context_probability
    cmp     eax, 68
    jne     .fail_inter_mode_context_probability
    mov     edi, 99
    mov     esi, 0
    call    er_vp8_inter_mode_context_probability
    cmp     eax, 234
    jne     .fail_inter_mode_context_probability
    mov     edi, 0
    mov     esi, VP8_INTER_MODE_PROBABILITY_COUNT
    call    er_vp8_inter_mode_context_probability
    test    eax, eax
    jnz     .fail_inter_mode_context_probability
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_inter_mode_context_probability
    inc     qword [rel passed]
    jmp     .split_mv_partition
.fail_inter_mode_context_probability:
    inc     qword [rel failed]

.split_mv_partition:
    mov     edi, 0
    mov     rsi, split_partition
    call    er_vp8_split_mv_partition
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_split_mv_partition
    test    edx, edx
    jnz     .fail_split_mv_partition
    cmp     byte [rel split_partition], 0
    jne     .fail_split_mv_partition
    cmp     byte [rel split_partition + 7], 0
    jne     .fail_split_mv_partition
    cmp     byte [rel split_partition + 8], 1
    jne     .fail_split_mv_partition
    mov     edi, 3
    mov     rsi, split_partition
    call    er_vp8_split_mv_partition
    cmp     byte [rel split_partition + 15], 15
    jne     .fail_split_mv_partition
    mov     edi, VP8_SPLIT_MV_PARTITION_COUNT
    mov     rsi, split_partition
    call    er_vp8_split_mv_partition
    test    eax, eax
    jnz     .fail_split_mv_partition
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_split_mv_partition
    inc     qword [rel passed]
    jmp     .read_split_mv_partition
.fail_split_mv_partition:
    inc     qword [rel failed]

.read_split_mv_partition:
    mov     rdi, mode_zero
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_split_mv_partition
    cmp     eax, 3
    jne     .fail_read_split_mv_partition
    test    edx, edx
    jnz     .fail_read_split_mv_partition
    mov     rdi, mode_full
    mov     esi, VP8_BOOL_INITIAL_BYTES
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    mov     rdi, bool_reader
    call    er_vp8_read_split_mv_partition
    cmp     eax, 1
    jne     .fail_read_split_mv_partition
    test    edx, edx
    jnz     .fail_read_split_mv_partition
    inc     qword [rel passed]
    jmp     .read_inter_split_motion
.fail_read_split_mv_partition:
    inc     qword [rel failed]

.read_inter_split_motion:
    mov     rdi, bool_zero
    mov     esi, 3
    mov     rdx, bool_reader
    call    er_vp8_bool_reader_init
    lea     rdi, [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS]
    xor     esi, esi
    mov     edx, VP8_Y_BLOCK_COUNT * VP8_MOTION_VECTOR_SIZE
    call    er_vp8_memset
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_ROW], 0
    mov     word [rel motion_vector + VP8_MOTION_VECTOR_COL], 0
    mov     rdi, bool_reader
    mov     rsi, compressed_header
    mov     rdx, motion_vector
    lea     rcx, [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS]
    call    er_vp8_read_inter_split_motion
    cmp     eax, VP8_Y_BLOCK_COUNT
    jne     .fail_read_inter_split_motion
    test    edx, edx
    jnz     .fail_read_inter_split_motion
    cmp     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + VP8_MOTION_VECTOR_ROW], 0
    jne     .fail_read_inter_split_motion
    cmp     word [rel macroblock_header + VP8_MACROBLOCK_HEADER_SPLIT_VECTORS + 15 * VP8_MOTION_VECTOR_SIZE + VP8_MOTION_VECTOR_COL], 0
    jne     .fail_read_inter_split_motion
    inc     qword [rel passed]
    jmp     .done
.fail_read_inter_split_motion:
    inc     qword [rel failed]

.done:
    mov     rax, [rel failed]
    test    rax, rax
    jz      .ok
    TEST_EXIT 1
.ok:
    TEST_EXIT 0
