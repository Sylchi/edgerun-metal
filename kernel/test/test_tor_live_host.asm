; EdgeRun live Tor ORPort host probe — x86_64 Linux assembly.
; Connects to 127.0.0.1:19001, completes repo TLS, then performs the
; client side of the Tor channel link handshake through NETINFO.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tls_constants.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_tls_init
extern er_tls_connect
extern er_tls_send
extern er_tls_recv
extern er_sha256_init
extern er_sha256_update
extern er_sha256_final
extern er_tor_curve25519_scalar_mult
extern er_tor_aes_ctr
extern er_memcpy

%define SYS_read      0
%define SYS_write     1
%define SYS_close     3
%define SYS_socket    41
%define SYS_connect   42
%define SYS_exit      60
%define SYS_getrandom 318

%define AF_INET       2
%define SOCK_STREAM   1
%define TOR_HOST_PORT 19001
%define SHA256_CTX_SIZE 108

SECTION .data
sockaddr:
    dw AF_INET
    db 0x4a, 0x39                ; 19001, network order
    db 127, 0, 0, 1
    dq 0

msg_tls_ok:  db "tls ok", 10
msg_tls_ok_len equ $ - msg_tls_ok
msg_link_ok: db "tor link ok", 10
msg_link_ok_len equ $ - msg_link_ok
msg_fail:    db "tor live host FAIL", 10
msg_fail_len equ $ - msg_fail

versions_cell:
    db 0, 0, TOR_CELL_VERSIONS, 0, 4, 0, TOR_LINK_V4, 0, TOR_LINK_V5
versions_cell_len equ $ - versions_cell

SECTION .bss
live_fd: resd 1
rx_cell: resb TOR_CELL_LEN
rx_len: resd 1
tx_netinfo: resb TOR_CELL_LEN
sha_ctx: resb SHA256_CTX_SIZE
hmac_ipad: resb 64
hmac_opad: resb 64
hmac_tmp: resb TLS_RANDOM_LEN
rng_buf: resb TLS_RANDOM_LEN

SECTION .text
global _start
_start:
    call    er_tls_init

    mov     eax, SYS_socket
    mov     edi, AF_INET
    mov     esi, SOCK_STREAM
    xor     edx, edx
    syscall
    test    eax, eax
    js      .fail
    mov     [rel live_fd], eax

    mov     edi, eax
    lea     rsi, [rel sockaddr]
    mov     edx, 16
    mov     eax, SYS_connect
    syscall
    test    eax, eax
    js      .fail

    mov     edi, [rel live_fd]
    call    er_tls_connect
    test    eax, eax
    js      .fail

    lea     rsi, [rel msg_tls_ok]
    mov     edx, msg_tls_ok_len
    call    write_stdout

    mov     edi, [rel live_fd]
    lea     rsi, [rel versions_cell]
    mov     edx, versions_cell_len
    call    er_tls_send
    test    eax, eax
    js      .fail

    call    recv_versions
    test    eax, eax
    js      .fail

    call    recv_var_cell
    test    eax, eax
    js      .fail
    cmp     byte [rel rx_cell + TOR_VAR_CMD], TOR_CELL_CERTS
    jne     .fail

    call    recv_var_cell
    test    eax, eax
    js      .fail
    cmp     byte [rel rx_cell + TOR_VAR_CMD], TOR_CELL_AUTH_CHALLENGE
    jne     .fail

    call    recv_fixed_cell
    test    eax, eax
    js      .fail
    cmp     byte [rel rx_cell + TOR_CELL_CMD], TOR_CELL_NETINFO
    jne     .fail

    call    build_netinfo
    mov     edi, [rel live_fd]
    lea     rsi, [rel tx_netinfo]
    mov     edx, TOR_CELL_LEN
    call    er_tls_send
    test    eax, eax
    js      .fail

    lea     rsi, [rel msg_link_ok]
    mov     edx, msg_link_ok_len
    call    write_stdout
    mov     edi, [rel live_fd]
    mov     eax, SYS_close
    syscall
    xor     edi, edi
    mov     eax, SYS_exit
    syscall

.fail:
    lea     rsi, [rel msg_fail]
    mov     edx, msg_fail_len
    call    write_stdout
    mov     edi, [rel live_fd]
    test    edi, edi
    jle     .exit_fail
    mov     eax, SYS_close
    syscall
.exit_fail:
    mov     edi, 1
    mov     eax, SYS_exit
    syscall

write_stdout:
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    ret

recv_versions:
    lea     rsi, [rel rx_cell]
    mov     dword [rel rx_len], TOR_VERSIONS_HEADER
    call    tls_recv_exact
    test    eax, eax
    js      .fail
    cmp     byte [rel rx_cell + 2], TOR_CELL_VERSIONS
    jne     .fail
    movzx   ecx, word [rel rx_cell + 3]
    rol     cx, 8
    test    ecx, 1
    jnz     .fail
    lea     rsi, [rel rx_cell + TOR_VERSIONS_HEADER]
    mov     [rel rx_len], ecx
    call    tls_recv_exact
    ret
.fail:
    mov     eax, -1
    ret

recv_var_cell:
    lea     rsi, [rel rx_cell]
    mov     dword [rel rx_len], TOR_VAR_HEADER
    call    tls_recv_exact
    test    eax, eax
    js      .fail
    movzx   ecx, word [rel rx_cell + TOR_VAR_LEN]
    rol     cx, 8
    lea     rsi, [rel rx_cell + TOR_VAR_PAYLOAD]
    mov     [rel rx_len], ecx
    call    tls_recv_exact
    ret
.fail:
    mov     eax, -1
    ret

recv_fixed_cell:
    lea     rsi, [rel rx_cell]
    mov     dword [rel rx_len], TOR_CELL_LEN
    call    tls_recv_exact
    ret

tls_recv_exact:
    mov     edi, [rel live_fd]
    lea     rdx, [rel rx_len]
    call    er_tls_recv
    test    eax, eax
    js      .fail
    xor     eax, eax
    ret
.fail:
    mov     eax, -1
    ret

build_netinfo:
    lea     rdi, [rel tx_netinfo]
    xor     eax, eax
    mov     ecx, TOR_CELL_LEN
    rep     stosb
    mov     byte [rel tx_netinfo + TOR_CELL_CMD], TOR_CELL_NETINFO
    mov     byte [rel tx_netinfo + TOR_CELL_PAYLOAD + 4], 4
    mov     byte [rel tx_netinfo + TOR_CELL_PAYLOAD + 5], 4
    mov     byte [rel tx_netinfo + TOR_CELL_PAYLOAD + 10], 0
    ret

; ------------------------------------------------------------------
; TLS platform hooks.
; ------------------------------------------------------------------
global er_tcp_send
er_tcp_send:
    mov     eax, SYS_write
    syscall
    test    eax, eax
    js      .fail
    xor     eax, eax
    ret
.fail:
    mov     eax, -1
    ret

global er_tcp_recv
er_tcp_recv:
    push    r12
    mov     r12, rdx
    mov     edx, [r12]
    mov     eax, SYS_read
    syscall
    test    eax, eax
    js      .fail
    mov     [r12], eax
    xor     eax, eax
    pop     r12
    ret
.fail:
    mov     dword [r12], 0
    mov     eax, -1
    pop     r12
    ret

global er_net_poll
er_net_poll:
    xor     eax, eax
    ret

global er_tpm_get_random
er_tpm_get_random:
    mov     rax, rdi
    ret

global er_tpm_crb_transfer
er_tpm_crb_transfer:
    mov     rdi, rdx
    mov     esi, TLS_RANDOM_LEN
    xor     edx, edx
    mov     eax, SYS_getrandom
    syscall
    test    eax, eax
    js      .fail
    ret
.fail:
    xor     eax, eax
    ret

global er_tpm_parse_get_random
er_tpm_parse_get_random:
    push    rcx
    mov     rdi, rdx
    mov     esi, ecx
    xor     edx, edx
    mov     eax, SYS_getrandom
    syscall
    pop     rcx
    cmp     eax, ecx
    jne     .fail
    ret
.fail:
    xor     eax, eax
    ret

global er_tor_sha256
er_tor_sha256:
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12d, esi
    mov     r13, rdx
    lea     rdi, [rel sha_ctx]
    call    er_sha256_init
    lea     rdi, [rel sha_ctx]
    mov     rsi, rbx
    mov     edx, r12d
    call    er_sha256_update
    lea     rdi, [rel sha_ctx]
    mov     rsi, r13
    call    er_sha256_final
    mov     eax, TLS_RANDOM_LEN
    pop     r13
    pop     r12
    pop     rbx
    ret

global er_tor_hmac_sha256
er_tor_hmac_sha256:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     rbx, rdi        ; key
    mov     r12d, esi       ; key_len
    mov     r13, rdx        ; msg
    mov     r14d, ecx       ; msg_len
    mov     r15, r8         ; out

    lea     rdi, [rel hmac_ipad]
    mov     al, 0x36
    mov     ecx, 64
    rep     stosb
    lea     rdi, [rel hmac_opad]
    mov     al, 0x5c
    mov     ecx, 64
    rep     stosb

    xor     ecx, ecx
.xor_key:
    cmp     ecx, r12d
    jae     .hash_inner
    cmp     ecx, 64
    jae     .hash_inner
    mov     al, [rbx + rcx]
    xor     [rel hmac_ipad + rcx], al
    xor     [rel hmac_opad + rcx], al
    inc     ecx
    jmp     .xor_key

.hash_inner:
    lea     rdi, [rel sha_ctx]
    call    er_sha256_init
    lea     rdi, [rel sha_ctx]
    lea     rsi, [rel hmac_ipad]
    mov     edx, 64
    call    er_sha256_update
    lea     rdi, [rel sha_ctx]
    mov     rsi, r13
    mov     edx, r14d
    call    er_sha256_update
    lea     rdi, [rel sha_ctx]
    lea     rsi, [rel hmac_tmp]
    call    er_sha256_final

    lea     rdi, [rel sha_ctx]
    call    er_sha256_init
    lea     rdi, [rel sha_ctx]
    lea     rsi, [rel hmac_opad]
    mov     edx, 64
    call    er_sha256_update
    lea     rdi, [rel sha_ctx]
    lea     rsi, [rel hmac_tmp]
    mov     edx, TLS_RANDOM_LEN
    call    er_sha256_update
    lea     rdi, [rel sha_ctx]
    mov     rsi, r15
    call    er_sha256_final
    mov     eax, TLS_RANDOM_LEN
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

global er_serial_putchar
global er_serial_puthex32
er_serial_putchar:
er_serial_puthex32:
    xor     eax, eax
    ret
