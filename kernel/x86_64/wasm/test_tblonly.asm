%include "x86_64/macros.inc"
SECTION .rodata
test_tblonly_start: incbin "test_tblonly.wasm"
test_tblonly_end:
global test_tblonly_start, test_tblonly_end, test_tblonly_len
test_tblonly_len: dq test_tblonly_end - test_tblonly_start
global test_tblonly_export
test_tblonly_export: db "f", 0
