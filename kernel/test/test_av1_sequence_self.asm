; EdgeRun AV1 sequence header self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"
%include "test/test_macros.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written
extern er_av1_cdf_symbol
extern er_av1_symbol_init
extern er_av1_symbol_write_init
extern er_av1_symbol_write_symbol
extern er_av1_symbol_write_bool
extern er_av1_symbol_write_literal
extern er_av1_symbol_write_finish
extern er_av1_symbol_read_symbol
extern er_av1_symbol_read_bool
extern er_av1_symbol_read_literal
extern er_av1_symbol_read_ns
extern er_av1_symbol_decode_subexp
extern er_av1_symbol_exit
extern er_av1_sequence_decode
extern er_av1_sequence_encode
extern er_av1_sequence_decode_reduced_still
extern er_av1_sequence_encode_reduced_still

TEST_BSS_PASSED_FAILED
bitctx: resb AV1_BITS_SIZE
symctx: resb AV1_SYMBOL_SIZE
seq:    resb AV1_SEQ_SIZE
outbuf: resb 32

SECTION .data
bit_src:     db 0xb1
sym_zero:    db 0x00
sym_one:     db 0xff
sym_trail_good: db 0x80
sym_trail_bad_padding: db 0xc0
bad_profile: db 0x20
short_seq:   db 0x18
cdf4:        dw 8192, 16384, 24576, AV1_CDF_PROB_TOP
cdf4_rt_w:   dw 8192, 16384, 24576, AV1_CDF_PROB_TOP
cdf4_rt_r:   dw 8192, 16384, 24576, AV1_CDF_PROB_TOP
cdf_bad_eq:  dw 8192, 8192, 24576, AV1_CDF_PROB_TOP
cdf_bad_top: dw 8192, AV1_CDF_PROB_TOP, 24576, AV1_CDF_PROB_TOP
cdf_bad_end: dw 8192, 16384, 24576, 32767
cdf_update_zero: dw AV1_CDF_BOOL_SPLIT, AV1_CDF_PROB_TOP, 0
cdf_update_one:  dw AV1_CDF_BOOL_SPLIT, AV1_CDF_PROB_TOP, 0

SECTION .text
global _start
_start:
    mov     rdi, bitctx
    mov     rsi, bit_src
    mov     edx, 1
    call    er_av1_bits_read_init
    test    edx, edx
    jnz     .fail_bit_read
    mov     rdi, bitctx
    mov     esi, 3
    call    er_av1_bits_read
    cmp     eax, 5
    jne     .fail_bit_read
    test    edx, edx
    jnz     .fail_bit_read
    mov     rdi, bitctx
    mov     esi, 5
    call    er_av1_bits_read
    cmp     eax, 17
    jne     .fail_bit_read
    test    edx, edx
    jnz     .fail_bit_read
    inc     qword [rel passed]
    jmp     .bit_write
.fail_bit_read:
    inc     qword [rel failed]

.bit_write:
    mov     byte [rel outbuf], 0
    mov     rdi, bitctx
    mov     rsi, outbuf
    mov     edx, 1
    call    er_av1_bits_write_init
    test    edx, edx
    jnz     .fail_bit_write
    mov     rdi, bitctx
    mov     esi, 5
    mov     edx, 3
    call    er_av1_bits_write
    test    edx, edx
    jnz     .fail_bit_write
    mov     rdi, bitctx
    mov     esi, 17
    mov     edx, 5
    call    er_av1_bits_write
    test    edx, edx
    jnz     .fail_bit_write
    cmp     byte [rel outbuf], 0xb1
    jne     .fail_bit_write
    mov     rdi, bitctx
    call    er_av1_bits_bytes_written
    cmp     eax, 1
    jne     .fail_bit_write
    test    edx, edx
    jnz     .fail_bit_write
    inc     qword [rel passed]
    jmp     .cdf_decode
.fail_bit_write:
    inc     qword [rel failed]

