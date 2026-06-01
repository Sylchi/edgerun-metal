; local_route.asm — EdgeRun identity routing table
;
; Maps 32-byte identity hashes to ring buffer slots.
; Each registered identity has an incoming mailbox ring buffer.
;
; Public API:
;   er_local_cell_init()     — init routing table and all rings
;   er_route_send()          — send cell to any identity route
;   er_route_register_relay() — bind identity to raw Tor cell forwarding
;   er_local_route_register() — register an identity
;   er_local_route_lookup()  — look up slot by identity hash
;   er_local_route_unregister() — unregister an identity
;   er_local_route_get_ring() — get ring pointer for a slot
;   er_local_cell_send_to_slot() — send cell to slot directly
;   er_local_cell_recv()     — receive cell from own mailbox
;   er_local_cell_poll()     — poll registered async handlers
;
; All functions use the two-register return convention:
;   eax = primary value, edx = 0 on success, error code on failure

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/local_constants.inc"
%include "x86_64/agent/agent_constants.inc"
%include "x86_64/crypto/tor_constants.inc"

extern er_memcpy
extern er_memset
extern er_memcmp
extern er_tor_send_cell

; DA WASM import wrappers (from agent/da_wasm.asm)
extern _wasm_import_da_surface_register
extern _wasm_import_da_surface_update
extern _wasm_import_da_surface_unregister

; Import ring buffer helpers from local_cell.asm
extern er_local_ring_init
extern er_local_ring_write
extern er_local_ring_read
extern er_local_ring_available

; Import circuit functions from local_circuit.asm
extern er_local_open_circuit
extern er_local_send_cell
extern er_local_recv_cell
extern er_local_close_circuit

; ==================================================================
; BSS data — routing table
; ==================================================================
SECTION .bss

; Identity routing table: array of LocalRouteEntry
global local_route_table
local_route_table:
    resb LOCAL_ROUTE_TABLE_SIZE

; Number of registered identities
global local_identity_count
local_identity_count: resd 1

; Pointer to the active WASM runtime config (set by kernel at boot)
global er_wasm_runtime_ptr
er_wasm_runtime_ptr: resq 1

SECTION .text

; ==================================================================
; _local_route_entry_ptr — get route table entry pointer
; rdi = slot_id (0 .. LOCAL_MAX_IDENTITIES-1)
; returns rax = pointer, edx = 0 on success
; ==================================================================
_local_route_entry_ptr:
    cmp     edi, LOCAL_MAX_IDENTITIES
    jae     .bad
    mov     eax, edi
    imul    eax, LOCAL_ID_SLOT_SIZE
    add     rax, local_route_table
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    ret

; ==================================================================
; _local_route_hash_valid — reject null or all-zero route identities
; rdi = hash_ptr (32 bytes)
; returns edx = 0 on success, ERROR_INVALID_PARAM on failure
; ==================================================================
_local_route_hash_valid:
    test    rdi, rdi
    jz      .bad
    mov     rax, [rdi]
    or      rax, [rdi + 8]
    or      rax, [rdi + 16]
    or      rax, [rdi + 24]
    test    rax, rax
    jz      .bad
    xor     eax, eax
    er_ok
    ret
.bad:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; ==================================================================
; _local_route_entry_active — validate an allocated route table entry
; rax = route entry ptr
; returns edx = 0 on success, ERROR_INVALID_PARAM on failure
; ==================================================================
_local_route_entry_active:
    test    rax, rax
    jz      .bad
    mov     rcx, [rax + LOCAL_ID_HASH]
    or      rcx, [rax + LOCAL_ID_HASH + 8]
    or      rcx, [rax + LOCAL_ID_HASH + 16]
    or      rcx, [rax + LOCAL_ID_HASH + 24]
    test    rcx, rcx
    jz      .bad
    movzx   ecx, byte [rax + LOCAL_ID_ROUTE_KIND]
    cmp     ecx, LOCAL_ROUTE_KIND_LOCAL
    je      .ok
    cmp     ecx, LOCAL_ROUTE_KIND_RELAY
    je      .ok
.bad:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret
.ok:
    er_ok
    ret

; ==================================================================
; _local_route_find_free — find first free slot
; returns eax = slot_id, or edx = ERROR_LOCAL_BUSY if none free
; ==================================================================
_local_route_find_free:
    xor     edi, edi
.loop:
    cmp     edi, LOCAL_MAX_IDENTITIES
    jae     .full
    ; Check if hash (first 8 bytes) is zero
    push    rdi
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .next_pop
    mov     rdi, rax
    mov     rcx, 4
    xor     eax, eax
    repe    scasd
    jne     .next_pop
    pop     rdi
    mov     eax, edi
    er_ok
    ret
.next_pop:
    pop     rdi
.next:
    inc     edi
    jmp     .loop
.full:
    mov     eax, -1
    er_err  ERROR_LOCAL_BUSY
    ret

; ==================================================================
; _local_route_find_by_hash — find slot by identity hash
; rdi = hash_ptr (32 bytes)
; returns eax = slot_id, or edx = ERROR_LOCAL_NOT_FOUND
; ==================================================================
_local_route_find_by_hash:
    push    rbx
    push    r12

    mov     r12, rdi        ; target hash
    xor     ebx, ebx        ; slot index

.loop:
    cmp     ebx, LOCAL_MAX_IDENTITIES
    jae     .not_found

    mov     edi, ebx
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .next

    lea     rdi, [rax + LOCAL_ID_HASH]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcmp
    test    eax, eax
    jz      .found

.next:
    inc     ebx
    jmp     .loop

.found:
    mov     eax, ebx
    er_ok
    pop     r12
    pop     rbx
    ret

.not_found:
    mov     eax, -1
    er_err  ERROR_LOCAL_NOT_FOUND
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_local_cell_init — initialize local cell transport
; void er_local_cell_init(void)
; ==================================================================
er_fn er_local_cell_init
    push    rbx
    push    r12

    ; Clear entire routing table
    mov     edi, local_route_table
    xor     esi, esi
    mov     edx, LOCAL_ROUTE_TABLE_SIZE
    call    er_memset

    ; Initialize each ring buffer's head/tail
    xor     r12d, r12d
.loop:
    cmp     r12d, LOCAL_MAX_IDENTITIES
    jae     .done

    mov     edi, r12d
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .next

    lea     rdi, [rax + LOCAL_ID_RING]
    call    er_local_ring_init

.next:
    inc     r12d
    jmp     .loop

.done:
    mov     dword [local_identity_count], 0
    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_route_register — register an identity for local routing
; int er_local_route_register(const u8 *identity_hash[32])
; rdi = identity hash pointer (32 bytes)
; Returns: eax = slot_id on success, edx = error on failure
; ==================================================================
er_fn er_local_route_register
    push    rbx
    push    r12

    mov     r12, rdi        ; identity hash

    call    _local_route_hash_valid
    test    edx, edx
    jnz     .internal_error

    ; Check if already registered
    mov     rdi, r12
    call    _local_route_find_by_hash
    test    edx, edx
    jz      .already_exists

    ; Find free slot
    call    _local_route_find_free
    test    edx, edx
    jnz     .full

    mov     ebx, eax        ; slot_id

    ; Copy identity hash into slot
    mov     edi, ebx
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .internal_error

    lea     rdi, [rax + LOCAL_ID_HASH]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcpy

    mov     edi, ebx
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .internal_error
    mov     byte [rax + LOCAL_ID_ROUTE_KIND], LOCAL_ROUTE_KIND_LOCAL

    inc     dword [local_identity_count]

    mov     eax, ebx
    er_ok
    pop     r12
    pop     rbx
    er_ret

.already_exists:
    mov     eax, -1
    er_err  ERROR_LOCAL_EXISTS
    pop     r12
    pop     rbx
    er_ret

.full:
    pop     r12
    pop     rbx
    er_ret

.internal_error:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_route_lookup — look up an identity by hash
; int er_local_route_lookup(const u8 *identity_hash[32])
; rdi = identity hash pointer (32 bytes)
; Returns: eax = slot_id, edx = 0 on success, ERROR_LOCAL_NOT_FOUND
; ==================================================================
er_fn er_local_route_lookup
    call    _local_route_hash_valid
    test    edx, edx
    jnz     .bad
    call    _local_route_find_by_hash
    ret
.bad:
    mov     eax, -1
    er_ret

; ==================================================================
; er_route_register_relay — register/update raw Tor cell forwarding
; int er_route_register_relay(hash[32])
; rdi = identity hash
; ==================================================================
global er_route_register_relay
er_fn er_route_register_relay
    push    rbx
    push    r12

    mov     r12, rdi

    call    _local_route_hash_valid
    test    edx, edx
    jnz     .bad

    mov     rdi, r12
    call    _local_route_find_by_hash
    test    edx, edx
    jz      .use_slot

    call    _local_route_find_free
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     edi, ebx
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad
    lea     rdi, [rax + LOCAL_ID_HASH]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcpy
    inc     dword [local_identity_count]
    jmp     .write

.use_slot:
    mov     ebx, eax
.write:
    mov     edi, ebx
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad
    mov     byte [rax + LOCAL_ID_ROUTE_KIND], LOCAL_ROUTE_KIND_RELAY
    mov     eax, ebx
    er_ok
.done:
    pop     r12
    pop     rbx
    er_ret
.bad:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_route_unregister — unregister an identity
; int er_local_route_unregister(u32 slot_id)
; rdi = slot_id
; Returns: eax = 0, edx = 0 on success
; ==================================================================
er_fn er_local_route_unregister
    push    rbx

    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad
    mov     rbx, rax
    call    _local_route_entry_active
    test    edx, edx
    jnz     .bad

    ; Clear the full route entry and reinitialize its ring.
    mov     rdi, rbx
    xor     esi, esi
    mov     edx, LOCAL_ID_SLOT_SIZE
    call    er_memset
    lea     rdi, [rbx + LOCAL_ID_RING]
    call    er_local_ring_init

    dec     dword [local_identity_count]
    xor     eax, eax
    er_ok
    pop     rbx
    er_ret

.bad:
    pop     rbx
    er_ret

; ==================================================================
; er_local_route_set_handler — set agent handler for a slot
; int er_local_route_set_handler(u32 slot_id, void *handler, u8 flags)
; rdi = slot_id, rsi = handler fn ptr, dl = flags
; Returns: eax = 0, edx = 0 on success
; ==================================================================
er_fn er_local_route_set_handler
    push    rbx
    push    r12

    mov     r12b, dl            ; flags

    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad
    call    _local_route_entry_active
    test    edx, edx
    jnz     .bad
    cmp     byte [rax + LOCAL_ID_ROUTE_KIND], LOCAL_ROUTE_KIND_LOCAL
    jne     .bad

    ; Store handler pointer
    mov     [rax + LOCAL_ID_HANDLER], rsi
    ; Store flags
    mov     [rax + LOCAL_ID_FLAGS], r12b

    xor     eax, eax
    er_ok
    pop     r12
    pop     rbx
    er_ret

.bad:
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_route_get_ring — get ring buffer pointer for a slot
; int er_local_route_get_ring(u32 slot_id)
; rdi = slot_id
; Returns: rax = ring pointer, edx = 0 on success
; ==================================================================
er_fn er_local_route_get_ring
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad
    call    _local_route_entry_active
    test    edx, edx
    jnz     .bad
    cmp     byte [rax + LOCAL_ID_ROUTE_KIND], LOCAL_ROUTE_KIND_LOCAL
    jne     .bad
    add     rax, LOCAL_ID_RING
    er_ok
    ret
.bad:
    xor     eax, eax
    er_ret

; ==================================================================
; er_route_send — send a cell to an identity route
; int er_route_send(const u8 *dest_hash[32], const u8 *cell[LOCAL_CELL_SIZE])
; rdi = dest identity hash, rsi = cell data
; Returns: eax = 0, edx = 0 on success
; ==================================================================
global er_route_send
er_fn er_route_send
    push    rbx
    push    r12
    push    r13

    mov     r12, rsi        ; cell

    call    _local_route_hash_valid
    test    edx, edx
    jnz     .bad

    call    _local_route_find_by_hash
    test    edx, edx
    jnz     .not_found

    mov     ebx, eax        ; slot_id
    mov     edi, ebx
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad

    movzx   ecx, byte [rax + LOCAL_ID_ROUTE_KIND]
    cmp     ecx, LOCAL_ROUTE_KIND_RELAY
    je      .send_tor
    cmp     ecx, LOCAL_ROUTE_KIND_LOCAL
    jne     .not_found

    mov     edi, ebx        ; slot_id
    mov     rsi, r12        ; cell
    call    er_local_cell_send_to_slot

    pop     r13
    pop     r12
    pop     rbx
    er_ret

.send_tor:
    mov     rdi, r12
    call    er_tor_send_cell
    test    eax, eax
    js      .tor_fail
    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.tor_fail:
    mov     eax, -1
    er_err  ERROR_TOR_STREAM_FAIL
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.not_found:
    mov     eax, -1
    er_err  ERROR_LOCAL_NOT_FOUND
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad:
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_cell_recv — receive a cell from an identity's incoming ring
; int er_local_cell_recv(u32 slot_id, u8 *out_cell[LOCAL_CELL_SIZE])
; rdi = slot_id, rsi = output buffer
; Returns: eax = 0, edx = 0 on success, ERROR_LOCAL_EMPTY if none
; ==================================================================
er_fn er_local_cell_recv
    push    rbx
    push    r12

    mov     r12, rsi        ; out buffer

    call    er_local_route_get_ring
    test    edx, edx
    jnz     .bad

    mov     rdi, rax        ; ring_ptr
    mov     rsi, r12        ; out cell
    call    er_local_ring_read

    pop     r12
    pop     rbx
    er_ret

.bad:
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_cell_send_to_slot — send a cell to a specific slot directly
; int er_local_cell_send_to_slot(u32 slot_id, const u8 *cell[LOCAL_CELL_SIZE])
; rdi = slot_id, rsi = cell data
; Skip hash lookup, use slot_id directly.
; ==================================================================
er_fn er_local_cell_send_to_slot
    push    rbx
    push    r12
    push    r13

    mov     ebx, edi        ; slot_id
    mov     r12, rsi        ; cell

    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .bad
    mov     r13, rax        ; route entry
    call    _local_route_entry_active
    test    edx, edx
    jnz     .bad
    cmp     byte [r13 + LOCAL_ID_ROUTE_KIND], LOCAL_ROUTE_KIND_LOCAL
    jne     .bad

    ; Synchronous handlers consume the cell immediately and do not queue it.
    movzx   ecx, byte [r13 + LOCAL_ID_FLAGS]
    test    cl, AGENT_FLAG_SYNC
    jz      .enqueue
    mov     rcx, [r13 + LOCAL_ID_HANDLER]
    test    rcx, rcx
    jz      .enqueue

    mov     rdi, r12
    mov     esi, [r12 + LOCAL_CELL_PAYLOAD + AGENT_PAYLOAD_SENDER_SLOT]
    call    rcx
    jmp     .done

.enqueue:
    lea     rdi, [r13 + LOCAL_ID_RING]
    mov     rsi, r12        ; cell
    call    er_local_ring_write

.done:
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.bad:
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_cell_poll — called from main loop
; void er_local_cell_poll(void)
;
; Iterates all registered identities. For each with a handler
; and pending cells, calls the handler.
; ==================================================================
er_fn er_local_cell_poll
    push    rbx
    push    r12
    push    r13
    push    r14

    xor     r12d, r12d          ; slot index
    xor     r14d, r14d          ; cells processed

.loop:
    cmp     r12d, LOCAL_MAX_IDENTITIES
    jae     .done

    mov     edi, r12d
    call    _local_route_entry_ptr
    test    edx, edx
    jnz     .next
    call    _local_route_entry_active
    test    edx, edx
    jnz     .next
    cmp     byte [rax + LOCAL_ID_ROUTE_KIND], LOCAL_ROUTE_KIND_LOCAL
    jne     .next

    ; Check for handler
    mov     rcx, [rax + LOCAL_ID_HANDLER]
    test    rcx, rcx
    jz      .next

    ; SYNC handlers are delivered by send_to_slot, not by queue polling.
    movzx   ebx, byte [rax + LOCAL_ID_FLAGS]
    test    bl, AGENT_FLAG_SYNC
    jnz     .next

    mov     rbx, rcx            ; handler, preserved across ring helpers

    ; Check ring for pending cells
    lea     r13, [rax + LOCAL_ID_RING]
    mov     rdi, r13
    call    er_local_ring_available
    test    eax, eax
    jz      .next

    ; Read one pending cell and dispatch
    sub     rsp, LOCAL_CELL_SIZE
    mov     rdi, r13
    mov     rsi, rsp
    call    er_local_ring_read
    test    edx, edx
    jnz     .pop_next

    ; Dispatch: handler(rdi=cell_ptr, rsi=sender_slot_id)
    mov     rdi, rsp
    lea     rsi, [rsp + LOCAL_CELL_PAYLOAD + AGENT_PAYLOAD_SENDER_SLOT]
    mov     esi, [rsi]          ; sender slot_id from payload
    call    rbx
    inc     r14d

.pop_next:
    add     rsp, LOCAL_CELL_SIZE

.next:
    inc     r12d
    jmp     .loop

.done:
    mov     eax, r14d
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; WASM host import wrappers
;
; These are the callback functions that the WASM interpreter dispatches
; to when a WASM module calls an imported function from module "er".
;
; Calling convention: System V AMD64 ABI
;   rdi, rsi, rdx, rcx, r8, r9 = args (from WASM exec stack)
;   rax = return value
;
; WASM i32 values are zero-extended to 64-bit by the interpreter.
; Linear memory offsets (passed as i32) need conversion to host pointers.
; ==================================================================

; er_wasm_local_cell_send(rdi=dest_hash_ptr(i32), rsi=cell_ptr(i32)) -> i32
_wasm_import_local_cell_send:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_local_cell_recv(rdi=slot_id(i32), rsi=out_cell_ptr(i32)) -> i32
_wasm_import_local_cell_recv:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_local_route_register(rdi=hash_ptr(i32)) -> i32 (slot_id)
_wasm_import_local_route_register:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_local_route_lookup(rdi=hash_ptr(i32)) -> i32 (slot_id or -1)
_wasm_import_local_route_lookup:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_local_route_unregister(rdi=slot_id(i32)) -> i32
_wasm_import_local_route_unregister:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_local_cell_available(rdi=slot_id(i32)) -> i32 (count)
_wasm_import_local_cell_available:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; ==================================================================
; Circuit WASM import wrappers
; ==================================================================

; er_wasm_circuit_open(rdi=dest_hash_ptr(i32), rsi=own_slot(i32)) -> i32 (fd)
_wasm_import_circuit_open:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_circuit_send(rdi=fd(i32), rsi=cell_ptr(i32)) -> i32
_wasm_import_circuit_send:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_circuit_recv(rdi=fd(i32), rsi=out_cell_ptr(i32)) -> i32
_wasm_import_circuit_recv:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; er_wasm_circuit_close(rdi=fd(i32)) -> i32
_wasm_import_circuit_close:
    mov     eax, -1
    er_err  ERROR_INVALID_PARAM
    ret

