#include "er_boot_admission_record.h"
#include "er_mem.h"

#define ER_BOOT_ADMISSION_RECORD_U16_BYTES 2u
#define ER_BOOT_ADMISSION_RECORD_U32_BYTES 4u
#define ER_BOOT_ADMISSION_RECORD_MAGIC_OFFSET 0u
#define ER_BOOT_ADMISSION_RECORD_ABI_OFFSET 4u
#define ER_BOOT_ADMISSION_RECORD_SIZE_OFFSET 6u
#define ER_BOOT_ADMISSION_RECORD_GENERATION_OFFSET 8u
#define ER_BOOT_ADMISSION_RECORD_MODE_OFFSET 12u
#define ER_BOOT_ADMISSION_RECORD_CHANNEL_OFFSET 13u
#define ER_BOOT_ADMISSION_RECORD_VENDOR_OFFSET 14u
#define ER_BOOT_ADMISSION_RECORD_DEVICE_OFFSET 16u
#define ER_BOOT_ADMISSION_RECORD_RESERVED_OFFSET 18u
#define ER_BOOT_ADMISSION_RECORD_IDENTITY_OFFSET 20u
#define ER_BOOT_ADMISSION_RECORD_IDENTITY_TYPE_OFFSET 20u
#define ER_BOOT_ADMISSION_RECORD_IDENTITY_BACKING_OFFSET 22u
#define ER_BOOT_ADMISSION_RECORD_IDENTITY_LEN_OFFSET 24u
#define ER_BOOT_ADMISSION_RECORD_IDENTITY_RESERVED_OFFSET 26u
#define ER_BOOT_ADMISSION_RECORD_IDENTITY_MATERIAL_OFFSET 28u
#define ER_BOOT_ADMISSION_RECORD_HASH_OFFSET 112u
#define ER_BOOT_ADMISSION_BYTE_MASK 0xffu
#define ER_BOOT_ADMISSION_U16_HIGH_SHIFT 8u
#define ER_BOOT_ADMISSION_U16_BYTE0 0u
#define ER_BOOT_ADMISSION_U16_BYTE1 1u
#define ER_BOOT_ADMISSION_U32_SHIFT0 24u
#define ER_BOOT_ADMISSION_U32_SHIFT1 16u
#define ER_BOOT_ADMISSION_U32_SHIFT2 8u
#define ER_BOOT_ADMISSION_U32_BYTE0 0u
#define ER_BOOT_ADMISSION_U32_BYTE1 1u
#define ER_BOOT_ADMISSION_U32_BYTE2 2u
#define ER_BOOT_ADMISSION_U32_BYTE3 3u

static const UINT8 g_er_boot_admission_record_hash_domain[] = "edgerun:c:v1:boot-admission-record";

static void er_boot_admission_put_be16(UINT8* dst, UINT16 value) {
  dst[ER_BOOT_ADMISSION_U16_BYTE0] = (UINT8)(value >> ER_BOOT_ADMISSION_U16_HIGH_SHIFT);
  dst[ER_BOOT_ADMISSION_U16_BYTE1] = (UINT8)(value & ER_BOOT_ADMISSION_BYTE_MASK);
}

static void er_boot_admission_put_be32(UINT8* dst, UINT32 value) {
  dst[ER_BOOT_ADMISSION_U32_BYTE0] = (UINT8)(value >> ER_BOOT_ADMISSION_U32_SHIFT0);
  dst[ER_BOOT_ADMISSION_U32_BYTE1] = (UINT8)((value >> ER_BOOT_ADMISSION_U32_SHIFT1) &
                                             ER_BOOT_ADMISSION_BYTE_MASK);
  dst[ER_BOOT_ADMISSION_U32_BYTE2] = (UINT8)((value >> ER_BOOT_ADMISSION_U32_SHIFT2) &
                                             ER_BOOT_ADMISSION_BYTE_MASK);
  dst[ER_BOOT_ADMISSION_U32_BYTE3] = (UINT8)(value & ER_BOOT_ADMISSION_BYTE_MASK);
}