.cdf_decode:
    mov     rdi, cdf4
    mov     esi, 4
    xor     edx, edx
    call    er_av1_cdf_symbol
    test    edx, edx
    jnz     .fail_cdf_decode
    test    eax, eax
    jnz     .fail_cdf_decode
    mov     rdi, cdf4
    mov     esi, 4
    mov     edx, 8191
    call    er_av1_cdf_symbol
    test    edx, edx
    jnz     .fail_cdf_decode
    test    eax, eax
    jnz     .fail_cdf_decode
    mov     rdi, cdf4
    mov     esi, 4
    mov     edx, 8192
    call    er_av1_cdf_symbol
    test    edx, edx
    jnz     .fail_cdf_decode
    cmp     eax, 1
    jne     .fail_cdf_decode
    mov     rdi, cdf4
    mov     esi, 4
    mov     edx, 16384
    call    er_av1_cdf_symbol
    test    edx, edx
    jnz     .fail_cdf_decode
    cmp     eax, 2
    jne     .fail_cdf_decode
    mov     rdi, cdf4
    mov     esi, 4
    mov     edx, 24576
    call    er_av1_cdf_symbol
    test    edx, edx
    jnz     .fail_cdf_decode
    cmp     eax, 3
    jne     .fail_cdf_decode
    mov     rdi, cdf4
    mov     esi, 4
    mov     edx, 32767
    call    er_av1_cdf_symbol
    test    edx, edx
    jnz     .fail_cdf_decode
    cmp     eax, 3
    jne     .fail_cdf_decode
    inc     qword [rel passed]
    jmp     .cdf_invalid
.fail_cdf_decode:
    inc     qword [rel failed]

.cdf_invalid:
    mov     rdi, cdf4
    mov     esi, 1
    xor     edx, edx
    call    er_av1_cdf_symbol
    test    eax, eax
    jnz     .fail_cdf_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_cdf_invalid
    mov     rdi, cdf4
    mov     esi, 4
    mov     edx, AV1_CDF_PROB_TOP
    call    er_av1_cdf_symbol
    test    eax, eax
    jnz     .fail_cdf_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_cdf_invalid
    inc     qword [rel passed]
    jmp     .cdf_corrupt
.fail_cdf_invalid:
    inc     qword [rel failed]

.cdf_corrupt:
    mov     rdi, cdf_bad_eq
    mov     esi, 4
    mov     edx, 9000
    call    er_av1_cdf_symbol
    test    eax, eax
    jnz     .fail_cdf_corrupt
    cmp     edx, ERROR_CORRUPT
    jne     .fail_cdf_corrupt
    mov     rdi, cdf_bad_top
    mov     esi, 4
    xor     edx, edx
    call    er_av1_cdf_symbol
    test    eax, eax
    jnz     .fail_cdf_corrupt
    cmp     edx, ERROR_CORRUPT
    jne     .fail_cdf_corrupt
    mov     rdi, cdf_bad_end
    mov     esi, 4
    xor     edx, edx
    call    er_av1_cdf_symbol
    test    eax, eax
    jnz     .fail_cdf_corrupt
    cmp     edx, ERROR_CORRUPT
    jne     .fail_cdf_corrupt
    inc     qword [rel passed]
    jmp     .symbol_read_zero
.fail_cdf_corrupt:
    inc     qword [rel failed]

.symbol_read_zero:
    mov     rdi, symctx
    mov     rsi, sym_zero
    mov     edx, 1
    call    er_av1_symbol_init
    cmp     eax, 8
    jne     .fail_symbol_read_zero
    test    edx, edx
    jnz     .fail_symbol_read_zero
    cmp     dword [rel symctx + AV1_SYMBOL_VALUE], AV1_CDF_PROB_TOP - 1
    jne     .fail_symbol_read_zero
    cmp     dword [rel symctx + AV1_SYMBOL_RANGE], AV1_CDF_PROB_TOP
    jne     .fail_symbol_read_zero
    cmp     dword [rel symctx + AV1_SYMBOL_MAX_BITS], -7
    jne     .fail_symbol_read_zero
    mov     rdi, symctx
    mov     rsi, cdf_update_zero
    mov     edx, 2
    xor     ecx, ecx
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .fail_symbol_read_zero
    test    eax, eax
    jnz     .fail_symbol_read_zero
    cmp     word [rel cdf_update_zero], 17408
    jne     .fail_symbol_read_zero
    cmp     word [rel cdf_update_zero + 4], 1
    jne     .fail_symbol_read_zero
    inc     qword [rel passed]
    jmp     .symbol_read_one
.fail_symbol_read_zero:
    inc     qword [rel failed]

.symbol_read_one:
    mov     rdi, symctx
    mov     rsi, sym_one
    mov     edx, 1
    call    er_av1_symbol_init
    cmp     eax, 8
    jne     .fail_symbol_read_one
    test    edx, edx
    jnz     .fail_symbol_read_one
    mov     rdi, symctx
    mov     rsi, cdf_update_one
    mov     edx, 2
    xor     ecx, ecx
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .fail_symbol_read_one
    cmp     eax, 1
    jne     .fail_symbol_read_one
    cmp     word [rel cdf_update_one], 15360
    jne     .fail_symbol_read_one
    cmp     word [rel cdf_update_one + 4], 1
    jne     .fail_symbol_read_one
    inc     qword [rel passed]
    jmp     .symbol_bool_literal
.fail_symbol_read_one:
    inc     qword [rel failed]

.symbol_bool_literal:
    mov     rdi, symctx
    mov     rsi, sym_one
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_bool_literal
    mov     rdi, symctx
    call    er_av1_symbol_read_bool
    test    edx, edx
    jnz     .fail_symbol_bool_literal
    cmp     eax, 1
    jne     .fail_symbol_bool_literal
    mov     rdi, symctx
    mov     rsi, sym_zero
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_bool_literal
    mov     rdi, symctx
    mov     esi, 3
    call    er_av1_symbol_read_literal
    test    edx, edx
    jnz     .fail_symbol_bool_literal
    test    eax, eax
    jnz     .fail_symbol_bool_literal
    inc     qword [rel passed]
    jmp     .symbol_write_roundtrip
.fail_symbol_bool_literal:
    inc     qword [rel failed]

.symbol_write_roundtrip:
    mov     qword [rel outbuf], 0
    mov     qword [rel outbuf + 8], 0
    mov     qword [rel outbuf + 16], 0
    mov     qword [rel outbuf + 24], 0
    mov     word [rel cdf4_rt_w], 8192
    mov     word [rel cdf4_rt_w + 2], 16384
    mov     word [rel cdf4_rt_w + 4], 24576
    mov     word [rel cdf4_rt_w + 6], AV1_CDF_PROB_TOP
    mov     word [rel cdf4_rt_r], 8192
    mov     word [rel cdf4_rt_r + 2], 16384
    mov     word [rel cdf4_rt_r + 4], 24576
    mov     word [rel cdf4_rt_r + 6], AV1_CDF_PROB_TOP
    mov     rdi, symctx
    mov     rsi, outbuf
    mov     edx, 32
    call    er_av1_symbol_write_init
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    mov     rdi, symctx
    mov     rsi, cdf4_rt_w
    mov     edx, 4
    xor     ecx, ecx
    mov     r8d, 1
    call    er_av1_symbol_write_symbol
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    mov     rdi, symctx
    mov     rsi, cdf4_rt_w
    mov     edx, 4
    mov     ecx, 1
    mov     r8d, 1
    call    er_av1_symbol_write_symbol
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    mov     rdi, symctx
    call    er_av1_symbol_write_finish
    test    eax, eax
    jz      .fail_symbol_write_roundtrip
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    mov     r9d, eax
    mov     rdi, symctx
    mov     rsi, outbuf
    mov     edx, r9d
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    mov     rdi, symctx
    mov     rsi, cdf4_rt_r
    mov     edx, 4
    mov     ecx, 1
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    test    eax, eax
    jnz     .fail_symbol_write_roundtrip
    mov     rdi, symctx
    mov     rsi, cdf4_rt_r
    mov     edx, 4
    mov     ecx, 1
    call    er_av1_symbol_read_symbol
    test    edx, edx
    jnz     .fail_symbol_write_roundtrip
    cmp     eax, 1
    jne     .fail_symbol_write_roundtrip
    inc     qword [rel passed]
    jmp     .symbol_write_literal_roundtrip
