; EdgeRun NVMe IO command helper self-hosted test.
; Verifies command frame construction and the eax/rdx return contract.

%include "test/test_macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_nvme_read_blocks
extern er_nvme_write_blocks

TEST_DATA_TOTAL_PASSED_FAILED

SECTION .bss
data_buf:       resb 512
doorbell_count: resq 1
doorbell_value: resd 1

SECTION .text
global _start
_start:
    call    map_nvme_queue_page
    mov     rdi, NVME_IO_SQ
    ASSERT_MEM_ZERO 0, 4096
    mov     rdi, NVME_IO_CQ
    ASSERT_MEM_ZERO 0, 4096

    mov     dword [rel doorbell_value], 0
    mov     qword [rel doorbell_count], 0

    mov     edi, TEST_BAR
    mov     rsi, 0x1122334455667788
    lea     rdx, [rel data_buf]
    mov     ecx, 3
    call    er_nvme_read_blocks
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0
    ASSERT_DWORD [NVME_IO_SQ], 2
    ASSERT_DWORD [NVME_IO_SQ + 4], 1
    ASSERT_DWORD [NVME_IO_SQ + 16], 0x55667788
    ASSERT_DWORD [NVME_IO_SQ + 20], 0x11223344
    ASSERT_DWORD [NVME_IO_SQ + 24], 2
    mov     eax, dword [NVME_IO_SQ + 40]
    lea     rdx, [rel data_buf]
    ASSERT_EQ eax, edx
    ASSERT_DWORD [NVME_IO_SQ + 44], 0
    ASSERT_QWORD [rel doorbell_count], 1
    ASSERT_DWORD [rel doorbell_value], 1

    mov     edi, TEST_BAR
    mov     rsi, 5
    lea     rdx, [rel data_buf]
    mov     ecx, 1
    call    er_nvme_write_blocks
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0
    ASSERT_DWORD [NVME_IO_SQ], 1
    ASSERT_DWORD [NVME_IO_SQ + 16], 5
    ASSERT_DWORD [NVME_IO_SQ + 20], 0
    ASSERT_DWORD [NVME_IO_SQ + 24], 0

    mov     edi, TEST_BAR
    xor     esi, esi
    lea     rdx, [rel data_buf]
    xor     ecx, ecx
    call    er_nvme_read_blocks
    ASSERT_EQ eax, -1
    ASSERT_EQ edx, ERROR_UNSUPPORTED

    TEST_EXIT_FAILED

map_nvme_queue_page:
    mov     rdi, NVME_IO_CQ
    mov     rsi, 8192
    mov     rdx, PROT_READ_WRITE
    mov     r10, MAP_PRIVATE_FIXED_ANON
    mov     r8, -1
    xor     r9d, r9d
    mov     eax, SYS_MMAP
    syscall
    ASSERT_EQ rax, NVME_IO_CQ
    ret

global er_mmio_write32
er_mmio_write32:
    cmp     edi, TEST_BAR + NVME_SQ1TDBL
    jne     .done
    mov     dword [rel doorbell_value], esi
    inc     qword [rel doorbell_count]
    mov     dword [NVME_IO_CQ], 1
    mov     word [NVME_IO_CQ + 6], 0
.done:
    xor     eax, eax
    ret

global er_mmio_read32
er_mmio_read32:
    xor     eax, eax
    ret

global er_pci_read32
er_pci_read32:
    xor     eax, eax
    ret

global er_serial_puts
global er_serial_puthex32
global er_serial_putdec32
global er_serial_crlf
er_serial_puts:
er_serial_puthex32:
er_serial_putdec32:
er_serial_crlf:
    ret

SYS_MMAP equ 9
PROT_READ_WRITE equ 3
MAP_PRIVATE_FIXED_ANON equ 0x32
NVME_IO_CQ equ 0x303000
NVME_IO_SQ equ 0x304000
NVME_SQ1TDBL equ 0x1008
TEST_BAR equ 0x100000
