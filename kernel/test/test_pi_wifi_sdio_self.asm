@ EdgeRun Pi Zero W CYW43438 SDIO Wi-Fi emulator — ARM assembly.
@ Links the real SDIO bring-up core from kernel/arm/pi/emmc.asm and
@ provides an emulated CYW43438 responder through emmc_sdio_cmd.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ CMD0_VAL,        (0 << 24)
.equ CMD3_VAL,        (3 << 24) | (2 << 16) | (1 << 19) | (1 << 20)
.equ CMD5_VAL,        (5 << 24) | (2 << 16)
.equ CMD7_VAL,        (7 << 24) | (3 << 16) | (1 << 19) | (1 << 20)
.equ CMD52_VAL,       (52 << 24) | (2 << 16) | (1 << 19) | (1 << 20)

.equ CMD5_VOLTAGE,    0x00ff8000
.equ SDIO_READY_BIT,  0x80000000
.equ CYW43438_OCR,    SDIO_READY_BIT | CMD5_VOLTAGE
.equ CYW43438_CCCR,   0x32
.equ CYW43438_RCA,    0x00010000
.equ SDIO_CMD52_WRITE, 0x80000000
.equ SDIO_CMD52_ADDR_SHIFT, 9
.equ SDIO_CMD53_WRITE, 0x80000000
.equ SDIO_CMD53_FUNC2, (2 << 28)
.equ SDIO_CMD53_OP_INC, (1 << 26)
.equ SDIO_CMD53_ADDR_SHIFT, 9
.equ SDIO_CMD53_WORD_BYTES, 4
.equ SDIO_CMD53_MAX_WORDS, 128
.equ SDIO_CMD53_ADDR_MASK, 0x1ffff
.equ SDIO_CCCR_REVISION,  0x00
.equ SDIO_CCCR_IO_ENABLE, 0x02
.equ SDIO_CCCR_IO_READY,  0x03
.equ SDIO_CCCR_BUS_IF,    0x07
.equ SDIO_FUNCS_MASK,     0x06
.equ SDIO_BUS_WIDTH_4BIT, 0x02
.equ CYW43438_BLOCK_BYTES, 64
.equ CMD52_READ_CCCR,     SDIO_CCCR_REVISION << SDIO_CMD52_ADDR_SHIFT
.equ CMD52_WRITE_IO_ENABLE, SDIO_CMD52_WRITE | (SDIO_CCCR_IO_ENABLE << SDIO_CMD52_ADDR_SHIFT) | SDIO_FUNCS_MASK
.equ CMD52_READ_IO_READY, SDIO_CCCR_IO_READY << SDIO_CMD52_ADDR_SHIFT
.equ CMD52_WRITE_BUS_IF,  SDIO_CMD52_WRITE | (SDIO_CCCR_BUS_IF << SDIO_CMD52_ADDR_SHIFT) | SDIO_BUS_WIDTH_4BIT
.equ CMD52_WRITE_F1_BLK_LO, SDIO_CMD52_WRITE | (0x110 << SDIO_CMD52_ADDR_SHIFT) | CYW43438_BLOCK_BYTES
.equ CMD52_WRITE_F1_BLK_HI, SDIO_CMD52_WRITE | (0x111 << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_WRITE_F2_BLK_LO, SDIO_CMD52_WRITE | (0x210 << SDIO_CMD52_ADDR_SHIFT) | CYW43438_BLOCK_BYTES
.equ CMD52_WRITE_F2_BLK_HI, SDIO_CMD52_WRITE | (0x211 << SDIO_CMD52_ADDR_SHIFT)
.equ SBSDIO_FUNC1_CHIPCLKCSR, 0x1000e
.equ SBSDIO_FUNC1_SDIOPULLUP, 0x1000f
.equ SBSDIO_FUNC1_SBADDRLOW,  0x1000a
.equ SBSDIO_FUNC1_SBADDRMID,  0x1000b
.equ SBSDIO_FUNC1_SBADDRHIGH, 0x1000c
.equ SBSDIO_ALP_REQ_VALUE, 0x28
.equ SBSDIO_FORCE_ALP_VALUE, 0x21
.equ SBSDIO_ALP_AVAIL, 0x40
.equ CYW43438_ENUM_BASE, 0x18000000
.equ CYW43438_SIGNATURE, 0x1542a9a6
.equ CYW43438_TEST_WRITE_ADDR, 0x18000004
.equ CYW43438_TEST_WRITE_VALUE, 0xa5c35a96
.equ CYW43438_TEST_CLEAR_MASK, 0x000000f0
.equ CYW43438_TEST_SET_MASK, 0x00000a00
.equ CYW43438_TEST_UPDATE_VALUE, 0x1542ab06
.equ CMD52_F1_READ_CHIPCLKCSR, (1 << 28) | (SBSDIO_FUNC1_CHIPCLKCSR << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_WRITE_ALP_REQ, SDIO_CMD52_WRITE | (1 << 28) | (SBSDIO_FUNC1_CHIPCLKCSR << SDIO_CMD52_ADDR_SHIFT) | SBSDIO_ALP_REQ_VALUE
.equ CMD52_F1_WRITE_FORCE_ALP, SDIO_CMD52_WRITE | (1 << 28) | (SBSDIO_FUNC1_CHIPCLKCSR << SDIO_CMD52_ADDR_SHIFT) | SBSDIO_FORCE_ALP_VALUE
.equ CMD52_F1_WRITE_PULLUP_OFF, SDIO_CMD52_WRITE | (1 << 28) | (SBSDIO_FUNC1_SDIOPULLUP << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_WRITE_SBADDRLOW,  SDIO_CMD52_WRITE | (1 << 28) | (SBSDIO_FUNC1_SBADDRLOW << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_WRITE_SBADDRMID,  SDIO_CMD52_WRITE | (1 << 28) | (SBSDIO_FUNC1_SBADDRMID << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_WRITE_SBADDRHIGH, SDIO_CMD52_WRITE | (1 << 28) | (SBSDIO_FUNC1_SBADDRHIGH << SDIO_CMD52_ADDR_SHIFT) | 0x18
.equ CMD52_F1_READ_ENUM0, (1 << 28) | 0
.equ CMD52_F1_READ_ENUM1, (1 << 28) | (1 << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_READ_ENUM2, (1 << 28) | (2 << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_READ_ENUM3, (1 << 28) | (3 << SDIO_CMD52_ADDR_SHIFT)
.equ CMD52_F1_WRITE_TEST0, SDIO_CMD52_WRITE | (1 << 28) | (4 << SDIO_CMD52_ADDR_SHIFT) | 0x96
.equ CMD52_F1_WRITE_TEST1, SDIO_CMD52_WRITE | (1 << 28) | (5 << SDIO_CMD52_ADDR_SHIFT) | 0x5a
.equ CMD52_F1_WRITE_TEST2, SDIO_CMD52_WRITE | (1 << 28) | (6 << SDIO_CMD52_ADDR_SHIFT) | 0xc3
.equ CMD52_F1_WRITE_TEST3, SDIO_CMD52_WRITE | (1 << 28) | (7 << SDIO_CMD52_ADDR_SHIFT) | 0xa5
.equ CMD52_F1_WRITE_UPDATE0, SDIO_CMD52_WRITE | (1 << 28) | 0x06
.equ CMD52_F1_WRITE_UPDATE1, SDIO_CMD52_WRITE | (1 << 28) | (1 << SDIO_CMD52_ADDR_SHIFT) | 0xab
.equ CMD52_F1_WRITE_UPDATE2, SDIO_CMD52_WRITE | (1 << 28) | (2 << SDIO_CMD52_ADDR_SHIFT) | 0x42
.equ CMD52_F1_WRITE_UPDATE3, SDIO_CMD52_WRITE | (1 << 28) | (3 << SDIO_CMD52_ADDR_SHIFT) | 0x15
.equ CMD53_F2_WRITE_ADDR, 0x1234
.equ CMD53_F2_WRITE_VALUE, 0x74434241
.equ CMD53_F2_WRITE_ARG, SDIO_CMD53_WRITE | SDIO_CMD53_FUNC2 | SDIO_CMD53_OP_INC | (CMD53_F2_WRITE_ADDR << SDIO_CMD53_ADDR_SHIFT) | SDIO_CMD53_WORD_BYTES
.equ CMD53_F2_WRITE_MANY_ADDR, 0x1240
.equ CMD53_F2_WRITE_MANY_WORDS, 3
.equ CMD53_F2_WRITE_MANY_BYTES, 12
.equ CMD53_F2_WRITE_MANY_ARG, SDIO_CMD53_WRITE | SDIO_CMD53_FUNC2 | SDIO_CMD53_OP_INC | (CMD53_F2_WRITE_MANY_ADDR << SDIO_CMD53_ADDR_SHIFT) | CMD53_F2_WRITE_MANY_BYTES
.equ CMD53_F2_BACKPLANE_ADDR, 0x18001240
.equ CMD53_F2_BACKPLANE_ARG, SDIO_CMD53_WRITE | SDIO_CMD53_FUNC2 | SDIO_CMD53_OP_INC | (CMD53_F2_WRITE_MANY_ADDR << SDIO_CMD53_ADDR_SHIFT) | CMD53_F2_WRITE_MANY_BYTES
.equ CMD53_F2_BAD_ADDR, SDIO_CMD53_ADDR_MASK + 1
.equ CMD53_F2_OVERFLOW_ADDR, SDIO_CMD53_ADDR_MASK - 1
.equ CMD53_F2_BACKPLANE_OVERFLOW_ADDR, 0x18007ffc
.equ TRACE_LIMIT,     25

.extern emmc_sdio_wifi_enable_core
.extern emmc_sdio_func1_write32
.extern emmc_sdio_func1_update32
.extern emmc_sdio_func2_write_word
.extern emmc_sdio_func2_write_words
.extern emmc_sdio_func2_write_backplane_words

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top

    bl      test_cyw43438_ready_probe
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_cyw43438_sdio_not_ready_fails
    cmp     r0, #0
    movne   r4, #2
    bne     .Lfail_code

    bl      test_cyw43438_io_not_ready_fails
    cmp     r0, #0
    movne   r4, #3
    bne     .Lfail_code

    bl      test_cyw43438_backplane_write32
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_cyw43438_backplane_update32
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_cyw43438_func2_write_word
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_cyw43438_func2_write_words
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_cyw43438_func2_write_backplane_words
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_cyw43438_func2_rejects_bad_addr
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    mov     r0, #0
    b       semihost_exit

.Lfail_code:
    mov     r0, r4
    b       semihost_exit

test_cyw43438_ready_probe:
    push    {lr}
    bl      reset_emulator
    mov     r0, #2
    ldr     r1, =ready_after
    str     r0, [r1]
    ldr     r0, =probe_out
    bl      emmc_sdio_wifi_enable_core
    cmp     r0, #0
    movne   r0, #11
    popne   {pc}

    ldr     r1, =probe_out
    ldr     r0, [r1, #4]
    cmp     r0, #CYW43438_CCCR
    movne   r0, #13
    popne   {pc}
    ldr     r0, [r1, #8]
    cmp     r0, #SDIO_FUNCS_MASK
    movne   r0, #14
    popne   {pc}
    ldr     r0, [r1, #12]
    cmp     r0, #SDIO_BUS_WIDTH_4BIT
    movne   r0, #16
    popne   {pc}
    ldr     r0, [r1, #16]
    cmp     r0, #CYW43438_BLOCK_BYTES
    movne   r0, #17
    popne   {pc}
    ldr     r0, [r1, #20]
    ldr     r4, =SBSDIO_ALP_REQ_VALUE | SBSDIO_ALP_AVAIL
    cmp     r0, r4
    movne   r0, #18
    popne   {pc}
    ldr     r0, [r1, #24]
    ldr     r4, =CYW43438_SIGNATURE
    cmp     r0, r4
    movne   r0, #19
    popne   {pc}

    ldr     r1, =trace_index
    ldr     r0, [r1]
    cmp     r0, #TRACE_LIMIT
    movne   r0, #15
    popne   {pc}

    ldr     r1, =trace_cmd
    ldr     r2, =trace_arg
    ldr     r0, [r1]
    cmp     r0, #CMD0_VAL
    bne     .Lready_fail
    ldr     r0, [r2]
    cmp     r0, #0
    bne     .Lready_fail

    ldr     r0, [r1, #4]
    ldr     r3, =CMD5_VAL
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #4]
    cmp     r0, #0
    bne     .Lready_fail

    ldr     r0, [r1, #8]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #8]
    ldr     r3, =CMD5_VOLTAGE
    cmp     r0, r3
    bne     .Lready_fail

    ldr     r0, [r1, #12]
    ldr     r3, =CMD3_VAL
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #12]
    cmp     r0, #0
    bne     .Lready_fail

    ldr     r0, [r1, #16]
    ldr     r3, =CMD7_VAL
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #16]
    ldr     r3, =CYW43438_RCA
    cmp     r0, r3
    bne     .Lready_fail

    ldr     r0, [r1, #20]
    ldr     r3, =CMD52_VAL
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #20]
    cmp     r0, #CMD52_READ_CCCR
    bne     .Lready_fail

    ldr     r0, [r1, #24]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #24]
    ldr     r4, =CMD52_WRITE_IO_ENABLE
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #28]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #28]
    cmp     r0, #CMD52_READ_IO_READY
    bne     .Lready_fail

    ldr     r0, [r1, #32]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #32]
    ldr     r4, =CMD52_WRITE_BUS_IF
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #36]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #36]
    ldr     r4, =CMD52_WRITE_F1_BLK_LO
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #40]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #40]
    ldr     r4, =CMD52_WRITE_F1_BLK_HI
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #44]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #44]
    ldr     r4, =CMD52_WRITE_F2_BLK_LO
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #48]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #48]
    ldr     r4, =CMD52_WRITE_F2_BLK_HI
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #52]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #52]
    ldr     r4, =CMD52_F1_WRITE_ALP_REQ
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #56]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #56]
    ldr     r4, =CMD52_F1_READ_CHIPCLKCSR
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #60]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #60]
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #64]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #64]
    ldr     r4, =CMD52_F1_WRITE_FORCE_ALP
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #68]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #68]
    ldr     r4, =CMD52_F1_WRITE_PULLUP_OFF
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #72]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #72]
    ldr     r4, =CMD52_F1_WRITE_SBADDRLOW
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #76]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #76]
    ldr     r4, =CMD52_F1_WRITE_SBADDRMID
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #80]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #80]
    ldr     r4, =CMD52_F1_WRITE_SBADDRHIGH
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #84]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #84]
    ldr     r4, =CMD52_F1_READ_ENUM0
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #88]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #88]
    ldr     r4, =CMD52_F1_READ_ENUM1
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #92]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #92]
    ldr     r4, =CMD52_F1_READ_ENUM2
    cmp     r0, r4
    bne     .Lready_fail

    ldr     r0, [r1, #96]
    cmp     r0, r3
    bne     .Lready_fail
    ldr     r0, [r2, #96]
    ldr     r4, =CMD52_F1_READ_ENUM3
    cmp     r0, r4
    bne     .Lready_fail

    mov     r0, #0
    pop     {pc}

.Lready_fail:
    mov     r0, #1
    pop     {pc}

test_cyw43438_sdio_not_ready_fails:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =1002
    ldr     r1, =ready_after
    str     r0, [r1]
    ldr     r0, =probe_out
    bl      emmc_sdio_wifi_enable_core
    cmp     r0, #1
    bne     .Lnot_ready_fail
    ldr     r1, =cmd5_count
    ldr     r0, [r1]
    ldr     r2, =1001
    cmp     r0, r2
    bne     .Lnot_ready_fail
    mov     r0, #0
    pop     {pc}

.Lnot_ready_fail:
    mov     r0, #1
    pop     {pc}

test_cyw43438_io_not_ready_fails:
    push    {lr}
    bl      reset_emulator
    mov     r0, #2
    ldr     r1, =ready_after
    str     r0, [r1]
    ldr     r0, =1001
    ldr     r1, =io_ready_after
    str     r0, [r1]
    ldr     r0, =probe_out
    bl      emmc_sdio_wifi_enable_core
    cmp     r0, #1
    bne     .Lio_not_ready_fail
    ldr     r1, =cmd52_ready_count
    ldr     r0, [r1]
    ldr     r2, =1000
    cmp     r0, r2
    bne     .Lio_not_ready_fail
    mov     r0, #0
    pop     {pc}

.Lio_not_ready_fail:
    mov     r0, #1
    pop     {pc}

test_cyw43438_backplane_write32:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =CYW43438_TEST_WRITE_ADDR
    ldr     r1, =CYW43438_TEST_WRITE_VALUE
    bl      emmc_sdio_func1_write32
    cmp     r0, #0
    movne   r0, #21
    popne   {pc}

    ldr     r0, =write32_trace_args
    mov     r1, #7
    mov     r2, #22
    bl      check_trace_args
    pop     {pc}

test_cyw43438_backplane_update32:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =CYW43438_ENUM_BASE
    ldr     r1, =CYW43438_TEST_CLEAR_MASK
    ldr     r2, =CYW43438_TEST_SET_MASK
    bl      emmc_sdio_func1_update32
    cmp     r0, #0
    movne   r0, #24
    popne   {pc}
    ldr     r3, =CYW43438_TEST_UPDATE_VALUE
    cmp     r1, r3
    movne   r0, #25
    popne   {pc}
    ldr     r0, =update32_trace_args
    mov     r1, #14
    mov     r2, #26
    bl      check_trace_args
    pop     {pc}

test_cyw43438_func2_write_word:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =CMD53_F2_WRITE_ADDR
    ldr     r1, =CMD53_F2_WRITE_VALUE
    bl      emmc_sdio_func2_write_word
    cmp     r0, #0
    movne   r0, #27
    popne   {pc}
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    cmp     r0, #1
    movne   r0, #28
    popne   {pc}
    ldr     r2, =cmd53_arg
    ldr     r0, [r2]
    ldr     r1, =CMD53_F2_WRITE_ARG
    cmp     r0, r1
    movne   r0, #29
    popne   {pc}
    ldr     r2, =cmd53_word
    ldr     r0, [r2]
    ldr     r1, =CMD53_F2_WRITE_VALUE
    cmp     r0, r1
    movne   r0, #30
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_cyw43438_func2_write_words:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =CMD53_F2_WRITE_MANY_ADDR
    ldr     r1, =cmd53_many_source
    mov     r2, #CMD53_F2_WRITE_MANY_WORDS
    bl      emmc_sdio_func2_write_words
    cmp     r0, #0
    movne   r0, #33
    popne   {pc}
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    cmp     r0, #1
    movne   r0, #34
    popne   {pc}
    ldr     r2, =cmd53_arg
    ldr     r0, [r2]
    ldr     r1, =CMD53_F2_WRITE_MANY_ARG
    cmp     r0, r1
    movne   r0, #35
    popne   {pc}
    ldr     r2, =cmd53_word_count
    ldr     r0, [r2]
    cmp     r0, #CMD53_F2_WRITE_MANY_WORDS
    movne   r0, #36
    popne   {pc}
    ldr     r0, =cmd53_words
    ldr     r1, =cmd53_many_source
    mov     r2, #CMD53_F2_WRITE_MANY_WORDS
    bl      check_words
    cmp     r0, #0
    movne   r0, #37
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_cyw43438_func2_write_backplane_words:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =CMD53_F2_BACKPLANE_ADDR
    ldr     r1, =cmd53_many_source
    mov     r2, #CMD53_F2_WRITE_MANY_WORDS
    bl      emmc_sdio_func2_write_backplane_words
    cmp     r0, #0
    movne   r0, #40
    popne   {pc}
    ldr     r0, =window_trace_args
    mov     r1, #3
    mov     r2, #41
    bl      check_trace_args
    cmp     r0, #0
    popne   {pc}
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    cmp     r0, #1
    movne   r0, #42
    popne   {pc}
    ldr     r2, =cmd53_arg
    ldr     r0, [r2]
    ldr     r1, =CMD53_F2_BACKPLANE_ARG
    cmp     r0, r1
    movne   r0, #43
    popne   {pc}
    ldr     r0, =cmd53_words
    ldr     r1, =cmd53_many_source
    mov     r2, #CMD53_F2_WRITE_MANY_WORDS
    bl      check_words
    cmp     r0, #0
    movne   r0, #44
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_cyw43438_func2_rejects_bad_addr:
    push    {lr}
    bl      reset_emulator
    ldr     r0, =CMD53_F2_BAD_ADDR
    ldr     r1, =CMD53_F2_WRITE_VALUE
    bl      emmc_sdio_func2_write_word
    cmp     r0, #1
    movne   r0, #31
    popne   {pc}
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    cmp     r0, #0
    movne   r0, #32
    popne   {pc}
    bl      reset_emulator
    ldr     r0, =CMD53_F2_OVERFLOW_ADDR
    ldr     r1, =cmd53_many_source
    mov     r2, #1
    bl      emmc_sdio_func2_write_words
    cmp     r0, #1
    movne   r0, #38
    popne   {pc}
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    cmp     r0, #0
    movne   r0, #39
    popne   {pc}
    bl      reset_emulator
    ldr     r0, =CMD53_F2_BACKPLANE_OVERFLOW_ADDR
    ldr     r1, =cmd53_many_source
    mov     r2, #2
    bl      emmc_sdio_func2_write_backplane_words
    cmp     r0, #1
    movne   r0, #45
    popne   {pc}
    ldr     r2, =trace_index
    ldr     r0, [r2]
    cmp     r0, #0
    movne   r0, #46
    popne   {pc}
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    cmp     r0, #0
    movne   r0, #47
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_words:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
1:
    ldr     r0, [r4], #4
    ldr     r1, [r5], #4
    cmp     r0, r1
    bne     .Lcheck_words_fail
    subs    r6, r6, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, pc}

.Lcheck_words_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

check_trace_args:
    push    {r4, r5, r6, r7, r8, lr}
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    ldr     r7, =trace_index
    ldr     r0, [r7]
    cmp     r0, r5
    bne     .Ltrace_args_fail
    ldr     r7, =trace_cmd
    ldr     r8, =trace_arg
    ldr     r3, =CMD52_VAL
1:
    ldr     r0, [r7], #4
    cmp     r0, r3
    bne     .Ltrace_args_fail
    ldr     r0, [r8], #4
    ldr     r1, [r4], #4
    cmp     r0, r1
    bne     .Ltrace_args_fail
    subs    r5, r5, #1
    bne     1b
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, pc}

.Ltrace_args_fail:
    mov     r0, r6
    pop     {r4, r5, r6, r7, r8, pc}

reset_emulator:
    push    {r4, lr}
    mov     r0, #0
    ldr     r1, =trace_index
    str     r0, [r1]
    ldr     r1, =cmd5_count
    str     r0, [r1]
    ldr     r1, =cmd52_ready_count
    str     r0, [r1]
    ldr     r1, =io_enable
    str     r0, [r1]
    ldr     r1, =bus_if
    str     r0, [r1]
    ldr     r1, =f1_block
    str     r0, [r1]
    ldr     r1, =f2_block
    str     r0, [r1]
    ldr     r1, =chipclkcsr
    str     r0, [r1]
    ldr     r1, =clk_ready_after
    str     r0, [r1]
    ldr     r1, =clk_read_count
    str     r0, [r1]
    ldr     r1, =cmd53_arg
    str     r0, [r1]
    ldr     r1, =cmd53_word
    str     r0, [r1]
    ldr     r1, =cmd53_word_count
    str     r0, [r1]
    ldr     r1, =cmd53_count
    str     r0, [r1]
    ldr     r1, =probe_out
    str     r0, [r1]
    str     r0, [r1, #4]
    str     r0, [r1, #8]
    str     r0, [r1, #12]
    str     r0, [r1, #16]
    str     r0, [r1, #20]
    str     r0, [r1, #24]
    mov     r0, #1
    ldr     r1, =io_ready_after
    str     r0, [r1]
    ldr     r1, =clk_ready_after
    str     r0, [r1]
    mov     r0, #0
    ldr     r1, =trace_cmd
    ldr     r2, =trace_arg
    mov     r3, #TRACE_LIMIT
1:
    str     r0, [r1], #4
    str     r0, [r2], #4
    subs    r3, r3, #1
    bne     1b
    pop     {r4, pc}

.globl emmc_sdio_write_words_cmd53
emmc_sdio_write_words_cmd53:
    push    {r4, r5, r6, lr}
    mov     r4, r1
    mov     r5, r2
    ldr     r2, =cmd53_arg
    str     r0, [r2]
    ldr     r2, =cmd53_word_count
    str     r5, [r2]
    ldr     r2, =cmd53_words
    mov     r6, r5
1:
    ldr     r0, [r4], #4
    str     r0, [r2], #4
    subs    r6, r6, #1
    bne     1b
    ldr     r2, =cmd53_word
    ldr     r0, =cmd53_words
    ldr     r0, [r0]
    str     r0, [r2]
    ldr     r2, =cmd53_count
    ldr     r0, [r2]
    add     r0, r0, #1
    str     r0, [r2]
    mov     r0, #0
    pop     {r4, r5, r6, pc}

.globl emmc_sdio_cmd
emmc_sdio_cmd:
    push    {r4, r5, lr}
    mov     r4, r0
    mov     r5, r1

    ldr     r2, =trace_index
    ldr     r3, [r2]
    cmp     r3, #TRACE_LIMIT
    bhs     .Ltrace_done
    ldr     r0, =trace_arg
    str     r4, [r0, r3, lsl #2]
    ldr     r0, =trace_cmd
    str     r5, [r0, r3, lsl #2]
    add     r3, r3, #1
    str     r3, [r2]
.Ltrace_done:
    ldr     r0, =CMD5_VAL
    cmp     r5, r0
    beq     .Lcmd5
    ldr     r0, =CMD3_VAL
    cmp     r5, r0
    beq     .Lcmd3
    ldr     r0, =CMD52_VAL
    cmp     r5, r0
    beq     .Lcmd52
    mov     r0, #0
    mov     r1, #0
    pop     {r4, r5, pc}

.Lcmd5:
    ldr     r2, =cmd5_count
    ldr     r0, [r2]
    add     r0, r0, #1
    str     r0, [r2]
    ldr     r2, =ready_after
    ldr     r2, [r2]
    cmp     r0, r2
    blo     .Lcmd5_not_ready
    mov     r0, #0
    ldr     r1, =CYW43438_OCR
    pop     {r4, r5, pc}
.Lcmd5_not_ready:
    mov     r0, #0
    ldr     r1, =CMD5_VOLTAGE
    pop     {r4, r5, pc}

.Lcmd3:
    mov     r0, #0
    ldr     r1, =CYW43438_RCA
    pop     {r4, r5, pc}

.Lcmd52:
    ldr     r0, =CMD52_WRITE_IO_ENABLE
    cmp     r4, r0
    beq     .Lcmd52_write_io_enable
    ldr     r0, =CMD52_WRITE_BUS_IF
    cmp     r4, r0
    beq     .Lcmd52_write_bus_if
    ldr     r0, =CMD52_WRITE_F1_BLK_LO
    cmp     r4, r0
    beq     .Lcmd52_write_f1_blk_lo
    ldr     r0, =CMD52_WRITE_F1_BLK_HI
    cmp     r4, r0
    beq     .Lcmd52_write_f1_blk_hi
    ldr     r0, =CMD52_WRITE_F2_BLK_LO
    cmp     r4, r0
    beq     .Lcmd52_write_f2_blk_lo
    ldr     r0, =CMD52_WRITE_F2_BLK_HI
    cmp     r4, r0
    beq     .Lcmd52_write_f2_blk_hi
    ldr     r0, =CMD52_F1_WRITE_ALP_REQ
    cmp     r4, r0
    beq     .Lcmd52_write_alp_req
    ldr     r0, =CMD52_F1_READ_CHIPCLKCSR
    cmp     r4, r0
    beq     .Lcmd52_read_chipclkcsr
    ldr     r0, =CMD52_F1_WRITE_FORCE_ALP
    cmp     r4, r0
    beq     .Lcmd52_write_force_alp
    ldr     r0, =CMD52_F1_WRITE_PULLUP_OFF
    cmp     r4, r0
    beq     .Lcmd52_write_pullup_off
    ldr     r0, =CMD52_F1_WRITE_SBADDRLOW
    cmp     r4, r0
    beq     .Lcmd52_write_sbaddrlow
    ldr     r0, =CMD52_F1_WRITE_SBADDRMID
    cmp     r4, r0
    beq     .Lcmd52_write_sbaddrmid
    ldr     r0, =CMD52_F1_WRITE_SBADDRHIGH
    cmp     r4, r0
    beq     .Lcmd52_write_sbaddrhigh
    ldr     r0, =CMD52_F1_READ_ENUM0
    cmp     r4, r0
    beq     .Lcmd52_read_enum0
    ldr     r0, =CMD52_F1_READ_ENUM1
    cmp     r4, r0
    beq     .Lcmd52_read_enum1
    ldr     r0, =CMD52_F1_READ_ENUM2
    cmp     r4, r0
    beq     .Lcmd52_read_enum2
    ldr     r0, =CMD52_F1_READ_ENUM3
    cmp     r4, r0
    beq     .Lcmd52_read_enum3
    ldr     r0, =CMD52_F1_WRITE_TEST0
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_TEST1
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_TEST2
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_TEST3
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_UPDATE0
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_UPDATE1
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_UPDATE2
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    ldr     r0, =CMD52_F1_WRITE_UPDATE3
    cmp     r4, r0
    beq     .Lcmd52_write_test_byte
    cmp     r4, #CMD52_READ_IO_READY
    beq     .Lcmd52_read_io_ready
    cmp     r4, #CMD52_READ_CCCR
    bne     .Lcmd52_error
    mov     r0, #0
    mov     r1, #CYW43438_CCCR
    pop     {r4, r5, pc}

.Lcmd52_write_io_enable:
    ldr     r0, =io_enable
    mov     r1, #SDIO_FUNCS_MASK
    str     r1, [r0]
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_bus_if:
    ldr     r0, =bus_if
    mov     r1, #SDIO_BUS_WIDTH_4BIT
    str     r1, [r0]
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_f1_blk_lo:
    ldr     r0, =f1_block
    mov     r1, #CYW43438_BLOCK_BYTES
    str     r1, [r0]
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_f1_blk_hi:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_f2_blk_lo:
    ldr     r0, =f2_block
    mov     r1, #CYW43438_BLOCK_BYTES
    str     r1, [r0]
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_f2_blk_hi:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_alp_req:
    ldr     r0, =chipclkcsr
    mov     r1, #SBSDIO_ALP_REQ_VALUE
    str     r1, [r0]
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_read_chipclkcsr:
    ldr     r2, =clk_read_count
    ldr     r0, [r2]
    add     r0, r0, #1
    str     r0, [r2]
    ldr     r2, =clk_ready_after
    ldr     r2, [r2]
    ldr     r1, =chipclkcsr
    ldr     r1, [r1]
    cmp     r0, r2
    orrhs   r1, r1, #SBSDIO_ALP_AVAIL
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_force_alp:
    ldr     r0, =chipclkcsr
    mov     r1, #SBSDIO_FORCE_ALP_VALUE
    str     r1, [r0]
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_pullup_off:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_sbaddrlow:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_sbaddrmid:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_write_sbaddrhigh:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_read_enum0:
    mov     r0, #0
    ldr     r1, =CYW43438_SIGNATURE
    and     r1, r1, #0xff
    pop     {r4, r5, pc}

.Lcmd52_read_enum1:
    mov     r0, #0
    ldr     r1, =CYW43438_SIGNATURE
    lsr     r1, r1, #8
    and     r1, r1, #0xff
    pop     {r4, r5, pc}

.Lcmd52_read_enum2:
    mov     r0, #0
    ldr     r1, =CYW43438_SIGNATURE
    lsr     r1, r1, #16
    and     r1, r1, #0xff
    pop     {r4, r5, pc}

.Lcmd52_read_enum3:
    mov     r0, #0
    ldr     r1, =CYW43438_SIGNATURE
    lsr     r1, r1, #24
    and     r1, r1, #0xff
    pop     {r4, r5, pc}

.Lcmd52_write_test_byte:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lcmd52_read_io_ready:
    ldr     r2, =cmd52_ready_count
    ldr     r0, [r2]
    add     r0, r0, #1
    str     r0, [r2]
    ldr     r2, =io_ready_after
    ldr     r2, [r2]
    cmp     r0, r2
    blo     .Lcmd52_io_not_ready
    mov     r0, #0
    ldr     r1, =io_enable
    ldr     r1, [r1]
    pop     {r4, r5, pc}
.Lcmd52_io_not_ready:
    mov     r0, #0
    mov     r1, #0
    pop     {r4, r5, pc}

.Lcmd52_error:
    mov     r0, #1
    mov     r1, #0
    pop     {r4, r5, pc}

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
cmd53_many_source:
    .word   0x03020100
    .word   0x07060504
    .word   0x0b0a0908
window_trace_args:
    .word   CMD52_F1_WRITE_SBADDRLOW
    .word   CMD52_F1_WRITE_SBADDRMID
    .word   CMD52_F1_WRITE_SBADDRHIGH
write32_trace_args:
    .word   CMD52_F1_WRITE_SBADDRLOW
    .word   CMD52_F1_WRITE_SBADDRMID
    .word   CMD52_F1_WRITE_SBADDRHIGH
    .word   CMD52_F1_WRITE_TEST0
    .word   CMD52_F1_WRITE_TEST1
    .word   CMD52_F1_WRITE_TEST2
    .word   CMD52_F1_WRITE_TEST3
update32_trace_args:
    .word   CMD52_F1_WRITE_SBADDRLOW
    .word   CMD52_F1_WRITE_SBADDRMID
    .word   CMD52_F1_WRITE_SBADDRHIGH
    .word   CMD52_F1_READ_ENUM0
    .word   CMD52_F1_READ_ENUM1
    .word   CMD52_F1_READ_ENUM2
    .word   CMD52_F1_READ_ENUM3
    .word   CMD52_F1_WRITE_SBADDRLOW
    .word   CMD52_F1_WRITE_SBADDRMID
    .word   CMD52_F1_WRITE_SBADDRHIGH
    .word   CMD52_F1_WRITE_UPDATE0
    .word   CMD52_F1_WRITE_UPDATE1
    .word   CMD52_F1_WRITE_UPDATE2
    .word   CMD52_F1_WRITE_UPDATE3

.section .bss
.align 4
trace_cmd:
    .space  100
trace_arg:
    .space  100
probe_out:
    .space  28
trace_index:
    .space  4
ready_after:
    .space  4
io_ready_after:
    .space  4
cmd5_count:
    .space  4
cmd52_ready_count:
    .space  4
io_enable:
    .space  4
bus_if:
    .space  4
f1_block:
    .space  4
f2_block:
    .space  4
chipclkcsr:
    .space  4
clk_ready_after:
    .space  4
clk_read_count:
    .space  4
cmd53_arg:
    .space  4
cmd53_word:
    .space  4
cmd53_word_count:
    .space  4
cmd53_count:
    .space  4
cmd53_words:
    .space  512
stack_bottom:
    .space  4096
stack_top:
