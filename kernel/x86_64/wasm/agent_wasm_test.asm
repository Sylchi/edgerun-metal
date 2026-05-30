%include "x86_64/macros.inc"

SECTION .rodata
agent_wasm_test_start:
    incbin "agent_wasm_test.wasm"
agent_wasm_test_end:
global agent_wasm_test_start
global agent_wasm_test_end
global agent_wasm_test_len
agent_wasm_test_len: dq agent_wasm_test_end - agent_wasm_test_start

global agent_wasm_test_export_name
agent_wasm_test_export_name: db "f", 0
