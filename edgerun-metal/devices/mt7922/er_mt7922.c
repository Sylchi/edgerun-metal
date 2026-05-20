#include "er_mt7922.h"

UINT8 er_mt7922_pci_id_supported(UINT32 id) {
  UINT16 vendor = er_pci_vendor_id(id);
  UINT16 device = er_pci_device_id(id);

  if (vendor != ER_MT7922_PCI_VENDOR_MEDIATEK) {
    return 0u;
  }

  switch (device) {
    case ER_MT7922_PCI_DEVICE_MT7922_RZ616:
      return 1u;
    default:
      return 0u;
  }
}

void er_mt7922_clear_pci_device(ErMt7922PciDevice* device) {
  if (device == 0) {
    return;
  }

  device->supported = 0u;
  device->bar_index = ER_PCI_BAR_INVALID_INDEX;
  device->device_id = 0u;
  device->mmio_base = 0u;
}

void er_mt7922_clear_boot_device(ErMt7922BootDevice* device) {
  if (device == 0) {
    return;
  }

  er_mt7922_clear_pci_device(&device->pci);
  er_firmware_loader_clear_image(&device->firmware);
}

UINT8 er_mt7922_prepare_pci_device(const ErPciDeviceSnapshot* snapshot,
                                   ErMt7922PciDevice* out_device) {
  ErPciBarSelection mmio;

  er_mt7922_clear_pci_device(out_device);
  if (snapshot == 0 || out_device == 0) {
    return 0u;
  }

  if (snapshot->present == 0u || er_mt7922_pci_id_supported(snapshot->id) == 0u) {
    return 0u;
  }

  mmio = er_pci_select_first_mmio_bar(snapshot->bars);
  if (mmio.found == 0u) {
    return 0u;
  }

  out_device->supported = 1u;
  out_device->bar_index = mmio.index;
  out_device->device_id = er_pci_device_id(snapshot->id);
  out_device->mmio_base = mmio.info.base;
  return 1u;
}

UINT8 er_mt7922_prepare_boot_device(const ErCryptoProvider* crypto,
                                    const ErBootConfig* config,
                                    const ErPciDeviceSnapshot* snapshot,
                                    ErFirmwareReadFn read_fn,
                                    void* read_ctx,
                                    UINT8* firmware_bytes,
                                    UINTN firmware_capacity,
                                    ErMt7922BootDevice* out_device) {
  ErMt7922PciDevice pci;

  er_mt7922_clear_boot_device(out_device);
  if (out_device == 0 ||
      er_mt7922_prepare_pci_device(snapshot, &pci) == 0u ||
      er_firmware_loader_load_for_pci(crypto,
                                      config,
                                      ER_MT7922_PCI_VENDOR_MEDIATEK,
                                      pci.device_id,
                                      read_fn,
                                      read_ctx,
                                      firmware_bytes,
                                      firmware_capacity,
                                      &out_device->firmware) == 0u) {
    er_mt7922_clear_boot_device(out_device);
    return 0u;
  }

  out_device->pci = pci;
  return 1u;
}
