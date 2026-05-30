; EdgeRun Render IR — x86_64 assembly
; Faithful port of edgerun-zig/src/render/ir.zig
; Defines packed float buffer layout and push/read-back operations.
; System V AMD64 ABI, freestanding.

%include "x86_64/macros.inc"

; ==================================================================
; Float stride sizes (in float units, i.e. sizeof(float) words)
; ==================================================================
%define RENDER_IR_RECT_FLOAT_STRIDE          15
%define RENDER_IR_TEXT_VERTEX_FLOAT_STRIDE   8
%define RENDER_IR_ICON_FLOAT_STRIDE          9
%define RENDER_IR_ICON_LINE_FLOAT_STRIDE     6
%define RENDER_IR_IMAGE_VERTEX_FLOAT_STRIDE  8
%define RENDER_IR_TEXTURED_QUAD_VERTEX_COUNT 6
%define TEXTURED_QUAD_VERTEX_COUNT 6

; Byte strides
%define RENDER_IR_RECT_BYTE_STRIDE           60  ; 15 * 4
%define RENDER_IR_TEXT_VERTEX_BYTE_STRIDE    32  ; 8 * 4
%define RENDER_IR_ICON_BYTE_STRIDE           36  ; 9 * 4
%define RENDER_IR_ICON_LINE_BYTE_STRIDE      24  ; 6 * 4

; ==================================================================
; Rect field indices (in float units from start of rect)
; ==================================================================
%define RECT_X       0
%define RECT_Y       1
%define RECT_W       2
%define RECT_H       3
%define RECT_RADIUS  4
%define RECT_SHADOW  5
%define RECT_R       6
%define RECT_G       7
%define RECT_B       8
%define RECT_A       9
%define RECT_R2      10
%define RECT_G2      11
%define RECT_B2      12
%define RECT_A2      13
%define RECT_MODE    14

; ==================================================================
; Textured vertex field indices
; ==================================================================
%define VTX_X     0
%define VTX_Y     1
%define VTX_U     2
%define VTX_V     3
%define VTX_R     4
%define VTX_G     5
%define VTX_B     6
%define VTX_A     7

; ==================================================================
; Icon instance field indices
; ==================================================================
%define ICON_X   0
%define ICON_Y   1
%define ICON_W   2
%define ICON_H   3
%define ICON_R   4
%define ICON_G   5
%define ICON_B   6
%define ICON_A   7
%define ICON_ID  8

; Image vertex field indices (same as textured vertex)
%define IMG_X     0
%define IMG_Y     1
%define IMG_U     2
%define IMG_V     3
%define IMG_R     4
%define IMG_G     5
%define IMG_B     6
%define IMG_A     7

; ==================================================================
; Icon line vertex field indices
; ==================================================================
%define LINE_X   0
%define LINE_Y   1
%define LINE_R   2
%define LINE_G   3
%define LINE_B   4
%define LINE_A   5

; ==================================================================
; Rect mode codes (as byte values)
; ==================================================================
%define RENDER_IR_RECT_MODE_FILL            0
%define RENDER_IR_RECT_MODE_SHADOW          1
%define RENDER_IR_RECT_MODE_BORDER          2
%define RENDER_IR_RECT_MODE_LINEAR_GRADIENT 3
%define RENDER_IR_RECT_MODE_PIE_SLICE       4

; ==================================================================
; Font constants
; ==================================================================
%define RENDER_IR_FONT_FIRST_PX   11
%define RENDER_IR_FONT_LAST_PX    48
%define RENDER_IR_FONT_FIRST_CHAR 32
%define RENDER_IR_FONT_LAST_CHAR  126

; ==================================================================
; Error codes (returned in rax)
; ==================================================================
%define RENDER_IR_OK       0
%define RENDER_IR_BUDGET  -1
%define RENDER_IR_INVALID -2

extern sw_fb_fill
extern sw_fb_blend_pixel

SECTION .rodata
align 16
float_255:      dd 255.0
float_one:      dd 1.0
float_half:     dd 0.5
float_zero:     dd 0.0

SECTION .text

er_fn er_render_ir_channel
    movzx   eax, dil
    cvtsi2ss xmm0, eax
    divss   xmm0, [rel float_255]
    ret

er_fn er_render_ir_pack_channel
    ; Clamp to [0, 1]
    maxss   xmm0, [rel float_zero]
    minss   xmm0, [rel float_one]
    ; value * 255 + 0.5 for round-to-nearest
    mulss   xmm0, [rel float_255]
    addss   xmm0, [rel float_half]
    cvtss2si eax, xmm0
    ; Clamp to 0..255
    test    eax, eax
    js      .clamp_low
    cmp     eax, 255
    jg      .clamp_high
    ret
.clamp_low:
    xor     eax, eax
    ret
.clamp_high:
    mov     eax, 255
    ret

; ==================================================================
; Internal push helper macro
; Expects: stride (float units), byte_stride
; rdi = buffer, rsi = len_ptr, rdx = capacity, rcx = source data
; Clobbers: r8, r9, rdi, rsi, rcx
; ==================================================================
%macro er_render_ir_push_impl 2
    mov     r8, rcx              ; save source ptr
    mov     rax, [rsi]           ; rax = *len
    lea     r9, [rax + %1]       ; r9 = *len + stride
    cmp     r9, rdx
    ja      %%budget
    push    rdi
    push    rsi
    lea     rdi, [rdi + rax*4]   ; dst = &buffer[*len]
    mov     rsi, r8              ; src = data
    mov     ecx, %2              ; byte count
    shr     ecx, 2               ; convert to dword count
    rep     movsd
    pop     rsi
    mov     rax, [rsi]
    add     rax, %1
    mov     [rsi], rax           ; *len += stride
    pop     rdi
    xor     eax, eax
    ret
%%budget:
    mov     rax, RENDER_IR_BUDGET
    ret
%endmacro

er_fn er_render_ir_push_rect
    er_render_ir_push_impl RENDER_IR_RECT_FLOAT_STRIDE, RENDER_IR_RECT_BYTE_STRIDE

er_fn er_render_ir_push_textured_vertex
    er_render_ir_push_impl RENDER_IR_TEXT_VERTEX_FLOAT_STRIDE, RENDER_IR_TEXT_VERTEX_BYTE_STRIDE

er_fn er_render_ir_push_icon
    er_render_ir_push_impl RENDER_IR_ICON_FLOAT_STRIDE, RENDER_IR_ICON_BYTE_STRIDE

er_fn er_render_ir_push_icon_line_vertex
    er_render_ir_push_impl RENDER_IR_ICON_LINE_FLOAT_STRIDE, RENDER_IR_ICON_LINE_BYTE_STRIDE

; ==================================================================
; Read-back helpers
; ==================================================================

er_fn er_render_ir_rect_at
    mov     rax, rsi
    shl     rax, 4           ; index * 16
    sub     rax, rsi         ; index * 15
    lea     rsi, [rdi + rax*4]  ; &buffer[index * 15]
    mov     rdi, rdx         ; rdi = out
    mov     ecx, RENDER_IR_RECT_BYTE_STRIDE / 4
    rep     movsd
    xor     eax, eax
    ret

er_fn er_render_ir_textured_vertex_at
    mov     rax, rsi
    shl     rax, 3           ; index * 8
    lea     rsi, [rdi + rax*4]  ; &buffer[index * 8]
    mov     rdi, rdx
    mov     ecx, RENDER_IR_TEXT_VERTEX_BYTE_STRIDE / 4
    rep     movsd
    xor     eax, eax
    ret

er_fn er_render_ir_icon_at
    mov     rax, rsi
    shl     rax, 3           ; index * 8
    add     rax, rsi         ; index * 9
    lea     rsi, [rdi + rax*4]  ; &buffer[index * 9]
    mov     rdi, rdx
    mov     ecx, RENDER_IR_ICON_BYTE_STRIDE / 4
    rep     movsd
    xor     eax, eax
    ret

er_fn er_render_ir_icon_line_vertex_at
    lea     rax, [rsi + rsi*2]  ; index * 3
    shl     rax, 1              ; index * 6
    lea     rsi, [rdi + rax*4]  ; &buffer[index * 6]
    mov     rdi, rdx
    mov     ecx, RENDER_IR_ICON_LINE_BYTE_STRIDE / 4
    rep     movsd
    xor     eax, eax
    ret

er_fn er_render_ir_push_rect_ex
    er_frame_push
    push    r12                    ; save buffer
    push    r13                    ; save len_ptr
    push    r14                    ; save capacity
    push    r15
    sub     rsp, 64                ; temp 15-float array + alignment

    mov     r12, rdi               ; buffer
    mov     r13, rsi               ; len_ptr
    mov     r14, rdx               ; capacity
    mov     r15d, r8d              ; color
    mov     [rsp + 60], r9d        ; color2

    ; Copy bounds (4 floats from rcx) to temp[0..3]
    mov     rax, [rcx]
    mov     [rsp + RECT_X*4], rax
    mov     rax, [rcx + 8]
    mov     [rsp + RECT_W*4], rax

    ; Convert color (r15d) channels
    ; r channel — byte 0
    mov     edi, r15d
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + RECT_R*4], xmm0

    ; g channel — byte 1
    mov     edi, r15d
    shr     edi, 8
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + RECT_G*4], xmm0

    ; b channel — byte 2
    mov     edi, r15d
    shr     edi, 16
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + RECT_B*4], xmm0

    ; a channel — byte 3
    mov     edi, r15d
    shr     edi, 24
    call    er_render_ir_channel
    movss   [rsp + RECT_A*4], xmm0

    ; Convert color2 channels
    mov     edi, [rsp + 60]
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + RECT_R2*4], xmm0

    mov     edi, [rsp + 60]
    shr     edi, 8
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + RECT_G2*4], xmm0

    mov     edi, [rsp + 60]
    shr     edi, 16
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + RECT_B2*4], xmm0

    mov     edi, [rsp + 60]
    shr     edi, 24
    call    er_render_ir_channel
    movss   [rsp + RECT_A2*4], xmm0

    ; radius, shadow, mode from stack
    movss   xmm0, [rbp + 16]
    movss   [rsp + RECT_RADIUS*4], xmm0
    movss   xmm0, [rbp + 24]
    movss   [rsp + RECT_SHADOW*4], xmm0
    movss   xmm0, [rbp + 32]
    movss   [rsp + RECT_MODE*4], xmm0

    ; Call raw push_rect
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     rcx, [rsp]
    call    er_render_ir_push_rect

    add     rsp, 64
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

er_fn er_render_ir_push_textured_vertex_ex
    er_frame_push
    push    r12                    ; save buffer
    push    r13                    ; save len_ptr
    push    r14                    ; save capacity
    push    r15                    ; save color
    sub     rsp, 32                ; temp 8-float array

    mov     r12, rdi               ; buffer
    mov     r13, rsi               ; len_ptr
    mov     r14, rdx               ; capacity
    mov     r15, rcx               ; color

    ; Store x, y, u, v from xmm regs
    movss   [rsp + VTX_X*4], xmm0
    movss   [rsp + VTX_Y*4], xmm1
    movss   [rsp + VTX_U*4], xmm2
    movss   [rsp + VTX_V*4], xmm3

    ; Convert color channels (r15d preserved across calls)
    mov     edi, r15d
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + VTX_R*4], xmm0

    mov     edi, r15d
    shr     edi, 8
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + VTX_G*4], xmm0

    mov     edi, r15d
    shr     edi, 16
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + VTX_B*4], xmm0

    mov     edi, r15d
    shr     edi, 24
    call    er_render_ir_channel
    movss   [rsp + VTX_A*4], xmm0

    ; Call raw push
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     rcx, [rsp]
    call    er_render_ir_push_textured_vertex

    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

