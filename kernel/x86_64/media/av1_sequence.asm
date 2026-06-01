; EdgeRun AV1 sequence header decoder/encoder — x86_64 assembly.
; Implements profile-0 sequence headers used by the reduced-still and next-stage
; non-reduced AV1 paths.

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

av1_sequence_read_uvlc:
    er_push rbx, r12
    mov     r12, rdi
    xor     ebx, ebx
.zero_loop:
    mov     rdi, r12
    mov     esi, 1
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    test    eax, eax
    jnz     .have_stop_bit
    cmp     ebx, 31
    jae     .corrupt
    inc     ebx
    jmp     .zero_loop
.have_stop_bit:
    test    ebx, ebx
    jz      .zero
    mov     rdi, r12
    mov     esi, ebx
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     ecx, ebx
    mov     ebx, 1
    shl     ebx, cl
    dec     ebx
    add     eax, ebx
    er_ok
    jmp     .done
.zero:
    xor     eax, eax
    er_ok
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12
    ret

av1_sequence_write_uvlc:
    er_push rbx, r12, r13, r14
    mov     r12, rdi
    mov     r13d, esi
    mov     eax, r13d
    inc     eax
    jz      .invalid_param
    bsr     ebx, eax
    mov     r14d, eax
    mov     ecx, ebx
    mov     eax, 1
    shl     eax, cl
    sub     r14d, eax
    xor     ecx, ecx
.zero_loop:
    cmp     ecx, ebx
    jae     .stop_bit
    mov     rdi, r12
    xor     esi, esi
    mov     edx, 1
    push    rcx
    call    er_av1_bits_write
    pop     rcx
    test    edx, edx
    jnz     .done
    inc     ecx
    jmp     .zero_loop
.stop_bit:
    mov     rdi, r12
    mov     esi, 1
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    test    ebx, ebx
    jz      .ok
    mov     rdi, r12
    mov     esi, r14d
    mov     edx, ebx
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.ok:
    mov     eax, r13d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13, r14
    ret

; er_av1_sequence_decode(payload, len, seq_desc)
; Parses a profile-0 AV1 sequence_header_obu into seq_desc.
; rdi=payload, esi=len, rdx=seq_desc. Returns eax=bits_consumed.
er_fn er_av1_sequence_decode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdx
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .done

    mov     rdi, rsp
    mov     esi, AV1_SEQ_PROFILE_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_SEQ_PROFILE_MAIN
    jne     .unsupported
    mov     [r12 + AV1_SEQ_PROFILE], al

    call_read_bit
    mov     [r12 + AV1_SEQ_STILL_PICTURE], al

    call_read_bit
    mov     [r12 + AV1_SEQ_REDUCED_STILL], al
    test    eax, eax
    jnz     .reduced_operating_point

    call_read_bit
    mov     [r12 + AV1_SEQ_TIMING_INFO_PRESENT], al
    test    eax, eax
    jnz     .timing_info
    mov     dword [r12 + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 0
    mov     dword [r12 + AV1_SEQ_TIME_SCALE], 0
    mov     byte [r12 + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 0
    mov     dword [r12 + AV1_SEQ_NUM_TICKS_PER_PICTURE_MINUS_1], 0
    jmp     .initial_display_delay

.timing_info:
    mov     rdi, rsp
    mov     esi, 32
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], eax
    mov     rdi, rsp
    mov     esi, 32
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_TIME_SCALE], eax
    call_read_bit
    mov     [r12 + AV1_SEQ_EQUAL_PICTURE_INTERVAL], al
    test    eax, eax
    jz      .timing_interval_done
    mov     rdi, rsp
    call    av1_sequence_read_uvlc
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_NUM_TICKS_PER_PICTURE_MINUS_1], eax
    jmp     .initial_display_delay
.timing_interval_done:
    mov     dword [r12 + AV1_SEQ_NUM_TICKS_PER_PICTURE_MINUS_1], 0

.initial_display_delay:
    call_read_bit
    mov     [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY], al
    test    eax, eax
    jz      .initial_display_delay_zero
    call_read_bit
    test    eax, eax
    jz      .initial_display_delay_zero
    mov     rdi, rsp
    mov     esi, AV1_SEQ_INITIAL_DISPLAY_DELAY_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY_MINUS_1], eax
    jmp     .initial_display_delay_done
.initial_display_delay_zero:
    mov     dword [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY_MINUS_1], 0
.initial_display_delay_done:

    mov     rdi, rsp
    mov     esi, AV1_SEQ_OPERATING_POINTS_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_OPERATING_POINTS_MINUS_1], al
    test    eax, eax
    jnz     .unsupported

    mov     rdi, rsp
    mov     esi, AV1_SEQ_OPERATING_POINT_IDC_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_OPERATING_POINT_IDC], ax

    mov     rdi, rsp
    mov     esi, AV1_SEQ_LEVEL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_LEVEL_IDX], al
    cmp     eax, AV1_SEQ_LEVEL_MAX
    ja      .unsupported
    cmp     eax, AV1_SEQ_LEVEL_TIER_MAX
    ja      .read_level_tier
    mov     byte [r12 + AV1_SEQ_LEVEL_TIER], 0
    jmp     .dimensions

.read_level_tier:
    call_read_bit
    mov     [r12 + AV1_SEQ_LEVEL_TIER], al
    jmp     .dimensions

.reduced_operating_point:
    mov     byte [r12 + AV1_SEQ_TIMING_INFO_PRESENT], 0
    mov     dword [r12 + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 0
    mov     dword [r12 + AV1_SEQ_TIME_SCALE], 0
    mov     byte [r12 + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 0
    mov     dword [r12 + AV1_SEQ_NUM_TICKS_PER_PICTURE_MINUS_1], 0
    mov     byte [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY], 0
    mov     dword [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY_MINUS_1], 0
    mov     byte [r12 + AV1_SEQ_OPERATING_POINTS_MINUS_1], 0
    mov     word [r12 + AV1_SEQ_OPERATING_POINT_IDC], 0
    mov     rdi, rsp
    mov     esi, AV1_SEQ_LEVEL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_LEVEL_IDX], al
    mov     byte [r12 + AV1_SEQ_LEVEL_TIER], 0

.dimensions:
    mov     rdi, rsp
    mov     esi, AV1_SEQ_DIMENSION_BITS_FIELD
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_WIDTH_BITS], al
    mov     r14d, eax

    mov     rdi, rsp
    mov     esi, AV1_SEQ_DIMENSION_BITS_FIELD
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_HEIGHT_BITS], al
    mov     r15d, eax

    mov     rdi, rsp
    mov     esi, r14d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_MAX_WIDTH], eax

    mov     rdi, rsp
    mov     esi, r15d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_MAX_HEIGHT], eax

    cmp     byte [r12 + AV1_SEQ_REDUCED_STILL], 1
    je      .reduced_color_config

    call_read_bit
    mov     [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], al
    test    eax, eax
    jz      .frame_id_done
    mov     rdi, rsp
    mov     esi, AV1_SEQ_FRAME_ID_DELTA_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    add     eax, AV1_SEQ_FRAME_ID_DELTA_BASE
    mov     [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH], al
    mov     rdi, rsp
    mov     esi, AV1_SEQ_FRAME_ID_ADDITIONAL_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    add     eax, AV1_SEQ_FRAME_ID_ADDITIONAL_BASE
    mov     [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH], al
    jmp     .after_frame_id_lengths
.frame_id_done:
    mov     byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH], 0
    mov     byte [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH], 0
.after_frame_id_lengths:
    call_read_bit
    mov     [r12 + AV1_SEQ_USE_128X128_SUPERBLOCK], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_FILTER_INTRA], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_INTRA_EDGE_FILTER], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_INTERINTRA_COMPOUND], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_MASKED_COMPOUND], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_WARPED_MOTION], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_DUAL_FILTER], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_ORDER_HINT], al
    test    eax, eax
    jz      .no_order_hint
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_JNT_COMP], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_REF_FRAME_MVS], al
    jmp     .screen_content_tools
.no_order_hint:
    mov     byte [r12 + AV1_SEQ_ENABLE_JNT_COMP], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_REF_FRAME_MVS], 0

.screen_content_tools:
    call_read_bit
    test    eax, eax
    jz      .read_force_screen_content_tools
    mov     byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], AV1_SEQ_SELECT_SCREEN_CONTENT_TOOLS
    jmp     .integer_mv_tools
.read_force_screen_content_tools:
    call_read_bit
    mov     [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], al

.integer_mv_tools:
    movzx   eax, byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS]
    test    eax, eax
    jz      .no_integer_mv_tools
    call_read_bit
    test    eax, eax
    jz      .read_force_integer_mv
    mov     byte [r12 + AV1_SEQ_FORCE_INTEGER_MV], AV1_SEQ_SELECT_INTEGER_MV
    jmp     .order_hint_bits
.read_force_integer_mv:
    call_read_bit
    mov     [r12 + AV1_SEQ_FORCE_INTEGER_MV], al
    jmp     .order_hint_bits
.no_integer_mv_tools:
    mov     byte [r12 + AV1_SEQ_FORCE_INTEGER_MV], AV1_SEQ_SELECT_INTEGER_MV

.order_hint_bits:
    cmp     byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT], 1
    jne     .no_order_hint_bits
    mov     rdi, rsp
    mov     esi, AV1_SEQ_ORDER_HINT_BITS_FIELD
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_ORDER_HINT_BITS], al
    jmp     .after_order_hint_bits
.no_order_hint_bits:
    mov     byte [r12 + AV1_SEQ_ORDER_HINT_BITS], 0
.after_order_hint_bits:
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_SUPERRES], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_CDEF], al
    call_read_bit
    mov     [r12 + AV1_SEQ_ENABLE_RESTORATION], al
    jmp     .color_config

.reduced_color_config:
    mov     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 0
    mov     byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH], 0
    mov     byte [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH], 0
    mov     byte [r12 + AV1_SEQ_USE_128X128_SUPERBLOCK], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_FILTER_INTRA], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_INTRA_EDGE_FILTER], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_INTERINTRA_COMPOUND], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_MASKED_COMPOUND], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_WARPED_MOTION], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_DUAL_FILTER], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_JNT_COMP], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_REF_FRAME_MVS], 0
    mov     byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], 0
    mov     byte [r12 + AV1_SEQ_FORCE_INTEGER_MV], 0
    mov     byte [r12 + AV1_SEQ_ORDER_HINT_BITS], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_SUPERRES], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_CDEF], 0
    mov     byte [r12 + AV1_SEQ_ENABLE_RESTORATION], 0

.color_config:
    call_read_bit
    test    eax, eax
    jz      .bit_depth_8
    mov     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_10
    jmp     .read_mono_chrome
.bit_depth_8:
    mov     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8

.read_mono_chrome:
    call_read_bit
    mov     [r12 + AV1_SEQ_MONO_CHROME], al

    call_read_bit
    mov     [r12 + AV1_SEQ_COLOR_DESCRIPTION_PRESENT], al
    test    eax, eax
    jz      .no_color_description
    mov     rdi, rsp
    mov     esi, AV1_SEQ_COLOR_DESCRIPTION_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_COLOR_PRIMARIES], al
    mov     rdi, rsp
    mov     esi, AV1_SEQ_COLOR_DESCRIPTION_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_TRANSFER_CHARACTERISTICS], al
    mov     rdi, rsp
    mov     esi, AV1_SEQ_COLOR_DESCRIPTION_BITS
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_MATRIX_COEFFICIENTS], al
    jmp     .color_range
.no_color_description:
    mov     byte [r12 + AV1_SEQ_COLOR_PRIMARIES], 0
    mov     byte [r12 + AV1_SEQ_TRANSFER_CHARACTERISTICS], 0
    mov     byte [r12 + AV1_SEQ_MATRIX_COEFFICIENTS], 0

.color_range:
    call_read_bit
    mov     [r12 + AV1_SEQ_COLOR_RANGE], al
    mov     byte [r12 + AV1_SEQ_SUBSAMPLING_X], 1
    mov     byte [r12 + AV1_SEQ_SUBSAMPLING_Y], 1
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .mono_color_done
    mov     rdi, rsp
    mov     esi, 2
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_CHROMA_SAMPLE_POSITION], al
    jmp     .after_chroma_position
.mono_color_done:
    mov     byte [r12 + AV1_SEQ_CHROMA_SAMPLE_POSITION], AV1_CHROMA_SAMPLE_POSITION_UNKNOWN
.after_chroma_position:
    cmp     byte [r12 + AV1_SEQ_REDUCED_STILL], 1
    je      .film_grain
    call_read_bit
    mov     [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q], al
    jmp     .film_grain

.film_grain:
    cmp     byte [r12 + AV1_SEQ_REDUCED_STILL], 1
    jne     .read_film_grain
    mov     byte [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q], 0
.read_film_grain:
    call_read_bit
    mov     [r12 + AV1_SEQ_FILM_GRAIN], al
    mov     eax, [rsp + AV1_BITS_POS]
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
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_sequence_encode(out, cap, seq_desc)
; Encodes a deterministic profile-0 AV1 sequence_header_obu from seq_desc.
; rdi=out, esi=cap, rdx=seq_desc. Returns eax=bytes_written.
er_fn er_av1_sequence_encode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdx
    cmp     byte [r12 + AV1_SEQ_PROFILE], AV1_SEQ_PROFILE_MAIN
    jne     .unsupported
    cmp     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8
    je      .validate_dimensions
    cmp     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_10
    jne     .unsupported
.validate_dimensions:
    cmp     dword [r12 + AV1_SEQ_MAX_WIDTH], 0
    je      .invalid_param
    cmp     dword [r12 + AV1_SEQ_MAX_HEIGHT], 0
    je      .invalid_param
    cmp     dword [r12 + AV1_SEQ_MAX_WIDTH], AV1_SEQ_DIMENSION_MAX
    ja      .invalid_param
    cmp     dword [r12 + AV1_SEQ_MAX_HEIGHT], AV1_SEQ_DIMENSION_MAX
    ja      .invalid_param
    movzx   eax, byte [r12 + AV1_SEQ_WIDTH_BITS]
    cmp     eax, AV1_SEQ_WIDTH_BITS_MIN
    jb      .invalid_param
    cmp     eax, AV1_SEQ_WIDTH_BITS_MAX
    ja      .invalid_param
    movzx   eax, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    cmp     eax, AV1_SEQ_HEIGHT_BITS_MIN
    jb      .invalid_param
    cmp     eax, AV1_SEQ_HEIGHT_BITS_MAX
    ja      .invalid_param
    cmp     byte [r12 + AV1_SEQ_TIMING_INFO_PRESENT], 0
    je      .validate_initial_display_delay
    cmp     dword [r12 + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 0
    je      .invalid_param
    cmp     dword [r12 + AV1_SEQ_TIME_SCALE], 0
    je      .invalid_param
.validate_initial_display_delay:
    cmp     byte [r12 + AV1_SEQ_OPERATING_POINTS_MINUS_1], 0
    jne     .unsupported
    cmp     byte [r12 + AV1_SEQ_LEVEL_IDX], AV1_SEQ_LEVEL_MAX
    ja      .invalid_param
    cmp     byte [r12 + AV1_SEQ_LEVEL_TIER], 1
    ja      .invalid_param
    cmp     byte [r12 + AV1_SEQ_LEVEL_IDX], AV1_SEQ_LEVEL_TIER_MAX
    ja      .params_ok
    cmp     byte [r12 + AV1_SEQ_LEVEL_TIER], 0
    jne     .invalid_param

.params_ok:
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .done

    movzx   esi, byte [r12 + AV1_SEQ_PROFILE]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_PROFILE_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_STILL_PICTURE]
    mov     rdi, rsp
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_REDUCED_STILL]
    mov     rdi, rsp
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    cmp     byte [r12 + AV1_SEQ_REDUCED_STILL], 1
    je      .write_reduced_level

    movzx   esi, byte [r12 + AV1_SEQ_TIMING_INFO_PRESENT]
    write_one_from_esi
    cmp     byte [r12 + AV1_SEQ_TIMING_INFO_PRESENT], 0
    je      .write_initial_display_delay
    mov     esi, [r12 + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK]
    mov     rdi, rsp
    mov     edx, 32
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, [r12 + AV1_SEQ_TIME_SCALE]
    mov     rdi, rsp
    mov     edx, 32
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_EQUAL_PICTURE_INTERVAL]
    write_one_from_esi
    cmp     byte [r12 + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 0
    je      .write_initial_display_delay
    mov     rdi, rsp
    mov     esi, [r12 + AV1_SEQ_NUM_TICKS_PER_PICTURE_MINUS_1]
    call    av1_sequence_write_uvlc
    test    edx, edx
    jnz     .done
.write_initial_display_delay:
    movzx   esi, byte [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY]
    write_one_from_esi
    cmp     byte [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY], 0
    je      .write_operating_points
    write_bits 1, 1
    mov     esi, [r12 + AV1_SEQ_INITIAL_DISPLAY_DELAY_MINUS_1]
    cmp     esi, 15
    ja      .invalid_param
    mov     rdi, rsp
    mov     edx, AV1_SEQ_INITIAL_DISPLAY_DELAY_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_operating_points:
    write_bits 0, 5
    movzx   esi, word [r12 + AV1_SEQ_OPERATING_POINT_IDC]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_OPERATING_POINT_IDC_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_LEVEL_IDX]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_LEVEL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    cmp     byte [r12 + AV1_SEQ_LEVEL_IDX], AV1_SEQ_LEVEL_TIER_MAX
    jbe     .write_dimensions
    movzx   esi, byte [r12 + AV1_SEQ_LEVEL_TIER]
    write_one_from_esi
    jmp     .write_dimensions
.write_reduced_level:
    movzx   esi, byte [r12 + AV1_SEQ_LEVEL_IDX]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_LEVEL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

.write_dimensions:
    movzx   esi, byte [r12 + AV1_SEQ_WIDTH_BITS]
    dec     esi
    mov     rdi, rsp
    mov     edx, AV1_SEQ_DIMENSION_BITS_FIELD
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    dec     esi
    mov     rdi, rsp
    mov     edx, AV1_SEQ_DIMENSION_BITS_FIELD
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, [r12 + AV1_SEQ_MAX_WIDTH]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_WIDTH_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     esi, [r12 + AV1_SEQ_MAX_HEIGHT]
    dec     esi
    movzx   edx, byte [r12 + AV1_SEQ_HEIGHT_BITS]
    mov     rdi, rsp
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    cmp     byte [r12 + AV1_SEQ_REDUCED_STILL], 1
    je      .write_color_config

    movzx   esi, byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT]
    mov     rdi, rsp
    mov     edx, 1
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    cmp     byte [r12 + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 0
    je      .write_tools
    movzx   esi, byte [r12 + AV1_SEQ_DELTA_FRAME_ID_LENGTH]
    cmp     esi, AV1_SEQ_FRAME_ID_DELTA_BASE
    jb      .invalid_param
    sub     esi, AV1_SEQ_FRAME_ID_DELTA_BASE
    mov     rdi, rsp
    mov     edx, AV1_SEQ_FRAME_ID_DELTA_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH]
    test    esi, esi
    jz      .invalid_param
    sub     esi, AV1_SEQ_FRAME_ID_ADDITIONAL_BASE
    mov     rdi, rsp
    mov     edx, AV1_SEQ_FRAME_ID_ADDITIONAL_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_tools:
    movzx   esi, byte [r12 + AV1_SEQ_USE_128X128_SUPERBLOCK]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_FILTER_INTRA]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_INTRA_EDGE_FILTER]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_INTERINTRA_COMPOUND]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_MASKED_COMPOUND]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_WARPED_MOTION]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_DUAL_FILTER]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT]
    write_one_from_esi
    cmp     byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT], 1
    jne     .write_screen_content_tools
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_JNT_COMP]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_REF_FRAME_MVS]
    write_one_from_esi
