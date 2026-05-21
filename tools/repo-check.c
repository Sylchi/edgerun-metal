#define _POSIX_C_SOURCE 200809L

#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

enum {
  ERC_INDEX_HEADER_BYTES = 12,
  ERC_INDEX_ENTRY_BASE_BYTES = 62,
  ERC_INDEX_MODE_OFFSET = 24,
  ERC_INDEX_FLAGS_OFFSET = 60,
  ERC_INDEX_FLAGS_BYTES = 2,
  ERC_INDEX_NAME_LEN_MASK = 0x0fff,
  ERC_INDEX_EXTENDED_NAME_LEN = 0x0fff,
  ERC_INDEX_ENTRY_ALIGNMENT = 8,
  ERC_GIT_DIRC_MAGIC_BYTES = 4,
  ERC_BE32_BYTE_SHIFT_1 = 8,
  ERC_BE32_BYTE_SHIFT_2 = 16,
  ERC_BE32_BYTE_SHIFT_3 = 24,
  ERC_BE32_BYTE_INDEX_0 = 0,
  ERC_BE32_BYTE_INDEX_1 = 1,
  ERC_BE32_BYTE_INDEX_2 = 2,
  ERC_BE32_BYTE_INDEX_3 = 3,
  ERC_GITLINK_MODE = 0160000,
  ERC_EXTERNAL_PATTERN_COUNT = 11
};

static const char ERC_BUILD_ARTIFACT_DIR[] = ".build/";
static const char ERC_VARFONT_BUILD_ARTIFACT_DIR[] = "edgerun-ui-core/varfont/build/";
static const char ERC_ROOT_README[] = "README.md";
static const char ERC_AGENT_POLICY[] = "AGENTS.md";
static const char ERC_MARKDOWN_SUFFIX[] = ".md";
static const char ERC_THIRD_PARTY_DIR[] = "third_party/";
static const char ERC_ALLOWED_BLAKE3_DIR[] = "third_party/blake3/";
static const char ERC_VENDOR_UI_DIR[] = "ui/shadcn-ui/";
static const char ERC_FIRMWARE_DIR[] = "firmware/";
static const char ERC_API_MANIFEST[] = "api/public-headers.manifest";

static const char* const ERC_EXTERNAL_PATTERNS[ERC_EXTERNAL_PATTERN_COUNT] = {
  "curl" " -",
  "wget" " ",
  "git" " clone ",
  "npm" " install",
  "pnpm" " install",
  "cargo" " install",
  "pip" " install",
  "#include <openssl" "/",
  "-l" "ssl",
  "-l" "crypto",
  "Open" "SSL"
};

static int erc_fail(const char* message) {
  fprintf(stderr, "repo-check: %s\n", message);
  return 1;
}

static uint32_t erc_be32(const unsigned char* p) {
  return ((uint32_t)p[ERC_BE32_BYTE_INDEX_0] << ERC_BE32_BYTE_SHIFT_3) |
         ((uint32_t)p[ERC_BE32_BYTE_INDEX_1] << ERC_BE32_BYTE_SHIFT_2) |
         ((uint32_t)p[ERC_BE32_BYTE_INDEX_2] << ERC_BE32_BYTE_SHIFT_1) |
         (uint32_t)p[ERC_BE32_BYTE_INDEX_3];
}

//@optimizer-ignore-function repository path validation must scan every path component
static int erc_has_component(const char* path, const char* component) {
  size_t component_len = strlen(component);
  const char* p = path;

  while (*p != '\0') {
    const char* start = p;
    size_t len;

    while (*p != '\0' && *p != '/') {
      ++p;
    }
    len = (size_t)(p - start);
    if (len == component_len && strncmp(start, component, component_len) == 0) {
      return 1;
    }
    if (*p == '/') {
      ++p;
    }
  }
  return 0;
}

static int erc_is_tracked_build_artifact(const char* path) {
  return strncmp(path, ERC_BUILD_ARTIFACT_DIR, sizeof(ERC_BUILD_ARTIFACT_DIR) - 1u) == 0 ||
         strncmp(path, ERC_VARFONT_BUILD_ARTIFACT_DIR, sizeof(ERC_VARFONT_BUILD_ARTIFACT_DIR) - 1u) == 0;
}

static int erc_has_readme_name(const char* path) {
  const char* slash = strrchr(path, '/');
  const char* name = slash == NULL ? path : slash + 1;

  return strcmp(name, ERC_ROOT_README) == 0;
}

static int erc_is_top_level_extra_markdown(const char* path) {
  size_t path_len;
  size_t suffix_len;

  if (strchr(path, '/') != NULL ||
      strcmp(path, ERC_ROOT_README) == 0 ||
      strcmp(path, ERC_AGENT_POLICY) == 0) {
    return 0;
  }
  path_len = strlen(path);
  suffix_len = sizeof(ERC_MARKDOWN_SUFFIX) - 1u;
  if (path_len < suffix_len) {
    return 0;
  }
  return strcmp(path + path_len - suffix_len, ERC_MARKDOWN_SUFFIX) == 0;
}

static int erc_is_first_party_readme(const char* path) {
  if (strcmp(path, ERC_ROOT_README) == 0) {
    return 0;
  }
  if (erc_has_readme_name(path) == 0) {
    return 0;
  }
  if (strncmp(path, ERC_THIRD_PARTY_DIR, sizeof(ERC_THIRD_PARTY_DIR) - 1u) == 0) {
    return 0;
  }
  if (strncmp(path, ERC_VENDOR_UI_DIR, sizeof(ERC_VENDOR_UI_DIR) - 1u) == 0) {
    return 0;
  }
  return 1;
}

static int erc_is_allowed_third_party_path(const char* path) {
  return strncmp(path, ERC_ALLOWED_BLAKE3_DIR,
                 sizeof(ERC_ALLOWED_BLAKE3_DIR) - 1u) == 0;
}

static int erc_is_unapproved_external_dependency_path(const char* path) {
  if (strncmp(path, ERC_THIRD_PARTY_DIR, sizeof(ERC_THIRD_PARTY_DIR) - 1u) == 0 &&
      erc_is_allowed_third_party_path(path) == 0) {
    return 1;
  }
  return 0;
}

static int erc_join(char* out, size_t out_len, const char* a, const char* b);
static unsigned char* erc_read_file(const char* path, size_t* out_len);

static int erc_has_suffix(const char* path, const char* suffix) {
  size_t path_len = strlen(path);
  size_t suffix_len = strlen(suffix);

  if (path_len < suffix_len) {
    return 0;
  }
  return strcmp(path + path_len - suffix_len, suffix) == 0;
}

static int erc_is_public_header_path(const char* path) {
  if (erc_has_suffix(path, ".h") == 0) {
    return 0;
  }
  if (strncmp(path, "include/", strlen("include/")) == 0 ||
      strncmp(path, "edgerun-ui-core/include/", strlen("edgerun-ui-core/include/")) == 0 ||
      strncmp(path, "edgerun-ui-core/varfont/include/", strlen("edgerun-ui-core/varfont/include/")) == 0 ||
      strncmp(path, "edgerun-crypto/include/", strlen("edgerun-crypto/include/")) == 0 ||
      strncmp(path, "storage/include/", strlen("storage/include/")) == 0 ||
      strncmp(path, "devices/", strlen("devices/")) == 0) {
    return 1;
  }
  if (strncmp(path, "edgerun-metal/core/", strlen("edgerun-metal/core/")) == 0 &&
      strchr(path + strlen("edgerun-metal/core/"), '/') == NULL) {
    return 1;
  }
  return 0;
}

static int erc_api_manifest_next(const unsigned char* bytes,
                                 size_t len,
                                 size_t* cursor,
                                 char* out,
                                 size_t out_len,
                                 int* out_has_line) {
  size_t start;
  size_t line_len;

  if (bytes == NULL || cursor == NULL || out == NULL || out_len == 0u || out_has_line == NULL) {
    return erc_fail("invalid API manifest state");
  }
  *out_has_line = 0;
  if (*cursor >= len) {
    return 0;
  }
  start = *cursor;
  while (*cursor < len && bytes[*cursor] != '\n') {
    if (bytes[*cursor] == '\r') {
      return erc_fail("API manifest contains carriage return");
    }
    ++*cursor;
  }
  line_len = *cursor - start;
  if (*cursor < len && bytes[*cursor] == '\n') {
    ++*cursor;
  }
  if (line_len == 0u || line_len >= out_len) {
    return erc_fail("API manifest contains invalid line");
  }
  memcpy(out, bytes + start, line_len);
  out[line_len] = '\0';
  *out_has_line = 1;
  return 0;
}

static int erc_is_external_dependency_audit_path(const char* path) {
  if (strncmp(path, ERC_THIRD_PARTY_DIR, sizeof(ERC_THIRD_PARTY_DIR) - 1u) == 0) {
    return 0;
  }
  if (strncmp(path, ERC_VENDOR_UI_DIR, sizeof(ERC_VENDOR_UI_DIR) - 1u) == 0) {
    return 0;
  }
  if (strncmp(path, ERC_FIRMWARE_DIR, sizeof(ERC_FIRMWARE_DIR) - 1u) == 0) {
    return 0;
  }
  return 1;
}

static int erc_bytes_contains(const unsigned char* bytes, size_t len, const char* pattern) {
  size_t pattern_len = strlen(pattern);
  size_t i;

  if (pattern_len == 0u || len < pattern_len) {
    return 0;
  }
  for (i = 0u; i <= len - pattern_len; ++i) {
    if (memcmp(bytes + i, pattern, pattern_len) == 0) {
      return 1;
    }
  }
  return 0;
}

static int erc_scan_external_dependencies(const char* root, const char* path) {
  char full_path[4096];
  unsigned char* bytes;
  size_t len;
  size_t i;

  if (erc_is_external_dependency_audit_path(path) == 0) {
    return 0;
  }
  if (!erc_join(full_path, sizeof(full_path), root, path)) {
    return erc_fail("path too long");
  }
  bytes = erc_read_file(full_path, &len);
  if (bytes == NULL) {
    return erc_fail("unable to read tracked file for external dependency audit");
  }
  for (i = 0u; i < ERC_EXTERNAL_PATTERN_COUNT; ++i) {
    if (erc_bytes_contains(bytes, len, ERC_EXTERNAL_PATTERNS[i]) != 0) {
      free(bytes);
      return erc_fail("first-party files must not introduce external dependency fetches or forbidden TLS libraries");
    }
  }
  free(bytes);
  return 0;
}

static int erc_join(char* out, size_t out_len, const char* a, const char* b) {
  int n;

  n = snprintf(out, out_len, "%s/%s", a, b);
  return n > 0 && (size_t)n < out_len;
}

//@optimizer-ignore-function nested git check must recursively scan repository directories
static int erc_scan_nested_git(const char* root, const char* rel) {
  char path[4096];
  DIR* dir;
  struct dirent* entry;

  if (rel[0] == '\0') {
    if (snprintf(path, sizeof(path), "%s", root) >= (int)sizeof(path)) {
      return erc_fail("path too long");
    }
  } else if (!erc_join(path, sizeof(path), root, rel)) {
    return erc_fail("path too long");
  }

  dir = opendir(path);
  if (dir == NULL) {
    return erc_fail("unable to scan repository");
  }

  while ((entry = readdir(dir)) != NULL) {
    char child_rel[4096];
    char child_path[4096];
    struct stat st;

    if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
      continue;
    }
    if (rel[0] == '\0' && strcmp(entry->d_name, ".git") == 0) {
      continue;
    }
    if (strcmp(entry->d_name, ".git") == 0 || strcmp(entry->d_name, ".gitmodules") == 0) {
      closedir(dir);
      return erc_fail("nested Git metadata is not allowed");
    }

    if (rel[0] == '\0') {
      if (snprintf(child_rel, sizeof(child_rel), "%s", entry->d_name) >= (int)sizeof(child_rel)) {
        closedir(dir);
        return erc_fail("path too long");
      }
    } else if (!erc_join(child_rel, sizeof(child_rel), rel, entry->d_name)) {
      closedir(dir);
      return erc_fail("path too long");
    }
    if (!erc_join(child_path, sizeof(child_path), root, child_rel)) {
      closedir(dir);
      return erc_fail("path too long");
    }
    if (lstat(child_path, &st) != 0) {
      closedir(dir);
      return erc_fail("unable to inspect repository entry");
    }
    if (S_ISDIR(st.st_mode) && erc_has_component(child_rel, ".build") == 0 &&
        erc_has_component(child_rel, "build") == 0) {
      int rc = erc_scan_nested_git(root, child_rel);
      if (rc != 0) {
        closedir(dir);
        return rc;
      }
    }
  }
  closedir(dir);
  return 0;
}

static unsigned char* erc_read_file(const char* path, size_t* out_len) {
  FILE* file;
  long len;
  unsigned char* bytes;

  file = fopen(path, "rb");
  if (file == NULL) {
    return NULL;
  }
  if (fseek(file, 0, SEEK_END) != 0) {
    fclose(file);
    return NULL;
  }
  len = ftell(file);
  if (len < 0 || fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return NULL;
  }
  bytes = (unsigned char*)malloc((size_t)len == 0u ? 1u : (size_t)len);
  if (bytes == NULL) {
    fclose(file);
    return NULL;
  }
  if ((size_t)len > 0u && fread(bytes, 1u, (size_t)len, file) != (size_t)len) {
    free(bytes);
    fclose(file);
    return NULL;
  }
  fclose(file);
  *out_len = (size_t)len;
  return bytes;
}

//@optimizer-ignore-function git index check must parse each tracked entry and fail immediately on violations
static int erc_scan_index(const char* root) {
  char index_path[4096];
  char manifest_path[4096];
  char manifest_entry[4096];
  unsigned char* index_bytes;
  unsigned char* manifest_bytes;
  size_t index_len;
  size_t manifest_len;
  size_t manifest_cursor = 0u;
  uint32_t entries;
  uint32_t i;
  size_t offset = ERC_INDEX_HEADER_BYTES;
  int has_manifest_entry = 0;

  if (!erc_join(index_path, sizeof(index_path), root, ".git/index")) {
    return erc_fail("path too long");
  }
  if (!erc_join(manifest_path, sizeof(manifest_path), root, ERC_API_MANIFEST)) {
    return erc_fail("path too long");
  }
  index_bytes = erc_read_file(index_path, &index_len);
  if (index_bytes == NULL) {
    return 0;
  }
  manifest_bytes = erc_read_file(manifest_path, &manifest_len);
  if (manifest_bytes == NULL) {
    free(index_bytes);
    return erc_fail("API manifest is missing");
  }
  if (index_len < ERC_INDEX_HEADER_BYTES || memcmp(index_bytes, "DIRC", ERC_GIT_DIRC_MAGIC_BYTES) != 0) {
    free(index_bytes);
    free(manifest_bytes);
    return erc_fail("Git index is not readable");
  }
  entries = erc_be32(index_bytes + 8u);
  for (i = 0u; i < entries; ++i) {
    uint32_t mode;
    uint16_t flags;
    size_t name_len;
    size_t entry_len;
    const char* name;

    if (offset + ERC_INDEX_ENTRY_BASE_BYTES > index_len) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("Git index entry is truncated");
    }
    mode = erc_be32(index_bytes + offset + ERC_INDEX_MODE_OFFSET);
    flags = (uint16_t)(((uint16_t)index_bytes[offset + ERC_INDEX_FLAGS_OFFSET] << ERC_BE32_BYTE_SHIFT_1) |
                       (uint16_t)index_bytes[offset + ERC_INDEX_FLAGS_OFFSET + ERC_INDEX_FLAGS_BYTES - 1u]);
    name = (const char*)(index_bytes + offset + ERC_INDEX_ENTRY_BASE_BYTES);
    name_len = (size_t)(flags & ERC_INDEX_NAME_LEN_MASK);
    if (name_len == ERC_INDEX_EXTENDED_NAME_LEN) {
      const unsigned char* end = memchr(name, '\0', index_len - offset - ERC_INDEX_ENTRY_BASE_BYTES);
      if (end == NULL) {
        free(index_bytes);
        free(manifest_bytes);
        return erc_fail("Git index entry path is truncated");
      }
      name_len = (size_t)(end - (const unsigned char*)name);
    }
    if (offset + ERC_INDEX_ENTRY_BASE_BYTES + name_len >= index_len) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("Git index entry path is truncated");
    }
    if (mode == ERC_GITLINK_MODE) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("Git submodule entries are not allowed");
    }
    if (erc_is_tracked_build_artifact(name) != 0) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("generated build artifacts must not be tracked");
    }
    if (erc_is_first_party_readme(name) != 0) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("first-party documentation must use the root README.md, not nested README.md files");
    }
    if (erc_is_top_level_extra_markdown(name) != 0) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("first-party documentation must stay in README.md; top-level markdown docs are not allowed");
    }
    if (erc_is_unapproved_external_dependency_path(name) != 0) {
      free(index_bytes);
      free(manifest_bytes);
      return erc_fail("unapproved external dependency path is not allowed");
    }
    if (erc_is_public_header_path(name) != 0) {
      if (erc_api_manifest_next(manifest_bytes, manifest_len, &manifest_cursor,
                                manifest_entry, sizeof(manifest_entry),
                                &has_manifest_entry) != 0) {
        free(index_bytes);
        free(manifest_bytes);
        return 1;
      }
      if (has_manifest_entry == 0 || strcmp(name, manifest_entry) != 0) {
        free(index_bytes);
        free(manifest_bytes);
        return erc_fail("public API header manifest is stale");
      }
    }
    if (erc_scan_external_dependencies(root, name) != 0) {
      free(index_bytes);
      free(manifest_bytes);
      return 1;
    }
    entry_len = ERC_INDEX_ENTRY_BASE_BYTES + name_len + 1u;
    entry_len = (entry_len + (ERC_INDEX_ENTRY_ALIGNMENT - 1u)) & ~(ERC_INDEX_ENTRY_ALIGNMENT - 1u);
    offset += entry_len;
  }
  if (erc_api_manifest_next(manifest_bytes, manifest_len, &manifest_cursor,
                            manifest_entry, sizeof(manifest_entry),
                            &has_manifest_entry) != 0) {
    free(index_bytes);
    free(manifest_bytes);
    return 1;
  }
  if (has_manifest_entry != 0) {
    free(index_bytes);
    free(manifest_bytes);
    return erc_fail("public API header manifest contains untracked header");
  }
  free(index_bytes);
  free(manifest_bytes);
  return 0;
}

int main(int argc, char** argv) {
  const char* root = argc > 1 ? argv[1] : ".";
  int rc;

  if (argc > 2) {
    return erc_fail("usage: repo-check [repo-root]");
  }
  rc = erc_scan_nested_git(root, "");
  if (rc != 0) {
    return rc;
  }
  return erc_scan_index(root);
}
