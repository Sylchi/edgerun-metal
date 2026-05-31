; EdgeRun TLS transport — x86_64 assembly
;
; Owns TLS record framing and handshake state. This module intentionally
; fails closed until encrypted record protection is implemented.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tls_constants.inc"

extern er_tcp_send
extern er_tcp_recv
extern er_tpm_get_random
extern er_tpm_crb_transfer
extern er_tpm_parse_get_random
extern er_tor_curve25519_scalar_mult
extern er_memcpy

SECTION .rodata

tls_x25519_basepoint:
    db 9
    times 31 db 0

SECTION .bss

tls_state: resd 1
tls_conn_id: resd 1
tls_tpm_cmd: resb 64
tls_tpm_rsp: resb 96
tls_client_hello: resb TLS_CLIENT_HELLO_RECORD_LEN
tls_client_private: resb TLS_X25519_KEY_LEN
tls_client_public: resb TLS_X25519_KEY_LEN

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

    ; ServerHello parsing, transcript hash, HKDF traffic secrets,
    ; certificate verification, Finished validation, and AEAD record
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
