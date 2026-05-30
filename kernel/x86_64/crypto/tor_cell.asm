; EdgeRun Tor cell protocol — x86_64 assembly
; Cell I/O, link handshake, circuit management, relay cell processing.
;
; The Tor client uses 1 TCP connection to a guard relay.
; All circuit extend operations go through this guard connection.
;
; Dependencies: tcp.asm, tor_ntor.asm, tor_aes.asm, blake3.asm, tpm.asm

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_tcp_connect
extern er_tcp_send
extern er_tcp_recv
extern er_tcp_close
extern er_net_poll
extern er_memcpy
extern er_memset
extern er_serial_puts
extern er_serial_putchar
extern er_serial_puthex64
extern er_serial_puthex32
extern er_serial_crlf

extern er_tor_ntor_keygen
extern er_tor_ntor_client_handshake
extern er_tor_ntor_client_process
extern er_tor_curve25519_scalar_mult
extern er_tor_aes_ctr
extern er_tor_sha256

; ==================================================================
; BSS data
; ==================================================================
SECTION .bss

; Cell read/write buffers
tor_tx_cell: resb TOR_CELL_LEN      ; 514 bytes transmit
tor_rx_cell: resb TOR_CELL_LEN      ; 514 bytes receive
tor_var_cell: resb TOR_CELL_VAR_MAX + TOR_CELL_VAR_HEADER  ; variable-length cell

; TCP connection to guard relay
global tor_conn_id
global tor_rx_cell
global tor_recv_len
tor_conn_id:  resd 1                ; TCP connection ID
tor_link_established: resd 1        ; 0 = no, 1 = yes
tor_link_version: resd 1            ; negotiated link protocol version

; Circuit table
tor_circuits: resb TOR_CIRC_SIZE * TOR_MAX_CIRCUITS

; Stream table
tor_streams: resb TOR_STREAM_SIZE * TOR_MAX_STREAMS

; Temporary buffers for circuit operations
tor_tmp_buf: resb 512

; Digest work buffer (large enough for 32 bytes running + 509 cell payload = 541)
tor_digest_buf: resb 1024

; Per-hop key material (for multi-hop circuits)
; Each hop needs: forward_key(16), backward_key(16), forward_iv(16), backward_iv(16)
tor_hop_keys: resb 64 * TOR_MAX_RELAYS

; Stream ID allocator
tor_stream_next_id: resw 1

; Counter for circuit ID allocation
tor_circ_next_id: resd 1

; Debug/status
tor_status_msg: resb 128

SECTION .text

er_fn er_tor_cell_init
    ; Zero all BSS state
    mov     dword [tor_conn_id], -1
    mov     dword [tor_link_established], 0
    mov     dword [tor_link_version], 0
    mov     dword [tor_circ_next_id], 1
    mov     word [tor_stream_next_id], 1

    ; Clear circuit table
    mov     edi, tor_circuits
    xor     esi, esi
    mov     edx, TOR_CIRC_SIZE * TOR_MAX_CIRCUITS
    call    er_memset

    ; Clear stream table
    mov     edi, tor_streams
    xor     esi, esi
    mov     edx, TOR_STREAM_SIZE * TOR_MAX_STREAMS
    call    er_memset

    er_ok
    er_ret

; ==================================================================
; _tor_circ_ptr — get circuit table entry pointer
; rdi = circuit_id (0..TOR_MAX_CIRCUITS-1)
; returns rax = pointer, or 0 if invalid
; ==================================================================
_tor_circ_ptr:
    cmp     edi, TOR_MAX_CIRCUITS
    jae     .bad
    mov     eax, edi
    imul    eax, TOR_CIRC_SIZE
    add     rax, tor_circuits
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    ret

; ==================================================================
; _tor_stream_ptr — get stream table entry pointer
; rdi = stream_id (0..TOR_MAX_STREAMS-1)
; returns rax = pointer, or 0 if invalid
; ==================================================================
_tor_stream_ptr:
    cmp     edi, TOR_MAX_STREAMS
    jae     .bad
    mov     eax, edi
    imul    eax, TOR_STREAM_SIZE
    add     rax, tor_streams
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    ret

_tor_cell_send:
    mov     edi, [tor_conn_id]
    mov     rsi, rsi        ; cell
    mov     edx, TOR_CELL_LEN
    call    er_tcp_send
    ret

