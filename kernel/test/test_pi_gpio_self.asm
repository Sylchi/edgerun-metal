@ EdgeRun Pi Zero W BCM2835 GPIO emulator test -- ARM assembly.

.syntax unified
.cpu arm1176jzf-s
.arm
.include "test/test_arm_macros.inc"

.equ GPIO_FUNCTION_INPUT, 0
.equ GPIO_FUNCTION_OUTPUT, 1
.equ GPIO_FUNCTION_ALT0, 4
.equ GPIO_ACT_LED_PIN, 47
.equ GPIO_GPFSEL0, 0x00
.equ GPIO_GPFSEL1, 0x04
.equ GPIO_GPFSEL4, 0x10
.equ GPIO_GPSET0,  0x1c
.equ GPIO_GPSET1,  0x20
.equ GPIO_GPCLR0,  0x28
.equ GPIO_GPCLR1,  0x2c
.equ GPIO_GPLEV0,  0x34
.equ GPIO_GPLEV1,  0x38
.equ GPIO_PIN_INVALID, 54
.equ GPIO_FUNCTION_INVALID, 8
.equ LED_FSEL_CLEAR_MASK, 0x00700000
.equ LED_FSEL_OUTPUT, 0x00100000
.equ LED_PIN_MASK, 0x00008000
.equ GPIO17_FSEL_ALT0, 0x00200000
.equ GPIO17_SET_MASK, 0x00020000
.equ TRACE_LIMIT, 16

.extern gpio_select_function
.extern gpio_set_pin
.extern gpio_clear_pin
.extern gpio_read_pin
.extern gpio_led_init
.extern gpio_led_on
.extern gpio_led_off

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top

    TEST_ARM_CALL test_gpio_select_preserves_bits
    TEST_ARM_CALL test_gpio_set_clear_and_level
    TEST_ARM_CALL test_gpio_led_helpers
    TEST_ARM_CALL test_gpio_rejects_invalid_values
    TEST_ARM_EXIT_OK
    TEST_ARM_EXIT_FAIL

test_gpio_select_preserves_bits:
    push    {lr}
    bl      reset_gpio_emulator
    ldr     r1, =gpio_regs
    ldr     r0, =0xffffffff
    str     r0, [r1, #GPIO_GPFSEL1]
    mov     r0, #17
    mov     r1, #GPIO_FUNCTION_ALT0
    bl      gpio_select_function
    cmp     r0, #0
    movne   r0, #11
    popne   {pc}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPFSEL1]
    ldr     r2, =0xff9fffff
    cmp     r0, r2
    movne   r0, #12
    popne   {pc}
    ldr     r0, =select_trace
    mov     r1, #2
    mov     r2, #13
    bl      check_trace
    pop     {pc}

test_gpio_set_clear_and_level:
    push    {lr}
    bl      reset_gpio_emulator
    mov     r0, #17
    bl      gpio_set_pin
    cmp     r0, #0
    movne   r0, #21
    popne   {pc}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPSET0]
    cmp     r0, #GPIO17_SET_MASK
    movne   r0, #22
    popne   {pc}
    mov     r0, #17
    bl      gpio_read_pin
    cmp     r0, #0
    movne   r0, #23
    popne   {pc}
    cmp     r1, #1
    movne   r0, #24
    popne   {pc}
    mov     r0, #17
    bl      gpio_clear_pin
    cmp     r0, #0
    movne   r0, #25
    popne   {pc}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPCLR0]
    cmp     r0, #GPIO17_SET_MASK
    movne   r0, #26
    popne   {pc}
    mov     r0, #17
    bl      gpio_read_pin
    cmp     r0, #0
    movne   r0, #27
    popne   {pc}
    cmp     r1, #0
    movne   r0, #28
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_gpio_led_helpers:
    push    {lr}
    bl      reset_gpio_emulator
    ldr     r1, =gpio_regs
    ldr     r0, =0xffffffff
    str     r0, [r1, #GPIO_GPFSEL4]
    bl      gpio_led_init
    cmp     r0, #0
    movne   r0, #31
    popne   {pc}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPFSEL4]
    ldr     r2, =0xff3fffff
    cmp     r0, r2
    movne   r0, #32
    popne   {pc}
    bl      gpio_led_on
    cmp     r0, #0
    movne   r0, #33
    popne   {pc}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPSET1]
    cmp     r0, #LED_PIN_MASK
    movne   r0, #34
    popne   {pc}
    bl      gpio_led_off
    cmp     r0, #0
    movne   r0, #35
    popne   {pc}
    ldr     r1, =gpio_regs
    ldr     r0, [r1, #GPIO_GPCLR1]
    cmp     r0, #LED_PIN_MASK
    movne   r0, #36
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_gpio_rejects_invalid_values:
    push    {lr}
    bl      reset_gpio_emulator
    mov     r0, #GPIO_PIN_INVALID
    mov     r1, #GPIO_FUNCTION_OUTPUT
    bl      gpio_select_function
    cmp     r0, #1
    movne   r0, #41
    popne   {pc}
    mov     r0, #17
    mov     r1, #GPIO_FUNCTION_INVALID
    bl      gpio_select_function
    cmp     r0, #1
    movne   r0, #42
    popne   {pc}
    mov     r0, #GPIO_PIN_INVALID
    bl      gpio_set_pin
    cmp     r0, #1
    movne   r0, #43
    popne   {pc}
    mov     r0, #GPIO_PIN_INVALID
    bl      gpio_read_pin
    cmp     r0, #1
    movne   r0, #44
    popne   {pc}
    ldr     r1, =trace_index
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #45
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_trace:
    push    {r4, r5, r6, r7, r8, lr}
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    ldr     r7, =trace_index
    ldr     r0, [r7]
    cmp     r0, r5
    bne     .Ltrace_fail
    ldr     r7, =trace_offsets
    ldr     r8, =trace_values
1:
    ldr     r0, [r7], #4
    ldr     r1, [r4], #4
    cmp     r0, r1
    bne     .Ltrace_fail
    ldr     r0, [r8], #4
    ldr     r1, [r4], #4
    cmp     r0, r1
    bne     .Ltrace_fail
    subs    r5, r5, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, pc}

.Ltrace_fail:
    mov     r0, r6
    pop     {r4, r5, r6, r7, r8, pc}

reset_gpio_emulator:
    push    {r4, lr}
    mov     r0, #0
    ldr     r1, =trace_index
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
    pop     {r4, pc}

.globl gpio_mmio_read
gpio_mmio_read:
    ldr     r2, =trace_index
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bhs     .Lread_no_trace
    ldr     r1, =trace_offsets
    str     r0, [r1, r3, lsl #2]
    ldr     r1, =trace_values
    mov     r4, #0
    str     r4, [r1, r3, lsl #2]
    add     r3, r3, #1
    str     r3, [r2]
.Lread_no_trace:
    ldr     r1, =gpio_regs
    ldr     r0, [r1, r0]
    bx      lr

.globl gpio_mmio_write
gpio_mmio_write:
    ldr     r2, =trace_index
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bhs     .Lwrite_no_trace
    ldr     r4, =trace_offsets
    str     r0, [r4, r3, lsl #2]
    ldr     r4, =trace_values
    str     r1, [r4, r3, lsl #2]
    add     r3, r3, #1
    str     r3, [r2]
.Lwrite_no_trace:
    ldr     r2, =gpio_regs
    str     r1, [r2, r0]
    cmp     r0, #GPIO_GPSET0
    beq     .Lset_level0
    cmp     r0, #GPIO_GPSET1
    beq     .Lset_level1
    b       .Lmaybe_clear
.Lset_level0:
    ldr     r2, =gpio_regs
    ldr     r3, [r2, #GPIO_GPLEV0]
    orr     r3, r3, r1
    str     r3, [r2, #GPIO_GPLEV0]
    bx      lr
.Lset_level1:
    ldr     r2, =gpio_regs
    ldr     r3, [r2, #GPIO_GPLEV1]
    orr     r3, r3, r1
    str     r3, [r2, #GPIO_GPLEV1]
    bx      lr
.Lmaybe_clear:
    cmp     r0, #GPIO_GPCLR0
    beq     .Lclear_level0
    cmp     r0, #GPIO_GPCLR1
    bxne    lr
    ldr     r2, =gpio_regs
    ldr     r3, [r2, #GPIO_GPLEV1]
    bic     r3, r3, r1
    str     r3, [r2, #GPIO_GPLEV1]
    bx      lr
.Lclear_level0:
    ldr     r2, =gpio_regs
    ldr     r3, [r2, #GPIO_GPLEV0]
    bic     r3, r3, r1
    str     r3, [r2, #GPIO_GPLEV0]
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
select_trace:
    .word   GPIO_GPFSEL1
    .word   0
    .word   GPIO_GPFSEL1
    .word   0xff9fffff

.section .bss
.align 4
gpio_regs:
    .space  64
trace_offsets:
    .space  64
trace_values:
    .space  64
trace_index:
    .space  4
stack_bottom:
    .space  4096
stack_top:
