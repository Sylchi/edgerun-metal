; EdgeRun Pi USB control host tool — x86_64 Linux userspace assembly
;
; Usage:
;   pi_usb_control_host [--dry-run] [--wait|--wait-ms N] gpio-read PIN
;   pi_usb_control_host [--dry-run] [--wait|--wait-ms N] gpio-write PIN VALUE
;   pi_usb_control_host [--dry-run] [--wait|--wait-ms N] memory-read ADDRESS LENGTH

%include "host/bcm2708_usb_boot.inc"

USB_SCAN_MAX_NUM equ 127
USB_DESCRIPTOR_DEVICE_LEN equ 18
USB_DESCRIPTOR_TYPE_DEVICE equ 0x0100
USB_REQUEST_GET_DESCRIPTOR equ 0x06
USB_REQUEST_TYPE_STANDARD_IN equ 0x80
USB_DEVICE_DESC_VENDOR equ 8
USB_DEVICE_DESC_PRODUCT equ 10

ERPI_MAGIC equ 0x55524345
ERPI_ABI_VERSION equ 1
ERPI_VENDOR_ID equ 0x4552
ERPI_PRODUCT_ID equ 0x5049
ERPI_ENDPOINT_OUT equ 0x01
ERPI_ENDPOINT_IN equ 0x81
ERPI_MAX_TRANSFER_BYTES equ 16384
ERPI_REQUEST_HEADER_BYTES equ 40
ERPI_RESPONSE_HEADER_BYTES equ 28
ERPI_FLAGS_WRITE_RESPONSE equ 0x00000005
ERPI_FLAGS_READ_RESPONSE equ 0x00000006
ERPI_COMMAND_GPIO_READ equ 0x00020001
ERPI_COMMAND_GPIO_WRITE equ 0x00020002
ERPI_COMMAND_MEMORY_READ equ 0x00050001
ERPI_STATUS_OK equ 0
ERPI_STATUS_BAD_REQUEST equ 1
ERPI_STATUS_UNSUPPORTED equ 2
ERPI_STATUS_IO_ERROR equ 3

TIMEOUT_MS equ 5000
WAIT_POLL_MS equ 250
WAIT_FOREVER_MS equ 0xffffffff
O_RDONLY equ 0
O_RDWR equ 2

section .bss
opt_dry_run:     resb 1
opt_wait:        resb 1
opt_help:        resb 1
opt_wait_ms:     resd 1
opt_sequence:    resd 1
opt_command:     resd 1
opt_address:     resq 1
opt_length:      resd 1
opt_value:       resd 1
dev_path:        resb 32
usbctrl_buf:     resb USBCTRL_SIZE
usbbulk_buf:     resb USBBULK_SIZE
descriptor_buf:  resb USB_DESCRIPTOR_DEVICE_LEN
request_buf:     resb ERPI_REQUEST_HEADER_BYTES
response_buf:    resb ERPI_RESPONSE_HEADER_BYTES
transfer_buf:    resb ERPI_MAX_TRANSFER_BYTES
stack_bottom:    resb 65536
stack_top:

section .text
global _start

_start:
    mov     r14, [rsp]
    lea     r15, [rsp + 8]
    mov     rsp, stack_top

    mov     byte [opt_dry_run], 0
    mov     byte [opt_wait], 0
    mov     byte [opt_help], 0
    mov     dword [opt_wait_ms], WAIT_FOREVER_MS
    mov     dword [opt_sequence], 1
    mov     dword [opt_command], 0
    mov     qword [opt_address], 0
    mov     dword [opt_length], 0
    mov     dword [opt_value], 0

    mov     rdi, r14
    mov     rsi, r15
    call    parse_options
    cmp     byte [opt_help], 1
    je      .help

    cmp     dword [opt_command], 0
    je      .bad_args
    call    encode_request
    test    eax, eax
    jz      .bad_args

    cmp     byte [opt_dry_run], 1
    je      .dry_run

    movzx   edi, byte [opt_wait]
    mov     esi, [opt_wait_ms]
    call    find_or_wait_device
    test    rax, rax
    jz      .not_found

    lea     rdi, [msg_found]
    call    print_str
    lea     rdi, [dev_path]
    call    print_str
    call    print_lf

    lea     rdi, [dev_path]
    call    transact
    test    eax, eax
    jz      .ok
    mov     edi, 1
    call    sys_exit

.dry_run:
    call    print_plan
.ok:
    xor     edi, edi
    call    sys_exit

.help:
    lea     rdi, [usage]
    call    print_str
    xor     edi, edi
    call    sys_exit

.bad_args:
    lea     rdi, [msg_bad_args]
    call    print_str
    mov     edi, 1
    call    sys_exit

.not_found:
    lea     rdi, [msg_not_found]
    call    print_str
    mov     edi, 1
    call    sys_exit

; parse_options(argc, argv)
parse_options:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, edi
    mov     r13, rsi
    mov     ebx, 1
.opt_loop:
    cmp     ebx, r12d
    jae     .bad
    mov     r14, [r13 + rbx * 8]
    cmp     byte [r14], '-'
    jne     .command
    inc     ebx
    mov     rdi, r14
    lea     rsi, [str_dry_run]
    call    str_eq
    test    eax, eax
    jz      .check_wait
    mov     byte [opt_dry_run], 1
    jmp     .opt_loop
.check_wait:
    mov     rdi, r14
    lea     rsi, [str_wait]
    call    str_eq
    test    eax, eax
    jz      .check_wait_ms
    mov     byte [opt_wait], 1
    jmp     .opt_loop
.check_wait_ms:
    mov     rdi, r14
    lea     rsi, [str_wait_ms]
    call    str_eq
    test    eax, eax
    jz      .check_help
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_uint64
    mov     [opt_wait_ms], eax
    mov     byte [opt_wait], 1
    jmp     .opt_loop
.check_help:
    mov     rdi, r14
    lea     rsi, [str_help]
    call    str_eq
    test    eax, eax
    jz      .bad
    mov     byte [opt_help], 1
    jmp     .done

.command:
    mov     rdi, r14
    lea     rsi, [str_gpio_read]
    call    str_eq
    test    eax, eax
    jz      .check_gpio_write
    inc     ebx
    mov     eax, ebx
    inc     eax
    cmp     eax, r12d
    jne     .bad
    mov     rdi, [r13 + rbx * 8]
    call    parse_uint64
    mov     [opt_address], rax
    mov     dword [opt_length], 4
    mov     dword [opt_command], ERPI_COMMAND_GPIO_READ
    jmp     .done

.check_gpio_write:
    mov     rdi, r14
    lea     rsi, [str_gpio_write]
    call    str_eq
    test    eax, eax
    jz      .check_memory_read
    inc     ebx
    mov     eax, ebx
    add     eax, 2
    cmp     eax, r12d
    jne     .bad
    mov     rdi, [r13 + rbx * 8]
    call    parse_uint64
    mov     [opt_address], rax
    inc     ebx
    mov     rdi, [r13 + rbx * 8]
    call    parse_uint64
    mov     [opt_value], eax
    mov     dword [opt_length], 0
    mov     dword [opt_command], ERPI_COMMAND_GPIO_WRITE
    jmp     .done

.check_memory_read:
    mov     rdi, r14
    lea     rsi, [str_memory_read]
    call    str_eq
    test    eax, eax
    jz      .bad
    inc     ebx
    mov     eax, ebx
    add     eax, 2
    cmp     eax, r12d
    jne     .bad
    mov     rdi, [r13 + rbx * 8]
    call    parse_uint64
    mov     [opt_address], rax
    inc     ebx
    mov     rdi, [r13 + rbx * 8]
    call    parse_uint64
    mov     [opt_length], eax
    mov     dword [opt_command], ERPI_COMMAND_MEMORY_READ
    jmp     .done

.bad:
    mov     dword [opt_command], 0
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

