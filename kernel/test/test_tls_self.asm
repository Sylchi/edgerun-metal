; EdgeRun TLS self-hosted test runner — x86_64 assembly
; Tests TLS ClientHello record construction and fail-closed record I/O.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tls_constants.inc"
%include "test/test_macros.inc"

extern er_tls_init
extern er_tls_client_hello_build
extern er_tls_send

SECTION .bss
passed: resq 1
failed: resq 1
total:  resq 1
out_buf: resb TLS_CLIENT_HELLO_RECORD_LEN
priv_buf: resb TLS_X25519_KEY_LEN
random_calls: resd 1

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

    ; Encrypted record send must fail until the TLS state is active.
    xor     edi, edi
    lea     rsi, [rel out_buf]
    mov     edx, TLS_CLIENT_HELLO_RECORD_LEN
    call    er_tls_send
    ASSERT_RAX -1

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

; ------------------------------------------------------------------
; Test stubs for platform I/O and crypto dependency surfaces.
; ------------------------------------------------------------------
global er_tpm_get_random
global er_tpm_crb_transfer
global er_tpm_parse_get_random
global er_tor_curve25519_scalar_mult
global er_tcp_send
global er_tcp_recv

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

er_tcp_send:
er_tcp_recv:
    xor     eax, eax
    ret