_tor_cell_recv:
    push    rbx
    mov     rbx, rsi        ; cell buffer

    ; Receive cell header (5 bytes) first
    mov     edi, [tor_conn_id]
    mov     rsi, rbx
    lea     rdx, [tor_recv_len]
    call    er_tcp_recv

    ; Receive remainder of cell
    ; TCP recv may return partial data; keep reading until full
    mov     edi, [tor_conn_id]
    lea     rsi, [rbx + 5]
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], 509
    call    er_tcp_recv

    xor     eax, eax
    er_ok
    pop     rbx
    ret

SECTION .data
global tor_recv_len
tor_recv_len: dd 0

SECTION .text

_tor_build_versions_cell:
    ; circ_id = 0
    mov     dword [rdi + TOR_VAR_CIRC_ID], 0
    ; cmd = VERSIONS
    mov     byte [rdi + TOR_VAR_CMD], TOR_CELL_VERSIONS
    ; len = 4 (two 16-bit versions)
    mov     word [rdi + TOR_VAR_LEN], 0x0004  ; big-endian
    ; versions: [4, 5]
    mov     word [rdi + TOR_VAR_PAYLOAD], 0x0004
    mov     word [rdi + TOR_VAR_PAYLOAD + 2], 0x0005
    ret

_tor_parse_versions:
    push    rbx
    mov     rbx, rdi        ; cell

    ; Cell is variable-length
    ; payload starts at offset 7
    lea     rsi, [rbx + TOR_VAR_PAYLOAD]
    movzx   ecx, word [rbx + TOR_VAR_LEN]
    xchg    cl, ch           ; big-endian to host
    shr     ecx, 1           ; number of version entries

    xor     eax, eax         ; result = -1
    dec     eax

.check_ver:
    test    ecx, ecx
    jz      .done
    movzx   r8d, word [rsi]
    xchg    r8b, r8b         ; big-endian to host

    ; Check if we support this version (4 or 5)
    cmp     r8w, TOR_LINK_V4
    je      .found
    cmp     r8w, TOR_LINK_V5
    je      .found
    cmp     r8w, TOR_LINK_V3
    je      .found

    add     rsi, 2
    dec     ecx
    jmp     .check_ver

.found:
    movzx   eax, r8w        ; return this version

.done:
    pop     rbx
    ret

_tor_build_netinfo_cell:
    ; circ_id = 0
    mov     dword [rdi + TOR_VAR_CIRC_ID], 0
    ; cmd = NETINFO
    mov     byte [rdi + TOR_VAR_CMD], TOR_CELL_NETINFO
    ; len = 2 (+ timestamp + my_addr + other_addr)
    ; Minimal: timestamp=0, my_addr type=4 (IPv4), len=4, addr=0, other=0
    ; Total: 2 + 4 + 1 + 1 + 4 + 1 + 0 = 13
    mov     word [rdi + TOR_VAR_LEN], 0x000D

    ; Timestamp (4 bytes, big-endian)
    mov     dword [rdi + TOR_VAR_PAYLOAD], 0

    ; My address: type=4 (IPv4), len=4
    mov     byte [rdi + TOR_VAR_PAYLOAD + 4], 4
    mov     byte [rdi + TOR_VAR_PAYLOAD + 5], 4
    ; IP address (big-endian, 0 = any)
    mov     dword [rdi + TOR_VAR_PAYLOAD + 6], 0

    ; Other addresses: type=0 (none)
    mov     byte [rdi + TOR_VAR_PAYLOAD + 10], 0

    ret

_tor_build_certs_cell:
    ; circ_id = 0
    mov     dword [rdi + TOR_VAR_CIRC_ID], 0
    ; cmd = CERTS
    mov     byte [rdi + TOR_VAR_CMD], TOR_CELL_CERTS
    ; len = 3 (n_certs=0)
    mov     word [rdi + TOR_VAR_LEN], 0x0001
    ; n_certs = 0 (no certs for anonymous auth)
    mov     byte [rdi + TOR_VAR_PAYLOAD], 0
    ret

_tor_build_authenticate_cell:
    push    rbx
    mov     rbx, rdi        ; cell
    ; rsi = challenge (32 bytes)

    ; circ_id = 0
    mov     dword [rbx + TOR_VAR_CIRC_ID], 0
    ; cmd = AUTHENTICATE
    mov     byte [rbx + TOR_VAR_CMD], TOR_CELL_AUTHENTICATE
    ; len = 1 (auth_type = ANON, no body)
    mov     word [rbx + TOR_VAR_LEN], 0x0001
    ; Auth type = 5 (anonymous)
    mov     byte [rbx + TOR_VAR_PAYLOAD], TOR_AUTHTYPE_ANON

    pop     rbx
    ret

er_fn er_tor_link_handshake
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; guard_ip (network order)
    mov     r13w, si        ; guard_port (host order)

    ; Retry TCP connect until it succeeds (handles ARP resolution).
    ; The connect may fail with ERROR_ARP_PENDING — er_net_poll
    ; processes ARP replies and populates the cache between retries.
    mov     ebx, 3               ; retry counter (ecx used for args)
.connect_retry:
    mov     edi, r12d
    mov     esi, r13d
    xor     edx, edx            ; src_ip = 0
    xor     ecx, ecx            ; src_port = 0 (auto)
    call    er_tcp_connect
    test    eax, eax
    jns     .connected2
    ; Print return value hex on first failure
    cmp     ebx, 3
    jne     .skip_dbg
    push    rax
    push    rdx
    mov     edi, 0x3f8
    mov     esi, 'e'
    call    er_serial_putchar
    pop     rdx
    mov     edi, 0x3f8
    mov     esi, edx
    call    er_serial_puthex32
    push    rdx
    mov     edi, 0x3f8
    mov     esi, ':'
    call    er_serial_putchar
    pop     rdx
    pop     rax
    mov     edi, 0x3f8
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, 0x3f8
    mov     esi, ' '
    call    er_serial_putchar
.skip_dbg:
    push    rbx
    call    er_net_poll
    pop     rbx
    dec     ebx
    jnz     .connect_retry
    jmp     .connect_fail

.connected2:
    mov     [tor_conn_id], eax

    ; Build VERSIONS cell once (before the poll loop)
    mov     rdi, tor_var_cell
    call    _tor_build_versions_cell

    ; Wait for TCP 3-way handshake to complete by polling
    ; er_net_poll and retrying er_tcp_send until it succeeds.
    ; The connection starts in SYN_SENT; er_net_poll processes
    ; the SYN-ACK from the host and completes the handshake.
    mov     ecx, 500
.wait_established:
    push    rcx
    call    er_net_poll
    pop     rcx

    push    rcx
    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    mov     edx, TOR_VAR_HEADER + 4
    call    er_tcp_send
    pop     rcx

    test    eax, eax
    jns     .versions_sent
    dec     ecx
    jnz     .wait_established
    jmp     .connect_fail

.versions_sent:

    ; Read VERSIONS cell response
    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_VAR_HEADER + 4
    call    er_tcp_recv
    test    eax, eax
    js      .recv_fail

    ; Check command is VERSIONS
    cmp     byte [tor_var_cell + TOR_VAR_CMD], TOR_CELL_VERSIONS
    jne     .proto_fail

    ; Parse versions
    mov     rdi, tor_var_cell
    call    _tor_parse_versions
    test    eax, eax
    js      .proto_fail

    mov     [tor_link_version], eax

    ; Send CERTS cell (no certs for anonymous)
    mov     rdi, tor_var_cell
    call    _tor_build_certs_cell

    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    movzx   edx, word [tor_var_cell + TOR_VAR_LEN]
    xchg    dl, dh
    add     edx, TOR_VAR_HEADER
    call    er_tcp_send
    test    eax, eax
    js      .send_fail

    ; Wait for CERTS from relay
    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], 256
    call    er_tcp_recv
    test    eax, eax
    js      .recv_fail

    ; Should be CERTS cell
    cmp     byte [tor_var_cell + TOR_VAR_CMD], TOR_CELL_CERTS
    jne     .proto_fail

    ; Wait for AUTH_CHALLENGE
    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], 256
    call    er_tcp_recv
    test    eax, eax
    js      .recv_fail

    ; Should be AUTH_CHALLENGE
    cmp     byte [tor_var_cell + TOR_VAR_CMD], TOR_CELL_AUTH_CHALLENGE
    jne     .proto_fail

    ; Extract challenge from AUTH_CHALLENGE payload
    ; Format: challenge_len(2) + challenge(len) + methods_len(1) + methods
    lea     rsi, [tor_var_cell + TOR_VAR_PAYLOAD]

    ; Send AUTHENTICATE (anonymous)
    mov     rdi, tor_var_cell
    call    _tor_build_authenticate_cell

    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    mov     edx, TOR_VAR_HEADER + 1  ; 1 byte auth type
    call    er_tcp_send
    test    eax, eax
    js      .send_fail

    ; Send NETINFO
    mov     rdi, tor_var_cell
    call    _tor_build_netinfo_cell

    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    movzx   edx, word [tor_var_cell + TOR_VAR_LEN]
    xchg    dl, dh
    add     edx, TOR_VAR_HEADER
    call    er_tcp_send
    test    eax, eax
    js      .send_fail

    ; Wait for NETINFO from relay
    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], 256
    call    er_tcp_recv
    test    eax, eax
    js      .recv_fail

    ; Verify NETINFO
    cmp     byte [tor_var_cell + TOR_VAR_CMD], TOR_CELL_NETINFO
    jne     .proto_fail

    ; Link established!
    mov     dword [tor_link_established], 1

    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.connect_fail:
    mov     dword [tor_conn_id], -1
    mov     eax, -1
    er_err  ERROR_TOR_LINK_FAILED
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.send_fail:
.recv_fail:
.proto_fail:
    mov     dword [tor_link_established], 0
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

_tor_send_create2:
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi       ; circ_id
    mov     r13, rsi        ; handshake_data
    mov     ebx, edx        ; handshake_len

    ; Build fixed-length cell in tor_tx_cell
    mov     rdi, tor_tx_cell
    xor     eax, eax
    mov     ecx, TOR_CELL_LEN
    call    er_memset

    ; circ_id (4 bytes for v4+)
    mov     [tor_tx_cell], r12d

    ; cmd = CREATE2
    mov     byte [tor_tx_cell + 4], TOR_CELL_CREATE2

    ; Payload: htype(2) + hlen(2) + handshake_data
    ; htype = 0x0002 (ntor) at payload offset 0 (= cell offset 5)
    mov     word [tor_tx_cell + 5], 0x0002

    ; hlen (big-endian)
    mov     eax, ebx
    xchg    ah, al
    mov     [tor_tx_cell + 7], ax

    ; handshake_data (84 bytes for ntor)
    mov     rdi, tor_tx_cell
    add     rdi, 9           ; after htype + hlen
    mov     rsi, r13
    mov     edx, ebx
    call    er_memcpy

    ; Send cell over TCP
    mov     edi, [tor_conn_id]
    mov     rsi, tor_tx_cell
    mov     edx, TOR_CELL_LEN
    call    er_tcp_send

    pop     r13
    pop     r12
    pop     rbx
    ret

_tor_recv_created2:
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi       ; circ_id
    mov     r13, rsi        ; reply buffer
    mov     r14, rdx        ; reply_len ptr

    ; Read cell from TCP
    mov     edi, [tor_conn_id]
    mov     rsi, tor_rx_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_CELL_LEN
    call    er_tcp_recv
    test    eax, eax
    js      .fail

    ; Verify cmd = CREATED2 (v4+: offset 4)
    cmp     byte [tor_rx_cell + 4], TOR_CELL_CREATED2
    jne     .fail

    ; Parse reply: htype(2) + hlen(2) + data
    movzx   ecx, word [tor_rx_cell + 7]  ; hlen (big-endian)
    xchg    cl, ch

    ; Copy handshake data to reply buffer
    lea     rsi, [tor_rx_cell + 9]       ; after htype + hlen
    mov     rdi, r13
    mov     edx, ecx
    call    er_memcpy

    ; Set reply length
    mov     dword [r14], ecx

    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.fail:
    mov     eax, -1
    er_err  ERROR_TOR_CIRC_BUILD_FAIL
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

_tor_build_extend2:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; cell
    mov     r13d, esi       ; circ_id
    mov     r14w, dx        ; stream_id
    mov     r15, rcx        ; node_id
    ; r8 = onion_key
    ; r9 = handshake[84]

    ; Build cell header: circ_id(4) + cmd(RELAY_EARLY)
    mov     [r12], r13d
    mov     byte [r12 + 4], TOR_CELL_RELAY_EARLY

    ; Relay header (cell payload offset 5):
    mov     [r12 + 5], r14w        ; stream_id (2 bytes)
    mov     dword [r12 + 7], 0     ; digest (zeroed, computed before encrypt)
    ; data_len (big-endian) — EXTEND2 body size
    mov     eax, 119
    xchg    ah, al
    mov     [r12 + 11], ax
    mov     byte [r12 + 13], TOR_RELAY_EXTEND2  ; relay cmd
    mov     word [r12 + 14], 0     ; recognized = 0

    ; EXTEND2 body starts at cell offset 16
    ; NSPEC = 2
    mov     byte [r12 + 16], 2

    ; Specifier 1: IPv4 socket (LSTYPE=2, LSLEN=6)
    mov     byte [r12 + 17], 2     ; LSTYPE = IPv4
    mov     byte [r12 + 18], 6     ; LSLEN = 6
    ; IP and port — use zeros (will be filled by caller or default)
    mov     dword [r12 + 19], 0    ; IP (4 bytes, network order)
    mov     word  [r12 + 23], 0    ; PORT (2 bytes, network order)

    ; Specifier 2: Legacy ID (LSTYPE=4, LSLEN=20)
    mov     byte [r12 + 25], 4     ; LSTYPE = legacy ID
    mov     byte [r12 + 26], 20    ; LSLEN = 20
    mov     rdi, r12
    add     rdi, 27
    mov     rsi, r15               ; node_id (20 bytes)
    mov     edx, 20
    call    er_memcpy

    ; Handshake type: ntor = 0x0002 (big-endian)
    mov     byte [r12 + 47], 0
    mov     byte [r12 + 48], 2

    ; Handshake data length: 84 (big-endian)
    mov     byte [r12 + 49], 0
    mov     byte [r12 + 50], 84

    ; Handshake data (84 bytes)
    mov     rdi, r12
    add     rdi, 51
    mov     rsi, r9                ; handshake[84] (NODE_ID||KEY_ID||X)
    mov     edx, 84
    call    er_memcpy

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

_tor_parse_extended2:
    push    rbx
    push    r12

    mov     r12, rdi        ; relay_body
    mov     ebx, esi        ; body_len

    ; Need at least 4 bytes (HTYPE + HLEN)
    cmp     ebx, 4
    jb      .bad

    ; Check handshake type is ntor (0x0002, big-endian → LE word = 0x0200)
    cmp     word [r12], 0x0200
    jne     .bad

    ; Read HLEN (big-endian)
    movzx   eax, byte [r12 + 2]
    shl     eax, 8
    movzx   ecx, byte [r12 + 3]
    or      eax, ecx

    ; ntor reply is 64 bytes (Y||AUTH)
    cmp     eax, 64
    jne     .bad

    ; Check body_len is enough
    cmp     ebx, 68         ; 4 + 64
    jb      .bad

    ; Copy HDATA to output
    mov     rdi, rdx        ; out_handshake_reply
    lea     rsi, [r12 + 4]
    mov     edx, 64
    call    er_memcpy

    xor     eax, eax
    pop     r12
    pop     rbx
    ret

.bad:
    mov     eax, -1
    pop     r12
    pop     rbx
    ret

global er_tor_relay_crypt
er_tor_relay_crypt:
    push    rbx
    push    r12
    push    r13
    push    r14              ; save cell pointer

    mov     r14, rdi         ; save original cell pointer
    mov     r12d, esi        ; circ_id
    mov     r13d, edx        ; direction

    ; Get circuit pointer
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .bad

    mov     rbx, rax         ; circuit entry

    ; Select forward or backward keys
    test    r13d, r13d
    jnz     .backward

    ; Forward: encrypt outgoing data
    lea     rcx, [rbx + TOR_CIRC_FORWARD_KEY]
    lea     r8,  [rbx + TOR_CIRC_FORWARD_IV]
    jmp     .do_crypt

.backward:
    lea     rcx, [rbx + TOR_CIRC_BACKWARD_KEY]
    lea     r8,  [rbx + TOR_CIRC_BACKWARD_IV]

.do_crypt:
    ; Encrypt cell payload (bytes 5..514, 509 bytes)
    mov     rdi, r14         ; restore cell pointer
    add     rdi, 5           ; payload starts at offset 5
    mov     rsi, rdi         ; in-place encryption
    mov     edx, 509
    ; rcx = key ptr, r8 = iv ptr
    call    er_tor_aes_ctr

.bad:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

er_fn er_tor_circuit_create
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; out_circ_id ptr
    mov     r13, rsi        ; node_id (20)
    mov     r14, rdx        ; onion_key (32)

    ; Allocate circuit ID
    mov     eax, [tor_circ_next_id]
    cmp     eax, TOR_MAX_CIRCUITS
    jae     .full

    mov     r15d, eax       ; circuit id
    inc     dword [tor_circ_next_id]

    ; Initialize circuit entry
    mov     edi, r15d
    call    _tor_circ_ptr
    mov     rbx, rax        ; circuit entry

    mov     dword [rbx + TOR_CIRC_STATE], TOR_CIRC_OPENING
    mov     dword [rbx + TOR_CIRC_CONN_ID], r15d
    mov     dword [rbx + TOR_CIRC_N_HOPS], 0
    mov     dword [rbx + TOR_CIRC_RX_BUF_LEN], 0

    ; Stack layout: [handshake_out(84) + handshake_len(4) + padding +
    ;                client_priv(32) + client_pub(32) + reply(64) + reply_len(4)]
    sub     rsp, 256

    ; Call er_tor_ntor_client_handshake to build CREATE2 body
    ; rdi = handshake_out, rsi = handshake_len, rdx = node_id,
    ; rcx = onion_key, r8 = client_priv, r9 = client_pub
    mov     rdi, rsp         ; handshake_out
    lea     rsi, [rsp + 84]  ; handshake_len
    mov     rdx, r13         ; node_id
    mov     rcx, r14         ; onion_key
    lea     r8,  [rsp + 88]  ; client_priv
    lea     r9,  [rsp + 120] ; client_pub
    call    er_tor_ntor_client_handshake
    test    eax, eax
    js      .build_fail

    ; Send CREATE2
    mov     edi, r15d
    mov     rsi, rsp
    mov     edx, 84
    call    _tor_send_create2

    ; Wait for CREATED2
    lea     rsi, [rsp + 152] ; reply buffer
    lea     rdx, [rsp + 216] ; reply_len ptr
    mov     edi, r15d
    call    _tor_recv_created2
    test    eax, eax
    js      .build_fail

    ; Full ntor key derivation via er_tor_ntor_client_process
    ; Push stack params: backward_key, forward_iv, backward_iv
    lea     rax, [rbx + TOR_CIRC_BACKWARD_IV]
    push    rax
    lea     rax, [rbx + TOR_CIRC_FORWARD_IV]
    push    rax
    lea     rax, [rbx + TOR_CIRC_BACKWARD_KEY]
    push    rax

    ; rdi = handshake_reply = [rsp+152+24] (reply = Y || AUTH)
    lea     rdi, [rsp + 152 + 24]  ; reply buffer
    mov     rsi, r13               ; node_id
    mov     rdx, r14               ; onion_key
    lea     rcx, [rsp + 88 + 24]   ; client_priv
    lea     r8,  [rsp + 120 + 24]  ; client_pub
    lea     r9,  [rbx + TOR_CIRC_FORWARD_KEY]  ; forward_key
    call    er_tor_ntor_client_process
    add     rsp, 24                ; pop stack params
    test    eax, eax
    js      .build_fail

    ; Mark circuit open
    mov     dword [rbx + TOR_CIRC_STATE], TOR_CIRC_OPEN
    mov     dword [rbx + TOR_CIRC_N_HOPS], 1

    ; Return circuit ID
    mov     dword [r12], r15d

    add     rsp, 256
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.full:
    mov     eax, -1
    er_err  ERROR_BUSY
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.build_fail:
    mov     dword [rbx + TOR_CIRC_STATE], TOR_CIRC_CLOSED
    add     rsp, 256
    mov     eax, -1
    er_err  ERROR_TOR_CIRC_BUILD_FAIL
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

er_fn er_tor_send_relay
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; circ_id
    mov     r13w, si        ; stream_id
    mov     r14d, edx       ; relay_cmd
    mov     r15, rcx        ; data
    mov     ebx, r8d        ; data_len

    ; Build relay cell in tor_tx_cell
    mov     rdi, tor_tx_cell
    xor     eax, eax
    mov     ecx, TOR_CELL_LEN
    call    er_memset

    ; Cell header (v4+): circ_id(4) + cmd(1)
    mov     [tor_tx_cell], r12d    ; circ_id (4 bytes)
    mov     byte [tor_tx_cell + 4], TOR_CELL_RELAY

    ; Relay header (inside cell payload, offset 5 = TOR_CELL_PAYLOAD)
    ; stream_id (2 bytes)
    mov     [tor_tx_cell + 5], r13w

    ; digest (4 bytes) — zero for now
    mov     dword [tor_tx_cell + 7], 0

    ; relay_data_len (2 bytes, big-endian)
    mov     eax, ebx
    xchg    ah, al
    mov     [tor_tx_cell + 11], ax

    ; relay_cmd (1 byte)
    mov     [tor_tx_cell + 13], r14b

    ; recognized (2 bytes) — usually 0
    mov     word [tor_tx_cell + 14], 0

    ; Relay payload starts at offset 16 (cell_header(5) + relay_header(11))
    cmp     ebx, 0
    je      .no_data
    mov     rdi, tor_tx_cell
    add     rdi, 16
    mov     rsi, r15
    mov     edx, ebx
    call    er_memcpy

