; EdgeRun Intel SDHCI/eMMC host controller constants — x86_64 assembly
; SD Host Controller Standard Specification v5.0 register map
;
; Included by intel_sdhci.asm — provides register offsets as %define constants.

; ─── PCI identifiers ───────────────────────────────────────────────
%define INTEL_VENDOR          0x8086
%define INTEL_EMMC_9D2B      0x9D2B  ; Sunrise Point-LP eMMC (Surface Go 1)
%define INTEL_SD_9D2D        0x9D2D  ; Sunrise Point-LP SD

; ─── Bar0 register offsets (byte offsets from SDHCI register base) ─
%define SDHCI_SDMA_ADDR      0x00
%define SDHCI_ARGUMENT       0x08
%define SDHCI_TRANSFER_MODE  0x0C
%define SDHCI_COMMAND        0x0E
%define SDHCI_RESPONSE_0     0x10
%define SDHCI_RESPONSE_1     0x14
%define SDHCI_RESPONSE_2     0x18
%define SDHCI_RESPONSE_3     0x1C
%define SDHCI_BUFFER_DATA    0x20
%define SDHCI_PRESENT_STATE  0x24
%define SDHCI_HOST_CTL       0x28
%define SDHCI_POWER          0x29
%define SDHCI_CLOCK          0x2C
%define SDHCI_TIMEOUT_CTRL   0x2E
%define SDHCI_SW_RST         0x2F
%define SDHCI_INT_STATUS     0x30
%define SDHCI_INT_ENABLE     0x34
%define SDHCI_SIGNAL_ENABLE  0x38
%define SDHCI_AC12_ERR       0x3C
%define SDHCI_CAPABILITIES_LO 0x40
%define SDHCI_CAPABILITIES_HI 0x44
%define SDHCI_MAX_CURRENT    0x48
%define SDHCI_HOST_CTL2      0x3E
%define SDHCI_ADMA_ERR       0x54
%define SDHCI_ADMA_ADDR_LO   0x58
%define SDHCI_ADMA_ADDR_HI   0x5C

; ─── Block size / count registers (16-bit each, stored at 0x04-0x07) ─
%define SDHCI_BLOCK_SIZE     0x04  ; bits 15:0 = block size
%define SDHCI_BLOCK_COUNT    0x06  ; bits 15:0 = block count

; ─── Transfer mode register bits (0x0C) ────────────────────────────
%define SDHCI_TRNS_DMA       (1 << 0)
%define SDHCI_TRNS_BLK_CNT  (1 << 1)
%define SDHCI_TRNS_AC        (1 << 2)
%define SDHCI_TRNS_READ     (1 << 4)
%define SDHCI_TRNS_MULTI    (1 << 5)

; ─── Command register bits (0x0E) ──────────────────────────────────
%define SDHCI_CMD_INDEX_SHIFT 8      ; bits 15:8
%define SDHCI_CMD_RESP_LEN    (1 << 6)
%define SDHCI_CMD_RESP_SHORT  (0 << 6)
%define SDHCI_CMD_RESP_LONG  (1 << 6)
%define SDHCI_CMD_CRC_CHECK  (1 << 5)
%define SDHCI_CMD_INDEX_CHECK (1 << 4)
%define SDHCI_CMD_DATA       (1 << 3)
%define SDHCI_CMD_SUSPEND    (1 << 2)
%define SDHCI_CMD_ABORT_CMD  (1 << 1)

; ─── Host control bits (0x28) ──────────────────────────────────────
%define SDHCI_HOST_CTL_LED    (1 << 0)
%define SDHCI_HOST_CTL_4BIT   (1 << 1)
%define SDHCI_HOST_CTL_HI_SPEED (1 << 2)
%define SDHCI_HOST_CTL_DMA_SEL_SHIFT 3
%define SDHCI_HOST_CTL_DMA_SEL_MASK (3 << 3)
%define SDHCI_HOST_CTL_DMA_SEL_SDMA (0 << 3)
%define SDHCI_HOST_CTL_DMA_SEL_ADMA1 (1 << 3)
%define SDHCI_HOST_CTL_DMA_SEL_ADMA2 (2 << 3)
%define SDHCI_HOST_CTL_8BIT  (1 << 5)
%define SDHCI_HOST_CTL_CARD_DET (1 << 6)

; ─── Power control bits (0x29) ─────────────────────────────────────
%define SDHCI_POWER_ON       0x0F
%define SDHCI_POWER_180      0x0A  ; 1.8V (eMMC)
%define SDHCI_POWER_300      0x0C
%define SDHCI_POWER_330      0x0E

; ─── Clock control bits (0x2C) ─────────────────────────────────────
%define SDHCI_CLOCK_INT_EN   (1 << 0)
%define SDHCI_CLOCK_INT_STABLE (1 << 1)
%define SDHCI_CLOCK_SD_EN    (1 << 2)
%define SDHCI_CLOCK_FREQ_SHIFT 8
%define SDHCI_CLOCK_FREQ_MASK (0xFF << 8)

; ─── Software reset bits (0x2F) ────────────────────────────────────
%define SDHCI_SW_RST_ALL     (1 << 0)
%define SDHCI_SW_RST_CMD     (1 << 1)
%define SDHCI_SW_RST_DATA    (1 << 2)

; ─── Interrupt status / enable bits (0x30, 0x34, 0x38) ────────────
%define SDHCI_INT_CMD_COMPLETE  (1 << 0)
%define SDHCI_INT_XFER_COMPLETE (1 << 1)
%define SDHCI_INT_BLOCK_GAP     (1 << 2)
%define SDHCI_INT_DMA_INT       (1 << 3)
%define SDHCI_INT_BUF_WR_READY  (1 << 4)
%define SDHCI_INT_BUF_RD_READY  (1 << 5)
%define SDHCI_INT_CARD_INS      (1 << 6)
%define SDHCI_INT_CARD_REM      (1 << 7)
%define SDHCI_INT_CARD_INT      (1 << 8)
%define SDHCI_INT_ERROR         (1 << 15)

; ─── Present state bits (0x24) ─────────────────────────────────────
%define SDHCI_STS_CMD_INHIBIT  (1 << 0)
%define SDHCI_STS_DATA_INHIBIT (1 << 1)
%define SDHCI_STS_CARD_INSERT  (1 << 16)
%define SDHCI_STS_CARD_STATE_STABLE (1 << 17)
%define SDHCI_STS_WRITE_XFER_ACTIVE (1 << 8)
%define SDHCI_STS_DAT_3_0      (0xF << 20)  ; DAT[3:0] signal level

; ─── Host Control 2 bits (0x3E) ────────────────────────────────────
%define SDHCI_HOST_CTL2_DRV_STR_SHIFT 4
%define SDHCI_HOST_CTL2_DRV_STR_MASK (3 << 4)
%define SDHCI_HOST_CTL2_PRESET_VAL_EN (1 << 14)
%define SDHCI_HOST_CTL2_ASYNC_INT_EN (1 << 6)

; ─── Capabilities LO bits (0x40) ───────────────────────────────────
%define SDHCI_CAP_V3_64BIT_DMA (1 << 28)
%define SDHCI_CAP_V3_BASE_CLOCK_SHIFT 8
%define SDHCI_CAP_V3_BASE_CLOCK_MASK (0xFF << 8)
%define SDHCI_CAP_V3_MAX_BLK_LEN_SHIFT 16
%define SDHCI_CAP_V3_MAX_BLK_LEN_MASK (3 << 16)

; ─── eMMC / SD commands ────────────────────────────────────────────
%define MMC_CMD0     0   ; GO_IDLE_STATE
%define MMC_CMD1     1   ; SEND_OP_COND (MMC)
%define MMC_CMD2     2   ; ALL_SEND_CID
%define MMC_CMD3     3   ; SET_RELATIVE_ADDR
%define MMC_CMD6     6   ; SWITCH
%define MMC_CMD7     7   ; SELECT_DESELECT_CARD
%define MMC_CMD8     8   ; SEND_IF_COND (SD)
%define MMC_CMD9     9   ; SEND_CSD
%define MMC_CMD12    12  ; STOP_TRANSMISSION
%define MMC_CMD13    13  ; SEND_STATUS
%define MMC_CMD16    16  ; SET_BLOCKLEN
%define MMC_CMD17    17  ; READ_SINGLE_BLOCK
%define MMC_CMD18    18  ; READ_MULTIPLE_BLOCK
%define MMC_CMD24    24  ; WRITE_BLOCK
%define MMC_CMD55    55  ; APP_CMD
%define MMC_ACMD6    6   ; SET_BUS_WIDTH (SD)
%define MMC_ACMD41   41  ; SD_SEND_OP_COND (SD)
%define MMC_ACMD51   51  ; SEND_SCR (SD)

; ─── R1 response bits ──────────────────────────────────────────────
%define R1_READY_FOR_DATA  (1 << 8)
%define R1_CURRENT_STATE_SHIFT 9
%define R1_CURRENT_STATE_MASK (0xF << 9)
%define R1_SWITCH_ERROR    (1 << 7)
; MMC states
%define MMC_STATE_IDLE   0
%define MMC_STATE_READY  1
%define MMC_STATE_IDENT  2
%define MMC_STATE_STBY   3
%define MMC_STATE_TRAN   4
%define MMC_STATE_DATA   5
%define MMC_STATE_RCV    6
%define MMC_STATE_PRG    7
%define MMC_STATE_DIS    8

; ─── OCR register bits ─────────────────────────────────────────────
%define OCR_3_3_3_4       (1 << 20)
%define OCR_3_2_3_3       (1 << 21)
%define OCR_3_1_3_2       (1 << 22)
%define OCR_3_0_3_1       (1 << 23)
%define OCR_2_9_3_0       (1 << 24)
%define OCR_2_8_2_9       (1 << 25)
%define OCR_2_7_2_8       (1 << 26)
%define OCR_2_6_2_7       (1 << 27)
%define OCR_2_5_2_6       (1 << 28)
%define OCR_2_4_2_5       (1 << 29)
%define OCR_2_3_2_4       (1 << 30)
%define OCR_2_2_2_3       (1 << 31)
%define OCR_CCS           (1 << 30)  ; Card Capacity Status
%define OCR_BUSY          (1 << 31)  ; Card power-up busy

; ─── SDHCI driver constants ────────────────────────────────────────
%define SDHCI_BLOCK_SIZE_512  0x200
%define SDHCI_POLL_MAX        100000
%define SDHCI_RCA_DEFAULT     0x0001  ; Default Relative Card Address for MMC

; Error codes (shared with wasm_defines.inc)
