; Deterministic platform hooks for TCP self-tests.

%include "x86_64/macros.inc"
%include "x86_64/net/net_constants.inc"

SECTION .bss
global tcp_stub_last_dst_ip
global tcp_stub_last_proto
global tcp_stub_last_len
global tcp_stub_last_packet
global tcp_stub_send_count
tcp_stub_last_dst_ip: resd 1
tcp_stub_last_proto:  resd 1
tcp_stub_last_len:    resd 1
tcp_stub_send_count:  resd 1
tcp_stub_last_packet: resb 1500

SECTION .text

global er_ip_send
er_ip_send:
    mov     [rel tcp_stub_last_dst_ip], edi
    mov     [rel tcp_stub_last_proto], esi
    mov     [rel tcp_stub_last_len], ecx
    inc     dword [rel tcp_stub_send_count]
    push    rdi
    push    rsi
    push    rdx
    push    rcx
    lea     rdi, [rel tcp_stub_last_packet]
    mov     rsi, rdx
    mov     edx, ecx
    call    er_memcpy
    pop     rcx
    pop     rdx
    pop     rsi
    pop     rdi
    xor     eax, eax
    er_ok
    ret

global er_net_get_ip
er_net_get_ip:
    mov     eax, 0x0100000a
    er_ok
    ret

global er_memcpy
er_memcpy:
    push    rcx
    push    rsi
    push    rdi
    mov     rcx, rdx
    rep     movsb
    pop     rdi
    pop     rsi
    pop     rcx
    xor     eax, eax
    er_ok
    ret

global er_memset
er_memset:
    push    rcx
    push    rdi
    mov     eax, esi
    mov     rcx, rdx
    rep     stosb
    pop     rdi
    pop     rcx
    xor     eax, eax
    er_ok
    ret

global er_tpm_get_random
er_tpm_get_random:
    mov     eax, 12
    er_ok
    ret

global er_tpm_crb_transfer
er_tpm_crb_transfer:
    mov     eax, 12
    er_ok
    ret

global er_tpm_parse_get_random
er_tpm_parse_get_random:
    mov     dword [rdx], 0x01020304
    mov     eax, 4
    er_ok
    ret

global er_serial_putchar
er_serial_putchar:
    xor     eax, eax
    er_ok
    ret

global er_serial_puthex32
er_serial_puthex32:
    xor     eax, eax
    er_ok
    ret
