#ifndef ER_IWLWIFI_H
#define ER_IWLWIFI_H

/*
 * Purpose: identify Intel iwlwifi PCI devices we can observe locally.
 * Intention: stage AX210 firmware handoff without committing to a full MAC driver yet.
 */

#include "er_firmware_loader.h"
#include "er_pci.h"
#include "er_types.h"

#define ER_IWLWIFI_PCI_VENDOR_INTEL 0x8086u
#define ER_IWLWIFI_PCI_DEVICE_AX210 0x2725u
#define ER_IWLWIFI_FIRMWARE_INSTANCE_UCODE 0u
#define ER_IWLWIFI_FIRMWARE_INSTANCE_PNVM 1u

typedef struct {
  UINT8 supported;
  UINT8 bar_index;
  UINT16 device_id;
  UINT64 mmio_base;
} ErIwlwifiPciDevice;

typedef struct {
  ErIwlwifiPciDevice pci;
  ErFirmwareImage ucode;
  ErFirmwareImage pnvm;
} ErIwlwifiBootDevice;

UINT8 er_iwlwifi_pci_id_supported(UINT32 id);
void er_iwlwifi_clear_pci_device(ErIwlwifiPciDevice* device);
UINT8 er_iwlwifi_prepare_pci_device(const ErPciDeviceSnapshot* snapshot,
                                    ErIwlwifiPciDevice* out_device);
void er_iwlwifi_clear_boot_device(ErIwlwifiBootDevice* device);
UINT8 er_iwlwifi_prepare_ax210_boot_device(const ErCryptoProvider* crypto,
                                           const ErBootConfig* config,
                                           const ErPciDeviceSnapshot* snapshot,
                                           ErFirmwareReadFn read_fn,
                                           void* read_ctx,
                                           UINT8* ucode_bytes,
                                           UINTN ucode_capacity,
                                           UINT8* pnvm_bytes,
                                           UINTN pnvm_capacity,
                                           ErIwlwifiBootDevice* out_device);

#endif
