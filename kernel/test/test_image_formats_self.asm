; EdgeRun image format self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/image_formats_constants.inc"
%include "test/test_macros.inc"

extern er_image_is_jpeg
extern er_image_is_png
extern er_image_jxl_kind
extern er_image_is_jxl
extern er_image_is_tga
extern er_image_detect_import_format
extern er_image_decode_jpeg_header
extern er_image_decode_png_header
extern er_image_decode_tga_header
extern er_image_decode_tga
extern er_image_encode_tga_rgba
extern er_jpeg_bit_reader_init
extern er_jpeg_read_bit
extern er_jpeg_read_bits
extern er_jpeg_consume_marker
extern er_jpeg_consume_restart
extern er_jpeg_consume_eoi
extern er_jpeg_build_huffman_table
extern er_jpeg_huffman_decode
extern er_jpeg_receive_extend
extern er_jpeg_decode_block
extern er_jpeg_clamp_u8
extern er_jpeg_gray_color
extern er_jpeg_ycbcr_color
extern er_jpeg_idct_sample
extern er_jpeg_sample_component
extern er_jpeg_state_init
extern er_jpeg_parse_dqt
extern er_jpeg_parse_sof0
extern er_jpeg_parse_dht
extern er_jpeg_parse_sos
extern er_jpeg_parse_dri
extern er_jpeg_parse
extern er_jpeg_decode_scan_gray
extern er_image_decode_jpeg
extern er_jpeg_reset_dc
extern er_image_runtime_payload_len
extern er_image_runtime_canonical_len
extern er_image_runtime_encode_rgba
extern er_image_runtime_encode_rgba_tiled
extern er_image_runtime_decode_rgba
extern er_png_unfilter
extern er_png_write_pixels
extern er_zlib_inflate_stored
extern er_image_decode_png_stored
extern er_image_decode_import_header

TEST_BSS_PASSED_FAILED
hdr: resb IMAGE_HEADER_SIZE
decoded_pixels: resd 4
encoded_tga: resb TGA_HEADER_SIZE + 4 * 4 + TGA_FOOTER_SIZE
encoded_erimg: resb ERIMG_HEADER_SIZE + 6 * 4
decoded_erimg: resd 6
png_pixels: resd 4
inflate_out: resb 128
png_scratch: resb 64
jpeg_reader: resb JPEG_BIT_READER_SIZE
jpeg_huff: resb JPEG_HUFF_TABLE_SIZE
jpeg_huff_ac: resb JPEG_HUFF_TABLE_SIZE
jpeg_quant: resw JPEG_BLOCK_LEN
jpeg_block: resw JPEG_BLOCK_LEN
jpeg_component_blocks: resw JPEG_MAX_COMPONENT_BLOCKS * JPEG_BLOCK_LEN
jpeg_prev_dc: resw 1
jpeg_state: resb JPEG_STATE_SIZE
jpeg_scan_offset: resq 1
jpeg_scan_scratch: resb JPEG_SCAN_SCRATCH_SIZE
jpeg_scan_pixels: resd 1
jpeg_decode_scratch: resb JPEG_DECODE_SCRATCH_SIZE
jpeg_decode_pixels: resd 1
jpeg_restart_pixels: resd 9

SECTION .data
jpeg_minimal:
    db 0xff, 0xd8
    db 0xff, 0xe0
    db 0x00, 0x04
    db 0x12, 0x34
    db 0xff, 0xc0
    db 0x00, 0x11
    db 0x08
    db 0x00, 0x03
    db 0x00, 0x02
    db 0x03
    db 0x01, 0x11, 0x00
    db 0x02, 0x11, 0x00
    db 0x03, 0x11, 0x00
jpeg_minimal_len equ $ - jpeg_minimal

png_minimal:
    db 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a
    dd 0x0d000000
    db 'I', 'H', 'D', 'R'
    db 0x00, 0x00, 0x00, 0x02
    db 0x00, 0x00, 0x00, 0x03
    db 0x08
    db 0x06
    db 0x00
    db 0x00
    db 0x00
    dd 0x81deeab9
    dd 0x01000000
    db 'I', 'D', 'A', 'T'
    db 0x00
    dd 0xe87d3828
    dd 0x00000000
    db 'I', 'E', 'N', 'D'
    dd 0x826042ae
png_minimal_len equ $ - png_minimal

png_bad_crc:
    db 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a
    dd 0x0d000000
    db 'I', 'H', 'D', 'R'
    db 0x00, 0x00, 0x00, 0x02
    db 0x00, 0x00, 0x00, 0x03
    db 0x08
    db 0x06
    db 0x00
    db 0x00
    db 0x00
    dd 0x80deeab9
    dd 0x01000000
    db 'I', 'D', 'A', 'T'
    db 0x00
    dd 0xe87d3828
    dd 0x00000000
    db 'I', 'E', 'N', 'D'
    dd 0x826042ae
png_bad_crc_len equ $ - png_bad_crc

png_filter_scanlines:
    db PNG_FILTER_NONE,    10, 20, 30
    db PNG_FILTER_SUB,     1, 1, 1
    db PNG_FILTER_UP,      5, 5, 5
    db PNG_FILTER_AVERAGE, 6, 2, 2
    db PNG_FILTER_PAETH,   3, 1, 1
png_filter_scanlines_len equ $ - png_filter_scanlines

png_gray_alpha_scanline:
    db PNG_FILTER_NONE, 0x20, 0x80, 0xe0, 0x40
png_gray_alpha_scanline_len equ $ - png_gray_alpha_scanline

png_rgba_scanline:
    db PNG_FILTER_NONE, 0xff, 0x00, 0x00, 0xff, 0x00, 0xff, 0x00, 0x80
png_rgba_scanline_len equ $ - png_rgba_scanline

zlib_stored_gray:
    db 0x78, 0x01
    db 0x01
    dw 3
    dw 0xfffc
    db PNG_FILTER_NONE, 0x20, 0xe0
    db 0x01, 0x23, 0x01, 0x01
zlib_stored_gray_len equ $ - zlib_stored_gray

zlib_stored_bad_adler:
    db 0x78, 0x01
    db 0x01
    dw 3
    dw 0xfffc
    db PNG_FILTER_NONE, 0x20, 0xe0
    db 0x01, 0x23, 0x01, 0x00
zlib_stored_bad_adler_len equ $ - zlib_stored_bad_adler

zlib_fixed_backref:
    db 0x78, 0x01, 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00
    db 0x1d, 0xe0, 0x04, 0x99
zlib_fixed_backref_len equ $ - zlib_fixed_backref

zlib_dynamic_literals:
    db 0x78, 0x01, 0x05, 0xc0, 0x01, 0x09, 0x00, 0x00
    db 0x00, 0x80, 0xa0, 0xe6, 0xd6, 0xff, 0x03, 0x69
    db 0x03, 0x01, 0x3b, 0x00, 0xd2
zlib_dynamic_literals_len equ $ - zlib_dynamic_literals

zlib_dynamic_backref:
    db 0x78, 0x9c, 0x8d, 0xcb, 0xd1, 0x09, 0xc0, 0x20
    db 0x0c, 0x05, 0xc0, 0x55, 0xde, 0x00, 0xa5, 0x93
    db 0xb8, 0x84, 0xc4, 0x20, 0x0f, 0x8c, 0x91, 0x24
    db 0xee, 0xdf, 0x15, 0x7a, 0xff, 0xd7, 0x3c, 0xd4
    db 0xc0, 0x93, 0xd7, 0x30, 0x7c, 0x79, 0x20, 0x59
    db 0xe8, 0xa6, 0xf5, 0x40, 0x7c, 0xa7, 0x4a, 0x69
    db 0xdd, 0x40, 0x1f, 0x3c, 0x4c, 0xe1, 0x9e, 0xd0
    db 0xc5, 0x7a, 0xd1, 0xfe, 0xc7, 0x0f, 0x55, 0x2f
    db 0x25, 0x24
