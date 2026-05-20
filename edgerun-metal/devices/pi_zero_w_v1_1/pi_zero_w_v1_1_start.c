#include "er_pi_zero_w_v1_1_uart.h"
#include "er_cyw43438_d11.h"
#include "er_cyw43438_owned_firmware.h"
#include "er_types.h"

/*
 * Purpose: provide the first owned ARMv6 payload for Raspberry Pi Zero W v1.1.
 * Intention: emit relay node-control state as erwire bytes over the bootstrap
 * UART carrier until the CYW43438 L2 relay carrier is ready.
 */

#define ER_PI_ZERO_W_V1_1_BOOT_MAGIC 0x45525a57u
#define ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC 0x31575245u
#define ER_PI_ZERO_W_V1_1_ERWIRE_VERSION 1u
#define ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE 32u
#define ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_FIRST 0x0001u
#define ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_LAST 0x0002u
#define ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_AVAILABLE 37u
#define ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_HEARTBEAT 38u
#define ER_PI_ZERO_W_V1_1_ERWIRE_STREAM_ID 0x45525a57u
#define ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION 1u
#define ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY 1u
#define ER_PI_ZERO_W_V1_1_CHANNEL_KIND_WIFI_OPEN_L2 14u
#define ER_PI_ZERO_W_V1_1_HEARTBEAT_SECS 10u
#define ER_PI_ZERO_W_V1_1_NODE_BYTES 32u
#define ER_PI_ZERO_W_V1_1_HASH_BYTES 32u
#define ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN 64u
#define ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN 54u
#define ER_PI_ZERO_W_V1_1_IEEE80211_DA_OFFSET 4u
#define ER_PI_ZERO_W_V1_1_IEEE80211_SA_OFFSET 10u
#define ER_PI_ZERO_W_V1_1_IEEE80211_BSSID_OFFSET 16u
#define ER_PI_ZERO_W_V1_1_IEEE80211_SEQUENCE_OFFSET 22u
#define ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_FIXED_OFFSET 24u
#define ER_PI_ZERO_W_V1_1_IEEE80211_SSID_IE_OFFSET 36u
#define ER_PI_ZERO_W_V1_1_IEEE80211_RATES_IE_OFFSET 57u
#define ER_PI_ZERO_W_V1_1_IEEE80211_DS_IE_OFFSET 63u
#define ER_PI_ZERO_W_V1_1_IEEE80211_ADDR_BROADCAST 0xffu
#define ER_PI_ZERO_W_V1_1_IEEE80211_FC_BEACON 0x80u
#define ER_PI_ZERO_W_V1_1_IEEE80211_FC_PROBE_REQUEST 0x40u
#define ER_PI_ZERO_W_V1_1_IEEE80211_IE_SSID 0u
#define ER_PI_ZERO_W_V1_1_IEEE80211_IE_SUPPORTED_RATES 1u
#define ER_PI_ZERO_W_V1_1_IEEE80211_IE_DS 3u
#define ER_PI_ZERO_W_V1_1_IEEE80211_SUPPORTED_RATE_COUNT 4u
#define ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_INTERVAL_TU 100u
#define ER_PI_ZERO_W_V1_1_IEEE80211_CAPABILITY_ESS 1u
#define ER_PI_ZERO_W_V1_1_IEEE80211_RATE_1M 0x82u
#define ER_PI_ZERO_W_V1_1_IEEE80211_RATE_2M 0x84u
#define ER_PI_ZERO_W_V1_1_IEEE80211_RATE_5M5 0x8bu
#define ER_PI_ZERO_W_V1_1_IEEE80211_RATE_11M 0x96u
#define ER_PI_ZERO_W_V1_1_CYW_TX_STATUS_EXPECTED \
  ((ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN << \
    ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_LEN_SHIFT) | \
   ER_PI_ZERO_W_V1_1_IEEE80211_FC_BEACON)
#define ER_PI_ZERO_W_V1_1_CYW_RX_STATUS_EXPECTED \
  ((ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN << \
    ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_LEN_SHIFT) | \
   ER_PI_ZERO_W_V1_1_IEEE80211_FC_PROBE_REQUEST)
#define ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES 189u
#define ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES 116u
#define ER_PI_ZERO_W_V1_1_CRC32_INITIAL 0xffffffffu
#define ER_PI_ZERO_W_V1_1_CRC32_POLY 0xedb88320u
#define ER_PI_ZERO_W_V1_1_CRC32_BITS_PER_BYTE 8u
#define ER_PI_ZERO_W_V1_1_BYTE_MASK 0xffu
#define ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT 8u
#define ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT 16u
#define ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT 24u
#define ER_PI_ZERO_W_V1_1_U64_BYTE4_SHIFT 32u
#define ER_PI_ZERO_W_V1_1_U64_BYTE5_SHIFT 40u
#define ER_PI_ZERO_W_V1_1_U64_BYTE6_SHIFT 48u
#define ER_PI_ZERO_W_V1_1_U64_BYTE7_SHIFT 56u
#define ER_PI_ZERO_W_V1_1_BOOT_MS 0u
#define ER_PI_ZERO_W_V1_1_WIFI_GPIO_DELAY_TICKS 150u
#define ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS 400000u
#define ER_PI_ZERO_W_V1_1_SDIO_POLL_BUDGET 1000000u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_NONE 0u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD0_DONE 1u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD5_DONE 2u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD3_DONE 3u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD7_DONE 4u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD52_DONE 5u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD53_DONE 6u
#define ER_PI_ZERO_W_V1_1_L2_READY 7u
#define ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR 0xffffffffu
#define ER_PI_ZERO_W_V1_1_LED_BOOT_ENTRY 1u
#define ER_PI_ZERO_W_V1_1_LED_UART_READY 2u
#define ER_PI_ZERO_W_V1_1_LED_WIFI_POWERED 3u
#define ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_OK 7u
#define ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_FAIL 11u
#define ER_PI_ZERO_W_V1_1_LED_STEP_DELAY_TICKS 250000u
#define ER_PI_ZERO_W_V1_1_EMMC_RESET_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_EMMC_STABLE_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_ENABLE_ADDR 0x00000002u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_READY_ADDR 0x00000003u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_1 0x02u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_2 0x04u
#define ER_PI_ZERO_W_V1_1_CYW43438_READY_POLL_BUDGET 10000u
#define ER_PI_ZERO_W_V1_1_CYW43438_ALP_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_CYW43438_RESET_POLL_BUDGET 1000u
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRLOW 0x0001000au
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRMID 0x0001000bu
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRHIGH 0x0001000cu
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR 0x0001000eu
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SDIOPULLUP 0x0001000fu
#define ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HW_CLKREQ_OFF 0x20u
#define ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL_REQ 0x08u
#define ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL 0x40u
#define ER_PI_ZERO_W_V1_1_CYW43438_FORCE_ALP 0x01u
#define ER_PI_ZERO_W_V1_1_CYW43438_SBWINDOW_MASK 0xffff8000u
#define ER_PI_ZERO_W_V1_1_CYW43438_SB_ADDR_MASK 0x00007fffu
#define ER_PI_ZERO_W_V1_1_CYW43438_SB_ACCESS_2_4B_FLAG 0x00008000u
#define ER_PI_ZERO_W_V1_1_CYW43438_RAM_BASE 0x00000000u
#define ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE 0x00080000u
#define ER_PI_ZERO_W_V1_1_CYW43438_RAM_CHUNK_BYTES 256u
#define ER_PI_ZERO_W_V1_1_CYW43438_CHIPCOMMON_BASE 0x18000000u
#define ER_PI_ZERO_W_V1_1_CYW43438_CHIPCOMMON_EROMPTR 0x000000fcu
#define ER_PI_ZERO_W_V1_1_CYW43438_CORE_ARM_CM3 0x082au
#define ER_PI_ZERO_W_V1_1_CYW43438_CORE_INTERNAL_MEM 0x080eu
#define ER_PI_ZERO_W_V1_1_CYW43438_CORE_80211 0x0812u
#define ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL 0x00000408u
#define ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_CLK 0x00000001u
#define ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_FGC 0x00000002u
#define ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL 0x00000800u
#define ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL_RESET 0x00000001u
#define ER_PI_ZERO_W_V1_1_CYW43438_D11_IOCTL_PHYCLOCKEN 0x00000004u
#define ER_PI_ZERO_W_V1_1_CYW43438_D11_IOCTL_PHYRESET 0x00000008u
#define ER_PI_ZERO_W_V1_1_CYW43438_SOCRAM_BANKIDX 0x00000010u
#define ER_PI_ZERO_W_V1_1_CYW43438_SOCRAM_BANKPDA 0x00000044u
#define ER_PI_ZERO_W_V1_1_CYW43438_SOCRAM_REMAP_BANK 3u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_TYPE_MASK 0x0000000fu
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_VALID 0x00000001u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_COMPONENT 0x00000001u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_MASTER_PORT 0x00000003u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRESS 0x00000005u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRSIZE_GT32 0x00000008u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_EOT 0x0000000fu
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_PARTNUM 0x000fff00u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_PARTNUM_SHIFT 8u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_SWRAP 0x00f80000u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_SWRAP_SHIFT 19u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_MWRAP 0x0007c000u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_MWRAP_SHIFT 14u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_ADDR_BASE 0xfffff000u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE 0x000000c0u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_SHIFT 6u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_SLAVE 0u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_SWRAP 2u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_MWRAP 3u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_TYPE 0x00000030u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_TYPE_SHIFT 4u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_4K 0u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_8K 1u
#define ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_DESC 3u
#define ER_PI_ZERO_W_V1_1_L2_OWNED_FIRMWARE_LOADED 12u
#define ER_PI_ZERO_W_V1_1_L2_CM3_ACTIVE 13u
#define ER_PI_ZERO_W_V1_1_L2_D11_TX_FIFO_READY 14u
#define ER_PI_ZERO_W_V1_1_L2_D11_TX_TEMPLATE_LOADED 15u
#define ER_PI_ZERO_W_V1_1_L2_D11_TX_PIO_ATTEMPTED 16u

volatile UINT32 g_er_pi_zero_w_v1_1_boot_magic =
    ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_probe_state =
    ER_PI_ZERO_W_V1_1_SDIO_PROBE_NONE;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_probe_interrupt = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_probe_response = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_relative_card_address = 0u;

static const UINT8 g_er_pi_zero_w_v1_1_node_id[ER_PI_ZERO_W_V1_1_NODE_BYTES] = {
  0x45u, 0x52u, 0x5au, 0x57u, 0x50u, 0x49u, 0x30u, 0x31u,
  0x52u, 0x45u, 0x4cu, 0x41u, 0x59u, 0x30u, 0x30u, 0x31u,
  0x43u, 0x59u, 0x57u, 0x34u, 0x33u, 0x34u, 0x33u, 0x38u,
  0x41u, 0x52u, 0x4du, 0x56u, 0x36u, 0x4cu, 0x32u, 0x01u
};

static const UINT8 g_er_pi_zero_w_v1_1_channel_id[ER_PI_ZERO_W_V1_1_HASH_BYTES] = {
  0x45u, 0x52u, 0x57u, 0x49u, 0x46u, 0x49u, 0x4cu, 0x32u,
  0x50u, 0x49u, 0x5au, 0x45u, 0x52u, 0x4fu, 0x57u, 0x31u,
  0x43u, 0x48u, 0x41u, 0x4eu, 0x4eu, 0x45u, 0x4cu, 0x30u,
  0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x31u
};

static UINT32 er_pi_zero_w_v1_1_wifi_beacon(
    UINT8 out_frame[ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN]);
static UINT32 er_pi_zero_w_v1_1_wifi_probe_request(
    UINT8 out_frame[ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN]);

static volatile UINT32* er_pi_zero_w_v1_1_reg(UINT32 base, UINT32 offset) {
  return (volatile UINT32*)(UINTN)(base + offset);
}

static UINT32 er_pi_zero_w_v1_1_read(UINT32 base, UINT32 offset) {
  return *er_pi_zero_w_v1_1_reg(base, offset);
}

static void er_pi_zero_w_v1_1_write(UINT32 base, UINT32 offset, UINT32 value) {
  *er_pi_zero_w_v1_1_reg(base, offset) = value;
}

static void er_pi_zero_w_v1_1_barrier(void) {
  __asm__ volatile("" ::: "memory");
}

static void er_pi_zero_w_v1_1_delay(UINT32 ticks) {
  volatile UINT32 i;

  for (i = 0u; i < ticks; ++i) {
    __asm__ volatile("nop" ::: "memory");
  }
}

static void er_pi_zero_w_v1_1_act_led_init(void) {
  UINT32 fsel4;

  fsel4 = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                 ER_PI_ZERO_W_V1_1_GPIO_GPFSEL4);
  fsel4 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel4,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_ACT_LED,
                              ER_PI_ZERO_W_V1_1_GPIO_OUTPUT);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPFSEL4,
                          fsel4);
}

static void er_pi_zero_w_v1_1_act_led_on(void) {
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPCLR1,
                          ER_PI_ZERO_W_V1_1_GPIO_SET_ACT_LED);
}

static void er_pi_zero_w_v1_1_act_led_off(void) {
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPSET1,
                          ER_PI_ZERO_W_V1_1_GPIO_SET_ACT_LED);
}

static void er_pi_zero_w_v1_1_act_led_status(UINT32 count) {
  UINT32 i;

  for (i = 0u; i < count; ++i) {
    er_pi_zero_w_v1_1_act_led_on();
    er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_LED_STEP_DELAY_TICKS);
    er_pi_zero_w_v1_1_act_led_off();
    er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_LED_STEP_DELAY_TICKS);
  }
}

static void er_pi_zero_w_v1_1_uart_gpio_init(void) {
  UINT32 fsel1;

  fsel1 = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                 ER_PI_ZERO_W_V1_1_GPIO_GPFSEL1);
  fsel1 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel1,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_UART_TX,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT5);
  fsel1 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel1,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_UART_RX,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT5);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPFSEL1,
                          fsel1);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPPUD,
                          ER_PI_ZERO_W_V1_1_GPIO_PULL_DISABLE);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPPUDCLK0,
                          ER_PI_ZERO_W_V1_1_GPIO_PULL_CLOCK_UART);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPPUDCLK0,
                          ER_PI_ZERO_W_V1_1_GPIO_PULL_DISABLE);
}

static void er_pi_zero_w_v1_1_uart_init(void) {
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_ENABLES,
                          ER_PI_ZERO_W_V1_1_AUX_ENABLE_MINI_UART);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_CNTL,
                          ER_PI_ZERO_W_V1_1_AUX_MU_DISABLE);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_IER,
                          ER_PI_ZERO_W_V1_1_AUX_MU_DISABLE_INTERRUPTS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_LCR,
                          ER_PI_ZERO_W_V1_1_AUX_MU_EIGHT_BIT_MODE);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_MCR,
                          ER_PI_ZERO_W_V1_1_AUX_MU_RTS_HIGH);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_IIR,
                          ER_PI_ZERO_W_V1_1_AUX_MU_CLEAR_FIFOS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_BAUD,
                          ER_PI_ZERO_W_V1_1_AUX_MU_BAUD_115200_CORE_250MHZ);
  er_pi_zero_w_v1_1_uart_gpio_init();
  er_pi_zero_w_v1_1_barrier();
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_CNTL,
                          ER_PI_ZERO_W_V1_1_AUX_MU_ENABLE_TX_RX);
}

static void er_pi_zero_w_v1_1_wifi_gpio_init(void) {
  UINT32 fsel3;
  UINT32 fsel4;

  fsel3 = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                 ER_PI_ZERO_W_V1_1_GPIO_GPFSEL3);
  fsel3 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel3,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_SDIO_CLK,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT3);
  fsel3 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel3,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_SDIO_CMD,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT3);
  fsel3 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel3,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_SDIO_DAT0,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT3);
  fsel3 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel3,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_SDIO_DAT1,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT3);
  fsel3 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel3,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_SDIO_DAT2,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT3);
  fsel3 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel3,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_SDIO_DAT3,
                              ER_PI_ZERO_W_V1_1_GPIO_ALT3);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPFSEL3,
                          fsel3);

  fsel4 = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                 ER_PI_ZERO_W_V1_1_GPIO_GPFSEL4);
  fsel4 = er_pi_zero_w_v1_1_gpio_fsel_alt(fsel4,
                              ER_PI_ZERO_W_V1_1_GPIO_PIN_WIFI_REG_ON,
                              ER_PI_ZERO_W_V1_1_GPIO_OUTPUT);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPFSEL4,
                          fsel4);

  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPPUD,
                          ER_PI_ZERO_W_V1_1_GPIO_PULL_DISABLE);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPPUDCLK1,
                          ER_PI_ZERO_W_V1_1_GPIO_PULL_CLOCK_WIFI_SDIO);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPPUDCLK1,
                          ER_PI_ZERO_W_V1_1_GPIO_PULL_DISABLE);

  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_ZERO_W_V1_1_GPIO_GPSET1,
                          ER_PI_ZERO_W_V1_1_GPIO_SET_WIFI_REG_ON);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  er_pi_zero_w_v1_1_barrier();
}

static UINT32 er_pi_zero_w_v1_1_emmc_response_bits(UINT32 response_kind) {
  switch (response_kind) {
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_NONE:
      return ER_PI_ZERO_W_V1_1_EMMC_CMDTM_RESPONSE_NONE;
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R4:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6:
      return ER_PI_ZERO_W_V1_1_EMMC_CMDTM_RESPONSE_48;
    default:
      return ER_PI_ZERO_W_V1_1_EMMC_CMDTM_RESPONSE_NONE;
  }
}

