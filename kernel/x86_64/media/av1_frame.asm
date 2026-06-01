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

%macro read_delta_q_to 1
    call_read_bit
    test    eax, eax
    jz      %%zero
    mov     rdi, rsp
    mov     esi, AV1_QUANT_DELTA_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     ecx, eax
    test    ecx, ecx
    jz      %%store
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    test    eax, eax
    jz      %%store
    neg     ecx
%%store:
    mov     [r13 + %1], ecx
    jmp     %%done
%%zero:
    mov     dword [r13 + %1], 0
%%done:
%endmacro

%macro write_delta_q_from 1
    mov     esi, [r13 + %1]
    test    esi, esi
    jnz     %%nonzero
    write_bits 0, 1
    jmp     %%done
%%nonzero:
    write_bits 1, 1
    mov     esi, [r13 + %1]
    test    esi, esi
    jns     %%positive
    neg     esi
%%positive:
    cmp     esi, AV1_QUANT_DELTA_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_QUANT_DELTA_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    xor     esi, esi
    cmp     dword [r13 + %1], 0
    jns     %%sign_ready
    mov     esi, 1
%%sign_ready:
    write_one_from_esi
%%done:
%endmacro

%macro zero_segmentation_state 0
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_ENABLED], 0
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_MAP], 0
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], 0
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_DATA], 0
    xor     ebx, ebx
%%mask_loop:
    cmp     ebx, AV1_SEGMENT_MAX_SEGMENTS
    jae     %%mask_done
    mov     byte [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx], 0
    inc     ebx
    jmp     %%mask_loop
%%mask_done:
    xor     ebx, ebx
%%data_loop:
    cmp     ebx, AV1_SEGMENT_MAX_SEGMENTS * AV1_SEGMENT_FEATURE_COUNT
    jae     %%done
    mov     dword [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rbx * 4], 0
    inc     ebx
    jmp     %%data_loop
%%done:
%endmacro

%macro zero_delta_state 0
    mov     byte [r13 + AV1_FRAME_DELTA_Q_PRESENT], 0
    mov     byte [r13 + AV1_FRAME_DELTA_Q_RES], 0
    mov     byte [r13 + AV1_FRAME_DELTA_LF_PRESENT], 0
    mov     byte [r13 + AV1_FRAME_DELTA_LF_RES], 0
    mov     byte [r13 + AV1_FRAME_DELTA_LF_MULTI], 0
%endmacro

%macro zero_transform_ref_state 0
    mov     byte [r13 + AV1_FRAME_TX_MODE], AV1_TX_MODE_ONLY_4X4
    mov     byte [r13 + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [r13 + AV1_FRAME_SKIP_MODE_PRESENT], 0
%endmacro

%macro zero_global_motion_state 0
    xor     ebx, ebx
%%type_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT
    jae     %%type_done
    mov     byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], AV1_GLOBAL_MOTION_IDENTITY
    inc     ebx
    jmp     %%type_loop
%%type_done:
    xor     ebx, ebx
%%param_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT * AV1_GLOBAL_MOTION_PARAM_COUNT
    jae     %%done
    mov     dword [r13 + AV1_FRAME_GLOBAL_MOTION_PARAMS + rbx * 4], 0
    inc     ebx
    jmp     %%param_loop
%%done:
%endmacro

%macro zero_loop_filter_delta_state 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 0
    xor     ebx, ebx
%%ref_loop:
    cmp     ebx, AV1_LOOP_FILTER_REF_DELTA_COUNT
    jae     %%mode_start
    mov     dword [r13 + AV1_FRAME_LOOP_FILTER_REF_DELTAS + rbx * 4], 0
    inc     ebx
    jmp     %%ref_loop
%%mode_start:
    xor     ebx, ebx
%%mode_loop:
    cmp     ebx, AV1_LOOP_FILTER_MODE_DELTA_COUNT
    jae     %%done
    mov     dword [r13 + AV1_FRAME_LOOP_FILTER_MODE_DELTAS + rbx * 4], 0
    inc     ebx
    jmp     %%mode_loop
%%done:
%endmacro

%macro read_segment_feature 4
    call_read_bit
    test    eax, eax
    jz      %%disabled
    mov     al, [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx]
    or      al, 1 << %1
    mov     [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx], al
%if %2 = 0
    mov     eax, ebx
    shl     eax, AV1_SEGMENT_FEATURE_DATA_SHIFT
    mov     dword [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rax + (%1 * 4)], 0
%else
    mov     rdi, rsp
    mov     esi, %2
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, %3
    ja      .corrupt
    mov     ecx, eax
%if %4 = 1
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    test    eax, eax
    jz      %%store
    neg     ecx
%%store:
%endif
    mov     eax, ebx
    shl     eax, AV1_SEGMENT_FEATURE_DATA_SHIFT
    mov     [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rax + (%1 * 4)], ecx
%endif
    jmp     %%done
%%disabled:
    mov     eax, ebx
    shl     eax, AV1_SEGMENT_FEATURE_DATA_SHIFT
    mov     dword [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rax + (%1 * 4)], 0
%%done:
%endmacro

%macro read_loop_filter_delta_value 1
    call_read_bit
    test    eax, eax
    jz      %%zero
    mov     rdi, rsp
    mov     esi, AV1_LOOP_FILTER_DELTA_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_LOOP_FILTER_DELTA_MAX
    ja      .corrupt
    mov     ecx, eax
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    test    eax, eax
    jz      %%store
    neg     ecx
%%store:
    mov     [r13 + %1 + rbx * 4], ecx
    jmp     %%done
%%zero:
    mov     dword [r13 + %1 + rbx * 4], 0
%%done:
%endmacro

%macro write_loop_filter_delta_value 1
    mov     esi, [r13 + %1 + rbx * 4]
    test    esi, esi
    jnz     %%nonzero
    write_bits 0, 1
    jmp     %%done
%%nonzero:
    write_bits 1, 1
    mov     esi, [r13 + %1 + rbx * 4]
    cmp     esi, AV1_LOOP_FILTER_DELTA_MAX
    jg      .invalid_param
    cmp     esi, -AV1_LOOP_FILTER_DELTA_MAX
    jl      .invalid_param
    test    esi, esi
    jns     %%positive
    neg     esi
%%positive:
    mov     rdi, rsp
    mov     edx, AV1_LOOP_FILTER_DELTA_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    xor     esi, esi
    cmp     dword [r13 + %1 + rbx * 4], 0
    jns     %%sign_ready
    mov     esi, 1
