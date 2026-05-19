static void eri_analyze_cleanup(EriPackages* packages, EriFunctions* funcs, EriFindings* findings,
                                EriBinaries* bins, EriSourceFiles* sources,
                                EriCoveragePackages* coverage_packages, EriSmellPackages* smell_packages,
                                EriCpuPackages* cpu_packages, EriWorldviewPackages* worldview_packages,
                                EriDuplicates* duplicates) {
  eri_sources_free(sources);
  eri_duplicates_free(duplicates);
  eri_functions_free(funcs);
  eri_findings_free(findings);
  free(packages->items);
  free(coverage_packages->items);
  free(smell_packages->items);
  free(cpu_packages->items);
  free(worldview_packages->items);
  free(bins->items);
}

static uint8_t eri_host_thread_count(size_t* out_count) {
  const char* env = getenv(ERI_THREAD_ENV);
  long online = sysconf(_SC_NPROCESSORS_ONLN);
  size_t threads;

  if (out_count == NULL) {
    return 0u;
  }
  if (env != NULL && env[0] != 0) {
    char* end = NULL;
    unsigned long requested;

    errno = 0;
    requested = strtoul(env, &end, 10);
    if (end == env || *end != 0 || errno == ERANGE ||
        requested < (unsigned long)ERI_MIN_THREAD_COUNT ||
        requested > (unsigned long)ERI_MAX_THREAD_COUNT) {
      fprintf(stderr, "repo-inspect: %s must be an integer from %u to %u\n",
              ERI_THREAD_ENV, ERI_MIN_THREAD_COUNT, ERI_MAX_THREAD_COUNT);
      return 0u;
    }
    *out_count = (size_t)requested;
    return 1u;
  }
  if (online < (long)ERI_MIN_THREAD_COUNT) {
    fprintf(stderr, "repo-inspect: cannot determine online CPU count\n");
    return 0u;
  }
  threads = (size_t)online;
  if (threads > ERI_MAX_THREAD_COUNT) {
    threads = ERI_MAX_THREAD_COUNT;
  }
  *out_count = threads;
  return 1u;
}

static uint8_t eri_append_array_move(void** dst_items, size_t* dst_len, size_t* dst_cap,
                                     void** src_items, size_t* src_len, size_t* src_cap,
                                     size_t item_size) {
  void* grown;

  if (*src_len == 0u) {
    return 1u;
  }
  if (*dst_len + *src_len > *dst_cap) {
    grown = eri_grow(*dst_items, item_size, dst_cap, *dst_len + *src_len);
    if (grown == NULL) {
      return 0u;
    }
    *dst_items = grown;
  }
  memcpy((uint8_t*)*dst_items + item_size * *dst_len, *src_items, item_size * *src_len);
  *dst_len += *src_len;
  *src_items = NULL;
  *src_len = 0u;
  *src_cap = 0u;
  return 1u;
}

static uint8_t eri_append_findings_move(EriFindings* dst, EriFindings* src) {
  return eri_append_array_move((void**)&dst->items, &dst->len, &dst->cap,
                               (void**)&src->items, &src->len, &src->cap,
                               sizeof(src->items[0]));
}

static uint8_t eri_append_functions_move(EriFunctions* dst, EriFunctions* src) {
  return eri_append_array_move((void**)&dst->items, &dst->len, &dst->cap,
                               (void**)&src->items, &src->len, &src->cap,
                               sizeof(src->items[0]));
}

static uint8_t eri_append_sources_move(EriSourceFiles* dst, EriSourceFiles* src) {
  return eri_append_array_move((void**)&dst->items, &dst->len, &dst->cap,
                               (void**)&src->items, &src->len, &src->cap,
                               sizeof(src->items[0]));
}

static void eri_file_analysis_free(EriFileAnalysis* analysis) {
  eri_sources_free(&analysis->sources);
  eri_functions_free(&analysis->funcs);
  eri_findings_free(&analysis->findings);
}

static void eri_file_analysis_scan(const EriVfsFile* file, EriFileAnalysis* analysis) {
  memset(analysis, 0, sizeof(*analysis));
  if (eri_is_build_path(file->path) != 0u || !eri_is_c_source(file->path) ||
      eri_is_generated_header(file->path, file->bytes, file->len) != 0u) {
    return;
  }
  analysis->analyzed = 1u;
  eri_scan_line_metrics(file->bytes, file->len, &analysis->totals, &analysis->findings, file->path);
  eri_scan_functions(file, &analysis->funcs, &analysis->findings);
  eri_scan_cpu_costs(file, &analysis->findings);
  if (eri_is_c_impl(file->path) && eri_is_example_path(file->path) == 0u &&
      eri_add_source_file(&analysis->sources, file->path, analysis->totals.code_lines,
                          eri_is_test_path(file->path)) == 0u) {
    analysis->failed = 1u;
    return;
  }
  if (analysis->totals.code_lines > ERI_LARGE_FILE_LINES) {
    char text[128];
    snprintf(text, sizeof(text), "file has %llu code lines", (unsigned long long)analysis->totals.code_lines);
    eri_add_finding(&analysis->findings, file->path, 1u, "large-file", text);
  }
}

//@optimizer-ignore-function worker must claim and analyze each VFS file index from the shared queue
static void* eri_analysis_worker(void* arg) {
  EriAnalysisJobs* jobs = (EriAnalysisJobs*)arg;

  for (;;) {
    size_t index;

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
    eri_file_analysis_scan(&jobs->vfs->files[index], &jobs->files[index]);
    if (jobs->files[index].failed != 0u) {
      if (pthread_mutex_lock(&jobs->mutex) != 0) {
        return NULL;
      }
      jobs->failed = 1u;
      (void)pthread_mutex_unlock(&jobs->mutex);
      return NULL;
    }
  }
}

//@optimizer-ignore-function pthread orchestration starts every worker and joins all started workers on failure
static uint8_t eri_run_file_analysis_jobs(const EriVfs* vfs, EriFileAnalysis* file_results,
                                          size_t thread_count) {
  EriAnalysisJobs jobs;
  pthread_t threads[ERI_MAX_THREAD_COUNT];
  size_t started = 0u;
  size_t i;

  memset(&jobs, 0, sizeof(jobs));
  jobs.vfs = vfs;
  jobs.files = file_results;
  if (pthread_mutex_init(&jobs.mutex, NULL) != 0) {
    return 0u;
  }
  for (i = 0u; i < thread_count; ++i) {
    if (pthread_create(&threads[i], NULL, eri_analysis_worker, &jobs) != 0) {
      if (pthread_mutex_lock(&jobs.mutex) == 0) {
        jobs.failed = 1u;
        (void)pthread_mutex_unlock(&jobs.mutex);
      }
      while (started > 0u) {
        --started;
        (void)pthread_join(threads[started], NULL);
      }
      (void)pthread_mutex_destroy(&jobs.mutex);
      return 0u;
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

//@optimizer-ignore-function repo analysis orchestrates per-file metric, function, and CPU scans over the VFS snapshot
static uint8_t eri_analyze(const EriVfs* vfs) {
  EriTotals totals;
  EriPackages packages;
  EriFunctions funcs;
  EriFindings findings;
  EriBinaries bins;
  EriSourceFiles sources;
  EriCoveragePackages coverage_packages;
  EriSmellPackages smell_packages;
  EriCpuPackages cpu_packages;
  EriWorldviewPackages worldview_packages;
  EriDuplicates duplicates;
  EriFileAnalysis* file_results;
  size_t thread_count;
  size_t i;

  file_results = (EriFileAnalysis*)calloc(vfs->len == 0u ? 1u : vfs->len, sizeof(file_results[0]));
  if (file_results == NULL) {
    return 0u;
  }
  if (eri_host_thread_count(&thread_count) == 0u) {
    free(file_results);
    return 0u;
  }

  memset(&totals, 0, sizeof(totals));
  memset(&packages, 0, sizeof(packages));
  memset(&funcs, 0, sizeof(funcs));
  memset(&findings, 0, sizeof(findings));
  memset(&bins, 0, sizeof(bins));
  memset(&sources, 0, sizeof(sources));
  memset(&coverage_packages, 0, sizeof(coverage_packages));
  memset(&smell_packages, 0, sizeof(smell_packages));
  memset(&cpu_packages, 0, sizeof(cpu_packages));
  memset(&worldview_packages, 0, sizeof(worldview_packages));
  memset(&duplicates, 0, sizeof(duplicates));

  if (eri_run_file_analysis_jobs(vfs, file_results, thread_count) == 0u) {
    for (i = 0u; i < vfs->len; ++i) {
      eri_file_analysis_free(&file_results[i]);
    }
    free(file_results);
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0u;
  }

  for (i = 0; i < vfs->len; ++i) {
    const EriVfsFile* file = &vfs->files[i];
    EriPackage* package;

    if (eri_is_binary_like(file) != 0u) {
      eri_add_binary(&bins, file);
    }
    if (file_results[i].analyzed == 0u) {
      continue;
    }
    if (eri_append_findings_move(&findings, &file_results[i].findings) == 0u ||
        eri_append_functions_move(&funcs, &file_results[i].funcs) == 0u ||
        eri_append_sources_move(&sources, &file_results[i].sources) == 0u) {
      for (; i < vfs->len; ++i) {
        eri_file_analysis_free(&file_results[i]);
      }
      free(file_results);
      eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                          &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
      return 0;
    }

    ++totals.files;
    totals.bytes += file->len;
    totals.total_lines += file_results[i].totals.total_lines;
    totals.code_lines += file_results[i].totals.code_lines;
    totals.comment_lines += file_results[i].totals.comment_lines;
    totals.blank_lines += file_results[i].totals.blank_lines;

    package = eri_package_get(&packages, file->path);
    if (package == NULL) {
      for (; i < vfs->len; ++i) {
        eri_file_analysis_free(&file_results[i]);
      }
      free(file_results);
      eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                          &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
      return 0;
    }
    ++package->files;
    package->bytes += file->len;
    package->code_lines += file_results[i].totals.code_lines;
  }
  free(file_results);

  if (eri_count_function_refs(vfs, &funcs, thread_count) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  if (eri_mark_test_signals(vfs, &sources, &funcs, thread_count) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  eri_measure_binary_release_sizes(&bins, thread_count);
  if (eri_collect_duplicates(vfs, &duplicates, thread_count) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  for (i = 0; i < sources.len; ++i) {
    char package_name[ERI_PACKAGE_MAX];
    EriCoveragePackage* coverage_package;

    eri_package_name(sources.items[i].path, package_name, sizeof(package_name));
    coverage_package = eri_coverage_package_get(&coverage_packages, package_name);
    if (coverage_package == NULL) {
      eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                          &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
      return 0;
    }
    if (sources.items[i].is_test != 0u) {
      ++coverage_package->test_files;
      coverage_package->test_code_lines += sources.items[i].code_lines;
    } else {
      ++coverage_package->source_files;
      coverage_package->source_code_lines += sources.items[i].code_lines;
      if (sources.items[i].has_test_signal != 0u) {
        ++coverage_package->tested_source_files;
      }
    }
  }
  qsort(packages.items, packages.len, sizeof(packages.items[0]), eri_cmp_pkg);
  qsort(coverage_packages.items, coverage_packages.len, sizeof(coverage_packages.items[0]), eri_cmp_coverage_pkg);
  qsort(bins.items, bins.len, sizeof(bins.items[0]), eri_cmp_bin);
  qsort(findings.items, findings.len, sizeof(findings.items[0]), eri_cmp_finding);
  if (eri_collect_smell_packages(&findings, &smell_packages) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  if (eri_collect_cpu_packages(&findings, &cpu_packages) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  if (eri_collect_worldview_packages(&findings, &worldview_packages) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }

  printf("repo-inspect\n");
  printf("============\n\n");
  printf("Inventory\n");
  printf("  C files: %llu  code: %llu loc  total: %llu lines  comments: %llu  blanks: %llu  bytes: ",
         (unsigned long long)totals.files,
         (unsigned long long)totals.code_lines,
         (unsigned long long)totals.total_lines,
         (unsigned long long)totals.comment_lines,
         (unsigned long long)totals.blank_lines);
  eri_print_size(totals.bytes);
  printf("\n");
  printf("  top packages:\n");
  for (i = 0; i < packages.len && i < ERI_HOTSPOT_LIMIT; ++i) {
    printf("    %-24s %6llu loc  %4llu files  ", packages.items[i].name,
           (unsigned long long)packages.items[i].code_lines,
           (unsigned long long)packages.items[i].files);
    eri_print_size(packages.items[i].bytes);
    printf("\n");
  }
  printf("\n");

  printf("Tests\n");
  printf("  static proxy: implementation .c files with same-stem tests or test references\n");
  for (i = 0; i < coverage_packages.len && i < ERI_HOTSPOT_LIMIT; ++i) {
    const EriCoveragePackage* pkg = &coverage_packages.items[i];
    uint64_t pct = pkg->source_files == 0u ? 100u : (pkg->tested_source_files * 100u) / pkg->source_files;

    printf("    %-24s %3llu%%  %3llu/%-3llu impl signaled  tests: %3llu files, %5llu loc\n",
           pkg->package, (unsigned long long)pct,
           (unsigned long long)pkg->tested_source_files,
           (unsigned long long)pkg->source_files,
           (unsigned long long)pkg->test_files,
           (unsigned long long)pkg->test_code_lines);
  }
  printf("\n");

  printf("Release binaries\n");
  printf("  stripped size is measured from a temporary copy when strip is available\n");
  if (bins.len == 0u) {
    printf("    none found in VFS snapshot\n");
  } else {
    for (i = 0; i < bins.len && i < ERI_HOTSPOT_LIMIT; ++i) {
      printf("    %-56s original ", bins.items[i].file->path);
      eri_print_size(bins.items[i].size);
      printf("  stripped ");
      if (bins.items[i].stripped_available != 0u) {
        eri_print_size(bins.items[i].stripped_size);
      } else {
        printf("n/a");
      }
      printf("\n");
    }
  }
  printf("\n");

  printf("Issues by group\n");
  printf("  duplication: %llu production, %llu mixed test/source, %llu test-only candidates\n",
         (unsigned long long)eri_count_duplicate_rank(&duplicates, 0u),
         (unsigned long long)eri_count_duplicate_rank(&duplicates, 1u),
         (unsigned long long)eri_count_duplicate_rank(&duplicates, 2u));
  printf("    heuristic: repeated %u-line normalized C blocks; adjacent windows compacted; reasoned ignores honored\n",
         ERI_DUP_BLOCK_LINES);
  if (duplicates.len == 0u) {
    printf("    none\n");
  } else {
    for (i = 0; i < duplicates.len && i < ERI_SAMPLE_LIMIT; ++i) {
      printf("    %s:%u resembles %s:%u\n",
             duplicates.items[i].path_a, duplicates.items[i].line_a,
             duplicates.items[i].path_b, duplicates.items[i].line_b);
    }
    if (duplicates.len > ERI_SAMPLE_LIMIT) {
      printf("    ... %llu more duplicate candidates\n", (unsigned long long)(duplicates.len - ERI_SAMPLE_LIMIT));
    }
  }
  printf("\n");

  printf("  dead code: static functions with no extra references\n");
  {
    size_t shown = 0u;
    for (i = 0; i < funcs.len && shown < ERI_DEAD_CODE_SAMPLE_LIMIT; ++i) {
      if (funcs.items[i].is_static != 0u && funcs.items[i].calls <= 1u) {
        printf("    %s:%u static %s appears unreferenced\n",
               funcs.items[i].path, funcs.items[i].line, funcs.items[i].name);
        ++shown;
      }
    }
    if (shown == 0u) {
      printf("    none\n");
    }
  }
  printf("\n");

  printf("  worldview: %llu findings (%llu host FS/process, %llu path identity, %llu legacy object ids, %llu raw object APIs, %llu WASM32-sized offset reviews)\n",
         (unsigned long long)eri_count_worldview_findings(&findings),
         (unsigned long long)eri_count_findings_kind(&findings, "world-host-fs"),
         (unsigned long long)eri_count_findings_kind(&findings, "world-path-identity"),
         (unsigned long long)eri_count_findings_kind(&findings, "world-legacy-object-id"),
         (unsigned long long)eri_count_findings_kind(&findings, "world-raw-object-api"),
         (unsigned long long)eri_count_findings_kind(&findings, "world-wasm64-offset"));
  if (eri_count_worldview_findings(&findings) == 0u) {
    printf("    none\n");
  } else {
    printf("    hotspots:\n");
    for (i = 0; i < worldview_packages.len && i < ERI_HOTSPOT_LIMIT; ++i) {
      const EriWorldviewPackage* pkg = &worldview_packages.items[i];

      if (eri_worldview_package_score(pkg) == 0u) {
        continue;
      }
      printf("      %-24s score %5llu  host-fs %3llu  path-id %3llu  obj-id %3llu  raw-api %3llu  u64 %3llu  nonprod %4llu\n",
             pkg->package,
             (unsigned long long)eri_worldview_package_score(pkg),
             (unsigned long long)pkg->host_fs_runtime,
             (unsigned long long)pkg->path_identity,
             (unsigned long long)pkg->legacy_object_ids,
             (unsigned long long)pkg->raw_object_apis,
             (unsigned long long)pkg->wasm64_offsets,
             (unsigned long long)pkg->nonprod_findings);
    }
    printf("    samples:\n");
    eri_print_worldview_finding_samples(&findings, ERI_SAMPLE_LIMIT);
  }
  printf("\n");

  printf("  CPU cost: %llu findings (%llu nested loops, %llu calls in loops, %llu division/modulo in loops, %llu memory ops in loops, %llu allocations in loops, %llu I/O ops in loops)\n",
         (unsigned long long)eri_count_cpu_findings(&findings),
         (unsigned long long)eri_count_findings_kind(&findings, "cpu-nested-loop"),
         (unsigned long long)eri_count_findings_kind(&findings, "cpu-call-in-loop"),
         (unsigned long long)eri_count_findings_kind(&findings, "cpu-div-in-loop"),
         (unsigned long long)eri_count_findings_kind(&findings, "cpu-memory-in-loop"),
         (unsigned long long)eri_count_findings_kind(&findings, "cpu-alloc-in-loop"),
         (unsigned long long)eri_count_findings_kind(&findings, "cpu-io-in-loop"));
  if (eri_count_cpu_findings(&findings) == 0u) {
    printf("    none\n");
  } else {
    printf("    hotspots:\n");
    for (i = 0; i < cpu_packages.len && i < ERI_HOTSPOT_LIMIT; ++i) {
      const EriCpuPackage* pkg = &cpu_packages.items[i];

      if (eri_cpu_package_score(pkg) == 0u) {
        continue;
      }
      printf("      %-24s score %5llu  nested %3llu  calls %4llu  div/mod %3llu  mem %3llu  alloc %3llu  io %3llu  nonprod %4llu\n",
             pkg->package,
             (unsigned long long)eri_cpu_package_score(pkg),
             (unsigned long long)pkg->nested_loops,
             (unsigned long long)pkg->calls_in_loops,
             (unsigned long long)pkg->divisions_in_loops,
             (unsigned long long)pkg->memory_ops_in_loops,
             (unsigned long long)pkg->allocations_in_loops,
             (unsigned long long)pkg->io_ops_in_loops,
             (unsigned long long)pkg->nonprod_findings);
    }
    printf("    samples:\n");
    eri_print_cpu_finding_samples(&findings, ERI_SAMPLE_LIMIT);
  }
  printf("\n");

  printf("  smells: %llu findings (%llu large files, %llu long functions, %llu markers, %llu ignore misuse, %llu gotos, %llu magic numbers, %llu string-indexing, %llu math primitives, %llu long lines)\n",
         (unsigned long long)eri_count_smell_findings(&findings),
         (unsigned long long)eri_count_findings_kind(&findings, "large-file"),
         (unsigned long long)eri_count_findings_kind(&findings, "long-function"),
         (unsigned long long)eri_count_findings_kind(&findings, "marker"),
         (unsigned long long)eri_count_findings_kind(&findings, "ignore-misuse"),
         (unsigned long long)eri_count_findings_kind(&findings, "goto"),
         (unsigned long long)eri_count_findings_kind(&findings, "magic-number"),
         (unsigned long long)eri_count_findings_kind(&findings, "string-indexing"),
         (unsigned long long)eri_count_findings_kind(&findings, "math-primitive"),
         (unsigned long long)eri_count_findings_kind(&findings, "long-line"));
  if (eri_count_smell_findings(&findings) == 0u) {
    printf("    none\n");
  } else {
    printf("    hotspots:\n");
    for (i = 0; i < smell_packages.len && i < ERI_HOTSPOT_LIMIT; ++i) {
      const EriSmellPackage* pkg = &smell_packages.items[i];

      if (eri_smell_package_score(pkg) == 0u) {
        continue;
      }
      printf("      %-24s score %5llu  large %2llu  funcs %2llu  markers %2llu  gotos %2llu  magic %4llu  str-index %3llu  math %3llu  long-lines %4llu  nonprod %4llu\n",
             pkg->package,
             (unsigned long long)eri_smell_package_score(pkg),
             (unsigned long long)pkg->large_files,
             (unsigned long long)pkg->long_functions,
             (unsigned long long)pkg->markers,
             (unsigned long long)pkg->gotos,
             (unsigned long long)pkg->magic_numbers,
             (unsigned long long)pkg->string_indexing,
             (unsigned long long)pkg->math_primitives,
             (unsigned long long)pkg->long_lines,
             (unsigned long long)pkg->nonprod_findings);
    }
    printf("    samples:\n");
    eri_print_smell_finding_samples(&findings, ERI_SAMPLE_LIMIT);
    printf("    focused magic-number candidates:\n");
    eri_print_magic_number_finding_samples(&findings, ERI_SAMPLE_LIMIT);
    printf("    focused string-indexing candidates:\n");
    eri_print_string_indexing_finding_samples(&findings, ERI_SAMPLE_LIMIT);
    printf("    focused math primitive candidates:\n");
    eri_print_math_primitive_finding_samples(&findings, ERI_SAMPLE_LIMIT);
  }

  eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                      &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
  return 1;
}
