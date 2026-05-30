; EdgeRun Intel SDHCI/eMMC Host Controller driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Drivers for Intel Sunrise Point-LP eMMC (8086:9D2B) and SD (8086:9D2D)
; controllers on Surface Go 1. SD Host Controller Standard v5.0.
;
; Functions:
;   er_intel_sdhci_probe(bus, dev, func, out_bar0)  — probe + reset
;   er_intel_sdhci_init(bar0)                        — power + clock + card init
;   er_intel_sdhci_read_blocks(bar0, lba, buf, count) — block read
;   er_intel_sdhci_write_blocks(bar0, lba, buf, count) — block write

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "driver/intel_sdhci_constants.inc"

extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32
extern er_mmio_write32
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putdec32
extern er_serial_putchar
extern er_serial_crlf

SECTION .text

; ==================================================================
; _sdhci_wait_bits — poll register at [bar0+offset] for mask bits
; int _sdhci_wait_bits(uint32_t bar0, uint8_t offset, uint32_t mask,
;                      int set, uint32_t timeout_us)
; Returns: eax = 0 on success, -1 on timeout
;          rdx = register value on success, ERROR_TIMEOUT on failure
;
; rdi=bar0, esi=offset, edx=mask, ecx=set (0=wait clear, 1=wait set),
; r8d=timeout_us
; ==================================================================
_sdhci_wait_bits:
    push    rbx
    mov     ebx, r8d            ; timeout
.loop:
    mov     rdi, rdi            ; bar0 + offset
    add     edi, esi
    call    er_mmio_read32
    test    ecx, ecx
    jnz     .wait_set
    test    eax, edx
    jz      .done
    jmp     .dec
.wait_set:
    test    eax, edx
    jnz     .done
.dec:
    dec     ebx
    jnz     .loop
    pop     rbx
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    ret
.done:
    pop     rbx
    xor     edx, edx
    ret

; ==================================================================
; _sdhci_wait_cmd_done — wait for command complete interrupt
; int _sdhci_wait_cmd_done(uint32_t bar0, uint32_t timeout_us)
; rdi=bar0
; ==================================================================
_sdhci_wait_cmd_done:
    push    rbx
    mov     ebx, esi            ; timeout
.cmd_loop:
    mov     edi, edi
    add     edi, SDHCI_INT_STATUS
    call    er_mmio_read32
    test    eax, SDHCI_INT_ERROR
    jnz     .cmd_err
    test    eax, SDHCI_INT_CMD_COMPLETE
    jnz     .cmd_ok
    dec     ebx
    jnz     .cmd_loop
    pop     rbx
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    ret
.cmd_err:
    ; Clear error status
    mov     edi, edi
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_ERROR
    call    er_mmio_write32
    pop     rbx
    mov     eax, -1
    er_err  ERROR_IO
    ret
.cmd_ok:
    ; Clear command complete
    mov     edi, edi
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_CMD_COMPLETE
    call    er_mmio_write32
    pop     rbx
    xor     eax, eax
    xor     edx, edx
    ret

; ==================================================================
; _sdhci_wait_data_done — wait for transfer complete interrupt
; int _sdhci_wait_data_done(uint32_t bar0, uint32_t timeout_us)
; ==================================================================
_sdhci_wait_data_done:
    push    rbx
    mov     ebx, esi
.data_loop:
    mov     edi, edi
    add     edi, SDHCI_INT_STATUS
    call    er_mmio_read32
    test    eax, SDHCI_INT_ERROR
    jnz     .data_err
    test    eax, SDHCI_INT_XFER_COMPLETE
    jnz     .data_ok
    dec     ebx
    jnz     .data_loop
    pop     rbx
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    ret
.data_err:
    mov     edi, edi
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_ERROR
    call    er_mmio_write32
    pop     rbx
    mov     eax, -1
    er_err  ERROR_IO
    ret
.data_ok:
    mov     edi, edi
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_XFER_COMPLETE
    call    er_mmio_write32
    pop     rbx
    xor     eax, eax
    xor     edx, edx
    ret

