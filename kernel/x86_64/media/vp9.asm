; EdgeRun VP9 uncompressed frame header helpers — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/vp9_constants.inc"

extern er_vp8_bool_reader_init
extern er_vp8_bool_read
extern er_vp8_bool_read_flag
extern er_vp8_bool_read_literal

SECTION .text

; er_vp9_parse_frame_header(buf, len, desc) -> eax=header bytes consumed, rdx=error
; Parses VP9 profile, show-existing-frame, and profile-0 key/inter frame header prefix.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp9_parse_frame_header
    er_push rbx, r12
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero esi, .no_data
    mov     r12, rdx
    movzx   ebx, byte [rdi]
    mov     eax, ebx
    and     eax, VP9_FRAME_MARKER_MASK
    cmp     eax, VP9_FRAME_MARKER
    jne     .corrupt
    mov     [r12 + VP9_HEADER_DESC_MARKER], al
    xor     ecx, ecx
    test    ebx, VP9_PROFILE_LOW_MASK
    setnz   cl
    xor     eax, eax
    test    ebx, VP9_PROFILE_HIGH_MASK
    setnz   al
    shl     eax, 1
    or      eax, ecx
    mov     [r12 + VP9_HEADER_DESC_PROFILE], al
    cmp     eax, VP9_PROFILE_MAX
    ja      .unsupported
    cmp     eax, VP9_PROFILE_MAX
    jne     .profile_ok
    test    ebx, VP9_PROFILE_RESERVED_MASK
    jnz     .unsupported
.profile_ok:
    xor     eax, eax
    test    ebx, VP9_SHOW_EXISTING_MASK
    setnz   al
    mov     [r12 + VP9_HEADER_DESC_SHOW_EXISTING], al
    er_check_nonzero eax, .show_existing
    mov     byte [r12 + VP9_HEADER_DESC_EXISTING_FRAME_IDX], 0
    mov     eax, ebx
    and     eax, VP9_FRAME_TYPE_MASK
    shr     eax, VP9_FRAME_TYPE_SHIFT
    mov     [r12 + VP9_HEADER_DESC_FRAME_TYPE], al
    xor     eax, eax
    test    ebx, VP9_SHOW_FRAME_MASK
    setnz   al
    mov     [r12 + VP9_HEADER_DESC_SHOW_FRAME], al
    xor     eax, eax
    test    ebx, VP9_ERROR_RESILIENT_MASK
    setnz   al
    mov     [r12 + VP9_HEADER_DESC_ERROR_RESILIENT], al
    cmp     byte [r12 + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_KEY
    je      .key_frame
    cmp     byte [r12 + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_INTER
    jne     .corrupt
    mov     word [r12 + VP9_HEADER_DESC_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_HEIGHT], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], 0
    mov     eax, VP9_INTER_HEADER_SIZE
    er_ok
    jmp     .done
.show_existing:
    mov     eax, ebx
    and     eax, VP9_SHOW_EXISTING_FRAME_INDEX_MASK
    shr     eax, VP9_SHOW_EXISTING_FRAME_INDEX_SHIFT
    mov     [r12 + VP9_HEADER_DESC_EXISTING_FRAME_IDX], al
    mov     byte [r12 + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_INTER
    mov     byte [r12 + VP9_HEADER_DESC_SHOW_FRAME], 1
    mov     byte [r12 + VP9_HEADER_DESC_ERROR_RESILIENT], 0
    mov     word [r12 + VP9_HEADER_DESC_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_HEIGHT], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], 0
    mov     eax, VP9_SHOW_EXISTING_HEADER_SIZE
    er_ok
    jmp     .done
.key_frame:
    cmp     byte [r12 + VP9_HEADER_DESC_PROFILE], 0
    jne     .unsupported
    cmp     esi, VP9_KEY_HEADER_SIZE
    jb      .no_data
    cmp     byte [rdi + VP9_SYNC_CODE_OFFSET], VP9_SYNC_CODE_0
    jne     .corrupt
    cmp     byte [rdi + VP9_SYNC_CODE_OFFSET + 1], VP9_SYNC_CODE_1
    jne     .corrupt
    cmp     byte [rdi + VP9_SYNC_CODE_OFFSET + 2], VP9_SYNC_CODE_2
    jne     .corrupt
    movzx   eax, byte [rdi + VP9_KEY_COLOR_BYTE]
    and     eax, VP9_KEY_COLOR_SPACE_MASK
    cmp     eax, VP9_KEY_COLOR_SPACE_MASK
    je      .corrupt
    movzx   eax, byte [rdi + VP9_KEY_COLOR_BYTE]
    shr     eax, VP9_KEY_FIELD_LOW_SHIFT
    movzx   ecx, byte [rdi + VP9_KEY_WIDTH_MID_BYTE]
    shl     ecx, VP9_KEY_FIELD_LOW_SHIFT
    or      eax, ecx
    movzx   ecx, byte [rdi + VP9_KEY_WIDTH_HIGH_HEIGHT_LOW_BYTE]
    and     ecx, VP9_KEY_LOW_NIBBLE_MASK
    shl     ecx, VP9_KEY_FIELD_HIGH_SHIFT
    or      eax, ecx
    inc     eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_WIDTH], ax
    movzx   eax, byte [rdi + VP9_KEY_WIDTH_HIGH_HEIGHT_LOW_BYTE]
    shr     eax, VP9_KEY_FIELD_LOW_SHIFT
    movzx   ecx, byte [rdi + VP9_KEY_HEIGHT_MID_BYTE]
    shl     ecx, VP9_KEY_FIELD_LOW_SHIFT
    or      eax, ecx
    movzx   ecx, byte [rdi + VP9_KEY_HEIGHT_HIGH_RENDER_FLAG_BYTE]
    and     ecx, VP9_KEY_LOW_NIBBLE_MASK
    shl     ecx, VP9_KEY_FIELD_HIGH_SHIFT
    or      eax, ecx
    inc     eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_HEIGHT], ax
    test    byte [rdi + VP9_KEY_HEIGHT_HIGH_RENDER_FLAG_BYTE], VP9_KEY_RENDER_DIFF_MASK
    jnz     .key_render_size
    movzx   eax, word [r12 + VP9_HEADER_DESC_WIDTH]
    mov     [r12 + VP9_HEADER_DESC_RENDER_WIDTH], ax
    movzx   eax, word [r12 + VP9_HEADER_DESC_HEIGHT]
    mov     [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], ax
    mov     eax, VP9_KEY_HEADER_SIZE
    er_ok
    jmp     .done
.key_render_size:
    cmp     esi, VP9_KEY_HEADER_RENDER_SIZE
    jb      .no_data
    movzx   eax, byte [rdi + VP9_KEY_HEIGHT_HIGH_RENDER_FLAG_BYTE]
    shr     eax, VP9_KEY_RENDER_FIELD_LOW_SHIFT
    movzx   ecx, byte [rdi + VP9_KEY_RENDER_WIDTH_MID_BYTE]
    shl     ecx, VP9_KEY_RENDER_FIELD_MID_SHIFT
    or      eax, ecx
    movzx   ecx, byte [rdi + VP9_KEY_RENDER_WIDTH_HIGH_HEIGHT_LOW_BYTE]
    and     ecx, VP9_KEY_LOW_FIVE_MASK
    shl     ecx, VP9_KEY_RENDER_FIELD_HIGH_SHIFT
    or      eax, ecx
    inc     eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_RENDER_WIDTH], ax
    movzx   eax, byte [rdi + VP9_KEY_RENDER_WIDTH_HIGH_HEIGHT_LOW_BYTE]
    shr     eax, VP9_KEY_RENDER_FIELD_LOW_SHIFT
    movzx   ecx, byte [rdi + VP9_KEY_RENDER_HEIGHT_MID_BYTE]
    shl     ecx, VP9_KEY_RENDER_FIELD_MID_SHIFT
    or      eax, ecx
    movzx   ecx, byte [rdi + VP9_KEY_RENDER_HEIGHT_HIGH_BYTE]
    and     ecx, VP9_KEY_LOW_FIVE_MASK
    shl     ecx, VP9_KEY_RENDER_FIELD_HIGH_SHIFT
    or      eax, ecx
    inc     eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], ax
    mov     eax, VP9_KEY_HEADER_RENDER_SIZE
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
    er_pop  rbx, r12
    er_ret

; er_vp9_is_key_frame(buf, len) -> eax=1 key frame, eax=0 otherwise, rdx=error
; rdi=buf, esi=len
er_fn er_vp9_is_key_frame
    er_stack_alloc VP9_HEADER_DESC_SIZE
    mov     rdx, rsp
    call    er_vp9_parse_frame_header
    er_check_nonzero edx, .done
    cmp     byte [rsp + VP9_HEADER_DESC_SHOW_EXISTING], 0
    jne     .not_key
    cmp     byte [rsp + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_KEY
    sete    al
    movzx   eax, al
    jmp     .ok
.not_key:
    xor     eax, eax
.ok:
    er_ok
.done:
    er_stack_free VP9_HEADER_DESC_SIZE
    er_ret

; er_vp9_read_tx_mode(reader) -> eax=tx_mode, rdx=error
; VP9 compressed header tx_mode syntax: literal(2), plus one flag when value is 3.
; rdi=reader
er_fn er_vp9_read_tx_mode
    er_push rbx, r12
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     esi, VP9_TX_MODE_LITERAL_BITS
    call    er_vp8_bool_read_literal
    er_check_nonzero edx, .done
    mov     ebx, eax
    cmp     ebx, VP9_TX_MODE_ALLOW_32X32
    jne     .ok
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    er_check_nonzero edx, .done
    add     ebx, eax
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12
    er_ret

; er_vp9_parse_tx_size_probability_updates(reader, out)
; -> eax=number of updated transform-size probabilities, rdx=error
; out receives VP9_TX_PROB_UPDATE_TOTAL bytes. Zero means no update at that
; position; non-zero values are the raw 7-bit update codes from the bitstream.
; rdi=reader, rsi=out
er_fn er_vp9_parse_tx_size_probability_updates
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rsi, .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     ebx, ebx
    xor     r14d, r14d
.loop:
    cmp     ebx, VP9_TX_PROB_UPDATE_TOTAL
    jae     .ok
    mov     byte [r13 + rbx], 0
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    er_check_nonzero edx, .done
    er_check_zero eax, .next
    mov     rdi, r12
    mov     esi, VP9_TX_PROB_UPDATE_BITS
    call    er_vp8_bool_read_literal
    er_check_nonzero edx, .done
    mov     [r13 + rbx], al
    inc     r14d
.next:
    inc     ebx
    jmp     .loop
.ok:
    mov     eax, r14d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp9_tx_mode_max_tx_size(tx_mode) -> eax=max tx size, rdx=error
; edi=VP9_TX_MODE_*.
er_fn er_vp9_tx_mode_max_tx_size
    cmp     edi, VP9_TX_MODE_ONLY_4X4
    je      .only4
    cmp     edi, VP9_TX_MODE_ALLOW_8X8
    je      .allow8
    cmp     edi, VP9_TX_MODE_ALLOW_16X16
    je      .allow16
    cmp     edi, VP9_TX_MODE_ALLOW_32X32
    je      .allow32
    cmp     edi, VP9_TX_MODE_SELECT
    je      .allow32
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.only4:
    mov     eax, VP9_TX_SIZE_4X4
    er_ok
    er_ret
.allow8:
    mov     eax, VP9_TX_SIZE_8X8
    er_ok
    er_ret
.allow16:
    mov     eax, VP9_TX_SIZE_16X16
    er_ok
    er_ret
.allow32:
    mov     eax, VP9_TX_SIZE_32X32
    er_ok
    er_ret

; er_vp9_parse_coef_probability_updates(reader, tx_mode, desc)
; -> eax=updated coefficient probability count, rdx=error
; Parses the leading read_coef_probs() update flag. Streams that request
; coefficient remapping fail explicitly until VP9 subexp probability remap is
; implemented.
; rdi=reader, esi=tx_mode, rdx=compressed desc
er_fn er_vp9_parse_coef_probability_updates
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdi
    mov     r13, rdx
    mov     edi, esi
    call    er_vp9_tx_mode_max_tx_size
    er_check_nonzero edx, .done
    mov     rdi, r12
    call    er_vp8_bool_read_flag
    er_check_nonzero edx, .done
    mov     [r13 + VP9_COMPRESSED_HEADER_COEF_UPDATE_FLAG], eax
    mov     dword [r13 + VP9_COMPRESSED_HEADER_COEF_UPDATE_COUNT], 0
    er_check_nonzero eax, .unsupported
    xor     eax, eax
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_vp9_inv_map(delta) -> eax=remapped delta, rdx=error
; Algorithmic form of the VP9 inv_map_table permutation.
; edi=delta in range 0..254.
er_fn er_vp9_inv_map
    cmp     edi, VP9_INV_MAP_LAST_INDEX
    ja      .invalid_param
    cmp     edi, VP9_INV_MAP_FAST_COUNT
    jae     .slow
    mov     eax, edi
    imul    eax, VP9_INV_MAP_FAST_STEP
    add     eax, VP9_INV_MAP_FAST_FIRST
    er_ok
    er_ret
.slow:
    cmp     edi, VP9_INV_MAP_LAST_INDEX
    jne     .search
    mov     eax, VP9_INV_MAP_LAST_VALUE
    er_ok
    er_ret
.search:
    mov     r8d, edi
    sub     r8d, VP9_INV_MAP_FAST_COUNT
    xor     ecx, ecx
    xor     eax, eax
.loop:
    inc     eax
    cmp     eax, VP9_INV_MAP_LAST_VALUE
    ja      .invalid_param
    mov     edx, eax
    sub     edx, VP9_INV_MAP_FAST_FIRST
    js      .candidate
    mov     r9d, edx
    mov     edx, r9d
    mov     r10d, VP9_INV_MAP_FAST_STEP
    div     r10d
    er_check_zero edx, .loop
.candidate:
    cmp     ecx, r8d
    je      .ok
    inc     ecx
    jmp     .loop
.ok:
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_vp9_inv_recenter_nonneg(v, m) -> eax=value, rdx=error
; edi=v, esi=m.
er_fn er_vp9_inv_recenter_nonneg
    mov     eax, esi
    shl     eax, 1
    cmp     edi, eax
    ja      .return_v
    test    edi, 1
    jnz     .odd
    mov     eax, edi
    shr     eax, 1
    add     eax, esi
    er_ok
    er_ret
.odd:
    mov     eax, edi
    inc     eax
    shr     eax, 1
    mov     ecx, esi
    sub     ecx, eax
    mov     eax, ecx
    er_ok
    er_ret
.return_v:
    mov     eax, edi
    er_ok
    er_ret

; er_vp9_inv_remap_prob(delta, prob) -> eax=probability, rdx=error
; edi=deltaProb, esi=current probability.
er_fn er_vp9_inv_remap_prob
    er_push rbx, r12
    er_check_zero esi, .invalid_param
    cmp     esi, VP9_PROBABILITY_MAX
    ja      .invalid_param
    mov     ebx, esi
    call    er_vp9_inv_map
    er_check_nonzero edx, .done
    mov     r12d, eax
    dec     ebx
    mov     eax, ebx
    shl     eax, 1
    cmp     eax, VP9_PROBABILITY_MAX
    ja      .high
    mov     edi, r12d
    mov     esi, ebx
    call    er_vp9_inv_recenter_nonneg
    er_check_nonzero edx, .done
    inc     eax
    er_ok
    jmp     .done
.high:
    mov     esi, VP9_PROBABILITY_MAX - 1
    sub     esi, ebx
    mov     edi, r12d
    call    er_vp9_inv_recenter_nonneg
    er_check_nonzero edx, .done
    mov     ecx, VP9_PROBABILITY_MAX
    sub     ecx, eax
    mov     eax, ecx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12
    er_ret

; er_vp9_parse_skip_probability_updates(reader, desc)
; -> eax=updated skip probability count, rdx=error
; rdi=reader, rsi=compressed desc
er_fn er_vp9_parse_skip_probability_updates
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rsi, .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    xor     ebx, ebx
    xor     r14d, r14d
.loop:
    cmp     ebx, VP9_SKIP_CONTEXTS
    jae     .ok
    mov     byte [r13 + VP9_COMPRESSED_HEADER_SKIP_UPDATES + rbx], 0
    mov     rdi, r12
    mov     esi, VP9_DIFF_UPDATE_PROB
    call    er_vp8_bool_read
    er_check_nonzero edx, .done
    er_check_nonzero eax, .unsupported
    inc     ebx
    jmp     .loop
.ok:
    mov     [r13 + VP9_COMPRESSED_HEADER_SKIP_UPDATE_COUNT], r14d
    mov     eax, r14d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp9_parse_compressed_header_prefix(buf, len, desc)
; -> eax=VP9_COMPRESSED_HEADER_SIZE, rdx=error
; Parses VP9 compressed-header tx_mode and tx-size probability update syntax,
; and leaves a live bool reader snapshot in desc for the remaining syntax.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp9_parse_compressed_header_prefix
    er_push rbx, r12
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdx
    call    er_vp8_bool_reader_init
    er_check_nonzero edx, .done
    mov     rdi, r12
    call    er_vp9_read_tx_mode
    er_check_nonzero edx, .done
    mov     [r12 + VP9_COMPRESSED_HEADER_TX_MODE], eax
    mov     dword [r12 + VP9_COMPRESSED_HEADER_TX_UPDATE_COUNT], 0
    mov     dword [r12 + VP9_COMPRESSED_HEADER_COEF_UPDATE_FLAG], 0
    mov     dword [r12 + VP9_COMPRESSED_HEADER_COEF_UPDATE_COUNT], 0
    mov     dword [r12 + VP9_COMPRESSED_HEADER_SKIP_UPDATE_COUNT], 0
    cmp     eax, VP9_TX_MODE_SELECT
    jne     .ok
    mov     rdi, r12
    lea     rsi, [r12 + VP9_COMPRESSED_HEADER_TX_UPDATES]
    call    er_vp9_parse_tx_size_probability_updates
    er_check_nonzero edx, .done
    mov     [r12 + VP9_COMPRESSED_HEADER_TX_UPDATE_COUNT], eax
.ok:
    mov     rdi, r12
    mov     esi, [r12 + VP9_COMPRESSED_HEADER_TX_MODE]
    mov     rdx, r12
    call    er_vp9_parse_coef_probability_updates
    er_check_nonzero edx, .done
    mov     rdi, r12
    mov     rsi, r12
    call    er_vp9_parse_skip_probability_updates
    er_check_nonzero edx, .done
    mov     eax, VP9_COMPRESSED_HEADER_SIZE
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12
    er_ret

; er_vp9_parse_superframe_index(buf, len, desc) -> eax=frame count, rdx=error
; No superframe index is a valid single-frame payload and returns eax=0.
; desc: frame_count u8, size_bytes u8, index_offset u32, payload_end u32, frame_sizes[8] u32.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp9_parse_superframe_index
    er_push rbx, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero esi, .no_data
    mov     r12, rdi
    mov     r13, rdx
    mov     r14d, esi
    movzx   ebx, byte [r12 + r14 - 1]
    mov     eax, ebx
    and     eax, VP9_SUPERFRAME_MARKER_MASK
    cmp     eax, VP9_SUPERFRAME_MARKER_VALUE
    jne     .not_superframe
    mov     eax, ebx
    and     eax, VP9_SUPERFRAME_FRAME_COUNT_MASK
    inc     eax
    mov     r15d, eax
    mov     eax, ebx
    and     eax, VP9_SUPERFRAME_SIZE_BYTES_MASK
    shr     eax, VP9_SUPERFRAME_SIZE_BYTES_SHIFT
    inc     eax
    mov     ecx, eax
    imul    eax, r15d
    add     eax, VP9_SUPERFRAME_MIN_INDEX_SIZE
    jc      .corrupt
    cmp     eax, r14d
    ja      .no_data
    mov     r9d, r14d
    sub     r9d, eax
    cmp     byte [r12 + r9], bl
    jne     .corrupt
    mov     [r13 + VP9_SUPERFRAME_DESC_FRAME_COUNT], r15b
    mov     [r13 + VP9_SUPERFRAME_DESC_SIZE_BYTES], cl
    mov     [r13 + VP9_SUPERFRAME_DESC_INDEX_OFFSET], r9d
    mov     [r13 + VP9_SUPERFRAME_DESC_PAYLOAD_END], r9d
    lea     r8, [r12 + r9 + 1]
    xor     r10d, r10d
    xor     r11d, r11d
.frame_loop:
    cmp     r10d, r15d
    jae     .ok
    movzx   eax, byte [r8]
    cmp     ecx, VP9_SUPERFRAME_SIZE_BYTES_1
    je      .size_done
    movzx   edx, byte [r8 + 1]
    shl     edx, 8
    or      eax, edx
    cmp     ecx, VP9_SUPERFRAME_SIZE_BYTES_2
    je      .size_done
    movzx   edx, byte [r8 + 2]
    shl     edx, 16
    or      eax, edx
    cmp     ecx, VP9_SUPERFRAME_SIZE_BYTES_3
    je      .size_done
    movzx   edx, byte [r8 + 3]
    shl     edx, 24
    or      eax, edx
.size_done:
    er_check_zero eax, .corrupt
    add     r11d, eax
    jc      .corrupt
    mov     [r13 + VP9_SUPERFRAME_DESC_FRAME_SIZES + r10 * 4], eax
    add     r8, rcx
    inc     r10d
    jmp     .frame_loop
.not_superframe:
    mov     byte [r13 + VP9_SUPERFRAME_DESC_FRAME_COUNT], 0
    mov     byte [r13 + VP9_SUPERFRAME_DESC_SIZE_BYTES], 0
    mov     [r13 + VP9_SUPERFRAME_DESC_INDEX_OFFSET], r14d
    mov     [r13 + VP9_SUPERFRAME_DESC_PAYLOAD_END], r14d
    xor     eax, eax
    er_ok
    jmp     .done
.ok:
    cmp     r11d, r9d
    jne     .corrupt
    mov     eax, r15d
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp9_validate_frame_payload(buf, len) -> eax=frame count, rdx=error
; Validates the uncompressed header for a single VP9 frame or every member of a
; VP9 superframe payload.
; rdi=buf, esi=len
er_fn er_vp9_validate_frame_payload
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP9_VALIDATE_STACK_SIZE
    er_check_zero rdi, .invalid_param
    er_check_zero esi, .no_data
    mov     r12, rdi
    mov     r13d, esi
    mov     rdx, rsp
    add     rdx, VP9_VALIDATE_STACK_SUPER
    call    er_vp9_parse_superframe_index
    er_check_nonzero edx, .done
    er_check_nonzero eax, .superframe
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + VP9_VALIDATE_STACK_HEADER]
    call    er_vp9_parse_frame_header
    er_check_nonzero edx, .done
    mov     eax, 1
    er_ok
    jmp     .done
.superframe:
    mov     r14d, eax
    xor     ebx, ebx
    xor     r15d, r15d
.frame_loop:
    cmp     ebx, r14d
    jae     .ok
    mov     esi, [rsp + VP9_VALIDATE_STACK_SUPER + VP9_SUPERFRAME_DESC_FRAME_SIZES + rbx * 4]
    mov     eax, r15d
    add     eax, esi
    jc      .corrupt
    cmp     eax, [rsp + VP9_VALIDATE_STACK_SUPER + VP9_SUPERFRAME_DESC_PAYLOAD_END]
    ja      .corrupt
    lea     rdi, [r12 + r15]
    lea     rdx, [rsp + VP9_VALIDATE_STACK_HEADER]
    call    er_vp9_parse_frame_header
    er_check_nonzero edx, .done
    mov     esi, [rsp + VP9_VALIDATE_STACK_SUPER + VP9_SUPERFRAME_DESC_FRAME_SIZES + rbx * 4]
    add     r15d, esi
    inc     ebx
    jmp     .frame_loop
.ok:
    cmp     r15d, [rsp + VP9_VALIDATE_STACK_SUPER + VP9_SUPERFRAME_DESC_PAYLOAD_END]
    jne     .corrupt
    mov     eax, r14d
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
    er_stack_free VP9_VALIDATE_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp9_ivf_is(buf, len) -> eax=1 if DKIF, else 0
; rdi=buf, esi=len
er_fn er_vp9_ivf_is
    er_check_zero rdi, .no
    cmp     esi, 4
    jb      .no
    cmp     dword [rdi], VP9_IVF_SIGNATURE
    jne     .no
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret

; er_vp9_ivf_decode_header(buf, len, desc) -> eax=VP9_IVF_HEADER_SIZE, rdx=error
; desc: codec u32, width u16, height u16, timebase_den u32,
;       timebase_num u32, frame_count u32.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp9_ivf_decode_header
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, VP9_IVF_HEADER_SIZE
    jb      .no_data
    cmp     dword [rdi], VP9_IVF_SIGNATURE
    jne     .unsupported
    cmp     word [rdi + VP9_IVF_FILE_VERSION], 0
    jne     .unsupported
    cmp     word [rdi + VP9_IVF_FILE_HEADER_LEN], VP9_IVF_HEADER_SIZE
    jne     .corrupt
    cmp     dword [rdi + VP9_IVF_FILE_CODEC], VP9_IVF_CODEC_VP90
    jne     .unsupported
    movzx   eax, word [rdi + VP9_IVF_FILE_WIDTH]
    er_check_zero eax, .corrupt
    movzx   ecx, word [rdi + VP9_IVF_FILE_HEIGHT]
    er_check_zero ecx, .corrupt
    mov     [rdx + VP9_IVF_HDR_CODEC], dword VP9_IVF_CODEC_VP90
    mov     [rdx + VP9_IVF_HDR_WIDTH], ax
    mov     [rdx + VP9_IVF_HDR_HEIGHT], cx
    mov     eax, [rdi + VP9_IVF_FILE_TIMEBASE_DEN]
    mov     [rdx + VP9_IVF_HDR_TIMEBASE_DEN], eax
    mov     eax, [rdi + VP9_IVF_FILE_TIMEBASE_NUM]
    mov     [rdx + VP9_IVF_HDR_TIMEBASE_NUM], eax
    mov     eax, [rdi + VP9_IVF_FILE_FRAME_COUNT]
    mov     [rdx + VP9_IVF_HDR_FRAME_COUNT], eax
    mov     eax, VP9_IVF_HEADER_SIZE
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

; er_vp9_ivf_read_frame(buf, len, cursor, frame_desc) -> eax=next_cursor, rdx=error
; frame_desc: payload_offset u32, payload_len u32, timestamp u64.
; rdi=buf, esi=len, edx=cursor, rcx=frame_desc
er_fn er_vp9_ivf_read_frame
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    er_check_zero rcx, .invalid_param
    mov     r12, rdi
    mov     r13, rcx
    mov     ebx, edx
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     eax, VP9_IVF_FRAME_HEADER_SIZE
    jb      .no_data
    mov     eax, [r12 + rbx + VP9_IVF_FRAME_RECORD_LEN]
    mov     edx, ebx
    add     edx, VP9_IVF_FRAME_HEADER_SIZE
    jc      .corrupt
    mov     r8d, edx
    add     r8d, eax
    jc      .corrupt
    cmp     r8d, esi
    ja      .no_data
    mov     [r13 + VP9_IVF_FRAME_PAYLOAD_OFFSET], edx
    mov     [r13 + VP9_IVF_FRAME_PAYLOAD_LEN], eax
    mov     rcx, [r12 + rbx + VP9_IVF_FRAME_RECORD_TIMESTAMP]
    mov     [r13 + VP9_IVF_FRAME_TIMESTAMP], rcx
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

