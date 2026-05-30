; EdgeRun Tor client — x86_64 assembly
; Main orchestrator: bootstrap, connect, circuit management, streaming.
;
; Entry point: er_tor_init() — called from kernel_main
;              er_tor_poll() — called from main loop

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tor_constants.inc"

%define COM1_PORT 0x3f8

extern er_tor_cell_init
extern er_tor_link_handshake
extern er_tor_circuit_create
extern er_tor_send_relay
extern er_tor_recv_relay
extern er_tor_open_stream
extern er_tor_ntor_keygen
extern er_tor_curve25519_scalar_mult
extern er_tcp_recv

extern er_serial_puts
extern er_serial_putchar
extern er_serial_puthex32
extern er_serial_crlf
extern er_net_get_ip
extern er_memcpy
extern er_memset
; er_sprintf not available

; Externs from tor_cell.asm
extern tor_conn_id
extern tor_rx_cell
extern tor_recv_len
extern er_tor_relay_crypt

SECTION .rodata

; Default Tor guard relay (for testing, use a public relay)
; Replace with actual guard IP at boot time
; 131.188.40.189 = 0xBD28B683 (but in network byte order)
; For testing in QEMU with local Tor: 10.0.2.2 = localhost via host
; We use a compile-time default that can be overridden
tor_default_guard_ip:   db 0x0A, 0x00, 0x02, 0x02  ; 10.0.2.2 (QEMU host)
tor_default_guard_port: dw 9001

; Status strings
str_tor_init:    db "tor: init", 0x0A, 0
str_tor_connect: db "tor: connecting...", 0x0A, 0
str_tor_link_ok: db "tor: link ok", 0x0A, 0
str_tor_link_fail: db "tor: link FAIL", 0x0A, 0
str_tor_circ_ok: db "tor: circuit ok", 0x0A, 0
str_tor_circ_fail: db "tor: circuit FAIL", 0x0A, 0
str_tor_stream:  db "tor: stream ", 0
str_tor_ok:      db "ok", 0x0A, 0
str_tor_fail:    db "FAIL", 0x0A, 0
str_tor_arrow:   db " -> ", 0

SECTION .bss

; Tor client state
tor_state: resb TOR_STATE_SIZE

; Circuit IDs for applications
tor_circ_id_app: resd 1    ; primary circuit for app traffic
tor_stream_id_app: resw 1  ; primary stream for app traffic

; Buffer for building test traffic
tor_test_buf: resb 512

; HTTP GET request buffer
tor_http_get: resb 256

SECTION .text

; ==================================================================
; _tor_print_status — print status message
; void _tor_print_status(const char *msg)
; ==================================================================
_tor_print_status:
    mov     esi, edi        ; string ptr to rsi
    mov     edi, COM1_PORT  ; port
    jmp     er_serial_puts

; ==================================================================
; _tor_print_ip — print IP address as dotted decimal
; void _tor_print_ip(u32 ip)
; ==================================================================
_tor_print_ip:
    push    rbx
    mov     ebx, edi

    movzx   eax, bl
    call    .print_byte
    mov     edi, COM1_PORT
    mov     esi, '.'
    call    er_serial_putchar

    mov     eax, ebx
    shr     eax, 8
    movzx   eax, al
    call    .print_byte
    mov     edi, COM1_PORT
    mov     esi, '.'
    call    er_serial_putchar

    mov     eax, ebx
    shr     eax, 16
    movzx   eax, al
    call    .print_byte
    mov     edi, COM1_PORT
    mov     esi, '.'
    call    er_serial_putchar

    mov     eax, ebx
    shr     eax, 24
    movzx   eax, al
    call    .print_byte

    pop     rbx
    ret

.print_byte:
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
    push    rcx
    mov     edi, COM1_PORT
    mov     esi, eax
    call    er_serial_putchar
    pop     rcx
    dec     ecx
    jnz     .write_loop
    pop     rdx
    pop     rbx
    ret

; ==================================================================
; er_tor_init — initialize and bootstrap Tor client
; int er_tor_init(void)
;
; 1. Initialize cell layer
; 2. Connect to guard relay
; 3. Perform link handshake
; 4. Build circuit
;
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_tor_init
    push    rbx
    push    r12
    push    r13
    push    r14

    lea     rdi, [rel str_tor_init]
    call    _tor_print_status

    ; Initialize Tor cell module
    call    er_tor_cell_init

    ; === Phase 1: Connect to guard relay ===
    lea     rdi, [rel str_tor_connect]
    call    _tor_print_status

    ; Load default guard IP and port
    mov     edi, [rel tor_default_guard_ip]
    bswap   edi             ; convert from stored to network order
    movzx   esi, word [rel tor_default_guard_port]

    ; Store guard IP/port in tor_state
    mov     [tor_state + TOR_STATE_GUARD_IP], edi
    mov     [tor_state + TOR_STATE_GUARD_PORT], si

    ; Print the guard IP we're connecting to
    call    _tor_print_ip
    lea     rdi, [rel str_tor_arrow]
    call    _tor_print_status
    mov     edi, COM1_PORT
    movzx   esi, word [tor_state + TOR_STATE_GUARD_PORT]
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    call    er_serial_crlf

    ; Perform link handshake
    mov     edi, [tor_state + TOR_STATE_GUARD_IP]
    movzx   esi, word [tor_state + TOR_STATE_GUARD_PORT]
    call    er_tor_link_handshake
    test    eax, eax
    js      .link_fail

    lea     rdi, [rel str_tor_link_ok]
    call    _tor_print_status

    ; === Phase 2: Build circuit ===
    ; Use a well-known relay's node ID and onion key
    ; For testing, we use dummy identity (the real handshake will fail)
    ; In production, these come from the Tor directory consensus

    ; For now, we just test the circuit creation machinery
    ; with a simple handshake to the guard itself

    sub     rsp, 128        ; node_id(20) + onion_key(32) + padding

    ; Use dummy node ID (20 bytes of the guard's IP repeated)
    ; In reality this comes from the relay's identity key fingerprint
    mov     rdi, rsp
    mov     eax, [tor_state + TOR_STATE_GUARD_IP]
    mov     ecx, 5
.fill_id:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .fill_id        ; writes 20 bytes

    ; Onion key is the guard's public curve25519 key
    ; For testing, generate a random one
    lea     rdi, [rsp + 20]
    lea     rsi, [rsp + 52]
    call    er_tor_ntor_keygen

    ; Create circuit
    lea     rdi, [tor_circ_id_app]
    mov     rsi, rsp         ; node_id
    lea     rdx, [rsp + 20]  ; onion_key
    call    er_tor_circuit_create
    test    eax, eax
    js      .circ_fail

    lea     rdi, [rel str_tor_circ_ok]
    call    _tor_print_status

    add     rsp, 128

    ; === Phase 3: Done ===
    mov     dword [tor_state + TOR_STATE_LINK_ESTABLISHED], 1

    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.link_fail:
    lea     rdi, [rel str_tor_link_fail]
    call    _tor_print_status
    mov     eax, -1
    er_err  ERROR_TOR_LINK_FAILED
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.circ_fail:
    lea     rdi, [rel str_tor_circ_fail]
    call    _tor_print_status
    add     rsp, 128
    mov     eax, -1
    er_err  ERROR_TOR_CIRC_BUILD_FAIL
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_tor_test_fetch — test HTTP fetch through Tor
; int er_tor_test_fetch(void)
;
; Opens a stream to a test destination and sends HTTP GET.
; ==================================================================
er_fn er_tor_test_fetch
    push    rbx
    push    r12

    ; Check if Tor is initialized
    cmp     dword [tor_state + TOR_STATE_LINK_ESTABLISHED], 1
    jne     .not_ready

    ; Check if we have a circuit
    cmp     dword [tor_circ_id_app], 0
    je      .not_ready

    ; Destination: check.torproject.org (need DNS or IP)
    ; For now: use a known IP
    ; 104.16.124.96 = check.torproject.org
    mov     edi, [tor_circ_id_app]    ; circ_id
    mov     esi, 0x607C10A8           ; 104.16.124.96 in network order
    movzx   edx, byte [tor_80]        ; port 80
    lea     rcx, [tor_stream_id_app]  ; out stream_id
    call    er_tor_open_stream

    ; Send RELAY_DATA with static HTTP request
    ; Use a pre-built GET request in tor_test_buf
    mov     rdi, tor_test_buf
    lea     rsi, [rel str_http_request]
    mov     edx, 64
    call    er_memcpy

    mov     edi, [tor_circ_id_app]
    movzx   esi, word [tor_stream_id_app]
    mov     edx, TOR_RELAY_DATA
    mov     rcx, tor_test_buf
    mov     r8d, 64
    call    er_tor_send_relay

    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret

.not_ready:
    mov     eax, -1
    er_err  ERROR_TOR_LINK_FAILED
    pop     r12
    pop     rbx
    er_ret

SECTION .rodata
tor_80: dw 80
str_http_request: db "GET / HTTP/1.1", 0x0D, 0x0A, "Host: check.torproject.org", 0x0D, 0x0A, "Connection: close", 0x0D, 0x0A, 0x0D, 0x0A, 0

SECTION .text

; ==================================================================
; er_tor_poll — poll Tor for incoming cells
; void er_tor_poll(void)
;
; Should be called periodically from the main loop.
; Checks for incoming relay cells and dispatches to streams.
; ==================================================================
er_fn er_tor_poll
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; Check if link is established
    cmp     dword [tor_state + TOR_STATE_LINK_ESTABLISHED], 1
    jne     .done

    ; Try to receive a cell (non-blocking via TCP recv)
    mov     edi, [tor_conn_id]
    mov     rsi, tor_rx_cell
    lea     rdx, [tor_recv_len]
    mov     dword [rdx], TOR_CELL_LEN
    call    er_tcp_recv
    test    eax, eax
    js      .done

    ; Check if any data was received
    cmp     dword [tor_recv_len], 0
    je      .done

    ; Parse received cell
    mov     r12d, [tor_rx_cell]        ; circ_id (4 bytes, v4+)
    movzx   r13d, byte [tor_rx_cell + 4] ; cmd

    ; Dispatch based on command
    cmp     r13b, TOR_CELL_RELAY
    je      .handle_relay
    cmp     r13b, TOR_CELL_DESTROY
    je      .handle_destroy
    cmp     r13b, TOR_CELL_PADDING
    je      .done
    cmp     r13b, TOR_CELL_VPADDING
    je      .done

    ; Unknown cell, ignore
    jmp     .done

.handle_relay:
    ; Decrypt with circuit's backward key
    mov     edi, tor_rx_cell
    mov     esi, r12d
    mov     edx, 1           ; backward direction
    call    er_tor_relay_crypt

    ; Extract stream ID and relay command
    movzx   r14d, word [tor_rx_cell + 5]   ; stream_id
    movzx   r15d, byte [tor_rx_cell + 13]  ; relay_cmd

    cmp     r15b, TOR_RELAY_CONNECTED
    je      .handle_connected
    cmp     r15b, TOR_RELAY_DATA
    je      .handle_data
    cmp     r15b, TOR_RELAY_END
    je      .handle_end
    cmp     r15b, TOR_RELAY_SENDME
    je      .done

    jmp     .done

.handle_connected:
    ; Stream opened successfully
    lea     rsi, [rel str_tor_stream]
    mov     edi, COM1_PORT
    call    er_serial_puts
    mov     edi, COM1_PORT
    movzx   esi, r14w
    call    er_serial_puthex32
    lea     rsi, [rel str_tor_ok]
    mov     edi, COM1_PORT
    call    er_serial_puts
    jmp     .done

.handle_data:
    ; Copy relay data to stream buffer
    movzx   ecx, word [tor_rx_cell + 11]  ; data_len (big-endian)
    xchg    cl, ch

    ; Print received data length
    push    rcx
    lea     rsi, [rel str_tor_stream]
    mov     edi, COM1_PORT
    call    er_serial_puts
    mov     edi, COM1_PORT
    movzx   esi, r14w
    call    er_serial_puthex32
    lea     rsi, [rel str_tor_arrow]
    mov     edi, COM1_PORT
    call    er_serial_puts
    pop     rcx
    mov     edi, COM1_PORT
    mov     esi, ecx
    call    er_serial_puthex32
    lea     rsi, [rel str_tor_ok_format]
    mov     edi, COM1_PORT
    call    er_serial_puts

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.handle_end:
    ; Stream ended
    jmp     .done

.handle_destroy:
    ; Circuit destroyed
    jmp     .done

SECTION .rodata
str_tor_ok_format: db " bytes", 0x0A, 0

SECTION .text
