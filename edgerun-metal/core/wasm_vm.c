#include "wasm_vm.h"


typedef struct {
  const UINT8* data;
  UINT32 size;
  UINT32 ofs;
} ErReader;

typedef struct {
  UINT8 form;
  UINT8 param_count;
  UINT8 result_count;
  UINT8 result_type;
} ErFuncType;

typedef struct {
  const char* module;
  UINT8 module_len;
  const char* field;
  UINT8 field_len;
  UINT8 kind;
} ErHostImport;

typedef struct {
  UINT8 kind;
  UINT32 start_pc;
  UINT32 end_pc;
  UINT32 stack_depth;
} ErControlFrame;

enum {
  ER_IMPORT_KIND_NONE = 0,
  ER_IMPORT_KIND_LOG_U64 = 1,
  ER_IMPORT_KIND_LOG_HEX = 2,
  ER_IMPORT_KIND_PCI_READ32 = 3,
  ER_IMPORT_KIND_PCI_WRITE32 = 4,
  ER_IMPORT_KIND_MMIO_MAP = 5,
  ER_IMPORT_KIND_MMIO_READ32 = 6
};

enum {
  ER_CONTROL_KIND_BLOCK = 1,
  ER_CONTROL_KIND_LOOP = 2,
  ER_CONTROL_KIND_IF = 3
};

static const ErHostImport ER_HOST_IMPORTS[] = {
  {"edgerun.log", 11, "u64", 3, ER_IMPORT_KIND_LOG_U64},
  {"edgerun.log", 11, "hex", 3, ER_IMPORT_KIND_LOG_HEX},
  {"edgerun.pci", 11, "read32", 6, ER_IMPORT_KIND_PCI_READ32},
  {"edgerun.pci", 11, "write32", 7, ER_IMPORT_KIND_PCI_WRITE32},
  {"edgerun.mmio", 12, "map", 3, ER_IMPORT_KIND_MMIO_MAP},
  {"edgerun.mmio", 12, "read32", 6, ER_IMPORT_KIND_MMIO_READ32}
};
static const UINT32 ER_HOST_IMPORT_COUNT = (UINT32)(sizeof(ER_HOST_IMPORTS) / sizeof(ER_HOST_IMPORTS[0]));

static UINT8 er_match_name(const UINT8* actual_name, UINT32 actual_len, const char* expected_name, UINT32 expected_len) {
  UINT32 i = 0;

  if (actual_name == 0 || expected_name == 0) {
    return 0;
  }
  if (actual_len != expected_len) {
    return 0;
  }

  for (i = 0; i < actual_len; ++i) {
    if (actual_name[i] != (UINT8)expected_name[i]) {
      return 0;
    }
  }

  return 1;
}

static void er_clear_module(ErWasmModule* module) {
  if (module == 0) {
    return;
  }

  module->num_types = 0;
  module->num_imports = 0;
  module->num_funcs = 0;
  module->num_exports = 0;
  module->function_has_main = 0;
  module->main_index = 0;

  for (UINT32 i = 0; i < 16; ++i) {
    module->function_type_indices[i] = 0;
    module->function_is_import[i] = 0;
    module->function_import_kind[i] = ER_IMPORT_KIND_NONE;
    module->type_params_0[i] = 0;
    module->type_result_count[i] = 0;
    module->type_result_type[i] = 0;
    module->code[i].body = 0;
    module->code[i].size = 0;
    module->code[i].local_count = 0;
  }

  module->host.log_u64 = 0;
  module->host.log_hex = 0;
  module->host.pci_read32 = 0;
  module->host.pci_write32 = 0;
  module->host.mmio_map = 0;
  module->host.mmio_read32 = 0;
}

static int er_reader_init(ErReader* r, const UINT8* data, UINT32 size) {
  if (r == 0) {
    return -1;
  }

  r->data = data;
  r->size = size;
  r->ofs = 0;
  return 0;
}

static int er_reader_more(const ErReader* r) {
  if (r == 0) {
    return 0;
  }
  return (r->ofs < r->size);
}

static int er_reader_read_u8(ErReader* r, UINT8* out) {
  if (r == 0 || out == 0) {
    return -1;
  }
  if (!er_reader_more(r)) {
    return -1;
  }

  *out = r->data[r->ofs];
  ++r->ofs;
  return 0;
}

static int er_reader_read_u32_leb(ErReader* r, UINT32* out) {
  UINT32 result = 0;
  UINT32 shift = 0;
  UINT8 byte = 0;
  UINT32 count = 0;

  if (r == 0 || out == 0) {
    return -1;
  }

  do {
    if (count++ >= 5 || r->ofs >= r->size) {
      return -1;
    }
    byte = r->data[r->ofs++];
    result |= (UINT32)(byte & 0x7f) << shift;
    shift += 7;
  } while (byte & 0x80);

  *out = result;
  return 0;
}

static int er_reader_read_i64_leb(ErReader* r, INT64* out) {
  UINT8 byte = 0;
  INT64 result = 0;
  INT32 shift = 0;
  UINT8 count = 0;

  if (r == 0 || out == 0) {
    return -1;
  }

  do {
    if (count++ >= 10 || r->ofs >= r->size) {
      return -1;
    }
    byte = r->data[r->ofs++];
    result |= (INT64)(byte & 0x7f) << shift;
    shift += 7;
  } while (byte & 0x80);

  if ((shift < 64) && (byte & 0x40)) {
    result |= (INT64)(~((UINT64)0) << shift);
  }

  *out = result;
  return 0;
}

static int er_skip_u32_leb(const UINT8* data, UINT32 size, UINT32* ofs) {
  UINT8 byte = 0;
  UINT32 count = 0;

  if (data == 0 || ofs == 0) {
    return -1;
  }

  while (*ofs < size) {
    byte = data[*ofs];
    ++(*ofs);
    if (!(byte & 0x80)) {
      return 0;
    }

    if (++count >= 5) {
      return -1;
    }
  }

  return -1;
}

static int er_skip_i64_leb(const UINT8* data, UINT32 size, UINT32* ofs) {
  UINT8 byte = 0;
  UINT32 count = 0;

  if (data == 0 || ofs == 0) {
    return -1;
  }

  while (*ofs < size) {
    byte = data[*ofs];
    ++(*ofs);
    if (!(byte & 0x80)) {
      return 0;
    }

    if (++count >= 10) {
      return -1;
    }
  }

  return -1;
}

static int er_reader_skip(ErReader* r, UINT32 count) {
  if (r == 0 || count > r->size - r->ofs) {
    return -1;
  }
  r->ofs += count;
  return 0;
}

static int er_read_string(ErReader* r, const UINT8** out_string, UINT32* out_len) {
  UINT32 len = 0;

  if (r == 0 || out_string == 0 || out_len == 0) {
    return -1;
  }

  if (er_reader_read_u32_leb(r, &len) != 0) {
    return -1;
  }

  if (r->ofs + len > r->size) {
    return -1;
  }

  *out_string = &r->data[r->ofs];
  *out_len = len;
  r->ofs += len;
  return 0;
}

static int er_scan_matching_end(const UINT8* data, UINT32 size, UINT32 start_pc, UINT32* out_end_pc, UINT32* out_else_pc) {
  UINT32 pc = start_pc;
  UINT32 depth = 1;

  if (data == 0 || out_end_pc == 0) {
    return -1;
  }

  if (start_pc >= size) {
    return -1;
  }

  if (out_else_pc != 0) {
    *out_else_pc = 0;
  }

  while (pc < size) {
    UINT8 op = data[pc++];

    if (op == 0x02 || op == 0x03 || op == 0x04) {
      if (pc >= size) {
        return -1;
      }
      pc += 1; /* block type */
      ++depth;
      continue;
    }

    if (op == 0x05) {
      if (depth == 1 && out_else_pc != 0 && *out_else_pc == 0) {
        *out_else_pc = pc;
      }
      continue;
    }

    if (op == 0x0b) {
      if (depth == 0) {
        return -1;
      }
      if (depth == 1) {
        *out_end_pc = pc;
        return 0;
      }
      --depth;
      continue;
    }

    if (op == 0x10 || op == 0x0c || op == 0x0d || op == 0x20 || op == 0x21 || op == 0x22) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == 0x41) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == 0x42) {
      if (er_skip_i64_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }
  }

  return -1;
}

