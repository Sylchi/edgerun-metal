%include "x86_64/macros.inc"

SECTION .rodata
test_imports_start:
    incbin "test_imports.wasm"
test_imports_end:
global test_imports_start
global test_imports_end
global test_imports_len
test_imports_len: dq test_imports_end - test_imports_start

global test_imports_export
test_imports_export: db "f", 0
