; EdgeRun Bluetooth Low Energy scanner — x86_64 assembly
; UART HCI (H4) transport. BLE advertising scan only — no connections.
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_serial_init
extern er_serial_puts
extern er_serial_putchar
extern er_serial_puthex32
extern er_serial_crlf
extern er_memcpy

; ─── HCI UART Transport (H4) ──────────────────────────────────────
HCI_CMD_PKT    equ 0x01
HCI_EVT_PKT    equ 0x04

; ─── HCI Command opcodes ──────────────────────────────────────────
HCI_OP_RESET              equ (0x0003 | (0x03 << 10))
HCI_OP_READ_LOCAL_VERSION equ (0x0001 | (0x01 << 10))
HCI_OP_READ_BD_ADDR       equ (0x0009 | (0x01 << 10))
HCI_OP_LE_SET_SCAN_PARAM  equ (0x000B | (0x08 << 10))
HCI_OP_LE_SET_SCAN_ENABLE equ (0x000C | (0x08 << 10))

; ─── HCI Event codes ──────────────────────────────────────────────
HCI_EVT_CMD_COMPLETE equ 0x0E
HCI_EVT_LE_META      equ 0x3E
HCI_EVT_LE_ADV_REPORT equ 0x02

; ─── LE Scan parameters ───────────────────────────────────────────
LE_SCAN_PASSIVE  equ 0
LE_SCAN_INTERVAL equ 0x0010
LE_SCAN_WINDOW   equ 0x0010

; ─── Buffer sizes ─────────────────────────────────────────────────
HCI_EVT_BUF_SIZE equ 256
BT_ADDR_BYTES    equ 6
ADV_DATA_MAX     equ 31

SECTION .bss
hci_evt_buf:   resb HCI_EVT_BUF_SIZE
bt_adv_addr:   resb BT_ADDR_BYTES
bt_adv_type:   resb 1
bt_adv_len:    resb 1
bt_adv_data:   resb ADV_DATA_MAX
bt_hci_ver:    resb 1
bt_hci_rev:    resw 1
bt_lmp_ver:    resb 1
bt_manufacturer: resw 1
bt_lmp_subver:  resw 1

SECTION .text

; ─── UART I/O helpers (use I/O port instructions) ───────────────────

; void _bt_outb(uint16_t port, uint8_t val)
_bt_outb:
    mov     dx, di
    mov     al, sil
    out     dx, al
    ret

; uint8_t _bt_inb(uint16_t port)
_bt_inb:
    mov     dx, di
    in      al, dx
    ret

; ==================================================================
; er_bt_uart_init — init UART for BT HCI
; void er_bt_uart_init(uint16_t uart_port, uint16_t baud_divisor)
;
; Sets up the UART to 8N1 at the given baud rate.
; rdi = UART port base, si = baud divisor
; ==================================================================
er_fn er_bt_uart_init
    call    er_serial_init
    er_ok
    ret

; ==================================================================
; _bt_uart_putchar — write one byte to UART
; rdi = UART port, sil = byte
; ==================================================================
_bt_uart_putchar:
    push    rdx
    push    rax
    mov     dx, di
    add     dx, 5           ; LSR
.wait_txe:
    in      al, dx
    test    al, 0x20        ; THR empty?
    jz      .wait_txe
    mov     dx, di
    mov     al, sil
    out     dx, al          ; write to THR
    ; Small delay to let UART settle
    mov     ecx, 1000
.pause:
    pause
    dec     ecx
    jnz     .pause
    pop     rax
    pop     rdx
    ret

; ==================================================================
; _bt_uart_getchar — read one byte from UART (with timeout)
; rdi = UART port
; Returns: al = byte, rdx = 0 on success
;          On timeout: al = 0, rdx = ERROR_TIMEOUT
; ==================================================================
_bt_uart_getchar:
    push    rcx
    push    rdx
    mov     ecx, 5000000       ; ~12ms timeout at ~2GHz
    mov     dx, di
    add     dx, 5              ; LSR
.wait_dr:
    in      al, dx
    test    al, 0x01           ; data ready?
    jnz     .have_data
    dec     ecx
    jnz     .wait_dr
    ; timeout
    xor     eax, eax
    mov     edx, ERROR_TIMEOUT
    pop     rdx
    pop     rcx
    ret
.have_data:
    mov     dx, di
    in      al, dx             ; read RBR
    xor     edx, edx
    pop     rdx
    pop     rcx
    ret

