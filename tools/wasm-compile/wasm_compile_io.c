#include "wasm_compile.h"

int erwc_read_file(const char* path, ErWcSource* source) {
  FILE* file;
  long size;

  if (path == NULL || source == NULL) {
    return 1;
  }
  memset(source, 0, sizeof(*source));
  source->path = path;
  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "wasm-compile: %s: open failed: %s\n", path, strerror(errno));
    return 1;
  }
  if (fseek(file, 0, SEEK_END) != 0 || (size = ftell(file)) < 0 ||
      fseek(file, 0, SEEK_SET) != 0) {
    fclose(file);
    return erwc_fail_path(path, "size failed");
  }
  source->bytes = (uint8_t*)malloc((size_t)size + 1u);
  if (source->bytes == NULL) {
    fclose(file);
    return erwc_fail_path(path, "allocation failed");
  }
  if (size > 0 && fread(source->bytes, 1u, (size_t)size, file) != (size_t)size) {
    free(source->bytes);
    fclose(file);
    return erwc_fail_path(path, "read failed");
  }
  fclose(file);
  source->bytes[size] = 0u;
  source->len = (size_t)size;
  return 0;
}

int erwc_write_file(const char* path, const ErWcBuffer* out) {
  FILE* file = fopen(path, "wb");

  if (file == NULL) {
    fprintf(stderr, "wasm-compile: %s: open failed: %s\n", path, strerror(errno));
    return 1;
  }
  if (out->len > 0u && fwrite(out->bytes, 1u, out->len, file) != out->len) {
    fclose(file);
    return erwc_fail_path(path, "write failed");
  }
  if (fclose(file) != 0) {
    return erwc_fail_path(path, "close failed");
  }
  return 0;
}

static int erwc_path_has_suffix(const char* path, const char* suffix) {
  size_t path_len;
  size_t suffix_len;

  if (path == NULL || suffix == NULL) {
    return 0;
  }
  path_len = strlen(path);
  suffix_len = strlen(suffix);
  if (path_len < suffix_len) {
    return 0;
  }
  return memcmp(path + path_len - suffix_len, suffix, suffix_len) == 0;
}

static ErWcCompileStatus erwc_source_kind_for_path(const char* path,
                                                   ErWcSourceKind* out_kind) {
  if (out_kind == NULL) {
    return ERWC_COMPILE_STATUS_BAD_ARGS;
  }
  if (erwc_path_has_suffix(path, ".c") != 0 ||
      erwc_path_has_suffix(path, ".erc") != 0) {
    *out_kind = ERWC_SOURCE_KIND_ERC;
    return ERWC_COMPILE_STATUS_OK;
  }
  if (erwc_path_has_suffix(path, ".wat") != 0) {
    *out_kind = ERWC_SOURCE_KIND_WAT;
    return ERWC_COMPILE_STATUS_OK;
  }
  return ERWC_COMPILE_STATUS_UNSUPPORTED_SOURCE_KIND;
}

int erwc_compile_path(const char* input_path, const char* output_path) {
  ErWcSource source;
  ErWcBuffer out;
  ErWcCompileStatus status;
  ErWcSourceKind source_kind;

  if (input_path == NULL || output_path == NULL) {
    return 1;
  }
  if (erwc_read_file(input_path, &source) != 0) {
    return 1;
  }
  status = erwc_source_kind_for_path(input_path, &source_kind);
  if (status == ERWC_COMPILE_STATUS_OK) {
    status = erwc_compile_source(&source, source_kind, &out);
  }
  free(source.bytes);
  if (status != ERWC_COMPILE_STATUS_OK) {
    fprintf(stderr, "wasm-compile: %s: %s: %s\n",
            input_path,
            erwc_compile_status_code(status),
            erwc_compile_status_message(status));
    return 1;
  }
  return erwc_write_file(output_path, &out);
}
