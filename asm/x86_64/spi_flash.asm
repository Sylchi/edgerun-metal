; EdgeRun AMD FCH SPI flash controller driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Controls the AMD FCH SPI flash controller found on Phoenix/FP4
; (Ryzen 7040 series) at MMIO 0xFEC10000.
;
; V2 controller (AMDI0062): opcode at SPI_CMD_CODE (0x45),
; execute via SPI_CMD_TRIGGER (0x47).
;
; Flash chip targets: Winbond W25Q256JW, GigaDevice GD25LR256EYIG.
; Polling mode only — no interrupts.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

; ─── AMD FCH SPI MMIO base (Phoenix/7840U) ──────────────────────
%define SPI_MMIO_BASE          0xFEC10000

; ─── V2 Register Offsets ─────────────────────────────────────────
%define SPI_CNTRL0             0x00
%define SPI_CNTRL1             0x0C
%define SPI_ALT_CS_REG         0x1D
%define SPI100_ENABLE          0x20
%define SPI_CMD_CODE           0x45
%define SPI_CMD_TRIGGER        0x47
%define SPI_TX_BYTE_COUNT      0x48
%define SPI_RX_BYTE_COUNT      0x4B
%define SPI_STATUS             0x4C
%define SPI_ADDR32CTRL_REG     0x50
%define SPI_FIFO_BASE          0x80

; SPI_STATUS bits
%define SPI_STATUS_BUSY        (1 << 31)

; SPI_CMD_TRIGGER bits
%define SPI_EXECUTE_CMD        (1 << 7)

; SPI timeout (spin iterations)
%define SPI_TIMEOUT            1000000

; ─── Flash Chip Commands ─────────────────────────────────────────
%define CMD_WRITE_ENABLE       0x06
%define CMD_WRITE_DISABLE      0x04
%define CMD_READ_STATUS        0x05
%define CMD_READ_STATUS2       0x35
%define CMD_JEDEC_ID           0x9F
%define CMD_READ_DATA          0x03
%define CMD_PAGE_PROGRAM       0x02
%define CMD_SECTOR_ERASE_4K    0x20
%define CMD_CHIP_ERASE         0xC7
%define CMD_ENABLE_4BYTE_ADDR  0xB7

; Status register bits
%define SR1_BUSY               (1 << 0)
%define SR1_WEL                (1 << 1)

; Error codes
%define ERROR_SPI_TIMEOUT      30
%define ERROR_SPI_ROM_ARMOR    31
%define JEDEC_DENSITY_32MB     0x19

SECTION .data
_spi_addr_mode: db 0      ; 1 = 3-byte, 2 = 4-byte

SECTION .text

; ==================================================================
; _spi_wait_busy — wait for controller idle
; ==================================================================
; In:   r12 = MMIO base
; Out:  edx = 0 on success, ERROR_SPI_TIMEOUT on timeout
; Clobbers: rdi, r13d, eax, ecx
_spi_wait_busy:
    mov     r13d, SPI_STATUS
    mov     ecx, SPI_TIMEOUT
.loop:
    lea     rdi, [r12 + r13]
    mov     eax, [rdi]
    test    eax, SPI_STATUS_BUSY
    jz      .ready
    dec     ecx
    jnz     .loop
    er_err  ERROR_SPI_TIMEOUT
    er_ret
.ready:
    er_ok
    er_ret

; ==================================================================
; _spi_cmd — opcode only, no address/data
; ==================================================================
; In:   r12 = MMIO base, al = opcode
; Out:  edx = 0 on success
; Clobbers: rdi, r13d, ecx
_spi_cmd:
    call    _spi_wait_busy
    test    edx, edx
    jnz     .done
    mov     r13d, SPI_TX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     byte [rdi], 0
    mov     r13d, SPI_RX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     byte [rdi], 0
    mov     r13d, SPI_CMD_CODE
    lea     rdi, [r12 + r13]
    mov     [rdi], al
    mov     r13d, SPI_CMD_TRIGGER
    lea     rdi, [r12 + r13]
    mov     byte [rdi], SPI_EXECUTE_CMD
    call    _spi_wait_busy
.done:
    er_ret

; ==================================================================
; _spi_cmd_read — opcode + RX (no TX)
; ==================================================================
; In:   r12 = MMIO base, al = opcode, bl = RX count, rdi = RX buf
; Out:  edx = 0 on success
; Clobbers: rdi, rsi, r13d, ecx
_spi_cmd_read:
    push    r9
    mov     r9, rdi

    call    _spi_wait_busy
    test    edx, edx
    jnz     .done

    movzx   ecx, bl
    mov     r13d, SPI_TX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     byte [rdi], 0
    mov     r13d, SPI_RX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     [rdi], cl
    mov     r13d, SPI_CMD_CODE
    lea     rdi, [r12 + r13]
    mov     [rdi], al
    mov     r13d, SPI_CMD_TRIGGER
    lea     rdi, [r12 + r13]
    mov     byte [rdi], SPI_EXECUTE_CMD

    call    _spi_wait_busy
    test    edx, edx
    jnz     .done

    movzx   ecx, bl
    lea     rsi, [r12 + SPI_FIFO_BASE]
    mov     rdi, r9
    cld
    rep     movsb

.done:
    pop     r9
    er_ret

; ==================================================================
; _spi_addr_read — opcode + address (TX) + RX bytes
; ==================================================================
; In:   r12 = MMIO base
;       al  = opcode
;       ah  = address byte count (3 or 4)
;       bl  = RX byte count
;       edx = flash address
;       rdi = RX buffer
; Out:  edx = 0 on success
; Clobbers: rdi, rsi, r13d, ecx, eax
_spi_addr_read:
    push    r9
    push    r10
    mov     r9, rdi
    mov     r10d, edx

    call    _spi_wait_busy
    test    edx, edx
    jnz     .done

    movzx   ecx, ah
    mov     r13d, SPI_TX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     [rdi], cl
    movzx   ecx, bl
    mov     r13d, SPI_RX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     [rdi], cl
    mov     r13d, SPI_CMD_CODE
    lea     rdi, [r12 + r13]
    mov     [rdi], al

    ; Write address bytes to FIFO
    mov     r13d, SPI_FIFO_BASE
    lea     rdi, [r12 + r13]
    mov     eax, r10d
    cmp     ah, 4
    jne     .a3
    shr     eax, 24
    mov     byte [rdi], al
    inc     rdi
    mov     eax, r10d
    shr     eax, 16
    mov     byte [rdi], al
    inc     rdi
    mov     eax, r10d
    shr     eax, 8
    mov     byte [rdi], al
    inc     rdi
    mov     byte [rdi], r10b
    jmp     .go
.a3:
    shr     eax, 16
    mov     byte [rdi], al
    inc     rdi
    mov     eax, r10d
    shr     eax, 8
    mov     byte [rdi], al
    inc     rdi
    mov     byte [rdi], r10b

.go:
    mov     r13d, SPI_CMD_TRIGGER
    lea     rdi, [r12 + r13]
    mov     byte [rdi], SPI_EXECUTE_CMD

    call    _spi_wait_busy
    test    edx, edx
    jnz     .done

    movzx   ecx, bl
    test    ecx, ecx
    jz      .done

    movzx   edx, ah
    lea     rsi, [r12 + rdx + SPI_FIFO_BASE]
    mov     rdi, r9
    cld
    rep     movsb

.done:
    pop     r10
    pop     r9
    er_ret

; ==================================================================
; _spi_addr_write — opcode + address (TX) + data (TX), no RX
; ==================================================================
; In:   r12 = MMIO base
;       al  = opcode
;       ah  = address byte count (3 or 4)
;       bl  = data byte count
;       edx = flash address
;       rsi = data buffer
; Out:  edx = 0 on success
; Clobbers: rdi, r13d, ecx, eax
_spi_addr_write:
    push    r9
    push    r10
    mov     r9, rsi
    mov     r10d, edx

    call    _spi_wait_busy
    test    edx, edx
    jnz     .done

    movzx   ecx, ah
    add     cl, bl
    mov     r13d, SPI_TX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     [rdi], cl
    mov     r13d, SPI_RX_BYTE_COUNT
    lea     rdi, [r12 + r13]
    mov     byte [rdi], 0
    mov     r13d, SPI_CMD_CODE
    lea     rdi, [r12 + r13]
    mov     [rdi], al

    ; Write address bytes + data bytes to FIFO
    mov     r13d, SPI_FIFO_BASE
    lea     rdi, [r12 + r13]
    mov     eax, r10d
    cmp     ah, 4
    jne     .a3
    shr     eax, 24
    mov     byte [rdi], al
    inc     rdi
    mov     eax, r10d
    shr     eax, 16
    mov     byte [rdi], al
    inc     rdi
    mov     eax, r10d
    shr     eax, 8
    mov     byte [rdi], al
    inc     rdi
    mov     byte [rdi], r10b
    inc     rdi
    jmp     .data
.a3:
    shr     eax, 16
    mov     byte [rdi], al
    inc     rdi
    mov     eax, r10d
    shr     eax, 8
    mov     byte [rdi], al
    inc     rdi
    mov     byte [rdi], r10b
    inc     rdi

.data:
    movzx   ecx, bl
    test    ecx, ecx
    jz      .go
    mov     rsi, r9
    cld
    rep     movsb

.go:
    mov     r13d, SPI_CMD_TRIGGER
    lea     rdi, [r12 + r13]
    mov     byte [rdi], SPI_EXECUTE_CMD

    call    _spi_wait_busy

.done:
    pop     r10
    pop     r9
    er_ret

; ==================================================================
; er_spi_flash_probe
; ==================================================================
; Out:  eax = JEDEC ID (24-bit), edx = 0 on success
er_fn er_spi_flash_probe
    push    r12
    push    r13

    mov     r12, SPI_MMIO_BASE

    mov     eax, [r12 + SPI_CNTRL0]
    cmp     eax, 0xFFFFFFFF
    jne     .ctrl_ok
    mov     eax, [r12 + SPI_CNTRL1]
    cmp     eax, 0xFFFFFFFF
    jne     .ctrl_ok
    er_err  ERROR_SPI_ROM_ARMOR
    jmp     .done

.ctrl_ok:
    lea     rdi, [r12 + SPI100_ENABLE]
    mov     al, [rdi]
    test    al, 1
    jnz     .spi100_ok
    mov     byte [rdi], 1
.spi100_ok:

    sub     rsp, 8
    mov     rdi, rsp
    mov     al, CMD_JEDEC_ID
    mov     bl, 3
    call    _spi_cmd_read
    test    edx, edx
    jnz     .err

    movzx   eax, byte [rsp]
    shl     eax, 16
    movzx   ecx, byte [rsp + 1]
    shl     ecx, 8
    or      eax, ecx
    movzx   ecx, byte [rsp + 2]
    or      eax, ecx

    movzx   ecx, byte [rsp + 2]
    cmp     cl, JEDEC_DENSITY_32MB
    jae     .four_byte
    mov     byte [_spi_addr_mode], 1
    add     rsp, 8
    jmp     .done

.four_byte:
    mov     byte [_spi_addr_mode], 2
    mov     al, CMD_ENABLE_4BYTE_ADDR
    call    _spi_cmd
    lea     rdi, [r12 + SPI_ADDR32CTRL_REG]
    mov     byte [rdi], 1
    add     rsp, 8
    jmp     .done

.err:
    add     rsp, 8
.done:
    pop     r13
    pop     r12
    er_ret

; ==================================================================
; er_spi_flash_read
; ==================================================================
; In:   edi = flash address, esi = buffer, edx = byte count
; Out:  edx = 0 on success
er_fn er_spi_flash_read
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r14d, edi       ; flash address
    mov     r15, rsi        ; buffer
    mov     r13d, edx       ; byte count
    mov     r12, SPI_MMIO_BASE

    mov     edx, r14d       ; flash address for _spi_addr_read
    mov     rdi, r15        ; RX buffer
    mov     al, CMD_READ_DATA
    mov     bl, r13b        ; RX count

    cmp     byte [_spi_addr_mode], 2
    jne     .r3
    mov     ah, 4
    call    _spi_addr_read
    jmp     .done
.r3:
    mov     ah, 3
    call    _spi_addr_read
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret

; ==================================================================
; er_spi_flash_write_enable
; ==================================================================
er_fn er_spi_flash_write_enable
    push    r12
    mov     r12, SPI_MMIO_BASE
    mov     al, CMD_WRITE_ENABLE
    call    _spi_cmd
    pop     r12
    er_ret

; ==================================================================
; er_spi_flash_wait_ready
; ==================================================================
er_fn er_spi_flash_wait_ready
    push    r12
    push    r14

    mov     r12, SPI_MMIO_BASE
    mov     r14d, SPI_TIMEOUT
.loop:
    sub     rsp, 4
    mov     rdi, rsp
    mov     al, CMD_READ_STATUS
    mov     bl, 1
    call    _spi_cmd_read
    test    edx, edx
    jnz     .err
    movzx   eax, byte [rsp]
    add     rsp, 4
    test    al, SR1_BUSY
    jz      .ready
    dec     r14d
    jnz     .loop
    er_err  ERROR_SPI_TIMEOUT
    jmp     .done
.err:
    add     rsp, 4
    jmp     .done
.ready:
    er_ok
.done:
    pop     r14
    pop     r12
    er_ret

; ==================================================================
; er_spi_flash_erase_sector
; ==================================================================
; In:   edi = flash address
er_fn er_spi_flash_erase_sector
    push    r12
    push    r13

    mov     r13d, edi
    mov     r12, SPI_MMIO_BASE

    call    er_spi_flash_wait_ready
    test    edx, edx
    jnz     .done

    call    er_spi_flash_write_enable
    test    edx, edx
    jnz     .done

    mov     edx, r13d
    cmp     byte [_spi_addr_mode], 2
    jne     .erase_3

    mov     al, CMD_SECTOR_ERASE_4K
    mov     ah, 4
    xor     bl, bl
    xor     esi, esi
    call    _spi_addr_write
    jmp     .done

.erase_3:
    mov     al, CMD_SECTOR_ERASE_4K
    mov     ah, 3
    xor     bl, bl
    xor     esi, esi
    call    _spi_addr_write

.done:
    pop     r13
    pop     r12
    er_ret

; ==================================================================
; er_spi_flash_page_program
; ==================================================================
; In:   edi = flash addr, rsi = data, edx = count (1-256)
er_fn er_spi_flash_page_program
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r14d, edi
    mov     r15, rsi
    mov     r13d, edx
    mov     r12, SPI_MMIO_BASE

    call    er_spi_flash_wait_ready
    test    edx, edx
    jnz     .done

    call    er_spi_flash_write_enable
    test    edx, edx
    jnz     .done

    mov     edx, r14d
    mov     rsi, r15
    mov     bl, r13b
    cmp     byte [_spi_addr_mode], 2
    jne     .prog_3

    mov     al, CMD_PAGE_PROGRAM
    mov     ah, 4
    call    _spi_addr_write
    jmp     .done

.prog_3:
    mov     al, CMD_PAGE_PROGRAM
    mov     ah, 3
    call    _spi_addr_write

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret
