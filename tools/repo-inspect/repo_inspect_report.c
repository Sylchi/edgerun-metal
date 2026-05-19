static int eri_cmp_pkg(const void* a, const void* b) {
  const EriPackage* pa = (const EriPackage*)a;
  const EriPackage* pb = (const EriPackage*)b;
  if (pa->code_lines < pb->code_lines) {
    return 1;
  }
  if (pa->code_lines > pb->code_lines) {
    return -1;
  }
  return strcmp(pa->name, pb->name);
}

static int eri_cmp_bin(const void* a, const void* b) {
  const EriBinary* ba = (const EriBinary*)a;
  const EriBinary* bb = (const EriBinary*)b;
  if (ba->size < bb->size) {
    return 1;
  }
  if (ba->size > bb->size) {
    return -1;
  }
  return strcmp(ba->file->path, bb->file->path);
}

static int eri_cmp_coverage_pkg(const void* a, const void* b) {
  const EriCoveragePackage* pa = (const EriCoveragePackage*)a;
  const EriCoveragePackage* pb = (const EriCoveragePackage*)b;
  if (pa->source_code_lines < pb->source_code_lines) {
    return 1;
  }
  if (pa->source_code_lines > pb->source_code_lines) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static uint64_t eri_smell_package_score(const EriSmellPackage* pkg) {
  return pkg->large_files * 800u + pkg->long_functions * 120u + pkg->markers * 80u +
         pkg->gotos * 60u + pkg->math_primitives * 45u + pkg->magic_numbers * 12u +
         pkg->string_indexing * 20u + pkg->long_lines;
}

static uint64_t eri_cpu_package_score(const EriCpuPackage* pkg) {
  return pkg->nested_loops * 90u + pkg->allocations_in_loops * 80u + pkg->io_ops_in_loops * 80u +
         pkg->memory_ops_in_loops * 45u + pkg->divisions_in_loops * 35u + pkg->calls_in_loops * 30u;
}

static uint64_t eri_worldview_package_score(const EriWorldviewPackage* pkg) {
  return pkg->host_fs_runtime * 120u + pkg->path_identity * 90u + pkg->legacy_object_ids * 90u +
         pkg->raw_object_apis * 45u + pkg->wasm64_offsets * 20u;
}

static int eri_cmp_smell_pkg(const void* a, const void* b) {
  const EriSmellPackage* pa = (const EriSmellPackage*)a;
  const EriSmellPackage* pb = (const EriSmellPackage*)b;
  uint64_t sa = eri_smell_package_score(pa);
  uint64_t sb = eri_smell_package_score(pb);

  if (sa < sb) {
    return 1;
  }
  if (sa > sb) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static int eri_cmp_cpu_pkg(const void* a, const void* b) {
  const EriCpuPackage* pa = (const EriCpuPackage*)a;
  const EriCpuPackage* pb = (const EriCpuPackage*)b;
  uint64_t sa = eri_cpu_package_score(pa);
  uint64_t sb = eri_cpu_package_score(pb);

  if (sa < sb) {
    return 1;
  }
  if (sa > sb) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static int eri_cmp_worldview_pkg(const void* a, const void* b) {
  const EriWorldviewPackage* pa = (const EriWorldviewPackage*)a;
  const EriWorldviewPackage* pb = (const EriWorldviewPackage*)b;
  uint64_t sa = eri_worldview_package_score(pa);
  uint64_t sb = eri_worldview_package_score(pb);

  if (sa < sb) {
    return 1;
  }
  if (sa > sb) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static int eri_cmp_dup_ref(const void* a, const void* b) {
  const EriDupBlockRef* ra = (const EriDupBlockRef*)a;
  const EriDupBlockRef* rb = (const EriDupBlockRef*)b;
  int path_cmp;

  if (ra->hash < rb->hash) {
    return -1;
  }
  if (ra->hash > rb->hash) {
    return 1;
  }
  path_cmp = strcmp(ra->path, rb->path);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (ra->line < rb->line) {
    return -1;
  }
  if (ra->line > rb->line) {
    return 1;
  }
  return 0;
}

static uint32_t eri_duplicate_rank(const EriDuplicate* duplicate) {
  uint32_t test_count = (uint32_t)duplicate->is_test_a + (uint32_t)duplicate->is_test_b;
  if (test_count == 0u) {
    return 0u;
  }
  if (test_count == 1u) {
    return 1u;
  }
  return 2u;
}

static int eri_cmp_duplicate(const void* a, const void* b) {
  const EriDuplicate* da = (const EriDuplicate*)a;
  const EriDuplicate* db = (const EriDuplicate*)b;
  uint32_t rank_a = eri_duplicate_rank(da);
  uint32_t rank_b = eri_duplicate_rank(db);
  int path_cmp;

  if (rank_a < rank_b) {
    return -1;
  }
  if (rank_a > rank_b) {
    return 1;
  }
  path_cmp = strcmp(da->path_a, db->path_a);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (da->line_a < db->line_a) {
    return -1;
  }
  if (da->line_a > db->line_a) {
    return 1;
  }
  path_cmp = strcmp(da->path_b, db->path_b);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (da->line_b < db->line_b) {
    return -1;
  }
  if (da->line_b > db->line_b) {
    return 1;
  }
  return 0;
}

typedef uint8_t (*EriFindingPredicate)(const EriFinding* finding);

static uint8_t eri_lines_near(uint32_t a, uint32_t b) {
  return (uint8_t)(a <= b ? b - a <= ERI_DUP_BLOCK_LINES : a - b <= ERI_DUP_BLOCK_LINES);
}

static uint8_t eri_same_duplicate_region(const EriDuplicate* a, const EriDuplicate* b) {
  return (uint8_t)(eri_duplicate_rank(a) == eri_duplicate_rank(b) &&
                   strcmp(a->path_a, b->path_a) == 0 &&
                   strcmp(a->path_b, b->path_b) == 0 &&
                   eri_lines_near(a->line_a, b->line_a) != 0u &&
                   eri_lines_near(a->line_b, b->line_b) != 0u);
}

//@optimizer-ignore-function duplicate compaction must release adjacent duplicate path copies while preserving stable order
static void eri_compact_duplicates(EriDuplicates* duplicates) {
  size_t read_i;
  size_t write_i = 0u;

  for (read_i = 0u; read_i < duplicates->len; ++read_i) {
    if (write_i > 0u && eri_same_duplicate_region(&duplicates->items[write_i - 1u],
                                                  &duplicates->items[read_i]) != 0u) {
      free(duplicates->items[read_i].path_a);
      free(duplicates->items[read_i].path_b);
      continue;
    }
    if (write_i != read_i) {
      duplicates->items[write_i] = duplicates->items[read_i];
    }
    ++write_i;
  }
  duplicates->len = write_i;
}

static uint32_t eri_finding_rank(const EriFinding* finding) {
  if (strcmp(finding->kind, "large-file") == 0) {
    return 0u;
  }
  if (strcmp(finding->kind, "long-function") == 0) {
    return 1u;
  }
  if (strcmp(finding->kind, "marker") == 0) {
    return 2u;
  }
  if (strcmp(finding->kind, "ignore-misuse") == 0) {
    return 3u;
  }
  if (strcmp(finding->kind, "goto") == 0) {
    return 4u;
  }
  if (strcmp(finding->kind, "magic-number") == 0) {
    return 5u;
  }
  if (strcmp(finding->kind, "string-indexing") == 0) {
    return 6u;
  }
  if (strcmp(finding->kind, "math-primitive") == 0) {
    return 7u;
  }
  if (strncmp(finding->kind, "world-", 6u) == 0) {
    return 8u;
  }
  if (strncmp(finding->kind, "cpu-", 4u) == 0) {
    return 9u;
  }
  if (strcmp(finding->kind, "long-line") == 0) {
    return 10u;
  }
  return 11u;
}

static int eri_cmp_finding(const void* a, const void* b) {
  const EriFinding* fa = (const EriFinding*)a;
  const EriFinding* fb = (const EriFinding*)b;
  uint32_t ra = eri_finding_rank(fa);
  uint32_t rb = eri_finding_rank(fb);
  uint8_t nonprod_a = eri_is_nonprod_path(fa->path);
  uint8_t nonprod_b = eri_is_nonprod_path(fb->path);
  int path_cmp;

  if (ra < rb) {
    return -1;
  }
  if (ra > rb) {
    return 1;
  }
  if (nonprod_a < nonprod_b) {
    return -1;
  }
  if (nonprod_a > nonprod_b) {
    return 1;
  }
  path_cmp = strcmp(fa->path, fb->path);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (fa->line < fb->line) {
    return -1;
  }
  if (fa->line > fb->line) {
    return 1;
  }
  return 0;
}

static uint64_t eri_count_findings_kind(const EriFindings* findings, const char* kind) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (strcmp(findings->items[i].kind, kind) == 0) {
      ++count;
    }
  }
  return count;
}

static uint8_t eri_finding_is_cpu_cost(const EriFinding* finding) {
  return (uint8_t)(strncmp(finding->kind, "cpu-", 4u) == 0);
}

static uint8_t eri_finding_is_worldview_risk(const EriFinding* finding) {
  return (uint8_t)(strncmp(finding->kind, "world-", 6u) == 0);
}

static uint8_t eri_finding_is_smell(const EriFinding* finding) {
  return (uint8_t)(eri_finding_is_cpu_cost(finding) == 0u &&
                   eri_finding_is_worldview_risk(finding) == 0u);
}

static uint8_t eri_finding_is_magic_number(const EriFinding* finding) {
  return (uint8_t)(strcmp(finding->kind, "magic-number") == 0);
}

static uint8_t eri_finding_is_string_indexing(const EriFinding* finding) {
  return (uint8_t)(strcmp(finding->kind, "string-indexing") == 0);
}

static uint8_t eri_finding_is_math_primitive(const EriFinding* finding) {
  return (uint8_t)(strcmp(finding->kind, "math-primitive") == 0);
}

static uint64_t eri_count_cpu_findings(const EriFindings* findings) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (eri_finding_is_cpu_cost(&findings->items[i]) != 0u) {
      ++count;
    }
  }
  return count;
}

static uint64_t eri_count_worldview_findings(const EriFindings* findings) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (eri_finding_is_worldview_risk(&findings->items[i]) != 0u) {
      ++count;
    }
  }
  return count;
}

static uint64_t eri_count_smell_findings(const EriFindings* findings) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (eri_finding_is_cpu_cost(&findings->items[i]) == 0u &&
        eri_finding_is_worldview_risk(&findings->items[i]) == 0u) {
      ++count;
    }
  }
  return count;
}

static void eri_print_filtered_finding_samples(const EriFindings* findings, size_t limit,
                                               EriFindingPredicate predicate) {
  size_t i;
  size_t shown = 0u;

  for (i = 0u; i < findings->len && shown < limit; ++i) {
    if (predicate(&findings->items[i]) == 0u) {
      continue;
    }
    printf("    %s:%u [%s] %s\n", findings->items[i].path, findings->items[i].line,
           findings->items[i].kind, findings->items[i].text);
    ++shown;
  }
  if (shown == 0u) {
    printf("    none\n");
  }
}

static void eri_print_cpu_finding_samples(const EriFindings* findings, size_t limit) {
  eri_print_filtered_finding_samples(findings, limit, eri_finding_is_cpu_cost);
}

static void eri_print_worldview_finding_samples(const EriFindings* findings, size_t limit) {
  eri_print_filtered_finding_samples(findings, limit, eri_finding_is_worldview_risk);
}

