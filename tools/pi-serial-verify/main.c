#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <string.h>

/*
 * Purpose:
 *   Validate captured Raspberry Pi serial boot logs against staged manifests.
 * Intention:
 *   Turn first-board bring-up from a visual guess into an explicit pass/fail
 *   check driven by the repo-owned boot artifact contract.
 */

enum {
  ERPSV_ARGC = 3,
  ERPSV_ARG_MANIFEST = 1,
  ERPSV_ARG_SERIAL_LOG = 2,
  ERPSV_FILE_CAP = 1048576,
  ERPSV_LINE_CAP = 4096
};

static const char ERPSV_EXPECT_PREFIX[] = "serial_expect=";

static unsigned char g_erpsv_manifest[ERPSV_FILE_CAP];
static unsigned char g_erpsv_serial_log[ERPSV_FILE_CAP];

static int erpsv_fail(const char* message) {
  fprintf(stderr, "pi-serial-verify: %s\n", message);
  return 1;
}

static int erpsv_read_file(const char* path,
                           unsigned char* buffer,
                           size_t cap,
                           size_t* out_len) {
  FILE* file;
  size_t total = 0u;
  size_t read_len;

  if (path == NULL || buffer == NULL || out_len == NULL || cap == 0u) {
    return erpsv_fail("invalid file read");
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "pi-serial-verify: open failed for %s\n", path);
    return 1;
  }
  while ((read_len = fread(buffer + total, 1u, cap - total, file)) > 0u) {
    total += read_len;
    if (total == cap) {
      if (fgetc(file) != EOF) {
        fclose(file);
        return erpsv_fail("file too large");
      }
      break;
    }
  }
  if (ferror(file) != 0) {
    fclose(file);
    return erpsv_fail("file read failed");
  }
  if (fclose(file) != 0) {
    return erpsv_fail("file close failed");
  }
  *out_len = total;
  return 0;
}

static int erpsv_next_line(const unsigned char* text,
                           size_t text_len,
                           size_t* cursor,
                           const unsigned char** out_line,
                           size_t* out_line_len) {
  size_t start;
  size_t end;

  if (text == NULL || cursor == NULL || out_line == NULL ||
      out_line_len == NULL) {
    return 0;
  }
  if (*cursor >= text_len) {
    return 0;
  }
  start = *cursor;
  end = start;
  while (end < text_len && text[end] != (unsigned char)'\n') {
    ++end;
  }
  *cursor = end;
  if (*cursor < text_len && text[*cursor] == (unsigned char)'\n') {
    ++*cursor;
  }
  if (end > start && text[end - 1u] == (unsigned char)'\r') {
    --end;
  }
  *out_line = text + start;
  *out_line_len = end - start;
  return 1;
}

static int erpsv_line_has_prefix(const unsigned char* line,
                                 size_t line_len,
                                 const char* prefix) {
  size_t prefix_len;

  if (line == NULL || prefix == NULL) {
    return 0;
  }
  prefix_len = strlen(prefix);
  if (line_len < prefix_len) {
    return 0;
  }
  return memcmp(line, prefix, prefix_len) == 0;
}

static int erpsv_find_log_line(const unsigned char* log,
                               size_t log_len,
                               size_t* cursor,
                               const unsigned char* expected,
                               size_t expected_len) {
  const unsigned char* line;
  size_t line_len;
  size_t scan;

  if (log == NULL || cursor == NULL || expected == NULL ||
      expected_len == 0u || expected_len > ERPSV_LINE_CAP) {
    return 0;
  }
  scan = *cursor;
  while (erpsv_next_line(log, log_len, &scan, &line, &line_len) != 0) {
    if (line_len == expected_len &&
        memcmp(line, expected, expected_len) == 0) {
      *cursor = scan;
      return 1;
    }
  }
  return 0;
}

static int erpsv_verify(const unsigned char* manifest,
                        size_t manifest_len,
                        const unsigned char* log,
                        size_t log_len) {
  const unsigned char* line;
  const unsigned char* expected;
  size_t line_len;
  size_t manifest_cursor = 0u;
  size_t log_cursor = 0u;
  size_t expected_len;
  size_t prefix_len = strlen(ERPSV_EXPECT_PREFIX);
  size_t expectation_count = 0u;

  while (erpsv_next_line(manifest, manifest_len, &manifest_cursor, &line,
                         &line_len) != 0) {
    if (erpsv_line_has_prefix(line, line_len, ERPSV_EXPECT_PREFIX) == 0) {
      continue;
    }
    expected = line + prefix_len;
    expected_len = line_len - prefix_len;
    if (expected_len == 0u || expected_len > ERPSV_LINE_CAP) {
      return erpsv_fail("invalid serial expectation");
    }
    if (erpsv_find_log_line(log, log_len, &log_cursor, expected,
                            expected_len) == 0) {
      fprintf(stderr, "pi-serial-verify: missing serial expectation: %.*s\n",
              (int)expected_len, (const char*)expected);
      return 1;
    }
    ++expectation_count;
  }
  if (expectation_count == 0u) {
    return erpsv_fail("manifest has no serial expectations");
  }
  printf("pi-serial-verify: %zu serial expectations matched\n",
         expectation_count);
  return 0;
}

int main(int argc, char** argv) {
  size_t manifest_len;
  size_t serial_log_len;

  if (argc != ERPSV_ARGC) {
    fprintf(stderr,
            "usage: pi-serial-verify <manifest> <serial-log>\n");
    return 2;
  }
  if (erpsv_read_file(argv[ERPSV_ARG_MANIFEST],
                      g_erpsv_manifest,
                      sizeof(g_erpsv_manifest),
                      &manifest_len) != 0 ||
      erpsv_read_file(argv[ERPSV_ARG_SERIAL_LOG],
                      g_erpsv_serial_log,
                      sizeof(g_erpsv_serial_log),
                      &serial_log_len) != 0) {
    return 1;
  }
  return erpsv_verify(g_erpsv_manifest, manifest_len, g_erpsv_serial_log,
                      serial_log_len);
}
