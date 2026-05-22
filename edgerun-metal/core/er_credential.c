#include "er_credential.h"
#include "er_mem.h"

/*
 * Purpose: validate compact credential material before it enters metal records.
 * Intention: keep this distinct from canonical routable identities.
 */

static UINT8 er_credential_material_len_valid(UINT16 credential_kind, UINT16 backing_type,
                                              UINT16 material_len) {
  switch (credential_kind) {
    case ER_CREDENTIAL_KIND_PUBLIC_KEY:
      switch (backing_type) {
        case ER_CREDENTIAL_BACKING_ED25519:
          return (UINT8)(material_len == ER_PUBLIC_KEY_LEN);
        case ER_CREDENTIAL_BACKING_P256:
        case ER_CREDENTIAL_BACKING_TPM_P256:
          return (UINT8)(material_len == ER_P256_PUBLIC_KEY_LEN);
        default:
          return 0;
      }
    case ER_CREDENTIAL_KIND_HASH:
      switch (backing_type) {
        case ER_CREDENTIAL_BACKING_HASH:
          return (UINT8)(material_len == ER_HASH_LEN);
        default:
          return 0;
      }
    default:
      return 0;
  }
}

UINT8 er_credential_prepare(UINT16 credential_kind, UINT16 backing_type,
                            const UINT8* material, UINT16 material_len,
                            ErCredential* out_credential) {
  if (material == 0 || out_credential == 0 ||
      material_len > ER_CREDENTIAL_MATERIAL_MAX ||
      er_credential_material_len_valid(credential_kind, backing_type, material_len) == 0u ||
      er_mem_any_nonzero(material, material_len) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_credential, (UINTN)sizeof(*out_credential));
  out_credential->credential_kind = credential_kind;
  out_credential->backing_type = backing_type;
  out_credential->material_len = material_len;
  er_mem_copy(out_credential->material, material, material_len);
  return 1;
}

UINT8 er_credential_valid(const ErCredential* credential) {
  if (credential == 0 ||
      credential->reserved != 0u ||
      er_credential_material_len_valid(credential->credential_kind, credential->backing_type,
                                       credential->material_len) == 0u ||
      er_mem_any_nonzero(credential->material, credential->material_len) == 0u) {
    return 0;
  }
  return 1;
}

UINT8 er_credential_equal(const ErCredential* left, const ErCredential* right) {
  if (er_credential_valid(left) == 0u ||
      er_credential_valid(right) == 0u ||
      left->credential_kind != right->credential_kind ||
      left->backing_type != right->backing_type ||
      left->material_len != right->material_len) {
    return 0;
  }
  return er_mem_equal(left->material, right->material, left->material_len);
}
