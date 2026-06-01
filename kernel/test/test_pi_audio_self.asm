@ EdgeRun Pi Zero W BCM2835 PWM audio emulator test.

.syntax unified
.cpu arm1176jzf-s
.arm
.include "test/test_arm_macros.inc"

.equ PWM_CTL,         0x00
.equ PWM_STA,         0x04
.equ PWM_RNG1,        0x10
.equ PWM_DAT1,        0x14
.equ PWM_RNG2,        0x20
.equ PWM_DAT2,        0x24
.equ CM_PWMCTL,       0xa0
.equ CM_PWMDIV,       0xa4
.equ CM_PASSWORD,     0x5a000000
.equ CM_CTL_ENAB,     (1 << 4)
.equ CM_CTL_SRC_OSC,  1
.equ CM_DIV_INT_SHIFT, 12
.equ CM_PWM_DIVISOR,  2
.equ CM_PWM_DIV_WORD, CM_PASSWORD | (CM_PWM_DIVISOR << CM_DIV_INT_SHIFT)
.equ CM_PWM_CTL_STOP, CM_PASSWORD | CM_CTL_SRC_OSC
.equ CM_PWM_CTL_START, CM_PASSWORD | CM_CTL_ENAB | CM_CTL_SRC_OSC
.equ PWM_CTL_AUDIO_ENABLE, ((1 << 0) | (1 << 7) | (1 << 8) | (1 << 15))
.equ PWM_STA_ALL,     0x000001ff
.equ GPIO_FUNCTION_ALT5, 2
.equ PI_AUDIO_LEFT_PIN,  18
.equ PI_AUDIO_RIGHT_PIN, 19
.equ PI_AUDIO_PWM_RANGE, 200
.equ PI_AUDIO_PWM_MID,   100
.equ TRACE_LIMIT,     16

.extern pi_audio_pwm_init
.extern pi_audio_pwm_write_stereo

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top

    TEST_ARM_CALL test_audio_init
    TEST_ARM_CALL test_audio_write_stereo
    TEST_ARM_CALL test_audio_rejects_out_of_range
    TEST_ARM_EXIT_OK
    TEST_ARM_EXIT_FAIL

test_audio_init:
    push    {lr}
    bl      reset_audio_emulator
    bl      pi_audio_pwm_init
    cmp     r0, #0
    movne   r0, #11
    popne   {pc}
    bl      check_gpio_alt5
    cmp     r0, #0
    popne   {pc}
    bl      check_audio_init_trace
    pop     {pc}

test_audio_write_stereo:
    push    {lr}
    bl      reset_audio_emulator
    mov     r0, #17
    mov     r1, #181
    bl      pi_audio_pwm_write_stereo
    cmp     r0, #0
    movne   r0, #31
    popne   {pc}
    bl      check_audio_write_trace
    pop     {pc}

test_audio_rejects_out_of_range:
    push    {lr}
    bl      reset_audio_emulator
    mov     r0, #PI_AUDIO_PWM_RANGE
    mov     r1, #0
    bl      pi_audio_pwm_write_stereo
    cmp     r0, #1
    movne   r0, #41
    popne   {pc}
    ldr     r1, =pwm_write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #42
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_gpio_alt5:
    push    {lr}
    ldr     r1, =gpio_count
    ldr     r0, [r1]
    cmp     r0, #2
    movne   r0, #12
    popne   {pc}
    ldr     r1, =gpio_pin_trace
    ldr     r0, [r1]
    cmp     r0, #PI_AUDIO_LEFT_PIN
    movne   r0, #13
    popne   {pc}
    ldr     r0, [r1, #4]
    cmp     r0, #PI_AUDIO_RIGHT_PIN
    movne   r0, #14
    popne   {pc}
    ldr     r1, =gpio_function_trace
    ldr     r0, [r1]
    cmp     r0, #GPIO_FUNCTION_ALT5
    movne   r0, #15
    popne   {pc}
    ldr     r0, [r1, #4]
    cmp     r0, #GPIO_FUNCTION_ALT5
    movne   r0, #16
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_audio_init_trace:
    push    {lr}
    ldr     r1, =clock_write_count
    ldr     r0, [r1]
    cmp     r0, #3
    movne   r0, #17
    popne   {pc}
    ldr     r1, =clock_offset_trace
    ldr     r0, [r1]
    cmp     r0, #CM_PWMCTL
    movne   r0, #18
    popne   {pc}
    ldr     r1, =clock_value_trace
    ldr     r0, [r1]
    ldr     r2, =CM_PWM_CTL_STOP
    cmp     r0, r2
    movne   r0, #19
    popne   {pc}
    ldr     r0, [r1, #4]
    ldr     r2, =CM_PWM_DIV_WORD
    cmp     r0, r2
    movne   r0, #20
    popne   {pc}
    ldr     r0, [r1, #8]
    ldr     r2, =CM_PWM_CTL_START
    cmp     r0, r2
    movne   r0, #21
    popne   {pc}

    ldr     r1, =pwm_write_count
    ldr     r0, [r1]
    cmp     r0, #7
    movne   r0, #22
    popne   {pc}
    ldr     r1, =pwm_offset_trace
    ldr     r0, [r1]
    cmp     r0, #PWM_CTL
    movne   r0, #23
    popne   {pc}
    ldr     r0, [r1, #4]
    cmp     r0, #PWM_STA
    movne   r0, #24
    popne   {pc}
    ldr     r0, [r1, #8]
    cmp     r0, #PWM_RNG1
    movne   r0, #25
    popne   {pc}
    ldr     r0, [r1, #12]
    cmp     r0, #PWM_RNG2
    movne   r0, #26
    popne   {pc}
    ldr     r0, [r1, #16]
    cmp     r0, #PWM_DAT1
    movne   r0, #27
    popne   {pc}
    ldr     r0, [r1, #20]
    cmp     r0, #PWM_DAT2
    movne   r0, #28
    popne   {pc}
    ldr     r0, [r1, #24]
    cmp     r0, #PWM_CTL
    movne   r0, #29
    popne   {pc}
    ldr     r1, =pwm_value_trace
    ldr     r0, [r1, #8]
    cmp     r0, #PI_AUDIO_PWM_RANGE
    movne   r0, #30
    popne   {pc}
    ldr     r0, [r1, #16]
    cmp     r0, #PI_AUDIO_PWM_MID
    movne   r0, #43
    popne   {pc}
    ldr     r0, [r1, #24]
    ldr     r2, =PWM_CTL_AUDIO_ENABLE
    cmp     r0, r2
    movne   r0, #44
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_audio_write_trace:
    push    {lr}
    ldr     r1, =pwm_write_count
    ldr     r0, [r1]
    cmp     r0, #2
    movne   r0, #32
    popne   {pc}
    ldr     r1, =pwm_offset_trace
    ldr     r0, [r1]
    cmp     r0, #PWM_DAT1
    movne   r0, #33
    popne   {pc}
    ldr     r0, [r1, #4]
    cmp     r0, #PWM_DAT2
    movne   r0, #34
    popne   {pc}
    ldr     r1, =pwm_value_trace
    ldr     r0, [r1]
    cmp     r0, #17
    movne   r0, #35
    popne   {pc}
    ldr     r0, [r1, #4]
    cmp     r0, #181
    movne   r0, #36
    popne   {pc}
    mov     r0, #0
    pop     {pc}

reset_audio_emulator:
    push    {lr}
    mov     r0, #0
    ldr     r1, =gpio_count
    str     r0, [r1]
    ldr     r1, =pwm_write_count
    str     r0, [r1]
    ldr     r1, =clock_write_count
    str     r0, [r1]
    pop     {pc}

.globl gpio_select_function
gpio_select_function:
    ldr     r2, =gpio_count
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bhs     1f
    add     r12, r3, #1
    str     r12, [r2]
    ldr     r2, =gpio_pin_trace
    str     r0, [r2, r3, lsl #2]
    ldr     r2, =gpio_function_trace
    str     r1, [r2, r3, lsl #2]
1:
    mov     r0, #0
    bx      lr

.globl pi_audio_pwm_mmio_read
pi_audio_pwm_mmio_read:
    mov     r0, #0
    bx      lr

.globl pi_audio_pwm_mmio_write
pi_audio_pwm_mmio_write:
    ldr     r2, =pwm_write_count
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bxhs    lr
    add     r12, r3, #1
    str     r12, [r2]
    ldr     r2, =pwm_offset_trace
    str     r0, [r2, r3, lsl #2]
    ldr     r2, =pwm_value_trace
    str     r1, [r2, r3, lsl #2]
    bx      lr

.globl pi_audio_clock_mmio_read
pi_audio_clock_mmio_read:
    mov     r0, #0
    bx      lr

.globl pi_audio_clock_mmio_write
pi_audio_clock_mmio_write:
    ldr     r2, =clock_write_count
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bxhs    lr
    add     r12, r3, #1
    str     r12, [r2]
    ldr     r2, =clock_offset_trace
    str     r0, [r2, r3, lsl #2]
    ldr     r2, =clock_value_trace
    str     r1, [r2, r3, lsl #2]
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
gpio_count:
    .space  4
pwm_write_count:
    .space  4
clock_write_count:
    .space  4
gpio_pin_trace:
    .space  (TRACE_LIMIT * 4)
gpio_function_trace:
    .space  (TRACE_LIMIT * 4)
pwm_offset_trace:
    .space  (TRACE_LIMIT * 4)
pwm_value_trace:
    .space  (TRACE_LIMIT * 4)
clock_offset_trace:
    .space  (TRACE_LIMIT * 4)
clock_value_trace:
    .space  (TRACE_LIMIT * 4)
stack_bottom:
    .space  4096
stack_top:
