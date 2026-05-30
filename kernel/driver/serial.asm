; EdgeRun x86 UART 16550 serial driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; COM1 at standard I/O port 0x3F8.
; For bare-metal use, serial_init must be called before any other serial function.
; For hosted testing, define HOSTED_TEST — OUT instructions become buffer stores,
; IN instructions return ready status, and the test can read the output buffer.

%include "x86_64/macros.inc"

; I/O port addresses
%define COM1_PORT    0x3f8
%define COM2_PORT    0x2f8

; UART register offsets (from base port)
%define UART_RBR     0       ; Receive Buffer Register (read)
%define UART_THR     0       ; Transmit Holding Register (write)
%define UART_DLL     0       ; Divisor Latch Low (when DLAB=1)
%define UART_DLM     1       ; Divisor Latch High (when DLAB=1)
%define UART_IER     1       ; Interrupt Enable Register
%define UART_IIR     2       ; Interrupt Identification Register (read)
%define UART_FCR     2       ; FIFO Control Register (write)
%define UART_LCR     3       ; Line Control Register
%define UART_MCR     4       ; Modem Control Register
%define UART_LSR     5       ; Line Status Register
%define UART_MSR     6       ; Modem Status Register
%define UART_SCR     7       ; Scratch Register

; LCR bit flags
%define LCR_DLAB     0x80    ; Divisor Latch Access Bit
%define LCR_8N1      0x03    ; 8 bits, no parity, 1 stop bit

; LSR bit flags
%define LSR_THR_EMPTY 0x20   ; Transmitter Holding Register Empty
%define LSR_DATA_READY 0x01  ; Receiver Data Ready

; Default baud rate divisor for 115200 (1.8432 MHz / (16 * 115200))
%define BAUD_115200  1

; er_outb, er_inb, er_out_dx_al, er_in_al_dx defined in macros.inc
; HOSTED_TEST overrides them below.

%ifdef HOSTED_TEST
; Hosted-testing mode: redirect serial output to a global buffer.
section .bss
global er_serial_tx_buffer, er_serial_tx_count
er_serial_tx_buffer: resb 4096
er_serial_tx_count:  resq 1

