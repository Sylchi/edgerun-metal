; EdgeRun IPv4 receive dispatch self-hosted test.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"
%include "test/test_macros.inc"

extern er_ip_set_config
extern er_ip_handle
extern er_checksum

LOCAL_IP        equ 0x0a01a8c0
LOCAL_NETMASK   equ 0x00ffffff
LOCAL_GATEWAY   equ 0x0101a8c0
REMOTE_IP       equ 0x1401a8c0
UNKNOWN_PROTO   equ 1

TEST_BSS_PASSED_FAILED

SECTION .bss
tcp_handle_count: resd 1
tcp_handle_len:   resd 1
tcp_handle_header: resq 1
ipv4_frame:       resb ETHER_HDR_LEN + IP_HDR_LEN

SECTION .data
local_mac:
    db 0x02, 0x45, 0x64, 0x67, 0x65, 0x01

SECTION .text
global _start

_start:
    mov     edi, LOCAL_IP
    mov     esi, LOCAL_NETMASK
    mov     edx, LOCAL_GATEWAY
    lea     rcx, [rel local_mac]
    call    er_ip_set_config

    call    prepare_tcp_frame
    lea     rdi, [rel ipv4_frame]
    mov     esi, ETHER_HDR_LEN + IP_HDR_LEN
    call    er_ip_handle
    ASSERT_EQ eax, 0
    ASSERT_RDX ERROR_OK
    ASSERT_DWORD [rel tcp_handle_count], 1
    ASSERT_DWORD [rel tcp_handle_len], IP_HDR_LEN

    call    prepare_udp_frame
    lea     rdi, [rel ipv4_frame]
    mov     esi, ETHER_HDR_LEN + IP_HDR_LEN
    call    er_ip_handle
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_UNSUPPORTED
    ASSERT_DWORD [rel tcp_handle_count], 1

    call    prepare_unknown_frame
    lea     rdi, [rel ipv4_frame]
    mov     esi, ETHER_HDR_LEN + IP_HDR_LEN
    call    er_ip_handle
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_UNSUPPORTED
    ASSERT_DWORD [rel tcp_handle_count], 1

    TEST_EXIT_FAILED

prepare_tcp_frame:
    mov     al, IP_PROTO_TCP
    jmp     prepare_frame

prepare_udp_frame:
    mov     al, IP_PROTO_UDP
    jmp     prepare_frame

prepare_unknown_frame:
    mov     al, UNKNOWN_PROTO

prepare_frame:
    push    rax
    push    rbx
    lea     rbx, [rel ipv4_frame]

    ; Ethernet header is ignored by er_ip_handle after net demux.
    xor     eax, eax
    mov     ecx, ETHER_HDR_LEN + IP_HDR_LEN
    mov     rdi, rbx
    rep     stosb

    lea     rbx, [rel ipv4_frame + ETHER_HDR_LEN]
    mov     byte [rbx + IP_VER_IHL], 0x45
    mov     byte [rbx + IP_DSCP_ECN], 0
    mov     byte [rbx + IP_TOTAL_LEN], 0
    mov     byte [rbx + IP_TOTAL_LEN + 1], IP_HDR_LEN
    mov     word [rbx + IP_ID], 0
    mov     word [rbx + IP_FLAGS_FRAG], 0
    mov     byte [rbx + IP_TTL], 64
    mov     al, byte [rsp + 8]
    mov     byte [rbx + IP_PROTOCOL], al
    mov     word [rbx + IP_CHECKSUM], 0
    mov     dword [rbx + IP_SRC], REMOTE_IP
    mov     dword [rbx + IP_DST], LOCAL_IP

    mov     rdi, rbx
    mov     esi, IP_HDR_LEN
    call    er_checksum
    xchg    ah, al
    mov     word [rbx + IP_CHECKSUM], ax

    pop     rbx
    pop     rax
    ret

global er_tcp_handle
er_tcp_handle:
    inc     dword [rel tcp_handle_count]
    mov     dword [rel tcp_handle_len], esi
    mov     qword [rel tcp_handle_header], rdi
    xor     eax, eax
    er_ok
    ret

global er_net_transmit
er_net_transmit:
    xor     eax, eax
    er_ok
    ret

global er_arp_resolve
er_arp_resolve:
    xor     eax, eax
    er_ok
    ret

global er_memcpy
er_memcpy:
    ret

global er_memset
er_memset:
    ret
