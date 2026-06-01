; EdgeRun Tor cell helper self-test.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"
%include "test/test_macros.inc"

extern er_tor_build_extend2_body

TEST_DATA_PASSED_FAILED
node_id:
    db 0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09
    db 0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,0x10,0x11,0x12,0x13
handshake:
%assign i 0
%rep 84
    db i
%assign i i+1
%endrep

SECTION .bss
body: resb 119

SECTION .text
global _start
_start:
    lea     rdi, [rel body]
    lea     rsi, [rel node_id]
    mov     edx, 0x04030201
    mov     ecx, 9001
    lea     r8, [rel handshake]
    call    er_tor_build_extend2_body
    ASSERT_EQ eax, 119
    ASSERT_EQ byte [rel body], 2
    ASSERT_EQ byte [rel body + 1], 0
    ASSERT_EQ byte [rel body + 2], 6
    ASSERT_EQ dword [rel body + 3], 0x04030201
    ASSERT_EQ byte [rel body + 7], 0x23
    ASSERT_EQ byte [rel body + 8], 0x29
    ASSERT_EQ byte [rel body + 9], 2
    ASSERT_EQ byte [rel body + 10], 20
    ASSERT_MEM_EQ [rel node_id], [rel body + 11], 20
    ASSERT_EQ byte [rel body + 31], 0
    ASSERT_EQ byte [rel body + 32], 2
    ASSERT_EQ byte [rel body + 33], 0
    ASSERT_EQ byte [rel body + 34], 84
    ASSERT_MEM_EQ [rel handshake], [rel body + 35], 84

    TEST_EXIT_FAILED

global er_memcpy
er_memcpy:
    push    rcx
    push    rsi
    push    rdi
    mov     rcx, rdx
    rep     movsb
    pop     rdi
    pop     rsi
    pop     rcx
    xor     eax, eax
    ret

global er_memset
er_memset:
    push    rcx
    push    rdi
    mov     eax, esi
    mov     rcx, rdx
    rep     stosb
    pop     rdi
    pop     rcx
    xor     eax, eax
    ret

global er_tcp_connect
global er_tcp_get_state
global er_tls_connect
global er_tls_send
global er_tls_recv
global er_tcp_close
global er_net_poll
global er_serial_puts
global er_serial_putchar
global er_serial_puthex64
global er_serial_puthex32
global er_serial_crlf
global er_tor_ntor_keygen
global er_tor_ntor_client_handshake
global er_tor_ntor_client_process
global er_tor_curve25519_scalar_mult
global er_tor_aes_ctr
global er_tor_sha256
er_tcp_connect:
er_tcp_get_state:
er_tls_connect:
er_tls_send:
er_tls_recv:
er_tcp_close:
er_net_poll:
er_serial_puts:
er_serial_putchar:
er_serial_puthex64:
er_serial_puthex32:
er_serial_crlf:
er_tor_ntor_keygen:
er_tor_ntor_client_handshake:
er_tor_ntor_client_process:
er_tor_curve25519_scalar_mult:
er_tor_aes_ctr:
er_tor_sha256:
    xor     eax, eax
    ret
