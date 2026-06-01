; EdgeRun still-image format/header parser — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/image_formats_constants.inc"

SECTION .rodata
deflate_length_base:
    dw 3, 4, 5, 6, 7, 8, 9, 10
    dw 11, 13, 15, 17, 19, 23, 27, 31
    dw 35, 43, 51, 59, 67, 83, 99, 115
    dw 131, 163, 195, 227, 258
deflate_length_extra:
    db 0, 0, 0, 0, 0, 0, 0, 0
    db 1, 1, 1, 1, 2, 2, 2, 2
    db 3, 3, 3, 3, 4, 4, 4, 4
    db 5, 5, 5, 5, 0
deflate_distance_base:
    dw 1, 2, 3, 4, 5, 7, 9, 13
    dw 17, 25, 33, 49, 65, 97, 129, 193
    dw 257, 385, 513, 769, 1025, 1537, 2049, 3073
    dw 4097, 6145, 8193, 12289, 16385, 24577
deflate_distance_extra:
    db 0, 0, 0, 0, 1, 1, 2, 2
    db 3, 3, 4, 4, 5, 5, 6, 6
    db 7, 7, 8, 8, 9, 9, 10, 10
    db 11, 11, 12, 12, 13, 13
deflate_cl_order:
    db 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15

SECTION .bss
dyn_cl_len:      resb DEFLATE_CL_COUNT
dyn_cl_code:     resw DEFLATE_CL_COUNT
dyn_ll_len:      resb DEFLATE_LL_COUNT
dyn_ll_code:     resw DEFLATE_LL_COUNT
dyn_dist_len:    resb DEFLATE_DIST_COUNT
dyn_dist_code:   resw DEFLATE_DIST_COUNT
dyn_count:       resw DEFLATE_MAX_BITS + 1
dyn_next_code:   resw DEFLATE_MAX_BITS + 1
dyn_hlit:        resd 1
dyn_hdist:       resd 1
dyn_hclen:       resd 1
dyn_prev_len:    resd 1
dyn_match_len:   resd 1

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

; er_jpeg_bit_reader_init(state, bytes, len) -> eax=1, rdx=error
er_fn er_jpeg_bit_reader_init
    er_check_zero rdi, .invalid_param
    er_check_zero rsi, .invalid_param
    mov     [rdi + JPEG_BIT_READER_BYTES_OFF], rsi
    mov     [rdi + JPEG_BIT_READER_LEN_OFF], edx
    mov     dword [rdi + JPEG_BIT_READER_CURSOR_OFF], 0
    mov     byte [rdi + JPEG_BIT_READER_BUFFER_OFF], 0
    mov     byte [rdi + JPEG_BIT_READER_BITS_LEFT_OFF], 0
    mov     eax, 1
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_jpeg_next_entropy_byte(state) -> eax=byte, rdx=error
er_fn er_jpeg_next_entropy_byte
    er_check_zero rdi, .invalid_param
    mov     r8, [rdi + JPEG_BIT_READER_BYTES_OFF]
    mov     eax, [rdi + JPEG_BIT_READER_CURSOR_OFF]
    cmp     eax, [rdi + JPEG_BIT_READER_LEN_OFF]
    jae     .corrupt
    movzx   ecx, byte [r8 + rax]
    inc     eax
    mov     [rdi + JPEG_BIT_READER_CURSOR_OFF], eax
    cmp     ecx, JPEG_MARKER_PREFIX
    jne     .ok_byte
    cmp     eax, [rdi + JPEG_BIT_READER_LEN_OFF]
    jae     .corrupt
    movzx   ecx, byte [r8 + rax]
    inc     eax
    mov     [rdi + JPEG_BIT_READER_CURSOR_OFF], eax
    test    ecx, ecx
    jz      .stuffed
    cmp     ecx, JPEG_MARKER_SOI ; EOI/RST are corrupt during entropy bit reads; other markers unsupported.
    je      .corrupt
    cmp     ecx, JPEG_MARKER_RST0
    jb      .unsupported
    cmp     ecx, JPEG_MARKER_RST7
    jbe     .corrupt
    jmp     .unsupported
.stuffed:
    mov     eax, JPEG_MARKER_PREFIX
    er_ok
    er_ret
.ok_byte:
    mov     eax, ecx
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

; er_jpeg_read_bit(state) -> eax=bit, rdx=error
er_fn er_jpeg_read_bit
    er_check_zero rdi, .invalid_param
    cmp     byte [rdi + JPEG_BIT_READER_BITS_LEFT_OFF], 0
    jne     .have_bits
    call    er_jpeg_next_entropy_byte
    test    edx, edx
    jnz     .done
    mov     [rdi + JPEG_BIT_READER_BUFFER_OFF], al
    mov     byte [rdi + JPEG_BIT_READER_BITS_LEFT_OFF], 8
.have_bits:
    dec     byte [rdi + JPEG_BIT_READER_BITS_LEFT_OFF]
    movzx   ecx, byte [rdi + JPEG_BIT_READER_BITS_LEFT_OFF]
    movzx   eax, byte [rdi + JPEG_BIT_READER_BUFFER_OFF]
    shr     eax, cl
    and     eax, 1
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_ret

; er_jpeg_read_bits(state, count) -> eax=value, rdx=error
er_fn er_jpeg_read_bits
    er_push rbx, r12
    er_check_zero rdi, .invalid_param
    cmp     esi, JPEG_MAX_CODE_LEN
    ja      .corrupt
    mov     r12, rdi
    mov     ebx, esi
    xor     ecx, ecx
.loop:
    test    ebx, ebx
    jz      .ok
    mov     rdi, r12
    call    er_jpeg_read_bit
    test    edx, edx
    jnz     .done
    shl     ecx, 1
    or      ecx, eax
    dec     ebx
    jmp     .loop
.ok:
    mov     eax, ecx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12
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
    mov     rax, 0x4953495645555254
    mov     [r10], rax
    mov     rax, 0x454c4946582d4e4f
    mov     [r10 + 8], rax
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

; er_image_runtime_tile_count(width, height, tile_w, tile_h) -> eax=count, rdx=error
er_fn er_image_runtime_tile_count
    test    edi, edi
    jz      .corrupt
    test    esi, esi
    jz      .corrupt
    test    edx, edx
    jz      .corrupt
    test    ecx, ecx
    jz      .corrupt
    cmp     edi, ERIMG_MAX_DIMENSION
    ja      .corrupt
    cmp     esi, ERIMG_MAX_DIMENSION
    ja      .corrupt
    cmp     edx, edi
    ja      .corrupt
    cmp     ecx, esi
    ja      .corrupt
    mov     r8d, edx
    mov     r9d, ecx
    mov     eax, edi
    add     eax, r8d
    jc      .memory
    dec     eax
    xor     edx, edx
    div     r8d
    mov     r8d, eax
    mov     eax, esi
    add     eax, r9d
    jc      .memory
    dec     eax
    xor     edx, edx
    div     r9d
    imul    eax, r8d
    jo      .memory
    er_ok
    er_ret
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_image_runtime_payload_len(width, height, tile_w, tile_h) -> rax=payload bytes, rdx=error
er_fn er_image_runtime_payload_len
    er_push rbx
    mov     ebx, edi
    call    er_image_runtime_tile_count
    test    edx, edx
    jnz     .done
    mov     eax, ebx
    imul    rax, rsi
    jo      .memory
    imul    rax, 4
    jo      .memory
    er_ok
    jmp     .done
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
.done:
    er_pop  rbx
    er_ret

; er_image_runtime_canonical_len(width, height, tile_w, tile_h) -> rax=total bytes, rdx=error
er_fn er_image_runtime_canonical_len
    call    er_image_runtime_payload_len
    test    edx, edx
    jnz     .done
    add     rax, ERIMG_HEADER_SIZE
    jc      .memory
    er_ok
    er_ret
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
.done:
    er_ret

