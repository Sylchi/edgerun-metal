#include "wasm_compile.h"

typedef struct {
  const char* cur;
  const char* end;
} ErWcCParser;

typedef struct {
  ErWasmImportKind kind;
  const char* module;
  const char* field;
} ErWcCHostImport;

static const ErWcCHostImport ERWC_C_HOST_IMPORTS[] = {
#define ERWC_C_HOST_IMPORT_ROW(kind, module, field, params, results, contracts) \
  {kind, module, field},
  ER_WASM_CONTRACT_IMPORTS(ERWC_C_HOST_IMPORT_ROW)
#undef ERWC_C_HOST_IMPORT_ROW
};
static const uint32_t ERWC_C_HOST_IMPORT_COUNT =
  (uint32_t)(sizeof(ERWC_C_HOST_IMPORTS) / sizeof(ERWC_C_HOST_IMPORTS[0]));

static void erwc_c_skip_ws(ErWcCParser* parser) {
  while (parser->cur < parser->end &&
         (*parser->cur == ' ' || *parser->cur == '\n' ||
          *parser->cur == '\r' || *parser->cur == '\t')) {
    ++parser->cur;
  }
}

static int erwc_c_take_literal(ErWcCParser* parser, const char* literal) {
  size_t len;

  erwc_c_skip_ws(parser);
  len = strlen(literal);
  if ((size_t)(parser->end - parser->cur) < len ||
      memcmp(parser->cur, literal, len) != 0) {
    return -1;
  }
  parser->cur += len;
  return 0;
}

static int erwc_c_take_ident(ErWcCParser* parser, char* out, size_t out_len) {
  size_t len = 0u;

  erwc_c_skip_ws(parser);
  if (parser->cur >= parser->end ||
      !((*parser->cur >= 'A' && *parser->cur <= 'Z') ||
        (*parser->cur >= 'a' && *parser->cur <= 'z') ||
        *parser->cur == '_')) {
    return -1;
  }
  while (parser->cur + len < parser->end &&
         ((parser->cur[len] >= 'A' && parser->cur[len] <= 'Z') ||
          (parser->cur[len] >= 'a' && parser->cur[len] <= 'z') ||
          (parser->cur[len] >= '0' && parser->cur[len] <= '9') ||
          parser->cur[len] == '_')) {
    ++len;
  }
  if (len + 1u > out_len) {
    return -1;
  }
  memcpy(out, parser->cur, len);
  out[len] = 0;
  parser->cur += len;
  return 0;
}

static int erwc_c_take_string(ErWcCParser* parser, char* out, size_t out_len) {
  size_t len = 0u;

  erwc_c_skip_ws(parser);
  if (parser->cur >= parser->end || *parser->cur != '"') {
    return -1;
  }
  ++parser->cur;
  while (parser->cur + len < parser->end && parser->cur[len] != '"') {
    if (parser->cur[len] == '\\') {
      return -1;
    }
    ++len;
  }
  if (parser->cur + len >= parser->end || len + 1u > out_len) {
    return -1;
  }
  memcpy(out, parser->cur, len);
  out[len] = 0;
  parser->cur += len + 1u;
  return 0;
}

static int erwc_c_take_i64_literal(ErWcCParser* parser, int64_t* out) {
  char text[ERWC_MAX_STRING] = {0};
  size_t len = 0u;
  char* end = NULL;
  long long value;

  erwc_c_skip_ws(parser);
  if (parser->cur < parser->end && *parser->cur == '-') {
    text[len++] = *parser->cur++;
  }
  if (parser->cur >= parser->end || *parser->cur < '0' || *parser->cur > '9') {
    return -1;
  }
  while (parser->cur < parser->end &&
         ((*parser->cur >= '0' && *parser->cur <= '9') ||
          (*parser->cur >= 'a' && *parser->cur <= 'f') ||
          (*parser->cur >= 'A' && *parser->cur <= 'F') ||
          *parser->cur == 'x' || *parser->cur == 'X')) {
    if (len + 1u >= sizeof(text)) {
      return -1;
    }
    text[len++] = *parser->cur++;
  }
  errno = 0;
  value = strtoll(text, &end, 0);
  if (end == text || *end != 0 || errno == ERANGE) {
    return -1;
  }
  *out = (int64_t)value;
  return 0;
}

static uint8_t erwc_c_type_from_ident(const char* ident) {
  if (strcmp(ident, "i64") == 0) {
    return ERWC_VALTYPE_I64;
  }
  if (strcmp(ident, "void") == 0) {
    return 0u;
  }
  return ERWC_C_INVALID_TYPE;
}

