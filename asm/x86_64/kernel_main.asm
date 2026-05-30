; EdgeRun x86_64 bare-metal kernel main.
; Called from entry.asm after stack and BSS are ready.
; Follows the project kernel pattern: banner → checks → PASS.

%include "x86_64/macros.inc"
%include "x86_64/tpm_constants.inc"
%include "x86_64/virtio_constants.inc"
%include "x86_64/virtio_net_constants.inc"

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
extern er_net_poll
extern er_halt

extern er_mmio_read32
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
extern er_pci_read32
extern er_nvme_probe
extern er_nvme_init
extern er_nvme_print_info
extern er_nvme_io_setup
extern er_nvme_identify_ns
extern er_nvme_print_ns_info
extern er_xhci_probe
extern er_xhci_init
extern er_rtl8125_probe
extern er_rtl8125_init
extern er_virtio_net_init
extern er_net_init
extern er_net_register_nic
extern er_bt_uart_init
extern er_bt_reset
extern er_bt_fw_load
extern er_bt_le_set_scan_params
extern er_bt_le_scan_enable
extern er_bt_poll_adv
extern er_bt_print_adv

extern er_display_init
extern er_display_clear
extern er_display_puts
extern er_display_putchar

extern er_amdgpu_probe
extern er_amdgpu_print_info
extern er_amdgpu_init
extern er_amdgpu_dcn_init
extern er_amdgpu_dcn_dump_regs

extern er_intel_sdhci_probe
extern er_intel_sdhci_init

extern er_intel_gpu_probe
extern er_intel_gpu_detect_pipe
extern er_intel_gpu_print_pipe_info
extern er_intel_gpu_write_test_pattern

extern er_smn_read32
extern er_smn_write32
extern er_psp_mbox_nop
extern er_psp_mbox_hsti_query
extern er_rom_armor_detect
extern er_rom_armor_read

extern er_acpi_find_rsdp
extern er_acpi_parse_rsdp
extern er_acpi_find_table
extern er_acpi_parse_madt
extern er_acpi_parse_mcfg

; Device status flag offsets (for device_flags BSS array)
%define DEV_TPM      0
%define DEV_KBD      1
%define DEV_NVME     2
%define DEV_XHCI     3
%define DEV_VIRTIO   4
%define DEV_AMDGPU   5
%define DEV_EMMC     6
%define DEV_INTEL_GPU 7
%define DEV_COUNT    8

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
check_smn:     db "check: smn psp mbox cmd 0x", 0
check_hsti:    db "check: psp hsti 0x", 0
check_ra:      db "check: rom armor ", 0
check_ra_na:   db "n/a", 0
check_ra_2:    db "v2", 0
check_ra_3:    db "v3", 0
check_ra_flash:db " flash 0x", 0
check_ble:     db "check: ble ", 0
check_abs:     db "absent", 0
check_virtio_net: db "check: virtio_net ", 0
check_amdgpu:  db "check: amdgpu ", 0
check_amdgpu_abs: db "check: amdgpu absent", 0
check_amdgpu_dcn: db " DCN init: ", 0
check_sdhci:     db "check: sdhci ", 0
check_sdhci_abs: db "check: sdhci absent", 0
check_intel_gpu: db "check: intel_gpu ", 0
check_intel_gpu_abs: db "check: intel_gpu absent", 0
ok_text:       db "ok", 0
fail_text:     db "FAIL", 0
pass_text:     db "PASS asm-bare-metal-x86_64", 0

SECTION .bss
tpm_cmd_buf:  resb 512
tpm_rsp_buf:  resb 512

; Boot device status flags (0=unknown, 1=absent, 2=present)
device_flags:
    .tpm:      resb 1
    .kbd:      resb 1
    .nvme:     resb 1
    .xhci:     resb 1
    .virtio:   resb 1
    .amdgpu:   resb 1
    .emmc:     resb 1
    .intel_gpu: resb 1

%define VIRTIO_NET_STORAGE_size 4900
virtio_net_dev:      resb VIRTIO_NET_DEVICE_size
virtio_net_storage:  resb VIRTIO_NET_STORAGE_size
virtio_net_mac_str:  resb 18    ; "XX:XX:XX:XX:XX:XX\0"

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

    ; Initialize display (tries framebuffer first, falls back to VGA)
    call    er_display_init

    ; ─── TPM ────────────────────────────────────────────────────────
    ; Debug: test MMIO reads from UC 2MB page
    mov     rdi, COM1_PORT
    mov     sil, 'I'
    call    er_serial_putchar
    mov     edi, 0xFEC00000       ; IOAPIC ID register
    call    er_mmio_read32
    push    rax
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    pop     rax
    mov     edi, 0xFED40030       ; TPM CRB_INTF_ID
    call    er_mmio_read32
    push    rax
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    pop     rax
    call    er_tpm_crb_present
    test    eax, eax
    jz      .tpm_absent

    ; TPM present — send GetRandom to test the TPM CRB data path.
    mov     rdi, tpm_cmd_buf
    mov     esi, 4
    call    er_tpm_get_random
    test    rax, rax
    jz      .tpm_fail
    ; er_tpm_get_random/header_build return buffer pointer in rax.
    ; Command size = TPM_CMD_GET_RANDOM_LEN (known constant).
    mov     esi, TPM_CMD_GET_RANDOM_LEN
    mov     rdx, tpm_rsp_buf
    mov     ecx, 512
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .tpm_fail

    mov     rdi, tpm_rsp_buf
    mov     esi, eax
    call    er_tpm_response_success
    test    eax, eax
    jz      .tpm_fail

    mov     byte [device_flags + DEV_TPM], 2
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_pre
    call    er_serial_puts
    call    .crlf
    jmp     .kbd_start

.tpm_absent:
    mov     byte [device_flags + DEV_TPM], 1
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_abs
    call    er_serial_puts
    call    .crlf
    jmp     .kbd_start

.tpm_fail:
    mov     byte [device_flags + DEV_TPM], 1
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_fail
    call    er_serial_puts
    call    .crlf
    jmp     .kbd_start

    ; ─── Keyboard ────────────────────────────────────────────────
.kbd_start:
    call    er_i8042_init
    test    edx, edx
    jnz     .kbd_fail

    mov     rdi, COM1_PORT
    mov     rsi, check_kbd
    call    er_serial_puts
    call    .crlf
    mov     byte [device_flags + DEV_KBD], 2
    jmp     .ec_check

.kbd_fail:
    mov     byte [device_flags + DEV_KBD], 1
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

    ; Initialize controller (admin queues, enable)
    mov     rdi, r14
    call    er_nvme_init
    test    edx, edx
    jnz     .nvme_noio

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
    jmp     .emmc_check

.nvme_fail:
    add     rsp, 8
.nvme_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_nvme_abs]
    call    er_serial_puts
    call    .crlf
    add     rsp, 3

    ; ─── eMMC / SDHCI ─────────────────────────────────────────────
.emmc_check:
    sub     rsp, 3
    mov     rdi, 0x08           ; class = Base system
    mov     esi, 0x05           ; subclass = SD host controller
    mov     edx, 0x01           ; prog-if = SD host
    mov     rcx, rsp            ; &out_bus
    lea     r8, [rsp + 1]       ; &out_dev
    lea     r9, [rsp + 2]       ; &out_func
    call    er_pci_find_class
    test    eax, eax
    jz      .emmc_absent

    movzx   r12d, byte [rsp]     ; bus
    movzx   r13d, byte [rsp+1]   ; dev
    movzx   r14d, byte [rsp+2]   ; func

    ; Print "check: sdhci "
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_sdhci]
    call    er_serial_puts

    sub     rsp, 4
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, rsp            ; &out_bar0
    call    er_intel_sdhci_probe
    test    edx, edx
    jnz     .emmc_fail

    mov     ebx, [rsp]          ; bar0

    mov     rdi, COM1_PORT
    mov     esi, ebx
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar

    ; Init + detect card
    mov     rdi, rbx
    call    er_intel_sdhci_init
    test    edx, edx
    jnz     .emmc_init_fail

    mov     byte [device_flags + DEV_EMMC], 2
    mov     rdi, COM1_PORT
    lea     rsi, [rel ok_text]
    call    er_serial_puts
    call    .crlf
    add     rsp, 4
    add     rsp, 3
    jmp     .xhci_check

.emmc_init_fail:
    mov     byte [device_flags + DEV_EMMC], 1
    mov     rdi, COM1_PORT
    lea     rsi, [rel fail_text]
    call    er_serial_puts
    call    .crlf
    add     rsp, 4
    add     rsp, 3
    jmp     .xhci_check

.emmc_fail:
    add     rsp, 4
.emmc_absent:
    mov     byte [device_flags + DEV_EMMC], 1
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_sdhci_abs]
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
    mov     r15, rdi             ; save port in callee-saved r15
    movzx   esi, byte [rsp]      ; bus
    movzx   edx, byte [rsp + 1]  ; dev
    movzx   ecx, byte [rsp + 2]  ; func
    ; er_rtl8125_probe(bus, dev, func, port)
    ; need to shift args: rdi=bus, rsi=dev, rdx=func, rcx=port
    mov     r8, rdi              ; save port (temp)
    mov     rdi, rsi             ; bus
    mov     rsi, rdx             ; dev
    mov     rdx, rcx             ; func
    mov     rcx, r8              ; port
    call    er_rtl8125_probe
    add     rsp, 3
    test    eax, eax
    jnz     .bt_check            ; probe failed → try BT

    ; Init TX/RX rings
    mov     rdi, r15             ; port from saved register
    lea     rsi, [rel .net_init_str]
    call    er_serial_puts
    call    er_rtl8125_init
    test    eax, eax
    jnz     .net_init_fail
    mov     rdi, r15
    lea     rsi, [rel .ok_str]
    call    er_serial_puts
    call    .crlf
    jmp     .virtio_net_check    ; skip BT

.net_init_fail:
    mov     rdi, r15
    lea     rsi, [rel .fail_str]
    call    er_serial_puts
    call    .crlf

    jmp     .rtl_absent  ; fall through to BT check

.rtl_absent:
    jmp     .bt_check

.net_init_str: db " net init: ", 0
.ok_str:       db "ok", 0
.fail_str:     db "FAIL", 0

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
    test    eax, eax
    jnz     .bt_absent

    ; Reset controller to known state
    mov     rdi, COM2_PORT
    call    er_bt_reset
    test    eax, eax
    jnz     .bt_absent

    ; Set LE scan parameters
    mov     rdi, COM2_PORT
    call    er_bt_le_set_scan_params
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
    jmp     .virtio_net_check
.bt_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_abs]
    call    er_serial_puts
    call    .crlf

.virtio_net_check:
    ; ─── Virtio-net ────────────────────────────────────────────
    ; Require TPM for networking (hard requirement)
    cmp     byte [device_flags + DEV_TPM], 2
    jne     .virtio_net_absent
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_virtio_net]
    call    er_serial_puts

    lea     rdi, [rel virtio_net_dev]
    lea     rsi, [rel virtio_net_storage]
    call    er_virtio_net_init
    test    eax, eax
    jnz     .virtio_net_absent

    ; Print MAC
    lea     rbx, [rel virtio_net_dev + VIRTIO_NET_DEVICE.mac]
    mov     ecx, 6
.mac_loop:
    mov     rdi, COM1_PORT
    movzx   esi, byte [rbx]
    call    er_serial_puthex32
    inc     rbx
    dec     ecx
    jnz     .mac_loop

    ; Register virtio-net NIC and init TCP/IP stack
    mov     edi, 2                  ; type = virtio-net
    lea     rsi, [rel virtio_net_dev]
    lea     rdx, [rel virtio_net_storage]
    call    er_net_register_nic

    ; Init networking (static IP for QEMU user-mode: 10.0.2.15/24 gw=10.0.2.2)
    ; IP is network byte order: 0x0F02000A = 10.0.2.15
    mov     edi, 0x0F02000A        ; 10.0.2.15
    mov     esi, 0x00FFFFFF        ; 255.255.255.0
    mov     edx, 0x0202000A        ; 10.0.2.2
    lea     rcx, [rel virtio_net_dev + VIRTIO_NET_DEVICE.mac]
    call    er_net_init

    jmp     .virtio_net_done

.virtio_net_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_abs]
    call    er_serial_puts

.virtio_net_done:
    call    .crlf

    ; ─── AMDGPU ─────────────────────────────────────────────────
.amdgpu_check:
    sub     rsp, 3
    mov     rdi, 0x03           ; class = display
    mov     esi, 0x00           ; subclass = VGA
    mov     edx, 0x00           ; prog-if = VGA
    mov     rcx, rsp            ; &out_bus
    lea     r8, [rsp + 1]       ; &out_dev
    lea     r9, [rsp + 2]       ; &out_func
    call    er_pci_find_class
    test    eax, eax
    jz      .amdgpu_absent

    movzx   ebx, byte [rsp]
    movzx   r12d, byte [rsp + 1]
    movzx   r13d, byte [rsp + 2]

    ; Print header
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_amdgpu]
    call    er_serial_puts
    mov     rdi, COM1_PORT
    movzx   esi, bl
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

    sub     rsp, 16
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r13
    mov     rcx, rsp            ; &out_bar0
    lea     r8, [rsp + 8]       ; &out_bar2
    call    er_amdgpu_probe
    test    edx, edx
    jnz     .amdgpu_fail

    mov     r14, [rsp]          ; BAR0

    ; Print BAR0
    mov     rdi, COM1_PORT
    mov     esi, r14d
    call    er_serial_puthex32
    call    .crlf

    ; Init and print info
    mov     rdi, r14
    call    er_amdgpu_init
    mov     rdi, r14
    mov     rsi, COM1_PORT
    call    er_amdgpu_print_info
    call    .crlf

    ; DCN display init
    mov     r15, [rsp + 8]      ; BAR2 (framebuffer)
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_amdgpu_dcn]
    call    er_serial_puts
    mov     rdi, r14
    mov     rsi, r15
    call    er_amdgpu_dcn_init
    test    edx, edx
    jnz     .amdgpu_dcn_fail
    mov     rdi, COM1_PORT
    lea     rsi, [rel ok_text]
    call    er_serial_puts
    jmp     .amdgpu_dcn_dump
.amdgpu_dcn_fail:
    mov     rdi, COM1_PORT
    lea     rsi, [rel fail_text]
    call    er_serial_puts
.amdgpu_dcn_dump:
    mov     rdi, r14
    mov     rsi, COM1_PORT
    call    er_amdgpu_dcn_dump_regs

    add     rsp, 16
    add     rsp, 3
    jmp     .pass

.amdgpu_fail:
    add     rsp, 16
.amdgpu_absent:
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_amdgpu_abs]
    call    er_serial_puts
    call    .crlf
    add     rsp, 3

    ; ─── Intel GPU ───────────────────────────────────────────────
.intel_gpu_check:
    sub     rsp, 3
    mov     rdi, 0x03           ; class = display
    mov     esi, 0x00           ; subclass = VGA
    mov     edx, 0x00           ; prog-if = VGA
    mov     rcx, rsp            ; &out_bus
    lea     r8, [rsp + 1]       ; &out_dev
    lea     r9, [rsp + 2]       ; &out_func
    call    er_pci_find_class
    test    eax, eax
    jz      .intel_gpu_absent

    movzx   r12d, byte [rsp]
    movzx   r13d, byte [rsp + 1]
    movzx   r14d, byte [rsp + 2]

    ; Check vendor
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    xor     ecx, ecx
    call    er_pci_read32
    and     eax, 0xFFFF
    cmp     eax, 0x8086         ; Intel vendor
    jne     .intel_gpu_absent

    sub     rsp, 8
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     rcx, rsp            ; &out_bar0
    lea     r8, [rsp + 4]       ; &out_bar2
    call    er_intel_gpu_probe
    test    edx, edx
    jnz     .intel_gpu_fail

    mov     r15d, [rsp]         ; bar0
    mov     ebx, [rsp + 4]      ; bar2

    mov     rdi, COM1_PORT
    lea     rsi, [rel check_intel_gpu]
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, r15d
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    mov     rdi, COM1_PORT
    mov     esi, ebx
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    call    er_serial_crlf

    ; Detect pipe A status
    mov     rdi, r15
    xor     esi, esi             ; pipe A
    mov     rdx, COM1_PORT
    call    er_intel_gpu_print_pipe_info

    ; If pipe A is active, write test pattern
    mov     rdi, r15
    xor     esi, esi
    sub     rsp, 12
    lea     rdx, [rsp]
    lea     rcx, [rsp + 4]
    lea     r8, [rsp + 8]
    call    er_intel_gpu_detect_pipe
    test    eax, eax
    jnz     .intel_gpu_no_scanout

    ; Found active pipe — write test pattern
    mov     edx, [rsp + 4]       ; width
    mov     ecx, [rsp + 8]       ; height
    mov     edi, ebx             ; aperture
    mov     esi, [rsp]           ; scanout offset
    call    er_intel_gpu_write_test_pattern

    mov     byte [device_flags + DEV_INTEL_GPU], 2
    mov     rdi, COM1_PORT
    lea     rsi, [rel ok_text]
    call    er_serial_puts
    call    .crlf
    add     rsp, 12
    add     rsp, 8
    add     rsp, 3
    jmp     .pass

.intel_gpu_no_scanout:
    mov     byte [device_flags + DEV_INTEL_GPU], 1
    add     rsp, 12
    add     rsp, 8
    add     rsp, 3
    jmp     .pass

.intel_gpu_fail:
    add     rsp, 8
.intel_gpu_absent:
    mov     byte [device_flags + DEV_INTEL_GPU], 1
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_intel_gpu_abs]
    call    er_serial_puts
    call    .crlf
    add     rsp, 3

.pass:
    ; PASS — serial
    mov     rdi, COM1_PORT
    mov     rsi, pass_text
    call    er_serial_puts
    call    .crlf

    ; PASS — VGA/fb display
    lea     rdi, [rel pass_text]
    call    er_display_puts
    mov     rdi, 0x0A
    call    er_display_putchar

    ; ─── Boot Device Summary ─────────────────────────────────
    ; Show detected peripherals on display before entering shell
    call    er_display_clear
    lea     rdi, [rel .boot_header]
    call    er_display_puts

    ; TPM (from stored flag)
    lea     rdi, [rel .dev_tpm]
    call    er_display_puts
    cmp     byte [device_flags + DEV_TPM], 2
    je      .b_tpm_ok
    lea     rdi, [rel .stat_absent]
    jmp     .b_tpm_done
.b_tpm_ok:
    lea     rdi, [rel .stat_ok]
.b_tpm_done:
    call    er_display_puts
    call    .b_newline

    ; Keyboard (from stored flag)
    lea     rdi, [rel .dev_kbd]
    call    er_display_puts
    cmp     byte [device_flags + DEV_KBD], 2
    je      .b_kbd_ok
    lea     rdi, [rel .stat_absent]
    jmp     .b_kbd_done
.b_kbd_ok:
    lea     rdi, [rel .stat_ok]
.b_kbd_done:
    call    er_display_puts
    call    .b_newline

    ; NVMe (re-probe PCI)
    lea     rdi, [rel .dev_nvme]
    call    er_display_puts
    sub     rsp, 3
    mov     rdi, rsp
    lea     rsi, [rsp + 1]
    lea     rdx, [rsp + 2]
    call    er_pci_find_nvme
    add     rsp, 3
    test    eax, eax
    jz      .b_nvme_absent
    lea     rdi, [rel .stat_present]
    jmp     .b_nvme_done
.b_nvme_absent:
    lea     rdi, [rel .stat_absent]
.b_nvme_done:
    call    er_display_puts
    call    .b_newline

    ; xHCI (re-probe PCI class 0x0C/0x03/0x30)
    lea     rdi, [rel .dev_xhci]
    call    er_display_puts
    sub     rsp, 3
    mov     rdi, 0x0C
    mov     esi, 0x03
    mov     edx, 0x30
    mov     rcx, rsp
    lea     r8, [rsp + 1]
    lea     r9, [rsp + 2]
    call    er_pci_find_class
    add     rsp, 3
    test    eax, eax
    jz      .b_xhci_absent
    lea     rdi, [rel .stat_present]
    jmp     .b_xhci_done
.b_xhci_absent:
    lea     rdi, [rel .stat_absent]
.b_xhci_done:
    call    er_display_puts
    call    .b_newline

    ; Virtio-net (re-probe PCI class 0x02/0x00/0x00)
    lea     rdi, [rel .dev_virtio]
    call    er_display_puts
    sub     rsp, 3
    mov     rdi, 0x02
    mov     esi, 0x00
    mov     edx, 0x00
    mov     rcx, rsp
    lea     r8, [rsp + 1]
    lea     r9, [rsp + 2]
    call    er_pci_find_class
    add     rsp, 3
    test    eax, eax
    jz      .b_virtio_absent
    lea     rdi, [rel .stat_present]
    jmp     .b_virtio_done
.b_virtio_absent:
    lea     rdi, [rel .stat_absent]
.b_virtio_done:
    call    er_display_puts
    call    .b_newline

    ; AMDGPU (re-probe PCI class 0x03/0x00/0x00 + check vendor)
    lea     rdi, [rel .dev_amdgpu]
    call    er_display_puts
    sub     rsp, 3
    mov     rdi, 0x03
    mov     esi, 0x00
    mov     edx, 0x00
    mov     rcx, rsp
    lea     r8, [rsp + 1]
    lea     r9, [rsp + 2]
    call    er_pci_find_class
    movzx   ebx, byte [rsp]      ; save bus
    movzx   r12d, byte [rsp + 1] ; save dev
    movzx   r13d, byte [rsp + 2] ; save func
    add     rsp, 3
    test    eax, eax
    jz      .b_amdgpu_absent
    ; Found a display controller — check if it's AMD
    mov     rdi, rbx
    mov     rsi, r12
    mov     rdx, r13
    xor     ecx, ecx
    call    er_pci_read32
    and     eax, 0xFFFF
    cmp     eax, 0x1002       ; AMD vendor ID
    je      .b_amdgpu_present
.b_amdgpu_absent:
    lea     rdi, [rel .stat_absent]
    jmp     .b_amdgpu_done
.b_amdgpu_present:
    lea     rdi, [rel .stat_present]
.b_amdgpu_done:
    call    er_display_puts
    call    .b_newline

    ; eMMC (from stored flag)
    lea     rdi, [rel .dev_emmc]
    call    er_display_puts
    cmp     byte [device_flags + DEV_EMMC], 2
    je      .b_emmc_ok
    lea     rdi, [rel .stat_absent]
    jmp     .b_emmc_done
.b_emmc_ok:
    lea     rdi, [rel .stat_present]
.b_emmc_done:
    call    er_display_puts
    call    .b_newline

    ; Intel GPU (from stored flag)
    lea     rdi, [rel .dev_intel_gpu]
    call    er_display_puts
    cmp     byte [device_flags + DEV_INTEL_GPU], 2
    je      .b_intel_gpu_ok
    lea     rdi, [rel .stat_absent]
    jmp     .b_intel_gpu_done
.b_intel_gpu_ok:
    lea     rdi, [rel .stat_present]
.b_intel_gpu_done:
    call    er_display_puts
    call    .b_newline

    ; Footer
    lea     rdi, [rel .boot_footer]
    call    er_display_puts

    ; Boot complete — main polling loop
.main_loop:
    call    er_net_poll
    ; Future: call er_tcp_poll, ui_shell_tick, etc.
    ; Yield to give other subsystems time
    mov     ecx, 100000
.delay:
    dec     ecx
    jnz     .delay
    jmp     .main_loop

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; Boot summary strings
.b_newline:
    mov     rdi, 0x0A
    jmp     er_display_putchar
.boot_header:
    db "Boot Device Detection", 0x0A, 0

.dev_tpm:    db "  TPM:         ", 0
.dev_kbd:    db "  Keyboard:    ", 0
.dev_nvme:   db "  NVMe:        ", 0
.dev_xhci:   db "  USB (xHCI):  ", 0
.dev_virtio: db "  Virtio-net:  ", 0
.dev_amdgpu: db "  AMD GPU:     ", 0
.dev_emmc:   db "  eMMC:        ", 0
.dev_intel_gpu: db "  Intel GPU:   ", 0
.stat_ok:    db "ok", 0x0A, 0
.stat_present: db "present", 0x0A, 0
.stat_absent: db "absent", 0x0A, 0
.boot_footer: db 0x0A, "Entering shell...", 0x0A, 0

.crlf:
    mov     rdi, COM1_PORT
    jmp     er_serial_crlf