; Override I/O macros — each port write appends to the buffer.
%macro er_outb 2
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_serial_tx_buffer
    mov     rdi, [er_serial_tx_count]
    add     rsi, rdi
    mov     byte [rsi], %2
    inc     rdi
    mov     [er_serial_tx_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
%endmacro

%macro er_inb 1
    mov     al, 0x60        ; LSR_THR_EMPTY always set
%endmacro

%macro er_out_dx_al 0
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_serial_tx_buffer
    mov     rdi, [er_serial_tx_count]
    add     rsi, rdi
    mov     [rsi], al
    inc     rdi
    mov     [er_serial_tx_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
%endmacro

%macro er_in_al_dx 0
    mov     al, 0x60
%endmacro
%endif

SECTION .text

; ==================================================================
; er_serial_init — initialize COM1 serial port
; void er_serial_init(uint16_t port, uint32_t baud_divisor)
;
; port = COM base address (e.g. 0x3F8)
; baud_divisor = divisor for baud rate (1 = 115200, 2 = 57600, etc.)
; ==================================================================
er_fn er_serial_init
    mov     r8, rdi

    ; Disable interrupts (IER = 0)
    mov     dx, r8w
    add     dx, UART_IER
    xor     al, al
    out     dx, al

    ; Set DLAB=1 to access divisor latch
    mov     dx, r8w
    add     dx, UART_LCR
    mov     al, LCR_DLAB
    out     dx, al

    ; Set baud rate divisor
    mov     dx, r8w
    add     dx, UART_DLL
    mov     al, sil
    out     dx, al
    mov     dx, r8w
    add     dx, UART_DLM
    mov     al, ah
    out     dx, al

    ; 8N1
    mov     dx, r8w
    add     dx, UART_LCR
    mov     al, LCR_8N1
    out     dx, al

    ; Enable FIFO, clear TX/RX, 14-byte threshold
    mov     dx, r8w
    add     dx, UART_FCR
    mov     al, 0xC7
    out     dx, al

    ; Enable RTS/DSR
    mov     dx, r8w
    add     dx, UART_MCR
    mov     al, 0x0B
    out     dx, al

    ; Enable receive data interrupt
    mov     dx, r8w
    add     dx, UART_IER
    mov     al, 0x01
    out     dx, al

    ret

; ==================================================================
; er_serial_putchar — write one character to serial port
; void er_serial_putchar(uint16_t port, unsigned char c)
; ==================================================================
er_fn er_serial_putchar
    mov     dx, di
    add     dx, UART_LSR
.wait:
    er_in_al_dx
    test    al, LSR_THR_EMPTY
    jz      .wait

    mov     dx, di
    mov     al, sil
    er_out_dx_al
    ret

; ==================================================================
; er_serial_puts — write null-terminated string to serial port
; void er_serial_puts(uint16_t port, const char* str)
; ==================================================================
er_fn er_serial_puts
    push    rbx
    mov     rbx, rdi            ; rbx = port
    ; rsi already holds str (second arg)

.loop:
    lodsb
    test    al, al
    jz      .done

    mov     dx, bx
    add     dx, UART_LSR
.wait:
    er_in_al_dx
    test    al, LSR_THR_EMPTY
    jz      .wait

    mov     dx, bx
    mov     al, [rsi - 1]
    er_out_dx_al

    jmp     .loop

.done:
    pop     rbx
    ret

; ==================================================================
; er_serial_puthex32 — write 32-bit value as 8 hex digits
; void er_serial_puthex32(uint16_t port, uint32_t value)
; ==================================================================
er_fn er_serial_puthex32
    push    rbx
    push    rcx
    mov     r8, rdi             ; r8 = port
    mov     r9d, esi            ; r9 = value

    ; Write "0x" prefix
    mov     sil, '0'
call _serial_putchar
    mov     sil, 'x'
call _serial_putchar

    ; Write 8 hex digits (most significant first)
    mov     ecx, 8              ; 8 nybbles
    shl     r9d, 0              ; position at top

.loop:
    mov     eax, r9d
    shr     eax, 28             ; get top nybble
    and     eax, 0x0f
    cmp     eax, 10
    jb      .digit
    add     eax, 'a' - 10 - '0'
.digit:
    add     eax, '0'
    mov     sil, al
call _serial_putchar
    shl     r9d, 4              ; shift next nybble into position
    dec     ecx
    jnz     .loop

    pop     rcx
    pop     rbx
    ret

; ==================================================================
; er_serial_puthex64 — write 64-bit value as 16 hex digits
; void er_serial_puthex64(uint16_t port, uint64_t value)
; ==================================================================
er_fn er_serial_puthex64
    push    rbx
    push    rcx
    mov     r8, rdi             ; r8 = port
    mov     r9, rsi             ; r9 = value

    ; Write "0x" prefix
    mov     sil, '0'
call _serial_putchar
    mov     sil, 'x'
call _serial_putchar

    ; Write 16 hex digits (most significant first)
    mov     ecx, 16
    shl     r9, 0

.loop:
    mov     rax, r9
    shr     rax, 60
    and     eax, 0x0f
    cmp     eax, 10
    jb      .digit
    add     eax, 'a' - 10 - '0'
.digit:
    add     eax, '0'
    mov     sil, al
call _serial_putchar
    shl     r9, 4
    dec     ecx
    jnz     .loop

    pop     rcx
    pop     rbx
    ret

; ==================================================================
; er_serial_putdec32 — write 32-bit value as decimal
; void er_serial_putdec32(uint16_t port, uint32_t value)
; ==================================================================
er_fn er_serial_putdec32
    push    rbx
    push    rcx
    push    rdx
    mov     r8, rdi             ; r8 = port
    mov     r9d, esi            ; r9 = value

    ; Handle zero
    test    r9d, r9d
    jnz     .nonzero

    mov     sil, '0'
call _serial_putchar
    jmp     .done

.nonzero:
    ; Buffer for digits (max 10 + null)
    sub     rsp, 16
    mov     byte [rsp + 10], 0
    mov     ecx, 9              ; start from end

    mov     eax, r9d
    xor     edx, edx

.convert:
    xor     edx, edx
    mov     ebx, 10
    div     ebx                 ; eax = quotient, edx = remainder
    add     dl, '0'
    mov     [rsp + rcx], dl
    dec     ecx
    test    eax, eax
    jnz     .convert

    ; Print from first digit
    inc     ecx
.print:
    mov     sil, [rsp + rcx]
call _serial_putchar
    inc     ecx
    cmp     ecx, 10
    jb      .print

    add     rsp, 16

.done:
    pop     rdx
    pop     rcx
    pop     rbx
    ret

_serial_putchar:
    mov     dx, r8w
    add     dx, UART_LSR
.wait:
    er_in_al_dx
    test    al, LSR_THR_EMPTY
    jz      .wait
    mov     dx, r8w
    mov     al, sil
    er_out_dx_al
    ret

er_fn er_serial_crlf
    push    rsi
    mov     sil, 0x0d           ; '\r'
    call    er_serial_putchar
    mov     sil, 0x0a           ; '\n'
    call    er_serial_putchar
    pop     rsi
    ret

; Error code for no-data condition
%define ERROR_NO_DATA 23

; ==================================================================
; er_serial_getchar — non-blocking serial read
; uint8_t er_serial_getchar(uint16_t port)
;
; rdi = COM port base (e.g. 0x3F8 for COM1)
; Returns: rax = byte read (if available), rdx = 0
;          rax = 0, rdx = ERROR_NO_DATA if nothing available
; ==================================================================
er_fn er_serial_getchar
    push    rdx

    mov     dx, di
    add     dx, UART_LSR
    er_in_al_dx
    test    al, LSR_DATA_READY
    jz      .no_data

    mov     dx, di
    add     dx, UART_RBR
    er_in_al_dx
    movzx   eax, al

    pop     rdx
    xor     edx, edx
    ret

.no_data:
    pop     rdx
    xor     eax, eax
    mov     edx, ERROR_NO_DATA
    ret
