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
extern er_image_decode_import_header

TEST_BSS_PASSED_FAILED
hdr: resb IMAGE_HEADER_SIZE
decoded_pixels: resd 4
encoded_tga: resb TGA_HEADER_SIZE + 4 * 4 + TGA_FOOTER_SIZE

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
    dd 0
png_minimal_len equ $ - png_minimal

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

bad_bytes:
    db 'n', 'o', 't', '-', 'i', 'm', 'a', 'g', 'e'
bad_bytes_len equ $ - bad_bytes

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
    jmp     .png_is
.fail_jpeg_is:
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
    jmp     .tga_header
.fail_png_header:
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
    cmp     qword [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 8], 0x4953495645555254
    jne     .fail_tga_encode
    cmp     qword [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 16], 0x454c4946582d4e4f
    jne     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 24], '.'
    jne     .fail_tga_encode
    cmp     byte [rel encoded_tga + TGA_HEADER_SIZE + 4 * 4 + 25], 0
    jne     .fail_tga_encode
    inc     qword [rel passed]
    jmp     .import_header
.fail_tga_encode:
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
