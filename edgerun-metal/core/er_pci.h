#ifndef ER_PCI_H
#define ER_PCI_H

/*
 * Purpose: provide the minimal PCI config-space and BAR decoding surface used by EdgeRun Metal.
 * Intention: keep PCI mechanics separate from boot profile code so BAR/MMIO work is testable.
 */

#include "er_types.h"

#define ER_PCI_BAR_KIND_NONE 0u
#define ER_PCI_BAR_KIND_IO 1u
#define ER_PCI_BAR_KIND_MMIO32 2u
#define ER_PCI_BAR_KIND_MMIO64 3u

#define ER_PCI_BUS_COUNT 256u
#define ER_PCI_DEVICE_COUNT 32u
#define ER_PCI_FUNCTION_COUNT 8u
#define ER_PCI_SINGLE_FUNCTION_COUNT 1u
#define ER_PCI_ID_OFFSET 0x00u
#define ER_PCI_COMMAND_STATUS_OFFSET 0x04u
#define ER_PCI_CLASS_REVISION_OFFSET 0x08u
#define ER_PCI_HEADER_CACHELINE_OFFSET 0x0cu
#define ER_PCI_BAR0_OFFSET 0x10u
#define ER_PCI_BAR_STRIDE 4u
#define ER_PCI_BAR_COUNT 6u
#define ER_PCI_BAR_INVALID_INDEX 0xffu

#define ER_PCI_COMMAND_IO_SPACE 0x00000001u
#define ER_PCI_COMMAND_MEMORY_SPACE 0x00000002u
#define ER_PCI_COMMAND_BUS_MASTER 0x00000004u

#define ER_PCI_TARGET_KIND_NONE 0u
#define ER_PCI_TARGET_KIND_NVIDIA 1u
#define ER_PCI_TARGET_KIND_NVME 2u
#define ER_PCI_TARGET_KIND_ETHERNET 3u
#define ER_PCI_TARGET_KIND_DISPLAY 4u

typedef struct {
  UINT8 kind;
  UINT64 base;
  UINT8 prefetchable;
} ErPciBarInfo;

typedef struct {
  UINT8 found;
  UINT8 index;
  ErPciBarInfo info;
} ErPciBarSelection;

typedef struct {
  UINT8 present;
  UINT32 bus;
  UINT32 dev;
  UINT32 func;
  UINT32 id;
  UINT32 command_status;
  UINT32 class_revision;
  UINT32 header_cacheline;
  UINT32 bars[ER_PCI_BAR_COUNT];
} ErPciDeviceSnapshot;

UINT8 er_pci_config_access_valid(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i);
INT64 er_pci_config_address(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i);
INT64 er_pci_read32(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i);
void er_pci_write32(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i, INT64 value_i);
UINT32 er_pci_cfg_read32(UINT32 bus, UINT32 dev, UINT32 func, UINT32 offset);
UINT8 er_pci_device_present(UINT32 id);
UINT16 er_pci_vendor_id(UINT32 id);
UINT8 er_pci_class_code(UINT32 class_rev);
UINT8 er_pci_subclass(UINT32 class_rev);
UINT8 er_pci_header_multifunction(UINT32 header_cacheline);
UINT32 er_pci_function_count(UINT32 header_cacheline);
UINT8 er_pci_command_io_enabled(UINT32 command_status);
UINT8 er_pci_command_memory_enabled(UINT32 command_status);
UINT8 er_pci_command_bus_master_enabled(UINT32 command_status);
UINT8 er_pci_classify_target(UINT32 id, UINT32 class_rev);
UINT8 er_pci_bar_is_mmio(const ErPciBarInfo* info);
ErPciBarInfo er_pci_decode_bar(UINT32 bar_low, UINT32 bar_high);
ErPciBarInfo er_pci_decode_bar_at(const UINT32* bars, UINT32 index);
ErPciBarSelection er_pci_select_first_mmio_bar(const UINT32* bars);
void er_pci_clear_snapshot(ErPciDeviceSnapshot* snapshot);
UINT8 er_pci_read_snapshot(UINT32 bus, UINT32 dev, UINT32 func, ErPciDeviceSnapshot* out_snapshot);

#endif
