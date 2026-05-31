; EdgeRun USB Video Class (UVC) scaffold — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no host stack assumptions.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

; Stream kinds
%define UVC_STREAM_RGB 0
%define UVC_STREAM_IR  1

; Capabilities bitmask
%define UVC_CAP_RGB_PRESENT   (1 << 0)
%define UVC_CAP_IR_PRESENT    (1 << 1)
%define UVC_CAP_MJPEG         (1 << 2)
%define UVC_CAP_YUY2          (1 << 3)
%define UVC_CAP_CONTROLS      (1 << 4)

; Stream state layout
%define UVC_STREAM_ENABLED    0   ; u8
%define UVC_STREAM_FMT        1   ; u8
%define UVC_STREAM_FPS        2   ; u16
%define UVC_STREAM_WIDTH      4   ; u16
%define UVC_STREAM_HEIGHT     6   ; u16
%define UVC_STREAM_FRAME_CNT  8   ; u32
%define UVC_STREAM_ERR_CNT    12  ; u32
%define UVC_STREAM_SIZE       16

SECTION .bss
uvc_capabilities:     resd 1
uvc_attached:         resb 1
uvc_rgb_state:        resb UVC_STREAM_SIZE
uvc_ir_state:         resb UVC_STREAM_SIZE
uvc_last_status:      resd 1

SECTION .text

; int er_uvc_probe(uint64_t xhci_ok_hint)
; Hint is non-zero when at least one xHCI controller initialized.
; Returns: eax=1 if a UVC-capable topology is considered present, else 0.
er_fn er_uvc_probe
    test    rdi, rdi
    jz      .no_xhci

    ; Scaffold defaults: mark attached with RGB+IR capability bits present.
    ; Real descriptor-driven detection will overwrite this.
    mov     byte [uvc_attached], 1
    mov     dword [uvc_capabilities], UVC_CAP_RGB_PRESENT | UVC_CAP_IR_PRESENT
    mov     dword [uvc_last_status], ERROR_OK
    mov     eax, 1
    er_ok
    ret

.no_xhci:
    mov     byte [uvc_attached], 0
    mov     dword [uvc_capabilities], 0
    mov     dword [uvc_last_status], ERROR_NOT_PRESENT
    xor     eax, eax
    er_ok
    ret

; int er_uvc_get_caps(uint32_t* out_caps)
er_fn er_uvc_get_caps
    test    rdi, rdi
    jz      .bad_arg
    mov     eax, [uvc_capabilities]
    mov     [rdi], eax
    xor     eax, eax
    er_ok
    ret
.bad_arg:
    mov     eax, -1
    er_err  ERROR_BAD_ARGUMENT
    ret

; int er_uvc_stream_config(uint32_t kind, uint16_t w, uint16_t h, uint16_t fps)
; kind: UVC_STREAM_RGB or UVC_STREAM_IR
er_fn er_uvc_stream_config
    cmp     edi, UVC_STREAM_IR
    ja      .cfg_bad_arg
    cmp     esi, 0
    je      .cfg_bad_arg
    cmp     edx, 0
    je      .cfg_bad_arg
    cmp     ecx, 0
    je      .cfg_bad_arg

    lea     r8, [uvc_rgb_state]
    test    edi, edi
    jz      .cfg_store
    lea     r8, [uvc_ir_state]

.cfg_store:
    mov     byte [r8 + UVC_STREAM_ENABLED], 1
    mov     word [r8 + UVC_STREAM_WIDTH], si
    mov     word [r8 + UVC_STREAM_HEIGHT], dx
    mov     word [r8 + UVC_STREAM_FPS], cx
    xor     eax, eax
    mov     dword [uvc_last_status], ERROR_OK
    er_ok
    ret

.cfg_bad_arg:
    mov     eax, -1
    mov     dword [uvc_last_status], ERROR_BAD_ARGUMENT
    er_err  ERROR_BAD_ARGUMENT
    ret

; int er_uvc_stream_start(uint32_t kind)
er_fn er_uvc_stream_start
    cmp     edi, UVC_STREAM_IR
    ja      .start_bad_arg
    cmp     byte [uvc_attached], 1
    jne     .start_absent
    ; Transport not yet implemented.
    mov     eax, -1
    mov     dword [uvc_last_status], ERROR_NOT_IMPLEMENTED
    er_err  ERROR_NOT_IMPLEMENTED
    ret
.start_bad_arg:
    mov     eax, -1
    mov     dword [uvc_last_status], ERROR_BAD_ARGUMENT
    er_err  ERROR_BAD_ARGUMENT
    ret
.start_absent:
    mov     eax, -1
    mov     dword [uvc_last_status], ERROR_NOT_PRESENT
    er_err  ERROR_NOT_PRESENT
    ret

; int er_uvc_stream_poll(uint32_t kind, uint64_t* out_frames, uint64_t* out_errors)
er_fn er_uvc_stream_poll
    cmp     edi, UVC_STREAM_IR
    ja      .poll_bad_arg
    test    rsi, rsi
    jz      .poll_bad_arg
    test    rdx, rdx
    jz      .poll_bad_arg
    lea     r8, [uvc_rgb_state]
    test    edi, edi
    jz      .poll_read
    lea     r8, [uvc_ir_state]
.poll_read:
    mov     eax, [r8 + UVC_STREAM_FRAME_CNT]
    mov     [rsi], rax
    mov     eax, [r8 + UVC_STREAM_ERR_CNT]
    mov     [rdx], rax
    xor     eax, eax
    er_ok
    ret
.poll_bad_arg:
    mov     eax, -1
    er_err  ERROR_BAD_ARGUMENT
    ret