static ErWasmImportKind erwc_c_host_import_kind(const char* module, const char* field) {
  for (uint32_t i = 0u; i < ERWC_C_HOST_IMPORT_COUNT; ++i) {
    //@optimizer-ignore shared Wasm host import ABI table requires indexed module lookup
    if (strcmp(module, ERWC_C_HOST_IMPORTS[i].module) == 0 &&
        //@optimizer-ignore shared Wasm host import ABI table requires indexed field lookup
        strcmp(field, ERWC_C_HOST_IMPORTS[i].field) == 0) {
      //@optimizer-ignore shared Wasm host import ABI table requires indexed kind lookup
      return ERWC_C_HOST_IMPORTS[i].kind;
    }
  }
  return ER_WASM_IMPORT_KIND_NONE;
}

static int erwc_c_add_type(ErWcModule* module,
                           const char* name,
                           const uint8_t* params,
                           uint32_t param_count,
                           uint8_t result_type,
                           uint8_t result_count,
                           uint32_t* out_index) {
  ErWcType* type;

  if (module->type_count >= ERWC_MAX_TYPES ||
      strlen(name) + 1u > ERWC_MAX_STRING ||
      param_count > (uint32_t)(sizeof(module->types[0].params) /
                               sizeof(module->types[0].params[0]))) {
    return -1;
  }
  type = &module->types[module->type_count];
  memset(type, 0, sizeof(*type));
  strcpy(type->name, name);
  for (uint32_t i = 0u; i < param_count; ++i) {
    type->params[i] = params[i];
  }
  type->param_count = param_count;
  type->result_type = result_type;
  type->result_count = result_count;
  *out_index = module->type_count;
  ++module->type_count;
  return 0;
}

static const ErWcType* erwc_c_import_type(const ErWcModule* module,
                                          const char* import_name,
                                          uint32_t* out_function_index) {
  for (uint32_t i = 0u; i < module->import_count; ++i) {
    const ErWcImport* import = &module->imports[i];
    //@optimizer-ignore imported C hostcall names require indexed lookup
    if (strcmp(import->name, import_name) == 0) {
      if (import->type_index >= module->type_count) {
        return NULL;
      }
      *out_function_index = import->function_index;
      return &module->types[import->type_index];
    }
  }
  return NULL;
}

static const ErWcConstant* erwc_c_find_constant(const ErWcModule* module,
                                                const char* name) {
  for (uint32_t i = 0u; i < module->constant_count; ++i) {
    //@optimizer-ignore authored C constants require indexed name lookup
    if (strcmp(module->constants[i].name, name) == 0) {
      return &module->constants[i];
    }
  }
  return NULL;
}

static int erwc_c_parse_constant(ErWcCParser* parser, ErWcModule* module) {
  ErWcConstant* constant;
  char name[ERWC_MAX_STRING];
  int64_t value = 0;

  if (module->constant_count >= ERWC_MAX_CONSTANTS ||
      erwc_c_take_literal(parser, "const") != 0 ||
      erwc_c_take_literal(parser, "i64") != 0 ||
      erwc_c_take_ident(parser, name, sizeof(name)) != 0 ||
      erwc_c_find_constant(module, name) != NULL ||
      erwc_c_take_literal(parser, "=") != 0 ||
      erwc_c_take_i64_literal(parser, &value) != 0 ||
      erwc_c_take_literal(parser, ";") != 0) {
    return -1;
  }
  constant = &module->constants[module->constant_count];
  memset(constant, 0, sizeof(*constant));
  strcpy(constant->name, name);
  constant->value = value;
  ++module->constant_count;
  return 0;
}

static int erwc_c_parse_import(ErWcCParser* parser, ErWcModule* module) {
  char result_ident[ERWC_MAX_STRING];
  char import_name[ERWC_MAX_STRING];
  char module_name[ERWC_MAX_STRING];
  char field_name[ERWC_MAX_STRING];
  char type_name[ERWC_MAX_STRING];
  uint8_t params[ERWC_C_IMPORT_PARAM_CAP];
  uint32_t param_count = 0u;
  uint8_t result_type;
  uint32_t type_index = 0u;
  ErWcImport* import;

  if (module->import_count >= ERWC_MAX_IMPORTS ||
      erwc_c_take_literal(parser, "extern") != 0 ||
      erwc_c_take_ident(parser, result_ident, sizeof(result_ident)) != 0 ||
      erwc_c_take_ident(parser, import_name, sizeof(import_name)) != 0 ||
      erwc_c_take_literal(parser, "(") != 0) {
    return -1;
  }
  result_type = erwc_c_type_from_ident(result_ident);
  if (result_type == ERWC_C_INVALID_TYPE) {
    return -1;
  }
  erwc_c_skip_ws(parser);
  if (erwc_c_take_literal(parser, "void") == 0) {
  } else {
    while (1) {
      char param_ident[ERWC_MAX_STRING];
      if (param_count >= ERWC_C_IMPORT_PARAM_CAP ||
          erwc_c_take_ident(parser, param_ident, sizeof(param_ident)) != 0 ||
          erwc_c_type_from_ident(param_ident) != ERWC_VALTYPE_I64) {
        return -1;
      }
      params[param_count++] = ERWC_VALTYPE_I64;
      erwc_c_skip_ws(parser);
      if (parser->cur < parser->end && *parser->cur == ',') {
        ++parser->cur;
      } else {
        break;
      }
    }
  }
  snprintf(type_name, sizeof(type_name), "%s_t", import_name);
  if (erwc_c_take_literal(parser, ")") != 0 ||
      erwc_c_take_literal(parser, "__import") != 0 ||
      erwc_c_take_literal(parser, "(") != 0 ||
      erwc_c_take_string(parser, module_name, sizeof(module_name)) != 0 ||
      erwc_c_take_literal(parser, ",") != 0 ||
      erwc_c_take_string(parser, field_name, sizeof(field_name)) != 0 ||
      erwc_c_take_literal(parser, ")") != 0 ||
      erwc_c_take_literal(parser, ";") != 0 ||
      erwc_c_add_type(module, type_name, params, param_count, result_type,
                      result_type == 0u ? 0u : 1u, &type_index) != 0) {
    return -1;
  }
  import = &module->imports[module->import_count];
  memset(import, 0, sizeof(*import));
  strcpy(import->name, import_name);
  strcpy(import->module, module_name);
  strcpy(import->field, field_name);
  strcpy(import->type_name, type_name);
  import->type_index = type_index;
  import->function_index = module->import_count;
  import->import_kind = erwc_c_host_import_kind(module_name, field_name);
  if (import->import_kind == ER_WASM_IMPORT_KIND_NONE) {
    return -1;
  }
  ++module->import_count;
  return 0;
}

static int erwc_c_parse_memory(ErWcCParser* parser, ErWcModule* module) {
  int64_t parsed_pages = 0;
  uint32_t pages = 0u;

  if (erwc_c_take_literal(parser, "memory") != 0 ||
      erwc_c_take_literal(parser, "(") != 0 ||
      erwc_c_take_i64_literal(parser, &parsed_pages) != 0 ||
      parsed_pages != ER_WASM_CONTRACT_REQUIRED_MEMORY_PAGES ||
      erwc_c_take_literal(parser, ")") != 0 ||
      erwc_c_take_literal(parser, ";") != 0) {
    return -1;
  }
  pages = (uint32_t)parsed_pages;
  module->memory_pages = pages;
  return 0;
}

