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
%include "x86_64/crypto/tls_constants.inc"

extern er_tcp_connect
extern er_tcp_get_state
extern er_tls_connect
extern er_tls_send
extern er_tls_recv
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

; _tor_hop_ptr(circ_ptr, hop_index) -> rax
; Returns a per-hop key/digest slot inside the circuit entry.
_tor_hop_ptr:
    cmp     esi, TOR_CIRC_MAX_HOPS
    jae     .bad
    mov     eax, esi
    imul    eax, TOR_CIRC_HOP_SIZE
    lea     rax, [rdi + TOR_CIRC_NTOR_KEYS + rax]
    ret
.bad:
    xor     eax, eax
    ret

; _tor_endpoint_hop_ptr(circ_ptr) -> rax
; Returns the current terminal hop slot for relay digest accounting.
_tor_endpoint_hop_ptr:
    mov     esi, [rdi + TOR_CIRC_N_HOPS]
    test    esi, esi
    jz      .bad
    dec     esi
    jmp     _tor_hop_ptr
.bad:
    xor     eax, eax
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

global er_tor_send_cell
er_tor_send_cell:
    mov     rsi, rdi        ; cell
    mov     edi, [tor_conn_id]
    mov     edx, TOR_CELL_LEN
    call    er_tls_send
    ret

_tor_cell_send:
    mov     edi, [tor_conn_id]
    mov     rsi, rsi        ; cell
    mov     edx, TOR_CELL_LEN
    call    er_tls_send
    ret

_tor_cell_recv:
    push    rbx
    mov     rbx, rsi        ; cell buffer

    ; Receive cell header (5 bytes) first
    mov     edi, [tor_conn_id]
    mov     rsi, rbx
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_CELL_HEADER_LEN
    call    er_tls_recv
    test    eax, eax
    js      .fail
    cmp     dword [tor_recv_len], TOR_CELL_HEADER_LEN
    jne     .fail

    ; Receive remainder of cell
    ; TCP recv may return partial data; keep reading until full
    mov     edi, [tor_conn_id]
    lea     rsi, [rbx + TOR_CELL_HEADER_LEN]
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_CELL_PAYLOAD_LEN
    call    er_tls_recv
    test    eax, eax
    js      .fail
    cmp     dword [tor_recv_len], TOR_CELL_PAYLOAD_LEN
    jne     .fail

    xor     eax, eax
    er_ok
    pop     rbx
    ret
.fail:
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
    pop     rbx
    ret

_tor_recv_versions_cell:
    push    rbx
    push    r12

    mov     rbx, rdi
    mov     edi, [tor_conn_id]
    mov     rsi, rbx
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_VERSIONS_HEADER
    call    er_tls_recv
    test    eax, eax
    js      .fail
    cmp     dword [tor_recv_len], TOR_VERSIONS_HEADER
    jne     .fail
    cmp     byte [rbx + 2], TOR_CELL_VERSIONS
    jne     .fail

    movzx   r12d, word [rbx + 3]
    rol     r12w, 8
    cmp     r12d, TOR_CELL_VAR_MAX
    ja      .fail
    test    r12d, 1
    jnz     .fail

    mov     edi, [tor_conn_id]
    lea     rsi, [rbx + TOR_VERSIONS_HEADER]
    lea     rdx, [tor_recv_len]
    mov     [rdx], r12d
    call    er_tls_recv
    test    eax, eax
    js      .fail
    cmp     [tor_recv_len], r12d
    jne     .fail

    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    ret
.fail:
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
    pop     r12
    pop     rbx
    ret

_tor_recv_var_cell:
    push    rbx
    push    r12

    mov     rbx, rdi
    mov     edi, [tor_conn_id]
    mov     rsi, rbx
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_VAR_HEADER
    call    er_tls_recv
    test    eax, eax
    js      .fail
    cmp     dword [tor_recv_len], TOR_VAR_HEADER
    jne     .fail

    movzx   r12d, word [rbx + TOR_VAR_LEN]
    rol     r12w, 8
    cmp     r12d, TOR_CELL_VAR_MAX
    ja      .fail

    mov     edi, [tor_conn_id]
    lea     rsi, [rbx + TOR_VAR_PAYLOAD]
    lea     rdx, [tor_recv_len]
    mov     [rdx], r12d
    call    er_tls_recv
    test    eax, eax
    js      .fail
    cmp     [tor_recv_len], r12d
    jne     .fail

    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    ret
.fail:
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
    pop     r12
    pop     rbx
    ret

SECTION .data
global tor_recv_len
tor_recv_len: dd 0

SECTION .text

_tor_build_versions_cell:
    ; circ_id = 0
    mov     word [rdi], 0
    ; cmd = VERSIONS
    mov     byte [rdi + 2], TOR_CELL_VERSIONS
    ; len = 4 (two 16-bit versions)
    mov     byte [rdi + 3], 0
    mov     byte [rdi + 4], 4
    ; versions: [4, 5]
    mov     byte [rdi + TOR_VERSIONS_HEADER], 0
    mov     byte [rdi + TOR_VERSIONS_HEADER + 1], TOR_LINK_V4
    mov     byte [rdi + TOR_VERSIONS_HEADER + 2], 0
    mov     byte [rdi + TOR_VERSIONS_HEADER + 3], TOR_LINK_V5
    ret

_tor_parse_versions:
    push    rbx
    mov     rbx, rdi        ; cell

    ; Cell is variable-length
    ; Initial VERSIONS uses v=0, so the payload starts after a
    ; 2-byte CircID, 1-byte command, and 2-byte length.
    lea     rsi, [rbx + TOR_VERSIONS_HEADER]
    movzx   ecx, word [rbx + 3]
    xchg    cl, ch           ; big-endian to host
    shr     ecx, 1           ; number of version entries

    xor     eax, eax         ; highest supported common version

.check_ver:
    test    ecx, ecx
    jz      .done_check
    movzx   r8d, byte [rsi]
    shl     r8d, 8
    movzx   r9d, byte [rsi + 1]
    or      r8d, r9d

    ; Check if we support this version (4 or 5)
    cmp     r8w, TOR_LINK_V4
    je      .maybe_found
    cmp     r8w, TOR_LINK_V5
    je      .maybe_found

    add     rsi, 2
    dec     ecx
    jmp     .check_ver

.maybe_found:
    cmp     r8d, eax
    jbe     .next_ver
    mov     eax, r8d
.next_ver:
    add     rsi, 2
    dec     ecx
    jmp     .check_ver

.done_check:
    test    eax, eax
    jnz     .done
    mov     eax, -1
.done:
    pop     rbx
    ret

_tor_build_netinfo_cell:
    push    rbx
    mov     rbx, rdi
    xor     esi, esi
    mov     edx, TOR_CELL_LEN
    call    er_memset

    ; NETINFO is a fixed-length cell after link version negotiation.
    mov     dword [rbx + TOR_CELL_CIRC_ID], 0
    mov     byte [rbx + TOR_CELL_CMD], TOR_CELL_NETINFO

    ; Client timestamp is zero to avoid fingerprinting.
    mov     dword [rbx + TOR_CELL_PAYLOAD], 0

    ; OTHERADDR: IPv4 0.0.0.0 when the observed address is unknown.
    mov     byte [rbx + TOR_CELL_PAYLOAD + 4], 4
    mov     byte [rbx + TOR_CELL_PAYLOAD + 5], 4
    mov     dword [rbx + TOR_CELL_PAYLOAD + 6], 0

    ; Clients send no advertised addresses of their own.
    mov     byte [rbx + TOR_CELL_PAYLOAD + 10], 0

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

    mov     ecx, TOR_TCP_ESTABLISH_POLLS
.wait_tcp_established:
    push    rcx
    call    er_net_poll
    pop     rcx

    push    rcx
    mov     edi, [tor_conn_id]
    call    er_tcp_get_state
    pop     rcx
    test    eax, eax
    js      .connect_fail
    cmp     eax, TCP_ESTABLISHED
    je      .tcp_ready
    dec     ecx
    jnz     .wait_tcp_established
    jmp     .connect_fail

.tcp_ready:
    ; TLS is mandatory for Tor OR links. Start TLS and fail closed
    ; until the TLS module reports an active encrypted record layer.
    mov     ecx, 500
.wait_tls:
    push    rcx
    call    er_net_poll
    pop     rcx

    push    rcx
    mov     edi, [tor_conn_id]
    call    er_tls_connect
    pop     rcx

    test    eax, eax
    jns     .tls_ready
    cmp     edx, ERROR_TLS_UNSUPPORTED
    je      .proto_fail
    dec     ecx
    jnz     .wait_tls
    jmp     .connect_fail

.tls_ready:
    ; Build VERSIONS cell once (before the poll loop)
    mov     rdi, tor_var_cell
    call    _tor_build_versions_cell

    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    mov     edx, TOR_VERSIONS_HEADER + 4
    call    er_tls_send
    test    eax, eax
    js      .send_fail

.versions_sent:

    ; Read VERSIONS cell response
    mov     rdi, tor_var_cell
    call    _tor_recv_versions_cell
    test    eax, eax
    js      .recv_fail

    ; Check command is VERSIONS
    cmp     byte [tor_var_cell + 2], TOR_CELL_VERSIONS
    jne     .proto_fail

    ; Parse versions
    mov     rdi, tor_var_cell
    call    _tor_parse_versions
    test    eax, eax
    js      .proto_fail

    mov     [tor_link_version], eax

    ; Wait for CERTS from relay
    mov     rdi, tor_var_cell
    call    _tor_recv_var_cell
    test    eax, eax
    js      .recv_fail

    ; Should be CERTS cell
    cmp     byte [tor_var_cell + TOR_VAR_CMD], TOR_CELL_CERTS
    jne     .proto_fail

    ; Wait for AUTH_CHALLENGE
    mov     rdi, tor_var_cell
    call    _tor_recv_var_cell
    test    eax, eax
    js      .recv_fail

    ; Should be AUTH_CHALLENGE
    cmp     byte [tor_var_cell + TOR_VAR_CMD], TOR_CELL_AUTH_CHALLENGE
    jne     .proto_fail

    ; Extract challenge from AUTH_CHALLENGE payload
    ; Format: challenge_len(2) + challenge(len) + methods_len(1) + methods
    lea     rsi, [tor_var_cell + TOR_VAR_PAYLOAD]

    ; Wait for responder NETINFO before sending our client NETINFO.
    mov     rsi, tor_rx_cell
    call    _tor_cell_recv
    test    eax, eax
    js      .recv_fail
    cmp     byte [tor_rx_cell + TOR_CELL_CMD], TOR_CELL_NETINFO
    jne     .proto_fail

    ; Send NETINFO
    mov     rdi, tor_var_cell
    call    _tor_build_netinfo_cell

    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    mov     edx, TOR_CELL_LEN
    call    er_tls_send
    test    eax, eax
    js      .send_fail

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
    call    er_tls_send

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
    call    er_tls_recv
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

    ; Relay header inside cell payload.
    mov     byte [r12 + TOR_CELL_PAYLOAD + TOR_RELAY_CMD], TOR_RELAY_EXTEND2
    mov     word [r12 + TOR_CELL_PAYLOAD + TOR_RELAY_RECOGNIZED], 0
    mov     [r12 + TOR_CELL_PAYLOAD + TOR_RELAY_STREAM_ID], r14w
    mov     dword [r12 + TOR_CELL_PAYLOAD + TOR_RELAY_DIGEST], 0
    mov     eax, 119
    xchg    ah, al
    mov     [r12 + TOR_CELL_PAYLOAD + TOR_RELAY_LEN], ax

    ; EXTEND2 body starts at cell offset 16
    ; NSPEC = 2
    mov     byte [r12 + 16], 2

    ; Specifier 1: IPv4 socket (LSTYPE=2, LSLEN=6)
    mov     byte [r12 + 17], 2     ; LSTYPE = IPv4
    mov     byte [r12 + 18], 6     ; LSLEN = 6
    ; IP and port — use zeros (will be filled by caller or default)
    mov     dword [r12 + 19], 0    ; IP (4 bytes, network order)
    mov     word  [r12 + 23], 0    ; PORT (2 bytes, network order)

    ; Specifier 2: Legacy ID (LSTYPE=2, LSLEN=20)
    mov     byte [r12 + 25], 2     ; LSTYPE = legacy ID
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

; er_tor_build_extend2_body(out, node_id20, ipv4, port, handshake84)
; Builds a RELAY_EXTEND2 payload with IPv4 and legacy-id link specifiers.
; Returns eax=119.
global er_tor_build_extend2_body
er_fn er_tor_build_extend2_body
    push    rbx
    push    r12
    push    r13
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, r8
    test    rbx, rbx
    jz      .fail
    test    r12, r12
    jz      .fail
    test    r13, r13
    jz      .fail
    cmp     ecx, 65535
    ja      .fail

    mov     byte [rbx], 2
    mov     byte [rbx + 1], 0
    mov     byte [rbx + 2], 6
    mov     [rbx + 3], edx
    mov     eax, ecx
    mov     [rbx + 7], ah
    mov     [rbx + 8], al

    mov     byte [rbx + 9], 2
    mov     byte [rbx + 10], 20
    lea     rdi, [rbx + 11]
    mov     rsi, r12
    mov     edx, 20
    call    er_memcpy

    mov     byte [rbx + 31], 0
    mov     byte [rbx + 32], 2
    mov     byte [rbx + 33], 0
    mov     byte [rbx + 34], 84
    lea     rdi, [rbx + 35]
    mov     rsi, r13
    mov     edx, 84
    call    er_memcpy

    mov     eax, 119
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; er_tor_circuit_extend(circ_id, node_id20, onion_key32, ipv4, port)
; Extends an open circuit by one ntor hop using RELAY_EXTEND2.
global er_tor_circuit_extend
er_fn er_tor_circuit_extend
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, edi       ; circ_id
    mov     r13, rsi        ; node_id
    mov     r14, rdx        ; onion_key
    mov     r15d, ecx       ; ipv4
    sub     rsp, 256
    mov     [rsp + 236], r8d ; port

    test    r13, r13
    jz      .fail
    test    r14, r14
    jz      .fail
    cmp     dword [rsp + 236], 65535
    ja      .fail

    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .fail
    mov     [rsp + 224], rax
    cmp     dword [rax + TOR_CIRC_STATE], TOR_CIRC_OPEN
    jne     .fail
    mov     eax, [rax + TOR_CIRC_N_HOPS]
    test    eax, eax
    jz      .fail
    cmp     eax, TOR_CIRC_MAX_HOPS
    jae     .fail
    mov     [rsp + 232], eax

    mov     rdi, rsp
    lea     rsi, [rsp + 84]
    mov     rdx, r13
    mov     rcx, r14
    lea     r8,  [rsp + 88]
    lea     r9,  [rsp + 120]
    call    er_tor_ntor_client_handshake
    test    eax, eax
    js      .fail

    lea     rdi, [tor_tmp_buf]
    mov     rsi, r13
    mov     edx, r15d
    mov     ecx, [rsp + 236]
    mov     r8, rsp
    call    er_tor_build_extend2_body
    test    eax, eax
    js      .fail

    mov     edi, r12d
    xor     esi, esi
    mov     edx, TOR_RELAY_EXTEND2
    lea     rcx, [tor_tmp_buf]
    mov     r8d, 119
    call    er_tor_send_relay_early
    test    eax, eax
    js      .fail

    mov     edi, r12d
    lea     rsi, [rsp + 216]
    lea     rdx, [rsp + 218]
    lea     rcx, [tor_tmp_buf]
    lea     r8,  [rsp + 220]
    call    er_tor_recv_relay
    test    eax, eax
    js      .fail
    cmp     byte [rsp + 218], TOR_RELAY_EXTENDED2
    jne     .fail

    lea     rdi, [tor_tmp_buf]
    mov     esi, [rsp + 220]
    lea     rdx, [rsp + 152]
    call    _tor_parse_extended2
    test    eax, eax
    js      .fail

    mov     rdi, [rsp + 224]
    mov     esi, [rsp + 232]
    call    _tor_hop_ptr
    test    rax, rax
    jz      .fail
    mov     rbx, rax

    lea     rax, [rbx + TOR_CIRC_HOP_BWD_IV]
    push    rax
    lea     rax, [rbx + TOR_CIRC_HOP_FWD_IV]
    push    rax
    lea     rax, [rbx + TOR_CIRC_HOP_BWD_KEY]
    push    rax
    lea     rdi, [rsp + 152 + 24]
    mov     rsi, r13
    mov     rdx, r14
    lea     rcx, [rsp + 88 + 24]
    lea     r8,  [rsp + 120 + 24]
    lea     r9,  [rbx + TOR_CIRC_HOP_FWD_KEY]
    call    er_tor_ntor_client_process
    add     rsp, 24
    test    eax, eax
    js      .fail

    lea     rdi, [rbx + TOR_CIRC_HOP_FWD_DIGEST]
    xor     esi, esi
    mov     edx, 64
    call    er_memset
    mov     rax, [rsp + 224]
    inc     dword [rax + TOR_CIRC_N_HOPS]
    xor     eax, eax
    er_ok
    add     rsp, 256
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    add     rsp, 256
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

global er_tor_relay_crypt
er_tor_relay_crypt:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r14, rdi         ; save original cell pointer
    mov     r12d, esi        ; circ_id
    mov     r13d, edx        ; direction

    ; Get circuit pointer
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .bad

    mov     rbx, rax         ; circuit entry
    test    r13d, r13d
    jnz     .backward_loop

    ; Outgoing relay cells are onion-encrypted from endpoint back to guard.
    mov     r15d, [rbx + TOR_CIRC_N_HOPS]
    test    r15d, r15d
    jz      .bad
    dec     r15d
.forward_loop:
    mov     rdi, rbx
    mov     esi, r15d
    call    _tor_hop_ptr
    test    rax, rax
    jz      .bad
    lea     rcx, [rax + TOR_CIRC_HOP_FWD_KEY]
    lea     r8,  [rax + TOR_CIRC_HOP_FWD_IV]
    call    .crypt_payload
    test    r15d, r15d
    jz      .done
    dec     r15d
    jmp     .forward_loop

.backward_loop:
    ; Incoming relay cells are decrypted from guard toward endpoint.
    xor     r15d, r15d
.backward_next:
    cmp     r15d, [rbx + TOR_CIRC_N_HOPS]
    jae     .done
    mov     rdi, rbx
    mov     esi, r15d
    call    _tor_hop_ptr
    test    rax, rax
    jz      .bad
    lea     rcx, [rax + TOR_CIRC_HOP_BWD_KEY]
    lea     r8,  [rax + TOR_CIRC_HOP_BWD_IV]
    call    .crypt_payload
    inc     r15d
    jmp     .backward_next

.crypt_payload:
    ; Encrypt cell payload (bytes 5..514, 509 bytes)
    mov     rdi, r14         ; restore cell pointer
    add     rdi, 5           ; payload starts at offset 5
    mov     rsi, rdi         ; in-place encryption
    mov     edx, 509
    ; rcx = key ptr, r8 = iv ptr
    jmp     er_tor_aes_ctr
.done:
.bad:
    pop     r15
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

    ; Mirror the guard hop into hop slot 0 so relay encryption can layer
    ; correctly once EXTEND2 adds more hops.
    mov     rdi, rbx
    xor     esi, esi
    call    _tor_hop_ptr
    test    rax, rax
    jz      .build_fail
    mov     r15, rax
    lea     rdi, [r15 + TOR_CIRC_HOP_FWD_KEY]
    lea     rsi, [rbx + TOR_CIRC_FORWARD_KEY]
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [r15 + TOR_CIRC_HOP_BWD_KEY]
    lea     rsi, [rbx + TOR_CIRC_BACKWARD_KEY]
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [r15 + TOR_CIRC_HOP_FWD_IV]
    lea     rsi, [rbx + TOR_CIRC_FORWARD_IV]
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [r15 + TOR_CIRC_HOP_BWD_IV]
    lea     rsi, [rbx + TOR_CIRC_BACKWARD_IV]
    mov     edx, 16
    call    er_memcpy
    lea     rdi, [r15 + TOR_CIRC_HOP_FWD_DIGEST]
    xor     esi, esi
    mov     edx, 64
    call    er_memset

    ; Mark circuit open
    mov     dword [rbx + TOR_CIRC_STATE], TOR_CIRC_OPEN
    mov     dword [rbx + TOR_CIRC_N_HOPS], 1

    ; Return circuit ID
    mov     r15d, [rbx + TOR_CIRC_CONN_ID]
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

global er_tor_send_relay_early
er_fn er_tor_send_relay_early
    mov     r9d, TOR_CELL_RELAY_EARLY
    jmp     _tor_send_relay_cmd

er_fn er_tor_send_relay
    mov     r9d, TOR_CELL_RELAY
_tor_send_relay_cmd:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8
    mov     [rsp], r9b

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
    mov     al, [rsp]
    mov     byte [tor_tx_cell + 4], al

    ; Relay header (inside cell payload, offset 5 = TOR_CELL_PAYLOAD)
    mov     [tor_tx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_CMD], r14b
    mov     word [tor_tx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_RECOGNIZED], 0
    mov     [tor_tx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_STREAM_ID], r13w
    mov     dword [tor_tx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DIGEST], 0
    mov     eax, ebx
    xchg    ah, al
    mov     [tor_tx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_LEN], ax

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
    mov     rdi, rax
    call    _tor_endpoint_hop_ptr
    test    rax, rax
    jz      .no_digest

    ; Build input at tor_digest_buf: forward_digest[32] || cell_payload[509]
    ; Cell payload = bytes 5..513 of tor_tx_cell (509 bytes including relay header)
    mov     rdi, tor_digest_buf
    lea     rsi, [rax + TOR_CIRC_HOP_FWD_DIGEST]
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
    mov     [tor_tx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DIGEST], eax

    ; Update circuit's forward_digest with new full digest
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .no_digest
    mov     rdi, rax
    call    _tor_endpoint_hop_ptr
    test    rax, rax
    jz      .no_digest
    lea     rdi, [rax + TOR_CIRC_HOP_FWD_DIGEST]
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
    call    er_tls_send
    test    eax, eax
    js      .send_fail

    xor     eax, eax
    er_ok
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.send_fail:
    mov     eax, -1
    er_err  ERROR_IO
    add     rsp, 8
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
    call    er_tls_recv
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
    mov     eax, [tor_rx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DIGEST]
    push    rax

    ; Zero the digest field for recomputation
    mov     dword [tor_rx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_DIGEST], 0

    ; Get circuit pointer
    mov     edi, r12d
    call    _tor_circ_ptr
    test    rax, rax
    jz      .digest_fail_saved
    mov     rdi, rax
    call    _tor_endpoint_hop_ptr
    test    rax, rax
    jz      .digest_fail_saved

    push    rax                          ; save endpoint hop ptr

    ; Build input at tor_digest_buf: backward_digest[32] || cell_payload[509]
    mov     rdi, tor_digest_buf
    lea     rsi, [rax + TOR_CIRC_HOP_BWD_DIGEST]
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
    jz      .digest_fail_both

    ; Compare first 4 bytes with saved digest.
    mov     eax, [tor_digest_buf + 541]
    pop     rdi                          ; endpoint hop ptr
    pop     rcx                          ; saved digest
    cmp     eax, ecx
    jne     .digest_fail

    ; Update circuit's backward_digest
    add     rdi, TOR_CIRC_HOP_BWD_DIGEST
    lea     rsi, [tor_digest_buf + 541]
    mov     edx, 32
    call    er_memcpy
    jmp     .digest_done

.digest_fail:
    ; Digest mismatch — signal error
    jmp     .fail

.digest_fail_both:
    add     rsp, 16          ; pop circuit ptr + saved digest
    jmp     .fail

.digest_fail_saved:
    add     rsp, 8           ; pop saved digest
    jmp     .fail

.digest_done:

    ; Parse relay header
    movzx   ecx, word [tor_rx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_STREAM_ID]
    mov     [r13], cx

    mov     al, byte [tor_rx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_CMD]
    mov     [r14], al

    movzx   ecx, word [tor_rx_cell + TOR_CELL_PAYLOAD + TOR_RELAY_LEN]
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

    ; Extract bytes from IP (network-order dword bytes in memory)
    mov     eax, r13d      ; first byte
    and     eax, 0xFF
    call    _tor_push_dec
    mov     byte [rdi], '.'
    inc     rdi

    mov     eax, r13d
    shr     eax, 8
    and     eax, 0xFF
    call    _tor_push_dec
    mov     byte [rdi], '.'
    inc     rdi

    mov     eax, r13d
    shr     eax, 16
    and     eax, 0xFF
    call    _tor_push_dec
    mov     byte [rdi], '.'
    inc     rdi

    mov     eax, r13d
    shr     eax, 24
    and     eax, 0xFF
    call    _tor_push_dec

    ; Add port
    mov     byte [rdi], ':'
    inc     rdi
    movzx   eax, r14w
    call    _tor_push_dec

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

; ==================================================================
; er_tor_open_dir_stream — open a directory stream on a circuit
; int er_tor_open_dir_stream(u32 circ_id, u16 *out_stream_id)
; rdi = circ_id, rsi = out_stream_id
; ==================================================================
global er_tor_open_dir_stream
er_fn er_tor_open_dir_stream
    push    rbx
    push    r12

    mov     r12d, edi       ; circ_id
    mov     rbx, rsi        ; out_stream_id ptr

    ; Allocate stream ID from same allocator
    movzx   eax, word [tor_stream_next_id]
    cmp     eax, TOR_MAX_STREAMS
    jae     .full
    mov     [rbx], ax
    inc     word [tor_stream_next_id]

    ; RELAY_BEGIN_DIR has no payload
    mov     edi, r12d
    movzx   esi, word [rbx]
    mov     edx, TOR_RELAY_BEGIN_DIR
    xor     ecx, ecx
    xor     r8d, r8d
    call    er_tor_send_relay

    pop     r12
    pop     rbx
    er_ret

.full:
    mov     eax, -1
    er_err  ERROR_BUSY
    pop     r12
    pop     rbx
    er_ret

; Helper to push a decimal number as string
_tor_push_dec:
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
