%include "x86_64/macros.inc"

SECTION .rodata
da_wasm_test_start:
    incbin "da_test.wasm"
da_wasm_test_end:
global da_wasm_test_start
global da_wasm_test_end
global da_wasm_test_len
da_wasm_test_len: dq da_wasm_test_end - da_wasm_test_start

global da_wasm_test_export_name
da_wasm_test_export_name: db "f", 0
