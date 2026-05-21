typedef struct {
  size_t start;
  size_t end;
  char snippet[ERI_SCAN_SNIPPET_MAX];
  char structural_line[ERI_SCAN_STRUCTURAL_LINE_MAX];
} EriScanLine;

typedef struct {
  const EriVfsFile* file;
  EriFindings* findings;
  size_t pos;
  uint32_t line_no;
  int brace_depth;
  int loop_depth;
  int loop_brace_stack[ERI_LOOP_STACK_MAX];
  size_t loop_stack_len;
  uint8_t pending_optimizer_ignore;
  uint8_t pending_function_ignore;
  uint8_t function_ignore_active;
  int function_ignore_depth;
} EriCpuScanState;

static uint8_t eri_scan_read_line(const uint8_t* bytes, size_t len, size_t* pos,
                                  EriScanLine* line) {
  size_t copy_len;

  line->start = *pos;
  while (*pos < len && bytes[*pos] != '\n') {
    ++*pos;
  }
  line->end = *pos;
  if (*pos < len && bytes[*pos] == '\n') {
    ++*pos;
  } else if (line->start == len) {
    return 0u;
  }
  if (line->end > line->start && bytes[line->end - 1u] == '\r') {
    --line->end;
  }
  copy_len = line->end - line->start;
  if (copy_len >= sizeof(line->snippet)) {
    copy_len = sizeof(line->snippet) - 1u;
  }
  memcpy(line->snippet, bytes + line->start, copy_len);
  line->snippet[copy_len] = 0;
  eri_copy_without_literals(bytes, line->start, line->end,
                            line->structural_line, sizeof(line->structural_line));
  return 1u;
}

static void eri_cpu_scan_update_context(EriCpuScanState* state,
                                        const char* structural_line,
                                        uint8_t has_loop_start) {
  while (state->loop_stack_len > 0u &&
         state->brace_depth < state->loop_brace_stack[state->loop_stack_len - 1u]) {
    --state->loop_stack_len;
    if (state->loop_depth > 0) {
      --state->loop_depth;
    }
  }
  eri_update_loop_context(structural_line, has_loop_start,
                          &state->brace_depth, &state->loop_depth,
                          state->loop_brace_stack, &state->loop_stack_len);
}

static uint8_t eri_cpu_scan_consume_pending_function_ignore(EriCpuScanState* state,
                                                           const char* structural_line) {
  char func_name[ERI_FUNCTION_NAME_MAX];
  uint8_t is_static;

  if (state->pending_function_ignore == 0u) {
    return 0u;
  }
  if (eri_probable_function_def(structural_line, func_name, sizeof(func_name), &is_static) != 0u ||
      strchr(structural_line, '{') != NULL) {
    int brace_delta = eri_line_brace_delta(structural_line);

    state->pending_function_ignore = 0u;
    state->function_ignore_active = 1u;
    state->function_ignore_depth = state->brace_depth;
    if (brace_delta <= 0) {
      state->function_ignore_active = 0u;
    }
    (void)is_static;
    return 1u;
  }
  if (strchr(structural_line, ';') == NULL && strchr(structural_line, '}') == NULL) {
    return 1u;
  }
  state->pending_function_ignore = 0u;
  return 0u;
}

static uint8_t eri_cpu_scan_skip_ignored_line(EriCpuScanState* state,
                                             const EriScanLine* line) {
  if (state->function_ignore_active != 0u) {
    if (state->brace_depth < state->function_ignore_depth) {
      state->function_ignore_active = 0u;
    }
    return 1u;
  }
  if (eri_line_has_invalid_optimizer_ignore(line->structural_line) != 0u) {
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_function_directive(line->snippet) != 0u) {
    state->pending_function_ignore = 1u;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_directive(line->snippet) != 0u) {
    state->pending_optimizer_ignore = 1u;
    return 1u;
  }
  if (eri_cpu_scan_consume_pending_function_ignore(state, line->structural_line) != 0u) {
    return 1u;
  }
  if (state->pending_optimizer_ignore != 0u ||
      eri_line_has_optimizer_ignore(line->snippet) != 0u ||
      eri_line_has_optimizer_ignore_constant(line->snippet) != 0u) {
    state->pending_optimizer_ignore = 0u;
    return 1u;
  }
  return 0u;
}

static void eri_cpu_scan_report_line(EriCpuScanState* state, const char* structural_line,
                                     uint8_t has_loop_start) {
  if (has_loop_start != 0u && state->loop_depth > 0) {
    eri_add_finding(state->findings, state->file->path, state->line_no,
                    "cpu-nested-loop", "nested loop may multiply CPU work");
  }
  if (state->loop_depth == 0) {
    return;
  }
  if (eri_line_has_allocator_op(structural_line) != 0u) {
    eri_add_finding(state->findings, state->file->path, state->line_no,
                    "cpu-alloc-in-loop", "allocator/free operation inside loop");
  }
  if (eri_line_has_io_op(structural_line) != 0u) {
    eri_add_finding(state->findings, state->file->path, state->line_no,
                    "cpu-io-in-loop", "hardware/firmware I/O call inside loop");
  }
  if (eri_line_has_memory_op(structural_line) != 0u) {
    eri_add_finding(state->findings, state->file->path, state->line_no,
                    "cpu-memory-in-loop", "memory operation inside loop");
  }
  if (eri_line_has_division_or_modulo(structural_line) != 0u) {
    eri_add_finding(state->findings, state->file->path, state->line_no,
                    "cpu-div-in-loop", "division or modulo inside loop");
  }
  if (eri_line_has_expensive_domain_call(structural_line) != 0u) {
    eri_add_finding(state->findings, state->file->path, state->line_no,
                    "cpu-call-in-loop", "domain-heavy helper call inside loop");
  }
}

//@optimizer-ignore-function CPU-cost analysis must scan each source line once while updating loop context
static void eri_scan_cpu_costs(const EriVfsFile* file, EriFindings* findings) {
  EriCpuScanState state;
  EriScanLine line;

  memset(&state, 0, sizeof(state));
  state.file = file;
  state.findings = findings;
  state.line_no = 1u;

  while (state.pos <= file->len) {
    uint8_t has_loop_start;

    if (eri_scan_read_line(file->bytes, file->len, &state.pos, &line) == 0u) {
      break;
    }
    has_loop_start = eri_line_has_loop_start(line.structural_line);
    if (eri_cpu_scan_skip_ignored_line(&state, &line) == 0u) {
      eri_cpu_scan_report_line(&state, line.structural_line, has_loop_start);
    }
    eri_cpu_scan_update_context(&state, line.structural_line, has_loop_start);
    ++state.line_no;
  }
}

//@optimizer-ignore-function line metric analysis must scan every byte and every source line once
static void eri_scan_line_metrics(const uint8_t* bytes, size_t len, EriTotals* file_totals,
                                  EriFindings* findings, const char* path) {
  size_t pos = 0u;
  uint8_t in_block = 0u;
  uint32_t line_no = 1u;
  uint8_t pending_optimizer_ignore = 0u;
  uint8_t pending_function_ignore = 0u;
  uint8_t pending_constant_ignore = 0u;
  uint8_t function_ignore_active = 0u;
  uint8_t constant_ignore_active = 0u;
  uint8_t constant_ignore_macro = 0u;
  int function_ignore_depth = 0;
  int brace_depth = 0;
  uint8_t type_decl_block = 0u;
  int type_decl_brace_depth = 0;

  while (pos <= len) {
    size_t start = pos;
    size_t end;
    size_t i;
    uint8_t has_code = 0u;
    uint8_t has_comment = 0u;
    char snippet[144];

    while (pos < len && bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < len && bytes[pos] == '\n') {
      ++pos;
    } else if (start == len) {
      break;
    }
    ++file_totals->total_lines;

    if (end > start && bytes[end - 1u] == '\r') {
      --end;
    }
    for (i = start; i < end;) {
      uint8_t c = bytes[i];
      if (in_block != 0u) {
        has_comment = 1u;
        if (i + 1u < end && bytes[i] == '*' && bytes[i + 1u] == '/') {
          in_block = 0u;
          i += 2u;
        } else {
          ++i;
        }
      } else if (i + 1u < end && bytes[i] == '/' && bytes[i + 1u] == '*') {
        has_comment = 1u;
        in_block = 1u;
        i += 2u;
      } else if (i + 1u < end && bytes[i] == '/' && bytes[i + 1u] == '/') {
        has_comment = 1u;
        break;
      } else if (!isspace((unsigned char)c)) {
        has_code = 1u;
        ++i;
      } else {
        ++i;
      }
    }
    if (has_code != 0u) {
      ++file_totals->code_lines;
    } else if (has_comment != 0u) {
      ++file_totals->comment_lines;
    } else {
      ++file_totals->blank_lines;
    }
    if (end > start) {
      size_t copy_len = end - start;
      char searchable[144];
      char literal[32];
      uint8_t line_in_type_decl = type_decl_block;

      if (copy_len >= sizeof(snippet)) {
        copy_len = sizeof(snippet) - 1u;
      }
      memcpy(snippet, bytes + start, copy_len);
      snippet[copy_len] = 0;
      eri_copy_without_literals(bytes, start, end, searchable, sizeof(searchable));
      if (line_in_type_decl == 0u && eri_line_starts_type_decl_block(searchable) != 0u) {
        line_in_type_decl = 1u;
        type_decl_block = 1u;
      }
      if (function_ignore_active != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        if (brace_depth < function_ignore_depth) {
          function_ignore_active = 0u;
        }
        ++line_no;
        continue;
      }
      if (constant_ignore_active != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);

        if ((constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) == 0u) ||
            (constant_ignore_macro == 0u && strchr(searchable, ';') != NULL)) {
          constant_ignore_active = 0u;
          constant_ignore_macro = 0u;
        }
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        ++line_no;
        continue;
      }
      if (eri_line_has_invalid_optimizer_ignore(searchable) != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);

        eri_add_finding(findings, path, line_no, "ignore-misuse",
                        "optimizer ignore must use line, function, or constant scope with an explicit reason");
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        ++line_no;
        continue;
      }
      if (eri_line_is_optimizer_ignore_function_directive(snippet) != 0u) {
        pending_function_ignore = 1u;
        ++line_no;
        continue;
      }
      if (eri_line_is_optimizer_ignore_constant_directive(snippet) != 0u) {
        pending_constant_ignore = 1u;
        ++line_no;
        continue;
      }
      if (eri_line_is_optimizer_ignore_directive(snippet) != 0u) {
        pending_optimizer_ignore = 1u;
        ++line_no;
        continue;
      }
      if (pending_function_ignore != 0u) {
        char func_name[128];
        uint8_t is_static;

        if (eri_probable_function_def(searchable, func_name, sizeof(func_name), &is_static) != 0u ||
            strchr(searchable, '{') != NULL) {
          int brace_delta = eri_line_brace_delta(searchable);

          pending_function_ignore = 0u;
          function_ignore_active = 1u;
          brace_depth += brace_delta;
          function_ignore_depth = brace_depth;
          if (brace_delta <= 0) {
            function_ignore_active = 0u;
          }
          (void)is_static;
          ++line_no;
          continue;
        }
        if (strchr(searchable, ';') != NULL || strchr(searchable, '}') != NULL) {
          pending_function_ignore = 0u;
          eri_add_finding(findings, path, line_no, "ignore-misuse",
                          "optimizer-ignore-function must be immediately before a function definition");
        }
      }
      if (pending_constant_ignore != 0u) {
        const char* trim = eri_ltrim(searchable);

        pending_constant_ignore = 0u;
        constant_ignore_macro = trim[0] == '#' ? 1u : 0u;
        if ((constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) != 0u) ||
            (constant_ignore_macro == 0u && strchr(searchable, ';') == NULL)) {
          constant_ignore_active = 1u;
        }
        brace_depth += eri_line_brace_delta(searchable);
        ++line_no;
        continue;
      }
      if (pending_optimizer_ignore != 0u || eri_line_has_optimizer_ignore(snippet) != 0u ||
          eri_line_has_optimizer_ignore_constant(snippet) != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);

        pending_optimizer_ignore = 0u;
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        ++line_no;
        continue;
      }
      if (end - start > ERI_LONG_LINE) {
        snprintf(snippet, sizeof(snippet), "line has %lu columns", (unsigned long)(end - start));
        eri_add_finding(findings, path, line_no, "long-line", snippet);
      }
      if (strstr(searchable, "TODO") != NULL || strstr(searchable, "FIXME") != NULL || strstr(searchable, "HACK") != NULL) {
        eri_add_finding(findings, path, line_no, "marker", eri_ltrim(snippet));
      }
      if (strstr(searchable, "goto ") != NULL) {
        eri_add_finding(findings, path, line_no, "goto", eri_ltrim(snippet));
      }
      if (line_in_type_decl == 0u && eri_line_has_magic_number(searchable, literal, sizeof(literal)) != 0u) {
        char text[144];
        snprintf(text, sizeof(text), "numeric literal %s in executable code", literal);
        eri_add_finding(findings, path, line_no, "magic-number", text);
      }
      if (eri_line_has_string_indexing_smell(snippet, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "string-indexing", "string table/indexing may need enum/count guard");
      }
      if (eri_line_has_math_primitive_smell(path, snippet, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "math-primitive", "local math primitive should use include/er_math.h");
      }
      if (eri_line_has_host_fs_runtime_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-host-fs",
                        "runtime code reaches for host filesystem/process API");
      }
      if (eri_line_has_path_identity_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-path-identity",
                        "path/name appears coupled to object identity or hashing");
      }
      if (eri_line_has_numeric_object_id_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-numeric-object-id",
                        "small numeric object_id should be an ErHash for content-addressed objects");
      }
      if (eri_line_has_raw_object_api_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-raw-object-api",
                        "runtime API takes raw object bytes where object hash/length may be enough");
      }
      if (eri_line_has_wasm64_offset_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-wasm64-offset",
                        "64-bit length/offset in runtime path needs a WASM32 reason");
      }
      {
        int brace_delta = eri_line_brace_delta(searchable);
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
      }
    } else if (pending_optimizer_ignore != 0u) {
      pending_optimizer_ignore = 0u;
    }
    ++line_no;
  }
}

//@optimizer-ignore-function function analysis must scan every line and brace transition in each C source file
static void eri_scan_functions(const EriVfsFile* file, EriFunctions* funcs, EriFindings* findings) {
  const uint8_t* bytes = file->bytes;
  size_t len = file->len;
  size_t pos = 0u;
  uint32_t line_no = 1u;
  int brace_depth = 0;
  size_t active_func = (size_t)-1;

  while (pos <= len) {
    size_t start = pos;
    size_t end;
    char line[1024];
    char structural_line[1024];
    size_t copy_len;
    size_t i;
    char name[128];
    uint8_t is_static;

    while (pos < len && bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < len && bytes[pos] == '\n') {
      ++pos;
    } else if (start == len) {
      break;
    }
    if (end > start && bytes[end - 1u] == '\r') {
      --end;
    }
    copy_len = end - start;
    if (copy_len >= sizeof(line)) {
      copy_len = sizeof(line) - 1u;
    }
    memcpy(line, bytes + start, copy_len);
    line[copy_len] = 0;
    eri_copy_without_literals(bytes, start, end, structural_line, sizeof(structural_line));

    if (brace_depth == 0 && eri_probable_function_def(structural_line, name, sizeof(name), &is_static) != 0u) {
      if (eri_add_function(funcs, file->path, name, strlen(name), line_no, is_static) != 0u) {
        active_func = funcs->len - 1u;
      }
    }

    for (i = 0; structural_line[i] != 0; ++i) {
      if (structural_line[i] == '{') {
        ++brace_depth;
      } else if (structural_line[i] == '}' && brace_depth > 0) {
        --brace_depth;
        if (brace_depth == 0 && active_func != (size_t)-1) {
          funcs->items[active_func].end_line = line_no;
          if (line_no - funcs->items[active_func].line + 1u > ERI_LONG_FUNCTION_LINES) {
            char text[128];
            snprintf(text, sizeof(text), "%s spans %u lines", funcs->items[active_func].name,
                     line_no - funcs->items[active_func].line + 1u);
            eri_add_finding(findings, file->path, funcs->items[active_func].line, "long-function", text);
          }
          active_func = (size_t)-1;
        }
      }
    }
    ++line_no;
  }
}

static uint32_t eri_count_function_ref_hits(const EriVfs* vfs, const char* name) {
  size_t name_len = strlen(name);
  size_t file_i;
  uint32_t calls = 0u;

  for (file_i = 0; file_i < vfs->len; ++file_i) {
    const EriVfsFile* file = &vfs->files[file_i];
    size_t pos;

    if (eri_is_build_path(file->path) != 0u || !eri_is_c_source(file->path)) {
      continue;
    }
    for (pos = 0u; pos + name_len < file->len; ++pos) {
      uint8_t before_ok;
      uint8_t after_ok;

      if (memcmp(file->bytes + pos, name, name_len) != 0) {
        continue;
      }
      before_ok = pos == 0u || !(isalnum((unsigned char)file->bytes[pos - 1u]) || file->bytes[pos - 1u] == '_');
      after_ok = pos + name_len >= file->len ||
                 !(isalnum((unsigned char)file->bytes[pos + name_len]) || file->bytes[pos + name_len] == '_');
      if (before_ok != 0u && after_ok != 0u) {
        ++calls;
      }
    }
  }
  return calls;
}

//@optimizer-ignore-function function reference worker compares each claimed function name against every source byte
static void* eri_function_ref_worker(void* arg) {
  EriFunctionRefJobs* jobs = (EriFunctionRefJobs*)arg;

  for (;;) {
    size_t index;

    if (pthread_mutex_lock(&jobs->mutex) != 0) {
      return NULL;
    }
    if (jobs->failed != 0u || jobs->next_index >= jobs->funcs->len) {
      if (pthread_mutex_unlock(&jobs->mutex) != 0) {
        jobs->failed = 1u;
      }
      return NULL;
    }
    index = jobs->next_index;
    ++jobs->next_index;
    if (pthread_mutex_unlock(&jobs->mutex) != 0) {
      jobs->failed = 1u;
      return NULL;
    }
    jobs->funcs->items[index].calls = eri_count_function_ref_hits(jobs->vfs, jobs->funcs->items[index].name);
  }
}

//@optimizer-ignore-function function reference analysis must compare every known function name against source bytes
static uint8_t eri_count_function_refs(const EriVfs* vfs, EriFunctions* funcs, size_t thread_count) {
  EriFunctionRefJobs jobs;
  pthread_t threads[ERI_MAX_THREAD_COUNT];
  size_t started = 0u;
  size_t i;

  if (funcs->len == 0u) {
    return 1u;
  }
  if (thread_count > funcs->len) {
    thread_count = funcs->len;
  }
  memset(&jobs, 0, sizeof(jobs));
  jobs.vfs = vfs;
  jobs.funcs = funcs;
  if (pthread_mutex_init(&jobs.mutex, NULL) != 0) {
    return 0u;
  }
  for (i = 0u; i < thread_count; ++i) {
    if (pthread_create(&threads[i], NULL, eri_function_ref_worker, &jobs) != 0) {
      if (pthread_mutex_lock(&jobs.mutex) == 0) {
        jobs.failed = 1u;
        (void)pthread_mutex_unlock(&jobs.mutex);
      }
      break;
    }
    ++started;
  }
  for (i = 0u; i < started; ++i) {
    if (pthread_join(threads[i], NULL) != 0) {
      jobs.failed = 1u;
    }
  }
  if (pthread_mutex_destroy(&jobs.mutex) != 0) {
    jobs.failed = 1u;
  }
  return jobs.failed == 0u ? 1u : 0u;
}
