; EdgeRun Tor cell helper self-test.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tor_constants.inc"
%include "x86_64/net/net_constants.inc"
%include "test/test_macros.inc"

extern er_tor_build_extend2_body
extern er_tor_cell_init
extern er_tor_circuit_create
extern er_tor_link_handshake
extern er_tor_open_stream
extern er_tor_recv_relay
extern er_tor_send_relay

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
onion_key:
%assign i 0
%rep 32
    db 0x80 + i
%assign i i+1
%endrep
created_reply:
%assign i 0
%rep 64
    db 0x40 + i
%assign i i+1
%endrep

SECTION .bss
body: resb 119
created2_cell: resb TOR_CELL_LEN
sent_create2_cell: resb TOR_CELL_LEN
out_circ_id: resd 1
opened_stream_id: resw 1
tls_recv_mode: resd 1
tls_recv_step: resd 1
link_bad_certs: resd 1
link_duplicate_certs: resd 1
link_with_vpadding: resd 1
link_bad_netinfo: resd 1
oversized_relay_body: resb TOR_HS_RELAY_DATA_MAX + 1

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

    call    er_tor_cell_init
    mov     dword [rel created2_cell + TOR_CELL_CIRC_ID], 1
    mov     byte [rel created2_cell + TOR_CELL_CMD], TOR_CELL_CREATED2
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD], 0
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 1], 2
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 2], 0
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 3], 64
    lea     rdi, [rel created2_cell + TOR_CELL_PAYLOAD + 4]
    lea     rsi, [rel created_reply]
    mov     edx, 64
    call    er_memcpy
    lea     rdi, [rel out_circ_id]
    lea     rsi, [rel node_id]
    lea     rdx, [rel onion_key]
    call    er_tor_circuit_create
    ASSERT_EQ eax, 0
    ASSERT_RDX 0
    ASSERT_EQ dword [rel out_circ_id], 1
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_CMD], TOR_CELL_CREATE2
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD], 0
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + 1], 2
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + 2], 0
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + 3], 84

    mov     dword [rel sent_create2_cell + TOR_CELL_CIRC_ID], 0
    mov     byte [rel sent_create2_cell + TOR_CELL_CMD], 0
    mov     word [rel opened_stream_id], 0
    mov     edi, 1
    mov     esi, 0x04030201
    mov     edx, 80
    lea     rcx, [rel opened_stream_id]
    call    er_tor_open_stream
    ASSERT_EQ eax, 0
    ASSERT_RDX 0
    ASSERT_EQ word [rel opened_stream_id], 1
    ASSERT_EQ dword [rel sent_create2_cell + TOR_CELL_CIRC_ID], 1
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_CMD], TOR_CELL_RELAY
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_CMD], TOR_RELAY_BEGIN
    ASSERT_EQ word [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_STREAM_ID], 1
    ASSERT_EQ word [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_LEN], 0x0b00
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET], '1'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 1], '.'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 2], '2'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 3], '.'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 4], '3'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 5], '.'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 6], '4'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 7], ':'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 8], '8'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 9], '0'
    ASSERT_EQ byte [rel sent_create2_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DATA_OFFSET + 10], 0

    call    er_tor_cell_init
    mov     dword [rel created2_cell + TOR_CELL_CIRC_ID], 2
    mov     byte [rel created2_cell + TOR_CELL_CMD], TOR_CELL_CREATED2
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD], 0
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 1], 2
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 2], 0
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 3], 64
    lea     rdi, [rel out_circ_id]
    lea     rsi, [rel node_id]
    lea     rdx, [rel onion_key]
    call    er_tor_circuit_create
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_CIRC_BUILD_FAIL

    call    er_tor_cell_init
    mov     dword [rel created2_cell + TOR_CELL_CIRC_ID], 1
    mov     byte [rel created2_cell + TOR_CELL_CMD], TOR_CELL_CREATED2
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD], 0
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 1], 2
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 2], 0
    mov     byte [rel created2_cell + TOR_CELL_PAYLOAD + 3], 63
    lea     rdi, [rel out_circ_id]
    lea     rsi, [rel node_id]
    lea     rdx, [rel onion_key]
    call    er_tor_circuit_create
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_CIRC_BUILD_FAIL

    mov     dword [rel tls_recv_mode], 1
    mov     dword [rel tls_recv_step], 0
    mov     dword [rel link_bad_certs], 1
    mov     dword [rel link_duplicate_certs], 0
    mov     edi, 0x6402000a
    mov     esi, 19001
    call    er_tor_link_handshake
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_PROTOCOL_ERR

    mov     dword [rel tls_recv_mode], 1
    mov     dword [rel tls_recv_step], 0
    mov     dword [rel link_bad_certs], 0
    mov     dword [rel link_duplicate_certs], 1
    mov     edi, 0x6402000a
    mov     esi, 19001
    call    er_tor_link_handshake
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_PROTOCOL_ERR

    mov     dword [rel tls_recv_mode], 1
    mov     dword [rel tls_recv_step], 0
    mov     dword [rel link_bad_certs], 0
    mov     dword [rel link_duplicate_certs], 0
    mov     dword [rel link_with_vpadding], 0
    mov     dword [rel link_bad_netinfo], 1
    mov     edi, 0x6402000a
    mov     esi, 19001
    call    er_tor_link_handshake
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_PROTOCOL_ERR

    mov     dword [rel tls_recv_mode], 1
    mov     dword [rel tls_recv_step], 0
    mov     dword [rel link_bad_certs], 0
    mov     dword [rel link_duplicate_certs], 0
    mov     dword [rel link_with_vpadding], 0
    mov     dword [rel link_bad_netinfo], 0
    mov     edi, 0x6402000a
    mov     esi, 19001
    call    er_tor_link_handshake
    ASSERT_EQ eax, 0
    ASSERT_RDX 0

    mov     dword [rel tls_recv_mode], 1
    mov     dword [rel tls_recv_step], 0
    mov     dword [rel link_bad_certs], 0
    mov     dword [rel link_duplicate_certs], 0
    mov     dword [rel link_with_vpadding], 1
    mov     dword [rel link_bad_netinfo], 0
    mov     edi, 0x6402000a
    mov     esi, 19001
    call    er_tor_link_handshake
    ASSERT_EQ eax, 0
    ASSERT_RDX 0

    mov     edi, 1
    xor     esi, esi
    mov     edx, TOR_RELAY_DATA
    lea     rcx, [rel oversized_relay_body]
    mov     r8d, TOR_HS_RELAY_DATA_MAX + 1
    call    er_tor_send_relay
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_PROTOCOL_ERR

    mov     edi, 1
    xor     esi, esi
    mov     edx, TOR_RELAY_DATA
    xor     ecx, ecx
    xor     r8d, r8d
    call    er_tor_send_relay
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_TOR_PROTOCOL_ERR

    mov     edi, 1
    xor     esi, esi
    xor     edx, edx
    xor     ecx, ecx
    xor     r8d, r8d
    call    er_tor_recv_relay
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_INVALID_PARAM

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
er_tls_connect:
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
    xor     eax, eax
    ret

er_tor_sha256:
    mov     eax, 32
    ret

er_tcp_get_state:
    mov     eax, TCP_ESTABLISHED
    er_ok
    ret

er_tls_send:
    push    rdi
    push    rsi
    push    rdx
    lea     rdi, [rel sent_create2_cell]
    mov     edx, TOR_CELL_LEN
    call    er_memcpy
    pop     rdx
    pop     rsi
    pop     rdi
    xor     eax, eax
    er_ok
    ret

er_tls_recv:
    cmp     dword [rel tls_recv_mode], 1
    je      .link_recv
    push    rdi
    push    rsi
    push    rdx
    mov     rdi, rsi
    lea     rsi, [rel created2_cell]
    mov     edx, TOR_CELL_LEN
    call    er_memcpy
    pop     rdx
    mov     dword [rdx], TOR_CELL_LEN
    pop     rsi
    pop     rdi
    xor     eax, eax
    er_ok
    ret

.link_recv:
    push    rbx
    push    r12
    mov     rbx, rsi
    mov     r12, rdx
    mov     eax, [rel tls_recv_step]
    inc     dword [rel tls_recv_step]
    cmp     dword [rel link_with_vpadding], 1
    je      .link_recv_padded
    cmp     eax, 0
    je      .versions_header
    cmp     eax, 1
    je      .versions_payload
    cmp     eax, 2
    je      .certs_header
    cmp     eax, 3
    je      .certs_payload
    cmp     eax, 4
    je      .auth_header
    cmp     eax, 5
    je      .auth_payload
    cmp     eax, 6
    je      .netinfo_header
    jmp     .netinfo_payload
.link_recv_padded:
    cmp     eax, 0
    je      .versions_header
    cmp     eax, 1
    je      .versions_payload
    cmp     eax, 2
    je      .vpadding_header
    cmp     eax, 3
    je      .vpadding_payload
    cmp     eax, 4
    je      .certs_header
    cmp     eax, 5
    je      .certs_payload
    cmp     eax, 6
    je      .vpadding_header
    cmp     eax, 7
    je      .vpadding_payload
    cmp     eax, 8
    je      .auth_header
    cmp     eax, 9
    je      .auth_payload
    cmp     eax, 10
    je      .netinfo_vpadding_header5
    cmp     eax, 11
    je      .netinfo_vpadding_len
    cmp     eax, 12
    je      .netinfo_vpadding_payload
    cmp     eax, 13
    je      .netinfo_header
    jmp     .netinfo_payload
.versions_header:
    mov     byte [rbx], 0
    mov     byte [rbx + 1], 0
    mov     byte [rbx + 2], TOR_CELL_VERSIONS
    mov     byte [rbx + 3], 0
    mov     byte [rbx + 4], 4
    mov     dword [r12], TOR_VERSIONS_HEADER
    jmp     .link_ok
.versions_payload:
    mov     byte [rbx], 0
    mov     byte [rbx + 1], TOR_LINK_V4
    mov     byte [rbx + 2], 0
    mov     byte [rbx + 3], TOR_LINK_V5
    mov     dword [r12], 4
    jmp     .link_ok
.vpadding_header:
    mov     dword [rbx + TOR_VAR_CIRC_ID], 0
    mov     byte [rbx + TOR_VAR_CMD], TOR_CELL_VPADDING
    mov     byte [rbx + TOR_VAR_LEN], 0
    mov     byte [rbx + TOR_VAR_LEN + 1], 2
    mov     dword [r12], TOR_VAR_HEADER
    jmp     .link_ok
.vpadding_payload:
    mov     byte [rbx], 0xa5
    mov     byte [rbx + 1], 0x5a
    mov     dword [r12], 2
    jmp     .link_ok
.certs_header:
    mov     dword [rbx + TOR_VAR_CIRC_ID], 0
    mov     byte [rbx + TOR_VAR_CMD], TOR_CELL_CERTS
    mov     byte [rbx + TOR_VAR_LEN], 0
    cmp     dword [rel link_bad_certs], 0
    je      .certs_header_good
    mov     byte [rbx + TOR_VAR_LEN + 1], 1
    jmp     .certs_header_done
.certs_header_good:
    cmp     dword [rel link_duplicate_certs], 0
    je      .certs_header_single
    mov     byte [rbx + TOR_VAR_LEN + 1], 7
    jmp     .certs_header_done
.certs_header_single:
    mov     byte [rbx + TOR_VAR_LEN + 1], 4
.certs_header_done:
    mov     dword [r12], TOR_VAR_HEADER
    jmp     .link_ok
.certs_payload:
    cmp     dword [rel link_bad_certs], 0
    je      .certs_payload_good
    mov     byte [rbx], 0
    mov     dword [r12], 1
    jmp     .link_ok
.certs_payload_good:
    cmp     dword [rel link_duplicate_certs], 0
    je      .certs_payload_single
    mov     byte [rbx], 2
    mov     byte [rbx + 1], TOR_CERTTYPE_ED25519_ID
    mov     byte [rbx + 2], 0
    mov     byte [rbx + 3], 0
    mov     byte [rbx + 4], TOR_CERTTYPE_ED25519_ID
    mov     byte [rbx + 5], 0
    mov     byte [rbx + 6], 0
    mov     dword [r12], 7
    jmp     .link_ok
.certs_payload_single:
    mov     byte [rbx], 1
    mov     byte [rbx + 1], TOR_CERTTYPE_ED25519_ID
    mov     byte [rbx + 2], 0
    mov     byte [rbx + 3], 0
    mov     dword [r12], 4
    jmp     .link_ok
.auth_header:
    mov     dword [rbx + TOR_VAR_CIRC_ID], 0
    mov     byte [rbx + TOR_VAR_CMD], TOR_CELL_AUTH_CHALLENGE
    mov     byte [rbx + TOR_VAR_LEN], 0
    mov     byte [rbx + TOR_VAR_LEN + 1], 34
    mov     dword [r12], TOR_VAR_HEADER
    jmp     .link_ok
.auth_payload:
    mov     rdi, rbx
    mov     esi, 0x5a
    mov     edx, 32
    call    er_memset
    mov     byte [rbx + 32], 0
    mov     byte [rbx + 33], 0
    mov     dword [r12], 34
    jmp     .link_ok
.netinfo_vpadding_header5:
    mov     dword [rbx + TOR_CELL_CIRC_ID], 0
    mov     byte [rbx + TOR_CELL_CMD], TOR_CELL_VPADDING
    mov     dword [r12], TOR_CELL_HEADER_LEN
    jmp     .link_ok
.netinfo_vpadding_len:
    mov     byte [rbx], 0
    mov     byte [rbx + 1], 2
    mov     dword [r12], 2
    jmp     .link_ok
.netinfo_vpadding_payload:
    mov     byte [rbx], 0xcc
    mov     byte [rbx + 1], 0xdd
    mov     dword [r12], 2
    jmp     .link_ok
.netinfo_header:
    mov     dword [rbx + TOR_CELL_CIRC_ID], 0
    mov     byte [rbx + TOR_CELL_CMD], TOR_CELL_NETINFO
    mov     dword [r12], TOR_CELL_HEADER_LEN
    jmp     .link_ok
.netinfo_payload:
    mov     rdi, rbx
    xor     esi, esi
    mov     edx, TOR_CELL_PAYLOAD_LEN
    call    er_memset
    mov     byte [rbx + 4], 4
    mov     byte [rbx + 5], 4
    mov     dword [rbx + 6], 0x6402000a
    cmp     dword [rel link_bad_netinfo], 0
    je      .netinfo_payload_good
    mov     byte [rbx + 10], 255
    jmp     .netinfo_payload_done
.netinfo_payload_good:
    mov     byte [rbx + 10], 0
.netinfo_payload_done:
    mov     dword [r12], TOR_CELL_PAYLOAD_LEN
.link_ok:
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    ret
