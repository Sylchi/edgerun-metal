; EdgeRun AMDGPU self-hosted test runner — x86_64 assembly
; Tests DCN MMIO writes against hosted memory.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "test/test_macros.inc"
%include "driver/amdgpu_constants.inc"

extern er_amdgpu_dcn_init
extern er_amdgpu_program_hubp0_scanout
extern er_amdgpu_program_otg0_mode
extern er_amdgpu_program_otg0_timing
extern er_amdgpu_validate_scanout_config
extern er_amdgpu_validate_timing

%define AMDGPU_TEST_BAR0_SIZE 0x28000

SECTION .bss
passed: resq 1
failed: resq 1
bar0: resb AMDGPU_TEST_BAR0_SIZE
fb: resb AMDGPU_FB_SIZE
scanout_cfg: resb AMDGPU_SCANOUT_SIZE
timing_cfg: resb AMDGPU_TIMING_SIZE

SECTION .rodata
pass_msg: db "PASS amdgpu", 10, 0
fail_msg: db "FAIL amdgpu", 10, 0

SECTION .text
global _start
global er_pci_read32
global er_pci_write32
global er_mmio_read32
global er_mmio_write32
global er_serial_puts
global er_serial_puthex32
global er_serial_puthex64
global er_serial_putdec32
global er_serial_putchar
global er_serial_crlf
global er_serial_putnewline
global er_serial_getchar
_start:
    xor     edi, edi
    lea     rsi, [rel fb]
    call    er_amdgpu_dcn_init
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel bar0 + DCN_DCFCLK_CNTL], 0x80000005

    lea     rdi, [rel bar0]
    lea     rsi, [rel fb]
    call    er_amdgpu_dcn_init
    ASSERT_EQ eax, 0

    mov     eax, [rel bar0 + DCN_DC_IP_REQUEST_CNTL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DCCG_GATE_DISABLE_CNTL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DCCG_GATE_DISABLE_CNTL2]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DCFCLK_CNTL]
    ASSERT_EQ eax, 5
    mov     eax, [rel bar0 + DCN_DOMAIN0_PG_CONFIG]
    ASSERT_EQ eax, 1
    mov     eax, [rel bar0 + DCN_DOMAIN1_PG_CONFIG]
    ASSERT_EQ eax, 1
    mov     eax, [rel bar0 + DCN_DOMAIN16_PG_CONFIG]
    ASSERT_EQ eax, 1
    mov     eax, [rel bar0 + DCN_HPO_TOP_HW_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DIO_MEM_PWR_CTRL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DCHUBBUB_GLOBAL_TIMER_CNTL]
    ASSERT_EQ eax, 0x00001202
    mov     eax, [rel bar0 + DCN_HUBP0_SURFACE_PITCH]
    ASSERT_EQ eax, AMDGPU_FB_WIDTH
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR]
    lea     rbx, [rel fb]
    ASSERT_EQ eax, ebx
    mov     eax, [rel bar0 + DCN_HUBP0_FLIP_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_HUBP0_DCHUBP_CNTL]
    ASSERT_EQ eax, 1
    mov     eax, [rel bar0 + DCN_OTG0_V_TOTAL]
    ASSERT_EQ eax, 1124
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL]
    ASSERT_EQ eax, 2199
    mov     eax, [rel bar0 + DCN_OTG0_H_SYNC_A]
    ASSERT_EQ eax, (1999 << 16) | 1968
    mov     eax, [rel bar0 + DCN_OTG0_V_SYNC_A]
    ASSERT_EQ eax, (1087 << 16) | 1083
    mov     eax, [rel bar0 + DCN_OTG0_H_BLANK_START_END]
    ASSERT_EQ eax, (1919 << 16) | 128
    mov     eax, [rel bar0 + DCN_OTG0_V_BLANK_START_END]
    ASSERT_EQ eax, (1079 << 16) | 4
    mov     eax, [rel bar0 + DCN_OTG0_INTERLACE_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_MASTER_EN]
    ASSERT_EQ eax, 1

    mov     eax, [rel fb]
    ASSERT_EQ eax, 0x00ffffff
    mov     eax, [rel fb + 240 * 4]
    ASSERT_EQ eax, 0x0000ffff
    mov     eax, [rel fb + 1919 * 4]
    ASSERT_EQ eax, 0

    lea     rdi, [rel bar0]
    mov     esi, AMDGPU_MODE_720P60
    call    er_amdgpu_program_otg0_mode
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_V_TOTAL]
    ASSERT_EQ eax, 749
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL]
    ASSERT_EQ eax, 1649
    mov     eax, [rel bar0 + DCN_OTG0_H_SYNC_A]
    ASSERT_EQ eax, (1429 << 16) | 1390
    mov     eax, [rel bar0 + DCN_OTG0_V_SYNC_A]
    ASSERT_EQ eax, (729 << 16) | 725
    mov     eax, [rel bar0 + DCN_OTG0_H_BLANK_START_END]
    ASSERT_EQ eax, (1279 << 16) | 370
    mov     eax, [rel bar0 + DCN_OTG0_V_BLANK_START_END]
    ASSERT_EQ eax, (719 << 16) | 30
    mov     eax, [rel bar0 + DCN_OTG0_MASTER_EN]
    ASSERT_EQ eax, 1

    lea     rdi, [rel bar0]
    mov     esi, AMDGPU_MODE_COUNT
    call    er_amdgpu_program_otg0_mode
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_TOTAL], 1650
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_SYNC_START], 1390
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_SYNC_END], 1430
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_BLANK_START], 1280
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_BLANK_END], 370
    mov     dword [rel timing_cfg + AMDGPU_TIMING_V_TOTAL], 750
    mov     dword [rel timing_cfg + AMDGPU_TIMING_V_SYNC_START], 725
    mov     dword [rel timing_cfg + AMDGPU_TIMING_V_SYNC_END], 730
    mov     dword [rel timing_cfg + AMDGPU_TIMING_V_BLANK_START], 720
    mov     dword [rel timing_cfg + AMDGPU_TIMING_V_BLANK_END], 30
    lea     rdi, [rel timing_cfg]
    call    er_amdgpu_validate_timing
    ASSERT_EQ eax, 0
    lea     rdi, [rel bar0]
    lea     rsi, [rel timing_cfg]
    call    er_amdgpu_program_otg0_timing
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL]
    ASSERT_EQ eax, 1649

    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_TOTAL], 0
    lea     rdi, [rel timing_cfg]
    call    er_amdgpu_validate_timing
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT
    lea     rdi, [rel bar0]
    lea     rsi, [rel timing_cfg]
    call    er_amdgpu_program_otg0_timing
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_TOTAL], 1650
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_SYNC_START], 1430
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_SYNC_END], 1390
    lea     rdi, [rel timing_cfg]
    call    er_amdgpu_validate_timing
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_SYNC_START], 1390
    mov     dword [rel timing_cfg + AMDGPU_TIMING_H_SYNC_END], 1430
    mov     dword [rel timing_cfg + AMDGPU_TIMING_V_BLANK_START], 751
    lea     rdi, [rel timing_cfg]
    call    er_amdgpu_validate_timing
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_LO], 0x12345000
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_HI], 0x00000001
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_PITCH_PIXELS], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_HEIGHT], 720
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, 0
    lea     rdi, [rel bar0]
    lea     rsi, [rel scanout_cfg]
    call    er_amdgpu_program_hubp0_scanout
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_HUBP0_SURFACE_PITCH]
    ASSERT_EQ eax, 1280
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR]
    ASSERT_EQ eax, 0x12345000
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR + 4]
    ASSERT_EQ eax, 1
    mov     eax, [rel bar0 + DCN_HUBP0_DCHUBP_CNTL]
    ASSERT_EQ eax, 1

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_PITCH_PIXELS], 0
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT
    lea     rdi, [rel bar0]
    lea     rsi, [rel scanout_cfg]
    call    er_amdgpu_program_hubp0_scanout
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_PITCH_PIXELS], 640
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_HEIGHT], 720
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT
    lea     rdi, [rel bar0]
    lea     rsi, [rel scanout_cfg]
    call    er_amdgpu_program_hubp0_scanout
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_PITCH_PIXELS], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], 0
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT
    lea     rdi, [rel bar0]
    lea     rsi, [rel scanout_cfg]
    call    er_amdgpu_program_hubp0_scanout
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     rax, [rel failed]
    test    rax, rax
    jnz     .fail
    mov     rdi, 1
    lea     rsi, [rel pass_msg]
    mov     rdx, 12
    mov     rax, 1
    syscall
    xor     edi, edi
    mov     rax, 60
    syscall

.fail:
    mov     rdi, 1
    lea     rsi, [rel fail_msg]
    mov     rdx, 12
    mov     rax, 1
    syscall
    mov     edi, 1
    mov     rax, 60
    syscall

; Unused AMDGPU object dependencies for functions outside this test path.
er_pci_read32:
er_pci_write32:
er_mmio_read32:
er_mmio_write32:
er_serial_puts:
er_serial_puthex32:
er_serial_puthex64:
er_serial_putdec32:
er_serial_putchar:
er_serial_crlf:
er_serial_putnewline:
er_serial_getchar:
    xor     eax, eax
    ret
