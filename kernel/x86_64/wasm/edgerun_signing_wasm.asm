; Embedded Ed25519 signing WASM guest.

SECTION .rodata
global edgerun_signing_wasm_start
global edgerun_signing_wasm_end
global edgerun_signing_wasm_len
edgerun_signing_wasm_start:
    incbin "../../../.build/kernel/edgerun_signing.wasm"
edgerun_signing_wasm_end:
edgerun_signing_wasm_len: dq edgerun_signing_wasm_end - edgerun_signing_wasm_start
