; EdgeRun AV1 block syntax decoder subset - x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_symbol_read_symbol
extern er_av1_symbol_read_bool

AV1_TILE_WALK_BLOCK                 equ 0
AV1_TILE_WALK_COEFFS                equ 16
AV1_TILE_WALK_DEQUANT               equ 144
AV1_TILE_WALK_RESID                 equ 272
AV1_TILE_WALK_PRED                  equ 400
AV1_TILE_WALK_LEFT                  equ 528
AV1_TILE_WALK_ABOVE                 equ 536
AV1_TILE_WALK_WIDTH                 equ 544
AV1_TILE_WALK_HEIGHT                equ 548
AV1_TILE_WALK_BLOCK_X               equ 552
AV1_TILE_WALK_BLOCK_Y               equ 556
AV1_TILE_WALK_DISABLE_UPDATE        equ 560
AV1_TILE_WALK_QSTEP                 equ 564
AV1_TILE_WALK_COUNT                 equ 568
AV1_TILE_WALK_STACK_SIZE            equ 576

SECTION .text

; er_av1_block_cdfs_init(cdfs) -> eax=bytes initialized, rdx=error
; Initializes the first supported intra block CDF slice from AV1 defaults.
; rdi=cdf workspace, size AV1_BLOCK_CDFS_SIZE.
er_fn er_av1_block_cdfs_init
    test    rdi, rdi
    jz      .invalid_param
    lea     rsi, [rel av1_block_default_cdfs]
    mov     ecx, AV1_BLOCK_CDFS_SIZE
    cld
    rep     movsb
    mov     eax, AV1_BLOCK_CDFS_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_av1_block_decode_intra_symbols(ctx, block_desc, cdfs, disable_update)
; rdi=symbol ctx, rsi=block desc, rdx=cdf workspace, ecx=disable_update.
; Reads partition, y_mode, skip, and tx_size symbols from an active entropy context.
er_fn er_av1_block_decode_intra_symbols
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
    mov     rdi, r12
    lea     rsi, [r14 + AV1_BLOCK_CDFS_PARTITION]
    mov     edx, AV1_BLOCK_PARTITION_SYMBOLS_W8
    mov     ecx, r15d
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_BLOCK_PARTITION], al
    mov     rdi, r12
    lea     rsi, [r14 + AV1_BLOCK_CDFS_Y_MODE]
    mov     edx, AV1_BLOCK_Y_MODE_SYMBOLS
    mov     ecx, r15d
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_BLOCK_Y_MODE], al
    mov     rdi, r12
    lea     rsi, [r14 + AV1_BLOCK_CDFS_SKIP]
    mov     edx, AV1_BLOCK_SKIP_SYMBOLS
    mov     ecx, r15d
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_BLOCK_SKIP], al
    mov     rdi, r12
    lea     rsi, [r14 + AV1_BLOCK_CDFS_TX_SIZE]
    mov     edx, AV1_BLOCK_TX_SIZE_SYMBOLS_8X8
    mov     ecx, r15d
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .done
    mov     [r13 + AV1_BLOCK_TX_SIZE], al
    mov     eax, AV1_BLOCK_SIZE
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_block_decode_coeffs_8x8(ctx, coeffs, cdfs, disable_update)
; rdi=symbol ctx, rsi=i16 coeffs[64], rdx=cdf workspace, ecx=disable_update.
; Decodes a deterministic 8x8 coefficient map and signed levels.
er_fn er_av1_block_decode_coeffs_8x8
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     [rsp], ecx
    mov     dword [rsp + 4], 0
    xor     ebx, ebx
.clear_loop:
    cmp     ebx, AV1_BLOCK_PIXELS_8X8
    jae     .decode_loop_start
    mov     word [r13 + rbx * 2], 0
    inc     ebx
    jmp     .clear_loop
.decode_loop_start:
    xor     ebx, ebx