.no_data:
    ; ============================================================
    ; Compute relay digest using forward running hash
    ; forward_digest = SHA256(forward_digest || cell_payload[0..508])
    ; digest_field = first 4 bytes of forward_digest
    ; ============================================================
    ; Get circuit pointer
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .no_digest

    ; Build input at tor_digest_buf: forward_digest[32] || cell_payload[509]
    ; Cell payload = bytes 5..513 of tor_tx_cell (509 bytes including relay header)
    mov     rdi, tor_digest_buf
    lea     rsi, [rax + TOR_CIRC_FORWARD_DIGEST]
    mov     edx, 32
    call    er_memcpy

    mov     rdi, tor_digest_buf + 32
    lea     rsi, [tor_tx_cell + 5]   ; cell payload (509 bytes)
    mov     edx, 509
    call    er_memcpy

    ; Compute SHA256(input, 541) → output to tor_digest_buf + 541
    mov     rdi, tor_digest_buf      ; input
    mov     esi, 541                 ; input length
    lea     rdx, [tor_digest_buf + 541] ; output (32 bytes)
    call    er_tor_sha256
    test    eax, eax
    jz      .no_digest

    ; Write first 4 bytes of new digest into cell's digest field
    mov     eax, [tor_digest_buf + 541]
    mov     [tor_tx_cell + 7], eax

    ; Update circuit's forward_digest with new full digest
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .no_digest
    mov     rdi, rax
    add     rdi, TOR_CIRC_FORWARD_DIGEST
    lea     rsi, [tor_digest_buf + 541]
    mov     edx, 32
    call    er_memcpy

.no_digest:
    ; Encrypt cell payload with circuit's forward key
    mov     edi, tor_tx_cell
    mov     esi, r12d       ; circ_id
    xor     edx, edx        ; forward direction
    call    er_tor_relay_crypt

    ; Send over TCP
    mov     edi, [tor_conn_id]
    mov     rsi, tor_tx_cell
    mov     edx, TOR_CELL_LEN
    call    er_tcp_send
    test    eax, eax
    js      .send_fail

    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.send_fail:
    mov     eax, -1
    er_err  ERROR_IO
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

er_fn er_tor_recv_relay
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; circ_id
    mov     r13, rsi        ; out_stream_id
    mov     r14, rdx        ; out_cmd
    mov     r15, rcx        ; out_data
    ; r8 = out_data_len

    ; Read cell from TCP
    mov     edi, [tor_conn_id]
    mov     rsi, tor_rx_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_CELL_LEN
    call    er_tcp_recv
    test    eax, eax
    js      .fail

    ; Verify circ_id matches
    mov     eax, [tor_rx_cell]
    cmp     eax, r12d
    jne     .fail

    ; Decrypt with circuit's backward key
    mov     edi, tor_rx_cell
    mov     esi, r12d
    mov     edx, 1           ; backward direction
    call    er_tor_relay_crypt

    ; ============================================================
    ; Verify relay digest
    ; ============================================================
    ; Save the current digest field (4 bytes)
    mov     eax, [tor_rx_cell + 7]
    push    rax

    ; Zero the digest field for recomputation
    mov     dword [tor_rx_cell + 7], 0

    ; Get circuit pointer
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .digest_skip

    push    rax                          ; save circuit ptr

    ; Build input at tor_digest_buf: backward_digest[32] || cell_payload[509]
    mov     rdi, tor_digest_buf
    lea     rsi, [rax + TOR_CIRC_BACKWARD_DIGEST]
    mov     edx, 32
    call    er_memcpy

    mov     rdi, tor_digest_buf + 32
    lea     rsi, [tor_rx_cell + 5]
    mov     edx, 509
    call    er_memcpy

    ; SHA256(input, 541) → output
    mov     rdi, tor_digest_buf
    mov     esi, 541
    lea     rdx, [tor_digest_buf + 541]
    call    er_tor_sha256
    test    eax, eax
    jz      .digest_skip_pop

    ; Compare first 4 bytes with saved digest
    mov     eax, [tor_digest_buf + 541]
    pop     rcx                          ; saved digest (from push at start)
    cmp     eax, ecx
    jne     .digest_fail

    ; Update circuit's backward_digest
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .digest_skip
    mov     rdi, rax
    add     rdi, TOR_CIRC_BACKWARD_DIGEST
    lea     rsi, [tor_digest_buf + 541]
    mov     edx, 32
    call    er_memcpy
    jmp     .digest_skip

.digest_fail:
    ; Digest mismatch — signal error
    add     rsp, 16          ; pop circuit ptr + saved digest
    jmp     .fail

.digest_skip_pop:
    pop     rax              ; circuit ptr (not needed)
.digest_skip:
    pop     rax              ; saved digest value (from the push)

    ; Parse relay header
    movzx   ecx, word [tor_rx_cell + 5]   ; stream_id
    mov     [r13], cx

    mov     al, byte [tor_rx_cell + 13]   ; relay_cmd
    mov     [r14], al

    movzx   ecx, word [tor_rx_cell + 11]  ; data_len (big-endian)
    xchg    cl, ch

    ; Copy relay data to output
    mov     [r8], ecx

    cmp     ecx, 0
    je      .done

    mov     rdi, r15        ; out_data
    lea     rsi, [tor_rx_cell + 16]  ; relay data
    mov     edx, ecx
    call    er_memcpy

.done:
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

er_fn er_tor_open_stream
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi       ; circ_id
    mov     r13d, esi       ; dst_ip
    mov     r14w, dx        ; dst_port
    ; rcx = out_stream_id

    ; Allocate stream ID
    movzx   eax, word [tor_stream_next_id]
    cmp     eax, TOR_MAX_STREAMS
    jae     .full
    mov     r15w, ax
    inc     word [tor_stream_next_id]

    ; Build RELAY_BEGIN payload: target address
    ; Format: "host:port\0" for the destination
    ; For IPv4: "1.2.3.4:80\0"
    ; For simplicity, we use a dotted-decimal format
    ; Actually, for Tor, RELAY_BEGIN uses a hostname or IP string
    ; We'll format the IP as a string

    ; Build address string on stack
    sub     rsp, 64
    mov     rdi, rsp
    ; Format: IP in dotted decimal + ":" + port + "\0"
    ; Max: "255.255.255.255:65535\0" = 21 bytes

    ; Extract bytes from IP (network order)
    movzx   eax, r13b      ; first byte
    call    .push_byte
    mov     byte [rdi], '.'
    inc     rdi

    movzx   eax, r13b
    shr     eax, 8
    call    .push_byte
    mov     byte [rdi], '.'
    inc     rdi

    movzx   eax, r13b
    shr     eax, 16
    call    .push_byte
    mov     byte [rdi], '.'
    inc     rdi

    movzx   eax, r13b
    shr     eax, 24
    call    .push_byte

    ; Add port
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, r14w
    call    .push_byte

    ; Null terminate
    mov     byte [rdi], 0
    inc     rdi

    ; Calculate address string length
    sub     rdi, rsp
    mov     r14d, edi       ; addr_str_len

    ; Send RELAY_BEGIN
    mov     edi, r12d       ; circ_id
    movzx   esi, r15w       ; stream_id
    mov     edx, TOR_RELAY_BEGIN
    mov     rcx, rsp        ; data = stack buffer (address string)
    mov     r8d, r14d       ; data_len = address string length
    call    er_tor_send_relay

    add     rsp, 64
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.full:
    mov     eax, -1
    er_err  ERROR_BUSY
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; Helper to push a decimal number as string
.push_byte:
    push    rbx
    push    rdx
    xor     ecx, ecx
    mov     ebx, 10
.div_loop:
    xor     edx, edx
    div     ebx
    add     edx, '0'
    push    rdx
    inc     ecx
    test    eax, eax
    jnz     .div_loop

.write_loop:
    pop     rax
    mov     [rdi], al
    inc     rdi
    dec     ecx
    jnz     .write_loop

    pop     rdx
    pop     rbx
    ret
