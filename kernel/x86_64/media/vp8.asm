; EdgeRun VP8 frame header helpers — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/vp8_constants.inc"

SECTION .text

; er_vp8_memset(dst, value, len) -> eax=dst, rdx=ok
er_fn er_vp8_memset
    mov     rax, rdi
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

; er_vp8_memcpy(dst, src, len) -> eax=dst, rdx=ok
er_fn er_vp8_memcpy
    mov     rax, rdi
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     ecx, edx
    rep     movsb
    mov     eax, 1
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_parse_frame_tag(buf, len, desc) -> eax=VP8_FRAME_TAG_SIZE, rdx=error
; desc: frame_type u8, version u8, show_frame u8, pad, first_partition_len u32.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp8_parse_frame_tag
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     esi, VP8_FRAME_TAG_SIZE
    jb      .no_data
    movzx   eax, byte [rdi]
    movzx   ecx, byte [rdi + 1]
    shl     ecx, 8
    or      eax, ecx
    movzx   ecx, byte [rdi + 2]
    shl     ecx, 16
    or      eax, ecx
    mov     ecx, eax
    and     ecx, VP8_VERSION_MASK
    shr     ecx, VP8_VERSION_SHIFT
    cmp     ecx, VP8_VERSION_MAX
    ja      .unsupported
    mov     r8d, eax
    and     r8d, VP8_SHOW_FRAME_MASK
    shr     r8d, VP8_SHOW_FRAME_SHIFT
    cmp     r8d, VP8_SHOW_FRAME_VISIBLE
    jne     .unsupported
    mov     r9d, eax
    and     r9d, VP8_FRAME_TYPE_MASK
    mov     [rdx + VP8_TAG_DESC_FRAME_TYPE], r9b
    mov     [rdx + VP8_TAG_DESC_VERSION], cl
    mov     [rdx + VP8_TAG_DESC_SHOW_FRAME], r8b
    shr     eax, VP8_FIRST_PARTITION_LEN_SHIFT
    mov     [rdx + VP8_TAG_DESC_FIRST_PARTITION_LEN], eax
    mov     eax, VP8_FRAME_TAG_SIZE
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

; er_vp8_write_visible_frame_tag(out, cap, frame_type, first_partition_len)
; -> eax=VP8_FRAME_TAG_SIZE, rdx=error
; rdi=out, esi=cap, edx=frame_type, ecx=first_partition_len
er_fn er_vp8_write_visible_frame_tag
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_FRAME_TAG_SIZE
    jb      .no_space
    cmp     ecx, VP8_FIRST_PARTITION_LEN_MAX
    ja      .invalid_param
    cmp     edx, VP8_FRAME_TYPE_KEY
    je      .frame_type_ok
    cmp     edx, VP8_FRAME_TYPE_INTER
    jne     .invalid_param
.frame_type_ok:
    mov     eax, ecx
    shl     eax, VP8_FIRST_PARTITION_LEN_SHIFT
    or      eax, VP8_SHOW_FRAME_MASK
    or      eax, edx
    mov     [rdi], al
    shr     eax, 8
    mov     [rdi + 1], al
    shr     eax, 8
    mov     [rdi + 2], al
    mov     eax, VP8_FRAME_TAG_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    er_ret

; er_vp8_write_visible_key_frame_tag(out, cap, first_partition_len)
; rdi=out, esi=cap, edx=first_partition_len
er_fn er_vp8_write_visible_key_frame_tag
    mov     ecx, edx
    mov     edx, VP8_FRAME_TYPE_KEY
    jmp     er_vp8_write_visible_frame_tag

; er_vp8_write_visible_inter_frame_tag(out, cap, first_partition_len)
; rdi=out, esi=cap, edx=first_partition_len
er_fn er_vp8_write_visible_inter_frame_tag
    mov     ecx, edx
    mov     edx, VP8_FRAME_TYPE_INTER
    jmp     er_vp8_write_visible_frame_tag

; er_vp8_is_key_frame(buf, len) -> eax=1 key frame, eax=0 inter frame, rdx=error
; rdi=buf, esi=len
er_fn er_vp8_is_key_frame
    er_stack_alloc VP8_TAG_DESC_SIZE
    lea     rdx, [rsp]
    call    er_vp8_parse_frame_tag
    test    edx, edx
    jnz     .done
    movzx   eax, byte [rsp + VP8_TAG_DESC_FRAME_TYPE]
    xor     eax, VP8_FRAME_TYPE_INTER
.done:
    er_stack_free VP8_TAG_DESC_SIZE
    er_ret

; er_vp8_parse_key_frame_header(buf, len, desc) -> eax=VP8_KEY_FRAME_HEADER_SIZE, rdx=error
; desc: width u16, height u16.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp8_parse_key_frame_header
    er_push rbx, r12
    er_stack_alloc VP8_TAG_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     esi, VP8_KEY_FRAME_HEADER_SIZE
    jb      .no_data
    mov     r12, rdx
    mov     rbx, rdi
    lea     rdx, [rsp]
    call    er_vp8_parse_frame_tag
    test    edx, edx
    jnz     .done
    cmp     byte [rsp + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_KEY
    jne     .unsupported
    cmp     byte [rbx + VP8_START_CODE_OFFSET], VP8_KEY_FRAME_START_CODE_0
    jne     .corrupt
    cmp     byte [rbx + VP8_START_CODE_OFFSET + 1], VP8_KEY_FRAME_START_CODE_1
    jne     .corrupt
    cmp     byte [rbx + VP8_START_CODE_OFFSET + 2], VP8_KEY_FRAME_START_CODE_2
    jne     .corrupt
    movzx   eax, word [rbx + VP8_DIMENSION_WIDTH_OFFSET]
    and     eax, VP8_DIMENSION_MASK
    jz      .corrupt
    movzx   ecx, word [rbx + VP8_DIMENSION_HEIGHT_OFFSET]
    and     ecx, VP8_DIMENSION_MASK
    jz      .corrupt
    mov     [r12 + VP8_KEY_HEADER_WIDTH], ax
    mov     [r12 + VP8_KEY_HEADER_HEIGHT], cx
    mov     eax, VP8_KEY_FRAME_HEADER_SIZE
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
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free VP8_TAG_DESC_SIZE
    er_pop  rbx, r12
    er_ret

; er_vp8_parse_key_frame_payload(buf, len, desc) -> eax=payload bytes consumed, rdx=error
; desc: width u16, height u16, first_offset u32, first_len u32, token_offset u32, token_len u32.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp8_parse_key_frame_payload
    er_push rbx, r12, r13
    er_stack_alloc VP8_TAG_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    lea     rdx, [rsp]
    call    er_vp8_parse_frame_tag
    test    edx, edx
    jnz     .done
    cmp     byte [rsp + VP8_TAG_DESC_FRAME_TYPE], VP8_FRAME_TYPE_KEY
    jne     .unsupported
    mov     eax, [rsp + VP8_TAG_DESC_FIRST_PARTITION_LEN]
    test    eax, eax
    jz      .corrupt
    cmp     r12d, VP8_KEY_FRAME_HEADER_SIZE
    jb      .no_data
    mov     rdi, rbx
    mov     esi, r12d
    mov     rdx, r13
    call    er_vp8_parse_key_frame_header
    test    edx, edx
    jnz     .done
    mov     ecx, [rsp + VP8_TAG_DESC_FIRST_PARTITION_LEN]
    mov     eax, VP8_KEY_FRAME_HEADER_SIZE
    add     eax, ecx
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     [r13 + VP8_KEY_PAYLOAD_FIRST_OFFSET], dword VP8_KEY_FRAME_HEADER_SIZE
    mov     [r13 + VP8_KEY_PAYLOAD_FIRST_LEN], ecx
    mov     [r13 + VP8_KEY_PAYLOAD_TOKEN_OFFSET], eax
    mov     edx, r12d
    sub     edx, eax
    mov     [r13 + VP8_KEY_PAYLOAD_TOKEN_LEN], edx
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
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free VP8_TAG_DESC_SIZE
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_decode_key_frame(data, len, yuv_out, yuv_cap, out_rgba, out_pixel_cap)
; -> eax=pixels decoded, rdx=error
; ASM key-frame decode orchestration. It walks key-frame intra macroblocks,
; reconstructs YUV, then converts the visible frame to RGBA.
er_fn er_vp8_decode_key_frame
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DECODE_STACK_TOTAL
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     [rsp + VP8_DECODE_STACK_YUV], rdx
    mov     [rsp + VP8_DECODE_STACK_OUT], r8
    mov     [rsp + VP8_DECODE_STACK_YUV_CAP], rcx
    mov     [rsp + VP8_DECODE_STACK_OUT_CAP], r9
    lea     rdx, [rsp + VP8_DECODE_STACK_PAYLOAD]
    call    er_vp8_parse_key_frame_payload
    test    edx, edx
    jnz     .done_decode
    movzx   eax, word [rsp + VP8_DECODE_STACK_PAYLOAD + VP8_KEY_PAYLOAD_WIDTH]
    mov     [rsp + VP8_DECODE_STACK_WIDTH], eax
    movzx   eax, word [rsp + VP8_DECODE_STACK_PAYLOAD + VP8_KEY_PAYLOAD_HEIGHT]
    mov     [rsp + VP8_DECODE_STACK_HEIGHT], eax
    mov     edi, [rsp + VP8_DECODE_STACK_WIDTH]
    call    er_vp8_macroblock_dimension
    test    edx, edx
    jnz     .done_decode
    mov     [rsp + VP8_DECODE_STACK_MB_WIDTH], eax
    mov     edi, [rsp + VP8_DECODE_STACK_HEIGHT]
    call    er_vp8_macroblock_dimension
    test    edx, edx
    jnz     .done_decode
    mov     [rsp + VP8_DECODE_STACK_MB_HEIGHT], eax
    mov     eax, [rsp + VP8_DECODE_STACK_WIDTH]
    imul    eax, [rsp + VP8_DECODE_STACK_HEIGHT]
    jc      .invalid_param
    cmp     [rsp + VP8_DECODE_STACK_OUT_CAP], rax
    jb      .no_space
    mov     ebx, eax
    mov     [rsp + VP8_DECODE_STACK_PIXEL_COUNT], eax
    mov     edi, [rsp + VP8_DECODE_STACK_WIDTH]
    call    er_vp8_chroma_dimension
    test    edx, edx
    jnz     .done_decode
    mov     [rsp + VP8_DECODE_STACK_CHROMA_WIDTH], eax
    mov     edi, [rsp + VP8_DECODE_STACK_HEIGHT]
    call    er_vp8_chroma_dimension
    test    edx, edx
    jnz     .done_decode
    mov     [rsp + VP8_DECODE_STACK_CHROMA_HEIGHT], eax
    mov     eax, [rsp + VP8_DECODE_STACK_CHROMA_WIDTH]
    imul    eax, [rsp + VP8_DECODE_STACK_CHROMA_HEIGHT]
    jc      .invalid_param
    mov     [rsp + VP8_DECODE_STACK_CHROMA_COUNT], eax
    lea     eax, [rbx + rax * 2]
    cmp     [rsp + VP8_DECODE_STACK_YUV_CAP], rax
    jb      .no_space
    lea     rdi, [rsp + VP8_DECODE_STACK_TOP_Y]
    mov     esi, VP8_PLANE_EDGE_DEFAULT
    mov     edx, VP8_MAX_LUMA_EDGE
    call    er_vp8_memset
    lea     rdi, [rsp + VP8_DECODE_STACK_TOP_U]
    mov     esi, VP8_PLANE_EDGE_DEFAULT
    mov     edx, VP8_MAX_CHROMA_EDGE
    call    er_vp8_memset
    lea     rdi, [rsp + VP8_DECODE_STACK_TOP_V]
    mov     esi, VP8_PLANE_EDGE_DEFAULT
    mov     edx, VP8_MAX_CHROMA_EDGE
    call    er_vp8_memset
    lea     rdi, [rsp + VP8_DECODE_STACK_TOP_MODES]
    mov     esi, VP8_INTRA4_MODE_DC
    mov     edx, VP8_MAX_LUMA_TOKEN_COLUMNS
    call    er_vp8_memset
    mov     eax, [rsp + VP8_DECODE_STACK_PAYLOAD + VP8_KEY_PAYLOAD_FIRST_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + VP8_DECODE_STACK_PAYLOAD + VP8_KEY_PAYLOAD_FIRST_LEN]
    lea     rdx, [rsp + VP8_DECODE_STACK_COEFF_PROBS]
    lea     rcx, [rsp + VP8_DECODE_STACK_COMPRESSED]
    call    er_vp8_parse_compressed_key_frame_header
    test    edx, edx
    jnz     .done_decode
    cmp     byte [rsp + VP8_DECODE_STACK_COMPRESSED + VP8_COMPRESSED_HEADER_TOKEN_COUNT], 1
    jne     .unsupported
    mov     eax, [rsp + VP8_DECODE_STACK_PAYLOAD + VP8_KEY_PAYLOAD_TOKEN_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + VP8_DECODE_STACK_PAYLOAD + VP8_KEY_PAYLOAD_TOKEN_LEN]
    lea     rdx, [rsp + VP8_DECODE_STACK_TOKEN_READER]
    call    er_vp8_bool_reader_init
    test    edx, edx
    jnz     .done_decode
    mov     dword [rsp + VP8_DECODE_STACK_MB_Y], 0
.decode_row_loop:
    mov     eax, [rsp + VP8_DECODE_STACK_MB_Y]
    cmp     eax, [rsp + VP8_DECODE_STACK_MB_HEIGHT]
    jae     .write_rgba
    lea     rdi, [rsp + VP8_DECODE_STACK_LEFT_Y]
    mov     esi, VP8_PLANE_LEFT_DEFAULT
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_memset
    lea     rdi, [rsp + VP8_DECODE_STACK_LEFT_U]
    mov     esi, VP8_PLANE_LEFT_DEFAULT
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_memset
    lea     rdi, [rsp + VP8_DECODE_STACK_LEFT_V]
    mov     esi, VP8_PLANE_LEFT_DEFAULT
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_memset
    lea     rdi, [rsp + VP8_DECODE_STACK_LEFT_MODES]
    mov     esi, VP8_INTRA4_MODE_DC
    mov     edx, VP8_BLOCK_SIZE
    call    er_vp8_memset
    mov     dword [rsp + VP8_DECODE_STACK_MB_X], 0
.decode_mb_loop:
    mov     eax, [rsp + VP8_DECODE_STACK_MB_X]
    cmp     eax, [rsp + VP8_DECODE_STACK_MB_WIDTH]
    jae     .next_decode_row
    lea     rdi, [rsp + VP8_DECODE_STACK_COMPRESSED]
    mov     esi, [rsp + VP8_DECODE_STACK_MB_X]
    lea     rdx, [rsp + VP8_DECODE_STACK_TOP_MODES]
    lea     rcx, [rsp + VP8_DECODE_STACK_LEFT_MODES]
    lea     r8, [rsp + VP8_DECODE_STACK_MB_HEADER]
    call    er_vp8_read_key_macroblock_header
    test    edx, edx
    jnz     .done_decode
    lea     rdi, [rsp + VP8_DECODE_STACK_COEFFS]
    xor     esi, esi
    mov     edx, VP8_MACROBLOCK_COEFF_BYTES
    call    er_vp8_memset
    cmp     byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_SKIP], 0
    jne     .skip_residual
    lea     rdi, [rsp + VP8_DECODE_STACK_TOKEN_READER]
    lea     rsi, [rsp + VP8_DECODE_STACK_COEFF_PROBS]
    movzx   edx, byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_LUMA_MODE]
    cmp     edx, VP8_LUMA_MODE_B_PRED
    sete    dl
    movzx   edx, dl
    xor     edx, 1
    lea     rcx, [rsp + VP8_DECODE_STACK_COEFFS]
    call    er_vp8_read_residual_macroblock_single
    test    edx, edx
    jnz     .done_decode
.skip_residual:
    lea     rdi, [rsp + VP8_DECODE_STACK_COMPRESSED + VP8_COMPRESSED_HEADER_QUANT]
    lea     rsi, [rsp + VP8_DECODE_STACK_COMPRESSED + VP8_COMPRESSED_HEADER_SEGMENT]
    movzx   edx, byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_SEGMENT_ID]
    lea     rcx, [rsp + VP8_DECODE_STACK_DEQUANT]
    call    er_vp8_build_dequant
    test    edx, edx
    jnz     .done_decode
    lea     rdi, [rsp + VP8_DECODE_STACK_Y_EDGES]
    lea     rsi, [rsp + VP8_DECODE_STACK_TOP_Y]
    lea     rdx, [rsp + VP8_DECODE_STACK_LEFT_Y]
    mov     ecx, [rsp + VP8_DECODE_STACK_MB_X]
    mov     r8d, [rsp + VP8_DECODE_STACK_MB_Y]
    mov     r9d, [rsp + VP8_DECODE_STACK_MB_WIDTH]
    call    er_vp8_make_luma_edges
    test    edx, edx
    jnz     .done_decode
    lea     rdi, [rsp + VP8_DECODE_STACK_U_EDGES]
    lea     rsi, [rsp + VP8_DECODE_STACK_TOP_U]
    lea     rdx, [rsp + VP8_DECODE_STACK_LEFT_U]
    mov     ecx, [rsp + VP8_DECODE_STACK_MB_X]
    mov     r8d, [rsp + VP8_DECODE_STACK_MB_Y]
    call    er_vp8_make_chroma_edges
    test    edx, edx
    jnz     .done_decode
    lea     rdi, [rsp + VP8_DECODE_STACK_V_EDGES]
    lea     rsi, [rsp + VP8_DECODE_STACK_TOP_V]
    lea     rdx, [rsp + VP8_DECODE_STACK_LEFT_V]
    mov     ecx, [rsp + VP8_DECODE_STACK_MB_X]
    mov     r8d, [rsp + VP8_DECODE_STACK_MB_Y]
    call    er_vp8_make_chroma_edges
    test    edx, edx
    jnz     .done_decode
    lea     rdi, [rsp + VP8_DECODE_STACK_DEQUANT]
    movzx   esi, byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_LUMA_MODE]
    movzx   edx, byte [rsp + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_CHROMA_MODE]
    lea     rcx, [rsp + VP8_DECODE_STACK_Y_EDGES]
    lea     r8, [rsp + VP8_DECODE_STACK_U_EDGES]
    lea     r9, [rsp + VP8_DECODE_STACK_V_EDGES]
    lea     rax, [rsp + VP8_DECODE_STACK_V_PLANE]
    push    rax
    lea     rax, [rsp + 8 + VP8_DECODE_STACK_U_PLANE]
    push    rax
    lea     rax, [rsp + 16 + VP8_DECODE_STACK_Y_PLANE]
    push    rax
    lea     rax, [rsp + 24 + VP8_DECODE_STACK_COEFFS]
    push    rax
    lea     rax, [rsp + 32 + VP8_DECODE_STACK_MB_HEADER + VP8_MACROBLOCK_HEADER_INTRA4_MODES]
    push    rax
    call    er_vp8_reconstruct_intra_macroblock
    add     rsp, 40
    test    edx, edx
    jnz     .done_decode
    mov     edi, [rsp + VP8_DECODE_STACK_WIDTH]
    mov     esi, [rsp + VP8_DECODE_STACK_HEIGHT]
    mov     edx, [rsp + VP8_DECODE_STACK_MB_X]
    mov     ecx, [rsp + VP8_DECODE_STACK_MB_Y]
    lea     r8, [rsp + VP8_DECODE_STACK_Y_PLANE]
    mov     r9, [rsp + VP8_DECODE_STACK_YUV]
    call    er_vp8_write_luma_macroblock
    test    edx, edx
    jnz     .done_decode
    mov     edi, [rsp + VP8_DECODE_STACK_CHROMA_WIDTH]
    mov     esi, [rsp + VP8_DECODE_STACK_CHROMA_HEIGHT]
    mov     edx, [rsp + VP8_DECODE_STACK_MB_X]
    mov     ecx, [rsp + VP8_DECODE_STACK_MB_Y]
    lea     r8, [rsp + VP8_DECODE_STACK_U_PLANE]
    lea     r9, [rsp + VP8_DECODE_STACK_V_PLANE]
    mov     r10, [rsp + VP8_DECODE_STACK_YUV]
    mov     eax, [rsp + VP8_DECODE_STACK_PIXEL_COUNT]
    lea     r11, [r10 + rax]
    mov     eax, [rsp + VP8_DECODE_STACK_CHROMA_COUNT]
    lea     r10, [r11 + rax]
    push    r10
    push    r11
    call    er_vp8_write_chroma_macroblock
    add     rsp, 16
    test    edx, edx
    jnz     .done_decode
    lea     rdi, [rsp + VP8_DECODE_STACK_TOP_Y]
    lea     rsi, [rsp + VP8_DECODE_STACK_TOP_U]
    lea     rdx, [rsp + VP8_DECODE_STACK_TOP_V]
    lea     rcx, [rsp + VP8_DECODE_STACK_LEFT_Y]
    lea     r8, [rsp + VP8_DECODE_STACK_LEFT_U]
    lea     r9, [rsp + VP8_DECODE_STACK_LEFT_V]
    lea     rax, [rsp + VP8_DECODE_STACK_V_PLANE]
    push    rax
    lea     rax, [rsp + 8 + VP8_DECODE_STACK_U_PLANE]
    push    rax
    lea     rax, [rsp + 16 + VP8_DECODE_STACK_Y_PLANE]
    push    rax
    mov     eax, [rsp + 24 + VP8_DECODE_STACK_MB_X]
    push    rax
    call    er_vp8_finish_prediction_state
    add     rsp, 32
    test    edx, edx
    jnz     .done_decode
    inc     dword [rsp + VP8_DECODE_STACK_MB_X]
    jmp     .decode_mb_loop
.next_decode_row:
    inc     dword [rsp + VP8_DECODE_STACK_MB_Y]
    jmp     .decode_row_loop
.write_rgba:
    mov     rdi, [rsp + VP8_DECODE_STACK_YUV]
    mov     eax, [rsp + VP8_DECODE_STACK_PIXEL_COUNT]
    lea     rsi, [rdi + rax]
    mov     eax, [rsp + VP8_DECODE_STACK_CHROMA_COUNT]
    lea     rdx, [rsi + rax]
    mov     ecx, [rsp + VP8_DECODE_STACK_WIDTH]
    mov     r8d, [rsp + VP8_DECODE_STACK_HEIGHT]
    mov     r9d, [rsp + VP8_DECODE_STACK_CHROMA_WIDTH]
    push    qword [rsp + VP8_DECODE_STACK_OUT]
    call    er_vp8_write_frame_rgba
    add     rsp, 8
    jmp     .done_decode
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_decode
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done_decode
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
.done_decode:
    er_stack_free VP8_DECODE_STACK_TOTAL
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_bool_reader_init(buf, len, reader) -> eax=VP8_BOOL_READER_SIZE, rdx=error
; rdi=buf, esi=len, rdx=reader
er_fn er_vp8_bool_reader_init
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     esi, VP8_BOOL_INITIAL_BYTES
    jb      .no_data
    mov     [rdx + VP8_BOOL_READER_BUF], rdi
    mov     [rdx + VP8_BOOL_READER_LEN], esi
    mov     [rdx + VP8_BOOL_READER_INPUT_INDEX], dword VP8_BOOL_INITIAL_BYTES
    mov     [rdx + VP8_BOOL_READER_RANGE], dword VP8_BOOL_RANGE_INIT
    movzx   eax, byte [rdi]
    shl     eax, VP8_BOOL_BYTE_BITS
    movzx   ecx, byte [rdi + 1]
    or      eax, ecx
    mov     [rdx + VP8_BOOL_READER_VALUE], eax
    mov     [rdx + VP8_BOOL_READER_BIT_COUNT], dword 0
    mov     eax, VP8_BOOL_READER_SIZE
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

; er_vp8_bool_read(reader, probability) -> eax=0/1, rdx=error
; rdi=reader, esi=probability
er_fn er_vp8_bool_read
    er_push rbx
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_BOOL_PROBABILITY_MAX
    ja      .invalid_param
    mov     eax, [rdi + VP8_BOOL_READER_RANGE]
    test    eax, eax
    jz      .corrupt
    dec     eax
    mul     esi
    shr     eax, VP8_BOOL_BYTE_BITS
    inc     eax
    mov     ecx, eax
    shl     ecx, VP8_BOOL_BYTE_BITS
    mov     edx, [rdi + VP8_BOOL_READER_VALUE]
    cmp     edx, ecx
    jae     .one
    mov     [rdi + VP8_BOOL_READER_RANGE], eax
    xor     ebx, ebx
    jmp     .renorm
.one:
    mov     r8d, [rdi + VP8_BOOL_READER_RANGE]
    sub     r8d, eax
    jz      .corrupt
    mov     [rdi + VP8_BOOL_READER_RANGE], r8d
    sub     edx, ecx
    mov     [rdi + VP8_BOOL_READER_VALUE], edx
    mov     ebx, 1
.renorm:
    mov     eax, [rdi + VP8_BOOL_READER_RANGE]
    cmp     eax, VP8_BOOL_RANGE_RENORM_MIN
    jae     .ok
    shl     dword [rdi + VP8_BOOL_READER_VALUE], 1
    shl     eax, 1
    mov     [rdi + VP8_BOOL_READER_RANGE], eax
    mov     ecx, [rdi + VP8_BOOL_READER_BIT_COUNT]
    inc     ecx
    cmp     ecx, VP8_BOOL_BYTE_BITS
    jne     .store_bit_count
    mov     r8d, [rdi + VP8_BOOL_READER_INPUT_INDEX]
    cmp     r8d, [rdi + VP8_BOOL_READER_LEN]
    jae     .reset_bit_count
    mov     r9, [rdi + VP8_BOOL_READER_BUF]
    movzx   eax, byte [r9 + r8]
    or      [rdi + VP8_BOOL_READER_VALUE], eax
    inc     r8d
    mov     [rdi + VP8_BOOL_READER_INPUT_INDEX], r8d
.reset_bit_count:
    xor     ecx, ecx
.store_bit_count:
    mov     [rdi + VP8_BOOL_READER_BIT_COUNT], ecx
    jmp     .renorm
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done_bool
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_bool
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_bool:
    er_pop  rbx
    er_ret

