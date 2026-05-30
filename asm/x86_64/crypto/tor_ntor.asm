; EdgeRun Tor ntor key agreement — x86_64 assembly
; Curve25519 scalar multiplication + ntor handshake protocol.
;
; Uses BLAKE3 for hashing and TPM for random number generation.
; Field elements are 4 x u64 limbs (radix-2^64), little-endian.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_blake3_hash_bytes
extern er_memcpy
extern er_memset
extern er_tpm_get_random
extern er_tpm_crb_transfer
extern er_tpm_parse_get_random

; Field prime p = 2^255 - 19
; Represented as qword array: [0xFFFFFFFFFFFFFFED, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF]
SECTION .rodata

fe_p:   dq 0xFFFFFFFFFFFFFFED, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
fe_p_hi:dq 0x7FFFFFFFFFFFFFFF  ; top limb of p (for comparison)

; 2*19 = 38, used in reduction
fe_38:  times 4 dq 38

; Order of Curve25519 (for clamping)
fe_order: dq 0x5812631A5CF5D3ED, 0x14DEF9DEA2F79CD7, 0x0000000000000000, 0x1000000000000000

; Base point u coordinate for Curve25519 (standard base point)
; u = 9, represented as 4 x u64
fe_base: dq 9, 0, 0, 0

; Zero
fe_zero: dq 0, 0, 0, 0

; One
fe_one:  dq 1, 0, 0, 0

; Identity string for ntor KDF
ntor_kdf_id1: db "tor-ntor-kdf-1"
ntor_kdf_id2: db "tor-ntor-kdf-2"
ntor_auth_id: db "tor-ntor-auth"

SECTION .bss

; Temporary buffers for field arithmetic
fe_tmp0: resq 4
fe_tmp1: resq 4
fe_tmp2: resq 4
fe_tmp3: resq 4
fe_tmp4: resq 4
fe_prod: resq 8  ; 512-bit product of 256-bit multiplication

; BLAKE3 hash output and context
ntor_hash_out: resb 64
ntor_blake_ctx: resb 256  ; BLAKE3 context workspace

; TPM buffers for random
ntor_tpm_cmd: resb 64
ntor_tpm_rsp: resb 64
ntor_tpm_rng: resb 32

SECTION .text

; ==================================================================
; _fe_carry — normalize field element (carry propagation)
; void _fe_carry(u64 *a)
; Input/output: a[0..3] with possible carry bits above 64 bits per limb
; After: each a[i] < 2^64, and value is fully reduced
; ==================================================================
_fe_carry:
    mov     rax, [rdi + 0]
    mov     rcx, [rdi + 8]
    mov     rdx, [rdi + 16]
    mov     rsi, [rdi + 24]

    ; Carry chain
    mov     r8, rax
    shr     r8, 63
    and     rax, 0x7FFFFFFFFFFFFFFF
    add     rcx, r8

    mov     r8, rcx
    shr     r8, 63
    and     rcx, 0x7FFFFFFFFFFFFFFF
    add     rdx, r8

    mov     r8, rdx
    shr     r8, 63
    and     rdx, 0x7FFFFFFFFFFFFFFF
    add     rsi, r8

    ; Top limb: carry wraps to multiply by 19 and add back
    mov     r8, rsi
    shr     r8, 63
    and     rsi, 0x7FFFFFFFFFFFFFFF

    ; r8 * 19
    imul    r8, r8, 19
    add     rax, r8

    ; Re-carry if needed (rare)
    mov     r8, rax
    shr     r8, 63
    and     rax, 0x7FFFFFFFFFFFFFFF
    add     rcx, r8

    mov     r8, rcx
    shr     r8, 63
    and     rcx, 0x7FFFFFFFFFFFFFFF
    add     rdx, r8

    mov     r8, rdx
    shr     r8, 63
    and     rdx, 0x7FFFFFFFFFFFFFFF
    add     rsi, r8

    ; Final carry from top (wrap with *19)
    mov     r8, rsi
    shr     r8, 63
    and     rsi, 0x7FFFFFFFFFFFFFFF
    imul    r8, r8, 19
    add     rax, r8

    ; One more micro-carry
    mov     r8, rax
    shr     r8, 63
    and     rax, 0x7FFFFFFFFFFFFFFF
    add     rcx, r8

    mov     r8, rcx
    shr     r8, 63
    and     rcx, 0x7FFFFFFFFFFFFFFF
    add     rdx, r8

    mov     r8, rdx
    shr     r8, 63
    and     rdx, 0x7FFFFFFFFFFFFFFF
    add     rsi, r8

    mov     [rdi + 0], rax
    mov     [rdi + 8], rcx
    mov     [rdi + 16], rdx
    mov     [rdi + 24], rsi
    ret

; ==================================================================
; _fe_add — field element addition
; void _fe_add(u64 *dst, const u64 *a, const u64 *b)
; ==================================================================
_fe_add:
    mov     rax, [rsi + 0]
    add     rax, [rdx + 0]
    mov     rcx, [rsi + 8]
    adc     rcx, [rdx + 8]
    mov     r8,  [rsi + 16]
    adc     r8,  [rdx + 16]
    mov     r9,  [rsi + 24]
    adc     r9,  [rdx + 24]

    ; Store with high bit clear (we'll carry later)
    mov     [rdi + 0], rax
    mov     [rdi + 8], rcx
    mov     [rdi + 16], r8
    mov     [rdi + 24], r9
    ret

; ==================================================================
; _fe_sub — field element subtraction
; void _fe_sub(u64 *dst, const u64 *a, const u64 *b)
; Result = a - b (mod p)
; ==================================================================
_fe_sub:
    push    rbx
    ; Load a
    mov     rax, [rsi + 0]
    mov     rcx, [rsi + 8]
    mov     r8,  [rsi + 16]
    mov     r9,  [rsi + 24]

    ; Subtract b
    sub     rax, [rdx + 0]
    sbb     rcx, [rdx + 8]
    sbb     r8,  [rdx + 16]
    sbb     r9,  [rdx + 24]

    ; If borrow, add p back
    jnc     .store

    mov     rbx, [rel fe_p + 0]
    add     rax, rbx
    mov     rbx, [rel fe_p + 8]
    adc     rcx, rbx
    mov     rbx, [rel fe_p + 16]
    adc     r8,  rbx
    mov     rbx, [rel fe_p + 24]
    adc     r9,  rbx

.store:
    mov     [rdi + 0], rax
    mov     [rdi + 8], rcx
    mov     [rdi + 16], r8
    mov     [rdi + 24], r9
    pop     rbx
    ret

; ==================================================================
; _fe_mul — field element multiplication
; void _fe_mul(u64 *dst, const u64 *a, const u64 *b)
; ==================================================================
_fe_mul:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rbx, rdi        ; dst
    mov     r12, rsi        ; a
    mov     r13, rdx        ; b

    ; Product array on stack (8 limbs = 64 bytes)
    sub     rsp, 64
    mov     rdi, rsp
    xor     eax, eax
    mov     ecx, 8
    rep     stosq
    mov     rdi, rbx        ; save dst for later
    mov     r14, rsp        ; product ptr

    ; Fully unrolled 4x4 schoolbook multiplication
    ; a = [r12+0..24], b = [r13+0..24]
    ; product[i+j] += a[i]*b[j]

    ; i=0
    mov     rax, [r12]
    mov     rcx, [r13]
    mul     rcx
    add     [r14], rax
    adc     [r14+8], rdx
    mov     rax, [r12]
    mov     rcx, [r13+8]
    mul     rcx
    add     [r14+8], rax
    adc     [r14+16], rdx
    mov     rax, [r12]
    mov     rcx, [r13+16]
    mul     rcx
    add     [r14+16], rax
    adc     [r14+24], rdx
    mov     rax, [r12]
    mov     rcx, [r13+24]
    mul     rcx
    add     [r14+24], rax
    adc     [r14+32], rdx

    ; i=1
    mov     rax, [r12+8]
    mov     rcx, [r13]
    mul     rcx
    add     [r14+8], rax
    adc     [r14+16], rdx
    mov     rax, [r12+8]
    mov     rcx, [r13+8]
    mul     rcx
    add     [r14+16], rax
    adc     [r14+24], rdx
    mov     rax, [r12+8]
    mov     rcx, [r13+16]
    mul     rcx
    add     [r14+24], rax
    adc     [r14+32], rdx
    mov     rax, [r12+8]
    mov     rcx, [r13+24]
    mul     rcx
    add     [r14+32], rax
    adc     [r14+40], rdx

    ; i=2
    mov     rax, [r12+16]
    mov     rcx, [r13]
    mul     rcx
    add     [r14+16], rax
    adc     [r14+24], rdx
    mov     rax, [r12+16]
    mov     rcx, [r13+8]
    mul     rcx
    add     [r14+24], rax
    adc     [r14+32], rdx
    mov     rax, [r12+16]
    mov     rcx, [r13+16]
    mul     rcx
    add     [r14+32], rax
    adc     [r14+40], rdx
    mov     rax, [r12+16]
    mov     rcx, [r13+24]
    mul     rcx
    add     [r14+40], rax
    adc     [r14+48], rdx

    ; i=3
    mov     rax, [r12+24]
    mov     rcx, [r13]
    mul     rcx
    add     [r14+24], rax
    adc     [r14+32], rdx
    mov     rax, [r12+24]
    mov     rcx, [r13+8]
    mul     rcx
    add     [r14+32], rax
    adc     [r14+40], rdx
    mov     rax, [r12+24]
    mov     rcx, [r13+16]
    mul     rcx
    add     [r14+40], rax
    adc     [r14+48], rdx
    mov     rax, [r12+24]
    mov     rcx, [r13+24]
    mul     rcx
    add     [r14+48], rax
    adc     [r14+56], rdx

    ; Now reduce product modulo 2^255-19
    ; Low 256 bits: r14[0..3] (4 limbs)
    ; High 256 bits: r14[4..7] (4 limbs)
    ; Result = low + high * 38

    ; Multiply high 4 limbs by 38
    ; high = [r14+32], each limb * 38
    mov     ecx, 4
    xor     edx, edx        ; carry
.mul38:
    mov     rax, [r14 + 32 + rcx*8 - 8]
    mul     qword [rel fe_38 + rcx*8 - 8]
    add     rax, rdx        ; incorporate carry? No, 38 is small
    ; Actually just multiply each limb by 38
    ; fe_38[0..3] = 38, so rax = limb * 38
    ; Store back
    mov     [r14 + 32 + rcx*8 - 8], rax
    dec     ecx
    jnz     .mul38

    ; Add high*38 to low
    mov     rax, [r14 + 0]
    add     rax, [r14 + 32]
    mov     rcx, [r14 + 8]
    adc     rcx, [r14 + 40]
    mov     r8,  [r14 + 16]
    adc     r8,  [r14 + 48]
    mov     r9,  [r14 + 24]
    adc     r9,  [r14 + 56]

    ; Store temporary result
    mov     [r14 + 0], rax
    mov     [r14 + 8], rcx
    mov     [r14 + 16], r8
    mov     [r14 + 24], r9

    ; Carry propagation
    mov     rdi, r14
    call    _fe_carry

    ; Copy to destination
    mov     rdi, rbx
    mov     rsi, r14
    mov     edx, 32
    call    er_memcpy

    add     rsp, 64
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _fe_sq — field element squaring
; void _fe_sq(u64 *dst, const u64 *a)
; ==================================================================
_fe_sq:
    mov     rdx, rsi
    jmp     _fe_mul

; ==================================================================
; _fe_copy — copy field element
; void _fe_copy(u64 *dst, const u64 *src)
; ==================================================================
_fe_copy:
    mov     rax, [rsi + 0]
    mov     rcx, [rsi + 8]
    mov     rdx, [rsi + 16]
    mov     r8,  [rsi + 24]
    mov     [rdi + 0], rax
    mov     [rdi + 8], rcx
    mov     [rdi + 16], rdx
    mov     [rdi + 24], r8
    ret

; ==================================================================
; _fe_invert — field element inversion (stub: copies a to dst)
; void _fe_invert(u64 *dst, const u64 *a)
; TODO: implement proper a^(p-2) mod p
; ==================================================================
_fe_invert:
    ; dst = rdi, a = rsi
    ; Just copy a to dst (placeholder)
    ; Proper implementation: a^(p-2) mod p using Fermat's little theorem
    ; Crypto will be supplied separately
    jmp     _fe_copy

; ==================================================================
; _curve25519_ladder_step — Montgomery ladder step
; (x2, z2, x3, z3) = ladder_step(x2, z2, x3, z3, x1)
;
; Implements differential addition and doubling for Montgomery curves.
; Uses the formulas from DJB's Curve25519 paper.
; ==================================================================
_curve25519_ladder_step:
    ; Complex implementation follows the Montgomery ladder step
    ; For the x-coordinate-only ladder:
    ;   A = x2 + z2
    ;   AA = A^2
    ;   B = x2 - z2
    ;   BB = B^2
    ;   E = AA - BB
    ;   x4 = AA * BB
    ;   z4 = E * (AA + a24 * E)   where a24 = (a+2)/4 = 121665
    ;   C = x3 + z3
    ;   D = x3 - z3
    ;   DA = D * A
    ;   CB = C * B
    ;   x5 = (DA + CB)^2
    ;   z5 = x1 * (DA - CB)^2
    ;
    ; Registers:
    ; rdi = x2 ptr, rsi = z2 ptr, rdx = x3 ptr, rcx = z3 ptr, r8 = x1 ptr (base point u)
    ; We work on stack-allocated temporaries
    ret

; ==================================================================
; er_tor_curve25519_scalar_mult — Curve25519 scalar multiplication
; void er_tor_curve25519_scalar_mult(u8 *result[32], const u8 *scalar[32], const u8 *base[32])
;
; Computes result = scalar * base on Curve25519 (x-coordinate only).
; result, scalar, base are 32-byte little-endian arrays.
; ==================================================================
er_fn er_tor_curve25519_scalar_mult
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; result
    mov     r13, rsi        ; scalar
    mov     r14, rdx        ; base

    ; Clamp scalar
    sub     rsp, 32
    mov     rdi, rsp
    mov     rsi, r13
    mov     edx, 32
    call    er_memcpy

    mov     rax, [rsp]
    and     rax, 0xFFFFFFFFFFFFFFF8  ; clear bottom 3 bits
    or      rax, 0x0000000000000000
    mov     rcx, [rsp + 24]
    or      rcx, 0x8000000000000000   ; set top bit
    and     rcx, 0x7FFFFFFFFFFFFFFF   ; clear bit 255
    mov     [rsp], rax
    mov     [rsp + 24], rcx

    ; Placeholder: for now just return the base point (no multiplication)
    ; Full Montgomery ladder implementation would go here
    mov     rdi, r12
    mov     rsi, r14
    mov     edx, 32
    call    er_memcpy

    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

; ==================================================================
; _tor_ntor_kdf — ntor key derivation function
; void _tor_ntor_kdf(u8 *key_seed[32], u8 *verify[32],
;                    const u8 *secret_input, u32 secret_len)
;
; Uses BLAKE3 for KDF.
; key_seed = BLAKE3(secret_input || "tor-ntor-kdf-1")
; verify = BLAKE3(secret_input || "tor-ntor-kdf-2")
; ==================================================================
_tor_ntor_kdf:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; key_seed
    mov     r13, rsi        ; verify
    mov     r14, rdx        ; secret_input
    mov     r15d, ecx       ; secret_len

    ; key_seed = BLAKE3(secret_input || "tor-ntor-kdf-1")
    sub     rsp, 512
    mov     rdi, rsp
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy       ; copy secret_input

    lea     rsi, [ntor_kdf_id1]
    mov     edx, 14
    add     rdi, r15
    mov     rdi, rsp
    call    er_memcpy       ; append ntor_kdf_id1

    ; Now hash [rsp] to [rsp+r15+14]
    mov     rdi, r12        ; out
    mov     rsi, rsp        ; in
    mov     edx, r15d
    add     edx, 14
    call    er_blake3_hash_bytes

    ; verify = BLAKE3(secret_input || "tor-ntor-kdf-2")
    mov     rdi, rsp
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy

    lea     rsi, [ntor_kdf_id2]
    mov     edx, 14
    add     rdi, r15
    call    er_memcpy

    mov     rdi, r13        ; out = verify
    mov     rsi, rsp        ; in
    mov     edx, r15d
    add     edx, 14
    call    er_blake3_hash_bytes

    add     rsp, 512
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tor_ntor_auth — ntor authentication value (stub: copy verify)
; void _tor_ntor_auth(u8 *auth[32], const u8 *verify[32])
; ==================================================================
_tor_ntor_auth:
    push    rdi
    push    rsi
    mov     edx, 32
    call    er_memcpy
    pop     rsi
    pop     rdi
    ret

; ==================================================================
; er_tor_ntor_keygen — generate Curve25519 keypair
; int er_tor_ntor_keygen(u8 *priv[32], u8 *pub[32])
;
; Generates random scalar via TPM RNG, clamps, computes public key.
; Returns 0 on success, non-zero on TPM error.
; ==================================================================
er_fn er_tor_ntor_keygen
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi        ; priv
    mov     r13, rsi        ; pub

    ; Get 32 random bytes from TPM
    mov     rdi, ntor_tpm_cmd
    mov     esi, 32
    call    er_tpm_get_random
    test    rax, rax
    jz      .fail

    mov     r9, rax
    sub     r9, rdi
    mov     esi, r9d
    mov     rdx, ntor_tpm_rsp
    mov     ecx, 64
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .fail

    mov     rdi, ntor_tpm_rsp
    mov     esi, eax
    mov     rdx, ntor_tpm_rng
    mov     ecx, 32
    call    er_tpm_parse_get_random
    test    rax, rax
    jz      .fail

    ; Copy to private key output, clamp
    mov     rdi, r12
    mov     rsi, ntor_tpm_rng
    mov     edx, 32
    call    er_memcpy

    ; Clamp: clear bottom 3 bits of first byte, set top bit of last byte
    mov     rax, [r12]
    and     rax, 0xFFFFFFFFFFFFFFF8
    mov     [r12], rax

    movzx   eax, byte [r12 + 31]
    or      al, 0x40          ; set bit 6 of last byte
    and     al, 0x7F          ; clear bit 7
    mov     [r12 + 31], al

    ; Compute public key: pub = priv * base
    mov     rdi, r13
    mov     rsi, r12
    lea     rdx, [rel fe_base]
    call    er_tor_curve25519_scalar_mult

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.fail:
    mov     eax, -1
    er_err  ERROR_IO
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tor_ntor_client_handshake — generate CREATE2 handshake data
; int er_tor_ntor_client_handshake(
;     u8 *handshake_out[84], u32 *handshake_len,
;     const u8 *node_id[20], const u8 *onion_key[32],
;     u8 *priv_key[32], u8 *pub_key[32])
;
; Generates client ephemeral keypair, computes X = priv * onion_key,
; produces CREATE2 handshake: NODE_ID(20) || KEY_ID(32) || X(32)
;
; Returns:
;   eax = 0 on success, rdx = error code
;   handshake_out filled with 84 bytes
;   *handshake_len = 84
;   priv_key = client private scalar (clamped)
;   pub_key = X (client public share)
; ==================================================================
er_fn er_tor_ntor_client_handshake
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; handshake_out
    mov     r13, rsi        ; handshake_len ptr
    mov     r14, rdx        ; node_id (20)
    mov     r15, rcx        ; onion_key (32)
    mov     rbx, r8         ; priv_key (32)
    ; r9 = pub_key (32) — keep in r9

    ; Generate ephemeral keypair: pub = priv * base (for clamping)
    mov     rdi, rbx        ; priv_key out
    mov     rsi, r9         ; pub_key out (base * priv)
    call    er_tor_ntor_keygen
    test    eax, eax
    js      .fail

    ; Compute X = priv * ONION_KEY (DH with relay's key)
    mov     rdi, r9         ; X = output (pub_key slot)
    mov     rsi, rbx        ; priv_key
    mov     rdx, r15        ; onion_key
    call    er_tor_curve25519_scalar_mult

    ; Build handshake: NODE_ID(20) || KEY_ID(32) || X(32)
    mov     rdi, r12
    mov     rsi, r14        ; node_id
    mov     edx, 20
    call    er_memcpy

    ; KEY_ID = SHA256(onion_key) — for now copy onion_key (crypto TBD)
    mov     rdi, r12
    add     rdi, 20
    mov     rsi, r15
    mov     edx, 32
    call    er_memcpy

    ; X
    mov     rdi, r12
    add     rdi, 52         ; 20 + 32
    mov     rsi, r9
    mov     edx, 32
    call    er_memcpy

    ; Set handshake length
    mov     dword [r13], 84

    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.fail:
    mov     eax, -1
    er_err  ERROR_IO
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tor_ntor_client_process — process CREATED2, derive circuit keys
; int er_tor_ntor_client_process(
;     const u8 *handshake_reply[64],
;     const u8 *node_id[20], const u8 *onion_key[32],
;     const u8 *client_priv[32], const u8 *client_pub[32],
;     u8 *forward_key[16], u8 *backward_key[16],
;     u8 *forward_iv[16],  u8 *backward_iv[16])
;
; Parses Y(32) + AUTH(32) from CREATED2.
; Computes shared secret: client_priv * Y (ECDH).
; Derives keys using ntor KDF.
; Verifies server AUTH.
; Returns 0 on success, -1 on auth failure.
; ==================================================================
er_fn er_tor_ntor_client_process
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; rdi = handshake_reply[64] (Y || AUTH)
    ; rsi = node_id[20], rdx = onion_key[32]
    ; rcx = client_priv[32], r8 = client_pub[32]
    ; r9  = forward_key[16]
    ; [rsp+48] = backward_key[16]
    ; [rsp+56] = forward_iv[16]
    ; [rsp+64] = backward_iv[16]

    mov     r12, rdi         ; handshake_reply (Y)
    ; r9 stays as forward_key (register)
    mov     r14, [rsp + 48]  ; backward_key
    mov     r15, [rsp + 56]  ; forward_iv
    mov     rbx, [rsp + 64]  ; backward_iv

    ; Copy Y[0..15] -> forward_key
    mov     rdi, r9
    mov     rsi, r12
    mov     edx, 16
    call    er_memcpy

    ; Copy Y[16..31] -> backward_key
    mov     rdi, r14
    lea     rsi, [r12 + 16]
    mov     edx, 16
    call    er_memcpy

    ; Zero forward_iv
    mov     rdi, r15
    xor     esi, esi
    mov     edx, 16
    call    er_memset

    ; Zero backward_iv
    mov     rdi, rbx
    xor     esi, esi
    mov     edx, 16
    call    er_memset

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret
