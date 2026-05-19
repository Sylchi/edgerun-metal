#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

/*
 * Purpose:
 *   Stage explicit Raspberry Pi boot trees around owned EdgeRun payloads.
 * Intention:
 *   Keep board bring-up artifacts deterministic and visible while the
 *   repository still treats Raspberry Pi firmware as an external first stage.
 */

enum {
  ERPBS_ARGC = 4,
  ERPBS_ARG_BOARD = 1,
  ERPBS_ARG_PAYLOAD = 2,
  ERPBS_ARG_OUTPUT = 3,
  ERPBS_PATH_CAP = 4096,
  ERPBS_COPY_CAP = 16384,
  ERPBS_OUTPUT_DIR_MODE = 0777
};

typedef struct {
  const char* board;
  const char* payload_path;
  const char* config_text;
  const char* startup_text;
  const char* manifest_name;
  const char* manifest_text;
  int needs_efi_dirs;
} ErpbsBoardProfile;

static const char ERPBS_BOOTAA64_PATH[] = "EFI/BOOT/BOOTAA64.EFI";
static const char ERPBS_KERNEL_IMG_PATH[] = "kernel.img";
static const char ERPBS_EFI_DIR[] = "EFI";
static const char ERPBS_EFI_BOOT_DIR[] = "EFI/BOOT";
static const char ERPBS_CONFIG_NAME[] = "config.txt";
static const char ERPBS_STARTUP_NAME[] = "startup.nsh";
static const char ERPBS_ZERO2W_MANIFEST_NAME[] = "EDGERUN-PI-ZERO-2W-BOOT.txt";
static const char ERPBS_ZERO_W_MANIFEST_NAME[] =
    "EDGERUN-PI-ZERO-W-V1_1-BOOT.txt";
static const char ERPBS_ZERO2W_CONFIG_TEXT[] =
    "arm_64bit=1\n"
    "enable_uart=1\n"
    "uart_2ndstage=1\n"
    "kernel=u-boot.bin\n";
static const char ERPBS_ZERO_W_CONFIG_TEXT[] =
    "arm_64bit=0\n"
    "enable_uart=1\n"
    "uart_2ndstage=1\n"
    "kernel=kernel.img\n";
static const char ERPBS_ZERO2W_STARTUP_TEXT[] =
    "fs0:\\EFI\\BOOT\\BOOTAA64.EFI\n";
static const char ERPBS_ZERO_W_STARTUP_TEXT[] = "";
static const char ERPBS_ZERO2W_MANIFEST_TEXT[] =
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
static const char ERPBS_ZERO_W_MANIFEST_TEXT[] =
    "board=pi-zero-w-v1_1\n"
    "arch=armv6\n"
    "owned_payload=kernel.img\n"
    "boot_chain=raspberry-pi-firmware -> kernel.img\n"
    "required_first_stage=raspberry-pi-firmware\n"
    "node=erzw-0:bootstrap-identity-package-index-serial-first-boot\n"
    "node=erzw-1:sealed-object-storage-replica\n"
    "node=erzw-2:relay-only\n"
    "node=erzw-3:offline-rejoin-failure-injection\n"
    "node=erzw-4:sealed-object-storage-replica-divergence-check\n"
    "node=erzw-5:mobile-observer-route-churn-late-admission\n";

static const ErpbsBoardProfile ERPBS_BOARD_PROFILES[] = {
  {
    "pi-zero-2w",
    ERPBS_BOOTAA64_PATH,
    ERPBS_ZERO2W_CONFIG_TEXT,
    ERPBS_ZERO2W_STARTUP_TEXT,
    ERPBS_ZERO2W_MANIFEST_NAME,
    ERPBS_ZERO2W_MANIFEST_TEXT,
    1
  },
  {
    "pi-zero-w-v1_1",
    ERPBS_KERNEL_IMG_PATH,
    ERPBS_ZERO_W_CONFIG_TEXT,
    ERPBS_ZERO_W_STARTUP_TEXT,
    ERPBS_ZERO_W_MANIFEST_NAME,
    ERPBS_ZERO_W_MANIFEST_TEXT,
    0
  }
};

static const size_t ERPBS_BOARD_PROFILE_COUNT =
    sizeof(ERPBS_BOARD_PROFILES) / sizeof(ERPBS_BOARD_PROFILES[0]);

static int erpbs_fail(const char* message) {
  fprintf(stderr, "pi-boot-stage: %s\n", message);
  return 1;
}

static const ErpbsBoardProfile* erpbs_find_board(const char* board) {
  size_t i;

  if (board == NULL) {
    return NULL;
  }
  for (i = 0u; i < ERPBS_BOARD_PROFILE_COUNT; ++i) {
    if (strcmp(board, ERPBS_BOARD_PROFILES[i].board) == 0) {
      return &ERPBS_BOARD_PROFILES[i];
    }
  }
  return NULL;
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

static int erpbs_stage(const ErpbsBoardProfile* profile,
                       const char* payload,
                       const char* output_dir) {
  char payload_path[ERPBS_PATH_CAP];
  char config_path[ERPBS_PATH_CAP];
  char startup_path[ERPBS_PATH_CAP];
  char manifest_path[ERPBS_PATH_CAP];

  if (profile == NULL || payload == NULL || output_dir == NULL ||
      payload[0] == '\0' ||
      output_dir[0] == '\0') {
    return erpbs_fail("empty path");
  }
  if (erpbs_mkdir_one(output_dir) != 0) {
    return 1;
  }
  if (profile->needs_efi_dirs != 0 &&
      (erpbs_mkdir_child(output_dir, ERPBS_EFI_DIR) != 0 ||
       erpbs_mkdir_child(output_dir, ERPBS_EFI_BOOT_DIR) != 0)) {
    return 1;
  }
  if (erpbs_join(payload_path, sizeof(payload_path), output_dir,
                 profile->payload_path) != 0 ||
      erpbs_join(config_path, sizeof(config_path), output_dir,
                 ERPBS_CONFIG_NAME) != 0 ||
      erpbs_join(startup_path, sizeof(startup_path), output_dir,
                 ERPBS_STARTUP_NAME) != 0 ||
      erpbs_join(manifest_path, sizeof(manifest_path), output_dir,
                 profile->manifest_name) != 0) {
    return 1;
  }
  if (erpbs_copy_payload(payload, payload_path) != 0 ||
      erpbs_write_text(config_path, profile->config_text) != 0 ||
      erpbs_write_text(startup_path, profile->startup_text) != 0 ||
      erpbs_write_text(manifest_path, profile->manifest_text) != 0) {
    return 1;
  }
  printf("pi-boot-stage: staged %s\n", output_dir);
  return 0;
}

int main(int argc, char** argv) {
  const ErpbsBoardProfile* profile;

  if (argc != ERPBS_ARGC) {
    fprintf(stderr,
            "usage: pi-boot-stage <board> <payload> <output-dir>\n");
    return 2;
  }
  profile = erpbs_find_board(argv[ERPBS_ARG_BOARD]);
  if (profile == NULL) {
    return erpbs_fail("unsupported board");
  }
  return erpbs_stage(profile, argv[ERPBS_ARG_PAYLOAD], argv[ERPBS_ARG_OUTPUT]);
}