.decode_loop:
    cmp     ebx, AV1_BLOCK_PIXELS_8X8
    jae     .ok
    mov     rdi, r12
    lea     rsi, [r14 + AV1_BLOCK_CDFS_COEFF_NONZERO]
    mov     edx, AV1_BLOCK_COEFF_NONZERO_SYMBOLS
    mov     ecx, [rsp]
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .next_coeff
    mov     rdi, r12
    lea     rsi, [r14 + AV1_BLOCK_CDFS_COEFF_LEVEL]
    mov     edx, AV1_BLOCK_COEFF_LEVEL_SYMBOLS
    mov     ecx, [rsp]
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .done
    inc     eax
    mov     [rsp + 8], eax
    mov     rdi, r12
    call    er_av1_symbol_read_bool
    test    edx, edx
    jnz     .done
    mov     esi, [rsp + 8]
    test    eax, eax
    jz      .store_coeff
    neg     esi
.store_coeff:
    mov     [r13 + rbx * 2], si
    inc     dword [rsp + 4]
.next_coeff:
    inc     ebx
    jmp     .decode_loop
.ok:
    mov     eax, [rsp + 4]
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_block_dequant_8x8(dst, src, qstep)
; rdi=i16 residual[64], rsi=i16 coeff levels[64], edx=quant step.
er_fn er_av1_block_dequant_8x8
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, AV1_QUANT_STEP_MIN
    jb      .invalid_param
    cmp     edx, AV1_QUANT_STEP_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    xor     ebx, ebx
.loop:
    cmp     ebx, AV1_BLOCK_PIXELS_8X8
    jae     .ok
    movsx   eax, word [r13 + rbx * 2]
    imul    eax, r14d
    cmp     eax, AV1_COEFF_MIN_16
    jl      .clip_low
    cmp     eax, AV1_COEFF_MAX_16
    jg      .clip_high
    jmp     .store
.clip_low:
    mov     eax, AV1_COEFF_MIN_16
    jmp     .store
.clip_high:
    mov     eax, AV1_COEFF_MAX_16
.store:
    mov     [r12 + rbx * 2], ax
    inc     ebx
    jmp     .loop
.ok:
    mov     eax, AV1_BLOCK_PIXELS_8X8
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_block_inverse_tx_8x8(dst, coeffs, tx_type)
; rdi=i16 residual[64], rsi=i16 coeffs[64], edx=AV1_TX_TYPE_*.
er_fn er_av1_block_inverse_tx_8x8
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    cmp     edx, AV1_TX_TYPE_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    xor     ebx, ebx
.clear_loop:
    cmp     ebx, AV1_BLOCK_PIXELS_8X8
    jae     .dispatch
    mov     word [r12 + rbx * 2], 0
    inc     ebx
    jmp     .clear_loop
.dispatch:
    cmp     r14d, AV1_TX_TYPE_IDTX
    je      .idtx
    cmp     r14d, AV1_TX_TYPE_DC_ONLY
    je      .dc_only
    jmp     .dct_dct
.idtx:
    xor     ebx, ebx
.idtx_loop:
    cmp     ebx, AV1_BLOCK_PIXELS_8X8
    jae     .ok
    mov     ax, [r13 + rbx * 2]
    mov     [r12 + rbx * 2], ax
    inc     ebx
    jmp     .idtx_loop
.dc_only:
    mov     ax, [r13]
    xor     ebx, ebx
.dc_loop:
    cmp     ebx, AV1_BLOCK_PIXELS_8X8
    jae     .ok
    mov     [r12 + rbx * 2], ax
    inc     ebx
    jmp     .dc_loop
.dct_dct:
    xor     r14d, r14d
.dct_y_loop:
    cmp     r14d, AV1_BLOCK_DIM_8
    jae     .ok
    xor     r15d, r15d
.dct_x_loop:
    cmp     r15d, AV1_BLOCK_DIM_8
    jae     .dct_next_y
    mov     dword [rsp], 0
    mov     dword [rsp + 4], 0
.dct_v_loop:
    cmp     dword [rsp + 4], AV1_BLOCK_DIM_8
    jae     .dct_store
    mov     dword [rsp + 8], 0
