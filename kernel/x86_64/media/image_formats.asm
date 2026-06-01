; EdgeRun still-image format/header parser — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/image_formats_constants.inc"

SECTION .text

; er_image_is_jpeg(buf, len) -> eax=1 if JPEG SOI, else 0
er_fn er_image_is_jpeg
    er_check_zero rdi, .no
    cmp     esi, 2
    jb      .no
    cmp     byte [rdi], JPEG_MARKER_PREFIX
    jne     .no
    cmp     byte [rdi + 1], JPEG_MARKER_SOI
    jne     .no
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret

; er_image_is_png(buf, len) -> eax=1 if PNG signature, else 0
er_fn er_image_is_png
    er_check_zero rdi, .no
    cmp     esi, PNG_SIGNATURE_SIZE
    jb      .no
    cmp     dword [rdi], PNG_SIGNATURE_HI
    jne     .no
    cmp     dword [rdi + 4], PNG_SIGNATURE_LO
    jne     .no
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret

; er_image_jxl_kind(buf, len) -> eax=kind, rdx=error
er_fn er_image_jxl_kind
    er_check_zero rdi, .invalid_param
    cmp     esi, 2
    jb      .unsupported
    cmp     word [rdi], JXL_CODESTREAM_SIGNATURE
    je      .codestream
    cmp     esi, JXL_CONTAINER_SIGNATURE_SIZE
    jb      .unsupported
    cmp     dword [rdi], JXL_CONTAINER_SIGNATURE_0
    jne     .unsupported
    cmp     dword [rdi + 4], JXL_CONTAINER_SIGNATURE_1
    jne     .unsupported
    cmp     dword [rdi + 8], JXL_CONTAINER_SIGNATURE_2
    jne     .unsupported
    mov     eax, IMAGE_JXL_KIND_CONTAINER
    er_ok
    er_ret
.codestream:
    mov     eax, IMAGE_JXL_KIND_CODESTREAM
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret

; er_image_is_jxl(buf, len) -> eax=1 if JPEG XL codestream/container, else 0
er_fn er_image_is_jxl
    call    er_image_jxl_kind
    test    edx, edx
    jnz     .no
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret

; er_image_is_tga(buf, len) -> eax=1 if supported true-color TGA header, else 0
er_fn er_image_is_tga
    er_check_zero rdi, .no
    cmp     esi, TGA_HEADER_SIZE
    jb      .no
    cmp     byte [rdi + TGA_COLOR_MAP_TYPE_INDEX], 0
    jne     .no
    cmp     byte [rdi + TGA_IMAGE_TYPE_INDEX], TGA_TYPE_TRUE_COLOR
    jne     .no
    movzx   eax, byte [rdi + TGA_DEPTH_INDEX]
    cmp     eax, TGA_DEPTH_RGB
    je      .yes
    cmp     eax, TGA_DEPTH_RGBA
    je      .yes
.no:
    xor     eax, eax
    er_ok
    er_ret
.yes:
    mov     eax, 1
    er_ok
    er_ret

; er_image_detect_import_format(buf, len) -> eax=IMAGE_FORMAT_*, rdx=error
er_fn er_image_detect_import_format
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12d, esi
    call    er_image_is_jpeg
    test    eax, eax
    jnz     .jpeg
    mov     rdi, rbx
    mov     esi, r12d
    call    er_image_is_jxl
    test    eax, eax
    jnz     .jxl
    mov     rdi, rbx
    mov     esi, r12d
    call    er_image_is_png
    test    eax, eax
    jnz     .png
    mov     rdi, rbx
    mov     esi, r12d
    call    er_image_is_tga
    test    eax, eax
    jnz     .tga
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.jpeg:
    mov     eax, IMAGE_FORMAT_JPEG
    er_ok
    jmp     .done
.jxl:
    mov     eax, IMAGE_FORMAT_JXL
    er_ok
    jmp     .done
.png:
    mov     eax, IMAGE_FORMAT_PNG
    er_ok
    jmp     .done
.tga:
    mov     eax, IMAGE_FORMAT_TGA
    er_ok
.done:
    er_pop  rbx, r12
    er_ret

; er_image_decode_tga_header(buf, len, out_header) -> eax=IMAGE_HEADER_SIZE, rdx=error
er_fn er_image_decode_tga_header
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, TGA_HEADER_SIZE
    jb      .corrupt
    cmp     byte [rdi + TGA_COLOR_MAP_TYPE_INDEX], 0
    jne     .unsupported
    cmp     byte [rdi + TGA_IMAGE_TYPE_INDEX], TGA_TYPE_TRUE_COLOR
    jne     .unsupported
    movzx   eax, byte [rdi + TGA_DEPTH_INDEX]
    cmp     eax, TGA_DEPTH_RGB
    je      .depth_ok
    cmp     eax, TGA_DEPTH_RGBA
    jne     .unsupported
.depth_ok:
    movzx   eax, word [rdi + TGA_WIDTH_INDEX]
    test    eax, eax
    jz      .corrupt
    movzx   ecx, word [rdi + TGA_HEIGHT_INDEX]
    test    ecx, ecx
    jz      .corrupt
    mov     [rdx + IMAGE_HEADER_WIDTH], eax
    mov     [rdx + IMAGE_HEADER_HEIGHT], ecx
    movzx   r8d, byte [rdi + TGA_ID_LEN_INDEX]
    cmp     byte [rdi + TGA_DEPTH_INDEX], TGA_DEPTH_RGB
    mov     r9d, 4
    jne     .have_bpp
    mov     r9d, 3
.have_bpp:
    imul    rax, rcx
    jo      .memory
    imul    rax, r9
    jo      .memory
    add     rax, TGA_HEADER_SIZE
    jc      .memory
    add     rax, r8
    jc      .memory
    cmp     rax, rsi
    ja      .corrupt
    mov     eax, IMAGE_HEADER_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_image_decode_tga(buf, len, out_pixels, out_count) -> eax=pixel_count, rdx=error
er_fn er_image_decode_tga
    er_push rbx, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, TGA_HEADER_SIZE
    jb      .corrupt
    cmp     byte [rdi + TGA_COLOR_MAP_TYPE_INDEX], 0
    jne     .unsupported
    cmp     byte [rdi + TGA_IMAGE_TYPE_INDEX], TGA_TYPE_TRUE_COLOR
    jne     .unsupported
    movzx   r10d, byte [rdi + TGA_DEPTH_INDEX]
    cmp     r10d, TGA_DEPTH_RGB
    je      .depth_rgb
    cmp     r10d, TGA_DEPTH_RGBA
    jne     .unsupported
    mov     r11d, 4
    jmp     .depth_ok
.depth_rgb:
    mov     r11d, 3
.depth_ok:
    movzx   r8d, word [rdi + TGA_WIDTH_INDEX]
    test    r8d, r8d
    jz      .corrupt
    movzx   r9d, word [rdi + TGA_HEIGHT_INDEX]
    test    r9d, r9d
    jz      .corrupt
    mov     eax, r8d
    imul    rax, r9
    jo      .memory
    cmp     rax, rcx
    ja      .no_space
    mov     r15, rax
    movzx   ebx, byte [rdi + TGA_ID_LEN_INDEX]
    mov     r12, r15
    imul    r12, r11
    jo      .memory
    add     r12, TGA_HEADER_SIZE
    jc      .memory
    add     r12, rbx
    jc      .memory
    cmp     r12, rsi
    ja      .corrupt
    lea     r12, [rdi + TGA_HEADER_SIZE + rbx]
    mov     r13, rdx
    mov     r14d, r8d
    mov     ebx, r9d
    xor     ecx, ecx
.row_loop:
    cmp     ecx, ebx
    jae     .ok
    test    byte [rdi + TGA_DESCRIPTOR_INDEX], TGA_ORIGIN_TOP
    jnz     .top_origin
    mov     eax, ebx
    dec     eax
    sub     eax, ecx
    jmp     .have_source_y
.top_origin:
    mov     eax, ecx
.have_source_y:
    imul    rax, r14
    imul    rax, r11
    lea     r8, [r12 + rax]
    mov     eax, ecx
    imul    rax, r14
    lea     r9, [r13 + rax * 4]
    xor     edx, edx
.col_loop:
    cmp     edx, r14d
    jae     .next_row
    movzx   eax, byte [r8 + 2]
    mov     [r9], al
    movzx   eax, byte [r8 + 1]
    mov     [r9 + 1], al
    movzx   eax, byte [r8]
    mov     [r9 + 2], al
    cmp     r11d, 4
    jne     .opaque
    movzx   eax, byte [r8 + 3]
    jmp     .store_alpha
.opaque:
    mov     eax, TGA_ALPHA_OPAQUE
