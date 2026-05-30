%include "x86_64/macros.inc"
SECTION .rodata
test_mem_start: incbin "test_mem.wasm"
test_mem_end:
global test_mem_start, test_mem_end, test_mem_len
test_mem_len: dq test_mem_end - test_mem_start
global test_mem_export
test_mem_export: db "f", 0
