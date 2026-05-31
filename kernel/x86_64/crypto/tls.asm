; EdgeRun TLS transport — x86_64 assembly
;
; Owns TLS record framing and handshake state. This module intentionally
; fails closed until encrypted record protection is implemented.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tls_constants.inc"

extern er_tcp_send
extern er_tcp_recv
extern er_net_poll
extern er_tpm_get_random
extern er_tpm_crb_transfer
extern er_tpm_parse_get_random
extern er_tor_curve25519_scalar_mult
extern er_tor_hmac_sha256
extern er_tor_sha256
extern er_tor_aes_ctr
extern er_memcpy
extern er_memcmp
extern er_memset

SECTION .rodata

tls_x25519_basepoint:
    db 9
    times 31 db 0
tls_hkdf_label_prefix:
    db "tls13 "
tls_zero_secret:
    times 32 db 0
tls_label_derived:
    db "derived"
tls_label_derived_len equ $ - tls_label_derived
tls_label_client_hs:
    db "c hs traffic"
tls_label_client_hs_len equ $ - tls_label_client_hs
tls_label_server_hs:
    db "s hs traffic"
tls_label_server_hs_len equ $ - tls_label_server_hs
tls_label_key:
    db "key"
tls_label_key_len equ $ - tls_label_key
tls_label_iv:
    db "iv"
tls_label_iv_len equ $ - tls_label_iv

SECTION .bss

tls_state: resd 1
tls_conn_id: resd 1
tls_tpm_cmd: resb 64
tls_tpm_rsp: resb 96
tls_client_hello: resb TLS_CLIENT_HELLO_RECORD_LEN
tls_rx_record: resb TLS_RX_RECORD_MAX
tls_rx_len: resd 1
tls_client_private: resb TLS_X25519_KEY_LEN
tls_client_public: resb TLS_X25519_KEY_LEN
tls_server_public: resb TLS_X25519_KEY_LEN
tls_shared_secret: resb TLS_X25519_KEY_LEN
tls_parse_flags: resd 1
tls_hkdf_out_ptr: resq 1
tls_hkdf_info: resb TLS_HKDF_INFO_MAX_LEN
tls_hkdf_msg: resb TLS_HKDF_INFO_MAX_LEN + 1
tls_transcript: resb TLS_CLIENT_HELLO_PAYLOAD_LEN + TLS_RX_RECORD_MAX
tls_transcript_hash: resb TLS_RANDOM_LEN
tls_empty_hash: resb TLS_RANDOM_LEN
tls_early_secret: resb TLS_RANDOM_LEN
tls_derived_secret: resb TLS_RANDOM_LEN
tls_handshake_secret: resb TLS_RANDOM_LEN
tls_client_hs_traffic_secret: resb TLS_RANDOM_LEN
tls_server_hs_traffic_secret: resb TLS_RANDOM_LEN
tls_client_hs_key: resb 16
tls_server_hs_key: resb 16
tls_client_hs_iv: resb 12
tls_server_hs_iv: resb 12
tls_key_block: resb TLS_RANDOM_LEN
tls_gcm_h: resb TLS_GCM_BLOCK_LEN
tls_gcm_y: resb TLS_GCM_BLOCK_LEN
tls_gcm_x: resb TLS_GCM_BLOCK_LEN
tls_gcm_z: resb TLS_GCM_BLOCK_LEN
tls_gcm_v: resb TLS_GCM_BLOCK_LEN
tls_gcm_block: resb TLS_GCM_BLOCK_LEN
tls_gcm_ctr: resb TLS_GCM_BLOCK_LEN
tls_gcm_tagmask: resb TLS_GCM_BLOCK_LEN
tls_gcm_len_block: resb TLS_GCM_BLOCK_LEN
tls_gcm_calc_tag: resb TLS_GCM_TAG_LEN
tls_gcm_key_ptr: resq 1
tls_gcm_iv_ptr: resq 1
tls_gcm_tag_ptr: resq 1

SECTION .text

; ==================================================================
; er_tls_init — clear TLS transport state
; ==================================================================
global er_tls_init
er_fn er_tls_init
    mov     dword [tls_state], TLS_STATE_CLOSED
    mov     dword [tls_conn_id], -1
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_tls_random32 — fill 32 bytes from TPM GetRandom
; rdi = out[32]
; ==================================================================
global er_tls_random32
er_fn er_tls_random32
    test    rdi, rdi
    jz      .fail
    push    rbx
    mov     rbx, rdi

    mov     rdi, tls_tpm_cmd
    mov     esi, TLS_RANDOM_LEN
    call    er_tpm_get_random
    test    rax, rax
    jz      .fail_pop

    mov     rdi, tls_tpm_cmd
    mov     esi, 12
    mov     rdx, tls_tpm_rsp
    mov     ecx, 96
    call    er_tpm_crb_transfer
    test    eax, eax
    jz      .fail_pop

    mov     rdi, tls_tpm_rsp
    mov     esi, eax
    mov     rdx, rbx
    mov     ecx, TLS_RANDOM_LEN
    call    er_tpm_parse_get_random
    cmp     eax, TLS_RANDOM_LEN
    jne     .fail_pop

    xor     eax, eax
    er_ok
    pop     rbx
    er_ret

