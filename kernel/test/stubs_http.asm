; Stubs for HTTP client test — provides extern symbols that http.asm
; references but the parsing tests don't actually call.

SECTION .text

global er_tcp_connect
er_tcp_connect:
    ret

global er_tcp_get_state
er_tcp_get_state:
    xor     eax, eax
    ret

global er_tcp_send
er_tcp_send:
    xor     eax, eax
    ret

global er_tcp_recv
er_tcp_recv:
    xor     eax, eax
    ret

global er_tcp_close
er_tcp_close:
    ret

global er_net_poll
er_net_poll:
    ret

global er_tcp_poll
er_tcp_poll:
    ret

global er_memcpy
er_memcpy:
    ret

global er_memset
er_memset:
    ret

global er_strlen
er_strlen:
    xor     eax, eax
    ret
