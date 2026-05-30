; EdgeRun Intel KBL/Gen9 GPU display driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Intel HD Graphics 615 (KBL GT2, PCI 8086:591e) — Surface Go 1
; eDP panel: 1800×1200@60
;
; Functions:
;   er_intel_gpu_probe(bus, dev, func, out_bar0, out_bar2)
;   er_intel_gpu_detect_pipe(bar0, pipe)
;   er_intel_gpu_write_test_pattern(bar2, scanout_offset)

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/drv/intel_gpu_constants.inc"

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

SECTION .text

; ==================================================================
; er_intel_gpu_probe — probe Intel GPU at PCI location
; int er_intel_gpu_probe(uint8_t bus, uint8_t dev, uint8_t func,
;                        uint32_t* out_bar0, uint32_t* out_bar2)
;
; rdi=bus, esi=dev, edx=func, rcx=out_bar0, r8=out_bar2
; Enables bus master + memory space, reads BAR0 (MMIO) and BAR2 (aperture).
; Returns: eax=0 on success, rdx=0 on success
;          eax=-1 on failure, rdx=error code
;          *out_bar0 = MMIO base (BAR0), *out_bar2 = aperture base (BAR2)
; ==================================================================
er_fn er_intel_gpu_probe
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi            ; bus
    mov     r13d, esi            ; dev
    mov     r14d, edx            ; func
    mov     r15, rcx             ; out_bar0
    push    r8                   ; save out_bar2

    ; Verify device exists and is Intel GPU
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .not_found

    movzx   ebx, ax              ; device ID
    shr     eax, 16              ; vendor ID
    cmp     eax, PCI_INTEL_VENDOR
    jne     .not_found

    ; Check if it's a known KBL GT2 device
    cmp     ebx, PCI_KBL_GT2_HD615
    je      .found
    cmp     ebx, PCI_KBL_GT2_HD620
    je      .found
    cmp     ebx, PCI_KBL_GT2_UHD620
    jne     .not_found

.found:
    ; Read BAR0 (MMIO registers)
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x10
    call    er_pci_read32
    and     eax, 0xFFFFFFF0
    mov     ebx, eax
    mov     [r15], ebx

    ; Read BAR2 (aperture)
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x18
    call    er_pci_read32
    and     eax, 0xFFFFFFF0

    pop     r8                   ; out_bar2
    test    r8, r8
    jz      .no_out_bar2
    mov     [r8], eax

.no_out_bar2:
    ; Enable bus mastering + memory space + io space
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x04
    call    er_pci_read32
    or      eax, 0x07            ; mem + io + bus master
    mov     r8, rax
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, r14d
    mov     ecx, 0x04
    call    er_pci_write32

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.not_found:
    pop     r8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret

; ==================================================================
; er_intel_gpu_detect_pipe — read display pipe status
; int er_intel_gpu_detect_pipe(uint32_t bar0, uint32_t pipe,
;                              uint32_t* out_surf, uint32_t* out_width,
;                              uint32_t* out_height)
;
; rdi=bar0, esi=pipe (0=A, 1=B, 2=C),
; rdx=out_surf, rcx=out_width, r8=out_height
;
; Returns: eax = 0 if pipe is active, -1 if disabled
;          *out_surf = current surface base address (from PLANE_SURF)
;          *out_width, *out_height = pipe dimensions
; ==================================================================
er_fn er_intel_gpu_detect_pipe
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    r8                ; save out_height (not callee-saved)

    mov     r12d, edi            ; bar0
    mov     r13d, esi            ; pipe (0=A, 1=B, 2=C)
    mov     r14, rdx             ; out_surf
    mov     r15, rcx             ; out_width

    ; Compute pipe register base: _PIPE_A + pipe * 0x1000
    mov     eax, r13d
    shl     eax, 12              ; pipe << 12
    add     eax, _PIPE_A
    mov     ebx, eax             ; ebx = pipe_base

    ; Read PIPECONF (pipe_base + 0x08)
    mov     rdi, r12
    add     rdi, rbx
    add     rdi, 0x08
    call    er_mmio_read32

    ; Check if pipe is enabled (bit 31)
    test    eax, eax
    jns     .pipe_off            ; bit 31 = 0 means disabled

    ; Pipe is active — read surface address
    ; PLANE_SURF(pipe,1) = pipe_base + 0x19C
    mov     rdi, r12
    add     rdi, rbx
    add     rdi, 0x19C
    call    er_mmio_read32
    mov     ecx, eax             ; ecx = surface address

    test    r14, r14
    jz      .skip_surf
    mov     [r14], ecx

.skip_surf:
    ; Read pipe source size (PIPESRC = pipe_base + 0x0C)
    mov     rdi, r12
    add     rdi, rbx
    add     rdi, 0x0C
    call    er_mmio_read32

    ; bits 15:0 = width-1, bits 31:16 = height-1
    ; Save eax (PIPESRC value) before clobbering
    mov     ebx, eax             ; ebx = PIPESRC value

    test    r15, r15
    jz      .skip_width
    mov     ecx, ebx
    and     ecx, 0xFFFF
    inc     ecx
    mov     [r15], ecx

.skip_width:
    ; out_height from saved r8 on stack
    mov     r8, [rsp]            ; saved r8 = out_height pointer
    test    r8, r8
    jz      .skip_height
    mov     ecx, ebx
    shr     ecx, 16
    and     ecx, 0xFFFF
    inc     ecx
    mov     [r8], ecx

.skip_height:
    pop     r8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.pipe_off:
    pop     r8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    ret

; ==================================================================
; er_intel_gpu_write_test_pattern — write 4-bar test pattern to
; framebuffer using PIO to aperture
;
; void er_intel_gpu_write_test_pattern(uint32_t aperture,
;                                      uint32_t scanout_offset,
;                                      uint32_t width, uint32_t height)
;
; rdi=aperture (BAR2), esi=scanout_offset, edx=width, ecx=height
; ==================================================================
er_fn er_intel_gpu_write_test_pattern
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi            ; aperture base
    mov     r13d, esi            ; scanout offset in aperture
    mov     r14d, edx            ; width
    mov     r15d, ecx            ; height

    ; Compute stride (32bpp = width * 4)
    mov     eax, r14d
    shl     eax, 2               ; width * 4
    mov     ebx, eax             ; ebx = stride

    ; Colors: white, green, blue, red (32-bit ARGB)
    ; Write 4 vertical bars
    mov     r8d, r14d
    shr     r8d, 2               ; quarter-width

    ; For each row
    xor     r10d, r10d           ; y = 0
.row_loop:
    cmp     r10d, r15d
    jae     .done

    ; Compute row base: aperture + scanout_offset + y * stride
    mov     eax, r10d
    mul     ebx
    add     eax, r13d
    add     eax, r12d            ; absolute aperture address
    mov     r11d, eax            ; row_start

    ; Bar 0: white (0xFFFFFFFF)
    mov     edi, eax
    xor     r9d, r9d
.bar0_loop:
    cmp     r9d, r8d
    jae     .bar0_done
    mov     dword [rdi], 0xFFFFFFFF
    add     edi, 4
    inc     r9d
    jmp     .bar0_loop
.bar0_done:

    ; Bar 1: red (0xFFFF0000)
    xor     r9d, r9d
.bar1_loop:
    cmp     r9d, r8d
    jae     .bar1_done
    mov     dword [rdi], 0xFFFF0000
    add     edi, 4
    inc     r9d
    jmp     .bar1_loop
.bar1_done:

    ; Bar 2: green (0xFF00FF00)
    xor     r9d, r9d
.bar2_loop:
    cmp     r9d, r8d
    jae     .bar2_done
    mov     dword [rdi], 0xFF00FF00
    add     edi, 4
    inc     r9d
    jmp     .bar2_loop
.bar2_done:

    ; Bar 3: blue (0xFF0000FF)
    xor     r9d, r9d
.bar3_loop:
    cmp     r9d, r8d
    jae     .bar3_done
    mov     dword [rdi], 0xFF0000FF
    add     edi, 4
    inc     r9d
    jmp     .bar3_loop
.bar3_done:

    inc     r10d
    jmp     .row_loop

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

; ==================================================================
; er_intel_gpu_print_pipe_info — print pipe status via serial
; void er_intel_gpu_print_pipe_info(uint32_t bar0, uint32_t pipe,
;                                   uint64_t com_port)
;
; rdi=bar0, esi=pipe, rdx=com_port
; ==================================================================
er_fn er_intel_gpu_print_pipe_info
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi            ; bar0
    mov     r13d, esi            ; pipe
    mov     r14, rdx             ; port

    sub     rsp, 16

    ; Detect pipe
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp]           ; out_surf
    lea     rcx, [rsp + 4]       ; out_width
    lea     r8, [rsp + 8]        ; out_height
    call    er_intel_gpu_detect_pipe
    test    eax, eax
    jnz     .inactive

    mov     rdi, r14
    lea     rsi, [rel .pipe_str]
    call    er_serial_puts
    mov     rdi, r14
    mov     esi, r13d
    call    er_serial_putdec32

    mov     rdi, r14
    lea     rsi, [rel .res_str]
    call    er_serial_puts
    mov     rdi, r14
    mov     esi, [rsp + 4]       ; width
    call    er_serial_putdec32
    mov     rdi, r14
    mov     sil, 'x'
    call    er_serial_putchar
    mov     rdi, r14
    mov     esi, [rsp + 8]       ; height
    call    er_serial_putdec32

    mov     rdi, r14
    lea     rsi, [rel .surf_str]
    call    er_serial_puts
    mov     rdi, r14
    mov     esi, [rsp]           ; surface address
    call    er_serial_puthex32
    jmp     .done

.inactive:
    mov     rdi, r14
    lea     rsi, [rel .inactive_str]
    call    er_serial_puts
    mov     rdi, r14
    mov     esi, r13d
    call    er_serial_putdec32

.done:
    mov     rdi, r14
    call    er_serial_crlf
    add     rsp, 16
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.pipe_str:    db " pipe ", 0
.res_str:     db " active ", 0
.surf_str:    db " surf 0x", 0
.inactive_str: db " pipe ", 0