; er_image_runtime_encode_rgba_tiled(pixels, pixel_count, width, height, tile_w, tile_h, out, out_cap)
; -> rax=canonical byte length, rdx=error
er_fn er_image_runtime_encode_rgba_tiled
    mov     r10, [rsp + 8]
    mov     r11, [rsp + 16]
    er_push rbx, rbp, r12, r13, r14, r15
    er_stack_alloc 64
    er_check_zero rdi, .invalid_param
    er_check_zero r10, .invalid_param
    mov     [rsp + 0], rdi       ; pixels
    mov     [rsp + 8], r10       ; out
    mov     [rsp + 16], rsi      ; pixel_count
    mov     [rsp + 24], r11      ; out_cap
    mov     [rsp + 32], edx      ; width
    mov     [rsp + 36], ecx      ; height
    mov     [rsp + 40], r8d      ; tile_w
    mov     [rsp + 44], r9d      ; tile_h
    mov     edi, edx
    mov     esi, ecx
    mov     edx, r8d
    mov     ecx, r9d
    call    er_image_runtime_tile_count
    test    edx, edx
    jnz     .done
    mov     [rsp + 48], eax      ; tile_count
    mov     edi, [rsp + 32]
    mov     esi, [rsp + 36]
    mov     edx, [rsp + 40]
    mov     ecx, [rsp + 44]
    call    er_image_runtime_payload_len
    test    edx, edx
    jnz     .done
    mov     [rsp + 56], rax      ; payload_len
    mov     rbx, rax
    add     rbx, ERIMG_HEADER_SIZE
    jc      .memory
    cmp     rbx, [rsp + 24]
    ja      .no_space
    mov     eax, [rsp + 32]
    mov     ecx, [rsp + 36]
    imul    rax, rcx
    jo      .memory
    cmp     qword [rsp + 16], rax
    jb      .corrupt
    mov     r13, [rsp + 8]
    xor     eax, eax
    xor     ecx, ecx
.zero_header:
    cmp     ecx, ERIMG_HEADER_SIZE
    jae     .write_header
    mov     [r13 + rcx], al
    inc     ecx
    jmp     .zero_header
.write_header:
    mov     rax, ERIMG_MAGIC
    mov     [r13 + ERIMG_MAGIC_OFFSET], rax
    mov     word [r13 + ERIMG_ABI_OFFSET], ERIMG_ABI_VERSION
    mov     word [r13 + ERIMG_FORMAT_OFFSET], ERIMG_FORMAT_RGBA8
    mov     eax, [rsp + 32]
    mov     [r13 + ERIMG_WIDTH_OFFSET], eax
    mov     eax, [rsp + 36]
    mov     [r13 + ERIMG_HEIGHT_OFFSET], eax
    mov     ax, [rsp + 40]
    mov     [r13 + ERIMG_TILE_W_OFFSET], ax
    mov     ax, [rsp + 44]
    mov     [r13 + ERIMG_TILE_H_OFFSET], ax
    mov     eax, [rsp + 48]
    mov     [r13 + ERIMG_TILE_COUNT_OFFSET], eax
    mov     rax, [rsp + 56]
    mov     [r13 + ERIMG_PAYLOAD_LEN_OFFSET], rax
    lea     r15, [r13 + ERIMG_HEADER_SIZE]
    mov     r12, [rsp + 0]
    mov     r14d, [rsp + 32]     ; width
    mov     ebx, [rsp + 40]      ; tile_w
    mov     ebp, [rsp + 44]      ; tile_h
    xor     r8d, r8d             ; tile_y
.tile_y_loop:
    cmp     r8d, [rsp + 36]
    jae     .ok
    xor     r9d, r9d             ; tile_x
.tile_x_loop:
    cmp     r9d, r14d
    jae     .next_tile_y
    mov     r10d, ebx            ; bounds_w
    mov     eax, r14d
    sub     eax, r9d
    cmp     r10d, eax
    cmova   r10d, eax
    mov     r11d, ebp            ; bounds_h
    mov     eax, [rsp + 36]
    sub     eax, r8d
    cmp     r11d, eax
    cmova   r11d, eax
    xor     ecx, ecx             ; row in tile
.copy_tile_row:
    cmp     ecx, r11d
    jae     .next_tile_x
    mov     eax, r8d
    add     eax, ecx
    imul    rax, r14
    add     eax, r9d
    lea     rsi, [r12 + rax * 4]
    mov     eax, r10d
    shl     eax, 2
    xor     edx, edx
.copy_row_bytes:
    cmp     edx, eax
    jae     .row_done
    mov     dil, [rsi + rdx]
    mov     [r15 + rdx], dil
    inc     edx
    jmp     .copy_row_bytes
.row_done:
    add     r15, rax
    inc     ecx
    jmp     .copy_tile_row
.next_tile_x:
    add     r9d, ebx
    jmp     .tile_x_loop
.next_tile_y:
    add     r8d, ebp
    jmp     .tile_y_loop
.ok:
    mov     rax, [rsp + 56]
    add     rax, ERIMG_HEADER_SIZE
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
    er_stack_free 64
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret

; er_image_runtime_encode_rgba(pixels, pixel_count, width, height, out, out_cap)
; -> rax=canonical byte length, rdx=error
er_fn er_image_runtime_encode_rgba
    mov     r10, r8
    mov     r11, r9
    mov     r8d, edx
    mov     r9d, ecx
    push    r11
    push    r10
    call    er_image_runtime_encode_rgba_tiled
    add     rsp, 16
    er_ret

; er_image_runtime_decode_rgba(canonical, len, out_pixels, out_count, out_header)
; -> rax=pixel_count, rdx=error
er_fn er_image_runtime_decode_rgba
    er_push rbx, rbp, r12, r13, r14, r15
    er_stack_alloc 80
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero r8, .invalid_param
    cmp     esi, ERIMG_HEADER_SIZE
    jb      .corrupt
    mov     rax, ERIMG_MAGIC
    cmp     [rdi + ERIMG_MAGIC_OFFSET], rax
    jne     .unsupported
    cmp     word [rdi + ERIMG_ABI_OFFSET], ERIMG_ABI_VERSION
    jne     .unsupported
    cmp     word [rdi + ERIMG_FORMAT_OFFSET], ERIMG_FORMAT_RGBA8
    jne     .unsupported
    cmp     dword [rdi + ERIMG_FLAGS_OFFSET], 0
    jne     .corrupt
    mov     eax, [rdi + ERIMG_WIDTH_OFFSET]
    mov     [rsp + 32], eax
    mov     eax, [rdi + ERIMG_HEIGHT_OFFSET]
    mov     [rsp + 36], eax
    movzx   eax, word [rdi + ERIMG_TILE_W_OFFSET]
    mov     [rsp + 40], eax
    movzx   eax, word [rdi + ERIMG_TILE_H_OFFSET]
    mov     [rsp + 44], eax
    mov     eax, [rdi + ERIMG_TILE_COUNT_OFFSET]
    mov     [rsp + 48], eax
    mov     rax, [rdi + ERIMG_PAYLOAD_LEN_OFFSET]
    mov     [rsp + 56], rax
    mov     [rsp + 0], rdi       ; canonical
    mov     [rsp + 8], rdx       ; out pixels
    mov     [rsp + 16], r8       ; out header
    mov     [rsp + 64], rsi      ; canonical len
    mov     [rsp + 72], rcx      ; out pixel capacity
    lea     rax, [rdi + ERIMG_HEADER_SIZE]
    mov     [rsp + 24], rax      ; payload cursor base
    mov     edi, [rsp + 32]
    mov     esi, [rsp + 36]
    mov     edx, [rsp + 40]
    mov     ecx, [rsp + 44]
    call    er_image_runtime_tile_count
    test    edx, edx
    jnz     .corrupt
    cmp     eax, [rsp + 48]
    jne     .corrupt
    mov     edi, [rsp + 32]
    mov     esi, [rsp + 36]
    mov     edx, [rsp + 40]
    mov     ecx, [rsp + 44]
    call    er_image_runtime_payload_len
    test    edx, edx
    jnz     .done
    cmp     rax, [rsp + 56]
    jne     .corrupt
    add     rax, ERIMG_HEADER_SIZE
    jc      .memory
    cmp     rax, [rsp + 64]
    jne     .corrupt
    mov     eax, [rsp + 32]
    mov     ecx, [rsp + 36]
    imul    rax, rcx
    jo      .memory
    mov     r11, rax
    cmp     r11, qword [rsp + 72]
    ja      .no_space
    mov     r13, [rsp + 16]
    mov     eax, [rsp + 32]
    mov     [r13 + IMAGE_HEADER_WIDTH], eax
    mov     eax, [rsp + 36]
    mov     [r13 + IMAGE_HEADER_HEIGHT], eax
    mov     r12, [rsp + 24]      ; payload cursor
    mov     r13, [rsp + 8]       ; out pixels
    mov     r14d, [rsp + 32]     ; width
    mov     ebx, [rsp + 40]      ; tile_w
    mov     ebp, [rsp + 44]      ; tile_h
    xor     r8d, r8d             ; tile_y
.tile_y_loop:
    cmp     r8d, [rsp + 36]
    jae     .ok
    xor     r9d, r9d             ; tile_x
.tile_x_loop:
    cmp     r9d, r14d
    jae     .next_tile_y
    mov     r10d, ebx
    mov     eax, r14d
    sub     eax, r9d
    cmp     r10d, eax
    cmova   r10d, eax
    mov     r11d, ebp
    mov     eax, [rsp + 36]
    sub     eax, r8d
    cmp     r11d, eax
    cmova   r11d, eax
    xor     ecx, ecx
.copy_tile_row:
    cmp     ecx, r11d
    jae     .next_tile_x
    mov     eax, r8d
    add     eax, ecx
    imul    rax, r14
    add     eax, r9d
    lea     rdi, [r13 + rax * 4]
    mov     eax, r10d
    shl     eax, 2
    xor     edx, edx
.copy_row_bytes:
    cmp     edx, eax
    jae     .row_done
    mov     sil, [r12 + rdx]
    mov     [rdi + rdx], sil
    inc     edx
    jmp     .copy_row_bytes
.row_done:
    add     r12, rax
    inc     ecx
    jmp     .copy_tile_row
.next_tile_x:
    add     r9d, ebx
    jmp     .tile_x_loop
.next_tile_y:
    add     r8d, ebp
    jmp     .tile_y_loop
.ok:
    mov     rax, [rsp + 32]
    mov     ecx, [rsp + 36]
    imul    rax, rcx
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
    er_stack_free 80
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret

; er_png_crc32(type_ptr, data_ptr, data_len) -> eax=CRC-32, rdx=error
er_fn er_png_crc32
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    mov     r12, rsi
    mov     r13d, edx
    mov     eax, 0xffffffff
    mov     rbx, rdi
    mov     r8d, PNG_TYPE_SIZE
.type_loop:
    test    r8d, r8d
    jz      .data_start
    movzx   edx, byte [rbx]
    call    .update_byte
    inc     rbx
    dec     r8d
    jmp     .type_loop
.data_start:
    test    r13d, r13d
    jz      .finish
    er_check_zero r12, .invalid_param
.data_loop:
    test    r13d, r13d
    jz      .finish
    movzx   edx, byte [r12]
    call    .update_byte
    inc     r12
    dec     r13d
    jmp     .data_loop
.finish:
    not     eax
    er_ok
    jmp     .done
.update_byte:
    xor     eax, edx
    mov     ecx, 8
.bit_loop:
    mov     edx, eax
    and     edx, 1
    shr     eax, 1
    test    edx, edx
    jz      .next_bit
    xor     eax, PNG_CRC32_POLY
.next_bit:
    dec     ecx
    jnz     .bit_loop
    ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_png_validate_chunk_type(type_ptr) -> eax=1, rdx=error
er_fn er_png_validate_chunk_type
    er_check_zero rdi, .invalid_param
    xor     ecx, ecx
.loop:
    cmp     ecx, PNG_TYPE_SIZE
    jae     .reserved
    movzx   eax, byte [rdi + rcx]
    cmp     eax, ASCII_UPPER_A
    jb      .maybe_lower
    cmp     eax, ASCII_UPPER_Z
    jbe     .next
.maybe_lower:
    cmp     eax, ASCII_LOWER_A
    jb      .corrupt
    cmp     eax, ASCII_LOWER_Z
    ja      .corrupt
.next:
    inc     ecx
    jmp     .loop
.reserved:
    test    byte [rdi + PNG_CHUNK_RESERVED_INDEX], PNG_CHUNK_ANCILLARY_BIT
    jnz     .corrupt
    mov     eax, 1
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_adler32(data, len) -> eax=Adler-32, rdx=error
er_fn er_adler32
    er_push rbx, r12, r13, r14
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, 1              ; a
    xor     ebx, ebx             ; b
    test    r13d, r13d
    jz      .finish
    er_check_zero r12, .invalid_param
.loop:
    test    r13d, r13d
    jz      .finish
    movzx   ecx, byte [r12]
    add     r14d, ecx
    mov     eax, r14d
    xor     edx, edx
    mov     ecx, 65521
    div     ecx
    mov     r14d, edx
    add     ebx, r14d
    mov     eax, ebx
    xor     edx, edx
    div     ecx
    mov     ebx, edx
    inc     r12
    dec     r13d
    jmp     .loop
.finish:
    mov     eax, ebx
    shl     eax, 16
    or      eax, r14d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_zlib_inflate_stored(src, src_len, out, out_cap) -> eax=bytes written, rdx=error
; Supports zlib-wrapped deflate streams made only of stored blocks.
er_fn er_zlib_inflate_stored
    er_push rbx, rbp, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, ZLIB_HEADER_SIZE + 5 + ZLIB_ADLER_SIZE
    jb      .corrupt
    mov     r12, rdi             ; src
    mov     r13d, esi            ; src_len
    mov     r14, rdx             ; out
    mov     r15d, ecx            ; out_cap
    movzx   eax, byte [r12]
    mov     edx, eax
    and     edx, 0x0f
    cmp     edx, ZLIB_CM_DEFLATE
    jne     .unsupported
    shr     eax, 4
    cmp     eax, ZLIB_CINFO_MAX
    ja      .unsupported
    movzx   eax, byte [r12]
    shl     eax, 8
    movzx   edx, byte [r12 + 1]
    or      eax, edx
    xor     edx, edx
    mov     ecx, 31
    div     ecx
    test    edx, edx
    jnz     .corrupt
    test    byte [r12 + 1], 0x20
    jnz     .unsupported
    mov     ebx, ZLIB_HEADER_SIZE ; cursor
    xor     ebp, ebp             ; written
    xor     r9d, r9d             ; bit cursor is nonzero only for fixed-Huffman blocks
.block_loop:
    mov     eax, r13d
    sub     eax, ebx
    cmp     eax, 5 + ZLIB_ADLER_SIZE
    jb      .corrupt
    movzx   eax, byte [r12 + rbx]
    mov     r8d, eax
    and     eax, DEFLATE_BTYPE_MASK
    cmp     eax, DEFLATE_BTYPE_STORED
    je      .stored_block
    cmp     eax, DEFLATE_BTYPE_FIXED
    je      .fixed_block
    cmp     eax, DEFLATE_BTYPE_DYNAMIC
    je      .dynamic_block
    jmp     .unsupported
.stored_block:
    test    r8d, 0xf8            ; stored blocks must be byte-aligned after header padding
    jnz     .corrupt
    inc     ebx
    movzx   eax, word [r12 + rbx]
    movzx   edx, word [r12 + rbx + 2]
    mov     ecx, eax
    not     cx
    cmp     cx, dx
    jne     .corrupt
    add     ebx, 4
    mov     ecx, r13d
    sub     ecx, ebx
    sub     ecx, ZLIB_ADLER_SIZE
    cmp     eax, ecx
    ja      .corrupt
    mov     edx, ebp
    add     edx, eax
    jc      .memory
    cmp     edx, r15d
    ja      .no_space
    lea     r11, [r14 + rbp]
    lea     r10, [r12 + rbx]
    xor     ecx, ecx
.copy_loop:
    cmp     ecx, eax
    jae     .copied
    mov     dl, [r10 + rcx]
    mov     [r11 + rcx], dl
    inc     ecx
    jmp     .copy_loop
.copied:
    add     ebp, eax
    add     ebx, eax
    test    r8d, DEFLATE_BFINAL_MASK
    jz      .block_loop
    jmp     .check_adler
.fixed_block:
    mov     r9d, ebx
    shl     r9d, 3
    add     r9d, 3               ; bit position after BFINAL/BTYPE
.fixed_loop:
    call    .fixed_symbol
    test    edx, edx
    jnz     .done
    cmp     eax, 256
    je      .fixed_end
    cmp     eax, 256
    ja      .fixed_length
    cmp     ebp, r15d
    jae     .no_space
    mov     [r14 + rbp], al
    inc     ebp
    jmp     .fixed_loop
.fixed_length:
    call    .deflate_length_base_extra
    test    edx, edx
    jnz     .done
    mov     edi, eax             ; length base
    test    ecx, ecx
    jz      .fixed_have_length
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     edi, eax
.fixed_have_length:
    mov     ecx, 5
    call    .read_bits
    test    edx, edx
    jnz     .done
    mov     r10d, eax
    mov     r11d, 5
    call    .reverse_symbol_bits
    call    .deflate_distance_base_extra
    test    edx, edx
    jnz     .done
    mov     esi, eax             ; distance base
    test    ecx, ecx
    jz      .fixed_have_distance
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     esi, eax
.fixed_have_distance:
    test    esi, esi
    jz      .corrupt
    cmp     esi, ebp
    ja      .corrupt
    mov     eax, ebp
    add     eax, edi
    jc      .memory
    cmp     eax, r15d
    ja      .no_space
    xor     ecx, ecx
.backref_loop:
    cmp     ecx, edi
    jae     .fixed_loop
    mov     eax, ebp
    sub     eax, esi
    mov     dl, [r14 + rax]
    mov     [r14 + rbp], dl
    inc     ebp
    inc     ecx
    jmp     .backref_loop
.fixed_end:
    test    r8d, DEFLATE_BFINAL_MASK
    jz      .unsupported
    jmp     .check_adler
.dynamic_block:
    mov     r9d, ebx
    shl     r9d, 3
    add     r9d, 3
    mov     ecx, 5
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     eax, 257
    mov     [rel dyn_hlit], eax
    cmp     eax, DEFLATE_LL_COUNT
    ja      .corrupt
    mov     ecx, 5
    call    .read_bits
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [rel dyn_hdist], eax
    cmp     eax, DEFLATE_DIST_COUNT
    ja      .corrupt
    mov     ecx, 4
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     eax, 4
    mov     [rel dyn_hclen], eax
    cmp     eax, DEFLATE_CL_COUNT
    ja      .corrupt
    lea     rdi, [rel dyn_cl_len]
    mov     ecx, DEFLATE_CL_COUNT
    xor     eax, eax
.zero_cl:
    test    ecx, ecx
    jz      .read_cl
    mov     [rdi], al
    inc     rdi
    dec     ecx
    jmp     .zero_cl
.read_cl:
    xor     esi, esi
.read_cl_loop:
    cmp     esi, [rel dyn_hclen]
    jae     .build_cl
    mov     ecx, 3
    call    .read_bits
    test    edx, edx
    jnz     .done
    lea     rdi, [rel deflate_cl_order]
    movzx   ecx, byte [rdi + rsi]
    lea     rdi, [rel dyn_cl_len]
    mov     [rdi + rcx], al
    inc     esi
    jmp     .read_cl_loop
.build_cl:
    lea     rdi, [rel dyn_cl_len]
    lea     rsi, [rel dyn_cl_code]
    mov     edx, DEFLATE_CL_COUNT
    call    .build_huffman_codes
    test    edx, edx
    jnz     .done
    lea     rdi, [rel dyn_ll_len]
    mov     ecx, DEFLATE_LL_COUNT
    xor     eax, eax
.zero_ll:
    test    ecx, ecx
    jz      .zero_dist_start
    mov     [rdi], al
    inc     rdi
    dec     ecx
    jmp     .zero_ll
.zero_dist_start:
    lea     rdi, [rel dyn_dist_len]
    mov     ecx, DEFLATE_DIST_COUNT
.zero_dist:
    test    ecx, ecx
    jz      .decode_lengths
    mov     [rdi], al
    inc     rdi
    dec     ecx
    jmp     .zero_dist
.decode_lengths:
    xor     esi, esi             ; index into combined lengths
    mov     dword [rel dyn_prev_len], 0
    mov     eax, [rel dyn_hlit]
    add     eax, [rel dyn_hdist]
    mov     [rel dyn_hclen], eax ; reuse as total combined length count
.decode_lengths_loop:
    cmp     esi, [rel dyn_hclen]
    jae     .build_dynamic_tables
    lea     rdi, [rel dyn_cl_len]
    lea     rdx, [rel dyn_cl_code]
    mov     ecx, DEFLATE_CL_COUNT
    call    .decode_huffman_symbol
    test    edx, edx
    jnz     .done
    cmp     eax, 15
    jbe     .store_length_literal
    cmp     eax, 16
    je      .repeat_previous
    cmp     eax, 17
    je      .repeat_zero_3
    cmp     eax, 18
    jne     .corrupt
    mov     ecx, 7
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     eax, 11
    mov     dword [rel dyn_prev_len], 0
    jmp     .repeat_length
.repeat_zero_3:
    mov     ecx, 3
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     eax, 3
    mov     dword [rel dyn_prev_len], 0
    jmp     .repeat_length
.repeat_previous:
    test    esi, esi
    jz      .corrupt
    mov     ecx, 2
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     eax, 3
    jmp     .repeat_length
.store_length_literal:
    mov     [rel dyn_prev_len], eax
    mov     eax, 1
.repeat_length:
    test    eax, eax
    jz      .decode_lengths_loop
    cmp     esi, [rel dyn_hclen]
    jae     .corrupt
    cmp     esi, [rel dyn_hlit]
    jb      .store_ll_length
    mov     ecx, esi
    sub     ecx, [rel dyn_hlit]
    lea     rdx, [rel dyn_dist_len]
    mov     edi, [rel dyn_prev_len]
    mov     [rdx + rcx], dil
    jmp     .stored_one_length
.store_ll_length:
    lea     rdx, [rel dyn_ll_len]
    mov     edi, [rel dyn_prev_len]
    mov     [rdx + rsi], dil
.stored_one_length:
    inc     esi
    dec     eax
    jmp     .repeat_length
.build_dynamic_tables:
    lea     rdi, [rel dyn_ll_len]
    lea     rsi, [rel dyn_ll_code]
    mov     edx, [rel dyn_hlit]
    call    .build_huffman_codes
    test    edx, edx
    jnz     .done
    lea     rdi, [rel dyn_dist_len]
    lea     rsi, [rel dyn_dist_code]
    mov     edx, [rel dyn_hdist]
    call    .build_huffman_codes
    test    edx, edx
    jnz     .done
.dynamic_loop:
    lea     rdi, [rel dyn_ll_len]
    lea     rdx, [rel dyn_ll_code]
    mov     ecx, [rel dyn_hlit]
    call    .decode_huffman_symbol
    test    edx, edx
    jnz     .done
    cmp     eax, 256
    je      .dynamic_end
    cmp     eax, 256
    ja      .dynamic_length
    cmp     ebp, r15d
    jae     .no_space
    mov     [r14 + rbp], al
    inc     ebp
    jmp     .dynamic_loop
.dynamic_length:
    call    .deflate_length_base_extra
    test    edx, edx
    jnz     .done
    mov     edi, eax
    test    ecx, ecx
    jz      .dynamic_have_length
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     edi, eax
.dynamic_have_length:
    mov     [rel dyn_match_len], edi
    lea     rdi, [rel dyn_dist_len]
    lea     rdx, [rel dyn_dist_code]
    mov     ecx, [rel dyn_hdist]
    call    .decode_huffman_symbol
    test    edx, edx
    jnz     .done
    call    .deflate_distance_base_extra
    test    edx, edx
    jnz     .done
    mov     esi, eax
    test    ecx, ecx
    jz      .dynamic_have_distance
    call    .read_bits
    test    edx, edx
    jnz     .done
    add     esi, eax
