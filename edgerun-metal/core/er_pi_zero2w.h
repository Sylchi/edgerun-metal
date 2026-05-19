#ifndef ER_PI_ZERO2W_H
#define ER_PI_ZERO2W_H

/*
 * Purpose: own Raspberry Pi Zero 2 W board bring-up constants and probes.
 * Intention: make Pi radio/storage state explicit before packets depend on it.
 */

#include "er_boot_services.h"
#include "er_mmio.h"

#define ER_PI_ZERO2W_PERIPHERAL_BASE 0x3f000000ull
#define ER_PI_ZERO2W_PERIPHERAL_BYTES 0x01000000ull
#define ER_PI_ZERO2W_MAILBOX_OFFSET 0x0000b880ull
#define ER_PI_ZERO2W_MAILBOX_BYTES 0x00000024ull
#define ER_PI_ZERO2W_GPIO_OFFSET 0x00200000ull
#define ER_PI_ZERO2W_GPIO_BYTES 0x000000b4ull
#define ER_PI_ZERO2W_SDHOST_OFFSET 0x00202000ull
#define ER_PI_ZERO2W_SDHOST_BYTES 0x00000100ull
#define ER_PI_ZERO2W_EMMC_OFFSET 0x00300000ull
#define ER_PI_ZERO2W_EMMC_BYTES 0x00000100ull
#define ER_PI_ZERO2W_AUX_OFFSET 0x00215000ull
#define ER_PI_ZERO2W_AUX_BYTES 0x00000100ull

#define ER_PI_ZERO2W_WIFI_SDIO_GPIO_FIRST 34u
#define ER_PI_ZERO2W_WIFI_SDIO_GPIO_LAST 39u
#define ER_PI_ZERO2W_BLUETOOTH_UART_TX_GPIO 32u
#define ER_PI_ZERO2W_BLUETOOTH_UART_RX_GPIO 33u
#define ER_PI_ZERO2W_WIFI_DEFAULT_CHANNEL 6u

#define ER_PI_MAILBOX_CHANNEL_PROPERTY 8u
#define ER_PI_MAILBOX_REQUEST_CODE 0u
#define ER_PI_MAILBOX_TAG_GET_BOARD_MODEL 0x00010001u
#define ER_PI_MAILBOX_TAG_GET_ARM_MEMORY 0x00010005u
#define ER_PI_MAILBOX_TAG_GET_CLOCK_RATE 0x00030002u
#define ER_PI_MAILBOX_TAG_SET_CLOCK_RATE 0x00038002u
#define ER_PI_MAILBOX_TAG_LAST 0u

#define ER_PI_CLOCK_ID_EMMC 1u
#define ER_PI_CLOCK_ID_UART 2u

#define ER_PI_MMC_CMD_GO_IDLE_STATE 0u
#define ER_PI_MMC_CMD_SEND_RELATIVE_ADDR 3u
#define ER_PI_MMC_CMD_IO_SEND_OP_COND 5u
#define ER_PI_MMC_CMD_SELECT_CARD 7u
#define ER_PI_MMC_CMD_IO_RW_DIRECT 52u
#define ER_PI_MMC_CMD_IO_RW_EXTENDED 53u

#define ER_PI_MMC_RESPONSE_NONE 0u
#define ER_PI_MMC_RESPONSE_R1 1u
#define ER_PI_MMC_RESPONSE_R4 4u
#define ER_PI_MMC_RESPONSE_R5 5u
#define ER_PI_MMC_RESPONSE_R6 6u

#define ER_PI_SDIO_FUNCTION_BACKPLANE 1u
#define ER_PI_SDIO_FUNCTION_WLAN 2u

#define ER_PI_SDIO_READ 0u
#define ER_PI_SDIO_WRITE 1u
#define ER_PI_SDIO_CMD52_READ ER_PI_SDIO_READ
#define ER_PI_SDIO_CMD52_WRITE ER_PI_SDIO_WRITE
#define ER_PI_SDIO_CMD52_NO_RAW 0u
#define ER_PI_SDIO_CMD52_RAW 1u

#define ER_PI_SDIO_CMD53_FIXED_ADDRESS 0u
#define ER_PI_SDIO_CMD53_INCREMENTING_ADDRESS 1u
#define ER_PI_SDIO_CMD53_BYTE_MODE 0u
#define ER_PI_SDIO_CMD53_BLOCK_MODE 1u

#define ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY 8u

typedef struct {
  UINT8 mapped;
  INT64 peripheral_handle;
  INT64 mailbox_handle;
  INT64 gpio_handle;
  INT64 sdhost_handle;
  INT64 emmc_handle;
  INT64 aux_handle;
} ErPiZero2wMmio;

typedef struct {
  UINT32 size_bytes;
  UINT32 request_code;
  UINT32 tag_id;
  UINT32 value_buffer_bytes;
  UINT32 request_value_bytes;
  UINT32 value0;
  UINT32 value1;
  UINT32 end_tag;
} ErPiMailboxTwoValueMessage;

typedef struct {
  UINT32 command_index;
  UINT32 argument;
  UINT32 response_kind;
} ErPiMmcCommand;

typedef struct {
  UINT32 command_count;
  ErPiMmcCommand commands[ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY];
} ErPiZero2wSdioBringupPlan;

UINT8 er_pi_zero2w_mmio_map(ErPiZero2wMmio* out_mmio);
UINT64 er_pi_zero2w_peripheral_phys(UINT64 offset);
UINT8 er_pi_mailbox_two_value_request(UINT32 tag_id,
                                      UINT32 value0,
                                      UINT32 value1,
                                      ErPiMailboxTwoValueMessage* out_message);
UINT32 er_pi_sdio_cmd52_argument(UINT8 write,
                                 UINT8 function,
                                 UINT8 raw,
                                 UINT32 address,
                                 UINT8 data);
UINT32 er_pi_sdio_cmd53_argument(UINT8 write,
                                 UINT8 function,
                                 UINT8 block_mode,
                                 UINT8 incrementing_address,
                                 UINT32 address,
                                 UINT32 count);
UINT32 er_pi_mmc_relative_card_argument(UINT32 relative_card_address);
UINT8 er_pi_mmc_command_prepare(UINT32 command_index,
                                UINT32 argument,
                                UINT32 response_kind,
                                ErPiMmcCommand* out_command);
UINT8 er_pi_zero2w_sdio_identity_plan(ErPiZero2wSdioBringupPlan* out_plan);
UINT8 er_pi_zero2w_sdio_claim_plan(UINT32 relative_card_address,
                                   ErPiZero2wSdioBringupPlan* out_plan);
UINT8 er_pi_zero2w_apply_boot_report(ErBootServicesReport* report);

#endif
