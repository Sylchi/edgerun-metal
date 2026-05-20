#include "wasm_compile.h"

int erwc_fail_path(const char* path, const char* message) {
  fprintf(stderr, "wasm-compile: %s: %s\n", path, message);
  return 1;
}

int erwc_usage(const char* program) {
  fprintf(stderr, "usage: %s <input.wat> <output.wasm>\n", program);
  return 2;
}

static const char ERWC_DIAG_OK[] = "ERWC0000";
static const char ERWC_DIAG_BAD_ARGS[] = "ERWC0001";
static const char ERWC_DIAG_UNSUPPORTED_ERC[] = "ERWC0100";
static const char ERWC_DIAG_TOKENIZATION_FAILED[] = "ERWC0200";
static const char ERWC_DIAG_UNSUPPORTED_WAT[] = "ERWC0201";
static const char ERWC_DIAG_CONTRACT_REJECTED[] = "ERWC0300";
static const char ERWC_DIAG_EMIT_FAILED[] = "ERWC0400";
static const char ERWC_DIAG_UNSUPPORTED_SOURCE_KIND[] = "ERWC0500";
static const char ERWC_DIAG_UNKNOWN[] = "ERWC0999";

const char* erwc_compile_status_code(ErWcCompileStatus status) {
  switch (status) {
    case ERWC_COMPILE_STATUS_OK:
      return ERWC_DIAG_OK;
    case ERWC_COMPILE_STATUS_BAD_ARGS:
      return ERWC_DIAG_BAD_ARGS;
    case ERWC_COMPILE_STATUS_UNSUPPORTED_ERC:
      return ERWC_DIAG_UNSUPPORTED_ERC;
    case ERWC_COMPILE_STATUS_TOKENIZATION_FAILED:
      return ERWC_DIAG_TOKENIZATION_FAILED;
    case ERWC_COMPILE_STATUS_UNSUPPORTED_WAT:
      return ERWC_DIAG_UNSUPPORTED_WAT;
    case ERWC_COMPILE_STATUS_CONTRACT_REJECTED:
      return ERWC_DIAG_CONTRACT_REJECTED;
    case ERWC_COMPILE_STATUS_EMIT_FAILED:
      return ERWC_DIAG_EMIT_FAILED;
    case ERWC_COMPILE_STATUS_UNSUPPORTED_SOURCE_KIND:
      return ERWC_DIAG_UNSUPPORTED_SOURCE_KIND;
    default:
      return ERWC_DIAG_UNKNOWN;
  }
}

const char* erwc_compile_status_message(ErWcCompileStatus status) {
  switch (status) {
    case ERWC_COMPILE_STATUS_OK:
      return "ok";
    case ERWC_COMPILE_STATUS_BAD_ARGS:
      return "bad arguments";
    case ERWC_COMPILE_STATUS_UNSUPPORTED_ERC:
      return "unsupported ERC source";
    case ERWC_COMPILE_STATUS_TOKENIZATION_FAILED:
      return "tokenization failed";
    case ERWC_COMPILE_STATUS_UNSUPPORTED_WAT:
      return "unsupported WAT subset";
    case ERWC_COMPILE_STATUS_CONTRACT_REJECTED:
      return "module contract rejected";
    case ERWC_COMPILE_STATUS_EMIT_FAILED:
      return "emit failed";
    case ERWC_COMPILE_STATUS_UNSUPPORTED_SOURCE_KIND:
      return "unsupported source kind";
    default:
      return "unknown compile status";
  }
}

int erwc_token_text_equals(const ErWcParse* parse, int token_index, const char* text) {
  const ErWcToken* token;
  size_t len;

  if (parse == NULL || token_index < 0 || text == NULL) {
    return 0;
  }
  token = &parse->tokens[token_index];
  len = strlen(text);
  return token->len == len && memcmp(token->start, text, len) == 0;
}

int erwc_node_atom_equals(const ErWcParse* parse, int node_index, const char* text) {
  const ErWcNode* node;

  if (node_index < 0) {
    return 0;
  }
  node = &parse->nodes[node_index];
  if (node->is_list != 0) {
    return 0;
  }
  return erwc_token_text_equals(parse, node->token, text);
}

int erwc_copy_token_text(const ErWcParse* parse, int node_index, char* dst, size_t dst_len) {
  const ErWcNode* node;
  const ErWcToken* token;
  size_t src_len;
  size_t offset = 0u;

  if (parse == NULL || node_index < 0 || dst == NULL || dst_len == 0u) {
    return -1;
  }
  node = &parse->nodes[node_index];
  if (node->is_list != 0) {
    return -1;
  }
  token = &parse->tokens[node->token];
  if (token->kind != ERWC_TOKEN_ATOM && token->kind != ERWC_TOKEN_STRING) {
    return -1;
  }
  if (token->kind == ERWC_TOKEN_ATOM && token->len > 0u && token->start[0] == '$') {
    offset = 1u;
  }
  if (token->len < offset) {
    return -1;
  }
  src_len = token->len - offset;
  if (src_len + 1u > dst_len) {
    return -1;
  }
  memcpy(dst, token->start + offset, src_len);
  dst[src_len] = 0;
  return 0;
}

