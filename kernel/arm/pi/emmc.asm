@ Pi EMMC/SD card driver — ARM1176JZF-S (BCM2835)
@
@ Implements SDHC-compatible card initialization and single-block
@ read/write via the BCM2835 EMMC controller at 0x20300000.
@
@ Public API:
@   emmc_init()          r0 = 0 on success
@   emmc_read_block(lba, buf)   r0 = 0 on success
@   emmc_write_block(lba, buf)  r0 = 0 on success

@ ---- Register offsets (from EMMC_BASE = 0x20300000) ----
.equ EMMC_BASE,             0x20300000
.equ EMMC_ARG2,             0x00
.equ EMMC_BLKSIZECNT,       0x04
.equ EMMC_ARG1,             0x08
.equ EMMC_CMDTM,            0x0c
.equ EMMC_RESP0,            0x10
.equ EMMC_RESP1,            0x14
.equ EMMC_RESP2,            0x18
.equ EMMC_RESP3,            0x1c
.equ EMMC_DATA,             0x20
.equ EMMC_CONTROL0,         0x28
.equ EMMC_CONTROL1,         0x2c
.equ EMMC_INTERRUPT,        0x30
.equ EMMC_IRPT_MASK,        0x34
.equ EMMC_IRPT_EN,          0x38
.equ EMMC_CONTROL2,         0x3c
.equ EMMC_CAPABILITIES_0,   0x40
.equ EMMC_CAPABILITIES_1,   0x44
.equ EMMC_SLOTISR_VER,      0xfc

@ ---- CONTROL0 bits ----
.equ CTL0_GAP_STOP,         (1 << 4)
.equ CTL0_ALT_BOOT_EN,      (1 << 6)
.equ CTL0_BOOT_EN,          (1 << 7)

@ ---- CONTROL1 bits ----
.equ CTL1_CLK_EN,           (1 << 0)
.equ CTL1_CLK_STABLE,       (1 << 1)
.equ CTL1_CLK_INT_EN,       (1 << 2)
.equ CTL1_DATA_TOUT_SHIFT,  8
.equ CTL1_DATA_TOUT_MASK,   (0xf << 8)
.equ CTL1_DATA_TOUT_MAX,    (0xe << 8)      @ 2^27 cycles
.equ CTL1_SRST_HC,          (1 << 24)
.equ CTL1_SRST_CMD,         (1 << 25)
.equ CTL1_SRST_DATA,        (1 << 26)

@ ---- CMDTM bit fields ----
.equ CMDTM_RESP_SHIFT,      16
.equ CMDTM_RESP_NONE,       (0 << 16)
.equ CMDTM_RESP_136,        (1 << 16)
.equ CMDTM_RESP_48,         (2 << 16)
.equ CMDTM_RESP_48_BUSY,    (3 << 16)
.equ CMDTM_CRC_CHK_EN,      (1 << 19)
.equ CMDTM_IDX_CHK_EN,      (1 << 20)
.equ CMDTM_IS_DATA,         (1 << 21)
.equ CMDTM_BLKCNT_EN,       (1 << 1)
.equ CMDTM_DIR_READ,        (1 << 4)
.equ CMDTM_DIR_WRITE,       0
.equ CMDTM_CMD_SHIFT,       24

@ ---- CMDTM presets (cmd index << 24 | resp << 16 | flags) ----
@ CMD0 — GO_IDLE_STATE, no response
.equ CMD0_VAL,              (0 << 24) | CMDTM_RESP_NONE
@ CMD2 — ALL_SEND_CID, 136-bit response
.equ CMD2_VAL,              (2 << 24) | CMDTM_RESP_136
@ CMD3 — SEND_RELATIVE_ADDR, 48-bit response with CRC
.equ CMD3_VAL,              (3 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD7 — SELECT_CARD, 48-bit response with busy
.equ CMD7_VAL,              (7 << 24) | CMDTM_RESP_48_BUSY | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD8 — SEND_IF_COND, 48-bit response
.equ CMD8_VAL,              (8 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD17 — READ_SINGLE_BLOCK, 48-bit response, data read
.equ CMD17_VAL,             (17 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN | CMDTM_IS_DATA | CMDTM_DIR_READ
@ CMD24 — WRITE_BLOCK, 48-bit response, data write
.equ CMD24_VAL,             (24 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN | CMDTM_IS_DATA | CMDTM_DIR_WRITE
@ CMD55 — APP_CMD, 48-bit response
.equ CMD55_VAL,             (55 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ ACMD41 — SD_SEND_OP_COND, 48-bit response (no CRC)
.equ ACMD41_VAL,            (41 << 24) | CMDTM_RESP_48

@ ---- Interrupt bits ----
.equ INT_CMD_DONE,          (1 << 0)
.equ INT_DATA_DONE,         (1 << 1)
.equ INT_WRITE_READY,       (1 << 4)
.equ INT_READ_READY,        (1 << 5)
.equ INT_CARD_INT,          (1 << 8)
.equ INT_ERROR,             (1 << 15)
.equ INT_ALL_ERRORS,        0xffff0000

@ ---- SD card commands ----
.equ SD_GO_IDLE_STATE,      0
.equ SD_ALL_SEND_CID,       2
.equ SD_SEND_RELATIVE_ADDR,  3
.equ SD_SELECT_CARD,        7
.equ SD_SEND_IF_COND,       8
.equ SD_READ_SINGLE_BLOCK,  17
.equ SD_WRITE_BLOCK,        24
.equ SD_APP_CMD,            55
.equ SD_ACMD_SD_SEND_OP_COND, 41

@ ---- Card status / OCR ----
.equ OCR_CCS_BIT,           30
.equ OCR_3_3V,              (1 << 21)
.equ OCR_BUSY,              (1 << 31)

@ ---- CMD8 check pattern ----
.equ IF_COND_VHS_3V3,       (1 << 8)
.equ IF_COND_CHECK_PATTERN, 0xAA

@ ---- Internal scratch offset (within EMMC register space) ----
.equ EMMC_SCRATCH,          0x100

@ ---- Functions ----

.globl emmc_init
.globl emmc_read_block
.globl emmc_write_block


@ ---- emmc_init ----
emmc_init:
    push    {r4, r5, r6, lr}
    ldr     r4, =EMMC_BASE

    @ 1. Reset controller
    ldr     r0, [r4, #EMMC_CONTROL1]
    orr     r0, r0, #CTL1_SRST_HC
    str     r0, [r4, #EMMC_CONTROL1]
    mov     r5, #0x1000000
1:  ldr     r0, [r4, #EMMC_CONTROL1]
    tst     r0, #CTL1_SRST_HC
    beq     2f
    subs    r5, r5, #1
    bne     1b
    mov     r0, #1
    pop     {r4, r5, r6, pc}
2:
    @ 2. Set data timeout
    ldr     r0, [r4, #EMMC_CONTROL1]
    bic     r0, r0, #CTL1_DATA_TOUT_MASK
    orr     r0, r0, #CTL1_DATA_TOUT_MAX
    str     r0, [r4, #EMMC_CONTROL1]

    @ 3. Enable all interrupts
    mvn     r0, #0
    str     r0, [r4, #EMMC_IRPT_EN]
    str     r0, [r4, #EMMC_IRPT_MASK]

    @ 4. Set init clock (~400kHz, divider ~311)
    ldr     r0, [r4, #EMMC_CONTROL1]
    bic     r0, r0, #0xff00
    mov     r1, #61
    orr     r0, r0, r1, lsl #8
    orr     r0, r0, #CTL1_CLK_EN
    str     r0, [r4, #EMMC_CONTROL1]
    mov     r5, #0x1000000
1:  ldr     r0, [r4, #EMMC_CONTROL1]
    tst     r0, #CTL1_CLK_STABLE
    bne     2f
    subs    r5, r5, #1
    bne     1b
    mov     r0, #1
    pop     {r4, r5, r6, pc}
2:
    @ 5. CMD0 — GO_IDLE_STATE
    mov     r0, #0
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =CMD0_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail

    @ 6. CMD8 — SEND_IF_COND
    ldr     r0, =(IF_COND_VHS_3V3 | IF_COND_CHECK_PATTERN)
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =CMD8_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail
    ldr     r0, [r4, #EMMC_RESP0]
    mov     r1, #0xff0
    add     r1, r1, #0xf
    and     r0, r0, r1
    ldr     r1, =(IF_COND_VHS_3V3 | IF_COND_CHECK_PATTERN)
    teq     r0, r1
    bne     .Lfail

    @ 7. Loop CMD55 + ACMD41
    mov     r5, #1000
1:  mov     r0, #0
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =CMD55_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail
    ldr     r0, =0x50ff8000
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =ACMD41_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail
    ldr     r0, [r4, #EMMC_RESP0]
    tst     r0, #OCR_BUSY
    bne     2f
    subs    r5, r5, #1
    bne     1b
    b       .Lfail
2:
    @ 8. Store SDHC flag (CCS bit)
    mov     r6, r0
    lsr     r6, r6, #OCR_CCS_BIT
    and     r6, r6, #1

    @ 9. CMD2 — ALL_SEND_CID
    mov     r0, #0
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =CMD2_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail

    @ 10. CMD3 — SEND_RELATIVE_ADDR
    mov     r0, #0
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =CMD3_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail
    ldr     r5, [r4, #EMMC_RESP0]
    lsr     r5, r5, #16
    lsl     r5, r5, #16

    @ 11. CMD7 — SELECT_CARD
    str     r5, [r4, #EMMC_ARG1]
    ldr     r0, =CMD7_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lfail

    @ 12. Set high-speed clock (~25MHz, divider ~5)
    ldr     r0, [r4, #EMMC_CONTROL1]
    bic     r0, r0, #0xff00
    mov     r1, #4
    orr     r0, r0, r1, lsl #8
    str     r0, [r4, #EMMC_CONTROL1]
    mov     r5, #0x1000000
1:  ldr     r0, [r4, #EMMC_CONTROL1]
    tst     r0, #CTL1_CLK_STABLE
    bne     2f
    subs    r5, r5, #1
    bne     1b
    mov     r0, #1
    pop     {r4, r5, r6, pc}
2:
    @ 13. Set 4-bit bus width (CONTROL0 bit 1)
    ldr     r0, [r4, #EMMC_CONTROL0]
    orr     r0, r0, #0x2
    str     r0, [r4, #EMMC_CONTROL0]

    @ Store capacity flag in scratch
    str     r6, [r4, #EMMC_SCRATCH]
    mov     r0, #0
    pop     {r4, r5, r6, pc}

.Lfail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

@ Wait for CMD_DONE interrupt, return 0 on success, 1 on error/timeout
emmc_wait_cmd_done:
    ldr     r1, =EMMC_BASE
    mov     r2, #0x1000000
1:  ldr     r0, [r1, #EMMC_INTERRUPT]
    tst     r0, #INT_CMD_DONE
    bne     2f
    tst     r0, #INT_ERROR
    bne     3f
    subs    r2, r2, #1
    bne     1b
3:  @ Error or timeout
    mvn     r0, #0
    str     r0, [r1, #EMMC_INTERRUPT]
    mov     r0, #1
    bx      lr
2:  @ Success
    str     r0, [r1, #EMMC_INTERRUPT]
    mov     r0, #0
    bx      lr

@ Wait for DATA_DONE interrupt or data_ready bit, return 0 on success
emmc_wait_data_done:
    ldr     r1, =EMMC_BASE
    mov     r2, #0x1000000
1:  ldr     r0, [r1, #EMMC_INTERRUPT]
    tst     r0, #INT_DATA_DONE
    bne     2f
    tst     r0, #INT_ERROR
    bne     3f
    subs    r2, r2, #1
    bne     1b
3:  mvn     r0, #0
    str     r0, [r1, #EMMC_INTERRUPT]
    mov     r0, #1
    bx      lr
2:  str     r0, [r1, #EMMC_INTERRUPT]
    mov     r0, #0
    bx      lr

@ ---- emmc_read_block ----
@ r0 = LBA (sector number)
@ r1 = destination buffer (must be 4-byte aligned)
@ Returns r0 = 0 on success
emmc_read_block:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    mov     r5, r1
    ldr     r6, =EMMC_BASE

    @ Compute byte address or LBA based on capacity flag
    ldr     r0, [r6, #EMMC_SCRATCH]
    cmp     r0, #0
    bne     1f
    @ SDSC: multiply LBA by 512
    mov     r0, r4, lsl #9
    b       2f
1:  @ SDHC: use LBA directly
    mov     r0, r4
2:  str     r0, [r6, #EMMC_ARG1]

    @ BLKSIZECNT = (512 << 16) | 1
    mov     r0, #512
    orr     r0, r0, #1
    str     r0, [r6, #EMMC_BLKSIZECNT]

    @ Send CMD17
    ldr     r0, =CMD17_VAL
    str     r0, [r6, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lread_fail

    @ Wait for READ_READY
    mov     r2, #0x1000000
1:  ldr     r0, [r6, #EMMC_INTERRUPT]
    tst     r0, #INT_READ_READY
    bne     2f
    tst     r0, #INT_ERROR
    bne     .Lread_fail
    subs    r2, r2, #1
    bne     1b
    b       .Lread_fail
2:  str     r0, [r6, #EMMC_INTERRUPT]

    @ Read 128 words from DATA FIFO
    mov     r3, #128
1:  ldr     r0, [r6, #EMMC_DATA]
    str     r0, [r5], #4
    subs    r3, r3, #1
    bne     1b

    @ Wait for DATA_DONE
    bl      emmc_wait_data_done
    cmp     r0, #0
    bne     .Lread_fail

    mov     r0, #0
    pop     {r4, r5, r6, pc}
.Lread_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

@ ---- emmc_write_block ----
@ r0 = LBA
@ r1 = source buffer
@ Returns r0 = 0 on success
emmc_write_block:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    mov     r5, r1
    ldr     r6, =EMMC_BASE

    ldr     r0, [r6, #EMMC_SCRATCH]
    cmp     r0, #0
    bne     1f
    mov     r0, r4, lsl #9
    b       2f
1:  mov     r0, r4
2:  str     r0, [r6, #EMMC_ARG1]

    mov     r0, #512
    orr     r0, r0, #1
    str     r0, [r6, #EMMC_BLKSIZECNT]

    ldr     r0, =CMD24_VAL
    str     r0, [r6, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lwrite_fail

    @ Wait for WRITE_READY
    mov     r2, #0x1000000
1:  ldr     r0, [r6, #EMMC_INTERRUPT]
    tst     r0, #INT_WRITE_READY
    bne     2f
    tst     r0, #INT_ERROR
    bne     .Lwrite_fail
    subs    r2, r2, #1
    bne     1b
    b       .Lwrite_fail
2:  str     r0, [r6, #EMMC_INTERRUPT]

    @ Write 128 words to DATA FIFO
    mov     r3, #128
1:  ldr     r0, [r5], #4
    str     r0, [r6, #EMMC_DATA]
    subs    r3, r3, #1
    bne     1b

    bl      emmc_wait_data_done
    cmp     r0, #0
    bne     .Lwrite_fail

    mov     r0, #0
    pop     {r4, r5, r6, pc}
.Lwrite_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}
