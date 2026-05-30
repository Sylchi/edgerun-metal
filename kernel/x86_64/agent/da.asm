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

extern er_local_route_register
extern er_local_route_set_handler
extern er_blake3_hash_bytes
extern er_memcpy
extern er_memset

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

; ==================================================================
; .data
; ==================================================================
SECTION .data
da_initialized: db 0

da_label: db "edgerun.agent.da", 0

da_layer_order: db DA_LAYER_SCRIM, DA_LAYER_MENU, DA_LAYER_POPOVER
                db DA_LAYER_MODAL, DA_LAYER_TOAST

; ==================================================================
; .rodata — test surface data
; ==================================================================
SECTION .rodata

; Surface 1: full-screen background (1 rect, scrim layer)
test1_rects:
    dd 0.0, 0.0, 1024.0, 768.0
    dd 0.0, 0.0
    dd 0.0431, 0.0431, 0.0431, 1.0
    dd 0.0, 0.0, 0.0, 0.0
    dd 0.0
test1_rects_end:
test1_rect_count: dq (test1_rects_end - test1_rects) / 60

; Surface 2: panel (2 rects: shadow bg + accent bar, menu layer)
test2_rects:
    ; Rect 1: shadow
    dd 200.0, 200.0, 624.0, 368.0
    dd 8.0, 4.0
    dd 0.0745, 0.0784, 0.0863, 1.0
    dd 0.0, 0.0, 0.0, 0.0
    dd 1.0
    ; Rect 2: accent bar
    dd 200.0, 200.0, 624.0, 4.0
    dd 0.0, 0.0
    dd 0.2902, 0.8706, 0.5020, 1.0
    dd 0.0, 0.0, 0.0, 0.0
    dd 0.0
test2_rects_end:
test2_rect_count: dq (test2_rects_end - test2_rects) / 60

; ==================================================================
; .text
; ==================================================================
SECTION .text

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
    call    er_da_inject_test_surfaces
    mov     byte [rel da_initialized], 1

    add     rsp, 32
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; _da_handler — stub for future cell-based surface protocol
; ==================================================================
_da_handler:
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_da_inject_test_surfaces
; ==================================================================
er_fn er_da_inject_test_surfaces
    push    rbx

    ; Surface 0: background (scrim)
    lea     rbx, [rel da_surface_registry]
    mov     byte [rbx + DA_SURFACE_LAYER], DA_LAYER_SCRIM
    mov     byte [rbx + DA_SURFACE_FLAGS], DA_SURFACE_VISIBLE
    lea     rax, [rel test1_rects]
    mov     [rbx + DA_SURFACE_RECT_PTR], rax
    mov     rax, [rel test1_rect_count]
    mov     [rbx + DA_SURFACE_RECT_LEN], rax
    mov     qword [rbx + DA_SURFACE_RECT_CAP], 16
    mov     qword [rbx + DA_SURFACE_ICON_PTR], 0
    mov     qword [rbx + DA_SURFACE_ICON_LEN], 0
    mov     qword [rbx + DA_SURFACE_ICON_CAP], 0

    ; Surface 1: panel (menu)
    lea     rbx, [rel da_surface_registry + DA_SURFACE_SIZE]
    mov     byte [rbx + DA_SURFACE_LAYER], DA_LAYER_MENU
    mov     byte [rbx + DA_SURFACE_FLAGS], DA_SURFACE_VISIBLE
    lea     rax, [rel test2_rects]
    mov     [rbx + DA_SURFACE_RECT_PTR], rax
    mov     rax, [rel test2_rect_count]
    mov     [rbx + DA_SURFACE_RECT_LEN], rax
    mov     qword [rbx + DA_SURFACE_RECT_CAP], 16
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
; er_da_tick — called from kernel main loop once per iteration
; ==================================================================
er_fn er_da_tick
    ; Debug: raw serial write to confirm tick runs
    push    rax
    push    rdx
    mov     dx, 0x3f8
    add     dx, 5
.wait:  in      al, dx
    test    al, 0x20
    jz      .wait
    mov     dx, 0x3f8
    mov     al, '!'
    out     dx, al
    pop     rdx
    pop     rax

    cmp     byte [rel da_initialized], 0
    jz      .tick_skip

.tick_skip:
    jmp     er_da_composite
