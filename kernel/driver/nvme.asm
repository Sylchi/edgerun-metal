; EdgeRun NVMe driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "driver/pci_constants.inc"

extern er_pci_read32
extern er_mmio_read32
extern er_mmio_write32
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putdec32
extern er_serial_crlf

; NVMe controller MMIO registers (BAR0 offset, 32-bit access)
%define NVME_CAP_LO     0x00
%define NVME_CAP_HI     0x04
%define NVME_VS         0x08
%define NVME_CC         0x14
%define NVME_CSTS       0x1C
%define NVME_AQA        0x24
%define NVME_ASQ_LO     0x28
%define NVME_ASQ_HI     0x2C
%define NVME_ACQ_LO     0x30
%define NVME_ACQ_HI     0x34

; CC bits
%define CC_EN           (1 << 0)
%define CC_IOSQES_SHIFT 20
%define CC_IOCQES_SHIFT 16
%define CC_IOSQES_64B   (6 << CC_IOSQES_SHIFT)
%define CC_IOCQES_16B   (4 << CC_IOCQES_SHIFT)

; CSTS bits
%define CSTS_RDY        (1 << 0)

; Admin SQ tail doorbell offset from BAR0
%define SQ0TDBL         0x1000

; Admin command opcodes
%define NVME_ADM_IDENTIFY  0x06
%define IDENTIFY_CTRL      0x01

; Fixed buffer addresses (identity-mapped, safe range above kernel)
%define NVME_ADMIN_SQ   0x300000
%define NVME_ADMIN_CQ   0x301000
%define NVME_ID_BUF     0x302000
%define NVME_IO_CQ      0x303000       ; IO completion queue (4K)
%define NVME_IO_SQ      0x304000       ; IO submission queue (4K)
%define NVME_IO_BUF     0x305000       ; IO data buffer (4K)
%define NVME_SQ1TDBL    0x1008         ; SQ1 (QID=1) tail doorbell

SECTION .text

; ==================================================================
; er_nvme_probe — probe NVMe controller at PCI location
; int er_nvme_probe(uint8_t bus, uint8_t dev, uint8_t func,
;                   uint64_t* out_bar0)
;
; Reads BAR0, identifies BAR type (32/64 bit MMIO).
; Returns: eax = 0 on success, -1 on failure
;          *out_bar0 = physical BAR0 base address (masked)
; ==================================================================
er_fn er_nvme_probe
    push    r8
    push    r9
    push    r10

    mov     r8, rcx             ; out_bar0

    ; Save bus/dev/func in callee-saved regs
    push    rbx
    mov     ebx, edi            ; bus
    mov     r9d, esi            ; dev
    mov     r10d, edx           ; func

    ; Read VID/DID to verify device exists
    mov     rdi, rbx
    mov     rsi, r9
    mov     rdx, r10
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .no_dev

    ; Read BAR0
    mov     rdi, rbx
    mov     rsi, r9
    mov     rdx, r10
    mov     ecx, PCI_BAR0
    call    er_pci_read32
    mov     r11d, eax           ; raw BAR0 value

    ; Check BAR type: bit 0 = 0 for MMIO, bit 2 = 1 for 64-bit
    test    al, 1
    jz      .mmio_bar
    ; I/O BAR — not supported
    er_err  ERROR_UNSUPPORTED
    jmp     .out

.mmio_bar:
    test    al, 4
    jz      .bar32
    ; 64-bit MMIO: read BAR1 for high bits
    mov     rdi, rbx
    mov     rsi, r9
    mov     rdx, r10
    mov     ecx, PCI_BAR1
    call    er_pci_read32
    shl     rax, 32
    mov     r11d, r11d          ; zero-extend low part
    or      r11, rax
.bar32:
    mov     rax, r11
    and     rax, ~0x0F          ; mask off type bits

    test    r8, r8
    jz      .skip_store
    mov     [r8], rax
.skip_store:
    er_ok
    jmp     .out

.no_dev:
    er_err  ERROR_NOT_PRESENT
.out:
    pop     rbx
    pop     r10
    pop     r9
    pop     r8
    ret

; ==================================================================
; er_nvme_init — initialize NVMe controller admin queues
; int er_nvme_init(uint64_t bar0)
;
; Uses fixed buffer addresses NVME_ADMIN_SQ / NVME_ADMIN_CQ.
; Enables controller with admin queue sizes = 64 entries.
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_nvme_init
    push    rbx
    push    r12

    mov     r12, rdi            ; BAR0

    ; Step 1: Disable controller (CC.EN = 0)
    lea     rdi, [r12 + NVME_CC]
    xor     esi, esi
    call    er_mmio_write32

    ; Wait for CSTS.RDY = 0
    mov     ebx, 1000000
.wait_rdy0:
    lea     rdi, [r12 + NVME_CSTS]
    call    er_mmio_read32
    test    al, CSTS_RDY
    jz      .rdy0_clear
    pause
    dec     ebx
    jnz     .wait_rdy0
    er_err  ERROR_TIMEOUT
    jmp     .out

.rdy0_clear:
    ; Step 2: Program admin queue attributes
    ; AQA: 63 entries each for SQ and CQ
    lea     rdi, [r12 + NVME_AQA]
    mov     esi, (63 << 16) | 63
    call    er_mmio_write32

    ; ASQ = NVME_ADMIN_SQ
    lea     rdi, [r12 + NVME_ASQ_LO]
    mov     esi, NVME_ADMIN_SQ
    call    er_mmio_write32
    lea     rdi, [r12 + NVME_ASQ_HI]
    xor     esi, esi            ; below 4GB
    call    er_mmio_write32

    ; ACQ = NVME_ADMIN_CQ
    lea     rdi, [r12 + NVME_ACQ_LO]
    mov     esi, NVME_ADMIN_CQ
    call    er_mmio_write32
    lea     rdi, [r12 + NVME_ACQ_HI]
    xor     esi, esi
    call    er_mmio_write32

    ; Step 3: Enable controller
    lea     rdi, [r12 + NVME_CC]
    mov     esi, CC_EN | CC_IOSQES_64B | CC_IOCQES_16B
    call    er_mmio_write32

    ; Wait for CSTS.RDY = 1
    mov     ebx, 1000000
.wait_rdy1:
    lea     rdi, [r12 + NVME_CSTS]
    call    er_mmio_read32
    test    al, CSTS_RDY
    jnz     .rdy1_set
    pause
    dec     ebx
    jnz     .wait_rdy1
    er_err  ERROR_TIMEOUT
    jmp     .out

.rdy1_set:
    er_ok
.out:
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_nvme_identify_controller — send Identify CNS=1
; int er_nvme_identify_controller(uint64_t bar0, void* data_buf)
;
; data_buf must be 4KB-aligned, within 32-bit address space.
; Uses NVME_ADMIN_SQ and NVME_ADMIN_CQ for the admin queues.
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_nvme_identify_controller
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; BAR0
    mov     r13, rsi            ; data buffer
    mov     r14, NVME_ADMIN_SQ ; admin SQ address
    mov     r15, NVME_ADMIN_CQ ; admin CQ address

    ; Build admin submission queue entry at [r14] (64 bytes)

    ; Clear the submission entry (64 bytes)
    xor     eax, eax
    mov     ecx, 16
.clear_sq:
    mov     [r14], eax
    add     r14, 4
    dec     ecx
    jnz     .clear_sq
    mov     r14, NVME_ADMIN_SQ ; restore

    ; CDW0: opcode = 0x06 (Identify), cmd_id = 0
    mov     dword [r14], NVME_ADM_IDENTIFY

    ; NSID = 0 (controller identify)
    mov     dword [r14 + 4], 0

    ; PRP1 = data buffer physical address
    mov     dword [r14 + 40], r13d
    mov     dword [r14 + 44], 0

    ; CDW10 = CNS (bits 31:16) = 1 (controller identify)
    mov     dword [r14 + 16], IDENTIFY_CTRL

    ; Reset completion queue phase tag
    mov     dword [r15], 0

    ; Ring admin SQ doorbell
    lea     rdi, [r12 + SQ0TDBL]
    mov     esi, 1
    call    er_mmio_write32

    ; Poll for completion (timeout = 100M iterations)
    mov     ebx, 100000000
.poll:
    lea     rdi, [r12 + NVME_CSTS]
    call    er_mmio_read32
    test    eax, eax
    js      .fatal

    mov     eax, [r15]
    test    eax, 1              ; check phase tag (bit 0 of CQE)
    jnz     .completed
    pause
    dec     ebx
    jnz     .poll

    er_err  ERROR_TIMEOUT
    jmp     .out

.completed:
    ; Check CQE status: word 3 (bytes 6-7)
    ; bits 15:1 = status code, bit 0 = phase tag
    movzx   eax, word [r15 + 6]
    and     eax, 0x7FFE
    jnz     .cmd_fail

    er_ok
    jmp     .out

.cmd_fail:
    er_err  ERROR_IO
    jmp     .out

.fatal:
    er_err  ERROR_IO
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_nvme_print_info — print NVMe controller info via serial
; void er_nvme_print_info(uint64_t bar0, uint64_t com_port)
; ==================================================================
er_fn er_nvme_print_info
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; BAR0
    mov     r13, rsi            ; COM port

    ; Read Version (VS)
    lea     rdi, [r12 + NVME_VS]
    call    er_mmio_read32
    mov     ebx, eax

    mov     rdi, r13
    lea     rsi, [rel .ver_str]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, ebx
    call    er_serial_puthex32
    mov     rdi, r13
    call    er_serial_crlf

    ; Read Capabilities low (CAP)
    lea     rdi, [r12 + NVME_CAP_LO]
    call    er_mmio_read32
    mov     ebx, eax

    mov     rdi, r13
    lea     rsi, [rel .cap_str]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, ebx
    call    er_serial_puthex32

    lea     rdi, [r12 + NVME_CAP_HI]
    call    er_mmio_read32
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, r13
    call    er_serial_crlf

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.ver_str: db "nvme: vs 0x", 0
.cap_str: db "nvme: cap 0x", 0

; ==================================================================
; er_nvme_io_setup — create IO Completion Queue + Submission Queue
; int er_nvme_io_setup(uint64_t bar0)
;
; Uses fixed IO queue buffers. Creates CQ 1 with 64 entries,
; then SQ 1 with 64 entries.
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_nvme_io_setup
    push    r12
    push    r13
    push    r14
    push    rbx

    mov     r12, rdi            ; BAR0
    mov     r13, NVME_ADMIN_SQ  ; admin SQ
    mov     r14, NVME_ADMIN_CQ  ; admin CQ

    ; ─── Create IO Completion Queue (qid=1) ───────────────────
    ; CQE size = 16 bytes (per CC.IOCQES)
    ; Queue size = 64 entries

    ; Clear SQE entry
    xor     eax, eax
    mov     ecx, 16
    mov     rdi, r13
.clr1:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .clr1

    ; CDW0 = opcode 5 (Create IO CQ)
    mov     dword [r13], 5

    ; PRP1 = physical address of IO CQ buffer
    mov     dword [r13 + 40], NVME_IO_CQ
    mov     dword [r13 + 44], 0

    ; CDW10: QID = 1 (bits 15:0), QSIZE = 63 (bits 31:16) (entries-1)
    mov     dword [r13 + 16], (63 << 16) | 1

    ; CDW11: PC = 1 (physically contiguous, bit 0), IEN = 0,
    ;        IV = 0 (interrupt vector)
    mov     dword [r13 + 20], 1

    ; NSID = 0
    mov     dword [r13 + 4], 0

    ; Reset CQ phase
    mov     dword [r14], 0

    ; Ring admin SQ doorbell
    lea     rdi, [r12 + SQ0TDBL]
    mov     esi, 1
    call    er_mmio_write32

    ; Poll
    mov     ebx, 100000000
.poll_cq:
    mov     eax, [r14]
    test    eax, 1
    jnz     .cq_done
    pause
    dec     ebx
    jnz     .poll_cq
    er_err  ERROR_TIMEOUT
    jmp     .out

.cq_done:
    movzx   eax, word [r14 + 6]
    and     eax, 0x7FFE
    jnz     .fail

    ; ─── Create IO Submission Queue (qid=1) ──────────────────
    ; SQE size = 64 bytes (per CC.IOSQES)

    xor     eax, eax
    mov     ecx, 16
    mov     rdi, r13
.clr2:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .clr2

    ; CDW0 = opcode 1 (Create IO SQ)
    mov     dword [r13], 1

    ; PRP1 = physical address of IO SQ buffer
    mov     dword [r13 + 40], NVME_IO_SQ
    mov     dword [r13 + 44], 0

    ; CDW10: QID = 1, QSIZE = 63
    mov     dword [r13 + 16], (63 << 16) | 1

    ; CDW11: PC = 1, QPRIO = 1 (high priority, bits 1:0)
    mov     dword [r13 + 20], 1   ; PC = 1, no CQ overlap info

    ; NSID = 0
    mov     dword [r13 + 4], 0

    ; Reset CQ phase
    mov     dword [r14], 0

    ; Ring admin SQ doorbell (SQ head pointer was incremented)
    lea     rdi, [r12 + SQ0TDBL]
    mov     esi, 1
    call    er_mmio_write32

    ; Poll
    mov     ebx, 100000000
.poll_sq:
    mov     eax, [r14]
    test    eax, 1
    jnz     .sq_done
    pause
    dec     ebx
    jnz     .poll_sq
    er_err  ERROR_TIMEOUT
    jmp     .out

.sq_done:
    movzx   eax, word [r14 + 6]
    and     eax, 0x7FFE
    jnz     .fail

    er_ok
    jmp     .out

.fail:
    er_err  ERROR_IO
.out:
    pop     rbx
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_nvme_identify_ns — identify namespace 1
; int er_nvme_identify_ns(uint64_t bar0)
;
; Sends Identify CNS=0 for NSID=1 into NVME_ID_BUF.
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_nvme_identify_ns
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; BAR0
    mov     r13, NVME_ADMIN_SQ
    mov     r14, NVME_ADMIN_CQ

    ; Clear SQE
    xor     eax, eax
    mov     ecx, 16
    mov     rdi, r13
.clr:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .clr

    ; CDW0 = opcode 6 (Identify)
    mov     dword [r13], NVME_ADM_IDENTIFY

    ; NSID = 1 (namespace 1)
    mov     dword [r13 + 4], 1

    ; PRP1 = NVME_ID_BUF
    mov     dword [r13 + 40], NVME_ID_BUF
    mov     dword [r13 + 44], 0

    ; CDW10 = CNS 0 (namespace struct)
    mov     dword [r13 + 16], 0

    ; Reset CQ phase
    mov     dword [r14], 0

    lea     rdi, [r12 + SQ0TDBL]
    mov     esi, 1
    call    er_mmio_write32

    mov     ebx, 100000000
.poll:
    mov     eax, [r14]
    test    eax, 1
    jnz     .done
    pause
    dec     ebx
    jnz     .poll
    er_err  ERROR_TIMEOUT
    jmp     .out

.done:
    movzx   eax, word [r14 + 6]
    and     eax, 0x7FFE
    jnz     .fail
    er_ok
    jmp     .out

.fail:
    er_err  ERROR_IO
.out:
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_nvme_print_ns_info — print namespace 1 info from NVME_ID_BUF
; void er_nvme_print_ns_info(uint64_t com_port)
; ==================================================================
er_fn er_nvme_print_ns_info
    push    rbx
    push    r12
    push    r13

    mov     r12, NVME_ID_BUF
    mov     r13w, di

    ; NSZE: bytes 0-7 = namespace size (in LBAs)
    mov     eax, [r12]          ; low 32 bits of NSZE
    mov     ebx, [r12 + 4]      ; high 32 bits of NSZE

    mov     rdi, r13
    lea     rsi, [rel .nsze_s]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, r13
    mov     esi, ebx
    call    er_serial_puthex32
    mov     rdi, r13
    call    er_serial_crlf

    ; LBA format: bytes 128+ = LBAF[]. LBAF[0] at offset 128
    ; byte 132+3 = LBADS (LBA data size, 2^LBADS bytes)
    movzx   ecx, byte [r12 + 131]   ; LBAF0[3] = LBADS
    mov     edx, 1
    shl     edx, cl                 ; data size per LBA

    mov     rdi, r13
    lea     rsi, [rel .lbads_s]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, edx
    call    er_serial_putdec32
    mov     rdi, r13
    lea     rsi, [rel .bytes_s]
    call    er_serial_puts
    mov     rdi, r13
    call    er_serial_crlf

    ; FLBAS (Formatted LBA size): byte 128
    movzx   eax, byte [r12 + 128]
    mov     rdi, r13
    lea     rsi, [rel .flbas_s]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, r13
    call    er_serial_crlf

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.nsze_s:  db "nsze: 0x", 0
.lbads_s: db "lbads: ", 0
.bytes_s: db " bytes/lba", 0
.flbas_s: db "flbas: ", 0

; ==================================================================
; er_nvme_read_blocks — read blocks from NVMe namespace
; int er_nvme_read_blocks(uint64_t bar0, uint64_t lba,
;                         void* buf, uint32_t count)
;
; rdi=bar0, rsi=lba, rdx=buf, ecx=count
; buf must be 4-byte aligned (PRP1 requires page alignment if >1 page).
; count: number of 512-byte blocks (max 64 for the 64-entry SQ).
; Uses IO SQ 1 (submission) and IO CQ 1 (completion).
; Returns: eax = 0 on success, -1 on failure (rdx = error code)
; ==================================================================
; ==================================================================
; _nvme_io_blocks — shared read/write internal helper
; rdi = BAR0, rsi = LBA, rdx = buf, ecx = count, r8d = opcode
; Returns: eax = 0 on success, rdx = error code
; ==================================================================
_nvme_io_blocks:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; BAR0
    mov     r13, rsi            ; lba
    mov     r14, rdx            ; buf
    mov     r15d, ecx           ; count

    test    r15d, r15d
    jz      .bad_arg
    cmp     r15d, 64
    ja      .bad_arg

    ; Build SQE at NVME_IO_SQ (64 bytes)
    mov     rdi, NVME_IO_SQ
    xor     eax, eax
    mov     ecx, 16
.clr_sqe:
    mov     [rdi], eax
    add     rdi, 4
    dec     ecx
    jnz     .clr_sqe

    ; CDW0: opcode from r8d, flags=0, cmd_id=0
    mov     dword [NVME_IO_SQ], r8d

    ; NSID = 1
    mov     dword [NVME_IO_SQ + 4], 1

    ; CDW10 = lba low 32 bits
    mov     dword [NVME_IO_SQ + 16], r13d
    ; CDW11 = lba high 32 bits
    shr     r13, 32
    mov     dword [NVME_IO_SQ + 20], r13d

    ; CDW12 = number of blocks - 1
    mov     eax, r15d
    dec     eax
    mov     dword [NVME_IO_SQ + 24], eax

    ; PRP1 = physical address of data buffer
    mov     dword [NVME_IO_SQ + 40], r14d
    mov     dword [NVME_IO_SQ + 44], 0

    ; Clear IO CQ phase tag (expect phase=1 initially)
    mov     dword [NVME_IO_CQ], 0

    ; Ring IO SQ tail doorbell
    lea     rdi, [r12 + NVME_SQ1TDBL]
    mov     esi, 1
    call    er_mmio_write32

    ; Poll IO CQ for completion
    mov     ebx, 100000000
.poll_cq:
    mov     eax, [NVME_IO_CQ]
    test    eax, 1              ; phase tag (bit 0)
    jnz     .cq_done
    pause
    dec     ebx
    jnz     .poll_cq
    mov     eax, -1
    er_err  ERROR_TIMEOUT
    jmp     .out

.cq_done:
    ; Check status: CQE word 3 (bytes 6-7), bits 15:1 = status
    movzx   eax, word [NVME_IO_CQ + 6]
    and     eax, 0x7FFE
    jnz     .io_fail

    xor     eax, eax
    er_ok
    jmp     .out

.bad_arg:
    mov     eax, -1
    er_err  ERROR_UNSUPPORTED
    jmp     .out

.io_fail:
    mov     eax, -1
    er_err  ERROR_IO
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_nvme_read_blocks — read blocks from NVMe namespace
; int er_nvme_read_blocks(uint64_t bar0, uint64_t lba,
;                         void* buf, uint32_t count)
; Returns: eax = 0 on success, rdx = error code
; ==================================================================
er_fn er_nvme_read_blocks
    mov     r8d, 2              ; opcode: Read
    jmp     _nvme_io_blocks

; ==================================================================
; er_nvme_write_blocks — write blocks to NVMe namespace
; int er_nvme_write_blocks(uint64_t bar0, uint64_t lba,
;                          const void* buf, uint32_t count)
; Returns: eax = 0 on success, rdx = error code
; ==================================================================
er_fn er_nvme_write_blocks
    mov     r8d, 1              ; opcode: Write
    jmp     _nvme_io_blocks
