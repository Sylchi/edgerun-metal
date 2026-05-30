; EdgeRun freestanding math functions — x86_64 assembly
; Faithful port of edgerun-zig/src/math.zig reference implementations
; System V AMD64 ABI: float args in xmm0..xmm7, return in xmm0
;
; Umbrella — includes sub-modules.

%include "x86_64/macros.inc"

SECTION .text
%include "math_float.asm"
%include "math_int.asm"
%include "math_bit.asm"
%include "math_hash.asm"
