#include "er_virtio.h"
#include "er_mem.h"

/*
 * Purpose: implement VirtIO MMIO register access and split-queue helpers.
 * Intention: make the first native device-driver path testable before adding device policy.
 */

#define ER_VIRTIO_MMIO_MIN_LEN 0x200u
#define ER_VIRTIO_FEATURE_SEL_LOW 0u
#define ER_VIRTIO_FEATURE_SEL_HIGH 1u
#define ER_VIRTIO_U64_HIGH_SHIFT 32u
#define ER_VIRTIO_U32_MASK 0xffffffffull
#define ER_VIRTIO_PCI_CAP_PTR_OFFSET 0x34u
#define ER_VIRTIO_PCI_CAP_MIN_OFFSET 0x40u
#define ER_VIRTIO_PCI_CAP_GUARD_MAX 48u
#define ER_VIRTIO_PCI_CAP_NEXT_MASK 0xfcu
#define ER_VIRTIO_PCI_CAP_VENDOR_OFFSET 0u
#define ER_VIRTIO_PCI_CAP_NEXT_OFFSET 1u
#define ER_VIRTIO_PCI_CAP_LEN_OFFSET 2u
#define ER_VIRTIO_PCI_CAP_CFG_TYPE_OFFSET 3u
#define ER_VIRTIO_PCI_CAP_BAR_OFFSET 4u
#define ER_VIRTIO_PCI_CAP_OFFSET_OFFSET 8u
#define ER_VIRTIO_PCI_CAP_LENGTH_OFFSET 12u
#define ER_VIRTIO_PCI_CAP_NOTIFY_MULT_OFFSET 16u
#define ER_VIRTIO_PCI_CAP_BASE_LEN 16u
#define ER_VIRTIO_PCI_NOTIFY_CAP_LEN 20u
#define ER_VIRTIO_PCI_BAR_COUNT 6u
#define ER_VIRTIO_PCI_ID_NET ER_VIRTIO_MODERN_DEVICE_ID_NET
#define ER_VIRTIO_PCI_ID_BLK ER_VIRTIO_MODERN_DEVICE_ID_BLK
#define ER_VIRTIO_PCI_ID_CONSOLE ER_VIRTIO_MODERN_DEVICE_ID_CONSOLE
#define ER_VIRTIO_PCI_ID_RNG ER_VIRTIO_MODERN_DEVICE_ID_RNG
#define ER_VIRTIO_PCI_ID_GPU ER_VIRTIO_MODERN_DEVICE_ID_GPU
#define ER_VIRTIO_PCI_COMMON_DEVICE_FEATURE_SELECT_OFFSET 0u
#define ER_VIRTIO_PCI_COMMON_DEVICE_FEATURE_OFFSET 4u
#define ER_VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT_OFFSET 8u
#define ER_VIRTIO_PCI_COMMON_DRIVER_FEATURE_OFFSET 12u
#define ER_VIRTIO_PCI_COMMON_DEVICE_STATUS_OFFSET 20u
#define ER_VIRTIO_PCI_COMMON_QUEUE_SELECT_OFFSET 22u
#define ER_VIRTIO_PCI_COMMON_QUEUE_SIZE_OFFSET 24u
#define ER_VIRTIO_PCI_COMMON_QUEUE_ENABLE_OFFSET 28u
#define ER_VIRTIO_PCI_COMMON_QUEUE_NOTIFY_OFF_OFFSET 30u
#define ER_VIRTIO_PCI_COMMON_QUEUE_DESC_OFFSET 32u
#define ER_VIRTIO_PCI_COMMON_QUEUE_DRIVER_OFFSET 40u
#define ER_VIRTIO_PCI_COMMON_QUEUE_DEVICE_OFFSET 48u
#define ER_VIRTIO_PCI_NOTIFY_VALUE_BYTES 2u
#define ER_VIRTIO_PCI_BAR_WINDOW_LEN 0x1000u

static void er_virtio_fence(void) {
#if defined(__GNUC__) || defined(__clang__)
  __atomic_thread_fence(__ATOMIC_SEQ_CST);
#endif
}

static UINT32 er_virtio_low32(UINT64 value) {
  return (UINT32)(value & ER_VIRTIO_U32_MASK);
}

static UINT32 er_virtio_high32(UINT64 value) {
  return (UINT32)(value >> ER_VIRTIO_U64_HIGH_SHIFT);
}

static UINT8 er_virtio_device_type_from_pci_id(UINT32 device_id, UINT32* out_device_type) {
  if (out_device_type == 0) {
    return 0;
  }
  switch (device_id) {
    case ER_VIRTIO_PCI_ID_NET:
      *out_device_type = ER_VIRTIO_DEVICE_TYPE_NET;
      return 1;
    case ER_VIRTIO_PCI_ID_BLK:
      *out_device_type = ER_VIRTIO_DEVICE_TYPE_BLK;
      return 1;
    case ER_VIRTIO_PCI_ID_CONSOLE:
      *out_device_type = ER_VIRTIO_DEVICE_TYPE_CONSOLE;
      return 1;
    case ER_VIRTIO_PCI_ID_RNG:
      *out_device_type = ER_VIRTIO_DEVICE_TYPE_RNG;
      return 1;
    case ER_VIRTIO_PCI_ID_GPU:
      *out_device_type = ER_VIRTIO_DEVICE_TYPE_GPU;
      return 1;
    default:
      *out_device_type = 0;
      return 0;
  }
}

static UINT8 er_virtio_cfg_read8(UINT32 bus, UINT32 dev, UINT32 func, UINT32 offset) {
  UINT32 value = er_pci_cfg_read32(bus, dev, func, offset & ~0x3u);
  return (UINT8)((value >> ((offset & 0x3u) * 8u)) & 0xffu);
}

static UINT32 er_virtio_cfg_read32(UINT32 bus, UINT32 dev, UINT32 func, UINT32 offset) {
  return er_pci_cfg_read32(bus, dev, func, offset);
}

static void er_virtio_enable_pci_device(UINT32 bus, UINT32 dev, UINT32 func) {
  UINT32 command_status = er_pci_cfg_read32(bus, dev, func, ER_PCI_COMMAND_STATUS_OFFSET);

  er_pci_write32((INT64)bus, (INT64)dev, (INT64)func, (INT64)ER_PCI_COMMAND_STATUS_OFFSET,
                 (INT64)(command_status | ER_PCI_COMMAND_MEMORY_SPACE | ER_PCI_COMMAND_BUS_MASTER));
}

static UINT8 er_virtio_pci_cap_prepare_address(UINT32 bus, UINT32 dev, UINT32 func,
                                               ErVirtioPciCap* cap) {
  ErPciDeviceSnapshot snapshot;
  ErPciBarInfo bar;
  UINT64 len;

  if (cap == 0 || cap->present == 0u || cap->bar >= ER_VIRTIO_PCI_BAR_COUNT) {
    return 0;
  }
  if (er_pci_read_snapshot(bus, dev, func, &snapshot) == 0u) {
    return 0;
  }
  bar = er_pci_decode_bar_at(snapshot.bars, cap->bar);
  if (er_pci_bar_is_mmio(&bar) == 0u) {
    return 0;
  }
  len = (cap->length == 0u || cap->length > ER_VIRTIO_PCI_BAR_WINDOW_LEN) ?
      ER_VIRTIO_PCI_BAR_WINDOW_LEN : (UINT64)cap->length;
  return er_bus_prepare_mmio32_address(bar.base + (UINT64)cap->offset, len, cap->bar,
                                       ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                       &cap->address);
}

static UINT8 er_virtio_pci_read_caps(UINT32 bus, UINT32 dev, UINT32 func,
                                     ErVirtioMmioTransport* out_transport) {
  UINT8 cap_ptr;
  UINT32 guard = 0;

  if (out_transport == 0) {
    return 0;
  }
  cap_ptr = (UINT8)(er_virtio_cfg_read8(bus, dev, func, ER_VIRTIO_PCI_CAP_PTR_OFFSET) &
                   ER_VIRTIO_PCI_CAP_NEXT_MASK);
  while (cap_ptr >= ER_VIRTIO_PCI_CAP_MIN_OFFSET && guard < ER_VIRTIO_PCI_CAP_GUARD_MAX) {
    UINT8 cap_vendor = er_virtio_cfg_read8(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_VENDOR_OFFSET);
    UINT8 cap_next = (UINT8)(er_virtio_cfg_read8(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_NEXT_OFFSET) &
                             ER_VIRTIO_PCI_CAP_NEXT_MASK);
    UINT8 cap_len = er_virtio_cfg_read8(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_LEN_OFFSET);

    if (cap_vendor == ER_VIRTIO_PCI_CAP_VENDOR && cap_len >= ER_VIRTIO_PCI_CAP_BASE_LEN) {
      ErVirtioPciCap cap;

      er_mem_zero((UINT8*)&cap, (UINTN)sizeof(cap));
      cap.present = 1u;
      cap.cfg_type = er_virtio_cfg_read8(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_CFG_TYPE_OFFSET);
      cap.bar = er_virtio_cfg_read8(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_BAR_OFFSET);
      cap.offset = er_virtio_cfg_read32(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_OFFSET_OFFSET);
      cap.length = er_virtio_cfg_read32(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_LENGTH_OFFSET);
      if (cap.cfg_type == ER_VIRTIO_PCI_CAP_NOTIFY_CFG && cap_len >= ER_VIRTIO_PCI_NOTIFY_CAP_LEN) {
        cap.notify_off_multiplier =
            er_virtio_cfg_read32(bus, dev, func, cap_ptr + ER_VIRTIO_PCI_CAP_NOTIFY_MULT_OFFSET);
      }
      switch (cap.cfg_type) {
        case ER_VIRTIO_PCI_CAP_COMMON_CFG:
          out_transport->common = cap;
          break;
        case ER_VIRTIO_PCI_CAP_NOTIFY_CFG:
          out_transport->notify = cap;
          break;
        case ER_VIRTIO_PCI_CAP_DEVICE_CFG:
          out_transport->device = cap;
          break;
        case ER_VIRTIO_PCI_CAP_ISR_CFG:
          out_transport->isr = cap;
          break;
        default:
          break;
      }
    }
    if (cap_next == 0u) {
      break;
    }
    cap_ptr = cap_next;
    ++guard;
  }
  return (UINT8)(out_transport->common.present != 0u && out_transport->notify.present != 0u);
}

static UINT8 er_virtio_common_read8(const ErVirtioMmioTransport* transport, UINT64 offset, UINT8* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_bus_read8(&transport->common.address, offset, out_value);
  }
  return er_bus_read8(&transport->address, offset, out_value);
}

static UINT8 er_virtio_common_read16(const ErVirtioMmioTransport* transport, UINT64 offset, UINT16* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_bus_read16(&transport->common.address, offset, out_value);
  }
  return er_bus_read16(&transport->address, offset, out_value);
}

static UINT8 er_virtio_common_read32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_bus_read32(&transport->common.address, offset, out_value);
  }
  return er_bus_read32(&transport->address, offset, out_value);
}

static UINT8 er_virtio_common_write8(const ErVirtioMmioTransport* transport, UINT64 offset, UINT8 value) {
  if (transport == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_bus_write8(&transport->common.address, offset, value);
  }
  return er_bus_write8(&transport->address, offset, value);
}

static UINT8 er_virtio_common_write16(const ErVirtioMmioTransport* transport, UINT64 offset, UINT16 value) {
  if (transport == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_bus_write16(&transport->common.address, offset, value);
  }
  return er_bus_write16(&transport->address, offset, value);
}

