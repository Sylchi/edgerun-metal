; Pi Zero USB boot host tool — x86_64 Linux userspace assembly
; Canonical Pi Zero USB boot host implementation.
;
; Usage: pi_usb_boot_host [options] [bootcode.bin]
;
; Build: yasm -f elf64 -o pi_usb_boot_host.o pi_usb_boot_host.asm
; Link:  ld -o pi_usb_boot_host pi_usb_boot_host.o
;
; This tool talks to a Raspberry Pi Zero in USB boot mode (BCM2708),
; uploads a second-stage bootloader (bootcode.bin), then serves
; boot files (kernel.img, config.txt, etc.) to the Pi's file server.

%include "host/bcm2708_usb_boot.inc"

SAFE_FILE_BACKSLASH equ 0x5c
USB_SCAN_MAX_NUM equ 127
USB_DESCRIPTOR_DEVICE_LEN equ 18
USB_DESCRIPTOR_TYPE_DEVICE equ 0x0100
USB_REQUEST_GET_DESCRIPTOR equ 0x06
USB_REQUEST_TYPE_STANDARD_IN equ 0x80
USB_DEVICE_DESC_VENDOR equ 8
USB_DEVICE_DESC_PRODUCT equ 10
USB_DEVICE_DESC_SERIAL_INDEX equ 16
BCM_SERIAL_INDEX_FIRST_ZERO equ 0
BCM_SERIAL_INDEX_FIRST_THREE equ 3

; ---- .data section ----
section .data
default_image:  db ".build/edgerun-metal/pi-zero-w-v1_1/boot/bootcode.bin", 0
default_boot_dir: db ".build/edgerun-metal/pi-zero-w-v1_1/boot", 0
default_kernel:  db ".build/pi-zero-w-v1_1-zig/kernel.img", 0
wait_forever_str: db "forever", 0

; Default constants
TIMEOUT_MS:        dd 5000
RETURN_TIMEOUT_MS: dd 20000
WAIT_POLL_MS:      dd 250

; ---- .bss section ----
section .bss
; Command-line options
opt_image_path:     resq 1
opt_boot_dir:       resq 1
opt_kernel_path:    resq 1
opt_wait:           resb 1
opt_wait_ms:        resd 1
opt_dry_run:        resb 1
opt_serve_only:     resb 1
opt_help:           resb 1

; File data
bootcode_data:      resq 1   ; ptr
bootcode_size:      resd 1

; Device path
dev_path:           resb 32  ; e.g. "/dev/bus/usb/003/007"
dev_path_len:       resq 1

; Scratch buffers
usbctrl_buf:        resb USBCTRL_SIZE
usbbulk_buf:        resb USBBULK_SIZE
file_msg_buf:       resb BCM_FILE_MESSAGE_BYTES
sysfs_path_buf:     resb 256
sysfs_data_buf:     resb 64

; Stack
stack_bottom:       resb 65536
stack_top:

; File descriptor
dev_fd:             resd 1

; ---- .text section ----
section .text
global _start

; ==================================================================
; Entry point
; ==================================================================
_start:
    ; Save argc and argv from kernel stack BEFORE switching to our own stack
    mov     r14, [rsp]      ; r14 = argc (from kernel stack)
    lea     r15, [rsp + 8]  ; r15 = argv pointer (from kernel stack)
    mov     rsp, stack_top  ; switch to our own BSS stack

    ; Default option values
    mov     qword [opt_image_path], default_image
    mov     qword [opt_boot_dir], default_boot_dir
    mov     qword [opt_kernel_path], default_kernel
    mov     dword [opt_wait_ms], 0xffffffff  ; wait_forever
    mov     byte [opt_wait], 0
    mov     byte [opt_dry_run], 0
    mov     byte [opt_serve_only], 0
    mov     byte [opt_help], 0

    ; Quick check for --help before doing anything else
    cmp     r14, 2
    jne     .parse_and_go
    mov     rax, [r15 + 8]  ; argv[1]
    cmp     dword [rax], 0x65682d2d  ; "--he" in little-endian
    jne     .parse_and_go
    cmp     word [rax + 4], 0x706c    ; "lp" in little-endian
    jne     .parse_and_go
    cmp     byte [rax + 6], 0
    je      .print_help_and_exit

