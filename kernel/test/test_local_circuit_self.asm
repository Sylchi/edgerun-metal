; EdgeRun local circuit self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/local_constants.inc"
%include "test/test_macros.inc"

extern er_local_cell_init
extern er_local_circuit_init
extern er_local_route_register
extern er_local_cell_send_to_slot
extern er_local_cell_recv
extern er_local_open_circuit
extern er_local_send_cell
extern er_local_recv_cell
extern er_local_close_circuit
extern local_circuit_own_slot

SECTION .data
own_hash:
    db "local-circuit-own-identity"
    times 32 - ($ - own_hash) db 0
dest_hash:
    db "local-circuit-dest-identity"
    times 32 - ($ - dest_hash) db 0
missing_hash:
    db "local-circuit-missing-identity"
    times 32 - ($ - missing_hash) db 0

TEST_BSS_PASSED_FAILED
own_slot:       resd 1
dest_slot:      resd 1
circuit_fd:     resd 1
test_cell:      resb LOCAL_CELL_SIZE
out_cell:       resb LOCAL_CELL_SIZE

SECTION .text
global _start
_start:
    call    er_local_cell_init
    ASSERT_RDX 0
    call    er_local_circuit_init
    ASSERT_RDX 0
    ASSERT_EQ dword [rel local_circuit_own_slot], -1

    mov     dword [rel test_cell + LOCAL_CELL_CIRC_ID], 0x11223344
    mov     edi, 1
    lea     rsi, [rel test_cell]
    call    er_local_send_cell
    ASSERT_RDX ERROR_CIRCUIT_INVALID
    ASSERT_EQ dword [rel test_cell + LOCAL_CELL_CIRC_ID], 0x11223344

    mov     edi, 1
    lea     rsi, [rel out_cell]
    call    er_local_recv_cell
    ASSERT_RDX ERROR_CIRCUIT_INVALID

    mov     edi, 1
    call    er_local_close_circuit
    ASSERT_RDX ERROR_CIRCUIT_INVALID

    lea     rdi, [rel own_hash]
    call    er_local_route_register
    ASSERT_RDX 0
    mov     [rel own_slot], eax

    lea     rdi, [rel dest_hash]
    call    er_local_route_register
    ASSERT_RDX 0
    mov     [rel dest_slot], eax

    lea     rdi, [rel dest_hash]
    mov     esi, [rel own_slot]
    call    er_local_open_circuit
    ASSERT_RDX 0
    ASSERT_RAX 1
    mov     [rel circuit_fd], eax
    mov     eax, [rel own_slot]
    ASSERT_EQ dword [rel local_circuit_own_slot], eax

    mov     dword [rel test_cell + LOCAL_CELL_CIRC_ID], 0
    mov     byte [rel test_cell + LOCAL_CELL_CMD], 0x5a
    mov     edi, [rel circuit_fd]
    lea     rsi, [rel test_cell]
    call    er_local_send_cell
    ASSERT_RDX 0
    mov     eax, [rel circuit_fd]
    ASSERT_EQ dword [rel test_cell + LOCAL_CELL_CIRC_ID], eax

    mov     edi, [rel dest_slot]
    lea     rsi, [rel out_cell]
    call    er_local_cell_recv
    ASSERT_RDX 0
    mov     eax, [rel circuit_fd]
    ASSERT_EQ dword [rel out_cell + LOCAL_CELL_CIRC_ID], eax
    ASSERT_EQ byte [rel out_cell + LOCAL_CELL_CMD], 0x5a

    mov     byte [rel test_cell + LOCAL_CELL_CMD], 0xa5
    mov     edi, [rel own_slot]
    lea     rsi, [rel test_cell]
    call    er_local_cell_send_to_slot
    ASSERT_RDX 0

    mov     edi, [rel circuit_fd]
    lea     rsi, [rel out_cell]
    call    er_local_recv_cell
    ASSERT_RDX 0
    ASSERT_EQ byte [rel out_cell + LOCAL_CELL_CMD], 0xa5

    mov     edi, [rel circuit_fd]
    call    er_local_close_circuit
    ASSERT_RDX 0

    mov     dword [rel test_cell + LOCAL_CELL_CIRC_ID], 0x55667788
    mov     edi, [rel circuit_fd]
    lea     rsi, [rel test_cell]
    call    er_local_send_cell
    ASSERT_RDX ERROR_CIRCUIT_INVALID
    ASSERT_EQ dword [rel test_cell + LOCAL_CELL_CIRC_ID], 0x55667788

    mov     edi, [rel circuit_fd]
    lea     rsi, [rel out_cell]
    call    er_local_recv_cell
    ASSERT_RDX ERROR_CIRCUIT_INVALID

    mov     edi, [rel circuit_fd]
    call    er_local_close_circuit
    ASSERT_RDX ERROR_CIRCUIT_INVALID

    lea     rdi, [rel dest_hash]
    mov     esi, LOCAL_MAX_IDENTITIES
    call    er_local_open_circuit
    ASSERT_RDX ERROR_INVALID_PARAM
    mov     eax, [rel own_slot]
    ASSERT_EQ dword [rel local_circuit_own_slot], eax

    lea     rdi, [rel missing_hash]
    mov     esi, [rel own_slot]
    call    er_local_open_circuit
    ASSERT_RDX ERROR_LOCAL_NOT_FOUND
    mov     eax, [rel own_slot]
    ASSERT_EQ dword [rel local_circuit_own_slot], eax

    TEST_EXIT_FAILED

global _wasm_import_da_surface_register
global _wasm_import_da_surface_update
global _wasm_import_da_surface_unregister
_wasm_import_da_surface_register:
_wasm_import_da_surface_update:
_wasm_import_da_surface_unregister:
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret

global er_tor_send_cell
er_tor_send_cell:
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret
