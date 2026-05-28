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
extern er_pci_find_class
extern er_nvme_probe
extern er_nvme_print_info
extern er_nvme_io_setup
extern er_nvme_identify_ns
extern er_nvme_print_ns_info
extern er_xhci_probe
extern er_xhci_init
extern er_rtl8125_probe
extern er_bt_uart_init
extern er_bt_reset
extern er_bt_fw_load
extern er_bt_le_set_scan_params
extern er_bt_le_scan_enable
extern er_bt_poll_adv
extern er_bt_print_adv

extern er_display_init
extern er_display_puts
extern er_display_putchar

extern er_acpi_find_rsdp
extern er_acpi_parse_rsdp
extern er_acpi_find_table
extern er_acpi_parse_madt
extern er_acpi_parse_mcfg

; QEMU debugcon port and ISA debugcon device registers
%define COM1_PORT      0x3f8
%define COM2_PORT      0x2f8
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
check_display: db "check: display vga text 80x25", 0
check_acpi:    db "check: acpi rsdp 0x", 0
check_rsdt:    db "check: acpi rsdt 0x", 0
check_xsdt:    db "check: acpi xsdt ", 0
check_madt:    db "check: acpi madt lapic 0x", 0
check_ioapic:  db " ioapic 0x", 0
check_mcfg:    db "check: acpi mcfg ecam 0x", 0
check_bus:     db " bus ", 0
check_acpi_abs:db "check: acpi absent", 0
check_ble:     db "check: ble ", 0
check_abs:     db "absent", 0
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

    ; Initialize VGA text-mode display
    call    er_display_init
    mov     rdi, COM1_PORT
    mov     rsi, check_display
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
    test    edx, edx
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

    ; Initialize IO queues and identify namespace
    mov     rdi, r14
    call    er_nvme_io_setup
    test    edx, edx
    jnz     .nvme_noio

    mov     rdi, r14
    call    er_nvme_identify_ns
    test    edx, edx
    jnz     .nvme_noio

    mov     rdi, COM1_PORT
    call    er_nvme_print_ns_info

.nvme_noio:
    add     rsp, 8
    add     rsp, 3
    jmp     .xhci_check

.nvme_fail:
    add     rsp, 8
.nvme_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_nvme_abs]
    call    er_serial_puts
    call    .crlf
    add     rsp, 3

    ; ─── xHCI USB ─────────────────────────────────────────────────
.xhci_check:
    sub     rsp, 3
    mov     rdi, 0x0C
    mov     esi, 0x03
    mov     edx, 0x30
    mov     rcx, rsp
    lea     r8, [rsp + 1]
    lea     r9, [rsp + 2]
    call    er_pci_find_class
    test    eax, eax
    jz      .xhci_absent

    movzx   r12d, byte [rsp]     ; bus
    movzx   r13d, byte [rsp+1]   ; dev
    movzx   r14d, byte [rsp+2]   ; func

    mov     rdi, COM1_PORT
    mov     esi, r12d
    mov     edx, r13d
    mov     ecx, r14d
    call    er_xhci_probe

    mov     rdi, COM1_PORT
    mov     esi, r12d
    mov     edx, r13d
    mov     ecx, r14d
    xor     r8d, r8d
    call    er_xhci_init
    add     rsp, 3
    jmp     .acpi_check

.xhci_absent:
    add     rsp, 3

    ; ─── ACPI ───────────────────────────────────────────────────────
    ; Stack: [rsdp@0]=8, [rsdt@8]=8, [xsdt@16]=8, [rev@24]=1, [tmp@28]=4
    ;        [madt@32]=8, [lapic@40]=4, [ioapic@44]=4, [gsibase@48]=4
    ; Total: 56 bytes (but we only push 32 + use dynamic for the rest)
.acpi_check:
    sub     rsp, 56
    mov     rdi, rsp            ; &rsdp_addr
    call    er_acpi_find_rsdp
    test    eax, eax
    jz      .acpi_absent

    mov     rdi, COM1_PORT
    mov     rsi, check_acpi
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, [rsp]          ; rsdp_addr lo 32
    call    er_serial_puthex32
    call    .crlf

    mov     rdi, [rsp]          ; rsdp_addr
    lea     rsi, [rsp + 8]      ; &rsdt_addr
    lea     rdx, [rsp + 16]     ; &xsdt_addr
    lea     rcx, [rsp + 24]     ; &revision
    call    er_acpi_parse_rsdp
    test    eax, eax
    jz      .acpi_absent

    mov     rdi, COM1_PORT
    mov     rsi, check_rsdt
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, [rsp + 8]      ; rsdt_addr lo 32
    call    er_serial_puthex32
    call    .crlf

    ; Find MADT
    lea     rcx, [rsp + 32]     ; &madt_addr
    mov     rdi, [rsp + 8]      ; rsdt_addr
    mov     rsi, [rsp + 16]     ; xsdt_addr
    mov     edx, 0x43495041     ; "APIC"
    call    er_acpi_find_table
    test    eax, eax
    jz      .skip_madt

    ; Parse MADT
    mov     rdi, [rsp + 32]     ; madt_ptr
    mov     esi, [rdi + 4]      ; SDT_LENGTH
    lea     rdx, [rsp + 40]     ; &lapic_addr
    lea     rcx, [rsp + 44]     ; &ioapic_addr
    lea     r8,  [rsp + 48]     ; &ioapic_gsi
    call    er_acpi_parse_madt

    mov     rdi, COM1_PORT
    mov     rsi, check_madt
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, [rsp + 40]     ; lapic_addr
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     rsi, check_ioapic
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, [rsp + 44]     ; ioapic_addr
    call    er_serial_puthex32
    call    .crlf

