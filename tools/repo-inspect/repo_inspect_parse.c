static const char* eri_ltrim(const char* s) {
  while (*s != 0 && isspace((unsigned char)*s)) {
    ++s;
  }
  return s;
}

static uint8_t eri_word_before_paren(const char* line, char* out, size_t out_cap, const char** out_start) {
  const char* paren = strchr(line, '(');
  const char* end;
  const char* start;
  size_t len;

  if (paren == NULL) {
    return 0;
  }
  end = paren;
  while (end > line && isspace((unsigned char)end[-1])) {
    --end;
  }
  start = end;
  while (start > line && (isalnum((unsigned char)start[-1]) || start[-1] == '_')) {
    --start;
  }
  if (start == end || !isalpha((unsigned char)start[0]) || (size_t)(end - start) >= out_cap) {
    return 0;
  }
  len = (size_t)(end - start);
  memcpy(out, start, len);
  out[len] = 0;
  *out_start = start;
  return 1;
}

static uint8_t eri_keyword_function_name(const char* name) {
  static const char* words[] = {
    "if", "for", "while", "switch", "return", "sizeof", "case", "typedef", "define"
  };
  size_t i;

  for (i = 0; i < sizeof(words) / sizeof(words[0]); ++i) {
    if (strcmp(name, words[i]) == 0) {
      return 1;
    }
  }
  return 0;
}

static uint8_t eri_probable_function_def(const char* line, char* name, size_t name_cap, uint8_t* is_static) {
  const char* trim = eri_ltrim(line);
  const char* name_start = NULL;
  const char* brace;

  *is_static = 0;
  brace = strchr(trim, '{');
  if (trim[0] == '#' || brace == NULL ||
      (strchr(trim, ';') != NULL && strchr(trim, ';') < brace) ||
      (strchr(trim, '=') != NULL && strchr(trim, '=') < brace)) {
    return 0;
  }
  if (eri_word_before_paren(trim, name, name_cap, &name_start) == 0u || eri_keyword_function_name(name) != 0u) {
    return 0;
  }
  if (strstr(trim, "static ") != NULL && strstr(trim, "static ") < name_start) {
    *is_static = 1;
  }
  return 1;
}

static void eri_copy_without_literals(const uint8_t* bytes, size_t start, size_t end, char* out, size_t out_cap) {
  size_t i;
  size_t n = 0u;
  uint8_t in_string = 0u;
  uint8_t in_char = 0u;
  uint8_t escaped = 0u;

  if (out_cap == 0u) {
    return;
  }
  for (i = start; i < end && n + 1u < out_cap; ++i) {
    uint8_t c = bytes[i];

    if (escaped != 0u) {
      escaped = 0u;
      continue;
    }
    if (in_string != 0u) {
      if (c == '\\') {
        escaped = 1u;
      } else if (c == '"') {
        in_string = 0u;
      }
      continue;
    }
    if (in_char != 0u) {
      if (c == '\\') {
        escaped = 1u;
      } else if (c == '\'') {
        in_char = 0u;
      }
      continue;
    }
    if (c == '"') {
      in_string = 1u;
      continue;
    }
    if (c == '\'') {
      in_char = 1u;
      continue;
    }
    out[n++] = (char)c;
  }
  out[n] = 0;
}

static uint8_t eri_line_starts_with_word(const char* line, const char* word) {
  size_t len = strlen(word);
  const char* trim = eri_ltrim(line);

  return (uint8_t)(strncmp(trim, word, len) == 0 &&
                   (trim[len] == 0 || isspace((unsigned char)trim[len]) || trim[len] == '('));
}

static uint8_t eri_line_declares_constant(const char* line) {
  const char* trim = eri_ltrim(line);
  size_t i = 0u;

  if (trim[0] == '#' || eri_line_starts_with_word(trim, "case") != 0u ||
      eri_line_starts_with_word(trim, "enum") != 0u ||
      strstr(trim, " const ") != NULL || strncmp(trim, "const ", 6u) == 0 ||
      strstr(trim, "static const ") != NULL) {
    return 1;
  }
  while (isupper((unsigned char)trim[i]) || isdigit((unsigned char)trim[i]) || trim[i] == '_') {
    ++i;
  }
  if (i > 0u && isspace((unsigned char)trim[i]) && strchr(trim + i, '=') != NULL) {
    return 1;
  }
  return 0;
}

static uint8_t eri_line_starts_type_decl_block(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "typedef enum", 12u) == 0 ||
                    strncmp(trim, "typedef struct", 14u) == 0 ||
                    strncmp(trim, "typedef union", 13u) == 0 ||
                    eri_line_starts_with_word(trim, "enum") != 0u ||
                    eri_line_starts_with_word(trim, "struct") != 0u ||
                    eri_line_starts_with_word(trim, "union") != 0u) &&
                   strchr(trim, '{') != NULL);
}

static void eri_update_type_decl_block(int brace_delta, uint8_t* type_decl_block, int* type_decl_brace_depth) {
  if (*type_decl_block == 0u) {
    return;
  }
  *type_decl_brace_depth += brace_delta;
  if (*type_decl_brace_depth <= 0) {
    *type_decl_block = 0u;
    *type_decl_brace_depth = 0;
  }
}

static uint8_t eri_common_numeric_literal(uint64_t value) {
  return (uint8_t)(value <= 2u || value == 8u || value == 16u || value == 32u || value == 64u);
}

//@optimizer-ignore-function magic-number scan must inspect each token-like numeric literal on the line
static uint8_t eri_line_has_magic_number(const char* line, char* out_literal, size_t out_cap) {
  const char* trim = eri_ltrim(line);
  size_t i;

  if (eri_line_declares_constant(trim) != 0u) {
    return 0;
  }
  for (i = 0u; trim[i] != 0; ++i) {
    char* end = NULL;
    uint64_t value;
    size_t len;

    if (!isdigit((unsigned char)trim[i])) {
      continue;
    }
    if (i > 0u && (isalnum((unsigned char)trim[i - 1u]) || trim[i - 1u] == '_' || trim[i - 1u] == '.')) {
      continue;
    }
    errno = 0;
    value = strtoull(trim + i, &end, 0);
    if (end == trim + i || errno == ERANGE) {
      continue;
    }
    while (*end == 'u' || *end == 'U' || *end == 'l' || *end == 'L') {
      ++end;
    }
    if (isalnum((unsigned char)*end) || *end == '_' || *end == '.') {
      i = (size_t)(end - trim);
      continue;
    }
    if (eri_common_numeric_literal(value) != 0u) {
      i = (size_t)(end - trim);
      continue;
    }
    len = (size_t)(end - (trim + i));
    if (len >= out_cap) {
      len = out_cap - 1u;
    }
    memcpy(out_literal, trim + i, len);
    out_literal[len] = 0;
    return 1;
  }
  return 0;
}

static uint8_t eri_identifier_contains_string_role(const char* line) {
  static const char* roles[] = {
    "label", "name", "text", "kind", "variant", "category", "icon", "slot"
  };
  size_t i;

  for (i = 0u; i < sizeof(roles) / sizeof(roles[0]); ++i) {
    if (strstr(line, roles[i]) != NULL) {
      return 1;
    }
  }
  return 0;
}

static uint8_t eri_line_declares_metadata_string_table(const char* line) {
  const char* trim = eri_ltrim(line);

  if (strstr(trim, "static const char* const ") == NULL || strstr(trim, "[]") == NULL ||
      strchr(trim, '{') == NULL) {
    return 0;
  }
  return (uint8_t)(strstr(trim, "slots_") != NULL || strstr(trim, "states_") != NULL ||
                   strstr(trim, "_variants") != NULL || strstr(trim, "_keyboard") != NULL ||
                   strstr(trim, "_interactions") != NULL || strstr(trim, "_sides") != NULL);
}

static uint8_t eri_line_has_string_indexing_smell(const char* raw_line, const char* structural_line) {
  const char* trim = eri_ltrim(raw_line);

  if (eri_line_declares_metadata_string_table(trim) != 0u) {
    return 0;
  }
  if (strstr(trim, "char ") != NULL || strstr(trim, "const char ") != NULL ||
      strstr(trim, "static const char ") != NULL || strstr(trim, "buffer") != NULL) {
    return 0;
  }
  if (strstr(structural_line, "control[") != NULL || strstr(structural_line, "stack[") != NULL) {
    return 0;
  }
  if (strstr(structural_line, "_name[") != NULL) {
    return 0;
  }
  if (strstr(trim, "const char*") != NULL && strstr(trim, "[]") != NULL && strchr(trim, '{') != NULL) {
    return 1;
  }
  if (strchr(structural_line, '[') != NULL && strchr(structural_line, ']') != NULL &&
      eri_identifier_contains_string_role(structural_line) != 0u &&
      strstr(structural_line, "sizeof") == NULL && strstr(structural_line, "->") == NULL &&
      strstr(structural_line, "out_") == NULL && strstr(structural_line, "buffer") == NULL) {
    return 1;
  }
  return 0;
}

static uint8_t eri_path_is_shared_math(const char* path) {
  return (uint8_t)(strcmp(path, "include/er_math.h") == 0 || strcmp(path, "./include/er_math.h") == 0);
}

static uint8_t eri_line_has_direct_host_math_call(const char* line) {
  static const char* calls[] = {
    "floorf(", "ceilf(", "sqrtf(", "atan2f(", "fabsf(", "roundf(", "lrintf(",
    "floor(", "ceil(", "sqrt(", "atan2(", "fabs(", "round("
  };
  size_t i;

  for (i = 0u; i < sizeof(calls) / sizeof(calls[0]); ++i) {
    const char* hit = strstr(line, calls[i]);
    if (hit == NULL) {
      continue;
    }
    if (hit > line && (isalnum((unsigned char)hit[-1]) || hit[-1] == '_')) {
      continue;
    }
    if (hit >= line + 8 && strncmp(hit - 8, "er_math_", 8u) == 0) {
      continue;
    }
    if (hit >= line + 3 && strncmp(hit - 3, "vr_", 3u) == 0) {
      continue;
    }
    if (hit >= line + 6 && strncmp(hit - 6, "er_ui_", 6u) == 0) {
      continue;
    }
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_math_primitive_smell(const char* path, const char* raw_line, const char* structural_line) {
  const char* trim = eri_ltrim(raw_line);

  if (eri_path_is_shared_math(path) != 0u) {
    return 0u;
  }
  if (strstr(structural_line, "er_math_") != NULL || strstr(trim, "#include \"er_math.h\"") != NULL) {
    return 0u;
  }
  if (strstr(structural_line, "3.4028234663852886e38f") != NULL ||
      strstr(structural_line, "0x5f3759df") != NULL) {
    return 1u;
  }
  if (strstr(structural_line, "value == value") != NULL ||
      strstr(structural_line, "value != value") != NULL ||
      strstr(structural_line, "isfinite") != NULL) {
    return 1u;
  }
  if (strstr(structural_line, "return a < b ? a : b") != NULL ||
      strstr(structural_line, "return a > b ? a : b") != NULL) {
    return 1u;
  }
  if ((strstr(structural_line, "return min_value") != NULL && strstr(structural_line, "< min_value") != NULL) ||
      (strstr(structural_line, "return max_value") != NULL && strstr(structural_line, "> max_value") != NULL)) {
    return 1u;
  }
  if ((strstr(structural_line, "< 0.0f") != NULL && strstr(structural_line, "return 0.0f") != NULL) ||
      (strstr(structural_line, "> 1.0f") != NULL && strstr(structural_line, "return 1.0f") != NULL)) {
    return 1u;
  }
  if (strstr(structural_line, "* 255.0f") != NULL && strstr(structural_line, "+ 0.5f") != NULL) {
    return 1u;
  }
  if (strstr(structural_line, "truncated = (int") != NULL ||
      strstr(structural_line, "truncated = (INT") != NULL ||
      strstr(structural_line, "truncated = (int64_t") != NULL) {
    return 1u;
  }
  if ((strstr(structural_line, "value / x") != NULL && strstr(structural_line, "0.5f") != NULL) ||
      strstr(structural_line, "1.0e-10f") != NULL ||
      strstr(structural_line, "0.1963f") != NULL ||
      strstr(structural_line, "0.9817f") != NULL) {
    return 1u;
  }
  if (eri_line_has_direct_host_math_call(structural_line) != 0u) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_any_token(const char* line, const char* const* tokens, size_t len);

//@optimizer-ignore-function host filesystem smell scan must check each disallowed runtime token
static uint8_t eri_line_has_host_fs_runtime_smell(const char* path, const char* structural_line) {
  static const char* tokens[] = {
    "fopen(", "freopen(", "open(", "openat(", "read(", "write(", "close(",
    "stat(", "lstat(", "fstat(", "opendir(", "readdir(", "closedir(",
    "mkdir(", "unlink(", "remove(", "rename(", "realpath(", "getcwd(",
    "chdir(", "access(", "system(", "popen(", "fork(", "getenv(",
    "FILE*", "FILE *", "DIR*", "DIR *"
  };
  size_t i;

  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  for (i = 0u; i < sizeof(tokens) / sizeof(tokens[0]); ++i) {
    const char* hit = structural_line;

    while ((hit = strstr(hit, tokens[i])) != NULL) {
      if (hit == structural_line ||
          (!isalnum((unsigned char)hit[-1]) && hit[-1] != '_')) {
        return 1u;
      }
      hit += strlen(tokens[i]);
    }
  }
  return 0u;
}

static uint8_t eri_line_has_path_identity_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if ((strstr(structural_line, "path") != NULL || strstr(structural_line, "name") != NULL) &&
      (strstr(structural_line, "object_id") != NULL || strstr(structural_line, "ErHash") != NULL ||
       strstr(structural_line, "_hash") != NULL || strstr(structural_line, "hash(") != NULL)) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_legacy_object_id_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if (strstr(structural_line, "UINT32 object_id") != NULL ||
      strstr(structural_line, "uint32_t object_id") != NULL) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_raw_object_api_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if (strstr(structural_line, "er_vfs_prepare_object_packet") != NULL ||
      strstr(structural_line, "er_vfs_prepare_object_label_ref") != NULL ||
      strstr(structural_line, "er_vfs_hash_object") != NULL) {
    return 0u;
  }
  if ((strstr(structural_line, "object_bytes") != NULL || strstr(structural_line, "file_data") != NULL) &&
      (strstr(structural_line, "const UINT8*") != NULL || strstr(structural_line, "const uint8_t*") != NULL ||
       strstr(structural_line, "UINT8*") != NULL || strstr(structural_line, "uint8_t*") != NULL) &&
      (strstr(structural_line, "_prepare_") != NULL || strstr(structural_line, "_create(") != NULL ||
       strstr(structural_line, "_init(") != NULL)) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_wasm64_offset_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if (strstr(structural_line, "(UINT64") != NULL || strstr(structural_line, "(uint64_t") != NULL ||
      strstr(structural_line, "er_print") != NULL) {
    return 0u;
  }
  if ((strstr(structural_line, "UINT64") != NULL || strstr(structural_line, "uint64_t") != NULL) &&
      (strstr(structural_line, "offset") != NULL || strstr(structural_line, "_len") != NULL ||
       strstr(structural_line, "length") != NULL || strstr(structural_line, "size") != NULL) &&
      strstr(structural_line, "ErHash") == NULL) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_directive_has_reason(const char* line, const char* tag) {
  const char* hit = strstr(line, tag);
  size_t tag_len = strlen(tag);

  if (hit == NULL) {
    return 0u;
  }
  if (strcmp(tag, ERI_OPTIMIZER_IGNORE_TAG) == 0 && hit[tag_len] == '-') {
    return 0u;
  }
  hit += tag_len;
  while (*hit != 0 && isspace((unsigned char)*hit)) {
    ++hit;
  }
  return (uint8_t)(isalnum((unsigned char)*hit) || *hit == '_' || *hit == '-' || *hit == '"' || *hit == '\'');
}

static uint8_t eri_line_mentions_optimizer_ignore(const char* line) {
  return (uint8_t)(strstr(line, ERI_OPTIMIZER_IGNORE_TAG) != NULL);
}

static uint8_t eri_line_has_optimizer_ignore(const char* line) {
  return eri_directive_has_reason(line, ERI_OPTIMIZER_IGNORE_TAG);
}

static uint8_t eri_line_has_optimizer_ignore_function(const char* line) {
  return eri_directive_has_reason(line, ERI_OPTIMIZER_IGNORE_FUNCTION_TAG);
}

static uint8_t eri_line_has_optimizer_ignore_constant(const char* line) {
  return eri_directive_has_reason(line, ERI_OPTIMIZER_IGNORE_CONSTANT_TAG);
}

static uint8_t eri_line_has_removed_optimizer_ignore_block(const char* line) {
  return (uint8_t)(strstr(line, "@optimizer-ignore-begin") != NULL ||
                   strstr(line, "@optimizer-ignore-end") != NULL);
}

static uint8_t eri_line_is_optimizer_ignore_directive(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "//", 2u) == 0 || strncmp(trim, "/*", 2u) == 0) &&
                   eri_line_has_optimizer_ignore(trim) != 0u);
}

static uint8_t eri_line_is_optimizer_ignore_function_directive(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "//", 2u) == 0 || strncmp(trim, "/*", 2u) == 0) &&
                   eri_line_has_optimizer_ignore_function(trim) != 0u);
}

static uint8_t eri_line_is_optimizer_ignore_constant_directive(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "//", 2u) == 0 || strncmp(trim, "/*", 2u) == 0) &&
                   eri_line_has_optimizer_ignore_constant(trim) != 0u);
}

static uint8_t eri_line_has_invalid_optimizer_ignore(const char* line) {
  if (eri_line_mentions_optimizer_ignore(line) == 0u) {
    return 0u;
  }
  if (eri_line_has_removed_optimizer_ignore_block(line) != 0u) {
    return 1u;
  }
  if (eri_line_has_optimizer_ignore(line) != 0u ||
      eri_line_has_optimizer_ignore_function(line) != 0u ||
      eri_line_has_optimizer_ignore_constant(line) != 0u) {
    return 0u;
  }
  return 1u;
}

static uint8_t eri_line_has_loop_start(const char* line) {
  const char* trim = eri_ltrim(line);

  if (strstr(trim, "for(") != NULL || strstr(trim, "for (") != NULL ||
      strstr(trim, "while(") != NULL || strstr(trim, "while (") != NULL) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_ends_with_backslash(const char* line) {
  size_t len = strlen(line);

  while (len > 0u && isspace((unsigned char)line[len - 1u])) {
    --len;
  }
  return (uint8_t)(len > 0u && line[len - 1u] == '\\');
}

static void eri_update_loop_context(const char* structural_line, uint8_t has_loop_start,
                                    int* brace_depth, int* loop_depth,
                                    int* loop_brace_stack, size_t* loop_stack_len) {
  size_t i;
  int opens = 0;
  int closes = 0;

  for (i = 0u; structural_line[i] != 0; ++i) {
    if (structural_line[i] == '{') {
      ++opens;
    } else if (structural_line[i] == '}') {
      ++closes;
    }
  }
  if (has_loop_start != 0u && opens > closes && *loop_stack_len < 128u) {
    loop_brace_stack[*loop_stack_len] = *brace_depth + opens - closes;
    ++(*loop_stack_len);
    ++(*loop_depth);
  }
  for (i = 0u; structural_line[i] != 0; ++i) {
    if (structural_line[i] == '{') {
      ++(*brace_depth);
    } else if (structural_line[i] == '}' && *brace_depth > 0) {
      --(*brace_depth);
    }
  }
}

static int eri_line_brace_delta(const char* structural_line) {
  size_t i;
  int delta = 0;

  for (i = 0u; structural_line[i] != 0; ++i) {
    if (structural_line[i] == '{') {
      ++delta;
    } else if (structural_line[i] == '}') {
      --delta;
    }
  }
  return delta;
}

static uint8_t eri_line_has_division_or_modulo(const char* line) {
  size_t i;

  for (i = 0u; line[i] != 0; ++i) {
    if (line[i] == '%') {
      return 1u;
    }
    if (line[i] == '/' && line[i + 1u] != '/' && line[i + 1u] != '*' &&
        (i == 0u || line[i - 1u] != '*')) {
      return 1u;
    }
  }
  return 0u;
}

static uint8_t eri_line_has_any_token(const char* line, const char* const* tokens, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (strstr(line, tokens[i]) != NULL) {
      return 1u;
    }
  }
  return 0u;
}

static uint8_t eri_line_has_memory_op(const char* line) {
  static const char* tokens[] = {
    "memcpy(", "memmove(", "memset(", "memcmp(", "er_mem_copy(", "er_mem_zero(",
    "eri_zero(", "vr_memcpy(", "vr_memset("
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

static uint8_t eri_line_has_allocator_op(const char* line) {
  static const char* tokens[] = {
    "malloc(", "calloc(", "realloc(", "free(", "eri_grow(", "_alloc(", "_realloc(", "alloc_"
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

static uint8_t eri_line_has_io_op(const char* line) {
  static const char* tokens[] = {
    "er_mmio_", "er_pci_", "er_bus_in", "er_bus_out", "er_io_in", "er_io_out",
    "LocateProtocol(", "HandleProtocol(", "OutputString(", "Poll(", "Transmit(",
    "Configure(", "Read(", "Write("
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

static uint8_t eri_line_has_expensive_domain_call(const char* line) {
  static const char* tokens[] = {
    "hash(", "compress", "rasterize", "shape", "measure", "render", "draw",
    "scan", "decode", "parse", "layout", "paint", "blit", "map("
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

//@optimizer-ignore-function CPU-cost analysis must scan every line while maintaining loop nesting state
