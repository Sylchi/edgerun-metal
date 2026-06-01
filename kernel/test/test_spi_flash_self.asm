; EdgeRun SPI flash self-hosted test runner — x86_64 assembly
; Verifies that spi_flash.asm assembles and links correctly.
; Does NOT probe hardware (MMIO not accessible from user-space).
; Tests pass if the module links without error.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

SECTION .data
pass_msg: db "PASS spi_flash (compile check only)", 10, 0

SECTION .text
global _start
_start:
    mov     rdi, 1
    mov     rsi, pass_msg
    mov     rdx, 37
%ifndef TEST_FLAT_KERNEL
    mov     rax, 1
    syscall
%endif
    TEST_EXIT 0
