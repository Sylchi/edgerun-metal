#ifndef ER_BLE_ADV_H
#define ER_BLE_ADV_H

/*
 * Purpose: carry EdgeRun bytes through 31-byte BLE advertising data during EFI Boot Services.
 * Intention: keep pre-runtime device discovery connectionless and independent of GATT.
 */

#include "er_types.h"

#define ER_BLE_ADV_DATA_BYTES 31u
#define ER_BLE_ADV_PAYLOAD_BYTES 18u
#define ER_BLE_ADV_CHANNEL_ID 1u
#define ER_BLE_ADV_SEQUENCE_INVALID 0u
#define ER_BLE_WIFI_GROUP_ID_INVALID 0u
#define ER_BLE_WIFI_CAPABILITY_AP 1u
#define ER_BLE_WIFI_CAPABILITY_STA 2u
#define ER_BLE_WIFI_CAPABILITY_BURST_TX_PENDING 4u

typedef enum {
  ER_BLE_PAYLOAD_KIND_NONE = 0,
  ER_BLE_PAYLOAD_KIND_WIFI_ROLE = 1
} ErBlePayloadKind;

typedef enum {
  ER_BLE_WIFI_ROLE_NONE = 0,
  ER_BLE_WIFI_ROLE_AP = 1,
  ER_BLE_WIFI_ROLE_STA = 2
} ErBleWifiRole;

typedef enum {
  ER_BLE_WIFI_ROLE_DECISION_NONE = 0,
  ER_BLE_WIFI_ROLE_DECISION_LOCAL_AP = 1,
  ER_BLE_WIFI_ROLE_DECISION_LOCAL_STA = 2,
  ER_BLE_WIFI_ROLE_DECISION_CONFLICT = 3
} ErBleWifiRoleDecision;

typedef struct {
  UINT8 channel_id;
  UINT16 sequence;
  UINT8 fragment_index;
  UINT8 fragment_count;
  UINT8 payload_len;
  UINT8 payload[ER_BLE_ADV_PAYLOAD_BYTES];
} ErBleAdvPacket;

typedef struct {
  UINT8 initialized;
  EFI_BLUETOOTH_HC_PROTOCOL* hc;
} ErBleAdvEfi;

typedef struct {
  UINT8 capabilities;
  UINT8 preferred_role;
  UINT8 election_priority;
  UINT8 wifi_channel;
  UINT32 group_id;
  UINT64 node_nonce;
} ErBleWifiRoleAdvert;

UINT8 er_ble_adv_prepare_packet(UINT8 channel_id,
                                UINT16 sequence,
                                UINT8 fragment_index,
                                UINT8 fragment_count,
                                const UINT8* payload,
                                UINT8 payload_len,
                                ErBleAdvPacket* out_packet);
UINT8 er_ble_adv_encode_data(const ErBleAdvPacket* packet,
                             UINT8 out_data[ER_BLE_ADV_DATA_BYTES],
                             UINT8* out_len);
UINT8 er_ble_adv_decode_data(const UINT8* data,
                             UINT8 data_len,
                             ErBleAdvPacket* out_packet);
UINT8 er_ble_wifi_role_advert_prepare(UINT8 capabilities,
                                      UINT8 preferred_role,
                                      UINT8 election_priority,
                                      UINT8 wifi_channel,
                                      UINT32 group_id,
                                      UINT64 node_nonce,
                                      ErBleWifiRoleAdvert* out_advert);
UINT8 er_ble_wifi_role_encode_payload(const ErBleWifiRoleAdvert* advert,
                                      UINT8 out_payload[ER_BLE_ADV_PAYLOAD_BYTES]);
UINT8 er_ble_wifi_role_decode_payload(const UINT8 payload[ER_BLE_ADV_PAYLOAD_BYTES],
                                      ErBleWifiRoleAdvert* out_advert);
UINT8 er_ble_wifi_role_advert_is_valid(const ErBleWifiRoleAdvert* advert);
ErBleWifiRoleDecision er_ble_wifi_role_decide(const ErBleWifiRoleAdvert* local,
                                              const ErBleWifiRoleAdvert* remote);
UINT8 er_ble_adv_efi_init(EFI_SYSTEM_TABLE* system_table, ErBleAdvEfi* out_ble);
UINT8 er_ble_adv_efi_start_advertising(ErBleAdvEfi* ble,
                                       const ErBleAdvPacket* packet);
UINT8 er_ble_adv_efi_poll_packet(ErBleAdvEfi* ble, ErBleAdvPacket* out_packet);

#endif
