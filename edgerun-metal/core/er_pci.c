#include "er_pci.h"

/*
 * Purpose: implement x86 PCI config-space access and pure BAR register decoding.
 * Intention: support safe device discovery first; BAR sizing and writes stay explicit later work.
 */

#define ER_PCI_CONFIG_ADDRESS_PORT 0x0cf8u
#define ER_PCI_CONFIG_DATA_PORT 0x0cfcu
#define ER_PCI_CONFIG_ADDRESS_ENABLE 0x80000000u
#define ER_PCI_CONFIG_MAX_BUS 255
#define ER_PCI_CONFIG_MAX_DEV 31
#define ER_PCI_CONFIG_MAX_FUNC 7
#define ER_PCI_CONFIG_MAX_OFFSET 252
#define ER_PCI_CONFIG_DWORD_ALIGN_MASK 0x3u
#define ER_PCI_CONFIG_BUS_SHIFT 16u
#define ER_PCI_CONFIG_DEV_SHIFT 11u
#define ER_PCI_CONFIG_FUNC_SHIFT 8u
#define ER_PCI_INVALID_ID 0xffffffffu
#define ER_PCI_INVALID_VENDOR_ID 0xffffu
#define ER_PCI_VENDOR_ID_MASK 0xffffu
#define ER_PCI_CLASS_CODE_SHIFT 24u
#define ER_PCI_SUBCLASS_SHIFT 16u
#define ER_PCI_REG_BYTE_MASK 0xffu
#define ER_PCI_HEADER_MULTIFUNCTION_BIT 0x00800000u
#define ER_PCI_NVIDIA_VENDOR_ID 0x10deu
#define ER_PCI_CLASS_MASS_STORAGE 0x01u
#define ER_PCI_SUBCLASS_NVME 0x08u
#define ER_PCI_CLASS_NETWORK 0x02u
#define ER_PCI_SUBCLASS_ETHERNET 0x00u
#define ER_PCI_CLASS_DISPLAY 0x03u
#define ER_PCI_BAR_IO_SPACE_BIT 0x1u
#define ER_PCI_BAR_IO_BASE_MASK 0xfffffffcu
#define ER_PCI_BAR_MEM_TYPE_SHIFT 1u
#define ER_PCI_BAR_MEM_TYPE_MASK 0x3u
#define ER_PCI_BAR_PREFETCH_SHIFT 3u
#define ER_PCI_BAR_PREFETCH_MASK 0x1u
#define ER_PCI_BAR_MEM_TYPE_32 0x0u
#define ER_PCI_BAR_MEM_TYPE_64 0x2u
#define ER_PCI_BAR_MMIO_BASE_MASK 0xfffffff0u
#define ER_PCI_BAR_HIGH_SHIFT 32u

static inline UINT32 er_in32(UINT16 port) {
  UINT32 value = 0;
  __asm__ __volatile__("inl %1, %0" : "=a"(value) : "Nd"(port));
  return value;
}

static inline void er_out32(UINT16 port, UINT32 value) {
  __asm__ __volatile__("outl %0, %1" : : "a"(value), "Nd"(port));
}

UINT8 er_pci_config_access_valid(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i) {
  if (bus_i < 0 || bus_i > ER_PCI_CONFIG_MAX_BUS) {
    return 0;
  }

  if (dev_i < 0 || dev_i > ER_PCI_CONFIG_MAX_DEV) {
    return 0;
  }

  if (func_i < 0 || func_i > ER_PCI_CONFIG_MAX_FUNC) {
    return 0;
  }

  if (offset_i < 0 || offset_i > ER_PCI_CONFIG_MAX_OFFSET) {
    return 0;
  }

  if (((UINT32)offset_i & ER_PCI_CONFIG_DWORD_ALIGN_MASK) != 0u) {
    return 0;
  }

  return 1;
}

INT64 er_pci_config_address(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i) {
  UINT32 bus;
  UINT32 dev;
  UINT32 func;
  UINT32 offset;
  UINT32 address;

  if (er_pci_config_access_valid(bus_i, dev_i, func_i, offset_i) == 0u) {
    return -1;
  }

  bus = (UINT32)bus_i;
  dev = (UINT32)dev_i;
  func = (UINT32)func_i;
  offset = (UINT32)offset_i;
  address = (UINT32)(ER_PCI_CONFIG_ADDRESS_ENABLE | (bus << ER_PCI_CONFIG_BUS_SHIFT) |
                     (dev << ER_PCI_CONFIG_DEV_SHIFT) | (func << ER_PCI_CONFIG_FUNC_SHIFT) | offset);
  return (INT64)address;
}

INT64 er_pci_read32(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i) {
  INT64 address = er_pci_config_address(bus_i, dev_i, func_i, offset_i);

  if (address < 0) {
    return -1;
  }

  er_out32((UINT16)ER_PCI_CONFIG_ADDRESS_PORT, (UINT32)address);
  return (INT64)(UINT32)er_in32((UINT16)ER_PCI_CONFIG_DATA_PORT);
}

void er_pci_write32(INT64 bus_i, INT64 dev_i, INT64 func_i, INT64 offset_i, INT64 value_i) {
  INT64 address = er_pci_config_address(bus_i, dev_i, func_i, offset_i);

  if (address < 0) {
    return;
  }

  er_out32((UINT16)ER_PCI_CONFIG_ADDRESS_PORT, (UINT32)address);
  er_out32((UINT16)ER_PCI_CONFIG_DATA_PORT, (UINT32)value_i);
}

UINT32 er_pci_cfg_read32(UINT32 bus, UINT32 dev, UINT32 func, UINT32 offset) {
  INT64 value = er_pci_read32((INT64)bus, (INT64)dev, (INT64)func, (INT64)offset);

  if (value < 0) {
    return ER_PCI_INVALID_ID;
  }

  return (UINT32)value;
}

UINT8 er_pci_device_present(UINT32 id) {
  UINT16 vendor = er_pci_vendor_id(id);

  if (id == ER_PCI_INVALID_ID || vendor == ER_PCI_INVALID_VENDOR_ID) {
    return 0;
  }

  return 1;
}

UINT16 er_pci_vendor_id(UINT32 id) {
  return (UINT16)(id & ER_PCI_VENDOR_ID_MASK);
}

UINT8 er_pci_class_code(UINT32 class_rev) {
  return (UINT8)((class_rev >> ER_PCI_CLASS_CODE_SHIFT) & ER_PCI_REG_BYTE_MASK);
}

UINT8 er_pci_subclass(UINT32 class_rev) {
  return (UINT8)((class_rev >> ER_PCI_SUBCLASS_SHIFT) & ER_PCI_REG_BYTE_MASK);
}

UINT8 er_pci_header_multifunction(UINT32 header_cacheline) {
  return (UINT8)((header_cacheline & ER_PCI_HEADER_MULTIFUNCTION_BIT) != 0u);
}

UINT32 er_pci_function_count(UINT32 header_cacheline) {
  if (er_pci_header_multifunction(header_cacheline) != 0u) {
    return ER_PCI_FUNCTION_COUNT;
  }

  return ER_PCI_SINGLE_FUNCTION_COUNT;
}

UINT8 er_pci_command_io_enabled(UINT32 command_status) {
  return (UINT8)((command_status & ER_PCI_COMMAND_IO_SPACE) != 0u);
}

UINT8 er_pci_command_memory_enabled(UINT32 command_status) {
  return (UINT8)((command_status & ER_PCI_COMMAND_MEMORY_SPACE) != 0u);
}

UINT8 er_pci_command_bus_master_enabled(UINT32 command_status) {
  return (UINT8)((command_status & ER_PCI_COMMAND_BUS_MASTER) != 0u);
}

UINT8 er_pci_classify_target(UINT32 id, UINT32 class_rev) {
  UINT16 vendor = er_pci_vendor_id(id);
  UINT8 class_code = er_pci_class_code(class_rev);
  UINT8 subclass = er_pci_subclass(class_rev);

  if (er_pci_device_present(id) == 0u) {
    return ER_PCI_TARGET_KIND_NONE;
  }

  if (vendor == ER_PCI_NVIDIA_VENDOR_ID) {
    return ER_PCI_TARGET_KIND_NVIDIA;
  }

  if (class_code == ER_PCI_CLASS_MASS_STORAGE && subclass == ER_PCI_SUBCLASS_NVME) {
    return ER_PCI_TARGET_KIND_NVME;
  }

  if (class_code == ER_PCI_CLASS_NETWORK && subclass == ER_PCI_SUBCLASS_ETHERNET) {
    return ER_PCI_TARGET_KIND_ETHERNET;
  }

  if (class_code == ER_PCI_CLASS_DISPLAY) {
    return ER_PCI_TARGET_KIND_DISPLAY;
  }

  return ER_PCI_TARGET_KIND_NONE;
}

UINT8 er_pci_bar_is_mmio(const ErPciBarInfo* info) {
  if (info == 0) {
    return 0;
  }

  if (info->base == 0u) {
    return 0;
  }

  return (UINT8)(info->kind == ER_PCI_BAR_KIND_MMIO32 || info->kind == ER_PCI_BAR_KIND_MMIO64);
}

ErPciBarInfo er_pci_decode_bar(UINT32 bar_low, UINT32 bar_high) {
  ErPciBarInfo info;
  UINT32 memory_type;

  info.kind = ER_PCI_BAR_KIND_NONE;
  info.base = 0;
  info.prefetchable = 0;

  if (bar_low == 0u || bar_low == ER_PCI_INVALID_ID) {
    return info;
  }

  if ((bar_low & ER_PCI_BAR_IO_SPACE_BIT) != 0u) {
    info.kind = ER_PCI_BAR_KIND_IO;
    info.base = (UINT64)(bar_low & ER_PCI_BAR_IO_BASE_MASK);
    return info;
  }

  memory_type = (bar_low >> ER_PCI_BAR_MEM_TYPE_SHIFT) & ER_PCI_BAR_MEM_TYPE_MASK;
  info.prefetchable = (UINT8)((bar_low >> ER_PCI_BAR_PREFETCH_SHIFT) & ER_PCI_BAR_PREFETCH_MASK);

  if (memory_type == ER_PCI_BAR_MEM_TYPE_32) {
    info.kind = ER_PCI_BAR_KIND_MMIO32;
    info.base = (UINT64)(bar_low & ER_PCI_BAR_MMIO_BASE_MASK);
    return info;
  }

  if (memory_type == ER_PCI_BAR_MEM_TYPE_64) {
    info.kind = ER_PCI_BAR_KIND_MMIO64;
    info.base = ((UINT64)bar_high << ER_PCI_BAR_HIGH_SHIFT) | (UINT64)(bar_low & ER_PCI_BAR_MMIO_BASE_MASK);
    return info;
  }

  return info;
}

ErPciBarInfo er_pci_decode_bar_at(const UINT32* bars, UINT32 index) {
  UINT32 high = 0;

  if (bars == 0 || index >= ER_PCI_BAR_COUNT) {
    return er_pci_decode_bar(0u, 0u);
  }

  if (index + 1u < ER_PCI_BAR_COUNT) {
    high = bars[index + 1u];
  }

  return er_pci_decode_bar(bars[index], high);
}

//@optimizer-ignore-function PCI BAR selection must walk the fixed six-register BAR layout and skip 64-bit pairs
ErPciBarSelection er_pci_select_first_mmio_bar(const UINT32* bars) {
  ErPciBarSelection selection;
  UINT32 index = 0;

  selection.found = 0;
  selection.index = ER_PCI_BAR_INVALID_INDEX;
  selection.info.kind = ER_PCI_BAR_KIND_NONE;
  selection.info.base = 0;
  selection.info.prefetchable = 0;

  if (bars == 0) {
    return selection;
  }

  while (index < ER_PCI_BAR_COUNT) {
    ErPciBarInfo info = er_pci_decode_bar_at(bars, index);

    if (er_pci_bar_is_mmio(&info) != 0u) {
      selection.found = 1;
      selection.index = (UINT8)index;
      selection.info.kind = info.kind;
      selection.info.base = info.base;
      selection.info.prefetchable = info.prefetchable;
      return selection;
    }

    if (info.kind == ER_PCI_BAR_KIND_MMIO64 && index + 1u < ER_PCI_BAR_COUNT) {
      index += 2u;
    } else {
      index += 1u;
    }
  }

  return selection;
}

void er_pci_clear_snapshot(ErPciDeviceSnapshot* snapshot) {
  UINT32 i;

  if (snapshot == 0) {
    return;
  }

  snapshot->present = 0;
  snapshot->bus = 0;
  snapshot->dev = 0;
  snapshot->func = 0;
  snapshot->id = ER_PCI_INVALID_ID;
  snapshot->command_status = ER_PCI_INVALID_ID;
  snapshot->class_revision = ER_PCI_INVALID_ID;
  snapshot->header_cacheline = ER_PCI_INVALID_ID;
  for (i = 0; i < ER_PCI_BAR_COUNT; ++i) {
    snapshot->bars[i] = 0;
  }
}

//@optimizer-ignore-function PCI snapshot must read each config-space BAR register from hardware
UINT8 er_pci_read_snapshot(UINT32 bus, UINT32 dev, UINT32 func, ErPciDeviceSnapshot* out_snapshot) {
  UINT32 i;

  if (out_snapshot == 0) {
    return 0;
  }

  er_pci_clear_snapshot(out_snapshot);

  if (er_pci_config_access_valid((INT64)bus, (INT64)dev, (INT64)func, 0) == 0u) {
    return 0;
  }

  out_snapshot->bus = bus;
  out_snapshot->dev = dev;
  out_snapshot->func = func;
  out_snapshot->id = er_pci_cfg_read32(bus, dev, func, ER_PCI_ID_OFFSET);
  if (er_pci_device_present(out_snapshot->id) == 0u) {
    return 0;
  }

  out_snapshot->present = 1;
  out_snapshot->command_status = er_pci_cfg_read32(bus, dev, func, ER_PCI_COMMAND_STATUS_OFFSET);
  out_snapshot->class_revision = er_pci_cfg_read32(bus, dev, func, ER_PCI_CLASS_REVISION_OFFSET);
  out_snapshot->header_cacheline = er_pci_cfg_read32(bus, dev, func, ER_PCI_HEADER_CACHELINE_OFFSET);
  for (i = 0; i < ER_PCI_BAR_COUNT; ++i) {
    out_snapshot->bars[i] = er_pci_cfg_read32(bus, dev, func, ER_PCI_BAR0_OFFSET + (i * ER_PCI_BAR_STRIDE));
  }

  return 1;
}
