; EdgeRun AV1 reduced-still frame header decoder/encoder — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written

%macro call_read_bit 0
    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
%endmacro

%macro write_bits 2
    mov     rdi, rsp
    mov     esi, %1
    mov     edx, %2
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
%endmacro

%macro write_one_from_esi 0
    mov     rdi, rsp
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
%endmacro

SECTION .text

; er_av1_frame_decode(payload, len, seq_desc, frame_desc)
; Decodes the next-stage non-reduced keyframe header subset.
; rdi=payload, esi=len, rdx=seq_desc, rcx=frame_desc. Returns eax=header_bytes.
er_fn er_av1_frame_decode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 0
    jne     .unsupported
    cmp     byte [rdx + AV1_SEQ_ENABLE_SUPERRES], 0
    jne     .unsupported
    mov     r12, rdx
    mov     r13, rcx
    mov     r14d, esi
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .done

    call_read_bit
    mov     [r13 + AV1_FRAME_SHOW_EXISTING_FRAME], al
    test    eax, eax
    jnz     .show_existing_frame

    mov     rdi, rsp
    mov     esi, AV1_FRAME_TYPE_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_TYPE], al
    cmp     eax, AV1_FRAME_TYPE_KEY
    je      .key_frame
    cmp     eax, AV1_FRAME_TYPE_INTRA_ONLY
    je      .intra_only_frame
    cmp     eax, AV1_FRAME_TYPE_INTER
    je      .inter_frame
    cmp     eax, AV1_FRAME_TYPE_SWITCH
    je      .inter_frame
    jmp     .unsupported

.key_frame:
    call_read_bit
    mov     [r13 + AV1_FRAME_SHOW_FRAME], al
    test    eax, eax
    jnz     .shown_frame
    call_read_bit
    mov     [r13 + AV1_FRAME_SHOWABLE_FRAME], al
    jmp     .keyframe_defaults
.shown_frame:
    mov     byte [r13 + AV1_FRAME_SHOWABLE_FRAME], 0
.keyframe_defaults:
    mov     byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], 1
    mov     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
    mov     byte [r13 + AV1_FRAME_REFRESH_FRAME_FLAGS], AV1_FRAME_REFRESH_ALL
    jmp     .read_disable_cdf

.intra_only_frame:
.inter_frame:
    call_read_bit
    mov     [r13 + AV1_FRAME_SHOW_FRAME], al
    test    eax, eax
    jnz     .intra_shown_frame
    call_read_bit
    mov     [r13 + AV1_FRAME_SHOWABLE_FRAME], al
    jmp     .read_error_resilient
.intra_shown_frame:
    mov     byte [r13 + AV1_FRAME_SHOWABLE_FRAME], 0
.read_error_resilient:
    call_read_bit
    mov     [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], al

.read_disable_cdf:
    call_read_bit
    mov     [r13 + AV1_FRAME_DISABLE_CDF_UPDATE], al

    cmp     byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT], 1
    jne     .no_order_hint
    movzx   esi, byte [r12 + AV1_SEQ_ORDER_HINT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_ORDER_HINT], eax
    jmp     .primary_ref
.no_order_hint:
    mov     dword [r13 + AV1_FRAME_ORDER_HINT], 0

.primary_ref:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    je      .frame_size_override
    cmp     byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], 1
    je      .primary_ref_none
    mov     rdi, rsp
    mov     esi, AV1_FRAME_PRIMARY_REF_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_PRIMARY_REF_FRAME], al
    jmp     .refresh_flags
.primary_ref_none:
    mov     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
.refresh_flags:
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REFRESH_FLAGS_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REFRESH_FRAME_FLAGS], al

.frame_size_override:
    call_read_bit
    mov     [r13 + AV1_FRAME_FRAME_SIZE_OVERRIDE], al

    movzx   eax, byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS]
    cmp     eax, AV1_SEQ_SELECT_SCREEN_CONTENT_TOOLS
    jne     .store_screen_tools
    call_read_bit
.store_screen_tools:
    mov     [r13 + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], al

    test    eax, eax
    jz      .integer_mv_select_done
    movzx   eax, byte [r12 + AV1_SEQ_FORCE_INTEGER_MV]
    cmp     eax, AV1_SEQ_SELECT_INTEGER_MV
    jne     .store_integer_mv
    call_read_bit
.store_integer_mv:
    mov     [r13 + AV1_FRAME_FORCE_INTEGER_MV], al
    jmp     .read_inter_refs
.integer_mv_select_done:
    mov     byte [r13 + AV1_FRAME_FORCE_INTEGER_MV], 0