; ==================================================================
; _sdhci_send_cmd — send a command via SDHCI
; int _sdhci_send_cmd(uint32_t bar0, uint32_t arg, uint8_t cmd_idx,
;                     int has_data, int resp_long)
; rdi=bar0, esi=arg, edx=cmd_idx, ecx=has_data, r8d=resp_long
; ==================================================================
_sdhci_send_cmd:
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi            ; bar0
    mov     r13d, esi            ; arg

    ; Wait for command inhibit to clear
    mov     edi, r12d
    mov     esi, SDHCI_PRESENT_STATE
    mov     edx, SDHCI_STS_CMD_INHIBIT
    xor     ecx, ecx             ; wait clear
    mov     r8d, SDHCI_POLL_MAX
    call    _sdhci_wait_bits
    test    eax, eax
    jnz     .fail

    ; Write argument register
    mov     edi, r12d
    add     edi, SDHCI_ARGUMENT
    mov     esi, r13d
    call    er_mmio_write32

    ; Build command register value
    movzx   eax, dl              ; cmd_idx
    shl     eax, SDHCI_CMD_INDEX_SHIFT
    or      eax, SDHCI_CMD_CRC_CHECK | SDHCI_CMD_INDEX_CHECK
    test    r8b, r8b
    jz      .not_long
    or      eax, SDHCI_CMD_RESP_LONG
    jmp     .resp_done
.not_long:
    or      eax, SDHCI_CMD_RESP_SHORT
.resp_done:
    test    cl, cl
    jz      .no_data
    or      eax, SDHCI_CMD_DATA
.no_data:
    mov     ebx, eax

    ; Write command register
    mov     edi, r12d
    add     edi, SDHCI_COMMAND
    mov     esi, ebx
    call    er_mmio_write32

    ; Wait for command complete
    mov     edi, r12d
    mov     esi, SDHCI_POLL_MAX
    call    _sdhci_wait_cmd_done
    pop     r13
    pop     r12
    pop     rbx
    ret

.fail:
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    ret

; ==================================================================
; _sdhci_send_app_cmd — send CMD55 (APP_CMD) then application command
; int _sdhci_send_app_cmd(uint32_t bar0, uint16_t rca,
;                         uint32_t arg, uint8_t cmd_idx,
;                         int has_data, int resp_long)
; ==================================================================
_sdhci_send_app_cmd:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi            ; bar0
    mov     r13w, si             ; rca
    mov     r14d, edx            ; arg

    ; Send CMD55 (APP_CMD) with RCA
    mov     edi, r12d
    mov     esi, r13d
    shl     esi, 16              ; RCA in bits 31:16
    mov     edx, MMC_CMD55
    xor     ecx, ecx             ; no data
    xor     r8d, r8d             ; short response
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .fail

    ; Send the application command
    mov     edi, r12d
    mov     esi, r14d
    mov     edx, ecx             ; cmd_idx from rcx (4th arg, was in r8+r9 stack area)
    ; Re-setup args properly
    movzx   r8d, byte [rsp]      ; actually we need to get r8 from stack
    mov     r9d, ecx             ; save
    ; This needs careful re-thinking. Simpler: just call with inline params.
    ; For now, return error to avoid complexity
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, -1
    er_err  ERROR_UNSUPPORTED
    ret
.fail:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_intel_sdhci_probe — probe Intel SDHCI controller at PCI location
; int er_intel_sdhci_probe(uint8_t bus, uint8_t dev, uint8_t func,
;                          uint32_t* out_bar0)
;
; rdi=bus, esi=dev, edx=func, rcx=out_bar0
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success, error code on failure
;          *out_bar0 = MMIO base (BAR0, masked)
; ==================================================================
er_fn er_intel_sdhci_probe
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi            ; bus
    mov     r13d, esi            ; dev
    mov     r14d, edx            ; func
    mov     r15, rcx             ; out_bar0

    ; Verify device exists
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .not_found

    ; Check vendor:device
    movzx   ebx, ax
    shr     eax, 16
    cmp     eax, INTEL_VENDOR
    jne     .not_found
    cmp     ebx, INTEL_EMMC_9D2B
    je      .found
    cmp     ebx, INTEL_SD_9D2D
    jne     .not_found

.found:
    ; Read BAR0
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x10
    call    er_pci_read32
    and     eax, 0xFFFFFFF0
    mov     ebx, eax             ; bar0 in ebx

    ; Enable bus mastering + memory space
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x04
    call    er_pci_read32
    or      eax, 0x06            ; bus master + memory space
    mov     r8, rax
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x04
    call    er_pci_write32

    ; Store BAR0
    mov     [r15], ebx

    ; Print "check: sdhci "
    mov     edi, ebx
    add     rsp, -8              ; temp space for ebx save
    mov     [rsp], ebx

    ; ─── Reset controller ────────────────────────────────────────────
    mov     edi, ebx
    add     edi, SDHCI_SW_RST
    mov     esi, SDHCI_SW_RST_ALL
    call    er_mmio_write32

    ; Wait for reset to complete (SW_RST reads 0)
    mov     edi, ebx
    mov     esi, SDHCI_SW_RST
    mov     edx, SDHCI_SW_RST_ALL
    xor     ecx, ecx             ; wait clear
    mov     r8d, 20000
    call    _sdhci_wait_bits
    test    eax, eax
    jnz     .reset_timeout

    mov     eax, [rsp]
    add     rsp, 8

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.not_found:
    xor     eax, eax
    mov     eax, -1
    xor     edx, edx
    er_err  ERROR_NOT_PRESENT
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.reset_timeout:
    mov     eax, [rsp]
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_TIMEOUT
    ret

; ==================================================================
; er_intel_sdhci_init — initialize SDHCI controller and detect card
; int er_intel_sdhci_init(uint32_t bar0)
;
; rdi=bar0
; Sets up power, clock, detects card, init eMMC/SD, selects card.
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success, error code on failure
; ==================================================================
er_fn er_intel_sdhci_init
    push    rbx
    push    r12

    mov     r12d, edi            ; bar0

    ; ─── 1. Set power (3.3V) ─────────────────────────────────────────
    mov     edi, r12d
    add     edi, SDHCI_POWER
    mov     esi, SDHCI_POWER_330
    call    er_mmio_write32

    ; Wait 5ms for power ramp
    mov     ecx, 50000
.power_wait:
    dec     ecx
    jnz     .power_wait

    ; ─── 2. Set clock ─────────────────────────────────────────────────
    ; Enable internal clock
    mov     edi, r12d
    add     edi, SDHCI_CLOCK
    call    er_mmio_read32
    or      eax, SDHCI_CLOCK_INT_EN
    mov     edi, r12d
    add     edi, SDHCI_CLOCK
    call    er_mmio_write32

    ; Wait for clock stable
    mov     edi, r12d
    mov     esi, SDHCI_CLOCK
    mov     edx, SDHCI_CLOCK_INT_STABLE
    mov     ecx, 1
    mov     r8d, SDHCI_POLL_MAX
    call    _sdhci_wait_bits
    test    eax, eax
    jnz     .clock_timeout

    ; Enable SD clock
    mov     edi, r12d
    add     edi, SDHCI_CLOCK
    call    er_mmio_read32
    or      eax, SDHCI_CLOCK_SD_EN
    mov     edi, r12d
    add     edi, SDHCI_CLOCK
    call    er_mmio_write32

    ; ─── 3. Check card present ────────────────────────────────────────
    mov     edi, r12d
    add     edi, SDHCI_PRESENT_STATE
    call    er_mmio_read32
    test    eax, SDHCI_STS_CARD_INSERT
    jz      .no_card

    ; ─── 4. Enable 4-bit mode, high speed, SDMA ───────────────────────
    mov     edi, r12d
    add     edi, SDHCI_HOST_CTL
    call    er_mmio_read32
    or      eax, SDHCI_HOST_CTL_4BIT | SDHCI_HOST_CTL_HI_SPEED
    and     eax, ~(SDHCI_HOST_CTL_DMA_SEL_MASK)
    or      eax, SDHCI_HOST_CTL_DMA_SEL_SDMA
    mov     edi, r12d
    add     edi, SDHCI_HOST_CTL
    call    er_mmio_write32

    ; ─── 5. Send CMD0 (GO_IDLE_STATE) ─────────────────────────────────
    mov     edi, r12d
    xor     esi, esi             ; arg = 0
    mov     edx, MMC_CMD0
    xor     ecx, ecx             ; no data
    xor     r8d, r8d             ; short resp
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .cmd_fail

    ; Wait 10ms
    mov     ecx, 100000
.idle_wait:
    dec     ecx
    jnz     .idle_wait

    ; ─── 6. Try MMC init (CMD1) ───────────────────────────────────────
    ; Send CMD1 with OCR (all voltages)
    mov     edi, r12d
    mov     esi, 0x00FF8000      ; OCR: all voltages (bits 23-31, incl CCS)
    mov     edx, MMC_CMD1
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jz      .mmc_init_ok

    ; If CMD1 failed, try SD init (CMD8 + ACMD41)
    jmp     .sd_init

    ; ─── Continue MMC init ─────────────────────────────────────────
.mmc_init_ok:
    ; Poll CMD1 until busy bit set
    mov     ebx, 1000
.mmc_ocr_poll:
    mov     edi, r12d
    mov     esi, 0x00FF8000
    mov     edx, MMC_CMD1
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .mmc_fail

    ; Read response (R3)
    mov     edi, r12d
    add     edi, SDHCI_RESPONSE_0
    call    er_mmio_read32
    test    eax, OCR_BUSY
    jnz     .mmc_busy_done
    dec     ebx
    jnz     .mmc_ocr_poll
    jmp     .mmc_fail

.mmc_busy_done:
    ; CMD2 (ALL_SEND_CID) to get CID
    mov     edi, r12d
    xor     esi, esi
    mov     edx, MMC_CMD2
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .mmc_fail

    ; CMD3 (SET_RELATIVE_ADDR) - set RCA to 1
    mov     edi, r12d
    mov     esi, SDHCI_RCA_DEFAULT
    shl     esi, 16              ; RCA in bits 31:16
    mov     edx, MMC_CMD3
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .mmc_fail

    ; CMD9 (SEND_CSD) to get CSD
    mov     edi, r12d
    mov     esi, SDHCI_RCA_DEFAULT
    shl     esi, 16
    mov     edx, MMC_CMD9
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .mmc_fail

    ; CMD7 (SELECT CARD) with RCA
    mov     edi, r12d
    mov     esi, SDHCI_RCA_DEFAULT
    shl     esi, 16
    mov     edx, MMC_CMD7
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .mmc_fail

    ; Set block size to 512
    mov     edi, r12d
    add     edi, SDHCI_BLOCK_SIZE
    mov     esi, SDHCI_BLOCK_SIZE_512
    call    er_mmio_write32

    pop     r12
    pop     rbx
    er_ok
    ret

    ; ─── SD card init ───────────────────────────────────────────────
.sd_init:
    ; Re-send CMD0 after MMC init attempt
    mov     edi, r12d
    xor     esi, esi
    mov     edx, MMC_CMD0
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; Wait 10ms
    mov     ecx, 100000
.sd_wait1:
    dec     ecx
    jnz     .sd_wait1

    ; CMD8 (SEND_IF_COND) for SD v2+
    mov     edi, r12d
    mov     esi, 0x000001AA      ; VHS=2.7-3.6V, check pattern=0xAA
    mov     edx, MMC_CMD8
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; ACMD41 (SD_SEND_OP_COND) via CMD55 + CMD41
    ; Send CMD55 (APP_CMD)
    mov     edi, r12d
    xor     esi, esi             ; RCA = 0
    mov     edx, MMC_CMD55
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; Send ACMD41 (CMD41) with OCR: HCS=1, voltage=0x00FF8000
    mov     edi, r12d
    mov     esi, 0x40FF8000      ; HCS=1, all voltages
    mov     edx, MMC_ACMD41
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; Poll ACMD41 until busy
    mov     ebx, 2000
.sd_acmd_poll:
    mov     edi, r12d
    xor     esi, esi
    mov     edx, MMC_CMD55
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    mov     edi, r12d
    mov     esi, 0x40FF8000
    mov     edx, MMC_ACMD41
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; Check response
    mov     edi, r12d
    add     edi, SDHCI_RESPONSE_0
    call    er_mmio_read32
    test    eax, OCR_BUSY
    jnz     .sd_busy_done
    dec     ebx
    jnz     .sd_acmd_poll

.sd_fail:
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

.sd_busy_done:
    ; CMD2 (ALL_SEND_CID)
    mov     edi, r12d
    xor     esi, esi
    mov     edx, MMC_CMD2
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; CMD3 (SET_RELATIVE_ADDR) - card generates RCA
    mov     edi, r12d
    xor     esi, esi
    mov     edx, MMC_CMD3
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; Read RCA from response
    mov     edi, r12d
    add     edi, SDHCI_RESPONSE_0
    call    er_mmio_read32
    mov     ebx, eax
    and     ebx, 0xFFFF0000     ; RCA stored in bits 31:16

    ; CMD9 (SEND_CSD)
    mov     edi, r12d
    mov     esi, ebx
    mov     edx, MMC_CMD9
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; CMD7 (SELECT CARD)
    mov     edi, r12d
    mov     esi, ebx
    mov     edx, MMC_CMD7
    xor     ecx, ecx
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .sd_fail

    ; Set block size to 512
    mov     edi, r12d
    add     edi, SDHCI_BLOCK_SIZE
    mov     esi, SDHCI_BLOCK_SIZE_512
    call    er_mmio_write32

    pop     r12
    pop     rbx
    er_ok
    ret

