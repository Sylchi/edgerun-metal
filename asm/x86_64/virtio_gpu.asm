; EdgeRun Virtio GPU driver — x86_64 assembly
; System V AMD64 ABI. Freestanding — no libc, no external dependencies.
;
; Implements the Virtio GPU protocol control queue for 2D scanout.
; Depends on virtio.asm for transport layer primitives.

%include "x86_64/macros.inc"
%include "x86_64/virtio_constants.inc"
%include "x86_64/virtio_gpu_constants.inc"

extern er_virtio_find_device
extern er_virtio_map_device
extern er_virtio_enable_device
extern er_virtio_negotiate_features
extern er_virtio_select_queue
extern er_virtio_read_queue_size
extern er_virtio_set_queue_size
extern er_virtio_set_queue_desc
extern er_virtio_set_queue_avail
extern er_virtio_set_queue_used
extern er_virtio_enable_queue
extern er_virtio_read_queue_notify_off
extern er_virtio_notify_queue
extern er_virtio_read_status
extern er_virtio_write_status
extern er_virtio_post_descriptor
extern er_virtio_next_used
extern er_virtio_read8
extern er_virtio_write8

; ==================================================================
; VIRTIO_GPU_DEVICE — GPU device state (56 bytes + embedded transport)
;
; Layout:
;   transport:         VIRTIO_TRANSPORT (44 bytes)
;   driver_features:   resq 1         (8)
;   queue_notify_off:  resw 1         (2)
;   queue_size:        resw 1         (2)
;   last_used_idx:     resw 1         (2)
;                      resb 6         (pad to 64 for alignment)
; Total: 64 bytes
; ==================================================================
struc VIRTIO_GPU_DEVICE
    .transport:         resb VIRTIO_TRANSPORT_size
    .driver_features:   resq 1
    .queue_notify_off:  resw 1
    .queue_size:        resw 1
    .last_used_idx:     resw 1
                        resb 6
endstruc

; VIRTIO_GPU_STORAGE — control queue storage (438 bytes)
struc VIRTIO_GPU_STORAGE
    .desc:          resb VIRTIO_QUEUE_SIZE * VIRTIO_DESC_SIZE  ; 256
    .avail:         resb VIRTIO_AVAIL_SIZE                      ; 68
    .used:          resb VIRTIO_USED_SIZE                       ; 72
    .response:      resb VIRTIO_GPU_RESPONSE_SIZE               ; 24
    .cmd_buf:       resb 128                                    ; 128 (room for largest cmd)
endstruc

SECTION .text

; ==================================================================
; er_virtio_gpu_init — discover, map, negotiate, and init GPU
; int er_virtio_gpu_init(VIRTIO_GPU_DEVICE* dev, VIRTIO_GPU_STORAGE* storage)
;
; Returns: eax = 0 on success, non-zero on failure.
; ==================================================================
er_fn er_virtio_gpu_init
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage

    ; Allocate VIRTIO_DEVICE and VIRTIO_TRANSPORT on stack
    sub     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    mov     rbx, rsp            ; rbx = VIRTIO_DEVICE*
    lea     r14, [rbx + VIRTIO_DEVICE_size]  ; r14 = VIRTIO_TRANSPORT*

    ; 1. PCI discovery
    mov     rdi, VIRTIO_DEVICE_GPU
    mov     rsi, rbx
    call    er_virtio_find_device
    test    eax, eax
    jz      .err_not_found

    ; 2. Map BARs
    mov     rdi, rbx
    mov     rsi, r14
    call    er_virtio_map_device

    ; 3. Negotiate features
    lea     rdx, [r12 + VIRTIO_GPU_DEVICE.driver_features]
    mov     rdi, r14
    mov     rsi, VIRTIO_GPU_F_VIRGL | VIRTIO_GPU_F_CONTEXT_INIT
    call    er_virtio_negotiate_features
    test    eax, eax
    jz      .err_features

    ; 4. Select control queue
    mov     rdi, r14
    xor     esi, esi            ; queue 0
    call    er_virtio_select_queue

    ; 5. Read and set queue size
    mov     rdi, r14
    call    er_virtio_read_queue_size
    cmp     ax, VIRTIO_QUEUE_SIZE
    jbe     .size_ok
    mov     ax, VIRTIO_QUEUE_SIZE
