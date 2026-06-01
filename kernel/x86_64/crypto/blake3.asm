; EdgeRun BLAKE3 hash — pure x86_64 scalar assembly
; System V AMD64 ABI: rdi, rsi, rdx, rcx, r8, r9
; No libc, no SIMD, no external dependencies.

%include "x86_64/macros.inc"

default rel

; ==================================================================
; Constants
; ==================================================================
%define BLAKE3_OUT_LEN       32
%define BLAKE3_BLOCK_LEN     64
%define BLAKE3_CHUNK_LEN     1024
%define BLAKE3_MAX_DEPTH     54
%define BLAKE3_COMPRESS_ROUNDS 7

%define BLAKE3_CHUNK_START   1
%define BLAKE3_CHUNK_END     2
%define BLAKE3_PARENT        4
%define BLAKE3_ROOT          8

; ==================================================================
; .rodata
; ==================================================================
SECTION .rodata

blake3_iv:
    dd 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    dd 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

blake3_perm:
    db  0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15
    db  2, 6, 3,10, 7, 0, 4,13, 1,11,12, 5, 9,14,15, 8
    db  3, 4,10,12,13, 2, 7,14, 6, 5, 9, 0,11,15, 8, 1
    db 10, 7,12, 9,14, 3,13,15, 4, 0,11, 2, 5, 8, 1, 6
    db 12,13, 9,11,15,10,14, 8, 7, 2, 5, 3, 0, 1, 6, 4
    db  9,14,11, 5, 8,12,15, 1,13, 3, 0,10, 2, 6, 4, 7
    db 11,15, 5, 0, 1, 9, 8, 6,14,10, 2,12, 3, 4, 7,13

; ==================================================================
; G function — state in [rdi], mx at [rsp+0], my at [rsp+4]
; Uses r10d, r11d, eax, ecx as temps
; ==================================================================
%macro _blake3_g 4
    mov     r10d, [rdi + %1 * 4]
    add     r10d, [rdi + %2 * 4]
    add     r10d, [rsp]
    mov     [rdi + %1 * 4], r10d
    mov     r11d, [rdi + %4 * 4]
    xor     r11d, r10d
    ror     r11d, 16
    mov     [rdi + %4 * 4], r11d
    mov     r10d, [rdi + %3 * 4]
    add     r10d, r11d
    mov     [rdi + %3 * 4], r10d
    mov     r11d, [rdi + %2 * 4]
    xor     r11d, r10d
    ror     r11d, 12
    mov     [rdi + %2 * 4], r11d
    mov     r10d, [rdi + %1 * 4]
    add     r10d, r11d
    add     r10d, [rsp + 4]
    mov     [rdi + %1 * 4], r10d
    mov     r11d, [rdi + %4 * 4]
    xor     r11d, r10d
    ror     r11d, 8
    mov     [rdi + %4 * 4], r11d
    mov     r10d, [rdi + %3 * 4]
    add     r10d, r11d
    mov     [rdi + %3 * 4], r10d
    mov     r11d, [rdi + %2 * 4]
    xor     r11d, r10d
    ror     r11d, 7
    mov     [rdi + %2 * 4], r11d
%endm

; ==================================================================
; Load mx/my from block_words[r13] using perm indices from [rbx]
; and place on stack for _blake3_g
; ==================================================================
%macro _blake3_g_pair 6
    movzx   r8d, byte [rbx + %1]
    movzx   r9d, byte [rbx + %2]
    mov     r10d, [r13 + r8 * 4]
    mov     r11d, [r13 + r9 * 4]
    sub     rsp, 8
    mov     [rsp], r10d
    mov     [rsp + 4], r11d
    _blake3_g %3, %4, %5, %6
    add     rsp, 8
%endm

; ==================================================================
; One round: 4 column G calls + 4 diagonal G calls
; rdi = state, rbx = perm ptr, r13 = block_words
; ==================================================================
%macro _blake3_round 0
    _blake3_g_pair 0, 1, 0, 4, 8,12
    _blake3_g_pair 2, 3, 1, 5, 9,13
    _blake3_g_pair 4, 5, 2, 6,10,14
    _blake3_g_pair 6, 7, 3, 7,11,15
    _blake3_g_pair 8, 9, 0, 5,10,15
    _blake3_g_pair 10,11, 1, 6,11,12
    _blake3_g_pair 12,13, 2, 7, 8,13
    _blake3_g_pair 14,15, 3, 4, 9,14
