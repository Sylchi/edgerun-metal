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

; DA-owned per-app WASM allocations.
; Each launched app receives one full fixed allocation slot; no shared buffer.
da_app_memory_pool: resb DA_MAX_APPS * DA_APP_MEMORY_BYTES
da_app_ticks_pool:  resq DA_MAX_APPS

; DA's active WASM runtime descriptor (points at the current app allocation)
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

; DA message dispatch table: [msg_type:1][pad:3][handler_addr:4]
da_msg_dispatch_table:
    db DA_MSG_SURFACE_REGISTER, 0, 0, 0
    dd _da_dispatch_register
    db DA_MSG_SURFACE_UPDATE, 0, 0, 0
    dd _da_dispatch_update
    db DA_MSG_SURFACE_UNREGISTER, 0, 0, 0
    dd _da_dispatch_unregister
    db DA_MSG_LAUNCH_APP, 0, 0, 0
    dd _da_dispatch_launch
    db DA_MSG_APP_EXIT, 0, 0, 0
    dd _da_dispatch_exit
    db DA_MSG_SURFACE_FOCUS, 0, 0, 0
    dd _da_dispatch_focus
da_msg_dispatch_table_end:
da_msg_dispatch_count: dq (da_msg_dispatch_table_end - da_msg_dispatch_table) / 8

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
    er_push rbx, r12
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
    er_check_zero rax, .init_skip_route

    mov     rdi, rsp
    call    er_local_route_register
    er_check_nonzero edx, .init_skip_route

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
    er_pop  rbx, r12
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; _da_handler — cell message dispatch for compositor
; rdi = cell_ptr, rsi = sender_slot_id
; ==================================================================
_da_handler:
    er_push rbx, r12, r13
    mov     r12, rdi            ; cell_ptr
    mov     r13d, esi           ; sender_slot_id

    movzx   ebx, byte [r12 + LOCAL_CELL_PAYLOAD]
    lea     rax, [rel da_msg_dispatch_table]
    mov     rcx, [rel da_msg_dispatch_count]

.dispatch_loop:
    er_check_zero rcx, .unknown
    cmp     bl, byte [rax]
    je      .dispatch_hit
    add     rax, 8
    dec     rcx
    jmp     .dispatch_loop

.dispatch_hit:
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, [rax + 4]
    call    rdx
    jmp     .done

.unknown:
    er_ok

.done:
    er_pop  rbx, r12, r13
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
    er_push rbx, r12
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
    er_check_zero eax, .found
    inc     ebx
    jmp     .loop
.found:
    mov     eax, ebx
    er_ok
    er_pop_ret rbx, r12
.not_found:
    xor     eax, eax
    er_err  ERROR_LOCAL_NOT_FOUND
    er_pop_ret rbx, r12

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
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13d, esi

    ; Extract sender identity hash from cell circ_id field
    lea     rsi, [r12 + LOCAL_CELL_PAYLOAD + 5]  ; hash starts at offset 5 in payload
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 5]  ; use it directly

    ; Check if this hash already has a surface
    mov     rdi, rsi
    call    _da_find_surface_by_hash
    er_check_zero edx, .update_existing

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
    er_pop  rbx, r12, r13
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

    er_pop  rbx, r12, r13
    xor     eax, eax
    er_ok
    ret

.fail:
    er_pop  rbx, r12, r13
    mov     eax, -1
    er_err  ERROR_LOCAL_FULL
    ret

; ==================================================================
; _da_unregister_surface — remove a surface by hash from cell
; rdi = cell_ptr
; ==================================================================
_da_unregister_surface:
    er_push rbx, r12, r13, r14

    lea     rdi, [rdi + LOCAL_CELL_PAYLOAD + 5]
    call    _da_find_surface_by_hash
    er_check_nonzero edx, .done

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
    er_pop  rbx, r12, r13, r14
    xor     eax, eax
    er_ok
    ret

; ==================================================================
; _da_update_surface — update a registered surface's rect/icon data
; rdi = cell_ptr, esi = sender_slot_id
; Cell payload:
;   See DA_UPDATE_PAYLOAD_* constants in da_constants.inc.
; ==================================================================
_da_update_surface:
    er_push rbx, r12, r13, r14, r15
    mov     r12, rdi                 ; cell_ptr
    mov     r13d, esi                ; sender_slot_id (unused)

    ; Find surface by identity hash.
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + DA_UPDATE_PAYLOAD_HASH_OFF]
    call    _da_find_surface_by_hash
    er_check_nonzero edx, .us_return

    mov     r14d, eax               ; r14d = slot_index
    mov     eax, r14d
    imul    eax, DA_SURFACE_SIZE
    lea     r15, [rel da_surface_registry + rax]  ; r15 = surface entry

    movzx   ebx, byte [r12 + LOCAL_CELL_PAYLOAD + DA_UPDATE_PAYLOAD_FLAGS_OFF]

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

    movzx   ecx, word [r12 + LOCAL_CELL_PAYLOAD + DA_UPDATE_PAYLOAD_RECT_COUNT_OFF]
    er_check_zero ecx, .us_check_icons

    da_pool_append_from_payload DA_SURFACE_RECT_LEN, DA_SURFACE_RECT_PTR, DA_SURFACE_RECT_CAP, da_surface_rect_pool, DA_SURFACE_POOL_RECTS, DA_RECT_BYTES, DA_UPDATE_PAYLOAD_DATA_OFF

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

    movzx   ecx, word [r12 + LOCAL_CELL_PAYLOAD + DA_UPDATE_PAYLOAD_ICON_COUNT_OFF]
    er_check_zero ecx, .us_done

    mov     r8d, [r15 + DA_SURFACE_ICON_LEN]
    mov     edx, DA_SURFACE_POOL_ICONS
    sub     edx, r8d
    jle     .us_done
    cmp     ecx, edx
    cmova   ecx, edx

    ; dst = icon_pool[slot] + current_len * 36
    mov     eax, r14d
    imul    eax, DA_SURFACE_POOL_ICONS * DA_ICON_BYTES
    mov     edx, r8d
    imul    edx, DA_ICON_BYTES
    add     eax, edx
    lea     rdi, [rel da_surface_icon_pool + rax]

    ; src = payload data + rect_count*rect_bytes
    movzx   eax, word [r12 + LOCAL_CELL_PAYLOAD + DA_UPDATE_PAYLOAD_RECT_COUNT_OFF]
    imul    eax, DA_RECT_BYTES
    add     eax, DA_UPDATE_PAYLOAD_DATA_OFF
    lea     rsi, [r12 + LOCAL_CELL_PAYLOAD]
    add     rsi, rax

    mov     r11d, ecx
    mov     eax, ecx
    imul    eax, DA_ICON_BYTES
    mov     edx, eax
    call    er_memcpy

    mov     eax, [r15 + DA_SURFACE_ICON_LEN]
    add     eax, r11d
    mov     [r15 + DA_SURFACE_ICON_LEN], eax

    mov     eax, r14d
    imul    eax, DA_SURFACE_POOL_ICONS * DA_ICON_BYTES
    lea     rax, [rel da_surface_icon_pool + rax]
    mov     [r15 + DA_SURFACE_ICON_PTR], rax

    cmp     qword [r15 + DA_SURFACE_ICON_CAP], 0
    jnz     .us_done
    mov     qword [r15 + DA_SURFACE_ICON_CAP], DA_SURFACE_POOL_ICONS

.us_done:
    er_pop  rbx, r12, r13, r14, r15
    xor     eax, eax
    er_ok
    ret

.us_return:
    er_pop  rbx, r12, r13, r14, r15
    xor     eax, eax
    er_err  ERROR_LOCAL_NOT_FOUND
    ret

; ==================================================================
; _da_store_export_name
; rdi = export_name_ptr, rsi = export_name_len
; ==================================================================
_da_store_export_name:
    push    rbx
    mov     rbx, rdi
    mov     [rel da_app_export_len], sil
    er_check_zero rsi, .done
    cmp     rsi, 64
    ja      .done
    push    rdx
    mov     rdx, rsi
    lea     rdi, [rel da_app_export]
    mov     rsi, rbx
    call    er_memcpy
    pop     rdx
.done:
    pop     rbx
    ret

; ==================================================================
; _da_app_allocation_bind
; rdi = app entry pointer, esi = app index
; Binds a full DA-owned runtime allocation to the app registry entry.
; ==================================================================
_da_app_allocation_bind:
    push    rbx
    mov     rbx, rdi
    mov     eax, esi
    shl     eax, 16
    lea     rdx, [rel da_app_memory_pool]
    add     rdx, rax
    mov     [rbx + DA_APP_MEM_PTR], rdx
    mov     qword [rbx + DA_APP_MEM_LEN], DA_APP_MEMORY_BYTES
    mov     eax, esi
    imul    eax, 8
    lea     rdx, [rel da_app_ticks_pool]
    add     rdx, rax
    mov     [rbx + DA_APP_TICKS_PTR], rdx
    xor     eax, eax
    er_ok
    pop     rbx
    ret