static UINT16 er_boot_admission_get_be16(const UINT8* src) {
  return (UINT16)(((UINT16)src[ER_BOOT_ADMISSION_U16_BYTE0] << ER_BOOT_ADMISSION_U16_HIGH_SHIFT) |
                  (UINT16)src[ER_BOOT_ADMISSION_U16_BYTE1]);
}

static UINT32 er_boot_admission_get_be32(const UINT8* src) {
  return ((UINT32)src[ER_BOOT_ADMISSION_U32_BYTE0] << ER_BOOT_ADMISSION_U32_SHIFT0) |
         ((UINT32)src[ER_BOOT_ADMISSION_U32_BYTE1] << ER_BOOT_ADMISSION_U32_SHIFT1) |
         ((UINT32)src[ER_BOOT_ADMISSION_U32_BYTE2] << ER_BOOT_ADMISSION_U32_SHIFT2) |
         (UINT32)src[ER_BOOT_ADMISSION_U32_BYTE3];
}

void er_boot_admission_record_clear(ErBootAdmissionRecord* record) {
  if (record == 0) {
    return;
  }
  er_mem_zero((UINT8*)record, (UINTN)sizeof(*record));
}

UINT8 er_boot_admission_channel_valid(UINT8 channel_kind) {
  switch (channel_kind) {
    case ER_BOOT_BOOTSTRAP_CHANNEL_NONE:
    case ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH:
    case ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN:
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_boot_admission_record_base_valid(const ErBootAdmissionRecord* record) {
  if (record == 0 ||
      record->magic != ER_BOOT_ADMISSION_RECORD_MAGIC ||
      record->abi_version != ER_BOOT_ADMISSION_RECORD_ABI_VERSION ||
      record->record_size != ER_BOOT_ADMISSION_RECORD_BYTES ||
      record->generation == 0u ||
      record->reserved != 0u ||
      er_boot_admission_channel_valid(record->bootstrap_channel_kind) == 0u) {
    return 0u;
  }

  switch (record->admission_mode) {
    case ER_BOOT_ADMISSION_MODE_LOCAL:
      if (record->admission_identity.identity_type != 0u ||
          record->admission_identity.backing_type != 0u ||
          record->admission_identity.material_len != 0u ||
          record->admission_identity.reserved != 0u ||
          er_mem_any_nonzero(record->admission_identity.material,
                             ER_IDENTITY_MATERIAL_MAX) != 0u) {
        return 0u;
      }
      return 1u;
    case ER_BOOT_ADMISSION_MODE_EXTERNAL:
      return er_identity_valid(&record->admission_identity);
    default:
      return 0u;
  }
}

static UINT8 er_boot_admission_record_prepare_common(const ErCryptoProvider* crypto,
                                                     UINT32 generation,
                                                     UINT8 admission_mode,
                                                     UINT8 bootstrap_channel_kind,
                                                     UINT16 bootstrap_pci_vendor_id,
                                                     UINT16 bootstrap_pci_device_id,
                                                     const ErIdentity* admission_identity,
                                                     ErBootAdmissionRecord* out_record) {
  ErHash record_hash;

  if (out_record == 0 ||
      generation == 0u ||
      er_boot_admission_channel_valid(bootstrap_channel_kind) == 0u) {
    return 0u;
  }

  er_boot_admission_record_clear(out_record);
  out_record->magic = ER_BOOT_ADMISSION_RECORD_MAGIC;
  out_record->abi_version = ER_BOOT_ADMISSION_RECORD_ABI_VERSION;
  out_record->record_size = ER_BOOT_ADMISSION_RECORD_BYTES;
  out_record->generation = generation;
  out_record->admission_mode = admission_mode;
  out_record->bootstrap_channel_kind = bootstrap_channel_kind;
  out_record->bootstrap_pci_vendor_id = bootstrap_pci_vendor_id;
  out_record->bootstrap_pci_device_id = bootstrap_pci_device_id;

  switch (admission_mode) {
    case ER_BOOT_ADMISSION_MODE_LOCAL:
      break;
    case ER_BOOT_ADMISSION_MODE_EXTERNAL:
      if (er_identity_valid(admission_identity) == 0u) {
        er_boot_admission_record_clear(out_record);
        return 0u;
      }
      out_record->admission_identity = *admission_identity;
      break;
    default:
      er_boot_admission_record_clear(out_record);
      return 0u;
  }

  if (er_boot_admission_record_hash(crypto, out_record, &record_hash) == 0u) {
    er_boot_admission_record_clear(out_record);
    return 0u;
  }
  out_record->record_hash = record_hash;
  return 1u;
}

UINT8 er_boot_admission_record_prepare_local(const ErCryptoProvider* crypto,
                                             UINT32 generation,
                                             UINT8 bootstrap_channel_kind,
                                             UINT16 bootstrap_pci_vendor_id,
                                             UINT16 bootstrap_pci_device_id,
                                             ErBootAdmissionRecord* out_record) {
  return er_boot_admission_record_prepare_common(crypto,
                                                 generation,
                                                 ER_BOOT_ADMISSION_MODE_LOCAL,
                                                 bootstrap_channel_kind,
                                                 bootstrap_pci_vendor_id,
                                                 bootstrap_pci_device_id,
                                                 0,
                                                 out_record);
}

UINT8 er_boot_admission_record_prepare_external(const ErCryptoProvider* crypto,
                                                UINT32 generation,
                                                UINT8 bootstrap_channel_kind,
                                                UINT16 bootstrap_pci_vendor_id,
                                                UINT16 bootstrap_pci_device_id,
                                                const ErIdentity* admission_identity,
                                                ErBootAdmissionRecord* out_record) {
  return er_boot_admission_record_prepare_common(crypto,
                                                 generation,
                                                 ER_BOOT_ADMISSION_MODE_EXTERNAL,
                                                 bootstrap_channel_kind,
                                                 bootstrap_pci_vendor_id,
                                                 bootstrap_pci_device_id,
                                                 admission_identity,
                                                 out_record);
}

UINT8 er_boot_admission_record_encode(const ErBootAdmissionRecord* record,
                                      UINT8 out_bytes[ER_BOOT_ADMISSION_RECORD_BYTES]) {
  if (record == 0 || out_bytes == 0) {
    return 0u;
  }

  er_mem_zero(out_bytes, ER_BOOT_ADMISSION_RECORD_BYTES);
  er_boot_admission_put_be32(&out_bytes[ER_BOOT_ADMISSION_RECORD_MAGIC_OFFSET], record->magic);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_ABI_OFFSET], record->abi_version);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_SIZE_OFFSET], record->record_size);
  er_boot_admission_put_be32(&out_bytes[ER_BOOT_ADMISSION_RECORD_GENERATION_OFFSET], record->generation);
  out_bytes[ER_BOOT_ADMISSION_RECORD_MODE_OFFSET] = record->admission_mode;
  out_bytes[ER_BOOT_ADMISSION_RECORD_CHANNEL_OFFSET] = record->bootstrap_channel_kind;
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_VENDOR_OFFSET],
                             record->bootstrap_pci_vendor_id);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_DEVICE_OFFSET],
                             record->bootstrap_pci_device_id);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_RESERVED_OFFSET], record->reserved);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_TYPE_OFFSET],
                             record->admission_identity.identity_type);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_BACKING_OFFSET],
                             record->admission_identity.backing_type);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_LEN_OFFSET],
                             record->admission_identity.material_len);
  er_boot_admission_put_be16(&out_bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_RESERVED_OFFSET],
                             record->admission_identity.reserved);
  er_mem_copy(&out_bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_MATERIAL_OFFSET],
              record->admission_identity.material,
              ER_IDENTITY_MATERIAL_MAX);
  er_mem_copy(&out_bytes[ER_BOOT_ADMISSION_RECORD_HASH_OFFSET],
              record->record_hash.bytes,
              ER_HASH_LEN);
  return 1u;
}

