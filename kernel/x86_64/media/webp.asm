; EdgeRun WebP container parser — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/webp_constants.inc"
%include "x86_64/media/vp8_constants.inc"

extern er_vp8_parse_key_frame_header
extern er_vp8_decode_key_frame

SECTION .text

; er_webp_is(buf, len) -> eax=1 if RIFF WEBP, else 0
er_fn er_webp_is
    test    rdi, rdi
    jz      .no
    cmp     esi, WEBP_RIFF_HEADER_SIZE
    jb      .no
    cmp     dword [rdi], WEBP_RIFF_SIGNATURE
    jne     .no
    cmp     dword [rdi + WEBP_SIGNATURE_OFFSET], WEBP_SIGNATURE
    jne     .no
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret

; er_webp_validate_riff_len(buf, len) -> eax=len, rdx=error
er_fn er_webp_validate_riff_len
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, WEBP_RIFF_HEADER_SIZE
    jb      .no_data
    cmp     dword [rdi], WEBP_RIFF_SIGNATURE
    jne     .unsupported
    cmp     dword [rdi + WEBP_SIGNATURE_OFFSET], WEBP_SIGNATURE
    jne     .unsupported
    mov     eax, [rdi + WEBP_RIFF_LEN_OFFSET]
    cmp     eax, 4
    jb      .corrupt
    add     eax, 8
    jc      .corrupt
    cmp     eax, esi
    jne     .corrupt
    mov     eax, esi
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_webp_read_chunk(buf, len, cursor, desc) -> eax=next cursor, rdx=error
; desc: type u32, data_offset u32, data_len u32, next_cursor u32
er_fn er_webp_read_chunk
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rcx
    mov     ebx, edx
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     eax, WEBP_CHUNK_HEADER_SIZE
    jb      .no_data
    mov     eax, [r12 + rbx]
    mov     [r13 + WEBP_CHUNK_DESC_TYPE], eax
    mov     eax, [r12 + rbx + 4]
    lea     edx, [rbx + WEBP_CHUNK_HEADER_SIZE]
    jc      .corrupt
    mov     [r13 + WEBP_CHUNK_DESC_DATA_OFFSET], edx
    mov     [r13 + WEBP_CHUNK_DESC_DATA_LEN], eax
    mov     r8d, edx
    add     r8d, eax
    jc      .corrupt
    cmp     r8d, esi
    ja      .corrupt
    test    eax, 1
    jz      .store_next
    cmp     r8d, esi
    jae     .corrupt
    inc     r8d
.store_next:
    mov     [r13 + WEBP_CHUNK_DESC_NEXT_CURSOR], r8d
    mov     eax, r8d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_webp_parse_vp8x(data, len, desc) -> eax=WEBP_HDR_SIZE, rdx=error
er_fn er_webp_parse_vp8x
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     esi, WEBP_VP8X_PAYLOAD_SIZE
    jne     .corrupt
    movzx   eax, byte [rdi + WEBP_VP8X_FLAGS_INDEX]
    test    eax, ~WEBP_VP8X_KNOWN_FLAGS
    jnz     .corrupt
    mov     [rdx + WEBP_HDR_FLAGS], al
    movzx   eax, word [rdi + WEBP_VP8X_WIDTH_INDEX]
    movzx   ecx, byte [rdi + WEBP_VP8X_WIDTH_INDEX + 2]
    shl     ecx, 16
    or      eax, ecx
    inc     eax
    mov     [rdx + WEBP_HDR_WIDTH], eax
    movzx   eax, word [rdi + WEBP_VP8X_HEIGHT_INDEX]
    movzx   ecx, byte [rdi + WEBP_VP8X_HEIGHT_INDEX + 2]
    shl     ecx, 16
    or      eax, ecx
    inc     eax
    mov     [rdx + WEBP_HDR_HEIGHT], eax
    mov     eax, WEBP_HDR_SIZE
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

; er_webp_parse_vp8l_header(data, len, desc) -> eax=WEBP_HDR_SIZE, rdx=error
er_fn er_webp_parse_vp8l_header
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     esi, WEBP_VP8L_HEADER_SIZE
    jb      .corrupt
    cmp     byte [rdi], WEBP_VP8L_SIGNATURE
    jne     .corrupt
    mov     eax, [rdi + 1]
    mov     ecx, eax
    shr     ecx, WEBP_VP8L_VERSION_SHIFT
    and     ecx, WEBP_VP8L_VERSION_MASK
    jnz     .unsupported
    mov     ecx, eax
    and     ecx, WEBP_VP8L_DIMENSION_MASK
    inc     ecx
    cmp     ecx, WEBP_MAX_LEGACY_DIMENSION
    ja      .corrupt
    mov     [rdx + WEBP_HDR_WIDTH], ecx
    shr     eax, WEBP_VP8L_HEIGHT_SHIFT
    and     eax, WEBP_VP8L_DIMENSION_MASK
    inc     eax
    cmp     eax, WEBP_MAX_LEGACY_DIMENSION
    ja      .corrupt
    mov     [rdx + WEBP_HDR_HEIGHT], eax
    mov     eax, WEBP_HDR_SIZE
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

; er_webp_parse_header(buf, len, desc) -> eax=WEBP_HDR_SIZE, rdx=error
er_fn er_webp_parse_header
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc WEBP_PARSE_STACK_TOTAL
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rdi, r14
    xor     esi, esi
    mov     edx, WEBP_HDR_SIZE
    call    er_webp_memset
    test    edx, edx
    jnz     .done_parse
    mov     rdi, r12
    mov     esi, r13d
    call    er_webp_validate_riff_len
    test    edx, edx
    jnz     .done_parse
    mov     ebx, WEBP_RIFF_HEADER_SIZE
    xor     r15d, r15d
.loop:
    cmp     ebx, r13d
    jae     .finish
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + WEBP_PARSE_STACK_CHUNK]
    call    er_webp_read_chunk
    test    edx, edx
    jnz     .done_parse
    mov     ebx, eax
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_TYPE]
    cmp     eax, WEBP_CHUNK_VP8X
    je      .chunk_vp8x
    cmp     eax, WEBP_CHUNK_VP8L
    je      .chunk_vp8l
    cmp     eax, WEBP_CHUNK_VP8
    je      .chunk_vp8
    cmp     eax, WEBP_CHUNK_ALPH
    je      .chunk_alph
    cmp     eax, WEBP_CHUNK_ICCP
    je      .loop
    cmp     eax, WEBP_CHUNK_EXIF
    je      .loop
    cmp     eax, WEBP_CHUNK_XMP
    je      .loop
    cmp     eax, WEBP_CHUNK_ANIM
    je      .unsupported
    cmp     eax, WEBP_CHUNK_ANMF
    je      .unsupported
    call    er_webp_chunk_is_critical
    test    eax, eax
    jnz     .unsupported
    jmp     .loop