; ==================================================================
; _da_prepare_wasm_runtime
; rdi = app entry pointer
; Returns rax = &da_wasm_runtime
;         edx = 0 on success, ERROR_NO_MEMORY if allocation is missing
; ==================================================================
_da_prepare_wasm_runtime:
    push    rbx
    mov     rbx, rdi
    mov     rdx, [rbx + DA_APP_MEM_PTR]
    er_check_zero rdx, .missing
    mov     rcx, [rbx + DA_APP_MEM_LEN]
    cmp     rcx, DA_APP_MEMORY_BYTES
    jb      .missing
    mov     r8, [rbx + DA_APP_TICKS_PTR]
    er_check_zero r8, .missing

    lea     rax, [rel da_wasm_runtime]
    mov     [rax + RUNTIME_MEMORY_PTR_OFF], rdx
    mov     [rax + RUNTIME_MEMORY_LEN_OFF], rcx
    mov     [rax + RUNTIME_TICKS_PTR_OFF], r8
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

    mov     rdi, [rbx + DA_APP_MEM_PTR]
    xor     esi, esi
    mov     edx, DA_APP_MEMORY_BYTES
    call    er_memset
    mov     rdx, [rbx + DA_APP_TICKS_PTR]
    mov     qword [rdx], 0
    lea     rax, [rel da_wasm_runtime]
    er_ok
    pop     rbx
    ret
.missing:
    xor     eax, eax
    er_err  ERROR_NO_MEMORY
    pop     rbx
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
; _da_find_app_by_hash
; rdi = app_hash_ptr (32 bytes)
; Returns eax=index, edx=0 on success
;         edx=ERROR_LOCAL_NOT_FOUND if not found
; ==================================================================
_da_find_app_by_hash:
    er_push rbx, r12
    mov     r12, rdi
    xor     ebx, ebx
.loop:
    cmp     ebx, [rel da_app_count]
    jae     .not_found
    mov     eax, ebx
    imul    eax, DA_APP_SIZE
    lea     rdi, [rel da_app_registry + rax + DA_APP_HASH]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcmp
    er_check_zero eax, .found
    inc     ebx
    jmp     .loop
.found:
    mov     eax, ebx
    er_ok
    er_pop_ret rbx, r12
.not_found:
    xor     eax, eax
    er_err  ERROR_LOCAL_NOT_FOUND
    er_pop_ret rbx, r12

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
    er_push rbx, r12, r13, r14, r15
    sub     rsp, 48

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx
    mov     [rsp + 40], r8d

    ; Compute app identity hash once.
    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [rsp]
    call    er_blake3_hash_bytes
    er_check_zero rax, .hash_fail

    ; Single-instance policy: existing hash reuses same app slot.
    lea     rdi, [rsp]
    call    _da_find_app_by_hash
    er_check_nonzero edx, .new_entry

    ; Existing hash found.
    imul    eax, DA_APP_SIZE
    lea     r9, [rel da_app_registry + rax]
    mov     [rsp + 32], r9
    mov     eax, [rsp + 40]
    mov     [r9 + DA_APP_SLOT], eax
    cmp     byte [r9 + DA_APP_STATE], 1
    jne     .reuse_entry

    ; Already running: launch means focus existing surface if it exists.
    lea     rdi, [rsp]
    call    _da_find_surface_by_hash
    er_check_nonzero edx, .already_running
    mov     ebx, eax
    call    _da_focus_clear_all_flags
    mov     edi, ebx
    call    _da_focus_assign_slot
.already_running:
    er_ok
    jmp     .done

.new_entry:
    mov     ebx, [rel da_app_count]
    cmp     ebx, DA_MAX_APPS
    jae     .full

    mov     eax, ebx
    imul    eax, DA_APP_SIZE
    lea     r9, [rel da_app_registry + rax]
    mov     [rsp + 32], r9
    mov     rdi, r9
    xor     esi, esi
    mov     edx, DA_APP_SIZE
    call    er_memset
    mov     r9, [rsp + 32]
    lea     rdi, [r9 + DA_APP_HASH]
    lea     rsi, [rsp]
    mov     edx, 32
    call    er_memcpy
    mov     r9, [rsp + 32]
    mov     rdi, r9
    mov     esi, ebx
    call    _da_app_allocation_bind
    mov     r9, [rsp + 32]
    er_check_nonzero edx, .alloc_fail
    inc     dword [rel da_app_count]

.reuse_entry:
    ; Existing or new entry now loads/reloads in-place.
    mov     [rsp + 32], r9
    lea     rdi, [r9 + DA_APP_HASH]
    lea     rsi, [rsp]
    mov     edx, 32
    call    er_memcpy
    mov     r9, [rsp + 32]

    mov     eax, [rsp + 40]
    mov     [r9 + DA_APP_SLOT], eax
    mov     byte [r9 + DA_APP_STATE], 1

    mov     rdi, r9
    call    _da_prepare_wasm_runtime
    mov     r9, [rsp + 32]
    er_check_nonzero edx, .alloc_fail
    mov     rbx, rax

    mov     rdi, r14
    mov     rsi, r15
    call    _da_store_export_name
    mov     r9, [rsp + 32]

    lea     rdi, [r9 + DA_APP_HASH]
    call    _da_publish_app_hash
    mov     r9, [rsp + 32]

    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r13
    call    er_fn_load
    mov     r9, [rsp + 32]
    er_check_nonzero edx, .load_fail

    mov     byte [rel da_app_loaded], 1
    er_ok
    jmp     .done

.full:
    er_err  ERROR_LOCAL_FULL
    jmp     .done

.hash_fail:
    er_err  ERROR_CORRUPT
    jmp     .done

.alloc_fail:
    mov     byte [r9 + DA_APP_STATE], 0
    er_err  ERROR_NO_MEMORY
    jmp     .done

.load_fail:
    mov     byte [r9 + DA_APP_STATE], 0

.done:
    add     rsp, 48
    er_pop_ret rbx, r12, r13, r14, r15

; ==================================================================
; _da_launch_app — launch a WASM app from cell payload
; rdi = cell_ptr, esi = sender_slot_id
; Cell payload: [type:1][wasm_len:4][export_len:1][export_name...][wasm_bytes...]
; ==================================================================
_da_launch_app:
    er_push rbx, r12
    mov     r12, rdi
    mov     ebx, esi

    movzx   ecx, byte [r12 + LOCAL_CELL_PAYLOAD + 5] ; export_name_len
    lea     rdx, [r12 + LOCAL_CELL_PAYLOAD + 6]      ; export_name_ptr
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 6]      ; base for wasm_ptr
    add     rdi, rcx
    mov     esi, [r12 + LOCAL_CELL_PAYLOAD + 1]      ; wasm_len
    mov     r8d, ebx                                 ; app_slot=sender_slot
    call    _da_launch_common

    er_pop_ret rbx, r12

; ==================================================================
; _da_app_exit — mark an app as exited by app hash
; rdi = cell_ptr
; Cell payload: [type=11][hash:32]
; ==================================================================
_da_app_exit:
    er_push rbx, r12, r13

    lea     r12, [rdi + LOCAL_CELL_PAYLOAD + 1]
    mov     rdi, r12
    call    _da_find_app_by_hash
    er_check_nonzero edx, .done

    imul    eax, DA_APP_SIZE
    lea     r13, [rel da_app_registry + rax]
    mov     byte [r13 + DA_APP_STATE], 2

    ; If this app currently has focus, clear focus.
    lea     rdi, [rel da_focused_hash]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcmp
    er_check_nonzero eax, .check_loaded
    call    _da_focus_clear_state

.check_loaded:
    ; If this app is the currently loaded runtime owner, clear loaded marker.
    lea     rdi, [rel da_wasm_app_hash]
    mov     rsi, r12
    mov     edx, 32
    call    er_memcmp
    er_check_nonzero eax, .done
    mov     byte [rel da_app_loaded], 0

.done:
    er_pop  rbx, r12, r13
    xor     eax, eax
    er_ok
    ret

; ==================================================================
; _da_focus_surface — set the focused surface by identity hash
; rdi = cell_ptr
; Cell payload: [type=4][hash:32]
; ==================================================================
_da_focus_surface:
    er_push rbx, r12, r13

    mov     r12, rdi

    ; Find surface by hash at payload[1..32]
    lea     rdi, [r12 + LOCAL_CELL_PAYLOAD + 1]
    call    _da_find_surface_by_hash
    er_check_nonzero edx, .done

    mov     r13d, eax               ; new focus slot

    call    _da_focus_clear_all_flags
    mov     edi, r13d
    call    _da_focus_assign_slot

.done:
    er_pop  rbx, r12, r13
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
    er_check_zero rax, .dc_done
    mov     eax, [rel da_fb_width]
    er_check_zero eax, .dc_done
    mov     eax, [rel da_fb_height]
    er_check_zero eax, .dc_done

    mov     qword [rel da_composite_rect_len], 0
    mov     qword [rel da_composite_icon_len], 0

    mov     r15d, [rel da_surface_count]
    er_check_zero r15d, .dc_render

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
    er_check_zero rsi, .dc_icons
    mov     rcx, [rbx + DA_SURFACE_RECT_LEN]
    er_check_zero rcx, .dc_icons

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
    er_check_zero rsi, .dc_next_surf
    mov     rcx, [rbx + DA_SURFACE_ICON_LEN]
    er_check_zero rcx, .dc_next_surf

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
    er_pop  rbx, r12, r13, r14, r15
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
