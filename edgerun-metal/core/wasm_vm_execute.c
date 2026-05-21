#include "internal/wasm_vm_internal.h"

typedef struct {
  ErWasmModule* module;
  ErReader code;
  ErControlFrame control[ER_WASM_MAX_CONTROL_DEPTH];
  UINT32 control_depth;
  INT64 stack[ER_WASM_STACK_MAX];
  UINT32 stack_size;
  INT64 locals[ER_WASM_STACK_MAX];
  UINT8 local_limit;
} ErWasmExecContext;

static int er_wasm_exec_push(ErWasmExecContext* exec, INT64 value) {
  if (exec->stack_size >= ER_WASM_STACK_MAX) {
    return -1;
  }
  exec->stack[exec->stack_size++] = value;
  return 0;
}

static int er_wasm_exec_pop(ErWasmExecContext* exec, INT64* out_value) {
  if (exec->stack_size == 0u) {
    return -1;
  }
  *out_value = exec->stack[--exec->stack_size];
  return 0;
}

static int er_wasm_exec_binary_i64(ErWasmExecContext* exec, UINT8 op) {
  INT64 left = 0;
  INT64 right = 0;

  if (er_wasm_exec_pop(exec, &right) != 0 ||
      er_wasm_exec_pop(exec, &left) != 0) {
    return -1;
  }
  switch (op) {
    case ER_WASM_OP_I64_NE:
      return er_wasm_exec_push(exec, (left != right) ? 1 : 0);
    case ER_WASM_OP_I64_EQ:
      return er_wasm_exec_push(exec, (left == right) ? 1 : 0);
    case ER_WASM_OP_I64_LT_U:
      return er_wasm_exec_push(exec, ((UINT64)left < (UINT64)right) ? 1 : 0);
    case ER_WASM_OP_I64_AND:
      return er_wasm_exec_push(exec, left & right);
    case ER_WASM_OP_I64_ADD:
      return er_wasm_exec_push(exec, left + right);
    default:
      return -1;
  }
}

static int er_wasm_exec_local(ErWasmExecContext* exec, UINT8 op) {
  UINT32 index = 0;
  INT64 value = 0;

  if (er_reader_read_u32_leb(&exec->code, &index) != 0 ||
      index >= exec->local_limit) {
    return -1;
  }
  switch (op) {
    case ER_WASM_OP_LOCAL_GET:
      return er_wasm_exec_push(exec, exec->locals[index]);
    case ER_WASM_OP_LOCAL_SET:
      if (er_wasm_exec_pop(exec, &value) != 0) {
        return -1;
      }
      exec->locals[index] = value;
      return 0;
    case ER_WASM_OP_LOCAL_TEE:
      if (exec->stack_size == 0u) {
        return -1;
      }
      exec->locals[index] = exec->stack[exec->stack_size - 1u];
      return 0;
    default:
      return -1;
  }
}

static UINT32 er_wasm_exec_memory_width(UINT8 op) {
  switch (op) {
    case ER_WASM_OP_I32_LOAD8_U:
    case ER_WASM_OP_I32_STORE8:
      return ER_WASM_U8_BYTES;
    case ER_WASM_OP_I32_LOAD16_U:
    case ER_WASM_OP_I32_STORE16:
      return ER_WASM_U16_BYTES;
    case ER_WASM_OP_I32_LOAD:
    case ER_WASM_OP_I32_STORE:
      return ER_WASM_U32_BYTES;
    default:
      return ER_WASM_U64_BYTES;
  }
}

static int er_wasm_exec_load(ErWasmExecContext* exec, UINT8 op) {
  UINT32 align = 0;
  UINT32 offset = 0;
  UINT64 address = 0;
  UINT32 width = 0;
  UINT8* bytes = 0;
  INT64 base = 0;

  if (er_reader_read_u32_leb(&exec->code, &align) != 0 ||
      er_reader_read_u32_leb(&exec->code, &offset) != 0 ||
      er_wasm_exec_pop(exec, &base) != 0) {
    return -1;
  }
  (void)align;
  address = (UINT64)base + (UINT64)offset;
  width = er_wasm_exec_memory_width(op);
  if (er_wasm_memory_range(exec->module, address, width, &bytes) != 0) {
    return -1;
  }
  switch (width) {
    case ER_WASM_U8_BYTES:
      return er_wasm_exec_push(exec, (INT64)bytes[0]);
    case ER_WASM_U16_BYTES:
      return er_wasm_exec_push(exec,
                               (INT64)((UINT32)bytes[0] | ((UINT32)bytes[1] << 8)));
    case ER_WASM_U32_BYTES:
      return er_wasm_exec_push(exec, (INT64)(UINT64)er_wasm_load_u32(bytes));
    default:
      return er_wasm_exec_push(exec, (INT64)er_wasm_load_u64(bytes));
  }
}

static int er_wasm_exec_store(ErWasmExecContext* exec, UINT8 op) {
  UINT32 align = 0;
  UINT32 offset = 0;
  UINT64 address = 0;
  UINT32 width = 0;
  UINT8* bytes = 0;
  INT64 base = 0;
  INT64 value = 0;

  if (er_reader_read_u32_leb(&exec->code, &align) != 0 ||
      er_reader_read_u32_leb(&exec->code, &offset) != 0 ||
      er_wasm_exec_pop(exec, &value) != 0 ||
      er_wasm_exec_pop(exec, &base) != 0) {
    return -1;
  }
  (void)align;
  address = (UINT64)base + (UINT64)offset;
  width = er_wasm_exec_memory_width(op);
  if (er_wasm_memory_range(exec->module, address, width, &bytes) != 0) {
    return -1;
  }
  switch (width) {
    case ER_WASM_U8_BYTES:
      bytes[0] = (UINT8)value;
      return 0;
    case ER_WASM_U16_BYTES:
      bytes[ER_WASM_U32_BYTE0] = (UINT8)((UINT64)value & ER_WASM_U8_MASK);
      bytes[ER_WASM_U32_BYTE1] =
        (UINT8)(((UINT64)value >> ER_WASM_U32_BYTE1_SHIFT) & ER_WASM_U8_MASK);
      return 0;
    case ER_WASM_U32_BYTES:
      er_wasm_store_u32(bytes, (UINT32)value);
      return 0;
    default:
      er_wasm_store_u64(bytes, (UINT64)value);
      return 0;
  }
}

static int er_wasm_exec_call_import(ErWasmExecContext* exec) {
  UINT32 target = 0;
  UINT32 type_index = 0;
  UINT8 import_kind = 0;

  if (er_reader_read_u32_leb(&exec->code, &target) != 0 ||
      target >= exec->module->num_funcs ||
      !exec->module->function_is_import[target]) {
    return -1;
  }
  type_index = exec->module->function_type_indices[target];
  if (type_index >= exec->module->num_types) {
    return -1;
  }
  import_kind = exec->module->function_import_kind[target];
  return er_wasm_execute_import_call(exec->module, import_kind,
                                     exec->module->type_params_0[type_index],
                                     exec->module->type_result_count[type_index],
                                     exec->module->type_result_type[type_index],
                                     exec->stack, &exec->stack_size);
}

static int er_wasm_exec_push_control(ErWasmExecContext* exec,
                                     UINT8 kind,
                                     UINT32 start_pc,
                                     UINT32 end_pc) {
  if (exec->control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
    return -1;
  }
  exec->control[exec->control_depth].kind = kind;
  exec->control[exec->control_depth].start_pc = start_pc;
  exec->control[exec->control_depth].end_pc = end_pc;
  exec->control[exec->control_depth].stack_depth = exec->stack_size;
  ++exec->control_depth;
  return 0;
}

static int er_wasm_exec_block(ErWasmExecContext* exec, UINT8 kind) {
  UINT8 block_type = 0;
  UINT32 matching_end = 0;
  UINT32 matching_else = 0;
  UINT32 start_pc = 0;

  if (er_reader_read_u8(&exec->code, &block_type) != 0) {
    return -1;
  }
  (void)block_type;
  start_pc = exec->code.ofs;
  if (er_scan_matching_end(exec->code.data, exec->code.size, exec->code.ofs,
                           &matching_end, &matching_else) != 0) {
    return -1;
  }
  (void)matching_else;
  return er_wasm_exec_push_control(exec, kind, start_pc, matching_end);
}

static int er_wasm_exec_if(ErWasmExecContext* exec) {
  UINT8 if_type = 0;
  UINT32 matching_end = 0;
  UINT32 matching_else = 0;
  INT64 condition = 0;

  if (er_reader_read_u8(&exec->code, &if_type) != 0 ||
      er_scan_matching_end(exec->code.data, exec->code.size, exec->code.ofs,
                           &matching_end, &matching_else) != 0 ||
      er_wasm_exec_pop(exec, &condition) != 0) {
    return -1;
  }
  (void)if_type;
  if ((UINT32)condition == 0u) {
    if (matching_else != 0u) {
      exec->code.ofs = matching_else;
      return er_wasm_exec_push_control(exec, ER_CONTROL_KIND_IF, exec->code.ofs,
                                       matching_end);
    }
    exec->code.ofs = matching_end;
    return 0;
  }
  return er_wasm_exec_push_control(exec, ER_CONTROL_KIND_IF, exec->code.ofs,
                                   matching_end);
}

static int er_wasm_exec_branch(ErWasmExecContext* exec, UINT32 target) {
  ErControlFrame* frame;

  if (target >= exec->control_depth) {
    return -1;
  }
  frame = &exec->control[exec->control_depth - 1u - target];
  exec->stack_size = frame->stack_depth;
  if (frame->kind == ER_CONTROL_KIND_LOOP) {
    exec->control_depth = exec->control_depth - target;
    exec->code.ofs = frame->start_pc;
  } else {
    exec->control_depth = exec->control_depth - target - 1u;
    exec->code.ofs = frame->end_pc;
  }
  return 0;
}

static int er_wasm_exec_branch_op(ErWasmExecContext* exec, UINT8 op) {
  UINT32 target = 0;
  INT64 condition = 0;

  if (er_reader_read_u32_leb(&exec->code, &target) != 0) {
    return -1;
  }
  if (op == ER_WASM_OP_BR_IF) {
    if (er_wasm_exec_pop(exec, &condition) != 0) {
      return -1;
    }
    if (condition == 0) {
      return 0;
    }
  }
  return er_wasm_exec_branch(exec, target);
}

static int er_wasm_exec_init(ErWasmExecContext* exec,
                             ErWasmModule* module,
                             UINT32 function_index) {
  UINT32 type_index;
  const ErWasmCode* c;
  UINT8 param_count;
  UINT8 local_total;

  if (exec == 0 || module == 0 ||
      function_index >= module->num_funcs ||
      module->function_is_import[function_index]) {
    return -1;
  }
  type_index = module->function_type_indices[function_index];
  if (type_index >= module->num_types ||
      module->type_params_0[type_index] != ER_WASM_HOSTCALL_NO_PARAMS ||
      module->type_result_count[type_index] != ER_WASM_HOSTCALL_I64_RESULTS ||
      module->type_result_type[type_index] != ER_WASM_VALTYPE_I64) {
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
  er_mem_zero((UINT8*)exec, (UINTN)sizeof(*exec));
  exec->module = module;
  exec->local_limit = param_count + local_total;
  er_reader_init(&exec->code, c->body, c->size);
  return 0;
}

int er_wasm_execute_i64(ErWasmModule* module, UINT32 function_index, INT64* result) {
  ErWasmExecContext exec;

  if (result == 0 ||
      er_wasm_exec_init(&exec, module, function_index) != 0) {
    return -1;
  }

  while (er_reader_more(&exec.code)) {
      UINT8 op = 0;

      if (er_reader_read_u8(&exec.code, &op) != 0) {
        return -1;
      }

      if (op == ER_WASM_OP_I64_CONST) {
        INT64 value = 0;
        if (er_reader_read_i64_leb(&exec.code, &value) != 0 ||
            er_wasm_exec_push(&exec, value) != 0) {
          return -1;
        }
      } else if (op == ER_WASM_OP_I32_CONST) {
        UINT32 value = 0;
        if (er_reader_read_u32_leb(&exec.code, &value) != 0 ||
            er_wasm_exec_push(&exec, (INT64)(UINT64)value) != 0) {
          return -1;
        }
      } else if (op == ER_WASM_OP_LOCAL_GET) {
        if (er_wasm_exec_local(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_LOCAL_SET) {
        if (er_wasm_exec_local(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_LOCAL_TEE) {
        if (er_wasm_exec_local(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I32_LOAD || op == ER_WASM_OP_I64_LOAD ||
                 op == ER_WASM_OP_I32_LOAD8_U || op == ER_WASM_OP_I32_LOAD16_U) {
        if (er_wasm_exec_load(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I32_STORE || op == ER_WASM_OP_I64_STORE ||
                 op == ER_WASM_OP_I32_STORE8 || op == ER_WASM_OP_I32_STORE16) {
        if (er_wasm_exec_store(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_MEMORY_SIZE) {
        UINT32 memory_index = 0;
        if (er_reader_read_u32_leb(&exec.code, &memory_index) != 0 ||
            memory_index != ER_WASM_MEMORY_INDEX_ZERO ||
            er_wasm_exec_push(&exec,
                              (INT64)(module->memory_size / ER_WASM_MEMORY_PAGE_BYTES)) != 0) {
          return -1;
        }
      } else if (op == ER_WASM_OP_I64_NE) {
        if (er_wasm_exec_binary_i64(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I64_EQ) {
        if (er_wasm_exec_binary_i64(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I64_LT_U) {
        if (er_wasm_exec_binary_i64(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I64_AND) {
        if (er_wasm_exec_binary_i64(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I64_ADD) {
        if (er_wasm_exec_binary_i64(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I32_EQZ) {
        INT64 value = 0;
        if (er_wasm_exec_pop(&exec, &value) != 0 ||
            er_wasm_exec_push(&exec, (value == 0) ? 1 : 0) != 0) { return -1; }
      } else if (op == ER_WASM_OP_I32_WRAP_I64) {
        INT64 value = 0;
        if (er_wasm_exec_pop(&exec, &value) != 0 ||
            er_wasm_exec_push(&exec, (INT64)(UINT64)((UINT32)value)) != 0) { return -1; }
      } else if (op == ER_WASM_OP_CALL) {
        if (er_wasm_exec_call_import(&exec) != 0) { return -1; }
      } else if (op == ER_WASM_OP_BLOCK) {
        if (er_wasm_exec_block(&exec, ER_CONTROL_KIND_BLOCK) != 0) { return -1; }
      } else if (op == ER_WASM_OP_LOOP) {
        if (er_wasm_exec_block(&exec, ER_CONTROL_KIND_LOOP) != 0) { return -1; }
      } else if (op == ER_WASM_OP_IF) {
        if (er_wasm_exec_if(&exec) != 0) { return -1; }
      } else if (op == ER_WASM_OP_ELSE) {
        if (exec.control_depth == 0 ||
            exec.control[exec.control_depth - 1u].kind != ER_CONTROL_KIND_IF) {
          return -1;
        }
        exec.code.ofs = exec.control[exec.control_depth - 1u].end_pc;
      } else if (op == ER_WASM_OP_BR_IF) {
        if (er_wasm_exec_branch_op(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_BR) {
        if (er_wasm_exec_branch_op(&exec, op) != 0) { return -1; }
      } else if (op == ER_WASM_OP_END) {
        if (exec.control_depth == 0u) {
          if (exec.stack_size == 0u) {
            *result = 0;
            return 0;
          }
          *result = exec.stack[exec.stack_size - 1u];
          return 0;
        }
        --exec.control_depth;
      } else if (op == ER_WASM_OP_DROP) {
        INT64 dropped = 0;
        if (er_wasm_exec_pop(&exec, &dropped) != 0) { return -1; }
      } else {
        return -1;
      }
  }

  return -1;
}
