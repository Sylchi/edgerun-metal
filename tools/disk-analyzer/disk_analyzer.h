#ifndef ER_TOOL_DISK_ANALYZER_H
#define ER_TOOL_DISK_ANALYZER_H

#define _POSIX_C_SOURCE 200809L

#include <stddef.h>
#include <stdint.h>
#include <sys/stat.h>

enum {
  DA_PATH_CAP = 4096,
  DA_DEFAULT_TOP_LIMIT = 20,
  DA_DEFAULT_DUP_LIMIT = 20,
  DA_DEFAULT_MIN_DUP_SIZE = 1048576,
  DA_SAMPLE_WINDOW_BYTES = 65536,
  DA_IO_CHUNK_BYTES = 1048576,
  DA_DECIMAL_BASE = 10,
  DA_KIB = 1024,
  DA_DIR_INITIAL_CAP = 128,
  DA_FILE_INITIAL_CAP = 1024,
  DA_FILE_PTR_INITIAL_CAP = 64,
  DA_VEC_GROWTH_FACTOR = 2,
  DA_TMP_SUFFIX_CAP = 64,
  DA_BYTE_MASK = 255,
  DA_SAMPLE_SPAN_COUNT = 3,
  DA_FNV_OFFSET_BASIS = 1469598103934665603ull,
  DA_FNV_PRIME = 1099511628211ull
};

typedef struct {
  char* path;
  uint64_t bytes;
  uint64_t files;
  uint16_t cache_kind;
} DaDir;

typedef struct {
  char* path;
  uint64_t bytes;
  dev_t dev;
  ino_t ino;
  uint64_t sample_hash;
  int has_sample_hash;
} DaFile;

typedef struct {
  DaDir* items;
  size_t count;
  size_t cap;
} DaDirVec;

typedef struct {
  DaFile* items;
  size_t count;
  size_t cap;
} DaFileVec;

typedef struct {
  DaDirVec dirs;
  DaFileVec files;
  const char* root;
  dev_t root_dev;
  int cross_device;
  uint64_t total_bytes;
  uint64_t total_files;
} DaScan;

typedef struct {
  const char* root;
  uint64_t min_dup_size;
  size_t top_limit;
  size_t duplicate_limit;
  int cross_device;
  int duplicates_enabled;
  int merge_hardlinks;
  int yes;
} DaOptions;

typedef struct {
  uint64_t candidate_size_groups;
  uint64_t sampled_files;
  uint64_t verified_bytes;
  uint64_t duplicate_files;
  uint64_t duplicate_bytes;
  uint64_t merged_hardlinks;
} DaDuplicateStats;

void da_options_init(DaOptions* options);
int da_parse_args(DaOptions* options, int argc, char** argv);
int da_scan_root(DaScan* scan, const DaOptions* options);
void da_scan_free(DaScan* scan);
void da_print_top_folders(DaScan* scan, size_t limit);
int da_report_duplicates(DaScan* scan, const DaOptions* options, DaDuplicateStats* stats);

#endif