.size_ok:
    mov     [r12 + VIRTIO_GPU_DEVICE.queue_size], ax
    mov     rdi, r14
    mov     esi, eax
    call    er_virtio_set_queue_size

    ; 6. Write queue addresses
    mov     rdi, r14
    lea     rsi, [r13 + VIRTIO_GPU_STORAGE.desc]
    call    er_virtio_set_queue_desc

    mov     rdi, r14
    lea     rsi, [r13 + VIRTIO_GPU_STORAGE.avail]
    call    er_virtio_set_queue_avail

    mov     rdi, r14
    lea     rsi, [r13 + VIRTIO_GPU_STORAGE.used]
    call    er_virtio_set_queue_used

    ; 7. Enable queue
    mov     rdi, r14
    mov     esi, 1
    call    er_virtio_enable_queue

    ; 8. Read notify offset
    mov     rdi, r14
    call    er_virtio_read_queue_notify_off
    mov     [r12 + VIRTIO_GPU_DEVICE.queue_notify_off], ax

    ; 9. Set driver_ok status
    mov     rdi, [r14 + VIRTIO_TRANSPORT.common_cfg]
    add     rdi, VIRTIO_COMMON_CFG_DEVICE_STATUS
    mov     esi, VIRTIO_STATUS_DRIVER_OK
    call    er_virtio_write8

    ; 10. Copy transport into device
    mov     ecx, VIRTIO_TRANSPORT_size / 8
    lea     rsi, [r14]
    lea     rdi, [r12 + VIRTIO_GPU_DEVICE.transport]
    rep     movsq

    add     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    xor     eax, eax
    er_ok
    jmp     .out

.err_not_found:
    add     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    mov     eax, ERROR_DEVICE_NOT_FOUND
    er_err  ERROR_DEVICE_NOT_FOUND
    jmp     .out

.err_features:
    add     rsp, VIRTIO_DEVICE_size + VIRTIO_TRANSPORT_size
    mov     eax, ERROR_FEATURE_NEGOTIATION
    er_err  ERROR_FEATURE_NEGOTIATION
    jmp     .out

.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    ret

; ==================================================================
; Command buffer write helpers
; ==================================================================

; void er_virtio_gpu_write_header(void* buf, uint32_t ctrl_type,
;                                 uint32_t context_id)
er_fn er_virtio_gpu_write_header
    xor     eax, eax
    mov     [rdi + VIRTIO_GPU_HDR_CTRL_TYPE], esi
    mov     [rdi + VIRTIO_GPU_HDR_FLAGS], eax
    mov     [rdi + VIRTIO_GPU_HDR_FENCE_ID], rax
    mov     [rdi + VIRTIO_GPU_HDR_CONTEXT_ID], edx
    ret

; void er_virtio_gpu_write_resource_create_2d(void* buf, uint32_t resource_id,
;                                             uint32_t width, uint32_t height,
;                                             uint32_t format)
er_fn er_virtio_gpu_write_resource_create_2d
    mov     dword [rdi + VIRTIO_GPU_HDR_CTRL_TYPE], VIRTIO_GPU_CMD_RESOURCE_CREATE_2D
    xor     eax, eax
    mov     [rdi + VIRTIO_GPU_HDR_FLAGS], eax
    mov     [rdi + VIRTIO_GPU_HDR_FENCE_ID], rax
    mov     [rdi + VIRTIO_GPU_HDR_CONTEXT_ID], eax
    mov     [rdi + VIRTIO_GPU_RES2D_RESOURCE_ID], esi
    mov     [rdi + VIRTIO_GPU_RES2D_WIDTH], edx
    mov     [rdi + VIRTIO_GPU_RES2D_HEIGHT], ecx
    mov     [rdi + VIRTIO_GPU_RES2D_FORMAT], r8d
    ret