static UINT32 er_pi_zero_w_v1_1_emmc_command_value(UINT32 command_index,
                                                   UINT32 response_kind) {
  UINT32 value;

  value = command_index << ER_PI_ZERO_W_V1_1_EMMC_CMDTM_INDEX_BITS;
  value |= er_pi_zero_w_v1_1_emmc_response_bits(response_kind) <<
           ER_PI_ZERO_W_V1_1_EMMC_CMDTM_RESPONSE_BITS;
  switch (response_kind) {
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6:
      value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_CRC_CHECK;
      value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_INDEX_CHECK;
      break;
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_NONE:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R4:
    default:
      break;
  }
  return value;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_command_value(UINT32 command_index,
                                                        UINT32 response_kind,
                                                        UINT32 data_read) {
  UINT32 value;

  value = er_pi_zero_w_v1_1_emmc_command_value(command_index, response_kind);
  value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_BLOCK_COUNT_ENABLE;
  value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_IS_DATA;
  if (data_read != 0u) {
    value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_DATA_READ;
  }
  return value;
}

static UINT32 er_pi_zero_w_v1_1_emmc_control1_ident_clock(void) {
  UINT32 divisor = ER_PI_ZERO_W_V1_1_EMMC_IDENT_CLOCK_DIVISOR;
  UINT32 control;

  control = ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_INTLEN |
            ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_GENSEL |
            (ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_DATA_TOUNIT_MAX <<
             ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_DATA_TOUNIT_SHIFT);
  control |= (divisor & ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_FREQ8_MASK) <<
             ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_FREQ8_SHIFT;
  control |= (divisor & ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_FREQ_MS2_MASK) >>
             ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_FREQ_MS2_SHIFT;
  return control;
}

static UINT32 er_pi_zero_w_v1_1_emmc_wait_clear(UINT32 offset,
                                                UINT32 mask,
                                                UINT32 poll_budget) {
  UINT32 poll;

  for (poll = 0u; poll < poll_budget; ++poll) {
    if ((er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE, offset) &
         mask) == 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_wait_set(UINT32 offset,
                                              UINT32 mask,
                                              UINT32 poll_budget) {
  UINT32 poll;

  for (poll = 0u; poll < poll_budget; ++poll) {
    if ((er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE, offset) &
         mask) == mask) {
      return 1u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_init(void) {
  UINT32 control1;

  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_CONTROL1,
                          ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_SRST_HC);
  if (er_pi_zero_w_v1_1_emmc_wait_clear(
          ER_PI_ZERO_W_V1_1_EMMC_REG_CONTROL1,
          ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_SRST_HC,
          ER_PI_ZERO_W_V1_1_EMMC_RESET_POLL_BUDGET) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_IRPT_EN,
                          0u);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_IRPT_MASK,
                          0u);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ALL);
  control1 =
      er_pi_zero_w_v1_1_emmc_control1_ident_clock();
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_CONTROL1,
                          control1);
  if (er_pi_zero_w_v1_1_emmc_wait_set(
          ER_PI_ZERO_W_V1_1_EMMC_REG_CONTROL1,
          ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_STABLE,
          ER_PI_ZERO_W_V1_1_EMMC_STABLE_POLL_BUDGET) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_CONTROL1,
                          control1 | ER_PI_ZERO_W_V1_1_EMMC_CONTROL1_CLK_EN);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_wait_command(UINT32* out_interrupt) {
  UINT32 poll;
  UINT32 interrupt;

  if (out_interrupt == 0) {
    return 0u;
  }
  *out_interrupt = 0u;
  for (poll = 0u;
       poll < ER_PI_ZERO_W_V1_1_SDIO_POLL_BUDGET;
       ++poll) {
    interrupt = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                       ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT);
    if ((interrupt & ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ERROR_MASK) != 0u ||
        (interrupt & ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_CMD_DONE) != 0u) {
      *out_interrupt = interrupt;
      return (UINT32)((interrupt & ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ERROR_MASK) == 0u);
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_command(UINT32 command_index,
                                             UINT32 argument,
                                             UINT32 response_kind,
                                             UINT32* out_response) {
  UINT32 interrupt;
  UINT32 ok;

  if (out_response == 0) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_emmc_wait_clear(
          ER_PI_ZERO_W_V1_1_EMMC_REG_STATUS,
          ER_PI_ZERO_W_V1_1_EMMC_STATUS_CMD_INHIBIT | ER_PI_ZERO_W_V1_1_EMMC_STATUS_DATA_INHIBIT,
          ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET) == 0u) {
    return 0u;
  }
  *out_response = 0u;
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ALL);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_ARG1,
                          argument);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_CMDTM,
      er_pi_zero_w_v1_1_emmc_command_value(command_index, response_kind));
  ok = er_pi_zero_w_v1_1_emmc_wait_command(&interrupt);
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
  if (ok == 0u) {
    return 0u;
  }
  if (response_kind != ER_PI_ZERO_W_V1_1_MMC_RESPONSE_NONE) {
    *out_response = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                           ER_PI_ZERO_W_V1_1_EMMC_REG_RESP0);
    g_er_pi_zero_w_v1_1_sdio_probe_response = *out_response;
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          interrupt);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_mmc_rca_argument(UINT32 relative_card_address) {
  return (relative_card_address & ER_PI_ZERO_W_V1_1_MMC_RCA_MASK) <<
         ER_PI_ZERO_W_V1_1_MMC_RCA_RESPONSE_SHIFT;
}

static UINT32 er_pi_zero_w_v1_1_sdio_cmd52_argument(UINT32 write,
                                                    UINT32 function,
                                                    UINT32 raw,
                                                    UINT32 address,
                                                    UINT8 data) {
  UINT32 argument = 0u;

  if (write != ER_PI_ZERO_W_V1_1_SDIO_CMD52_READ) {
    argument |= 1u << ER_PI_ZERO_W_V1_1_SDIO_RW_FLAG_BIT;
  }
  argument |= ((function & ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_MASK) <<
               ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BITS);
  if (raw != ER_PI_ZERO_W_V1_1_SDIO_CMD52_NO_RAW) {
    argument |= 1u << ER_PI_ZERO_W_V1_1_SDIO_RAW_FLAG_BIT;
  }
  argument |= (address & ER_PI_ZERO_W_V1_1_SDIO_ADDRESS_MASK) <<
              ER_PI_ZERO_W_V1_1_SDIO_ADDRESS_BITS;
  argument |= (UINT32)data & ER_PI_ZERO_W_V1_1_SDIO_CMD52_DATA_MASK;
  return argument;
}

static UINT32 er_pi_zero_w_v1_1_sdio_cmd53_argument(UINT32 write,
                                                    UINT32 function,
                                                    UINT32 block_mode,
                                                    UINT32 incrementing,
                                                    UINT32 address,
                                                    UINT32 count) {
  UINT32 argument = 0u;

  if (write != ER_PI_ZERO_W_V1_1_SDIO_CMD53_READ) {
    argument |= 1u << ER_PI_ZERO_W_V1_1_SDIO_RW_FLAG_BIT;
  }
  argument |= ((function & ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_MASK) <<
               ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BITS);
  if (block_mode != ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE) {
    argument |= 1u << ER_PI_ZERO_W_V1_1_SDIO_BLOCK_MODE_BIT;
  }
  if (incrementing != ER_PI_ZERO_W_V1_1_SDIO_CMD53_FIXED_ADDRESS) {
    argument |= 1u << ER_PI_ZERO_W_V1_1_SDIO_INCREMENTING_ADDRESS_BIT;
  }
  argument |= (address & ER_PI_ZERO_W_V1_1_SDIO_ADDRESS_MASK) <<
              ER_PI_ZERO_W_V1_1_SDIO_ADDRESS_BITS;
  argument |= count & ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK;
  return argument;
}

static UINT32 er_pi_zero_w_v1_1_emmc_wait_interrupt(UINT32 wanted_interrupt,
                                                    UINT32* out_interrupt) {
  UINT32 poll;
  UINT32 interrupt;

  if (out_interrupt == 0 || wanted_interrupt == 0u) {
    return 0u;
  }
  *out_interrupt = 0u;
  for (poll = 0u;
       poll < ER_PI_ZERO_W_V1_1_SDIO_POLL_BUDGET;
       ++poll) {
    interrupt = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                       ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT);
    if ((interrupt & ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ERROR_MASK) != 0u) {
      *out_interrupt = interrupt;
      return 0u;
    }
    if ((interrupt & wanted_interrupt) != 0u) {
      *out_interrupt = interrupt;
      return 1u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_read_byte(UINT32 function,
                                                    UINT32 address,
                                                    UINT8* out_byte) {
  UINT32 interrupt;
  UINT32 response;
  UINT32 data;

  if (out_byte == 0 ||
      er_pi_zero_w_v1_1_emmc_wait_clear(
          ER_PI_ZERO_W_V1_1_EMMC_REG_STATUS,
          ER_PI_ZERO_W_V1_1_EMMC_STATUS_CMD_INHIBIT | ER_PI_ZERO_W_V1_1_EMMC_STATUS_DATA_INHIBIT,
          ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET) == 0u) {
    return 0u;
  }
  *out_byte = 0u;
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ALL);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_BLKSIZECNT,
      (1u << ER_PI_ZERO_W_V1_1_EMMC_BLOCK_COUNT_BITS) | 1u);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_ARG1,
      er_pi_zero_w_v1_1_sdio_cmd53_argument(ER_PI_ZERO_W_V1_1_SDIO_CMD53_READ,
                                            function,
                                            ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
                                            ER_PI_ZERO_W_V1_1_SDIO_CMD53_FIXED_ADDRESS,
                                            address,
                                            1u));
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_CMDTM,
      er_pi_zero_w_v1_1_emmc_sdio_command_value(ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_EXTENDED,
                                                ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
                                                1u));
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_READ_RDY,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  data = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                ER_PI_ZERO_W_V1_1_EMMC_REG_DATA);
  *out_byte = (UINT8)(data & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_DATA_DONE,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  response = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                    ER_PI_ZERO_W_V1_1_EMMC_REG_RESP0);
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
  g_er_pi_zero_w_v1_1_sdio_probe_response = response;
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          interrupt);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_write_byte(UINT32 function,
                                                     UINT32 address,
                                                     UINT8 byte) {
  UINT32 response;

  return er_pi_zero_w_v1_1_emmc_command(
      ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_DIRECT,
      er_pi_zero_w_v1_1_sdio_cmd52_argument(
          ER_PI_ZERO_W_V1_1_SDIO_CMD52_WRITE,
          function,
          ER_PI_ZERO_W_V1_1_SDIO_CMD52_NO_RAW,
          address,
          byte),
      ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
      &response);
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_read_direct(UINT32 function,
                                                      UINT32 address,
                                                      UINT8* out_byte) {
  UINT32 response;

  if (out_byte == 0 ||
      er_pi_zero_w_v1_1_emmc_command(
          ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_DIRECT,
          er_pi_zero_w_v1_1_sdio_cmd52_argument(
              ER_PI_ZERO_W_V1_1_SDIO_CMD52_READ,
              function,
              ER_PI_ZERO_W_V1_1_SDIO_CMD52_NO_RAW,
              address,
              0u),
          ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
          &response) == 0u) {
    return 0u;
  }
  *out_byte = (UINT8)(response & ER_PI_ZERO_W_V1_1_SDIO_CMD52_DATA_MASK);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_write_bytes(UINT32 function,
                                                      UINT32 address,
                                                      const UINT8* bytes,
                                                      UINT32 bytes_len) {
  UINT32 interrupt;
  UINT32 offset;

  if (bytes == 0 ||
      bytes_len == 0u ||
      bytes_len > ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK ||
      er_pi_zero_w_v1_1_emmc_wait_clear(
          ER_PI_ZERO_W_V1_1_EMMC_REG_STATUS,
          ER_PI_ZERO_W_V1_1_EMMC_STATUS_CMD_INHIBIT | ER_PI_ZERO_W_V1_1_EMMC_STATUS_DATA_INHIBIT,
          ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ALL);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_BLKSIZECNT,
      (1u << ER_PI_ZERO_W_V1_1_EMMC_BLOCK_COUNT_BITS) | bytes_len);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_ARG1,
      er_pi_zero_w_v1_1_sdio_cmd53_argument(ER_PI_ZERO_W_V1_1_SDIO_CMD53_WRITE,
                                            function,
                                            ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
                                            ER_PI_ZERO_W_V1_1_SDIO_CMD53_INCREMENTING_ADDRESS,
                                            address,
                                            bytes_len));
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_CMDTM,
      er_pi_zero_w_v1_1_emmc_sdio_command_value(ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_EXTENDED,
                                                ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
                                                0u));
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_WRITE_RDY,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  for (offset = 0u; offset < bytes_len; offset += (UINT32)sizeof(UINT32)) {
    UINT32 word = 0u;
    UINT32 byte_index;

    for (byte_index = 0u;
         byte_index < (UINT32)sizeof(UINT32) && offset + byte_index < bytes_len;
         ++byte_index) {
      word |= (UINT32)bytes[offset + byte_index] <<
              (byte_index * ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT);
    }
    er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                            ER_PI_ZERO_W_V1_1_EMMC_REG_DATA,
                            word);
  }
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_DATA_DONE,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
  g_er_pi_zero_w_v1_1_sdio_probe_response =
      er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                             ER_PI_ZERO_W_V1_1_EMMC_REG_RESP0);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          interrupt);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_read_bytes(UINT32 function,
                                                     UINT32 address,
                                                     UINT8* bytes,
                                                     UINT32 bytes_len) {
  UINT32 interrupt;
  UINT32 offset;

  if (bytes == 0 ||
      bytes_len == 0u ||
      bytes_len > ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK ||
      er_pi_zero_w_v1_1_emmc_wait_clear(
          ER_PI_ZERO_W_V1_1_EMMC_REG_STATUS,
          ER_PI_ZERO_W_V1_1_EMMC_STATUS_CMD_INHIBIT | ER_PI_ZERO_W_V1_1_EMMC_STATUS_DATA_INHIBIT,
          ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ALL);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_BLKSIZECNT,
      (1u << ER_PI_ZERO_W_V1_1_EMMC_BLOCK_COUNT_BITS) | bytes_len);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_ARG1,
      er_pi_zero_w_v1_1_sdio_cmd53_argument(ER_PI_ZERO_W_V1_1_SDIO_CMD53_READ,
                                            function,
                                            ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
                                            ER_PI_ZERO_W_V1_1_SDIO_CMD53_INCREMENTING_ADDRESS,
                                            address,
                                            bytes_len));
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_CMDTM,
      er_pi_zero_w_v1_1_emmc_sdio_command_value(ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_EXTENDED,
                                                ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
                                                1u));
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_READ_RDY,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  for (offset = 0u; offset < bytes_len; offset += (UINT32)sizeof(UINT32)) {
    UINT32 word;
    UINT32 byte_index;

    word = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                  ER_PI_ZERO_W_V1_1_EMMC_REG_DATA);
    for (byte_index = 0u;
         byte_index < (UINT32)sizeof(UINT32) && offset + byte_index < bytes_len;
         ++byte_index) {
      bytes[offset + byte_index] =
          (UINT8)((word >> (byte_index * ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT)) &
                  ER_PI_ZERO_W_V1_1_BYTE_MASK);
    }
  }
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_DATA_DONE,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
  g_er_pi_zero_w_v1_1_sdio_probe_response =
      er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                             ER_PI_ZERO_W_V1_1_EMMC_REG_RESP0);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          interrupt);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_read_le32(const UINT8* bytes) {
  return ((UINT32)bytes[0]) |
         ((UINT32)bytes[1] << ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) |
         ((UINT32)bytes[2] << ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) |
         ((UINT32)bytes[3] << ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT);
}

static void er_pi_zero_w_v1_1_cyw43438_put_le32(UINT8* bytes, UINT32 value) {
  bytes[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[2] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[3] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK);
}

static UINT16 er_pi_zero_w_v1_1_cyw43438_read_le16(const UINT8* bytes) {
  return (UINT16)(((UINT16)bytes[0]) |
                  ((UINT16)bytes[1] << ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT));
}

static void er_pi_zero_w_v1_1_cyw43438_put_le16(UINT8* bytes, UINT16 value) {
  bytes[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[1] = (UINT8)(((UINT32)value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_enable_function1(void) {
  UINT8 ready;
  UINT32 poll;

  if (er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_CCCR,
          ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_ENABLE_ADDR,
          ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_1) == 0u) {
    return 0u;
  }
  for (poll = 0u; poll < ER_PI_ZERO_W_V1_1_CYW43438_READY_POLL_BUDGET; ++poll) {
    if (er_pi_zero_w_v1_1_emmc_sdio_read_direct(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_CCCR,
            ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_READY_ADDR,
            &ready) != 0u &&
        (((UINT32)ready & ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_1) != 0u)) {
      return 1u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_buscoreprep(void) {
  UINT8 clock;
  UINT32 poll;

  if (er_pi_zero_w_v1_1_cyw43438_enable_function1() == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR,
          ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HW_CLKREQ_OFF |
          ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL_REQ) == 0u) {
    return 0u;
  }
  for (poll = 0u; poll < ER_PI_ZERO_W_V1_1_CYW43438_ALP_POLL_BUDGET; ++poll) {
    if (er_pi_zero_w_v1_1_emmc_sdio_read_direct(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
            ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR,
            &clock) != 0u &&
        (((UINT32)clock & ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL) != 0u)) {
      return er_pi_zero_w_v1_1_emmc_sdio_write_byte(
                 ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
                 ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR,
                 ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HW_CLKREQ_OFF |
                 ER_PI_ZERO_W_V1_1_CYW43438_FORCE_ALP) != 0u &&
             er_pi_zero_w_v1_1_emmc_sdio_write_byte(
                 ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
                 ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SDIOPULLUP,
                 0u) != 0u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_set_backplane_window(UINT32 address) {
  UINT32 window;

  window = address & ER_PI_ZERO_W_V1_1_CYW43438_SBWINDOW_MASK;
  return er_pi_zero_w_v1_1_emmc_sdio_write_byte(
             ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
             ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRLOW,
             (UINT8)((window >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK)) != 0u &&
         er_pi_zero_w_v1_1_emmc_sdio_write_byte(
             ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
             ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRMID,
             (UINT8)((window >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK)) != 0u &&
         er_pi_zero_w_v1_1_emmc_sdio_write_byte(
             ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
             ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRHIGH,
             (UINT8)((window >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
                     ER_PI_ZERO_W_V1_1_BYTE_MASK)) != 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_address(UINT32 address) {
  return (address & ER_PI_ZERO_W_V1_1_CYW43438_SB_ADDR_MASK) |
         ER_PI_ZERO_W_V1_1_CYW43438_SB_ACCESS_2_4B_FLAG;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
    UINT32 address,
    const UINT8* bytes,
    UINT32 bytes_len) {
  UINT32 offset;

  if (bytes == 0 || bytes_len == 0u) {
    return 0u;
  }
  offset = 0u;
  while (offset < bytes_len) {
    UINT32 chunk;
    UINT32 current_address;
    UINT32 window_remaining;

    current_address = address + offset;
    window_remaining = ER_PI_ZERO_W_V1_1_CYW43438_SB_ACCESS_2_4B_FLAG -
                       (current_address & ER_PI_ZERO_W_V1_1_CYW43438_SB_ADDR_MASK);
    chunk = bytes_len - offset;
    if (chunk > ER_PI_ZERO_W_V1_1_CYW43438_RAM_CHUNK_BYTES) {
      chunk = ER_PI_ZERO_W_V1_1_CYW43438_RAM_CHUNK_BYTES;
    }
    if (chunk > window_remaining) {
      chunk = window_remaining;
    }
    if (er_pi_zero_w_v1_1_cyw43438_set_backplane_window(current_address) == 0u ||
        er_pi_zero_w_v1_1_emmc_sdio_write_bytes(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
            er_pi_zero_w_v1_1_cyw43438_backplane_address(current_address),
            bytes + offset,
            chunk) == 0u) {
      return 0u;
    }
    offset += chunk;
  }
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_read32(UINT32 address,
                                                         UINT32* out_value) {
  UINT8 bytes[4];

  if (out_value == 0 ||
      er_pi_zero_w_v1_1_cyw43438_set_backplane_window(address) == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_read_bytes(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          er_pi_zero_w_v1_1_cyw43438_backplane_address(address),
          bytes,
          (UINT32)sizeof(bytes)) == 0u) {
    return 0u;
  }
  *out_value = er_pi_zero_w_v1_1_cyw43438_read_le32(bytes);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_write32(UINT32 address,
                                                          UINT32 value) {
  UINT8 bytes[4];

  er_pi_zero_w_v1_1_cyw43438_put_le32(bytes, value);
  return er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
      address,
      bytes,
      (UINT32)sizeof(bytes));
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_read16(UINT32 address,
                                                         UINT16* out_value) {
  UINT8 bytes[2];

  if (out_value == 0 ||
      er_pi_zero_w_v1_1_cyw43438_set_backplane_window(address) == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_read_bytes(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          er_pi_zero_w_v1_1_cyw43438_backplane_address(address),
          bytes,
          (UINT32)sizeof(bytes)) == 0u) {
    return 0u;
  }
  *out_value = er_pi_zero_w_v1_1_cyw43438_read_le16(bytes);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_write16(UINT32 address,
                                                          UINT16 value) {
  UINT8 bytes[2];

  er_pi_zero_w_v1_1_cyw43438_put_le16(bytes, value);
  return er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
      address,
      bytes,
      (UINT32)sizeof(bytes));
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_dmp_type(UINT32 descriptor) {
  UINT32 type;

  type = descriptor & ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_TYPE_MASK;
  if ((type & ~ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRSIZE_GT32) ==
      ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRESS) {
    return ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRESS;
  }
  return type;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_dmp_next(UINT32* erom_address,
                                                  UINT32* out_type,
                                                  UINT32* out_value) {
  UINT32 value;

  if (erom_address == 0 || out_type == 0 || out_value == 0 ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(*erom_address, &value) == 0u) {
    return 0u;
  }
  *erom_address += (UINT32)sizeof(UINT32);
  *out_value = value;
  *out_type = er_pi_zero_w_v1_1_cyw43438_dmp_type(value);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_dmp_regaddr(UINT32* erom_address,
                                                     UINT32* out_base,
                                                     UINT32* out_wrap) {
  UINT32 descriptor_type;
  UINT32 value;
  UINT32 wrap_type;

  if (erom_address == 0 || out_base == 0 || out_wrap == 0 ||
      er_pi_zero_w_v1_1_cyw43438_dmp_next(erom_address,
                                          &descriptor_type,
                                          &value) == 0u) {
    return 0u;
  }
  *out_base = 0u;
  *out_wrap = 0u;
  switch (descriptor_type) {
    case ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_MASTER_PORT:
      wrap_type = ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_MWRAP;
      break;
    case ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRESS:
      *erom_address -= (UINT32)sizeof(UINT32);
      wrap_type = ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_SWRAP;
      break;
    default:
      *erom_address -= (UINT32)sizeof(UINT32);
      return 0u;
  }

  while (*out_base == 0u || *out_wrap == 0u) {
    UINT32 size_type;
    UINT32 slave_type;

    do {
      if (er_pi_zero_w_v1_1_cyw43438_dmp_next(erom_address,
                                              &descriptor_type,
                                              &value) == 0u) {
        return 0u;
      }
      if (descriptor_type == ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_EOT) {
        *erom_address -= (UINT32)sizeof(UINT32);
        return 0u;
      }
    } while (descriptor_type != ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRESS &&
             descriptor_type != ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_COMPONENT);

    if (descriptor_type == ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_COMPONENT) {
      *erom_address -= (UINT32)sizeof(UINT32);
      return 1u;
    }
    if ((value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRSIZE_GT32) != 0u &&
        er_pi_zero_w_v1_1_cyw43438_dmp_next(erom_address,
                                            &descriptor_type,
                                            &value) == 0u) {
      return 0u;
    }
    size_type = (value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_TYPE) >>
                ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_TYPE_SHIFT;
    if (size_type == ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_DESC) {
      if (er_pi_zero_w_v1_1_cyw43438_dmp_next(erom_address,
                                              &descriptor_type,
                                              &value) == 0u) {
        return 0u;
      }
      if ((value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_ADDRSIZE_GT32) != 0u &&
          er_pi_zero_w_v1_1_cyw43438_dmp_next(erom_address,
                                              &descriptor_type,
                                              &value) == 0u) {
        return 0u;
      }
    }
    if (size_type != ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_4K &&
        size_type != ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_SIZE_8K) {
      continue;
    }
    slave_type = (value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE) >>
                 ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_SHIFT;
    if (*out_base == 0u &&
        slave_type == ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_TYPE_SLAVE) {
      *out_base = value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_ADDR_BASE;
    }
    if (*out_wrap == 0u && slave_type == wrap_type) {
      *out_wrap = value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_SLAVE_ADDR_BASE;
    }
  }
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_find_core(UINT32 wanted_core,
                                                   UINT32* out_base,
                                                   UINT32* out_wrap) {
  UINT32 erom_address;
  UINT32 descriptor_type;
  UINT32 value;

  if (out_base == 0 || out_wrap == 0 ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_PI_ZERO_W_V1_1_CYW43438_CHIPCOMMON_BASE +
          ER_PI_ZERO_W_V1_1_CYW43438_CHIPCOMMON_EROMPTR,
          &erom_address) == 0u) {
    return 0u;
  }
  *out_base = 0u;
  *out_wrap = 0u;
  descriptor_type = 0u;
  while (descriptor_type != ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_EOT) {
    UINT32 core;
    UINT32 master_wrap_count;
    UINT32 slave_wrap_count;
    UINT32 base;
    UINT32 wrap;

    if (er_pi_zero_w_v1_1_cyw43438_dmp_next(&erom_address,
                                            &descriptor_type,
                                            &value) == 0u) {
      return 0u;
    }
    if ((value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_VALID) == 0u ||
        descriptor_type != ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_COMPONENT) {
      continue;
    }
    core = (value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_PARTNUM) >>
           ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_PARTNUM_SHIFT;
    if (er_pi_zero_w_v1_1_cyw43438_dmp_next(&erom_address,
                                            &descriptor_type,
                                            &value) == 0u ||
        (value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_TYPE_MASK) !=
            ER_PI_ZERO_W_V1_1_CYW43438_DMP_DESC_COMPONENT) {
      return 0u;
    }
    master_wrap_count = (value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_MWRAP) >>
                        ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_MWRAP_SHIFT;
    slave_wrap_count = (value & ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_SWRAP) >>
                       ER_PI_ZERO_W_V1_1_CYW43438_DMP_COMP_NUM_SWRAP_SHIFT;
    if ((master_wrap_count + slave_wrap_count) == 0u) {
      continue;
    }
    if (er_pi_zero_w_v1_1_cyw43438_dmp_regaddr(&erom_address,
                                               &base,
                                               &wrap) == 0u) {
      continue;
    }
    if (core == wanted_core) {
      *out_base = base;
      *out_wrap = wrap;
      return (UINT32)(base != 0u && wrap != 0u);
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_core_up(UINT32 wrap) {
  UINT32 ioctl;
  UINT32 reset;

  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL,
          &ioctl) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL,
          &reset) == 0u) {
    return 0u;
  }
  return (UINT32)(((ioctl & (ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_FGC |
                            ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_CLK)) ==
                   ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_CLK) &&
                  ((reset & ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL_RESET) == 0u));
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_disable_core(UINT32 wrap,
                                                      UINT32 prereset,
                                                      UINT32 reset) {
  UINT32 reset_control;

  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL,
          &reset_control) == 0u) {
    return 0u;
  }
  if ((reset_control & ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL_RESET) == 0u &&
      (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
           wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL,
           prereset | ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_FGC |
           ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_CLK) == 0u ||
       er_pi_zero_w_v1_1_cyw43438_backplane_write32(
           wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL,
           ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL_RESET) == 0u)) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_backplane_write32(
      wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL,
      reset | ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_FGC |
      ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_CLK);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_reset_core(UINT32 wrap,
                                                    UINT32 prereset,
                                                    UINT32 reset_config,
                                                    UINT32 postreset) {
  UINT32 poll;
  UINT32 reset;

  if (er_pi_zero_w_v1_1_cyw43438_disable_core(wrap,
                                              prereset,
                                              reset_config) == 0u) {
    return 0u;
  }
  for (poll = 0u; poll < ER_PI_ZERO_W_V1_1_CYW43438_RESET_POLL_BUDGET; ++poll) {
    if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
            wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL,
            &reset) == 0u) {
      return 0u;
    }
    if ((reset & ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL_RESET) == 0u) {
      break;
    }
    if (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
            wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_RESET_CTL,
            0u) == 0u) {
      return 0u;
    }
    er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_GPIO_DELAY_TICKS);
  }
  return er_pi_zero_w_v1_1_cyw43438_backplane_write32(
      wrap + ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL,
      postreset | ER_PI_ZERO_W_V1_1_CYW43438_BCMA_IOCTL_CLK);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_set_passive(UINT32 arm_wrap,
                                                     UINT32 mem_base,
                                                     UINT32 mem_wrap,
                                                     UINT32 d11_wrap) {
  if (er_pi_zero_w_v1_1_cyw43438_disable_core(arm_wrap, 0u, 0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_reset_core(
          d11_wrap,
          ER_PI_ZERO_W_V1_1_CYW43438_D11_IOCTL_PHYRESET |
          ER_PI_ZERO_W_V1_1_CYW43438_D11_IOCTL_PHYCLOCKEN,
          ER_PI_ZERO_W_V1_1_CYW43438_D11_IOCTL_PHYCLOCKEN,
          ER_PI_ZERO_W_V1_1_CYW43438_D11_IOCTL_PHYCLOCKEN) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_reset_core(mem_wrap, 0u, 0u, 0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          mem_base + ER_PI_ZERO_W_V1_1_CYW43438_SOCRAM_BANKIDX,
          ER_PI_ZERO_W_V1_1_CYW43438_SOCRAM_REMAP_BANK) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          mem_base + ER_PI_ZERO_W_V1_1_CYW43438_SOCRAM_BANKPDA,
          0u) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_core_up(mem_wrap);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_d11_tx_fifo_probe(UINT32 d11_base,
                                                           UINT16* out_ready) {
  UINT32 maccontrol;
  UINT16 command;

  if (out_ready == 0 ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          d11_base + ER_CYW43438_D11_MACCONTROL,
          ER_CYW43438_D11_MACCONTROL_PROBE) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          d11_base + ER_CYW43438_D11_MACCONTROL,
          &maccontrol) == 0u ||
      (maccontrol & ER_CYW43438_D11_MACCONTROL_PROBE) !=
          ER_CYW43438_D11_MACCONTROL_PROBE ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write16(
          d11_base + ER_CYW43438_D11_XMTFIFOCMD,
          (UINT16)ER_CYW43438_D11_TX_BCMC_FIFO_RESET) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_GPIO_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write16(
          d11_base + ER_CYW43438_D11_XMTFIFOCMD,
          (UINT16)ER_CYW43438_D11_TX_BCMC_FIFO_SELECT) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read16(
          d11_base + ER_CYW43438_D11_XMTFIFOCMD,
          &command) == 0u ||
      (command & ER_CYW43438_D11_TXFIFOCMD_FIFOSEL_MASK) !=
          ER_CYW43438_D11_TX_BCMC_FIFO_SELECT ||
      (command & ER_CYW43438_D11_TXFIFOCMD_RESET) != 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read16(
          d11_base + ER_CYW43438_D11_XMTFIFORDY,
          out_ready) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_d11_write_frame_words(
    UINT32 address,
    const UINT8* frame,
    UINT32 frame_len) {
  UINT32 offset;

  if (frame == 0 || frame_len == 0u) {
    return 0u;
  }
  for (offset = 0u; offset < frame_len; offset += (UINT32)sizeof(UINT32)) {
    UINT8 word_bytes[4] = {0u, 0u, 0u, 0u};
    UINT32 byte_index;

    for (byte_index = 0u;
         byte_index < (UINT32)sizeof(UINT32) && offset + byte_index < frame_len;
         ++byte_index) {
      word_bytes[byte_index] = frame[offset + byte_index];
    }
    if (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
            address,
            er_pi_zero_w_v1_1_cyw43438_read_le32(word_bytes)) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_d11_stage_tx_frame(
    UINT32 d11_base,
    const UINT8* frame,
    UINT32 frame_len) {
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          d11_base + ER_CYW43438_D11_TPLATEWRPTR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_d11_write_frame_words(
          d11_base + ER_CYW43438_D11_TPLATEWRDATA,
          frame,
          frame_len) == 0u) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_L2_D11_TX_TEMPLATE_LOADED;
  g_er_pi_zero_w_v1_1_sdio_probe_response = frame_len;
  if (er_pi_zero_w_v1_1_cyw43438_d11_write_frame_words(
          d11_base + ER_CYW43438_D11_TX_BCMC_PIO_TX_DATA,
          frame,
          frame_len) == 0u) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_L2_D11_TX_PIO_ATTEMPTED;
  g_er_pi_zero_w_v1_1_sdio_probe_response = frame_len;
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_start_owned_firmware(void) {
  UINT32 arm_base;
  UINT32 arm_wrap;
  UINT32 mem_base;
  UINT32 mem_wrap;
  UINT32 d11_base;
  UINT32 d11_wrap;
  UINT32 mailbox;
  UINT32 heartbeat_first;
  UINT32 heartbeat_second;
  UINT32 command_response;
  UINT32 tx_status;
  UINT32 d11_tx_frame;
  UINT32 d11_tx_len;
  UINT32 d11_tx_status;
  UINT32 rx_status;
  UINT32 tx_beacon_len;
  UINT32 rx_probe_len;
  UINT16 d11_fifo_ready;
  UINT8 tx_beacon[ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN];
  UINT8 rx_probe[ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN];

  if (sizeof(ER_CYW43438_OWNED_FIRMWARE) >=
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE ||
      ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN >
          ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_CAPACITY ||
      ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN >
          ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_CAPACITY ||
      (ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR +
       ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_CAPACITY) >=
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE ||
      (ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR +
       ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_CAPACITY) >=
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE ||
      (ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR <
       ER_CYW43438_OWNED_FIRMWARE_SIZE) ||
      (ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR <
       ER_CYW43438_OWNED_FIRMWARE_SIZE) ||
      (ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR <
       (ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR +
        ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_CAPACITY)) ||
      (tx_beacon_len = er_pi_zero_w_v1_1_wifi_beacon(tx_beacon)) == 0u ||
      (rx_probe_len = er_pi_zero_w_v1_1_wifi_probe_request(rx_probe)) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_buscoreprep() == 0u ||
      er_pi_zero_w_v1_1_cyw43438_find_core(
          ER_PI_ZERO_W_V1_1_CYW43438_CORE_ARM_CM3,
          &arm_base,
          &arm_wrap) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_find_core(
          ER_PI_ZERO_W_V1_1_CYW43438_CORE_INTERNAL_MEM,
          &mem_base,
          &mem_wrap) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_find_core(
          ER_PI_ZERO_W_V1_1_CYW43438_CORE_80211,
          &d11_base,
          &d11_wrap) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_set_passive(arm_wrap,
                                             mem_base,
                                             mem_wrap,
                                             d11_wrap) == 0u) {
    return 0u;
  }
  (void)arm_base;
  (void)mem_base;
  if (er_pi_zero_w_v1_1_cyw43438_d11_tx_fifo_probe(d11_base,
                                                   &d11_fifo_ready) == 0u) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_L2_D11_TX_FIFO_READY;
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = (UINT32)d11_fifo_ready;
  if (er_pi_zero_w_v1_1_cyw43438_d11_stage_tx_frame(d11_base,
                                                    tx_beacon,
                                                    tx_beacon_len) == 0u) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_BASE,
          ER_CYW43438_OWNED_FIRMWARE,
          (UINT32)sizeof(ER_CYW43438_OWNED_FIRMWARE)) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_HEARTBEAT_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_ADDR,
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_NONE) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_TX_LEN_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_D11_TX_FRAME_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_D11_TX_LEN_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_D11_TX_STATUS_ADDR,
          0u) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
          ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR,
          tx_beacon,
          tx_beacon_len) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
          ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR,
          rx_probe,
          rx_probe_len) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_TX_LEN_ADDR,
          tx_beacon_len) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR,
          rx_probe_len) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_BASE,
          ER_CYW43438_OWNED_FIRMWARE_RESET_VECTOR) == 0u) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_L2_OWNED_FIRMWARE_LOADED;
  if (er_pi_zero_w_v1_1_cyw43438_reset_core(arm_wrap, 0u, 0u, 0u) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_MAILBOX_ADDR,
          &mailbox) == 0u ||
      mailbox != ER_CYW43438_OWNED_FIRMWARE_MAILBOX_MAGIC) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_HEARTBEAT_ADDR,
          &heartbeat_first) == 0u ||
      heartbeat_first == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_HEARTBEAT_ADDR,
          &heartbeat_second) == 0u ||
      heartbeat_second == heartbeat_first) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_ADDR,
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_PING) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ADDR,
          &command_response) == 0u ||
      command_response != ER_CYW43438_OWNED_FIRMWARE_RESPONSE_PING_ACK) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_ADDR,
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_TX_BEACON) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ADDR,
          &command_response) == 0u ||
      command_response != ER_CYW43438_OWNED_FIRMWARE_RESPONSE_TX_BEACON_ACK ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_TX_STATUS_ADDR,
          &tx_status) == 0u ||
      tx_status != ER_PI_ZERO_W_V1_1_CYW_TX_STATUS_EXPECTED ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_D11_TX_FRAME_ADDR,
          &d11_tx_frame) == 0u ||
      d11_tx_frame != ER_CYW43438_OWNED_FIRMWARE_TX_FRAME_ADDR ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_D11_TX_LEN_ADDR,
          &d11_tx_len) == 0u ||
      d11_tx_len != tx_beacon_len ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_D11_TX_STATUS_ADDR,
          &d11_tx_status) == 0u ||
      d11_tx_status != ER_PI_ZERO_W_V1_1_CYW_TX_STATUS_EXPECTED) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_ADDR,
          ER_CYW43438_OWNED_FIRMWARE_COMMAND_RX_PROBE) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_RESPONSE_ADDR,
          &command_response) == 0u ||
      command_response != ER_CYW43438_OWNED_FIRMWARE_RESPONSE_RX_PROBE_ACK ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_RX_STATUS_ADDR,
          &rx_status) == 0u ||
      rx_status != ER_PI_ZERO_W_V1_1_CYW_RX_STATUS_EXPECTED) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_response = mailbox;
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = rx_status;
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_L2_CM3_ACTIVE;
  return 1u;
}

static void er_pi_zero_w_v1_1_sdio_probe(void) {
  UINT32 response;
  UINT8 cmd53_byte;

  g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_NONE;
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = 0u;
  g_er_pi_zero_w_v1_1_sdio_probe_response = 0u;
  g_er_pi_zero_w_v1_1_sdio_relative_card_address = 0u;
  if (er_pi_zero_w_v1_1_emmc_init() == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  if (er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_GO_IDLE_STATE,
                                     0u,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_NONE,
                                     &response) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD0_DONE;
  if (er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_IO_SEND_OP_COND,
                                     ER_PI_ZERO_W_V1_1_SDIO_OCR_3V3,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R4,
                                     &response) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD5_DONE;
  if (er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_SEND_RELATIVE_ADDR,
                                     0u,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6,
                                     &response) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_relative_card_address =
      response >> ER_PI_ZERO_W_V1_1_MMC_RCA_RESPONSE_SHIFT;
  if (g_er_pi_zero_w_v1_1_sdio_relative_card_address == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD3_DONE;
  if (er_pi_zero_w_v1_1_emmc_command(
          ER_PI_ZERO_W_V1_1_MMC_CMD_SELECT_CARD,
          er_pi_zero_w_v1_1_mmc_rca_argument(
              g_er_pi_zero_w_v1_1_sdio_relative_card_address),
          ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1,
          &response) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD7_DONE;
  if (er_pi_zero_w_v1_1_emmc_command(
          ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_DIRECT,
          er_pi_zero_w_v1_1_sdio_cmd52_argument(ER_PI_ZERO_W_V1_1_SDIO_CMD52_READ,
                                                ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
                                                ER_PI_ZERO_W_V1_1_SDIO_CMD52_NO_RAW,
                                                0u,
                                                0u),
          ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
          &response) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD52_DONE;
  if (er_pi_zero_w_v1_1_emmc_sdio_read_byte(ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
                                            0u,
                                            &cmd53_byte) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_SDIO_PROBE_ERROR;
    return;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_response =
      (g_er_pi_zero_w_v1_1_sdio_probe_response &
       ~ER_PI_ZERO_W_V1_1_SDIO_CMD52_DATA_MASK) |
      (UINT32)cmd53_byte;
  g_er_pi_zero_w_v1_1_sdio_probe_state =
      ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD53_DONE;
}

static void er_pi_zero_w_v1_1_uart_put_byte(UINT8 byte) {
  while ((er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_AUX_BASE,
                                 ER_PI_ZERO_W_V1_1_AUX_MU_LSR) &
          ER_PI_ZERO_W_V1_1_AUX_MU_LSR_TX_EMPTY) == 0u) {
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_ZERO_W_V1_1_AUX_MU_IO,
                          (UINT32)byte);
}

static void er_pi_zero_w_v1_1_put_u16(UINT8** cursor, UINT16 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 2u;
}

static void er_pi_zero_w_v1_1_put_u32(UINT8** cursor, UINT32 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[2] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[3] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 4u;
}

static void er_pi_zero_w_v1_1_put_u64(UINT8** cursor, UINT64 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[2] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[3] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[4] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE4_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[5] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE5_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[6] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE6_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[7] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U64_BYTE7_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 8u;
}

static void er_pi_zero_w_v1_1_put_bytes(UINT8** cursor,
                                        const UINT8* bytes,
                                        UINT32 len) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    (*cursor)[i] = bytes[i];
  }
  *cursor += len;
}

static void er_pi_zero_w_v1_1_fill_zero(UINT8* bytes, UINT32 len) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = 0u;
  }
}

static void er_pi_zero_w_v1_1_fill_byte(UINT8* bytes,
                                        UINT32 len,
                                        UINT8 value) {
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    bytes[i] = value;
  }
}

static UINT32 er_pi_zero_w_v1_1_wifi_address(
    UINT8 out_address[ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES]) {
  return er_pi_zero_w_v1_1_l2_address(g_er_pi_zero_w_v1_1_node_id,
                                      ER_PI_ZERO_W_V1_1_L2_WIFI_CHANNEL,
                                      out_address);
}

static UINT32 er_pi_zero_w_v1_1_wifi_beacon(
    UINT8 out_frame[ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN]) {
  UINT8 mac[ER_PI_ZERO_W_V1_1_L2_MAC_BYTES];
  UINT8 ssid[ER_PI_ZERO_W_V1_1_L2_SSID_BYTES];
  UINT8* cursor;

  if (out_frame == 0 ||
      er_pi_zero_w_v1_1_l2_node_mac(g_er_pi_zero_w_v1_1_node_id, mac) == 0u ||
      er_pi_zero_w_v1_1_l2_node_ssid(g_er_pi_zero_w_v1_1_node_id, ssid) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_fill_zero(out_frame,
                              ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN);
  out_frame[0] = ER_PI_ZERO_W_V1_1_IEEE80211_FC_BEACON;
  er_pi_zero_w_v1_1_fill_byte(
      out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_DA_OFFSET,
      ER_PI_ZERO_W_V1_1_L2_MAC_BYTES,
      ER_PI_ZERO_W_V1_1_IEEE80211_ADDR_BROADCAST);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_SA_OFFSET;
  er_pi_zero_w_v1_1_put_bytes(&cursor, mac, ER_PI_ZERO_W_V1_1_L2_MAC_BYTES);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_BSSID_OFFSET;
  er_pi_zero_w_v1_1_put_bytes(&cursor, mac, ER_PI_ZERO_W_V1_1_L2_MAC_BYTES);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_SEQUENCE_OFFSET;
  er_pi_zero_w_v1_1_put_u16(&cursor, 0u);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_FIXED_OFFSET + 8u;
  er_pi_zero_w_v1_1_put_u16(
      &cursor,
      ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_INTERVAL_TU);
  er_pi_zero_w_v1_1_put_u16(&cursor,
                            ER_PI_ZERO_W_V1_1_IEEE80211_CAPABILITY_ESS);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_SSID_IE_OFFSET;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_IE_SSID;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_L2_SSID_BYTES;
  cursor += 1u;
  er_pi_zero_w_v1_1_put_bytes(&cursor, ssid, ER_PI_ZERO_W_V1_1_L2_SSID_BYTES);
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_IE_SUPPORTED_RATES;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_SUPPORTED_RATE_COUNT;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_1M;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_2M;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_5M5;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_11M;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_IE_DS;
  cursor += 1u;
  *cursor = 1u;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_L2_WIFI_CHANNEL;
  return ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_LEN;
}

static UINT32 er_pi_zero_w_v1_1_wifi_probe_request(
    UINT8 out_frame[ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN]) {
  UINT8 mac[ER_PI_ZERO_W_V1_1_L2_MAC_BYTES];
  UINT8 ssid[ER_PI_ZERO_W_V1_1_L2_SSID_BYTES];
  UINT8* cursor;

  if (out_frame == 0 ||
      er_pi_zero_w_v1_1_l2_node_mac(g_er_pi_zero_w_v1_1_node_id, mac) == 0u ||
      er_pi_zero_w_v1_1_l2_node_ssid(g_er_pi_zero_w_v1_1_node_id, ssid) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_fill_zero(out_frame,
                              ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN);
  out_frame[0] = ER_PI_ZERO_W_V1_1_IEEE80211_FC_PROBE_REQUEST;
  er_pi_zero_w_v1_1_fill_byte(
      out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_DA_OFFSET,
      ER_PI_ZERO_W_V1_1_L2_MAC_BYTES,
      ER_PI_ZERO_W_V1_1_IEEE80211_ADDR_BROADCAST);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_SA_OFFSET;
  er_pi_zero_w_v1_1_put_bytes(&cursor, mac, ER_PI_ZERO_W_V1_1_L2_MAC_BYTES);
  er_pi_zero_w_v1_1_fill_byte(
      out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_BSSID_OFFSET,
      ER_PI_ZERO_W_V1_1_L2_MAC_BYTES,
      ER_PI_ZERO_W_V1_1_IEEE80211_ADDR_BROADCAST);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_SEQUENCE_OFFSET;
  er_pi_zero_w_v1_1_put_u16(&cursor, 0u);
  cursor = out_frame + ER_PI_ZERO_W_V1_1_IEEE80211_BEACON_FIXED_OFFSET;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_IE_SSID;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_L2_SSID_BYTES;
  cursor += 1u;
  er_pi_zero_w_v1_1_put_bytes(&cursor, ssid, ER_PI_ZERO_W_V1_1_L2_SSID_BYTES);
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_IE_SUPPORTED_RATES;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_SUPPORTED_RATE_COUNT;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_1M;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_2M;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_5M5;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_RATE_11M;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_IEEE80211_IE_DS;
  cursor += 1u;
  *cursor = 1u;
  cursor += 1u;
  *cursor = ER_PI_ZERO_W_V1_1_L2_WIFI_CHANNEL;
  return ER_PI_ZERO_W_V1_1_IEEE80211_PROBE_REQUEST_LEN;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_start_owned_l2(void) {
  return er_pi_zero_w_v1_1_cyw43438_start_owned_firmware();
}

static UINT32 er_pi_zero_w_v1_1_crc32(const UINT8* bytes, UINT32 len) {
  UINT32 crc = ER_PI_ZERO_W_V1_1_CRC32_INITIAL;
  UINT32 i;

  for (i = 0u; i < len; ++i) {
    UINT32 bit;
    crc ^= (UINT32)bytes[i];
    for (bit = 0u; bit < ER_PI_ZERO_W_V1_1_CRC32_BITS_PER_BYTE; ++bit) {
      UINT32 mask = 0u - (crc & 1u);
      crc = (crc >> 1) ^ (ER_PI_ZERO_W_V1_1_CRC32_POLY & mask);
    }
  }
  return ~crc;
}

static void er_pi_zero_w_v1_1_send_erwire(UINT16 kind,
                                          UINT32 seq,
                                          const UINT8* payload,
                                          UINT32 payload_len) {
  UINT8 header[ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE];
  UINT8* cursor = header;
  UINT32 i;

  er_pi_zero_w_v1_1_put_u32(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_VERSION);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE);
  er_pi_zero_w_v1_1_put_u32(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_STREAM_ID);
  er_pi_zero_w_v1_1_put_u32(&cursor, seq);
  er_pi_zero_w_v1_1_put_u16(&cursor, kind);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_FIRST |
                                     ER_PI_ZERO_W_V1_1_ERWIRE_FLAG_LAST);
  er_pi_zero_w_v1_1_put_u32(&cursor, payload_len);
  er_pi_zero_w_v1_1_put_u32(&cursor,
                            er_pi_zero_w_v1_1_crc32(payload, payload_len));
  er_pi_zero_w_v1_1_put_u32(&cursor, 0u);
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE; ++i) {
    er_pi_zero_w_v1_1_uart_put_byte(header[i]);
  }
  for (i = 0u; i < payload_len; ++i) {
    er_pi_zero_w_v1_1_uart_put_byte(payload[i]);
  }
}

static void er_pi_zero_w_v1_1_send_node_available(void) {
  UINT8 payload[ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES];
  UINT8 wifi_address[ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES];
  UINT8 log_head[ER_PI_ZERO_W_V1_1_HASH_BYTES];
  UINT8* cursor = payload;
  UINT32 l2_ready;

  l2_ready = er_pi_zero_w_v1_1_wifi_address(wifi_address);
  er_pi_zero_w_v1_1_fill_zero(log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  cursor = log_head;
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state);
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_interrupt);
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_response);
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_relative_card_address);
  er_pi_zero_w_v1_1_put_u32(&cursor, l2_ready);
  cursor = payload;
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_node_id,
                              ER_PI_ZERO_W_V1_1_NODE_BYTES);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_node_id,
                              ER_PI_ZERO_W_V1_1_NODE_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor,
                            ER_PI_ZERO_W_V1_1_CHANNEL_KIND_WIFI_OPEN_L2);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_channel_id,
                              ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              wifi_address,
                              ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES);
  er_pi_zero_w_v1_1_put_u64(&cursor, 1u);
  er_pi_zero_w_v1_1_put_u64(&cursor, ER_PI_ZERO_W_V1_1_BOOT_MS);
  er_pi_zero_w_v1_1_put_u64(&cursor, ER_PI_ZERO_W_V1_1_HEARTBEAT_SECS);
  er_pi_zero_w_v1_1_put_bytes(&cursor, log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_send_erwire(ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_AVAILABLE,
                                0u,
                                payload,
                                ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES);
}

static void er_pi_zero_w_v1_1_send_node_heartbeat(UINT32 heartbeat) {
  UINT8 payload[ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES];
  UINT8 connection_hash[ER_PI_ZERO_W_V1_1_HASH_BYTES];
  UINT8 log_head[ER_PI_ZERO_W_V1_1_HASH_BYTES];
  UINT8* cursor = payload;
  UINT32 i;

  for (i = 0u; i < ER_PI_ZERO_W_V1_1_HASH_BYTES; ++i) {
    connection_hash[i] =
        (UINT8)(g_er_pi_zero_w_v1_1_channel_id[i] ^ (UINT8)heartbeat);
  }
  er_pi_zero_w_v1_1_fill_zero(log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION);
  er_pi_zero_w_v1_1_put_u16(&cursor, ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              g_er_pi_zero_w_v1_1_node_id,
                              ER_PI_ZERO_W_V1_1_NODE_BYTES);
  er_pi_zero_w_v1_1_put_u64(&cursor, (UINT64)heartbeat + 2u);
  er_pi_zero_w_v1_1_put_u64(&cursor, (UINT64)heartbeat);
  er_pi_zero_w_v1_1_put_bytes(&cursor,
                              connection_hash,
                              ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_put_bytes(&cursor, log_head, ER_PI_ZERO_W_V1_1_HASH_BYTES);
  er_pi_zero_w_v1_1_send_erwire(ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_HEARTBEAT,
                                heartbeat + 1u,
                                payload,
                                ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES);
}

void er_pi_zero_w_v1_1_main(void) {
  UINT32 heartbeat = 0u;

  er_pi_zero_w_v1_1_act_led_init();
  er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_BOOT_ENTRY);
  er_pi_zero_w_v1_1_uart_init();
  er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_UART_READY);
  er_pi_zero_w_v1_1_wifi_gpio_init();
  er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_WIFI_POWERED);
  er_pi_zero_w_v1_1_sdio_probe();
  if (g_er_pi_zero_w_v1_1_sdio_probe_state ==
          ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD53_DONE &&
      er_pi_zero_w_v1_1_cyw43438_start_owned_l2() != 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_L2_READY;
    er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_OK);
  } else {
    er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_FAIL);
  }
  er_pi_zero_w_v1_1_send_node_available();

  for (;;) {
    g_er_pi_zero_w_v1_1_boot_magic = ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
    er_pi_zero_w_v1_1_send_node_heartbeat(heartbeat);
    heartbeat += 1u;
    er_pi_zero_w_v1_1_delay(
        ER_PI_ZERO_W_V1_1_UART_HEARTBEAT_DELAY_TICKS);
  }
}
