#include "er_identity.h"
#include "er_mem.h"

/*
 * Purpose: validate compact identity material before it enters route records.
 * Intention: make unsupported identity/backing pairs fail closed.
 */

static UINT8 er_identity_material_len_valid(UINT16 identity_type, UINT16 backing_type,
                                            UINT16 material_len) {
  switch (identity_type) {
    case ER_IDENTITY_TYPE_PUBLIC_KEY:
      switch (backing_type) {
        case ER_IDENTITY_BACKING_ED25519:
          return (UINT8)(material_len == ER_PUBLIC_KEY_LEN);
        case ER_IDENTITY_BACKING_P256:
        case ER_IDENTITY_BACKING_TPM_P256:
          return (UINT8)(material_len == ER_P256_PUBLIC_KEY_LEN);
        default:
          return 0;
      }
    case ER_IDENTITY_TYPE_HASH:
      switch (backing_type) {
        case ER_IDENTITY_BACKING_HASH:
          return (UINT8)(material_len == ER_HASH_LEN);
        default:
          return 0;
      }
    default:
      return 0;
  }
}

UINT8 er_identity_prepare(UINT16 identity_type, UINT16 backing_type,
                          const UINT8* material, UINT16 material_len,
                          ErIdentity* out_identity) {
  if (material == 0 || out_identity == 0 ||
      material_len > ER_IDENTITY_MATERIAL_MAX ||
      er_identity_material_len_valid(identity_type, backing_type, material_len) == 0u ||
      er_mem_any_nonzero(material, material_len) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_identity, (UINTN)sizeof(*out_identity));
  out_identity->identity_type = identity_type;
  out_identity->backing_type = backing_type;
  out_identity->material_len = material_len;
  er_mem_copy(out_identity->material, material, material_len);
  return 1;
}

UINT8 er_identity_valid(const ErIdentity* identity) {
  if (identity == 0 ||
      identity->reserved != 0u ||
      er_identity_material_len_valid(identity->identity_type, identity->backing_type,
                                     identity->material_len) == 0u ||
      er_mem_any_nonzero(identity->material, identity->material_len) == 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_identity_equal(const ErIdentity* left, const ErIdentity* right) {
  if (er_identity_valid(left) == 0u ||
      er_identity_valid(right) == 0u ||
      left->identity_type != right->identity_type ||
      left->backing_type != right->backing_type ||
      left->material_len != right->material_len) {
    return 0;
  }
  return er_mem_equal(left->material, right->material, left->material_len);
}
