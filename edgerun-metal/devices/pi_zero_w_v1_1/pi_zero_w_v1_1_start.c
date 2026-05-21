#include "er_pi_zero_w_v1_1_uart.h"
#include "er_pi_zero_w_v1_1_boot_log.h"
#include "er_pi_zero_w_v1_1_lcd_hat.h"
#include "er_pi_zero_w_v1_1_ota.h"
#include "er_pi_zero_w_v1_1_status.h"
#include "er_ble_adv.h"
#include "er_crypto_blake3.h"
#include "er_cyw43438_d11.h"
#include "er_cyw43438_owned_firmware.h"
#include "er_cyw43438_sdpcm.h"
#include "er_ephemeral_node.h"
#include "er_pi_mmc.h"
#include "er_types.h"
#include "pi_zero_w_v1_1_cyw43438_firmware.h"

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
#define ER_PI_ZERO_W_V1_1_ERWIRE_KIND_BLE_ADVERTISEMENT 42u
#define ER_PI_ZERO_W_V1_1_ERWIRE_STREAM_ID 0x45525a57u
#define ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC_OFFSET 0u
#define ER_PI_ZERO_W_V1_1_ERWIRE_VERSION_OFFSET 4u
#define ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE_OFFSET 6u
#define ER_PI_ZERO_W_V1_1_ERWIRE_PAYLOAD_LEN_OFFSET 20u
#define ER_PI_ZERO_W_V1_1_ERWIRE_RESERVED_OFFSET 28u
#define ER_PI_ZERO_W_V1_1_UART_RX_FRAME_BYTES \
  (ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE + \
   ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_BYTES_MAX)
#define ER_PI_ZERO_W_V1_1_UART_RX_POLL_BYTES 4096u
#define ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER 0u
#define ER_PI_ZERO_W_V1_1_WORK_ABI_VERSION 1u
#define ER_PI_ZERO_W_V1_1_NODE_ROLE_RELAY 1u
#define ER_PI_ZERO_W_V1_1_CHANNEL_KIND_WIFI_OPEN_L2 14u
#define ER_PI_ZERO_W_V1_1_L2_LABEL "pi-zero-w-v1_1"
#define ER_PI_ZERO_W_V1_1_L2_LABEL_BYTES 14u
#define ER_PI_ZERO_W_V1_1_BLE_WIFI_GROUP_ID 0x45525a57u
#define ER_PI_ZERO_W_V1_1_BLE_WIFI_PRIORITY 3u
#define ER_PI_ZERO_W_V1_1_BLE_ADV_FRAGMENT_INDEX 0u
#define ER_PI_ZERO_W_V1_1_BLE_ADV_FRAGMENT_COUNT 1u
#define ER_PI_ZERO_W_V1_1_HEARTBEAT_SECS 10u
#define ER_PI_ZERO_W_V1_1_NODE_BYTES 32u
#define ER_PI_ZERO_W_V1_1_HASH_BYTES 32u
#define ER_PI_ZERO_W_V1_1_ADMISSION_ID_TEXT "ERADMISSIONPIZEROW1PROOF000001XX"
#define ER_PI_ZERO_W_V1_1_CHANNEL_ID_TEXT "ERWIFIL2PIZEROW1CHANNEL00000001"
#define ER_PI_ZERO_W_V1_1_C_STRING_NUL_BYTES 1u
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
#define ER_PI_ZERO_W_V1_1_UPDATE_STATE_BYTES 20u
#define ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BASE_BYTES 189u
#define ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES \
  (ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BASE_BYTES + \
   ER_PI_ZERO_W_V1_1_UPDATE_STATE_BYTES)
#define ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BASE_BYTES 116u
#define ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES \
  (ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BASE_BYTES + \
   ER_PI_ZERO_W_V1_1_UPDATE_STATE_BYTES)
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
#define ER_PI_ZERO_W_V1_1_LE_BYTE0 0u
#define ER_PI_ZERO_W_V1_1_LE_BYTE1 1u
#define ER_PI_ZERO_W_V1_1_LE_BYTE2 2u
#define ER_PI_ZERO_W_V1_1_LE_BYTE3 3u
#define ER_PI_ZERO_W_V1_1_LE_BYTE4 4u
#define ER_PI_ZERO_W_V1_1_LE_BYTE5 5u
#define ER_PI_ZERO_W_V1_1_LE_BYTE6 6u
#define ER_PI_ZERO_W_V1_1_LE_BYTE7 7u
#define ER_PI_ZERO_W_V1_1_BOOT_MS 0u
#define ER_PI_ZERO_W_V1_1_WIFI_GPIO_DELAY_TICKS 150u
#define ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS 400000u
#define ER_PI_ZERO_W_V1_1_SDIO_POLL_BUDGET 1000000u
#define ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ 0u
#define ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE 1u
#define ER_PI_ZERO_W_V1_1_STORAGE_PROBE_NONE 0u
#define ER_PI_ZERO_W_V1_1_STORAGE_PROBE_CMD8_DONE 1u
#define ER_PI_ZERO_W_V1_1_STORAGE_PROBE_ACMD41_DONE 2u
#define ER_PI_ZERO_W_V1_1_STORAGE_PROBE_CMD2_DONE 3u
#define ER_PI_ZERO_W_V1_1_STORAGE_PROBE_CMD3_DONE 4u
#define ER_PI_ZERO_W_V1_1_STORAGE_READY 5u
#define ER_PI_ZERO_W_V1_1_STORAGE_WRITE_VERIFIED 6u
#define ER_PI_ZERO_W_V1_1_STORAGE_PROBE_ERROR 0xffffffffu
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_NONE 0u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_PLAN 1u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_FIRMWARE 2u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_MPC 3u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_INFRA 4u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_AUTH 5u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_WSEC 6u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_CHANNEL 7u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_UP 8u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_SSID 9u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_READY 10u
#define ER_PI_ZERO_W_V1_1_WIFI_STAGE_ERROR 0x80000000u
#define ER_PI_ZERO_W_V1_1_LED_BOOT_ENTRY 1u
#define ER_PI_ZERO_W_V1_1_LED_UART_READY 2u
#define ER_PI_ZERO_W_V1_1_LED_WIFI_POWERED 3u
#define ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_OK 7u
#define ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_FAIL 11u
#define ER_PI_ZERO_W_V1_1_LED_CYW_RX_UNSUPPORTED 13u
#define ER_PI_ZERO_W_V1_1_LED_STEP_DELAY_TICKS 250000u
#define ER_PI_ZERO_W_V1_1_NODE_ENTROPY_ROUNDS 8u
#define ER_PI_ZERO_W_V1_1_NODE_ENTROPY_DELAY_TICKS 97u
#define ER_PI_ZERO_W_V1_1_EMMC_RESET_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_EMMC_STABLE_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_SD_MEMORY_OCR_POLL_BUDGET 1000u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_ENABLE_ADDR 0x00000002u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_READY_ADDR 0x00000003u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_1 0x02u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_2 0x04u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTIONS_1_2 \
  (ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_1 | \
   ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_2)
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_F2_BLOCK_SIZE_LOW 0x00000210u
#define ER_PI_ZERO_W_V1_1_CYW43438_CCCR_F2_BLOCK_SIZE_HIGH 0x00000211u
#define ER_PI_ZERO_W_V1_1_CYW43438_READY_POLL_BUDGET 10000u
#define ER_PI_ZERO_W_V1_1_CYW43438_ALP_POLL_BUDGET 100000u
#define ER_PI_ZERO_W_V1_1_CYW43438_RESET_POLL_BUDGET 1000u
#define ER_PI_ZERO_W_V1_1_CYW43438_F2_POLL_BUDGET 64u
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRLOW 0x0001000au
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRMID 0x0001000bu
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SBADDRHIGH 0x0001000cu
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_WATERMARK 0x00010008u
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR 0x0001000eu
#define ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SDIOPULLUP 0x0001000fu
#define ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HW_CLKREQ_OFF 0x20u
#define ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL_REQ 0x08u
#define ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL 0x40u
#define ER_PI_ZERO_W_V1_1_CYW43438_FORCE_ALP 0x01u
#define ER_PI_ZERO_W_V1_1_CYW43438_HT_AVAIL_REQ 0x10u
#define ER_PI_ZERO_W_V1_1_CYW43438_HT_AVAIL 0x80u
#define ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HT 0x02u
#define ER_PI_ZERO_W_V1_1_CYW43438_F2_WATERMARK 0x08u
#define ER_PI_ZERO_W_V1_1_CYW43438_SDPCM_PROT_VERSION 4u
#define ER_PI_ZERO_W_V1_1_CYW43438_SMB_DATA_VERSION_SHIFT 16u
#define ER_PI_ZERO_W_V1_1_CYW43438_SDIO_CORE 0x0829u
#define ER_PI_ZERO_W_V1_1_CYW43438_SDIO_INTSTATUS 0x00000020u
#define ER_PI_ZERO_W_V1_1_CYW43438_SDIO_HOSTINTMASK 0x00000024u
#define ER_PI_ZERO_W_V1_1_CYW43438_SDIO_TOSBMAILBOXDATA 0x00000048u
#define ER_PI_ZERO_W_V1_1_CYW43438_INT_HMB_SW_MASK 0x000000f0u
#define ER_PI_ZERO_W_V1_1_CYW43438_INT_CHIPACTIVE 0x20000000u
#define ER_PI_ZERO_W_V1_1_CYW43438_INT_HMB_FRAME_IND 0x00000040u
#define ER_PI_ZERO_W_V1_1_CYW43438_HOSTINTMASK \
  (ER_PI_ZERO_W_V1_1_CYW43438_INT_HMB_SW_MASK | \
   ER_PI_ZERO_W_V1_1_CYW43438_INT_CHIPACTIVE)
#define ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES 512u
#define ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_COUNT_MAX 3u
#define ER_PI_ZERO_W_V1_1_CYW43438_F2_FRAME_BYTES \
  (ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES * \
   ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_COUNT_MAX)
#define ER_PI_ZERO_W_V1_1_CYW43438_CONTROL_POLL_BUDGET 32u
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
#define ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_BASE 0x20003000u
#define ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_COUNTER_LOW 0x00000004u
#define ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_COUNTER_HIGH 0x00000008u
#define ER_PI_ZERO_W_V1_1_MIX_CONSTANT 0x9e3779b9u
#define ER_PI_ZERO_W_V1_1_MIX_LEFT_SHIFT 6u
#define ER_PI_ZERO_W_V1_1_MIX_RIGHT_SHIFT 2u
volatile UINT32 g_er_pi_zero_w_v1_1_boot_magic =
    ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_probe_state =
    ER_PI_ZERO_W_V1_1_SDIO_PROBE_NONE;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_probe_interrupt = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_probe_response = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_sdio_relative_card_address = 0u;
static UINT32 g_er_pi_zero_w_v1_1_cyw43438_sdio_base = 0u;
static UINT8 g_er_pi_zero_w_v1_1_cyw43438_sdpcm_sequence = 1u;
static UINT16 g_er_pi_zero_w_v1_1_cyw43438_bcdc_request_id = 1u;
volatile UINT32 g_er_pi_zero_w_v1_1_storage_probe_state =
    ER_PI_ZERO_W_V1_1_STORAGE_PROBE_NONE;
volatile UINT32 g_er_pi_zero_w_v1_1_storage_relative_card_address = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_storage_last_block = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_storage_last_response = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_wifi_control_state =
    ER_PI_ZERO_W_V1_1_WIFI_STAGE_NONE;
volatile UINT32 g_er_pi_zero_w_v1_1_ota_status =
    ER_PI_ZERO_W_V1_1_OTA_STATUS_IDLE;
volatile UINT32 g_er_pi_zero_w_v1_1_ota_offset = 0u;
volatile UINT32 g_er_pi_zero_w_v1_1_ota_target_block =
    ER_PI_ZERO_W_V1_1_OTA_DEFAULT_SLOT_BLOCK;

static ErPiZeroWV11OtaState g_er_pi_zero_w_v1_1_ota_state;
static ErPiZeroWV11BootLog g_er_pi_zero_w_v1_1_boot_log;
static UINT8
    g_er_pi_zero_w_v1_1_uart_rx_frame[ER_PI_ZERO_W_V1_1_UART_RX_FRAME_BYTES];
static UINT8
    g_er_pi_zero_w_v1_1_l2_rx_frame[ER_PI_ZERO_W_V1_1_CYW43438_F2_FRAME_BYTES];
static UINT8
    g_er_pi_zero_w_v1_1_l2_tx_frame[ER_PI_ZERO_W_V1_1_CYW43438_F2_FRAME_BYTES];
static UINT32 g_er_pi_zero_w_v1_1_uart_rx_len =
    ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER;
static UINT32 g_er_pi_zero_w_v1_1_uart_rx_expected_len =
    ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER;

static UINT8
    g_er_pi_zero_w_v1_1_node_id[ER_PI_ZERO_W_V1_1_NODE_BYTES] = {0u};

static const UINT8
    g_er_pi_zero_w_v1_1_admission_id[ER_PI_ZERO_W_V1_1_HASH_BYTES +
                                     ER_PI_ZERO_W_V1_1_C_STRING_NUL_BYTES] =
    ER_PI_ZERO_W_V1_1_ADMISSION_ID_TEXT;

static const UINT8
    g_er_pi_zero_w_v1_1_channel_id[ER_PI_ZERO_W_V1_1_HASH_BYTES +
                                   ER_PI_ZERO_W_V1_1_C_STRING_NUL_BYTES] =
    ER_PI_ZERO_W_V1_1_CHANNEL_ID_TEXT;
static const char g_er_pi_zero_w_v1_1_cyw43438_iovar_mpc[] = {
    'm', 'p', 'c', 0
};

static volatile UINT32* er_pi_zero_w_v1_1_reg(UINT32 base, UINT32 offset) {
  return (volatile UINT32*)(UINTN)(base + offset);
}

static UINT32 er_pi_zero_w_v1_1_read(UINT32 base, UINT32 offset) {
  return *er_pi_zero_w_v1_1_reg(base, offset);
}

static void er_pi_zero_w_v1_1_write(UINT32 base, UINT32 offset, UINT32 value) {
  *er_pi_zero_w_v1_1_reg(base, offset) = value;
}

static UINT8 er_pi_zero_w_v1_1_emmc_read32_op(void* ctx,
                                              UINT32 offset,
                                              UINT32* out_value) {
  (void)ctx;
  if (out_value == 0) {
    return 0u;
  }
  *out_value = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE, offset);
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_emmc_write32_op(void* ctx,
                                               UINT32 offset,
                                               UINT32 value) {
  (void)ctx;
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE, offset, value);
  return 1u;
}

static void er_pi_zero_w_v1_1_barrier(void) {
  __asm__ volatile("" ::: "memory");
}

static void er_pi_zero_w_v1_1_reboot(void) {
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_PM_BASE,
                          ER_PI_ZERO_W_V1_1_PM_WDOG,
                          ER_PI_ZERO_W_V1_1_PM_PASSWORD |
                              ER_PI_ZERO_W_V1_1_PM_WDOG_RESET_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_PM_BASE,
                          ER_PI_ZERO_W_V1_1_PM_RSTC,
                          ER_PI_ZERO_W_V1_1_PM_PASSWORD |
                              ER_PI_ZERO_W_V1_1_PM_RSTC_WRCFG_FULL_RESET);
  for (;;) {
    er_pi_zero_w_v1_1_barrier();
  }
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
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R2:
      return ER_PI_ZERO_W_V1_1_EMMC_CMDTM_RESPONSE_136;
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R3:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R4:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R7:
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
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R2:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R7:
      value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_CRC_CHECK;
      break;
    default:
      break;
  }
  switch (response_kind) {
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R7:
      value |= ER_PI_ZERO_W_V1_1_EMMC_CMDTM_INDEX_CHECK;
      break;
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_NONE:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R2:
    case ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R3:
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

static UINT32 er_pi_zero_w_v1_1_emmc_wait_interrupt_mask(UINT32 wanted_interrupt,
                                                         UINT32 require_wanted,
                                                         UINT32* out_interrupt) {
  UINT32 poll;
  UINT32 interrupt;

  if (out_interrupt == 0 || (require_wanted != 0u && wanted_interrupt == 0u)) {
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

static UINT32 er_pi_zero_w_v1_1_emmc_wait_command(UINT32* out_interrupt) {
  return er_pi_zero_w_v1_1_emmc_wait_interrupt_mask(
      ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_CMD_DONE,
      0u,
      out_interrupt);
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

static UINT32 er_pi_zero_w_v1_1_mmc_rca_from_response(UINT32 response) {
  return (response >> ER_PI_ZERO_W_V1_1_MMC_RCA_RESPONSE_SHIFT) &
         ER_PI_ZERO_W_V1_1_MMC_RCA_MASK;
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
  return er_pi_zero_w_v1_1_emmc_wait_interrupt_mask(wanted_interrupt,
                                                   1u,
                                                   out_interrupt);
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_start_cmd53_transfer(
    UINT32 function,
    UINT32 address,
    UINT32 transfer_len,
    UINT32 cmd53_count,
    UINT32 block_mode,
    UINT32 write,
    UINT32 incrementing,
    UINT32 data_is_read) {
  if (transfer_len == 0u ||
      cmd53_count == 0u ||
      cmd53_count > ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK ||
      er_pi_zero_w_v1_1_emmc_wait_clear(
          ER_PI_ZERO_W_V1_1_EMMC_REG_STATUS,
          ER_PI_ZERO_W_V1_1_EMMC_STATUS_CMD_INHIBIT |
              ER_PI_ZERO_W_V1_1_EMMC_STATUS_DATA_INHIBIT,
          ER_PI_ZERO_W_V1_1_EMMC_READY_POLL_BUDGET) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_ALL);
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_BLKSIZECNT,
      ((block_mode == ER_PI_ZERO_W_V1_1_SDIO_CMD53_BLOCK_MODE ?
        cmd53_count :
        1u) << ER_PI_ZERO_W_V1_1_EMMC_BLOCK_COUNT_BITS) |
          (block_mode == ER_PI_ZERO_W_V1_1_SDIO_CMD53_BLOCK_MODE ?
           ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES :
           transfer_len));
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_ARG1,
      er_pi_zero_w_v1_1_sdio_cmd53_argument(write,
                                            function,
                                            block_mode,
                                            incrementing,
                                            address,
                                            cmd53_count));
  er_pi_zero_w_v1_1_write(
      ER_PI_ZERO_W_V1_1_EMMC_BASE,
      ER_PI_ZERO_W_V1_1_EMMC_REG_CMDTM,
      er_pi_zero_w_v1_1_emmc_sdio_command_value(
          ER_PI_ZERO_W_V1_1_MMC_CMD_IO_RW_EXTENDED,
          ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R5,
          data_is_read));
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_start_cmd53(
    UINT32 function,
    UINT32 address,
    UINT32 bytes_len,
    UINT32 write,
    UINT32 incrementing,
    UINT32 data_is_read) {
  if (bytes_len > ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_emmc_sdio_start_cmd53_transfer(
      function,
      address,
      bytes_len,
      bytes_len,
      ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
      write,
      incrementing,
      data_is_read);
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_finish_data(UINT32* out_interrupt) {
  UINT32 interrupt;

  if (out_interrupt == 0 ||
      er_pi_zero_w_v1_1_emmc_wait_interrupt(
          ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_DATA_DONE,
          &interrupt) == 0u) {
    if (out_interrupt != 0) {
      g_er_pi_zero_w_v1_1_sdio_probe_interrupt = *out_interrupt;
    }
    return 0u;
  }
  *out_interrupt = interrupt;
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
  g_er_pi_zero_w_v1_1_sdio_probe_response =
      er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                             ER_PI_ZERO_W_V1_1_EMMC_REG_RESP0);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                          ER_PI_ZERO_W_V1_1_EMMC_REG_INTERRUPT,
                          interrupt);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_pack_le32_partial(const UINT8* bytes,
                                                  UINT32 bytes_len) {
  UINT32 word = 0u;
  UINT32 byte_index;

  for (byte_index = 0u;
       byte_index < (UINT32)sizeof(UINT32) && byte_index < bytes_len;
       ++byte_index) {
    word |= (UINT32)bytes[byte_index] <<
            (byte_index * ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT);
  }
  return word;
}

static void er_pi_zero_w_v1_1_unpack_le32_partial(UINT32 word,
                                                  UINT8* bytes,
                                                  UINT32 bytes_len) {
  UINT32 byte_index;

  for (byte_index = 0u;
       byte_index < (UINT32)sizeof(UINT32) && byte_index < bytes_len;
       ++byte_index) {
    bytes[byte_index] =
        (UINT8)((word >> (byte_index * ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT)) &
                ER_PI_ZERO_W_V1_1_BYTE_MASK);
  }
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_transfer_chunk_len(UINT32 bytes_len,
                                                             UINT32 offset) {
  UINT32 chunk_len;

  chunk_len = bytes_len - offset;
  if (chunk_len > (UINT32)sizeof(UINT32)) {
    chunk_len = (UINT32)sizeof(UINT32);
  }
  return chunk_len;
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_ready_interrupt(UINT32 transfer_kind) {
  switch (transfer_kind) {
    case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ:
      return ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_READ_RDY;
    case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE:
      return ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_WRITE_RDY;
    default:
      return 0u;
  }
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_cmd53_write_flag(UINT32 transfer_kind) {
  switch (transfer_kind) {
    case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ:
      return ER_PI_ZERO_W_V1_1_SDIO_CMD53_READ;
    case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE:
      return ER_PI_ZERO_W_V1_1_SDIO_CMD53_WRITE;
    default:
      return ER_PI_ZERO_W_V1_1_SDIO_CMD53_READ;
  }
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_data_is_read(UINT32 transfer_kind) {
  switch (transfer_kind) {
    case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ:
      return 1u;
    case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE:
      return 0u;
    default:
      return 0u;
  }
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_transfer(
    UINT32 function,
    UINT32 address,
    const UINT8* write_bytes,
    UINT8* read_bytes,
    UINT32 bytes_len,
    UINT32 cmd53_count,
    UINT32 block_mode,
    UINT32 transfer_kind) {
  UINT32 interrupt;
  UINT32 offset;
  UINT32 ready_interrupt;

  ready_interrupt = er_pi_zero_w_v1_1_emmc_sdio_ready_interrupt(transfer_kind);
  if (ready_interrupt == 0u ||
      (transfer_kind == ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ && read_bytes == 0) ||
      (transfer_kind == ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE && write_bytes == 0) ||
      er_pi_zero_w_v1_1_emmc_sdio_start_cmd53_transfer(
          function,
          address,
          bytes_len,
          cmd53_count,
          block_mode,
          er_pi_zero_w_v1_1_emmc_sdio_cmd53_write_flag(transfer_kind),
          ER_PI_ZERO_W_V1_1_SDIO_CMD53_INCREMENTING_ADDRESS,
          er_pi_zero_w_v1_1_emmc_sdio_data_is_read(transfer_kind)) == 0u) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ready_interrupt, &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  for (offset = 0u; offset < bytes_len; offset += (UINT32)sizeof(UINT32)) {
    UINT32 word;
    UINT32 chunk_len;

    chunk_len = er_pi_zero_w_v1_1_emmc_sdio_transfer_chunk_len(bytes_len, offset);
    switch (transfer_kind) {
      case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ:
        word = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                      ER_PI_ZERO_W_V1_1_EMMC_REG_DATA);
        er_pi_zero_w_v1_1_unpack_le32_partial(word, read_bytes + offset, chunk_len);
        break;
      case ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE:
        er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                ER_PI_ZERO_W_V1_1_EMMC_REG_DATA,
                                er_pi_zero_w_v1_1_pack_le32_partial(
                                    write_bytes + offset,
                                    chunk_len));
        break;
      default:
        return 0u;
    }
  }
  return er_pi_zero_w_v1_1_emmc_sdio_finish_data(&interrupt);
}

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_read_byte(UINT32 function,
                                                    UINT32 address,
                                                    UINT8* out_byte) {
  UINT32 interrupt;
  UINT32 data;

  if (out_byte == 0) {
    return 0u;
  }
  *out_byte = 0u;
  if (er_pi_zero_w_v1_1_emmc_sdio_start_cmd53(
          function,
          address,
          1u,
          ER_PI_ZERO_W_V1_1_SDIO_CMD53_READ,
          ER_PI_ZERO_W_V1_1_SDIO_CMD53_FIXED_ADDRESS,
          1u) == 0u) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_emmc_wait_interrupt(ER_PI_ZERO_W_V1_1_EMMC_INTERRUPT_READ_RDY,
                                            &interrupt) == 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_interrupt = interrupt;
    return 0u;
  }
  data = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_EMMC_BASE,
                                ER_PI_ZERO_W_V1_1_EMMC_REG_DATA);
  *out_byte = (UINT8)(data & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  return er_pi_zero_w_v1_1_emmc_sdio_finish_data(&interrupt);
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

static UINT32 er_pi_zero_w_v1_1_emmc_sdio_read_blocks(UINT32 function,
                                                      UINT32 address,
                                                      UINT8* bytes,
                                                      UINT32 block_count) {
  UINT32 bytes_len;

  bytes_len = block_count * ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES;
  if (bytes == 0 ||
      block_count == 0u ||
      block_count > ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_COUNT_MAX) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_emmc_sdio_transfer(
      function,
      address,
      0,
      bytes,
      bytes_len,
      block_count,
      ER_PI_ZERO_W_V1_1_SDIO_CMD53_BLOCK_MODE,
      ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_read_le32(const UINT8* bytes) {
  return ((UINT32)bytes[ER_PI_ZERO_W_V1_1_LE_BYTE0]) |
         ((UINT32)bytes[ER_PI_ZERO_W_V1_1_LE_BYTE1] <<
          ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) |
         ((UINT32)bytes[ER_PI_ZERO_W_V1_1_LE_BYTE2] <<
          ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) |
         ((UINT32)bytes[ER_PI_ZERO_W_V1_1_LE_BYTE3] <<
          ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT);
}

static void er_pi_zero_w_v1_1_cyw43438_put_le32(UINT8* bytes, UINT32 value) {
  bytes[ER_PI_ZERO_W_V1_1_LE_BYTE0] =
      (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[ER_PI_ZERO_W_V1_1_LE_BYTE1] =
      (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
              ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[ER_PI_ZERO_W_V1_1_LE_BYTE2] =
      (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
              ER_PI_ZERO_W_V1_1_BYTE_MASK);
  bytes[ER_PI_ZERO_W_V1_1_LE_BYTE3] =
      (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
              ER_PI_ZERO_W_V1_1_BYTE_MASK);
}

static UINT16 er_pi_zero_w_v1_1_cyw43438_read_le16(const UINT8* bytes) {
  return (UINT16)(((UINT16)bytes[ER_PI_ZERO_W_V1_1_LE_BYTE0]) |
                  ((UINT16)bytes[ER_PI_ZERO_W_V1_1_LE_BYTE1] <<
                   ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT));
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_wait_io_ready(UINT8 ready_mask) {
  UINT8 ready;
  UINT32 poll;

  for (poll = 0u; poll < ER_PI_ZERO_W_V1_1_CYW43438_READY_POLL_BUDGET; ++poll) {
    if (er_pi_zero_w_v1_1_emmc_sdio_read_direct(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_CCCR,
            ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_READY_ADDR,
            &ready) != 0u &&
        (((UINT32)ready & (UINT32)ready_mask) == (UINT32)ready_mask)) {
      return 1u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_set_io_enable(UINT8 enable_mask) {
  return er_pi_zero_w_v1_1_emmc_sdio_write_byte(
             ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_CCCR,
             ER_PI_ZERO_W_V1_1_CYW43438_CCCR_IO_ENABLE_ADDR,
             enable_mask) != 0u &&
         er_pi_zero_w_v1_1_cyw43438_wait_io_ready(enable_mask) != 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_request_clock(UINT8 request_mask,
                                                       UINT8 ready_mask,
                                                       UINT8 force_mask) {
  UINT8 clock;
  UINT32 poll;

  if (er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR,
          ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HW_CLKREQ_OFF | request_mask) == 0u) {
    return 0u;
  }
  for (poll = 0u; poll < ER_PI_ZERO_W_V1_1_CYW43438_ALP_POLL_BUDGET; ++poll) {
    if (er_pi_zero_w_v1_1_emmc_sdio_read_direct(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
            ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR,
            &clock) != 0u &&
        (((UINT32)clock & (UINT32)ready_mask) != 0u)) {
      return er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_CHIPCLKCSR,
          ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HW_CLKREQ_OFF | force_mask);
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_enable_function1(void) {
  return er_pi_zero_w_v1_1_cyw43438_set_io_enable(
      ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTION_1);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_buscoreprep(void) {
  if (er_pi_zero_w_v1_1_cyw43438_enable_function1() == 0u ||
      er_pi_zero_w_v1_1_cyw43438_request_clock(
          ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL_REQ,
          ER_PI_ZERO_W_V1_1_CYW43438_ALP_AVAIL,
          ER_PI_ZERO_W_V1_1_CYW43438_FORCE_ALP) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_emmc_sdio_write_byte(
      ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
      ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_SDIOPULLUP,
      0u);
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
        er_pi_zero_w_v1_1_emmc_sdio_transfer(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
            er_pi_zero_w_v1_1_cyw43438_backplane_address(current_address),
            bytes + offset,
            0,
            chunk,
            chunk,
            ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
            ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE) == 0u) {
      return 0u;
    }
    offset += chunk;
  }
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_read_bytes(
    UINT32 address,
    UINT8* bytes,
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
                       (current_address &
                        ER_PI_ZERO_W_V1_1_CYW43438_SB_ADDR_MASK);
    chunk = bytes_len - offset;
    if (chunk > ER_PI_ZERO_W_V1_1_CYW43438_RAM_CHUNK_BYTES) {
      chunk = ER_PI_ZERO_W_V1_1_CYW43438_RAM_CHUNK_BYTES;
    }
    if (chunk > window_remaining) {
      chunk = window_remaining;
    }
    if (er_pi_zero_w_v1_1_cyw43438_set_backplane_window(current_address) == 0u ||
        er_pi_zero_w_v1_1_emmc_sdio_transfer(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
            er_pi_zero_w_v1_1_cyw43438_backplane_address(current_address),
            0,
            bytes + offset,
            chunk,
            chunk,
            ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
            ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ) == 0u) {
      return 0u;
    }
    offset += chunk;
  }
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_read32(UINT32 address,
                                                         UINT32* out_value) {
  UINT8 bytes[sizeof(UINT32)];

  if (out_value == 0 ||
      er_pi_zero_w_v1_1_cyw43438_set_backplane_window(address) == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_transfer(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          er_pi_zero_w_v1_1_cyw43438_backplane_address(address),
          0,
          bytes,
          (UINT32)sizeof(bytes),
          (UINT32)sizeof(bytes),
          ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
          ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ) == 0u) {
    return 0u;
  }
  *out_value = er_pi_zero_w_v1_1_cyw43438_read_le32(bytes);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_backplane_write32(UINT32 address,
                                                          UINT32 value) {
  UINT8 bytes[sizeof(UINT32)];

  er_pi_zero_w_v1_1_cyw43438_put_le32(bytes, value);
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

static UINT32 er_pi_zero_w_v1_1_cyw43438_enable_function2(void) {
  if (er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_CCCR,
          ER_PI_ZERO_W_V1_1_CYW43438_CCCR_F2_BLOCK_SIZE_LOW,
          (UINT8)(ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES &
                  ER_PI_ZERO_W_V1_1_BYTE_MASK)) == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_CCCR,
          ER_PI_ZERO_W_V1_1_CYW43438_CCCR_F2_BLOCK_SIZE_HIGH,
          (UINT8)((ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES >>
                   ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                  ER_PI_ZERO_W_V1_1_BYTE_MASK)) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_set_io_enable(
      ER_PI_ZERO_W_V1_1_CYW43438_CCCR_ENABLE_FUNCTIONS_1_2);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_force_ht_clock(void) {
  return er_pi_zero_w_v1_1_cyw43438_request_clock(
      ER_PI_ZERO_W_V1_1_CYW43438_HT_AVAIL_REQ,
      ER_PI_ZERO_W_V1_1_CYW43438_HT_AVAIL,
      ER_PI_ZERO_W_V1_1_CYW43438_FORCE_HT);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_start_wlan_firmware(void) {
  UINT32 arm_base;
  UINT32 arm_wrap;
  UINT32 mem_base;
  UINT32 mem_wrap;
  UINT32 d11_base;
  UINT32 d11_wrap;
  UINT32 sdio_base;
  UINT32 sdio_wrap;
  UINT32 nvram_address;
  UINT32 reset_vector;

  if (ER_PI_ZERO_W_V1_1_CYW43438_RAM_FIRMWARE_SIZE >=
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE ||
      ER_PI_ZERO_W_V1_1_CYW43438_NVRAM_FIRMWARE_SIZE >=
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE ||
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
      er_pi_zero_w_v1_1_cyw43438_find_core(
          ER_PI_ZERO_W_V1_1_CYW43438_SDIO_CORE,
          &sdio_base,
          &sdio_wrap) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_set_passive(arm_wrap,
                                             mem_base,
                                             mem_wrap,
                                             d11_wrap) == 0u) {
    return 0u;
  }
  (void)arm_base;
  (void)mem_base;
  (void)d11_base;
  (void)sdio_wrap;
  nvram_address = ER_PI_ZERO_W_V1_1_CYW43438_RAM_SIZE -
                  (UINT32)ER_PI_ZERO_W_V1_1_CYW43438_NVRAM_FIRMWARE_SIZE;
  reset_vector = er_pi_zero_w_v1_1_cyw43438_read_le32(
      g_er_pi_zero_w_v1_1_cyw43438_ram_firmware);
  if (er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_BASE,
          g_er_pi_zero_w_v1_1_cyw43438_ram_firmware,
          (UINT32)ER_PI_ZERO_W_V1_1_CYW43438_RAM_FIRMWARE_SIZE) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write_bytes(
          nvram_address,
          g_er_pi_zero_w_v1_1_cyw43438_nvram_firmware,
          (UINT32)ER_PI_ZERO_W_V1_1_CYW43438_NVRAM_FIRMWARE_SIZE) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          ER_PI_ZERO_W_V1_1_CYW43438_RAM_BASE,
          reset_vector) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_reset_core(arm_wrap, 0u, 0u, 0u) == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_WIFI_POWER_DELAY_TICKS);
  if (er_pi_zero_w_v1_1_cyw43438_force_ht_clock() == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          sdio_base + ER_PI_ZERO_W_V1_1_CYW43438_SDIO_TOSBMAILBOXDATA,
          ER_PI_ZERO_W_V1_1_CYW43438_SDPCM_PROT_VERSION <<
              ER_PI_ZERO_W_V1_1_CYW43438_SMB_DATA_VERSION_SHIFT) == 0u ||
      er_pi_zero_w_v1_1_cyw43438_enable_function2() == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_write32(
          sdio_base + ER_PI_ZERO_W_V1_1_CYW43438_SDIO_HOSTINTMASK,
          ER_PI_ZERO_W_V1_1_CYW43438_HOSTINTMASK) == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_write_byte(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_BACKPLANE,
          ER_PI_ZERO_W_V1_1_CYW43438_FUNC1_WATERMARK,
          ER_PI_ZERO_W_V1_1_CYW43438_F2_WATERMARK) == 0u) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_sdio_probe_response = sdio_base;
  g_er_pi_zero_w_v1_1_cyw43438_sdio_base = sdio_base;
  g_er_pi_zero_w_v1_1_sdio_probe_interrupt =
      (UINT32)ER_PI_ZERO_W_V1_1_CYW43438_CLM_FIRMWARE_SIZE;
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
      er_pi_zero_w_v1_1_mmc_rca_from_response(response);
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

static UINT32 er_pi_zero_w_v1_1_sd_memory_app_command(UINT32 rca,
                                                      UINT32 command_index,
                                                      UINT32 argument,
                                                      UINT32 response_kind,
                                                      UINT32* out_response) {
  UINT32 app_response;

  if (out_response == 0 ||
      er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_APP_CMD,
                                     er_pi_zero_w_v1_1_mmc_rca_argument(rca),
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1,
                                     &app_response) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_emmc_command(command_index,
                                        argument,
                                        response_kind,
                                        out_response);
}

static UINT32 er_pi_zero_w_v1_1_storage_probe_error(void) {
  g_er_pi_zero_w_v1_1_storage_probe_state =
      ER_PI_ZERO_W_V1_1_STORAGE_PROBE_ERROR;
  return 0u;
}

static void er_pi_zero_w_v1_1_storage_probe_step(UINT32 response,
                                                 UINT32 probe_state) {
  g_er_pi_zero_w_v1_1_storage_last_response = response;
  g_er_pi_zero_w_v1_1_storage_probe_state = probe_state;
}

static UINT32 er_pi_zero_w_v1_1_sd_memory_init(void) {
  UINT32 response;
  UINT32 poll;

  g_er_pi_zero_w_v1_1_storage_probe_state =
      ER_PI_ZERO_W_V1_1_STORAGE_PROBE_NONE;
  g_er_pi_zero_w_v1_1_storage_relative_card_address = 0u;
  g_er_pi_zero_w_v1_1_storage_last_response = 0u;
  if (er_pi_zero_w_v1_1_emmc_init() == 0u ||
      er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_GO_IDLE_STATE,
                                     0u,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_NONE,
                                     &response) == 0u ||
      er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_SEND_IF_COND,
                                     ER_PI_ZERO_W_V1_1_SD_MEMORY_IF_COND_3V3_CHECK,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R7,
                                     &response) == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  er_pi_zero_w_v1_1_storage_probe_step(response,
                                       ER_PI_ZERO_W_V1_1_STORAGE_PROBE_CMD8_DONE);
  for (poll = 0u;
       poll < ER_PI_ZERO_W_V1_1_SD_MEMORY_OCR_POLL_BUDGET;
       ++poll) {
    if (er_pi_zero_w_v1_1_sd_memory_app_command(
            0u,
            ER_PI_ZERO_W_V1_1_MMC_ACMD_SD_SEND_OP_COND,
            ER_PI_ZERO_W_V1_1_SD_MEMORY_OCR_3V3_HCS,
            ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R3,
            &response) == 0u) {
      return er_pi_zero_w_v1_1_storage_probe_error();
    }
    g_er_pi_zero_w_v1_1_storage_last_response = response;
    if ((response & ER_PI_ZERO_W_V1_1_SD_MEMORY_OCR_READY) != 0u) {
      break;
    }
  }
  if ((response & ER_PI_ZERO_W_V1_1_SD_MEMORY_OCR_READY) == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  g_er_pi_zero_w_v1_1_storage_probe_state =
      ER_PI_ZERO_W_V1_1_STORAGE_PROBE_ACMD41_DONE;
  if (er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_ALL_SEND_CID,
                                     0u,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R2,
                                     &response) == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  er_pi_zero_w_v1_1_storage_probe_step(response,
                                       ER_PI_ZERO_W_V1_1_STORAGE_PROBE_CMD2_DONE);
  if (er_pi_zero_w_v1_1_emmc_command(ER_PI_ZERO_W_V1_1_MMC_CMD_SEND_RELATIVE_ADDR,
                                     0u,
                                     ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R6,
                                     &response) == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  g_er_pi_zero_w_v1_1_storage_last_response = response;
  g_er_pi_zero_w_v1_1_storage_relative_card_address =
      er_pi_zero_w_v1_1_mmc_rca_from_response(response);
  if (g_er_pi_zero_w_v1_1_storage_relative_card_address == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  g_er_pi_zero_w_v1_1_storage_probe_state =
      ER_PI_ZERO_W_V1_1_STORAGE_PROBE_CMD3_DONE;
  if (er_pi_zero_w_v1_1_emmc_command(
          ER_PI_ZERO_W_V1_1_MMC_CMD_SELECT_CARD,
          er_pi_zero_w_v1_1_mmc_rca_argument(
              g_er_pi_zero_w_v1_1_storage_relative_card_address),
          ER_PI_ZERO_W_V1_1_MMC_RESPONSE_R1,
          &response) == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  er_pi_zero_w_v1_1_storage_probe_step(response,
                                       ER_PI_ZERO_W_V1_1_STORAGE_READY);
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_storage_ready(void) {
  if (g_er_pi_zero_w_v1_1_storage_probe_state ==
          ER_PI_ZERO_W_V1_1_STORAGE_READY ||
      g_er_pi_zero_w_v1_1_storage_probe_state ==
          ER_PI_ZERO_W_V1_1_STORAGE_WRITE_VERIFIED) {
    return 1u;
  }
  return er_pi_zero_w_v1_1_sd_memory_init();
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

static UINT8 er_pi_zero_w_v1_1_uart_try_get_byte(UINT8* out_byte) {
  UINT32 lsr;

  if (out_byte == 0) {
    return 0u;
  }
  lsr = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_AUX_BASE,
                               ER_PI_ZERO_W_V1_1_AUX_MU_LSR);
  if ((lsr & ER_PI_ZERO_W_V1_1_AUX_MU_LSR_RX_READY) == 0u) {
    return 0u;
  }
  *out_byte = (UINT8)(er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_AUX_BASE,
                                             ER_PI_ZERO_W_V1_1_AUX_MU_IO) &
                      ER_PI_ZERO_W_V1_1_BYTE_MASK);
  return 1u;
}

static void er_pi_zero_w_v1_1_put_u16(UINT8** cursor, UINT16 value) {
  (*cursor)[0] = (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[1] = (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
                         ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += 2u;
}

static void er_pi_zero_w_v1_1_put_u32(UINT8** cursor, UINT32 value) {
  (*cursor)[ER_PI_ZERO_W_V1_1_LE_BYTE0] =
      (UINT8)(value & ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[ER_PI_ZERO_W_V1_1_LE_BYTE1] =
      (UINT8)((value >> ER_PI_ZERO_W_V1_1_U16_HIGH_SHIFT) &
              ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[ER_PI_ZERO_W_V1_1_LE_BYTE2] =
      (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE2_SHIFT) &
              ER_PI_ZERO_W_V1_1_BYTE_MASK);
  (*cursor)[ER_PI_ZERO_W_V1_1_LE_BYTE3] =
      (UINT8)((value >> ER_PI_ZERO_W_V1_1_U32_BYTE3_SHIFT) &
              ER_PI_ZERO_W_V1_1_BYTE_MASK);
  *cursor += (UINT32)sizeof(UINT32);
}

static void er_pi_zero_w_v1_1_put_u64(UINT8** cursor, UINT64 value) {
  er_pi_zero_w_v1_1_put_u32(cursor, (UINT32)value);
  er_pi_zero_w_v1_1_put_u32(cursor,
                            (UINT32)(value >> ER_PI_ZERO_W_V1_1_U64_BYTE4_SHIFT));
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

static void er_pi_zero_w_v1_1_put_nonce_word(UINT8* nonce,
                                             UINT32 word_index,
                                             UINT32 value) {
  UINT8* cursor = nonce + (word_index * (UINT32)sizeof(UINT32));

  er_pi_zero_w_v1_1_put_u32(&cursor, value);
}

static UINT32 er_pi_zero_w_v1_1_mix_entropy(UINT32 state, UINT32 sample) {
  return state ^ (sample + ER_PI_ZERO_W_V1_1_MIX_CONSTANT +
                  (state << ER_PI_ZERO_W_V1_1_MIX_LEFT_SHIFT) +
                  (state >> ER_PI_ZERO_W_V1_1_MIX_RIGHT_SHIFT));
}

static void er_pi_zero_w_v1_1_boot_nonce(
    UINT8 nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN]) {
  UINT32 state;
  UINT32 i;

  state = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_BASE,
                                 ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_COUNTER_LOW) ^
          ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_NODE_ENTROPY_ROUNDS; ++i) {
    er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_NODE_ENTROPY_DELAY_TICKS + i);
    state = er_pi_zero_w_v1_1_mix_entropy(
        state,
        er_pi_zero_w_v1_1_read(
            ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_BASE,
            ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_COUNTER_LOW));
    state = er_pi_zero_w_v1_1_mix_entropy(
        state,
        er_pi_zero_w_v1_1_read(
            ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_BASE,
            ER_PI_ZERO_W_V1_1_SYSTEM_TIMER_COUNTER_HIGH));
    state = er_pi_zero_w_v1_1_mix_entropy(
        state,
        er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_AUX_BASE,
                               ER_PI_ZERO_W_V1_1_AUX_MU_LSR));
    state = er_pi_zero_w_v1_1_mix_entropy(
        state,
        (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state ^
            (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state);
    er_pi_zero_w_v1_1_put_nonce_word(nonce, i, state);
  }
  nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN - 1u] |= 1u;
}

static UINT8 er_pi_zero_w_v1_1_init_ephemeral_identity(void) {
  ErCryptoProvider crypto;
  ErHash admission_id;
  ErEphemeralNode node;
  UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN];
  UINT32 i;

  er_crypto_blake3_provider(&crypto);
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_HASH_BYTES; ++i) {
    admission_id.bytes[i] = g_er_pi_zero_w_v1_1_admission_id[i];
  }
  er_pi_zero_w_v1_1_boot_nonce(boot_nonce);
  if (er_ephemeral_node_derive(&crypto,
                               &admission_id,
                               boot_nonce,
                               &node) == 0u) {
    return 0u;
  }
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_NODE_BYTES; ++i) {
    g_er_pi_zero_w_v1_1_node_id[i] = node.node_id.bytes[i];
  }
  return 1u;
}

static void er_pi_zero_w_v1_1_node_id(ErNodeId* out_node_id) {
  UINT32 i;

  for (i = 0u; i < ER_PI_ZERO_W_V1_1_NODE_BYTES; ++i) {
    out_node_id->bytes[i] = g_er_pi_zero_w_v1_1_node_id[i];
  }
}

static UINT32 er_pi_zero_w_v1_1_wifi_plan(ErWifiL2ApPlan* out_plan) {
  ErNodeId node_id;

  if (out_plan == 0) {
    return 0u;
  }
  er_pi_zero_w_v1_1_node_id(&node_id);
  return er_wifi_l2_control_plan_prepare(&node_id, out_plan);
}

static UINT32 er_pi_zero_w_v1_1_wifi_address(
    UINT8 out_address[ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES]) {
  ErWifiL2ApPlan plan;
  ErHash channel_id;
  ErChannelEndpoint endpoint;
  UINT32 i;

  if (out_address == 0 ||
      er_pi_zero_w_v1_1_wifi_plan(&plan) == 0u) {
    return 0u;
  }
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_HASH_BYTES; ++i) {
    channel_id.bytes[i] = g_er_pi_zero_w_v1_1_channel_id[i];
  }
  if (er_wifi_l2_prepare_channel_endpoint(&channel_id,
                                          &plan,
                                          ER_PI_ZERO_W_V1_1_L2_LABEL,
                                          ER_PI_ZERO_W_V1_1_L2_LABEL_BYTES,
                                          &endpoint) == 0u ||
      endpoint.address_len != ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES) {
    return 0u;
  }
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_L2_ADDRESS_BYTES; ++i) {
    out_address[i] = endpoint.address[i];
  }
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_cyw43438_next_sdpcm_sequence(void) {
  UINT8 sequence = g_er_pi_zero_w_v1_1_cyw43438_sdpcm_sequence;

  g_er_pi_zero_w_v1_1_cyw43438_sdpcm_sequence =
      (UINT8)(g_er_pi_zero_w_v1_1_cyw43438_sdpcm_sequence + 1u);
  if (g_er_pi_zero_w_v1_1_cyw43438_sdpcm_sequence == 0u) {
    g_er_pi_zero_w_v1_1_cyw43438_sdpcm_sequence = 1u;
  }
  return sequence;
}

static UINT16 er_pi_zero_w_v1_1_cyw43438_next_bcdc_request_id(void) {
  UINT16 request_id = g_er_pi_zero_w_v1_1_cyw43438_bcdc_request_id;

  g_er_pi_zero_w_v1_1_cyw43438_bcdc_request_id =
      (UINT16)(g_er_pi_zero_w_v1_1_cyw43438_bcdc_request_id + 1u);
  if (g_er_pi_zero_w_v1_1_cyw43438_bcdc_request_id == 0u) {
    g_er_pi_zero_w_v1_1_cyw43438_bcdc_request_id = 1u;
  }
  return request_id;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_f2_fifo_address(void) {
  if (er_pi_zero_w_v1_1_cyw43438_set_backplane_window(
          ER_PI_ZERO_W_V1_1_CYW43438_CHIPCOMMON_BASE) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_backplane_address(
      ER_PI_ZERO_W_V1_1_CYW43438_CHIPCOMMON_BASE);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_read_sdpcm_frame(
    UINT8* frame,
    UINT32 frame_capacity,
    UINT32* out_frame_len) {
  UINT32 intstatus;
  UINT32 frame_len;
  UINT32 checksum;
  UINT32 remaining;
  UINT32 read_address;

  if (frame == 0 ||
      out_frame_len == 0 ||
      frame_capacity < ER_CYW43438_SDPCM_HEADER_BYTES ||
      g_er_pi_zero_w_v1_1_cyw43438_sdio_base == 0u ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          g_er_pi_zero_w_v1_1_cyw43438_sdio_base +
              ER_PI_ZERO_W_V1_1_CYW43438_SDIO_INTSTATUS,
          &intstatus) == 0u ||
      (intstatus & ER_PI_ZERO_W_V1_1_CYW43438_INT_HMB_FRAME_IND) == 0u) {
    return 0u;
  }
  read_address = er_pi_zero_w_v1_1_cyw43438_f2_fifo_address();
  if (read_address == 0u ||
      er_pi_zero_w_v1_1_emmc_sdio_transfer(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_WLAN,
          read_address,
          0,
          frame,
          ER_CYW43438_SDPCM_HEADER_BYTES,
          ER_CYW43438_SDPCM_HEADER_BYTES,
          ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
          ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ) == 0u) {
    return 0u;
  }
  frame_len = er_pi_zero_w_v1_1_cyw43438_read_le16(frame);
  checksum = er_pi_zero_w_v1_1_cyw43438_read_le16(
      frame + (UINT32)sizeof(UINT16));
  if (frame_len < ER_CYW43438_SDPCM_HEADER_BYTES ||
      frame_len > frame_capacity ||
      ((frame_len ^ checksum) & ER_CYW43438_SDPCM_HEADER_CHECK_VALUE) !=
          ER_CYW43438_SDPCM_HEADER_CHECK_VALUE) {
    return 0u;
  }
  remaining = frame_len - ER_CYW43438_SDPCM_HEADER_BYTES;
  if (remaining != 0u &&
      remaining <= ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK &&
      er_pi_zero_w_v1_1_emmc_sdio_transfer(
          ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_WLAN,
          read_address,
          0,
          frame + ER_CYW43438_SDPCM_HEADER_BYTES,
          remaining,
          remaining,
          ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
          ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_READ) == 0u) {
    return 0u;
  }
  if (remaining > ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK) {
    UINT32 block_count;

    if (remaining <= ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES) {
      block_count = 1u;
    } else if (remaining <=
               (ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_BYTES * 2u)) {
      block_count = 2u;
    } else {
      block_count = ER_PI_ZERO_W_V1_1_CYW43438_F2_BLOCK_COUNT_MAX;
    }
    if (er_pi_zero_w_v1_1_emmc_sdio_read_blocks(
            ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_WLAN,
            read_address,
            frame + ER_CYW43438_SDPCM_HEADER_BYTES,
            block_count) == 0u) {
      return 0u;
    }
  }
  (void)er_pi_zero_w_v1_1_cyw43438_backplane_write32(
      g_er_pi_zero_w_v1_1_cyw43438_sdio_base +
          ER_PI_ZERO_W_V1_1_CYW43438_SDIO_INTSTATUS,
      intstatus);
  *out_frame_len = frame_len;
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_write_sdpcm_frame(
    const UINT8* frame,
    UINT32 frame_len) {
  UINT32 write_address;

  if (frame == 0 ||
      frame_len == 0u ||
      frame_len > ER_PI_ZERO_W_V1_1_SDIO_CMD53_COUNT_MASK) {
    return 0u;
  }
  write_address = er_pi_zero_w_v1_1_cyw43438_f2_fifo_address();
  if (write_address == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_emmc_sdio_transfer(
      ER_PI_ZERO_W_V1_1_SDIO_FUNCTION_WLAN,
      write_address,
      frame,
      0,
      frame_len,
      frame_len,
      ER_PI_ZERO_W_V1_1_SDIO_CMD53_BYTE_MODE,
      ER_PI_ZERO_W_V1_1_SDIO_TRANSFER_WRITE);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_wait_bcdc_response(
    UINT16 request_id) {
  UINT32 poll;

  for (poll = 0u;
       poll < ER_PI_ZERO_W_V1_1_CYW43438_CONTROL_POLL_BUDGET;
       ++poll) {
    UINT32 frame_len;
    ErCyw43438BcdcDcmd dcmd;

    if (er_pi_zero_w_v1_1_cyw43438_read_sdpcm_frame(
            g_er_pi_zero_w_v1_1_l2_rx_frame,
            (UINT32)sizeof(g_er_pi_zero_w_v1_1_l2_rx_frame),
            &frame_len) == 0u) {
      continue;
    }
    if (er_cyw43438_bcdc_parse_dcmd_response(
            g_er_pi_zero_w_v1_1_l2_rx_frame,
            frame_len,
            request_id,
            &dcmd) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_send_bcdc_frame(
    UINT16 request_id,
    UINT32 frame_len) {
  if (er_pi_zero_w_v1_1_cyw43438_write_sdpcm_frame(
          g_er_pi_zero_w_v1_1_l2_tx_frame,
          frame_len) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_wait_bcdc_response(request_id);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_dcmd_int(UINT32 command,
                                                  UINT32 value) {
  UINT16 request_id;
  UINT32 frame_len;

  request_id = er_pi_zero_w_v1_1_cyw43438_next_bcdc_request_id();
  if (er_cyw43438_bcdc_build_int_dcmd(
          er_pi_zero_w_v1_1_cyw43438_next_sdpcm_sequence(),
          request_id,
          command,
          value,
          g_er_pi_zero_w_v1_1_l2_tx_frame,
          (UINT32)sizeof(g_er_pi_zero_w_v1_1_l2_tx_frame),
          &frame_len) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_send_bcdc_frame(request_id, frame_len);
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_iovar_int(const char* name,
                                                   UINT32 value) {
  UINT16 request_id;
  UINT32 frame_len;

  request_id = er_pi_zero_w_v1_1_cyw43438_next_bcdc_request_id();
  if (er_cyw43438_bcdc_build_iovar_int_dcmd(
          er_pi_zero_w_v1_1_cyw43438_next_sdpcm_sequence(),
          request_id,
          name,
          value,
          g_er_pi_zero_w_v1_1_l2_tx_frame,
          (UINT32)sizeof(g_er_pi_zero_w_v1_1_l2_tx_frame),
          &frame_len) == 0u) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_send_bcdc_frame(request_id, frame_len);
}

static UINT32 er_pi_zero_w_v1_1_wifi_stage_error(UINT32 stage) {
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_ERROR | stage;
  return 0u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_join_control_ap(
    const ErWifiL2ApPlan* plan) {
  UINT16 request_id;
  UINT32 frame_len;

  if (plan == 0) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_PLAN);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_MPC;
  if (er_pi_zero_w_v1_1_cyw43438_iovar_int(
          g_er_pi_zero_w_v1_1_cyw43438_iovar_mpc,
          0u) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_MPC);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_INFRA;
  if (er_pi_zero_w_v1_1_cyw43438_dcmd_int(
          ER_CYW43438_BCDC_CMD_SET_INFRA,
          ER_CYW43438_BCDC_INFRA_STA) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_INFRA);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_AUTH;
  if (er_pi_zero_w_v1_1_cyw43438_dcmd_int(
          ER_CYW43438_BCDC_CMD_SET_AUTH,
          ER_CYW43438_BCDC_OPEN_AUTH) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_AUTH);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_WSEC;
  if (er_pi_zero_w_v1_1_cyw43438_dcmd_int(
          ER_CYW43438_BCDC_CMD_SET_WSEC,
          ER_CYW43438_BCDC_WSEC_OPEN) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_WSEC);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_CHANNEL;
  if (er_pi_zero_w_v1_1_cyw43438_dcmd_int(
          ER_CYW43438_BCDC_CMD_SET_CHANNEL,
          plan->channel) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_CHANNEL);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_UP;
  if (er_pi_zero_w_v1_1_cyw43438_dcmd_int(
          ER_CYW43438_BCDC_CMD_UP,
          0u) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_UP);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_SSID;
  request_id = er_pi_zero_w_v1_1_cyw43438_next_bcdc_request_id();
  if (er_cyw43438_bcdc_build_set_ssid_dcmd(
          er_pi_zero_w_v1_1_cyw43438_next_sdpcm_sequence(),
          request_id,
          plan->ssid,
          plan->ssid_len,
          g_er_pi_zero_w_v1_1_l2_tx_frame,
          (UINT32)sizeof(g_er_pi_zero_w_v1_1_l2_tx_frame),
          &frame_len) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_SSID);
  }
  if (er_pi_zero_w_v1_1_cyw43438_send_bcdc_frame(request_id, frame_len) ==
      0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_SSID);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_READY;
  return 1u;
}

static UINT32 er_pi_zero_w_v1_1_cyw43438_start_owned_l2(void) {
  ErWifiL2ApPlan plan;

  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_PLAN;
  if (er_pi_zero_w_v1_1_wifi_plan(&plan) == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_PLAN);
  }
  g_er_pi_zero_w_v1_1_wifi_control_state =
      ER_PI_ZERO_W_V1_1_WIFI_STAGE_FIRMWARE;
  if (er_pi_zero_w_v1_1_cyw43438_start_wlan_firmware() == 0u) {
    return er_pi_zero_w_v1_1_wifi_stage_error(
        ER_PI_ZERO_W_V1_1_WIFI_STAGE_FIRMWARE);
  }
  return er_pi_zero_w_v1_1_cyw43438_join_control_ap(&plan);
}

static UINT32 er_pi_zero_w_v1_1_ota_wire_magic(const UINT8* bytes) {
  if (bytes == 0) {
    return 0u;
  }
  return er_pi_zero_w_v1_1_cyw43438_read_le32(bytes);
}

static UINT64 er_pi_zero_w_v1_1_node_nonce(void) {
  return (UINT64)er_pi_zero_w_v1_1_cyw43438_read_le32(
             g_er_pi_zero_w_v1_1_node_id) |
         ((UINT64)er_pi_zero_w_v1_1_cyw43438_read_le32(
              g_er_pi_zero_w_v1_1_node_id + (UINT32)sizeof(UINT32))
          << ER_PI_ZERO_W_V1_1_U64_BYTE4_SHIFT);
}

static void er_pi_zero_w_v1_1_storage_emmc_ops(ErPiEmmcMmioOps* ops) {
  ops->ctx = 0;
  ops->read32 = er_pi_zero_w_v1_1_emmc_read32_op;
  ops->write32 = er_pi_zero_w_v1_1_emmc_write32_op;
  ops->read8 = 0;
  ops->write8 = 0;
}

static UINT8 er_pi_zero_w_v1_1_storage_block_error(
    const ErPiEmmcBlockResult* result) {
  g_er_pi_zero_w_v1_1_storage_probe_state =
      ER_PI_ZERO_W_V1_1_STORAGE_PROBE_ERROR;
  g_er_pi_zero_w_v1_1_storage_last_response = result->response0;
  return 0u;
}

static void er_pi_zero_w_v1_1_storage_block_step(
    UINT32 block_address,
    const ErPiEmmcBlockResult* result) {
  g_er_pi_zero_w_v1_1_storage_last_block = block_address;
  g_er_pi_zero_w_v1_1_storage_last_response = result->response0;
}

static UINT8 er_pi_zero_w_v1_1_storage_read_block(
    UINT32 block_address,
    UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES]) {
  ErPiEmmcMmioOps ops;
  ErPiEmmcBlockResult result;

  if (block == 0 ||
      er_pi_zero_w_v1_1_storage_ready() == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_storage_emmc_ops(&ops);
  if (er_pi_emmc_read_block_with_ops(&ops,
                                     block_address,
                                     block,
                                     ER_PI_ZERO_W_V1_1_SDIO_POLL_BUDGET,
                                     &result) == 0u) {
    return er_pi_zero_w_v1_1_storage_block_error(&result);
  }
  er_pi_zero_w_v1_1_storage_block_step(block_address, &result);
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_storage_blocks_equal(const UINT8* left,
                                                    const UINT8* right) {
  UINT32 i;

  if (left == 0 || right == 0) {
    return 0u;
  }
  for (i = 0u; i < ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES; ++i) {
    if (left[i] != right[i]) {
      return 0u;
    }
  }
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_storage_write_block_verified(
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES]) {
  ErPiEmmcMmioOps ops;
  ErPiEmmcBlockResult result;
  UINT8 readback[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES];

  if (block == 0 ||
      er_pi_zero_w_v1_1_storage_ready() == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_storage_emmc_ops(&ops);
  if (er_pi_emmc_write_block_with_ops(&ops,
                                      block_address,
                                      block,
                                      ER_PI_ZERO_W_V1_1_SDIO_POLL_BUDGET,
                                      &result) == 0u) {
    return er_pi_zero_w_v1_1_storage_block_error(&result);
  }
  er_pi_zero_w_v1_1_storage_block_step(block_address, &result);
  if (er_pi_zero_w_v1_1_storage_read_block(block_address, readback) == 0u ||
      er_pi_zero_w_v1_1_storage_blocks_equal(block, readback) == 0u) {
    return er_pi_zero_w_v1_1_storage_probe_error();
  }
  return 1u;
}

static UINT8 er_pi_zero_w_v1_1_boot_log_write_block(
    void* ctx,
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_BYTES]) {
  (void)ctx;
  return er_pi_zero_w_v1_1_storage_write_block_verified(block_address, block);
}

static UINT8 er_pi_zero_w_v1_1_ota_write_block_unbound(
    void* ctx,
    UINT32 block_address,
    const UINT8 block[ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES]) {
  (void)ctx;
  if (er_pi_zero_w_v1_1_storage_write_block_verified(block_address,
                                                     block) == 0u) {
    return 0u;
  }
  g_er_pi_zero_w_v1_1_storage_probe_state =
      ER_PI_ZERO_W_V1_1_STORAGE_WRITE_VERIFIED;
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_OTA_BLOCK_WRITTEN,
      block_address,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.next_offset,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.status,
      (UINT32)g_er_pi_zero_w_v1_1_storage_last_response);
  return 1u;
}

static void er_pi_zero_w_v1_1_ota_status_refresh(void) {
  g_er_pi_zero_w_v1_1_ota_status = g_er_pi_zero_w_v1_1_ota_state.status;
  g_er_pi_zero_w_v1_1_ota_offset = g_er_pi_zero_w_v1_1_ota_state.next_offset;
  g_er_pi_zero_w_v1_1_ota_target_block =
      g_er_pi_zero_w_v1_1_ota_state.target_block;
}

static void er_pi_zero_w_v1_1_ota_listen_init(void) {
  er_pi_zero_w_v1_1_ota_reset(&g_er_pi_zero_w_v1_1_ota_state);
  g_er_pi_zero_w_v1_1_uart_rx_len =
      ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER;
  g_er_pi_zero_w_v1_1_uart_rx_expected_len =
      ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER;
  er_pi_zero_w_v1_1_ota_status_refresh();
}

static void er_pi_zero_w_v1_1_uart_rx_reset(void) {
  g_er_pi_zero_w_v1_1_uart_rx_len =
      ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER;
  g_er_pi_zero_w_v1_1_uart_rx_expected_len =
      ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER;
}

static UINT8 er_pi_zero_w_v1_1_uart_rx_frame_header_ready(void) {
  UINT32 payload_len;

  if (g_er_pi_zero_w_v1_1_uart_rx_len !=
      ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE) {
    return 0u;
  }
  if (er_pi_zero_w_v1_1_cyw43438_read_le32(
          g_er_pi_zero_w_v1_1_uart_rx_frame +
          ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC_OFFSET) !=
          ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC ||
      er_pi_zero_w_v1_1_cyw43438_read_le16(
          g_er_pi_zero_w_v1_1_uart_rx_frame +
          ER_PI_ZERO_W_V1_1_ERWIRE_VERSION_OFFSET) !=
          ER_PI_ZERO_W_V1_1_ERWIRE_VERSION ||
      er_pi_zero_w_v1_1_cyw43438_read_le16(
          g_er_pi_zero_w_v1_1_uart_rx_frame +
          ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE_OFFSET) !=
          ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE ||
      er_pi_zero_w_v1_1_cyw43438_read_le32(
          g_er_pi_zero_w_v1_1_uart_rx_frame +
          ER_PI_ZERO_W_V1_1_ERWIRE_RESERVED_OFFSET) != 0u) {
    er_pi_zero_w_v1_1_uart_rx_reset();
    return 0u;
  }
  payload_len = er_pi_zero_w_v1_1_cyw43438_read_le32(
      g_er_pi_zero_w_v1_1_uart_rx_frame +
      ER_PI_ZERO_W_V1_1_ERWIRE_PAYLOAD_LEN_OFFSET);
  if (payload_len > ER_PI_ZERO_W_V1_1_OTA_ERWIRE_PAYLOAD_BYTES_MAX) {
    er_pi_zero_w_v1_1_uart_rx_reset();
    return 0u;
  }
  g_er_pi_zero_w_v1_1_uart_rx_expected_len =
      ER_PI_ZERO_W_V1_1_ERWIRE_HEADER_SIZE + payload_len;
  return 1u;
}

static void er_pi_zero_w_v1_1_ota_receive_complete_uart_frame(void) {
  ErCryptoProvider crypto;

  er_crypto_blake3_provider(&crypto);
  (void)er_pi_zero_w_v1_1_ota_receive_frame(
      &g_er_pi_zero_w_v1_1_ota_state,
      &crypto,
      g_er_pi_zero_w_v1_1_uart_rx_frame,
      g_er_pi_zero_w_v1_1_uart_rx_expected_len,
      er_pi_zero_w_v1_1_ota_write_block_unbound,
      0);
  er_pi_zero_w_v1_1_uart_rx_reset();
  er_pi_zero_w_v1_1_ota_status_refresh();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_UART_OTA_FRAME,
      (UINT32)g_er_pi_zero_w_v1_1_ota_status,
      (UINT32)g_er_pi_zero_w_v1_1_ota_offset,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.accepted_packet_count,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.reboot_required);
}

static void er_pi_zero_w_v1_1_ota_poll_uart_rx(void) {
  UINT32 poll_index;

  for (poll_index = 0u;
       poll_index < ER_PI_ZERO_W_V1_1_UART_RX_POLL_BYTES;
       ++poll_index) {
    UINT8 byte;

    if (er_pi_zero_w_v1_1_uart_try_get_byte(&byte) == 0u) {
      return;
    }
    if (g_er_pi_zero_w_v1_1_uart_rx_len >=
        ER_PI_ZERO_W_V1_1_UART_RX_FRAME_BYTES) {
      er_pi_zero_w_v1_1_uart_rx_reset();
      return;
    }
    g_er_pi_zero_w_v1_1_uart_rx_frame[g_er_pi_zero_w_v1_1_uart_rx_len] = byte;
    g_er_pi_zero_w_v1_1_uart_rx_len += 1u;
    if (g_er_pi_zero_w_v1_1_uart_rx_expected_len ==
            ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER &&
        er_pi_zero_w_v1_1_uart_rx_frame_header_ready() == 0u) {
      continue;
    }
    if (g_er_pi_zero_w_v1_1_uart_rx_expected_len !=
            ER_PI_ZERO_W_V1_1_UART_RX_EXPECTING_HEADER &&
        g_er_pi_zero_w_v1_1_uart_rx_len ==
            g_er_pi_zero_w_v1_1_uart_rx_expected_len) {
      er_pi_zero_w_v1_1_ota_receive_complete_uart_frame();
    }
  }
}

static UINT32 er_pi_zero_w_v1_1_ota_poll_owned_shared_rx(
    const ErCryptoProvider* crypto,
    const ErWifiL2ApPlan* plan) {
  UINT32 frame_len;
  UINT8 received;

  if (crypto == 0 ||
      plan == 0 ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read32(
          ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR,
          &frame_len) == 0u ||
      frame_len == 0u) {
    return 0u;
  }
  if (frame_len > ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_CAPACITY ||
      frame_len > ER_PI_ZERO_W_V1_1_CYW43438_F2_FRAME_BYTES ||
      er_pi_zero_w_v1_1_cyw43438_backplane_read_bytes(
          ER_CYW43438_OWNED_FIRMWARE_RX_FRAME_ADDR,
          g_er_pi_zero_w_v1_1_l2_rx_frame,
          frame_len) == 0u) {
    (void)er_pi_zero_w_v1_1_cyw43438_backplane_write32(
        ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR,
        0u);
    return 0u;
  }
  received = er_pi_zero_w_v1_1_ota_receive_l2_frame(
      &g_er_pi_zero_w_v1_1_ota_state,
      crypto,
      plan->mac,
      g_er_pi_zero_w_v1_1_l2_rx_frame,
      frame_len,
      er_pi_zero_w_v1_1_ota_write_block_unbound,
      0);
  (void)er_pi_zero_w_v1_1_cyw43438_backplane_write32(
      ER_CYW43438_OWNED_FIRMWARE_RX_LEN_ADDR,
      0u);
  if (received == 0u) {
    return 0u;
  }
  er_pi_zero_w_v1_1_ota_status_refresh();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_OTA_FRAME,
      (UINT32)g_er_pi_zero_w_v1_1_ota_status,
      (UINT32)g_er_pi_zero_w_v1_1_ota_offset,
      frame_len,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.reboot_required);
  return 1u;
}

static void er_pi_zero_w_v1_1_ota_poll_owned_rx(void) {
  ErCryptoProvider crypto;
  UINT32 frame_len;
  ErWifiL2ApPlan plan;
  UINT8 src_mac[ER_NET_MAC_LEN];
  const UINT8* erwire;
  UINT32 erwire_len;

  er_crypto_blake3_provider(&crypto);
  if (g_er_pi_zero_w_v1_1_sdio_probe_state != ER_PI_ZERO_W_V1_1_L2_READY ||
      er_pi_zero_w_v1_1_wifi_plan(&plan) == 0u) {
    return;
  }
  if (ER_CYW43438_OWNED_FIRMWARE_RAW_RX_SUPPORTED != 0u &&
      er_pi_zero_w_v1_1_ota_poll_owned_shared_rx(&crypto, &plan) != 0u) {
    return;
  }
  if (er_pi_zero_w_v1_1_cyw43438_read_sdpcm_frame(
          g_er_pi_zero_w_v1_1_l2_rx_frame,
          (UINT32)sizeof(g_er_pi_zero_w_v1_1_l2_rx_frame),
          &frame_len) == 0u) {
    return;
  }
  if (er_cyw43438_sdpcm_parse_raw_l2_erwire(
          g_er_pi_zero_w_v1_1_l2_rx_frame,
          frame_len,
          plan.mac,
          src_mac,
          &erwire,
          &erwire_len) == 0u ||
      er_pi_zero_w_v1_1_ota_wire_magic(erwire) !=
          ER_PI_ZERO_W_V1_1_ERWIRE_MAGIC) {
    return;
  }
  (void)er_pi_zero_w_v1_1_ota_receive_frame(
      &g_er_pi_zero_w_v1_1_ota_state,
      &crypto,
      erwire,
      erwire_len,
      er_pi_zero_w_v1_1_ota_write_block_unbound,
      0);
  er_pi_zero_w_v1_1_ota_status_refresh();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_OTA_FRAME,
      (UINT32)g_er_pi_zero_w_v1_1_ota_status,
      (UINT32)g_er_pi_zero_w_v1_1_ota_offset,
      erwire_len,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.reboot_required);
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

static void er_pi_zero_w_v1_1_put_update_state(UINT8** cursor) {
  er_pi_zero_w_v1_1_put_u32(
      cursor,
      (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state);
  er_pi_zero_w_v1_1_put_u32(
      cursor,
      (UINT32)g_er_pi_zero_w_v1_1_storage_relative_card_address);
  er_pi_zero_w_v1_1_put_u32(
      cursor,
      (UINT32)g_er_pi_zero_w_v1_1_storage_last_block);
  er_pi_zero_w_v1_1_put_u32(
      cursor,
      (UINT32)g_er_pi_zero_w_v1_1_storage_last_response);
  er_pi_zero_w_v1_1_put_u32(
      cursor,
      (UINT32)g_er_pi_zero_w_v1_1_ota_state.reboot_required);
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
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_ota_status);
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_ota_offset);
  er_pi_zero_w_v1_1_put_u32(
      &cursor,
      (UINT32)g_er_pi_zero_w_v1_1_ota_target_block);
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
  er_pi_zero_w_v1_1_put_update_state(&cursor);
  er_pi_zero_w_v1_1_send_erwire(ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_AVAILABLE,
                                0u,
                                payload,
                                ER_PI_ZERO_W_V1_1_NODE_AVAILABLE_BYTES);
}

static UINT8 er_pi_zero_w_v1_1_ble_capabilities(void) {
  UINT8 capabilities = ER_BLE_WIFI_CAPABILITY_AP |
                       ER_BLE_WIFI_CAPABILITY_STA;

  if (g_er_pi_zero_w_v1_1_ota_state.reboot_required != 0u ||
      g_er_pi_zero_w_v1_1_ota_state.status ==
          ER_PI_ZERO_W_V1_1_OTA_STATUS_RECEIVING) {
    capabilities |= ER_BLE_WIFI_CAPABILITY_BURST_TX_PENDING;
  }
  return capabilities;
}

static UINT16 er_pi_zero_w_v1_1_ble_sequence(UINT32 heartbeat) {
  UINT16 sequence = (UINT16)(heartbeat & 0xffffu);

  if (sequence == ER_BLE_ADV_SEQUENCE_INVALID) {
    return 1u;
  }
  return sequence;
}

static void er_pi_zero_w_v1_1_send_ble_advertisement(UINT32 heartbeat) {
  ErBleWifiRoleAdvert advert;
  ErBleAdvPacket packet;
  UINT8 ble_payload[ER_BLE_ADV_PAYLOAD_BYTES];
  UINT8 adv_data[ER_BLE_ADV_DATA_BYTES];
  UINT8 adv_len;
  UINT16 sequence = er_pi_zero_w_v1_1_ble_sequence(heartbeat);

  if (er_ble_wifi_role_advert_prepare(er_pi_zero_w_v1_1_ble_capabilities(),
                                      ER_BLE_WIFI_ROLE_NONE,
                                      ER_PI_ZERO_W_V1_1_BLE_WIFI_PRIORITY,
                                      ER_PI_ZERO_W_V1_1_L2_WIFI_CHANNEL,
                                      ER_PI_ZERO_W_V1_1_BLE_WIFI_GROUP_ID,
                                      er_pi_zero_w_v1_1_node_nonce(),
                                      &advert) == 0u ||
      er_ble_wifi_role_encode_payload(&advert, ble_payload) == 0u ||
      er_ble_adv_prepare_packet(ER_BLE_ADV_CHANNEL_ID,
                                sequence,
                                ER_PI_ZERO_W_V1_1_BLE_ADV_FRAGMENT_INDEX,
                                ER_PI_ZERO_W_V1_1_BLE_ADV_FRAGMENT_COUNT,
                                ble_payload,
                                ER_BLE_ADV_PAYLOAD_BYTES,
                                &packet) == 0u ||
      er_ble_adv_encode_data(&packet, adv_data, &adv_len) == 0u) {
    return;
  }
  er_pi_zero_w_v1_1_send_erwire(
      ER_PI_ZERO_W_V1_1_ERWIRE_KIND_BLE_ADVERTISEMENT,
      (UINT32)sequence,
      adv_data,
      adv_len);
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
  er_pi_zero_w_v1_1_put_update_state(&cursor);
  er_pi_zero_w_v1_1_send_erwire(ER_PI_ZERO_W_V1_1_ERWIRE_KIND_NODE_HEARTBEAT,
                                heartbeat + 1u,
                                payload,
                                ER_PI_ZERO_W_V1_1_NODE_HEARTBEAT_BYTES);
}

static UINT8 er_pi_zero_w_v1_1_update_reboot_ready(void) {
  if (g_er_pi_zero_w_v1_1_ota_state.reboot_required != 0u &&
      g_er_pi_zero_w_v1_1_storage_probe_state ==
          ER_PI_ZERO_W_V1_1_STORAGE_WRITE_VERIFIED) {
    return 1u;
  }
  return 0u;
}

static void er_pi_zero_w_v1_1_lcd_debug_status(UINT32 heartbeat) {
  ErPiZeroWV11DebugStatus status;

  status.heartbeat = heartbeat;
  status.sdio_state = (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state;
  status.storage_state = (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state;
  status.wifi_state = (UINT32)g_er_pi_zero_w_v1_1_wifi_control_state;
  status.ota_status = (UINT32)g_er_pi_zero_w_v1_1_ota_status;
  status.ota_offset = (UINT32)g_er_pi_zero_w_v1_1_ota_offset;
  status.l2_ready = g_er_pi_zero_w_v1_1_sdio_probe_state ==
                   ER_PI_ZERO_W_V1_1_L2_READY;
  status.input_state = er_pi_zero_w_v1_1_lcd_hat_input_state();
  er_pi_zero_w_v1_1_lcd_hat_status(&status);
}

void er_pi_zero_w_v1_1_main(void) {
  UINT32 heartbeat = 0u;

  er_pi_zero_w_v1_1_boot_log_init(&g_er_pi_zero_w_v1_1_boot_log,
                                  ER_PI_ZERO_W_V1_1_BOOT_MAGIC);
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_BOOT_ENTRY,
      (UINT32)g_er_pi_zero_w_v1_1_boot_magic,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state,
      (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state,
      (UINT32)g_er_pi_zero_w_v1_1_wifi_control_state);
  er_pi_zero_w_v1_1_act_led_init();
  er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_BOOT_ENTRY);
  er_pi_zero_w_v1_1_uart_init();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_UART_READY,
      0u,
      0u,
      0u,
      0u);
  er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_UART_READY);
  er_pi_zero_w_v1_1_lcd_hat_init();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_LCD_INIT,
      0u,
      0u,
      0u,
      0u);
  er_pi_zero_w_v1_1_lcd_debug_status(heartbeat);
  if (er_pi_zero_w_v1_1_init_ephemeral_identity() == 0u) {
    (void)er_pi_zero_w_v1_1_boot_log_append(
        &g_er_pi_zero_w_v1_1_boot_log,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_IDENTITY_FAILED,
        0u,
        0u,
        0u,
        0u);
    er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_FAIL);
    for (;;) {
      g_er_pi_zero_w_v1_1_boot_magic = ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
    }
  }
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_IDENTITY_READY,
      (UINT32)g_er_pi_zero_w_v1_1_node_id[0],
      (UINT32)g_er_pi_zero_w_v1_1_node_id[1],
      (UINT32)g_er_pi_zero_w_v1_1_node_id[2],
      (UINT32)g_er_pi_zero_w_v1_1_node_id[3]);
  er_pi_zero_w_v1_1_ota_listen_init();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_OTA_LISTEN,
      (UINT32)g_er_pi_zero_w_v1_1_ota_status,
      (UINT32)g_er_pi_zero_w_v1_1_ota_target_block,
      ER_PI_ZERO_W_V1_1_OTA_BLOCK_BYTES,
      ER_PI_ZERO_W_V1_1_OTA_PACKET_CAPACITY);
  if (er_pi_zero_w_v1_1_storage_ready() != 0u &&
      er_pi_zero_w_v1_1_boot_log_enable_storage(
          &g_er_pi_zero_w_v1_1_boot_log,
          er_pi_zero_w_v1_1_boot_log_write_block,
          0) != 0u) {
    (void)er_pi_zero_w_v1_1_boot_log_append(
        &g_er_pi_zero_w_v1_1_boot_log,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_STORAGE_READY,
        (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state,
        (UINT32)g_er_pi_zero_w_v1_1_storage_relative_card_address,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_START_BLOCK,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_BLOCK_COUNT);
  } else {
    (void)er_pi_zero_w_v1_1_boot_log_append(
        &g_er_pi_zero_w_v1_1_boot_log,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_STORAGE_FAILED,
        (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state,
        (UINT32)g_er_pi_zero_w_v1_1_storage_relative_card_address,
        (UINT32)g_er_pi_zero_w_v1_1_storage_last_block,
        (UINT32)g_er_pi_zero_w_v1_1_storage_last_response);
  }
  er_pi_zero_w_v1_1_lcd_debug_status(heartbeat);
  er_pi_zero_w_v1_1_wifi_gpio_init();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_WIFI_POWERED,
      (UINT32)g_er_pi_zero_w_v1_1_wifi_control_state,
      0u,
      0u,
      0u);
  er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_WIFI_POWERED);
  er_pi_zero_w_v1_1_sdio_probe();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_SDIO_PROBED,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_interrupt,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_response,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_relative_card_address);
  if (g_er_pi_zero_w_v1_1_sdio_probe_state ==
          ER_PI_ZERO_W_V1_1_SDIO_PROBE_CMD53_DONE &&
      er_pi_zero_w_v1_1_cyw43438_start_owned_l2() != 0u) {
    g_er_pi_zero_w_v1_1_sdio_probe_state = ER_PI_ZERO_W_V1_1_L2_READY;
    er_pi_zero_w_v1_1_ota_status_refresh();
    (void)er_pi_zero_w_v1_1_boot_log_append(
        &g_er_pi_zero_w_v1_1_boot_log,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_READY,
        (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state,
        (UINT32)g_er_pi_zero_w_v1_1_wifi_control_state,
        (UINT32)g_er_pi_zero_w_v1_1_ota_status,
        (UINT32)g_er_pi_zero_w_v1_1_ota_offset);
    er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_OK);
  } else {
    (void)er_pi_zero_w_v1_1_boot_log_append(
        &g_er_pi_zero_w_v1_1_boot_log,
        ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_L2_FAILED,
        (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state,
        (UINT32)g_er_pi_zero_w_v1_1_wifi_control_state,
        (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_interrupt,
        (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_response);
    er_pi_zero_w_v1_1_act_led_status(ER_PI_ZERO_W_V1_1_LED_CYW_MAILBOX_FAIL);
  }
  er_pi_zero_w_v1_1_lcd_debug_status(heartbeat);
  er_pi_zero_w_v1_1_send_node_available();
  (void)er_pi_zero_w_v1_1_boot_log_append(
      &g_er_pi_zero_w_v1_1_boot_log,
      ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_NODE_AVAILABLE_SENT,
      (UINT32)g_er_pi_zero_w_v1_1_sdio_probe_state,
      (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state,
      (UINT32)g_er_pi_zero_w_v1_1_ota_status,
      (UINT32)g_er_pi_zero_w_v1_1_ota_offset);
  er_pi_zero_w_v1_1_send_ble_advertisement(1u);

  for (;;) {
    g_er_pi_zero_w_v1_1_boot_magic = ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
    er_pi_zero_w_v1_1_ota_poll_uart_rx();
    er_pi_zero_w_v1_1_ota_poll_owned_rx();
    er_pi_zero_w_v1_1_send_ble_advertisement(heartbeat + 1u);
    er_pi_zero_w_v1_1_send_node_heartbeat(heartbeat);
    er_pi_zero_w_v1_1_lcd_debug_status(heartbeat);
    if (er_pi_zero_w_v1_1_update_reboot_ready() != 0u) {
      (void)er_pi_zero_w_v1_1_boot_log_append(
          &g_er_pi_zero_w_v1_1_boot_log,
          ER_PI_ZERO_W_V1_1_BOOT_LOG_EVENT_REBOOT_READY,
          (UINT32)g_er_pi_zero_w_v1_1_ota_status,
          (UINT32)g_er_pi_zero_w_v1_1_ota_offset,
          (UINT32)g_er_pi_zero_w_v1_1_storage_probe_state,
          (UINT32)g_er_pi_zero_w_v1_1_storage_last_block);
      er_pi_zero_w_v1_1_reboot();
    }
    heartbeat += 1u;
    er_pi_zero_w_v1_1_delay(
        ER_PI_ZERO_W_V1_1_UART_HEARTBEAT_DELAY_TICKS);
  }
}