%%sign_ready:
    write_one_from_esi
%%done:
%endmacro

%macro read_global_motion_param 0
    mov     rdi, rsp
    mov     esi, AV1_GLOBAL_MOTION_PARAM_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     ecx, eax
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    test    eax, eax
    jz      %%store
    neg     ecx
%%store:
    mov     eax, ebx
    imul    eax, AV1_GLOBAL_MOTION_PARAM_STRIDE
    lea     rax, [rax + r11 * 4]
    mov     [r13 + AV1_FRAME_GLOBAL_MOTION_PARAMS + rax], ecx
%endmacro

%macro write_global_motion_param 0
    mov     eax, ebx
    imul    eax, AV1_GLOBAL_MOTION_PARAM_STRIDE
    lea     rax, [rax + r11 * 4]
    mov     esi, [r13 + AV1_FRAME_GLOBAL_MOTION_PARAMS + rax]
    cmp     esi, AV1_GLOBAL_MOTION_PARAM_MAX
    jg      .invalid_param
    cmp     esi, -AV1_GLOBAL_MOTION_PARAM_MAX
    jl      .invalid_param
    test    esi, esi
    jns     %%positive
    neg     esi
%%positive:
    mov     rdi, rsp
    mov     edx, AV1_GLOBAL_MOTION_PARAM_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    xor     esi, esi
    mov     eax, ebx
    imul    eax, AV1_GLOBAL_MOTION_PARAM_STRIDE
    lea     rax, [rax + r11 * 4]
    cmp     dword [r13 + AV1_FRAME_GLOBAL_MOTION_PARAMS + rax], 0
    jns     %%sign_ready
    mov     esi, 1
%%sign_ready:
    write_one_from_esi
%endmacro

%macro write_segment_feature 4
    mov     al, [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx]
    test    al, 1 << %1
    jnz     %%enabled
    write_bits 0, 1
    jmp     %%done
%%enabled:
    write_bits 1, 1
    mov     eax, ebx
    shl     eax, AV1_SEGMENT_FEATURE_DATA_SHIFT
    mov     esi, [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rax + (%1 * 4)]
%if %2 = 0
    cmp     esi, 0
    jne     .invalid_param
%else
%if %4 = 1
    cmp     esi, %3
    jg      .invalid_param
    cmp     esi, -%3
    jl      .invalid_param
    test    esi, esi
    jns     %%positive
    neg     esi
%%positive:
%else
    cmp     esi, %3
    ja      .invalid_param
%endif
    mov     rdi, rsp
    mov     edx, %2
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
%if %4 = 1
    xor     esi, esi
    mov     eax, ebx
    shl     eax, AV1_SEGMENT_FEATURE_DATA_SHIFT
    cmp     dword [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rax + (%1 * 4)], 0
    jns     %%sign_ready
    mov     esi, 1
%%sign_ready:
    write_one_from_esi
%endif
%endif
%%done:
%endmacro

SECTION .text

; er_av1_frame_decode(payload, len, seq_desc, frame_desc)
; Decodes the next-stage non-reduced keyframe header subset.
; rdi=payload, esi=len, rdx=seq_desc, rcx=frame_desc. Returns eax=header_bytes.
er_fn er_av1_frame_decode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE + 8
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 0
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
    jmp     .frame_id
.no_order_hint:
    mov     dword [r13 + AV1_FRAME_ORDER_HINT], 0

.frame_id:
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    je      .read_current_frame_id
    mov     dword [r13 + AV1_FRAME_CURRENT_FRAME_ID], 0
    jmp     .primary_ref
.read_current_frame_id:
    movzx   esi, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    add     sil, [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_CURRENT_FRAME_ID], eax

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
    jmp     .read_superres

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

.read_superres:
    mov     r15d, [r13 + AV1_FRAME_WIDTH]
    mov     dword [r13 + AV1_FRAME_SUPERRES_DENOM], AV1_SUPERRES_NUM
    cmp     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .read_render_size
    call_read_bit
    test    eax, eax
    jz      .read_render_size
    mov     rdi, rsp
    mov     esi, AV1_SUPERRES_DENOM_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    add     eax, AV1_SUPERRES_DENOM_MIN
    mov     [r13 + AV1_FRAME_SUPERRES_DENOM], eax
    mov     ebx, eax
    mov     eax, r15d
    imul    eax, AV1_SUPERRES_NUM
    mov     ecx, ebx
    shr     ecx, 1
    add     eax, ecx
    xor     edx, edx
    div     ebx
    test    eax, eax
    jz      .corrupt
    mov     [r13 + AV1_FRAME_WIDTH], eax

.read_render_size:
    call_read_bit
    test    eax, eax
    jnz     .render_different
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], r15d
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

.read_quantization:
    mov     rdi, rsp
    mov     esi, AV1_QUANT_BASE_Q_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_BASE_Q_IDX], al
    read_delta_q_to AV1_FRAME_DELTA_Q_Y_DC
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_quant_mono
    read_delta_q_to AV1_FRAME_DELTA_Q_U_DC
    read_delta_q_to AV1_FRAME_DELTA_Q_U_AC
    cmp     byte [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    je      .read_quant_v
    mov     eax, [r13 + AV1_FRAME_DELTA_Q_U_DC]
    mov     [r13 + AV1_FRAME_DELTA_Q_V_DC], eax
    mov     eax, [r13 + AV1_FRAME_DELTA_Q_U_AC]
    mov     [r13 + AV1_FRAME_DELTA_Q_V_AC], eax
    jmp     .read_qmatrix
.read_quant_v:
    read_delta_q_to AV1_FRAME_DELTA_Q_V_DC
    read_delta_q_to AV1_FRAME_DELTA_Q_V_AC
    jmp     .read_qmatrix
.read_quant_mono:
    mov     dword [r13 + AV1_FRAME_DELTA_Q_U_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_U_AC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_V_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_V_AC], 0
.read_qmatrix:
    call_read_bit
    mov     [r13 + AV1_FRAME_USING_QMATRIX], al
    test    eax, eax
    jnz     .unsupported
    jmp     .read_segmentation

.read_segmentation:
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_ENABLED], al
    test    eax, eax
    jnz     .read_segmentation_enabled
    zero_segmentation_state
    jmp     .read_delta_q_params
