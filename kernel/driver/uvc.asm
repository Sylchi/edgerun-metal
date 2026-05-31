; EdgeRun USB Video Class (UVC) scaffold — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no host stack assumptions.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_xhci_get_info
extern er_xhci_read_portsc
extern er_xhci_get_port_config_blob

; Stream kinds
%define UVC_STREAM_RGB 0
%define UVC_STREAM_IR  1

; Capabilities bitmask
%define UVC_CAP_RGB_PRESENT   (1 << 0)
%define UVC_CAP_IR_PRESENT    (1 << 1)
%define UVC_CAP_MJPEG         (1 << 2)
%define UVC_CAP_YUY2          (1 << 3)
%define UVC_CAP_CONTROLS      (1 << 4)
%define XHCI_PORTSC_CCS       (1 << 0)
%define USB_DESC_INTERFACE    0x04
%define USB_DESC_CS_INTERFACE 0x24
%define USB_CLASS_VIDEO       0x0E
%define UVC_SC_VIDEOCONTROL   0x01
%define UVC_SC_VIDEOSTREAMING 0x02
%define UVC_VS_FORMAT_UNCOMPRESSED 0x04
%define UVC_VS_FORMAT_MJPEG   0x06

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
uvc_xhci_bar0:        resq 1
uvc_xhci_max_ports:   resd 1
uvc_last_portsc:      resd 1
uvc_cfg_blob_ptr:     resq 1
uvc_cfg_blob_len:     resq 1
uvc_port_blob_ptr:    resq 1
uvc_port_blob_len:    resq 1
uvc_caps_seen:        resd 1

SECTION .text

; int er_uvc_parse_config_caps(const uint8_t* buf, uint64_t len, uint32_t* out_caps)
; Derives stream/control capability hints from a USB configuration descriptor blob.
er_fn er_uvc_parse_config_caps
    test    rdi, rdi
    jz      .pc_bad_arg
    test    rdx, rdx
    jz      .pc_bad_arg

    xor     r9d, r9d             ; caps
    mov     r8, rdi              ; cursor
    mov     rcx, rsi             ; remaining

.pc_loop:
    cmp     rcx, 2
    jb      .pc_done
    movzx   eax, byte [r8]       ; bLength
    cmp     eax, 2
    jb      .pc_bad_arg
    cmp     rax, rcx
    ja      .pc_bad_arg
    movzx   esi, byte [r8 + 1]   ; bDescriptorType
    cmp     esi, USB_DESC_INTERFACE
    je      .pc_interface
    cmp     esi, USB_DESC_CS_INTERFACE
    je      .pc_cs_interface
    jmp     .pc_next

.pc_interface:
    cmp     eax, 9
    jb      .pc_next
    movzx   esi, byte [r8 + 5]   ; bInterfaceClass
    cmp     esi, USB_CLASS_VIDEO
    jne     .pc_next
    movzx   esi, byte [r8 + 6]   ; bInterfaceSubClass
    cmp     esi, UVC_SC_VIDEOCONTROL
    jne     .pc_streaming_if
    or      r9d, UVC_CAP_CONTROLS
    jmp     .pc_next
.pc_streaming_if:
    cmp     esi, UVC_SC_VIDEOSTREAMING
    jne     .pc_next
    or      r9d, UVC_CAP_RGB_PRESENT
    jmp     .pc_next

.pc_cs_interface:
    cmp     eax, 3
    jb      .pc_next
    movzx   esi, byte [r8 + 2]   ; bDescriptorSubtype
    cmp     esi, UVC_VS_FORMAT_MJPEG
    jne     .pc_check_uncomp
    or      r9d, UVC_CAP_MJPEG | UVC_CAP_RGB_PRESENT
    jmp     .pc_next
.pc_check_uncomp:
    cmp     esi, UVC_VS_FORMAT_UNCOMPRESSED
    jne     .pc_next
    cmp     eax, 0x1B            ; includes 16-byte guidFormat
    jb      .pc_next
    ; guidFormat first dword carries fourcc in little-endian for common formats.
    mov     esi, dword [r8 + 5]
    cmp     esi, 0x32595559      ; "YUY2"
    jne     .pc_check_y800
    or      r9d, UVC_CAP_YUY2 | UVC_CAP_RGB_PRESENT
    jmp     .pc_next
.pc_check_y800:
    cmp     esi, 0x30303859      ; "Y800" (grayscale; often IR/mono sensors)
    jne     .pc_check_y16
    or      r9d, UVC_CAP_IR_PRESENT
    jmp     .pc_next
.pc_check_y16:
    cmp     esi, 0x20363159      ; "Y16 "
    jne     .pc_next
    or      r9d, UVC_CAP_IR_PRESENT

.pc_next:
    add     r8, rax
    sub     rcx, rax
    jmp     .pc_loop

.pc_done:
    mov     [rdx], r9d
    xor     eax, eax
    er_ok
    ret
.pc_bad_arg:
    mov     eax, -1
    er_err  ERROR_BAD_ARGUMENT
    ret

; int er_uvc_set_config_blob(const uint8_t* buf, uint64_t len)
; Installs a descriptor blob source for capability derivation in er_uvc_probe.
; Pass buf=0,len=0 to clear.
er_fn er_uvc_set_config_blob
    test    rdi, rdi
    jz      .sb_clear_or_bad
    test    rsi, rsi
    jz      .sb_bad_arg
    mov     [uvc_cfg_blob_ptr], rdi
    mov     [uvc_cfg_blob_len], rsi
    xor     eax, eax
    er_ok
    ret
.sb_clear_or_bad:
    test    rsi, rsi
    jnz     .sb_bad_arg
    mov     qword [uvc_cfg_blob_ptr], 0
    mov     qword [uvc_cfg_blob_len], 0
    xor     eax, eax
    er_ok
    ret
.sb_bad_arg:
    mov     eax, -1
    er_err  ERROR_BAD_ARGUMENT
    ret

; int er_uvc_probe(uint64_t xhci_ok_hint)
; Hint is non-zero when at least one xHCI controller initialized.
; Returns: eax=1 if a UVC-capable topology is considered present, else 0.
er_fn er_uvc_probe
    lea     rdi, [uvc_xhci_bar0]
    lea     rsi, [uvc_xhci_max_ports]
    call    er_xhci_get_info
    test    eax, eax
    jnz     .no_xhci

    xor     r8d, r8d             ; connected_count
    mov     ecx, 1               ; port index (1-based)
.port_loop:
    cmp     ecx, [uvc_xhci_max_ports]
    ja      .port_done
    mov     edi, ecx
    lea     rsi, [uvc_last_portsc]
    call    er_xhci_read_portsc
    test    eax, eax
    jnz     .port_next
    mov     eax, [uvc_last_portsc]
    test    eax, XHCI_PORTSC_CCS
    jz      .port_next
    inc     r8d
.port_next:
    inc     ecx
    jmp     .port_loop

.port_done:
    test    r8d, r8d
    jz      .no_xhci
    mov     dword [uvc_caps_seen], 0
    mov     byte [uvc_attached], 0
    mov     dword [uvc_capabilities], 0
    mov     ecx, 1
.caps_port_loop:
    cmp     ecx, [uvc_xhci_max_ports]
    ja      .caps_fallback
    mov     edi, ecx
    lea     rsi, [uvc_last_portsc]
    call    er_xhci_read_portsc
    test    eax, eax
    jnz     .caps_next_port
    mov     eax, [uvc_last_portsc]
    test    eax, XHCI_PORTSC_CCS
    jz      .caps_next_port
    mov     edi, ecx
    lea     rsi, [uvc_port_blob_ptr]
    lea     rdx, [uvc_port_blob_len]
    call    er_xhci_get_port_config_blob
    test    eax, eax
    jnz     .caps_next_port
    mov     rdi, [uvc_port_blob_ptr]
    mov     rsi, [uvc_port_blob_len]
    lea     rdx, [uvc_last_portsc]
    call    er_uvc_parse_config_caps
    test    eax, eax
    jnz     .probe_parse_fail
    mov     dword [uvc_caps_seen], 1
    mov     eax, [uvc_capabilities]
    or      eax, [uvc_last_portsc]
    mov     [uvc_capabilities], eax
.caps_next_port:
    inc     ecx
    jmp     .caps_port_loop

.caps_fallback:
    mov     rdi, [uvc_cfg_blob_ptr]
    mov     rsi, [uvc_cfg_blob_len]
    test    rdi, rdi
    jz      .probe_ok
    test    rsi, rsi
    jz      .probe_ok
    lea     rdx, [uvc_last_portsc]
    call    er_uvc_parse_config_caps
    test    eax, eax
    jnz     .probe_parse_fail
    mov     dword [uvc_caps_seen], 1
    mov     eax, [uvc_capabilities]
    or      eax, [uvc_last_portsc]
    mov     [uvc_capabilities], eax
.probe_ok:
    cmp     dword [uvc_caps_seen], 0
    jne     .probe_have_caps
    ; We have USB connectivity but no parsed video descriptor source yet.
    ; Do not claim UVC is attached.
    mov     byte [uvc_attached], 0
    mov     dword [uvc_last_status], ERROR_NOT_PRESENT
    xor     eax, eax
    er_ok
    ret
.probe_have_caps:
    mov     eax, [uvc_capabilities]
    test    eax, (UVC_CAP_RGB_PRESENT | UVC_CAP_IR_PRESENT | UVC_CAP_MJPEG | UVC_CAP_YUY2 | UVC_CAP_CONTROLS)
    jnz     .probe_mark_attached
    mov     byte [uvc_attached], 0
    mov     dword [uvc_last_status], ERROR_NOT_PRESENT
    xor     eax, eax
    er_ok
    ret
.probe_mark_attached:
    mov     byte [uvc_attached], 1
    mov     dword [uvc_last_status], ERROR_OK
    mov     eax, 1
    er_ok
    ret

.probe_parse_fail:
    mov     dword [uvc_capabilities], 0
    mov     dword [uvc_last_status], ERROR_BAD_ARGUMENT
    mov     eax, -1
    er_err  ERROR_BAD_ARGUMENT
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
