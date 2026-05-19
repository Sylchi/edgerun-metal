#include "er_wifi_burst.h"
#include "er_mem.h"

enum {
  ER_WIFI_BURST_BYTE_MASK = 0xffu,
  ER_WIFI_BURST_BYTE_BITS = 8u,
  ER_WIFI_BURST_U32_BYTE0_OFFSET = 0u,
  ER_WIFI_BURST_U32_BYTE1_OFFSET = 1u,
  ER_WIFI_BURST_U32_BYTE2_OFFSET = 2u,
  ER_WIFI_BURST_U32_BYTE3_OFFSET = 3u,
  ER_WIFI_BURST_U64_LO_U32_OFFSET = 0u,
  ER_WIFI_BURST_U64_HI_U32_OFFSET = 4u,
  ER_WIFI_BURST_SSID_MAGIC_E_OFFSET = 0u,
  ER_WIFI_BURST_SSID_MAGIC_R_OFFSET = 1u,
  ER_WIFI_BURST_SSID_MAGIC_W_OFFSET = 2u,
  ER_WIFI_BURST_SSID_MAGIC_B_OFFSET = 3u,
  ER_WIFI_BURST_SSID_GROUP_OFFSET = 4u,
  ER_WIFI_BURST_SSID_SESSION_OFFSET = 8u,
  ER_WIFI_BURST_MAGIC_E = 'E',
  ER_WIFI_BURST_MAGIC_R = 'R',
  ER_WIFI_BURST_MAGIC_W = 'W',
  ER_WIFI_BURST_MAGIC_B = 'B'
};

static void er_wifi_burst_write_u32(UINT8* dst, UINT32 value) {
  dst[ER_WIFI_BURST_U32_BYTE0_OFFSET] = (UINT8)(value & ER_WIFI_BURST_BYTE_MASK);
  dst[ER_WIFI_BURST_U32_BYTE1_OFFSET] =
      (UINT8)((value >> ER_WIFI_BURST_BYTE_BITS) & ER_WIFI_BURST_BYTE_MASK);
  dst[ER_WIFI_BURST_U32_BYTE2_OFFSET] =
      (UINT8)((value >> (ER_WIFI_BURST_BYTE_BITS * ER_WIFI_BURST_U32_BYTE2_OFFSET)) &
              ER_WIFI_BURST_BYTE_MASK);
  dst[ER_WIFI_BURST_U32_BYTE3_OFFSET] =
      (UINT8)((value >> (ER_WIFI_BURST_BYTE_BITS * ER_WIFI_BURST_U32_BYTE3_OFFSET)) &
              ER_WIFI_BURST_BYTE_MASK);
}

static void er_wifi_burst_write_u64(UINT8* dst, UINT64 value) {
  er_wifi_burst_write_u32(dst + ER_WIFI_BURST_U64_LO_U32_OFFSET, (UINT32)value);
  er_wifi_burst_write_u32(dst + ER_WIFI_BURST_U64_HI_U32_OFFSET,
                          (UINT32)(value >> (ER_WIFI_BURST_BYTE_BITS *
                                             ER_WIFI_BURST_U64_HI_U32_OFFSET)));
}

static UINT8 er_wifi_burst_tx_pending(const ErBleWifiRoleAdvert* advert) {
  return (UINT8)(advert != 0 &&
                 (advert->capabilities & ER_BLE_WIFI_CAPABILITY_BURST_TX_PENDING) != 0u);
}

static UINT64 er_wifi_burst_session_id(const ErBleWifiRoleAdvert* local,
                                       const ErBleWifiRoleAdvert* remote) {
  return local->node_nonce ^
         remote->node_nonce ^
         ((UINT64)local->group_id << (ER_WIFI_BURST_BYTE_BITS * ER_WIFI_BURST_U64_HI_U32_OFFSET)) ^
         (UINT64)local->wifi_channel;
}

static void er_wifi_burst_fill_ssid(UINT32 group_id, UINT64 session_id,
                                    ErWifiBurstPlan* plan) {
  plan->ssid[ER_WIFI_BURST_SSID_MAGIC_E_OFFSET] = ER_WIFI_BURST_MAGIC_E;
  plan->ssid[ER_WIFI_BURST_SSID_MAGIC_R_OFFSET] = ER_WIFI_BURST_MAGIC_R;
  plan->ssid[ER_WIFI_BURST_SSID_MAGIC_W_OFFSET] = ER_WIFI_BURST_MAGIC_W;
  plan->ssid[ER_WIFI_BURST_SSID_MAGIC_B_OFFSET] = ER_WIFI_BURST_MAGIC_B;
  er_wifi_burst_write_u32(plan->ssid + ER_WIFI_BURST_SSID_GROUP_OFFSET, group_id);
  er_wifi_burst_write_u64(plan->ssid + ER_WIFI_BURST_SSID_SESSION_OFFSET, session_id);
  plan->ssid_len = ER_WIFI_BURST_SSID_BYTES;
}

UINT8 er_wifi_burst_plan_prepare(const ErBleWifiRoleAdvert* local,
                                 const ErBleWifiRoleAdvert* remote,
                                 ErWifiBurstPlan* out_plan) {
  ErBleWifiRoleDecision decision;

  if (out_plan == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_plan, (UINTN)sizeof(*out_plan));
  if (er_ble_wifi_role_advert_is_valid(local) == 0u ||
      er_ble_wifi_role_advert_is_valid(remote) == 0u ||
      local->group_id != remote->group_id ||
      local->wifi_channel != remote->wifi_channel) {
    return 0u;
  }
  if (er_wifi_burst_tx_pending(local) == 0u &&
      er_wifi_burst_tx_pending(remote) == 0u) {
    return 1u;
  }

  decision = er_ble_wifi_role_decide(local, remote);
  switch (decision) {
    case ER_BLE_WIFI_ROLE_DECISION_LOCAL_AP:
      out_plan->local_role = ER_BLE_WIFI_ROLE_AP;
      break;
    case ER_BLE_WIFI_ROLE_DECISION_LOCAL_STA:
      out_plan->local_role = ER_BLE_WIFI_ROLE_STA;
      break;
    case ER_BLE_WIFI_ROLE_DECISION_NONE:
    case ER_BLE_WIFI_ROLE_DECISION_CONFLICT:
    default:
      return 0u;
  }

  out_plan->open = 1u;
  out_plan->wifi_channel = local->wifi_channel;
  out_plan->group_id = local->group_id;
  out_plan->session_id = er_wifi_burst_session_id(local, remote);
  er_wifi_burst_fill_ssid(out_plan->group_id, out_plan->session_id, out_plan);
  return 1u;
}
