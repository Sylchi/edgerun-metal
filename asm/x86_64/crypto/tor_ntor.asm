; EdgeRun Tor ntor key agreement — x86_64 assembly
; Curve25519 scalar multiplication + ntor handshake protocol.
;
; Uses BLAKE3 for hashing and TPM for random number generation.
; Field elements are 4 x u64 limbs (radix-2^64), little-endian.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_memcpy
extern er_memcmp
extern er_memset
extern er_tpm_get_random
extern er_tpm_crb_transfer
extern er_tpm_parse_get_random
extern er_tor_sha256
extern er_tor_hmac_sha256

; Export internal symbols for test access
GLOBAL _fe_invert
GLOBAL _fe_mul
GLOBAL _fe_copy
GLOBAL fe_base
GLOBAL fe_one
GLOBAL fe_tmp0
GLOBAL fe_tmp1
GLOBAL fe_tmp2
GLOBAL fe_tmp3
GLOBAL fe_tmp4

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

; a24 = (A+2)/4 = (486662+2)/4 = 121666 for Curve25519 Montgomery ladder
fe_a24: dq 121666, 0, 0, 0

; Identity string for ntor KDF
ntor_kdf_id1: db "tor-ntor-kdf-1"
ntor_kdf_id2: db "tor-ntor-kdf-2"
ntor_auth_id: db "tor-ntor-auth-1"
ntor_protoid: db "ntor-curve25519-sha256-1"
ntor_protoid_len: equ $ - ntor_protoid
ntor_server_str: db "Server"
ntor_server_str_len: equ $ - ntor_server_str

SECTION .bss

; Temporary buffers for field arithmetic
fe_tmp0: resq 4
fe_tmp1: resq 4
fe_tmp2: resq 4
fe_tmp3: resq 4
fe_tmp4: resq 4
fe_prod: resq 8  ; 512-bit product of 256-bit multiplication

; TPM buffers for random
ntor_tpm_cmd: resb 64
ntor_tpm_rsp: resb 64
ntor_tpm_rng: resb 32

; ntor work buffer for building secret_input and key material
ntor_work_buf: resb 1024

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

    ; Multiply high 4 limbs by 38, accumulating overflow
    mov     ecx, 4
    xor     r15d, r15d      ; accumulated overflow from mul38
.mul38:
    mov     rax, [r14 + 32 + rcx*8 - 8]
    mul     qword [rel fe_38 + rcx*8 - 8]   ; rdx:rax = limb * 38
    add     rax, r15                         ; add previous overflow
    mov     r15, rdx                         ; save new overflow (mul hi)
    adc     r15, 0                           ; propagate carry from add
    mov     [r14 + 32 + rcx*8 - 8], rax
    dec     ecx
    jnz     .mul38

    ; Add mod-reduced high*38 to low (4-limb carry chain)
    mov     rax, [r14 + 0]
    add     rax, [r14 + 32]
    mov     rcx, [r14 + 8]
    adc     rcx, [r14 + 40]
    mov     r8,  [r14 + 16]
    adc     r8,  [r14 + 48]
    mov     r9,  [r14 + 24]
    adc     r9,  [r14 + 56]     ; carry3 from last adc

    ; Combine r15 (mul38 final overflow) with carry from last adc
    ; r15 represents bits at position 256; 2^256 ≡ 38 (mod 2^255-19)
    adc     r15, 0              ; r15 += carry3

    ; Multiply by 38 for 2^256 wrap-around (fits in < 2^64)
    mov     rdi, r15
    imul    rdi, rdi, 38

    ; Add overflow to result limbs
    add     rax, rdi
    mov     [r14 + 0], rax
    adc     rcx, 0
    mov     [r14 + 8], rcx
    adc     r8,  0
    mov     [r14 + 16], r8
    adc     r9,  0
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
; _fe_invert — field element inversion via a^(p-2) mod p
; void _fe_invert(u64 *dst, const u64 *a)
; Uses Fermat's little theorem with binary exponentiation.
; p = 2^255 - 19, so exponent e = p - 2 = 2^255 - 21.
; 254 sq + 252 mul = 506 field ops.
; ==================================================================
_fe_invert:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; r12 = dst
    mov     r13, rsi        ; r13 = a

    ; Copy input a to fe_tmp1 (preserved as multiplier throughout)
    mov     rdi, fe_tmp1
    mov     rsi, r13
    call    _fe_copy
    ; Carry the input copy for safety
    mov     rdi, fe_tmp1
    call    _fe_carry

    ; Initialize result = 1 in fe_tmp0
    mov     rdi, fe_tmp0
    lea     rsi, [rel fe_one]
    call    _fe_copy

    ; Binary exponentiation: square and multiply
    ; Exponent bits 254..0; e = 2^255 - 21
    ; Zero bits at positions 2 and 4 only — skip multiply for those
    mov     r14d, 254

.loop:
    ; result = result^2
    mov     rdi, fe_tmp0
    mov     rsi, fe_tmp0
    call    _fe_sq

    ; Skip multiply for zero bits of exponent
    cmp     r14d, 2
    je      .next
    cmp     r14d, 4
    je      .next

    ; result = result * a
    mov     rdi, fe_tmp0
    mov     rsi, fe_tmp0
    mov     rdx, fe_tmp1
    call    _fe_mul

.next:
    dec     r14d
    jns     .loop

    ; Copy result to dst
    mov     rdi, r12
    mov     rsi, fe_tmp0
    call    _fe_copy

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _curve25519_ladder_step — Montgomery ladder step
; (x2, z2, x3, z3) = ladder_step(x2, z2, x3, z3, x1)
;
; Implements differential addition and doubling for Montgomery curves.
; Formulas (DJB Curve25519 paper):
;   A   = x2 + z2    ; AA = A^2
;   B   = x2 - z2    ; BB = B^2
;   E   = AA - BB
;   x2' = AA * BB
;   z2' = E * (BB + a24 * E)   a24 = (A+2)/4 = 121666
;   C   = x3 + z3    ; D = x3 - z3
;   DA  = D * A      ; CB = C * B
;   x3' = (DA + CB)^2
;   z3' = x1 * (DA - CB)^2
;
; Registers (caller-saved): rdi=x2, rsi=z2, rdx=x3, rcx=z3, r8=x1
; ==================================================================
_curve25519_ladder_step:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; Save pointer args in callee-saved regs
    mov     r12, rdi        ; x2
    mov     r13, rsi        ; z2
    mov     r14, rdx        ; x3
    mov     r15, rcx        ; z3
    mov     rbx, r8         ; x1

    ; Allocate stack temps: 10 field elements × 32 bytes = 320 bytes
    sub     rsp, 320
    ; Offset defines:
    ; 0:   A        32: B       64: C       96:  D
    ; 128: AA       160: BB     192: E      224: DA
    ; 256: CB       288: scratch

    ; 1. A = x2 + z2
    mov     rdi, rsp
    mov     rsi, r12
    mov     rdx, r13
    call    _fe_add

    ; 2. B = x2 - z2
    lea     rdi, [rsp + 32]
    mov     rsi, r12
    mov     rdx, r13
    call    _fe_sub

    ; 3. C = x3 + z3
    lea     rdi, [rsp + 64]
    mov     rsi, r14
    mov     rdx, r15
    call    _fe_add

    ; 4. D = x3 - z3
    lea     rdi, [rsp + 96]
    mov     rsi, r14
    mov     rdx, r15
    call    _fe_sub

    ; 5. AA = A^2
    lea     rdi, [rsp + 128]
    mov     rsi, rsp
    call    _fe_sq

    ; 6. BB = B^2
    lea     rdi, [rsp + 160]
    lea     rsi, [rsp + 32]
    call    _fe_sq

    ; 7. E = AA - BB
    lea     rdi, [rsp + 192]
    lea     rsi, [rsp + 128]
    lea     rdx, [rsp + 160]
    call    _fe_sub

    ; 8. x2 = AA * BB
    mov     rdi, r12
    lea     rsi, [rsp + 128]
    lea     rdx, [rsp + 160]
    call    _fe_mul

    ; 9. z2 = E * (BB + a24 * E)
    ; scratch = a24 * E
    lea     rdi, [rsp + 288]
    lea     rsi, [rel fe_a24]
    lea     rdx, [rsp + 192]
    call    _fe_mul
    ; AA slot = BB + scratch (BB no longer needed as BB alone)
    lea     rdi, [rsp + 128]
    lea     rsi, [rsp + 160]
    lea     rdx, [rsp + 288]
    call    _fe_add
    ; z2 = E * (BB + a24*E)
    mov     rdi, r13
    lea     rsi, [rsp + 192]
    lea     rdx, [rsp + 128]
    call    _fe_mul

    ; 10. DA = D * A
    lea     rdi, [rsp + 224]
    lea     rsi, [rsp + 96]
    mov     rdx, rsp
    call    _fe_mul

    ; 11. CB = C * B
    lea     rdi, [rsp + 256]
    lea     rsi, [rsp + 64]
    lea     rdx, [rsp + 32]
    call    _fe_mul

    ; 12. x3 = (DA + CB)^2
    lea     rdi, [rsp + 288]
    lea     rsi, [rsp + 224]
    lea     rdx, [rsp + 256]
    call    _fe_add
    mov     rdi, r14
    lea     rsi, [rsp + 288]
    call    _fe_sq

    ; 13. z3 = x1 * (DA - CB)^2
    lea     rdi, [rsp + 288]
    lea     rsi, [rsp + 224]
    lea     rdx, [rsp + 256]
    call    _fe_sub
    lea     rdi, [rsp + 288]
    lea     rsi, [rsp + 288]
    call    _fe_sq
    mov     rdi, r15
    mov     rsi, rbx
    lea     rdx, [rsp + 288]
    call    _fe_mul

    add     rsp, 320
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
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

    ; Clamp scalar on stack
    sub     rsp, 32
    mov     rdi, rsp
    mov     rsi, r13
    mov     edx, 32
    call    er_memcpy

    ; byte 0: clear bottom 3 bits
    mov     rax, [rsp]
    and     rax, 0xFFFFFFFFFFFFFFF8
    mov     [rsp], rax

    ; byte 31 (in u64 at [rsp+24]): clear bit 255, set bit 254
    mov     rax, [rsp + 24]
    and     rax, 0x7FFFFFFFFFFFFFFF
    or      rax, 0x4000000000000000
    mov     [rsp + 24], rax

    ; Initialize ladder state in BSS temps
    ; x2 = 1
    mov     rdi, fe_tmp0
    lea     rsi, [rel fe_one]
    call    _fe_copy

    ; z2 = 0
    mov     rdi, fe_tmp1
    lea     rsi, [rel fe_zero]
    call    _fe_copy

    ; x3 = base (same memory layout: u8[32] ≡ u64[4] LE)
    mov     rdi, fe_tmp2
    mov     rsi, r14
    call    _fe_copy

    ; z3 = 1
    mov     rdi, fe_tmp3
    lea     rsi, [rel fe_one]
    call    _fe_copy

    ; Save base pointer
    mov     rbx, r14

    ; Montgomery ladder: bits 254 down to 0
    mov     r15d, 254

.loop:
    ; Compute bit = (clamped[byte_idx] >> bit_idx) & 1
    mov     ecx, r15d
    shr     ecx, 3
    mov     edx, r15d
    and     edx, 7

    movzx   eax, byte [rsp + rcx]
    bt      eax, edx
    jc      .bit_set

    ; bit = 0: ladder_step(x3, z3, x2, z2, base)
    mov     rdi, fe_tmp2
    mov     rsi, fe_tmp3
    mov     rdx, fe_tmp0
    mov     rcx, fe_tmp1
    mov     r8,  rbx
    call    _curve25519_ladder_step
    jmp     .next

.bit_set:
    ; bit = 1: ladder_step(x2, z2, x3, z3, base)
    mov     rdi, fe_tmp0
    mov     rsi, fe_tmp1
    mov     rdx, fe_tmp2
    mov     rcx, fe_tmp3
    mov     r8,  rbx
    call    _curve25519_ladder_step

.next:
    dec     r15d
    jns     .loop

    ; result = x2 * z2^(-1) mod p
    ; Invert z2 (fe_tmp1) in place
    mov     rdi, fe_tmp1
    mov     rsi, fe_tmp1
    call    _fe_invert

    ; x2 = x2 * z2_inv
    mov     rdi, fe_tmp0
    mov     rsi, fe_tmp0
    mov     rdx, fe_tmp1
    call    _fe_mul

    ; Copy result to output
    mov     rdi, r12
    mov     rsi, fe_tmp0
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
; Uses HMAC-SHA256 via TPM.
; key_seed = HMAC-SHA256(secret_input, "tor-ntor-kdf-1")
; verify = HMAC-SHA256(secret_input, "tor-ntor-kdf-2")
; ==================================================================
_tor_ntor_kdf:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; key_seed
    mov     r13, rsi        ; verify
    mov     r14, rdx        ; secret_input
    mov     r15d, ecx       ; secret_len

    ; key_seed = HMAC-SHA256(secret_input, "tor-ntor-kdf-1")
    mov     rdi, r14        ; key = secret_input
    mov     esi, r15d       ; key_len
    lea     rdx, [rel ntor_kdf_id1] ; msg = "tor-ntor-kdf-1"
    mov     ecx, 14         ; msg_len
    mov     r8, r12         ; out = key_seed
    call    er_tor_hmac_sha256
    test    eax, eax
    jz      .err

    ; verify = HMAC-SHA256(secret_input, "tor-ntor-kdf-2")
    mov     rdi, r14        ; key = secret_input
    mov     esi, r15d       ; key_len
    lea     rdx, [rel ntor_kdf_id2] ; msg = "tor-ntor-kdf-2"
    mov     ecx, 14         ; msg_len
    mov     r8, r13         ; out = verify
    call    er_tor_hmac_sha256
    test    eax, eax
    jz      .err

    mov     eax, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.err:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tor_ntor_auth — compute ntor server authentication value
; int _tor_ntor_auth(u8 *auth[32], const u8 *verify[32],
;    const u8 *node_id[20], const u8 *onion_key[32],
;    const u8 *y[32], const u8 *client_pub[32])
;
; auth_input = verify(32) || node_id(20) || onion_key(32)
;              || y(32) || client_pub(32) || PROTOID(24) || "Server"(6)
; AUTH = HMAC-SHA256(auth_input, "tor-ntor-auth-1")
;
; Returns 0 on success, non-zero on TPM error.
; ==================================================================
_tor_ntor_auth:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; auth
    mov     r13, rsi        ; verify
    mov     r14, rdx        ; node_id
    mov     rbx, rcx        ; onion_key
    ; r8 = y
    ; r9 = client_pub

    ; Build auth_input at ntor_work_buf:
    mov     rdi, ntor_work_buf
    mov     rsi, r13        ; verify (32)
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 32
    mov     rsi, r14        ; node_id (20)
    mov     edx, 20
    call    er_memcpy

    mov     rdi, ntor_work_buf + 52
    mov     rsi, rbx        ; onion_key (32)
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 84
    mov     rsi, r8         ; y (32)
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 116
    mov     rsi, r9         ; client_pub (32)
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 148
    lea     rsi, [rel ntor_protoid]  ; PROTOID (24)
    mov     edx, ntor_protoid_len
    call    er_memcpy

    mov     rdi, ntor_work_buf + 172
    lea     rsi, [rel ntor_server_str]  ; "Server" (6)
    mov     edx, ntor_server_str_len
    call    er_memcpy

    ; auth_input = 32+20+32+32+32+24+6 = 178 bytes
    mov     rdi, ntor_work_buf      ; key = auth_input
    mov     esi, 178                ; key_len
    lea     rdx, [rel ntor_auth_id] ; msg = "tor-ntor-auth-1"
    mov     ecx, 14                 ; msg_len
    mov     r8, r12                 ; out = auth
    call    er_tor_hmac_sha256
    test    eax, eax
    jz      .err

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.err:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
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

    ; KEY_ID = SHA256(onion_key)
    mov     rdi, r15        ; data = onion_key
    mov     esi, 32
    mov     rdx, ntor_work_buf ; temp output
    call    er_tor_sha256
    test    eax, eax
    jz      .fail

    mov     rdi, r12
    add     rdi, 20
    mov     rsi, ntor_work_buf
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
; Computes secret_input = EXP(Y,x) | EXP(B,x) | ID | B | X | Y | PROTOID
; Derives key_seed and verify via HMAC-SHA256.
; Verifies server AUTH via HMAC-SHA256.
; Expands key_seed to forward/backward keys + IVs.
; Returns 0 on success, -1 on error.
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

    mov     r12, rdi        ; handshake_reply (Y)
    mov     r13, rsi        ; node_id
    mov     r14, rdx        ; onion_key
    mov     r15, rcx        ; client_priv
    mov     rbx, r8         ; client_pub
    ; r9 = forward_key (register)

    ; Load stack params into r10, r11, and a register for backward_iv
    mov     r10, [rsp + 48] ; backward_key
    mov     r11, [rsp + 56] ; forward_iv

    ; ============================================================
    ; Step 1: Compute EXP(Y, x) = ECDH(client_priv, Y)
    ; ============================================================
    mov     rdi, ntor_work_buf       ; output = EXP(Y,x) at [0..31]
    mov     rsi, r15                 ; client_priv
    mov     rdx, r12                 ; Y (handshake_reply)
    call    er_tor_curve25519_scalar_mult

    ; ============================================================
    ; Step 2: Build secret_input at ntor_work_buf
    ; Layout (204 bytes):
    ;   [0..31]:   EXP(Y,x)             — already written
    ;   [32..63]:  client_pub (EXP(B,x))
    ;   [64..83]:  node_id
    ;   [84..115]: onion_key
    ;   [116..147]: client_pub
    ;   [148..179]: Y
    ;   [180..203]: PROTOID
    ; ============================================================
    mov     rdi, ntor_work_buf + 32
    mov     rsi, rbx
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 64
    mov     rsi, r13
    mov     edx, 20
    call    er_memcpy

    mov     rdi, ntor_work_buf + 84
    mov     rsi, r14
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 116
    mov     rsi, rbx
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 148
    mov     rsi, r12                 ; Y (handshake_reply start)
    mov     edx, 32
    call    er_memcpy

    mov     rdi, ntor_work_buf + 180
    lea     rsi, [rel ntor_protoid]
    mov     edx, ntor_protoid_len
    call    er_memcpy

    ; ============================================================
    ; Step 3: key_seed = HMAC-SHA256(secret_input, "tor-ntor-kdf-1")
    ; Store at ntor_work_buf[256..287]
    ; ============================================================
    mov     rdi, ntor_work_buf       ; key = secret_input
    mov     esi, 204
    lea     rdx, [rel ntor_kdf_id1] ; msg
    mov     ecx, 14
    mov     r8, ntor_work_buf + 256  ; out = key_seed
    call    er_tor_hmac_sha256
    test    eax, eax
    jz      .err

    ; ============================================================
    ; Step 4: verify = HMAC-SHA256(secret_input, "tor-ntor-kdf-2")
    ; Store at ntor_work_buf[288..319]
    ; ============================================================
    mov     rdi, ntor_work_buf       ; key = secret_input
    mov     esi, 204
    lea     rdx, [rel ntor_kdf_id2] ; msg
    mov     ecx, 14
    mov     r8, ntor_work_buf + 288  ; out = verify
    call    er_tor_hmac_sha256
    test    eax, eax
    jz      .err

    ; ============================================================
    ; Step 5: Compute expected server AUTH
    ; _tor_ntor_auth(out, verify, node_id, onion_key, y, client_pub)
    ; out = ntor_work_buf[320..351]
    ; ============================================================
    mov     rdi, ntor_work_buf + 320 ; auth out
    mov     rsi, ntor_work_buf + 288 ; verify
    mov     rdx, r13                ; node_id
    mov     rcx, r14                ; onion_key
    mov     r8, r12                 ; y (handshake_reply)
    mov     r9, rbx                 ; client_pub
    call    _tor_ntor_auth
    test    eax, eax
    js      .err

    ; ============================================================
    ; Step 6: Compare expected_AUTH with server_AUTH (constant-time)
    ; server_AUTH = handshake_reply[32..63] = [r12 + 32]
    ; ============================================================
    mov     rdi, ntor_work_buf + 320 ; expected
    lea     rsi, [r12 + 32]         ; server_AUTH
    mov     edx, 32
    call    er_memcmp
    test    eax, eax
    jnz     .auth_fail

    ; ============================================================
    ; Step 7: Derive forward_key, backward_key from key_seed
    ; K0 = SHA256(key_seed(32) || 0x00)  → forward_key[16] + backward_key[16]
    ; ============================================================
    mov     rdi, ntor_work_buf + 400
    mov     rsi, ntor_work_buf + 256  ; key_seed
    mov     edx, 32
    call    er_memcpy
    mov     byte [ntor_work_buf + 432], 0x00

    mov     rdi, ntor_work_buf + 400  ; data = key_seed || 0x00
    mov     esi, 33
    mov     rdx, ntor_work_buf + 352  ; K0 output
    call    er_tor_sha256
    test    eax, eax
    jz      .err

    ; forward_key = K0[0..15]
    mov     rdi, r9                  ; forward_key
    mov     rsi, ntor_work_buf + 352
    mov     edx, 16
    call    er_memcpy

    ; backward_key = K0[16..31]
    mov     rdi, r10                 ; backward_key (from stack)
    lea     rsi, [ntor_work_buf + 368]
    mov     edx, 16
    call    er_memcpy

    ; ============================================================
    ; Step 8: Derive forward_iv, backward_iv from key_seed
    ; K1 = SHA256(key_seed(32) || 0x01)  → forward_iv[16] + backward_iv[16]
    ; ============================================================
    mov     byte [ntor_work_buf + 432], 0x01

    mov     rdi, ntor_work_buf + 400  ; data = key_seed || 0x01
    mov     esi, 33
    mov     rdx, ntor_work_buf + 352  ; K1 output (reuse buffer)
    call    er_tor_sha256
    test    eax, eax
    jz      .err

    ; forward_iv = K1[0..15]
    mov     rdi, r11                 ; forward_iv (from stack)
    mov     rsi, ntor_work_buf + 352
    mov     edx, 16
    call    er_memcpy

    ; backward_iv = K1[16..31]
    mov     rdi, [rsp + 64]          ; backward_iv (from stack)
    lea     rsi, [ntor_work_buf + 368]
    mov     edx, 16
    call    er_memcpy

    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.auth_fail:
    mov     eax, -1
    er_err  ERROR_AUTH
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.err:
    mov     eax, -1
    er_err  ERROR_IO
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
