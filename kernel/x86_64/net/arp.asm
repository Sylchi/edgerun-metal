; EdgeRun ARP module — x86_64 assembly
; ARP cache, request/reply handling, Ethernet frame dispatch.
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"

extern er_net_transmit
extern er_memcpy
extern er_memset
extern er_ticks

SECTION .data

arp_local_ip:   dd 0
arp_local_mac:  db 0, 0, 0, 0, 0, 0

SECTION .bss

; ARP cache: ARP_CACHE_SIZE entries of ARP_ENTRY_SIZE bytes
arp_cache:      resb ARP_CACHE_SIZE * ARP_ENTRY_SIZE

; Pending ARP resolution tracking
arp_pending_ip: resd 1      ; IP we're waiting for, or 0 if none
arp_pending_tick: resd 1    ; tick when request was sent
arp_pending_retries: resb 1 ; retry count

SECTION .text

; ==================================================================
; er_arp_init — set local IP and MAC for ARP module
; void er_arp_init(uint32_t local_ip, const uint8_t mac[6])
; ==================================================================
er_fn er_arp_init
    mov     [arp_local_ip], edi
    mov     eax, [rsi]
    mov     [arp_local_mac], eax
    mov     ax, [rsi + 4]
    mov     [arp_local_mac + 4], ax
    ; Clear ARP cache
    mov     edi, arp_cache
    xor     esi, esi            ; value = 0
    mov     edx, ARP_CACHE_SIZE * ARP_ENTRY_SIZE
    call    er_memset
    ; Clear pending state
    mov     dword [arp_pending_ip], 0
    mov     byte [arp_pending_retries], 0
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; er_arp_resolve — look up or request MAC for IP
; int er_arp_resolve(uint32_t ip, uint8_t mac_out[6])
;
; Returns:
;   eax = 1  — found in cache, mac_out populated
;   eax = 0  — resolution pending (send ARP request)
;   eax = -1 — error
;   rdx = error code on error
; ==================================================================
er_fn er_arp_resolve
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi       ; ip
    mov     r13, rsi        ; mac_out

    ; Search cache for matching IP
    xor     ecx, ecx        ; index
.search_loop:
    cmp     ecx, ARP_CACHE_SIZE
    jae     .not_found

    mov     eax, ecx
    imul    eax, ARP_ENTRY_SIZE
    mov     ebx, eax

    ; Check valid flag
    cmp     byte [arp_cache + ebx + ARP_ENTRY_VALID], 0
    je      .next

    ; Compare IP
    mov     eax, [arp_cache + ebx + ARP_ENTRY_IP]
    cmp     eax, r12d
    jne     .next

    ; Found! Copy MAC to output
    mov     eax, [arp_cache + ebx + ARP_ENTRY_MAC]
    mov     [r13], eax
    mov     ax, [arp_cache + ebx + ARP_ENTRY_MAC + 4]
    mov     [r13 + 4], ax

    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.next:
    inc     ecx
    jmp     .search_loop

.not_found:
    ; Check if resolution already pending for this IP
    cmp     dword [arp_pending_ip], 0
    jne     .already_pending

    ; Check retry limit
    cmp     byte [arp_pending_retries], 3
    jae     .timeout

    ; Send ARP request
    mov     edi, r12d       ; target IP
    call    _arp_send_request
    test    eax, eax
    js      .send_fail

    ; Mark pending
    mov     [arp_pending_ip], r12d
    mov     dword [arp_pending_tick], 0  ; will set on next poll
    inc     byte [arp_pending_retries]

.already_pending:
    ; Resolution in progress — caller must poll
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.timeout:
    mov     eax, -1
    er_err  ERROR_NET_UNREACHABLE
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.send_fail:
    mov     eax, -1
    er_err  ERROR_IO
    pop     r13
    pop     r12
    pop     rbx
    er_ret
; ==================================================================

; ==================================================================
; er_arp_handle — process incoming ARP packet
; void er_arp_handle(const uint8_t *frame, uint32_t len)
; ==================================================================
er_fn er_arp_handle
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi        ; frame (Ethernet header start)
    mov     r13d, esi       ; frame length

    ; Validate minimum length (Ethernet + ARP)
    cmp     esi, ETHER_HDR_LEN + ARP_PKT_LEN
    jb      .done

    ; Point to ARP payload
    lea     rbx, [rdi + ETHER_HDR_LEN]

    ; Check hardware type (must be Ethernet = 1)
    cmp     word [rbx + ARP_HTYPE], 0x0100
    jne     .done

    ; Check protocol type (must be IPv4 = 0x0800)
    cmp     word [rbx + ARP_PTYPE], 0x0008
    jne     .done

    ; Check hardware/protocol lengths
    cmp     byte [rbx + ARP_HLEN], 6
    jne     .done
    cmp     byte [rbx + ARP_PLEN], 4
    jne     .done

    ; Check if target IP is ours
    mov     eax, [rbx + ARP_TPA]
    cmp     eax, [arp_local_ip]
    jne     .done

    ; We are the target — check operation
    cmp     word [rbx + ARP_OPER], ARP_OP_REQUEST
    je      .send_reply

    cmp     word [rbx + ARP_OPER], ARP_OP_REPLY
    je      .process_reply

    jmp     .done

.send_reply:
    ; Learn sender's address first (gratuitous cache update)
    call    _arp_cache_update

    ; Build and send ARP reply
    mov     edi, r12d       ; input frame
    call    _arp_build_reply
    test    eax, eax
    js      .done

    mov     rdi, rax        ; reply frame buffer
    mov     esi, ETHER_HDR_LEN + ARP_PKT_LEN
    call    er_net_transmit
    jmp     .done

.process_reply:
    ; Update cache with sender info
    call    _arp_cache_update

    ; Check if this resolves our pending request
    mov     eax, [rbx + ARP_SPA]
    cmp     eax, [arp_pending_ip]
    jne     .done

    ; Clear pending state
    mov     dword [arp_pending_ip], 0
    mov     byte [arp_pending_retries], 0

.done:
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
; ==================================================================

; ==================================================================
; _arp_send_request — send ARP request for a given IP
; int _arp_send_request(uint32_t target_ip)
;
; Uses static request buffer, returns 0 on success, -1 on error
; ==================================================================
_arp_send_request:
    push    rbx
    push    r12

    mov     r12d, edi       ; target IP

    ; Build request in static buffer
    lea     rbx, [arp_req_buf]

    ; Ethernet: destination = broadcast
    mov     dword [rbx + ETHER_DST], 0xFFFFFFFF
    mov     word [rbx + ETHER_DST + 4], 0xFFFF

    ; Ethernet: source = local MAC
    mov     eax, [arp_local_mac]
    mov     [rbx + ETHER_SRC], eax
    mov     ax, [arp_local_mac + 4]
    mov     [rbx + ETHER_SRC + 4], ax

    ; Ethernet: type = ARP
    mov     word [rbx + ETHER_TYPE], ETHERTYPE_ARP

    ; ARP header
    lea     rdi, [rbx + ETHER_HDR_LEN]

    mov     word [rdi + ARP_HTYPE], 0x0100    ; Ethernet = 1
    mov     word [rdi + ARP_PTYPE], 0x0008    ; IPv4 = 0x0800
    mov     byte [rdi + ARP_HLEN], 6
    mov     byte [rdi + ARP_PLEN], 4
    mov     word [rdi + ARP_OPER], ARP_OP_REQUEST

    ; Sender MAC = local
    mov     eax, [arp_local_mac]
    mov     [rdi + ARP_SHA], eax
    mov     ax, [arp_local_mac + 4]
    mov     [rdi + ARP_SHA + 4], ax

    ; Sender IP = local
    mov     eax, [arp_local_ip]
    mov     [rdi + ARP_SPA], eax

    ; Target MAC = zero (unknown)
    mov     dword [rdi + ARP_THA], 0
    mov     word [rdi + ARP_THA + 4], 0

    ; Target IP = requested
    mov     [rdi + ARP_TPA], r12d

    ; Transmit
    mov     rdi, rbx
    mov     esi, ETHER_HDR_LEN + ARP_PKT_LEN
    call    er_net_transmit
    test    eax, eax
    js      .fail

    xor     eax, eax
    pop     r12
    pop     rbx
    er_ok
    er_ret

.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_arp_add_static — add static ARP entry
; void er_arp_add_static(uint32_t ip, const uint8_t mac[6])
; ==================================================================
global er_arp_add_static
er_arp_add_static:
    push    rbx
    push    rcx
    push    rdx

    xor     ecx, ecx
.find_slot:
    cmp     ecx, ARP_CACHE_SIZE
    jae     .done

    mov     eax, ecx
    imul    eax, ARP_ENTRY_SIZE

    cmp     byte [arp_cache + eax + ARP_ENTRY_VALID], 0
    je      .fill

    inc     ecx
    jmp     .find_slot

.fill:
    ; Store IP
    mov     [arp_cache + eax + ARP_ENTRY_IP], edi

    ; Store MAC (6 bytes) — load as dword + word to avoid overread
    mov     edx, [rsi]
    mov     [arp_cache + eax + ARP_ENTRY_MAC], edx
    mov     dx, [rsi + 4]
    mov     [arp_cache + eax + ARP_ENTRY_MAC + 4], dx

    ; Mark valid
    mov     byte [arp_cache + eax + ARP_ENTRY_VALID], 1