.read_segmentation_enabled:
    cmp     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
    jne     .read_segmentation_update_flags
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_MAP], 1
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], 0
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_DATA], 1
    jmp     .read_segmentation_data
.read_segmentation_update_flags:
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_UPDATE_MAP], al
    test    eax, eax
    jz      .read_segmentation_temporal_zero
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], al
    jmp     .read_segmentation_update_data
.read_segmentation_temporal_zero:
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], 0
.read_segmentation_update_data:
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_UPDATE_DATA], al
    test    eax, eax
    jz      .unsupported
.read_segmentation_data:
    xor     ebx, ebx
.read_segmentation_segment_loop:
    cmp     ebx, AV1_SEGMENT_MAX_SEGMENTS
    jae     .read_delta_q_params
    mov     byte [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx], 0
    read_segment_feature AV1_SEGMENT_FEATURE_ALT_Q, AV1_SEGMENT_ALT_Q_BITS, AV1_SEGMENT_ALT_Q_MAX, 1
    read_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_Y_V, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    read_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_Y_H, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    read_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_U, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    read_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_V, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    read_segment_feature AV1_SEGMENT_FEATURE_REF_FRAME, AV1_SEGMENT_REF_FRAME_BITS, AV1_SEGMENT_REF_FRAME_MAX, 0
    read_segment_feature AV1_SEGMENT_FEATURE_SKIP, AV1_SEGMENT_SKIP_BITS, AV1_SEGMENT_SKIP_MAX, 0
    read_segment_feature AV1_SEGMENT_FEATURE_GLOBALMV, AV1_SEGMENT_GLOBALMV_BITS, AV1_SEGMENT_GLOBALMV_MAX, 0
    inc     ebx
    jmp     .read_segmentation_segment_loop

.read_delta_q_params:
    cmp     byte [r13 + AV1_FRAME_BASE_Q_IDX], 0
    je      .read_delta_zero
    call_read_bit
    mov     [r13 + AV1_FRAME_DELTA_Q_PRESENT], al
    test    eax, eax
    jz      .read_delta_q_res_zero
    mov     rdi, rsp
    mov     esi, AV1_DELTA_Q_RES_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_DELTA_Q_RES_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_DELTA_Q_RES], al
    jmp     .read_delta_lf_params
.read_delta_q_res_zero:
    mov     byte [r13 + AV1_FRAME_DELTA_Q_RES], 0
    jmp     .read_delta_lf_zero
.read_delta_lf_params:
    call_read_bit
    mov     [r13 + AV1_FRAME_DELTA_LF_PRESENT], al
    test    eax, eax
    jz      .read_delta_lf_zero_res
    mov     rdi, rsp
    mov     esi, AV1_DELTA_LF_RES_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_DELTA_LF_RES_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_DELTA_LF_RES], al
    call_read_bit
    mov     [r13 + AV1_FRAME_DELTA_LF_MULTI], al
    jmp     .read_loop_filter
.read_delta_lf_zero_res:
    mov     byte [r13 + AV1_FRAME_DELTA_LF_RES], 0
    mov     byte [r13 + AV1_FRAME_DELTA_LF_MULTI], 0
    jmp     .read_loop_filter
.read_delta_lf_zero:
    mov     byte [r13 + AV1_FRAME_DELTA_LF_PRESENT], 0
    mov     byte [r13 + AV1_FRAME_DELTA_LF_RES], 0
    mov     byte [r13 + AV1_FRAME_DELTA_LF_MULTI], 0
    jmp     .read_loop_filter
.read_delta_zero:
    zero_delta_state
    jmp     .read_loop_filter

.read_loop_filter:
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .read_loop_filter_zero
    mov     rdi, rsp
    mov     esi, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], al
    mov     rdi, rsp
    mov     esi, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], al
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_loop_filter_chroma_zero
    movzx   eax, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V]
    movzx   ecx, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H]
    or      eax, ecx
    jz      .read_loop_filter_chroma_zero
    mov     rdi, rsp
    mov     esi, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], al
    mov     rdi, rsp
    mov     esi, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], al
    jmp     .read_loop_filter_sharpness
.read_loop_filter_chroma_zero:
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], 0
.read_loop_filter_sharpness:
    mov     rdi, rsp
    mov     esi, AV1_LOOP_FILTER_SHARPNESS_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_LOOP_FILTER_SHARPNESS], al
    call_read_bit
    mov     [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], al
    test    eax, eax
    jnz     .read_loop_filter_delta_update
    zero_loop_filter_delta_state
    jmp     .read_cdef
.read_loop_filter_delta_update:
    call_read_bit
    mov     [r13 + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], al
    test    eax, eax
    jz      .read_loop_filter_delta_zero
    xor     ebx, ebx
.read_loop_filter_ref_delta_loop:
    cmp     ebx, AV1_LOOP_FILTER_REF_DELTA_COUNT
    jae     .read_loop_filter_mode_delta_start
    read_loop_filter_delta_value AV1_FRAME_LOOP_FILTER_REF_DELTAS
    inc     ebx
    jmp     .read_loop_filter_ref_delta_loop
.read_loop_filter_mode_delta_start:
    xor     ebx, ebx
.read_loop_filter_mode_delta_loop:
    cmp     ebx, AV1_LOOP_FILTER_MODE_DELTA_COUNT
    jae     .read_cdef
    read_loop_filter_delta_value AV1_FRAME_LOOP_FILTER_MODE_DELTAS
    inc     ebx
    jmp     .read_loop_filter_mode_delta_loop
.read_loop_filter_delta_zero:
    zero_loop_filter_delta_state
    jmp     .read_cdef
.read_loop_filter_zero:
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_SHARPNESS], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 0
    zero_loop_filter_delta_state
    zero_loop_filter_delta_state
    jmp     .read_cdef

.read_cdef:
    cmp     byte [r12 + AV1_SEQ_ENABLE_CDEF], 1
    jne     .read_cdef_zero
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .read_cdef_zero
    mov     rdi, rsp
    mov     esi, AV1_CDEF_DAMPING_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    add     eax, AV1_CDEF_DAMPING_MIN
    mov     [r13 + AV1_FRAME_CDEF_DAMPING], al
    mov     rdi, rsp
    mov     esi, AV1_CDEF_BITS_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_CDEF_BITS_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_CDEF_BITS], al
    mov     ecx, eax
    mov     r15d, 1
    shl     r15d, cl
    xor     ebx, ebx
.read_cdef_loop:
    cmp     ebx, r15d
    jae     .read_restoration
    mov     rdi, rsp
    mov     esi, AV1_CDEF_PRI_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_CDEF_Y_PRI + rbx], al
    mov     rdi, rsp
    mov     esi, AV1_CDEF_SEC_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_CDEF_SEC_SKIP
    jne     .read_cdef_y_sec_store
    inc     eax
.read_cdef_y_sec_store:
    mov     [r13 + AV1_FRAME_CDEF_Y_SEC + rbx], al
    mov     rdi, rsp
    mov     esi, AV1_CDEF_PRI_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_CDEF_UV_PRI + rbx], al
    mov     rdi, rsp
    mov     esi, AV1_CDEF_SEC_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_CDEF_SEC_SKIP
    jne     .read_cdef_uv_sec_store
    inc     eax
.read_cdef_uv_sec_store:
    mov     [r13 + AV1_FRAME_CDEF_UV_SEC + rbx], al
    inc     ebx
    jmp     .read_cdef_loop
.read_cdef_zero:
    mov     byte [r13 + AV1_FRAME_CDEF_DAMPING], 0
    mov     byte [r13 + AV1_FRAME_CDEF_BITS], 0
    xor     ebx, ebx
.read_cdef_zero_loop:
    cmp     ebx, AV1_CDEF_ENTRY_MAX
    jae     .read_restoration
    mov     byte [r13 + AV1_FRAME_CDEF_Y_PRI + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_Y_SEC + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_UV_PRI + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_UV_SEC + rbx], 0
    inc     ebx
    jmp     .read_cdef_zero_loop

.read_restoration:
    cmp     byte [r12 + AV1_SEQ_ENABLE_RESTORATION], 1
    jne     .read_restoration_zero
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .read_restoration_zero
    mov     rdi, rsp
    mov     esi, AV1_RESTORATION_TYPE_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_RESTORATION_TYPE_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_Y], al
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_restoration_chroma_zero
    mov     rdi, rsp
    mov     esi, AV1_RESTORATION_TYPE_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_RESTORATION_TYPE_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_U], al
    mov     rdi, rsp
    mov     esi, AV1_RESTORATION_TYPE_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_RESTORATION_TYPE_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_V], al
    jmp     .read_restoration_units
.read_restoration_chroma_zero:
    mov     byte [r13 + AV1_FRAME_RESTORATION_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_V], 0
.read_restoration_units:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_Y], AV1_RESTORE_NONE
    je      .read_restoration_unit_y_zero
    mov     rdi, rsp
    mov     esi, AV1_RESTORATION_UNIT_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_RESTORATION_UNIT_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_UNIT_Y], al
    jmp     .read_restoration_unit_u
.read_restoration_unit_y_zero:
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_Y], 0
.read_restoration_unit_u:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    je      .read_restoration_unit_v
    mov     rdi, rsp
    mov     esi, AV1_RESTORATION_UNIT_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_RESTORATION_UNIT_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_UNIT_U], al
    jmp     .read_restoration_unit_v
.read_restoration_unit_v:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    jne     .read_restoration_unit_v_check
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_U], 0
.read_restoration_unit_v_check:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_V], AV1_RESTORE_NONE
    jne     .read_restoration_unit_v_read
    jmp     .read_restoration_unit_v_zero
.read_restoration_unit_v_read:
    mov     rdi, rsp
    mov     esi, AV1_RESTORATION_UNIT_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_RESTORATION_UNIT_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_UNIT_V], al
    jmp     .read_transform_ref
.read_restoration_unit_v_zero:
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_V], 0
    jmp     .read_transform_ref
.read_restoration_zero:
    mov     byte [r13 + AV1_FRAME_RESTORATION_Y], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_V], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_Y], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_V], 0

.read_transform_ref:
    call_read_bit
    test    eax, eax
    jz      .read_tx_largest
    mov     byte [r13 + AV1_FRAME_TX_MODE], AV1_TX_MODE_SELECT
    jmp     .read_reference_mode
.read_tx_largest:
    mov     byte [r13 + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
.read_reference_mode:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    je      .read_reference_select
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_SWITCH
    je      .read_reference_select
    mov     byte [r13 + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [r13 + AV1_FRAME_SKIP_MODE_PRESENT], 0
    zero_global_motion_state
    jmp     .finish_header
.read_reference_select:
    call_read_bit
    mov     [r13 + AV1_FRAME_REFERENCE_SELECT], al
    call_read_bit
    mov     [r13 + AV1_FRAME_SKIP_MODE_PRESENT], al
    zero_global_motion_state
    xor     ebx, ebx
.read_global_motion_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT
    jae     .finish_header
    call_read_bit
    test    eax, eax
    jz      .read_global_motion_next
    mov     rdi, rsp
    mov     esi, AV1_GLOBAL_MOTION_TYPE_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .corrupt
    cmp     eax, AV1_GLOBAL_MOTION_AFFINE
    ja      .corrupt
    mov     [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], al
    xor     r11d, r11d
.read_global_motion_param_loop:
    cmp     byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], AV1_GLOBAL_MOTION_TRANSLATION
    jne     .read_global_motion_rotzoom_check
    cmp     r11d, 2
    jae     .read_global_motion_next
    jmp     .read_global_motion_param
.read_global_motion_rotzoom_check:
    cmp     byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], AV1_GLOBAL_MOTION_ROTZOOM
    jne     .read_global_motion_affine_check
    cmp     r11d, 4
    jae     .read_global_motion_next
    jmp     .read_global_motion_param
.read_global_motion_affine_check:
    cmp     r11d, AV1_GLOBAL_MOTION_PARAM_COUNT
    jae     .read_global_motion_next
.read_global_motion_param:
    read_global_motion_param
    inc     r11d
    jmp     .read_global_motion_param_loop
.read_global_motion_next:
    inc     ebx
    jmp     .read_global_motion_loop

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
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    je      .read_display_frame_id
    mov     dword [r13 + AV1_FRAME_DISPLAY_FRAME_ID], 0
    jmp     .show_existing_defaults