; void er_virtio_gpu_write_attach_backing(void* buf, uint32_t resource_id,
;                                         uint64_t address, uint32_t byte_len)
er_fn er_virtio_gpu_write_attach_backing
    mov     dword [rdi + VIRTIO_GPU_HDR_CTRL_TYPE], VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING
    xor     eax, eax
    mov     [rdi + VIRTIO_GPU_HDR_FLAGS], eax
    mov     [rdi + VIRTIO_GPU_HDR_FENCE_ID], rax
    mov     [rdi + VIRTIO_GPU_HDR_CONTEXT_ID], eax

    mov     [rdi + VIRTIO_GPU_ATTACH_RESOURCE_ID], esi
    mov     dword [rdi + VIRTIO_GPU_ATTACH_NR_ENTRIES], 1
    mov     [rdi + VIRTIO_GPU_ATTACH_ENTRY_ADDR], rdx     ; address
    mov     [rdi + VIRTIO_GPU_ATTACH_ENTRY_LEN], ecx      ; byte_len
    mov     [rdi + VIRTIO_GPU_ATTACH_ENTRY_ADDR + 8], eax ; padding
    ret

; void er_virtio_gpu_write_set_scanout(void* buf, uint32_t scanout_id,
;                                      uint32_t resource_id,
;                                      uint32_t width, uint32_t height)
er_fn er_virtio_gpu_write_set_scanout
    mov     dword [rdi + VIRTIO_GPU_HDR_CTRL_TYPE], VIRTIO_GPU_CMD_SET_SCANOUT
    xor     eax, eax
    mov     [rdi + VIRTIO_GPU_HDR_FLAGS], eax
    mov     [rdi + VIRTIO_GPU_HDR_FENCE_ID], rax
    mov     [rdi + VIRTIO_GPU_HDR_CONTEXT_ID], eax

    mov     [rdi + VIRTIO_GPU_SCANOUT_RECT_X], eax
    mov     [rdi + VIRTIO_GPU_SCANOUT_RECT_Y], eax
    mov     [rdi + VIRTIO_GPU_SCANOUT_RECT_W], ecx
    mov     [rdi + VIRTIO_GPU_SCANOUT_RECT_H], r8d
    mov     [rdi + VIRTIO_GPU_SCANOUT_SCANOUT_ID], esi
    mov     [rdi + VIRTIO_GPU_SCANOUT_RESOURCE_ID], edx
    ret

; void er_virtio_gpu_write_transfer_to_host_2d(void* buf, uint32_t resource_id,
;                                              uint32_t width, uint32_t height)
er_fn er_virtio_gpu_write_transfer_to_host_2d
    mov     dword [rdi + VIRTIO_GPU_HDR_CTRL_TYPE], VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D
    xor     eax, eax
    mov     [rdi + VIRTIO_GPU_HDR_FLAGS], eax
    mov     [rdi + VIRTIO_GPU_HDR_FENCE_ID], rax
    mov     [rdi + VIRTIO_GPU_HDR_CONTEXT_ID], eax

    mov     [rdi + VIRTIO_GPU_T2D_RECT_X], eax
    mov     [rdi + VIRTIO_GPU_T2D_RECT_Y], eax
    mov     [rdi + VIRTIO_GPU_T2D_RECT_W], edx
    mov     [rdi + VIRTIO_GPU_T2D_RECT_H], ecx
    mov     [rdi + VIRTIO_GPU_T2D_OFFSET], rax
    mov     [rdi + VIRTIO_GPU_T2D_RESOURCE_ID], esi
    ret

; void er_virtio_gpu_write_flush(void* buf, uint32_t resource_id,
;                                uint32_t width, uint32_t height)
er_fn er_virtio_gpu_write_flush
    mov     dword [rdi + VIRTIO_GPU_HDR_CTRL_TYPE], VIRTIO_GPU_CMD_RESOURCE_FLUSH
    xor     eax, eax
    mov     [rdi + VIRTIO_GPU_HDR_FLAGS], eax
    mov     [rdi + VIRTIO_GPU_HDR_FENCE_ID], rax
    mov     [rdi + VIRTIO_GPU_HDR_CONTEXT_ID], eax

    mov     [rdi + VIRTIO_GPU_FLUSH_RECT_X], eax
    mov     [rdi + VIRTIO_GPU_FLUSH_RECT_Y], eax
    mov     [rdi + VIRTIO_GPU_FLUSH_RECT_W], edx
    mov     [rdi + VIRTIO_GPU_FLUSH_RECT_H], ecx
    mov     [rdi + VIRTIO_GPU_FLUSH_RESOURCE_ID], esi
    ret

