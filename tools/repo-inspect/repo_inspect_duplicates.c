static uint64_t eri_hash_bytes(const char* bytes, size_t len) {
  uint64_t hash = 1469598103934665603ull;
  size_t i;

  for (i = 0; i < len; ++i) {
    hash ^= (uint8_t)bytes[i];
    hash *= 1099511628211ull;
  }
  return hash;
}

static uint8_t eri_normalize_code_line(const uint8_t* bytes, size_t start, size_t end, char* out, size_t out_cap) {
  size_t i = start;
  size_t n = 0u;
  uint8_t in_space = 0u;

  while (i < end && isspace((unsigned char)bytes[i])) {
    ++i;
  }
  if (i >= end || bytes[i] == '#') {
    return 0;
  }
  if (i + 1u < end && bytes[i] == '/' && (bytes[i + 1u] == '/' || bytes[i + 1u] == '*')) {
    return 0;
  }
  for (; i < end && n + 1u < out_cap; ++i) {
    uint8_t c = bytes[i];

    if (i + 1u < end && bytes[i] == '/' && bytes[i + 1u] == '/') {
      break;
    }
    if (isspace((unsigned char)c)) {
      in_space = 1u;
      continue;
    }
    if (in_space != 0u && n > 0u && (isalnum((unsigned char)c) || c == '_')) {
      out[n++] = ' ';
    }
    out[n++] = (char)c;
    in_space = 0u;
  }
  while (n > 0u && isspace((unsigned char)out[n - 1u])) {
    --n;
  }
  out[n] = 0;
  if (n < 8u || strcmp(out, "{") == 0 || strcmp(out, "}") == 0 || strcmp(out, "};") == 0) {
    return 0;
  }
  return 1;
}

static uint8_t eri_add_dup_block_ref(EriDupBlockRefs* refs, uint64_t hash, const char* path, uint32_t line) {
  EriDupBlockRef* grown;

  if (refs->len + 1u > refs->cap) {
    grown = (EriDupBlockRef*)eri_grow(refs->items, sizeof(refs->items[0]), &refs->cap, refs->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    refs->items = grown;
  }
  refs->items[refs->len].hash = hash;
  refs->items[refs->len].path = eri_strdup(path);
  if (refs->items[refs->len].path == NULL) {
    return 0;
  }
  refs->items[refs->len].line = line;
  ++refs->len;
  return 1;
}

//@optimizer-ignore-function duplicate reference teardown must release each duplicated block path
static void eri_dup_refs_free(EriDupBlockRefs* refs) {
  size_t i;

  for (i = 0; i < refs->len; ++i) {
    free(refs->items[i].path);
  }
  free(refs->items);
}

//@optimizer-ignore-function duplicate collection must allocate stable path copies for each reported pair
static uint8_t eri_add_duplicate(EriDuplicates* duplicates, const EriDupBlockRef* a, const EriDupBlockRef* b) {
  EriDuplicate* grown;

  if (duplicates->len + 1u > duplicates->cap) {
    grown = (EriDuplicate*)eri_grow(duplicates->items, sizeof(duplicates->items[0]),
                                   &duplicates->cap, duplicates->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    duplicates->items = grown;
  }
  duplicates->items[duplicates->len].path_a = eri_strdup(a->path);
  duplicates->items[duplicates->len].path_b = eri_strdup(b->path);
  if (duplicates->items[duplicates->len].path_a == NULL || duplicates->items[duplicates->len].path_b == NULL) {
    return 0;
  }
  duplicates->items[duplicates->len].line_a = a->line;
  duplicates->items[duplicates->len].is_test_a = eri_is_test_path(a->path);
  duplicates->items[duplicates->len].line_b = b->line;
  duplicates->items[duplicates->len].is_test_b = eri_is_test_path(b->path);
  duplicates->items[duplicates->len].hash = a->hash;
  ++duplicates->len;
  return 1;
}

//@optimizer-ignore-function duplicate teardown must release both path copies for each reported pair
static void eri_duplicates_free(EriDuplicates* duplicates) {
  size_t i;

  for (i = 0; i < duplicates->len; ++i) {
    free(duplicates->items[i].path_a);
    free(duplicates->items[i].path_b);
  }
  free(duplicates->items);
}

static uint8_t eri_append_dup_line(uint64_t** hashes, uint32_t** lines, uint32_t** segments,
                                   size_t* len, size_t* cap, uint64_t hash,
                                   uint32_t line, uint32_t segment) {
  if (*len + 1u > *cap) {
    size_t next = *cap == 0u ? 64u : *cap * 2u;
    uint64_t* grown_hashes = (uint64_t*)malloc(sizeof((*hashes)[0]) * next);
    uint32_t* grown_lines = (uint32_t*)malloc(sizeof((*lines)[0]) * next);
    uint32_t* grown_segments = (uint32_t*)malloc(sizeof((*segments)[0]) * next);

    if (grown_hashes == NULL || grown_lines == NULL || grown_segments == NULL) {
      free(grown_hashes);
      free(grown_lines);
      free(grown_segments);
      return 0u;
    }
    if (*len > 0u) {
      memcpy(grown_hashes, *hashes, sizeof((*hashes)[0]) * *len);
      memcpy(grown_lines, *lines, sizeof((*lines)[0]) * *len);
      memcpy(grown_segments, *segments, sizeof((*segments)[0]) * *len);
    }
    free(*hashes);
    free(*lines);
    free(*segments);
    *hashes = grown_hashes;
    *lines = grown_lines;
    *segments = grown_segments;
    *cap = next;
  }
  (*hashes)[*len] = hash;
  (*lines)[*len] = line;
  (*segments)[*len] = segment;
  ++*len;
  return 1u;
}

static uint8_t eri_dup_line_is_ignored(EriDupIgnoreState* state, const uint8_t* bytes, size_t start, size_t end) {
  char snippet[224];
  char searchable[224];
  size_t copy_len = end - start;

  if (copy_len >= sizeof(snippet)) {
    copy_len = sizeof(snippet) - 1u;
  }
  memcpy(snippet, bytes + start, copy_len);
  snippet[copy_len] = 0;
  eri_copy_without_literals(bytes, start, end, searchable, sizeof(searchable));
  if (state->function_ignore_active != 0u) {
    int brace_delta = eri_line_brace_delta(searchable);

    state->brace_depth += brace_delta;
    if (state->brace_depth < state->function_ignore_depth) {
      state->function_ignore_active = 0u;
    }
    ++state->segment;
    return 1u;
  }
  if (state->constant_ignore_active != 0u) {
    int brace_delta = eri_line_brace_delta(searchable);

    if ((state->constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) == 0u) ||
        (state->constant_ignore_macro == 0u && strchr(searchable, ';') != NULL)) {
      state->constant_ignore_active = 0u;
      state->constant_ignore_macro = 0u;
    }
    state->brace_depth += brace_delta;
    ++state->segment;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_function_directive(snippet) != 0u) {
    state->pending_function_ignore = 1u;
    ++state->segment;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_constant_directive(snippet) != 0u) {
    state->pending_constant_ignore = 1u;
    ++state->segment;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_directive(snippet) != 0u) {
    state->pending_optimizer_ignore = 1u;
    ++state->segment;
    return 1u;
  }
  if (state->pending_function_ignore != 0u) {
    char func_name[128];
    uint8_t is_static;

    if (eri_probable_function_def(searchable, func_name, sizeof(func_name), &is_static) != 0u ||
        strchr(searchable, '{') != NULL) {
      int brace_delta = eri_line_brace_delta(searchable);

      (void)is_static;
      state->pending_function_ignore = 0u;
      state->function_ignore_active = 1u;
      state->brace_depth += brace_delta;
      state->function_ignore_depth = state->brace_depth;
      if (brace_delta <= 0) {
        state->function_ignore_active = 0u;
      }
      ++state->segment;
      return 1u;
    }
    if (strchr(searchable, ';') != NULL || strchr(searchable, '}') != NULL) {
      state->pending_function_ignore = 0u;
    }
  }
  if (state->pending_constant_ignore != 0u) {
    const char* trim = eri_ltrim(searchable);

    state->pending_constant_ignore = 0u;
    state->constant_ignore_macro = trim[0] == '#' ? 1u : 0u;
    if ((state->constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) != 0u) ||
        (state->constant_ignore_macro == 0u && strchr(searchable, ';') == NULL)) {
      state->constant_ignore_active = 1u;
    }
    state->brace_depth += eri_line_brace_delta(searchable);
    ++state->segment;
    return 1u;
  }
  if (state->pending_optimizer_ignore != 0u || eri_line_has_optimizer_ignore(snippet) != 0u ||
      eri_line_has_optimizer_ignore_constant(snippet) != 0u) {
    state->pending_optimizer_ignore = 0u;
    state->brace_depth += eri_line_brace_delta(searchable);
    ++state->segment;
    return 1u;
  }
  state->brace_depth += eri_line_brace_delta(searchable);
  return 0u;
}

//@optimizer-ignore-function duplicate analysis must normalize each line and build rolling block references
static uint8_t eri_collect_file_blocks(const EriVfsFile* file, EriDupBlockRefs* refs) {
  uint64_t* hashes = NULL;
  uint32_t* lines = NULL;
  uint32_t* segments = NULL;
  size_t len = 0u;
  size_t cap = 0u;
  size_t pos = 0u;
  uint32_t line_no = 1u;
  EriDupIgnoreState ignore_state;
  size_t i;

  memset(&ignore_state, 0, sizeof(ignore_state));
  ignore_state.segment = 1u;
  while (pos <= file->len) {
    size_t start = pos;
    size_t end;
    char normalized[160];

    while (pos < file->len && file->bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < file->len && file->bytes[pos] == '\n') {
      ++pos;
    } else if (start == file->len) {
      break;
    }
    if (end > start && file->bytes[end - 1u] == '\r') {
      --end;
    }
    if (eri_dup_line_is_ignored(&ignore_state, file->bytes, start, end) != 0u) {
      ++line_no;
      continue;
    }
    if (eri_normalize_code_line(file->bytes, start, end, normalized, sizeof(normalized)) != 0u) {
      if (eri_append_dup_line(&hashes, &lines, &segments, &len, &cap,
                              eri_hash_bytes(normalized, strlen(normalized)),
                              line_no, ignore_state.segment) == 0u) {
        free(hashes);
        free(lines);
        free(segments);
        return 0;
      }
    }
    ++line_no;
  }
  if (len >= ERI_DUP_BLOCK_LINES) {
    for (i = 0; i + ERI_DUP_BLOCK_LINES <= len; ++i) {
      uint64_t block_hash = 1469598103934665603ull;
      size_t j;

      if (segments[i] != segments[i + ERI_DUP_BLOCK_LINES - 1u]) {
        continue;
      }
      for (j = 0; j < ERI_DUP_BLOCK_LINES; ++j) {
        block_hash ^= hashes[i + j];
        block_hash *= 1099511628211ull;
      }
      if (eri_add_dup_block_ref(refs, block_hash, file->path, lines[i]) == 0u) {
        free(hashes);
        free(lines);
        free(segments);
        return 0;
      }
    }
  }
  free(hashes);
  free(lines);
  free(segments);
  return 1;
}

static uint8_t eri_append_dup_refs_move(EriDupBlockRefs* dst, EriDupBlockRefs* src) {
  EriDupBlockRef* grown;

  if (src->len == 0u) {
    return 1u;
  }
  if (dst->len + src->len > dst->cap) {
    grown = (EriDupBlockRef*)eri_grow(dst->items, sizeof(dst->items[0]), &dst->cap, dst->len + src->len);
    if (grown == NULL) {
      return 0u;
    }
    dst->items = grown;
  }
  memcpy(dst->items + dst->len, src->items, sizeof(src->items[0]) * src->len);
  dst->len += src->len;
  src->items = NULL;
  src->len = 0u;
  src->cap = 0u;
  return 1u;
}
