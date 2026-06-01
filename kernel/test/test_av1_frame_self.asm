; EdgeRun AV1 reduced-still frame header self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_sequence_encode_reduced_still
extern er_av1_sequence_decode_reduced_still
extern er_av1_frame_decode
extern er_av1_frame_encode
extern er_av1_frame_decode_reduced_still
extern er_av1_frame_encode_reduced_still

SECTION .bss
passed: resq 1
failed: resq 1
seq:    resb AV1_SEQ_SIZE
frame:  resb AV1_FRAME_SIZE
seqbuf: resb 16
outbuf: resb 256

SECTION .text
global _start
_start:
    mov     rdi, seqbuf
    mov     esi, 16
    mov     edx, 64
    mov     ecx, 32
    call    er_av1_sequence_encode_reduced_still
    test    edx, edx
    jnz     .fail_seq
    mov     rdi, seqbuf
    mov     esi, eax
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .fail_seq
    inc     qword [rel passed]
    jmp     .encode_frame
.fail_seq:
    inc     qword [rel failed]

.encode_frame:
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, seq
    mov     ecx, 64
    mov     r8d, 32
    call    er_av1_frame_encode_reduced_still
    test    edx, edx
    jnz     .fail_encode_frame
    test    eax, eax
    jz      .fail_encode_frame
    inc     qword [rel passed]
    jmp     .decode_frame
.fail_encode_frame:
    inc     qword [rel failed]

.decode_frame:
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode_reduced_still
    test    eax, eax
    jz      .fail_decode_frame
    test    edx, edx
    jnz     .fail_decode_frame
    cmp     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    jne     .fail_decode_frame
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 64
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 32
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 64
    jne     .fail_decode_frame
    cmp     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 32
    jne     .fail_decode_frame
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    jne     .fail_decode_frame
    inc     qword [rel passed]
    jmp     .short_frame
.fail_decode_frame:
    inc     qword [rel failed]

.short_frame:
    mov     rdi, outbuf
    mov     esi, 1
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode_reduced_still
    test    eax, eax
    jnz     .fail_short_frame
    cmp     edx, ERROR_NO_DATA
    jne     .fail_short_frame
    inc     qword [rel passed]
    jmp     .invalid_seq
.fail_short_frame:
    inc     qword [rel failed]

.invalid_seq:
    mov     byte [rel seq + AV1_SEQ_REDUCED_STILL], 0
    mov     rdi, outbuf
    mov     esi, 16
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode_reduced_still
    test    eax, eax
    jnz     .fail_invalid_seq
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_invalid_seq
    inc     qword [rel passed]
    jmp     .encode_non_reduced_keyframe
.fail_invalid_seq:
    inc     qword [rel failed]

.encode_non_reduced_keyframe:
    mov     byte [rel seq + AV1_SEQ_PROFILE], AV1_SEQ_PROFILE_MAIN
    mov     byte [rel seq + AV1_SEQ_STILL_PICTURE], 0
    mov     byte [rel seq + AV1_SEQ_REDUCED_STILL], 0
    mov     byte [rel seq + AV1_SEQ_WIDTH_BITS], 16
    mov     byte [rel seq + AV1_SEQ_HEIGHT_BITS], 16
    mov     dword [rel seq + AV1_SEQ_MAX_WIDTH], 640
    mov     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 480
    mov     byte [rel seq + AV1_SEQ_ENABLE_SUPERRES], 0
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 0
    mov     byte [rel seq + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    mov     byte [rel seq + AV1_SEQ_DELTA_FRAME_ID_LENGTH], 4
    mov     byte [rel seq + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH], 3
    mov     byte [rel seq + AV1_SEQ_MONO_CHROME], 0
    mov     byte [rel seq + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    mov     byte [rel seq + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], 1
    mov     byte [rel seq + AV1_SEQ_FORCE_INTEGER_MV], 1
    mov     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    mov     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 1
    mov     byte [rel frame + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 1
    mov     byte [rel frame + AV1_FRAME_FORCE_INTEGER_MV], 1
    mov     byte [rel frame + AV1_FRAME_FRAME_SIZE_OVERRIDE], 1
    mov     dword [rel frame + AV1_FRAME_WIDTH], 320
    mov     dword [rel frame + AV1_FRAME_HEIGHT], 240
    mov     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 160
    mov     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 120
    mov     dword [rel frame + AV1_FRAME_CURRENT_FRAME_ID], 17
    mov     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_COLS_LOG2], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_ROWS_LOG2], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 2
    mov     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 2
    mov     byte [rel frame + AV1_FRAME_BASE_Q_IDX], 128
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_Y_DC], -3
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_U_DC], 2
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_U_AC], -1
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_V_DC], 4
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_V_AC], -5
    mov     byte [rel frame + AV1_FRAME_USING_QMATRIX], 0
    mov     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    mov     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 0
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_encode
    test    eax, eax
    jz      .fail_encode_non_reduced_keyframe
    test    edx, edx
    jnz     .fail_encode_non_reduced_keyframe
    inc     qword [rel passed]
    jmp     .decode_non_reduced_keyframe
