%include "x86_64/macros.inc"
SECTION .rodata
test_table_start: incbin "test_table.wasm"
test_table_end:
global test_table_start, test_table_end, test_table_len
test_table_len: dq test_table_end - test_table_start
global test_table_export
test_table_export: db "f", 0
