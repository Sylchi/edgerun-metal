; EdgeRun framebuffer text renderer — x86_64 assembly
; System V AMD64 ABI, freestanding.
;
; Renders text to a linear 32bpp RGBA framebuffer using a
; pre-rasterized alpha8 font atlas (1024×1024) and glyph table.
;
; Cursor tracks baseline position in pixels.
; Line height: 20px for 16px font scale.

%include "x86_64/macros.inc"

%define ATLAS_W     1024
%define ATLAS_H     1024
%define LINE_HEIGHT 20
%define TAB_WIDTH   40

; GlyphRecord layout (20 bytes each)
%define GR_CP       0    ; u32
%define GR_ATLAS_X  4    ; u16
%define GR_ATLAS_Y  6    ; u16
%define GR_W        8    ; u16
%define GR_H        10   ; u16
%define GR_LEFT     12   ; i16
%define GR_TOP      14   ; i16
%define GR_ADVANCE  16   ; u16 (1/16th pixel units; >>4 for pixels)

; Error codes
%define ERROR_NOT_PRESENT 22

SECTION .data
fb_addr:     dq 0
fb_width:    dd 0
fb_height:   dd 0
fb_pitch:    dd 0
fb_bpp:      db 0          ; bytes per pixel
fb_cursor_x: dd 0          ; pixel position (baseline)
fb_cursor_y: dd 0
fb_fg_color: dd 0xFFFFFFFF ; white

SECTION .rodata
font_atlas:
    incbin "font_atlas.bin"
font_atlas_end:

font_glyph_table:
    incbin "font_glyph_table.bin"
font_glyph_table_end:
glyph_count: dd (font_glyph_table_end - font_glyph_table) / 20

SECTION .text

extern mb_info_ptr

er_fn er_fb_text_init
    push    rdi
    push    rcx
    push    rax

    mov     rdi, [mb_info_ptr]
    test    rdi, rdi
    jz      .no_fb

    ; Multiboot v1 info structure — check flags bit 12
    mov     eax, [rdi]
    test    eax, 1 << 12
    jz      .no_fb

    ; +0x58: framebuffer_addr (u64)
    mov     rax, [rdi + 0x58]
    mov     [fb_addr], rax

    ; +0x60: framebuffer_pitch (u32, bytes per scanline)
    mov     eax, [rdi + 0x60]
    mov     [fb_pitch], eax

    ; +0x64: framebuffer_width (u32)
    mov     eax, [rdi + 0x64]
    mov     [fb_width], eax

    ; +0x68: framebuffer_height (u32)
    mov     eax, [rdi + 0x68]
    mov     [fb_height], eax

    ; +0x6C: framebuffer_bpp (u8) → convert to bytes
    movzx   eax, byte [rdi + 0x6C]
    shr     eax, 3
    mov     [fb_bpp], al

    ; Reset cursor
    xor     eax, eax
    mov     [fb_cursor_x], eax
    mov     [fb_cursor_y], eax

    ; Clear display
    call    er_fb_text_clear

    pop     rax
    pop     rcx
    pop     rdi
    er_ok
    ret

.no_fb:
    pop     rax
    pop     rcx
    pop     rdi
    xor     eax, eax
    mov     edx, ERROR_NOT_PRESENT
    ret

; ==================================================================
; er_fb_text_clear — fill entire framebuffer with black
; void er_fb_text_clear(void)
; ==================================================================
er_fn er_fb_text_clear
    push    rdi
    push    rcx
    push    rax

    mov     rdi, [fb_addr]
    test    rdi, rdi
    jz      .done_c

    mov     eax, [fb_height]
    mul     dword [fb_pitch]
    mov     ecx, eax
    xor     eax, eax
    rep stosb

.done_c:
    pop     rax
    pop     rcx
    pop     rdi
    er_ok
    ret

; ==================================================================
; _fb_text_scroll — scroll display up by one line
; ==================================================================
_fb_text_scroll:
    push    rdi
    push    rsi
    push    rcx
    push    rax

    mov     rdi, [fb_addr]
    test    rdi, rdi
    jz      .done_s

    ; Move everything up by LINE_HEIGHT pixel rows
    mov     esi, [fb_pitch]
    imul    esi, LINE_HEIGHT
    add     rsi, rdi                ; src = fb + LINE_HEIGHT * pitch

    mov     edx, [fb_height]
    sub     edx, LINE_HEIGHT
    imul    edx, [fb_pitch]
    mov     ecx, edx                ; bytes to copy
    rep movsb

    ; Clear bottom LINE_HEIGHT rows
    mov     edi, [fb_height]
    sub     edi, LINE_HEIGHT
    imul    edi, [fb_pitch]
    add     rdi, [fb_addr]
    mov     ecx, LINE_HEIGHT
    imul    ecx, [fb_pitch]
    xor     eax, eax
    rep stosb

.done_s:
    pop     rax
    pop     rcx
    pop     rsi
    pop     rdi
    ret

; ==================================================================
; er_fb_text_putchar — render one character to framebuffer
; void er_fb_text_putchar(unsigned char c)
; ==================================================================
er_fn er_fb_text_putchar
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r8
    push    r9
    push    r10
    push    r11
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 8

    movzx   ebx, dil                ; rbx = character
    mov     r12d, [fb_cursor_x]     ; r12 = cursor_x
    mov     r13d, [fb_cursor_y]     ; r13 = cursor_y

    cmp     bl, 0x0A                ; '\n'
    je      .line_feed
    cmp     bl, 0x0D                ; '\r'
    je      .carriage_return
    cmp     bl, 0x09                ; '\t'
    je      .tab
    cmp     bl, ' '                 ; below space → control, skip
    jb      .done_char

    ; Look up glyph in table (linear scan of all entries)
    lea     r14, [rel font_glyph_table]
    mov     ecx, [glyph_count]
.find_loop:
    cmp     ebx, [r14 + GR_CP]
    je      .found
    add     r14, 20
    dec     ecx
    jnz     .find_loop
    jmp     .done_char              ; not found, skip

.found:
    ; r14 = glyph record — save in rbx for later (callee-saved in _fb_text_blit)
    mov     rbx, r14
    movzx   r8d, word [rbx + GR_W]  ; glyph_w
    movzx   r9d, word [rbx + GR_H]  ; glyph_h
    movzx   r10d, word [rbx + GR_ATLAS_X]
    movzx   r11d, word [rbx + GR_ATLAS_Y]
    movsx   ecx, word [rbx + GR_LEFT]  ; left bearing
    movsx   edx, word [rbx + GR_TOP]   ; top bearing

    ; dest_x = cursor_x + left
    mov     r15d, r12d
    add     r15d, ecx

    ; dest_y = cursor_y + top
    mov     ebp, r13d
    add     ebp, edx

    ; Check visibility: skip if fully off-screen
    cmp     r15d, [fb_width]
    jge     .advance_only_rbx
    mov     eax, r15d
    add     eax, r8d
    cmp     eax, 0
    jle     .advance_only_rbx
    cmp     ebp, [fb_height]
    jge     .advance_only_rbx
    mov     eax, ebp
    add     eax, r9d
    cmp     eax, 0
    jle     .advance_only_rbx

    ; Blit glyph to framebuffer
    mov     rdi, [fb_addr]          ; fb base
    mov     esi, [fb_pitch]         ; fb pitch
    lea     rdx, [rel font_atlas]   ; atlas base
    mov     ecx, r15d               ; dest_x
    mov     r15d, ebp               ; dest_y
    mov     r14d, r8d               ; w
    mov     ebp, r9d                ; h
    mov     r8d, r10d               ; src_x
    mov     r9d, r11d               ; src_y
    mov     eax, [fb_fg_color]
    mov     [rsp], eax              ; color on stack
    call    _fb_text_blit

.advance_only_rbx:
    ; Advance cursor by glyph advance (1/16th pixel units)
    movzx   eax, word [rbx + GR_ADVANCE]
    shr     eax, 4                  ; advance_px = advance_fp >> 4
    add     r12d, eax
    mov     [fb_cursor_x], r12d
    jmp     .done_char

.tab:
    add     r12d, TAB_WIDTH
    mov     [fb_cursor_x], r12d
    jmp     .done_char

.carriage_return:
    xor     r12d, r12d
    mov     [fb_cursor_x], r12d
    jmp     .done_char

.line_feed:
    mov     r12d, 0
    mov     [fb_cursor_x], r12d
    add     r13d, LINE_HEIGHT
    mov     [fb_cursor_y], r13d

    ; Scroll if past bottom
    mov     eax, [fb_height]
    sub     eax, LINE_HEIGHT
    cmp     r13d, eax
    jb      .done_char
    sub     r13d, LINE_HEIGHT
    mov     [fb_cursor_y], r13d
    call    _fb_text_scroll

.done_char:
    add     rsp, 8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    er_ok
    ret

; ==================================================================
; _fb_text_blit — blit a glyph from the atlas to the framebuffer
;
; rdi = fb_base
; rsi = fb_pitch (bytes per row)
; rdx = atlas_base (alpha8, 1024×1024)
; ecx = dest_x (screen pixel)
; r15d = dest_y
; r14d = glyph_w
; ebp = glyph_h
; r8d = src_x (atlas pixel)
; r9d = src_y (atlas pixel)
; [rsp] = fg_color (packed u32 0xAABBGGRR)
; ==================================================================
_fb_text_blit:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, ecx               ; dest_x
    mov     r13d, r15d              ; dest_y
    mov     r14d, ebp               ; h

    ; Load color
    mov     r15d, [rsp + 5*8]       ; fg_color (5 push regs on stack)

    ; Clip rect to framebuffer bounds
    mov     ebx, 0                  ; clip left
    cmp     r12d, 0
    cmovl   ebx, r12d
    neg     ebx                     ; how many atlas pixels to skip on left
    ; Wait, this is getting complex. Let me do simple scissor.

    ; Actually, let me clip in a simpler way:
    ; compute actual dest range, clip, then loop.

    ; Clip dest_x: left edge
    mov     eax, r12d
    mov     ecx, 0
    cmp     eax, 0
    cmovl   r12d, ecx               ; dest_x = max(0, dest_x)

    ; Bottom clip for dest_y

    ; For simplicity, skip clipping and just let the inner loop
    ; check bounds before writing. This is simpler and works correctly
    ; even if partially off-screen.

    mov     eax, r12d
    mov     r12d, ecx
    ; OK let me properly clip the source/dest rectangle.

    ; r12 = original dest_x, r8 = original src_x, r14 = w
    ; r13 = original dest_y, r9 = original src_y, ebp = h

    ; Clip left: if dest_x < 0, shift src_x and reduce w
    xor     ecx, ecx
    cmp     r12d, 0
    jge     .clip_right
    sub     ecx, r12d               ; adjust by how far left we are
    add     r8d, ecx                ; src_x += adjust
    add     r12d, ecx               ; dest_x += adjust (= 0)
    sub     r14d, ecx               ; w -= adjust
.clip_right:
    ; Clip right: if dest_x + w > fb_width
    mov     eax, r12d
    add     eax, r14d
    cmp     eax, [fb_width]
    jle     .clip_top
    sub     eax, [fb_width]
    sub     r14d, eax

.clip_top:
    xor     ecx, ecx
    cmp     r13d, 0
    jge     .clip_bottom
    sub     ecx, r13d
    add     r9d, ecx
    add     r13d, ecx
    sub     ebp, ecx

.clip_bottom:
    mov     eax, r13d
    add     eax, ebp
    cmp     eax, [fb_height]
    jle     .check_empty
    sub     eax, [fb_height]
    sub     ebp, eax

.check_empty:
    test    r14d, r14d
    jle     .done_blit
    test    ebp, ebp
    jle     .done_blit

    ; Inner loop: for y = 0..h, for x = 0..w
    ; Compute row start: fb += dest_y * pitch + dest_x * 4
    mov     eax, r13d              ; dest_y
    mul     esi                    ; * pitch
    mov     ebx, r12d              ; dest_x
    shl     ebx, 2                 ; * 4 bytes per pixel
    add     eax, ebx
    add     rdi, rax               ; fb ptr at start of first row

    ; Row advance: after pop, skip from row start to next row start
    mov     r11d, [fb_pitch]

    mov     r10d, ebp              ; row counter
.row_loop:
    push    r10
    push    rdi

    ; atlas_row = src_y + current_y_offset
    ; current_y_offset = h - row_counter
    mov     eax, r10d
    ; Actually, current_y_offset = (original_h - row_counter)
    ; But since we clipped, ebp = clipped_h
    ; We track from top: row 0 to row h-1
    ; current_y_offset = (clipped_h - rowcounter)
    mov     eax, ebp
    sub     eax, r10d               ; row index from top (0 = first row)
    add     eax, r9d                ; + src_y
    imul    eax, ATLAS_W
    add     eax, r8d                ; + src_x
    lea     rbx, [rdx + rax]        ; atlas ptr for this row start

    mov     ecx, r14d               ; pixel count
.pixel_loop:
    movzx   eax, byte [rbx]         ; alpha from atlas
    test    eax, eax
    jz      .skip_pixel

    cmp     eax, 255
    je      .opaque

    ; Blend: result = (fg * alpha + bg * (255 - alpha)) / 255
    mov     r8d, [rdi]              ; bg pixel (RGBA bytes)
    mov     r9d, r15d               ; fg color

    ; R channel (byte 0)
    movzx   ecx, r9b                ; fg_r
    imul    ecx, eax                ; * alpha
    mov     ebx, eax                ; save alpha
    movzx   edx, r8b                ; bg_r
    mov     r10d, 255
    sub     r10d, eax               ; inv_alpha
    imul    edx, r10d
    add     ecx, edx
    add     ecx, 127
    shr     ecx, 8                  ; (sum + 127) / 255 ≈ divide by 255
    mov     byte [rdi], cl

    ; G channel (byte 1)
    mov     ecx, r9d
    shr     ecx, 8
    and     ecx, 0xFF
    imul    ecx, eax
    mov     edx, r8d
    shr     edx, 8
    and     edx, 0xFF
    imul    edx, r10d
    add     ecx, edx
    add     ecx, 127
    shr     ecx, 8
    mov     byte [rdi + 1], cl

    ; B channel (byte 2)
    mov     ecx, r9d
    shr     ecx, 16
    and     ecx, 0xFF
    imul    ecx, eax
    mov     edx, r8d
    shr     edx, 16
    and     edx, 0xFF
    imul    edx, r10d
    add     ecx, edx
    add     ecx, 127
    shr     ecx, 8
    mov     byte [rdi + 2], cl

    jmp     .advance_loop

.opaque:
    mov     [rdi], r15d             ; write fg color directly

.skip_pixel:
.advance_loop:
    inc     rbx                     ; next atlas pixel
    add     rdi, 4                  ; next fb pixel
    dec     ecx
    jnz     .pixel_loop

    ; Move to next row
    pop     rdi
    pop     r10
    add     rdi, r11                ; advance fb by pitch (from row start)
    dec     r10d
    jnz     .row_loop

.done_blit:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_fb_text_puts — write a null-terminated string
; void er_fb_text_puts(const char* str)
; ==================================================================
er_fn er_fb_text_puts
    push    rdi
    push    rsi

    mov     rsi, rdi
.loop_s:
    lodsb
    test    al, al
    jz      .done_s
    movzx   edi, al
    call    er_fb_text_putchar
    jmp     .loop_s

.done_s:
    pop     rsi
    pop     rdi
    er_ok
    ret

; ==================================================================
; er_fb_text_gotoxy — set cursor pixel position
; void er_fb_text_gotoxy(uint32_t x, uint32_t y)
; x = rdi, y = rsi
; ==================================================================
er_fn er_fb_text_gotoxy
    mov     [fb_cursor_x], edi
    mov     [fb_cursor_y], esi
    ret

; ==================================================================
; er_fb_text_color — set foreground text color
; void er_fb_text_color(uint32_t color)  ; 0xAABBGGRR
; ==================================================================
er_fn er_fb_text_color
    mov     [fb_fg_color], edi
    ret

; ==================================================================
; int er_fb_text_measure(const char *str, u64 len)
; Measure the pixel width of a length-prefixed string.
; rdi = str, rsi = len
; returns: rax = width in pixels
; ==================================================================
er_fn er_fb_text_measure
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r12
    push    r13

    mov     r12, rdi               ; str
    mov     r13, rsi               ; len
    xor     eax, eax               ; total_width

    xor     r10d, r10d
.loop:
    cmp     r10, r13
    jae     .done

    movzx   ebx, byte [r12 + r10]  ; character
    inc     r10

    ; Control chars: tab, newline don't add measure width
    cmp     bl, ' '
    jb      .loop

    ; Look up glyph
    lea     rcx, [rel font_glyph_table]
    mov     edx, [glyph_count]
.find:
    cmp     ebx, [rcx + GR_CP]
    je      .found
    add     rcx, 20
    dec     edx
    jnz     .find
    jmp     .loop                  ; not found

.found:
    ; advance width is GR_ADVANCE (u16, 1/16th pixel units)
    movzx   edx, word [rcx + GR_ADVANCE]
    shr     edx, 4                  ; advance_px = advance_fp >> 4
    add     eax, edx
    jmp     .loop

.done:
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ==================================================================
; int er_fb_text_render(const char *str, u64 len, u32 x, u32 y, u32 color)
; Render a length-prefixed string at pixel position (x, y) with color.
; rdi = str, rsi = len, rdx = x, rcx = y, r8 = color
; returns: rax = 0
; ==================================================================
er_fn er_fb_text_render
    er_frame_push
    push    r12
    push    r13
    push    r14

    mov     r12, rdi               ; str
    mov     r13, rsi               ; len
    mov     r14d, r8d              ; color

    ; Set position and color
    mov     rdi, rdx               ; x
    mov     rsi, rcx               ; y
    call    er_fb_text_gotoxy

    mov     edi, r14d
    call    er_fb_text_color

    ; Render each character
    xor     r10d, r10d
.loop:
    cmp     r10, r13
    jae     .done

    movzx   edi, byte [r12 + r10]
    call    er_fb_text_putchar

    inc     r10
    jmp     .loop

.done:
    xor     eax, eax
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ==================================================================
; int er_fb_text_glyph_lookup(u32 codepoint, void *out_record)
; Look up a codepoint in the glyph table.
; rdi = codepoint, rsi = out (20-byte record buffer)
; returns: rax = 0 found (record copied to [rsi]), -1 not found
; ==================================================================
er_fn er_fb_text_glyph_lookup
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    mov     ebx, edi               ; codepoint
    lea     rcx, [rel font_glyph_table]
    mov     edx, [glyph_count]
    xor     eax, eax               ; index = 0
.lookup_loop:
    cmp     edx, eax
    jbe     .lookup_not_found
    cmp     ebx, [rcx + GR_CP]
    je      .lookup_found
    add     rcx, 20
    inc     eax
    jmp     .lookup_loop
.lookup_found:
    ; Copy 20-byte GlyphRecord to [rsi]
    mov     rdi, rsi               ; dst
    mov     rsi, rcx               ; src
    mov     ecx, 5                 ; 20 bytes / 4
    rep movsd                      ; copy 5 dwords
    xor     eax, eax               ; return 0
    jmp     .lookup_done
.lookup_not_found:
    or      eax, -1                ; return -1
.lookup_done:
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    ret
