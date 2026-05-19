#ifndef ER_DRIVER_POLICY_H
#define ER_DRIVER_POLICY_H

/*
 * Purpose: bind admitted Wasm driver packages to explicit memory and bus access.
 * Intention: reject driver I/O that was not declared by package admission.
 */

#include "er_bus.h"
#include "er_types.h"

typedef struct {
  UINT32 memory_bytes;
  ErBusAddress bus_address;
} ErDriverAdmissionPolicy;

UINT8 er_driver_policy_prepare_mmio32(UINT32 memory_bytes, UINT64 base, UINT64 len,
                                      UINT32 access_flags,
                                      ErDriverAdmissionPolicy* out_policy);
UINT8 er_driver_policy_memory_allowed(const ErDriverAdmissionPolicy* policy,
                                      UINT32 memory_bytes);
UINT8 er_driver_policy_bus_packet_allowed(const ErDriverAdmissionPolicy* policy,
                                          const ErBusIoPacket* request);

#endif
