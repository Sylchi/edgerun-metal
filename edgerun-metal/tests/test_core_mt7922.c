#include "test_core_internal.h"

static void test_mt7922_pci_prepare(void) {
  ErPciDeviceSnapshot snapshot;
  ErMt7922PciDevice device;
  UINT32 i;

  er_pci_clear_snapshot(&snapshot);
  for (i = 0u; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot.bars[i] = 0u;
  }

  check_int64("mt7922 unsupported null id", er_mt7922_pci_id_supported(0xffffffffu), 0);
  check_int64("mt7922 unsupported vendor", er_mt7922_pci_id_supported(0x061610ecu), 0);
  check_int64("mt7922 unsupported mediatek mt7921 id",
              er_mt7922_pci_id_supported(0x796114c3u), 0);
  check_int64("mt7922 supported rz616", er_mt7922_pci_id_supported(0x061614c3u), 1);

  device.supported = 99u;
  device.bar_index = 99u;
  device.device_id = 99u;
  device.mmio_base = 99u;
  er_mt7922_clear_pci_device(&device);
  check_int64("mt7922 clear supported", device.supported, 0);
  check_int64("mt7922 clear bar", device.bar_index, ER_PCI_BAR_INVALID_INDEX);
  check_int64("mt7922 clear device", device.device_id, 0);
  check_uint64("mt7922 clear mmio", device.mmio_base, 0u);

  check_int64("mt7922 prepare reject null snapshot",
              er_mt7922_prepare_pci_device(0, &device), 0);
  check_int64("mt7922 prepare reject null output",
              er_mt7922_prepare_pci_device(&snapshot, 0), 0);

  snapshot.present = 1u;
  snapshot.id = 0x061614c3u;
  check_int64("mt7922 prepare reject no mmio",
              er_mt7922_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[0] = 0x0000d001u;
  check_int64("mt7922 prepare reject io bar",
              er_mt7922_prepare_pci_device(&snapshot, &device), 0);

  snapshot.bars[0] = 0xfedc0000u;
  check_int64("mt7922 prepare rz616", er_mt7922_prepare_pci_device(&snapshot, &device), 1);
  check_int64("mt7922 prepare supported", device.supported, 1);
  check_int64("mt7922 prepare bar", device.bar_index, 0u);
  check_int64("mt7922 prepare device", device.device_id, ER_MT7922_PCI_DEVICE_MT7922_RZ616);
  check_uint64("mt7922 prepare mmio", device.mmio_base, 0xfedc0000u);
}
