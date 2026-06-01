; EdgeRun AV1 block syntax self-hosted test runner.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_symbol_init
extern er_av1_block_cdfs_init
extern er_av1_block_decode_intra_symbols
extern er_av1_block_decode_coeffs_8x8
extern er_av1_block_dequant_8x8
extern er_av1_block_inverse_tx_8x8
extern er_av1_tile_decode_intra8x8_luma
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
tile_y: resb 256
tile_u: resb 64
tile_v: resb 64

SECTION .data
syntax_zero: db 0x00, 0x00, 0x00, 0x80
syntax_one:  db 0xff, 0xff, 0xff, 0x80
coeff_zero:  times 96 db 0x00
coeff_one:   times 256 db 0xff
tile_zero:   times 512 db 0x00
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
    inc     qword [rel passed]
    jmp     .decode_zero
.fail_cdfs_init:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .decode_one
.fail_decode_zero:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .invalid
.fail_decode_one:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .predict_dc
.fail_invalid:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .predict_v
.fail_predict_dc:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .predict_h
.fail_predict_v:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .reconstruct_identity
.fail_predict_h:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .reconstruct_dc
.fail_reconstruct_identity:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .predict_invalid
.fail_reconstruct_dc:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .coeff_zero
.fail_predict_invalid:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .coeff_one
.fail_coeff_zero:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .dequant
.fail_coeff_one:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .coeff_reconstruct
.fail_dequant:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .inverse_idtx
.fail_coeff_reconstruct:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .inverse_dct_dc
.fail_inverse_idtx:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .inverse_dct_ac
.fail_inverse_dct_dc:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .coeff_invalid
.fail_inverse_dct_ac:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .tile_walk_zero
.fail_coeff_invalid:
    inc     qword [rel failed]

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
    cmp     eax, 4
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
    inc     qword [rel passed]
    jmp     .tile_walk_invalid
.fail_tile_walk_zero:
    inc     qword [rel failed]

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
    inc     qword [rel passed]
    jmp     .done
.fail_tile_walk_invalid:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