; ==================================================================
; er_virtio_gpu_send — send command, read response
; int er_virtio_gpu_send(VIRTIO_GPU_DEVICE* dev, VIRTIO_GPU_STORAGE* storage,
;                        void* cmd, uint32_t cmd_len,
;                        void* rsp, uint32_t rsp_len)
;
; Returns: eax = 0 on success (r8d = response type), non-zero on error.
; ==================================================================
er_fn er_virtio_gpu_send
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage
    mov     r14, rdx            ; cmd
    mov     r15d, ecx           ; cmd_len
    mov     rbx, r8             ; rsp
    mov     r9d, r9d            ; rsp_len

    test    r15d, r15d
    jz      .err_invalid
    test    r9d, r9d
    jz      .err_invalid

    ; Build descriptor chain: desc[0] = cmd (out), desc[1] = rsp (in)
    ; desc[0]
    mov     [r13 + VIRTIO_GPU_STORAGE.desc + 0], r14       ; addr
    mov     [r13 + VIRTIO_GPU_STORAGE.desc + 8], r15d      ; len
    mov     word [r13 + VIRTIO_GPU_STORAGE.desc + 12], VIRTIO_DESC_F_NEXT
    mov     word [r13 + VIRTIO_GPU_STORAGE.desc + 14], 1   ; next=1

    ; desc[1]
    mov     [r13 + VIRTIO_GPU_STORAGE.desc + 16], rbx      ; addr
    mov     [r13 + VIRTIO_GPU_STORAGE.desc + 24], r9d      ; len
    mov     word [r13 + VIRTIO_GPU_STORAGE.desc + 28], VIRTIO_DESC_F_WRITE
    mov     word [r13 + VIRTIO_GPU_STORAGE.desc + 30], 0   ; next=0

    ; Post descriptor to avail ring
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.avail]
    movzx   esi, word [r12 + VIRTIO_GPU_DEVICE.queue_size]
    xor     edx, edx               ; desc_id = 0
    call    er_virtio_post_descriptor

    ; Notify device
    lea     rdi, [r12 + VIRTIO_GPU_DEVICE.transport]
    xor     esi, esi               ; queue_num = 0 (control queue)
    call    er_virtio_notify_queue

    ; Wait for completion
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.used]
    movzx   esi, word [r12 + VIRTIO_GPU_DEVICE.queue_size]
    lea     rdx, [r12 + VIRTIO_GPU_DEVICE.last_used_idx]

.wait:
    call    er_virtio_next_used
    test    eax, eax
    jnz     .done
    pause
    jmp     .wait

.done:
    ; Check response type
    mov     r8d, [rbx]
    cmp     r8d, VIRTIO_GPU_RESP_OK_NODATA
    je      .ok
    cmp     r8d, VIRTIO_GPU_RESP_OK_DISPLAY_INFO
    je      .ok
    cmp     r8d, VIRTIO_GPU_RESP_OK_CAPSET_INFO
    je      .ok

    mov     eax, ERROR_INVALID_RESPONSE
    er_err  ERROR_INVALID_RESPONSE
    jmp     .out

.ok:
    xor     eax, eax
    er_ok
    jmp     .out

.err_invalid:
    mov     eax, ERROR_INVALID_PARAM
    er_err  ERROR_INVALID_PARAM
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    ret

; ==================================================================
; er_virtio_gpu_send_nodata — send command, expect ok_nodata
; int er_virtio_gpu_send_nodata(VIRTIO_GPU_DEVICE* dev,
;                               VIRTIO_GPU_STORAGE* storage,
;                               void* cmd, uint32_t cmd_len)
; ==================================================================
er_fn er_virtio_gpu_send_nodata
    push    r8
    push    r9
    mov     r8, rsi
    add     r8, VIRTIO_GPU_STORAGE.response   ; rsp = &storage->response
    mov     r9d, VIRTIO_GPU_RESPONSE_SIZE     ; rsp_len = sizeof(Response)
    call    er_virtio_gpu_send
    pop     r9
    pop     r8
    ret

; ==================================================================
; er_virtio_gpu_setup_2d — full 2D setup: create + attach + scanout
; int er_virtio_gpu_setup_2d(VIRTIO_GPU_DEVICE* dev,
;                            VIRTIO_GPU_STORAGE* storage,
;                            uint32_t resource_id, uint32_t scanout_id,
;                            uint32_t width, uint32_t height,
;                            uint64_t pixel_addr, uint32_t pixel_len)
;
; AMD64 ABI: rdi=dev, rsi=storage, rdx=res_id, rcx=scanout_id,
;            r8=width, r9=height, [rbp+16]=pixel_addr, [rbp+24]=pixel_len
; ==================================================================
er_fn er_virtio_gpu_setup_2d
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    r9              ; save height (callee-saved now, though r9 is not)

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage
    mov     r14d, edx           ; resource_id
    mov     r15d, ecx           ; scanout_id
    mov     ebx, r8d            ; width
    ; height at [rsp] (pushed r9), pixel_addr at [rbp+16], pixel_len at [rbp+24]

    ; ── Command 1: resource_create_2d ──────────────────────────────
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     esi, r14d           ; resource_id
    mov     edx, ebx            ; width
    mov     ecx, [rsp]          ; height (saved r9)
    mov     r8d, VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM
    call    er_virtio_gpu_write_resource_create_2d

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     ecx, VIRTIO_GPU_RESOURCE_CREATE_2D_SIZE
    call    er_virtio_gpu_send_nodata
    test    eax, eax
    jnz     .out

    ; ── Command 2: attach_backing ──────────────────────────────────
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     esi, r14d           ; resource_id
    mov     rdx, [rbp + 16]     ; pixel_addr
    mov     ecx, [rbp + 24]     ; pixel_len
    call    er_virtio_gpu_write_attach_backing

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     ecx, VIRTIO_GPU_RESOURCE_ATTACH_BACKING_SIZE
    call    er_virtio_gpu_send_nodata
    test    eax, eax
    jnz     .out

    ; ── Command 3: set_scanout ─────────────────────────────────────
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     esi, r15d           ; scanout_id
    mov     edx, r14d           ; resource_id
    mov     ecx, ebx            ; width
    mov     r8d, [rsp]          ; height
    call    er_virtio_gpu_write_set_scanout

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     ecx, VIRTIO_GPU_SET_SCANOUT_SIZE
    call    er_virtio_gpu_send_nodata
    ; eax carries the return value

.out:
    add     rsp, 8              ; discard saved height
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    ret

; ==================================================================
; er_virtio_gpu_flush_2d — transfer + flush a 2D resource
; int er_virtio_gpu_flush_2d(VIRTIO_GPU_DEVICE* dev,
;                            VIRTIO_GPU_STORAGE* storage,
;                            uint32_t resource_id,
;                            uint32_t width, uint32_t height)
;
; AMD64 ABI: rdi=dev, rsi=storage, rdx=res_id, rcx=width, r8=height
; ==================================================================
er_fn er_virtio_gpu_flush_2d
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; dev
    mov     r13, rsi            ; storage
    mov     r14d, edx           ; resource_id
    mov     ebx, ecx            ; width
    ; r8 = height

    ; ── Command 1: transfer_to_host_2d ─────────────────────────────
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     esi, r14d           ; resource_id
    mov     edx, ebx            ; width
    mov     ecx, r8d            ; height
    call    er_virtio_gpu_write_transfer_to_host_2d

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     ecx, VIRTIO_GPU_TRANSFER_TO_HOST_2D_SIZE
    call    er_virtio_gpu_send_nodata
    test    eax, eax
    jnz     .out

    ; ── Command 2: resource_flush ──────────────────────────────────
    lea     rdi, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     esi, r14d           ; resource_id
    mov     edx, ebx            ; width
    mov     ecx, r8d            ; height
    call    er_virtio_gpu_write_flush

    mov     rdi, r12
    mov     rsi, r13
    lea     rdx, [r13 + VIRTIO_GPU_STORAGE.cmd_buf]
    mov     ecx, VIRTIO_GPU_RESOURCE_FLUSH_SIZE
    call    er_virtio_gpu_send_nodata

.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_frame_pop
    ret