UINT8 er_boot_admission_record_decode(const UINT8 bytes[ER_BOOT_ADMISSION_RECORD_BYTES],
                                      ErBootAdmissionRecord* out_record) {
  if (bytes == 0 || out_record == 0) {
    return 0u;
  }

  er_boot_admission_record_clear(out_record);
  out_record->magic = er_boot_admission_get_be32(&bytes[ER_BOOT_ADMISSION_RECORD_MAGIC_OFFSET]);
  out_record->abi_version = er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_ABI_OFFSET]);
  out_record->record_size = er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_SIZE_OFFSET]);
  out_record->generation = er_boot_admission_get_be32(&bytes[ER_BOOT_ADMISSION_RECORD_GENERATION_OFFSET]);
  out_record->admission_mode = bytes[ER_BOOT_ADMISSION_RECORD_MODE_OFFSET];
  out_record->bootstrap_channel_kind = bytes[ER_BOOT_ADMISSION_RECORD_CHANNEL_OFFSET];
  out_record->bootstrap_pci_vendor_id = er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_VENDOR_OFFSET]);
  out_record->bootstrap_pci_device_id = er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_DEVICE_OFFSET]);
  out_record->reserved = er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_RESERVED_OFFSET]);
  out_record->admission_identity.identity_type =
    er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_TYPE_OFFSET]);
  out_record->admission_identity.backing_type =
    er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_BACKING_OFFSET]);
  out_record->admission_identity.material_len =
    er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_LEN_OFFSET]);
  out_record->admission_identity.reserved =
    er_boot_admission_get_be16(&bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_RESERVED_OFFSET]);
  er_mem_copy(out_record->admission_identity.material,
              &bytes[ER_BOOT_ADMISSION_RECORD_IDENTITY_MATERIAL_OFFSET],
              ER_IDENTITY_MATERIAL_MAX);
  er_mem_copy(out_record->record_hash.bytes,
              &bytes[ER_BOOT_ADMISSION_RECORD_HASH_OFFSET],
              ER_HASH_LEN);
  return 1u;
}

