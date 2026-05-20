#include "disk_analyzer.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
  DaFile** items;
  size_t count;
  size_t cap;
} DaFilePtrVec;

static int da_file_ptr_vec_push(DaFilePtrVec* vec, DaFile* item) {
  DaFile** next;
  size_t next_cap;

  if (vec->count == vec->cap) {
    next_cap = vec->cap == 0u ? DA_FILE_PTR_INITIAL_CAP : vec->cap * DA_VEC_GROWTH_FACTOR;
    next = realloc(vec->items, next_cap * sizeof(vec->items[0]));
    if (next == NULL) {
      return -1;
    }
    vec->items = next;
    vec->cap = next_cap;
  }
  vec->items[vec->count] = item;
  ++vec->count;
  return 0;
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
    middle = (file->bytes / DA_VEC_GROWTH_FACTOR) -
             ((uint64_t)DA_SAMPLE_WINDOW_BYTES / DA_VEC_GROWTH_FACTOR);
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
    stats->verified_bytes += (uint64_t)want * DA_VEC_GROWTH_FACTOR;
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
  if (options->duplicate_limit != 0u && *printed >= options->duplicate_limit) {
    stats->stopped_after_limit = 1u;
    return 1;
  }
  ++stats->duplicate_files;
  stats->duplicate_bytes += duplicate->bytes;
  printf("%s bytes=%llu canonical=%s duplicate=%s\n",
         options->verify_duplicates != 0 ? "duplicate" : "duplicate-candidate",
         (unsigned long long)duplicate->bytes,
         canonical->path,
         duplicate->path);
  ++*printed;
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
      int equal = 1;
      if (matched[j - first] != 0u) {
        continue;
      }
      if (options->verify_duplicates != 0) {
        equal = da_files_equal(files[i], files[j], stats);
        if (equal < 0) {
          free(matched);
          return -1;
        }
      }
      if (equal != 0) {
        int report_result = da_report_pair(options, files[i], files[j], printed, stats);
        if (report_result != 0) {
          free(matched);
          return report_result;
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
    if (da_file_ptr_vec_push(&ptrs, scan->files.items + i) != 0) {
      free(ptrs.items);
      return -1;
    }
  }
  qsort(ptrs.items, ptrs.count, sizeof(ptrs.items[0]), da_compare_file_ptrs_size);
  printf("duplicates min-bytes=%llu verify=%d\n",
         (unsigned long long)options->min_dup_size,
         options->verify_duplicates);
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
          if (stats->stopped_after_limit == 0u) {
            free(ptrs.items);
            return -1;
          }
          i = ptrs.count;
          sample_first = size_last;
          break;
        }
        sample_first = sample_last;
      }
    }
    if (stats->stopped_after_limit != 0u) {
      i = ptrs.count;
    } else {
      i = size_last;
    }
  }
  printf("duplicate-summary candidate-size-groups=%llu sampled-files=%llu "
         "verified-bytes=%llu duplicate-files=%llu reclaimable-bytes=%llu "
         "merged-hardlinks=%llu partial=%llu\n",
         (unsigned long long)stats->candidate_size_groups,
         (unsigned long long)stats->sampled_files,
         (unsigned long long)stats->verified_bytes,
         (unsigned long long)stats->duplicate_files,
         (unsigned long long)stats->duplicate_bytes,
         (unsigned long long)stats->merged_hardlinks,
         (unsigned long long)stats->stopped_after_limit);
  free(ptrs.items);
  return 0;
}
