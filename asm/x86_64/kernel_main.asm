; EdgeRun x86_64 bare-metal kernel main.
; Called from entry.asm after stack and BSS are ready.
; Follows the project kernel pattern: banner → checks → PASS.

%include "x86_64/macros.inc"
%include "x86_64/tpm_constants.inc"

extern er_serial_init
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putdec32
extern er_serial_putchar
extern er_serial_putdec32
extern er_serial_crlf
extern er_strcmp_prefix
extern er_cpu_id
extern er_rdtsc
extern er_halt

extern er_tpm_crb_present
extern er_tpm_crb_transfer
extern er_tpm_startup
extern er_tpm_get_random
extern er_tpm_get_capability
extern er_tpm_response_success
extern er_tpm_has_algorithm

extern er_cmos_read_time
extern er_cmos_read_date
extern er_i8042_init
extern er_i8042_read_scancode
extern er_i8042_scancode_to_ascii
extern er_cros_ec_probe
extern er_cros_ec_read_battery

extern er_dw_i2c_probe
extern er_dw_i2c_init
extern er_i2c_hid_probe

extern er_pci_find_nvme
extern er_nvme_probe
extern er_nvme_print_info

; QEMU debugcon port and ISA debugcon device registers
%define COM1_PORT      0x3f8
%define BAUD_115200    1

; I2C / touchpad constants
%define I2CB_MMIO      0xFEDC3000
%define TPAD_ADDR      0x2C

SECTION .data
banner:        db "EdgeRun x86_64 bare metal", 0
check_cpu:     db "check: cpuid signature 0x", 0
check_rdtsc:   db "check: rdtsc ok", 0
check_serial:  db "check: serial 0x", 0
check_tpm_abs: db "check: tpm absent", 0
check_tpm_pre: db "check: tpm present", 0
check_tpm_sta: db "check: tpm startup ok", 0
check_tpm_rnd: db "check: tpm random ok", 0
check_tpm_sh2: db "check: tpm alg sha256 ok", 0
check_tpm_ecc: db "check: tpm alg ecc ok", 0
check_tpm_fail:db "check: tpm failed", 0
check_cmos:    db "check: cmos rtc ", 0
check_kbd:     db "check: i8042 keyboard ok", 0
check_kbd_fail:db "check: i8042 keyboard fail", 0
check_ec:      db "check: ec ", 0
check_ec_bat:  db "check: ec battery ", 0
check_tpad:    db "check: touchpad ", 0
check_tpad_abs:db "absent", 0
check_nvme:    db "check: nvme ", 0
check_nvme_abs:db "check: nvme absent", 0
pass_text:     db "PASS asm-bare-metal-x86_64", 0

SECTION .bss
tpm_cmd_buf:  resb 512
tpm_rsp_buf:  resb 512

SECTION .text

; Helper: save regs for TPM operations
%macro tpm_op_save 0
    push    r12
    push    r13
    push    r14
%endmacro

%macro tpm_op_restore 0
    pop     r14
    pop     r13
    pop     r12
%endmacro

er_fn er_kernel_main
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; Initialize serial COM1 at 115200 baud
    mov     rdi, COM1_PORT
    mov     rsi, BAUD_115200
    call    er_serial_init

    ; Print banner
    mov     rdi, COM1_PORT
    mov     rsi, banner
    call    er_serial_puts
    call    .crlf

    ; check: cpuid signature
    mov     rdi, COM1_PORT
    mov     rsi, check_cpu
    call    er_serial_puts
    call    er_cpu_id
    mov     r12, rax
    mov     rdi, COM1_PORT
    mov     rsi, r12
    call    er_serial_puthex32
    call    .crlf

    ; check: serial
    mov     rdi, COM1_PORT
    mov     rsi, check_serial
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     rsi, COM1_PORT
    call    er_serial_puthex32
    call    .crlf

    ; check: rdtsc
    call    er_rdtsc
    mov     rdi, COM1_PORT
    mov     rsi, check_rdtsc
    call    er_serial_puts
    call    .crlf

    ; ─── CMOS/RTC ────────────────────────────────────────────────
    sub     rsp, 16
    lea     rdi, [rsp]          ; &hours
    lea     rsi, [rsp + 2]      ; &minutes
    lea     rdx, [rsp + 4]      ; &seconds
    call    er_cmos_read_time

    mov     rdi, COM1_PORT
    mov     rsi, check_cmos
    call    er_serial_puts
    mov     rdi, COM1_PORT
    movzx   esi, word [rsp]
    call    er_serial_putdec32
    mov     sil, ':'
    call    er_serial_putchar
    mov     rdi, COM1_PORT
    movzx   esi, word [rsp + 2]
    call    er_serial_putdec32
    mov     sil, ':'
    call    er_serial_putchar
    mov     rdi, COM1_PORT
    movzx   esi, word [rsp + 4]
    call    er_serial_putdec32
    add     rsp, 16
    call    .crlf

    ; ─── Keyboard ────────────────────────────────────────────────
    call    er_i8042_init
    test    edx, edx
    jnz     .kbd_fail

    mov     rdi, COM1_PORT
    mov     rsi, check_kbd
    call    er_serial_puts
    call    .crlf
    jmp     .ec_check

.kbd_fail:
    mov     rdi, COM1_PORT
    mov     rsi, check_kbd_fail
    call    er_serial_puts
    call    .crlf

    ; ─── EC ──────────────────────────────────────────────────────
.ec_check:
    mov     r12, COM1_PORT       ; save port in callee-saved reg
    mov     rdi, r12
    mov     rsi, check_ec
    call    er_serial_puts

    call    er_cros_ec_probe
    test    eax, eax
    jz      .ec_absent

    mov     rdi, r12
    mov     sil, 'p'
    call    er_serial_putchar
    mov     rdi, r12
    mov     sil, ' '
    call    er_serial_putchar
    mov     rdi, r12
    mov     rsi, check_ec_bat
    call    er_serial_puts

    call    er_cros_ec_read_battery
    mov     r13d, eax

    mov     rdi, r12
    mov     esi, r13d
    call    er_serial_putdec32
    mov     rdi, r12
    mov     sil, '%'
    call    er_serial_putchar
    call    .crlf
    jmp     .nvme_check

.ec_absent:
    mov     rdi, r12
    mov     sil, 'a'
    call    er_serial_putchar
    mov     rdi, r12
    mov     sil, 'b'
    call    er_serial_putchar
    mov     rdi, r12
    mov     sil, 's'
    call    er_serial_putchar
    mov     rdi, r12
    mov     sil, 'e'
    call    er_serial_putchar
    mov     rdi, r12
    mov     sil, 'n'
    call    er_serial_putchar
    mov     rdi, r12
    mov     sil, 't'
    call    er_serial_putchar
    call    .crlf

    ; ─── Touchpad ──────────────────────────────────────────────
.tpad_check:
    mov     r14, COM1_PORT
    mov     rdi, r14
    mov     rsi, check_tpad
    call    er_serial_puts

    mov     rdi, I2CB_MMIO
    call    er_dw_i2c_probe
    test    eax, eax
    jz      .tpad_absent

    mov     rdi, I2CB_MMIO
    mov     esi, 400
    call    er_dw_i2c_init
    test    edx, edx
    jnz     .tpad_absent

    sub     rsp, 4
    mov     rdi, I2CB_MMIO
    mov     sil, TPAD_ADDR
    lea     rdx, [rsp]
    lea     rcx, [rsp + 2]
    call    er_i2c_hid_probe
    test    edx, edx
    jnz     .tpad_absent_fail

    movzx   esi, word [rsp]
    mov     rdi, r14
    call    er_serial_puthex32
    mov     rdi, r14
    mov     sil, ':'
    call    er_serial_putchar
    movzx   esi, word [rsp + 2]
    mov     rdi, r14
    call    er_serial_puthex32
    add     rsp, 4
    call    .crlf
    jmp     .nvme_check

.tpad_absent_fail:
    add     rsp, 4
.tpad_absent:
    mov     rdi, r14
    mov     rsi, check_tpad_abs
    call    er_serial_puts
    call    .crlf

    ; ─── NVMe ──────────────────────────────────────────────────────
.nvme_check:
    ; Find NVMe controller on bus 0
    sub     rsp, 3
    mov     rdi, rsp
    lea     rsi, [rsp + 1]
    lea     rdx, [rsp + 2]
    call    er_pci_find_nvme
    test    eax, eax
    jz      .nvme_absent

    movzx   ebx, byte [rsp]
    movzx   r12d, byte [rsp + 1]
    movzx   r13d, byte [rsp + 2]

    mov     rdi, COM1_PORT
    lea     rsi, [rel check_nvme]
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, ebx
    call    er_serial_putdec32
    mov     rdi, COM1_PORT
    mov     sil, ':'
    call    er_serial_putchar
    mov     rdi, COM1_PORT
    mov     esi, r12d
    call    er_serial_putdec32
    mov     rdi, COM1_PORT
    mov     sil, '.'
    call    er_serial_putchar
    mov     rdi, COM1_PORT
    mov     esi, r13d
    call    er_serial_putdec32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar

    sub     rsp, 8
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r13
    mov     rcx, rsp
    call    er_nvme_probe
    test    eax, eax
    jnz     .nvme_fail

    mov     rax, [rsp]
    mov     r14, rax

    mov     rdi, COM1_PORT
    mov     esi, r14d
    call    er_serial_puthex32
    call    .crlf

    mov     rdi, r14
    mov     rsi, COM1_PORT
    call    er_nvme_print_info
    add     rsp, 8
    add     rsp, 3
    jmp     .pass

.nvme_fail:
    add     rsp, 8
.nvme_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_nvme_abs]
    call    er_serial_puts
    call    .crlf
    add     rsp, 3

.pass:
    ; PASS
    mov     rdi, COM1_PORT
    mov     rsi, pass_text
    call    er_serial_puts
    call    .crlf

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.crlf:
    mov     rdi, COM1_PORT
    jmp     er_serial_crlf