.fail_encode_non_reduced_keyframe:
    inc     qword [rel failed]

.decode_non_reduced_keyframe:
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode
    test    eax, eax
    jz      .fail_decode_non_reduced_keyframe
    test    edx, edx
    jnz     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_SHOW_EXISTING_FRAME], 0
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 1
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 320
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 240
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 160
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 120
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_CURRENT_FRAME_ID], 17
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 1
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_COUNT], 4
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 2
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_BASE_Q_IDX], 128
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_DELTA_Q_Y_DC], -3
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_DELTA_Q_U_DC], 2
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_DELTA_Q_U_AC], -1
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_DELTA_Q_V_DC], 4
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_DELTA_Q_V_AC], -5
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_USING_QMATRIX], 0
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    jne     .fail_decode_non_reduced_keyframe
    inc     qword [rel passed]
    jmp     .encode_nonshown_keyframe
.fail_decode_non_reduced_keyframe:
    inc     qword [rel failed]

.encode_nonshown_keyframe:
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 4
    mov     byte [rel seq + AV1_SEQ_ENABLE_SUPERRES], 1
    mov     byte [rel seq + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 0
    mov     dword [rel seq + AV1_SEQ_MAX_WIDTH], 320
    mov     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 240
    mov     byte [rel seq + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], 0
    mov     byte [rel seq + AV1_SEQ_FORCE_INTEGER_MV], AV1_SEQ_SELECT_INTEGER_MV
    mov     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    mov     byte [rel frame + AV1_FRAME_SHOW_FRAME], 0
    mov     byte [rel frame + AV1_FRAME_SHOWABLE_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 0
    mov     byte [rel frame + AV1_FRAME_FRAME_SIZE_OVERRIDE], 0
    mov     dword [rel frame + AV1_FRAME_ORDER_HINT], 9
    mov     byte [rel frame + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 0
    mov     byte [rel frame + AV1_FRAME_FORCE_INTEGER_MV], 0
    mov     dword [rel frame + AV1_FRAME_WIDTH], 320
    mov     dword [rel frame + AV1_FRAME_HEIGHT], 240
    mov     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 320
    mov     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 240
    mov     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_COLS_LOG2], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_ROWS_LOG2], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 1
    mov     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 0
    mov     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    mov     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 0
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_encode
    test    eax, eax
    jz      .fail_encode_nonshown_keyframe
    test    edx, edx
    jnz     .fail_encode_nonshown_keyframe
    inc     qword [rel passed]
    jmp     .decode_nonshown_keyframe
.fail_encode_nonshown_keyframe:
    inc     qword [rel failed]

.decode_nonshown_keyframe:
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode
    test    eax, eax
    jz      .fail_decode_nonshown_keyframe
    test    edx, edx
    jnz     .fail_decode_nonshown_keyframe
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 0
    jne     .fail_decode_nonshown_keyframe
    cmp     byte [rel frame + AV1_FRAME_SHOWABLE_FRAME], 1
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_ORDER_HINT], 9
    jne     .fail_decode_nonshown_keyframe
    cmp     byte [rel frame + AV1_FRAME_FRAME_SIZE_OVERRIDE], 0
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 320
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 240
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 320
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 240
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_SUPERRES_DENOM], AV1_SUPERRES_NUM
    jne     .fail_decode_nonshown_keyframe
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_COUNT], 1
    jne     .fail_decode_nonshown_keyframe
    inc     qword [rel passed]
    jmp     .encode_active_superres_keyframe
.fail_decode_nonshown_keyframe:
    inc     qword [rel failed]

.encode_active_superres_keyframe:
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 0
    mov     byte [rel seq + AV1_SEQ_ENABLE_SUPERRES], 1
    mov     dword [rel seq + AV1_SEQ_MAX_WIDTH], 320
    mov     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 240
    mov     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_KEY
    mov     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_SHOWABLE_FRAME], 0
    mov     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 1
    mov     byte [rel frame + AV1_FRAME_FRAME_SIZE_OVERRIDE], 0
    mov     byte [rel frame + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 0
    mov     byte [rel frame + AV1_FRAME_FORCE_INTEGER_MV], 0
    mov     dword [rel frame + AV1_FRAME_WIDTH], 160
    mov     dword [rel frame + AV1_FRAME_HEIGHT], 240
    mov     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 320
    mov     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 240
    mov     dword [rel frame + AV1_FRAME_SUPERRES_DENOM], AV1_SUPERRES_DENOM_MAX
    mov     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_COLS_LOG2], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_ROWS_LOG2], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 1
    mov     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 0
    mov     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    mov     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 0
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_encode
    test    eax, eax
    jz      .fail_encode_active_superres_keyframe
    test    edx, edx
    jnz     .fail_encode_active_superres_keyframe
    inc     qword [rel passed]
    jmp     .decode_active_superres_keyframe
.fail_encode_active_superres_keyframe:
    inc     qword [rel failed]

.decode_active_superres_keyframe:
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode
    test    eax, eax
    jz      .fail_decode_active_superres_keyframe
    test    edx, edx
    jnz     .fail_decode_active_superres_keyframe
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 160
    jne     .fail_decode_active_superres_keyframe
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 240
    jne     .fail_decode_active_superres_keyframe
    cmp     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 320
    jne     .fail_decode_active_superres_keyframe
    cmp     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 240
    jne     .fail_decode_active_superres_keyframe
    cmp     dword [rel frame + AV1_FRAME_SUPERRES_DENOM], AV1_SUPERRES_DENOM_MAX
    jne     .fail_decode_active_superres_keyframe
    inc     qword [rel passed]
    jmp     .encode_show_existing_frame
.fail_decode_active_superres_keyframe:
    inc     qword [rel failed]

