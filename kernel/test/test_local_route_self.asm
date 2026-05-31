; EdgeRun local route queue/dispatch self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/local_constants.inc"
%include "x86_64/agent/agent_constants.inc"
%include "test/test_macros.inc"

extern er_local_cell_init
extern er_local_route_register
extern er_local_route_set_handler
extern er_local_cell_send
extern er_local_cell_send_to_slot
extern er_local_cell_recv
extern er_local_cell_poll

SECTION .data
sync_hash:
    db "sync-local-route-test-identity-0"
    times 32 - ($ - sync_hash) db 0
async_hash:
    db "async-local-route-test-identity"
    times 32 - ($ - async_hash) db 0

SECTION .bss
passed:             resq 1
failed:             resq 1
sync_slot:          resd 1
async_slot:         resd 1
sync_count:         resd 1
async_count:        resd 1
last_sync_sender:   resd 1
last_async_sender:  resd 1
test_cell:          resb LOCAL_CELL_SIZE
out_cell:           resb LOCAL_CELL_SIZE

SECTION .text
global _start
_start:
    call    er_local_cell_init
    ASSERT_RDX 0

    lea     rdi, [rel sync_hash]
    call    er_local_route_register
    ASSERT_RDX 0
    mov     [rel sync_slot], eax

    lea     rdi, [rel async_hash]
    call    er_local_route_register
    ASSERT_RDX 0
    mov     [rel async_slot], eax

    mov     edi, [rel sync_slot]
    lea     rsi, [rel sync_handler]
    mov     dl, AGENT_FLAG_SYNC
    call    er_local_route_set_handler
    ASSERT_RDX 0

    mov     edi, [rel async_slot]
    lea     rsi, [rel async_handler]
    xor     edx, edx
    call    er_local_route_set_handler
    ASSERT_RDX 0

    ; SYNC delivery consumes immediately and does not leave queued work.
    mov     byte [rel test_cell + LOCAL_CELL_CMD], 0x42
    mov     dword [rel test_cell + LOCAL_CELL_PAYLOAD + 2], 9
    mov     edi, [rel sync_slot]
    lea     rsi, [rel test_cell]
    call    er_local_cell_send_to_slot
    ASSERT_RDX 0
    ASSERT_EQ dword [rel sync_count], 1
    ASSERT_EQ dword [rel last_sync_sender], 9

    mov     edi, [rel sync_slot]
    lea     rsi, [rel out_cell]
    call    er_local_cell_recv
    ASSERT_RDX ERROR_LOCAL_EMPTY

    call    er_local_cell_poll
    ASSERT_RDX 0
    ASSERT_RAX 0
    ASSERT_EQ dword [rel sync_count], 1

    ; ASYNC delivery enters the queue and is consumed by pipeline polling.
    mov     byte [rel test_cell + LOCAL_CELL_CMD], 0x55
    mov     dword [rel test_cell + LOCAL_CELL_PAYLOAD + 2], 11
    mov     edi, [rel async_slot]
    lea     rsi, [rel test_cell]
    call    er_local_cell_send_to_slot
    ASSERT_RDX 0
    ASSERT_EQ dword [rel async_count], 0

    call    er_local_cell_poll
    ASSERT_RDX 0
    ASSERT_RAX 1
    ASSERT_EQ dword [rel async_count], 1
    ASSERT_EQ dword [rel last_async_sender], 11

    mov     edi, [rel async_slot]
    lea     rsi, [rel out_cell]
    call    er_local_cell_recv
    ASSERT_RDX ERROR_LOCAL_EMPTY

    ; Hash-routed send must use the same sync/async gate as slot-routed send.
    mov     dword [rel test_cell + LOCAL_CELL_PAYLOAD + 2], 13
    lea     rdi, [rel sync_hash]
    lea     rsi, [rel test_cell]
    call    er_local_cell_send
    ASSERT_RDX 0
    ASSERT_EQ dword [rel sync_count], 2
    ASSERT_EQ dword [rel last_sync_sender], 13

    mov     rax, [rel failed]
    test    rax, rax
    jnz     .exit_fail
    xor     edi, edi
    jmp     .exit
.exit_fail:
    mov     edi, 1
.exit:
    mov     eax, 60
    syscall

sync_handler:
    inc     dword [rel sync_count]
    mov     [rel last_sync_sender], esi
    xor     eax, eax
    er_ok
    ret

async_handler:
    inc     dword [rel async_count]
    mov     [rel last_async_sender], esi
    xor     eax, eax
    er_ok
    ret

; local_route import table symbols are not exercised by this test.
global _wasm_import_da_surface_register
global _wasm_import_da_surface_update
global _wasm_import_da_surface_unregister
_wasm_import_da_surface_register:
_wasm_import_da_surface_update:
_wasm_import_da_surface_unregister:
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret
