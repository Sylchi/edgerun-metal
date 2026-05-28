; x86_64 SIMD assembly macros for EdgeRun
; SSE / SSE2 / SSE4.1 / AVX helpers in NASM/yasm syntax
;
; %include "x86_64/simd.inc"

; ------------------------------------------------------------------
; XMM register aliases
; ------------------------------------------------------------------
; None needed — xmm0–xmm15 are the canonical names in NASM/yasm.
; These comments serve as a reminder of the calling convention:
;   arg1..arg8 (float) = xmm0..xmm7
;   retval (float)     = xmm0
;   scratch            = xmm0..xmm15
;   callee-saved       = none (XMM regs are scratch in SysV AMD64)

; ------------------------------------------------------------------
; SSE scalar single-precision helpers
; ------------------------------------------------------------------
; Load 32-bit float from [PTR] into xmm0
%macro er_movss_load 1
    movss   xmm0, [%1]
%endm

; Store 32-bit float from xmm0 to [PTR]
%macro er_movss_store 1
    movss   [%1], xmm0
%endm

; Move 32-bit float from xmmSRC to xmmDST (upper 96 bits zeroed)
%macro er_movss 2
    movss   %1, %2
%endm

; ------------------------------------------------------------------
; SSE packed single-precision helpers
; ------------------------------------------------------------------
; Load 4 floats from [PTR] into xmmDST
%macro er_movaps_load 2
    movaps  %1, [%2]
%endm

; Store 4 floats from xmmSRC to [PTR]
%macro er_movaps_store 2
    movaps  [%2], %1
%endm

; Load 4 floats (may be unaligned)
%macro er_movups_load 2
    movups  %1, [%2]
%endm

; Store 4 floats (may be unaligned)
%macro er_movups_store 2
    movups  [%2], %1
%endm

; Broadcast 32-bit from xmmSRC (low) to all lanes of xmmDST
%macro er_shuf_broadcast 2
    shufps  %1, %1, 0x00
%endm

; ------------------------------------------------------------------
; SSE2 packed double-precision helpers
; ------------------------------------------------------------------
; Load 2 doubles from [PTR]
%macro er_movapd_load 2
    movapd  %1, [%2]
%endm

; Store 2 doubles to [PTR]
%macro er_movapd_store 2
    movapd  [%2], %1
%endm

; Load 2 doubles (may be unaligned)
%macro er_movupd_load 2
    movupd  %1, [%2]
%endm

; ------------------------------------------------------------------
; SSE constant generation (via memory loads from .rodata)
; ------------------------------------------------------------------
; Load a single-precision float constant from memory
%macro er_load_float 2
    comiss  xmm0, xmm0      ; (no-op for alignment, then load)
    movss   %1, [%2]
%endm

; Load a 128-bit bitmask into xmm register from .rodata
%macro er_load_mask 2
    movaps  %1, [%2]
%endm

; ------------------------------------------------------------------
; SSE arithmetic — scalar single-precision
; ------------------------------------------------------------------
%macro er_addss 2
    addss   %1, %2
%endm

%macro er_subss 2
    subss   %1, %2
%endm

%macro er_mulss 2
    mulss   %1, %2
%endm

%macro er_divss 2
    divss   %1, %2
%endm

%macro er_sqrtss 2
    sqrtss  %1, %2
%endm

%macro er_rsqrtss 2
    rsqrtss %1, %2
%endm

; ------------------------------------------------------------------
; SSE arithmetic — packed single-precision
; ------------------------------------------------------------------
%macro er_addps 2
    addps   %1, %2
%endm

%macro er_subps 2
    subps   %1, %2
%endm

%macro er_mulps 2
    mulps   %1, %2
%endm

%macro er_divps 2
    divps   %1, %2
%endm

%macro er_sqrtps 2
    sqrtps  %1, %2
%endm

%macro er_rsqrtps 2
    rsqrtps %1, %2
%endm

; ------------------------------------------------------------------
; SSE bitwise
; ------------------------------------------------------------------
%macro er_andps 2
    andps   %1, %2
%endm

%macro er_andnps 2
    andnps  %1, %2
%endm

%macro er_orps 2
    orps    %1, %2
%endm

%macro er_xorps 2
    xorps   %1, %2
%endm

; ------------------------------------------------------------------
; SSE comparison — scalar single-precision
; ------------------------------------------------------------------
; Compare xmm0 < xmm1, result in xmm0 (all ones if true, all zeros if false)
%macro er_cmpltss 3
    cmpltss %1, %2, %3
%endm

%macro er_cmpless 3
    cmpless %1, %2, %3
%endm

%macro er_cmpnless 3
    cmpnless %1, %2, %3
%endm

%macro er_cmpordss 3
    cmpordss %1, %2, %3
%endm

%macro er_cmpunordss 3
    cmpunordss %1, %2, %3
%endm

; ------------------------------------------------------------------
; SSE min/max — scalar single-precision
; ------------------------------------------------------------------
%macro er_minss 2
    minss   %1, %2
%endm

%macro er_maxss 2
    maxss   %1, %2
%endm

; ------------------------------------------------------------------
; SSE conversion
; ------------------------------------------------------------------
; Convert 32-bit integer (from GPR) to float in xmmDST
%macro er_cvtsi2ss 2
    cvtsi2ss %1, %2
%endm

; Convert float to 32-bit integer (truncate toward zero)
%macro er_cvttss2si 2
    cvttss2si %1, %2
%endm

; Convert float to 32-bit integer (round to nearest)
%macro er_cvtss2si 2
    cvtss2si %1, %2
%endm

; ------------------------------------------------------------------
; SSE2 double-precision arithmetic — scalar
; ------------------------------------------------------------------
%macro er_addsd 2
    addsd   %1, %2
%endm

%macro er_subsd 2
    subsd   %1, %2
%endm

%macro er_mulsd 2
    mulsd   %1, %2
%endm

%macro er_divsd 2
    divsd   %1, %2
%endm

%macro er_sqrtsd 2
    sqrtsd  %1, %2
%endm

%macro er_minsd 2
    minsd   %1, %2
%endm

%macro er_maxsd 2
    maxsd   %1, %2
%endm

; ------------------------------------------------------------------
; SSE4.1 helpers
; ------------------------------------------------------------------
; Round float to nearest integer (0 = nearest, 1 = floor, 2 = ceil, 3 = trunc)
%macro er_roundss 3
    roundss %1, %2, %3
%endm

; ------------------------------------------------------------------
; AVX 256-bit helpers (only when VEX encoding is desired)
; ------------------------------------------------------------------
%macro er_vaddps 3
    vaddps  %1, %2, %3
%endm

%macro er_vmulps 3
    vmulps  %1, %2, %3
%endm

%macro er_vfmadd231ps 3
    vfmadd231ps %1, %2, %3
%endm

; ------------------------------------------------------------------
; Prefetch
; ------------------------------------------------------------------
%macro er_prefetch_nta 1
    prefetchnta [%1]
%endm

%macro er_prefetch_t0 1
    prefetcht0 [%1]
%endm

%macro er_prefetch_t1 1
    prefetcht1 [%1]
%endm

%macro er_prefetch_t2 1
    prefetcht2 [%1]
%endm

; ------------------------------------------------------------------
; SSE control word helpers
; ------------------------------------------------------------------
; Set MXCSR rounding mode: 0 = nearest, 1 = floor, 2 = ceil, 3 = trunc
%macro er_set_rounding 1
    push    rax
    stmxcsr [rsp - 4]
    mov     eax, [rsp - 4]
    and     eax, ~0x6000          ; Clear rounding control bits (13:14)
    shl     %1, 13
    or      eax, %1
    mov     [rsp - 4], eax
    ldmxcsr [rsp - 4]
    pop     rax
%endm

; Restore MXCSR to default (round to nearest)
%macro er_reset_rounding 0
    push    rax
    push    rcx
    stmxcsr [rsp - 4]
    mov     eax, [rsp - 4]
    and     eax, ~0x6000
    mov     [rsp - 4], eax
    ldmxcsr [rsp - 4]
    pop     rcx
    pop     rax
%endm
