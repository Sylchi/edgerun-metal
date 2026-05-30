; ESP32 serial boot host tool — x86_64 Linux userspace assembly
; Target: x86_64 (host) talking to ESP32 ROM bootloader over UART
;
; Usage: esp32_serial_boot_host [options] <binary> [entry_point]

%include "host/esp32_serial_boot.inc"

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
opt_binary:     resq 1
opt_help:       resb 1
opt_dry_run:    resb 1

binary_data:    resq 1
binary_size:    resd 1

serial_fd:      resd 1

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

_start:
    mov     r14, [rsp]
    lea     r15, [rsp + 8]
    mov     rsp, stack_top

    mov     qword [opt_port], default_port
    mov     dword [opt_baud], ESP_DEFAULT_BAUD
    mov     dword [opt_entry], 0x40000000
    mov     byte [opt_help], 0
    mov     byte [opt_dry_run], 0
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
    cmp     qword [opt_binary], 0
    je      .help_exit

    mov     rdi, [opt_binary]
    call    read_file
    test    rax, rax
    jz      .file_err
    mov     [binary_data], rax
    mov     [binary_size], edx

    lea     rdi, [m_plan]
    call    print_str
    mov     edi, [binary_size]
    call    print_dec
    lea     rdi, [m_to]
    call    print_str
    mov     rdi, [opt_port]
    call    print_str
    call    print_crlf

    cmp     byte [opt_dry_run], 1
    je      .dry_exit

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

    mov     edi, [serial_fd]
    call    esp_reset
    test    eax, eax
    js      .rst_err

    mov     edi, [serial_fd]
    call    esp_sync
    test    eax, eax
    jnz     .sync_err

    mov     edi, [serial_fd]
    mov     rsi, [binary_data]
    mov     edx, [binary_size]
    mov     ecx, [opt_entry]
    call    esp_download
    test    eax, eax
    jnz     .dl_err

    lea     rdi, [m_ok]
    call    print_str
    call    print_crlf
    xor     edi, edi
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
    jz      .ck_help
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex32
    mov     [opt_entry], eax
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

    ; VMIN = 1, VTIME = 0
    mov     byte [termios_buf + TERMIO2_CC + VMIN], 1
    mov     byte [termios_buf + TERMIO2_CC + VTIME], 0

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
    mov     r8d, ebx            ; r8d = num_packets

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
    mov     edx, r8d            ; num_packets
    mov     ecx, ESP_MEM_PACKET_SIZE
    mov     r8d, 0x40000000     ; mem_offset = IROM base
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
    cmp     r9d, r8d
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
    push    r12
    push    r13

    mov     r12d, edi
    mov     r13, rsi
    xor     ecx, ecx

.loop:
    cmp     ecx, edx
    jae     .done

    mov     edi, r12d
    lea     rsi, [r13 + rcx]
    mov     edx, 1
    mov     eax, SYS_read
    syscall
    test    eax, eax
    jle     .done

    inc     ecx
    cmp     byte [r13 + rcx - 1], SLIP_END
    jne     .loop

.done:
    mov     eax, ecx
    pop     r13
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
    mov     [rbp - 8], eax
    mov     eax, edx
    mov     ecx, 1000000
    mul     ecx
    mov     [rbp - 4], eax

    lea     rdi, [rbp - 8]
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
str_help:           db "--help", 0
str_dry:            db "--dry-run", 0

m_plan:             db "ESP32 boot: ", 0
m_to:               db " bytes -> ", 0
m_ok:               db "OK", 0
m_dry:              db "Dry run", 0
m_file_err:         db "Cannot read binary file", 0
m_open_err:         db "Cannot open serial port", 0
m_cfg_err:          db "Cannot configure serial port", 0
m_rst_err:          db "Reset failed", 0
m_sync_err:         db "SYNC failed", 0
m_dl_err:           db "Download failed", 0
m_bad_arg:          db "Bad argument. Use --help for usage.", 0

usage_str:          db "Usage: esp32_serial_boot_host [options] <binary> [entry_point]", 0x0a
                    db "Options:", 0x0a
                    db "  --port <device>      Serial port (default: /dev/ttyUSB0)", 0x0a
                    db "  --baud <rate>        Baud rate (default: 115200)", 0x0a
                    db "  --entry <hex>        Entry point address (default: 0x40000000)", 0x0a
                    db "  --dry-run            Scan port but don't write", 0x0a
                    db "  --help               Show this help", 0x0a
                    db 0
