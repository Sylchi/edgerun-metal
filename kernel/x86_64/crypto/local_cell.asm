; local_cell.asm — EdgeRun local cell ring buffer transport
;
; SPSC ring buffer for same-machine identity-based cell delivery.
; Producer: kernel (writes on behalf of any sender)
; Consumer: the registered identity's WASM handler
;
; All functions use the two-register return convention:
;   eax = primary value, edx = 0 on success, error code on failure

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/crypto/local_constants.inc"

extern er_memcpy
extern er_memset

; Exported for use by local_route.asm
global er_local_ring_init
global er_local_ring_write
global er_local_ring_read

; ==================================================================
; BSS data
; ==================================================================
SECTION .bss

; Ring buffer scratch for cell send
local_tx_cell: resb LOCAL_CELL_SIZE

; Debug/status counter
local_cells_sent: resd 1
local_cells_recv: resd 1

SECTION .text

; ==================================================================
; _local_ring_init — initialize a ring buffer
; void _local_ring_init(LocalRing *ring)
; rdi = ring pointer
; ==================================================================
er_local_ring_init:
    mov     dword [rdi + LOCAL_RING_HEAD], 0
    mov     dword [rdi + LOCAL_RING_TAIL], 0
    er_ok
    ret

; ==================================================================
; _local_ring_write — write a cell to the ring buffer (non-blocking)
; int _local_ring_write(LocalRing *ring, const u8 *cell[LOCAL_CELL_SIZE])
; rdi = ring pointer, rsi = cell pointer
; Returns: edx = 0 on success, ERROR_LOCAL_FULL if ring is full
; ==================================================================
er_local_ring_write:
    push    rbx
    push    r12
    push    r13

    mov     rbx, rdi        ; ring
    mov     r12, rsi        ; cell

    ; Check if full: (head - tail) >= LOCAL_RING_SLOTS
    mov     eax, [rbx + LOCAL_RING_HEAD]
    mov     ecx, [rbx + LOCAL_RING_TAIL]
    sub     eax, ecx
    cmp     eax, LOCAL_RING_SLOTS
    jae     .full

    ; Compute slot index: head % LOCAL_RING_SLOTS
    mov     eax, [rbx + LOCAL_RING_HEAD]
    xor     edx, edx
    mov     ecx, LOCAL_RING_SLOTS
    div     ecx

    ; Slot offset in bytes: slot * LOCAL_CELL_SIZE
    mov     r13d, eax
    imul    r13d, LOCAL_CELL_SIZE

    ; Slot pointer = ring + LOCAL_RING_CELLS + slot_offset
    lea     rdi, [rbx + LOCAL_RING_CELLS]
    add     rdi, r13
    mov     rsi, r12
    mov     edx, LOCAL_CELL_SIZE
    call    er_memcpy

    ; Increment head
    inc     dword [rbx + LOCAL_RING_HEAD]
    inc     dword [local_cells_sent]

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    ret

.full:
    mov     eax, -1
    er_err  ERROR_LOCAL_FULL
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _local_ring_read — read a cell from the ring buffer (non-blocking)
; int _local_ring_read(LocalRing *ring, u8 *out_cell[LOCAL_CELL_SIZE])
; rdi = ring pointer, rsi = out cell pointer
; Returns: edx = 0 on success, ERROR_LOCAL_EMPTY if ring is empty
; ==================================================================
er_local_ring_read:
    push    rbx
    push    r12
    push    r13

    mov     rbx, rdi        ; ring
    mov     r12, rsi        ; out cell

    ; Check if empty: head == tail
    mov     eax, [rbx + LOCAL_RING_HEAD]
    mov     ecx, [rbx + LOCAL_RING_TAIL]
    cmp     eax, ecx
    je      .empty

    ; Compute slot index: tail % LOCAL_RING_SLOTS
    mov     eax, ecx        ; tail
    xor     edx, edx
    mov     ecx, LOCAL_RING_SLOTS
    div     ecx

    ; Slot offset in bytes: slot * LOCAL_CELL_SIZE
    mov     r13d, eax
    imul    r13d, LOCAL_CELL_SIZE

    ; Slot pointer = ring + LOCAL_RING_CELLS + slot_offset
    ; Copy from slot to out buffer
    lea     rsi, [rbx + LOCAL_RING_CELLS]
    add     rsi, r13
    mov     rdi, r12
    mov     edx, LOCAL_CELL_SIZE
    call    er_memcpy

    ; Increment tail
    inc     dword [rbx + LOCAL_RING_TAIL]
    inc     dword [local_cells_recv]

    xor     eax, eax
    er_ok
    pop     r13
    pop     r12
    pop     rbx
    ret

.empty:
    mov     eax, -1
    er_err  ERROR_LOCAL_EMPTY
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _local_ring_available — return number of cells available to read
; u32 _local_ring_available(LocalRing *ring)
; rdi = ring pointer
; Returns: eax = count, edx = 0
; ==================================================================
global er_local_ring_available
er_fn er_local_ring_available
    mov     eax, [rdi + LOCAL_RING_HEAD]
    sub     eax, [rdi + LOCAL_RING_TAIL]
    er_ok
    ret

; ==================================================================
; _local_ring_write_space — return number of free slots for writing
; u32 _local_ring_write_space(LocalRing *ring)
; rdi = ring pointer
; Returns: eax = count, edx = 0
; ==================================================================
er_local_ring_write_space:
    mov     eax, [rdi + LOCAL_RING_HEAD]
    sub     eax, [rdi + LOCAL_RING_TAIL]
    neg     eax
    add     eax, LOCAL_RING_SLOTS
    er_ok
    ret
