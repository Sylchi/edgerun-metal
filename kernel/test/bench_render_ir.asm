; EdgeRun bench_render_ir — RDTSC cycle benchmark for render_ir backend
; Measures cycles per call for sw_fb_fill, sw_fb_render_ir_rects (fill),
; sw_fb_render_ir_rects (shadow), and sw_fb_render_ir_icons.

%include "x86_64/macros.inc"

%define ITER 10000

extern sw_fb_fill
extern sw_fb_render_ir_rects
extern sw_fb_render_ir_icons

SECTION .bss
align 64
fb:         resd 100
result_buf: resb 80

SECTION .data
align 16
; Fill rect: red 10x10
rect_fill:
    dd 0x00000000, 0x00000000   ; x=0, y=0
    dd 0x41200000, 0x41200000   ; w=10, h=10
    dd 0x00000000, 0x00000000   ; radius=0, shadow=0
    dd 0x3F800000, 0x00000000   ; r=1, g=0
    dd 0x00000000, 0x3F800000   ; b=0, a=1
    dd 0x00000000, 0x00000000   ; r2=0, g2=0
    dd 0x00000000, 0x00000000   ; b2=0, a2=0
    dd 0x00000000               ; mode=0 (fill)

; Shadow rect: red main + blue shadow, 6x6, radius=2
rect_shadow:
    dd 0x40000000, 0x40000000   ; x=2, y=2
    dd 0x40C00000, 0x40C00000   ; w=6, h=6
    dd 0x40000000, 0x00000000   ; radius=2 (shadow offset), shadow=0
    dd 0x3F800000, 0x00000000   ; r=1, g=0 (red)
    dd 0x00000000, 0x3F800000   ; b=0, a=1
    dd 0x00000000, 0x00000000   ; r2=0, g2=0
    dd 0x3F800000, 0x3F800000   ; b2=1, a2=1 (blue)
    dd 0x3F800000               ; mode=1 (shadow)

; Icon entry: green 4x4
icon_data:
    dd 0x00000000, 0x00000000   ; x=0, y=0
    dd 0x40800000, 0x40800000   ; w=4, h=4
    dd 0x00000000, 0x3F800000   ; r=0, g=1 (green)
    dd 0x00000000, 0x3F800000   ; b=0, a=1
    dd 0x42280000               ; icon_id=42.0

SECTION .text
global _start
_start:
    ; init fb to black
    lea     rdi, [rel fb]
    mov     ecx, 100
    mov     eax, 0xFF000000
    rep stosd

    ; ===== 1. sw_fb_fill (10x10 red) =====
    xor     ebx, ebx
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     r12, rax
.bench_fill:
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_fill]
    mov     r8d, 0xFF0000FF
    call    sw_fb_fill
    inc     ebx
    cmp     ebx, ITER
    jb      .bench_fill
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r12
    xor     edx, edx
    mov     ecx, ITER
    div     ecx
    mov     r13, rax

    ; ===== 2. sw_fb_render_ir_rects — fill mode =====
    xor     ebx, ebx
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     r12, rax
.bench_rr_fill:
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_fill]
    mov     r8d, 1
    call    sw_fb_render_ir_rects
    inc     ebx
    cmp     ebx, ITER
    jb      .bench_rr_fill
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r12
    xor     edx, edx
    mov     ecx, ITER
    div     ecx
    mov     r14, rax

    ; ===== 3. sw_fb_render_ir_rects — shadow mode =====
    xor     ebx, ebx
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     r12, rax
.bench_rr_shadow:
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_shadow]
    mov     r8d, 1
    call    sw_fb_render_ir_rects
    inc     ebx
    cmp     ebx, ITER
    jb      .bench_rr_shadow
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r12
    xor     edx, edx
    mov     ecx, ITER
    div     ecx
    mov     r15, rax

    ; ===== 4. sw_fb_render_ir_icons =====
    xor     ebx, ebx
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     r12, rax
.bench_ri:
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel icon_data]
    mov     r8d, 1
    call    sw_fb_render_ir_icons
    inc     ebx
    cmp     ebx, ITER
    jb      .bench_ri
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r12
    xor     edx, edx
    mov     ecx, ITER
    div     ecx
    mov     rbx, rax                ; icon cycles

    ; ===== print results =====
    lea     rdi, [rel result_buf]
    mov     esi, 80
    mov     edx, r13d               ; fill
    mov     ecx, r14d               ; rr_fill
    mov     r8d, r15d               ; rr_shadow
    mov     r9d, ebx                ; icon
    call    format_results
    mov     edx, eax                ; count
    lea     rsi, [rel result_buf]   ; buf
    mov     edi, 1                  ; stdout
    mov     eax, 1                  ; sys_write
    syscall

    xor     edi, edi
    mov     eax, 60
    syscall

; format_results(rdi=buf, rsi=buf_size, rdx=fill, rcx=rr_fill,
;                r8=rr_shadow, r9=icon)
; returns rax = bytes written
format_results:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    mov     r12, rdi
    xor     ebx, ebx

    push    r8                     ; save rr_shadow cycles on stack
    push    r9                     ; save icon cycles on stack

    lea     rsi, [rel str_fill]
    call    strcpy
    mov     edi, edx
    call    dec_write
    mov     byte [r12 + rbx], 10
    inc     ebx

    lea     rsi, [rel str_rr_fill]
    call    strcpy
    mov     edi, ecx
    call    dec_write
    mov     byte [r12 + rbx], 10
    inc     ebx

    lea     rsi, [rel str_rr_shadow]
    call    strcpy
    mov     edi, [rbp - 24]       ; rr_shadow cycles from stack
    call    dec_write
    mov     byte [r12 + rbx], 10
    inc     ebx

    lea     rsi, [rel str_icon]
    call    strcpy
    mov     edi, [rbp - 32]       ; icon cycles from stack
    call    dec_write
    mov     byte [r12 + rbx], 10
    inc     ebx

    mov     eax, ebx
    pop     r9
    pop     r8

    pop     r12
    pop     rbx
    pop     rbp
    ret

strcpy:
    push    rax
.l:
    mov     al, [rsi]
    test    al, al
    jz      .d
    mov     [r12 + rbx], al
    inc     rbx
    inc     rsi
    jmp     .l
.d:
    pop     rax
    ret

; dec_write: write decimal(edi) to r12+rbx, advances rbx
dec_write:
    push    rax
    push    rcx
    push    rdx

    mov     eax, edi
    mov     ecx, 10
    lea     r8, [r12 + rbx]
    add     r8, 10
    mov     byte [r8], 0
    dec     r8
.next:
    xor     edx, edx
    div     ecx
    add     dl, '0'
    mov     [r8], dl
    dec     r8
    test    eax, eax
    jnz     .next
    inc     r8
.cp:
    mov     al, [r8]
    test    al, al
    jz      .dn
    mov     [r12 + rbx], al
    inc     rbx
    inc     r8
    jmp     .cp
.dn:
    pop     rdx
    pop     rcx
    pop     rax
    ret

SECTION .rodata
str_fill:      db "fill: ", 0
str_rr_fill:   db "rr_fill: ", 0
str_rr_shadow: db "rr_shadow: ", 0
str_icon:      db "icon: ", 0