.write_screen_content_tools:
    movzx   eax, byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS]
    cmp     eax, AV1_SEQ_SELECT_SCREEN_CONTENT_TOOLS
    jne     .write_force_screen_content_tools
    write_bits 1, 1
    jmp     .write_integer_mv_tools
.write_force_screen_content_tools:
    cmp     eax, 1
    ja      .invalid_param
    write_bits 0, 1
    movzx   esi, byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS]
    write_one_from_esi
.write_integer_mv_tools:
    movzx   eax, byte [r12 + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS]
    test    eax, eax
    jz      .write_order_hint_bits
    movzx   eax, byte [r12 + AV1_SEQ_FORCE_INTEGER_MV]
    cmp     eax, AV1_SEQ_SELECT_INTEGER_MV
    jne     .write_force_integer_mv
    write_bits 1, 1
    jmp     .write_order_hint_bits
.write_force_integer_mv:
    cmp     eax, 1
    ja      .invalid_param
    write_bits 0, 1
    movzx   esi, byte [r12 + AV1_SEQ_FORCE_INTEGER_MV]
    write_one_from_esi
.write_order_hint_bits:
    cmp     byte [r12 + AV1_SEQ_ENABLE_ORDER_HINT], 1
    jne     .write_post_order_tools
    movzx   esi, byte [r12 + AV1_SEQ_ORDER_HINT_BITS]
    test    esi, esi
    jz      .invalid_param
    dec     esi
    mov     rdi, rsp
    mov     edx, AV1_SEQ_ORDER_HINT_BITS_FIELD
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_post_order_tools:
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_SUPERRES]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_CDEF]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_ENABLE_RESTORATION]
    write_one_from_esi

.write_color_config:
    cmp     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_10
    sete    sil
    movzx   esi, sil
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_MONO_CHROME]
    write_one_from_esi
    movzx   esi, byte [r12 + AV1_SEQ_COLOR_DESCRIPTION_PRESENT]
    write_one_from_esi
    cmp     byte [r12 + AV1_SEQ_COLOR_DESCRIPTION_PRESENT], 1
    jne     .write_color_range
    movzx   esi, byte [r12 + AV1_SEQ_COLOR_PRIMARIES]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_COLOR_DESCRIPTION_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_TRANSFER_CHARACTERISTICS]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_COLOR_DESCRIPTION_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    movzx   esi, byte [r12 + AV1_SEQ_MATRIX_COEFFICIENTS]
    mov     rdi, rsp
    mov     edx, AV1_SEQ_COLOR_DESCRIPTION_BITS
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_color_range:
    movzx   esi, byte [r12 + AV1_SEQ_COLOR_RANGE]
    write_one_from_esi
    cmp     byte [r12 + AV1_SEQ_MONO_CHROME], 1
    je      .write_separate_uv
    movzx   esi, byte [r12 + AV1_SEQ_CHROMA_SAMPLE_POSITION]
    mov     rdi, rsp
    mov     edx, 2
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
.write_separate_uv:
    cmp     byte [r12 + AV1_SEQ_REDUCED_STILL], 1
    je      .write_film_grain
    movzx   esi, byte [r12 + AV1_SEQ_SEPARATE_UV_DELTA_Q]
    write_one_from_esi