; er_vp8_bool_read_flag(reader) -> eax=0/1, rdx=error
; rdi=reader
er_fn er_vp8_bool_read_flag
    mov     esi, VP8_BOOL_PROBABILITY_HALF
    jmp     er_vp8_bool_read

; er_vp8_bool_read_literal(reader, bit_count) -> eax=value, rdx=error
; rdi=reader, esi=bit_count
er_fn er_vp8_bool_read_literal
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_BOOL_LITERAL_BITS_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    xor     ebx, ebx
.loop:
    test    r13d, r13d
    jz      .ok
    shl     ebx, 1
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_literal
    or      ebx, eax
    dec     r13d
    jmp     .loop
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done_literal
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_literal:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_parse_token_partitions(buf, len, partition_count, desc)
; -> eax=partition_count, rdx=error
; desc: count u32, then up to 8 entries of payload_offset u32 + payload_len u32.
; rdi=buf, esi=len, edx=partition_count, rcx=desc
er_fn er_vp8_parse_token_partitions
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    cmp     edx, VP8_TOKEN_PARTITION_COUNT_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx
    mov     eax, edx
    dec     eax
    imul    eax, VP8_TOKEN_PARTITION_SIZE_BYTES
    cmp     eax, r13d
    ja      .no_data
    mov     ebx, eax
    mov     [r15 + VP8_TOKEN_PARTITIONS_COUNT], r14d
    xor     r11d, r11d
.loop:
    mov     eax, r14d
    dec     eax
    cmp     r11d, eax
    jae     .last
    mov     eax, r11d
    imul    eax, VP8_TOKEN_PARTITION_SIZE_BYTES
    movzx   ecx, byte [r12 + rax]
    movzx   edx, byte [r12 + rax + 1]
    shl     edx, 8
    or      ecx, edx
    movzx   edx, byte [r12 + rax + 2]
    shl     edx, 16
    or      ecx, edx
    mov     eax, r13d
    sub     eax, ebx
    cmp     ecx, eax
    ja      .corrupt
    mov     eax, r11d
    imul    eax, VP8_TOKEN_PARTITION_ENTRY_SIZE
    mov     [r15 + VP8_TOKEN_PARTITIONS_TABLE + rax + VP8_TOKEN_PARTITION_OFFSET], ebx
    mov     [r15 + VP8_TOKEN_PARTITIONS_TABLE + rax + VP8_TOKEN_PARTITION_LEN], ecx
    add     ebx, ecx
    jc      .corrupt
    inc     r11d
    jmp     .loop
.last:
    mov     eax, r13d
    sub     eax, ebx
    mov     ecx, r11d
    imul    ecx, VP8_TOKEN_PARTITION_ENTRY_SIZE
    mov     [r15 + VP8_TOKEN_PARTITIONS_TABLE + rcx + VP8_TOKEN_PARTITION_OFFSET], ebx
    mov     [r15 + VP8_TOKEN_PARTITIONS_TABLE + rcx + VP8_TOKEN_PARTITION_LEN], eax
    mov     eax, r14d
    er_ok
    jmp     .done_partitions
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_partitions
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done_partitions
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_partitions:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_token_partition_count(partition_bits) -> eax=count, rdx=error
; edi=partition_bits in range 0..3.
er_fn er_vp8_token_partition_count
    cmp     edi, 3
    ja      .invalid_param
    mov     eax, 1
    mov     ecx, edi
    shl     eax, cl
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_updated_motion_vector_probability(update) -> eax=probability, rdx=error
; edi=7-bit update literal.
er_fn er_vp8_updated_motion_vector_probability
    cmp     edi, 0x7f
    ja      .invalid_param
    test    edi, edi
    jnz     .shifted
    mov     eax, VP8_MOTION_VECTOR_UPDATE_ZERO
    er_ok
    er_ret
.shifted:
    mov     eax, edi
    shl     eax, VP8_MOTION_VECTOR_UPDATE_SHIFT
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_bool_read_signed_literal(reader, bit_count) -> eax=signed value, rdx=error
; rdi=reader, esi=bit_count. The result is sign-extended in eax.
er_fn er_vp8_bool_read_signed_literal
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, 7
    ja      .invalid_param
    mov     r12, rdi
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_signed
    mov     ebx, eax
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_signed
    test    eax, eax
    jz      .positive
    neg     ebx
.positive:
    mov     eax, ebx
    er_ok
    jmp     .done_signed
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_signed:
    er_pop  rbx, r12
    er_ret

; er_vp8_bool_read_optional_signed_literal(reader, bit_count) -> eax=signed value, rdx=error
; rdi=reader, esi=bit_count.
er_fn er_vp8_bool_read_optional_signed_literal
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_optional
    test    eax, eax
    jnz     .present
    xor     eax, eax
    er_ok
    jmp     .done_optional
.present:
    mov     rdi, r12
    mov     esi, ebx
    call    er_vp8_bool_read_signed_literal
    jmp     .done_optional
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_optional:
    er_pop  rbx, r12
    er_ret

; er_vp8_parse_quant_indices(reader, desc) -> eax=VP8_QUANT_SIZE, rdx=error
; desc: y_ac u8, y_dc_delta i8, y2_dc_delta i8, y2_ac_delta i8, uv_dc_delta i8, uv_ac_delta i8.
; rdi=reader, rsi=desc
er_fn er_vp8_parse_quant_indices
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rsi
    mov     esi, VP8_QUANT_BASE_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_quant
    mov     [r12 + VP8_QUANT_Y_AC], al
    mov     ebx, VP8_QUANT_Y_DC_DELTA
.delta_loop:
    cmp     ebx, VP8_QUANT_UV_AC_DELTA
    ja      .ok
    mov     esi, VP8_QUANT_DELTA_BITS
    call    er_vp8_bool_read_optional_signed_literal
    test    edx, edx
    jnz     .done_quant
    mov     [r12 + rbx], al
    inc     ebx
    jmp     .delta_loop
.ok:
    mov     eax, VP8_QUANT_SIZE
    er_ok
    jmp     .done_quant
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_quant:
    er_pop  rbx, r12
    er_ret

; er_vp8_quant_index(base, delta) -> eax=clamped index 0..127, rdx=error
; edi=base u8, esi=delta signed.
er_fn er_vp8_quant_index
    cmp     edi, VP8_QUANT_INDEX_MAX
    ja      .invalid_param
    mov     eax, edi
    add     eax, esi
    js      .zero
    cmp     eax, VP8_QUANT_INDEX_MAX
    ja      .max
    er_ok
    er_ret
.zero:
    xor     eax, eax
    er_ok
    er_ret
.max:
    mov     eax, VP8_QUANT_INDEX_MAX
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_segment_quant_base(y_ac, segment_delta, absolute) -> eax=clamped base, rdx=error
; edi=y_ac u8, esi=segment_delta signed, edx=0 relative / 1 absolute.
er_fn er_vp8_segment_quant_base
    cmp     edi, VP8_QUANT_INDEX_MAX
    ja      .invalid_param
    cmp     edx, 1
    ja      .invalid_param
    test    edx, edx
    jnz     .absolute
    add     esi, edi
.absolute:
    mov     eax, esi
    test    eax, eax
    js      .zero
    cmp     eax, VP8_QUANT_INDEX_MAX
    ja      .max
    er_ok
    er_ret
.zero:
    xor     eax, eax
    er_ok
    er_ret
.max:
    mov     eax, VP8_QUANT_INDEX_MAX
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_dc_quant(index) -> eax=DC quant, rdx=error
; edi=quant index 0..127.
er_fn er_vp8_dc_quant
    cmp     edi, VP8_QUANT_INDEX_MAX
    ja      .invalid_param
    lea     rax, [rel vp8_dc_quant]
    movzx   eax, word [rax + rdi * 2]
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_ac_quant(index) -> eax=AC quant, rdx=error
; edi=quant index 0..127.
er_fn er_vp8_ac_quant
    cmp     edi, VP8_QUANT_INDEX_MAX
    ja      .invalid_param
    lea     rax, [rel vp8_ac_quant]
    movzx   eax, word [rax + rdi * 2]
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_build_dequant(quant, segment, segment_id, out) -> eax=VP8_DEQUANT_SIZE, rdx=error
; quant=VP8_QUANT_SIZE, segment=VP8_SEGMENT_HEADER_SIZE, out=Vp8Dequant i16 fields.
; rdi=quant, rsi=segment, edx=segment_id, rcx=out.
er_fn er_vp8_build_dequant
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     edx, VP8_SEGMENT_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15, rcx
    movzx   edi, byte [r12 + VP8_QUANT_Y_AC]
    movsx   esi, byte [r13 + VP8_SEGMENT_QUANT_DELTAS + r14]
    movzx   edx, byte [r13 + VP8_SEGMENT_QUANT_ABSOLUTE]
    call    er_vp8_segment_quant_base
    test    edx, edx
    jnz     .done_dequant
    mov     ebx, eax
    mov     [rsp], eax

    mov     edi, ebx
    movsx   esi, byte [r12 + VP8_QUANT_Y_DC_DELTA]
    call    er_vp8_quant_index
    test    edx, edx
    jnz     .done_dequant
    mov     [rsp + 4], eax
    mov     edi, eax
    call    er_vp8_dc_quant
    test    edx, edx
    jnz     .done_dequant
    mov     [r15 + VP8_DEQUANT_Y_DC], ax

    mov     edi, [rsp]
    call    er_vp8_ac_quant
    test    edx, edx
    jnz     .done_dequant
    mov     [r15 + VP8_DEQUANT_Y_AC], ax

    mov     edi, ebx
    movsx   esi, byte [r12 + VP8_QUANT_Y2_DC_DELTA]
    call    er_vp8_quant_index
    test    edx, edx
    jnz     .done_dequant
    mov     edi, eax
    call    er_vp8_dc_quant
    test    edx, edx
    jnz     .done_dequant
    shl     eax, 1
    mov     [r15 + VP8_DEQUANT_Y2_DC], ax

    mov     edi, ebx
    movsx   esi, byte [r12 + VP8_QUANT_Y2_AC_DELTA]
    call    er_vp8_quant_index
    test    edx, edx
    jnz     .done_dequant
    mov     edi, eax
    call    er_vp8_ac_quant
    test    edx, edx
    jnz     .done_dequant
    imul    eax, 155
    mov     ecx, 100
    cdq
    idiv    ecx
    mov     [r15 + VP8_DEQUANT_Y2_AC], ax

    mov     edi, ebx
    movsx   esi, byte [r12 + VP8_QUANT_UV_DC_DELTA]
    call    er_vp8_quant_index
    test    edx, edx
    jnz     .done_dequant
    mov     edi, eax
    call    er_vp8_dc_quant
    test    edx, edx
    jnz     .done_dequant
    mov     [r15 + VP8_DEQUANT_UV_DC], ax

    mov     edi, ebx
    movsx   esi, byte [r12 + VP8_QUANT_UV_AC_DELTA]
    call    er_vp8_quant_index
    test    edx, edx
    jnz     .done_dequant
    mov     edi, eax
    call    er_vp8_ac_quant
    test    edx, edx
    jnz     .done_dequant
    mov     [r15 + VP8_DEQUANT_UV_AC], ax
    mov     eax, VP8_DEQUANT_SIZE
    er_ok
    jmp     .done_dequant
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_dequant:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_parse_segmentation_header(reader, desc) -> eax=VP8_SEGMENT_HEADER_SIZE, rdx=error
; desc: update_map u8, quant_absolute u8, probabilities[3] u8,
;       quant_deltas[4] i8, loop_filter_deltas[4] i8.
; rdi=reader, rsi=desc
er_fn er_vp8_parse_segmentation_header
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     byte [r13 + VP8_SEGMENT_UPDATE_MAP], 0
    mov     byte [r13 + VP8_SEGMENT_QUANT_ABSOLUTE], 0
    mov     byte [r13 + VP8_SEGMENT_PROBABILITIES], VP8_SEGMENT_PROB_DEFAULT
    mov     byte [r13 + VP8_SEGMENT_PROBABILITIES + 1], VP8_SEGMENT_PROB_DEFAULT
    mov     byte [r13 + VP8_SEGMENT_PROBABILITIES + 2], VP8_SEGMENT_PROB_DEFAULT
    xor     ebx, ebx
.clear_quant:
    cmp     ebx, VP8_SEGMENT_COUNT
    jae     .clear_loop_start
    mov     byte [r13 + VP8_SEGMENT_QUANT_DELTAS + rbx], 0
    inc     ebx
    jmp     .clear_quant
.clear_loop_start:
    xor     ebx, ebx
.clear_loop:
    cmp     ebx, VP8_SEGMENT_COUNT
    jae     .read_enabled
    mov     byte [r13 + VP8_SEGMENT_LOOP_FILTER_DELTAS + rbx], 0
    inc     ebx
    jmp     .clear_loop
.read_enabled:
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    test    eax, eax
    jz      .ok
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    mov     [r13 + VP8_SEGMENT_UPDATE_MAP], al
    mov     r14d, eax
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    test    eax, eax
    jz      .probabilities
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    xor     eax, 1
    mov     [r13 + VP8_SEGMENT_QUANT_ABSOLUTE], al
    xor     ebx, ebx
.quant_loop:
    cmp     ebx, VP8_SEGMENT_COUNT
    jae     .loop_filter_loop_start
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    test    eax, eax
    jz      .next_quant
    mov     rdi, r12
    mov     esi, VP8_QUANTIZER_UPDATE_BITS
    call    er_vp8_bool_read_signed_literal
    test    edx, edx
    jnz     .done_segment
    mov     [r13 + VP8_SEGMENT_QUANT_DELTAS + rbx], al
.next_quant:
    inc     ebx
    jmp     .quant_loop
.loop_filter_loop_start:
    xor     ebx, ebx
.loop_filter_loop:
    cmp     ebx, VP8_SEGMENT_COUNT
    jae     .probabilities
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    test    eax, eax
    jz      .next_loop_filter
    mov     rdi, r12
    mov     esi, VP8_LOOP_FILTER_UPDATE_BITS
    call    er_vp8_bool_read_signed_literal
    test    edx, edx
    jnz     .done_segment
    mov     [r13 + VP8_SEGMENT_LOOP_FILTER_DELTAS + rbx], al
.next_loop_filter:
    inc     ebx
    jmp     .loop_filter_loop
.probabilities:
    test    r14d, r14d
    jz      .ok
    xor     ebx, ebx
.prob_loop:
    cmp     ebx, VP8_SEGMENT_PROB_COUNT
    jae     .ok
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_segment
    test    eax, eax
    jz      .next_prob
    mov     rdi, r12
    mov     esi, VP8_BOOL_BYTE_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_segment
    mov     [r13 + VP8_SEGMENT_PROBABILITIES + rbx], al
.next_prob:
    inc     ebx
    jmp     .prob_loop
.ok:
    mov     eax, VP8_SEGMENT_HEADER_SIZE
    er_ok
    jmp     .done_segment
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_segment:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_parse_loop_filter_header(reader, desc) -> eax=VP8_LOOP_FILTER_HEADER_SIZE, rdx=error
; desc: type u8, level u8, sharpness u8, delta_enabled u8,
;       ref_deltas[4] i8, mode_deltas[4] i8.
; rdi=reader, rsi=desc
er_fn er_vp8_parse_loop_filter_header
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     ebx, ebx
.clear_ref:
    cmp     ebx, VP8_LOOP_FILTER_DELTA_COUNT
    jae     .clear_mode_start
    mov     byte [r13 + VP8_LOOP_FILTER_REF_DELTAS + rbx], 0
    inc     ebx
    jmp     .clear_ref
.clear_mode_start:
    xor     ebx, ebx
.clear_mode:
    cmp     ebx, VP8_LOOP_FILTER_DELTA_COUNT
    jae     .read_type
    mov     byte [r13 + VP8_LOOP_FILTER_MODE_DELTAS + rbx], 0
    inc     ebx
    jmp     .clear_mode
.read_type:
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_loop_filter
    mov     [r13 + VP8_LOOP_FILTER_TYPE], al
    mov     rdi, r12
    mov     esi, VP8_LOOP_FILTER_LEVEL_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_loop_filter
    mov     [r13 + VP8_LOOP_FILTER_LEVEL], al
    mov     rdi, r12
    mov     esi, VP8_LOOP_FILTER_SHARPNESS_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_loop_filter
    mov     [r13 + VP8_LOOP_FILTER_SHARPNESS], al
    mov     byte [r13 + VP8_LOOP_FILTER_DELTA_ENABLED], 0
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_loop_filter
    test    eax, eax
    jz      .ok
    mov     byte [r13 + VP8_LOOP_FILTER_DELTA_ENABLED], 1
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_loop_filter
    test    eax, eax
    jz      .ok
    xor     ebx, ebx
.ref_loop:
    cmp     ebx, VP8_LOOP_FILTER_DELTA_COUNT
    jae     .mode_loop_start
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_loop_filter
    test    eax, eax
    jz      .next_ref
    mov     rdi, r12
    mov     esi, VP8_LOOP_FILTER_UPDATE_BITS
    call    er_vp8_bool_read_signed_literal
    test    edx, edx
    jnz     .done_loop_filter
    mov     [r13 + VP8_LOOP_FILTER_REF_DELTAS + rbx], al
.next_ref:
    inc     ebx
    jmp     .ref_loop
.mode_loop_start:
    xor     ebx, ebx
.mode_loop:
    cmp     ebx, VP8_LOOP_FILTER_DELTA_COUNT
    jae     .ok
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_loop_filter
    test    eax, eax
    jz      .next_mode
    mov     rdi, r12
    mov     esi, VP8_LOOP_FILTER_UPDATE_BITS
    call    er_vp8_bool_read_signed_literal
    test    edx, edx
    jnz     .done_loop_filter
    mov     [r13 + VP8_LOOP_FILTER_MODE_DELTAS + rbx], al
.next_mode:
    inc     ebx
    jmp     .mode_loop
.ok:
    mov     eax, VP8_LOOP_FILTER_HEADER_SIZE
    er_ok
    jmp     .done_loop_filter
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_loop_filter:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_read_reference_copy(reader) -> eax=copy enum, rdx=error
; rdi=reader. Values: 0 none, 1 last, 2 golden. Literal 3 is corrupt.
er_fn er_vp8_read_reference_copy
    test    rdi, rdi
    jz      .invalid_param
    mov     esi, VP8_INTER_COPY_BUFFER_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_copy
    cmp     eax, VP8_REFERENCE_COPY_GOLDEN
    ja      .corrupt
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_copy:
    er_ret

; er_vp8_parse_inter_reference_header(reader, desc) -> eax=VP8_REFERENCE_HEADER_SIZE, rdx=error
; desc: refresh_last u8, refresh_golden u8, refresh_alternate u8,
;       copy_to_golden u8, copy_to_alternate u8, refresh_entropy u8.
; rdi=reader, rsi=desc
er_fn er_vp8_parse_inter_reference_header
    er_push r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     byte [r13 + VP8_REFERENCE_REFRESH_LAST], 0
    mov     byte [r13 + VP8_REFERENCE_REFRESH_GOLDEN], 0
    mov     byte [r13 + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    mov     byte [r13 + VP8_REFERENCE_COPY_TO_GOLDEN], VP8_REFERENCE_COPY_NONE
    mov     byte [r13 + VP8_REFERENCE_COPY_TO_ALTERNATE], VP8_REFERENCE_COPY_NONE
    mov     byte [r13 + VP8_REFERENCE_REFRESH_ENTROPY], 0
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_reference
    mov     [r13 + VP8_REFERENCE_REFRESH_GOLDEN], al
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_reference
    mov     [r13 + VP8_REFERENCE_REFRESH_ALTERNATE], al
    cmp     byte [r13 + VP8_REFERENCE_REFRESH_GOLDEN], 0
    jne     .maybe_copy_alternate
    mov     rdi, r12
    call    er_vp8_read_reference_copy
    test    edx, edx
    jnz     .done_reference
    mov     [r13 + VP8_REFERENCE_COPY_TO_GOLDEN], al
.maybe_copy_alternate:
    cmp     byte [r13 + VP8_REFERENCE_REFRESH_ALTERNATE], 0
    jne     .skip_unused
    mov     rdi, r12
    call    er_vp8_read_reference_copy
    test    edx, edx
    jnz     .done_reference
    mov     [r13 + VP8_REFERENCE_COPY_TO_ALTERNATE], al
.skip_unused:
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_reference
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_reference
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_reference
    mov     [r13 + VP8_REFERENCE_REFRESH_ENTROPY], al
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_reference
    mov     [r13 + VP8_REFERENCE_REFRESH_LAST], al
    mov     eax, VP8_REFERENCE_HEADER_SIZE
    er_ok
    jmp     .done_reference
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_reference:
    er_pop  r12, r13
    er_ret

; er_vp8_parse_compressed_key_frame_header(first_partition, len, coeff_probs, desc)
; -> eax=VP8_COMPRESSED_HEADER_SIZE, rdx=error
; desc stores a copied bool reader, segmentation header, loop filter header, quant indices,
; token partition count, refresh-entropy flag, skip flag/probability, and token update count.
; rdi=first_partition, esi=len, rdx=coeff_probs[1056], rcx=desc.
er_fn er_vp8_parse_compressed_key_frame_header
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdx
    mov     r13, rcx
    mov     rdx, r13
    call    er_vp8_bool_reader_init
    test    edx, edx
    jnz     .done_compressed_key
    mov     r14, r13
    mov     rdi, r14
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_compressed_key
    mov     rdi, r14
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_compressed_key
    mov     rdi, r14
    lea     rsi, [r13 + VP8_COMPRESSED_HEADER_SEGMENT]
    call    er_vp8_parse_segmentation_header
    test    edx, edx
    jnz     .done_compressed_key
    mov     rdi, r14
    lea     rsi, [r13 + VP8_COMPRESSED_HEADER_LOOP_FILTER]
    call    er_vp8_parse_loop_filter_header
    test    edx, edx
    jnz     .done_compressed_key
    mov     rdi, r14
    mov     esi, 2
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_compressed_key
    mov     edi, eax
    call    er_vp8_token_partition_count
    test    edx, edx
    jnz     .done_compressed_key
    mov     [r13 + VP8_COMPRESSED_HEADER_TOKEN_COUNT], al
    mov     rdi, r14
    lea     rsi, [r13 + VP8_COMPRESSED_HEADER_QUANT]
    call    er_vp8_parse_quant_indices
    test    edx, edx
    jnz     .done_compressed_key
    mov     rdi, r14
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_compressed_key
    mov     [r13 + VP8_COMPRESSED_HEADER_REFRESH_ENTROPY], al
    mov     rdi, r12
    call    er_vp8_copy_default_coeff_probabilities
    test    edx, edx
    jnz     .done_compressed_key
    mov     rdi, r14
    mov     rsi, r12
    call    er_vp8_parse_token_probability_updates
    test    edx, edx
    jnz     .done_compressed_key
    mov     [r13 + VP8_COMPRESSED_HEADER_TOKEN_UPDATES], eax
    mov     rdi, r14
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_compressed_key
    mov     [r13 + VP8_COMPRESSED_HEADER_USE_SKIP], al
    mov     byte [r13 + VP8_COMPRESSED_HEADER_SKIP_PROB], 0
    test    eax, eax
    jz      .ok
    mov     rdi, r14
    mov     esi, VP8_SKIP_PROBABILITY_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_compressed_key
    mov     [r13 + VP8_COMPRESSED_HEADER_SKIP_PROB], al
.ok:
    mov     eax, VP8_COMPRESSED_HEADER_SIZE
    er_ok
    jmp     .done_compressed_key
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_compressed_key:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_read_key_macroblock_header(compressed_header, mb_x, top_modes, left_modes, out)
; -> eax=VP8_MACROBLOCK_HEADER_SIZE, rdx=error
; top_modes is VP8_MAX_LUMA_TOKEN_COLUMNS bytes, left_modes is 4 bytes.
; rdi=compressed_header, esi=mb_x, rdx=top_modes, rcx=left_modes, r8=out.
er_fn er_vp8_read_key_macroblock_header
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 8
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     [rsp], esi
    mov     byte [r15 + VP8_MACROBLOCK_HEADER_SEGMENT_ID], 0
    mov     byte [r15 + VP8_MACROBLOCK_HEADER_SKIP], 0
    cmp     byte [r12 + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_UPDATE_MAP], 0
    je      .skip_segment_id
    mov     rdi, r12
    movzx   esi, byte [r12 + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_PROBABILITIES]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_key_mb
    test    eax, eax
    jnz     .segment_high
    mov     rdi, r12
    movzx   esi, byte [r12 + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_PROBABILITIES + 1]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_key_mb
    mov     [r15 + VP8_MACROBLOCK_HEADER_SEGMENT_ID], al
    jmp     .skip_segment_id
.segment_high:
    mov     rdi, r12
    movzx   esi, byte [r12 + VP8_COMPRESSED_HEADER_SEGMENT + VP8_SEGMENT_PROBABILITIES + 2]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_key_mb
    add     al, 2
    mov     [r15 + VP8_MACROBLOCK_HEADER_SEGMENT_ID], al
.skip_segment_id:
    cmp     byte [r12 + VP8_COMPRESSED_HEADER_USE_SKIP], 0
    je      .read_luma_selector
    mov     rdi, r12
    movzx   esi, byte [r12 + VP8_COMPRESSED_HEADER_SKIP_PROB]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_key_mb
    mov     [r15 + VP8_MACROBLOCK_HEADER_SKIP], al
.read_luma_selector:
    mov     rdi, r12
    mov     esi, 145
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_key_mb
    test    eax, eax
    jz      .read_intra4_modes
    mov     rdi, r12
    call    er_vp8_read_intra16_mode
    test    edx, edx
    jnz     .done_key_mb
    mov     [r15 + VP8_MACROBLOCK_HEADER_LUMA_MODE], al
    mov     edi, eax
    call    er_vp8_luma_mode_intra4_mode
    test    edx, edx
    jnz     .done_key_mb
    mov     ebx, eax
    xor     ecx, ecx
.fill_intra16_modes:
    cmp     ecx, VP8_Y_BLOCK_COUNT
    jae     .update_intra16_state
    mov     byte [r15 + VP8_MACROBLOCK_HEADER_INTRA4_MODES + rcx], bl
    inc     ecx
    jmp     .fill_intra16_modes
.update_intra16_state:
    mov     eax, [rsp]
    shl     eax, 2
    xor     ecx, ecx
.update_intra16_top:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .update_intra16_left
    lea     r11, [r13 + rax]
    mov     [r11 + rcx], bl
    inc     ecx
    jmp     .update_intra16_top
.update_intra16_left:
    xor     ecx, ecx
.update_intra16_left_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .read_chroma
    mov     [r14 + rcx], bl
    inc     ecx
    jmp     .update_intra16_left_loop

.read_intra4_modes:
    mov     byte [r15 + VP8_MACROBLOCK_HEADER_LUMA_MODE], VP8_LUMA_MODE_B_PRED
    mov     r10d, [rsp]
    shl     r10d, 2
    xor     ebx, ebx
.intra4_y_loop:
    cmp     ebx, VP8_BLOCK_SIZE
    jae     .read_chroma
    xor     ecx, ecx
.intra4_x_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .next_intra4_y
    lea     r11, [r13 + r10]
    movzx   eax, byte [r11 + rcx]
    cmp     eax, VP8_INTRA4_MODE_HORIZONTAL_UP
    ja      .corrupt
    imul    eax, VP8_INTRA4_MODE_COUNT
    movzx   edx, byte [r14 + rbx]
    cmp     edx, VP8_INTRA4_MODE_HORIZONTAL_UP
    ja      .corrupt
    add     eax, edx
    imul    eax, VP8_INTRA4_PROB_COUNT
    lea     rsi, [rel vp8_intra4_keyframe_probabilities + rax]
    mov     rdi, r12
    push    rcx
    push    r10
    call    er_vp8_read_intra4_mode
    pop     r10
    pop     rcx
    test    edx, edx
    jnz     .done_key_mb
    mov     edx, ebx
    shl     edx, 2
    add     edx, ecx
    mov     [r15 + VP8_MACROBLOCK_HEADER_INTRA4_MODES + rdx], al
    lea     r11, [r13 + r10]
    mov     [r11 + rcx], al
    mov     [r14 + rbx], al
    inc     ecx
    jmp     .intra4_x_loop
.next_intra4_y:
    inc     ebx
    jmp     .intra4_y_loop

.read_chroma:
    mov     rdi, r12
    call    er_vp8_read_chroma_mode
    test    edx, edx
    jnz     .done_key_mb
    mov     [r15 + VP8_MACROBLOCK_HEADER_CHROMA_MODE], al
.ok:
    mov     eax, VP8_MACROBLOCK_HEADER_SIZE
    er_ok
    jmp     .done_key_mb
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    jmp     .done_key_mb
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_key_mb:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_luma_mode_intra4_mode(luma_mode) -> eax=VP8_INTRA4_MODE_*, rdx=error
er_fn er_vp8_luma_mode_intra4_mode
    cmp     edi, VP8_LUMA_MODE_DC
    je      .dc
    cmp     edi, VP8_LUMA_MODE_VERTICAL
    je      .vertical
    cmp     edi, VP8_LUMA_MODE_HORIZONTAL
    je      .horizontal
    cmp     edi, VP8_LUMA_MODE_TRUE_MOTION
    je      .true_motion
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.dc:
    mov     eax, VP8_INTRA4_MODE_DC
    er_ok
    er_ret
.vertical:
    mov     eax, VP8_INTRA4_MODE_VERTICAL
    er_ok
    er_ret
.horizontal:
    mov     eax, VP8_INTRA4_MODE_HORIZONTAL
    er_ok
    er_ret
.true_motion:
    mov     eax, VP8_INTRA4_MODE_TRUE_MOTION
    er_ok
    er_ret

; er_vp8_read_intra16_mode(reader) -> eax=VP8_LUMA_MODE_*, rdx=error
; rdi=reader
er_fn er_vp8_read_intra16_mode
    er_push r12
    test    rdi, rdi
    jz      .invalid_param
    mov     r12, rdi
    mov     esi, VP8_INTRA16_MODE_PROB_0
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra16
    test    eax, eax
    jz      .low_branch
    mov     rdi, r12
    mov     esi, VP8_INTRA16_MODE_PROB_1
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra16
    test    eax, eax
    jz      .horizontal
    mov     eax, VP8_LUMA_MODE_TRUE_MOTION
    er_ok
    jmp     .done_intra16
.horizontal:
    mov     eax, VP8_LUMA_MODE_HORIZONTAL
    er_ok
    jmp     .done_intra16
.low_branch:
    mov     rdi, r12
    mov     esi, VP8_INTRA16_MODE_PROB_2
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra16
    test    eax, eax
    jz      .dc
    mov     eax, VP8_LUMA_MODE_VERTICAL
    er_ok
    jmp     .done_intra16
.dc:
    mov     eax, VP8_LUMA_MODE_DC
    er_ok
    jmp     .done_intra16
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_intra16:
    er_pop  r12
    er_ret

; er_vp8_read_chroma_mode(reader) -> eax=VP8_CHROMA_MODE_*, rdx=error
; rdi=reader
er_fn er_vp8_read_chroma_mode
    er_push r12
    test    rdi, rdi
    jz      .invalid_param
    mov     r12, rdi
    mov     esi, VP8_CHROMA_MODE_PROB_0
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_chroma
    test    eax, eax
    jz      .dc
    mov     rdi, r12
    mov     esi, VP8_CHROMA_MODE_PROB_1
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_chroma
    test    eax, eax
    jz      .vertical
    mov     rdi, r12
    mov     esi, VP8_CHROMA_MODE_PROB_2
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_chroma
    test    eax, eax
    jz      .horizontal
    mov     eax, VP8_CHROMA_MODE_TRUE_MOTION
    er_ok
    jmp     .done_chroma
.horizontal:
    mov     eax, VP8_CHROMA_MODE_HORIZONTAL
    er_ok
    jmp     .done_chroma
.vertical:
    mov     eax, VP8_CHROMA_MODE_VERTICAL
    er_ok
    jmp     .done_chroma
.dc:
    mov     eax, VP8_CHROMA_MODE_DC
    er_ok
    jmp     .done_chroma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_chroma:
    er_pop  r12
    er_ret

; er_vp8_read_inter_intra16_mode(reader, probabilities) -> eax=VP8_LUMA_MODE_*, rdx=error
; rdi=reader, rsi=probabilities[4]
er_fn er_vp8_read_inter_intra16_mode
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    movzx   esi, byte [r13]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_i16
    test    eax, eax
    jnz     .prob1
    mov     eax, VP8_LUMA_MODE_DC
    er_ok
    jmp     .done_inter_i16
.prob1:
    mov     rdi, r12
    movzx   esi, byte [r13 + 1]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_i16
    test    eax, eax
    jnz     .prob3
    mov     rdi, r12
    movzx   esi, byte [r13 + 2]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_i16
    test    eax, eax
    jz      .vertical
    mov     eax, VP8_LUMA_MODE_HORIZONTAL
    er_ok
    jmp     .done_inter_i16
.vertical:
    mov     eax, VP8_LUMA_MODE_VERTICAL
    er_ok
    jmp     .done_inter_i16
.prob3:
    mov     rdi, r12
    movzx   esi, byte [r13 + 3]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_i16
    test    eax, eax
    jnz     .b_pred
    mov     eax, VP8_LUMA_MODE_TRUE_MOTION
    er_ok
    jmp     .done_inter_i16
.b_pred:
    mov     eax, VP8_LUMA_MODE_B_PRED
    er_ok
    jmp     .done_inter_i16
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_inter_i16:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_read_inter_chroma_mode(reader, probabilities) -> eax=VP8_CHROMA_MODE_*, rdx=error
; rdi=reader, rsi=probabilities[3]
er_fn er_vp8_read_inter_chroma_mode
    er_push r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    movzx   esi, byte [r13]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_chroma
    test    eax, eax
    jnz     .prob1
    mov     eax, VP8_CHROMA_MODE_DC
    er_ok
    jmp     .done_inter_chroma
.prob1:
    mov     rdi, r12
    movzx   esi, byte [r13 + 1]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_chroma
    test    eax, eax
    jnz     .prob2
    mov     eax, VP8_CHROMA_MODE_VERTICAL
    er_ok
    jmp     .done_inter_chroma
.prob2:
    mov     rdi, r12
    movzx   esi, byte [r13 + 2]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_inter_chroma
    test    eax, eax
    jz      .horizontal
    mov     eax, VP8_CHROMA_MODE_TRUE_MOTION
    er_ok
    jmp     .done_inter_chroma
.horizontal:
    mov     eax, VP8_CHROMA_MODE_HORIZONTAL
    er_ok
    jmp     .done_inter_chroma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_inter_chroma:
    er_pop  r12, r13
    er_ret

; er_vp8_read_intra4_mode(reader, probabilities) -> eax=VP8_INTRA4_MODE_*, rdx=error
; rdi=reader, rsi=probabilities[9]
er_fn er_vp8_read_intra4_mode
    er_push r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    movzx   esi, byte [r13]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob1
    mov     eax, VP8_INTRA4_MODE_DC
    er_ok
    jmp     .done_intra4
.prob1:
    mov     rdi, r12
    movzx   esi, byte [r13 + 1]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob2
    mov     eax, VP8_INTRA4_MODE_TRUE_MOTION
    er_ok
    jmp     .done_intra4
.prob2:
    mov     rdi, r12
    movzx   esi, byte [r13 + 2]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob3
    mov     eax, VP8_INTRA4_MODE_VERTICAL
    er_ok
    jmp     .done_intra4
.prob3:
    mov     rdi, r12
    movzx   esi, byte [r13 + 3]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob6
    mov     rdi, r12
    movzx   esi, byte [r13 + 4]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob5
    mov     eax, VP8_INTRA4_MODE_HORIZONTAL
    er_ok
    jmp     .done_intra4
.prob5:
    mov     rdi, r12
    movzx   esi, byte [r13 + 5]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jz      .right_down
    mov     eax, VP8_INTRA4_MODE_VERTICAL_RIGHT
    er_ok
    jmp     .done_intra4
.right_down:
    mov     eax, VP8_INTRA4_MODE_RIGHT_DOWN
    er_ok
    jmp     .done_intra4
.prob6:
    mov     rdi, r12
    movzx   esi, byte [r13 + 6]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob7
    mov     eax, VP8_INTRA4_MODE_LEFT_DOWN
    er_ok
    jmp     .done_intra4
.prob7:
    mov     rdi, r12
    movzx   esi, byte [r13 + 7]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jnz     .prob8
    mov     eax, VP8_INTRA4_MODE_VERTICAL_LEFT
    er_ok
    jmp     .done_intra4
.prob8:
    mov     rdi, r12
    movzx   esi, byte [r13 + 8]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_intra4
    test    eax, eax
    jz      .horizontal_down
    mov     eax, VP8_INTRA4_MODE_HORIZONTAL_UP
    er_ok
    jmp     .done_intra4
.horizontal_down:
    mov     eax, VP8_INTRA4_MODE_HORIZONTAL_DOWN
    er_ok
    jmp     .done_intra4
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_intra4:
    er_pop  r12, r13
    er_ret

; er_vp8_read_category_coeff_value(reader, category) -> eax=value, rdx=error
; rdi=reader, esi=category 0..3.
er_fn er_vp8_read_category_coeff_value
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, 3
    ja      .corrupt
    mov     r12, rdi
    xor     ebx, ebx
    cmp     esi, 0
    je      .cat3
    cmp     esi, 1
    je      .cat4
    cmp     esi, 2
    je      .cat5
    lea     r13, [rel vp8_coeff_cat6_probs]
    mov     r14d, VP8_COEFF_CAT6_PROB_COUNT
    mov     r15d, VP8_COEFF_CAT6_BASE
    jmp     .loop
.cat3:
    lea     r13, [rel vp8_coeff_cat3_probs]
    mov     r14d, VP8_COEFF_CAT3_PROB_COUNT
    mov     r15d, VP8_COEFF_CAT3_BASE
    jmp     .loop
.cat4:
    lea     r13, [rel vp8_coeff_cat4_probs]
    mov     r14d, VP8_COEFF_CAT4_PROB_COUNT
    mov     r15d, VP8_COEFF_CAT4_BASE
    jmp     .loop
.cat5:
    lea     r13, [rel vp8_coeff_cat5_probs]
    mov     r14d, VP8_COEFF_CAT5_PROB_COUNT
    mov     r15d, VP8_COEFF_CAT5_BASE
.loop:
    test    r14d, r14d
    jz      .ok
    shl     ebx, 1
    mov     rdi, r12
    movzx   esi, byte [r13]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_category
    or      ebx, eax
    inc     r13
    dec     r14d
    jmp     .loop
.ok:
    lea     eax, [rbx + r15]
    er_ok
    jmp     .done_category
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_category
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_category:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_read_signed_coeff(reader, magnitude) -> eax=signed coeff, rdx=error
; rdi=reader, esi=positive magnitude.
er_fn er_vp8_read_signed_coeff
    er_push rbx
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jle     .corrupt
    mov     ebx, esi
    call    er_vp8_bool_read_flag
    test    edx, edx
    jnz     .done_signed_coeff
    test    eax, eax
    jz      .positive
    neg     ebx
.positive:
    mov     eax, ebx
    er_ok
    jmp     .done_signed_coeff
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done_signed_coeff
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_signed_coeff:
    er_pop  rbx
    er_ret

; er_vp8_macroblock_dimension(pixel_dimension) -> eax=ceil(pixel_dimension / 16), rdx=error
; edi=pixel_dimension. Zero dimensions are corrupt.
er_fn er_vp8_macroblock_dimension
    test    edi, edi
    jz      .corrupt
    mov     eax, edi
    add     eax, VP8_MACROBLOCK_SIZE - 1
    jc      .corrupt
    shr     eax, 4
    er_ok
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_vp8_macroblock_count(width, height) -> eax=count, rdx=error
; edi=width, esi=height.
er_fn er_vp8_macroblock_count
    er_push rbx, r12
    call    er_vp8_macroblock_dimension
    test    edx, edx
    jnz     .done_count
    mov     ebx, eax
    mov     edi, esi
    call    er_vp8_macroblock_dimension
    test    edx, edx
    jnz     .done_count
    mov     r12d, eax
    mov     eax, ebx
    mul     r12d
    test    edx, edx
    jnz     .corrupt
    er_ok
    jmp     .done_count
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done_count:
    er_pop  rbx, r12
    er_ret

; er_vp8_chroma_dimension(pixel_dimension) -> eax=ceil(pixel_dimension / 2), rdx=error
er_fn er_vp8_chroma_dimension
    test    edi, edi
    jz      .invalid_param
    lea     eax, [rdi + 1]
    shr     eax, 1
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_write_luma_macroblock(width, height, mb_x, mb_y, y_plane, out_y)
; -> eax=pixels written, rdx=error
er_fn er_vp8_write_luma_macroblock
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    edi, edi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    mov     r12d, edi
    mov     r13d, esi
    mov     r14d, edx
    shl     r14d, 4
    mov     r15d, ecx
    shl     r15d, 4
    mov     rbx, r8
    mov     [rsp], r9
    mov     dword [rsp + 8], 0
    xor     r8d, r8d
.row_loop:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .ok
    mov     eax, r15d
    add     eax, r8d
    cmp     eax, r13d
    jae     .ok
    xor     r9d, r9d
.col_loop:
    cmp     r9d, VP8_MACROBLOCK_SIZE
    jae     .next_row
    mov     ecx, r14d
    add     ecx, r9d
    cmp     ecx, r12d
    jae     .next_row
    mov     edx, r8d
    shl     edx, 4
    add     edx, r9d
    movzx   edx, byte [rbx + rdx]
    imul    eax, r12d
    add     eax, ecx
    mov     r10, [rsp]
    mov     [r10 + rax], dl
    inc     dword [rsp + 8]
    mov     eax, r15d
    add     eax, r8d
    inc     r9d
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, [rsp + 8]
    er_ok
    jmp     .done_luma_write
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_luma_write:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_write_chroma_macroblock(chroma_width, chroma_height, mb_x, mb_y, u_plane, v_plane, out_u, out_v)
; -> eax=samples written per plane, rdx=error
er_fn er_vp8_write_chroma_macroblock
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 24
    test    edi, edi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    mov     rax, [rsp + 72]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp], rax
    mov     rax, [rsp + 80]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 8], rax
    mov     r12d, edi
    mov     r13d, esi
    mov     r14d, edx
    shl     r14d, 3
    mov     r15d, ecx
    shl     r15d, 3
    mov     rbx, r8
    mov     [rsp + 16], r9
    xor     r8d, r8d
    xor     r11d, r11d
.row_loop:
    cmp     r8d, VP8_CHROMA_BLOCK_SIZE
    jae     .ok
    mov     eax, r15d
    add     eax, r8d
    cmp     eax, r13d
    jae     .ok
    xor     r9d, r9d
.col_loop:
    cmp     r9d, VP8_CHROMA_BLOCK_SIZE
    jae     .next_row
    mov     ecx, r14d
    add     ecx, r9d
    cmp     ecx, r12d
    jae     .next_row
    mov     edx, r8d
    shl     edx, 3
    add     edx, r9d
    imul    eax, r12d
    add     eax, ecx
    movzx   ecx, byte [rbx + rdx]
    mov     r10, [rsp]
    mov     [r10 + rax], cl
    mov     r10, [rsp + 16]
    movzx   ecx, byte [r10 + rdx]
    mov     r10, [rsp + 8]
    mov     [r10 + rax], cl
    inc     r11d
    mov     eax, r15d
    add     eax, r8d
    inc     r9d
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, r11d
    er_ok
    jmp     .done_chroma_write
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_chroma_write:
    er_stack_free 24
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_read_reference_luma_nearest(width, height, mb_x, mb_y, row_offset, col_offset, previous, out)
; -> eax=256 samples, rdx=error. Full-pixel reference copy with clamped source coordinates.
er_fn er_vp8_read_reference_luma_nearest
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    test    edi, edi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    mov     rax, [rsp + 80]
    test    rax, rax
    jz      .invalid_param
    mov     rbx, rax
    mov     rax, [rsp + 88]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp], rax
    mov     r12d, edi
    mov     r13d, esi
    mov     r14d, edx
    shl     r14d, 4
    mov     r15d, ecx
    shl     r15d, 4
    mov     [rsp + 8], r8d
    mov     [rsp + 12], r9d
    xor     r8d, r8d
.row_loop:
    cmp     r8d, VP8_MACROBLOCK_SIZE
    jae     .ok
    xor     r9d, r9d
.col_loop:
    cmp     r9d, VP8_MACROBLOCK_SIZE
    jae     .next_row
    mov     eax, r15d
    add     eax, r8d
    cmp     eax, r13d
    jb      .origin_y_ok
    mov     eax, r13d
    dec     eax
.origin_y_ok:
    add     eax, [rsp + 8]
    jns     .src_y_nonnegative
    xor     eax, eax
    jmp     .src_y_ready
.src_y_nonnegative:
    cmp     eax, r13d
    jb      .src_y_ready
    mov     eax, r13d
    dec     eax
.src_y_ready:
    mov     r10d, eax
    mov     eax, r14d
    add     eax, r9d
    cmp     eax, r12d
    jb      .origin_x_ok
    mov     eax, r12d
    dec     eax
.origin_x_ok:
    add     eax, [rsp + 12]
    jns     .src_x_nonnegative
    xor     eax, eax
    jmp     .src_x_ready
.src_x_nonnegative:
    cmp     eax, r12d
    jb      .src_x_ready
    mov     eax, r12d
    dec     eax
.src_x_ready:
    mov     r11d, r10d
    imul    r11d, r12d
    add     r11d, eax
    movzx   eax, byte [rbx + r11]
    mov     edx, r8d
    shl     edx, 4
    add     edx, r9d
    mov     r10, [rsp]
    mov     [r10 + rdx], al
    inc     r9d
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    er_ok
    jmp     .done_ref_luma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_ref_luma:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_read_reference_chroma_nearest(chroma_width, chroma_height, mb_x, mb_y, row_offset, col_offset, prev_u, prev_v, out_u, out_v)
; -> eax=64 samples per plane, rdx=error.
er_fn er_vp8_read_reference_chroma_nearest
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 48
    test    edi, edi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    mov     rax, [rsp + 96]
    test    rax, rax
    jz      .invalid_param
    mov     rbx, rax
    mov     rax, [rsp + 104]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp], rax
    mov     rax, [rsp + 112]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 8], rax
    mov     rax, [rsp + 120]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 16], rax
    mov     r12d, edi
    mov     r13d, esi
    mov     r14d, edx
    shl     r14d, 3
    mov     r15d, ecx
    shl     r15d, 3
    mov     [rsp + 24], r8d
    mov     [rsp + 28], r9d
    xor     r8d, r8d
.row_loop:
    cmp     r8d, VP8_CHROMA_BLOCK_SIZE
    jae     .ok
    xor     r9d, r9d
.col_loop:
    cmp     r9d, VP8_CHROMA_BLOCK_SIZE
    jae     .next_row
    mov     eax, r15d
    add     eax, r8d
    cmp     eax, r13d
    jb      .origin_y_ok
    mov     eax, r13d
    dec     eax
.origin_y_ok:
    add     eax, [rsp + 24]
    jns     .src_y_nonnegative
    xor     eax, eax
    jmp     .src_y_ready
.src_y_nonnegative:
    cmp     eax, r13d
    jb      .src_y_ready
    mov     eax, r13d
    dec     eax
.src_y_ready:
    mov     r10d, eax
    mov     eax, r14d
    add     eax, r9d
    cmp     eax, r12d
    jb      .origin_x_ok
    mov     eax, r12d
    dec     eax
.origin_x_ok:
    add     eax, [rsp + 28]
    jns     .src_x_nonnegative
    xor     eax, eax
    jmp     .src_x_ready
.src_x_nonnegative:
    cmp     eax, r12d
    jb      .src_x_ready
    mov     eax, r12d
    dec     eax
.src_x_ready:
    mov     r11d, r10d
    imul    r11d, r12d
    add     r11d, eax
    mov     edx, r8d
    shl     edx, 3
    add     edx, r9d
    movzx   eax, byte [rbx + r11]
    mov     r10, [rsp + 8]
    mov     [r10 + rdx], al
    mov     r10, [rsp]
    movzx   eax, byte [r10 + r11]
    mov     r10, [rsp + 16]
    mov     [r10 + rdx], al
    inc     r9d
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, VP8_CHROMA_BLOCK_SIZE * VP8_CHROMA_BLOCK_SIZE
    er_ok
    jmp     .done_ref_chroma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_ref_chroma:
    er_stack_free 48
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_subpixel_filter_value(values, phase) -> eax=filtered u8, rdx=error
; values points to 6 u8 taps. phase is 0..7.
er_fn er_vp8_subpixel_filter_value
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_SUBPIXEL_FILTER_PHASE_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    imul    r13d, VP8_SUBPIXEL_FILTER_TAP_COUNT * 2
    lea     rbx, [rel vp8_subpixel_filters + r13]
    mov     r13d, VP8_SUBPIXEL_FILTER_ROUND
    xor     ecx, ecx
.tap_loop:
    cmp     ecx, VP8_SUBPIXEL_FILTER_TAP_COUNT
    jae     .clamp
    movzx   eax, byte [r12 + rcx]
    movsx   edx, word [rbx + rcx * 2]
    imul    eax, edx
    add     r13d, eax
    inc     ecx
    jmp     .tap_loop
.clamp:
    mov     edi, r13d
    sar     edi, VP8_SUBPIXEL_FILTER_SHIFT
    call    er_vp8_clamp_u8
    jmp     .done_filter_value
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_filter_value:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_reference_horizontal_sample(plane, width, height, origin_x, origin_y, row_offset, col_offset, phase)
; -> eax=filtered u8, rdx=error
er_fn er_vp8_reference_horizontal_sample
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    mov     eax, [rsp + 72]
    cmp     eax, VP8_SUBPIXEL_FILTER_PHASE_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp + 8], r9d
    mov     eax, [rsp + 64]
    mov     [rsp + 12], eax
    mov     eax, ebx
    add     eax, [rsp + 8]
    jns     .src_y_nonnegative
    xor     eax, eax
    jmp     .src_y_ready
.src_y_nonnegative:
    cmp     eax, r14d
    jb      .src_y_ready
    mov     eax, r14d
    dec     eax
.src_y_ready:
    imul    eax, r13d
    mov     [rsp + 8], eax
    xor     ecx, ecx
.tap_loop:
    cmp     ecx, VP8_SUBPIXEL_FILTER_TAP_COUNT
    jae     .filter
    mov     eax, r15d
    add     eax, [rsp + 12]
    add     eax, ecx
    sub     eax, 2
    jns     .src_x_nonnegative
    xor     eax, eax
    jmp     .src_x_ready
.src_x_nonnegative:
    cmp     eax, r13d
    jb      .src_x_ready
    mov     eax, r13d
    dec     eax
.src_x_ready:
    add     eax, [rsp + 8]
    movzx   eax, byte [r12 + rax]
    mov     [rsp + rcx], al
    inc     ecx
    jmp     .tap_loop
.filter:
    mov     rdi, rsp
    mov     esi, [rsp + 72]
    call    er_vp8_subpixel_filter_value
    jmp     .done_horizontal_sample
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_horizontal_sample:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_reference_vertical_sample(plane, width, height, origin_x, origin_y, row_offset, col_offset, phase)
; -> eax=filtered u8, rdx=error
er_fn er_vp8_reference_vertical_sample
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    mov     eax, [rsp + 72]
    cmp     eax, VP8_SUBPIXEL_FILTER_PHASE_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp + 8], r9d
    mov     eax, [rsp + 64]
    mov     [rsp + 12], eax
    mov     eax, r15d
    add     eax, [rsp + 12]
    jns     .src_x_nonnegative
    xor     eax, eax
    jmp     .src_x_ready
.src_x_nonnegative:
    cmp     eax, r13d
    jb      .src_x_ready
    mov     eax, r13d
    dec     eax
.src_x_ready:
    mov     [rsp + 12], eax
    xor     ecx, ecx
.tap_loop:
    cmp     ecx, VP8_SUBPIXEL_FILTER_TAP_COUNT
    jae     .filter
    mov     eax, ebx
    add     eax, [rsp + 8]
    add     eax, ecx
    sub     eax, 2
    jns     .src_y_nonnegative
    xor     eax, eax
    jmp     .src_y_ready
.src_y_nonnegative:
    cmp     eax, r14d
    jb      .src_y_ready
    mov     eax, r14d
    dec     eax
.src_y_ready:
    imul    eax, r13d
    add     eax, [rsp + 12]
    movzx   eax, byte [r12 + rax]
    mov     [rsp + rcx], al
    inc     ecx
    jmp     .tap_loop
.filter:
    mov     rdi, rsp
    mov     esi, [rsp + 72]
    call    er_vp8_subpixel_filter_value
    jmp     .done_vertical_sample
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_vertical_sample:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_reference_subpixel_sample(plane, width, height, origin_x, origin_y, row_offset, col_offset, row_phase, col_phase)
; -> eax=filtered u8, rdx=error
er_fn er_vp8_reference_subpixel_sample
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    mov     eax, [rsp + 88]
    cmp     eax, VP8_SUBPIXEL_FILTER_PHASE_COUNT
    jae     .invalid_param
    mov     eax, [rsp + 96]
    cmp     eax, VP8_SUBPIXEL_FILTER_PHASE_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp + 8], r9d
    mov     eax, [rsp + 80]
    mov     [rsp + 12], eax
    mov     eax, [rsp + 88]
    mov     [rsp + 16], eax
    mov     eax, [rsp + 96]
    mov     [rsp + 20], eax
    mov     dword [rsp + 4], 0
.tap_loop:
    mov     ecx, [rsp + 4]
    cmp     ecx, VP8_SUBPIXEL_FILTER_TAP_COUNT
    jae     .filter
    mov     r9d, [rsp + 8]
    add     r9d, ecx
    sub     r9d, 2
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, r15d
    mov     r8d, ebx
    movsxd  r10, dword [rsp + 20]
    movsxd  r11, dword [rsp + 12]
    push    r10
    push    r11
    call    er_vp8_reference_horizontal_sample
    add     rsp, 16
    test    edx, edx
    jnz     .done_subpixel_sample
    mov     ecx, [rsp + 4]
    mov     [rsp + 24 + rcx], al
    inc     dword [rsp + 4]
    jmp     .tap_loop
.filter:
    lea     rdi, [rsp + 24]
    mov     esi, [rsp + 16]
    call    er_vp8_subpixel_filter_value
    jmp     .done_subpixel_sample
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_subpixel_sample:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_abs_diff_u8(left, right) -> eax=abs(left-right), rdx=error
er_fn er_vp8_abs_diff_u8
    movzx   eax, dil
    movzx   ecx, sil
    cmp     eax, ecx
    jae     .ok
    xchg    eax, ecx
.ok:
    sub     eax, ecx
    er_ok
    er_ret

; er_vp8_saturate_i8(value) -> eax=clamped -128..127, rdx=error
er_fn er_vp8_saturate_i8
    cmp     edi, -128
    jl      .min
    cmp     edi, 127
    jg      .max
    mov     eax, edi
    er_ok
    er_ret
.min:
    mov     eax, -128
    er_ok
    er_ret
.max:
    mov     eax, 127
    er_ok
    er_ret

; er_vp8_filter_normal_macroblock_vertical_edge(plane, width, height, edge_x, edge_y, edge_limit, interior_limit, hev_threshold, size)
; -> eax=edges filtered, rdx=error
er_fn er_vp8_filter_normal_macroblock_vertical_edge
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 48
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    cmp     ecx, 4
    jb      .ok_zero
    mov     eax, ecx
    add     eax, 3
    cmp     eax, esi
    jae     .ok_zero
    mov     eax, [rsp + 112]
    test    eax, eax
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp], r9d
    mov     eax, [rsp + 96]
    mov     [rsp + 4], eax
    mov     eax, [rsp + 112]
    imul    eax, VP8_CHROMA_BLOCK_SIZE
    mov     [rsp + 8], eax
    mov     dword [rsp + 12], 0
    mov     dword [rsp + 44], 0
.row_loop:
    mov     eax, [rsp + 12]
    cmp     eax, [rsp + 8]
    jae     .ok
    mov     ecx, ebx
    add     ecx, eax
    cmp     ecx, r14d
    jae     .ok
    imul    ecx, r13d
    add     ecx, r15d
    jmp     .filter_one
.after_filter_one:
    inc     dword [rsp + 12]
    jmp     .row_loop
.filter_one:
    mov     [rsp + 40], ecx
    movzx   eax, byte [r12 + rcx - 4]
    mov     [rsp + 16], eax
    movzx   eax, byte [r12 + rcx - 3]
    mov     [rsp + 20], eax
    movzx   eax, byte [r12 + rcx - 2]
    mov     [rsp + 24], eax
    movzx   eax, byte [r12 + rcx - 1]
    mov     [rsp + 28], eax
    movzx   eax, byte [r12 + rcx]
    mov     [rsp + 32], eax
    movzx   eax, byte [r12 + rcx + 1]
    mov     [rsp + 36], eax
    movzx   edi, byte [r12 + rcx - 1]
    movzx   esi, byte [r12 + rcx]
    call    er_vp8_abs_diff_u8
    lea     eax, [rax * 2]
    mov     r10d, eax
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx - 2]
    movzx   esi, byte [r12 + rcx + 1]
    call    er_vp8_abs_diff_u8
    shr     eax, 1
    add     r10d, eax
    mov     eax, [rsp]
    shl     eax, 1
    add     eax, [rsp + 4]
    cmp     eax, 255
    jbe     .limit_ready
    mov     eax, 255
.limit_ready:
    cmp     r10d, eax
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx - 4]
    movzx   esi, byte [r12 + rcx - 3]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx - 3]
    movzx   esi, byte [r12 + rcx - 2]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx - 2]
    movzx   esi, byte [r12 + rcx - 1]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx + 2]
    movzx   esi, byte [r12 + rcx + 1]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx + 3]
    movzx   esi, byte [r12 + rcx + 2]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx + 1]
    movzx   esi, byte [r12 + rcx]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     edi, [rsp + 24]
    mov     esi, [rsp + 28]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 104]
    ja      .write_common_outer
    mov     edi, [rsp + 36]
    mov     esi, [rsp + 32]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 104]
    ja      .write_common_outer
    mov     edi, [rsp + 24]
    sub     edi, [rsp + 36]
    call    er_vp8_saturate_i8
    mov     edi, eax
    mov     eax, [rsp + 32]
    sub     eax, [rsp + 28]
    lea     edi, [rdi + rax * 2]
    add     edi, eax
    call    er_vp8_saturate_i8
    mov     r11d, eax
    mov     eax, r11d
    imul    eax, 27
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 28]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx - 1], al
    mov     eax, r11d
    imul    eax, 27
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 32]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx], al
    mov     eax, r11d
    imul    eax, 18
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 24]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx - 2], al
    mov     eax, r11d
    imul    eax, 18
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 36]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx + 1], al
    mov     eax, r11d
    imul    eax, 9
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 20]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx - 3], al
    mov     eax, r11d
    imul    eax, 9
    add     eax, 63
    sar     eax, 7
    mov     ecx, [rsp + 40]
    movzx   edi, byte [r12 + rcx + 2]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     [r12 + rcx + 2], al
    inc     dword [rsp + 44]
.filtered_ret:
    jmp     .after_filter_one
.write_common_outer:
    mov     eax, [rsp + 32]
    sub     eax, [rsp + 28]
    lea     edi, [rax + rax * 2]
    mov     eax, [rsp + 24]
    sub     eax, [rsp + 36]
    add     edi, eax
    call    er_vp8_saturate_i8
    mov     r11d, eax
    mov     eax, r11d
    add     eax, 4
    cmp     eax, 127
    jle     .vertical_common_f1_ready
    mov     eax, 127
.vertical_common_f1_ready:
    sar     eax, 3
    mov     edi, [rsp + 32]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx], al
    mov     eax, r11d
    add     eax, 3
    cmp     eax, 127
    jle     .vertical_common_f2_ready
    mov     eax, 127
.vertical_common_f2_ready:
    sar     eax, 3
    mov     edi, [rsp + 28]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx - 1], al
    inc     dword [rsp + 44]
    jmp     .filtered_ret
.ok_zero:
    xor     eax, eax
    er_ok
    jmp     .done_filter_vertical
.ok:
    mov     eax, [rsp + 44]
    er_ok
    jmp     .done_filter_vertical
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_filter_vertical:
    er_stack_free 48
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_filter_normal_macroblock_horizontal_edge(plane, width, height, edge_x, edge_y, edge_limit, interior_limit, hev_threshold, size)
; -> eax=edges filtered, rdx=error
er_fn er_vp8_filter_normal_macroblock_horizontal_edge
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 48
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    cmp     r8d, 4
    jb      .ok_zero
    mov     eax, r8d
    add     eax, 3
    cmp     eax, edx
    jae     .ok_zero
    mov     eax, [rsp + 112]
    test    eax, eax
    jz      .invalid_param
    imul    eax, VP8_CHROMA_BLOCK_SIZE
    mov     [rsp + 8], eax
    mov     eax, ecx
    add     eax, [rsp + 8]
    cmp     eax, esi
    ja      .ok_zero
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp], r9d
    mov     eax, [rsp + 96]
    mov     [rsp + 4], eax
    mov     dword [rsp + 12], 0
    mov     dword [rsp + 44], 0
.col_loop:
    mov     eax, [rsp + 12]
    cmp     eax, [rsp + 8]
    jae     .ok
    mov     ecx, ebx
    imul    ecx, r13d
    add     ecx, r15d
    add     ecx, eax
    jmp     .filter_one
.after_filter_one:
    inc     dword [rsp + 12]
    jmp     .col_loop
.filter_one:
    mov     [rsp + 40], ecx
    mov     edx, r13d
    mov     eax, edx
    shl     eax, 2
    mov     esi, ecx
    sub     esi, eax
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 16], eax
    mov     eax, edx
    lea     eax, [rax + rax * 2]
    mov     esi, ecx
    sub     esi, eax
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 20], eax
    mov     eax, edx
    shl     eax, 1
    mov     esi, ecx
    sub     esi, eax
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 24], eax
    mov     esi, ecx
    sub     esi, edx
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 28], eax
    movzx   eax, byte [r12 + rcx]
    mov     [rsp + 32], eax
    mov     esi, ecx
    add     esi, edx
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 36], eax
    mov     edi, [rsp + 28]
    mov     esi, [rsp + 32]
    call    er_vp8_abs_diff_u8
    lea     eax, [rax * 2]
    mov     r10d, eax
    mov     edi, [rsp + 24]
    mov     esi, [rsp + 36]
    call    er_vp8_abs_diff_u8
    shr     eax, 1
    add     r10d, eax
    mov     eax, [rsp]
    shl     eax, 1
    add     eax, [rsp + 4]
    cmp     eax, 255
    jbe     .limit_ready
    mov     eax, 255
.limit_ready:
    cmp     r10d, eax
    ja      .filtered_ret
    mov     edi, [rsp + 16]
    mov     esi, [rsp + 20]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     edi, [rsp + 20]
    mov     esi, [rsp + 24]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     edi, [rsp + 24]
    mov     esi, [rsp + 28]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    mov     edx, r13d
    mov     eax, edx
    shl     eax, 1
    add     eax, ecx
    movzx   edi, byte [r12 + rax]
    mov     esi, [rsp + 36]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     ecx, [rsp + 40]
    mov     edx, r13d
    mov     eax, edx
    shl     eax, 1
    add     eax, ecx
    movzx   esi, byte [r12 + rax]
    add     eax, edx
    movzx   edi, byte [r12 + rax]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     edi, [rsp + 36]
    mov     esi, [rsp + 32]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 4]
    ja      .filtered_ret
    mov     edi, [rsp + 24]
    mov     esi, [rsp + 28]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 104]
    ja      .write_common_outer
    mov     edi, [rsp + 36]
    mov     esi, [rsp + 32]
    call    er_vp8_abs_diff_u8
    cmp     eax, [rsp + 104]
    ja      .write_common_outer
    mov     edi, [rsp + 24]
    sub     edi, [rsp + 36]
    call    er_vp8_saturate_i8
    mov     edi, eax
    mov     eax, [rsp + 32]
    sub     eax, [rsp + 28]
    lea     edi, [rdi + rax * 2]
    add     edi, eax
    call    er_vp8_saturate_i8
    mov     r11d, eax
    mov     eax, r11d
    imul    eax, 27
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 28]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     edx, r13d
    sub     ecx, edx
    mov     [r12 + rcx], al
    mov     eax, r11d
    imul    eax, 27
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 32]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx], al
    mov     eax, r11d
    imul    eax, 18
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 24]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     edx, r13d
    lea     edx, [rdx + rdx]
    sub     ecx, edx
    mov     [r12 + rcx], al
    mov     eax, r11d
    imul    eax, 18
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 36]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    add     ecx, r13d
    mov     [r12 + rcx], al
    mov     eax, r11d
    imul    eax, 9
    add     eax, 63
    sar     eax, 7
    mov     edi, [rsp + 20]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     edx, r13d
    lea     edx, [rdx + rdx * 2]
    sub     ecx, edx
    mov     [r12 + rcx], al
    mov     eax, r11d
    imul    eax, 9
    add     eax, 63
    sar     eax, 7
    mov     ecx, [rsp + 40]
    mov     edx, r13d
    lea     edx, [rdx + rdx]
    add     ecx, edx
    movzx   edi, byte [r12 + rcx]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     [r12 + rcx], al
    inc     dword [rsp + 44]
.filtered_ret:
    jmp     .after_filter_one
.write_common_outer:
    mov     eax, [rsp + 32]
    sub     eax, [rsp + 28]
    lea     edi, [rax + rax * 2]
    mov     eax, [rsp + 24]
    sub     eax, [rsp + 36]
    add     edi, eax
    call    er_vp8_saturate_i8
    mov     r11d, eax
    mov     eax, r11d
    add     eax, 4
    cmp     eax, 127
    jle     .horizontal_common_f1_ready
    mov     eax, 127
.horizontal_common_f1_ready:
    sar     eax, 3
    mov     edi, [rsp + 32]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    mov     [r12 + rcx], al
    mov     eax, r11d
    add     eax, 3
    cmp     eax, 127
    jle     .horizontal_common_f2_ready
    mov     eax, 127
.horizontal_common_f2_ready:
    sar     eax, 3
    mov     edi, [rsp + 28]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 40]
    sub     ecx, r13d
    mov     [r12 + rcx], al
    inc     dword [rsp + 44]
    jmp     .filtered_ret
.ok_zero:
    xor     eax, eax
    er_ok
    jmp     .done_filter_horizontal
.ok:
    mov     eax, [rsp + 44]
    er_ok
    jmp     .done_filter_horizontal
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_filter_horizontal:
    er_stack_free 48
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_filter_simple_vertical_edge(plane, width, height, edge_x, edge_y, filter_limit)
; -> eax=edges filtered, rdx=error
er_fn er_vp8_filter_simple_vertical_edge
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    cmp     ecx, 2
    jb      .ok_zero
    mov     eax, ecx
    inc     eax
    cmp     eax, esi
    jae     .ok_zero
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp], r9d
    mov     dword [rsp + 4], 0
    mov     dword [rsp + 28], 0
.row_loop:
    mov     eax, [rsp + 4]
    cmp     eax, VP8_MACROBLOCK_SIZE
    jae     .ok
    mov     ecx, ebx
    add     ecx, eax
    cmp     ecx, r14d
    jae     .ok
    imul    ecx, r13d
    add     ecx, r15d
    mov     [rsp + 24], ecx
    movzx   edi, byte [r12 + rcx - 1]
    movzx   esi, byte [r12 + rcx]
    call    er_vp8_abs_diff_u8
    lea     eax, [rax * 2]
    mov     r10d, eax
    mov     ecx, [rsp + 24]
    movzx   edi, byte [r12 + rcx - 2]
    movzx   esi, byte [r12 + rcx + 1]
    call    er_vp8_abs_diff_u8
    shr     eax, 1
    add     r10d, eax
    cmp     r10d, [rsp]
    ja      .next_row
    mov     ecx, [rsp + 24]
    movzx   eax, byte [r12 + rcx - 1]
    mov     [rsp + 8], eax
    movzx   eax, byte [r12 + rcx]
    mov     [rsp + 12], eax
    movzx   eax, byte [r12 + rcx - 2]
    mov     [rsp + 16], eax
    movzx   eax, byte [r12 + rcx + 1]
    mov     [rsp + 20], eax
    mov     eax, [rsp + 12]
    sub     eax, [rsp + 8]
    lea     edi, [rax + rax * 2]
    mov     eax, [rsp + 16]
    sub     eax, [rsp + 20]
    add     edi, eax
    call    er_vp8_saturate_i8
    mov     r11d, eax
    mov     eax, r11d
    add     eax, 4
    cmp     eax, 127
    jle     .f1_ready
    mov     eax, 127
.f1_ready:
    sar     eax, 3
    mov     edi, [rsp + 12]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 24]
    mov     [r12 + rcx], al
    mov     eax, r11d
    add     eax, 3
    cmp     eax, 127
    jle     .f2_ready
    mov     eax, 127
.f2_ready:
    sar     eax, 3
    mov     edi, [rsp + 8]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 24]
    mov     [r12 + rcx - 1], al
    inc     dword [rsp + 28]
.next_row:
    inc     dword [rsp + 4]
    jmp     .row_loop
.ok_zero:
    xor     eax, eax
    er_ok
    jmp     .done_simple_vertical
.ok:
    mov     eax, [rsp + 28]
    er_ok
    jmp     .done_simple_vertical
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_simple_vertical:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_filter_simple_horizontal_edge(plane, width, height, edge_x, edge_y, filter_limit)
; -> eax=edges filtered, rdx=error
er_fn er_vp8_filter_simple_horizontal_edge
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    test    rdi, rdi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    cmp     r8d, 2
    jb      .ok_zero
    mov     eax, r8d
    inc     eax
    cmp     eax, edx
    jae     .ok_zero
    mov     eax, ecx
    add     eax, VP8_MACROBLOCK_SIZE
    cmp     eax, esi
    ja      .ok_zero
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp], r9d
    mov     dword [rsp + 4], 0
    mov     dword [rsp + 28], 0
.col_loop:
    mov     eax, [rsp + 4]
    cmp     eax, VP8_MACROBLOCK_SIZE
    jae     .ok
    mov     ecx, ebx
    imul    ecx, r13d
    add     ecx, r15d
    add     ecx, eax
    mov     [rsp + 24], ecx
    mov     edx, r13d
    mov     esi, ecx
    sub     esi, edx
    movzx   edi, byte [r12 + rsi]
    movzx   esi, byte [r12 + rcx]
    call    er_vp8_abs_diff_u8
    lea     eax, [rax * 2]
    mov     r10d, eax
    mov     ecx, [rsp + 24]
    mov     edx, r13d
    mov     eax, edx
    shl     eax, 1
    mov     esi, ecx
    sub     esi, eax
    movzx   edi, byte [r12 + rsi]
    mov     esi, ecx
    add     esi, edx
    movzx   esi, byte [r12 + rsi]
    call    er_vp8_abs_diff_u8
    shr     eax, 1
    add     r10d, eax
    cmp     r10d, [rsp]
    ja      .next_col
    mov     ecx, [rsp + 24]
    mov     edx, r13d
    mov     esi, ecx
    sub     esi, edx
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 8], eax
    movzx   eax, byte [r12 + rcx]
    mov     [rsp + 12], eax
    mov     eax, edx
    shl     eax, 1
    mov     esi, ecx
    sub     esi, eax
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 16], eax
    mov     esi, ecx
    add     esi, edx
    movzx   eax, byte [r12 + rsi]
    mov     [rsp + 20], eax
    mov     eax, [rsp + 12]
    sub     eax, [rsp + 8]
    lea     edi, [rax + rax * 2]
    mov     eax, [rsp + 16]
    sub     eax, [rsp + 20]
    add     edi, eax
    call    er_vp8_saturate_i8
    mov     r11d, eax
    mov     eax, r11d
    add     eax, 4
    cmp     eax, 127
    jle     .h_f1_ready
    mov     eax, 127
.h_f1_ready:
    sar     eax, 3
    mov     edi, [rsp + 12]
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 24]
    mov     [r12 + rcx], al
    mov     eax, r11d
    add     eax, 3
    cmp     eax, 127
    jle     .h_f2_ready
    mov     eax, 127
.h_f2_ready:
    sar     eax, 3
    mov     edi, [rsp + 8]
    add     edi, eax
    call    er_vp8_clamp_u8
    mov     ecx, [rsp + 24]
    sub     ecx, r13d
    mov     [r12 + rcx], al
    inc     dword [rsp + 28]
.next_col:
    inc     dword [rsp + 4]
    jmp     .col_loop
.ok_zero:
    xor     eax, eax
    er_ok
    jmp     .done_simple_horizontal
.ok:
    mov     eax, [rsp + 28]
    er_ok
    jmp     .done_simple_horizontal
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_simple_horizontal:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_coeff_band(index) -> eax=band, rdx=error
; edi=coefficient scan index 0..16.
er_fn er_vp8_coeff_band
    cmp     edi, VP8_COEFF_BAND_ENTRIES - 1
    ja      .invalid_param
    lea     rax, [rel vp8_coeff_bands]
    movzx   eax, byte [rax + rdi]
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_zigzag(index) -> eax=zigzag coefficient index, rdx=error
; edi=coefficient index 0..15.
er_fn er_vp8_zigzag
    cmp     edi, VP8_COEFF_BLOCK_COEFF_COUNT - 1
    ja      .invalid_param
    lea     rax, [rel vp8_zigzag]
    movzx   eax, byte [rax + rdi]
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_coeff_probability_offset(block_type, band, context, probability_index)
; -> eax=linear probability offset, rdx=error
; edi=block_type, esi=band, edx=context, ecx=probability_index.
er_fn er_vp8_coeff_probability_offset
    cmp     edi, VP8_COEFF_TYPE_COUNT
    jae     .invalid_param
    cmp     esi, VP8_COEFF_BAND_COUNT
    jae     .invalid_param
    cmp     edx, VP8_COEFF_CONTEXT_COUNT
    jae     .invalid_param
    cmp     ecx, VP8_COEFF_PROBABILITY_COUNT
    jae     .invalid_param
    mov     eax, edi
    imul    eax, VP8_COEFF_BAND_COUNT
    add     eax, esi
    imul    eax, VP8_COEFF_CONTEXT_COUNT
    add     eax, edx
    imul    eax, VP8_COEFF_PROBABILITY_COUNT
    add     eax, ecx
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_coeff_probability_from(probabilities, block_type, band, context, probability_index)
; -> eax=probability, rdx=error
; rdi=probabilities[1056], esi=block_type, edx=band, ecx=context, r8d=probability_index.
er_fn er_vp8_coeff_probability_from
    er_push rbx
    test    rdi, rdi
    jz      .invalid_param
    mov     rbx, rdi
    mov     edi, esi
    mov     esi, edx
    mov     edx, ecx
    mov     ecx, r8d
    call    er_vp8_coeff_probability_offset
    test    edx, edx
    jnz     .done_probability_from
    movzx   eax, byte [rbx + rax]
    er_ok
    jmp     .done_probability_from
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_probability_from:
    er_pop  rbx
    er_ret

; er_vp8_coeff_default_probability(block_type, band, context, probability_index)
; -> eax=default token probability, rdx=error
; edi=block_type, esi=band, edx=context, ecx=probability_index.
er_fn er_vp8_coeff_default_probability
    call    er_vp8_coeff_probability_offset
    test    edx, edx
    jnz     .done_default_prob
    lea     r8, [rel vp8_coeff_default_probabilities]
    movzx   eax, byte [r8 + rax]
    er_ok
.done_default_prob:
    er_ret

; er_vp8_copy_default_coeff_probabilities(out) -> eax=1056, rdx=error
; rdi=out[1056].
er_fn er_vp8_copy_default_coeff_probabilities
    test    rdi, rdi
    jz      .invalid_param
    lea     rsi, [rel vp8_coeff_default_probabilities]
    xor     ecx, ecx
.copy_loop:
    cmp     ecx, VP8_COEFF_UPDATE_PROBABILITY_COUNT
    jae     .ok
    movzx   eax, byte [rsi + rcx]
    mov     [rdi + rcx], al
    inc     ecx
    jmp     .copy_loop
.ok:
    mov     eax, VP8_COEFF_UPDATE_PROBABILITY_COUNT
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_read_large_coeff_value(reader, probabilities, block_type, band, context)
; -> eax=magnitude >= 2, rdx=error
; rdi=reader, rsi=probabilities[1056], edx=block_type, ecx=band, r8d=context.
er_fn er_vp8_read_large_coeff_value
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, VP8_COEFF_TYPE_COUNT
    jae     .invalid_param
    cmp     ecx, VP8_COEFF_BAND_COUNT
    jae     .invalid_param
    cmp     r8d, VP8_COEFF_CONTEXT_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_0
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    test    eax, eax
    jnz     .large_3
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_1
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    test    eax, eax
    jnz     .value_3_or_4
    mov     eax, VP8_COEFF_MIN_LARGE_VALUE
    er_ok
    jmp     .done_large
.value_3_or_4:
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_2
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    add     eax, 3
    er_ok
    jmp     .done_large
.large_3:
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_3
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    test    eax, eax
    jnz     .category
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_4
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    test    eax, eax
    jnz     .value_7_to_10
    mov     rdi, r12
    mov     esi, VP8_COEFF_CAT_EXTRA_PROBABILITY_0
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_large
    add     eax, 5
    er_ok
    jmp     .done_large
.value_7_to_10:
    mov     rdi, r12
    mov     esi, VP8_COEFF_CAT_EXTRA_PROBABILITY_1
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_large
    lea     eax, [rax * 2 + 7]
    mov     ebx, eax
    mov     rdi, r12
    mov     esi, VP8_COEFF_CAT_EXTRA_PROBABILITY_2
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_large
    add     eax, ebx
    er_ok
    jmp     .done_large
.category:
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_5
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    mov     ebx, eax
    mov     r8d, VP8_COEFF_LARGE_PROBABILITY_6
    add     r8d, ebx
    call    .read_table_bool
    test    edx, edx
    jnz     .done_large
    lea     esi, [rbx * 2 + rax]
    mov     rdi, r12
    call    er_vp8_read_category_coeff_value
    jmp     .done_large
.read_table_bool:
    mov     rdi, r13
    mov     esi, r14d
    mov     edx, r15d
    mov     ecx, ebx
    call    er_vp8_coeff_probability_from
    test    edx, edx
    jnz     .read_table_done
    mov     rdi, r12
    mov     esi, eax
    call    er_vp8_bool_read
.read_table_done:
    ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_large:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_read_coeff_block(reader, probabilities, block_type, start_index, context, out)
; -> eax=next scan index, r8d=nonzero flag, rdx=error
; rdi=reader, rsi=probabilities[1056], edx=block_type, ecx=start_index, r8d=context, r9=out[16] i16.
er_fn er_vp8_read_coeff_block
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    cmp     edx, VP8_COEFF_TYPE_COUNT
    jae     .invalid_param
    cmp     ecx, VP8_COEFF_BAND_ENTRIES - 1
    jae     .invalid_param
    cmp     r8d, VP8_COEFF_CONTEXT_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, r9
    mov     r15d, ecx
    mov     ebx, r8d
    mov     [rsp], edx
    mov     dword [rsp + 4], 0
    xor     ecx, ecx
.clear_loop:
    cmp     ecx, VP8_COEFF_BLOCK_COEFF_COUNT
    jae     .scan_loop
    mov     word [r14 + rcx * 2], 0
    inc     ecx
    jmp     .clear_loop
.scan_loop:
    cmp     r15d, VP8_COEFF_BAND_ENTRIES - 1
    jae     .ok
    mov     r8d, VP8_COEFF_EOB_PROBABILITY_INDEX
    call    .read_block_bool
    test    edx, edx
    jnz     .done_block
    test    eax, eax
    jz      .ok
.zero_loop:
    mov     r8d, VP8_COEFF_ZERO_PROBABILITY_INDEX
    call    .read_block_bool
    test    edx, edx
    jnz     .done_block
    test    eax, eax
    jnz     .non_zero_token
    inc     r15d
    xor     ebx, ebx
    cmp     r15d, VP8_COEFF_BAND_ENTRIES - 1
    jae     .ok
    jmp     .zero_loop
.non_zero_token:
    mov     r8d, VP8_COEFF_ONE_PROBABILITY_INDEX
    call    .read_block_bool
    test    edx, edx
    jnz     .done_block
    test    eax, eax
    jnz     .large_coeff
    mov     eax, 1
    jmp     .magnitude_ready
.large_coeff:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, [rsp]
    mov     ecx, r15d
    push    rbx
    mov     edi, ecx
    call    er_vp8_coeff_band
    mov     ecx, eax
    pop     rbx
    test    edx, edx
    jnz     .done_block
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, [rsp]
    mov     r8d, ebx
    call    er_vp8_read_large_coeff_value
    test    edx, edx
    jnz     .done_block
.magnitude_ready:
    mov     [rsp + 8], eax
    mov     rdi, r12
    mov     esi, eax
    call    er_vp8_read_signed_coeff
    test    edx, edx
    jnz     .done_block
    mov     [rsp + 12], eax
    mov     edi, r15d
    call    er_vp8_zigzag
    test    edx, edx
    jnz     .done_block
    mov     ecx, [rsp + 12]
    mov     [r14 + rax * 2], cx
    mov     dword [rsp + 4], 1
    mov     eax, [rsp + 8]
    cmp     eax, 1
    jne     .context_large
    mov     ebx, 1
    jmp     .advance
.context_large:
    mov     ebx, 2
.advance:
    inc     r15d
    jmp     .scan_loop
.read_block_bool:
    mov     [rsp + 16], r8d
    mov     edi, r15d
    call    er_vp8_coeff_band
    test    edx, edx
    jnz     .read_block_done
    mov     rdi, r13
    mov     esi, [rsp + 8]
    mov     edx, eax
    mov     ecx, ebx
    mov     r8d, [rsp + 16]
    call    er_vp8_coeff_probability_from
    test    edx, edx
    jnz     .read_block_done
    mov     rdi, r12
    mov     esi, eax
    call    er_vp8_bool_read
.read_block_done:
    ret
.ok:
    mov     eax, r15d
    mov     r8d, [rsp + 4]
    er_ok
    jmp     .done_block
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_block:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_read_residual_macroblock_single(reader, probabilities, has_y2, coeffs)
; -> eax=nonzero block count, rdx=error
; Single-macroblock residual reader with local top/left contexts initialized empty.
; rdi=reader, rsi=probabilities[1056], edx=has_y2, rcx=coeffs[25][16] i16.
er_fn er_vp8_read_residual_macroblock_single
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rcx
    mov     r15d, edx
    mov     dword [rsp], 0
    mov     qword [rsp + 4], 0
    mov     qword [rsp + 12], 0
    mov     qword [rsp + 20], 0
    test    r15d, r15d
    jz      .y_blocks
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, 1
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [r14 + VP8_Y2_BLOCK_INDEX * VP8_COEFF_BLOCK_BYTES]
    call    er_vp8_read_coeff_block
    test    edx, edx
    jnz     .done_residual_single
    test    r8d, r8d
    jz      .y_blocks
    inc     dword [rsp]
.y_blocks:
    xor     ebx, ebx
.y_loop:
    cmp     ebx, VP8_Y_BLOCK_COUNT
    jae     .u_blocks
    mov     eax, ebx
    and     eax, 3
    mov     ecx, ebx
    shr     ecx, 2
    xor     r8d, r8d
    test    eax, eax
    jz      .y_no_left
    movzx   r8d, byte [rsp + 4 + rcx]
.y_no_left:
    movzx   edx, byte [rsp + 8 + rax]
    add     r8d, edx
    mov     edx, 3
    xor     ecx, ecx
    test    r15d, r15d
    jz      .y_call
    xor     edx, edx
    mov     ecx, 1
.y_call:
    mov     rdi, r12
    mov     rsi, r13
    mov     r9, rbx
    imul    r9, VP8_COEFF_BLOCK_BYTES
    add     r9, r14
    call    er_vp8_read_coeff_block
    test    edx, edx
    jnz     .done_residual_single
    mov     eax, ebx
    and     eax, 3
    mov     ecx, ebx
    shr     ecx, 2
    mov     [rsp + 4 + rcx], r8b
    mov     [rsp + 8 + rax], r8b
    test    r8d, r8d
    jz      .next_y
    inc     dword [rsp]
.next_y:
    inc     ebx
    jmp     .y_loop
.u_blocks:
    xor     ebx, ebx
.u_loop:
    cmp     ebx, VP8_UV_BLOCK_COUNT
    jae     .v_blocks
    mov     eax, ebx
    and     eax, 1
    mov     ecx, ebx
    shr     ecx, 1
    xor     r8d, r8d
    test    eax, eax
    jz      .u_no_left
    movzx   r8d, byte [rsp + 12 + rcx]
.u_no_left:
    movzx   edx, byte [rsp + 14 + rax]
    add     r8d, edx
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, 2
    xor     ecx, ecx
    mov     r9, rbx
    add     r9, VP8_Y_BLOCK_COUNT
    imul    r9, VP8_COEFF_BLOCK_BYTES
    add     r9, r14
    call    er_vp8_read_coeff_block
    test    edx, edx
    jnz     .done_residual_single
    mov     eax, ebx
    and     eax, 1
    mov     ecx, ebx
    shr     ecx, 1
    mov     [rsp + 12 + rcx], r8b
    mov     [rsp + 14 + rax], r8b
    test    r8d, r8d
    jz      .next_u
    inc     dword [rsp]
.next_u:
    inc     ebx
    jmp     .u_loop
.v_blocks:
    xor     ebx, ebx
.v_loop:
    cmp     ebx, VP8_UV_BLOCK_COUNT
    jae     .ok
    mov     eax, ebx
    and     eax, 1
    mov     ecx, ebx
    shr     ecx, 1
    xor     r8d, r8d
    test    eax, eax
    jz      .v_no_left
    movzx   r8d, byte [rsp + 16 + rcx]
.v_no_left:
    movzx   edx, byte [rsp + 18 + rax]
    add     r8d, edx
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, 2
    xor     ecx, ecx
    mov     r9, rbx
    add     r9, VP8_Y_BLOCK_COUNT + VP8_UV_BLOCK_COUNT
    imul    r9, VP8_COEFF_BLOCK_BYTES
    add     r9, r14
    call    er_vp8_read_coeff_block
    test    edx, edx
    jnz     .done_residual_single
    mov     eax, ebx
    and     eax, 1
    mov     ecx, ebx
    shr     ecx, 1
    mov     [rsp + 16 + rcx], r8b
    mov     [rsp + 18 + rax], r8b
    test    r8d, r8d
    jz      .next_v
    inc     dword [rsp]
.next_v:
    inc     ebx
    jmp     .v_loop
.ok:
    mov     eax, [rsp]
    er_ok
    jmp     .done_residual_single
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_residual_single:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_init_default_edges(edges, size) -> eax=edges bytes initialized, rdx=error
; size must be 8 or 16. Top samples default to 127, left samples to 129,
; top-left defaults to 127, and has_top/has_left are cleared.
er_fn er_vp8_init_default_edges
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_CHROMA_BLOCK_SIZE
    je      .size_ok
    cmp     esi, VP8_MACROBLOCK_SIZE
    jne     .invalid_param
.size_ok:
    mov     r12, rdi
    mov     ebx, esi
    xor     ecx, ecx
.top_loop:
    cmp     ecx, ebx
    jae     .left_start
    mov     byte [r12 + rcx], VP8_PLANE_EDGE_DEFAULT
    inc     ecx
    jmp     .top_loop
.left_start:
    xor     ecx, ecx
.left_loop:
    cmp     ecx, ebx
    jae     .top_right_start
    mov     eax, ebx
    add     eax, ecx
    mov     byte [r12 + rax], VP8_PLANE_LEFT_DEFAULT
    inc     ecx
    jmp     .left_loop
.top_right_start:
    mov     eax, ebx
    shl     eax, 1
    mov     byte [r12 + rax], VP8_PLANE_EDGE_DEFAULT
    mov     byte [r12 + rax + 1], 0
    mov     byte [r12 + rax + 2], 0
    cmp     ebx, VP8_MACROBLOCK_SIZE
    jne     .ok_8
    xor     ecx, ecx
.top_right_loop_16:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok_16
    mov     byte [r12 + VP8_EDGES_TOP_RIGHT_16 + rcx], VP8_PLANE_EDGE_DEFAULT
    inc     ecx
    jmp     .top_right_loop_16
.ok_16:
    mov     eax, VP8_EDGES_SIZE_16
    er_ok
    jmp     .done_init_edges
.ok_8:
    mov     eax, VP8_EDGES_SIZE_8
    er_ok
    jmp     .done_init_edges
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_init_edges:
    er_pop  rbx, r12
    er_ret

; er_vp8_make_luma_edges(edges, top_y, left_y, mb_x, mb_y, mb_w)
er_fn er_vp8_make_luma_edges
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 8
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r9d, r9d
    jz      .invalid_param
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14d, ecx
    mov     r15d, r8d
    mov     [rsp], r9d
    mov     esi, VP8_MACROBLOCK_SIZE
    call    er_vp8_init_default_edges
    test    edx, edx
    jnz     .done_luma_edges
    mov     eax, r14d
    shl     eax, 4
    test    r15d, r15d
    jz      .left_luma
    lea     rdi, [rbx + VP8_EDGES_TOP]
    lea     rsi, [r12 + rax]
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_memcpy
    mov     byte [rbx + VP8_EDGES_HAS_TOP_16], 1
    mov     ecx, r14d
    inc     ecx
    cmp     ecx, [rsp]
    jae     .repeat_top_right_luma
    mov     eax, r14d
    shl     eax, 4
    lea     rdi, [rbx + VP8_EDGES_TOP_RIGHT_16]
    lea     rsi, [r12 + rax + VP8_MACROBLOCK_SIZE]
    mov     edx, VP8_BLOCK_SIZE
    call    er_vp8_memcpy
    jmp     .left_luma
.repeat_top_right_luma:
    movzx   esi, byte [rbx + VP8_EDGES_TOP + VP8_MACROBLOCK_SIZE - 1]
    lea     rdi, [rbx + VP8_EDGES_TOP_RIGHT_16]
    mov     edx, VP8_BLOCK_SIZE
    call    er_vp8_memset
.left_luma:
    test    r14d, r14d
    jz      .ok_luma_edges
    lea     rdi, [rbx + VP8_EDGES_LEFT_16]
    mov     rsi, r13
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_memcpy
    mov     byte [rbx + VP8_EDGES_HAS_LEFT_16], 1
    test    r15d, r15d
    jz      .ok_luma_edges
    mov     eax, r14d
    shl     eax, 4
    movzx   ecx, byte [r12 + rax - 1]
    mov     [rbx + VP8_EDGES_TOP_LEFT_16], cl
.ok_luma_edges:
    mov     eax, VP8_EDGES_SIZE_16
    er_ok
    jmp     .done_luma_edges
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_luma_edges:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_make_chroma_edges(edges, top, left, mb_x, mb_y)
er_fn er_vp8_make_chroma_edges
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14d, ecx
    mov     r15d, r8d
    mov     esi, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_init_default_edges
    test    edx, edx
    jnz     .done_chroma_edges
    mov     eax, r14d
    shl     eax, 3
    test    r15d, r15d
    jz      .left_chroma
    lea     rdi, [rbx + VP8_EDGES_TOP]
    lea     rsi, [r12 + rax]
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_memcpy
    mov     byte [rbx + VP8_EDGES_HAS_TOP_8], 1
.left_chroma:
    test    r14d, r14d
    jz      .ok_chroma_edges
    lea     rdi, [rbx + VP8_EDGES_LEFT_8]
    mov     rsi, r13
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_memcpy
    mov     byte [rbx + VP8_EDGES_HAS_LEFT_8], 1
    test    r15d, r15d
    jz      .ok_chroma_edges
    mov     eax, r14d
    shl     eax, 3
    movzx   ecx, byte [r12 + rax - 1]
    mov     [rbx + VP8_EDGES_TOP_LEFT_8], cl
.ok_chroma_edges:
    mov     eax, VP8_EDGES_SIZE_8
    er_ok
    jmp     .done_chroma_edges
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_chroma_edges:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_finish_prediction_state(top_y, top_u, top_v, left_y, left_u, left_v, mb_x, y_plane, u_plane, v_plane)
er_fn er_vp8_finish_prediction_state
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     r11, r9
    mov     eax, [rsp + 48]
    mov     r10, [rsp + 56]
    test    r10, r10
    jz      .invalid_param
    mov     rcx, [rsp + 64]
    test    rcx, rcx
    jz      .invalid_param
    mov     rdx, [rsp + 72]
    test    rdx, rdx
    jz      .invalid_param
    mov     esi, eax
    shl     esi, 4
    lea     rdi, [rbx + rsi]
    lea     rsi, [r10 + (VP8_MACROBLOCK_SIZE - 1) * VP8_MACROBLOCK_SIZE]
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_memcpy
    xor     ecx, ecx
.copy_left_y:
    cmp     ecx, VP8_MACROBLOCK_SIZE
    jae     .copy_top_u
    mov     edx, ecx
    shl     edx, 4
    movzx   esi, byte [r10 + rdx + VP8_MACROBLOCK_SIZE - 1]
    mov     [r14 + rcx], sil
    inc     ecx
    jmp     .copy_left_y
.copy_top_u:
    mov     eax, [rsp + 48]
    mov     esi, eax
    shl     esi, 3
    mov     rcx, [rsp + 64]
    lea     rdi, [r12 + rsi]
    lea     rsi, [rcx + (VP8_CHROMA_BLOCK_SIZE - 1) * VP8_CHROMA_BLOCK_SIZE]
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_memcpy
    mov     eax, [rsp + 48]
    mov     esi, eax
    shl     esi, 3
    mov     rdx, [rsp + 72]
    lea     rdi, [r13 + rsi]
    lea     rsi, [rdx + (VP8_CHROMA_BLOCK_SIZE - 1) * VP8_CHROMA_BLOCK_SIZE]
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_memcpy
    mov     rcx, [rsp + 64]
    mov     rdx, [rsp + 72]
    xor     eax, eax
.copy_left_uv:
    cmp     eax, VP8_CHROMA_BLOCK_SIZE
    jae     .ok_finish
    mov     esi, eax
    shl     esi, 3
    movzx   edi, byte [rcx + rsi + VP8_CHROMA_BLOCK_SIZE - 1]
    mov     [r15 + rax], dil
    movzx   edi, byte [rdx + rsi + VP8_CHROMA_BLOCK_SIZE - 1]
    mov     [r11 + rax], dil
    inc     eax
    jmp     .copy_left_uv
.ok_finish:
    mov     eax, VP8_MACROBLOCK_SIZE
    er_ok
    jmp     .done_finish
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_finish:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_dequantize_y2_block(coeffs, dequant, out) -> eax=64, rdx=error
; coeffs[16] i16, dequant=VP8_DEQUANT_SIZE, out[16] i32.
er_fn er_vp8_dequantize_y2_block
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    movsx   eax, word [rdi]
    movsx   ecx, word [rsi + VP8_DEQUANT_Y2_DC]
    imul    eax, ecx
    mov     [rdx], eax
    movsx   r8d, word [rsi + VP8_DEQUANT_Y2_AC]
    mov     ecx, 1
.loop:
    cmp     ecx, VP8_COEFF_BLOCK_COEFF_COUNT
    jae     .ok
    movsx   eax, word [rdi + rcx * 2]
    imul    eax, r8d
    mov     [rdx + rcx * 4], eax
    inc     ecx
    jmp     .loop
.ok:
    mov     eax, VP8_DEQUANT_BLOCK_BYTES
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_dequantize_y_block_with_own_dc(coeffs, dequant, out) -> eax=64, rdx=error
er_fn er_vp8_dequantize_y_block_with_own_dc
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    movsx   eax, word [rdi]
    movsx   ecx, word [rsi + VP8_DEQUANT_Y_DC]
    imul    eax, ecx
    mov     [rdx], eax
    movsx   r8d, word [rsi + VP8_DEQUANT_Y_AC]
    mov     ecx, 1
.loop:
    cmp     ecx, VP8_COEFF_BLOCK_COEFF_COUNT
    jae     .ok
    movsx   eax, word [rdi + rcx * 2]
    imul    eax, r8d
    mov     [rdx + rcx * 4], eax
    inc     ecx
    jmp     .loop
.ok:
    mov     eax, VP8_DEQUANT_BLOCK_BYTES
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_dequantize_y_block_with_y2_dc(coeffs, dequant, y2_dc, out) -> eax=64, rdx=error
; rdi=coeffs, rsi=dequant, edx=y2_dc, rcx=out.
er_fn er_vp8_dequantize_y_block_with_y2_dc
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     [rcx], edx
    movsx   r8d, word [rsi + VP8_DEQUANT_Y_AC]
    mov     edx, 1
.loop:
    cmp     edx, VP8_COEFF_BLOCK_COEFF_COUNT
    jae     .ok
    movsx   eax, word [rdi + rdx * 2]
    imul    eax, r8d
    mov     [rcx + rdx * 4], eax
    inc     edx
    jmp     .loop
.ok:
    mov     eax, VP8_DEQUANT_BLOCK_BYTES
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_dequantize_uv_block(coeffs, dequant, out) -> eax=64, rdx=error
er_fn er_vp8_dequantize_uv_block
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    movsx   eax, word [rdi]
    movsx   ecx, word [rsi + VP8_DEQUANT_UV_DC]
    imul    eax, ecx
    mov     [rdx], eax
    movsx   r8d, word [rsi + VP8_DEQUANT_UV_AC]
    mov     ecx, 1
.loop:
    cmp     ecx, VP8_COEFF_BLOCK_COEFF_COUNT
    jae     .ok
    movsx   eax, word [rdi + rcx * 2]
    imul    eax, r8d
    mov     [rdx + rcx * 4], eax
    inc     ecx
    jmp     .loop
.ok:
    mov     eax, VP8_DEQUANT_BLOCK_BYTES
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_inverse_wht(input, out) -> eax=64, rdx=error
; input[16] i32, out[16] i32.
er_fn er_vp8_inverse_wht
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DEQUANT_BLOCK_BYTES
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     r14d, r14d
.column_loop:
    cmp     r14d, 4
    jae     .row_start
    mov     eax, [r12 + r14 * 4]
    mov     ebx, [r12 + r14 * 4 + 48]
    lea     r8d, [eax + ebx]
    sub     eax, ebx
    mov     r9d, eax
    mov     eax, [r12 + r14 * 4 + 16]
    mov     ebx, [r12 + r14 * 4 + 32]
    lea     r10d, [eax + ebx]
    sub     eax, ebx
    mov     r11d, eax
    mov     eax, r8d
    add     eax, r10d
    mov     [rsp + r14 * 4], eax
    mov     eax, r11d
    add     eax, r9d
    mov     [rsp + r14 * 4 + 16], eax
    mov     eax, r8d
    sub     eax, r10d
    mov     [rsp + r14 * 4 + 32], eax
    mov     eax, r9d
    sub     eax, r11d
    mov     [rsp + r14 * 4 + 48], eax
    inc     r14d
    jmp     .column_loop
.row_start:
    xor     r14d, r14d
.row_loop:
    cmp     r14d, 4
    jae     .ok
    mov     r15d, r14d
    shl     r15d, 4
    mov     eax, [rsp + r15]
    mov     ebx, [rsp + r15 + 12]
    lea     r8d, [eax + ebx]
    sub     eax, ebx
    mov     r9d, eax
    mov     eax, [rsp + r15 + 4]
    mov     ebx, [rsp + r15 + 8]
    lea     r10d, [eax + ebx]
    sub     eax, ebx
    mov     r11d, eax
    mov     eax, r8d
    add     eax, r10d
    add     eax, VP8_WHT_ROUND
    sar     eax, VP8_WHT_SHIFT
    mov     [r13 + r15], eax
    mov     eax, r11d
    add     eax, r9d
    add     eax, VP8_WHT_ROUND
    sar     eax, VP8_WHT_SHIFT
    mov     [r13 + r15 + 4], eax
    mov     eax, r8d
    sub     eax, r10d
    add     eax, VP8_WHT_ROUND
    sar     eax, VP8_WHT_SHIFT
    mov     [r13 + r15 + 8], eax
    mov     eax, r9d
    sub     eax, r11d
    add     eax, VP8_WHT_ROUND
    sar     eax, VP8_WHT_SHIFT
    mov     [r13 + r15 + 12], eax
    inc     r14d
    jmp     .row_loop
.ok:
    mov     eax, VP8_DEQUANT_BLOCK_BYTES
    er_ok
    jmp     .done_wht
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_wht:
    er_stack_free VP8_DEQUANT_BLOCK_BYTES
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_idct_mul_shift(value, factor) -> eax=(value * factor) >> 16, rdx=error
; edi=value i32, esi=factor i32.
er_fn er_vp8_idct_mul_shift
    movsxd  rax, edi
    movsxd  rcx, esi
    imul    rax, rcx
    sar     rax, 16
    er_ok
    er_ret

; er_vp8_inverse_idct(input, out) -> eax=64, rdx=error
; input[16] i32, out[16] i32 residual deltas.
er_fn er_vp8_inverse_idct
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 96
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     r14d, r14d
.column_loop:
    cmp     r14d, 4
    jae     .row_start
    mov     eax, [r12 + r14 * 4]
    mov     ebx, [r12 + r14 * 4 + 32]
    lea     r8d, [eax + ebx]
    sub     eax, ebx
    mov     r9d, eax
    mov     edi, [r12 + r14 * 4 + 16]
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    mov     [rsp + 64], eax
    mov     edi, [r12 + r14 * 4 + 48]
    mov     esi, VP8_IDCT_COSPI8SQRT2MINUS1
    call    er_vp8_idct_mul_shift
    add     eax, [r12 + r14 * 4 + 48]
    mov     ecx, [rsp + 64]
    sub     ecx, eax
    mov     [rsp + 68], ecx
    mov     eax, [r12 + r14 * 4 + 16]
    mov     [rsp + 72], eax
    mov     edi, eax
    mov     esi, VP8_IDCT_COSPI8SQRT2MINUS1
    call    er_vp8_idct_mul_shift
    add     eax, [rsp + 72]
    mov     [rsp + 76], eax
    mov     edi, [r12 + r14 * 4 + 48]
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    add     eax, [rsp + 76]
    mov     r10d, eax
    mov     ecx, r8d
    add     ecx, r10d
    mov     [rsp + r14 * 4], ecx
    mov     ecx, r8d
    sub     ecx, r10d
    mov     [rsp + r14 * 4 + 48], ecx
    mov     ecx, r9d
    add     ecx, [rsp + 68]
    mov     [rsp + r14 * 4 + 16], ecx
    mov     ecx, r9d
    sub     ecx, [rsp + 68]
    mov     [rsp + r14 * 4 + 32], ecx
    inc     r14d
    jmp     .column_loop
.row_start:
    xor     r14d, r14d
.row_loop:
    cmp     r14d, 4
    jae     .ok
    mov     r15d, r14d
    shl     r15d, 4
    mov     eax, [rsp + r15]
    mov     ebx, [rsp + r15 + 8]
    lea     r8d, [eax + ebx]
    sub     eax, ebx
    mov     r9d, eax
    mov     edi, [rsp + r15 + 4]
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    mov     [rsp + 64], eax
    mov     edi, [rsp + r15 + 12]
    mov     esi, VP8_IDCT_COSPI8SQRT2MINUS1
    call    er_vp8_idct_mul_shift
    add     eax, [rsp + r15 + 12]
    mov     ecx, [rsp + 64]
    sub     ecx, eax
    mov     [rsp + 68], ecx
    mov     eax, [rsp + r15 + 4]
    mov     [rsp + 72], eax
    mov     edi, eax
    mov     esi, VP8_IDCT_COSPI8SQRT2MINUS1
    call    er_vp8_idct_mul_shift
    add     eax, [rsp + 72]
    mov     [rsp + 76], eax
    mov     edi, [rsp + r15 + 12]
    mov     esi, VP8_IDCT_SINPI8SQRT2
    call    er_vp8_idct_mul_shift
    add     eax, [rsp + 76]
    mov     r10d, eax
    mov     eax, r8d
    add     eax, r10d
    add     eax, VP8_IDCT_ROUND
    sar     eax, VP8_IDCT_SHIFT
    mov     [r13 + r15], eax
    mov     eax, r8d
    sub     eax, r10d
    add     eax, VP8_IDCT_ROUND
    sar     eax, VP8_IDCT_SHIFT
    mov     [r13 + r15 + 12], eax
    mov     eax, r9d
    add     eax, [rsp + 68]
    add     eax, VP8_IDCT_ROUND
    sar     eax, VP8_IDCT_SHIFT
    mov     [r13 + r15 + 4], eax
    mov     eax, r9d
    sub     eax, [rsp + 68]
    add     eax, VP8_IDCT_ROUND
    sar     eax, VP8_IDCT_SHIFT
    mov     [r13 + r15 + 8], eax
    inc     r14d
    jmp     .row_loop
.ok:
    mov     eax, VP8_DEQUANT_BLOCK_BYTES
    er_ok
    jmp     .done_idct
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_idct:
    er_stack_free 96
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_clamp_u8(value) -> eax=clamped 0..255, rdx=error
; edi=signed value.
er_fn er_vp8_clamp_u8
    test    edi, edi
    js      .zero
    cmp     edi, 255
    ja      .max
    mov     eax, edi
    er_ok
    er_ret
.zero:
    xor     eax, eax
    er_ok
    er_ret
.max:
    mov     eax, 255
    er_ok
    er_ret

; er_vp8_yuv_to_rgba(y, u, v) -> eax=packed RGBA bytes, rdx=error
; dil=y, sil=u, dl=v.
er_fn er_vp8_yuv_to_rgba
    er_push rbx, r12, r13
    movzx   r12d, dil
    movzx   ebx, sil
    sub     ebx, VP8_YUV_CENTER
    movzx   r13d, dl
    sub     r13d, VP8_YUV_CENTER
    mov     eax, r13d
    imul    eax, VP8_YUV_V_TO_R
    add     eax, VP8_YUV_ROUND
    sar     eax, VP8_YUV_SHIFT
    lea     edi, [r12 + rax]
    call    er_vp8_clamp_u8
    mov     r10d, eax
    mov     eax, ebx
    imul    eax, VP8_YUV_U_TO_G
    mov     ecx, r13d
    imul    ecx, VP8_YUV_V_TO_G
    add     eax, ecx
    add     eax, VP8_YUV_ROUND
    sar     eax, VP8_YUV_SHIFT
    mov     edi, r12d
    sub     edi, eax
    call    er_vp8_clamp_u8
    mov     r11d, eax
    mov     eax, ebx
    imul    eax, VP8_YUV_U_TO_B
    add     eax, VP8_YUV_ROUND
    sar     eax, VP8_YUV_SHIFT
    lea     edi, [r12 + rax]
    call    er_vp8_clamp_u8
    shl     eax, 16
    shl     r11d, 8
    or      eax, r11d
    or      eax, r10d
    or      eax, VP8_RGBA_ALPHA_OPAQUE << 24
    er_ok
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_write_frame_rgba(y_plane, u_plane, v_plane, width, height, chroma_width, out_rgba)
; -> eax=pixels written, rdx=error
er_fn er_vp8_write_frame_rgba
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 40
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8d, r8d
    jz      .invalid_param
    test    r9d, r9d
    jz      .invalid_param
    mov     rax, [rsp + 88]
    test    rax, rax
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rax
    mov     [rsp], ecx
    mov     [rsp + 4], r8d
    mov     [rsp + 8], r9d
    mov     dword [rsp + 12], 0
    mov     dword [rsp + 16], 0
.rgba_row_loop:
    mov     eax, [rsp + 16]
    cmp     eax, [rsp + 4]
    jae     .ok
    mov     dword [rsp + 20], 0
.rgba_col_loop:
    mov     eax, [rsp + 20]
    cmp     eax, [rsp]
    jae     .rgba_next_row
    mov     eax, [rsp + 16]
    imul    eax, [rsp]
    add     eax, [rsp + 20]
    mov     [rsp + 24], eax
    mov     eax, [rsp + 16]
    shr     eax, 1
    imul    eax, [rsp + 8]
    mov     ecx, [rsp + 20]
    shr     ecx, 1
    add     eax, ecx
    mov     [rsp + 28], eax
    mov     ecx, [rsp + 24]
    mov     ebx, [rsp + 28]
    movzx   edi, byte [r12 + rcx]
    movzx   esi, byte [r13 + rbx]
    movzx   edx, byte [r14 + rbx]
    call    er_vp8_yuv_to_rgba
    mov     ecx, [rsp + 24]
    mov     [r15 + rcx * 4], eax
    inc     dword [rsp + 12]
    inc     dword [rsp + 20]
    jmp     .rgba_col_loop
.rgba_next_row:
    inc     dword [rsp + 16]
    jmp     .rgba_row_loop
.ok:
    mov     eax, [rsp + 12]
    er_ok
    jmp     .done_write_frame_rgba
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_write_frame_rgba:
    er_stack_free 40
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_add_pixel(plane, index, delta) -> eax=new pixel, rdx=error
; rdi=plane, esi=index, edx=delta.
er_fn er_vp8_add_pixel
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    movzx   edi, byte [r12 + rbx]
    add     edi, edx
    call    er_vp8_clamp_u8
    test    edx, edx
    jnz     .done_add_pixel
    mov     [r12 + rbx], al
    er_ok
    jmp     .done_add_pixel
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_add_pixel:
    er_pop  rbx, r12
    er_ret

; er_vp8_add_idct_block(input, plane, offset, stride)
; -> eax=VP8_BLOCK_SIZE * VP8_BLOCK_SIZE, rdx=error
; input[16] i32, plane u8*, edx=offset, ecx=stride.
er_fn er_vp8_add_idct_block
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DEQUANT_BLOCK_BYTES
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    mov     r12, rsi
    mov     r13d, edx
    mov     r14d, ecx
    mov     r15, rsp
    mov     rsi, r15
    call    er_vp8_inverse_idct
    test    edx, edx
    jnz     .done_add_block
    xor     ebx, ebx
.row_loop:
    cmp     ebx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r11d, r11d
.col_loop:
    cmp     r11d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     eax, ebx
    imul    eax, r14d
    add     eax, r13d
    add     eax, r11d
    mov     esi, eax
    mov     eax, ebx
    shl     eax, 4
    lea     eax, [eax + r11d * 4]
    mov     edx, [r15 + rax]
    mov     rdi, r12
    call    er_vp8_add_pixel
    test    edx, edx
    jnz     .done_add_block
    inc     r11d
    jmp     .col_loop
.next_row:
    inc     ebx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_add_block
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_add_block:
    er_stack_free VP8_DEQUANT_BLOCK_BYTES
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_y_plane_block_offset(block) -> eax=offset inside 16x16 luma plane, rdx=error
; edi=block 0..15.
er_fn er_vp8_y_plane_block_offset
    cmp     edi, VP8_Y_BLOCK_COUNT
    jae     .invalid_param
    mov     eax, edi
    and     eax, 3
    shl     eax, 2
    mov     ecx, edi
    shr     ecx, 2
    shl     ecx, 6
    add     eax, ecx
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_uv_plane_block_offset(block) -> eax=offset inside 8x8 chroma plane, rdx=error
; edi=block 0..3.
er_fn er_vp8_uv_plane_block_offset
    cmp     edi, VP8_UV_BLOCK_COUNT
    jae     .invalid_param
    mov     eax, edi
    and     eax, 1
    shl     eax, 2
    mov     ecx, edi
    shr     ecx, 1
    shl     ecx, 5
    add     eax, ecx
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_add_luma_residuals_without_y2(dequant, coeffs, y_plane) -> eax=16 blocks, rdx=error
; coeffs is 25 contiguous VP8_COEFF_BLOCK_BYTES blocks.
er_fn er_vp8_add_luma_residuals_without_y2
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DEQUANT_BLOCK_BYTES
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    xor     r15d, r15d
.block_loop:
    cmp     r15d, VP8_Y_BLOCK_COUNT
    jae     .ok
    mov     eax, r15d
    imul    eax, VP8_COEFF_BLOCK_BYTES
    lea     rdi, [r13 + rax]
    mov     rsi, r12
    mov     rdx, rsp
    call    er_vp8_dequantize_y_block_with_own_dc
    test    edx, edx
    jnz     .done_luma_without_y2
    mov     edi, r15d
    call    er_vp8_y_plane_block_offset
    test    edx, edx
    jnz     .done_luma_without_y2
    mov     ebx, eax
    mov     rdi, rsp
    mov     rsi, r14
    mov     edx, ebx
    mov     ecx, VP8_MACROBLOCK_SIZE
    call    er_vp8_add_idct_block
    test    edx, edx
    jnz     .done_luma_without_y2
    inc     r15d
    jmp     .block_loop
.ok:
    mov     eax, VP8_Y_BLOCK_COUNT
    er_ok
    jmp     .done_luma_without_y2
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_luma_without_y2:
    er_stack_free VP8_DEQUANT_BLOCK_BYTES
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_add_luma_residuals_with_y2(dequant, coeffs, y_plane) -> eax=16 blocks, rdx=error
er_fn er_vp8_add_luma_residuals_with_y2
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DEQUANT_BLOCK_BYTES * 2
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    lea     rdi, [r13 + VP8_Y2_BLOCK_INDEX * VP8_COEFF_BLOCK_BYTES]
    mov     rsi, r12
    mov     rdx, rsp
    call    er_vp8_dequantize_y2_block
    test    edx, edx
    jnz     .done_luma_with_y2
    mov     rdi, rsp
    lea     rsi, [rsp + VP8_DEQUANT_BLOCK_BYTES]
    call    er_vp8_inverse_wht
    test    edx, edx
    jnz     .done_luma_with_y2
    xor     r15d, r15d
.block_loop:
    cmp     r15d, VP8_Y_BLOCK_COUNT
    jae     .ok
    mov     eax, r15d
    imul    eax, VP8_COEFF_BLOCK_BYTES
    lea     rdi, [r13 + rax]
    mov     rsi, r12
    mov     edx, [rsp + VP8_DEQUANT_BLOCK_BYTES + r15 * 4]
    mov     rcx, rsp
    call    er_vp8_dequantize_y_block_with_y2_dc
    test    edx, edx
    jnz     .done_luma_with_y2
    mov     edi, r15d
    call    er_vp8_y_plane_block_offset
    test    edx, edx
    jnz     .done_luma_with_y2
    mov     ebx, eax
    mov     rdi, rsp
    mov     rsi, r14
    mov     edx, ebx
    mov     ecx, VP8_MACROBLOCK_SIZE
    call    er_vp8_add_idct_block
    test    edx, edx
    jnz     .done_luma_with_y2
    inc     r15d
    jmp     .block_loop
.ok:
    mov     eax, VP8_Y_BLOCK_COUNT
    er_ok
    jmp     .done_luma_with_y2
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_luma_with_y2:
    er_stack_free VP8_DEQUANT_BLOCK_BYTES * 2
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_add_chroma_residuals(dequant, coeffs, u_plane, v_plane) -> eax=8 blocks, rdx=error
er_fn er_vp8_add_chroma_residuals
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DEQUANT_BLOCK_BYTES
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx
    xor     ebx, ebx
.block_loop:
    cmp     ebx, VP8_CHROMA_COEFF_BLOCK_COUNT
    jae     .ok
    mov     eax, VP8_Y_BLOCK_COUNT
    add     eax, ebx
    imul    eax, VP8_COEFF_BLOCK_BYTES
    lea     rdi, [r13 + rax]
    mov     rsi, r12
    mov     rdx, rsp
    call    er_vp8_dequantize_uv_block
    test    edx, edx
    jnz     .done_chroma
    mov     edi, ebx
    cmp     ebx, VP8_UV_BLOCK_COUNT
    jb      .u_plane
    sub     edi, VP8_UV_BLOCK_COUNT
.u_plane:
    call    er_vp8_uv_plane_block_offset
    test    edx, edx
    jnz     .done_chroma
    mov     edx, eax
    mov     rdi, rsp
    mov     rsi, r14
    cmp     ebx, VP8_UV_BLOCK_COUNT
    jb      .add_block
    mov     rsi, r15
.add_block:
    mov     ecx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_add_idct_block
    test    edx, edx
    jnz     .done_chroma
    inc     ebx
    jmp     .block_loop
.ok:
    mov     eax, VP8_CHROMA_COEFF_BLOCK_COUNT
    er_ok
    jmp     .done_chroma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_chroma:
    er_stack_free VP8_DEQUANT_BLOCK_BYTES
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_reconstruct_bpred_luma(dequant, edges, modes, coeffs, y_plane) -> eax=16 blocks, rdx=error
; modes are 16 VP8_INTRA4_MODE_* bytes. coeffs is 25 contiguous coefficient blocks.
er_fn er_vp8_reconstruct_bpred_luma
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP8_DEQUANT_BLOCK_BYTES + 8
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx
    mov     [rsp], r8
    xor     ebx, ebx
.block_loop:
    cmp     ebx, VP8_Y_BLOCK_COUNT
    jae     .ok
    movzx   edi, byte [r14 + rbx]
    mov     rsi, r13
    mov     rdx, [rsp]
    mov     ecx, ebx
    call    er_vp8_predict_intra4_block
    test    edx, edx
    jnz     .done_reconstruct_bpred
    mov     eax, ebx
    imul    eax, VP8_COEFF_BLOCK_BYTES
    lea     rdi, [r15 + rax]
    mov     rsi, r12
    lea     rdx, [rsp + 8]
    call    er_vp8_dequantize_y_block_with_own_dc
    test    edx, edx
    jnz     .done_reconstruct_bpred
    mov     edi, ebx
    call    er_vp8_y_plane_block_offset
    test    edx, edx
    jnz     .done_reconstruct_bpred
    lea     rdi, [rsp + 8]
    mov     rsi, [rsp]
    mov     edx, eax
    mov     ecx, VP8_MACROBLOCK_SIZE
    call    er_vp8_add_idct_block
    test    edx, edx
    jnz     .done_reconstruct_bpred
    inc     ebx
    jmp     .block_loop
.ok:
    mov     eax, VP8_Y_BLOCK_COUNT
    er_ok
    jmp     .done_reconstruct_bpred
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_reconstruct_bpred:
    er_stack_free VP8_DEQUANT_BLOCK_BYTES + 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_reconstruct_intra_luma(dequant, mode, edges, coeffs, y_plane) -> eax=16 blocks, rdx=error
; Non-B_PRED path: predict full luma plane, then add Y2-backed luma residuals.
er_fn er_vp8_reconstruct_intra_luma
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_LUMA_MODE_TRUE_MOTION
    ja      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     edi, ebx
    mov     rsi, r13
    mov     rdx, r15
    call    er_vp8_predict_luma
    test    edx, edx
    jnz     .done_intra_luma
    mov     rdi, r12
    mov     rsi, r14
    mov     rdx, r15
    call    er_vp8_add_luma_residuals_with_y2
    jmp     .done_intra_luma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_intra_luma:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_reconstruct_chroma(dequant, mode, u_edges, v_edges, coeffs, u_plane, v_plane) -> eax=8 blocks, rdx=error
er_fn er_vp8_reconstruct_chroma
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_CHROMA_MODE_TRUE_MOTION
    ja      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, r8
    mov     r14, r9
    mov     r15, [rsp + 64]
    test    r15, r15
    jz      .invalid_param
    mov     [rsp], rdx
    mov     [rsp + 8], rcx
    mov     edi, ebx
    mov     rsi, [rsp]
    mov     rdx, r14
    call    er_vp8_predict_chroma
    test    edx, edx
    jnz     .done_chroma_reconstruct
    mov     edi, ebx
    mov     rsi, [rsp + 8]
    mov     rdx, r15
    call    er_vp8_predict_chroma
    test    edx, edx
    jnz     .done_chroma_reconstruct
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    call    er_vp8_add_chroma_residuals
    jmp     .done_chroma_reconstruct
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_chroma_reconstruct:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_reconstruct_intra_macroblock(dequant, luma_mode, chroma_mode, y_edges, u_edges, v_edges, modes, coeffs, y_plane, u_plane, v_plane)
; -> eax=25 reconstructed coefficient blocks, rdx=error
er_fn er_vp8_reconstruct_intra_macroblock
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 48
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_LUMA_MODE_B_PRED
    ja      .invalid_param
    cmp     edx, VP8_CHROMA_MODE_TRUE_MOTION
    ja      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     [rsp], edx
    mov     r13, rcx
    mov     r14, r8
    mov     r15, r9
    mov     rax, [rsp + 96]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 8], rax
    mov     rax, [rsp + 104]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 16], rax
    mov     rax, [rsp + 112]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 24], rax
    mov     rax, [rsp + 120]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 32], rax
    mov     rax, [rsp + 128]
    test    rax, rax
    jz      .invalid_param
    mov     [rsp + 40], rax
    cmp     ebx, VP8_LUMA_MODE_B_PRED
    jne     .intra_luma
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, [rsp + 8]
    mov     rcx, [rsp + 16]
    mov     r8, [rsp + 24]
    call    er_vp8_reconstruct_bpred_luma
    jmp     .luma_done
.intra_luma:
    mov     rdi, r12
    mov     esi, ebx
    mov     rdx, r13
    mov     rcx, [rsp + 16]
    mov     r8, [rsp + 24]
    call    er_vp8_reconstruct_intra_luma
.luma_done:
    test    edx, edx
    jnz     .done_macroblock
    mov     rdi, r12
    mov     esi, [rsp]
    mov     rdx, r14
    mov     rcx, r15
    mov     r8, [rsp + 16]
    mov     r9, [rsp + 32]
    push    qword [rsp + 40]
    call    er_vp8_reconstruct_chroma
    add     rsp, 8
    test    edx, edx
    jnz     .done_macroblock
    mov     eax, VP8_MACROBLOCK_COEFF_BLOCK_COUNT
    er_ok
    jmp     .done_macroblock
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_macroblock:
    er_stack_free 48
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_dc_prediction_value(edges, size) -> eax=value, rdx=error
; edges layout: top[size], left[size], top_left, has_top, has_left.
; size must be 8 or 16.
er_fn er_vp8_dc_prediction_value
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_CHROMA_BLOCK_SIZE
    je      .size_ok
    cmp     esi, VP8_MACROBLOCK_SIZE
    jne     .invalid_param
.size_ok:
    mov     r12, rdi
    mov     r13d, esi
    xor     ebx, ebx
    movzx   r8d, byte [r12 + r13 * 2 + 1]
    test    r8d, r8d
    jz      .left_sum
    xor     ecx, ecx
.top_loop:
    cmp     ecx, r13d
    jae     .left_sum
    movzx   eax, byte [r12 + rcx]
    add     ebx, eax
    inc     ecx
    jmp     .top_loop
.left_sum:
    movzx   r9d, byte [r12 + r13 * 2 + 2]
    test    r9d, r9d
    jz      .compute
    xor     ecx, ecx
.left_loop:
    cmp     ecx, r13d
    jae     .compute
    mov     eax, r13d
    add     eax, ecx
    movzx   eax, byte [r12 + rax]
    add     ebx, eax
    inc     ecx
    jmp     .left_loop
.compute:
    test    r8d, r8d
    jz      .maybe_left_only
    test    r9d, r9d
    jz      .one_edge
    lea     eax, [rbx + r13]
    cmp     r13d, VP8_MACROBLOCK_SIZE
    je      .both16
    shr     eax, 4
    er_ok
    jmp     .done_dc
.both16:
    shr     eax, 5
    er_ok
    jmp     .done_dc
.maybe_left_only:
    test    r9d, r9d
    jz      .neutral
.one_edge:
    mov     eax, r13d
    shr     eax, 1
    add     eax, ebx
    cmp     r13d, VP8_MACROBLOCK_SIZE
    je      .one16
    shr     eax, 3
    er_ok
    jmp     .done_dc
.one16:
    shr     eax, 4
    er_ok
    jmp     .done_dc
.neutral:
    mov     eax, VP8_NEUTRAL_LUMA
    er_ok
    jmp     .done_dc
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_dc:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_predict_dc(edges, plane, size) -> eax=pixels written, rdx=error
er_fn er_vp8_predict_dc
    er_push rbx, r12, r13, r14
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rsi
    mov     r13d, edx
    mov     esi, edx
    call    er_vp8_dc_prediction_value
    test    edx, edx
    jnz     .done_predict_dc
    mov     r14d, eax
    mov     eax, r13d
    imul    eax, r13d
    mov     ebx, eax
    xor     ecx, ecx
.loop:
    cmp     ecx, ebx
    jae     .ok
    mov     [r12 + rcx], r14b
    inc     ecx
    jmp     .loop
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done_predict_dc
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_predict_dc:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_predict_vertical(edges, plane, size) -> eax=pixels written, rdx=error
er_fn er_vp8_predict_vertical
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, VP8_CHROMA_BLOCK_SIZE
    je      .size_ok
    cmp     edx, VP8_MACROBLOCK_SIZE
    jne     .invalid_param
.size_ok:
    xor     r8d, r8d
.row_loop:
    cmp     r8d, edx
    jae     .ok
    xor     ecx, ecx
.col_loop:
    cmp     ecx, edx
    jae     .next_row
    movzx   eax, byte [rdi + rcx]
    mov     r9d, r8d
    imul    r9d, edx
    add     r9d, ecx
    mov     [rsi + r9], al
    inc     ecx
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, edx
    imul    eax, edx
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_predict_horizontal(edges, plane, size) -> eax=pixels written, rdx=error
er_fn er_vp8_predict_horizontal
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, VP8_CHROMA_BLOCK_SIZE
    je      .size_ok
    cmp     edx, VP8_MACROBLOCK_SIZE
    jne     .invalid_param
.size_ok:
    xor     r8d, r8d
.row_loop:
    cmp     r8d, edx
    jae     .ok
    mov     eax, edx
    add     eax, r8d
    movzx   eax, byte [rdi + rax]
    xor     ecx, ecx
.col_loop:
    cmp     ecx, edx
    jae     .next_row
    mov     r9d, r8d
    imul    r9d, edx
    add     r9d, ecx
    mov     [rsi + r9], al
    inc     ecx
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, edx
    imul    eax, edx
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_predict_true_motion(edges, plane, size) -> eax=pixels written, rdx=error
er_fn er_vp8_predict_true_motion
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, VP8_CHROMA_BLOCK_SIZE
    je      .size_ok
    cmp     edx, VP8_MACROBLOCK_SIZE
    jne     .invalid_param
.size_ok:
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    movzx   ebx, byte [r12 + r14 * 2]
    xor     r8d, r8d
.row_loop:
    cmp     r8d, r14d
    jae     .ok
    xor     r9d, r9d
.col_loop:
    cmp     r9d, r14d
    jae     .next_row
    mov     edi, r14d
    add     edi, r8d
    movzx   edi, byte [r12 + rdi]
    movzx   eax, byte [r12 + r9]
    add     edi, eax
    sub     edi, ebx
    call    er_vp8_clamp_u8
    test    edx, edx
    jnz     .done_true_motion
    mov     ecx, r8d
    imul    ecx, r14d
    add     ecx, r9d
    mov     [r13 + rcx], al
    inc     r9d
    jmp     .col_loop
.next_row:
    inc     r8d
    jmp     .row_loop
.ok:
    mov     eax, r14d
    imul    eax, r14d
    er_ok
    jmp     .done_true_motion
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_true_motion:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_predict_luma(mode, edges, plane) -> eax=256 pixels, rdx=error
; B_PRED mode fills all sixteen 4x4 blocks with intra4 DC prediction.
er_fn er_vp8_predict_luma
    er_push rbx, r12, r13
    cmp     edi, VP8_LUMA_MODE_B_PRED
    ja      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     ebx, edi
    mov     r12, rsi
    mov     r13, rdx
    cmp     ebx, VP8_LUMA_MODE_VERTICAL
    je      .vertical
    cmp     ebx, VP8_LUMA_MODE_HORIZONTAL
    je      .horizontal
    cmp     ebx, VP8_LUMA_MODE_TRUE_MOTION
    je      .true_motion
    cmp     ebx, VP8_LUMA_MODE_B_PRED
    je      .b_pred
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_predict_dc
    jmp     .done_luma
.vertical:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_predict_vertical
    jmp     .done_luma
.horizontal:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_predict_horizontal
    jmp     .done_luma
.true_motion:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_MACROBLOCK_SIZE
    call    er_vp8_predict_true_motion
    jmp     .done_luma
.b_pred:
    xor     ebx, ebx
.b_loop:
    cmp     ebx, VP8_Y_BLOCK_COUNT
    jae     .b_ok
    mov     edi, VP8_INTRA4_MODE_DC
    mov     rsi, r12
    mov     rdx, r13
    mov     ecx, ebx
    call    er_vp8_predict_intra4_block
    test    edx, edx
    jnz     .done_luma
    inc     ebx
    jmp     .b_loop
.b_ok:
    mov     eax, VP8_MACROBLOCK_SIZE * VP8_MACROBLOCK_SIZE
    er_ok
    jmp     .done_luma
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_luma:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_predict_chroma(mode, edges, plane) -> eax=64 pixels, rdx=error
er_fn er_vp8_predict_chroma
    er_push rbx, r12, r13
    cmp     edi, VP8_CHROMA_MODE_TRUE_MOTION
    ja      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     ebx, edi
    mov     r12, rsi
    mov     r13, rdx
    cmp     ebx, VP8_CHROMA_MODE_VERTICAL
    je      .vertical
    cmp     ebx, VP8_CHROMA_MODE_HORIZONTAL
    je      .horizontal
    cmp     ebx, VP8_CHROMA_MODE_TRUE_MOTION
    je      .true_motion
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_dc
    jmp     .done_chroma_predict
.vertical:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_vertical
    jmp     .done_chroma_predict
.horizontal:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_horizontal
    jmp     .done_chroma_predict
.true_motion:
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, VP8_CHROMA_BLOCK_SIZE
    call    er_vp8_predict_true_motion
    jmp     .done_chroma_predict
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_chroma_predict:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_avg2(x, y) -> eax=rounded average, rdx=error
er_fn er_vp8_avg2
    movzx   eax, dil
    movzx   ecx, sil
    add     eax, ecx
    inc     eax
    shr     eax, 1
    er_ok
    er_ret

; er_vp8_avg3(x, y, z) -> eax=(x + 2*y + z + 2) >> 2, rdx=error
er_fn er_vp8_avg3
    movzx   eax, dil
    movzx   ecx, sil
    lea     eax, [eax + ecx * 2 + 2]
    movzx   ecx, dl
    add     eax, ecx
    shr     eax, 2
    er_ok
    er_ret

; er_vp8_write_intra4(plane, block_x, block_y, y, x, value) -> eax=offset, rdx=error
er_fn er_vp8_write_intra4
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, VP8_MACROBLOCK_SIZE - VP8_BLOCK_SIZE
    ja      .invalid_param
    cmp     edx, VP8_MACROBLOCK_SIZE - VP8_BLOCK_SIZE
    ja      .invalid_param
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .invalid_param
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .invalid_param
    mov     eax, edx
    add     eax, ecx
    shl     eax, 4
    add     eax, esi
    add     eax, r8d
    mov     [rdi + rax], r9b
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_predict_intra4_dc(a, l, plane, block_x, block_y) -> eax=16, rdx=error
; a[8] top samples, l[4] left samples.
er_fn er_vp8_predict_intra4_dc
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15d, ecx
    mov     ebx, r8d
    xor     eax, eax
    xor     ecx, ecx
.sum_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .fill
    movzx   edx, byte [r12 + rcx]
    add     eax, edx
    movzx   edx, byte [r13 + rcx]
    add     eax, edx
    inc     ecx
    jmp     .sum_loop
.fill:
    add     eax, 4
    shr     eax, 3
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r15d
    add     edx, r8d
    mov     [r14 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_intra4_dc
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_intra4_dc:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_predict_intra4_true_motion(a, l, p, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_true_motion
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 8
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     [rsp], edx
    mov     r14, rcx
    mov     r15d, r8d
    mov     ebx, r9d
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    movzx   edi, byte [r13 + rcx]
    movzx   eax, byte [r12 + r8]
    add     edi, eax
    sub     edi, [rsp]
    call    er_vp8_clamp_u8
    test    edx, edx
    jnz     .done_true4
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r15d
    add     edx, r8d
    mov     [r14 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_true4
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_true4:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_predict_intra4_vertical(a, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_vertical
    er_push rbx, r12, r13, r14
    er_stack_alloc 8
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     ebx, ecx
    xor     ecx, ecx
.value_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .fill_rows
    movzx   edi, byte [r12 + rcx]
    movzx   esi, byte [r12 + rcx + 1]
    movzx   edx, byte [r12 + rcx + 2]
    call    er_vp8_avg3
    mov     [rsp + rcx], al
    inc     ecx
    jmp     .value_loop
.fill_rows:
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r14d
    add     edx, r8d
    movzx   eax, byte [rsp + r8]
    mov     [r13 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_vertical4
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_vertical4:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_predict_intra4_horizontal(l, p, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_horizontal
    er_push rbx, r12, r13, r14
    er_stack_alloc 8
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     [rsp + 4], esi
    mov     r13, rdx
    mov     r14d, ecx
    mov     ebx, r8d
    movzx   edi, byte [rsp + 4]
    movzx   esi, byte [r12]
    movzx   edx, byte [r12 + 1]
    call    er_vp8_avg3
    mov     [rsp], al
    movzx   edi, byte [r12]
    movzx   esi, byte [r12 + 1]
    movzx   edx, byte [r12 + 2]
    call    er_vp8_avg3
    mov     [rsp + 1], al
    movzx   edi, byte [r12 + 1]
    movzx   esi, byte [r12 + 2]
    movzx   edx, byte [r12 + 3]
    call    er_vp8_avg3
    mov     [rsp + 2], al
    movzx   edi, byte [r12 + 2]
    movzx   esi, byte [r12 + 3]
    movzx   edx, byte [r12 + 3]
    call    er_vp8_avg3
    mov     [rsp + 3], al
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    movzx   eax, byte [rsp + rcx]
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r14d
    add     edx, r8d
    mov     [r13 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_horizontal4
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_horizontal4:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_predict_intra4_left_down(a, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_left_down
    er_push rbx, r12, r13, r14
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     ebx, ecx
    xor     ecx, ecx
.value_loop:
    cmp     ecx, 7
    jae     .fill
    movzx   edi, byte [r12 + rcx]
    movzx   esi, byte [r12 + rcx + 1]
    movzx   edx, byte [r12 + rcx + 2]
    call    er_vp8_avg3
    mov     [rsp + rcx], al
    inc     ecx
    jmp     .value_loop
.fill:
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     eax, ecx
    add     eax, r8d
    movzx   eax, byte [rsp + rax]
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r14d
    add     edx, r8d
    mov     [r13 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_left_down
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_left_down:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_predict_intra4_vertical_left(a, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_vertical_left
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     ebx, ecx
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     eax, ecx
    add     eax, r8d
    mov     r9d, eax
    test    ecx, 1
    jnz     .use_avg3
    movzx   edi, byte [r12 + r9]
    movzx   esi, byte [r12 + r9 + 1]
    call    er_vp8_avg2
    jmp     .write
.use_avg3:
    movzx   edi, byte [r12 + r9]
    movzx   esi, byte [r12 + r9 + 1]
    movzx   edx, byte [r12 + r9 + 2]
    call    er_vp8_avg3
.write:
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r14d
    add     edx, r8d
    mov     [r13 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_vertical_left
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_vertical_left:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_predict_intra4_horizontal_up(l, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_horizontal_up
    er_push rbx, r12, r13, r14
    er_stack_alloc 8
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     ebx, ecx
    movzx   edi, byte [r12]
    movzx   esi, byte [r12 + 1]
    call    er_vp8_avg2
    mov     [rsp], al
    movzx   edi, byte [r12 + 1]
    movzx   esi, byte [r12 + 2]
    movzx   edx, byte [r12 + 3]
    call    er_vp8_avg3
    mov     [rsp + 1], al
    movzx   edi, byte [r12 + 1]
    movzx   esi, byte [r12 + 2]
    call    er_vp8_avg2
    mov     [rsp + 2], al
    movzx   edi, byte [r12 + 2]
    movzx   esi, byte [r12 + 3]
    movzx   edx, byte [r12 + 3]
    call    er_vp8_avg3
    mov     [rsp + 3], al
    movzx   edi, byte [r12 + 2]
    movzx   esi, byte [r12 + 3]
    call    er_vp8_avg2
    mov     [rsp + 4], al
    movzx   eax, byte [r12 + 3]
    mov     [rsp + 5], al
    xor     ecx, ecx
.row_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .ok
    xor     r8d, r8d
.col_loop:
    cmp     r8d, VP8_BLOCK_SIZE
    jae     .next_row
    mov     eax, ecx
    shl     eax, 1
    add     eax, r8d
    cmp     eax, 5
    jbe     .load
    mov     eax, 5
.load:
    movzx   eax, byte [rsp + rax]
    mov     edx, ebx
    add     edx, ecx
    shl     edx, 4
    add     edx, r14d
    add     edx, r8d
    mov     [r13 + rdx], al
    inc     r8d
    jmp     .col_loop
.next_row:
    inc     ecx
    jmp     .row_loop
.ok:
    mov     eax, VP8_COEFF_BLOCK_COEFF_COUNT
    er_ok
    jmp     .done_horizontal_up
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_horizontal_up:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_build_intra4_edge(a, l, p, out) -> eax=VP8_INTRA4_EDGE_SIZE, rdx=error
; out is [l3, l2, l1, l0, p, a0, a1, a2, a3].
er_fn er_vp8_build_intra4_edge
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    movzx   eax, byte [rsi + 3]
    mov     [rcx], al
    movzx   eax, byte [rsi + 2]
    mov     [rcx + 1], al
    movzx   eax, byte [rsi + 1]
    mov     [rcx + 2], al
    movzx   eax, byte [rsi]
    mov     [rcx + 3], al
    mov     [rcx + 4], dl
    movzx   eax, byte [rdi]
    mov     [rcx + 5], al
    movzx   eax, byte [rdi + 1]
    mov     [rcx + 6], al
    movzx   eax, byte [rdi + 2]
    mov     [rcx + 7], al
    movzx   eax, byte [rdi + 3]
    mov     [rcx + 8], al
    mov     eax, VP8_INTRA4_EDGE_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_predict_intra4_table(e, plane, block_x, block_y, table, count) -> eax=count, rdx=error
; table entries are y, x, e-index, average-kind bytes.
er_fn er_vp8_predict_intra4_table
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    cmp     edx, VP8_MACROBLOCK_SIZE - VP8_BLOCK_SIZE
    ja      .invalid_param
    cmp     ecx, VP8_MACROBLOCK_SIZE - VP8_BLOCK_SIZE
    ja      .invalid_param
    cmp     r9d, VP8_COEFF_BLOCK_COEFF_COUNT
    ja      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     [rsp], edx
    mov     [rsp + 4], ecx
    mov     rbx, r8
    mov     r14d, r9d
    xor     r15d, r15d
.entry_loop:
    cmp     r15d, r14d
    jae     .ok
    mov     eax, r15d
    shl     eax, 2
    movzx   ecx, byte [rbx + rax + VP8_INTRA4_TABLE_Y]
    mov     [rsp + 8], ecx
    movzx   ecx, byte [rbx + rax + VP8_INTRA4_TABLE_X]
    mov     [rsp + 12], ecx
    movzx   r10d, byte [rbx + rax + VP8_INTRA4_TABLE_INDEX]
    cmp     byte [rbx + rax + VP8_INTRA4_TABLE_KIND], VP8_INTRA4_TABLE_KIND_AVG3
    je      .avg3
    movzx   edi, byte [r12 + r10]
    movzx   esi, byte [r12 + r10 + 1]
    call    er_vp8_avg2
    jmp     .write
.avg3:
    movzx   edi, byte [r12 + r10 - 1]
    movzx   esi, byte [r12 + r10]
    movzx   edx, byte [r12 + r10 + 1]
    call    er_vp8_avg3
.write:
    test    edx, edx
    jnz     .done_table
    mov     ecx, [rsp + 4]
    add     ecx, [rsp + 8]
    shl     ecx, 4
    add     ecx, [rsp]
    add     ecx, [rsp + 12]
    mov     [r13 + rcx], al
    inc     r15d
    jmp     .entry_loop
.ok:
    mov     eax, r14d
    er_ok
    jmp     .done_table
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_table:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_predict_intra4_right_down(e, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_right_down
    lea     r8, [rel vp8_intra4_right_down_table]
    mov     r9d, VP8_COEFF_BLOCK_COEFF_COUNT
    call    er_vp8_predict_intra4_table
    er_ret

; er_vp8_predict_intra4_vertical_right(e, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_vertical_right
    lea     r8, [rel vp8_intra4_vertical_right_table]
    mov     r9d, VP8_COEFF_BLOCK_COEFF_COUNT
    call    er_vp8_predict_intra4_table
    er_ret

; er_vp8_predict_intra4_horizontal_down(e, plane, block_x, block_y) -> eax=16, rdx=error
er_fn er_vp8_predict_intra4_horizontal_down
    lea     r8, [rel vp8_intra4_horizontal_down_table]
    mov     r9d, VP8_COEFF_BLOCK_COEFF_COUNT
    call    er_vp8_predict_intra4_table
    er_ret

; er_vp8_predict_intra4_block(mode, edges, plane, block) -> eax=16, rdx=error
; Builds VP8 intra4 top/left/top-left samples from 16x16 edges and already written plane pixels.
er_fn er_vp8_predict_intra4_block
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    cmp     edi, VP8_INTRA4_MODE_HORIZONTAL_UP
    ja      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     ecx, VP8_Y_BLOCK_COUNT
    jae     .invalid_param
    mov     ebx, edi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14d, ecx
    and     r14d, 3
    shl     r14d, 2
    mov     r15d, ecx
    shr     r15d, 2
    shl     r15d, 2
    xor     ecx, ecx
.top_loop:
    cmp     ecx, VP8_BLOCK_SIZE * 2
    jae     .left_start
    mov     eax, r14d
    add     eax, ecx
    test    r15d, r15d
    jnz     .top_from_plane
    cmp     eax, VP8_MACROBLOCK_SIZE
    jae     .top_from_right
    movzx   edx, byte [r12 + VP8_EDGES_TOP + rax]
    jmp     .top_store
.top_from_plane:
    cmp     eax, VP8_MACROBLOCK_SIZE
    jae     .top_from_right
    mov     edx, r15d
    dec     edx
    shl     edx, 4
    add     edx, eax
    movzx   edx, byte [r13 + rdx]
    jmp     .top_store
.top_from_right:
    sub     eax, VP8_MACROBLOCK_SIZE
    movzx   edx, byte [r12 + VP8_EDGES_TOP_RIGHT_16 + rax]
.top_store:
    mov     [rsp + rcx], dl
    inc     ecx
    jmp     .top_loop
.left_start:
    xor     ecx, ecx
.left_loop:
    cmp     ecx, VP8_BLOCK_SIZE
    jae     .top_left
    test    r14d, r14d
    jnz     .left_from_plane
    mov     eax, r15d
    add     eax, ecx
    movzx   edx, byte [r12 + VP8_EDGES_LEFT_16 + rax]
    jmp     .left_store
.left_from_plane:
    mov     edx, r15d
    add     edx, ecx
    shl     edx, 4
    add     edx, r14d
    dec     edx
    movzx   edx, byte [r13 + rdx]
.left_store:
    mov     [rsp + 8 + rcx], dl
    inc     ecx
    jmp     .left_loop
.top_left:
    test    r15d, r15d
    jnz     .top_left_not_top_row
    test    r14d, r14d
    jnz     .top_left_from_top
    movzx   eax, byte [r12 + VP8_EDGES_TOP_LEFT_16]
    jmp     .top_left_store
.top_left_from_top:
    mov     eax, r14d
    dec     eax
    movzx   eax, byte [r12 + VP8_EDGES_TOP + rax]
    jmp     .top_left_store
.top_left_not_top_row:
    test    r14d, r14d
    jnz     .top_left_from_plane
    mov     eax, r15d
    dec     eax
    movzx   eax, byte [r12 + VP8_EDGES_LEFT_16 + rax]
    jmp     .top_left_store
.top_left_from_plane:
    mov     eax, r15d
    dec     eax
    shl     eax, 4
    add     eax, r14d
    dec     eax
    movzx   eax, byte [r13 + rax]
.top_left_store:
    mov     [rsp + 28], al
    lea     rdi, [rsp]
    lea     rsi, [rsp + 8]
    movzx   edx, byte [rsp + 28]
    lea     rcx, [rsp + 16]
    call    er_vp8_build_intra4_edge
    test    edx, edx
    jnz     .done_block
    cmp     ebx, VP8_INTRA4_MODE_TRUE_MOTION
    je      .call_true
    cmp     ebx, VP8_INTRA4_MODE_VERTICAL
    je      .call_vertical
    cmp     ebx, VP8_INTRA4_MODE_HORIZONTAL
    je      .call_horizontal
    cmp     ebx, VP8_INTRA4_MODE_RIGHT_DOWN
    je      .call_right_down
    cmp     ebx, VP8_INTRA4_MODE_VERTICAL_RIGHT
    je      .call_vertical_right
    cmp     ebx, VP8_INTRA4_MODE_LEFT_DOWN
    je      .call_left_down
    cmp     ebx, VP8_INTRA4_MODE_VERTICAL_LEFT
    je      .call_vertical_left
    cmp     ebx, VP8_INTRA4_MODE_HORIZONTAL_DOWN
    je      .call_horizontal_down
    cmp     ebx, VP8_INTRA4_MODE_HORIZONTAL_UP
    je      .call_horizontal_up
    lea     rdi, [rsp]
    lea     rsi, [rsp + 8]
    mov     rdx, r13
    mov     ecx, r14d
    mov     r8d, r15d
    call    er_vp8_predict_intra4_dc
    jmp     .done_block
.call_true:
    lea     rdi, [rsp]
    lea     rsi, [rsp + 8]
    movzx   edx, byte [rsp + 28]
    mov     rcx, r13
    mov     r8d, r14d
    mov     r9d, r15d
    call    er_vp8_predict_intra4_true_motion
    jmp     .done_block
.call_vertical:
    lea     rdi, [rsp]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_vertical
    jmp     .done_block
.call_horizontal:
    lea     rdi, [rsp + 8]
    movzx   esi, byte [rsp + 28]
    mov     rdx, r13
    mov     ecx, r14d
    mov     r8d, r15d
    call    er_vp8_predict_intra4_horizontal
    jmp     .done_block
.call_right_down:
    lea     rdi, [rsp + 16]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_right_down
    jmp     .done_block
.call_vertical_right:
    lea     rdi, [rsp + 16]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_vertical_right
    jmp     .done_block
.call_left_down:
    lea     rdi, [rsp]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_left_down
    jmp     .done_block
.call_vertical_left:
    lea     rdi, [rsp]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_vertical_left
    jmp     .done_block
.call_horizontal_down:
    lea     rdi, [rsp + 16]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_horizontal_down
    jmp     .done_block
.call_horizontal_up:
    lea     rdi, [rsp + 8]
    mov     rsi, r13
    mov     edx, r14d
    mov     ecx, r15d
    call    er_vp8_predict_intra4_horizontal_up
    jmp     .done_block
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_block:
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_coeff_update_probability(index) -> eax=update probability, rdx=error
; edi=linear coefficient probability index 0..1055.
er_fn er_vp8_coeff_update_probability
    cmp     edi, VP8_COEFF_UPDATE_PROBABILITY_COUNT
    jae     .invalid_param
    lea     r8, [rel vp8_coeff_update_probabilities]
    xor     ecx, ecx
    mov     edx, VP8_COEFF_UPDATE_SPARSE_COUNT
.lookup:
    cmp     ecx, edx
    jae     .default
    mov     eax, ecx
    add     eax, edx
    shr     eax, 1
    mov     r9d, eax
    imul    r9d, VP8_COEFF_UPDATE_ENTRY_SIZE
    movzx   r10d, word [r8 + r9]
    cmp     r10d, edi
    je      .found
    jb      .right
    mov     edx, eax
    jmp     .lookup
.right:
    lea     ecx, [eax + 1]
    jmp     .lookup
.found:
    movzx   eax, byte [r8 + r9 + 2]
    er_ok
    er_ret
.default:
    mov     eax, VP8_COEFF_UPDATE_PROBABILITY_DEFAULT
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_parse_token_probability_updates(reader, probabilities)
; -> eax=updated probability count, rdx=error
; rdi=reader, rsi=probabilities[1056].
er_fn er_vp8_parse_token_probability_updates
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     r14d, r14d
    xor     r15d, r15d
.loop:
    cmp     r14d, VP8_COEFF_UPDATE_PROBABILITY_COUNT
    jae     .ok
    mov     edi, r14d
    call    er_vp8_coeff_update_probability
    test    edx, edx
    jnz     .done_updates
    mov     rdi, r12
    mov     esi, eax
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_updates
    test    eax, eax
    jz      .next
    mov     rdi, r12
    mov     esi, VP8_BOOL_BYTE_BITS
    call    er_vp8_bool_read_literal
    test    edx, edx
    jnz     .done_updates
    mov     [r13 + r14], al
    inc     r15d
.next:
    inc     r14d
    jmp     .loop
.ok:
    mov     eax, r15d
    er_ok
    jmp     .done_updates
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_updates:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp8_read_small_motion_vector_component(reader, probabilities) -> eax=magnitude 0..7, rdx=error
; rdi=reader, rsi=probabilities[19].
er_fn er_vp8_read_small_motion_vector_component
    er_push r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    lea     r13, [rsi + VP8_MV_SMALL_PROBABILITY_INDEX]
    movzx   esi, byte [r13]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    test    eax, eax
    jnz     .high
    mov     rdi, r12
    movzx   esi, byte [r13 + 1]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    test    eax, eax
    jnz     .two_or_three
    mov     rdi, r12
    movzx   esi, byte [r13 + 2]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    test    eax, eax
    jz      .zero
    mov     eax, 1
    er_ok
    jmp     .done_small_mv
.zero:
    xor     eax, eax
    er_ok
    jmp     .done_small_mv
.two_or_three:
    mov     rdi, r12
    movzx   esi, byte [r13 + 3]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    add     eax, 2
    er_ok
    jmp     .done_small_mv
.high:
    mov     rdi, r12
    movzx   esi, byte [r13 + 4]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    test    eax, eax
    jnz     .six_or_seven
    mov     rdi, r12
    movzx   esi, byte [r13 + 5]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    add     eax, 4
    er_ok
    jmp     .done_small_mv
.six_or_seven:
    mov     rdi, r12
    movzx   esi, byte [r13 + 6]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_small_mv
    add     eax, 6
    er_ok
    jmp     .done_small_mv
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_small_mv:
    er_pop  r12, r13
    er_ret

; er_vp8_read_long_motion_vector_component(reader, probabilities) -> eax=magnitude, rdx=error
; rdi=reader, rsi=probabilities[19].
er_fn er_vp8_read_long_motion_vector_component
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     ebx, ebx
    xor     r14d, r14d
.low_loop:
    cmp     r14d, VP8_MV_LONG_LOW_BIT_COUNT
    jae     .high_start
    mov     rdi, r12
    lea     eax, [r14 + VP8_MV_LONG_PROBABILITY_INDEX]
    movzx   esi, byte [r13 + rax]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_long_mv
    test    eax, eax
    jz      .next_low
    mov     eax, 1
    mov     ecx, r14d
    shl     eax, cl
    add     ebx, eax
.next_low:
    inc     r14d
    jmp     .low_loop
.high_start:
    mov     r14d, VP8_MV_LONG_HIGH_BIT_MAX
.high_loop:
    mov     rdi, r12
    lea     eax, [r14 + VP8_MV_LONG_PROBABILITY_INDEX]
    movzx   esi, byte [r13 + rax]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_long_mv
    test    eax, eax
    jz      .next_high
    mov     eax, 1
    mov     ecx, r14d
    shl     eax, cl
    add     ebx, eax
.next_high:
    cmp     r14d, VP8_MV_LONG_HIGH_BIT_MIN
    je      .implicit_check
    dec     r14d
    jmp     .high_loop
.implicit_check:
    cmp     ebx, VP8_MV_LONG_BIT3_THRESHOLD
    jb      .add_implicit
    mov     rdi, r12
    movzx   esi, byte [r13 + VP8_MV_LONG_PROBABILITY_INDEX + VP8_MV_LONG_BIT3_INDEX]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_long_mv
    test    eax, eax
    jz      .ok
.add_implicit:
    add     ebx, VP8_MV_LONG_IMPLICIT_BIT
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done_long_mv
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_long_mv:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_read_motion_vector_component(reader, probabilities) -> eax=signed component, rdx=error
; rdi=reader, rsi=probabilities[19].
er_fn er_vp8_read_motion_vector_component
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    movzx   esi, byte [r13 + VP8_MV_SHORT_PROBABILITY_INDEX]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_mv_component
    test    eax, eax
    jnz     .long_path
    mov     rdi, r12
    mov     rsi, r13
    call    er_vp8_read_small_motion_vector_component
    jmp     .magnitude_ready
.long_path:
    mov     rdi, r12
    mov     rsi, r13
    call    er_vp8_read_long_motion_vector_component
.magnitude_ready:
    test    edx, edx
    jnz     .done_mv_component
    mov     ebx, eax
    test    ebx, ebx
    jz      .ok
    mov     rdi, r12
    movzx   esi, byte [r13 + VP8_MV_SIGN_PROBABILITY_INDEX]
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done_mv_component
    test    eax, eax
    jz      .ok
    neg     ebx
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done_mv_component
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_mv_component:
    er_pop  rbx, r12, r13
    er_ret

; er_vp8_read_motion_vector(reader, probabilities, desc) -> eax=VP8_MOTION_VECTOR_SIZE, rdx=error
; probabilities points to two contiguous 19-byte component probability tables.
; desc: row i16, col i16.
; rdi=reader, rsi=probabilities, rdx=desc
er_fn er_vp8_read_motion_vector
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    call    er_vp8_read_motion_vector_component
    test    edx, edx
    jnz     .done_mv
    mov     [r14 + VP8_MOTION_VECTOR_ROW], ax
    mov     rdi, r12
    lea     rsi, [r13 + VP8_MV_PROBABILITY_COUNT]
    call    er_vp8_read_motion_vector_component
    test    edx, edx
    jnz     .done_mv
    mov     [r14 + VP8_MOTION_VECTOR_COL], ax
    mov     eax, VP8_MOTION_VECTOR_SIZE
    er_ok
    jmp     .done_mv
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done_mv:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp8_same_motion_vector(left, right) -> eax=1 if equal, eax=0 otherwise, rdx=error
; left/right point to VP8_MOTION_VECTOR_SIZE records.
er_fn er_vp8_same_motion_vector
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    movzx   eax, word [rdi + VP8_MOTION_VECTOR_ROW]
    cmp     ax, [rsi + VP8_MOTION_VECTOR_ROW]
    jne     .not_equal
    movzx   eax, word [rdi + VP8_MOTION_VECTOR_COL]
    cmp     ax, [rsi + VP8_MOTION_VECTOR_COL]
    jne     .not_equal
    mov     eax, 1
    er_ok
    er_ret
.not_equal:
    xor     eax, eax
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_add_motion_vector(left, right, out) -> eax=VP8_MOTION_VECTOR_SIZE, rdx=error
er_fn er_vp8_add_motion_vector
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    movsx   eax, word [rdi + VP8_MOTION_VECTOR_ROW]
    movsx   ecx, word [rsi + VP8_MOTION_VECTOR_ROW]
    add     eax, ecx
    jo      .invalid_param
    cmp     eax, 32767
    jg      .invalid_param
    cmp     eax, -32768
    jl      .invalid_param
    mov     [rdx + VP8_MOTION_VECTOR_ROW], ax
    movsx   eax, word [rdi + VP8_MOTION_VECTOR_COL]
    movsx   ecx, word [rsi + VP8_MOTION_VECTOR_COL]
    add     eax, ecx
    jo      .invalid_param
    cmp     eax, 32767
    jg      .invalid_param
    cmp     eax, -32768
    jl      .invalid_param
    mov     [rdx + VP8_MOTION_VECTOR_COL], ax
    mov     eax, VP8_MOTION_VECTOR_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_sub_motion_context(left, above) -> eax=context, rdx=error
; left/above point to VP8_MOTION_VECTOR_SIZE records.
er_fn er_vp8_sub_motion_context
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    movsx   eax, word [rdi + VP8_MOTION_VECTOR_ROW]
    or      ax, [rdi + VP8_MOTION_VECTOR_COL]
    sete    r8b
    movsx   eax, word [rsi + VP8_MOTION_VECTOR_ROW]
    or      ax, [rsi + VP8_MOTION_VECTOR_COL]
    sete    r9b
    test    r8b, r8b
    jz      .left_nonzero
    test    r9b, r9b
    jz      .left_zero
    mov     eax, VP8_SUB_MV_CONTEXT_LEFT_ABOVE_ZERO
    er_ok
    er_ret
.left_zero:
    mov     eax, VP8_SUB_MV_CONTEXT_LEFT_ZERO
    er_ok
    er_ret
.left_nonzero:
    test    r9b, r9b
    jz      .compare_vectors
    mov     eax, VP8_SUB_MV_CONTEXT_ABOVE_ZERO
    er_ok
    er_ret
.compare_vectors:
    movzx   eax, word [rdi + VP8_MOTION_VECTOR_ROW]
    cmp     ax, [rsi + VP8_MOTION_VECTOR_ROW]
    jne     .differs
    movzx   eax, word [rdi + VP8_MOTION_VECTOR_COL]
    cmp     ax, [rsi + VP8_MOTION_VECTOR_COL]
    jne     .differs
    mov     eax, VP8_SUB_MV_CONTEXT_LEFT_EQUALS_ABOVE
    er_ok
    er_ret
.differs:
    mov     eax, VP8_SUB_MV_CONTEXT_LEFT_DIFFERS_ABOVE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_inter_mode_context_probability(count, index) -> eax=probability, rdx=error
er_fn er_vp8_inter_mode_context_probability
    cmp     esi, VP8_INTER_MODE_PROBABILITY_COUNT
    jae     .invalid_param
    mov     eax, edi
    cmp     eax, VP8_INTER_MODE_CONTEXT_COUNT
    jb      .context_ready
    mov     eax, VP8_INTER_MODE_CONTEXT_COUNT - 1
.context_ready:
    imul    eax, VP8_INTER_MODE_PROBABILITY_COUNT
    add     eax, esi
    movzx   eax, byte [rel vp8_inter_mode_context_probabilities + rax]
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_split_mv_partition(index, out) -> eax=VP8_Y_BLOCK_COUNT, rdx=error
; out receives 16 one-byte partition ids.
er_fn er_vp8_split_mv_partition
    test    rsi, rsi
    jz      .invalid_param
    cmp     edi, VP8_SPLIT_MV_PARTITION_COUNT
    jae     .invalid_param
    mov     eax, edi
    shl     eax, 4
    lea     rdi, [rel vp8_split_mv_partitions + rax]
    mov     rdx, rsi
    mov     ecx, VP8_Y_BLOCK_COUNT
.copy_loop:
    test    ecx, ecx
    jz      .ok
    mov     al, [rdi]
    mov     [rdx], al
    inc     rdi
    inc     rdx
    dec     ecx
    jmp     .copy_loop
.ok:
    mov     eax, VP8_Y_BLOCK_COUNT
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp8_read_split_mv_partition(reader) -> eax=partition index, rdx=error
er_fn er_vp8_read_split_mv_partition
    test    rdi, rdi
    jz      .invalid_param
    mov     esi, VP8_SPLIT_MV_PROBABILITY_0
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jnz     .read_second
    mov     eax, 3
    er_ok
    jmp     .done
.read_second:
    mov     esi, VP8_SPLIT_MV_PROBABILITY_1
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jnz     .read_third
    mov     eax, 2
    er_ok
    jmp     .done
.read_third:
    mov     esi, VP8_SPLIT_MV_PROBABILITY_2
    call    er_vp8_bool_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .zero
    mov     eax, 1
    er_ok
    jmp     .done
.zero:
    xor     eax, eax
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_ret

SECTION .rodata
vp8_inter_mode_context_probabilities:
    db 7, 1, 1, 143
    db 14, 18, 14, 107
    db 135, 64, 57, 68
    db 60, 56, 128, 65
    db 159, 134, 128, 34
    db 234, 188, 128, 28
vp8_split_mv_partitions:
    db 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1
    db 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1
    db 0, 0, 1, 1, 0, 0, 1, 1, 2, 2, 3, 3, 2, 2, 3, 3
    db 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15
vp8_intra4_keyframe_probabilities:
    db 231, 120, 48,  89,  115, 113, 120, 152, 112, 152, 179, 64,  126, 170, 118, 46,  70,  95
    db 175, 69,  143, 80,  85,  82,  72,  155, 103, 56,  58,  10,  171, 218, 189, 17,  13,  152
    db 144, 71,  10,  38,  171, 213, 144, 34,  26,  114, 26,  17,  163, 44,  195, 21,  10,  173
    db 121, 24,  80,  195, 26,  62,  44,  64,  85,  170, 46,  55,  19,  136, 160, 33,  206, 71
    db 63,  20,  8,   114, 114, 208, 12,  9,   226, 81,  40,  11,  96,  182, 84,  29,  16,  36
    db 134, 183, 89,  137, 98,  101, 106, 165, 148, 72,  187, 100, 130, 157, 111, 32,  75,  80
    db 66,  102, 167, 99,  74,  62,  40,  234, 128, 41,  53,  9,   178, 241, 141, 26,  8,   107
    db 104, 79,  12,  27,  217, 255, 87,  17,  7,   74,  43,  26,  146, 73,  166, 49,  23,  157
    db 65,  38,  105, 160, 51,  52,  31,  115, 128, 87,  68,  71,  44,  114, 51,  15,  186, 23
    db 47,  41,  14,  110, 182, 183, 21,  17,  194, 66,  45,  25,  102, 197, 189, 23,  18,  22
    db 88,  88,  147, 150, 42,  46,  45,  196, 205, 43,  97,  183, 117, 85,  38,  35,  179, 61
    db 39,  53,  200, 87,  26,  21,  43,  232, 171, 56,  34,  51,  104, 114, 102, 29,  93,  77
    db 107, 54,  32,  26,  51,  1,   81,  43,  31,  39,  28,  85,  171, 58,  165, 90,  98,  64
    db 34,  22,  116, 206, 23,  34,  43,  166, 73,  68,  25,  106, 22,  64,  171, 36,  225, 114
    db 34,  19,  21,  102, 132, 188, 16,  76,  124, 62,  18,  78,  95,  85,  57,  50,  48,  51
    db 193, 101, 35,  159, 215, 111, 89,  46,  111, 60,  148, 31,  172, 219, 228, 21,  18,  111
    db 112, 113, 77,  85,  179, 255, 38,  120, 114, 40,  42,  1,   196, 245, 209, 10,  25,  109
    db 100, 80,  8,   43,  154, 1,   51,  26,  71,  88,  43,  29,  140, 166, 213, 37,  43,  154
    db 61,  63,  30,  155, 67,  45,  68,  1,   209, 142, 78,  78,  16,  255, 128, 34,  197, 171
    db 41,  40,  5,   102, 211, 183, 4,   1,   221, 51,  50,  17,  168, 209, 192, 23,  25,  82
    db 125, 98,  42,  88,  104, 85,  117, 175, 82,  95,  84,  53,  89,  128, 100, 113, 101, 45
    db 75,  79,  123, 47,  51,  128, 81,  171, 1,   57,  17,  5,   71,  102, 57,  53,  41,  49
    db 115, 21,  2,   10,  102, 255, 166, 23,  6,   38,  33,  13,  121, 57,  73,  26,  1,   85
    db 41,  10,  67,  138, 77,  110, 90,  47,  114, 101, 29,  16,  10,  85,  128, 101, 196, 26
    db 57,  18,  10,  102, 102, 213, 34,  20,  43,  117, 20,  15,  36,  163, 128, 68,  1,   26
    db 138, 31,  36,  171, 27,  166, 38,  44,  229, 67,  87,  58,  169, 82,  115, 26,  59,  179
    db 63,  59,  90,  180, 59,  166, 93,  73,  154, 40,  40,  21,  116, 143, 209, 34,  39,  175
    db 57,  46,  22,  24,  128, 1,   54,  17,  37,  47,  15,  16,  183, 34,  223, 49,  45,  183
    db 46,  17,  33,  183, 6,   98,  15,  32,  183, 65,  32,  73,  115, 28,  128, 23,  128, 205
    db 40,  3,   9,   115, 51,  192, 18,  6,   223, 87,  37,  9,   115, 59,  77,  64,  21,  47
    db 104, 55,  44,  218, 9,   54,  53,  130, 226, 64,  90,  70,  205, 40,  41,  23,  26,  57
    db 54,  57,  112, 184, 5,   41,  38,  166, 213, 30,  34,  26,  133, 152, 116, 10,  32,  134
    db 75,  32,  12,  51,  192, 255, 160, 43,  51,  39,  19,  53,  221, 26,  114, 32,  73,  255
    db 31,  9,   65,  234, 2,   15,  1,   118, 73,  88,  31,  35,  67,  102, 85,  55,  186, 85
    db 56,  21,  23,  111, 59,  205, 45,  37,  192, 55,  38,  70,  124, 73,  102, 1,   34,  98
    db 102, 61,  71,  37,  34,  53,  31,  243, 192, 69,  60,  71,  38,  73,  119, 28,  222, 37
    db 68,  45,  128, 34,  1,   47,  11,  245, 171, 62,  17,  19,  70,  146, 85,  55,  62,  70
    db 75,  15,  9,   9,   64,  255, 184, 119, 16,  37,  43,  37,  154, 100, 163, 85,  160, 1
    db 63,  9,   92,  136, 28,  64,  32,  201, 85,  86,  6,   28,  5,   64,  255, 25,  248, 1
    db 56,  8,   17,  132, 137, 255, 55,  116, 128, 58,  15,  20,  82,  135, 57,  26,  121, 40
    db 164, 50,  31,  137, 154, 133, 25,  35,  218, 51,  103, 44,  131, 131, 123, 31,  6,   158
    db 86,  40,  64,  135, 148, 224, 45,  183, 128, 22,  26,  17,  131, 240, 154, 14,  1,   209
    db 83,  12,  13,  54,  192, 255, 68,  47,  28,  45,  16,  21,  91,  64,  222, 7,   1,   197
    db 56,  21,  39,  155, 60,  138, 23,  102, 213, 85,  26,  85,  85,  128, 128, 32,  146, 171
    db 18,  11,  7,   63,  144, 171, 4,   4,   246, 35,  27,  10,  146, 174, 171, 12,  26,  128
    db 190, 80,  35,  99,  180, 80,  126, 54,  45,  85,  126, 47,  87,  176, 51,  41,  20,  32
    db 101, 75,  128, 139, 118, 146, 116, 128, 85,  56,  41,  15,  176, 236, 85,  37,  9,   62
    db 146, 36,  19,  30,  171, 255, 97,  27,  20,  71,  30,  17,  119, 118, 255, 17,  18,  138
    db 101, 38,  60,  138, 55,  70,  43,  26,  142, 138, 45,  61,  62,  219, 1,   81,  188, 64
    db 32,  41,  20,  117, 151, 142, 20,  21,  163, 112, 19,  12,  61,  195, 128, 48,  4,   24
vp8_dc_quant:
    dw 4, 5, 6, 7, 8, 9, 10, 10, 11, 12, 13, 14, 15, 16, 17, 17
    dw 18, 19, 20, 20, 21, 21, 22, 22, 23, 23, 24, 25, 25, 26, 27, 28
    dw 29, 30, 31, 32, 33, 34, 35, 36, 37, 37, 38, 39, 40, 41, 42, 43
    dw 44, 45, 46, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58
    dw 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 70, 71, 72, 73
    dw 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89
    dw 91, 93, 95, 96, 98, 100, 101, 102, 104, 106, 108, 110, 112, 114, 116, 118
    dw 122, 124, 126, 128, 130, 132, 134, 136, 138, 140, 143, 145, 148, 151, 154, 157
vp8_ac_quant:
    dw 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19
    dw 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35
    dw 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51
    dw 52, 53, 54, 55, 56, 57, 58, 60, 62, 64, 66, 68, 70, 72, 74, 76
    dw 78, 80, 82, 84, 86, 88, 90, 92, 94, 96, 98, 100, 102, 104, 106, 108
    dw 110, 112, 114, 116, 119, 122, 125, 128, 131, 134, 137, 140, 143, 146, 149, 152
    dw 155, 158, 161, 164, 167, 170, 173, 177, 181, 185, 189, 193, 197, 201, 205, 209
    dw 213, 217, 221, 225, 229, 234, 239, 245, 249, 254, 259, 264, 269, 274, 279, 284
vp8_coeff_bands: db 0, 1, 2, 3, 6, 4, 5, 6, 6, 6, 6, 6, 6, 6, 6, 7, 0
vp8_zigzag: db 0, 1, 4, 8, 5, 2, 3, 6, 9, 12, 13, 10, 7, 11, 14, 15
vp8_coeff_cat3_probs: db 173, 148, 140
vp8_coeff_cat4_probs: db 176, 155, 140, 135
vp8_coeff_cat5_probs: db 180, 157, 141, 134, 130
vp8_coeff_cat6_probs: db 254, 254, 243, 230, 196, 177, 153, 140, 133, 130, 129
vp8_subpixel_filters:
    dw 0, 0, 128, 0, 0, 0
    dw 0, -6, 123, 12, -1, 0
    dw 2, -11, 108, 36, -8, 1
    dw 0, -9, 93, 50, -6, 0
    dw 3, -16, 77, 77, -16, 3
    dw 0, -6, 50, 93, -9, 0
    dw 1, -8, 36, 108, -11, 2
    dw 0, -1, 12, 123, -6, 0
vp8_intra4_right_down_table:
    db 0, 3, 1, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 3, 2, VP8_INTRA4_TABLE_KIND_AVG3
    db 0, 2, 2, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 3, 3, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 2, 3, VP8_INTRA4_TABLE_KIND_AVG3
    db 0, 1, 3, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 3, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 2, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 1, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 0, 0, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 2, 5, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 1, 5, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 0, 5, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 1, 6, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 0, 6, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 0, 7, VP8_INTRA4_TABLE_KIND_AVG3
vp8_intra4_vertical_right_table:
    db 0, 3, 2, VP8_INTRA4_TABLE_KIND_AVG3
    db 0, 2, 3, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 3, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 0, 1, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 2, 4, VP8_INTRA4_TABLE_KIND_AVG2
    db 0, 0, 4, VP8_INTRA4_TABLE_KIND_AVG2
    db 2, 3, 5, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 1, 5, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 2, 5, VP8_INTRA4_TABLE_KIND_AVG2
    db 1, 0, 5, VP8_INTRA4_TABLE_KIND_AVG2
    db 3, 3, 6, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 1, 6, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 2, 6, VP8_INTRA4_TABLE_KIND_AVG2
    db 2, 0, 6, VP8_INTRA4_TABLE_KIND_AVG2
    db 3, 1, 7, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 0, 7, VP8_INTRA4_TABLE_KIND_AVG2
vp8_intra4_horizontal_down_table:
    db 0, 3, 0, VP8_INTRA4_TABLE_KIND_AVG2
    db 1, 3, 1, VP8_INTRA4_TABLE_KIND_AVG3
    db 0, 2, 1, VP8_INTRA4_TABLE_KIND_AVG2
    db 2, 3, 1, VP8_INTRA4_TABLE_KIND_AVG2
    db 1, 2, 2, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 3, 2, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 2, 2, VP8_INTRA4_TABLE_KIND_AVG2
    db 0, 1, 2, VP8_INTRA4_TABLE_KIND_AVG2
    db 3, 2, 3, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 1, 3, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 1, 3, VP8_INTRA4_TABLE_KIND_AVG2
    db 0, 0, 3, VP8_INTRA4_TABLE_KIND_AVG2
    db 3, 1, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 1, 0, 4, VP8_INTRA4_TABLE_KIND_AVG3
    db 2, 0, 5, VP8_INTRA4_TABLE_KIND_AVG3
    db 3, 0, 6, VP8_INTRA4_TABLE_KIND_AVG3
vp8_coeff_default_probabilities:
    db 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128
    db 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 253, 136, 254, 255, 228, 219, 128, 128, 128, 128, 128
    db 189, 129, 242, 255, 227, 213, 255, 219, 128, 128, 128, 106, 126, 227, 252, 214, 209, 255, 255, 128, 128, 128
    db 1, 98, 248, 255, 236, 226, 255, 255, 128, 128, 128, 181, 133, 238, 254, 221, 234, 255, 154, 128, 128, 128
    db 78, 134, 202, 247, 198, 180, 255, 219, 128, 128, 128, 1, 185, 249, 255, 243, 255, 128, 128, 128, 128, 128
    db 184, 150, 247, 255, 236, 224, 128, 128, 128, 128, 128, 77, 110, 216, 255, 236, 230, 128, 128, 128, 128, 128
    db 1, 101, 251, 255, 241, 255, 128, 128, 128, 128, 128, 170, 139, 241, 252, 236, 209, 255, 255, 128, 128, 128
    db 37, 116, 196, 243, 228, 255, 255, 255, 128, 128, 128, 1, 204, 254, 255, 245, 255, 128, 128, 128, 128, 128
    db 207, 160, 250, 255, 238, 128, 128, 128, 128, 128, 128, 102, 103, 231, 255, 211, 171, 128, 128, 128, 128, 128
    db 1, 152, 252, 255, 240, 255, 128, 128, 128, 128, 128, 177, 135, 243, 255, 234, 225, 128, 128, 128, 128, 128
    db 80, 129, 211, 255, 194, 224, 128, 128, 128, 128, 128, 1, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128
    db 246, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128
    db 198, 35, 237, 223, 193, 187, 162, 160, 145, 155, 62, 131, 45, 198, 221, 172, 176, 220, 157, 252, 221, 1
    db 68, 47, 146, 208, 149, 167, 221, 162, 255, 223, 128, 1, 149, 241, 255, 221, 224, 255, 255, 128, 128, 128
    db 184, 141, 234, 253, 222, 220, 255, 199, 128, 128, 128, 81, 99, 181, 242, 176, 190, 249, 202, 255, 255, 128
    db 1, 129, 232, 253, 214, 197, 242, 196, 255, 255, 128, 99, 121, 210, 250, 201, 198, 255, 202, 128, 128, 128
    db 23, 91, 163, 242, 170, 187, 247, 210, 255, 255, 128, 1, 200, 246, 255, 234, 255, 128, 128, 128, 128, 128
    db 109, 178, 241, 255, 231, 245, 255, 255, 128, 128, 128, 44, 130, 201, 253, 205, 192, 255, 255, 128, 128, 128
    db 1, 132, 239, 251, 219, 209, 255, 165, 128, 128, 128, 94, 136, 225, 251, 218, 190, 255, 255, 128, 128, 128
    db 22, 100, 174, 245, 186, 161, 255, 199, 128, 128, 128, 1, 182, 249, 255, 232, 235, 128, 128, 128, 128, 128
    db 124, 143, 241, 255, 227, 234, 128, 128, 128, 128, 128, 35, 77, 181, 251, 193, 211, 255, 205, 128, 128, 128
    db 1, 157, 247, 255, 236, 231, 255, 255, 128, 128, 128, 121, 141, 235, 255, 225, 227, 255, 255, 128, 128, 128
    db 45, 99, 188, 251, 195, 217, 255, 224, 128, 128, 128, 1, 1, 251, 255, 213, 255, 128, 128, 128, 128, 128
    db 203, 1, 248, 255, 255, 128, 128, 128, 128, 128, 128, 137, 1, 177, 255, 224, 255, 128, 128, 128, 128, 128
    db 253, 9, 248, 251, 207, 208, 255, 192, 128, 128, 128, 175, 13, 224, 243, 193, 185, 249, 198, 255, 255, 128
    db 73, 17, 171, 221, 161, 179, 236, 167, 255, 234, 128, 1, 95, 247, 253, 212, 183, 255, 255, 128, 128, 128
    db 239, 90, 244, 250, 211, 209, 255, 255, 128, 128, 128, 155, 77, 195, 248, 188, 195, 255, 255, 128, 128, 128
    db 1, 24, 239, 251, 218, 219, 255, 205, 128, 128, 128, 201, 51, 219, 255, 196, 186, 128, 128, 128, 128, 128
    db 69, 46, 190, 239, 201, 218, 255, 228, 128, 128, 128, 1, 191, 251, 255, 255, 128, 128, 128, 128, 128, 128
    db 223, 165, 249, 255, 213, 255, 128, 128, 128, 128, 128, 141, 124, 248, 255, 255, 128, 128, 128, 128, 128, 128
    db 1, 16, 248, 255, 255, 128, 128, 128, 128, 128, 128, 190, 36, 230, 255, 236, 255, 128, 128, 128, 128, 128
    db 149, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128, 1, 226, 255, 128, 128, 128, 128, 128, 128, 128, 128
    db 247, 192, 255, 128, 128, 128, 128, 128, 128, 128, 128, 240, 128, 255, 128, 128, 128, 128, 128, 128, 128, 128
    db 1, 134, 252, 255, 255, 128, 128, 128, 128, 128, 128, 213, 62, 250, 255, 255, 128, 128, 128, 128, 128, 128
    db 55, 93, 255, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128
    db 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128, 128
    db 202, 24, 213, 235, 186, 191, 220, 160, 240, 175, 255, 126, 38, 182, 232, 169, 184, 228, 174, 255, 187, 128
    db 61, 46, 138, 219, 151, 178, 240, 170, 255, 216, 128, 1, 112, 230, 250, 199, 191, 247, 159, 255, 255, 128
    db 166, 109, 228, 252, 211, 215, 255, 174, 128, 128, 128, 39, 77, 162, 232, 172, 180, 245, 178, 255, 255, 128
    db 1, 52, 220, 246, 198, 199, 249, 220, 255, 255, 128, 124, 74, 191, 243, 183, 193, 250, 221, 255, 255, 128
    db 24, 71, 130, 219, 154, 170, 243, 182, 255, 255, 128, 1, 182, 225, 249, 219, 240, 255, 224, 128, 128, 128
    db 149, 150, 226, 252, 216, 205, 255, 171, 128, 128, 128, 28, 108, 170, 242, 183, 194, 254, 223, 255, 255, 128
    db 1, 81, 230, 252, 204, 203, 255, 192, 128, 128, 128, 123, 102, 209, 247, 188, 196, 255, 233, 128, 128, 128
    db 20, 95, 153, 243, 164, 173, 255, 203, 128, 128, 128, 1, 222, 248, 255, 216, 213, 128, 128, 128, 128, 128
    db 168, 175, 246, 252, 235, 205, 255, 255, 128, 128, 128, 47, 116, 215, 255, 211, 212, 255, 255, 128, 128, 128
    db 1, 121, 236, 253, 212, 214, 255, 255, 128, 128, 128, 141, 84, 213, 252, 201, 202, 255, 219, 128, 128, 128
    db 42, 80, 160, 240, 162, 185, 255, 205, 128, 128, 128, 1, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128
    db 244, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128, 238, 1, 255, 128, 128, 128, 128, 128, 128, 128, 128
vp8_coeff_update_probabilities:
    dd 0xb00021, 0xf60022, 0xdf002c, 0xf1002d
    dd 0xfc002e, 0xf90037, 0xfd0038, 0xfd0039
    dd 0xf40043, 0xfc0044, 0xea004d, 0xfe004e
    dd 0xfe004f, 0xfd0058, 0xf60064, 0xfe0065
    dd 0xef006e, 0xfd006f, 0xfe0070, 0xfe0079
    dd 0xfe007b, 0xf80085, 0xfe0086, 0xfb008f
    dd 0xfe0091, 0xfd00a6, 0xfe00a7, 0xfb00b0
    dd 0xfe00b1, 0xfe00b2, 0xfe00bb, 0xfe00bd
    dd 0xfe00c7, 0xfd00c8, 0xfe00ca, 0xfa00d1
    dd 0xfe00d3, 0xfe00d5, 0xfe00dc, 0xd90108
    dd 0xe10113, 0xfc0114, 0xf10115, 0xfd0116
    dd 0xfe0119, 0xea011e, 0xfa011f, 0xf10120
    dd 0xfa0121, 0xfd0122, 0xfd0124, 0xfe0125
    dd 0xfe012a, 0xdf0134, 0xfe0135, 0xfe0136
    dd 0xee013f, 0xfd0140, 0xfe0141, 0xfe0142
    dd 0xf8014b, 0xfe014c, 0xf90155, 0xfe0156
    dd 0xfd016c, 0xf70176, 0xfe0177, 0xfd018d
    dd 0xfe018e, 0xfc0197, 0xfe01ae, 0xfe01af
    dd 0xfd01b8, 0xfe01cf, 0xfd01d0, 0xfa01d9
    dd 0xfe01e4, 0xba0210, 0xfb0211, 0xfa0212
    dd 0xea021b, 0xfb021c, 0xf4021d, 0xfe021e
    dd 0xfb0226, 0xfb0227, 0xf30228, 0xfd0229
    dd 0xfe022a, 0xfe022c, 0xfd0232, 0xfe0233
    dd 0xec023c, 0xfd023d, 0xfe023e, 0xfb0247
    dd 0xfd0248, 0xfd0249, 0xfe024a, 0xfe024b
    dd 0xfe0253, 0xfe0254, 0xfe025d, 0xfe025e
    dd 0xfe025f, 0xfe0274, 0xfe027e, 0xfe027f
    dd 0xfe0289, 0xfe029f, 0xf80318, 0xfa0323
    dd 0xfe0324, 0xfc0325, 0xfe0326, 0xf8032e
    dd 0xfe032f, 0xf90330, 0xfd0331, 0xfd033a
    dd 0xfd033b, 0xf60344, 0xfd0345, 0xfd0346
    dd 0xfc034f, 0xfe0350, 0xfb0351, 0xfe0352
    dd 0xfe0353, 0xfe035b, 0xfc035c, 0xf80365
    dd 0xfe0366, 0xfd0367, 0xfd0370, 0xfe0372
    dd 0xfe0373, 0xfb037c, 0xfe037d, 0xf50386
    dd 0xfb0387, 0xfe0388, 0xfd0391, 0xfd0392
    dd 0xfe0393, 0xfb039d, 0xfd039e, 0xfc03a7
    dd 0xfd03a8, 0xfe03a9, 0xfe03b3, 0xfc03be
    dd 0xf903c8, 0xfe03ca, 0xfe03d5, 0xfd03e0
    dd 0xfa03e9, 0xfe040a