.read_inter_refs:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    je      .read_ref_indices
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_SWITCH
    jne     .read_dimensions
.read_ref_indices:
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX0], al
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX1], al
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX2], al
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX3], al
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX4], al
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX5], al
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX6], al
    call_read_bit
    mov     [r13 + AV1_FRAME_ALLOW_HIGH_PRECISION_MV], al

.read_dimensions:
    cmp     byte [r13 + AV1_FRAME_FRAME_SIZE_OVERRIDE], 1
    je      .read_override_dimensions
    mov     eax, [r12 + AV1_SEQ_MAX_WIDTH]
    mov     [r13 + AV1_FRAME_WIDTH], eax
    mov     eax, [r12 + AV1_SEQ_MAX_HEIGHT]
    mov     [r13 + AV1_FRAME_HEIGHT], eax
    jmp     .read_render_size

.read_override_dimensions:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_WIDTH], eax

    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_HEIGHT], eax

.read_render_size:
    call_read_bit
    test    eax, eax
    jnz     .render_different
    mov     eax, [r13 + AV1_FRAME_WIDTH]
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    mov     eax, [r13 + AV1_FRAME_HEIGHT]
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax
    jmp     .allow_intrabc

.render_different:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax

.allow_intrabc:
    cmp     byte [r13 + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 1
    jne     .no_intrabc
    cmp     byte [r13 + AV1_FRAME_FORCE_INTEGER_MV], 1
    jne     .no_intrabc
    call_read_bit
    mov     [r13 + AV1_FRAME_ALLOW_INTRABC], al
    jmp     .read_tile_info
.no_intrabc:
    mov     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 0

.read_tile_info:
    call_read_bit
    cmp     eax, 1
    jne     .unsupported
    mov     [r13 + AV1_FRAME_TILE_INFO_UNIFORM], al
    mov     rdi, rsp
    mov     esi, AV1_TILE_LOG2_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_TILE_LOG2_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2], al
    mov     ecx, eax
    mov     eax, 1
    shl     eax, cl
    mov     [r13 + AV1_FRAME_TILE_INFO_COLS], eax
    mov     rdi, rsp
    mov     esi, AV1_TILE_LOG2_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_TILE_LOG2_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_TILE_INFO_ROWS_LOG2], al
    mov     ecx, eax
    mov     eax, 1
    shl     eax, cl
    mov     [r13 + AV1_FRAME_TILE_INFO_ROWS], eax
    imul    eax, [r13 + AV1_FRAME_TILE_INFO_COLS]
    mov     [r13 + AV1_FRAME_TILE_INFO_COUNT], eax
    movzx   ebx, byte [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2]
    add     bl, [r13 + AV1_FRAME_TILE_INFO_ROWS_LOG2]
    test    ebx, ebx
    jz      .read_tile_size_bytes
    mov     rdi, rsp
    mov     esi, ebx
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], eax
.read_tile_size_bytes:
    mov     rdi, rsp
    mov     esi, AV1_TILE_SIZE_BYTES_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], al

.finish_header:
    mov     ebx, [rsp + AV1_BITS_POS]
    mov     [r13 + AV1_FRAME_HEADER_BITS], ebx
    lea     eax, [rbx + 7]
    shr     eax, 3
    cmp     eax, r14d
    ja      .no_data
    mov     [r13 + AV1_FRAME_TILE_OFFSET], eax
    mov     ecx, r14d
    sub     ecx, eax
    mov     [r13 + AV1_FRAME_TILE_LEN], ecx
    er_ok
    jmp     .done
