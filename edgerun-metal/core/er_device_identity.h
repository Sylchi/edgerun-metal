#ifndef ER_DEVICE_IDENTITY_H
#define ER_DEVICE_IDENTITY_H

/*
 * Purpose: derive device-scoped relay identities from measured code and device keys.
 * Intention: let admission distinguish hardware-backed relays from ephemeral boot relays.
 */

#include "er_crypto.h"
#include "er_identity.h"

#define ER_DEVICE_IDENTITY_KIND_HARDWARE 1u
#define ER_DEVICE_IDENTITY_KIND_EPHEMERAL 2u

typedef struct {
  UINT16 abi_version;
  UINT16 kind;
  ErIdentity identity;
} ErDeviceIdentity;

typedef struct {
  UINT16 abi_version;
  UINT16 trust_kind;
  ErHash program_hash;
  ErNodeIdentity relay_node;
} ErDeviceRelayIdentity;

UINT8 er_device_identity_prepare(UINT16 kind, const ErIdentity* identity,
                                 ErDeviceIdentity* out_identity);
UINT8 er_device_relay_identity_derive(const ErCryptoProvider* crypto,
                                      const ErDeviceIdentity* device_identity,
                                      const ErHash* measured_program_hash,
                                      ErDeviceRelayIdentity* out_relay_identity);

#endif
