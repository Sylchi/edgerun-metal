; EdgeRun AV1 reduced-still frame header decoder/encoder — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written

%macro read_bits 1
    mov     rdi, rsp
    mov     esi, %1
    call    er_av1_bits_read
    er_check_nonzero edx, .done
%endmacro

%macro call_read_bit 0
    read_bits 1
%endmacro

%macro write_esi_bits 1
    mov     rdi, rsp
    mov     edx, %1
    call    er_av1_bits_write
    er_check_nonzero edx, .done
%endmacro

%macro write_bits 2
    mov     esi, %1
    write_esi_bits %2
%endmacro

%macro write_one_from_esi 0
    write_esi_bits 1
%endmacro

%macro write_byte_field_bits 2
    movzx   esi, byte [r13 + %1]
    write_esi_bits %2
%endmacro

%macro write_bit_field 1
    movzx   esi, byte [r13 + %1]
    cmp     esi, 1
    ja      .invalid_param
    write_one_from_esi
%endmacro

%macro write_byte_field_max_bits 3
    movzx   esi, byte [r13 + %1]
    cmp     esi, %2
    ja      .invalid_param
    write_esi_bits %3
%endmacro

%macro write_byte_field_range_offset_bits 4
    movzx   esi, byte [r13 + %1]
    cmp     esi, %2
    jb      .invalid_param
    cmp     esi, %3
    ja      .invalid_param
    sub     esi, %2
    write_esi_bits %4
%endmacro

%macro write_dword_field_max_bits 3
    mov     esi, [r13 + %1]
    cmp     esi, %2
    ja      .invalid_param
    write_esi_bits %3
%endmacro

%macro write_cdef_sec_field 1
    movzx   esi, byte [r13 + %1 + rbx]
    cmp     esi, AV1_CDEF_SEC_SKIP
    je      .invalid_param
    cmp     esi, AV1_CDEF_SEC_MAX
    ja      .invalid_param
    cmp     esi, AV1_CDEF_SEC_MAX
    jne     %%ready
    mov     esi, AV1_CDEF_SEC_SKIP
%%ready:
    write_esi_bits AV1_CDEF_SEC_BITS
%endmacro

%macro check_byte_max_rcx 2
    cmp     byte [rcx + %1], %2
    ja      .invalid_param
%endmacro

%macro check_byte_max_r13 2
    cmp     byte [r13 + %1], %2
    ja      .invalid_param
%endmacro

%macro check_byte_zero_rcx 1
    cmp     byte [rcx + %1], 0
    jne     .invalid_param
%endmacro

%macro check_byte_zero_r13 1
    cmp     byte [r13 + %1], 0
    jne     .invalid_param
%endmacro

%macro check_dword_signed_rcx 2
    mov     eax, [rcx + %1]
    cmp     eax, %2
    jg      .invalid_param
    cmp     eax, -%2
    jl      .invalid_param
%endmacro

%macro check_eax_signed_range 1
    cmp     eax, %1
    jg      .invalid_param
    cmp     eax, -%1
    jl      .invalid_param
%endmacro

%macro read_delta_q_to 1
    call_read_bit
    er_check_zero eax, %%zero
    read_bits AV1_QUANT_DELTA_BITS
    mov     ecx, eax
    er_check_zero ecx, %%store
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    er_check_zero eax, %%store
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
    er_check_nonzero esi, %%nonzero
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
    write_esi_bits AV1_QUANT_DELTA_BITS
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

%macro zero_motion_tool_state 0
    mov     byte [r13 + AV1_FRAME_ALLOW_WARPED_MOTION], 0
    mov     byte [r13 + AV1_FRAME_REDUCED_TX_SET], 0
    mov     byte [r13 + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_EIGHTTAP
%endmacro

%macro zero_film_grain_state 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_APPLY], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_UPDATE], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_REF_IDX], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_SCALING_MINUS_8], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_AR_LAG], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_AR_SHIFT_MINUS_6], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_SCALE_SHIFT], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_OVERLAP], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_CLIP_RESTRICTED], 0
    mov     dword [r13 + AV1_FRAME_FILM_GRAIN_CB_OFFSET], 0
    mov     dword [r13 + AV1_FRAME_FILM_GRAIN_CR_OFFSET], 0
    mov     dword [r13 + AV1_FRAME_FILM_GRAIN_SEED], 0
%endmacro

%macro read_film_grain_point 2
    read_bits AV1_FILM_GRAIN_POINT_VALUE_BITS
    mov     [r13 + %1 + rbx], al
    read_bits AV1_FILM_GRAIN_POINT_SCALING_BITS
    mov     [r13 + %2 + rbx], al
%endmacro

%macro read_film_grain_points 3
    xor     ebx, ebx
%%loop:
    cmp     bl, [r13 + %1]
    jae     %%done
    read_film_grain_point %2, %3
    inc     ebx
    jmp     %%loop
%%done:
%endmacro

%macro write_film_grain_point 2
    movzx   esi, byte [r13 + %1 + rbx]
    write_esi_bits AV1_FILM_GRAIN_POINT_VALUE_BITS
    movzx   esi, byte [r13 + %2 + rbx]
    write_esi_bits AV1_FILM_GRAIN_POINT_SCALING_BITS
%endmacro

%macro write_film_grain_points 3
    xor     ebx, ebx
%%loop:
    cmp     bl, [r13 + %1]
    jae     %%done
    write_film_grain_point %2, %3
    inc     ebx
    jmp     %%loop
%%done:
%endmacro

%macro read_film_grain_ar_coeff 1
    read_bits AV1_FILM_GRAIN_AR_COEFF_BITS
    sub     eax, AV1_FILM_GRAIN_AR_COEFF_BIAS
    mov     [r13 + %1 + rbx * 4], eax
%endmacro

%macro read_film_grain_ar_coeffs 2
    xor     ebx, ebx
%%loop:
    cmp     ebx, %2
    jae     %%done
    read_film_grain_ar_coeff %1
    inc     ebx
    jmp     %%loop
%%done:
%endmacro

%macro write_film_grain_ar_coeff 1
    mov     esi, [r13 + %1 + rbx * 4]
    cmp     esi, AV1_FILM_GRAIN_AR_COEFF_MAX
    jg      .invalid_param
    cmp     esi, AV1_FILM_GRAIN_AR_COEFF_MIN
    jl      .invalid_param
    add     esi, AV1_FILM_GRAIN_AR_COEFF_BIAS
    write_esi_bits AV1_FILM_GRAIN_AR_COEFF_BITS
%endmacro

%macro write_film_grain_ar_coeffs 2
    xor     ebx, ebx
%%loop:
    cmp     ebx, %2
    jae     %%done
    write_film_grain_ar_coeff %1
    inc     ebx
    jmp     %%loop
%%done:
%endmacro

%macro read_segment_feature 4
    call_read_bit
    er_check_zero eax, %%disabled
    mov     al, [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx]
    or      al, 1 << %1
    mov     [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx], al
%if %2 = 0
    mov     eax, ebx
    shl     eax, AV1_SEGMENT_FEATURE_DATA_SHIFT
    mov     dword [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rax + (%1 * 4)], 0
%else
    read_bits %2
    cmp     eax, %3
    ja      .corrupt
    mov     ecx, eax
%if %4 = 1
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    er_check_zero eax, %%store
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
    er_check_zero eax, %%zero
    read_bits AV1_LOOP_FILTER_DELTA_BITS
    cmp     eax, AV1_LOOP_FILTER_DELTA_MAX
    ja      .corrupt
    mov     ecx, eax
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    er_check_zero eax, %%store
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
    er_check_nonzero esi, %%nonzero
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
    write_esi_bits AV1_LOOP_FILTER_DELTA_BITS
    xor     esi, esi
    cmp     dword [r13 + %1 + rbx * 4], 0
    jns     %%sign_ready
    mov     esi, 1
%%sign_ready:
    write_one_from_esi
%%done:
%endmacro

%macro read_global_motion_param 0
    read_bits AV1_GLOBAL_MOTION_PARAM_BITS
    mov     ecx, eax
    mov     [rsp + AV1_BITS_SIZE], ecx
    call_read_bit
    mov     ecx, [rsp + AV1_BITS_SIZE]
    er_check_zero eax, %%store
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
    write_esi_bits AV1_GLOBAL_MOTION_PARAM_BITS
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
    write_esi_bits %2
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
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 0
    jne     .unsupported
    mov     r12, rdx
    mov     r13, rcx
    mov     r14d, esi
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    er_check_nonzero edx, .done

    call_read_bit
    mov     [r13 + AV1_FRAME_SHOW_EXISTING_FRAME], al
    er_check_nonzero eax, .show_existing_frame

    read_bits AV1_FRAME_TYPE_BITS
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
    er_check_nonzero eax, .shown_frame
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
    er_check_nonzero eax, .intra_shown_frame
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
    er_check_nonzero edx, .done
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
    er_check_nonzero edx, .done
    mov     [r13 + AV1_FRAME_CURRENT_FRAME_ID], eax

.primary_ref:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    je      .frame_size_override
    cmp     byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], 1
    je      .primary_ref_none
    read_bits AV1_FRAME_PRIMARY_REF_BITS
    mov     [r13 + AV1_FRAME_PRIMARY_REF_FRAME], al
    jmp     .refresh_flags
.primary_ref_none:
    mov     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
.refresh_flags:
    read_bits AV1_FRAME_REFRESH_FLAGS_BITS
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

    er_check_zero eax, .integer_mv_select_done
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
    read_bits AV1_FRAME_REF_INDEX_BITS
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX0], al
    read_bits AV1_FRAME_REF_INDEX_BITS
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX1], al
    read_bits AV1_FRAME_REF_INDEX_BITS
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX2], al
    read_bits AV1_FRAME_REF_INDEX_BITS
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX3], al
    read_bits AV1_FRAME_REF_INDEX_BITS
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX4], al
    read_bits AV1_FRAME_REF_INDEX_BITS
    mov     [r13 + AV1_FRAME_REF_FRAME_IDX5], al
    read_bits AV1_FRAME_REF_INDEX_BITS
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
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_WIDTH], eax

    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_HEIGHT], eax

.read_superres:
    mov     r15d, [r13 + AV1_FRAME_WIDTH]
    mov     dword [r13 + AV1_FRAME_SUPERRES_DENOM], AV1_SUPERRES_NUM
    cmp     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .read_render_size
    call_read_bit
    er_check_zero eax, .read_render_size
    read_bits AV1_SUPERRES_DENOM_BITS
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
    er_check_zero eax, .corrupt
    mov     [r13 + AV1_FRAME_WIDTH], eax

.read_render_size:
    call_read_bit
    er_check_nonzero eax, .render_different
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], r15d
    mov     eax, [r13 + AV1_FRAME_HEIGHT]
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax
    jmp     .allow_intrabc

.render_different:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
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
    read_bits AV1_TILE_LOG2_BITS
    cmp     eax, AV1_TILE_LOG2_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2], al
    mov     ecx, eax
    mov     eax, 1
    shl     eax, cl
    mov     [r13 + AV1_FRAME_TILE_INFO_COLS], eax
    read_bits AV1_TILE_LOG2_BITS
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
    er_check_zero ebx, .read_tile_size_bytes
    read_bits ebx
    mov     [r13 + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], eax
.read_tile_size_bytes:
    read_bits AV1_TILE_SIZE_BYTES_BITS
    inc     eax
    mov     [r13 + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], al

.read_quantization:
    read_bits AV1_QUANT_BASE_Q_BITS
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
    er_check_nonzero eax, .read_qmatrix_levels
    mov     byte [r13 + AV1_FRAME_QM_Y], 0
    mov     byte [r13 + AV1_FRAME_QM_U], 0
    mov     byte [r13 + AV1_FRAME_QM_V], 0
    jmp     .read_segmentation
.read_qmatrix_levels:
    read_bits AV1_QM_LEVEL_BITS
    mov     [r13 + AV1_FRAME_QM_Y], al
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_qmatrix_mono
    read_bits AV1_QM_LEVEL_BITS
    mov     [r13 + AV1_FRAME_QM_U], al
    cmp     byte [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    jne     .read_qmatrix_copy_v
    read_bits AV1_QM_LEVEL_BITS
    mov     [r13 + AV1_FRAME_QM_V], al
    jmp     .read_segmentation
.read_qmatrix_copy_v:
    mov     al, [r13 + AV1_FRAME_QM_U]
    mov     [r13 + AV1_FRAME_QM_V], al
    jmp     .read_segmentation
.read_qmatrix_mono:
    mov     byte [r13 + AV1_FRAME_QM_U], 0
    mov     byte [r13 + AV1_FRAME_QM_V], 0
    jmp     .read_segmentation

.read_segmentation:
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_ENABLED], al
    er_check_nonzero eax, .read_segmentation_enabled
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
    er_check_zero eax, .read_segmentation_temporal_zero
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], al
    jmp     .read_segmentation_update_data