.skip_madt:
    ; Find MCFG — rsdt_addr still at [rsp+8], xsdt at [rsp+16]
    lea     rcx, [rsp + 32]     ; &mcfg_addr (reuse madt slot)
    mov     rdi, [rsp + 8]
    mov     rsi, [rsp + 16]
    mov     edx, 0x4746434d     ; "MCFG"
    call    er_acpi_find_table
    test    eax, eax
    jz      .acpi_done

    mov     rdi, COM1_PORT
    mov     rsi, check_mcfg
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, [rsp + 32]     ; ecam base lo 32
    call    er_serial_puthex32
    call    .crlf
    jmp     .acpi_done

.acpi_absent:
    mov     rdi, COM1_PORT
    mov     rsi, check_acpi_abs
    call    er_serial_puts
    call    .crlf

.acpi_done:
    add     rsp, 56

    ; ─── RTL8125 Ethernet ─────────────────────────────────────────
    sub     rsp, 3
    mov     rdi, 0x02
    mov     esi, 0x00
    mov     edx, 0x00
    mov     rcx, rsp
    lea     r8, [rsp + 1]
    lea     r9, [rsp + 2]
    call    er_pci_find_class
    test    eax, eax
    jz      .rtl_absent

    mov     rdi, COM1_PORT
    movzx   esi, byte [rsp]      ; bus
    movzx   edx, byte [rsp + 1]  ; dev
    movzx   ecx, byte [rsp + 2]  ; func
    ; er_rtl8125_probe(bus, dev, func, port)
    ; need to shift args: rdi=bus, rsi=dev, rdx=func, rcx=port
    mov     r8, rdi              ; save port
    mov     rdi, rsi             ; bus
    mov     rsi, rdx             ; dev
    mov     rdx, rcx             ; func
    mov     rcx, r8              ; port
    call    er_rtl8125_probe
    add     rsp, 3
    test    eax, eax
    jz      .pass                ; success → skip BT
    jmp     .bt_check            ; probe failed → try BT


.rtl_absent:
    add     rsp, 3

.bt_check:
    ; ─── Bluetooth LE (UART HCI on COM2) ──────────────────────────
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_ble]
    call    er_serial_puts

    ; Init COM2 UART for BT HCI
    mov     rdi, COM2_PORT
    mov     rsi, BAUD_115200
    call    er_serial_init

    ; Try to load firmware / verify HCI is alive
    mov     rdi, COM2_PORT
    call    er_bt_fw_load
    push    rax
    mov     rdi, COM1_PORT
    pop     rsi
    push    rsi
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, 0x20
    call    er_serial_putchar
    pop     rax
    test    eax, eax
    jnz     .bt_absent

    ; Reset controller to known state
    mov     rdi, COM2_PORT
    call    er_bt_reset
    push    rax
    mov     rdi, COM1_PORT
    pop     rsi
    push    rsi
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, 0x20
    call    er_serial_putchar
    pop     rax
    test    eax, eax
    jnz     .bt_absent

    ; Set LE scan parameters
    mov     rdi, COM2_PORT
    call    er_bt_le_set_scan_params
    push    rax
    mov     rdi, COM1_PORT
    pop     rsi
    push    rsi
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, 0x20
    call    er_serial_putchar
    pop     rax
    test    eax, eax
    jnz     .bt_absent

    ; Enable scanning
    mov     rdi, COM2_PORT
    mov     sil, 1
    call    er_bt_le_scan_enable
    test    eax, eax
    jnz     .bt_absent

    ; Poll for advertisements (up to ~3 seconds)
    mov     r12, 300
.bt_poll:
    mov     rdi, COM2_PORT
    call    er_bt_poll_adv
    test    eax, eax
    jz      .bt_poll_next
    ; Got advertisement — print it
    mov     rdi, COM2_PORT
    mov     rsi, COM1_PORT
    call    er_bt_print_adv
.bt_poll_next:
    dec     r12
    jnz     .bt_poll

    ; Stop scanning
    mov     rdi, COM2_PORT
    xor     esi, esi
    call    er_bt_le_scan_enable

    ; Print CRLF before PASS
    mov     rdi, COM1_PORT
    call    er_serial_crlf
    jmp     .pass
.bt_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_abs]
    call    er_serial_puts
    call    .crlf

.pass:
    ; PASS — serial
    mov     rdi, COM1_PORT
    mov     rsi, pass_text
    call    er_serial_puts
    call    .crlf

    ; PASS — VGA display
    lea     rdi, [rel pass_text]
    call    er_display_puts
    mov     rdi, 0x0A
    call    er_display_putchar

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.crlf:
    mov     rdi, COM1_PORT
    jmp     er_serial_crlf
