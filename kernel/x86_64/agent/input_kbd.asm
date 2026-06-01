; input_kbd.asm — Keyboard input agent
;
; Registers as ephemeral identity (per-boot random, no TPM binding).
; Polls i8042 each pipeline tick and forwards input cells by focused identity.
;
; Ephemeral identity properties:
;   - 32 bytes generated from RDTSC + Xorshift32 (per-boot random)
;   - NOT derived from binary hash or TPM measurement
;   - Changes every boot — no cross-session linkability
;   - Sender is local-only; focused app identity decides local vs remote route
;   - Collision-resistant for LOCAL_MAX_IDENTITIES (16 entries)
;
; Focus target is read from da_focused_hash (DA's BSS, same address
; space). The DA tracks which app has focus; this agent sends input
; cells through the identity route. Keystrokes never pass through the DA compositor.
;
; WASM apps receive input via er.cell_recv — check payload[0]==5
; for DA_MSG_INPUT_EVENT.

%include "x86_64/macros.inc"
%include "x86_64/agent/agent_constants.inc"
%include "x86_64/agent/da_constants.inc"
%include "x86_64/crypto/local_constants.inc"

extern er_i8042_read_scancode
extern er_i8042_scancode_to_ascii
extern er_local_route_register
extern er_local_cell_send
extern er_memset

; DA's focus globals — read directly (same address space, no cell overhead)
extern da_focused_slot
extern da_focused_hash

; ==================================================================
; BSS
; ==================================================================
SECTION .bss

ik_identity:     resb 32   ; ephemeral identity (per-boot random)
ik_modifiers:    resb 1    ; keyboard modifier state
ik_cell:         resb LOCAL_CELL_SIZE  ; scratch cell for building input
ik_initialized:  resb 1

; ==================================================================
; .data
; ==================================================================
SECTION .data
ik_initialized_data: db 0

; ==================================================================
; .text
; ==================================================================
SECTION .text

; ==================================================================
; er_input_kbd_init — initialize keyboard input agent
;
; Generates ephemeral 32-byte identity using RDTSC + Xorshift32.
; Registers with route table for identity-based routing.
; No sync handler — this agent is poll-based.
; ==================================================================
global er_input_kbd_init
er_fn er_input_kbd_init
    push    rbx
    push    r12
    push    r13

    ; Generate ephemeral identity (32 bytes)
    ; Xorshift32 seeded with RDTSC — not cryptographic, just sufficient
    ; for local collision resistance + cross-boot unlinkability.
    lea     r13, [rel ik_identity]
    rdtsc
    mov     ebx, eax          ; seed low
    mov     r12d, edx         ; seed high (mix-in)

    mov     ecx, 8            ; 8 iterations × 4 bytes = 32 bytes
.gen_loop:
    ; Xorshift32: x ^= x << 13; x ^= x >> 17; x ^= x << 5
    mov     eax, ebx
    shl     eax, 13
    xor     ebx, eax
    mov     eax, ebx
    shr     eax, 17
    xor     ebx, eax
    mov     eax, ebx
    shl     eax, 5
    xor     ebx, eax
    xor     ebx, r12d          ; mix in TSC high bits
    ror     r12d, 7
    mov     [r13], ebx
    add     r13, 4
    dec     ecx
    jnz     .gen_loop

    ; Register ephemeral identity with route table
    lea     rdi, [rel ik_identity]
    call    er_local_route_register
    test    edx, edx
    jnz     .done

.done:
    mov     byte [rel ik_initialized], 1
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_input_kbd_poll — poll keyboard, forward input to focused app
;
; Called from kernel main loop each iteration.
; Non-blocking — returns immediately if no scancode available
; or no app has focus.
; ==================================================================
global er_input_kbd_poll
er_fn er_input_kbd_poll
    push    rbx
    push    r12
    push    r13
    push    r14

    cmp     byte [rel ik_initialized], 0
    jz      .done

    ; Fast path: skip if no app has focus
    cmp     dword [rel da_focused_slot], -1
    je      .done

    ; Non-blocking scancode read
    call    er_i8042_read_scancode
    test    edx, edx
    jnz     .done

    mov     ebx, eax            ; bl = raw scancode
    mov     r12d, eax           ; preserve across calls

    ; Track modifier keys
    ; Left shift = 0x12, Right shift = 0x59
    mov     al, bl
    and     al, 0x7f
    cmp     al, 0x12
    je      .shift_key
    cmp     al, 0x59
    je      .shift_key

    ; Not a modifier — determine make or break
    test    bl, 0x80
    jnz     .key_up

.key_down:
    ; Translate scancode to ASCII
    mov     dil, bl
    movzx   esi, byte [rel ik_modifiers]
    and     esi, DA_MOD_SHIFT
    call    er_i8042_scancode_to_ascii
    mov     r13d, eax           ; r13b = ASCII char

    ; Build input cell in scratch buffer
    lea     r14, [rel ik_cell]
    xor     esi, esi
    mov     edx, LOCAL_CELL_SIZE
    mov     rdi, r14
    call    er_memset

    mov     byte [r14 + LOCAL_CELL_CMD], LOCAL_CELL_DATA
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 0], DA_MSG_INPUT_EVENT
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 1], DA_INPUT_KEY_DOWN
    mov     al, [rel ik_modifiers]
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 2], al
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 3], r12b
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 4], r13b

    mov     rdi, r14
    call    _ik_forward
    jmp     .done

.key_up:
    mov     dil, bl
    movzx   esi, byte [rel ik_modifiers]
    and     esi, DA_MOD_SHIFT
    call    er_i8042_scancode_to_ascii
    mov     r13d, eax

    lea     r14, [rel ik_cell]
    xor     esi, esi
    mov     edx, LOCAL_CELL_SIZE
    mov     rdi, r14
    call    er_memset

    mov     byte [r14 + LOCAL_CELL_CMD], LOCAL_CELL_DATA
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 0], DA_MSG_INPUT_EVENT
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 1], DA_INPUT_KEY_UP
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 2], 0
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 3], r12b
    mov     byte [r14 + LOCAL_CELL_PAYLOAD + 4], r13b

    mov     rdi, r14
    call    _ik_forward
    jmp     .done

.shift_key:
    test    bl, 0x80
    jnz     .shift_break
    or      byte [rel ik_modifiers], DA_MOD_SHIFT
    jmp     .done
.shift_break:
    and     byte [rel ik_modifiers], ~DA_MOD_SHIFT

.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ret

; ==================================================================
; _ik_forward — forward cell to focused app identity
;
; rdi = cell_ptr (already populated input cell)
; Reads da_focused_hash and lets the route layer choose local or remote delivery.
; ==================================================================
_ik_forward:
    push    r12

    mov     r12, rdi

    lea     rdi, [rel da_focused_hash]
    mov     rsi, r12
    call    er_local_cell_send

    pop     r12
    xor     eax, eax
    ret
