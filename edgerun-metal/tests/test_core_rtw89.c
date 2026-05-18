#include "test_core_internal.h"

static void test_rtw89_pci_prepare(void) {
  ErPciDeviceSnapshot snapshot;
  ErRtw89PciDevice device;
  UINT32 i;

  er_pci_clear_snapshot(&snapshot);
  for (i = 0; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot.bars[i] = 0;
  }

  check_int64("rtw89 unsupported null id", er_rtw89_pci_id_supported(0xffffffffu), 0);
  check_int64("rtw89 unsupported vendor", er_rtw89_pci_id_supported(0x89228086u), 0);
  check_int64("rtw89 supported rtl8922ae", er_rtw89_pci_id_supported(0x892210ecu), 1);
  check_int64("rtw89 supported rtl8922ae vs", er_rtw89_pci_id_supported(0x892b10ecu), 1);

  device.supported = 99;
  device.bar_index = 99;
  device.device_id = 99;
  device.mmio_base = 99;
  er_rtw89_clear_pci_device(&device);
  check_int64("rtw89 clear supported", device.supported, 0);
  check_int64("rtw89 clear bar", device.bar_index, ER_PCI_BAR_INVALID_INDEX);
  check_int64("rtw89 clear device", device.device_id, 0);
  check_uint64("rtw89 clear mmio", device.mmio_base, 0);

  check_int64("rtw89 prepare reject null snapshot", er_rtw89_prepare_pci_device(0, &device), 0);
  check_int64("rtw89 prepare reject null output", er_rtw89_prepare_pci_device(&snapshot, 0), 0);

  snapshot.present = 1;
  snapshot.id = 0x892210ecu;
  check_int64("rtw89 prepare reject no bar2", er_rtw89_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0x0000c001u;
  check_int64("rtw89 prepare reject io bar2", er_rtw89_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[ER_RTW89_PCI_MMIO_BAR_INDEX] = 0xfebc0000u;
  check_int64("rtw89 prepare rtl8922ae", er_rtw89_prepare_pci_device(&snapshot, &device), 1);
  check_int64("rtw89 prepare supported", device.supported, 1);
  check_int64("rtw89 prepare bar", device.bar_index, ER_RTW89_PCI_MMIO_BAR_INDEX);
  check_int64("rtw89 prepare device", device.device_id, ER_RTW89_PCI_DEVICE_RTL8922AE);
  check_uint64("rtw89 prepare mmio", device.mmio_base, 0xfebc0000u);

  snapshot.id = 0x892b10ecu;
  check_int64("rtw89 prepare rtl8922ae vs", er_rtw89_prepare_pci_device(&snapshot, &device), 1);
  check_int64("rtw89 prepare vs device", device.device_id, ER_RTW89_PCI_DEVICE_RTL8922AE_VS);
}