.fail_symbol_write_roundtrip:
    inc     qword [rel failed]

.symbol_write_literal_roundtrip:
    mov     qword [rel outbuf], 0
    mov     qword [rel outbuf + 8], 0
    mov     rdi, symctx
    mov     rsi, outbuf
    mov     edx, 32
    call    er_av1_symbol_write_init
    test    edx, edx
    jnz     .fail_symbol_write_literal_roundtrip
    mov     rdi, symctx
    mov     esi, 7
    mov     edx, 3
    call    er_av1_symbol_write_literal
    cmp     eax, 3
    jne     .fail_symbol_write_literal_roundtrip
    test    edx, edx
    jnz     .fail_symbol_write_literal_roundtrip
    mov     rdi, symctx
    call    er_av1_symbol_write_finish
    test    eax, eax
    jz      .fail_symbol_write_literal_roundtrip
    test    edx, edx
    jnz     .fail_symbol_write_literal_roundtrip
    mov     r9d, eax
    mov     rdi, symctx
    mov     rsi, outbuf
    mov     edx, r9d
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_write_literal_roundtrip
    mov     rdi, symctx
    mov     esi, 3
    call    er_av1_symbol_read_literal
    test    edx, edx
    jnz     .fail_symbol_write_literal_roundtrip
    cmp     eax, 7
    jne     .fail_symbol_write_literal_roundtrip
    inc     qword [rel passed]
    jmp     .symbol_ns_zero
.fail_symbol_write_literal_roundtrip:
    inc     qword [rel failed]

.symbol_ns_zero:
    mov     rdi, symctx
    mov     rsi, sym_zero
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_ns_zero
    mov     rdi, symctx
    mov     esi, 5
    call    er_av1_symbol_read_ns
    test    edx, edx
    jnz     .fail_symbol_ns_zero
    test    eax, eax
    jnz     .fail_symbol_ns_zero
    inc     qword [rel passed]
    jmp     .symbol_ns_one
.fail_symbol_ns_zero:
    inc     qword [rel failed]

.symbol_ns_one:
    mov     rdi, symctx
    mov     rsi, sym_one
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_ns_one
    mov     rdi, symctx
    mov     esi, 1
    call    er_av1_symbol_read_ns
    test    edx, edx
    jnz     .fail_symbol_ns_one
    test    eax, eax
    jnz     .fail_symbol_ns_one
    inc     qword [rel passed]
    jmp     .symbol_ns_invalid
.fail_symbol_ns_one:
    inc     qword [rel failed]

.symbol_ns_invalid:
    mov     rdi, symctx
    xor     esi, esi
    call    er_av1_symbol_read_ns
    test    eax, eax
    jnz     .fail_symbol_ns_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_symbol_ns_invalid
    inc     qword [rel passed]
    jmp     .symbol_subexp_zero
.fail_symbol_ns_invalid:
    inc     qword [rel failed]

.symbol_subexp_zero:
    mov     rdi, symctx
    mov     rsi, sym_zero
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_subexp_zero
    mov     rdi, symctx
    mov     esi, 16
    call    er_av1_symbol_decode_subexp
    test    edx, edx
    jnz     .fail_symbol_subexp_zero
    test    eax, eax
    jnz     .fail_symbol_subexp_zero
    inc     qword [rel passed]
    jmp     .symbol_subexp_one
.fail_symbol_subexp_zero:
    inc     qword [rel failed]

.symbol_subexp_one:
    mov     rdi, symctx
    mov     rsi, sym_one
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_subexp_one
    mov     rdi, symctx
    mov     esi, 16
    call    er_av1_symbol_decode_subexp
    test    edx, edx
    jnz     .fail_symbol_subexp_one
    cmp     eax, 15
    jne     .fail_symbol_subexp_one
    inc     qword [rel passed]
    jmp     .symbol_subexp_invalid
.fail_symbol_subexp_one:
    inc     qword [rel failed]

