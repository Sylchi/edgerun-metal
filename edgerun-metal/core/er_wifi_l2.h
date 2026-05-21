#ifndef ER_WIFI_L2_H
#define ER_WIFI_L2_H

/*
 * Purpose: define Wi-Fi as a raw L2 EdgeRun frame carrier.
 * Intention: keep Pi AP identity tied to node id without TCP/IP assumptions.
 */

#include "er_net_frame.h"
#include "er_work.h"

#define ER_WIFI_L2_ABI_VERSION 1u
#define ER_WIFI_L2_NODE_SSID_LEN 19u
#define ER_WIFI_L2_NODE_SSID_CAP 32u
#define ER_WIFI_L2_CONTROL_SSID_LEN 7u
#define ER_WIFI_L2_CONTROL_CHANNEL 1u
#define ER_WIFI_L2_ENDPOINT_ADDR_FIXED_LEN 10u
#define ER_WIFI_L2_ENDPOINT_ADDR_MAC_OFFSET 0u
#define ER_WIFI_L2_ENDPOINT_ADDR_ETH_TYPE_OFFSET 6u
#define ER_WIFI_L2_ENDPOINT_ADDR_CHANNEL_OFFSET 8u
#define ER_WIFI_L2_ENDPOINT_ADDR_SSID_LEN_OFFSET 9u
#define ER_WIFI_L2_ENDPOINT_ADDR_SSID_OFFSET 10u

typedef struct {
  UINT16 abi_version;
  UINT8 channel;
  UINT8 ssid_len;
  UINT16 eth_type;
  UINT8 reserved[2];
  UINT8 mac[ER_NET_MAC_LEN];
  UINT8 ssid[ER_WIFI_L2_NODE_SSID_CAP];
} ErWifiL2ApPlan;

UINT8 er_wifi_l2_node_mac(const ErNodeId* node_id,
                          UINT8 out_mac[ER_NET_MAC_LEN]);
UINT8 er_wifi_l2_node_ssid(const ErNodeId* node_id,
                           UINT8* out_ssid,
                           UINT8 out_capacity,
                           UINT8* out_ssid_len);
UINT8 er_wifi_l2_ap_plan_prepare(const ErNodeId* node_id,
                                 UINT8 channel,
                                 ErWifiL2ApPlan* out_plan);
UINT8 er_wifi_l2_control_plan_prepare(const ErNodeId* node_id,
                                      ErWifiL2ApPlan* out_plan);
UINT8 er_wifi_l2_ap_plan_valid(const ErWifiL2ApPlan* plan);
UINT8 er_wifi_l2_control_ssid(UINT8* out_ssid,
                              UINT8 out_capacity,
                              UINT8* out_ssid_len);
UINT8 er_wifi_l2_prepare_channel_endpoint(const ErHash* channel_id,
                                          const ErWifiL2ApPlan* plan,
                                          const char* label,
                                          UINTN label_len,
                                          ErChannelEndpoint* out_endpoint);
UINT8 er_wifi_l2_channel_endpoint_valid(const ErChannelEndpoint* endpoint);

#endif
