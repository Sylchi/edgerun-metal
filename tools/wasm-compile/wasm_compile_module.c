#include "wasm_compile.h"

typedef struct {
  ErWasmImportKind kind;
  const char* module;
  const char* field;
} ErWcHostImport;

static const ErWcHostImport ERWC_HOST_IMPORTS[] = {
#define ERWC_HOST_IMPORT_ROW(kind, module, field, params, results, contracts) \
  {kind, module, field},
  ER_WASM_CONTRACT_IMPORTS(ERWC_HOST_IMPORT_ROW)
#undef ERWC_HOST_IMPORT_ROW
};
static const uint32_t ERWC_HOST_IMPORT_COUNT =
  (uint32_t)(sizeof(ERWC_HOST_IMPORTS) / sizeof(ERWC_HOST_IMPORTS[0]));

static ErWasmImportKind erwc_host_import_kind(const char* module, const char* field) {
  for (uint32_t i = 0u; i < ERWC_HOST_IMPORT_COUNT; ++i) {
    if (strcmp(module, ERWC_HOST_IMPORTS[i].module) == 0 &&
        strcmp(field, ERWC_HOST_IMPORTS[i].field) == 0) {
      return ERWC_HOST_IMPORTS[i].kind;
    }
  }
  return ER_WASM_IMPORT_KIND_NONE;
}

static int erwc_parse_type_ref(const ErWcParse* parse, int list_node, char* out_name, size_t out_len) {
  int child;

  if (list_node < 0 || parse->nodes[list_node].is_list == 0) {
    return -1;
  }
  child = parse->nodes[list_node].first_child;
  if (!erwc_node_atom_equals(parse, child, "type")) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (child < 0 || parse->nodes[child].next_sibling >= 0) {
    return -1;
  }
  return erwc_copy_token_text(parse, child, out_name, out_len);
}

static int erwc_parse_type_decl(const ErWcParse* parse, int list_node, ErWcModule* module) {
  ErWcType* type;
  int child;
  int func_list;
  int func_child;

  if (module->type_count >= ERWC_MAX_TYPES) {
    return -1;
  }
  type = &module->types[module->type_count];
  memset(type, 0, sizeof(*type));
  child = parse->nodes[list_node].first_child;
  if (!erwc_node_atom_equals(parse, child, "type")) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (erwc_copy_token_text(parse, child, type->name, sizeof(type->name)) != 0) {
    return -1;
  }
  func_list = parse->nodes[child].next_sibling;
  if (func_list < 0 || parse->nodes[func_list].is_list == 0 ||
      parse->nodes[func_list].next_sibling >= 0) {
    return -1;
  }
  func_child = parse->nodes[func_list].first_child;
  if (!erwc_node_atom_equals(parse, func_child, "func")) {
    return -1;
  }
  for (func_child = parse->nodes[func_child].next_sibling;
       func_child >= 0;
       func_child = parse->nodes[func_child].next_sibling) {
    int head;
    int value;
    if (parse->nodes[func_child].is_list == 0) {
      return -1;
    }
    head = parse->nodes[func_child].first_child;
    if (erwc_node_atom_equals(parse, head, "param")) {
      for (value = parse->nodes[head].next_sibling; value >= 0;
           value = parse->nodes[value].next_sibling) {
        char text[ERWC_MAX_STRING];
        uint8_t valtype;
        if (type->param_count >= (uint32_t)(sizeof(type->params) / sizeof(type->params[0])) ||
            erwc_copy_token_text(parse, value, text, sizeof(text)) != 0) {
          return -1;
        }
        valtype = erwc_valtype_from_name(text);
        if (valtype == 0u) {
          return -1;
        }
        type->params[type->param_count++] = valtype;
      }
    } else if (erwc_node_atom_equals(parse, head, "result")) {
      char text[ERWC_MAX_STRING];
      value = parse->nodes[head].next_sibling;
      if (value < 0 || parse->nodes[value].next_sibling >= 0 ||
          erwc_copy_token_text(parse, value, text, sizeof(text)) != 0) {
        return -1;
      }
      type->result_type = erwc_valtype_from_name(text);
      if (type->result_type == 0u) {
        return -1;
      }
      type->result_count = 1u;
    } else {
      return -1;
    }
  }
  ++module->type_count;
  return 0;
}

static int erwc_parse_import_decl(const ErWcParse* parse, int list_node, ErWcModule* module) {
  ErWcImport* import;
  int child;
  int func_list;
  int func_child;

  if (module->import_count >= ERWC_MAX_IMPORTS) {
    return -1;
  }
  import = &module->imports[module->import_count];
  memset(import, 0, sizeof(*import));
  child = parse->nodes[list_node].first_child;
  if (!erwc_node_atom_equals(parse, child, "import")) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (erwc_copy_token_text(parse, child, import->module, sizeof(import->module)) != 0) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (erwc_copy_token_text(parse, child, import->field, sizeof(import->field)) != 0) {
    return -1;
  }
  func_list = parse->nodes[child].next_sibling;
  if (func_list < 0 || parse->nodes[func_list].is_list == 0 ||
      parse->nodes[func_list].next_sibling >= 0) {
    return -1;
  }
  func_child = parse->nodes[func_list].first_child;
  if (!erwc_node_atom_equals(parse, func_child, "func")) {
    return -1;
  }
  func_child = parse->nodes[func_child].next_sibling;
  if (erwc_copy_token_text(parse, func_child, import->name, sizeof(import->name)) != 0) {
    return -1;
  }
  func_child = parse->nodes[func_child].next_sibling;
  if (erwc_parse_type_ref(parse, func_child, import->type_name, sizeof(import->type_name)) != 0 ||
      parse->nodes[func_child].next_sibling >= 0 ||
      erwc_find_type(module, import->type_name, &import->type_index) != 0) {
    return -1;
  }
  import->import_kind = erwc_host_import_kind(import->module, import->field);
  if (import->import_kind == ER_WASM_IMPORT_KIND_NONE) {
    return -1;
  }
  import->function_index = module->import_count;
  ++module->import_count;
  return 0;
}

static int erwc_parse_memory_decl(const ErWcParse* parse, int list_node, ErWcModule* module) {
  int child = parse->nodes[list_node].first_child;
  uint32_t pages = 0u;

  if (!erwc_node_atom_equals(parse, child, "memory")) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (child < 0 || parse->nodes[child].next_sibling >= 0 ||
      erwc_node_u32(parse, child, &pages) != 0 ||
      pages == 0u || pages > 1u) {
    return -1;
  }
  module->memory_pages = pages;
  return 0;
}

static int erwc_parse_memory_immediate(const ErWcParse* parse, int node_index,
                                       uint32_t* offset, uint32_t* align) {
  char text[ERWC_MAX_STRING];

  if (erwc_copy_token_text(parse, node_index, text, sizeof(text)) != 0) {
    return -1;
  }
  if (strncmp(text, "offset=", 7u) == 0) {
    return erwc_parse_u32_text(text + 7u, offset);
  }
  if (strncmp(text, "align=", 6u) == 0) {
    return erwc_parse_u32_text(text + 6u, align);
  }
  return -1;
}

static int erwc_compile_expr(const ErWcParse* parse, const ErWcModule* module,
                             ErWcFunc* func, int expr_node) {
  int child;
  const char* op_name = NULL;
  char op_text[ERWC_MAX_STRING];

  if (expr_node < 0 || parse->nodes[expr_node].is_list == 0) {
    return -1;
  }
  child = parse->nodes[expr_node].first_child;
  if (child < 0 || erwc_copy_token_text(parse, child, op_text, sizeof(op_text)) != 0) {
    return -1;
  }
  op_name = op_text;
  child = parse->nodes[child].next_sibling;

  if (strcmp(op_name, "i32.const") == 0) {
    uint32_t value = 0u;
    if (child < 0 || parse->nodes[child].next_sibling >= 0 ||
        erwc_node_u32(parse, child, &value) != 0 ||
        erwc_buffer_push(&func->code, ERWC_OP_I32_CONST) != 0 ||
        erwc_emit_u32_leb(&func->code, value) != 0) {
      return -1;
    }
  } else if (strcmp(op_name, "i64.const") == 0) {
    int64_t value = 0;
    if (child < 0 || parse->nodes[child].next_sibling >= 0 ||
        erwc_node_i64(parse, child, &value) != 0 ||
        erwc_buffer_push(&func->code, ERWC_OP_I64_CONST) != 0 ||
        erwc_emit_i64_leb(&func->code, value) != 0) {
      return -1;
    }
  } else if (strcmp(op_name, "local.get") == 0 ||
             strcmp(op_name, "local.set") == 0 ||
             strcmp(op_name, "local.tee") == 0) {
    char name[ERWC_MAX_STRING];
    uint32_t index = 0u;
    uint8_t op = ERWC_OP_LOCAL_GET;

    if (strcmp(op_name, "local.set") == 0) {
      op = ERWC_OP_LOCAL_SET;
    } else if (strcmp(op_name, "local.tee") == 0) {
      op = ERWC_OP_LOCAL_TEE;
    }
    if (child < 0 || parse->nodes[child].next_sibling >= 0 ||
        erwc_copy_token_text(parse, child, name, sizeof(name)) != 0 ||
        erwc_find_local(func, name, &index) != 0 ||
        erwc_buffer_push(&func->code, op) != 0 ||
        erwc_emit_u32_leb(&func->code, index) != 0) {
      return -1;
    }
  } else if (strcmp(op_name, "call") == 0) {
    char name[ERWC_MAX_STRING];
    uint32_t index = 0u;
    if (child < 0 || parse->nodes[child].next_sibling >= 0 ||
        erwc_copy_token_text(parse, child, name, sizeof(name)) != 0 ||
        erwc_find_function(module, name, &index) != 0 ||
        erwc_buffer_push(&func->code, ERWC_OP_CALL) != 0 ||
        erwc_emit_u32_leb(&func->code, index) != 0) {
      return -1;
    }
  } else if (strcmp(op_name, "drop") == 0 ||
             strcmp(op_name, "i32.wrap_i64") == 0) {
    uint8_t op = strcmp(op_name, "drop") == 0 ? ERWC_OP_DROP : ERWC_OP_I32_WRAP_I64;
    if (child >= 0 || erwc_buffer_push(&func->code, op) != 0) {
      return -1;
    }
  } else if (strcmp(op_name, "i32.store") == 0 ||
             strcmp(op_name, "i32.store16") == 0 ||
             strcmp(op_name, "i64.store") == 0 ||
             strcmp(op_name, "i32.load") == 0 ||
             strcmp(op_name, "i64.load") == 0) {
    uint8_t op = ERWC_OP_I32_STORE;
    uint32_t align = 0u;
    uint32_t offset = 0u;

    if (strcmp(op_name, "i32.store16") == 0) {
      op = ERWC_OP_I32_STORE16;
    } else if (strcmp(op_name, "i64.store") == 0) {
      op = ERWC_OP_I64_STORE;
    } else if (strcmp(op_name, "i32.load") == 0) {
      op = ERWC_OP_I32_LOAD;
    } else if (strcmp(op_name, "i64.load") == 0) {
      op = ERWC_OP_I64_LOAD;
    }
    while (child >= 0) {
      if (erwc_parse_memory_immediate(parse, child, &offset, &align) != 0) {
        return -1;
      }
      child = parse->nodes[child].next_sibling;
    }
    if (erwc_buffer_push(&func->code, op) != 0 ||
        erwc_emit_u32_leb(&func->code, align) != 0 ||
        erwc_emit_u32_leb(&func->code, offset) != 0) {
      return -1;
    }
  } else {
    return -1;
  }
  return 0;
}

static int erwc_parse_local_decl(const ErWcParse* parse, int list_node, ErWcFunc* func) {
  int child = parse->nodes[list_node].first_child;
  char type_name[ERWC_MAX_STRING];
  ErWcLocal* local;

  if (!erwc_node_atom_equals(parse, child, "local") ||
      func->local_count >= ERWC_MAX_LOCALS) {
    return -1;
  }
  local = &func->locals[func->local_count];
  memset(local, 0, sizeof(*local));
  child = parse->nodes[child].next_sibling;
  if (erwc_copy_token_text(parse, child, local->name, sizeof(local->name)) != 0) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (child < 0 || parse->nodes[child].next_sibling >= 0 ||
      erwc_copy_token_text(parse, child, type_name, sizeof(type_name)) != 0) {
    return -1;
  }
  local->type = erwc_valtype_from_name(type_name);
  if (local->type == 0u) {
    return -1;
  }
  ++func->local_count;
  return 0;
}

static int erwc_parse_func_decl(const ErWcParse* parse, int list_node, ErWcModule* module) {
  ErWcFunc* func;
  int child;
  int body_started = 0;

  if (module->func_count >= ERWC_MAX_FUNCS) {
    return -1;
  }
  func = &module->funcs[module->func_count];
  memset(func, 0, sizeof(*func));
  child = parse->nodes[list_node].first_child;
  if (!erwc_node_atom_equals(parse, child, "func")) {
    return -1;
  }
  child = parse->nodes[child].next_sibling;
  if (child >= 0 && parse->nodes[child].is_list == 0) {
    if (erwc_copy_token_text(parse, child, func->name, sizeof(func->name)) != 0) {
      return -1;
    }
    child = parse->nodes[child].next_sibling;
  }
  for (; child >= 0; child = parse->nodes[child].next_sibling) {
    int head;

    if (parse->nodes[child].is_list == 0) {
      return -1;
    }
    head = parse->nodes[child].first_child;
    if (erwc_node_atom_equals(parse, head, "export")) {
      int name_node = parse->nodes[head].next_sibling;
      if (name_node < 0 || parse->nodes[name_node].next_sibling >= 0 ||
          !erwc_node_atom_equals(parse, name_node, "main")) {
        return -1;
      }
      func->exported_main = 1u;
    } else if (erwc_node_atom_equals(parse, head, "type")) {
      if (erwc_parse_type_ref(parse, child, func->type_name, sizeof(func->type_name)) != 0) {
        return -1;
      }
    } else if (erwc_node_atom_equals(parse, head, "result")) {
      continue;
    } else if (erwc_node_atom_equals(parse, head, "local")) {
      if (body_started != 0 || erwc_parse_local_decl(parse, child, func) != 0) {
        return -1;
      }
    } else {
      body_started = 1;
      if (erwc_compile_expr(parse, module, func, child) != 0) {
        return -1;
      }
    }
  }
  if (func->type_name[0] == 0 ||
      erwc_find_type(module, func->type_name, &func->type_index) != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_END) != 0) {
    return -1;
  }
  func->function_index = module->import_count + module->func_count;
  ++module->func_count;
  return 0;
}

int erwc_build_module(const ErWcParse* parse, int root, ErWcModule* module) {
  int child;

  memset(module, 0, sizeof(*module));
  if (root < 0 || parse->nodes[root].is_list == 0) {
    return -1;
  }
  child = parse->nodes[root].first_child;
  if (!erwc_node_atom_equals(parse, child, "module")) {
    return -1;
  }
  for (child = parse->nodes[child].next_sibling; child >= 0;
       child = parse->nodes[child].next_sibling) {
    int head;
    if (parse->nodes[child].is_list == 0) {
      return -1;
    }
    head = parse->nodes[child].first_child;
    if (erwc_node_atom_equals(parse, head, "type")) {
      if (erwc_parse_type_decl(parse, child, module) != 0) {
        return -1;
      }
    } else if (erwc_node_atom_equals(parse, head, "import")) {
      if (erwc_parse_import_decl(parse, child, module) != 0) {
        return -1;
      }
    } else if (erwc_node_atom_equals(parse, head, "memory")) {
      if (erwc_parse_memory_decl(parse, child, module) != 0) {
        return -1;
      }
    } else if (erwc_node_atom_equals(parse, head, "func")) {
      if (erwc_parse_func_decl(parse, child, module) != 0) {
        return -1;
      }
    } else {
      return -1;
    }
  }
  if (module->type_count == 0u || module->func_count == 0u || module->memory_pages == 0u) {
    return -1;
  }
  return 0;
}