zlib_dynamic_backref_len equ $ - zlib_dynamic_backref

png_gray_stored:
    db 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a
    db 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52
    db 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01
    db 0x08, 0x00, 0x00, 0x00, 0x00, 0xd1, 0x49, 0x20
    db 0x56, 0x00, 0x00, 0x00, 0x0e, 0x49, 0x44, 0x41
    db 0x54, 0x78, 0x01, 0x01, 0x03, 0x00, 0xfc, 0xff
    db 0x00, 0x20, 0xe0, 0x01, 0x23, 0x01, 0x01, 0x1c
    db 0x95, 0x37, 0xd3, 0x00, 0x00, 0x00, 0x00, 0x49
    db 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82
png_gray_stored_len equ $ - png_gray_stored

png_rgba_fixed:
    db 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a
    db 0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52
    db 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01
    db 0x08, 0x06, 0x00, 0x00, 0x00, 0xf4, 0x22, 0x7f
    db 0x8a, 0x00, 0x00, 0x00, 0x11, 0x49, 0x44, 0x41
    db 0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0xf0
    db 0x9f, 0xe1, 0x3f, 0x43, 0x03, 0x00, 0x10, 0x79
    db 0x03, 0x7e, 0x21, 0xc0, 0xfd, 0x8d, 0x00, 0x00
    db 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42
    db 0x60, 0x82
png_rgba_fixed_len equ $ - png_rgba_fixed

jxl_codestream:
    db 0xff, 0x0a, 0x00, 0x01
jxl_codestream_len equ $ - jxl_codestream

jxl_container:
    db 0x00, 0x00, 0x00, 0x0c, 0x4a, 0x58, 0x4c, 0x20, 0x0d, 0x0a, 0x87, 0x0a
    dd 0
jxl_container_len equ $ - jxl_container

tga_rgba:
    db 0
    db 0
    db TGA_TYPE_TRUE_COLOR
    times 9 db 0
    dw 2
    dw 2
    db TGA_DEPTH_RGBA
    db 0x28
    db 0x00, 0x00, 0xff, 0xff
    db 0x00, 0xff, 0x00, 0x80
    db 0xff, 0x00, 0x00, 0x40
    db 0xff, 0xff, 0xff, 0x00
tga_rgba_len equ $ - tga_rgba

expected_rgba_pixels:
    dd 0xff0000ff
    dd 0x8000ff00
    dd 0x40ff0000
    dd 0x00ffffff

erimg_pixels_2x1:
    dd 0x04030201
    dd 0x08070605

erimg_pixels_3x2:
    dd 0xff000001
    dd 0xff000002
    dd 0xff000003
    dd 0xff000004
    dd 0xff000005
    dd 0xff000006

bad_bytes:
    db 'n', 'o', 't', '-', 'i', 'm', 'a', 'g', 'e'
bad_bytes_len equ $ - bad_bytes

jpeg_entropy_stuffed:
    db 0xa5, 0xff, 0x00
jpeg_entropy_stuffed_len equ $ - jpeg_entropy_stuffed

jpeg_entropy_marker:
    db 0xff, JPEG_MARKER_EOI
jpeg_entropy_marker_len equ $ - jpeg_entropy_marker

jpeg_restart_marker:
    db 0xff, 0xff, JPEG_MARKER_RST3
jpeg_restart_marker_len equ $ - jpeg_restart_marker

jpeg_eoi_marker:
    db 0xff, JPEG_MARKER_EOI
jpeg_eoi_marker_len equ $ - jpeg_eoi_marker

jpeg_huff_counts:
    db 0, 2, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
jpeg_huff_values:
    db 0x11, 0x22, 0x33
jpeg_huff_values_len equ $ - jpeg_huff_values
jpeg_huff_bits:
    db 0x18
jpeg_huff_bits_len equ $ - jpeg_huff_bits

jpeg_receive_negative_bits:
    db 0x20
jpeg_receive_negative_bits_len equ $ - jpeg_receive_negative_bits

jpeg_dc_counts:
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
jpeg_dc_values:
    db 2
jpeg_dc_values_len equ $ - jpeg_dc_values
jpeg_ac_counts:
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
jpeg_ac_values:
    db 0
jpeg_ac_values_len equ $ - jpeg_ac_values
jpeg_block_bits:
    db 0x60
jpeg_block_bits_len equ $ - jpeg_block_bits

jpeg_dqt_payload:
    db 0x02
    db 5, 6, 7, 8, 9, 10, 11, 12
    db 13, 14, 15, 16, 17, 18, 19, 20
    db 21, 22, 23, 24, 25, 26, 27, 28
    db 29, 30, 31, 32, 33, 34, 35, 36
    db 37, 38, 39, 40, 41, 42, 43, 44
    db 45, 46, 47, 48, 49, 50, 51, 52
    db 53, 54, 55, 56, 57, 58, 59, 60
    db 61, 62, 63, 64, 65, 66, 67, 68
jpeg_dqt_payload_len equ $ - jpeg_dqt_payload

jpeg_sof0_payload:
    db JPEG_PRECISION_8
    db 0x00, 0x03
    db 0x00, 0x02
    db 0x03
    db 0x01, 0x21, 0x00
    db 0x02, 0x11, 0x01
    db 0x03, 0x11, 0x02
jpeg_sof0_payload_len equ $ - jpeg_sof0_payload

jpeg_dht_payload:
    db 0x01
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x02
    db 0x12
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x00
jpeg_dht_payload_len equ $ - jpeg_dht_payload

jpeg_sos_payload:
    db 0x03
    db 0x01, 0x12
    db 0x02, 0x12
    db 0x03, 0x12
    db 0x00, 0x3f, 0x00
jpeg_sos_payload_len equ $ - jpeg_sos_payload

jpeg_dri_payload:
    db 0x00, 0x04
jpeg_dri_payload_len equ $ - jpeg_dri_payload

jpeg_parse_fixture:
    db 0xff, JPEG_MARKER_SOI
    db 0xff, 0xdb
    db 0x00, 0x43
    db 0x02
    db 5, 6, 7, 8, 9, 10, 11, 12
    db 13, 14, 15, 16, 17, 18, 19, 20
    db 21, 22, 23, 24, 25, 26, 27, 28
    db 29, 30, 31, 32, 33, 34, 35, 36
    db 37, 38, 39, 40, 41, 42, 43, 44
    db 45, 46, 47, 48, 49, 50, 51, 52
    db 53, 54, 55, 56, 57, 58, 59, 60
    db 61, 62, 63, 64, 65, 66, 67, 68
    db 0xff, 0xc4
    db 0x00, 0x26
    db 0x01
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x02
    db 0x12
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x00
    db 0xff, JPEG_MARKER_SOF0
    db 0x00, 0x11
    db JPEG_PRECISION_8
    db 0x00, 0x03
    db 0x00, 0x02
    db 0x03
    db 0x01, 0x21, 0x00
    db 0x02, 0x11, 0x01
    db 0x03, 0x11, 0x02
    db 0xff, JPEG_MARKER_SOS
    db 0x00, 0x0c
    db 0x03
    db 0x01, 0x12
    db 0x02, 0x12
    db 0x03, 0x12
    db 0x00, 0x3f, 0x00
    db 0xff, JPEG_MARKER_EOI
jpeg_parse_fixture_len equ $ - jpeg_parse_fixture
jpeg_parse_fixture_scan_offset equ jpeg_parse_fixture_len - 2

jpeg_gray_dqt_payload:
    db 0x00
    times 64 db 1
jpeg_gray_dqt_payload_len equ $ - jpeg_gray_dqt_payload

jpeg_gray_dht_payload:
    db 0x00
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x07
    db 0x10
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x00
jpeg_gray_dht_payload_len equ $ - jpeg_gray_dht_payload

jpeg_gray_sof0_payload:
    db JPEG_PRECISION_8
    db 0x00, 0x01
    db 0x00, 0x01
    db 0x01
    db 0x01, 0x11, 0x00
jpeg_gray_sof0_payload_len equ $ - jpeg_gray_sof0_payload

jpeg_gray_sof0_w9_payload:
    db JPEG_PRECISION_8
    db 0x00, 0x01
    db 0x00, 0x09
    db 0x01
    db 0x01, 0x11, 0x00
jpeg_gray_sof0_w9_payload_len equ $ - jpeg_gray_sof0_w9_payload

jpeg_gray_sos_payload:
    db 0x01
    db 0x01, 0x00
    db 0x00, 0x3f, 0x00
jpeg_gray_sos_payload_len equ $ - jpeg_gray_sos_payload

jpeg_gray_scan:
    db 0x50, 0x00, 0xff, JPEG_MARKER_EOI
jpeg_gray_scan_len equ $ - jpeg_gray_scan

jpeg_gray_restart_scan:
    db 0x50, 0x00, 0xff, JPEG_MARKER_RST0
    db 0x50, 0x00, 0xff, JPEG_MARKER_EOI
jpeg_gray_restart_scan_len equ $ - jpeg_gray_restart_scan

jpeg_gray_full:
    db 0xff, JPEG_MARKER_SOI
    db 0xff, 0xdb
    db 0x00, 0x43
    db 0x00
    times 64 db 1
    db 0xff, 0xc4
    db 0x00, 0x26
    db 0x00
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x07
    db 0x10
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0x00
    db 0xff, JPEG_MARKER_SOF0
    db 0x00, 0x0b
    db JPEG_PRECISION_8
    db 0x00, 0x01
    db 0x00, 0x01
    db 0x01
    db 0x01, 0x11, 0x00
    db 0xff, JPEG_MARKER_SOS
    db 0x00, 0x08
    db 0x01
    db 0x01, 0x00
    db 0x00, 0x3f, 0x00
    db 0x50, 0x00, 0xff, JPEG_MARKER_EOI
jpeg_gray_full_len equ $ - jpeg_gray_full

SECTION .text
global _start
_start:
    mov     rdi, jpeg_minimal
    mov     esi, jpeg_minimal_len
    call    er_image_is_jpeg
    cmp     eax, 1
    jne     .fail_jpeg_is
    test    edx, edx
    jnz     .fail_jpeg_is
    inc     qword [rel passed]
    jmp     .jpeg_bit_reader
.fail_jpeg_is:
    inc     qword [rel failed]

.jpeg_bit_reader:
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_entropy_stuffed
    mov     edx, jpeg_entropy_stuffed_len
    call    er_jpeg_bit_reader_init
    cmp     eax, 1
    jne     .fail_jpeg_bit_reader
    test    edx, edx
    jnz     .fail_jpeg_bit_reader
    mov     rdi, jpeg_reader
    mov     esi, 8
    call    er_jpeg_read_bits
    cmp     eax, 0xa5
    jne     .fail_jpeg_bit_reader
    test    edx, edx
    jnz     .fail_jpeg_bit_reader
    mov     rdi, jpeg_reader
    mov     esi, 8
    call    er_jpeg_read_bits
    cmp     eax, JPEG_MARKER_PREFIX
    jne     .fail_jpeg_bit_reader
    test    edx, edx
    jnz     .fail_jpeg_bit_reader
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_entropy_marker
    mov     edx, jpeg_entropy_marker_len
    call    er_jpeg_bit_reader_init
    mov     rdi, jpeg_reader
    call    er_jpeg_read_bit
    test    eax, eax
    jnz     .fail_jpeg_bit_reader
    cmp     edx, ERROR_CORRUPT
    jne     .fail_jpeg_bit_reader
    inc     qword [rel passed]
    jmp     .jpeg_marker_consumers
.fail_jpeg_bit_reader:
    inc     qword [rel failed]

.jpeg_marker_consumers:
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_restart_marker
    mov     edx, jpeg_restart_marker_len
    call    er_jpeg_bit_reader_init
    mov     rdi, jpeg_reader
    mov     esi, JPEG_MARKER_RST3
    call    er_jpeg_consume_restart
    cmp     eax, 1
    jne     .fail_jpeg_marker_consumers
    test    edx, edx
    jnz     .fail_jpeg_marker_consumers
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_eoi_marker
    mov     edx, jpeg_eoi_marker_len
    call    er_jpeg_bit_reader_init
    mov     rdi, jpeg_reader
    call    er_jpeg_consume_eoi
    cmp     eax, 1
    jne     .fail_jpeg_marker_consumers
    test    edx, edx
    jnz     .fail_jpeg_marker_consumers
    inc     qword [rel passed]
    jmp     .jpeg_huffman
.fail_jpeg_marker_consumers:
    inc     qword [rel failed]

.jpeg_huffman:
    mov     rdi, jpeg_huff_counts
    mov     rsi, jpeg_huff_values
    mov     edx, jpeg_huff_values_len
    mov     rcx, jpeg_huff
    call    er_jpeg_build_huffman_table
    cmp     eax, 1
    jne     .fail_jpeg_huffman
    test    edx, edx
    jnz     .fail_jpeg_huffman
    cmp     dword [rel jpeg_huff + JPEG_HUFF_TABLE_LEN_OFF], 3
    jne     .fail_jpeg_huffman
    cmp     dword [rel jpeg_huff + JPEG_HUFF_TABLE_READY_OFF], 1
    jne     .fail_jpeg_huffman
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_huff_bits
    mov     edx, jpeg_huff_bits_len
    call    er_jpeg_bit_reader_init
    mov     rdi, jpeg_huff
    mov     rsi, jpeg_reader
    call    er_jpeg_huffman_decode
    cmp     eax, 0x11
    jne     .fail_jpeg_huffman
    test    edx, edx
    jnz     .fail_jpeg_huffman
    mov     rdi, jpeg_huff
    mov     rsi, jpeg_reader
    call    er_jpeg_huffman_decode
    cmp     eax, 0x22
    jne     .fail_jpeg_huffman
    test    edx, edx
    jnz     .fail_jpeg_huffman
    mov     rdi, jpeg_huff
    mov     rsi, jpeg_reader
    call    er_jpeg_huffman_decode
    cmp     eax, 0x33
    jne     .fail_jpeg_huffman
    test    edx, edx
    jnz     .fail_jpeg_huffman
    inc     qword [rel passed]
    jmp     .jpeg_receive_extend
.fail_jpeg_huffman:
    inc     qword [rel failed]

.jpeg_receive_extend:
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_receive_negative_bits
    mov     edx, jpeg_receive_negative_bits_len
    call    er_jpeg_bit_reader_init
    mov     rdi, jpeg_reader
    mov     esi, 3
    call    er_jpeg_receive_extend
    cmp     eax, -6
    jne     .fail_jpeg_receive_extend
    test    edx, edx
    jnz     .fail_jpeg_receive_extend
    inc     qword [rel passed]
    jmp     .jpeg_decode_block
.fail_jpeg_receive_extend:
    inc     qword [rel failed]

