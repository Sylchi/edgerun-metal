; EdgeRun display driver — x86_64 assembly
; System V AMD64 ABI, freestanding.
;
; Primary path: linear framebuffer (multiboot-provided UEFI GOP).
;
; Framebuffer text rendering delegates to fb_text.asm (alpha8 atlas).

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

%define VGA_TEXT_BUF     0xB8000
%define VGA_COLS         80
%define VGA_ROWS         25
%define VGA_ATTR         0x07

; Bochs VBE IO ports
%define VBE_DISPI_IOPORT_INDEX  0x1CE
%define VBE_DISPI_IOPORT_DATA   0x1CF

; Bochs VBE index register values
%define VBE_DISPI_INDEX_ID      0
%define VBE_DISPI_INDEX_XRES    1
%define VBE_DISPI_INDEX_YRES    2
%define VBE_DISPI_INDEX_BPP     3
%define VBE_DISPI_INDEX_ENABLE  4

; Bochs VBE enable flags
%define VBE_DISPI_DISABLED      0x00
%define VBE_DISPI_ENABLED       0x01
%define VBE_DISPI_LFB_ENABLED   0x40
%define VBE_DISPI_NOCLEARMEM    0x80

; Bochs PCI vendor/device IDs
%define BOCHS_VENDOR            0x1234
%define BOCHS_VGA_DEV           0x1111

SECTION .data
vga_cursor:      dd 0
display_mode:    db 0        ; 0=unavailable, 1=framebuffer

SECTION .text

extern er_fb_text_init
extern er_fb_text_putchar
extern er_fb_text_puts
extern er_fb_text_clear

extern fb_addr, fb_width, fb_height, fb_pitch
extern er_pci_read32
extern er_memset

; ==================================================================
; er_display_init — initialize display
; void er_display_init(void)
;
; Tries: multiboot framebuffer → native framebuffer.
; No legacy text-mode fallback.
; ==================================================================
er_fn er_display_init
    push    rdi

    call    er_fb_text_init
    test    rdx, rdx
    jnz     .try_native

    mov     byte [display_mode], 1
    jmp     .done_init

.try_native:
    call    _native_fb_init
    test    eax, eax
    jnz     .display_unavailable

    mov     byte [display_mode], 1
    jmp     .done_init

.display_unavailable:
    mov     byte [display_mode], 0
    er_err  ERROR_NOT_PRESENT

.done_init:
    pop     rdi
    ret

; ==================================================================
; _native_fb_init — try native framebuffer initialization
; Returns eax=0 on success, 1 on failure.
;
; Scans PCI for a known VGA device. Currently supports:
;   - Bochs VGA (vendor 0x1234, device 0x1111) — QEMU `-vga std`
; Each device type has its own init path.
; ==================================================================
_native_fb_init:
    call    _bochs_vbe_init
    test    eax, eax
    jz      .done
    mov     eax, 1
.done:
    ret

; ==================================================================
; _bochs_vbe_init — initialize Bochs VBE linear framebuffer
; Returns eax=0 on success, 1 on failure.
;
; Scans PCI for vendor=0x1234, device=0x1111 (Bochs VGA).
; Programs VBE registers via IO ports 0x1CE/0x1CF to set 1024x768x32.
; Sets fb_addr/fb_width/fb_height/fb_pitch on success.
; ==================================================================
_bochs_vbe_init:
    push    rbx
    push    r12
    push    r13
    push    r14

    xor     ebx, ebx            ; bus
.bus_loop:
    xor     r12d, r12d          ; dev
.dev_loop:
    xor     r14d, r14d          ; func
.func_loop:
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r14
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .next_func
    movzx   esi, ax
    cmp     esi, BOCHS_VENDOR
    jne     .next_func
    shr     eax, 16
    cmp     eax, BOCHS_VGA_DEV
    jne     .next_func

    ; Found Bochs VGA — read BAR0 (offset 0x10) for LFB address
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r14
    mov     ecx, 0x10
    call    er_pci_read32
    and     eax, 0xFFFFFFF0
    mov     [rel fb_addr], rax

    ; Program Bochs VBE registers via IO ports
    mov     dx, VBE_DISPI_IOPORT_INDEX
    mov     ax, VBE_DISPI_INDEX_ENABLE
    out     dx, ax
    mov     dx, VBE_DISPI_IOPORT_DATA
    mov     ax, VBE_DISPI_DISABLED
    out     dx, ax

    mov     dx, VBE_DISPI_IOPORT_INDEX
    mov     ax, VBE_DISPI_INDEX_ID
    out     dx, ax
    mov     dx, VBE_DISPI_IOPORT_DATA
    mov     ax, 0xB0C4
    out     dx, ax

    mov     dx, VBE_DISPI_IOPORT_INDEX
    mov     ax, VBE_DISPI_INDEX_XRES
    out     dx, ax
    mov     dx, VBE_DISPI_IOPORT_DATA
    mov     ax, 1024
    out     dx, ax

    mov     dx, VBE_DISPI_IOPORT_INDEX
    mov     ax, VBE_DISPI_INDEX_YRES
    out     dx, ax
    mov     dx, VBE_DISPI_IOPORT_DATA
    mov     ax, 768
    out     dx, ax

    mov     dx, VBE_DISPI_IOPORT_INDEX
    mov     ax, VBE_DISPI_INDEX_BPP
    out     dx, ax
    mov     dx, VBE_DISPI_IOPORT_DATA
    mov     ax, 32
    out     dx, ax

    mov     dx, VBE_DISPI_IOPORT_INDEX
    mov     ax, VBE_DISPI_INDEX_ENABLE
    out     dx, ax
    mov     dx, VBE_DISPI_IOPORT_DATA
    mov     ax, VBE_DISPI_ENABLED | VBE_DISPI_LFB_ENABLED | VBE_DISPI_NOCLEARMEM
    out     dx, ax

    mov     dword [rel fb_width], 1024
    mov     dword [rel fb_height], 768
    mov     dword [rel fb_pitch], 4096

    mov     rdi, [rel fb_addr]
    xor     esi, esi
    mov     edx, 1024 * 768 * 4
    call    er_memset

    xor     eax, eax
    jmp     .done

.next_func:
    inc     r14d
    cmp     r14d, 8
    jb      .func_loop
    xor     r14d, r14d
    inc     r12d
    cmp     r12d, 32
    jb      .dev_loop
    xor     r12d, r12d
    inc     ebx
    cmp     ebx, 256
    jb      .bus_loop

    mov     eax, 1
.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_display_clear — clear display
; void er_display_clear(void)
; ==================================================================
er_fn er_display_clear
    cmp     byte [display_mode], 1
    je      er_fb_text_clear
    er_err  ERROR_NOT_PRESENT
    ret

; ==================================================================
; _vga_scroll — scroll VGA display up by one row
; ==================================================================
_vga_scroll:
    push    rdi
    push    rsi
    push    rcx
    push    rax

    mov     rdi, VGA_TEXT_BUF
    mov     rsi, VGA_TEXT_BUF + VGA_COLS * 2
    mov     ecx, (VGA_ROWS - 1) * VGA_COLS
    rep movsw

    mov     rdi, VGA_TEXT_BUF + (VGA_ROWS - 1) * VGA_COLS * 2
    mov     ecx, VGA_COLS
    mov     ax, (VGA_ATTR << 8) | ' '
    rep stosw

    pop     rax
    pop     rcx
    pop     rsi
    pop     rdi
    ret

; ==================================================================
; er_display_putchar — write one character
; void er_display_putchar(unsigned char c)
; ==================================================================
er_fn er_display_putchar
    cmp     byte [display_mode], 1
    je      er_fb_text_putchar
    er_err  ERROR_NOT_PRESENT
    ret

; ==================================================================
; er_display_puts — write a null-terminated string
; void er_display_puts(const char* str)
; ==================================================================
er_fn er_display_puts
    cmp     byte [display_mode], 1
    je      er_fb_text_puts
    er_err  ERROR_NOT_PRESENT
    ret