.read_segmentation_temporal_zero:
    mov     byte [r13 + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], 0
.read_segmentation_update_data:
    call_read_bit
    mov     [r13 + AV1_FRAME_SEGMENTATION_UPDATE_DATA], al
    er_check_zero eax, .read_segmentation_no_update_data
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
.read_segmentation_no_update_data:
    xor     ebx, ebx
.read_segmentation_no_update_mask_loop:
    cmp     ebx, AV1_SEGMENT_MAX_SEGMENTS
    jae     .read_segmentation_no_update_data_loop_start
    mov     byte [r13 + AV1_FRAME_SEGMENT_FEATURE_MASKS + rbx], 0
    inc     ebx
    jmp     .read_segmentation_no_update_mask_loop
.read_segmentation_no_update_data_loop_start:
    xor     ebx, ebx
.read_segmentation_no_update_data_loop:
    cmp     ebx, AV1_SEGMENT_MAX_SEGMENTS * AV1_SEGMENT_FEATURE_COUNT
    jae     .read_delta_q_params
    mov     dword [r13 + AV1_FRAME_SEGMENT_FEATURE_DATA + rbx * 4], 0
    inc     ebx
    jmp     .read_segmentation_no_update_data_loop

.read_delta_q_params:
    cmp     byte [r13 + AV1_FRAME_BASE_Q_IDX], 0
    je      .read_delta_zero
    call_read_bit
    mov     [r13 + AV1_FRAME_DELTA_Q_PRESENT], al
    er_check_zero eax, .read_delta_q_res_zero
    read_bits AV1_DELTA_Q_RES_BITS
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
    er_check_zero eax, .read_delta_lf_zero_res
    read_bits AV1_DELTA_LF_RES_BITS
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
    read_bits AV1_LOOP_FILTER_LEVEL_BITS
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], al
    read_bits AV1_LOOP_FILTER_LEVEL_BITS
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], al
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_loop_filter_chroma_zero
    movzx   eax, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V]
    movzx   ecx, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H]
    or      eax, ecx
    jz      .read_loop_filter_chroma_zero
    read_bits AV1_LOOP_FILTER_LEVEL_BITS
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], al
    read_bits AV1_LOOP_FILTER_LEVEL_BITS
    mov     [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], al
    jmp     .read_loop_filter_sharpness
.read_loop_filter_chroma_zero:
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_U], 0
    mov     byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_V], 0
.read_loop_filter_sharpness:
    read_bits AV1_LOOP_FILTER_SHARPNESS_BITS
    mov     [r13 + AV1_FRAME_LOOP_FILTER_SHARPNESS], al
    call_read_bit
    mov     [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], al
    er_check_nonzero eax, .read_loop_filter_delta_update
    zero_loop_filter_delta_state
    jmp     .read_cdef
.read_loop_filter_delta_update:
    call_read_bit
    mov     [r13 + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], al
    er_check_zero eax, .read_loop_filter_delta_zero
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
    read_bits AV1_CDEF_DAMPING_BITS
    add     eax, AV1_CDEF_DAMPING_MIN
    mov     [r13 + AV1_FRAME_CDEF_DAMPING], al
    read_bits AV1_CDEF_BITS_BITS
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
    read_bits AV1_CDEF_PRI_BITS
    mov     [r13 + AV1_FRAME_CDEF_Y_PRI + rbx], al
    read_bits AV1_CDEF_SEC_BITS
    cmp     eax, AV1_CDEF_SEC_SKIP
    jne     .read_cdef_y_sec_store
    inc     eax
.read_cdef_y_sec_store:
    mov     [r13 + AV1_FRAME_CDEF_Y_SEC + rbx], al
    read_bits AV1_CDEF_PRI_BITS
    mov     [r13 + AV1_FRAME_CDEF_UV_PRI + rbx], al
    read_bits AV1_CDEF_SEC_BITS
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
    read_bits AV1_RESTORATION_TYPE_BITS
    cmp     eax, AV1_RESTORATION_TYPE_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_Y], al
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_restoration_chroma_zero
    read_bits AV1_RESTORATION_TYPE_BITS
    cmp     eax, AV1_RESTORATION_TYPE_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_U], al
    read_bits AV1_RESTORATION_TYPE_BITS
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
    read_bits AV1_RESTORATION_UNIT_BITS
    cmp     eax, AV1_RESTORATION_UNIT_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_RESTORATION_UNIT_Y], al
    jmp     .read_restoration_unit_u
.read_restoration_unit_y_zero:
    mov     byte [r13 + AV1_FRAME_RESTORATION_UNIT_Y], 0
.read_restoration_unit_u:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    je      .read_restoration_unit_v
    read_bits AV1_RESTORATION_UNIT_BITS
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
    read_bits AV1_RESTORATION_UNIT_BITS
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
    er_check_zero eax, .read_tx_largest
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
    zero_motion_tool_state
    jmp     .read_film_grain
.read_reference_select:
    call_read_bit
    mov     [r13 + AV1_FRAME_REFERENCE_SELECT], al
    call_read_bit
    mov     [r13 + AV1_FRAME_SKIP_MODE_PRESENT], al
    zero_global_motion_state
    xor     ebx, ebx
.read_global_motion_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT
    jae     .read_motion_tools
    call_read_bit
    er_check_zero eax, .read_global_motion_next
    read_bits AV1_GLOBAL_MOTION_TYPE_BITS
    er_check_zero eax, .corrupt
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

.read_motion_tools:
    cmp     byte [r12 + AV1_SEQ_ENABLE_WARPED_MOTION], 1
    jne     .read_allow_warped_zero
    cmp     byte [r13 + AV1_FRAME_FORCE_INTEGER_MV], 1
    je      .read_allow_warped_zero
    call_read_bit
    mov     [r13 + AV1_FRAME_ALLOW_WARPED_MOTION], al
    jmp     .read_interpolation_filter
.read_allow_warped_zero:
    mov     byte [r13 + AV1_FRAME_ALLOW_WARPED_MOTION], 0
.read_interpolation_filter:
    cmp     byte [r12 + AV1_SEQ_ENABLE_DUAL_FILTER], 1
    jne     .read_interpolation_eighttap
    call_read_bit
    er_check_zero eax, .read_interpolation_fixed
    mov     byte [r13 + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_SWITCHABLE
    jmp     .read_reduced_tx_set
.read_interpolation_fixed:
    read_bits AV1_INTERP_FILTER_BITS
    cmp     eax, AV1_INTERP_FILTER_FIXED_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_INTERPOLATION_FILTER], al
    jmp     .read_reduced_tx_set
