; EdgeRun NVMe driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"

extern er_pci_read32
extern er_mmio_read32
extern er_mmio_write32
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_crlf

; PCI config registers (reused from pci.asm context)
%define PCI_BAR0        0x10
%define PCI_BAR1        0x14

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

; Fixed buffer addresses (identity-mapped low 4MB)
%define NVME_ADMIN_SQ   0x300000
%define NVME_ADMIN_CQ   0x301000
%define NVME_ID_BUF     0x302000

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
    xor     eax, eax
    mov     eax, -1
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
    mov     eax, 0
    jmp     .out

.no_dev:
    mov     eax, -1
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
    mov     eax, -1
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
    mov     eax, -1
    jmp     .out

.rdy1_set:
    mov     eax, 0
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

    mov     eax, -1
    jmp     .out

.completed:
    ; Check CQE status: word 3 (bytes 6-7)
    ; bits 15:1 = status code, bit 0 = phase tag
    movzx   eax, word [r15 + 6]
    and     eax, 0x7FFE
    jnz     .cmd_fail

    mov     eax, 0
    jmp     .out

.cmd_fail:
    mov     eax, -1
    jmp     .out

.fatal:
    mov     eax, -1
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
    lea     rdi, [r13]
    call    .crlf

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
    call    .crlf

    pop     r13
    pop     r12
    pop     rbx
    ret

.crlf:
    mov     rdi, r13
    jmp     er_serial_crlf

.ver_str: db "nvme: vs 0x", 0
.cap_str: db "nvme: cap 0x", 0