.read_display_frame_id:
    movzx   esi, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    add     sil, [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
    mov     rdi, rsp
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_FRAME_DISPLAY_FRAME_ID], eax
.show_existing_defaults:
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
    mov     dword [r13 + AV1_FRAME_SUPERRES_DENOM], 0
    mov     dword [r13 + AV1_FRAME_CURRENT_FRAME_ID], 0
    mov     byte [r13 + AV1_FRAME_BASE_Q_IDX], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_Y_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_U_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_U_AC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_V_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_V_AC], 0
    mov     byte [r13 + AV1_FRAME_USING_QMATRIX], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_SHARPNESS], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 0
    zero_loop_filter_delta_state
    mov     byte [r13 + AV1_FRAME_CDEF_DAMPING], 0
    mov     byte [r13 + AV1_FRAME_CDEF_BITS], 0
    xor     ebx, ebx
.show_existing_cdef_zero_loop:
    cmp     ebx, AV1_CDEF_ENTRY_MAX
    jae     .show_existing_cdef_zero_done
    mov     byte [r13 + AV1_FRAME_CDEF_Y_PRI + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_Y_SEC + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_UV_PRI + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_UV_SEC + rbx], 0
    inc     ebx
    jmp     .show_existing_cdef_zero_loop
.show_existing_cdef_zero_done:
    mov     byte [r13 + AV1_FRAME_RESTORATION_Y], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_V], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_Y], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_V], 0
    zero_segmentation_state
    zero_delta_state
    zero_transform_ref_state
    zero_global_motion_state
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
    er_stack_free AV1_BITS_SIZE + 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_frame_encode(out, cap, seq_desc, frame_desc)
; Encodes a non-reduced keyframe header subset from frame_desc.
; rdi=out, esi=cap, rdx=seq_desc, rcx=frame_desc. Returns eax=bytes.
er_fn er_av1_frame_encode
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_BITS_SIZE + 8
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 0
    jne     .unsupported
    cmp     byte [rcx + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    je      .params_ok
    mov     eax, [rcx + AV1_FRAME_DELTA_Q_Y_DC]
    cmp     eax, AV1_QUANT_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_QUANT_DELTA_MAX
    jl      .invalid_param
    mov     eax, [rcx + AV1_FRAME_DELTA_Q_U_DC]
    cmp     eax, AV1_QUANT_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_QUANT_DELTA_MAX
    jl      .invalid_param
    mov     eax, [rcx + AV1_FRAME_DELTA_Q_U_AC]
    cmp     eax, AV1_QUANT_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_QUANT_DELTA_MAX
    jl      .invalid_param
    mov     eax, [rcx + AV1_FRAME_DELTA_Q_V_DC]
    cmp     eax, AV1_QUANT_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_QUANT_DELTA_MAX
    jl      .invalid_param
    mov     eax, [rcx + AV1_FRAME_DELTA_Q_V_AC]
    cmp     eax, AV1_QUANT_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_QUANT_DELTA_MAX
    jl      .invalid_param
    cmp     byte [rcx + AV1_FRAME_USING_QMATRIX], 0
    jne     .unsupported
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], AV1_LOOP_FILTER_LEVEL_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], AV1_LOOP_FILTER_LEVEL_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_LEVEL_U], AV1_LOOP_FILTER_LEVEL_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_LEVEL_V], AV1_LOOP_FILTER_LEVEL_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_SHARPNESS], 7
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 1
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    jne     .check_loop_filter_delta_done
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 1
    jne     .check_loop_filter_delta_done
    xor     r11d, r11d
.check_loop_filter_ref_delta_loop:
    cmp     r11d, AV1_LOOP_FILTER_REF_DELTA_COUNT
    jae     .check_loop_filter_mode_delta_start
    mov     eax, [rcx + AV1_FRAME_LOOP_FILTER_REF_DELTAS + r11 * 4]
    cmp     eax, AV1_LOOP_FILTER_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_LOOP_FILTER_DELTA_MAX
    jl      .invalid_param
    inc     r11d
    jmp     .check_loop_filter_ref_delta_loop
.check_loop_filter_mode_delta_start:
    xor     r11d, r11d
.check_loop_filter_mode_delta_loop:
    cmp     r11d, AV1_LOOP_FILTER_MODE_DELTA_COUNT
    jae     .check_loop_filter_delta_done
    mov     eax, [rcx + AV1_FRAME_LOOP_FILTER_MODE_DELTAS + r11 * 4]
    cmp     eax, AV1_LOOP_FILTER_DELTA_MAX
    jg      .invalid_param
    cmp     eax, -AV1_LOOP_FILTER_DELTA_MAX
    jl      .invalid_param
    inc     r11d
    jmp     .check_loop_filter_mode_delta_loop
.check_loop_filter_delta_done:
    cmp     byte [rdx + AV1_SEQ_ENABLE_CDEF], 1
    jne     .check_cdef_done
    cmp     byte [rcx + AV1_FRAME_ALLOW_INTRABC], 1
    je      .check_cdef_done
    cmp     byte [rcx + AV1_FRAME_CDEF_DAMPING], AV1_CDEF_DAMPING_MIN
    jb      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_DAMPING], AV1_CDEF_DAMPING_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_BITS], AV1_CDEF_BITS_MAX
    ja      .invalid_param
    movzx   eax, byte [rcx + AV1_FRAME_CDEF_BITS]
    mov     ebx, 1
    cmp     eax, 0
    je      .check_cdef_count_done
    mov     ebx, 2
    cmp     eax, 1
    je      .check_cdef_count_done
    mov     ebx, 4
    cmp     eax, 2
    je      .check_cdef_count_done
    mov     ebx, AV1_CDEF_ENTRY_MAX
.check_cdef_count_done:
    xor     r11d, r11d
.check_cdef_loop:
    cmp     r11d, ebx
    jae     .check_cdef_done
    cmp     byte [rcx + AV1_FRAME_CDEF_Y_PRI + r11], AV1_CDEF_PRI_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_Y_SEC + r11], AV1_CDEF_SEC_SKIP
    je      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_Y_SEC + r11], AV1_CDEF_SEC_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_UV_PRI + r11], AV1_CDEF_PRI_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_UV_SEC + r11], AV1_CDEF_SEC_SKIP
    je      .invalid_param
    cmp     byte [rcx + AV1_FRAME_CDEF_UV_SEC + r11], AV1_CDEF_SEC_MAX
    ja      .invalid_param
    inc     r11d
    jmp     .check_cdef_loop