%endm

; ==================================================================
; .text
; ==================================================================
SECTION .text

; ==================================================================
; er_blake3_words_from_block(block[64], words[16])
; Convert 64 big-endian bytes to 16 little-endian uint32_t
; =================================================================+
global er_blake3_words_from_block
er_blake3_words_from_block:
    er_frame_push
    xor     rcx, rcx
.loop:
    mov     eax, [rdi + rcx * 4]
    mov     [rsi + rcx * 4], eax
    inc     rcx
    cmp     rcx, 16
    jb      .loop
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_store32(dst, word)
; Store uint32_t as 4 little-endian bytes
; =================================================================+
global er_blake3_store32
er_blake3_store32:
    mov     [rdi], esi
    er_ret

; ==================================================================
; er_blake3_compress(cv[8], block_words[16], counter, block_len,
;                     flags, out[16])
; rdi=cv, rsi=block_words, rdx=counter, rcx=block_len, r8=flags, r9=out
; =================================================================+
global er_blake3_compress
er_blake3_compress:
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 64             ; state[16]

    mov     r12, rdi            ; cv
    mov     r13, rsi            ; block_words
    mov     r14, rdx            ; counter
    mov     r15, r9             ; out

    ; state[14] = block_len — save from ecx before loops clobber it
    mov     [rsp + 14 * 4], ecx
    ; state[15] = flags
    mov     [rsp + 15 * 4], r8d

    ; state[0..7] = cv[0..7]
    xor     rcx, rcx
.icv:
    mov     eax, [r12 + rcx * 4]
    mov     [rsp + rcx * 4], eax
    inc     rcx
    cmp     rcx, 8
    jb      .icv

    ; state[8..11] = IV[0..3]
    lea     rbx, [rel blake3_iv]
    xor     rcx, rcx
.iiv:
    mov     eax, [rbx + rcx * 4]
    mov     [rsp + (8 + rcx) * 4], eax
    inc     rcx
    cmp     rcx, 4
    jb      .iiv

    ; state[12] = counter[31:0]
    mov     [rsp + 12 * 4], r14d
    ; state[13] = counter[63:32]
    mov     eax, r14d
    shr     r14, 32
    mov     [rsp + 13 * 4], r14d

    ; 7 rounds
    mov     rdi, rsp            ; state ptr
    lea     rbx, [rel blake3_perm]
    _blake3_round

    lea     rbx, [rel blake3_perm + 16]
    _blake3_round

    lea     rbx, [rel blake3_perm + 32]
    _blake3_round

    lea     rbx, [rel blake3_perm + 48]
    _blake3_round

    lea     rbx, [rel blake3_perm + 64]
    _blake3_round

    lea     rbx, [rel blake3_perm + 80]
    _blake3_round

    lea     rbx, [rel blake3_perm + 96]
    _blake3_round

    ; out[0..7] = state[0..7] ^ state[8..15]
    ; out[8..15] = state[8..15] ^ cv[0..7]
    xor     rcx, rcx
.fxor:
    mov     eax, [rsp + rcx * 4]
    mov     ebx, [rsp + rcx * 4 + 32]
    xor     eax, ebx
    mov     [r15 + rcx * 4], eax
    xor     ebx, [r12 + rcx * 4]
    mov     [r15 + rcx * 4 + 32], ebx
    inc     rcx
    cmp     rcx, 8
    jb      .fxor

    add     rsp, 64
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_compress_cv(cv[8], block[64], counter, block_len,
;                        flags, new_cv[8])
; Deserializes block to words, compresses, extracts CV from output
; =================================================================+
global er_blake3_compress_cv
er_blake3_compress_cv:
    ; rdi=cv[8], rsi=block[64], rdx=counter, rcx=block_len, r8=flags, r9=new_cv[8]
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 136            ; words[16] + out[16] + saved[2]

    mov     r12, rdi            ; cv
    mov     r13, rsi            ; block
    mov     r14, rdx            ; counter
    mov     r15, r9             ; new_cv

    ; Save block_len and flags across call that clobbers caller-saved regs
    mov     [rsp + 128], ecx
    mov     [rsp + 132], r8d

    ; words_from_block(block, words)
    lea     rsi, [rsp]          ; words at rsp
    mov     rdi, r13
    call    er_blake3_words_from_block

    ; compress(cv, words, counter, block_len, flags, out)
    mov     rdi, r12            ; cv
    lea     rsi, [rsp]          ; words
    mov     rdx, r14            ; counter
    mov     ecx, [rsp + 128]    ; restored block_len
    mov     r8d, [rsp + 132]    ; restored flags
    lea     r9, [rsp + 64]      ; out
    call    er_blake3_compress

    ; new_cv[0..7] = out[0..7]
    xor     rcx, rcx
.xcv:
    mov     eax, [rsp + rcx * 4 + 64]
    mov     [r15 + rcx * 4], eax
    inc     rcx
    cmp     rcx, 8
    jb      .xcv

    add     rsp, 136
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_parent_cv(left_cv[8], right_cv[8], out_cv[8])
; Combine two child CVs into a parent block and compress
; =================================================================+
global er_blake3_parent_cv
er_blake3_parent_cv:
    ; rdi=left_cv, rsi=right_cv, rdx=out_cv
    er_frame_push_regs rbx, r12, r13, r14
    sub     rsp, 64             ; block[64]
    mov     r12, rdi            ; left_cv
    mov     r13, rsi            ; right_cv
    mov     r14, rdx            ; out_cv
    xor     rcx, rcx
.pack_loop:
    mov     eax, [r12 + rcx * 4]
    mov     [rsp + rcx * 4], eax
    mov     eax, [r13 + rcx * 4]
    mov     [rsp + rcx * 4 + 32], eax
    inc     rcx
    cmp     rcx, 8
    jb      .pack_loop
    ; compress_cv(IV, block, 0, 64, PARENT, out_cv)
    lea     rdi, [rel blake3_iv]
    mov     rsi, rsp            ; block
    xor     rdx, rdx            ; counter = 0
    mov     ecx, 64             ; block_len
    mov     r8d, BLAKE3_PARENT  ; flags
    mov     r9, r14             ; out_cv
    call    er_blake3_compress_cv
    add     rsp, 64
    er_pop  rbx, r12, r13, r14
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_hash_chunk(input, len, counter, flags, out_cv)
; Hash one chunk (≤ 1024 bytes), producing a CV
; Stack layout: key[32] + zb[64] + nblocks(8) + i(8) = 112 bytes
; rdi=input, rsi=len, rdx=counter, rcx=flags, r8=out_cv
; =================================================================+
global er_blake3_hash_chunk
er_blake3_hash_chunk:
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 112            ; see layout above

    mov     r12, rdi            ; input
    mov     r13, rsi            ; len
    mov     r14, rdx            ; counter
    mov     r15, rcx            ; flags
    mov     rbx, r8             ; out_cv

    ; key[0..7] = IV
    lea     rax, [rel blake3_iv]
    mov     ecx, [rax]
    mov     [rsp], ecx
    mov     ecx, [rax + 4]
    mov     [rsp + 4], ecx
    mov     ecx, [rax + 8]
    mov     [rsp + 8], ecx
    mov     ecx, [rax + 12]
    mov     [rsp + 12], ecx
    mov     ecx, [rax + 16]
    mov     [rsp + 16], ecx
    mov     ecx, [rax + 20]
    mov     [rsp + 20], ecx
    mov     ecx, [rax + 24]
    mov     [rsp + 24], ecx
    mov     ecx, [rax + 28]
    mov     [rsp + 28], ecx

    er_check_nonzero r13, .nonempty
    ; len == 0: copy IV to out_cv
    mov     ecx, [rax]
    mov     [rbx], ecx
    mov     ecx, [rax + 4]
    mov     [rbx + 4], ecx
    mov     ecx, [rax + 8]
    mov     [rbx + 8], ecx
    mov     ecx, [rax + 12]
    mov     [rbx + 12], ecx
    mov     ecx, [rax + 16]
    mov     [rbx + 16], ecx
    mov     ecx, [rax + 20]
    mov     [rbx + 20], ecx
    mov     ecx, [rax + 24]
    mov     [rbx + 24], ecx
    mov     ecx, [rax + 28]
    mov     [rbx + 28], ecx
    jmp     .done

.nonempty:
    ; nblocks = ceil(len / 64)
    mov     rax, r13
    add     rax, 63
    shr     rax, 6
    mov     [rsp + 96], rax     ; nblocks
    xor     ecx, ecx            ; i = 0 (stays in rcx)

.block_loop:
    cmp     rcx, [rsp + 96]
    jae     .copy_out

    mov     [rsp + 104], rcx    ; save i (safe, above zb)
    mov     r8d, r15d           ; bflags
    mov     r10d, 64            ; block_len
    xor     r11d, r11d          ; rem = 0

    ; Detect last block
    mov     rax, [rsp + 96]     ; nblocks
    dec     rax
    cmp     rcx, rax
    jne     .skip_rem
    mov     rax, r13
    and     eax, 63
    mov     r11d, eax
    er_check_zero eax, .skip_rem
    mov     r10d, eax
.skip_rem:

    ; bflags |= CHUNK_START if i == 0
    er_check_nonzero rcx, .no_cs2
    or      r8d, BLAKE3_CHUNK_START
.no_cs2:

    ; bflags |= CHUNK_END if last
    mov     rax, [rsp + 96]
    dec     rax
    cmp     rcx, rax
    jne     .no_ce2
    or      r8d, BLAKE3_CHUNK_END
.no_ce2:

    ; Force both flags if single block
    cmp     qword [rsp + 96], 1
    jne     .no_frc
    or      r8d, BLAKE3_CHUNK_START | BLAKE3_CHUNK_END
.no_frc:

    ; Set up block pointer
    er_check_zero r11d, .direct_block

    ; Partial last block: zero zb then copy rem bytes
    lea     rdi, [rsp + 32]
    xor     eax, eax
    mov     ecx, 16
    rep stosd

    mov     rsi, r12            ; input
    mov     rax, [rsp + 104]    ; i
    shl     rax, 6
    add     rsi, rax
    lea     rdi, [rsp + 32]
    mov     ecx, r11d
    rep movsb

    lea     r9, [rsp + 32]      ; block = zb
    jmp     .do_compress

.direct_block:
    mov     r9, r12             ; block = input
    mov     rax, [rsp + 104]
    shl     rax, 6
    add     r9, rax

.do_compress:
    mov     rdi, rsp            ; key
    mov     rsi, r9             ; block
    mov     rdx, r14            ; counter
    mov     ecx, r10d           ; block_len
    ; r8d already = bflags
    mov     r9, rsp             ; new_cv = key
    call    er_blake3_compress_cv

    mov     rcx, [rsp + 104]    ; i
    inc     rcx
    jmp     .block_loop

.copy_out:
    mov     ecx, [rsp]
    mov     [rbx], ecx
    mov     ecx, [rsp + 4]
    mov     [rbx + 4], ecx
    mov     ecx, [rsp + 8]
    mov     [rbx + 8], ecx
    mov     ecx, [rsp + 12]
    mov     [rbx + 12], ecx
    mov     ecx, [rsp + 16]
    mov     [rbx + 16], ecx
    mov     ecx, [rsp + 20]
    mov     [rbx + 20], ecx
    mov     ecx, [rsp + 24]
    mov     [rbx + 24], ecx
    mov     ecx, [rsp + 28]
    mov     [rbx + 28], ecx

.done:
    add     rsp, 112
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_hash_one_chunk(input, len, out[32])
; Hash one chunk (≤ 1024 bytes), produce 32-byte output
; Returns rax=1 on success, 0 on failure (len > CHUNK_LEN)
; rdi=input, rsi=len, rdx=out
; =================================================================+
global er_blake3_hash_one_chunk
er_blake3_hash_one_chunk:
    ; Reject if len > CHUNK_LEN (1024)
    cmp     rsi, BLAKE3_CHUNK_LEN
    jbe     .valid_len
    xor     eax, eax
    er_ret
.valid_len:
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 224            ; cv[32] + words[64] + zb[64] + tmp[64]

    mov     r12, rdi            ; input
    mov     r13, rsi            ; len
    mov     r14, rdx            ; out

    ; cv = IV (at rsp+0)
    lea     rax, [rel blake3_iv]
    mov     ecx, [rax]
    mov     [rsp], ecx
    mov     ecx, [rax + 4]
    mov     [rsp + 4], ecx
    mov     ecx, [rax + 8]
    mov     [rsp + 8], ecx
    mov     ecx, [rax + 12]
    mov     [rsp + 12], ecx
    mov     ecx, [rax + 16]
    mov     [rsp + 16], ecx
    mov     ecx, [rax + 20]
    mov     [rsp + 20], ecx
    mov     ecx, [rax + 24]
    mov     [rsp + 24], ecx
    mov     ecx, [rax + 28]
    mov     [rsp + 28], ecx

    er_check_nonzero r13, .hoc_nonempty

    ; Empty input: compress(IV, zeros, 0, 0, C|E|R, tmp)
    ; Zero block_words at rsp+32
    lea     rdi, [rsp + 32]
    xor     eax, eax
    mov     ecx, 16
    rep stosd

    lea     rdi, [rsp]          ; cv = IV
    lea     rsi, [rsp + 32]     ; block_words (zeros)
    xor     rdx, rdx            ; counter = 0
    xor     ecx, ecx            ; block_len = 0
    mov     r8d, BLAKE3_CHUNK_START | BLAKE3_CHUNK_END | BLAKE3_ROOT
    lea     r9, [rsp + 160]     ; tmp
    call    er_blake3_compress

    ; cv = tmp[0..7]
    mov     ecx, [rsp + 160]
    mov     [rsp], ecx
    mov     ecx, [rsp + 164]
    mov     [rsp + 4], ecx
    mov     ecx, [rsp + 168]
    mov     [rsp + 8], ecx
    mov     ecx, [rsp + 172]
    mov     [rsp + 12], ecx
    mov     ecx, [rsp + 176]
    mov     [rsp + 16], ecx
    mov     ecx, [rsp + 180]
    mov     [rsp + 20], ecx
    mov     ecx, [rsp + 184]
    mov     [rsp + 24], ecx
    mov     ecx, [rsp + 188]
    mov     [rsp + 28], ecx

    jmp     .hoc_copy_out

.hoc_nonempty:
    xor     r15d, r15d          ; offset = 0 (in r15)
    mov     rbx, r13            ; remaining = len (in rbx)

.hoc_block_loop:
    cmp     rbx, 64
    jbe     .hoc_last_block

    ; Full block: compress_cv(cv, input + offset, 0, 64, flags, cv)
    mov     rdi, rsp            ; cv
    mov     rsi, r12
    add     rsi, r15            ; input + offset
    xor     rdx, rdx            ; counter = 0
    mov     ecx, 64             ; block_len
    mov     r8d, 0              ; flags (default)
    er_check_nonzero r15, .hoc_flags_set
    mov     r8d, BLAKE3_CHUNK_START
.hoc_flags_set:
    mov     r9, rsp             ; new_cv = cv
    call    er_blake3_compress_cv

    add     r15, 64
    sub     rbx, 64
    jmp     .hoc_block_loop

.hoc_last_block:
    ; Zero-pad zb[64] at rsp+96
    lea     rdi, [rsp + 96]
    xor     eax, eax
    mov     ecx, 16
    rep stosd

    ; Copy remaining bytes to zb
    mov     rsi, r12
    add     rsi, r15            ; input + offset
    lea     rdi, [rsp + 96]     ; zb
    mov     ecx, ebx            ; remaining bytes (≤ 64)
    rep movsb

    ; Load block_words[16] from zb
    lea     rdi, [rsp + 96]     ; zb
    lea     rsi, [rsp + 32]     ; block_words
    call    er_blake3_words_from_block

    ; flags = CHUNK_END
    mov     r8d, BLAKE3_CHUNK_END
    ; Add CHUNK_START if offset == 0 (single block total)
    er_check_nonzero r15, .hoc_flags_done
    or      r8d, BLAKE3_CHUNK_START
.hoc_flags_done:
    or      r8d, BLAKE3_ROOT

    ; compress(cv, block_words, 0, block_len, flags, tmp)
    mov     rdi, rsp            ; cv
    lea     rsi, [rsp + 32]     ; block_words
    xor     rdx, rdx            ; counter = 0
    mov     ecx, ebx            ; block_len = remaining length
    ; r8d already set
    lea     r9, [rsp + 160]     ; tmp
    call    er_blake3_compress

    ; cv = tmp[0..7]
    mov     ecx, [rsp + 160]
    mov     [rsp], ecx
    mov     ecx, [rsp + 164]
    mov     [rsp + 4], ecx
    mov     ecx, [rsp + 168]
    mov     [rsp + 8], ecx
    mov     ecx, [rsp + 172]
    mov     [rsp + 12], ecx
    mov     ecx, [rsp + 176]
    mov     [rsp + 16], ecx
    mov     ecx, [rsp + 180]
    mov     [rsp + 20], ecx
    mov     ecx, [rsp + 184]
    mov     [rsp + 24], ecx
    mov     ecx, [rsp + 188]
    mov     [rsp + 28], ecx

.hoc_copy_out:
    ; Copy cv bytes to out (little-endian uint32_t → byte output)
    mov     ecx, [rsp]
    mov     [r14], ecx
    mov     ecx, [rsp + 4]
    mov     [r14 + 4], ecx
    mov     ecx, [rsp + 8]
    mov     [r14 + 8], ecx
    mov     ecx, [rsp + 12]
    mov     [r14 + 12], ecx
    mov     ecx, [rsp + 16]
    mov     [r14 + 16], ecx
    mov     ecx, [rsp + 20]
    mov     [r14 + 20], ecx
    mov     ecx, [rsp + 24]
    mov     [r14 + 24], ecx
    mov     ecx, [rsp + 28]
    mov     [r14 + 28], ecx

    mov     eax, 1

    add     rsp, 224
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_round_down_pow2(n) — largest power of 2 ≤ n
; =================================================================+
er_blake3_round_down_pow2:
    mov     eax, edi
    or      eax, eax
    jz      .done
    bsr     ecx, eax           ; ecx = highest bit index in eax
    mov     eax, 1
    shl     eax, cl            ; 1 << highest_bit
.done:
    er_ret

; ==================================================================
; er_blake3_subtree_cv(input, len, counter, flags, out_cv)
; Compute CV for arbitrary-length input via recursive tree
; rdi=input, rsi=len, rdx=counter, rcx=flags, r8=out_cv
; =================================================================+
global er_blake3_subtree_cv
er_blake3_subtree_cv:
    cmp     rsi, BLAKE3_CHUNK_LEN
    ja      .multi_chunk
    jmp     er_blake3_hash_chunk   ; tail call (same args)

.multi_chunk:
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 96             ; left_cv[32] + right_cv[32] + saved[32]

    mov     r12, rdi            ; input
    mov     r13, rsi            ; len
    mov     r14, rdx            ; counter
    mov     r15, rcx            ; flags
    mov     rbx, r8             ; out_cv

    ; nfull = len / CHUNK_LEN, rem = len % CHUNK_LEN
    mov     rax, r13
    mov     rdx, rax
    and     rdx, 1023           ; rem = len & (CHUNK_LEN - 1)
    shr     rax, 10             ; nfull = len >> 10 (CHUNK_LEN = 1024 = 2^10)
    mov     [rsp + 64], rax     ; save nfull
    mov     [rsp + 72], rdx     ; save rem

    ; left_chunks = round_down_pow2(nfull)
    mov     rdi, rax
    call    er_blake3_round_down_pow2
    mov     [rsp + 80], rax     ; save left_chunks (in callee-saved stack)

    ; Check if left_chunks == nfull && rem == 0 — exact power-of-2
    mov     rax, [rsp + 64]     ; nfull
    cmp     [rsp + 80], rax     ; left_chunks == nfull?
    jne     .general_case
    cmp     qword [rsp + 72], 0 ; rem == 0?
    jne     .general_case

    ; Exact power-of-2 chunks
    cmp     r13, BLAKE3_CHUNK_LEN
    ja      .bisect

    ; len == CHUNK_LEN — hash as single chunk
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, r15
    mov     r8, rbx
    call    er_blake3_hash_chunk
    jmp     .stc_done

