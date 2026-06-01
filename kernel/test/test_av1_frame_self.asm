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
outbuf: resb 32

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
    mov     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_UNIFORM], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_COLS_LOG2], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_ROWS_LOG2], 1
    mov     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 2
    mov     dword [rel frame + AV1_FRAME_TILE_INFO_CONTEXT_UPDATE_ID], 2
    mov     rdi, outbuf
    mov     esi, 32
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
    mov     esi, 32
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
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 1
    jne     .fail_decode_non_reduced_keyframe
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_COUNT], 4
    jne     .fail_decode_non_reduced_keyframe
    cmp     byte [rel frame + AV1_FRAME_TILE_INFO_TILE_SIZE_BYTES], 2
    jne     .fail_decode_non_reduced_keyframe
    inc     qword [rel passed]
    jmp     .encode_nonshown_keyframe
.fail_decode_non_reduced_keyframe:
    inc     qword [rel failed]

.encode_nonshown_keyframe:
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 4
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
    mov     rdi, outbuf
    mov     esi, 32
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
    mov     esi, 32
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
    cmp     byte [rel frame + AV1_FRAME_ALLOW_INTRABC], 0
    jne     .fail_decode_nonshown_keyframe
    cmp     dword [rel frame + AV1_FRAME_TILE_INFO_COUNT], 1
    jne     .fail_decode_nonshown_keyframe
    inc     qword [rel passed]
    jmp     .encode_show_existing_frame
.fail_decode_nonshown_keyframe:
    inc     qword [rel failed]

.encode_show_existing_frame:
    mov     byte [rel frame + AV1_FRAME_SHOW_EXISTING_FRAME], 1
    mov     byte [rel frame + AV1_FRAME_EXISTING_FRAME_IDX], 5
    mov     rdi, outbuf
    mov     esi, 32
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
    mov     esi, 32
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
    cmp     byte [rel frame + AV1_FRAME_SHOW_FRAME], 1
    jne     .fail_decode_show_existing_frame
    cmp     dword [rel frame + AV1_FRAME_TILE_LEN], 0
    jne     .fail_decode_show_existing_frame
    inc     qword [rel passed]
    jmp     .encode_intra_only_frame
.fail_decode_show_existing_frame:
    inc     qword [rel failed]

.encode_intra_only_frame:
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 5
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
    mov     rdi, outbuf
    mov     esi, 32
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
    mov     esi, 32
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
    inc     qword [rel passed]
    jmp     .encode_inter_frame
.fail_decode_intra_only_frame:
    inc     qword [rel failed]

.encode_inter_frame:
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 5
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
    mov     rdi, outbuf
    mov     esi, 32
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
    mov     esi, 32
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
