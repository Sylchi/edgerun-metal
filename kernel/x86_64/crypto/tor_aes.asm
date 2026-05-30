; EdgeRun Tor AES-128 CTR mode — x86_64 assembly
; Software AES-128 for circuit-level encryption.
; Freestanding, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_memcpy

SECTION .rodata

; AES S-box
aes_sbox:
db 0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76
db 0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0
db 0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15
db 0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75
db 0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84
db 0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf
db 0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8
db 0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2
db 0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73
db 0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb
db 0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79
db 0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08
db 0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a
db 0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e
db 0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf
db 0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16

; AES round constant (Rcon)
aes_rcon:
db 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36

SECTION .text

; ==================================================================
; _aes_key_expand — expand 128-bit key to 11 round keys
; void _aes_key_expand(const u8 *key[16], u8 *round_keys[176])
; ==================================================================
_aes_key_expand:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; key
    mov     r13, rsi        ; round_keys buffer

    lea     r10, [rel aes_sbox]
    lea     r11, [rel aes_rcon]

    ; Copy first 16 bytes (round key 0)
    mov     rdi, r13
    mov     rsi, r12
    mov     edx, 16
    call    er_memcpy

    ; Generate remaining 10 round keys
    xor     ecx, ecx        ; round index 0..9
    lea     rbx, [r13 + 16] ; current position

.expand_loop:
    ; Previous round key end (16 bytes before current)
    lea     rsi, [rbx - 16]

    mov     r14d, [rsi]         ; w[i-4] LE: byte0=a0, byte1=a1, byte2=a2, byte3=a3
    mov     r15d, [rsi + 12]    ; w[i-1] LE: byte0=b0, byte1=b1, byte2=b2, byte3=b3

    ; byte0 of result = a3 ^ S[b0] = (w0>>24) ^ S[w3_byte0]
    movzx   edx, r15b           ; w3 byte 0 = b0
    movzx   edx, byte [r10 + rdx]
    mov     eax, r14d
    shr     eax, 24
    xor     eax, edx
    mov     r8d, eax

    ; byte1 = a2 ^ S[b3] = (w0>>16 & 0xFF) ^ S[w3>>24]
    mov     eax, r15d
    shr     eax, 24
    movzx   edx, al
    movzx   edx, byte [r10 + rdx]
    mov     eax, r14d
    shr     eax, 16
    movzx   eax, al
    xor     eax, edx
    shl     eax, 8
    or      r8d, eax

    ; byte2 = a1 ^ S[b2] = (w0>>8 & 0xFF) ^ S[(w3>>16) & 0xFF]
    mov     eax, r15d
    shr     eax, 16
    movzx   edx, al
    movzx   edx, byte [r10 + rdx]
    mov     eax, r14d
    shr     eax, 8
    movzx   eax, al
    xor     eax, edx
    shl     eax, 16
    or      r8d, eax

    ; byte3 = a0 ^ S[b1] ^ Rcon = (w0 & 0xFF) ^ S[(w3>>8) & 0xFF] ^ Rcon
    mov     eax, r15d
    shr     eax, 8
    movzx   edx, al
    movzx   edx, byte [r10 + rdx]
    movzx   eax, r14b
    xor     eax, edx
    movzx   edx, byte [r11 + rcx]
    xor     eax, edx
    shl     eax, 24
    or      r8d, eax

    ; Store in BE byte order (matching state and round key 0 byte order)
    bswap   r8d
    mov     [rbx], r8d        ; w[i] = w[i-4] ^ SubWord(RotWord(w[i-1])) ^ Rcon

    ; Remaining 3 columns: w[i+N] = w[i-4+N] ^ w[i+N-1]
    mov     eax, [rsi + 4]      ; w[i-3]
    xor     eax, [rbx]          ; ^ w[i]
    mov     [rbx + 4], eax      ; w[i+1]

    mov     eax, [rsi + 8]      ; w[i-2]
    xor     eax, [rbx + 4]      ; ^ w[i+1]
    mov     [rbx + 8], eax      ; w[i+2]

    mov     eax, [rsi + 12]     ; w[i-1]
    xor     eax, [rbx + 8]      ; ^ w[i+2]
    mov     [rbx + 12], eax     ; w[i+3]

    add     rbx, 16
    inc     ecx
    cmp     ecx, 10
    jb      .expand_loop

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _aes_encrypt_block — encrypt one 16-byte block
; void _aes_encrypt_block(u8 *block[16], const u8 *round_keys[176])
; ==================================================================
_aes_encrypt_block:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; block
    mov     r13, rsi        ; round_keys buffer

    ; AddRoundKey (initial)
    mov     eax, [r13]
    xor     [r12 + 0], eax
    mov     eax, [r13 + 4]
    xor     [r12 + 4], eax
    mov     eax, [r13 + 8]
    xor     [r12 + 8], eax
    mov     eax, [r13 + 12]
    xor     [r12 + 12], eax

    ; 9 main rounds
    xor     r14d, r14d
    inc     r14d            ; round key index (1-based)

.round_loop:
    ; Compute round key pointer: r13 + r14*16
    mov     rbx, r14
    shl     rbx, 4          ; rbx = r14 * 16
    add     rbx, r13        ; rbx = &round_keys[r14]

    ; SubBytes (table lookup)
    lea     r10, [rel aes_sbox]

    xor     eax, eax
    mov     al,  byte [r12]
    movzx   eax, byte [r10 + rax]
    shl     eax, 0
    mov     ecx, eax
    movzx   eax, byte [r12 + 1]
    movzx   eax, byte [r10 + rax]
    shl     eax, 8
    or      ecx, eax
    movzx   eax, byte [r12 + 2]
    movzx   eax, byte [r10 + rax]
    shl     eax, 16
    or      ecx, eax
    movzx   eax, byte [r12 + 3]
    movzx   eax, byte [r10 + rax]
    shl     eax, 24
    or      ecx, eax
    mov     dword [r12], ecx

    xor     eax, eax
    mov     al,  byte [r12 + 4]
    movzx   eax, byte [r10 + rax]
    shl     eax, 0
    mov     ecx, eax
    movzx   eax, byte [r12 + 5]
    movzx   eax, byte [r10 + rax]
    shl     eax, 8
    or      ecx, eax
    movzx   eax, byte [r12 + 6]
    movzx   eax, byte [r10 + rax]
    shl     eax, 16
    or      ecx, eax
    movzx   eax, byte [r12 + 7]
    movzx   eax, byte [r10 + rax]
    shl     eax, 24
    or      ecx, eax
    mov     dword [r12 + 4], ecx

    xor     eax, eax
    mov     al,  byte [r12 + 8]
    movzx   eax, byte [r10 + rax]
    shl     eax, 0
    mov     ecx, eax
    movzx   eax, byte [r12 + 9]
    movzx   eax, byte [r10 + rax]
    shl     eax, 8
    or      ecx, eax
    movzx   eax, byte [r12 + 10]
    movzx   eax, byte [r10 + rax]
    shl     eax, 16
    or      ecx, eax
    movzx   eax, byte [r12 + 11]
    movzx   eax, byte [r10 + rax]
    shl     eax, 24
    or      ecx, eax
    mov     dword [r12 + 8], ecx

    xor     eax, eax
    mov     al,  byte [r12 + 12]
    movzx   eax, byte [r10 + rax]
    shl     eax, 0
    mov     ecx, eax
    movzx   eax, byte [r12 + 13]
    movzx   eax, byte [r10 + rax]
    shl     eax, 8
    or      ecx, eax
    movzx   eax, byte [r12 + 14]
    movzx   eax, byte [r10 + rax]
    shl     eax, 16
    or      ecx, eax
    movzx   eax, byte [r12 + 15]
    movzx   eax, byte [r10 + rax]
    shl     eax, 24
    or      ecx, eax
    mov     dword [r12 + 12], ecx

    ; ShiftRows — standard AES row shift on column-major state

    ; Load state as 4 column dwords (column-major throughout)
    ; column 0 = [s00,s10,s20,s30] at bytes 0-3
    ; column 1 = [s01,s11,s21,s31] at bytes 4-7
    ; column 2 = [s02,s12,s22,s32] at bytes 8-11
    ; column 3 = [s03,s13,s23,s33] at bytes 12-15
    mov     eax, [r12 + 0]   ; col 0: s00 s10 s20 s30
    mov     ecx, [r12 + 4]   ; col 1: s01 s11 s21 s31
    mov     edx, [r12 + 8]   ; col 2: s02 s12 s22 s32
    mov     esi, [r12 + 12]  ; col 3: s03 s13 s23 s33

    ; ShiftRows on column-major state, output column-major:
    ;   row 0: s00,s01,s02,s03 -> s00,s01,s02,s03 (unchanged)
    ;   row 1: s10,s11,s12,s13 -> s11,s12,s13,s10 (left rotate 1)
    ;   row 2: s20,s21,s22,s23 -> s22,s23,s20,s21 (left rotate 2)
    ;   row 3: s30,s31,s32,s33 -> s33,s30,s31,s32 (left rotate 3)
    ;
    ; New columns (reading rows from column dwords):
    ;   c0' = [eax.byte0=s00, ecx.byte1=s11, edx.byte2=s22, esi.byte3=s33]
    ;   c1' = [ecx.byte0=s01, edx.byte1=s12, esi.byte2=s23, eax.byte3=s30]
    ;   c2' = [edx.byte0=s02, esi.byte1=s13, eax.byte2=s20, ecx.byte3=s31]
    ;   c3' = [esi.byte0=s03, eax.byte1=s10, ecx.byte2=s21, edx.byte3=s32]

    ; Extract bytes from 4 column dwords
    ; eax = column 0 = byte0(s00),byte1(s10),byte2(s20),byte3(s30)
    ; ecx = column 1 = byte0(s01),byte1(s11),byte2(s21),byte3(s31)
    ; edx = column 2 = byte0(s02),byte1(s12),byte2(s22),byte3(s32)
    ; esi = column 3 = byte0(s03),byte1(s13),byte2(s23),byte3(s33)

    ; Build new columns
    push    rbx
    ; c0' = s00 | s11 | s22 | s33
    mov     ebx, eax        ; s00
    and     ebx, 0xFF
    mov     edi, ecx
    shr     edi, 8
    and     edi, 0xFF       ; s11
    shl     edi, 8
    or      ebx, edi
    mov     edi, edx
    shr     edi, 16
    and     edi, 0xFF       ; s22
    shl     edi, 16
    or      ebx, edi
    mov     edi, esi
    shr     edi, 24
    and     edi, 0xFF       ; s33
    shl     edi, 24
    or      ebx, edi
    mov     [r12 + 0], ebx  ; store c0'

    ; c1' = s01 | s12 | s23 | s30
    mov     ebx, ecx
    and     ebx, 0xFF       ; s01 = ecx byte 0
    mov     edi, edx
    shr     edi, 8
    and     edi, 0xFF       ; s12 = edx byte 1
    shl     edi, 8
    or      ebx, edi
    mov     edi, esi
    shr     edi, 16
    and     edi, 0xFF       ; s23 = esi byte 2
    shl     edi, 16
    or      ebx, edi
    mov     edi, eax
    shr     edi, 24
    and     edi, 0xFF       ; s30 = eax byte 3
    shl     edi, 24
    or      ebx, edi
    mov     [r12 + 4], ebx  ; store c1'

    ; c2' = s02 | s13 | s20 | s31
    mov     ebx, edx
    and     ebx, 0xFF       ; s02 = edx byte 0
    mov     edi, esi
    shr     edi, 8
    and     edi, 0xFF       ; s13 = esi byte 1
    shl     edi, 8
    or      ebx, edi
    mov     edi, eax
    shr     edi, 16
    and     edi, 0xFF       ; s20 = eax byte 2
    shl     edi, 16
    or      ebx, edi
    mov     edi, ecx
    shr     edi, 24
    and     edi, 0xFF       ; s31 = ecx byte 3
    shl     edi, 24
    or      ebx, edi
    mov     [r12 + 8], ebx  ; store c2'

    ; c3' = s03 | s10 | s21 | s32
    mov     ebx, esi
    and     ebx, 0xFF       ; s03 = esi byte 0
    mov     edi, eax
    shr     edi, 8
    and     edi, 0xFF       ; s10 = eax byte 1
    shl     edi, 8
    or      ebx, edi
    mov     edi, ecx
    shr     edi, 16
    and     edi, 0xFF       ; s21 = ecx byte 2
    shl     edi, 16
    or      ebx, edi
    mov     edi, edx
    shr     edi, 24
    and     edi, 0xFF       ; s32 = edx byte 3
    shl     edi, 24
    or      ebx, edi
    mov     [r12 + 12], ebx ; store c3'
    pop     rbx

    ; MixColumns (done in all rounds except final)
    cmp     r14d, 10
    je      .add_key        ; last round: skip MixColumns

    ; For each column, apply MixColumns matrix multiplication:
    ; [s0']   [2 3 1 1] [s0]
    ; [s1'] = [1 2 3 1] [s1]
    ; [s2']   [1 1 2 3] [s2]
    ; [s3']   [3 1 1 2] [s3]
    ;
    ; GF(2^8) multiplication by 2: xtime (<< 1, conditional XOR with 0x1b)
    ; *3 = *2 XOR *1

    ; MixColumns — process all 4 columns via macro
    ;
    ; For a column [a,b,c,d] (4 bytes), output is:
    ;   out0 = 2*a ^ 3*b ^ c ^ d
    ;   out1 = a ^ 2*b ^ 3*c ^ d
    ;   out2 = a ^ b ^ 2*c ^ 3*d
    ;   out3 = 3*a ^ b ^ c ^ 2*d
    ; where 2*x = xtime(x) = (x<<1) ^ (0x1b & -(x>>7))
    ;       3*x = xtime(x) ^ x
    ;
    ; Uses r8-r15 as scratch; r12/r13/r14/r15 saved on stack and restored after.
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12        ; rsi = state pointer (safe for reading)

%macro _MC_COL 2  ; read_offset, store_offset
    movzx   eax, byte [rsi + %1 + 0]
    movzx   ecx, byte [rsi + %1 + 1]
    movzx   edx, byte [rsi + %1 + 2]
    movzx   ebx, byte [rsi + %1 + 3]

    ; xtime for each byte (r8=xtime(a), r9=xtime(b), r10=xtime(c), r11=xtime(d))
    movzx   r8d, al
    mov     r13d, r8d
    shl     r13d, 1
    mov     r12d, r8d
    shr     r12d, 7
    neg     r12d
    and     r12d, 0x1b
    xor     r13d, r12d
    mov     r8d, r13d

    movzx   r9d, cl
    mov     r13d, r9d
    shl     r13d, 1
    mov     r12d, r9d
    shr     r12d, 7
    neg     r12d
    and     r12d, 0x1b
    xor     r13d, r12d
    mov     r9d, r13d

    movzx   r10d, dl
    mov     r13d, r10d
    shl     r13d, 1
    mov     r12d, r10d
    shr     r12d, 7
    neg     r12d
    and     r12d, 0x1b
    xor     r13d, r12d
    mov     r10d, r13d

    movzx   r11d, bl
    mov     r13d, r11d
    shl     r13d, 1
    mov     r12d, r11d
    shr     r12d, 7
    neg     r12d
    and     r12d, 0x1b
    xor     r13d, r12d
    mov     r11d, r13d

    ; Save original bytes
    movzx   r12d, al
    movzx   r13d, cl
    movzx   r14d, dl
    movzx   r15d, bl

    ; out0 = 2*a ^ 3*b ^ c ^ d
    mov     edi, r8d
    xor     edi, r9d
    xor     edi, r13d
    xor     edi, r14d
    xor     edi, r15d
    mov     byte [rsi + %2 + 0], dil

    ; out1 = a ^ 2*b ^ 3*c ^ d
    mov     edi, r12d
    xor     edi, r9d
    xor     edi, r10d
    xor     edi, r14d
    xor     edi, r15d
    mov     byte [rsi + %2 + 1], dil

    ; out2 = a ^ b ^ 2*c ^ 3*d
    mov     edi, r12d
    xor     edi, r13d
    xor     edi, r10d
    xor     edi, r11d
    xor     edi, r15d
    mov     byte [rsi + %2 + 2], dil

    ; out3 = 3*a ^ b ^ c ^ 2*d
    mov     edi, r8d
    xor     edi, r12d
    xor     edi, r13d
    xor     edi, r14d
    xor     edi, r11d
    mov     byte [rsi + %2 + 3], dil
%endmacro

    _MC_COL 0, 0
    _MC_COL 4, 4
    _MC_COL 8, 8
    _MC_COL 12, 12

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx

.add_key:
    ; AddRoundKey
    ; rbx already holds round key pointer (set up at start of loop)
    mov     eax, [rbx]
    xor     [r12 + 0], eax
    mov     eax, [rbx + 4]
    xor     [r12 + 4], eax
    mov     eax, [rbx + 8]
    xor     [r12 + 8], eax
    mov     eax, [rbx + 12]
    xor     [r12 + 12], eax

    inc     r14d
    cmp     r14d, 11
    jl      .round_loop

    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_tor_aes_ctr — AES-128-CTR encrypt/decrypt
; void er_tor_aes_ctr(u8 *out, const u8 *in, u32 len,
;                     const u8 *key[16], u8 *iv[16])
;
; In CTR mode, encryption and decryption are the same operation.
; IV is incremented after each block.
; ==================================================================
er_fn er_tor_aes_ctr
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; out
    mov     r13, rsi        ; in
    mov     r14d, edx       ; len
    mov     r15, rcx        ; key

    ; Combined stack frame: 32 (counter/work) + 16 (IV save + pad) + 176 (round_keys) = 224
    sub     rsp, 224
    mov     [rsp + 32], r8  ; save IV pointer

    ; Key expansion — pass buffer at rsp+48
    mov     rdi, r15
    lea     rsi, [rsp + 48]
    call    _aes_key_expand

    ; Copy counter from saved IV
    mov     r8, [rsp + 32]  ; restore IV pointer
    mov     rdi, rsp        ; counter buffer at rsp
    mov     rsi, r8
    mov     edx, 16
    call    er_memcpy
    mov     rbx, rsp        ; rbx = counter block

.ctr_loop:
    cmp     r14d, 0
    je      .done

    ; Calculate block size (16 bytes unless partial)
    mov     ecx, 16
    cmp     r14d, 16
    jae     .full_block
    mov     ecx, r14d
.full_block:

    ; Copy counter to work buffer and encrypt the copy
    mov     r15d, ecx       ; save block size (no push — keeps stack aligned)
    lea     rdi, [rbx + 16]
    mov     rsi, rbx
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [rbx + 16]
    lea     rsi, [rsp + 48] ; round_keys buffer
    call    _aes_encrypt_block
    mov     ecx, r15d       ; restore block size

    ; XOR encrypted counter with input (from work buffer at rbx+16)
    xor     r8d, r8d
.xor_loop:
    cmp     r8d, ecx
    jae     .xor_done
    mov     al, [r13 + r8]
    xor     al, [rbx + 16 + r8]
    mov     [r12 + r8], al
    inc     r8d
    jmp     .xor_loop
.xor_done:

    ; Advance pointers
    add     r12, rcx
    add     r13, rcx
    sub     r14d, ecx

    ; Increment counter (big-endian) — increments the original counter at rbx
    mov     eax, [rbx + 12]
    bswap   eax
    add     eax, 1          ; use add to set CF (inc does not set CF)
    bswap   eax
    mov     [rbx + 12], eax
    jnc     .ctr_loop      ; no carry, continue
    ; Carry into next dword (rare)
    mov     eax, [rbx + 8]
    bswap   eax
    add     eax, 1
    bswap   eax
    mov     [rbx + 8], eax
    jmp     .ctr_loop

.done:
    add     rsp, 224
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