static int erwc_c_emit_i64_const(ErWcFunc* func, int64_t value) {
  if (erwc_buffer_push(&func->code, ERWC_OP_I64_CONST) != 0 ||
      erwc_emit_i64_leb(&func->code, value) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_emit_i32_wrap_i64(ErWcFunc* func) {
  return erwc_buffer_push(&func->code, ERWC_OP_I32_WRAP_I64);
}

static int erwc_c_emit_local_get(ErWcFunc* func, const char* name) {
  uint32_t local_index = 0u;

  if (erwc_find_local(func, name, &local_index) != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_LOCAL_GET) != 0 ||
      erwc_emit_u32_leb(&func->code, local_index) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_emit_local_set(ErWcFunc* func, uint32_t local_index) {
  if (erwc_buffer_push(&func->code, ERWC_OP_LOCAL_SET) != 0 ||
      erwc_emit_u32_leb(&func->code, local_index) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_add_local(ErWcFunc* func, const char* name, uint32_t* out_index) {
  ErWcLocal* local;
  uint32_t existing_index = 0u;

  if (func->local_count >= ERWC_MAX_LOCALS ||
      strlen(name) + 1u > sizeof(func->locals[0].name) ||
      erwc_find_local(func, name, &existing_index) == 0) {
    return -1;
  }
  local = &func->locals[func->local_count];
  memset(local, 0, sizeof(*local));
  strcpy(local->name, name);
  local->type = ERWC_VALTYPE_I64;
  *out_index = func->local_count;
  ++func->local_count;
  return 0;
}

static int erwc_c_parse_expression(ErWcCParser* parser,
                                   const ErWcModule* module,
                                   ErWcFunc* func);
static int erwc_c_parse_main_statement(ErWcCParser* parser,
                                       const ErWcModule* module,
                                       ErWcFunc* func,
                                       uint8_t* out_parsed);
static int erwc_c_parse_memory_offset(ErWcCParser* parser,
                                      const ErWcModule* module,
                                      int64_t* out_offset);
static int erwc_c_emit_load(ErWcCParser* parser,
                            const ErWcModule* module,
                            ErWcFunc* func,
                            const char* name,
                            uint8_t opcode,
                            uint32_t align);

static int erwc_c_emit_call(ErWcCParser* parser,
                            const ErWcModule* module,
                            ErWcFunc* func,
                            const char* import_name) {
  uint32_t function_index = 0u;
  const ErWcType* type;

  type = erwc_c_import_type(module, import_name, &function_index);
  if (type == NULL ||
      type->result_count != ER_WASM_HOSTCALL_I64_RESULTS ||
      type->result_type != ERWC_VALTYPE_I64 ||
      erwc_c_take_literal(parser, "(") != 0) {
    return -1;
  }
  for (uint32_t i = 0u; i < type->param_count; ++i) {
    if (erwc_c_parse_expression(parser, module, func) != 0) {
      return -1;
    }
    if (i + 1u < type->param_count && erwc_c_take_literal(parser, ",") != 0) {
      return -1;
    }
  }
  if (erwc_c_take_literal(parser, ")") != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_CALL) != 0 ||
      erwc_emit_u32_leb(&func->code, function_index) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_parse_expression(ErWcCParser* parser,
                                   const ErWcModule* module,
                                   ErWcFunc* func) {
  ErWcCParser before_literal = *parser;
  const ErWcConstant* constant;
  char ident[ERWC_MAX_STRING];
  int64_t return_value = 0;
  uint32_t local_index = 0u;

  if (erwc_c_take_i64_literal(parser, &return_value) == 0) {
    return erwc_c_emit_i64_const(func, return_value);
  }
  *parser = before_literal;
  if (erwc_c_take_ident(parser, ident, sizeof(ident)) != 0) {
    return -1;
  }
  erwc_c_skip_ws(parser);
  if (parser->cur < parser->end && *parser->cur == '(') {
    if (strcmp(ident, "load32") == 0) {
      *parser = before_literal;
      return erwc_c_emit_load(parser, module, func, "load32",
                              ERWC_OP_I32_LOAD, 2u);
    }
    if (strcmp(ident, "load64") == 0) {
      *parser = before_literal;
      return erwc_c_emit_load(parser, module, func, "load64",
                              ERWC_OP_I64_LOAD, 3u);
    }
    return erwc_c_emit_call(parser, module, func, ident);
  }
  if (erwc_find_local(func, ident, &local_index) == 0) {
    return erwc_c_emit_local_get(func, ident);
  }
  constant = erwc_c_find_constant(module, ident);
  if (constant == NULL) {
    return -1;
  }
  return erwc_c_emit_i64_const(func, constant->value);
}

static int erwc_c_parse_local_decl(ErWcCParser* parser,
                                   const ErWcModule* module,
                                   ErWcFunc* func) {
  char local_name[ERWC_MAX_STRING];
  uint32_t local_index = 0u;

  if (erwc_c_take_literal(parser, "i64") != 0 ||
      erwc_c_take_ident(parser, local_name, sizeof(local_name)) != 0 ||
      erwc_c_take_literal(parser, "=") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_take_literal(parser, ";") != 0 ||
      erwc_c_add_local(func, local_name, &local_index) != 0 ||
      erwc_c_emit_local_set(func, local_index) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_parse_assignment(ErWcCParser* parser,
                                   const ErWcModule* module,
                                   ErWcFunc* func) {
  char local_name[ERWC_MAX_STRING];
  uint32_t local_index = 0u;

  if (erwc_c_take_ident(parser, local_name, sizeof(local_name)) != 0 ||
      erwc_find_local(func, local_name, &local_index) != 0 ||
      erwc_c_take_literal(parser, "=") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_take_literal(parser, ";") != 0 ||
      erwc_c_emit_local_set(func, local_index) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_parse_store_statement(ErWcCParser* parser,
                                        const ErWcModule* module,
                                        ErWcFunc* func,
                                        const char* name,
                                        uint8_t opcode,
                                        uint32_t align) {
  int64_t offset = 0;

  if (erwc_c_take_literal(parser, name) != 0 ||
      erwc_c_take_literal(parser, "(") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_emit_i32_wrap_i64(func) != 0 ||
      erwc_c_take_literal(parser, ",") != 0 ||
      erwc_c_parse_memory_offset(parser, module, &offset) != 0 ||
      erwc_c_take_literal(parser, ",") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_emit_i32_wrap_i64(func) != 0 ||
      erwc_c_take_literal(parser, ")") != 0 ||
      erwc_c_take_literal(parser, ";") != 0 ||
      erwc_buffer_push(&func->code, opcode) != 0 ||
      erwc_emit_u32_leb(&func->code, align) != 0 ||
      erwc_emit_u32_leb(&func->code, (uint32_t)offset) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_parse_memory_offset(ErWcCParser* parser,
                                      const ErWcModule* module,
                                      int64_t* out_offset) {
  const ErWcConstant* constant;
  char offset_name[ERWC_MAX_STRING];
  ErWcCParser before_offset;
  int64_t offset = 0;

  if (out_offset == NULL) {
    return -1;
  }
  before_offset = *parser;
  if (erwc_c_take_i64_literal(parser, &offset) != 0) {
    *parser = before_offset;
    if (erwc_c_take_ident(parser, offset_name, sizeof(offset_name)) != 0) {
      return -1;
    }
    constant = erwc_c_find_constant(module, offset_name);
    if (constant == NULL) {
      return -1;
    }
    offset = constant->value;
  }
  if (offset < 0 || offset > (int64_t)ERWC_U32_MAX_VALUE) {
    return -1;
  }
  *out_offset = offset;
  return 0;
}

static int erwc_c_emit_load(ErWcCParser* parser,
                            const ErWcModule* module,
                            ErWcFunc* func,
                            const char* name,
                            uint8_t opcode,
                            uint32_t align) {
  int64_t offset = 0;

  if (erwc_c_take_literal(parser, name) != 0 ||
      erwc_c_take_literal(parser, "(") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_emit_i32_wrap_i64(func) != 0 ||
      erwc_c_take_literal(parser, ",") != 0 ||
      erwc_c_parse_memory_offset(parser, module, &offset) != 0 ||
      erwc_c_take_literal(parser, ")") != 0 ||
      erwc_buffer_push(&func->code, opcode) != 0 ||
      erwc_emit_u32_leb(&func->code, align) != 0 ||
      erwc_emit_u32_leb(&func->code, (uint32_t)offset) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_parse_statement_block(ErWcCParser* parser,
                                        const ErWcModule* module,
                                        ErWcFunc* func) {
  while (1) {
    uint8_t parsed_statement = 0u;
    erwc_c_skip_ws(parser);
    if (parser->cur < parser->end && *parser->cur == '}') {
      return 0;
    }
    if (erwc_c_parse_main_statement(parser, module, func, &parsed_statement) != 0 ||
        parsed_statement == 0u) {
      return -1;
    }
  }
}

static int erwc_c_parse_if_statement(ErWcCParser* parser,
                                     const ErWcModule* module,
                                     ErWcFunc* func) {
  if (erwc_c_take_literal(parser, "if") != 0 ||
      erwc_c_take_literal(parser, "(") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_take_literal(parser, ")") != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_IF) != 0 ||
      erwc_buffer_push(&func->code, ERWC_BLOCKTYPE_EMPTY) != 0 ||
      erwc_c_take_literal(parser, "{") != 0 ||
      erwc_c_parse_statement_block(parser, module, func) != 0 ||
      erwc_c_take_literal(parser, "}") != 0 ||
      erwc_c_take_literal(parser, "else") != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_ELSE) != 0 ||
      erwc_c_take_literal(parser, "{") != 0 ||
      erwc_c_parse_statement_block(parser, module, func) != 0 ||
      erwc_c_take_literal(parser, "}") != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_END) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_c_parse_main_statement(ErWcCParser* parser,
                                       const ErWcModule* module,
                                       ErWcFunc* func,
                                       uint8_t* out_parsed) {
  ErWcCParser before_statement = *parser;

  *out_parsed = 0u;
  if (erwc_c_parse_local_decl(parser, module, func) == 0) {
    *out_parsed = 1u;
    return 0;
  }
  *parser = before_statement;
  if (erwc_c_parse_assignment(parser, module, func) == 0) {
    *out_parsed = 1u;
    return 0;
  }
  *parser = before_statement;
  if (erwc_c_parse_store_statement(parser, module, func, "store16",
                                   ERWC_OP_I32_STORE16, 1u) == 0) {
    *out_parsed = 1u;
    return 0;
  }
  *parser = before_statement;
  if (erwc_c_parse_store_statement(parser, module, func, "store32",
                                   ERWC_OP_I32_STORE, 2u) == 0) {
    *out_parsed = 1u;
    return 0;
  }
  *parser = before_statement;
  if (erwc_c_parse_store_statement(parser, module, func, "store64",
                                   ERWC_OP_I64_STORE, 3u) == 0) {
    *out_parsed = 1u;
    return 0;
  }
  *parser = before_statement;
  if (erwc_c_parse_if_statement(parser, module, func) == 0) {
    *out_parsed = 1u;
    return 0;
  }
  *parser = before_statement;
  return 0;
}

static int erwc_c_parse_main(ErWcCParser* parser, ErWcModule* module) {
  static const uint8_t no_params[1] = {0u};
  ErWcFunc* func;
  uint32_t type_index = 0u;

  if (module->func_count >= ERWC_MAX_FUNCS ||
      erwc_c_take_literal(parser, "export") != 0 ||
      erwc_c_take_literal(parser, "i64") != 0 ||
      erwc_c_take_literal(parser, "main") != 0 ||
      erwc_c_take_literal(parser, "(") != 0 ||
      erwc_c_take_literal(parser, "void") != 0 ||
      erwc_c_take_literal(parser, ")") != 0 ||
      erwc_c_take_literal(parser, "{") != 0 ||
      erwc_c_add_type(module, "main_t", no_params, 0u, ERWC_VALTYPE_I64, 1u,
                      &type_index) != 0) {
    return -1;
  }
  func = &module->funcs[module->func_count];
  memset(func, 0, sizeof(*func));
  strcpy(func->name, "main");
  strcpy(func->type_name, "main_t");
  func->type_index = type_index;
  func->function_index = module->import_count + module->func_count;
  func->exported_main = 1u;
  while (1) {
    uint8_t parsed_statement = 0u;
    if (erwc_c_parse_main_statement(parser, module, func, &parsed_statement) != 0) {
      return -1;
    }
    if (parsed_statement == 0u) {
      break;
    }
  }
  if (erwc_c_take_literal(parser, "return") != 0 ||
      erwc_c_parse_expression(parser, module, func) != 0 ||
      erwc_c_take_literal(parser, ";") != 0 ||
      erwc_c_take_literal(parser, "}") != 0 ||
      erwc_buffer_push(&func->code, ERWC_OP_END) != 0) {
    return -1;
  }
  ++module->func_count;
  return 0;
}

int erwc_build_c_source(const ErWcSource* source, ErWcModule* module) {
  ErWcCParser parser;

  if (source == NULL || module == NULL || source->bytes == NULL) {
    return -1;
  }
  memset(module, 0, sizeof(*module));
  parser.cur = (const char*)source->bytes;
  parser.end = (const char*)source->bytes + source->len;
  while (1) {
    erwc_c_skip_ws(&parser);
    if ((size_t)(parser.end - parser.cur) >= strlen("extern") &&
        memcmp(parser.cur, "extern", strlen("extern")) == 0) {
      if (erwc_c_parse_import(&parser, module) != 0) {
        return -1;
      }
    } else {
      break;
    }
  }
  while (1) {
    erwc_c_skip_ws(&parser);
    if ((size_t)(parser.end - parser.cur) >= strlen("const") &&
        memcmp(parser.cur, "const", strlen("const")) == 0) {
      if (erwc_c_parse_constant(&parser, module) != 0) {
        return -1;
      }
    } else {
      break;
    }
  }
  if (erwc_c_parse_memory(&parser, module) != 0 ||
      erwc_c_parse_main(&parser, module) != 0) {
    return -1;
  }
  erwc_c_skip_ws(&parser);
  if (parser.cur != parser.end ||
      module->type_count == 0u ||
      module->func_count != ER_WASM_CONTRACT_REQUIRED_IMPORT_COUNT ||
      module->memory_pages != ER_WASM_CONTRACT_REQUIRED_MEMORY_PAGES) {
    return -1;
  }
  return 0;
}
