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
%define TRB_LINK         6
%define TRB_EV_CMD_CMPL  33
%define TRB_TYPE_SHIFT   10
%define TRB_CYCLE        (1 << 0)
%define TRB_LINK_TOGGLE  (1 << 1)
%define TRB_TYPE_MASK    (0x3F << TRB_TYPE_SHIFT)
%define XHCI_CC_SUCCESS  1

; ─── Ring sizes ─────────────────────────────────────────────────────
%define CMD_RING_NTRB    16
%define EVT_RING_NTRB    16
%define XHCI_BLOB_PORT_SLOTS 32

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
xhci_cfg_blob_ptrs: resq XHCI_BLOB_PORT_SLOTS
xhci_cfg_blob_lens: resq XHCI_BLOB_PORT_SLOTS
xhci_cmd_enq_idx:   resd 1
xhci_cmd_cycle:     resd 1
xhci_evt_deq_idx:   resd 1
xhci_evt_cycle:     resd 1
xhci_cw_p0:         resq 1
xhci_cw_st:         resd 1
xhci_cw_ctl:        resd 1
xhci_cw_rsv:        resd 1

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

    ; ─── 0. Initialize software/hardware ring backing storage ──────
    ; Clear command ring
    lea     rdi, [rel xhci_cmd_ring]
    xor     eax, eax
    mov     ecx, (CMD_RING_NTRB * 16) / 8
    rep stosq
    ; Clear event ring
    lea     rdi, [rel xhci_evt_ring]
    xor     eax, eax
    mov     ecx, (EVT_RING_NTRB * 16) / 8
    rep stosq
    ; Clear ERST entry then populate with event ring base + size
    lea     rdi, [rel xhci_erst]
    xor     eax, eax
    mov     ecx, 16 / 8
    rep stosq
    lea     rax, [rel xhci_evt_ring]
    mov     [rel xhci_erst + 0], rax
    mov     dword [rel xhci_erst + 8], EVT_RING_NTRB

    ; Command ring needs a terminal Link TRB back to ring base.
    lea     rax, [rel xhci_cmd_ring]
    lea     rdi, [rel xhci_cmd_ring + ((CMD_RING_NTRB - 1) * 16)]
    mov     [rdi + 0], rax
    mov     dword [rdi + 8], 0
    mov     dword [rdi + 12], (TRB_LINK << TRB_TYPE_SHIFT) | TRB_LINK_TOGGLE
    mov     dword [xhci_cmd_enq_idx], 0
    mov     dword [xhci_cmd_cycle], 1
    mov     dword [xhci_evt_deq_idx], 0
    mov     dword [xhci_evt_cycle], 1

    ; Clear per-port descriptor blob registry.
    lea     rdi, [rel xhci_cfg_blob_ptrs]
    xor     eax, eax
    mov     ecx, (XHCI_BLOB_PORT_SLOTS * 8) / 8
    rep stosq
    lea     rdi, [rel xhci_cfg_blob_lens]
    xor     eax, eax
    mov     ecx, (XHCI_BLOB_PORT_SLOTS * 8) / 8
    rep stosq

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

; ==================================================================
; er_xhci_set_port_config_blob — install/clear descriptor blob for port
; int er_xhci_set_port_config_blob(uint32_t port_index, const void* ptr, uint64_t len)
; port_index is 1-based. clear by ptr=0,len=0.
; ==================================================================
er_fn er_xhci_set_port_config_blob
    cmp     edi, 1
    jb      .sp_bad_arg
    cmp     edi, XHCI_BLOB_PORT_SLOTS
    ja      .sp_bad_arg
    test    rsi, rsi
    jz      .sp_clear_or_bad
    test    rdx, rdx
    jz      .sp_bad_arg
    mov     eax, edi
    dec     eax
    lea     rcx, [xhci_cfg_blob_ptrs]
    lea     r8, [xhci_cfg_blob_lens]
    mov     [rcx + rax*8], rsi
    mov     [r8 + rax*8], rdx
    xor     eax, eax
    er_ok
    ret
.sp_clear_or_bad:
    test    rdx, rdx
    jnz     .sp_bad_arg
    mov     eax, edi
    dec     eax
    lea     rcx, [xhci_cfg_blob_ptrs]
    lea     r8, [xhci_cfg_blob_lens]
    mov     qword [rcx + rax*8], 0
    mov     qword [r8 + rax*8], 0
    xor     eax, eax
    er_ok
    ret
.sp_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

; ==================================================================
; er_xhci_get_port_config_blob — fetch descriptor blob for port
; int er_xhci_get_port_config_blob(uint32_t port_index, uint64_t* out_ptr, uint64_t* out_len)
; Returns ERROR_NOT_PRESENT when no blob installed for the port.
; ==================================================================
er_fn er_xhci_get_port_config_blob
    cmp     edi, 1
    jb      .gp_bad_arg
    cmp     edi, XHCI_BLOB_PORT_SLOTS
    ja      .gp_bad_arg
    test    rsi, rsi
    jz      .gp_bad_arg
    test    rdx, rdx
    jz      .gp_bad_arg
    mov     eax, edi
    dec     eax
    lea     rcx, [xhci_cfg_blob_ptrs]
    lea     r8, [xhci_cfg_blob_lens]
    mov     r9, [rcx + rax*8]
    mov     r10, [r8 + rax*8]
    test    r9, r9
    jz      .gp_absent
    test    r10, r10
    jz      .gp_absent
    mov     [rsi], r9
    mov     [rdx], r10
    xor     eax, eax
    er_ok
    ret
.gp_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret
.gp_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

; ==================================================================
; er_xhci_cmd_submit_noop — enqueue a command No-Op TRB and ring doorbell 0
; int er_xhci_cmd_submit_noop(void)
; Returns: 0 on success, -1 on controller-not-present.
; ==================================================================
er_fn er_xhci_cmd_submit_noop
    mov     eax, [xhci_bar0]
    test    eax, eax
    jz      .cn_absent

    mov     ecx, [xhci_cmd_enq_idx]
    cmp     ecx, (CMD_RING_NTRB - 1)
    jb      .cn_have_slot
    mov     ecx, 0
    mov     eax, [xhci_cmd_cycle]
    xor     eax, 1
    mov     [xhci_cmd_cycle], eax
.cn_have_slot:
    lea     rdi, [rel xhci_cmd_ring]
    mov     eax, ecx
    shl     eax, 4
    add     rdi, rax
    ; TRB parameter/status are zero for No-Op.
    mov     qword [rdi + 0], 0
    mov     dword [rdi + 8], 0
    mov     eax, (TRB_CMD_NOOP << TRB_TYPE_SHIFT)
    mov     edx, [xhci_cmd_cycle]
    and     edx, TRB_CYCLE
    or      eax, edx
    mov     [rdi + 12], eax

    ; Advance enqueue pointer, skipping permanent Link TRB at tail.
    mov     eax, ecx
    inc     eax
    cmp     eax, (CMD_RING_NTRB - 1)
    jb      .cn_store_idx
    mov     eax, 0
    mov     edx, [xhci_cmd_cycle]
    xor     edx, 1
    mov     [xhci_cmd_cycle], edx
.cn_store_idx:
    mov     [xhci_cmd_enq_idx], eax

    ; Ring command doorbell (DB0 target 0, stream 0).
    mov     edi, [xhci_bar0]
    add     edi, [xhci_db_off]
    xor     esi, esi
    call    er_mmio_write32
    xor     eax, eax
    er_ok
    ret
.cn_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    ret

; ==================================================================
; er_xhci_event_pop — pop next event TRB if present
; int er_xhci_event_pop(uint64_t* out_p0, uint32_t* out_status,
;                       uint32_t* out_control, uint32_t* out_reserved)
; Returns: 1 when an event is popped, 0 when no event available, -1 bad args.
; ==================================================================
er_fn er_xhci_event_pop
    test    rdi, rdi
    jz      .ep_bad_arg
    test    rsi, rsi
    jz      .ep_bad_arg
    test    rdx, rdx
    jz      .ep_bad_arg
    test    rcx, rcx
    jz      .ep_bad_arg

    mov     eax, [xhci_evt_deq_idx]
    cmp     eax, EVT_RING_NTRB
    jb      .ep_idx_ok
    mov     eax, 0
    mov     [xhci_evt_deq_idx], eax
.ep_idx_ok:
    lea     r8, [rel xhci_evt_ring]
    mov     r9d, eax
    shl     r9d, 4
    add     r8, r9
    mov     r10d, [r8 + 12]
    mov     r11d, [xhci_evt_cycle]
    and     r11d, TRB_CYCLE
    mov     eax, r10d
    and     eax, TRB_CYCLE
    cmp     eax, r11d
    jne     .ep_empty

    mov     rax, [r8 + 0]
    mov     [rdi], rax
    mov     eax, [r8 + 8]
    mov     [rsi], eax
    mov     eax, [r8 + 12]
    mov     [rdx], eax
    mov     dword [rcx], 0

    ; Software consumes event entry by clearing it.
    mov     qword [r8 + 0], 0
    mov     dword [r8 + 8], 0
    mov     dword [r8 + 12], 0

    mov     eax, [xhci_evt_deq_idx]
    inc     eax
    cmp     eax, EVT_RING_NTRB
    jb      .ep_store_next
    mov     eax, 0
    mov     edx, [xhci_evt_cycle]
    xor     edx, 1
    mov     [xhci_evt_cycle], edx
.ep_store_next:
    mov     [xhci_evt_deq_idx], eax
    mov     eax, 1
    er_ok
    ret

.ep_empty:
    xor     eax, eax
    er_ok
    ret
.ep_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

; ==================================================================
; er_xhci_cmd_wait_completion — wait for command completion event
; int er_xhci_cmd_wait_completion(uint32_t spins, uint32_t* out_cc)
; Returns: 0 on command completion, -1 on timeout/bad args/failure.
; ==================================================================
er_fn er_xhci_cmd_wait_completion
    test    rsi, rsi
    jz      .cw_bad_arg
    test    edi, edi
    jz      .cw_bad_arg

    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; spins remaining

.cw_poll:
    lea     rdi, [rel xhci_cw_p0]
    lea     rsi, [rel xhci_cw_st]
    lea     rdx, [rel xhci_cw_ctl]
    lea     rcx, [rel xhci_cw_rsv]
    call    er_xhci_event_pop
    cmp     eax, 1
    je      .cw_have_evt
    cmp     eax, 0
    jne     .cw_fail
    dec     r12d
    jnz     .cw_poll
    jmp     .cw_timeout

.cw_have_evt:
    mov     eax, [rel xhci_cw_ctl]
    and     eax, TRB_TYPE_MASK
    cmp     eax, (TRB_EV_CMD_CMPL << TRB_TYPE_SHIFT)
    jne     .cw_skip
    mov     eax, [rel xhci_cw_st]
    shr     eax, 24
    and     eax, 0xFF
    mov     [rsi], eax
    cmp     eax, XHCI_CC_SUCCESS
    jne     .cw_fail
    xor     eax, eax
    er_ok
    jmp     .cw_out

.cw_skip:
    dec     r12d
    jnz     .cw_poll
    jmp     .cw_timeout

.cw_timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
    jmp     .cw_out

.cw_fail:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
    jmp     .cw_out

.cw_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

.cw_out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret
