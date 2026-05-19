#include "wasm_compile.h"

static int erwc_emit_section(ErWcBuffer* out, uint8_t id, const ErWcBuffer* payload) {
  if (erwc_buffer_push(out, id) != 0 ||
      erwc_emit_u32_leb(out, (uint32_t)payload->len) != 0 ||
      erwc_buffer_append(out, payload->bytes, payload->len) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_emit_type_section(ErWcBuffer* out, const ErWcModule* module) {
  ErWcBuffer payload = {{0}, 0u};
  uint32_t i;

  if (erwc_emit_u32_leb(&payload, module->type_count) != 0) {
    return -1;
  }
  for (i = 0u; i < module->type_count; ++i) {
    uint32_t p;
    if (erwc_buffer_push(&payload, ERWC_TYPE_FORM_FUNC) != 0 ||
        erwc_emit_u32_leb(&payload, module->types[i].param_count) != 0) {
      return -1;
    }
    for (p = 0u; p < module->types[i].param_count; ++p) {
      if (erwc_buffer_push(&payload, module->types[i].params[p]) != 0) {
        return -1;
      }
    }
    if (erwc_emit_u32_leb(&payload, module->types[i].result_count) != 0) {
      return -1;
    }
    if (module->types[i].result_count != 0u &&
        erwc_buffer_push(&payload, module->types[i].result_type) != 0) {
      return -1;
    }
  }
  return erwc_emit_section(out, ERWC_SECTION_TYPE, &payload);
}

static int erwc_emit_import_section(ErWcBuffer* out, const ErWcModule* module) {
  ErWcBuffer payload = {{0}, 0u};
  uint32_t i;

  if (erwc_emit_u32_leb(&payload, module->import_count) != 0) {
    return -1;
  }
  for (i = 0u; i < module->import_count; ++i) {
    if (erwc_emit_name(&payload, module->imports[i].module) != 0 ||
        erwc_emit_name(&payload, module->imports[i].field) != 0 ||
        erwc_buffer_push(&payload, ERWC_EXTERNAL_FUNC) != 0 ||
        erwc_emit_u32_leb(&payload, module->imports[i].type_index) != 0) {
      return -1;
    }
  }
  return erwc_emit_section(out, ERWC_SECTION_IMPORT, &payload);
}

static int erwc_emit_function_section(ErWcBuffer* out, const ErWcModule* module) {
  ErWcBuffer payload = {{0}, 0u};
  uint32_t i;

  if (erwc_emit_u32_leb(&payload, module->func_count) != 0) {
    return -1;
  }
  for (i = 0u; i < module->func_count; ++i) {
    if (erwc_emit_u32_leb(&payload, module->funcs[i].type_index) != 0) {
      return -1;
    }
  }
  return erwc_emit_section(out, ERWC_SECTION_FUNCTION, &payload);
}

static int erwc_emit_memory_section(ErWcBuffer* out, const ErWcModule* module) {
  ErWcBuffer payload = {{0}, 0u};

  if (erwc_emit_u32_leb(&payload, 1u) != 0 ||
      erwc_buffer_push(&payload, 0u) != 0 ||
      erwc_emit_u32_leb(&payload, module->memory_pages) != 0) {
    return -1;
  }
  return erwc_emit_section(out, ERWC_SECTION_MEMORY, &payload);
}

static int erwc_emit_export_section(ErWcBuffer* out, const ErWcModule* module) {
  ErWcBuffer payload = {{0}, 0u};
  uint32_t i;
  uint32_t main_index = 0u;
  uint32_t found = 0u;

  for (i = 0u; i < module->func_count; ++i) {
    if (module->funcs[i].exported_main != 0u) {
      main_index = module->funcs[i].function_index;
      ++found;
    }
  }
  if (found != 1u ||
      erwc_emit_u32_leb(&payload, 1u) != 0 ||
      erwc_emit_name(&payload, "main") != 0 ||
      erwc_buffer_push(&payload, ERWC_EXTERNAL_FUNC) != 0 ||
      erwc_emit_u32_leb(&payload, main_index) != 0) {
    return -1;
  }
  return erwc_emit_section(out, ERWC_SECTION_EXPORT, &payload);
}

static int erwc_emit_code_section(ErWcBuffer* out, const ErWcModule* module) {
  ErWcBuffer payload = {{0}, 0u};
  uint32_t i;

  if (erwc_emit_u32_leb(&payload, module->func_count) != 0) {
    return -1;
  }
  for (i = 0u; i < module->func_count; ++i) {
    ErWcBuffer body = {{0}, 0u};
    uint32_t local_i;
    if (module->funcs[i].param_count > module->funcs[i].local_count ||
        erwc_emit_u32_leb(&body, module->funcs[i].local_count -
                          module->funcs[i].param_count) != 0) {
      return -1;
    }
    for (local_i = module->funcs[i].param_count;
         local_i < module->funcs[i].local_count; ++local_i) {
      if (erwc_emit_u32_leb(&body, 1u) != 0 ||
          erwc_buffer_push(&body, module->funcs[i].locals[local_i].type) != 0) {
        return -1;
      }
    }
    if (erwc_buffer_append(&body, module->funcs[i].code.bytes, module->funcs[i].code.len) != 0 ||
        erwc_emit_u32_leb(&payload, (uint32_t)body.len) != 0 ||
        erwc_buffer_append(&payload, body.bytes, body.len) != 0) {
      return -1;
    }
  }
  return erwc_emit_section(out, ERWC_SECTION_CODE, &payload);
}

int erwc_emit_wasm(const ErWcModule* module, ErWcBuffer* out) {
  static const uint8_t header[] = {0x00u, 0x61u, 0x73u, 0x6du, 0x01u, 0x00u, 0x00u, 0x00u};

  memset(out, 0, sizeof(*out));
  if (erwc_buffer_append(out, header, sizeof(header)) != 0 ||
      erwc_emit_type_section(out, module) != 0 ||
      erwc_emit_import_section(out, module) != 0 ||
      erwc_emit_function_section(out, module) != 0 ||
      erwc_emit_memory_section(out, module) != 0 ||
      erwc_emit_export_section(out, module) != 0 ||
      erwc_emit_code_section(out, module) != 0) {
    return -1;
  }
  return 0;
}
