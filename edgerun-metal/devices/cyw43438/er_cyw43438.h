#ifndef ER_CYW43438_H
#define ER_CYW43438_H

/*
 * Purpose: bind Pi CYW43438 SDIO discovery to owned 802.11 AP frame templates.
 * Intention: make the firmware/register executor boundary explicit without
 * inventing hidden chipset state.
 */

#include "er_ieee80211_ap.h"
#include "er_firmware_loader.h"
#include "er_pi_zero2w.h"

#define ER_CYW43438_ABI_VERSION 1u
#define ER_CYW43438_SDIO_VENDOR_BROADCOM 0x02d0u
#define ER_CYW43438_SDIO_DEVICE_BCM43430 0xa9a6u
#define ER_CYW43438_FIRMWARE_INSTANCE_RAM 0u
#define ER_CYW43438_FIRMWARE_INSTANCE_NVRAM 1u
#define ER_CYW43438_FIRMWARE_INSTANCE_CLM_BLOB 2u
#define ER_CYW43438_FIRMWARE_SOURCE_COUNT 3u
#define ER_CYW43438_AP_TEMPLATE_COUNT 2u
#define ER_CYW43438_AP_STAGE_COUNT 4u
#define ER_CYW43438_AP_BLOCKED_NONE 0u
#define ER_CYW43438_AP_BLOCKED_NO_RCA 1u
#define ER_CYW43438_AP_BLOCKED_NO_FIRMWARE 2u
#define ER_CYW43438_AP_BLOCKED_NO_FIRMWARE_REGISTER_EXECUTOR 4u
#define ER_CYW43438_SDIO_FUNCTION_CCCR 0u
#define ER_CYW43438_SDIO_FUNCTION_BACKPLANE 1u
#define ER_CYW43438_SDIO_FUNCTION_WLAN 2u
#define ER_CYW43438_REGISTER_OP_CAPACITY 5u

typedef enum {
  ER_CYW43438_REGISTER_OP_WRITE8 = 1,
  ER_CYW43438_REGISTER_OP_READ8_EXPECT = 2,
  ER_CYW43438_REGISTER_OP_WRITE_TEMPLATE = 3
} ErCyw43438RegisterOpKind;

typedef enum {
  ER_CYW43438_AP_STAGE_SDIO_IDENTITY = 1,
  ER_CYW43438_AP_STAGE_SDIO_CLAIM = 2,
  ER_CYW43438_AP_STAGE_INSTALL_BEACON_TEMPLATE = 3,
  ER_CYW43438_AP_STAGE_INSTALL_PROBE_RESPONSE_TEMPLATE = 4
} ErCyw43438ApStageKind;

typedef enum {
  ER_CYW43438_AP_TEMPLATE_BEACON = 1,
  ER_CYW43438_AP_TEMPLATE_PROBE_RESPONSE = 2
} ErCyw43438ApTemplateKind;

typedef struct {
  UINT16 abi_version;
  UINT16 kind;
  UINT32 frame_len;
  UINT8 frame[ER_IEEE80211_AP_FRAME_MAX];
} ErCyw43438ApTemplate;

typedef struct {
  UINT16 abi_version;
  UINT16 kind;
  UINT8 function;
  UINT8 template_kind;
  UINT16 reserved;
  UINT32 address;
  UINT32 value;
  UINT32 value_mask;
  UINT32 bytes_len;
} ErCyw43438RegisterOp;

typedef struct {
  UINT16 abi_version;
  UINT16 op_count;
  ErCyw43438RegisterOp ops[ER_CYW43438_REGISTER_OP_CAPACITY];
} ErCyw43438RegisterExecutorPlan;

typedef struct {
  UINT16 abi_version;
  UINT16 completed_ops;
  UINT16 failed_op;
  UINT16 reserved;
  UINT32 last_response0;
  UINT32 last_interrupt_value;
  UINT8 completed;
} ErCyw43438RegisterExecutorResult;

typedef struct {
  UINT16 abi_version;
  UINT16 kind;
  UINT32 blocked_reason;
  ErPiZero2wSdioBringupPlan sdio_plan;
  ErCyw43438ApTemplate ap_template;
} ErCyw43438ApStage;

typedef struct {
  UINT16 abi_version;
  UINT16 stage_count;
  UINT32 blocked_reason;
  ErIeee80211OpenApConfig ap_config;
  ErCyw43438ApStage stages[ER_CYW43438_AP_STAGE_COUNT];
} ErCyw43438ApPath;

typedef struct {
  ErFirmwareImage ram;
  ErFirmwareImage nvram;
  ErFirmwareImage clm_blob;
} ErCyw43438FirmwareSet;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErCyw43438FirmwareSet firmware;
  ErCyw43438ApPath ap_path;
  ErCyw43438RegisterExecutorPlan register_executor;
} ErCyw43438OpenApBootDevice;

typedef struct {
  UINT16 abi_version;
  UINT8 function;
  UINT8 value;
  UINT32 address;
  UINT32 response0;
  UINT32 interrupt_value;
} ErCyw43438SdioDirectResult;

typedef struct {
  UINT16 abi_version;
  UINT8 function;
  UINT8 incrementing_address;
  UINT32 address;
  UINT32 bytes_len;
  UINT32 response0;
  UINT32 interrupt_value;
} ErCyw43438SdioTransferResult;

void er_cyw43438_clear_firmware_set(ErCyw43438FirmwareSet* firmware);
void er_cyw43438_clear_open_ap_boot_device(
    ErCyw43438OpenApBootDevice* device);
UINT8 er_cyw43438_sdio_function_valid(UINT8 function);
UINT8 er_cyw43438_sdio_read8(INT64 emmc_handle,
                             UINT8 function,
                             UINT32 address,
                             UINT32 poll_budget,
                             ErCyw43438SdioDirectResult* out_result);
UINT8 er_cyw43438_sdio_write8(INT64 emmc_handle,
                              UINT8 function,
                              UINT32 address,
                              UINT8 value,
                              UINT32 poll_budget,
                              ErCyw43438SdioDirectResult* out_result);
UINT8 er_cyw43438_sdio_read_bytes(
    INT64 emmc_handle,
    UINT8 function,
    UINT8 incrementing_address,
    UINT32 address,
    UINT8* out_bytes,
    UINT32 bytes_len,
    UINT32 poll_budget,
    ErCyw43438SdioTransferResult* out_result);
UINT8 er_cyw43438_sdio_write_bytes(
    INT64 emmc_handle,
    UINT8 function,
    UINT8 incrementing_address,
    UINT32 address,
    const UINT8* bytes,
    UINT32 bytes_len,
    UINT32 poll_budget,
    ErCyw43438SdioTransferResult* out_result);
UINT8 er_cyw43438_add_pi_zero_w_firmware_sources(ErBootConfig* config);
UINT8 er_cyw43438_load_pi_zero_w_firmware(
    const ErCryptoProvider* crypto,
    const ErBootConfig* config,
    ErFirmwareReadFn read_fn,
    void* read_ctx,
    UINT8* ram_bytes,
    UINTN ram_capacity,
    UINT8* nvram_bytes,
    UINTN nvram_capacity,
    UINT8* clm_blob_bytes,
    UINTN clm_blob_capacity,
    ErCyw43438FirmwareSet* out_firmware);
UINT8 er_cyw43438_prepare_open_l2_ap_boot_device(
    const ErCryptoProvider* crypto,
    const ErBootConfig* config,
    ErFirmwareReadFn read_fn,
    void* read_ctx,
    UINT8* ram_bytes,
    UINTN ram_capacity,
    UINT8* nvram_bytes,
    UINTN nvram_capacity,
    UINT8* clm_blob_bytes,
    UINTN clm_blob_capacity,
    const ErWifiL2ApPlan* ap_plan,
    UINT32 relative_card_address,
    const UINT8 probe_station_mac[ER_NET_MAC_LEN],
    ErCyw43438OpenApBootDevice* out_device);
UINT8 er_cyw43438_prepare_open_l2_ap_path(
    const ErWifiL2ApPlan* ap_plan,
    UINT32 relative_card_address,
    const UINT8 probe_station_mac[ER_NET_MAC_LEN],
    ErCyw43438ApPath* out_path);
UINT8 er_cyw43438_prepare_register_executor_plan(
    const ErCyw43438ApPath* path,
    ErCyw43438RegisterExecutorPlan* out_plan);
UINT8 er_cyw43438_execute_register_executor_plan(
    INT64 emmc_handle,
    const ErCyw43438ApPath* path,
    const ErCyw43438RegisterExecutorPlan* plan,
    UINT32 poll_budget,
    ErCyw43438RegisterExecutorResult* out_result);

#endif