.chunk_vp8x:
    test    r15d, r15d
    jnz     .corrupt
    cmp     dword [r14 + WEBP_HDR_WIDTH], 0
    jne     .corrupt
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    mov     rdx, r14
    call    er_webp_parse_vp8x
    test    edx, edx
    jnz     .done_parse
    mov     dword [r14 + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8X
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    mov     [r14 + WEBP_HDR_PRIMARY_OFFSET], eax
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    mov     [r14 + WEBP_HDR_PRIMARY_LEN], eax
    jmp     .loop
.chunk_vp8l:
    test    r15d, r15d
    jnz     .corrupt
    cmp     dword [r14 + WEBP_HDR_WIDTH], 0
    jne     .have_vp8l_header
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    mov     rdx, r14
    call    er_webp_parse_vp8l_header
    test    edx, edx
    jnz     .done_parse
.have_vp8l_header:
    mov     dword [r14 + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8L
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    mov     [r14 + WEBP_HDR_PRIMARY_OFFSET], eax
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    mov     [r14 + WEBP_HDR_PRIMARY_LEN], eax
    mov     r15d, 1
    jmp     .loop
.chunk_vp8:
    test    r15d, r15d
    jnz     .corrupt
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    lea     rdx, [rsp + WEBP_PARSE_STACK_VP8_HEADER]
    call    er_vp8_parse_key_frame_header
    test    edx, edx
    jnz     .done_parse
    cmp     dword [r14 + WEBP_HDR_WIDTH], 0
    jne     .have_vp8_header
    movzx   eax, word [rsp + WEBP_PARSE_STACK_VP8_HEADER + VP8_KEY_HEADER_WIDTH]
    mov     [r14 + WEBP_HDR_WIDTH], eax
    movzx   eax, word [rsp + WEBP_PARSE_STACK_VP8_HEADER + VP8_KEY_HEADER_HEIGHT]
    mov     [r14 + WEBP_HDR_HEIGHT], eax
.have_vp8_header:
    mov     dword [r14 + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    mov     [r14 + WEBP_HDR_PRIMARY_OFFSET], eax
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    mov     [r14 + WEBP_HDR_PRIMARY_LEN], eax
    mov     r15d, 1
    jmp     .loop
.chunk_alph:
    cmp     dword [r14 + WEBP_HDR_ALPHA_LEN], 0
    jne     .corrupt
    test    r15d, r15d
    jnz     .corrupt
    cmp     dword [r14 + WEBP_HDR_WIDTH], 0
    je      .corrupt
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_OFFSET]
    mov     [r14 + WEBP_HDR_ALPHA_OFFSET], eax
    mov     eax, [rsp + WEBP_PARSE_STACK_CHUNK + WEBP_CHUNK_DESC_DATA_LEN]
    mov     [r14 + WEBP_HDR_ALPHA_LEN], eax
    jmp     .loop
.finish:
    test    r15d, r15d
    jz      .corrupt
    cmp     dword [r14 + WEBP_HDR_WIDTH], 0
    je      .corrupt
    cmp     dword [r14 + WEBP_HDR_ALPHA_LEN], 0
    je      .no_alpha
    cmp     dword [r14 + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8
    jne     .corrupt
    test    byte [r14 + WEBP_HDR_FLAGS], WEBP_VP8X_FLAG_ALPHA
    jz      .corrupt
    jmp     .ok
.no_alpha:
    cmp     dword [r14 + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8
    jne     .ok
    test    byte [r14 + WEBP_HDR_FLAGS], WEBP_VP8X_FLAG_ALPHA
    jnz     .corrupt
.ok:
    mov     eax, WEBP_HDR_SIZE
    er_ok
    jmp     .done_parse
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_parse
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done_parse
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_parse:
    er_stack_free WEBP_PARSE_STACK_TOTAL
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_webp_decode_vp8_key_frame(buf, len, yuv_out, yuv_cap, out_rgba, out_pixel_cap)
; -> eax=pixels decoded, rdx=error
; Decodes simple WebP containers whose primary image is a VP8 key frame.
er_fn er_webp_decode_vp8_key_frame
    er_push rbx, r12, r13
    er_stack_alloc WEBP_DECODE_STACK_TOTAL
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     [rsp + WEBP_DECODE_STACK_YUV], rdx
    mov     [rsp + WEBP_DECODE_STACK_OUT], r8
    mov     [rsp + WEBP_DECODE_STACK_YUV_CAP], rcx
    mov     [rsp + WEBP_DECODE_STACK_OUT_CAP], r9
    lea     rdx, [rsp + WEBP_DECODE_STACK_HEADER]
    call    er_webp_parse_header
    test    edx, edx
    jnz     .done_decode
    cmp     dword [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_PRIMARY_TYPE], WEBP_CHUNK_VP8
    jne     .unsupported
    mov     eax, [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_PRIMARY_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_PRIMARY_LEN]
    mov     rdx, [rsp + WEBP_DECODE_STACK_YUV]
    mov     rcx, [rsp + WEBP_DECODE_STACK_YUV_CAP]
    mov     r8, [rsp + WEBP_DECODE_STACK_OUT]
    mov     r9, [rsp + WEBP_DECODE_STACK_OUT_CAP]
    call    er_vp8_decode_key_frame
    test    edx, edx
    jnz     .done_decode
    cmp     dword [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_ALPHA_LEN], 0
    je      .done_decode
    mov     [rsp + WEBP_DECODE_STACK_PIXEL_COUNT], rax
    mov     ecx, [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_ALPHA_OFFSET]
    lea     rdi, [r12 + rcx]
    mov     esi, [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_ALPHA_LEN]
    mov     edx, [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_WIDTH]
    mov     ecx, [rsp + WEBP_DECODE_STACK_HEADER + WEBP_HDR_HEIGHT]
    mov     r8, [rsp + WEBP_DECODE_STACK_OUT]
    mov     r9, [rsp + WEBP_DECODE_STACK_PIXEL_COUNT]
    call    er_webp_apply_alpha_values
    test    edx, edx
    jnz     .done_decode
    mov     rax, [rsp + WEBP_DECODE_STACK_PIXEL_COUNT]
    jmp     .done_decode
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_decode
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done_decode:
    er_stack_free WEBP_DECODE_STACK_TOTAL
    er_pop  rbx, r12, r13
    er_ret

; er_webp_apply_alpha_values(alpha_data, len, width, height, out_rgba, pixel_cap)
; -> eax=pixel count, rdx=error
; Supports raw ALPH payloads. Compressed ALPH is VP8L-backed and remains explicit.
er_fn er_webp_apply_alpha_values
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    edx, edx
    jz      .corrupt
    test    ecx, ecx
    jz      .corrupt
    cmp     esi, WEBP_ALPH_HEADER_SIZE
    jb      .corrupt
    mov     r12, rdi
    mov     r13d, edx
    mov     r14d, ecx
    mov     r15, r8
    mov     eax, r13d
    imul    eax, r14d
    jo      .corrupt
    mov     ebx, eax
    cmp     r9d, ebx
    jb      .pixel_budget
    mov     eax, esi
    sub     eax, WEBP_ALPH_HEADER_SIZE
    cmp     eax, ebx
    jne     .corrupt
    movzx   eax, byte [r12]
    mov     edx, eax
    and     edx, WEBP_ALPH_COMPRESSION_MASK
    cmp     edx, WEBP_ALPH_COMPRESSION_NONE
    jne     .unsupported
    and     eax, WEBP_ALPH_FILTER_MASK
    shr     eax, WEBP_ALPH_FILTER_SHIFT
    cmp     eax, WEBP_ALPH_FILTER_GRADIENT
    ja      .corrupt
    xor     ecx, ecx
.copy_loop:
    cmp     ecx, ebx
    jae     .filter
    movzx   edx, byte [r12 + WEBP_ALPH_HEADER_SIZE + rcx]
    mov     [r15 + rcx * 4 + 3], dl
    inc     ecx
    jmp     .copy_loop
.filter:
    cmp     eax, WEBP_ALPH_FILTER_NONE
    je      .ok
    xor     r10d, r10d
.row_loop:
    cmp     r10d, r14d
    jae     .ok
    xor     r11d, r11d
.col_loop:
    cmp     r11d, r13d
    jae     .next_row
    mov     ecx, r10d
    imul    ecx, r13d
    add     ecx, r11d
    cmp     eax, WEBP_ALPH_FILTER_HORIZONTAL
    je      .predict_horizontal
    cmp     eax, WEBP_ALPH_FILTER_VERTICAL
    je      .predict_vertical
    jmp     .predict_gradient
.predict_horizontal:
    test    r11d, r11d
    jnz     .left_predictor
    test    r10d, r10d
    jz      .zero_predictor
    mov     edx, ecx
    sub     edx, r13d
    movzx   edx, byte [r15 + rdx * 4 + 3]
    jmp     .add_predictor
.predict_vertical:
    test    r10d, r10d
    jnz     .top_predictor
    test    r11d, r11d
    jz      .zero_predictor
.left_predictor:
    mov     edx, ecx
    dec     edx
    movzx   edx, byte [r15 + rdx * 4 + 3]
    jmp     .add_predictor
.top_predictor:
    mov     edx, ecx
    sub     edx, r13d
    movzx   edx, byte [r15 + rdx * 4 + 3]
    jmp     .add_predictor
.predict_gradient:
    test    r11d, r11d
    jz      .gradient_first_col
    test    r10d, r10d
    jz      .left_predictor
    mov     edx, ecx
    dec     edx
    movzx   edx, byte [r15 + rdx * 4 + 3]
    mov     r8d, ecx
    sub     r8d, r13d
    movzx   r8d, byte [r15 + r8 * 4 + 3]
    add     edx, r8d
    mov     r8d, ecx
    sub     r8d, r13d
    dec     r8d
    movzx   r8d, byte [r15 + r8 * 4 + 3]
    sub     edx, r8d
    cmp     edx, 0
    jl      .gradient_clamp_low
    cmp     edx, 255
    jg      .gradient_clamp_high
    jmp     .add_predictor
.gradient_clamp_low:
    xor     edx, edx
    jmp     .add_predictor
.gradient_clamp_high:
    mov     edx, 255
    jmp     .add_predictor
.gradient_first_col:
    test    r10d, r10d
    jz      .zero_predictor
    jmp     .top_predictor
.zero_predictor:
    xor     edx, edx
.add_predictor:
    add     [r15 + rcx * 4 + 3], dl
    inc     r11d
    jmp     .col_loop
.next_row:
    inc     r10d
    jmp     .row_loop
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done_alpha
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_alpha
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done_alpha
.pixel_budget:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    jmp     .done_alpha
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_alpha:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_webp_memset(dst, value, len) -> eax=1, rdx=error
er_fn er_webp_memset
    test    rdi, rdi
    jz      .invalid_param
    mov     ecx, edx
    mov     eax, esi
    rep     stosb
    mov     eax, 1
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_webp_chunk_is_critical(type) -> eax=1 if unknown critical chunk
; eax=input chunk type in RIFF byte order
er_fn er_webp_chunk_is_critical
    mov     ecx, eax
    mov     edx, 4
.loop:
    mov     r8b, cl
    cmp     r8b, ' '
    je      .next
    cmp     r8b, 'A'
    jb      .critical
    cmp     r8b, 'Z'
    jbe     .next
    cmp     r8b, 'a'
    jb      .critical
    cmp     r8b, 'z'
    ja      .critical
.next:
    shr     ecx, 8
    dec     edx
    jnz     .loop
    mov     ecx, eax
    and     ecx, 0xff
    cmp     ecx, 'A'
    jb      .not_critical
    cmp     ecx, 'Z'
    ja      .not_critical
.critical:
    mov     eax, 1
    er_ok
    er_ret
.not_critical:
    xor     eax, eax
    er_ok
    er_ret
