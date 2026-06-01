; Minimal runtime support for flat bare-metal unit tests.

%include "x86_64/macros.inc"

SECTION .text

er_fn er_bss_zero
    mov     rcx, rsi
    sub     rcx, rdi
    jle     .done
    xor     eax, eax
    cld
    shr     rcx, 3
    rep     stosq
.done:
    ret
