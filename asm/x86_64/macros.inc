; x86_64 assembly macros for EdgeRun assembly porting
; NASM/yasm syntax — our own assembler is the long-term goal
;
; Usage:
;   %include "x86_64/macros.inc"

[BITS 64]

; ------------------------------------------------------------------
; Register aliases — System V AMD64 ABI
; ------------------------------------------------------------------
; Argument registers (integer)
%define arg1    rdi
%define arg2    rsi
%define arg3    rdx
%define arg4    rcx
%define arg5    r8
%define arg6    r9

; Return register
%define retval  rax

; Callee-saved GPRs (must preserve)
%define saved1  rbx
%define saved2  rbp
%define saved3  r12
%define saved4  r13
%define saved5  r14
%define saved6  r15

; ------------------------------------------------------------------
; Useful IEEE 754 single-precision constants (as bit patterns)
; ------------------------------------------------------------------
%define FLOAT_SIGN_BIT    0x80000000
%define FLOAT_ABS_MASK    0x7fffffff
%define FLOAT_NAN         0x7fc00000
%define FLOAT_POS_INF     0x7f800000
%define FLOAT_NEG_INF     0xff800000
%define FLOAT_ONE         0x3f800000
%define FLOAT_HALF        0x3f000000
%define FLOAT_TWO         0x40000000
%define FLOAT_ZERO        0x00000000

; Double-precision constants
%define DOUBLE_SIGN_BIT   0x8000000000000000
%define DOUBLE_ABS_MASK   0x7fffffffffffffff

; Integer sizes
%define WORD_SIZE     8
%define DWORD_SIZE    4
%define CACHE_LINE    64
%define PAGE_SIZE     4096

; ------------------------------------------------------------------
; Function prologue / epilogue
; ------------------------------------------------------------------
; Begin a function with standard cfi + 16-byte alignment
%macro er_fn 1
    SECTION .text
    align 16
    global %1
    %1:
%endm

; Return from function
%macro er_ret 0
    ret
%endm

; ------------------------------------------------------------------
; Stack frame macros
; ------------------------------------------------------------------
; Push frame pointer, set up new frame
%macro er_frame_push 0
    push    rbp
    mov     rbp, rsp
%endm

; Pop frame pointer
%macro er_frame_pop 0
    pop     rbp
%endm

; Push all callee-saved GPRs
%macro er_push_all 0
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
%endm

; Pop all callee-saved GPRs
%macro er_pop_all 0
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
%endm

; Allocate N bytes on the stack (N must be multiple of 16)
%macro er_stack_alloc 1
    sub     rsp, %1
%endm

; Deallocate N bytes from the stack
%macro er_stack_free 1
    add     rsp, %1
%endm

; Align RSP to 16 bytes
%macro er_align_stack 0
    and     rsp, -16
%endm

; ------------------------------------------------------------------
; Conditional move helpers
; ------------------------------------------------------------------
%macro er_cmoveq 2
    cmove   %1, %2
%endm

%macro er_cmovne 2
    cmovne  %1, %2
%endm

%macro er_cmovl 2
    cmovl   %1, %2
%endm

%macro er_cmovg 2
    cmovg   %1, %2
%endm

%macro er_cmovle 2
    cmovle  %1, %2
%endm

%macro er_cmovge 2
    cmovge  %1, %2
%endm

; ------------------------------------------------------------------
; Branch helpers
; ------------------------------------------------------------------
; Unconditional trap
%macro er_trap 0
    ud2
%endm

; Assert register is in [min, max] — traps if out of range
%macro er_assert_range 3
    cmp     %1, %2
    jl      %%trap
    cmp     %1, %3
    jg      %%trap
    jmp     %%ok
%%trap:
    ud2
%%ok:
%endm

; Assert zero flag set (argument must be zero)
%macro er_assert_zero 1
    test    %1, %1
    jnz     %%trap
    jmp     %%ok
%%trap:
    ud2
%%ok:
%endm

; ------------------------------------------------------------------
; Memory helpers (clobber rax, rcx, rdi, rsi)
; ------------------------------------------------------------------
; Zero N bytes at [PTR]
%macro er_zero_mem 2
    cld
    mov     rdi, %1
    mov     rcx, %2
    xor     eax, eax
    rep     stosb
%endm

; Copy N bytes from [SRC] to [DST]
%macro er_copy_mem 3
    cld
    mov     rsi, %1  ; src
    mov     rdi, %2  ; dst
    mov     rcx, %3  ; count
    rep     movsb
%endm

; Compare N bytes of [A] vs [B]; sets ZF if equal
%macro er_cmp_mem 3
    cld
    mov     rsi, %1
    mov     rdi, %2
    mov     rcx, %3
    repe    cmpsb
%endm

; ------------------------------------------------------------------
; Debug helpers (use only in hosted/test builds)
; ------------------------------------------------------------------
; Breakpoint (int3)
%macro er_break 0
    int3
%endm

; ------------------------------------------------------------------
; Section switching helpers
; ------------------------------------------------------------------
%macro er_section_text 0
    SECTION .text
%endm

%macro er_section_data 0
    SECTION .data
%endm

%macro er_section_rodata 0
    SECTION .rodata
%endm

; ------------------------------------------------------------------
; Read/write x86 control registers
; ------------------------------------------------------------------
%macro er_read_cr0 1
    mov     %1, cr0
%endm

%macro er_read_cr2 1
    mov     %1, cr2
%endm

%macro er_read_cr3 1
    mov     %1, cr3
%endm

%macro er_read_cr4 1
    mov     %1, cr4
%endm

%macro er_write_cr0 1
    mov     cr0, %1
%endm

%macro er_write_cr3 1
    mov     cr3, %1
%endm
