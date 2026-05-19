#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
  ER_EMBED_BYTES_PER_WASM_LINE = 12,
  ER_EMBED_BYTES_PER_BINARY_LINE = 16,
  ER_EMBED_BINARY_ARGC = 7,
  ER_EMBED_WASM_ARGC = 8,
  ER_EMBED_MODE_ARG = 1,
  ER_EMBED_INPUT_ARG = 2,
  ER_EMBED_OUTPUT_ARG = 3,
  ER_EMBED_GUARD_ARG = 4,
  ER_EMBED_ARRAY_ARG = 5,
  ER_EMBED_SIZE_ARG = 6,
  ER_EMBED_SOURCE_ARG = 7
};

static int er_embed_usage(const char* program) {
  fprintf(stderr,
          "usage: %s <binary|wasm> <input> <output> <guard> <array-name> <size-name> [source]\n",
          program);
  return 2;
}

static long er_embed_file_size(FILE* file, const char* path) {
  long size;

  if (fseek(file, 0, SEEK_END) != 0) {
    fprintf(stderr, "%s: seek failed: %s\n", path, strerror(errno));
    return -1;
  }
  size = ftell(file);
  if (size < 0) {
    fprintf(stderr, "%s: size failed: %s\n", path, strerror(errno));
    return -1;
  }
  if (fseek(file, 0, SEEK_SET) != 0) {
    fprintf(stderr, "%s: rewind failed: %s\n", path, strerror(errno));
    return -1;
  }
  return size;
}

static uint8_t* er_embed_read_file(const char* path, size_t* out_len) {
  FILE* file;
  long file_size;
  uint8_t* bytes;

  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "%s: open failed: %s\n", path, strerror(errno));
    return NULL;
  }

  file_size = er_embed_file_size(file, path);
  if (file_size < 0) {
    fclose(file);
    return NULL;
  }

  bytes = (uint8_t*)malloc((size_t)file_size == 0u ? 1u : (size_t)file_size);
  if (bytes == NULL) {
    fprintf(stderr, "%s: allocation failed\n", path);
    fclose(file);
    return NULL;
  }

  if ((size_t)file_size > 0u && fread(bytes, 1u, (size_t)file_size, file) != (size_t)file_size) {
    fprintf(stderr, "%s: read failed: %s\n", path, ferror(file) != 0 ? strerror(errno) : "short read");
    free(bytes);
    fclose(file);
    return NULL;
  }

  fclose(file);
  *out_len = (size_t)file_size;
  return bytes;
}

static int er_embed_write_bytes(FILE* out, const uint8_t* bytes, size_t len, size_t bytes_per_line) {
  size_t i;
  size_t line_remaining = 0u;

  for (i = 0u; i < len; ++i) {
    if (line_remaining == 0u) {
      if (fprintf(out, "  ") < 0) {
        return 0;
      }
      line_remaining = bytes_per_line;
    }
    if (fprintf(out, "0x%02x", (unsigned int)bytes[i]) < 0) {
      return 0;
    }
    --line_remaining;
    if (i + 1u < len) {
      if (fprintf(out, ",") < 0) {
        return 0;
      }
      if (line_remaining == 0u) {
        if (fprintf(out, "\n") < 0) {
          return 0;
        }
      } else if (fprintf(out, " ") < 0) {
        return 0;
      }
    } else if (fprintf(out, "\n") < 0) {
      return 0;
    }
  }
  return 1;
}

static int er_embed_write_header(const char* mode, const char* input_path, const char* output_path,
                                 const char* guard, const char* array_name, const char* size_name,
                                 const char* source_path) {
  uint8_t* bytes;
  size_t len = 0u;
  FILE* out;
  int ok = 1;
  int is_wasm = strcmp(mode, "wasm") == 0;

  bytes = er_embed_read_file(input_path, &len);
  if (bytes == NULL) {
    return 1;
  }

  out = fopen(output_path, "wb");
  if (out == NULL) {
    fprintf(stderr, "%s: open failed: %s\n", output_path, strerror(errno));
    free(bytes);
    return 1;
  }

  if (is_wasm != 0 && source_path != NULL) {
    ok = ok && fprintf(out, "/* Generated from %s */\n", source_path) >= 0;
  }
  ok = ok && fprintf(out, "#ifndef %s\n", guard) >= 0;
  ok = ok && fprintf(out, "#define %s\n", guard) >= 0;
  if (is_wasm == 0) {
    ok = ok && fprintf(out, "\n#include \"er_types.h\"\n\n") >= 0;
  }
  ok = ok && fprintf(out, "static const UINT8 %s[] = {\n", array_name) >= 0;
  ok = ok && er_embed_write_bytes(out, bytes, len, is_wasm != 0 ? ER_EMBED_BYTES_PER_WASM_LINE : ER_EMBED_BYTES_PER_BINARY_LINE);
  ok = ok && fprintf(out, "};\n") >= 0;
  if (is_wasm != 0) {
    ok = ok && fprintf(out, "static const UINT32 %s = %uu;\n", size_name, (unsigned int)len) >= 0;
  } else {
    ok = ok && fprintf(out, "\n#define %s ((UINTN)sizeof(%s))\n\n", size_name, array_name) >= 0;
  }
  ok = ok && fprintf(out, "#endif\n") >= 0;

  if (fclose(out) != 0) {
    fprintf(stderr, "%s: close failed: %s\n", output_path, strerror(errno));
    ok = 0;
  }
  free(bytes);
  return ok != 0 ? 0 : 1;
}

int main(int argc, char** argv) {
  const char* mode;

  if (argc != ER_EMBED_BINARY_ARGC && argc != ER_EMBED_WASM_ARGC) {
    return er_embed_usage(argv[0]);
  }
  mode = argv[ER_EMBED_MODE_ARG];
  if (strcmp(mode, "binary") != 0 && strcmp(mode, "wasm") != 0) {
    return er_embed_usage(argv[0]);
  }
  if (strcmp(mode, "wasm") == 0 && argc != ER_EMBED_WASM_ARGC) {
    return er_embed_usage(argv[0]);
  }
  if (strcmp(mode, "binary") == 0 && argc != ER_EMBED_BINARY_ARGC) {
    return er_embed_usage(argv[0]);
  }
  return er_embed_write_header(mode, argv[ER_EMBED_INPUT_ARG], argv[ER_EMBED_OUTPUT_ARG],
                               argv[ER_EMBED_GUARD_ARG], argv[ER_EMBED_ARRAY_ARG],
                               argv[ER_EMBED_SIZE_ARG],
                               argc == ER_EMBED_WASM_ARGC ? argv[ER_EMBED_SOURCE_ARG] : NULL);
}
