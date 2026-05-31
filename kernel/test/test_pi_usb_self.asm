@ EdgeRun Pi Zero W DWC2 USB host initialization emulator test.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ DWC_GAHBCFG,           0x008
.equ DWC_GUSBCFG,           0x00c
.equ DWC_GRSTCTL,           0x010
.equ DWC_GINTMSK,           0x018
.equ DWC_GRXFSIZ,           0x024
.equ DWC_GNPTXFSIZ,         0x028
.equ DWC_CID,               0x040
.equ DWC_HPTXFSIZ,          0x100
.equ DWC_HCFG,              0x400
.equ DWC_HFIR,              0x404
.equ DWC_HPRT,              0x440

.equ DWC2_CORE_ID_310A,     0x4f54230b
.equ GRSTCTL_CSFTRST,       (1 << 0)
.equ GRSTCTL_AHBIDLE,       (1 << 31)
.equ GAHBCFG_GLBL_INTR_EN,  (1 << 0)
.equ GUSBCFG_PHYIF,         (1 << 6)
.equ GUSBCFG_ULPI_UTMI_SEL, (1 << 4)
.equ GUSBCFG_FS_INTF,       (1 << 5)
.equ GUSBCFG_SRPCAP,        (1 << 8)
.equ GUSBCFG_HNPCAP,        (1 << 9)
.equ GUSBCFG_TRDT_SHIFT,    10
.equ GUSBCFG_TRDT_MASK,     (0xf << 10)
.equ HCFG_FSLSS,            (1 << 2)
.equ HCFG_FSLS_PHOST,       (1 << 3)
.equ HPRT_PRTENA,           (1 << 0)
.equ HPRT_PRTCONNDET,       (1 << 2)
.equ HPRT_PRTRST,           (1 << 6)
.equ HPRT_PRTPWR,           (1 << 9)
.equ HPRT_SPD_FS,           (1 << 17)
.equ HPRR_PRT_SPD_SHIFT,    17
.equ HPRR_PRT_SPD_MASK,     (3 << 17)
.equ GINT_HC_INT,           (1 << 25)
.equ GINT_PRT_INT,          (1 << 24)
.equ GINT_DISC_INT,         (1 << 28)
.equ FIFO_SIZE_128,         128
.equ TRACE_LIMIT,           32

.extern dwc2_init
.extern dwc2_port_detect

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top

    bl      test_dwc2_init_programs_core
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_init_rejects_bad_core
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_init_ahb_idle_timeout
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_init_reset_timeout
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_reports_speed
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_resets_to_enable
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_reset_timeout
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_rejects_null
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    mov     r0, #0
    b       semihost_exit

.Lfail_code:
    mov     r0, r4
    b       semihost_exit

test_dwc2_init_programs_core:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =DWC2_CORE_ID_310A
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #0
    movne   r0, #11
    popne   {pc}
    bl      check_usb_init_registers
    pop     {pc}

