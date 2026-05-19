#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

/*
 * Purpose:
 *   Stage the explicit Raspberry Pi Zero 2 W boot tree around the owned
 *   EdgeRun AArch64 EFI payload.
 * Intention:
 *   Keep board bring-up artifacts deterministic and visible while the
 *   repository still treats Raspberry Pi firmware and U-Boot as external
 *   first-stage hardware prerequisites.
 */

enum {
  ERPBS_ARGC = 3,
  ERPBS_ARG_EFI = 1,
  ERPBS_ARG_OUTPUT = 2,
  ERPBS_PATH_CAP = 4096,
  ERPBS_COPY_CAP = 16384,
  ERPBS_OUTPUT_DIR_MODE = 0777
};

static const char ERPBS_BOOTAA64_PATH[] = "EFI/BOOT/BOOTAA64.EFI";
static const char ERPBS_EFI_DIR[] = "EFI";
static const char ERPBS_EFI_BOOT_DIR[] = "EFI/BOOT";
static const char ERPBS_CONFIG_NAME[] = "config.txt";
static const char ERPBS_STARTUP_NAME[] = "startup.nsh";
static const char ERPBS_MANIFEST_NAME[] = "EDGERUN-PI-ZERO-2W-BOOT.txt";
static const char ERPBS_CONFIG_TEXT[] =
    "arm_64bit=1\n"
    "enable_uart=1\n"
    "uart_2ndstage=1\n"
    "kernel=u-boot.bin\n";
static const char ERPBS_STARTUP_TEXT[] =
    "fs0:\\EFI\\BOOT\\BOOTAA64.EFI\n";
static const char ERPBS_MANIFEST_TEXT[] =
    "board=pi-zero-2w\n"
    "arch=aarch64\n"
    "owned_payload=EFI/BOOT/BOOTAA64.EFI\n"
    "boot_chain=raspberry-pi-firmware -> u-boot-efi -> BOOTAA64.EFI\n"
    "required_first_stage=raspberry-pi-firmware\n"
    "required_first_stage=u-boot.bin\n"
    "node=erz2w-0:bootstrap-identity-package-index-serial-first-boot\n"
    "node=erz2w-1:sealed-object-storage-replica\n"
    "node=erz2w-2:relay-only\n"
    "node=erz2w-3:offline-rejoin-failure-injection\n"
    "node=erz2w-4:sealed-object-storage-replica-divergence-check\n"
    "node=erz2w-5:mobile-observer-route-churn-late-admission\n";

static int erpbs_fail(const char* message) {
  fprintf(stderr, "pi-boot-stage: %s\n", message);
  return 1;
}

static int erpbs_join(char* out, size_t out_len, const char* left,
                      const char* right) {
  int written;

  if (out == NULL || left == NULL || right == NULL || out_len == 0u ||
      left[0] == '\0' || right[0] == '\0') {
    return erpbs_fail("invalid path");
  }
  written = snprintf(out, out_len, "%s/%s", left, right);
  if (written < 0 || (size_t)written >= out_len) {
    return erpbs_fail("path too long");
  }
  return 0;
}

static int erpbs_mkdir_one(const char* path) {
  struct stat st;

  if (mkdir(path, ERPBS_OUTPUT_DIR_MODE) == 0) {
    return 0;
  }
  if (errno == EEXIST && stat(path, &st) == 0 && S_ISDIR(st.st_mode)) {
    return 0;
  }
  fprintf(stderr, "pi-boot-stage: mkdir failed for %s: %s\n", path,
          strerror(errno));
  return 1;
}

static int erpbs_mkdir_child(const char* root, const char* child) {
  char path[ERPBS_PATH_CAP];

  if (erpbs_join(path, sizeof(path), root, child) != 0) {
    return 1;
  }
  return erpbs_mkdir_one(path);
}

static int erpbs_write_text(const char* path, const char* text) {
  FILE* file;
  size_t text_len;
  size_t written;

  if (path == NULL || text == NULL) {
    return erpbs_fail("invalid text write");
  }
  file = fopen(path, "wb");
  if (file == NULL) {
    fprintf(stderr, "pi-boot-stage: open failed for %s: %s\n", path,
            strerror(errno));
    return 1;
  }
  text_len = strlen(text);
  written = fwrite(text, 1u, text_len, file);
  if (written != text_len) {
    fclose(file);
    fprintf(stderr, "pi-boot-stage: write failed for %s\n", path);
    return 1;
  }
  if (fclose(file) != 0) {
    fprintf(stderr, "pi-boot-stage: close failed for %s: %s\n", path,
            strerror(errno));
    return 1;
  }
  return 0;
}

static int erpbs_copy_payload(const char* src, const char* dst) {
  FILE* in;
  FILE* out;
  unsigned char buffer[ERPBS_COPY_CAP];
  size_t total = 0u;
  size_t read_len;

  in = fopen(src, "rb");
  if (in == NULL) {
    fprintf(stderr, "pi-boot-stage: open failed for %s: %s\n", src,
            strerror(errno));
    return 1;
  }
  out = fopen(dst, "wb");
  if (out == NULL) {
    fclose(in);
    fprintf(stderr, "pi-boot-stage: open failed for %s: %s\n", dst,
            strerror(errno));
    return 1;
  }
  while ((read_len = fread(buffer, 1u, sizeof(buffer), in)) > 0u) {
    if (fwrite(buffer, 1u, read_len, out) != read_len) {
      fclose(in);
      fclose(out);
      fprintf(stderr, "pi-boot-stage: write failed for %s\n", dst);
      return 1;
    }
    total += read_len;
  }
  if (ferror(in) != 0) {
    fclose(in);
    fclose(out);
    fprintf(stderr, "pi-boot-stage: read failed for %s\n", src);
    return 1;
  }
  if (fclose(in) != 0) {
    fclose(out);
    fprintf(stderr, "pi-boot-stage: close failed for %s: %s\n", src,
            strerror(errno));
    return 1;
  }
  if (fclose(out) != 0) {
    fprintf(stderr, "pi-boot-stage: close failed for %s: %s\n", dst,
            strerror(errno));
    return 1;
  }
  if (total == 0u) {
    return erpbs_fail("EFI payload is empty");
  }
  return 0;
}

static int erpbs_stage(const char* efi_payload, const char* output_dir) {
  char boot_path[ERPBS_PATH_CAP];
  char config_path[ERPBS_PATH_CAP];
  char startup_path[ERPBS_PATH_CAP];
  char manifest_path[ERPBS_PATH_CAP];

  if (efi_payload == NULL || output_dir == NULL || efi_payload[0] == '\0' ||
      output_dir[0] == '\0') {
    return erpbs_fail("empty path");
  }
  if (erpbs_mkdir_one(output_dir) != 0 ||
      erpbs_mkdir_child(output_dir, ERPBS_EFI_DIR) != 0 ||
      erpbs_mkdir_child(output_dir, ERPBS_EFI_BOOT_DIR) != 0 ||
      erpbs_join(boot_path, sizeof(boot_path), output_dir,
                 ERPBS_BOOTAA64_PATH) != 0 ||
      erpbs_join(config_path, sizeof(config_path), output_dir,
                 ERPBS_CONFIG_NAME) != 0 ||
      erpbs_join(startup_path, sizeof(startup_path), output_dir,
                 ERPBS_STARTUP_NAME) != 0 ||
      erpbs_join(manifest_path, sizeof(manifest_path), output_dir,
                 ERPBS_MANIFEST_NAME) != 0) {
    return 1;
  }
  if (erpbs_copy_payload(efi_payload, boot_path) != 0 ||
      erpbs_write_text(config_path, ERPBS_CONFIG_TEXT) != 0 ||
      erpbs_write_text(startup_path, ERPBS_STARTUP_TEXT) != 0 ||
      erpbs_write_text(manifest_path, ERPBS_MANIFEST_TEXT) != 0) {
    return 1;
  }
  printf("pi-boot-stage: staged %s\n", output_dir);
  return 0;
}

int main(int argc, char** argv) {
  if (argc != ERPBS_ARGC) {
    fprintf(stderr, "usage: pi-boot-stage <BOOTAA64.EFI> <output-dir>\n");
    return 2;
  }
  return erpbs_stage(argv[ERPBS_ARG_EFI], argv[ERPBS_ARG_OUTPUT]);
}
