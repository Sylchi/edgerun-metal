; EdgeRun Virtio-net driver — x86_64 assembly
; System V AMD64 ABI. Freestanding — no libc, no external dependencies.
;
; Minimal virtio-net driver: one RX queue, one TX queue.
; No offloads, no checksum offloading, no multi-segment buffers.

%include "x86_64/macros.inc"
%include "driver/virtio_constants.inc"
%include "driver/virtio_net_constants.inc"

extern er_virtio_find_device
extern er_virtio_map_device
extern er_virtio_enable_device
extern er_virtio_negotiate_features
extern er_virtio_select_queue
extern er_serial_putchar
extern er_serial_puthex32
extern er_virtio_read_queue_size
extern er_virtio_set_queue_size
extern er_virtio_set_queue_address
extern er_virtio_notify_queue
extern er_virtio_read_status
extern er_virtio_write_status
extern er_virtio_post_descriptor
extern er_virtio_next_used
extern er_virtio_read8
extern er_virtio_write8
extern er_virtio_read16
extern er_virtio_write16
extern er_virtio_read32
extern er_virtio_write32
extern er_serial_puthex64
extern er_serial_puthex32
extern er_serial_putchar

SECTION .text

; ==================================================================
; er_virtio_net_init — discover, map, negotiate, and init net
; int er_virtio_net_init(VIRTIO_NET_DEVICE* dev, VIRTIO_NET_STORAGE* storage)
;
; Returns: eax = 0 on success, non-zero on failure.
; ==================================================================
er_fn er_virtio_net_init
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage

    ; Allocate VIRTIO_DEVICE and VIRTIO_TRANSPORT on stack
    sub     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    mov     rbx, rsp            ; rbx = VIRTIO_DEVICE*
    lea     r14, [rbx + VIRTIO_DEVICE_size]  ; r14 = VIRTIO_TRANSPORT*

    ; 1. PCI discovery
    mov     rdi, VIRTIO_DEVICE_NET
    mov     rsi, rbx
    call    er_virtio_find_device
    test    eax, eax
    jz      .err_not_found

    ; 2. Map BARs
    mov     rdi, rbx
    mov     rsi, r14
    call    er_virtio_map_device

    ; 3. Negotiate features
    lea     rdx, [r12 + VIRTIO_NET_DEVICE.driver_features]
    mov     rdi, r14
    mov     rsi, VIRTIO_NET_SUPPORTED
    call    er_virtio_negotiate_features
    test    eax, eax
    jz      .err_features

    ; 4. Set up RX queue (queue 0) — legacy I/O port mode
    mov     rdi, r14
    xor     esi, esi                    ; queue 0
    call    er_virtio_select_queue

    mov     rdi, r14
    call    er_virtio_read_queue_size
    cmp     ax, VIRTIO_QUEUE_SIZE
    jbe     .rx_size_ok
    mov     ax, VIRTIO_QUEUE_SIZE
.rx_size_ok:
    mov     [r12 + VIRTIO_NET_DEVICE.queue_size], ax
    mov     rdi, r14
    mov     esi, eax
    call    er_virtio_set_queue_size

    ; Legacy: write queue address (desc table physical address)
    mov     rdi, r14
    lea     esi, [r13 + VIRTIO_NET_STORAGE.rx_desc]
    call    er_virtio_set_queue_address

    ; Post an initial RX buffer descriptor
    mov     rdi, r13
    call    _virtio_net_post_rx_buf

    ; 5. Set up TX queue (queue 1) — legacy I/O port mode
    mov     rdi, r14
    mov     esi, VIRTIO_NET_TX_QUEUE
    call    er_virtio_select_queue

    mov     rdi, r14
    call    er_virtio_read_queue_size
    cmp     ax, VIRTIO_QUEUE_SIZE
    jbe     .tx_size_ok
    mov     ax, VIRTIO_QUEUE_SIZE
.tx_size_ok:
    mov     rdi, r14
    mov     esi, eax
    call    er_virtio_set_queue_size

    ; Legacy: write queue address (desc table physical address)
    mov     rdi, r14
    lea     esi, [r13 + VIRTIO_NET_STORAGE.tx_desc]
    call    er_virtio_set_queue_address

    ; 6. Set driver_ok status (legacy: write to I/O port)
    mov     rdi, r14
    mov     esi, VIRTIO_STATUS_DRIVER_OK
    call    er_virtio_write_status

    ; 7. Copy transport into device (needed for device config access)
    mov     ecx, VIRTIO_TRANSPORT_size / 8
    lea     rsi, [r14]
    lea     rdi, [r12 + VIRTIO_NET_DEVICE.transport]
    rep     movsq

    ; 8. Read MAC from device config
    mov     rdi, r12
    call    _virtio_net_read_mac

    ; 9. Read link status from device config
    mov     rdi, r12
    call    _virtio_net_read_link_status

    add     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    xor     eax, eax
    er_ok
    jmp     .out

.err_not_found:
    add     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    mov     eax, ERROR_DEVICE_NOT_FOUND
    er_err  ERROR_DEVICE_NOT_FOUND
    jmp     .out

.err_features:
    add     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    mov     eax, ERROR_FEATURE_NEGOTIATION
    er_err  ERROR_FEATURE_NEGOTIATION
    jmp     .out

.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    ret

; ==================================================================
; _virtio_net_post_rx_buf — post RX buffer descriptor to avail ring
; void _virtio_net_post_rx_buf(VIRTIO_NET_STORAGE* storage)
; ==================================================================
_virtio_net_post_rx_buf:
    ; Set desc[0]: address of rx_buf, len BUF_SIZE, WRITE flag
    lea     rax, [rdi + VIRTIO_NET_STORAGE.rx_buf]
    mov     [rdi + VIRTIO_NET_STORAGE.rx_desc + 0], rax
    mov     dword [rdi + VIRTIO_NET_STORAGE.rx_desc + 8], VIRTIO_NET_BUF_SIZE
    mov     word [rdi + VIRTIO_NET_STORAGE.rx_desc + 12], VIRTIO_DESC_F_WRITE
    mov     word [rdi + VIRTIO_NET_STORAGE.rx_desc + 14], 0   ; next=0

    ; Post to avail ring
    lea     rdi, [rdi + VIRTIO_NET_STORAGE.rx_avail]
    mov     esi, VIRTIO_QUEUE_SIZE
    xor     edx, edx               ; desc_id = 0
    jmp     er_virtio_post_descriptor    ; tail call

; ==================================================================
; _virtio_net_read_mac — read MAC from device config (legacy I/O)
; void _virtio_net_read_mac(VIRTIO_NET_DEVICE* dev)
; ==================================================================
_virtio_net_read_mac:
    push    r12
    push    r13
    mov     r12, rdi

    ; Get device config I/O port
    movzx   edx, word [r12 + VIRTIO_NET_DEVICE.transport + VIRTIO_TRANSPORT.device_config]
    test    dx, dx
    jz      .done

    ; Read MAC bytes 0-3 (dword at device config + 0)
    mov     r13d, edx
    lea     rdi, [r12 + VIRTIO_NET_DEVICE.mac]
    mov     ecx, 6
.next_byte:
    mov     dx, r13w
    in      al, dx
    mov     [rdi], al
    inc     r13d
    inc     rdi
    dec     ecx
    jnz     .next_byte

.done:
    pop     r13
    pop     r12
    ret

; ==================================================================
; _virtio_net_read_link_status — read link status from device config
; void _virtio_net_read_link_status(VIRTIO_NET_DEVICE* dev)
; ==================================================================
_virtio_net_read_link_status:
    push    r12
    push    r13
    mov     r12, rdi

    ; Get device config I/O port + status offset
    movzx   edx, word [r12 + VIRTIO_NET_DEVICE.transport + VIRTIO_TRANSPORT.device_config]
    test    dx, dx
    jz      .done

    add     edx, VIRTIO_NET_CFG_STATUS
    mov     r13w, dx                 ; save port for word read
    mov     dx, r13w
    in      ax, dx
    mov     [r12 + VIRTIO_NET_DEVICE.link_status], ax

.done:
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_virtio_net_transmit — transmit a packet
; int er_virtio_net_transmit(VIRTIO_NET_DEVICE* dev,
;                            VIRTIO_NET_STORAGE* storage,
;                            void* data, uint32_t len)
;
; Returns: eax = 0 on success, non-zero on error.
; ==================================================================
er_fn er_virtio_net_transmit
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage
    mov     r14, rdx            ; data
    mov     r15d, ecx           ; len

    test    r15d, r15d
    jz      .err_invalid

    cmp     r15d, VIRTIO_NET_MTU
    ja      .err_invalid

    ; Clear tx header (all zeros = no offloads)
    xor     eax, eax
    mov     [r13 + VIRTIO_NET_STORAGE.tx_hdr + 0], eax
    mov     [r13 + VIRTIO_NET_STORAGE.tx_hdr + 4], eax
    mov     [r13 + VIRTIO_NET_STORAGE.tx_hdr + 8], eax

    ; Copy data into tx_buf
    push    r15
    push    r14
    lea     rdi, [r13 + VIRTIO_NET_STORAGE.tx_buf]
    mov     rsi, r14
    mov     ecx, r15d
    rep     movsb
    pop     r14
    pop     r15

    ; Build descriptor chain: desc[0] = hdr (OUT), desc[1] = data (OUT)
    lea     rax, [r13 + VIRTIO_NET_STORAGE.tx_hdr]
    mov     [r13 + VIRTIO_NET_STORAGE.tx_desc + 0], rax
    mov     dword [r13 + VIRTIO_NET_STORAGE.tx_desc + 8], VIRTIO_NET_HDR_SIZE
    mov     word [r13 + VIRTIO_NET_STORAGE.tx_desc + 12], VIRTIO_DESC_F_NEXT
    mov     word [r13 + VIRTIO_NET_STORAGE.tx_desc + 14], 1   ; next=1

    lea     rax, [r13 + VIRTIO_NET_STORAGE.tx_buf]
    mov     [r13 + VIRTIO_NET_STORAGE.tx_desc + 16], rax
    mov     [r13 + VIRTIO_NET_STORAGE.tx_desc + 24], r15d
    mov     word [r13 + VIRTIO_NET_STORAGE.tx_desc + 28], 0   ; no flags
    mov     word [r13 + VIRTIO_NET_STORAGE.tx_desc + 30], 0   ; next=0

    ; Post to avail ring
    lea     rdi, [r13 + VIRTIO_NET_STORAGE.tx_avail]
    movzx   esi, word [r12 + VIRTIO_NET_DEVICE.queue_size]
    xor     edx, edx               ; desc_id = 0
    call    er_virtio_post_descriptor

    ; Notify device
    lea     rdi, [r12 + VIRTIO_NET_DEVICE.transport]
    mov     esi, VIRTIO_NET_TX_QUEUE
    call    er_virtio_notify_queue

    ; Wait for completion
    lea     rdi, [r13 + VIRTIO_NET_STORAGE.tx_used]
    movzx   esi, word [r12 + VIRTIO_NET_DEVICE.queue_size]
    lea     rdx, [r12 + VIRTIO_NET_DEVICE.last_used_idx_tx]

.wait:
    call    er_virtio_next_used
    test    eax, eax
    jnz     .done
    pause
    jmp     .wait

.done:
    xor     eax, eax
    er_ok
    jmp     .out

.err_invalid:
    mov     eax, ERROR_INVALID_PARAM
    er_err  ERROR_INVALID_PARAM

.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    ret

; ==================================================================
; er_virtio_net_receive — receive a packet (non-blocking)
; int er_virtio_net_receive(VIRTIO_NET_DEVICE* dev,
;                           VIRTIO_NET_STORAGE* storage,
;                           void* buf, uint32_t* len)
;
; Returns: eax = 1 if packet received (*len set), 0 if none.
; ==================================================================
er_fn er_virtio_net_receive
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage
    mov     r14, rdx            ; buf
    mov     r15, rcx            ; len_out

    test    r14, r14
    jz      .err_invalid
    test    r15, r15
    jz      .err_invalid

    ; Check used ring for completed RX
    lea     rdi, [r13 + VIRTIO_NET_STORAGE.rx_used]
    movzx   esi, word [r12 + VIRTIO_NET_DEVICE.queue_size]
    lea     rdx, [r12 + VIRTIO_NET_DEVICE.last_used_idx_rx]
    call    er_virtio_next_used
    test    eax, eax
    jz      .none

    ; rcx = descriptor id, r8d = length (bytes written by device)
    ; Copy packet data from rx_buf + hdr_size to caller buffer
    ; rx_buf layout: [0-11] = virtio_net_hdr (12 bytes), [12+] = packet
    push    r8                  ; save total length
    mov     r8d, r8d
    sub     r8d, VIRTIO_NET_HDR_SIZE    ; subtract header to get payload
    jbe     .skip_copy          ; nothing to copy

    mov     [r15], r8d          ; *len = payload size

    lea     rsi, [r13 + VIRTIO_NET_STORAGE.rx_buf + VIRTIO_NET_HDR_SIZE]
    mov     rdi, r14
    mov     ecx, r8d
    rep     movsb

.skip_copy:
    pop     r8
    ; fall through

    ; Re-post the RX buffer for next packet
    mov     rdi, r13
    call    _virtio_net_post_rx_buf

    mov     eax, 1
    er_ok
    jmp     .out

.none:
    xor     eax, eax
    er_ok
    jmp     .out

.err_invalid:
    mov     eax, ERROR_INVALID_PARAM
    er_err  ERROR_INVALID_PARAM

.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_frame_pop
    ret
