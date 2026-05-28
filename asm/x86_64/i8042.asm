; EdgeRun i8042 PS/2 keyboard driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Standard PC i8042 controller at I/O ports 0x60 (data) / 0x64 (status/cmd).
; Keyboard typically uses scancode set 2 (AT protocol).
;
; Ports:
;   0x60 - Data port (read = received data, write = send data)
;   0x64 - Status register (read) / Command register (write)
;
; Status byte (read 0x64):
;   Bit 0: Output buffer full (data ready to read)
;   Bit 1: Input buffer full (can't send yet)
;   Bit 2: System flag
;   Bit 3: Command/data (1=cmd written to 0x64, 0=data written to 0x60)
;   Bit 4: Inhibit flag
;   Bit 5: Transmit timeout
;   Bit 6: Receive timeout
;   Bit 7: Parity error

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

; I/O ports
%define I8042_DATA      0x60
%define I8042_STATUS    0x64
%define I8042_CMD       0x64

; Status register bits
%define I8042_OBF        0x01    ; Output buffer full
%define I8042_IBF        0x02    ; Input buffer full

; i8042 commands (write to 0x64)
%define I8042_CMD_READ_CONFIG  0x20
%define I8042_CMD_WRITE_CONFIG 0x60
%define I8042_CMD_DISABLE_KBD  0xAD
%define I8042_CMD_ENABLE_KBD   0xAE
%define I8042_CMD_SELF_TEST    0xAA
%define I8042_CMD_KBD_TEST     0xAB
%define I8042_CMD_KBD_DISABLE  0xA7
%define I8042_CMD_KBD_ENABLE   0xA8
%define I8042_CMD_WRITE_KBD    0xD4    ; Write next byte to keyboard controller

; Keyboard commands (write to 0x60 via 0xD4)
%define KBD_CMD_RESET          0xFF
%define KBD_CMD_SET_LEDS       0xED
%define KBD_CMD_SET_SCANCODE   0xF0
%define KBD_CMD_TYPEMATIC      0xF3
%define KBD_CMD_ENABLE         0xF4
%define KBD_CMD_DISABLE        0xF5
%define KBD_CMD_SET_DEFAULTS   0xF6
%define KBD_CMD_ACK            0xFA
%define KBD_CMD_BAT_DONE       0xAA    ; Basic Assurance Test passed

; HOSTED_TEST capture/response buffers (unconditional)
section .bss
global er_i8042_tx_buffer, er_i8042_tx_count
global er_i8042_rx_buffer, er_i8042_rx_count, er_i8042_rx_read
er_i8042_tx_buffer: resb 4096   ; Bytes written to controller
er_i8042_tx_count:  resq 1
er_i8042_rx_buffer: resb 4096   ; Pre-loaded response data
er_i8042_rx_count:  resq 1
er_i8042_rx_read:   resq 1

SECTION .text

; ==================================================================
; Port I/O macros
; =================================================================
%macro _i8042_out_data 1
    mov     al, %1
    mov     dx, I8042_DATA
    out     dx, al
%endmacro

%macro _i8042_in_data 0
    mov     dx, I8042_DATA
    in      al, dx
%endmacro

%macro _i8042_in_status 0
    mov     dx, I8042_STATUS
    in      al, dx
%endmacro

%macro _i8042_out_cmd 1
    mov     al, %1
    mov     dx, I8042_CMD
    out     dx, al
%endmacro

; ==================================================================
; er_i8042_status — read i8042 status register
; uint8_t er_i8042_status(void)
; =================================================================
er_fn er_i8042_status
    %ifdef HOSTED_TEST
    ; Simulate: set OBF if unread data in rx buffer
    push    rsi
    mov     rsi, [er_i8042_rx_count]
    mov     rax, [er_i8042_rx_read]
    cmp     rsi, rax
    ja      .data_avail
    xor     eax, eax
    pop     rsi
    er_ok
    er_ret
.data_avail:
    mov     al, I8042_OBF
    pop     rsi
    er_ok
    er_ret
    %else
    _i8042_in_status
    er_ok
    er_ret
    %endif

; ==================================================================
; er_i8042_wait_write — wait until input buffer is empty
; void er_i8042_wait_write(void)
; =================================================================
er_fn er_i8042_wait_write
    %ifndef HOSTED_TEST
    push    rcx
    mov     ecx, 100000
.loop:
    _i8042_in_status
    test    al, I8042_IBF
    jz      .ready
    pause
    dec     ecx
    jnz     .loop
    ; timeout
    pop     rcx
    er_err  ERROR_TIMEOUT
    er_ret
.ready:
    pop     rcx
    %endif
    er_ok
    er_ret

; ==================================================================
; er_i8042_wait_read — wait until output buffer has data
; void er_i8042_wait_read(void)
; =================================================================
er_fn er_i8042_wait_read
    %ifndef HOSTED_TEST
    push    rcx
    mov     ecx, 100000
.loop:
    _i8042_in_status
    test    al, I8042_OBF
    jnz     .ready
    pause
    dec     ecx
    jnz     .loop
    ; timeout
    pop     rcx
    er_err  ERROR_TIMEOUT
    er_ret
.ready:
    pop     rcx
    %endif
    er_ok
    er_ret

; ==================================================================
; er_i8042_write_cmd — write command byte to i8042 command port (0x64)
; void er_i8042_write_cmd(uint8_t cmd)
; =================================================================
er_fn er_i8042_write_cmd
    %ifdef HOSTED_TEST
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_i8042_tx_buffer
    mov     rdi, [er_i8042_tx_count]
    add     rsi, rdi
    mov     byte [rsi], dil
    inc     rdi
    mov     [er_i8042_tx_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
    er_ok
    er_ret
    %else
    call    er_i8042_wait_write
    test    edx, edx
    jnz     .fail
    _i8042_out_cmd dil
    er_ok
    er_ret
.fail:
    er_ret
    %endif

; ==================================================================
; er_i8042_write_data — write data byte to i8042 data port (0x60)
; void er_i8042_write_data(uint8_t data)
; =================================================================
er_fn er_i8042_write_data
    %ifdef HOSTED_TEST
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_i8042_tx_buffer
    mov     rdi, [er_i8042_tx_count]
    add     rsi, rdi
    mov     byte [rsi], sil
    inc     rdi
    mov     [er_i8042_tx_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
    er_ok
    er_ret
    %else
    call    er_i8042_wait_write
    test    edx, edx
    jnz     .fail
    _i8042_out_data sil
    er_ok
    er_ret
.fail:
    er_ret
    %endif

; ==================================================================
; er_i8042_read_data — read data byte from i8042 data port (0x60)
; Waits for data to be available. Returns byte.
; uint8_t er_i8042_read_data(void)
; =================================================================
er_fn er_i8042_read_data
    %ifdef HOSTED_TEST
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, [er_i8042_rx_read]
    mov     al, [er_i8042_rx_buffer + rsi]
    inc     rsi
    mov     [er_i8042_rx_read], rsi
    pop     rcx
    pop     rdi
    pop     rsi
    er_ok
    er_ret
    %else
    call    er_i8042_wait_read
    test    edx, edx
    jnz     .fail
    _i8042_in_data
    er_ok
    er_ret
.fail:
    xor     eax, eax
    er_ret
    %endif

; ==================================================================
; er_i8042_send_kbd_cmd — send a byte to the keyboard controller
; (writes 0xD4 to command port, then byte to data port)
; void er_i8042_send_kbd_cmd(uint8_t cmd)
; =================================================================
er_fn er_i8042_send_kbd_cmd
    %ifdef HOSTED_TEST
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_i8042_tx_buffer
    mov     rdi, [er_i8042_tx_count]
    add     rsi, rdi
    mov     byte [rsi], 0xD4
    inc     rdi
    mov     byte [rsi + 1], sil
    add     rdi, 2
    mov     [er_i8042_tx_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
    er_ok
    er_ret
    %else
    call    er_i8042_wait_write
    test    edx, edx
    jnz     .fail
    mov     al, 0xD4
    mov     dx, I8042_CMD
    out     dx, al
    call    er_i8042_wait_write
    test    edx, edx
    jnz     .fail
    mov     al, sil
    mov     dx, I8042_DATA
    out     dx, al
    er_ok
    er_ret
.fail:
    er_ret
    %endif

; ==================================================================
; er_i8042_init — initialize the i8042 controller and keyboard
; Returns: rax = 0 on success, nonzero on error
;
; Sequence: test controller, enable keyboard, reset keyboard
; =================================================================
er_fn er_i8042_init
    push    r12

    %ifndef HOSTED_TEST
    ; Enable keyboard port (command 0xAE). On QEMU the PS/2 keyboard
    ; is already functional, but we ensure the port is active.
    mov     dil, I8042_CMD_ENABLE_KBD
    call    er_i8042_write_cmd
    test    edx, edx
    jnz     .fail

    ; Drain any stale data
    mov     ecx, 16
.drain:
    call    er_i8042_status
    test    al, I8042_OBF
    jz      .drained
    call    er_i8042_read_data
    dec     ecx
    jnz     .drain
.drained:
    %endif

    pop     r12
    er_ok
    er_ret

.fail:
    pop     r12
    er_ret

; ==================================================================
; er_i8042_read_scancode — non-blocking scancode read
; Returns: rax = scancode byte (0 if nothing available)
;
; For scancode set 2 (default AT):
;   - Bits 0-7: scancode
;   - Bit 8 (in caller context): 0 = make, 1 = break
;   - Break codes are prefixed with 0xF0 in set 2
;
; This function coalesces set 2 make/break into a simpler format:
;   - Make: return scancode (bit 7 = 0)
;   - Break: return scancode | 0x80 (bit 7 = 1)
; =================================================================
er_fn er_i8042_read_scancode
    push    rcx
    push    rdx

    call    er_i8042_status
    test    al, I8042_OBF
    jz      .none

    call    er_i8042_read_data

    ; Check for set 2 break prefix (0xF0)
    cmp     al, 0xF0
    jne     .check_multi

    ; Read next byte (the actual key that was released)
    call    er_i8042_wait_read
    call    er_i8042_read_data
    or      al, 0x80             ; set break flag (bit 7)
    jmp     .done

.check_multi:
    ; Check for multi-byte prefix (0xE0, 0xE1)
    cmp     al, 0xE0
    je      .multi_byte
    cmp     al, 0xE1
    jne     .done

.multi_byte:
    ; Multi-byte scancode: prefix + second byte
    ; Return second byte only (most set 2 extended keys map to < 0x80)
    push    rax                  ; save prefix
    call    er_i8042_wait_read
    call    er_i8042_read_data
    mov     cl, al               ; cl = second byte

    ; Check if it's a break (0xF0 after prefix)
    cmp     cl, 0xF0
    jne     .store_ext

    ; Extended break: prefix + 0xF0 + keycode
    call    er_i8042_wait_read
    call    er_i8042_read_data
    or      al, 0x80
    pop     rcx                  ; discard prefix
    jmp     .done

.store_ext:
    mov     al, cl
    pop     rcx                  ; discard prefix
    jmp     .done

.none:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    pop     rdx
    pop     rcx
    er_ret

.done:
    pop     rdx
    pop     rcx
    er_ok
    er_ret

; ==================================================================
; er_i8042_scancode_to_ascii — translate scancode set 2 to ASCII
; char er_i8042_scancode_to_ascii(uint8_t scancode, uint8_t shifted)
;
; rdi = scancode (make code, bit 7 clear)
; sil = shifted (0 = lowercase, nonzero = uppercase/shifted)
; Returns: rax = ASCII character, 0 if unmapped
;
; Only handles common alphanumeric keys. Extended keys (0xE0 prefix)
; should be stripped before calling.
; =================================================================
er_fn er_i8042_scancode_to_ascii
    push    rbx

    movzx   eax, dil
    and     al, 0x7f             ; strip break flag
    cmp     al, 0x5d             ; max scancode in our table
    ja      .unmapped

    mov     ebx, eax
    test    sil, sil
    jnz     .shifted

    ; Lowercase / unshifted table (index 0 = scancode 0)
    ; Ordered by scancode value
    lea     rdx, [rel .lower_table]
    movzx   eax, byte [rdx + rbx]
    jmp     .done

.shifted:
    lea     rdx, [rel .upper_table]
    movzx   eax, byte [rdx + rbx]

.done:
    pop     rbx
    er_ok
    er_ret

.unmapped:
    xor     eax, eax
    pop     rbx
    er_ok
    er_ret

; Scancode set 2 → ASCII tables
; Index = make scancode value (0x00 - 0x5d)
; 0x00 = unmapped/unused
SECTION .rodata
.lower_table:
    db 0, 0, 0, 0, 0, 0, 0, 0      ; 00-07
    db 0, 0, 0, 0, 0, '`', 0, 0   ; 08-0f
    db 0, 0, 0, 0, 0, 'q', '1', 0 ; 10-17
    db 0, 0, 0, 'z', 's', 'a', 'w', '2' ; 18-1f
    db 0, 0, 'c', 'x', 'd', 'e', '4', '3' ; 20-27
    db 0, 0, ' ', 'v', 'f', 't', 'r', '5' ; 28-2f
    db 0, 0, 'n', 'b', 'h', 'g', 'y', '6' ; 30-37
    db 0, 0, 0, 'm', 'j', 'u', '7', '8' ; 38-3f
    db 0, 0, ',', 'k', 'i', 'o', '0', '9' ; 40-47
    db 0, 0, '.', '/', 'l', ';', 'p', '-' ; 48-4f
    db 0, 0, 0, 39, 0, '[', '=', 0     ; 50-57 (39 = ')  
    db 0, 0, 0, 0, 0, 0, 0, 0      ; 58-5f
    ; Note: 0x5c = ']', 0x5d = '\'
    ; But these aren't at these offsets — need proper mapping

.upper_table:
    db 0, 0, 0, 0, 0, 0, 0, 0      ; 00-07
    db 0, 0, 0, 0, 0, '~', 0, 0   ; 08-0f
    db 0, 0, 0, 0, 0, 'Q', '!', 0 ; 10-17
    db 0, 0, 0, 'Z', 'S', 'A', 'W', '@' ; 18-1f
    db 0, 0, 'C', 'X', 'D', 'E', '$', '#' ; 20-27
    db 0, 0, ' ', 'V', 'F', 'T', 'R', '%' ; 28-2f
    db 0, 0, 'N', 'B', 'H', 'G', 'Y', '^' ; 30-37
    db 0, 0, 0, 'M', 'J', 'U', '&', '*' ; 38-3f
    db 0, 0, '<', 'K', 'I', 'O', ')', '(' ; 40-47
    db 0, 0, '>', '?', 'L', ':', 'P', '_' ; 48-4f
    db 0, 0, 0, '"', 0, '{', '+', 0     ; 50-57
    db 0, 0, 0, 0, 0, 0, 0, 0      ; 58-5f