.encode_show_existing_frame:
    mov     byte [rel seq + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 1
    mov     byte [rel seq + AV1_SEQ_DELTA_FRAME_ID_LENGTH], 4
    mov     byte [rel seq + AV1_SEQ_ADDITIONAL_FRAME_ID_LENGTH], 3
    mov     byte [rel frame + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_EXISTING_FRAME_IDX], 5
    mov     dword [rel frame + AV1_FRAME_DISPLAY_FRAME_ID], 33
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_encode
    test    eax, eax
    jz      .fail_encode_show_existing_frame
    test    edx, edx
    jnz     .fail_encode_show_existing_frame
    inc     qword [rel passed]
    jmp     .decode_show_existing_frame
.fail_encode_show_existing_frame:
    inc     qword [rel failed]

.decode_show_existing_frame:
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode
    test    eax, eax
    jz      .fail_decode_show_existing_frame
    test    edx, edx
    jnz     .fail_decode_show_existing_frame
    cmp     byte [rel frame + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    jne     .fail_decode_show_existing_frame
    cmp     byte [rel frame + AV1_FRAME_EXISTING_FRAME_IDX], 5
    jne     .fail_decode_show_existing_frame
    cmp     dword [rel frame + AV1_FRAME_DISPLAY_FRAME_ID], 33
    jne     .fail_decode_show_existing_frame
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_show_existing_frame
    cmp     dword [rel frame + AV1_FRAME_TILE_LEN], 0
    jne     .fail_decode_show_existing_frame
    inc     qword [rel passed]
    jmp     .encode_intra_only_frame
.fail_decode_show_existing_frame:
    inc     qword [rel failed]

.encode_intra_only_frame:
    mov     byte [rel seq + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 0
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 5
    mov     byte [rel seq + AV1_SEQ_ENABLE_CDEF], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_RESTORATION], 1
    mov     byte [rel seq + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], 1
    mov     byte [rel seq + AV1_SEQ_FORCE_INTEGER_MV], 1
    mov     byte [rel frame + AV1_FRAME_SHOW_EXISTING_FRAME], 0
    mov     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTRA_ONLY
    mov     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_SHOWABLE_FRAME], 0
    mov     byte [rel frame + AV1_FRAME_ERROR_RESILIENT_MODE], 0
    mov     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 1
    mov     dword [rel frame + AV1_FRAME_ORDER_HINT], 17
    mov     byte [rel frame + AV1_FRAME_PRIMARY_REF_FRAME], 3
    mov     byte [rel frame + AV1_FRAME_REFRESH_FRAME_FLAGS], 0x5a
    mov     byte [rel frame + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 1
    mov     byte [rel frame + AV1_FRAME_FORCE_INTEGER_MV], 1
    mov     byte [rel frame + AV1_FRAME_FRAME_SIZE_OVERRIDE], 1
    mov     dword [rel frame + AV1_FRAME_WIDTH], 300
    mov     dword [rel frame + AV1_FRAME_HEIGHT], 200
    mov     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 300
    mov     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 200
    mov     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_COLS_LOG2], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_ROWS_LOG2], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 3
    mov     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 1
    mov     byte [rel frame + AV1_FRAME_BASE_Q_IDX], 96
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_Y_DC], 0
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_U_DC], 0
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_U_AC], 0
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_V_DC], 0
    mov     dword [rel frame + AV1_FRAME_DELTA_Q_V_AC], 0
    mov     byte [rel frame + AV1_FRAME_USING_QMATRIX], 0
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], 12
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], 10
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_U], 8
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_V], 6
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_SHARPNESS], 3
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 1
    mov     dword [rel frame + AV1_FRAME_LOOP_FILTER_REF_DELTAS], -1
    mov     dword [rel frame + AV1_FRAME_LOOP_FILTER_REF_DELTAS + 4], 2
    mov     dword [rel frame + AV1_FRAME_LOOP_FILTER_REF_DELTAS + 8], -3
    mov     dword [rel frame + AV1_FRAME_LOOP_FILTER_MODE_DELTAS], 4
    mov     dword [rel frame + AV1_FRAME_LOOP_FILTER_MODE_DELTAS + 4], -5
    mov     byte [rel frame + AV1_FRAME_CDEF_DAMPING], 5
    mov     byte [rel frame + AV1_FRAME_CDEF_BITS], 1
    mov     byte [rel frame + AV1_FRAME_CDEF_Y_PRI], 7
    mov     byte [rel frame + AV1_FRAME_CDEF_Y_SEC], 2
    mov     byte [rel frame + AV1_FRAME_CDEF_UV_PRI], 5
    mov     byte [rel frame + AV1_FRAME_CDEF_UV_SEC], 4
    mov     byte [rel frame + AV1_FRAME_CDEF_Y_PRI + 1], 3
    mov     byte [rel frame + AV1_FRAME_CDEF_Y_SEC + 1], 1
    mov     byte [rel frame + AV1_FRAME_CDEF_UV_PRI + 1], 2
    mov     byte [rel frame + AV1_FRAME_CDEF_UV_SEC + 1], 0
    mov     byte [rel frame + AV1_FRAME_RESTORATION_Y], AV1_RESTORE_WIENER
    mov     byte [rel frame + AV1_FRAME_RESTORATION_U], AV1_RESTORE_SGRPROJ
    mov     byte [rel frame + AV1_FRAME_RESTORATION_V], AV1_RESTORE_SWITCHABLE
    mov     byte [rel frame + AV1_FRAME_RESTORATION_UNIT_Y], 1
    mov     byte [rel frame + AV1_FRAME_RESTORATION_UNIT_U], 2
    mov     byte [rel frame + AV1_FRAME_RESTORATION_UNIT_V], 3
    mov     byte [rel frame + AV1_FRAME_SEGMENTATION_ENABLED], 1
    mov     byte [rel frame + AV1_FRAME_SEGMENTATION_UPDATE_MAP], 1
    mov     byte [rel frame + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], 1
    mov     byte [rel frame + AV1_FRAME_SEGMENTATION_UPDATE_DATA], 1
    mov     byte [rel frame + AV1_FRAME_SEGMENT_FEATURE_MASKS], (1 << AV1_SEGMENT_FEATURE_ALT_Q) | (1 << AV1_SEGMENT_FEATURE_ALT_LF_Y_V) | (1 << AV1_SEGMENT_FEATURE_REF_FRAME) | (1 << AV1_SEGMENT_FEATURE_SKIP) | (1 << AV1_SEGMENT_FEATURE_GLOBALMV)
    mov     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (AV1_SEGMENT_FEATURE_ALT_Q * 4)], -23
    mov     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (AV1_SEGMENT_FEATURE_ALT_LF_Y_V * 4)], 5
    mov     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (AV1_SEGMENT_FEATURE_REF_FRAME * 4)], 2
    mov     byte [rel frame + AV1_FRAME_SEGMENT_FEATURE_MASKS + 3], 1 << AV1_SEGMENT_FEATURE_ALT_LF_V
    mov     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (3 * AV1_SEGMENT_FEATURE_DATA_STRIDE) + (AV1_SEGMENT_FEATURE_ALT_LF_V * 4)], -7
    mov     byte [rel frame + AV1_FRAME_DELTA_Q_PRESENT], 1
    mov     byte [rel frame + AV1_FRAME_DELTA_Q_RES], 2
    mov     byte [rel frame + AV1_FRAME_DELTA_LF_PRESENT], 1
    mov     byte [rel frame + AV1_FRAME_DELTA_LF_RES], 1
    mov     byte [rel frame + AV1_FRAME_DELTA_LF_MULTI], 1
    mov     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_SELECT
    mov     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 0
    mov     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 0
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_encode
    test    eax, eax
    jz      .fail_encode_intra_only_frame
    test    edx, edx
    jnz     .fail_encode_intra_only_frame
    inc     qword [rel passed]
    jmp     .decode_intra_only_frame