; er_vp9_ivf_count_frames(buf, len) -> eax=actual frame count, rdx=error
; rdi=buf, esi=len
er_fn er_vp9_ivf_count_frames
    er_push rbx, r12, r13, r14
    er_stack_alloc VP9_IVF_SCAN_STACK_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + VP9_IVF_SCAN_HDR]
    call    er_vp9_ivf_decode_header
    er_check_nonzero edx, .done
    mov     ebx, VP9_IVF_HEADER_SIZE
    xor     r14d, r14d
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + VP9_IVF_SCAN_FRAME]
    call    er_vp9_ivf_read_frame
    er_check_nonzero edx, .done
    cmp     r14d, VP9_U32_MAX
    je      .corrupt
    inc     r14d
    mov     ebx, eax
    jmp     .loop
.ok:
    mov     eax, r14d
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
    er_stack_free VP9_IVF_SCAN_STACK_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp9_ivf_validate_frame_count(buf, len) -> eax=actual frame count, rdx=error
; rdi=buf, esi=len
er_fn er_vp9_ivf_validate_frame_count
    er_push rbx, r12, r13
    er_stack_alloc VP9_IVF_HDR_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    call    er_vp9_ivf_count_frames
    er_check_nonzero edx, .done
    mov     ebx, eax
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    call    er_vp9_ivf_decode_header
    er_check_nonzero edx, .done
    cmp     ebx, [rsp + VP9_IVF_HDR_FRAME_COUNT]
    jne     .corrupt
    mov     eax, ebx
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
    er_stack_free VP9_IVF_HDR_SIZE
    er_pop  rbx, r12, r13
    er_ret

