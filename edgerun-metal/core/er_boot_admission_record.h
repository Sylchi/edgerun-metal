#ifndef ER_BOOT_ADMISSION_RECORD_H
#define ER_BOOT_ADMISSION_RECORD_H

/*
 * Purpose: describe the minimal durable boot authority choice.
 * Intention: keep first boot bound to one local authority plus a bootstrap channel.
 */

#include "er_crypto.h"
#include "er_credential.h"

#define ER_BOOT_ADMISSION_RECORD_ABI_VERSION 1u
#define ER_BOOT_ADMISSION_RECORD_MAGIC 0x45524252u
#define ER_BOOT_ADMISSION_RECORD_BYTES 144u
#define ER_BOOT_ADMISSION_RECORD_HASHED_BYTES 112u

#define ER_BOOT_ADMISSION_MODE_LOCAL 1u

#define ER_BOOT_BOOTSTRAP_CHANNEL_NONE 0u
#define ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH 1u
#define ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN 2u

typedef struct {
  UINT32 magic;
  UINT16 abi_version;
  UINT16 record_size;
  UINT32 generation;
  UINT8 admission_mode;
  UINT8 bootstrap_channel_kind;
  UINT16 bootstrap_pci_vendor_id;
  UINT16 bootstrap_pci_device_id;
  UINT16 reserved;
  ErCredential admission_identity;
  ErHash record_hash;
} ErBootAdmissionRecord;

void er_boot_admission_record_clear(ErBootAdmissionRecord* record);
UINT8 er_boot_admission_channel_valid(UINT8 channel_kind);
UINT8 er_boot_admission_record_prepare(const ErCryptoProvider* crypto,
                                       UINT32 generation,
                                       UINT8 bootstrap_channel_kind,
                                       UINT16 bootstrap_pci_vendor_id,
                                       UINT16 bootstrap_pci_device_id,
                                       ErBootAdmissionRecord* out_record);
UINT8 er_boot_admission_record_hash(const ErCryptoProvider* crypto,
                                    const ErBootAdmissionRecord* record,
                                    ErHash* out_hash);
UINT8 er_boot_admission_record_valid(const ErCryptoProvider* crypto,
                                     const ErBootAdmissionRecord* record);
UINT8 er_boot_admission_record_encode(const ErBootAdmissionRecord* record,
                                      UINT8 out_bytes[ER_BOOT_ADMISSION_RECORD_BYTES]);
UINT8 er_boot_admission_record_decode(const UINT8 bytes[ER_BOOT_ADMISSION_RECORD_BYTES],
                                      ErBootAdmissionRecord* out_record);
const char* er_boot_admission_mode_label(UINT8 admission_mode);
const char* er_boot_bootstrap_channel_label(UINT8 channel_kind);

#endif
