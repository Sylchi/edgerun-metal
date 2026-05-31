; EdgeRun Tor client — x86_64 assembly
; Main orchestrator: bootstrap, connect, circuit management, streaming.
;
; Entry point: er_tor_init() — called explicitly by a Tor role owner
;              er_tor_poll() — called explicitly by a Tor role owner

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/tor_constants.inc"
%include "x86_64/crypto/local_constants.inc"

%define COM1_PORT 0x3f8

extern er_tor_cell_init
extern er_tor_link_handshake
extern er_tor_circuit_create
extern er_tor_send_relay
extern er_tor_recv_relay
extern er_tor_open_stream
extern er_tor_open_dir_stream
extern er_tor_ntor_keygen
extern er_tcp_recv

extern er_serial_puts
extern er_serial_putchar
extern er_serial_puthex32
extern er_serial_crlf
extern er_memcpy
extern er_memset
extern er_memcmp
extern er_http_parse_status
extern er_http_find_body
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
tor_default_guard_ip:       db 0x0A, 0x00, 0x02, 0x64  ; 10.0.2.100 (QEMU host)
tor_default_guard_port: dw 19001

; Status strings
str_tor_init:    db "tor: init", 0x0A, 0
str_tor_connect: db "tor: connecting...", 0x0A, 0
str_tor_link_ok: db "tor: link ok", 0x0A, 0
str_tor_link_fail: db "tor: link FAIL", 0x0A, 0
str_tor_circ_ok: db "tor: circuit ok", 0x0A, 0
str_tor_circ_fail: db "tor: circuit FAIL", 0x0A, 0
str_tor_dir_fail: db "tor: directory FAIL", 0x0A, 0
str_tor_stream:  db "tor: stream ", 0
str_tor_ok:      db "ok", 0x0A, 0
str_tor_arrow:   db " -> ", 0

SECTION .bss

; Tor client state
tor_state: resb TOR_STATE_SIZE

; Circuit IDs for applications
tor_circ_id_app: resd 1    ; primary circuit for app traffic
tor_stream_id_app: resw 1  ; primary stream for app traffic

; Buffer for building test traffic
tor_test_buf: resb 512

; Tor cell-tunnel state (local cell format over RELAY_DATA)
tor_tunnel_dst_ip: resd 1
tor_tunnel_dst_port: resw 1
tor_tunnel_stream_id: resw 1
tor_tunnel_stream_open: resd 1
tor_dir_stream_id: resw 1
tor_dir_stream_open: resd 1
tor_tunnel_rx_head: resd 1
tor_tunnel_rx_tail: resd 1
tor_tunnel_rx_ring: resb LOCAL_CELL_SIZE * 4

; Directory fetch buffers/state
tor_dir_resp_len: resd 1
tor_dir_resp_buf: resb TOR_RECV_BUF_SIZE
tor_dir_body_len: resd 1
tor_dir_body_buf: resb TOR_RECV_BUF_SIZE
tor_dir_tmp_stream: resw 1
tor_dir_tmp_cmd: resb 1
tor_dir_tmp_len: resd 1
tor_dir_tmp_data: resb 512
tor_dir_guard_id: resb 20
tor_guard_onion_key: resb 32

SECTION .text

; ==================================================================
; _tor_caps_from_role — map role enum to capability mask
; edi = role
; returns eax = caps, or -1 on invalid role
; ==================================================================
_tor_caps_from_role:
    cmp     edi, TOR_ROLE_CLIENT
    je      .client
    cmp     edi, TOR_ROLE_GUARD
    je      .guard
    cmp     edi, TOR_ROLE_MIDDLE
    je      .middle
    cmp     edi, TOR_ROLE_EXIT
    je      .exit
    cmp     edi, TOR_ROLE_DIRECTORY
    je      .directory
    cmp     edi, TOR_ROLE_BRIDGE
    je      .bridge
    cmp     edi, TOR_ROLE_HS_SERVICE
    je      .hs_service
    cmp     edi, TOR_ROLE_HS_INTRO
    je      .hs_intro
    cmp     edi, TOR_ROLE_HS_RENDEZVOUS
    je      .hs_rendezvous
    mov     eax, -1
    ret
.client:
    mov     eax, TOR_CAP_CLIENT
    ret
.guard:
    mov     eax, TOR_CAP_OR_RELAY
    ret
.middle:
    mov     eax, TOR_CAP_OR_RELAY
    ret
.exit:
    mov     eax, TOR_CAP_OR_RELAY | TOR_CAP_EXIT
    ret
.directory:
    mov     eax, TOR_CAP_DIRECTORY
    ret
.bridge:
    mov     eax, TOR_CAP_OR_RELAY | TOR_CAP_BRIDGE
    ret
.hs_service:
    mov     eax, TOR_CAP_HS_SERVICE
    ret
.hs_intro:
    mov     eax, TOR_CAP_HS_INTRO
    ret
.hs_rendezvous:
    mov     eax, TOR_CAP_HS_RENDEZVOUS
    ret

; ==================================================================
; er_tor_set_role — configure Tor operating role
; edi = role (TOR_ROLE_*)
; returns eax=0 on success, -1 on invalid role
; ==================================================================
global er_tor_set_role
er_fn er_tor_set_role
    call    _tor_caps_from_role
    cmp     eax, -1
    je      .bad_role
    mov     [tor_state + TOR_STATE_ROLE], edi
    mov     [tor_state + TOR_STATE_ROLE_CAPS], eax
    xor     eax, eax
    er_ok
    er_ret
.bad_role:
    mov     eax, -1
    er_err  ERROR_TOR_ROLE_INVALID
    er_ret

; ==================================================================
; er_tor_get_role — read current role
; returns eax = TOR_ROLE_*
; ==================================================================
global er_tor_get_role
er_fn er_tor_get_role
    mov     eax, [tor_state + TOR_STATE_ROLE]
    er_ok
    er_ret

; ==================================================================
; er_tor_get_role_caps — read current role capability mask
; returns eax = TOR_CAP_* bitmask
; ==================================================================
global er_tor_get_role_caps
er_fn er_tor_get_role_caps
    mov     eax, [tor_state + TOR_STATE_ROLE_CAPS]
    er_ok
    er_ret

; ==================================================================
; er_tor_tunnel_set_exit — set destination endpoint for tunnel stream
; edi = dst IPv4 (network byte order), esi = dst port (host order)
; ==================================================================
global er_tor_tunnel_set_exit
er_fn er_tor_tunnel_set_exit
    mov     [tor_tunnel_dst_ip], edi
    mov     [tor_tunnel_dst_port], si
    mov     dword [tor_tunnel_stream_open], 0
    mov     word [tor_tunnel_stream_id], 0
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_tor_open_directory_channel — open BEGIN_DIR stream on app circuit
; returns eax=0 on success, -1 on failure
; ==================================================================
global er_tor_open_directory_channel
er_fn er_tor_open_directory_channel
    cmp     dword [tor_state + TOR_STATE_LINK_ESTABLISHED], 1
    jne     .fail
    cmp     dword [tor_circ_id_app], 0
    je      .fail
    cmp     dword [tor_dir_stream_open], 1
    je      .ok

    mov     edi, [tor_circ_id_app]
    lea     rsi, [tor_dir_stream_id]
    call    er_tor_open_dir_stream
    test    eax, eax
    js      .fail
    mov     dword [tor_dir_stream_open], 1

.ok:
    xor     eax, eax
    er_ok
    er_ret
.fail:
    mov     eax, -1
    er_err  ERROR_TOR_STREAM_FAIL
    er_ret

; ==================================================================
; er_tor_directory_fetch_consensus — fetch current consensus over BEGIN_DIR
; returns eax=0 on success, -1 on failure
; ==================================================================
global er_tor_directory_fetch_consensus
er_fn er_tor_directory_fetch_consensus
    push    rbx
    push    r12
    push    r13
    push    r14

    call    er_tor_open_directory_channel
    test    eax, eax
    js      .fail

    ; Send HTTP GET over directory stream
    mov     edi, [tor_circ_id_app]
    movzx   esi, word [tor_dir_stream_id]
    mov     edx, TOR_RELAY_DATA
    lea     rcx, [rel str_tor_dir_consensus_get]
    mov     r8d, str_tor_dir_consensus_get_len
    call    er_tor_send_relay
    test    eax, eax
    js      .fail

    xor     r12d, r12d                  ; bytes collected
    mov     r13d, 2048                  ; bounded receive loop

.recv_loop:
    mov     edi, [tor_circ_id_app]
    lea     rsi, [tor_dir_tmp_stream]
    lea     rdx, [tor_dir_tmp_cmd]
    lea     rcx, [tor_dir_tmp_data]
    lea     r8, [tor_dir_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .next

    movzx   eax, word [tor_dir_tmp_stream]
    cmp     ax, [tor_dir_stream_id]
    jne     .next

    movzx   eax, byte [tor_dir_tmp_cmd]
    cmp     al, TOR_RELAY_CONNECTED
    je      .next
    cmp     al, TOR_RELAY_END
    je      .parse_http
    cmp     al, TOR_RELAY_DATA
    jne     .next

    mov     ebx, [tor_dir_tmp_len]
    cmp     ebx, 0
    je      .next

    mov     eax, TOR_RECV_BUF_SIZE
    sub     eax, r12d
    jbe     .fail
    cmp     ebx, eax
    jbe     .copy_chunk
    mov     ebx, eax

.copy_chunk:
    lea     rdi, [tor_dir_resp_buf + r12]
    lea     rsi, [tor_dir_tmp_data]
    mov     edx, ebx
    call    er_memcpy
    add     r12d, ebx

.next:
    dec     r13d
    jnz     .recv_loop
    jmp     .fail

.parse_http:
    cmp     r12d, 0
    je      .fail
    mov     [tor_dir_resp_len], r12d

    lea     rdi, [tor_dir_resp_buf]
    mov     esi, r12d
    call    er_http_parse_status
    cmp     eax, 200
    jne     .fail

    lea     rdi, [tor_dir_resp_buf]
    mov     esi, r12d
    call    er_http_find_body
    test    rax, rax
    jz      .fail
    mov     r14, rax

    lea     rax, [tor_dir_resp_buf + r12]
    sub     rax, r14
    test    eax, eax
    jle     .fail
    mov     [tor_dir_body_len], eax
    mov     edx, eax
    lea     rdi, [tor_dir_body_buf]
    mov     rsi, r14
    call    er_memcpy

    ; Parse first relay entry from consensus and persist guard material
    call    _tor_parse_consensus_first_relay
    test    eax, eax
    js      .fail
    call    er_tor_directory_fetch_guard_descriptor
    test    eax, eax
    js      .fail

    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.fail:
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; _tor_b64_val — map base64 char to value
; dil = char, returns eax=value or -1
; ==================================================================
_tor_b64_val:
    movzx   eax, dil
    cmp     al, 'A'
    jb      .chk_l
    cmp     al, 'Z'
    ja      .chk_l
    sub     eax, 'A'
    ret
.chk_l:
    cmp     al, 'a'
    jb      .chk_d
    cmp     al, 'z'
    ja      .chk_d
    sub     eax, 'a'
    add     eax, 26
    ret
.chk_d:
    cmp     al, '0'
    jb      .chk_plus
    cmp     al, '9'
    ja      .chk_plus
    sub     eax, '0'
    add     eax, 52
    ret
.chk_plus:
    cmp     al, '+'
    jne     .chk_slash
    mov     eax, 62
    ret
.chk_slash:
    cmp     al, '/'
    jne     .bad
    mov     eax, 63
    ret
.bad:
    mov     eax, -1
    ret

; ==================================================================
; _tor_decode_b64_20 — decode relay ID token into 20 bytes
; rdi=token ptr, esi=token len, rdx=out[20]
; returns eax=0 success, -1 failure
; ==================================================================
_tor_decode_b64_20:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    xor     r15d, r15d      ; in idx
    xor     ebx, ebx        ; out idx

.loop:
    cmp     ebx, 20
    jae     .ok
    cmp     r15d, r13d
    jae     .fail

    movzx   edi, byte [r12 + r15]
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail
    mov     ecx, eax

    cmp     r15d, r13d
    jae     .fail
    movzx   edi, byte [r12 + r15]
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail
    mov     edx, eax

    mov     eax, ecx
    shl     eax, 2
    mov     esi, edx
    shr     esi, 4
    or      eax, esi
    mov     [r14 + rbx], al
    inc     ebx
    cmp     ebx, 20
    jae     .ok

    cmp     r15d, r13d
    jae     .ok
    movzx   edi, byte [r12 + r15]
    cmp     dil, '='
    je      .ok
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail
    mov     esi, eax

    mov     eax, edx
    and     eax, 0x0F
    shl     eax, 4
    mov     ecx, esi
    shr     ecx, 2
    or      eax, ecx
    mov     [r14 + rbx], al
    inc     ebx
    cmp     ebx, 20
    jae     .ok

    cmp     r15d, r13d
    jae     .ok
    movzx   edi, byte [r12 + r15]
    cmp     dil, '='
    je      .ok
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail

    mov     ecx, esi
    and     ecx, 0x03
    shl     ecx, 6
    or      ecx, eax
    mov     [r14 + rbx], cl
    inc     ebx
    jmp     .loop

.ok:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tor_decode_b64_32 — decode base64 token to 32 bytes
; rdi=token ptr, esi=token len, rdx=out[32]
; returns eax=0 success, -1 failure
; ==================================================================
_tor_decode_b64_32:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    xor     r15d, r15d
    xor     ebx, ebx

.loop:
    cmp     ebx, 32
    jae     .ok
    cmp     r15d, r13d
    jae     .fail
    movzx   edi, byte [r12 + r15]
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail
    mov     ecx, eax

    cmp     r15d, r13d
    jae     .fail
    movzx   edi, byte [r12 + r15]
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail
    mov     edx, eax

    mov     eax, ecx
    shl     eax, 2
    mov     esi, edx
    shr     esi, 4
    or      eax, esi
    mov     [r14 + rbx], al
    inc     ebx
    cmp     ebx, 32
    jae     .ok

    cmp     r15d, r13d
    jae     .ok
    movzx   edi, byte [r12 + r15]
    cmp     dil, '='
    je      .ok
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail
    mov     esi, eax

    mov     eax, edx
    and     eax, 0x0F
    shl     eax, 4
    mov     ecx, esi
    shr     ecx, 2
    or      eax, ecx
    mov     [r14 + rbx], al
    inc     ebx
    cmp     ebx, 32
    jae     .ok

    cmp     r15d, r13d
    jae     .ok
    movzx   edi, byte [r12 + r15]
    cmp     dil, '='
    je      .ok
    inc     r15d
    call    _tor_b64_val
    cmp     eax, -1
    je      .fail

    mov     ecx, esi
    and     ecx, 0x03
    shl     ecx, 6
    or      ecx, eax
    mov     [r14 + rbx], cl
    inc     ebx
    jmp     .loop

.ok:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tor_hex_encode_20_upper — encode 20 bytes as 40 hex uppercase
; rdi=in[20], rsi=out[40]
; ==================================================================
_tor_hex_encode_20_upper:
    push    rbx
    xor     ecx, ecx
.hex_loop:
    cmp     ecx, 20
    jae     .hex_done
    movzx   eax, byte [rdi + rcx]
    mov     ebx, eax
    shr     ebx, 4
    and     eax, 0x0F
    cmp     bl, 9
    jbe     .hi_num
    add     bl, 'A' - 10
    jmp     .hi_store
.hi_num:
    add     bl, '0'
.hi_store:
    mov     [rsi + rcx*2], bl
    cmp     al, 9
    jbe     .lo_num
    add     al, 'A' - 10
    jmp     .lo_store
.lo_num:
    add     al, '0'
.lo_store:
    mov     [rsi + rcx*2 + 1], al
    inc     ecx
    jmp     .hex_loop
.hex_done:
    pop     rbx
    ret

; ==================================================================
; _tor_parse_descriptor_ntor_key — parse ntor-onion-key from descriptor
; returns eax=0 success, -1 failure
; ==================================================================
_tor_parse_descriptor_ntor_key:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    lea     r12, [tor_dir_body_buf]
    mov     r13d, [tor_dir_body_len]
    xor     r14d, r14d

.scan:
    cmp     r14d, r13d
    jae     .fail
    mov     eax, r13d
    sub     eax, r14d
    cmp     eax, str_tor_ntor_key_prefix_len
    jb      .next_line
    lea     rdi, [r12 + r14]
    lea     rsi, [rel str_tor_ntor_key_prefix]
    mov     edx, str_tor_ntor_key_prefix_len
    call    er_memcmp
    test    eax, eax
    jz      .found
.next_line:
    cmp     r14d, r13d
    jae     .fail
    cmp     byte [r12 + r14], 0x0A
    je      .adv
    inc     r14d
    jmp     .next_line
.adv:
    inc     r14d
    jmp     .scan

.found:
    add     r14d, str_tor_ntor_key_prefix_len
    mov     r15d, r14d
.tok_end:
    cmp     r15d, r13d
    jae     .decode
    movzx   ebx, byte [r12 + r15]
    cmp     bl, 0x0D
    je      .decode
    cmp     bl, 0x0A
    je      .decode
    inc     r15d
    jmp     .tok_end
.decode:
    lea     rdi, [r12 + r14]
    mov     esi, r15d
    sub     esi, r14d
    lea     rdx, [tor_guard_onion_key]
    call    _tor_decode_b64_32
    test    eax, eax
    js      .fail
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_tor_directory_fetch_guard_descriptor — fetch selected relay descriptor
; returns eax=0 success, -1 failure
; ==================================================================
global er_tor_directory_fetch_guard_descriptor
er_fn er_tor_directory_fetch_guard_descriptor
    push    rbx
    push    r12

    ; Force fresh BEGIN_DIR stream for this fetch
    mov     dword [tor_dir_stream_open], 0

    ; Build GET /tor/server/fp/<HEX40> request in tor_test_buf
    lea     rdi, [tor_test_buf]
    lea     rsi, [rel str_tor_dir_desc_get_prefix]
    mov     edx, str_tor_dir_desc_get_prefix_len
    call    er_memcpy
    mov     ebx, str_tor_dir_desc_get_prefix_len

    lea     rdi, [tor_state + TOR_STATE_GUARD_FINGERPRINT]
    lea     rsi, [tor_test_buf + rbx]
    call    _tor_hex_encode_20_upper
    add     ebx, 40

    lea     rdi, [tor_test_buf + rbx]
    lea     rsi, [rel str_tor_dir_desc_get_suffix]
    mov     edx, str_tor_dir_desc_get_suffix_len
    call    er_memcpy
    add     ebx, str_tor_dir_desc_get_suffix_len

    call    er_tor_open_directory_channel
    test    eax, eax
    js      .fail

    mov     edi, [tor_circ_id_app]
    movzx   esi, word [tor_dir_stream_id]
    mov     edx, TOR_RELAY_DATA
    lea     rcx, [tor_test_buf]
    mov     r8d, ebx
    call    er_tor_send_relay
    test    eax, eax
    js      .fail

    xor     r12d, r12d
    mov     dword [tor_dir_resp_len], 0
    mov     ebx, 2048
.recv_loop:
    mov     edi, [tor_circ_id_app]
    lea     rsi, [tor_dir_tmp_stream]
    lea     rdx, [tor_dir_tmp_cmd]
    lea     rcx, [tor_dir_tmp_data]
    lea     r8, [tor_dir_tmp_len]
    call    er_tor_recv_relay
    test    eax, eax
    js      .next
    movzx   eax, word [tor_dir_tmp_stream]
    cmp     ax, [tor_dir_stream_id]
    jne     .next
    movzx   eax, byte [tor_dir_tmp_cmd]
    cmp     al, TOR_RELAY_CONNECTED
    je      .next
    cmp     al, TOR_RELAY_END
    je      .parse
    cmp     al, TOR_RELAY_DATA
    jne     .next
    mov     eax, [tor_dir_tmp_len]
    test    eax, eax
    jle     .next
    mov     edx, TOR_RECV_BUF_SIZE
    sub     edx, r12d
    jbe     .fail
    cmp     eax, edx
    jbe     .cpsz
    mov     eax, edx
.cpsz:
    lea     rdi, [tor_dir_resp_buf + r12]
    lea     rsi, [tor_dir_tmp_data]
    mov     edx, eax
    call    er_memcpy
    add     r12d, eax
.next:
    dec     ebx
    jnz     .recv_loop
    jmp     .fail
.parse:
    cmp     r12d, 0
    je      .fail
    mov     [tor_dir_resp_len], r12d
    lea     rdi, [tor_dir_resp_buf]
    mov     esi, r12d
    call    er_http_parse_status
    cmp     eax, 200
    jne     .fail
    lea     rdi, [tor_dir_resp_buf]
    mov     esi, r12d
    call    er_http_find_body
    test    rax, rax
    jz      .fail
    lea     rdx, [tor_dir_resp_buf + r12]
    sub     rdx, rax
    test    edx, edx
    jle     .fail
    mov     [tor_dir_body_len], edx
    lea     rdi, [tor_dir_body_buf]
    mov     rsi, rax
    call    er_memcpy
    call    _tor_parse_descriptor_ntor_key
    test    eax, eax
    js      .fail
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; _tor_parse_u16_dec — parse unsigned decimal port
; rdi=ptr, esi=len, returns eax=value or -1
; ==================================================================
_tor_parse_u16_dec:
    xor     eax, eax
    xor     ecx, ecx
.lp:
    cmp     ecx, esi
    jae     .done
    movzx   edx, byte [rdi + rcx]
    cmp     dl, '0'
    jb      .bad
    cmp     dl, '9'
    ja      .bad
    imul    eax, eax, 10
    sub     edx, '0'
    add     eax, edx
    cmp     eax, 65535
    ja      .bad
    inc     ecx
    jmp     .lp
.done:
    ret
.bad:
    mov     eax, -1
    ret

; ==================================================================
; _tor_parse_ipv4_token — parse dotted ipv4 to little-endian dword
; rdi=ptr, esi=len
; returns eax=ip dword (bytes in memory are wire order), or -1
; ==================================================================
_tor_parse_ipv4_token:
    push    rbx
    push    r12
    push    r13
    xor     eax, eax
    xor     ebx, ebx          ; octet idx
    xor     r12d, r12d        ; cursor
    xor     r13d, r13d        ; current octet value

.next_char:
    cmp     r12d, esi
    jae     .flush_last
    movzx   ecx, byte [rdi + r12]
    inc     r12d
    cmp     cl, '.'
    je      .flush_octet
    cmp     cl, '0'
    jb      .bad
    cmp     cl, '9'
    ja      .bad
    imul    r13d, r13d, 10
    sub     ecx, '0'
    add     r13d, ecx
    cmp     r13d, 255
    ja      .bad
    jmp     .next_char

.flush_octet:
    cmp     ebx, 3
    jae     .bad
    mov     ecx, ebx
    shl     ecx, 3
    mov     edx, r13d
    shl     edx, cl
    or      eax, edx
    inc     ebx
    xor     r13d, r13d
    jmp     .next_char

.flush_last:
    cmp     ebx, 3
    jne     .bad
    mov     edx, r13d
    shl     edx, 24
    or      eax, edx
    pop     r13
    pop     r12
    pop     rbx
    ret

.bad:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tor_parse_consensus_first_relay — parse first "r " line relay info
; writes TOR_STATE_GUARD_IP/PORT/FINGERPRINT and tor_dir_guard_id
; returns eax=0 success, -1 failure
; ==================================================================
_tor_parse_consensus_first_relay:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    lea     r12, [tor_dir_body_buf]
    mov     r13d, [tor_dir_body_len]
    xor     r14d, r14d          ; cursor

.scan_lines:
    cmp     r14d, r13d
    jae     .fail
    cmp     byte [r12 + r14], 'r'
    jne     .next_line
    cmp     r14d, r13d
    jae     .fail
    cmp     byte [r12 + r14 + 1], ' '
    jne     .next_line
    lea     r15, [r12 + r14 + 2] ; token scan start
    jmp     .parse_r_line

.next_line:
    cmp     r14d, r13d
    jae     .fail
    cmp     byte [r12 + r14], 0x0A
    je      .line_advance
    inc     r14d
    jmp     .next_line
.line_advance:
    inc     r14d
    jmp     .scan_lines

.parse_r_line:
    ; token indices on r-line after "r ":
    ; 0=nickname 1=identity(b64) 2=desc 3=date 4=time 5=ip 6=orport 7=dirport
    xor     ebx, ebx
    xor     ecx, ecx             ; in_token flag
    xor     edx, edx             ; token start offset from r15
    xor     r8d, r8d             ; token len
    xor     r9d, r9d             ; local cursor
    mov     dword [tor_state + TOR_STATE_GUARD_IP], 0
    mov     word [tor_state + TOR_STATE_GUARD_PORT], 0
    lea     rdi, [tor_state + TOR_STATE_GUARD_FINGERPRINT]
    xor     esi, esi
    mov     edx, 20
    call    er_memset

.tok_loop:
    movzx   eax, byte [r15 + r9]
    cmp     al, 0x0A
    je      .tok_line_end
    cmp     al, 0
    je      .tok_line_end
    cmp     al, ' '
    je      .tok_sep
    test    ecx, ecx
    jnz     .tok_cont
    mov     edx, r9d
    xor     r8d, r8d
    mov     ecx, 1
.tok_cont:
    inc     r8d
    inc     r9d
    jmp     .tok_loop

.tok_sep:
    test    ecx, ecx
    jz      .tok_skip_space
    ; finalize token at [r15+rdx], len r8d
    cmp     ebx, 1
    je      .tok_identity
    cmp     ebx, 5
    je      .tok_ip
    cmp     ebx, 6
    je      .tok_orport
    jmp     .tok_done

.tok_identity:
    lea     rdi, [r15 + rdx]
    mov     esi, r8d
    lea     rdx, [tor_dir_guard_id]
    call    _tor_decode_b64_20
    test    eax, eax
    js      .fail
    lea     rdi, [tor_state + TOR_STATE_GUARD_FINGERPRINT]
    lea     rsi, [tor_dir_guard_id]
    mov     edx, 20
    call    er_memcpy
    jmp     .tok_done

.tok_ip:
    lea     rdi, [r15 + rdx]
    mov     esi, r8d
    call    _tor_parse_ipv4_token
    test    eax, eax
    js      .fail
    mov     [tor_state + TOR_STATE_GUARD_IP], eax
    jmp     .tok_done

.tok_orport:
    lea     rdi, [r15 + rdx]
    mov     esi, r8d
    call    _tor_parse_u16_dec
    test    eax, eax
    js      .fail
    mov     [tor_state + TOR_STATE_GUARD_PORT], ax
    jmp     .tok_done

.tok_done:
    inc     ebx
    xor     ecx, ecx
    xor     r8d, r8d
.tok_skip_space:
    inc     r9d
    jmp     .tok_loop

.tok_line_end:
    cmp     dword [tor_state + TOR_STATE_GUARD_IP], 0
    je      .next_line
    cmp     word [tor_state + TOR_STATE_GUARD_PORT], 0
    je      .next_line
    ; Enforce guard policy from following "s " flags line:
    ; require Running + Valid + Guard for selected relay.
    mov     r10d, r14d
    add     r10d, 2
    add     r10d, r9d
    xor     r11d, r11d

.flags_seek:
    cmp     r10d, r13d
    jae     .fail
    cmp     byte [r12 + r10], 0x0A
    jne     .flags_line_check
    inc     r10d
    jmp     .flags_seek
.flags_line_check:
    cmp     byte [r12 + r10], 'r'
    jne     .check_s
    cmp     r10d, r13d
    jae     .fail
    cmp     byte [r12 + r10 + 1], ' '
    je      .line_advance
.check_s:
    cmp     byte [r12 + r10], 's'
    jne     .flags_skip_line
    cmp     r10d, r13d
    jae     .fail
    cmp     byte [r12 + r10 + 1], ' '
    jne     .flags_skip_line
    add     r10d, 2
    xor     r11d, r11d           ; bit0=Guard bit1=Running bit2=Valid
.flags_tok_seek:
    cmp     r10d, r13d
    jae     .flags_done
    movzx   eax, byte [r12 + r10]
    cmp     al, 0x0A
    je      .flags_done
    cmp     al, ' '
    jne     .flags_tok_start
    inc     r10d
    jmp     .flags_tok_seek
.flags_tok_start:
    mov     r8d, r10d
    xor     r9d, r9d
.flags_tok_len:
    cmp     r10d, r13d
    jae     .flags_tok_eval
    movzx   eax, byte [r12 + r10]
    cmp     al, 0x0A
    je      .flags_tok_eval
    cmp     al, ' '
    je      .flags_tok_eval
    inc     r10d
    inc     r9d
    jmp     .flags_tok_len
.flags_tok_eval:
    cmp     r9d, 5
    jne     .flags_chk_run
    lea     rdi, [r12 + r8]
    lea     rsi, [rel str_flag_guard]
    mov     edx, 5
    call    er_memcmp
    test    eax, eax
    jnz     .flags_chk_run
    or      r11d, 1
.flags_chk_run:
    cmp     r9d, 7
    jne     .flags_chk_valid
    lea     rdi, [r12 + r8]
    lea     rsi, [rel str_flag_running]
    mov     edx, 7
    call    er_memcmp
    test    eax, eax
    jnz     .flags_chk_valid
    or      r11d, 2
.flags_chk_valid:
    cmp     r9d, 5
    jne     .flags_tok_seek
    lea     rdi, [r12 + r8]
    lea     rsi, [rel str_flag_valid]
    mov     edx, 5
    call    er_memcmp
    test    eax, eax
    jnz     .flags_tok_seek
    or      r11d, 4
    jmp     .flags_tok_seek
.flags_done:
    cmp     r11d, 7
    jne     .flags_skip_line
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.flags_skip_line:
    ; Continue searching from current probe position
    mov     r14d, r10d
    jmp     .scan_lines

.fail:
    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _tor_tunnel_open_if_needed — open stream if not already open
; returns eax=0 success, -1 on failure
; ==================================================================
_tor_tunnel_open_if_needed:
    cmp     dword [tor_tunnel_stream_open], 1
    je      .ok
    cmp     dword [tor_state + TOR_STATE_LINK_ESTABLISHED], 1
    jne     .fail
    cmp     dword [tor_circ_id_app], 0
    je      .fail

    mov     edi, [tor_circ_id_app]
    mov     esi, [tor_tunnel_dst_ip]
    movzx   edx, word [tor_tunnel_dst_port]
    lea     rcx, [tor_tunnel_stream_id]
    call    er_tor_open_stream
    test    eax, eax
    js      .fail

    mov     dword [tor_tunnel_stream_open], 1
.ok:
    xor     eax, eax
    ret
.fail:
    mov     eax, -1
    ret

; ==================================================================
; er_tor_tunnel_send_cell — send one 256-byte local cell over Tor
; rdi = cell_ptr (LOCAL_CELL_SIZE)
; ==================================================================
global er_tor_tunnel_send_cell
er_fn er_tor_tunnel_send_cell
    push    rbx
    mov     rbx, rdi
    call    _tor_tunnel_open_if_needed
    test    eax, eax
    js      .fail

    mov     edi, [tor_circ_id_app]
    movzx   esi, word [tor_tunnel_stream_id]
    mov     edx, TOR_RELAY_DATA
    mov     rcx, rbx
    mov     r8d, LOCAL_CELL_SIZE
    call    er_tor_send_relay
    test    eax, eax
    js      .fail

    xor     eax, eax
    er_ok
    pop     rbx
    er_ret
.fail:
    mov     eax, -1
    er_err  ERROR_TOR_STREAM_FAIL
    pop     rbx
    er_ret

; ==================================================================
; er_tor_tunnel_recv_cell — recv one tunneled local cell (non-blocking)
; rdi = out_cell_ptr (LOCAL_CELL_SIZE)
; ==================================================================
global er_tor_tunnel_recv_cell
er_fn er_tor_tunnel_recv_cell
    push    rbx
    push    r12
    mov     r12, rdi
    mov     eax, [tor_tunnel_rx_head]
    mov     ebx, [tor_tunnel_rx_tail]
    cmp     eax, ebx
    je      .empty

    and     ebx, 3
    imul    ebx, LOCAL_CELL_SIZE
    lea     rsi, [tor_tunnel_rx_ring + rbx]
    mov     rdi, r12
    mov     edx, LOCAL_CELL_SIZE
    call    er_memcpy

    inc     dword [tor_tunnel_rx_tail]
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret
.empty:
    mov     eax, -1
    er_err  ERROR_LOCAL_EMPTY
    pop     r12
    pop     rbx
    er_ret

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
    mov     edi, TOR_ROLE_CLIENT
    call    er_tor_set_role
    test    eax, eax
    js      .link_fail
    mov     dword [tor_tunnel_dst_ip], 0x607C10A8   ; 104.16.124.96
    mov     word [tor_tunnel_dst_port], 80
    mov     dword [tor_tunnel_stream_open], 0
    mov     word [tor_tunnel_stream_id], 0
    mov     dword [tor_dir_stream_open], 0
    mov     word [tor_dir_stream_id], 0
    mov     dword [tor_tunnel_rx_head], 0
    mov     dword [tor_tunnel_rx_tail], 0

    ; === Phase 1: Connect to guard relay ===
    lea     rdi, [rel str_tor_connect]
    call    _tor_print_status

    ; Load default guard IP and port
    ; The IP is stored as db 0x0A,0x00,0x02,0x02 — loading as a dword
    ; gives 0x0202000A, whose in-memory bytes (0A 00 02 02) already match
    ; the network-order representation. No bswap — er_ip_send stores this
    ; dword directly into the IP header, and the memory byte order produces
    ; the correct big-endian wire format.
    mov     edi, [rel tor_default_guard_ip]
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

    ; === Phase 2: Build bootstrap circuit ===
    ; Bootstrap uses temporary key material to bring up a one-hop
    ; directory channel. A real app circuit is built after descriptor fetch.

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

    ; Mark ready before directory channel setup/fetch
    mov     dword [tor_state + TOR_STATE_LINK_ESTABLISHED], 1

    ; === Phase 3: Fetch directory consensus + descriptor over BEGIN_DIR ===
    call    er_tor_directory_fetch_consensus
    test    eax, eax
    js      .dir_fail

    ; === Phase 4: Build real circuit using parsed relay material ===
    sub     rsp, 64
    lea     rdi, [rsp]
    lea     rsi, [tor_state + TOR_STATE_GUARD_FINGERPRINT]
    mov     edx, 20
    call    er_memcpy
    lea     rdi, [rsp + 20]
    lea     rsi, [tor_guard_onion_key]
    mov     edx, 32
    call    er_memcpy
    lea     rdi, [tor_circ_id_app]
    mov     rsi, rsp
    lea     rdx, [rsp + 20]
    call    er_tor_circuit_create
    add     rsp, 64
    test    eax, eax
    js      .circ_fail

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

.dir_fail:
    lea     rdi, [rel str_tor_dir_fail]
    call    _tor_print_status
    mov     eax, -1
    er_err  ERROR_TOR_PROTOCOL_ERR
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
str_tor_dir_consensus_get: db "GET /tor/status-vote/current/consensus HTTP/1.1", 0x0D, 0x0A, "Host: tor", 0x0D, 0x0A, "Connection: close", 0x0D, 0x0A, 0x0D, 0x0A
str_tor_dir_consensus_get_len equ $ - str_tor_dir_consensus_get
str_tor_dir_desc_get_prefix: db "GET /tor/server/fp/"
str_tor_dir_desc_get_prefix_len equ $ - str_tor_dir_desc_get_prefix
str_tor_dir_desc_get_suffix: db " HTTP/1.1", 0x0D, 0x0A, "Host: tor", 0x0D, 0x0A, "Connection: close", 0x0D, 0x0A, 0x0D, 0x0A
str_tor_dir_desc_get_suffix_len equ $ - str_tor_dir_desc_get_suffix
str_tor_ntor_key_prefix: db "ntor-onion-key "
str_tor_ntor_key_prefix_len equ $ - str_tor_ntor_key_prefix
str_flag_guard: db "Guard"
str_flag_running: db "Running"
str_flag_valid: db "Valid"

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

    ; Fast-path: tunnel cell payload (exactly one local cell) for the
    ; configured tunnel stream. Drop when ring is full.
    movzx   eax, word [tor_tunnel_stream_id]
    cmp     r14w, ax
    jne     .print_data
    cmp     ecx, LOCAL_CELL_SIZE
    jne     .print_data
    mov     eax, [tor_tunnel_rx_head]
    mov     edx, [tor_tunnel_rx_tail]
    sub     eax, edx
    cmp     eax, 4
    jae     .done
    mov     eax, [tor_tunnel_rx_head]
    and     eax, 3
    imul    eax, LOCAL_CELL_SIZE
    lea     rdi, [tor_tunnel_rx_ring + rax]
    lea     rsi, [tor_rx_cell + 16]
    mov     edx, LOCAL_CELL_SIZE
    call    er_memcpy
    inc     dword [tor_tunnel_rx_head]
    jmp     .done

.print_data:
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
