; EdgeRun UVC descriptor capability parser self-hosted test.

%include "x86_64/macros.inc"

extern er_uvc_parse_config_caps

SECTION .bss
passed:     resq 1
failed:     resq 1
caps_out:   resd 1

SECTION .rodata
; VideoControl interface + VideoStreaming interface + MJPEG format descriptor.
cfg_mjpeg:
    db 9, 4, 0, 0, 1, 0x0E, 0x01, 0, 0
    db 9, 4, 1, 0, 1, 0x0E, 0x02, 0, 0
    db 0x0B, 0x24, 0x06, 1, 1, 0, 0, 0, 0, 0, 0
cfg_mjpeg_len equ $ - cfg_mjpeg

; VideoStreaming interface + uncompressed YUY2 format descriptor.
cfg_yuy2:
    db 9, 4, 1, 0, 1, 0x0E, 0x02, 0, 0
    db 0x1B, 0x24, 0x04, 1, 1
    db 'Y','U','Y','2', 0,0,0x10,0,0x80,0,0,0xAA,0,0x38,0x9B,0x71
    db 16, 1, 0, 0, 0, 0
cfg_yuy2_len equ $ - cfg_yuy2

; VideoStreaming interface + uncompressed Y800 format descriptor.
cfg_ir_y800:
    db 9, 4, 2, 0, 1, 0x0E, 0x02, 0, 0
    db 0x1B, 0x24, 0x04, 1, 1
    db 'Y','8','0','0', 0,0,0x10,0,0x80,0,0,0xAA,0,0x38,0x9B,0x71
    db 8, 1, 0, 0, 0, 0
cfg_ir_y800_len equ $ - cfg_ir_y800

; Malformed descriptor (bLength=1) must fail.
cfg_bad:
    db 1, 4, 0, 0, 0, 0, 0, 0, 0
cfg_bad_len equ $ - cfg_bad

%define UVC_CAP_RGB_PRESENT   (1 << 0)
%define UVC_CAP_IR_PRESENT    (1 << 1)
%define UVC_CAP_MJPEG         (1 << 2)
%define UVC_CAP_YUY2          (1 << 3)
%define UVC_CAP_CONTROLS      (1 << 4)

SECTION .text
global _start
_start:
    ; Test 1: MJPEG + VC/VS interfaces -> controls + rgb + mjpeg
    lea     rdi, [rel cfg_mjpeg]
    mov     rsi, cfg_mjpeg_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    cmp     eax, 0
    jne     .fail_case
    mov     eax, [rel caps_out]
    mov     edx, UVC_CAP_CONTROLS | UVC_CAP_RGB_PRESENT | UVC_CAP_MJPEG
    cmp     eax, edx
    jne     .fail_case
    inc     qword [rel passed]

    ; Test 2: YUY2 uncompressed -> rgb + yuy2
    lea     rdi, [rel cfg_yuy2]
    mov     rsi, cfg_yuy2_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    cmp     eax, 0
    jne     .fail_case
    mov     eax, [rel caps_out]
    mov     edx, UVC_CAP_RGB_PRESENT | UVC_CAP_YUY2
    cmp     eax, edx
    jne     .fail_case
    inc     qword [rel passed]

    ; Test 3: Y800 uncompressed -> ir present
    lea     rdi, [rel cfg_ir_y800]
    mov     rsi, cfg_ir_y800_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    cmp     eax, 0
    jne     .fail_case
    mov     eax, [rel caps_out]
    mov     edx, UVC_CAP_RGB_PRESENT | UVC_CAP_IR_PRESENT
    cmp     eax, edx
    jne     .fail_case
    inc     qword [rel passed]

    ; Test 4: malformed descriptor fails
    lea     rdi, [rel cfg_bad]
    mov     rsi, cfg_bad_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    cmp     eax, -1
    jne     .fail_case
    inc     qword [rel passed]
    jmp     .done

.fail_case:
    inc     qword [rel failed]

.done:
    cmp     qword [rel failed], 0
    jne     .exit_fail
    mov     rax, 60
    xor     rdi, rdi
    syscall
.exit_fail:
    mov     rax, 60
    mov     rdi, 1
    syscall
