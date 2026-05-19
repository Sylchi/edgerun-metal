#ifndef ER_BLE_ADV_H
#define ER_BLE_ADV_H

/*
 * Purpose: carry EdgeRun bytes through BLE legacy advertising during EFI Boot Services.
 * Intention: keep pre-runtime device discovery connectionless and independent of GATT.
 */

#include "er_types.h"

#define ER_BLE_ADV_LEGACY_DATA_BYTES 31u
#define ER_BLE_ADV_PAYLOAD_BYTES 18u
#define ER_BLE_ADV_CHANNEL_ID 1u
#define ER_BLE_ADV_SEQUENCE_INVALID 0u

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

UINT8 er_ble_adv_prepare_packet(UINT8 channel_id,
                                UINT16 sequence,
                                UINT8 fragment_index,
                                UINT8 fragment_count,
                                const UINT8* payload,
                                UINT8 payload_len,
                                ErBleAdvPacket* out_packet);
UINT8 er_ble_adv_encode_data(const ErBleAdvPacket* packet,
                             UINT8 out_data[ER_BLE_ADV_LEGACY_DATA_BYTES],
                             UINT8* out_len);
UINT8 er_ble_adv_decode_data(const UINT8* data,
                             UINT8 data_len,
                             ErBleAdvPacket* out_packet);
UINT8 er_ble_adv_efi_init(EFI_SYSTEM_TABLE* system_table, ErBleAdvEfi* out_ble);
UINT8 er_ble_adv_efi_start_advertising(ErBleAdvEfi* ble,
                                       const ErBleAdvPacket* packet);
UINT8 er_ble_adv_efi_poll_packet(ErBleAdvEfi* ble, ErBleAdvPacket* out_packet);

#endif
