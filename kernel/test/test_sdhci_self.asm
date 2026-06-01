; EdgeRun Intel SDHCI command helper self-hosted test.
; Verifies command register construction and APP_CMD sequencing.

%include "test/test_macros.inc"
%include "driver/intel_sdhci_constants.inc"

extern _sdhci_send_cmd
extern _sdhci_send_app_cmd

TEST_DATA_TOTAL_PASSED_FAILED

SECTION .bss
arg_log:        resd 8
cmd_log:        resd 8
int_clear_log:  resd 8
arg_count:      resq 1
cmd_count:      resq 1
int_clear_count: resq 1
read_present_count: resq 1
read_int_count: resq 1

SECTION .text
global _start
_start:
    call    reset_logs

    mov     edi, TEST_BAR
    mov     esi, 0x12345678
    mov     edx, MMC_CMD17
    mov     ecx, 1
    xor     r8d, r8d
    call    _sdhci_send_cmd
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0
    ASSERT_QWORD [rel arg_count], 1
    ASSERT_QWORD [rel cmd_count], 1
    ASSERT_DWORD [rel arg_log], 0x12345678
    ASSERT_DWORD [rel cmd_log], ((MMC_CMD17 << SDHCI_CMD_INDEX_SHIFT) | SDHCI_CMD_CRC_CHECK | SDHCI_CMD_INDEX_CHECK | SDHCI_CMD_DATA)
    ASSERT_DWORD [rel int_clear_log], SDHCI_INT_CMD_COMPLETE

    call    reset_logs

    mov     edi, TEST_BAR
    mov     esi, 0x1234
    mov     edx, 0x40ff8000
    mov     ecx, MMC_ACMD41
    xor     r8d, r8d
    xor     r9d, r9d
    call    _sdhci_send_app_cmd
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0
    ASSERT_QWORD [rel arg_count], 2
    ASSERT_QWORD [rel cmd_count], 2
    ASSERT_DWORD [rel arg_log], 0x12340000
    ASSERT_DWORD [rel arg_log + 4], 0x40ff8000
    ASSERT_DWORD [rel cmd_log], ((MMC_CMD55 << SDHCI_CMD_INDEX_SHIFT) | SDHCI_CMD_CRC_CHECK | SDHCI_CMD_INDEX_CHECK)
    ASSERT_DWORD [rel cmd_log + 4], ((MMC_ACMD41 << SDHCI_CMD_INDEX_SHIFT) | SDHCI_CMD_CRC_CHECK | SDHCI_CMD_INDEX_CHECK)
    ASSERT_QWORD [rel int_clear_count], 2

    call    reset_logs

    mov     edi, TEST_BAR
    xor     esi, esi
    mov     edx, MMC_CMD2
    xor     ecx, ecx
    mov     r8d, 1
    call    _sdhci_send_cmd
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0
    ASSERT_DWORD [rel cmd_log], ((MMC_CMD2 << SDHCI_CMD_INDEX_SHIFT) | SDHCI_CMD_CRC_CHECK | SDHCI_CMD_INDEX_CHECK | SDHCI_CMD_RESP_LONG)

    TEST_EXIT_FAILED

reset_logs:
    mov     qword [rel arg_count], 0
    mov     qword [rel cmd_count], 0
    mov     qword [rel int_clear_count], 0
    mov     qword [rel read_present_count], 0
    mov     qword [rel read_int_count], 0
    ret

global er_mmio_read32
er_mmio_read32:
    mov     eax, edi
    sub     eax, TEST_BAR
    cmp     eax, SDHCI_PRESENT_STATE
    je      .present
    cmp     eax, SDHCI_INT_STATUS
    je      .int_status
    xor     eax, eax
    ret
.present:
    inc     qword [rel read_present_count]
    xor     eax, eax
    ret
.int_status:
    inc     qword [rel read_int_count]
    mov     eax, SDHCI_INT_CMD_COMPLETE
    ret

global er_mmio_write32
er_mmio_write32:
    mov     eax, edi
    sub     eax, TEST_BAR
    cmp     eax, SDHCI_ARGUMENT
    je      .arg
    cmp     eax, SDHCI_COMMAND
    je      .cmd
    cmp     eax, SDHCI_INT_STATUS
    je      .int_clear
    xor     eax, eax
    ret
.arg:
    mov     rax, [rel arg_count]
    mov     [rel arg_log + rax * 4], esi
    inc     qword [rel arg_count]
    xor     eax, eax
    ret
.cmd:
    mov     rax, [rel cmd_count]
    mov     [rel cmd_log + rax * 4], esi
    inc     qword [rel cmd_count]
    xor     eax, eax
    ret
.int_clear:
    mov     rax, [rel int_clear_count]
    mov     [rel int_clear_log + rax * 4], esi
    inc     qword [rel int_clear_count]
    xor     eax, eax
    ret

global er_pci_read32
er_pci_read32:
    xor     eax, eax
    ret

global er_pci_write32
er_pci_write32:
    xor     eax, eax
    ret

global er_serial_puts
global er_serial_puthex32
global er_serial_putdec32
global er_serial_putchar
global er_serial_crlf
er_serial_puts:
er_serial_puthex32:
er_serial_putdec32:
er_serial_putchar:
er_serial_crlf:
    ret

TEST_BAR equ 0x100000