; er_vp9_ivf_validate_timestamps(buf, len) -> eax=frame count, rdx=error
; Requires complete IVF frames with strictly increasing timestamps.
; rdi=buf, esi=len
er_fn er_vp9_ivf_validate_timestamps
    er_push rbx, r12, r13, r14
    er_stack_alloc VP9_IVF_SCAN_STACK_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + VP9_IVF_SCAN_HDR]
    call    er_vp9_ivf_decode_header
    er_check_nonzero edx, .done
    mov     ebx, VP9_IVF_HEADER_SIZE
    xor     r14d, r14d
    mov     qword [rsp + VP9_IVF_SCAN_PREV_TIMESTAMP], 0
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + VP9_IVF_SCAN_FRAME]
    call    er_vp9_ivf_read_frame
    er_check_nonzero edx, .done
    er_check_zero r14d, .first_frame
    mov     rcx, [rsp + VP9_IVF_SCAN_FRAME + VP9_IVF_FRAME_TIMESTAMP]
    cmp     rcx, [rsp + VP9_IVF_SCAN_PREV_TIMESTAMP]
    jbe     .corrupt
    jmp     .record
.first_frame:
    mov     rcx, [rsp + VP9_IVF_SCAN_FRAME + VP9_IVF_FRAME_TIMESTAMP]
.record:
    mov     [rsp + VP9_IVF_SCAN_PREV_TIMESTAMP], rcx
    cmp     r14d, VP9_U32_MAX
    je      .corrupt
    inc     r14d
    mov     ebx, eax
    jmp     .loop
.ok:
    mov     eax, r14d
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
    er_stack_free VP9_IVF_SCAN_STACK_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_vp9_ivf_seek_frame(buf, len, frame_index, frame_desc) -> eax=next_cursor, rdx=error
; rdi=buf, esi=len, edx=frame_index, rcx=frame_desc
er_fn er_vp9_ivf_seek_frame
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc VP9_IVF_HDR_SIZE
    er_check_zero rdi, .invalid_param
    er_check_zero rcx, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    call    er_vp9_ivf_decode_header
    er_check_nonzero edx, .done
    cmp     r14d, [rsp + VP9_IVF_HDR_FRAME_COUNT]
    jae     .not_found
    mov     ebx, VP9_IVF_HEADER_SIZE
.loop:
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    mov     rcx, r15
    call    er_vp9_ivf_read_frame
    er_check_nonzero edx, .done
    er_check_zero r14d, .ok
    dec     r14d
    mov     ebx, eax
    jmp     .loop
.ok:
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.not_found:
    xor     eax, eax
    er_err  ERROR_NOT_FOUND
.done:
    er_stack_free VP9_IVF_HDR_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_vp9_ivf_validate_payloads(buf, len) -> eax=frame count, rdx=error
; Scans declared IVF records and validates each VP9 frame payload.
; rdi=buf, esi=len
er_fn er_vp9_ivf_validate_payloads
    er_push rbx, r12, r13, r14
    er_stack_alloc VP9_IVF_SCAN_STACK_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + VP9_IVF_SCAN_HDR]
    call    er_vp9_ivf_decode_header
    er_check_nonzero edx, .done
    mov     ebx, VP9_IVF_HEADER_SIZE
    xor     r14d, r14d
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + VP9_IVF_SCAN_FRAME]
    call    er_vp9_ivf_read_frame
    er_check_nonzero edx, .done
    mov     ebx, eax
    mov     eax, [rsp + VP9_IVF_SCAN_FRAME + VP9_IVF_FRAME_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + VP9_IVF_SCAN_FRAME + VP9_IVF_FRAME_PAYLOAD_LEN]
    call    er_vp9_validate_frame_payload
    er_check_nonzero edx, .done
    cmp     r14d, VP9_U32_MAX
    je      .corrupt
    inc     r14d
    jmp     .loop
.ok:
    mov     eax, r14d
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
    er_stack_free VP9_IVF_SCAN_STACK_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret
