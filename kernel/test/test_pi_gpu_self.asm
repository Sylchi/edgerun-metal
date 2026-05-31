@ EdgeRun Pi Zero W VideoCore mailbox/GPU emulator test.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ MAILBOX_RD,   0x00
.equ MAILBOX_WR,   0x00
.equ MAILBOX_STA,  0x18
.equ PROPERTY_CHANNEL, 8
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
.equ GPU_FB_SIZE, 1232640
.equ GPU_FB_PITCH, 2568
.equ GPU_FB_COLOR, 0x11223344
.equ GPU_FB_RECT_COLOR, 0x55667788
.equ GPU_FB_PAD_SENTINEL, 0xa5a5a5a5
.equ GPU_BLIT_SRC_PITCH, 16
.equ GPU_ALPHA_DST, 0x12202020
.equ GPU_ALPHA_BLEND_SRC, 0x80e06020
.equ GPU_ALPHA_BLEND_OUT, 0x12804020
.equ GPU_COPY_A, 0x0a0a0a0a
.equ GPU_COPY_B, 0x0b0b0b0b
.equ GPU_COPY_C, 0x0c0c0c0c
.equ GPU_COPY_D, 0x0d0d0d0d
.equ GPU_COPY_E, 0x0e0e0e0e
.equ GPU_COPY_F, 0x0f0f0f0f
.equ GPU_GLYPH_COLOR, 0x33445566
.equ GPU_TEXT_COLOR, 0x778899aa

