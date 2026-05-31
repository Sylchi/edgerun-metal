; EdgeRun AMDGPU display driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Target: RDNA3 integrated GPU (Radeon 780M on Phoenix/7840U)
; PCI vendor 0x1002 (AMD), class 0x03/0x00/0x00 (VGA-compatible display)

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "driver/amdgpu_constants.inc"

extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32
extern er_mmio_write32
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_puthex64
extern er_serial_putdec32
extern er_serial_putchar
extern er_serial_crlf
extern er_serial_putnewline
extern er_serial_getchar

; PCI BAR offsets (replicated from pci.asm for standalone assembly)
%define PCI_BAR0    0x10
%define PCI_BAR1    0x14
%define PCI_BAR2    0x18
%define PCI_BAR3    0x1C

SECTION .data

str_bar0:      db " regs ", 0
str_bar2:      db " fb ", 0
str_rev:       db " rev 0x", 0
str_gpu_id:    db " id 0x", 0
str_pg:        db " pg ", 0
str_clk:       db " clk ", 0
str_otg:       db " otg ", 0
str_hubp:      db " hubp ", 0
amdgpu_timing_1080p60:
    dd 2200, 1968, 2000, 1920, 128
    dd 1125, 1083, 1088, 1080, 4
amdgpu_timing_720p60:
    dd 1650, 1390, 1430, 1280, 370
    dd 750, 725, 730, 720, 30

SECTION .text

; Helper: MMIO read from BAR0 + offset
; rdi = bar0, rsi = byte_offset
; returns eax = value
_mmio_read:
    mov     eax, [rdi + rsi]
    ret

; Helper: MMIO write 32 to BAR0 + offset
; rdi = bar0, rsi = byte_offset, edx = value
_mmio_write:
    mov     [rdi + rsi], edx
    ret

; ==================================================================
; er_amdgpu_probe — probe AMDGPU at given PCI location
; int er_amdgpu_probe(uint8_t bus, uint8_t dev, uint8_t func,
;                     uint64_t* out_bar0, uint64_t* out_bar2)
; ==================================================================
er_fn er_amdgpu_probe
    push    r8
    push    r9
    push    r10
    push    r11
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rcx            ; out_bar0
    mov     r13, r8             ; out_bar2
    mov     r14d, edi           ; bus
    mov     r15d, esi           ; dev
    mov     ebx, edx            ; func

    ; Verify vendor ID
    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .no_dev
    and     eax, 0xFFFF
    cmp     ax, AMD_VENDOR_ID
    jne     .no_dev

    ; Read BAR0 (MMIO registers)
    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    mov     ecx, PCI_BAR0
    call    er_pci_read32
    mov     r8d, eax

    test    al, 1
    jnz     .bad_bar
    test    al, 4
    jz      .bar0_32

    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    mov     ecx, PCI_BAR1
    call    er_pci_read32
    shl     rax, 32
    mov     r8d, r8d
    or      r8, rax

.bar0_32:
    mov     rax, r8
    and     rax, ~0x0F
    mov     r8, rax

    ; Read BAR2 (framebuffer aperture)
    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    mov     ecx, PCI_BAR2
    call    er_pci_read32
    mov     r9d, eax

    test    al, 1
    jnz     .bar2_absent
    test    al, 4
    jz      .bar2_32

    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    mov     ecx, PCI_BAR3
    call    er_pci_read32
    shl     rax, 32
    mov     r9d, r9d
    or      r9, rax

.bar2_32:
    mov     rax, r9
    and     rax, ~0x0F
    mov     r9, rax
    jmp     .bar2_done

.bar2_absent:
    xor     r9, r9

.bar2_done:
    ; Verify GPU responds to MMIO read on BAR0
    mov     rdi, r8
    add     rdi, mmCC_DRM_ID * 4
    call    er_mmio_read32
    cmp     eax, 0xFFFFFFFF
    je      .no_dev

    test    r12, r12
    jz      .skip_bar0_store
    mov     [r12], r8
.skip_bar0_store:
    test    r13, r13
    jz      .skip_bar2_store
    mov     [r13], r9
.skip_bar2_store:

    ; Enable bus mastering + memory space in PCI command register
    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    mov     ecx, 0x04
    call    er_pci_read32
    or      ax, 0x0006
    mov     r8d, eax
    mov     rdi, r14
    mov     rsi, r15
    mov     rdx, rbx
    mov     ecx, 0x04
    call    er_pci_write32

    xor     eax, eax
    er_ok
    jmp     .out

.no_dev:
    er_err  ERROR_NOT_PRESENT
    jmp     .out

.bad_bar:
    er_err  ERROR_UNSUPPORTED

.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret

; ==================================================================
; er_amdgpu_print_info — print AMDGPU info via serial
; ==================================================================
er_fn er_amdgpu_print_info
    push    r12
    push    r13

    mov     r12, rdi            ; BAR0
    mov     r13w, si            ; port

    mov     rdi, r13
    lea     rsi, [rel str_bar0]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, r12d
    call    er_serial_puthex32

    ; Read chip revision
    mov     rdi, r12
    add     rdi, mmCHIP_REVISION * 4
    call    er_mmio_read32
    and     eax, 0xFF

    push    rax
    mov     rdi, r13
    lea     rsi, [rel str_rev]
    call    er_serial_puts
    pop     rax
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    ; Read GPU ID
    mov     rdi, r12
    add     rdi, mmCC_DRM_ID * 4
    call    er_mmio_read32

    mov     rdi, r13
    lea     rsi, [rel str_gpu_id]
    call    er_serial_puts
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    pop     r13
    pop     r12
    ret

; ==================================================================
; er_amdgpu_dcn_dump_regs — dump DCN register state via serial
; void er_amdgpu_dcn_dump_regs(uint64_t bar0, uint16_t port)
; ==================================================================
er_fn er_amdgpu_dcn_dump_regs
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; BAR0
    mov     r13w, si            ; port

    ; Dump power gate status registers
    mov     rdi, r13
    lea     rsi, [rel str_pg]
    call    er_serial_puts

    ; Read and print DOMAIN0_PG_STATUS
    mov     rdi, r12
    mov     esi, DCN_DOMAIN0_PG_STATUS
    call    _mmio_read
    mov     r14d, eax
    mov     rdi, r13
    mov     esi, r14d
    call    er_serial_puthex32

    mov     rdi, r13
    mov     sil, ' '
    call    er_serial_putchar

    ; DOMAIN16_PG_STATUS (DSC0)
    mov     rdi, r12
    mov     esi, DCN_DOMAIN16_PG_STATUS
    call    _mmio_read
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    call    er_serial_crlf

    ; Dump clock gating status
    mov     rdi, r13
    lea     rsi, [rel str_clk]
    call    er_serial_puts

    mov     rdi, r12
    mov     esi, DCN_DCCG_GATE_DISABLE_CNTL
    call    _mmio_read
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    call    er_serial_crlf

    ; Dump OTG0 status
    mov     rdi, r13
    lea     rsi, [rel str_otg]
    call    er_serial_puts

    mov     rdi, r12
    mov     esi, DCN_OTG0_CONTROL
    call    _mmio_read
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    mov     rdi, r13
    mov     sil, ' '
    call    er_serial_putchar

    mov     rdi, r12
    mov     esi, DCN_OTG0_MASTER_EN
    call    _mmio_read
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    call    er_serial_crlf

    ; Dump HUBP0 status
    mov     rdi, r13
    lea     rsi, [rel str_hubp]
    call    er_serial_puts

    mov     rdi, r12
    mov     esi, DCN_HUBP0_DCHUBP_CNTL
    call    _mmio_read
    mov     rdi, r13
    mov     esi, eax
    call    er_serial_puthex32

    call    er_serial_crlf

    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_amdgpu_dcn_init — DCN 3.1 display init
; int er_amdgpu_dcn_init(uint64_t bar0, uint64_t fb_addr)
; ==================================================================
er_fn er_amdgpu_dcn_init
    push    r12
    push    r13
    push    r14
    push    r15

    test    rdi, rdi
    jz      .bad_arg
    mov     r12, rdi            ; BAR0
    mov     r13, rsi            ; fb_addr

    ; ─── Step 1: IP Request Enable ───
    ; Enable IP request access (needed for power gating control)
    mov     rdi, r12
    mov     esi, DCN_DC_IP_REQUEST_CNTL
    mov     edx, 0x00000001     ; IP_REQUEST_EN = 1
    call    _mmio_write

    ; ─── Step 2: Clock gating ───
    ; Write 0 to DCCG_GATE_DISABLE_CNTL to enable all clock gating
    mov     rdi, r12
    mov     esi, DCN_DCCG_GATE_DISABLE_CNTL
    xor     edx, edx
    call    _mmio_write

    ; DCCG_GATE_DISABLE_CNTL2 = 0
    mov     rdi, r12
    mov     esi, DCN_DCCG_GATE_DISABLE_CNTL2
    xor     edx, edx
    call    _mmio_write

    ; DCFCLK_CNTL: DCFCLK_GATE_DIS = 0 (bit 31)
    ; Read-modify-write to clear bit 31
    mov     rdi, r12
    mov     esi, DCN_DCFCLK_CNTL
    call    _mmio_read
    and     eax, 0x7FFFFFFF     ; clear bit 31
    mov     edx, eax
    mov     rdi, r12
    mov     esi, DCN_DCFCLK_CNTL
    call    _mmio_write

    ; ─── Step 3: Domain power gating ───
    ; Clear DOMAIN_POWER_FORCEON for all HUBP/DPP domains (enable power gating)
    ; This lets the hardware power gate unused domains
    ; For now, keep force_on = true (disable power gating) for stability
    ; DOMAIN0_PG_CONFIG: DOMAIN_POWER_FORCEON = 1, DOMAIN_POWER_GATE = 0
    mov     rdi, r12
    mov     esi, DCN_DOMAIN0_PG_CONFIG
    mov     edx, 0x00000001     ; FORCEON=1, GATE=0
    call    _mmio_write

    mov     rdi, r12
    mov     esi, DCN_DOMAIN1_PG_CONFIG
    mov     edx, 0x00000001
    call    _mmio_write

    mov     rdi, r12
    mov     esi, DCN_DOMAIN2_PG_CONFIG
    mov     edx, 0x00000001
    call    _mmio_write

    mov     rdi, r12
    mov     esi, DCN_DOMAIN3_PG_CONFIG
    mov     edx, 0x00000001
    call    _mmio_write

    ; DSC domains
    mov     rdi, r12
    mov     esi, DCN_DOMAIN16_PG_CONFIG
    mov     edx, 0x00000001
    call    _mmio_write

    mov     rdi, r12
    mov     esi, DCN_DOMAIN17_PG_CONFIG
    mov     edx, 0x00000001
    call    _mmio_write

    mov     rdi, r12
    mov     esi, DCN_DOMAIN18_PG_CONFIG
    mov     edx, 0x00000001
    call    _mmio_write

    ; ─── Step 4: HPO HW control ───
    ; Disable HPO IO (no high-speed display output yet)
    mov     rdi, r12
    mov     esi, DCN_HPO_TOP_HW_CONTROL
    xor     edx, edx
    call    _mmio_write

    ; ─── Step 5: DIO memory power on ───
    ; Write 0 to DIO_MEM_PWR_CTRL to power on DIO memory
    mov     rdi, r12
    mov     esi, DCN_DIO_MEM_PWR_CTRL
    xor     edx, edx
    call    _mmio_write

    ; ─── Step 6: DCHUBBUB global timer ───
    ; Enable global timer, set refdiv = 2
    mov     rdi, r12
    mov     esi, DCN_DCHUBBUB_GLOBAL_TIMER_CNTL
    mov     edx, 0x00001202     ; REFDIV=2, ENABLE=1 (bit 12)
    call    _mmio_write

    ; ─── Step 7: Clear IP request enable ───
    mov     rdi, r12
    mov     esi, DCN_DC_IP_REQUEST_CNTL
    xor     edx, edx
    call    _mmio_write

    ; ─── Step 8: Write test pattern to framebuffer ───
    test    r13, r13
    jz      .no_fb

    mov     rdi, r13
    call    _write_test_pattern
    sub     rsp, 24
    mov     [rsp + AMDGPU_SCANOUT_ADDR_LO], r13d
    mov     rax, r13
    shr     rax, 32
    mov     [rsp + AMDGPU_SCANOUT_ADDR_HI], eax
    mov     dword [rsp + AMDGPU_SCANOUT_PITCH_PIXELS], AMDGPU_FB_WIDTH
    mov     dword [rsp + AMDGPU_SCANOUT_WIDTH], AMDGPU_FB_WIDTH
    mov     dword [rsp + AMDGPU_SCANOUT_HEIGHT], AMDGPU_FB_HEIGHT
    mov     rdi, r12
    mov     rsi, rsp
    call    er_amdgpu_program_hubp0_scanout
    add     rsp, 24
    test    eax, eax
    jnz     .fail

    ; ─── Step 9: Basic OTG0 timing ───
    mov     rdi, r12
    mov     esi, AMDGPU_MODE_1080P60
    call    er_amdgpu_program_otg0_mode
    test    eax, eax
    jnz     .fail

