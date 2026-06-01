; EdgeRun AV1 block syntax self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_symbol_init
extern er_av1_block_cdfs_init
extern er_av1_block_decode_intra_symbols
extern er_av1_block_decode_coeffs_8x8
extern er_av1_block_decode_mv
extern er_av1_block_dequant_8x8
extern er_av1_block_inverse_tx_8x8
extern er_av1_tile_decode_intra8x8_luma
extern er_av1_tile_decode_inter8x8_luma
extern er_av1_loop_filter_plane_8x8
extern er_av1_loop_filter_image_420
extern er_av1_refs_init
extern er_av1_refs_store_image
extern er_av1_refs_refresh
extern er_av1_refs_get_plane
extern er_av1_image_validate_420
extern er_av1_block_inter_predict_8x8
extern er_av1_block_predict_8x8
extern er_av1_block_reconstruct_add_8x8

SECTION .bss
passed: resq 1
failed: resq 1
symctx: resb AV1_SYMBOL_SIZE
block:  resb AV1_BLOCK_SIZE
cdfs:   resb AV1_BLOCK_CDFS_SIZE
pred:   resb 128
dst:    resb 128
coeffs: resb AV1_BLOCK_PIXELS_8X8 * 2
resid:  resb AV1_BLOCK_PIXELS_8X8 * 2
image:  resb AV1_IMAGE_SIZE
refs:   resb AV1_REF_STATE_SIZE
ref_plane: resb AV1_PLANE_SIZE
tile_y: resb 256
tile_u: resb 64
tile_v: resb 64
inter_y: resb 256
inter_u: resb 64
inter_v: resb 64

SECTION .data
syntax_zero: db 0x00, 0x00, 0x00, 0x80
syntax_one:  db 0xff, 0xff, 0xff, 0x80
coeff_zero:  times 96 db 0x00
coeff_one:   times 256 db 0xff
tile_zero:   times 512 db 0x00
tile_one:    times 512 db 0xff
left_ref:    db 10, 20, 30, 40, 50, 60, 70, 80
above_ref:   db 90, 100, 110, 120, 130, 140, 150, 160
coeff_identity:
    dw -20
    times 62 dw 0
    dw 200
coeff_dc:
    dw 10
    times 63 dw 0
coeff_dct_dc:
    dw 9
    times 63 dw 0
coeff_dct_ac:
    dw 0, 64
    times 62 dw 0

SECTION .text
global _start
_start:
    mov     rdi, cdfs
    call    er_av1_block_cdfs_init
    cmp     eax, AV1_BLOCK_CDFS_SIZE
    jne     .fail_cdfs_init
    test    edx, edx
    jnz     .fail_cdfs_init
    cmp     word [rel cdfs + AV1_BLOCK_CDFS_PARTITION], 19132
    jne     .fail_cdfs_init
    cmp     word [rel cdfs + AV1_BLOCK_CDFS_Y_MODE + 24], AV1_CDF_PROB_TOP
    jne     .fail_cdfs_init
    cmp     word [rel cdfs + AV1_BLOCK_CDFS_SKIP + 4], 0
    jne     .fail_cdfs_init
    cmp     word [rel cdfs + AV1_BLOCK_CDFS_COEFF_LEVEL + 6], AV1_CDF_PROB_TOP
    jne     .fail_cdfs_init
    TEST_PASS_NEXT .decode_zero
.fail_cdfs_init:
    TEST_FAIL_CASE

.decode_zero:
    mov     rdi, symctx
    mov     rsi, syntax_zero
    mov     edx, 4
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_decode_zero
    mov     rdi, symctx
    mov     rsi, block
    mov     rdx, cdfs
    mov     ecx, 1
    call    er_av1_block_decode_intra_symbols
    cmp     eax, AV1_BLOCK_SIZE
    jne     .fail_decode_zero
    test    edx, edx
    jnz     .fail_decode_zero
    cmp     byte [rel block + AV1_BLOCK_PARTITION], 0
    jne     .fail_decode_zero
    cmp     byte [rel block + AV1_BLOCK_Y_MODE], 0
    jne     .fail_decode_zero
    cmp     byte [rel block + AV1_BLOCK_SKIP], 0
    jne     .fail_decode_zero
    cmp     byte [rel block + AV1_BLOCK_TX_SIZE], 0
    jne     .fail_decode_zero
    TEST_PASS_NEXT .decode_one