.write_film_grain:
    movzx   esi, byte [r12 + AV1_SEQ_FILM_GRAIN]
    write_one_from_esi
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_sequence_decode_reduced_still(payload, len, seq_desc)
; rdi=payload, esi=len, rdx=seq_desc. Returns eax=bits_consumed.
er_fn er_av1_sequence_decode_reduced_still
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdx
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .done

    mov     rdi, rsp
    mov     esi, 3
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    cmp     eax, AV1_SEQ_PROFILE_MAIN
    jne     .unsupported
    mov     [r12 + AV1_SEQ_PROFILE], al

    call_read_bit
    cmp     eax, 1
    jne     .unsupported
    mov     [r12 + AV1_SEQ_STILL_PICTURE], al

    call_read_bit
    cmp     eax, 1
    jne     .unsupported
    mov     [r12 + AV1_SEQ_REDUCED_STILL], al

    mov     rdi, rsp
    mov     esi, 5
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_LEVEL_IDX], al
    mov     byte [r12 + AV1_SEQ_LEVEL_TIER], 0

    mov     rdi, rsp
    mov     esi, 4
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_WIDTH_BITS], al
    mov     r14d, eax

    mov     rdi, rsp
    mov     esi, 4
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_HEIGHT_BITS], al
    mov     r15d, eax

    mov     rdi, rsp
    mov     esi, r14d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_MAX_WIDTH], eax

    mov     rdi, rsp
    mov     esi, r15d
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [r12 + AV1_SEQ_MAX_HEIGHT], eax

    call_read_bit
    test    eax, eax
    jnz     .unsupported
    mov     byte [r12 + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8

    call_read_bit
    test    eax, eax
    jnz     .unsupported
    mov     [r12 + AV1_SEQ_MONO_CHROME], al

    call_read_bit
    test    eax, eax
    jnz     .unsupported

    call_read_bit
    mov     [r12 + AV1_SEQ_COLOR_RANGE], al

    mov     byte [r12 + AV1_SEQ_SUBSAMPLING_X], 1
    mov     byte [r12 + AV1_SEQ_SUBSAMPLING_Y], 1

    mov     rdi, rsp
    mov     esi, 2
    call    er_av1_bits_read
    test    edx, edx
    jnz     .done
    mov     [r12 + AV1_SEQ_CHROMA_SAMPLE_POSITION], al

    call_read_bit
    mov     [r12 + AV1_SEQ_FILM_GRAIN], al
    mov     eax, [rsp + AV1_BITS_POS]
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
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_sequence_encode_reduced_still(out, cap, width, height)
; rdi=out, esi=cap, edx=width, ecx=height. Returns eax=bytes_written.
er_fn er_av1_sequence_encode_reduced_still
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE
    test    edx, edx
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    cmp     edx, AV1_SEQ_DIMENSION_MAX
    ja      .invalid_param
    cmp     ecx, AV1_SEQ_DIMENSION_MAX
    ja      .invalid_param
    mov     r12d, edx
    mov     r13d, ecx
    mov     r14d, edx
    dec     r14d
    mov     r15d, ecx
    dec     r15d

    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .done

    write_bits AV1_SEQ_PROFILE_MAIN, 3
    write_bits 1, 1
    write_bits 1, 1
    write_bits AV1_SEQ_LEVEL_2_0, 5
    write_bits 15, 4
    write_bits 15, 4

    mov     rdi, rsp
    mov     esi, r14d
    mov     edx, 16
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    mov     esi, r15d
    mov     edx, 16
    call    er_av1_bits_write
    test    edx, edx
    jnz     .done

    write_bits 0, 1
    write_bits 0, 1
    write_bits 0, 1
    write_bits 0, 1
    write_bits AV1_CHROMA_SAMPLE_POSITION_UNKNOWN, 2
    write_bits 0, 1

    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret
