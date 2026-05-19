#define _GNU_SOURCE
#define _POSIX_C_SOURCE 200809L

/*
 * Purpose:
 *   Destructively measure SD-card addressability and sequential throughput.
 * Intention:
 *   Catch counterfeit cards by writing deterministic signatures across the
 *   claimed capacity and verifying that every addressed block reads back.
 */

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <time.h>
#include <unistd.h>

#ifdef __linux__
#include <linux/fs.h>
#endif

enum {
  ERSD_ARG_PROGRAM = 0,
  ERSD_DEFAULT_BLOCK_BYTES = 4096u,
  ERSD_BUFFER_BYTES = 16777216u,
  ERSD_IO_ALIGN_BYTES = 4096u,
  ERSD_PATH_BYTES = 512u,
  ERSD_TEXT_BYTES = 128u,
  ERSD_ETA_TEXT_BYTES = 64u,
  ERSD_DECIMAL_BASE = 10,
  ERSD_MIN_ARGS = 3,
  ERSD_EXIT_USAGE = 2,
  ERSD_PATTERN_SALT_A = 0x51u,
  ERSD_PATTERN_SALT_SHIFT = 56u,
  ERSD_MIB_BYTES = 1048576u,
  ERSD_MB_BYTES = 1000000u,
  ERSD_SEC_NSEC = 1000000000u,
  ERSD_SECONDS_PER_MINUTE = 60u,
  ERSD_SECONDS_PER_HOUR = 3600u,
  ERSD_SYSFS_SECTOR_BYTES = 512u,
  ERSD_PROGRESS_BYTES = 268435456u,
  ERSD_SPEED_MB_C2 = 2u,
  ERSD_SPEED_MB_C4 = 4u,
  ERSD_SPEED_MB_C6 = 6u,
  ERSD_SPEED_MB_C10 = 10u,
  ERSD_SPEED_MB_V30 = 30u,
  ERSD_SPEED_MB_V60 = 60u,
  ERSD_SPEED_MB_V90 = 90u
};

typedef enum {
  ERSD_DEVICE_UNKNOWN = 0,
  ERSD_DEVICE_REGULAR = 1,
  ERSD_DEVICE_BLOCK = 2
} ErsdDeviceKind;

typedef struct {
  const char* target;
  uint64_t byte_limit;
  size_t block_bytes;
  int destroy;
} ErsdConfig;

typedef struct {
  ErsdDeviceKind kind;
  uint64_t claimed_bytes;
  char sysfs_path[ERSD_PATH_BYTES];
  char vendor[ERSD_TEXT_BYTES];
  char model[ERSD_TEXT_BYTES];
  char serial[ERSD_TEXT_BYTES];
  char cid[ERSD_TEXT_BYTES];
  char csd[ERSD_TEXT_BYTES];
} ErsdDeviceInfo;

typedef struct {
  uint64_t write_bytes;
  uint64_t verify_bytes;
  uint64_t read_check_bytes;
  uint64_t first_bad_offset;
  uint64_t actual_bytes;
  double write_seconds;
  double verify_seconds;
  double read_check_seconds;
  int failed;
  int wrapped;
} ErsdProbeResult;

static const uint64_t ERSD_PATTERN_BLOCK_FACTOR = UINT64_C(0xbf58476d1ce4e5b9);
static const uint64_t ERSD_PATTERN_WORD_STEP = UINT64_C(0x94d049bb133111eb);
static const uint64_t ERSD_PATTERN_BASE = UINT64_C(0x9e3779b97f4a7c15);

_Alignas(ERSD_IO_ALIGN_BYTES) static unsigned char g_ersd_buffer[ERSD_BUFFER_BYTES];
_Alignas(ERSD_IO_ALIGN_BYTES) static unsigned char g_ersd_verify[ERSD_BUFFER_BYTES];
_Alignas(ERSD_IO_ALIGN_BYTES) static unsigned char g_ersd_block_a[ERSD_BUFFER_BYTES];
_Alignas(ERSD_IO_ALIGN_BYTES) static unsigned char g_ersd_block_read[ERSD_BUFFER_BYTES];

static int ersd_fail(const char* message) {
  fprintf(stderr, "sdcard-probe: %s\n", message);
  return 1;
}

static int ersd_usage(const char* program) {
  fprintf(stderr,
          "usage: %s --destroy <device-or-file> [--bytes N] [--block-bytes N]\n",
          program);
  fprintf(stderr,
          "sdcard-probe: destructive; target contents will be overwritten\n");
  return ERSD_EXIT_USAGE;
}

static int ersd_parse_u64(const char* text, uint64_t* out) {
  char* end = NULL;
  unsigned long long value;

  if (text == NULL || out == NULL || text[0] == '\0') {
    return 0;
  }
  errno = 0;
  value = strtoull(text, &end, ERSD_DECIMAL_BASE);
  if (errno != 0 || end == text || end == NULL || *end != '\0') {
    return 0;
  }
  *out = (uint64_t)value;
  return 1;
}

static int ersd_parse_size(const char* text, size_t* out) {
  uint64_t value;

  if (out == NULL || ersd_parse_u64(text, &value) == 0 ||
      value == 0u || value > ERSD_BUFFER_BYTES) {
    return 0;
  }
  *out = (size_t)value;
  return 1;
}

static int ersd_parse_args(int argc, char** argv, ErsdConfig* cfg) {
  int i;

  if (cfg == NULL) {
    return 1;
  }
  cfg->target = NULL;
  cfg->byte_limit = 0u;
  cfg->block_bytes = ERSD_DEFAULT_BLOCK_BYTES;
  cfg->destroy = 0;
  if (argc < ERSD_MIN_ARGS) {
    return ersd_usage(argv[ERSD_ARG_PROGRAM]);
  }
  for (i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--destroy") == 0) {
      cfg->destroy = 1;
    } else if (strcmp(argv[i], "--bytes") == 0) {
      ++i;
      if (i >= argc || ersd_parse_u64(argv[i], &cfg->byte_limit) == 0) {
        return ersd_usage(argv[ERSD_ARG_PROGRAM]);
      }
    } else if (strcmp(argv[i], "--block-bytes") == 0) {
      ++i;
      if (i >= argc || ersd_parse_size(argv[i], &cfg->block_bytes) == 0) {
        return ersd_usage(argv[ERSD_ARG_PROGRAM]);
      }
    } else if (argv[i][0] == '-') {
      return ersd_usage(argv[ERSD_ARG_PROGRAM]);
    } else if (cfg->target == NULL) {
      cfg->target = argv[i];
    } else {
      return ersd_usage(argv[ERSD_ARG_PROGRAM]);
    }
  }
  if (cfg->destroy == 0 || cfg->target == NULL) {
    return ersd_usage(argv[ERSD_ARG_PROGRAM]);
  }
  if ((ERSD_BUFFER_BYTES % cfg->block_bytes) != 0u) {
    return ersd_fail("block size must divide internal buffer size");
  }
  if ((cfg->block_bytes % sizeof(uint64_t)) != 0u) {
    return ersd_fail("block size must be a multiple of eight bytes");
  }
  if (cfg->byte_limit != 0u && (cfg->byte_limit % cfg->block_bytes) != 0u) {
    return ersd_fail("byte limit must be a multiple of block size");
  }
  return 0;
}

static double ersd_seconds_since(const struct timespec* start,
                                 const struct timespec* end) {
  time_t sec;
  long nsec;

  sec = end->tv_sec - start->tv_sec;
  nsec = end->tv_nsec - start->tv_nsec;
  if (nsec < 0) {
    --sec;
    nsec += (long)ERSD_SEC_NSEC;
  }
  return (double)sec + ((double)nsec / (double)ERSD_SEC_NSEC);
}

static void ersd_fill_pattern(unsigned char* out,
                              size_t bytes,
                              uint64_t block_index,
                              uint8_t salt) {
  size_t word_index;
  size_t word_count;
  uint64_t* words;
  uint64_t word;

  if (out == NULL || (bytes % sizeof(uint64_t)) != 0u) {
    return;
  }
  words = (uint64_t*)out;
  word_count = bytes / sizeof(uint64_t);
  word = ERSD_PATTERN_BASE ^
         ((uint64_t)salt << ERSD_PATTERN_SALT_SHIFT) ^
         (block_index * ERSD_PATTERN_BLOCK_FACTOR);
  for (word_index = 0u; word_index < word_count; ++word_index) {
    words[word_index] = word;
    word += ERSD_PATTERN_WORD_STEP;
  }
}

static void ersd_fill_span(unsigned char* out,
                           size_t bytes,
                           uint64_t offset,
                           size_t block_bytes,
                           uint8_t salt) {
  size_t cursor = 0u;

  while (cursor < bytes) {
    ersd_fill_pattern(out + cursor, block_bytes,
                      (offset + (uint64_t)cursor) / (uint64_t)block_bytes,
                      salt);
    cursor += block_bytes;
  }
}

static int ersd_write_all_at(int fd,
                             const unsigned char* data,
                             size_t bytes,
                             uint64_t offset) {
  size_t done = 0u;

  while (done < bytes) {
    ssize_t wrote = pwrite(fd, data + done, bytes - done,
                           (off_t)(offset + (uint64_t)done));
    if (wrote <= 0) {
      return 0;
    }
    done += (size_t)wrote;
  }
  return 1;
}

static int ersd_read_all_at(int fd,
                            unsigned char* data,
                            size_t bytes,
                            uint64_t offset) {
  size_t done = 0u;

  while (done < bytes) {
    ssize_t read_len = pread(fd, data + done, bytes - done,
                             (off_t)(offset + (uint64_t)done));
    if (read_len <= 0) {
      return 0;
    }
    done += (size_t)read_len;
  }
  return 1;
}

static int ersd_same_span(int fd,
                          uint64_t offset,
                          size_t bytes,
                          size_t block_bytes,
                          uint8_t salt) {
  ersd_fill_span(g_ersd_buffer, bytes, offset, block_bytes, salt);
  if (ersd_read_all_at(fd, g_ersd_verify, bytes, offset) == 0) {
    return 0;
  }
  return memcmp(g_ersd_buffer, g_ersd_verify, bytes) == 0;
}

static void ersd_trim_line(char* text) {
  size_t len;

  if (text == NULL) {
    return;
  }
  len = strlen(text);
  while (len > 0u && (text[len - 1u] == '\n' || text[len - 1u] == '\r' ||
                      text[len - 1u] == ' ' || text[len - 1u] == '\t')) {
    text[len - 1u] = '\0';
    --len;
  }
}

static int ersd_read_text(const char* path, char* out, size_t out_size) {
  FILE* file;

  if (path == NULL || out == NULL || out_size == 0u) {
    return 0;
  }
  file = fopen(path, "rb");
  if (file == NULL) {
    return 0;
  }
  if (fgets(out, (int)out_size, file) == NULL) {
    fclose(file);
    return 0;
  }
  if (fclose(file) != 0) {
    return 0;
  }
  ersd_trim_line(out);
  return out[0] != '\0';
}

static int ersd_join(char* out, size_t out_size, const char* a, const char* b) {
  int written;

  if (out == NULL || a == NULL || b == NULL || out_size == 0u) {
    return 0;
  }
  written = snprintf(out, out_size, "%s/%s", a, b);
  return written >= 0 && (size_t)written < out_size;
}

static void ersd_read_sysfs_field(const char* base,
                                  const char* name,
                                  char* out,
                                  size_t out_size) {
  char path[ERSD_PATH_BYTES];

  if (out == NULL || out_size == 0u) {
    return;
  }
  out[0] = '\0';
  if (base == NULL || name == NULL ||
      ersd_join(path, sizeof(path), base, name) == 0) {
    return;
  }
  (void)ersd_read_text(path, out, out_size);
}

static int ersd_block_size_from_sysfs(const char* base, uint64_t* out_bytes) {
  char text[ERSD_TEXT_BYTES];
  uint64_t sectors;
  char path[ERSD_PATH_BYTES];

  if (base == NULL || out_bytes == NULL ||
      ersd_join(path, sizeof(path), base, "size") == 0 ||
      ersd_read_text(path, text, sizeof(text)) == 0 ||
      ersd_parse_u64(text, &sectors) == 0) {
    return 0;
  }
  *out_bytes = sectors * ERSD_SYSFS_SECTOR_BYTES;
  return 1;
}

static void ersd_probe_sysfs(const struct stat* st, ErsdDeviceInfo* info) {
  char link_path[ERSD_PATH_BYTES];
  char resolved[ERSD_PATH_BYTES];
  char mm[ERSD_TEXT_BYTES];
  ssize_t len;

  if (st == NULL || info == NULL || !S_ISBLK(st->st_mode)) {
    return;
  }
  snprintf(mm, sizeof(mm), "%u:%u", major(st->st_rdev), minor(st->st_rdev));
  snprintf(link_path, sizeof(link_path), "/sys/dev/block/%s", mm);
  len = readlink(link_path, resolved, sizeof(resolved) - 1u);
  if (len <= 0) {
    return;
  }
  resolved[len] = '\0';
  snprintf(info->sysfs_path, sizeof(info->sysfs_path), "/sys/dev/block/%s", mm);
  ersd_read_sysfs_field(info->sysfs_path, "device/vendor",
                        info->vendor, sizeof(info->vendor));
  ersd_read_sysfs_field(info->sysfs_path, "device/model",
                        info->model, sizeof(info->model));
  ersd_read_sysfs_field(info->sysfs_path, "device/serial",
                        info->serial, sizeof(info->serial));
  ersd_read_sysfs_field(info->sysfs_path, "device/cid",
                        info->cid, sizeof(info->cid));
  ersd_read_sysfs_field(info->sysfs_path, "device/csd",
                        info->csd, sizeof(info->csd));
  if (info->claimed_bytes == 0u) {
    (void)ersd_block_size_from_sysfs(info->sysfs_path, &info->claimed_bytes);
  }
}

static int ersd_open_info(const char* target, int* out_fd, ErsdDeviceInfo* info) {
  struct stat st;
  int fd;

  if (target == NULL || out_fd == NULL || info == NULL) {
    return ersd_fail("invalid target");
  }
  memset(info, 0, sizeof(*info));
  fd = open(target, O_RDWR | O_CLOEXEC | O_DIRECT);
  if (fd < 0) {
    fprintf(stderr, "sdcard-probe: open failed for %s: %s\n", target, strerror(errno));
    return 1;
  }
  if (fstat(fd, &st) != 0) {
    close(fd);
    return ersd_fail("target stat failed");
  }
  if (S_ISREG(st.st_mode)) {
    info->kind = ERSD_DEVICE_REGULAR;
    info->claimed_bytes = (uint64_t)st.st_size;
  } else if (S_ISBLK(st.st_mode)) {
    info->kind = ERSD_DEVICE_BLOCK;
#ifdef BLKGETSIZE64
    if (ioctl(fd, BLKGETSIZE64, &info->claimed_bytes) != 0) {
      close(fd);
      return ersd_fail("BLKGETSIZE64 failed");
    }
#else
    close(fd);
    return ersd_fail("block-device capacity ioctl unavailable");
#endif
    ersd_probe_sysfs(&st, info);
  } else {
    close(fd);
    return ersd_fail("target must be a regular file or block device");
  }
  if (info->claimed_bytes == 0u) {
    close(fd);
    return ersd_fail("target capacity is zero");
  }
  *out_fd = fd;
  return 0;
}

static uint64_t ersd_min_u64(uint64_t a, uint64_t b) {
  return a < b ? a : b;
}

static double ersd_mib_per_sec(uint64_t bytes, double seconds) {
  if (seconds <= 0.0) {
    return 0.0;
  }
  return ((double)bytes / (double)ERSD_MIB_BYTES) / seconds;
}

static double ersd_mb_per_sec(uint64_t bytes, double seconds) {
  if (seconds <= 0.0) {
    return 0.0;
  }
  return ((double)bytes / (double)ERSD_MB_BYTES) / seconds;
}

static const char* ersd_sd_speed_class(double write_mb_sec) {
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C10) {
    return "C10";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C6) {
    return "C6";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C4) {
    return "C4";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C2) {
    return "C2";
  }
  return "below-C2";
}

static const char* ersd_uhs_speed_class(double write_mb_sec) {
  if (write_mb_sec >= (double)ERSD_SPEED_MB_V30) {
    return "U3";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C10) {
    return "U1";
  }
  return "below-U1";
}

static const char* ersd_video_speed_class(double write_mb_sec) {
  if (write_mb_sec >= (double)ERSD_SPEED_MB_V90) {
    return "V90";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_V60) {
    return "V60";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_V30) {
    return "V30";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C10) {
    return "V10";
  }
  if (write_mb_sec >= (double)ERSD_SPEED_MB_C6) {
    return "V6";
  }
  return "below-V6";
}

static void ersd_format_eta(double seconds, char* out, size_t out_size) {
  unsigned long long whole_seconds;
  unsigned long long hours;
  unsigned long long minutes;

  if (out == NULL || out_size == 0u) {
    return;
  }
  if (seconds <= 0.0) {
    snprintf(out, out_size, "unknown");
    return;
  }
  whole_seconds = (unsigned long long)(seconds + 0.5);
  hours = whole_seconds / ERSD_SECONDS_PER_HOUR;
  whole_seconds %= ERSD_SECONDS_PER_HOUR;
  minutes = whole_seconds / ERSD_SECONDS_PER_MINUTE;
  whole_seconds %= ERSD_SECONDS_PER_MINUTE;
  if (hours > 0u) {
    snprintf(out, out_size, "%lluh%02llum%02llus", hours, minutes, whole_seconds);
  } else if (minutes > 0u) {
    snprintf(out, out_size, "%llum%02llus", minutes, whole_seconds);
  } else {
    snprintf(out, out_size, "%llus", whole_seconds);
  }
}

static const char* ersd_kind_label(ErsdDeviceKind kind) {
  switch (kind) {
    case ERSD_DEVICE_REGULAR:
      return "regular-file";
    case ERSD_DEVICE_BLOCK:
      return "block-device";
    case ERSD_DEVICE_UNKNOWN:
    default:
      return "unknown";
  }
}

static void ersd_print_progress(uint64_t done,
                                uint64_t total,
                                const ErsdProbeResult* result) {
  double write_mb_sec;
  double combined_seconds;
  double eta_seconds;
  char eta[ERSD_ETA_TEXT_BYTES];

  if (done == total || (done % ERSD_PROGRESS_BYTES) == 0u) {
    write_mb_sec = ersd_mb_per_sec(result->write_bytes, result->write_seconds);
    combined_seconds = result->write_seconds + result->verify_seconds;
    eta_seconds = 0.0;
    if (done > 0u && combined_seconds > 0.0 && total > done) {
      eta_seconds = ((double)(total - done) * combined_seconds) / (double)done;
    }
    ersd_format_eta(eta_seconds, eta, sizeof(eta));
    fprintf(stderr,
            "sdcard-probe: checked %llu / %llu bytes write %.2f MiB/s %.2f MB/s %s/%s/%s verify %.2f MiB/s eta-real-card %s\n",
            (unsigned long long)done,
            (unsigned long long)total,
            ersd_mib_per_sec(result->write_bytes, result->write_seconds),
            write_mb_sec,
            ersd_sd_speed_class(write_mb_sec),
            ersd_uhs_speed_class(write_mb_sec),
            ersd_video_speed_class(write_mb_sec),
            ersd_mib_per_sec(result->verify_bytes, result->verify_seconds),
            eta);
  }
}

static void ersd_print_live_text_field(const char* label, const char* value) {
  if (value != NULL && value[0] != '\0') {
    fprintf(stderr, "sdcard-probe: %s: %s\n", label, value);
  } else {
    fprintf(stderr, "sdcard-probe: %s: unavailable\n", label);
  }
}

