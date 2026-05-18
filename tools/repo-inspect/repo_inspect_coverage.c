static uint8_t eri_file_contains_word(const EriVfsFile* file, const char* word) {
  size_t len = strlen(word);
  size_t pos;

  if (len == 0u) {
    return 0;
  }
  for (pos = 0u; pos + len <= file->len; ++pos) {
    uint8_t before_ok;
    uint8_t after_ok;

    if (memcmp(file->bytes + pos, word, len) != 0) {
      continue;
    }
    before_ok = pos == 0u || !(isalnum((unsigned char)file->bytes[pos - 1u]) || file->bytes[pos - 1u] == '_');
    after_ok = pos + len >= file->len ||
               !(isalnum((unsigned char)file->bytes[pos + len]) || file->bytes[pos + len] == '_');
    if (before_ok != 0u && after_ok != 0u) {
      return 1;
    }
  }
  return 0;
}

static EriCoveragePackage* eri_coverage_package_get(EriCoveragePackages* packages, const char* name) {
  size_t i;
  EriCoveragePackage* grown;

  for (i = 0; i < packages->len; ++i) {
    if (strcmp(packages->items[i].package, name) == 0) {
      return &packages->items[i];
    }
  }
  if (packages->len + 1u > packages->cap) {
    grown = (EriCoveragePackage*)eri_grow(packages->items, sizeof(packages->items[0]),
                                          &packages->cap, packages->len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    packages->items = grown;
  }
  memset(&packages->items[packages->len], 0, sizeof(packages->items[packages->len]));
  snprintf(packages->items[packages->len].package, sizeof(packages->items[packages->len].package), "%s", name);
  ++packages->len;
  return &packages->items[packages->len - 1u];
}

static EriSmellPackage* eri_smell_package_get(EriSmellPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];
  size_t i;
  EriSmellPackage* grown;

  eri_package_name(path, name, sizeof(name));
  for (i = 0; i < packages->len; ++i) {
    if (strcmp(packages->items[i].package, name) == 0) {
      return &packages->items[i];
    }
  }
  if (packages->len + 1u > packages->cap) {
    grown = (EriSmellPackage*)eri_grow(packages->items, sizeof(packages->items[0]),
                                       &packages->cap, packages->len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    packages->items = grown;
  }
  memset(&packages->items[packages->len], 0, sizeof(packages->items[packages->len]));
  snprintf(packages->items[packages->len].package, sizeof(packages->items[packages->len].package), "%s", name);
  ++packages->len;
  return &packages->items[packages->len - 1u];
}

static EriCpuPackage* eri_cpu_package_get(EriCpuPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];
  size_t i;
  EriCpuPackage* grown;

  eri_package_name(path, name, sizeof(name));
  for (i = 0; i < packages->len; ++i) {
    if (strcmp(packages->items[i].package, name) == 0) {
      return &packages->items[i];
    }
  }
  if (packages->len + 1u > packages->cap) {
    grown = (EriCpuPackage*)eri_grow(packages->items, sizeof(packages->items[0]),
                                     &packages->cap, packages->len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    packages->items = grown;
  }
  memset(&packages->items[packages->len], 0, sizeof(packages->items[packages->len]));
  snprintf(packages->items[packages->len].package, sizeof(packages->items[packages->len].package), "%s", name);
  ++packages->len;
  return &packages->items[packages->len - 1u];
}

static EriWorldviewPackage* eri_worldview_package_get(EriWorldviewPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];
  size_t i;
  EriWorldviewPackage* grown;

  eri_package_name(path, name, sizeof(name));

  for (i = 0; i < packages->len; ++i) {
    if (strcmp(packages->items[i].package, name) == 0) {
      return &packages->items[i];
    }
  }
  if (packages->len + 1u > packages->cap) {
    grown = (EriWorldviewPackage*)eri_grow(packages->items, sizeof(packages->items[0]),
                                           &packages->cap, packages->len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    packages->items = grown;
  }
  memset(&packages->items[packages->len], 0, sizeof(packages->items[packages->len]));
  snprintf(packages->items[packages->len].package, sizeof(packages->items[packages->len].package), "%s", name);
  ++packages->len;
  return &packages->items[packages->len - 1u];
}

static uint8_t eri_source_uses_included_tool_tests(const EriVfs* vfs, const char* path) {
  size_t i;

  if (strncmp(path, "tools/repo-inspect/", strlen("tools/repo-inspect/")) != 0) {
    return 0u;
  }
  for (i = 0u; i < vfs->len; ++i) {
    const EriVfsFile* file = &vfs->files[i];

    if (eri_is_build_path(file->path) == 0u && eri_is_test_path(file->path) != 0u &&
        eri_is_binary_like(file) == 0u && eri_file_contains_word(file, "repo-inspect") != 0u) {
      return 1u;
    }
  }
  return 0u;
}

static void eri_mark_source_test_signal(const EriVfs* vfs, EriSourceFiles* sources,
                                        const EriFunctions* funcs, size_t source_index) {
  char stem[128];
  size_t t;
  size_t f;

  if (sources->items[source_index].is_test != 0u || !eri_is_c_impl(sources->items[source_index].path)) {
    return;
  }
  if (eri_source_uses_included_tool_tests(vfs, sources->items[source_index].path) != 0u) {
    sources->items[source_index].has_test_signal = 1u;
    return;
  }
  eri_basename_no_ext(sources->items[source_index].path, stem, sizeof(stem));
  for (t = 0; t < vfs->len && sources->items[source_index].has_test_signal == 0u; ++t) {
    const EriVfsFile* test_file = &vfs->files[t];

    if (eri_is_build_path(test_file->path) != 0u || eri_is_test_path(test_file->path) == 0u ||
        eri_is_binary_like(test_file) != 0u) {
      continue;
    }
    if (strstr(test_file->path, stem) != NULL || eri_file_contains_word(test_file, stem) != 0u) {
      sources->items[source_index].has_test_signal = 1u;
    }
  }
  for (f = 0; f < funcs->len && sources->items[source_index].has_test_signal == 0u; ++f) {
    if (strcmp(funcs->items[f].path, sources->items[source_index].path) != 0) {
      continue;
    }
    if (strlen(funcs->items[f].name) < 8u || strcmp(funcs->items[f].name, "main") == 0) {
      continue;
    }
    for (t = 0; t < vfs->len; ++t) {
      const EriVfsFile* test_file = &vfs->files[t];

      if (eri_is_build_path(test_file->path) == 0u && eri_is_test_path(test_file->path) != 0u &&
          eri_is_binary_like(test_file) == 0u && eri_file_contains_word(test_file, funcs->items[f].name) != 0u) {
        sources->items[source_index].has_test_signal = 1u;
        break;
      }
    }
  }
}

//@optimizer-ignore-function test-signal worker claims source slots and compares each against tests and function refs
static void* eri_test_signal_worker(void* arg) {
  EriTestSignalJobs* jobs = (EriTestSignalJobs*)arg;

  for (;;) {
    size_t index;

    if (pthread_mutex_lock(&jobs->mutex) != 0) {
      return NULL;
    }
    if (jobs->failed != 0u || jobs->next_index >= jobs->sources->len) {
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
    eri_mark_source_test_signal(jobs->vfs, jobs->sources, jobs->funcs, index);
  }
}

//@optimizer-ignore-function coverage proxy must compare implementations, tests, and function references exhaustively
static uint8_t eri_mark_test_signals(const EriVfs* vfs, EriSourceFiles* sources,
                                     const EriFunctions* funcs, size_t thread_count) {
  EriTestSignalJobs jobs;
  pthread_t threads[ERI_MAX_THREAD_COUNT];
  size_t started = 0u;
  size_t i;

  if (sources->len == 0u) {
    return 1u;
  }
  if (thread_count > sources->len) {
    thread_count = sources->len;
  }
  memset(&jobs, 0, sizeof(jobs));
  jobs.vfs = vfs;
  jobs.sources = sources;
  jobs.funcs = funcs;
  if (pthread_mutex_init(&jobs.mutex, NULL) != 0) {
    return 0u;
  }
  for (i = 0u; i < thread_count; ++i) {
    if (pthread_create(&threads[i], NULL, eri_test_signal_worker, &jobs) != 0) {
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
