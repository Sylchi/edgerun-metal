; EdgeRun x86 port I/O primitives — x86_64 assembly
; Provides low-level in/out operations as callable functions.
; A test build can link its own versions that buffer I/O instead.

SECTION .text

global er_in_al_dx
er_in_al_dx:
    in      al, dx
    ret

global er_out_dx_al
er_out_dx_al:
    out     dx, al
    ret
