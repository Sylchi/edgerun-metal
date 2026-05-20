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

typedef struct {
  DaFile** items;
  size_t count;
  size_t cap;
} DaFilePtrVec;

static void da_usage(void) {
  fprintf(stderr,
          "usage: disk-analyzer --root PATH [--top N] [--duplicates N]\n"
          "                     [--min-dup-size BYTES] [--cross-device]\n"
          "                     [--no-duplicates] [--merge-hardlinks --yes]\n");
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

static int da_file_ptr_vec_push(DaFilePtrVec* vec, DaFile* item) {
  if (da_vec_reserve((void**)&vec->items,
                     &vec->cap,
                     vec->count,
                     sizeof(vec->items[0]),
                     DA_FILE_PTR_INITIAL_CAP) != 0) {
    return -1;
  }
  vec->items[vec->count] = item;
  ++vec->count;
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
      file.path = da_strdup(child_path);
      file.bytes = (uint64_t)st.st_size;
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
      dir_bytes += file.bytes;
      ++dir_files;
    }
  }
  if (closedir(dir) != 0) {
    fprintf(stderr, "closedir failed for %s: %s\n", path, strerror(errno));
    return -1;
  }
  {
    DaDir record;
    record.path = da_strdup(path);
    record.bytes = dir_bytes;
    record.files = dir_files;
    record.cache_kind = da_cache_kind_for_scan_path(scan, path);
    if (record.path == NULL || da_dir_vec_push(&scan->dirs, record) != 0) {
      free(record.path);
      fprintf(stderr, "out of memory while recording %s\n", path);
      return -1;
    }
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
  return 0;
}

int da_scan_root(DaScan* scan, const DaOptions* options) {
  struct stat st;

  memset(scan, 0, sizeof(*scan));
  scan->root = options->root;
  scan->cross_device = options->cross_device;
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

  if (a->bytes > b->bytes) {
    return -1;
  }
  if (a->bytes < b->bytes) {
    return 1;
  }
  return strcmp(a->path, b->path);
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

static int da_compare_file_ptrs_size(const void* left, const void* right) {
  const DaFile* a = *(DaFile* const*)left;
  const DaFile* b = *(DaFile* const*)right;

  if (a->bytes > b->bytes) {
    return -1;
  }
  if (a->bytes < b->bytes) {
    return 1;
  }
  return strcmp(a->path, b->path);
}

static int da_compare_file_ptrs_sample(const void* left, const void* right) {
  const DaFile* a = *(DaFile* const*)left;
  const DaFile* b = *(DaFile* const*)right;

  if (a->sample_hash < b->sample_hash) {
    return -1;
  }
  if (a->sample_hash > b->sample_hash) {
    return 1;
  }
  return strcmp(a->path, b->path);
}

static uint64_t da_hash_u64(uint64_t hash, uint64_t value) {
  unsigned shift;

  for (shift = 0u; shift < 64u; shift += 8u) {
    hash ^= (value >> shift) & DA_BYTE_MASK;
    hash *= DA_FNV_PRIME;
  }
  return hash;
}

static uint64_t da_hash_bytes(uint64_t hash, const unsigned char* bytes, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    hash ^= bytes[i];
    hash *= DA_FNV_PRIME;
  }
  return hash;
}

static int da_read_exact_span(int fd, uint64_t offset, unsigned char* buffer, size_t len) {
  size_t done = 0u;

  while (done < len) {
    ssize_t got = pread(fd, buffer + done, len - done, (off_t)(offset + done));
    if (got < 0) {
      if (errno == EINTR) {
        continue;
      }
      return -1;
    }
    if (got == 0) {
      return -1;
    }
    done += (size_t)got;
  }
  return 0;
}

static int da_hash_span(int fd,
                        uint64_t offset,
                        uint64_t len,
                        unsigned char* buffer,
                        uint64_t* hash) {
  uint64_t done = 0u;

  while (done < len) {
    uint64_t remaining = len - done;
    size_t want = remaining < DA_SAMPLE_WINDOW_BYTES ? (size_t)remaining : DA_SAMPLE_WINDOW_BYTES;
    if (da_read_exact_span(fd, offset + done, buffer, want) != 0) {
      return -1;
    }
    *hash = da_hash_bytes(*hash, buffer, want);
    done += want;
  }
  return 0;
}

static int da_sample_file(DaFile* file, DaDuplicateStats* stats) {
  int fd;
  unsigned char* buffer;
  uint64_t hash = DA_FNV_OFFSET_BASIS;
  uint64_t middle;
  uint64_t end_offset;

  if (file->has_sample_hash != 0) {
    return 0;
  }
  fd = open(file->path, O_RDONLY);
  if (fd < 0) {
    fprintf(stderr, "open failed for %s: %s\n", file->path, strerror(errno));
    return -1;
  }
  buffer = malloc(DA_SAMPLE_WINDOW_BYTES);
  if (buffer == NULL) {
    close(fd);
    return -1;
  }
  hash = da_hash_u64(hash, file->bytes);
  if (file->bytes <= (uint64_t)DA_SAMPLE_WINDOW_BYTES * DA_SAMPLE_SPAN_COUNT) {
    if (da_hash_span(fd, 0u, file->bytes, buffer, &hash) != 0) {
      free(buffer);
      close(fd);
      fprintf(stderr, "read failed for %s\n", file->path);
      return -1;
    }
    stats->verified_bytes += file->bytes;
  } else {
    middle = (file->bytes / 2u) - ((uint64_t)DA_SAMPLE_WINDOW_BYTES / 2u);
    end_offset = file->bytes - (uint64_t)DA_SAMPLE_WINDOW_BYTES;
    if (da_hash_span(fd, 0u, DA_SAMPLE_WINDOW_BYTES, buffer, &hash) != 0 ||
        da_hash_span(fd, middle, DA_SAMPLE_WINDOW_BYTES, buffer, &hash) != 0 ||
        da_hash_span(fd, end_offset, DA_SAMPLE_WINDOW_BYTES, buffer, &hash) != 0) {
      free(buffer);
      close(fd);
      fprintf(stderr, "read failed for %s\n", file->path);
      return -1;
    }
    stats->verified_bytes += (uint64_t)DA_SAMPLE_WINDOW_BYTES * DA_SAMPLE_SPAN_COUNT;
  }
  free(buffer);
  if (close(fd) != 0) {
    fprintf(stderr, "close failed for %s: %s\n", file->path, strerror(errno));
    return -1;
  }
  file->sample_hash = hash;
  file->has_sample_hash = 1;
  ++stats->sampled_files;
  return 0;
}

static int da_files_equal(const DaFile* left, const DaFile* right, DaDuplicateStats* stats) {
  int a_fd;
  int b_fd;
  unsigned char* a_buf;
  unsigned char* b_buf;
  uint64_t done = 0u;

  if (left->bytes != right->bytes) {
    return 0;
  }
  a_fd = open(left->path, O_RDONLY);
  if (a_fd < 0) {
    fprintf(stderr, "open failed for %s: %s\n", left->path, strerror(errno));
    return -1;
  }
  b_fd = open(right->path, O_RDONLY);
  if (b_fd < 0) {
    fprintf(stderr, "open failed for %s: %s\n", right->path, strerror(errno));
    close(a_fd);
    return -1;
  }
  a_buf = malloc(DA_IO_CHUNK_BYTES);
  b_buf = malloc(DA_IO_CHUNK_BYTES);
  if (a_buf == NULL || b_buf == NULL) {
    free(a_buf);
    free(b_buf);
    close(a_fd);
    close(b_fd);
    return -1;
  }
  while (done < left->bytes) {
    uint64_t remaining = left->bytes - done;
    size_t want = remaining < DA_IO_CHUNK_BYTES ? (size_t)remaining : DA_IO_CHUNK_BYTES;
    if (da_read_exact_span(a_fd, done, a_buf, want) != 0 ||
        da_read_exact_span(b_fd, done, b_buf, want) != 0) {
      free(a_buf);
      free(b_buf);
      close(a_fd);
      close(b_fd);
      fprintf(stderr, "read failed while comparing %s and %s\n", left->path, right->path);
      return -1;
    }
    stats->verified_bytes += (uint64_t)want * 2u;
    if (memcmp(a_buf, b_buf, want) != 0) {
      free(a_buf);
      free(b_buf);
      close(a_fd);
      close(b_fd);
      return 0;
    }
    done += want;
  }
  free(a_buf);
  free(b_buf);
  if (close(a_fd) != 0 || close(b_fd) != 0) {
    fprintf(stderr, "close failed while comparing files\n");
    return -1;
  }
  return 1;
}

static int da_merge_hardlink(const DaFile* canonical, const DaFile* duplicate) {
  struct stat canonical_st;
  struct stat duplicate_st;
  char* tmp_path;
  int written;
  int result = -1;

  if (lstat(canonical->path, &canonical_st) != 0 ||
      lstat(duplicate->path, &duplicate_st) != 0) {
    fprintf(stderr, "stat failed before merge: %s\n", strerror(errno));
    return -1;
  }
  if (canonical_st.st_dev == duplicate_st.st_dev &&
      canonical_st.st_ino == duplicate_st.st_ino) {
    return 0;
  }
  if (canonical_st.st_dev != duplicate_st.st_dev) {
    fprintf(stderr, "cannot hardlink across devices: %s -> %s\n",
            canonical->path,
            duplicate->path);
    return -1;
  }
  tmp_path = malloc(strlen(duplicate->path) + DA_TMP_SUFFIX_CAP);
  if (tmp_path == NULL) {
    return -1;
  }
  written = sprintf(tmp_path, "%s.edgerun-merge-tmp.%ld", duplicate->path, (long)getpid());
  if (written < 0) {
    free(tmp_path);
    return -1;
  }
  if (link(canonical->path, tmp_path) != 0) {
    fprintf(stderr, "link failed for %s: %s\n", tmp_path, strerror(errno));
    free(tmp_path);
    return -1;
  }
  if (rename(tmp_path, duplicate->path) != 0) {
    fprintf(stderr, "rename failed for %s: %s\n", duplicate->path, strerror(errno));
    unlink(tmp_path);
    free(tmp_path);
    return -1;
  }
  if (lstat(duplicate->path, &duplicate_st) == 0 &&
      duplicate_st.st_dev == canonical_st.st_dev &&
      duplicate_st.st_ino == canonical_st.st_ino) {
    result = 0;
  } else {
    fprintf(stderr, "merge verification failed for %s\n", duplicate->path);
  }
  free(tmp_path);
  return result;
}

static int da_report_pair(const DaOptions* options,
                          const DaFile* canonical,
                          const DaFile* duplicate,
                          uint64_t* printed,
                          DaDuplicateStats* stats) {
  if (canonical->dev == duplicate->dev && canonical->ino == duplicate->ino) {
    return 0;
  }
  ++stats->duplicate_files;
  stats->duplicate_bytes += duplicate->bytes;
  if (*printed < options->duplicate_limit) {
    printf("duplicate bytes=%llu canonical=%s duplicate=%s\n",
           (unsigned long long)duplicate->bytes,
           canonical->path,
           duplicate->path);
    ++*printed;
  }
  if (options->merge_hardlinks != 0) {
    if (da_merge_hardlink(canonical, duplicate) != 0) {
      return -1;
    }
    ++stats->merged_hardlinks;
  }
  return 0;
}

static int da_process_sample_group(DaFile** files,
                                   size_t first,
                                   size_t last,
                                   const DaOptions* options,
                                   DaDuplicateStats* stats,
                                   uint64_t* printed) {
  unsigned char* matched;
  size_t i;
  size_t j;

  matched = calloc(last - first, sizeof(matched[0]));
  if (matched == NULL) {
    return -1;
  }
  for (i = first; i < last; ++i) {
    if (matched[i - first] != 0u) {
      continue;
    }
    for (j = i + 1u; j < last; ++j) {
      int equal;
      if (matched[j - first] != 0u) {
        continue;
      }
      equal = da_files_equal(files[i], files[j], stats);
      if (equal < 0) {
        free(matched);
        return -1;
      }
      if (equal != 0) {
        if (da_report_pair(options, files[i], files[j], printed, stats) != 0) {
          free(matched);
          return -1;
        }
        matched[j - first] = 1u;
      }
    }
  }
  free(matched);
  return 0;
}

int da_report_duplicates(DaScan* scan, const DaOptions* options, DaDuplicateStats* stats) {
  DaFilePtrVec ptrs;
  size_t i;
  uint64_t printed = 0u;

  memset(stats, 0, sizeof(*stats));
  memset(&ptrs, 0, sizeof(ptrs));
  for (i = 0u; i < scan->files.count; ++i) {
    if (scan->files.items[i].bytes >= options->min_dup_size &&
        da_file_ptr_vec_push(&ptrs, scan->files.items + i) != 0) {
      free(ptrs.items);
      return -1;
    }
  }
  qsort(ptrs.items, ptrs.count, sizeof(ptrs.items[0]), da_compare_file_ptrs_size);
  printf("duplicates min-bytes=%llu\n", (unsigned long long)options->min_dup_size);
  i = 0u;
  while (i < ptrs.count) {
    size_t size_first = i;
    size_t size_last;
    size_t sample_first;
    uint64_t size_value = ptrs.items[i]->bytes;
    for (size_last = i + 1u;
         size_last < ptrs.count && ptrs.items[size_last]->bytes == size_value;
         ++size_last) {
    }
    if (size_last - size_first > 1u) {
      ++stats->candidate_size_groups;
      for (sample_first = size_first; sample_first < size_last; ++sample_first) {
        if (da_sample_file(ptrs.items[sample_first], stats) != 0) {
          free(ptrs.items);
          return -1;
        }
      }
      qsort(ptrs.items + size_first,
            size_last - size_first,
            sizeof(ptrs.items[0]),
            da_compare_file_ptrs_sample);
      sample_first = size_first;
      while (sample_first < size_last) {
        size_t sample_last;
        uint64_t sample_hash = ptrs.items[sample_first]->sample_hash;
        for (sample_last = sample_first + 1u;
             sample_last < size_last && ptrs.items[sample_last]->sample_hash == sample_hash;
             ++sample_last) {
        }
        if (sample_last - sample_first > 1u &&
            da_process_sample_group(ptrs.items,
                                    sample_first,
                                    sample_last,
                                    options,
                                    stats,
                                    &printed) != 0) {
          free(ptrs.items);
          return -1;
        }
        sample_first = sample_last;
      }
    }
    i = size_last;
  }
  printf("duplicate-summary candidate-size-groups=%llu sampled-files=%llu "
         "verified-bytes=%llu duplicate-files=%llu reclaimable-bytes=%llu "
         "merged-hardlinks=%llu\n",
         (unsigned long long)stats->candidate_size_groups,
         (unsigned long long)stats->sampled_files,
         (unsigned long long)stats->verified_bytes,
         (unsigned long long)stats->duplicate_files,
         (unsigned long long)stats->duplicate_bytes,
         (unsigned long long)stats->merged_hardlinks);
  free(ptrs.items);
  return 0;
}
