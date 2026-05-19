#ifndef ER_MT7922_H
#define ER_MT7922_H

/*
 * Purpose: identify MediaTek MT7922/RZ616 PCI Wi-Fi devices before driver bring-up.
 * Intention: let BLE/Wi-Fi burst planning verify usable hardware without binding a full MAC yet.
 */

#include "er_pci.h"
#include "er_types.h"

#define ER_MT7922_PCI_VENDOR_MEDIATEK 0x14c3u
#define ER_MT7922_PCI_DEVICE_MT7922_RZ616 0x0616u

typedef struct {
  UINT8 supported;
  UINT8 bar_index;
  UINT16 device_id;
  UINT64 mmio_base;
} ErMt7922PciDevice;

UINT8 er_mt7922_pci_id_supported(UINT32 id);
void er_mt7922_clear_pci_device(ErMt7922PciDevice* device);
UINT8 er_mt7922_prepare_pci_device(const ErPciDeviceSnapshot* snapshot,
                                   ErMt7922PciDevice* out_device);

#endif