.dct_u_loop:
    cmp     dword [rsp + 8], AV1_BLOCK_DIM_8
    jae     .dct_next_v
    mov     eax, [rsp + 4]
    shl     eax, 3
    add     eax, [rsp + 8]
    movsx   eax, word [r13 + rax * 2]
    test    eax, eax
    jz      .dct_next_u
    mov     ebx, [rsp + 8]
    shl     ebx, 3
    add     ebx, r15d
    movsx   ebx, word [rel av1_idct8_basis + rbx * 2]
    imul    eax, ebx
    mov     ebx, [rsp + 4]
    shl     ebx, 3
    add     ebx, r14d
    movsx   ebx, word [rel av1_idct8_basis + rbx * 2]
    imul    eax, ebx
    add     [rsp], eax
.dct_next_u:
    inc     dword [rsp + 8]
    jmp     .dct_u_loop
.dct_next_v:
    inc     dword [rsp + 4]
    jmp     .dct_v_loop
.dct_store:
    mov     eax, [rsp]
    add     eax, 1 << (AV1_TX_DCT_SCALE_BITS - 1)
    jmp     .dct_shift
.dct_shift:
    sar     eax, AV1_TX_DCT_SCALE_BITS
    cmp     eax, AV1_COEFF_MIN_16
    jl      .dct_clip_low
    cmp     eax, AV1_COEFF_MAX_16
    jg      .dct_clip_high
    jmp     .dct_write
.dct_clip_low:
    mov     eax, AV1_COEFF_MIN_16
    jmp     .dct_write
.dct_clip_high:
    mov     eax, AV1_COEFF_MAX_16
.dct_write:
    mov     ebx, r14d
    shl     ebx, 3
    add     ebx, r15d
    mov     [r12 + rbx * 2], ax
    inc     r15d
    jmp     .dct_x_loop
.dct_next_y:
    inc     r14d
    jmp     .dct_y_loop
.ok:
    mov     eax, AV1_BLOCK_PIXELS_8X8
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_decode_intra8x8_luma(ctx, image_desc, cdfs, qstep, disable_update)
; Walks an 8-bit luma tile in 8x8 blocks and reconstructs into image_desc Y.
er_fn er_av1_tile_decode_intra8x8_luma
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_TILE_WALK_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     ecx, AV1_QUANT_STEP_MIN
    jb      .invalid_param
    cmp     ecx, AV1_QUANT_STEP_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     [rsp + AV1_TILE_WALK_QSTEP], ecx
    mov     [rsp + AV1_TILE_WALK_DISABLE_UPDATE], r8d
    mov     dword [rsp + AV1_TILE_WALK_COUNT], 0
    mov     eax, [r13 + AV1_IMAGE_WIDTH]
    cmp     eax, AV1_BLOCK_WALK_MIN_DIM
    jb      .invalid_param
    test    eax, AV1_BLOCK_DIM_8 - 1
    jnz     .unsupported
    mov     [rsp + AV1_TILE_WALK_WIDTH], eax
    mov     eax, [r13 + AV1_IMAGE_HEIGHT]
    cmp     eax, AV1_BLOCK_WALK_MIN_DIM
    jb      .invalid_param
    test    eax, AV1_BLOCK_DIM_8 - 1
    jnz     .unsupported
    mov     [rsp + AV1_TILE_WALK_HEIGHT], eax
    cmp     qword [r13 + AV1_IMAGE_Y_PTR], 0
    je      .invalid_param
    mov     eax, [rsp + AV1_TILE_WALK_WIDTH]
    mul     dword [rsp + AV1_TILE_WALK_HEIGHT]
    test    edx, edx
    jnz     .corrupt
    cmp     [r13 + AV1_IMAGE_Y_LEN], eax
    jb      .corrupt
    call    .fill_chroma_neutral
    xor     ebx, ebx
.row_loop:
    cmp     ebx, [rsp + AV1_TILE_WALK_HEIGHT]
    jae     .ok
    mov     [rsp + AV1_TILE_WALK_BLOCK_Y], ebx
    xor     r15d, r15d