er_fn er_render_ir_push_icon_ex
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 48                ; temp 9-float array + alignment

    mov     r12, rdi               ; buffer
    mov     r13, rsi               ; len_ptr
    mov     r14, rdx               ; capacity
    mov     r15, r9                ; icon_id
    mov     [rsp + 36], r8d        ; color (save in free stack slot)

    ; Copy bounds
    mov     rax, [rcx]
    mov     [rsp + ICON_X*4], rax
    mov     rax, [rcx + 8]
    mov     [rsp + ICON_W*4], rax

    ; Convert color channels
    mov     edi, [rsp + 36]
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + ICON_R*4], xmm0

    mov     edi, [rsp + 36]
    shr     edi, 8
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + ICON_G*4], xmm0

    mov     edi, [rsp + 36]
    shr     edi, 16
    and     edi, 0xFF
    call    er_render_ir_channel
    movss   [rsp + ICON_B*4], xmm0

    mov     edi, [rsp + 36]
    shr     edi, 24
    call    er_render_ir_channel
    movss   [rsp + ICON_A*4], xmm0

    ; icon_id as float
    mov     eax, r15d
    cvtsi2ss xmm0, eax
    movss   [rsp + ICON_ID*4], xmm0

    ; Call raw push
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    lea     rcx, [rsp]
    call    er_render_ir_push_icon

    add     rsp, 48
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

er_fn er_render_ir_push_textured_quad
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 64

    mov     r12, rdi               ; buffer
    mov     r13, rsi               ; len_ptr
    mov     r14, rdx               ; capacity
    mov     r15, r9                ; color

    ; Save tex coords
    movss   [rsp + 48], xmm0       ; tex_u0
    movss   [rsp + 52], xmm1       ; tex_v0
    movss   [rsp + 56], xmm2       ; tex_u1
    movss   [rsp + 60], xmm3       ; tex_v1

    ; ---- Intersect bounds (r8) with clip (rcx) ----
    ; x = max(bounds.x, clip.x)
    movss   xmm0, [r8]
    movss   xmm1, [rcx]
    maxss   xmm0, xmm1
    movss   [rsp], xmm0

    ; y = max(bounds.y, clip.y)
    movss   xmm0, [r8 + 4]
    movss   xmm1, [rcx + 4]
    maxss   xmm0, xmm1
    movss   [rsp + 4], xmm0

    ; x1 = min(bounds.x+bounds.w, clip.x+clip.w)
    movss   xmm0, [r8]
    addss   xmm0, [r8 + 8]
    movss   xmm1, [rcx]
    addss   xmm1, [rcx + 8]
    minss   xmm0, xmm1
    movss   [rsp + 8], xmm0        ; store in w slot temporarily

    ; y1 = min(bounds.y+bounds.h, clip.y+clip.h)
    movss   xmm0, [r8 + 4]
    addss   xmm0, [r8 + 12]
    movss   xmm1, [rcx + 4]
    addss   xmm1, [rcx + 12]
    minss   xmm0, xmm1
    movss   [rsp + 12], xmm0       ; store in h slot temporarily

    ; w = x1 - x
    movss   xmm0, [rsp + 8]
    subss   xmm0, [rsp]
    movss   [rsp + 8], xmm0

    ; h = y1 - y
    movss   xmm0, [rsp + 12]
    subss   xmm0, [rsp + 4]
    movss   [rsp + 12], xmm0

    ; Check w <= 0 or h <= 0
    pxor    xmm4, xmm4
    ucomiss xmm0, xmm4
    jbe     .ret0_tq
    movss   xmm0, [rsp + 8]
    ucomiss xmm0, xmm4
    jbe     .ret0_tq

    ; ---- Budget check: *len + 48 > capacity ----
    mov     rax, [r13]
    add     rax, RENDER_IR_TEXT_VERTEX_FLOAT_STRIDE * TEXTURED_QUAD_VERTEX_COUNT
    cmp     rax, r14
    ja      .budget_tq

    ; ---- Compute UV adjustment ----
    ; tx0 = (bounds.w > 0) ? (x0 - bounds.x) / bounds.w : 0
    ; tx1 = (bounds.w > 0) ? (x0+w - bounds.x) / bounds.w : 1
    movss   xmm4, [r8 + 8]         ; bounds.w
    pxor    xmm5, xmm5
    ucomiss xmm4, xmm5
    jbe     .bw_zero_tq

    movss   xmm0, [rsp]            ; clipped.x
    subss   xmm0, [r8]             ; - bounds.x
    divss   xmm0, xmm4             ; / bounds.w
    movss   [rsp + 16], xmm0       ; tx0

    movss   xmm0, [rsp]            ; clipped.x
    addss   xmm0, [rsp + 8]        ; + clipped.w
    subss   xmm0, [r8]             ; - bounds.x
    divss   xmm0, xmm4             ; / bounds.w
    movss   [rsp + 20], xmm0       ; tx1
    jmp     .ty_tq

