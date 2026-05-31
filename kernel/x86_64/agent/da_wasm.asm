; da_wasm.asm — WASM import wrappers for Display Agent surface operations
;
; Translates WASM import calls into cells sent to the DA's route slot.
; Caches the DA's slot_id and the calling app's identity hash on first use.
;
; Import API (struct-in-memory approach to work around 2-param WASM limit):
;   da_surface_register(params_ptr:i32) -> i32
;     params: [layer:4][flags:4][rect_data:4][rect_count:4] = 16 bytes
;     rect_data = WASM linear memory offset of [15*rect_count] f32 values
;
;   da_surface_update(params_ptr:i32) -> i32
;     params: [update_flags:4][rect_count:4][rect_data:4][icon_count:4][icon_data:4] = 20 bytes
;
;   da_surface_unregister(_:i32) -> i32

%include "x86_64/macros.inc"
%include "x86_64/agent/agent_constants.inc"
%include "x86_64/agent/da_constants.inc"
%include "x86_64/crypto/local_constants.inc"
%include "x86_64/wasm_defines.inc"

extern er_wasm_runtime_ptr
extern er_local_route_lookup
extern er_local_cell_send_to_slot
extern er_blake3_hash_bytes
extern er_memcpy

SECTION .bss
da_wasm_da_slot:   resd 1    ; cached DA route slot (-1 = uninit)
global da_wasm_app_hash
da_wasm_app_hash:  resb 32   ; cached app identity hash (BLAKE3)
global da_wasm_ready
da_wasm_ready:     resb 1    ; non-zero when caches are valid

SECTION .data
da_wasm_da_label:   db "edgerun.agent.da", 0
da_wasm_da_label_len: dq 16

SECTION .text

; ==================================================================
; _da_wasm_ensure_init — initialize caches if not already done
; Returns: eax = 0 on success, -1 on failure
; Clobbers: rdi, rsi, rdx, rax (callee-save everything else per ABI)
; Uses: 64 bytes of stack temp (two BLAKE3 hashes)
; ==================================================================
_da_wasm_ensure_init:
    cmp     byte [rel da_wasm_ready], 0
    jnz     .cached

    push    rbp
    push    rbx
    push    r12
    sub     rsp, 64              ; space for two 32-byte hashes

    ; Compute DA identity hash into rsp[0..31]
    lea     rdi, [rel da_wasm_da_label]
    mov     rsi, [rel da_wasm_da_label_len]
    mov     rdx, rsp
    call    er_blake3_hash_bytes
    test    rax, rax
    jz      .fail

    ; Look up DA route slot from hash
    mov     rdi, rsp
    call    er_local_route_lookup
    test    edx, edx
    jnz     .fail
    mov     [rel da_wasm_da_slot], eax

    ; App identity hash is provided by launcher from the loaded WASM bytes.
    ; Fail if unset (all zeros).
    lea     rdi, [rel da_wasm_app_hash]
    lea     rsi, [rsp + 32]
    mov     edx, 32
    call    er_memcpy
    lea     rdi, [rsp + 32]
    xor     esi, esi
    mov     ecx, 32
.check_app_hash_nonzero:
    movzx   eax, byte [rdi]
    or      esi, eax
    inc     rdi
    dec     ecx
    jnz     .check_app_hash_nonzero
    test    esi, esi
    jz      .fail

    mov     byte [rel da_wasm_ready], 1
    mov     eax, [rel da_wasm_da_slot]
    xor     edx, edx

    add     rsp, 64
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail:
    add     rsp, 64
    pop     r12
    pop     rbx
    pop     rbp
    mov     eax, -1
    er_err  ERROR_LOCAL_NOT_FOUND
    ret

.cached:
    mov     eax, [rel da_wasm_da_slot]
    xor     edx, edx
    ret

; ==================================================================
; _wasm_import_da_surface_register — register a surface with the DA
; rdi = params_ptr (WASM linear memory offset, i32)
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
global _wasm_import_da_surface_register
_wasm_import_da_surface_register:
    push    rbp
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbp, rsp
    sub     rsp, 256          ; cell buffer

    ; Initialize caches
    call    _da_wasm_ensure_init
    test    edx, edx
    jnz     .ret_with_eax

    ; Get WASM memory base pointer
    mov     rax, [rel er_wasm_runtime_ptr]
    test    rax, rax
    jz      .ret_fail
    mov     r14, [rax + RUNTIME_MEMORY_PTR_OFF]  ; r14 = memory base
    test    r14, r14
    jz      .ret_fail

    ; Read params struct from WASM memory
    ; params layout: layer(4), flags(4), rect_data(4), rect_count(4) = 16 bytes
    mov     r12d, edi         ; r12d = params offset (zero-extend)
    add     r12, r14          ; r12 = host pointer to params
    mov     r13d, [r12]       ; r13d = layer
    mov     ebx, [r12 + 4]    ; ebx = flags
    mov     ecx, [r12 + 8]    ; ecx = rect_data offset (WASM)
    mov     r8d, [r12 + 12]   ; r8d = rect_count

    ; Build register cell on stack (at rbp - 256 = rsp)
    mov     rdi, rbp
    sub     rdi, 256          ; rdi = cell buffer

    ; [0] type = DA_MSG_SURFACE_REGISTER (1)
    mov     byte [rdi + LOCAL_CELL_PAYLOAD + 0], DA_MSG_SURFACE_REGISTER
    ; [1] layer
    mov     [rdi + LOCAL_CELL_PAYLOAD + 1], r13b
    ; [2] flags
    mov     [rdi + LOCAL_CELL_PAYLOAD + 2], bl
    ; [3-4] rect_count (LE u16)
    mov     [rdi + LOCAL_CELL_PAYLOAD + 3], r8w

    ; [5-36] app hash (32 bytes)
    lea     rsi, [rel da_wasm_app_hash]
    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 5]
    mov     edx, 32
    call    er_memcpy

    ; If rect_count > 0, copy rect data from WASM memory
    test    r8d, r8d
    jz      .send

    ; Clamp rect_count: max 3 rects fit in cell after header
    ; Header = type(1) + layer(1) + flags(1) + rect_count(2) + hash(32) = 37
    ; Max rects = (251 - 37) / 60 = 3
    cmp     r8d, 3
    jbe     .rect_count_ok_register
    mov     r8d, 3
.rect_count_ok_register:

    mov     eax, r8d
    imul    eax, 60           ; rect data bytes
    mov     edx, eax

    mov     rdi, rbp
    sub     rdi, 256
    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 37]  ; dst in cell

    mov     esi, ecx          ; WASM offset of rect data
    add     rsi, r14          ; host pointer
    call    er_memcpy

.send:
    ; Send cell to DA route slot
    mov     rdi, rbp
    sub     rdi, 256
    mov     rsi, rdi          ; rsi = cell_ptr
    mov     edi, [rel da_wasm_da_slot]
    call    er_local_cell_send_to_slot
    test    edx, edx
    jnz     .ret_fail

    xor     eax, eax
    jmp     .done

.ret_with_eax:
    ; eax already contains the error code from _da_wasm_ensure_init
    jmp     .done

.ret_fail:
    mov     eax, -1
.done:
    mov     rsp, rbp
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; _wasm_import_da_surface_update — update a registered surface's data
; rdi = params_ptr (WASM linear memory offset, i32)
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
global _wasm_import_da_surface_update
_wasm_import_da_surface_update:
    push    rbp
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbp, rsp
    sub     rsp, 256

    call    _da_wasm_ensure_init
    test    edx, edx
    jnz     .ret_fail

    mov     rax, [rel er_wasm_runtime_ptr]
    test    rax, rax
    jz      .ret_fail
    mov     r14, [rax + RUNTIME_MEMORY_PTR_OFF]
    test    r14, r14
    jz      .ret_fail

    ; Read params struct from WASM memory
    ; params layout: update_flags(4), rect_count(4), rect_data(4), icon_count(4), icon_data(4)
    mov     r12d, edi
    add     r12, r14
    mov     r13d, [r12]        ; r13d = update_flags
    mov     ebx, [r12 + 4]     ; ebx = rect_count
    mov     ecx, [r12 + 8]     ; ecx = rect_data offset
    mov     r8d, [r12 + 12]    ; r8d = icon_count
    mov     r9d, [r12 + 16]    ; r9d = icon_data offset

    ; Build update cell
    mov     rdi, rbp
    sub     rdi, 256

    ; [0] type = DA_MSG_SURFACE_UPDATE (2)
    mov     byte [rdi + LOCAL_CELL_PAYLOAD + 0], DA_MSG_SURFACE_UPDATE
    ; [1] update_flags
    mov     [rdi + LOCAL_CELL_PAYLOAD + 1], r13b
    ; [2-33] app hash (32 bytes)
    lea     rsi, [rel da_wasm_app_hash]
    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 2]
    mov     edx, 32
    call    er_memcpy

    ; [34-35] rect_count
    mov     rdi, rbp
    sub     rdi, 256
    mov     [rdi + LOCAL_CELL_PAYLOAD + 34], bx
    ; [36-37] icon_count
    mov     [rdi + LOCAL_CELL_PAYLOAD + 36], r8w
    ; [38-39] reserved
    mov     word [rdi + LOCAL_CELL_PAYLOAD + 38], 0

    ; Clamp rect_count to fit payload budget.
    ; Header = 40 bytes, payload max = 251 bytes, rect = 60 bytes.
    test    ebx, ebx
    jz      .rect_done

    cmp     ebx, 3
    jbe     .rect_count_prelim_ok
    mov     ebx, 3
.rect_count_prelim_ok:
    mov     eax, ebx
    imul    eax, 60
    cmp     eax, 211               ; 251 - 40
    jbe     .rect_count_ok_update
    mov     ebx, 3                 ; defensive
.rect_count_ok_update:
    mov     [rdi + LOCAL_CELL_PAYLOAD + 34], bx

    mov     eax, ebx
    imul    eax, 60
    mov     edx, eax
    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 40]
    mov     esi, ecx
    add     rsi, r14
    call    er_memcpy
.rect_done:

    ; Clamp and copy icon payload after rect bytes.
    test    r8d, r8d
    jz      .send

    mov     eax, ebx
    imul    eax, 60
    mov     r10d, eax                 ; rect_bytes
    mov     r11d, 211
    sub     r11d, r10d                ; remaining bytes
    jle     .icons_zero
    mov     eax, r11d
    xor     edx, edx
    mov     ecx, 36
    div     ecx
    cmp     r8d, eax
    jbe     .icon_count_ok
    mov     r8d, eax
.icon_count_ok:
    mov     rdi, rbp
    sub     rdi, 256
    mov     [rdi + LOCAL_CELL_PAYLOAD + 36], r8w

    test    r8d, r8d
    jz      .send
    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 40]
    add     rdi, r10
    mov     esi, r9d
    add     rsi, r14
    mov     eax, r8d
    imul    eax, 36
    mov     edx, eax
    call    er_memcpy
    jmp     .send

.icons_zero:
    mov     rdi, rbp
    sub     rdi, 256
    mov     word [rdi + LOCAL_CELL_PAYLOAD + 36], 0

.send:
    mov     rdi, rbp
    sub     rdi, 256
    mov     rsi, rdi
    mov     edi, [rel da_wasm_da_slot]
    call    er_local_cell_send_to_slot
    test    edx, edx
    jnz     .ret_fail

    xor     eax, eax
    jmp     .done

.ret_fail:
    mov     eax, -1
.done:
    mov     rsp, rbp
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; _wasm_import_da_surface_unregister — unregister a surface
; rdi = _unused: i32
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
global _wasm_import_da_surface_unregister
_wasm_import_da_surface_unregister:
    push    rbp
    push    rbx
    push    r12
    mov     rbp, rsp
    sub     rsp, 256

    call    _da_wasm_ensure_init
    test    edx, edx
    jnz     .ret_fail

    mov     rdi, rbp
    sub     rdi, 256

    ; [0] type = DA_MSG_SURFACE_UNREGISTER (3)
    mov     byte [rdi + LOCAL_CELL_PAYLOAD + 0], DA_MSG_SURFACE_UNREGISTER
    ; [1-4] padding (unused)
    ; [5-36] app hash (32 bytes)
    lea     rsi, [rel da_wasm_app_hash]
    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 5]
    mov     edx, 32
    call    er_memcpy

    mov     rdi, rbp
    sub     rdi, 256
    mov     rsi, rdi
    mov     edi, [rel da_wasm_da_slot]
    call    er_local_cell_send_to_slot
    test    edx, edx
    jnz     .ret_fail

    xor     eax, eax
    jmp     .done

.ret_fail:
    mov     eax, -1
.done:
    mov     rsp, rbp
    pop     r12
    pop     rbx
    pop     rbp
    ret
