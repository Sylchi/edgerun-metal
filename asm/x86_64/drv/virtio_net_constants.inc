; EdgeRun Virtio-net protocol constants
; Included by virtio_net.asm and consumers.

%define VIRTIO_DEVICE_NET           0x1000
%define VIRTIO_DEVICE_TYPE_NET      1

; Feature bits
%define VIRTIO_NET_F_MAC           (1 << 5)
%define VIRTIO_NET_F_STATUS        (1 << 16)

%define VIRTIO_NET_SUPPORTED      VIRTIO_NET_F_MAC | VIRTIO_NET_F_STATUS

; Queue identifiers
%define VIRTIO_NET_RX_QUEUE        0
%define VIRTIO_NET_TX_QUEUE        1

; Virtio-net header size (modern, no mrg_rxbuf)
%define VIRTIO_NET_HDR_SIZE        12

; Device config offsets
%define VIRTIO_NET_CFG_MAC         0
%define VIRTIO_NET_CFG_STATUS      6
%define VIRTIO_NET_CFG_MAX_VQPAIRS 8
%define VIRTIO_NET_CFG_MTU         10

; Link status bits
%define VIRTIO_NET_S_LINK_UP       0x01

; Buffer sizes
%define VIRTIO_NET_MTU             1500
%define VIRTIO_NET_BUF_SIZE        2048    ; hdr + MTU + padding

; Error codes
%define ERROR_TX_FAILED            10
%define ERROR_RX_FAILED            11

; ─── VIRTIO_NET_DEVICE state structure (64 bytes) ──────────────────
struc VIRTIO_NET_DEVICE
    .transport:         resb VIRTIO_TRANSPORT_size  ; 44
    .driver_features:   resq 1                        ; 8
    .rx_notify_off:     resw 1                        ; 2
    .tx_notify_off:     resw 1                        ; 2
    .queue_size:        resw 1                        ; 2
    .last_used_idx_rx:  resw 1                        ; 2
    .last_used_idx_tx:  resw 1                        ; 2
                        resb 2                        ; padding
    .mac:               resb 6                        ; 6
    .link_status:       resw 1                        ; 2
endstruc

; ─── VIRTIO_NET_STORAGE queue memory (2 queues) ───────────────────
struc VIRTIO_NET_STORAGE
    .rx_desc:   resb VIRTIO_QUEUE_SIZE * VIRTIO_DESC_SIZE  ; 256
    .rx_avail:  resb VIRTIO_AVAIL_SIZE                      ; 68
    .rx_used:   resb VIRTIO_USED_SIZE                       ; 72
    .tx_desc:   resb VIRTIO_QUEUE_SIZE * VIRTIO_DESC_SIZE   ; 256
    .tx_avail:  resb VIRTIO_AVAIL_SIZE                       ; 68
    .tx_used:   resb VIRTIO_USED_SIZE                        ; 72
    .rx_buf:    resb VIRTIO_NET_BUF_SIZE                    ; 2048
    .tx_hdr:    resb VIRTIO_NET_HDR_SIZE                    ; 12
    .tx_buf:    resb VIRTIO_NET_BUF_SIZE                    ; 2048
endstruc