; ==================================================================
; Host import table
;
; Array of HostImport struct entries (HOST_IMPORT_SIZE each).
; Module name is always "er" for EdgeRun runtime imports.
; ==================================================================
SECTION .data

; Module name string
er_module_name: db "er"
er_module_name_len: dq 2

; Function name strings
fn_send:       db "cell_send"
fn_send_len:   dq 9
fn_recv:       db "cell_recv"
fn_recv_len:   dq 9
fn_register:   db "route_register"
fn_register_len: dq 14
fn_lookup:     db "route_lookup"
fn_lookup_len: dq 12
fn_unregister: db "route_unregister"
fn_unregister_len: dq 16
fn_available:  db "cell_available"
fn_available_len: dq 14
fn_circ_open:  db "circuit_open"
fn_circ_open_len: dq 11
fn_circ_send:  db "circuit_send"
fn_circ_send_len: dq 12
fn_circ_recv:  db "circuit_recv"
fn_circ_recv_len: dq 12
fn_circ_close: db "circuit_close"
fn_circ_close_len: dq 12
fn_da_register:  db "da_surface_register"
fn_da_register_len: dq 19
fn_da_update:    db "da_surface_update"
fn_da_update_len: dq 17
fn_da_unregister: db "da_surface_unregister"
fn_da_unregister_len: dq 21

; Import table — 13 entries × 40 bytes = 520 bytes total
; Note: assembled as ELF32, use dd (4-byte) with zero upper padding
; to keep 8-byte-per-field struct layout (HOST_IMPORT_SIZE = 40).
global er_local_cell_imports
er_local_cell_imports:
; Entry 0: local_cell_send
dd er_module_name, 0
dd 2, 0
dd fn_send, 0
dd 9, 0
dd _wasm_import_local_cell_send, 0

; Entry 1: local_cell_recv
dd er_module_name, 0
dd 2, 0
dd fn_recv, 0
dd 9, 0
dd _wasm_import_local_cell_recv, 0

; Entry 2: local_route_register
dd er_module_name, 0
dd 2, 0
dd fn_register, 0
dd 14, 0
dd _wasm_import_local_route_register, 0

; Entry 3: local_route_lookup
dd er_module_name, 0
dd 2, 0
dd fn_lookup, 0
dd 12, 0
dd _wasm_import_local_route_lookup, 0

; Entry 4: local_route_unregister
dd er_module_name, 0
dd 2, 0
dd fn_unregister, 0
dd 16, 0
dd _wasm_import_local_route_unregister, 0

; Entry 5: local_cell_available
dd er_module_name, 0
dd 2, 0
dd fn_available, 0
dd 14, 0
dd _wasm_import_local_cell_available, 0

; Entry 6: circuit_open
dd er_module_name, 0
dd 2, 0
dd fn_circ_open, 0
dd 11, 0
dd _wasm_import_circuit_open, 0

; Entry 7: circuit_send
dd er_module_name, 0
dd 2, 0
dd fn_circ_send, 0
dd 12, 0
dd _wasm_import_circuit_send, 0

; Entry 8: circuit_recv
dd er_module_name, 0
dd 2, 0
dd fn_circ_recv, 0
dd 12, 0
dd _wasm_import_circuit_recv, 0

; Entry 9: circuit_close
dd er_module_name, 0
dd 2, 0
dd fn_circ_close, 0
dd 12, 0
dd _wasm_import_circuit_close, 0

; Entry 10: da_surface_register
dd er_module_name, 0
dd 2, 0
dd fn_da_register, 0
dd 19, 0
dd _wasm_import_da_surface_register, 0

; Entry 11: da_surface_update
dd er_module_name, 0
dd 2, 0
dd fn_da_update, 0
dd 17, 0
dd _wasm_import_da_surface_update, 0

; Entry 12: da_surface_unregister
dd er_module_name, 0
dd 2, 0
dd fn_da_unregister, 0
dd 21, 0
dd _wasm_import_da_surface_unregister, 0

; Import count
global er_local_cell_import_count
er_local_cell_import_count: dq 13