.parse_and_go:
    ; Parse arguments
    mov     rdi, r14        ; argc
    mov     rsi, r15        ; argv
    call    parse_options

    ; Check for help
    cmp     byte [opt_help], 1
    je      .print_help_and_exit

    ; Read bootcode image (skip for dry-run — we still need size info)
    mov     rdi, [opt_image_path]
    call    read_file
    mov     [bootcode_data], rax
    mov     [bootcode_size], edx

    ; Print plan
    mov     edi, 1
    lea     rsi, [msg_plan1]
    mov     edx, msg_plan1_len
    call    write_stdout

    mov     edi, [bootcode_size]
    call    print_dec
    mov     edi, 1
    lea     rsi, [msg_plan2]
    mov     edx, msg_plan2_len
    call    write_stdout

    mov     rdi, [opt_image_path]
    call    print_str
    call    print_crlf

    ; Check dry-run
    cmp     byte [opt_dry_run], 1
    je      .do_dry_run

    ; Check serve-only
    cmp     byte [opt_serve_only], 1
    je      .do_serve_only

    ; Phase 1: find device in first-stage boot mode, load bootcode
    mov     edi, 0          ; phase = first_stage (0)
    mov     rsi, [opt_wait_ms]
    movzx   edx, byte [opt_wait]
    call    find_or_wait_boot_device
    test    rax, rax
    jz      .device_not_found

    mov     rdi, rax        ; device path
    call    print_str
    lea     rsi, [msg_found]
    mov     edx, 1
    mov     edi, 1
    call    write_stdout
    call    print_crlf

    ; Open and load
    mov     rdi, rax
    call    open_device
    test    eax, eax
    js      .open_failed
    mov     [dev_fd], eax

    mov     edi, eax
    mov     rsi, [bootcode_data]
    mov     edx, [bootcode_size]
    call    load_second_stage

    ; Close
    mov     edi, [dev_fd]
    call    close_device

    ; Phase 2: serve boot files
.do_serve_only:
    call    serve_boot_files

    ; Done
    mov     edi, 0
    call    sys_exit

.do_dry_run:
    call    find_boot_device_any
    test    rax, rax
    jz      .dry_not_found
    mov     rdi, rax
    call    print_str
    call    print_crlf
    mov     edi, 0
    call    sys_exit
.dry_not_found:
    lea     rdi, [msg_not_found]
    call    print_str
    call    print_crlf
    mov     edi, 0
    call    sys_exit

.print_help_and_exit:
    lea     rdi, [usage_str]
    call    print_str
    mov     edi, 0
    call    sys_exit

.device_not_found:
    lea     rdi, [msg_not_found]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit

.open_failed:
    lea     rdi, [msg_open_failed]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit

; ==================================================================
; parse_options(argc, argv)
; ==================================================================
parse_options:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; argc
    mov     r13, rsi        ; argv
    mov     ebx, 1          ; index
    xor     ecx, ecx        ; image_seen flag

.loop:
    cmp     ebx, r12d
    jae     .done

    mov     r14, [r13 + rbx * 8]  ; r14 = current arg (preserved across calls)
    inc     ebx

    ; Check for options
    cmp     byte [r14], '-'
    jne     .maybe_image

    mov     rdi, r14
    mov     rsi, str_dry_run
    call    str_eq
    test    eax, eax
    jz      .check_serve_only
    mov     byte [opt_dry_run], 1
    jmp     .loop

.check_serve_only:
    mov     rdi, r14
    mov     rsi, str_serve_only
    call    str_eq
    test    eax, eax
    jz      .check_wait
    mov     byte [opt_serve_only], 1
    mov     byte [opt_wait], 1
    jmp     .loop

.check_wait:
    mov     rdi, r14
    mov     rsi, str_wait
    call    str_eq
    test    eax, eax
    jz      .check_wait_ms
    mov     byte [opt_wait], 1
    jmp     .loop

.check_wait_ms:
    mov     rdi, r14
    mov     rsi, str_wait_ms
    call    str_eq
    test    eax, eax
    jz      .check_serve_dir
    cmp     ebx, r12d
    jae     .bad_arg
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_uint32
    mov     [opt_wait_ms], eax
    mov     byte [opt_wait], 1
    jmp     .loop

.check_serve_dir:
    mov     rdi, r14
    mov     rsi, str_serve_dir
    call    str_eq
    test    eax, eax
    jz      .check_kernel
    cmp     ebx, r12d
    jae     .bad_arg
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_boot_dir], rdi
    jmp     .loop

.check_kernel:
    mov     rdi, r14
    mov     rsi, str_kernel
    call    str_eq
    test    eax, eax
    jz      .check_help
    cmp     ebx, r12d
    jae     .bad_arg
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_kernel_path], rdi
    jmp     .loop

.check_help:
    mov     rdi, r14
    mov     rsi, str_help
    call    str_eq
    test    eax, eax
    jz      .bad_arg
    mov     byte [opt_help], 1
    jmp     .loop

.maybe_image:
    test    ecx, ecx
    jnz     .bad_arg
    mov     [opt_image_path], r14
    mov     ecx, 1
    jmp     .loop

.bad_arg:
    lea     rdi, [msg_bad_arg]
    call    print_str
    mov     edi, 1
    call    sys_exit

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; find_or_wait_boot_device(wait, timeout_ms, phase) -> path ptr
; ==================================================================
; edi = phase (0=first_stage, 1=file_server, 2=any)
; esi = timeout_ms
; edx = wait (bool)
find_or_wait_boot_device:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi       ; phase
    mov     r13d, esi       ; timeout_ms
    mov     r13d, edx       ; wait flag
    xor     ebx, ebx        ; waited_ms

.loop:
    mov     edi, r12d
    call    find_boot_device
    test    rax, rax
    jnz     .found

    test    r13b, r13b
    jz      .not_found

    ; Check timeout
    cmp     r13d, 0xffffffff
    je      .sleep
    cmp     ebx, r13d
    jae     .not_found

