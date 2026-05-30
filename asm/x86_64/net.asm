; EdgeRun Network Module — x86_64 assembly
; NIC abstraction, network init, polling dispatch.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net_constants.inc"

extern er_rtl8125_transmit
extern er_rtl8125_receive
extern er_virtio_net_transmit
extern er_virtio_net_receive

extern er_arp_init
extern er_arp_handle
extern er_ip_set_config
extern er_ip_handle
extern er_tcp_init

extern er_memcpy
extern er_memset

SECTION .data

net_mac:     db 0, 0, 0, 0, 0, 0
net_ip:      dd 0
net_netmask: dd 0
net_gateway: dd 0
net_nic_type: db 0

net_nic_dev_ptr:  dq 0
net_nic_stor_ptr: dq 0

SECTION .bss

net_rx_buf: resb 1518
net_rx_len: resd 1

SECTION .text

; ==================================================================
; er_net_init — init networking (IP config, ARP, TCP)
; void er_net_init(uint32_t ip, uint32_t mask, uint32_t gw, mac[6])
; ==================================================================
er_fn er_net_init
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx

    mov     eax, [rcx]
    mov     [net_mac], eax
    mov     ax, [rcx + 4]
    mov     [net_mac + 4], ax

    mov     [net_ip], r12d
    mov     [net_netmask], r13d
    mov     [net_gateway], r14d

    mov     byte [net_nic_type], 0

    mov     edi, r12d
    mov     rsi, r15
    call    er_arp_init

    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     rcx, r15
    call    er_ip_set_config

    call    er_tcp_init

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_net_register_nic — register active NIC
; void er_net_register_nic(u8 type, void *dev, void *storage)
; type: 1=RTL8125, 2=virtio-net
; ==================================================================
er_fn er_net_register_nic
    mov     [net_nic_type], dil
    mov     [net_nic_dev_ptr], rsi
    mov     [net_nic_stor_ptr], rdx
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_net_transmit — transmit raw frame
; int er_net_transmit(const void *frame, uint32_t len)
; ==================================================================
er_fn er_net_transmit
    movzx   eax, byte [net_nic_type]
    cmp     al, 1
    je      .rtl
    cmp     al, 2
    je      .virtio
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret

.rtl:
    ; er_rtl8125_transmit(frame=rdi, len=esi) — args already match
    jmp     er_rtl8125_transmit

.virtio:
    ; er_virtio_net_transmit(dev, storage, frame, len)
    ; rdi=dev, rsi=storage, rdx=frame, ecx=len
    push    rdi              ; save frame
    push    rsi              ; save len

    mov     rdi, [net_nic_dev_ptr]
    mov     rsi, [net_nic_stor_ptr]
    pop     rcx              ; len (was 2nd push)
    pop     rdx              ; frame (was 1st push)

    jmp     er_virtio_net_transmit
; ==================================================================

; ==================================================================
; er_net_receive — receive raw frame
; int er_net_receive(void *buf, uint32_t *len)
; ==================================================================
er_fn er_net_receive
    movzx   eax, byte [net_nic_type]
    cmp     al, 1
    je      .rtl_recv
    cmp     al, 2
    je      .virtio_recv
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret

.rtl_recv:
    jmp     er_rtl8125_receive

.virtio_recv:
    push    rdi              ; buf
    push    rsi              ; len ptr

    mov     rdi, [net_nic_dev_ptr]
    mov     rsi, [net_nic_stor_ptr]
    pop     rcx              ; len ptr
    pop     rdx              ; buf

    jmp     er_virtio_net_receive
; ==================================================================

; ==================================================================
; er_net_poll — poll NIC, dispatch ARP/IP
; void er_net_poll(void)
; ==================================================================
er_fn er_net_poll
    push    rbx
    push    r12

    lea     rdi, [net_rx_buf]
    lea     rsi, [net_rx_len]
    call    er_net_receive
    test    eax, eax
    jz      .done

    mov     rbx, net_rx_buf
    mov     r12d, [net_rx_len]

    cmp     r12d, ETHER_HDR_LEN
    jb      .done

    movzx   eax, word [rbx + ETHER_TYPE]
    cmp     ax, ETHERTYPE_ARP
    je      .arp
    cmp     ax, ETHERTYPE_IPV4
    je      .ip
    jmp     .done

.arp:
    mov     rdi, rbx
    mov     esi, r12d
    call    er_arp_handle
    jmp     .done

.ip:
    mov     rdi, rbx
    mov     esi, r12d
    call    er_ip_handle

.done:
    pop     r12
    pop     rbx
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_net_get_mac — get active NIC MAC
; void er_net_get_mac(uint8_t mac[6])
; ==================================================================
er_fn er_net_get_mac
    mov     eax, [net_mac]
    mov     [rdi], eax
    mov     ax, [net_mac + 4]
    mov     [rdi + 4], ax
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_net_get_ip — get local IP (network byte order)
; uint32_t er_net_get_ip(void)
; ==================================================================
er_fn er_net_get_ip
    mov     eax, [net_ip]
    er_ok
    er_ret
; ==================================================================
