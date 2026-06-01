; EdgeRun software framebuffer — x86_64 assembly
; Pixel-level operations for the software renderer backend.
; System V AMD64 ABI, freestanding.

%include "x86_64/macros.inc"

SECTION .rodata
align 8
ceil_addend:    dd 0x3F7FFFFE       ; 0.99999988f → add then trunc to get ceil

SECTION .text

; ==================================================================
; void sw_fb_fill(usize width, usize height, u32 *pixels,
;                 const float *bounds, u32 color)
; Fill a rectangle with a solid color.
; rdi = width (pixels), rsi = height (pixels)
; rdx = pixels (u32 frame buffer, row-major)
; rcx = bounds ptr (4 floats: x, y, w, h)
; r8  = color (packed u32 0xAABBGGRR on LE)
; ==================================================================
er_fn sw_fb_fill
    er_frame_push_regs rbx, r12, r13, r14, r15

    mov     r12, rdi               ; width
    mov     r13, rsi               ; height
    mov     r14, rdx               ; pixels
    mov     r15, r8                ; color

    ; x0 = clamp(floor(bounds.x), 0, width)
    movss   xmm0, [rcx]
    cvttss2si eax, xmm0
    xor     edx, edx
    cmp     eax, edx
    cmovl   eax, edx
    cmp     eax, r12d
    cmova   eax, r12d
    mov     r8d, eax               ; r8d = x0

    ; y0 = clamp(floor(bounds.y), 0, height)
    movss   xmm0, [rcx + 4]
    cvttss2si eax, xmm0
    xor     edx, edx
    cmp     eax, edx
    cmovl   eax, edx
    cmp     eax, r13d
    cmova   eax, r13d
    mov     r9d, eax               ; r9d = y0

    ; x1 = clamp(ceil(bounds.x + bounds.w), 0, width)
    movss   xmm0, [rcx]
    addss   xmm0, [rcx + 8]
    addss   xmm0, [rel ceil_addend]
    cvttss2si eax, xmm0
    xor     edx, edx
    cmp     eax, edx
    cmovl   eax, edx
    cmp     eax, r12d
    cmova   eax, r12d
    mov     r10d, eax              ; r10d = x1

    ; y1 = clamp(ceil(bounds.y + bounds.h), 0, height)
    movss   xmm0, [rcx + 4]
    addss   xmm0, [rcx + 12]
    addss   xmm0, [rel ceil_addend]
    cvttss2si eax, xmm0
    xor     edx, edx
    cmp     eax, edx
    cmovl   eax, edx
    cmp     eax, r13d
    cmova   eax, r13d
    mov     r11d, eax              ; r11d = y1

    ; if x1 <= x0 or y1 <= y0 → early return
    cmp     r10d, r8d
    jle     .early_ret_fill
    cmp     r11d, r9d
    jle     .early_ret_fill

    ; Compute start pointer = pixels + y0 * width + x0
    mov     eax, r9d
    mul     r12d
    add     eax, r8d
    lea     r13, [r14 + rax*4]    ; r13 = row pointer (incremented by pitch)

    mov     ecx, r10d
    sub     ecx, r8d              ; ecx = pixels per row
    mov     eax, r15d             ; color
    shl     r12d, 2               ; r12d = pitch in bytes (width * 4)

.row_loop_fill:
    mov     rdi, r13
    push    rcx                   ; save count
    rep     stosd
    pop     rcx
    add     r13, r12              ; next row by pitch

    dec     r11d
    cmp     r11d, r9d
    ja      .row_loop_fill

.early_ret_fill:
    er_pop_ret rbp, rbx, r12, r13, r14, r15

; ==================================================================
; void sw_fb_blend_pixel(usize width, usize height, u32 *pixels,
;                        usize x, usize y, u32 color, u8 alpha)
; Alpha-blend a pixel onto the framebuffer.
; rdi = width, rsi = height, rdx = pixels
; rcx = x, r8 = y, r9 = color (packed u32 0xAABBGGRR)
; [rbp+16] = alpha (u8, 0-255)
; Uses (x * 257 + 257) >> 16 in place of div 255.
; ==================================================================
er_fn sw_fb_blend_pixel
    er_frame_push_regs rbx, r12

    mov     r12, rdx               ; save pixels ptr

    ; index = y * width + x
    mov     eax, r8d
    mul     edi
    add     eax, ecx
    mov     ebx, eax               ; save index

    ; dst = pixels[index]
    mov     edi, [r12 + rbx*4]

    ; alpha
    movzx   r8d, byte [rbp + 16]
    mov     r10d, 255
    sub     r10d, r8d              ; r10d = inv_alpha

    ; ---- Blend all 4 channels using multiply (no div) ----
    ; Each channel: (src_ch * alpha + dst_ch * inv + 127) * 257 + 257) >> 16

    ; R channel (byte 0)
    movzx   eax, r9b
    imul    eax, r8d
    movzx   ecx, dil
    imul    ecx, r10d
    add     eax, ecx
    add     eax, 127
    imul    eax, 257
    add     eax, 257
    shr     eax, 16
    mov     byte [rsp - 8], al

    ; G channel (byte 1)
    mov     eax, r9d
    shr     eax, 8
    and     eax, 0xFF
    imul    eax, r8d
    mov     ecx, edi
    shr     ecx, 8
    and     ecx, 0xFF
    imul    ecx, r10d
    add     eax, ecx
    add     eax, 127
    imul    eax, 257
    add     eax, 257
    shr     eax, 16
    mov     byte [rsp - 7], al

    ; B channel (byte 2)
    mov     eax, r9d
    shr     eax, 16
    and     eax, 0xFF
    imul    eax, r8d
    mov     ecx, edi
    shr     ecx, 16
    and     ecx, 0xFF
    imul    ecx, r10d
    add     eax, ecx
    add     eax, 127
    imul    eax, 257
    add     eax, 257
    shr     eax, 16
    mov     byte [rsp - 6], al

    ; A channel (byte 3) — different formula:
    ; alpha_final = min(255, dst.a + (color.a * alpha) / 255)
    mov     eax, r9d
    shr     eax, 24
    imul    eax, r8d
    imul    eax, 257
    add     eax, 257
    shr     eax, 16
    mov     ecx, edi
    shr     ecx, 24
    add     eax, ecx
    cmp     eax, 255
    jle     .a_ok_bp
    mov     eax, 255
.a_ok_bp:
    mov     byte [rsp - 5], al

    ; Write back blended pixel
    mov     eax, [rsp - 8]
    mov     [r12 + rbx*4], eax

    er_pop_ret rbp, rbx, r12