.sleep:
    mov     edi, WAIT_POLL_MS
    call    sleep_ms
    add     ebx, WAIT_POLL_MS
    jmp     .loop

.found:
    lea     rdi, [dev_path]
    mov     rax, rdi
    jmp     .done

.not_found:
    xor     eax, eax

.done:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; find_boot_device(phase) -> path ptr or 0
; Scans /sys/bus/usb/devices/ for BCM2708 devices.
; phase: 0=first_stage, 1=file_server, 2=any
; ==================================================================
find_boot_device:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; phase

    xor     ebx, ebx        ; bus number (1-based)
.bus_loop:
    inc     ebx
    cmp     ebx, USB_SCAN_MAX_NUM
    ja      .done_none

    xor     r13d, r13d      ; device number (1-based)
.dev_loop:
    inc     r13d
    cmp     r13d, USB_SCAN_MAX_NUM
    ja      .bus_loop

    ; Build path /dev/bus/usb/BBB/DDD
    lea     rdi, [dev_path]
    mov     esi, ebx
    mov     edx, r13d
    call    format_usb_path

    ; Open the device
    lea     rdi, [dev_path]
    xor     esi, esi        ; O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .dev_loop       ; skip if can't open

    mov     r14d, eax       ; fd

    mov     edi, r14d
    mov     esi, r12d
    call    is_bcm_boot_device
    mov     r15d, eax

    mov     edi, r14d
    mov     eax, SYS_close
    syscall

    test    r15d, r15d
    jnz     .found
    jmp     .dev_loop

.done_none:
    xor     eax, eax
    jmp     .done

.found:
    lea     rax, [dev_path]

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; is_bcm_boot_device(fd, phase) -> 1 if BCM2708 boot device matches phase
is_bcm_boot_device:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     r12d, edi
    mov     ebx, esi

    mov     byte [usbctrl_buf + USBCTRL_REQUEST_TYPE], USB_REQUEST_TYPE_STANDARD_IN
    mov     byte [usbctrl_buf + USBCTRL_REQUEST], USB_REQUEST_GET_DESCRIPTOR
    mov     word [usbctrl_buf + USBCTRL_VALUE], USB_DESCRIPTOR_TYPE_DEVICE
    mov     word [usbctrl_buf + USBCTRL_INDEX], 0
    mov     word [usbctrl_buf + USBCTRL_LENGTH], USB_DESCRIPTOR_DEVICE_LEN
    mov     eax, [TIMEOUT_MS]
    mov     dword [usbctrl_buf + USBCTRL_TIMEOUT], eax
    lea     rax, [sysfs_data_buf]
    mov     qword [usbctrl_buf + USBCTRL_DATA], rax

    mov     edi, r12d
    mov     esi, USBDEVFS_CONTROL
    lea     rdx, [usbctrl_buf]
    mov     eax, SYS_ioctl
    syscall
    cmp     eax, USB_DESCRIPTOR_DEVICE_LEN
    jl      .no

    movzx   eax, word [sysfs_data_buf + USB_DEVICE_DESC_VENDOR]
    cmp     eax, BCM_VENDOR_ID
    jne     .no

    movzx   eax, word [sysfs_data_buf + USB_DEVICE_DESC_PRODUCT]
    cmp     eax, BCM_PRODUCT_ID_FIRST
    je      .product_ok
    cmp     eax, BCM_PRODUCT_ID_SECOND
    jne     .no

.product_ok:
    cmp     ebx, 2
    je      .yes

    movzx   eax, byte [sysfs_data_buf + USB_DEVICE_DESC_SERIAL_INDEX]
    cmp     eax, BCM_SERIAL_INDEX_FIRST_ZERO
    je      .serial_first
    cmp     eax, BCM_SERIAL_INDEX_FIRST_THREE
    je      .serial_first

    cmp     ebx, 1
    je      .yes
    jmp     .no

.serial_first:
    test    ebx, ebx
    jz      .yes

.no:
    xor     eax, eax
    pop     r12
    pop     rbx
    pop     rbp
    ret

.yes:
    mov     eax, 1
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; find_boot_device_any() — dry-run version
; ==================================================================
find_boot_device_any:
    mov     edi, 2  ; phase=any
    call    find_boot_device
    ret

; ==================================================================
; open_device(path) -> fd or -1
; ==================================================================
open_device:
    push    rbp
    mov     rbp, rsp

    mov     rdi, rdi        ; path
    mov     esi, 2          ; O_RDWR
    xor     edx, edx
    mov     eax, SYS_open
    syscall

    pop     rbp
    ret

; ==================================================================
; close_device(fd)
; ==================================================================
close_device:
    push    rbp
    mov     rbp, rsp

    mov     eax, SYS_close
    syscall

    pop     rbp
    ret

; ==================================================================
; load_second_stage(fd, image_ptr, image_size)
; ==================================================================
load_second_stage:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi       ; fd
    mov     r13, rsi        ; image ptr
    mov     r14d, edx       ; image size

    ; Claim interface 0
    mov     edi, r12d
    call    claim_interface
    test    eax, eax
    js      .fail

    ; Build second-stage header (24 bytes on stack)
    sub     rsp, BCM_SECOND_STAGE_HEADER_BYTES
    mov     rdi, rsp
    mov     esi, r14d       ; bootcode size
    xor     edx, edx        ; no signature
    ; Write header size to [rdi] directly
    mov     [rdi], esi      ; bootcode size at bytes 0-3
    xor     eax, eax
    mov     [rdi + 4], eax
    mov     [rdi + 8], eax
    mov     [rdi + 12], eax
    mov     [rdi + 16], eax
    mov     [rdi + 20], eax

    ; Send header via control transfer
    mov     edi, r12d
    mov     rsi, rsp
    mov     edx, BCM_SECOND_STAGE_HEADER_BYTES
    call    send_control_bulk_payload
    test    eax, eax
    js      .fail_header

    ; Send bootcode image via control + bulk
    mov     edi, r12d
    mov     rsi, r13
    mov     edx, r14d
    call    send_control_bulk_payload
    test    eax, eax
    js      .fail_payload

    ; Wait for return code
    mov     edi, r12d
    call    read_return_code
    test    eax, eax
    jnz     .fail_return

    add     rsp, BCM_SECOND_STAGE_HEADER_BYTES
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail_header:
    add     rsp, BCM_SECOND_STAGE_HEADER_BYTES
.fail:
.fail_payload:
.fail_return:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; serve_boot_files()
; ==================================================================
serve_boot_files:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    lea     rdi, [msg_serving]
    call    print_str
    call    print_crlf

    ; Find device in file server phase
    mov     edi, 1          ; phase = file_server
    mov     esi, [opt_wait_ms]
    movzx   edx, byte [opt_wait]
    call    find_or_wait_boot_device
    test    rax, rax
    jz      .done

    mov     rdi, rax
    call    print_str
    lea     rsi, [msg_found]
    mov     edx, 1
    mov     edi, 1
    call    write_stdout
    call    print_crlf

    ; Open device
    mov     rdi, rax
    call    open_device
    test    eax, eax
    js      .done
    mov     r12d, eax       ; fd
    mov     [dev_fd], eax

    ; Claim interface
    mov     edi, r12d
    call    claim_interface
    test    eax, eax
    js      .close

    ; File server loop
.server_loop:
    ; Read file request (260 bytes control transfer)
    mov     edi, r12d
    lea     rsi, [file_msg_buf]
    mov     edx, BCM_FILE_MESSAGE_BYTES
    call    read_control

    ; Decode command
    mov     eax, [file_msg_buf]
    cmp     eax, BCM_FILE_CMD_DONE
    je      .server_done
    cmp     eax, BCM_FILE_CMD_GET_SIZE
    je      .cmd_get_size
    cmp     eax, BCM_FILE_CMD_READ
    je      .cmd_read

    ; Unknown command — send 0 length
    mov     edi, r12d
    xor     esi, esi
    call    send_length_only
    jmp     .server_loop

.cmd_get_size:
    lea     rdi, [file_msg_buf + 4]
    call    safe_file_name
    test    eax, eax
    jz      .send_zero

    lea     rdi, [file_msg_buf + 4]
    call    get_boot_file_size
    test    eax, eax
    jz      .send_zero

    mov     edi, r12d
    mov     esi, eax
    call    send_length_only
    jmp     .server_loop

.cmd_read:
    lea     rdi, [file_msg_buf + 4]
    call    safe_file_name
    test    eax, eax
    jz      .send_zero

    lea     rdi, [file_msg_buf + 4]
    call    read_boot_file
    test    rax, rax
    jz      .send_zero

    mov     r14, rax        ; data ptr
    mov     r15d, edx       ; data size

    mov     edi, r12d
    mov     rsi, r14
    mov     edx, r15d
    call    send_control_bulk_payload

    ; Free the file buffer (use munmap since we read with mmap)
    mov     rdi, r14
    mov     esi, r15d
    mov     eax, SYS_munmap
    syscall
    jmp     .server_loop

.send_zero:
    mov     edi, r12d
    xor     esi, esi
    call    send_length_only
    jmp     .server_loop

.server_done:
    lea     rdi, [msg_done]
    call    print_str
    call    print_crlf

.close:
    mov     edi, r12d
    call    close_device

.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; claim_interface(fd) -> 0 on success, -1 on failure
; ==================================================================
claim_interface:
    push    rbp
    mov     rbp, rsp

    mov     edi, edi
    mov     esi, USBDEVFS_CLAIM_INTERFACE
    xor     edx, edx        ; interface = 0
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail
    xor     eax, eax
    pop     rbp
    ret
.fail:
    mov     eax, -1
    pop     rbp
    ret

; ==================================================================
; send_control_bulk_payload(fd, data, size) -> 0 on success
; Sends a payload using control transfer to set length, then bulk writes.
; ==================================================================
send_control_bulk_payload:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi       ; fd
    mov     r13, rsi        ; data ptr
    mov     r14d, edx       ; size

    ; Build control transfer: USBDEVFS_CONTROL
    ; request_type = 0x40 (vendor out)
    ; request = 0
    ; value = size & 0xffff
    ; index = (size >> 16) & 0xffff
    ; length = 0
    ; timeout = TIMEOUT_MS
    ; data = NULL

    lea     r15, [usbctrl_buf]
    mov     byte [r15 + USBCTRL_REQUEST_TYPE], BCM_CONTROL_VENDOR_OUT
    mov     byte [r15 + USBCTRL_REQUEST], BCM_CONTROL_REQUEST
    mov     ax, r14w
    mov     [r15 + USBCTRL_VALUE], ax
    mov     eax, r14d
    shr     eax, 16
    mov     [r15 + USBCTRL_INDEX], ax
    mov     word [r15 + USBCTRL_LENGTH], 0
    mov     eax, [TIMEOUT_MS]
    mov     [r15 + USBCTRL_TIMEOUT], eax
    mov     qword [r15 + USBCTRL_DATA], 0

    ; ioctl(fd, USBDEVFS_CONTROL, &ctrl)
    mov     edi, r12d
    mov     esi, USBDEVFS_CONTROL
    mov     rdx, r15
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    ; Send data in bulk transfers
    xor     r15d, r15d      ; offset
.bulk_loop:
    cmp     r15d, r14d
    jae     .done

    mov     ecx, r14d
    sub     ecx, r15d
    cmp     ecx, BCM_MAX_BULK_BYTES
    jbe     .chunk_ok
    mov     ecx, BCM_MAX_BULK_BYTES
.chunk_ok:

    ; Build bulk transfer struct
    lea     rbx, [usbbulk_buf]
    mov     dword [rbx + USBBULK_ENDPOINT], BCM_ENDPOINT_OUT
    mov     [rbx + USBBULK_LEN], ecx
    mov     eax, [TIMEOUT_MS]
    mov     [rbx + USBBULK_TIMEOUT], eax
    lea     rax, [r13 + r15]
    mov     [rbx + USBBULK_DATA], rax

    ; ioctl(fd, USBDEVFS_BULK, &bulk)
    mov     edi, r12d
    mov     esi, USBDEVFS_BULK
    mov     rdx, rbx
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    add     r15d, ecx
    jmp     .bulk_loop

.done:
    xor     eax, eax

.fail_ret:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail:
    mov     eax, -1
    jmp     .fail_ret

; ==================================================================
; read_return_code(fd) -> 0 on success
; ==================================================================
read_return_code:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 32

    ; Build control transfer for read
    lea     r15, [usbctrl_buf]
    mov     byte [r15 + USBCTRL_REQUEST_TYPE], BCM_CONTROL_VENDOR_IN
    mov     byte [r15 + USBCTRL_REQUEST], BCM_CONTROL_REQUEST
    mov     ax, BCM_RETURN_CODE_BYTES
    mov     [r15 + USBCTRL_VALUE], ax  ; length in value
    mov     word [r15 + USBCTRL_INDEX], 0
    mov     [r15 + USBCTRL_LENGTH], ax
    mov     eax, [RETURN_TIMEOUT_MS]
    mov     [r15 + USBCTRL_TIMEOUT], eax
    lea     rax, [rbp - 4]   ; buffer for return code
    mov     [r15 + USBCTRL_DATA], rax

    mov     edi, edi          ; fd
    mov     esi, USBDEVFS_CONTROL
    mov     rdx, r15
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    mov     eax, [rbp - 4]   ; return code
    test    eax, eax
    jz      .ok

    ; Print error
    lea     rdi, [msg_return_failed]
    call    print_str
    mov     edi, [rbp - 4]
    call    print_hex32
    call    print_crlf
    mov     eax, -1
    jmp     .done

.ok:
    xor     eax, eax
.done:
    add     rsp, 32
    pop     rbp
    ret
.fail:
    mov     eax, -1
    jmp     .done

; ==================================================================
; read_control(fd, buf, len) -> 0 on success
; ==================================================================
read_control:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi       ; fd
    push    rsi             ; save buf
    push    rdx             ; save len

    ; Build control transfer
    lea     r15, [usbctrl_buf]
    mov     byte [r15 + USBCTRL_REQUEST_TYPE], BCM_CONTROL_VENDOR_IN
    mov     byte [r15 + USBCTRL_REQUEST], BCM_CONTROL_REQUEST
    mov     ax, dx          ; len
    mov     [r15 + USBCTRL_VALUE], ax
    mov     word [r15 + USBCTRL_INDEX], 0
    mov     [r15 + USBCTRL_LENGTH], ax
    mov     eax, [TIMEOUT_MS]
    mov     [r15 + USBCTRL_TIMEOUT], eax
    mov     [r15 + USBCTRL_DATA], rsi

    mov     edi, r12d
    mov     esi, USBDEVFS_CONTROL
    mov     rdx, r15
    mov     eax, SYS_ioctl
    syscall

    add     rsp, 16
    pop     r12
    pop     rbp
    ret

; ==================================================================
; send_length_only(fd, length)
; ==================================================================
send_length_only:
    push    rbp
    mov     rbp, rsp

    ; Build control transfer for write with length, no data
    lea     r15, [usbctrl_buf]
    mov     byte [r15 + USBCTRL_REQUEST_TYPE], BCM_CONTROL_VENDOR_OUT
    mov     byte [r15 + USBCTRL_REQUEST], BCM_CONTROL_REQUEST
    mov     ax, si          ; length
    mov     [r15 + USBCTRL_VALUE], ax
    mov     eax, esi
    shr     eax, 16
    mov     [r15 + USBCTRL_INDEX], ax
    mov     word [r15 + USBCTRL_LENGTH], 0
    mov     eax, [TIMEOUT_MS]
    mov     [r15 + USBCTRL_TIMEOUT], eax
    mov     qword [r15 + USBCTRL_DATA], 0

    mov     edi, edi
    mov     esi, USBDEVFS_CONTROL
    mov     rdx, r15
    mov     eax, SYS_ioctl
    syscall

    pop     rbp
    ret

; ==================================================================
; safe_file_name(name) -> 1 if safe, 0 if not
; ==================================================================
safe_file_name:
    push    rbp
    mov     rbp, rsp
    push    rbx

    mov     rbx, rdi
    cmp     byte [rbx], 0
    je      .unsafe         ; empty
    cmp     byte [rbx], '/'
    je      .unsafe
    cmp     byte [rbx], SAFE_FILE_BACKSLASH
    je      .unsafe
    cmp     byte [rbx], '*'
    je      .unsafe

    ; Check for ".."
    mov     rsi, rbx
.scan:
    cmp     byte [rsi], 0
    je      .safe
    cmp     byte [rsi], SAFE_FILE_BACKSLASH
    je      .unsafe
    ; Check for ".."
    cmp     byte [rsi], '.'
    jne     .next
    cmp     byte [rsi + 1], '.'
    jne     .next
    cmp     byte [rsi + 2], 0
    je      .unsafe
    cmp     byte [rsi + 2], '/'
    je      .unsafe
.next:
    inc     rsi
    jmp     .scan

.safe:
    mov     eax, 1
    pop     rbx
    pop     rbp
    ret
.unsafe:
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; get_boot_file_size(name) -> size or 0
; ==================================================================
get_boot_file_size:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13

    mov     r12, rdi        ; name

    ; Build path
    lea     rdi, [sysfs_path_buf]
    mov     rsi, [opt_boot_dir]
    mov     rdx, r12
    call    path_join

    ; Stat to get size (we'll read then stat)
    ; Use open + lseek(SEEK_END) instead
    lea     rdi, [sysfs_path_buf]
    xor     esi, esi        ; O_RDONLY
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .not_found

    mov     r12d, eax       ; fd

    ; lseek to end
    mov     edi, r12d
    xor     esi, esi
    mov     edx, 2          ; SEEK_END
    mov     eax, SYS_read   ; need to use a different approach... actually lseek is syscall 8
    ; Use syscall 8 for lseek
    mov     eax, 8
    syscall
    mov     r13d, eax       ; size

    ; Close
    mov     edi, r12d
    mov     eax, SYS_close
    syscall

    mov     eax, r13d
    pop     r13
    pop     r12
    pop     rbp
    ret

.not_found:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbp
    ret

; ==================================================================
; read_boot_file(name) -> ptr, size (rax=ptr, edx=size), or 0
; Uses mmap for file reading.
; ==================================================================
read_boot_file:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    push    r14

    mov     r12, rdi        ; name

    ; Check if it's "kernel.img"
    mov     rsi, str_kernel_img
    call    str_eq
    test    eax, eax
    jnz     .use_kernel_path

    ; Otherwise, join boot_dir + name
    lea     rdi, [sysfs_path_buf]
    mov     rsi, [opt_boot_dir]
    mov     rdx, r12
    call    path_join
    jmp     .open_file

.use_kernel_path:
    ; use opt_kernel_path directly
    mov     rdi, [opt_kernel_path]
    lea     rsi, [sysfs_path_buf]
    call    strcpy
    jmp     .open_file

.open_file:
    lea     rdi, [sysfs_path_buf]
    xor     esi, esi        ; O_RDONLY
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .not_found

    mov     r12d, eax       ; fd

    ; Get size via lseek
    mov     edi, r12d
    xor     esi, esi
    mov     edx, 2          ; SEEK_END
    mov     eax, 8          ; lseek
    syscall
    mov     r13d, eax       ; size
    js      .close_fail

    ; Seek back to beginning
    mov     edi, r12d
    xor     esi, esi
    xor     edx, edx        ; SEEK_SET
    mov     eax, 8          ; lseek
    syscall

    ; mmap the file
    xor     edi, edi        ; addr = 0
    mov     esi, r13d       ; length
    mov     edx, PROT_READ  ; prot
    mov     ecx, MAP_PRIVATE ; flags
    mov     r8d, r12d       ; fd
    xor     r9d, r9d        ; offset = 0
    mov     eax, SYS_mmap
    syscall
    cmp     rax, -1
    je      .close_fail

    ; Close fd
    push    rax             ; save mmap ptr
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
    pop     rax

    mov     edx, r13d       ; size in edx
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.close_fail:
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
.not_found:
    xor     eax, eax
    xor     edx, edx
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ==================================================================
; read_file(path) -> rax=ptr, edx=size, or rax=0 on failure
; Reads an entire file into a mmap'd buffer.
; ==================================================================
read_file:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13

    mov     r12, rdi        ; path
    xor     esi, esi        ; O_RDONLY
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .fail

    mov     r12d, eax       ; fd

    ; Get size
    mov     edi, r12d
    xor     esi, esi
    mov     edx, 2          ; SEEK_END
    mov     eax, 8          ; lseek
    syscall
    mov     r13d, eax       ; size
    test    eax, eax
    js      .close_fail

    ; Seek back
    mov     edi, r12d
    xor     esi, esi
    xor     edx, edx
    mov     eax, 8
    syscall

    ; mmap
    xor     edi, edi
    mov     esi, r13d
    mov     edx, PROT_READ
    mov     ecx, MAP_PRIVATE
    mov     r8d, r12d
    xor     r9d, r9d
    mov     eax, SYS_mmap
    syscall
    cmp     rax, -1
    je      .close_fail

    push    rax
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
    pop     rax

    mov     edx, r13d
    pop     r13
    pop     r12
    pop     rbp
    ret

.close_fail:
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
.fail:
    xor     eax, eax
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Utility functions
; ==================================================================

; sleep_ms(ms)
sleep_ms:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16

    ; Build timespec
    mov     eax, edi
    xor     edx, edx
    mov     ecx, 1000
    div     ecx
    mov     [rbp - 8], eax    ; sec
    mov     eax, edx
    mov     ecx, 1000000
    mul     ecx
    mov     [rbp - 4], eax    ; nsec

    lea     rdi, [rbp - 8]
    xor     esi, esi
    mov     eax, SYS_nanosleep
    syscall

    add     rsp, 16
    pop     rbp
    ret

; str_eq(str1, str2) -> 1 if equal, 0 if not
str_eq:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    rcx

    mov     rbx, rdi
    mov     rcx, rsi
.loop:
    mov     al, [rbx]
    cmp     al, [rcx]
    jne     .not_eq
    test    al, al
    jz      .eq
    inc     rbx
    inc     rcx
    jmp     .loop
.eq:
    mov     eax, 1
    pop     rcx
    pop     rbx
    pop     rbp
    ret
.not_eq:
    xor     eax, eax
    pop     rcx
    pop     rbx
    pop     rbp
    ret

; strcpy(src, dst) — copies null-terminated string
strcpy:
    push    rbp
    mov     rbp, rsp
    push    rcx
    mov     rcx, rdi
    mov     rdi, rsi
.loop:
    mov     al, [rcx]
    mov     [rdi], al
    test    al, al
    jz      .done
    inc     rcx
    inc     rdi
    jmp     .loop
.done:
    pop     rcx
    pop     rbp
    ret

; path_join(buf, dir, name) — writes "dir/name" into buf
path_join:
    push    rbp
    mov     rbp, rsp
    push    rcx

    ; Copy dir
.loop_dir:
    mov     al, [rsi]
    test    al, al
    jz      .add_slash
    mov     [rdi], al
    inc     rdi
    inc     rsi
    jmp     .loop_dir
.add_slash:
    mov     byte [rdi], '/'
    inc     rdi
    ; Copy name
.loop_name:
    mov     al, [rdx]
    test    al, al
    jz      .done
    mov     [rdi], al
    inc     rdi
    inc     rdx
    jmp     .loop_name
.done:
    mov     byte [rdi], 0
    pop     rcx
    pop     rbp
    ret

; format_usb_path(buf, bus, dev) — writes "/dev/bus/usb/BBB/DDD"
format_usb_path:
    push    rbp
    mov     rbp, rsp
    mov     r8d, edx

    ; Write "/dev/bus/usb/"
    mov     rcx, usb_path_prefix
    push    rdi
.loop_prefix:
    mov     al, [rcx]
    test    al, al
    jz      .prefix_done
    mov     [rdi], al
    inc     rdi
    inc     rcx
    jmp     .loop_prefix
.prefix_done:
    ; Write bus number (3 digits zero-padded)
    mov     eax, esi
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    add     al, '0'
    mov     [rdi], al
    inc     rdi
    mov     eax, edx
    mov     ecx, 10
    xor     edx, edx
    div     ecx
    add     al, '0'
    mov     [rdi], al
    inc     rdi
    mov     eax, edx
    add     al, '0'
    mov     [rdi], al
    inc     rdi

    ; Write '/'
    mov     byte [rdi], '/'
    inc     rdi

    ; Write device number (3 digits zero-padded)
    mov     eax, r8d
    mov     ecx, 100
    xor     edx, edx
    div     ecx
    add     al, '0'
    mov     [rdi], al
    inc     rdi
    mov     eax, edx
    mov     ecx, 10
    xor     edx, edx
    div     ecx
    add     al, '0'
    mov     [rdi], al
    inc     rdi
    add     dl, '0'
    mov     [rdi], dl
    inc     rdi

    mov     byte [rdi], 0
    pop     rdi
    pop     rbp
    ret

; parse_uint32(str) -> value
parse_uint32:
    push    rbp
    mov     rbp, rsp
    xor     eax, eax
.loop:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done
    sub     cl, '0'
    cmp     cl, 9
    ja      .done
    imul    eax, eax, 10
    add     eax, ecx
    inc     rdi
    jmp     .loop
.done:
    pop     rbp
    ret

; write_stdout(fd, buf, len)
write_stdout:
    push    rbp
    mov     rbp, rsp
    mov     eax, SYS_write
    syscall
    pop     rbp
    ret

; print_str(str)
print_str:
    push    rbp
    mov     rbp, rsp
    push    rdi
    push    rcx

    mov     rcx, rdi
    xor     edx, edx
.len_loop:
    cmp     byte [rcx + rdx], 0
    je      .print
    inc     edx
    jmp     .len_loop
.print:
    mov     rsi, rdi
    mov     edi, 1
    mov     eax, SYS_write
    syscall

    pop     rcx
    pop     rdi
    pop     rbp
    ret

; print_crlf()
print_crlf:
    push    rbp
    mov     rbp, rsp
    mov     edi, 1
    lea     rsi, [crlf]
    mov     edx, 1
    cmp     byte [rsi], 0x0a
    mov     edx, 2
    mov     eax, SYS_write
    syscall
    pop     rbp
    ret

; print_dec(value)
print_dec:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16
    mov     rcx, 10
    lea     rbx, [rbp - 1]
    mov     byte [rbx], 0
    mov     eax, edi
.loop:
    xor     edx, edx
    div     ecx
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    test    eax, eax
    jnz     .loop

    mov     rsi, rbx
    lea     rdx, [rbp - 1]
    sub     rdx, rbx
    mov     edi, 1
    mov     eax, SYS_write
    syscall

    add     rsp, 16
    pop     rbp
    ret

; print_hex32(value)
print_hex32:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16
    mov     ecx, 8
    lea     rbx, [rbp - 1]
    mov     byte [rbx], 0
    mov     eax, edi
.hex_loop:
    mov     edx, eax
    and     edx, 0xf
    cmp     dl, 9
    jbe     .hex_digit
    add     dl, ('a' - 10 - '0')
.hex_digit:
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    shr     eax, 4
    dec     ecx
    jnz     .hex_loop

    mov     rsi, rbx
    lea     rdx, [rbp - 1]
    sub     rdx, rbx
    inc     edx
    mov     edi, 1
    mov     eax, SYS_write
    syscall

    add     rsp, 16
    pop     rbp
    ret

; sys_exit(exit_code)
sys_exit:
    mov     eax, SYS_exit_group
    syscall

; ==================================================================
; Data strings
; ==================================================================
section .data

sysfs_usb_devices: db "/sys/bus/usb/devices", 0
usb_path_prefix:   db "/dev/bus/usb/", 0
crlf:              db 0x0a
crlf2:             db 0x0d, 0x0a

str_dry_run:       db "--dry-run", 0
str_serve_only:    db "--serve-only", 0
str_wait:          db "--wait", 0
str_wait_ms:       db "--wait-ms", 0
str_serve_dir:     db "--serve-dir", 0
str_kernel:        db "--kernel-image", 0
str_help:          db "--help", 0
str_kernel_img:    db "kernel.img", 0

msg_plan1:         db "BCM2708 second-stage plan: bootcode=", 0
msg_plan1_len      equ $ - msg_plan1
msg_plan2:         db " bytes image=", 0
msg_plan2_len      equ $ - msg_plan2
msg_found:         db " found", 0
msg_not_found:     db "BCM2708 boot device not found", 0
msg_open_failed:   db "Failed to open device", 0
msg_return_failed: db "BCM2708 second-stage returned 0x", 0
msg_serving:       db "Waiting for BCM2708 file server...", 0
msg_done:          db "BCM2708 file server done", 0
msg_bad_arg:       db "Invalid argument. Use --help for usage.", 0

usage_str:         db "Usage: pi_usb_boot_host [options] [bootcode.bin]", 0x0a
                   db "Options:", 0x0a
                   db "  --dry-run              Scan but don't boot", 0x0a
                   db "  --serve-only           Skip first-stage, just serve files", 0x0a
                   db "  --wait                 Wait for device", 0x0a
                   db "  --wait-ms <ms>         Wait timeout (default: forever)", 0x0a
                   db "  --serve-dir <dir>      Boot file directory", 0x0a
                   db "  --kernel-image <path>  kernel.img path", 0x0a
                   db "  --help                 Show this help", 0x0a
                   db 0