encode_request:
    mov     ecx, ERPI_REQUEST_HEADER_BYTES
    lea     rdi, [request_buf]
    xor     eax, eax
    rep stosb
    cmp     dword [opt_sequence], 0
    je      .fail
    mov     eax, [opt_command]
    cmp     eax, ERPI_COMMAND_GPIO_READ
    je      .read_flags
    cmp     eax, ERPI_COMMAND_MEMORY_READ
    je      .read_flags
    cmp     eax, ERPI_COMMAND_GPIO_WRITE
    jne     .fail
    cmp     dword [opt_length], 0
    jne     .fail
    mov     edx, ERPI_FLAGS_WRITE_RESPONSE
    jmp     .write
.read_flags:
    cmp     dword [opt_length], 0
    je      .fail
    cmp     dword [opt_length], ERPI_MAX_TRANSFER_BYTES
    ja      .fail
    mov     edx, ERPI_FLAGS_READ_RESPONSE
.write:
    mov     dword [request_buf + 0], ERPI_MAGIC
    mov     word [request_buf + 4], ERPI_ABI_VERSION
    mov     word [request_buf + 6], ERPI_REQUEST_HEADER_BYTES
    mov     ecx, [opt_sequence]
    mov     [request_buf + 8], ecx
    mov     [request_buf + 12], eax
    mov     [request_buf + 16], edx
    mov     rcx, [opt_address]
    mov     [request_buf + 24], rcx
    mov     ecx, [opt_length]
    mov     [request_buf + 32], ecx
    mov     ecx, [opt_value]
    mov     [request_buf + 36], ecx
    mov     eax, 1
    ret
.fail:
    xor     eax, eax
    ret

find_or_wait_device:
    push    rbx
    push    r12
    push    r13
    mov     r12d, edi
    mov     r13d, esi
    xor     ebx, ebx
.loop:
    call    find_device
    test    rax, rax
    jnz     .done
    test    r12b, r12b
    jz      .done
    cmp     r13d, WAIT_FOREVER_MS
    je      .sleep
    cmp     ebx, r13d
    jae     .done
.sleep:
    mov     edi, WAIT_POLL_MS
    call    sleep_ms
    add     ebx, WAIT_POLL_MS
    jmp     .loop
.done:
    pop     r13
    pop     r12
    pop     rbx
    ret

find_device:
    push    rbx
    push    r12
    push    r13
    push    r14
    xor     ebx, ebx
.bus_loop:
    inc     ebx
    cmp     ebx, USB_SCAN_MAX_NUM
    ja      .none
    xor     r12d, r12d
.dev_loop:
    inc     r12d
    cmp     r12d, USB_SCAN_MAX_NUM
    ja      .bus_loop
    lea     rdi, [dev_path]
    mov     esi, ebx
    mov     edx, r12d
    call    format_usb_path
    lea     rdi, [dev_path]
    mov     esi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .dev_loop
    mov     r13d, eax
    mov     edi, r13d
    call    is_control_device
    mov     r14d, eax
    mov     edi, r13d
    mov     eax, SYS_close
    syscall
    test    r14d, r14d
    jz      .dev_loop
    lea     rax, [dev_path]
    jmp     .done
.none:
    xor     eax, eax
.done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

is_control_device:
    mov     byte [usbctrl_buf + USBCTRL_REQUEST_TYPE], USB_REQUEST_TYPE_STANDARD_IN
    mov     byte [usbctrl_buf + USBCTRL_REQUEST], USB_REQUEST_GET_DESCRIPTOR
    mov     word [usbctrl_buf + USBCTRL_VALUE], USB_DESCRIPTOR_TYPE_DEVICE
    mov     word [usbctrl_buf + USBCTRL_INDEX], 0
    mov     word [usbctrl_buf + USBCTRL_LENGTH], USB_DESCRIPTOR_DEVICE_LEN
    mov     dword [usbctrl_buf + USBCTRL_TIMEOUT], TIMEOUT_MS
    lea     rax, [descriptor_buf]
    mov     qword [usbctrl_buf + USBCTRL_DATA], rax
    mov     esi, USBDEVFS_CONTROL
    lea     rdx, [usbctrl_buf]
    mov     eax, SYS_ioctl
    syscall
    cmp     eax, USB_DESCRIPTOR_DEVICE_LEN
    jl      .no
    movzx   eax, word [descriptor_buf + USB_DEVICE_DESC_VENDOR]
    cmp     eax, ERPI_VENDOR_ID
    jne     .no
    movzx   eax, word [descriptor_buf + USB_DEVICE_DESC_PRODUCT]
    cmp     eax, ERPI_PRODUCT_ID
    jne     .no
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