static UINT8 er_virtio_common_write32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32 value) {
  if (transport == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_bus_write32(&transport->common.address, offset, value);
  }
  return er_bus_write32(&transport->address, offset, value);
}

static UINT8 er_virtio_common_write64(const ErVirtioMmioTransport* transport, UINT64 offset, UINT64 value) {
  if (transport == 0) {
    return 0;
  }
  return (UINT8)(er_bus_write32(&transport->common.address, offset, er_virtio_low32(value)) != 0u &&
                 er_bus_write32(&transport->common.address, offset + sizeof(UINT32), er_virtio_high32(value)) != 0u);
}

static UINT8 er_virtio_mmio_set_failed(const ErVirtioMmioTransport* transport) {
  UINT8 status = 0;

  if (er_virtio_mmio_read_status(transport, &status) == 0u) {
    return 0;
  }
  return er_virtio_mmio_write_status(transport, (UINT8)(status | ER_VIRTIO_STATUS_FAILED));
}

UINT8 er_virtio_mmio_transport_init(UINT64 base, UINT64 len, UINT32 expected_device_type,
                                    ErVirtioMmioTransport* out_transport) {
  ErBusAddress address;
  UINT32 magic = 0;
  UINT32 version = 0;
  UINT32 device_type = 0;
  UINT32 vendor = 0;

  if (out_transport == 0 || len < ER_VIRTIO_MMIO_MIN_LEN) {
    return 0;
  }
  er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
  if (er_bus_prepare_mmio32_address(base, len, 0u, ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL,
                                    &address) == 0u) {
    return 0;
  }
  out_transport->address = address;
  if (er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_MAGIC_VALUE_OFFSET, &magic) == 0u ||
      er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_VERSION_OFFSET, &version) == 0u ||
      er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_DEVICE_ID_OFFSET, &device_type) == 0u ||
      er_virtio_mmio_read32(out_transport, ER_VIRTIO_MMIO_VENDOR_OFFSET, &vendor) == 0u) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
    return 0;
  }
  if (magic != ER_VIRTIO_MMIO_MAGIC || version != ER_VIRTIO_MMIO_VERSION_MODERN ||
      device_type == 0u ||
      (expected_device_type != 0u && device_type != expected_device_type)) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
    return 0;
  }
  out_transport->device_type = device_type;
  out_transport->vendor_id = vendor;
  out_transport->transport_kind = ER_VIRTIO_TRANSPORT_KIND_MMIO;
  return 1;
}

