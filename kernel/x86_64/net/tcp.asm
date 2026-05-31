; EdgeRun TCP module — x86_64 assembly
; TCP connection management, state machine, segment handling.
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"

extern er_ip_send
extern er_net_get_ip
extern er_checksum
extern er_memcpy
extern er_memset
extern er_tpm_get_random
extern er_tpm_crb_transfer
extern er_tpm_parse_get_random
extern er_serial_putchar
extern er_serial_puthex32

SECTION .data

; Ephemeral port allocator
tcp_next_port: dw EPHEMERAL_PORT_START

; Connection table
tcp_conns:
times TCP_MAX_CONNS db 0  ; zero-filled at BSS equivalent

; For BSS initialization we use explicit resb
; but we need link-time zeroing. Let's use .bss.

SECTION .bss

tcp_conns_bss: resb TCP_MAX_CONNS * TCP_CONN_SIZE

; Static buffer for building TCP segments (TCP header + payload)
; Max size: TCP header (40 with options) + payload (1460) = 1500
tcp_seg_buf: resb 1500
tcp_seg_len: resd 1

; Temp storage for incoming segment payload pointer (saved during connection lookup)
tcp_in_payload_ptr: resq 1

; TPM command/response buffers for ISN generation
tpm_isn_cmd:  resb 64
tpm_isn_rsp:  resb 64
tpm_isn_out:  resb 4

SECTION .text

; ==================================================================
; _tcp_conn_ptr — get pointer to connection table entry
; rdi = conn_id (0..TCP_MAX_CONNS-1)
; returns rax = pointer to entry, or 0 if invalid
; ==================================================================
_tcp_conn_ptr:
    cmp     edi, TCP_MAX_CONNS
    jae     .bad
    mov     eax, edi
    imul    eax, TCP_CONN_SIZE
    add     rax, tcp_conns_bss
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    ret

er_fn er_tcp_init
    ; Zero the connection table
    mov     edi, tcp_conns_bss
    xor     esi, esi            ; value = 0
    mov     edx, TCP_MAX_CONNS * TCP_CONN_SIZE
    call    er_memset
    ; Reset port allocator
    mov     word [tcp_next_port], EPHEMERAL_PORT_START
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_tcp_get_state — get TCP connection state
; int er_tcp_get_state(uint32_t conn_id)
;
; Returns: eax = TCP state constant (TCP_CLOSED, TCP_SYN_SENT, etc.)
;          eax = -1 on error, rdx = error code
; ==================================================================
er_fn er_tcp_get_state
    push    rbx
    mov     ebx, edi        ; conn_id

    mov     edi, ebx
    call    _tcp_conn_ptr
    test    rax, rax
    jz      .bad

    mov     eax, [rax + TCP_CONN_STATE]
    er_ok
    pop     rbx
    er_ret

.bad:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     rbx
    er_ret
; ==================================================================

er_fn er_tcp_connect
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; dst_ip (network order)
    mov     r13w, si        ; dst_port (host order)
    mov     r14d, edx       ; src_ip (network order)
    mov     r15w, cx        ; src_port (host order, 0 = auto)
    test    r14d, r14d
    jnz     .have_src_ip
    call    er_net_get_ip
    mov     r14d, eax
.have_src_ip:

    ; Find free connection slot
    xor     ebx, ebx
.find_free:
    cmp     ebx, TCP_MAX_CONNS
    jae     .full

    mov     eax, ebx
    imul    eax, TCP_CONN_SIZE

    cmp     dword [tcp_conns_bss + eax + TCP_CONN_STATE], TCP_CLOSED
    je      .found_slot

    inc     ebx
    jmp     .find_free

.found_slot:
    ; Allocate port if needed
    test    r15w, r15w
    jnz     .have_port
    mov     ax, [tcp_next_port]
    mov     r15w, ax
    inc     word [tcp_next_port]
    cmp     word [tcp_next_port], 65535
    jbe     .have_port
    mov     word [tcp_next_port], EPHEMERAL_PORT_START

.have_port:
    ; Initialize connection entry
    mov     eax, ebx
    imul    eax, TCP_CONN_SIZE
    mov     r8, rax
    add     r8, tcp_conns_bss

    mov     dword [r8 + TCP_CONN_STATE], TCP_SYN_SENT
    mov     [r8 + TCP_CONN_DST_IP], r12d
    mov     [r8 + TCP_CONN_SRC_IP], r14d
    mov     [r8 + TCP_CONN_DST_PORT], r13w
    mov     [r8 + TCP_CONN_SRC_PORT], r15w

    ; Generate ISN from TPM RNG (hard requirement — no fallback)
    mov     rdi, tpm_isn_cmd
    mov     esi, 4
    call    er_tpm_get_random
    test    rax, rax
    jz      .tpm_fail

    mov     esi, 12             ; TPM_CMD_GET_RANDOM_LEN
    mov     rdx, tpm_isn_rsp
    mov     ecx, 64
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .tpm_fail
    ; Debug: got transfer
    push    rax
    mov     edi, 0x3f8
    mov     esi, 'X'
    call    er_serial_putchar
    pop     rax

    mov     rdi, tpm_isn_rsp
    mov     esi, eax
    mov     rdx, tpm_isn_out
    mov     ecx, 4
    call    er_tpm_parse_get_random
    test    rax, rax
    jz      .tpm_fail
    ; Debug: got parse
    mov     edi, 0x3f8
    mov     esi, 'P'
    call    er_serial_putchar

    ; Recalculate connection pointer (r8 may be clobbered by TPM calls)
    mov     eax, ebx
    imul    eax, TCP_CONN_SIZE
    mov     r8, rax
    add     r8, tcp_conns_bss

    mov     eax, [tpm_isn_out]
    add     eax, ebx            ; unique per connection
    mov     [r8 + TCP_CONN_ISS], eax
    mov     [r8 + TCP_CONN_SND_NXT], eax

    ; IRS unknown yet
    mov     dword [r8 + TCP_CONN_IRS], 0
    mov     dword [r8 + TCP_CONN_RCV_NXT], 1

    ; Windows and MSS
    mov     word [r8 + TCP_CONN_SND_WND], 65535
    mov     word [r8 + TCP_CONN_RCV_WND], 65535
    mov     word [r8 + TCP_CONN_MSS], TCP_DEFAULT_MSS

    ; Clear buffers
    mov     dword [r8 + TCP_CONN_RX_LEN], 0
    mov     dword [r8 + TCP_CONN_TX_LEN], 0

    ; Send SYN
    mov     rdi, r8
    call    _tcp_send_syn
    test    eax, eax
    js      .send_fail

    ; Return connection ID
    mov     eax, ebx
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

.send_fail:
    ; Mark connection as closed
    mov     eax, ebx
    imul    eax, TCP_CONN_SIZE
    mov     dword [tcp_conns_bss + eax + TCP_CONN_STATE], TCP_CLOSED

    mov     eax, -1
    er_err  ERROR_IO
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.tpm_fail:
    ; TPM RNG failed — no fallback, hard requirement
    jmp     .send_fail
; ==================================================================

; ==================================================================
; _tcp_send_syn — send SYN segment for connection
; int _tcp_send_syn(tcp_conn *conn)
; ==================================================================
_tcp_send_syn:
    push    r12

    mov     r12, rdi        ; conn pointer
    lea     rdi, [tcp_seg_buf]

    ; Build TCP header with MSS option (24 bytes)
    ; Data offset = 6 (24 bytes) = 0x60
    movzx   eax, word [r12 + TCP_CONN_SRC_PORT]
    xchg    ah, al
    mov     [rdi + TCP_SRC_PORT], ax

    movzx   eax, word [r12 + TCP_CONN_DST_PORT]
    xchg    ah, al
    mov     [rdi + TCP_DST_PORT], ax

    ; Sequence number = ISS (network order)
    mov     eax, [r12 + TCP_CONN_ISS]
    bswap   eax
    mov     [rdi + TCP_SEQ_NUM], eax

    ; ACK number = 0 (no ACK in SYN)
    mov     dword [rdi + TCP_ACK_NUM], 0

    ; Data offset = 6 (24 bytes with MSS option)
    mov     byte [rdi + TCP_DATA_OFF], 0x60

    ; Flags = SYN
    mov     byte [rdi + TCP_FLAGS], TCP_SYN

    ; Window (0xFFFF is byte-order symmetric)
    mov     word [rdi + TCP_WINDOW], 0xFFFF

    ; Checksum = 0 (will compute)
    mov     word [rdi + TCP_CHECKSUM], 0

    ; Urgent pointer = 0
    mov     word [rdi + TCP_URGENT], 0

    ; MSS option: Kind=2, Len=4, MSS value
    mov     byte [rdi + 20], 2       ; kind
    mov     byte [rdi + 21], 4       ; length
    mov     eax, TCP_DEFAULT_MSS
    xchg    ah, al
    mov     [rdi + 22], ax           ; MSS value

    ; Compute TCP checksum (pseudo-header + segment)
    ; Destination: build pseudo-header, compute checksum over the combined buffer
    mov     rdi, r12        ; conn pointer
    ; We'll call a generic function
    lea     rsi, [tcp_seg_buf]
    mov     edx, 24         ; TCP header length with MSS option

    mov     rdi, r12
    lea     rsi, [tcp_seg_buf]
    mov     edx, 24
    call    _tcp_compute_checksum
    mov     [tcp_seg_buf + TCP_CHECKSUM], ax

    ; Send via IP
    mov     edi, [r12 + TCP_CONN_DST_IP]  ; dst_ip
    mov     esi, IP_PROTO_TCP
    lea     rdx, [tcp_seg_buf]
    mov     ecx, 24
    call    er_ip_send
    test    eax, eax
    js      .fail

    xor     eax, eax
    pop     r12
    ret

.fail:
    mov     eax, -1
    pop     r12
    ret

; ==================================================================
; _tcp_compute_checksum — compute TCP checksum with pseudo-header
; void _tcp_compute_checksum(tcp_conn *conn, void *tcp_seg, uint32_t seg_len)
; Stores checksum (network byte order) at tcp_seg + TCP_CHECKSUM
; ==================================================================
_tcp_compute_checksum:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; conn
    mov     r13, rsi        ; tcp_seg
    mov     r14d, edx       ; seg_len

    ; Build pseudo-header on stack (12 bytes)
    sub     rsp, 16         ; 12 bytes + padding

    ; Source IP (from connection)
    mov     eax, [r12 + TCP_CONN_SRC_IP]
    mov     [rsp + TCP_PSEUDO_SRC], eax

    ; Destination IP
    mov     eax, [r12 + TCP_CONN_DST_IP]
    mov     [rsp + TCP_PSEUDO_DST], eax

    ; Zero
    mov     byte [rsp + TCP_PSEUDO_ZERO], 0

    ; Protocol (TCP = 6)
    mov     byte [rsp + TCP_PSEUDO_PROT], IP_PROTO_TCP

    ; TCP length (network byte order)
    mov     eax, r14d
    xchg    ah, al
    mov     [rsp + TCP_PSEUDO_LEN_IDX], ax  ; equ and label naming...

    ; First checksum pass: pseudo-header
    mov     rdi, rsp
    mov     esi, TCP_PSEUDO_SIZE
    call    er_checksum
    mov     ebx, eax        ; partial sum

    ; Second pass: TCP segment (seg_len bytes)
    mov     rdi, r13
    mov     esi, r14d
    call    er_checksum
    add     ax, bx
    adc     ax, 0

    ; Fold 32-bit to 16-bit
    mov     ecx, eax
    shr     ecx, 16
    and     eax, 0xFFFF
    add     ax, cx
    adc     ax, 0

    ; One's complement
    not     ax
    cmp     ax, 0xFFFF
    jne     .store
    xor     ax, ax

.store:
    ; Store checksum in network byte order at TCP_CHECKSUM
    xchg    ah, al
    mov     [r13 + TCP_CHECKSUM], ax

    add     rsp, 16
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; Missing label for pseudo-header length field
TCP_PSEUDO_LEN_IDX equ TCP_PSEUDO_LEN  ; use same offset

; ==================================================================
; er_tcp_send — send data on established connection
; int er_tcp_send(uint32_t conn_id, const void *data, uint32_t len)
; ==================================================================
er_fn er_tcp_send
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi       ; conn_id
    mov     r13, rsi        ; data
    mov     r14d, edx       ; len

    ; Get connection pointer
    mov     edi, r12d
    call    _tcp_conn_ptr
    test    rax, rax
    jz      .bad_conn

    mov     rbx, rax        ; conn pointer

    ; Check state is ESTABLISHED
    cmp     dword [rbx + TCP_CONN_STATE], TCP_ESTABLISHED
    jne     .not_established

    ; Limit length to MSS
    movzx   eax, word [rbx + TCP_CONN_MSS]
    cmp     r14d, eax
    jbe     .len_ok
    mov     r14d, eax

.len_ok:
    ; Build TCP segment in buffer
    lea     rdi, [tcp_seg_buf]

    ; Source port
    movzx   eax, word [rbx + TCP_CONN_SRC_PORT]
    xchg    ah, al
    mov     [rdi + TCP_SRC_PORT], ax

    ; Destination port
    movzx   eax, word [rbx + TCP_CONN_DST_PORT]
    xchg    ah, al
    mov     [rdi + TCP_DST_PORT], ax

    ; Sequence number = snd_nxt
    mov     eax, [rbx + TCP_CONN_SND_NXT]
    bswap   eax
    mov     [rdi + TCP_SEQ_NUM], eax

    ; ACK number = rcv_nxt
    mov     eax, [rbx + TCP_CONN_RCV_NXT]
    bswap   eax
    mov     [rdi + TCP_ACK_NUM], eax

    ; Data offset = 5 (20 bytes, no options)
    mov     byte [rdi + TCP_DATA_OFF], TCP_DEFAULT_DATA_OFF

    ; Flags = PSH | ACK
    mov     byte [rdi + TCP_FLAGS], TCP_PSH | TCP_ACK

    ; Window
    movzx   eax, word [rbx + TCP_CONN_RCV_WND]
    xchg    ah, al
    mov     [rdi + TCP_WINDOW], ax

    ; Checksum placeholder
    mov     word [rdi + TCP_CHECKSUM], 0

    ; Urgent pointer
    mov     word [rdi + TCP_URGENT], 0

    ; Copy payload after TCP header
    cmp     r14d, 0
    je      .checksum

    lea     rdi, [tcp_seg_buf + TCP_HDR_LEN]
    mov     rsi, r13
    mov     edx, r14d
    call    er_memcpy

.checksum:
    ; Compute TCP checksum
    mov     rdi, rbx        ; conn
    lea     rsi, [tcp_seg_buf]
    mov     edx, TCP_HDR_LEN
    add     edx, r14d       ; total TCP segment length
    call    _tcp_compute_checksum

    ; Send via IP
    mov     edi, [rbx + TCP_CONN_DST_IP]  ; dst_ip
    mov     esi, IP_PROTO_TCP
    lea     rdx, [tcp_seg_buf]
    mov     ecx, TCP_HDR_LEN
    add     ecx, r14d
    call    er_ip_send
    test    eax, eax
    js      .send_fail

    ; Update snd_nxt
    mov     eax, [rbx + TCP_CONN_SND_NXT]
    add     eax, r14d
    mov     [rbx + TCP_CONN_SND_NXT], eax

    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad_conn:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.not_established:
    mov     eax, -1
    er_err  ERROR_TCP_CLOSED
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.send_fail:
    mov     eax, -1
    er_err  ERROR_IO
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
; ==================================================================

er_fn er_tcp_recv
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi       ; conn_id
    mov     r13, rsi        ; buf
    mov     r14, rdx        ; len pointer

    ; Get connection pointer
    mov     edi, r12d
    call    _tcp_conn_ptr
    test    rax, rax
    jz      .bad_conn

    mov     rbx, rax

    ; Check state
    cmp     dword [rbx + TCP_CONN_STATE], TCP_ESTABLISHED
    je      .recv_data
    cmp     dword [rbx + TCP_CONN_STATE], TCP_CLOSE_WAIT
    je      .recv_data

    ; Closed or closing — no more data
    mov     dword [r14], 0
    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.recv_data:
    ; Check how much data is in the buffer
    mov     ecx, [rbx + TCP_CONN_RX_LEN]
    cmp     ecx, 0
    je      .no_data

    ; Limit to available and requested
    mov     eax, [r14]      ; requested max
    cmp     ecx, eax
    jbe     .copy_len
    mov     ecx, eax

.copy_len:
    ; Copy data from connection buffer to user buffer
    lea     rdi, [rbx + TCP_CONN_RX_BUF]
    mov     rsi, r13
    mov     edx, ecx

    mov     rdi, r13        ; dst = user buffer
    lea     rsi, [rbx + TCP_CONN_RX_BUF]  ; src = conn buffer
    mov     edx, ecx        ; len
    push    rcx             ; save count before er_memcpy clobbers rcx
    call    er_memcpy
    pop     rcx

    ; Shift remaining data in connection buffer
    mov     eax, [rbx + TCP_CONN_RX_LEN]
    sub     eax, ecx
    mov     [rbx + TCP_CONN_RX_LEN], eax

    cmp     eax, 0
    je      .done_copy

    ; Move remaining data to front
    ; rdi = start of rx buffer (dest)
    ; rsi = start + copied_bytes (src)
    lea     rdi, [rbx + TCP_CONN_RX_BUF]
    lea     rsi, [rbx + TCP_CONN_RX_BUF]
    mov     r8d, ecx
    add     rsi, r8
    mov     edx, eax
    call    er_memcpy

.done_copy:
    ; Update rcv_nxt (acknowledge data)
    mov     eax, [rbx + TCP_CONN_RCV_NXT]
    add     eax, ecx
    mov     [rbx + TCP_CONN_RCV_NXT], eax

    ; Update stored length
    mov     [r14], ecx

    ; Send ACK
    mov     rdi, rbx
    call    _tcp_send_ack

    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.no_data:
    mov     dword [r14], 0
    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad_conn:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
; ==================================================================

; ==================================================================
; er_tcp_close — gracefully close TCP connection
; int er_tcp_close(uint32_t conn_id)
; ==================================================================
er_fn er_tcp_close
    push    rbx

    mov     ebx, edi        ; conn_id

    ; Get connection pointer
    mov     edi, ebx
    call    _tcp_conn_ptr
    test    rax, rax
    jz      .bad_conn

    mov     rbx, rax

    ; Check state
    cmp     dword [rbx + TCP_CONN_STATE], TCP_ESTABLISHED
    jne     .check_closing

    ; Send FIN
    mov     rdi, rbx
    call    _tcp_send_fin
    test    eax, eax
    js      .fail

    mov     dword [rbx + TCP_CONN_STATE], TCP_FIN_WAIT_1
    jmp     .done

.check_closing:
    cmp     dword [rbx + TCP_CONN_STATE], TCP_CLOSE_WAIT
    jne     .not_connected

    ; Send FIN from CLOSE_WAIT
    mov     rdi, rbx
    call    _tcp_send_fin
    test    eax, eax
    js      .fail

    mov     dword [rbx + TCP_CONN_STATE], TCP_LAST_ACK
    jmp     .done

.not_connected:
    ; Already closed or closing
    xor     eax, eax
    er_ok
    pop     rbx
    er_ret

.done:
    xor     eax, eax
    er_ok
    pop     rbx
    er_ret

.bad_conn:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     rbx
    er_ret

.fail:
    mov     eax, -1
    pop     rbx
    er_ret
; ==================================================================

_tcp_send_ack:
    push    r12
    mov     r12, rdi

    lea     rdi, [tcp_seg_buf]

    ; Source port
    movzx   eax, word [r12 + TCP_CONN_SRC_PORT]
    xchg    ah, al
    mov     [rdi + TCP_SRC_PORT], ax

    ; Destination port
    movzx   eax, word [r12 + TCP_CONN_DST_PORT]
    xchg    ah, al
    mov     [rdi + TCP_DST_PORT], ax

    ; Sequence number = snd_nxt (but ACK doesn't consume sequence space)
    mov     eax, [r12 + TCP_CONN_SND_NXT]
    bswap   eax
    mov     [rdi + TCP_SEQ_NUM], eax

    ; ACK number = rcv_nxt
    mov     eax, [r12 + TCP_CONN_RCV_NXT]
    bswap   eax
    mov     [rdi + TCP_ACK_NUM], eax

    ; Data offset = 5
    mov     byte [rdi + TCP_DATA_OFF], TCP_DEFAULT_DATA_OFF

    ; Flags = ACK
    mov     byte [rdi + TCP_FLAGS], TCP_ACK

    ; Window
    movzx   eax, word [r12 + TCP_CONN_RCV_WND]
    xchg    ah, al
    mov     [rdi + TCP_WINDOW], ax

    ; Checksum placeholder
    mov     word [rdi + TCP_CHECKSUM], 0

    ; Urgent pointer
    mov     word [rdi + TCP_URGENT], 0

    ; Compute checksum (no payload)
    mov     rdi, r12
    lea     rsi, [tcp_seg_buf]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum

    ; Send via IP
    mov     edi, [r12 + TCP_CONN_DST_IP]
    mov     esi, IP_PROTO_TCP
    lea     rdx, [tcp_seg_buf]
    mov     ecx, TCP_HDR_LEN
    call    er_ip_send

    pop     r12
    ret

_tcp_send_fin:
    push    r12
    mov     r12, rdi

    lea     rdi, [tcp_seg_buf]

    ; Source port
    movzx   eax, word [r12 + TCP_CONN_SRC_PORT]
    xchg    ah, al
    mov     [rdi + TCP_SRC_PORT], ax

    ; Destination port
    movzx   eax, word [r12 + TCP_CONN_DST_PORT]
    xchg    ah, al
    mov     [rdi + TCP_DST_PORT], ax

    ; Sequence number = snd_nxt
    mov     eax, [r12 + TCP_CONN_SND_NXT]
    bswap   eax
    mov     [rdi + TCP_SEQ_NUM], eax

    ; ACK number = rcv_nxt
    mov     eax, [r12 + TCP_CONN_RCV_NXT]
    bswap   eax
    mov     [rdi + TCP_ACK_NUM], eax

    ; Data offset = 5
    mov     byte [rdi + TCP_DATA_OFF], TCP_DEFAULT_DATA_OFF

    ; Flags = FIN | ACK
    mov     byte [rdi + TCP_FLAGS], TCP_FIN | TCP_ACK

    ; Window
    movzx   eax, word [r12 + TCP_CONN_RCV_WND]
    xchg    ah, al
    mov     [rdi + TCP_WINDOW], ax

    ; Checksum placeholder
    mov     word [rdi + TCP_CHECKSUM], 0

    ; Urgent pointer
    mov     word [rdi + TCP_URGENT], 0

    ; Compute checksum
    mov     rdi, r12
    lea     rsi, [tcp_seg_buf]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum

    ; Send via IP
    mov     edi, [r12 + TCP_CONN_DST_IP]
    mov     esi, IP_PROTO_TCP
    lea     rdx, [tcp_seg_buf]
    mov     ecx, TCP_HDR_LEN
    call    er_ip_send

    ; FIN consumes one sequence number
    mov     eax, [r12 + TCP_CONN_SND_NXT]
    inc     eax
    mov     [r12 + TCP_CONN_SND_NXT], eax

    pop     r12
    ret

er_fn er_tcp_handle
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; IP header
    mov     r13d, esi       ; IP total length

    ; TCP header starts after IP header (20 bytes)
    lea     rbx, [rdi + 20]

    ; Minimum TCP header length
    cmp     esi, 40         ; IP(20) + TCP(20)
    jb      .done

    ; Get TCP data offset (top 4 bits * 4 = header length)
    movzx   eax, byte [rbx + TCP_DATA_OFF]
    shr     eax, 4
    shl     eax, 2          ; TCP header length in bytes
    cmp     eax, TCP_HDR_LEN
    jb      .done           ; invalid header length

    ; Compute TCP segment length
    mov     ecx, r13d
    sub     ecx, 20         ; minus IP header
    sub     ecx, eax        ; minus TCP header options
    js      .done
    mov     r14d, ecx       ; TCP payload length

    ; Extract fields
    movzx   r15d, word [rbx + TCP_SRC_PORT]
    xchg    r15b, r15b      ; network to host byte order (just swap bytes)
    rol     r15w, 8

    movzx   ecx, word [rbx + TCP_DST_PORT]
    rol     cx, 8

    mov     r8d, [rbx + TCP_SEQ_NUM]
    bswap   r8d             ; sequence number (host order)

    mov     r9d, [rbx + TCP_ACK_NUM]
    bswap   r9d             ; ack number (host order)

    movzx   r10d, byte [rbx + TCP_FLAGS]

    movzx   r11d, word [rbx + TCP_WINDOW]
    rol     r11w, 8

    ; Look up connection by (dst_ip, dst_port, src_ip, src_port)
    ; For client-side connections:
    ;   incoming dst_ip = conn.src_ip, dst_port = conn.src_port
    ;   incoming src_ip = conn.dst_ip, src_port = conn.dst_port

    ; Save TCP payload pointer before find_conn loop clobbers rbx/r12
    ; rbx = TCP header, rax = TCP header length (from data offset)
    lea     r13, [rbx + rax]        ; r13 reused: IP total len → payload ptr

    mov     edx, [r12 + IP_DST]     ; destination IP in packet
    mov     edi, [r12 + IP_SRC]     ; source IP in packet

    xor     ebx, ebx        ; connection index

.find_conn:
    cmp     ebx, TCP_MAX_CONNS
    jae     .done

    mov     eax, ebx
    imul    eax, TCP_CONN_SIZE
    mov     rsi, rax
    add     rsi, tcp_conns_bss

    cmp     dword [rsi + TCP_CONN_STATE], TCP_CLOSED
    je      .next_conn

    ; Check: packet dst_ip == conn.src_ip ?
    cmp     [rsi + TCP_CONN_SRC_IP], edx
    jne     .next_conn

    ; Check: packet src_ip == conn.dst_ip ?
    cmp     [rsi + TCP_CONN_DST_IP], edi
    jne     .next_conn

    ; Check: packet dst_port == conn.src_port ?
    movzx   eax, word [rsi + TCP_CONN_SRC_PORT]
    cmp     ax, cx
    jne     .next_conn

    ; Check: packet src_port == conn.dst_port ?
    movzx   eax, word [rsi + TCP_CONN_DST_PORT]
    cmp     ax, r15w
    jne     .next_conn

    ; Found connection!
    mov     r12, rsi        ; conn pointer
    jmp     .handle_seg

.next_conn:
    inc     ebx
    jmp     .find_conn

.handle_seg:
    ; r12 = conn, rbx = conn index
    ; r8 = seq, r9 = ack, r10 = flags, r11 = window
    ; r14 = payload length
    ; r15 = src_port (host order)
    ; cx  = dst_port (host order)

    ; Handle RST
    test    r10b, TCP_RST
    jnz     .handle_rst

    ; Handle SYN
    test    r10b, TCP_SYN
    jnz     .handle_syn

    ; Handle FIN
    test    r10b, TCP_FIN
    jnz     .handle_fin

    ; Handle ACK (regular data segment or pure ACK)
    test    r10b, TCP_ACK
    jnz     .handle_ack

    jmp     .done

; ---- SYN handling ----
.handle_syn:
    ; We only expect SYN in SYN_SENT state
    mov     eax, [r12 + TCP_CONN_STATE]
    cmp     eax, TCP_SYN_SENT
    jne     .done

    ; Verify ACK field matches ISS+1
    mov     eax, [r12 + TCP_CONN_ISS]
    inc     eax
    cmp     r9d, eax
    jne     .done          ; wrong ACK, ignore

    ; Set IRS = seq
    mov     [r12 + TCP_CONN_IRS], r8d
    mov     eax, r8d
    inc     eax
    mov     [r12 + TCP_CONN_RCV_NXT], eax

    ; Update snd_nxt (our SYN consumed one byte of sequence space)
    mov     eax, [r12 + TCP_CONN_ISS]
    inc     eax
    mov     [r12 + TCP_CONN_SND_NXT], eax

    ; Update window
    mov     [r12 + TCP_CONN_SND_WND], r11w

    ; Transition to ESTABLISHED
    mov     dword [r12 + TCP_CONN_STATE], TCP_ESTABLISHED

    ; Send ACK
    mov     rdi, r12
    call    _tcp_send_ack

    jmp     .done

; ---- FIN handling ----
.handle_fin:
    ; FIN received — from remote side closing
    mov     eax, [r12 + TCP_CONN_STATE]
    cmp     eax, TCP_ESTABLISHED
    je      .fin_established
    cmp     eax, TCP_FIN_WAIT_1
    je      .fin_fin_wait_1
    jmp     .done

.fin_established:
    mov     dword [r12 + TCP_CONN_STATE], TCP_CLOSE_WAIT

    ; Update rcv_nxt for FIN
    mov     eax, [r12 + TCP_CONN_RCV_NXT]
    inc     eax
    mov     [r12 + TCP_CONN_RCV_NXT], eax

    ; Send ACK
    mov     rdi, r12
    call    _tcp_send_ack
    jmp     .done

.fin_fin_wait_1:
    ; Our FIN and their FIN crossed
    mov     dword [r12 + TCP_CONN_STATE], TCP_TIME_WAIT

    ; Update rcv_nxt for FIN
    mov     eax, [r12 + TCP_CONN_RCV_NXT]
    inc     eax
    mov     [r12 + TCP_CONN_RCV_NXT], eax

    ; Send ACK
    mov     rdi, r12
    call    _tcp_send_ack
    jmp     .done

; ---- ACK handling ----
.handle_ack:
    mov     eax, [r12 + TCP_CONN_STATE]

    ; In SYN_SENT: ACK means SYN-ACK was valid
    cmp     eax, TCP_SYN_SENT
    je      .ack_syn_sent

    ; In ESTABLISHED: normal data ACK
    cmp     eax, TCP_ESTABLISHED
    je      .ack_established

    ; In FIN_WAIT_1: ACK of our FIN
    cmp     eax, TCP_FIN_WAIT_1
    je      .ack_fin_wait_1

    ; In LAST_ACK: ACK of our FIN
    cmp     eax, TCP_LAST_ACK
    je      .ack_last_ack

    jmp     .done

.ack_syn_sent:
    ; SYN-ACK handling was done in SYN handler
    ; This is just SYN-ACK's ACK flag being processed
    jmp     .done

.ack_fin_wait_1:
    mov     dword [r12 + TCP_CONN_STATE], TCP_FIN_WAIT_2
    jmp     .done

.ack_last_ack:
    mov     dword [r12 + TCP_CONN_STATE], TCP_CLOSED
    jmp     .done

.ack_established:
    ; Process data payload if present
    cmp     r14d, 0
    je      .ack_only

    ; Check if payload fits in rx buffer
    mov     eax, [r12 + TCP_CONN_RX_LEN]
    add     eax, r14d
    cmp     eax, 1460       ; TCP_CONN_RX_BUF size
    ja      .ack_only       ; drop if full

    ; Copy payload to connection rx buffer
    lea     rdi, [r12 + TCP_CONN_RX_BUF]
    add     rdi, [r12 + TCP_CONN_RX_LEN]   ; dest = rx_buf + rx_len
    mov     rsi, r13                        ; src = saved payload ptr (r13)
    mov     edx, r14d                       ; len
    call    er_memcpy

    ; Update rx length
    mov     eax, [r12 + TCP_CONN_RX_LEN]
    add     eax, r14d
    mov     [r12 + TCP_CONN_RX_LEN], eax

    ; Update rcv_nxt
    mov     eax, [r12 + TCP_CONN_RCV_NXT]
    add     eax, r14d
    mov     [r12 + TCP_CONN_RCV_NXT], eax

    ; Send ACK
    mov     rdi, r12
    call    _tcp_send_ack
    jmp     .done

.ack_only:
    ; Pure ACK, no data
    jmp     .done

; ---- RST handling ----
.handle_rst:
    mov     dword [r12 + TCP_CONN_STATE], TCP_CLOSED
    jmp     .done

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_tcp_poll — check for timeouts and retransmit if needed
; void er_tcp_poll(void)
;
; Should be called periodically by the main loop.
; ==================================================================
er_fn er_tcp_poll
    push    rbx
    push    r12

    xor     ebx, ebx

.poll_loop:
    cmp     ebx, TCP_MAX_CONNS
    jae     .done_poll

    mov     eax, ebx
    imul    eax, TCP_CONN_SIZE
    lea     r12, [tcp_conns_bss + rax]

    ; Check for timed-out connections
    mov     eax, [r12 + TCP_CONN_STATE]
    cmp     eax, TCP_SYN_SENT
    je      .check_syn_timeout
    cmp     eax, TCP_TIME_WAIT
    je      .check_timewait

    ; In the future: check retransmission timeouts for sent but unacked data

.next_poll:
    inc     ebx
    jmp     .poll_loop

.check_syn_timeout:
    ; For now, just check if too many ticks have passed
    ; A proper implementation would track when SYN was sent
    ; For simplicity, leave SYN_SENT connections alone (they'll time out eventually)
    jmp     .next_poll

.check_timewait:
    ; TIME_WAIT should last 2*MSL (~60 seconds)
    ; For now, immediately transition to CLOSED
    mov     dword [r12 + TCP_CONN_STATE], TCP_CLOSED
    jmp     .next_poll

.done_poll:
    pop     r12
    pop     rbx
    er_ok
    er_ret
; ==================================================================