.show_existing_frame:
    mov     rdi, rsp
    mov     esi, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_EXISTING_FRAME_IDX], al
    mov     byte [r13 + AV1_FRAME_SHOW_FRAME], 1
    mov     byte [r13 + AV1_FRAME_SHOWABLE_FRAME], 0
    mov     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    mov     byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], 0
    mov     byte [r13 + AV1_FRAME_DISABLE_CDF_UPDATE], 0
    mov     byte [r13 + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 0
    mov     byte [r13 + AV1_FRAME_FORCE_INTEGER_MV], 0
    mov     byte [r13 + AV1_FRAME_FRAME_SIZE_OVERRIDE], 0
    mov     dword [r13 + AV1_FRAME_ORDER_HINT], 0
    mov     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
    mov     byte [r13 + AV1_FRAME_REFRESH_FRAME_FLAGS], 0
    mov     dword [r13 + AV1_FRAME_WIDTH], 0
    mov     dword [r13 + AV1_FRAME_HEIGHT], 0
    mov     dword [r13 + AV1_FRAME_RENDER_WIDTH], 0
    mov     dword [r13 + AV1_FRAME_RENDER_HEIGHT], 0
    mov     dword [r13 + AV1_FRAME_TILE_OFFSET], 0
    mov     dword [r13 + AV1_FRAME_TILE_LEN], 0
    mov     ebx, [rsp + AV1_BITS_POS]
    mov     [r13 + AV1_FRAME_HEADER_BITS], ebx
    lea     eax, [rbx + 7]
    shr     eax, 3
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
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_frame_encode(out, cap, seq_desc, frame_desc)
; Encodes a non-reduced keyframe header subset from frame_desc.
; rdi=out, esi=cap, rdx=seq_desc, rcx=frame_desc. Returns eax=bytes.
er_fn er_av1_frame_encode
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 0
    jne     .unsupported
    cmp     byte [rdx + AV1_SEQ_ENABLE_SUPERRES], 0
    jne     .unsupported
    cmp     byte [rcx + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    je      .params_ok
    movzx   eax, byte [rcx + AV1_FRAME_TYPE]
    cmp     eax, AV1_FRAME_TYPE_KEY
    je      .check_dimensions
    cmp     eax, AV1_FRAME_TYPE_INTRA_ONLY
    je      .check_dimensions
    cmp     eax, AV1_FRAME_TYPE_INTER
    je      .check_dimensions
    cmp     eax, AV1_FRAME_TYPE_SWITCH
    jne     .unsupported
.check_dimensions:
    cmp     dword [rcx + AV1_FRAME_WIDTH], 0
    je      .invalid_param
    cmp     dword [rcx + AV1_FRAME_HEIGHT], 0
    je      .invalid_param
.params_ok:
    mov     r12, rdx
    mov     r13, rcx
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .done

    movzx   esi, byte [r13 + AV1_FRAME_SHOW_EXISTING_FRAME]
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    jne     .write_frame_type
    movzx   esi, byte [r13 + AV1_FRAME_EXISTING_FRAME_IDX]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    jmp     .bytes_written

.write_frame_type:
    movzx   esi, byte [r13 + AV1_FRAME_TYPE]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_TYPE_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_SHOW_FRAME]
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_SHOW_FRAME], 1
    je      .write_keyframe_defaults
    movzx   esi, byte [r13 + AV1_FRAME_SHOWABLE_FRAME]
    write_one_from_esi
.write_keyframe_defaults:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    je      .write_disable_cdf
    movzx   esi, byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE]
    write_one_from_esi
.write_disable_cdf:
    movzx   esi, byte [r13 + AV1_FRAME_DISABLE_CDF_UPDATE]
    write_one_from_esi

    cmp     byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT], 1
    jne     .write_frame_size_override
    mov     esi, [r13 + AV1_FRAME_ORDER_HINT]
    movzx   edx, byte [r12 + AV1_SEQ_ORDER_HINT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.write_frame_size_override:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    je      .write_frame_size_override_bit
    cmp     byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], 1
    je      .write_refresh_flags
    movzx   esi, byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_PRIMARY_REF_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_refresh_flags:
    movzx   esi, byte [r13 + AV1_FRAME_REFRESH_FRAME_FLAGS]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REFRESH_FLAGS_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.write_frame_size_override_bit:
    movzx   esi, byte [r13 + AV1_FRAME_FRAME_SIZE_OVERRIDE]
    write_one_from_esi

    movzx   eax, byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS]
    cmp     eax, AV1_SEQ_SELECT_SCREEN_CONTENT_TOOLS
    jne     .write_integer_mv
    movzx   esi, byte [r13 + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS]
    write_one_from_esi

.write_integer_mv:
    cmp     byte [r13 + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 1
    jne     .write_inter_refs
    movzx   eax, byte [r12 + AV1_SEQ_FORCE_INTEGER_MV]
    cmp     eax, AV1_SEQ_SELECT_INTEGER_MV
    jne     .write_inter_refs
    movzx   esi, byte [r13 + AV1_FRAME_FORCE_INTEGER_MV]
    write_one_from_esi

.write_inter_refs:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    je      .write_ref_indices
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_SWITCH
    jne     .write_dimensions
.write_ref_indices:
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX0]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX1]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX2]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX3]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX4]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX5]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_REF_FRAME_IDX6]
    mov     rdi, rsp
    mov     edx, AV1_FRAME_REF_INDEX_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_ALLOW_HIGH_PRECISION_MV]
    write_one_from_esi

