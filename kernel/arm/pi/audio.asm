@ Raspberry Pi Zero W BCM2835 PWM audio bring-up -- ARM1176JZF-S.
@
@ Public API:
@   pi_audio_pwm_init()                 r0 = 0 on success
@   pi_audio_pwm_write_stereo(l, r)     r0 = 0 on success

.syntax unified
.cpu arm1176jzf-s
.arm

.equ PERIPHERAL_BASE, 0x20000000
.equ PWM_BASE,        PERIPHERAL_BASE + 0x0020c000
.equ CM_BASE,         PERIPHERAL_BASE + 0x00101000

.equ PWM_CTL,         0x00
.equ PWM_STA,         0x04
.equ PWM_RNG1,        0x10
.equ PWM_DAT1,        0x14
.equ PWM_RNG2,        0x20
.equ PWM_DAT2,        0x24

.equ PWM_CTL_PWEN1,   (1 << 0)
.equ PWM_CTL_MODE1,   (1 << 1)
.equ PWM_CTL_RPTL1,   (1 << 2)
.equ PWM_CTL_SBIT1,   (1 << 3)
.equ PWM_CTL_POLA1,   (1 << 4)
.equ PWM_CTL_USEF1,   (1 << 5)
.equ PWM_CTL_CLRF1,   (1 << 6)
.equ PWM_CTL_MSEN1,   (1 << 7)
.equ PWM_CTL_PWEN2,   (1 << 8)
.equ PWM_CTL_MODE2,   (1 << 9)
.equ PWM_CTL_RPTL2,   (1 << 10)
.equ PWM_CTL_SBIT2,   (1 << 11)
.equ PWM_CTL_POLA2,   (1 << 12)
.equ PWM_CTL_USEF2,   (1 << 13)
.equ PWM_CTL_MSEN2,   (1 << 15)
.equ PWM_CTL_AUDIO_ENABLE, (PWM_CTL_PWEN1 | PWM_CTL_MSEN1 | PWM_CTL_PWEN2 | PWM_CTL_MSEN2)

.equ PWM_STA_ALL,     0x000001ff

.equ CM_PWMCTL,       0xa0
.equ CM_PWMDIV,       0xa4
.equ CM_PASSWORD,     0x5a000000
.equ CM_CTL_ENAB,     (1 << 4)
.equ CM_CTL_KILL,     (1 << 5)
.equ CM_CTL_BUSY,     (1 << 7)
.equ CM_CTL_SRC_OSC,  1
.equ CM_DIV_INT_SHIFT, 12
.equ CM_PWM_DIVISOR,  2
.equ CM_PWM_DIV_WORD, CM_PASSWORD | (CM_PWM_DIVISOR << CM_DIV_INT_SHIFT)
.equ CM_PWM_CTL_STOP, CM_PASSWORD | CM_CTL_SRC_OSC
.equ CM_PWM_CTL_START, CM_PASSWORD | CM_CTL_ENAB | CM_CTL_SRC_OSC

.equ GPIO_FUNCTION_ALT5, 2
.equ PI_AUDIO_LEFT_PIN,  18
.equ PI_AUDIO_RIGHT_PIN, 19
.equ PI_AUDIO_PWM_RANGE, 200
.equ PI_AUDIO_PWM_MID,   (PI_AUDIO_PWM_RANGE >> 1)
.equ PI_AUDIO_CLOCK_POLLS, 4096

.globl pi_audio_pwm_init
.globl pi_audio_pwm_write_stereo
.weak pi_audio_pwm_mmio_read
.weak pi_audio_pwm_mmio_write
.weak pi_audio_clock_mmio_read
.weak pi_audio_clock_mmio_write

.extern gpio_select_function

@ ---- pi_audio_pwm_init ----
@ Configure GPIO18/19 as PWM ALT5 and start PWM channels 1/2.
@ Returns r0 = 0 on success.
pi_audio_pwm_init:
    push    {r4, lr}

    mov     r0, #PI_AUDIO_LEFT_PIN
    mov     r1, #GPIO_FUNCTION_ALT5
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Laudio_init_fail

    mov     r0, #PI_AUDIO_RIGHT_PIN
    mov     r1, #GPIO_FUNCTION_ALT5
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Laudio_init_fail

    mov     r0, #PWM_CTL
    mov     r1, #0
    bl      pi_audio_pwm_mmio_write

    mov     r0, #CM_PWMCTL
    ldr     r1, =CM_PWM_CTL_STOP
    bl      pi_audio_clock_mmio_write

    mov     r4, #PI_AUDIO_CLOCK_POLLS
1:
    mov     r0, #CM_PWMCTL
    bl      pi_audio_clock_mmio_read
    tst     r0, #CM_CTL_BUSY
    beq     2f
    subs    r4, r4, #1
    bne     1b
    b       .Laudio_init_fail
2:
    mov     r0, #CM_PWMDIV
    ldr     r1, =CM_PWM_DIV_WORD
    bl      pi_audio_clock_mmio_write

    mov     r0, #CM_PWMCTL
    ldr     r1, =CM_PWM_CTL_START
    bl      pi_audio_clock_mmio_write

    mov     r0, #PWM_STA
    ldr     r1, =PWM_STA_ALL
    bl      pi_audio_pwm_mmio_write

    mov     r0, #PWM_RNG1
    mov     r1, #PI_AUDIO_PWM_RANGE
    bl      pi_audio_pwm_mmio_write

    mov     r0, #PWM_RNG2
    mov     r1, #PI_AUDIO_PWM_RANGE
    bl      pi_audio_pwm_mmio_write

    mov     r0, #PWM_DAT1
    mov     r1, #PI_AUDIO_PWM_MID
    bl      pi_audio_pwm_mmio_write

    mov     r0, #PWM_DAT2
    mov     r1, #PI_AUDIO_PWM_MID
    bl      pi_audio_pwm_mmio_write

    mov     r0, #PWM_CTL
    ldr     r1, =PWM_CTL_AUDIO_ENABLE
    bl      pi_audio_pwm_mmio_write

    mov     r0, #0
    pop     {r4, pc}

.Laudio_init_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- pi_audio_pwm_write_stereo ----
@ r0 = left sample, r1 = right sample. Samples must be < PI_AUDIO_PWM_RANGE.
@ Returns r0 = 0 on success.
pi_audio_pwm_write_stereo:
    push    {r4, lr}
    cmp     r0, #PI_AUDIO_PWM_RANGE
    bhs     .Laudio_write_fail
    cmp     r1, #PI_AUDIO_PWM_RANGE
    bhs     .Laudio_write_fail
    mov     r4, r1
    mov     r1, r0
    mov     r0, #PWM_DAT1
    bl      pi_audio_pwm_mmio_write
    mov     r0, #PWM_DAT2
    mov     r1, r4
    bl      pi_audio_pwm_mmio_write
    mov     r0, #0
    pop     {r4, pc}

.Laudio_write_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- default MMIO hooks ----
pi_audio_pwm_mmio_read:
    ldr     r1, =PWM_BASE
    ldr     r0, [r1, r0]
    bx      lr

pi_audio_pwm_mmio_write:
    ldr     r2, =PWM_BASE
    str     r1, [r2, r0]
    bx      lr

pi_audio_clock_mmio_read:
    ldr     r1, =CM_BASE
    ldr     r0, [r1, r0]
    bx      lr

pi_audio_clock_mmio_write:
    ldr     r2, =CM_BASE
    str     r1, [r2, r0]
    bx      lr
