; EdgeRun Tor AES self-hosted test runner — x86_64 assembly
; Tests AES-128-CTR with NIST known-answer vectors and roundtrip.
; No libc, no external dependencies beyond runtime.o. Exits via syscall.

%include "x86_64/macros.inc"
%include "x86_64/crypto/tor_constants.inc"
%include "x86_64/crypto/local_constants.inc"
%include "test/test_macros.inc"

extern er_tor_aes_ctr
extern er_tor_aes256_ctr
extern er_tor_set_role
extern er_tor_set_role_caps
extern er_tor_enable_role
extern er_tor_get_role
extern er_tor_get_role_caps
extern er_tor_hsdir_build_publish_header
extern er_tor_hsdir_build_fetch_request
extern er_local_cell_init
extern er_route_register_relay
extern er_route_send
extern er_memcpy

TEST_DATA_PASSED_FAILED

test_key: db 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6
          db 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c

test_key256:
          db 0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe
          db 0x2b, 0x73, 0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81
          db 0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7
          db 0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4

test_iv:  db 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7
          db 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff

test_pt:  db 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96
          db 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a
          db 0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c
          db 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51
          db 0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11
          db 0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef
          db 0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17
          db 0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10

test_ct:  db 0x87, 0x4d, 0x61, 0x91, 0xb6, 0x20, 0xe3, 0x26
          db 0x1b, 0xef, 0x68, 0x64, 0x99, 0x0d, 0xb6, 0xce
          db 0x98, 0x06, 0xf6, 0x6b, 0x79, 0x70, 0xfd, 0xff
          db 0x86, 0x17, 0x18, 0x7b, 0xb9, 0xff, 0xfd, 0xff
          db 0x5a, 0xe4, 0xdf, 0x3e, 0xdb, 0xd5, 0xd3, 0x5e
          db 0x5b, 0x4f, 0x09, 0x02, 0x0d, 0xb0, 0x3e, 0xab
          db 0x1e, 0x03, 0x1d, 0xda, 0x2f, 0xbe, 0x03, 0xd1
          db 0x79, 0x21, 0x70, 0xa0, 0xf3, 0x00, 0x9c, 0xee

test_ct256:
          db 0x60, 0x1e, 0xc3, 0x13, 0x77, 0x57, 0x89, 0xa5
          db 0xb7, 0xa7, 0xf5, 0x04, 0xbb, 0xf3, 0xd2, 0x28
          db 0xf4, 0x43, 0xe3, 0xca, 0x4d, 0x62, 0xb5, 0x9a
          db 0xca, 0x84, 0xe9, 0x90, 0xca, 0xca, 0xf5, 0xc5
          db 0x2b, 0x09, 0x30, 0xda, 0xa2, 0x3d, 0xe9, 0x4c
          db 0xe8, 0x70, 0x17, 0xba, 0x2d, 0x84, 0x98, 0x8d
          db 0xdf, 0xc9, 0xc5, 0x8d, 0xb6, 0x7a, 0xad, 0xa6
          db 0x13, 0xc2, 0xdd, 0x08, 0x45, 0x79, 0x41, 0xa6
hsdir_blinded: db "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789+abc"
hsdir_blinded_len equ $ - hsdir_blinded
hsdir_publish_expected:
          db "POST /tor/hs/3/publish HTTP/1.1", 0x0D, 0x0A
          db "Host: tor", 0x0D, 0x0A
          db "Content-Length: 123", 0x0D, 0x0A
          db "Connection: close", 0x0D, 0x0A, 0x0D, 0x0A
hsdir_publish_expected_len equ $ - hsdir_publish_expected
hsdir_fetch_expected:
          db "GET /tor/hs/3/AbCdEfGhIjKlMnOpQrStUvWxYz0123456789+abc HTTP/1.1", 0x0D, 0x0A
          db "Host: tor", 0x0D, 0x0A
          db "Connection: close", 0x0D, 0x0A, 0x0D, 0x0A
hsdir_fetch_expected_len equ $ - hsdir_fetch_expected
route_hash:
          db "tor-route-test-identity"
          times 32 - ($ - route_hash) db 0

SECTION .bss
buf:      resb 64
req_buf:  resb 512
iv_copy:  resb 16
bench_buf: resb TOR_CELL_LEN
route_cell: resb LOCAL_CELL_SIZE
last_relay_circ: resd 1
last_relay_stream: resd 1
last_relay_cmd: resd 1
last_relay_data: resq 1
last_relay_len: resd 1
tor_conn_id: resd 1
tor_rx_cell: resb TOR_CELL_LEN
tor_recv_len: resd 1
SECTION .text
global _start
_start:
    call    er_local_cell_init
    ASSERT_RDX 0

; ================================================================
; Test 1: AES-128-CTR encrypt — known-answer test
; NIST SP 800-38A test vector F.5.1 (64 bytes, key=2b...)
; ================================================================
    TEST_DEBUG_LABEL "1"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 64
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ASSERT_MEM_EQ [rel test_ct], [rel buf], 64

; ================================================================
; Test 2: AES-128-CTR roundtrip (decrypt = same operation in CTR)
; ================================================================
    TEST_DEBUG_LABEL "2"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 64
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel buf]
    mov     edx, 64
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ASSERT_MEM_EQ [rel test_pt], [rel buf], 64

; ================================================================
; Test 3: Partial block (non-16-byte aligned length)
; ================================================================
    TEST_DEBUG_LABEL "3"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 7
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ; First 7 bytes should match known ciphertext
    ASSERT_MEM_EQ [rel test_ct], [rel buf], 7

; ================================================================
; Test 4: Empty length (should be no-op)
; ================================================================
    TEST_DEBUG_LABEL "4"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    xor     edx, edx
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ; IV should be unchanged (no blocks encrypted)
    ASSERT_MEM_EQ [rel test_iv], [rel iv_copy], 16

; ================================================================
; Test 5: Multi-block XOR (3 blocks = 48 bytes)
; ================================================================
    TEST_DEBUG_LABEL "5"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 48
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr

    ASSERT_MEM_EQ [rel test_ct], [rel buf], 48

; ================================================================
; Test 6: AES-256-CTR encrypt — known-answer test
; NIST SP 800-38A test vector F.5.5 (64 bytes, key=603d...)
; ================================================================
    TEST_DEBUG_LABEL "6"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 64
    lea     rcx, [rel test_key256]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes256_ctr

    ASSERT_MEM_EQ [rel test_ct256], [rel buf], 64

; ================================================================
; Test 7: AES-256-CTR roundtrip
; ================================================================
    TEST_DEBUG_LABEL "7"
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel test_pt]
    mov     edx, 64
    lea     rcx, [rel test_key256]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes256_ctr

    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy

    lea     rdi, [rel buf]
    lea     rsi, [rel buf]
    mov     edx, 64
    lea     rcx, [rel test_key256]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes256_ctr

    ASSERT_MEM_EQ [rel test_pt], [rel buf], 64

; ================================================================
; Test 8: Tor role state accepts every defined node role
; ================================================================
    TEST_DEBUG_LABEL "8"
    mov     edi, TOR_ROLE_CLIENT
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_CLIENT

    mov     edi, TOR_ROLE_GUARD
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_OR_RELAY

    mov     edi, TOR_ROLE_MIDDLE
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_OR_RELAY

    mov     edi, TOR_ROLE_EXIT
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_OR_RELAY | TOR_CAP_EXIT

    mov     edi, TOR_ROLE_DIRECTORY
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_DIRECTORY

    mov     edi, TOR_ROLE_BRIDGE
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_OR_RELAY | TOR_CAP_BRIDGE

    mov     edi, TOR_ROLE_HS_SERVICE
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_SERVICE

    mov     edi, TOR_ROLE_HS_INTRO
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_INTRO

    mov     edi, TOR_ROLE_HS_RENDEZVOUS
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_RENDEZVOUS

    mov     edi, TOR_ROLE_HS_PEER
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_PEER

    mov     edi, TOR_ROLE_HS_FULL
    call    er_tor_set_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_FULL

    call    er_tor_get_role
    ASSERT_EQ eax, TOR_ROLE_HS_FULL

; ================================================================
; Test 9: Invalid roles fail without changing current role
; ================================================================
    TEST_DEBUG_LABEL "9"
    mov     edi, 0x7fffffff
    call    er_tor_set_role
    ASSERT_EQ eax, -1
    call    er_tor_get_role
    ASSERT_EQ eax, TOR_ROLE_HS_FULL

    mov     edi, TOR_CAP_HS_PEER
    call    er_tor_set_role_caps
    ASSERT_EQ eax, 0
    call    er_tor_get_role
    ASSERT_EQ eax, -1
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_PEER

    mov     edi, TOR_ROLE_HS_RENDEZVOUS
    call    er_tor_enable_role
    ASSERT_EQ eax, 0
    call    er_tor_get_role_caps
    ASSERT_EQ eax, TOR_CAP_HS_PEER | TOR_CAP_HS_RENDEZVOUS

    mov     edi, TOR_CAP_KNOWN_MASK + 1
    call    er_tor_set_role_caps
    ASSERT_EQ eax, -1

; ================================================================
; Test 10: HSDir v3 publish POST header
; ================================================================
    TEST_DEBUG_LABEL "10"
    lea     rdi, [rel req_buf]
    mov     esi, 512
    mov     edx, 123
    call    er_tor_hsdir_build_publish_header
    ASSERT_EQ eax, hsdir_publish_expected_len
    ASSERT_MEM_EQ [rel hsdir_publish_expected], [rel req_buf], hsdir_publish_expected_len

; ================================================================
; Test 11: HSDir v3 descriptor fetch GET request
; ================================================================
    TEST_DEBUG_LABEL "11"
    lea     rdi, [rel req_buf]
    mov     esi, 512
    lea     rdx, [rel hsdir_blinded]
    mov     ecx, hsdir_blinded_len
    call    er_tor_hsdir_build_fetch_request
    ASSERT_EQ eax, hsdir_fetch_expected_len
    ASSERT_MEM_EQ [rel hsdir_fetch_expected], [rel req_buf], hsdir_fetch_expected_len

; ================================================================
; Test 12: identity route requires registered relay forwarding
; ================================================================
    TEST_DEBUG_LABEL "12"
    lea     rdi, [rel route_hash]
    lea     rsi, [rel route_cell]
    call    er_route_send
    ASSERT_RDX ERROR_LOCAL_NOT_FOUND

    lea     rdi, [rel route_hash]
    call    er_route_register_relay
    ASSERT_RDX 0

    lea     rdi, [rel route_hash]
    lea     rsi, [rel route_cell]
    call    er_route_send
    ASSERT_RDX 0
    lea     rax, [rel route_cell]
    ASSERT_EQ qword [rel last_relay_data], rax
    ASSERT_EQ dword [rel last_relay_len], LOCAL_CELL_SIZE

; ================================================================
; Test 13: relay route can be registered idempotently
; ================================================================
    TEST_DEBUG_LABEL "13"
    lea     rdi, [rel route_hash]
    call    er_route_register_relay
    ASSERT_RDX 0

    lea     rdi, [rel route_hash]
    lea     rsi, [rel route_cell]
    call    er_route_send
    ASSERT_RDX 0
    lea     rax, [rel route_cell]
    ASSERT_EQ qword [rel last_relay_data], rax

%ifdef TOR_BENCH
; ================================================================
; Local crypto bench: AES-CTR one Tor cell and batched cells
; ================================================================
    lea     rdi, [rel msg_bench_cell]
    call    putstr
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy
    call    rdtsc64
    mov     r12, rax
    lea     rdi, [rel bench_buf]
    lea     rsi, [rel bench_buf]
    mov     edx, TOR_CELL_LEN
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr
    call    rdtsc64
    sub     rax, r12
    mov     rdi, rax
    call    puthex64
    call    newline

    lea     rdi, [rel msg_bench_batch]
    call    putstr
    mov     r13d, 1024
    call    rdtsc64
    mov     r12, rax
.bench_loop:
    lea     rdi, [rel iv_copy]
    lea     rsi, [rel test_iv]
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [rel bench_buf]
    lea     rsi, [rel bench_buf]
    mov     edx, TOR_CELL_LEN
    lea     rcx, [rel test_key]
    lea     r8,  [rel iv_copy]
    call    er_tor_aes_ctr
    dec     r13d
    jnz     .bench_loop
    call    rdtsc64
    sub     rax, r12
    mov     rdi, rax
    call    puthex64
    call    newline
%endif

; ================================================================
; Done — report results
; ================================================================
    TEST_EXIT_FAILED

%ifdef TOR_BENCH
rdtsc64:
    lfence
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    ret

putstr:
    push    rdi
    xor     rdx, rdx
.len:
    cmp     byte [rdi + rdx], 0
    je      .write
    inc     rdx
    jmp     .len
.write:
    mov     rsi, rdi
    mov     edi, 1
    mov     eax, 1
    syscall
    pop     rdi
    ret

puthex64:
    push    rbx
    push    rcx
    push    rdx
    lea     rsi, [rel hexbuf + 18]
    mov     byte [rsi], 0
    mov     rbx, rdi
    mov     ecx, 16
.digit:
    dec     rsi
    mov     edx, ebx
    and     edx, 0x0f
    mov     dl, [rel hexdigits + rdx]
    mov     [rsi], dl
    shr     rbx, 4
    dec     ecx
    jnz     .digit
    dec     rsi
    mov     byte [rsi], 'x'
    dec     rsi
    mov     byte [rsi], '0'
    mov     edi, 1
    mov     edx, 18
    mov     eax, 1
    syscall
    pop     rdx
    pop     rcx
    pop     rbx
    ret

newline:
    mov     edi, 1
    lea     rsi, [rel nl]
    mov     edx, 1
    mov     eax, 1
    syscall
    ret

SECTION .data
msg_bench_cell: db "tor bench cell cycles: ", 0
msg_bench_batch: db "tor bench 1024 cells cycles: ", 0
hexdigits: db "0123456789abcdef"
nl: db 10
hexbuf: times 19 db 0
SECTION .text
%endif

global er_tor_cell_init
global er_tor_link_handshake
global er_tor_circuit_create
global er_tor_circuit_extend
global er_tor_send_relay
global er_tor_send_cell
global er_tor_recv_relay
global er_tor_open_stream
global er_tor_open_dir_stream
global er_tor_hs_desc_parse_intro
global er_tor_hs_desc_build_v3
global er_tor_hs_parse_linkspecs
global er_tor_hs_build_linkspecs
global er_tor_hs_client_connect
global er_tor_hs_client_connect_from_desc
global er_tor_hs_client_introduce_from_desc
global er_tor_hs_open_client_stream
global er_tor_hs_establish_intro
global er_tor_hs_wait_rendezvous2
global er_tor_hs_service_wait_introduce2
global er_tor_hs_parse_introduce_plaintext
global er_tor_hs_send_rendezvous1
global er_tor_hs_cert_build
global er_tor_hs_cert_armor_ed25519
global er_tor_ntor_keygen
global er_tcp_recv
global er_serial_puts
global er_serial_putchar
global er_serial_puthex32
global er_serial_crlf
global er_http_parse_status
global er_http_find_body
global er_tor_relay_crypt
global tor_conn_id
global tor_rx_cell
global tor_recv_len
global _wasm_import_da_surface_register
global _wasm_import_da_surface_update
global _wasm_import_da_surface_unregister

er_tor_cell_init:
er_tor_link_handshake:
er_tor_circuit_create:
er_tor_circuit_extend:
er_tor_recv_relay:
er_tor_open_stream:
er_tor_open_dir_stream:
er_tor_hs_desc_parse_intro:
er_tor_hs_desc_build_v3:
er_tor_hs_parse_linkspecs:
er_tor_hs_build_linkspecs:
er_tor_hs_client_connect:
er_tor_hs_client_connect_from_desc:
er_tor_hs_client_introduce_from_desc:
er_tor_hs_open_client_stream:
er_tor_hs_establish_intro:
er_tor_hs_wait_rendezvous2:
er_tor_hs_service_wait_introduce2:
er_tor_hs_parse_introduce_plaintext:
er_tor_hs_send_rendezvous1:
er_tor_hs_cert_build:
er_tor_hs_cert_armor_ed25519:
er_tor_ntor_keygen:
er_tcp_recv:
er_serial_puts:
er_serial_putchar:
er_serial_puthex32:
er_serial_crlf:
er_http_parse_status:
er_http_find_body:
er_tor_relay_crypt:
_wasm_import_da_surface_register:
_wasm_import_da_surface_update:
_wasm_import_da_surface_unregister:
    xor     eax, eax
    er_ok
    ret

er_tor_send_relay:
    mov     [rel last_relay_circ], edi
    mov     [rel last_relay_stream], esi
    mov     [rel last_relay_cmd], edx
    mov     [rel last_relay_data], rcx
    mov     [rel last_relay_len], r8d
    xor     eax, eax
    er_ok
    ret

er_tor_send_cell:
    mov     [rel last_relay_data], rdi
    mov     dword [rel last_relay_len], LOCAL_CELL_SIZE
    xor     eax, eax
    er_ok
    ret