.store_alpha:
    mov     [r9 + 3], al
    add     r8, r11
    add     r9, 4
    inc     edx
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     rax, r15
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    jmp     .done
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_image_encode_tga_rgba(pixels, width, height, out, out_cap) -> eax=byte_len, rdx=error
er_fn er_image_encode_tga_rgba
    er_push rbx, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero rcx, .invalid_param
    test    esi, esi
    jz      .corrupt
    test    edx, edx
    jz      .corrupt
    cmp     esi, 0xffff
    ja      .corrupt
    cmp     edx, 0xffff
    ja      .corrupt
    mov     r12, rdi
    mov     r13, rcx
    mov     r14d, esi
    mov     r15d, edx
    mov     eax, esi
    imul    rax, rdx
    jo      .memory
    mov     rbx, rax
    imul    rax, 4
    jo      .memory
    add     rax, TGA_HEADER_SIZE + TGA_FOOTER_SIZE
    jc      .memory
    cmp     rax, r8
    ja      .no_space
    mov     r9, rax
    xor     eax, eax
    xor     ecx, ecx
.zero_loop:
    cmp     rcx, r9
    jae     .header
    mov     [r13 + rcx], al
    inc     rcx
    jmp     .zero_loop
.header:
    mov     byte [r13 + TGA_IMAGE_TYPE_INDEX], TGA_TYPE_TRUE_COLOR
    mov     [r13 + TGA_WIDTH_INDEX], r14w
    mov     [r13 + TGA_HEIGHT_INDEX], r15w
    mov     byte [r13 + TGA_DEPTH_INDEX], TGA_DEPTH_RGBA
    mov     byte [r13 + TGA_DESCRIPTOR_INDEX], TGA_DESCRIPTOR_RGBA_TOP_LEFT
    lea     r10, [r13 + TGA_HEADER_SIZE]
    xor     ecx, ecx
.pixel_loop:
    cmp     rcx, rbx
    jae     .footer
    movzx   eax, byte [r12 + rcx * 4 + 2]
    mov     [r10], al
    movzx   eax, byte [r12 + rcx * 4 + 1]
    mov     [r10 + 1], al
    movzx   eax, byte [r12 + rcx * 4]
    mov     [r10 + 2], al
    movzx   eax, byte [r12 + rcx * 4 + 3]
    mov     [r10 + 3], al
    add     r10, 4
    inc     rcx
    jmp     .pixel_loop
.footer:
    add     r10, 8
    mov     qword [r10], 0x4953495645555254
    mov     qword [r10 + 8], 0x454c4946582d4e4f
    mov     byte [r10 + 16], '.'
    mov     byte [r10 + 17], 0
    mov     rax, r9
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    jmp     .done
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_image_decode_png_header(buf, len, out_header) -> eax=IMAGE_HEADER_SIZE, rdx=error
er_fn er_image_decode_png_header
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, PNG_SIGNATURE_SIZE + PNG_CHUNK_OVERHEAD + PNG_IHDR_SIZE
    jb      .corrupt
    cmp     dword [rdi], PNG_SIGNATURE_HI
    jne     .unsupported
    cmp     dword [rdi + 4], PNG_SIGNATURE_LO
    jne     .unsupported
    cmp     dword [rdi + PNG_SIGNATURE_SIZE], 0x0d000000
    jne     .corrupt
    cmp     dword [rdi + PNG_SIGNATURE_SIZE + 4], PNG_CHUNK_IHDR
    jne     .corrupt
    mov     eax, [rdi + PNG_SIGNATURE_SIZE + 8]
    bswap   eax
    test    eax, eax
    jz      .corrupt
    mov     ecx, [rdi + PNG_SIGNATURE_SIZE + 12]
    bswap   ecx
    test    ecx, ecx
    jz      .corrupt
    cmp     byte [rdi + PNG_SIGNATURE_SIZE + 16], PNG_BIT_DEPTH_U8
    jne     .unsupported
    movzx   r8d, byte [rdi + PNG_SIGNATURE_SIZE + 17]
    cmp     r8d, PNG_COLOR_GRAYSCALE
    je      .color_ok
    cmp     r8d, PNG_COLOR_RGB
    je      .color_ok
    cmp     r8d, PNG_COLOR_GRAYSCALE_ALPHA
    je      .color_ok
    cmp     r8d, PNG_COLOR_RGBA
    jne     .unsupported
.color_ok:
    cmp     byte [rdi + PNG_SIGNATURE_SIZE + 18], PNG_METHOD_DEFLATE
    jne     .unsupported
    cmp     byte [rdi + PNG_SIGNATURE_SIZE + 19], PNG_FILTER_STANDARD
    jne     .unsupported
    cmp     byte [rdi + PNG_SIGNATURE_SIZE + 20], PNG_INTERLACE_NONE
    jne     .unsupported
    mov     [rdx + IMAGE_HEADER_WIDTH], eax
    mov     [rdx + IMAGE_HEADER_HEIGHT], ecx
    mov     eax, IMAGE_HEADER_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_image_decode_jpeg_header(buf, len, out_header) -> eax=IMAGE_HEADER_SIZE, rdx=error
