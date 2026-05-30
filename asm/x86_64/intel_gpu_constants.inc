; EdgeRun Intel KBL/Gen9 GPU display constants — x86_64 assembly
; Registers for Intel HD Graphics 615 (KBL GT2, PCI 8086:591e)
; on Surface Go 1 (1800×1200 eDP panel)

; ─── PCI ───────────────────────────────────────────────────────────
%define PCI_INTEL_VENDOR      0x8086
%define PCI_KBL_GT2_HD615    0x591E  ; HD Graphics 615 (KBL GT2)
%define PCI_KBL_GT2_HD620    0x5916  ; HD Graphics 620 (KBL GT2)
%define PCI_KBL_GT2_UHD620   0x5917  ; UHD Graphics 620

; ─── BAR types ─────────────────────────────────────────────────────
; BAR0 = MMIO (4MB, fixed at 0-4MB)
; BAR2 = GTT aperture (typically 256MB-512MB, configurable via PCI)

; ─── Display pipe/plane/port bases (Gen9/KBL) ────────────────────
; Pipes: A=0, B=1, C=2
; Planes per pipe: 1=primary, 2=sprite, 3=sprite
; Ports: A=DDI A (eDP), B=DDI B (DP/HDMI), C=DDI C (DP)

; ─── Pipe registers (offset = base + pipe*0x1000) ──────────────────
%define _PIPE_A                0x70000
%define _PIPE_B                0x71000
%define _PIPE_C                0x72000

%define PIPECONF(pipe)        (_PIPE_A + (pipe << 12) + 0x08)
%define PIPESTAT(pipe)        (_PIPE_A + (pipe << 12) + 0x00)
%define PIPESRC(pipe)         (_PIPE_A + (pipe << 12) + 0x0C)

; ─── Primary plane registers (offset = base + pipe*0x1000 + plane*0x100) ─
%define PLANE_CTL(pipe,plane)  (_PIPE_A + (pipe << 12) + 0x180 + ((plane-1) << 8))
%define PLANE_SURF(pipe,plane) (_PIPE_A + (pipe << 12) + 0x19C + ((plane-1) << 8))
%define PLANE_STRIDE(pipe,plane) (_PIPE_A + (pipe << 12) + 0x188 + ((plane-1) << 8))
%define PLANE_SIZE(pipe,plane) (_PIPE_A + (pipe << 12) + 0x190 + ((plane-1) << 8))
%define PLANE_POS(pipe,plane)  (_PIPE_A + (pipe << 12) + 0x18C + ((plane-1) << 8))
%define PLANE_OFFSET(pipe,plane) (_PIPE_A + (pipe << 12) + 0x1A4 + ((plane-1) << 8))
%define PLANE_KEYVAL(pipe,plane) (_PIPE_A + (pipe << 12) + 0x194 + ((plane-1) << 8))
%define PLANE_KEYMSK(pipe,plane) (_PIPE_A + (pipe << 12) + 0x198 + ((plane-1) << 8))
%define PLANE_KEYMAX(pipe,plane) (_PIPE_A + (pipe << 12) + 0x1A0 + ((plane-1) << 8))
%define PLANE_BUF_CFG(pipe,plane) (_PIPE_A + (pipe << 12) + 0x1C0 + ((plane-1) << 8))
%define PLANE_NV12_BUF_CFG(pipe,plane) (_PIPE_A + (pipe << 12) + 0x1CC + ((plane-1) << 8))
%define PLANE_AUX_DIST(pipe,plane) (_PIPE_A + (pipe << 12) + 0x1C8 + ((plane-1) << 8))
%define PLANE_AUX_OFFSET(pipe,plane) (_PIPE_A + (pipe << 12) + 0x1C4 + ((plane-1) << 8))

; ─── Plane control bits ────────────────────────────────────────────
%define PLANE_CTL_ENABLE      (1 << 31)
%define PLANE_CTL_PIPE_CSC_EN (1 << 24)
%define PLANE_CTL_FORMAT_SHIFT 26
%define PLANE_CTL_FORMAT_MASK (7 << 26)
%define PLANE_CTL_FORMAT_XRGB8888 (5 << 26)
%define PLANE_CTL_FORMAT_ARGB8888 (4 << 26)
%define PLANE_CTL_TILED_LINEAR (0 << 10)
%define PLANE_CTL_TILED_X     (1 << 10)
%define PLANE_CTL_TILED_Y     (4 << 10)
%define PLANE_CTL_TILED_Yf    (5 << 10)
%define PLANE_CTL_ALPHA_SHIFT 8
%define PLANE_CTL_ALPHA_MASK  (3 << 8)
%define PLANE_CTL_ALPHA_DISABLE (0 << 8)
%define PLANE_CTL_ALPHA_PREMULT (2 << 8)
%define PLANE_CTL_ALPHA_HW     (3 << 8)

; ─── Pipe config bits ──────────────────────────────────────────────
%define PIPECONF_ENABLE       (1 << 31)
%define PIPECONF_DISABLE      (0 << 31)
%define PIPECONF_BPC_6        (0 << 5)
%define PIPECONF_BPC_8        (1 << 5)
%define PIPECONF_BPC_10       (2 << 5)
%define PIPECONF_BPC_12       (3 << 5)
%define PIPECONF_DITHER_EN    (1 << 4)

; ─── Transcoder timing registers (offset = base + pipe*0x1000) ─────
%define _TRANSCODER_A          0x60000
%define _TRANSCODER_B          0x61000
%define _TRANSCODER_C          0x62000

%define HTOTAL(pipe)          (_TRANSCODER_A + (pipe << 12))
%define HBLANK(pipe)          (_TRANSCODER_A + (pipe << 12) + 0x04)
%define HSYNC(pipe)           (_TRANSCODER_A + (pipe << 12) + 0x08)
%define VTOTAL(pipe)          (_TRANSCODER_A + (pipe << 12) + 0x0C)
%define VBLANK(pipe)          (_TRANSCODER_A + (pipe << 12) + 0x10)
%define VSYNC(pipe)           (_TRANSCODER_A + (pipe << 12) + 0x14)
%define BLC_PWM_CTL(pipe)     (_TRANSCODER_A + (pipe << 12) + 0x50)
%define BLC_PWM_DUTY(pipe)    (_TRANSCODER_A + (pipe << 12) + 0x54)

; ─── DDI port registers (DDI A = eDP on Surface Go) ───────────────
%define _DDI_A                 0x64000
%define _DDI_B                 0x65000
%define _DDI_C                 0x66000

%define DDI_BUF_CTL(port)     (_DDI_A + (port << 12))
%define DDI_CLK_SEL(port)     (_DDI_A + (port << 12) + 0x08)
%define DDI_BUF_TRANS(port)   (_DDI_A + (port << 12) + 0x0C)

%define DDI_BUF_CTL_ENABLE    (1 << 31)
%define DDI_BUF_CTL_IDLE      (1 << 7)
%define DDI_BUF_CTL_TC_1_64   (0 << 24)  ; training pattern
%define DDI_BUF_CTL_TC_2_64   (1 << 24)
%define DDI_BUF_CTL_TC_3_64   (4 << 24)
%define DDI_CLK_SEL_DDI       (0)        ; DDI clock from DPLL
%define DDI_CLK_SEL_NONE      (0x80000000) ; no clock

; ─── DPLL registers (Gen9/KBL) ─────────────────────────────────────
%define DPLL_CTRL1            0x6C058
%define DPLL_CTRL2            0x6C05C
%define DPLL_STATUS           0x6C060
%define DPLL_CFGCR0(dpll)     (0x6C068 + (dpll * 8))
%define DPLL_CFGCR1(dpll)     (0x6C06C + (dpll * 8))
%define DPLL_ENABLE(dpll)     (0x6C080 + (dpll * 0x100))
%define LCPLL1_CTL            0x46010  ; PCH LCPLL1

; DPLL_CTRL1 bits: each 4 bits per DPLL (0=LCPLL1, 1=DPLL1, 2=DPLL2, 3=DPLL3)
; Link rate selection per DPLL:
%define DPLL_CTRL1_LINK_RATE_2700 (0 << 9) ; 2.7 Gbps (HBR)
%define DPLL_CTRL1_LINK_RATE_5400 (1 << 9) ; 5.4 Gbps (HBR2)
%define DPLL_CTRL1_LINK_RATE_8100 (2 << 9) ; 8.1 Gbps (HBR3)

; DPLL_CTRL2 bits:
%define DPLL_CTRL2_DDI_CLK_OFF(dpll) (1 << (dpll + 15))
%define DPLL_CTRL2_DDI_SEL_SHIFT(dpll) (dpll * 3 + 6)
%define DPLL_CTRL2_DDI_SEL_MASK(dpll) (7 << (dpll * 3 + 6))
%define DPLL_CTRL2_DDI_SEL_EDP(dpll) (0 << (dpll * 3 + 6))
%define DPLL_CTRL2_DDI_SEL_DDI(dpll, port) ((port+1) << (dpll * 3 + 6))

; DPLL_ENABLE bits:
%define DPLL_ENABLE_ENABLE    (1 << 31)
%define DPLL_ENABLE_LOCK      (1 << 30)

; ─── CDCLK control (Gen9/KBL) ──────────────────────────────────────
%define CDCLK_CTL             0x46000
%define CDCLK_FREQ_DECIMAL    (1 << 26) ; decimal frequency select
%define CDCLK_FREQ_SEL_SHIFT  12
%define CDCLK_FREQ_SEL_MASK   (0xF << 12)
%define CDCLK_FREQ_337_5      (0x3 << 12) ; 337.5 MHz
%define CDCLK_FREQ_450        (0x4 << 12) ; 450 MHz
%define CDCLK_FREQ_540        (0x5 << 12) ; 540 MHz
%define CDCLK_FREQ_308_57     (0x6 << 12) ; 308.57 MHz
%define CDCLK_FREQ_617_14     (0x7 << 12) ; 617.14 MHz

; ─── GTT / aperture ────────────────────────────────────────────────
; The GTT (Graphics Translation Table) is at offset 0 within BAR0
; Each GTT entry is 8 bytes
; Physical addresses are written to GTT entries, then the GPU translates
; aperture accesses through the GTT.
;
; For a simple linear framebuffer, we can:
; 1. Program GTT entry 0 to point to a physical page
; 2. Set PLANE_SURF to the aperture offset of that GTT entry
;
; The aperture is accessible via BAR2.
; To write to the framebuffer, we write to BAR2 + GTT_offset.

; ─── GTT programming (via BAR0) ────────────────────────────────────
; GTT base offset within BAR0 (for KBL):
%define GTT_BASE              0x00000000  ; GTT starts at BAR0+0
; Each GTTE = 8 bytes: bits 11:0 = flags, bits 63:12 = physical addr >> 12
; GTTE format:
%define GTTE_PHYS_ADDR(addr)  ((addr >> 12) << 12)
%define GTTE_PRESENT          (1 << 0)

; ─── Framebuffer constants for Surface Go 1 (1800×1200) ────────────
%define FB_WIDTH              1800
%define FB_HEIGHT             1200
%define FB_BPP                32
%define FB_STRIDE             (FB_WIDTH * 4)
%define FB_SIZE               (FB_HEIGHT * FB_STRIDE)  ; ~8.4 MB
%define FB_PAGES              (FB_SIZE / 4096)

; ─── Global control registers ──────────────────────────────────────
%define GFX_MODE              0x02520  ; GFX mode register
%define RING_MODE             0x0209C  ; XCS ring mode
%define MI_MODE               0x0209C  ; MI mode
%define FORCE_WAKE_CTL        0x0A278  ; force wake control
%define FORCE_WAKE_ACK        0x0A27C  ; force wake acknowledge
%define ECO_CHICKEN           0x02064
%define GTFIFODBG             0x01208  ; GT FIFO debug

; ─── Global GTT (GGTT) registers ───────────────────────────────────
%define GGTT_BASE             0x000000  ; offset within GTTMMADR (BAR0)
%define GGTT_SIZE_SHIFT       4
%define GGTT_PTE_SIZE         8        ; 64-bit PTE