.no_fb:
    xor     eax, eax
    er_ok
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
.fail:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_amdgpu_program_hubp0_scanout — program HUBP0 surface state
; int er_amdgpu_program_hubp0_scanout(uint64_t bar0, const uint32_t* cfg)
; ==================================================================
er_fn er_amdgpu_program_hubp0_scanout
    mov     rdx, rsi
    xor     esi, esi
    jmp     er_amdgpu_program_hubp_scanout

; ==================================================================
; er_amdgpu_program_hubp_scanout — program HUBP surface state
; int er_amdgpu_program_hubp_scanout(uint64_t bar0, uint32_t pipe,
;                                    const uint32_t* cfg)
; ==================================================================
er_fn er_amdgpu_program_hubp_scanout
    push    r12
    push    r13
    push    r14
    test    rdi, rdi
    jz      .bad_arg
    cmp     esi, DCN_HUBP_PIPE_COUNT
    jae     .bad_arg
    mov     r12, rdi
    mov     r13, rdx
    mov     r14d, esi
    mov     rdi, r13
    call    er_amdgpu_validate_scanout_config
    test    eax, eax
    jnz     .bad_arg
    mov     eax, r14d
    imul    eax, DCN_HUBP_PIPE_STRIDE
    mov     r14d, eax
    mov     edx, [r13 + AMDGPU_SCANOUT_PITCH_PIXELS]
    mov     rdi, r12
    lea     esi, [r14d + DCN_HUBP0_SURFACE_PITCH]
    call    _mmio_write
    mov     edx, [r13 + AMDGPU_SCANOUT_ADDR_LO]
    mov     rdi, r12
    lea     esi, [r14d + DCN_HUBP0_PRIMARY_SURFACE_ADDR]
    call    _mmio_write
    mov     edx, [r13 + AMDGPU_SCANOUT_ADDR_HI]
    mov     rdi, r12
    lea     esi, [r14d + DCN_HUBP0_PRIMARY_SURFACE_ADDR + 4]
    call    _mmio_write
    xor     edx, edx
    mov     rdi, r12
    lea     esi, [r14d + DCN_HUBP0_FLIP_CONTROL]
    call    _mmio_write
    mov     edx, 1
    mov     rdi, r12
    lea     esi, [r14d + DCN_HUBP0_DCHUBP_CNTL]
    call    _mmio_write
    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    ret

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_amdgpu_validate_scanout_config — validate scanout config fields
; int er_amdgpu_validate_scanout_config(const uint32_t* cfg)
; ==================================================================
er_fn er_amdgpu_validate_scanout_config
    test    rdi, rdi
    jz      .bad_arg
    mov     edx, [rdi + AMDGPU_SCANOUT_PITCH_PIXELS]
    test    edx, edx
    jz      .bad_arg
    mov     eax, [rdi + AMDGPU_SCANOUT_WIDTH]
    test    eax, eax
    jz      .bad_arg
    cmp     edx, eax
    jb      .bad_arg
    mov     eax, [rdi + AMDGPU_SCANOUT_HEIGHT]
    test    eax, eax
    jz      .bad_arg
    xor     eax, eax
    er_ok
    ret
.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

; ==================================================================
; er_amdgpu_validate_timing — validate OTG timing fields
; int er_amdgpu_validate_timing(const uint32_t* timing)
; ==================================================================
er_fn er_amdgpu_validate_timing
    test    rdi, rdi
    jz      .bad_arg

    mov     ecx, [rdi + AMDGPU_TIMING_H_TOTAL]
    test    ecx, ecx
    jz      .bad_arg
    mov     eax, [rdi + AMDGPU_TIMING_H_SYNC_START]
    mov     edx, [rdi + AMDGPU_TIMING_H_SYNC_END]
    cmp     eax, edx
    jae     .bad_arg
    cmp     edx, ecx
    ja      .bad_arg
    mov     eax, [rdi + AMDGPU_TIMING_H_BLANK_START]
    test    eax, eax
    jz      .bad_arg
    cmp     eax, ecx
    ja      .bad_arg
    mov     edx, [rdi + AMDGPU_TIMING_H_BLANK_END]
    cmp     edx, eax
    jae     .bad_arg

    mov     ecx, [rdi + AMDGPU_TIMING_V_TOTAL]
    test    ecx, ecx
    jz      .bad_arg
    mov     eax, [rdi + AMDGPU_TIMING_V_SYNC_START]
    mov     edx, [rdi + AMDGPU_TIMING_V_SYNC_END]
    cmp     eax, edx
    jae     .bad_arg
    cmp     edx, ecx
    ja      .bad_arg
    mov     eax, [rdi + AMDGPU_TIMING_V_BLANK_START]
    test    eax, eax
    jz      .bad_arg
    cmp     eax, ecx
    ja      .bad_arg
    mov     edx, [rdi + AMDGPU_TIMING_V_BLANK_END]
    cmp     edx, eax
    jae     .bad_arg

    xor     eax, eax
    er_ok
    ret
.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    ret

; ==================================================================
; er_amdgpu_program_otg0_mode — program OTG0 using a known mode ID
; int er_amdgpu_program_otg0_mode(uint64_t bar0, uint32_t mode)
; ==================================================================
er_fn er_amdgpu_program_otg0_mode
    mov     edx, esi
    xor     esi, esi
    jmp     er_amdgpu_program_otg_mode

; ==================================================================
; er_amdgpu_program_otg_mode — program OTG timing using a known mode ID
; int er_amdgpu_program_otg_mode(uint64_t bar0, uint32_t pipe, uint32_t mode)
; ==================================================================
er_fn er_amdgpu_program_otg_mode
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13d, esi
    cmp     esi, DCN_OTG_PIPE_COUNT
    jae     .bad_arg
    cmp     edx, AMDGPU_MODE_1080P60
    je      .mode_1080
    cmp     edx, AMDGPU_MODE_720P60
    je      .mode_720
.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    pop     r13
    pop     r12
    ret
.mode_1080:
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rel amdgpu_timing_1080p60]
    call    er_amdgpu_program_otg_timing
    pop     r13
    pop     r12
    ret
.mode_720:
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rel amdgpu_timing_720p60]
    call    er_amdgpu_program_otg_timing
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_amdgpu_program_otg0_timing — program OTG0 from timing struct
; int er_amdgpu_program_otg0_timing(uint64_t bar0, const uint32_t* timing)
; ==================================================================
er_fn er_amdgpu_program_otg0_timing
    mov     rdx, rsi
    xor     esi, esi
    jmp     er_amdgpu_program_otg_timing

; ==================================================================
; er_amdgpu_program_otg_timing — program OTG from timing struct
; int er_amdgpu_program_otg_timing(uint64_t bar0, uint32_t pipe,
;                                  const uint32_t* timing)
; ==================================================================
er_fn er_amdgpu_program_otg_timing
    push    r12
    push    r13
    push    r14
    test    rdi, rdi
    jz      .bad_arg
    cmp     esi, DCN_OTG_PIPE_COUNT
    jae     .bad_arg
    mov     r12, rdi            ; bar0
    mov     r13, rdx            ; timing
    mov     r14d, esi
    mov     rdi, r13
    call    er_amdgpu_validate_timing
    test    eax, eax
    jnz     .bad_arg
    mov     eax, r14d
    imul    eax, DCN_OTG_PIPE_STRIDE
    mov     r14d, eax

    ; Set V_TOTAL
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_V_TOTAL]
    mov     edx, [r13 + AMDGPU_TIMING_V_TOTAL]
    dec     edx
    call    _mmio_write

    ; Set H_TOTAL
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_H_TOTAL]
    mov     edx, [r13 + AMDGPU_TIMING_H_TOTAL]
    dec     edx
    call    _mmio_write

    ; Set H_SYNC_A: bits 15:0 = start, bits 31:16 = end - 1.
    mov     edx, [r13 + AMDGPU_TIMING_H_SYNC_END]
    dec     edx
    shl     edx, 16
    mov     eax, [r13 + AMDGPU_TIMING_H_SYNC_START]
    and     eax, 0xffff
    or      edx, eax
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_H_SYNC_A]
    call    _mmio_write

    ; Set V_SYNC_A
    mov     edx, [r13 + AMDGPU_TIMING_V_SYNC_END]
    dec     edx
    shl     edx, 16
    mov     eax, [r13 + AMDGPU_TIMING_V_SYNC_START]
    and     eax, 0xffff
    or      edx, eax
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_V_SYNC_A]
    call    _mmio_write

    ; Set H_BLANK_START_END
    mov     edx, [r13 + AMDGPU_TIMING_H_BLANK_START]
    dec     edx
    shl     edx, 16
    mov     eax, [r13 + AMDGPU_TIMING_H_BLANK_END]
    and     eax, 0xffff
    or      edx, eax
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_H_BLANK_START_END]
    call    _mmio_write

    ; Set V_BLANK_START_END
    mov     edx, [r13 + AMDGPU_TIMING_V_BLANK_START]
    dec     edx
    shl     edx, 16
    mov     eax, [r13 + AMDGPU_TIMING_V_BLANK_END]
    and     eax, 0xffff
    or      edx, eax
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_V_BLANK_START_END]
    call    _mmio_write

    ; Disable interlace
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_INTERLACE_CONTROL]
    xor     edx, edx
    call    _mmio_write

    ; Enable OTG master
    mov     rdi, r12
    lea     esi, [r14d + DCN_OTG0_MASTER_EN]
    mov     edx, 1
    call    _mmio_write

    xor     eax, eax
    er_ok
    pop     r14
    pop     r13
    pop     r12
    ret

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; _write_test_pattern — write colored bars to framebuffer
; rdi = framebuffer physical address
;
; Writes 8 vertical color bars from left to right:
;   White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
; Each bar is AMDGPU_FB_WIDTH/8 pixels wide, full height
; Format: XRGB8888 (32-bit, little-endian)
; ==================================================================
_write_test_pattern:
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; fb base

    ; Color values (AABBGGRR little-endian for XRGB8888):
    ; White:   0x00FFFFFF
    ; Yellow:  0x0000FFFF
    ; Cyan:    0x00FFFF00
    ; Green:   0x0000FF00
    ; Magenta: 0x00FF00FF
    ; Red:     0x000000FF
    ; Blue:    0x00FF0000
    ; Black:   0x00000000

    xor     r13d, r13d          ; y = 0
.tb_y_loop:
    cmp     r13d, AMDGPU_FB_HEIGHT
    jae     .tb_done

    xor     r14d, r14d          ; x pixel = 0
    ; r15 = row start = fb + y * pitch
    mov     eax, r13d
    mov     ecx, AMDGPU_FB_PITCH
    mul     ecx                 ; eax = y * pitch
    mov     r15, r12
    add     r15, rax            ; r15 = &fb[y * pitch]

.tb_x_loop:
    cmp     r14d, AMDGPU_FB_WIDTH
    jae     .tb_next_y

    ; Determine bar index (0-7)
    mov     eax, r14d
    xor     edx, edx
    mov     ecx, (AMDGPU_FB_WIDTH + 7) / 8
    div     ecx
    ; eax = bar index (0-7)

    ; Select color
    xor     ebx, ebx
.tb_color_branch:
    cmp     eax, 0
    jne     .tb_c1
    mov     ebx, 0x00FFFFFF     ; White
    jmp     .tb_write_pixel
.tb_c1:
    cmp     eax, 1
    jne     .tb_c2
    mov     ebx, 0x0000FFFF     ; Yellow
    jmp     .tb_write_pixel
.tb_c2:
    cmp     eax, 2
    jne     .tb_c3
    mov     ebx, 0x00FFFF00     ; Cyan
    jmp     .tb_write_pixel
.tb_c3:
    cmp     eax, 3
    jne     .tb_c4
    mov     ebx, 0x0000FF00     ; Green
    jmp     .tb_write_pixel
.tb_c4:
    cmp     eax, 4
    jne     .tb_c5
    mov     ebx, 0x00FF00FF     ; Magenta
    jmp     .tb_write_pixel
.tb_c5:
    cmp     eax, 5
    jne     .tb_c6
    mov     ebx, 0x000000FF     ; Red
    jmp     .tb_write_pixel
.tb_c6:
    cmp     eax, 6
    jne     .tb_c7
    mov     ebx, 0x00FF0000     ; Blue
    jmp     .tb_write_pixel
.tb_c7:
    xor     ebx, ebx            ; Black

.tb_write_pixel:
    ; mem[fb + y*pitch + x*4] = color
    mov     [r15 + r14 * 4], ebx
    inc     r14d
    jmp     .tb_x_loop

.tb_next_y:
    inc     r13d
    jmp     .tb_y_loop

.tb_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_amdgpu_init — basic AMDGPU init
; int er_amdgpu_init(uint64_t bar0)
; ==================================================================
er_fn er_amdgpu_init
    push    r12

    mov     r12, rdi            ; BAR0

    ; Disable interrupts
    mov     rdi, r12
    lea     rdi, [rdi + 0x1590 * 4]
    xor     esi, esi
    call    er_mmio_write32

    xor     eax, eax
    er_ok
    pop     r12
    ret