.col_loop:
    cmp     r15d, [rsp + AV1_TILE_WALK_WIDTH]
    jae     .next_row
    mov     [rsp + AV1_TILE_WALK_BLOCK_X], r15d
    call    .prepare_edges
    mov     rdi, r12
    lea     rsi, [rsp + AV1_TILE_WALK_BLOCK]
    mov     rdx, r14
    mov     ecx, [rsp + AV1_TILE_WALK_DISABLE_UPDATE]
    call    er_av1_block_decode_intra_symbols
    test    edx, edx
    jnz     .done
    cmp     byte [rsp + AV1_TILE_WALK_BLOCK + AV1_BLOCK_PARTITION], 0
    jne     .unsupported
    cmp     byte [rsp + AV1_TILE_WALK_BLOCK + AV1_BLOCK_TX_SIZE], 0
    ja      .unsupported
    movzx   eax, byte [rsp + AV1_TILE_WALK_BLOCK + AV1_BLOCK_Y_MODE]
    cmp     eax, AV1_PRED_MODE_H
    ja      .unsupported
    mov     rdi, r12
    lea     rsi, [rsp + AV1_TILE_WALK_COEFFS]
    mov     rdx, r14
    mov     ecx, [rsp + AV1_TILE_WALK_DISABLE_UPDATE]
    call    er_av1_block_decode_coeffs_8x8
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    add     rdi, AV1_TILE_WALK_DEQUANT
    lea     rsi, [rsp + AV1_TILE_WALK_COEFFS]
    mov     edx, [rsp + AV1_TILE_WALK_QSTEP]
    call    er_av1_block_dequant_8x8
    test    edx, edx
    jnz     .done
    mov     rdi, rsp
    add     rdi, AV1_TILE_WALK_RESID
    lea     rsi, [rsp + AV1_TILE_WALK_DEQUANT]
    mov     edx, AV1_TX_TYPE_DCT_DCT
    call    er_av1_block_inverse_tx_8x8
    test    edx, edx
    jnz     .done
    lea     rdi, [rsp + AV1_TILE_WALK_PRED]
    mov     esi, AV1_BLOCK_DIM_8
    xor     edx, edx
    cmp     dword [rsp + AV1_TILE_WALK_BLOCK_X], 0
    je      .left_ready
    lea     rdx, [rsp + AV1_TILE_WALK_LEFT]
.left_ready:
    xor     ecx, ecx
    cmp     dword [rsp + AV1_TILE_WALK_BLOCK_Y], 0
    je      .above_ready
    lea     rcx, [rsp + AV1_TILE_WALK_ABOVE]
.above_ready:
    movzx   r8d, byte [rsp + AV1_TILE_WALK_BLOCK + AV1_BLOCK_Y_MODE]
    call    er_av1_block_predict_8x8
    test    edx, edx
    jnz     .done
    call    .block_dst_ptr
    mov     rdi, rax
    mov     esi, [rsp + AV1_TILE_WALK_WIDTH]
    lea     rdx, [rsp + AV1_TILE_WALK_PRED]
    mov     ecx, AV1_BLOCK_DIM_8
    lea     r8, [rsp + AV1_TILE_WALK_RESID]
    xor     r9d, r9d
    call    er_av1_block_reconstruct_add_8x8
    test    edx, edx
    jnz     .done
    inc     dword [rsp + AV1_TILE_WALK_COUNT]
    add     r15d, AV1_BLOCK_DIM_8
    jmp     .col_loop
.next_row:
    add     ebx, AV1_BLOCK_DIM_8
    jmp     .row_loop
.ok:
    mov     eax, [rsp + AV1_TILE_WALK_COUNT]
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
    er_stack_free AV1_TILE_WALK_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

.block_dst_ptr:
    mov     eax, [rsp + AV1_TILE_WALK_BLOCK_Y]
    mul     dword [rsp + AV1_TILE_WALK_WIDTH]
    add     eax, [rsp + AV1_TILE_WALK_BLOCK_X]
    mov     rdx, [r13 + AV1_IMAGE_Y_PTR]
    add     rax, rdx
    ret

.prepare_edges:
    cmp     dword [rsp + AV1_TILE_WALK_BLOCK_X], 0
    je      .above
    call    .block_dst_ptr
    lea     rdx, [rsp + AV1_TILE_WALK_LEFT]
    mov     ecx, AV1_BLOCK_DIM_8
    mov     r9d, [rsp + AV1_TILE_WALK_WIDTH]
    lea     rax, [rax - 1]
.left_loop:
    mov     sil, [rax]
    mov     [rdx], sil
    add     rax, r9
    inc     rdx
    dec     ecx
    jnz     .left_loop
.above:
    cmp     dword [rsp + AV1_TILE_WALK_BLOCK_Y], 0
    je      .edges_done
    call    .block_dst_ptr
    mov     edx, [rsp + AV1_TILE_WALK_WIDTH]
    sub     rax, rdx
    lea     rdx, [rsp + AV1_TILE_WALK_ABOVE]
    mov     ecx, AV1_BLOCK_DIM_8
.above_loop:
    mov     sil, [rax]
    mov     [rdx], sil
    inc     rax
    inc     rdx
    dec     ecx
    jnz     .above_loop
.edges_done:
    ret

.fill_chroma_neutral:
    mov     rdi, [r13 + AV1_IMAGE_U_PTR]
    mov     ecx, [r13 + AV1_IMAGE_U_LEN]
    call    .fill_plane_neutral
    mov     rdi, [r13 + AV1_IMAGE_V_PTR]
    mov     ecx, [r13 + AV1_IMAGE_V_LEN]
    call    .fill_plane_neutral
    ret

.fill_plane_neutral:
    test    rdi, rdi
    jz      .fill_done
    test    ecx, ecx
    jz      .fill_done
.fill_loop:
    mov     byte [rdi], AV1_PIXEL_MID_8
    inc     rdi
    dec     ecx
    jnz     .fill_loop
.fill_done:
    ret

; er_av1_block_predict_8x8(dst, stride, left, above, mode)
; rdi=dst, esi=stride, rdx=left[8] or 0, rcx=above[8] or 0, r8d=mode.
; Produces an 8-bit 8x8 intra predictor for the supported DC/V/H modes.
er_fn er_av1_block_predict_8x8
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_BLOCK_DIM_8
    jb      .invalid_param
    cmp     r8d, AV1_PRED_MODE_H
    ja      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15, rcx
    cmp     r8d, AV1_PRED_MODE_DC
    je      .dc
    cmp     r8d, AV1_PRED_MODE_V
    je      .vertical
    test    r14, r14
    jz      .invalid_param
    xor     ebx, ebx
.h_row:
    cmp     ebx, AV1_BLOCK_DIM_8
    jae     .ok
    movzx   eax, byte [r14 + rbx]
    mov     edx, ebx
    imul    edx, r13d
    lea     r9, [r12 + rdx]
    mov     ecx, AV1_BLOCK_DIM_8
.h_col:
    mov     [r9], al
    inc     r9
    loop    .h_col
    inc     ebx
    jmp     .h_row
.vertical:
    test    r15, r15
    jz      .invalid_param
    xor     ebx, ebx
.v_row:
    cmp     ebx, AV1_BLOCK_DIM_8
    jae     .ok
    mov     edx, ebx
    imul    edx, r13d
    lea     r9, [r12 + rdx]
    mov     r10, r15
    mov     ecx, AV1_BLOCK_DIM_8
.v_col:
    movzx   eax, byte [r10]
    mov     [r9], al
    inc     r10
    inc     r9
    loop    .v_col
    inc     ebx
    jmp     .v_row
.dc:
    xor     eax, eax
    xor     ebx, ebx
    test    r14, r14
    jz      .dc_above
.dc_left:
    add     al, [r14 + rbx]
    adc     ah, 0
    inc     ebx
    cmp     ebx, AV1_BLOCK_DIM_8
    jb      .dc_left
.dc_above:
    xor     ebx, ebx
    test    r15, r15
    jz      .dc_divisor
.dc_above_loop:
    add     al, [r15 + rbx]
    adc     ah, 0
    inc     ebx
    cmp     ebx, AV1_BLOCK_DIM_8
    jb      .dc_above_loop
.dc_divisor:
    test    r14, r14
    jz      .dc_above_only
    test    r15, r15
    jz      .dc_left_only
    add     eax, AV1_BLOCK_DIM_8
    shr     eax, 4
    jmp     .fill
.dc_left_only:
    add     eax, 4
    shr     eax, 3
    jmp     .fill
.dc_above_only:
    test    r15, r15
    jz      .dc_none
    add     eax, 4
    shr     eax, 3
    jmp     .fill
.dc_none:
    mov     eax, AV1_PIXEL_MID_8
.fill:
    xor     ebx, ebx
.fill_row:
    cmp     ebx, AV1_BLOCK_DIM_8
    jae     .ok
    mov     edx, ebx
    imul    edx, r13d
    lea     r9, [r12 + rdx]
    mov     ecx, AV1_BLOCK_DIM_8
.fill_col:
    mov     [r9], al
    inc     r9
    loop    .fill_col
    inc     ebx
    jmp     .fill_row
.ok:
    mov     eax, AV1_BLOCK_PIXELS_8X8
    er_ok
    jmp     .predict_done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.predict_done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_block_reconstruct_add_8x8(dst, dst_stride, pred, pred_stride, coeffs, tx)
; rdi=dst, esi=dst_stride, rdx=pred, ecx=pred_stride, r8=residual[64] i16, r9d=unused.
; Adds transformed residuals to the predictor.
er_fn er_av1_block_reconstruct_add_8x8
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    cmp     esi, AV1_BLOCK_DIM_8
    jb      .invalid_param
    cmp     ecx, AV1_BLOCK_DIM_8
    jb      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx
    xor     ebx, ebx
.row:
    cmp     ebx, AV1_BLOCK_DIM_8
    jae     .ok
    mov     eax, ebx
    imul    eax, r13d
    lea     r10, [r12 + rax]
    mov     eax, ebx
    imul    eax, r15d
    lea     r11, [r14 + rax]
    imul    eax, ebx, AV1_BLOCK_DIM_8
    lea     rcx, [r8 + rax * 2]
    xor     edx, edx
.col:
    cmp     edx, AV1_BLOCK_DIM_8
    jae     .next_row
    movzx   eax, byte [r11 + rdx]
    movsx   esi, word [rcx + rdx * 2]
.add_coeff:
    add     eax, esi
    js      .clip_low
    cmp     eax, AV1_PIXEL_MAX_8
    ja      .clip_high
    jmp     .store
.clip_low:
    xor     eax, eax
    jmp     .store
.clip_high:
    mov     eax, AV1_PIXEL_MAX_8
.store:
    mov     [r10 + rdx], al
    inc     edx
    jmp     .col
.next_row:
    inc     ebx
    jmp     .row
.ok:
    mov     eax, AV1_BLOCK_PIXELS_8X8
    er_ok
    jmp     .recon_done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.recon_done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

SECTION .rodata

av1_block_default_cdfs:
    dw 19132, 25510, 30392, AV1_CDF_PROB_TOP, 0
    times 3 dw 0
    dw 22801, 23489, 24293, 24756, 25601, 26123, 26606
    dw 27418, 27945, 29228, 29685, 30349, AV1_CDF_PROB_TOP, 0
    times 2 dw 0
    dw 31671, AV1_CDF_PROB_TOP, 0
    dw 0
    dw 19968, AV1_CDF_PROB_TOP, 0
    dw 0
    dw AV1_CDF_BOOL_SPLIT, AV1_CDF_PROB_TOP, 0
    dw 0
    dw 8192, 16384, 24576, AV1_CDF_PROB_TOP, 0
    dw 0

av1_idct8_basis:
    dw 64, 64, 64, 64, 64, 64, 64, 64
    dw 89, 75, 50, 18, -18, -50, -75, -89
    dw 83, 35, -35, -83, -83, -35, 35, 83
    dw 75, -18, -89, -50, 50, 89, 18, -75
    dw 64, -64, -64, 64, 64, -64, -64, 64
    dw 50, -89, 18, 75, -75, -18, 89, -50
    dw 35, -83, 83, -35, -35, 83, -83, 35
    dw 18, -50, 75, -89, 89, -75, 50, -18
