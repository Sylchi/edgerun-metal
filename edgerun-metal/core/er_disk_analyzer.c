#include "er_disk_analyzer.h"
#include "er_mem.h"

typedef struct {
  const char* name;
  UINT32 len;
  UINT16 kind;
} ErDiskAnalyzerCacheRule;

#define ER_DA_RULE(text, kind_value) { text, (UINT32)(sizeof(text) - 1u), kind_value }

static const ErDiskAnalyzerCacheRule g_cache_rules[] = {
    ER_DA_RULE(".build", ER_DISK_ANALYZER_CACHE_C_BUILD),
    ER_DA_RULE("build", ER_DISK_ANALYZER_CACHE_C_BUILD),
    ER_DA_RULE("target", ER_DISK_ANALYZER_CACHE_RUST),
    ER_DA_RULE("registry", ER_DISK_ANALYZER_CACHE_RUST),
    ER_DA_RULE("node_modules", ER_DISK_ANALYZER_CACHE_NODE),
    ER_DA_RULE(".next", ER_DISK_ANALYZER_CACHE_NODE),
    ER_DA_RULE(".turbo", ER_DISK_ANALYZER_CACHE_NODE),
    ER_DA_RULE("__pycache__", ER_DISK_ANALYZER_CACHE_PYTHON),
    ER_DA_RULE(".pytest_cache", ER_DISK_ANALYZER_CACHE_PYTHON),
    ER_DA_RULE(".mypy_cache", ER_DISK_ANALYZER_CACHE_PYTHON),
    ER_DA_RULE(".ruff_cache", ER_DISK_ANALYZER_CACHE_PYTHON),
    ER_DA_RULE(".venv", ER_DISK_ANALYZER_CACHE_PYTHON),
    ER_DA_RULE("venv", ER_DISK_ANALYZER_CACHE_PYTHON),
    ER_DA_RULE("go-build", ER_DISK_ANALYZER_CACHE_GO),
    ER_DA_RULE("gomodcache", ER_DISK_ANALYZER_CACHE_GO)};

enum {
  ER_DA_CACHE_RULE_COUNT = (UINT32)(sizeof(g_cache_rules) / sizeof(g_cache_rules[0])),
  ER_DA_CMAKE_BUILD_PREFIX_LEN = 12u
};

UINT8 er_disk_analyzer_cache_kind_valid(UINT16 cache_kind) {
  switch (cache_kind) {
    case ER_DISK_ANALYZER_CACHE_C_BUILD:
    case ER_DISK_ANALYZER_CACHE_RUST:
    case ER_DISK_ANALYZER_CACHE_NODE:
    case ER_DISK_ANALYZER_CACHE_PYTHON:
    case ER_DISK_ANALYZER_CACHE_GO:
      return 1u;
    case ER_DISK_ANALYZER_CACHE_NONE:
    default:
      return 0u;
  }
}

const char* er_disk_analyzer_cache_kind_label(UINT16 cache_kind) {
  switch (cache_kind) {
    case ER_DISK_ANALYZER_CACHE_C_BUILD:
      return "c-build";
    case ER_DISK_ANALYZER_CACHE_RUST:
      return "rust";
    case ER_DISK_ANALYZER_CACHE_NODE:
      return "node";
    case ER_DISK_ANALYZER_CACHE_PYTHON:
      return "python";
    case ER_DISK_ANALYZER_CACHE_GO:
      return "go";
    case ER_DISK_ANALYZER_CACHE_NONE:
    default:
      return "none";
  }
}

static UINT8 er_disk_analyzer_segment_matches(const char* path,
                                              UINT32 offset,
                                              UINT32 len,
                                              const char* expected,
                                              UINT32 expected_len) {
  if (len != expected_len) {
    return 0u;
  }
  return er_mem_equal((const UINT8*)path + offset,
                      (const UINT8*)expected,
                      (UINTN)expected_len);
}

static UINT8 er_disk_analyzer_segment_has_prefix(const char* path,
                                                 UINT32 offset,
                                                 UINT32 len,
                                                 const char* expected,
                                                 UINT32 expected_len) {
  if (len < expected_len) {
    return 0u;
  }
  return er_mem_equal((const UINT8*)path + offset,
                      (const UINT8*)expected,
                      (UINTN)expected_len);
}

static UINT8 er_disk_analyzer_segment_rule(const char* path,
                                           UINT32 offset,
                                           UINT32 len,
                                           UINT16* out_kind) {
  UINT32 rule_index;
  const ErDiskAnalyzerCacheRule* rule;

  if (out_kind == 0) {
    return 0u;
  }
  if (er_disk_analyzer_segment_has_prefix(path, offset, len,
                                          "cmake-build-",
                                          ER_DA_CMAKE_BUILD_PREFIX_LEN) != 0u) {
    *out_kind = ER_DISK_ANALYZER_CACHE_C_BUILD;
    return 1u;
  }
  for (rule_index = 0u; rule_index < ER_DA_CACHE_RULE_COUNT; ++rule_index) {
    rule = g_cache_rules + rule_index;
    if (er_disk_analyzer_segment_matches(path, offset, len,
                                         rule->name,
                                         rule->len) != 0u) {
      *out_kind = rule->kind;
      return 1u;
    }
  }
  return 0u;
}

static UINT8 er_disk_analyzer_path_byte_valid(char value) {
  return (UINT8)(value != 0 && value != '\\');
}

UINT8 er_disk_analyzer_classify_cache_path(const char* path,
                                           UINT32 path_len,
                                           ErDiskAnalyzerCacheMatch* out_match) {
  UINT32 start = 0u;
  UINT32 i;

  if (out_match == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_match, (UINTN)sizeof(*out_match));
  if (path == 0 || path_len == 0u) {
    return 0u;
  }
  for (i = 0u; i <= path_len; ++i) {
    UINT8 at_end = (UINT8)(i == path_len);
    UINT8 at_slash = (UINT8)(at_end == 0u && path[i] == '/');
    if (at_end == 0u && at_slash == 0u &&
        er_disk_analyzer_path_byte_valid(path[i]) == 0u) {
      return 0u;
    }
    if (at_end != 0u || at_slash != 0u) {
      UINT32 len = i - start;
      UINT16 kind = ER_DISK_ANALYZER_CACHE_NONE;
      if (len != 0u &&
          er_disk_analyzer_segment_rule(path, start, len, &kind) != 0u) {
        out_match->abi_version = ER_DISK_ANALYZER_ABI_VERSION;
        out_match->cache_kind = kind;
        out_match->segment_offset = start;
        out_match->segment_len = len;
        return 1u;
      }
      start = i + 1u;
    }
  }
  return 0u;
}