.symbol_subexp_invalid:
    mov     rdi, symctx
    xor     esi, esi
    call    er_av1_symbol_decode_subexp
    test    eax, eax
    jnz     .fail_symbol_subexp_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_symbol_subexp_invalid
    inc     qword [rel passed]
    jmp     .symbol_invalid
.fail_symbol_subexp_invalid:
    inc     qword [rel failed]

.symbol_invalid:
    mov     rdi, symctx
    xor     esi, esi
    mov     edx, 1
    call    er_av1_symbol_init
    test    eax, eax
    jnz     .fail_symbol_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_symbol_invalid
    mov     rdi, symctx
    mov     rsi, sym_zero
    xor     edx, edx
    call    er_av1_symbol_init
    test    eax, eax
    jnz     .fail_symbol_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_symbol_invalid
    mov     rdi, symctx
    mov     rsi, cdf_bad_eq
    mov     edx, 4
    xor     ecx, ecx
    call    er_av1_symbol_read_symbol
    test    eax, eax
    jnz     .fail_symbol_invalid
    cmp     edx, ERROR_CORRUPT
    jne     .fail_symbol_invalid
    inc     qword [rel passed]
    jmp     .symbol_exit_good
.fail_symbol_invalid:
    inc     qword [rel failed]

.symbol_exit_good:
    mov     rdi, symctx
    mov     rsi, sym_trail_good
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_exit_good
    mov     rdi, symctx
    call    er_av1_symbol_exit
    test    edx, edx
    jnz     .fail_symbol_exit_good
    cmp     eax, 8
    jne     .fail_symbol_exit_good
    cmp     dword [rel symctx + AV1_SYMBOL_POS], 8
    jne     .fail_symbol_exit_good
    inc     qword [rel passed]
    jmp     .symbol_exit_bad_marker
.fail_symbol_exit_good:
    inc     qword [rel failed]

.symbol_exit_bad_marker:
    mov     rdi, symctx
    mov     rsi, sym_zero
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_exit_bad_marker
    mov     rdi, symctx
    call    er_av1_symbol_exit
    test    eax, eax
    jnz     .fail_symbol_exit_bad_marker
    cmp     edx, ERROR_CORRUPT
    jne     .fail_symbol_exit_bad_marker
    inc     qword [rel passed]
    jmp     .symbol_exit_bad_padding
.fail_symbol_exit_bad_marker:
    inc     qword [rel failed]

.symbol_exit_bad_padding:
    mov     rdi, symctx
    mov     rsi, sym_trail_bad_padding
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_exit_bad_padding
    mov     rdi, symctx
    call    er_av1_symbol_exit
    test    eax, eax
    jnz     .fail_symbol_exit_bad_padding
    cmp     edx, ERROR_CORRUPT
    jne     .fail_symbol_exit_bad_padding
    inc     qword [rel passed]
    jmp     .symbol_exit_bad_maxbits
.fail_symbol_exit_bad_padding:
    inc     qword [rel failed]

.symbol_exit_bad_maxbits:
    mov     rdi, symctx
    mov     rsi, sym_trail_good
    mov     edx, 1
    call    er_av1_symbol_init
    test    edx, edx
    jnz     .fail_symbol_exit_bad_maxbits
    mov     dword [rel symctx + AV1_SYMBOL_MAX_BITS], -15
    mov     rdi, symctx
    call    er_av1_symbol_exit
    test    eax, eax
    jnz     .fail_symbol_exit_bad_maxbits
    cmp     edx, ERROR_CORRUPT
    jne     .fail_symbol_exit_bad_maxbits
    inc     qword [rel passed]
    jmp     .sequence_encode
.fail_symbol_exit_bad_maxbits:
    inc     qword [rel failed]

.sequence_encode:
    mov     rdi, outbuf
    mov     esi, 16
    mov     edx, 64
    mov     ecx, 32
    call    er_av1_sequence_encode_reduced_still
    cmp     eax, 8
    jne     .fail_sequence_encode
    test    edx, edx
    jnz     .fail_sequence_encode
    inc     qword [rel passed]
    jmp     .sequence_decode
.fail_sequence_encode:
    inc     qword [rel failed]

.sequence_decode:
    mov     rdi, outbuf
    mov     esi, 8
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    eax, eax
    jz      .fail_sequence_decode
    test    edx, edx
    jnz     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_PROFILE], AV1_SEQ_PROFILE_MAIN
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_STILL_PICTURE], 1
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_REDUCED_STILL], 1
    jne     .fail_sequence_decode
    cmp     dword [rel seq + AV1_SEQ_MAX_WIDTH], 64
    jne     .fail_sequence_decode
    cmp     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 32
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_SUBSAMPLING_X], 1
    jne     .fail_sequence_decode
    cmp     byte [rel seq + AV1_SEQ_SUBSAMPLING_Y], 1
    jne     .fail_sequence_decode
    inc     qword [rel passed]
    jmp     .sequence_non_reduced_encode
.fail_sequence_decode:
    inc     qword [rel failed]

.sequence_non_reduced_encode:
    mov     byte [rel seq + AV1_SEQ_PROFILE], AV1_SEQ_PROFILE_MAIN
    mov     byte [rel seq + AV1_SEQ_STILL_PICTURE], 0
    mov     byte [rel seq + AV1_SEQ_REDUCED_STILL], 0
    mov     byte [rel seq + AV1_SEQ_LEVEL_IDX], AV1_SEQ_LEVEL_2_0
    mov     byte [rel seq + AV1_SEQ_WIDTH_BITS], 16
    mov     byte [rel seq + AV1_SEQ_HEIGHT_BITS], 16
    mov     dword [rel seq + AV1_SEQ_MAX_WIDTH], 320
    mov     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 240
    mov     byte [rel seq + AV1_SEQ_BIT_DEPTH], AV1_SEQ_BIT_DEPTH_8
    mov     byte [rel seq + AV1_SEQ_TIMING_INFO_PRESENT], 1
    mov     dword [rel seq + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 1001
    mov     dword [rel seq + AV1_SEQ_TIME_SCALE], 60000
    mov     byte [rel seq + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 0
    mov     byte [rel seq + AV1_SEQ_INITIAL_DISPLAY_DELAY], 0
    mov     byte [rel seq + AV1_SEQ_OPERATING_POINTS_MINUS_1], 0
    mov     word [rel seq + AV1_SEQ_OPERATING_POINT_IDC], 0
    mov     byte [rel seq + AV1_SEQ_FRAME_ID_NUMBERS_PRESENT], 0
    mov     byte [rel seq + AV1_SEQ_USE_128X128_SUPERBLOCK], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_FILTER_INTRA], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_INTRA_EDGE_FILTER], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_INTERINTRA_COMPOUND], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_MASKED_COMPOUND], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_WARPED_MOTION], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_DUAL_FILTER], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_JNT_COMP], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_REF_FRAME_MVS], 1
    mov     byte [rel seq + AV1_SEQ_FORCE_SCREEN_CONTENT_TOOLS], AV1_SEQ_SELECT_SCREEN_CONTENT_TOOLS
    mov     byte [rel seq + AV1_SEQ_FORCE_INTEGER_MV], AV1_SEQ_SELECT_INTEGER_MV
    mov     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 7
    mov     byte [rel seq + AV1_SEQ_ENABLE_SUPERRES], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_CDEF], 1
    mov     byte [rel seq + AV1_SEQ_ENABLE_RESTORATION], 1
    mov     byte [rel seq + AV1_SEQ_MONO_CHROME], 0
    mov     byte [rel seq + AV1_SEQ_COLOR_DESCRIPTION_PRESENT], 0
    mov     byte [rel seq + AV1_SEQ_COLOR_RANGE], 1
    mov     byte [rel seq + AV1_SEQ_CHROMA_SAMPLE_POSITION], AV1_CHROMA_SAMPLE_POSITION_UNKNOWN
    mov     byte [rel seq + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    mov     byte [rel seq + AV1_SEQ_FILM_GRAIN], 1
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, seq
    call    er_av1_sequence_encode
    test    eax, eax
    jz      .fail_sequence_non_reduced_encode
    test    edx, edx
    jnz     .fail_sequence_non_reduced_encode
    inc     qword [rel passed]
    jmp     .sequence_non_reduced_decode
.fail_sequence_non_reduced_encode:
    inc     qword [rel failed]

.sequence_non_reduced_decode:
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, seq
    call    er_av1_sequence_decode
    test    eax, eax
    jz      .fail_sequence_non_reduced_decode
    test    edx, edx
    jnz     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_REDUCED_STILL], 0
    jne     .fail_sequence_non_reduced_decode
    cmp     dword [rel seq + AV1_SEQ_MAX_WIDTH], 320
    jne     .fail_sequence_non_reduced_decode
    cmp     dword [rel seq + AV1_SEQ_MAX_HEIGHT], 240
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_TIMING_INFO_PRESENT], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     dword [rel seq + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 1001
    jne     .fail_sequence_non_reduced_decode
    cmp     dword [rel seq + AV1_SEQ_TIME_SCALE], 60000
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 0
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_USE_128X128_SUPERBLOCK], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_ENABLE_ORDER_HINT], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_ORDER_HINT_BITS], 7
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_ENABLE_SUPERRES], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_ENABLE_CDEF], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_ENABLE_RESTORATION], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_SEPARATE_UV_DELTA_Q], 1
    jne     .fail_sequence_non_reduced_decode
    cmp     byte [rel seq + AV1_SEQ_FILM_GRAIN], 1
    jne     .fail_sequence_non_reduced_decode
    inc     qword [rel passed]
    jmp     .sequence_bad_profile
