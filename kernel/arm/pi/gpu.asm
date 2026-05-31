@ Raspberry Pi Zero W VideoCore mailbox/GPU property driver -- ARM1176JZF-S.
@
@ Public API:
@   mailbox_call(buf)          r0 = 0 on success
@   gpu_framebuffer_init(out)  r0 = 0 on success
@   gpu_framebuffer_fill(info, color) r0 = 0 on success
@   gpu_framebuffer_fill_rect(info, x, y, w, h, color) r0 = 0 on success
@   gpu_framebuffer_blit(info, x, y, src, src_pitch, w, h) r0 = 0 on success
@   gpu_framebuffer_blit_alpha(info, x, y, src, src_pitch, w, h) r0 = 0 on success
@   gpu_framebuffer_copy_rect(info, dst_x, dst_y, src_x, src_y, w, h) r0 = 0 on success
@   gpu_framebuffer_draw_glyph(info, x, y, glyph, color) r0 = 0 on success
@   gpu_framebuffer_draw_text8(info, x, y, text, glyph_table, color) r0 = 0 on success
@
@ gpu_framebuffer_init writes five words to out:
@   [0] framebuffer bus address
@   [1] framebuffer byte size
@   [2] pitch bytes
@   [3] width
@   [4] height

.syntax unified
.cpu arm1176jzf-s
.arm

.equ PERIPHERAL_BASE, 0x20000000
.equ MAILBOX_BASE,    PERIPHERAL_BASE + 0x0000b880

.equ MAILBOX_RD,   0x00
.equ MAILBOX_WR,   0x00
.equ MAILBOX_STA,  0x18
.equ MAILBOX_FULL,     (1 << 31)
.equ MAILBOX_EMPTY,    (1 << 30)
.equ PROPERTY_CHANNEL, 8
.equ MAILBOX_VALUE_MASK, 0xfffffff0
.equ MAILBOX_RESPONSE_OK, 0x80000000

.equ TAG_SET_PHYSICAL_SIZE, 0x00048003
.equ TAG_SET_VIRTUAL_SIZE,  0x00048004
.equ TAG_SET_DEPTH,         0x00048005
.equ TAG_SET_PIXEL_ORDER,   0x00048006
.equ TAG_ALLOCATE_BUFFER,   0x00040001
.equ TAG_GET_PITCH,         0x00040008
.equ TAG_LAST,              0

.equ GPU_FB_WIDTH,  640
.equ GPU_FB_HEIGHT, 480
.equ GPU_FB_DEPTH,  32
.equ GPU_FB_PIXEL_ORDER_RGB, 1
.equ GPU_FB_ALIGNMENT, 4096
.equ GPU_GLYPH_EDGE, 8
.equ GPU_GLYPH_FIRST_MASK, 0x80

.globl mailbox_call
.globl gpu_framebuffer_init
.globl gpu_framebuffer_fill
.globl gpu_framebuffer_fill_rect
.globl gpu_framebuffer_blit
.globl gpu_framebuffer_blit_alpha
.globl gpu_framebuffer_copy_rect
.globl gpu_framebuffer_draw_glyph
.globl gpu_framebuffer_draw_text8
.weak mailbox_mmio_read
.weak mailbox_mmio_write

@ ---- mailbox_write ----
@ r0 = 28-bit aligned value; writes property-channel mailbox word.
mailbox_write:
    push    {r4, lr}
    and     r4, r0, #MAILBOX_VALUE_MASK
    orr     r4, r4, #PROPERTY_CHANNEL
1:
    mov     r0, #MAILBOX_STA
    bl      mailbox_mmio_read
    tst     r0, #MAILBOX_FULL
    bne     1b
    mov     r0, #MAILBOX_WR
    mov     r1, r4
    bl      mailbox_mmio_write
    pop     {r4, pc}

@ ---- mailbox_read ----
@ Returns r0 = 28-bit aligned buffer address from property channel.
mailbox_read:
    push    {lr}
1:
    mov     r0, #MAILBOX_STA
    bl      mailbox_mmio_read
    tst     r0, #MAILBOX_EMPTY
    bne     1b
    mov     r0, #MAILBOX_RD
    bl      mailbox_mmio_read
    and     r1, r0, #0xf
    cmp     r1, #PROPERTY_CHANNEL
    bne     1b
    and     r0, r0, #MAILBOX_VALUE_MASK
    pop     {pc}

@ ---- mailbox_call ----
@ r0 = 28-bit aligned property buffer.
@ Returns r0 = 0 on success.
mailbox_call:
    push    {r4, lr}
    mov     r4, r0
    bl      mailbox_write
    bl      mailbox_read
    cmp     r0, r4
    bne     .Lmailbox_call_fail
    ldr     r1, [r4, #4]
    ldr     r2, =MAILBOX_RESPONSE_OK
    cmp     r1, r2
    bne     .Lmailbox_call_fail
    mov     r0, #0
    pop     {r4, pc}

.Lmailbox_call_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- gpu_framebuffer_init ----
@ r0 = output buffer for framebuffer address, size, pitch, width, height.
@ Returns r0 = 0 on success.
gpu_framebuffer_init:
    push    {r4, lr}
    mov     r4, r0
    ldr     r0, =gpu_fb_mailbox
    bl      mailbox_call
    cmp     r0, #0
    bne     .Lgpu_fb_fail

    ldr     r1, =gpu_fb_mailbox
    ldr     r0, [r1, #92]
    cmp     r0, #0
    beq     .Lgpu_fb_fail
    str     r0, [r4]
    ldr     r0, [r1, #96]
    cmp     r0, #0
    beq     .Lgpu_fb_fail
    str     r0, [r4, #4]
    ldr     r0, [r1, #112]
    cmp     r0, #0
    beq     .Lgpu_fb_fail
    str     r0, [r4, #8]
    ldr     r0, =GPU_FB_WIDTH
    str     r0, [r4, #12]
    ldr     r0, =GPU_FB_HEIGHT
    str     r0, [r4, #16]
    mov     r0, #0
    pop     {r4, pc}

.Lgpu_fb_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- gpu_framebuffer_fill ----
@ r0 = framebuffer info from gpu_framebuffer_init, r1 = 32-bit ARGB/RGBx color.
@ Returns r0 = 0 on success.
gpu_framebuffer_fill:
    push    {r4, r5, r6, r7, r8, r9, lr}
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_fill_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_fill_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_fill_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_fill_fail
    lsl     r2, r6, #2
    cmp     r5, r2
    blo     .Lgpu_fill_fail
    mov     r8, r1
1:
    mov     r9, r6
    mov     r3, r4
2:
    str     r8, [r3], #4
    subs    r9, r9, #1
    bne     2b
    add     r4, r4, r5
    subs    r7, r7, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, pc}

.Lgpu_fill_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, pc}

@ ---- gpu_framebuffer_fill_rect ----
@ r0 = framebuffer info, r1 = x, r2 = y, r3 = width,
@ [sp] = height, [sp+4] = 32-bit ARGB/RGBx color.
@ Returns r0 = 0 on success.
gpu_framebuffer_fill_rect:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_rect_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_rect_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_rect_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_rect_fail
    cmp     r3, #0
    beq     .Lgpu_rect_fail
    ldr     r8, [sp, #36]
    cmp     r8, #0
    beq     .Lgpu_rect_fail
    add     r9, r1, r3
    cmp     r9, r6
    bhi     .Lgpu_rect_fail
    add     r9, r2, r8
    cmp     r9, r7
    bhi     .Lgpu_rect_fail
    lsl     r9, r6, #2
    cmp     r5, r9
    blo     .Lgpu_rect_fail
    mul     r9, r2, r5
    add     r4, r4, r9
    add     r4, r4, r1, lsl #2
    ldr     r10, [sp, #40]
1:
    mov     r11, r3
    mov     r9, r4
2:
    str     r10, [r9], #4
    subs    r11, r11, #1
    bne     2b
    add     r4, r4, r5
    subs    r8, r8, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_rect_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ---- gpu_framebuffer_blit ----
@ r0 = framebuffer info, r1 = x, r2 = y, r3 = source pixels,
@ [sp] = source pitch bytes, [sp+4] = width, [sp+8] = height.
@ Returns r0 = 0 on success.
gpu_framebuffer_blit:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_blit_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_blit_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_blit_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_blit_fail
    cmp     r3, #0
    beq     .Lgpu_blit_fail
    ldr     r9, [sp, #40]
    cmp     r9, #0
    beq     .Lgpu_blit_fail
    ldr     r8, [sp, #44]
    cmp     r8, #0
    beq     .Lgpu_blit_fail
    ldr     r10, [sp, #36]
    lsl     r11, r9, #2
    cmp     r10, r11
    blo     .Lgpu_blit_fail
    add     r11, r1, r9
    cmp     r11, r6
    bhi     .Lgpu_blit_fail
    add     r11, r2, r8
    cmp     r11, r7
    bhi     .Lgpu_blit_fail
    lsl     r11, r6, #2
    cmp     r5, r11
    blo     .Lgpu_blit_fail
    mul     r11, r2, r5
    add     r4, r4, r11
    add     r4, r4, r1, lsl #2
1:
    mov     r11, r9
    mov     r0, r4
    mov     r1, r3
2:
    ldr     r2, [r1], #4
    str     r2, [r0], #4
    subs    r11, r11, #1
    bne     2b
    add     r4, r4, r5
    add     r3, r3, r10
    subs    r8, r8, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_blit_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ---- gpu_framebuffer_blit_alpha ----
@ r0 = framebuffer info, r1 = x, r2 = y, r3 = source ARGB pixels,
@ [sp] = source pitch bytes, [sp+4] = width, [sp+8] = height.
@ Returns r0 = 0 on success.
gpu_framebuffer_blit_alpha:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_blit_alpha_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_blit_alpha_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_blit_alpha_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_blit_alpha_fail
    cmp     r3, #0
    beq     .Lgpu_blit_alpha_fail
    ldr     r9, [sp, #40]
    cmp     r9, #0
    beq     .Lgpu_blit_alpha_fail
    ldr     r8, [sp, #44]
    cmp     r8, #0
    beq     .Lgpu_blit_alpha_fail
    ldr     r10, [sp, #36]
    lsl     r11, r9, #2
    cmp     r10, r11
    blo     .Lgpu_blit_alpha_fail
    add     r11, r1, r9
    cmp     r11, r6
    bhi     .Lgpu_blit_alpha_fail
    add     r11, r2, r8
    cmp     r11, r7
    bhi     .Lgpu_blit_alpha_fail
    lsl     r11, r6, #2
    cmp     r5, r11
    blo     .Lgpu_blit_alpha_fail
    mul     r11, r2, r5
    add     r4, r4, r11
    add     r4, r4, r1, lsl #2
    mov     r6, r3
    sub     sp, sp, #12
1:
    str     r4, [sp]
    str     r6, [sp, #4]
    str     r9, [sp, #8]
2:
    ldr     r11, [sp, #4]
    ldr     r0, [r11], #4
    str     r11, [sp, #4]
    lsr     r1, r0, #24
    cmp     r1, #0
    beq     4f
    ldr     r11, [sp]
    cmp     r1, #255
    beq     3f
    ldr     r2, [r11]
    bl      gpu_alpha_blend_pixel
3:
    ldr     r11, [sp]
    str     r0, [r11]
4:
    ldr     r11, [sp]
    add     r11, r11, #4
    str     r11, [sp]
    ldr     r11, [sp, #8]
    subs    r11, r11, #1
    str     r11, [sp, #8]
    bne     2b
    add     r4, r4, r5
    add     r6, r6, r10
    subs    r8, r8, #1
    bne     1b
    add     sp, sp, #12
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_blit_alpha_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ---- gpu_alpha_blend_pixel ----
@ r0 = source ARGB, r1 = alpha, r2 = destination pixel.
@ Returns r0 = blended pixel, preserving destination top byte.
gpu_alpha_blend_pixel:
    push    {r4, r5, r6, r7, r8, lr}
    mov     r4, r0
    mov     r5, r1
    rsb     r6, r5, #255
    mov     r7, r2
    ldr     r8, =0xff000000
    and     r8, r8, r7

    and     r0, r4, #0xff
    and     r1, r7, #0xff
    mov     r2, r5
    mov     r3, r6
    bl      gpu_alpha_blend_channel
    orr     r8, r8, r0

    lsr     r0, r4, #8
    and     r0, r0, #0xff
    lsr     r1, r7, #8
    and     r1, r1, #0xff
    mov     r2, r5
    mov     r3, r6
    bl      gpu_alpha_blend_channel
    orr     r8, r8, r0, lsl #8

    lsr     r0, r4, #16
    and     r0, r0, #0xff
    lsr     r1, r7, #16
    and     r1, r1, #0xff
    mov     r2, r5
    mov     r3, r6
    bl      gpu_alpha_blend_channel
    orr     r0, r8, r0, lsl #16
    pop     {r4, r5, r6, r7, r8, pc}

@ ---- gpu_alpha_blend_channel ----
@ r0 = source channel, r1 = destination channel, r2 = alpha, r3 = 255-alpha.
@ Returns exact floor((src*a + dst*(255-a) + 127) / 255).
gpu_alpha_blend_channel:
    mul     r0, r2, r0
    mla     r0, r3, r1, r0
    add     r0, r0, #127
    mov     r1, #0
1:
    cmp     r0, #255
    blo     2f
    sub     r0, r0, #255
    add     r1, r1, #1
    b       1b
2:
    mov     r0, r1
    bx      lr

@ ---- gpu_framebuffer_copy_rect ----
@ r0 = framebuffer info, r1 = dst_x, r2 = dst_y, r3 = src_x,
@ [sp] = src_y, [sp+4] = width, [sp+8] = height.
@ Returns r0 = 0 on success. Handles overlapping source/destination.
gpu_framebuffer_copy_rect:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    sub     sp, sp, #16
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_copy_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_copy_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_copy_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_copy_fail
    ldr     r8, [sp, #56]
    cmp     r8, #0
    beq     .Lgpu_copy_fail
    ldr     r9, [sp, #60]
    cmp     r9, #0
    beq     .Lgpu_copy_fail
    str     r8, [sp]
    str     r9, [sp, #4]
    ldr     r10, [sp, #52]
    add     r11, r1, r8
    cmp     r11, r6
    bhi     .Lgpu_copy_fail
    add     r11, r3, r8
    cmp     r11, r6
    bhi     .Lgpu_copy_fail
    add     r11, r2, r9
    cmp     r11, r7
    bhi     .Lgpu_copy_fail
    add     r11, r10, r9
    cmp     r11, r7
    bhi     .Lgpu_copy_fail
    lsl     r11, r6, #2
    cmp     r5, r11
    blo     .Lgpu_copy_fail

    mul     r11, r2, r5
    add     r8, r4, r11
    add     r8, r8, r1, lsl #2
    mul     r11, r10, r5
    add     r9, r4, r11
    add     r9, r9, r3, lsl #2
    str     r8, [sp, #8]
    str     r9, [sp, #12]
    cmp     r8, r9
    bhi     .Lgpu_copy_backward

.Lgpu_copy_forward_rows:
    ldr     r8, [sp, #8]
    ldr     r9, [sp, #12]
    ldr     r10, [sp, #4]
1:
    ldr     r11, [sp]
    mov     r0, r8
    mov     r1, r9
2:
    ldr     r2, [r1], #4
    str     r2, [r0], #4
    subs    r11, r11, #1
    bne     2b
    add     r8, r8, r5
    add     r9, r9, r5
    subs    r10, r10, #1
    bne     1b
    add     sp, sp, #16
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_copy_backward:
    ldr     r8, [sp, #8]
    ldr     r9, [sp, #12]
    ldr     r10, [sp, #4]
    subs    r10, r10, #1
    mul     r11, r10, r5
    add     r8, r8, r11
    add     r9, r9, r11
    ldr     r11, [sp]
    sub     r11, r11, #1
    add     r8, r8, r11, lsl #2
    add     r9, r9, r11, lsl #2
    ldr     r10, [sp, #4]
1:
    ldr     r11, [sp]
    mov     r0, r8
    mov     r1, r9
2:
    ldr     r2, [r1], #-4
    str     r2, [r0], #-4
    subs    r11, r11, #1
    bne     2b
    sub     r8, r8, r5
    sub     r9, r9, r5
    subs    r10, r10, #1
    bne     1b
    add     sp, sp, #16
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_copy_fail:
    add     sp, sp, #16
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ---- gpu_framebuffer_draw_glyph ----
@ r0 = framebuffer info, r1 = x, r2 = y, r3 = 8-byte glyph bitmap,
@ [sp] = 32-bit color. Glyph bits are MSB-left and zero bits are transparent.
@ Returns r0 = 0 on success.
gpu_framebuffer_draw_glyph:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_glyph_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_glyph_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_glyph_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_glyph_fail
    cmp     r3, #0
    beq     .Lgpu_glyph_fail
    add     r10, r1, #GPU_GLYPH_EDGE
    cmp     r10, r6
    bhi     .Lgpu_glyph_fail
    add     r10, r2, #GPU_GLYPH_EDGE
    cmp     r10, r7
    bhi     .Lgpu_glyph_fail
    lsl     r10, r6, #2
    cmp     r5, r10
    blo     .Lgpu_glyph_fail
    mul     r10, r2, r5
    add     r4, r4, r10
    add     r4, r4, r1, lsl #2
    ldr     r11, [sp, #36]
    mov     r8, r3
    mov     r9, #GPU_GLYPH_EDGE
1:
    ldrb    r6, [r8], #1
    mov     r7, #GPU_GLYPH_EDGE
    mov     r10, r4
    mov     r0, #GPU_GLYPH_FIRST_MASK
2:
    tst     r6, r0
    strne   r11, [r10]
    add     r10, r10, #4
    lsr     r0, r0, #1
    subs    r7, r7, #1
    bne     2b
    add     r4, r4, r5
    subs    r9, r9, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_glyph_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ---- gpu_framebuffer_draw_text8 ----
@ r0 = framebuffer info, r1 = x, r2 = y, r3 = null-terminated text,
@ [sp] = glyph table, [sp+4] = 32-bit color.
@ Glyph table entries are 8 bytes each, indexed directly by byte value.
@ Returns r0 = 0 on success. No wrapping or clipping is performed.
gpu_framebuffer_draw_text8:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    ldr     r4, [r0]
    cmp     r4, #0
    beq     .Lgpu_text_fail
    ldr     r5, [r0, #8]
    cmp     r5, #0
    beq     .Lgpu_text_fail
    ldr     r6, [r0, #12]
    cmp     r6, #0
    beq     .Lgpu_text_fail
    ldr     r7, [r0, #16]
    cmp     r7, #0
    beq     .Lgpu_text_fail
    cmp     r3, #0
    beq     .Lgpu_text_fail
    ldr     r10, [sp, #36]
    cmp     r10, #0
    beq     .Lgpu_text_fail
    add     r0, r2, #GPU_GLYPH_EDGE
    cmp     r0, r7
    bhi     .Lgpu_text_fail
    lsl     r0, r6, #2
    cmp     r5, r0
    blo     .Lgpu_text_fail
    mov     r8, r1
    mov     r9, r3
.Lgpu_text_preflight:
    ldrb    r0, [r9], #1
    cmp     r0, #0
    beq     .Lgpu_text_preflight_done
    add     r8, r8, #GPU_GLYPH_EDGE
    cmp     r8, r6
    bhi     .Lgpu_text_fail
    b       .Lgpu_text_preflight

.Lgpu_text_preflight_done:
    mul     r0, r2, r5
    add     r4, r4, r0
    add     r4, r4, r1, lsl #2
    mov     r8, r1
    mov     r9, r3
    ldr     r11, [sp, #40]

.Lgpu_text_next:
    ldrb    r0, [r9], #1
    cmp     r0, #0
    beq     .Lgpu_text_done
    add     r0, r10, r0, lsl #3
    mov     r1, r4
    mov     r2, #GPU_GLYPH_EDGE
1:
    ldrb    r3, [r0], #1
    mov     r7, #GPU_GLYPH_EDGE
    mov     r12, r1
    mov     lr, #GPU_GLYPH_FIRST_MASK
2:
    tst     r3, lr
    strne   r11, [r12]
    add     r12, r12, #4
    lsr     lr, lr, #1
    subs    r7, r7, #1
    bne     2b
    add     r1, r1, r5
    subs    r2, r2, #1
    bne     1b
    add     r8, r8, #GPU_GLYPH_EDGE
    add     r4, r4, #(GPU_GLYPH_EDGE * 4)
    b       .Lgpu_text_next

.Lgpu_text_done:
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lgpu_text_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ---- default MMIO hooks ----
mailbox_mmio_read:
    ldr     r1, =MAILBOX_BASE
    ldr     r0, [r1, r0]
    bx      lr

mailbox_mmio_write:
    ldr     r2, =MAILBOX_BASE
    str     r1, [r2, r0]
    bx      lr

.section .data
.align 4
gpu_fb_mailbox:
    .word   120
    .word   0
    .word   TAG_SET_PHYSICAL_SIZE
    .word   8
    .word   8
    .word   GPU_FB_WIDTH
    .word   GPU_FB_HEIGHT
    .word   TAG_SET_VIRTUAL_SIZE
    .word   8
    .word   8
    .word   GPU_FB_WIDTH
    .word   GPU_FB_HEIGHT
    .word   TAG_SET_DEPTH
    .word   4
    .word   4
    .word   GPU_FB_DEPTH
    .word   TAG_SET_PIXEL_ORDER
    .word   4
    .word   4
    .word   GPU_FB_PIXEL_ORDER_RGB
    .word   TAG_ALLOCATE_BUFFER
    .word   8
    .word   4
    .word   GPU_FB_ALIGNMENT
    .word   0
    .word   TAG_GET_PITCH
    .word   4
    .word   0
    .word   0
    .word   TAG_LAST
