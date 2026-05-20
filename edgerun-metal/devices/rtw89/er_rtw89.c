#include "er_rtw89.h"

UINT8 er_rtw89_pci_id_supported(UINT32 id) {
  UINT16 vendor = er_pci_vendor_id(id);
  UINT16 device = er_pci_device_id(id);

  if (vendor != ER_RTW89_PCI_VENDOR_REALTEK) {
    return 0;
  }

  switch (device) {
    case ER_RTW89_PCI_DEVICE_RTL8922AE:
    case ER_RTW89_PCI_DEVICE_RTL8922AE_VS:
      return 1;
    default:
      return 0;
  }
}

void er_rtw89_clear_pci_device(ErRtw89PciDevice* device) {
  if (device == 0) {
    return;
  }

  device->supported = 0;
  device->bar_index = ER_PCI_BAR_INVALID_INDEX;
  device->device_id = 0;
  device->mmio_base = 0;
}

void er_rtw89_clear_boot_device(ErRtw89BootDevice* device) {
  if (device == 0) {
    return;
  }

  er_rtw89_clear_pci_device(&device->pci);
  er_firmware_loader_clear_image(&device->firmware);
}

UINT8 er_rtw89_prepare_pci_device(const ErPciDeviceSnapshot* snapshot, ErRtw89PciDevice* out_device) {
  ErPciBarInfo mmio;

  er_rtw89_clear_pci_device(out_device);
  if (snapshot == 0 || out_device == 0) {
    return 0;
  }

  if (snapshot->present == 0u || er_rtw89_pci_id_supported(snapshot->id) == 0u) {
    return 0;
  }

  mmio = er_pci_decode_bar_at(snapshot->bars, ER_RTW89_PCI_MMIO_BAR_INDEX);
  if (er_pci_bar_is_mmio(&mmio) == 0u) {
    return 0;
  }

  out_device->supported = 1;
  out_device->bar_index = ER_RTW89_PCI_MMIO_BAR_INDEX;
  out_device->device_id = er_pci_device_id(snapshot->id);
  out_device->mmio_base = mmio.base;
  return 1;
}

UINT8 er_rtw89_prepare_boot_device(const ErCryptoProvider* crypto,
                                   const ErBootConfig* config,
                                   const ErPciDeviceSnapshot* snapshot,
                                   ErFirmwareReadFn read_fn,
                                   void* read_ctx,
                                   UINT8* firmware_bytes,
                                   UINTN firmware_capacity,
                                   ErRtw89BootDevice* out_device) {
  ErRtw89PciDevice pci;

  er_rtw89_clear_boot_device(out_device);
  if (out_device == 0 ||
      er_rtw89_prepare_pci_device(snapshot, &pci) == 0u ||
      er_firmware_loader_load_for_pci(crypto,
                                      config,
                                      ER_RTW89_PCI_VENDOR_REALTEK,
                                      pci.device_id,
                                      read_fn,
                                      read_ctx,
                                      firmware_bytes,
                                      firmware_capacity,
                                      &out_device->firmware) == 0u) {
    er_rtw89_clear_boot_device(out_device);
    return 0u;
  }

  out_device->pci = pci;
  return 1u;
}