.fail_sequence_non_reduced_decode:
    inc     qword [rel failed]

.sequence_bad_profile:
    mov     rdi, bad_profile
    mov     esi, 1
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    eax, eax
    jnz     .fail_sequence_bad_profile
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_sequence_bad_profile
    inc     qword [rel passed]
    jmp     .sequence_short
.fail_sequence_bad_profile:
    inc     qword [rel failed]

.sequence_short:
    mov     rdi, short_seq
    mov     esi, 1
    mov     rdx, seq
    call    er_av1_sequence_decode_reduced_still
    test    eax, eax
    jnz     .fail_sequence_short
    cmp     edx, ERROR_NO_DATA
    jne     .fail_sequence_short
    inc     qword [rel passed]
    jmp     .sequence_encode_invalid
.fail_sequence_short:
    inc     qword [rel failed]

.sequence_encode_invalid:
    mov     rdi, outbuf
    mov     esi, 16
    xor     edx, edx
    mov     ecx, 32
    call    er_av1_sequence_encode_reduced_still
    test    eax, eax
    jnz     .fail_sequence_encode_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_sequence_encode_invalid
    inc     qword [rel passed]
    jmp     .sequence_encode_invalid_timing
.fail_sequence_encode_invalid:
    inc     qword [rel failed]

.sequence_encode_invalid_timing:
    mov     byte [rel seq + AV1_SEQ_TIMING_INFO_PRESENT], 1
    mov     dword [rel seq + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 0
    mov     dword [rel seq + AV1_SEQ_TIME_SCALE], 60000
    mov     byte [rel seq + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 0
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, seq
    call    er_av1_sequence_encode
    test    eax, eax
    jnz     .fail_sequence_encode_invalid_timing
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_sequence_encode_invalid_timing
    mov     dword [rel seq + AV1_SEQ_NUM_UNITS_IN_DISPLAY_TICK], 1001
    mov     byte [rel seq + AV1_SEQ_EQUAL_PICTURE_INTERVAL], 1
    mov     rdi, outbuf
    mov     esi, 32
    mov     rdx, seq
    call    er_av1_sequence_encode
    test    eax, eax
    jnz     .fail_sequence_encode_invalid_timing
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_sequence_encode_invalid_timing
    inc     qword [rel passed]
    jmp     .done
.fail_sequence_encode_invalid_timing:
    inc     qword [rel failed]

.done:
    xor     edi, edi
    cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall
