; EdgeRun VGA text-mode display driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Writes to VGA text-mode framebuffer at 0xB8000 (80x25, 2 bytes per cell).
; Cursor position tracked in memory (no CRTC port I/O in long mode).

%include "x86_64/macros.inc"

%define VGA_TEXT_BUF     0xB8000
%define VGA_COLS         80
%define VGA_ROWS         25
%define VGA_ATTR         0x07        ; light gray on black

SECTION .data
vga_cursor:      dd 0        ; current cursor offset (0-1999)

SECTION .text

; ==================================================================
; er_display_clear — clear the VGA text screen, reset cursor to (0,0)
; void er_display_clear(void)
; ==================================================================
er_fn er_display_clear
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
; _vga_scroll — scroll the display up by one row
; Preserves: rbx,rcx,rdx,rsi,rdi,r8-r15
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
; er_display_putchar — write one character at current cursor position
; void er_display_putchar(unsigned char c)
;
; Handles \n (line feed, next row same column),
; \r (carriage return, column 0), and automatic scrolling.
; ==================================================================
er_fn er_display_putchar
    push    rbx
    push    rcx
    push    rdx

    movzx   ebx, dil                     ; bl = character
    mov     ecx, [vga_cursor]            ; ecx = cursor offset

    cmp     bl, 0x0A                     ; '\n'
    je      .line_feed

    cmp     bl, 0x0D                     ; '\r'
    je      .carriage_return

    ; Normal character: write at cursor offset
    mov     eax, ecx
    shl     eax, 1
    add     rax, VGA_TEXT_BUF
    mov     [rax], bl                    ; char
    mov     byte [rax + 1], VGA_ATTR     ; attribute

    inc     ecx                          ; advance cursor
    jmp     .check_scroll

.line_feed:
    add     ecx, VGA_COLS
    jmp     .check_scroll

.carriage_return:
    xor     edx, edx
    mov     eax, ecx
    mov     ecx, VGA_COLS
    div     ecx                          ; eax = row, edx = col
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
; er_display_puts — write a null-terminated string to the VGA display
; void er_display_puts(const char* str)
; ==================================================================
er_fn er_display_puts
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

; ==================================================================
; er_display_init — initialize VGA text mode display
; void er_display_init(void)
;
; Clears screen, resets cursor, and prints a startup banner.
; ==================================================================
er_fn er_display_init
    push    rdi

    call    er_display_clear

    lea     rdi, [rel .banner]
    call    er_display_puts

    pop     rdi
    er_ok
    ret

.banner: db "EdgeRun x86_64 bare metal - VGA text mode", 0x0A, 0
