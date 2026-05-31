; EdgeRun AMDGPU constants — x86_64 assembly
; AMDGPU display driver constants for RDNA3 (Phoenix / Radeon 780M)
;
; Target: Framework 13 AMD 7840U — integrated Radeon 780M (gfx1103, DCN 3.1.4)
;
; Reference: Linux drivers/gpu/drm/amd/amdgpu + umr (amdgpu debug tool)

; ─── PCI IDs ────────────────────────────────────────────────────────
%define AMD_VENDOR_ID               0x1002
%define PHOENIX_GPU_DEVICE_ID       0x15BF   ; Radeon 780M in 7840U

; Display controller class codes
%define PCI_CLASS_DISPLAY           0x03
%define PCI_SUBCLASS_VGA            0x00
%define PCI_PROGIF_VGA              0x00

; ─── PCI config space registers (not defined in pci.asm) ──────────
%define PCI_REVISION_ID             0x08

; ─── AMDGPU MMIO register blocks (BAR0 offset ranges) ────────────
; RDNA3 GPU MMIO: BAR0 gives access to the full 2MB register space.
; Registers are 32-bit, offset from BAR0 base.
%define AMDGPU_REG_SPACE_SIZE       0x200000   ; 2 MB

; ─── MMIO registers common to all AMD GPUs (GCN+) ─────────────────
; Chip identity (present since SI/CIK)
%define mmCHIP_REVISION             0x143E
%define mmCC_DRM_ID                 0x0439

; ─── DCN 3.1.4 power/clock register byte offsets from BAR0 ──────
; Power gate domains (all in DCN segment, base_seg=0x34C0)
%define DCN_DC_IP_REQUEST_CNTL             0xD554
%define DCN_DOMAIN0_PG_CONFIG              0xD500
%define DCN_DOMAIN1_PG_CONFIG              0xD508
%define DCN_DOMAIN2_PG_CONFIG              0xD510
%define DCN_DOMAIN3_PG_CONFIG              0xD518
%define DCN_DOMAIN16_PG_CONFIG             0xD524
%define DCN_DOMAIN17_PG_CONFIG             0xD52C
%define DCN_DOMAIN18_PG_CONFIG             0xD534
%define DCN_DOMAIN0_PG_STATUS              0xD504
%define DCN_DOMAIN1_PG_STATUS              0xD50C
%define DCN_DOMAIN2_PG_STATUS              0xD514
%define DCN_DOMAIN3_PG_STATUS              0xD51C
%define DCN_DOMAIN16_PG_STATUS             0xD528
%define DCN_DOMAIN17_PG_STATUS             0xD530
%define DCN_DOMAIN18_PG_STATUS             0xD538

; Clock gating (DCCG segment, base_seg=0x00C0)
%define DCN_DCCG_GATE_DISABLE_CNTL         0x04D0
%define DCN_DCCG_GATE_DISABLE_CNTL2        0x04F0
%define DCN_DCFCLK_CNTL                    0xE7CC

; Memory power control
%define DCN_DIO_MEM_PWR_CTRL               0x14E78
%define DCN_DMU_MEM_PWR_CNTL               0xD630
%define DCN_ODM_MEM_PWR_CTRL3              0x14BBC
%define DCN_MMHUBBUB_MEM_PWR_CNTL          0xE000

; Global timer
%define DCN_DCHUBBUB_GLOBAL_TIMER_CNTL     0xE790

; HPO control (base_seg=0x9000)
%define DCN_HPO_TOP_HW_CONTROL             0x27928

; ─── OTG registers (OTG0, base_seg=0x34C0) ──────────────────────
%define DCN_OTG0_CONTROL                   0x14004
%define DCN_OTG0_MASTER_EN                 0x14070
%define DCN_OTG0_V_TOTAL                   0x13FBC
%define DCN_OTG0_H_TOTAL                   0x13FA8
%define DCN_OTG0_V_SYNC_A                  0x13FDC
%define DCN_OTG0_H_SYNC_A                  0x13FB0
%define DCN_OTG0_V_BLANK_START_END         0x13FD8
%define DCN_OTG0_H_BLANK_START_END         0x13FAC
%define DCN_OTG0_INTERLACE_CONTROL         0x14010
%define DCN_OTG0_V_UPDATE_POSITION         0x1401C

; OTG pipe stride: each OTGn is +0x370 bytes from OTGn-1
%define DCN_OTG_PIPE_STRIDE                0x370

; ─── HUBP registers (HUBP0, base_seg=0x34C0) ────────────────────
%define DCN_HUBP0_DCHUBP_CNTL              0xEACC
%define DCN_HUBP0_SURFACE_PITCH            0xEB1C
%define DCN_HUBP0_PRIMARY_SURFACE_ADDR     0xEB28
%define DCN_HUBP0_FLIP_CONTROL             0xEB6C

; HUBP pipe stride: each HUBPn is +0x370 bytes from HUBPn-1
%define DCN_HUBP_PIPE_STRIDE               0x370
%define DCN_HUBP_PIPE_COUNT                4

; ─── Framebuffer setup constants ───────────────────────────────────
%define AMDGPU_FB_WIDTH             1920
%define AMDGPU_FB_HEIGHT            1080
%define AMDGPU_FB_BPP               32         ; XRGB8888
%define AMDGPU_FB_PITCH             (AMDGPU_FB_WIDTH * 4)
%define AMDGPU_FB_SIZE              (AMDGPU_FB_PITCH * AMDGPU_FB_HEIGHT)

; ─── DCN timing plan structure offsets ─────────────────────────────
%define AMDGPU_TIMING_H_TOTAL              0
%define AMDGPU_TIMING_H_SYNC_START         4
%define AMDGPU_TIMING_H_SYNC_END           8
%define AMDGPU_TIMING_H_BLANK_START        12
%define AMDGPU_TIMING_H_BLANK_END          16
%define AMDGPU_TIMING_V_TOTAL              20
%define AMDGPU_TIMING_V_SYNC_START         24
%define AMDGPU_TIMING_V_SYNC_END           28
%define AMDGPU_TIMING_V_BLANK_START        32
%define AMDGPU_TIMING_V_BLANK_END          36
%define AMDGPU_TIMING_SIZE                 40
%define AMDGPU_MODE_1080P60                0
%define AMDGPU_MODE_720P60                 1
%define AMDGPU_MODE_COUNT                  2

; ─── DCN HUBP scanout config structure offsets ─────────────────────
%define AMDGPU_SCANOUT_ADDR_LO             0
%define AMDGPU_SCANOUT_ADDR_HI             4
%define AMDGPU_SCANOUT_PITCH_PIXELS        8
%define AMDGPU_SCANOUT_WIDTH               12
%define AMDGPU_SCANOUT_HEIGHT              16
%define AMDGPU_SCANOUT_SIZE                20

; ─── AMDGPU driver error codes ────────────────────────────────────
%define AMDGPU_ERR_NOT_FOUND        30
%define AMDGPU_ERR_BAR_INVALID      31
%define AMDGPU_ERR_INIT             32

; ─── Power gating domain mapping (DCN 3.1.4) ──────────────────────
; DOMAIN0    → HUBP0, DPP0
; DOMAIN1    → HUBP1, DPP1
; DOMAIN2    → HUBP2, DPP2
; DOMAIN3    → HUBP3, DPP3
; DOMAIN16   → DSC0
; DOMAIN17   → DSC1
; DOMAIN18   → DSC2
