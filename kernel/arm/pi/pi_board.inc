; Raspberry Pi board profiles — constants from pi_board.zig
; Target: ARM (arm-none-eabi-as)
;
; Two board profiles:
;   pi_zero_w_v1_1  — BCM2835 (ARM1176JZF-S), peripheral base 0x2000_0000
;   pi_zero_2_w     — BCM2837 (Cortex-A53), peripheral base 0x3f00_0000

; ---- peripheral base addresses ----
%define PI_ZERO_W_V1_1_PERIPHERAL_BASE    0x20000000
%define PI_ZERO_2_W_PERIPHERAL_BASE       0x3f000000

; ---- peripheral register offsets (from peripheral_base) ----
; GPIO
%define PI_GPIO_OFFSET      0x00200000
%define PI_GPIO_BYTES       0xb4

; SDHOST (SD card controller, simpler but slower)
%define PI_SDHOST_OFFSET    0x00202000
%define PI_SDHOST_BYTES     0x100

; EMMC (SD card controller, full-featured)
%define PI_EMMC_OFFSET      0x00300000
%define PI_EMMC_BYTES       0x100

; AUX (mini UART, SPI1, SPI2)
%define PI_AUX_OFFSET       0x00215000
%define PI_AUX_BYTES        0x100

; Mailbox (VideoCore GPU communication)
%define PI_MAILBOX_OFFSET   0x0000b880
%define PI_MAILBOX_BYTES    0x24

; PL011 UART (primary UART on Pi)
%define PI_PL011_OFFSET     0x00201000
%define PI_PL011_BYTES      0x100

; Mailbox property channel
%define PI_MAILBOX_PROPERTY_CHANNEL        8
%define PI_MAILBOX_REQUEST_CODE            0

; Mailbox property tags
%define PI_TAG_GET_BOARD_MODEL             0x00010001
%define PI_TAG_GET_ARM_MEMORY              0x00010005
%define PI_TAG_GET_CLOCK_RATE              0x00030002
%define PI_TAG_SET_CLOCK_RATE              0x00038002
%define PI_TAG_LAST                        0

; ---- absolute peripheral addresses (pi_zero_w_v1_1) ----
%define PI_ZERO_W_GPIO      (PI_ZERO_W_V1_1_PERIPHERAL_BASE + PI_GPIO_OFFSET)
%define PI_ZERO_W_SDHOST    (PI_ZERO_W_V1_1_PERIPHERAL_BASE + PI_SDHOST_OFFSET)
%define PI_ZERO_W_EMMC      (PI_ZERO_W_V1_1_PERIPHERAL_BASE + PI_EMMC_OFFSET)
%define PI_ZERO_W_AUX       (PI_ZERO_W_V1_1_PERIPHERAL_BASE + PI_AUX_OFFSET)
%define PI_ZERO_W_MAILBOX   (PI_ZERO_W_V1_1_PERIPHERAL_BASE + PI_MAILBOX_OFFSET)
%define PI_ZERO_W_PL011     (PI_ZERO_W_V1_1_PERIPHERAL_BASE + PI_PL011_OFFSET)

; ---- absolute peripheral addresses (pi_zero_2_w) ----
%define PI_ZERO2_GPIO       (PI_ZERO_2_W_PERIPHERAL_BASE + PI_GPIO_OFFSET)
%define PI_ZERO2_SDHOST     (PI_ZERO_2_W_PERIPHERAL_BASE + PI_SDHOST_OFFSET)
%define PI_ZERO2_EMMC       (PI_ZERO_2_W_PERIPHERAL_BASE + PI_EMMC_OFFSET)
%define PI_ZERO2_AUX        (PI_ZERO_2_W_PERIPHERAL_BASE + PI_AUX_OFFSET)
%define PI_ZERO2_MAILBOX    (PI_ZERO_2_W_PERIPHERAL_BASE + PI_MAILBOX_OFFSET)
%define PI_ZERO2_PL011      (PI_ZERO_2_W_PERIPHERAL_BASE + PI_PL011_OFFSET)

; ---- WiFi / Bluetooth chip types ----
%define WIFI_NONE           0
%define WIFI_CYW43438_SDIO  1
%define WIFI_CYW43439_SDIO  2

%define BT_NONE             0
%define BT_CYW43438_HCI     1
%define BT_CYW43439_HCI     2

; Pi Zero W v1.1:  CYW43438 (SDIO WiFi + HCI UART Bluetooth)
; Pi Zero 2 W:     CYW43439 (SDIO WiFi + HCI UART Bluetooth)
