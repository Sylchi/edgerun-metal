; EdgeRun TLS self-hosted test runner — x86_64 assembly
; Tests TLS ClientHello record construction and fail-closed record I/O.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tls_constants.inc"
%include "test/test_macros.inc"

extern er_tls_init
extern er_tls_client_hello_build
extern er_tls_server_hello_parse
extern er_tls_shared_secret_from_server_hello
extern er_tls_hkdf_extract
extern er_tls_hkdf_expand_label
extern er_tls_transcript_hash_ch_sh
extern er_tls_derive_handshake_secrets
extern er_tls_aes128_gcm_encrypt
extern er_tls_send

SECTION .bss
passed: resq 1
failed: resq 1
total:  resq 1
out_buf: resb TLS_CLIENT_HELLO_RECORD_LEN
priv_buf: resb TLS_X25519_KEY_LEN
server_key: resb TLS_X25519_KEY_LEN
shared_buf: resb TLS_X25519_KEY_LEN
hkdf_out: resb TLS_RANDOM_LEN
hash_out: resb TLS_RANDOM_LEN
gcm_ct: resb 16
gcm_tag: resb 16
random_calls: resd 1

SECTION .rodata
server_hello:
    db TLS_RECORD_HANDSHAKE, TLS_RECORD_VERSION_MAJOR, TLS_RECORD_VERSION_COMPAT_MINOR, 0, server_hello_payload_len
    db TLS_HANDSHAKE_SERVER_HELLO, 0, 0, server_hello_body_len
    db TLS_RECORD_VERSION_MAJOR, TLS_LEGACY_VERSION_MINOR
    db 0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17
    db 0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f
    db 0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27
    db 0x28,0x29,0x2a,0x2b,0x2c,0x2d,0x2e,0x2f
    db TLS_SESSION_ID_LEN
    db 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37
    db 0x38,0x39,0x3a,0x3b,0x3c,0x3d,0x3e,0x3f
    db 0x40,0x41,0x42,0x43,0x44,0x45,0x46,0x47
    db 0x48,0x49,0x4a,0x4b,0x4c,0x4d,0x4e,0x4f
    db 0x13, 0x01, 0x00
    db 0, server_hello_ext_len
    db 0x00, 0x2b, 0x00, 0x02, 0x03, 0x04
    db 0x00, 0x33, 0x00, 0x24, 0x00, 0x1d, 0x00, TLS_X25519_KEY_LEN
    db 0x70,0x71,0x72,0x73,0x74,0x75,0x76,0x77
    db 0x78,0x79,0x7a,0x7b,0x7c,0x7d,0x7e,0x7f
    db 0x80,0x81,0x82,0x83,0x84,0x85,0x86,0x87
    db 0x88,0x89,0x8a,0x8b,0x8c,0x8d,0x8e,0x8f
server_hello_len equ $ - server_hello
server_hello_payload_len equ server_hello_len - TLS_RECORD_HEADER_LEN
server_hello_body_len equ server_hello_payload_len - TLS_HANDSHAKE_HEADER_LEN
server_hello_ext_len equ 46

hkdf_label:
    db "c hs traffic"
hkdf_label_len equ $ - hkdf_label
hkdf_context:
    times TLS_RANDOM_LEN db 0x11
gcm_key_zero:
    times 16 db 0
gcm_iv_zero:
    times 12 db 0
gcm_pt_zero:
    times 16 db 0
gcm_ct_expected:
    db 0x03,0x88,0xda,0xce,0x60,0xb6,0xa3,0x92
    db 0xf3,0x28,0xc2,0xb9,0x71,0xb2,0xfe,0x78
gcm_tag_expected:
    db 0xab,0x6e,0x47,0xd4,0x2c,0xec,0x13,0xbd
    db 0xf5,0x3a,0x67,0xb2,0x12,0x57,0xbd,0xdf

SECTION .text
global _start
_start:
    call    er_tls_init

    lea     rdi, [rel out_buf]
    mov     esi, TLS_CLIENT_HELLO_RECORD_LEN
    lea     rdx, [rel priv_buf]
    call    er_tls_client_hello_build
    ASSERT_RAX TLS_CLIENT_HELLO_RECORD_LEN
    ASSERT_RDX 0

    movzx   eax, byte [rel out_buf + 0]
    ASSERT_EQ eax, TLS_RECORD_HANDSHAKE
    movzx   eax, byte [rel out_buf + 1]
    ASSERT_EQ eax, TLS_RECORD_VERSION_MAJOR
    movzx   eax, byte [rel out_buf + 2]
    ASSERT_EQ eax, TLS_RECORD_VERSION_COMPAT_MINOR
    movzx   eax, byte [rel out_buf + 4]
    ASSERT_EQ eax, TLS_CLIENT_HELLO_PAYLOAD_LEN

    movzx   eax, byte [rel out_buf + 5]
    ASSERT_EQ eax, TLS_HANDSHAKE_CLIENT_HELLO
    movzx   eax, byte [rel out_buf + 8]
    ASSERT_EQ eax, TLS_CLIENT_HELLO_BODY_LEN
    movzx   eax, byte [rel out_buf + 9]
    ASSERT_EQ eax, TLS_RECORD_VERSION_MAJOR
    movzx   eax, byte [rel out_buf + 10]
    ASSERT_EQ eax, TLS_LEGACY_VERSION_MINOR

    movzx   eax, byte [rel out_buf + 43]
    ASSERT_EQ eax, TLS_SESSION_ID_LEN
    movzx   eax, byte [rel out_buf + 76]
    ASSERT_EQ eax, 0
    movzx   eax, byte [rel out_buf + 77]
    ASSERT_EQ eax, 2
    movzx   eax, word [rel out_buf + 78]
    ASSERT_EQ eax, 0x0113

    movzx   eax, byte [rel out_buf + 82]
    ASSERT_EQ eax, 0
    movzx   eax, byte [rel out_buf + 83]
    ASSERT_EQ eax, TLS_CLIENT_EXTENSIONS_LEN

    movzx   eax, word [rel out_buf + 84]
    ASSERT_EQ eax, 0x2B00
    movzx   eax, word [rel out_buf + 91]
    ASSERT_EQ eax, 0x0A00
    movzx   eax, word [rel out_buf + 99]
    ASSERT_EQ eax, 0x0D00
    movzx   eax, word [rel out_buf + 111]
    ASSERT_EQ eax, 0x3300
    movzx   eax, word [rel out_buf + 117]
    ASSERT_EQ eax, 0x1D00
    movzx   eax, word [rel out_buf + 119]
    ASSERT_EQ eax, 0x2000

    ; Private scalar was clamped.
    movzx   eax, byte [rel priv_buf]
    and     eax, 7
    ASSERT_EQ eax, 0
    movzx   eax, byte [rel priv_buf + 31]
    and     eax, 0xC0
    ASSERT_EQ eax, 0x40

    ; Strict ServerHello parse extracts the server X25519 key share.
    lea     rdi, [rel server_hello]
    mov     esi, server_hello_len
    lea     rdx, [rel server_key]
    call    er_tls_server_hello_parse
    ASSERT_RAX 0
    movzx   eax, byte [rel server_key]
    ASSERT_EQ eax, 0x70
    movzx   eax, byte [rel server_key + 31]
    ASSERT_EQ eax, 0x8f

    ; ServerHello processing computes the ECDHE shared secret.
    lea     rdi, [rel server_hello]
    mov     esi, server_hello_len
    lea     rdx, [rel shared_buf]
    call    er_tls_shared_secret_from_server_hello
    ASSERT_RAX 0
    movzx   eax, byte [rel shared_buf]
    ASSERT_EQ eax, 0xA5
    movzx   eax, byte [rel shared_buf + 31]
    ASSERT_EQ eax, 0xA5

    ; HKDF helpers route through HMAC-SHA256 and produce 32 bytes.
    xor     rdi, rdi
    xor     esi, esi
    lea     rdx, [rel shared_buf]
    mov     ecx, TLS_X25519_KEY_LEN
    lea     r8, [rel hkdf_out]
    call    er_tls_hkdf_extract
    ASSERT_RAX 0
    movzx   eax, byte [rel hkdf_out]
    ASSERT_EQ eax, 0xC0

    lea     rdi, [rel hkdf_out]
    lea     rsi, [rel hkdf_label]
    mov     edx, hkdf_label_len
    lea     rcx, [rel hkdf_context]
    mov     r8d, TLS_RANDOM_LEN
    lea     r9, [rel hkdf_out]
    call    er_tls_hkdf_expand_label
    ASSERT_RAX 0
    movzx   eax, byte [rel hkdf_out]
    ASSERT_EQ eax, 0xC0

    lea     rdi, [rel server_hello]
    mov     esi, server_hello_len
    lea     rdx, [rel hash_out]
    call    er_tls_transcript_hash_ch_sh
    ASSERT_RAX 0
    movzx   eax, byte [rel hash_out]
    ASSERT_EQ eax, 0xD0

    lea     rdi, [rel server_hello]
    mov     esi, server_hello_len
    call    er_tls_derive_handshake_secrets
    ASSERT_RAX 0

    ; AES-128-GCM NIST SP 800-38D test case: zero key/IV, one zero block.
    lea     rdi, [rel gcm_ct]
    lea     rsi, [rel gcm_pt_zero]
    mov     edx, 16
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [rel gcm_key_zero]
    lea     rax, [rel gcm_tag]
    push    rax
    lea     rax, [rel gcm_iv_zero]
    push    rax
    call    er_tls_aes128_gcm_encrypt
    add     rsp, 16
    ASSERT_RAX 0
    lea     rdi, [rel gcm_ct]
    lea     rsi, [rel gcm_ct_expected]
    mov     edx, 16
    call    _mem_eq
    ASSERT_EQ eax, 1
    lea     rdi, [rel gcm_tag]
    lea     rsi, [rel gcm_tag_expected]
    mov     edx, 16
    call    _mem_eq
    ASSERT_EQ eax, 1

    ; Encrypted record send must fail until the TLS state is active.
    xor     edi, edi
    lea     rsi, [rel out_buf]
    mov     edx, TLS_CLIENT_HELLO_RECORD_LEN
    call    er_tls_send
    ASSERT_EQ eax, -1

    mov     rax, [rel failed]
    test    rax, rax
    jnz     .exit_fail
    xor     edi, edi
    jmp     .exit
.exit_fail:
    mov     edi, 1
.exit:
    mov     eax, 60
    syscall

_mem_eq:
    push    rcx
    push    rsi
    push    rdi
    mov     rcx, rdx
    repe    cmpsb
    setz    al
    movzx   eax, al
    pop     rdi
    pop     rsi
    pop     rcx
    ret

; ------------------------------------------------------------------
; Test stubs for platform I/O and crypto dependency surfaces.
; ------------------------------------------------------------------
global er_tpm_get_random
global er_tpm_crb_transfer
global er_tpm_parse_get_random
global er_tor_curve25519_scalar_mult
global er_tor_hmac_sha256
global er_tor_sha256
global er_tcp_send
global er_tcp_recv
global er_net_poll

er_tpm_get_random:
    mov     rax, rdi
    ret

er_tpm_crb_transfer:
    mov     eax, esi
    ret

er_tpm_parse_get_random:
    push    rbx
    push    rcx
    mov     ebx, [rel random_calls]
    inc     dword [rel random_calls]
    mov     eax, ebx
    shl     eax, 5
    mov     ebx, eax
    mov     rdi, rdx
    mov     ecx, TLS_RANDOM_LEN
.fill:
    mov     [rdi], bl
    inc     bl
    inc     rdi
    dec     ecx
    jnz     .fill
    mov     eax, TLS_RANDOM_LEN
    pop     rcx
    pop     rbx
    ret

er_tor_curve25519_scalar_mult:
    push    rcx
    mov     ecx, TLS_X25519_KEY_LEN
.pub:
    mov     byte [rdi], 0xA5
    inc     rdi
    dec     ecx
    jnz     .pub
    pop     rcx
    ret

er_tor_hmac_sha256:
    push    rcx
    mov     rdi, r8
    mov     ecx, TLS_RANDOM_LEN
.hmac:
    mov     byte [rdi], 0xC0
    inc     rdi
    dec     ecx
    jnz     .hmac
    mov     eax, TLS_RANDOM_LEN
    pop     rcx
    ret

er_tor_sha256:
    push    rcx
    mov     rdi, rdx
    mov     ecx, TLS_RANDOM_LEN
.sha:
    mov     byte [rdi], 0xD0
    inc     rdi
    dec     ecx
    jnz     .sha
    mov     eax, TLS_RANDOM_LEN
    pop     rcx
    ret

er_tcp_send:
er_tcp_recv:
er_net_poll:
    xor     eax, eax
    ret
