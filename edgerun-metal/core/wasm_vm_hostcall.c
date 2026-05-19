#include "wasm_vm_internal.h"

static int er_wasm_stack_pop(INT64* stack, UINT32* stack_size, INT64* out) {
  if (*stack_size == 0u) {
    return -1;
  }
  *out = stack[--(*stack_size)];
  return 0;
}

static int er_wasm_stack_push(INT64* stack, UINT32* stack_size, INT64 value) {
  if (*stack_size >= ER_WASM_STACK_MAX) {
    return -1;
  }
  stack[(*stack_size)++] = value;
  return 0;
}

static int er_wasm_import_signature_matches(UINT8 actual_params,
                                            UINT8 actual_results,
                                            UINT8 actual_result_type,
                                            UINT8 expected_params,
                                            UINT8 expected_results) {
  if (actual_params != expected_params || actual_results != expected_results) {
    return -1;
  }
  if (expected_results != ER_WASM_HOSTCALL_NO_RESULTS &&
      actual_result_type != ER_WASM_VALTYPE_I64) {
    return -1;
  }
  return 0;
}

int er_wasm_execute_import_call(ErWasmModule* module,
                                UINT8 import_kind,
                                UINT8 param_count_call,
                                UINT8 result_count,
                                UINT8 result_type,
                                INT64* stack,
                                UINT32* stack_size) {
  switch (import_kind) {
    case ER_WASM_IMPORT_KIND_LOG_U64: {
      INT64 value = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_UNARY_PARAMS,
                                           ER_WASM_HOSTCALL_NO_RESULTS) != 0 ||
          er_wasm_stack_pop(stack, stack_size, &value) != 0 ||
          module->host.log_u64 == 0) {
        return -1;
      }
      module->host.log_u64(value);
      return 0;
    }
    case ER_WASM_IMPORT_KIND_LOG_HEX: {
      INT64 value = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_UNARY_PARAMS,
                                           ER_WASM_HOSTCALL_NO_RESULTS) != 0 ||
          er_wasm_stack_pop(stack, stack_size, &value) != 0 ||
          module->host.log_hex == 0) {
        return -1;
      }
      module->host.log_hex((UINT64)value);
      return 0;
    }
    case ER_WASM_IMPORT_KIND_PCI_READ32: {
      INT64 bus = 0;
      INT64 dev = 0;
      INT64 func = 0;
      INT64 offset = 0;
      INT64 value = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_PCI_READ32_PARAM_COUNT,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_PCI_READ32_PARAM_COUNT ||
          module->host.pci_read32 == 0) {
        return -1;
      }
      offset = stack[--(*stack_size)];
      func = stack[--(*stack_size)];
      dev = stack[--(*stack_size)];
      bus = stack[--(*stack_size)];
      value = module->host.pci_read32(bus, dev, func, offset);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    case ER_WASM_IMPORT_KIND_PCI_WRITE32: {
      INT64 bus = 0;
      INT64 dev = 0;
      INT64 func = 0;
      INT64 offset = 0;
      INT64 value = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_PCI_WRITE32_PARAM_COUNT,
                                           ER_WASM_HOSTCALL_NO_RESULTS) != 0 ||
          *stack_size < ER_WASM_PCI_WRITE32_PARAM_COUNT ||
          module->host.pci_write32 == 0) {
        return -1;
      }
      value = stack[--(*stack_size)];
      offset = stack[--(*stack_size)];
      func = stack[--(*stack_size)];
      dev = stack[--(*stack_size)];
      bus = stack[--(*stack_size)];
      module->host.pci_write32(bus, dev, func, offset, value);
      return 0;
    }
    case ER_WASM_IMPORT_KIND_MMIO_MAP: {
      INT64 phys = 0;
      INT64 len = 0;
      INT64 value = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_BINARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_HOSTCALL_BINARY_PARAMS ||
          module->host.mmio_map == 0) {
        return -1;
      }
      len = stack[--(*stack_size)];
      phys = stack[--(*stack_size)];
      value = module->host.mmio_map(phys, len);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    case ER_WASM_IMPORT_KIND_MMIO_READ32: {
      INT64 handle = 0;
      INT64 offset = 0;
      INT64 value = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_BINARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_HOSTCALL_BINARY_PARAMS ||
          module->host.mmio_read32 == 0) {
        return -1;
      }
      offset = stack[--(*stack_size)];
      handle = stack[--(*stack_size)];
      value = module->host.mmio_read32(handle, offset);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    case ER_WASM_IMPORT_KIND_BUS_EXEC: {
      INT64 request_ptr = 0;
      INT64 response_ptr = 0;
      INT64 value = 0;
      UINT8* request_bytes = 0;
      UINT8* response_bytes = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_BINARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_HOSTCALL_BINARY_PARAMS ||
          module->host.bus_exec == 0 ||
          module->host.driver_policy == 0) {
        return -1;
      }
      response_ptr = stack[--(*stack_size)];
      request_ptr = stack[--(*stack_size)];
      if (request_ptr < 0 || response_ptr < 0 ||
          er_wasm_memory_range(module, (UINT64)request_ptr, (UINT32)sizeof(ErBusIoPacket),
                               &request_bytes) != 0 ||
          er_wasm_memory_range(module, (UINT64)response_ptr, (UINT32)sizeof(ErBusIoPacket),
                               &response_bytes) != 0) {
        return -1;
      }
      if (er_driver_policy_bus_packet_allowed(module->host.driver_policy,
                                              (const ErBusIoPacket*)request_bytes) == 0u) {
        return -1;
      }
      value = module->host.bus_exec((const ErBusIoPacket*)request_bytes,
                                    (ErBusIoPacket*)response_bytes);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    case ER_WASM_IMPORT_KIND_RELAY_SEND: {
      INT64 ptr = 0;
      INT64 len = 0;
      INT64 value = 0;
      UINT8* bytes = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_BINARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_HOSTCALL_BINARY_PARAMS ||
          module->host.relay_send == 0) {
        return -1;
      }
      len = stack[--(*stack_size)];
      ptr = stack[--(*stack_size)];
      if (ptr < 0 || len < 0 || (UINT64)len > (UINT64)ER_WASM_U32_MASK ||
          er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)len,
                                      module->linear_memory.relay_outbox_base,
                                      module->linear_memory.relay_outbox_len,
                                      &bytes) != 0 ||
          er_relay_packet_authorized_for_app((const UINT8*)bytes, (UINT32)len,
                                             module->host.app_usage,
                                             module->host.app_budget) == 0u ||
          er_app_usage_charge(module->host.app_usage, module->host.app_budget,
                              ER_APP_BUDGET_PACKET_BYTE, (UINT64)len) == 0u) {
        return -1;
      }
      value = module->host.relay_send((const UINT8*)bytes, (UINT32)len);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    case ER_WASM_IMPORT_KIND_RELAY_RECV: {
      INT64 ptr = 0;
      INT64 capacity = 0;
      INT64 value = 0;
      UINT8* bytes = 0;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_BINARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_HOSTCALL_BINARY_PARAMS ||
          module->host.relay_recv == 0) {
        return -1;
      }
      capacity = stack[--(*stack_size)];
      ptr = stack[--(*stack_size)];
      if (ptr < 0 || capacity < 0 || (UINT64)capacity > (UINT64)ER_WASM_U32_MASK ||
          er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)capacity,
                                      module->linear_memory.relay_inbox_base,
                                      module->linear_memory.relay_inbox_len,
                                      &bytes) != 0) {
        return -1;
      }
      value = module->host.relay_recv(bytes, (UINT32)capacity);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    case ER_WASM_IMPORT_KIND_MEMORY_REGION_BASE:
    case ER_WASM_IMPORT_KIND_MEMORY_REGION_LEN: {
      INT64 region_id = 0;
      UINT32 region_base = 0u;
      UINT32 region_len = 0u;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_UNARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          er_wasm_stack_pop(stack, stack_size, &region_id) != 0 ||
          region_id < 0 || (UINT64)region_id > (UINT64)ER_WASM_U32_MASK ||
          er_wasm_linear_memory_public_region(&module->linear_memory, (UINT32)region_id,
                                              &region_base, &region_len) != 0) {
        return -1;
      }
      if (import_kind == ER_WASM_IMPORT_KIND_MEMORY_REGION_BASE) {
        return er_wasm_stack_push(stack, stack_size, (INT64)(UINT64)region_base);
      }
      return er_wasm_stack_push(stack, stack_size, (INT64)(UINT64)region_len);
    }
    case ER_WASM_IMPORT_KIND_UI_EMIT: {
      INT64 ptr = 0;
      INT64 len = 0;
      INT64 value = 0;
      UINT8* bytes = 0;
      er_ui_scene_stats_t stats;
      if (er_wasm_import_signature_matches(param_count_call, result_count, result_type,
                                           ER_WASM_HOSTCALL_BINARY_PARAMS,
                                           ER_WASM_HOSTCALL_I64_RESULTS) != 0 ||
          *stack_size < ER_WASM_HOSTCALL_BINARY_PARAMS ||
          module->host.ui_emit == 0 ||
          module->host.ui_presentation == 0) {
        return -1;
      }
      len = stack[--(*stack_size)];
      ptr = stack[--(*stack_size)];
      if (ptr < 0 || len < 0 || (UINT64)len > (UINT64)ER_WASM_U32_MASK ||
          er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)len,
                                      module->linear_memory.relay_outbox_base,
                                      module->linear_memory.relay_outbox_len,
                                      &bytes) != 0 ||
          er_wasm_ui_command_stats(bytes, (UINT32)len, &stats) != 0 ||
          er_app_ui_scene_fits_presentation(stats,
                                            module->host.ui_presentation) == 0u) {
        return -1;
      }
      value = module->host.ui_emit(module->host.ui_emit_user,
                                   (const UINT8*)bytes, (UINT32)len,
                                   &stats);
      return er_wasm_stack_push(stack, stack_size, value);
    }
    default:
      return -1;
  }
}