.bw_zero_tq:
    mov     dword [rsp + 16], 0x00000000  ; tx0 = 0
    mov     dword [rsp + 20], 0x3F800000  ; tx1 = 1

.ty_tq:
    ; ty0 = (bounds.h > 0) ? (y0 - bounds.y) / bounds.h : 0
    ; ty1 = (bounds.h > 0) ? (y0+h - bounds.y) / bounds.h : 1
    movss   xmm4, [r8 + 12]        ; bounds.h
    pxor    xmm5, xmm5
    ucomiss xmm4, xmm5
    jbe     .bh_zero_tq

    movss   xmm0, [rsp + 4]        ; clipped.y
    subss   xmm0, [r8 + 4]         ; - bounds.y
    divss   xmm0, xmm4             ; / bounds.h
    movss   [rsp + 24], xmm0       ; ty0

    movss   xmm0, [rsp + 4]        ; clipped.y
    addss   xmm0, [rsp + 12]       ; + clipped.h
    subss   xmm0, [r8 + 4]         ; - bounds.y
    divss   xmm0, xmm4             ; / bounds.h
    movss   [rsp + 28], xmm0       ; ty1
    jmp     .lerp_tq

.bh_zero_tq:
    mov     dword [rsp + 24], 0x00000000  ; ty0 = 0
    mov     dword [rsp + 28], 0x3F800000  ; ty1 = 1

.lerp_tq:
    ; cu0 = u0 + (u1 - u0) * tx0
    movss   xmm4, [rsp + 48]       ; tex_u0
    movss   xmm5, [rsp + 56]       ; tex_u1
    movss   xmm6, [rsp + 16]       ; tx0
    subss   xmm5, xmm4             ; (u1-u0)
    mulss   xmm5, xmm6             ; (u1-u0)*tx0
    addss   xmm4, xmm5             ; u0 + ...
    movss   [rsp + 32], xmm4       ; cu0

    ; cv0 = v0 + (v1 - v0) * ty0
    movss   xmm4, [rsp + 52]       ; tex_v0
    movss   xmm5, [rsp + 60]       ; tex_v1
    movss   xmm6, [rsp + 24]       ; ty0
    subss   xmm5, xmm4             ; (v1-v0)
    mulss   xmm5, xmm6             ; (v1-v0)*ty0
    addss   xmm4, xmm5             ; v0 + ...
    movss   [rsp + 36], xmm4       ; cv0

    ; cu1 = u0 + (u1 - u0) * tx1
    movss   xmm4, [rsp + 48]       ; tex_u0
    movss   xmm5, [rsp + 56]       ; tex_u1
    movss   xmm6, [rsp + 20]       ; tx1
    subss   xmm5, xmm4             ; (u1-u0)
    mulss   xmm5, xmm6             ; (u1-u0)*tx1
    addss   xmm4, xmm5             ; u0 + ...
    movss   [rsp + 40], xmm4       ; cu1

    ; cv1 = v0 + (v1 - v0) * ty1
    movss   xmm4, [rsp + 52]       ; tex_v0
    movss   xmm5, [rsp + 60]       ; tex_v1
    movss   xmm6, [rsp + 28]       ; ty1
    subss   xmm5, xmm4             ; (v1-v0)
    mulss   xmm5, xmm6             ; (v1-v0)*ty1
    addss   xmm4, xmm5             ; v0 + ...
    movss   [rsp + 44], xmm4       ; cv1

    ; ---- Push 6 vertices via push_textured_vertex_ex ----
    ; Vertex 1: (x0, y0, cu0, cv0, color)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, r15d
    movss   xmm0, [rsp]            ; x0
    movss   xmm1, [rsp + 4]        ; y0
    movss   xmm2, [rsp + 32]       ; cu0
    movss   xmm3, [rsp + 36]       ; cv0
    call    er_render_ir_push_textured_vertex_ex

    ; Vertex 2: (x0+w, y0, cu1, cv0, color)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, r15d
    movss   xmm0, [rsp]            ; x0
    addss   xmm0, [rsp + 8]        ; + w
    movss   xmm1, [rsp + 4]        ; y0
    movss   xmm2, [rsp + 40]       ; cu1
    movss   xmm3, [rsp + 36]       ; cv0
    call    er_render_ir_push_textured_vertex_ex

    ; Vertex 3: (x0+w, y0+h, cu1, cv1, color)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, r15d
    movss   xmm0, [rsp]            ; x0
    addss   xmm0, [rsp + 8]        ; + w
    movss   xmm1, [rsp + 4]        ; y0
    addss   xmm1, [rsp + 12]       ; + h
    movss   xmm2, [rsp + 40]       ; cu1
    movss   xmm3, [rsp + 44]       ; cv1
    call    er_render_ir_push_textured_vertex_ex

    ; Vertex 4: (x0, y0, cu0, cv0, color) — same as vertex 1
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, r15d
    movss   xmm0, [rsp]            ; x0
    movss   xmm1, [rsp + 4]        ; y0
    movss   xmm2, [rsp + 32]       ; cu0
    movss   xmm3, [rsp + 36]       ; cv0
    call    er_render_ir_push_textured_vertex_ex

    ; Vertex 5: (x0+w, y0+h, cu1, cv1, color) — same as vertex 3
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, r15d
    movss   xmm0, [rsp]            ; x0
    addss   xmm0, [rsp + 8]        ; + w
    movss   xmm1, [rsp + 4]        ; y0
    addss   xmm1, [rsp + 12]       ; + h
    movss   xmm2, [rsp + 40]       ; cu1
    movss   xmm3, [rsp + 44]       ; cv1
    call    er_render_ir_push_textured_vertex_ex

    ; Vertex 6: (x0, y0+h, cu0, cv1, color)
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, r15d
    movss   xmm0, [rsp]            ; x0
    movss   xmm1, [rsp + 4]        ; y0
    addss   xmm1, [rsp + 12]       ; + h
    movss   xmm2, [rsp + 32]       ; cu0
    movss   xmm3, [rsp + 44]       ; cv1
    call    er_render_ir_push_textured_vertex_ex

    xor     eax, eax
    jmp     .cleanup_tq

.ret0_tq:
    xor     eax, eax
    jmp     .cleanup_tq

.budget_tq:
    mov     eax, -1
.cleanup_tq:
    add     rsp, 64
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Count validation helpers
; ==================================================================

; Returns number of complete rect instances, or -1 if misaligned.
; rdi = len (in float units)
; returns: rax = count or -2 on invalid
; ==================================================================
er_fn er_render_ir_rect_count
    mov     rax, rdi
    xor     edx, edx
    mov     ecx, RENDER_IR_RECT_FLOAT_STRIDE
    div     rcx
    test    rdx, rdx
    jnz     .invalid_cnt
    ret