.jpeg_decode_block:
    mov     word [rel jpeg_quant], 2
    mov     eax, 1
.jpeg_quant_loop:
    cmp     eax, JPEG_BLOCK_LEN
    jae     .jpeg_tables
    mov     word [rel jpeg_quant + rax * 2], 1
    inc     eax
    jmp     .jpeg_quant_loop
.jpeg_tables:
    mov     word [rel jpeg_prev_dc], 4
    mov     rdi, jpeg_dc_counts
    mov     rsi, jpeg_dc_values
    mov     edx, jpeg_dc_values_len
    mov     rcx, jpeg_huff
    call    er_jpeg_build_huffman_table
    cmp     eax, 1
    jne     .fail_jpeg_decode_block
    test    edx, edx
    jnz     .fail_jpeg_decode_block
    mov     rdi, jpeg_ac_counts
    mov     rsi, jpeg_ac_values
    mov     edx, jpeg_ac_values_len
    mov     rcx, jpeg_huff_ac
    call    er_jpeg_build_huffman_table
    cmp     eax, 1
    jne     .fail_jpeg_decode_block
    test    edx, edx
    jnz     .fail_jpeg_decode_block
    mov     rdi, jpeg_reader
    mov     rsi, jpeg_block_bits
    mov     edx, jpeg_block_bits_len
    call    er_jpeg_bit_reader_init
    mov     rdi, jpeg_huff
    mov     rsi, jpeg_huff_ac
    mov     rdx, jpeg_quant
    mov     rcx, jpeg_prev_dc
    mov     r8, jpeg_reader
    mov     r9, jpeg_block
    call    er_jpeg_decode_block
    cmp     eax, 1
    jne     .fail_jpeg_decode_block
    test    edx, edx
    jnz     .fail_jpeg_decode_block
    cmp     word [rel jpeg_prev_dc], 7
    jne     .fail_jpeg_decode_block
    cmp     word [rel jpeg_block], 14
    jne     .fail_jpeg_decode_block
    cmp     word [rel jpeg_block + 2], 0
    jne     .fail_jpeg_decode_block
    inc     qword [rel passed]
    jmp     .jpeg_color_helpers
.fail_jpeg_decode_block:
    inc     qword [rel failed]

.jpeg_color_helpers:
    mov     edi, -3
    call    er_jpeg_clamp_u8
    test    eax, eax
    jnz     .fail_jpeg_color_helpers
    test    edx, edx
    jnz     .fail_jpeg_color_helpers
    mov     edi, 300
    call    er_jpeg_clamp_u8
    cmp     eax, 255
    jne     .fail_jpeg_color_helpers
    test    edx, edx
    jnz     .fail_jpeg_color_helpers
    mov     edi, 32
    call    er_jpeg_gray_color
    cmp     eax, 0xff202020
    jne     .fail_jpeg_color_helpers
    test    edx, edx
    jnz     .fail_jpeg_color_helpers
    mov     edi, 128
    mov     esi, 128
    mov     edx, 128
    call    er_jpeg_ycbcr_color
    cmp     eax, 0xff808080
    jne     .fail_jpeg_color_helpers
    test    edx, edx
    jnz     .fail_jpeg_color_helpers
    mov     edi, 255
    mov     esi, 128
    mov     edx, 128
    call    er_jpeg_ycbcr_color
    cmp     eax, 0xffffffff
    jne     .fail_jpeg_color_helpers
    test    edx, edx
    jnz     .fail_jpeg_color_helpers
    inc     qword [rel passed]
    jmp     .jpeg_idct_sample
.fail_jpeg_color_helpers:
    inc     qword [rel failed]

.jpeg_idct_sample:
    xor     eax, eax
.jpeg_idct_clear_loop:
    cmp     eax, JPEG_BLOCK_LEN
    jae     .jpeg_idct_run
    mov     word [rel jpeg_block + rax * 2], 0
    inc     eax
    jmp     .jpeg_idct_clear_loop
.jpeg_idct_run:
    mov     word [rel jpeg_block], 80
    mov     rdi, jpeg_block
    xor     esi, esi
    xor     edx, edx
    call    er_jpeg_idct_sample
    cmp     eax, 138
    jne     .fail_jpeg_idct_sample
    test    edx, edx
    jnz     .fail_jpeg_idct_sample
    mov     rdi, jpeg_block
    mov     esi, 7
    mov     edx, 7
    call    er_jpeg_idct_sample
    cmp     eax, 138
    jne     .fail_jpeg_idct_sample
    test    edx, edx
    jnz     .fail_jpeg_idct_sample
    inc     qword [rel passed]
    jmp     .jpeg_sample_component
.fail_jpeg_idct_sample:
    inc     qword [rel failed]

.jpeg_sample_component:
    xor     eax, eax
.jpeg_component_clear_loop:
    cmp     eax, JPEG_MAX_COMPONENT_BLOCKS * JPEG_BLOCK_LEN
    jae     .jpeg_component_run
    mov     word [rel jpeg_component_blocks + rax * 2], 0
    inc     eax
    jmp     .jpeg_component_clear_loop
.jpeg_component_run:
    mov     word [rel jpeg_component_blocks], 80
    mov     word [rel jpeg_component_blocks + JPEG_BLOCK_LEN * 2], 160
    mov     rdi, jpeg_component_blocks
    mov     esi, 0x11
    mov     edx, 1
    mov     ecx, 1
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_jpeg_sample_component
    cmp     eax, 138
    jne     .fail_jpeg_sample_component
    test    edx, edx
    jnz     .fail_jpeg_sample_component
    mov     rdi, jpeg_component_blocks
    mov     esi, 0x21
    mov     edx, 2
    mov     ecx, 1
    mov     r8d, 8
    xor     r9d, r9d
    call    er_jpeg_sample_component
    cmp     eax, 148
    jne     .fail_jpeg_sample_component
    test    edx, edx
    jnz     .fail_jpeg_sample_component
    inc     qword [rel passed]
    jmp     .jpeg_state_parsers
.fail_jpeg_sample_component:
    inc     qword [rel failed]

.jpeg_state_parsers:
    mov     rdi, jpeg_state
    call    er_jpeg_state_init
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_MAX_H_OFF], 1
    jne     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_MAX_V_OFF], 1
    jne     .fail_jpeg_state_parsers
    mov     rdi, jpeg_dqt_payload
    mov     esi, jpeg_dqt_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dqt
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_QUANT_READY_OFF + 2], 1
    jne     .fail_jpeg_state_parsers
    cmp     word [rel jpeg_state + JPEG_STATE_QUANT_OFF + 2 * JPEG_BLOCK_LEN * 2], 5
    jne     .fail_jpeg_state_parsers
    cmp     word [rel jpeg_state + JPEG_STATE_QUANT_OFF + 2 * JPEG_BLOCK_LEN * 2 + 63 * 2], 68
    jne     .fail_jpeg_state_parsers
    mov     rdi, jpeg_sof0_payload
    mov     esi, jpeg_sof0_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_sof0
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_WIDTH_OFF], 2
    jne     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_HEIGHT_OFF], 3
    jne     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_COMPONENT_COUNT_OFF], 3
    jne     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_MAX_H_OFF], 2
    jne     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_SAMPLING_OFF], 0x21
    jne     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_SIZE + JPEG_COMPONENT_QUANT_ID_OFF], 1
    jne     .fail_jpeg_state_parsers
    mov     rdi, jpeg_dht_payload
    mov     esi, jpeg_dht_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dht
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_DC_TABLES_OFF + JPEG_HUFF_TABLE_SIZE + JPEG_HUFF_TABLE_READY_OFF], 1
    jne     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_DC_TABLES_OFF + JPEG_HUFF_TABLE_SIZE + JPEG_HUFF_TABLE_SYMBOLS_OFF + JPEG_HUFF_VALUE_OFF], 0x02
    jne     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_AC_TABLES_OFF + 2 * JPEG_HUFF_TABLE_SIZE + JPEG_HUFF_TABLE_READY_OFF], 1
    jne     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_AC_TABLES_OFF + 2 * JPEG_HUFF_TABLE_SIZE + JPEG_HUFF_TABLE_SYMBOLS_OFF + JPEG_HUFF_VALUE_OFF], 0x00
    jne     .fail_jpeg_state_parsers
    mov     rdi, jpeg_sos_payload
    mov     esi, jpeg_sos_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_sos
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_DC_TABLE_OFF], 1
    jne     .fail_jpeg_state_parsers
    cmp     byte [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_AC_TABLE_OFF], 2
    jne     .fail_jpeg_state_parsers
    mov     rdi, jpeg_dri_payload
    mov     esi, jpeg_dri_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dri
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     dword [rel jpeg_state + JPEG_STATE_RESTART_INTERVAL_OFF], 4
    jne     .fail_jpeg_state_parsers
    mov     word [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_PREV_DC_OFF], 11
    mov     word [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_SIZE + JPEG_COMPONENT_PREV_DC_OFF], 22
    mov     word [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + 2 * JPEG_COMPONENT_SIZE + JPEG_COMPONENT_PREV_DC_OFF], 33
    mov     rdi, jpeg_state
    call    er_jpeg_reset_dc
    cmp     eax, 1
    jne     .fail_jpeg_state_parsers
    test    edx, edx
    jnz     .fail_jpeg_state_parsers
    cmp     word [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_PREV_DC_OFF], 0
    jne     .fail_jpeg_state_parsers
    cmp     word [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_SIZE + JPEG_COMPONENT_PREV_DC_OFF], 0
    jne     .fail_jpeg_state_parsers
    cmp     word [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + 2 * JPEG_COMPONENT_SIZE + JPEG_COMPONENT_PREV_DC_OFF], 0
    jne     .fail_jpeg_state_parsers
    inc     qword [rel passed]
    jmp     .jpeg_parse_fixture
.fail_jpeg_state_parsers:
    inc     qword [rel failed]

.jpeg_parse_fixture:
    mov     rdi, jpeg_state
    call    er_jpeg_state_init
    mov     rdi, jpeg_parse_fixture
    mov     esi, jpeg_parse_fixture_len
    mov     rdx, jpeg_state
    mov     ecx, 1
    mov     r8, jpeg_scan_offset
    call    er_jpeg_parse
    cmp     eax, 1
    jne     .fail_jpeg_parse_fixture
    test    edx, edx
    jnz     .fail_jpeg_parse_fixture
    cmp     qword [rel jpeg_scan_offset], jpeg_parse_fixture_scan_offset
    jne     .fail_jpeg_parse_fixture
    cmp     dword [rel jpeg_state + JPEG_STATE_WIDTH_OFF], 2
    jne     .fail_jpeg_parse_fixture
    cmp     byte [rel jpeg_state + JPEG_STATE_COMPONENTS_OFF + JPEG_COMPONENT_AC_TABLE_OFF], 2
    jne     .fail_jpeg_parse_fixture
    cmp     dword [rel jpeg_state + JPEG_STATE_DC_TABLES_OFF + JPEG_HUFF_TABLE_SIZE + JPEG_HUFF_TABLE_READY_OFF], 1
    jne     .fail_jpeg_parse_fixture
    inc     qword [rel passed]
    jmp     .jpeg_decode_scan_gray
.fail_jpeg_parse_fixture:
    inc     qword [rel failed]

.jpeg_decode_scan_gray:
    mov     rdi, jpeg_state
    call    er_jpeg_state_init
    mov     rdi, jpeg_gray_dqt_payload
    mov     esi, jpeg_gray_dqt_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dqt
    mov     rdi, jpeg_gray_dht_payload
    mov     esi, jpeg_gray_dht_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dht
    mov     rdi, jpeg_gray_sof0_payload
    mov     esi, jpeg_gray_sof0_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_sof0
    mov     rdi, jpeg_gray_sos_payload
    mov     esi, jpeg_gray_sos_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_sos
    mov     rdi, jpeg_state
    mov     rsi, jpeg_gray_scan
    mov     edx, jpeg_gray_scan_len
    mov     rcx, jpeg_scan_pixels
    mov     r8d, 1
    mov     r9, jpeg_scan_scratch
    push    JPEG_SCAN_SCRATCH_SIZE
    call    er_jpeg_decode_scan_gray
    add     rsp, 8
    cmp     eax, 1
    jne     .fail_jpeg_decode_scan_gray
    test    edx, edx
    jnz     .fail_jpeg_decode_scan_gray
    cmp     dword [rel jpeg_scan_pixels], 0xff8a8a8a
    jne     .fail_jpeg_decode_scan_gray
    mov     rdi, jpeg_state
    call    er_jpeg_state_init
    mov     rdi, jpeg_gray_dqt_payload
    mov     esi, jpeg_gray_dqt_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dqt
    mov     rdi, jpeg_gray_dht_payload
    mov     esi, jpeg_gray_dht_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dht
    mov     rdi, jpeg_gray_sof0_w9_payload
    mov     esi, jpeg_gray_sof0_w9_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_sof0
    mov     rdi, jpeg_gray_sos_payload
    mov     esi, jpeg_gray_sos_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_sos
    mov     rdi, jpeg_dri_payload
    mov     esi, jpeg_dri_payload_len
    mov     rdx, jpeg_state
    call    er_jpeg_parse_dri
    mov     dword [rel jpeg_state + JPEG_STATE_RESTART_INTERVAL_OFF], 1
    mov     rdi, jpeg_state
    mov     rsi, jpeg_gray_restart_scan
    mov     edx, jpeg_gray_restart_scan_len
    mov     rcx, jpeg_restart_pixels
    mov     r8d, 9
    mov     r9, jpeg_scan_scratch
    push    JPEG_SCAN_SCRATCH_SIZE
    call    er_jpeg_decode_scan_gray
    add     rsp, 8
    cmp     eax, 9
    jne     .fail_jpeg_decode_scan_gray
    test    edx, edx
    jnz     .fail_jpeg_decode_scan_gray
    cmp     dword [rel jpeg_restart_pixels], 0xff8a8a8a
    jne     .fail_jpeg_decode_scan_gray
    cmp     dword [rel jpeg_restart_pixels + 8 * 4], 0xff8a8a8a
    jne     .fail_jpeg_decode_scan_gray
    inc     qword [rel passed]
    jmp     .jpeg_decode_full_gray
.fail_jpeg_decode_scan_gray:
    inc     qword [rel failed]

.jpeg_decode_full_gray:
    mov     rdi, jpeg_gray_full
    mov     esi, jpeg_gray_full_len
    mov     rdx, jpeg_decode_pixels
    mov     ecx, 1
    mov     r8, jpeg_decode_scratch
    mov     r9d, JPEG_DECODE_SCRATCH_SIZE
    push    hdr
    call    er_image_decode_jpeg
    add     rsp, 8
    cmp     eax, 1
    jne     .fail_jpeg_decode_full_gray
    test    edx, edx
    jnz     .fail_jpeg_decode_full_gray
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 1
    jne     .fail_jpeg_decode_full_gray
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 1
    jne     .fail_jpeg_decode_full_gray
    cmp     dword [rel jpeg_decode_pixels], 0xff8a8a8a
    jne     .fail_jpeg_decode_full_gray
    inc     qword [rel passed]
    jmp     .png_is
.fail_jpeg_decode_full_gray:
    inc     qword [rel failed]

.png_is:
    mov     rdi, png_minimal
    mov     esi, png_minimal_len
    call    er_image_is_png
    cmp     eax, 1
    jne     .fail_png_is
    test    edx, edx
    jnz     .fail_png_is
    inc     qword [rel passed]
    jmp     .jxl_kind
.fail_png_is:
    inc     qword [rel failed]

.jxl_kind:
    mov     rdi, jxl_codestream
    mov     esi, jxl_codestream_len
    call    er_image_jxl_kind
    cmp     eax, IMAGE_JXL_KIND_CODESTREAM
    jne     .fail_jxl_kind
    test    edx, edx
    jnz     .fail_jxl_kind
    mov     rdi, jxl_container
    mov     esi, jxl_container_len
    call    er_image_jxl_kind
    cmp     eax, IMAGE_JXL_KIND_CONTAINER
    jne     .fail_jxl_kind
    test    edx, edx
    jnz     .fail_jxl_kind
    inc     qword [rel passed]
    jmp     .tga_is
.fail_jxl_kind:
    inc     qword [rel failed]

.tga_is:
    mov     rdi, tga_rgba
    mov     esi, tga_rgba_len
    call    er_image_is_tga
    cmp     eax, 1
    jne     .fail_tga_is
    test    edx, edx
    jnz     .fail_tga_is
    inc     qword [rel passed]
    jmp     .detect_order
.fail_tga_is:
    inc     qword [rel failed]

.detect_order:
    mov     rdi, jpeg_minimal
    mov     esi, jpeg_minimal_len
    call    er_image_detect_import_format
    cmp     eax, IMAGE_FORMAT_JPEG
    jne     .fail_detect_order
    test    edx, edx
    jnz     .fail_detect_order
    mov     rdi, jxl_codestream
    mov     esi, jxl_codestream_len
    call    er_image_detect_import_format
    cmp     eax, IMAGE_FORMAT_JXL
    jne     .fail_detect_order
    mov     rdi, png_minimal
    mov     esi, png_minimal_len
    call    er_image_detect_import_format
    cmp     eax, IMAGE_FORMAT_PNG
    jne     .fail_detect_order
    mov     rdi, tga_rgba
    mov     esi, tga_rgba_len
    call    er_image_detect_import_format
    cmp     eax, IMAGE_FORMAT_TGA
    jne     .fail_detect_order
    inc     qword [rel passed]
    jmp     .jpeg_header
.fail_detect_order:
    inc     qword [rel failed]

.jpeg_header:
    mov     rdi, jpeg_minimal
    mov     esi, jpeg_minimal_len
    mov     rdx, hdr
    call    er_image_decode_jpeg_header
    cmp     eax, IMAGE_HEADER_SIZE
    jne     .fail_jpeg_header
    test    edx, edx
    jnz     .fail_jpeg_header
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 2
    jne     .fail_jpeg_header
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 3
    jne     .fail_jpeg_header
    inc     qword [rel passed]
    jmp     .png_header
.fail_jpeg_header:
    inc     qword [rel failed]

.png_header:
    mov     rdi, png_minimal
    mov     esi, png_minimal_len
    mov     rdx, hdr
    call    er_image_decode_png_header
    cmp     eax, IMAGE_HEADER_SIZE
    jne     .fail_png_header
    test    edx, edx
    jnz     .fail_png_header
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 2
    jne     .fail_png_header
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 3
    jne     .fail_png_header
    inc     qword [rel passed]
    jmp     .png_bad_crc
.fail_png_header:
    inc     qword [rel failed]

.png_bad_crc:
    mov     rdi, png_bad_crc
    mov     esi, png_bad_crc_len
    mov     rdx, hdr
    call    er_image_decode_png_header
    test    eax, eax
    jnz     .fail_png_bad_crc
    cmp     edx, ERROR_CORRUPT
    jne     .fail_png_bad_crc
    inc     qword [rel passed]
    jmp     .png_unfilter
.fail_png_bad_crc:
    inc     qword [rel failed]

.png_unfilter:
    mov     rdi, png_filter_scanlines
    mov     esi, png_filter_scanlines_len
    mov     edx, 3
    mov     ecx, 5
    mov     r8d, 1
    call    er_png_unfilter
    cmp     eax, png_filter_scanlines_len
    jne     .fail_png_unfilter
    test    edx, edx
    jnz     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 1], 10
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 2], 20
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 3], 30
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 5], 1
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 6], 2
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 7], 3
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 9], 6
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 10], 7
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 11], 8
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 13], 9
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 14], 10
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 15], 11
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 17], 12
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 18], 13
    jne     .fail_png_unfilter
    cmp     byte [rel png_filter_scanlines + 19], 14
    jne     .fail_png_unfilter
    inc     qword [rel passed]
    jmp     .png_write_gray_alpha
.fail_png_unfilter:
    inc     qword [rel failed]

.png_write_gray_alpha:
    mov     rdi, png_gray_alpha_scanline
    mov     esi, png_gray_alpha_scanline_len
    mov     edx, 2
    mov     ecx, 1
    mov     r8d, 2
    mov     r9, png_pixels
    push    2
    call    er_png_write_pixels
    add     rsp, 8
    cmp     eax, 2
    jne     .fail_png_write_gray_alpha
    test    edx, edx
    jnz     .fail_png_write_gray_alpha
    cmp     dword [rel png_pixels], 0x80202020
    jne     .fail_png_write_gray_alpha
    cmp     dword [rel png_pixels + 4], 0x40e0e0e0
    jne     .fail_png_write_gray_alpha
    inc     qword [rel passed]
    jmp     .png_write_rgba
.fail_png_write_gray_alpha:
    inc     qword [rel failed]

.png_write_rgba:
    mov     rdi, png_rgba_scanline
    mov     esi, png_rgba_scanline_len
    mov     edx, 2
    mov     ecx, 1
    mov     r8d, 4
    mov     r9, png_pixels
    push    2
    call    er_png_write_pixels
    add     rsp, 8
    cmp     eax, 2
    jne     .fail_png_write_rgba
    test    edx, edx
    jnz     .fail_png_write_rgba
    cmp     dword [rel png_pixels], 0xff0000ff
    jne     .fail_png_write_rgba
    cmp     dword [rel png_pixels + 4], 0x8000ff00
    jne     .fail_png_write_rgba
    inc     qword [rel passed]
    jmp     .zlib_stored
.fail_png_write_rgba:
    inc     qword [rel failed]

.zlib_stored:
    mov     rdi, zlib_stored_gray
    mov     esi, zlib_stored_gray_len
    mov     rdx, inflate_out
    mov     ecx, 16
    call    er_zlib_inflate_stored
    cmp     eax, 3
    jne     .fail_zlib_stored
    test    edx, edx
    jnz     .fail_zlib_stored
    cmp     byte [rel inflate_out], PNG_FILTER_NONE
    jne     .fail_zlib_stored
    cmp     byte [rel inflate_out + 1], 0x20
    jne     .fail_zlib_stored
    cmp     byte [rel inflate_out + 2], 0xe0
    jne     .fail_zlib_stored
    inc     qword [rel passed]
    jmp     .zlib_bad_adler
.fail_zlib_stored:
    inc     qword [rel failed]

.zlib_bad_adler:
    mov     rdi, zlib_stored_bad_adler
    mov     esi, zlib_stored_bad_adler_len
    mov     rdx, inflate_out
    mov     ecx, 16
    call    er_zlib_inflate_stored
    test    eax, eax
    jnz     .fail_zlib_bad_adler
    cmp     edx, ERROR_CORRUPT
    jne     .fail_zlib_bad_adler
    inc     qword [rel passed]
    jmp     .zlib_fixed_backref
.fail_zlib_bad_adler:
    inc     qword [rel failed]

.zlib_fixed_backref:
    mov     rdi, zlib_fixed_backref
    mov     esi, zlib_fixed_backref_len
    mov     rdx, inflate_out
    mov     ecx, 16
    call    er_zlib_inflate_stored
    cmp     eax, 12
    jne     .fail_zlib_fixed_backref
    test    edx, edx
    jnz     .fail_zlib_fixed_backref
    cmp     dword [rel inflate_out], 0x61636261
    jne     .fail_zlib_fixed_backref
    cmp     dword [rel inflate_out + 4], 0x62616362
    jne     .fail_zlib_fixed_backref
    cmp     dword [rel inflate_out + 8], 0x63626163
    jne     .fail_zlib_fixed_backref
    inc     qword [rel passed]
    jmp     .zlib_dynamic_literals
.fail_zlib_fixed_backref:
    inc     qword [rel failed]

.zlib_dynamic_literals:
    mov     rdi, zlib_dynamic_literals
    mov     esi, zlib_dynamic_literals_len
    mov     rdx, inflate_out
    mov     ecx, 16
    call    er_zlib_inflate_stored
    test    edx, edx
    jnz     .fail_zlib_dynamic_err
    cmp     eax, 2
    jne     .fail_zlib_dynamic_len
    cmp     byte [rel inflate_out], 'h'
    jne     .fail_zlib_dynamic_byte0
    cmp     byte [rel inflate_out + 1], 'i'
    jne     .fail_zlib_dynamic_byte1
    inc     qword [rel passed]
    jmp     .zlib_dynamic_backref
.fail_zlib_dynamic_literals:
    inc     qword [rel failed]
    jmp     .png_decode_stored
.fail_zlib_dynamic_len:
    inc     qword [rel failed]
    jmp     .png_decode_stored
.fail_zlib_dynamic_err:
    inc     qword [rel failed]
    jmp     .png_decode_stored
.fail_zlib_dynamic_byte0:
    inc     qword [rel failed]
    jmp     .png_decode_stored
.fail_zlib_dynamic_byte1:
    inc     qword [rel failed]
    jmp     .png_decode_stored

.zlib_dynamic_backref:
    mov     rdi, zlib_dynamic_backref
    mov     esi, zlib_dynamic_backref_len
    mov     rdx, inflate_out
    mov     ecx, 128
    call    er_zlib_inflate_stored
    cmp     eax, 100
    jne     .fail_zlib_dynamic_backref
    test    edx, edx
    jnz     .fail_zlib_dynamic_backref
    cmp     dword [rel inflate_out], 0x65726f4c
    jne     .fail_zlib_dynamic_backref
    cmp     dword [rel inflate_out + 56], 0x726f4c20
    jne     .fail_zlib_dynamic_backref
    cmp     dword [rel inflate_out + 96], 0x69646120
    jne     .fail_zlib_dynamic_backref
    inc     qword [rel passed]
    jmp     .png_decode_stored
.fail_zlib_dynamic_backref:
    inc     qword [rel failed]
    jmp     .png_decode_stored

.png_decode_stored:
    mov     rdi, png_gray_stored
    mov     esi, png_gray_stored_len
    mov     rdx, png_pixels
    mov     ecx, 2
    mov     r8, png_scratch
    mov     r9d, 64
    push    hdr
    call    er_image_decode_png_stored
    add     rsp, 8
    cmp     eax, 2
    jne     .fail_png_decode_stored
    test    edx, edx
    jnz     .fail_png_decode_stored
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 2
    jne     .fail_png_decode_stored
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 1
    jne     .fail_png_decode_stored
    cmp     dword [rel png_pixels], 0xff202020
    jne     .fail_png_decode_stored
    cmp     dword [rel png_pixels + 4], 0xffe0e0e0
    jne     .fail_png_decode_stored
    inc     qword [rel passed]
    jmp     .png_decode_fixed
.fail_png_decode_stored:
    inc     qword [rel failed]

.png_decode_fixed:
    mov     rdi, png_rgba_fixed
    mov     esi, png_rgba_fixed_len
    mov     rdx, png_pixels
    mov     ecx, 2
    mov     r8, png_scratch
    mov     r9d, 64
    push    hdr
    call    er_image_decode_png_stored
    add     rsp, 8
    cmp     eax, 2
    jne     .fail_png_decode_fixed
    test    edx, edx
    jnz     .fail_png_decode_fixed
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 2
    jne     .fail_png_decode_fixed
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 1
    jne     .fail_png_decode_fixed
    cmp     dword [rel png_pixels], 0xff0000ff
    jne     .fail_png_decode_fixed
    cmp     dword [rel png_pixels + 4], 0x8000ff00
    jne     .fail_png_decode_fixed
    inc     qword [rel passed]
    jmp     .tga_header
.fail_png_decode_fixed:
    inc     qword [rel failed]

.tga_header:
    mov     rdi, tga_rgba
    mov     esi, tga_rgba_len
    mov     rdx, hdr
    call    er_image_decode_tga_header
    cmp     eax, IMAGE_HEADER_SIZE
    jne     .fail_tga_header
    test    edx, edx
    jnz     .fail_tga_header
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 2
    jne     .fail_tga_header
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 2
    jne     .fail_tga_header
    inc     qword [rel passed]
    jmp     .tga_decode
.fail_tga_header:
    inc     qword [rel failed]

.tga_decode:
    mov     rdi, tga_rgba
    mov     esi, tga_rgba_len
    mov     rdx, decoded_pixels
    mov     ecx, 4
    call    er_image_decode_tga
    cmp     eax, 4
    jne     .fail_tga_decode
    test    edx, edx
    jnz     .fail_tga_decode
    cmp     dword [rel decoded_pixels], 0xff0000ff
    jne     .fail_tga_decode
    cmp     dword [rel decoded_pixels + 4], 0x8000ff00
    jne     .fail_tga_decode
    cmp     dword [rel decoded_pixels + 8], 0x40ff0000
    jne     .fail_tga_decode
    cmp     dword [rel decoded_pixels + 12], 0x00ffffff
    jne     .fail_tga_decode
    inc     qword [rel passed]
    jmp     .tga_encode
.fail_tga_decode:
    inc     qword [rel failed]

.tga_encode:
    mov     rdi, expected_rgba_pixels
    mov     esi, 2
    mov     edx, 2
    mov     rcx, encoded_tga
    mov     r8d, TGA_HEADER_SIZE + 4 * 4 + TGA_FOOTER_SIZE
    call    er_image_encode_tga_rgba
    cmp     eax, TGA_HEADER_SIZE + 4 * 4 + TGA_FOOTER_SIZE
    jne     .fail_tga_encode
    test    edx, edx
    jnz     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_IMAGE_TYPE_INDEX], TGA_TYPE_TRUE_COLOR
    jne     .fail_tga_encode
    cmp     word [rel encoded_tga + TGA_WIDTH_INDEX], 2
    jne     .fail_tga_encode
    cmp     word [rel encoded_tga + TGA_HEIGHT_INDEX], 2
    jne     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_DEPTH_INDEX], TGA_DEPTH_RGBA
    jne     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_DESCRIPTOR_INDEX], TGA_DESCRIPTOR_RGBA_TOP_LEFT
    jne     .fail_tga_encode
    cmp     dword [rel encoded_tga + TGA_HEADER_SIZE], 0xffff0000
    jne     .fail_tga_encode
    cmp     dword [rel encoded_tga + TGA_HEADER_SIZE + 4], 0x8000ff00
    jne     .fail_tga_encode
    mov     rax, 0x4953495645555254
    cmp     qword [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 8], rax
    jne     .fail_tga_encode
    mov     rax, 0x454c4946582d4e4f
    cmp     qword [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 16], rax
    jne     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 24], '.'
    jne     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 25], 0
    jne     .fail_tga_encode
    inc     qword [rel passed]
    jmp     .erimg_len
.fail_tga_encode:
    inc     qword [rel failed]

.erimg_len:
    mov     edi, 3
    mov     esi, 2
    mov     edx, 2
    mov     ecx, 1
    call    er_image_runtime_payload_len
    cmp     eax, 24
    jne     .fail_erimg_len
    test    edx, edx
    jnz     .fail_erimg_len
    mov     edi, 3
    mov     esi, 2
    mov     edx, 2
    mov     ecx, 1
    call    er_image_runtime_canonical_len
    cmp     eax, ERIMG_HEADER_SIZE + 24
    jne     .fail_erimg_len
    test    edx, edx
    jnz     .fail_erimg_len
    inc     qword [rel passed]
    jmp     .erimg_single
.fail_erimg_len:
    inc     qword [rel failed]

.erimg_single:
    mov     rdi, erimg_pixels_2x1
    mov     esi, 2
    mov     edx, 2
    mov     ecx, 1
    mov     r8, encoded_erimg
    mov     r9d, ERIMG_HEADER_SIZE + 8
    call    er_image_runtime_encode_rgba
    cmp     eax, ERIMG_HEADER_SIZE + 8
    jne     .fail_erimg_single
    test    edx, edx
    jnz     .fail_erimg_single
    mov     rax, ERIMG_MAGIC
    cmp     qword [rel encoded_erimg + ERIMG_MAGIC_OFFSET], rax
    jne     .fail_erimg_single
    cmp     word [rel encoded_erimg + ERIMG_ABI_OFFSET], ERIMG_ABI_VERSION
    jne     .fail_erimg_single
    cmp     word [rel encoded_erimg + ERIMG_FORMAT_OFFSET], ERIMG_FORMAT_RGBA8
    jne     .fail_erimg_single
    cmp     dword [rel encoded_erimg + ERIMG_WIDTH_OFFSET], 2
    jne     .fail_erimg_single
    cmp     dword [rel encoded_erimg + ERIMG_HEIGHT_OFFSET], 1
    jne     .fail_erimg_single
    cmp     dword [rel encoded_erimg + ERIMG_TILE_COUNT_OFFSET], ERIMG_TILE_COUNT_SINGLE
    jne     .fail_erimg_single
    cmp     qword [rel encoded_erimg + ERIMG_PAYLOAD_LEN_OFFSET], 8
    jne     .fail_erimg_single
    mov     rax, 0x0807060504030201
    cmp     qword [rel encoded_erimg + ERIMG_HEADER_SIZE], rax
    jne     .fail_erimg_single
    mov     rdi, encoded_erimg
    mov     esi, ERIMG_HEADER_SIZE + 8
    mov     rdx, decoded_erimg
    mov     ecx, 2
    mov     r8, hdr
    call    er_image_runtime_decode_rgba
    cmp     eax, 2
    jne     .fail_erimg_single
    test    edx, edx
    jnz     .fail_erimg_single
    mov     rax, 0x0807060504030201
    cmp     qword [rel decoded_erimg], rax
    jne     .fail_erimg_single
    inc     qword [rel passed]
    jmp     .erimg_tiled
.fail_erimg_single:
    inc     qword [rel failed]

.erimg_tiled:
    mov     rdi, erimg_pixels_3x2
    mov     esi, 6
    mov     edx, 3
    mov     ecx, 2
    mov     r8d, 2
    mov     r9d, 1
    push    ERIMG_HEADER_SIZE + 24
    push    encoded_erimg
    call    er_image_runtime_encode_rgba_tiled
    add     rsp, 16
    cmp     eax, ERIMG_HEADER_SIZE + 24
    jne     .fail_erimg_tiled
    test    edx, edx
    jnz     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_TILE_COUNT_OFFSET], 4
    jne     .fail_erimg_tiled
    cmp     word [rel encoded_erimg + ERIMG_TILE_W_OFFSET], 2
    jne     .fail_erimg_tiled
    cmp     word [rel encoded_erimg + ERIMG_TILE_H_OFFSET], 1
    jne     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_HEADER_SIZE], 0xff000001
    jne     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_HEADER_SIZE + 4], 0xff000002
    jne     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_HEADER_SIZE + 8], 0xff000003
    jne     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_HEADER_SIZE + 12], 0xff000004
    jne     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_HEADER_SIZE + 16], 0xff000005
    jne     .fail_erimg_tiled
    cmp     dword [rel encoded_erimg + ERIMG_HEADER_SIZE + 20], 0xff000006
    jne     .fail_erimg_tiled
    mov     rdi, encoded_erimg
    mov     esi, ERIMG_HEADER_SIZE + 24
    mov     rdx, decoded_erimg
    mov     ecx, 6
    mov     r8, hdr
    call    er_image_runtime_decode_rgba
    cmp     eax, 6
    jne     .fail_erimg_tiled
    test    edx, edx
    jnz     .fail_erimg_tiled
    cmp     dword [rel decoded_erimg], 0xff000001
    jne     .fail_erimg_tiled
    cmp     dword [rel decoded_erimg + 4], 0xff000002
    jne     .fail_erimg_tiled
    cmp     dword [rel decoded_erimg + 8], 0xff000003
    jne     .fail_erimg_tiled
    cmp     dword [rel decoded_erimg + 12], 0xff000004
    jne     .fail_erimg_tiled
    cmp     dword [rel decoded_erimg + 16], 0xff000005
    jne     .fail_erimg_tiled
    cmp     dword [rel decoded_erimg + 20], 0xff000006
    jne     .fail_erimg_tiled
    inc     qword [rel passed]
    jmp     .import_header
.fail_erimg_tiled:
    inc     qword [rel failed]

.import_header:
    mov     rdi, png_minimal
    mov     esi, png_minimal_len
    mov     rdx, hdr
    call    er_image_decode_import_header
    cmp     eax, IMAGE_HEADER_SIZE
    jne     .fail_import_header
    test    edx, edx
    jnz     .fail_import_header
    cmp     dword [rel hdr + IMAGE_HEADER_WIDTH], 2
    jne     .fail_import_header
    cmp     dword [rel hdr + IMAGE_HEADER_HEIGHT], 3
    jne     .fail_import_header
    inc     qword [rel passed]
    jmp     .reject_unknown
.fail_import_header:
    inc     qword [rel failed]

.reject_unknown:
    mov     rdi, bad_bytes
    mov     esi, bad_bytes_len
    call    er_image_detect_import_format
    test    eax, eax
    jnz     .fail_reject_unknown
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_reject_unknown
    inc     qword [rel passed]
    jmp     .reject_jxl_header
.fail_reject_unknown:
    inc     qword [rel failed]

.reject_jxl_header:
    mov     rdi, jxl_codestream
    mov     esi, jxl_codestream_len
    mov     rdx, hdr
    call    er_image_decode_import_header
    test    eax, eax
    jnz     .fail_reject_jxl_header
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_reject_jxl_header
    inc     qword [rel passed]
    jmp     .done
.fail_reject_jxl_header:
    inc     qword [rel failed]
    jmp     .done

.done:
    TEST_EXIT_FAILED
