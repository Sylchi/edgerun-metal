; EdgeRun AMDGPU self-hosted test runner — x86_64 assembly
; Tests DCN MMIO writes against a synthetic BAR0 memory window.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "test/test_macros.inc"
%include "driver/amdgpu_constants.inc"

extern er_amdgpu_dcn_init
extern er_amdgpu_dcn_get_stage
extern er_amdgpu_probe
extern er_amdgpu_probe_get_stage
extern er_amdgpu_program_hubp_scanout
extern er_amdgpu_program_hubp0_scanout
extern er_amdgpu_program_dpp_plane
extern er_amdgpu_program_dpp0_plane
extern er_amdgpu_program_pipe
extern er_amdgpu_program_otg_mode
extern er_amdgpu_program_otg0_mode
extern er_amdgpu_program_otg_timing
extern er_amdgpu_program_otg0_timing
extern er_amdgpu_validate_scanout_config
extern er_amdgpu_validate_timing

%define AMDGPU_TEST_BAR0_SIZE 0x28000
%define AMDGPU_TEST_PCI_BAR0 0x10
%define AMDGPU_TEST_PCI_BAR2 0x18

SECTION .bss
passed: resq 1
failed: resq 1
align 16
bar0: resb AMDGPU_TEST_BAR0_SIZE
align 4096
fb: resb AMDGPU_FB_SIZE
scanout_cfg: resb AMDGPU_SCANOUT_SIZE
timing_cfg: resb AMDGPU_TIMING_SIZE
out_bar0: resq 1
out_bar2: resq 1
pci_id: resd 1
pci_bar0_raw: resd 1
pci_bar2_raw: resd 1
pci_command: resd 1

SECTION .rodata
pass_msg: db "PASS amdgpu", 10, 0
fail_msg: db "FAIL amdgpu", 10, 0

SECTION .text
global _start
global er_amdgpu_selftest
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
    call    er_amdgpu_selftest
    test    eax, eax
    jnz     .host_fail
    mov     rdi, 1
    lea     rsi, [rel pass_msg]
    mov     rdx, 12
    mov     rax, 1
    syscall
    xor     edi, edi
    mov     rax, 60
    syscall

.host_fail:
    mov     rdi, 1
    lea     rsi, [rel fail_msg]
    mov     rdx, 12
    mov     rax, 1
    syscall
    mov     edi, 1
    mov     rax, 60
    syscall

er_amdgpu_selftest:
    mov     qword [rel passed], 0
    mov     qword [rel failed], 0

    mov     dword [rel pci_id], (PHOENIX_GPU_DEVICE_ID << 16) | AMD_VENDOR_ID
    lea     rax, [rel bar0]
    mov     [rel pci_bar0_raw], eax
    lea     rax, [rel fb]
    mov     [rel pci_bar2_raw], eax
    mov     dword [rel bar0 + mmCC_DRM_ID * 4], 0x000015bf
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    lea     rcx, [rel out_bar0]
    lea     r8, [rel out_bar2]
    call    er_amdgpu_probe
    ASSERT_EQ eax, 0
    call    er_amdgpu_probe_get_stage
    ASSERT_EQ eax, AMDGPU_PROBE_STAGE_OK
    mov     rax, [rel out_bar0]
    lea     rdx, [rel bar0]
    ASSERT_EQ rax, rdx
    mov     rax, [rel out_bar2]
    lea     rdx, [rel fb]
    ASSERT_EQ rax, rdx
    mov     eax, [rel pci_command]
    ASSERT_EQ eax, 0x00000006

    mov     dword [rel pci_bar0_raw], 0
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    lea     rcx, [rel out_bar0]
    lea     r8, [rel out_bar2]
    call    er_amdgpu_probe
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_UNSUPPORTED
    call    er_amdgpu_probe_get_stage
    ASSERT_EQ eax, AMDGPU_PROBE_STAGE_BAR0
    lea     rax, [rel bar0]
    mov     [rel pci_bar0_raw], eax

    mov     dword [rel pci_bar2_raw], 0
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    lea     rcx, [rel out_bar0]
    lea     r8, [rel out_bar2]
    call    er_amdgpu_probe
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_UNSUPPORTED
    call    er_amdgpu_probe_get_stage
    ASSERT_EQ eax, AMDGPU_PROBE_STAGE_BAR2
    lea     rax, [rel fb]
    mov     [rel pci_bar2_raw], eax

    mov     dword [rel bar0 + mmCC_DRM_ID * 4], 0xffffffff
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    lea     rcx, [rel out_bar0]
    lea     r8, [rel out_bar2]
    call    er_amdgpu_probe
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_NOT_PRESENT
    call    er_amdgpu_probe_get_stage
    ASSERT_EQ eax, AMDGPU_PROBE_STAGE_MMIO
    mov     dword [rel bar0 + mmCC_DRM_ID * 4], 0x000015bf

    mov     dword [rel pci_id], (0xffff << 16) | AMD_VENDOR_ID
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    lea     rcx, [rel out_bar0]
    lea     r8, [rel out_bar2]
    call    er_amdgpu_probe
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_UNSUPPORTED
    call    er_amdgpu_probe_get_stage
    ASSERT_EQ eax, AMDGPU_PROBE_STAGE_UNSUPPORTED_ID
    mov     dword [rel pci_id], (PHOENIX_GPU_DEVICE_ID << 16) | AMD_VENDOR_ID

    xor     edi, edi
    lea     rsi, [rel fb]
    call    er_amdgpu_dcn_init
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT
    call    er_amdgpu_dcn_get_stage
    ASSERT_EQ eax, AMDGPU_DCN_STAGE_BAD_ARG

    lea     rdi, [rel bar0]
    xor     esi, esi
    call    er_amdgpu_dcn_init
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT
    call    er_amdgpu_dcn_get_stage
    ASSERT_EQ eax, AMDGPU_DCN_STAGE_BAD_ARG

    mov     dword [rel bar0 + DCN_DCFCLK_CNTL], 0x80000005

    lea     rdi, [rel bar0]
    lea     rsi, [rel fb]
    call    er_amdgpu_dcn_init
    ASSERT_EQ eax, 0
    call    er_amdgpu_dcn_get_stage
    ASSERT_EQ eax, AMDGPU_DCN_STAGE_OK

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
    ASSERT_EQ eax, AMDGPU_DCN_GLOBAL_TIMER_REFDIV2_EN
    mov     eax, [rel bar0 + DCN_HUBP0_SURFACE_PITCH]
    ASSERT_EQ eax, AMDGPU_FB_WIDTH
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR]
    lea     rbx, [rel fb]
    ASSERT_EQ eax, ebx
    mov     eax, [rel bar0 + DCN_HUBP0_FLIP_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_HUBP0_DCHUBP_CNTL]
    ASSERT_EQ eax, 1
    mov     eax, [rel bar0 + DCN_DPP0_DPP_CONTROL]
    ASSERT_EQ eax, AMDGPU_DPP_CONTROL_ENABLE
    mov     eax, [rel bar0 + DCN_DPP0_CNVC_SURFACE_PIXEL_FORMAT]
    ASSERT_EQ eax, AMDGPU_DPP_SURFACE_FORMAT_ARGB8888
    mov     eax, [rel bar0 + DCN_DPP0_FORMAT_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_CNVC_PRE_DEALPHA]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_CNVC_PRE_CSC_MODE]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_CNVC_PRE_DEGAM]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_CNVC_PRE_REALPHA]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_DSCL_SCL_MODE]
    ASSERT_EQ eax, AMDGPU_DPP_PIPE_BYPASS
    mov     eax, [rel bar0 + DCN_DPP0_DSCL_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_RECOUT_SIZE]
    ASSERT_EQ eax, (AMDGPU_FB_HEIGHT << 16) | AMDGPU_FB_WIDTH
    mov     eax, [rel bar0 + DCN_DPP0_MPC_SIZE]
    ASSERT_EQ eax, (AMDGPU_FB_HEIGHT << 16) | AMDGPU_FB_WIDTH
    mov     eax, [rel bar0 + DCN_DPP0_LB_DATA_FORMAT]
    ASSERT_EQ eax, AMDGPU_DPP_SURFACE_FORMAT_ARGB8888

    lea     rdi, [rel bar0]
    mov     esi, 1920
    mov     edx, 1080
    call    er_amdgpu_program_dpp0_plane
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_RECOUT_SIZE]
    ASSERT_EQ eax, (1080 << 16) | 1920
    mov     eax, [rel bar0 + DCN_DPP0_MPC_SIZE]
    ASSERT_EQ eax, (1080 << 16) | 1920

    lea     rdi, [rel bar0]
    mov     esi, 1
    mov     edx, 1280
    mov     ecx, 720
    call    er_amdgpu_program_dpp_plane
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_DPP0_DPP_CONTROL + DCN_DPP_PIPE_STRIDE]
    ASSERT_EQ eax, AMDGPU_DPP_CONTROL_ENABLE
    mov     eax, [rel bar0 + DCN_DPP0_RECOUT_SIZE + DCN_DPP_PIPE_STRIDE]
    ASSERT_EQ eax, (720 << 16) | 1280
    mov     eax, [rel bar0 + DCN_DPP0_LB_DATA_FORMAT + DCN_DPP_PIPE_STRIDE]
    ASSERT_EQ eax, AMDGPU_DPP_SURFACE_FORMAT_ARGB8888

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_LO], 0x32345000
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_HI], 0x00000003
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_PITCH_PIXELS], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_HEIGHT], 720
    lea     rdi, [rel bar0]
    mov     esi, 2
    lea     rdx, [rel scanout_cfg]
    mov     ecx, AMDGPU_MODE_720P60
    call    er_amdgpu_program_pipe
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR + (DCN_HUBP_PIPE_STRIDE * 2)]
    ASSERT_EQ eax, 0x32345000
    mov     eax, [rel bar0 + DCN_DPP0_RECOUT_SIZE + (DCN_DPP_PIPE_STRIDE * 2)]
    ASSERT_EQ eax, (720 << 16) | 1280
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL + (DCN_OTG_PIPE_STRIDE * 2)]
    ASSERT_EQ eax, 1649

    lea     rdi, [rel bar0]
    mov     esi, DCN_HUBP_PIPE_COUNT
    lea     rdx, [rel scanout_cfg]
    mov     ecx, AMDGPU_MODE_720P60
    call    er_amdgpu_program_pipe
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    lea     rdi, [rel bar0]
    mov     esi, DCN_DPP_PIPE_COUNT
    mov     edx, 1280
    mov     ecx, 720
    call    er_amdgpu_program_dpp_plane
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    lea     rdi, [rel bar0]
    xor     esi, esi
    mov     edx, 1280
    xor     ecx, ecx
    call    er_amdgpu_program_dpp_plane
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     eax, [rel bar0 + DCN_OTG0_V_TOTAL]
    ASSERT_EQ eax, 1548
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL]
    ASSERT_EQ eax, 2535
    mov     eax, [rel bar0 + DCN_OTG0_H_SYNC_A]
    ASSERT_EQ eax, (2335 << 16) | 2304
    mov     eax, [rel bar0 + DCN_OTG0_V_SYNC_A]
    ASSERT_EQ eax, (1512 << 16) | 1507
    mov     eax, [rel bar0 + DCN_OTG0_H_BLANK_START_END]
    ASSERT_EQ eax, (2255 << 16) | 280
    mov     eax, [rel bar0 + DCN_OTG0_V_BLANK_START_END]
    ASSERT_EQ eax, (1503 << 16) | 45
    mov     eax, [rel bar0 + DCN_OTG0_INTERLACE_CONTROL]
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_MASTER_EN]
    ASSERT_EQ eax, 1

    mov     eax, [rel fb]
    ASSERT_EQ eax, 0x00ffffff
    mov     eax, [rel fb + 282 * 4]
    ASSERT_EQ eax, 0x0000ffff
    mov     eax, [rel fb + 2255 * 4]
    ASSERT_EQ eax, 0

    lea     rdi, [rel bar0]
    mov     esi, AMDGPU_MODE_EDP_NATIVE_2256X1504_60
    call    er_amdgpu_program_otg0_mode
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL]
    ASSERT_EQ eax, 2535

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
    mov     esi, 1
    mov     edx, AMDGPU_MODE_720P60
    call    er_amdgpu_program_otg_mode
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_V_TOTAL + DCN_OTG_PIPE_STRIDE]
    ASSERT_EQ eax, 749
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL + DCN_OTG_PIPE_STRIDE]
    ASSERT_EQ eax, 1649
    mov     eax, [rel bar0 + DCN_OTG0_H_SYNC_A + DCN_OTG_PIPE_STRIDE]
    ASSERT_EQ eax, (1429 << 16) | 1390
    mov     eax, [rel bar0 + DCN_OTG0_MASTER_EN + DCN_OTG_PIPE_STRIDE]
    ASSERT_EQ eax, 1

    lea     rdi, [rel bar0]
    mov     esi, DCN_OTG_PIPE_COUNT
    mov     edx, AMDGPU_MODE_720P60
    call    er_amdgpu_program_otg_mode
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

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
    lea     rdi, [rel bar0]
    mov     esi, 1
    lea     rdx, [rel timing_cfg]
    call    er_amdgpu_program_otg_timing
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_OTG0_H_TOTAL + DCN_OTG_PIPE_STRIDE]
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
    lea     rdi, [rel bar0]
    mov     esi, DCN_OTG_PIPE_COUNT
    lea     rdx, [rel timing_cfg]
    call    er_amdgpu_program_otg_timing
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

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_LO], 0x22345000
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_HI], 0x00000002
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_PITCH_PIXELS], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], 1280
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_HEIGHT], 720
    lea     rdi, [rel bar0]
    mov     esi, 1
    lea     rdx, [rel scanout_cfg]
    call    er_amdgpu_program_hubp_scanout
    ASSERT_EQ eax, 0
    mov     eax, [rel bar0 + DCN_HUBP0_SURFACE_PITCH + DCN_HUBP_PIPE_STRIDE]
    ASSERT_EQ eax, 1280
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR + DCN_HUBP_PIPE_STRIDE]
    ASSERT_EQ eax, 0x22345000
    mov     eax, [rel bar0 + DCN_HUBP0_PRIMARY_SURFACE_ADDR + DCN_HUBP_PIPE_STRIDE + 4]
    ASSERT_EQ eax, 2
    mov     eax, [rel bar0 + DCN_HUBP0_DCHUBP_CNTL + DCN_HUBP_PIPE_STRIDE]
    ASSERT_EQ eax, 1

    lea     rdi, [rel bar0]
    mov     esi, DCN_HUBP_PIPE_COUNT
    lea     rdx, [rel scanout_cfg]
    call    er_amdgpu_program_hubp_scanout
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

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

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_LO], 0
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_HI], 0
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], 1280
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_LO], 0x12345004
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_HI], 1
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_ADDR_LO], 0x12345000
    mov     dword [rel scanout_cfg + AMDGPU_SCANOUT_WIDTH], AMDGPU_DPP_SIZE_FIELD_LIMIT
    lea     rdi, [rel scanout_cfg]
    call    er_amdgpu_validate_scanout_config
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     rax, [rel failed]
    test    rax, rax
    jnz     .self_fail
    xor     eax, eax
    ret

.self_fail:
    mov     eax, -1
    ret

; Unused AMDGPU object dependencies for functions outside this test path.
er_pci_read32:
    cmp     ecx, 0
    je      .read_vendor
    cmp     ecx, AMDGPU_TEST_PCI_BAR0
    je      .read_bar0
    cmp     ecx, AMDGPU_TEST_PCI_BAR2
    je      .read_bar2
    cmp     ecx, 0x04
    je      .read_command
    xor     eax, eax
    ret
.read_vendor:
    mov     eax, [rel pci_id]
    ret
.read_bar0:
    mov     eax, [rel pci_bar0_raw]
    ret
.read_bar2:
    mov     eax, [rel pci_bar2_raw]
    ret
.read_command:
    mov     eax, [rel pci_command]
    ret
er_pci_write32:
    cmp     ecx, 0x04
    jne     .write_done
    mov     [rel pci_command], r8d
.write_done:
    xor     eax, eax
    ret
er_mmio_read32:
    mov     eax, [rdi]
    ret
er_mmio_write32:
    mov     [rdi], esi
    xor     eax, eax
    ret
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
