#include "disk_analyzer.h"

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

#include "er_disk_analyzer.h"

static uint16_t da_cache_kind_for_scan_path(const DaScan* scan, const char* path);
static uint16_t da_cache_delete_kind_for_path(const char* path);

static void da_usage(void) {
  fprintf(stderr,
          "usage: disk-analyzer --root PATH [--top N] [--duplicates N]\n"
          "                     [--min-dup-size BYTES] [--cross-device]\n"
          "                     [--no-duplicates] [--verify-duplicates]\n"
          "                     [--delete-caches --yes]\n"
          "                     [--merge-hardlinks --yes]\n");
}

static int da_parse_u64(const char* text, uint64_t* out) {
  char* end;
  uint64_t multiplier = 1u;
  unsigned long long value;

  if (text == NULL || out == NULL || *text == 0) {
    return -1;
  }
  errno = 0;
  value = strtoull(text, &end, DA_DECIMAL_BASE);
  if (errno != 0 || end == text) {
    return -1;
  }
  switch (*end) {
    case 0:
      multiplier = 1u;
      break;
    case 'k':
    case 'K':
      multiplier = DA_KIB;
      ++end;
      break;
    case 'm':
    case 'M':
      multiplier = (uint64_t)DA_KIB * DA_KIB;
      ++end;
      break;
    case 'g':
    case 'G':
      multiplier = (uint64_t)DA_KIB * DA_KIB * DA_KIB;
      ++end;
      break;
    default:
      return -1;
  }
  if (*end != 0) {
    return -1;
  }
  *out = (uint64_t)value * multiplier;
  return 0;
}

static char* da_strdup(const char* text) {
  size_t len;
  char* copy;

  if (text == NULL) {
    return NULL;
  }
  len = strlen(text);
  copy = malloc(len + 1u);
  if (copy == NULL) {
    return NULL;
  }
  memcpy(copy, text, len + 1u);
  return copy;
}

static int da_vec_reserve(void** items,
                          size_t* cap,
                          size_t count,
                          size_t item_size,
                          size_t initial_cap) {
  void* next;
  size_t next_cap;

  if (count == *cap) {
    next_cap = *cap == 0u ? initial_cap : *cap * DA_VEC_GROWTH_FACTOR;
    next = realloc(*items, next_cap * item_size);
    if (next == NULL) {
      return -1;
    }
    *items = next;
    *cap = next_cap;
  }
  return 0;
}

static int da_dir_vec_push(DaDirVec* vec, DaDir item) {
  if (da_vec_reserve((void**)&vec->items,
                     &vec->cap,
                     vec->count,
                     sizeof(vec->items[0]),
                     DA_DIR_INITIAL_CAP) != 0) {
    return -1;
  }
  vec->items[vec->count] = item;
  ++vec->count;
  return 0;
}

static int da_file_vec_push(DaFileVec* vec, DaFile item) {
  if (da_vec_reserve((void**)&vec->items,
                     &vec->cap,
                     vec->count,
                     sizeof(vec->items[0]),
                     DA_FILE_INITIAL_CAP) != 0) {
    return -1;
  }
  vec->items[vec->count] = item;
  ++vec->count;
  return 0;
}

static int da_compare_dir_rank(const DaDir* left, const DaDir* right) {
  if (left->bytes > right->bytes) {
    return -1;
  }
  if (left->bytes < right->bytes) {
    return 1;
  }
  return strcmp(left->path, right->path);
}

static int da_record_top_dir(DaScan* scan, const char* path, uint64_t bytes, uint64_t files) {
  DaDir record;
  size_t i;
  size_t worst = 0u;

  ++scan->total_dirs;
  if (scan->top_limit == 0u) {
    return 0;
  }
  record.path = da_strdup(path);
  record.bytes = bytes;
  record.files = files;
  record.cache_kind = da_cache_kind_for_scan_path(scan, path);
  if (record.path == NULL) {
    fprintf(stderr, "out of memory while recording %s\n", path);
    return -1;
  }
  if (scan->dirs.count < scan->top_limit) {
    if (da_dir_vec_push(&scan->dirs, record) != 0) {
      free(record.path);
      fprintf(stderr, "out of memory while recording %s\n", path);
      return -1;
    }
    return 0;
  }
  for (i = 1u; i < scan->dirs.count; ++i) {
    if (da_compare_dir_rank(scan->dirs.items + i, scan->dirs.items + worst) > 0) {
      worst = i;
    }
  }
  if (da_compare_dir_rank(&record, scan->dirs.items + worst) < 0) {
    free(scan->dirs.items[worst].path);
    scan->dirs.items[worst] = record;
    return 0;
  }
  free(record.path);
  return 0;
}

