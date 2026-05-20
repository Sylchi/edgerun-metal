#ifndef ER_CYW43438_H
#define ER_CYW43438_H

/*
 * Purpose: bind Pi CYW43438 SDIO discovery to owned 802.11 AP frame templates.
 * Intention: make the firmware/register executor boundary explicit without
 * inventing hidden chipset state.
 */

#include "er_ieee80211_ap.h"
#include "er_pi_zero2w.h"

#define ER_CYW43438_ABI_VERSION 1u
#define ER_CYW43438_AP_TEMPLATE_COUNT 2u
#define ER_CYW43438_AP_STAGE_COUNT 4u
#define ER_CYW43438_AP_BLOCKED_NONE 0u
#define ER_CYW43438_AP_BLOCKED_NO_RCA 1u
#define ER_CYW43438_AP_BLOCKED_NO_FIRMWARE_REGISTER_EXECUTOR 2u

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

UINT8 er_cyw43438_prepare_open_l2_ap_path(
    const ErWifiL2ApPlan* ap_plan,
    UINT32 relative_card_address,
    const UINT8 probe_station_mac[ER_NET_MAC_LEN],
    ErCyw43438ApPath* out_path);

#endif