.write_dimensions:
    cmp     byte [r13 + AV1_FRAME_FRAME_SIZE_OVERRIDE], 1
    jne     .write_render_size
    mov     esi, [r13 + AV1_FRAME_WIDTH]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, [r13 + AV1_FRAME_HEIGHT]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_render_size:
    mov     eax, [r13 + AV1_FRAME_RENDER_WIDTH]
    cmp     eax, [r13 + AV1_FRAME_WIDTH]
    jne     .write_render_different
    mov     eax, [r13 + AV1_FRAME_RENDER_HEIGHT]
    cmp     eax, [r13 + AV1_FRAME_HEIGHT]
    jne     .write_render_different
    write_bits 0, 1
    jmp     .write_intrabc
.write_render_different:
    write_bits 1, 1
    mov     esi, [r13 + AV1_FRAME_RENDER_WIDTH]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, [r13 + AV1_FRAME_RENDER_HEIGHT]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.write_intrabc:
    cmp     byte [r13 + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 1
    jne     .write_tile_info
    cmp     byte [r13 + AV1_FRAME_FORCE_INTEGER_MV], 1
    jne     .write_tile_info
    movzx   esi, byte [r13 + AV1_FRAME_ALLOW_INTRABC]
    write_one_from_esi

.write_tile_info:
    cmp     byte [r13 + AV1_FRAME_TILE_INFO_UNIFORM], 1
    jne     .unsupported
    cmp     byte [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2], AV1_TILE_LOG2_MAX
    ja      .invalid_param
    cmp     byte [r13 + AV1_FRAME_TILE_INFO_ROWS_LOG2], AV1_TILE_LOG2_MAX
    ja      .invalid_param
    cmp     byte [r13 + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], AV1_TILE_SIZE_BYTES_MIN
    jb      .invalid_param
    cmp     byte [r13 + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], AV1_TILE_SIZE_BYTES_MAX
    ja      .invalid_param
    write_bits 1, 1
    movzx   esi, byte [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2]
    mov     rdi, rsp
    mov     edx, AV1_TILE_LOG2_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_TILE_INFO_ROWS_LOG2]
    mov     rdi, rsp
    mov     edx, AV1_TILE_LOG2_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   ebx, byte [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2]
    add     bl, [r13 + AV1_FRAME_TILE_INFO_ROWS_LOG2]
    test    ebx, ebx
    jz      .write_tile_size_bytes
    mov     esi, [r13 + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID]
    mov     edx, ebx
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_tile_size_bytes:
    movzx   esi, byte [r13 + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES]
    dec     esi
    mov     rdi, rsp
    mov     edx, AV1_TILE_SIZE_BYTES_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.bytes_written:
    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_frame_decode_reduced_still(payload, len, seq_desc, frame_desc)
; rdi=payload, esi=len, rdx=seq_desc, rcx=frame_desc. Returns eax=header_bytes.
er_fn er_av1_frame_decode_reduced_still
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 1
    jne     .unsupported
    mov     r12, rdx
    mov     r13, rcx
    mov     r14d, esi
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .done

    mov     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    mov     byte [r13 + AV1_FRAME_SHOW_FRAME], 1

    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_WIDTH], eax

    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_HEIGHT], eax

    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jnz     .render_different
    mov     eax, [r13 + AV1_FRAME_WIDTH]
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    mov     eax, [r13 + AV1_FRAME_HEIGHT]
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax
    jmp     .allow_intrabc

.render_different:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax

.allow_intrabc:
    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_ALLOW_INTRABC], al
    mov     ebx, [rsp + AV1_BITS_POS]
    mov     [r13 + AV1_FRAME_HEADER_BITS], ebx
    lea     eax, [rbx + 7]
    shr     eax, 3
    cmp     eax, r14d
    ja      .no_data
    mov     [r13 + AV1_FRAME_TILE_OFFSET], eax
    mov     ecx, r14d
    sub     ecx, eax
    mov     [r13 + AV1_FRAME_TILE_LEN], ecx
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
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_frame_encode_reduced_still(out, cap, seq_desc, width, height)
; rdi=out, esi=cap, rdx=seq_desc, ecx=width, r8d=height. Returns eax=bytes.
er_fn er_av1_frame_encode_reduced_still
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    test    r8d, r8d
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 1
    jne     .unsupported
    mov     r12, rdx
    mov     r13d, ecx
    mov     r14d, r8d
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .done
    mov     esi, r13d
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, r14d
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret
