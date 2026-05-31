@ Pi Zero W v1.1 boot entry point -- ARM1176JZF-S (ARMv6)
@ The GPU loads kernel.img to 0x8000 and starts execution here.
@
@ This is the very first code that runs on the Pi.  It sets up:
@   1. Exception vectors at 0x8000
@   2. Stack pointer (SVC mode)
@   3. PL011 UART for serial output
@   4. GPIO ACT LED to show life
@   5. Jump to kernel_main

@ Peripheral base for Pi Zero W v1.1 (BCM2835)
.equ PERIPHERAL_BASE, 0x20000000
.equ PL011_BASE,      PERIPHERAL_BASE + 0x00201000
.equ MAILBOX_BASE,    PERIPHERAL_BASE + 0x0000b880

@ PL011 register offsets
.equ PL011_DR,    0x000
.equ PL011_FR,    0x018
.equ PL011_IBRD,  0x024
.equ PL011_FBRD,  0x028
.equ PL011_LCR_H, 0x02c
.equ PL011_CR,    0x030
.equ PL011_IMSC,  0x038
.equ PL011_ICR,   0x044

@ PL011 FR flags
.equ PL011_FR_TXFF, (1 << 5)
.equ PL011_FR_RXFE, (1 << 4)

@ PL011 LCR_H: 8-bit + FIFO + 1 stop bit + no parity
.equ PL011_LCR_H_8N1, 0x60

@ PL011 CR flags
.equ PL011_CR_UARTEN, (1 << 0)
.equ PL011_CR_TXE,    (1 << 8)
.equ PL011_CR_RXE,    (1 << 9)

@ Mailbox registers (offset from MAILBOX_BASE)
.equ MAILBOX_RD,   0x00
.equ MAILBOX_WR,   0x00
.equ MAILBOX_STA,  0x18
.equ MAILBOX_CFG,  0x1c

@ Mailbox status flags
.equ MAILBOX_FULL,     (1 << 31)
.equ MAILBOX_EMPTY,    (1 << 30)

@ Mailbox property channel
.equ PROPERTY_CHANNEL, 8

@ Mailbox property tags
.equ TAG_GET_BOARD_REV,     0x00010002
.equ TAG_GET_BOARD_SERIAL,  0x00010004
.equ TAG_GET_ARM_MEM,       0x00010005
.equ TAG_GET_CLOCK_RATE,    0x00030002
.equ TAG_LAST,               0

@ Clock IDs for TAG_GET_CLOCK_RATE
.equ CLOCK_ID_ARM,  0x0
.equ CLOCK_ID_CORE, 0x4
.equ CLOCK_ID_EMMC, 0x1
.equ CLOCK_ID_UART, 0x2

@ External references
.extern emmc_init
.extern emmc_read_block
.extern emmc_sdio_wifi_enable
.extern dwc2_init
.extern dwc2_port_detect
.extern dwc2_enumerate
.extern gpio_led_init
.extern gpio_led_on

@ USB speed constants (from dwc2.asm)
.equ USB_SPEED_HS, 0
.equ USB_SPEED_FS, 1
.equ USB_SPEED_LS, 2

.section .text.startup,"ax",%progbits
.globl _start
_start:
    @ Exception vectors
    b       reset_handler
    b       undef_handler
    b       swi_handler
    b       prefetch_abort_handler
    b       data_abort_handler
    b       .
    b       irq_handler
    b       fiq_handler

reset_handler:
    @ Set SVC mode stack pointer
    ldr     sp, =stack_top

    @ Initialize PL011 UART
    bl      pl011_init

    @ Say hello
    ldr     r0, =hello_msg
    bl      pl011_puts

    @ Blink the ACT LED (GPIO 47 on Pi Zero W) to show life
    bl      gpio_led_init
    bl      gpio_led_on

    @ Jump to kernel main
    bl      kernel_main

hang:
    wfi
    b       hang

undef_handler:
    ldr     r0, =msg_undef
    bl      pl011_puts
    b       hang

swi_handler:
    ldr     r0, =msg_swi
    bl      pl011_puts
    b       hang

prefetch_abort_handler:
    ldr     r0, =msg_pabt
    bl      pl011_puts
    b       hang

data_abort_handler:
    ldr     r0, =msg_dabt
    bl      pl011_puts
    b       hang

irq_handler:
    ldr     r0, =msg_irq
    bl      pl011_puts
    b       hang

fiq_handler:
    ldr     r0, =msg_fiq
    bl      pl011_puts
    b       hang

@ pl011_init -- initialize PL011 UART at 115200 baud
pl011_init:
    push    {lr}

    @ Disable UART while configuring
    ldr     r1, =PL011_BASE
    mov     r0, #0
    str     r0, [r1, #PL011_CR]

    @ Set baud rate: UART clock = 3 MHz
    @ IBRD = 1, FBRD = 40 (for 115200)
    mov     r0, #1
    str     r0, [r1, #PL011_IBRD]
    mov     r0, #40
    str     r0, [r1, #PL011_FBRD]

    @ Line control: 8N1 + FIFO
    mov     r0, #PL011_LCR_H_8N1
    str     r0, [r1, #PL011_LCR_H]

    @ Clear pending interrupts
    ldr     r0, =0x7ff
    str     r0, [r1, #PL011_ICR]

    @ Disable all interrupts
    mov     r0, #0
    str     r0, [r1, #PL011_IMSC]

    @ Enable UART, TX, RX
    ldr     r0, =(PL011_CR_UARTEN | PL011_CR_TXE | PL011_CR_RXE)
    str     r0, [r1, #PL011_CR]

    pop     {pc}

@ pl011_putchar -- write one character
@ r0 = character
pl011_putchar:
    ldr     r1, =PL011_BASE
.Lwait_tx:
    ldr     r2, [r1, #PL011_FR]
    tst     r2, #PL011_FR_TXFF
    bne     .Lwait_tx
    str     r0, [r1, #PL011_DR]
    bx      lr

@ pl011_getchar -- read one character, or return 0 if none
pl011_getchar:
    ldr     r1, =PL011_BASE
    ldr     r2, [r1, #PL011_FR]
    tst     r2, #PL011_FR_RXFE
    bne     .Lno_data
    ldr     r0, [r1, #PL011_DR]
    bx      lr
.Lno_data:
    mov     r0, #0
    bx      lr

@ pl011_puts -- write null-terminated string
@ r0 = string pointer
pl011_puts:
    push    {lr}
    mov     r3, r0
.Lloop:
    ldrb    r0, [r3], #1
    cmp     r0, #0
    beq     .Ldone
    bl      pl011_putchar
    b       .Lloop
.Ldone:
    pop     {pc}

@ pl011_crlf -- write CR+LF
pl011_crlf:
    push    {lr}
    ldr     r0, =crlf_msg
    bl      pl011_puts
    pop     {pc}

@ pl011_puthex32 -- write 32-bit hex value
@ r0 = value
pl011_puthex32:
    push    {r4, lr}
    mov     r4, r0
    mov     r2, #8
    ldr     r0, =hex_prefix
    bl      pl011_puts
.Lhex_loop:
    mov     r0, r4, lsr #28
    and     r0, r0, #0xf
    cmp     r0, #10
    addlo   r0, r0, #'0'
    addhs   r0, r0, #('a' - 10)
    bl      pl011_putchar
    mov     r4, r4, lsl #4
    subs    r2, r2, #1
    bne     .Lhex_loop
    pop     {r4, pc}

@ pl011_putdec32 -- write 32-bit decimal value
@ r0 = value
pl011_putdec32:
    push    {r4, r5, lr}
    mov     r4, r0
    mov     r5, #0
    ldr     r2, =dec_buf
    add     r2, r2, #10
    mov     r1, #0
    strb    r1, [r2]
.Ldec_loop:
    mov     r0, r4
    mov     r1, #10
    bl      __udivmod
    mov     r4, r0
    add     r1, r1, #'0'
    sub     r2, r2, #1
    strb    r1, [r2]
    add     r5, r5, #1
    cmp     r4, #0
    bne     .Ldec_loop

    ldr     r0, =dec_buf
    add     r0, r0, #10
    sub     r0, r0, r5
    bl      pl011_puts
    pop     {r4, r5, pc}

@ __udivmod -- unsigned division
@ r0 = quotient on return, r1 = remainder
__udivmod:
    push    {r2, r3}
    mov     r2, r1
    mov     r1, r0
    mov     r0, #0
    cmp     r2, #0
    beq     .Ldiv_end
    mov     r3, #1
.Ldiv_shift:
    cmp     r2, r1
    bhi     .Ldiv_loop
    mov     r2, r2, lsl #1
    mov     r3, r3, lsl #1
    b       .Ldiv_shift
.Ldiv_loop:
    cmp     r2, r1
    bhi     .Ldiv_next
    sub     r1, r1, r2
    orr     r0, r0, r3
.Ldiv_next:
    mov     r2, r2, lsr #1
    mov     r3, r3, lsr #1
    cmp     r3, #0
    bne     .Ldiv_loop
.Ldiv_end:
    pop     {r2, r3}
    bx      lr

@ ==================================================================
@ Mailbox functions
@ ==================================================================

@ mailbox_write — write value to property channel
@ r0 = 28-bit aligned value (will be ORed with channel 8)
mailbox_write:
    ldr     r1, =MAILBOX_BASE
    and     r0, r0, #0xfffffff0
    orr     r0, r0, #PROPERTY_CHANNEL
.Lwait_wr:
    ldr     r2, [r1, #MAILBOX_STA]
    tst     r2, #MAILBOX_FULL
    bne     .Lwait_wr
    str     r0, [r1, #MAILBOX_WR]
    bx      lr

@ mailbox_read — read value from property channel
@ Returns: r0 = 28-bit aligned value
mailbox_read:
    ldr     r1, =MAILBOX_BASE
.Lwait_rd:
    ldr     r2, [r1, #MAILBOX_STA]
    tst     r2, #MAILBOX_EMPTY
    bne     .Lwait_rd
    ldr     r2, [r1, #MAILBOX_RD]   @ read once: bits 3:0 = channel
    and     r3, r2, #0xf            @ extract channel
    cmp     r3, #PROPERTY_CHANNEL
    bne     .Lwait_rd               @ wrong channel, retry
    and     r0, r2, #0xfffffff0     @ extract data (28-bit aligned)
    bx      lr

@ mailbox_call — send property tag request and wait for response
@ r0 = 28-bit aligned buffer address
@ Buffer format:
@   [0-3]:   buffer size (32-bit)
@   [4-7]:   request code (0 = request)
@   [8...]:  tags (each 16-byte aligned)
@   [...]:   0 (end tag)
@ Returns: r0 = 0 on success, non-zero on failure
mailbox_call:
    push    {lr}
    bl      mailbox_write
    bl      mailbox_read
    @ Check response code at buffer[4]
    ldr     r1, [r0, #4]
    cmp     r1, #0x80000000
    movne   r0, #1
    moveq   r0, #0
    pop     {pc}

@ ==================================================================
@ kernel_main — entry from reset_handler
@ ==================================================================
.globl kernel_main
kernel_main:
    push    {lr}

    @ Query board revision
    ldr     r0, =msg_board
    bl      pl011_puts
    ldr     r0, =mbuf_board
    bl      mailbox_call
    ldr     r0, =mbuf_board
    add     r0, r0, #20         @ response data at offset 20
    ldr     r0, [r0]
    bl      pl011_puthex32
    bl      pl011_crlf

    @ Query board serial
    ldr     r0, =msg_serial
    bl      pl011_puts
    ldr     r0, =mbuf_serial
    bl      mailbox_call
    ldr     r0, =mbuf_serial
    add     r0, r0, #20         @ serial low at offset 20
    ldr     r0, [r0]
    bl      pl011_puthex32
    ldr     r0, =mbuf_serial
    add     r0, r0, #24         @ serial high at offset 24
    ldr     r0, [r0]
    bl      pl011_puthex32
    bl      pl011_crlf

    @ Query ARM memory
    ldr     r0, =msg_arm_mem
    bl      pl011_puts
    ldr     r0, =mbuf_arm_mem
    bl      mailbox_call
    ldr     r0, =mbuf_arm_mem
    add     r0, r0, #20         @ base at offset 20
    ldr     r0, [r0]
    bl      pl011_puthex32
    ldr     r0, =msg_size
    bl      pl011_puts
    ldr     r0, =mbuf_arm_mem
    add     r0, r0, #24         @ size at offset 24
    ldr     r0, [r0]
    bl      pl011_puthex32
    bl      pl011_crlf

    @ Query clock rates (ARM, Core, EMMC, UART)
    ldr     r0, =msg_arm_clk
    bl      pl011_puts
    ldr     r0, =mbuf_arm_clk
    bl      mailbox_call
    ldr     r0, =mbuf_arm_clk
    add     r0, r0, #24         @ rate at offset 24
    ldr     r0, [r0]
    bl      pl011_putdec32
    ldr     r0, =msg_hz
    bl      pl011_puts
    bl      pl011_crlf

    ldr     r0, =msg_core_clk
    bl      pl011_puts
    ldr     r0, =mbuf_core_clk
    bl      mailbox_call
    ldr     r0, =mbuf_core_clk
    add     r0, r0, #24         @ rate at offset 24
    ldr     r0, [r0]
    bl      pl011_putdec32
    ldr     r0, =msg_hz
    bl      pl011_puts
    bl      pl011_crlf

    ldr     r0, =msg_emmc_clk
    bl      pl011_puts
    ldr     r0, =mbuf_emmc_clk
    bl      mailbox_call
    ldr     r0, =mbuf_emmc_clk
    add     r0, r0, #24         @ rate at offset 24
    ldr     r0, [r0]
    bl      pl011_putdec32
    ldr     r0, =msg_hz
    bl      pl011_puts
    bl      pl011_crlf

    ldr     r0, =msg_uart_clk
    bl      pl011_puts
    ldr     r0, =mbuf_uart_clk
    bl      mailbox_call
    ldr     r0, =mbuf_uart_clk
    add     r0, r0, #24         @ rate at offset 24
    ldr     r0, [r0]
    bl      pl011_putdec32
    ldr     r0, =msg_hz
    bl      pl011_puts
    bl      pl011_crlf

    @ Probe Pi Zero W CYW43438 SDIO before SD-memory init.
    ldr     r0, =msg_wifi_probe
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    bl      emmc_sdio_wifi_enable
    cmp     r0, #0
    bne     .Lwifi_fail
    ldr     r0, =msg_ok
    bl      pl011_puts
    ldr     r0, =msg_wifi_ocr
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0]
    bl      pl011_puthex32
    ldr     r0, =msg_wifi_cccr
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0, #4]
    bl      pl011_puthex32
    ldr     r0, =msg_wifi_ready
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0, #8]
    bl      pl011_puthex32
    ldr     r0, =msg_wifi_bus
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0, #12]
    bl      pl011_puthex32
    ldr     r0, =msg_wifi_block
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0, #16]
    bl      pl011_puthex32
    ldr     r0, =msg_wifi_clk
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0, #20]
    bl      pl011_puthex32
    ldr     r0, =msg_wifi_sig
    bl      pl011_puts
    ldr     r0, =wifi_probe_buf
    ldr     r0, [r0, #24]
    bl      pl011_puthex32
    bl      pl011_crlf
    b       .Lwifi_done

.Lwifi_fail:
    ldr     r0, =msg_fail
    bl      pl011_puts
    bl      pl011_crlf
    b       hang

.Lwifi_done:

    @ Init SD card
    ldr     r0, =msg_sd_init
    bl      pl011_puts
    bl      emmc_init
    cmp     r0, #0
    bne     .Lsd_fail
    ldr     r0, =msg_ok
    bl      pl011_puts
    bl      pl011_crlf

    @ Read MBR (sector 0)
    ldr     r0, =msg_sd_read
    bl      pl011_puts
    ldr     r0, =sector_buf
    mov     r1, r0
    mov     r0, #0
    bl      emmc_read_block
    cmp     r0, #0
    bne     .Lsd_fail
    ldr     r0, =msg_ok
    bl      pl011_puts
    bl      pl011_crlf

    @ Dump MBR signature (bytes 510-511)
    ldr     r0, =msg_sig
    bl      pl011_puts
    ldr     r5, =sector_buf
    add     r5, r5, #512
    sub     r5, r5, #2
    ldrb    r0, [r5]
    ldrb    r1, [r5, #1]
    orr     r0, r1, r0, lsl #8
    bl      pl011_puthex32
    bl      pl011_crlf

    b       .Lmain_start

.Lsd_fail:
    ldr     r0, =msg_fail
    bl      pl011_puts
    bl      pl011_crlf

    @ ---- USB init via DWC2 ----
    ldr     r0, =msg_usb_init
    bl      pl011_puts
    bl      dwc2_init
    cmp     r0, #0
    bne     .Lusb_fail_full
    ldr     r0, =msg_ok
    bl      pl011_puts
    bl      pl011_crlf

    @ ---- USB port detect ----
    ldr     r0, =msg_usb_port
    bl      pl011_puts
    sub     sp, sp, #4          @ allocate speed byte
    mov     r0, sp
    bl      dwc2_port_detect
    cmp     r0, #0
    bne     .Lusb_fail

    ldr     r0, =msg_ok
    bl      pl011_puts
    bl      pl011_crlf

    @ Print port speed
    ldrb    r0, [sp]
    cmp     r0, #USB_SPEED_HS
    ldreq   r0, =msg_speed_hs
    cmp     r0, #USB_SPEED_FS
    ldreq   r0, =msg_speed_fs
    cmp     r0, #USB_SPEED_LS
    ldreq   r0, =msg_speed_ls
    bleq    pl011_puts

    @ ---- USB enumerate ----
    ldr     r0, =msg_usb_enum
    bl      pl011_puts
    bl      dwc2_enumerate
    cmp     r0, #0
    beq     .Lusb_fail

    mov     r1, r0
    ldr     r0, =msg_ok
    bl      pl011_puts
    bl      pl011_crlf

    @ Print device address
    ldr     r0, =msg_usb_addr
    bl      pl011_puts
    mov     r0, r1
    bl      pl011_putdec32
    bl      pl011_crlf

    add     sp, sp, #4
    b       .Lmain_start

.Lusb_fail:
    add     sp, sp, #4          @ deallocate speed byte
.Lusb_fail_full:
    ldr     r0, =msg_fail
    bl      pl011_puts
    bl      pl011_crlf

.Lmain_start:

    @ Prompt and echo loop
    ldr     r0, =prompt_msg
    bl      pl011_puts
.Lmain_loop:
    bl      pl011_getchar
    cmp     r0, #0
    beq     .Lmain_loop
    bl      pl011_putchar
    cmp     r0, #0x0d
    bne     .Lmain_loop
    ldr     r0, =crlf_msg
    bl      pl011_puts
    b       .Lmain_loop

    pop     {pc}

@ Read-only data
.section .rodata,"a",%progbits
hello_msg:  .asciz "\r\nEdgeRun Pi Zero W v1.1 -- self-hosted ASM\r\n"
prompt_msg: .asciz "\r\n> "
crlf_msg:   .asciz "\r\n"
hex_prefix: .asciz "0x"
msg_undef:  .asciz "\r\nEXCEPTION: Undefined instruction\r\n"
msg_swi:    .asciz "\r\nEXCEPTION: Software interrupt\r\n"
msg_pabt:   .asciz "\r\nEXCEPTION: Prefetch abort\r\n"
msg_dabt:   .asciz "\r\nEXCEPTION: Data abort\r\n"
msg_irq:    .asciz "\r\nEXCEPTION: IRQ\r\n"
msg_fiq:    .asciz "\r\nEXCEPTION: FIQ\r\n"
msg_board:  .asciz "\r\nBoard revision: "
msg_serial: .asciz "\r\nBoard serial:  "
msg_arm_mem:.asciz "\r\nARM memory:    base="
msg_size:   .asciz " size="
msg_arm_clk:.asciz "\r\nARM clock:     "
msg_core_clk:.asciz "\r\nCore clock:    "
msg_emmc_clk:.asciz "\r\nEMMC clock:    "
msg_uart_clk:.asciz "\r\nUART clock:    "
msg_hz:     .asciz " Hz"
msg_sd_init:.asciz "\r\nSD init: "
msg_sd_read:.asciz "\r\nSD read:  "
msg_sig:    .asciz "\r\nMBR sig:  0x"
msg_wifi_probe:.asciz "\r\nWiFi SDIO probe: "
msg_wifi_ocr:.asciz " OCR="
msg_wifi_cccr:.asciz " CCCR="
msg_wifi_ready:.asciz " READY="
msg_wifi_bus:.asciz " BUS="
msg_wifi_block:.asciz " BLK="
msg_wifi_clk:.asciz " CLK="
msg_wifi_sig:.asciz " SIG="
msg_ok:     .asciz "ok"
msg_fail:   .asciz "FAIL"
msg_usb_init:.asciz "\r\nUSB init: "
msg_usb_port:.asciz "\r\nUSB port: "
msg_usb_enum:.asciz "\r\nUSB enum:  "
msg_usb_addr:.asciz "\r\nUSB addr:  "
msg_speed_hs:.asciz " (HS)\r\n"
msg_speed_fs:.asciz " (FS)\r\n"
msg_speed_ls:.asciz " (LS)\r\n"

@ Mailbox property tag buffers (must be 16-byte aligned)
.section .data
.align 4
mbuf_board:
    .word   28              @ buffer size (8 header + 16 tag + 4 end)
    .word   0               @ request code
    .word   TAG_GET_BOARD_REV
    .word   4               @ value_buffer_size
    .word   0               @ data_size = 0 (GET)
    .word   0               @ board revision (filled by VC)
    .word   TAG_LAST        @ end tag

mbuf_serial:
    .word   32
    .word   0
    .word   TAG_GET_BOARD_SERIAL
    .word   8               @ value_buffer_size (for 8-byte serial)
    .word   0               @ data_size = 0 (GET)
    .word   0               @ serial low (filled by VC)
    .word   0               @ serial high (filled by VC)
    .word   TAG_LAST

mbuf_arm_mem:
    .word   32
    .word   0
    .word   TAG_GET_ARM_MEM
    .word   8               @ value_buffer_size (base + size)
    .word   0               @ data_size = 0 (GET)
    .word   0               @ base address (filled by VC)
    .word   0               @ size (filled by VC)
    .word   TAG_LAST

mbuf_arm_clk:
    .word   32
    .word   0
    .word   TAG_GET_CLOCK_RATE
    .word   8               @ value_buffer_size (clock_id + rate)
    .word   4               @ data_size = 4 (send clock ID)
    .word   CLOCK_ID_ARM    @ clock ID (request)
    .word   0               @ rate (filled by VC)
    .word   TAG_LAST

mbuf_core_clk:
    .word   32
    .word   0
    .word   TAG_GET_CLOCK_RATE
    .word   8
    .word   4
    .word   CLOCK_ID_CORE
    .word   0
    .word   TAG_LAST

mbuf_emmc_clk:
    .word   32
    .word   0
    .word   TAG_GET_CLOCK_RATE
    .word   8
    .word   4
    .word   CLOCK_ID_EMMC
    .word   0
    .word   TAG_LAST

mbuf_uart_clk:
    .word   32
    .word   0
    .word   TAG_GET_CLOCK_RATE
    .word   8
    .word   4
    .word   CLOCK_ID_UART
    .word   0
    .word   TAG_LAST

.align 4
dec_buf:    .space 12
stack_bottom:
    .space 16384
stack_top:

@ Sector buffer for SD card reads (512 bytes)
.balign 512
sector_buf:
    .space 512

.align 4
wifi_probe_buf:
    .space 28
