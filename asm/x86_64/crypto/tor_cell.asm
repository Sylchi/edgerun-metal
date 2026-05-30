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
extern er_memcpy
extern er_memset
extern er_serial_puts
extern er_serial_puthex64
extern er_serial_crlf
extern er_blake3_hash

extern er_tor_ntor_keygen
extern er_tor_ntor_client_handshake
extern er_tor_ntor_client_process
extern er_tor_curve25519_scalar_mult
extern er_tor_aes_ctr

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

; ==================================================================
; er_tor_cell_init — initialize Tor cell module
; void er_tor_cell_init(void)
; ==================================================================
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

; ==================================================================
; _tor_cell_send — send a fixed-length Tor cell over TCP
; int _tor_cell_send(u32 conn_id, const u8 *cell[514])
; ==================================================================
_tor_cell_send:
    mov     edi, [tor_conn_id]
    mov     rsi, rsi        ; cell
    mov     edx, TOR_CELL_LEN
    call    er_tcp_send
    ret

; ==================================================================
; _tor_cell_recv — receive a fixed-length Tor cell from TCP
; int _tor_cell_recv(u32 conn_id, u8 *cell[514])
; Populates cell buffer. Returns 0 on success.
; ==================================================================
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

; ==================================================================
; _tor_build_versions_cell — build VERSIONS cell
; void _tor_build_versions_cell(u8 *cell, u32 version)
;
; Variable-length cell: circ_id(4)=0 + cmd=7 + len(2) + versions
; For link protocol version requests: [4, 5]
; ==================================================================
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

; ==================================================================
; _tor_parse_versions — parse VERSIONS cell, pick highest common version
; int _tor_parse_versions(const u8 *cell, u32 cell_len)
; Returns chosen version, or -1 if none match.
; ==================================================================
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

; ==================================================================
; _tor_build_netinfo_cell — build NETINFO cell
; void _tor_build_netinfo_cell(u8 *cell)
; ==================================================================
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

; ==================================================================
; _tor_build_certs_cell — build CERTS cell (minimal, anonymous auth)
; void _tor_build_certs_cell(u8 *cell)
; ==================================================================
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

; ==================================================================
; _tor_build_authenticate_cell — build AUTHENTICATE cell (anonymous)
; void _tor_build_authenticate_cell(u8 *cell, const u8 *challenge[32])
; ==================================================================
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

; ==================================================================
; er_tor_link_handshake — perform Tor link handshake
; int er_tor_link_handshake(u32 guard_ip, u16 guard_port)
;
; 1. TCP connect to guard relay
; 2. Exchange VERSIONS cells → negotiate link version
; 3. Exchange CERTS cells
; 4. Process AUTH_CHALLENGE, send AUTHENTICATE
; 5. Exchange NETINFO
; 6. Set tor_link_established = 1
;
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_tor_link_handshake
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; guard_ip (network order)
    mov     r13w, si        ; guard_port (host order)

    ; TCP connect to guard relay
    xor     ecx, ecx        ; src_port = 0 (auto)
    xor     edx, edx        ; src_ip = 0
    mov     edi, r12d
    mov     esi, r13d
    call    er_tcp_connect

    test    eax, eax
    js      .connect_fail
    mov     [tor_conn_id], eax

    ; Small delay for connection to establish
    ; The TCP stack handles SYN/SYN-ACK/ACK in er_net_poll
    ; For now, just proceed (polling in main loop handles it)

    ; Send VERSIONS cell
    mov     rdi, tor_var_cell
    call    _tor_build_versions_cell

    ; Send variable-length cell
    mov     edi, [tor_conn_id]
    mov     rsi, tor_var_cell
    ; Length = header(7) + payload(4)
    mov     edx, TOR_VAR_HEADER + 4
    call    er_tcp_send
    test    eax, eax
    js      .send_fail

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

; ==================================================================
; _tor_send_create2 — send CREATE2 cell to build circuit
; int _tor_send_create2(u32 circ_id, const u8 *handshake_data, u32 handshake_len)
;
; Sends fixed-length cell: circ_id(2)+cmd+payload
; CREATE2 payload: htype(2) + hlen(2) + handshake_data
; ==================================================================
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

; ==================================================================
; _tor_recv_created2 — wait for CREATED2 cell
; int _tor_recv_created2(u32 circ_id, u8 *reply, u32 *reply_len)
;
; Waits for CREATED2 cell for given circ_id.
; reply buffer must be at least 128 bytes.
; ==================================================================
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

; ==================================================================
; _tor_build_extend2 — build RELAY_EARLY cell with EXTEND2 body
; void _tor_build_extend2(u8 *cell, u32 circ_id, u16 stream_id,
;                         const u8 *node_id[20], const u8 *onion_key[32],
;                         const u8 *handshake[84])
;
; Builds a relay cell containing an EXTEND2 body.
; ==================================================================
_tor_build_extend2:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; cell
    mov     r13d, esi       ; circ_id
    mov     r14w, dx        ; stream_id (ax)
    mov     r15, rcx        ; node_id (8th arg from stack)

    ; This is a very complex relay cell builder
    ; For now, just build a minimal EXTEND2
    ; Full implementation would:
    ; 1. Build RELAY header (stream_id, digest, len, cmd=EXTEND2, recognized=0)
    ; 2. Build EXTEND2 body: nspec(1) + spec(n) + handshake_type(2) + hlen(2) + data
    ; 3. Encrypt relay payload with circuit key
    ; 4. Wrap in cell header

    ; Relay cell header inside payload (11 bytes)
    ; Actually cell structure is:
    ; circ_id(2/4) + cmd(1) + relay_header(11) + relay_body(498 max)

    ; Placeholder: for first iteration skip extend, use 1-hop circuits
    ; For now, this is a no-op

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_tor_relay_crypt — encrypt/decrypt a relay cell for a circuit
; Applies AES-CTR encryption using circuit's forward/backward keys
; void er_tor_relay_crypt(u8 *cell, u32 circ_id, int direction)
; direction: 0 = forward (outgoing), 1 = backward (incoming)
; ==================================================================
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

; ==================================================================
; er_tor_circuit_create — build a circuit through the guard relay
; int er_tor_circuit_create(u32 *out_circ_id,
;                           const u8 *node_id[20],
;                           const u8 *onion_key[32])
;
; Creates a 1-hop circuit to the guard relay using CREATE2/CREATED2.
; Returns circuit ID in *out_circ_id.
; ==================================================================
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

    ; Simplified key derivation: use first 32 bytes of reply (Y)
    ; forward_key = Y[0..15], backward_key = Y[16..31]
    lea     rsi, [rsp + 152] ; Y
    lea     rdi, [rbx + TOR_CIRC_FORWARD_KEY]
    mov     edx, 16
    call    er_memcpy

    lea     rsi, [rsp + 168] ; Y + 16
    lea     rdi, [rbx + TOR_CIRC_BACKWARD_KEY]
    mov     edx, 16
    call    er_memcpy

    ; Zero IVs
    lea     rdi, [rbx + TOR_CIRC_FORWARD_IV]
    xor     esi, esi
    mov     edx, 16
    call    er_memset

    lea     rdi, [rbx + TOR_CIRC_BACKWARD_IV]
    xor     esi, esi
    mov     edx, 16
    call    er_memset

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

; ==================================================================
; er_tor_send_relay — send a relay cell through a circuit
; int er_tor_send_relay(u32 circ_id, u16 stream_id,
;                       u8 relay_cmd, const u8 *data, u32 data_len)
;
; Builds, encrypts, and sends a relay cell over the circuit.
; ==================================================================
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

; ==================================================================
; er_tor_recv_relay — receive and decrypt a relay cell
; int er_tor_recv_relay(u32 circ_id, u16 *out_stream_id,
;                       u8 *out_cmd, u8 *out_data, u32 *out_data_len)
;
; Reads a cell from TCP, decrypts with circuit's backward key,
; parses relay header.
; ==================================================================
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

; ==================================================================
; er_tor_open_stream — open a TCP stream through a circuit
; int er_tor_open_stream(u32 circ_id, u32 dst_ip, u16 dst_port,
;                        u16 *out_stream_id)
;
; Sends RELAY_BEGIN cell through the circuit.
; ==================================================================
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
