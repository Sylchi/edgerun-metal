#include "er_device_identity.h"
#include "er_mem.h"

/*
 * Purpose: bind relay node identity to the device/session key and measured booted program.
 * Intention: keep relay identity derivation deterministic while leaving trust decisions to admission.
 */

static const UINT8 g_device_relay_node_domain[] = "edgerun:c:v1:device:relay-node";

enum {
  ER_DEVICE_TYPE_FIELD_BYTES = 2u,
  ER_DEVICE_RELAY_SPAN_COUNT = 3u,
  ER_DEVICE_RELAY_TYPE_SPAN = 0u,
  ER_DEVICE_RELAY_PROGRAM_SPAN = 1u,
  ER_DEVICE_RELAY_PUBLIC_KEY_SPAN = 2u,
  ER_DEVICE_BYTE_BITS = 8u,
  ER_DEVICE_U8_MASK = 0xffu
};

static UINT8 er_device_identity_kind_valid(UINT16 kind) {
  switch (kind) {
    case ER_DEVICE_IDENTITY_KIND_HARDWARE:
    case ER_DEVICE_IDENTITY_KIND_EPHEMERAL:
      return 1;
    default:
      return 0;
  }
}

static void er_device_put_u16(UINT8* dst, UINT16 value) {
  dst[0] = (UINT8)(value & ER_DEVICE_U8_MASK);
  dst[1] = (UINT8)((value >> ER_DEVICE_BYTE_BITS) & ER_DEVICE_U8_MASK);
}

static void er_device_span_set(ErByteSpan* span, const UINT8* bytes, UINTN len) {
  span->bytes = bytes;
  span->len = len;
}

UINT8 er_device_identity_prepare(UINT16 kind, const ErPublicKey* public_key,
                                 ErDeviceIdentity* out_identity) {
  if (public_key == 0 || out_identity == 0 ||
      er_device_identity_kind_valid(kind) == 0u ||
      er_mem_any_nonzero(public_key->bytes, ER_PUBLIC_KEY_LEN) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_identity, (UINTN)sizeof(*out_identity));
  out_identity->abi_version = ER_WORK_ABI_VERSION;
  out_identity->kind = kind;
  out_identity->public_key = *public_key;
  return 1;
}

UINT8 er_device_relay_identity_derive(const ErCryptoProvider* crypto,
                                      const ErDeviceIdentity* device_identity,
                                      const ErHash* measured_program_hash,
                                      ErDeviceRelayIdentity* out_relay_identity) {
  UINT8 type_bytes[ER_DEVICE_TYPE_FIELD_BYTES];
  ErHash node_hash;
  ErByteSpan spans[ER_DEVICE_RELAY_SPAN_COUNT];

  if (crypto == 0 || device_identity == 0 || measured_program_hash == 0 ||
      out_relay_identity == 0 ||
      device_identity->abi_version != ER_WORK_ABI_VERSION ||
      er_device_identity_kind_valid(device_identity->kind) == 0u ||
      er_mem_any_nonzero(device_identity->public_key.bytes, ER_PUBLIC_KEY_LEN) == 0u ||
      er_mem_any_nonzero(measured_program_hash->bytes, ER_HASH_LEN) == 0u) {
    return 0;
  }

  er_device_put_u16(type_bytes, device_identity->kind);
  er_device_span_set(&spans[ER_DEVICE_RELAY_TYPE_SPAN], type_bytes, (UINTN)sizeof(type_bytes));
  er_device_span_set(&spans[ER_DEVICE_RELAY_PROGRAM_SPAN], measured_program_hash->bytes, ER_HASH_LEN);
  er_device_span_set(&spans[ER_DEVICE_RELAY_PUBLIC_KEY_SPAN],
                     device_identity->public_key.bytes, ER_PUBLIC_KEY_LEN);

  if (er_crypto_hash(crypto, g_device_relay_node_domain,
                     (UINTN)(sizeof(g_device_relay_node_domain) - 1u),
                     spans, ER_DEVICE_RELAY_SPAN_COUNT, &node_hash) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_relay_identity, (UINTN)sizeof(*out_relay_identity));
  out_relay_identity->abi_version = ER_WORK_ABI_VERSION;
  out_relay_identity->trust_kind = device_identity->kind;
  out_relay_identity->program_hash = *measured_program_hash;
  out_relay_identity->relay_node.abi_version = ER_WORK_ABI_VERSION;
  out_relay_identity->relay_node.role = ER_NODE_ROLE_RELAY;
  out_relay_identity->relay_node.public_key = device_identity->public_key;
  er_mem_copy(out_relay_identity->relay_node.node_id.bytes, node_hash.bytes, ER_NODE_ID_LEN);
  return 1;
}
