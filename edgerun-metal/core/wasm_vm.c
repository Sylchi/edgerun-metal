#include "internal/wasm_vm_internal.h"

static const ErHostImport ER_HOST_IMPORTS[] = {
#define ER_HOST_IMPORT_ROW(kind, module, field, params, results, contracts) \
  {module, ER_WASM_STRING_LEN(module), field, ER_WASM_STRING_LEN(field), kind},
  ER_WASM_CONTRACT_IMPORTS(ER_HOST_IMPORT_ROW)
#undef ER_HOST_IMPORT_ROW
};
static const UINT32 ER_HOST_IMPORT_COUNT = (UINT32)(sizeof(ER_HOST_IMPORTS) / sizeof(ER_HOST_IMPORTS[0]));

static UINT8 er_match_name(const UINT8* actual_name, UINT32 actual_len,
                           const char* expected_name, UINT32 expected_len) {
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

static UINT8 er_find_host_import(const UINT8* module_name, UINT32 module_len,
                                 const UINT8* field_name, UINT32 field_len) {
  const ErHostImport* import = ER_HOST_IMPORTS;
  const ErHostImport* end = ER_HOST_IMPORTS + ER_HOST_IMPORT_COUNT;

  while (import < end) {
    if (er_match_name(module_name, module_len, import->module, import->module_len) &&
        er_match_name(field_name, field_len, import->field, import->field_len)) {
      return import->kind;
    }
    ++import;
  }
  return ER_WASM_IMPORT_KIND_NONE;
}

static void er_clear_module(ErWasmModule* module) {
  if (module == 0) {
    return;
  }

  module->num_types = 0;
  module->num_imports = 0;
  module->num_funcs = 0;
  module->num_exports = 0;
  module->memory_min_pages = 0;
  module->memory_size = 0;
  module->memory = 0;
  er_mem_zero((UINT8*)&module->linear_memory, (UINTN)sizeof(module->linear_memory));
  module->function_has_main = 0;
  module->main_index = 0;

  for (UINT32 i = 0; i < ER_WASM_MAX_FUNCTIONS; ++i) {
    module->function_type_indices[i] = 0;
    module->function_is_import[i] = 0;
    module->function_import_kind[i] = ER_WASM_IMPORT_KIND_NONE;
    module->type_params_0[i] = 0;
    for (UINT32 p = 0; p < ER_WASM_MAX_TYPE_PARAMS; ++p) {
      module->type_param_types[i][p] = 0;
    }
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
  module->host.bus_exec = 0;
  module->host.relay_send = 0;
  module->host.relay_recv = 0;
  module->host.ui_emit = 0;
  module->host.memory = 0;
  module->host.memory_size = 0;
  er_mem_zero((UINT8*)&module->host.linear_memory, (UINTN)sizeof(module->host.linear_memory));
  module->host.app_usage = 0;
  module->host.app_budget = 0;
  module->host.ui_presentation = 0;
  module->host.driver_policy = 0;
}

static int er_wasm_init_host(ErWasmModule* module, const ErWasmHostCalls* host) {
  if (host != 0) {
    module->host.log_u64 = host->log_u64;
    module->host.log_hex = host->log_hex;
    module->host.pci_read32 = host->pci_read32;
    module->host.pci_write32 = host->pci_write32;
    module->host.mmio_map = host->mmio_map;
    module->host.mmio_read32 = host->mmio_read32;
    module->host.bus_exec = host->bus_exec;
    module->host.relay_send = host->relay_send;
    module->host.relay_recv = host->relay_recv;
    module->host.ui_emit = host->ui_emit;
    module->host.ui_emit_user = host->ui_emit_user;
    module->host.memory = host->memory;
    module->host.memory_size = host->memory_size;
    module->host.linear_memory = host->linear_memory;
    module->host.app_usage = host->app_usage;
    module->host.app_budget = host->app_budget;
    module->host.ui_presentation = host->ui_presentation;
    module->host.driver_policy = host->driver_policy;
    if (host->linear_memory.bytes != 0) {
      if (er_wasm_linear_memory_valid(&host->linear_memory) == 0) {
        return -1;
      }
      module->linear_memory = host->linear_memory;
      module->memory = host->linear_memory.bytes;
      module->memory_size = host->linear_memory.address_len;
    } else if (host->memory != 0 && host->memory_size != 0u) {
      if (er_wasm_prepare_linear_memory(host->memory, host->memory_size,
                                        ER_WASM_LINEAR_MEMORY_BASE, host->memory_size,
                                        ER_WASM_LINEAR_MEMORY_BASE, host->memory_size,
                                        &module->linear_memory) != 0) {
        return -1;
      }
      module->host.linear_memory = module->linear_memory;
      module->memory = host->memory;
      module->memory_size = host->memory_size;
    }
    if (module->host.driver_policy != 0 &&
        er_driver_policy_memory_allowed(module->host.driver_policy,
                                        module->memory_size) == 0u) {
      return -1;
    }
  }
  return 0;
}

static int er_wasm_header_valid(const UINT8* data, UINT32 size) {
  if (data == 0 || size < ER_WASM_MAGIC_BYTES) {
    return -1;
  }
  if (data[ER_WASM_HEADER_BYTE0] != ER_WASM_MAGIC_0 ||
      data[ER_WASM_HEADER_BYTE1] != ER_WASM_MAGIC_1 ||
      data[ER_WASM_HEADER_BYTE2] != ER_WASM_MAGIC_2 ||
      data[ER_WASM_HEADER_BYTE3] != ER_WASM_MAGIC_3) {
    return -1;
  }

  if (data[ER_WASM_HEADER_BYTE4] != ER_WASM_VERSION_0 ||
      data[ER_WASM_HEADER_BYTE5] != ER_WASM_VERSION_1 ||
      data[ER_WASM_HEADER_BYTE6] != ER_WASM_VERSION_2 ||
      data[ER_WASM_HEADER_BYTE7] != ER_WASM_VERSION_3) {
    return -1;
  }
  return 0;
}

static int er_wasm_parse_type_section(ErReader* r, ErWasmModule* module,
                                      ErFuncType* func_types) {
  ErFuncType temp_type[ER_WASM_MAX_FUNCTIONS];
  UINT32 type_count = 0;

  if (er_reader_read_u32_leb(r, &type_count) != 0) {
    return -1;
  }
  if (type_count > ER_WASM_MAX_FUNCTIONS) {
    return -1;
  }
  er_mem_zero((UINT8*)temp_type, (UINTN)sizeof(temp_type));
  for (UINT32 i = 0; i < type_count; ++i) {
    UINT8 form;
    UINT32 param_count;
    UINT32 result_count;

    if (er_reader_read_u8(r, &form) != 0) {
      return -1;
    }
    if (form != ER_WASM_TYPE_FORM_FUNC) {
      return -1;
    }
    if (er_reader_read_u32_leb(r, &param_count) != 0) {
      return -1;
    }
    if (param_count > ER_WASM_MAX_TYPE_PARAMS) {
      return -1;
    }

    for (UINT32 p = 0; p < param_count; ++p) {
      UINT8 param_type;
      if (er_reader_read_u8(r, &param_type) != 0) {
        return -1;
      }
      if (param_type != ER_WASM_VALTYPE_I64 && param_type != ER_WASM_VALTYPE_I32 &&
          param_type != ER_WASM_VALTYPE_F32 && param_type != ER_WASM_VALTYPE_F64) {
        return -1;
      }
      temp_type[i].param_types[p] = param_type;
    }

    if (er_reader_read_u32_leb(r, &result_count) != 0) {
      return -1;
    }
    if (result_count > ER_WASM_MAX_TYPE_RESULTS) {
      return -1;
    }

    temp_type[i].form = form;
    temp_type[i].param_count = (UINT8)param_count;
    temp_type[i].result_count = (UINT8)result_count;
    temp_type[i].result_type = 0;

    if (result_count == 1) {
      if (er_reader_read_u8(r, &temp_type[i].result_type) != 0) {
        return -1;
      }
    }
  }
  for (UINT32 i = 0; i < type_count; ++i) {
    func_types[i] = temp_type[i];
  }
  module->num_types = type_count;
  return 0;
}

static int er_wasm_parse_import_section(ErReader* r, ErWasmModule* module) {
  UINT32 import_count = 0;

  if (er_reader_read_u32_leb(r, &import_count) != 0) {
    return -1;
  }
  if (import_count > ER_WASM_MAX_FUNCTIONS) {
    return -1;
  }
  for (UINT32 import_i = 0; import_i < import_count; ++import_i) {
    UINT8 import_kind = ER_WASM_IMPORT_KIND_NONE;
    UINT8 kind = 0;
    UINT32 type_index = 0;
    UINT32 function_index = 0;
    const UINT8* module_name = 0;
    UINT32 module_len = 0;
    const UINT8* field_name = 0;
    UINT32 field_len = 0;

    if (module->num_funcs >= ER_WASM_MAX_FUNCTIONS) {
      return -1;
    }
    if (er_read_string(r, &module_name, &module_len) != 0 ||
        er_read_string(r, &field_name, &field_len) != 0) {
      return -1;
    }

    import_kind = er_find_host_import(module_name, module_len, field_name, field_len);

    if (er_reader_read_u8(r, &kind) != 0) {
      return -1;
    }
    if (kind != ER_WASM_EXTERNAL_KIND_FUNC) {
      return -1;
    }
    if (er_reader_read_u32_leb(r, &type_index) != 0 || type_index >= module->num_types) {
      return -1;
    }

    function_index = module->num_funcs;
    module->function_type_indices[function_index] = type_index;
    module->function_is_import[function_index] = 1;
    module->function_import_kind[function_index] = import_kind;
    module->num_funcs += 1;
    module->num_imports += 1;
  }
  return 0;
}

static int er_wasm_parse_function_section(ErReader* r, ErWasmModule* module) {
  UINT32 func_count = 0;

  if (er_reader_read_u32_leb(r, &func_count) != 0) {
    return -1;
  }
  if (func_count > ER_WASM_MAX_FUNCTIONS ||
      module->num_funcs + func_count > ER_WASM_MAX_FUNCTIONS) {
    return -1;
  }
  for (UINT32 func_i = 0; func_i < func_count; ++func_i) {
    UINT32 type_index = 0;
    if (er_reader_read_u32_leb(r, &type_index) != 0 || type_index >= module->num_types) {
      return -1;
    }
    module->function_type_indices[module->num_funcs] = type_index;
    module->function_is_import[module->num_funcs] = 0;
    module->function_import_kind[module->num_funcs] = ER_WASM_IMPORT_KIND_NONE;
    module->num_funcs += 1;
  }
  return 0;
}

static int er_wasm_parse_memory_section(ErReader* r, ErWasmModule* module) {
  UINT32 memory_count = 0;
  UINT8 flags = 0;
  UINT32 min_pages = 0;
  UINT32 max_pages = 0;

  if (er_reader_read_u32_leb(r, &memory_count) != 0 || memory_count > 1u) {
    return -1;
  }
  if (memory_count == 0u) {
    return 0;
  }
  if (er_reader_read_u8(r, &flags) != 0 ||
      (flags & (UINT8)~ER_WASM_MEMORY_LIMIT_HAS_MAX) != 0u) {
    return -1;
  }
  if (er_reader_read_u32_leb(r, &min_pages) != 0) {
    return -1;
  }
  if ((flags & ER_WASM_MEMORY_LIMIT_HAS_MAX) != 0u &&
      er_reader_read_u32_leb(r, &max_pages) != 0) {
    return -1;
  }
  if (min_pages > 0u) {
    UINT64 required_bytes = (UINT64)min_pages * ER_WASM_MEMORY_PAGE_BYTES;
    if (module->memory == 0 || required_bytes > (UINT64)module->memory_size) {
      return -1;
    }
    er_mem_zero(module->memory, (UINTN)required_bytes);
  }
  module->memory_min_pages = min_pages;
  return 0;
}

static int er_wasm_parse_export_section(ErReader* r, ErWasmModule* module) {
  UINT32 export_count = 0;

  if (er_reader_read_u32_leb(r, &export_count) != 0) {
    return -1;
  }
  if (export_count > ER_WASM_MAX_FUNCTIONS) {
    return -1;
  }
  module->num_exports = export_count;

  for (UINT32 i = 0; i < export_count; ++i) {
    UINT32 name_len = 0;
    UINT8 is_main = 0;
    UINT8 kind = 0;
    UINT32 index = 0;

    if (er_reader_read_u32_leb(r, &name_len) != 0) {
      return -1;
    }
    if (name_len == ER_WASM_MAIN_NAME_LEN &&
        r->ofs + ER_WASM_MAIN_NAME_LEN <= r->size &&
        r->data[r->ofs] == ER_WASM_MAIN_NAME_BYTE0 &&
        r->data[r->ofs + ER_WASM_U32_BYTE1] == ER_WASM_MAIN_NAME_BYTE1 &&
        r->data[r->ofs + ER_WASM_U32_BYTE2] == ER_WASM_MAIN_NAME_BYTE2 &&
        r->data[r->ofs + ER_WASM_U32_BYTE3] == ER_WASM_MAIN_NAME_BYTE3) {
      r->ofs += ER_WASM_MAIN_NAME_LEN;
      is_main = 1;
    } else {
      r->ofs += name_len;
    }

    if (er_reader_read_u8(r, &kind) != 0) {
      return -1;
    }
    if (er_reader_read_u32_leb(r, &index) != 0) {
      return -1;
    }

    if (is_main) {
      if (kind != ER_WASM_EXTERNAL_KIND_FUNC) {
        return -1;
      }
      module->function_has_main = 1;
      module->main_index = index;
    }
  }
  return 0;
}

static int er_wasm_parse_code_section(ErReader* r, ErWasmModule* module) {
  UINT32 body_count = 0;

  if (er_reader_read_u32_leb(r, &body_count) != 0) {
    return -1;
  }
  if (body_count > ER_WASM_MAX_FUNCTIONS ||
      body_count > module->num_funcs - module->num_imports) {
    return -1;
  }
  for (UINT32 i = 0; i < body_count; ++i) {
    UINT32 body_size = 0;
    UINT32 body_start = 0;
    UINT32 body_end = 0;
    UINT32 local_count = 0;
    UINT32 local_total = 0;

    if (er_reader_read_u32_leb(r, &body_size) != 0) {
      return -1;
    }
    if (r->ofs + body_size > r->size) {
      return -1;
    }
    body_start = r->ofs;
    body_end = body_start + body_size;

    if (er_reader_read_u32_leb(r, &local_count) != 0) {
      return -1;
    }
    for (UINT32 l = 0; l < local_count; ++l) {
      UINT32 local_repeat = 0;
      UINT8 local_type = 0;
      if (er_reader_read_u32_leb(r, &local_repeat) != 0 ||
          er_reader_read_u8(r, &local_type) != 0) {
        return -1;
      }
      if (local_type != ER_WASM_VALTYPE_I64 && local_type != ER_WASM_VALTYPE_I32) {
        return -1;
      }
      local_total += local_repeat;
      if (local_total > ER_WASM_MAX_LOCALS) {
        return -1;
      }
    }

    module->code[module->num_imports + i].body = &r->data[r->ofs];
    if (r->ofs > body_end) {
      return -1;
    }
    module->code[module->num_imports + i].size = body_end - r->ofs;
    module->code[module->num_imports + i].local_count = (UINT8)local_total;
    r->ofs = body_end;
  }
  return 0;
}

static int er_wasm_parse_data_section(ErReader* r, ErWasmModule* module) {
  UINT32 segment_count = 0;

  if (er_reader_read_u32_leb(r, &segment_count) != 0 ||
      segment_count > ER_WASM_MAX_DATA_SEGMENTS) {
    return -1;
  }
  for (UINT32 segment_i = 0; segment_i < segment_count; ++segment_i) {
    UINT32 flags = 0;
    UINT8 op = 0;
    UINT32 offset = 0;
    UINT32 len = 0;
    UINT8* dst = 0;

    if (er_reader_read_u32_leb(r, &flags) != 0 || flags != 0u) {
      return -1;
    }
    if (er_reader_read_u8(r, &op) != 0 || op != ER_WASM_OP_I32_CONST) {
      return -1;
    }
    if (er_reader_read_u32_leb(r, &offset) != 0) {
      return -1;
    }
    if (er_reader_read_u8(r, &op) != 0 || op != ER_WASM_OP_END) {
      return -1;
    }
    if (er_reader_read_u32_leb(r, &len) != 0) {
      return -1;
    }
    if (len > r->size - r->ofs || er_wasm_memory_range(module, offset, len, &dst) != 0) {
      return -1;
    }
    for (UINT32 byte_i = 0; byte_i < len; ++byte_i) {
      dst[byte_i] = r->data[r->ofs + byte_i];
    }
    r->ofs += len;
  }
  return 0;
}

static int er_wasm_parse_section(ErReader* r, ErWasmModule* module,
                                 ErFuncType* func_types, UINT8 section_id,
                                 UINT32 section_len) {
  switch (section_id) {
    case ER_WASM_SECTION_TYPE:
      return er_wasm_parse_type_section(r, module, func_types);
    case ER_WASM_SECTION_IMPORT:
      return er_wasm_parse_import_section(r, module);
    case ER_WASM_SECTION_FUNCTION:
      return er_wasm_parse_function_section(r, module);
    case ER_WASM_SECTION_MEMORY:
      return er_wasm_parse_memory_section(r, module);
    case ER_WASM_SECTION_EXPORT:
      return er_wasm_parse_export_section(r, module);
    case ER_WASM_SECTION_CODE:
      return er_wasm_parse_code_section(r, module);
    case ER_WASM_SECTION_DATA:
      return er_wasm_parse_data_section(r, module);
    default:
      return er_reader_skip(r, section_len);
  }
}

static void er_wasm_commit_type_metadata(ErWasmModule* module,
                                         const ErFuncType* func_types) {
  for (UINT32 i = 0; i < module->num_types; ++i) {
    if (i < ER_WASM_MAX_FUNCTIONS) {
      module->type_params_0[i] = func_types[i].param_count;
      for (UINT32 p = 0; p < ER_WASM_MAX_TYPE_PARAMS; ++p) {
        module->type_param_types[i][p] = func_types[i].param_types[p];
      }
      module->type_result_count[i] = func_types[i].result_count;
      module->type_result_type[i] = func_types[i].result_type;
    }
  }
}

int er_wasm_init(ErWasmModule* module, const UINT8* data, UINT32 size, const ErWasmHostCalls* host) {
  ErReader r;
  ErFuncType func_types[ER_WASM_MAX_FUNCTIONS];

  if (module == 0) {
    return -1;
  }
  er_clear_module(module);

  if (er_wasm_init_host(module, host) != 0 ||
      er_reader_init(&r, data, size) != 0 ||
      er_wasm_header_valid(data, size) != 0) {
    return -1;
  }

  r.ofs = ER_WASM_MAGIC_BYTES;
  while (r.ofs < r.size) {
    UINT8 section_id = 0;
    UINT32 section_len = 0;
    UINT32 section_end = 0;

    if (er_reader_read_u8(&r, &section_id) != 0 ||
        er_reader_read_u32_leb(&r, &section_len) != 0) {
      return -1;
    }
    if (section_len > r.size - r.ofs) {
      return -1;
    }

    section_end = r.ofs + section_len;
    if (er_wasm_parse_section(&r, module, func_types, section_id, section_len) != 0) {
      return -1;
    }
    if (r.ofs != section_end) {
      r.ofs = section_end;
    }
  }

  er_wasm_commit_type_metadata(module, func_types);
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

//@optimizer-ignore-function Wasm interpreter dispatches bytecode, host calls, and structured control blocks
