@ Raspberry Pi Zero W BCM2835 GPIO driver -- ARM1176JZF-S.
@
@ Public API:
@   gpio_select_function(pin, function)  r0 = 0 on success
@   gpio_set_pin(pin)                    r0 = 0 on success
@   gpio_clear_pin(pin)                  r0 = 0 on success
@   gpio_read_pin(pin)                   r0 = 0 on success, r1 = 0/1
@   gpio_led_init/on/off()               ACT LED helpers for GPIO 47

.syntax unified
.cpu arm1176jzf-s
.arm

.equ PERIPHERAL_BASE, 0x20000000
.equ GPIO_BASE,       PERIPHERAL_BASE + 0x00200000

.equ GPIO_PIN_COUNT, 54
.equ GPIO_PIN_WORD_BITS, 32
.equ GPIO_FSEL_PINS_PER_REG, 10
.equ GPIO_FSEL_BITS_PER_PIN, 3
.equ GPIO_FUNCTION_MASK, 7
.equ GPIO_FUNCTION_INPUT, 0
.equ GPIO_FUNCTION_OUTPUT, 1
.equ GPIO_ACT_LED_PIN, 47

.equ GPIO_GPFSEL0, 0x00
.equ GPIO_GPSET0,  0x1c
.equ GPIO_GPCLR0,  0x28
.equ GPIO_GPLEV0,  0x34
.equ GPIO_REG_STRIDE, 4

.globl gpio_select_function
.globl gpio_set_pin
.globl gpio_clear_pin
.globl gpio_read_pin
.globl gpio_led_init
.globl gpio_led_on
.globl gpio_led_off
.weak gpio_mmio_read
.weak gpio_mmio_write

@ ---- gpio_select_function ----
@ r0 = GPIO pin 0..53, r1 = function 0..7.
@ Returns r0 = 0 on success.
gpio_select_function:
    push    {r4, r5, r6, r7, lr}
    cmp     r0, #GPIO_PIN_COUNT
    bhs     .Lgpio_select_fail
    cmp     r1, #GPIO_FUNCTION_MASK
    bhi     .Lgpio_select_fail
    mov     r4, r0
    mov     r5, r1
    mov     r6, #0
1:
    cmp     r4, #GPIO_FSEL_PINS_PER_REG
    blo     2f
    sub     r4, r4, #GPIO_FSEL_PINS_PER_REG
    add     r6, r6, #GPIO_REG_STRIDE
    b       1b
2:
    mov     r7, r4
    add     r7, r7, r4, lsl #1
    mov     r0, r6
    bl      gpio_mmio_read
    mov     r2, #GPIO_FUNCTION_MASK
    lsl     r2, r2, r7
    bic     r0, r0, r2
    lsl     r5, r5, r7
    orr     r1, r0, r5
    mov     r0, r6
    bl      gpio_mmio_write
    mov     r0, #0
    pop     {r4, r5, r6, r7, pc}

.Lgpio_select_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, pc}

@ ---- gpio_set_pin ----
@ r0 = GPIO pin 0..53.
@ Returns r0 = 0 on success.
gpio_set_pin:
    push    {lr}
    ldr     r1, =GPIO_GPSET0
    bl      gpio_write_pin_word
    pop     {pc}

@ ---- gpio_clear_pin ----
@ r0 = GPIO pin 0..53.
@ Returns r0 = 0 on success.
gpio_clear_pin:
    push    {lr}
    ldr     r1, =GPIO_GPCLR0
    bl      gpio_write_pin_word
    pop     {pc}

@ ---- gpio_read_pin ----
@ r0 = GPIO pin 0..53.
@ Returns r0 = 0 on success, r1 = 0/1 level.
gpio_read_pin:
    push    {r4, r5, lr}
    cmp     r0, #GPIO_PIN_COUNT
    bhs     .Lgpio_read_fail
    mov     r4, #0
1:
    cmp     r0, #GPIO_PIN_WORD_BITS
    blo     2f
    sub     r0, r0, #GPIO_PIN_WORD_BITS
    add     r4, r4, #GPIO_REG_STRIDE
    b       1b
2:
    mov     r5, #1
    lsl     r5, r5, r0
    ldr     r0, =GPIO_GPLEV0
    add     r0, r0, r4
    bl      gpio_mmio_read
    tst     r0, r5
    movne   r1, #1
    moveq   r1, #0
    mov     r0, #0
    pop     {r4, r5, pc}

.Lgpio_read_fail:
    mov     r0, #1
    mov     r1, #0
    pop     {r4, r5, pc}

@ ---- gpio_led_init/on/off ----
gpio_led_init:
    push    {lr}
    mov     r0, #GPIO_ACT_LED_PIN
    mov     r1, #GPIO_FUNCTION_OUTPUT
    bl      gpio_select_function
    pop     {pc}

gpio_led_on:
    push    {lr}
    mov     r0, #GPIO_ACT_LED_PIN
    bl      gpio_set_pin
    pop     {pc}

gpio_led_off:
    push    {lr}
    mov     r0, #GPIO_ACT_LED_PIN
    bl      gpio_clear_pin
    pop     {pc}

@ ---- gpio_write_pin_word ----
@ r0 = pin, r1 = GPSET0/GPCLR0 offset.
@ Returns r0 = 0 on success.
gpio_write_pin_word:
    push    {r4, r5, lr}
    cmp     r0, #GPIO_PIN_COUNT
    bhs     .Lgpio_write_pin_fail
    mov     r4, r1
1:
    cmp     r0, #GPIO_PIN_WORD_BITS
    blo     2f
    sub     r0, r0, #GPIO_PIN_WORD_BITS
    add     r4, r4, #GPIO_REG_STRIDE
    b       1b
2:
    mov     r5, #1
    lsl     r5, r5, r0
    mov     r0, r4
    mov     r1, r5
    bl      gpio_mmio_write
    mov     r0, #0
    pop     {r4, r5, pc}

.Lgpio_write_pin_fail:
    mov     r0, #1
    pop     {r4, r5, pc}

@ ---- default MMIO hooks ----
@ r0 = GPIO register offset, r1 = value for write.
gpio_mmio_read:
    ldr     r1, =GPIO_BASE
    ldr     r0, [r1, r0]
    bx      lr

gpio_mmio_write:
    ldr     r2, =GPIO_BASE
    str     r1, [r2, r0]
    bx      lr
