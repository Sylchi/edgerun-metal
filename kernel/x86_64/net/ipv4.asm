; EdgeRun IPv4 module — x86_64 assembly
; IP header construction, checksum, send/receive demux.
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"

extern er_net_transmit
extern er_arp_resolve
extern er_tcp_handle
extern er_memcpy
extern er_memset

SECTION .data

ip_config:
    .addr    dd 0
    .netmask dd 0
    .gateway dd 0
    .mac     db 0, 0, 0, 0, 0, 0

ip_pkt_id dw 0  ; IP identification counter

SECTION .bss

; Static buffer for building outgoing IP packets
; Max size: Ethernet header (14) + IP header (20) + TCP header (20) + payload (1460) = 1514
ip_tx_buf:   resb 1514
ip_tx_len:   resd 1

; Incoming IP dispatch buffer
ip_rx_data:  resb 1514
ip_rx_len:   resd 1

SECTION .text

; ==================================================================
; er_ip_set_config — set IP configuration
; void er_ip_set_config(uint32_t addr, uint32_t netmask, uint32_t gateway, const uint8_t mac[6])
; ==================================================================
er_fn er_ip_set_config
    mov     [ip_config.addr], edi
    mov     [ip_config.netmask], esi
    mov     [ip_config.gateway], edx
    mov     eax, [rcx]
    mov     [ip_config.mac], eax
    mov     ax, [rcx + 4]
    mov     [ip_config.mac + 4], ax
    mov     word [ip_pkt_id], 0
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_checksum — compute 16-bit one's complement checksum
; uint16_t er_checksum(const void *buf, uint32_t len)
;
; Sums all 16-bit network-order words, folds carry, returns one's complement.
; ==================================================================
er_fn er_checksum
    push    rbx

    xor     eax, eax        ; accumulator
    mov     rbx, rdi        ; buffer pointer
    mov     ecx, esi        ; length

    ; Sum 16-bit words
    shr     ecx, 1          ; number of 16-bit words
    jz      .done_bytes

.sum_loop:
    movzx   edx, byte [rbx]
    shl     edx, 8
    movzx   edi, byte [rbx + 1]
    or      edx, edi
    add     ax, dx
    adc     ax, 0           ; add carry
    add     rbx, 2
    dec     ecx
    jnz     .sum_loop

.done_bytes:
    ; Handle odd byte if present
    test    esi, 1
    jz      .fold

    movzx   ecx, byte [rbx]
    shl     ecx, 8          ; odd byte goes to high byte (network order)
    add     ax, cx
    adc     ax, 0

.fold:
    ; Fold 32-bit sum to 16 bits
    mov     ecx, eax
    shr     ecx, 16
    and     eax, 0xFFFF
    add     ax, cx
    adc     ax, 0

    ; One's complement
    not     ax

    ; Return 0 if result is 0xFFFF (should be 0 for checksum field)
    cmp     ax, 0xFFFF
    jne     .done
    xor     ax, ax

