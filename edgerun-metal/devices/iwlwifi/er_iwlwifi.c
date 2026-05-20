#include "er_iwlwifi.h"

UINT8 er_iwlwifi_pci_id_supported(UINT32 id) {
  UINT16 vendor = er_pci_vendor_id(id);
  UINT16 device = er_pci_device_id(id);

  if (vendor != ER_IWLWIFI_PCI_VENDOR_INTEL) {
    return 0u;
  }

  switch (device) {
    case ER_IWLWIFI_PCI_DEVICE_AX210:
      return 1u;
    default:
      return 0u;
  }
}

void er_iwlwifi_clear_pci_device(ErIwlwifiPciDevice* device) {
  if (device == 0) {
    return;
  }

  device->supported = 0u;
  device->bar_index = ER_PCI_BAR_INVALID_INDEX;
  device->device_id = 0u;
  device->mmio_base = 0u;
}

UINT8 er_iwlwifi_prepare_pci_device(const ErPciDeviceSnapshot* snapshot,
                                    ErIwlwifiPciDevice* out_device) {
  ErPciBarSelection mmio;

  er_iwlwifi_clear_pci_device(out_device);
  if (snapshot == 0 || out_device == 0) {
    return 0u;
  }

  if (snapshot->present == 0u || er_iwlwifi_pci_id_supported(snapshot->id) == 0u) {
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

void er_iwlwifi_clear_boot_device(ErIwlwifiBootDevice* device) {
  if (device == 0) {
    return;
  }

  er_iwlwifi_clear_pci_device(&device->pci);
  er_firmware_loader_clear_image(&device->ucode);
  er_firmware_loader_clear_image(&device->pnvm);
}

UINT8 er_iwlwifi_prepare_ax210_boot_device(const ErCryptoProvider* crypto,
                                           const ErBootConfig* config,
                                           const ErPciDeviceSnapshot* snapshot,
                                           ErFirmwareReadFn read_fn,
                                           void* read_ctx,
                                           UINT8* ucode_bytes,
                                           UINTN ucode_capacity,
                                           UINT8* pnvm_bytes,
                                           UINTN pnvm_capacity,
                                           ErIwlwifiBootDevice* out_device) {
  ErIwlwifiPciDevice pci;

  er_iwlwifi_clear_boot_device(out_device);
  if (out_device == 0 ||
      er_iwlwifi_prepare_pci_device(snapshot, &pci) == 0u ||
      pci.device_id != ER_IWLWIFI_PCI_DEVICE_AX210 ||
      er_firmware_loader_load_for_pci_instance(crypto,
                                               config,
                                               ER_IWLWIFI_PCI_VENDOR_INTEL,
                                               ER_IWLWIFI_PCI_DEVICE_AX210,
                                               ER_IWLWIFI_FIRMWARE_INSTANCE_UCODE,
                                               read_fn,
                                               read_ctx,
                                               ucode_bytes,
                                               ucode_capacity,
                                               &out_device->ucode) == 0u ||
      er_firmware_loader_load_for_pci_instance(crypto,
                                               config,
                                               ER_IWLWIFI_PCI_VENDOR_INTEL,
                                               ER_IWLWIFI_PCI_DEVICE_AX210,
                                               ER_IWLWIFI_FIRMWARE_INSTANCE_PNVM,
                                               read_fn,
                                               read_ctx,
                                               pnvm_bytes,
                                               pnvm_capacity,
                                               &out_device->pnvm) == 0u) {
    er_iwlwifi_clear_boot_device(out_device);
    return 0u;
  }

  out_device->pci = pci;
  return 1u;
}