.fail_decode_zero:
    TEST_FAIL_CASE

.decode_one:
    mov     rdi, cdfs
    call    er_av1_block_cdfs_init
    test    edx, edx
    jnz     .fail_decode_one
    mov     rdi, symctx
    mov     rsi, syntax_one
    mov     edx, 4
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_decode_one
    mov     rdi, symctx
    mov     rsi, block
    mov     rdx, cdfs
    xor     ecx, ecx
    call    er_av1_block_decode_intra_symbols
    cmp     eax, AV1_BLOCK_SIZE
    jne     .fail_decode_one
    test    edx, edx
    jnz     .fail_decode_one
    cmp     byte [rel block + AV1_BLOCK_PARTITION], 3
    jne     .fail_decode_one
    cmp     byte [rel block + AV1_BLOCK_Y_MODE], 12
    jne     .fail_decode_one
    cmp     byte [rel block + AV1_BLOCK_SKIP], 1
    jne     .fail_decode_one
    cmp     byte [rel block + AV1_BLOCK_TX_SIZE], 1
    jne     .fail_decode_one
    cmp     word [rel cdfs + AV1_BLOCK_CDFS_PARTITION + 8], 1
    jne     .fail_decode_one
    TEST_PASS_NEXT .invalid
.fail_decode_one:
    TEST_FAIL_CASE

.invalid:
    xor     edi, edi
    call    er_av1_block_cdfs_init
    test    eax, eax
    jnz     .fail_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_invalid
    mov     rdi, symctx
    xor     esi, esi
    mov     rdx, cdfs
    xor     ecx, ecx
    call    er_av1_block_decode_intra_symbols
    test    eax, eax
    jnz     .fail_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_invalid
    TEST_PASS_NEXT .predict_dc
.fail_invalid:
    TEST_FAIL_CASE

.predict_dc:
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, left_ref
    mov     rcx, above_ref
    mov     r8d, AV1_PRED_MODE_DC
    call    er_av1_block_predict_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_predict_dc
    test    edx, edx
    jnz     .fail_predict_dc
    cmp     byte [rel pred], 85
    jne     .fail_predict_dc
    cmp     byte [rel pred + 7], 85
    jne     .fail_predict_dc
    cmp     byte [rel pred + 56], 85
    jne     .fail_predict_dc
    cmp     byte [rel pred + 63], 85
    jne     .fail_predict_dc
    TEST_PASS_NEXT .predict_v
.fail_predict_dc:
    TEST_FAIL_CASE

.predict_v:
    mov     rdi, pred
    mov     esi, 10
    xor     edx, edx
    mov     rcx, above_ref
    mov     r8d, AV1_PRED_MODE_V
    call    er_av1_block_predict_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_predict_v
    test    edx, edx
    jnz     .fail_predict_v
    cmp     byte [rel pred], 90
    jne     .fail_predict_v
    cmp     byte [rel pred + 7], 160
    jne     .fail_predict_v
    cmp     byte [rel pred + 10], 90
    jne     .fail_predict_v
    cmp     byte [rel pred + 17], 160
    jne     .fail_predict_v
    TEST_PASS_NEXT .predict_h
.fail_predict_v:
    TEST_FAIL_CASE

.predict_h:
    mov     rdi, pred
    mov     esi, 10
    mov     rdx, left_ref
    xor     ecx, ecx
    mov     r8d, AV1_PRED_MODE_H
    call    er_av1_block_predict_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_predict_h
    test    edx, edx
    jnz     .fail_predict_h
    cmp     byte [rel pred], 10
    jne     .fail_predict_h
    cmp     byte [rel pred + 7], 10
    jne     .fail_predict_h
    cmp     byte [rel pred + 70], 80
    jne     .fail_predict_h
    cmp     byte [rel pred + 77], 80
    jne     .fail_predict_h
    TEST_PASS_NEXT .predict_paeth
.fail_predict_h:
    TEST_FAIL_CASE

.predict_paeth:
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, left_ref
    mov     rcx, above_ref
    mov     r8d, AV1_PRED_MODE_PAETH
    call    er_av1_block_predict_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_predict_paeth
    test    edx, edx
    jnz     .fail_predict_paeth
    cmp     byte [rel pred], 10
    jne     .fail_predict_paeth
    cmp     byte [rel pred + 7], 10
    jne     .fail_predict_paeth
    TEST_PASS_NEXT .predict_smooth
.fail_predict_paeth:
    TEST_FAIL_CASE

.predict_smooth:
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, left_ref
    mov     rcx, above_ref
    mov     r8d, AV1_PRED_MODE_SMOOTH
    call    er_av1_block_predict_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_predict_smooth
    test    edx, edx
    jnz     .fail_predict_smooth
    cmp     byte [rel pred], 50
    jne     .fail_predict_smooth
    cmp     byte [rel pred + 63], 120
    jne     .fail_predict_smooth
    TEST_PASS_NEXT .refs_refresh
.fail_predict_smooth:
    TEST_FAIL_CASE

.refs_refresh:
    mov     dword [rel image + AV1_IMAGE_WIDTH], 16
    mov     dword [rel image + AV1_IMAGE_HEIGHT], 16
    mov     qword [rel image + AV1_IMAGE_Y_PTR], tile_y
    mov     qword [rel image + AV1_IMAGE_U_PTR], tile_u
    mov     qword [rel image + AV1_IMAGE_V_PTR], tile_v
    mov     dword [rel image + AV1_IMAGE_Y_LEN], 256
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    mov     dword [rel image + AV1_IMAGE_V_LEN], 64
    mov     rdi, image
    call    er_av1_image_validate_420
    cmp     eax, 384
    jne     .fail_refs_refresh
    test    edx, edx
    jnz     .fail_refs_refresh
    mov     rdi, refs
    call    er_av1_refs_init
    cmp     eax, AV1_REF_STATE_SIZE
    jne     .fail_refs_refresh
    test    edx, edx
    jnz     .fail_refs_refresh
    mov     rdi, refs
    mov     esi, 0x05
    mov     rdx, image
    call    er_av1_refs_refresh
    cmp     eax, 2
    jne     .fail_refs_refresh
    test    edx, edx
    jnz     .fail_refs_refresh
    mov     rdi, refs
    mov     esi, 2
    mov     edx, AV1_PLANE_Y
    mov     rcx, ref_plane
    call    er_av1_refs_get_plane
    cmp     eax, AV1_PLANE_SIZE
    jne     .fail_refs_refresh
    test    edx, edx
    jnz     .fail_refs_refresh
    cmp     qword [rel ref_plane + AV1_PLANE_PTR], tile_y
    jne     .fail_refs_refresh
    cmp     dword [rel ref_plane + AV1_PLANE_WIDTH], 16
    jne     .fail_refs_refresh
    cmp     dword [rel ref_plane + AV1_PLANE_LEN], 256
    jne     .fail_refs_refresh
    mov     rdi, refs
    mov     esi, 1
    mov     edx, AV1_PLANE_Y
    mov     rcx, ref_plane
    call    er_av1_refs_get_plane
    test    eax, eax
    jnz     .fail_refs_refresh
    cmp     edx, ERROR_CORRUPT
    jne     .fail_refs_refresh
    TEST_PASS_NEXT .refs_store_chroma
.fail_refs_refresh:
    TEST_FAIL_CASE

.refs_store_chroma:
    mov     rdi, refs
    mov     esi, 6
    mov     rdx, image
    call    er_av1_refs_store_image
    cmp     eax, AV1_IMAGE_SIZE
    jne     .fail_refs_store_chroma
    test    edx, edx
    jnz     .fail_refs_store_chroma
    mov     rdi, refs
    mov     esi, 6
    mov     edx, AV1_PLANE_U
    mov     rcx, ref_plane
    call    er_av1_refs_get_plane
    cmp     eax, AV1_PLANE_SIZE
    jne     .fail_refs_store_chroma
    test    edx, edx
    jnz     .fail_refs_store_chroma
    cmp     qword [rel ref_plane + AV1_PLANE_PTR], tile_u
    jne     .fail_refs_store_chroma
    cmp     dword [rel ref_plane + AV1_PLANE_WIDTH], 8
    jne     .fail_refs_store_chroma
    cmp     dword [rel ref_plane + AV1_PLANE_HEIGHT], 8
    jne     .fail_refs_store_chroma
    cmp     dword [rel ref_plane + AV1_PLANE_LEN], 64
    jne     .fail_refs_store_chroma
    mov     dword [rel image + AV1_IMAGE_U_LEN], 63
    mov     rdi, refs
    mov     esi, 7
    mov     rdx, image
    call    er_av1_refs_store_image
    test    eax, eax
    jnz     .fail_refs_store_chroma
    cmp     edx, ERROR_CORRUPT
    jne     .fail_refs_store_chroma
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    TEST_PASS_NEXT .inter_predict
.fail_refs_store_chroma:
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    TEST_FAIL_CASE

.inter_predict:
    mov     byte [rel tile_y + 35], 33
    mov     byte [rel tile_y + 154], 154
    mov     qword [rel ref_plane + AV1_PLANE_PTR], tile_y
    mov     dword [rel ref_plane + AV1_PLANE_WIDTH], 16
    mov     dword [rel ref_plane + AV1_PLANE_HEIGHT], 16
    mov     dword [rel ref_plane + AV1_PLANE_LEN], 256
    mov     rdi, pred
    mov     esi, 10
    mov     rdx, ref_plane
    mov     ecx, 2
    mov     r8d, 3
    mov     r9d, 0xffff0001
    call    er_av1_block_inter_predict_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_inter_predict
    test    edx, edx
    jnz     .fail_inter_predict
    cmp     byte [rel pred], 33
    jne     .fail_inter_predict
    cmp     byte [rel pred + 77], 154
    jne     .fail_inter_predict
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, ref_plane
    mov     ecx, 9
    mov     r8d, 8
    xor     r9d, r9d
    call    er_av1_block_inter_predict_8x8
    test    eax, eax
    jnz     .fail_inter_predict
    cmp     edx, ERROR_CORRUPT
    jne     .fail_inter_predict
    TEST_PASS_NEXT .mv_decode
.fail_inter_predict:
    TEST_FAIL_CASE

.mv_decode:
    mov     rdi, symctx
    mov     rsi, tile_zero
    mov     edx, 16
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_mv_decode
    mov     rdi, symctx
    call    er_av1_block_decode_mv
    test    eax, eax
    jnz     .fail_mv_decode
    test    edx, edx
    jnz     .fail_mv_decode
    mov     rdi, symctx
    mov     rsi, tile_one
    mov     edx, 16
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_mv_decode
    mov     rdi, symctx
    call    er_av1_block_decode_mv
    test    edx, edx
    jnz     .fail_mv_decode
    cmp     eax, 0xfff9fff9
    jne     .fail_mv_decode
    xor     edi, edi
    call    er_av1_block_decode_mv
    test    eax, eax
    jnz     .fail_mv_decode
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_mv_decode
    TEST_PASS_NEXT .reconstruct_identity
.fail_mv_decode:
    TEST_FAIL_CASE

.reconstruct_identity:
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, left_ref
    mov     rcx, above_ref
    mov     r8d, AV1_PRED_MODE_DC
    call    er_av1_block_predict_8x8
    test    edx, edx
    jnz     .fail_reconstruct_identity
    mov     rdi, dst
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, pred
    mov     ecx, AV1_BLOCK_DIM_8
    mov     r8, coeff_identity
    xor     r9d, r9d
    call    er_av1_block_reconstruct_add_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_reconstruct_identity
    test    edx, edx
    jnz     .fail_reconstruct_identity
    cmp     byte [rel dst], 65
    jne     .fail_reconstruct_identity
    cmp     byte [rel dst + 1], 85
    jne     .fail_reconstruct_identity
    cmp     byte [rel dst + 63], AV1_PIXEL_MAX_8
    jne     .fail_reconstruct_identity
    TEST_PASS_NEXT .reconstruct_dc
.fail_reconstruct_identity:
    TEST_FAIL_CASE

.reconstruct_dc:
    mov     rdi, resid
    mov     rsi, coeff_dc
    mov     edx, AV1_TX_TYPE_DC_ONLY
    call    er_av1_block_inverse_tx_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_reconstruct_dc
    test    edx, edx
    jnz     .fail_reconstruct_dc
    mov     rdi, dst
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, pred
    mov     ecx, AV1_BLOCK_DIM_8
    mov     r8, resid
    xor     r9d, r9d
    call    er_av1_block_reconstruct_add_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_reconstruct_dc
    test    edx, edx
    jnz     .fail_reconstruct_dc
    cmp     byte [rel dst], 95
    jne     .fail_reconstruct_dc
    cmp     byte [rel dst + 63], 95
    jne     .fail_reconstruct_dc
    TEST_PASS_NEXT .predict_invalid
.fail_reconstruct_dc:
    TEST_FAIL_CASE

.predict_invalid:
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    xor     edx, edx
    xor     ecx, ecx
    mov     r8d, AV1_PRED_MODE_V
    call    er_av1_block_predict_8x8
    test    eax, eax
    jnz     .fail_predict_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_predict_invalid
    mov     rdi, dst
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, pred
    mov     ecx, AV1_BLOCK_DIM_8
    mov     r8, coeff_dc
    xor     r9d, r9d
    call    er_av1_block_reconstruct_add_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_predict_invalid
    test    edx, edx
    jnz     .fail_predict_invalid
    TEST_PASS_NEXT .coeff_zero
.fail_predict_invalid:
    TEST_FAIL_CASE

.coeff_zero:
    mov     rdi, cdfs
    call    er_av1_block_cdfs_init
    test    edx, edx
    jnz     .fail_coeff_zero
    mov     rdi, symctx
    mov     rsi, coeff_zero
    mov     edx, 96
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_coeff_zero
    mov     rdi, symctx
    mov     rsi, coeffs
    mov     rdx, cdfs
    mov     ecx, 1
    call    er_av1_block_decode_coeffs_8x8
    test    eax, eax
    jnz     .fail_coeff_zero
    test    edx, edx
    jnz     .fail_coeff_zero
    cmp     word [rel coeffs], 0
    jne     .fail_coeff_zero
    cmp     word [rel coeffs + 126], 0
    jne     .fail_coeff_zero
    TEST_PASS_NEXT .coeff_one
.fail_coeff_zero:
    TEST_FAIL_CASE

.coeff_one:
    mov     rdi, cdfs
    call    er_av1_block_cdfs_init
    test    edx, edx
    jnz     .fail_coeff_one
    mov     rdi, symctx
    mov     rsi, coeff_one
    mov     edx, 256
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_coeff_one
    mov     rdi, symctx
    mov     rsi, coeffs
    mov     rdx, cdfs
    mov     ecx, 1
    call    er_av1_block_decode_coeffs_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_coeff_one
    test    edx, edx
    jnz     .fail_coeff_one
    cmp     word [rel coeffs], -4
    jne     .fail_coeff_one
    cmp     word [rel coeffs + 126], -4
    jne     .fail_coeff_one
    TEST_PASS_NEXT .dequant
.fail_coeff_one:
    TEST_FAIL_CASE

.dequant:
    mov     rdi, resid
    mov     rsi, coeffs
    mov     edx, 3
    call    er_av1_block_dequant_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_dequant
    test    edx, edx
    jnz     .fail_dequant
    cmp     word [rel resid], -12
    jne     .fail_dequant
    cmp     word [rel resid + 126], -12
    jne     .fail_dequant
    mov     word [rel coeffs], 200
    mov     rdi, resid
    mov     rsi, coeffs
    mov     edx, AV1_QUANT_STEP_MAX
    call    er_av1_block_dequant_8x8
    test    edx, edx
    jnz     .fail_dequant
    cmp     word [rel resid], AV1_COEFF_MAX_16
    jne     .fail_dequant
    TEST_PASS_NEXT .coeff_reconstruct
.fail_dequant:
    TEST_FAIL_CASE

.coeff_reconstruct:
    mov     rdi, pred
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, left_ref
    mov     rcx, above_ref
    mov     r8d, AV1_PRED_MODE_DC
    call    er_av1_block_predict_8x8
    test    edx, edx
    jnz     .fail_coeff_reconstruct
    mov     word [rel resid], -12
    mov     word [rel resid + 2], 10
    mov     rdi, dst
    mov     esi, AV1_BLOCK_DIM_8
    mov     rdx, pred
    mov     ecx, AV1_BLOCK_DIM_8
    mov     r8, resid
    xor     r9d, r9d
    call    er_av1_block_reconstruct_add_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_coeff_reconstruct
    test    edx, edx
    jnz     .fail_coeff_reconstruct
    cmp     byte [rel dst], 73
    jne     .fail_coeff_reconstruct
    cmp     byte [rel dst + 1], 95
    jne     .fail_coeff_reconstruct
    TEST_PASS_NEXT .inverse_idtx
.fail_coeff_reconstruct:
    TEST_FAIL_CASE

.inverse_idtx:
    mov     word [rel coeffs], -3
    mov     word [rel coeffs + 2], 7
    mov     word [rel coeffs + 126], 11
    mov     rdi, resid
    mov     rsi, coeffs
    mov     edx, AV1_TX_TYPE_IDTX
    call    er_av1_block_inverse_tx_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_inverse_idtx
    test    edx, edx
    jnz     .fail_inverse_idtx
    cmp     word [rel resid], -3
    jne     .fail_inverse_idtx
    cmp     word [rel resid + 2], 7
    jne     .fail_inverse_idtx
    cmp     word [rel resid + 126], 11
    jne     .fail_inverse_idtx
    TEST_PASS_NEXT .inverse_dct_dc
.fail_inverse_idtx:
    TEST_FAIL_CASE

.inverse_dct_dc:
    mov     rdi, resid
    mov     rsi, coeff_dct_dc
    mov     edx, AV1_TX_TYPE_DCT_DCT
    call    er_av1_block_inverse_tx_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_inverse_dct_dc
    test    edx, edx
    jnz     .fail_inverse_dct_dc
    cmp     word [rel resid], 9
    jne     .fail_inverse_dct_dc
    cmp     word [rel resid + 126], 9
    jne     .fail_inverse_dct_dc
    TEST_PASS_NEXT .inverse_dct_ac
.fail_inverse_dct_dc:
    TEST_FAIL_CASE

.inverse_dct_ac:
    mov     rdi, resid
    mov     rsi, coeff_dct_ac
    mov     edx, AV1_TX_TYPE_DCT_DCT
    call    er_av1_block_inverse_tx_8x8
    cmp     eax, AV1_BLOCK_PIXELS_8X8
    jne     .fail_inverse_dct_ac
    test    edx, edx
    jnz     .fail_inverse_dct_ac
    cmp     word [rel resid], 89
    jne     .fail_inverse_dct_ac
    cmp     word [rel resid + 14], -89
    jne     .fail_inverse_dct_ac
    TEST_PASS_NEXT .coeff_invalid
.fail_inverse_dct_ac:
    TEST_FAIL_CASE

.coeff_invalid:
    mov     rdi, coeffs
    mov     rsi, coeffs
    xor     edx, edx
    call    er_av1_block_dequant_8x8
    test    eax, eax
    jnz     .fail_coeff_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_coeff_invalid
    mov     rdi, symctx
    xor     esi, esi
    mov     rdx, cdfs
    xor     ecx, ecx
    call    er_av1_block_decode_coeffs_8x8
    test    eax, eax
    jnz     .fail_coeff_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_coeff_invalid
    mov     rdi, resid
    mov     rsi, coeffs
    mov     edx, AV1_TX_TYPE_MAX + 1
    call    er_av1_block_inverse_tx_8x8
    test    eax, eax
    jnz     .fail_coeff_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_coeff_invalid
    TEST_PASS_NEXT .tile_walk_zero
.fail_coeff_invalid:
    TEST_FAIL_CASE

