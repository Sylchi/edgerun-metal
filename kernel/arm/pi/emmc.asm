@ Pi EMMC/SD card driver — ARM1176JZF-S (BCM2835)
@
@ Implements SDHC-compatible card initialization and single-block
@ read/write via the BCM2835 EMMC controller at 0x20300000.
@
@ Public API:
@   emmc_init()          r0 = 0 on success
@   emmc_read_block(lba, buf)   r0 = 0 on success
@   emmc_write_block(lba, buf)  r0 = 0 on success
@   emmc_sdio_probe(out)      r0 = 0 on success, out[0] = OCR, out[1] = CCCR rev
@   emmc_sdio_wifi_enable(out) r0 = 0 on success, out[2] = IO_READY byte
@   emmc_sdio_probe_core(out) same probe sequence through emmc_sdio_cmd
@   emmc_sdio_wifi_enable_core(out) probes and enables SDIO functions 1 and 2

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
@ CMD5 — IO_SEND_OP_COND, 48-bit R4 response (no CRC)
.equ CMD5_VAL,              (5 << 24) | CMDTM_RESP_48
@ CMD2 — ALL_SEND_CID, 136-bit response
.equ CMD2_VAL,              (2 << 24) | CMDTM_RESP_136
@ CMD3 — SEND_RELATIVE_ADDR, 48-bit response with CRC
.equ CMD3_VAL,              (3 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD7 — SELECT_CARD, 48-bit response with busy
.equ CMD7_VAL,              (7 << 24) | CMDTM_RESP_48_BUSY | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD8 — SEND_IF_COND, 48-bit response
.equ CMD8_VAL,              (8 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD17 — READ_SINGLE_BLOCK, 48-bit response, data read
.equ CMD17_VAL,             (17 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN | CMDTM_IS_DATA | CMDTM_BLKCNT_EN | CMDTM_DIR_READ
@ CMD24 — WRITE_BLOCK, 48-bit response, data write
.equ CMD24_VAL,             (24 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN | CMDTM_IS_DATA | CMDTM_BLKCNT_EN | CMDTM_DIR_WRITE
@ CMD52 — IO_RW_DIRECT, 48-bit R5 response
.equ CMD52_VAL,             (52 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN
@ CMD53 — IO_RW_EXTENDED, 48-bit R5 response, data write
.equ CMD53_WRITE_VAL,       (53 << 24) | CMDTM_RESP_48 | CMDTM_CRC_CHK_EN | CMDTM_IDX_CHK_EN | CMDTM_IS_DATA | CMDTM_DIR_WRITE
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
.equ OCR_CCS_BIT,           30
.equ OCR_IO_BUSY,           (1 << 31)
.equ OCR_3_3V,              (1 << 21)
.equ OCR_BUSY,              (1 << 31)

@ ---- SDIO CCCR fields ----
.equ SDIO_OCR_VOLTAGE_3V3,  0x00ff8000
.equ SDIO_CCCR_REVISION,    0x00
.equ SDIO_CCCR_IO_ENABLE,   0x02
.equ SDIO_CCCR_IO_READY,    0x03
.equ SDIO_CCCR_BUS_IF,      0x07
.equ SDIO_FUNC_BACKPLANE_BIT, (1 << 1)
.equ SDIO_FUNC_WLAN_BIT,    (1 << 2)
.equ SDIO_WIFI_FUNCS_MASK,  (SDIO_FUNC_BACKPLANE_BIT | SDIO_FUNC_WLAN_BIT)
.equ SDIO_BUS_WIDTH_4BIT,   0x02
.equ SDIO_CMD52_WRITE,      (1 << 31)
.equ SDIO_CMD52_ADDR_SHIFT, 9
.equ SDIO_CMD53_WRITE,      (1 << 31)
.equ SDIO_CMD53_OP_INC,     (1 << 26)
.equ SDIO_CMD53_FUNC2,      (2 << 28)
.equ SDIO_CMD53_ADDR_SHIFT, 9
.equ SDIO_CMD53_WORD_BYTES, 4
.equ SDIO_CMD53_MAX_WORDS,  128
.equ SDIO_CMD53_ADDR_MASK,  0x1ffff
.equ SDIO_READY_POLLS,      1000
.equ SDIO_FBR_FUNC1_BLOCK_LOW,  0x110
.equ SDIO_FBR_FUNC1_BLOCK_HIGH, 0x111
.equ SDIO_FBR_FUNC2_BLOCK_LOW,  0x210
.equ SDIO_FBR_FUNC2_BLOCK_HIGH, 0x211
.equ CYW43438_SDIO_BLOCK_BYTES, 64
.equ SBSDIO_FUNC1_CHIPCLKCSR, 0x1000e
.equ SBSDIO_FUNC1_SDIOPULLUP, 0x1000f
.equ SBSDIO_FUNC1_SBADDRLOW,  0x1000a
.equ SBSDIO_FUNC1_SBADDRMID,  0x1000b
.equ SBSDIO_FUNC1_SBADDRHIGH, 0x1000c
.equ SBSDIO_SB_OFT_ADDR_MASK, 0x7fff
.equ CYW43438_ENUM_BASE,      0x18000000
.equ SBSDIO_FORCE_ALP,       0x01
.equ SBSDIO_ALP_AVAIL_REQ,   0x08
.equ SBSDIO_FORCE_HW_CLKREQ_OFF, 0x20
.equ SBSDIO_ALP_AVAIL,       0x40
.equ SBSDIO_AVBITS,          0xc0
.equ SBSDIO_ALP_REQ_VALUE,   (SBSDIO_FORCE_HW_CLKREQ_OFF | SBSDIO_ALP_AVAIL_REQ)
.equ SBSDIO_FORCE_ALP_VALUE, (SBSDIO_FORCE_HW_CLKREQ_OFF | SBSDIO_FORCE_ALP)
.equ SDIO_CLOCK_POLLS,       1000

@ ---- SD block transfer fields ----
.equ SD_BLOCK_BYTES,         512
.equ SD_BLOCK_WORDS,         128
.equ SD_BLOCK_COUNT_ONE,     1
.equ SD_BLKSIZECNT_SINGLE,   SD_BLOCK_BYTES | (SD_BLOCK_COUNT_ONE << 16)

@ ---- CMD8 check pattern ----
.equ IF_COND_VHS_3V3,       (1 << 8)
.equ IF_COND_CHECK_PATTERN, 0xAA

@ ---- Internal scratch offset (within EMMC register space) ----
.equ EMMC_SCRATCH,          0x100

@ ---- Functions ----

.globl emmc_init
.globl emmc_read_block
.globl emmc_write_block
.globl emmc_sdio_probe
.globl emmc_sdio_wifi_enable
.globl emmc_sdio_probe_core
.globl emmc_sdio_wifi_enable_core
.globl emmc_sdio_func1_read32
.globl emmc_sdio_func1_write32
.globl emmc_sdio_func1_update32
.globl emmc_sdio_func2_write_word
.globl emmc_sdio_func2_write_words
.globl emmc_sdio_func2_write_backplane_words
.weak emmc_sdio_cmd
.weak emmc_sdio_write_words_cmd53
.weak emmc_mmio_read
.weak emmc_mmio_write


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

@ ---- emmc_sdio_probe ----
@ r0 = output buffer, two words:
@      [0] = final CMD5 OCR/R4 response
@      [1] = CCCR/SDIO revision byte read with CMD52 address 0
@ Returns r0 = 0 on success
emmc_sdio_probe:
    push    {r4, lr}
    mov     r4, r0
    bl      emmc_sdio_prepare
    cmp     r0, #0
    bne     .Lsdio_probe_fail
    mov     r0, r4
    bl      emmc_sdio_probe_core
    pop     {r4, pc}

.Lsdio_probe_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- emmc_sdio_wifi_enable ----
@ r0 = output buffer, three words
@ Returns r0 = 0 on success.
emmc_sdio_wifi_enable:
    push    {r4, lr}
    mov     r4, r0
    bl      emmc_sdio_prepare
    cmp     r0, #0
    bne     .Lsdio_wifi_fail
    mov     r0, r4
    bl      emmc_sdio_wifi_enable_core
    pop     {r4, pc}

.Lsdio_wifi_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- emmc_sdio_prepare ----
@ Reset controller and keep SDIO at identification speed.
emmc_sdio_prepare:
    push    {r4, r5, lr}
    ldr     r4, =EMMC_BASE

    ldr     r0, [r4, #EMMC_CONTROL1]
    orr     r0, r0, #CTL1_SRST_HC
    str     r0, [r4, #EMMC_CONTROL1]
    mov     r5, #0x1000000
1:  ldr     r0, [r4, #EMMC_CONTROL1]
    tst     r0, #CTL1_SRST_HC
    beq     2f
    subs    r5, r5, #1
    bne     1b
    b       .Lsdio_prepare_fail
2:
    ldr     r0, [r4, #EMMC_CONTROL1]
    bic     r0, r0, #CTL1_DATA_TOUT_MASK
    orr     r0, r0, #CTL1_DATA_TOUT_MAX
    str     r0, [r4, #EMMC_CONTROL1]

    mvn     r0, #0
    str     r0, [r4, #EMMC_IRPT_EN]
    str     r0, [r4, #EMMC_IRPT_MASK]
    str     r0, [r4, #EMMC_INTERRUPT]

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
    b       .Lsdio_prepare_fail
2:
    mov     r0, #0
    pop     {r4, r5, pc}

.Lsdio_prepare_fail:
    mov     r0, #1
    pop     {r4, r5, pc}

@ ---- emmc_sdio_probe_core ----
@ r0 = output buffer, two words
@ Uses emmc_sdio_cmd(arg, cmdtm), which returns r0 = status, r1 = RESP0.
emmc_sdio_probe_core:
    push    {r4, r5, r6, r7, lr}
    mov     r7, r0

    mov     r0, #0
    ldr     r1, =CMD0_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lsdio_core_fail

    @ CMD5 with zero argument discovers SDIO OCR and function count.
    mov     r0, #0
    ldr     r1, =CMD5_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lsdio_core_fail

    @ CMD5 again requests the advertised 3.2-3.4V window until IO is ready.
    mov     r5, #1000
1:  ldr     r0, =SDIO_OCR_VOLTAGE_3V3
    ldr     r1, =CMD5_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lsdio_core_fail
    mov     r6, r1
    tst     r6, #OCR_IO_BUSY
    bne     2f
    subs    r5, r5, #1
    bne     1b
    b       .Lsdio_core_fail
2:
    str     r6, [r7]

    @ CMD3 assigns and returns the SDIO RCA.
    mov     r0, #0
    ldr     r1, =CMD3_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lsdio_core_fail
    mov     r5, r1
    lsr     r5, r5, #16
    lsl     r5, r5, #16

    mov     r0, r5
    ldr     r1, =CMD7_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lsdio_core_fail

    @ CMD52 read, function 0, CCCR address 0x00.
    mov     r0, #0
    ldr     r1, =CMD52_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lsdio_core_fail
    and     r1, r1, #0xff
    str     r1, [r7, #4]

    mov     r0, #0
    pop     {r4, r5, r6, r7, pc}

.Lsdio_core_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, pc}

@ ---- emmc_sdio_wifi_enable_core ----
@ r0 = output buffer, seven words:
@      [0] = final CMD5 OCR/R4 response
@      [1] = CCCR/SDIO revision byte
@      [2] = final IO_READY byte
@      [3] = BUS_INTERFACE byte written
@      [4] = function block size in bytes
@      [5] = final CHIPCLKCSR byte
@      [6] = backplane enum-base signature word
@ Returns r0 = 0 on success.
emmc_sdio_wifi_enable_core:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    bl      emmc_sdio_probe_core
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    @ Enable CYW43438 backplane function 1 and WLAN function 2.
    mov     r0, #SDIO_CCCR_IO_ENABLE
    lsl     r0, r0, #SDIO_CMD52_ADDR_SHIFT
    orr     r0, r0, #SDIO_WIFI_FUNCS_MASK
    ldr     r1, =SDIO_CMD52_WRITE
    orr     r0, r0, r1
    ldr     r1, =CMD52_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    mov     r5, #SDIO_READY_POLLS
1:
    mov     r0, #SDIO_CCCR_IO_READY
    lsl     r0, r0, #SDIO_CMD52_ADDR_SHIFT
    ldr     r1, =CMD52_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lwifi_enable_fail
    and     r6, r1, #0xff
    and     r1, r6, #SDIO_WIFI_FUNCS_MASK
    cmp     r1, #SDIO_WIFI_FUNCS_MASK
    beq     2f
    subs    r5, r5, #1
    bne     1b
    b       .Lwifi_enable_fail
2:
    str     r6, [r4, #8]

    mov     r0, #SDIO_CCCR_BUS_IF
    mov     r1, #SDIO_BUS_WIDTH_4BIT
    bl      emmc_sdio_cmd52_write_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    ldr     r0, =SDIO_FBR_FUNC1_BLOCK_LOW
    mov     r1, #CYW43438_SDIO_BLOCK_BYTES
    bl      emmc_sdio_cmd52_write_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    ldr     r0, =SDIO_FBR_FUNC1_BLOCK_HIGH
    mov     r1, #0
    bl      emmc_sdio_cmd52_write_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    ldr     r0, =SDIO_FBR_FUNC2_BLOCK_LOW
    mov     r1, #CYW43438_SDIO_BLOCK_BYTES
    bl      emmc_sdio_cmd52_write_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    ldr     r0, =SDIO_FBR_FUNC2_BLOCK_HIGH
    mov     r1, #0
    bl      emmc_sdio_cmd52_write_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    mov     r0, #SDIO_BUS_WIDTH_4BIT
    str     r0, [r4, #12]
    mov     r0, #CYW43438_SDIO_BLOCK_BYTES
    str     r0, [r4, #16]

    ldr     r0, =SBSDIO_FUNC1_CHIPCLKCSR
    mov     r1, #SBSDIO_ALP_REQ_VALUE
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    ldr     r0, =SBSDIO_FUNC1_CHIPCLKCSR
    bl      emmc_sdio_cmd52_read_func1_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail
    bic     r2, r1, #SBSDIO_AVBITS
    cmp     r2, #SBSDIO_ALP_REQ_VALUE
    bne     .Lwifi_enable_fail

    mov     r5, #SDIO_CLOCK_POLLS
1:
    ldr     r0, =SBSDIO_FUNC1_CHIPCLKCSR
    bl      emmc_sdio_cmd52_read_func1_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail
    tst     r1, #SBSDIO_ALP_AVAIL
    bne     2f
    subs    r5, r5, #1
    bne     1b
    b       .Lwifi_enable_fail
2:
    and     r6, r1, #0xff

    ldr     r0, =SBSDIO_FUNC1_CHIPCLKCSR
    mov     r1, #SBSDIO_FORCE_ALP_VALUE
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    ldr     r0, =SBSDIO_FUNC1_SDIOPULLUP
    mov     r1, #0
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwifi_enable_fail

    str     r6, [r4, #20]
    ldr     r0, =CYW43438_ENUM_BASE
    bl      emmc_sdio_func1_read32
    cmp     r0, #0
    bne     .Lwifi_enable_fail
    str     r1, [r4, #24]
    mov     r0, #0
    pop     {r4, r5, r6, pc}

.Lwifi_enable_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

@ ---- emmc_sdio_cmd52_write_byte ----
@ r0 = function 0 SDIO address, r1 = byte value
@ Returns r0 = 0 on success.
emmc_sdio_cmd52_write_byte:
    push    {lr}
    lsl     r0, r0, #SDIO_CMD52_ADDR_SHIFT
    and     r1, r1, #0xff
    orr     r0, r0, r1
    ldr     r1, =SDIO_CMD52_WRITE
    orr     r0, r0, r1
    ldr     r1, =CMD52_VAL
    bl      emmc_sdio_cmd
    pop     {pc}

@ ---- emmc_sdio_cmd52_write_func1_byte ----
@ r0 = function 1 SDIO address, r1 = byte value
@ Returns r0 = 0 on success.
emmc_sdio_cmd52_write_func1_byte:
    push    {lr}
    lsl     r0, r0, #SDIO_CMD52_ADDR_SHIFT
    and     r1, r1, #0xff
    orr     r0, r0, r1
    ldr     r1, =(SDIO_CMD52_WRITE | (1 << 28))
    orr     r0, r0, r1
    ldr     r1, =CMD52_VAL
    bl      emmc_sdio_cmd
    pop     {pc}

@ ---- emmc_sdio_cmd52_read_func1_byte ----
@ r0 = function 1 SDIO address
@ Returns r0 = 0 on success, r1 = byte value.
emmc_sdio_cmd52_read_func1_byte:
    push    {lr}
    lsl     r0, r0, #SDIO_CMD52_ADDR_SHIFT
    ldr     r1, =(1 << 28)
    orr     r0, r0, r1
    ldr     r1, =CMD52_VAL
    bl      emmc_sdio_cmd
    cmp     r0, #0
    bne     .Lcmd52_read_func1_done
    and     r1, r1, #0xff
.Lcmd52_read_func1_done:
    pop     {pc}

@ ---- emmc_sdio_func1_set_backplane_window ----
@ r0 = 32-bit backplane address.
@ Returns r0 = 0 on success.
emmc_sdio_func1_set_backplane_window:
    push    {r4, lr}
    mov     r4, r0

    ldr     r0, =SBSDIO_FUNC1_SBADDRLOW
    lsr     r1, r4, #8
    and     r1, r1, #0x80
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lset_window_fail

    ldr     r0, =SBSDIO_FUNC1_SBADDRMID
    lsr     r1, r4, #16
    and     r1, r1, #0xff
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lset_window_fail

    ldr     r0, =SBSDIO_FUNC1_SBADDRHIGH
    lsr     r1, r4, #24
    and     r1, r1, #0xff
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lset_window_fail

    mov     r0, #0
    pop     {r4, pc}

.Lset_window_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ---- emmc_sdio_func1_read32 ----
@ r0 = 32-bit backplane address.
@ Returns r0 = 0 on success, r1 = little-endian word.
emmc_sdio_func1_read32:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    bl      emmc_sdio_func1_set_backplane_window
    cmp     r0, #0
    bne     .Lread32_fail

    ldr     r5, =SBSDIO_SB_OFT_ADDR_MASK
    and     r5, r4, r5
    mov     r6, #0

    mov     r0, r5
    bl      emmc_sdio_cmd52_read_func1_byte
    cmp     r0, #0
    bne     .Lread32_fail
    orr     r6, r6, r1

    add     r0, r5, #1
    bl      emmc_sdio_cmd52_read_func1_byte
    cmp     r0, #0
    bne     .Lread32_fail
    orr     r6, r6, r1, lsl #8

    add     r0, r5, #2
    bl      emmc_sdio_cmd52_read_func1_byte
    cmp     r0, #0
    bne     .Lread32_fail
    orr     r6, r6, r1, lsl #16

    add     r0, r5, #3
    bl      emmc_sdio_cmd52_read_func1_byte
    cmp     r0, #0
    bne     .Lread32_fail
    orr     r6, r6, r1, lsl #24

    mov     r0, #0
    mov     r1, r6
    pop     {r4, r5, r6, pc}

.Lread32_fail:
    mov     r0, #1
    mov     r1, #0
    pop     {r4, r5, r6, pc}

@ ---- emmc_sdio_func1_write32 ----
@ r0 = 32-bit backplane address, r1 = little-endian word.
@ Returns r0 = 0 on success.
emmc_sdio_func1_write32:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    mov     r6, r1
    bl      emmc_sdio_func1_set_backplane_window
    cmp     r0, #0
    bne     .Lwrite32_fail

    ldr     r5, =SBSDIO_SB_OFT_ADDR_MASK
    and     r5, r4, r5

    mov     r0, r5
    and     r1, r6, #0xff
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwrite32_fail

    add     r0, r5, #1
    lsr     r1, r6, #8
    and     r1, r1, #0xff
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwrite32_fail

    add     r0, r5, #2
    lsr     r1, r6, #16
    and     r1, r1, #0xff
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwrite32_fail

    add     r0, r5, #3
    lsr     r1, r6, #24
    and     r1, r1, #0xff
    bl      emmc_sdio_cmd52_write_func1_byte
    cmp     r0, #0
    bne     .Lwrite32_fail

    mov     r0, #0
    pop     {r4, r5, r6, pc}

.Lwrite32_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

@ ---- emmc_sdio_func1_update32 ----
@ r0 = 32-bit backplane address, r1 = clear mask, r2 = set mask.
@ Returns r0 = 0 on success, r1 = updated little-endian word.
emmc_sdio_func1_update32:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    bl      emmc_sdio_func1_read32
    cmp     r0, #0
    bne     .Lupdate32_fail
    bic     r1, r1, r5
    orr     r6, r1, r6
    mov     r0, r4
    mov     r1, r6
    bl      emmc_sdio_func1_write32
    cmp     r0, #0
    bne     .Lupdate32_fail
    mov     r0, #0
    mov     r1, r6
    pop     {r4, r5, r6, pc}

.Lupdate32_fail:
    mov     r0, #1
    mov     r1, #0
    pop     {r4, r5, r6, pc}

@ ---- emmc_sdio_func2_write_word ----
@ r0 = function 2 SDIO address, r1 = little-endian word.
@ Returns r0 = 0 on success.
emmc_sdio_func2_write_word:
    push    {lr}
    sub     sp, sp, #4
    str     r1, [sp]
    mov     r1, sp
    mov     r2, #1
    bl      emmc_sdio_func2_write_words
    add     sp, sp, #4
    pop     {pc}

@ ---- emmc_sdio_func2_write_words ----
@ r0 = function 2 SDIO address, r1 = word buffer, r2 = word count (1..128).
@ Returns r0 = 0 on success.
emmc_sdio_func2_write_words:
    push    {r4, r5, r6, r7, lr}
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    cmp     r6, #0
    beq     .Lfunc2_write_words_fail
    cmp     r6, #SDIO_CMD53_MAX_WORDS
    bhi     .Lfunc2_write_words_fail
    ldr     r7, =SDIO_CMD53_ADDR_MASK
    bic     r3, r4, r7
    cmp     r3, #0
    bne     .Lfunc2_write_words_fail
    lsl     r2, r6, #2
    add     r3, r4, r2
    subs    r3, r3, #1
    bic     r3, r3, r7
    cmp     r3, #0
    bne     .Lfunc2_write_words_fail
    ldr     r3, =512
    cmp     r2, r3
    moveq   r2, #0
    lsl     r0, r4, #SDIO_CMD53_ADDR_SHIFT
    ldr     r3, =(SDIO_CMD53_WRITE | SDIO_CMD53_FUNC2 | SDIO_CMD53_OP_INC)
    orr     r0, r0, r2
    orr     r0, r0, r3
    mov     r1, r5
    mov     r2, r6
    bl      emmc_sdio_write_words_cmd53
    pop     {r4, r5, r6, r7, pc}

.Lfunc2_write_words_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, pc}

@ ---- emmc_sdio_func2_write_backplane_words ----
@ r0 = 32-bit backplane address, r1 = word buffer, r2 = word count (1..128).
@ Returns r0 = 0 on success.
emmc_sdio_func2_write_backplane_words:
    push    {r4, r5, r6, r7, lr}
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    cmp     r6, #0
    beq     .Lfunc2_write_backplane_words_fail
    cmp     r6, #SDIO_CMD53_MAX_WORDS
    bhi     .Lfunc2_write_backplane_words_fail
    ldr     r7, =SBSDIO_SB_OFT_ADDR_MASK
    and     r0, r4, r7
    lsl     r3, r6, #2
    add     r3, r0, r3
    subs    r3, r3, #1
    bic     r3, r3, r7
    cmp     r3, #0
    bne     .Lfunc2_write_backplane_words_fail
    mov     r0, r4
    bl      emmc_sdio_func1_set_backplane_window
    cmp     r0, #0
    bne     .Lfunc2_write_backplane_words_fail
    and     r0, r4, r7
    mov     r1, r5
    mov     r2, r6
    bl      emmc_sdio_func2_write_words
    pop     {r4, r5, r6, r7, pc}

.Lfunc2_write_backplane_words_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, pc}

@ ---- emmc_sdio_write_words_cmd53 ----
@ r0 = CMD53 ARG1, r1 = word buffer, r2 = word count.
@ Returns r0 = 0 on success.
emmc_sdio_write_words_cmd53:
    push    {r4, r5, r6, r7, lr}
    ldr     r4, =EMMC_BASE
    mov     r5, r1
    mov     r6, r2
    lsl     r1, r6, #2
    mov     r7, #1
    orr     r1, r1, r7, lsl #16
    str     r1, [r4, #EMMC_BLKSIZECNT]
    str     r0, [r4, #EMMC_ARG1]
    ldr     r0, =CMD53_WRITE_VAL
    str     r0, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lcmd53_write_words_fail

    mov     r2, #0x1000000
1:  ldr     r0, [r4, #EMMC_INTERRUPT]
    tst     r0, #INT_WRITE_READY
    bne     2f
    tst     r0, #INT_ERROR
    bne     .Lcmd53_write_words_fail
    subs    r2, r2, #1
    bne     1b
    b       .Lcmd53_write_words_fail
2:
    str     r0, [r4, #EMMC_INTERRUPT]
3:
    ldr     r0, [r5], #4
    str     r0, [r4, #EMMC_DATA]
    subs    r6, r6, #1
    bne     3b
    bl      emmc_wait_data_done
    cmp     r0, #0
    bne     .Lcmd53_write_words_fail
    mov     r0, #0
    pop     {r4, r5, r6, r7, pc}

.Lcmd53_write_words_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, pc}

@ ---- emmc_sdio_cmd ----
@ r0 = ARG1, r1 = CMDTM
@ Returns r0 = 0 on success, r1 = RESP0.
emmc_sdio_cmd:
    push    {r4, lr}
    ldr     r4, =EMMC_BASE
    str     r0, [r4, #EMMC_ARG1]
    str     r1, [r4, #EMMC_CMDTM]
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lsdio_cmd_fail
    ldr     r1, [r4, #EMMC_RESP0]
    mov     r0, #0
    pop     {r4, pc}

.Lsdio_cmd_fail:
    mov     r0, #1
    mov     r1, #0
    pop     {r4, pc}

@ Wait for CMD_DONE interrupt, return 0 on success, 1 on error/timeout
emmc_wait_cmd_done:
    push    {r4, r5, lr}
    mov     r4, #0x1000000
    mov     r5, #EMMC_INTERRUPT
1:  mov     r0, r5
    bl      emmc_mmio_read
    tst     r0, #INT_CMD_DONE
    bne     2f
    tst     r0, #INT_ERROR
    bne     3f
    subs    r4, r4, #1
    bne     1b
3:  @ Error or timeout
    mvn     r0, #0
    mov     r1, r0
    mov     r0, r5
    bl      emmc_mmio_write
    mov     r0, #1
    pop     {r4, r5, pc}
2:  @ Success
    mov     r1, r0
    mov     r0, r5
    bl      emmc_mmio_write
    mov     r0, #0
    pop     {r4, r5, pc}

@ Wait for DATA_DONE interrupt or data_ready bit, return 0 on success
emmc_wait_data_done:
    push    {r4, r5, lr}
    mov     r4, #0x1000000
    mov     r5, #EMMC_INTERRUPT
1:  mov     r0, r5
    bl      emmc_mmio_read
    tst     r0, #INT_DATA_DONE
    bne     2f
    tst     r0, #INT_ERROR
    bne     3f
    subs    r4, r4, #1
    bne     1b
3:  mvn     r0, #0
    mov     r1, r0
    mov     r0, r5
    bl      emmc_mmio_write
    mov     r0, #1
    pop     {r4, r5, pc}
2:  mov     r1, r0
    mov     r0, r5
    bl      emmc_mmio_write
    mov     r0, #0
    pop     {r4, r5, pc}

@ ---- emmc_read_block ----
@ r0 = LBA (sector number)
@ r1 = destination buffer (must be 4-byte aligned)
@ Returns r0 = 0 on success
emmc_read_block:
    push    {r4, r5, r6, lr}
    mov     r4, r0
    mov     r5, r1
    cmp     r5, #0
    beq     .Lread_fail
    tst     r5, #3
    bne     .Lread_fail

    @ Compute byte address or LBA based on capacity flag
    mov     r0, #EMMC_SCRATCH
    bl      emmc_mmio_read
    cmp     r0, #0
    bne     1f
    @ SDSC: multiply LBA by 512
    mov     r0, r4, lsl #9
    b       2f
1:  @ SDHC: use LBA directly
    mov     r0, r4
2:  mov     r1, r0
    mov     r0, #EMMC_ARG1
    bl      emmc_mmio_write

    ldr     r0, =SD_BLKSIZECNT_SINGLE
    mov     r1, r0
    mov     r0, #EMMC_BLKSIZECNT
    bl      emmc_mmio_write

    @ Send CMD17
    ldr     r0, =CMD17_VAL
    mov     r1, r0
    mov     r0, #EMMC_CMDTM
    bl      emmc_mmio_write
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lread_fail

    @ Wait for READ_READY
    mov     r6, #0x1000000
1:  mov     r0, #EMMC_INTERRUPT
    bl      emmc_mmio_read
    tst     r0, #INT_READ_READY
    bne     2f
    tst     r0, #INT_ERROR
    bne     .Lread_fail
    subs    r6, r6, #1
    bne     1b
    b       .Lread_fail
2:  mov     r1, r0
    mov     r0, #EMMC_INTERRUPT
    bl      emmc_mmio_write

    @ Read one 512-byte block from DATA FIFO.
    mov     r6, #SD_BLOCK_WORDS
1:  mov     r0, #EMMC_DATA
    bl      emmc_mmio_read
    str     r0, [r5], #4
    subs    r6, r6, #1
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
    cmp     r5, #0
    beq     .Lwrite_fail
    tst     r5, #3
    bne     .Lwrite_fail

    mov     r0, #EMMC_SCRATCH
    bl      emmc_mmio_read
    cmp     r0, #0
    bne     1f
    mov     r0, r4, lsl #9
    b       2f
1:  mov     r0, r4
2:  mov     r1, r0
    mov     r0, #EMMC_ARG1
    bl      emmc_mmio_write

    ldr     r0, =SD_BLKSIZECNT_SINGLE
    mov     r1, r0
    mov     r0, #EMMC_BLKSIZECNT
    bl      emmc_mmio_write

    ldr     r0, =CMD24_VAL
    mov     r1, r0
    mov     r0, #EMMC_CMDTM
    bl      emmc_mmio_write
    bl      emmc_wait_cmd_done
    cmp     r0, #0
    bne     .Lwrite_fail

    @ Wait for WRITE_READY
    mov     r6, #0x1000000
1:  mov     r0, #EMMC_INTERRUPT
    bl      emmc_mmio_read
    tst     r0, #INT_WRITE_READY
    bne     2f
    tst     r0, #INT_ERROR
    bne     .Lwrite_fail
    subs    r6, r6, #1
    bne     1b
    b       .Lwrite_fail
2:  mov     r1, r0
    mov     r0, #EMMC_INTERRUPT
    bl      emmc_mmio_write

    @ Write one 512-byte block to DATA FIFO.
    mov     r6, #SD_BLOCK_WORDS
1:  ldr     r0, [r5], #4
    mov     r1, r0
    mov     r0, #EMMC_DATA
    bl      emmc_mmio_write
    subs    r6, r6, #1
    bne     1b

    bl      emmc_wait_data_done
    cmp     r0, #0
    bne     .Lwrite_fail

    mov     r0, #0
    pop     {r4, r5, r6, pc}
.Lwrite_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

@ ---- default MMIO hooks ----
emmc_mmio_read:
    ldr     r1, =EMMC_BASE
    ldr     r0, [r1, r0]
    bx      lr

emmc_mmio_write:
    ldr     r2, =EMMC_BASE
    str     r1, [r2, r0]
    bx      lr
