#ifndef ER_WIFI_BURST_H
#define ER_WIFI_BURST_H

/*
 * Purpose: derive short-lived Wi-Fi link intent from BLE role advertisements.
 * Intention: keep BLE as the always-on presence plane and Wi-Fi as an explicit burst data plane.
 */

#include "er_ble_adv.h"

#define ER_WIFI_BURST_SSID_BYTES 16u

typedef struct {
  UINT8 open;
  UINT8 wifi_channel;
  UINT32 group_id;
  UINT64 session_id;
  ErBleWifiRole local_role;
  UINT8 ssid_len;
  UINT8 ssid[ER_WIFI_BURST_SSID_BYTES];
} ErWifiBurstPlan;

UINT8 er_wifi_burst_plan_prepare(const ErBleWifiRoleAdvert* local,
                                 const ErBleWifiRoleAdvert* remote,
                                 ErWifiBurstPlan* out_plan);

#endif
