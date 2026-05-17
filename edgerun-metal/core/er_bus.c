#include "er_bus.h"
#include "er_mem.h"

/*
 * Purpose: execute concrete PCI config, MMIO, and I/O port bus operations.
 * Intention: all hardware communication has explicit address, width, operation, and response status.
 */

static inline UINT8 er_bus_in8(UINT16 port) {
  UINT8 value = 0;
  __asm__ __volatile__("inb %1, %0" : "=a"(value) : "Nd"(port));
  return value;
}

static inline UINT16 er_bus_in16(UINT16 port) {
  UINT16 value = 0;
  __asm__ __volatile__("inw %1, %0" : "=a"(value) : "Nd"(port));
  return value;
}

static inline UINT32 er_bus_in32(UINT16 port) {
  UINT32 value = 0;
  __asm__ __volatile__("inl %1, %0" : "=a"(value) : "Nd"(port));
  return value;
}

static inline void er_bus_out8(UINT16 port, UINT8 value) {
  __asm__ __volatile__("outb %0, %1" : : "a"(value), "Nd"(port));
}

static inline void er_bus_out16(UINT16 port, UINT16 value) {
  __asm__ __volatile__("outw %0, %1" : : "a"(value), "Nd"(port));
}

static inline void er_bus_out32(UINT16 port, UINT32 value) {
  __asm__ __volatile__("outl %0, %1" : : "a"(value), "Nd"(port));
}

static UINT8 er_bus_access_valid(UINT32 access_flags) {
  return (UINT8)(access_flags != 0u && (access_flags & ~ER_BUS_ACCESS_ALL) == 0u);
}

static UINT32 er_bus_read_access_for_width(UINT32 width) {
  if (width == 1u) {
    return ER_BUS_ACCESS_READ8;
  }
  if (width == 2u) {
    return ER_BUS_ACCESS_READ16;
  }
  if (width == 4u) {
    return ER_BUS_ACCESS_READ32;
  }
  return 0u;
}

static UINT32 er_bus_write_access_for_width(UINT32 width) {
  if (width == 1u) {
    return ER_BUS_ACCESS_WRITE8;
  }
  if (width == 2u) {
    return ER_BUS_ACCESS_WRITE16;
  }
  if (width == 4u) {
    return ER_BUS_ACCESS_WRITE32;
  }
  return 0u;
}

static UINT8 er_bus_access_is_read(UINT32 access) {
  return (UINT8)(access == ER_BUS_ACCESS_READ8 || access == ER_BUS_ACCESS_READ16 ||
                 access == ER_BUS_ACCESS_READ32);
}

static UINT8 er_bus_access_is_write(UINT32 access) {
  return (UINT8)(access == ER_BUS_ACCESS_WRITE8 || access == ER_BUS_ACCESS_WRITE16 ||
                 access == ER_BUS_ACCESS_WRITE32);
}

static void er_bus_copy_address(ErBusAddress* dst, const ErBusAddress* src) {
  if (dst == 0 || src == 0) {
    return;
  }
  dst->abi_version = src->abi_version;
  dst->bus_kind = src->bus_kind;
  dst->access_flags = src->access_flags;
  dst->bus = src->bus;
  dst->dev = src->dev;
  dst->func = src->func;
  dst->bar_index = src->bar_index;
  dst->port = src->port;
  dst->base = src->base;
  dst->len = src->len;
}

UINT8 er_bus_prepare_pci_config_address(UINT32 bus, UINT32 dev, UINT32 func, UINT32 access_flags,
                                        ErBusAddress* out_address) {
  if (out_address == 0 ||
      er_pci_config_access_valid((INT64)bus, (INT64)dev, (INT64)func, 0) == 0u ||
      er_bus_access_valid(access_flags) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_address, (UINTN)sizeof(*out_address));
  out_address->abi_version = ER_BUS_ABI_VERSION;
  out_address->bus_kind = ER_BUS_KIND_PCI_CONFIG;
  out_address->access_flags = access_flags;
  out_address->bus = bus;
  out_address->dev = dev;
  out_address->func = func;
  out_address->len = 256u;
  return 1;
}

UINT8 er_bus_prepare_io_port_address(UINT32 port, UINT32 access_flags, ErBusAddress* out_address) {
  if (out_address == 0 || port > 0xffffu ||
      er_bus_access_valid(access_flags) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_address, (UINTN)sizeof(*out_address));
  out_address->abi_version = ER_BUS_ABI_VERSION;
  out_address->bus_kind = ER_BUS_KIND_IO_PORT;
  out_address->access_flags = access_flags;
  out_address->port = port;
  out_address->len = 0x10000u - port;
  return 1;
}

UINT8 er_bus_prepare_mmio32_address(UINT64 base, UINT64 len, UINT32 bar_index, UINT32 access_flags,
                                    ErBusAddress* out_address) {
  if (out_address == 0 || base == 0u || len == 0u ||
      er_bus_access_valid(access_flags) == 0u) {
    return 0;
  }
  if (base + len < base || bar_index >= ER_PCI_BAR_COUNT) {
    return 0;
  }

  er_mem_zero((UINT8*)out_address, (UINTN)sizeof(*out_address));
  out_address->abi_version = ER_BUS_ABI_VERSION;
  out_address->bus_kind = ER_BUS_KIND_MMIO32;
  out_address->access_flags = access_flags;
  out_address->bar_index = bar_index;
  out_address->base = base;
  out_address->len = len;
  return 1;
}

UINT8 er_bus_address_supports(const ErBusAddress* address, UINT32 access) {
  if (address == 0 || address->abi_version != ER_BUS_ABI_VERSION || access == 0u ||
      (access & ~ER_BUS_ACCESS_ALL) != 0u) {
    return 0;
  }
  return (UINT8)((address->access_flags & access) == access);
}

UINT8 er_bus_op32_valid(const ErBusOp32* op) {
  if (op == 0 || op->abi_version != ER_BUS_ABI_VERSION || op->bus_kind != op->address.bus_kind) {
    return 0;
  }
  if (er_bus_address_supports(&op->address, op->access) == 0u) {
    return 0;
  }
  if ((op->offset & 0x3u) != 0u) {
    return 0;
  }
  if (op->address.bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    return er_pci_config_access_valid((INT64)op->address.bus, (INT64)op->address.dev,
                                      (INT64)op->address.func, (INT64)op->offset);
  }
  if (op->address.bus_kind == ER_BUS_KIND_MMIO32) {
    return (UINT8)(op->offset < op->address.len && op->address.len - op->offset >= 4u);
  }
  if (op->address.bus_kind == ER_BUS_KIND_IO_PORT) {
    return (UINT8)(op->offset == 0u && op->address.port <= 0xfffcu && (op->address.port & 0x3u) == 0u);
  }
  return 0;
}

UINT8 er_bus_io_op_valid(const ErBusIoOp* op) {
  UINT32 expected_access;

  if (op == 0 || op->abi_version != ER_BUS_ABI_VERSION || op->bus_kind != op->address.bus_kind ||
      (op->width != 1u && op->width != 2u && op->width != 4u)) {
    return 0;
  }
  expected_access = er_bus_access_is_read(op->access) != 0u ?
                    er_bus_read_access_for_width(op->width) :
                    er_bus_write_access_for_width(op->width);
  if (expected_access == 0u || op->access != expected_access ||
      er_bus_address_supports(&op->address, op->access) == 0u) {
    return 0;
  }
  if ((op->offset & (UINT64)(op->width - 1u)) != 0u) {
    return 0;
  }
  if (op->address.bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    if (op->offset > 255u || 256u - op->offset < op->width) {
      return 0;
    }
    return er_pci_config_access_valid((INT64)op->address.bus, (INT64)op->address.dev,
                                      (INT64)op->address.func, (INT64)(op->offset & ~0x3ull));
  }
  if (op->address.bus_kind == ER_BUS_KIND_MMIO32) {
    return (UINT8)(op->offset < op->address.len && op->address.len - op->offset >= op->width);
  }
  if (op->address.bus_kind == ER_BUS_KIND_IO_PORT) {
    UINT64 port = (UINT64)op->address.port + op->offset;
    return (UINT8)(port <= 0xffffu && 0x10000u - port >= op->width);
  }
  return 0;
}

UINT8 er_bus_prepare_op32_packet(UINT64 packet_id, const ErBusAddress* address, UINT32 access,
                                 UINT64 offset, UINT32 value, ErBusPacket32* out_packet) {
  if (out_packet == 0 || address == 0) {
    return 0;
  }

  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  out_packet->abi_version = ER_BUS_ABI_VERSION;
  out_packet->packet_kind = ER_BUS_PACKET_OP32_REQUEST;
  out_packet->status = ER_BUS_STATUS_OK;
  out_packet->packet_id = packet_id;
  out_packet->op.abi_version = ER_BUS_ABI_VERSION;
  out_packet->op.bus_kind = address->bus_kind;
  out_packet->op.access = access;
  er_bus_copy_address(&out_packet->op.address, address);
  out_packet->op.offset = offset;
  out_packet->op.value = value;

  if (er_bus_op32_valid(&out_packet->op) == 0u) {
    out_packet->status = ER_BUS_STATUS_INVALID_OPERATION;
    return 0;
  }
  return 1;
}

static void er_bus_copy_op32(ErBusOp32* dst, const ErBusOp32* src) {
  if (dst == 0 || src == 0) {
    return;
  }
  dst->abi_version = src->abi_version;
  dst->bus_kind = src->bus_kind;
  dst->access = src->access;
  er_bus_copy_address(&dst->address, &src->address);
  dst->offset = src->offset;
  dst->value = src->value;
}

static void er_bus_copy_io_op(ErBusIoOp* dst, const ErBusIoOp* src) {
  if (dst == 0 || src == 0) {
    return;
  }
  dst->abi_version = src->abi_version;
  dst->bus_kind = src->bus_kind;
  dst->access = src->access;
  dst->width = src->width;
  er_bus_copy_address(&dst->address, &src->address);
  dst->offset = src->offset;
  dst->value = src->value;
}

UINT8 er_bus_execute_op32_packet(const ErBusPacket32* request, ErBusPacket32* out_response) {
  UINT32 value = 0;

  if (out_response == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_response, (UINTN)sizeof(*out_response));
  out_response->abi_version = ER_BUS_ABI_VERSION;
  out_response->packet_kind = ER_BUS_PACKET_OP32_RESPONSE;
  out_response->status = ER_BUS_STATUS_INVALID_OPERATION;

  if (request == 0 || request->abi_version != ER_BUS_ABI_VERSION ||
      request->packet_kind != ER_BUS_PACKET_OP32_REQUEST) {
    return 0;
  }

  out_response->packet_id = request->packet_id;
  er_bus_copy_op32(&out_response->op, &request->op);

  if (er_bus_op32_valid(&request->op) == 0u) {
    out_response->status = ER_BUS_STATUS_INVALID_OPERATION;
    return 0;
  }

  if (request->op.access == ER_BUS_ACCESS_READ32) {
    if (er_bus_read32(&request->op.address, request->op.offset, &value) == 0u) {
      out_response->status = ER_BUS_STATUS_IO_FAILED;
      return 0;
    }
    out_response->status = ER_BUS_STATUS_OK;
    out_response->result = value;
    return 1;
  }

  if (request->op.access == ER_BUS_ACCESS_WRITE32) {
    if (er_bus_write32(&request->op.address, request->op.offset, request->op.value) == 0u) {
      out_response->status = ER_BUS_STATUS_IO_FAILED;
      return 0;
    }
    out_response->status = ER_BUS_STATUS_OK;
    out_response->result = request->op.value;
    return 1;
  }

  out_response->status = ER_BUS_STATUS_DENIED;
  return 0;
}

UINT8 er_bus_prepare_io_packet(UINT64 packet_id, const ErBusAddress* address, UINT32 access,
                               UINT32 width, UINT64 offset, UINT32 value, ErBusIoPacket* out_packet) {
  if (out_packet == 0 || address == 0) {
    return 0;
  }

  er_mem_zero((UINT8*)out_packet, (UINTN)sizeof(*out_packet));
  out_packet->abi_version = ER_BUS_ABI_VERSION;
  out_packet->packet_kind = ER_BUS_PACKET_IO_REQUEST;
  out_packet->status = ER_BUS_STATUS_OK;
  out_packet->packet_id = packet_id;
  out_packet->op.abi_version = ER_BUS_ABI_VERSION;
  out_packet->op.bus_kind = address->bus_kind;
  out_packet->op.access = access;
  out_packet->op.width = width;
  er_bus_copy_address(&out_packet->op.address, address);
  out_packet->op.offset = offset;
  out_packet->op.value = value;

  if (er_bus_io_op_valid(&out_packet->op) == 0u) {
    out_packet->status = ER_BUS_STATUS_INVALID_OPERATION;
    return 0;
  }
  return 1;
}

UINT8 er_bus_execute_io_packet(const ErBusIoPacket* request, ErBusIoPacket* out_response) {
  UINT32 value = 0;

  if (out_response == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_response, (UINTN)sizeof(*out_response));
  out_response->abi_version = ER_BUS_ABI_VERSION;
  out_response->packet_kind = ER_BUS_PACKET_IO_RESPONSE;
  out_response->status = ER_BUS_STATUS_INVALID_OPERATION;

  if (request == 0 || request->abi_version != ER_BUS_ABI_VERSION ||
      request->packet_kind != ER_BUS_PACKET_IO_REQUEST) {
    return 0;
  }

  out_response->packet_id = request->packet_id;
  er_bus_copy_io_op(&out_response->op, &request->op);

  if (er_bus_io_op_valid(&request->op) == 0u) {
    out_response->status = ER_BUS_STATUS_INVALID_OPERATION;
    return 0;
  }

  if (er_bus_access_is_read(request->op.access) != 0u) {
    if (request->op.width == 1u) {
      UINT8 read_value = 0;
      if (er_bus_read8(&request->op.address, request->op.offset, &read_value) == 0u) {
        out_response->status = ER_BUS_STATUS_IO_FAILED;
        return 0;
      }
      value = read_value;
    } else if (request->op.width == 2u) {
      UINT16 read_value = 0;
      if (er_bus_read16(&request->op.address, request->op.offset, &read_value) == 0u) {
        out_response->status = ER_BUS_STATUS_IO_FAILED;
        return 0;
      }
      value = read_value;
    } else {
      if (er_bus_read32(&request->op.address, request->op.offset, &value) == 0u) {
        out_response->status = ER_BUS_STATUS_IO_FAILED;
        return 0;
      }
    }
    out_response->status = ER_BUS_STATUS_OK;
    out_response->result = value;
    return 1;
  }

  if (er_bus_access_is_write(request->op.access) != 0u) {
    UINT8 ok;

    if (request->op.width == 1u) {
      ok = er_bus_write8(&request->op.address, request->op.offset, (UINT8)request->op.value);
    } else if (request->op.width == 2u) {
      ok = er_bus_write16(&request->op.address, request->op.offset, (UINT16)request->op.value);
    } else {
      ok = er_bus_write32(&request->op.address, request->op.offset, request->op.value);
    }
    if (ok == 0u) {
      out_response->status = ER_BUS_STATUS_IO_FAILED;
      return 0;
    }
    out_response->status = ER_BUS_STATUS_OK;
    out_response->result = request->op.value;
    return 1;
  }

  out_response->status = ER_BUS_STATUS_DENIED;
  return 0;
}

UINT8 er_bus_read8(const ErBusAddress* address, UINT64 offset, UINT8* out_value) {
  ErBusIoOp op;

  if (out_value == 0 || address == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)&op, (UINTN)sizeof(op));
  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = address->bus_kind;
  op.access = ER_BUS_ACCESS_READ8;
  op.width = 1u;
  er_bus_copy_address(&op.address, address);
  op.offset = offset;
  if (er_bus_io_op_valid(&op) == 0u) {
    return 0;
  }

  if (address->bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    INT64 value = er_pci_read32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                                (INT64)(offset & ~0x3ull));
    if (value < 0) {
      return 0;
    }
    *out_value = (UINT8)(((UINT32)value >> ((UINT32)(offset & 0x3u) * 8u)) & 0xffu);
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_MMIO32) {
    INT64 handle = er_mmio_map((INT64)address->base, (INT64)address->len);
    INT64 value;

    if (handle < 0) {
      return 0;
    }
    value = er_mmio_read8(handle, (INT64)offset);
    if (value < 0) {
      return 0;
    }
    *out_value = (UINT8)value;
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_IO_PORT) {
    *out_value = er_bus_in8((UINT16)(address->port + offset));
    return 1;
  }

  return 0;
}

UINT8 er_bus_read16(const ErBusAddress* address, UINT64 offset, UINT16* out_value) {
  ErBusIoOp op;

  if (out_value == 0 || address == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)&op, (UINTN)sizeof(op));
  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = address->bus_kind;
  op.access = ER_BUS_ACCESS_READ16;
  op.width = 2u;
  er_bus_copy_address(&op.address, address);
  op.offset = offset;
  if (er_bus_io_op_valid(&op) == 0u) {
    return 0;
  }

  if (address->bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    INT64 value = er_pci_read32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                                (INT64)(offset & ~0x3ull));
    if (value < 0) {
      return 0;
    }
    *out_value = (UINT16)(((UINT32)value >> ((UINT32)(offset & 0x2u) * 8u)) & 0xffffu);
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_MMIO32) {
    INT64 handle = er_mmio_map((INT64)address->base, (INT64)address->len);
    INT64 value;

    if (handle < 0) {
      return 0;
    }
    value = er_mmio_read16(handle, (INT64)offset);
    if (value < 0) {
      return 0;
    }
    *out_value = (UINT16)value;
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_IO_PORT) {
    *out_value = er_bus_in16((UINT16)(address->port + offset));
    return 1;
  }

  return 0;
}

UINT8 er_bus_read32(const ErBusAddress* address, UINT64 offset, UINT32* out_value) {
  ErBusOp32 op;

  if (out_value == 0 || address == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)&op, (UINTN)sizeof(op));
  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = address->bus_kind;
  op.access = ER_BUS_ACCESS_READ32;
  er_bus_copy_address(&op.address, address);
  op.offset = offset;
  if (er_bus_op32_valid(&op) == 0u) {
    return 0;
  }

  if (address->bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    INT64 value = er_pci_read32((INT64)address->bus, (INT64)address->dev,
                                (INT64)address->func, (INT64)offset);
    if (value < 0) {
      return 0;
    }
    *out_value = (UINT32)value;
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_MMIO32) {
    INT64 handle = er_mmio_map((INT64)address->base, (INT64)address->len);
    INT64 value;

    if (handle < 0) {
      return 0;
    }
    value = er_mmio_read32(handle, (INT64)offset);
    if (value < 0) {
      return 0;
    }
    *out_value = (UINT32)value;
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_IO_PORT) {
    *out_value = er_bus_in32((UINT16)address->port);
    return 1;
  }

  return 0;
}

UINT8 er_bus_write8(const ErBusAddress* address, UINT64 offset, UINT8 value) {
  ErBusIoOp op;

  if (address == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)&op, (UINTN)sizeof(op));
  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = address->bus_kind;
  op.access = ER_BUS_ACCESS_WRITE8;
  op.width = 1u;
  er_bus_copy_address(&op.address, address);
  op.offset = offset;
  op.value = value;
  if (er_bus_io_op_valid(&op) == 0u) {
    return 0;
  }

  if (address->bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    UINT32 shift = (UINT32)(offset & 0x3u) * 8u;
    UINT64 aligned_offset = offset & ~0x3ull;
    INT64 old_value = er_pci_read32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                                    (INT64)aligned_offset);
    UINT32 new_value;

    if (old_value < 0) {
      return 0;
    }
    new_value = ((UINT32)old_value & ~(0xffu << shift)) | ((UINT32)value << shift);
    er_pci_write32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                   (INT64)aligned_offset, (INT64)new_value);
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_MMIO32) {
    INT64 handle = er_mmio_map((INT64)address->base, (INT64)address->len);

    if (handle < 0) {
      return 0;
    }
    return er_mmio_write8(handle, (INT64)offset, value);
  }

  if (address->bus_kind == ER_BUS_KIND_IO_PORT) {
    er_bus_out8((UINT16)(address->port + offset), value);
    return 1;
  }

  return 0;
}

UINT8 er_bus_write16(const ErBusAddress* address, UINT64 offset, UINT16 value) {
  ErBusIoOp op;

  if (address == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)&op, (UINTN)sizeof(op));
  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = address->bus_kind;
  op.access = ER_BUS_ACCESS_WRITE16;
  op.width = 2u;
  er_bus_copy_address(&op.address, address);
  op.offset = offset;
  op.value = value;
  if (er_bus_io_op_valid(&op) == 0u) {
    return 0;
  }

  if (address->bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    UINT32 shift = (UINT32)(offset & 0x2u) * 8u;
    UINT64 aligned_offset = offset & ~0x3ull;
    INT64 old_value = er_pci_read32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                                    (INT64)aligned_offset);
    UINT32 new_value;

    if (old_value < 0) {
      return 0;
    }
    new_value = ((UINT32)old_value & ~(0xffffu << shift)) | ((UINT32)value << shift);
    er_pci_write32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                   (INT64)aligned_offset, (INT64)new_value);
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_MMIO32) {
    INT64 handle = er_mmio_map((INT64)address->base, (INT64)address->len);

    if (handle < 0) {
      return 0;
    }
    return er_mmio_write16(handle, (INT64)offset, value);
  }

  if (address->bus_kind == ER_BUS_KIND_IO_PORT) {
    er_bus_out16((UINT16)(address->port + offset), value);
    return 1;
  }

  return 0;
}

UINT8 er_bus_write32(const ErBusAddress* address, UINT64 offset, UINT32 value) {
  ErBusOp32 op;

  if (address == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)&op, (UINTN)sizeof(op));
  op.abi_version = ER_BUS_ABI_VERSION;
  op.bus_kind = address->bus_kind;
  op.access = ER_BUS_ACCESS_WRITE32;
  er_bus_copy_address(&op.address, address);
  op.offset = offset;
  op.value = value;
  if (er_bus_op32_valid(&op) == 0u) {
    return 0;
  }

  if (address->bus_kind == ER_BUS_KIND_PCI_CONFIG) {
    er_pci_write32((INT64)address->bus, (INT64)address->dev, (INT64)address->func,
                   (INT64)offset, (INT64)value);
    return 1;
  }

  if (address->bus_kind == ER_BUS_KIND_MMIO32) {
    INT64 handle = er_mmio_map((INT64)address->base, (INT64)address->len);

    if (handle < 0) {
      return 0;
    }
    return er_mmio_write32(handle, (INT64)offset, value);
  }

  if (address->bus_kind == ER_BUS_KIND_IO_PORT) {
    er_bus_out32((UINT16)address->port, value);
    return 1;
  }

  return 0;
}
