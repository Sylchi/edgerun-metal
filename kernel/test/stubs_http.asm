; Stubs for HTTP client test — provides extern symbols that http.asm
; references but the parsing tests don't actually call.

SYS_EXIT equ 60
UNEXPECTED_HTTP_STUB_EXIT equ 86

SECTION .text

global er_tcp_connect
er_tcp_connect:
    jmp     unexpected_http_stub_call

global er_tcp_get_state
er_tcp_get_state:
    jmp     unexpected_http_stub_call

global er_tcp_send
er_tcp_send:
    jmp     unexpected_http_stub_call

global er_tcp_recv
er_tcp_recv:
    jmp     unexpected_http_stub_call

global er_tcp_close
er_tcp_close:
    jmp     unexpected_http_stub_call

global er_net_poll
er_net_poll:
    jmp     unexpected_http_stub_call

global er_tcp_poll
er_tcp_poll:
    jmp     unexpected_http_stub_call

global er_memcpy
er_memcpy:
    jmp     unexpected_http_stub_call

global er_memset
er_memset:
    jmp     unexpected_http_stub_call

global er_strlen
er_strlen:
    jmp     unexpected_http_stub_call

unexpected_http_stub_call:
%ifdef TEST_FLAT_KERNEL
    mov     dx, 0xf4
    mov     eax, UNEXPECTED_HTTP_STUB_EXIT
    out     dx, eax
.halt:
    cli
    hlt
    jmp     .halt
%else
    mov     edi, UNEXPECTED_HTTP_STUB_EXIT
    mov     eax, SYS_EXIT
    syscall
%endif
