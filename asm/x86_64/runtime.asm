; EdgeRun freestanding memory and string runtime — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, retval=rax
; All functions are freestanding — no libc, no external dependencies.
;
; Umbrella — includes sub-modules.

%include "x86_64/macros.inc"

SECTION .text
%include "runtime_mem.asm"
%include "runtime_str.asm"
%include "runtime_conv.asm"