.invalid_cnt:
    mov     rax, RENDER_IR_INVALID
    ret

; ==================================================================
; usize er_render_ir_textured_vertex_count(usize len)
; Returns number of complete textured vertices, or -2 if misaligned.
; rdi = len (in float units)
; returns: rax = count or -2 on invalid
; ==================================================================
er_fn er_render_ir_textured_vertex_count
    mov     rax, rdi
    mov     rdx, rax
    and     edx, 7          ; rem = len & (STRIDE - 1)
    shr     rax, 3          ; count = len >> 3 (STRIDE = 8 = 2^3)
    test    rdx, rdx
    jnz     .invalid_vtx
    ret
.invalid_vtx:
    mov     rax, RENDER_IR_INVALID
    ret

; ==================================================================
; usize er_render_ir_icon_count(usize len)
; Returns number of complete icon instances, or -2 if misaligned.
; rdi = len (in float units)
; returns: rax = count or -2 on invalid
; ==================================================================
er_fn er_render_ir_icon_count
    mov     rax, rdi
    xor     edx, edx
    mov     ecx, RENDER_IR_ICON_FLOAT_STRIDE
    div     rcx
    test    rdx, rdx
    jnz     .invalid_icon
    ret
.invalid_icon:
    mov     rax, RENDER_IR_INVALID
    ret

; ==================================================================
; usize er_render_ir_icon_line_vertex_count(usize len)
; Returns number of complete icon line vertices, or -2 if misaligned.
; rdi = len (in float units)
; returns: rax = count or -2 on invalid
; ==================================================================
er_fn er_render_ir_icon_line_vertex_count
    mov     rax, rdi
    xor     edx, edx
    mov     ecx, RENDER_IR_ICON_LINE_FLOAT_STRIDE
    div     rcx
    test    rdx, rdx
    jnz     .invalid_ilv
    ret
.invalid_ilv:
    mov     rax, RENDER_IR_INVALID
    ret

; ==================================================================
; int er_render_ir_validate_buffers(usize *lens[9], usize caps[9])
; Validate all 9 buffer lengths against capacities.
; rdi = pointer to array of 9 usize length values
; rsi = pointer to array of 9 usize capacity values
; returns: rax = 0 if all valid, -2 if any invalid
; ==================================================================
er_fn er_render_ir_validate_buffers
    push    rbx
    mov     rbx, rsi        ; save caps pointer
    xor     ecx, ecx        ; counter = 0
.loop:
    mov     rax, [rdi + rcx*8]  ; len[i]
    mov     rdx, [rbx + rcx*8]  ; cap[i]
    cmp     rax, rdx
    ja      .invalid_vb
    inc     ecx
    cmp     ecx, 9
    jb      .loop
    xor     eax, eax
    pop     rbx
    ret
.invalid_vb:
    mov     rax, RENDER_IR_INVALID
    pop     rbx
    ret

; ==================================================================
; Internal helpers
; ==================================================================

; Pack single float channel to u8 (0..255)
; xmm0 = value (0..1)
; returns: al = u8
_ir_pack_channel:
    maxss   xmm0, [rel float_zero]
    minss   xmm0, [rel float_one]
    mulss   xmm0, [rel float_255]
    addss   xmm0, [rel float_half]
    cvtss2si eax, xmm0
    test    eax, eax
    js      .clamp_low_pc
    cmp     eax, 255
    jg      .clamp_high_pc
    ret
.clamp_low_pc:
    xor     eax, eax
    ret
.clamp_high_pc:
    mov     eax, 255
    ret

; Pack 4 RGBA floats to u32 (0xAABBGGRR LE)
; rdi = pointer to [r,g,b,a] floats
; returns: eax = packed u32
_ir_pack_color:
    push    rbx
    sub     rsp, 8

    movss   xmm0, [rdi]
    call    _ir_pack_channel
    mov     [rsp], al

    movss   xmm0, [rdi + 4]
    call    _ir_pack_channel
    mov     [rsp + 1], al

    movss   xmm0, [rdi + 8]
    call    _ir_pack_channel
    mov     [rsp + 2], al

    movss   xmm0, [rdi + 12]
    call    _ir_pack_channel
    mov     [rsp + 3], al

    mov     eax, [rsp]
    add     rsp, 8
    pop     rbx
    ret

; ==================================================================
; void sw_fb_render_ir_rects(u32 fb_width, u32 fb_height, u32 *pixels,
;                            const float *rect_buf, u32 rect_count)
; Render rect IR buffer entries to a software framebuffer.
; rdi = fb_width, rsi = fb_height, rdx = pixels
; rcx = rect_buf, r8 = rect_count
; ==================================================================
er_fn sw_fb_render_ir_rects
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15, rcx
    mov     ebx, r8d

    test    ebx, ebx
    jz      .done_rr

    xor     ebp, ebp

.loop_rr:
    mov     eax, ebp
    imul    eax, RENDER_IR_RECT_BYTE_STRIDE
    lea     rcx, [r15 + rax]

    lea     rdi, [rcx + RECT_R*4]
    call    _ir_pack_color
    mov     r8d, eax

    movss   xmm0, [rcx + RECT_MODE*4]
    cvtss2si eax, xmm0
    cmp     eax, RENDER_IR_RECT_MODE_SHADOW
    je      .shadow_rr

.fill_rr:
    mov     edi, r12d
    mov     esi, r13d
    mov     rdx, r14
    call    sw_fb_fill
    jmp     .next_rr

.shadow_rr:
    push    rcx
    push    r8

    lea     rdi, [rcx + RECT_R2*4]
    call    _ir_pack_color
    mov     r9d, eax

    pop     r8
    pop     rcx

    sub     rsp, 16
    movss   xmm0, [rcx + RECT_X*4]
    addss   xmm0, [rcx + RECT_RADIUS*4]
    movss   [rsp], xmm0
    movss   xmm0, [rcx + RECT_Y*4]
    addss   xmm0, [rcx + RECT_RADIUS*4]
    movss   [rsp + 4], xmm0
    movss   xmm0, [rcx + RECT_W*4]
    movss   [rsp + 8], xmm0
    movss   xmm0, [rcx + RECT_H*4]
    movss   [rsp + 12], xmm0

    mov     edi, r12d
    mov     esi, r13d
    mov     rdx, r14
    lea     rcx, [rsp]
    push    r8
    mov     r8d, r9d
    call    sw_fb_fill
    pop     r8

    add     rsp, 16

    mov     eax, ebp
    imul    eax, RENDER_IR_RECT_BYTE_STRIDE
    lea     rcx, [r15 + rax]
    jmp     .fill_rr

.next_rr:
    inc     ebp
    cmp     ebp, ebx
    jb      .loop_rr

.done_rr:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; void sw_fb_render_ir_icons(u32 fb_width, u32 fb_height, u32 *pixels,
;                            const float *icon_buf, u32 icon_count)
; Render icon IR buffer entries to a software framebuffer.
; rdi = fb_width, rsi = fb_height, rdx = pixels
; rcx = icon_buf, r8 = icon_count
; ==================================================================
er_fn sw_fb_render_ir_icons
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15, rcx
    mov     ebx, r8d

    test    ebx, ebx
    jz      .done_ri

    xor     ebp, ebp

.loop_ri:
    mov     eax, ebp
    imul    eax, RENDER_IR_ICON_BYTE_STRIDE
    lea     rcx, [r15 + rax]

    lea     rdi, [rcx + ICON_R*4]
    call    _ir_pack_color
    mov     r8d, eax

    mov     edi, r12d
    mov     esi, r13d
    mov     rdx, r14
    call    sw_fb_fill

    inc     ebp
    cmp     ebp, ebx
    jb      .loop_ri

.done_ri:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