.dynamic_have_distance:
    mov     edi, [rel dyn_match_len]
    test    esi, esi
    jz      .corrupt
    cmp     esi, ebp
    ja      .corrupt
    mov     eax, ebp
    add     eax, edi
    jc      .memory
    cmp     eax, r15d
    ja      .no_space
    xor     ecx, ecx
.dynamic_backref_loop:
    cmp     ecx, edi
    jae     .dynamic_loop
    mov     eax, ebp
    sub     eax, esi
    mov     dl, [r14 + rax]
    mov     [r14 + rbp], dl
    inc     ebp
    inc     ecx
    jmp     .dynamic_backref_loop
.dynamic_end:
    test    r8d, DEFLATE_BFINAL_MASK
    jz      .unsupported
    jmp     .check_adler
.check_adler:
    mov     eax, r13d
    sub     eax, ebx
    cmp     r9d, 0
    je      .adler_from_cursor
    mov     ebx, r9d
    add     ebx, 7
    shr     ebx, 3
    mov     eax, r13d
    sub     eax, ebx
.adler_from_cursor:
    cmp     eax, ZLIB_ADLER_SIZE
    jne     .corrupt
    mov     edx, [r12 + rbx]
    bswap   edx
    mov     rdi, r14
    mov     esi, ebp
    call    er_adler32
    test    edx, edx
    jnz     .done
    mov     edx, [r12 + rbx]
    bswap   edx
    cmp     eax, edx
    jne     .corrupt
    mov     eax, ebp
    er_ok
    jmp     .done
.read_bit:
    mov     eax, r9d
    shr     eax, 3
    mov     edx, r13d
    sub     edx, ZLIB_ADLER_SIZE
    cmp     eax, edx
    jae     .read_bit_corrupt
    movzx   edx, byte [r12 + rax]
    mov     ecx, r9d
    and     ecx, 7
    shr     edx, cl
    and     edx, 1
    inc     r9d
    mov     eax, edx
    er_ok
    ret
.read_bit_corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    ret
.read_bits:
    push    rdi
    mov     r10d, ecx
    xor     r11d, r11d
    mov     edi, 1
.read_bits_loop:
    test    r10d, r10d
    jz      .read_bits_done
    call    .read_bit
    test    edx, edx
    jnz     .read_bits_fail
    test    eax, eax
    jz      .read_bits_next
    or      r11d, edi
.read_bits_next:
    shl     edi, 1
    dec     r10d
    jmp     .read_bits_loop
.read_bits_done:
    mov     eax, r11d
    er_ok
.read_bits_fail:
    pop     rdi
    ret
.fixed_symbol:
    xor     r10d, r10d
    xor     r11d, r11d
.fixed_bit_loop:
    call    .read_bit
    test    edx, edx
    jnz     .fixed_symbol_done
    mov     ecx, r11d
    shl     eax, cl
    or      r10d, eax
    inc     r11d
    cmp     r11d, 7
    jb      .fixed_bit_loop
    call    .reverse_symbol_bits
    cmp     eax, 0x00
    jb      .fixed_after_7
    cmp     eax, 0x17
    ja      .fixed_after_7
    add     eax, 256
    er_ok
    ret
.fixed_after_7:
    call    .read_bit
    test    edx, edx
    jnz     .fixed_symbol_done
    mov     ecx, r11d
    shl     eax, cl
    or      r10d, eax
    inc     r11d
    call    .reverse_symbol_bits
    cmp     eax, 0x30
    jb      .fixed_try_280
    cmp     eax, 0xbf
    ja      .fixed_try_280
    sub     eax, 0x30
    er_ok
    ret
.fixed_try_280:
    cmp     eax, 0xc0
    jb      .fixed_read_9
    cmp     eax, 0xc7
    ja      .fixed_read_9
    add     eax, 88
    er_ok
    ret
.fixed_read_9:
    call    .read_bit
    test    edx, edx
    jnz     .fixed_symbol_done
    mov     ecx, r11d
    shl     eax, cl
    or      r10d, eax
    inc     r11d
    call    .reverse_symbol_bits
    cmp     eax, 0x190
    jb      .fixed_bad_symbol
    cmp     eax, 0x1ff
    ja      .fixed_bad_symbol
    sub     eax, 0x100
    er_ok
    ret
.reverse_symbol_bits:
    xor     eax, eax
    mov     ecx, r11d
    mov     edx, r10d
.reverse_loop:
    test    ecx, ecx
    jz      .reverse_done
    shl     eax, 1
    mov     esi, edx
    and     esi, 1
    or      eax, esi
    shr     edx, 1
    dec     ecx
    jmp     .reverse_loop
.reverse_done:
    ret
.fixed_bad_symbol:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.fixed_symbol_done:
    ret
.build_huffman_codes:
    ; rdi=length bytes, rsi=code words, edx=count
    push    rbx
    push    rbp
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    mov     ebp, edx
    lea     rdi, [rel dyn_count]
    mov     ecx, DEFLATE_MAX_BITS + 1
    xor     eax, eax
.bh_zero_counts:
    test    ecx, ecx
    jz      .bh_count_lengths
    mov     word [rdi], 0
    add     rdi, 2
    dec     ecx
    jmp     .bh_zero_counts
.bh_count_lengths:
    xor     ebx, ebx
.bh_count_loop:
    cmp     ebx, ebp
    jae     .bh_next_codes
    movzx   eax, byte [r12 + rbx]
    cmp     eax, DEFLATE_MAX_BITS
    ja      .bh_corrupt
    test    eax, eax
    jz      .bh_count_next
    lea     rdi, [rel dyn_count]
    inc     word [rdi + rax * 2]
.bh_count_next:
    inc     ebx
    jmp     .bh_count_loop
.bh_next_codes:
    lea     rdi, [rel dyn_next_code]
    mov     ecx, DEFLATE_MAX_BITS + 1
.bh_zero_next:
    test    ecx, ecx
    jz      .bh_make_next
    mov     word [rdi], 0
    add     rdi, 2
    dec     ecx
    jmp     .bh_zero_next
.bh_make_next:
    xor     eax, eax             ; code
    mov     ebx, 1               ; bits
.bh_next_loop:
    cmp     ebx, DEFLATE_MAX_BITS
    ja      .bh_assign
    lea     rdi, [rel dyn_count]
    movzx   ecx, word [rdi + rbx * 2 - 2]
    add     eax, ecx
    shl     eax, 1
    cmp     eax, 0xffff
    ja      .bh_corrupt
    lea     rdi, [rel dyn_next_code]
    mov     [rdi + rbx * 2], ax
    inc     ebx
    jmp     .bh_next_loop
.bh_assign:
    xor     ebx, ebx
.bh_assign_loop:
    cmp     ebx, ebp
    jae     .bh_ok
    movzx   eax, byte [r12 + rbx]
    test    eax, eax
    jz      .bh_store_zero
    lea     rdi, [rel dyn_next_code]
    movzx   r10d, word [rdi + rax * 2]
    mov     r11d, eax
    call    .reverse_symbol_bits
    mov     [r13 + rbx * 2], ax
    lea     rdi, [rel dyn_next_code]
    inc     word [rdi + r11 * 2]
    jmp     .bh_assign_next
.bh_store_zero:
    mov     word [r13 + rbx * 2], 0
.bh_assign_next:
    inc     ebx
    jmp     .bh_assign_loop
.bh_ok:
    mov     eax, 1
    er_ok
    jmp     .bh_done
.bh_corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.bh_done:
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret
.decode_huffman_symbol:
    ; rdi=length bytes, rdx=code words, ecx=count
    push    rbx
    push    rbp
    push    r14
    push    r15
    mov     r14, rdi
    mov     r15, rdx
    mov     ebp, ecx
    xor     r10d, r10d           ; bit accumulator, LSB-first value
    mov     r11d, 1              ; current bit length
.dh_len_loop:
    cmp     r11d, DEFLATE_MAX_BITS
    ja      .dh_corrupt
    call    .read_bit
    test    edx, edx
    jnz     .dh_done
    mov     ecx, r11d
    dec     ecx
    shl     eax, cl
    or      r10d, eax
    xor     ebx, ebx
.dh_scan:
    cmp     ebx, ebp
    jae     .dh_next_len
    movzx   eax, byte [r14 + rbx]
    cmp     eax, r11d
    jne     .dh_scan_next
    movzx   eax, word [r15 + rbx * 2]
    cmp     eax, r10d
    je      .dh_found
.dh_scan_next:
    inc     ebx
    jmp     .dh_scan
.dh_next_len:
    inc     r11d
    jmp     .dh_len_loop
.dh_found:
    mov     eax, ebx
    er_ok
    jmp     .dh_done
.dh_corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.dh_done:
    pop     r15
    pop     r14
    pop     rbp
    pop     rbx
    ret
.deflate_length_base_extra:
    cmp     eax, 257
    jb      .deflate_length_bad
    cmp     eax, 285
    ja      .deflate_length_bad
    sub     eax, 257
    lea     r11, [rel deflate_length_extra]
    movzx   ecx, byte [r11 + rax]
    lea     r11, [rel deflate_length_base]
    movzx   eax, word [r11 + rax * 2]
    er_ok
    ret
.deflate_length_bad:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    ret
.deflate_distance_base_extra:
    cmp     eax, 29
    ja      .deflate_distance_bad
    lea     r11, [rel deflate_distance_extra]
    movzx   ecx, byte [r11 + rax]
    lea     r11, [rel deflate_distance_base]
    movzx   eax, word [r11 + rax * 2]
    er_ok
    ret
.deflate_distance_bad:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    ret
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
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret

; er_png_paeth_predictor(left, above, upper_left) -> eax=predictor, rdx=error
er_fn er_png_paeth_predictor
    movzx   edi, dil
    movzx   esi, sil
    movzx   edx, dl
    mov     eax, edi
    add     eax, esi
    sub     eax, edx             ; p
    mov     ecx, eax
    sub     ecx, edi             ; p - left
    jns     .pa_ok
    neg     ecx
.pa_ok:
    mov     r8d, eax
    sub     r8d, esi             ; p - above
    jns     .pb_ok
    neg     r8d
.pb_ok:
    mov     r9d, eax
    sub     r9d, edx             ; p - upper_left
    jns     .pc_ok
    neg     r9d
.pc_ok:
    cmp     ecx, r8d
    ja      .maybe_above
    cmp     ecx, r9d
    ja      .maybe_above
    mov     eax, edi
    er_ok
    er_ret
.maybe_above:
    cmp     r8d, r9d
    ja      .upper_left
    mov     eax, esi
    er_ok
    er_ret
.upper_left:
    mov     eax, edx
    er_ok
    er_ret

; er_png_unfilter(decoded, len, width, height, channels) -> eax=decoded bytes, rdx=error
er_fn er_png_unfilter
    er_push rbx, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    test    edx, edx
    jz      .corrupt
    test    ecx, ecx
    jz      .corrupt
    cmp     r8d, 1
    jb      .unsupported
    cmp     r8d, PNG_COLOR_RGBA
    ja      .unsupported
    mov     r12, rdi             ; decoded
    mov     r13d, esi            ; len
    mov     r14d, edx            ; width
    mov     r15d, ecx            ; height
    mov     ebx, r8d             ; channels
    mov     eax, r14d
    imul    eax, ebx
    jo      .memory
    mov     r9d, eax             ; row_body
    inc     eax
    imul    eax, r15d
    jo      .memory
    cmp     eax, r13d
    ja      .corrupt
    xor     r10d, r10d           ; y
.row_loop:
    cmp     r10d, r15d
    jae     .ok
    mov     eax, r9d
    inc     eax
    imul    eax, r10d
    lea     rdi, [r12 + rax]
    movzx   eax, byte [rdi]
    inc     rdi                  ; row data
    cmp     eax, PNG_FILTER_NONE
    je      .next_row
    cmp     eax, PNG_FILTER_SUB
    je      .filter_sub
    cmp     eax, PNG_FILTER_UP
    je      .filter_up
    cmp     eax, PNG_FILTER_AVERAGE
    je      .filter_average
    cmp     eax, PNG_FILTER_PAETH
    jne     .unsupported
    jmp     .filter_paeth
.filter_sub:
    mov     ecx, ebx
.sub_loop:
    cmp     ecx, r9d
    jae     .next_row
    mov     r11d, ecx
    sub     r11d, ebx
    movzx   eax, byte [rdi + r11]
    add     [rdi + rcx], al
    inc     ecx
    jmp     .sub_loop
.filter_up:
    test    r10d, r10d
    jz      .next_row
    mov     r11, rdi
    sub     r11, r9
    dec     r11
    xor     ecx, ecx
.up_loop:
    cmp     ecx, r9d
    jae     .next_row
    movzx   eax, byte [r11 + rcx]
    add     [rdi + rcx], al
    inc     ecx
    jmp     .up_loop
.filter_average:
    xor     ecx, ecx
.avg_loop:
    cmp     ecx, r9d
    jae     .next_row
    xor     eax, eax             ; left
    cmp     ecx, ebx
    jb      .avg_above
    mov     r11d, ecx
    sub     r11d, ebx
    movzx   eax, byte [rdi + r11]
.avg_above:
    xor     edx, edx             ; above
    test    r10d, r10d
    jz      .avg_apply
    mov     r11, rdi
    sub     r11, r9
    dec     r11
    movzx   edx, byte [r11 + rcx]
.avg_apply:
    add     eax, edx
    shr     eax, 1
    add     [rdi + rcx], al
    inc     ecx
    jmp     .avg_loop
.filter_paeth:
    xor     ecx, ecx
.paeth_loop:
    cmp     ecx, r9d
    jae     .next_row
    xor     eax, eax             ; left
    cmp     ecx, ebx
    jb      .paeth_have_left
    mov     r11d, ecx
    sub     r11d, ebx
    movzx   eax, byte [rdi + r11]
.paeth_have_left:
    xor     edx, edx             ; above
    xor     r8d, r8d             ; upper_left
    test    r10d, r10d
    jz      .paeth_apply
    mov     r11, rdi
    sub     r11, r9
    dec     r11
    movzx   edx, byte [r11 + rcx]
    cmp     ecx, ebx
    jb      .paeth_apply
    mov     r13d, ecx
    sub     r13d, ebx
    movzx   r8d, byte [r11 + r13]
.paeth_apply:
    ; inline paeth predictor: left=eax, above=edx, upper_left=r8d
    mov     r13d, eax
    add     r13d, edx
    sub     r13d, r8d
    mov     r11d, r13d
    sub     r11d, eax
    jns     .pa_abs_a
    neg     r11d
.pa_abs_a:
    mov     esi, r13d
    sub     esi, edx
    jns     .pa_abs_b
    neg     esi
.pa_abs_b:
    mov     r13d, r13d
    sub     r13d, r8d
    jns     .pa_abs_c
    neg     r13d
.pa_abs_c:
    cmp     r11d, esi
    ja      .pa_pick_b_or_c
    cmp     r11d, r13d
    ja      .pa_pick_b_or_c
    jmp     .pa_add
.pa_pick_b_or_c:
    cmp     esi, r13d
    ja      .pa_pick_c
    mov     eax, edx
    jmp     .pa_add
.pa_pick_c:
    mov     eax, r8d
.pa_add:
    add     [rdi + rcx], al
    inc     ecx
    jmp     .paeth_loop
.next_row:
    inc     r10d
    jmp     .row_loop
.ok:
    mov     eax, r9d
    inc     eax
    imul    eax, r15d
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

; er_png_write_pixels(decoded, len, width, height, channels, out, out_count)
; -> eax=pixel_count, rdx=error
er_fn er_png_write_pixels
    mov     r10, [rsp + 8]
    er_push rbx, rbp, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero r9, .invalid_param
    test    edx, edx
    jz      .corrupt
    test    ecx, ecx
    jz      .corrupt
    cmp     r8d, 1
    je      .channels_ok
    cmp     r8d, 2
    je      .channels_ok
    cmp     r8d, 3
    je      .channels_ok
    cmp     r8d, 4
    jne     .unsupported
.channels_ok:
    mov     r12, rdi             ; decoded scanlines
    mov     r13, r9              ; out pixels
    mov     r14d, edx            ; width
    mov     r15d, ecx            ; height
    mov     ebx, r8d             ; channels
    mov     eax, r14d
    imul    eax, r15d
    jo      .memory
    cmp     rax, r10
    ja      .no_space
    mov     ebp, eax             ; pixel_count
    mov     eax, r14d
    imul    eax, ebx
    jo      .memory
    mov     r11d, eax            ; row_body
    inc     eax
    imul    eax, r15d
    jo      .memory
    cmp     eax, esi
    ja      .corrupt
    xor     r8d, r8d             ; y
.row_loop:
    cmp     r8d, r15d
    jae     .ok
    mov     eax, r11d
    inc     eax
    imul    eax, r8d
    lea     rdi, [r12 + rax + 1]
    mov     eax, r8d
    imul    eax, r14d
    lea     r9, [r13 + rax * 4]
    xor     ecx, ecx             ; x
.pixel_loop:
    cmp     ecx, r14d
    jae     .next_row
    mov     eax, ecx
    imul    eax, ebx
    lea     r10, [rdi + rax]
    movzx   eax, byte [r10]
    mov     [r9], al             ; r or gray
    cmp     ebx, 1
    je      .gray_opaque
    cmp     ebx, 2
    je      .gray_alpha
    movzx   eax, byte [r10 + 1]
    mov     [r9 + 1], al
    movzx   eax, byte [r10 + 2]
    mov     [r9 + 2], al
    cmp     ebx, 4
    jne     .rgb_opaque
    movzx   eax, byte [r10 + 3]
    mov     [r9 + 3], al
    jmp     .pixel_done
.rgb_opaque:
    mov     byte [r9 + 3], PNG_ALPHA_OPAQUE
    jmp     .pixel_done
.gray_alpha:
    movzx   eax, byte [r10]
    mov     [r9 + 1], al
    mov     [r9 + 2], al
    movzx   eax, byte [r10 + 1]
    mov     [r9 + 3], al
    jmp     .pixel_done
.gray_opaque:
    movzx   eax, byte [r10]
    mov     [r9 + 1], al
    mov     [r9 + 2], al
    mov     byte [r9 + 3], PNG_ALPHA_OPAQUE
.pixel_done:
    add     r9, 4
    inc     ecx
    jmp     .pixel_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, ebp
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
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret

; er_image_decode_png_stored(bytes, len, out_pixels, out_count, scratch, scratch_cap, out_header)
; -> eax=pixel_count, rdx=error. PNG decode for zlib stored-block IDAT streams.
er_fn er_image_decode_png_stored
    mov     r10, [rsp + 8]
    er_push rbx, rbp, r12, r13, r14, r15
    er_stack_alloc 96
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero r8, .invalid_param
    er_check_zero r10, .invalid_param
    mov     [rsp + 0], rdi       ; bytes
    mov     [rsp + 8], rsi       ; len
    mov     [rsp + 16], rdx      ; out pixels
    mov     [rsp + 24], rcx      ; out count
    mov     [rsp + 32], r8       ; scratch
    mov     [rsp + 40], r9       ; scratch cap
    mov     [rsp + 48], r10      ; out header
    mov     qword [rsp + 56], 0  ; idat total
    mov     dword [rsp + 64], 0  ; width
    mov     dword [rsp + 68], 0  ; height
    mov     dword [rsp + 72], 0  ; channels
    cmp     esi, PNG_SIGNATURE_SIZE + PNG_CHUNK_OVERHEAD + PNG_IHDR_SIZE + PNG_CHUNK_OVERHEAD + PNG_CHUNK_OVERHEAD
    jb      .corrupt
    cmp     dword [rdi], PNG_SIGNATURE_HI
    jne     .unsupported
    cmp     dword [rdi + 4], PNG_SIGNATURE_LO
    jne     .unsupported
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, PNG_SIGNATURE_SIZE
    xor     r15d, r15d
.chunk_loop:
    mov     eax, r13d
    sub     eax, ebx
    cmp     eax, PNG_CHUNK_OVERHEAD
    jb      .corrupt
    mov     eax, [r12 + rbx]
    bswap   eax
    mov     [rsp + 76], eax
    lea     rdi, [r12 + rbx + PNG_LENGTH_SIZE]
    call    er_png_validate_chunk_type
    test    edx, edx
    jnz     .done
    mov     eax, r13d
    sub     eax, ebx
    sub     eax, PNG_CHUNK_OVERHEAD
    cmp     [rsp + 76], eax
    ja      .corrupt
    lea     rdi, [r12 + rbx + PNG_LENGTH_SIZE]
    lea     rsi, [r12 + rbx + PNG_CHUNK_HEADER_SIZE]
    mov     edx, [rsp + 76]
    call    er_png_crc32
    test    edx, edx
    jnz     .done
    mov     ecx, [rsp + 76]
    lea     r11, [r12 + rbx]
    mov     edx, [r11 + rcx + PNG_CHUNK_HEADER_SIZE]
    bswap   edx
    cmp     eax, edx
    jne     .corrupt
    mov     eax, [r12 + rbx + PNG_LENGTH_SIZE]
    cmp     eax, PNG_CHUNK_IHDR
    je      .ihdr
    cmp     eax, PNG_CHUNK_IDAT
    je      .idat
    cmp     eax, PNG_CHUNK_IEND
    je      .iend
    test    r15d, 1
    jz      .corrupt
    test    eax, PNG_CHUNK_ANCILLARY_BIT
    jz      .unsupported
    test    r15d, 2
    jz      .advance
    or      r15d, 4
    jmp     .advance
.ihdr:
    test    r15d, 1
    jnz     .corrupt
    cmp     ebx, PNG_SIGNATURE_SIZE
    jne     .corrupt
    cmp     dword [rsp + 76], PNG_IHDR_SIZE
    jne     .corrupt
    lea     rdi, [r12 + rbx + PNG_CHUNK_HEADER_SIZE]
    mov     eax, [rdi]
    bswap   eax
    test    eax, eax
    jz      .corrupt
    mov     [rsp + 64], eax
    mov     eax, [rdi + 4]
    bswap   eax
    test    eax, eax
    jz      .corrupt
    mov     [rsp + 68], eax
    cmp     byte [rdi + 8], PNG_BIT_DEPTH_U8
    jne     .unsupported
    movzx   eax, byte [rdi + 9]
    cmp     eax, PNG_COLOR_GRAYSCALE
    je      .channels_1
    cmp     eax, PNG_COLOR_RGB
    je      .channels_3
    cmp     eax, PNG_COLOR_GRAYSCALE_ALPHA
    je      .channels_2
    cmp     eax, PNG_COLOR_RGBA
    jne     .unsupported
    mov     dword [rsp + 72], 4
    jmp     .ihdr_methods
.channels_1:
    mov     dword [rsp + 72], 1
    jmp     .ihdr_methods
.channels_2:
    mov     dword [rsp + 72], 2
    jmp     .ihdr_methods
.channels_3:
    mov     dword [rsp + 72], 3
.ihdr_methods:
    cmp     byte [rdi + 10], PNG_METHOD_DEFLATE
    jne     .unsupported
    cmp     byte [rdi + 11], PNG_FILTER_STANDARD
    jne     .unsupported
    cmp     byte [rdi + 12], PNG_INTERLACE_NONE
    jne     .unsupported
    or      r15d, 1
    jmp     .advance
.idat:
    test    r15d, 1
    jz      .corrupt
    test    r15d, 4
    jnz     .corrupt
    or      r15d, 2
    mov     rax, [rsp + 56]
    mov     ecx, [rsp + 76]
    add     rax, rcx
    jc      .memory
    cmp     rax, [rsp + 40]
    ja      .no_space
    mov     rdi, [rsp + 32]
    add     rdi, [rsp + 56]
    lea     rsi, [r12 + rbx + PNG_CHUNK_HEADER_SIZE]
    xor     edx, edx
.copy_idat:
    cmp     edx, [rsp + 76]
    jae     .idat_copied
    mov     al, [rsi + rdx]
    mov     [rdi + rdx], al
    inc     edx
    jmp     .copy_idat
.idat_copied:
    mov     rax, [rsp + 56]
    add     rax, rcx
    mov     [rsp + 56], rax
    jmp     .advance
.iend:
    test    r15d, 1
    jz      .corrupt
    test    r15d, 2
    jz      .corrupt
    cmp     qword [rsp + 56], 0
    je      .corrupt
    cmp     dword [rsp + 76], 0
    jne     .corrupt
    add     ebx, PNG_CHUNK_OVERHEAD
    cmp     ebx, r13d
    jne     .corrupt
    jmp     .inflate
.advance:
    add     ebx, PNG_CHUNK_OVERHEAD
    add     ebx, [rsp + 76]
    jc      .memory
    jmp     .chunk_loop
.inflate:
    mov     eax, [rsp + 64]
    imul    eax, dword [rsp + 72]
    jo      .memory
    mov     [rsp + 80], eax      ; row_body
    inc     eax
    imul    eax, dword [rsp + 68]
    jo      .memory
    mov     [rsp + 84], eax      ; decoded len
    mov     rcx, [rsp + 56]
    add     rcx, rax
    jc      .memory
    cmp     rcx, [rsp + 40]
    ja      .no_space
    mov     rdi, [rsp + 32]
    mov     rsi, [rsp + 56]
    mov     rdx, [rsp + 32]
    add     rdx, [rsp + 56]
    mov     ecx, [rsp + 84]
    call    er_zlib_inflate_stored
    test    edx, edx
    jnz     .done
    cmp     eax, [rsp + 84]
    jne     .corrupt
    mov     rdi, [rsp + 32]
    add     rdi, [rsp + 56]
    mov     esi, [rsp + 84]
    mov     edx, [rsp + 64]
    mov     ecx, [rsp + 68]
    mov     r8d, [rsp + 72]
    call    er_png_unfilter
    test    edx, edx
    jnz     .done
    mov     rdi, [rsp + 32]
    add     rdi, [rsp + 56]
    mov     esi, [rsp + 84]
    mov     edx, [rsp + 64]
    mov     ecx, [rsp + 68]
    mov     r8d, [rsp + 72]
    mov     r9, [rsp + 16]
    push    qword [rsp + 24]
    call    er_png_write_pixels
    add     rsp, 8
    test    edx, edx
    jnz     .done
    mov     rdi, [rsp + 48]
    mov     ecx, [rsp + 64]
    mov     [rdi + IMAGE_HEADER_WIDTH], ecx
    mov     ecx, [rsp + 68]
    mov     [rdi + IMAGE_HEADER_HEIGHT], ecx
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
    er_stack_free 96
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret

; er_image_decode_png_header(buf, len, out_header) -> eax=IMAGE_HEADER_SIZE, rdx=error
er_fn er_image_decode_png_header
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, PNG_SIGNATURE_SIZE + PNG_CHUNK_OVERHEAD + PNG_IHDR_SIZE + PNG_CHUNK_OVERHEAD + 1 + PNG_CHUNK_OVERHEAD
    jb      .corrupt
    cmp     dword [rdi], PNG_SIGNATURE_HI
    jne     .unsupported
    cmp     dword [rdi + 4], PNG_SIGNATURE_LO
    jne     .unsupported
    mov     r12, rdi             ; bytes
    mov     r13d, esi            ; len
    mov     r14, rdx             ; out header
    mov     ebx, PNG_SIGNATURE_SIZE
    xor     r15d, r15d           ; flags: bit0 header, bit1 saw IDAT, bit2 closed IDAT
    mov     qword [rsp + 0], 0   ; idat_total
.chunk_loop:
    mov     eax, r13d
    sub     eax, ebx
    cmp     eax, PNG_CHUNK_OVERHEAD
    jb      .corrupt
    mov     eax, [r12 + rbx]
    bswap   eax
    mov     [rsp + 8], eax       ; length
    lea     rdi, [r12 + rbx + PNG_LENGTH_SIZE]
    call    er_png_validate_chunk_type
    test    edx, edx
    jnz     .done
    mov     eax, r13d
    sub     eax, ebx
    sub     eax, PNG_CHUNK_OVERHEAD
    cmp     [rsp + 8], eax
    ja      .corrupt
    lea     rdi, [r12 + rbx + PNG_LENGTH_SIZE]
    lea     rsi, [r12 + rbx + PNG_CHUNK_HEADER_SIZE]
    mov     edx, [rsp + 8]
    call    er_png_crc32
    test    edx, edx
    jnz     .done
    mov     ecx, [rsp + 8]
    lea     r10, [r12 + rbx]
    mov     edx, [r10 + rcx + PNG_CHUNK_HEADER_SIZE]
    bswap   edx
    cmp     eax, edx
    jne     .corrupt
    mov     eax, [r12 + rbx + PNG_LENGTH_SIZE]
    cmp     eax, PNG_CHUNK_IHDR
    je      .ihdr
    cmp     eax, PNG_CHUNK_IDAT
    je      .idat
    cmp     eax, PNG_CHUNK_IEND
    je      .iend
    test    r15d, 1
    jz      .corrupt
    test    eax, PNG_CHUNK_ANCILLARY_BIT
    jz      .unsupported
    test    r15d, 2
    jz      .advance
    or      r15d, 4
    jmp     .advance
.ihdr:
    test    r15d, 1
    jnz     .corrupt
    cmp     ebx, PNG_SIGNATURE_SIZE
    jne     .corrupt
    cmp     dword [rsp + 8], PNG_IHDR_SIZE
    jne     .corrupt
    lea     rdi, [r12 + rbx + PNG_CHUNK_HEADER_SIZE]
    mov     eax, [rdi + 0]
    bswap   eax
    test    eax, eax
    jz      .corrupt
    mov     [r14 + IMAGE_HEADER_WIDTH], eax
    mov     eax, [rdi + 4]
    bswap   eax
    test    eax, eax
    jz      .corrupt
    mov     [r14 + IMAGE_HEADER_HEIGHT], eax
    cmp     byte [rdi + 8], PNG_BIT_DEPTH_U8
    jne     .unsupported
    movzx   eax, byte [rdi + 9]
    cmp     eax, PNG_COLOR_GRAYSCALE
    je      .ihdr_color_ok
    cmp     eax, PNG_COLOR_RGB
    je      .ihdr_color_ok
    cmp     eax, PNG_COLOR_GRAYSCALE_ALPHA
    je      .ihdr_color_ok
    cmp     eax, PNG_COLOR_RGBA
    jne     .unsupported
.ihdr_color_ok:
    cmp     byte [rdi + 10], PNG_METHOD_DEFLATE
    jne     .unsupported
    cmp     byte [rdi + 11], PNG_FILTER_STANDARD
    jne     .unsupported
    cmp     byte [rdi + 12], PNG_INTERLACE_NONE
    jne     .unsupported
    or      r15d, 1
    jmp     .advance
.idat:
    test    r15d, 1
    jz      .corrupt
    test    r15d, 4
    jnz     .corrupt
    or      r15d, 2
    mov     eax, [rsp + 8]
    add     [rsp + 0], rax
    jc      .memory
    jmp     .advance
.iend:
    test    r15d, 1
    jz      .corrupt
    test    r15d, 2
    jz      .corrupt
    cmp     qword [rsp + 0], 0
    je      .corrupt
    cmp     dword [rsp + 8], 0
    jne     .corrupt
    add     ebx, PNG_CHUNK_OVERHEAD
    cmp     ebx, r13d
    jne     .corrupt
    mov     eax, IMAGE_HEADER_SIZE
    er_ok
    jmp     .done
.advance:
    add     ebx, PNG_CHUNK_OVERHEAD
    add     ebx, [rsp + 8]
    jc      .memory
    jmp     .chunk_loop
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.memory:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
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