.fail_encode_intra_only_frame:
    inc     qword [rel failed]

.decode_intra_only_frame:
    mov     rdi, outbuf
    mov     esi, 128
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode
    test    eax, eax
    jz      .fail_decode_intra_only_frame
    test    edx, edx
    jnz     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTRA_ONLY
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_ERROR_RESILIENT_MODE], 0
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 1
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_ORDER_HINT], 17
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_PRIMARY_REF_FRAME], 3
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_REFRESH_FRAME_FLAGS], 0x5a
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 300
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 200
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_COUNT], 2
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 3
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_BASE_Q_IDX], 96
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_Y_V], 12
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_Y_H], 10
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_U], 8
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_LEVEL_V], 6
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_SHARPNESS], 3
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 1
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_LOOP_FILTER_REF_DELTAS], -1
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_LOOP_FILTER_REF_DELTAS + 4], 2
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_LOOP_FILTER_REF_DELTAS + 8], -3
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_LOOP_FILTER_MODE_DELTAS], 4
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_LOOP_FILTER_MODE_DELTAS + 4], -5
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_DAMPING], 5
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_BITS], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_Y_PRI], 7
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_Y_SEC], 2
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_UV_PRI], 5
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_UV_SEC], 4
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_Y_PRI + 1], 3
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_Y_SEC + 1], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_UV_PRI + 1], 2
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_CDEF_UV_SEC + 1], 0
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_RESTORATION_Y], AV1_RESTORE_WIENER
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_RESTORATION_U], AV1_RESTORE_SGRPROJ
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_RESTORATION_V], AV1_RESTORE_SWITCHABLE
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_RESTORATION_UNIT_Y], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_RESTORATION_UNIT_U], 2
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_RESTORATION_UNIT_V], 3
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SEGMENTATION_ENABLED], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SEGMENTATION_UPDATE_MAP], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SEGMENTATION_TEMPORAL_UPDATE], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SEGMENTATION_UPDATE_DATA], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SEGMENT_FEATURE_MASKS], (1 << AV1_SEGMENT_FEATURE_ALT_Q) | (1 << AV1_SEGMENT_FEATURE_ALT_LF_Y_V) | (1 << AV1_SEGMENT_FEATURE_REF_FRAME) | (1 << AV1_SEGMENT_FEATURE_SKIP) | (1 << AV1_SEGMENT_FEATURE_GLOBALMV)
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (AV1_SEGMENT_FEATURE_ALT_Q * 4)], -23
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (AV1_SEGMENT_FEATURE_ALT_LF_Y_V * 4)], 5
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (AV1_SEGMENT_FEATURE_REF_FRAME * 4)], 2
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SEGMENT_FEATURE_MASKS + 3], 1 << AV1_SEGMENT_FEATURE_ALT_LF_V
    jne     .fail_decode_intra_only_frame
    cmp     dword [rel frame + AV1_FRAME_SEGMENT_FEATURE_DATA + (3 * AV1_SEGMENT_FEATURE_DATA_STRIDE) + (AV1_SEGMENT_FEATURE_ALT_LF_V * 4)], -7
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_DELTA_Q_PRESENT], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_DELTA_Q_RES], 2
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_DELTA_LF_PRESENT], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_DELTA_LF_RES], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_DELTA_LF_MULTI], 1
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_SELECT
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 0
    jne     .fail_decode_intra_only_frame
    cmp     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 0
    jne     .fail_decode_intra_only_frame
    inc     qword [rel passed]
    jmp     .encode_inter_frame
.fail_decode_intra_only_frame:
    inc     qword [rel failed]

.encode_inter_frame:
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 5
    mov     byte [rel seq + AV1_SEQ_ENABLE_CDEF], 0
    mov     byte [rel seq + AV1_SEQ_ENABLE_RESTORATION], 0
    mov     byte [rel seq + AV1_SEQ_ENABLE_WARPED_MOTION], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_DUAL_FILTER], 1
    mov     byte [rel seq + AV1_SEQ_FILM_GRAIN], 1
    mov     byte [rel seq + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], 0
    mov     byte [rel seq + AV1_SEQ_FORCE_INTEGER_MV], AV1_SEQ_SELECT_INTEGER_MV
    mov     byte [rel frame + AV1_FRAME_SHOW_EXISTING_FRAME], 0
    mov     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    mov     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_SHOWABLE_FRAME], 0
    mov     byte [rel frame + AV1_FRAME_ERROR_RESILIENT_MODE], 0
    mov     byte [rel frame + AV1_FRAME_DISABLE_CDF_UPDATE], 0
    mov     dword [rel frame + AV1_FRAME_ORDER_HINT], 19
    mov     byte [rel frame + AV1_FRAME_PRIMARY_REF_FRAME], 2
    mov     byte [rel frame + AV1_FRAME_REFRESH_FRAME_FLAGS], 0x33
    mov     byte [rel frame + AV1_FRAME_ALLOW_SCREEN_CONTENT_TOOLS], 0
    mov     byte [rel frame + AV1_FRAME_FORCE_INTEGER_MV], 0
    mov     byte [rel frame + AV1_FRAME_FRAME_SIZE_OVERRIDE], 1
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX0], 0
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX1], 1
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX2], 2
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX3], 3
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX4], 4
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX5], 5
    mov     byte [rel frame + AV1_FRAME_REF_FRAME_IDX6], 6
    mov     byte [rel frame + AV1_FRAME_ALLOW_HIGH_PRECISION_MV], 1
    mov     dword [rel frame + AV1_FRAME_WIDTH], 256
    mov     dword [rel frame + AV1_FRAME_HEIGHT], 144
    mov     dword [rel frame + AV1_FRAME_RENDER_WIDTH], 256
    mov     dword [rel frame + AV1_FRAME_RENDER_HEIGHT], 144
    mov     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_COLS_LOG2], 2
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_ROWS_LOG2], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 4
    mov     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 5
    mov     byte [rel frame + AV1_FRAME_SEGMENTATION_ENABLED], 0
    mov     byte [rel frame + AV1_FRAME_DELTA_Q_PRESENT], 0
    mov     byte [rel frame + AV1_FRAME_DELTA_Q_RES], 0
    mov     byte [rel frame + AV1_FRAME_DELTA_LF_PRESENT], 0
    mov     byte [rel frame + AV1_FRAME_DELTA_LF_RES], 0
    mov     byte [rel frame + AV1_FRAME_DELTA_LF_MULTI], 0
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_DELTA_ENABLED], 0
    mov     byte [rel frame + AV1_FRAME_LOOP_FILTER_DELTA_UPDATE], 0
    mov     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    mov     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 1
    mov     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 1
    mov     byte [rel frame + AV1_FRAME_GLOBAL_MOTION_TYPES], AV1_GLOBAL_MOTION_TRANSLATION
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS], 11
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + 4], -12
    mov     byte [rel frame + AV1_FRAME_GLOBAL_MOTION_TYPES + 3], AV1_GLOBAL_MOTION_AFFINE
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE)], 1
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 4], -2
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 8], 3
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 12], -4
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 16], 5
    mov     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 20], -6
    mov     byte [rel frame + AV1_FRAME_ALLOW_WARPED_MOTION], 1
    mov     byte [rel frame + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_EIGHTTAP_SHARP
    mov     byte [rel frame + AV1_FRAME_REDUCED_TX_SET], 1
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_APPLY], 1
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_UPDATE], 1
    mov     dword [rel frame + AV1_FRAME_FILM_GRAIN_SEED], 0x1234
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 1
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_Y_VALUES], 12
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_Y_SCALING], 34
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_NUM_CB_POINTS], 0
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_NUM_CR_POINTS], 0
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_SCALING_MINUS_8], 2
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_AR_LAG], 0
    mov     dword [rel frame + AV1_FRAME_FILM_GRAIN_AR_CB_COEFFS], 7
    mov     dword [rel frame + AV1_FRAME_FILM_GRAIN_AR_CR_COEFFS], -8
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_AR_SHIFT_MINUS_6], 1
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_SCALE_SHIFT], 3
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_OVERLAP], 1
    mov     byte [rel frame + AV1_FRAME_FILM_GRAIN_CLIP_RESTRICTED], 1
    mov     rdi, outbuf
    mov     esi, 256
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_encode
    test    eax, eax
    jz      .fail_encode_inter_frame
    test    edx, edx
    jnz     .fail_encode_inter_frame
    inc     qword [rel passed]
    jmp     .decode_inter_frame
