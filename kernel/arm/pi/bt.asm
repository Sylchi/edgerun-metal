@ Raspberry Pi Zero W CYW43438 Bluetooth UART bring-up -- ARM1176JZF-S.
@
@ Public API:
@   pi_bt_init()  r0 = 0 on success.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ PERIPHERAL_BASE, 0x20000000
.equ PL011_BASE,      PERIPHERAL_BASE + 0x00201000

.equ PL011_DR,    0x000
.equ PL011_FR,    0x018
.equ PL011_IBRD,  0x024
.equ PL011_FBRD,  0x028
.equ PL011_LCR_H, 0x02c
.equ PL011_CR,    0x030
.equ PL011_IMSC,  0x038
.equ PL011_ICR,   0x044

.equ PL011_CR_UARTEN, (1 << 0)
.equ PL011_CR_TXE,    (1 << 8)
.equ PL011_CR_RXE,    (1 << 9)
.equ PL011_CR_RTSEN,  (1 << 14)
.equ PL011_CR_CTSEN,  (1 << 15)
.equ PL011_LCR_H_8N1_FIFO, 0x70
.equ PL011_ICR_ALL, 0x7ff
.equ PL011_IBRD_3MHZ_115200, 1
.equ PL011_FBRD_3MHZ_115200, 40

.equ GPIO_FUNCTION_ALT3, 7
.equ PI_BT_CTS_PIN, 30
.equ PI_BT_RTS_PIN, 31
.equ PI_BT_TX_PIN,  32
.equ PI_BT_RX_PIN,  33
.equ PI_BT_REG_ON_PIN, 45
.equ PI_BT_RESET_DELAY, 4096

.globl pi_bt_init
.weak pi_bt_uart_mmio_write

.extern gpio_select_function
.extern gpio_set_pin
.extern gpio_clear_pin

@ ---- pi_bt_init ----
@ Configure GPIO30..33 as UART0 ALT3, toggle BT_REG_ON, and enable PL011.
@ Returns r0 = 0 on success.
pi_bt_init:
    push    {r4, lr}

    mov     r0, #PI_BT_CTS_PIN
    mov     r1, #GPIO_FUNCTION_ALT3
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r0, #PI_BT_RTS_PIN
    mov     r1, #GPIO_FUNCTION_ALT3
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r0, #PI_BT_TX_PIN
    mov     r1, #GPIO_FUNCTION_ALT3
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r0, #PI_BT_RX_PIN
    mov     r1, #GPIO_FUNCTION_ALT3
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r0, #PI_BT_REG_ON_PIN
    mov     r1, #1
    bl      gpio_select_function
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r0, #PI_BT_REG_ON_PIN
    bl      gpio_clear_pin
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r4, #PI_BT_RESET_DELAY
1:
    subs    r4, r4, #1
    bne     1b

    mov     r0, #PI_BT_REG_ON_PIN
    bl      gpio_set_pin
    cmp     r0, #0
    bne     .Lpi_bt_fail

    mov     r0, #PL011_CR
    mov     r1, #0
    bl      pi_bt_uart_mmio_write

    mov     r0, #PL011_IBRD
    mov     r1, #PL011_IBRD_3MHZ_115200
    bl      pi_bt_uart_mmio_write

    mov     r0, #PL011_FBRD
    mov     r1, #PL011_FBRD_3MHZ_115200
    bl      pi_bt_uart_mmio_write

    mov     r0, #PL011_LCR_H
    mov     r1, #PL011_LCR_H_8N1_FIFO
    bl      pi_bt_uart_mmio_write

    mov     r0, #PL011_ICR
    ldr     r1, =PL011_ICR_ALL
    bl      pi_bt_uart_mmio_write

    mov     r0, #PL011_IMSC
    mov     r1, #0
    bl      pi_bt_uart_mmio_write

    mov     r0, #PL011_CR
    ldr     r1, =(PL011_CR_UARTEN | PL011_CR_TXE | PL011_CR_RXE | PL011_CR_RTSEN | PL011_CR_CTSEN)
    bl      pi_bt_uart_mmio_write

    mov     r0, #0
    pop     {r4, pc}

.Lpi_bt_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- pi_bt_uart_mmio_write ----
@ r0 = PL011 register offset, r1 = value.
pi_bt_uart_mmio_write:
    ldr     r2, =PL011_BASE
    str     r1, [r2, r0]
    bx      lr
