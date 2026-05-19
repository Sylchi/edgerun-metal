static void eri_add_binary(EriBinaries* bins, const EriVfsFile* file) {
  EriBinary* grown;

  if (bins->len + 1u > bins->cap) {
    grown = (EriBinary*)eri_grow(bins->items, sizeof(bins->items[0]), &bins->cap, bins->len + 1u);
    if (grown == NULL) {
      return;
    }
    bins->items = grown;
  }
  bins->items[bins->len].file = file;
  bins->items[bins->len].size = file->len;
  bins->items[bins->len].stripped_size = 0u;
  bins->items[bins->len].stripped_available = 0u;
  ++bins->len;
}

static uint8_t eri_write_temp_file(const char* path, const uint8_t* bytes, size_t len) {
  FILE* fp = fopen(path, "wb");

  if (fp == NULL) {
    return 0;
  }
  if (len > 0u && fwrite(bytes, 1u, len, fp) != len) {
    fclose(fp);
    return 0;
  }
  return fclose(fp) == 0 ? 1u : 0u;
}

static uint8_t eri_file_size(const char* path, uint64_t* out_size) {
  struct stat st;

  if (stat(path, &st) != 0 || out_size == 0) {
    return 0;
  }
  *out_size = (uint64_t)st.st_size;
  return 1;
}

static uint8_t eri_measure_stripped_size(const EriVfsFile* file, const char* strip_command, uint64_t* out_size) {
  char tmpl[] = "/tmp/repo-inspect-strip-XXXXXX";
  char command[ERI_MAX_PATH * 3u];
  int fd;
  int rc;

  if (file == NULL || strip_command == NULL || out_size == NULL) {
    return 0;
  }

  fd = mkstemp(tmpl);
  if (fd < 0) {
    return 0;
  }
  close(fd);
  if (eri_write_temp_file(tmpl, file->bytes, file->len) == 0u) {
    unlink(tmpl);
    return 0;
  }
  snprintf(command, sizeof(command), "%s -s '%s' >/dev/null 2>&1", strip_command, tmpl);
  rc = system(command);
  if (rc != 0 || eri_file_size(tmpl, out_size) == 0u) {
    unlink(tmpl);
    return 0;
  }
  unlink(tmpl);
  return 1;
}

//@optimizer-ignore-function binary worker must claim each artifact and run strip on an isolated temporary copy
static void* eri_binary_worker(void* arg) {
  EriBinaryJobs* jobs = (EriBinaryJobs*)arg;

  for (;;) {
    size_t index;
    uint64_t stripped_size;

    if (pthread_mutex_lock(&jobs->mutex) != 0) {
      return NULL;
    }
    if (jobs->failed != 0u || jobs->next_index >= jobs->bins->len) {
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

    if (eri_measure_stripped_size(jobs->bins->items[index].file, jobs->strip_command, &stripped_size) != 0u) {
      jobs->bins->items[index].stripped_size = stripped_size;
      jobs->bins->items[index].stripped_available = 1u;
    }
  }
}

//@optimizer-ignore-function release-size report must measure each discovered binary artifact
static void eri_measure_binary_release_sizes(EriBinaries* bins, size_t thread_count) {
  EriBinaryJobs jobs;
  pthread_t threads[ERI_MAX_THREAD_COUNT];
  size_t started = 0u;
  size_t i;

  if (bins->len == 0u) {
    return;
  }
  memset(&jobs, 0, sizeof(jobs));
  jobs.bins = bins;
  jobs.strip_command = ERI_STRIP_COMMAND;
  if (thread_count > bins->len) {
    thread_count = bins->len;
  }
  if (pthread_mutex_init(&jobs.mutex, NULL) != 0) {
    return;
  }
  for (i = 0u; i < thread_count; ++i) {
    if (pthread_create(&threads[i], NULL, eri_binary_worker, &jobs) != 0) {
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
  (void)pthread_mutex_destroy(&jobs.mutex);
}

//@optimizer-ignore-function coverage signal scan must compare each source byte against the searched word