UINT8 er_boot_admission_record_hash(const ErCryptoProvider* crypto,
                                    const ErBootAdmissionRecord* record,
                                    ErHash* out_hash) {
  UINT8 encoded[ER_BOOT_ADMISSION_RECORD_BYTES];
  ErByteSpan span;

  if (crypto == 0 || out_hash == 0 ||
      er_boot_admission_record_base_valid(record) == 0u ||
      er_boot_admission_record_encode(record, encoded) == 0u) {
    return 0u;
  }

  span.bytes = encoded;
  span.len = ER_BOOT_ADMISSION_RECORD_HASHED_BYTES;
  return er_crypto_hash(crypto,
                        g_er_boot_admission_record_hash_domain,
                        (UINTN)(sizeof(g_er_boot_admission_record_hash_domain) - 1u),
                        &span,
                        1u,
                        out_hash);
}

UINT8 er_boot_admission_record_valid(const ErCryptoProvider* crypto,
                                     const ErBootAdmissionRecord* record) {
  ErHash expected_hash;

  if (er_boot_admission_record_base_valid(record) == 0u ||
      er_hash_nonzero(&record->record_hash) == 0u ||
      er_boot_admission_record_hash(crypto, record, &expected_hash) == 0u ||
      er_hash_equal(&expected_hash, &record->record_hash) == 0u) {
    return 0u;
  }
  return 1u;
}

const char* er_boot_admission_mode_label(UINT8 admission_mode) {
  switch (admission_mode) {
    case ER_BOOT_ADMISSION_MODE_LOCAL:
      return "local";
    case ER_BOOT_ADMISSION_MODE_EXTERNAL:
      return "external";
    default:
      return "invalid";
  }
}

const char* er_boot_bootstrap_channel_label(UINT8 channel_kind) {
  switch (channel_kind) {
    case ER_BOOT_BOOTSTRAP_CHANNEL_NONE:
      return "none";
    case ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH:
      return "native-eth";
    case ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN:
      return "wifi-open-edgerun";
    default:
      return "invalid";
  }
}
