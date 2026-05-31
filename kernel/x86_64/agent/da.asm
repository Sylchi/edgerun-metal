; da.asm — EdgeRun Display Agent (DA)
;
; Kernel-side compositor and display manager.
; Registers as identity "edgerun.agent.da".
;
; On each frame tick, composites registered surfaces in layer order
; (scrim → menu → popover → modal → toast), renders to framebuffer.
;
; Phase 1: Hardcoded test surfaces verify the rendering pipeline.
; Phase 2+: Cell-based surface registration from WASM apps.

%include "x86_64/macros.inc"
%include "x86_64/ui/ui_constants.inc"
%include "x86_64/agent/agent_constants.inc"
%include "x86_64/agent/da_constants.inc"
%include "x86_64/crypto/local_constants.inc"
%include "x86_64/wasm_defines.inc"

extern er_local_route_register
extern er_local_route_set_handler
extern er_blake3_hash_bytes
extern er_memcpy
extern er_memset
extern er_memcmp
extern er_fn_run
extern er_fn_load
extern er_fn_call
extern da_wasm_app_hash
extern da_wasm_ready
extern er_local_cell_imports
extern er_local_cell_import_count

; Framebuffer info from fb_text.asm
extern fb_addr, fb_width, fb_height, fb_pitch

; Software renderers from render_ir.asm
extern sw_fb_render_ir_rects
extern sw_fb_render_ir_icons
extern sw_fb_fill

; ==================================================================
; BSS
; ==================================================================
SECTION .bss

da_fb_addr:     resq 1
da_fb_width:    resd 1
da_fb_height:   resd 1

; Composite output buffers
da_composite_rect_buf:  resd DA_COMPOSITE_MAX_RECTS * 15
da_composite_rect_len:  resq 1
da_composite_icon_buf:  resd DA_COMPOSITE_MAX_ICONS * 9
da_composite_icon_len:  resq 1

; Surface registry
da_surface_registry: resb DA_MAX_SURFACES * DA_SURFACE_SIZE
da_surface_count:    resd 1

; App registry — tracks launched apps by identity
da_app_registry: resb DA_MAX_APPS * DA_APP_SIZE
da_app_count:    resd 1

; DA's WASM runtime (for launching apps)
da_wasm_memory:  resb 65536
da_wasm_ticks:   resq 1
da_wasm_runtime: resb RUNTIME_SIZE

; Per-surface rect/icon storage pools (DA_MAX_SURFACES entries each)
; Each surface's rect/icon pool is at [pool_base + slot_idx * entry_size].
; Rect pool entry: 32 rects * 15 floats * 4 bytes = 1920 bytes
; Icon pool entry: 16 icons * 9 floats * 4 bytes = 576 bytes
da_surface_rect_pool: resd DA_MAX_SURFACES * DA_SURFACE_POOL_RECTS * 15
da_surface_icon_pool: resd DA_MAX_SURFACES * DA_SURFACE_POOL_ICONS * 9

; Focus tracking — input_kbd.asm reads these directly (same address space)
global da_focused_slot
global da_focused_hash
da_focused_slot:   resd 1   ; surface slot index, -1 = none
da_focused_hash:   resb 32  ; 32-byte identity hash of focused app (zero if none)

; Persistent app state (for WASM event loop)
da_app_loaded:     resb 1   ; non-zero when a persistent app is loaded
da_app_export:     resb 64  ; export name buffer
da_app_export_len: resb 1   ; length of export name

; ==================================================================
; .data
; ==================================================================
SECTION .data
da_initialized: db 0

da_label: db "edgerun.agent.da", 0

da_layer_order: db DA_LAYER_SCRIM, DA_LAYER_MENU, DA_LAYER_POPOVER
                db DA_LAYER_MODAL, DA_LAYER_TOAST

; ==================================================================
; .rodata — shell surface data
; ==================================================================
SECTION .rodata

; Shell background: full-screen dark fill (1 rect, scrim layer)
shell_bg_rects:
    dd 0.0, 0.0, 1024.0, 768.0
    dd 0.0, 0.0
    dd 0.0431, 0.0431, 0.0431, 1.0
    dd 0.0, 0.0, 0.0, 0.0
    dd 0.0
shell_bg_rects_end:
shell_bg_count: dq (shell_bg_rects_end - shell_bg_rects) / 60

; Shell status bar: bottom bar + accent line (2 rects, toast layer)
shell_bar_rects:
    ; Bar background
    dd 0.0, 724.0, 1024.0, 44.0
    dd 0.0, 0.0
    dd 0.0745, 0.0784, 0.0863, 1.0
    dd 0.0, 0.0, 0.0, 0.0
    dd 1.0
    ; Accent line at top of bar
    dd 0.0, 724.0, 1024.0, 2.0
    dd 0.0, 0.0
    dd 0.2902, 0.8706, 0.5020, 1.0
    dd 0.0, 0.0, 0.0, 0.0
    dd 0.0
shell_bar_rects_end:
shell_bar_count: dq (shell_bar_rects_end - shell_bar_rects) / 60

; DA message dispatch table: [msg_type:1][pad:7][handler_ptr:8]
da_msg_dispatch_table:
    db DA_MSG_SURFACE_REGISTER, 0, 0, 0, 0, 0, 0, 0
    dd _da_dispatch_register
    dd 0
    db DA_MSG_SURFACE_UPDATE, 0, 0, 0, 0, 0, 0, 0
    dd _da_dispatch_update
    dd 0
    db DA_MSG_SURFACE_UNREGISTER, 0, 0, 0, 0, 0, 0, 0
    dd _da_dispatch_unregister
    dd 0
    db DA_MSG_LAUNCH_APP, 0, 0, 0, 0, 0, 0, 0
    dd _da_dispatch_launch
    dd 0
    db DA_MSG_APP_EXIT, 0, 0, 0, 0, 0, 0, 0
    dd _da_dispatch_exit
    dd 0
    db DA_MSG_SURFACE_FOCUS, 0, 0, 0, 0, 0, 0, 0
    dd _da_dispatch_focus
    dd 0
da_msg_dispatch_table_end:
da_msg_dispatch_count: dq (da_msg_dispatch_table_end - da_msg_dispatch_table) / 16

; ==================================================================
; .text
; ==================================================================
SECTION .text

%macro da_pool_append_from_payload 7
    ; %1=len_off %2=ptr_off %3=cap_off %4=pool_sym %5=pool_cap %6=item_bytes %7=payload_src_off
    mov     r8d, [r15 + %1]            ; current_len
    mov     edx, %5
    sub     edx, r8d                   ; available
    jle     %%done
    cmp     ecx, edx
    cmova   ecx, edx

    mov     eax, r14d
    imul    eax, %5 * %6               ; per-surface bytes
    mov     edx, r8d
    imul    edx, %6
    add     eax, edx
    lea     rdi, [rel %4 + rax]

    lea     rsi, [r12 + LOCAL_CELL_PAYLOAD + %7]
    mov     r11d, ecx
    mov     eax, ecx
    imul    eax, %6
    mov     edx, eax
    call    er_memcpy

    mov     eax, [r15 + %1]
    add     eax, r11d
    mov     [r15 + %1], eax

    mov     eax, r14d
    imul    eax, %5 * %6
    lea     rax, [rel %4 + rax]
    mov     [r15 + %2], rax

    cmp     qword [r15 + %3], 0
    jnz     %%done
    mov     qword [r15 + %3], %5
%%done:
%endmacro

; ==================================================================
; er_da_init
; ==================================================================
er_fn er_da_init
    push    rbx
    push    r12
    sub     rsp, 32

    mov     rax, [rel fb_addr]
    mov     [rel da_fb_addr], rax
    mov     eax, [rel fb_width]
    mov     [rel da_fb_width], eax
    mov     eax, [rel fb_height]
    mov     [rel da_fb_height], eax

    ; Register DA identity
    lea     rdi, [rel da_label]
    mov     esi, DA_LABEL_LEN
    mov     rdx, rsp
    call    er_blake3_hash_bytes
    test    rax, rax
    jz      .init_skip_route

    mov     rdi, rsp
    call    er_local_route_register
    test    edx, edx
    jnz     .init_skip_route

    mov     r12d, eax
    mov     edi, r12d
    lea     rsi, [rel _da_handler]
    mov     dl, AGENT_FLAG_SYNC
    call    er_local_route_set_handler

.init_skip_route:
    mov     dword [rel da_focused_slot], -1
    ; Zero out focused_hash (no app has focus yet)
    lea     rdi, [rel da_focused_hash]
    xor     esi, esi
    mov     edx, 32
    call    er_memset
    call    er_da_inject_shell_surfaces
    mov     byte [rel da_initialized], 1

    add     rsp, 32
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; _da_handler — cell message dispatch for compositor
; rdi = cell_ptr, rsi = sender_slot_id
; ==================================================================
_da_handler:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi            ; cell_ptr
    mov     r13d, esi           ; sender_slot_id

    movzx   ebx, byte [r12 + LOCAL_CELL_PAYLOAD]
    lea     rax, [rel da_msg_dispatch_table]
    mov     rcx, [rel da_msg_dispatch_count]

.dispatch_loop:
    test    rcx, rcx
    jz      .unknown
    cmp     bl, byte [rax]
    je      .dispatch_hit
    add     rax, 16
    dec     rcx
    jmp     .dispatch_loop

.dispatch_hit:
    mov     rdi, r12
    mov     esi, r13d
    mov     eax, dword [rax + 8]
    call    rax
    jmp     .done

.unknown:
    er_ok

.done:
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; Dispatcher wrappers (uniform signature: rdi=cell_ptr, rsi=sender_slot_id)
_da_dispatch_register:
    call    _da_register_surface
    ret

_da_dispatch_update:
    call    _da_update_surface
    er_ok
    ret

_da_dispatch_unregister:
    call    _da_unregister_surface
    er_ok
    ret

_da_dispatch_launch:
    call    _da_launch_app
    ret

_da_dispatch_exit:
    call    _da_app_exit
    er_ok
    ret

_da_dispatch_focus:
    call    _da_focus_surface
    er_ok
    ret

; ==================================================================
; _da_find_surface_by_hash — find surface slot by app hash
; rdi = hash_ptr (32 bytes)
; returns eax = slot_index, edx = ERROR_LOCAL_NOT_FOUND if none
; ==================================================================
_da_find_surface_by_hash:
    push    rbx
    push    r12
    mov     r12, rdi
    xor     ebx, ebx
.loop:
    cmp     ebx, [rel da_surface_count]
    jae     .not_found
    mov     eax, ebx
    imul    eax, DA_SURFACE_SIZE
    lea     rdi, [rel da_surface_registry + rax + DA_SURFACE_HASH]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcmp
    test    eax, eax
    jz      .found
    inc     ebx
    jmp     .loop
.found:
    mov     eax, ebx
    er_ok
    pop     r12
    pop     rbx
    ret
.not_found:
    xor     eax, eax
    er_err  ERROR_LOCAL_NOT_FOUND
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _da_surface_ptr_by_slot
; edi = slot_index
; returns rax = &da_surface_registry[slot]
; ==================================================================
_da_surface_ptr_by_slot:
    mov     eax, edi
    imul    eax, DA_SURFACE_SIZE
    lea     rax, [rel da_surface_registry + rax]
    ret

; ==================================================================
; _da_focus_clear_state
; Clears focused slot + focused hash
; ==================================================================
_da_focus_clear_state:
    mov     dword [rel da_focused_slot], -1
    lea     rdi, [rel da_focused_hash]
    xor     esi, esi
    mov     edx, 32
    call    er_memset
    ret

; ==================================================================
; _da_focus_clear_all_flags
; Clears DA_SURFACE_FOCUSED on all registered surfaces.
; ==================================================================
_da_focus_clear_all_flags:
    push    rbx
    xor     ebx, ebx
.loop:
    cmp     ebx, [rel da_surface_count]
    jae     .done
    mov     edi, ebx
    call    _da_surface_ptr_by_slot
    and     byte [rax + DA_SURFACE_FLAGS], ~DA_SURFACE_FOCUSED
    inc     ebx
    jmp     .loop
.done:
    pop     rbx
    ret

; ==================================================================
; _da_focus_assign_slot
; edi = slot_index
; Sets focused slot, focused flag, and focused hash.
; ==================================================================
_da_focus_assign_slot:
    mov     [rel da_focused_slot], edi
    call    _da_surface_ptr_by_slot
    or      byte [rax + DA_SURFACE_FLAGS], DA_SURFACE_FOCUSED
    lea     rdi, [rel da_focused_hash]
    lea     rsi, [rax + DA_SURFACE_HASH]
    mov     edx, 32
    call    er_memcpy
    ret

; ==================================================================
; _da_register_surface — register a surface from cell payload
; rdi = cell_ptr, esi = sender_slot_id
; Cell payload: [type:1][layer:1][flags:1][rect_count:2][hash:32][rect_data...]
; ==================================================================
_da_register_surface:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13d, esi

    ; Extract sender identity hash from cell circ_id field
    lea     rsi, [r12 + LOCAL_CELL_PAYLOAD + 5]  ; hash starts at offset 5 in payload
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 5]  ; use it directly

    ; Check if this hash already has a surface
    mov     rdi, rsi
    call    _da_find_surface_by_hash
    test    edx, edx
    jz      .update_existing

    ; Find free slot or allocate new
    mov     ebx, [rel da_surface_count]
    cmp     ebx, DA_MAX_SURFACES
    jae     .fail

    mov     r13d, ebx           ; save slot_index for pool calc
    mov     eax, ebx
    imul    eax, DA_SURFACE_SIZE
    lea     rbx, [rel da_surface_registry + rax]

    ; Zero the slot
    mov     rdi, rbx
    xor     esi, esi
    mov     edx, DA_SURFACE_SIZE
    call    er_memset

    ; Copy app identity hash
    lea     rdi, [rbx + DA_SURFACE_HASH]
    lea     rsi, [r12 + LOCAL_CELL_PAYLOAD + 5]
    mov     edx, 32
    call    er_memcpy

    ; Set layer from cell payload byte 1
    mov     al, [r12 + LOCAL_CELL_PAYLOAD + 1]
    mov     [rbx + DA_SURFACE_LAYER], al

    ; Set flags from cell payload byte 2
    mov     al, [r12 + LOCAL_CELL_PAYLOAD + 2]
    mov     [rbx + DA_SURFACE_FLAGS], al

    ; Point to surface's pool slot for rects and icons
    mov     eax, r13d
    imul    eax, DA_SURFACE_POOL_RECTS * 15 * 4   ; byte offset into rect pool
    lea     rax, [rel da_surface_rect_pool + rax]
    mov     [rbx + DA_SURFACE_RECT_PTR], rax
    mov     qword [rbx + DA_SURFACE_RECT_LEN], 0
    mov     qword [rbx + DA_SURFACE_RECT_CAP], DA_SURFACE_POOL_RECTS

    mov     eax, r13d
    imul    eax, DA_SURFACE_POOL_ICONS * 9 * 4    ; byte offset into icon pool
    lea     rax, [rel da_surface_icon_pool + rax]
    mov     [rbx + DA_SURFACE_ICON_PTR], rax
    mov     qword [rbx + DA_SURFACE_ICON_LEN], 0
    mov     qword [rbx + DA_SURFACE_ICON_CAP], DA_SURFACE_POOL_ICONS

    ; Auto-focus if no surface has focus and this is a non-shell surface
    cmp     dword [rel da_focused_slot], -1
    jne     .no_autofocus
    movzx   ecx, byte [rbx + DA_SURFACE_LAYER]
    cmp     cl, DA_LAYER_SCRIM
    je      .no_autofocus
    cmp     cl, DA_LAYER_TOAST
    je      .no_autofocus
    mov     edi, r13d
    call    _da_focus_assign_slot
.no_autofocus:

    inc     dword [rel da_surface_count]
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.update_existing:
    ; Surface already exists — update flags/layer
    mov     eax, eax
    imul    eax, DA_SURFACE_SIZE
    lea     rbx, [rel da_surface_registry + rax]

    mov     al, [r12 + LOCAL_CELL_PAYLOAD + 1]
    mov     [rbx + DA_SURFACE_LAYER], al
    mov     al, [r12 + LOCAL_CELL_PAYLOAD + 2]
    mov     [rbx + DA_SURFACE_FLAGS], al

    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.fail:
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, -1
    er_err  ERROR_LOCAL_FULL
    ret

; ==================================================================
; _da_unregister_surface — remove a surface by hash from cell
; rdi = cell_ptr
; ==================================================================
_da_unregister_surface:
    push    rbx
    push    r12
    push    r13
    push    r14

    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 5]
    call    _da_find_surface_by_hash
    test    edx, edx
    jnz     .done

    mov     r13d, eax                          ; removed slot
    mov     r14d, [rel da_surface_count]
    dec     r14d                               ; last occupied slot
    mov     r12d, [rel da_focused_slot]        ; focused slot before mutation

    ; If removed slot is not last, move last slot into removed slot.
    cmp     r13d, r14d
    je      .clear_removed

    ; Copy surface entry bytes: dst=removed, src=last
    mov     edi, r13d
    call    _da_surface_ptr_by_slot
    mov     rbx, rax                           ; dst surface entry
    mov     edi, r14d
    call    _da_surface_ptr_by_slot
    mov     rsi, rax                           ; src surface entry
    mov     rdi, rbx
    mov     edx, DA_SURFACE_SIZE
    call    er_memcpy

    ; Copy rect pool bytes for moved slot
    mov     eax, r13d
    imul    eax, DA_SURFACE_POOL_RECTS * 15 * 4
    lea     rdi, [rel da_surface_rect_pool + rax]
    mov     eax, r14d
    imul    eax, DA_SURFACE_POOL_RECTS * 15 * 4
    lea     rsi, [rel da_surface_rect_pool + rax]
    mov     edx, DA_SURFACE_POOL_RECTS * 15 * 4
    call    er_memcpy

    ; Copy icon pool bytes for moved slot
    mov     eax, r13d
    imul    eax, DA_SURFACE_POOL_ICONS * 9 * 4
    lea     rdi, [rel da_surface_icon_pool + rax]
    mov     eax, r14d
    imul    eax, DA_SURFACE_POOL_ICONS * 9 * 4
    lea     rsi, [rel da_surface_icon_pool + rax]
    mov     edx, DA_SURFACE_POOL_ICONS * 9 * 4
    call    er_memcpy

    ; Rebind moved entry's pool pointers to the new slot pools.
    mov     eax, r13d
    imul    eax, DA_SURFACE_POOL_RECTS * 15 * 4
    lea     rdx, [rel da_surface_rect_pool + rax]
    mov     [rbx + DA_SURFACE_RECT_PTR], rdx
    mov     eax, r13d
    imul    eax, DA_SURFACE_POOL_ICONS * 9 * 4
    lea     rdx, [rel da_surface_icon_pool + rax]
    mov     [rbx + DA_SURFACE_ICON_PTR], rdx

    ; If focus pointed at the moved last slot, remap to removed slot.
    cmp     r12d, r14d
    jne     .clear_removed
    mov     dword [rel da_focused_slot], r13d

 .clear_removed:
    ; Clear old last slot entry.
    mov     edi, r14d
    call    _da_surface_ptr_by_slot
    mov     rdi, rax
    xor     esi, esi
    mov     edx, DA_SURFACE_SIZE
    call    er_memset

    ; If removed slot was focused (and not remapped above), clear focus.
    cmp     r12d, r13d
    jne     .no_focus_clear
    call    _da_focus_clear_state
.no_focus_clear:

    dec     dword [rel da_surface_count]

.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

; ==================================================================
; _da_update_surface — update a registered surface's rect/icon data
; rdi = cell_ptr, esi = sender_slot_id
; Cell payload:
;   [0] type=2 (DA_MSG_SURFACE_UPDATE, already consumed by handler)
;   [1] update_flags (DA_UPDATE_* bitmask)
;   [2] 32-byte app identity hash
;   [34] rect_count (u16 LE)
;   [36] N*60 bytes of rect data (up to 3 rects = 180 bytes)
; ==================================================================
_da_update_surface:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi                 ; cell_ptr
    mov     r13d, esi                ; sender_slot_id (unused)

    ; Find surface by identity hash at payload[2..33]
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 2]
    call    _da_find_surface_by_hash
    test    edx, edx
    jnz     .us_return              ; not found — return error

    mov     r14d, eax               ; r14d = slot_index
    mov     eax, r14d
    imul    eax, DA_SURFACE_SIZE
    lea     r15, [rel da_surface_registry + rax]  ; r15 = surface entry

    movzx   ebx, byte [r12 + LOCAL_CELL_PAYLOAD + 1]  ; bl = update_flags

    ; ── Handle rect updates ──
    test    bl, DA_UPDATE_CLEAR_RECTS
    jz      .us_check_replace_rects
    mov     qword [r15 + DA_SURFACE_RECT_LEN], 0
    jmp     .us_check_icons

.us_check_replace_rects:
    test    bl, DA_UPDATE_REPLACE_RECTS
    jz      .us_check_append_rects
    mov     qword [r15 + DA_SURFACE_RECT_LEN], 0
    ; fall through to append

.us_check_append_rects:
    test    bl, DA_UPDATE_APPEND_RECTS | DA_UPDATE_REPLACE_RECTS
    jz      .us_check_icons          ; no rect changes

    ; Read rect_count from payload[34..35]
    movzx   ecx, word [r12 + LOCAL_CELL_PAYLOAD + 34]
    test    ecx, ecx
    jz      .us_check_icons          ; no rects to copy

    da_pool_append_from_payload DA_SURFACE_RECT_LEN, DA_SURFACE_RECT_PTR, DA_SURFACE_RECT_CAP, da_surface_rect_pool, DA_SURFACE_POOL_RECTS, (15 * 4), 36

.us_check_icons:
    ; ── Handle icon updates (same pattern, reserved for future) ──
    test    bl, DA_UPDATE_CLEAR_ICONS
    jz      .us_check_replace_icons
    mov     qword [r15 + DA_SURFACE_ICON_LEN], 0
    jmp     .us_done

.us_check_replace_icons:
    test    bl, DA_UPDATE_REPLACE_ICONS
    jz      .us_check_append_icons
    mov     qword [r15 + DA_SURFACE_ICON_LEN], 0

.us_check_append_icons:
    test    bl, DA_UPDATE_APPEND_ICONS | DA_UPDATE_REPLACE_ICONS
    jz      .us_done

    movzx   ecx, word [r12 + LOCAL_CELL_PAYLOAD + 34]
    test    ecx, ecx
    jz      .us_done

    da_pool_append_from_payload DA_SURFACE_ICON_LEN, DA_SURFACE_ICON_PTR, DA_SURFACE_ICON_CAP, da_surface_icon_pool, DA_SURFACE_POOL_ICONS, (9 * 4), 36

.us_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.us_return:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_err  ERROR_LOCAL_NOT_FOUND
    ret

; ==================================================================
; _da_store_export_name
; rdi = export_name_ptr, rsi = export_name_len
; ==================================================================
_da_store_export_name:
    mov     [rel da_app_export_len], sil
    test    rsi, rsi
    jz      .done
    cmp     rsi, 64
    ja      .done
    push    rdx
    lea     rdi, [rel da_app_export]
    mov     rdx, rsi
    call    er_memcpy
    pop     rdx
.done:
    ret

; ==================================================================
; _da_prepare_wasm_runtime
; Returns rax = &da_wasm_runtime
; ==================================================================
_da_prepare_wasm_runtime:
    lea     rax, [rel da_wasm_runtime]
    lea     rdx, [rel da_wasm_memory]
    mov     [rax + RUNTIME_MEMORY_PTR_OFF], rdx
    mov     qword [rax + RUNTIME_MEMORY_LEN_OFF], 65536
    lea     rdx, [rel da_wasm_ticks]
    mov     [rax + RUNTIME_TICKS_PTR_OFF], rdx
    xor     edx, edx
    mov     [rax + RUNTIME_MEM_GROW_FN_OFF], rdx
    mov     [rax + RUNTIME_MEM_GROW_CTX_OFF], rdx
    mov     [rax + RUNTIME_TABLE_GROW_FN_OFF], rdx
    mov     [rax + RUNTIME_TABLE_GROW_CTX_OFF], rdx
    mov     [rax + RUNTIME_INITIAL_PAGES_OFF], rdx
    mov     byte [rax + RUNTIME_HAS_PAGES_OFF], 0
    lea     rdx, [rel er_local_cell_imports]
    mov     [rax + RUNTIME_IMPORTS_PTR_OFF], rdx
    mov     rdx, [rel er_local_cell_import_count]
    mov     [rax + RUNTIME_IMPORTS_LEN_OFF], rdx

    lea     rdi, [rel da_wasm_memory]
    xor     esi, esi
    mov     edx, 65536
    call    er_memset
    mov     qword [rel da_wasm_ticks], 0
    ret

; ==================================================================
; _da_publish_app_hash
; rdi = app_hash_ptr (32 bytes)
; ==================================================================
_da_publish_app_hash:
    mov     rsi, rdi
    lea     rdi, [rel da_wasm_app_hash]
    mov     edx, 32
    call    er_memcpy
    mov     byte [rel da_wasm_ready], 0
    ret

; ==================================================================
; _da_launch_common — shared launch core
; rdi = wasm_bytes_ptr
; rsi = wasm_bytes_len
; rdx = export_name_ptr
; rcx = export_name_len
; r8d = app_slot (sender slot or -1)
; Returns: rdx = error code (0 on success)
; ==================================================================
_da_launch_common:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx

    mov     ebx, [rel da_app_count]
    cmp     ebx, DA_MAX_APPS
    jae     .full

    mov     eax, ebx
    imul    eax, DA_APP_SIZE
    lea     r9, [rel da_app_registry + rax]

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [r9 + DA_APP_HASH]
    call    er_blake3_hash_bytes
    test    rax, rax
    jz      .hash_fail

    mov     [r9 + DA_APP_SLOT], r8d
    mov     byte [r9 + DA_APP_STATE], 1

    call    _da_prepare_wasm_runtime
    mov     rbx, rax

    mov     rdi, r14
    mov     rsi, r15
    call    _da_store_export_name

    lea     rdi, [r9 + DA_APP_HASH]
    call    _da_publish_app_hash

    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r13
    call    er_fn_load
    test    edx, edx
    jnz     .load_fail

    mov     byte [rel da_app_loaded], 1
    inc     dword [rel da_app_count]
    er_ok
    jmp     .done

.full:
    er_err  ERROR_LOCAL_FULL
    jmp     .done

.hash_fail:
    er_err  ERROR_CORRUPT
    jmp     .done

.load_fail:
    mov     byte [r9 + DA_APP_STATE], 0

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _da_launch_app — launch a WASM app from cell payload
; rdi = cell_ptr, esi = sender_slot_id
; Cell payload: [type:1][wasm_len:4][export_len:1][export_name...][wasm_bytes...]
; ==================================================================
_da_launch_app:
    push    rbx
    push    r12
    mov     r12, rdi
    mov     ebx, esi

    movzx   ecx, byte [r12 + LOCAL_CELL_PAYLOAD + 5] ; export_name_len
    lea     rdx, [r12 + LOCAL_CELL_PAYLOAD + 6]      ; export_name_ptr
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 6]      ; base for wasm_ptr
    add     rdi, rcx
    mov     esi, [r12 + LOCAL_CELL_PAYLOAD + 1]      ; wasm_len
    mov     r8d, ebx                                 ; app_slot=sender_slot
    call    _da_launch_common

    pop     r12
    pop     rbx
    ret

; ==================================================================
; _da_app_exit — mark an app as exited
; rdi = cell_ptr
; ==================================================================
_da_app_exit:
    push    rbx

    mov     ebx, [rel da_app_count]
    test    ebx, ebx
    jz      .done

    dec     ebx
    mov     eax, ebx
    imul    eax, DA_APP_SIZE
    lea     rbx, [rel da_app_registry + rax]
    mov     byte [rbx + DA_APP_STATE], 2
    ; Clear persistent app state
    mov     byte [rel da_app_loaded], 0

.done:
    pop     rbx
    xor     eax, eax
    er_ok
    ret

; ==================================================================
; _da_focus_surface — set the focused surface by identity hash
; rdi = cell_ptr
; Cell payload: [type=4][hash:32]
; ==================================================================
_da_focus_surface:
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi

    ; Find surface by hash at payload[1..32]
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 1]
    call    _da_find_surface_by_hash
    test    edx, edx
    jnz     .done

    mov     r13d, eax               ; new focus slot

    call    _da_focus_clear_all_flags
    mov     edi, r13d
    call    _da_focus_assign_slot

.done:
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

; ==================================================================
; er_da_launch_app — public API: launch a WASM module
; rdi = wasm_bytes_ptr, rsi = wasm_bytes_len, rdx = export_name_ptr
; rcx = export_name_len
; ==================================================================
global er_da_launch_app
er_fn er_da_launch_app
    mov     r8d, -1
    call    _da_launch_common
    er_ret

; ==================================================================
; er_da_inject_shell_surfaces — set up shell compositor surfaces
; ==================================================================
er_fn er_da_inject_shell_surfaces
    push    rbx

    ; Surface 0: shell background (scrim)
    lea     rbx, [rel da_surface_registry]
    mov     byte [rbx + DA_SURFACE_LAYER], DA_LAYER_SCRIM
    mov     byte [rbx + DA_SURFACE_FLAGS], DA_SURFACE_VISIBLE
    lea     rax, [rel shell_bg_rects]
    mov     [rbx + DA_SURFACE_RECT_PTR], rax
    mov     rax, [rel shell_bg_count]
    mov     [rbx + DA_SURFACE_RECT_LEN], rax
    mov     qword [rbx + DA_SURFACE_RECT_CAP], 0
    mov     qword [rbx + DA_SURFACE_ICON_PTR], 0
    mov     qword [rbx + DA_SURFACE_ICON_LEN], 0
    mov     qword [rbx + DA_SURFACE_ICON_CAP], 0

    ; Surface 1: shell status bar (toast)
    lea     rbx, [rel da_surface_registry + DA_SURFACE_SIZE]
    mov     byte [rbx + DA_SURFACE_LAYER], DA_LAYER_TOAST
    mov     byte [rbx + DA_SURFACE_FLAGS], DA_SURFACE_VISIBLE
    lea     rax, [rel shell_bar_rects]
    mov     [rbx + DA_SURFACE_RECT_PTR], rax
    mov     rax, [rel shell_bar_count]
    mov     [rbx + DA_SURFACE_RECT_LEN], rax
    mov     qword [rbx + DA_SURFACE_RECT_CAP], 0
    mov     qword [rbx + DA_SURFACE_ICON_PTR], 0
    mov     qword [rbx + DA_SURFACE_ICON_LEN], 0
    mov     qword [rbx + DA_SURFACE_ICON_CAP], 0

    mov     dword [rel da_surface_count], 2

    pop     rbx
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_da_composite
; ==================================================================
er_fn er_da_composite
    push    rbx
    push    r12                 ; layer index
    push    r13                 ; current layer byte
    push    r14                 ; surface index
    push    r15                 ; surface count

    cmp     byte [rel da_initialized], 0
    jz      .dc_done

    ; Skip if no framebuffer
    mov     rax, [rel da_fb_addr]
    test    rax, rax
    jz      .dc_done
    mov     eax, [rel da_fb_width]
    test    eax, eax
    jz      .dc_done
    mov     eax, [rel da_fb_height]
    test    eax, eax
    jz      .dc_done

    mov     qword [rel da_composite_rect_len], 0
    mov     qword [rel da_composite_icon_len], 0

    mov     r15d, [rel da_surface_count]
    test    r15d, r15d
    jz      .dc_render

    xor     r12d, r12d           ; layer index
.dc_layer_loop:
    cmp     r12b, DA_LAYER_COUNT
    jae     .dc_render

    movzx   r13d, byte [rel da_layer_order + r12]

    xor     r14d, r14d           ; surface index
.dc_surf_loop:
    cmp     r14d, r15d
    jae     .dc_next_layer

    mov     eax, r14d
    imul    eax, DA_SURFACE_SIZE
    lea     rbx, [rel da_surface_registry + rax]

    movzx   ecx, byte [rbx + DA_SURFACE_LAYER]
    cmp     cl, r13b
    jne     .dc_next_surf

    test    byte [rbx + DA_SURFACE_FLAGS], DA_SURFACE_VISIBLE
    jz      .dc_next_surf

    ; Append rects — use volatile regs only
    mov     rsi, [rbx + DA_SURFACE_RECT_PTR]
    test    rsi, rsi
    jz      .dc_icons
    mov     rcx, [rbx + DA_SURFACE_RECT_LEN]
    test    rcx, rcx
    jz      .dc_icons

    mov     rax, [rel da_composite_rect_len]
    imul    eax, 60
    lea     rdi, [rel da_composite_rect_buf + rax]
    push    rcx
    mov     eax, ecx
    imul    eax, 60
    mov     edx, eax
    call    er_memcpy
    pop     rcx
    mov     rax, [rel da_composite_rect_len]
    add     rax, rcx
    mov     [rel da_composite_rect_len], rax

.dc_icons:
    mov     rsi, [rbx + DA_SURFACE_ICON_PTR]
    test    rsi, rsi
    jz      .dc_next_surf
    mov     rcx, [rbx + DA_SURFACE_ICON_LEN]
    test    rcx, rcx
    jz      .dc_next_surf

    mov     rax, [rel da_composite_icon_len]
    imul    eax, 36
    lea     rdi, [rel da_composite_icon_buf + rax]
    push    rcx
    mov     eax, ecx
    imul    eax, 36
    mov     edx, eax
    call    er_memcpy
    pop     rcx
    mov     rax, [rel da_composite_icon_len]
    add     rax, rcx
    mov     [rel da_composite_icon_len], rax

.dc_next_surf:
    inc     r14d
    jmp     .dc_surf_loop

.dc_next_layer:
    inc     r12b
    jmp     .dc_layer_loop

.dc_render:
    mov     edi, [rel da_fb_width]
    mov     esi, [rel da_fb_height]
    mov     rdx, [rel da_fb_addr]
    lea     rcx, [rel da_composite_rect_buf]
    mov     r8d, [rel da_composite_rect_len]
    call    sw_fb_render_ir_rects

    mov     edi, [rel da_fb_width]
    mov     esi, [rel da_fb_height]
    mov     rdx, [rel da_fb_addr]
    lea     rcx, [rel da_composite_icon_buf]
    mov     r8d, [rel da_composite_icon_len]
    call    sw_fb_render_ir_icons

.dc_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; ==================================================================
; er_da_tick — called from kernel pipeline once per iteration
; Runs the persistent WASM app's tick function, then composites.
; =================================================================+
er_fn er_da_tick
    cmp     byte [rel da_app_loaded], 0
    jz      .tick_composite

    ; Call the loaded app's tick export
    lea     rdi, [rel da_wasm_runtime]
    lea     rsi, [rel da_app_export]
    movzx   edx, byte [rel da_app_export_len]
    call    er_fn_call
    ; Ignore errors from app ticks — keep compositing

.tick_composite:
    jmp     er_da_composite
