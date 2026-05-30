; EdgeRun display driver — x86_64 assembly
; System V AMD64 ABI, freestanding.
;
; Dual-mode: VGA text mode (0xB8000, 80x25) or linear framebuffer
; (multiboot-provided UEFI GOP).  Mode is selected at init time.
;
; Framebuffer text rendering delegates to fb_text.asm (alpha8 atlas).

%include "x86_64/macros.inc"

%define VGA_TEXT_BUF     0xB8000
%define VGA_COLS         80
%define VGA_ROWS         25
%define VGA_ATTR         0x07

SECTION .data
vga_cursor:      dd 0
display_mode:    db 0        ; 0=VGA text mode, 1=framebuffer

SECTION .text

extern er_fb_text_init
extern er_fb_text_putchar
extern er_fb_text_puts
extern er_fb_text_clear

; ==================================================================
; er_display_init — initialize display
; void er_display_init(void)
;
; Tries framebuffer (multiboot v1) first; falls back to VGA text mode.
; ==================================================================
er_fn er_display_init
    push    rdi

    call    er_fb_text_init
    test    rdx, rdx
    jnz     .vga_fallback

    mov     byte [display_mode], 1
    jmp     .done_init

.vga_fallback:
    mov     byte [display_mode], 0
    call    er_display_clear
    lea     rdi, [rel .banner]
    call    er_display_puts

.done_init:
    pop     rdi
    er_ok
    ret

.banner: db "EdgeRun x86_64 bare metal - VGA text mode", 0x0A, 0

; ==================================================================
; er_display_clear — clear display
; void er_display_clear(void)
; ==================================================================
er_fn er_display_clear
    cmp     byte [display_mode], 1
    je      er_fb_text_clear

    push    rdi
    push    rcx
    push    rax

    mov     rdi, VGA_TEXT_BUF
    mov     ecx, VGA_COLS * VGA_ROWS
    mov     ax, (VGA_ATTR << 8) | ' '
    rep stosw

    mov     dword [vga_cursor], 0

    pop     rax
    pop     rcx
    pop     rdi
    er_ok
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

    push    rbx
    push    rcx
    push    rdx

    movzx   ebx, dil
    mov     ecx, [vga_cursor]

    cmp     bl, 0x0A
    je      .line_feed
    cmp     bl, 0x0D
    je      .carriage_return

    mov     eax, ecx
    shl     eax, 1
    add     rax, VGA_TEXT_BUF
    mov     [rax], bl
    mov     byte [rax + 1], VGA_ATTR

    inc     ecx
    jmp     .check_scroll

.line_feed:
    add     ecx, VGA_COLS
    jmp     .check_scroll

.carriage_return:
    xor     edx, edx
    mov     eax, ecx
    mov     ecx, VGA_COLS
    div     ecx
    imul    eax, VGA_COLS
    mov     ecx, eax
    jmp     .store

.check_scroll:
    cmp     ecx, VGA_COLS * VGA_ROWS
    jb      .store
    sub     ecx, VGA_COLS
    call    _vga_scroll

.store:
    mov     [vga_cursor], ecx
    pop     rdx
    pop     rcx
    pop     rbx
    er_ok
    ret

; ==================================================================
; er_display_puts — write a null-terminated string
; void er_display_puts(const char* str)
; ==================================================================
er_fn er_display_puts
    cmp     byte [display_mode], 1
    je      er_fb_text_puts

    push    rdi
    push    rsi
    mov     rsi, rdi
.loop:
    lodsb
    test    al, al
    jz      .done
    movzx   edi, al
    call    er_display_putchar
    jmp     .loop
.done:
    pop     rsi
    pop     rdi
    er_ok
    ret