int er_wasm_init(ErWasmModule* module, const UINT8* data, UINT32 size, const ErWasmHostCalls* host) {
  ErReader r;
  ErFuncType temp_type[16];
  ErFuncType func_types[16];
  UINT8 i;

  if (module == 0) {
    return -1;
  }

  er_clear_module(module);

  if (host != 0) {
    module->host.log_u64 = host->log_u64;
    module->host.log_hex = host->log_hex;
    module->host.pci_read32 = host->pci_read32;
    module->host.pci_write32 = host->pci_write32;
    module->host.mmio_map = host->mmio_map;
    module->host.mmio_read32 = host->mmio_read32;
  }

  if (er_reader_init(&r, data, size) != 0) {
    return -1;
  }

  if (size < 8) {
    return -1;
  }

  if (data[0] != 0x00 || data[1] != 0x61 || data[2] != 0x73 || data[3] != 0x6d) {
    return -1;
  }

  if (data[4] != 0x01 || data[5] != 0x00 || data[6] != 0x00 || data[7] != 0x00) {
    return -1;
  }

  r.ofs = 8;

  while (r.ofs < r.size) {
    UINT8 section_id = 0;
    UINT32 section_len = 0;
    UINT32 section_end = 0;

    if (er_reader_read_u8(&r, &section_id) != 0) {
      return -1;
    }
    if (er_reader_read_u32_leb(&r, &section_len) != 0) {
      return -1;
    }

    if (section_len > r.size - r.ofs) {
      return -1;
    }

    section_end = r.ofs + section_len;

    if (section_id == 1) {
      UINT32 type_count = 0;
      if (er_reader_read_u32_leb(&r, &type_count) != 0) {
        return -1;
      }
      if (type_count > 16) {
        return -1;
      }

      for (i = 0; i < (UINT8)type_count; ++i) {
        UINT8 form;
        UINT32 param_count;
        UINT32 result_count;

        if (er_reader_read_u8(&r, &form) != 0) {
          return -1;
        }
        if (form != 0x60) {
          return -1;
        }

        if (er_reader_read_u32_leb(&r, &param_count) != 0) {
          return -1;
        }

        if (param_count > 5) {
          return -1;
        }

        for (UINT32 p = 0; p < param_count; ++p) {
          UINT8 skip;
          if (er_reader_read_u8(&r, &skip) != 0) {
            return -1;
          }
          if (skip != 0x7e && skip != 0x7f && skip != 0x7d && skip != 0x7c) {
            return -1;
          }
        }

        if (er_reader_read_u32_leb(&r, &result_count) != 0) {
          return -1;
        }
        if (result_count > 1) {
          return -1;
        }

        temp_type[i].form = form;
        temp_type[i].param_count = (UINT8)param_count;
        temp_type[i].result_count = (UINT8)result_count;
        temp_type[i].result_type = 0;

        if (result_count == 1) {
          if (er_reader_read_u8(&r, &temp_type[i].result_type) != 0) {
            return -1;
          }
        }
      }

      for (i = 0; i < (UINT8)type_count; ++i) {
        func_types[i] = temp_type[i];
      }
      module->num_types = type_count;
    } else if (section_id == 2) {
      UINT32 import_count = 0;
      if (er_reader_read_u32_leb(&r, &import_count) != 0) {
        return -1;
      }
      if (import_count > 16) {
        return -1;
      }

      for (UINT32 import_i = 0; import_i < import_count; ++import_i) {
        UINT8 import_kind = ER_IMPORT_KIND_NONE;
        UINT8 kind = 0;
        UINT32 type_index = 0;
        UINT32 function_index = 0;
        const UINT8* module_name = 0;
        UINT32 module_len = 0;
        const UINT8* field_name = 0;
        UINT32 field_len = 0;

        if (module->num_funcs >= 16) {
          return -1;
        }

        if (er_read_string(&r, &module_name, &module_len) != 0) {
          return -1;
        }
        if (er_read_string(&r, &field_name, &field_len) != 0) {
          return -1;
        }

        for (i = 0; i < (UINT8)ER_HOST_IMPORT_COUNT; ++i) {
          if (er_match_name(module_name, module_len, ER_HOST_IMPORTS[i].module, ER_HOST_IMPORTS[i].module_len) &&
              er_match_name(field_name, field_len, ER_HOST_IMPORTS[i].field, ER_HOST_IMPORTS[i].field_len)) {
            import_kind = ER_HOST_IMPORTS[i].kind;
            break;
          }
        }

        if (er_reader_read_u8(&r, &kind) != 0) {
          return -1;
        }
        if (kind != 0x00) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &type_index) != 0 || type_index >= module->num_types) {
          return -1;
        }

        function_index = module->num_funcs;
        module->function_type_indices[function_index] = type_index;
        module->function_is_import[function_index] = 1;
        module->function_import_kind[function_index] = import_kind;
        module->num_funcs += 1;
        module->num_imports += 1;
      }
    } else if (section_id == 3) {
      UINT32 func_count = 0;
      if (er_reader_read_u32_leb(&r, &func_count) != 0) {
        return -1;
      }
      if (func_count > 16 || module->num_funcs + func_count > 16) {
        return -1;
      }

      for (UINT32 func_i = 0; func_i < func_count; ++func_i) {
        UINT32 type_index = 0;
        if (er_reader_read_u32_leb(&r, &type_index) != 0 || type_index >= module->num_types) {
          return -1;
        }
        module->function_type_indices[module->num_funcs] = type_index;
        module->function_is_import[module->num_funcs] = 0;
        module->function_import_kind[module->num_funcs] = ER_IMPORT_KIND_NONE;
        module->num_funcs += 1;
      }
    } else if (section_id == 7) {
      UINT32 export_count = 0;
      if (er_reader_read_u32_leb(&r, &export_count) != 0) {
        return -1;
      }
      if (export_count > 16) {
        return -1;
      }

      module->num_exports = export_count;

      for (i = 0; i < (UINT8)export_count; ++i) {
        UINT32 name_len = 0;
        UINT8 is_main = 0;
        UINT8 kind = 0;
        UINT32 index = 0;

        if (er_reader_read_u32_leb(&r, &name_len) != 0) {
          return -1;
        }

        if (name_len == 4 && r.ofs + 4 <= r.size &&
            r.data[r.ofs] == 'm' &&
            r.data[r.ofs + 1] == 'a' &&
            r.data[r.ofs + 2] == 'i' &&
            r.data[r.ofs + 3] == 'n') {
          r.ofs += 4;
          is_main = 1;
        } else {
          r.ofs += name_len;
        }

        if (er_reader_read_u8(&r, &kind) != 0) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &index) != 0) {
          return -1;
        }

        if (is_main) {
          if (kind != 0x00) {
            return -1;
          }
          module->function_has_main = 1;
          module->main_index = index;
        }
      }
    } else if (section_id == 10) {
      UINT32 body_count = 0;
      if (er_reader_read_u32_leb(&r, &body_count) != 0) {
        return -1;
      }

      if (body_count > 16 || body_count > module->num_funcs - module->num_imports) {
        return -1;
      }

      for (i = 0; i < (UINT8)body_count; ++i) {
        UINT32 body_size = 0;
        UINT32 body_start = 0;
        UINT32 body_end = 0;
        UINT32 local_count = 0;
        UINT32 local_total = 0;

        if (er_reader_read_u32_leb(&r, &body_size) != 0) {
          return -1;
        }

        if (r.ofs + body_size > r.size) {
          return -1;
        }

        body_start = r.ofs;
        body_end = body_start + body_size;

        if (er_reader_read_u32_leb(&r, &local_count) != 0) {
          return -1;
        }

        for (UINT32 l = 0; l < local_count; ++l) {
          UINT32 local_repeat = 0;
          UINT8 local_type = 0;
          if (er_reader_read_u32_leb(&r, &local_repeat) != 0) {
            return -1;
          }
          if (er_reader_read_u8(&r, &local_type) != 0) {
            return -1;
          }
          if (local_type != 0x7e) {
            return -1;
          }
          local_total += local_repeat;
          if (local_total > 16) {
            return -1;
          }
        }

        module->code[module->num_imports + i].body = &r.data[r.ofs];
        if (r.ofs > body_end) {
          return -1;
        }
        module->code[module->num_imports + i].size = body_end - r.ofs;
        module->code[module->num_imports + i].local_count = (UINT8)local_total;
        r.ofs = body_end;
      }
    } else {
      if (er_reader_skip(&r, section_len) != 0) {
        return -1;
      }
    }

    if (r.ofs != section_end) {
      r.ofs = section_end;
    }
  }

  for (i = 0; i < module->num_types; ++i) {
    if (i < 16) {
      module->type_params_0[i] = func_types[i].param_count;
      module->type_result_count[i] = func_types[i].result_count;
      module->type_result_type[i] = func_types[i].result_type;
    }
  }

  return 0;
}

int er_wasm_find_main(ErWasmModule* module, UINT32* main_index) {
  if (module == 0 || main_index == 0) {
    return -1;
  }

  if (!module->function_has_main) {
    return -1;
  }

  *main_index = module->main_index;
  return 0;
}

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
    INT64 stack[32];
    UINT32 stack_size = 0;
    INT64 locals[32];

    if (type_index >= module->num_types) {
      return -1;
    }
    if (module->type_params_0[type_index] != 0) {
      return -1;
    }
    if (module->type_result_count[type_index] != 1) {
      return -1;
    }
    if (module->type_result_type[type_index] != 0x7e) {
      return -1;
    }

    c = &module->code[function_index];
    if (c->body == 0 || c->size == 0) {
      return -1;
    }

    param_count = module->type_params_0[type_index];
    local_total = c->local_count;
    if (param_count + local_total > 32) {
      return -1;
    }

    local_limit = param_count + local_total;
    for (UINT8 l = 0; l < local_limit; ++l) {
      locals[l] = 0;
    }

    ErReader code;
    ErControlFrame control[16];
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

      if (op == 0x42) {
        INT64 value = 0;
        if (stack_size >= 32) {
          return -1;
        }
        if (er_reader_read_i64_leb(&code, &value) != 0) {
          return -1;
        }
        stack[stack_size++] = value;
      } else if (op == 0x41) {
        UINT32 value = 0;
        INT64 signed_value = 0;
        if (stack_size >= 32) {
          return -1;
        }
        if (er_reader_read_u32_leb(&code, &value) != 0) {
          return -1;
        }
        signed_value = (INT64)(UINT64)value;
        stack[stack_size++] = signed_value;
      } else if (op == 0x20) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size >= 32) {
          return -1;
        }
        stack[stack_size++] = locals[index];
      } else if (op == 0x21) {
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
      } else if (op == 0x22) {
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
      } else if (op == 0x52) {
        INT64 left = 0;
        INT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = (left != right) ? 1 : 0;
      } else if (op == 0x51) {
        INT64 left = 0;
        INT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = (left == right) ? 1 : 0;
      } else if (op == 0x54) {
        UINT64 left = 0;
        UINT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = (UINT64)stack[--stack_size];
        left = (UINT64)stack[--stack_size];
        stack[stack_size++] = (left < right) ? 1 : 0;
      } else if (op == 0x83) {
        INT64 right = 0;
        INT64 left = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = left & right;
      } else if (op == 0x7c) {
        INT64 right = 0;
        INT64 left = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = left + right;
      } else if (op == 0x45) {
        INT64 value = 0;
        if (stack_size < 1) {
          return -1;
        }
        value = stack[--stack_size];
        stack[stack_size++] = (value == 0) ? 1 : 0;
      } else if (op == 0x10) {
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

          if (import_kind == ER_IMPORT_KIND_LOG_U64) {
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
          } else if (import_kind == ER_IMPORT_KIND_LOG_HEX) {
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
          } else if (import_kind == ER_IMPORT_KIND_PCI_READ32) {
            INT64 value = 0;
            INT64 bus = 0;
            INT64 dev = 0;
            INT64 func = 0;
            INT64 offset = 0;
            if (param_count_call != 4 || result_count != 1) {
              return -1;
            }
            if (result_type != 0x7e) {
              return -1;
            }
            if (stack_size < 4) {
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
            if (stack_size >= 32) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_PCI_WRITE32) {
            INT64 bus = 0;
            INT64 dev = 0;
            INT64 func = 0;
            INT64 offset = 0;
            INT64 value = 0;
            if (param_count_call != 5 || result_count != 0) {
              return -1;
            }
            if (stack_size < 5) {
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
          } else if (import_kind == ER_IMPORT_KIND_MMIO_MAP) {
            INT64 value = 0;
            INT64 phys = 0;
            INT64 len = 0;
            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != 0x7e) {
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
            if (stack_size >= 32) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_MMIO_READ32) {
            INT64 value = 0;
            INT64 handle = 0;
            INT64 offset = 0;
            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != 0x7e) {
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
            if (stack_size >= 32) {
              return -1;
            }
            stack[stack_size++] = value;
          } else {
            return -1;
          }
        }
      } else if (op == 0x02) {
        UINT8 block_type = 0;
        if (er_reader_read_u8(&code, &block_type) != 0) {
          return -1;
        }
        UINT32 start_pc = code.ofs;
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        (void)block_type;
        if (control_depth >= 16) {
          return -1;
        }
        control[control_depth].kind = ER_CONTROL_KIND_BLOCK;
        control[control_depth].start_pc = start_pc;
        control[control_depth].end_pc = matching_end;
        control[control_depth].stack_depth = stack_size;
        ++control_depth;
      } else if (op == 0x03) {
        UINT8 loop_type = 0;
        if (er_reader_read_u8(&code, &loop_type) != 0) {
          return -1;
        }
        UINT32 start_pc = code.ofs;
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        (void)loop_type;
        if (control_depth >= 16) {
          return -1;
        }
        control[control_depth].kind = ER_CONTROL_KIND_LOOP;
        control[control_depth].start_pc = start_pc;
        control[control_depth].end_pc = matching_end;
        control[control_depth].stack_depth = stack_size;
        ++control_depth;
      } else if (op == 0x04) {
        UINT8 if_type = 0;
        if (er_reader_read_u8(&code, &if_type) != 0) {
          return -1;
        }
        if (control_depth >= 16) {
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
      } else if (op == 0x05) {
        if (control_depth == 0 || control[control_depth - 1].kind != ER_CONTROL_KIND_IF) {
          return -1;
        }
        code.ofs = control[control_depth - 1].end_pc;
      } else if (op == 0x0d) {
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
      } else if (op == 0x0c) {
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
      } else if (op == 0x0b) {
        if (control_depth == 0) {
          if (stack_size == 0) {
            *result = 0;
            return 0;
          }
          *result = stack[stack_size - 1];
          return 0;
        }
        --control_depth;
      } else if (op == 0x1a) {
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
