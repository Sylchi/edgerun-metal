#include "wasm_vm_internal.h"

int er_wasm_execute_i64(ErWasmModule* module, UINT32 function_index, INT64* result) {
  if (module == 0 || result == 0) {
    return -1;
  }

  if (function_index >= module->num_funcs) {
    return -1;
  }
  if (module->function_is_import[function_index]) {
    return -1;
  }

  {
    UINT32 type_index = module->function_type_indices[function_index];
    const ErWasmCode* c = 0;
    UINT8 param_count = 0;
    UINT8 local_limit = 0;
    UINT8 local_total = 0;
    INT64 stack[ER_WASM_STACK_MAX];
    UINT32 stack_size = 0;
    INT64 locals[ER_WASM_STACK_MAX];

    if (type_index >= module->num_types) {
      return -1;
    }
    if (module->type_params_0[type_index] != 0) {
      return -1;
    }
    if (module->type_result_count[type_index] != 1) {
      return -1;
    }
    if (module->type_result_type[type_index] != ER_WASM_VALTYPE_I64) {
      return -1;
    }

    c = &module->code[function_index];
    if (c->body == 0 || c->size == 0) {
      return -1;
    }

    param_count = module->type_params_0[type_index];
    local_total = c->local_count;
    if (param_count + local_total > ER_WASM_STACK_MAX) {
      return -1;
    }

    local_limit = param_count + local_total;
    for (UINT8 l = 0; l < local_limit; ++l) {
      locals[l] = 0;
    }

    ErReader code;
    ErControlFrame control[ER_WASM_MAX_CONTROL_DEPTH];
    UINT32 control_depth = 0;

    er_reader_init(&code, c->body, c->size);

    while (er_reader_more(&code)) {
      UINT8 op = 0;
      UINT32 i32value = 0;
      UINT32 target = 0;
      UINT32 matching_end = 0;
      UINT32 matching_else = 0;

      if (er_reader_read_u8(&code, &op) != 0) {
        return -1;
      }

      if (op == ER_WASM_OP_I64_CONST) {
        INT64 value = 0;
        if (stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        if (er_reader_read_i64_leb(&code, &value) != 0) {
          return -1;
        }
        stack[stack_size++] = value;
      } else if (op == ER_WASM_OP_I32_CONST) {
        UINT32 value = 0;
        INT64 signed_value = 0;
        if (stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        if (er_reader_read_u32_leb(&code, &value) != 0) {
          return -1;
        }
        signed_value = (INT64)(UINT64)value;
        stack[stack_size++] = signed_value;
      } else if (op == ER_WASM_OP_LOCAL_GET) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        stack[stack_size++] = locals[index];
      } else if (op == ER_WASM_OP_LOCAL_SET) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        locals[index] = stack[--stack_size];
      } else if (op == ER_WASM_OP_LOCAL_TEE) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        locals[index] = stack[stack_size - 1];
      } else if (op == ER_WASM_OP_I32_LOAD || op == ER_WASM_OP_I64_LOAD ||
                 op == ER_WASM_OP_I32_LOAD8_U || op == ER_WASM_OP_I32_LOAD16_U) {
        UINT32 align = 0;
        UINT32 offset = 0;
        UINT64 address = 0;
        UINT32 width = 0;
        UINT8* bytes = 0;

        if (er_reader_read_u32_leb(&code, &align) != 0 || er_reader_read_u32_leb(&code, &offset) != 0) {
          return -1;
        }
        (void)align;
        if (stack_size < 1) {
          return -1;
        }
        address = (UINT64)stack[--stack_size] + (UINT64)offset;
        if (op == ER_WASM_OP_I32_LOAD8_U) {
          width = ER_WASM_U8_BYTES;
        } else if (op == ER_WASM_OP_I32_LOAD16_U) {
          width = ER_WASM_U16_BYTES;
        } else if (op == ER_WASM_OP_I32_LOAD) {
          width = ER_WASM_U32_BYTES;
        } else {
          width = ER_WASM_U64_BYTES;
        }
        if (er_wasm_memory_range(module, address, width, &bytes) != 0 ||
            stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        if (width == ER_WASM_U8_BYTES) {
          stack[stack_size++] = (INT64)bytes[0];
        } else if (width == ER_WASM_U16_BYTES) {
          stack[stack_size++] = (INT64)((UINT32)bytes[0] | ((UINT32)bytes[1] << 8));
        } else if (width == ER_WASM_U32_BYTES) {
          stack[stack_size++] = (INT64)(UINT64)er_wasm_load_u32(bytes);
        } else {
          stack[stack_size++] = (INT64)er_wasm_load_u64(bytes);
        }
      } else if (op == ER_WASM_OP_I32_STORE || op == ER_WASM_OP_I64_STORE ||
                 op == ER_WASM_OP_I32_STORE8 || op == ER_WASM_OP_I32_STORE16) {
        UINT32 align = 0;
        UINT32 offset = 0;
        UINT64 address = 0;
        INT64 value = 0;
        UINT32 width = 0;
        UINT8* bytes = 0;

        if (er_reader_read_u32_leb(&code, &align) != 0 || er_reader_read_u32_leb(&code, &offset) != 0) {
          return -1;
        }
        (void)align;
        if (stack_size < 2) {
          return -1;
        }
        value = stack[--stack_size];
        address = (UINT64)stack[--stack_size] + (UINT64)offset;
        if (op == ER_WASM_OP_I32_STORE8) {
          width = ER_WASM_U8_BYTES;
        } else if (op == ER_WASM_OP_I32_STORE16) {
          width = ER_WASM_U16_BYTES;
        } else if (op == ER_WASM_OP_I32_STORE) {
          width = ER_WASM_U32_BYTES;
        } else {
          width = ER_WASM_U64_BYTES;
        }
        if (er_wasm_memory_range(module, address, width, &bytes) != 0) {
          return -1;
        }
        if (width == ER_WASM_U8_BYTES) {
          bytes[0] = (UINT8)value;
        } else if (width == ER_WASM_U16_BYTES) {
          bytes[ER_WASM_U32_BYTE0] = (UINT8)((UINT64)value & ER_WASM_U8_MASK);
          bytes[ER_WASM_U32_BYTE1] =
            (UINT8)(((UINT64)value >> ER_WASM_U32_BYTE1_SHIFT) & ER_WASM_U8_MASK);
        } else if (width == ER_WASM_U32_BYTES) {
          er_wasm_store_u32(bytes, (UINT32)value);
        } else {
          er_wasm_store_u64(bytes, (UINT64)value);
        }
      } else if (op == ER_WASM_OP_MEMORY_SIZE) {
        UINT32 memory_index = 0;
        if (er_reader_read_u32_leb(&code, &memory_index) != 0 ||
            memory_index != ER_WASM_MEMORY_INDEX_ZERO ||
            stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        stack[stack_size++] = (INT64)(module->memory_size / ER_WASM_MEMORY_PAGE_BYTES);
      } else if (op == ER_WASM_OP_I64_NE) {
        INT64 left = 0;
        INT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = (left != right) ? 1 : 0;
      } else if (op == ER_WASM_OP_I64_EQ) {
        INT64 left = 0;
        INT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = (left == right) ? 1 : 0;
      } else if (op == ER_WASM_OP_I64_LT_U) {
        UINT64 left = 0;
        UINT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = (UINT64)stack[--stack_size];
        left = (UINT64)stack[--stack_size];
        stack[stack_size++] = (left < right) ? 1 : 0;
      } else if (op == ER_WASM_OP_I64_AND) {
        INT64 right = 0;
        INT64 left = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = left & right;
      } else if (op == ER_WASM_OP_I64_ADD) {
        INT64 right = 0;
        INT64 left = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = left + right;
      } else if (op == ER_WASM_OP_I32_EQZ) {
        INT64 value = 0;
        if (stack_size < 1) {
          return -1;
        }
        value = stack[--stack_size];
        stack[stack_size++] = (value == 0) ? 1 : 0;
      } else if (op == ER_WASM_OP_I32_WRAP_I64) {
        INT64 value = 0;
        if (stack_size < 1) {
          return -1;
        }
        value = stack[--stack_size];
        stack[stack_size++] = (INT64)(UINT64)((UINT32)value);
      } else if (op == ER_WASM_OP_CALL) {
        UINT32 type_index_local = 0;
        if (er_reader_read_u32_leb(&code, &target) != 0) {
          return -1;
        }
        if (target >= module->num_funcs) {
          return -1;
        }
        if (!module->function_is_import[target]) {
          return -1;
        }

        type_index_local = module->function_type_indices[target];
        if (type_index_local >= module->num_types) {
          return -1;
        }

        {
          UINT8 import_kind = module->function_import_kind[target];
          UINT8 param_count_call = module->type_params_0[type_index_local];
          UINT8 result_count = module->type_result_count[type_index_local];
          UINT8 result_type = module->type_result_type[type_index_local];

          if (import_kind == ER_WASM_IMPORT_KIND_LOG_U64) {
            INT64 value = 0;
            if (param_count_call != 1 || result_count != 0) {
              return -1;
            }
            if (stack_size < 1) {
              return -1;
            }
            if (module->host.log_u64 == 0) {
              return -1;
            }
            value = stack[--stack_size];
            module->host.log_u64(value);
          } else if (import_kind == ER_WASM_IMPORT_KIND_LOG_HEX) {
            INT64 value = 0;
            if (param_count_call != 1 || result_count != 0) {
              return -1;
            }
            if (stack_size < 1) {
              return -1;
            }
            if (module->host.log_hex == 0) {
              return -1;
            }
            value = stack[--stack_size];
            module->host.log_hex((UINT64)value);
          } else if (import_kind == ER_WASM_IMPORT_KIND_PCI_READ32) {
            INT64 value = 0;
            INT64 bus = 0;
            INT64 dev = 0;
            INT64 func = 0;
            INT64 offset = 0;
            if (param_count_call != ER_WASM_PCI_READ32_PARAM_COUNT || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < ER_WASM_PCI_READ32_PARAM_COUNT) {
              return -1;
            }
            if (module->host.pci_read32 == 0) {
              return -1;
            }
            offset = stack[--stack_size];
            func = stack[--stack_size];
            dev = stack[--stack_size];
            bus = stack[--stack_size];

            value = module->host.pci_read32(bus, dev, func, offset);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_WASM_IMPORT_KIND_PCI_WRITE32) {
            INT64 bus = 0;
            INT64 dev = 0;
            INT64 func = 0;
            INT64 offset = 0;
            INT64 value = 0;
            if (param_count_call != ER_WASM_PCI_WRITE32_PARAM_COUNT || result_count != 0) {
              return -1;
            }
            if (stack_size < ER_WASM_PCI_WRITE32_PARAM_COUNT) {
              return -1;
            }
            if (module->host.pci_write32 == 0) {
              return -1;
            }
            value = stack[--stack_size];
            offset = stack[--stack_size];
            func = stack[--stack_size];
            dev = stack[--stack_size];
            bus = stack[--stack_size];
            module->host.pci_write32(bus, dev, func, offset, value);
          } else if (import_kind == ER_WASM_IMPORT_KIND_MMIO_MAP) {
            INT64 value = 0;
            INT64 phys = 0;
            INT64 len = 0;
            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.mmio_map == 0) {
              return -1;
            }
            len = stack[--stack_size];
            phys = stack[--stack_size];

            value = module->host.mmio_map(phys, len);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_WASM_IMPORT_KIND_MMIO_READ32) {
            INT64 value = 0;
            INT64 handle = 0;
            INT64 offset = 0;
            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.mmio_read32 == 0) {
              return -1;
            }
            offset = stack[--stack_size];
            handle = stack[--stack_size];

            value = module->host.mmio_read32(handle, offset);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_WASM_IMPORT_KIND_BUS_EXEC) {
            INT64 value = 0;
            INT64 request_ptr = 0;
            INT64 response_ptr = 0;
            UINT8* request_bytes = 0;
            UINT8* response_bytes = 0;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.bus_exec == 0) {
              return -1;
            }
            response_ptr = stack[--stack_size];
            request_ptr = stack[--stack_size];
            if (request_ptr < 0 || response_ptr < 0) {
              return -1;
            }
            if (er_wasm_memory_range(module, (UINT64)request_ptr, (UINT32)sizeof(ErBusIoPacket),
                                     &request_bytes) != 0 ||
                er_wasm_memory_range(module, (UINT64)response_ptr, (UINT32)sizeof(ErBusIoPacket),
                                     &response_bytes) != 0) {
              return -1;
            }

            value = module->host.bus_exec((const ErBusIoPacket*)request_bytes,
                                          (ErBusIoPacket*)response_bytes);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_WASM_IMPORT_KIND_RELAY_SEND) {
            INT64 value = 0;
            INT64 ptr = 0;
            INT64 len = 0;
            UINT8* bytes = 0;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.relay_send == 0) {
              return -1;
            }
            len = stack[--stack_size];
            ptr = stack[--stack_size];
            if (ptr < 0 || len < 0 || (UINT64)len > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)len,
                                            module->linear_memory.relay_outbox_base,
                                            module->linear_memory.relay_outbox_len,
                                            &bytes) != 0) {
              return -1;
            }
            if (er_relay_packet_authorized_for_app((const UINT8*)bytes, (UINT32)len,
                                                   module->host.app_usage,
                                                   module->host.app_budget) == 0u ||
                er_app_usage_charge(module->host.app_usage, module->host.app_budget,
                                    ER_APP_BUDGET_PACKET_BYTE, (UINT64)len) == 0u) {
              return -1;
            }

            value = module->host.relay_send((const UINT8*)bytes, (UINT32)len);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_WASM_IMPORT_KIND_RELAY_RECV) {
            INT64 value = 0;
            INT64 ptr = 0;
            INT64 capacity = 0;
            UINT8* bytes = 0;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.relay_recv == 0) {
              return -1;
            }
            capacity = stack[--stack_size];
            ptr = stack[--stack_size];
            if (ptr < 0 || capacity < 0 ||
                (UINT64)capacity > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)capacity,
                                            module->linear_memory.relay_inbox_base,
                                            module->linear_memory.relay_inbox_len,
                                            &bytes) != 0) {
              return -1;
            }

            value = module->host.relay_recv(bytes, (UINT32)capacity);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_WASM_IMPORT_KIND_MEMORY_REGION_BASE ||
                     import_kind == ER_WASM_IMPORT_KIND_MEMORY_REGION_LEN) {
            INT64 region_id = 0;
            UINT32 region_base = 0u;
            UINT32 region_len = 0u;

            if (param_count_call != 1 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 1) {
              return -1;
            }
            region_id = stack[--stack_size];
            if (region_id < 0 || (UINT64)region_id > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_linear_memory_public_region(&module->linear_memory, (UINT32)region_id,
                                                    &region_base, &region_len) != 0) {
              return -1;
            }
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            if (import_kind == ER_WASM_IMPORT_KIND_MEMORY_REGION_BASE) {
              stack[stack_size++] = (INT64)(UINT64)region_base;
            } else {
              stack[stack_size++] = (INT64)(UINT64)region_len;
            }
          } else if (import_kind == ER_WASM_IMPORT_KIND_UI_EMIT) {
            INT64 value = 0;
            INT64 ptr = 0;
            INT64 len = 0;
            UINT8* bytes = 0;
            er_ui_scene_stats_t stats;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.ui_emit == 0 || module->host.ui_presentation == 0) {
              return -1;
            }
            len = stack[--stack_size];
            ptr = stack[--stack_size];
            if (ptr < 0 || len < 0 || (UINT64)len > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)len,
                                            module->linear_memory.relay_outbox_base,
                                            module->linear_memory.relay_outbox_len,
                                            &bytes) != 0) {
              return -1;
            }
            if (er_wasm_ui_command_stats(bytes, (UINT32)len, &stats) != 0 ||
                er_app_ui_scene_fits_presentation(stats,
                                                  module->host.ui_presentation) == 0u) {
              return -1;
            }

            value = module->host.ui_emit(module->host.ui_emit_user,
                                         (const UINT8*)bytes, (UINT32)len,
                                         &stats);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else {
            return -1;
          }
        }
      } else if (op == ER_WASM_OP_BLOCK) {
        UINT8 block_type = 0;
        if (er_reader_read_u8(&code, &block_type) != 0) {
          return -1;
        }
        UINT32 start_pc = code.ofs;
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        (void)block_type;
        if (control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
          return -1;
        }
        control[control_depth].kind = ER_CONTROL_KIND_BLOCK;
        control[control_depth].start_pc = start_pc;
        control[control_depth].end_pc = matching_end;
        control[control_depth].stack_depth = stack_size;
        ++control_depth;
      } else if (op == ER_WASM_OP_LOOP) {
        UINT8 loop_type = 0;
        if (er_reader_read_u8(&code, &loop_type) != 0) {
          return -1;
        }
        UINT32 start_pc = code.ofs;
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        (void)loop_type;
        if (control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
          return -1;
        }
        control[control_depth].kind = ER_CONTROL_KIND_LOOP;
        control[control_depth].start_pc = start_pc;
        control[control_depth].end_pc = matching_end;
        control[control_depth].stack_depth = stack_size;
        ++control_depth;
      } else if (op == ER_WASM_OP_IF) {
        UINT8 if_type = 0;
        if (er_reader_read_u8(&code, &if_type) != 0) {
          return -1;
        }
        if (control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
          return -1;
        }
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        i32value = (UINT32)stack[--stack_size];
        if (i32value == 0) {
          if (matching_else != 0) {
            code.ofs = matching_else;
            control[control_depth].kind = ER_CONTROL_KIND_IF;
            control[control_depth].start_pc = code.ofs;
            control[control_depth].end_pc = matching_end;
            control[control_depth].stack_depth = stack_size;
            ++control_depth;
          } else {
            code.ofs = matching_end;
          }
        } else {
          control[control_depth].kind = ER_CONTROL_KIND_IF;
          control[control_depth].start_pc = code.ofs;
          control[control_depth].end_pc = matching_end;
          control[control_depth].stack_depth = stack_size;
          ++control_depth;
          (void)if_type;
          (void)matching_else;
        }
      } else if (op == ER_WASM_OP_ELSE) {
        if (control_depth == 0 || control[control_depth - 1].kind != ER_CONTROL_KIND_IF) {
          return -1;
        }
        code.ofs = control[control_depth - 1].end_pc;
      } else if (op == ER_WASM_OP_BR_IF) {
        if (er_reader_read_u32_leb(&code, &target) != 0) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        if (stack[--stack_size] == 0) {
          continue;
        }
        if (target >= control_depth) {
          return -1;
        }
        {
          ErControlFrame* frame = &control[control_depth - 1 - target];
          stack_size = frame->stack_depth;
          if (frame->kind == ER_CONTROL_KIND_LOOP) {
            control_depth = control_depth - target;
            code.ofs = frame->start_pc;
          } else {
            control_depth = control_depth - target - 1;
            code.ofs = frame->end_pc;
          }
        }
      } else if (op == ER_WASM_OP_BR) {
        if (er_reader_read_u32_leb(&code, &target) != 0) {
          return -1;
        }
        if (target >= control_depth) {
          return -1;
        }
        {
          ErControlFrame* frame = &control[control_depth - 1 - target];
          stack_size = frame->stack_depth;
          if (frame->kind == ER_CONTROL_KIND_LOOP) {
            control_depth = control_depth - target;
            code.ofs = frame->start_pc;
          } else {
            control_depth = control_depth - target - 1;
            code.ofs = frame->end_pc;
          }
        }
      } else if (op == ER_WASM_OP_END) {
        if (control_depth == 0) {
          if (stack_size == 0) {
            *result = 0;
            return 0;
          }
          *result = stack[stack_size - 1];
          return 0;
        }
        --control_depth;
      } else if (op == ER_WASM_OP_DROP) {
        if (stack_size == 0) {
          return -1;
        }
        --stack_size;
      } else {
        return -1;
      }
    }
  }

  return -1;
}
