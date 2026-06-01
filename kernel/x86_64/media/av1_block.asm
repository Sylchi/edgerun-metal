; EdgeRun AV1 block syntax decoder subset - x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_symbol_read_symbol
extern er_av1_symbol_read_bool
extern er_av1_symbol_read_literal

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
AV1_TILE_WALK_PLANE_PTR             equ 576
AV1_TILE_WALK_PLANE_WIDTH           equ 584
AV1_TILE_WALK_PLANE_HEIGHT          equ 588
AV1_TILE_WALK_PLANE_LEN             equ 592
AV1_TILE_WALK_CHROMA_INDEX          equ 596
AV1_TILE_WALK_REFS_PTR              equ 600
AV1_TILE_WALK_REF_PLANE             equ 608
AV1_TILE_WALK_REF_INDEX             equ 632
AV1_TILE_WALK_STACK_SIZE            equ 640

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

; er_av1_block_decode_mv(ctx) -> eax=packed mv, rdx=error
; Reads signed 3-bit integer X/Y motion components and packs x in low 16, y high 16.
er_fn er_av1_block_decode_mv
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    mov     r12, rdi
    mov     rdi, r12
    mov     esi, AV1_MV_COMPONENT_BITS
    call    er_av1_symbol_read_literal
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    test    ebx, ebx
    jz      .x_ready
    mov     rdi, r12
    call    er_av1_symbol_read_bool
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .x_ready
    neg     ebx
.x_ready:
    mov     rdi, r12
    mov     esi, AV1_MV_COMPONENT_BITS
    call    er_av1_symbol_read_literal
    test    edx, edx
    jnz     .done
    mov     r13d, eax
    test    r13d, r13d
    jz      .pack
    mov     rdi, r12
    call    er_av1_symbol_read_bool
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .pack
    neg     r13d
.pack:
    movzx   eax, bx
    shl     r13d, 16
    or      eax, r13d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13
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
    call    .validate_chroma
    test    edx, edx
    jnz     .done
    xor     ebx, ebx
.row_loop:
    cmp     ebx, [rsp + AV1_TILE_WALK_HEIGHT]
    jae     .decode_chroma
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
    cmp     eax, AV1_PRED_MODE_MAX_SUPPORTED
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
.decode_chroma:
    mov     rax, [r13 + AV1_IMAGE_U_PTR]
    mov     [rsp + AV1_TILE_WALK_PLANE_PTR], rax
    mov     eax, [rsp + AV1_TILE_WALK_WIDTH]
    shr     eax, 1
    mov     [rsp + AV1_TILE_WALK_PLANE_WIDTH], eax
    mov     eax, [rsp + AV1_TILE_WALK_HEIGHT]
    shr     eax, 1
    mov     [rsp + AV1_TILE_WALK_PLANE_HEIGHT], eax
    mov     eax, [r13 + AV1_IMAGE_U_LEN]
    mov     [rsp + AV1_TILE_WALK_PLANE_LEN], eax
    mov     dword [rsp + AV1_TILE_WALK_CHROMA_INDEX], 0
    call    .decode_chroma_plane
    test    edx, edx
    jnz     .done
    mov     rax, [r13 + AV1_IMAGE_V_PTR]
    mov     [rsp + AV1_TILE_WALK_PLANE_PTR], rax
    mov     eax, [r13 + AV1_IMAGE_V_LEN]
    mov     [rsp + AV1_TILE_WALK_PLANE_LEN], eax
    mov     dword [rsp + AV1_TILE_WALK_CHROMA_INDEX], 1
    call    .decode_chroma_plane
    test    edx, edx
    jnz     .done
    jmp     .ok
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
    mov     eax, [rsp + 8 + AV1_TILE_WALK_BLOCK_Y]
    mul     dword [rsp + 8 + AV1_TILE_WALK_WIDTH]
    add     eax, [rsp + 8 + AV1_TILE_WALK_BLOCK_X]
    mov     rdx, [r13 + AV1_IMAGE_Y_PTR]
    add     rax, rdx
    ret

.prepare_edges:
    mov     eax, [rsp + 8 + AV1_TILE_WALK_BLOCK_Y]
    mul     dword [rsp + 8 + AV1_TILE_WALK_WIDTH]
    add     eax, [rsp + 8 + AV1_TILE_WALK_BLOCK_X]
    mov     rdx, [r13 + AV1_IMAGE_Y_PTR]
    add     rax, rdx
    mov     r10, rax
    cmp     dword [rsp + 8 + AV1_TILE_WALK_BLOCK_X], 0
    je      .above
    lea     rdx, [rsp + 8 + AV1_TILE_WALK_LEFT]
    mov     ecx, AV1_BLOCK_DIM_8
    mov     r9d, [rsp + 8 + AV1_TILE_WALK_WIDTH]
    lea     rax, [r10 - 1]
.left_loop:
    mov     sil, [rax]
    mov     [rdx], sil
    add     rax, r9
    inc     rdx
    dec     ecx
    jnz     .left_loop
.above:
    cmp     dword [rsp + 8 + AV1_TILE_WALK_BLOCK_Y], 0
    je      .edges_done
    mov     rax, r10
    mov     edx, [rsp + 8 + AV1_TILE_WALK_WIDTH]
    sub     rax, rdx
    lea     rdx, [rsp + 8 + AV1_TILE_WALK_ABOVE]
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

.validate_chroma:
    cmp     qword [r13 + AV1_IMAGE_U_PTR], 0
    je      .chroma_bad
    cmp     qword [r13 + AV1_IMAGE_V_PTR], 0
    je      .chroma_bad
    mov     eax, [rsp + 8 + AV1_TILE_WALK_WIDTH]
    shr     eax, 1
    cmp     eax, AV1_BLOCK_DIM_8
    jb      .chroma_bad
    test    eax, AV1_BLOCK_DIM_8 - 1
    jnz     .chroma_unsupported
    mov     edx, [rsp + 8 + AV1_TILE_WALK_HEIGHT]
    shr     edx, 1
    cmp     edx, AV1_BLOCK_DIM_8
    jb      .chroma_bad
    test    edx, AV1_BLOCK_DIM_8 - 1
    jnz     .chroma_unsupported
    mul     edx
    test    edx, edx
    jnz     .chroma_corrupt
    cmp     [r13 + AV1_IMAGE_U_LEN], eax
    jb      .chroma_corrupt
    cmp     [r13 + AV1_IMAGE_V_LEN], eax
    jb      .chroma_corrupt
    er_ok
    ret
.chroma_bad:
    er_err  ERROR_INVALID_PARAM
    ret
.chroma_unsupported:
    er_err  ERROR_UNSUPPORTED
    ret
.chroma_corrupt:
    er_err  ERROR_CORRUPT
    ret

.decode_chroma_plane:
    xor     ebx, ebx
.chroma_row_loop:
    cmp     ebx, [rsp + 8 + AV1_TILE_WALK_PLANE_HEIGHT]
    jae     .chroma_ok
    mov     [rsp + 8 + AV1_TILE_WALK_BLOCK_Y], ebx
    xor     r15d, r15d
.chroma_col_loop:
    cmp     r15d, [rsp + 8 + AV1_TILE_WALK_PLANE_WIDTH]
    jae     .chroma_next_row
    mov     [rsp + 8 + AV1_TILE_WALK_BLOCK_X], r15d
    mov     rdi, r12
    lea     rsi, [rsp + 8 + AV1_TILE_WALK_COEFFS]
    mov     rdx, r14
    mov     ecx, [rsp + 8 + AV1_TILE_WALK_DISABLE_UPDATE]
    call    er_av1_block_decode_coeffs_8x8
    test    edx, edx
    jnz     .chroma_ret
    mov     rdi, rsp
    add     rdi, 8 + AV1_TILE_WALK_DEQUANT
    lea     rsi, [rsp + 8 + AV1_TILE_WALK_COEFFS]
    mov     edx, [rsp + 8 + AV1_TILE_WALK_QSTEP]
    call    er_av1_block_dequant_8x8
    test    edx, edx
    jnz     .chroma_ret
    mov     rdi, rsp
    add     rdi, 8 + AV1_TILE_WALK_RESID
    lea     rsi, [rsp + 8 + AV1_TILE_WALK_DEQUANT]
    mov     edx, AV1_TX_TYPE_DCT_DCT
    call    er_av1_block_inverse_tx_8x8
    test    edx, edx
    jnz     .chroma_ret
    lea     rdi, [rsp + 8 + AV1_TILE_WALK_PRED]
    mov     esi, AV1_BLOCK_DIM_8
    xor     edx, edx
    xor     ecx, ecx
    mov     r8d, AV1_PRED_MODE_DC
    call    er_av1_block_predict_8x8
    test    edx, edx
    jnz     .chroma_ret
    mov     eax, [rsp + 8 + AV1_TILE_WALK_BLOCK_Y]
    mul     dword [rsp + 8 + AV1_TILE_WALK_PLANE_WIDTH]
    add     eax, [rsp + 8 + AV1_TILE_WALK_BLOCK_X]
    mov     rdi, [rsp + 8 + AV1_TILE_WALK_PLANE_PTR]
    add     rdi, rax
    mov     esi, [rsp + 8 + AV1_TILE_WALK_PLANE_WIDTH]
    lea     rdx, [rsp + 8 + AV1_TILE_WALK_PRED]
    mov     ecx, AV1_BLOCK_DIM_8
    lea     r8, [rsp + 8 + AV1_TILE_WALK_RESID]
    xor     r9d, r9d
    call    er_av1_block_reconstruct_add_8x8
    test    edx, edx
    jnz     .chroma_ret
    inc     dword [rsp + 8 + AV1_TILE_WALK_COUNT]
    add     r15d, AV1_BLOCK_DIM_8
    jmp     .chroma_col_loop
.chroma_next_row:
    add     ebx, AV1_BLOCK_DIM_8
    jmp     .chroma_row_loop
.chroma_ok:
    er_ok
.chroma_ret:
    ret

; er_av1_tile_decode_inter8x8_luma(ctx, image_desc, cdfs, refs, qstep, ref_index)
; Walks luma blocks, predicts from a decoded reference slot with zero MV, and adds residuals.
er_fn er_av1_tile_decode_inter8x8_luma
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_TILE_WALK_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rsi, rsi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     r8d, AV1_QUANT_STEP_MIN
    jb      .invalid_param
    cmp     r8d, AV1_QUANT_STEP_MAX
    ja      .invalid_param
    cmp     r9d, AV1_REF_COUNT
    jae     .invalid_param
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15d, r9d
    mov     [rsp + AV1_TILE_WALK_REFS_PTR], rcx
    mov     [rsp + AV1_TILE_WALK_REF_INDEX], r9d
    mov     [rsp + AV1_TILE_WALK_QSTEP], r8d
    mov     dword [rsp + AV1_TILE_WALK_DISABLE_UPDATE], 1
    mov     dword [rsp + AV1_TILE_WALK_COUNT], 0
    mov     rdi, r13
    call    er_av1_image_validate_420
    test    edx, edx
    jnz     .done
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
    mov     rdi, [rsp + AV1_TILE_WALK_REFS_PTR]
    mov     esi, r15d
    mov     edx, AV1_PLANE_Y
    lea     rcx, [rsp + AV1_TILE_WALK_REF_PLANE]
    call    er_av1_refs_get_plane
    test    edx, edx
    jnz     .done
    mov     eax, [rsp + AV1_TILE_WALK_REF_PLANE + AV1_PLANE_WIDTH]
    cmp     eax, [rsp + AV1_TILE_WALK_WIDTH]
    jb      .unsupported
    mov     eax, [rsp + AV1_TILE_WALK_REF_PLANE + AV1_PLANE_HEIGHT]
    cmp     eax, [rsp + AV1_TILE_WALK_HEIGHT]
    jb      .unsupported
    xor     ebx, ebx
.row_loop:
    cmp     ebx, [rsp + AV1_TILE_WALK_HEIGHT]
    jae     .decode_chroma
    mov     [rsp + AV1_TILE_WALK_BLOCK_Y], ebx
    xor     r15d, r15d