er_fn er_image_decode_jpeg_header
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, 4
    jb      .corrupt
    cmp     byte [rdi], JPEG_MARKER_PREFIX
    jne     .unsupported
    cmp     byte [rdi + 1], JPEG_MARKER_SOI
    jne     .unsupported
    mov     r12, rdi
    mov     r13, rdx
    mov     ebx, 2
.marker_loop:
    cmp     ebx, esi
    jae     .corrupt
.scan_prefix:
    cmp     ebx, esi
    jae     .corrupt
    cmp     byte [r12 + rbx], JPEG_MARKER_PREFIX
    je      .skip_prefix
    inc     ebx
    jmp     .scan_prefix
.skip_prefix:
    cmp     ebx, esi
    jae     .corrupt
    cmp     byte [r12 + rbx], JPEG_MARKER_PREFIX
    jne     .have_marker
    inc     ebx
    jmp     .skip_prefix
.have_marker:
    cmp     ebx, esi
    jae     .corrupt
    movzx   eax, byte [r12 + rbx]
    inc     ebx
    test    eax, eax
    jz      .corrupt
    cmp     eax, JPEG_MARKER_SOF0
    je      .sof0
    cmp     eax, JPEG_MARKER_SOF2
    je      .unsupported
    cmp     eax, JPEG_MARKER_SOS
    je      .corrupt
    cmp     eax, JPEG_MARKER_RST0
    jb      .skip_segment
    cmp     eax, JPEG_MARKER_RST7
    jbe     .corrupt
.skip_segment:
    mov     edx, esi
    sub     edx, ebx
    cmp     edx, 2
    jb      .corrupt
    movzx   edx, word [r12 + rbx]
    xchg    dl, dh
    cmp     edx, 2
    jb      .corrupt
    mov     ecx, esi
    sub     ecx, ebx
    cmp     edx, ecx
    ja      .corrupt
    add     ebx, edx
    jmp     .marker_loop
.sof0:
    mov     edx, esi
    sub     edx, ebx
    cmp     edx, 8
    jb      .corrupt
    movzx   edx, word [r12 + rbx]
    xchg    dl, dh
    cmp     edx, 8
    jb      .corrupt
    mov     ecx, esi
    sub     ecx, ebx
    cmp     edx, ecx
    ja      .corrupt
    cmp     byte [r12 + rbx + 2], JPEG_PRECISION_8
    jne     .unsupported
    movzx   ecx, word [r12 + rbx + 3]
    xchg    cl, ch
    test    ecx, ecx
    jz      .corrupt
    movzx   eax, word [r12 + rbx + 5]
    xchg    al, ah
    test    eax, eax
    jz      .corrupt
    movzx   edx, byte [r12 + rbx + 7]
    test    edx, edx
    jz      .corrupt
    cmp     edx, JPEG_MAX_COMPONENTS
    ja      .unsupported
    mov     [r13 + IMAGE_HEADER_WIDTH], eax
    mov     [r13 + IMAGE_HEADER_HEIGHT], ecx
    mov     eax, IMAGE_HEADER_SIZE
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_image_decode_import_header(buf, len, out_header) -> eax=IMAGE_HEADER_SIZE, rdx=error
er_fn er_image_decode_import_header
    er_push rbx, r12, r13
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    call    er_image_detect_import_format
    test    edx, edx
    jnz     .done
    cmp     eax, IMAGE_FORMAT_JPEG
    je      .jpeg
    cmp     eax, IMAGE_FORMAT_JXL
    je      .jxl
    cmp     eax, IMAGE_FORMAT_PNG
    je      .png
    cmp     eax, IMAGE_FORMAT_TGA
    je      .tga
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.jpeg:
    mov     rdi, rbx
    mov     esi, r12d
    mov     rdx, r13
    call    er_image_decode_jpeg_header
    jmp     .done
.jxl:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.png:
    mov     rdi, rbx
    mov     esi, r12d
    mov     rdx, r13
    call    er_image_decode_png_header
    jmp     .done
.tga:
    mov     rdi, rbx
    mov     esi, r12d
    mov     rdx, r13
    call    er_image_decode_tga_header
.done:
    er_pop  rbx, r12, r13
    er_ret