.fail_pop:
    pop     rbx
.fail:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    er_ret

; ==================================================================
; er_tls_client_hello_build
; rdi = out buffer, esi = out capacity, rdx = optional priv_out[32]
; returns eax = bytes written, edx = 0 on success
; ==================================================================
global er_tls_client_hello_build
er_fn er_tls_client_hello_build
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx

    test    r12, r12
    jz      .bad_param
    cmp     r13d, TLS_CLIENT_HELLO_RECORD_LEN
    jb      .bad_param

    ; Generate client random, session id, and X25519 private key.
    lea     rdi, [tls_client_hello + TLS_RECORD_HEADER_LEN + TLS_HANDSHAKE_HEADER_LEN + 2]
    call    er_tls_random32
    test    eax, eax
    js      .fail

    lea     rdi, [tls_client_hello + TLS_RECORD_HEADER_LEN + TLS_HANDSHAKE_HEADER_LEN + 2 + TLS_RANDOM_LEN + 1]
    call    er_tls_random32
    test    eax, eax
    js      .fail

    lea     rdi, [tls_client_private]
    call    er_tls_random32
    test    eax, eax
    js      .fail

    ; Clamp X25519 scalar.
    and     byte [tls_client_private], 0xF8
    and     byte [tls_client_private + 31], 0x7F
    or      byte [tls_client_private + 31], 0x40

    lea     rdi, [tls_client_public]
    lea     rsi, [tls_client_private]
    lea     rdx, [rel tls_x25519_basepoint]
    call    er_tor_curve25519_scalar_mult

    test    r14, r14
    jz      .build
    mov     rdi, r14
    lea     rsi, [tls_client_private]
    mov     edx, TLS_X25519_KEY_LEN
    call    er_memcpy

.build:
    ; Record header.
    mov     byte [tls_client_hello + 0], TLS_RECORD_HANDSHAKE
    mov     byte [tls_client_hello + 1], TLS_RECORD_VERSION_MAJOR
    mov     byte [tls_client_hello + 2], TLS_RECORD_VERSION_COMPAT_MINOR
    mov     byte [tls_client_hello + 3], 0
    mov     byte [tls_client_hello + 4], TLS_CLIENT_HELLO_PAYLOAD_LEN

    ; Handshake header.
    mov     byte [tls_client_hello + 5], TLS_HANDSHAKE_CLIENT_HELLO
    mov     byte [tls_client_hello + 6], 0
    mov     byte [tls_client_hello + 7], 0
    mov     byte [tls_client_hello + 8], TLS_CLIENT_HELLO_BODY_LEN

    ; ClientHello legacy_version.
    mov     byte [tls_client_hello + 9], TLS_RECORD_VERSION_MAJOR
    mov     byte [tls_client_hello + 10], TLS_LEGACY_VERSION_MINOR

    ; Session id length is followed by bytes already filled from TPM.
    mov     byte [tls_client_hello + 43], TLS_SESSION_ID_LEN

    ; Cipher suites: TLS_AES_128_GCM_SHA256 only.
    mov     byte [tls_client_hello + 76], 0
    mov     byte [tls_client_hello + 77], 2
    mov     byte [tls_client_hello + 78], 0x13
    mov     byte [tls_client_hello + 79], 0x01

    ; Legacy compression methods: null only.
    mov     byte [tls_client_hello + 80], 1
    mov     byte [tls_client_hello + 81], 0

    ; Extensions vector.
    mov     byte [tls_client_hello + 82], 0
    mov     byte [tls_client_hello + 83], TLS_CLIENT_EXTENSIONS_LEN
    mov     rbx, tls_client_hello + 84

    ; supported_versions.
    mov     word [rbx], 0x2B00
    mov     word [rbx + 2], 0x0300
    mov     byte [rbx + 4], 2
    mov     word [rbx + 5], 0x0403
    add     rbx, TLS_EXT_SUPPORTED_VERSIONS_LEN

    ; supported_groups: x25519.
    mov     word [rbx], 0x0A00
    mov     word [rbx + 2], 0x0400
    mov     word [rbx + 4], 0x0200
    mov     word [rbx + 6], 0x1D00
    add     rbx, TLS_EXT_SUPPORTED_GROUPS_LEN

    ; signature_algorithms.
    mov     word [rbx], 0x0D00
    mov     word [rbx + 2], 0x0800
    mov     word [rbx + 4], 0x0600
    mov     word [rbx + 6], 0x0304
    mov     word [rbx + 8], 0x0708
    mov     word [rbx + 10], 0x0408
    add     rbx, TLS_EXT_SIGNATURE_ALGORITHMS_LEN

    ; key_share: x25519.
    mov     word [rbx], 0x3300
    mov     word [rbx + 2], 0x2600
    mov     word [rbx + 4], 0x2400
    mov     word [rbx + 6], 0x1D00
    mov     word [rbx + 8], 0x2000
    lea     rdi, [rbx + 10]
    lea     rsi, [tls_client_public]
    mov     edx, TLS_X25519_KEY_LEN
    call    er_memcpy

    mov     rdi, r12
    lea     rsi, [tls_client_hello]
    mov     edx, TLS_CLIENT_HELLO_RECORD_LEN
    call    er_memcpy

    mov     eax, TLS_CLIENT_HELLO_RECORD_LEN
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad_param:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tls_server_hello_parse
; rdi = TLS record, esi = record length, rdx = out key_share[32]
; Returns eax=0 on success.
; ==================================================================
global er_tls_server_hello_parse
er_fn er_tls_server_hello_parse
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx

    test    r12, r12
    jz      .bad_record
    test    r14, r14
    jz      .bad_record
    cmp     r13d, TLS_RECORD_HEADER_LEN + TLS_HANDSHAKE_HEADER_LEN + 38
    jb      .bad_record

    cmp     byte [r12], TLS_RECORD_HANDSHAKE
    jne     .bad_record
    cmp     byte [r12 + 1], TLS_RECORD_VERSION_MAJOR
    jne     .bad_record
    movzx   eax, word [r12 + 3]
    xchg    al, ah
    lea     ecx, [r13d - TLS_RECORD_HEADER_LEN]
    cmp     eax, ecx
    jne     .bad_record

    lea     rbx, [r12 + TLS_RECORD_HEADER_LEN]
    cmp     byte [rbx], TLS_HANDSHAKE_SERVER_HELLO
    jne     .bad_handshake
    movzx   eax, byte [rbx + 1]
    test    eax, eax
    jne     .bad_handshake
    movzx   eax, byte [rbx + 2]
    shl     eax, 8
    movzx   ecx, byte [rbx + 3]
    or      eax, ecx
    lea     ecx, [r13d - TLS_RECORD_HEADER_LEN - TLS_HANDSHAKE_HEADER_LEN]
    cmp     eax, ecx
    jne     .bad_handshake

    ; legacy_version must be 0x0303.
    cmp     byte [rbx + 4], TLS_RECORD_VERSION_MAJOR
    jne     .bad_handshake
    cmp     byte [rbx + 5], TLS_LEGACY_VERSION_MINOR
    jne     .bad_handshake

    ; cursor = handshake body after random.
    lea     r15, [rbx + TLS_HANDSHAKE_HEADER_LEN + 2 + TLS_RANDOM_LEN]
    movzx   eax, byte [r15]            ; session_id_echo len
    inc     r15
    cmp     eax, TLS_SESSION_ID_LEN
    ja      .bad_handshake
    add     r15, rax

    ; Need cipher_suite + compression + extensions_len.
    lea     rax, [r12 + r13]
    mov     rcx, rax
    sub     rcx, r15
    cmp     rcx, 5
    jb      .bad_handshake
    cmp     byte [r15], 0x13
    jne     .bad_handshake
    cmp     byte [r15 + 1], 0x01
    jne     .bad_handshake
    cmp     byte [r15 + 2], 0
    jne     .bad_handshake
    movzx   eax, word [r15 + 3]
    xchg    al, ah
    lea     r15, [r15 + 5]             ; extension cursor
    mov     r11, r15
    add     r11, rax                   ; extension end
    lea     rcx, [r12 + r13]
    cmp     r11, rcx
    jne     .bad_handshake

    mov     dword [tls_parse_flags], 0 ; bit0 supported_versions, bit1 key_share
.ext_loop:
    cmp     r15, r11
    jae     .ext_done
    mov     rcx, r11
    sub     rcx, r15
    cmp     rcx, 4
    jb      .bad_handshake
    movzx   eax, word [r15]
    xchg    al, ah
    movzx   ecx, word [r15 + 2]
    xchg    cl, ch
    lea     r15, [r15 + 4]
    mov     r9, r15
    add     r9, rcx
    cmp     r9, r11
    ja      .bad_handshake

    cmp     eax, TLS_EXT_SUPPORTED_VERSIONS
    je      .ext_versions
    cmp     eax, TLS_EXT_KEY_SHARE
    je      .ext_key_share
    mov     r15, r9
    jmp     .ext_loop

.ext_versions:
    cmp     ecx, 2
    jne     .bad_handshake
    cmp     byte [r15], 0x03
    jne     .bad_handshake
    cmp     byte [r15 + 1], 0x04
    jne     .bad_handshake
    or      dword [tls_parse_flags], 1
    mov     r15, r9
    jmp     .ext_loop

.ext_key_share:
    cmp     ecx, 36
    jne     .bad_handshake
    cmp     byte [r15], 0
    jne     .bad_handshake
    cmp     byte [r15 + 1], 0x1D
    jne     .bad_handshake
    cmp     byte [r15 + 2], 0
    jne     .bad_handshake
    cmp     byte [r15 + 3], TLS_X25519_KEY_LEN
    jne     .bad_handshake
    mov     rdi, r14
    lea     rsi, [r15 + 4]
    mov     edx, TLS_X25519_KEY_LEN
    call    er_memcpy
    or      dword [tls_parse_flags], 2
    mov     r15, r9
    jmp     .ext_loop

.ext_done:
    cmp     dword [tls_parse_flags], 3
    jne     .bad_handshake
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad_handshake:
.bad_record:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tls_shared_secret_from_server_hello
; rdi = TLS ServerHello record, esi = record length, rdx = out shared[32]
; ==================================================================
global er_tls_shared_secret_from_server_hello
er_fn er_tls_shared_secret_from_server_hello
    push    rbx
    mov     rbx, rdx
    lea     rdx, [tls_server_public]
    call    er_tls_server_hello_parse
    test    eax, eax
    js      .fail
    mov     rdi, rbx
    lea     rsi, [tls_client_private]
    lea     rdx, [tls_server_public]
    call    er_tor_curve25519_scalar_mult
    xor     eax, eax
    er_ok
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     rbx
    er_ret

; ==================================================================
; er_tls_hkdf_extract
; rdi=salt, esi=salt_len, rdx=ikm, ecx=ikm_len, r8=out[32]
; ==================================================================
global er_tls_hkdf_extract
er_fn er_tls_hkdf_extract
    test    rdx, rdx
    jz      .bad
    test    r8, r8
    jz      .bad
    test    rdi, rdi
    jnz     .have_salt
    lea     rdi, [rel tls_zero_secret]
    mov     esi, TLS_RANDOM_LEN
.have_salt:
    call    er_tor_hmac_sha256
    cmp     eax, TLS_RANDOM_LEN
    jne     .fail
    xor     eax, eax
    er_ok
    er_ret
.bad:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    er_ret
.fail:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    er_ret

; ==================================================================
; er_tls_hkdf_expand_label
; rdi=secret[32], rsi=label, edx=label_len, rcx=context, r8d=context_len, r9=out[32]
; Supports one 32-byte SHA-256 block, enough for TLS 1.3 traffic secrets.
; ==================================================================
global er_tls_hkdf_expand_label
er_fn er_tls_hkdf_expand_label
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15, rcx
    mov     ebx, r8d
    mov     [tls_hkdf_out_ptr], r9

    test    r12, r12
    jz      .bad_label
    test    r13, r13
    jz      .bad_label
    cmp     qword [tls_hkdf_out_ptr], 0
    jz      .bad_label
    cmp     r14d, TLS_HKDF_LABEL_MAX_LEN
    ja      .bad_label
    cmp     ebx, TLS_HKDF_CONTEXT_MAX_LEN
    ja      .bad_label
    test    ebx, ebx
    jz      .context_ok
    test    r15, r15
    jz      .bad_label
.context_ok:
    ; HkdfLabel.length = 32.
    mov     byte [tls_hkdf_info], 0
    mov     byte [tls_hkdf_info + 1], TLS_RANDOM_LEN
    ; HkdfLabel.label = "tls13 " || label.
    lea     eax, [r14d + TLS_HKDF_LABEL_PREFIX_LEN]
    mov     [tls_hkdf_info + 2], al
    lea     rdi, [tls_hkdf_info + 3]
    lea     rsi, [rel tls_hkdf_label_prefix]
    mov     edx, TLS_HKDF_LABEL_PREFIX_LEN
    call    er_memcpy
    lea     rdi, [tls_hkdf_info + 3 + TLS_HKDF_LABEL_PREFIX_LEN]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy
    lea     r10d, [r14d + TLS_HKDF_LABEL_PREFIX_LEN + 3]
    mov     [tls_hkdf_info + r10], bl
    inc     r10d
    test    ebx, ebx
    jz      .copy_done
    lea     rdi, [tls_hkdf_info + r10]
    mov     rsi, r15
    mov     edx, ebx
    call    er_memcpy
    add     r10d, ebx
.copy_done:
    ; HKDF-Expand single block: HMAC(secret, info || 0x01).
    lea     rdi, [tls_hkdf_msg]
    lea     rsi, [tls_hkdf_info]
    mov     edx, r10d
    call    er_memcpy
    mov     byte [tls_hkdf_msg + r10], 1
    inc     r10d

    mov     rdi, r12
    mov     esi, TLS_RANDOM_LEN
    lea     rdx, [tls_hkdf_msg]
    mov     ecx, r10d
    mov     r8, [tls_hkdf_out_ptr]
    call    er_tor_hmac_sha256
    cmp     eax, TLS_RANDOM_LEN
    jne     .fail_label
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad_label:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail_label:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; _tls_gcm_shift_v — shift V right by one bit, apply R when lsb was set.
; ==================================================================
_tls_gcm_shift_v:
    push    rbx
    movzx   ebx, byte [tls_gcm_v + 15]
    and     ebx, 1
    xor     edx, edx
    xor     ecx, ecx
.shift_loop:
    cmp     ecx, TLS_GCM_BLOCK_LEN
    jae     .shift_done
    movzx   eax, byte [tls_gcm_v + rcx]
    mov     r8d, eax
    and     r8d, 1
    shr     al, 1
    test    edx, edx
    jz      .no_carry
    or      al, 0x80
.no_carry:
    mov     [tls_gcm_v + rcx], al
    mov     edx, r8d
    inc     ecx
    jmp     .shift_loop
.shift_done:
    test    ebx, ebx
    jz      .done
    xor     byte [tls_gcm_v], 0xE1
.done:
    pop     rbx
    ret

; ==================================================================
; _tls_gcm_mul — GF(2^128) multiply X by H into X.
; ==================================================================
_tls_gcm_mul:
    push    rbx
    push    r12
    push    r13

    lea     rdi, [tls_gcm_z]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_v]
    lea     rsi, [tls_gcm_h]
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memcpy

    xor     r12d, r12d          ; byte index
.byte_loop:
    cmp     r12d, TLS_GCM_BLOCK_LEN
    jae     .finish
    movzx   r13d, byte [tls_gcm_x + r12]
    mov     ebx, 0x80
.bit_loop:
    test    r13d, ebx
    jz      .skip_xor
    xor     ecx, ecx
.xor_loop:
    cmp     ecx, TLS_GCM_BLOCK_LEN
    jae     .skip_xor
    movzx   eax, byte [tls_gcm_v + rcx]
    xor     [tls_gcm_z + rcx], al
    inc     ecx
    jmp     .xor_loop
.skip_xor:
    call    _tls_gcm_shift_v
    shr     ebx, 1
    jnz     .bit_loop
    inc     r12d
    jmp     .byte_loop

.finish:
    lea     rdi, [tls_gcm_x]
    lea     rsi, [tls_gcm_z]
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memcpy
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tls_gcm_absorb — GHASH absorb bytes at rsi, edx=len.
; ==================================================================
_tls_gcm_absorb:
    push    rbx
    push    r12
    push    r13

    mov     r12, rsi
    mov     r13d, edx
.block_loop:
    test    r13d, r13d
    jz      .done
    lea     rdi, [tls_gcm_block]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    mov     ebx, TLS_GCM_BLOCK_LEN
    cmp     r13d, ebx
    jae     .copy
    mov     ebx, r13d
.copy:
    lea     rdi, [tls_gcm_block]
    mov     rsi, r12
    mov     edx, ebx
    call    er_memcpy
    xor     ecx, ecx
.xor:
    cmp     ecx, TLS_GCM_BLOCK_LEN
    jae     .mul
    movzx   eax, byte [tls_gcm_block + rcx]
    xor     [tls_gcm_x + rcx], al
    inc     ecx
    jmp     .xor
.mul:
    call    _tls_gcm_mul
    add     r12, rbx
    sub     r13d, ebx
    jmp     .block_loop
.done:
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_tls_aes128_gcm_encrypt
; rdi=out, rsi=in, edx=len, rcx=aad, r8d=aad_len, r9=key
; [rsp+8]=iv12, [rsp+16]=tag16
; ==================================================================
global er_tls_aes128_gcm_encrypt
er_fn er_tls_aes128_gcm_encrypt
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15, rcx
    mov     ebx, r8d
    mov     r10, r9
    mov     r11, [rsp + 48]     ; iv12
    mov     r9,  [rsp + 56]     ; tag
    mov     [tls_gcm_key_ptr], r10
    mov     [tls_gcm_iv_ptr], r11
    mov     [tls_gcm_tag_ptr], r9
    test    r12, r12
    jz      .bad_gcm
    test    r13, r13
    jz      .bad_gcm
    test    r10, r10
    jz      .bad_gcm
    test    r11, r11
    jz      .bad_gcm
    test    r9, r9
    jz      .bad_gcm
    test    ebx, ebx
    jz      .aad_ok
    test    r15, r15
    jz      .bad_gcm
.aad_ok:
    ; H = AES_K(0^128)
    lea     rdi, [tls_gcm_h]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_ctr]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_h]
    lea     rsi, [tls_gcm_h]
    mov     edx, TLS_GCM_BLOCK_LEN
    mov     rcx, [tls_gcm_key_ptr]
    lea     r8, [tls_gcm_ctr]
    call    er_tor_aes_ctr

    ; J0 = IV || 0x00000001
    lea     rdi, [tls_gcm_ctr]
    mov     rsi, [tls_gcm_iv_ptr]
    mov     edx, TLS_GCM_IV_LEN
    call    er_memcpy
    mov     dword [tls_gcm_ctr + 12], 0x01000000
    ; tag mask = E(K, J0)
    lea     rdi, [tls_gcm_tagmask]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_tagmask]
    lea     rsi, [tls_gcm_tagmask]
    mov     edx, TLS_GCM_BLOCK_LEN
    mov     rcx, [tls_gcm_key_ptr]
    lea     r8, [tls_gcm_ctr]
    call    er_tor_aes_ctr

    ; Encrypt with inc32(J0).
    lea     rdi, [tls_gcm_ctr]
    mov     rsi, [tls_gcm_iv_ptr]
    mov     edx, TLS_GCM_IV_LEN
    call    er_memcpy
    mov     dword [tls_gcm_ctr + 12], 0x02000000
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, r14d
    mov     rcx, [tls_gcm_key_ptr]
    lea     r8, [tls_gcm_ctr]
    call    er_tor_aes_ctr

    ; GHASH(AAD || ciphertext || lengths)
    lea     rdi, [tls_gcm_x]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    mov     rsi, r15
    mov     edx, ebx
    call    _tls_gcm_absorb
    mov     rsi, r12
    mov     edx, r14d
    call    _tls_gcm_absorb

    lea     rdi, [tls_gcm_len_block]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    mov     eax, ebx
    shl     rax, 3
    bswap   rax
    mov     [tls_gcm_len_block], rax
    mov     eax, r14d
    shl     rax, 3
    bswap   rax
    mov     [tls_gcm_len_block + 8], rax
    mov     rsi, tls_gcm_len_block
    mov     edx, TLS_GCM_BLOCK_LEN
    call    _tls_gcm_absorb

    xor     ecx, ecx
.tag_loop:
    cmp     ecx, TLS_GCM_TAG_LEN
    jae     .ok_gcm
    movzx   eax, byte [tls_gcm_x + rcx]
    xor     al, [tls_gcm_tagmask + rcx]
    mov     rdx, [tls_gcm_tag_ptr]
    mov     [rdx + rcx], al
    inc     ecx
    jmp     .tag_loop
.ok_gcm:
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.bad_gcm:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tls_aes128_gcm_decrypt
; rdi=out, rsi=in, edx=len, rcx=aad, r8d=aad_len, r9=key
; [rsp+8]=iv12, [rsp+16]=tag16
; ==================================================================
global er_tls_aes128_gcm_decrypt
er_fn er_tls_aes128_gcm_decrypt
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15, rcx
    mov     ebx, r8d
    mov     r10, r9
    mov     r11, [rsp + 48]     ; iv12
    mov     r9,  [rsp + 56]     ; tag
    mov     [tls_gcm_key_ptr], r10
    mov     [tls_gcm_iv_ptr], r11
    mov     [tls_gcm_tag_ptr], r9
    test    r12, r12
    jz      .bad_gcm_dec
    test    r13, r13
    jz      .bad_gcm_dec
    test    r10, r10
    jz      .bad_gcm_dec
    test    r11, r11
    jz      .bad_gcm_dec
    test    r9, r9
    jz      .bad_gcm_dec
    test    ebx, ebx
    jz      .aad_ok_dec
    test    r15, r15
    jz      .bad_gcm_dec
.aad_ok_dec:
    ; H = AES_K(0^128)
    lea     rdi, [tls_gcm_h]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_ctr]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_h]
    lea     rsi, [tls_gcm_h]
    mov     edx, TLS_GCM_BLOCK_LEN
    mov     rcx, [tls_gcm_key_ptr]
    lea     r8, [tls_gcm_ctr]
    call    er_tor_aes_ctr

    ; J0 = IV || 0x00000001, tag mask = E(K, J0)
    lea     rdi, [tls_gcm_ctr]
    mov     rsi, [tls_gcm_iv_ptr]
    mov     edx, TLS_GCM_IV_LEN
    call    er_memcpy
    mov     dword [tls_gcm_ctr + 12], 0x01000000
    lea     rdi, [tls_gcm_tagmask]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    lea     rdi, [tls_gcm_tagmask]
    lea     rsi, [tls_gcm_tagmask]
    mov     edx, TLS_GCM_BLOCK_LEN
    mov     rcx, [tls_gcm_key_ptr]
    lea     r8, [tls_gcm_ctr]
    call    er_tor_aes_ctr

    ; GHASH(AAD || ciphertext || lengths)
    lea     rdi, [tls_gcm_x]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    mov     rsi, r15
    mov     edx, ebx
    call    _tls_gcm_absorb
    mov     rsi, r13
    mov     edx, r14d
    call    _tls_gcm_absorb
    lea     rdi, [tls_gcm_len_block]
    xor     esi, esi
    mov     edx, TLS_GCM_BLOCK_LEN
    call    er_memset
    mov     eax, ebx
    shl     rax, 3
    bswap   rax
    mov     [tls_gcm_len_block], rax
    mov     eax, r14d
    shl     rax, 3
    bswap   rax
    mov     [tls_gcm_len_block + 8], rax
    mov     rsi, tls_gcm_len_block
    mov     edx, TLS_GCM_BLOCK_LEN
    call    _tls_gcm_absorb

    xor     ecx, ecx
.tag_dec_loop:
    cmp     ecx, TLS_GCM_TAG_LEN
    jae     .check_tag_dec
    movzx   eax, byte [tls_gcm_x + rcx]
    xor     al, [tls_gcm_tagmask + rcx]
    mov     [tls_gcm_calc_tag + rcx], al
    inc     ecx
    jmp     .tag_dec_loop
.check_tag_dec:
    mov     rsi, [tls_gcm_tag_ptr]
    xor     eax, eax
    xor     ecx, ecx
.cmp_tag_dec:
    cmp     ecx, TLS_GCM_TAG_LEN
    jae     .cmp_done_dec
    movzx   edx, byte [tls_gcm_calc_tag + rcx]
    xor     dl, [rsi + rcx]
    or      al, dl
    inc     ecx
    jmp     .cmp_tag_dec
.cmp_done_dec:
    test    al, al
    jnz     .auth_fail_dec

    ; Decrypt with inc32(J0).
    lea     rdi, [tls_gcm_ctr]
    mov     rsi, [tls_gcm_iv_ptr]
    mov     edx, TLS_GCM_IV_LEN
    call    er_memcpy
    mov     dword [tls_gcm_ctr + 12], 0x02000000
    mov     rdi, r12
    mov     rsi, r13
    mov     edx, r14d
    mov     rcx, [tls_gcm_key_ptr]
    lea     r8, [tls_gcm_ctr]
    call    er_tor_aes_ctr
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.auth_fail_dec:
    mov     eax, -1
    er_err  ERROR_TLS_RECORD
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.bad_gcm_dec:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tls_transcript_hash_ch_sh
; rdi=ServerHello record, esi=record len, rdx=out hash[32]
; Hashes ClientHello.handshake || ServerHello.handshake.
; ==================================================================
global er_tls_transcript_hash_ch_sh
er_fn er_tls_transcript_hash_ch_sh
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi
    mov     r13d, esi
    mov     rbx, rdx
    test    r12, r12
    jz      .bad_hash
    test    rbx, rbx
    jz      .bad_hash
    cmp     r13d, TLS_RECORD_HEADER_LEN + TLS_HANDSHAKE_HEADER_LEN
    jb      .bad_hash
    cmp     r13d, TLS_RX_RECORD_MAX
    ja      .bad_hash
    cmp     byte [r12], TLS_RECORD_HANDSHAKE
    jne     .bad_hash

    movzx   eax, word [r12 + 3]
    xchg    al, ah
    lea     ecx, [r13d - TLS_RECORD_HEADER_LEN]
    cmp     eax, ecx
    jne     .bad_hash

    lea     rdi, [tls_transcript]
    lea     rsi, [tls_client_hello + TLS_RECORD_HEADER_LEN]
    mov     edx, TLS_CLIENT_HELLO_PAYLOAD_LEN
    call    er_memcpy
    lea     rdi, [tls_transcript + TLS_CLIENT_HELLO_PAYLOAD_LEN]
    lea     rsi, [r12 + TLS_RECORD_HEADER_LEN]
    lea     edx, [r13d - TLS_RECORD_HEADER_LEN]
    call    er_memcpy

    lea     rdi, [tls_transcript]
    lea     esi, [r13d - TLS_RECORD_HEADER_LEN + TLS_CLIENT_HELLO_PAYLOAD_LEN]
    mov     rdx, rbx
    call    er_tor_sha256
    cmp     eax, TLS_RANDOM_LEN
    jne     .fail_hash

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad_hash:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail_hash:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tls_derive_handshake_secrets
; rdi=ServerHello record, esi=record len
; returns eax=0 after deriving early, derived, handshake,
; client handshake traffic, and server handshake traffic secrets.
; ==================================================================
global er_tls_derive_handshake_secrets
er_fn er_tls_derive_handshake_secrets
    push    rbx
    push    r12

    mov     r12, rdi
    mov     ebx, esi

    lea     rdx, [tls_transcript_hash]
    call    er_tls_transcript_hash_ch_sh
    test    eax, eax
    js      .fail_derive

    ; early_secret = HKDF-Extract(0, 0-length IKM)
    xor     rdi, rdi
    xor     esi, esi
    lea     rdx, [rel tls_zero_secret]
    xor     ecx, ecx
    lea     r8, [tls_early_secret]
    call    er_tls_hkdf_extract
    test    eax, eax
    js      .fail_derive

    ; empty_hash = SHA256("")
    lea     rdi, [rel tls_zero_secret]
    xor     esi, esi
    lea     rdx, [tls_empty_hash]
    call    er_tor_sha256
    cmp     eax, TLS_RANDOM_LEN
    jne     .fail_derive

    ; derived_secret = Derive-Secret(early_secret, "derived", empty_hash)
    lea     rdi, [tls_early_secret]
    lea     rsi, [rel tls_label_derived]
    mov     edx, tls_label_derived_len
    lea     rcx, [tls_empty_hash]
    mov     r8d, TLS_RANDOM_LEN
    lea     r9, [tls_derived_secret]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive

    ; handshake_secret = HKDF-Extract(derived_secret, ECDHE shared secret)
    lea     rdi, [tls_derived_secret]
    mov     esi, TLS_RANDOM_LEN
    lea     rdx, [tls_shared_secret]
    mov     ecx, TLS_RANDOM_LEN
    lea     r8, [tls_handshake_secret]
    call    er_tls_hkdf_extract
    test    eax, eax
    js      .fail_derive

    ; client/server handshake traffic secrets.
    lea     rdi, [tls_handshake_secret]
    lea     rsi, [rel tls_label_client_hs]
    mov     edx, tls_label_client_hs_len
    lea     rcx, [tls_transcript_hash]
    mov     r8d, TLS_RANDOM_LEN
    lea     r9, [tls_client_hs_traffic_secret]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive

    lea     rdi, [tls_handshake_secret]
    lea     rsi, [rel tls_label_server_hs]
    mov     edx, tls_label_server_hs_len
    lea     rcx, [tls_transcript_hash]
    mov     r8d, TLS_RANDOM_LEN
    lea     r9, [tls_server_hs_traffic_secret]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive

    ; client/server handshake record keys and IVs.
    lea     rdi, [tls_client_hs_traffic_secret]
    lea     rsi, [rel tls_label_key]
    mov     edx, tls_label_key_len
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [tls_key_block]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive
    lea     rdi, [tls_client_hs_key]
    lea     rsi, [tls_key_block]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [tls_server_hs_traffic_secret]
    lea     rsi, [rel tls_label_key]
    mov     edx, tls_label_key_len
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [tls_key_block]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive
    lea     rdi, [tls_server_hs_key]
    lea     rsi, [tls_key_block]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [tls_client_hs_traffic_secret]
    lea     rsi, [rel tls_label_iv]
    mov     edx, tls_label_iv_len
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [tls_key_block]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive
    lea     rdi, [tls_client_hs_iv]
    lea     rsi, [tls_key_block]
    mov     edx, 12
    call    er_memcpy

    lea     rdi, [tls_server_hs_traffic_secret]
    lea     rsi, [rel tls_label_iv]
    mov     edx, tls_label_iv_len
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [tls_key_block]
    call    er_tls_hkdf_expand_label
    test    eax, eax
    js      .fail_derive
    lea     rdi, [tls_server_hs_iv]
    lea     rsi, [tls_key_block]
    mov     edx, 12
    call    er_memcpy

    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret

.fail_derive:
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tls_connect — start TLS handshake on an established TCP conn
; edi = conn_id. Returns fail-closed until encrypted records exist.
; ==================================================================
global er_tls_connect
er_fn er_tls_connect
    push    rbx
    mov     ebx, edi

    mov     rdi, tls_client_hello
    mov     esi, TLS_CLIENT_HELLO_RECORD_LEN
    xor     edx, edx
    call    er_tls_client_hello_build
    test    eax, eax
    js      .fail

    mov     edi, ebx
    mov     rsi, tls_client_hello
    mov     edx, TLS_CLIENT_HELLO_RECORD_LEN
    call    er_tcp_send
    test    eax, eax
    js      .fail

    mov     [tls_conn_id], ebx
    mov     dword [tls_state], TLS_STATE_CLIENT_HELLO_SENT

    ; Read and process ServerHello.
    mov     ecx, 500
.wait_server_hello:
    push    rcx
    call    er_net_poll
    pop     rcx

    push    rcx
    mov     edi, ebx
    lea     rsi, [tls_rx_record]
    lea     rdx, [tls_rx_len]
    mov     dword [tls_rx_len], TLS_RX_RECORD_MAX
    call    er_tcp_recv
    pop     rcx
    test    eax, eax
    jns     .got_server_hello
    dec     ecx
    jnz     .wait_server_hello
    jmp     .fail

.got_server_hello:
    cmp     dword [tls_rx_len], 0
    jne     .process_server_hello
    dec     ecx
    jnz     .wait_server_hello
    jmp     .fail

.process_server_hello:
    lea     rdi, [tls_rx_record]
    mov     esi, [tls_rx_len]
    lea     rdx, [tls_shared_secret]
    call    er_tls_shared_secret_from_server_hello
    test    eax, eax
    js      .fail
    lea     rdi, [tls_rx_record]
    mov     esi, [tls_rx_len]
    call    er_tls_derive_handshake_secrets
    test    eax, eax
    js      .fail

    ; Certificate verification, Finished validation, and AEAD record
    ; protection are required before application data can flow.
    mov     eax, -1
    er_err  ERROR_TLS_UNSUPPORTED
    pop     rbx
    er_ret

.fail:
    mov     dword [tls_state], TLS_STATE_CLOSED
    mov     eax, -1
    er_err  ERROR_TLS_HANDSHAKE
    pop     rbx
    er_ret

; ==================================================================
; er_tls_send / er_tls_recv — encrypted record I/O
; Fail closed until TLS_STATE_ACTIVE.
; ==================================================================
global er_tls_send
er_fn er_tls_send
    cmp     dword [tls_state], TLS_STATE_ACTIVE
    jne     .closed
    call    er_tcp_send
    er_ret
.closed:
    mov     eax, -1
    er_err  ERROR_TLS_CLOSED
    er_ret

global er_tls_recv
er_fn er_tls_recv
    cmp     dword [tls_state], TLS_STATE_ACTIVE
    jne     .closed
    call    er_tcp_recv
    er_ret
.closed:
    mov     eax, -1
    er_err  ERROR_TLS_CLOSED
    er_ret
