static char* eri_strdup_len(const char* s, size_t len) {
  char* out = (char*)malloc(len + 1u);

  if (out == NULL) {
    return NULL;
  }
  if (len > 0u) {
    memcpy(out, s, len);
  }
  out[len] = 0;
  return out;
}

static char* eri_strdup(const char* s) {
  return eri_strdup_len(s, strlen(s));
}

static void* eri_grow(void* ptr, size_t elem, size_t* cap, size_t need) {
  size_t next = *cap == 0u ? 16u : *cap;
  void* grown;

  while (next < need) {
    next *= 2u;
  }
  grown = realloc(ptr, elem * next);
  if (grown == NULL) {
    return NULL;
  }
  *cap = next;
  return grown;
}

static uint8_t eri_vfs_add(EriVfs* vfs, const char* path, uint8_t* bytes, size_t len, uint8_t executable) {
  EriVfsFile* grown;

  if (vfs->len + 1u > vfs->cap) {
    grown = (EriVfsFile*)eri_grow(vfs->files, sizeof(vfs->files[0]), &vfs->cap, vfs->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    vfs->files = grown;
  }
  vfs->files[vfs->len].path = eri_strdup(path);
  if (vfs->files[vfs->len].path == NULL) {
    return 0;
  }
  vfs->files[vfs->len].bytes = bytes;
  vfs->files[vfs->len].len = len;
  vfs->files[vfs->len].executable = executable;
  ++vfs->len;
  return 1;
}

//@optimizer-ignore-function VFS teardown must release each loaded path and byte buffer
static void eri_vfs_free(EriVfs* vfs) {
  size_t i;

  for (i = 0; i < vfs->len; ++i) {
    free(vfs->files[i].path);
    free(vfs->files[i].bytes);
  }
  free(vfs->files);
}

static uint8_t eri_ends_with(const char* s, const char* suffix) {
  size_t slen = strlen(s);
  size_t suffix_len = strlen(suffix);

  return slen >= suffix_len && memcmp(s + slen - suffix_len, suffix, suffix_len) == 0 ? 1u : 0u;
}

static uint8_t eri_contains_part(const char* path, const char* part) {
  size_t part_len = strlen(part);
  const char* p = path;

  while (*p != 0) {
    if ((p == path || p[-1] == '/') && strncmp(p, part, part_len) == 0 &&
        (p[part_len] == 0 || p[part_len] == '/')) {
      return 1;
    }
    ++p;
  }
  return 0;
}

static uint8_t eri_skip_path(const char* rel) {
  const size_t vendor_ui_len = sizeof(ERI_VENDOR_UI_PATH) - 1u;

  if (rel[0] == 0) {
    return 0;
  }
  if (eri_contains_part(rel, ERI_GIT_PATH) != 0u ||
      eri_contains_part(rel, ERI_LOCAL_BUILD_PATH) != 0u ||
      eri_contains_part(rel, ERI_BUILD_PATH) != 0u ||
      eri_contains_part(rel, ERI_CMAKE_DEBUG_PATH) != 0u ||
      eri_contains_part(rel, ERI_THIRD_PARTY_PATH) != 0u ||
      (strncmp(rel, ERI_VENDOR_UI_PATH, vendor_ui_len) == 0 &&
       (rel[vendor_ui_len] == 0 || rel[vendor_ui_len] == '/'))) {
    return 1;
  }
  return 0;
}

static uint8_t eri_is_build_path(const char* path) {
  return eri_contains_part(path, ERI_LOCAL_BUILD_PATH) != 0u ||
         eri_contains_part(path, ERI_BUILD_PATH) != 0u ||
         eri_contains_part(path, ERI_CMAKE_DEBUG_PATH) != 0u;
}

static uint8_t eri_is_c_source(const char* path) {
  return eri_ends_with(path, ".c") || eri_ends_with(path, ".h") ||
         eri_ends_with(path, ".cc") || eri_ends_with(path, ".cpp") ||
         eri_ends_with(path, ".hpp");
}

static uint8_t eri_is_c_impl(const char* path) {
  return eri_ends_with(path, ".c") || eri_ends_with(path, ".cc") || eri_ends_with(path, ".cpp");
}

static uint8_t eri_is_test_path(const char* path) {
  const char* base = strrchr(path, '/');

  base = base == NULL ? path : base + 1;
  return eri_contains_part(path, "tests") != 0u || strncmp(base, "test_", 5u) == 0 ||
         strstr(base, "_test") != NULL ? 1u : 0u;
}

static uint8_t eri_is_example_path(const char* path) {
  return (uint8_t)(eri_contains_part(path, "examples") != 0u ||
                   eri_contains_part(path, "bench") != 0u ||
                   eri_contains_part(path, "demo") != 0u ||
                   strstr(path, "_demo.c") != NULL);
}

static uint8_t eri_is_nonprod_path(const char* path) {
  return (uint8_t)(eri_is_test_path(path) != 0u || eri_is_example_path(path) != 0u);
}

static uint8_t eri_is_hosted_tool_path(const char* path) {
  return (uint8_t)(eri_contains_part(path, "tools") != 0u ||
                   eri_contains_part(path, "codex") != 0u ||
                   eri_contains_part(path, "scripts") != 0u ||
                   eri_contains_part(path, "bench") != 0u);
}

static uint8_t eri_is_runtime_path(const char* path) {
  return (uint8_t)(eri_is_nonprod_path(path) == 0u &&
                   eri_is_hosted_tool_path(path) == 0u &&
                   eri_is_build_path(path) == 0u);
}

static void eri_package_name(const char* path, char* out, size_t out_cap) {
  const char* slash = strchr(path, '/');
  size_t len = slash == NULL ? strlen(path) : (size_t)(slash - path);

  if (len == 0u) {
    snprintf(out, out_cap, ".");
  } else if (len >= out_cap) {
    memcpy(out, path, out_cap - 1u);
    out[out_cap - 1u] = 0;
  } else {
    memcpy(out, path, len);
    out[len] = 0;
  }
}

static void eri_basename_no_ext(const char* path, char* out, size_t out_cap) {
  const char* base = strrchr(path, '/');
  const char* dot;
  size_t len;

  base = base == NULL ? path : base + 1;
  dot = strrchr(base, '.');
  len = dot == NULL ? strlen(base) : (size_t)(dot - base);
  if (len >= out_cap) {
    len = out_cap - 1u;
  }
  memcpy(out, base, len);
  out[len] = 0;
}

static uint8_t eri_is_generated_header(const char* path, const uint8_t* bytes, size_t len) {
  if (!eri_ends_with(path, ".h")) {
    return 0;
  }
  if (strstr((const char*)bytes, "Generated from") != NULL ||
      strstr((const char*)bytes, "generated from") != NULL ||
      strstr((const char*)bytes, "DO NOT EDIT") != NULL) {
    return 1;
  }
  if (len > 4096u && (strstr((const char*)bytes, "static const unsigned char") != NULL ||
                      strstr((const char*)bytes, "static const UINT8") != NULL ||
                      strstr((const char*)bytes, "const UINT8") != NULL)) {
    return 1;
  }
  return eri_contains_part(path, "generated");
}

static uint8_t eri_is_binary_like(const EriVfsFile* file) {
  size_t i;
  size_t sample = file->len < 256u ? file->len : 256u;
  const char* base = strrchr(file->path, '/');

  base = base == NULL ? file->path : base + 1;

  if (eri_ends_with(file->path, ".o") || eri_ends_with(file->path, ".obj")) {
    return 0;
  }
  if (strcmp(base, ".ninja_deps") == 0 || strcmp(base, ".ninja_log") == 0 ||
      strcmp(base, "CMakeCache.txt") == 0) {
    return 0;
  }
  if (eri_ends_with(file->path, ".efi") || eri_ends_with(file->path, ".wasm") ||
      eri_ends_with(file->path, ".a") || eri_ends_with(file->path, ".so") ||
      eri_ends_with(file->path, ".dylib") || eri_ends_with(file->path, ".bin") ||
      eri_ends_with(file->path, ".ttf")) {
    return 1;
  }
  if (file->executable != 0u && !eri_is_c_source(file->path) && !eri_ends_with(file->path, ".sh")) {
    return 1;
  }
  for (i = 0; i < sample; ++i) {
    uint8_t c = file->bytes[i];
    if (c == 0u) {
      return 1;
    }
  }
  return 0;
}

static uint8_t eri_read_file(const char* full, uint8_t** out_bytes, size_t* out_len) {
  FILE* fp = fopen(full, "rb");
  long len;
  uint8_t* bytes;

  if (fp == NULL) {
    return 0;
  }
  if (fseek(fp, 0, SEEK_END) != 0) {
    fclose(fp);
    return 0;
  }
  len = ftell(fp);
  if (len < 0) {
    fclose(fp);
    return 0;
  }
  if (fseek(fp, 0, SEEK_SET) != 0) {
    fclose(fp);
    return 0;
  }
  bytes = (uint8_t*)malloc((size_t)len + 1u);
  if (bytes == NULL) {
    fclose(fp);
    return 0;
  }
  if ((size_t)len > 0u && fread(bytes, 1u, (size_t)len, fp) != (size_t)len) {
    free(bytes);
    fclose(fp);
    return 0;
  }
  fclose(fp);
  bytes[len] = 0u;
  *out_bytes = bytes;
  *out_len = (size_t)len;
  return 1;
}

static uint8_t eri_load_entries_add(EriLoadEntries* entries, const char* path, uint8_t executable) {
  EriLoadEntry* grown;

  if (entries->len + 1u > entries->cap) {
    grown = (EriLoadEntry*)eri_grow(entries->items, sizeof(entries->items[0]), &entries->cap, entries->len + 1u);
    if (grown == NULL) {
      return 0u;
    }
    entries->items = grown;
  }
  memset(&entries->items[entries->len], 0, sizeof(entries->items[entries->len]));
  entries->items[entries->len].path = eri_strdup(path);
  if (entries->items[entries->len].path == NULL) {
    return 0u;
  }
  entries->items[entries->len].executable = executable;
  ++entries->len;
  return 1u;
}

//@optimizer-ignore-function load-entry teardown must release every queued path and any unread VFS bytes
static void eri_load_entries_free(EriLoadEntries* entries) {
  size_t i;

  for (i = 0u; i < entries->len; ++i) {
    free(entries->items[i].path);
    free(entries->items[i].bytes);
  }
  free(entries->items);
}

//@optimizer-ignore-function repo inspection must recursively enumerate each regular file before parallel reads
static uint8_t eri_collect_dir_entries(EriLoadEntries* entries, const char* root, const char* rel) {
  char full[ERI_MAX_PATH * 2u];
  DIR* dir;
  struct dirent* entry;

  if (rel[0] == 0) {
    snprintf(full, sizeof(full), "%s", root);
  } else {
    snprintf(full, sizeof(full), "%s/%s", root, rel);
  }
  dir = opendir(full);
  if (dir == NULL) {
    fprintf(stderr, "repo-inspect: cannot open %s: %s\n", full, strerror(errno));
    return 0;
  }

  while ((entry = readdir(dir)) != NULL) {
    char child_rel[ERI_MAX_PATH];
    char child_full[ERI_MAX_PATH * 2u];
    struct stat st;

    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    if (rel[0] == 0) {
      snprintf(child_rel, sizeof(child_rel), "%s", entry->d_name);
    } else {
      snprintf(child_rel, sizeof(child_rel), "%s/%s", rel, entry->d_name);
    }
    if (eri_skip_path(child_rel) != 0u) {
      continue;
    }
    snprintf(child_full, sizeof(child_full), "%s/%s", root, child_rel);
    if (stat(child_full, &st) != 0) {
      continue;
    }
    if (S_ISDIR(st.st_mode)) {
      if (eri_collect_dir_entries(entries, root, child_rel) == 0u) {
        closedir(dir);
        return 0;
      }
    } else if (S_ISREG(st.st_mode)) {
      uint8_t executable = (st.st_mode & 0111) != 0 ? 1u : 0u;

      if (eri_load_entries_add(entries, child_rel, executable) == 0u) {
        closedir(dir);
        return 0;
      }
    }
  }
  closedir(dir);
  return 1;
}

//@optimizer-ignore-function load worker claims each queued file and reads its bytes into a stable slot
static void* eri_load_worker(void* arg) {
  EriLoadJobs* jobs = (EriLoadJobs*)arg;

  for (;;) {
    size_t index;
    char full[ERI_MAX_PATH * 2u];

    if (pthread_mutex_lock(&jobs->mutex) != 0) {
      return NULL;
    }
    if (jobs->failed != 0u || jobs->next_index >= jobs->entries->len) {
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
    snprintf(full, sizeof(full), "%s/%s", jobs->root, jobs->entries->items[index].path);
    if (eri_read_file(full, &jobs->entries->items[index].bytes, &jobs->entries->items[index].len) != 0u) {
      jobs->entries->items[index].loaded = 1u;
    }
  }
}

//@optimizer-ignore-function VFS loading reads queued files in parallel then merges loaded files in traversal order
static uint8_t eri_read_entries_parallel(EriLoadEntries* entries, const char* root, size_t thread_count) {
  EriLoadJobs jobs;
  pthread_t threads[ERI_MAX_THREAD_COUNT];
  size_t started = 0u;
  size_t i;

  if (entries->len == 0u) {
    return 1u;
  }
  if (thread_count > entries->len) {
    thread_count = entries->len;
  }
  memset(&jobs, 0, sizeof(jobs));
  jobs.root = root;
  jobs.entries = entries;
  if (pthread_mutex_init(&jobs.mutex, NULL) != 0) {
    return 0u;
  }
  for (i = 0u; i < thread_count; ++i) {
    if (pthread_create(&threads[i], NULL, eri_load_worker, &jobs) != 0) {
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

//@optimizer-ignore-function repo inspection loads every enumerated regular file into the analysis VFS
static uint8_t eri_load_dir(EriVfs* vfs, const char* root, const char* rel) {
  EriLoadEntries entries;
  size_t thread_count;
  size_t i;

  memset(&entries, 0, sizeof(entries));
  if (eri_host_thread_count(&thread_count) == 0u ||
      eri_collect_dir_entries(&entries, root, rel) == 0u ||
      eri_read_entries_parallel(&entries, root, thread_count) == 0u) {
    eri_load_entries_free(&entries);
    return 0u;
  }
  for (i = 0u; i < entries.len; ++i) {
    if (entries.items[i].loaded == 0u) {
      continue;
    }
    if (eri_vfs_add(vfs, entries.items[i].path, entries.items[i].bytes,
                    entries.items[i].len, entries.items[i].executable) == 0u) {
      eri_load_entries_free(&entries);
      return 0u;
    }
    entries.items[i].bytes = NULL;
  }
  eri_load_entries_free(&entries);
  return 1u;
}
