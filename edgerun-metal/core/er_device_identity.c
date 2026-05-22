#include "er_device_identity.h"
#include "er_mem.h"
#include "er_node_id.h"

/*
 * Purpose: bind relay node identity to the device/session key and measured booted program.
 * Intention: keep relay identity derivation deterministic while leaving trust decisions to admission.
 */

static UINT8 er_device_identity_kind_valid(UINT16 kind) {
  switch (kind) {
    case ER_DEVICE_IDENTITY_KIND_HARDWARE:
    case ER_DEVICE_IDENTITY_KIND_EPHEMERAL:
      return 1;
    default:
      return 0;
  }
}

static UINT16 er_device_node_id_source_kind(const ErCredential* identity) {
  switch (identity->credential_kind) {
    case ER_CREDENTIAL_KIND_PUBLIC_KEY:
      switch (identity->backing_type) {
        case ER_CREDENTIAL_BACKING_TPM_P256:
          return ER_NODE_ID_SOURCE_TPM_P256_PUBLIC_KEY;
        case ER_CREDENTIAL_BACKING_ED25519:
        case ER_CREDENTIAL_BACKING_P256:
          return ER_NODE_ID_SOURCE_PUBLIC_KEY;
        default:
          return 0u;
      }
    case ER_CREDENTIAL_KIND_HASH:
      return ER_NODE_ID_SOURCE_HASH;
    default:
      return 0u;
  }
}

UINT8 er_device_identity_prepare(UINT16 kind, const ErCredential* identity,
                                 ErDeviceIdentity* out_identity) {
  if (identity == 0 || out_identity == 0 ||
      er_device_identity_kind_valid(kind) == 0u ||
      er_credential_valid(identity) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_identity, (UINTN)sizeof(*out_identity));
  out_identity->abi_version = ER_WORK_ABI_VERSION;
  out_identity->kind = kind;
  out_identity->identity = *identity;
  return 1;
}

UINT8 er_device_relay_identity_derive(const ErCryptoProvider* crypto,
                                      const ErDeviceIdentity* device_identity,
                                      const ErHash* measured_program_hash,
                                      ErDeviceRelayIdentity* out_relay_identity) {
  UINT16 source_kind;
  ErNodeId node_id;

  if (crypto == 0 || device_identity == 0 || measured_program_hash == 0 ||
      out_relay_identity == 0 ||
      device_identity->abi_version != ER_WORK_ABI_VERSION ||
      er_device_identity_kind_valid(device_identity->kind) == 0u ||
      er_credential_valid(&device_identity->identity) == 0u ||
      er_hash_nonzero(measured_program_hash) == 0u) {
    return 0;
  }

  source_kind = er_device_node_id_source_kind(&device_identity->identity);
  if (source_kind == 0u ||
      er_node_id_from_material(crypto,
                               source_kind,
                               device_identity->identity.material,
                               device_identity->identity.material_len,
                               &node_id) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_relay_identity, (UINTN)sizeof(*out_relay_identity));
  out_relay_identity->abi_version = ER_WORK_ABI_VERSION;
  out_relay_identity->trust_kind = device_identity->kind;
  out_relay_identity->program_hash = *measured_program_hash;
  out_relay_identity->relay_node.abi_version = ER_WORK_ABI_VERSION;
  out_relay_identity->relay_node.role = ER_NODE_ROLE_RELAY;
  out_relay_identity->relay_node.identity = device_identity->identity;
  out_relay_identity->relay_node.node_id = node_id;
  return 1;
}
