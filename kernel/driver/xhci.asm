; EdgeRun xHCI (USB 3.0) driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Probes xHCI controllers, reads capability/port registers.
; Initializes controller (reset, command/event ring setup, start).

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_pci_read32
extern er_mmio_read32
extern er_mmio_write32
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putdec32
extern er_serial_putchar
extern er_serial_crlf

; ─── PCI constants ──────────────────────────────────────────────────
%define XHCI_CLASS      0x0C
%define XHCI_SUBCLASS   0x03
%define XHCI_PROGIF     0x30

; ─── Capability register offsets (from BAR0) ────────────────────────
%define XHCI_CAPLENGTH  0x00
%define XHCI_HCIVERSION 0x02
%define XHCI_HCSPARAMS1 0x04
%define XHCI_HCCPARAMS1 0x10
%define XHCI_DBOFF      0x14
%define XHCI_RTSOFF     0x18

; ─── HCSPARAMS1 bit fields ──────────────────────────────────────────
%define HCS1_MAX_SLOTS  0xFF            ; bits 7:0
%define HCS1_MAX_PORTS_SHIFT 24

; ─── HCCPARAMS1 bits ────────────────────────────────────────────────
%define HCC1_PPC         (1 << 4)
%define HCC1_64BIT       (1 << 0)

; ─── Operational register offsets (from port_off = CAPLENGTH) ──────
%define OP_USBCMD        0x00
%define OP_USBSTS        0x04
%define OP_CRCR_LO       0x18
%define OP_CRCR_HI       0x1C
%define OP_DCBAAP_LO     0x30
%define OP_DCBAAP_HI     0x34
%define OP_CONFIG        0x38
%define OP_PORTSC        0x400

; ─── Runtime register offsets (from rts_off) ────────────────────────
%define RT_ERSTSZ        0x08
%define RT_ERSTBA_LO     0x10
%define RT_ERSTBA_HI     0x14
%define RT_ERDP_LO       0x18
%define RT_ERDP_HI       0x1C

; ─── USBCMD bits ────────────────────────────────────────────────────
%define CMD_RUN          (1 << 0)
%define CMD_HCRST        (1 << 1)

; ─── USBSTS bits ────────────────────────────────────────────────────
%define STS_HCH          (1 << 0)

; ─── CRCR bits ──────────────────────────────────────────────────────
%define CRCR_RCS         (1 << 0)

; ─── PORTSC bits ────────────────────────────────────────────────────
%define PORTSC_CCS       (1 << 0)
%define PORTSC_PED       (1 << 1)
%define PORTSC_PR        (1 << 4)
%define PORTSC_PP        (1 << 9)
%define PORTSC_SPEED_SHIFT 10

; ─── TRB constants ──────────────────────────────────────────────────
%define TRB_CMD_NOOP     23

; ─── Ring sizes ─────────────────────────────────────────────────────
%define CMD_RING_NTRB    16
%define EVT_RING_NTRB    16

; ─── BSS ────────────────────────────────────────────────────────────
SECTION .bss
align 64
xhci_dcbaa:        resb 2048          ; 256 × 8 bytes
align 64
xhci_erst:         resb 16            ; 1 × 16 bytes
align 64
xhci_evt_ring:     resb (EVT_RING_NTRB * 16)
align 16
xhci_cmd_ring:     resb (CMD_RING_NTRB * 16)

xhci_bar0:         resd 1
xhci_port_off:     resd 1
xhci_rts_off:      resd 1
xhci_db_off:       resd 1
xhci_max_slots:    resd 1
xhci_max_ports:    resd 1
xhci_hci_rev:      resd 1

; ─── Text ───────────────────────────────────────────────────────────
SECTION .text

; ===== Speed name lookup ============================================
_xhci_speed_name:
    cmp     edi, 1;    je .full
    cmp     edi, 2;    je .low
    cmp     edi, 3;    je .high
    cmp     edi, 4;    je .super
    cmp     edi, 5;    je .s20
    cmp     edi, 6;    je .s10
    cmp     edi, 7;    je .s102
    lea     rax, [rel .unk]; ret
.full:  lea rax, [rel .f];  ret
.low:   lea rax, [rel .l];  ret
.high:  lea rax, [rel .h];  ret
.super: lea rax, [rel .s];  ret
.s20:   lea rax, [rel .s20s];ret
.s10:   lea rax, [rel .s10s];ret
.s102:  lea rax, [rel .s102s];ret
.unk:   db "?",0
.f:     db "Full",0
.l:     db "Low",0
.h:     db "High",0
.s:     db "Super",0
.s20s:  db "Super20G",0
.s10s:  db "Super10G",0
.s102s: db "Super10Gx2",0

; ==================================================================
; er_xhci_probe — probe xHCI controller at PCI location
; void er_xhci_probe(uint16_t com_port, uint8_t bus, uint8_t dev, uint8_t func)
;
; Reads capabilities and port status. Does NOT initialize controller.
; ==================================================================
er_fn er_xhci_probe
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx

    mov     r15w, di
    mov     r12d, esi           ; bus
    mov     r13d, edx           ; dev
    mov     ebx, ecx            ; func

    ; Verify device exists
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, ebx
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .no_dev

    ; Read BAR0
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, ebx
    mov     ecx, 0x10
    call    er_pci_read32
    and     eax, ~0x0F
    mov     r14d, eax           ; BAR0 base
    mov     [xhci_bar0], eax

    ; Location string
    mov     rdi, r15
    lea     rsi, [rel .loc_s]
    call    er_serial_puts
    mov     rdi, r15
    mov     esi, r12d
    call    er_serial_putdec32
    mov     rdi, r15
    mov     esi, ':'
    call    er_serial_putchar
    mov     rdi, r15
    mov     esi, r13d
    call    er_serial_putdec32
    mov     rdi, r15
    mov     esi, '.'
    call    er_serial_putchar
    mov     rdi, r15
    mov     esi, ebx
    call    er_serial_putdec32
    mov     rdi, r15
    mov     esi, ' '
    call    er_serial_putchar
    mov     rdi, r15
    mov     esi, r14d
    call    er_serial_puthex32

    ; Read CAPLENGTH + HCIVERSION
    mov     rdi, r14
    call    er_mmio_read32
    movzx   ecx, al
    mov     [xhci_port_off], ecx

    mov     rdi, r15
    lea     rsi, [rel .ver_s]
    call    er_serial_puts
    shr     eax, 16
    mov     [xhci_hci_rev], eax
    movzx   esi, ax
    mov     rdi, r15
    call    er_serial_puthex32

    ; HCSPARAMS1
    lea     rdi, [r14 + XHCI_HCSPARAMS1]
    call    er_mmio_read32
    mov     ecx, eax
    and     ecx, HCS1_MAX_SLOTS
    mov     [xhci_max_slots], ecx
    shr     eax, HCS1_MAX_PORTS_SHIFT
    mov     [xhci_max_ports], eax

    mov     rdi, r15
    lea     rsi, [rel .port_s]
    call    er_serial_puts
    mov     rdi, r15
    mov     esi, eax
    call    er_serial_putdec32
    mov     rdi, r15
    call    er_serial_crlf

    ; DBOFF + RTSOFF
    lea     rdi, [r14 + XHCI_DBOFF]
    call    er_mmio_read32
    mov     [xhci_db_off], eax
    lea     rdi, [r14 + XHCI_RTSOFF]
    call    er_mmio_read32
    mov     [xhci_rts_off], eax

    ; HCCPARAMS1
    lea     rdi, [r14 + XHCI_HCCPARAMS1]
    call    er_mmio_read32
    test    eax, HCC1_PPC
    jz      .probe_ports

    ; Power up all ports
    mov     edi, [xhci_max_ports]
.pwr:
    mov     eax, edi
    dec     eax
    shl     eax, 4
    add     eax, OP_PORTSC
    add     eax, [xhci_port_off]
    add     eax, r14d
    mov     rsi, rax
    mov     rdi, rsi
    call    er_mmio_read32
    or      eax, PORTSC_PP
    mov     rdi, rsi
    call    er_mmio_write32
    dec     edi
    jnz     .pwr

    ; Port scan
.probe_ports:
    mov     rdi, r15
    lea     rsi, [rel .hdr_s]
    call    er_serial_puts
    mov     rdi, r15
    call    er_serial_crlf

    xor     r12d, r12d
.ploop:
    inc     r12d
    cmp     r12d, [xhci_max_ports]
    ja      .done

    mov     eax, r12d
    dec     eax
    shl     eax, 4
    add     eax, OP_PORTSC
    add     eax, [xhci_port_off]
    add     eax, r14d
    mov     rdi, rax
    call    er_mmio_read32
    mov     r13d, eax

    mov     rdi, r15
    mov     esi, r12d
    call    er_serial_putdec32
    mov     rdi, r15
    mov     esi, ':'
    call    er_serial_putchar

    test    r13d, PORTSC_CCS
    jnz     .conn

    mov     rdi, r15
    lea     rsi, [rel .emp_s]
    call    er_serial_puts
    mov     rdi, r15
    call    er_serial_crlf
    jmp     .ploop

.conn:
    mov     rdi, r15
    lea     rsi, [rel .con_s]
    call    er_serial_puts

    mov     eax, r13d
    shr     eax, PORTSC_SPEED_SHIFT
    and     eax, 0xF
    mov     edi, eax
    call    _xhci_speed_name
    mov     rdi, r15
    mov     rsi, rax
    call    er_serial_puts

    test    r13d, PORTSC_PED
    jnz     .ena
    mov     rdi, r15
    lea     rsi, [rel .dis_s]
    call    er_serial_puts
    jmp     .pr
.ena:
    mov     rdi, r15
    lea     rsi, [rel .en_s]
    call    er_serial_puts
.pr:
    mov     rdi, r15
    mov     esi, ' '
    call    er_serial_putchar
    mov     rdi, r15
    mov     esi, r13d
    call    er_serial_puthex32
    mov     rdi, r15
    call    er_serial_crlf
    jmp     .ploop

.done:
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    ret

.no_dev:
    mov     rdi, r15
    lea     rsi, [rel .abs_s]
    call    er_serial_puts
    mov     rdi, r15
    call    er_serial_crlf
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret

.loc_s:  db "xhci: ",0
.ver_s:  db " ver 0x",0
.port_s: db " ports ",0
.hdr_s:  db "--- ports ---",0
.emp_s:  db " empty",0
.con_s:  db " connected ",0
.dis_s:  db " disabled",0
.en_s:   db " enabled",0
.abs_s:  db "xhci: not found",0

; ==================================================================
; er_xhci_init — full xHCI controller initialization
; int er_xhci_init(uint16_t com_port, uint8_t bus, uint8_t dev,
;                  uint8_t func, uint8_t* out_max_ports)
;
; rdi=com_port, esi=bus, edx=dev, ecx=func, r8=out_max_ports
;
; Resets controller, sets up rings, starts HC.
; Returns: eax = 0 on success, -1 on failure
;          *out_max_ports = number of downstream ports
; ==================================================================
er_fn er_xhci_init
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx
    push    r8              ; save out_max_ports

    mov     r15w, di
    mov     r12d, esi
    mov     r13d, edx
    mov     ebx, ecx

    ; Verify device
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, ebx
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .fail

    ; Read BAR0
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, ebx
    mov     ecx, 0x10
    call    er_pci_read32
    and     eax, ~0x0F
    mov     r14d, eax
    mov     [xhci_bar0], eax

    ; Read registers we need stored
    mov     rdi, r14
    call    er_mmio_read32
    movzx   ecx, al
    mov     [xhci_port_off], ecx

    lea     rdi, [r14 + XHCI_HCSPARAMS1]
    call    er_mmio_read32
    mov     ecx, eax
    and     ecx, HCS1_MAX_SLOTS
    mov     [xhci_max_slots], ecx
    shr     eax, HCS1_MAX_PORTS_SHIFT
    mov     [xhci_max_ports], eax

    lea     rdi, [r14 + XHCI_DBOFF]
    call    er_mmio_read32
    mov     [xhci_db_off], eax
    lea     rdi, [r14 + XHCI_RTSOFF]
    call    er_mmio_read32
    mov     [xhci_rts_off], eax

    ; ─── 1. Reset controller ──────────────────────────────────
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_USBCMD
    call    er_mmio_read32
    or      eax, CMD_HCRST
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_USBCMD
    call    er_mmio_write32

    ; Wait for reset (HCH = 0 in USBSTS)
    mov     ecx, 200000
.wait_rst:
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_USBSTS
    call    er_mmio_read32
    test    eax, STS_HCH
    jz      .rst_done
    dec     ecx
    jnz     .wait_rst
    jmp     .timeout

.rst_done:
    ; ─── 2. DCBAAP ────────────────────────────────────────────
    lea     rax, [rel xhci_dcbaa]
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_DCBAAP_LO
    mov     esi, eax
    call    er_mmio_write32

    lea     rax, [rel xhci_dcbaa]
    shr     rax, 32
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_DCBAAP_HI
    mov     esi, eax
    call    er_mmio_write32

    ; ─── 3. Command Ring ─────────────────────────────────────
    lea     rax, [rel xhci_cmd_ring]
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_CRCR_LO
    mov     esi, eax
    or      esi, CRCR_RCS           ; ring cycle state = 1
    call    er_mmio_write32

    lea     rax, [rel xhci_cmd_ring]
    shr     rax, 32
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_CRCR_HI
    mov     esi, eax
    call    er_mmio_write32

    ; ─── 4. Event Ring ───────────────────────────────────────
    ; ERSTSZ = 1
    mov     edi, r14d
    add     edi, [xhci_rts_off]
    add     edi, RT_ERSTSZ
    mov     esi, 1
    call    er_mmio_write32

    ; ERSTBA
    lea     rax, [rel xhci_erst]
    mov     edi, r14d
    add     edi, [xhci_rts_off]
    add     edi, RT_ERSTBA_LO
    mov     esi, eax
    call    er_mmio_write32

    lea     rax, [rel xhci_erst]
    shr     rax, 32
    mov     edi, r14d
    add     edi, [xhci_rts_off]
    add     edi, RT_ERSTBA_HI
    mov     esi, eax
    call    er_mmio_write32

    ; ERDP = event ring base (initial dequeue at start)
    lea     rax, [rel xhci_evt_ring]
    mov     edi, r14d
    add     edi, [xhci_rts_off]
    add     edi, RT_ERDP_LO
    mov     esi, eax
    call    er_mmio_write32

    lea     rax, [rel xhci_evt_ring]
    shr     rax, 32
    mov     edi, r14d
    add     edi, [xhci_rts_off]
    add     edi, RT_ERDP_HI
    mov     esi, eax
    call    er_mmio_write32

    ; ─── 5. Configure ────────────────────────────────────────
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_CONFIG
    mov     esi, [xhci_max_slots]
    call    er_mmio_write32

    ; ─── 6. Start (RUN=1) ────────────────────────────────────
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_USBCMD
    call    er_mmio_read32
    or      eax, CMD_RUN
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_USBCMD
    call    er_mmio_write32

    ; Wait for HCH to clear
    mov     ecx, 200000
.wait_run:
    mov     edi, r14d
    add     edi, [xhci_port_off]
    add     edi, OP_USBSTS
    call    er_mmio_read32
    test    eax, STS_HCH
    jz      .started
    dec     ecx
    jnz     .wait_run
    jmp     .timeout

.started:
    ; Power up all ports (if PPC)
    lea     rdi, [r14 + XHCI_HCCPARAMS1]
    call    er_mmio_read32
    test    eax, HCC1_PPC
    jz      .no_ppc

    mov     edi, [xhci_max_ports]
.init_pwr:
    mov     eax, edi
    dec     eax
    shl     eax, 4
    add     eax, OP_PORTSC
    add     eax, [xhci_port_off]
    add     eax, r14d
    mov     rsi, rax
    mov     rdi, rsi
    call    er_mmio_read32
    or      eax, PORTSC_PP
    mov     rdi, rsi
    call    er_mmio_write32
    dec     edi
    jnz     .init_pwr

.no_ppc:
    ; Write out_max_ports
    pop     rax
    test    rax, rax
    jz      .no_out
    mov     ecx, [xhci_max_ports]
    mov     [rax], cl
.no_out:

    mov     rdi, r15
    lea     rsi, [rel .ok_s]
    call    er_serial_puts
    mov     rdi, r15
    mov     esi, r14d
    call    er_serial_puthex32
    mov     rdi, r15
    call    er_serial_crlf

    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    ret

.timeout:
    pop     rax             ; out_max_ports (discard)
    mov     rdi, r15
    lea     rsi, [rel .to_s]
    call    er_serial_puts
    mov     rdi, r15
    call    er_serial_crlf
.fail:
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_err  ERROR_TIMEOUT

.ok_s: db "xhci_init: ok bar ",0
.to_s: db "xhci_init: timeout",0

; ==================================================================
; er_xhci_get_info — fetch initialized controller summary
; int er_xhci_get_info(uint64_t* out_bar0, uint32_t* out_max_ports)
; Returns: eax=0 on success, -1 if controller state is unavailable.
; ==================================================================
er_fn er_xhci_get_info
    test    rdi, rdi
    jz      .gi_bad_arg
    test    rsi, rsi
    jz      .gi_bad_arg
    mov     eax, [xhci_bar0]
    test    eax, eax
    jz      .gi_absent
    mov     [rdi], rax
    mov     eax, [xhci_max_ports]
    mov     [rsi], eax
    er_ok
    xor     eax, eax
    ret
.gi_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret
.gi_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

; ==================================================================
; er_xhci_read_portsc — read xHCI PORTSC for a given 1-based port index
; int er_xhci_read_portsc(uint32_t port_index, uint32_t* out_portsc)
; Returns: eax=0 on success, -1 on bad args/state.
; ==================================================================
er_fn er_xhci_read_portsc
    test    rsi, rsi
    jz      .rp_bad_arg
    cmp     edi, 1
    jb      .rp_bad_arg
    mov     eax, [xhci_max_ports]
    cmp     edi, eax
    ja      .rp_bad_arg
    mov     eax, [xhci_bar0]
    test    eax, eax
    jz      .rp_absent
    mov     edx, edi
    dec     edx
    shl     edx, 4
    add     edx, OP_PORTSC
    add     edx, [xhci_port_off]
    add     edx, [xhci_bar0]
    mov     rdi, rdx
    call    er_mmio_read32
    mov     [rsi], eax
    er_ok
    xor     eax, eax
    ret
.rp_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret
.rp_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret
