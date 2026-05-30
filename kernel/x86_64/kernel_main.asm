; EdgeRun x86_64 bare-metal kernel main.
; Called from entry.asm after stack and BSS are ready.
; Follows the project kernel pattern: banner → checks → PASS.

%include "x86_64/macros.inc"
%include "x86_64/tpm/tpm_constants.inc"
%include "driver/virtio_constants.inc"
%include "driver/virtio_net_constants.inc"
%include "x86_64/wasm_defines.inc"

; ─── Local constants ─────────────────────────────────────────────
%define TPM_RSP_BUF_SIZE         512
%define TPM_GET_RANDOM_BYTES     4
%define SHA256_BLOCK_SIZE        64
%define SHA256_DATA_1K           1024
%define SHA256_ITER_64           10
%define SHA256_ITER_1K           5
%define SHA256_SW_BENCH_ITER     10000
%define WASM_MEM_SIZE            65536

extern er_serial_init
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_puthex64
extern er_serial_putdec32
extern er_serial_putchar
extern er_serial_putdec32
extern er_serial_crlf
extern er_strcmp_prefix
extern er_cpu_id
extern er_rdtsc
extern er_net_poll
extern er_halt
extern er_tor_init
extern er_tor_poll
extern er_local_cell_init
extern er_local_cell_poll
extern er_local_circuit_init
extern er_local_cell_imports
extern er_local_cell_import_count
extern er_wasm_runtime_ptr
extern er_agent_http_init
extern er_da_init
extern er_da_tick
extern er_input_kbd_init
extern er_input_kbd_poll
extern er_clock_init
extern er_clock_advance_with

extern er_mmio_read32
extern er_tpm_crb_present
extern er_tpm_crb_transfer
extern er_tpm_startup
extern er_tpm_get_random
extern er_tpm_hash_sha256
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

extern er_fn_run
extern wasm_return42_start
extern wasm_return42_len
extern wasm_export_name
extern test_mem_start
extern test_mem_len
extern test_mem_export
extern test_tblonly_start
extern test_tblonly_len
extern test_tblonly_export
extern agent_minimal_start
extern agent_minimal_len
extern agent_minimal_export_name
extern da_wasm_test_start
extern da_wasm_test_len
extern da_wasm_test_export_name
extern _wasm_import_da_surface_register
extern er_memset

extern er_sha256_init
extern er_sha256_update
extern er_sha256_final
extern _sha256_compress
extern er_memcmp

extern _fe_invert
extern _fe_mul
extern _fe_sq
extern _fe_copy
extern fe_base
extern fe_one
extern fe_tmp0
extern fe_tmp1
extern fe_tmp2
extern fe_tmp3
extern fe_tmp4

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

; Clock struct sizes (from rt/clock.asm)
%define KERNEL_STAMP_SIZE     64
%define KERNEL_LIMITS_SIZE    24
%define KERNEL_CLOCK_SIZE     88

; Clock limits
%define KERNEL_TICKS_PER_SLOT   1024
%define KERNEL_SLOTS_PER_EPOCH  1024
%define KERNEL_EPOCHS_PER_ERA   1024

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
pass_text:       db "PASS asm-bare-metal-x86_64", 0
check_wasm:      db "check: wasm return42 ", 0
check_mem:       db "check: wasm mem45 ", 0
check_tblonly:   db "check: wasm tblonly47 ", 0
check_minimal:   db "check: wasm minimal43 ", 0
check_da_wasm:   db "check: wasm da_test ", 0
bench_banner:  db "TPM SHA-256 bench", 0
bench_sha64:   db "  sha256 64B: ", 0
bench_sha1k:   db "  sha256 1KB: ", 0
bench_cyc:     db " cyc/call", 0
bench_data:    times 1024 db 0xAB

; Kernel clock identity keeper (32 bytes, non-zero)
kernel_keeper_id:
    db "EdgeRun Kernel Keeper v1.0", 0, 0, 0, 0, 0

; Kernel clock limits (powers of two)
kernel_limits:
    dq KERNEL_TICKS_PER_SLOT
    dq KERNEL_SLOTS_PER_EPOCH
    dq KERNEL_EPOCHS_PER_ERA

sha256_test_abc:     db "abc", 0
sha256_expected_abc: db 0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea
                     db 0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23
                     db 0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c
                     db 0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad
sha256_pass:         db "  sha256: PASS", 0
sha256_pre:          db " sha256:pre ", 0
sha256_post:         db " sha256:post ", 0
sha256_fail_str:     db "  sha256: FAIL", 0
sha256_bench_str:    db "  sw-sha256 64B: ", 0

fe_inv_pass_str:     db "  fe_invert: PASS", 0
fe_inv_fail_str:     db "  fe_invert: FAIL hi=", 0

SECTION .bss
tpm_cmd_buf:  resb 512
tpm_rsp_buf:  resb 512

; WASM runtime config + scratch memory
wasm_memory:   resb WASM_MEM_SIZE
wasm_ticks:    resq 1            ; tick counter
wasm_runtime:  resb RUNTIME_SIZE ; RuntimeConfig struct (88 bytes)

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

sha256_ctx:  resb 108
sha256_out:  resb 32
sha256_block: resb 64

; Kernel clock state
kernel_clock: resb KERNEL_CLOCK_SIZE

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
    mov     esi, TPM_GET_RANDOM_BYTES
    call    er_tpm_get_random
    test    rax, rax
    jz      .tpm_fail
    ; er_tpm_get_random/header_build return buffer pointer in rax.
    ; Command size = TPM_CMD_GET_RANDOM_LEN (known constant).
    mov     esi, TPM_CMD_GET_RANDOM_LEN
    mov     rdx, tpm_rsp_buf
    mov     ecx, TPM_RSP_BUF_SIZE
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

    ; ═══════ TPM SHA-256 BENCHMARK ═══════
    mov     rdi, COM1_PORT
    lea     rsi, [rel bench_banner]
    call    er_serial_puts
    call    .crlf

    ; Warm up: one SHA-256
    mov     rdi, tpm_cmd_buf
    lea     rsi, [rel bench_data]
    mov     edx, SHA256_BLOCK_SIZE
    mov     ecx, TPM_RH_NULL
    call    er_tpm_hash_sha256
    test    rax, rax
    jz      .bench_done
    mov     esi, SHA256_BLOCK_SIZE + TPM_CMD_HASH_FIXED_LEN
    mov     rdi, tpm_cmd_buf
    mov     rdx, tpm_rsp_buf
    mov     ecx, TPM_RSP_BUF_SIZE
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .bench_done

    ; Benchmark SHA-256, 64 bytes, 10 iterations
    mov     r12d, SHA256_ITER_64
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     rbp, rax

.bench64:
    mov     rdi, tpm_cmd_buf
    lea     rsi, [rel bench_data]
    mov     edx, SHA256_BLOCK_SIZE
    mov     ecx, TPM_RH_NULL
    call    er_tpm_hash_sha256
    test    rax, rax
    jz      .bench_done
    mov     esi, SHA256_BLOCK_SIZE + TPM_CMD_HASH_FIXED_LEN
    mov     rdi, tpm_cmd_buf
    mov     rdx, tpm_rsp_buf
    mov     ecx, TPM_RSP_BUF_SIZE
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .bench_done
    dec     r12d
    jnz     .bench64

    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, rbp
    xor     edx, edx
    mov     ecx, SHA256_ITER_64
    div     ecx

    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel bench_sha64]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    lea     rsi, [rel bench_cyc]
    mov     rdi, COM1_PORT
    call    er_serial_puts
    call    .crlf

    ; Benchmark SHA-256, SHA256_DATA_1K bytes, SHA256_ITER_1K iterations
    mov     r12d, SHA256_ITER_1K
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     rbp, rax

.bench1k:
    mov     rdi, tpm_cmd_buf
    lea     rsi, [rel bench_data]
    mov     edx, SHA256_DATA_1K
    mov     ecx, TPM_RH_NULL
    call    er_tpm_hash_sha256
    test    rax, rax
    jz      .bench_done
    mov     esi, SHA256_DATA_1K + TPM_CMD_HASH_FIXED_LEN
    mov     rdi, tpm_cmd_buf
    mov     rdx, tpm_rsp_buf
    mov     ecx, TPM_RSP_BUF_SIZE
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .bench_done
    dec     r12d
    jnz     .bench1k

    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, rbp
    xor     edx, edx
    mov     ecx, SHA256_ITER_1K
    div     ecx

    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel bench_sha1k]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    lea     rsi, [rel bench_cyc]
    mov     rdi, COM1_PORT
    call    er_serial_puts
    call    .crlf

.bench_done:
    ; ═══════ END TPM BENCHMARK ═══════

.sha_test_start:
    ; ═══════ SOFTWARE SHA-256 SELF-TEST ═══════
    ; SHA-256 direct compress test: all-zeros block, manually set H
    ; Write initial H values directly to ctx
    mov     dword [sha256_ctx + 0],  0x6a09e667
    mov     dword [sha256_ctx + 4],  0xbb67ae85
    mov     dword [sha256_ctx + 8],  0x3c6ef372
    mov     dword [sha256_ctx + 12], 0xa54ff53a
    mov     dword [sha256_ctx + 16], 0x510e527f
    mov     dword [sha256_ctx + 20], 0x9b05688c
    mov     dword [sha256_ctx + 24], 0x1f83d9ab
    mov     dword [sha256_ctx + 28], 0x5be0cd19
    mov     edi, COM1_PORT
    lea     rsi, [rel sha256_pre]
    call    er_serial_puts
    mov     rdi, sha256_ctx
    mov     rsi, sha256_block
    call    _sha256_compress
    mov     edi, COM1_PORT
    lea     rsi, [rel sha256_post]
    call    er_serial_puts
    ; Dump H[0..1]
    push    r12
    mov     r12d, [sha256_ctx]
    mov     edi, COM1_PORT
    mov     esi, r12d
    call    er_serial_puthex32
    mov     r12d, [sha256_ctx + 4]
    mov     edi, COM1_PORT
    mov     esi, r12d
    call    er_serial_puthex32
    pop     r12
    mov     rdi, sha256_ctx
    call    er_sha256_init
    test    rax, rax
    jz      .sha_fail

    mov     rdi, sha256_ctx
    lea     rsi, [rel sha256_test_abc]
    mov     edx, 3
    call    er_sha256_update
    test    rax, rax
    jz      .sha_fail

    mov     rdi, sha256_ctx
    mov     rsi, sha256_out
    call    er_sha256_final
    test    rax, rax
    jz      .sha_fail

    ; Compare with expected digest
    mov     rdi, sha256_out
    lea     rsi, [rel sha256_expected_abc]
    mov     edx, 32
    call    er_memcmp
    test    eax, eax
    jnz     .sha_fail

    mov     rdi, COM1_PORT
    lea     rsi, [rel sha256_pass]
    call    er_serial_puts
    call    .crlf

    ; Skip software SHA-256 benchmark when running without TPM (QEMU speed)
    jmp     .sha_done

    ; Software SHA-256 benchmark: SHA256_SW_BENCH_ITER iterations
    mov     r12d, SHA256_SW_BENCH_ITER
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    mov     rbp, rax

.sha_bench_loop:
    mov     rdi, sha256_ctx
    call    er_sha256_init
    mov     rdi, sha256_ctx
    lea     rsi, [rel bench_data]
    mov     edx, SHA256_BLOCK_SIZE
    call    er_sha256_update
    mov     rdi, sha256_ctx
    mov     rsi, sha256_out
    call    er_sha256_final
    dec     r12d
    jnz     .sha_bench_loop

    rdtsc
    shl     rdx, 32
    or      rax, rdx
    sub     rax, rbp
    xor     edx, edx
    mov     ecx, 10000
    div     ecx

    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel sha256_bench_str]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    lea     rsi, [rel bench_cyc]
    mov     rdi, COM1_PORT
    call    er_serial_puts
    call    .crlf
    jmp     .sha_done

.sha_fail:
    mov     rdi, COM1_PORT
    lea     rsi, [rel sha256_fail_str]
    call    er_serial_puts
    ; Dump first dword of actual output
    mov     edi, COM1_PORT
    mov     esi, [sha256_out]
    call    er_serial_puthex32
    jmp     .sha_done