.check_cdef_done:
    cmp     byte [rdx + AV1_SEQ_ENABLE_RESTORATION], 1
    jne     .check_restoration_done
    cmp     byte [rcx + AV1_FRAME_ALLOW_INTRABC], 1
    je      .check_restoration_done
    cmp     byte [rcx + AV1_FRAME_RESTORATION_Y], AV1_RESTORATION_TYPE_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_RESTORATION_U], AV1_RESTORATION_TYPE_MAX
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_RESTORATION_V], AV1_RESTORATION_TYPE_MAX
    ja      .invalid_param
    cmp     byte [rdx + AV1_SEQ_MONO_CHROME], 1
    jne     .check_restoration_units
    cmp     byte [rcx + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    jne     .invalid_param
    cmp     byte [rcx + AV1_FRAME_RESTORATION_V], AV1_RESTORE_NONE
    jne     .invalid_param
.check_restoration_units:
    cmp     byte [rcx + AV1_FRAME_RESTORATION_Y], AV1_RESTORE_NONE
    je      .check_restoration_unit_u
    cmp     byte [rcx + AV1_FRAME_RESTORATION_UNIT_Y], AV1_RESTORATION_UNIT_MAX
    ja      .invalid_param
.check_restoration_unit_u:
    cmp     byte [rcx + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    je      .check_restoration_unit_v
    cmp     byte [rcx + AV1_FRAME_RESTORATION_UNIT_U], AV1_RESTORATION_UNIT_MAX
    ja      .invalid_param
.check_restoration_unit_v:
    cmp     byte [rcx + AV1_FRAME_RESTORATION_V], AV1_RESTORE_NONE
    je      .check_restoration_done
    cmp     byte [rcx + AV1_FRAME_RESTORATION_UNIT_V], AV1_RESTORATION_UNIT_MAX
    ja      .invalid_param
.check_restoration_done:
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
    cmp     byte [rdx + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .params_ok
    mov     eax, [rcx + AV1_FRAME_SUPERRES_DENOM]
    test    eax, eax
    jz      .params_ok
    cmp     eax, AV1_SUPERRES_NUM
    je      .params_ok
    cmp     eax, AV1_SUPERRES_DENOM_MIN
    jb      .invalid_param
    cmp     eax, AV1_SUPERRES_DENOM_MAX
    ja      .invalid_param
    mov     eax, [rcx + AV1_FRAME_RENDER_WIDTH]
    cmp     eax, [rcx + AV1_FRAME_WIDTH]
    jbe     .invalid_param
    mov     eax, [rcx + AV1_FRAME_RENDER_HEIGHT]
    cmp     eax, [rcx + AV1_FRAME_HEIGHT]
    jne     .unsupported
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
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    jne     .bytes_written
    mov     esi, [r13 + AV1_FRAME_DISPLAY_FRAME_ID]
    movzx   edx, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    add     dl, [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
    mov     rdi, rsp
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
    jne     .write_frame_id
    mov     esi, [r13 + AV1_FRAME_ORDER_HINT]
    movzx   edx, byte [r12 + AV1_SEQ_ORDER_HINT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.write_frame_id:
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    jne     .write_frame_size_override
    mov     esi, [r13 + AV1_FRAME_CURRENT_FRAME_ID]
    movzx   edx, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    add     dl, [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
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
    jne     .write_superres
    mov     esi, [r13 + AV1_FRAME_WIDTH]
    cmp     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .write_frame_width
    mov     eax, [r13 + AV1_FRAME_SUPERRES_DENOM]
    cmp     eax, AV1_SUPERRES_NUM
    jbe     .write_frame_width
    mov     esi, [r13 + AV1_FRAME_RENDER_WIDTH]
.write_frame_width:
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
.write_superres:
    cmp     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .write_render_size
    mov     ebx, [r13 + AV1_FRAME_SUPERRES_DENOM]
    cmp     ebx, AV1_SUPERRES_NUM
    jbe     .write_superres_inactive
    write_bits 1, 1
    mov     esi, ebx
    sub     esi, AV1_SUPERRES_DENOM_MIN
    mov     rdi, rsp
    mov     edx, AV1_SUPERRES_DENOM_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    jmp     .write_render_size
.write_superres_inactive:
    write_bits 0, 1
.write_render_size:
    cmp     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .write_render_size_compare
    mov     eax, [r13 + AV1_FRAME_SUPERRES_DENOM]
    cmp     eax, AV1_SUPERRES_NUM
    jbe     .write_render_size_compare
    mov     eax, [r13 + AV1_FRAME_RENDER_HEIGHT]
    cmp     eax, [r13 + AV1_FRAME_HEIGHT]
    jne     .unsupported
    write_bits 0, 1
    jmp     .write_intrabc
.write_render_size_compare:
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

.write_quantization:
    movzx   esi, byte [r13 + AV1_FRAME_BASE_Q_IDX]
    mov     rdi, rsp
    mov     edx, AV1_QUANT_BASE_Q_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    write_delta_q_from AV1_FRAME_DELTA_Q_Y_DC
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_qmatrix
    write_delta_q_from AV1_FRAME_DELTA_Q_U_DC
    write_delta_q_from AV1_FRAME_DELTA_Q_U_AC
    cmp     byte [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    jne     .write_qmatrix
    write_delta_q_from AV1_FRAME_DELTA_Q_V_DC
    write_delta_q_from AV1_FRAME_DELTA_Q_V_AC
.write_qmatrix:
    cmp     byte [r13 + AV1_FRAME_USING_QMATRIX], 0
    jne     .unsupported
    write_bits 0, 1
    jmp     .write_segmentation

.write_segmentation:
    movzx   esi, byte [r13 + AV1_FRAME_SEGMENTATION_ENABLED]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_SEGMENTATION_ENABLED], 1
    jne     .write_delta_q_params
    cmp     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
    je      .write_segmentation_data
    movzx   esi, byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_MAP]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_MAP], 1
    jne     .write_segmentation_temporal_done
    movzx   esi, byte [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
.write_segmentation_temporal_done:
    movzx   esi, byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_DATA]
    cmp     esi, 1
    jne     .unsupported
    write_one_from_esi
.write_segmentation_data:
    xor     ebx, ebx
.write_segmentation_segment_loop:
    cmp     ebx, AV1_SEGMENT_MAX_SEGMENTS
    jae     .write_delta_q_params
    write_segment_feature AV1_SEGMENT_FEATURE_ALT_Q, AV1_SEGMENT_ALT_Q_BITS, AV1_SEGMENT_ALT_Q_MAX, 1
    write_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_Y_V, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    write_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_Y_H, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    write_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_U, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    write_segment_feature AV1_SEGMENT_FEATURE_ALT_LF_V, AV1_SEGMENT_ALT_LF_BITS, AV1_SEGMENT_ALT_LF_MAX, 1
    write_segment_feature AV1_SEGMENT_FEATURE_REF_FRAME, AV1_SEGMENT_REF_FRAME_BITS, AV1_SEGMENT_REF_FRAME_MAX, 0
    write_segment_feature AV1_SEGMENT_FEATURE_SKIP, AV1_SEGMENT_SKIP_BITS, AV1_SEGMENT_SKIP_MAX, 0
    write_segment_feature AV1_SEGMENT_FEATURE_GLOBALMV, AV1_SEGMENT_GLOBALMV_BITS, AV1_SEGMENT_GLOBALMV_MAX, 0
    inc     ebx
    jmp     .write_segmentation_segment_loop

.write_delta_q_params:
    cmp     byte [r13 + AV1_FRAME_BASE_Q_IDX], 0
    je      .write_delta_zero
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_Q_PRESENT]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_DELTA_Q_PRESENT], 1
    jne     .write_delta_lf_zero_required
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_Q_RES]
    cmp     esi, AV1_DELTA_Q_RES_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_DELTA_Q_RES_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_LF_PRESENT]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_PRESENT], 1
    jne     .write_loop_filter
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_LF_RES]
    cmp     esi, AV1_DELTA_LF_RES_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_DELTA_LF_RES_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_LF_MULTI]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    jmp     .write_loop_filter
.write_delta_lf_zero_required:
    cmp     byte [r13 + AV1_FRAME_DELTA_Q_RES], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_PRESENT], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_RES], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_MULTI], 0
    jne     .invalid_param
    jmp     .write_loop_filter
.write_delta_zero:
    cmp     byte [r13 + AV1_FRAME_DELTA_Q_PRESENT], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_Q_RES], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_PRESENT], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_RES], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_MULTI], 0
    jne     .invalid_param
    jmp     .write_loop_filter

.write_loop_filter:
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .write_cdef
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V]
    mov     rdi, rsp
    mov     edx, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H]
    mov     rdi, rsp
    mov     edx, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_loop_filter_sharpness
    movzx   eax, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V]
    movzx   ecx, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H]
    or      eax, ecx
    jz      .write_loop_filter_sharpness
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U]
    mov     rdi, rsp
    mov     edx, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V]
    mov     rdi, rsp
    mov     edx, AV1_LOOP_FILTER_LEVEL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_loop_filter_sharpness:
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_SHARPNESS]
    mov     rdi, rsp
    mov     edx, AV1_LOOP_FILTER_SHARPNESS_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    jne     .write_cdef
    movzx   esi, byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 1
    jne     .write_cdef
    xor     ebx, ebx
.write_loop_filter_ref_delta_loop:
    cmp     ebx, AV1_LOOP_FILTER_REF_DELTA_COUNT
    jae     .write_loop_filter_mode_delta_start
    write_loop_filter_delta_value AV1_FRAME_LOOP_FILTER_REF_DELTAS
    inc     ebx
    jmp     .write_loop_filter_ref_delta_loop
.write_loop_filter_mode_delta_start:
    xor     ebx, ebx
.write_loop_filter_mode_delta_loop:
    cmp     ebx, AV1_LOOP_FILTER_MODE_DELTA_COUNT
    jae     .write_cdef
    write_loop_filter_delta_value AV1_FRAME_LOOP_FILTER_MODE_DELTAS
    inc     ebx
    jmp     .write_loop_filter_mode_delta_loop

.write_cdef:
    cmp     byte [r12 + AV1_SEQ_ENABLE_CDEF], 1
    jne     .write_restoration
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .write_restoration
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_DAMPING]
    cmp     esi, AV1_CDEF_DAMPING_MIN
    jb      .invalid_param
    cmp     esi, AV1_CDEF_DAMPING_MAX
    ja      .invalid_param
    sub     esi, AV1_CDEF_DAMPING_MIN
    mov     rdi, rsp
    mov     edx, AV1_CDEF_DAMPING_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_BITS]
    cmp     esi, AV1_CDEF_BITS_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_CDEF_BITS_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   eax, byte [r13 + AV1_FRAME_CDEF_BITS]
    mov     r14d, 1
    cmp     eax, 0
    je      .write_cdef_count_done
    mov     r14d, 2
    cmp     eax, 1
    je      .write_cdef_count_done
    mov     r14d, 4
    cmp     eax, 2
    je      .write_cdef_count_done
    mov     r14d, AV1_CDEF_ENTRY_MAX
.write_cdef_count_done:
    xor     ebx, ebx
.write_cdef_loop:
    cmp     ebx, r14d
    jae     .write_restoration
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_Y_PRI + rbx]
    mov     rdi, rsp
    mov     edx, AV1_CDEF_PRI_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_Y_SEC + rbx]
    cmp     esi, AV1_CDEF_SEC_SKIP
    je      .invalid_param
    cmp     esi, AV1_CDEF_SEC_MAX
    ja      .invalid_param
    cmp     esi, AV1_CDEF_SEC_MAX
    jne     .write_cdef_y_sec
    mov     esi, AV1_CDEF_SEC_SKIP
.write_cdef_y_sec:
    mov     rdi, rsp
    mov     edx, AV1_CDEF_SEC_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_UV_PRI + rbx]
    mov     rdi, rsp
    mov     edx, AV1_CDEF_PRI_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_UV_SEC + rbx]
    cmp     esi, AV1_CDEF_SEC_SKIP
    je      .invalid_param
    cmp     esi, AV1_CDEF_SEC_MAX
    ja      .invalid_param
    cmp     esi, AV1_CDEF_SEC_MAX
    jne     .write_cdef_uv_sec
    mov     esi, AV1_CDEF_SEC_SKIP
.write_cdef_uv_sec:
    mov     rdi, rsp
    mov     edx, AV1_CDEF_SEC_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    inc     ebx
    jmp     .write_cdef_loop

