#ifndef ER_DISK_ANALYZER_H
#define ER_DISK_ANALYZER_H

/*
 * Purpose: hold deterministic disk-analyzer policy shared by UI and storage code.
 * Intention: make destructive cache cleanup depend on explicit classifications, not host paths.
 */

#include "er_types.h"

#define ER_DISK_ANALYZER_ABI_VERSION 1u

typedef enum {
  ER_DISK_ANALYZER_CACHE_NONE = 0,
  ER_DISK_ANALYZER_CACHE_C_BUILD = 1,
  ER_DISK_ANALYZER_CACHE_RUST = 2,
  ER_DISK_ANALYZER_CACHE_NODE = 3,
  ER_DISK_ANALYZER_CACHE_PYTHON = 4,
  ER_DISK_ANALYZER_CACHE_GO = 5
} ErDiskAnalyzerCacheKind;

typedef struct {
  UINT16 abi_version;
  UINT16 cache_kind;
  UINT32 segment_offset;
  UINT32 segment_len;
} ErDiskAnalyzerCacheMatch;

UINT8 er_disk_analyzer_cache_kind_valid(UINT16 cache_kind);
const char* er_disk_analyzer_cache_kind_label(UINT16 cache_kind);
UINT8 er_disk_analyzer_classify_cache_path(const char* path,
                                           UINT32 path_len,
                                           ErDiskAnalyzerCacheMatch* out_match);

#endif