UINT8 er_virtio_pci_transport_init(UINT32 bus, UINT32 dev, UINT32 func,
                                   UINT32 expected_device_type,
                                   ErVirtioMmioTransport* out_transport) {
  UINT32 id;
  UINT32 vendor;
  UINT32 device_id;
  UINT32 device_type = 0;

  if (out_transport == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
  if (er_pci_config_access_valid((INT64)bus, (INT64)dev, (INT64)func, 0) == 0u) {
    return 0;
  }
  id = er_pci_cfg_read32(bus, dev, func, ER_PCI_ID_OFFSET);
  if (er_pci_device_present(id) == 0u) {
    return 0;
  }
  vendor = er_pci_vendor_id(id);
  device_id = (id >> 16u) & 0xffffu;
  if (vendor != ER_VIRTIO_VENDOR_ID ||
      er_virtio_device_type_from_pci_id(device_id, &device_type) == 0u ||
      (expected_device_type != 0u && device_type != expected_device_type)) {
    return 0;
  }
  out_transport->transport_kind = ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI;
  out_transport->bus = bus;
  out_transport->dev = dev;
  out_transport->func = func;
  out_transport->device_type = device_type;
  out_transport->vendor_id = vendor;
  if (er_virtio_pci_read_caps(bus, dev, func, out_transport) == 0u ||
      er_virtio_pci_cap_prepare_address(bus, dev, func, &out_transport->common) == 0u ||
      er_virtio_pci_cap_prepare_address(bus, dev, func, &out_transport->notify) == 0u ||
      (out_transport->device.present != 0u &&
       er_virtio_pci_cap_prepare_address(bus, dev, func, &out_transport->device) == 0u) ||
      (out_transport->isr.present != 0u &&
       er_virtio_pci_cap_prepare_address(bus, dev, func, &out_transport->isr) == 0u)) {
    er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
    return 0;
  }
  er_virtio_enable_pci_device(bus, dev, func);
  return 1;
}

UINT8 er_virtio_pci_find_transport(UINT32 expected_device_type,
                                   ErVirtioMmioTransport* out_transport) {
  UINT32 bus;
  UINT32 dev;

  if (out_transport == 0 || expected_device_type == 0u) {
    return 0;
  }
  for (bus = 0u; bus < ER_PCI_BUS_COUNT; ++bus) {
    for (dev = 0u; dev < ER_PCI_DEVICE_COUNT; ++dev) {
      UINT32 id0 = er_pci_cfg_read32(bus, dev, 0u, ER_PCI_ID_OFFSET);
      UINT32 header0;
      UINT32 max_func;
      UINT32 func;

      if (er_pci_device_present(id0) == 0u) {
        continue;
      }
      header0 = er_pci_cfg_read32(bus, dev, 0u, ER_PCI_HEADER_CACHELINE_OFFSET);
      max_func = er_pci_function_count(header0);
      for (func = 0u; func < max_func; ++func) {
        if (er_virtio_pci_transport_init(bus, dev, func, expected_device_type, out_transport) != 0u) {
          return 1;
        }
      }
    }
  }
  er_mem_zero((UINT8*)out_transport, (UINTN)sizeof(*out_transport));
  return 0;
}

UINT8 er_virtio_mmio_read32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  return er_bus_read32(&transport->address, offset, out_value);
}

UINT8 er_virtio_mmio_write32(const ErVirtioMmioTransport* transport, UINT64 offset, UINT32 value) {
  if (transport == 0) {
    return 0;
  }
  return er_bus_write32(&transport->address, offset, value);
}

UINT8 er_virtio_mmio_read_features(const ErVirtioMmioTransport* transport, UINT64* out_features) {
  UINT32 low = 0;
  UINT32 high = 0;

  if (transport == 0 || out_features == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    if (er_virtio_common_write32(transport, ER_VIRTIO_PCI_COMMON_DEVICE_FEATURE_SELECT_OFFSET,
                                ER_VIRTIO_FEATURE_SEL_LOW) == 0u ||
        er_virtio_common_read32(transport, ER_VIRTIO_PCI_COMMON_DEVICE_FEATURE_OFFSET, &low) == 0u ||
        er_virtio_common_write32(transport, ER_VIRTIO_PCI_COMMON_DEVICE_FEATURE_SELECT_OFFSET,
                                ER_VIRTIO_FEATURE_SEL_HIGH) == 0u ||
        er_virtio_common_read32(transport, ER_VIRTIO_PCI_COMMON_DEVICE_FEATURE_OFFSET, &high) == 0u) {
      return 0;
    }
    *out_features = (UINT64)low | ((UINT64)high << ER_VIRTIO_U64_HIGH_SHIFT);
    return 1;
  }
  if (er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_SEL_OFFSET,
                            ER_VIRTIO_FEATURE_SEL_LOW) == 0u ||
      er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET, &low) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_SEL_OFFSET,
                            ER_VIRTIO_FEATURE_SEL_HIGH) == 0u ||
      er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_DEVICE_FEATURES_OFFSET, &high) == 0u) {
    return 0;
  }
  *out_features = (UINT64)low | ((UINT64)high << ER_VIRTIO_U64_HIGH_SHIFT);
  return 1;
}

UINT8 er_virtio_mmio_write_driver_features(const ErVirtioMmioTransport* transport, UINT64 features) {
  if (transport == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return (UINT8)(er_virtio_common_write32(transport, ER_VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT_OFFSET,
                                           ER_VIRTIO_FEATURE_SEL_LOW) != 0u &&
                   er_virtio_common_write32(transport, ER_VIRTIO_PCI_COMMON_DRIVER_FEATURE_OFFSET,
                                           er_virtio_low32(features)) != 0u &&
                   er_virtio_common_write32(transport, ER_VIRTIO_PCI_COMMON_DRIVER_FEATURE_SELECT_OFFSET,
                                           ER_VIRTIO_FEATURE_SEL_HIGH) != 0u &&
                   er_virtio_common_write32(transport, ER_VIRTIO_PCI_COMMON_DRIVER_FEATURE_OFFSET,
                                           er_virtio_high32(features)) != 0u);
  }
  return (UINT8)(er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET,
                                       ER_VIRTIO_FEATURE_SEL_LOW) != 0u &&
                 er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET,
                                       er_virtio_low32(features)) != 0u &&
                 er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_SEL_OFFSET,
                                       ER_VIRTIO_FEATURE_SEL_HIGH) != 0u &&
                 er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_DRIVER_FEATURES_OFFSET,
                                       er_virtio_high32(features)) != 0u);
}

UINT8 er_virtio_mmio_read_status(const ErVirtioMmioTransport* transport, UINT8* out_status) {
  UINT32 status = 0;

  if (transport != 0 && transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_virtio_common_read8(transport, ER_VIRTIO_PCI_COMMON_DEVICE_STATUS_OFFSET, out_status);
  }
  if (out_status == 0 || er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_STATUS_OFFSET, &status) == 0u) {
    return 0;
  }
  *out_status = (UINT8)status;
  return 1;
}

UINT8 er_virtio_mmio_write_status(const ErVirtioMmioTransport* transport, UINT8 status) {
  if (transport != 0 && transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    return er_virtio_common_write8(transport, ER_VIRTIO_PCI_COMMON_DEVICE_STATUS_OFFSET, status);
  }
  return er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_STATUS_OFFSET, (UINT32)status);
}

UINT8 er_virtio_config_read8(const ErVirtioMmioTransport* transport, UINT64 offset, UINT8* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    if (transport->device.present == 0u) {
      return 0;
    }
    return er_bus_read8(&transport->device.address, offset, out_value);
  }
  return er_bus_read8(&transport->address, ER_VIRTIO_MMIO_CONFIG_OFFSET + offset, out_value);
}

UINT8 er_virtio_config_read16(const ErVirtioMmioTransport* transport, UINT64 offset, UINT16* out_value) {
  if (transport == 0 || out_value == 0) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    if (transport->device.present == 0u) {
      return 0;
    }
    return er_bus_read16(&transport->device.address, offset, out_value);
  }
  return er_bus_read16(&transport->address, ER_VIRTIO_MMIO_CONFIG_OFFSET + offset, out_value);
}

UINT8 er_virtio_mmio_negotiate_features(const ErVirtioMmioTransport* transport, UINT64 supported_features,
                                        ErVirtioFeatureSet* out_features) {
  UINT64 host = 0;
  UINT64 driver = 0;
  UINT8 status = 0;

  if (transport == 0 || out_features == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_features, (UINTN)sizeof(*out_features));
  if (er_virtio_mmio_write_status(transport, 0u) == 0u ||
      er_virtio_mmio_write_status(transport, ER_VIRTIO_STATUS_ACKNOWLEDGE) == 0u ||
      er_virtio_mmio_write_status(transport, ER_VIRTIO_STATUS_ACKNOWLEDGE | ER_VIRTIO_STATUS_DRIVER) == 0u ||
      er_virtio_mmio_read_features(transport, &host) == 0u) {
    return 0;
  }
  driver = host & supported_features;
  if ((driver & ER_VIRTIO_F_VERSION_1) == 0u) {
    (void)er_virtio_mmio_set_failed(transport);
    return 0;
  }
  if (er_virtio_mmio_write_driver_features(transport, driver) == 0u ||
      er_virtio_mmio_read_status(transport, &status) == 0u ||
      er_virtio_mmio_write_status(transport, (UINT8)(status | ER_VIRTIO_STATUS_FEATURES_OK)) == 0u ||
      er_virtio_mmio_read_status(transport, &status) == 0u) {
    return 0;
  }
  if ((status & ER_VIRTIO_STATUS_FEATURES_OK) == 0u) {
    (void)er_virtio_mmio_set_failed(transport);
    return 0;
  }
  out_features->host = host;
  out_features->driver = driver;
  return 1;
}

UINT8 er_virtio_mmio_configure_split_queue(const ErVirtioMmioTransport* transport, UINT16 queue,
                                           UINT16 max_queue_size, UINT16 min_queue_size,
                                           UINT64 desc, UINT64 driver, UINT64 device,
                                           UINT16* out_queue_size) {
  UINT32 host_queue_size = 0;
  UINT16 queue_size;

  if (transport == 0 || out_queue_size == 0 || max_queue_size == 0u ||
      min_queue_size == 0u || min_queue_size > max_queue_size ||
      desc == 0u || driver == 0u || device == 0u) {
    return 0;
  }
  *out_queue_size = 0;
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    UINT16 host_queue_size16 = 0;

    if (er_virtio_common_write16(transport, ER_VIRTIO_PCI_COMMON_QUEUE_SELECT_OFFSET, queue) == 0u ||
        er_virtio_common_read16(transport, ER_VIRTIO_PCI_COMMON_QUEUE_SIZE_OFFSET, &host_queue_size16) == 0u) {
      return 0;
    }
    host_queue_size = host_queue_size16;
  } else if (er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_SEL_OFFSET, (UINT32)queue) == 0u ||
             er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_QUEUE_NUM_MAX_OFFSET, &host_queue_size) == 0u) {
    return 0;
  }
  queue_size = (host_queue_size < (UINT32)max_queue_size) ? (UINT16)host_queue_size : max_queue_size;
  if (queue_size < min_queue_size) {
    return 0;
  }
  if (transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    if (er_virtio_common_write16(transport, ER_VIRTIO_PCI_COMMON_QUEUE_SIZE_OFFSET, queue_size) == 0u ||
        er_virtio_common_write64(transport, ER_VIRTIO_PCI_COMMON_QUEUE_DESC_OFFSET, desc) == 0u ||
        er_virtio_common_write64(transport, ER_VIRTIO_PCI_COMMON_QUEUE_DRIVER_OFFSET, driver) == 0u ||
        er_virtio_common_write64(transport, ER_VIRTIO_PCI_COMMON_QUEUE_DEVICE_OFFSET, device) == 0u ||
        er_virtio_common_write16(transport, ER_VIRTIO_PCI_COMMON_QUEUE_ENABLE_OFFSET, 1u) == 0u) {
      return 0;
    }
    *out_queue_size = queue_size;
    return 1;
  }
  if (er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_NUM_OFFSET, (UINT32)queue_size) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DESC_LOW_OFFSET, er_virtio_low32(desc)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DESC_HIGH_OFFSET, er_virtio_high32(desc)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DRIVER_LOW_OFFSET, er_virtio_low32(driver)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DRIVER_HIGH_OFFSET, er_virtio_high32(driver)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DEVICE_LOW_OFFSET, er_virtio_low32(device)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_DEVICE_HIGH_OFFSET, er_virtio_high32(device)) == 0u ||
      er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_READY_OFFSET, 1u) == 0u) {
    return 0;
  }
  *out_queue_size = queue_size;
  return 1;
}

UINT8 er_virtio_mmio_notify_queue(const ErVirtioMmioTransport* transport, UINT16 queue) {
  if (transport != 0 && transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    UINT16 queue_notify_off = 0;
    UINT64 notify_offset;

    if (er_virtio_common_write16(transport, ER_VIRTIO_PCI_COMMON_QUEUE_SELECT_OFFSET, queue) == 0u ||
        er_virtio_common_read16(transport, ER_VIRTIO_PCI_COMMON_QUEUE_NOTIFY_OFF_OFFSET,
                               &queue_notify_off) == 0u) {
      return 0;
    }
    notify_offset = (UINT64)queue_notify_off * (UINT64)transport->notify.notify_off_multiplier;
    return er_bus_write16(&transport->notify.address, notify_offset, queue);
  }
  return er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_QUEUE_NOTIFY_OFFSET, (UINT32)queue);
}

UINT8 er_virtio_mmio_take_interrupt_status(const ErVirtioMmioTransport* transport, UINT8* out_status) {
  UINT32 status = 0;

  if (transport != 0 && transport->transport_kind == ER_VIRTIO_TRANSPORT_KIND_MODERN_PCI) {
    if (out_status == 0) {
      return 0;
    }
    *out_status = 0u;
    if (transport->isr.present == 0u) {
      return 1;
    }
    return er_bus_read8(&transport->isr.address, 0u, out_status);
  }
  if (out_status == 0 || er_virtio_mmio_read32(transport, ER_VIRTIO_MMIO_INTERRUPT_STATUS_OFFSET, &status) == 0u) {
    return 0;
  }
  *out_status = (UINT8)status;
  if (*out_status == 0u) {
    return 1;
  }
  return er_virtio_mmio_write32(transport, ER_VIRTIO_MMIO_INTERRUPT_ACK_OFFSET, (UINT32)*out_status);
}

void er_virtio_queue_clear(ErVirtioQueueDesc* desc, ErVirtioQueueAvail* avail,
                           ErVirtioQueueUsed* used) {
  if (desc != 0) {
    er_mem_zero((UINT8*)desc, (UINTN)(sizeof(ErVirtioQueueDesc) * ER_VIRTIO_QUEUE_SIZE));
  }
  if (avail != 0) {
    er_mem_zero((UINT8*)avail, (UINTN)sizeof(*avail));
  }
  if (used != 0) {
    er_mem_zero((UINT8*)used, (UINTN)sizeof(*used));
  }
}

UINT8 er_virtio_queue_post_descriptor(ErVirtioQueueAvail* avail, UINT16 queue_size, UINT16 desc_id) {
  UINT16 idx;

  if (avail == 0 || queue_size == 0u || queue_size > ER_VIRTIO_QUEUE_SIZE || desc_id >= queue_size) {
    return 0;
  }
  idx = avail->idx;
  avail->ring[(UINTN)(idx % queue_size)] = desc_id;
  er_virtio_fence();
  avail->idx = (UINT16)(idx + 1u);
  return 1;
}

UINT16 er_virtio_queue_used_idx(const ErVirtioQueueUsed* used) {
  if (used == 0) {
    return 0;
  }
  return used->idx;
}

UINT8 er_virtio_queue_take_next_used(const ErVirtioQueueUsed* used, UINT16 queue_size,
                                     UINT16* last_used_idx, ErVirtioQueueUsedElem* out_elem) {
  UINT16 used_idx;
  UINT16 ring_idx;

  if (used == 0 || last_used_idx == 0 || out_elem == 0 ||
      queue_size == 0u || queue_size > ER_VIRTIO_QUEUE_SIZE) {
    return 0;
  }
  used_idx = er_virtio_queue_used_idx(used);
  if (used_idx == *last_used_idx) {
    return 0;
  }
  ring_idx = (UINT16)(*last_used_idx % queue_size);
  *out_elem = used->ring[ring_idx];
  *last_used_idx = (UINT16)(*last_used_idx + 1u);
  return 1;
}
