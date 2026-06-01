; EdgeRun UVC descriptor capability parser self-hosted test.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_uvc_parse_config_caps
extern er_uvc_set_config_blob
extern er_xhci_set_port_config_blob
extern er_xhci_get_port_config_blob

TEST_BSS_PASSED_FAILED
caps_out:   resd 1
ptr_out:    resq 1
len_out:    resq 1

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
    ; Test -1: xHCI per-port blob registry set/get/clear
    mov     edi, 1
    lea     rsi, [rel cfg_mjpeg]
    mov     rdx, cfg_mjpeg_len
    call    er_xhci_set_port_config_blob
    EXPECT_EAX 0, .fail_case
    mov     edi, 1
    lea     rsi, [rel ptr_out]
    lea     rdx, [rel len_out]
    call    er_xhci_get_port_config_blob
    EXPECT_EAX 0, .fail_case
    mov     rax, [rel ptr_out]
    lea     rbx, [rel cfg_mjpeg]
    cmp     rax, rbx
    jne     .fail_case
    EXPECT_QWORD [rel len_out], cfg_mjpeg_len, .fail_case
    mov     edi, 1
    xor     rsi, rsi
    xor     rdx, rdx
    call    er_xhci_set_port_config_blob
    EXPECT_EAX 0, .fail_case
    mov     edi, 1
    lea     rsi, [rel ptr_out]
    lea     rdx, [rel len_out]
    call    er_xhci_get_port_config_blob
    EXPECT_EAX -1, .fail_case
    TEST_CASE_PASS

    ; Test 0: set/clear config blob API
    lea     rdi, [rel cfg_mjpeg]
    mov     rsi, cfg_mjpeg_len
    call    er_uvc_set_config_blob
    EXPECT_EAX 0, .fail_case
    xor     rdi, rdi
    xor     rsi, rsi
    call    er_uvc_set_config_blob
    EXPECT_EAX 0, .fail_case
    xor     rdi, rdi
    mov     rsi, 8
    call    er_uvc_set_config_blob
    EXPECT_EAX -1, .fail_case
    TEST_CASE_PASS

    ; Test 1: MJPEG + VC/VS interfaces -> controls + rgb + mjpeg
    lea     rdi, [rel cfg_mjpeg]
    mov     rsi, cfg_mjpeg_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    EXPECT_EAX 0, .fail_case
    EXPECT_DWORD [rel caps_out], UVC_CAP_CONTROLS | UVC_CAP_RGB_PRESENT | UVC_CAP_MJPEG, .fail_case
    TEST_CASE_PASS

    ; Test 2: YUY2 uncompressed -> rgb + yuy2
    lea     rdi, [rel cfg_yuy2]
    mov     rsi, cfg_yuy2_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    EXPECT_EAX 0, .fail_case
    EXPECT_DWORD [rel caps_out], UVC_CAP_RGB_PRESENT | UVC_CAP_YUY2, .fail_case
    TEST_CASE_PASS

    ; Test 3: Y800 uncompressed -> ir present
    lea     rdi, [rel cfg_ir_y800]
    mov     rsi, cfg_ir_y800_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    EXPECT_EAX 0, .fail_case
    EXPECT_DWORD [rel caps_out], UVC_CAP_RGB_PRESENT | UVC_CAP_IR_PRESENT, .fail_case
    TEST_CASE_PASS

    ; Test 4: malformed descriptor fails
    lea     rdi, [rel cfg_bad]
    mov     rsi, cfg_bad_len
    lea     rdx, [rel caps_out]
    call    er_uvc_parse_config_caps
    EXPECT_EAX -1, .fail_case
    TEST_CASE_PASS
    jmp     .done

.fail_case:
    TEST_CASE_FAIL

.done:
    TEST_EXIT_FAILED
