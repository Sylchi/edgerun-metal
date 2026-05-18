#define _POSIX_C_SOURCE 200809L

#include <ctype.h>
#include <errno.h>
#include <stdarg.h>
#include <stdint.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

enum {
  ER_QEMU_ARGC = 3,
  ER_QEMU_CHECK_ARGC = 4,
  ER_QEMU_CONFIG_ARG = 1,
  ER_QEMU_ESP_ARG = 2,
  ER_QEMU_CHECK_CONFIG_ARG = 2,
  ER_QEMU_CHECK_ESP_ARG = 3,
  ER_QEMU_MAX_ARGS = 64,
  ER_QEMU_MAX_LINE = 512,
  ER_QEMU_PATH_MAX = 512,
  ER_QEMU_COPY_BUFFER_SIZE = 8192,
  ER_QEMU_PARSE_BASE = 10,
  ER_QEMU_EXEC_FAILED_STATUS = 127,
  ER_QEMU_SIGNAL_STATUS_BASE = 128,
  ER_QEMU_SWTPM_TPMSTATE_ARG = 3,
  ER_QEMU_SWTPM_CTRL_ARG = 4,
  ER_QEMU_SWTPM_PID_ARG = 5,
  ER_QEMU_SOCKET_WAIT_ATTEMPTS = 50,
  ER_QEMU_SOCKET_WAIT_NS = 100000000
};

typedef struct {
  char* qemu_binary;
  char* display;
  char* ovmf_code;
  char* ovmf_vars;
  char* capture;
  char* net_id;
  char* net_mac;
  char* tpm_state_dir;
  char* tpm_socket;
  char* tpm_pidfile;
  uint32_t memory_mb;
  uint32_t width;
  uint32_t height;
  uint32_t refresh;
  int virtio_gpu;
  int virtio_net;
  int tpm;
  int tpm_persist_state;
} ErQemuConfig;

typedef struct {
  char* values[ER_QEMU_MAX_ARGS];
  size_t count;
} ErQemuArgs;

static void er_qemu_free_string(char** value) {
  if (value != NULL && *value != NULL) {
    free(*value);
    *value = NULL;
  }
}

static char* er_qemu_dup_range(const char* begin, const char* end) {
  size_t len;
  char* out;

  if (begin == NULL || end == NULL || end < begin) return NULL;
  len = (size_t)(end - begin);
  out = (char*)malloc(len + 1u);
  if (out == NULL) return NULL;
  memcpy(out, begin, len);
  out[len] = '\0';
  return out;
}

static char* er_qemu_dup_cstr(const char* text) {
  if (text == NULL) return NULL;
  return er_qemu_dup_range(text, text + strlen(text));
}

static char* er_qemu_trim(char* text) {
  char* end;

  if (text == NULL) return NULL;
  while (*text != '\0' && isspace((unsigned char)*text) != 0) text++;
  end = text + strlen(text);
  while (end > text) {
    char* previous = end - 1;
    if (isspace((unsigned char)*previous) == 0) break;
    end = previous;
  }
  *end = '\0';
  return text;
}

static int er_qemu_set_string(char** field, const char* value) {
  char* copy;

  copy = er_qemu_dup_cstr(value);
  if (copy == NULL) return 0;
  er_qemu_free_string(field);
  *field = copy;
  return 1;
}

static int er_qemu_parse_bool(const char* value, int* out) {
  if (strcmp(value, "true") == 0 || strcmp(value, "yes") == 0 || strcmp(value, "1") == 0) {
    *out = 1;
    return 1;
  }
  if (strcmp(value, "false") == 0 || strcmp(value, "no") == 0 || strcmp(value, "0") == 0) {
    *out = 0;
    return 1;
  }
  return 0;
}

static int er_qemu_parse_u32(const char* value, uint32_t* out) {
  char* end;
  unsigned long parsed;

  errno = 0;
  parsed = strtoul(value, &end, ER_QEMU_PARSE_BASE);
  if (errno != 0 || end == value || *end != '\0' || parsed > UINT32_MAX) return 0;
  *out = (uint32_t)parsed;
  return 1;
}

static void er_qemu_config_destroy(ErQemuConfig* config) {
  if (config == NULL) return;
  er_qemu_free_string(&config->qemu_binary);
  er_qemu_free_string(&config->display);
  er_qemu_free_string(&config->ovmf_code);
  er_qemu_free_string(&config->ovmf_vars);
  er_qemu_free_string(&config->capture);
  er_qemu_free_string(&config->net_id);
  er_qemu_free_string(&config->net_mac);
  er_qemu_free_string(&config->tpm_state_dir);
  er_qemu_free_string(&config->tpm_socket);
  er_qemu_free_string(&config->tpm_pidfile);
}

static int er_qemu_apply_config(ErQemuConfig* config, const char* key, const char* value, const char* path, unsigned int line) {
  if (strcmp(key, "qemu_binary") == 0) return er_qemu_set_string(&config->qemu_binary, value);
  if (strcmp(key, "display") == 0) return er_qemu_set_string(&config->display, value);
  if (strcmp(key, "ovmf_code") == 0) return er_qemu_set_string(&config->ovmf_code, value);
  if (strcmp(key, "ovmf_vars") == 0) return er_qemu_set_string(&config->ovmf_vars, value);
  if (strcmp(key, "capture") == 0) return er_qemu_set_string(&config->capture, value);
  if (strcmp(key, "net_id") == 0) return er_qemu_set_string(&config->net_id, value);
  if (strcmp(key, "net_mac") == 0) return er_qemu_set_string(&config->net_mac, value);
  if (strcmp(key, "tpm_state_dir") == 0) return er_qemu_set_string(&config->tpm_state_dir, value);
  if (strcmp(key, "tpm_socket") == 0) return er_qemu_set_string(&config->tpm_socket, value);
  if (strcmp(key, "tpm_pidfile") == 0) return er_qemu_set_string(&config->tpm_pidfile, value);
  if (strcmp(key, "memory_mb") == 0) return er_qemu_parse_u32(value, &config->memory_mb);
  if (strcmp(key, "width") == 0) return er_qemu_parse_u32(value, &config->width);
  if (strcmp(key, "height") == 0) return er_qemu_parse_u32(value, &config->height);
  if (strcmp(key, "refresh") == 0) return er_qemu_parse_u32(value, &config->refresh);
  if (strcmp(key, "virtio_gpu") == 0) return er_qemu_parse_bool(value, &config->virtio_gpu);
  if (strcmp(key, "virtio_net") == 0) return er_qemu_parse_bool(value, &config->virtio_net);
  if (strcmp(key, "tpm") == 0) return er_qemu_parse_bool(value, &config->tpm);
  if (strcmp(key, "tpm_persist_state") == 0) return er_qemu_parse_bool(value, &config->tpm_persist_state);
  fprintf(stderr, "%s:%u: unknown key: %s\n", path, line, key);
  return 0;
}

static int er_qemu_load_config(const char* path, ErQemuConfig* config) {
  FILE* file;
  char line_buf[ER_QEMU_MAX_LINE];
  unsigned int line_no = 0u;

  file = fopen(path, "rb");
  if (file == NULL) {
    fprintf(stderr, "%s: open failed: %s\n", path, strerror(errno));
    return 0;
  }

  while (fgets(line_buf, sizeof(line_buf), file) != NULL) {
    char* comment;
    char* equals;
    char* key;
    char* value;
    line_no++;
    comment = strchr(line_buf, '#');
    if (comment != NULL) *comment = '\0';
    key = er_qemu_trim(line_buf);
    if (*key == '\0') continue;
    equals = strchr(key, '=');
    if (equals == NULL) {
      fprintf(stderr, "%s:%u: expected key = value\n", path, line_no);
      fclose(file);
      return 0;
    }
    *equals = '\0';
    value = er_qemu_trim(equals + 1);
    key = er_qemu_trim(key);
    if (*key == '\0') {
      fprintf(stderr, "%s:%u: empty key\n", path, line_no);
      fclose(file);
      return 0;
    }
    if (er_qemu_apply_config(config, key, value, path, line_no) == 0) {
      fclose(file);
      return 0;
    }
  }

  if (ferror(file) != 0) {
    fprintf(stderr, "%s: read failed: %s\n", path, strerror(errno));
    fclose(file);
    return 0;
  }
  fclose(file);
  return 1;
}

static int er_qemu_string_empty(const char* value) {
  return value == NULL || value[0] == '\0';
}

static int er_qemu_file_exists(const char* path) {
  struct stat st;
  return path != NULL && stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

static int er_qemu_validate_config(const ErQemuConfig* config, const char* esp_dir) {
  char boot_path[ER_QEMU_PATH_MAX];

  if (er_qemu_string_empty(config->qemu_binary) != 0) {
    fprintf(stderr, "qemu.conf: qemu_binary is required\n");
    return 0;
  }
  if (er_qemu_string_empty(config->display) != 0) {
    fprintf(stderr, "qemu.conf: display is required\n");
    return 0;
  }
  if (config->memory_mb == 0u || config->width == 0u || config->height == 0u || config->refresh == 0u) {
    fprintf(stderr, "qemu.conf: memory_mb, width, height, and refresh must be positive\n");
    return 0;
  }
  if (er_qemu_file_exists(config->ovmf_code) == 0) {
    fprintf(stderr, "qemu.conf: ovmf_code does not exist: %s\n", config->ovmf_code ? config->ovmf_code : "");
    return 0;
  }
  if (er_qemu_file_exists(config->ovmf_vars) == 0) {
    fprintf(stderr, "qemu.conf: ovmf_vars does not exist: %s\n", config->ovmf_vars ? config->ovmf_vars : "");
    return 0;
  }
  if (snprintf(boot_path, sizeof(boot_path), "%s/EFI/BOOT/BOOTX64.EFI", esp_dir) >= (int)sizeof(boot_path)) {
    fprintf(stderr, "ESP path is too long\n");
    return 0;
  }
  if (er_qemu_file_exists(boot_path) == 0) {
    fprintf(stderr, "Missing %s. Run make first.\n", boot_path);
    return 0;
  }
  if (config->virtio_net == 0 && er_qemu_string_empty(config->capture) == 0) {
    fprintf(stderr, "qemu.conf: capture requires virtio_net = true\n");
    return 0;
  }
  if (config->virtio_net != 0 && (er_qemu_string_empty(config->net_id) != 0 || er_qemu_string_empty(config->net_mac) != 0)) {
    fprintf(stderr, "qemu.conf: net_id and net_mac are required when virtio_net = true\n");
    return 0;
  }
  if (config->tpm != 0 &&
      (er_qemu_string_empty(config->tpm_state_dir) != 0 ||
       er_qemu_string_empty(config->tpm_socket) != 0 ||
       er_qemu_string_empty(config->tpm_pidfile) != 0)) {
    fprintf(stderr, "qemu.conf: TPM paths are required when tpm = true\n");
    return 0;
  }
  return 1;
}

static int er_qemu_copy_file(const char* src, const char* dst) {
  FILE* in;
  FILE* out;
  unsigned char buffer[ER_QEMU_COPY_BUFFER_SIZE];
  size_t read_count;

  in = fopen(src, "rb");
  if (in == NULL) {
    fprintf(stderr, "%s: open failed: %s\n", src, strerror(errno));
    return 0;
  }
  out = fopen(dst, "wb");
  if (out == NULL) {
    fprintf(stderr, "%s: open failed: %s\n", dst, strerror(errno));
    fclose(in);
    return 0;
  }
  while ((read_count = fread(buffer, 1u, sizeof(buffer), in)) > 0u) {
    if (fwrite(buffer, 1u, read_count, out) != read_count) {
      fprintf(stderr, "%s: write failed: %s\n", dst, strerror(errno));
      fclose(out);
      fclose(in);
      return 0;
    }
  }
  if (ferror(in) != 0) {
    fprintf(stderr, "%s: read failed: %s\n", src, strerror(errno));
    fclose(out);
    fclose(in);
    return 0;
  }
  if (fclose(out) != 0) {
    fprintf(stderr, "%s: close failed: %s\n", dst, strerror(errno));
    fclose(in);
    return 0;
  }
  fclose(in);
  return 1;
}

static int er_qemu_args_add(ErQemuArgs* args, const char* value) {
  if (args->count + 1u >= ER_QEMU_MAX_ARGS) {
    fprintf(stderr, "too many qemu arguments\n");
    return 0;
  }
  args->values[args->count] = er_qemu_dup_cstr(value);
  if (args->values[args->count] == NULL) return 0;
  args->count++;
  args->values[args->count] = NULL;
  return 1;
}

static int er_qemu_args_add_owned(ErQemuArgs* args, char* value) {
  if (args->count + 1u >= ER_QEMU_MAX_ARGS) {
    fprintf(stderr, "too many qemu arguments\n");
    free(value);
    return 0;
  }
  args->values[args->count] = value;
  args->count++;
  args->values[args->count] = NULL;
  return 1;
}

static char* er_qemu_format_arg(const char* fmt, ...)
#if defined(__GNUC__)
  __attribute__((format(printf, 1, 2)))
#endif
;

static char* er_qemu_format_arg(const char* fmt, ...) {
  int needed;
  char* out;
  va_list args;
  va_list count_args;

  va_start(args, fmt);
  va_copy(count_args, args);
  needed = vsnprintf(NULL, 0, fmt, count_args);
  va_end(count_args);
  if (needed < 0) return NULL;
  out = (char*)malloc((size_t)needed + 1u);
  if (out == NULL) {
    va_end(args);
    return NULL;
  }
  if (vsnprintf(out, (size_t)needed + 1u, fmt, args) != needed) {
    free(out);
    va_end(args);
    return NULL;
  }
  va_end(args);
  return out;
}

static void er_qemu_args_destroy(ErQemuArgs* args) {
  size_t i;

  if (args == NULL) return;
  for (i = 0u; i < args->count; ++i) free(args->values[i]);
  args->count = 0u;
}

static int er_qemu_build_args(const ErQemuConfig* config, const char* esp_dir, const char* vars_copy, ErQemuArgs* args) {
  char memory[32];
  char* device;
  char* drive;
  char* capture;

  snprintf(memory, sizeof(memory), "%u", config->memory_mb);
  if (!er_qemu_args_add(args, config->qemu_binary)) return 0;
  if (!er_qemu_args_add(args, "-m") || !er_qemu_args_add(args, memory)) return 0;
  if (!er_qemu_args_add(args, "-display") || !er_qemu_args_add(args, config->display)) return 0;
  if (!er_qemu_args_add(args, "-vga") || !er_qemu_args_add(args, "none")) return 0;
  if (config->virtio_gpu != 0) {
    device = er_qemu_format_arg("virtio-vga,disable-legacy=on,xres=%u,yres=%u", config->width, config->height);
  } else {
    device = er_qemu_format_arg("VGA,xres=%u,yres=%u,refresh_rate=%u", config->width, config->height, config->refresh);
  }
  if (device == NULL || !er_qemu_args_add(args, "-device") || !er_qemu_args_add_owned(args, device)) return 0;
  drive = er_qemu_format_arg("if=pflash,format=raw,readonly=on,file=%s", config->ovmf_code);
  if (drive == NULL || !er_qemu_args_add(args, "-drive") || !er_qemu_args_add_owned(args, drive)) return 0;
  drive = er_qemu_format_arg("if=pflash,format=raw,file=%s", vars_copy);
  if (drive == NULL || !er_qemu_args_add(args, "-drive") || !er_qemu_args_add_owned(args, drive)) return 0;
  drive = er_qemu_format_arg("format=raw,file=fat:rw:%s,media=disk", esp_dir);
  if (drive == NULL || !er_qemu_args_add(args, "-drive") || !er_qemu_args_add_owned(args, drive)) return 0;
  if (config->virtio_net != 0) {
    char* netdev = er_qemu_format_arg("user,id=%s", config->net_id);
    char* net_device = er_qemu_format_arg("virtio-net-pci,netdev=%s,mac=%s,disable-legacy=on", config->net_id, config->net_mac);
    if (netdev == NULL || net_device == NULL ||
        !er_qemu_args_add(args, "-netdev") || !er_qemu_args_add_owned(args, netdev) ||
        !er_qemu_args_add(args, "-device") || !er_qemu_args_add_owned(args, net_device)) {
      free(netdev);
      free(net_device);
      return 0;
    }
  }
  if (er_qemu_string_empty(config->capture) == 0) {
    capture = er_qemu_format_arg("filter-dump,id=edgerun-os-net-dump,netdev=%s,file=%s", config->net_id, config->capture);
    if (capture == NULL || !er_qemu_args_add(args, "-object") || !er_qemu_args_add_owned(args, capture)) return 0;
  }
  if (!er_qemu_args_add(args, "-serial") || !er_qemu_args_add(args, "mon:stdio")) return 0;
  return 1;
}

static int er_qemu_wait_for_socket(const char* path) {
  struct timespec sleep_time;
  int i;

  sleep_time.tv_sec = 0;
  sleep_time.tv_nsec = ER_QEMU_SOCKET_WAIT_NS;
  for (i = 0; i < ER_QEMU_SOCKET_WAIT_ATTEMPTS; ++i) {
    struct stat st;
    if (stat(path, &st) == 0 && S_ISSOCK(st.st_mode)) return 1;
    nanosleep(&sleep_time, NULL);
  }
  return 0;
}

static pid_t er_qemu_read_pidfile(const char* path) {
  FILE* file;
  long parsed;

  file = fopen(path, "rb");
  if (file == NULL) return 0;
  parsed = 0;
  if (fscanf(file, "%ld", &parsed) != 1) parsed = 0;
  fclose(file);
  return parsed > 0 ? (pid_t)parsed : 0;
}

static int er_qemu_run_child(char* const* argv) {
  pid_t pid;
  int status;

  pid = fork();
  if (pid < 0) {
    fprintf(stderr, "fork failed: %s\n", strerror(errno));
    return 1;
  }
  if (pid == 0) {
    execvp(argv[0], argv);
    fprintf(stderr, "%s: exec failed: %s\n", argv[0], strerror(errno));
    _exit(ER_QEMU_EXEC_FAILED_STATUS);
  }
  if (waitpid(pid, &status, 0) < 0) {
    fprintf(stderr, "waitpid failed: %s\n", strerror(errno));
    return 1;
  }
  if (WIFEXITED(status)) return WEXITSTATUS(status);
  if (WIFSIGNALED(status)) return ER_QEMU_SIGNAL_STATUS_BASE + WTERMSIG(status);
  return 1;
}

static int er_qemu_start_tpm(const ErQemuConfig* config, pid_t* out_pid) {
  char* swtpm_args[] = {
    "swtpm",
    "socket",
    "--tpm2",
    NULL,
    NULL,
    NULL,
    NULL,
    "--daemon",
    NULL
  };
  char tpmstate[ER_QEMU_PATH_MAX];
  char ctrl[ER_QEMU_PATH_MAX];
  char pidfile[ER_QEMU_PATH_MAX];
  int rc;

  if (snprintf(tpmstate, sizeof(tpmstate), "--tpmstate=dir=%s", config->tpm_state_dir) >= (int)sizeof(tpmstate) ||
      snprintf(ctrl, sizeof(ctrl), "--ctrl=type=unixio,path=%s", config->tpm_socket) >= (int)sizeof(ctrl) ||
      snprintf(pidfile, sizeof(pidfile), "--pid=file=%s", config->tpm_pidfile) >= (int)sizeof(pidfile)) {
    fprintf(stderr, "TPM paths are too long\n");
    return 0;
  }
  swtpm_args[ER_QEMU_SWTPM_TPMSTATE_ARG] = tpmstate;
  swtpm_args[ER_QEMU_SWTPM_CTRL_ARG] = ctrl;
  swtpm_args[ER_QEMU_SWTPM_PID_ARG] = pidfile;
  unlink(config->tpm_socket);
  unlink(config->tpm_pidfile);
  rc = er_qemu_run_child(swtpm_args);
  if (rc != 0) {
    fprintf(stderr, "swtpm failed with status %d\n", rc);
    return 0;
  }
  if (er_qemu_wait_for_socket(config->tpm_socket) == 0) {
    fprintf(stderr, "swtpm socket did not become ready: %s\n", config->tpm_socket);
    return 0;
  }
  *out_pid = er_qemu_read_pidfile(config->tpm_pidfile);
  return 1;
}

static int er_qemu_append_tpm_args(const ErQemuConfig* config, ErQemuArgs* args) {
  char* chardev = er_qemu_format_arg("socket,id=chrtpm,path=%s", config->tpm_socket);
  if (chardev == NULL ||
      !er_qemu_args_add(args, "-chardev") || !er_qemu_args_add_owned(args, chardev) ||
      !er_qemu_args_add(args, "-tpmdev") || !er_qemu_args_add(args, "emulator,id=tpm0,chardev=chrtpm") ||
      !er_qemu_args_add(args, "-device") || !er_qemu_args_add(args, "tpm-crb,tpmdev=tpm0")) {
    free(chardev);
    return 0;
  }
  return 1;
}

static int er_qemu_usage(const char* program) {
  fprintf(stderr, "usage: %s [--check] <qemu.conf> <esp-dir>\n", program);
  return 2;
}

int main(int argc, char** argv) {
  ErQemuConfig config;
  ErQemuArgs args;
  char vars_copy[ER_QEMU_PATH_MAX];
  const char* config_path;
  const char* esp_dir;
  int rc;
  pid_t tpm_pid = 0;

  if (argc == ER_QEMU_ARGC) {
    config_path = argv[ER_QEMU_CONFIG_ARG];
    esp_dir = argv[ER_QEMU_ESP_ARG];
  } else if (argc == ER_QEMU_CHECK_ARGC && strcmp(argv[1], "--check") == 0) {
    config_path = argv[ER_QEMU_CHECK_CONFIG_ARG];
    esp_dir = argv[ER_QEMU_CHECK_ESP_ARG];
  } else {
    return er_qemu_usage(argv[0]);
  }
  memset(&config, 0, sizeof(config));
  memset(&args, 0, sizeof(args));
  if (er_qemu_load_config(config_path, &config) == 0 ||
      er_qemu_validate_config(&config, esp_dir) == 0) {
    er_qemu_config_destroy(&config);
    return 1;
  }
  if (argc == ER_QEMU_CHECK_ARGC) {
    er_qemu_config_destroy(&config);
    return 0;
  }
  if (snprintf(vars_copy, sizeof(vars_copy), "%s/ovmf-vars-runtime.fd", esp_dir) >= (int)sizeof(vars_copy)) {
    fprintf(stderr, "runtime OVMF vars path is too long\n");
    er_qemu_config_destroy(&config);
    return 1;
  }
  if (er_qemu_copy_file(config.ovmf_vars, vars_copy) == 0) {
    er_qemu_config_destroy(&config);
    return 1;
  }
  if (config.tpm != 0 && er_qemu_start_tpm(&config, &tpm_pid) == 0) {
    unlink(vars_copy);
    er_qemu_config_destroy(&config);
    return 1;
  }
  if (er_qemu_build_args(&config, esp_dir, vars_copy, &args) == 0 ||
      (config.tpm != 0 && er_qemu_append_tpm_args(&config, &args) == 0)) {
    er_qemu_args_destroy(&args);
    unlink(vars_copy);
    er_qemu_config_destroy(&config);
    return 1;
  }
  rc = er_qemu_run_child(args.values);
  if (tpm_pid > 0) kill(tpm_pid, SIGTERM);
  er_qemu_args_destroy(&args);
  unlink(vars_copy);
  if (config.tpm != 0 && config.tpm_persist_state == 0) {
    unlink(config.tpm_socket);
    unlink(config.tpm_pidfile);
  }
  er_qemu_config_destroy(&config);
  return rc;
}