test_dwc2_init_rejects_bad_core:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =0x12345678
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #1
    movne   r0, #31
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #32
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_init_ahb_idle_timeout:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =DWC2_CORE_ID_310A
    str     r0, [r1]
    ldr     r1, =ahb_idle_enabled
    mov     r0, #0
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #1
    movne   r0, #33
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #34
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_init_reset_timeout:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =DWC2_CORE_ID_310A
    str     r0, [r1]
    ldr     r1, =reset_clears
    mov     r0, #0
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #1
    movne   r0, #35
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #36
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_reports_speed:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =hprt_value
    ldr     r0, =(HPRT_PRTCONNDET | HPRT_PRTENA | HPRT_SPD_FS)
    str     r0, [r1]
    ldr     r0, =speed_out
    bl      dwc2_port_detect
    cmp     r0, #0
    movne   r0, #41
    popne   {pc}
    ldr     r1, =speed_out
    ldrb    r0, [r1]
    cmp     r0, #1
    movne   r0, #42
    popne   {pc}
    ldr     r1, =hprt_value
    ldr     r0, [r1]
    tst     r0, #HPRT_PRTPWR
    moveq   r0, #43
    popeq   {pc}
    ldr     r1, =hprt_write_count
    ldr     r0, [r1]
    cmp     r0, #2
    movne   r0, #44
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_resets_to_enable:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =hprt_value
    ldr     r0, =(HPRT_PRTCONNDET | HPRT_SPD_FS)
    str     r0, [r1]
    ldr     r1, =hprt_reset_enables
    mov     r0, #1
    str     r0, [r1]
    ldr     r0, =speed_out
    bl      dwc2_port_detect
    cmp     r0, #0
    movne   r0, #47
    popne   {pc}
    ldr     r1, =speed_out
    ldrb    r0, [r1]
    cmp     r0, #1
    movne   r0, #48
    popne   {pc}
    ldr     r1, =hprt_reset_seen
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #49
    popne   {pc}
    ldr     r1, =hprt_value
    ldr     r0, [r1]
    tst     r0, #HPRT_PRTENA
    moveq   r0, #50
    popeq   {pc}
    tst     r0, #HPRT_PRTRST
    movne   r0, #51
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_reset_timeout:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =hprt_value
    ldr     r0, =(HPRT_PRTCONNDET | HPRT_SPD_FS)
    str     r0, [r1]
    ldr     r0, =speed_out
    bl      dwc2_port_detect
    cmp     r0, #1
    movne   r0, #52
    popne   {pc}
    ldr     r1, =hprt_reset_seen
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #53
    popne   {pc}
    ldr     r1, =speed_out
    ldrb    r0, [r1]
    cmp     r0, #0
    movne   r0, #54
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_rejects_null:
    push    {lr}
    bl      reset_usb_emulator
    mov     r0, #0
    bl      dwc2_port_detect
    cmp     r0, #1
    movne   r0, #45
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #46
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_usb_init_registers:
    push    {lr}
    ldr     r1, =grxfsiz_value
    ldr     r0, [r1]
    cmp     r0, #FIFO_SIZE_128
    movne   r0, #12
    popne   {pc}
    ldr     r1, =gnptxfsiz_value
    ldr     r0, [r1]
    ldr     r2, =(FIFO_SIZE_128 | (FIFO_SIZE_128 << 16))
    cmp     r0, r2
    movne   r0, #13
    popne   {pc}
    ldr     r1, =hptxfsiz_value
    ldr     r0, [r1]
    ldr     r2, =(FIFO_SIZE_128 | ((FIFO_SIZE_128 + FIFO_SIZE_128) << 16))
    cmp     r0, r2
    movne   r0, #14
    popne   {pc}
    ldr     r1, =hfir_value
    ldr     r0, [r1]
    ldr     r2, =60000
    cmp     r0, r2
    movne   r0, #16
    popne   {pc}
    ldr     r1, =gintmsk_value
    ldr     r0, [r1]
    ldr     r2, =(GINT_HC_INT | GINT_PRT_INT | GINT_DISC_INT)
    cmp     r0, r2
    movne   r0, #17
    popne   {pc}
    ldr     r1, =gahbcfg_value
    ldr     r0, [r1]
    tst     r0, #GAHBCFG_GLBL_INTR_EN
    moveq   r0, #18
    popeq   {pc}
    ldr     r1, =gusbcfg_value
    ldr     r0, [r1]
    tst     r0, #GUSBCFG_PHYIF
    movne   r0, #19
    popne   {pc}
    tst     r0, #GUSBCFG_ULPI_UTMI_SEL
    movne   r0, #20
    popne   {pc}
    tst     r0, #GUSBCFG_FS_INTF
    movne   r0, #21
    popne   {pc}
    tst     r0, #GUSBCFG_SRPCAP
    movne   r0, #22
    popne   {pc}
    tst     r0, #GUSBCFG_HNPCAP
    movne   r0, #23
    popne   {pc}
    and     r0, r0, #GUSBCFG_TRDT_MASK
    ldr     r2, =(5 << GUSBCFG_TRDT_SHIFT)
    cmp     r0, r2
    movne   r0, #24
    popne   {pc}
    ldr     r1, =hcfg_value
    ldr     r0, [r1]
    tst     r0, #HCFG_FSLSS
    movne   r0, #25
    popne   {pc}
    tst     r0, #HCFG_FSLS_PHOST
    movne   r0, #26
    popne   {pc}
    mov     r0, #0
    pop     {pc}

reset_usb_emulator:
    push    {lr}
    mov     r0, #0
    ldr     r1, =write_count
    str     r0, [r1]
    ldr     r1, =reset_pending
    str     r0, [r1]
    ldr     r1, =ahb_idle_enabled
    mov     r0, #1
    str     r0, [r1]
    ldr     r1, =reset_clears
    str     r0, [r1]
    mov     r0, #0
    ldr     r1, =gahbcfg_value
    str     r0, [r1]
    ldr     r1, =gusbcfg_value
    ldr     r0, =(GUSBCFG_PHYIF | GUSBCFG_ULPI_UTMI_SEL | GUSBCFG_FS_INTF | GUSBCFG_SRPCAP | GUSBCFG_HNPCAP)
    str     r0, [r1]
    ldr     r1, =hcfg_value
    mov     r0, #(HCFG_FSLSS | HCFG_FSLS_PHOST)
    str     r0, [r1]
    mov     r0, #0
    ldr     r1, =hfir_value
    str     r0, [r1]
    ldr     r1, =grxfsiz_value
    str     r0, [r1]
    ldr     r1, =gnptxfsiz_value
    str     r0, [r1]
    ldr     r1, =hptxfsiz_value
    str     r0, [r1]
    ldr     r1, =gintmsk_value
    str     r0, [r1]
    ldr     r1, =hprt_value
    str     r0, [r1]
    ldr     r1, =hprt_write_count
    str     r0, [r1]
    ldr     r1, =hprt_reset_enables
    str     r0, [r1]
    ldr     r1, =hprt_reset_seen
    str     r0, [r1]
    ldr     r1, =speed_out
    str     r0, [r1]
    pop     {pc}

