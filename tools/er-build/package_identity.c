#include "package_identity.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "er_blake3.h"

enum {
  ERB_PACKAGE_HASH_CHUNK_CAP = 4096,
  ERB_PACKAGE_HASH_HEX_CAP = (ER_BLAKE3_OUT_LEN * 2u) + 1u,
  ERB_PACKAGE_IDENTITY_TEXT_CAP = 512,
  ERB_PACKAGE_HASH_NIBBLE_SHIFT = 4u,
  ERB_PACKAGE_HASH_NIBBLE_MASK = 0x0f
};

static const char ERB_PACKAGE_IDENTITY_DOMAIN[] = "edgerun:erc:v1:app-package-identity\n";
static const char ERB_PACKAGE_IDENTITY_ASSETS[] = "assets=none\n";
static const char ERB_PACKAGE_HEX[] = "0123456789abcdef";

static int erb_package_identity_fail(const char* message) {
  fprintf(stderr, "er-build: %s\n", message);
  return 1;
}

static void erb_package_hash_to_hex(const uint8_t hash[ER_BLAKE3_OUT_LEN],
                                    char out[ERB_PACKAGE_HASH_HEX_CAP]) {
  size_t i;

  for (i = 0u; i < ER_BLAKE3_OUT_LEN; ++i) {
    out[i * 2u] =
        ERB_PACKAGE_HEX[(hash[i] >> ERB_PACKAGE_HASH_NIBBLE_SHIFT) &
                        ERB_PACKAGE_HASH_NIBBLE_MASK];
    out[(i * 2u) + 1u] = ERB_PACKAGE_HEX[hash[i] & ERB_PACKAGE_HASH_NIBBLE_MASK];
  }
  out[ERB_PACKAGE_HASH_HEX_CAP - 1u] = '\0';
}

static int erb_package_hash_file(const char* path, uint8_t out[ER_BLAKE3_OUT_LEN]) {
  ErBlake3Hasher hasher;
  FILE* file;
  uint8_t buffer[ERB_PACKAGE_HASH_CHUNK_CAP];
  size_t len;

  if (path == NULL || out == NULL) {
    return erb_package_identity_fail("invalid hash input");
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "er-build: open failed for %s: %s\n", path, strerror(errno));
    return 1;
  }
  er_blake3_init(&hasher);
  do {
    len = fread(buffer, 1u, sizeof(buffer), file);
    if (len > 0u && er_blake3_update(&hasher, buffer, len) == 0u) {
      fclose(file);
      return erb_package_identity_fail("hash update failed");
    }
  } while (len == sizeof(buffer));
  if (ferror(file) != 0) {
    fclose(file);
    fprintf(stderr, "er-build: read failed for %s\n", path);
    return 1;
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "er-build: close failed for %s: %s\n", path, strerror(errno));
    return 1;
  }
  if (er_blake3_final(&hasher, out) == 0u) {
    return erb_package_identity_fail("hash final failed");
  }
  return 0;
}

static int erb_package_hash_identity(const uint8_t source_hash[ER_BLAKE3_OUT_LEN],
                                     const uint8_t manifest_hash[ER_BLAKE3_OUT_LEN],
                                     const uint8_t wasm_hash[ER_BLAKE3_OUT_LEN],
                                     uint8_t package_hash[ER_BLAKE3_OUT_LEN]) {
  ErBlake3Hasher hasher;

  er_blake3_init(&hasher);
  if (er_blake3_update(&hasher, (const uint8_t*)ERB_PACKAGE_IDENTITY_DOMAIN,
                       strlen(ERB_PACKAGE_IDENTITY_DOMAIN)) == 0u ||
      er_blake3_update(&hasher, source_hash, ER_BLAKE3_OUT_LEN) == 0u ||
      er_blake3_update(&hasher, manifest_hash, ER_BLAKE3_OUT_LEN) == 0u ||
      er_blake3_update(&hasher, wasm_hash, ER_BLAKE3_OUT_LEN) == 0u ||
      er_blake3_update(&hasher, (const uint8_t*)ERB_PACKAGE_IDENTITY_ASSETS,
                       strlen(ERB_PACKAGE_IDENTITY_ASSETS)) == 0u ||
      er_blake3_final(&hasher, package_hash) == 0u) {
    return erb_package_identity_fail("package identity hash failed");
  }
  return 0;
}

static const char* erb_package_basename(const char* path) {
  const char* slash;

  if (path == NULL || path[0] == '\0') {
    return NULL;
  }
  slash = strrchr(path, '/');
  if (slash == NULL) {
    return path;
  }
  if (slash[1] == '\0') {
    return NULL;
  }
  return slash + 1;
}

static int erb_format_app_package_identity(const char* app_source,
                                           const char* manifest_source,
                                           const char* output_wasm,
                                           char out[ERB_PACKAGE_IDENTITY_TEXT_CAP]) {
  uint8_t source_hash[ER_BLAKE3_OUT_LEN];
  uint8_t manifest_hash[ER_BLAKE3_OUT_LEN];
  uint8_t wasm_hash[ER_BLAKE3_OUT_LEN];
  uint8_t package_hash[ER_BLAKE3_OUT_LEN];
  char source_hex[ERB_PACKAGE_HASH_HEX_CAP];
  char manifest_hex[ERB_PACKAGE_HASH_HEX_CAP];
  char wasm_hex[ERB_PACKAGE_HASH_HEX_CAP];
  char package_hex[ERB_PACKAGE_HASH_HEX_CAP];
  const char* source_name;
  const char* manifest_name;
  int written;

  source_name = erb_package_basename(app_source);
  manifest_name = erb_package_basename(manifest_source);
  if (source_name == NULL || manifest_name == NULL) {
    return erb_package_identity_fail("invalid package identity path");
  }
  if (erb_package_hash_file(app_source, source_hash) != 0 ||
      erb_package_hash_file(manifest_source, manifest_hash) != 0 ||
      erb_package_hash_file(output_wasm, wasm_hash) != 0 ||
      erb_package_hash_identity(source_hash, manifest_hash, wasm_hash, package_hash) != 0) {
    return 1;
  }
  erb_package_hash_to_hex(source_hash, source_hex);
  erb_package_hash_to_hex(manifest_hash, manifest_hex);
  erb_package_hash_to_hex(wasm_hash, wasm_hex);
  erb_package_hash_to_hex(package_hash, package_hex);

  written = snprintf(out, ERB_PACKAGE_IDENTITY_TEXT_CAP,
                     "package_identity_v1\n"
                     "source=%s\n"
                     "source_blake3=%s\n"
                     "manifest=%s\n"
                     "manifest_blake3=%s\n"
                     "wasm=.build/app.wasm\n"
                     "wasm_blake3=%s\n"
                     "%s"
                     "package_blake3=%s\n",
                     source_name, source_hex, manifest_name, manifest_hex, wasm_hex,
                     ERB_PACKAGE_IDENTITY_ASSETS,
                     package_hex);
  if (written < 0 || (size_t)written >= ERB_PACKAGE_IDENTITY_TEXT_CAP) {
    return erb_package_identity_fail("package identity text too large");
  }
  return 0;
}

int erb_write_app_package_identity(const char* identity_path,
                                   const char* app_source,
                                   const char* manifest_source,
                                   const char* output_wasm) {
  char text[ERB_PACKAGE_IDENTITY_TEXT_CAP];
  FILE* file;

  if (erb_format_app_package_identity(app_source, manifest_source, output_wasm, text) != 0) {
    return 1;
  }
  file = fopen(identity_path, "wb");
  if (file == NULL) {
    fprintf(stderr, "er-build: open failed for %s: %s\n", identity_path, strerror(errno));
    return 1;
  }
  if (fputs(text, file) < 0) {
    fclose(file);
    fprintf(stderr, "er-build: write failed for %s\n", identity_path);
    return 1;
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "er-build: close failed for %s: %s\n", identity_path, strerror(errno));
    return 1;
  }
  return 0;
}

int erb_verify_app_package_identity(const char* identity_path,
                                    const char* app_source,
                                    const char* manifest_source,
                                    const char* output_wasm) {
  char expected[ERB_PACKAGE_IDENTITY_TEXT_CAP];
  char actual[ERB_PACKAGE_IDENTITY_TEXT_CAP];
  FILE* file;
  size_t len;

  if (erb_format_app_package_identity(app_source, manifest_source, output_wasm,
                                      expected) != 0) {
    return 1;
  }
  file = fopen(identity_path, "rb");
  if (file == NULL) {
    fprintf(stderr, "er-build: open failed for %s: %s\n", identity_path, strerror(errno));
    return 1;
  }
  len = fread(actual, 1u, sizeof(actual) - 1u, file);
  if (ferror(file) != 0) {
    fclose(file);
    fprintf(stderr, "er-build: read failed for %s\n", identity_path);
    return 1;
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "er-build: close failed for %s: %s\n", identity_path, strerror(errno));
    return 1;
  }
  actual[len] = '\0';
  if (len == sizeof(actual) - 1u || strcmp(actual, expected) != 0) {
    fprintf(stderr, "er-build: invalid package identity %s\n", identity_path);
    return 1;
  }
  return 0;
}
