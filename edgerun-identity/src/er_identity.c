#include "er_identity.h"

#include "er_blake3.h"
#include "er_clock.h"

static const uint8_t g_er_identity_id_domain[] = "edgerun:c:v1:identity-id";
static const uint8_t g_er_identity_child_domain[] = "edgerun:c:v1:identity-child";
static const uint8_t g_er_identity_app_scope_domain[] = "edgerun:c:v1:identity-app-scope";

enum {
  ER_IDENTITY_U16_BYTES = 2u,
  ER_IDENTITY_BYTE_SHIFT = 8u,
  ER_IDENTITY_U16_BYTE0 = 0u,
  ER_IDENTITY_U16_BYTE1 = 1u,
  ER_IDENTITY_SOURCE_KIND_OFF = 0u,
  ER_IDENTITY_SOURCE_LEN_OFF = 2u,
  ER_IDENTITY_DELEGATION_PARENT_OFF = 0u,
  ER_IDENTITY_DELEGATION_DELEGATE_OFF = 32u,
  ER_IDENTITY_DELEGATION_SCOPE_OFF = 64u,
  ER_IDENTITY_DERIVED_MATERIAL_SIZE = 32u,
  ER_IDENTITY_U32_BYTES = 4u,
  ER_IDENTITY_U32_BYTE0 = 0u,
  ER_IDENTITY_U32_BYTE1 = 1u,
  ER_IDENTITY_U32_BYTE2 = 2u,
  ER_IDENTITY_U32_BYTE3 = 3u,
  ER_IDENTITY_U32_SHIFT2 = 16u,
  ER_IDENTITY_U32_SHIFT3 = 24u
};

static void er_identity_zero(void* dst, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;

  for (i = 0u; i < len; ++i) {
    out[i] = 0u;
  }
}

static void er_identity_copy(void* dst, const void* src, size_t len) {
  size_t i;
  uint8_t* out = (uint8_t*)dst;
  const uint8_t* in = (const uint8_t*)src;

  for (i = 0u; i < len; ++i) {
    out[i] = in[i];
  }
}

//@optimizer-ignore-function identity ids and key material are fixed-size protocol byte arrays
static int er_identity_bytes_nonzero(const uint8_t* bytes, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (bytes[i] != 0u) {
      return 1;
    }
  }
  return 0;
}

//@optimizer-ignore-function identity ids and key material are fixed-size protocol byte arrays
static int er_identity_bytes_equal(const uint8_t* left, const uint8_t* right,
                                   size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (left[i] != right[i]) {
      return 0;
    }
  }
  return 1;
}

static void er_identity_store16(uint8_t* out, uint16_t value) {
  out[ER_IDENTITY_U16_BYTE0] = (uint8_t)value;
  out[ER_IDENTITY_U16_BYTE1] = (uint8_t)(value >> ER_IDENTITY_BYTE_SHIFT);
}

static void er_identity_store32(uint8_t* out, uint32_t value) {
  out[ER_IDENTITY_U32_BYTE0] = (uint8_t)value;
  out[ER_IDENTITY_U32_BYTE1] = (uint8_t)(value >> ER_IDENTITY_BYTE_SHIFT);
  out[ER_IDENTITY_U32_BYTE2] = (uint8_t)(value >> ER_IDENTITY_U32_SHIFT2);
  out[ER_IDENTITY_U32_BYTE3] = (uint8_t)(value >> ER_IDENTITY_U32_SHIFT3);
}

static int er_identity_kind_valid(uint16_t identity_kind) {
  switch (identity_kind) {
    case ER_IDENTITY_KIND_USER:
    case ER_IDENTITY_KIND_DEVICE:
    case ER_IDENTITY_KIND_APP:
    case ER_IDENTITY_KIND_STORAGE:
    case ER_IDENTITY_KIND_RELAY:
    case ER_IDENTITY_KIND_RESOURCE:
    case ER_IDENTITY_KIND_OBJECT:
    case ER_IDENTITY_KIND_EPHEMERAL:
    case ER_IDENTITY_KIND_DELEGATED:
      return 1;
    default:
      return 0;
  }
}

static int er_identity_source_kind_valid(uint16_t source_kind) {
  switch (source_kind) {
    case ER_IDENTITY_SOURCE_HASH:
    case ER_IDENTITY_SOURCE_ED25519_PUBLIC:
    case ER_IDENTITY_SOURCE_P256_PUBLIC:
    case ER_IDENTITY_SOURCE_TPM_P256_PUBLIC:
    case ER_IDENTITY_SOURCE_OBJECT_ID:
    case ER_IDENTITY_SOURCE_ENDPOINT:
    case ER_IDENTITY_SOURCE_DERIVED:
    case ER_IDENTITY_SOURCE_DELEGATION:
    case ER_IDENTITY_SOURCE_ANDROID_KEYSTONE_P256_PUBLIC:
      return 1;
    default:
      return 0;
  }
}

static int er_identity_source_material_len_valid(uint16_t source_kind,
                                                 size_t material_len) {
  switch (source_kind) {
    case ER_IDENTITY_SOURCE_HASH:
    case ER_IDENTITY_SOURCE_OBJECT_ID:
    case ER_IDENTITY_SOURCE_DERIVED:
      return material_len == ER_IDENTITY_HASH_SIZE;
    case ER_IDENTITY_SOURCE_ED25519_PUBLIC:
      return material_len == ER_IDENTITY_ED25519_PUBLIC_SIZE;
    case ER_IDENTITY_SOURCE_P256_PUBLIC:
    case ER_IDENTITY_SOURCE_TPM_P256_PUBLIC:
    case ER_IDENTITY_SOURCE_ANDROID_KEYSTONE_P256_PUBLIC:
      return material_len == ER_IDENTITY_P256_PUBLIC_SIZE;
    case ER_IDENTITY_SOURCE_ENDPOINT:
      return material_len >= ER_IDENTITY_ENDPOINT_MIN_SIZE &&
             material_len <= ER_IDENTITY_MATERIAL_MAX;
    case ER_IDENTITY_SOURCE_DELEGATION:
      return material_len == ER_IDENTITY_DELEGATION_MATERIAL_SIZE;
    default:
      return 0;
  }
}

int er_identity_id_nonzero(const er_identity_id_t* id) {
  if (id == (const er_identity_id_t*)0) {
    return 0;
  }
  return er_identity_bytes_nonzero(id->bytes, ER_IDENTITY_ID_SIZE);
}

int er_identity_id_equal(const er_identity_id_t* left,
                         const er_identity_id_t* right) {
  if (er_identity_id_nonzero(left) == 0 ||
      er_identity_id_nonzero(right) == 0) {
    return 0;
  }
  return er_identity_bytes_equal(left->bytes, right->bytes,
                                 ER_IDENTITY_ID_SIZE);
}

int er_identity_source_prepare(uint16_t source_kind,
                               const void* material,
                               size_t material_len,
                               er_identity_source_t* out_source) {
  if (material == (const void*)0 ||
      out_source == (er_identity_source_t*)0 ||
      material_len > ER_IDENTITY_MATERIAL_MAX ||
      er_identity_source_kind_valid(source_kind) == 0 ||
      er_identity_source_material_len_valid(source_kind, material_len) == 0 ||
      er_identity_bytes_nonzero((const uint8_t*)material, material_len) == 0) {
    return ER_IDENTITY_ERR_BADARG;
  }
  er_identity_zero(out_source, sizeof(*out_source));
  out_source->source_kind = source_kind;
  out_source->material_len = (uint16_t)material_len;
  er_identity_copy(out_source->material, material, material_len);
  return ER_IDENTITY_OK;
}

int er_identity_source_prepare_delegation(const er_identity_id_t* parent,
                                          const er_identity_id_t* delegate,
                                          const uint8_t scope_hash[ER_IDENTITY_HASH_SIZE],
                                          er_identity_source_t* out_source) {
  uint8_t material[ER_IDENTITY_DELEGATION_MATERIAL_SIZE];

  if (er_identity_id_nonzero(parent) == 0 ||
      er_identity_id_nonzero(delegate) == 0 ||
      scope_hash == (const uint8_t*)0 ||
      er_identity_bytes_nonzero(scope_hash, ER_IDENTITY_HASH_SIZE) == 0) {
    return ER_IDENTITY_ERR_BADARG;
  }
  er_identity_copy(&material[ER_IDENTITY_DELEGATION_PARENT_OFF],
                   parent->bytes,
                   ER_IDENTITY_ID_SIZE);
  er_identity_copy(&material[ER_IDENTITY_DELEGATION_DELEGATE_OFF],
                   delegate->bytes,
                   ER_IDENTITY_ID_SIZE);
  er_identity_copy(&material[ER_IDENTITY_DELEGATION_SCOPE_OFF],
                   scope_hash,
                   ER_IDENTITY_HASH_SIZE);
  return er_identity_source_prepare(ER_IDENTITY_SOURCE_DELEGATION,
                                    material,
                                    sizeof(material),
                                    out_source);
}

int er_identity_source_valid(const er_identity_source_t* source) {
  if (source == (const er_identity_source_t*)0 ||
      er_identity_source_kind_valid(source->source_kind) == 0 ||
      er_identity_source_material_len_valid(source->source_kind,
                                            source->material_len) == 0 ||
      er_identity_bytes_nonzero(source->material, source->material_len) == 0) {
    return 0;
  }
  return 1;
}

int er_identity_id_from_source(const er_identity_source_t* source,
                               er_identity_id_t* out_id) {
  ErBlake3Hasher hasher;
  uint8_t header[ER_IDENTITY_U16_BYTES * ER_IDENTITY_U16_BYTES];

  if (out_id == (er_identity_id_t*)0 ||
      er_identity_source_valid(source) == 0) {
    return ER_IDENTITY_ERR_BADARG;
  }

  er_identity_store16(&header[ER_IDENTITY_SOURCE_KIND_OFF],
                      source->source_kind);
  er_identity_store16(&header[ER_IDENTITY_SOURCE_LEN_OFF],
                      source->material_len);
  er_blake3_init(&hasher);
  if (er_blake3_update(&hasher,
                       g_er_identity_id_domain,
                       sizeof(g_er_identity_id_domain) - 1u) == 0u ||
      er_blake3_update(&hasher, header, sizeof(header)) == 0u ||
      er_blake3_update(&hasher,
                       source->material,
                       source->material_len) == 0u ||
      er_blake3_final(&hasher, out_id->bytes) == 0u) {
    er_identity_zero(out_id, sizeof(*out_id));
    return ER_IDENTITY_ERR_CORRUPT;
  }
  return ER_IDENTITY_OK;
}

int er_identity_prepare(uint16_t identity_kind,
                        const er_identity_source_t* source,
                        er_clock_epoch_stamp_t epoch,
                        er_identity_t* out_identity) {
  if (out_identity == (er_identity_t*)0 ||
      er_identity_kind_valid(identity_kind) == 0 ||
      er_clock_stamp_valid(epoch) == 0 ||
      er_identity_source_valid(source) == 0) {
    return ER_IDENTITY_ERR_BADARG;
  }
  er_identity_zero(out_identity, sizeof(*out_identity));
  out_identity->abi_version = ER_IDENTITY_ABI_VERSION;
  out_identity->identity_kind = identity_kind;
  out_identity->epoch = epoch;
  out_identity->source = *source;
  return er_identity_id_from_source(source, &out_identity->id);
}

static int er_identity_instantiation_operations_valid(uint32_t operations) {
  switch (operations) {
    case ER_IDENTITY_INSTANTIATION_OPERATION_VERIFY:
    case ER_IDENTITY_INSTANTIATION_OPERATION_SIGN:
    case ER_IDENTITY_INSTANTIATION_OPERATION_VERIFY_AND_SIGN:
      return 1;
    default:
      return 0;
  }
}

int er_identity_instantiate(const er_identity_instantiation_t* instantiation,
                            er_identity_t* out_identity) {
  er_identity_source_t source;

  if (instantiation == (const er_identity_instantiation_t*)0 ||
      out_identity == (er_identity_t*)0 ||
      instantiation->source_kind == ER_IDENTITY_SOURCE_DELEGATION ||
      instantiation->source_kind == ER_IDENTITY_SOURCE_DERIVED) {
    return ER_IDENTITY_ERR_BADARG;
  }
  if (er_identity_source_prepare(instantiation->source_kind,
                                 instantiation->material,
                                 instantiation->material_len,
                                 &source) != ER_IDENTITY_OK) {
    return ER_IDENTITY_ERR_BADARG;
  }
  return er_identity_prepare(instantiation->identity_kind,
                             &source,
                             instantiation->epoch,
                             out_identity);
}

int er_identity_instantiate_app(const er_identity_app_instantiation_t* instantiation,
                                er_identity_t* out_identity) {
  ErBlake3Hasher hasher;
  er_identity_t app_anchor;
  er_identity_source_t app_source;
  er_identity_source_t delegation_source;
  uint8_t operations_bytes[ER_IDENTITY_U32_BYTES];
  uint8_t delegated_scope_hash[ER_IDENTITY_HASH_SIZE];

  if (instantiation == (const er_identity_app_instantiation_t*)0 ||
      out_identity == (er_identity_t*)0 ||
      er_identity_valid(instantiation->parent) == 0 ||
      instantiation->scope_hash == (const uint8_t*)0 ||
      er_identity_bytes_nonzero(instantiation->scope_hash,
                                ER_IDENTITY_HASH_SIZE) == 0 ||
      er_clock_stamp_valid(instantiation->epoch) == 0 ||
      er_identity_instantiation_operations_valid(instantiation->required_parent_operations) == 0) {
    return ER_IDENTITY_ERR_BADARG;
  }
  if (er_identity_source_prepare(ER_IDENTITY_SOURCE_HASH,
                                 instantiation->app_material,
                                 instantiation->app_material_len,
                                 &app_source) != ER_IDENTITY_OK ||
      er_identity_prepare(ER_IDENTITY_KIND_APP,
                          &app_source,
                          instantiation->epoch,
                          &app_anchor) != ER_IDENTITY_OK) {
    return ER_IDENTITY_ERR_BADARG;
  }
  er_identity_store32(operations_bytes,
                      instantiation->required_parent_operations);
  er_blake3_init(&hasher);
  if (er_blake3_update(&hasher,
                       g_er_identity_app_scope_domain,
                       sizeof(g_er_identity_app_scope_domain) - 1u) == 0u ||
      er_blake3_update(&hasher,
                       operations_bytes,
                       sizeof(operations_bytes)) == 0u ||
      er_blake3_update(&hasher,
                       instantiation->scope_hash,
                       ER_IDENTITY_HASH_SIZE) == 0u ||
      er_blake3_final(&hasher, delegated_scope_hash) == 0u) {
    return ER_IDENTITY_ERR_CORRUPT;
  }
  if (er_identity_source_prepare_delegation(&instantiation->parent->id,
                                            &app_anchor.id,
                                            delegated_scope_hash,
                                            &delegation_source) != ER_IDENTITY_OK) {
    return ER_IDENTITY_ERR_BADARG;
  }
  return er_identity_prepare(ER_IDENTITY_KIND_DELEGATED,
                             &delegation_source,
                             instantiation->epoch,
                             out_identity);
}

int er_identity_valid(const er_identity_t* identity) {
  er_identity_id_t derived_id;

  if (identity == (const er_identity_t*)0 ||
      identity->abi_version != ER_IDENTITY_ABI_VERSION ||
      er_identity_kind_valid(identity->identity_kind) == 0 ||
      er_clock_stamp_valid(identity->epoch) == 0 ||
      er_identity_id_nonzero(&identity->id) == 0 ||
      er_identity_source_valid(&identity->source) == 0 ||
      er_identity_id_from_source(&identity->source, &derived_id) != ER_IDENTITY_OK ||
      er_identity_id_equal(&identity->id, &derived_id) == 0) {
    return 0;
  }
  return 1;
}

int er_identity_equal(const er_identity_t* left,
                      const er_identity_t* right) {
  if (er_identity_valid(left) == 0 ||
      er_identity_valid(right) == 0 ||
      left->identity_kind != right->identity_kind ||
      er_clock_stamp_compare(left->epoch, right->epoch) != 0 ||
      left->source.source_kind != right->source.source_kind ||
      left->source.material_len != right->source.material_len ||
      er_identity_id_equal(&left->id, &right->id) == 0) {
    return 0;
  }
  return er_identity_bytes_equal(left->source.material,
                                 right->source.material,
                                 left->source.material_len);
}

int er_identity_derive_child(const er_identity_t* parent,
                             uint16_t child_kind,
                             er_clock_epoch_stamp_t epoch,
                             const void* label,
                             size_t label_len,
                             const void* material,
                             size_t material_len,
                             er_identity_t* out_child) {
  ErBlake3Hasher hasher;
  er_identity_source_t source;
  uint8_t child_material[ER_IDENTITY_DERIVED_MATERIAL_SIZE];
  uint8_t child_kind_bytes[ER_IDENTITY_U16_BYTES];

  if (er_identity_valid(parent) == 0 ||
      er_identity_kind_valid(child_kind) == 0 ||
      er_clock_stamp_valid(epoch) == 0 ||
      out_child == (er_identity_t*)0 ||
      label == (const void*)0 ||
      material == (const void*)0 ||
      label_len == 0u ||
      material_len == 0u ||
      er_identity_bytes_nonzero((const uint8_t*)label, label_len) == 0 ||
      er_identity_bytes_nonzero((const uint8_t*)material, material_len) == 0) {
    return ER_IDENTITY_ERR_BADARG;
  }

  er_identity_store16(child_kind_bytes, child_kind);
  er_blake3_init(&hasher);
  if (er_blake3_update(&hasher,
                       g_er_identity_child_domain,
                       sizeof(g_er_identity_child_domain) - 1u) == 0u ||
      er_blake3_update(&hasher, parent->id.bytes, ER_IDENTITY_ID_SIZE) == 0u ||
      er_blake3_update(&hasher, child_kind_bytes, sizeof(child_kind_bytes)) == 0u ||
      er_blake3_update(&hasher, (const uint8_t*)label, label_len) == 0u ||
      er_blake3_update(&hasher, (const uint8_t*)material, material_len) == 0u ||
      er_blake3_final(&hasher, child_material) == 0u) {
    return ER_IDENTITY_ERR_CORRUPT;
  }
  if (er_identity_source_prepare(ER_IDENTITY_SOURCE_DERIVED,
                                 child_material,
                                 sizeof(child_material),
                                 &source) != ER_IDENTITY_OK) {
    return ER_IDENTITY_ERR_CORRUPT;
  }
  return er_identity_prepare(child_kind, &source, epoch, out_child);
}
