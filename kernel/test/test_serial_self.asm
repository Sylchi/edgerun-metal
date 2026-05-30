; EdgeRun serial driver self-hosted test.
; Provides buffer-backed er_in_al_dx / er_out_dx_al and _start,
; linking against serial.o (which declares these functions extern).

; -------------------------------------------------------------------
; Test I/O buffer
; -------------------------------------------------------------------
section .bss
tx_buf:         resb 4096
tx_count:       resq 1

; -------------------------------------------------------------------
; Buffer-backed I/O — provides symbols that serial.o references as extern
; -------------------------------------------------------------------
SECTION .text
global er_in_al_dx
er_in_al_dx:
    mov     al, 0x60        ; LSR_THR_EMPTY | LSR_DATA_READY
    ret

global er_out_dx_al
er_out_dx_al:
    push    rsi
    push    rdi
    push    rcx
    lea     rsi, [tx_buf]
    mov     rdi, [tx_count]
    add     rsi, rdi
    mov     [rsi], al
    inc     rdi
    mov     [tx_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
    ret

; -------------------------------------------------------------------
; Extern serial functions (defined in serial.o)
; -------------------------------------------------------------------
extern er_serial_putchar
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_puthex64
extern er_serial_putdec32
extern er_serial_crlf

; -------------------------------------------------------------------
; Extern runtime helpers
; -------------------------------------------------------------------
extern er_strcmp
extern er_strlen
extern er_memset

; -------------------------------------------------------------------
; Test macro
; -------------------------------------------------------------------
%macro TEST_STR 3
    mov     rdi, %1
    mov     rsi, %2
    call    er_strcmp
    test    eax, eax
    jnz     .fail_%3
    inc     qword [test_pass]
    jmp     .next_%3
.fail_%3:
    inc     qword [test_fail]
.next_%3:
    inc     qword [test_count]
%endmacro

section .data
test_pass:  dq 0
test_fail:  dq 0
test_count: dq 0

; -------------------------------------------------------------------
; Entry point
; -------------------------------------------------------------------
SECTION .text
global _start
_start:
    ; Reset buffer
    call    reset_buf

    ; Test putchar
    mov     rdi, 0x3f8
    mov     sil, 'H'
    call    er_serial_putchar
    mov     rdi, 0x3f8
    mov     sil, 'i'
    call    er_serial_putchar
    mov     rdi, 0x3f8
    mov     sil, '!'
    call    er_serial_putchar
    lea     rdi, [tx_buf]
    lea     rsi, [expected_hi]
    TEST_STR rdi, rsi, putchar

    ; Test puts
    call    reset_buf
    mov     rdi, 0x3f8
    lea     rsi, [hello_str]
    call    er_serial_puts
    lea     rdi, [tx_buf]
    lea     rsi, [expected_hello]
    TEST_STR rdi, rsi, puts

    ; Test crlf
    call    reset_buf
    mov     rdi, 0x3f8
    call    er_serial_crlf
    lea     rdi, [tx_buf]
    lea     rsi, [expected_crlf]
    TEST_STR rdi, rsi, crlf

    ; Test puts empty string
    call    reset_buf
    mov     rdi, 0x3f8
    lea     rsi, [empty_str]
    call    er_serial_puts
    cmp     qword [tx_count], 0
    jz      .empty_ok
    inc     qword [test_fail]
    jmp     .next_empty
.empty_ok:
    inc     qword [test_pass]
.next_empty:

    ; Test puthex32 zero
    call    reset_buf
    mov     rdi, 0x3f8
    xor     esi, esi
    call    er_serial_puthex32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h32_zero]
    TEST_STR rdi, rsi, hex32_zero

    ; Test puthex32 deadbeef
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 0xdeadbeef
    call    er_serial_puthex32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h32_dead]
    TEST_STR rdi, rsi, hex32_dead

    ; Test puthex32 all ones
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 0xffffffff
    call    er_serial_puthex32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h32_ff]
    TEST_STR rdi, rsi, hex32_ff

    ; Test puthex32 12345678
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 0x12345678
    call    er_serial_puthex32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h32_1234]
    TEST_STR rdi, rsi, hex32_1234

    ; Test puthex64 zero
    call    reset_buf
    mov     rdi, 0x3f8
    xor     esi, esi
    call    er_serial_puthex64
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h64_zero]
    TEST_STR rdi, rsi, hex64_zero

    ; Test puthex64 deadbeefcafebabe
    call    reset_buf
    mov     rdi, 0x3f8
    mov     rsi, 0xdeadbeefcafebabe
    call    er_serial_puthex64
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h64_dead]
    TEST_STR rdi, rsi, hex64_dead

    ; Test puthex64 all ones
    call    reset_buf
    mov     rdi, 0x3f8
    mov     rsi, -1
    call    er_serial_puthex64
    lea     rdi, [tx_buf]
    lea     rsi, [expected_h64_ff]
    TEST_STR rdi, rsi, hex64_ff

    ; Test putdec32 zero
    call    reset_buf
    mov     rdi, 0x3f8
    xor     esi, esi
    call    er_serial_putdec32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_d32_zero]
    TEST_STR rdi, rsi, dec32_zero

    ; Test putdec32 one
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 1
    call    er_serial_putdec32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_d32_one]
    TEST_STR rdi, rsi, dec32_one

    ; Test putdec32 42
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 42
    call    er_serial_putdec32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_d32_42]
    TEST_STR rdi, rsi, dec32_42

    ; Test putdec32 1234567890
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 1234567890
    call    er_serial_putdec32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_d32_large]
    TEST_STR rdi, rsi, dec32_large

    ; Test putdec32 max uint32
    call    reset_buf
    mov     rdi, 0x3f8
    mov     esi, 0xffffffff
    call    er_serial_putdec32
    lea     rdi, [tx_buf]
    lea     rsi, [expected_d32_max]
    TEST_STR rdi, rsi, dec32_max

    ; Report results
    mov     rax, [test_fail]
    test    rax, rax
    jnz     .fail
    xor     rdi, rdi
    mov     rax, 60
    syscall
.fail:
    mov     rdi, 1
    mov     rax, 60
    syscall

; -------------------------------------------------------------------
; reset_buf — zero tx_count and the buffer
; -------------------------------------------------------------------
reset_buf:
    mov     qword [tx_count], 0
    lea     rdi, [tx_buf]
    mov     esi, 0
    mov     rdx, 4096
    call    er_memset
    ret

; -------------------------------------------------------------------
; Expected strings
; -------------------------------------------------------------------
section .rodata
expected_hi:        db "Hi!", 0
hello_str:          db "Hello, World!", 0
expected_hello:     db "Hello, World!", 0
empty_str:          db 0
expected_crlf:      db 0x0d, 0x0a, 0
expected_h32_zero:  db "0x00000000", 0
expected_h32_dead:  db "0xdeadbeef", 0
expected_h32_ff:    db "0xffffffff", 0
expected_h32_1234:  db "0x12345678", 0
expected_h64_zero:  db "0x0000000000000000", 0
expected_h64_dead:  db "0xdeadbeefcafebabe", 0
expected_h64_ff:    db "0xffffffffffffffff", 0
expected_d32_zero:  db "0", 0
expected_d32_one:   db "1", 0
expected_d32_42:    db "42", 0
expected_d32_large: db "1234567890", 0
expected_d32_max:   db "4294967295", 0