transact:
    push    rbx
    push    r12
    mov     esi, O_RDWR
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .fail
    mov     r12d, eax
    mov     edi, r12d
    call    claim_interface
    test    eax, eax
    js      .close_fail
    mov     edi, r12d
    mov     esi, ERPI_ENDPOINT_OUT
    lea     rdx, [request_buf]
    mov     ecx, ERPI_REQUEST_HEADER_BYTES
    call    bulk_transfer
    test    eax, eax
    js      .release_fail
    mov     edi, r12d
    mov     esi, ERPI_ENDPOINT_IN
    lea     rdx, [response_buf]
    mov     ecx, ERPI_RESPONSE_HEADER_BYTES
    call    bulk_transfer
    test    eax, eax
    js      .release_fail
    call    decode_response
    test    eax, eax
    jz      .release_fail
    call    print_response
    cmp     dword [response_buf + 16], ERPI_STATUS_OK
    jne     .release_fail
    cmp     dword [opt_command], ERPI_COMMAND_MEMORY_READ
    jne     .release_ok
    mov     ecx, [response_buf + 20]
    test    ecx, ecx
    jz      .release_ok
    cmp     ecx, ERPI_MAX_TRANSFER_BYTES
    ja      .release_fail
    mov     edi, r12d
    mov     esi, ERPI_ENDPOINT_IN
    lea     rdx, [transfer_buf]
    call    bulk_transfer
    test    eax, eax
    js      .release_fail
    lea     rdi, [transfer_buf]
    mov     esi, [response_buf + 20]
    call    dump_hex
.release_ok:
    mov     edi, r12d
    call    release_interface
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
    xor     eax, eax
    jmp     .done
.release_fail:
    mov     edi, r12d
    call    release_interface
.close_fail:
    mov     edi, r12d
    mov     eax, SYS_close
    syscall
.fail:
    mov     eax, 1
.done:
    pop     r12
    pop     rbx
    ret

claim_interface:
    sub     rsp, 8
    mov     dword [rsp], 0
    mov     esi, USBDEVFS_CLAIM_INTERFACE
    mov     rdx, rsp
    mov     eax, SYS_ioctl
    syscall
    add     rsp, 8
    ret

release_interface:
    sub     rsp, 8
    mov     dword [rsp], 0
    mov     esi, USBDEVFS_RELEASE_INTERFACE
    mov     rdx, rsp
    mov     eax, SYS_ioctl
    syscall
    add     rsp, 8
    ret

bulk_transfer:
    mov     dword [usbbulk_buf + USBBULK_ENDPOINT], esi
    mov     dword [usbbulk_buf + USBBULK_LEN], ecx
    mov     dword [usbbulk_buf + USBBULK_TIMEOUT], TIMEOUT_MS
    mov     qword [usbbulk_buf + USBBULK_DATA], rdx
    mov     esi, USBDEVFS_BULK
    lea     rdx, [usbbulk_buf]
    mov     eax, SYS_ioctl
    syscall
    ret

decode_response:
    cmp     dword [response_buf + 0], ERPI_MAGIC
    jne     .bad
    cmp     word [response_buf + 4], ERPI_ABI_VERSION
    jne     .bad
    cmp     word [response_buf + 6], ERPI_RESPONSE_HEADER_BYTES
    jne     .bad
    mov     eax, [opt_sequence]
    cmp     [response_buf + 8], eax
    jne     .bad
    mov     eax, [opt_command]
    cmp     [response_buf + 12], eax
    jne     .bad
    mov     eax, [response_buf + 16]
    cmp     eax, ERPI_STATUS_IO_ERROR
    ja      .bad
    mov     eax, 1
    ret
.bad:
    xor     eax, eax
    ret

print_plan:
    lea     rdi, [msg_plan_sequence]
    call    print_str
    mov     edi, [opt_sequence]
    call    print_dec
    lea     rdi, [msg_plan_command]
    call    print_str
    call    print_command_name
    lea     rdi, [msg_plan_address]
    call    print_str
    mov     rdi, [opt_address]
    call    print_hex64
    lea     rdi, [msg_plan_length]
    call    print_str
    mov     edi, [opt_length]
    call    print_dec
    lea     rdi, [msg_plan_value]
    call    print_str
    mov     edi, [opt_value]
    call    print_hex32
    call    print_lf
    ret

print_response:
    lea     rdi, [msg_status]
    call    print_str
    mov     eax, [response_buf + 16]
    cmp     eax, ERPI_STATUS_OK
    je      .ok
    cmp     eax, ERPI_STATUS_BAD_REQUEST
    je      .bad_request
    cmp     eax, ERPI_STATUS_UNSUPPORTED
    je      .unsupported
    lea     rdi, [str_io_error]
    jmp     .status
.ok:
    lea     rdi, [str_ok]
    jmp     .status
.bad_request:
    lea     rdi, [str_bad_request]
    jmp     .status
.unsupported:
    lea     rdi, [str_unsupported]
.status:
    call    print_str
    lea     rdi, [msg_length]
    call    print_str
    mov     edi, [response_buf + 20]
    call    print_dec
    lea     rdi, [msg_value]
    call    print_str
    mov     edi, [response_buf + 24]
    call    print_hex32
    call    print_lf
    ret

print_command_name:
    mov     eax, [opt_command]
    cmp     eax, ERPI_COMMAND_GPIO_READ
    je      .gpio_read
    cmp     eax, ERPI_COMMAND_GPIO_WRITE
    je      .gpio_write
    lea     rdi, [str_memory_read]
    jmp     print_str
.gpio_read:
    lea     rdi, [str_gpio_read]
    jmp     print_str
.gpio_write:
    lea     rdi, [str_gpio_write]
    jmp     print_str

dump_hex:
    push    rbx
    push    r12
    mov     r12, rdi
    xor     ebx, ebx
.loop:
    cmp     ebx, esi
    jae     .done
    movzx   edi, byte [r12 + rbx]
    call    print_hex8
    inc     ebx
    mov     eax, ebx
    and     eax, 15
    jz      .newline
    cmp     ebx, esi
    jae     .newline
    lea     rdi, [space]
    call    print_str
    jmp     .loop
.newline:
    call    print_lf
    jmp     .loop
.done:
    pop     r12
    pop     rbx
    ret

sleep_ms:
    sub     rsp, 16
    mov     eax, edi
    xor     edx, edx
    mov     ecx, 1000
    div     ecx
    mov     qword [rsp], rax
    mov     eax, edx
    mov     ecx, 1000000
    mul     ecx
    mov     qword [rsp + 8], rax
    mov     rdi, rsp
    xor     esi, esi
    mov     eax, SYS_nanosleep
    syscall
    add     rsp, 16
    ret

str_eq:
.loop:
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .no
    test    al, al
    jz      .yes
    inc     rdi
    inc     rsi
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

parse_uint64:
    xor     eax, eax
    cmp     byte [rdi], '0'
    jne     .dec_loop
    mov     cl, [rdi + 1]
    cmp     cl, 'x'
    je      .hex_start
    cmp     cl, 'X'
    jne     .dec_loop
.hex_start:
    add     rdi, 2
.hex_loop:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done
    cmp     cl, '0'
    jb      .done
    cmp     cl, '9'
    jbe     .hex_digit
    cmp     cl, 'a'
    jb      .hex_upper
    cmp     cl, 'f'
    ja      .done
    sub     cl, 'a' - 10
    jmp     .hex_add
.hex_upper:
    cmp     cl, 'A'
    jb      .done
    cmp     cl, 'F'
    ja      .done
    sub     cl, 'A' - 10
    jmp     .hex_add
.hex_digit:
    sub     cl, '0'
.hex_add:
    shl     rax, 4
    add     rax, rcx
    inc     rdi
    jmp     .hex_loop
.dec_loop:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done
    sub     cl, '0'
    cmp     cl, 9
    ja      .done
    imul    rax, rax, 10
    add     rax, rcx
    inc     rdi
    jmp     .dec_loop
.done:
    ret

format_usb_path:
    push    rdi
    lea     rcx, [usb_path_prefix]
.prefix:
    mov     al, [rcx]
    test    al, al
    jz      .bus
    mov     [rdi], al
    inc     rdi
    inc     rcx
    jmp     .prefix
.bus:
    mov     eax, esi
    call    write_3digits
    mov     byte [rdi], '/'
    inc     rdi
    mov     eax, edx
    call    write_3digits
    mov     byte [rdi], 0
    pop     rdi
    ret

write_3digits:
    push    rdx
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
    pop     rdx
    ret

print_str:
    push    rdi
    xor     edx, edx
.len:
    cmp     byte [rdi + rdx], 0
    je      .write
    inc     edx
    jmp     .len
.write:
    mov     rsi, rdi
    mov     edi, 1
    mov     eax, SYS_write
    syscall
    pop     rdi
    ret

print_lf:
    lea     rdi, [lf]
    jmp     print_str

print_dec:
    push    rbx
    sub     rsp, 32
    mov     eax, edi
    lea     rbx, [rsp + 31]
    mov     byte [rbx], 0
    mov     ecx, 10
.loop:
    xor     edx, edx
    div     ecx
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    test    eax, eax
    jnz     .loop
    mov     rdi, rbx
    call    print_str
    add     rsp, 32
    pop     rbx
    ret

print_hex8:
    push    rbx
    sub     rsp, 4
    lea     rbx, [rsp]
    mov     byte [rbx + 2], 0
    mov     eax, edi
    mov     ecx, 2
    lea     rbx, [rbx + 2]
.loop:
    mov     edx, eax
    and     edx, 0x0f
    cmp     dl, 9
    jbe     .digit
    add     dl, 'a' - 10 - '0'
.digit:
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    shr     eax, 4
    dec     ecx
    jnz     .loop
    mov     rdi, rbx
    call    print_str
    add     rsp, 4
    pop     rbx
    ret

print_hex32:
    mov     eax, edi
    mov     ecx, 8
    jmp     print_hex_common

print_hex64:
    mov     rax, rdi
    mov     ecx, 16

print_hex_common:
    push    rbx
    sub     rsp, 24
    lea     rbx, [rsp + 23]
    mov     byte [rbx], 0
.loop:
    mov     rdx, rax
    and     edx, 0x0f
    cmp     dl, 9
    jbe     .digit
    add     dl, 'a' - 10 - '0'
.digit:
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    shr     rax, 4
    dec     ecx
    jnz     .loop
    mov     rdi, rbx
    call    print_str
    add     rsp, 24
    pop     rbx
    ret

sys_exit:
    mov     eax, SYS_exit_group
    syscall

section .data
usage: db "Usage: pi_usb_control_host [--dry-run] [--wait|--wait-ms N] gpio-read PIN", 10
       db "       pi_usb_control_host [--dry-run] [--wait|--wait-ms N] gpio-write PIN VALUE", 10
       db "       pi_usb_control_host [--dry-run] [--wait|--wait-ms N] memory-read ADDRESS LENGTH", 10, 0
msg_bad_args: db "invalid arguments", 10, 0
msg_not_found: db "Edgerun Pi control device not found", 10, 0
msg_found: db "found Edgerun Pi control device at ", 0
msg_plan_sequence: db "Edgerun Pi control plan: sequence=", 0
msg_plan_command: db " command=", 0
msg_plan_address: db " address=0x", 0
msg_plan_length: db " length=", 0
msg_plan_value: db " value=0x", 0
msg_status: db "status=", 0
msg_length: db " length=", 0
msg_value: db " value=0x", 0
str_dry_run: db "--dry-run", 0
str_wait: db "--wait", 0
str_wait_ms: db "--wait-ms", 0
str_help: db "--help", 0
str_gpio_read: db "gpio-read", 0
str_gpio_write: db "gpio-write", 0
str_memory_read: db "memory-read", 0
str_ok: db "ok", 0
str_bad_request: db "bad_request", 0
str_unsupported: db "unsupported", 0
str_io_error: db "io_error", 0
usb_path_prefix: db "/dev/bus/usb/", 0
space: db " ", 0
lf: db 10, 0
