@ EdgeRun Pi Zero W Bluetooth UART bring-up emulator test.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ GPIO_FUNCTION_ALT3, 7
.equ GPIO_FUNCTION_OUTPUT, 1
.equ PI_BT_CTS_PIN, 30
.equ PI_BT_RTS_PIN, 31
.equ PI_BT_TX_PIN,  32
.equ PI_BT_RX_PIN,  33
.equ PI_BT_REG_ON_PIN, 45

.equ GPIO_GPFSEL3, 0x0c
.equ GPIO_GPFSEL4, 0x10
.equ GPIO_GPSET1,  0x20
.equ GPIO_GPCLR1,  0x2c
.equ BT_UART_PINS_ALT3, 0x00000fff
.equ BT_REG_ON_OUTPUT, 0x00008000
.equ BT_REG_ON_MASK, 0x00002000

.equ PL011_IBRD,  0x024
.equ PL011_FBRD,  0x028
.equ PL011_LCR_H, 0x02c
.equ PL011_CR,    0x030
.equ PL011_IMSC,  0x038
.equ PL011_ICR,   0x044
.equ PL011_LCR_H_8N1_FIFO, 0x70
.equ PL011_ICR_ALL, 0x7ff
.equ PL011_CR_HCI, 0xc301
.equ TRACE_LIMIT, 32
.equ UART_TRACE_LIMIT, 8

.extern pi_bt_init

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top
    bl      reset_bt_emulator
    bl      pi_bt_init
    cmp     r0, #0
    movne   r4, #1
    bne     .Lfail_code

    bl      check_gpio_state
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      check_uart_trace
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    mov     r0, #0
    b       semihost_exit

.Lfail_code:
    mov     r0, r4
    b       semihost_exit

check_gpio_state:
    push    {lr}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPFSEL3]
    ldr     r2, =BT_UART_PINS_ALT3
    cmp     r0, r2
    movne   r0, #11
    popne   {pc}
    ldr     r0, [r1, #GPIO_GPFSEL4]
    ldr     r2, =BT_REG_ON_OUTPUT
    cmp     r0, r2
    movne   r0, #12
    popne   {pc}
    ldr     r0, [r1, #GPIO_GPCLR1]
    ldr     r2, =BT_REG_ON_MASK
    cmp     r0, r2
    movne   r0, #13
    popne   {pc}
    ldr     r0, [r1, #GPIO_GPSET1]
    cmp     r0, r2
    movne   r0, #14
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_uart_trace:
    push    {r4, r5, lr}
    ldr     r1, =uart_trace_index
    ldr     r0, [r1]
    cmp     r0, #7
    movne   r0, #21
    popne   {r4, r5, pc}
    ldr     r4, =uart_trace_offsets
    ldr     r5, =uart_trace_values

    ldr     r0, [r4], #4
    cmp     r0, #PL011_CR
    movne   r0, #22
    popne   {r4, r5, pc}
    ldr     r0, [r5], #4
    cmp     r0, #0
    movne   r0, #23
    popne   {r4, r5, pc}

    ldr     r0, [r4], #4
    cmp     r0, #PL011_IBRD
    movne   r0, #24
    popne   {r4, r5, pc}
    ldr     r0, [r5], #4
    cmp     r0, #1
    movne   r0, #25
    popne   {r4, r5, pc}

    ldr     r0, [r4], #4
    cmp     r0, #PL011_FBRD
    movne   r0, #26
    popne   {r4, r5, pc}
    ldr     r0, [r5], #4
    cmp     r0, #40
    movne   r0, #27
    popne   {r4, r5, pc}

    ldr     r0, [r4], #4
    cmp     r0, #PL011_LCR_H
    movne   r0, #28
    popne   {r4, r5, pc}
    ldr     r0, [r5], #4
    cmp     r0, #PL011_LCR_H_8N1_FIFO
    movne   r0, #29
    popne   {r4, r5, pc}

    ldr     r0, [r4], #4
    cmp     r0, #PL011_ICR
    movne   r0, #30
    popne   {r4, r5, pc}
    ldr     r0, [r5], #4
    ldr     r1, =PL011_ICR_ALL
    cmp     r0, r1
    movne   r0, #31
    popne   {r4, r5, pc}

    ldr     r0, [r4], #4
    cmp     r0, #PL011_IMSC
    movne   r0, #32
    popne   {r4, r5, pc}
    ldr     r0, [r5], #4
    cmp     r0, #0
    movne   r0, #33
    popne   {r4, r5, pc}

    ldr     r0, [r4]
    cmp     r0, #PL011_CR
    movne   r0, #34
    popne   {r4, r5, pc}
    ldr     r0, [r5]
    ldr     r1, =PL011_CR_HCI
    cmp     r0, r1
    movne   r0, #35
    popne   {r4, r5, pc}

    mov     r0, #0
    pop     {r4, r5, pc}

reset_bt_emulator:
    push    {lr}
    mov     r0, #0
    ldr     r1, =trace_index
    str     r0, [r1]
    ldr     r1, =uart_trace_index
    str     r0, [r1]
    ldr     r1, =gpio_regs
    mov     r2, #16
1:
    str     r0, [r1], #4
    subs    r2, r2, #1
    bne     1b
    ldr     r1, =trace_offsets
    ldr     r2, =trace_values
    mov     r3, #TRACE_LIMIT
2:
    str     r0, [r1], #4
    str     r0, [r2], #4
    subs    r3, r3, #1
    bne     2b
    ldr     r1, =uart_trace_offsets
    ldr     r2, =uart_trace_values
    mov     r3, #UART_TRACE_LIMIT
3:
    str     r0, [r1], #4
    str     r0, [r2], #4
    subs    r3, r3, #1
    bne     3b
    pop     {pc}

.globl gpio_mmio_read
gpio_mmio_read:
    ldr     r1, =gpio_regs
    ldr     r0, [r1, r0]
    bx      lr

.globl gpio_mmio_write
gpio_mmio_write:
    ldr     r2, =trace_index
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bhs     .Lgpio_write_no_trace
    ldr     r4, =trace_offsets
    str     r0, [r4, r3, lsl #2]
    ldr     r4, =trace_values
    str     r1, [r4, r3, lsl #2]
    add     r3, r3, #1
    str     r3, [r2]
.Lgpio_write_no_trace:
    ldr     r2, =gpio_regs
    str     r1, [r2, r0]
    bx      lr

.globl pi_bt_uart_mmio_write
pi_bt_uart_mmio_write:
    ldr     r2, =uart_trace_index
    ldr     r3, [r2]
    cmp     r3, #UART_TRACE_LIMIT
    bhs     .Luart_write_no_trace
    ldr     r4, =uart_trace_offsets
    str     r0, [r4, r3, lsl #2]
    ldr     r4, =uart_trace_values
    str     r1, [r4, r3, lsl #2]
    add     r3, r3, #1
    str     r3, [r2]
.Luart_write_no_trace:
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
gpio_regs:
    .space  64
trace_offsets:
    .space  128
trace_values:
    .space  128
trace_index:
    .space  4
uart_trace_offsets:
    .space  32
uart_trace_values:
    .space  32
uart_trace_index:
    .space  4
stack_bottom:
    .space  4096
stack_top:
