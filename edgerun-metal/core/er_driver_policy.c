#include "er_driver_policy.h"

static UINT8 er_driver_policy_range_allowed(UINT64 base, UINT64 len,
                                            UINT64 candidate_base,
                                            UINT64 candidate_len) {
  UINT64 end;
  UINT64 candidate_end;

  if (len == 0u || candidate_len == 0u ||
      base + len < base ||
      candidate_base + candidate_len < candidate_base) {
    return 0u;
  }
  end = base + len;
  candidate_end = candidate_base + candidate_len;
  return (UINT8)(candidate_base >= base && candidate_end <= end);
}

UINT8 er_driver_policy_prepare_mmio32(UINT32 memory_bytes, UINT64 base, UINT64 len,
                                      UINT32 access_flags,
                                      ErDriverAdmissionPolicy* out_policy) {
  if (out_policy == 0 || memory_bytes == 0u ||
      er_bus_prepare_mmio32_address(base, len, 0u, access_flags,
                                    &out_policy->bus_address) == 0u) {
    return 0u;
  }
  out_policy->memory_bytes = memory_bytes;
  return 1u;
}

UINT8 er_driver_policy_memory_allowed(const ErDriverAdmissionPolicy* policy,
                                      UINT32 memory_bytes) {
  if (policy == 0 || policy->memory_bytes == 0u || memory_bytes == 0u) {
    return 0u;
  }
  return (UINT8)(policy->memory_bytes == memory_bytes);
}

UINT8 er_driver_policy_bus_packet_allowed(const ErDriverAdmissionPolicy* policy,
                                          const ErBusIoPacket* request) {
  UINT64 access_base;

  if (policy == 0 || request == 0 ||
      er_bus_io_op_valid(&request->op) == 0u ||
      request->abi_version != ER_BUS_ABI_VERSION ||
      request->packet_kind != ER_BUS_PACKET_IO_REQUEST ||
      request->op.address.bus_kind != policy->bus_address.bus_kind ||
      er_bus_address_supports(&policy->bus_address, request->op.access) == 0u) {
    return 0u;
  }

  switch (request->op.address.bus_kind) {
    case ER_BUS_KIND_MMIO32:
      access_base = request->op.address.base + request->op.offset;
      if (access_base < request->op.address.base) {
        return 0u;
      }
      return er_driver_policy_range_allowed(policy->bus_address.base,
                                            policy->bus_address.len,
                                            access_base,
                                            request->op.width);
    case ER_BUS_KIND_PCI_CONFIG:
      if (request->op.address.bus != policy->bus_address.bus ||
          request->op.address.dev != policy->bus_address.dev ||
          request->op.address.func != policy->bus_address.func) {
        return 0u;
      }
      return er_driver_policy_range_allowed(0u, policy->bus_address.len,
                                            request->op.offset,
                                            request->op.width);
    case ER_BUS_KIND_IO_PORT:
      access_base = (UINT64)request->op.address.port + request->op.offset;
      if (access_base < (UINT64)request->op.address.port ||
          policy->bus_address.port > access_base) {
        return 0u;
      }
      return er_driver_policy_range_allowed((UINT64)policy->bus_address.port,
                                            policy->bus_address.len,
                                            access_base,
                                            request->op.width);
    default:
      return 0u;
  }
}
