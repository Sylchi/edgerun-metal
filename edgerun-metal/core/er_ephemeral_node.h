#ifndef ER_EPHEMERAL_NODE_H
#define ER_EPHEMERAL_NODE_H

/*
 * Purpose: derive boot-local node identity from a persistent admission anchor.
 * Intention: avoid pretending Pi Zero W SD cards can safely store node secrets.
 */

#include "er_crypto.h"
#include "er_wifi_l2.h"

#define ER_EPHEMERAL_NODE_ABI_VERSION 1u
#define ER_EPHEMERAL_NODE_BOOT_NONCE_LEN 32u

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErHash admission_id;
  UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN];
  ErNodeId node_id;
} ErEphemeralNode;

typedef struct {
  UINT16 abi_version;
  UINT16 reserved;
  ErEphemeralNode node;
  ErWifiL2ApPlan ap_plan;
} ErEphemeralNodeWifiL2;

UINT8 er_ephemeral_node_derive(const ErCryptoProvider* crypto,
                               const ErHash* admission_id,
                               const UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN],
                               ErEphemeralNode* out_node);
UINT8 er_ephemeral_node_wifi_l2_prepare(const ErCryptoProvider* crypto,
                                        const ErHash* admission_id,
                                        const UINT8 boot_nonce[ER_EPHEMERAL_NODE_BOOT_NONCE_LEN],
                                        UINT8 channel,
                                        ErEphemeralNodeWifiL2* out_binding);

#endif
