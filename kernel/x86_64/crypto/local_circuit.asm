; local_circuit.asm — EdgeRun local circuit abstraction
;
; Provides open_circuit, send_cell, recv_cell, close_circuit over the
; identity routing table (local_route.asm) ring buffers.  Each circuit
; entry caches the destination slot_id so that send() avoids a hash
; lookup on every call.
;
; Public API:
;   er_local_circuit_init()             — zero circuit table
;   er_local_open_circuit()             — open circuit to identity
;   er_local_send_cell()                — send cell on circuit
;   er_local_recv_cell()                — receive cell from own ring
;   er_local_close_circuit()            — close circuit
;
; All functions use the two-register return convention:
;   eax = primary value, edx = 0 on success, error code on failure

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/local_constants.inc"

extern er_memset
extern er_memcpy
extern er_local_route_lookup
extern er_local_cell_send_to_slot
extern er_local_cell_recv
extern er_local_route_get_ring

; ==================================================================
; BSS — circuit table
; ==================================================================
SECTION .bss

; Circuit table: fixed-size array of CircuitSlot entries
global local_circuit_table
local_circuit_table:
    resb CIRCUIT_TABLE_SIZE

; Own slot_id for this process (set by open_circuit, used by recv)
global local_circuit_own_slot
local_circuit_own_slot: resd 1

SECTION .text

; ==================================================================
; _local_circuit_entry_ptr — get circuit table entry pointer
; rdi = circuit_index (0 .. MAX_CIRCUITS-1)
; returns rax = ptr, edx = 0 on success, ERROR_CIRCUIT_INVALID on bad idx
; ==================================================================
_local_circuit_entry_ptr:
    test    edi, edi
    js      .bad
    cmp     edi, MAX_CIRCUITS
    jae     .bad
    mov     eax, edi
    imul    eax, CIRCUIT_SLOT_SIZE
    add     rax, local_circuit_table
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_CIRCUIT_INVALID
    ret

; ==================================================================
; _local_circuit_find_free — find first free circuit slot
; returns eax = circuit_index (0-based), edx = 0 on success
; ==================================================================
_local_circuit_find_free:
    xor     edi, edi
.loop:
    cmp     edi, MAX_CIRCUITS
    jae     .full
    call    _local_circuit_entry_ptr
    test    edx, edx
    jnz     .full
    cmp     dword [rax + CIRCUIT_STATE], CIRCUIT_STATE_FREE
    je      .found
    inc     edi
    jmp     .loop
.full:
    mov     eax, -1
    er_err  ERROR_LOCAL_BUSY
    ret
.found:
    mov     eax, edi
    er_ok
    ret

; ==================================================================
; _local_circuit_fd_to_index — convert 1-based fd to circuit_index
; rdi = fd
; returns eax = index, edx = 0 on success
; ==================================================================
_local_circuit_fd_to_index:
    lea     eax, [rdi - 1]
    test    eax, eax
    js      .bad
    cmp     eax, MAX_CIRCUITS
    jae     .bad
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_CIRCUIT_INVALID
    ret

; ==================================================================
; _local_circuit_open_entry — validate fd and return open circuit entry
; rdi = fd
; returns rax = entry ptr, edx = 0 on success
; ==================================================================
_local_circuit_open_entry:
    call    _local_circuit_fd_to_index
    test    edx, edx
    jnz     .bad
    mov     edi, eax
    call    _local_circuit_entry_ptr
    test    edx, edx
    jnz     .bad
    cmp     dword [rax + CIRCUIT_STATE], CIRCUIT_STATE_OPEN
    jne     .bad
    er_ok
    ret
.bad:
    xor     eax, eax
    er_err  ERROR_CIRCUIT_INVALID
    ret

; ==================================================================
; er_local_circuit_init — initialize circuit table
; void er_local_circuit_init(void)
; ==================================================================
er_fn er_local_circuit_init
    mov     edi, local_circuit_table
    xor     esi, esi
    mov     edx, CIRCUIT_TABLE_SIZE
    call    er_memset
    mov     dword [local_circuit_own_slot], -1
    er_ok
    ret

; ==================================================================
; er_local_open_circuit — open a circuit to a destination identity
; int er_local_open_circuit(const u8 *dest_hash[32], u32 own_slot)
; rdi = dest identity hash (32 bytes), esi = caller's own slot_id
; Returns: eax = fd (1-based circuit handle), edx = 0 on success
; ==================================================================
er_fn er_local_open_circuit
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; dest_hash
    mov     r13d, esi       ; own_slot

    ; Validate own slot before mutating global recv state.
    mov     edi, r13d
    call    er_local_route_get_ring
    test    edx, edx
    jnz     .not_found

    ; Look up destination in route table
    mov     rdi, r12
    call    er_local_route_lookup
    test    edx, edx
    jnz     .not_found

    mov     ebx, eax        ; dest_slot_id

    ; Find free circuit slot
    call    _local_circuit_find_free
    test    edx, edx
    jnz     .busy

    mov     r14d, eax       ; circuit_index

    ; Get circuit entry pointer
    mov     edi, r14d
    call    _local_circuit_entry_ptr
    test    edx, edx
    jnz     .internal_error

    ; Store destination hash
    lea     rdi, [rax + CIRCUIT_DEST_HASH]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcpy

    ; Get entry pointer again (rdi may have been clobbered)
    mov     edi, r14d
    call    _local_circuit_entry_ptr

    ; Store destination slot and state
    mov     [rax + CIRCUIT_DEST_SLOT], ebx
    mov     dword [rax + CIRCUIT_STATE], CIRCUIT_STATE_OPEN
    mov     dword [local_circuit_own_slot], r13d

    ; Return fd = circuit_index + 1
    lea     eax, [r14d + 1]
    er_ok
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.not_found:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.busy:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

.internal_error:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_send_cell — send a cell on a circuit
; int er_local_send_cell(u32 fd, const u8 *cell[LOCAL_CELL_SIZE])
; rdi = fd (circuit handle), rsi = cell data
; Sets cell circuit_id to fd, sends to destination's ring buffer.
; Returns: eax = 0, edx = 0 on success
; ==================================================================
er_fn er_local_send_cell
    push    rbx
    push    r12
    push    r13

    mov     r12, rsi        ; cell
    mov     r13d, edi       ; fd (save for circ ID)

    ; Validate circuit before mutating caller-owned cell bytes.
    call    _local_circuit_open_entry
    test    edx, edx
    jnz     .bad

    mov     [r12 + LOCAL_CELL_CIRC_ID], r13d

    ; Get destination slot and send
    mov     edi, [rax + CIRCUIT_DEST_SLOT]
    mov     rsi, r12
    call    er_local_cell_send_to_slot

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
; er_local_recv_cell — receive a cell from own ring buffer
; int er_local_recv_cell(u32 fd, u8 *out_cell[LOCAL_CELL_SIZE])
; rdi = fd (for validation only), rsi = output buffer
; Returns: eax = 0, edx = 0 on success, ERROR_LOCAL_EMPTY if none
; ==================================================================
er_fn er_local_recv_cell
    push    rbx
    push    r12

    mov     r12, rsi        ; out buffer

    ; Validate fd and open state.
    call    _local_circuit_open_entry
    test    edx, edx
    jnz     .bad

    ; Read from own slot's ring buffer
    mov     edi, [local_circuit_own_slot]
    test    edi, edi
    js      .bad            ; own_slot not set

    mov     rsi, r12
    call    er_local_cell_recv

    pop     r12
    pop     rbx
    er_ret

.bad:
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_local_close_circuit — close a circuit, free its slot
; int er_local_close_circuit(u32 fd)
; rdi = fd
; Returns: eax = 0, edx = 0 on success
; ==================================================================
er_fn er_local_close_circuit
    push    rbx

    call    _local_circuit_open_entry
    test    edx, edx
    jnz     .bad

    ; Clear the full circuit entry so stale destinations are not retained.
    mov     rdi, rax
    xor     esi, esi
    mov     edx, CIRCUIT_SLOT_SIZE
    call    er_memset

    xor     eax, eax
    er_ok
    pop     rbx
    er_ret

.bad:
    pop     rbx
    er_ret