.done:
    pop     rbx
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_ip_send — send an IP packet
; int er_ip_send(uint32_t dst_ip, uint8_t protocol,
;                const void *payload, uint32_t payload_len)
;
; Builds IP header + payload, resolves destination MAC via ARP,
; wraps in Ethernet frame, and transmits.
;
; Returns: eax = 0 on success, -1 on error, rdx = error code
; ==================================================================
er_fn er_ip_send
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; dst_ip
    mov     r13b, sil       ; protocol
    mov     r14, rdx        ; payload pointer
    mov     r15d, ecx       ; payload_len

    ; Validate payload length (max 1500 - 20 IP header = 1480)
    cmp     r15d, 1480
    ja      .fail_param

    ; Build IP header in ip_tx_buf (starting at Ethernet header offset)
    mov     rbx, ip_tx_buf
    add     rbx, ETHER_HDR_LEN

    ; Version/IHL = 0x45
    mov     byte [rbx + IP_VER_IHL], 0x45

    ; DSCP/ECN = 0
    mov     byte [rbx + IP_DSCP_ECN], 0

    ; Total length = header (20) + payload
    mov     eax, 20
    add     eax, r15d
    xchg    ah, al          ; to network byte order
    mov     [rbx + IP_TOTAL_LEN], ax

    ; Identification
    mov     ax, [ip_pkt_id]
    xchg    ah, al
    mov     [rbx + IP_ID], ax
    inc     word [ip_pkt_id]

    ; Flags/fragment offset = 0 (don't fragment, offset 0)
    mov     word [rbx + IP_FLAGS_FRAG], 0x4000  ; DF flag set, in network byte order = 0x0040

    ; TTL = 64
    mov     byte [rbx + IP_TTL], 64

    ; Protocol
    mov     [rbx + IP_PROTOCOL], r13b

    ; Checksum = 0 (will compute)
    mov     word [rbx + IP_CHECKSUM], 0

    ; Source IP
    mov     eax, [ip_config.addr]
    mov     [rbx + IP_SRC], eax

    ; Destination IP
    mov     [rbx + IP_DST], r12d

    ; Compute header checksum
    mov     rdi, rbx
    mov     esi, 20
    call    er_checksum
    xchg    ah, al
    mov     [rbx + IP_CHECKSUM], ax

    ; Copy payload after IP header
    cmp     r15d, 0
    je      .resolve_mac

    lea     rdi, [rbx + 20]
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy

.resolve_mac:
    ; Build Ethernet header
    ; Destination MAC — resolve via ARP
    mov     edi, r12d
    lea     rsi, [ip_tx_buf + ETHER_DST]
    call    er_arp_resolve
    cmp     eax, 0
    jl      .fail_unreachable
    je      .pending

    ; ARP resolved: source MAC
    mov     eax, [ip_config.mac]
    mov     [ip_tx_buf + ETHER_SRC], eax
    mov     ax, [ip_config.mac + 4]
    mov     [ip_tx_buf + ETHER_SRC + 4], ax

    ; EtherType = IPv4
    mov     word [ip_tx_buf + ETHER_TYPE], ETHERTYPE_IPV4

    ; Transmit
    mov     edi, ip_tx_buf
    mov     esi, ETHER_HDR_LEN
    add     esi, 20         ; IP header
    add     esi, r15d       ; payload

    ; Pad to minimum Ethernet frame size
    cmp     esi, ETHERNET_MIN
    jae     .send
    mov     esi, ETHERNET_MIN

.send:
    call    er_net_transmit

    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.pending:
    ; ARP resolution in progress — caller should retry later
    mov     eax, -1
    er_err  ERROR_ARP_PENDING
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.fail_param:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.fail_unreachable:
    mov     eax, -1
    er_err  ERROR_NET_UNREACHABLE
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
; ==================================================================

; ==================================================================
; er_ip_handle — process incoming IP packet
; int er_ip_handle(const uint8_t *frame, uint32_t frame_len)
;
; Validates IP header, checks protocol field, dispatches to TCP/UDP.
; Invalid, corrupt, or non-local frames are dropped successfully.
; Valid local packets with unsupported protocols fail explicitly.
; ==================================================================
er_fn er_ip_handle
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi        ; frame
    mov     r13d, esi       ; frame_len

    ; Must have at least Ethernet + IP header
    cmp     esi, ETHER_HDR_LEN + IP_HDR_LEN
    jb      .done

    lea     rbx, [rdi + ETHER_HDR_LEN]

    ; Verify IP version (top nibble must be 4)
    movzx   eax, byte [rbx + IP_VER_IHL]
    test    al, 0xF0
    jnz     .check_v4
    jmp     .done        ; not IPv4 if top nibble is 0
.check_v4:
    cmp     al, 0x45     ; IPv4, 5 dword header
    je      .valid_ihl
    cmp     al, 0x46
    je      .valid_ihl
    cmp     al, 0x47
    je      .valid_ihl
    cmp     al, 0x48
    je      .valid_ihl
    cmp     al, 0x49
    je      .valid_ihl
    cmp     al, 0x4A
    je      .valid_ihl
    cmp     al, 0x4B
    je      .valid_ihl
    cmp     al, 0x4C
    je      .valid_ihl
    cmp     al, 0x4D
    je      .valid_ihl
    cmp     al, 0x4E
    je      .valid_ihl
    cmp     al, 0x4F
    je      .valid_ihl
    jmp     .done        ; not a standard IPv4 header

.valid_ihl:
    ; Verify checksum
    push    rbx
    push    rsi
    mov     rdi, rbx
    mov     esi, 20          ; only checksum header (20 bytes for 5-dword IHL)
    call    er_checksum
    test    ax, ax
    pop     rsi
    pop     rbx
    jnz     .done            ; bad checksum, drop

    ; Verify destination IP is ours (or broadcast)
    mov     eax, [rbx + IP_DST]
    cmp     eax, [ip_config.addr]
    je      .for_us
    cmp     eax, 0xFFFFFFFF  ; limited broadcast
    je      .for_us
    test    eax, eax
    jz      .done            ; 0.0.0.0, drop

    ; Check if subnet broadcast
    mov     ecx, [ip_config.netmask]
    not     ecx
    or      ecx, [ip_config.addr]
    cmp     eax, ecx
    jne     .done

.for_us:
    ; Dispatch by protocol
    movzx   eax, byte [rbx + IP_PROTOCOL]
    cmp     al, IP_PROTO_TCP
    jne     .unsupported_protocol

    ; Dispatch to TCP
    mov     rdi, rbx        ; IP header start
    ; Total length in host byte order
    movzx   esi, byte [rbx + IP_TOTAL_LEN]
    shl     esi, 8
    movzx   eax, byte [rbx + IP_TOTAL_LEN + 1]
    or      esi, eax

    call    er_tcp_handle
    jmp     .done

.unsupported_protocol:
    mov     eax, -1
    er_err  ERROR_UNSUPPORTED
    jmp     .ret

.done:
    xor     eax, eax
    er_ok

.ret:
    pop     r13
    pop     r12
    pop     rbx
    er_ret
; ==================================================================

; ==================================================================
; er_ip_get_config — return pointer to IP config block
; Used by external modules to read local IP/MAC
; ==================================================================
er_fn er_ip_get_config
    lea     rax, [ip_config]
    er_ok
    er_ret
; ==================================================================
