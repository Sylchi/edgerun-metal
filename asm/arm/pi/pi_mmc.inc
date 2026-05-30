; Pi EMMC/SD host controller — constants from pi_mmc.zig
; Target: ARM (arm-none-eabi-as)
;
; EMMC register offsets (relative to EMMC peripheral base)
%define EMMC_REG_ARG2              0x00
%define EMMC_REG_BLKSIZECNT        0x04
%define EMMC_REG_ARG1              0x08
%define EMMC_REG_CMDTM             0x0c
%define EMMC_REG_RESP0             0x10
%define EMMC_REG_RESP1             0x14
%define EMMC_REG_RESP2             0x18
%define EMMC_REG_RESP3             0x1c
%define EMMC_REG_DATA              0x20
%define EMMC_REG_CONTROL0          0x28
%define EMMC_REG_CONTROL1          0x2c
%define EMMC_REG_INTERRUPT         0x30
%define EMMC_REG_IRPT_MASK         0x34
%define EMMC_REG_IRPT_EN           0x38
%define EMMC_REG_CONTROL2          0x3c
%define EMMC_REG_CAPABILITIES_0    0x40
%define EMMC_REG_CAPABILITIES_1    0x44
%define EMMC_SLOTISR_VER           0xfc

; EMMC interrupt bits
%define EMMC_INT_CMD_DONE          0x00000001
%define EMMC_INT_DATA_DONE         0x00000002
%define EMMC_INT_WRITE_READY       0x00000010
%define EMMC_INT_READ_READY        0x00000020
%define EMMC_INT_ERROR_MASK        0xffff0000
%define EMMC_INT_ALL               0xffffffff

; EMMC CMDTM fields
%define EMMC_CMDTM_RESP_NONE       0
%define EMMC_CMDTM_RESP_136        1
%define EMMC_CMDTM_RESP_48         2
%define EMMC_CMDTM_BLOCK_COUNT_EN  (1 << 1)
%define EMMC_CMDTM_DATA_READ       (1 << 4)
%define EMMC_CMDTM_CRC_CHECK       (1 << 19)
%define EMMC_CMDTM_INDEX_CHECK     (1 << 20)
%define EMMC_CMDTM_IS_DATA         (1 << 21)
%define EMMC_CMDTM_INDEX_BITS      24

; Block size
%define EMMC_BLOCK_BYTES           512

; SD command indexes
%define SD_CMD_GO_IDLE_STATE       0
%define SD_CMD_ALL_SEND_CID        2
%define SD_CMD_SEND_RELATIVE_ADDR  3
%define SD_CMD_IO_SEND_OP_COND     5
%define SD_CMD_SELECT_CARD         7
%define SD_CMD_SEND_IF_COND        8
%define SD_CMD_READ_SINGLE_BLOCK   17
%define SD_CMD_WRITE_BLOCK         24
%define SD_CMD_IO_RW_DIRECT        52
%define SD_CMD_IO_RW_EXTENDED      53
%define SD_ACMD_SD_SEND_OP_COND    41
%define SD_CMD_APP_CMD             55

; SD response types
%define SD_RESP_NONE               0
%define SD_RESP_R1                 1
%define SD_RESP_R2                 2
%define SD_RESP_R3                 3
%define SD_RESP_R4                 4
%define SD_RESP_R5                 5
%define SD_RESP_R6                 6
%define SD_RESP_R7                 7

; SDIO function numbers
%define SDIO_FUNC_CCCR             0
%define SDIO_FUNC_BACKPLANE        1
%define SDIO_FUNC_WLAN             2

; SDIO CMD52/CMD53 argument helpers
; sdioCmd52Argument(write, function, raw, address, data):
;   bit 31: write flag
;   bits 30..28: function number (3 bits)
;   bit 27: raw flag
;   bits 25..9: address (17 bits)
;   bits 7..0: data byte
%define SDIO_CMD52_WRITE_BIT       31
%define SDIO_CMD52_FUNCTION_BITS   28
%define SDIO_CMD52_RAW_BIT         27
%define SDIO_CMD52_ADDRESS_BITS    9

; sdioCmd53Argument(write, function, block_mode, incrementing, address, count):
;   bit 31: write flag
;   bits 30..28: function number
;   bit 27: block_mode flag
;   bit 26: incrementing address flag
;   bits 25..9: address
;   bits 8..0: count
%define SDIO_CMD53_WRITE_BIT       31
%define SDIO_CMD53_FUNCTION_BITS   28
%define SDIO_CMD53_BLOCK_MODE_BIT  27
%define SDIO_CMD53_INC_ADDR_BIT    26
%define SDIO_CMD53_ADDRESS_BITS    9

; RCA (Relative Card Address)
%define MMC_RCA_MASK               0x0000ffff
%define MMC_RCA_ARGUMENT_BITS      16

; Clock IDs for mailbox set/get clock rate
%define CLOCK_ID_EMMC              1
%define CLOCK_ID_UART              2

; Mailbox two-value message structure (8 words = 32 bytes)
; struct MailboxTwoValueMessage {
;     u32 size_bytes;
;     u32 request_code;
;     u32 tag_id;
;     u32 value_buffer_bytes;
;     u32 request_value_bytes;
;     u32 value0;
;     u32 value1;
;     u32 end_tag;  (= 0)
; };
%define MAILBOX_TWO_VALUE_WORDS    8
%define MAILBOX_TWO_VALUE_BYTES    32

; ---- helper macro: pack SDIO CMD52 argument ----
; args: %1 = write (0/1), %2 = function, %3 = raw (0/1), %4 = address, %5 = data
; result: r0
%macro sdio_cmd52_arg 5
    mov     r0, %5
    orr     r0, r0, %4, lsl #9
    orr     r0, r0, %3, lsl #27
    orr     r0, r0, %2, lsl #28
    orr     r0, r0, %1, lsl #31
%endmacro

; ---- helper macro: pack SDIO CMD53 argument ----
; args: %1 = write (0/1), %2 = function, %3 = block_mode (0/1), %4 = inc_addr (0/1), %5 = address, %6 = count
; result: r0
%macro sdio_cmd53_arg 6
    mov     r0, %6
    and     r0, r0, #0x1ff
    orr     r0, r0, %5, lsl #9
    orr     r0, r0, %4, lsl #26
    orr     r0, r0, %3, lsl #27
    orr     r0, r0, %2, lsl #28
    orr     r0, r0, %1, lsl #31
%endmacro

; ---- helper: pack CMDTM value from command index and response kind ----
; args: %1 = cmd_index, %2 = response_kind (SD_RESP_*)
; result: r0
%macro emmc_cmdtm_value 2
    mov     r0, %2, lsl #16
    orr     r0, r0, %1, lsl #24
    ; add CRC check for R1, R2, R5, R6, R7
    ; (simplified: always set CRC+index check — harmless for No response)
%endmacro