.col_loop:
    cmp     r15d, [rsp + AV1_TILE_WALK_WIDTH]
    jae     .next_row
    mov     [rsp + AV1_TILE_WALK_BLOCK_X], r15d
    mov     rdi, r12
    call    er_av1_block_decode_mv
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_TILE_WALK_CHROMA_INDEX], eax
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
    lea     rdx, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     ecx, [rsp + AV1_TILE_WALK_BLOCK_X]
    mov     r8d, [rsp + AV1_TILE_WALK_BLOCK_Y]
    mov     r9d, [rsp + AV1_TILE_WALK_CHROMA_INDEX]
    call    er_av1_block_inter_predict_8x8
    test    edx, edx
    jnz     .done
    mov     eax, [rsp + AV1_TILE_WALK_BLOCK_Y]
    mul     dword [rsp + AV1_TILE_WALK_WIDTH]
    add     eax, [rsp + AV1_TILE_WALK_BLOCK_X]
    mov     rdi, [r13 + AV1_IMAGE_Y_PTR]
    add     rdi, rax
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
.decode_chroma:
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     esi, [rsp + AV1_TILE_WALK_CHROMA_INDEX]
    mov     edx, AV1_PLANE_U
    lea     rcx, [rsp + AV1_TILE_WALK_REF_PLANE]
    call    er_av1_refs_get_plane
    test    edx, edx
    jnz     .done
    mov     rax, [r13 + AV1_IMAGE_U_PTR]
    mov     [rsp + AV1_TILE_WALK_PLANE_PTR], rax
    mov     eax, [r13 + AV1_IMAGE_WIDTH]
    shr     eax, 1
    mov     [rsp + AV1_TILE_WALK_PLANE_WIDTH], eax
    mov     eax, [r13 + AV1_IMAGE_HEIGHT]
    shr     eax, 1
    mov     [rsp + AV1_TILE_WALK_PLANE_HEIGHT], eax
    mov     eax, [r13 + AV1_IMAGE_U_LEN]
    mov     [rsp + AV1_TILE_WALK_PLANE_LEN], eax
    call    .decode_inter_chroma_plane
    test    edx, edx
    jnz     .done
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE + AV1_PLANE_PTR]
    mov     [rsp + AV1_TILE_WALK_PLANE_PTR], rdi
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE + AV1_PLANE_LEN]
    mov     [rsp + AV1_TILE_WALK_PLANE_LEN], rdi
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE + AV1_PLANE_WIDTH]
    mov     [rsp + AV1_TILE_WALK_PLANE_WIDTH], rdi
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE + AV1_PLANE_HEIGHT]
    mov     [rsp + AV1_TILE_WALK_PLANE_HEIGHT], rdi
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR - 32]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE - 32]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
    mov     rdi, [rsp + AV1_TILE_WALK_PLANE_PTR]
    mov     rdi, [rsp + AV1_TILE_WALK_REF_PLANE]
.ok:
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
.done:
    er_stack_free AV1_TILE_WALK_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_loop_filter_plane_8x8(plane, width, height, strength)
; Filters reconstructed 8-bit block boundaries for one 8x8-aligned plane.
er_fn er_av1_loop_filter_plane_8x8
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_BLOCK_DIM_8
    jb      .invalid_param
    test    esi, AV1_BLOCK_DIM_8 - 1
    jnz     .unsupported
    cmp     edx, AV1_BLOCK_DIM_8
    jb      .invalid_param
    test    edx, AV1_BLOCK_DIM_8 - 1
    jnz     .unsupported
    cmp     ecx, AV1_LOOP_FILTER_STRENGTH_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    xor     r15d, r15d
    test    ecx, ecx
    jz      .ok
    mov     ebx, AV1_BLOCK_DIM_8
.v_boundary_loop:
    cmp     ebx, r13d
    jae     .h_start
    xor     r10d, r10d
.v_row_loop:
    cmp     r10d, r14d
    jae     .v_next_boundary
    mov     eax, r10d
    imul    eax, r13d
    add     eax, ebx
    lea     r11, [r12 + rax]
    movzx   eax, byte [r11 - 1]
    movzx   edx, byte [r11]
    sub     eax, edx
    jns     .v_abs_ready
    neg     eax
.v_abs_ready:
    cmp     eax, ecx
    ja      .v_skip
    movzx   eax, byte [r11 - 1]
    movzx   edx, byte [r11]
    add     eax, edx
    inc     eax
    shr     eax, 1
    mov     [r11 - 1], al
    mov     [r11], al
    inc     r15d
.v_skip:
    inc     r10d
    jmp     .v_row_loop
.v_next_boundary:
    add     ebx, AV1_BLOCK_DIM_8
    jmp     .v_boundary_loop
.h_start:
    mov     ebx, AV1_BLOCK_DIM_8
.h_boundary_loop:
    cmp     ebx, r14d
    jae     .ok
    xor     r10d, r10d
.h_col_loop:
    cmp     r10d, r13d
    jae     .h_next_boundary
    mov     eax, ebx
    imul    eax, r13d
    add     eax, r10d
    lea     r11, [r12 + rax]
    mov     r9d, r13d
    mov     r8, r11
    sub     r8, r9
    movzx   eax, byte [r8]
    movzx   edx, byte [r11]
    sub     eax, edx
    jns     .h_abs_ready
    neg     eax
.h_abs_ready:
    cmp     eax, ecx
    ja      .h_skip
    mov     r8, r11
    sub     r8, r9
    movzx   eax, byte [r8]
    movzx   edx, byte [r11]
    add     eax, edx
    inc     eax
    shr     eax, 1
    mov     [r8], al
    mov     [r11], al
    inc     r15d
.h_skip:
    inc     r10d
    jmp     .h_col_loop
.h_next_boundary:
    add     ebx, AV1_BLOCK_DIM_8
    jmp     .h_boundary_loop
.ok:
    mov     eax, r15d
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_loop_filter_image_420(image_desc, strength)
; Applies the 8x8 boundary filter to Y, U, and V planes in a 4:2:0 image.
er_fn er_av1_loop_filter_image_420
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_LOOP_FILTER_STRENGTH_MAX
    ja      .invalid_param
    mov     r12, rdi
    mov     r15d, esi
    mov     r13d, [r12 + AV1_IMAGE_WIDTH]
    mov     r14d, [r12 + AV1_IMAGE_HEIGHT]
    cmp     qword [r12 + AV1_IMAGE_Y_PTR], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_U_PTR], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_V_PTR], 0
    je      .invalid_param
    mov     eax, r13d
    mul     r14d
    test    edx, edx
    jnz     .corrupt
    cmp     [r12 + AV1_IMAGE_Y_LEN], eax
    jb      .corrupt
    mov     ebx, r13d
    shr     ebx, 1
    mov     r11d, r14d
    shr     r11d, 1
    mov     eax, ebx
    mul     r11d
    test    edx, edx
    jnz     .corrupt
    cmp     [r12 + AV1_IMAGE_U_LEN], eax
    jb      .corrupt
    cmp     [r12 + AV1_IMAGE_V_LEN], eax
    jb      .corrupt
    mov     rdi, [r12 + AV1_IMAGE_Y_PTR]
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, r15d
    call    er_av1_loop_filter_plane_8x8
    test    edx, edx
    jnz     .done
    mov     r13d, eax
    mov     ebx, [r12 + AV1_IMAGE_WIDTH]
    shr     ebx, 1
    mov     r14d, [r12 + AV1_IMAGE_HEIGHT]
    shr     r14d, 1
    mov     rdi, [r12 + AV1_IMAGE_U_PTR]
    mov     esi, ebx
    mov     edx, r14d
    mov     ecx, r15d
    call    er_av1_loop_filter_plane_8x8
    test    edx, edx
    jnz     .done
    add     r13d, eax
    mov     rdi, [r12 + AV1_IMAGE_V_PTR]
    mov     esi, ebx
    mov     edx, r14d
    mov     ecx, r15d
    call    er_av1_loop_filter_plane_8x8
    test    edx, edx
    jnz     .done
    add     eax, r13d
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_refs_init(refs) -> eax=bytes cleared, rdx=error
; Clears the eight decoded-frame reference slots.
er_fn er_av1_refs_init
    test    rdi, rdi
    jz      .invalid_param
    xor     eax, eax
    mov     ecx, AV1_REF_STATE_SIZE
    cld
    rep     stosb
    mov     eax, AV1_REF_STATE_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_av1_refs_store_image(refs, index, image_desc) -> eax=AV1_IMAGE_SIZE
; Stores one validated 4:2:0 image descriptor in a reference slot.
er_fn er_av1_refs_store_image
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_REF_COUNT
    jae     .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rdx
    mov     rdi, r13
    call    er_av1_image_validate_420
    test    edx, edx
    jnz     .done
    mov     eax, ebx
    imul    eax, AV1_REF_SLOT_SIZE
    lea     rdi, [r12 + rax]
    mov     byte [rdi + AV1_REF_SLOT_VALID], 1
    add     rdi, AV1_REF_SLOT_IMAGE
    mov     rsi, r13
    mov     ecx, AV1_IMAGE_SIZE
    cld
    rep     movsb
    mov     eax, AV1_IMAGE_SIZE
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_av1_refs_refresh(refs, refresh_flags, image_desc) -> eax=slots refreshed
; Copies the current image descriptor to every reference slot selected by flags.
er_fn er_av1_refs_refresh
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_FRAME_REFRESH_ALL
    ja      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rdi, r14
    call    er_av1_image_validate_420
    test    edx, edx
    jnz     .done
    xor     ebx, ebx
    xor     r15d, r15d
.slot_loop:
    cmp     ebx, AV1_REF_COUNT
    jae     .ok
    mov     eax, 1
    mov     ecx, ebx
    shl     eax, cl
    test    eax, r13d
    jz      .next_slot
    mov     eax, ebx
    imul    eax, AV1_REF_SLOT_SIZE
    lea     rdi, [r12 + rax]
    mov     byte [rdi + AV1_REF_SLOT_VALID], 1
    add     rdi, AV1_REF_SLOT_IMAGE
    mov     rsi, r14
    mov     ecx, AV1_IMAGE_SIZE
    cld
    rep     movsb
    inc     r15d
.next_slot:
    inc     ebx
    jmp     .slot_loop
.ok:
    mov     eax, r15d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_refs_get_plane(refs, index, plane_id, out_plane) -> eax=AV1_PLANE_SIZE
; Exposes one plane descriptor from a valid reference slot.
er_fn er_av1_refs_get_plane
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_REF_COUNT
    jae     .invalid_param
    cmp     edx, AV1_PLANE_MAX
    ja      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     r13d, edx
    mov     r14, rcx
    mov     eax, ebx
    imul    eax, AV1_REF_SLOT_SIZE
    lea     r12, [r12 + rax]
    cmp     byte [r12 + AV1_REF_SLOT_VALID], 0
    je      .corrupt
    add     r12, AV1_REF_SLOT_IMAGE
    cmp     r13d, AV1_PLANE_Y
    je      .plane_y
    cmp     r13d, AV1_PLANE_U
    je      .plane_u
    mov     rax, [r12 + AV1_IMAGE_V_PTR]
    mov     [r14 + AV1_PLANE_PTR], rax
    mov     eax, [r12 + AV1_IMAGE_WIDTH]
    shr     eax, 1
    mov     [r14 + AV1_PLANE_WIDTH], eax
    mov     eax, [r12 + AV1_IMAGE_HEIGHT]
    shr     eax, 1
    mov     [r14 + AV1_PLANE_HEIGHT], eax
    mov     eax, [r12 + AV1_IMAGE_V_LEN]
    mov     [r14 + AV1_PLANE_LEN], eax
    jmp     .ok