.fail_encode_inter_frame:
    inc     qword [rel failed]

.decode_inter_frame:
    mov     rdi, outbuf
    mov     esi, 256
    mov     rdx, seq
    mov     rcx, frame
    call    er_av1_frame_decode
    test    eax, eax
    jz      .fail_decode_inter_frame
    test    edx, edx
    jnz     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_TYPE], AV1_FRAME_TYPE_INTER
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_ORDER_HINT], 19
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_PRIMARY_REF_FRAME], 2
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_REFRESH_FRAME_FLAGS], 0x33
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_REF_FRAME_IDX0], 0
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_REF_FRAME_IDX3], 3
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_REF_FRAME_IDX6], 6
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_ALLOW_HIGH_PRECISION_MV], 1
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_WIDTH], 256
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_HEIGHT], 144
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_COUNT], 8
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 5
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 4
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_TX_MODE], AV1_TX_MODE_LARGEST
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_REFERENCE_SELECT], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_SKIP_MODE_PRESENT], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_GLOBAL_MOTION_TYPES], AV1_GLOBAL_MOTION_TRANSLATION
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS], 11
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + 4], -12
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_GLOBAL_MOTION_TYPES + 3], AV1_GLOBAL_MOTION_AFFINE
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE)], 1
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 4], -2
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 8], 3
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 12], -4
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 16], 5
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_GLOBAL_MOTION_PARAMS + (3 * AV1_GLOBAL_MOTION_PARAM_STRIDE) + 20], -6
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_ALLOW_WARPED_MOTION], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_INTERPOLATION_FILTER], AV1_INTERP_FILTER_EIGHTTAP_SHARP
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_REDUCED_TX_SET], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_APPLY], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_UPDATE], 1
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_FILM_GRAIN_SEED], 0x1234
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_NUM_Y_POINTS], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_Y_VALUES], 12
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_Y_SCALING], 34
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_CHROMA_FROM_LUMA], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_SCALING_MINUS_8], 2
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_AR_LAG], 0
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_FILM_GRAIN_AR_CB_COEFFS], 7
    jne     .fail_decode_inter_frame
    cmp     dword [rel frame + AV1_FRAME_FILM_GRAIN_AR_CR_COEFFS], -8
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_AR_SHIFT_MINUS_6], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_SCALE_SHIFT], 3
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_OVERLAP], 1
    jne     .fail_decode_inter_frame
    cmp     byte [rel frame + AV1_FRAME_FILM_GRAIN_CLIP_RESTRICTED], 1
    jne     .fail_decode_inter_frame
    inc     qword [rel passed]
    jmp     .done
.fail_decode_inter_frame:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