.tile_walk_zero:
    mov     rdi, cdfs
    call    er_av1_block_cdfs_init
    test    edx, edx
    jnz     .fail_tile_walk_zero
    mov     dword [rel image + AV1_IMAGE_WIDTH], 16
    mov     dword [rel image + AV1_IMAGE_HEIGHT], 16
    mov     qword [rel image + AV1_IMAGE_Y_PTR], tile_y
    mov     qword [rel image + AV1_IMAGE_U_PTR], tile_u
    mov     qword [rel image + AV1_IMAGE_V_PTR], tile_v
    mov     dword [rel image + AV1_IMAGE_Y_LEN], 256
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    mov     dword [rel image + AV1_IMAGE_V_LEN], 64
    mov     rdi, symctx
    mov     rsi, tile_zero
    mov     edx, 512
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_tile_walk_zero
    mov     rdi, symctx
    mov     rsi, image
    mov     rdx, cdfs
    mov     ecx, 1
    mov     r8d, 1
    call    er_av1_tile_decode_intra8x8_luma
    cmp     eax, 6
    jne     .fail_tile_walk_zero
    test    edx, edx
    jnz     .fail_tile_walk_zero
    cmp     byte [rel tile_y], AV1_PIXEL_MID_8
    jne     .fail_tile_walk_zero
    cmp     byte [rel tile_y + 7], AV1_PIXEL_MID_8
    jne     .fail_tile_walk_zero
    cmp     byte [rel tile_y + 8], AV1_PIXEL_MID_8
    jne     .fail_tile_walk_zero
    cmp     byte [rel tile_y + 255], AV1_PIXEL_MID_8
    jne     .fail_tile_walk_zero
    cmp     byte [rel tile_u], AV1_PIXEL_MID_8
    jne     .fail_tile_walk_zero
    cmp     byte [rel tile_v + 63], AV1_PIXEL_MID_8
    jne     .fail_tile_walk_zero
    TEST_PASS_NEXT .tile_walk_inter
.fail_tile_walk_zero:
    TEST_FAIL_CASE

.tile_walk_inter:
    mov     byte [rel tile_y], 11
    mov     byte [rel tile_y + 63], 63
    mov     byte [rel tile_y + 128], 128
    mov     byte [rel tile_y + 255], 255
    mov     byte [rel tile_u], 21
    mov     byte [rel tile_u + 63], 63
    mov     byte [rel tile_v], 31
    mov     byte [rel tile_v + 63], 127
    mov     dword [rel image + AV1_IMAGE_WIDTH], 16
    mov     dword [rel image + AV1_IMAGE_HEIGHT], 16
    mov     qword [rel image + AV1_IMAGE_Y_PTR], tile_y
    mov     qword [rel image + AV1_IMAGE_U_PTR], tile_u
    mov     qword [rel image + AV1_IMAGE_V_PTR], tile_v
    mov     dword [rel image + AV1_IMAGE_Y_LEN], 256
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    mov     dword [rel image + AV1_IMAGE_V_LEN], 64
    mov     rdi, refs
    xor     esi, esi
    mov     rdx, image
    call    er_av1_refs_store_image
    test    edx, edx
    jnz     .fail_tile_walk_inter
    mov     dword [rel image + AV1_IMAGE_WIDTH], 16
    mov     dword [rel image + AV1_IMAGE_HEIGHT], 16
    mov     qword [rel image + AV1_IMAGE_Y_PTR], inter_y
    mov     qword [rel image + AV1_IMAGE_U_PTR], inter_u
    mov     qword [rel image + AV1_IMAGE_V_PTR], inter_v
    mov     dword [rel image + AV1_IMAGE_Y_LEN], 256
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    mov     dword [rel image + AV1_IMAGE_V_LEN], 64
    mov     rdi, symctx
    mov     rsi, tile_zero
    mov     edx, 512
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_tile_walk_inter
    mov     rdi, symctx
    mov     rsi, image
    mov     rdx, cdfs
    mov     rcx, refs
    mov     r8d, 1
    xor     r9d, r9d
    call    er_av1_tile_decode_inter8x8_luma
    cmp     eax, 6
    jne     .fail_tile_walk_inter
    test    edx, edx
    jnz     .fail_tile_walk_inter
    cmp     byte [rel inter_y], 11
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_y + 63], 63
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_y + 128], 128
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_y + 255], 255
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_u], 21
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_u + 63], 63
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_v], 31
    jne     .fail_tile_walk_inter
    cmp     byte [rel inter_v + 63], 127
    jne     .fail_tile_walk_inter
    mov     dword [rel image + AV1_IMAGE_WIDTH], 16
    mov     dword [rel image + AV1_IMAGE_HEIGHT], 16
    mov     qword [rel image + AV1_IMAGE_Y_PTR], tile_y
    mov     qword [rel image + AV1_IMAGE_U_PTR], tile_u
    mov     qword [rel image + AV1_IMAGE_V_PTR], tile_v
    mov     dword [rel image + AV1_IMAGE_Y_LEN], 256
    mov     dword [rel image + AV1_IMAGE_U_LEN], 64
    mov     dword [rel image + AV1_IMAGE_V_LEN], 64
    mov     rdi, symctx
    mov     rsi, image
    mov     rdx, cdfs
    mov     rcx, refs
    mov     r8d, 1
    mov     r9d, 1
    call    er_av1_tile_decode_inter8x8_luma
    test    eax, eax
    jnz     .fail_tile_walk_inter
    cmp     edx, ERROR_CORRUPT
    jne     .fail_tile_walk_inter
    mov     rdi, symctx
    mov     rsi, tile_one
    mov     edx, 512
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_tile_walk_inter
    mov     rdi, symctx
    mov     rsi, image
    mov     rdx, cdfs
    mov     rcx, refs
    mov     r8d, 1
    xor     r9d, r9d
    call    er_av1_tile_decode_inter8x8_luma
    test    eax, eax
    jnz     .fail_tile_walk_inter
    cmp     edx, ERROR_CORRUPT
    jne     .fail_tile_walk_inter
    TEST_PASS_NEXT .loop_filter_plane
.fail_tile_walk_inter:
    TEST_FAIL_CASE

.loop_filter_plane:
    mov     byte [rel tile_y + 7], 10
    mov     byte [rel tile_y + 8], 20
    mov     byte [rel tile_y + 127], 30
    mov     byte [rel tile_y + 128], 40
    mov     rdi, tile_y
    mov     esi, 16
    mov     edx, 16
    xor     ecx, ecx
    call    er_av1_loop_filter_plane_8x8
    test    eax, eax
    jnz     .fail_loop_filter_plane
    test    edx, edx
    jnz     .fail_loop_filter_plane
    cmp     byte [rel tile_y + 7], 10
    jne     .fail_loop_filter_plane
    mov     rdi, tile_y
    mov     esi, 16
    mov     edx, 16
    mov     ecx, AV1_LOOP_FILTER_STRENGTH_MAX
    call    er_av1_loop_filter_plane_8x8
    cmp     eax, 32
    jne     .fail_loop_filter_plane
    test    edx, edx
    jnz     .fail_loop_filter_plane
    cmp     byte [rel tile_y + 7], 15
    jne     .fail_loop_filter_plane
    cmp     byte [rel tile_y + 8], 15
    jne     .fail_loop_filter_plane
    TEST_PASS_NEXT .loop_filter_image
.fail_loop_filter_plane:
    TEST_FAIL_CASE

.loop_filter_image:
    mov     byte [rel tile_y + 7], 0
    mov     byte [rel tile_y + 8], 100
    mov     rdi, image
    mov     esi, AV1_LOOP_FILTER_STRENGTH_MAX
    call    er_av1_loop_filter_image_420
    cmp     eax, 32
    jne     .fail_loop_filter_image
    test    edx, edx
    jnz     .fail_loop_filter_image
    cmp     byte [rel tile_y + 7], 50
    jne     .fail_loop_filter_image
    cmp     byte [rel tile_y + 8], 50
    jne     .fail_loop_filter_image
    mov     rdi, tile_y
    mov     esi, 10
    mov     edx, 16
    mov     ecx, AV1_LOOP_FILTER_STRENGTH_MAX
    call    er_av1_loop_filter_plane_8x8
    test    eax, eax
    jnz     .fail_loop_filter_image
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_loop_filter_image
    TEST_PASS_NEXT .tile_walk_invalid
.fail_loop_filter_image:
    TEST_FAIL_CASE

.tile_walk_invalid:
    mov     dword [rel image + AV1_IMAGE_WIDTH], 10
    mov     dword [rel image + AV1_IMAGE_HEIGHT], 16
    mov     rdi, symctx
    mov     rsi, image
    mov     rdx, cdfs
    mov     ecx, 1
    xor     r8d, r8d
    call    er_av1_tile_decode_intra8x8_luma
    test    eax, eax
    jnz     .fail_tile_walk_invalid
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_tile_walk_invalid
    xor     edi, edi
    mov     rsi, image
    mov     rdx, cdfs
    mov     ecx, 1
    xor     r8d, r8d
    call    er_av1_tile_decode_intra8x8_luma
    test    eax, eax
    jnz     .fail_tile_walk_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_tile_walk_invalid
    TEST_PASS_NEXT .done
.fail_tile_walk_invalid:
    TEST_FAIL_CASE

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