.globl dwc2_mmio_read
dwc2_mmio_read:
    cmp     r0, #DWC_CID
    bne     1f
    ldr     r1, =core_id
    ldr     r0, [r1]
    bx      lr
1:
    cmp     r0, #DWC_GRSTCTL
    bne     2f
    ldr     r1, =ahb_idle_enabled
    ldr     r2, [r1]
    cmp     r2, #0
    moveq   r0, #0
    bxeq    lr
    ldr     r1, =reset_pending
    ldr     r2, [r1]
    cmp     r2, #0
    beq     7f
    ldr     r3, =reset_clears
    ldr     r0, [r3]
    cmp     r0, #0
    ldreq   r0, =(GRSTCTL_AHBIDLE | GRSTCTL_CSFTRST)
    bxeq    lr
    movne   r2, #0
    strne   r2, [r1]
7:
    mov     r0, #GRSTCTL_AHBIDLE
    bx      lr
2:
    cmp     r0, #DWC_GAHBCFG
    bne     3f
    ldr     r1, =gahbcfg_value
    ldr     r0, [r1]
    bx      lr
3:
    cmp     r0, #DWC_GUSBCFG
    bne     4f
    ldr     r1, =gusbcfg_value
    ldr     r0, [r1]
    bx      lr
4:
    ldr     r3, =DWC_HCFG
    cmp     r0, r3
    bne     5f
    ldr     r1, =hcfg_value
    ldr     r0, [r1]
    bx      lr
5:
    ldr     r3, =DWC_HPRT
    cmp     r0, r3
    bne     6f
    ldr     r1, =hprt_value
    ldr     r0, [r1]
    bx      lr
6:
    mov     r0, #0
    bx      lr

.globl dwc2_mmio_write
dwc2_mmio_write:
    ldr     r2, =write_count
    ldr     r3, [r2]
    add     r3, r3, #1
    str     r3, [r2]
    cmp     r0, #DWC_GRSTCTL
    bne     1f
    ldr     r2, =reset_pending
    str     r1, [r2]
    bx      lr
1:
    cmp     r0, #DWC_GAHBCFG
    ldreq   r2, =gahbcfg_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GUSBCFG
    ldreq   r2, =gusbcfg_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_HCFG
    ldreq   r2, =hcfg_value
    streq   r1, [r2]
    bxeq    lr
    ldr     r3, =DWC_HFIR
    cmp     r0, r3
    ldreq   r2, =hfir_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GRXFSIZ
    ldreq   r2, =grxfsiz_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GNPTXFSIZ
    ldreq   r2, =gnptxfsiz_value
    streq   r1, [r2]
    bxeq    lr
    ldr     r3, =DWC_HPTXFSIZ
    cmp     r0, r3
    ldreq   r2, =hptxfsiz_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GINTMSK
    ldreq   r2, =gintmsk_value
    streq   r1, [r2]
    bxeq    lr
    ldr     r3, =DWC_HPRT
    cmp     r0, r3
    bne     2f
    tst     r1, #HPRT_PRTRST
    beq     3f
    ldr     r2, =hprt_reset_seen
    mov     r3, #1
    str     r3, [r2]
3:
    tst     r1, #HPRT_PRTRST
    bne     4f
    ldr     r2, =hprt_reset_enables
    ldr     r3, [r2]
    cmp     r3, #0
    beq     4f
    ldr     r2, =hprt_reset_seen
    ldr     r3, [r2]
    cmp     r3, #0
    beq     4f
    orr     r1, r1, #HPRT_PRTENA
    bic     r1, r1, #HPRT_PRTRST
4:
    ldr     r2, =hprt_value
    str     r1, [r2]
    ldr     r2, =hprt_write_count
    ldr     r3, [r2]
    add     r3, r3, #1
    str     r3, [r2]
    bx      lr
2:
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

.section .bss
.align 4
core_id:
    .space  4
write_count:
    .space  4
reset_pending:
    .space  4
ahb_idle_enabled:
    .space  4
reset_clears:
    .space  4
gahbcfg_value:
    .space  4
gusbcfg_value:
    .space  4
hcfg_value:
    .space  4
hfir_value:
    .space  4
grxfsiz_value:
    .space  4
gnptxfsiz_value:
    .space  4
hptxfsiz_value:
    .space  4
gintmsk_value:
    .space  4
hprt_value:
    .space  4
hprt_write_count:
    .space  4
hprt_reset_enables:
    .space  4
hprt_reset_seen:
    .space  4
speed_out:
    .space  4
stack_bottom:
    .space  4096
stack_top:
