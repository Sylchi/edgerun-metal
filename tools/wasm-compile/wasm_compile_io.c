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

int erwc_compile_path(const char* input_path, const char* output_path) {
  ErWcSource source;
  ErWcParse parse;
  ErWcModule module;
  ErWcBuffer out;
  int root;

  memset(&parse, 0, sizeof(parse));
  if (erwc_read_file(input_path, &source) != 0) {
    return 1;
  }
  if (erwc_tokenize(&source, &parse) != 0) {
    fprintf(stderr, "wasm-compile: %s: tokenization failed\n", input_path);
    free(source.bytes);
    return 1;
  }
  root = erwc_parse_tree(&parse);
  if (root < 0 || erwc_build_module(&parse, root, &module) != 0) {
    fprintf(stderr, "wasm-compile: %s: unsupported WAT subset\n", input_path);
    free(source.bytes);
    return 1;
  }
  if (erwc_validate_contract(&module) != 0) {
    fprintf(stderr, "wasm-compile: %s: module contract rejected\n", input_path);
    free(source.bytes);
    return 1;
  }
  if (erwc_emit_wasm(&module, &out) != 0) {
    fprintf(stderr, "wasm-compile: %s: emit failed\n", input_path);
    free(source.bytes);
    return 1;
  }
  free(source.bytes);
  return erwc_write_file(output_path, &out);
}
