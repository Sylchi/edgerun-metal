; EdgeRun Synopsys DesignWare I2C (DW_apb_i2c) master driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Controls the Synopsys DesignWare I2C controller found in the AMD FCH
; on Framework AMD 7840U laptops (AMDI0010 ACPI HID, MMIO at 0xFEDC*000).
;
; Polling-mode master only — no interrupts, no slave mode.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_mmio_read32
extern er_mmio_write32

; ─── DW I2C register offsets (from MMIO base) ──────────────────────
%define DW_IC_CON              0x00
%define DW_IC_TAR              0x04
%define DW_IC_SAR              0x08
%define DW_IC_DATA_CMD         0x10
%define DW_IC_SS_SCL_HCNT     0x14
%define DW_IC_SS_SCL_LCNT     0x18
%define DW_IC_FS_SCL_HCNT     0x1c
%define DW_IC_FS_SCL_LCNT     0x20
%define DW_IC_INTR_STAT       0x2c
%define DW_IC_INTR_MASK       0x30
%define DW_IC_RAW_INTR_STAT   0x34
%define DW_IC_RX_TL           0x38
%define DW_IC_TX_TL           0x3c
%define DW_IC_CLR_INTR        0x40
%define DW_IC_CLR_TX_ABRT     0x54
%define DW_IC_CLR_STOP_DET    0x60
%define DW_IC_ENABLE          0x6c
%define DW_IC_STATUS          0x70
%define DW_IC_TXFLR           0x74
%define DW_IC_RXFLR           0x78
%define DW_IC_SDA_HOLD        0x7c
%define DW_IC_TX_ABRT_SOURCE  0x80
%define DW_IC_ENABLE_STATUS   0x9c
%define DW_IC_COMP_TYPE       0xfc

; IC_CON bits
%define DW_CON_MASTER         (1 << 0)
%define DW_CON_SPEED_STD      0x00
%define DW_CON_SPEED_FAST     (1 << 2)
%define DW_CON_SPEED_HIGH     (2 << 2)
%define DW_CON_RESTART_EN     (1 << 6)
%define DW_CON_SLAVE_DISABLE  (1 << 7)

; IC_STATUS bits
%define DW_STATUS_ACTIVITY    (1 << 0)
%define DW_STATUS_TFNF        (1 << 1)
%define DW_STATUS_TFE         (1 << 2)
%define DW_STATUS_RFNE        (1 << 3)
%define DW_STATUS_RFF         (1 << 4)

; IC_DATA_CMD bits
%define DW_CMD_READ           (1 << 8)
%define DW_CMD_STOP           (1 << 9)

; IC_RAW_INTR_STAT bits
%define DW_INTR_TX_ABRT       (1 << 6)
%define DW_INTR_STOP_DET      (1 << 9)

; Timeout (spin iterations)
%define DW_I2C_TIMEOUT        2000000

; COMP_TYPE magic value for DesignWare I2C
%define DW_IC_COMP_TYPE_VAL   0x44570140

; Default timing for 400 kHz fast mode (50 MHz input clock assumption)
%define DW_FS_SCL_HCNT_DEF   60
%define DW_FS_SCL_LCNT_DEF  100

; MMIO base for touchpad's I2C bus on Framework AMD 7840U
%define DW_I2CB_MMIO          0xFEDC3000

; Touchpad I2C address
%define DW_TPAD_ADDR          0x2C

; ==================================================================
; MMIO read/write helpers
; ==================================================================
; In:   r12 = base, r13d = offset
; Out:  eax = value
; Clobbers: rdi
_dw_read:
    lea     rdi, [r12 + r13]
    call    er_mmio_read32
    er_ok
    er_ret

; In:   r12 = base, r13d = offset, eax = value
; Clobbers: rdi, rsi
_dw_write:
    lea     rdi, [r12 + r13]
    mov     esi, eax
    call    er_mmio_write32
    er_ok
    er_ret

; Wait for TX FIFO not full
; In:   r12 = base
; Out:  edx = 0 ready, ERROR_TIMEOUT on timeout
_dw_wait_tfnf:
    mov     r13d, DW_IC_STATUS
    mov     ecx, DW_I2C_TIMEOUT
.loop:
    call    _dw_read
    test    eax, DW_STATUS_TFNF
    jnz     .ready
    pause
    dec     ecx
    jnz     .loop
    xor     eax, eax
    er_err  ERROR_TIMEOUT
    er_ret
.ready:
    xor     eax, eax
    er_ok
    er_ret

; Wait for TX FIFO empty
_dw_wait_tx_empty:
    mov     r13d, DW_IC_STATUS
    mov     ecx, DW_I2C_TIMEOUT
.loop:
    call    _dw_read
    test    eax, DW_STATUS_TFE
    jnz     .done
    pause
    dec     ecx
    jnz     .loop
    xor     eax, eax
    er_err  ERROR_TIMEOUT
    er_ret
.done:
    xor     eax, eax
    er_ok
    er_ret

; Wait for RX FIFO not empty
_dw_wait_rfne:
    mov     r13d, DW_IC_STATUS
    mov     ecx, DW_I2C_TIMEOUT
.loop:
    call    _dw_read
    test    eax, DW_STATUS_RFNE
    jnz     .ready
    pause
    dec     ecx
    jnz     .loop
    xor     eax, eax
    er_err  ERROR_TIMEOUT
    er_ret
.ready:
    xor     eax, eax
    er_ok
    er_ret

; Check and clear TX abort
; In:   r12 = base
; Out:  eax = 1 if aborted, 0 otherwise
_dw_check_abort:
    mov     r13d, DW_IC_RAW_INTR_STAT
    call    _dw_read
    test    eax, DW_INTR_TX_ABRT
    jz      .no_abort
    mov     r13d, DW_IC_CLR_TX_ABRT
    call    _dw_read
    mov     eax, 1
    er_ok
    er_ret
.no_abort:
    xor     eax, eax
    er_ok
    er_ret

; ─── HOSTED_TEST shadow buffer (unconditional) ────────────────────
section .bss
global er_dw_i2c_shadow
er_dw_i2c_shadow: resb 256
global er_dw_i2c_enabled, er_dw_i2c_tar
er_dw_i2c_enabled: resq 1
er_dw_i2c_tar:     resq 1

SECTION .text

; ==================================================================
; er_dw_i2c_probe — check if DesignWare I2C controller exists at base
; int er_dw_i2c_probe(uint64_t mmio_base)
; Returns: eax = 1 if present, 0 if absent
; ==================================================================
er_fn er_dw_i2c_probe
%ifndef HOSTED_TEST
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13d, DW_IC_COMP_TYPE
    call    _dw_read
    cmp     eax, DW_IC_COMP_TYPE_VAL
    sete    al
    movzx   eax, al
    pop     r13
    pop     r12
    er_ok
    er_ret
%else
    cmp     qword [er_dw_i2c_enabled], 0
    sete    al
    movzx   eax, al
    er_ok
    er_ret
%endif

; ==================================================================
; er_dw_i2c_init — initialize DW I2C controller in master mode
; int er_dw_i2c_init(uint64_t mmio_base, uint32_t speed_khz)
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_dw_i2c_init
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r14d, esi

%ifndef HOSTED_TEST
    ; Disable controller
    xor     eax, eax
    mov     r13d, DW_IC_ENABLE
    call    _dw_write

    mov     ecx, DW_I2C_TIMEOUT
.wait_dis:
    mov     r13d, DW_IC_ENABLE_STATUS
    call    _dw_read
    test    eax, 1
    jz      .disabled
    pause
    dec     ecx
    jnz     .wait_dis
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    jmp     .out

.disabled:
    mov     eax, DW_CON_MASTER | DW_CON_RESTART_EN | DW_CON_SLAVE_DISABLE
    cmp     r14d, 400
    jae     .fast
    mov     r13d, DW_IC_CON
    call    _dw_write
    mov     eax, 300
    mov     r13d, DW_IC_SS_SCL_HCNT
    call    _dw_write
    mov     eax, 400
    mov     r13d, DW_IC_SS_SCL_LCNT
    call    _dw_write
    jmp     .timing_done

.fast:
    or      eax, DW_CON_SPEED_FAST
    mov     r13d, DW_IC_CON
    call    _dw_write
    mov     eax, DW_FS_SCL_HCNT_DEF
    mov     r13d, DW_IC_FS_SCL_HCNT
    call    _dw_write
    mov     eax, DW_FS_SCL_LCNT_DEF
    mov     r13d, DW_IC_FS_SCL_LCNT
    call    _dw_write

.timing_done:
    xor     eax, eax
    mov     r13d, DW_IC_RX_TL
    call    _dw_write
    mov     r13d, DW_IC_TX_TL
    call    _dw_write
    mov     eax, 8
    mov     r13d, DW_IC_SDA_HOLD
    call    _dw_write
    mov     r13d, DW_IC_CLR_INTR
    call    _dw_read
    mov     eax, 1
    mov     r13d, DW_IC_ENABLE
    call    _dw_write

    mov     ecx, DW_I2C_TIMEOUT
.wait_en:
    mov     r13d, DW_IC_ENABLE_STATUS
    call    _dw_read
    test    eax, 1
    jnz     .enabled
    pause
    dec     ecx
    jnz     .wait_en
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    jmp     .out

.enabled:
%endif
    xor     eax, eax
    er_ok
.out:
    pop     r14
    pop     r13
    pop     r12
    er_ret

; ==================================================================
; er_dw_i2c_set_target — set target slave address
; ==================================================================
er_fn er_dw_i2c_set_target
%ifndef HOSTED_TEST
    push    r12
    push    r13
    mov     r12, rdi
    movzx   eax, si
    and     eax, 0x7f
    mov     r13d, DW_IC_TAR
    call    _dw_write
    pop     r13
    pop     r12
%endif
    er_ok
    er_ret

; ==================================================================
; er_dw_i2c_write_bytes — write bytes to I2C bus
; int er_dw_i2c_write_bytes(uint64_t mmio_base, const uint8_t* buf,
;                           uint32_t len)
; Returns: eax = 0 on success, -1 on timeout/abort
; ==================================================================
er_fn er_dw_i2c_write_bytes
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r14, rsi
    mov     r15d, edx

%ifndef HOSTED_TEST
    test    r15d, r15d
    jz      .done_write

.loop_write:
    call    _dw_wait_tfnf
    test    edx, edx
    jnz     .fail

    call    _dw_check_abort
    test    eax, eax
    jnz     .fail

    movzx   eax, byte [r14]
    mov     r13d, DW_IC_DATA_CMD
    call    _dw_write

    inc     r14
    dec     r15d
    jnz     .loop_write

.done_write:
    call    _dw_wait_tx_empty
    test    edx, edx
    jnz     .fail

    mov     ecx, DW_I2C_TIMEOUT
.stop_wait:
    mov     r13d, DW_IC_RAW_INTR_STAT
    call    _dw_read
    test    eax, DW_INTR_STOP_DET
    jnz     .stop_done
    pause
    dec     ecx
    jnz     .stop_wait
    jmp     .fail

.stop_done:
    mov     r13d, DW_IC_CLR_STOP_DET
    call    _dw_read
%endif

    xor     eax, eax
    er_ok
    jmp     .out

.fail:
    mov     eax, -1
    er_err  ERROR_IO
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret

; ==================================================================
; er_dw_i2c_read_bytes — read bytes from I2C bus
; int er_dw_i2c_read_bytes(uint64_t mmio_base, uint8_t* buf,
;                          uint32_t len)
; Returns: eax = 0 on success, -1 on timeout/abort
; ==================================================================
er_fn er_dw_i2c_read_bytes
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx
    mov     r12, rdi
    mov     r14, rsi
    mov     r15d, edx

%ifndef HOSTED_TEST
    test    r15d, r15d
    jz      .done_read

    xor     ebx, ebx
.read_cmd_loop:
    cmp     ebx, r15d
    jae     .read_data_loop

    call    _dw_wait_tfnf
    test    edx, edx
    jnz     .fail

    mov     eax, DW_CMD_READ
    lea     ecx, [ebx + 1]
    cmp     ecx, r15d
    jb      .no_stop
    or      eax, DW_CMD_STOP
.no_stop:
    mov     r13d, DW_IC_DATA_CMD
    call    _dw_write

    inc     ebx
    jmp     .read_cmd_loop

.read_data_loop:
    xor     ebx, ebx
.read_next:
    cmp     ebx, r15d
    jae     .done_read

    call    _dw_wait_rfne
    test    edx, edx
    jnz     .fail

    mov     r13d, DW_IC_DATA_CMD
    call    _dw_read
    mov     byte [r14 + rbx], al
    inc     ebx
    jmp     .read_next
%endif

.done_read:
    xor     eax, eax
    er_ok
    jmp     .out

.fail:
    mov     eax, -1
    er_err  ERROR_IO
.out:
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret

; ==================================================================
; er_dw_i2c_xfer — combined write-then-read transfer
; int er_dw_i2c_xfer(uint64_t mmio_base, uint8_t addr,
;                    const uint8_t* wbuf, uint32_t wlen,
;                    uint8_t* rbuf, uint32_t rlen)
; Args: rdi=base, sil=addr, rdx=wbuf, ecx=wlen, r8=rbuf, r9d=rlen
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_dw_i2c_xfer
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx
    mov     r12, rdi
    movzx   ebx, sil
    mov     r14, rdx
    mov     r15d, ecx
    push    r8
    push    r9

%ifndef HOSTED_TEST
    movzx   eax, bl
    and     eax, 0x7f
    mov     r13d, DW_IC_TAR
    call    _dw_write

    mov     rdi, r12
    mov     rsi, r14
    mov     edx, r15d
    call    er_dw_i2c_write_bytes
    test    edx, edx
    jnz     .fail

    ; Read phase — access r8/r9 from their saved stack slots
    ; [rsp+0] = saved r9 (rlen), [rsp+8] = saved r8 (rbuf)
    mov     r9, [rsp]
    test    r9d, r9d
    jz      .done_xfer
    mov     r8, [rsp + 8]
    mov     rdi, r12
    mov     rsi, r8
    mov     edx, r9d
    call    er_dw_i2c_read_bytes
    test    edx, edx
    jnz     .fail
    jmp     .done_xfer

.fail:
    mov     eax, -1
    er_err  ERROR_IO
    add     rsp, 16
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret

.done_xfer:
%endif
    xor     eax, eax
    er_ok
    add     rsp, 16
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret
