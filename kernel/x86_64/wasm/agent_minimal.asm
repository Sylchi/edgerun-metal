%include "x86_64/macros.inc"

SECTION .rodata
agent_minimal_start:
    incbin "agent_minimal.wasm"
agent_minimal_end:
global agent_minimal_start
global agent_minimal_end
global agent_minimal_len
agent_minimal_len: dq agent_minimal_end - agent_minimal_start

global agent_minimal_export_name
agent_minimal_export_name: db "f", 0