static int da_join_path(char* out, size_t out_cap, const char* dir, const char* name) {
  int written;
  const char* slash = "/";

  if (strcmp(dir, "/") == 0) {
    slash = "";
  }
  written = snprintf(out, out_cap, "%s%s%s", dir, slash, name);
  if (written < 0 || (size_t)written >= out_cap) {
    fprintf(stderr, "path too long: %s/%s\n", dir, name);
    return -1;
  }
  return 0;
}

static uint16_t da_cache_kind_for_scan_path(const DaScan* scan, const char* path) {
  ErDiskAnalyzerCacheMatch match;
  const char* classified_path = path;
  size_t root_len = strlen(scan->root);
  size_t len;

  if (strncmp(path, scan->root, root_len) == 0) {
    classified_path = path + root_len;
    if (classified_path[0] == '/') {
      ++classified_path;
    }
  }
  len = strlen(classified_path);
  if (len > UINT32_MAX) {
    return ER_DISK_ANALYZER_CACHE_NONE;
  }
  if (er_disk_analyzer_classify_cache_path(classified_path, (UINT32)len, &match) == 0u) {
    return ER_DISK_ANALYZER_CACHE_NONE;
  }
  return match.cache_kind;
}

static const char* da_path_base(const char* path) {
  const char* slash = strrchr(path, '/');

  if (slash == NULL) {
    return path;
  }
  return slash + 1;
}

static int da_parent_has_marker(const char* path, const char* marker) {
  char parent_marker[DA_PATH_CAP];
  const char* slash = strrchr(path, '/');
  int written;

  if (slash == NULL || slash == path) {
    return 0;
  }
  written = snprintf(parent_marker,
                     sizeof(parent_marker),
                     "%.*s/%s",
                     (int)(slash - path),
                     path,
                     marker);
  if (written < 0 || (size_t)written >= sizeof(parent_marker)) {
    return 0;
  }
  return access(parent_marker, F_OK) == 0;
}

static int da_parent_base_is(const char* path, const char* expected) {
  char parent[DA_PATH_CAP];
  const char* slash = strrchr(path, '/');
  int written;

  if (slash == NULL || slash == path) {
    return 0;
  }
  written = snprintf(parent, sizeof(parent), "%.*s", (int)(slash - path), path);
  if (written < 0 || (size_t)written >= sizeof(parent)) {
    return 0;
  }
  return strcmp(da_path_base(parent), expected) == 0;
}

static int da_child_exists(const char* path, const char* child) {
  char child_path[DA_PATH_CAP];
  int written = snprintf(child_path, sizeof(child_path), "%s/%s", path, child);

  if (written < 0 || (size_t)written >= sizeof(child_path)) {
    return 0;
  }
  return access(child_path, F_OK) == 0;
}

static uint16_t da_cache_delete_kind_for_path(const char* path) {
  const char* base = da_path_base(path);

  if (strcmp(base, ".build") == 0 ||
      strncmp(base, "cmake-build-", DA_CMAKE_BUILD_PREFIX_LEN) == 0) {
    return ER_DISK_ANALYZER_CACHE_C_BUILD;
  }
  if (strcmp(base, "build") == 0 &&
      (da_parent_has_marker(path, "CMakeLists.txt") != 0 ||
       da_parent_has_marker(path, "meson.build") != 0)) {
    return ER_DISK_ANALYZER_CACHE_C_BUILD;
  }
  if ((strcmp(base, "target") == 0 && da_parent_has_marker(path, "Cargo.toml") != 0) ||
      ((strcmp(base, "registry") == 0 || strcmp(base, "git") == 0) &&
       da_parent_base_is(path, ".cargo") != 0)) {
    return ER_DISK_ANALYZER_CACHE_RUST;
  }
  if (strcmp(base, "node_modules") == 0 || strcmp(base, ".next") == 0 ||
      strcmp(base, ".turbo") == 0 ||
      (strcmp(base, "_cacache") == 0 && da_parent_base_is(path, ".npm") != 0) ||
      ((strcmp(base, "cache") == 0 || strcmp(base, "store") == 0) &&
       (da_parent_base_is(path, ".yarn") != 0 || da_parent_base_is(path, ".pnpm") != 0))) {
    return ER_DISK_ANALYZER_CACHE_NODE;
  }
  if (strcmp(base, "__pycache__") == 0 || strcmp(base, ".pytest_cache") == 0 ||
      strcmp(base, ".mypy_cache") == 0 || strcmp(base, ".ruff_cache") == 0 ||
      ((strcmp(base, "pip") == 0 || strcmp(base, "uv") == 0 ||
        strcmp(base, "pypoetry") == 0) &&
       da_parent_base_is(path, ".cache") != 0) ||
      ((strcmp(base, ".venv") == 0 || strcmp(base, "venv") == 0) &&
       da_child_exists(path, "pyvenv.cfg") != 0)) {
    return ER_DISK_ANALYZER_CACHE_PYTHON;
  }
  if (strcmp(base, "go-build") == 0 || strcmp(base, "gomodcache") == 0) {
    return ER_DISK_ANALYZER_CACHE_GO;
  }
  if (strcmp(base, "caches") == 0 && da_parent_base_is(path, ".gradle") != 0) {
    return ER_DISK_ANALYZER_CACHE_C_BUILD;
  }
  if (strcmp(base, "repository") == 0 && da_parent_base_is(path, ".m2") != 0) {
    return ER_DISK_ANALYZER_CACHE_C_BUILD;
  }
  return ER_DISK_ANALYZER_CACHE_NONE;
}

static int da_remove_tree(const char* path,
                          uint64_t* removed_bytes,
                          uint64_t* removed_files,
                          uint64_t* removed_dirs) {
  DIR* dir;
  struct dirent* entry;
  struct stat st;
  char child_path[DA_PATH_CAP];

  if (lstat(path, &st) != 0) {
    fprintf(stderr, "lstat failed for cache path %s: %s\n", path, strerror(errno));
    return -1;
  }
  if (S_ISDIR(st.st_mode)) {
    dir = opendir(path);
    if (dir == NULL) {
      fprintf(stderr, "opendir failed for cache path %s: %s\n", path, strerror(errno));
      return -1;
    }
    while ((entry = readdir(dir)) != NULL) {
      if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
        continue;
      }
      if (da_join_path(child_path, sizeof(child_path), path, entry->d_name) != 0) {
        closedir(dir);
        return -1;
      }
      if (da_remove_tree(child_path, removed_bytes, removed_files, removed_dirs) != 0) {
        closedir(dir);
        return -1;
      }
    }
    if (closedir(dir) != 0) {
      fprintf(stderr, "closedir failed for cache path %s: %s\n", path, strerror(errno));
      return -1;
    }
    if (rmdir(path) != 0) {
      fprintf(stderr, "rmdir failed for cache path %s: %s\n", path, strerror(errno));
      return -1;
    }
    ++*removed_dirs;
    return 0;
  }
  if (S_ISREG(st.st_mode)) {
    *removed_bytes += (uint64_t)st.st_size;
  }
  if (unlink(path) != 0) {
    fprintf(stderr, "unlink failed for cache path %s: %s\n", path, strerror(errno));
    return -1;
  }
  ++*removed_files;
  return 0;
}

static int da_delete_cache_dir(DaScan* scan, const char* path, uint16_t cache_kind) {
  uint64_t removed_bytes = 0u;
  uint64_t removed_files = 0u;
  uint64_t removed_dirs = 0u;

  if (scan->printed_cache_deletes < DA_CACHE_DELETE_PRINT_LIMIT) {
    printf("cache-delete cache=%s path=%s\n",
           er_disk_analyzer_cache_kind_label(cache_kind),
           path);
    ++scan->printed_cache_deletes;
  } else if (scan->printed_cache_deletes == DA_CACHE_DELETE_PRINT_LIMIT) {
    printf("cache-delete output-truncated limit=%llu\n",
           (unsigned long long)DA_CACHE_DELETE_PRINT_LIMIT);
    ++scan->printed_cache_deletes;
  }
  if (da_remove_tree(path, &removed_bytes, &removed_files, &removed_dirs) != 0) {
    return -1;
  }
  scan->deleted_cache_bytes += removed_bytes;
  scan->deleted_cache_files += removed_files;
  scan->deleted_cache_dirs += removed_dirs;
  ++scan->deleted_cache_roots;
  return 0;
}

