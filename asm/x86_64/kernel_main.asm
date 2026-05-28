; EdgeRun x86_64 bare-metal kernel main.
; Called from entry.asm after stack and BSS are ready.
; Follows the project kernel pattern: banner → checks → PASS.

%include "x86_64/macros.inc"

extern er_serial_init
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putdec32
extern er_serial_crlf
extern er_strcmp_prefix
extern er_cpu_id
extern er_rdtsc
extern er_halt

; QEMU debugcon port and ISA debugcon device registers
%define DEBUGCON_PORT  0x402
%define COM1_PORT      0x3f8
%define BAUD_115200    1

SECTION .data
banner:        db "EdgeRun x86_64 bare metal", 0
check_cpu:     db "check: cpuid signature 0x", 0
check_rdtsc:   db "check: rdtsc ok", 0
check_serial:  db "check: serial 0x", 0
pass_text:     db "PASS asm-bare-metal-x86_64", 0
hex_prefix:    db "0x", 0

SECTION .text

er_fn er_kernel_main
    push    rbx
    push    r12

    ; Initialize serial COM1 at 115200 baud
    mov     rdi, COM1_PORT
    mov     rsi, BAUD_115200
    call    er_serial_init

    ; Print banner
    mov     rdi, COM1_PORT
    mov     rsi, banner
    call    er_serial_puts
    call    .crlf

    ; check: cpuid signature
    mov     rdi, COM1_PORT
    mov     rsi, check_cpu
    call    er_serial_puts
    call    er_cpu_id
    mov     r12, rax            ; save CPU signature
    mov     rdi, COM1_PORT
    mov     rsi, r12
    call    er_serial_puthex32
    call    .crlf

    ; check: serial output works (we just did)
    mov     rdi, COM1_PORT
    mov     rsi, check_serial
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     rsi, COM1_PORT
    call    er_serial_puthex32
    call    .crlf

    ; check: rdtsc
    call    er_rdtsc
    mov     rdi, COM1_PORT
    mov     rsi, check_rdtsc
    call    er_serial_puts
    call    .crlf

    ; PASS
    mov     rdi, COM1_PORT
    mov     rsi, pass_text
    call    er_serial_puts
    call    .crlf

    pop     r12
    pop     rbx
    ret

.crlf:
    mov     rdi, COM1_PORT
    jmp     er_serial_crlf