.done:
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ==================================================================
; _arp_cache_update — update cache from current ARP packet sender
; Clobbers: none
; ==================================================================
_arp_cache_update:
    push    rax
    push    rcx
    push    rdi
    push    rsi

    lea     rdi, [rbx + ARP_SPA]  ; sender IP
    lea     rsi, [rbx + ARP_SHA]  ; sender MAC

    ; Check if IP already in cache
    xor     ecx, ecx
.lookup:
    cmp     ecx, ARP_CACHE_SIZE
    jae     .find_slot

    mov     eax, ecx
    imul    eax, ARP_ENTRY_SIZE

    cmp     byte [arp_cache + eax + ARP_ENTRY_VALID], 0
    je      .next_slot

    mov     r8d, [arp_cache + eax + ARP_ENTRY_IP]
    cmp     r8d, [rdi]
    je      .update_entry

.next_slot:
    inc     ecx
    jmp     .lookup

.find_slot:
    ; Not found — find first empty slot (round-robin replacement)
    xor     ecx, ecx
.find_empty:
    cmp     ecx, ARP_CACHE_SIZE
    jae     .replace_oldest

    mov     eax, ecx
    imul    eax, ARP_ENTRY_SIZE

    cmp     byte [arp_cache + eax + ARP_ENTRY_VALID], 0
    je      .update_entry

    inc     ecx
    jmp     .find_empty

.replace_oldest:
    ; Simple: replace slot 0 (could be improved with LRU)
    xor     ecx, ecx

.update_entry:
    mov     eax, ecx
    imul    eax, ARP_ENTRY_SIZE
    add     rax, arp_cache

    mov     r8d, [rdi]           ; IP
    mov     [rax + ARP_ENTRY_IP], r8d
    mov     r8d, [rsi]           ; MAC bytes 0-3
    mov     [rax + ARP_ENTRY_MAC], r8d
    mov     r8w, [rsi + 4]       ; MAC bytes 4-5
    mov     [rax + ARP_ENTRY_MAC + 4], r8w
    mov     byte [rax + ARP_ENTRY_VALID], 1

    pop     rsi
    pop     rdi
    pop     rcx
    pop     rax
    ret

; ==================================================================
; _arp_build_reply — build ARP reply in static buffer
; Changes sender/target fields for reply
; Returns rax = buffer pointer
; ==================================================================
_arp_build_reply:
    push    r12

    lea     r12, [arp_req_buf]   ; reuse request buffer

    ; Copy Ethernet header from request
    ; Already has correct destination (sender of request)

    ; Swap Ethernet addresses: dst = src of request
    mov     eax, [r12 + ETHER_SRC]
    mov     ecx, [r12 + ETHER_DST]
    mov     [r12 + ETHER_DST], eax
    mov     [r12 + ETHER_SRC], ecx

    mov     ax, [r12 + ETHER_SRC + 4]
    mov     cx, [r12 + ETHER_DST + 4]
    mov     [r12 + ETHER_DST + 4], ax
    mov     [r12 + ETHER_SRC + 4], cx

    ; Ethernet type stays ARP

    ; Now edit ARP payload
    lea     rdi, [r12 + ETHER_HDR_LEN]

    ; Change operation to REPLY
    mov     word [rdi + ARP_OPER], ARP_OP_REPLY

    ; Sender becomes us (already our MAC from request?)
    mov     eax, [arp_local_mac]
    mov     [rdi + ARP_SHA], eax
    mov     ax, [arp_local_mac + 4]
    mov     [rdi + ARP_SHA + 4], ax
    mov     eax, [arp_local_ip]
    mov     [rdi + ARP_SPA], eax

    ; Target becomes the original sender
    ; Sender info is already in the ARP request we received
    ; but we need to get it from the incoming frame
    ; (caller passed the original frame in rdi)

    ; This function is called with r12 pointing to the original frame
    ; Let's get sender info from the original
    mov     rsi, rdi            ; save target ARP pointer

    ; Get original sender info from r12 (original frame)
    lea     rdi, [r12 + ETHER_HDR_LEN]  ; original ARP

    ; Target MAC = original sender MAC
    mov     eax, [rdi + ARP_SHA]
    mov     [rsi + ARP_THA], eax
    mov     ax, [rdi + ARP_SHA + 4]
    mov     [rsi + ARP_THA + 4], ax

    ; Target IP = original sender IP
    mov     eax, [rdi + ARP_SPA]
    mov     [rsi + ARP_TPA], eax

    mov     rax, r12
    pop     r12
    ret

; ==================================================================
; Static ARP request/reply buffer
; ==================================================================
SECTION .bss

arp_req_buf: resb ETHER_HDR_LEN + ARP_PKT_LEN + 2  ; +2 for alignment