.read_interpolation_eighttap:
    mov     byte [r13 + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_EIGHTTAP
.read_reduced_tx_set:
    call_read_bit
    mov     [r13 + AV1_FRAME_REDUCED_TX_SET], al
    jmp     .read_film_grain

.read_film_grain:
    cmp     byte [r12 + AV1_SEQ_FILM_GRAIN], 1
    jne     .read_film_grain_zero
    cmp     byte [r13 + AV1_FRAME_SHOW_FRAME], 1
    je      .read_film_grain_apply
    cmp     byte [r13 + AV1_FRAME_SHOWABLE_FRAME], 1
    jne     .read_film_grain_zero
.read_film_grain_apply:
    call_read_bit
    mov     [r13 + AV1_FRAME_FILM_GRAIN_APPLY], al
    er_check_zero eax, .read_film_grain_zero
    read_bits AV1_FILM_GRAIN_SEED_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_SEED], eax
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    jne     .read_film_grain_update_true
    call_read_bit
    mov     [r13 + AV1_FRAME_FILM_GRAIN_UPDATE], al
    er_check_nonzero eax, .read_film_grain_points_y_count
    read_bits AV1_FILM_GRAIN_REF_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_REF_IDX], al
    jmp     .finish_header
.read_film_grain_update_true:
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_UPDATE], 1
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_REF_IDX], 0
.read_film_grain_points_y_count:
    read_bits AV1_FILM_GRAIN_Y_POINTS_BITS
    cmp     eax, AV1_FILM_GRAIN_Y_POINTS_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], al
    read_film_grain_points AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS, AV1_FRAME_FILM_GRAIN_Y_VALUES, AV1_FRAME_FILM_GRAIN_Y_SCALING
.read_film_grain_chroma_from_luma:
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_film_grain_chroma_from_luma_zero
    call_read_bit
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], al
    jmp     .read_film_grain_chroma_counts
.read_film_grain_chroma_from_luma_zero:
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 0
.read_film_grain_chroma_counts:
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .read_film_grain_chroma_counts_zero
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    je      .read_film_grain_chroma_counts_zero
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    je      .read_film_grain_chroma_counts_zero
    read_bits AV1_FILM_GRAIN_CHROMA_POINTS_BITS
    cmp     eax, AV1_FILM_GRAIN_CHROMA_POINTS_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], al
    read_film_grain_points AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS, AV1_FRAME_FILM_GRAIN_CB_VALUES, AV1_FRAME_FILM_GRAIN_CB_SCALING
.read_film_grain_cr_count:
    read_bits AV1_FILM_GRAIN_CHROMA_POINTS_BITS
    cmp     eax, AV1_FILM_GRAIN_CHROMA_POINTS_MAX
    ja      .corrupt
    mov     [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], al
    read_film_grain_points AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS, AV1_FRAME_FILM_GRAIN_CR_VALUES, AV1_FRAME_FILM_GRAIN_CR_SCALING
    jmp     .read_film_grain_scaling
.read_film_grain_chroma_counts_zero:
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    mov     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
.read_film_grain_scaling:
    read_bits AV1_FILM_GRAIN_SCALING_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_SCALING_MINUS_8], al
    read_bits AV1_FILM_GRAIN_AR_LAG_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_AR_LAG], al
    movzx   ecx, al
    lea     eax, [rcx + 1]
    imul    eax, ecx
    shl     eax, 1
    mov     r15d, eax
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    je      .read_film_grain_cb_coeffs_start
    read_film_grain_ar_coeffs AV1_FRAME_FILM_GRAIN_AR_Y_COEFFS, r15d
.read_film_grain_cb_coeffs_start:
    movzx   ecx, byte [r13 + AV1_FRAME_FILM_GRAIN_AR_LAG]
    lea     eax, [rcx + 1]
    imul    eax, ecx
    shl     eax, 1
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    je      .read_film_grain_cb_coeff_count_ready
    inc     eax
.read_film_grain_cb_coeff_count_ready:
    mov     r15d, eax
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    jne     .read_film_grain_cb_coeff_loop_start
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    jne     .read_film_grain_cr_coeffs_start
.read_film_grain_cb_coeff_loop_start:
    read_film_grain_ar_coeffs AV1_FRAME_FILM_GRAIN_AR_CB_COEFFS, r15d
.read_film_grain_cr_coeffs_start:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    jne     .read_film_grain_cr_coeff_loop_start
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    jne     .read_film_grain_shifts
.read_film_grain_cr_coeff_loop_start:
    read_film_grain_ar_coeffs AV1_FRAME_FILM_GRAIN_AR_CR_COEFFS, r15d
.read_film_grain_shifts:
    read_bits AV1_FILM_GRAIN_AR_SHIFT_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_AR_SHIFT_MINUS_6], al
    read_bits AV1_FILM_GRAIN_SCALE_SHIFT_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_SCALE_SHIFT], al
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    je      .read_film_grain_cr_mults
    read_bits AV1_FILM_GRAIN_MULT_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CB_MULT], al
    read_bits AV1_FILM_GRAIN_MULT_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CB_LUMA_MULT], al
    read_bits AV1_FILM_GRAIN_OFFSET_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CB_OFFSET], eax
.read_film_grain_cr_mults:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    je      .read_film_grain_tail
    read_bits AV1_FILM_GRAIN_MULT_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CR_MULT], al
    read_bits AV1_FILM_GRAIN_MULT_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CR_LUMA_MULT], al
    read_bits AV1_FILM_GRAIN_OFFSET_BITS
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CR_OFFSET], eax
.read_film_grain_tail:
    call_read_bit
    mov     [r13 + AV1_FRAME_FILM_GRAIN_OVERLAP], al
    call_read_bit
    mov     [r13 + AV1_FRAME_FILM_GRAIN_CLIP_RESTRICTED], al
    jmp     .finish_header
.read_film_grain_zero:
    zero_film_grain_state
    jmp     .finish_header

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
    read_bits AV1_FRAME_REF_INDEX_BITS
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
    er_check_nonzero edx, .done
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
    zero_motion_tool_state
    zero_film_grain_state
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
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 0
    jne     .unsupported
    cmp     byte [rcx + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    je      .params_ok
    check_dword_signed_rcx AV1_FRAME_DELTA_Q_Y_DC, AV1_QUANT_DELTA_MAX
    check_dword_signed_rcx AV1_FRAME_DELTA_Q_U_DC, AV1_QUANT_DELTA_MAX
    check_dword_signed_rcx AV1_FRAME_DELTA_Q_U_AC, AV1_QUANT_DELTA_MAX
    check_dword_signed_rcx AV1_FRAME_DELTA_Q_V_DC, AV1_QUANT_DELTA_MAX
    check_dword_signed_rcx AV1_FRAME_DELTA_Q_V_AC, AV1_QUANT_DELTA_MAX
    cmp     byte [rcx + AV1_FRAME_USING_QMATRIX], 1
    ja      .invalid_param
    cmp     byte [rcx + AV1_FRAME_USING_QMATRIX], 1
    jne     .check_qmatrix_done
    check_byte_max_rcx AV1_FRAME_QM_Y, AV1_QM_LEVEL_MAX
    cmp     byte [rdx + AV1_SEQ_MONO_CHROME], 1
    je      .check_qmatrix_chroma_zero
    check_byte_max_rcx AV1_FRAME_QM_U, AV1_QM_LEVEL_MAX
    check_byte_max_rcx AV1_FRAME_QM_V, AV1_QM_LEVEL_MAX
    jmp     .check_qmatrix_done
.check_qmatrix_chroma_zero:
    check_byte_zero_rcx AV1_FRAME_QM_U
    check_byte_zero_rcx AV1_FRAME_QM_V
.check_qmatrix_done:
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_LEVEL_Y_V, AV1_LOOP_FILTER_LEVEL_MAX
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_LEVEL_Y_H, AV1_LOOP_FILTER_LEVEL_MAX
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_LEVEL_U, AV1_LOOP_FILTER_LEVEL_MAX
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_LEVEL_V, AV1_LOOP_FILTER_LEVEL_MAX
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_SHARPNESS, 7
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_DELTA_ENABLED, 1
    check_byte_max_rcx AV1_FRAME_LOOP_FILTER_DELTA_UPDATE, 1
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    jne     .check_loop_filter_delta_done
    cmp     byte [rcx + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 1
    jne     .check_loop_filter_delta_done
    xor     r11d, r11d
.check_loop_filter_ref_delta_loop:
    cmp     r11d, AV1_LOOP_FILTER_REF_DELTA_COUNT
    jae     .check_loop_filter_mode_delta_start
    mov     eax, [rcx + AV1_FRAME_LOOP_FILTER_REF_DELTAS + r11 * 4]
    check_eax_signed_range AV1_LOOP_FILTER_DELTA_MAX
    inc     r11d
    jmp     .check_loop_filter_ref_delta_loop
.check_loop_filter_mode_delta_start:
    xor     r11d, r11d
.check_loop_filter_mode_delta_loop:
    cmp     r11d, AV1_LOOP_FILTER_MODE_DELTA_COUNT
    jae     .check_loop_filter_delta_done
    mov     eax, [rcx + AV1_FRAME_LOOP_FILTER_MODE_DELTAS + r11 * 4]
    check_eax_signed_range AV1_LOOP_FILTER_DELTA_MAX
    inc     r11d
    jmp     .check_loop_filter_mode_delta_loop
.check_loop_filter_delta_done:
    cmp     byte [rdx + AV1_SEQ_ENABLE_CDEF], 1
    jne     .check_cdef_done
    cmp     byte [rcx + AV1_FRAME_ALLOW_INTRABC], 1
    je      .check_cdef_done
    cmp     byte [rcx + AV1_FRAME_CDEF_DAMPING], AV1_CDEF_DAMPING_MIN
    jb      .invalid_param
    check_byte_max_rcx AV1_FRAME_CDEF_DAMPING, AV1_CDEF_DAMPING_MAX
    check_byte_max_rcx AV1_FRAME_CDEF_BITS, AV1_CDEF_BITS_MAX
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
    check_byte_max_rcx AV1_FRAME_RESTORATION_Y, AV1_RESTORATION_TYPE_MAX
    check_byte_max_rcx AV1_FRAME_RESTORATION_U, AV1_RESTORATION_TYPE_MAX
    check_byte_max_rcx AV1_FRAME_RESTORATION_V, AV1_RESTORATION_TYPE_MAX
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
    je      .check_motion_tools_zero
    cmp     eax, AV1_FRAME_TYPE_INTRA_ONLY
    je      .check_motion_tools_zero
    cmp     eax, AV1_FRAME_TYPE_INTER
    je      .check_motion_tools_inter
    cmp     eax, AV1_FRAME_TYPE_SWITCH
    je      .check_motion_tools_inter
    jmp     .unsupported
.check_motion_tools_zero:
    check_byte_zero_rcx AV1_FRAME_ALLOW_WARPED_MOTION
    check_byte_zero_rcx AV1_FRAME_REDUCED_TX_SET
    cmp     byte [rcx + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_EIGHTTAP
    jne     .invalid_param
    jmp     .check_dimensions
.check_motion_tools_inter:
    check_byte_max_rcx AV1_FRAME_ALLOW_WARPED_MOTION, 1
    check_byte_max_rcx AV1_FRAME_REDUCED_TX_SET, 1
    check_byte_max_rcx AV1_FRAME_INTERPOLATION_FILTER, AV1_INTERP_FILTER_MAX
    cmp     byte [rdx + AV1_SEQ_ENABLE_WARPED_MOTION], 1
    je      .check_motion_tools_force_integer
    check_byte_zero_rcx AV1_FRAME_ALLOW_WARPED_MOTION
    jmp     .check_motion_tools_interp
.check_motion_tools_force_integer:
    cmp     byte [rcx + AV1_FRAME_FORCE_INTEGER_MV], 1
    jne     .check_motion_tools_interp
    check_byte_zero_rcx AV1_FRAME_ALLOW_WARPED_MOTION
.check_motion_tools_interp:
    cmp     byte [rdx + AV1_SEQ_ENABLE_DUAL_FILTER], 1
    je      .check_dimensions
    cmp     byte [rcx + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_EIGHTTAP
    jne     .invalid_param
.check_dimensions:
    cmp     dword [rcx + AV1_FRAME_WIDTH], 0
    je      .invalid_param
    cmp     dword [rcx + AV1_FRAME_HEIGHT], 0
    je      .invalid_param
    cmp     byte [rdx + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .params_ok
    mov     eax, [rcx + AV1_FRAME_SUPERRES_DENOM]
    er_check_zero eax, .params_ok
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
    er_check_nonzero edx, .done

    movzx   esi, byte [r13 + AV1_FRAME_SHOW_EXISTING_FRAME]
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    jne     .write_frame_type
    write_byte_field_bits AV1_FRAME_EXISTING_FRAME_IDX, AV1_FRAME_REF_INDEX_BITS
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    jne     .bytes_written
    mov     esi, [r13 + AV1_FRAME_DISPLAY_FRAME_ID]
    movzx   edx, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    add     dl, [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    jmp     .bytes_written

.write_frame_type:
    write_byte_field_bits AV1_FRAME_TYPE, AV1_FRAME_TYPE_BITS
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
    er_check_nonzero edx, .done

.write_frame_id:
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    jne     .write_frame_size_override
    mov     esi, [r13 + AV1_FRAME_CURRENT_FRAME_ID]
    movzx   edx, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    add     dl, [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done

.write_frame_size_override:
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    je      .write_frame_size_override_bit
    cmp     byte [r13 + AV1_FRAME_ERROR_RESILIENT_MODE], 1
    je      .write_refresh_flags
    write_byte_field_bits AV1_FRAME_PRIMARY_REF_FRAME, AV1_FRAME_PRIMARY_REF_BITS
.write_refresh_flags:
    write_byte_field_bits AV1_FRAME_REFRESH_FRAME_FLAGS, AV1_FRAME_REFRESH_FLAGS_BITS

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
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX0, AV1_FRAME_REF_INDEX_BITS
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX1, AV1_FRAME_REF_INDEX_BITS
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX2, AV1_FRAME_REF_INDEX_BITS
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX3, AV1_FRAME_REF_INDEX_BITS
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX4, AV1_FRAME_REF_INDEX_BITS
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX5, AV1_FRAME_REF_INDEX_BITS
    write_byte_field_bits AV1_FRAME_REF_FRAME_IDX6, AV1_FRAME_REF_INDEX_BITS
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
    er_check_nonzero edx, .done
    mov     esi, [r13 + AV1_FRAME_HEIGHT]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
.write_superres:
    cmp     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .write_render_size
    mov     ebx, [r13 + AV1_FRAME_SUPERRES_DENOM]
    cmp     ebx, AV1_SUPERRES_NUM
    jbe     .write_superres_inactive
    write_bits 1, 1
    mov     esi, ebx
    sub     esi, AV1_SUPERRES_DENOM_MIN
    write_esi_bits AV1_SUPERRES_DENOM_BITS
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
    er_check_nonzero edx, .done
    mov     esi, [r13 + AV1_FRAME_RENDER_HEIGHT]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done

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
    write_byte_field_bits AV1_FRAME_TILE_INFO_COLS_LOG2, AV1_TILE_LOG2_BITS
    write_byte_field_bits AV1_FRAME_TILE_INFO_ROWS_LOG2, AV1_TILE_LOG2_BITS
    movzx   ebx, byte [r13 + AV1_FRAME_TILE_INFO_COLS_LOG2]
    add     bl, [r13 + AV1_FRAME_TILE_INFO_ROWS_LOG2]
    er_check_zero ebx, .write_tile_size_bytes
    mov     esi, [r13 + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID]
    mov     edx, ebx
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
.write_tile_size_bytes:
    movzx   esi, byte [r13 + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES]
    dec     esi
    write_esi_bits AV1_TILE_SIZE_BYTES_BITS

.write_quantization:
    write_byte_field_bits AV1_FRAME_BASE_Q_IDX, AV1_QUANT_BASE_Q_BITS
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
    movzx   esi, byte [r13 + AV1_FRAME_USING_QMATRIX]
    write_one_from_esi
    cmp     byte [r13 + AV1_FRAME_USING_QMATRIX], 1
    jne     .write_segmentation
    write_byte_field_bits AV1_FRAME_QM_Y, AV1_QM_LEVEL_BITS
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_segmentation
    write_byte_field_bits AV1_FRAME_QM_U, AV1_QM_LEVEL_BITS
    cmp     byte [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    jne     .write_segmentation
    write_byte_field_bits AV1_FRAME_QM_V, AV1_QM_LEVEL_BITS
    jmp     .write_segmentation

.write_segmentation:
    write_bit_field AV1_FRAME_SEGMENTATION_ENABLED
    cmp     byte [r13 + AV1_FRAME_SEGMENTATION_ENABLED], 1
    jne     .write_delta_q_params
    cmp     byte [r13 + AV1_FRAME_PRIMARY_REF_FRAME], AV1_FRAME_PRIMARY_REF_NONE
    je      .write_segmentation_data
    write_bit_field AV1_FRAME_SEGMENTATION_UPDATE_MAP
    cmp     byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_MAP], 1
    jne     .write_segmentation_temporal_done
    write_bit_field AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE
.write_segmentation_temporal_done:
    movzx   esi, byte [r13 + AV1_FRAME_SEGMENTATION_UPDATE_DATA]
    cmp     esi, 1
    ja      .invalid_param
    er_check_zero esi, .write_segmentation_no_update_data
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
.write_segmentation_no_update_data:
    write_one_from_esi
    jmp     .write_delta_q_params

.write_delta_q_params:
    cmp     byte [r13 + AV1_FRAME_BASE_Q_IDX], 0
    je      .write_delta_zero
    write_bit_field AV1_FRAME_DELTA_Q_PRESENT
    cmp     byte [r13 + AV1_FRAME_DELTA_Q_PRESENT], 1
    jne     .write_delta_lf_zero_required
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_Q_RES]
    cmp     esi, AV1_DELTA_Q_RES_MAX
    ja      .invalid_param
    write_esi_bits AV1_DELTA_Q_RES_BITS
    write_bit_field AV1_FRAME_DELTA_LF_PRESENT
    cmp     byte [r13 + AV1_FRAME_DELTA_LF_PRESENT], 1
    jne     .write_loop_filter
    movzx   esi, byte [r13 + AV1_FRAME_DELTA_LF_RES]
    cmp     esi, AV1_DELTA_LF_RES_MAX
    ja      .invalid_param
    write_esi_bits AV1_DELTA_LF_RES_BITS
    write_bit_field AV1_FRAME_DELTA_LF_MULTI
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
    write_byte_field_bits AV1_FRAME_LOOP_FILTER_LEVEL_Y_V, AV1_LOOP_FILTER_LEVEL_BITS
    write_byte_field_bits AV1_FRAME_LOOP_FILTER_LEVEL_Y_H, AV1_LOOP_FILTER_LEVEL_BITS
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_loop_filter_sharpness
    movzx   eax, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V]
    movzx   ecx, byte [r13 + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H]
    or      eax, ecx
    jz      .write_loop_filter_sharpness
    write_byte_field_bits AV1_FRAME_LOOP_FILTER_LEVEL_U, AV1_LOOP_FILTER_LEVEL_BITS
    write_byte_field_bits AV1_FRAME_LOOP_FILTER_LEVEL_V, AV1_LOOP_FILTER_LEVEL_BITS
.write_loop_filter_sharpness:
    write_byte_field_bits AV1_FRAME_LOOP_FILTER_SHARPNESS, AV1_LOOP_FILTER_SHARPNESS_BITS
    write_bit_field AV1_FRAME_LOOP_FILTER_DELTA_ENABLED
    cmp     byte [r13 + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    jne     .write_cdef
    write_bit_field AV1_FRAME_LOOP_FILTER_DELTA_UPDATE
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
    write_byte_field_range_offset_bits AV1_FRAME_CDEF_DAMPING, AV1_CDEF_DAMPING_MIN, AV1_CDEF_DAMPING_MAX, AV1_CDEF_DAMPING_BITS
    write_byte_field_max_bits AV1_FRAME_CDEF_BITS, AV1_CDEF_BITS_MAX, AV1_CDEF_BITS_BITS
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
    write_esi_bits AV1_CDEF_PRI_BITS
    write_cdef_sec_field AV1_FRAME_CDEF_Y_SEC
    movzx   esi, byte [r13 + AV1_FRAME_CDEF_UV_PRI + rbx]
    write_esi_bits AV1_CDEF_PRI_BITS
    write_cdef_sec_field AV1_FRAME_CDEF_UV_SEC
    inc     ebx
    jmp     .write_cdef_loop

.write_restoration:
    cmp     byte [r12 + AV1_SEQ_ENABLE_RESTORATION], 1
    jne     .write_transform_ref
    cmp     byte [r13 + AV1_FRAME_ALLOW_INTRABC], 1
    je      .write_transform_ref
    write_byte_field_max_bits AV1_FRAME_RESTORATION_Y, AV1_RESTORATION_TYPE_MAX, AV1_RESTORATION_TYPE_BITS
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_restoration_units
    write_byte_field_max_bits AV1_FRAME_RESTORATION_U, AV1_RESTORATION_TYPE_MAX, AV1_RESTORATION_TYPE_BITS
    write_byte_field_max_bits AV1_FRAME_RESTORATION_V, AV1_RESTORATION_TYPE_MAX, AV1_RESTORATION_TYPE_BITS
.write_restoration_units:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_Y], AV1_RESTORE_NONE
    je      .write_restoration_unit_u
    write_byte_field_max_bits AV1_FRAME_RESTORATION_UNIT_Y, AV1_RESTORATION_UNIT_MAX, AV1_RESTORATION_UNIT_BITS
.write_restoration_unit_u:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_U], AV1_RESTORE_NONE
    je      .write_restoration_unit_v
    write_byte_field_max_bits AV1_FRAME_RESTORATION_UNIT_U, AV1_RESTORATION_UNIT_MAX, AV1_RESTORATION_UNIT_BITS
.write_restoration_unit_v:
    cmp     byte [r13 + AV1_FRAME_RESTORATION_V], AV1_RESTORE_NONE
    je      .write_transform_ref
    write_byte_field_max_bits AV1_FRAME_RESTORATION_UNIT_V, AV1_RESTORATION_UNIT_MAX, AV1_RESTORATION_UNIT_BITS

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
    write_bit_field AV1_FRAME_REFERENCE_SELECT
    write_bit_field AV1_FRAME_SKIP_MODE_PRESENT
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
    jae     .write_film_grain
    cmp     dword [r13 + AV1_FRAME_GLOBAL_MOTION_PARAMS + rbx * 4], 0
    jne     .invalid_param
    inc     ebx
    jmp     .write_global_motion_zero_param_loop

.write_global_motion:
    xor     ebx, ebx
.write_global_motion_loop:
    cmp     ebx, AV1_GLOBAL_MOTION_REF_COUNT
    jae     .write_motion_tools
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
    write_esi_bits AV1_GLOBAL_MOTION_TYPE_BITS
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

.write_motion_tools:
    cmp     byte [r12 + AV1_SEQ_ENABLE_WARPED_MOTION], 1
    jne     .write_interpolation_filter
    cmp     byte [r13 + AV1_FRAME_FORCE_INTEGER_MV], 1
    je      .write_interpolation_filter
    write_bit_field AV1_FRAME_ALLOW_WARPED_MOTION
.write_interpolation_filter:
    cmp     byte [r12 + AV1_SEQ_ENABLE_DUAL_FILTER], 1
    jne     .write_reduced_tx_set
    cmp     byte [r13 + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_SWITCHABLE
    jne     .write_interpolation_fixed
    write_bits 1, 1
    jmp     .write_reduced_tx_set
.write_interpolation_fixed:
    cmp     byte [r13 + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_FIXED_MAX
    ja      .invalid_param
    write_bits 0, 1
    write_byte_field_bits AV1_FRAME_INTERPOLATION_FILTER, AV1_INTERP_FILTER_BITS
.write_reduced_tx_set:
    write_bit_field AV1_FRAME_REDUCED_TX_SET
    jmp     .write_film_grain

.write_film_grain:
    cmp     byte [r12 + AV1_SEQ_FILM_GRAIN], 1
    jne     .write_film_grain_inactive_required
    cmp     byte [r13 + AV1_FRAME_SHOW_FRAME], 1
    je      .write_film_grain_apply
    cmp     byte [r13 + AV1_FRAME_SHOWABLE_FRAME], 1
    jne     .write_film_grain_inactive_required
.write_film_grain_apply:
    write_bit_field AV1_FRAME_FILM_GRAIN_APPLY
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_APPLY], 1
    jne     .bytes_written
    mov     esi, [r13 + AV1_FRAME_FILM_GRAIN_SEED]
    write_esi_bits AV1_FILM_GRAIN_SEED_BITS
    cmp     byte [r13 + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    jne     .write_film_grain_update_required
    write_bit_field AV1_FRAME_FILM_GRAIN_UPDATE
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_UPDATE], 1
    je      .write_film_grain_y_count
    write_byte_field_bits AV1_FRAME_FILM_GRAIN_REF_IDX, AV1_FILM_GRAIN_REF_BITS
    jmp     .bytes_written
.write_film_grain_update_required:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_UPDATE], 1
    jne     .invalid_param
.write_film_grain_y_count:
    write_byte_field_max_bits AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS, AV1_FILM_GRAIN_Y_POINTS_MAX, AV1_FILM_GRAIN_Y_POINTS_BITS
    write_film_grain_points AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS, AV1_FRAME_FILM_GRAIN_Y_VALUES, AV1_FRAME_FILM_GRAIN_Y_SCALING
.write_film_grain_chroma_from_luma:
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_film_grain_chroma_counts
    write_bit_field AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA
.write_film_grain_chroma_counts:
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_film_grain_chroma_counts_zero_required
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    je      .write_film_grain_chroma_counts_zero_required
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    je      .write_film_grain_chroma_counts_zero_required
    write_byte_field_max_bits AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS, AV1_FILM_GRAIN_CHROMA_POINTS_MAX, AV1_FILM_GRAIN_CHROMA_POINTS_BITS
    write_film_grain_points AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS, AV1_FRAME_FILM_GRAIN_CB_VALUES, AV1_FRAME_FILM_GRAIN_CB_SCALING
.write_film_grain_cr_count:
    write_byte_field_max_bits AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS, AV1_FILM_GRAIN_CHROMA_POINTS_MAX, AV1_FILM_GRAIN_CHROMA_POINTS_BITS
    write_film_grain_points AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS, AV1_FRAME_FILM_GRAIN_CR_VALUES, AV1_FRAME_FILM_GRAIN_CR_SCALING
    jmp     .write_film_grain_scaling
.write_film_grain_chroma_counts_zero_required:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    jne     .invalid_param
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    jne     .invalid_param
.write_film_grain_scaling:
    write_byte_field_max_bits AV1_FRAME_FILM_GRAIN_SCALING_MINUS_8, 3, AV1_FILM_GRAIN_SCALING_BITS
    movzx   esi, byte [r13 + AV1_FRAME_FILM_GRAIN_AR_LAG]
    cmp     esi, 3
    ja      .invalid_param
    mov     r14d, esi
    write_esi_bits AV1_FILM_GRAIN_AR_LAG_BITS
    lea     eax, [r14d + 1]
    imul    eax, r14d
    shl     eax, 1
    mov     r14d, eax
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    je      .write_film_grain_cb_coeffs_start
    write_film_grain_ar_coeffs AV1_FRAME_FILM_GRAIN_AR_Y_COEFFS, r14d
.write_film_grain_cb_coeffs_start:
    movzx   ecx, byte [r13 + AV1_FRAME_FILM_GRAIN_AR_LAG]
    lea     eax, [rcx + 1]
    imul    eax, ecx
    shl     eax, 1
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 0
    je      .write_film_grain_cb_coeff_count_ready
    inc     eax
.write_film_grain_cb_coeff_count_ready:
    mov     r14d, eax
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    jne     .write_film_grain_cb_coeff_loop_start
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    jne     .write_film_grain_cr_coeffs_start
.write_film_grain_cb_coeff_loop_start:
    write_film_grain_ar_coeffs AV1_FRAME_FILM_GRAIN_AR_CB_COEFFS, r14d
.write_film_grain_cr_coeffs_start:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    jne     .write_film_grain_cr_coeff_loop_start
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    jne     .write_film_grain_shifts
.write_film_grain_cr_coeff_loop_start:
    write_film_grain_ar_coeffs AV1_FRAME_FILM_GRAIN_AR_CR_COEFFS, r14d
.write_film_grain_shifts:
    write_byte_field_max_bits AV1_FRAME_FILM_GRAIN_AR_SHIFT_MINUS_6, 3, AV1_FILM_GRAIN_AR_SHIFT_BITS
    write_byte_field_max_bits AV1_FRAME_FILM_GRAIN_SCALE_SHIFT, 3, AV1_FILM_GRAIN_SCALE_SHIFT_BITS
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    je      .write_film_grain_cr_mults
    write_byte_field_bits AV1_FRAME_FILM_GRAIN_CB_MULT, AV1_FILM_GRAIN_MULT_BITS
    write_byte_field_bits AV1_FRAME_FILM_GRAIN_CB_LUMA_MULT, AV1_FILM_GRAIN_MULT_BITS
    write_dword_field_max_bits AV1_FRAME_FILM_GRAIN_CB_OFFSET, AV1_FILM_GRAIN_OFFSET_MAX, AV1_FILM_GRAIN_OFFSET_BITS
.write_film_grain_cr_mults:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    je      .write_film_grain_tail
    write_byte_field_bits AV1_FRAME_FILM_GRAIN_CR_MULT, AV1_FILM_GRAIN_MULT_BITS
    write_byte_field_bits AV1_FRAME_FILM_GRAIN_CR_LUMA_MULT, AV1_FILM_GRAIN_MULT_BITS
    write_dword_field_max_bits AV1_FRAME_FILM_GRAIN_CR_OFFSET, AV1_FILM_GRAIN_OFFSET_MAX, AV1_FILM_GRAIN_OFFSET_BITS
.write_film_grain_tail:
    write_bit_field AV1_FRAME_FILM_GRAIN_OVERLAP
    write_bit_field AV1_FRAME_FILM_GRAIN_CLIP_RESTRICTED
    jmp     .bytes_written
.write_film_grain_inactive_required:
    cmp     byte [r13 + AV1_FRAME_FILM_GRAIN_APPLY], 0
    jne     .invalid_param
    jmp     .bytes_written

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
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 1
    jne     .unsupported
    mov     r12, rdx
    mov     r13, rcx
    mov     r14d, esi
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    er_check_nonzero edx, .done

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
    zero_motion_tool_state
    zero_film_grain_state

    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_WIDTH], eax

    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_HEIGHT], eax

    read_bits 1
    er_check_nonzero eax, .render_different
    mov     eax, [r13 + AV1_FRAME_WIDTH]
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    mov     eax, [r13 + AV1_FRAME_HEIGHT]
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax
    jmp     .allow_intrabc

.render_different:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_WIDTH], eax
    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r13 + AV1_FRAME_RENDER_HEIGHT], eax

.allow_intrabc:
    read_bits 1
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
    er_check_zero rdx, .invalid_param
    er_check_zero ecx, .invalid_param
    er_check_zero r8d, .invalid_param
    cmp     byte [rdx + AV1_SEQ_REDUCED_STILL], 1
    jne     .unsupported
    mov     r12, rdx
    mov     r13d, ecx
    mov     r14d, r8d
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    er_check_nonzero edx, .done
    mov     esi, r13d
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    mov     esi, r14d
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    er_check_nonzero edx, .done
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
