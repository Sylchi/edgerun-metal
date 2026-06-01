; EdgeRun owned freestanding standard runtime — x86_64 assembly
; Umbrella object for app-side bootstrap tools that still compile through Zig.

%include "x86_64/macros.inc"
%define ER_RT_STD_UNIFIED 1

SECTION .text
%include "runtime_mem.asm"
%include "runtime_str.asm"
%include "runtime_conv.asm"
%include "bytes.asm"
%include "ctype.asm"
%include "clock.asm"
%include "math_float.asm"
%include "math_int.asm"
%include "math_bit.asm"
%include "math_hash.asm"