.bisect:
    ; half = len >> 1
    mov     rax, r13
    shr     rax, 1
    mov     [rsp + 88], rax     ; save half

    ; subtree_cv(input, half, counter, flags, left_cv)
    mov     rdi, r12
    mov     rsi, rax
    mov     rdx, r14
    mov     rcx, r15
    lea     r8, [rsp]
    call    er_blake3_subtree_cv

    ; counter2 = counter + half / CHUNK_LEN
    mov     rax, [rsp + 88]     ; half
    shr     rax, 10             ; half >> 10 (CHUNK_LEN = 1024 = 2^10)
    mov     r9, rax
    add     r9, r14             ; counter + half/CHUNK_LEN

    ; subtree_cv(input + half, half, counter2, flags, right_cv)
    mov     rdi, r12
    add     rdi, [rsp + 88]     ; input + half
    mov     rsi, [rsp + 88]     ; half
    mov     rdx, r9             ; counter2
    mov     rcx, r15
    lea     r8, [rsp + 32]
    call    er_blake3_subtree_cv

    ; parent_cv(left_cv, right_cv, out_cv)
    lea     rdi, [rsp]
    lea     rsi, [rsp + 32]
    mov     rdx, rbx
    call    er_blake3_parent_cv
    jmp     .stc_done

.general_case:
    ; left_len = left_chunks * CHUNK_LEN
    mov     rax, [rsp + 80]     ; left_chunks
    mov     ecx, BLAKE3_CHUNK_LEN
    mul     rcx
    mov     [rsp + 88], rax     ; save left_len

    ; subtree_cv(input, left_len, counter, flags, left_cv)
    mov     rdi, r12
    mov     rsi, rax
    mov     rdx, r14
    mov     rcx, r15
    lea     r8, [rsp]
    call    er_blake3_subtree_cv

    ; counter2 = counter + left_chunks
    mov     r9, [rsp + 80]      ; left_chunks
    add     r9, r14             ; counter + left_chunks

    ; subtree_cv(input + left_len, len - left_len, counter2, flags, right_cv)
    mov     rdi, r12
    add     rdi, [rsp + 88]     ; input + left_len
    mov     rsi, r13
    sub     rsi, [rsp + 88]     ; len - left_len
    mov     rdx, r9             ; counter2
    mov     rcx, r15
    lea     r8, [rsp + 32]
    call    er_blake3_subtree_cv

    ; parent_cv(left_cv, right_cv, out_cv)
    lea     rdi, [rsp]
    lea     rsi, [rsp + 32]
    mov     rdx, rbx
    call    er_blake3_parent_cv

.stc_done:
    add     rsp, 96
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_root_from_parent_cvs(left_cv, right_cv, out[32])
; Final root hash from two parent CVs
; =================================================================+
global er_blake3_root_from_parent_cvs
er_blake3_root_from_parent_cvs:
    ; rdi=left_cv, rsi=right_cv, rdx=out
    ; Build block = left_cv|right_cv, compress(IV, block_words, 0, 64, P|R, tmp),
    ; copy tmp[0..7] bytes to out
    er_frame_push_regs rbx, r12, r13
    sub     rsp, 192            ; block[64] + words[64] + tmp[64]

    mov     r12, rdi            ; left_cv
    mov     r13, rsi            ; right_cv
    mov     rbx, rdx            ; out

    ; Build block[64] at rsp: left_cv at +0, right_cv at +32
    xor     rcx, rcx
.pack_r:
    mov     eax, [r12 + rcx * 4]
    mov     [rsp + rcx * 4], eax
    mov     eax, [r13 + rcx * 4]
    mov     [rsp + rcx * 4 + 32], eax
    inc     rcx
    cmp     rcx, 8
    jb      .pack_r

    ; words_from_block(block, words) — at rsp+64
    mov     rdi, rsp            ; block
    lea     rsi, [rsp + 64]     ; words
    call    er_blake3_words_from_block

    ; compress(IV, words, 0, 64, PARENT|ROOT, tmp at rsp+128)
    lea     rdi, [rel blake3_iv]
    lea     rsi, [rsp + 64]     ; words
    xor     rdx, rdx            ; counter = 0
    mov     ecx, 64             ; block_len
    mov     r8d, BLAKE3_PARENT | BLAKE3_ROOT
    lea     r9, [rsp + 128]     ; tmp
    call    er_blake3_compress

    ; Copy tmp[0..7] bytes to out
    mov     ecx, [rsp + 128]
    mov     [rbx], ecx
    mov     ecx, [rsp + 132]
    mov     [rbx + 4], ecx
    mov     ecx, [rsp + 136]
    mov     [rbx + 8], ecx
    mov     ecx, [rsp + 140]
    mov     [rbx + 12], ecx
    mov     ecx, [rsp + 144]
    mov     [rbx + 16], ecx
    mov     ecx, [rsp + 148]
    mov     [rbx + 20], ecx
    mov     ecx, [rsp + 152]
    mov     [rbx + 24], ecx
    mov     ecx, [rsp + 156]
    mov     [rbx + 28], ecx

    add     rsp, 192
    er_pop  rbx, r12, r13
    er_frame_pop
    er_ret

; ==================================================================
; er_blake3_hash_bytes(input, len, out[32])
; Top-level BLAKE3 hash entry point
; Returns rax=1 on success, 0 on failure (null ptr, etc.)
; =================================================================+
global er_blake3_hash_bytes
er_blake3_hash_bytes:
    ; Allow NULL input only when len == 0
    er_check_zero rdi, .check_len_for_null
    jmp     .hb_ready
.check_len_for_null:
    er_check_nonzero rsi, .null_input
.hb_ready:
    er_check_zero rdx, .null_input

    cmp     rsi, BLAKE3_CHUNK_LEN
    jbe     .single

    ; Multi-chunk
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 64             ; left_cv[32] + right_cv[32]

    mov     r12, rdi            ; input
    mov     r13, rsi            ; len
    mov     r14, rdx            ; out

    ; nfull = len / CHUNK_LEN
    mov     rax, r13
    shr     rax, 10             ; nfull = len >> 10 (CHUNK_LEN = 1024 = 2^10)
    mov     r15, rax            ; nfull

    ; left_chunks = pow2 split
    ; If nfull is power of 2 and len % CHUNK_LEN == 0: split evenly
    ; else: largest power-of-2 of nfull
    er_check_nonzero rdx, .split_pow2
    ; Check if nfull is power of 2
    mov     rax, r15
    er_check_zero rax, .split_pow2
    mov     rcx, rax
    dec     rcx
    test    rax, rcx
    jnz     .split_pow2
    ; Power of 2: left_chunks = nfull / 2
    shr     rax, 1
    jmp     .got_left

.split_pow2:
    mov     rdi, r15
    call    er_blake3_round_down_pow2

.got_left:
    mov     r15, rax            ; left_chunks
    mov     rcx, BLAKE3_CHUNK_LEN
    mul     rcx
    mov     rbx, rax            ; left_len = left_chunks * CHUNK_LEN

    ; subtree_cv(input, left_len, 0, 0, left_cv at rsp)
    mov     rdi, r12
    mov     rsi, rbx
    xor     rdx, rdx            ; counter = 0
    xor     rcx, rcx            ; flags = 0
    lea     r8, [rsp]           ; left_cv
    call    er_blake3_subtree_cv

    ; subtree_cv(input + left_len, len - left_len, left_chunks, 0, right_cv at rsp+32)
    mov     rdi, r12
    add     rdi, rbx
    mov     rsi, r13
    sub     rsi, rbx
    mov     rdx, r15            ; counter = left_chunks
    xor     rcx, rcx            ; flags = 0
    lea     r8, [rsp + 32]      ; right_cv
    call    er_blake3_subtree_cv

    ; root_from_parent_cvs(left_cv, right_cv, out)
    lea     rdi, [rsp]          ; left_cv
    lea     rsi, [rsp + 32]     ; right_cv
    mov     rdx, r14            ; out
    call    er_blake3_root_from_parent_cvs

    mov     eax, 1

    add     rsp, 64
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

.single:
    ; er_blake3_hash_one_chunk(input, len, out)
    ; rdi=input, rsi=len, rdx=out — already set
    call    er_blake3_hash_one_chunk
    er_ret

.null_input:
    xor     eax, eax
    er_ret

