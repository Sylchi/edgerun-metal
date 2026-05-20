#ifndef ER_IEEE80211_AP_H
#define ER_IEEE80211_AP_H

/*
 * Purpose: serialize open 802.11 management frames for the Wi-Fi L2 relay.
 * Intention: keep AP identity derived from ErWifiL2ApPlan and independent of
 * chipset firmware command formats.
 */

#include "er_wifi_l2.h"

#define ER_IEEE80211_AP_ABI_VERSION 1u
#define ER_IEEE80211_AP_MANAGEMENT_HEADER_LEN 24u
#define ER_IEEE80211_AP_BEACON_FIXED_LEN 12u
#define ER_IEEE80211_AP_SUPPORTED_RATE_COUNT 4u
#define ER_IEEE80211_AP_BEACON_INTERVAL_TU 100u
#define ER_IEEE80211_AP_FRAME_MAX 128u

typedef struct {
  UINT16 abi_version;
  UINT16 beacon_interval_tu;
  UINT8 bssid[ER_NET_MAC_LEN];
  UINT8 ssid[ER_WIFI_L2_NODE_SSID_CAP];
  UINT8 ssid_len;
  UINT8 channel;
  UINT8 reserved[2];
} ErIeee80211OpenApConfig;

UINT8 er_ieee80211_open_ap_config_from_l2_plan(
    const ErWifiL2ApPlan* plan,
    ErIeee80211OpenApConfig* out_config);
UINT8 er_ieee80211_open_ap_build_beacon(
    const ErIeee80211OpenApConfig* config,
    UINT16 sequence,
    UINT8* out_frame,
    UINT32 out_capacity,
    UINT32* out_frame_len);
UINT8 er_ieee80211_open_ap_build_probe_response(
    const ErIeee80211OpenApConfig* config,
    const UINT8 station_mac[ER_NET_MAC_LEN],
    UINT16 sequence,
    UINT8* out_frame,
    UINT32 out_capacity,
    UINT32* out_frame_len);
UINT8 er_ieee80211_open_ap_probe_request_matches(
    const ErIeee80211OpenApConfig* config,
    const UINT8* frame,
    UINT32 frame_len);

#endif
