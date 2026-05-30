; EdgeRun freestanding WASM interpreter — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, arg5=r8, arg6=r9, retval=rax
; Port of edgerun-zig/src/wasm/root.zig
; No libc, no external dependencies.
;
; This file is the umbrella that includes all sub-modules:
;   wasm_constants.inc — %defines, BSS, and data sections
;   wasm_decode.asm    — LEB128 readers, module parsing, section parsers
;   wasm_exec.asm      — execution engine, opcode dispatch, stack ops
;   wasm_run.asm       — top-level entry point (er_fn_run) and init

%include "x86_64/macros.inc"
default rel

%include "wasm_constants.inc"

SECTION .text
%include "wasm_decode.asm"
%include "wasm_exec.asm"
%include "wasm_run.asm"