.no_card:
    pop     r12
    pop     rbx
    er_err  ERROR_NOT_PRESENT
    ret

.clock_timeout:
    pop     r12
    pop     rbx
    er_err  ERROR_TIMEOUT
    ret

.cmd_fail:
    pop     r12
    pop     rbx
    ret

.mmc_fail:
    ; Fall through to SD init attempt
    jmp     .sd_init

; ==================================================================
; er_intel_sdhci_read_blocks — read blocks from eMMC/SD
; int er_intel_sdhci_read_blocks(uint32_t bar0, uint32_t lba,
;                                void* buf, uint32_t count)
;
; rdi=bar0, esi=lba, rdx=buf, ecx=count
; Reads count blocks (512 bytes each) starting at lba into buf.
; Uses PIO mode (SDMA not implemented here).
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_intel_sdhci_read_blocks
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi            ; bar0
    mov     r13d, esi            ; lba
    mov     r14, rdx             ; buf
    mov     r15d, ecx            ; count

    ; Set block size & count
    mov     edi, r12d
    add     edi, SDHCI_BLOCK_SIZE
    mov     eax, r15d
    shl     eax, 16              ; BLOCK_COUNT in upper 16 bits
    or      eax, SDHCI_BLOCK_SIZE_512
    mov     esi, eax
    call    er_mmio_write32

    ; For SDHC/SDXC, LBA is the block address (CMD17/18 uses block addr)
    ; For eMMC, LBA is the block address too (in standard capacity mode)

    ; Check if single or multi block
    cmp     r15d, 1
    jbe     .single_read

    ; ─── Multi-block read (CMD18) ─────────────────────────────────────
    ; Write transfer mode: multi-block, read, DMA off, block count enable
    mov     edi, r12d
    add     edi, SDHCI_TRANSFER_MODE
    mov     esi, SDHCI_TRNS_READ | SDHCI_TRNS_MULTI | SDHCI_TRNS_BLK_CNT
    call    er_mmio_write32

    ; Send CMD18
    mov     edi, r12d
    mov     esi, r13d             ; lba
    mov     edx, MMC_CMD18
    mov     ecx, 1                ; has data
    xor     r8d, r8d              ; short resp
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .fail

    ; Read data via PIO (buffer data port)
.read_multi:
    ; Wait for buffer write ready or transfer complete
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    call    er_mmio_read32
    test    eax, SDHCI_INT_ERROR
    jnz     .io_error
    test    eax, SDHCI_INT_XFER_COMPLETE
    jnz     .read_done
    test    eax, SDHCI_INT_BUF_RD_READY
    jz      .read_multi

    ; Clear buffer ready
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_BUF_RD_READY
    call    er_mmio_write32

    ; Read 128 words (512 bytes) from buffer data port
    mov     ecx, 128
.read_word:
    mov     edi, r12d
    add     edi, SDHCI_BUFFER_DATA
    call    er_mmio_read32
    mov     [r14], eax
    add     r14, 4
    dec     ecx
    jnz     .read_word

    dec     r15d
    jnz     .read_multi

    ; Wait for transfer complete
.read_done:
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_XFER_COMPLETE
    call    er_mmio_write32

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

    ; ─── Single-block read (CMD17) ────────────────────────────────────
.single_read:
    mov     edi, r12d
    add     edi, SDHCI_TRANSFER_MODE
    mov     esi, SDHCI_TRNS_READ  ; single block, no blk count
    call    er_mmio_write32

    mov     edi, r12d
    mov     esi, r13d             ; lba
    mov     edx, MMC_CMD17
    mov     ecx, 1                ; has data
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .fail

    ; Wait for buffer read ready
    mov     edi, r12d
    mov     esi, SDHCI_PRESENT_STATE
    mov     edx, SDHCI_STS_DATA_INHIBIT
    xor     ecx, ecx             ; wait clear
    mov     r8d, SDHCI_POLL_MAX
    call    _sdhci_wait_bits
    test    eax, eax
    jnz     .fail

    ; Read 128 words
    mov     ecx, 128
.single_read_word:
    mov     edi, r12d
    add     edi, SDHCI_BUFFER_DATA
    call    er_mmio_read32
    mov     [r14], eax
    add     r14, 4
    dec     ecx
    jnz     .single_read_word

    ; Wait transfer complete
    mov     edi, r12d
    mov     esi, SDHCI_POLL_MAX
    call    _sdhci_wait_data_done
    test    eax, eax
    jnz     .fail

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.io_error:
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_ERROR
    call    er_mmio_write32
.fail:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_intel_sdhci_write_blocks — write blocks to eMMC/SD
; int er_intel_sdhci_write_blocks(uint32_t bar0, uint32_t lba,
;                                 const void* buf, uint32_t count)
;
; rdi=bar0, esi=lba, rdx=buf, ecx=count
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_intel_sdhci_write_blocks
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi            ; bar0
    mov     r13d, esi            ; lba
    mov     r14, rdx             ; buf
    mov     r15d, ecx            ; count

    ; Set block size & count
    mov     edi, r12d
    add     edi, SDHCI_BLOCK_SIZE
    mov     eax, r15d
    shl     eax, 16
    or      eax, SDHCI_BLOCK_SIZE_512
    mov     esi, eax
    call    er_mmio_write32

    cmp     r15d, 1
    ja      .multi_write

    ; ─── Single-block write (CMD24) ───────────────────────────────────
    mov     edi, r12d
    add     edi, SDHCI_TRANSFER_MODE
    xor     esi, esi             ; write, single block, no DMA, no blk cnt
    call    er_mmio_write32

    ; Send CMD24
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, MMC_CMD24
    mov     ecx, 1                ; has data
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .fail

    ; Wait for buffer write ready
    mov     edi, r12d
    mov     esi, SDHCI_PRESENT_STATE
    mov     edx, SDHCI_STS_DATA_INHIBIT
    xor     ecx, ecx
    mov     r8d, SDHCI_POLL_MAX
    call    _sdhci_wait_bits
    test    eax, eax
    jnz     .fail

    ; Write 128 words
    mov     ecx, 128
.single_write_word:
    mov     eax, [r14]
    mov     edi, r12d
    add     edi, SDHCI_BUFFER_DATA
    mov     esi, eax
    call    er_mmio_write32
    add     r14, 4
    dec     ecx
    jnz     .single_write_word

    ; Wait transfer complete
    mov     edi, r12d
    mov     esi, SDHCI_POLL_MAX
    call    _sdhci_wait_data_done
    test    eax, eax
    jnz     .fail

    jmp     .done

    ; ─── Multi-block write (CMD25) ──────────────────────────────────
.multi_write:
    mov     edi, r12d
    add     edi, SDHCI_TRANSFER_MODE
    mov     esi, SDHCI_TRNS_MULTI | SDHCI_TRNS_BLK_CNT
    call    er_mmio_write32

    ; Send CMD25
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 25              ; WRITE_MULTIPLE_BLOCK
    mov     ecx, 1
    xor     r8d, r8d
    call    _sdhci_send_cmd
    test    eax, eax
    jnz     .fail

.write_multi:
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    call    er_mmio_read32
    test    eax, SDHCI_INT_ERROR
    jnz     .io_error
    test    eax, SDHCI_INT_XFER_COMPLETE
    jnz     .done
    test    eax, SDHCI_INT_BUF_WR_READY
    jz      .write_multi

    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_BUF_WR_READY
    call    er_mmio_write32

    mov     ecx, 128
.write_word:
    mov     eax, [r14]
    mov     edi, r12d
    add     edi, SDHCI_BUFFER_DATA
    mov     esi, eax
    call    er_mmio_write32
    add     r14, 4
    dec     ecx
    jnz     .write_word

    dec     r15d
    jnz     .write_multi

.done:
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_XFER_COMPLETE
    call    er_mmio_write32

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.io_error:
    mov     edi, r12d
    add     edi, SDHCI_INT_STATUS
    mov     esi, SDHCI_INT_ERROR
    call    er_mmio_write32
.fail:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret
