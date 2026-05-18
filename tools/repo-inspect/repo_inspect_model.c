static EriPackage* eri_package_get(EriPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];
  size_t i;
  EriPackage* grown;

  eri_package_name(path, name, sizeof(name));

  for (i = 0; i < packages->len; ++i) {
    if (strcmp(packages->items[i].name, name) == 0) {
      return &packages->items[i];
    }
  }
  if (packages->len + 1u > packages->cap) {
    grown = (EriPackage*)eri_grow(packages->items, sizeof(packages->items[0]), &packages->cap, packages->len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    packages->items = grown;
  }
  memset(&packages->items[packages->len], 0, sizeof(packages->items[packages->len]));
  snprintf(packages->items[packages->len].name, sizeof(packages->items[packages->len].name), "%s", name);
  ++packages->len;
  return &packages->items[packages->len - 1u];
}

static void eri_add_finding(EriFindings* findings, const char* path, uint32_t line, const char* kind, const char* text) {
  EriFinding* grown;

  if (findings->len + 1u > findings->cap) {
    grown = (EriFinding*)eri_grow(findings->items, sizeof(findings->items[0]), &findings->cap, findings->len + 1u);
    if (grown == NULL) {
      return;
    }
    findings->items = grown;
  }
  findings->items[findings->len].path = eri_strdup(path);
  if (findings->items[findings->len].path == NULL) {
    return;
  }
  findings->items[findings->len].line = line;
  snprintf(findings->items[findings->len].kind, sizeof(findings->items[findings->len].kind), "%s", kind);
  snprintf(findings->items[findings->len].text, sizeof(findings->items[findings->len].text), "%s", text);
  ++findings->len;
}

//@optimizer-ignore-function findings teardown must release each duplicated finding path
static void eri_findings_free(EriFindings* findings) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    free(findings->items[i].path);
  }
  free(findings->items);
}

static uint8_t eri_add_function(EriFunctions* funcs, const char* path, const char* name, size_t name_len,
                                uint32_t line, uint8_t is_static) {
  EriFunction* grown;

  if (funcs->len + 1u > funcs->cap) {
    grown = (EriFunction*)eri_grow(funcs->items, sizeof(funcs->items[0]), &funcs->cap, funcs->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    funcs->items = grown;
  }
  funcs->items[funcs->len].path = eri_strdup(path);
  funcs->items[funcs->len].name = eri_strdup_len(name, name_len);
  if (funcs->items[funcs->len].path == NULL || funcs->items[funcs->len].name == NULL) {
    return 0;
  }
  funcs->items[funcs->len].line = line;
  funcs->items[funcs->len].end_line = line;
  funcs->items[funcs->len].is_static = is_static;
  funcs->items[funcs->len].calls = 0u;
  ++funcs->len;
  return 1;
}

//@optimizer-ignore-function function table teardown must release each duplicated path and function name
static void eri_functions_free(EriFunctions* funcs) {
  size_t i;

  for (i = 0; i < funcs->len; ++i) {
    free(funcs->items[i].path);
    free(funcs->items[i].name);
  }
  free(funcs->items);
}

static uint8_t eri_add_source_file(EriSourceFiles* sources, const char* path, uint64_t code_lines, uint8_t is_test) {
  EriSourceFile* grown;

  if (sources->len + 1u > sources->cap) {
    grown = (EriSourceFile*)eri_grow(sources->items, sizeof(sources->items[0]), &sources->cap, sources->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    sources->items = grown;
  }
  sources->items[sources->len].path = eri_strdup(path);
  if (sources->items[sources->len].path == NULL) {
    return 0;
  }
  sources->items[sources->len].code_lines = code_lines;
  sources->items[sources->len].is_test = is_test;
  sources->items[sources->len].has_test_signal = is_test;
  ++sources->len;
  return 1;
}

//@optimizer-ignore-function source table teardown must release each duplicated path
static void eri_sources_free(EriSourceFiles* sources) {
  size_t i;

  for (i = 0; i < sources->len; ++i) {
    free(sources->items[i].path);
  }
  free(sources->items);
}
