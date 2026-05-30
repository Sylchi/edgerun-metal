; EdgeRun embedded WASM module data — x86_64 assembly
; Module bytes are linked into .rodata via incbin.
; Global symbols expose the begin/end addresses and the export name.

%include "x86_64/macros.inc"

SECTION .rodata
wasm_return42_start:
    incbin "wasm_return42.bin"
wasm_return42_end:

; For now the module exports a single function named "f".
; We'll look it up by name "f" (length 1) from the caller.
wasm_export_name:
    db "f", 0

global wasm_return42_start
global wasm_return42_end
global wasm_return42_len
global wasm_export_name

wasm_return42_len: dq wasm_return42_end - wasm_return42_start