.write_restoration:
    cmp     byte [r12 + AV1_SEQ_ENABLE_RESTORATION], 1
    jne     .write_transform_ref
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .write_transform_ref
    movzx   esi, byte [r13 + AV1_FRAME_RESTORATION_Y]
    cmp     esi, AV1_RESTORATION_TYPE_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_RESTORATION_TYPE_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_restoration_units
    movzx   esi, byte [r13 + AV1_FRAME_RESTORATION_U]
    cmp     esi, AV1_RESTORATION_TYPE_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_RESTORATION_TYPE_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r13 + AV1_FRAME_RESTORATION_V]
    cmp     esi, AV1_RESTORATION_TYPE_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_RESTORATION_TYPE_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_restoration_units:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_Y], AV1_RESTORE_NONE
    je      .write_restoration_unit_u
    movzx   esi, byte [r13 + AV1_FRAME_RESTORATION_UNIT_Y]
    cmp     esi, AV1_RESTORATION_UNIT_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_RESTORATION_UNIT_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_restoration_unit_u:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    je      .write_restoration_unit_v
    movzx   esi, byte [r13 + AV1_FRAME_RESTORATION_UNIT_U]
    cmp     esi, AV1_RESTORATION_UNIT_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_RESTORATION_UNIT_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_restoration_unit_v:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_V], AV1_RESTORE_NONE
    je      .write_transform_ref
    movzx   esi, byte [r13 + AV1_FRAME_RESTORATION_UNIT_V]
    cmp     esi, AV1_RESTORATION_UNIT_MAX
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_RESTORATION_UNIT_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.write_transform_ref:
    movzx   esi, byte [r13 + AV1_FRAME_TX_MODE]
    cmp     esi, AV1_TX_MODE_SELECT
    je      .write_tx_select
    cmp     esi, AV1_TX_MODE_LARGEST
    jne     .invalid_param
    write_bits 0, 1
    jmp     .write_reference_mode
.write_tx_select:
    write_bits 1, 1
.write_reference_mode:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    je      .write_reference_select
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_SWITCH
    je      .write_reference_select
    cmp     byte [r13 + AV1_FRAME_REFERENCE_SELECT], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_SKIP_MODE_PRESENT], 0
    jne     .invalid_param
    jmp     .write_global_motion_zero_required
.write_reference_select:
    movzx   esi, byte [r13 + AV1_FRAME_REFERENCE_SELECT]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    movzx   esi, byte [r13 + AV1_FRAME_SKIP_MODE_PRESENT]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
    jmp     .write_global_motion

.write_global_motion_zero_required:
    xor     ebx, ebx
.write_global_motion_zero_type_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT
    jae     .write_global_motion_zero_param_start
    cmp     byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], AV1_GLOBAL_MOTION_IDENTITY
    jne     .invalid_param
    inc     ebx
    jmp     .write_global_motion_zero_type_loop
.write_global_motion_zero_param_start:
    xor     ebx, ebx
.write_global_motion_zero_param_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT * AV1_GLOBAL_MOTION_PARAM_COUNT
    jae     .bytes_written
    cmp     dword [r13 + AV1_FRAME_GLOBAL_MOTION_PARAMS + rbx * 4], 0
    jne     .invalid_param
    inc     ebx
    jmp     .write_global_motion_zero_param_loop

.write_global_motion:
    xor     ebx, ebx
.write_global_motion_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT
    jae     .bytes_written
    movzx   esi, byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx]
    cmp     esi, AV1_GLOBAL_MOTION_IDENTITY
    jne     .write_global_motion_nonidentity
    write_bits 0, 1
    inc     ebx
    jmp     .write_global_motion_loop
.write_global_motion_nonidentity:
    cmp     esi, AV1_GLOBAL_MOTION_AFFINE
    ja      .invalid_param
    write_bits 1, 1
    movzx   esi, byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx]
    mov     rdi, rsp
    mov     edx, AV1_GLOBAL_MOTION_TYPE_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    xor     r11d, r11d
.write_global_motion_param_loop:
    cmp     byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], AV1_GLOBAL_MOTION_TRANSLATION
    jne     .write_global_motion_rotzoom_check
    cmp     r11d, 2
    jae     .write_global_motion_next
    jmp     .write_global_motion_param
.write_global_motion_rotzoom_check:
    cmp     byte [r13 + AV1_FRAME_GLOBAL_MOTION_TYPES + rbx], AV1_GLOBAL_MOTION_ROTZOOM
    jne     .write_global_motion_affine_check
    cmp     r11d, 4
    jae     .write_global_motion_next
    jmp     .write_global_motion_param
.write_global_motion_affine_check:
    cmp     r11d, AV1_GLOBAL_MOTION_PARAM_COUNT
    jae     .write_global_motion_next
.write_global_motion_param:
    write_global_motion_param
    inc     r11d
    jmp     .write_global_motion_param_loop
.write_global_motion_next:
    inc     ebx
    jmp     .write_global_motion_loop

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
    er_stack_free AV1_BITS_SIZE + 8
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
    mov     dword [r13 + AV1_FRAME_SUPERRES_DENOM], AV1_SUPERRES_NUM
    mov     dword [r13 + AV1_FRAME_CURRENT_FRAME_ID], 0
    mov     dword [r13 + AV1_FRAME_DISPLAY_FRAME_ID], 0
    mov     byte [r13 + AV1_FRAME_BASE_Q_IDX], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_Y_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_U_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_U_AC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_V_DC], 0
    mov     dword [r13 + AV1_FRAME_DELTA_Q_V_AC], 0
    mov     byte [r13 + AV1_FRAME_USING_QMATRIX], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_SHARPNESS], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 0
    mov     byte [r13 + AV1_FRAME_CDEF_DAMPING], 0
    mov     byte [r13 + AV1_FRAME_CDEF_BITS], 0
    xor     ebx, ebx
.reduced_cdef_zero_loop:
    cmp     ebx, AV1_CDEF_ENTRY_MAX
    jae     .reduced_cdef_zero_done
    mov     byte [r13 + AV1_FRAME_CDEF_Y_PRI + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_Y_SEC + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_UV_PRI + rbx], 0
    mov     byte [r13 + AV1_FRAME_CDEF_UV_SEC + rbx], 0
    inc     ebx
    jmp     .reduced_cdef_zero_loop
.reduced_cdef_zero_done:
    mov     byte [r13 + AV1_FRAME_RESTORATION_Y], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_V], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_Y], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_U], 0
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_V], 0
    zero_segmentation_state
    zero_delta_state
    zero_transform_ref_state
    zero_global_motion_state

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
