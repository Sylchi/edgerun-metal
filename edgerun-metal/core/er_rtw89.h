#ifndef ER_RTW89_H
#define ER_RTW89_H

/*
 * Purpose: identify Realtek rtw89 PCI Wi-Fi devices before firmware and DMA bring-up.
 * Intention: keep first-packet work staged behind explicit PCI ID and BAR2 proofs.
 */

#include "er_pci.h"
#include "er_types.h"

#define ER_RTW89_PCI_VENDOR_REALTEK 0x10ecu
#define ER_RTW89_PCI_DEVICE_RTL8922AE 0x8922u
#define ER_RTW89_PCI_DEVICE_RTL8922AE_VS 0x892bu
#define ER_RTW89_PCI_MMIO_BAR_INDEX 2u

typedef struct {
  UINT8 supported;
  UINT8 bar_index;
  UINT16 device_id;
  UINT64 mmio_base;
} ErRtw89PciDevice;

UINT8 er_rtw89_pci_id_supported(UINT32 id);
void er_rtw89_clear_pci_device(ErRtw89PciDevice* device);
UINT8 er_rtw89_prepare_pci_device(const ErPciDeviceSnapshot* snapshot, ErRtw89PciDevice* out_device);

#endif
