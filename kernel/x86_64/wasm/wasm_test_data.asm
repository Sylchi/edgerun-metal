; EdgeRun embedded WASM test module data
; All test modules consolidated here to reduce file count.

%include "x86_64/macros.inc"

SECTION .rodata

; ── return42 (no imports, no memory) ──
wasm_return42_start:
    incbin "wasm_return42.bin"
wasm_return42_end:
wasm_return42_len: dq wasm_return42_end - wasm_return42_start
global wasm_return42_start, wasm_return42_end, wasm_return42_len

; Shared export name "f" for all tests
wasm_export_name: db "f", 0
global wasm_export_name

; ── minimal43 (imports, returns 43) ──
agent_minimal_start:
    incbin "agent_minimal.wasm"
agent_minimal_end:
agent_minimal_len: dq agent_minimal_end - agent_minimal_start
global agent_minimal_start, agent_minimal_end, agent_minimal_len

agent_minimal_export_name: db "f", 0
global agent_minimal_export_name

; ── mem45 (imports, memory, returns 45) ──
test_mem_start:
    incbin "test_mem_simple.wasm"
test_mem_end:
test_mem_len: dq test_mem_end - test_mem_start
global test_mem_start, test_mem_end, test_mem_len

test_mem_export: db "f", 0
global test_mem_export

; ── tblonly47 (imports, table, memory, returns 47) ──
test_tblonly_start:
    incbin "test_tblonly.wasm"
test_tblonly_end:
test_tblonly_len: dq test_tblonly_end - test_tblonly_start
global test_tblonly_start, test_tblonly_end, test_tblonly_len

test_tblonly_export: db "f", 0
global test_tblonly_export
