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

_Static_assert(offsetof(EriCoveragePackage, package) == 0u, "package key must be first");
_Static_assert(offsetof(EriSmellPackage, package) == 0u, "package key must be first");
_Static_assert(offsetof(EriCpuPackage, package) == 0u, "package key must be first");
_Static_assert(offsetof(EriWorldviewPackage, package) == 0u, "package key must be first");

static void* eri_package_slot_get(void** items, size_t* len, size_t* cap, size_t item_size,
                                  const char* name) {
  size_t i;
  void* grown;

  for (i = 0; i < *len; ++i) {
    void* item = (uint8_t*)*items + item_size * i;
    const char* package = (const char*)item;

    if (strcmp(package, name) == 0) {
      return item;
    }
  }
  if (*len + 1u > *cap) {
    grown = eri_grow(*items, item_size, cap, *len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    *items = grown;
  }
  memset((uint8_t*)*items + item_size * *len, 0, item_size);
  snprintf((char*)*items + item_size * *len, ERI_PACKAGE_MAX, "%s", name);
  ++(*len);
  return (uint8_t*)*items + item_size * (*len - 1u);
}

static EriCoveragePackage* eri_coverage_package_get(EriCoveragePackages* packages, const char* name) {
  return (EriCoveragePackage*)eri_package_slot_get((void**)&packages->items, &packages->len,
                                                   &packages->cap, sizeof(packages->items[0]),
                                                   name);
}

static EriSmellPackage* eri_smell_package_get(EriSmellPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];

  eri_package_name(path, name, sizeof(name));
  return (EriSmellPackage*)eri_package_slot_get((void**)&packages->items, &packages->len,
                                                &packages->cap, sizeof(packages->items[0]),
                                                name);
}

static EriCpuPackage* eri_cpu_package_get(EriCpuPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];

  eri_package_name(path, name, sizeof(name));
  return (EriCpuPackage*)eri_package_slot_get((void**)&packages->items, &packages->len,
                                              &packages->cap, sizeof(packages->items[0]),
                                              name);
}

static EriWorldviewPackage* eri_worldview_package_get(EriWorldviewPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];

  eri_package_name(path, name, sizeof(name));
  return (EriWorldviewPackage*)eri_package_slot_get((void**)&packages->items, &packages->len,
                                                    &packages->cap, sizeof(packages->items[0]),
                                                    name);
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