.extern gpu_framebuffer_init
.extern gpu_framebuffer_fill
.extern gpu_framebuffer_fill_rect
.extern gpu_framebuffer_blit
.extern gpu_framebuffer_blit_alpha
.extern gpu_framebuffer_copy_rect
.extern gpu_framebuffer_draw_glyph
.extern gpu_framebuffer_draw_text8

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top
    bl      reset_gpu_emulator
    ldr     r0, =fb_out
    bl      gpu_framebuffer_init
    cmp     r0, #0
    movne   r4, #1
    bne     .Lfail_code

    bl      check_mailbox_write
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      check_framebuffer_out
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    ldr     r1, =GPU_FB_COLOR
    bl      gpu_framebuffer_fill
    cmp     r0, #0
    movne   r4, #41
    bne     .Lfail_code

    bl      check_framebuffer_fill
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      reset_framebuffer
    ldr     r0, =fb_out
    mov     r1, #2
    mov     r2, #3
    mov     r3, #4
    ldr     r4, =GPU_FB_RECT_COLOR
    push    {r4}
    mov     r4, #2
    push    {r4}
    bl      gpu_framebuffer_fill_rect
    add     sp, sp, #8
    cmp     r0, #0
    movne   r4, #51
    bne     .Lfail_code

    bl      check_framebuffer_rect
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    ldr     r1, =638
    mov     r2, #0
    mov     r3, #4
    ldr     r4, =GPU_FB_RECT_COLOR
    push    {r4}
    mov     r4, #1
    push    {r4}
    bl      gpu_framebuffer_fill_rect
    add     sp, sp, #8
    cmp     r0, #1
    movne   r4, #57
    bne     .Lfail_code

    bl      reset_framebuffer
    ldr     r0, =fb_out
    mov     r1, #5
    mov     r2, #6
    ldr     r3, =blit_source
    mov     r4, #2
    push    {r4}
    mov     r4, #3
    push    {r4}
    mov     r4, #GPU_BLIT_SRC_PITCH
    push    {r4}
    bl      gpu_framebuffer_blit
    add     sp, sp, #12
    cmp     r0, #0
    movne   r4, #61
    bne     .Lfail_code

    bl      check_framebuffer_blit
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    mov     r1, #0
    mov     r2, #0
    ldr     r3, =blit_source
    mov     r4, #1
    push    {r4}
    mov     r4, #2
    push    {r4}
    mov     r4, #4
    push    {r4}
    bl      gpu_framebuffer_blit
    add     sp, sp, #12
    cmp     r0, #1
    movne   r4, #68
    bne     .Lfail_code

    bl      reset_framebuffer
    bl      init_alpha_dest
    ldr     r0, =fb_out
    mov     r1, #9
    mov     r2, #10
    ldr     r3, =alpha_source
    mov     r4, #1
    push    {r4}
    mov     r4, #3
    push    {r4}
    mov     r4, #12
    push    {r4}
    bl      gpu_framebuffer_blit_alpha
    add     sp, sp, #12
    cmp     r0, #0
    movne   r4, #71
    bne     .Lfail_code

    bl      check_framebuffer_alpha_blit
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    mov     r1, #0
    mov     r2, #0
    ldr     r3, =alpha_source
    mov     r4, #1
    push    {r4}
    mov     r4, #2
    push    {r4}
    mov     r4, #4
    push    {r4}
    bl      gpu_framebuffer_blit_alpha
    add     sp, sp, #12
    cmp     r0, #1
    movne   r4, #77
    bne     .Lfail_code

    bl      reset_framebuffer
    bl      init_copy_source
    ldr     r0, =fb_out
    mov     r1, #2
    mov     r2, #3
    mov     r3, #1
    mov     r4, #2
    push    {r4}
    mov     r4, #3
    push    {r4}
    mov     r4, #2
    push    {r4}
    bl      gpu_framebuffer_copy_rect
    add     sp, sp, #12
    cmp     r0, #0
    movne   r4, #81
    bne     .Lfail_code

    bl      check_framebuffer_copy_rect
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    ldr     r1, =639
    mov     r2, #0
    mov     r3, #0
    mov     r4, #1
    push    {r4}
    mov     r4, #2
    push    {r4}
    mov     r4, #0
    push    {r4}
    bl      gpu_framebuffer_copy_rect
    add     sp, sp, #12
    cmp     r0, #1
    movne   r4, #89
    bne     .Lfail_code

    bl      reset_framebuffer
    ldr     r0, =fb_out
    mov     r1, #12
    mov     r2, #13
    ldr     r3, =glyph_source
    ldr     r4, =GPU_GLYPH_COLOR
    push    {r4}
    bl      gpu_framebuffer_draw_glyph
    add     sp, sp, #4
    cmp     r0, #0
    movne   r4, #91
    bne     .Lfail_code

    bl      check_framebuffer_glyph
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    ldr     r1, =633
    mov     r2, #0
    ldr     r3, =glyph_source
    ldr     r4, =GPU_GLYPH_COLOR
    push    {r4}
    bl      gpu_framebuffer_draw_glyph
    add     sp, sp, #4
    cmp     r0, #1
    movne   r4, #97
    bne     .Lfail_code

    ldr     r0, =fb_out
    mov     r1, #0
    mov     r2, #0
    mov     r3, #0
    ldr     r4, =GPU_GLYPH_COLOR
    push    {r4}
    bl      gpu_framebuffer_draw_glyph
    add     sp, sp, #4
    cmp     r0, #1
    movne   r4, #98
    bne     .Lfail_code

    bl      reset_framebuffer
    ldr     r0, =fb_out
    mov     r1, #24
    mov     r2, #25
    ldr     r3, =text_source
    ldr     r4, =GPU_TEXT_COLOR
    push    {r4}
    ldr     r4, =text_glyph_table
    push    {r4}
    bl      gpu_framebuffer_draw_text8
    add     sp, sp, #8
    cmp     r0, #0
    movne   r4, #101
    bne     .Lfail_code

    bl      check_framebuffer_text8
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      reset_framebuffer
    ldr     r0, =fb_out
    ldr     r1, =625
    mov     r2, #0
    ldr     r3, =text_source
    ldr     r4, =GPU_TEXT_COLOR
    push    {r4}
    ldr     r4, =text_glyph_table
    push    {r4}
    bl      gpu_framebuffer_draw_text8
    add     sp, sp, #8
    cmp     r0, #1
    movne   r4, #107
    bne     .Lfail_code

    bl      check_framebuffer_text8_reject_clean
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    ldr     r0, =fb_out
    mov     r1, #0
    mov     r2, #0
    ldr     r3, =text_source
    ldr     r4, =GPU_TEXT_COLOR
    push    {r4}
    mov     r4, #0
    push    {r4}
    bl      gpu_framebuffer_draw_text8
    add     sp, sp, #8
    cmp     r0, #1
    movne   r4, #108
    bne     .Lfail_code

    mov     r0, #0
    b       semihost_exit

.Lfail_code:
    mov     r0, r4
    b       semihost_exit

check_mailbox_write:
    push    {lr}
    ldr     r1, =mailbox_write_count
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #11
    popne   {pc}
    ldr     r1, =mailbox_buffer_ptr
    ldr     r0, [r1]
    cmp     r0, #0
    moveq   r0, #12
    popeq   {pc}
    ldr     r1, [r0]
    cmp     r1, #120
    movne   r0, #13
    popne   {pc}
    ldr     r1, [r0, #8]
    ldr     r2, =TAG_SET_PHYSICAL_SIZE
    cmp     r1, r2
    movne   r0, #14
    popne   {pc}
    ldr     r1, [r0, #20]
    ldr     r2, =GPU_FB_WIDTH
    cmp     r1, r2
    movne   r0, #15
    popne   {pc}
    ldr     r1, [r0, #24]
    ldr     r2, =GPU_FB_HEIGHT
    cmp     r1, r2
    movne   r0, #16
    popne   {pc}
    ldr     r1, [r0, #28]
    ldr     r2, =TAG_SET_VIRTUAL_SIZE
    cmp     r1, r2
    movne   r0, #17
    popne   {pc}
    ldr     r1, [r0, #48]
    ldr     r2, =TAG_SET_DEPTH
    cmp     r1, r2
    movne   r0, #18
    popne   {pc}
    ldr     r1, [r0, #60]
    cmp     r1, #GPU_FB_DEPTH
    movne   r0, #19
    popne   {pc}
    ldr     r1, [r0, #64]
    ldr     r2, =TAG_SET_PIXEL_ORDER
    cmp     r1, r2
    movne   r0, #20
    popne   {pc}
    ldr     r1, [r0, #76]
    cmp     r1, #GPU_FB_PIXEL_ORDER_RGB
    movne   r0, #21
    popne   {pc}
    ldr     r1, [r0, #80]
    ldr     r2, =TAG_ALLOCATE_BUFFER
    cmp     r1, r2
    movne   r0, #22
    popne   {pc}
    ldr     r1, [r0, #92]
    ldr     r2, =framebuffer
    cmp     r1, r2
    movne   r0, #23
    popne   {pc}
    ldr     r1, [r0, #100]
    ldr     r2, =TAG_GET_PITCH
    cmp     r1, r2
    movne   r0, #24
    popne   {pc}
    ldr     r1, [r0, #116]
    cmp     r1, #TAG_LAST
    movne   r0, #25
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_framebuffer_out:
    push    {lr}
    ldr     r1, =fb_out
    ldr     r0, [r1]
    ldr     r2, =framebuffer
    cmp     r0, r2
    movne   r0, #31
    popne   {pc}
    ldr     r0, [r1, #4]
    ldr     r2, =GPU_FB_SIZE
    cmp     r0, r2
    movne   r0, #32
    popne   {pc}
    ldr     r0, [r1, #8]
    ldr     r2, =GPU_FB_PITCH
    cmp     r0, r2
    movne   r0, #33
    popne   {pc}
    ldr     r0, [r1, #12]
    ldr     r2, =GPU_FB_WIDTH
    cmp     r0, r2
    movne   r0, #34
    popne   {pc}
    ldr     r0, [r1, #16]
    ldr     r2, =GPU_FB_HEIGHT
    cmp     r0, r2
    movne   r0, #35
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_framebuffer_fill:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r0, [r4]
    ldr     r1, =GPU_FB_COLOR
    cmp     r0, r1
    movne   r0, #42
    popne   {r4, pc}
    ldr     r0, [r4, #2556]
    cmp     r0, r1
    movne   r0, #43
    popne   {r4, pc}
    ldr     r0, [r4, #2560]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #44
    popne   {r4, pc}
    ldr     r0, [r4, #2568]
    ldr     r1, =GPU_FB_COLOR
    cmp     r0, r1
    movne   r0, #45
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    ldr     r3, =479
    mul     r0, r2, r3
    ldr     r2, =2556
    add     r0, r0, r2
    ldr     r0, [r4, r0]
    cmp     r0, r1
    movne   r0, #46
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_framebuffer_rect:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r0, [r4]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #52
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #3
    mul     r0, r2, r3
    add     r0, r0, #8
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_RECT_COLOR
    cmp     r0, r1
    movne   r0, #53
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #3
    mul     r0, r2, r3
    add     r0, r0, #24
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #54
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #4
    mul     r0, r2, r3
    add     r0, r0, #20
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_RECT_COLOR
    cmp     r0, r1
    movne   r0, #55
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #5
    mul     r0, r2, r3
    add     r0, r0, #8
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #56
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_framebuffer_blit:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #6
    mul     r0, r2, r3
    add     r0, r0, #20
    ldr     r0, [r4, r0]
    ldr     r1, =0x10111213
    cmp     r0, r1
    movne   r0, #62
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #6
    mul     r0, r2, r3
    add     r0, r0, #32
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #63
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #7
    mul     r0, r2, r3
    add     r0, r0, #20
    ldr     r0, [r4, r0]
    ldr     r1, =0x20212223
    cmp     r0, r1
    movne   r0, #64
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #7
    mul     r0, r2, r3
    add     r0, r0, #24
    ldr     r0, [r4, r0]
    ldr     r1, =0x24252627
    cmp     r0, r1
    movne   r0, #65
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #8
    mul     r0, r2, r3
    add     r0, r0, #20
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #66
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

init_alpha_dest:
    push    {lr}
    ldr     r1, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #10
    mul     r0, r2, r3
    add     r1, r1, r0
    add     r1, r1, #36
    ldr     r0, =0x01020304
    str     r0, [r1]
    ldr     r0, =GPU_ALPHA_DST
    str     r0, [r1, #4]
    ldr     r0, =0x00303030
    str     r0, [r1, #8]
    pop     {pc}

check_framebuffer_alpha_blit:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #10
    mul     r0, r2, r3
    add     r4, r4, r0
    add     r4, r4, #36
    ldr     r0, [r4]
    ldr     r1, =0x01020304
    cmp     r0, r1
    movne   r0, #72
    popne   {r4, pc}
    ldr     r0, [r4, #4]
    ldr     r1, =GPU_ALPHA_BLEND_OUT
    cmp     r0, r1
    movne   r0, #73
    popne   {r4, pc}
    ldr     r0, [r4, #8]
    ldr     r1, =0xff010203
    cmp     r0, r1
    movne   r0, #74
    popne   {r4, pc}
    ldr     r0, [r4, #12]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #75
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

init_copy_source:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #2
    mul     r0, r2, r3
    add     r4, r4, r0
    add     r4, r4, #4
    ldr     r0, =GPU_COPY_A
    str     r0, [r4]
    ldr     r0, =GPU_COPY_B
    str     r0, [r4, #4]
    ldr     r0, =GPU_COPY_C
    str     r0, [r4, #8]
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #3
    mul     r0, r2, r3
    add     r4, r4, r0
    add     r4, r4, #4
    ldr     r0, =GPU_COPY_D
    str     r0, [r4]
    ldr     r0, =GPU_COPY_E
    str     r0, [r4, #4]
    ldr     r0, =GPU_COPY_F
    str     r0, [r4, #8]
    pop     {r4, pc}

check_framebuffer_copy_rect:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #3
    mul     r0, r2, r3
    add     r0, r0, #8
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_COPY_A
    cmp     r0, r1
    movne   r0, #82
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #3
    mul     r0, r2, r3
    add     r0, r0, #16
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_COPY_C
    cmp     r0, r1
    movne   r0, #83
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #4
    mul     r0, r2, r3
    add     r0, r0, #8
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_COPY_D
    cmp     r0, r1
    movne   r0, #84
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #4
    mul     r0, r2, r3
    add     r0, r0, #16
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_COPY_F
    cmp     r0, r1
    movne   r0, #85
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #2
    mul     r0, r2, r3
    add     r0, r0, #4
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_COPY_A
    cmp     r0, r1
    movne   r0, #86
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #4
    mul     r0, r2, r3
    add     r0, r0, #20
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #87
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_framebuffer_glyph:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #13
    mul     r0, r2, r3
    add     r0, r0, #48
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_GLYPH_COLOR
    cmp     r0, r1
    movne   r0, #92
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #13
    mul     r0, r2, r3
    add     r0, r0, #52
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #93
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #20
    mul     r0, r2, r3
    add     r0, r0, #76
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_GLYPH_COLOR
    cmp     r0, r1
    movne   r0, #94
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #20
    mul     r0, r2, r3
    add     r0, r0, #72
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #95
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #21
    mul     r0, r2, r3
    add     r0, r0, #48
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #96
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_framebuffer_text8:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #25
    mul     r0, r2, r3
    add     r0, r0, #96
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_TEXT_COLOR
    cmp     r0, r1
    movne   r0, #102
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #25
    mul     r0, r2, r3
    add     r0, r0, #100
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #103
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #25
    mul     r0, r2, r3
    add     r0, r0, #128
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #104
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    mov     r3, #25
    mul     r0, r2, r3
    add     r0, r0, #156
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_TEXT_COLOR
    cmp     r0, r1
    movne   r0, #105
    popne   {r4, pc}
    ldr     r2, =GPU_FB_PITCH
    ldr     r3, =33
    mul     r0, r2, r3
    add     r0, r0, #96
    ldr     r0, [r4, r0]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #106
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_framebuffer_text8_reject_clean:
    push    {r4, lr}
    ldr     r4, =framebuffer
    ldr     r0, [r4, #2500]
    ldr     r1, =GPU_FB_PAD_SENTINEL
    cmp     r0, r1
    movne   r0, #109
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

reset_framebuffer:
    push    {lr}
    ldr     r1, =framebuffer
    ldr     r2, =(GPU_FB_SIZE >> 2)
    ldr     r3, =GPU_FB_PAD_SENTINEL
1:
    str     r3, [r1], #4
    subs    r2, r2, #1
    bne     1b
    pop     {pc}

reset_gpu_emulator:
    push    {lr}
    mov     r0, #0
    ldr     r1, =mailbox_write_count
    str     r0, [r1]
    ldr     r1, =mailbox_last_word
    str     r0, [r1]
    ldr     r1, =mailbox_buffer_ptr
    str     r0, [r1]
    ldr     r1, =fb_out
    mov     r2, #5
1:
    str     r0, [r1], #4
    subs    r2, r2, #1
    bne     1b
    bl      reset_framebuffer
    pop     {pc}

.globl mailbox_mmio_read
mailbox_mmio_read:
    cmp     r0, #MAILBOX_STA
    moveq   r0, #0
    bxeq    lr
    cmp     r0, #MAILBOX_RD
    bne     .Lmailbox_bad_read
    ldr     r1, =mailbox_last_word
    ldr     r0, [r1]
    bx      lr
.Lmailbox_bad_read:
    mov     r0, #0
    bx      lr

.globl mailbox_mmio_write
mailbox_mmio_write:
    cmp     r0, #MAILBOX_WR
    bxne    lr
    ldr     r2, =mailbox_last_word
    str     r1, [r2]
    ldr     r2, =mailbox_write_count
    ldr     r3, [r2]
    add     r3, r3, #1
    str     r3, [r2]
    bic     r1, r1, #0xf
    ldr     r2, =mailbox_buffer_ptr
    str     r1, [r2]
    ldr     r2, =MAILBOX_RESPONSE_OK
    str     r2, [r1, #4]
    ldr     r2, =framebuffer
    str     r2, [r1, #92]
    ldr     r2, =GPU_FB_SIZE
    str     r2, [r1, #96]
    ldr     r2, =GPU_FB_PITCH
    str     r2, [r1, #112]
    bx      lr

semihost_exit:
    ldr     r1, =exit_block
    str     r0, [r1, #4]
    mov     r0, #0x20
    svc     #0x123456
1:  b       1b

.section .data
.align 4
exit_block:
    .word   0x20026
    .word   0
blit_source:
    .word   0x10111213
    .word   0x14151617
    .word   0x18191a1b
    .word   0xdead0000
    .word   0x20212223
    .word   0x24252627
    .word   0x28292a2b
    .word   0xdead0001
alpha_source:
    .word   0x00abcdef
    .word   GPU_ALPHA_BLEND_SRC
    .word   0xff010203
glyph_source:
    .byte   0x80
    .byte   0x40
    .byte   0x20
    .byte   0x10
    .byte   0x08
    .byte   0x04
    .byte   0x02
    .byte   0x01
    .align  4
text_source:
    .byte   0x41
    .byte   0x42
    .byte   0
    .align  4
text_glyph_table:
    .space  (0x41 * 8)
    .byte   0x80
    .byte   0x40
    .byte   0x20
    .byte   0x10
    .byte   0x08
    .byte   0x04
    .byte   0x02
    .byte   0x01
    .byte   0x01
    .byte   0x02
    .byte   0x04
    .byte   0x08
    .byte   0x10
    .byte   0x20
    .byte   0x40
    .byte   0x80
    .align  4

.section .bss
.align 4
fb_out:
    .space  20
mailbox_last_word:
    .space  4
mailbox_buffer_ptr:
    .space  4
mailbox_write_count:
    .space  4
stack_bottom:
    .space  4096
stack_top:
framebuffer:
    .space  GPU_FB_SIZE