.plane_u:
    mov     rax, [r12 + AV1_IMAGE_U_PTR]
    mov     [r14 + AV1_PLANE_PTR], rax
    mov     eax, [r12 + AV1_IMAGE_WIDTH]
    shr     eax, 1
    mov     [r14 + AV1_PLANE_WIDTH], eax
    mov     eax, [r12 + AV1_IMAGE_HEIGHT]
    shr     eax, 1
    mov     [r14 + AV1_PLANE_HEIGHT], eax
    mov     eax, [r12 + AV1_IMAGE_U_LEN]
    mov     [r14 + AV1_PLANE_LEN], eax
    jmp     .ok
.plane_y:
    mov     rax, [r12 + AV1_IMAGE_Y_PTR]
    mov     [r14 + AV1_PLANE_PTR], rax
    mov     eax, [r12 + AV1_IMAGE_WIDTH]
    mov     [r14 + AV1_PLANE_WIDTH], eax
    mov     eax, [r12 + AV1_IMAGE_HEIGHT]
    mov     [r14 + AV1_PLANE_HEIGHT], eax
    mov     eax, [r12 + AV1_IMAGE_Y_LEN]
    mov     [r14 + AV1_PLANE_LEN], eax
.ok:
    mov     eax, AV1_PLANE_SIZE
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
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_image_validate_420(image_desc) -> eax=raw420 bytes, rdx=error
; Validates an 8-bit 4:2:0 image descriptor used by decoded-frame references.
er_fn er_av1_image_validate_420
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    mov     r12, rdi
    cmp     qword [r12 + AV1_IMAGE_Y_PTR], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_U_PTR], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_V_PTR], 0
    je      .invalid_param
    mov     r13d, [r12 + AV1_IMAGE_WIDTH]
    cmp     r13d, AV1_BLOCK_DIM_8
    jb      .invalid_param
    test    r13d, 1
    jnz     .unsupported
    mov     ebx, [r12 + AV1_IMAGE_HEIGHT]
    cmp     ebx, AV1_BLOCK_DIM_8
    jb      .invalid_param
    test    ebx, 1
    jnz     .unsupported
    mov     eax, r13d
    mul     ebx
    test    edx, edx
    jnz     .corrupt
    cmp     [r12 + AV1_IMAGE_Y_LEN], eax
    jb      .corrupt
    mov     r13d, eax
    mov     eax, [r12 + AV1_IMAGE_WIDTH]
    shr     eax, 1
    mov     ebx, [r12 + AV1_IMAGE_HEIGHT]
    shr     ebx, 1
    mul     ebx
    test    edx, edx
    jnz     .corrupt
    cmp     [r12 + AV1_IMAGE_U_LEN], eax
    jb      .corrupt
    cmp     [r12 + AV1_IMAGE_V_LEN], eax
    jb      .corrupt
    add     eax, eax
    add     eax, r13d
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
    er_pop  rbx, r12, r13
    er_ret

; er_av1_block_inter_predict_8x8(dst, dst_stride, ref_plane, block_x, block_y, mv)
; rdi=dst, esi=dst_stride, rdx=AV1_PLANE_*, ecx=block_x, r8d=block_y.
; r9d packs signed integer mv_x in low 16 bits and mv_y in high 16 bits.
er_fn er_av1_block_inter_predict_8x8
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_BLOCK_DIM_8
    jb      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     qword [rdx + AV1_PLANE_PTR], 0
    je      .invalid_param
    cmp     dword [rdx + AV1_PLANE_WIDTH], AV1_BLOCK_DIM_8
    jb      .invalid_param
    cmp     dword [rdx + AV1_PLANE_HEIGHT], AV1_BLOCK_DIM_8
    jb      .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, [rdx + AV1_PLANE_PTR]
    mov     r14d, [rdx + AV1_PLANE_WIDTH]
    mov     r15d, [rdx + AV1_PLANE_HEIGHT]
    mov     r10d, [rdx + AV1_PLANE_LEN]
    mov     eax, r14d
    mul     r15d
    test    edx, edx
    jnz     .corrupt
    cmp     r10d, eax
    jb      .corrupt
    movsx   eax, r9w
    add     ecx, eax
    js      .corrupt
    mov     eax, r9d
    sar     eax, 16
    add     r8d, eax
    js      .corrupt
    lea     eax, [rcx + AV1_BLOCK_DIM_8 - 1]
    cmp     eax, r14d
    jae     .corrupt
    lea     eax, [r8 + AV1_BLOCK_DIM_8 - 1]
    cmp     eax, r15d
    jae     .corrupt
    mov     eax, r8d
    mul     r14d
    add     eax, ecx
    add     r13, rax
    xor     edx, edx
.row:
    cmp     edx, AV1_BLOCK_DIM_8
    jae     .ok
    mov     eax, edx
    imul    eax, ebx
    lea     r10, [r12 + rax]
    mov     eax, edx
    imul    eax, r14d
    lea     r11, [r13 + rax]
    mov     rax, [r11]
    mov     [r10], rax
    inc     edx
    jmp     .row
.ok:
    mov     eax, AV1_BLOCK_PIXELS_8X8
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_block_predict_8x8(dst, stride, left, above, mode)
; rdi=dst, esi=stride, rdx=left[8] or 0, rcx=above[8] or 0, r8d=mode.
; Produces an 8-bit 8x8 intra predictor for the supported intra modes.
er_fn er_av1_block_predict_8x8
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    cmp     esi, AV1_BLOCK_DIM_8
    jb      .invalid_param
    cmp     r8d, AV1_PRED_MODE_MAX_SUPPORTED
    ja      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15, rcx
    cmp     r8d, AV1_PRED_MODE_DC
    je      .dc
    cmp     r8d, AV1_PRED_MODE_V
    je      .vertical
    cmp     r8d, AV1_PRED_MODE_H
    je      .horizontal
    cmp     r8d, AV1_PRED_MODE_PAETH
    je      .paeth
    jmp     .smooth
.horizontal:
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
.paeth:
    test    r14, r14
    jz      .invalid_param
    test    r15, r15
    jz      .invalid_param
    xor     ebx, ebx
.paeth_row:
    cmp     ebx, AV1_BLOCK_DIM_8
    jae     .ok
    mov     edx, ebx
    imul    edx, r13d
    lea     r9, [r12 + rdx]
    xor     ecx, ecx
.paeth_col:
    cmp     ecx, AV1_BLOCK_DIM_8
    jae     .paeth_next_row
    movzx   eax, byte [r14 + rbx]
    movzx   edx, byte [r15 + rcx]
    add     eax, edx
    sub     eax, AV1_PIXEL_MID_8
    mov     esi, eax
    movzx   edx, byte [r14 + rbx]
    sub     esi, edx
    jns     .paeth_left_abs
    neg     esi
.paeth_left_abs:
    mov     r10d, eax
    movzx   edx, byte [r15 + rcx]
    sub     r10d, edx
    jns     .paeth_above_abs
    neg     r10d
.paeth_above_abs:
    cmp     esi, r10d
    jbe     .paeth_store_left
    movzx   eax, byte [r15 + rcx]
    jmp     .paeth_store
.paeth_store_left:
    movzx   eax, byte [r14 + rbx]
.paeth_store:
    mov     [r9 + rcx], al
    inc     ecx
    jmp     .paeth_col
.paeth_next_row:
    inc     ebx
    jmp     .paeth_row
.smooth:
    test    r14, r14
    jz      .invalid_param
    test    r15, r15
    jz      .invalid_param
    xor     ebx, ebx
.smooth_row:
    cmp     ebx, AV1_BLOCK_DIM_8
    jae     .ok
    mov     edx, ebx
    imul    edx, r13d
    lea     r9, [r12 + rdx]
    xor     ecx, ecx
.smooth_col:
    cmp     ecx, AV1_BLOCK_DIM_8
    jae     .smooth_next_row
    movzx   eax, byte [r14 + rbx]
    movzx   edx, byte [r15 + rcx]
    add     eax, edx
    inc     eax
    shr     eax, 1
    mov     [r9 + rcx], al
    inc     ecx
    jmp     .smooth_col
.smooth_next_row:
    inc     ebx
    jmp     .smooth_row
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
