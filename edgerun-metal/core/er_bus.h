#ifndef ER_BUS_H
#define ER_BUS_H

/*
 * Purpose: describe concrete hardware bus addresses and bounded operations.
 * Intention: let driver apps send byte/word/dword transactions to explicit bus addresses.
 */

#include "er_mmio.h"
#include "er_pci.h"

#define ER_BUS_ABI_VERSION 1u

#define ER_BUS_KIND_PCI_CONFIG 1u
#define ER_BUS_KIND_MMIO32 2u
#define ER_BUS_KIND_IO_PORT 3u

#define ER_BUS_ACCESS_READ32 0x00000001u
#define ER_BUS_ACCESS_WRITE32 0x00000002u
#define ER_BUS_ACCESS_READ8 0x00000004u
#define ER_BUS_ACCESS_WRITE8 0x00000008u
#define ER_BUS_ACCESS_READ16 0x00000010u
#define ER_BUS_ACCESS_WRITE16 0x00000020u
#define ER_BUS_ACCESS_READ_ALL (ER_BUS_ACCESS_READ8 | ER_BUS_ACCESS_READ16 | ER_BUS_ACCESS_READ32)
#define ER_BUS_ACCESS_WRITE_ALL (ER_BUS_ACCESS_WRITE8 | ER_BUS_ACCESS_WRITE16 | ER_BUS_ACCESS_WRITE32)
#define ER_BUS_ACCESS_ALL (ER_BUS_ACCESS_READ_ALL | ER_BUS_ACCESS_WRITE_ALL)

#define ER_BUS_PACKET_OP32_REQUEST 1u
#define ER_BUS_PACKET_OP32_RESPONSE 2u
#define ER_BUS_PACKET_IO_REQUEST 3u
#define ER_BUS_PACKET_IO_RESPONSE 4u

#define ER_BUS_STATUS_OK 0u
#define ER_BUS_STATUS_DENIED 1u
#define ER_BUS_STATUS_INVALID_ADDRESS 2u
#define ER_BUS_STATUS_INVALID_OPERATION 3u
#define ER_BUS_STATUS_IO_FAILED 4u

typedef struct {
  UINT16 abi_version;
  UINT16 bus_kind;
  UINT32 access_flags;
  UINT32 bus;
  UINT32 dev;
  UINT32 func;
  UINT32 bar_index;
  UINT32 port;
  UINT64 base;
  UINT64 len;
} ErBusAddress;

typedef struct {
  UINT16 abi_version;
  UINT16 bus_kind;
  UINT32 access;
  ErBusAddress address;
  UINT64 offset;
  UINT32 value;
} ErBusOp32;

typedef struct {
  UINT16 abi_version;
  UINT16 packet_kind;
  UINT32 status;
  UINT64 packet_id;
  ErBusOp32 op;
  UINT32 result;
} ErBusPacket32;

typedef struct {
  UINT16 abi_version;
  UINT16 bus_kind;
  UINT32 access;
  UINT32 width;
  ErBusAddress address;
  UINT64 offset;
  UINT32 value;
} ErBusIoOp;

typedef struct {
  UINT16 abi_version;
  UINT16 packet_kind;
  UINT32 status;
  UINT64 packet_id;
  ErBusIoOp op;
  UINT32 result;
} ErBusIoPacket;

UINT8 er_bus_prepare_pci_config_address(UINT32 bus, UINT32 dev, UINT32 func, UINT32 access_flags,
                                        ErBusAddress* out_address);
UINT8 er_bus_prepare_mmio32_address(UINT64 base, UINT64 len, UINT32 bar_index, UINT32 access_flags,
                                    ErBusAddress* out_address);
UINT8 er_bus_prepare_io_port_address(UINT32 port, UINT32 access_flags, ErBusAddress* out_address);
UINT8 er_bus_address_supports(const ErBusAddress* address, UINT32 access);
UINT8 er_bus_op32_valid(const ErBusOp32* op);
UINT8 er_bus_io_op_valid(const ErBusIoOp* op);
UINT8 er_bus_prepare_op32_packet(UINT64 packet_id, const ErBusAddress* address, UINT32 access,
                                 UINT64 offset, UINT32 value, ErBusPacket32* out_packet);
UINT8 er_bus_execute_op32_packet(const ErBusPacket32* request, ErBusPacket32* out_response);
UINT8 er_bus_prepare_io_packet(UINT64 packet_id, const ErBusAddress* address, UINT32 access,
                               UINT32 width, UINT64 offset, UINT32 value, ErBusIoPacket* out_packet);
UINT8 er_bus_execute_io_packet(const ErBusIoPacket* request, ErBusIoPacket* out_response);
UINT8 er_bus_read8(const ErBusAddress* address, UINT64 offset, UINT8* out_value);
UINT8 er_bus_read16(const ErBusAddress* address, UINT64 offset, UINT16* out_value);
UINT8 er_bus_read32(const ErBusAddress* address, UINT64 offset, UINT32* out_value);
UINT8 er_bus_write8(const ErBusAddress* address, UINT64 offset, UINT8 value);
UINT8 er_bus_write16(const ErBusAddress* address, UINT64 offset, UINT16 value);
UINT8 er_bus_write32(const ErBusAddress* address, UINT64 offset, UINT32 value);

#endif