static int da_scan_dir(DaScan* scan, const char* path, uint64_t* out_bytes, uint64_t* out_files) {
  DIR* dir;
  struct dirent* entry;
  struct stat st;
  char child_path[DA_PATH_CAP];
  uint64_t dir_bytes = 0u;
  uint64_t dir_files = 0u;

  dir = opendir(path);
  if (dir == NULL) {
    fprintf(stderr, "opendir failed for %s: %s\n", path, strerror(errno));
    return -1;
  }
  while ((entry = readdir(dir)) != NULL) {
    uint64_t child_bytes = 0u;
    uint64_t child_files = 0u;
    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
#ifdef DT_DIR
    if (scan->cache_delete_only != 0 &&
        entry->d_type != DT_DIR &&
        entry->d_type != DT_UNKNOWN) {
      continue;
    }
#endif
    if (da_join_path(child_path, sizeof(child_path), path, entry->d_name) != 0) {
      closedir(dir);
      return -1;
    }
    if (lstat(child_path, &st) != 0) {
      fprintf(stderr, "lstat failed for %s: %s\n", child_path, strerror(errno));
      closedir(dir);
      return -1;
    }
    if (scan->cross_device == 0 && st.st_dev != scan->root_dev) {
      continue;
    }
    if (S_ISDIR(st.st_mode)) {
      uint16_t cache_kind = da_cache_delete_kind_for_path(child_path);
      if (scan->delete_caches != 0 &&
          er_disk_analyzer_cache_kind_valid(cache_kind) != 0u) {
        if (da_delete_cache_dir(scan, child_path, cache_kind) != 0) {
          closedir(dir);
          return -1;
        }
        continue;
      }
      if (da_scan_dir(scan, child_path, &child_bytes, &child_files) != 0) {
        closedir(dir);
        return -1;
      }
      dir_bytes += child_bytes;
      dir_files += child_files;
      continue;
    }
    if (S_ISREG(st.st_mode)) {
      DaFile file;
      uint64_t file_bytes = (uint64_t)st.st_size;
      if (scan->collect_files != 0 && file_bytes >= scan->min_dup_size) {
        file.path = da_strdup(child_path);
        file.bytes = file_bytes;
        file.dev = st.st_dev;
        file.ino = st.st_ino;
        file.sample_hash = 0u;
        file.has_sample_hash = 0;
        if (file.path == NULL || da_file_vec_push(&scan->files, file) != 0) {
          free(file.path);
          fprintf(stderr, "out of memory while recording %s\n", child_path);
          closedir(dir);
          return -1;
        }
      }
      dir_bytes += file_bytes;
      ++dir_files;
    }
  }
  if (closedir(dir) != 0) {
    fprintf(stderr, "closedir failed for %s: %s\n", path, strerror(errno));
    return -1;
  }
  if (da_record_top_dir(scan, path, dir_bytes, dir_files) != 0) {
    return -1;
  }
  *out_bytes = dir_bytes;
  *out_files = dir_files;
  return 0;
}

void da_options_init(DaOptions* options) {
  memset(options, 0, sizeof(*options));
  options->min_dup_size = DA_DEFAULT_MIN_DUP_SIZE;
  options->top_limit = DA_DEFAULT_TOP_LIMIT;
  options->duplicate_limit = DA_DEFAULT_DUP_LIMIT;
  options->duplicates_enabled = 1;
}

int da_parse_args(DaOptions* options, int argc, char** argv) {
  int i;

  for (i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--root") == 0) {
      if (i + 1 >= argc) {
        da_usage();
        return -1;
      }
      ++i;
      options->root = argv[i];
      continue;
    }
    if (strcmp(argv[i], "--top") == 0 || strcmp(argv[i], "--duplicates") == 0) {
      uint64_t parsed;
      int is_top = (strcmp(argv[i], "--top") == 0);
      if (i + 1 >= argc || da_parse_u64(argv[i + 1], &parsed) != 0) {
        da_usage();
        return -1;
      }
      ++i;
      if (is_top != 0) {
        options->top_limit = (size_t)parsed;
      } else {
        options->duplicate_limit = (size_t)parsed;
      }
      continue;
    }
    if (strcmp(argv[i], "--min-dup-size") == 0) {
      if (i + 1 >= argc || da_parse_u64(argv[i + 1], &options->min_dup_size) != 0) {
        da_usage();
        return -1;
      }
      ++i;
      continue;
    }
    if (strcmp(argv[i], "--cross-device") == 0) {
      options->cross_device = 1;
      continue;
    }
    if (strcmp(argv[i], "--no-duplicates") == 0) {
      options->duplicates_enabled = 0;
      continue;
    }
    if (strcmp(argv[i], "--verify-duplicates") == 0) {
      options->verify_duplicates = 1;
      continue;
    }
    if (strcmp(argv[i], "--delete-caches") == 0) {
      options->delete_caches = 1;
      continue;
    }
    if (strcmp(argv[i], "--merge-hardlinks") == 0) {
      options->merge_hardlinks = 1;
      continue;
    }
    if (strcmp(argv[i], "--yes") == 0) {
      options->yes = 1;
      continue;
    }
    if (strcmp(argv[i], "--help") == 0) {
      da_usage();
      exit(0);
    }
    da_usage();
    return -1;
  }
  if (options->root == NULL) {
    da_usage();
    return -1;
  }
  if (options->merge_hardlinks != 0 && options->yes == 0) {
    fprintf(stderr, "--merge-hardlinks requires --yes\n");
    return -1;
  }
  if (options->delete_caches != 0 && options->yes == 0) {
    fprintf(stderr, "--delete-caches requires --yes\n");
    return -1;
  }
  if (options->merge_hardlinks != 0) {
    options->verify_duplicates = 1;
  }
  return 0;
}

int da_scan_root(DaScan* scan, const DaOptions* options) {
  struct stat st;

  memset(scan, 0, sizeof(*scan));
  scan->root = options->root;
  scan->cross_device = options->cross_device;
  scan->delete_caches = options->delete_caches;
  scan->collect_files = options->duplicates_enabled;
  scan->cache_delete_only = (int)(options->delete_caches != 0 &&
                                  options->duplicates_enabled == 0 &&
                                  options->top_limit == 0u);
  scan->min_dup_size = options->min_dup_size;
  scan->top_limit = options->top_limit;
  if (lstat(options->root, &st) != 0) {
    fprintf(stderr, "lstat failed for root %s: %s\n", options->root, strerror(errno));
    return -1;
  }
  if (!S_ISDIR(st.st_mode)) {
    fprintf(stderr, "root must be a directory: %s\n", options->root);
    return -1;
  }
  scan->root_dev = st.st_dev;
  if (da_scan_dir(scan, options->root, &scan->total_bytes, &scan->total_files) != 0) {
    da_scan_free(scan);
    return -1;
  }
  return 0;
}

void da_scan_free(DaScan* scan) {
  size_t i;

  for (i = 0u; i < scan->dirs.count; ++i) {
    free(scan->dirs.items[i].path);
  }
  free(scan->dirs.items);
  for (i = 0u; i < scan->files.count; ++i) {
    free(scan->files.items[i].path);
  }
  free(scan->files.items);
  memset(scan, 0, sizeof(*scan));
}

static int da_compare_dirs(const void* left, const void* right) {
  const DaDir* a = left;
  const DaDir* b = right;

  return da_compare_dir_rank(a, b);
}

void da_print_top_folders(DaScan* scan, size_t limit) {
  size_t i;
  size_t shown;

  qsort(scan->dirs.items, scan->dirs.count, sizeof(scan->dirs.items[0]), da_compare_dirs);
  shown = scan->dirs.count < limit ? scan->dirs.count : limit;
  printf("top-folders count=%zu\n", shown);
  for (i = 0u; i < shown; ++i) {
    const DaDir* dir = scan->dirs.items + i;
    printf("folder bytes=%llu files=%llu cache=%s path=%s\n",
           (unsigned long long)dir->bytes,
           (unsigned long long)dir->files,
           er_disk_analyzer_cache_kind_label(dir->cache_kind),
           dir->path);
  }
}