; ==================================================================
; _bt_send_hci_cmd — send HCI command packet over UART
; rdi = UART port, rsi = opcode (16-bit), rdx = param len,
; rcx = param data pointer
;
; Builds HCI command packet: HCI_CMD_PKT | opcode(2) | len | params
; ==================================================================
_bt_send_hci_cmd:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; UART port
    mov     r13w, si        ; opcode
    mov     r14d, edx       ; param length
    mov     r15, rcx        ; param pointer

    ; Send H4 packet type
    mov     rdi, r12
    mov     sil, HCI_CMD_PKT
    call    _bt_uart_putchar

    ; Send opcode (little-endian, 2 bytes)
    mov     rdi, r12
    mov     sil, r13b
    call    _bt_uart_putchar
    mov     rdi, r12
    shr     r13w, 8
    mov     sil, r13b
    call    _bt_uart_putchar

    ; Send parameter length
    mov     rdi, r12
    mov     sil, r14b
    call    _bt_uart_putchar

    ; Send parameters
    xor     ebx, ebx
.param_loop:
    cmp     ebx, r14d
    jae     .param_done
    mov     rdi, r12
    mov     sil, [r15 + rbx]
    call    _bt_uart_putchar
    inc     ebx
    jmp     .param_loop
.param_done:

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _bt_recv_hci_evt — receive HCI event packet from UART
; rdi = UART port
; Returns: eax = event length (including header), rdx = 0 on success
;          On failure/timeout: eax = 0, rdx = ERROR_TIMEOUT
;          hci_evt_buf filled with raw event bytes on success
; ==================================================================
_bt_recv_hci_evt:
    push    r12
    mov     r12, rdi

    ; Read H4 packet type (should be HCI_EVT_PKT)
    call    _bt_uart_getchar
    test    edx, edx
    jnz     .fail
    cmp     al, HCI_EVT_PKT
    jne     .fail

    ; Read event code
    call    _bt_uart_getchar
    test    edx, edx
    jnz     .fail
    mov     byte [hci_evt_buf + 0], al

    ; Read parameter length
    call    _bt_uart_getchar
    test    edx, edx
    jnz     .fail
    mov     byte [hci_evt_buf + 1], al
    movzx   ecx, al

    ; Read parameters
    xor     ebx, ebx
.read_params:
    cmp     ebx, ecx
    jae     .done

    ; Avoid buffer overflow
    cmp     ebx, HCI_EVT_BUF_SIZE - 2
    jae     .done

    call    _bt_uart_getchar
    test    edx, edx
    jnz     .fail
    mov     byte [hci_evt_buf + 2 + rbx], al
    inc     ebx
    jmp     .read_params

.done:
    ; Return total event length: 2 (code + plen) + params actually read
    lea     eax, [rbx + 2]
    xor     edx, edx
    pop     r12
    ret

.fail:
    xor     eax, eax
    mov     edx, ERROR_TIMEOUT
    pop     r12
    ret

; ==================================================================
; _bt_hci_cmd_sync — send HCI command and wait for Command Complete
; rdi = UART port, si = opcode, edx = param len, rcx = params
;
; Returns: eax = status byte from command complete event, rdx = 0
;          On failure: eax = -1, rdx = error
; ==================================================================
_bt_hci_cmd_sync:
    push    r12
    push    r13

    mov     r12, rdi        ; UART port
    mov     r13w, si        ; opcode

    ; Send the command
    call    _bt_send_hci_cmd

    ; Wait for Command Complete event
    mov     ecx, 100        ; max attempts
.wait_cc:
    push    rcx
    ; Debug: read LSR
    mov     dx, r12w
    add     dx, 5
    in      al, dx
    mov     byte [hci_evt_buf + 0], al
    mov     rdi, 0x3f8
    mov     esi, 0x4c       ; 'L'
    call    er_serial_putchar
    mov     esi, 0x3d
    call    er_serial_putchar
    movzx   esi, byte [hci_evt_buf + 0]
    call    er_serial_puthex32
    mov     esi, 0x20
    call    er_serial_putchar
    pop     rcx
    mov     rdi, r12
    call    _bt_recv_hci_evt
    test    edx, edx
    jnz     .next           ; timeout/error — try next

    ; Check if it's Command Complete
    movzx   eax, byte [hci_evt_buf + 0]
    cmp     al, HCI_EVT_CMD_COMPLETE
    jne     .next

    ; Check that opcode matches (hci_evt_buf[3..4] is the command opcode)
    movzx   eax, word [hci_evt_buf + 3]
    cmp     ax, r13w
    je      .match

.next:
    dec     ecx
    jnz     .wait_cc

    ; Ran out of attempts
    mov     eax, -1
    mov     edx, ERROR_TIMEOUT
    pop     r13
    pop     r12
    ret

.match:
    ; Return status (hci_evt_buf[5] is the status in CC event)
    movzx   eax, byte [hci_evt_buf + 5]
    xor     edx, edx
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_bt_reset — reset Bluetooth controller
; rdi = UART port
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success, error code on failure
; ==================================================================
er_fn er_bt_reset
    xor     esi, esi        ; opcode (will be set below)
    mov     si, HCI_OP_RESET
    xor     edx, edx        ; no params
    xor     ecx, ecx
    call    _bt_hci_cmd_sync
    test    eax, eax
    jnz     .fail

    xor     eax, eax
    xor     edx, edx
    er_ok
    ret
.fail:
    mov     eax, -1
    er_err  ERROR_IO
    ret

; ==================================================================
; er_bt_fw_load — load firmware if controller needs it
; rdi = UART port
;
; Attempts to detect whether the Bluetooth controller is in HCI
; mode.  If not, tries to detect a bootloader and load firmware.
; Returns success if the controller is usable after this call.
;
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success, error code on failure
; ==================================================================
er_fn er_bt_fw_load
    push    r12
    push    r13
    mov     r12, rdi

    ; Check if controller is already in HCI mode by reading
    ; local version information.
    mov     rdi, r12
    mov     si, HCI_OP_READ_LOCAL_VERSION
    xor     edx, edx
    xor     ecx, ecx
    call    _bt_hci_cmd_sync
    test    eax, eax
    jnz     .try_bootloader

    ; HCI responder — parse version info from Command Complete.
    ; Layout: status(1) + hci_ver(1) + hci_rev(2) + lmp_ver(1)
    ;         + manufacturer(2) + lmp_subver(2)
    movzx   eax, byte [hci_evt_buf + 6]
    mov     byte [bt_hci_ver], al
    movzx   eax, word [hci_evt_buf + 7]
    mov     word [bt_hci_rev], ax
    movzx   eax, byte [hci_evt_buf + 9]
    mov     byte [bt_lmp_ver], al
    movzx   eax, word [hci_evt_buf + 10]
    mov     word [bt_manufacturer], ax
    movzx   eax, word [hci_evt_buf + 12]
    mov     word [bt_lmp_subver], ax

    ; Already in HCI mode — firmware is loaded.
    xor     eax, eax
    xor     edx, edx
    er_ok
    pop     r13
    pop     r12
    ret

.try_bootloader:
    ; Controller did not respond to a standard HCI command.
    ; It may be in a bootloader / firmware-download mode.
    ;
    ; Two common patterns:
    ;   CSR (Cambridge Silicon Radio) — sends 0x00 bytes or
    ;     newline characters periodically.
    ;   Broadcom — sends a fixed 15-byte signature.
    ;
    ; For now the firmware blob is absent, so report NOT_PRESENT.
    ; When firmware images are added (as .rodata incbin), the
    ; detection and download logic goes here.
    mov     eax, -1
    er_err  ERROR_NOT_PRESENT
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_bt_le_set_scan_params — set LE scan parameters
; rdi = UART port
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success
; ==================================================================
er_fn er_bt_le_set_scan_params
    push    r12
    mov     r12, rdi
    sub     rsp, 7

    ; Parameters: type(1) + interval(2) + window(2) + ownAddrType(1) + filterPolicy(1)
    mov     byte [rsp + 0], LE_SCAN_PASSIVE   ; scan type
    mov     word [rsp + 1], LE_SCAN_INTERVAL  ; scan interval
    mov     word [rsp + 3], LE_SCAN_WINDOW    ; scan window
    mov     byte [rsp + 5], 0                 ; own address type (public)
    mov     byte [rsp + 6], 0                 ; filter policy (accept all)

    mov     rdi, r12
    mov     si, HCI_OP_LE_SET_SCAN_PARAM
    mov     edx, 7
    lea     rcx, [rsp]
    call    _bt_hci_cmd_sync

    add     rsp, 7
    pop     r12
    test    eax, eax
    jnz     .fail
    xor     eax, eax
    xor     edx, edx
    er_ok
    ret
.fail:
    mov     eax, -1
    er_err  ERROR_IO
    ret

; ==================================================================
; er_bt_le_scan_enable — start/stop BLE scanning
; rdi = UART port, sil = enable (1=start, 0=stop)
; Returns: eax = 0 on success, -1 on failure
;          rdx = 0 on success
; ==================================================================
er_fn er_bt_le_scan_enable
    push    r12
    mov     r12, rdi
    sub     rsp, 2

    ; Parameters: enable(1) + filter_duplicates(1)
    mov     byte [rsp + 0], sil     ; scan enable
    mov     byte [rsp + 1], 0       ; filter duplicates

    mov     rdi, r12
    mov     si, HCI_OP_LE_SET_SCAN_ENABLE
    mov     edx, 2
    lea     rcx, [rsp]
    call    _bt_hci_cmd_sync

    add     rsp, 2
    pop     r12
    test    eax, eax
    jnz     .fail
    xor     eax, eax
    xor     edx, edx
    er_ok
    ret
.fail:
    mov     eax, -1
    er_err  ERROR_IO
    ret

; ==================================================================
; er_bt_poll_adv — poll for next BLE advertisement report
; rdi = UART port
;
; Reads and parses the next LE Advertising Report event.
; Stores MAC in bt_adv_addr, type in bt_adv_type, data in bt_adv_data.
;
; Returns: eax = 1 if advertisement received, 0 if none available
;          rdx = 0
; ==================================================================
er_fn er_bt_poll_adv
    push    r12
    mov     r12, rdi

    ; Try to read an HCI event (non-blocking)
    ; For now, use blocking read with timeout would be better, but
    ; we do a simple blocking read (will wait for data)
    ; In practice this should be called from a polling loop

    mov     rdi, r12
    call    _bt_recv_hci_evt

    ; Check for timeout / error
    test    edx, edx
    jnz     .not_adv

    ; Check if LE Meta Event
    movzx   eax, byte [hci_evt_buf + 0]
    cmp     al, HCI_EVT_LE_META
    jne     .not_adv

    ; Check sub-event: LE Advertising Report (0x02)
    movzx   eax, byte [hci_evt_buf + 2]   ; first param byte = sub-event
    cmp     al, HCI_EVT_LE_ADV_REPORT
    jne     .not_adv

    ; Parse LE Advertising Report
    ; hci_evt_buf[2] = sub-event (0x02)
    ; hci_evt_buf[3] = num_reports
    ; hci_evt_buf[4] = event_type
    ; hci_evt_buf[5] = address_type
    ; hci_evt_buf[6..11] = address (MAC)
    ; hci_evt_buf[12] = data length
    ; hci_evt_buf[13..] = data
    ; last byte = RSSI

    movzx   eax, byte [hci_evt_buf + 4]   ; event type
    mov     byte [bt_adv_type], al

    ; Copy MAC address (6 bytes at offset 6)
    lea     rsi, [hci_evt_buf + 6]
    mov     rdi, bt_adv_addr
    mov     ecx, BT_ADDR_BYTES
    call    er_memcpy

    ; Copy advertisement data length and payload
    movzx   ecx, byte [hci_evt_buf + 12]   ; data length
    cmp     ecx, ADV_DATA_MAX
    jbe     .copy_len
    mov     ecx, ADV_DATA_MAX
.copy_len:
    mov     byte [bt_adv_len], cl

    lea     rsi, [hci_evt_buf + 13]
    mov     rdi, bt_adv_data
    call    er_memcpy

    mov     eax, 1
    xor     edx, edx
    pop     r12
    ret

.not_adv:
    xor     eax, eax
    xor     edx, edx
    pop     r12
    ret

; ==================================================================
; er_bt_print_adv — print current advertisement info via serial
; rdi = UART port (for BT, not used for display)
; rsi = display serial port
; ==================================================================
er_fn er_bt_print_adv
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi        ; BT UART (unused)
    mov     r13, rsi        ; display port

    ; Print "ble adv "
    mov     rdi, r13
    lea     rsi, [rel .adv_str]
    call    er_serial_puts

    ; Print MAC address (6 bytes, bt_adv_addr)
    xor     ebx, ebx
.mac_loop:
    movzx   esi, byte [bt_adv_addr + rbx]
    mov     rdi, r13
    call    er_serial_puthex32
    inc     ebx
    cmp     ebx, BT_ADDR_BYTES
    jae     .mac_done
    mov     rdi, r13
    mov     sil, ':'
    call    er_serial_putchar
    jmp     .mac_loop
.mac_done:

    ; Print space then data bytes
    mov     rdi, r13
    mov     sil, ' '
    call    er_serial_putchar

    xor     ebx, ebx
    movzx   ecx, byte [bt_adv_len]
.data_loop:
    cmp     ebx, ecx
    jae     .data_done
    movzx   esi, byte [bt_adv_data + rbx]
    mov     rdi, r13
    call    er_serial_puthex32
    inc     ebx
    jmp     .data_loop
.data_done:

    mov     rdi, r13
    call    er_serial_crlf

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

; ─── Data ───────────────────────────────────────────────────────────
.adv_str: db "ble adv ", 0