static void ersd_print_live_header(const ErsdConfig* cfg,
                                   const ErsdDeviceInfo* info,
                                   uint64_t tested_bytes) {
  fprintf(stderr, "sdcard-probe: target: %s\n", cfg->target);
  fprintf(stderr, "sdcard-probe: kind: %s\n", ersd_kind_label(info->kind));
  fprintf(stderr, "sdcard-probe: claimed-bytes: %llu\n",
          (unsigned long long)info->claimed_bytes);
  fprintf(stderr, "sdcard-probe: tested-bytes: %llu\n",
          (unsigned long long)tested_bytes);
  ersd_print_live_text_field("vendor", info->vendor);
  ersd_print_live_text_field("model", info->model);
  ersd_print_live_text_field("serial", info->serial);
  ersd_print_live_text_field("cid", info->cid);
  ersd_print_live_text_field("csd", info->csd);
}

static int ersd_probe_interleaved(int fd,
                                  uint64_t bytes,
                                  size_t block_bytes,
                                  ErsdProbeResult* result) {
  uint64_t offset = 0u;
  uint64_t next_read_offset = 0u;
  uint64_t read_limit;
  struct timespec start;
  struct timespec end;
  struct timespec write_start;
  struct timespec write_end;
  struct timespec verify_start;
  struct timespec verify_end;

  if (result == NULL) {
    return 1;
  }
  memset(result, 0, sizeof(*result));
  result->first_bad_offset = bytes;
  result->actual_bytes = bytes;
  ersd_fill_pattern(g_ersd_block_a, block_bytes, 0u, ERSD_PATTERN_SALT_A);
  while (offset < bytes) {
    size_t span = (size_t)ersd_min_u64((uint64_t)sizeof(g_ersd_buffer),
                                       bytes - offset);
    ersd_fill_span(g_ersd_buffer, span, offset, block_bytes, ERSD_PATTERN_SALT_A);
    if (clock_gettime(CLOCK_MONOTONIC, &write_start) != 0) {
      return ersd_fail("clock_gettime failed");
    }
    if (ersd_write_all_at(fd, g_ersd_buffer, span, offset) == 0) {
      result->failed = 1;
      result->first_bad_offset = offset;
      break;
    }
    if (clock_gettime(CLOCK_MONOTONIC, &write_end) != 0) {
      return ersd_fail("clock_gettime failed");
    }
    offset += (uint64_t)span;
    result->write_bytes = offset;
    result->write_seconds += ersd_seconds_since(&write_start, &write_end);
    if (clock_gettime(CLOCK_MONOTONIC, &verify_start) != 0) {
      return ersd_fail("clock_gettime failed");
    }
    if (ersd_same_span(fd, offset - (uint64_t)span, span,
                       block_bytes, ERSD_PATTERN_SALT_A) == 0) {
      result->failed = 1;
      result->first_bad_offset = offset - (uint64_t)span;
      result->actual_bytes = result->first_bad_offset;
      break;
    }
    result->verify_bytes = offset;
    if (offset > (uint64_t)span &&
        (ersd_read_all_at(fd, g_ersd_block_read, block_bytes, 0u) == 0 ||
         memcmp(g_ersd_block_a, g_ersd_block_read, block_bytes) != 0)) {
      result->failed = 1;
      result->wrapped = 1;
      result->first_bad_offset = offset - (uint64_t)span;
      result->actual_bytes = result->first_bad_offset;
      break;
    }
    if (clock_gettime(CLOCK_MONOTONIC, &verify_end) != 0) {
      return ersd_fail("clock_gettime failed");
    }
    result->verify_seconds += ersd_seconds_since(&verify_start, &verify_end);
    ersd_print_progress(offset, bytes, result);
  }
  read_limit = result->actual_bytes;
  if (clock_gettime(CLOCK_MONOTONIC, &start) != 0) {
    return ersd_fail("clock_gettime failed");
  }
  while (next_read_offset < read_limit) {
    size_t span = (size_t)ersd_min_u64((uint64_t)sizeof(g_ersd_buffer),
                                       read_limit - next_read_offset);
    if (ersd_same_span(fd, next_read_offset, span, block_bytes,
                       ERSD_PATTERN_SALT_A) == 0) {
      result->failed = 1;
      result->first_bad_offset = next_read_offset;
      result->actual_bytes = next_read_offset;
      break;
    }
    next_read_offset += (uint64_t)span;
    result->read_check_bytes = next_read_offset;
  }
  if (clock_gettime(CLOCK_MONOTONIC, &end) != 0) {
    return ersd_fail("clock_gettime failed");
  }
  result->read_check_seconds = ersd_seconds_since(&start, &end);
  return 0;
}

static void ersd_print_text_field(const char* label, const char* value) {
  if (value != NULL && value[0] != '\0') {
    printf("%s: %s\n", label, value);
  } else {
    printf("%s: unavailable\n", label);
  }
}

static void ersd_print_report(const ErsdConfig* cfg,
                              const ErsdDeviceInfo* info,
                              const ErsdProbeResult* result,
                              uint64_t tested_bytes) {
  double write_mb_sec = ersd_mb_per_sec(result->write_bytes,
                                        result->write_seconds);

  printf("target: %s\n", cfg->target);
  printf("kind: %s\n", ersd_kind_label(info->kind));
  printf("claimed-bytes: %llu\n", (unsigned long long)info->claimed_bytes);
  printf("tested-bytes: %llu\n", (unsigned long long)tested_bytes);
  ersd_print_text_field("vendor", info->vendor);
  ersd_print_text_field("model", info->model);
  ersd_print_text_field("serial", info->serial);
  ersd_print_text_field("cid", info->cid);
  ersd_print_text_field("csd", info->csd);
  printf("write-bytes: %llu\n", (unsigned long long)result->write_bytes);
  printf("verify-bytes: %llu\n", (unsigned long long)result->verify_bytes);
  printf("read-check-bytes: %llu\n", (unsigned long long)result->read_check_bytes);
  printf("first-bad-offset: %llu\n", (unsigned long long)result->first_bad_offset);
  printf("actual-bytes: %llu\n", (unsigned long long)result->actual_bytes);
  printf("wrapped: %s\n", result->wrapped == 0 ? "no" : "yes");
  printf("write-mib-sec: %.2f\n",
         ersd_mib_per_sec(result->write_bytes, result->write_seconds));
  printf("write-mb-sec: %.2f\n", write_mb_sec);
  printf("observed-sd-speed-class: %s\n", ersd_sd_speed_class(write_mb_sec));
  printf("observed-uhs-speed-class: %s\n", ersd_uhs_speed_class(write_mb_sec));
  printf("observed-video-speed-class: %s\n",
         ersd_video_speed_class(write_mb_sec));
  printf("verify-mib-sec: %.2f\n",
         ersd_mib_per_sec(result->verify_bytes, result->verify_seconds));
  printf("read-check-mib-sec: %.2f\n",
         ersd_mib_per_sec(result->read_check_bytes, result->read_check_seconds));
  printf("status: %s\n", result->failed == 0 ? "pass" : "fail");
}

int main(int argc, char** argv) {
  ErsdConfig cfg;
  ErsdDeviceInfo info;
  ErsdProbeResult result;
  uint64_t tested_bytes;
  int fd;
  int status = 0;

  status = ersd_parse_args(argc, argv, &cfg);
  if (status != 0) {
    return status;
  }
  if (ersd_open_info(cfg.target, &fd, &info) != 0) {
    return 1;
  }
  tested_bytes = info.claimed_bytes;
  if (cfg.byte_limit != 0u) {
    tested_bytes = ersd_min_u64(tested_bytes, cfg.byte_limit);
  }
  tested_bytes -= tested_bytes % (uint64_t)cfg.block_bytes;
  if (tested_bytes == 0u) {
    close(fd);
    return ersd_fail("tested byte count is zero after block alignment");
  }
  ersd_print_live_header(&cfg, &info, tested_bytes);
  if (ersd_probe_interleaved(fd, tested_bytes, cfg.block_bytes, &result) != 0) {
    close(fd);
    return 1;
  }
  ersd_print_report(&cfg, &info, &result, tested_bytes);
  if (result.failed != 0 || result.actual_bytes < tested_bytes) {
    status = 1;
  }
  if (close(fd) != 0) {
    return ersd_fail("target close failed");
  }
  return status;
}
