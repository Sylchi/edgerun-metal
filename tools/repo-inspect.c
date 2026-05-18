/*
 * Purpose: report C repository shape from a virtual file snapshot.
 * Intention: keep analysis independent from the host filesystem while still
 * offering a small CLI loader for local development.
 */

#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define ERI_MAX_PATH 512u
#define ERI_PACKAGE_MAX 96u
#define ERI_TOP_LIMIT 12u
#define ERI_LONG_LINE 120u
#define ERI_LONG_FUNCTION_LINES 120u
#define ERI_LARGE_FILE_LINES 800u
#define ERI_DUP_BLOCK_LINES 6u
#define ERI_OPTIMIZER_IGNORE_TAG "@optimizer-ignore"
#define ERI_OPTIMIZER_IGNORE_FUNCTION_TAG "@optimizer-ignore-function"
#define ERI_OPTIMIZER_IGNORE_CONSTANT_TAG "@optimizer-ignore-constant"

typedef struct {
  char* path;
  uint8_t* bytes;
  size_t len;
  uint8_t executable;
} EriVfsFile;

typedef struct {
  EriVfsFile* files;
  size_t len;
  size_t cap;
} EriVfs;

typedef struct {
  uint64_t files;
  uint64_t bytes;
  uint64_t total_lines;
  uint64_t code_lines;
  uint64_t comment_lines;
  uint64_t blank_lines;
} EriTotals;

typedef struct {
  char name[ERI_PACKAGE_MAX];
  uint64_t files;
  uint64_t bytes;
  uint64_t code_lines;
} EriPackage;

typedef struct {
  EriPackage* items;
  size_t len;
  size_t cap;
} EriPackages;

typedef struct {
  char* path;
  char* name;
  uint32_t line;
  uint32_t end_line;
  uint8_t is_static;
  uint32_t calls;
} EriFunction;

typedef struct {
  EriFunction* items;
  size_t len;
  size_t cap;
} EriFunctions;

typedef struct {
  char* path;
  uint32_t line;
  char kind[32];
  char text[144];
} EriFinding;

typedef struct {
  EriFinding* items;
  size_t len;
  size_t cap;
} EriFindings;

typedef struct {
  const EriVfsFile* file;
  uint64_t size;
  uint64_t stripped_size;
  uint8_t stripped_available;
} EriBinary;

typedef struct {
  EriBinary* items;
  size_t len;
  size_t cap;
} EriBinaries;

typedef struct {
  char* path;
  uint64_t code_lines;
  uint8_t is_test;
  uint8_t has_test_signal;
} EriSourceFile;

typedef struct {
  EriSourceFile* items;
  size_t len;
  size_t cap;
} EriSourceFiles;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t source_files;
  uint64_t tested_source_files;
  uint64_t source_code_lines;
  uint64_t test_files;
  uint64_t test_code_lines;
} EriCoveragePackage;

typedef struct {
  EriCoveragePackage* items;
  size_t len;
  size_t cap;
} EriCoveragePackages;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t large_files;
  uint64_t long_functions;
  uint64_t markers;
  uint64_t gotos;
  uint64_t long_lines;
  uint64_t magic_numbers;
  uint64_t string_indexing;
  uint64_t math_primitives;
  uint64_t nonprod_findings;
} EriSmellPackage;

typedef struct {
  EriSmellPackage* items;
  size_t len;
  size_t cap;
} EriSmellPackages;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t nested_loops;
  uint64_t calls_in_loops;
  uint64_t divisions_in_loops;
  uint64_t memory_ops_in_loops;
  uint64_t allocations_in_loops;
  uint64_t io_ops_in_loops;
  uint64_t nonprod_findings;
} EriCpuPackage;

typedef struct {
  char package[ERI_PACKAGE_MAX];
  uint64_t host_fs_runtime;
  uint64_t path_identity;
  uint64_t legacy_object_ids;
  uint64_t raw_object_apis;
  uint64_t wasm64_offsets;
  uint64_t nonprod_findings;
} EriWorldviewPackage;

typedef struct {
  EriCpuPackage* items;
  size_t len;
  size_t cap;
} EriCpuPackages;

typedef struct {
  EriWorldviewPackage* items;
  size_t len;
  size_t cap;
} EriWorldviewPackages;

typedef struct {
  uint64_t hash;
  char* path;
  uint32_t line;
} EriDupBlockRef;

typedef struct {
  EriDupBlockRef* items;
  size_t len;
  size_t cap;
} EriDupBlockRefs;

typedef struct {
  char* path_a;
  uint32_t line_a;
  uint8_t is_test_a;
  char* path_b;
  uint32_t line_b;
  uint8_t is_test_b;
  uint64_t hash;
} EriDuplicate;

typedef struct {
  EriDuplicate* items;
  size_t len;
  size_t cap;
} EriDuplicates;

typedef struct {
  uint32_t segment;
  int brace_depth;
  int function_ignore_depth;
  uint8_t pending_optimizer_ignore;
  uint8_t pending_function_ignore;
  uint8_t pending_constant_ignore;
  uint8_t function_ignore_active;
  uint8_t constant_ignore_active;
  uint8_t constant_ignore_macro;
} EriDupIgnoreState;

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
  if (rel[0] == 0) {
    return 0;
  }
  if (eri_contains_part(rel, ".git") != 0u) {
    return 1;
  }
  return 0;
}

static uint8_t eri_is_build_path(const char* path) {
  return eri_contains_part(path, ".build") != 0u ||
         eri_contains_part(path, "build") != 0u ||
         eri_contains_part(path, "cmake-build-debug") != 0u;
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

//@optimizer-ignore-function repo inspection must recursively load each regular file into the analysis VFS
static uint8_t eri_load_dir(EriVfs* vfs, const char* root, const char* rel) {
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
      if (eri_load_dir(vfs, root, child_rel) == 0u) {
        closedir(dir);
        return 0;
      }
    } else if (S_ISREG(st.st_mode)) {
      uint8_t* bytes = NULL;
      size_t len = 0u;
      uint8_t executable = (st.st_mode & 0111) != 0 ? 1u : 0u;

      if (eri_read_file(child_full, &bytes, &len) != 0u) {
        if (eri_vfs_add(vfs, child_rel, bytes, len, executable) == 0u) {
          free(bytes);
          closedir(dir);
          return 0;
        }
      }
    }
  }
  closedir(dir);
  return 1;
}

static EriPackage* eri_package_get(EriPackages* packages, const char* path) {
  char name[ERI_PACKAGE_MAX];
  size_t i;
  EriPackage* grown;

  eri_package_name(path, name, sizeof(name));

  for (i = 0; i < packages->len; ++i) {
    if (strcmp(packages->items[i].name, name) == 0) {
      return &packages->items[i];
    }
  }
  if (packages->len + 1u > packages->cap) {
    grown = (EriPackage*)eri_grow(packages->items, sizeof(packages->items[0]), &packages->cap, packages->len + 1u);
    if (grown == NULL) {
      return NULL;
    }
    packages->items = grown;
  }
  memset(&packages->items[packages->len], 0, sizeof(packages->items[packages->len]));
  snprintf(packages->items[packages->len].name, sizeof(packages->items[packages->len].name), "%s", name);
  ++packages->len;
  return &packages->items[packages->len - 1u];
}

static void eri_add_finding(EriFindings* findings, const char* path, uint32_t line, const char* kind, const char* text) {
  EriFinding* grown;

  if (findings->len + 1u > findings->cap) {
    grown = (EriFinding*)eri_grow(findings->items, sizeof(findings->items[0]), &findings->cap, findings->len + 1u);
    if (grown == NULL) {
      return;
    }
    findings->items = grown;
  }
  findings->items[findings->len].path = eri_strdup(path);
  if (findings->items[findings->len].path == NULL) {
    return;
  }
  findings->items[findings->len].line = line;
  snprintf(findings->items[findings->len].kind, sizeof(findings->items[findings->len].kind), "%s", kind);
  snprintf(findings->items[findings->len].text, sizeof(findings->items[findings->len].text), "%s", text);
  ++findings->len;
}

//@optimizer-ignore-function findings teardown must release each duplicated finding path
static void eri_findings_free(EriFindings* findings) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    free(findings->items[i].path);
  }
  free(findings->items);
}

static uint8_t eri_add_function(EriFunctions* funcs, const char* path, const char* name, size_t name_len,
                                uint32_t line, uint8_t is_static) {
  EriFunction* grown;

  if (funcs->len + 1u > funcs->cap) {
    grown = (EriFunction*)eri_grow(funcs->items, sizeof(funcs->items[0]), &funcs->cap, funcs->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    funcs->items = grown;
  }
  funcs->items[funcs->len].path = eri_strdup(path);
  funcs->items[funcs->len].name = eri_strdup_len(name, name_len);
  if (funcs->items[funcs->len].path == NULL || funcs->items[funcs->len].name == NULL) {
    return 0;
  }
  funcs->items[funcs->len].line = line;
  funcs->items[funcs->len].end_line = line;
  funcs->items[funcs->len].is_static = is_static;
  funcs->items[funcs->len].calls = 0u;
  ++funcs->len;
  return 1;
}

//@optimizer-ignore-function function table teardown must release each duplicated path and function name
static void eri_functions_free(EriFunctions* funcs) {
  size_t i;

  for (i = 0; i < funcs->len; ++i) {
    free(funcs->items[i].path);
    free(funcs->items[i].name);
  }
  free(funcs->items);
}

static uint8_t eri_add_source_file(EriSourceFiles* sources, const char* path, uint64_t code_lines, uint8_t is_test) {
  EriSourceFile* grown;

  if (sources->len + 1u > sources->cap) {
    grown = (EriSourceFile*)eri_grow(sources->items, sizeof(sources->items[0]), &sources->cap, sources->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    sources->items = grown;
  }
  sources->items[sources->len].path = eri_strdup(path);
  if (sources->items[sources->len].path == NULL) {
    return 0;
  }
  sources->items[sources->len].code_lines = code_lines;
  sources->items[sources->len].is_test = is_test;
  sources->items[sources->len].has_test_signal = is_test;
  ++sources->len;
  return 1;
}

//@optimizer-ignore-function source table teardown must release each duplicated path
static void eri_sources_free(EriSourceFiles* sources) {
  size_t i;

  for (i = 0; i < sources->len; ++i) {
    free(sources->items[i].path);
  }
  free(sources->items);
}

static const char* eri_ltrim(const char* s) {
  while (*s != 0 && isspace((unsigned char)*s)) {
    ++s;
  }
  return s;
}

static uint8_t eri_word_before_paren(const char* line, char* out, size_t out_cap, const char** out_start) {
  const char* paren = strchr(line, '(');
  const char* end;
  const char* start;
  size_t len;

  if (paren == NULL) {
    return 0;
  }
  end = paren;
  while (end > line && isspace((unsigned char)end[-1])) {
    --end;
  }
  start = end;
  while (start > line && (isalnum((unsigned char)start[-1]) || start[-1] == '_')) {
    --start;
  }
  if (start == end || !isalpha((unsigned char)start[0]) || (size_t)(end - start) >= out_cap) {
    return 0;
  }
  len = (size_t)(end - start);
  memcpy(out, start, len);
  out[len] = 0;
  *out_start = start;
  return 1;
}

static uint8_t eri_keyword_function_name(const char* name) {
  static const char* words[] = {
    "if", "for", "while", "switch", "return", "sizeof", "case", "typedef", "define"
  };
  size_t i;

  for (i = 0; i < sizeof(words) / sizeof(words[0]); ++i) {
    if (strcmp(name, words[i]) == 0) {
      return 1;
    }
  }
  return 0;
}

static uint8_t eri_probable_function_def(const char* line, char* name, size_t name_cap, uint8_t* is_static) {
  const char* trim = eri_ltrim(line);
  const char* name_start = NULL;
  const char* brace;

  *is_static = 0;
  brace = strchr(trim, '{');
  if (trim[0] == '#' || brace == NULL ||
      (strchr(trim, ';') != NULL && strchr(trim, ';') < brace) ||
      (strchr(trim, '=') != NULL && strchr(trim, '=') < brace)) {
    return 0;
  }
  if (eri_word_before_paren(trim, name, name_cap, &name_start) == 0u || eri_keyword_function_name(name) != 0u) {
    return 0;
  }
  if (strstr(trim, "static ") != NULL && strstr(trim, "static ") < name_start) {
    *is_static = 1;
  }
  return 1;
}

static void eri_copy_without_literals(const uint8_t* bytes, size_t start, size_t end, char* out, size_t out_cap) {
  size_t i;
  size_t n = 0u;
  uint8_t in_string = 0u;
  uint8_t in_char = 0u;
  uint8_t escaped = 0u;

  if (out_cap == 0u) {
    return;
  }
  for (i = start; i < end && n + 1u < out_cap; ++i) {
    uint8_t c = bytes[i];

    if (escaped != 0u) {
      escaped = 0u;
      continue;
    }
    if (in_string != 0u) {
      if (c == '\\') {
        escaped = 1u;
      } else if (c == '"') {
        in_string = 0u;
      }
      continue;
    }
    if (in_char != 0u) {
      if (c == '\\') {
        escaped = 1u;
      } else if (c == '\'') {
        in_char = 0u;
      }
      continue;
    }
    if (c == '"') {
      in_string = 1u;
      continue;
    }
    if (c == '\'') {
      in_char = 1u;
      continue;
    }
    out[n++] = (char)c;
  }
  out[n] = 0;
}

static uint8_t eri_line_starts_with_word(const char* line, const char* word) {
  size_t len = strlen(word);
  const char* trim = eri_ltrim(line);

  return (uint8_t)(strncmp(trim, word, len) == 0 &&
                   (trim[len] == 0 || isspace((unsigned char)trim[len]) || trim[len] == '('));
}

static uint8_t eri_line_declares_constant(const char* line) {
  const char* trim = eri_ltrim(line);
  size_t i = 0u;

  if (trim[0] == '#' || eri_line_starts_with_word(trim, "case") != 0u ||
      eri_line_starts_with_word(trim, "enum") != 0u ||
      strstr(trim, " const ") != NULL || strncmp(trim, "const ", 6u) == 0 ||
      strstr(trim, "static const ") != NULL) {
    return 1;
  }
  while (isupper((unsigned char)trim[i]) || isdigit((unsigned char)trim[i]) || trim[i] == '_') {
    ++i;
  }
  if (i > 0u && isspace((unsigned char)trim[i]) && strchr(trim + i, '=') != NULL) {
    return 1;
  }
  return 0;
}

static uint8_t eri_line_starts_type_decl_block(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "typedef enum", 12u) == 0 ||
                    strncmp(trim, "typedef struct", 14u) == 0 ||
                    strncmp(trim, "typedef union", 13u) == 0 ||
                    eri_line_starts_with_word(trim, "enum") != 0u ||
                    eri_line_starts_with_word(trim, "struct") != 0u ||
                    eri_line_starts_with_word(trim, "union") != 0u) &&
                   strchr(trim, '{') != NULL);
}

static void eri_update_type_decl_block(int brace_delta, uint8_t* type_decl_block, int* type_decl_brace_depth) {
  if (*type_decl_block == 0u) {
    return;
  }
  *type_decl_brace_depth += brace_delta;
  if (*type_decl_brace_depth <= 0) {
    *type_decl_block = 0u;
    *type_decl_brace_depth = 0;
  }
}

static uint8_t eri_common_numeric_literal(uint64_t value) {
  return (uint8_t)(value <= 2u || value == 8u || value == 16u || value == 32u || value == 64u);
}

//@optimizer-ignore-function magic-number scan must inspect each token-like numeric literal on the line
static uint8_t eri_line_has_magic_number(const char* line, char* out_literal, size_t out_cap) {
  const char* trim = eri_ltrim(line);
  size_t i;

  if (eri_line_declares_constant(trim) != 0u) {
    return 0;
  }
  for (i = 0u; trim[i] != 0; ++i) {
    char* end = NULL;
    uint64_t value;
    size_t len;

    if (!isdigit((unsigned char)trim[i])) {
      continue;
    }
    if (i > 0u && (isalnum((unsigned char)trim[i - 1u]) || trim[i - 1u] == '_' || trim[i - 1u] == '.')) {
      continue;
    }
    errno = 0;
    value = strtoull(trim + i, &end, 0);
    if (end == trim + i || errno == ERANGE) {
      continue;
    }
    while (*end == 'u' || *end == 'U' || *end == 'l' || *end == 'L') {
      ++end;
    }
    if (isalnum((unsigned char)*end) || *end == '_' || *end == '.') {
      i = (size_t)(end - trim);
      continue;
    }
    if (eri_common_numeric_literal(value) != 0u) {
      i = (size_t)(end - trim);
      continue;
    }
    len = (size_t)(end - (trim + i));
    if (len >= out_cap) {
      len = out_cap - 1u;
    }
    memcpy(out_literal, trim + i, len);
    out_literal[len] = 0;
    return 1;
  }
  return 0;
}

static uint8_t eri_identifier_contains_string_role(const char* line) {
  static const char* roles[] = {
    "label", "name", "text", "kind", "variant", "category", "icon", "slot"
  };
  size_t i;

  for (i = 0u; i < sizeof(roles) / sizeof(roles[0]); ++i) {
    if (strstr(line, roles[i]) != NULL) {
      return 1;
    }
  }
  return 0;
}

static uint8_t eri_line_declares_metadata_string_table(const char* line) {
  const char* trim = eri_ltrim(line);

  if (strstr(trim, "static const char* const ") == NULL || strstr(trim, "[]") == NULL ||
      strchr(trim, '{') == NULL) {
    return 0;
  }
  return (uint8_t)(strstr(trim, "slots_") != NULL || strstr(trim, "states_") != NULL ||
                   strstr(trim, "_variants") != NULL || strstr(trim, "_keyboard") != NULL ||
                   strstr(trim, "_interactions") != NULL || strstr(trim, "_sides") != NULL);
}

static uint8_t eri_line_has_string_indexing_smell(const char* raw_line, const char* structural_line) {
  const char* trim = eri_ltrim(raw_line);

  if (eri_line_declares_metadata_string_table(trim) != 0u) {
    return 0;
  }
  if (strstr(trim, "char ") != NULL || strstr(trim, "const char ") != NULL ||
      strstr(trim, "static const char ") != NULL || strstr(trim, "buffer") != NULL) {
    return 0;
  }
  if (strstr(structural_line, "control[") != NULL || strstr(structural_line, "stack[") != NULL) {
    return 0;
  }
  if (strstr(structural_line, "_name[") != NULL) {
    return 0;
  }
  if (strstr(trim, "const char*") != NULL && strstr(trim, "[]") != NULL && strchr(trim, '{') != NULL) {
    return 1;
  }
  if (strchr(structural_line, '[') != NULL && strchr(structural_line, ']') != NULL &&
      eri_identifier_contains_string_role(structural_line) != 0u &&
      strstr(structural_line, "sizeof") == NULL && strstr(structural_line, "->") == NULL &&
      strstr(structural_line, "out_") == NULL && strstr(structural_line, "buffer") == NULL) {
    return 1;
  }
  return 0;
}

static uint8_t eri_path_is_shared_math(const char* path) {
  return (uint8_t)(strcmp(path, "include/er_math.h") == 0 || strcmp(path, "./include/er_math.h") == 0);
}

static uint8_t eri_line_has_direct_host_math_call(const char* line) {
  static const char* calls[] = {
    "floorf(", "ceilf(", "sqrtf(", "atan2f(", "fabsf(", "roundf(", "lrintf(",
    "floor(", "ceil(", "sqrt(", "atan2(", "fabs(", "round("
  };
  size_t i;

  for (i = 0u; i < sizeof(calls) / sizeof(calls[0]); ++i) {
    const char* hit = strstr(line, calls[i]);
    if (hit == NULL) {
      continue;
    }
    if (hit > line && (isalnum((unsigned char)hit[-1]) || hit[-1] == '_')) {
      continue;
    }
    if (hit >= line + 8 && strncmp(hit - 8, "er_math_", 8u) == 0) {
      continue;
    }
    if (hit >= line + 3 && strncmp(hit - 3, "vr_", 3u) == 0) {
      continue;
    }
    if (hit >= line + 6 && strncmp(hit - 6, "er_ui_", 6u) == 0) {
      continue;
    }
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_math_primitive_smell(const char* path, const char* raw_line, const char* structural_line) {
  const char* trim = eri_ltrim(raw_line);

  if (eri_path_is_shared_math(path) != 0u) {
    return 0u;
  }
  if (strstr(structural_line, "er_math_") != NULL || strstr(trim, "#include \"er_math.h\"") != NULL) {
    return 0u;
  }
  if (strstr(structural_line, "3.4028234663852886e38f") != NULL ||
      strstr(structural_line, "0x5f3759df") != NULL) {
    return 1u;
  }
  if (strstr(structural_line, "value == value") != NULL ||
      strstr(structural_line, "value != value") != NULL ||
      strstr(structural_line, "isfinite") != NULL) {
    return 1u;
  }
  if (strstr(structural_line, "return a < b ? a : b") != NULL ||
      strstr(structural_line, "return a > b ? a : b") != NULL) {
    return 1u;
  }
  if ((strstr(structural_line, "return min_value") != NULL && strstr(structural_line, "< min_value") != NULL) ||
      (strstr(structural_line, "return max_value") != NULL && strstr(structural_line, "> max_value") != NULL)) {
    return 1u;
  }
  if ((strstr(structural_line, "< 0.0f") != NULL && strstr(structural_line, "return 0.0f") != NULL) ||
      (strstr(structural_line, "> 1.0f") != NULL && strstr(structural_line, "return 1.0f") != NULL)) {
    return 1u;
  }
  if (strstr(structural_line, "* 255.0f") != NULL && strstr(structural_line, "+ 0.5f") != NULL) {
    return 1u;
  }
  if (strstr(structural_line, "truncated = (int") != NULL ||
      strstr(structural_line, "truncated = (INT") != NULL ||
      strstr(structural_line, "truncated = (int64_t") != NULL) {
    return 1u;
  }
  if ((strstr(structural_line, "value / x") != NULL && strstr(structural_line, "0.5f") != NULL) ||
      strstr(structural_line, "1.0e-10f") != NULL ||
      strstr(structural_line, "0.1963f") != NULL ||
      strstr(structural_line, "0.9817f") != NULL) {
    return 1u;
  }
  if (eri_line_has_direct_host_math_call(structural_line) != 0u) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_any_token(const char* line, const char* const* tokens, size_t len);

//@optimizer-ignore-function host filesystem smell scan must check each disallowed runtime token
static uint8_t eri_line_has_host_fs_runtime_smell(const char* path, const char* structural_line) {
  static const char* tokens[] = {
    "fopen(", "freopen(", "open(", "openat(", "read(", "write(", "close(",
    "stat(", "lstat(", "fstat(", "opendir(", "readdir(", "closedir(",
    "mkdir(", "unlink(", "remove(", "rename(", "realpath(", "getcwd(",
    "chdir(", "access(", "system(", "popen(", "fork(", "getenv(",
    "FILE*", "FILE *", "DIR*", "DIR *"
  };
  size_t i;

  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  for (i = 0u; i < sizeof(tokens) / sizeof(tokens[0]); ++i) {
    const char* hit = structural_line;

    while ((hit = strstr(hit, tokens[i])) != NULL) {
      if (hit == structural_line ||
          (!isalnum((unsigned char)hit[-1]) && hit[-1] != '_')) {
        return 1u;
      }
      hit += strlen(tokens[i]);
    }
  }
  return 0u;
}

static uint8_t eri_line_has_path_identity_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if ((strstr(structural_line, "path") != NULL || strstr(structural_line, "name") != NULL) &&
      (strstr(structural_line, "object_id") != NULL || strstr(structural_line, "ErHash") != NULL ||
       strstr(structural_line, "_hash") != NULL || strstr(structural_line, "hash(") != NULL)) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_legacy_object_id_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if (strstr(structural_line, "UINT32 object_id") != NULL ||
      strstr(structural_line, "uint32_t object_id") != NULL) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_raw_object_api_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if (strstr(structural_line, "er_vfs_prepare_object_packet") != NULL ||
      strstr(structural_line, "er_vfs_prepare_object_label_ref") != NULL ||
      strstr(structural_line, "er_vfs_hash_object") != NULL) {
    return 0u;
  }
  if ((strstr(structural_line, "object_bytes") != NULL || strstr(structural_line, "file_data") != NULL) &&
      (strstr(structural_line, "const UINT8*") != NULL || strstr(structural_line, "const uint8_t*") != NULL ||
       strstr(structural_line, "UINT8*") != NULL || strstr(structural_line, "uint8_t*") != NULL) &&
      (strstr(structural_line, "_prepare_") != NULL || strstr(structural_line, "_create(") != NULL ||
       strstr(structural_line, "_init(") != NULL)) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_has_wasm64_offset_smell(const char* path, const char* structural_line) {
  if (eri_is_runtime_path(path) == 0u) {
    return 0u;
  }
  if (strstr(structural_line, "(UINT64") != NULL || strstr(structural_line, "(uint64_t") != NULL ||
      strstr(structural_line, "er_print") != NULL) {
    return 0u;
  }
  if ((strstr(structural_line, "UINT64") != NULL || strstr(structural_line, "uint64_t") != NULL) &&
      (strstr(structural_line, "offset") != NULL || strstr(structural_line, "_len") != NULL ||
       strstr(structural_line, "length") != NULL || strstr(structural_line, "size") != NULL) &&
      strstr(structural_line, "ErHash") == NULL) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_directive_has_reason(const char* line, const char* tag) {
  const char* hit = strstr(line, tag);
  size_t tag_len = strlen(tag);

  if (hit == NULL) {
    return 0u;
  }
  if (strcmp(tag, ERI_OPTIMIZER_IGNORE_TAG) == 0 && hit[tag_len] == '-') {
    return 0u;
  }
  hit += tag_len;
  while (*hit != 0 && isspace((unsigned char)*hit)) {
    ++hit;
  }
  return (uint8_t)(isalnum((unsigned char)*hit) || *hit == '_' || *hit == '-' || *hit == '"' || *hit == '\'');
}

static uint8_t eri_line_mentions_optimizer_ignore(const char* line) {
  return (uint8_t)(strstr(line, ERI_OPTIMIZER_IGNORE_TAG) != NULL);
}

static uint8_t eri_line_has_optimizer_ignore(const char* line) {
  return eri_directive_has_reason(line, ERI_OPTIMIZER_IGNORE_TAG);
}

static uint8_t eri_line_has_optimizer_ignore_function(const char* line) {
  return eri_directive_has_reason(line, ERI_OPTIMIZER_IGNORE_FUNCTION_TAG);
}

static uint8_t eri_line_has_optimizer_ignore_constant(const char* line) {
  return eri_directive_has_reason(line, ERI_OPTIMIZER_IGNORE_CONSTANT_TAG);
}

static uint8_t eri_line_has_removed_optimizer_ignore_block(const char* line) {
  return (uint8_t)(strstr(line, "@optimizer-ignore-begin") != NULL ||
                   strstr(line, "@optimizer-ignore-end") != NULL);
}

static uint8_t eri_line_is_optimizer_ignore_directive(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "//", 2u) == 0 || strncmp(trim, "/*", 2u) == 0) &&
                   eri_line_has_optimizer_ignore(trim) != 0u);
}

static uint8_t eri_line_is_optimizer_ignore_function_directive(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "//", 2u) == 0 || strncmp(trim, "/*", 2u) == 0) &&
                   eri_line_has_optimizer_ignore_function(trim) != 0u);
}

static uint8_t eri_line_is_optimizer_ignore_constant_directive(const char* line) {
  const char* trim = eri_ltrim(line);

  return (uint8_t)((strncmp(trim, "//", 2u) == 0 || strncmp(trim, "/*", 2u) == 0) &&
                   eri_line_has_optimizer_ignore_constant(trim) != 0u);
}

static uint8_t eri_line_has_invalid_optimizer_ignore(const char* line) {
  if (eri_line_mentions_optimizer_ignore(line) == 0u) {
    return 0u;
  }
  if (eri_line_has_removed_optimizer_ignore_block(line) != 0u) {
    return 1u;
  }
  if (eri_line_has_optimizer_ignore(line) != 0u ||
      eri_line_has_optimizer_ignore_function(line) != 0u ||
      eri_line_has_optimizer_ignore_constant(line) != 0u) {
    return 0u;
  }
  return 1u;
}

static uint8_t eri_line_has_loop_start(const char* line) {
  const char* trim = eri_ltrim(line);

  if (strstr(trim, "for(") != NULL || strstr(trim, "for (") != NULL ||
      strstr(trim, "while(") != NULL || strstr(trim, "while (") != NULL) {
    return 1u;
  }
  return 0u;
}

static uint8_t eri_line_ends_with_backslash(const char* line) {
  size_t len = strlen(line);

  while (len > 0u && isspace((unsigned char)line[len - 1u])) {
    --len;
  }
  return (uint8_t)(len > 0u && line[len - 1u] == '\\');
}

static void eri_update_loop_context(const char* structural_line, uint8_t has_loop_start,
                                    int* brace_depth, int* loop_depth,
                                    int* loop_brace_stack, size_t* loop_stack_len) {
  size_t i;
  int opens = 0;
  int closes = 0;

  for (i = 0u; structural_line[i] != 0; ++i) {
    if (structural_line[i] == '{') {
      ++opens;
    } else if (structural_line[i] == '}') {
      ++closes;
    }
  }
  if (has_loop_start != 0u && opens > closes && *loop_stack_len < 128u) {
    loop_brace_stack[*loop_stack_len] = *brace_depth + opens - closes;
    ++(*loop_stack_len);
    ++(*loop_depth);
  }
  for (i = 0u; structural_line[i] != 0; ++i) {
    if (structural_line[i] == '{') {
      ++(*brace_depth);
    } else if (structural_line[i] == '}' && *brace_depth > 0) {
      --(*brace_depth);
    }
  }
}

static int eri_line_brace_delta(const char* structural_line) {
  size_t i;
  int delta = 0;

  for (i = 0u; structural_line[i] != 0; ++i) {
    if (structural_line[i] == '{') {
      ++delta;
    } else if (structural_line[i] == '}') {
      --delta;
    }
  }
  return delta;
}

static uint8_t eri_line_has_division_or_modulo(const char* line) {
  size_t i;

  for (i = 0u; line[i] != 0; ++i) {
    if (line[i] == '%') {
      return 1u;
    }
    if (line[i] == '/' && line[i + 1u] != '/' && line[i + 1u] != '*' &&
        (i == 0u || line[i - 1u] != '*')) {
      return 1u;
    }
  }
  return 0u;
}

static uint8_t eri_line_has_any_token(const char* line, const char* const* tokens, size_t len) {
  size_t i;

  for (i = 0u; i < len; ++i) {
    if (strstr(line, tokens[i]) != NULL) {
      return 1u;
    }
  }
  return 0u;
}

static uint8_t eri_line_has_memory_op(const char* line) {
  static const char* tokens[] = {
    "memcpy(", "memmove(", "memset(", "memcmp(", "er_mem_copy(", "er_mem_zero(",
    "eri_zero(", "vr_memcpy(", "vr_memset("
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

static uint8_t eri_line_has_allocator_op(const char* line) {
  static const char* tokens[] = {
    "malloc(", "calloc(", "realloc(", "free(", "eri_grow(", "_alloc(", "_realloc(", "alloc_"
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

static uint8_t eri_line_has_io_op(const char* line) {
  static const char* tokens[] = {
    "er_mmio_", "er_pci_", "er_bus_in", "er_bus_out", "er_io_in", "er_io_out",
    "LocateProtocol(", "HandleProtocol(", "OutputString(", "Poll(", "Transmit(",
    "Configure(", "Read(", "Write("
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

static uint8_t eri_line_has_expensive_domain_call(const char* line) {
  static const char* tokens[] = {
    "hash(", "compress", "rasterize", "shape", "measure", "render", "draw",
    "scan", "decode", "parse", "layout", "paint", "blit", "map("
  };

  return eri_line_has_any_token(line, tokens, sizeof(tokens) / sizeof(tokens[0]));
}

//@optimizer-ignore-function CPU-cost analysis must scan every line while maintaining loop nesting state
static void eri_scan_cpu_costs(const EriVfsFile* file, EriFindings* findings) {
  const uint8_t* bytes = file->bytes;
  size_t len = file->len;
  size_t pos = 0u;
  uint32_t line_no = 1u;
  int brace_depth = 0;
  int loop_depth = 0;
  int loop_brace_stack[128];
  size_t loop_stack_len = 0u;
  uint8_t pending_optimizer_ignore = 0u;
  uint8_t pending_function_ignore = 0u;
  uint8_t function_ignore_active = 0u;
  int function_ignore_depth = 0;

  while (pos <= len) {
    size_t start = pos;
    size_t end;
    size_t copy_len;
    char snippet[256];
    char structural_line[1024];
    uint8_t has_loop_start;

    while (pos < len && bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < len && bytes[pos] == '\n') {
      ++pos;
    } else if (start == len) {
      break;
    }
    if (end > start && bytes[end - 1u] == '\r') {
      --end;
    }
    copy_len = end - start;
    if (copy_len >= sizeof(snippet)) {
      copy_len = sizeof(snippet) - 1u;
    }
    memcpy(snippet, bytes + start, copy_len);
    snippet[copy_len] = 0;
    eri_copy_without_literals(bytes, start, end, structural_line, sizeof(structural_line));

    while (loop_stack_len > 0u && brace_depth < loop_brace_stack[loop_stack_len - 1u]) {
      --loop_stack_len;
      if (loop_depth > 0) {
        --loop_depth;
      }
    }

    if (function_ignore_active != 0u) {
      has_loop_start = eri_line_has_loop_start(structural_line);
      eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
      if (brace_depth < function_ignore_depth) {
        function_ignore_active = 0u;
      }
      ++line_no;
      continue;
    }

    if (eri_line_has_invalid_optimizer_ignore(structural_line) != 0u) {
      has_loop_start = eri_line_has_loop_start(structural_line);
      eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
      ++line_no;
      continue;
    }

    if (eri_line_is_optimizer_ignore_function_directive(snippet) != 0u) {
      pending_function_ignore = 1u;
      has_loop_start = eri_line_has_loop_start(structural_line);
      eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
      ++line_no;
      continue;
    }

    if (eri_line_is_optimizer_ignore_directive(snippet) != 0u) {
      pending_optimizer_ignore = 1u;
      has_loop_start = eri_line_has_loop_start(structural_line);
      eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
      ++line_no;
      continue;
    }

    if (pending_function_ignore != 0u) {
      char func_name[128];
      uint8_t is_static;

      if (eri_probable_function_def(structural_line, func_name, sizeof(func_name), &is_static) != 0u ||
          strchr(structural_line, '{') != NULL) {
        int brace_delta = eri_line_brace_delta(structural_line);

        pending_function_ignore = 0u;
        function_ignore_active = 1u;
        has_loop_start = eri_line_has_loop_start(structural_line);
        eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
        function_ignore_depth = brace_depth;
        if (brace_delta <= 0) {
          function_ignore_active = 0u;
        }
        (void)is_static;
        ++line_no;
        continue;
      }
      if (strchr(structural_line, ';') == NULL && strchr(structural_line, '}') == NULL) {
        ++line_no;
        continue;
      }
      pending_function_ignore = 0u;
    }

    if (pending_optimizer_ignore != 0u || eri_line_has_optimizer_ignore(snippet) != 0u ||
        eri_line_has_optimizer_ignore_constant(snippet) != 0u) {
      pending_optimizer_ignore = 0u;
      has_loop_start = eri_line_has_loop_start(structural_line);
      eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
      ++line_no;
      continue;
    }

    has_loop_start = eri_line_has_loop_start(structural_line);
    if (has_loop_start != 0u && loop_depth > 0) {
      eri_add_finding(findings, file->path, line_no, "cpu-nested-loop", "nested loop may multiply CPU work");
    }
    if (loop_depth > 0) {
      if (eri_line_has_allocator_op(structural_line) != 0u) {
        eri_add_finding(findings, file->path, line_no, "cpu-alloc-in-loop", "allocator/free operation inside loop");
      }
      if (eri_line_has_io_op(structural_line) != 0u) {
        eri_add_finding(findings, file->path, line_no, "cpu-io-in-loop", "hardware/firmware I/O call inside loop");
      }
      if (eri_line_has_memory_op(structural_line) != 0u) {
        eri_add_finding(findings, file->path, line_no, "cpu-memory-in-loop", "memory operation inside loop");
      }
      if (eri_line_has_division_or_modulo(structural_line) != 0u) {
        eri_add_finding(findings, file->path, line_no, "cpu-div-in-loop", "division or modulo inside loop");
      }
      if (eri_line_has_expensive_domain_call(structural_line) != 0u) {
        eri_add_finding(findings, file->path, line_no, "cpu-call-in-loop", "domain-heavy helper call inside loop");
      }
    }

    eri_update_loop_context(structural_line, has_loop_start, &brace_depth, &loop_depth, loop_brace_stack, &loop_stack_len);
    ++line_no;
  }
}

//@optimizer-ignore-function line metric analysis must scan every byte and every source line once
static void eri_scan_line_metrics(const uint8_t* bytes, size_t len, EriTotals* file_totals,
                                  EriFindings* findings, const char* path) {
  size_t pos = 0u;
  uint8_t in_block = 0u;
  uint32_t line_no = 1u;
  uint8_t pending_optimizer_ignore = 0u;
  uint8_t pending_function_ignore = 0u;
  uint8_t pending_constant_ignore = 0u;
  uint8_t function_ignore_active = 0u;
  uint8_t constant_ignore_active = 0u;
  uint8_t constant_ignore_macro = 0u;
  int function_ignore_depth = 0;
  int brace_depth = 0;
  uint8_t type_decl_block = 0u;
  int type_decl_brace_depth = 0;

  while (pos <= len) {
    size_t start = pos;
    size_t end;
    size_t i;
    uint8_t has_code = 0u;
    uint8_t has_comment = 0u;
    char snippet[144];

    while (pos < len && bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < len && bytes[pos] == '\n') {
      ++pos;
    } else if (start == len) {
      break;
    }
    ++file_totals->total_lines;

    if (end > start && bytes[end - 1u] == '\r') {
      --end;
    }
    for (i = start; i < end;) {
      uint8_t c = bytes[i];
      if (in_block != 0u) {
        has_comment = 1u;
        if (i + 1u < end && bytes[i] == '*' && bytes[i + 1u] == '/') {
          in_block = 0u;
          i += 2u;
        } else {
          ++i;
        }
      } else if (i + 1u < end && bytes[i] == '/' && bytes[i + 1u] == '*') {
        has_comment = 1u;
        in_block = 1u;
        i += 2u;
      } else if (i + 1u < end && bytes[i] == '/' && bytes[i + 1u] == '/') {
        has_comment = 1u;
        break;
      } else if (!isspace((unsigned char)c)) {
        has_code = 1u;
        ++i;
      } else {
        ++i;
      }
    }
    if (has_code != 0u) {
      ++file_totals->code_lines;
    } else if (has_comment != 0u) {
      ++file_totals->comment_lines;
    } else {
      ++file_totals->blank_lines;
    }
    if (end > start) {
      size_t copy_len = end - start;
      char searchable[144];
      char literal[32];
      uint8_t line_in_type_decl = type_decl_block;

      if (copy_len >= sizeof(snippet)) {
        copy_len = sizeof(snippet) - 1u;
      }
      memcpy(snippet, bytes + start, copy_len);
      snippet[copy_len] = 0;
      eri_copy_without_literals(bytes, start, end, searchable, sizeof(searchable));
      if (line_in_type_decl == 0u && eri_line_starts_type_decl_block(searchable) != 0u) {
        line_in_type_decl = 1u;
        type_decl_block = 1u;
      }
      if (function_ignore_active != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        if (brace_depth < function_ignore_depth) {
          function_ignore_active = 0u;
        }
        ++line_no;
        continue;
      }
      if (constant_ignore_active != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);

        if ((constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) == 0u) ||
            (constant_ignore_macro == 0u && strchr(searchable, ';') != NULL)) {
          constant_ignore_active = 0u;
          constant_ignore_macro = 0u;
        }
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        ++line_no;
        continue;
      }
      if (eri_line_has_invalid_optimizer_ignore(searchable) != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);

        eri_add_finding(findings, path, line_no, "ignore-misuse",
                        "optimizer ignore must use line, function, or constant scope with an explicit reason");
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        ++line_no;
        continue;
      }
      if (eri_line_is_optimizer_ignore_function_directive(snippet) != 0u) {
        pending_function_ignore = 1u;
        ++line_no;
        continue;
      }
      if (eri_line_is_optimizer_ignore_constant_directive(snippet) != 0u) {
        pending_constant_ignore = 1u;
        ++line_no;
        continue;
      }
      if (eri_line_is_optimizer_ignore_directive(snippet) != 0u) {
        pending_optimizer_ignore = 1u;
        ++line_no;
        continue;
      }
      if (pending_function_ignore != 0u) {
        char func_name[128];
        uint8_t is_static;

        if (eri_probable_function_def(searchable, func_name, sizeof(func_name), &is_static) != 0u ||
            strchr(searchable, '{') != NULL) {
          int brace_delta = eri_line_brace_delta(searchable);

          pending_function_ignore = 0u;
          function_ignore_active = 1u;
          brace_depth += brace_delta;
          function_ignore_depth = brace_depth;
          if (brace_delta <= 0) {
            function_ignore_active = 0u;
          }
          (void)is_static;
          ++line_no;
          continue;
        }
        if (strchr(searchable, ';') != NULL || strchr(searchable, '}') != NULL) {
          pending_function_ignore = 0u;
          eri_add_finding(findings, path, line_no, "ignore-misuse",
                          "optimizer-ignore-function must be immediately before a function definition");
        }
      }
      if (pending_constant_ignore != 0u) {
        const char* trim = eri_ltrim(searchable);

        pending_constant_ignore = 0u;
        constant_ignore_macro = trim[0] == '#' ? 1u : 0u;
        if ((constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) != 0u) ||
            (constant_ignore_macro == 0u && strchr(searchable, ';') == NULL)) {
          constant_ignore_active = 1u;
        }
        brace_depth += eri_line_brace_delta(searchable);
        ++line_no;
        continue;
      }
      if (pending_optimizer_ignore != 0u || eri_line_has_optimizer_ignore(snippet) != 0u ||
          eri_line_has_optimizer_ignore_constant(snippet) != 0u) {
        int brace_delta = eri_line_brace_delta(searchable);

        pending_optimizer_ignore = 0u;
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
        ++line_no;
        continue;
      }
      if (end - start > ERI_LONG_LINE) {
        snprintf(snippet, sizeof(snippet), "line has %lu columns", (unsigned long)(end - start));
        eri_add_finding(findings, path, line_no, "long-line", snippet);
      }
      if (strstr(searchable, "TODO") != NULL || strstr(searchable, "FIXME") != NULL || strstr(searchable, "HACK") != NULL) {
        eri_add_finding(findings, path, line_no, "marker", eri_ltrim(snippet));
      }
      if (strstr(searchable, "goto ") != NULL) {
        eri_add_finding(findings, path, line_no, "goto", eri_ltrim(snippet));
      }
      if (line_in_type_decl == 0u && eri_line_has_magic_number(searchable, literal, sizeof(literal)) != 0u) {
        char text[144];
        snprintf(text, sizeof(text), "numeric literal %s in executable code", literal);
        eri_add_finding(findings, path, line_no, "magic-number", text);
      }
      if (eri_line_has_string_indexing_smell(snippet, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "string-indexing", "string table/indexing may need enum/count guard");
      }
      if (eri_line_has_math_primitive_smell(path, snippet, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "math-primitive", "local math primitive should use include/er_math.h");
      }
      if (eri_line_has_host_fs_runtime_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-host-fs",
                        "runtime code reaches for host filesystem/process API");
      }
      if (eri_line_has_path_identity_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-path-identity",
                        "path/name appears coupled to object identity or hashing");
      }
      if (eri_line_has_legacy_object_id_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-legacy-object-id",
                        "small numeric object_id should be an ErHash for content-addressed objects");
      }
      if (eri_line_has_raw_object_api_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-raw-object-api",
                        "runtime API takes raw object bytes where object hash/length may be enough");
      }
      if (eri_line_has_wasm64_offset_smell(path, searchable) != 0u) {
        eri_add_finding(findings, path, line_no, "world-wasm64-offset",
                        "64-bit length/offset in runtime path needs a WASM32 reason");
      }
      {
        int brace_delta = eri_line_brace_delta(searchable);
        brace_depth += brace_delta;
        eri_update_type_decl_block(brace_delta, &type_decl_block, &type_decl_brace_depth);
      }
    } else if (pending_optimizer_ignore != 0u) {
      pending_optimizer_ignore = 0u;
    }
    ++line_no;
  }
}

//@optimizer-ignore-function function analysis must scan every line and brace transition in each C source file
static void eri_scan_functions(const EriVfsFile* file, EriFunctions* funcs, EriFindings* findings) {
  const uint8_t* bytes = file->bytes;
  size_t len = file->len;
  size_t pos = 0u;
  uint32_t line_no = 1u;
  int brace_depth = 0;
  size_t active_func = (size_t)-1;

  while (pos <= len) {
    size_t start = pos;
    size_t end;
    char line[1024];
    char structural_line[1024];
    size_t copy_len;
    size_t i;
    char name[128];
    uint8_t is_static;

    while (pos < len && bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < len && bytes[pos] == '\n') {
      ++pos;
    } else if (start == len) {
      break;
    }
    if (end > start && bytes[end - 1u] == '\r') {
      --end;
    }
    copy_len = end - start;
    if (copy_len >= sizeof(line)) {
      copy_len = sizeof(line) - 1u;
    }
    memcpy(line, bytes + start, copy_len);
    line[copy_len] = 0;
    eri_copy_without_literals(bytes, start, end, structural_line, sizeof(structural_line));

    if (brace_depth == 0 && eri_probable_function_def(structural_line, name, sizeof(name), &is_static) != 0u) {
      if (eri_add_function(funcs, file->path, name, strlen(name), line_no, is_static) != 0u) {
        active_func = funcs->len - 1u;
      }
    }

    for (i = 0; structural_line[i] != 0; ++i) {
      if (structural_line[i] == '{') {
        ++brace_depth;
      } else if (structural_line[i] == '}' && brace_depth > 0) {
        --brace_depth;
        if (brace_depth == 0 && active_func != (size_t)-1) {
          funcs->items[active_func].end_line = line_no;
          if (line_no - funcs->items[active_func].line + 1u > ERI_LONG_FUNCTION_LINES) {
            char text[128];
            snprintf(text, sizeof(text), "%s spans %u lines", funcs->items[active_func].name,
                     line_no - funcs->items[active_func].line + 1u);
            eri_add_finding(findings, file->path, funcs->items[active_func].line, "long-function", text);
          }
          active_func = (size_t)-1;
        }
      }
    }
    ++line_no;
  }
}

//@optimizer-ignore-function function reference analysis must compare every known function name against source bytes
static void eri_count_function_refs(const EriVfs* vfs, EriFunctions* funcs) {
  size_t f;

  for (f = 0; f < funcs->len; ++f) {
    size_t name_len = strlen(funcs->items[f].name);
    size_t file_i;

    for (file_i = 0; file_i < vfs->len; ++file_i) {
      const EriVfsFile* file = &vfs->files[file_i];
      size_t pos;

      if (eri_is_build_path(file->path) != 0u || !eri_is_c_source(file->path)) {
        continue;
      }
      for (pos = 0u; pos + name_len < file->len; ++pos) {
        uint8_t before_ok;
        uint8_t after_ok;

        if (memcmp(file->bytes + pos, funcs->items[f].name, name_len) != 0) {
          continue;
        }
        before_ok = pos == 0u || !(isalnum((unsigned char)file->bytes[pos - 1u]) || file->bytes[pos - 1u] == '_');
        after_ok = pos + name_len >= file->len ||
                   !(isalnum((unsigned char)file->bytes[pos + name_len]) || file->bytes[pos + name_len] == '_');
        if (before_ok != 0u && after_ok != 0u) {
          ++funcs->items[f].calls;
        }
      }
    }
  }
}

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

static uint8_t eri_command_exists(const char* command) {
  char check[160];
  int rc;

  snprintf(check, sizeof(check), "command -v %s >/dev/null 2>&1", command);
  rc = system(check);
  return rc == 0 ? 1u : 0u;
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

static uint8_t eri_measure_stripped_size(const EriVfsFile* file, uint64_t* out_size) {
  char tmpl[] = "/tmp/repo-inspect-strip-XXXXXX";
  char command[ERI_MAX_PATH * 3u];
  const char* strip_command = NULL;
  int fd;
  int rc;

  if (file == NULL || out_size == NULL) {
    return 0;
  }
  if (eri_command_exists("llvm-strip") != 0u) {
    strip_command = "llvm-strip";
  } else if (eri_command_exists("strip") != 0u) {
    strip_command = "strip";
  } else {
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

//@optimizer-ignore-function release-size report must measure each discovered binary artifact
static void eri_measure_binary_release_sizes(EriBinaries* bins) {
  size_t i;

  for (i = 0; i < bins->len; ++i) {
    uint64_t stripped_size;

    if (eri_measure_stripped_size(bins->items[i].file, &stripped_size) != 0u) {
      bins->items[i].stripped_size = stripped_size;
      bins->items[i].stripped_available = 1u;
    }
  }
}

//@optimizer-ignore-function coverage signal scan must compare each source byte against the searched word
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

//@optimizer-ignore-function coverage proxy must compare implementations, tests, and function references exhaustively
static void eri_mark_test_signals(const EriVfs* vfs, EriSourceFiles* sources, const EriFunctions* funcs) {
  size_t i;

  for (i = 0; i < sources->len; ++i) {
    char stem[128];
    size_t t;
    size_t f;

    if (sources->items[i].is_test != 0u || !eri_is_c_impl(sources->items[i].path)) {
      continue;
    }
    eri_basename_no_ext(sources->items[i].path, stem, sizeof(stem));
    for (t = 0; t < vfs->len && sources->items[i].has_test_signal == 0u; ++t) {
      const EriVfsFile* test_file = &vfs->files[t];

      if (eri_is_build_path(test_file->path) != 0u || eri_is_test_path(test_file->path) == 0u ||
          eri_is_binary_like(test_file) != 0u) {
        continue;
      }
      if (strstr(test_file->path, stem) != NULL || eri_file_contains_word(test_file, stem) != 0u) {
        sources->items[i].has_test_signal = 1u;
      }
    }
    for (f = 0; f < funcs->len && sources->items[i].has_test_signal == 0u; ++f) {
      if (strcmp(funcs->items[f].path, sources->items[i].path) != 0) {
        continue;
      }
      if (strlen(funcs->items[f].name) < 8u || strcmp(funcs->items[f].name, "main") == 0) {
        continue;
      }
      for (t = 0; t < vfs->len; ++t) {
        const EriVfsFile* test_file = &vfs->files[t];

        if (eri_is_build_path(test_file->path) == 0u && eri_is_test_path(test_file->path) != 0u &&
            eri_is_binary_like(test_file) == 0u && eri_file_contains_word(test_file, funcs->items[f].name) != 0u) {
          sources->items[i].has_test_signal = 1u;
          break;
        }
      }
    }
  }
}

static uint64_t eri_hash_bytes(const char* bytes, size_t len) {
  uint64_t hash = 1469598103934665603ull;
  size_t i;

  for (i = 0; i < len; ++i) {
    hash ^= (uint8_t)bytes[i];
    hash *= 1099511628211ull;
  }
  return hash;
}

static uint8_t eri_normalize_code_line(const uint8_t* bytes, size_t start, size_t end, char* out, size_t out_cap) {
  size_t i = start;
  size_t n = 0u;
  uint8_t in_space = 0u;

  while (i < end && isspace((unsigned char)bytes[i])) {
    ++i;
  }
  if (i >= end || bytes[i] == '#') {
    return 0;
  }
  if (i + 1u < end && bytes[i] == '/' && (bytes[i + 1u] == '/' || bytes[i + 1u] == '*')) {
    return 0;
  }
  for (; i < end && n + 1u < out_cap; ++i) {
    uint8_t c = bytes[i];

    if (i + 1u < end && bytes[i] == '/' && bytes[i + 1u] == '/') {
      break;
    }
    if (isspace((unsigned char)c)) {
      in_space = 1u;
      continue;
    }
    if (in_space != 0u && n > 0u && (isalnum((unsigned char)c) || c == '_')) {
      out[n++] = ' ';
    }
    out[n++] = (char)c;
    in_space = 0u;
  }
  while (n > 0u && isspace((unsigned char)out[n - 1u])) {
    --n;
  }
  out[n] = 0;
  if (n < 8u || strcmp(out, "{") == 0 || strcmp(out, "}") == 0 || strcmp(out, "};") == 0) {
    return 0;
  }
  return 1;
}

static uint8_t eri_add_dup_block_ref(EriDupBlockRefs* refs, uint64_t hash, const char* path, uint32_t line) {
  EriDupBlockRef* grown;

  if (refs->len + 1u > refs->cap) {
    grown = (EriDupBlockRef*)eri_grow(refs->items, sizeof(refs->items[0]), &refs->cap, refs->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    refs->items = grown;
  }
  refs->items[refs->len].hash = hash;
  refs->items[refs->len].path = eri_strdup(path);
  if (refs->items[refs->len].path == NULL) {
    return 0;
  }
  refs->items[refs->len].line = line;
  ++refs->len;
  return 1;
}

//@optimizer-ignore-function duplicate reference teardown must release each duplicated block path
static void eri_dup_refs_free(EriDupBlockRefs* refs) {
  size_t i;

  for (i = 0; i < refs->len; ++i) {
    free(refs->items[i].path);
  }
  free(refs->items);
}

//@optimizer-ignore-function duplicate collection must allocate stable path copies for each reported pair
static uint8_t eri_add_duplicate(EriDuplicates* duplicates, const EriDupBlockRef* a, const EriDupBlockRef* b) {
  EriDuplicate* grown;

  if (duplicates->len + 1u > duplicates->cap) {
    grown = (EriDuplicate*)eri_grow(duplicates->items, sizeof(duplicates->items[0]),
                                   &duplicates->cap, duplicates->len + 1u);
    if (grown == NULL) {
      return 0;
    }
    duplicates->items = grown;
  }
  duplicates->items[duplicates->len].path_a = eri_strdup(a->path);
  duplicates->items[duplicates->len].path_b = eri_strdup(b->path);
  if (duplicates->items[duplicates->len].path_a == NULL || duplicates->items[duplicates->len].path_b == NULL) {
    return 0;
  }
  duplicates->items[duplicates->len].line_a = a->line;
  duplicates->items[duplicates->len].is_test_a = eri_is_test_path(a->path);
  duplicates->items[duplicates->len].line_b = b->line;
  duplicates->items[duplicates->len].is_test_b = eri_is_test_path(b->path);
  duplicates->items[duplicates->len].hash = a->hash;
  ++duplicates->len;
  return 1;
}

//@optimizer-ignore-function duplicate teardown must release both path copies for each reported pair
static void eri_duplicates_free(EriDuplicates* duplicates) {
  size_t i;

  for (i = 0; i < duplicates->len; ++i) {
    free(duplicates->items[i].path_a);
    free(duplicates->items[i].path_b);
  }
  free(duplicates->items);
}

static uint8_t eri_append_dup_line(uint64_t** hashes, uint32_t** lines, uint32_t** segments,
                                   size_t* len, size_t* cap, uint64_t hash,
                                   uint32_t line, uint32_t segment) {
  if (*len + 1u > *cap) {
    size_t next = *cap == 0u ? 64u : *cap * 2u;
    uint64_t* grown_hashes = (uint64_t*)malloc(sizeof((*hashes)[0]) * next);
    uint32_t* grown_lines = (uint32_t*)malloc(sizeof((*lines)[0]) * next);
    uint32_t* grown_segments = (uint32_t*)malloc(sizeof((*segments)[0]) * next);

    if (grown_hashes == NULL || grown_lines == NULL || grown_segments == NULL) {
      free(grown_hashes);
      free(grown_lines);
      free(grown_segments);
      return 0u;
    }
    if (*len > 0u) {
      memcpy(grown_hashes, *hashes, sizeof((*hashes)[0]) * *len);
      memcpy(grown_lines, *lines, sizeof((*lines)[0]) * *len);
      memcpy(grown_segments, *segments, sizeof((*segments)[0]) * *len);
    }
    free(*hashes);
    free(*lines);
    free(*segments);
    *hashes = grown_hashes;
    *lines = grown_lines;
    *segments = grown_segments;
    *cap = next;
  }
  (*hashes)[*len] = hash;
  (*lines)[*len] = line;
  (*segments)[*len] = segment;
  ++*len;
  return 1u;
}

static uint8_t eri_dup_line_is_ignored(EriDupIgnoreState* state, const uint8_t* bytes, size_t start, size_t end) {
  char snippet[224];
  char searchable[224];
  size_t copy_len = end - start;

  if (copy_len >= sizeof(snippet)) {
    copy_len = sizeof(snippet) - 1u;
  }
  memcpy(snippet, bytes + start, copy_len);
  snippet[copy_len] = 0;
  eri_copy_without_literals(bytes, start, end, searchable, sizeof(searchable));
  if (state->function_ignore_active != 0u) {
    int brace_delta = eri_line_brace_delta(searchable);

    state->brace_depth += brace_delta;
    if (state->brace_depth < state->function_ignore_depth) {
      state->function_ignore_active = 0u;
    }
    ++state->segment;
    return 1u;
  }
  if (state->constant_ignore_active != 0u) {
    int brace_delta = eri_line_brace_delta(searchable);

    if ((state->constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) == 0u) ||
        (state->constant_ignore_macro == 0u && strchr(searchable, ';') != NULL)) {
      state->constant_ignore_active = 0u;
      state->constant_ignore_macro = 0u;
    }
    state->brace_depth += brace_delta;
    ++state->segment;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_function_directive(snippet) != 0u) {
    state->pending_function_ignore = 1u;
    ++state->segment;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_constant_directive(snippet) != 0u) {
    state->pending_constant_ignore = 1u;
    ++state->segment;
    return 1u;
  }
  if (eri_line_is_optimizer_ignore_directive(snippet) != 0u) {
    state->pending_optimizer_ignore = 1u;
    ++state->segment;
    return 1u;
  }
  if (state->pending_function_ignore != 0u) {
    char func_name[128];
    uint8_t is_static;

    if (eri_probable_function_def(searchable, func_name, sizeof(func_name), &is_static) != 0u ||
        strchr(searchable, '{') != NULL) {
      int brace_delta = eri_line_brace_delta(searchable);

      (void)is_static;
      state->pending_function_ignore = 0u;
      state->function_ignore_active = 1u;
      state->brace_depth += brace_delta;
      state->function_ignore_depth = state->brace_depth;
      if (brace_delta <= 0) {
        state->function_ignore_active = 0u;
      }
      ++state->segment;
      return 1u;
    }
    if (strchr(searchable, ';') != NULL || strchr(searchable, '}') != NULL) {
      state->pending_function_ignore = 0u;
    }
  }
  if (state->pending_constant_ignore != 0u) {
    const char* trim = eri_ltrim(searchable);

    state->pending_constant_ignore = 0u;
    state->constant_ignore_macro = trim[0] == '#' ? 1u : 0u;
    if ((state->constant_ignore_macro != 0u && eri_line_ends_with_backslash(searchable) != 0u) ||
        (state->constant_ignore_macro == 0u && strchr(searchable, ';') == NULL)) {
      state->constant_ignore_active = 1u;
    }
    state->brace_depth += eri_line_brace_delta(searchable);
    ++state->segment;
    return 1u;
  }
  if (state->pending_optimizer_ignore != 0u || eri_line_has_optimizer_ignore(snippet) != 0u ||
      eri_line_has_optimizer_ignore_constant(snippet) != 0u) {
    state->pending_optimizer_ignore = 0u;
    state->brace_depth += eri_line_brace_delta(searchable);
    ++state->segment;
    return 1u;
  }
  state->brace_depth += eri_line_brace_delta(searchable);
  return 0u;
}

//@optimizer-ignore-function duplicate analysis must normalize each line and build rolling block references
static uint8_t eri_collect_file_blocks(const EriVfsFile* file, EriDupBlockRefs* refs) {
  uint64_t* hashes = NULL;
  uint32_t* lines = NULL;
  uint32_t* segments = NULL;
  size_t len = 0u;
  size_t cap = 0u;
  size_t pos = 0u;
  uint32_t line_no = 1u;
  EriDupIgnoreState ignore_state;
  size_t i;

  memset(&ignore_state, 0, sizeof(ignore_state));
  ignore_state.segment = 1u;
  while (pos <= file->len) {
    size_t start = pos;
    size_t end;
    char normalized[160];

    while (pos < file->len && file->bytes[pos] != '\n') {
      ++pos;
    }
    end = pos;
    if (pos < file->len && file->bytes[pos] == '\n') {
      ++pos;
    } else if (start == file->len) {
      break;
    }
    if (end > start && file->bytes[end - 1u] == '\r') {
      --end;
    }
    if (eri_dup_line_is_ignored(&ignore_state, file->bytes, start, end) != 0u) {
      ++line_no;
      continue;
    }
    if (eri_normalize_code_line(file->bytes, start, end, normalized, sizeof(normalized)) != 0u) {
      if (eri_append_dup_line(&hashes, &lines, &segments, &len, &cap,
                              eri_hash_bytes(normalized, strlen(normalized)),
                              line_no, ignore_state.segment) == 0u) {
        free(hashes);
        free(lines);
        free(segments);
        return 0;
      }
    }
    ++line_no;
  }
  if (len >= ERI_DUP_BLOCK_LINES) {
    for (i = 0; i + ERI_DUP_BLOCK_LINES <= len; ++i) {
      uint64_t block_hash = 1469598103934665603ull;
      size_t j;

      if (segments[i] != segments[i + ERI_DUP_BLOCK_LINES - 1u]) {
        continue;
      }
      for (j = 0; j < ERI_DUP_BLOCK_LINES; ++j) {
        block_hash ^= hashes[i + j];
        block_hash *= 1099511628211ull;
      }
      if (eri_add_dup_block_ref(refs, block_hash, file->path, lines[i]) == 0u) {
        free(hashes);
        free(lines);
        return 0;
      }
    }
  }
  free(hashes);
  free(lines);
  free(segments);
  return 1;
}

static int eri_cmp_pkg(const void* a, const void* b) {
  const EriPackage* pa = (const EriPackage*)a;
  const EriPackage* pb = (const EriPackage*)b;
  if (pa->code_lines < pb->code_lines) {
    return 1;
  }
  if (pa->code_lines > pb->code_lines) {
    return -1;
  }
  return strcmp(pa->name, pb->name);
}

static int eri_cmp_bin(const void* a, const void* b) {
  const EriBinary* ba = (const EriBinary*)a;
  const EriBinary* bb = (const EriBinary*)b;
  if (ba->size < bb->size) {
    return 1;
  }
  if (ba->size > bb->size) {
    return -1;
  }
  return strcmp(ba->file->path, bb->file->path);
}

static int eri_cmp_coverage_pkg(const void* a, const void* b) {
  const EriCoveragePackage* pa = (const EriCoveragePackage*)a;
  const EriCoveragePackage* pb = (const EriCoveragePackage*)b;
  if (pa->source_code_lines < pb->source_code_lines) {
    return 1;
  }
  if (pa->source_code_lines > pb->source_code_lines) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static uint64_t eri_smell_package_score(const EriSmellPackage* pkg) {
  return pkg->large_files * 800u + pkg->long_functions * 120u + pkg->markers * 80u +
         pkg->gotos * 60u + pkg->math_primitives * 45u + pkg->magic_numbers * 12u +
         pkg->string_indexing * 20u + pkg->long_lines;
}

static uint64_t eri_cpu_package_score(const EriCpuPackage* pkg) {
  return pkg->nested_loops * 90u + pkg->allocations_in_loops * 80u + pkg->io_ops_in_loops * 80u +
         pkg->memory_ops_in_loops * 45u + pkg->divisions_in_loops * 35u + pkg->calls_in_loops * 30u;
}

static uint64_t eri_worldview_package_score(const EriWorldviewPackage* pkg) {
  return pkg->host_fs_runtime * 120u + pkg->path_identity * 90u + pkg->legacy_object_ids * 90u +
         pkg->raw_object_apis * 45u + pkg->wasm64_offsets * 20u;
}

static int eri_cmp_smell_pkg(const void* a, const void* b) {
  const EriSmellPackage* pa = (const EriSmellPackage*)a;
  const EriSmellPackage* pb = (const EriSmellPackage*)b;
  uint64_t sa = eri_smell_package_score(pa);
  uint64_t sb = eri_smell_package_score(pb);

  if (sa < sb) {
    return 1;
  }
  if (sa > sb) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static int eri_cmp_cpu_pkg(const void* a, const void* b) {
  const EriCpuPackage* pa = (const EriCpuPackage*)a;
  const EriCpuPackage* pb = (const EriCpuPackage*)b;
  uint64_t sa = eri_cpu_package_score(pa);
  uint64_t sb = eri_cpu_package_score(pb);

  if (sa < sb) {
    return 1;
  }
  if (sa > sb) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static int eri_cmp_worldview_pkg(const void* a, const void* b) {
  const EriWorldviewPackage* pa = (const EriWorldviewPackage*)a;
  const EriWorldviewPackage* pb = (const EriWorldviewPackage*)b;
  uint64_t sa = eri_worldview_package_score(pa);
  uint64_t sb = eri_worldview_package_score(pb);

  if (sa < sb) {
    return 1;
  }
  if (sa > sb) {
    return -1;
  }
  return strcmp(pa->package, pb->package);
}

static int eri_cmp_dup_ref(const void* a, const void* b) {
  const EriDupBlockRef* ra = (const EriDupBlockRef*)a;
  const EriDupBlockRef* rb = (const EriDupBlockRef*)b;
  int path_cmp;

  if (ra->hash < rb->hash) {
    return -1;
  }
  if (ra->hash > rb->hash) {
    return 1;
  }
  path_cmp = strcmp(ra->path, rb->path);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (ra->line < rb->line) {
    return -1;
  }
  if (ra->line > rb->line) {
    return 1;
  }
  return 0;
}

static uint32_t eri_duplicate_rank(const EriDuplicate* duplicate) {
  uint32_t test_count = (uint32_t)duplicate->is_test_a + (uint32_t)duplicate->is_test_b;
  if (test_count == 0u) {
    return 0u;
  }
  if (test_count == 1u) {
    return 1u;
  }
  return 2u;
}

static int eri_cmp_duplicate(const void* a, const void* b) {
  const EriDuplicate* da = (const EriDuplicate*)a;
  const EriDuplicate* db = (const EriDuplicate*)b;
  uint32_t rank_a = eri_duplicate_rank(da);
  uint32_t rank_b = eri_duplicate_rank(db);
  int path_cmp;

  if (rank_a < rank_b) {
    return -1;
  }
  if (rank_a > rank_b) {
    return 1;
  }
  path_cmp = strcmp(da->path_a, db->path_a);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (da->line_a < db->line_a) {
    return -1;
  }
  if (da->line_a > db->line_a) {
    return 1;
  }
  path_cmp = strcmp(da->path_b, db->path_b);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (da->line_b < db->line_b) {
    return -1;
  }
  if (da->line_b > db->line_b) {
    return 1;
  }
  return 0;
}

static uint8_t eri_lines_near(uint32_t a, uint32_t b) {
  return (uint8_t)(a <= b ? b - a <= ERI_DUP_BLOCK_LINES : a - b <= ERI_DUP_BLOCK_LINES);
}

static uint8_t eri_same_duplicate_region(const EriDuplicate* a, const EriDuplicate* b) {
  return (uint8_t)(eri_duplicate_rank(a) == eri_duplicate_rank(b) &&
                   strcmp(a->path_a, b->path_a) == 0 &&
                   strcmp(a->path_b, b->path_b) == 0 &&
                   eri_lines_near(a->line_a, b->line_a) != 0u &&
                   eri_lines_near(a->line_b, b->line_b) != 0u);
}

//@optimizer-ignore-function duplicate compaction must release adjacent duplicate path copies while preserving stable order
static void eri_compact_duplicates(EriDuplicates* duplicates) {
  size_t read_i;
  size_t write_i = 0u;

  for (read_i = 0u; read_i < duplicates->len; ++read_i) {
    if (write_i > 0u && eri_same_duplicate_region(&duplicates->items[write_i - 1u],
                                                  &duplicates->items[read_i]) != 0u) {
      free(duplicates->items[read_i].path_a);
      free(duplicates->items[read_i].path_b);
      continue;
    }
    if (write_i != read_i) {
      duplicates->items[write_i] = duplicates->items[read_i];
    }
    ++write_i;
  }
  duplicates->len = write_i;
}

static uint32_t eri_finding_rank(const EriFinding* finding) {
  if (strcmp(finding->kind, "large-file") == 0) {
    return 0u;
  }
  if (strcmp(finding->kind, "long-function") == 0) {
    return 1u;
  }
  if (strcmp(finding->kind, "marker") == 0) {
    return 2u;
  }
  if (strcmp(finding->kind, "ignore-misuse") == 0) {
    return 3u;
  }
  if (strcmp(finding->kind, "goto") == 0) {
    return 4u;
  }
  if (strcmp(finding->kind, "magic-number") == 0) {
    return 5u;
  }
  if (strcmp(finding->kind, "string-indexing") == 0) {
    return 6u;
  }
  if (strcmp(finding->kind, "math-primitive") == 0) {
    return 7u;
  }
  if (strncmp(finding->kind, "world-", 6u) == 0) {
    return 8u;
  }
  if (strncmp(finding->kind, "cpu-", 4u) == 0) {
    return 9u;
  }
  if (strcmp(finding->kind, "long-line") == 0) {
    return 10u;
  }
  return 11u;
}

static int eri_cmp_finding(const void* a, const void* b) {
  const EriFinding* fa = (const EriFinding*)a;
  const EriFinding* fb = (const EriFinding*)b;
  uint32_t ra = eri_finding_rank(fa);
  uint32_t rb = eri_finding_rank(fb);
  uint8_t nonprod_a = eri_is_nonprod_path(fa->path);
  uint8_t nonprod_b = eri_is_nonprod_path(fb->path);
  int path_cmp;

  if (ra < rb) {
    return -1;
  }
  if (ra > rb) {
    return 1;
  }
  if (nonprod_a < nonprod_b) {
    return -1;
  }
  if (nonprod_a > nonprod_b) {
    return 1;
  }
  path_cmp = strcmp(fa->path, fb->path);
  if (path_cmp != 0) {
    return path_cmp;
  }
  if (fa->line < fb->line) {
    return -1;
  }
  if (fa->line > fb->line) {
    return 1;
  }
  return 0;
}

static uint64_t eri_count_findings_kind(const EriFindings* findings, const char* kind) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (strcmp(findings->items[i].kind, kind) == 0) {
      ++count;
    }
  }
  return count;
}

static void eri_print_finding_kind_samples(const EriFindings* findings, const char* kind, size_t limit) {
  size_t i;
  size_t shown = 0u;

  for (i = 0u; i < findings->len && shown < limit; ++i) {
    if (strcmp(findings->items[i].kind, kind) != 0) {
      continue;
    }
    printf("    %s:%u %s\n", findings->items[i].path, findings->items[i].line, findings->items[i].text);
    ++shown;
  }
  if (shown == 0u) {
    printf("    none\n");
  }
}

static uint8_t eri_finding_is_cpu_cost(const EriFinding* finding) {
  return (uint8_t)(strncmp(finding->kind, "cpu-", 4u) == 0);
}

static uint8_t eri_finding_is_worldview_risk(const EriFinding* finding) {
  return (uint8_t)(strncmp(finding->kind, "world-", 6u) == 0);
}

static uint64_t eri_count_cpu_findings(const EriFindings* findings) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (eri_finding_is_cpu_cost(&findings->items[i]) != 0u) {
      ++count;
    }
  }
  return count;
}

static uint64_t eri_count_worldview_findings(const EriFindings* findings) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < findings->len; ++i) {
    if (eri_finding_is_worldview_risk(&findings->items[i]) != 0u) {
      ++count;
    }
  }
  return count;
}

static void eri_print_cpu_finding_samples(const EriFindings* findings, size_t limit) {
  size_t i;
  size_t shown = 0u;

  for (i = 0u; i < findings->len && shown < limit; ++i) {
    if (eri_finding_is_cpu_cost(&findings->items[i]) == 0u) {
      continue;
    }
    printf("    %s:%u [%s] %s\n", findings->items[i].path, findings->items[i].line,
           findings->items[i].kind, findings->items[i].text);
    ++shown;
  }
  if (shown == 0u) {
    printf("    none\n");
  }
}

static void eri_print_worldview_finding_samples(const EriFindings* findings, size_t limit) {
  size_t i;
  size_t shown = 0u;

  for (i = 0u; i < findings->len && shown < limit; ++i) {
    if (eri_finding_is_worldview_risk(&findings->items[i]) == 0u) {
      continue;
    }
    printf("    %s:%u [%s] %s\n", findings->items[i].path, findings->items[i].line,
           findings->items[i].kind, findings->items[i].text);
    ++shown;
  }
  if (shown == 0u) {
    printf("    none\n");
  }
}

static uint8_t eri_collect_smell_packages(const EriFindings* findings, EriSmellPackages* packages) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    EriSmellPackage* pkg = eri_smell_package_get(packages, findings->items[i].path);

    if (pkg == NULL) {
      return 0;
    }
    if (eri_is_nonprod_path(findings->items[i].path) != 0u) {
      ++pkg->nonprod_findings;
      continue;
    }
    if (strcmp(findings->items[i].kind, "large-file") == 0) {
      ++pkg->large_files;
    } else if (strcmp(findings->items[i].kind, "long-function") == 0) {
      ++pkg->long_functions;
    } else if (strcmp(findings->items[i].kind, "marker") == 0) {
      ++pkg->markers;
    } else if (strcmp(findings->items[i].kind, "ignore-misuse") == 0) {
      ++pkg->markers;
    } else if (strcmp(findings->items[i].kind, "goto") == 0) {
      ++pkg->gotos;
    } else if (strcmp(findings->items[i].kind, "magic-number") == 0) {
      ++pkg->magic_numbers;
    } else if (strcmp(findings->items[i].kind, "string-indexing") == 0) {
      ++pkg->string_indexing;
    } else if (strcmp(findings->items[i].kind, "math-primitive") == 0) {
      ++pkg->math_primitives;
    } else if (strcmp(findings->items[i].kind, "long-line") == 0) {
      ++pkg->long_lines;
    }
  }
  qsort(packages->items, packages->len, sizeof(packages->items[0]), eri_cmp_smell_pkg);
  return 1;
}

static uint8_t eri_collect_cpu_packages(const EriFindings* findings, EriCpuPackages* packages) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    EriCpuPackage* pkg;

    if (eri_finding_is_cpu_cost(&findings->items[i]) == 0u) {
      continue;
    }
    pkg = eri_cpu_package_get(packages, findings->items[i].path);
    if (pkg == NULL) {
      return 0;
    }
    if (eri_is_nonprod_path(findings->items[i].path) != 0u) {
      ++pkg->nonprod_findings;
      continue;
    }
    if (strcmp(findings->items[i].kind, "cpu-nested-loop") == 0) {
      ++pkg->nested_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-call-in-loop") == 0) {
      ++pkg->calls_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-div-in-loop") == 0) {
      ++pkg->divisions_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-memory-in-loop") == 0) {
      ++pkg->memory_ops_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-alloc-in-loop") == 0) {
      ++pkg->allocations_in_loops;
    } else if (strcmp(findings->items[i].kind, "cpu-io-in-loop") == 0) {
      ++pkg->io_ops_in_loops;
    }
  }
  qsort(packages->items, packages->len, sizeof(packages->items[0]), eri_cmp_cpu_pkg);
  return 1;
}

static uint8_t eri_collect_worldview_packages(const EriFindings* findings, EriWorldviewPackages* packages) {
  size_t i;

  for (i = 0; i < findings->len; ++i) {
    EriWorldviewPackage* pkg;

    if (eri_finding_is_worldview_risk(&findings->items[i]) == 0u) {
      continue;
    }
    pkg = eri_worldview_package_get(packages, findings->items[i].path);
    if (pkg == NULL) {
      return 0;
    }
    if (eri_is_runtime_path(findings->items[i].path) == 0u) {
      ++pkg->nonprod_findings;
      continue;
    }
    if (strcmp(findings->items[i].kind, "world-host-fs") == 0) {
      ++pkg->host_fs_runtime;
    } else if (strcmp(findings->items[i].kind, "world-path-identity") == 0) {
      ++pkg->path_identity;
    } else if (strcmp(findings->items[i].kind, "world-legacy-object-id") == 0) {
      ++pkg->legacy_object_ids;
    } else if (strcmp(findings->items[i].kind, "world-raw-object-api") == 0) {
      ++pkg->raw_object_apis;
    } else if (strcmp(findings->items[i].kind, "world-wasm64-offset") == 0) {
      ++pkg->wasm64_offsets;
    }
  }
  qsort(packages->items, packages->len, sizeof(packages->items[0]), eri_cmp_worldview_pkg);
  return 1;
}

//@optimizer-ignore-function duplicate collection must scan each source block reference and adjacent equal hash group
static uint8_t eri_collect_duplicates(const EriVfs* vfs, EriDuplicates* duplicates) {
  EriDupBlockRefs refs;
  size_t i;

  memset(&refs, 0, sizeof(refs));
  for (i = 0; i < vfs->len; ++i) {
    const EriVfsFile* file = &vfs->files[i];

    if (eri_is_build_path(file->path) == 0u && eri_is_c_impl(file->path) &&
        eri_is_generated_header(file->path, file->bytes, file->len) == 0u) {
      if (eri_collect_file_blocks(file, &refs) == 0u) {
        eri_dup_refs_free(&refs);
        return 0;
      }
    }
  }
  qsort(refs.items, refs.len, sizeof(refs.items[0]), eri_cmp_dup_ref);
  for (i = 1u; i < refs.len; ++i) {
    if (refs.items[i].hash == refs.items[i - 1u].hash &&
        (strcmp(refs.items[i].path, refs.items[i - 1u].path) != 0 ||
         refs.items[i].line > refs.items[i - 1u].line + ERI_DUP_BLOCK_LINES)) {
      if (eri_add_duplicate(duplicates, &refs.items[i - 1u], &refs.items[i]) == 0u) {
        eri_dup_refs_free(&refs);
        return 0;
      }
      while (i + 1u < refs.len && refs.items[i + 1u].hash == refs.items[i].hash) {
        ++i;
      }
    }
  }
  eri_dup_refs_free(&refs);
  qsort(duplicates->items, duplicates->len, sizeof(duplicates->items[0]), eri_cmp_duplicate);
  eri_compact_duplicates(duplicates);
  return 1;
}

static uint64_t eri_count_duplicate_rank(const EriDuplicates* duplicates, uint32_t rank) {
  size_t i;
  uint64_t count = 0u;

  for (i = 0; i < duplicates->len; ++i) {
    if (eri_duplicate_rank(&duplicates->items[i]) == rank) {
      ++count;
    }
  }
  return count;
}

static void eri_print_size(uint64_t bytes) {
  if (bytes >= 1024u * 1024u) {
    printf("%.2f MiB", (double)bytes / (1024.0 * 1024.0));
  } else if (bytes >= 1024u) {
    printf("%.1f KiB", (double)bytes / 1024.0);
  } else {
    printf("%llu B", (unsigned long long)bytes);
  }
}

static void eri_analyze_cleanup(EriPackages* packages, EriFunctions* funcs, EriFindings* findings,
                                EriBinaries* bins, EriSourceFiles* sources,
                                EriCoveragePackages* coverage_packages, EriSmellPackages* smell_packages,
                                EriCpuPackages* cpu_packages, EriWorldviewPackages* worldview_packages,
                                EriDuplicates* duplicates) {
  eri_sources_free(sources);
  eri_duplicates_free(duplicates);
  eri_functions_free(funcs);
  eri_findings_free(findings);
  free(packages->items);
  free(coverage_packages->items);
  free(smell_packages->items);
  free(cpu_packages->items);
  free(worldview_packages->items);
  free(bins->items);
}

//@optimizer-ignore-function repo analysis orchestrates per-file metric, function, and CPU scans over the VFS snapshot
static uint8_t eri_analyze(const EriVfs* vfs) {
  EriTotals totals;
  EriPackages packages;
  EriFunctions funcs;
  EriFindings findings;
  EriBinaries bins;
  EriSourceFiles sources;
  EriCoveragePackages coverage_packages;
  EriSmellPackages smell_packages;
  EriCpuPackages cpu_packages;
  EriWorldviewPackages worldview_packages;
  EriDuplicates duplicates;
  size_t i;

  memset(&totals, 0, sizeof(totals));
  memset(&packages, 0, sizeof(packages));
  memset(&funcs, 0, sizeof(funcs));
  memset(&findings, 0, sizeof(findings));
  memset(&bins, 0, sizeof(bins));
  memset(&sources, 0, sizeof(sources));
  memset(&coverage_packages, 0, sizeof(coverage_packages));
  memset(&smell_packages, 0, sizeof(smell_packages));
  memset(&cpu_packages, 0, sizeof(cpu_packages));
  memset(&worldview_packages, 0, sizeof(worldview_packages));
  memset(&duplicates, 0, sizeof(duplicates));

  for (i = 0; i < vfs->len; ++i) {
    const EriVfsFile* file = &vfs->files[i];
    EriTotals file_totals;
    EriPackage* package;

    if (eri_is_binary_like(file) != 0u) {
      eri_add_binary(&bins, file);
    }
    if (eri_is_build_path(file->path) != 0u || !eri_is_c_source(file->path) ||
        eri_is_generated_header(file->path, file->bytes, file->len) != 0u) {
      continue;
    }
    memset(&file_totals, 0, sizeof(file_totals));
    eri_scan_line_metrics(file->bytes, file->len, &file_totals, &findings, file->path);
    eri_scan_functions(file, &funcs, &findings);
    eri_scan_cpu_costs(file, &findings);
    if (eri_is_c_impl(file->path) && eri_is_example_path(file->path) == 0u &&
        eri_add_source_file(&sources, file->path, file_totals.code_lines, eri_is_test_path(file->path)) == 0u) {
      eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                          &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
      return 0;
    }
    if (file_totals.code_lines > ERI_LARGE_FILE_LINES) {
      char text[128];
      snprintf(text, sizeof(text), "file has %llu code lines", (unsigned long long)file_totals.code_lines);
      eri_add_finding(&findings, file->path, 1u, "large-file", text);
    }

    ++totals.files;
    totals.bytes += file->len;
    totals.total_lines += file_totals.total_lines;
    totals.code_lines += file_totals.code_lines;
    totals.comment_lines += file_totals.comment_lines;
    totals.blank_lines += file_totals.blank_lines;

    package = eri_package_get(&packages, file->path);
    if (package == NULL) {
      eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                          &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
      return 0;
    }
    ++package->files;
    package->bytes += file->len;
    package->code_lines += file_totals.code_lines;
  }

  eri_count_function_refs(vfs, &funcs);
  eri_mark_test_signals(vfs, &sources, &funcs);
  eri_measure_binary_release_sizes(&bins);
  if (eri_collect_duplicates(vfs, &duplicates) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  for (i = 0; i < sources.len; ++i) {
    char package_name[ERI_PACKAGE_MAX];
    EriCoveragePackage* coverage_package;

    eri_package_name(sources.items[i].path, package_name, sizeof(package_name));
    coverage_package = eri_coverage_package_get(&coverage_packages, package_name);
    if (coverage_package == NULL) {
      eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                          &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
      return 0;
    }
    if (sources.items[i].is_test != 0u) {
      ++coverage_package->test_files;
      coverage_package->test_code_lines += sources.items[i].code_lines;
    } else {
      ++coverage_package->source_files;
      coverage_package->source_code_lines += sources.items[i].code_lines;
      if (sources.items[i].has_test_signal != 0u) {
        ++coverage_package->tested_source_files;
      }
    }
  }
  qsort(packages.items, packages.len, sizeof(packages.items[0]), eri_cmp_pkg);
  qsort(coverage_packages.items, coverage_packages.len, sizeof(coverage_packages.items[0]), eri_cmp_coverage_pkg);
  qsort(bins.items, bins.len, sizeof(bins.items[0]), eri_cmp_bin);
  qsort(findings.items, findings.len, sizeof(findings.items[0]), eri_cmp_finding);
  if (eri_collect_smell_packages(&findings, &smell_packages) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  if (eri_collect_cpu_packages(&findings, &cpu_packages) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }
  if (eri_collect_worldview_packages(&findings, &worldview_packages) == 0u) {
    eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                        &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
    return 0;
  }

  printf("repo-inspect report\n");
  printf("===================\n\n");
  printf("C source snapshot\n");
  printf("  files:         %llu\n", (unsigned long long)totals.files);
  printf("  bytes:         ");
  eri_print_size(totals.bytes);
  printf("\n");
  printf("  total lines:   %llu\n", (unsigned long long)totals.total_lines);
  printf("  code lines:    %llu\n", (unsigned long long)totals.code_lines);
  printf("  comment lines: %llu\n", (unsigned long long)totals.comment_lines);
  printf("  blank lines:   %llu\n\n", (unsigned long long)totals.blank_lines);

  printf("Biggest packages by C code lines\n");
  for (i = 0; i < packages.len && i < ERI_TOP_LIMIT; ++i) {
    printf("  %-24s %6llu loc  %4llu files  ", packages.items[i].name,
           (unsigned long long)packages.items[i].code_lines,
           (unsigned long long)packages.items[i].files);
    eri_print_size(packages.items[i].bytes);
    printf("\n");
  }
  printf("\n");

  printf("Static test coverage proxy\n");
  printf("  heuristic: implementation .c files with same-stem tests or test references\n");
  for (i = 0; i < coverage_packages.len && i < ERI_TOP_LIMIT; ++i) {
    const EriCoveragePackage* pkg = &coverage_packages.items[i];
    uint64_t pct = pkg->source_files == 0u ? 100u : (pkg->tested_source_files * 100u) / pkg->source_files;

    printf("  %-24s %3llu%%  %3llu/%-3llu impl files signaled  C tests: %3llu files, %5llu loc\n",
           pkg->package, (unsigned long long)pct,
           (unsigned long long)pkg->tested_source_files,
           (unsigned long long)pkg->source_files,
           (unsigned long long)pkg->test_files,
           (unsigned long long)pkg->test_code_lines);
  }
  printf("\n");

  printf("Optimized stripped release sizes\n");
  printf("  original is on-disk size; stripped is measured from a temporary copy when strip is available\n");
  if (bins.len == 0u) {
    printf("  none found in VFS snapshot\n");
  } else {
    for (i = 0; i < bins.len && i < ERI_TOP_LIMIT; ++i) {
      printf("  %-56s original ", bins.items[i].file->path);
      eri_print_size(bins.items[i].size);
      printf("  stripped ");
      if (bins.items[i].stripped_available != 0u) {
        eri_print_size(bins.items[i].stripped_size);
      } else {
        printf("n/a");
      }
      printf("\n");
    }
  }
  printf("\n");

  printf("Potential duplication\n");
  printf("  heuristic: repeated %u-line normalized C blocks; adjacent windows are compacted;"
         " reasoned optimizer ignores are honored\n",
         ERI_DUP_BLOCK_LINES);
  if (duplicates.len == 0u) {
    printf("  none found\n");
  } else {
    uint64_t production_pairs = eri_count_duplicate_rank(&duplicates, 0u);
    uint64_t mixed_pairs = eri_count_duplicate_rank(&duplicates, 1u);
    uint64_t test_pairs = eri_count_duplicate_rank(&duplicates, 2u);

    printf("  candidates: %llu production, %llu mixed test/source, %llu test-only\n",
           (unsigned long long)production_pairs,
           (unsigned long long)mixed_pairs,
           (unsigned long long)test_pairs);
    for (i = 0; i < duplicates.len && i < ERI_TOP_LIMIT; ++i) {
      printf("  %s:%u resembles %s:%u\n",
             duplicates.items[i].path_a, duplicates.items[i].line_a,
             duplicates.items[i].path_b, duplicates.items[i].line_b);
    }
    if (duplicates.len > ERI_TOP_LIMIT) {
      printf("  ... %llu more candidate blocks\n", (unsigned long long)(duplicates.len - ERI_TOP_LIMIT));
    }
  }
  printf("\n");

  printf("Dead-code candidates\n");
  {
    size_t shown = 0u;
    for (i = 0; i < funcs.len && shown < ERI_TOP_LIMIT; ++i) {
      if (funcs.items[i].is_static != 0u && funcs.items[i].calls <= 1u) {
        printf("  %s:%u static %s appears unreferenced\n",
               funcs.items[i].path, funcs.items[i].line, funcs.items[i].name);
        ++shown;
      }
    }
    if (shown == 0u) {
      printf("  none from static-function heuristic\n");
    }
  }
  printf("\n");

  printf("Content-addressed VFS worldview risks\n");
  printf("  heuristic: runtime APIs should prefer VFS object hashes/lengths over host paths or mutable names\n");
  if (eri_count_worldview_findings(&findings) == 0u) {
    printf("  none from current heuristics\n");
  } else {
    printf("  summary: %llu host FS/process, %llu path identity, %llu legacy object ids, %llu raw object APIs, %llu WASM32-sized offset reviews\n",
           (unsigned long long)eri_count_findings_kind(&findings, "world-host-fs"),
           (unsigned long long)eri_count_findings_kind(&findings, "world-path-identity"),
           (unsigned long long)eri_count_findings_kind(&findings, "world-legacy-object-id"),
           (unsigned long long)eri_count_findings_kind(&findings, "world-raw-object-api"),
           (unsigned long long)eri_count_findings_kind(&findings, "world-wasm64-offset"));
    printf("  package hotspots:\n");
    for (i = 0; i < worldview_packages.len && i < ERI_TOP_LIMIT; ++i) {
      const EriWorldviewPackage* pkg = &worldview_packages.items[i];

      if (eri_worldview_package_score(pkg) == 0u) {
        continue;
      }
      printf("    %-24s score %5llu  host-fs %3llu  path-id %3llu  obj-id %3llu  raw-api %3llu  u64 %3llu  nonprod %4llu\n",
             pkg->package,
             (unsigned long long)eri_worldview_package_score(pkg),
             (unsigned long long)pkg->host_fs_runtime,
             (unsigned long long)pkg->path_identity,
             (unsigned long long)pkg->legacy_object_ids,
             (unsigned long long)pkg->raw_object_apis,
             (unsigned long long)pkg->wasm64_offsets,
             (unsigned long long)pkg->nonprod_findings);
    }
    printf("  focused worldview candidates:\n");
    eri_print_worldview_finding_samples(&findings, ERI_TOP_LIMIT);
  }
  printf("\n");

  printf("CPU cost signals\n");
  printf("  heuristic: loop-local review targets; use reasoned line/function/constant optimizer ignores for intentional hot paths\n");
  if (eri_count_cpu_findings(&findings) == 0u) {
    printf("  none from current heuristics\n");
  } else {
    printf("  summary: %llu nested loops, %llu calls in loops, %llu division/modulo in loops, %llu memory ops in loops, %llu allocations in loops, %llu I/O ops in loops\n",
           (unsigned long long)eri_count_findings_kind(&findings, "cpu-nested-loop"),
           (unsigned long long)eri_count_findings_kind(&findings, "cpu-call-in-loop"),
           (unsigned long long)eri_count_findings_kind(&findings, "cpu-div-in-loop"),
           (unsigned long long)eri_count_findings_kind(&findings, "cpu-memory-in-loop"),
           (unsigned long long)eri_count_findings_kind(&findings, "cpu-alloc-in-loop"),
           (unsigned long long)eri_count_findings_kind(&findings, "cpu-io-in-loop"));
    printf("  package hotspots:\n");
    for (i = 0; i < cpu_packages.len && i < ERI_TOP_LIMIT; ++i) {
      const EriCpuPackage* pkg = &cpu_packages.items[i];

      if (eri_cpu_package_score(pkg) == 0u) {
        continue;
      }
      printf("    %-24s score %5llu  nested %3llu  calls %4llu  div/mod %3llu  mem %3llu  alloc %3llu  io %3llu  nonprod %4llu\n",
             pkg->package,
             (unsigned long long)eri_cpu_package_score(pkg),
             (unsigned long long)pkg->nested_loops,
             (unsigned long long)pkg->calls_in_loops,
             (unsigned long long)pkg->divisions_in_loops,
             (unsigned long long)pkg->memory_ops_in_loops,
             (unsigned long long)pkg->allocations_in_loops,
             (unsigned long long)pkg->io_ops_in_loops,
             (unsigned long long)pkg->nonprod_findings);
    }
    printf("  focused CPU-cost candidates:\n");
    eri_print_cpu_finding_samples(&findings, ERI_TOP_LIMIT);
  }
  printf("\n");

  printf("Code smells and review targets\n");
  if (findings.len == 0u) {
    printf("  none from current heuristics\n");
  } else {
    printf("  summary: %llu large files, %llu long functions, %llu markers, %llu ignore misuse, %llu gotos, %llu magic numbers, %llu string-indexing, %llu math primitives, %llu long lines\n",
           (unsigned long long)eri_count_findings_kind(&findings, "large-file"),
           (unsigned long long)eri_count_findings_kind(&findings, "long-function"),
           (unsigned long long)eri_count_findings_kind(&findings, "marker"),
           (unsigned long long)eri_count_findings_kind(&findings, "ignore-misuse"),
           (unsigned long long)eri_count_findings_kind(&findings, "goto"),
           (unsigned long long)eri_count_findings_kind(&findings, "magic-number"),
           (unsigned long long)eri_count_findings_kind(&findings, "string-indexing"),
           (unsigned long long)eri_count_findings_kind(&findings, "math-primitive"),
           (unsigned long long)eri_count_findings_kind(&findings, "long-line"));
    printf("  package hotspots:\n");
    for (i = 0; i < smell_packages.len && i < ERI_TOP_LIMIT; ++i) {
      const EriSmellPackage* pkg = &smell_packages.items[i];

      if (eri_smell_package_score(pkg) == 0u) {
        continue;
      }
      printf("    %-24s score %5llu  large %2llu  funcs %2llu  markers %2llu  gotos %2llu  magic %4llu  str-index %3llu  math %3llu  long-lines %4llu  nonprod %4llu\n",
             pkg->package,
             (unsigned long long)eri_smell_package_score(pkg),
             (unsigned long long)pkg->large_files,
             (unsigned long long)pkg->long_functions,
             (unsigned long long)pkg->markers,
             (unsigned long long)pkg->gotos,
             (unsigned long long)pkg->magic_numbers,
             (unsigned long long)pkg->string_indexing,
             (unsigned long long)pkg->math_primitives,
             (unsigned long long)pkg->long_lines,
             (unsigned long long)pkg->nonprod_findings);
    }
    printf("  focused magic-number candidates:\n");
    eri_print_finding_kind_samples(&findings, "magic-number", ERI_TOP_LIMIT);
    printf("  focused string-indexing candidates:\n");
    eri_print_finding_kind_samples(&findings, "string-indexing", ERI_TOP_LIMIT);
    printf("  focused math primitive candidates:\n");
    eri_print_finding_kind_samples(&findings, "math-primitive", ERI_TOP_LIMIT);
    for (i = 0; i < findings.len && i < ERI_TOP_LIMIT * 2u; ++i) {
      if (eri_finding_is_cpu_cost(&findings.items[i]) != 0u ||
          eri_finding_is_worldview_risk(&findings.items[i]) != 0u) {
        continue;
      }
      printf("  %s:%u [%s] %s\n", findings.items[i].path, findings.items[i].line,
             findings.items[i].kind, findings.items[i].text);
    }
    if (findings.len > ERI_TOP_LIMIT * 2u) {
      printf("  ... %llu more findings\n", (unsigned long long)(findings.len - (ERI_TOP_LIMIT * 2u)));
    }
  }

  eri_analyze_cleanup(&packages, &funcs, &findings, &bins, &sources, &coverage_packages,
                      &smell_packages, &cpu_packages, &worldview_packages, &duplicates);
  return 1;
}

static void eri_usage(const char* argv0) {
  printf("usage: %s [repo-root]\n", argv0);
  printf("\n");
  printf("Builds a virtual file snapshot, then reports C LOC, package size,\n");
  printf("binary artifacts, test signals, duplicate blocks, dead-code candidates,\n");
  printf("CPU cost signals, and simple code smells.\n");
}

int main(int argc, char** argv) {
  EriVfs vfs;
  const char* root = ".";
  int ok;

  if (argc > 2 || (argc == 2 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0))) {
    eri_usage(argv[0]);
    return argc > 2 ? 1 : 0;
  }
  if (argc == 2) {
    root = argv[1];
  }

  memset(&vfs, 0, sizeof(vfs));
  if (eri_load_dir(&vfs, root, "") == 0u) {
    eri_vfs_free(&vfs);
    return 1;
  }
  ok = eri_analyze(&vfs) != 0u ? 0 : 1;
  eri_vfs_free(&vfs);
  return ok;
}