int erwc_parse_u32_text(const char* text, uint32_t* out_value) {
  char* end = NULL;
  unsigned long value;

  if (text == NULL || out_value == NULL) {
    return -1;
  }
  errno = 0;
  value = strtoul(text, &end, ERWC_DECIMAL_BASE);
  if (end == text || *end != 0 || errno == ERANGE || value > ERWC_U32_MAX_VALUE) {
    return -1;
  }
  *out_value = (uint32_t)value;
  return 0;
}

int erwc_node_u32(const ErWcParse* parse, int node_index, uint32_t* out_value) {
  char text[ERWC_MAX_STRING];

  if (erwc_copy_token_text(parse, node_index, text, sizeof(text)) != 0) {
    return -1;
  }
  return erwc_parse_u32_text(text, out_value);
}

int erwc_node_i64(const ErWcParse* parse, int node_index, int64_t* out_value) {
  char text[ERWC_MAX_STRING];
  char* end = NULL;
  long long value;

  if (out_value == NULL ||
      erwc_copy_token_text(parse, node_index, text, sizeof(text)) != 0) {
    return -1;
  }
  errno = 0;
  value = strtoll(text, &end, ERWC_DECIMAL_BASE);
  if (end == text || *end != 0 || errno == ERANGE) {
    return -1;
  }
  *out_value = (int64_t)value;
  return 0;
}

uint8_t erwc_valtype_from_name(const char* name) {
  if (strcmp(name, "i32") == 0) {
    return ERWC_VALTYPE_I32;
  }
  if (strcmp(name, "i64") == 0) {
    return ERWC_VALTYPE_I64;
  }
  return 0u;
}

int erwc_find_type(const ErWcModule* module, const char* name, uint32_t* out_index) {
  uint32_t i;

  for (i = 0u; i < module->type_count; ++i) {
    if (strcmp(module->types[i].name, name) == 0) {
      *out_index = i;
      return 0;
    }
  }
  return -1;
}

int erwc_find_function(const ErWcModule* module, const char* name, uint32_t* out_index) {
  uint32_t i;

  for (i = 0u; i < module->import_count; ++i) {
    if (strcmp(module->imports[i].name, name) == 0) {
      *out_index = module->imports[i].function_index;
      return 0;
    }
  }
  for (i = 0u; i < module->func_count; ++i) {
    if (strcmp(module->funcs[i].name, name) == 0 && module->funcs[i].name[0] != 0) {
      *out_index = module->funcs[i].function_index;
      return 0;
    }
  }
  return -1;
}

int erwc_find_local(const ErWcFunc* func, const char* name, uint32_t* out_index) {
  uint32_t i;

  for (i = 0u; i < func->local_count; ++i) {
    if (strcmp(func->locals[i].name, name) == 0) {
      *out_index = i;
      return 0;
    }
  }
  return -1;
}

int erwc_buffer_push(ErWcBuffer* buffer, uint8_t byte) {
  if (buffer->len >= ERWC_MAX_BYTES) {
    return -1;
  }
  buffer->bytes[buffer->len++] = byte;
  return 0;
}

int erwc_buffer_append(ErWcBuffer* buffer, const uint8_t* bytes, size_t len) {
  if (len > ERWC_MAX_BYTES - buffer->len) {
    return -1;
  }
  memcpy(buffer->bytes + buffer->len, bytes, len);
  buffer->len += len;
  return 0;
}

int erwc_emit_u32_leb(ErWcBuffer* buffer, uint32_t value) {
  do {
    uint8_t byte = (uint8_t)(value & ERWC_LEB_PAYLOAD_MASK);
    value >>= ERWC_LEB_SHIFT;
    if (value != 0u) {
      byte |= ERWC_LEB_CONTINUATION_BIT;
    }
    if (erwc_buffer_push(buffer, byte) != 0) {
      return -1;
    }
  } while (value != 0u);
  return 0;
}

int erwc_emit_i64_leb(ErWcBuffer* buffer, int64_t value) {
  int more = 1;

  while (more != 0) {
    uint8_t byte = (uint8_t)((uint64_t)value & ERWC_LEB_PAYLOAD_MASK);
    int64_t shifted = value >> ERWC_LEB_SHIFT;
    int sign = (byte & ERWC_LEB_SIGN_BIT) != 0u;

    if ((shifted == 0 && sign == 0) || (shifted == -1 && sign != 0)) {
      more = 0;
    } else {
      byte |= ERWC_LEB_CONTINUATION_BIT;
    }
    if (erwc_buffer_push(buffer, byte) != 0) {
      return -1;
    }
    value = shifted;
  }
  return 0;
}

int erwc_emit_name(ErWcBuffer* buffer, const char* name) {
  size_t len = strlen(name);

  if (len > ERWC_U32_MAX_VALUE ||
      erwc_emit_u32_leb(buffer, (uint32_t)len) != 0 ||
      erwc_buffer_append(buffer, (const uint8_t*)name, len) != 0) {
    return -1;
  }
  return 0;
}