static void eri_print_smell_finding_samples(const EriFindings* findings, size_t limit) {
  eri_print_filtered_finding_samples(findings, limit, eri_finding_is_smell);
}

static void eri_print_magic_number_finding_samples(const EriFindings* findings, size_t limit) {
  eri_print_filtered_finding_samples(findings, limit, eri_finding_is_magic_number);
}

static void eri_print_string_indexing_finding_samples(const EriFindings* findings, size_t limit) {
  eri_print_filtered_finding_samples(findings, limit, eri_finding_is_string_indexing);
}

static void eri_print_math_primitive_finding_samples(const EriFindings* findings, size_t limit) {
  eri_print_filtered_finding_samples(findings, limit, eri_finding_is_math_primitive);
}

static uint8_t eri_collect_smell_packages(const EriFindings* findings, EriSmellPackages* packages) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    EriSmellPackage* pkg = eri_smell_package_get(packages, findings->items[i].path);

    if (pkg == NULL) {
      return 0;
    }
    if (eri_is_nonprod_path(findings->items[i].path) != 0u) {
      ++pkg->nonprod_findings;
      continue;
    }
    if (strcmp(findings->items[i].kind, "large-file") == 0) {
      ++pkg->large_files;
    } else if (strcmp(findings->items[i].kind, "long-function") == 0) {
      ++pkg->long_functions;
    } else if (strcmp(findings->items[i].kind, "marker") == 0) {
      ++pkg->markers;
    } else if (strcmp(findings->items[i].kind, "ignore-misuse") == 0) {
      ++pkg->markers;
    } else if (strcmp(findings->items[i].kind, "goto") == 0) {
      ++pkg->gotos;
    } else if (strcmp(findings->items[i].kind, "magic-number") == 0) {
      ++pkg->magic_numbers;
    } else if (strcmp(findings->items[i].kind, "string-indexing") == 0) {
      ++pkg->string_indexing;
    } else if (strcmp(findings->items[i].kind, "math-primitive") == 0) {
      ++pkg->math_primitives;
    } else if (strcmp(findings->items[i].kind, "long-line") == 0) {
      ++pkg->long_lines;
    }
  }
  qsort(packages->items, packages->len, sizeof(packages->items[0]), eri_cmp_smell_pkg);
  return 1;
}

static uint8_t eri_collect_cpu_packages(const EriFindings* findings, EriCpuPackages* packages) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    EriCpuPackage* pkg;

    if (eri_finding_is_cpu_cost(&findings->items[i]) == 0u) {
      continue;
    }
    pkg = eri_cpu_package_get(packages, findings->items[i].path);
    if (pkg == NULL) {
      return 0;
    }
    if (eri_is_nonprod_path(findings->items[i].path) != 0u) {
      ++pkg->nonprod_findings;
      continue;
    }
    if (strcmp(findings->items[i].kind, "cpu-nested-loop") == 0) {
      ++pkg->nested_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-call-in-loop") == 0) {
      ++pkg->calls_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-div-in-loop") == 0) {
      ++pkg->divisions_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-memory-in-loop") == 0) {
      ++pkg->memory_ops_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-alloc-in-loop") == 0) {
      ++pkg->allocations_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-io-in-loop") == 0) {
      ++pkg->io_ops_in_loops;
    }
  }
  qsort(packages->items, packages->len, sizeof(packages->items[0]), eri_cmp_cpu_pkg);
  return 1;
}

static uint8_t eri_collect_worldview_packages(const EriFindings* findings, EriWorldviewPackages* packages) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    EriWorldviewPackage* pkg;

    if (eri_finding_is_worldview_risk(&findings->items[i]) == 0u) {
      continue;
    }
    pkg = eri_worldview_package_get(packages, findings->items[i].path);
    if (pkg == NULL) {
      return 0;
    }
    if (eri_is_runtime_path(findings->items[i].path) == 0u) {
      ++pkg->nonprod_findings;
      continue;
    }
    if (strcmp(findings->items[i].kind, "world-host-fs") == 0) {
      ++pkg->host_fs_runtime;
    } else if (strcmp(findings->items[i].kind, "world-path-identity") == 0) {
      ++pkg->path_identity;
    } else if (strcmp(findings->items[i].kind, "world-legacy-object-id") == 0) {
      ++pkg->legacy_object_ids;
    } else if (strcmp(findings->items[i].kind, "world-raw-object-api") == 0) {
      ++pkg->raw_object_apis;
    } else if (strcmp(findings->items[i].kind, "world-wasm64-offset") == 0) {
      ++pkg->wasm64_offsets;
    }
  }
  qsort(packages->items, packages->len, sizeof(packages->items[0]), eri_cmp_worldview_pkg);
  return 1;
}

//@optimizer-ignore-function duplicate worker must claim and scan each VFS file for normalized block refs
static void* eri_duplicate_worker(void* arg) {
  EriDuplicateJobs* jobs = (EriDuplicateJobs*)arg;

  for (;;) {
    size_t index;
    const EriVfsFile* file;

    if (pthread_mutex_lock(&jobs->mutex) != 0) {
      return NULL;
    }
    if (jobs->failed != 0u || jobs->next_index >= jobs->vfs->len) {
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

    file = &jobs->vfs->files[index];
    if (eri_is_build_path(file->path) == 0u && eri_is_c_impl(file->path) &&
        eri_is_generated_header(file->path, file->bytes, file->len) == 0u &&
        eri_collect_file_blocks(file, &jobs->refs[index]) == 0u) {
      if (pthread_mutex_lock(&jobs->mutex) != 0) {
        return NULL;
      }
      jobs->failed = 1u;
      (void)pthread_mutex_unlock(&jobs->mutex);
      return NULL;
    }
  }
}

//@optimizer-ignore-function duplicate block refs are gathered in parallel then merged by VFS index for stable output
static uint8_t eri_collect_duplicate_refs_parallel(const EriVfs* vfs, EriDupBlockRefs* refs,
                                                   size_t thread_count) {
  EriDupBlockRefs* file_refs;
  EriDuplicateJobs jobs;
  pthread_t threads[ERI_MAX_THREAD_COUNT];
  size_t started = 0u;
  size_t i;
  uint8_t ok = 1u;

  file_refs = (EriDupBlockRefs*)calloc(vfs->len == 0u ? 1u : vfs->len, sizeof(file_refs[0]));
  if (file_refs == NULL) {
    return 0u;
  }
  memset(&jobs, 0, sizeof(jobs));
  jobs.vfs = vfs;
  jobs.refs = file_refs;
  if (pthread_mutex_init(&jobs.mutex, NULL) != 0) {
    free(file_refs);
    return 0u;
  }
  for (i = 0u; i < thread_count; ++i) {
    if (pthread_create(&threads[i], NULL, eri_duplicate_worker, &jobs) != 0) {
      if (pthread_mutex_lock(&jobs.mutex) == 0) {
        jobs.failed = 1u;
        (void)pthread_mutex_unlock(&jobs.mutex);
      }
      ok = 0u;
      break;
    }
    ++started;
  }
  for (i = 0u; i < started; ++i) {
    if (pthread_join(threads[i], NULL) != 0) {
      ok = 0u;
    }
  }
  if (pthread_mutex_destroy(&jobs.mutex) != 0) {
    ok = 0u;
  }
  if (jobs.failed != 0u) {
    ok = 0u;
  }
  if (ok != 0u) {
    for (i = 0u; i < vfs->len; ++i) {
      if (eri_append_dup_refs_move(refs, &file_refs[i]) == 0u) {
        ok = 0u;
        break;
      }
    }
  }
  for (i = 0u; i < vfs->len; ++i) {
    eri_dup_refs_free(&file_refs[i]);
  }
  free(file_refs);
  return ok;
}

//@optimizer-ignore-function duplicate collection must scan each source block reference and adjacent equal hash group
static uint8_t eri_collect_duplicates(const EriVfs* vfs, EriDuplicates* duplicates, size_t thread_count) {
  EriDupBlockRefs refs;
  size_t i;

  memset(&refs, 0, sizeof(refs));
  if (eri_collect_duplicate_refs_parallel(vfs, &refs, thread_count) == 0u) {
    eri_dup_refs_free(&refs);
    return 0;
  }
  qsort(refs.items, refs.len, sizeof(refs.items[0]), eri_cmp_dup_ref);
  for (i = 1u; i < refs.len; ++i) {
    if (refs.items[i].hash == refs.items[i - 1u].hash &&
        (strcmp(refs.items[i].path, refs.items[i - 1u].path) != 0 ||
         refs.items[i].line > refs.items[i - 1u].line + ERI_DUP_BLOCK_LINES)) {
      if (eri_add_duplicate(duplicates, &refs.items[i - 1u], &refs.items[i]) == 0u) {
        eri_dup_refs_free(&refs);
        return 0;
      }
      while (i + 1u < refs.len && refs.items[i + 1u].hash == refs.items[i].hash) {
        ++i;
      }
    }
  }
  eri_dup_refs_free(&refs);
  qsort(duplicates->items, duplicates->len, sizeof(duplicates->items[0]), eri_cmp_duplicate);
  eri_compact_duplicates(duplicates);
  return 1;
}

static uint64_t eri_count_duplicate_rank(const EriDuplicates* duplicates, uint32_t rank) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < duplicates->len; ++i) {
    if (eri_duplicate_rank(&duplicates->items[i]) == rank) {
      ++count;
    }
  }
  return count;
}

static void eri_print_size(uint64_t bytes) {
  if (bytes >= 1024u * 1024u) {
    printf("%.2f MiB", (double)bytes / (1024.0 * 1024.0));
  } else if (bytes >= 1024u) {
    printf("%.1f KiB", (double)bytes / 1024.0);
  } else {
    printf("%llu B", (unsigned long long)bytes);
  }
}
