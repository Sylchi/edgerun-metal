#ifndef ER_PI_ZERO2W_H
#define ER_PI_ZERO2W_H

/*
 * Purpose: own Raspberry Pi Zero 2 W board bring-up constants and probes.
 * Intention: make Pi radio/storage state explicit before packets depend on it.
 */

#include "er_boot_services.h"
#include "er_mmio.h"
#include "er_pi_mmc.h"

#define ER_PI_ZERO2W_PERIPHERAL_BASE 0x3f000000ull
#define ER_PI_ZERO2W_PERIPHERAL_BYTES 0x01000000ull
#define ER_PI_ZERO_W_V1_1_PERIPHERAL_BASE 0x20000000ull
#define ER_PI_ZERO_W_V1_1_PERIPHERAL_BYTES 0x01000000ull
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
#define ER_PI_ZERO_W_V1_1_WIFI_DEFAULT_CHANNEL 6u

#define ER_PI_MAILBOX_CHANNEL_PROPERTY 8u
#define ER_PI_MAILBOX_REQUEST_CODE 0u
#define ER_PI_MAILBOX_TAG_GET_BOARD_MODEL 0x00010001u
#define ER_PI_MAILBOX_TAG_GET_ARM_MEMORY 0x00010005u
#define ER_PI_MAILBOX_TAG_GET_CLOCK_RATE 0x00030002u
#define ER_PI_MAILBOX_TAG_SET_CLOCK_RATE 0x00038002u
#define ER_PI_MAILBOX_TAG_LAST 0u

#define ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY 8u
#define ER_PI_ZERO2W_SD_MEMORY_BRINGUP_COMMAND_CAPACITY 8u

typedef struct {
  UINT64 peripheral_base;
  UINT64 peripheral_bytes;
  UINT64 mailbox_offset;
  UINT64 mailbox_bytes;
  UINT64 gpio_offset;
  UINT64 gpio_bytes;
  UINT64 sdhost_offset;
  UINT64 sdhost_bytes;
  UINT64 emmc_offset;
  UINT64 emmc_bytes;
  UINT64 aux_offset;
  UINT64 aux_bytes;
  UINT8 wifi_kind;
  UINT8 bluetooth_kind;
  UINT8 wifi_default_channel;
} ErPiBoardProfile;

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
  UINT32 command_count;
  ErPiMmcCommand commands[ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY];
} ErPiZero2wSdioBringupPlan;

typedef struct {
  UINT32 command_count;
  ErPiMmcCommand commands[ER_PI_ZERO2W_SD_MEMORY_BRINGUP_COMMAND_CAPACITY];
} ErPiZero2wSdMemoryBringupPlan;

typedef struct {
  UINT32 command_count;
  UINT32 completed_count;
  UINT32 relative_card_address;
  UINT32 responses[ER_PI_ZERO2W_SDIO_BRINGUP_COMMAND_CAPACITY];
  UINT32 last_interrupt_value;
  UINT8 completed;
  UINT8 error;
} ErPiZero2wSdioBringupState;

typedef struct {
  UINT32 command_count;
  UINT32 completed_count;
  UINT32 relative_card_address;
  UINT32 operating_conditions;
  UINT32 responses[ER_PI_ZERO2W_SD_MEMORY_BRINGUP_COMMAND_CAPACITY];
  UINT32 last_interrupt_value;
  UINT8 completed;
  UINT8 error;
} ErPiZero2wSdMemoryBringupState;

UINT8 er_pi_zero2w_mmio_map(ErPiZero2wMmio* out_mmio);
UINT64 er_pi_zero2w_peripheral_phys(UINT64 offset);
const ErPiBoardProfile* er_pi_zero2w_profile(void);
const ErPiBoardProfile* er_pi_zero_w_v1_1_profile(void);
UINT64 er_pi_board_peripheral_phys(const ErPiBoardProfile* profile,
                                   UINT64 offset);
UINT8 er_pi_board_mmio_map(const ErPiBoardProfile* profile,
                           ErPiZero2wMmio* out_mmio);
UINT8 er_pi_mailbox_two_value_request(UINT32 tag_id,
                                      UINT32 value0,
                                      UINT32 value1,
                                      ErPiMailboxTwoValueMessage* out_message);
UINT8 er_pi_zero2w_sd_memory_identity_plan(
    ErPiZero2wSdMemoryBringupPlan* out_plan);
UINT8 er_pi_zero2w_sd_memory_claim_plan(
    UINT32 relative_card_address,
    ErPiZero2wSdMemoryBringupPlan* out_plan);
UINT8 er_pi_zero2w_sd_memory_execute_plan(
    INT64 emmc_handle,
    const ErPiZero2wSdMemoryBringupPlan* plan,
    UINT32 poll_budget_per_command,
    ErPiZero2wSdMemoryBringupState* out_state);
UINT8 er_pi_zero2w_sdio_identity_plan(ErPiZero2wSdioBringupPlan* out_plan);
UINT8 er_pi_zero2w_sdio_claim_plan(UINT32 relative_card_address,
                                   ErPiZero2wSdioBringupPlan* out_plan);
UINT8 er_pi_zero2w_sdio_execute_plan(
    INT64 emmc_handle,
    const ErPiZero2wSdioBringupPlan* plan,
    UINT32 poll_budget_per_command,
    ErPiZero2wSdioBringupState* out_state);
UINT8 er_pi_board_apply_boot_report(const ErPiBoardProfile* profile,
                                    ErBootServicesReport* report);
UINT8 er_pi_zero2w_apply_boot_report(ErBootServicesReport* report);
UINT8 er_pi_zero_w_v1_1_apply_boot_report(ErBootServicesReport* report);

#endif
