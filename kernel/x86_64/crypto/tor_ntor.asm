; EdgeRun Tor ntor key agreement — x86_64 assembly
; ntor handshake protocol.
;
; Curve25519 field arithmetic provided by curve25519.asm (5×51-bit limbs).
; This file contains the ntor key exchange protocol layer only.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tor_constants.inc"

; Curve25519 field primitives (from curve25519.asm)
extern _fe_copy
extern _fe_mul
extern _fe_sq
extern _fe_invert
extern _curve25519_ladder_step
extern er_tor_curve25519_scalar_mult
extern fe_base
extern fe_one
extern fe_zero
extern fe_tmp0
extern fe_tmp1
extern fe_tmp2
extern fe_tmp3
extern fe_tmp4

extern er_memcpy
extern er_memcmp
extern er_memset
extern er_tpm_get_random
extern er_tpm_crb_transfer
extern er_tpm_parse_get_random
extern er_tor_sha256
extern er_tor_hmac_sha256

; ntor protocol data
SECTION .rodata

ntor_kdf_id1: db "tor-ntor-kdf-1"
ntor_kdf_id2: db "tor-ntor-kdf-2"
ntor_auth_id: db "tor-ntor-auth-1"
ntor_protoid: db "ntor-curve25519-sha256-1"
ntor_protoid_len: equ $ - ntor_protoid
ntor_server_str: db "Server"
ntor_server_str_len: equ $ - ntor_server_str

SECTION .bss

; TPM buffers for random
ntor_tpm_cmd: resb 64
ntor_tpm_rsp: resb 64
ntor_tpm_rng: resb 32

; ntor work buffer
ntor_work_buf: resb 1024

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

    mov     esi, 12             ; TPM_CMD_GET_RANDOM_LEN
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
    and     byte [r12], 0xF8

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
