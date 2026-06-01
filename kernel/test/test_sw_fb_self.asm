; EdgeRun sw_fb self-hosted test — x86_64 assembly
; Exits via syscall: 0 = pass, 1 = fail.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern sw_fb_fill
extern sw_fb_blend_pixel

SECTION .rodata
; Color: 0xAABBGGRR LE
; red = 0xFFFF0000 (r=0, g=0, b=255, a=255)
; Hmm wait, on LE 0xAABBGGRR: byte0=R, byte1=G, byte2=B, byte3=A
; So 0xFFFF0000 = byte3=0xFF, byte2=0xFF, byte1=0x00, byte0=0x00
; That's R=0, G=0, B=255, A=255 → blue actually
; Let me use:
; red   = 0xFF0000FF (r=255, g=0, b=0, a=255)
; green = 0xFF00FF00 (r=0, g=255, b=0, a=255)
; blue  = 0xFFFF0000 (r=0, g=0, b=255, a=255)
; white = 0xFFFFFFFF (r=255, g=255, b=255, a=255)
; black = 0x00000000

red:    dd 0xFF0000FF
green:  dd 0xFF00FF00
blue:   dd 0xFFFF0000
white:  dd 0xFFFFFFFF
black:  dd 0x00000000

; Bounds for various tests
rect_full:  dd 0.0, 0.0, 0x41200000, 0x41200000  ; (0, 0, 10, 10)
rect_part:  dd 0x40400000, 0x40400000, 0x40A00000, 0x40A00000  ; (3, 3, 5, 5)
rect_part2: dd 0x40800000, 0x40800000, 0x40800000, 0x40800000  ; (4, 4, 4, 4)
rect_empty: dd 0x41200000, 0x41200000, 0x00000000, 0x00000000  ; (10,10,0,0) — nothing to draw
rect_off:   dd 0x41A00000, 0x41200000, 0x40800000, 0x40800000  ; (20,10,4,4) — partially off-screen

TEST_BSS_TOTAL_PASSED
fb:         resd 100          ; 10x10 framebuffer (400 bytes)
row:        resd 10           ; buffer for reading one row (40 bytes)

SECTION .data
fb_len:     dq 0              ; used as len tracking

SECTION .text
global _start
_start:
    ; ===== 1. sw_fb_fill entire framebuffer with blue =====
    mov     edi, 10            ; width
    mov     esi, 10            ; height
    lea     rdx, [rel fb]      ; pixels
    lea     rcx, [rel rect_full]
    mov     r8d, [rel blue]    ; color
    call    sw_fb_fill

    ; Verify first pixel is blue
    TEST_DWORD_MEM [rel fb], [rel blue]

    ; Verify last pixel (index 99) is blue
    TEST_DWORD_MEM [rel fb + 99*4], [rel blue]

    ; ===== 2. Fill partially (overwrite middle with red) =====
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_part]   ; (3,3,5,5)
    mov     r8d, [rel red]
    call    sw_fb_fill

    ; Pixel at (0,0) should still be blue
    TEST_DWORD_MEM [rel fb], [rel blue]

    ; Pixel at (3,3) = index 3*10+3 = 33 should be red
    TEST_DWORD_MEM [rel fb + 33*4], [rel red]

    ; Pixel at (7,7) = index 7*10+7 = 77 should be red
    TEST_DWORD_MEM [rel fb + 77*4], [rel red]

    ; Pixel at (9,9) = index 99 should still be blue
    TEST_DWORD_MEM [rel fb + 99*4], [rel blue]

    ; ===== 3. Empty rect (no-op) =====
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_empty]  ; (10,10,0,0) — entirely off right edge
    mov     r8d, [rel green]
    call    sw_fb_fill

    ; fb[99] should still be blue (unchanged)
    TEST_DWORD_MEM [rel fb + 99*4], [rel blue]

    ; ===== 4. Fill with rect partially off-screen =====
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_off]    ; (20,10,4,4) — starts at x=20, entirely off
    mov     r8d, [rel green]
    call    sw_fb_fill

    ; Nothing should be written (off-screen). fb[99] still blue.
    TEST_DWORD_MEM [rel fb + 99*4], [rel blue]

    ; ===== 5. sw_fb_blend_pixel with alpha=0 =====
    ; Reset fb to black
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    lea     rcx, [rel rect_full]
    mov     r8d, [rel black]
    call    sw_fb_fill

    ; Blend red at (0,0) with alpha=0
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    xor     ecx, ecx           ; x = 0
    xor     r8d, r8d           ; y = 0
    mov     r9d, [rel red]
    push    0                  ; alpha = 0
    call    sw_fb_blend_pixel
    add     rsp, 8

    ; fb[0] should still be black (alpha=0 → no change)
    TEST_DWORD_MEM [rel fb], [rel black]

    ; ===== 6. Blend pixel with alpha=255 (full overwrite) =====
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9d, [rel red]
    push    255                ; alpha = 255
    call    sw_fb_blend_pixel
    add     rsp, 8

    ; fb[0] should now be red (full overwrite)
    TEST_DWORD_MEM [rel fb], [rel red]

    ; ===== 7. Blend pixel with partial alpha =====
    ; fb[0] is currently red. Let's blend blue on top with alpha=128
    mov     edi, 10
    mov     esi, 10
    lea     rdx, [rel fb]
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9d, [rel blue]
    push    128                ; alpha = 128 (half)
    call    sw_fb_blend_pixel
    add     rsp, 8

    ; The result should be 50/50 blend of red and blue
    ; R channel: (0*128 + 255*127 + 127) / 255 = (0 + 32385 + 127) / 255 = 32512 / 255 = 127
    ; G channel: (0*128 + 0*127 + 127) / 255 = 0
    ; B channel: (255*128 + 0*127 + 127) / 255 = (32640 + 127) / 255 = 32767 / 255 = 128
    ; A channel: min(255, 255 + (255*128/255)) = min(255, 255+128) = 255
    ; Result: A=255, B=128, G=0, R=127 → 0xFF80007F

    TEST_DWORD_IMM [rel fb], 0xFF80007F

    ; ===== done =====
    TEST_EXIT_PASSED_TOTAL
