; ESP32 serial boot host tool — x86_64 Linux userspace assembly
; Target: x86_64 (host) talking to ESP32 ROM bootloader over UART
;
; Usage: esp32_serial_boot_host [options] <binary> [entry_point]

%include "host/esp32_serial_boot.inc"
%include "esp32s3/jc3248w535/registers.inc"

%define PROT_READ           1
%define MAP_PRIVATE          2
%define SYS_mmap             9
%define SYS_munmap           11
%define SYS_exit_group       231
%define SYS_lseek            8

section .data
default_port:   db "/dev/ttyUSB0", 0

section .bss
opt_port:       resq 1
opt_baud:       resd 1
opt_entry:      resd 1
opt_flash_offset: resd 1
opt_binary:     resq 1
opt_help:       resb 1
opt_dry_run:    resb 1
opt_flash:      resb 1
opt_no_reset:   resb 1
opt_sync_only:  resb 1
opt_read_reg:   resb 1
opt_read_reg_addr: resd 1
opt_write_reg:  resb 1
opt_write_reg_addr: resd 1
opt_write_reg_value: resd 1
opt_write_reg_mask: resd 1
opt_write_reg_delay: resd 1
opt_jc3248_bl: resb 1
opt_jc3248_spi2: resb 1
opt_jc3248_qspi_route: resb 1
opt_jc3248_spi2_init: resb 1
opt_jc3248_lcd_cmd: resb 1
opt_jc3248_lcd_cmd_value: resd 1
opt_jc3248_lcd_unlock: resb 1
opt_jc3248_lcd_wake: resb 1
opt_jc3248_lcd_smoke: resb 1
opt_jc3248_lcd_stripes: resb 1
opt_jc3248_lcd_status: resb 1

binary_data:    resq 1
binary_size:    resd 1

serial_fd:      resd 1
download_packets: resd 1
read_reg_value: resd 1
spi_word_index: resd 1

; Buffers: packet building (raw), SLIP output, receive
pkt_buf:        resb 16384 + 256
slip_buf:       resb 16384 + 512
recv_buf:       resb 4096

termios_buf:    resb TERMIO2_SIZE
rtsdtr_val:     resd 1

stack_bottom:   resb 65536
stack_top:

section .text
global _start

%macro jc_lcd_cmd_data_checked 3
    mov     edi, r12d
    mov     esi, %1
    lea     rdx, [%2]
    mov     ecx, %3
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail
%endmacro

%macro jc_lcd_chunk_burst_checked 3
    mov     edi, r12d
    lea     rsi, [%1]
    mov     edx, %2
    mov     ecx, %3
    call    jc3248_lcd_send_chunks
    test    eax, eax
    jnz     .fail
%endmacro

_start:
    mov     r14, [rsp]
    lea     r15, [rsp + 8]
    mov     rsp, stack_top

    mov     qword [opt_port], default_port
    mov     dword [opt_baud], ESP_DEFAULT_BAUD
    mov     dword [opt_entry], ESP32S3_IRAM_ENTRY
    mov     dword [opt_flash_offset], ESP_DEFAULT_FLASH_OFF
    mov     byte [opt_help], 0
    mov     byte [opt_dry_run], 0
    mov     byte [opt_flash], 0
    mov     byte [opt_no_reset], 0
    mov     byte [opt_sync_only], 0
    mov     byte [opt_read_reg], 0
    mov     dword [opt_read_reg_addr], 0
    mov     byte [opt_write_reg], 0
    mov     dword [opt_write_reg_addr], 0
    mov     dword [opt_write_reg_value], 0
    mov     dword [opt_write_reg_mask], 0xffffffff
    mov     dword [opt_write_reg_delay], 0
    mov     byte [opt_jc3248_bl], 0
    mov     byte [opt_jc3248_spi2], 0
    mov     byte [opt_jc3248_qspi_route], 0
    mov     byte [opt_jc3248_spi2_init], 0
    mov     byte [opt_jc3248_lcd_cmd], 0
    mov     dword [opt_jc3248_lcd_cmd_value], 0
    mov     byte [opt_jc3248_lcd_unlock], 0
    mov     byte [opt_jc3248_lcd_wake], 0
    mov     byte [opt_jc3248_lcd_smoke], 0
    mov     byte [opt_jc3248_lcd_stripes], 0
    mov     byte [opt_jc3248_lcd_status], 0
    mov     qword [opt_binary], 0

    cmp     r14, 2
    jne     .parse_start
    mov     rax, [r15 + 8]
    cmp     dword [rax], 0x65682d2d
    jne     .parse_start
    cmp     word [rax + 4], 0x706c
    jne     .parse_start
    cmp     byte [rax + 6], 0
    je      .help_exit

.parse_start:
    mov     rdi, r14
    mov     rsi, r15
    call    parse_options
    cmp     byte [opt_help], 1
    je      .help_exit
    cmp     byte [opt_sync_only], 1
    je      .skip_binary_read
    cmp     byte [opt_read_reg], 1
    je      .skip_binary_read
    cmp     byte [opt_write_reg], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_bl], 0
    jne     .skip_binary_read
    cmp     byte [opt_jc3248_spi2], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_qspi_route], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_spi2_init], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_lcd_cmd], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_lcd_unlock], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_lcd_wake], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_lcd_smoke], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_lcd_stripes], 1
    je      .skip_binary_read
    cmp     byte [opt_jc3248_lcd_status], 1
    je      .skip_binary_read
    cmp     qword [opt_binary], 0
    je      .help_exit

    mov     rdi, [opt_binary]
    call    read_file
    test    rax, rax
    jz      .file_err
    mov     [binary_data], rax
    mov     [binary_size], edx

    cmp     byte [opt_flash], 1
    jne     .plan_ram
    lea     rdi, [m_plan_flash]
    call    print_str
    mov     edi, [opt_flash_offset]
    call    print_hex32
    lea     rdi, [m_plan_sep]
    call    print_str
    jmp     .plan_size
.plan_ram:
    lea     rdi, [m_plan_ram]
    call    print_str
.plan_size:
    mov     edi, [binary_size]
    call    print_dec
    lea     rdi, [m_to]
    call    print_str
    mov     rdi, [opt_port]
    call    print_str
    call    print_crlf

    cmp     byte [opt_dry_run], 1
    je      .dry_exit
    jmp     .open_port

.skip_binary_read:
    cmp     byte [opt_dry_run], 1
    je      .dry_exit

.open_port:
    mov     rdi, [opt_port]
    call    serial_open
    test    eax, eax
    js      .open_err
    mov     [serial_fd], eax

    mov     edi, eax
    mov     esi, [opt_baud]
    call    serial_configure
    test    eax, eax
    js      .cfg_err

    cmp     byte [opt_no_reset], 1
    je      .sync_start
    mov     edi, [serial_fd]
    call    esp_reset
    test    eax, eax
    js      .rst_err

.sync_start:
    mov     edi, [serial_fd]
    call    esp_sync
    test    eax, eax
    jnz     .sync_err

    cmp     byte [opt_sync_only], 1
    je      .sync_ok
    mov     edi, [serial_fd]
    call    serial_drain
    cmp     byte [opt_read_reg], 1
    je      .read_reg
    cmp     byte [opt_write_reg], 1
    je      .write_reg
    cmp     byte [opt_jc3248_bl], 0
    jne     .jc3248_backlight
    cmp     byte [opt_jc3248_spi2], 1
    je      .jc3248_spi2
    cmp     byte [opt_jc3248_qspi_route], 1
    je      .jc3248_qspi_route
    cmp     byte [opt_jc3248_spi2_init], 1
    je      .jc3248_spi2_init
    cmp     byte [opt_jc3248_lcd_cmd], 1
    je      .jc3248_lcd_cmd
    cmp     byte [opt_jc3248_lcd_unlock], 1
    je      .jc3248_lcd_unlock
    cmp     byte [opt_jc3248_lcd_wake], 1
    je      .jc3248_lcd_wake
    cmp     byte [opt_jc3248_lcd_smoke], 1
    je      .jc3248_lcd_smoke
    cmp     byte [opt_jc3248_lcd_stripes], 1
    je      .jc3248_lcd_stripes
    cmp     byte [opt_jc3248_lcd_status], 1
    je      .jc3248_lcd_status

    mov     edi, [serial_fd]
    mov     rsi, [binary_data]
    mov     edx, [binary_size]
    cmp     byte [opt_flash], 1
    jne     .ram_download
    mov     ecx, [opt_flash_offset]
    call    esp_flash_download
    jmp     .download_done
.ram_download:
    mov     ecx, [opt_entry]
    call    esp_download
.download_done:
    test    eax, eax
    jnz     .dl_err

    lea     rdi, [m_ok]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.sync_ok:
    lea     rdi, [m_sync_ok]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.read_reg:
    mov     edi, [serial_fd]
    mov     esi, [opt_read_reg_addr]
    call    esp_read_reg
    test    edx, edx
    jnz     .read_reg_err
    mov     [read_reg_value], eax
    lea     rdi, [m_read_reg]
    call    print_str
    mov     edi, [opt_read_reg_addr]
    call    print_hex32
    lea     rdi, [m_eq]
    call    print_str
    mov     edi, [read_reg_value]
    call    print_hex32
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.read_reg_err:
    lea     rdi, [m_read_reg_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.write_reg:
    mov     edi, [serial_fd]
    mov     esi, [opt_write_reg_addr]
    mov     edx, [opt_write_reg_value]
    mov     ecx, [opt_write_reg_mask]
    mov     r8d, [opt_write_reg_delay]
    call    esp_write_reg
    test    eax, eax
    jnz     .write_reg_err
    lea     rdi, [m_write_reg]
    call    print_str
    mov     edi, [opt_write_reg_addr]
    call    print_hex32
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.write_reg_err:
    lea     rdi, [m_write_reg_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_backlight:
    mov     edi, [serial_fd]
    movzx   esi, byte [opt_jc3248_bl]
    call    jc3248_backlight
    test    eax, eax
    jnz     .jc3248_backlight_err
    lea     rdi, [m_jc3248_bl]
    call    print_str
    cmp     byte [opt_jc3248_bl], 2
    je      .jc3248_backlight_on_msg
    lea     rdi, [m_off]
    jmp     .jc3248_backlight_msg
.jc3248_backlight_on_msg:
    lea     rdi, [m_on]
.jc3248_backlight_msg:
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_backlight_err:
    lea     rdi, [m_jc3248_bl_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_spi2:
    mov     edi, [serial_fd]
    call    jc3248_spi2_enable
    test    eax, eax
    jnz     .jc3248_spi2_err
    lea     rdi, [m_jc3248_spi2]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_spi2_err:
    lea     rdi, [m_jc3248_spi2_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_qspi_route:
    mov     edi, [serial_fd]
    call    jc3248_qspi_route
    test    eax, eax
    jnz     .jc3248_qspi_route_err
    lea     rdi, [m_jc3248_qspi_route]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_qspi_route_err:
    lea     rdi, [m_jc3248_qspi_route_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_spi2_init:
    mov     edi, [serial_fd]
    call    jc3248_spi2_init
    test    eax, eax
    jnz     .jc3248_spi2_init_err
    lea     rdi, [m_jc3248_spi2_init]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_spi2_init_err:
    lea     rdi, [m_jc3248_spi2_init_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_lcd_cmd:
    mov     edi, [serial_fd]
    mov     esi, [opt_jc3248_lcd_cmd_value]
    call    jc3248_lcd_cmd
    test    eax, eax
    jnz     .jc3248_lcd_cmd_err
    lea     rdi, [m_jc3248_lcd_cmd]
    call    print_str
    mov     edi, [opt_jc3248_lcd_cmd_value]
    call    print_hex32
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_lcd_cmd_err:
    lea     rdi, [m_jc3248_lcd_cmd_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_lcd_unlock:
    mov     edi, [serial_fd]
    call    jc3248_lcd_unlock
    test    eax, eax
    jnz     .jc3248_lcd_unlock_err
    lea     rdi, [m_jc3248_lcd_unlock]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_lcd_unlock_err:
    lea     rdi, [m_jc3248_lcd_unlock_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_lcd_wake:
    mov     edi, [serial_fd]
    call    jc3248_lcd_wake
    test    eax, eax
    jnz     .jc3248_lcd_wake_err
    lea     rdi, [m_jc3248_lcd_wake]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_lcd_wake_err:
    lea     rdi, [m_jc3248_lcd_wake_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_lcd_smoke:
    mov     edi, [serial_fd]
    call    jc3248_lcd_smoke_fill
    test    eax, eax
    jnz     .jc3248_lcd_smoke_err
    lea     rdi, [m_jc3248_lcd_smoke]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_lcd_smoke_err:
    lea     rdi, [m_jc3248_lcd_smoke_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_lcd_stripes:
    mov     edi, [serial_fd]
    call    jc3248_lcd_stripes
    test    eax, eax
    jnz     .jc3248_lcd_stripes_err
    lea     rdi, [m_jc3248_lcd_stripes]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_lcd_stripes_err:
    lea     rdi, [m_jc3248_lcd_stripes_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.jc3248_lcd_status:
    mov     edi, [serial_fd]
    call    jc3248_lcd_status
    test    eax, eax
    jnz     .jc3248_lcd_status_err
    lea     rdi, [m_jc3248_lcd_status]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.jc3248_lcd_status_err:
    lea     rdi, [m_jc3248_lcd_status_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit

.help_exit:
    lea     rdi, [usage_str]
    call    print_str
    xor     edi, edi
    call    sys_exit
.dry_exit:
    lea     rdi, [m_dry]
    call    print_str
    call    print_crlf
    xor     edi, edi
    call    sys_exit
.file_err:
    lea     rdi, [m_file_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.open_err:
    lea     rdi, [m_open_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.cfg_err:
    lea     rdi, [m_cfg_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.rst_err:
    lea     rdi, [m_rst_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.sync_err:
    lea     rdi, [m_sync_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit
.dl_err:
    lea     rdi, [m_dl_err]
    call    print_str
    call    print_crlf
    mov     edi, 1
    call    sys_exit

; ==================================================================
; parse_options(argc, argv)
; rdi=argc, rsi=argv
; ==================================================================
parse_options:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13, rsi
    mov     ebx, 1
    xor     ecx, ecx            ; binary_seen

.loop:
    cmp     ebx, r12d
    jae     .done
    mov     r14, [r13 + rbx * 8]
    inc     ebx
    cmp     byte [r14], '-'
    jne     .maybe_binary

    mov     rdi, r14
    lea     rsi, [str_port]
    call    str_eq
    test    eax, eax
    jz      .ck_baud
    cmp     ebx, r12d
    jae     .bad
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_port], rax
    jmp     .loop

.ck_baud:
    mov     rdi, r14
    lea     rsi, [str_baud]
    call    str_eq
    test    eax, eax
    jz      .ck_entry
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_uint32
    mov     [opt_baud], eax
    jmp     .loop

.ck_entry:
    mov     rdi, r14
    lea     rsi, [str_entry]
    call    str_eq
    test    eax, eax
    jz      .ck_flash_offset
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_entry], eax
    jmp     .loop

.ck_flash_offset:
    mov     rdi, r14
    lea     rsi, [str_flash_offset]
    call    str_eq
    test    eax, eax
    jz      .ck_flash
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_flash_offset], eax
    jmp     .loop

.ck_flash:
    mov     rdi, r14
    lea     rsi, [str_flash]
    call    str_eq
    test    eax, eax
    jz      .ck_no_reset
    mov     byte [opt_flash], 1
    jmp     .loop

.ck_no_reset:
    mov     rdi, r14
    lea     rsi, [str_no_reset]
    call    str_eq
    test    eax, eax
    jz      .ck_sync_only
    mov     byte [opt_no_reset], 1
    jmp     .loop

.ck_sync_only:
    mov     rdi, r14
    lea     rsi, [str_sync_only]
    call    str_eq
    test    eax, eax
    jz      .ck_read_reg
    mov     byte [opt_sync_only], 1
    jmp     .loop

.ck_read_reg:
    mov     rdi, r14
    lea     rsi, [str_read_reg]
    call    str_eq
    test    eax, eax
    jz      .ck_write_reg
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_read_reg_addr], eax
    mov     byte [opt_read_reg], 1
    jmp     .loop

.ck_write_reg:
    mov     rdi, r14
    lea     rsi, [str_write_reg]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_bl_on
    mov     eax, r12d
    sub     eax, ebx
    cmp     eax, 3
    jb      .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_write_reg_addr], eax
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_write_reg_value], eax
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_write_reg_mask], eax
    mov     eax, r12d
    cmp     ebx, eax
    jae     .write_reg_args_done
    mov     rdi, [r13 + rbx * 8]
    cmp     byte [rdi], '-'
    je      .write_reg_args_done
    inc     ebx
    call    parse_uint32
    mov     [opt_write_reg_delay], eax
.write_reg_args_done:
    mov     byte [opt_write_reg], 1
    jmp     .loop

.ck_jc3248_bl_on:
    mov     rdi, r14
    lea     rsi, [str_jc3248_bl_on]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_bl_off
    mov     byte [opt_jc3248_bl], 2
    jmp     .loop

.ck_jc3248_bl_off:
    mov     rdi, r14
    lea     rsi, [str_jc3248_bl_off]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_spi2
    mov     byte [opt_jc3248_bl], 1
    jmp     .loop

.ck_jc3248_spi2:
    mov     rdi, r14
    lea     rsi, [str_jc3248_spi2]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_qspi_route
    mov     byte [opt_jc3248_spi2], 1
    jmp     .loop

.ck_jc3248_qspi_route:
    mov     rdi, r14
    lea     rsi, [str_jc3248_qspi_route]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_spi2_init
    mov     byte [opt_jc3248_qspi_route], 1
    jmp     .loop

.ck_jc3248_spi2_init:
    mov     rdi, r14
    lea     rsi, [str_jc3248_spi2_init]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_lcd_cmd
    mov     byte [opt_jc3248_spi2_init], 1
    jmp     .loop

.ck_jc3248_lcd_cmd:
    mov     rdi, r14
    lea     rsi, [str_jc3248_lcd_cmd]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_lcd_unlock
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    and     eax, 0xff
    mov     [opt_jc3248_lcd_cmd_value], eax
    mov     byte [opt_jc3248_lcd_cmd], 1
    jmp     .loop

.ck_jc3248_lcd_unlock:
    mov     rdi, r14
    lea     rsi, [str_jc3248_lcd_unlock]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_lcd_wake
    mov     byte [opt_jc3248_lcd_unlock], 1
    jmp     .loop

.ck_jc3248_lcd_wake:
    mov     rdi, r14
    lea     rsi, [str_jc3248_lcd_wake]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_lcd_smoke
    mov     byte [opt_jc3248_lcd_wake], 1
    jmp     .loop

.ck_jc3248_lcd_smoke:
    mov     rdi, r14
    lea     rsi, [str_jc3248_lcd_smoke]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_lcd_stripes
    mov     byte [opt_jc3248_lcd_smoke], 1
    jmp     .loop

.ck_jc3248_lcd_stripes:
    mov     rdi, r14
    lea     rsi, [str_jc3248_lcd_stripes]
    call    str_eq
    test    eax, eax
    jz      .ck_jc3248_lcd_status
    mov     byte [opt_jc3248_lcd_stripes], 1
    jmp     .loop

.ck_jc3248_lcd_status:
    mov     rdi, r14
    lea     rsi, [str_jc3248_lcd_status]
    call    str_eq
    test    eax, eax
    jz      .ck_target
    mov     byte [opt_jc3248_lcd_status], 1
    jmp     .loop

.ck_target:
    mov     rdi, r14
    lea     rsi, [str_target]
    call    str_eq
    test    eax, eax
    jz      .ck_help
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    lea     rsi, [str_jc3248w535]
    call    str_eq
    test    eax, eax
    jz      .bad
    mov     dword [opt_entry], ESP32S3_IRAM_ENTRY
    mov     dword [opt_flash_offset], ESP_DEFAULT_FLASH_OFF
    jmp     .loop

.ck_help:
    mov     rdi, r14
    lea     rsi, [str_help]
    call    str_eq
    test    eax, eax
    jz      .ck_dry
    mov     byte [opt_help], 1
    jmp     .loop

.ck_dry:
    mov     rdi, r14
    lea     rsi, [str_dry]
    call    str_eq
    test    eax, eax
    jz      .bad
    mov     byte [opt_dry_run], 1
    jmp     .loop

.maybe_binary:
    test    ecx, ecx
    jnz     .maybe_entry
    mov     [opt_binary], r14
    mov     ecx, 1
    jmp     .loop

.maybe_entry:
    mov     rdi, r14
    call    parse_hex32
    mov     [opt_entry], eax
    jmp     .loop

.bad:
    lea     rdi, [m_bad_arg]
    call    print_str
    call    print_crlf
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
; serial_open(path) -> fd or -1
; ==================================================================
serial_open:
    mov     esi, O_RDWR | O_NOCTTY | O_NDELAY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    ret

; ==================================================================
; serial_configure(fd, baud_index_or_rate)
; ==================================================================
serial_configure:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     r12d, edi
    mov     ebx, esi

    ; Convert baud rate to termios2 index
    mov     edi, ebx
    call    baud_to_index
    mov     ebx, eax

    ; TCGETS2
    mov     edi, r12d
    mov     esi, TCGETS2
    lea     rdx, [termios_buf]
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    ; Raw mode: clear iflag, oflag, lflag
    xor     eax, eax
    mov     [termios_buf + TERMIO2_IFLAG], eax
    mov     [termios_buf + TERMIO2_OFLAG], eax
    mov     [termios_buf + TERMIO2_LFLAG], eax

    ; cflag = CS8 | CREAD | CLOCAL | HUPCL
    mov     dword [termios_buf + TERMIO2_CFLAG], CS8 | CREAD | CLOCAL | HUPCL

    ; VTIME bounds probe reads so SYNC attempts fail cleanly.
    mov     byte [termios_buf + TERMIO2_CC + VMIN], 0
    mov     byte [termios_buf + TERMIO2_CC + VTIME], 1

    ; Set speeds
    mov     [termios_buf + TERMIO2_ISPEED], ebx
    mov     [termios_buf + TERMIO2_OSPEED], ebx

    ; TCSETS2
    mov     edi, r12d
    mov     esi, TCSETS2
    lea     rdx, [termios_buf]
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    xor     eax, eax
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; baud_to_index(rate) -> termios2 index
; ==================================================================
baud_to_index:
    mov     eax, B115200
    cmp     edi, 115200
    je      .done
    mov     eax, B9600
    cmp     edi, 9600
    je      .done
    mov     eax, B19200
    cmp     edi, 19200
    je      .done
    mov     eax, B38400
    cmp     edi, 38400
    je      .done
    mov     eax, B57600
    cmp     edi, 57600
    je      .done
    mov     eax, B230400
    cmp     edi, 230400
    je      .done
    mov     eax, B460800
    cmp     edi, 460800
    je      .done
    mov     eax, B921600
    cmp     edi, 921600
    je      .done
    mov     eax, B115200
.done:
    ret

; ==================================================================
; esp_reset(fd) -> 0 ok, -1 fail
; Pulse DTR=EN, RTS=GPIO0 for download mode entry.
; ==================================================================
esp_reset:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    ; Get current modem bits
    lea     rdx, [rtsdtr_val]
    mov     edi, r12d
    mov     esi, TIOCMGET
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    ; Both low (DTR=0, RTS=0) → EN low, GPIO0 low
    mov     eax, [rtsdtr_val]
    or      eax, TIOCM_RTS | TIOCM_DTR
    mov     [rtsdtr_val], eax
    mov     edi, r12d
    mov     esi, TIOCMSET
    lea     rdx, [rtsdtr_val]
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    mov     edi, 100
    call    sleep_ms

    ; RTS high (GPIO0 low kept), DTR low (EN low)
    mov     eax, [rtsdtr_val]
    and     eax, ~TIOCM_RTS
    or      eax, TIOCM_DTR
    mov     [rtsdtr_val], eax
    mov     edi, r12d
    mov     esi, TIOCMSET
    lea     rdx, [rtsdtr_val]
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    mov     edi, 100
    call    sleep_ms

    ; RTS low (GPIO0 low), DTR high (EN high → CPU starts, stays in download)
    mov     eax, [rtsdtr_val]
    and     eax, ~(TIOCM_RTS | TIOCM_DTR)
    mov     [rtsdtr_val], eax
    mov     edi, r12d
    mov     esi, TIOCMSET
    lea     rdx, [rtsdtr_val]
    mov     eax, SYS_ioctl
    syscall
    test    eax, eax
    js      .fail

    mov     edi, 100
    call    sleep_ms

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, -1
    pop     r12
    pop     rbp
    ret

; ==================================================================
; esp_sync(fd) -> 0 ok, 1 timeout, 2 io error
;
; Send SLIP-encoded SYNC (CMD 0x08) frames up to SYNC_RETRIES times.
; SYNC data = 4 magic bytes + 32 bytes of 0x55.
; ==================================================================
esp_sync:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    xor     r13d, r13d          ; retry counter
    lea     r14, [pkt_buf]      ; raw packet buffer
    lea     r15, [recv_buf]     ; recv buffer

    ; Build SYNC data buffer (4 magic + 32 x 0x55)
    mov     byte [r14 + 0], SYNC_MAGIC_BYTE1
    mov     byte [r14 + 1], SYNC_MAGIC_BYTE2
    mov     byte [r14 + 2], SYNC_MAGIC_BYTE3
    mov     byte [r14 + 3], SYNC_MAGIC_BYTE4
    xor     ecx, ecx
.fill:
    mov     byte [r14 + SYNC_HEADER_BYTES + rcx], SYNC_FILL_BYTE
    inc     ecx
    cmp     ecx, SYNC_PATTERN_BYTES
    jb      .fill

.sync_loop:
    cmp     r13d, SYNC_RETRIES
    jae     .fail_timeout

    ; Build raw packet header at recv_buf
    mov     byte [r15 + PKT_DIRECTION], DIR_REQUEST
    mov     byte [r15 + PKT_COMMAND], CMD_SYNC
    mov     word [r15 + PKT_SIZE], SYNC_TOTAL_BYTES
    xor     eax, eax
    mov     [r15 + PKT_CHECKSUM], eax

    ; Copy SYNC data into packet
    lea     rsi, [r14]
    lea     rdi, [r15 + PKT_DATA]
    mov     ecx, SYNC_TOTAL_BYTES
    rep movsb

    ; SLIP encode raw packet → slip_buf
    mov     rdi, r15
    mov     esi, PKT_HEADER_BYTES + SYNC_TOTAL_BYTES
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax            ; encoded length

    ; Send
    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    mov     edi, ESP_SYNC_TIMEOUT_MS
    call    sleep_ms

    ; Read response
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 512
    call    serial_read_slip
    test    eax, eax
    jle     .retry

    ; SLIP decode
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .retry

    ; Validate response header
    cmp     byte [recv_buf + PKT_DIRECTION], DIR_RESPONSE
    jne     .retry
    cmp     byte [recv_buf + PKT_COMMAND], CMD_SYNC
    jne     .retry

    ; Check status at end
    movzx   eax, word [recv_buf + PKT_SIZE]
    add     eax, PKT_HEADER_BYTES
    cmp     byte [recv_buf + eax - 2], STATUS_SUCCESS
    je      .ok

.retry:
    inc     r13d
    jmp     .sync_loop

.ok:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail_timeout:
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail_io:
    mov     eax, 2
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; esp_download(fd, data, data_size, entry_point) -> 0 ok
;
; MEM_BEGIN → MEM_DATA × N → MEM_END sequence.
; Uses recv_buf for packet construction, slip_buf for SLIP output.
; ==================================================================
esp_download:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; fd
    mov     r13, rsi            ; data ptr
    mov     r14d, edx           ; data size
    mov     r15d, ecx           ; entry point

    ; Calculate num_packets = ceil(data_size / ESP_MEM_PACKET_SIZE)
    mov     eax, r14d
    xor     edx, edx
    mov     ecx, ESP_MEM_PACKET_SIZE
    div     ecx
    mov     ebx, eax            ; num_packets
    test    edx, edx
    jz      .pk_ok
    inc     ebx
.pk_ok:
    mov     [download_packets], ebx

    ; ─── MEM_BEGIN ────────────────────────────────────────────────
    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_MEM_BEGIN
    mov     word [rdi + PKT_SIZE], MEM_BEGIN_DATA_BYTES
    xor     eax, eax
    mov     [rdi + PKT_CHECKSUM], eax

    ; Build MEM_BEGIN payload
    lea     rdi, [rdi + PKT_DATA]
    mov     esi, r14d           ; total_size
    mov     edx, [download_packets]
    mov     ecx, ESP_MEM_PACKET_SIZE
    mov     r8d, r15d           ; mem_offset
    build_mem_begin

    ; SLIP encode
    lea     rdi, [recv_buf]
    mov     esi, PKT_HEADER_BYTES + MEM_BEGIN_DATA_BYTES
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    mov     edi, ESP_RESPONSE_TIMEOUT_MS
    call    sleep_ms

    ; Read MEM_BEGIN response
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    call    serial_read_slip
    test    eax, eax
    jle     .fail_resp

    ; SLIP decode
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .fail_resp

    call    check_response
    test    eax, eax
    jnz     .fail_resp

    ; ─── MEM_DATA packets ─────────────────────────────────────────
    xor     r9d, r9d            ; sequence number
    xor     r10d, r10d          ; byte offset into source data

.data_loop:
    cmp     r9d, [download_packets]
    jae     .data_done

    ; chunk_size = min(remaining, ESP_MEM_PACKET_SIZE)
    mov     eax, r14d
    sub     eax, r10d
    cmp     eax, ESP_MEM_PACKET_SIZE
    jbe     .chunk_ok
    mov     eax, ESP_MEM_PACKET_SIZE
.chunk_ok:
    mov     r11d, eax           ; chunk_size

    ; Build raw MEM_DATA packet at recv_buf
    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_MEM_DATA
    mov     eax, r11d
    add     eax, MEM_DATA_HEADER_BYTES
    mov     word [rdi + PKT_SIZE], ax

    ; Compute XOR checksum of source chunk
    push    rdi
    mov     rdi, r13
    add     rdi, r10
    mov     esi, r11d
    checksum_compute
    pop     rdi

    ; Store checksum
    mov     [rdi + PKT_CHECKSUM], al

    ; Build MEM_DATA payload: data_size, seq_num, reserved(8), data
    lea     rdi, [rdi + PKT_DATA]
    mov     [rdi + MEM_DATA_SIZE], r11d
    mov     [rdi + MEM_DATA_SEQUENCE], r9d
    mov     dword [rdi + 8], 0
    mov     dword [rdi + 12], 0

    ; Copy data chunk
    lea     rdi, [rdi + MEM_DATA_HEADER_BYTES]
    lea     rsi, [r13 + r10]
    mov     ecx, r11d
    rep movsb

    ; SLIP encode
    lea     rdi, [recv_buf]
    mov     eax, r11d
    add     eax, MEM_DATA_HEADER_BYTES
    add     eax, PKT_HEADER_BYTES
    mov     esi, eax
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    ; Send
    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    ; Read response (short wait between packets)
    mov     edi, 50
    call    sleep_ms

    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    call    serial_read_slip
    test    eax, eax
    jle     .fail_resp

    ; Decode and check
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .fail_resp

    call    check_response
    test    eax, eax
    jnz     .fail_resp

    inc     r9d
    add     r10d, r11d
    jmp     .data_loop

.data_done:
    ; ─── MEM_END ──────────────────────────────────────────────────
    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_MEM_END
    mov     word [rdi + PKT_SIZE], MEM_END_DATA_BYTES
    xor     eax, eax
    mov     [rdi + PKT_CHECKSUM], eax

    ; Build MEM_END payload
    lea     rdi, [rdi + PKT_DATA]
    mov     esi, 1              ; execute_flag = 1
    mov     edx, r15d           ; entry_point
    build_mem_end

    ; SLIP encode
    lea     rdi, [recv_buf]
    mov     esi, PKT_HEADER_BYTES + MEM_END_DATA_BYTES
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, [serial_fd]
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail_io:
    mov     eax, 2
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail_resp:
    mov     eax, 3
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; esp_flash_download(fd, data, data_size, flash_offset) -> 0 ok
;
; FLASH_BEGIN -> FLASH_DATA x N -> FLASH_END sequence.
; ==================================================================
esp_flash_download:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; fd
    mov     r13, rsi            ; data ptr
    mov     r14d, edx           ; data size
    mov     r15d, ecx           ; flash offset

    mov     eax, r14d
    xor     edx, edx
    mov     ecx, ESP_FLASH_PACKET_SIZE
    div     ecx
    mov     ebx, eax
    test    edx, edx
    jz      .pk_ok
    inc     ebx
.pk_ok:
    mov     [download_packets], ebx

    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_FLASH_BEGIN
    mov     word [rdi + PKT_SIZE], FLASH_BEGIN_DATA_BYTES
    xor     eax, eax
    mov     [rdi + PKT_CHECKSUM], eax
    lea     rdi, [rdi + PKT_DATA]
    mov     [rdi + FLASH_BEGIN_TOTAL_SIZE], r14d
    mov     eax, [download_packets]
    mov     [rdi + FLASH_BEGIN_NUM_PACKETS], eax
    mov     dword [rdi + FLASH_BEGIN_PACKET_SIZE], ESP_FLASH_PACKET_SIZE
    mov     [rdi + FLASH_BEGIN_OFFSET], r15d

    lea     rdi, [recv_buf]
    mov     esi, PKT_HEADER_BYTES + FLASH_BEGIN_DATA_BYTES
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    mov     edi, ESP_RESPONSE_TIMEOUT_MS
    call    sleep_ms
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    call    serial_read_slip
    test    eax, eax
    jle     .fail_resp
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .fail_resp
    call    check_response
    test    eax, eax
    jnz     .fail_resp

    xor     r9d, r9d            ; sequence number
    xor     r10d, r10d          ; byte offset

.data_loop:
    cmp     r9d, [download_packets]
    jae     .data_done
    mov     eax, r14d
    sub     eax, r10d
    cmp     eax, ESP_FLASH_PACKET_SIZE
    jbe     .chunk_ok
    mov     eax, ESP_FLASH_PACKET_SIZE
.chunk_ok:
    mov     r11d, eax

    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_FLASH_DATA
    mov     eax, r11d
    add     eax, FLASH_DATA_HEADER_BYTES
    mov     word [rdi + PKT_SIZE], ax

    push    rdi
    mov     rdi, r13
    add     rdi, r10
    mov     esi, r11d
    checksum_compute
    pop     rdi
    mov     [rdi + PKT_CHECKSUM], al

    lea     rdi, [rdi + PKT_DATA]
    mov     [rdi + FLASH_DATA_SIZE], r11d
    mov     [rdi + FLASH_DATA_SEQUENCE], r9d
    mov     dword [rdi + 8], 0
    mov     dword [rdi + 12], 0
    lea     rdi, [rdi + FLASH_DATA_HEADER_BYTES]
    lea     rsi, [r13 + r10]
    mov     ecx, r11d
    rep movsb

    lea     rdi, [recv_buf]
    mov     eax, r11d
    add     eax, FLASH_DATA_HEADER_BYTES
    add     eax, PKT_HEADER_BYTES
    mov     esi, eax
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    mov     edi, 50
    call    sleep_ms
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    call    serial_read_slip
    test    eax, eax
    jle     .fail_resp
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .fail_resp
    call    check_response
    test    eax, eax
    jnz     .fail_resp

    inc     r9d
    add     r10d, r11d
    jmp     .data_loop

.data_done:
    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_FLASH_END
    mov     word [rdi + PKT_SIZE], FLASH_END_DATA_BYTES
    xor     eax, eax
    mov     [rdi + PKT_CHECKSUM], eax
    mov     dword [rdi + PKT_DATA + FLASH_END_REBOOT_FLAG], 0

    lea     rdi, [recv_buf]
    mov     esi, PKT_HEADER_BYTES + FLASH_END_DATA_BYTES
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail_io

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.fail_io:
    mov     eax, 2
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail_resp:
    mov     eax, 3
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; esp_read_reg(fd, addr) -> eax=value, edx=0 ok / nonzero error
; ==================================================================
esp_read_reg:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     r12d, edi
    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_READ_REG
    mov     word [rdi + PKT_SIZE], 4
    xor     eax, eax
    mov     [rdi + PKT_CHECKSUM], eax
    mov     [rdi + PKT_DATA], esi

    lea     rdi, [recv_buf]
    mov     esi, PKT_HEADER_BYTES + 4
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail

.read_loop_start:
    mov     ebx, 16
.read_loop:
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    call    serial_read_slip
    test    eax, eax
    jle     .read_wait
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .read_next
    cmp     byte [recv_buf + PKT_DIRECTION], DIR_RESPONSE
    jne     .read_next
    cmp     byte [recv_buf + PKT_COMMAND], CMD_READ_REG
    jne     .read_next
    call    check_response
    test    eax, eax
    jnz     .fail
    mov     eax, [recv_buf + PKT_CHECKSUM]
    xor     edx, edx
    pop     r12
    pop     rbx
    pop     rbp
    ret
.read_wait:
    mov     edi, 5
    call    sleep_ms
.read_next:
    dec     ebx
    jnz     .read_loop
.fail:
    xor     eax, eax
    mov     edx, 1
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; esp_write_reg(fd, addr, value, mask, delay_us) -> eax=0 ok
; ==================================================================
esp_write_reg:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     r12d, edi
    lea     rdi, [recv_buf]
    mov     byte [rdi + PKT_DIRECTION], DIR_REQUEST
    mov     byte [rdi + PKT_COMMAND], CMD_WRITE_REG
    mov     word [rdi + PKT_SIZE], 16
    xor     eax, eax
    mov     [rdi + PKT_CHECKSUM], eax
    mov     [rdi + PKT_DATA + 0], esi
    mov     [rdi + PKT_DATA + 4], edx
    mov     [rdi + PKT_DATA + 8], ecx
    mov     [rdi + PKT_DATA + 12], r8d

    lea     rdi, [recv_buf]
    mov     esi, PKT_HEADER_BYTES + 16
    lea     rdx, [slip_buf]
    slip_encode
    mov     ebx, eax

    mov     edi, r12d
    lea     rsi, [slip_buf]
    mov     edx, ebx
    call    serial_write_all
    test    eax, eax
    js      .fail

    mov     ebx, 16
.read_loop:
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    call    serial_read_slip
    test    eax, eax
    jle     .read_wait
    mov     rdi, rsi
    mov     esi, eax
    slip_decode
    jc      .read_next
    cmp     byte [recv_buf + PKT_DIRECTION], DIR_RESPONSE
    jne     .read_next
    cmp     byte [recv_buf + PKT_COMMAND], CMD_WRITE_REG
    jne     .read_next
    call    check_response
    test    eax, eax
    jnz     .fail
    xor     eax, eax
    pop     r12
    pop     rbx
    pop     rbp
    ret
.read_wait:
    mov     edi, 5
    call    sleep_ms
.read_next:
    dec     ebx
    jnz     .read_loop
.fail:
    mov     eax, 1
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; jc3248_backlight(fd, mode) -> eax=0 ok
; esi: 1 off, 2 on.
; ==================================================================
jc3248_backlight:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12

    mov     r12d, edi
    mov     ebx, esi

    mov     edi, r12d
    mov     esi, ESP32S3_GPIO_ENABLE_W1TS
    mov     edx, 1 << JC3248_PIN_BL
    mov     ecx, 1 << JC3248_PIN_BL
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    cmp     ebx, 2
    je      .on
    mov     esi, ESP32S3_GPIO_OUT_W1TC
    jmp     .write_level
.on:
    mov     esi, ESP32S3_GPIO_OUT_W1TS
.write_level:
    mov     edx, 1 << JC3248_PIN_BL
    mov     ecx, 1 << JC3248_PIN_BL
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail
    xor     eax, eax
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; jc3248_spi2_enable(fd) -> eax=0 ok
; Enables SPI2 peripheral clock and releases reset through SYSTEM MMIO.
; ==================================================================
jc3248_spi2_enable:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    mov     esi, ESP32S3_SYSTEM_CLK_EN0
    call    esp_read_reg
    test    edx, edx
    jnz     .fail
    or      eax, ESP32S3_SYSTEM_SPI2_CLK_EN
    mov     edi, r12d
    mov     esi, ESP32S3_SYSTEM_CLK_EN0
    mov     edx, eax
    mov     ecx, ESP32S3_SYSTEM_SPI2_CLK_EN
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SYSTEM_RST_EN0
    call    esp_read_reg
    test    edx, edx
    jnz     .fail
    or      eax, ESP32S3_SYSTEM_SPI2_RST
    mov     edi, r12d
    mov     esi, ESP32S3_SYSTEM_RST_EN0
    mov     edx, eax
    mov     ecx, ESP32S3_SYSTEM_SPI2_RST
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SYSTEM_RST_EN0
    call    esp_read_reg
    test    edx, edx
    jnz     .fail
    and     eax, ~ESP32S3_SYSTEM_SPI2_RST
    mov     edi, r12d
    mov     esi, ESP32S3_SYSTEM_RST_EN0
    mov     edx, eax
    mov     ecx, ESP32S3_SYSTEM_SPI2_RST
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CLK_GATE
    mov     edx, ESP32S3_SPI_CLK_EN | ESP32S3_SPI_MST_CLK_ACTIVE | ESP32S3_SPI_MST_CLK_SEL
    mov     ecx, ESP32S3_SPI_CLK_EN | ESP32S3_SPI_MST_CLK_ACTIVE | ESP32S3_SPI_MST_CLK_SEL
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; ==================================================================
; jc3248_qspi_route(fd) -> eax=0 ok
; Routes JC3248 AXS15231B QSPI pins through ESP32-S3 GPIO matrix.
; ==================================================================
jc3248_qspi_route:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    mov     esi, JC3248_PIN_LCD_CS
    mov     edx, ESP32S3_IO_MUX_GPIO45
    mov     ecx, ESP32S3_FSPICS0_OUT
    mov     r8d, ESP32S3_FSPICS0_IN
    call    jc3248_route_spi_pin
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, JC3248_PIN_LCD_CLK
    mov     edx, ESP32S3_IO_MUX_GPIO47
    mov     ecx, ESP32S3_FSPICLK_OUT
    mov     r8d, ESP32S3_FSPICLK_IN
    call    jc3248_route_spi_pin
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, JC3248_PIN_LCD_D0
    mov     edx, ESP32S3_IO_MUX_GPIO21
    mov     ecx, ESP32S3_FSPID_OUT
    mov     r8d, ESP32S3_FSPID_IN
    call    jc3248_route_spi_pin
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, JC3248_PIN_LCD_D1
    mov     edx, ESP32S3_IO_MUX_GPIO48
    mov     ecx, ESP32S3_FSPIQ_OUT
    mov     r8d, ESP32S3_FSPIQ_IN
    call    jc3248_route_spi_pin
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, JC3248_PIN_LCD_D2
    mov     edx, ESP32S3_IO_MUX_GPIO40
    mov     ecx, ESP32S3_FSPIWP_OUT
    mov     r8d, ESP32S3_FSPIWP_IN
    call    jc3248_route_spi_pin
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, JC3248_PIN_LCD_D3
    mov     edx, ESP32S3_IO_MUX_GPIO39
    mov     ecx, ESP32S3_FSPIHD_OUT
    mov     r8d, ESP32S3_FSPIHD_IN
    call    jc3248_route_spi_pin
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_route_spi_pin(fd, pin, iomux, out_signal, in_signal) -> eax=0 ok
jc3248_route_spi_pin:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; fd
    mov     r13d, esi           ; pin
    mov     r14d, ecx           ; output signal
    mov     r15d, r8d           ; input signal
    mov     ebx, edx            ; IO_MUX register

    mov     edi, r12d
    mov     esi, ebx
    call    esp_read_reg
    test    edx, edx
    jnz     .fail
    and     eax, ~(ESP32S3_MCU_SEL_MASK | ESP32S3_FUN_DRV_MASK | ESP32S3_FUN_IE)
    or      eax, (ESP32S3_GPIO_FUNC << ESP32S3_MCU_SEL_SHIFT) | (ESP32S3_DRIVE_3 << ESP32S3_FUN_DRV_SHIFT) | ESP32S3_FUN_IE
    mov     edi, r12d
    mov     esi, ebx
    mov     edx, eax
    mov     ecx, ESP32S3_MCU_SEL_MASK | ESP32S3_FUN_DRV_MASK | ESP32S3_FUN_IE
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     eax, r13d
    shl     eax, 2
    add     eax, ESP32S3_GPIO_FUNC_OUT_SEL
    mov     edi, r12d
    mov     esi, eax
    mov     edx, r14d
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     eax, r15d
    shl     eax, 2
    add     eax, ESP32S3_GPIO_FUNC_IN_SEL
    mov     edi, r12d
    mov     esi, eax
    mov     edx, r13d
    or      edx, 0x80
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; jc3248_spi2_init(fd) -> eax=0 ok
; Configures SPI2 master registers after clock enable and QSPI routing.
; ==================================================================
jc3248_spi2_init:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    call    jc3248_spi2_enable
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    call    jc3248_qspi_route
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_SLAVE
    xor     edx, edx
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_DMA_CONF
    xor     edx, edx
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_DMA_INT_CLR
    mov     edx, 0xffffffff
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CLOCK
    mov     edx, ESP32S3_SPI_CLOCK_INIT
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CTRL
    xor     edx, edx
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MISC
    mov     edx, ESP32S3_SPI_MISC_INIT
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_USER1
    xor     edx, edx
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_USER2
    xor     edx, edx
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_USER
    mov     edx, ESP32S3_SPI_USR_MOSI
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    call    jc3248_spi2_apply_config
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_cmd(fd, cmd8) -> eax=0 ok
jc3248_lcd_cmd:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13

    mov     r12d, edi
    mov     r13d, esi

    mov     edi, r12d
    call    jc3248_spi2_init
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI_USR
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_W0
    mov     edx, r13d
    shl     edx, 16
    or      edx, JC3248_LCD_OPCODE_WRITE_CMD
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MS_DLEN
    mov     edx, 31
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MISC
    mov     edx, ESP32S3_SPI_MISC_INIT
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_USER
    mov     edx, ESP32S3_SPI_USR_MOSI
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    call    jc3248_spi2_apply_config
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CMD
    mov     edx, ESP32S3_SPI_USR
    mov     ecx, ESP32S3_SPI_USR
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI_USR
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_cmd_no_init(fd, cmd8) -> eax=0 ok
jc3248_lcd_cmd_no_init:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13

    mov     r12d, edi
    mov     r13d, esi

    mov     edi, r12d
    mov     esi, ESP32S3_SPI_USR
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_W0
    mov     edx, r13d
    shl     edx, 16
    or      edx, JC3248_LCD_OPCODE_WRITE_CMD
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MS_DLEN
    mov     edx, 31
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MISC
    mov     edx, ESP32S3_SPI_MISC_INIT
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_USER
    mov     edx, ESP32S3_SPI_USR_MOSI
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    call    jc3248_spi2_apply_config
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CMD
    mov     edx, ESP32S3_SPI_USR
    mov     ecx, ESP32S3_SPI_USR
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI_USR
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_unlock(fd) -> eax=0 ok
jc3248_lcd_unlock:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi
    mov     byte [lcd_cmd_word + 0], JC3248_LCD_OPCODE_WRITE_CMD
    mov     byte [lcd_cmd_word + 1], 0
    mov     byte [lcd_cmd_word + 2], 0xbb
    mov     byte [lcd_cmd_word + 3], 0

    mov     edi, r12d
    call    jc3248_spi2_init
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    lea     rsi, [lcd_cmd_word]
    mov     edx, 4
    xor     ecx, ecx
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    lea     rsi, [lcd_unlock_data]
    mov     edx, 8
    xor     ecx, ecx
    xor     r8d, r8d
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_wake(fd) -> eax=0 ok
jc3248_lcd_wake:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    call    jc3248_lcd_unlock
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x13
    call    jc3248_lcd_cmd
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x11
    call    jc3248_lcd_cmd
    test    eax, eax
    jnz     .fail

    mov     edi, 120
    call    sleep_ms

    mov     edi, r12d
    mov     esi, 0x29
    call    jc3248_lcd_cmd
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_board_init(fd) -> eax=0 ok
jc3248_lcd_board_init:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    call    jc3248_spi2_init
    test    eax, eax
    jnz     .fail

    mov     edi, 120
    call    sleep_ms

    mov     edi, r12d
    mov     esi, 0x01
    call    jc3248_lcd_cmd_no_init
    test    eax, eax
    jnz     .fail

    mov     edi, 150
    call    sleep_ms

    jc_lcd_cmd_data_checked 0x36, lcd_madctl_data, 1
    jc_lcd_cmd_data_checked 0x3a, lcd_pixfmt_data, 1
    jc_lcd_cmd_data_checked 0xbb, lcd_unlock_data, 8

    jc_lcd_cmd_data_checked 0xa0, lcd_init_a0, 17
    jc_lcd_cmd_data_checked 0xa2, lcd_init_a2, 31
    jc_lcd_cmd_data_checked 0xd0, lcd_init_d0, 30
    jc_lcd_cmd_data_checked 0xa3, lcd_init_a3, 22
    jc_lcd_cmd_data_checked 0xc1, lcd_init_c1, 30
    jc_lcd_cmd_data_checked 0xc3, lcd_init_c3, 11
    jc_lcd_cmd_data_checked 0xc4, lcd_init_c4, 29
    jc_lcd_cmd_data_checked 0xc5, lcd_init_c5, 23
    jc_lcd_cmd_data_checked 0xc6, lcd_init_c6, 20
    jc_lcd_cmd_data_checked 0xc7, lcd_init_c7, 20
    jc_lcd_cmd_data_checked 0xc9, lcd_init_c9, 4
    jc_lcd_cmd_data_checked 0xcf, lcd_init_cf, 27
    jc_lcd_cmd_data_checked 0xd5, lcd_init_d5, 30
    jc_lcd_cmd_data_checked 0xd6, lcd_init_d6, 30
    jc_lcd_cmd_data_checked 0xd7, lcd_init_d7, 19
    jc_lcd_cmd_data_checked 0xd8, lcd_init_d8, 12
    jc_lcd_cmd_data_checked 0xd9, lcd_init_d9, 12
    jc_lcd_cmd_data_checked 0xdd, lcd_init_dd, 12
    jc_lcd_cmd_data_checked 0xdf, lcd_init_df, 8
    jc_lcd_cmd_data_checked 0xe0, lcd_init_e0, 17
    jc_lcd_cmd_data_checked 0xe1, lcd_init_e1, 17
    jc_lcd_cmd_data_checked 0xe2, lcd_init_e2, 17
    jc_lcd_cmd_data_checked 0xe3, lcd_init_e3, 17
    jc_lcd_cmd_data_checked 0xe4, lcd_init_e4, 17
    jc_lcd_cmd_data_checked 0xe5, lcd_init_e5, 17
    jc_lcd_cmd_data_checked 0xa4, lcd_init_a4_0, 16
    jc_lcd_cmd_data_checked 0xa4, lcd_init_a4_1, 4
    jc_lcd_cmd_data_checked 0xbb, lcd_init_bb_lock, 8

    mov     edi, r12d
    mov     esi, 0x13
    call    jc3248_lcd_cmd_no_init
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x11
    call    jc3248_lcd_cmd_no_init
    test    eax, eax
    jnz     .fail

    mov     edi, 120
    call    sleep_ms

    jc_lcd_cmd_data_checked 0x2c, lcd_init_2c_tail, 4

    mov     edi, r12d
    mov     esi, 0x29
    call    jc3248_lcd_cmd_no_init
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_smoke_fill(fd) -> eax=0 ok
; Sends a tiny red RGB565 pixel burst after wake/init-lite commands.
jc3248_lcd_smoke_fill:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    call    jc3248_lcd_board_init
    test    eax, eax
    jnz     .fail

    jc_lcd_cmd_data_checked 0x36, lcd_madctl_data, 1
    jc_lcd_cmd_data_checked 0x3a, lcd_pixfmt_data, 1
    jc_lcd_cmd_data_checked 0x2a, lcd_col_data, 4
    jc_lcd_cmd_data_checked 0x2b, lcd_status_row_data, 4

    mov     byte [lcd_cmd_word + 0], JC3248_LCD_OPCODE_WRITE_COLOR
    mov     byte [lcd_cmd_word + 1], 0
    mov     byte [lcd_cmd_word + 2], 0x2c
    mov     byte [lcd_cmd_word + 3], 0

    mov     edi, r12d
    lea     rsi, [lcd_cmd_word]
    mov     edx, 4
    xor     ecx, ecx
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    lea     rsi, [lcd_red_pixels]
    mov     edx, 64
    mov     ecx, 1
    xor     r8d, r8d
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_stripes(fd) -> eax=0 ok
; Sends three 64-byte RGB565 bursts: red, green, blue.
jc3248_lcd_stripes:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    call    jc3248_lcd_wake
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x36
    lea     rdx, [lcd_madctl_data]
    mov     ecx, 1
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x3a
    lea     rdx, [lcd_pixfmt_data]
    mov     ecx, 1
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x2a
    lea     rdx, [lcd_col_data]
    mov     ecx, 4
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail

    mov     byte [lcd_cmd_word + 0], JC3248_LCD_OPCODE_WRITE_COLOR
    mov     byte [lcd_cmd_word + 1], 0
    mov     byte [lcd_cmd_word + 2], 0x2c
    mov     byte [lcd_cmd_word + 3], 0

    mov     edi, r12d
    lea     rsi, [lcd_cmd_word]
    mov     edx, 4
    xor     ecx, ecx
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    lea     rsi, [lcd_red_pixels]
    mov     edx, 64
    mov     ecx, 1
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    lea     rsi, [lcd_green_pixels]
    mov     edx, 64
    mov     ecx, 1
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    lea     rsi, [lcd_blue_pixels]
    mov     edx, 64
    mov     ecx, 1
    xor     r8d, r8d
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_status(fd) -> eax=0 ok
; Renders a bounded hardware status band: blue/green/cyan/white blocks.
jc3248_lcd_status:
    push    rbp
    mov     rbp, rsp
    push    r12

    mov     r12d, edi

    mov     edi, r12d
    call    jc3248_lcd_wake
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x36
    lea     rdx, [lcd_madctl_data]
    mov     ecx, 1
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x3a
    lea     rdx, [lcd_pixfmt_data]
    mov     ecx, 1
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, 0x2a
    lea     rdx, [lcd_col_data]
    mov     ecx, 4
    call    jc3248_lcd_cmd_data
    test    eax, eax
    jnz     .fail

    mov     byte [lcd_cmd_word + 0], JC3248_LCD_OPCODE_WRITE_COLOR
    mov     byte [lcd_cmd_word + 1], 0
    mov     byte [lcd_cmd_word + 2], 0x2c
    mov     byte [lcd_cmd_word + 3], 0

    mov     edi, r12d
    lea     rsi, [lcd_cmd_word]
    mov     edx, 4
    xor     ecx, ecx
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    jc_lcd_chunk_burst_checked lcd_blue_pixels, 30, 0
    jc_lcd_chunk_burst_checked lcd_green_pixels, 30, 0
    jc_lcd_chunk_burst_checked lcd_cyan_pixels, 30, 0
    jc_lcd_chunk_burst_checked lcd_white_pixels, 30, 1

    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_lcd_send_chunks(fd, buf, count, release_last) -> eax=0 ok
jc3248_lcd_send_chunks:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15d, ecx

.loop:
    test    r14d, r14d
    jz      .ok
    mov     ebx, 1
    cmp     r14d, 1
    jne     .send
    test    r15d, r15d
    jz      .send
    xor     ebx, ebx
.send:
    mov     edi, r12d
    mov     rsi, r13
    mov     edx, 64
    mov     ecx, 1
    mov     r8d, ebx
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail
    dec     r14d
    jmp     .loop
.ok:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; jc3248_lcd_cmd_data(fd, cmd8, data, len) -> eax=0 ok
jc3248_lcd_cmd_data:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx

    mov     byte [lcd_cmd_word + 0], JC3248_LCD_OPCODE_WRITE_CMD
    mov     byte [lcd_cmd_word + 1], 0
    mov     byte [lcd_cmd_word + 2], r13b
    mov     byte [lcd_cmd_word + 3], 0

    mov     edi, r12d
    lea     rsi, [lcd_cmd_word]
    mov     edx, 4
    xor     ecx, ecx
    mov     r8d, 1
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     rsi, r14
    mov     edx, r15d
    xor     ecx, ecx
    xor     r8d, r8d
    call    jc3248_spi2_write_buf
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; jc3248_spi2_write_buf(fd, buf, len, quad, keep_cs) -> eax=0 ok
jc3248_spi2_write_buf:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13, rsi
    mov     r14d, edx
    mov     r15d, ecx
    mov     ebx, r8d

    test    r14d, r14d
    jz      .ok
    cmp     r14d, 64
    ja      .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI_USR
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail

    mov     dword [spi_word_index], 0
.clear_loop:
    mov     eax, [spi_word_index]
    cmp     eax, 16
    jae     .pack_start
    shl     eax, 2
    add     eax, ESP32S3_SPI2_W0
    mov     edi, r12d
    mov     esi, eax
    xor     edx, edx
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail
    inc     dword [spi_word_index]
    jmp     .clear_loop

.pack_start:
    xor     r9d, r9d
.pack_loop:
    cmp     r9d, r14d
    jae     .write_len
    xor     edx, edx
    xor     r10d, r10d
.byte_loop:
    cmp     r10d, 4
    jae     .write_word
    cmp     r9d, r14d
    jae     .write_word
    movzx   eax, byte [r13 + r9]
    mov     ecx, r10d
    shl     ecx, 3
    shl     eax, cl
    or      edx, eax
    inc     r9d
    inc     r10d
    jmp     .byte_loop
.write_word:
    mov     eax, r9d
    dec     eax
    shr     eax, 2
    shl     eax, 2
    add     eax, ESP32S3_SPI2_W0
    push    r9
    mov     edi, r12d
    mov     esi, eax
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    pop     r9
    test    eax, eax
    jnz     .fail
    jmp     .pack_loop

.write_len:
    mov     eax, r14d
    shl     eax, 3
    dec     eax
    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MS_DLEN
    mov     edx, eax
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edx, ESP32S3_SPI_USR_MOSI
    test    r15d, r15d
    jz      .user_ok
    or      edx, ESP32S3_SPI_FWRITE_QUAD
.user_ok:
    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_USER
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edx, ESP32S3_SPI_MISC_INIT
    test    ebx, ebx
    jz      .misc_ok
    or      edx, ESP32S3_SPI_CS_KEEP_ACTIVE
.misc_ok:
    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_MISC
    mov     ecx, 0xffffffff
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    call    jc3248_spi2_apply_config
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CMD
    mov     edx, ESP32S3_SPI_USR
    mov     ecx, ESP32S3_SPI_USR
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail

    mov     edi, r12d
    mov     esi, ESP32S3_SPI_USR
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail

.ok:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; jc3248_spi2_apply_config(fd) -> eax=0 ok
jc3248_spi2_apply_config:
    push    rbp
    mov     rbp, rsp
    push    r12
    mov     r12d, edi
    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CMD
    mov     edx, ESP32S3_SPI_UPDATE
    mov     ecx, ESP32S3_SPI_UPDATE
    xor     r8d, r8d
    call    esp_write_reg
    test    eax, eax
    jnz     .fail
    mov     edi, r12d
    mov     esi, ESP32S3_SPI_UPDATE
    call    jc3248_spi2_wait_clear
    test    eax, eax
    jnz     .fail
    xor     eax, eax
    pop     r12
    pop     rbp
    ret
.fail:
    mov     eax, 1
    pop     r12
    pop     rbp
    ret

; jc3248_spi2_wait_clear(fd, mask) -> eax=0 ok
jc3248_spi2_wait_clear:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    mov     r12d, edi
    mov     r13d, esi
    mov     ebx, 1000
.loop:
    mov     edi, r12d
    mov     esi, ESP32S3_SPI2_CMD
    call    esp_read_reg
    test    edx, edx
    jnz     .fail
    test    eax, r13d
    jz      .ok
    dec     ebx
    jnz     .loop
.fail:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.ok:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; check_response() -> 0 ok, 1 fail
; Checks recv_buf content for valid response.
; ==================================================================
check_response:
    cmp     byte [recv_buf + PKT_DIRECTION], DIR_RESPONSE
    jne     .fail
    movzx   eax, word [recv_buf + PKT_SIZE]
    add     eax, PKT_HEADER_BYTES
    cmp     byte [recv_buf + eax - 2], STATUS_SUCCESS
    jne     .fail
    xor     eax, eax
    ret
.fail:
    mov     eax, 1
    ret

; ==================================================================
; serial_write_all(fd, buf, len) -> 0 ok, -1 fail
; ==================================================================
serial_write_all:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi
    mov     r13, rsi
    mov     ebx, edx

.loop:
    test    ebx, ebx
    jz      .done
    mov     edi, r12d
    mov     rsi, r13
    mov     edx, ebx
    mov     eax, SYS_write
    syscall
    test    eax, eax
    js      .fail
    sub     ebx, eax
    add     r13, rax
    jmp     .loop

.done:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
.fail:
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; serial_read_slip(fd, buf, maxlen) -> bytes read (0 on timeout)
; Reads bytes until trailing SLIP_END (0xC0).
; ==================================================================
serial_read_slip:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi
    mov     r13, rsi
    mov     r15d, edx
    xor     r14d, r14d
    xor     ebx, ebx

.loop:
    cmp     r14d, r15d
    jae     .done

    mov     edi, r12d
    lea     rsi, [r13 + r14]
    mov     edx, 1
    mov     eax, SYS_read
    syscall
    test    eax, eax
    jle     .done

    cmp     byte [r13 + r14], SLIP_END
    jne     .got_payload_byte
    test    ebx, ebx
    jz      .loop
    inc     r14d
    jmp     .done
.got_payload_byte:
    mov     ebx, 1
    inc     r14d
    cmp     byte [r13 + r14 - 1], SLIP_END
    jne     .loop

.done:
    mov     eax, r14d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; serial_drain(fd)
; Drains queued ROM responses after SYNC so later commands do not consume stale
; SYNC frames.
; ==================================================================
serial_drain:
    push    rbp
    mov     rbp, rsp
    push    r12
    mov     r12d, edi
    mov     edi, 100
    call    sleep_ms
.loop:
    mov     edi, r12d
    lea     rsi, [recv_buf]
    mov     edx, 256
    mov     eax, SYS_read
    syscall
    test    eax, eax
    jg      .loop
    pop     r12
    pop     rbp
    ret

; ==================================================================
; sleep_ms(ms)
; ==================================================================
sleep_ms:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16

    mov     eax, edi
    xor     edx, edx
    mov     ecx, 1000
    div     ecx
    mov     qword [rbp - 16], rax
    mov     eax, edx
    mov     ecx, 1000000
    mul     ecx
    mov     qword [rbp - 8], rax

    lea     rdi, [rbp - 16]
    xor     esi, esi
    mov     eax, SYS_nanosleep
    syscall

    add     rsp, 16
    pop     rbp
    ret

; ==================================================================
; str_eq(a, b) -> 1 if equal
; ==================================================================
str_eq:
    push    rbx
.l:
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .ne
    test    al, al
    jz      .eq
    inc     rdi
    inc     rsi
    jmp     .l
.eq:
    mov     eax, 1
    pop     rbx
    ret
.ne:
    xor     eax, eax
    pop     rbx
    ret

; parse_uint32(str) -> value
parse_uint32:
    xor     eax, eax
.l:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done
    sub     cl, '0'
    cmp     cl, 9
    ja      .done
    imul    eax, eax, 10
    add     eax, ecx
    inc     rdi
    jmp     .l
.done:
    ret

; parse_hex32(str) -> value
parse_hex32:
    xor     eax, eax
.l:
    movzx   ecx, byte [rdi]
    test    cl, cl
    jz      .done
    cmp     cl, '0'
    jb      .done
    cmp     cl, '9'
    ja      .let
    sub     ecx, '0'
    jmp     .acc
.let:
    or      cl, 0x20
    sub     ecx, 'a' - 10
.acc:
    shl     eax, 4
    or      eax, ecx
    inc     rdi
    jmp     .l
.done:
    ret

; print_str(str)
print_str:
    push    rdi
    push    rcx
    mov     rcx, rdi
    xor     edx, edx
.len:
    cmp     byte [rcx + rdx], 0
    je      .print
    inc     edx
    jmp     .len
.print:
    mov     rsi, rdi
    mov     edi, 1
    mov     eax, SYS_write
    syscall
    pop     rcx
    pop     rdi
    ret

; print_crlf()
print_crlf:
    mov     edi, 1
    lea     rsi, [crlf_str]
    mov     edx, 1
    mov     eax, SYS_write
    syscall
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
.l:
    xor     edx, edx
    div     ecx
    add     dl, '0'
    dec     rbx
    mov     [rbx], dl
    test    eax, eax
    jnz     .l
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
    push    rbx
    sub     rsp, 16
    mov     byte [rbp - 24], '0'
    mov     byte [rbp - 23], 'x'
    mov     ecx, 8
    lea     rbx, [rbp - 22]
.l:
    mov     eax, edi
    shr     eax, 28
    cmp     al, 9
    ja      .hex
    add     al, '0'
    jmp     .store
.hex:
    add     al, 'a' - 10
.store:
    mov     [rbx], al
    inc     rbx
    shl     edi, 4
    dec     ecx
    jnz     .l
    mov     edi, 1
    lea     rsi, [rbp - 24]
    mov     edx, 10
    mov     eax, SYS_write
    syscall
    add     rsp, 16
    pop     rbx
    pop     rbp
    ret

; read_file(path) → rax=ptr, edx=size, or rax=0
read_file:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13

    xor     esi, esi
    mov     eax, SYS_open
    syscall
    test    eax, eax
    js      .fail

    mov     r12d, eax
    ; lseek to end
    mov     edi, r12d
    xor     esi, esi
    mov     edx, 2
    mov     eax, SYS_lseek
    syscall
    mov     r13d, eax
    test    eax, eax
    js      .close_fail

    ; lseek back to start
    mov     edi, r12d
    xor     esi, esi
    xor     edx, edx
    mov     eax, SYS_lseek
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

; sys_exit(exit_code)
sys_exit:
    mov     eax, SYS_exit_group
    syscall

; ==================================================================
section .data
crlf_str:           db 0x0a

str_port:           db "--port", 0
str_baud:           db "--baud", 0
str_entry:          db "--entry", 0
str_flash_offset:   db "--flash-offset", 0
str_flash:          db "--flash", 0
str_no_reset:       db "--no-reset", 0
str_sync_only:      db "--sync-only", 0
str_read_reg:       db "--read-reg", 0
str_write_reg:      db "--write-reg", 0
str_jc3248_bl_on:   db "--jc3248-bl-on", 0
str_jc3248_bl_off:  db "--jc3248-bl-off", 0
str_jc3248_spi2:    db "--jc3248-spi2-enable", 0
str_jc3248_qspi_route: db "--jc3248-qspi-route", 0
str_jc3248_spi2_init: db "--jc3248-spi2-init", 0
str_jc3248_lcd_cmd: db "--jc3248-lcd-cmd", 0
str_jc3248_lcd_unlock: db "--jc3248-lcd-unlock", 0
str_jc3248_lcd_wake: db "--jc3248-lcd-wake", 0
str_jc3248_lcd_smoke: db "--jc3248-lcd-smoke", 0
str_jc3248_lcd_stripes: db "--jc3248-lcd-stripes", 0
str_jc3248_lcd_status: db "--jc3248-lcd-status", 0
str_target:         db "--target", 0
str_jc3248w535:     db "jc3248w535", 0
str_help:           db "--help", 0
str_dry:            db "--dry-run", 0

m_plan_ram:         db "ESP32-S3 RAM boot: ", 0
m_plan_flash:       db "ESP32-S3 flash @ ", 0
m_plan_sep:         db ": ", 0
m_to:               db " bytes -> ", 0
m_ok:               db "OK", 0
m_dry:              db "Dry run", 0
m_file_err:         db "Cannot read binary file", 0
m_open_err:         db "Cannot open serial port", 0
m_cfg_err:          db "Cannot configure serial port", 0
m_rst_err:          db "Reset failed", 0
m_sync_err:         db "SYNC failed", 0
m_sync_ok:          db "SYNC OK", 0
m_read_reg:         db "READ_REG ", 0
m_eq:               db " = ", 0
m_read_reg_err:     db "READ_REG failed", 0
m_write_reg:        db "WRITE_REG ", 0
m_write_reg_err:    db "WRITE_REG failed", 0
m_jc3248_bl:        db "JC3248 backlight ", 0
m_jc3248_bl_err:    db "JC3248 backlight failed", 0
m_jc3248_spi2:      db "JC3248 SPI2 enabled", 0
m_jc3248_spi2_err:  db "JC3248 SPI2 enable failed", 0
m_jc3248_qspi_route: db "JC3248 QSPI routed", 0
m_jc3248_qspi_route_err: db "JC3248 QSPI route failed", 0
m_jc3248_spi2_init: db "JC3248 SPI2 initialized", 0
m_jc3248_spi2_init_err: db "JC3248 SPI2 init failed", 0
m_jc3248_lcd_cmd:  db "JC3248 LCD cmd ", 0
m_jc3248_lcd_cmd_err: db "JC3248 LCD cmd failed", 0
m_jc3248_lcd_unlock: db "JC3248 LCD unlock sent", 0
m_jc3248_lcd_unlock_err: db "JC3248 LCD unlock failed", 0
m_jc3248_lcd_wake: db "JC3248 LCD wake sent", 0
m_jc3248_lcd_wake_err: db "JC3248 LCD wake failed", 0
m_jc3248_lcd_smoke: db "JC3248 LCD smoke fill sent", 0
m_jc3248_lcd_smoke_err: db "JC3248 LCD smoke fill failed", 0
m_jc3248_lcd_stripes: db "JC3248 LCD stripes sent", 0
m_jc3248_lcd_stripes_err: db "JC3248 LCD stripes failed", 0
m_jc3248_lcd_status: db "JC3248 LCD status rendered", 0
m_jc3248_lcd_status_err: db "JC3248 LCD status failed", 0
m_on:               db "on", 0
m_off:              db "off", 0
m_dl_err:           db "Download failed", 0
m_bad_arg:          db "Bad argument. Use --help for usage.", 0

usage_str:          db "Usage: esp32_serial_boot_host [options] <binary> [entry_point]", 0x0a
                    db "Options:", 0x0a
                    db "  --target jc3248w535  Select ESP32-S3 display/controller defaults", 0x0a
                    db "  --flash              Write binary to SPI flash instead of RAM", 0x0a
                    db "  --flash-offset <hex> Flash offset (default: 0x00010000)", 0x0a
                    db "  --no-reset           Do not toggle reset lines before SYNC", 0x0a
                    db "  --sync-only          Probe ROM SYNC and exit without writing", 0x0a
                    db "  --read-reg <hex>     Read one ESP32 ROM-loader MMIO register", 0x0a
                    db "  --write-reg <addr> <value> <mask> [delay-us]", 0x0a
                    db "  --jc3248-bl-on      Configure GPIO1 and turn backlight on", 0x0a
                    db "  --jc3248-bl-off     Configure GPIO1 and turn backlight off", 0x0a
                    db "  --jc3248-spi2-enable Enable SPI2 peripheral clock/reset", 0x0a
                    db "  --jc3248-qspi-route Route LCD QSPI pins through GPIO matrix", 0x0a
                    db "  --jc3248-spi2-init  Configure SPI2 master registers", 0x0a
                    db "  --jc3248-lcd-cmd <hex> Send one AXS15231B command byte", 0x0a
                    db "  --jc3248-lcd-unlock Send AXS15231B 0xBB unlock prefix", 0x0a
                    db "  --jc3248-lcd-wake  Send unlock, normal, sleep-out, display-on", 0x0a
                    db "  --jc3248-lcd-smoke Send 64 bytes of red RGB565 pixels", 0x0a
                    db "  --jc3248-lcd-stripes Send red/green/blue RGB565 bursts", 0x0a
                    db "  --jc3248-lcd-status Render bounded hardware status band", 0x0a
                    db "  --port <device>      Serial port (default: /dev/ttyUSB0)", 0x0a
                    db "  --baud <rate>        Baud rate (default: 115200)", 0x0a
                    db "  --entry <hex>        RAM load/entry address (default: 0x40374000)", 0x0a
                    db "  --dry-run            Scan port but don't write", 0x0a
                    db "  --help               Show this help", 0x0a
                    db 0

lcd_cmd_word:        db 0, 0, 0, 0
lcd_unlock_data:     db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5a, 0xa5
lcd_init_a0:         db 0xc0,0x10,0x00,0x02,0x00,0x00,0x04,0x3f,0x20,0x05,0x3f,0x3f,0x00,0x00,0x00,0x00,0x00
lcd_init_a2:         db 0x30,0x3c,0x24,0x14,0xd0,0x20,0xff,0xe0,0x40,0x19,0x80,0x80,0x80,0x20,0xf9,0x10,0x02,0xff,0xff,0xf0,0x90,0x01,0x32,0xa0,0x91,0xe0,0x20,0x7f,0xff,0x00,0x5a
lcd_init_d0:         db 0xe0,0x40,0x51,0x24,0x08,0x05,0x10,0x01,0x20,0x15,0x42,0xc2,0x22,0x22,0xaa,0x03,0x10,0x12,0x60,0x14,0x1e,0x51,0x15,0x00,0x8a,0x20,0x00,0x03,0x3a,0x12
lcd_init_a3:         db 0xa0,0x06,0xaa,0x00,0x08,0x02,0x0a,0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x04,0x00,0x55,0x55
lcd_init_c1:         db 0x31,0x04,0x02,0x02,0x71,0x05,0x24,0x55,0x02,0x00,0x41,0x00,0x53,0xff,0xff,0xff,0x4f,0x52,0x00,0x4f,0x52,0x00,0x45,0x3b,0x0b,0x02,0x0d,0x00,0xff,0x40
lcd_init_c3:         db 0x00,0x00,0x00,0x50,0x03,0x00,0x00,0x00,0x01,0x80,0x01
lcd_init_c4:         db 0x00,0x24,0x33,0x80,0x00,0xea,0x64,0x32,0xc8,0x64,0xc8,0x32,0x90,0x90,0x11,0x06,0xdc,0xfa,0x00,0x00,0x80,0xfe,0x10,0x10,0x00,0x0a,0x0a,0x44,0x50
lcd_init_c5:         db 0x18,0x00,0x00,0x03,0xfe,0x3a,0x4a,0x20,0x30,0x10,0x88,0xde,0x0d,0x08,0x0f,0x0f,0x01,0x3a,0x4a,0x20,0x10,0x10,0x00
lcd_init_c6:         db 0x05,0x0a,0x05,0x0a,0x00,0xe0,0x2e,0x0b,0x12,0x22,0x12,0x22,0x01,0x03,0x00,0x3f,0x6a,0x18,0xc8,0x22
lcd_init_c7:         db 0x50,0x32,0x28,0x00,0xa2,0x80,0x8f,0x00,0x80,0xff,0x07,0x11,0x9c,0x67,0xff,0x24,0x0c,0x0d,0x0e,0x0f
lcd_init_c9:         db 0x33,0x44,0x44,0x01
lcd_init_cf:         db 0x2c,0x1e,0x88,0x58,0x13,0x18,0x56,0x18,0x1e,0x68,0x88,0x00,0x65,0x09,0x22,0xc4,0x0c,0x77,0x22,0x44,0xaa,0x55,0x08,0x08,0x12,0xa0,0x08
lcd_init_d5:         db 0x40,0x8e,0x8d,0x01,0x35,0x04,0x92,0x74,0x04,0x92,0x74,0x04,0x08,0x6a,0x04,0x46,0x03,0x03,0x03,0x03,0x82,0x01,0x03,0x00,0xe0,0x51,0xa1,0x00,0x00,0x00
lcd_init_d6:         db 0x10,0x32,0x54,0x76,0x98,0xba,0xdc,0xfe,0x93,0x00,0x01,0x83,0x07,0x07,0x00,0x07,0x07,0x00,0x03,0x03,0x03,0x03,0x03,0x03,0x00,0x84,0x00,0x20,0x01,0x00
lcd_init_d7:         db 0x03,0x01,0x0b,0x09,0x0f,0x0d,0x1e,0x1f,0x18,0x1d,0x1f,0x19,0x40,0x8e,0x04,0x00,0x20,0xa0,0x1f
lcd_init_d8:         db 0x02,0x00,0x0a,0x08,0x0e,0x0c,0x1e,0x1f,0x18,0x1d,0x1f,0x19
lcd_init_d9:         times 12 db 0x1f
lcd_init_dd:         times 12 db 0x1f
lcd_init_df:         db 0x44,0x73,0x4b,0x69,0x00,0x0a,0x02,0x90
lcd_init_e0:         db 0x3b,0x28,0x10,0x16,0x0c,0x06,0x11,0x28,0x5c,0x21,0x0d,0x35,0x13,0x2c,0x33,0x28,0x0d
lcd_init_e1:         db 0x37,0x28,0x10,0x16,0x0b,0x06,0x11,0x28,0x5c,0x21,0x0d,0x35,0x14,0x2c,0x33,0x28,0x0f
lcd_init_e2:         db 0x3b,0x07,0x12,0x18,0x0e,0x0d,0x17,0x35,0x44,0x32,0x0c,0x14,0x14,0x36,0x3a,0x2f,0x0d
lcd_init_e3:         db 0x37,0x07,0x12,0x18,0x0e,0x0d,0x17,0x35,0x44,0x32,0x0c,0x14,0x14,0x36,0x32,0x2f,0x0f
lcd_init_e4:         db 0x3b,0x07,0x12,0x18,0x0e,0x0d,0x17,0x39,0x44,0x2e,0x0c,0x14,0x14,0x36,0x3a,0x2f,0x0d
lcd_init_e5:         db 0x37,0x07,0x12,0x18,0x0e,0x0d,0x17,0x39,0x44,0x2e,0x0c,0x14,0x14,0x36,0x3a,0x2f,0x0f
lcd_init_a4_0:       db 0x85,0x85,0x95,0x82,0xaf,0xaa,0xaa,0x80,0x10,0x30,0x40,0x40,0x20,0xff,0x60,0x30
lcd_init_a4_1:       db 0x85,0x85,0x95,0x85
lcd_init_bb_lock:    times 8 db 0x00
lcd_init_2c_tail:    db 0x00,0x00,0x00,0x00
lcd_madctl_data:     db 0x70
lcd_pixfmt_data:     db 0x55
lcd_col_data:        db 0x00, 0x00, 0x01, 0x3f
lcd_status_row_data: db 0x00, 0x00, 0x00, 0x0b
lcd_red_pixels:      times 32 db 0xf8, 0x00
lcd_green_pixels:    times 32 db 0x07, 0xe0
lcd_blue_pixels:     times 32 db 0x00, 0x1f
lcd_cyan_pixels:     times 32 db 0x07, 0xff
lcd_white_pixels:    times 32 db 0xff, 0xff
