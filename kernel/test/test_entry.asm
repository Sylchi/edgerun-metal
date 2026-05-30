; EdgeRun freestanding test entry point
; _start -> main() -> exit(return_code)
; No libc, no I/O.

extern main

global _start
section .text
_start:
    xor     edi, edi
    xor     esi, esi
    call    main
    mov     edi, eax
    mov     eax, 60
    syscall
