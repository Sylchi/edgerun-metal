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

UINT8 er_pi_zero2w_mmio_map(ErPiZero2wMmio* out_mmio);
UINT64 er_pi_zero2w_peripheral_phys(UINT64 offset);
UINT8 er_pi_mailbox_two_value_request(UINT32 tag_id,
                                      UINT32 value0,
                                      UINT32 value1,
                                      ErPiMailboxTwoValueMessage* out_message);
UINT8 er_pi_zero2w_apply_boot_report(ErBootServicesReport* report);

#endif