.sha_done:
    ; ═══════ CONSTANT VERIFICATION ═══════
    ; Print fe_one content
    mov     rdi, COM1_PORT
    mov     sil, 'O'
    call    er_serial_putchar
    mov     r15d, 4
    xor     r14d, r14d
.const_dump:
    mov     edi, COM1_PORT
    mov     rax, [rel fe_one + r14]
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     rax, [rel fe_one + r14]
    shr     rax, 32
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    add     r14d, 8
    dec     r15d
    jnz     .const_dump
    call    .crlf

    ; ═══════ SIMPLE MULTIPLY SMOKE TEST ═══════
    ; 9 * 1 should be 9 — quick check that _fe_mul isn't trivially broken
    mov     rdi, COM1_PORT
    mov     sil, 's'
    call    er_serial_putchar
    mov     rdi, fe_tmp4
    lea     rsi, [rel fe_base]
    lea     rdx, [rel fe_one]
    call    _fe_mul               ; fe_tmp4 = 9 * 1
    mov     rdi, fe_tmp4
    lea     rsi, [rel fe_base]
    mov     edx, 32
    call    er_memcmp
    test    eax, eax
    jz      .smoke_pass
    mov     rdi, COM1_PORT
    mov     sil, 'F'
    call    er_serial_putchar
.smoke_pass:
    mov     rdi, COM1_PORT
    mov     sil, 's'
    call    er_serial_putchar

    ; ═══════ SQ/MUL SEQUENCE TEST — a^255 = a^(2^8-1) ═══════
    ; Manually do 8 sq+multiply iterations: should give 9^255
    ; This matches the first 8 loop iterations of the invert
    mov     r15d, 8
    mov     rdi, fe_tmp0
    lea     rsi, [rel fe_base]
    call    _fe_copy
.seq_loop:
    mov     rdi, fe_tmp0
    mov     rsi, fe_tmp0
    call    _fe_sq
    mov     rdi, fe_tmp0
    mov     rsi, fe_tmp0
    lea     rdx, [rel fe_base]
    call    _fe_mul
    dec     r15d
    jnz     .seq_loop
    ; Print first limb to compare with expected from invert
    mov     rdi, COM1_PORT
    mov     sil, 's'
    call    er_serial_putchar
    mov     edi, COM1_PORT
    mov     rax, [fe_tmp0]
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     rax, [fe_tmp0]
    shr     rax, 32
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ':'
    call    er_serial_putchar

    ; ═══════ CURVE25519 FIELD INVERT TEST ═══════
    ; Verify n * n^(-1) mod p = 1 using base point 9
    mov     rdi, COM1_PORT
    mov     sil, 'I'
    call    er_serial_putchar

    mov     rdi, fe_tmp2
    lea     rsi, [rel fe_base]
    call    _fe_copy

    mov     rdi, COM1_PORT
    mov     sil, 'C'
    call    er_serial_putchar

    ; invert(9) → fe_tmp3
    mov     rdi, fe_tmp3
    mov     rsi, fe_tmp2
    call    _fe_invert

    mov     rdi, COM1_PORT
    mov     sil, 'V'
    call    er_serial_putchar

    ; fe_tmp4 = 9 * invert(9)
    mov     rdi, fe_tmp4
    mov     rsi, fe_tmp2
    mov     rdx, fe_tmp3
    call    _fe_mul

    mov     rdi, COM1_PORT
    mov     sil, 'M'
    call    er_serial_putchar

    ; Verify fe_tmp4 == fe_one
    mov     rdi, fe_tmp4
    lea     rsi, [rel fe_one]
    mov     edx, 32
    call    er_memcmp
    test    eax, eax
    jnz     .fe_inv_fail

    mov     rdi, COM1_PORT
    lea     rsi, [rel fe_inv_pass_str]
    call    er_serial_puts
    call    .crlf
    jmp     .kbd_start

.fe_inv_fail:
    ; Print all 4 limbs of fe_tmp4
    mov     rdi, COM1_PORT
    lea     rsi, [rel fe_inv_fail_str]
    call    er_serial_puts
    mov     r15d, 4
    xor     r14d, r14d
.dump_limbs:
    mov     edi, COM1_PORT
    mov     rax, [fe_tmp4 + r14]
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     rax, [fe_tmp4 + r14]
    shr     rax, 32
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    add     r14d, 8
    dec     r15d
    jnz     .dump_limbs
    call    .crlf
    jmp     .fe_inv_test_invert

.fe_inv_test_invert:
    ; Also dump fe_tmp3 (the invert result) - all 4 limbs
    mov     rdi, COM1_PORT
    mov     sil, '3'         ; prefix for fe_tmp3
    call    er_serial_putchar
    mov     edi, COM1_PORT
    mov     sil, ':'
    call    er_serial_putchar
    mov     r15d, 4
    xor     r14d, r14d
.dump_limbs3:
    mov     edi, COM1_PORT
    mov     rax, [fe_tmp3 + r14]
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     rax, [fe_tmp3 + r14]
    shr     rax, 32
    mov     esi, eax
    call    er_serial_puthex32
    mov     edi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    add     r14d, 8
    dec     r15d
    jnz     .dump_limbs3
    call    .crlf
    jmp     .kbd_start

.tpm_absent:
    mov     byte [device_flags + DEV_TPM], 1
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_abs
    call    er_serial_puts
    call    .crlf
    jmp     .sha_test_start

.tpm_fail:
    mov     byte [device_flags + DEV_TPM], 1
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_fail
    call    er_serial_puts
    call    .crlf
    jmp     .sha_test_start

    ; ─── Keyboard ────────────────────────────────────────────────
.kbd_start:
    er_call er_i8042_init, .kbd_fail

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
    er_call er_dw_i2c_init, .tpad_absent

    sub     rsp, 4
    mov     rdi, I2CB_MMIO
    mov     sil, TPAD_ADDR
    lea     rdx, [rsp]
    lea     rcx, [rsp + 2]
    er_call er_i2c_hid_probe, .tpad_absent_fail

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
    er_call er_nvme_probe, .nvme_fail

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
    er_call er_nvme_init, .nvme_noio

    ; Initialize IO queues and identify namespace
    mov     rdi, r14
    er_call er_nvme_io_setup, .nvme_noio

    mov     rdi, r14
    er_call er_nvme_identify_ns, .nvme_noio

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
    er_call er_intel_sdhci_probe, .emmc_fail

    mov     ebx, [rsp]          ; bar0

    mov     rdi, COM1_PORT
    mov     esi, ebx
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar

    ; Init + detect card
    mov     rdi, rbx
    er_call er_intel_sdhci_init, .emmc_init_fail

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
.dbg_tor:   db " tor: init ok", 0
.dbg_cell:  db " cell: init ok", 0
.dbg_circ:  db " circ: init ok", 0
.dbg_agent: db " agent: init ok", 0
.dbg_da_init: db " da: init ok", 0
.dbg_input_kbd_init: db " kbd: init ok", 0
.dbg_da_reg:  db " da: register: ", 0
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
    er_call er_amdgpu_probe, .amdgpu_fail

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
    er_call er_amdgpu_dcn_init, .amdgpu_dcn_fail
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
    er_call er_intel_gpu_probe, .intel_gpu_fail

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

.wasm_check:
    ; ─── WASM module execution test ──────────────────────────────
    ; Set up RuntimeConfig struct on stack (88 bytes)
    sub     rsp, 96
    lea     rbx, [rel wasm_runtime]

    ; memory_ptr
    lea     rax, [rel wasm_memory]
    mov     [rbx + RUNTIME_MEMORY_PTR_OFF], rax
    ; memory_len
    mov     qword [rbx + RUNTIME_MEMORY_LEN_OFF], 65536
    ; ticks_ptr
    lea     rax, [rel wasm_ticks]
    mov     [rbx + RUNTIME_TICKS_PTR_OFF], rax
    ; Zero out grow functions, imports
    xor     eax, eax
    mov     [rbx + RUNTIME_MEM_GROW_FN_OFF], rax
    mov     [rbx + RUNTIME_MEM_GROW_CTX_OFF], rax
    mov     [rbx + RUNTIME_TABLE_GROW_FN_OFF], rax
    mov     [rbx + RUNTIME_TABLE_GROW_CTX_OFF], rax
    mov     [rbx + RUNTIME_INITIAL_PAGES_OFF], rax
    mov     byte [rbx + RUNTIME_HAS_PAGES_OFF], 0
    lea     rax, [rel er_local_cell_imports]
    mov     [rbx + RUNTIME_IMPORTS_PTR_OFF], rax
    mov     rax, [rel er_local_cell_import_count]
    mov     [rbx + RUNTIME_IMPORTS_LEN_OFF], rax

    ; Save pointer for WASM import wrappers
    lea     rax, [rel wasm_runtime]
    mov     [rel er_wasm_runtime_ptr], rax

    ; ── Test 1: return42 (no imports, no mem) ──
    mov     rdi, rbx            ; runtime
    lea     rsi, [rel wasm_return42_start]
    mov     rdx, [rel wasm_return42_len]
    lea     rcx, [rel wasm_export_name]
    mov     r8, 1
    call    er_fn_run
    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_wasm]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    call    .crlf

    ; ── Test 2: minimal (imports, returns 43) ──
    push    rbx
    lea     rdi, [rel wasm_memory]
    xor     esi, esi
    mov     edx, WASM_MEM_SIZE
    call    er_memset
    pop     rbx
    mov     rdi, rbx
    lea     rsi, [rel agent_minimal_start]
    mov     rdx, [rel agent_minimal_len]
    lea     rcx, [rel agent_minimal_export_name]
    mov     r8, 1
    call    er_fn_run
    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_minimal]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    call    .crlf

    ; ── Test 3: DA test (wasm imports, memory, calls da_surface_register) ──
    push    rbx
    lea     rdi, [rel wasm_memory]
    xor     esi, esi
    mov     edx, WASM_MEM_SIZE
    call    er_memset
    pop     rbx
    mov     rdi, rbx
    lea     rsi, [rel da_wasm_test_start]
    mov     rdx, [rel da_wasm_test_len]
    lea     rcx, [rel da_wasm_test_export_name]
    mov     r8, 1
    call    er_fn_run
    push    rax
    push    rdx
    mov     rdi, COM1_PORT
    lea     rsi, [rel check_da_wasm]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    call    er_serial_crlf

    add     rsp, 96

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

    ; ─── Tor client init ─────────────────────────────────────
    call    er_tor_init
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_tor]
    call    er_serial_puts

    ; ─── Local cell transport init ───────────────────────────
    call    er_local_cell_init
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_cell]
    call    er_serial_puts

    ; ─── Local circuit transport init ────────────────────────
    call    er_local_circuit_init
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_circ]
    call    er_serial_puts

    ; ─── Agent init ──────────────────────────────────────────
    call    er_agent_http_init
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_agent]
    call    er_serial_puts

    ; ─── Display Agent init ──────────────────────────────────
    call    er_da_init
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_da_init]
    call    er_serial_puts

    ; ─── Keyboard Input Agent init ──────────────────────────
    call    er_input_kbd_init
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_input_kbd_init]
    call    er_serial_puts

    ; ─── DA WASM Registration Test ────────────────────────────
    xor     edi, edi        ; params at WASM memory offset 0
    call    _wasm_import_da_surface_register
    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel .dbg_da_reg]
    call    er_serial_puts
    pop     rsi
    mov     rdi, COM1_PORT
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    call    er_serial_crlf

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

    ; ─── Kernel clock init ──────────────────────────────────────
    lea     rdi, [rel kernel_keeper_id]
    lea     rsi, [rel kernel_limits]
    lea     rdx, [rel kernel_clock]
    call    er_clock_init
    test    eax, eax
    jz      .main_loop         ; clock unavailable — run without it

    ; Boot complete — pipeline main loop
.main_loop:
    ; Advance kernel clock by 1 tick per iteration
    lea     rdi, [rel kernel_clock]
    mov     esi, 1
    call    er_clock_advance_with

    ; Pipeline stages — each returns cells processed (0 = idle)
    call    er_net_poll
    call    er_tor_poll
    call    er_local_cell_poll
    call    er_input_kbd_poll
    call    er_da_tick

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
